class_name KatonLib
extends RefCounted
## Ateş doğası malzeme / şekil kütüphanesi (Katon). Ortak efekt yardımcısı kullanmaz; her şey bu dosyanın kendi shader'ları:
##   alev dili   : eksenli billboard yaprağında çok sayıda ince, kıvrılan, ayrı ayrı titreyen alev dili; uçlar kırılıp kopar,
##                 saydamlaşır, ucun üstünde kopmuş kıvılcım parçaları yükselir (asla tek koni / düz disk değil)
##   alev kütlesi: kabaran, yuvarlanan hacimli ateş topu (küre yüzeyi gürültüyle kabarır, kenar yırtılır, soğudukça dağılır)
##   alev şeridi : nokta dizisi boyunca akan, kenarları yalayan yırtık alev akımı (dil, halka, ağ ipliği, sargı)
##   ısı / iz    : köz kıvılcımı, ısı dalgalanması (ekran kırılması), kavrulmuş zemin + soğuyan kızgın damarlar, yanan zemin
##   renk        : beyaz-sarı çekirdek → sarı → turuncu → koyu kızıl kenar (pal 0); pal 1 mavi alev, pal 2 kızıl, pal 3 mühür
## Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır; burası yalnız malzeme + yapı taşı verir.

## Görünüm: 1 = cel (düz bantlı, çizgi film; 2026-11-24 grup 1 bu hâlde, "dön" denirse STYLE := 1),
##           2 = hacimli (yumuşak geçişli renk, parlayan çekirdek, yumuşak eriyen kenar, soğudukça duman; kullanıcı "güzel" dedi)
##           3 = parçacıklı (2 + alev dilleri sert şekil yerine yükselip sönen yumuşak alev parçacıklarından; sahnede doğan her
##               dil / kütle gerçek 3B alev parçacığı da püskürtür — kullanıcı: "katı çizimler olmasın, doğal partiküller")
##           4 = Storm 4 (kaynak: Storm 4 ateş topu videoları, 2026-11-24): opak, çizgisiz, 3 düz ton (sarı çekirdek /
##               turuncu gövde / koyu turuncu kenar), topak topak yırtık siluet; patlama soğudukça kömür dumanına döner, ardında
##               koyu duman topakları + yere yayılan gri toz kalır (kullanıcı 3'ü "doğal durmuyor" diye beğenmedi, Storm 4 seçti)
const STYLE := 2   # 4 (Storm) yapım aşamasında; 3 (parçacık) reddedildi

## Yapı (kullanıcı 2026-11-24, Gōkakyū onaylı yön): alev kütlesi / topu opak (içi dolu, siluet yırtık, arkası görünmez, çizgi
## efekti üstüne kontur çizmez); büyük patlama soğuyup kömür dumanı + toz bırakır; anlık alev dili aşağı / yana ışın gibi değil yukarı akar
const OPAQUE_BODY := true
## Yer ateşi 3B mi (true: hacimli alev gövdesi, false: kameraya dönen alev kartı) — kullanıcıya yan yana gösterilip seçilecek
const GROUND_3D := false   # 2026-11-24 denendi (FLAME3D_SHADER): kullanıcı kart hâlini daha iyi buldu

const PAL_FIRE := 0.0
const PAL_BLUE := 1.0
const PAL_CRIMSON := 2.0
const PAL_SEAL := 3.0
const PAL_BLACK := 4.0   # Amaterasu / Enton kara alevi

static var _cache := {}

# ================================================================== shader parçaları
const KNOISE := """
float kh(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float kn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(kh(i), kh(i + vec2(1.0, 0.0)), f.x);
	float b = mix(kh(i + vec2(0.0, 1.0)), kh(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float kf(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * kn(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return s;
}
"""

## Beş tonlu cel rampası: e yükseldikçe kenar (c4) → çekirdek (c0). Mühür paletinde iç koyu, kenar kızgın.
const KPAL := """
void kpal(float p, out vec3 c0, out vec3 c1, out vec3 c2, out vec3 c3, out vec3 c4) {
	if (p < 0.5) {
		c0 = vec3(1.0, 0.98, 0.86);
		c1 = vec3(1.0, 0.85, 0.3);
		c2 = vec3(1.0, 0.52, 0.1);
		c3 = vec3(0.86, 0.19, 0.05);
		c4 = vec3(0.42, 0.06, 0.03);
	} else if (p < 1.5) {
		c0 = vec3(0.93, 0.98, 1.0);
		c1 = vec3(0.58, 0.86, 1.0);
		c2 = vec3(0.3, 0.55, 1.0);
		c3 = vec3(0.2, 0.24, 0.86);
		c4 = vec3(0.08, 0.07, 0.38);
	} else if (p < 2.5) {
		c0 = vec3(1.0, 0.9, 0.78);
		c1 = vec3(1.0, 0.5, 0.32);
		c2 = vec3(0.93, 0.17, 0.1);
		c3 = vec3(0.6, 0.04, 0.06);
		c4 = vec3(0.26, 0.02, 0.04);
	} else if (p < 3.5) {
		c0 = vec3(0.1, 0.03, 0.09);
		c1 = vec3(0.17, 0.04, 0.12);
		c2 = vec3(0.32, 0.05, 0.12);
		c3 = vec3(0.95, 0.24, 0.07);
		c4 = vec3(1.0, 0.62, 0.22);
	} else {
		// Amaterasu kara alevi (anime): gövde zifiri kara, kenara doğru koyu mor-bordo kontur
		c0 = vec3(0.0, 0.0, 0.0);
		c1 = vec3(0.012, 0.004, 0.02);
		c2 = vec3(0.05, 0.015, 0.075);
		c3 = vec3(0.16, 0.05, 0.22);
		c4 = vec3(0.3, 0.09, 0.38);
	}
}

#ifdef KV2
vec4 kramp(float e, float p) {
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	kpal(p, c0, c1, c2, c3, c4);
	vec3 col = c4;
#ifdef KV4
	// Storm 4: opak, üç düz ton, kenar çizgisi yok; yalnız en sıcak yerde açık sarı
	vec3 k3 = mix(c2, c3, 0.4);
	col = k3;
	col = mix(col, c2, smoothstep(0.3, 0.36, e));
	col = mix(col, c1, smoothstep(0.58, 0.64, e));
	if (p < 0.5) {
		col = mix(col, mix(c1, c0, 0.55), smoothstep(0.86, 0.92, e));
	}
	return vec4(col * (1.0 + 0.3 * smoothstep(0.55, 0.9, e)), smoothstep(0.12, 0.17, e));
#endif
#ifdef KV3
	// kenar koyulaşmadan önce saydamlaşır (koyu kızıl halka = çizgi gibi okunuyordu); çekirdek beyaza patlamaz
	// doygun: dış kızıl → turuncu gövde → sarı; beyaz yalnız en yoğun çekirdekte
	col = mix(c3, c2, smoothstep(0.08, 0.38, e));
	col = mix(col, c1, smoothstep(0.42, 0.78, e));
	if (p < 0.5) {
		col = mix(col, c0, smoothstep(0.9, 1.15, e));
	}
	float hot3 = 1.0 + (p < 0.5 ? 0.6 : 0.3) * smoothstep(0.55, 1.0, e);
	return vec4(col * hot3, smoothstep(0.04, 0.85, e));   // saydamlık yavaş artar: kart kenarı okunmaz
#endif
	col = mix(col, c3, smoothstep(0.02, 0.17, e));
	col = mix(col, c2, smoothstep(0.17, 0.36, e));
	col = mix(col, c1, smoothstep(0.36, 0.58, e));
	col = mix(col, c0, smoothstep(0.58, 0.9, e));
	// sıcak kısım parlar (sRGB çarpanı; doğrusalda ~4 kat: ışık taşması eşiğini geçer)
	float hot = 1.0 + 0.85 * smoothstep(0.3, 0.95, e);
	return vec4(col * hot, smoothstep(0.0, 0.22, e));
}
#else
vec4 kramp(float e, float p) {
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	kpal(p, c0, c1, c2, c3, c4);
	vec3 col = c4;
	float a = 0.88;
	if (e > 0.1) {
		col = c3;
		a = 1.0;
	}
	if (e > 0.25) {
		col = c2;
	}
	if (e > 0.45) {
		col = c1;
	}
	if (e > 0.68) {
		col = c0;
	}
	return vec4(col, a);
}
#endif
"""

## Alev dili yaprağı (QuadMesh, taban orijinde; düğümün Y ekseni dilin yönü, kameraya eksen etrafında döner).
## count: yapraktaki ayrı dil sayısı; lean: dillerin uca doğru yana yatması; heat: söndükçe diller kısalır, kızarır, kopar.
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float count = 6.0;
instance uniform float lean = 0.0;

varying float vsx;
varying float vsy;
varying float vface;

KNOISE
KPAL

void vertex() {
	vsx = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	vsy = max(length(MODEL_MATRIX[1].xyz), 0.0001);
	vec3 ax = MODEL_MATRIX[1].xyz;
	float sy = max(length(ax), 0.0001);
	ax /= sy;
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 tocam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vface = abs(dot(ax, normalize(tocam)));
	vec3 rt = cross(ax, tocam);
	float rl = length(rt);
	rt = rl > 0.0001 ? rt / rl : vec3(1.0, 0.0, 0.0);
	vec3 fw = cross(rt, ax);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * sx, 0.0), vec4(ax * sy, 0.0), vec4(fw * sx, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME;
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float e = -1.0;
	int nt = int(clamp(count, 1.0, 9.0));
	float span = max(float(nt - 1), 1.0);
	float warp = kf(vec2(x * 1.3 + seed * 5.0, y * 2.0 - t * 2.6));
	for (int i = 0; i < 9; i++) {
		if (i >= nt) {
			break;
		}
		float fi = float(i);
		float r1 = kh(vec2(seed * 3.1 + fi, 7.7));
		float r2 = kh(vec2(fi * 1.3 + 0.5, seed + 2.2));
		float cx = (nt > 1 ? (fi / span - 0.5) * 1.1 : 0.0) + (r1 - 0.5) * 0.14;
		float ht = (0.45 + 0.55 * r2) * (1.0 - abs(cx) * 0.5);
		ht *= 0.8 + 0.2 * sin(t * (8.0 + r1 * 5.0) + fi * 2.1 + seed);
		float yy = y / max(ht, 0.05);
		if (yy < 1.6) {
			float bend = (sin(yy * 2.8 - t * (4.5 + r2 * 3.0) + fi * 1.7 + seed * 2.0) * 0.16 + (warp - 0.5) * 0.5 + lean) * yy * yy;
			float w = (0.09 + 0.08 * r1) * pow(max(1.0 - yy, 0.0), 0.75) * smoothstep(-0.05, 0.18, yy);
			float ei = 1.0 - abs(x - cx - bend) / max(w, 0.0001);
			float brk = kn(vec2(x * 7.0 + seed * 9.0 + fi, y * 6.0 - t * 7.0));
			if (yy > 0.5 && brk < (yy - 0.5) * 1.3) {
				ei = -1.0;
			}
			e = max(e, ei * (1.05 - yy * 0.55));
			float ph = fract(t * (1.1 + r1) + r2);
			vec2 fp = vec2(cx + bend * 1.2 + (r1 - 0.5) * 0.1, ht * (0.95 + ph * 0.45));
			float fr = 0.055 * (1.0 - ph) * (0.6 + r2 * 0.6);
			float ef = 1.0 - length(vec2(x * 0.6, y) - vec2(fp.x * 0.6, fp.y)) / max(fr, 0.0001);
			e = max(e, ef * 0.32);
		}
	}
	float bw = 0.62 * max(1.0 - y * 2.2, 0.0);
	float eb = (1.0 - abs(x + (warp - 0.5) * 0.25) / max(bw, 0.0001)) * max(1.0 - y * 2.0, 0.0) * 1.2;
	e = max(e, eb);
	e *= 0.75 + 0.5 * kf(vec2(x * 3.0 - seed, y * 4.0 - t * 5.0));
	float e_cel = e;   // çok dilli, dalgalı, ucu kopan alev silueti (opak alevde kullanılır)
#ifdef KV2
	// hacimli alev: ayrı bıçak diller yerine, yukarı akan ve kıvrılan gürültüden yumuşak alev gövdesi; dillerin izi içinde
	// daha sıcak damarlar olarak kalır. Kenar sert kesilmez, gürültüyle erir.
	vec2 q = vec2(x * 1.6 + (warp - 0.5) * 0.9 * y, y * 2.2 - t * 3.2 + seed);
	float fb = kf(q + vec2(kf(q * 1.7 + vec2(t * 0.7, seed)) * 0.8, 0.0));
	float body = (1.0 - abs(x) * (1.9 + y * 1.8)) * (1.0 - y * y * 0.9);
	float es = body * 0.95 + (fb - 0.5) * 0.8 * (0.3 + y);
	// kartın kenarına asla değmez (dikdörtgen kesik görünmesin)
	es *= (1.0 - smoothstep(0.45, 0.85, abs(x))) * (1.0 - smoothstep(0.7, 0.98, y)) * smoothstep(0.0, 0.06, y);
	e = max(es, e * 0.6) * (0.85 + 0.3 * fb);
#endif
#ifdef KV4
	// Storm 4 alevi: dikey çizgi değil, yuvarlak loblu topak gövde (düşük frekanslı, iki eksende eşit gürültü) + ucunda yalama
	{
		vec2 q4 = vec2(x * 1.15, y * 1.25 - t * 1.5) + vec2(seed * 3.0, seed);
		float lob = kf(q4 + vec2(kf(q4 * 1.3 + vec2(t * 0.35, seed)) * 0.8, 0.0));
		float body4 = (1.0 - abs(x) * (1.5 + y * 1.3)) * (1.0 - y * y * 0.75);
		e = body4 * 0.95 + (lob - 0.5) * 1.15;
		e *= (1.0 - smoothstep(0.55, 0.9, abs(x))) * (1.0 - smoothstep(0.8, 0.98, y)) * smoothstep(0.0, 0.12, y);
	}
#endif
#ifdef KV3
	// parçacık alev: kart içinde tabandan yükselen, kıvrılan, küçülüp soğuyan yumuşak yuvarlak alev parçaları (metre ölçeğinde
	// yuvarlak kalır); sert şekil yok, yoğunluk üst üste binen parçaların toplamı
	{
		float X = x * 0.5 * vsx;
		float Y = y * vsy;
		X += (kf(vec2(X * 1.3 + seed, Y * 1.1 - t * 2.4)) - 0.5) * 0.35 * vsx * y;
		float acc = 0.0;
		float hot = 0.0;
		for (int i = 0; i < 16; i++) {
			float fi = float(i);
			float r1 = kh(vec2(fi * 1.7 + seed, 3.3));
			float r2 = kh(vec2(seed * 2.1, fi * 0.9 + 1.1));
			float r3 = kh(vec2(fi + 4.4, seed * 1.3 + 7.0));
			float ph = fract(t * (0.8 + r1 * 0.9) + r2);
			float by = (0.12 + ph * (0.7 + 0.25 * r3)) * vsy;   // kartın içinden doğar (tabanda düz kesik olmasın)
			float bx = ((r1 - 0.5) * 0.55 * (1.0 - ph * 0.6) + sin(ph * 5.0 + fi) * 0.06 * ph + lean * ph * ph) * vsx;
			float rad = (0.16 + 0.1 * r3) * vsx * (1.0 - ph * 0.7) + 0.02 * vsy;
			vec2 dp = vec2(X - bx, Y - by);
			// yuvarlak baloncuk okunmasın: parça kenarı gürültüyle yırtılır, yukarı doğru uzar
			dp += (vec2(kn(dp / max(rad, 0.001) * 1.6 + vec2(fi * 3.1, t * 3.0)), kn(dp / max(rad, 0.001) * 1.6 + vec2(t * 2.0, fi * 1.7))) - 0.5) * rad * 1.3;
			dp.y *= 0.6;
			float g = exp(-dot(dp, dp) / max(rad * rad, 0.00001));
			acc += g * (1.0 - ph * 0.35);
			hot += g * (1.0 - ph);
		}
		float ep = (1.0 - exp(-acc * 0.45)) * (0.35 + 0.65 * clamp(hot * 0.6, 0.0, 1.0));   // yumuşak doyma
		e = ep * (0.9 + 0.25 * kf(vec2(X * 2.0, Y * 2.0 - t * 4.0)));
		// kartın kenarında dümdüz kesilmesin
		e *= (1.0 - smoothstep(0.5, 0.92, abs(x))) * (1.0 - smoothstep(0.78, 0.99, y)) * smoothstep(0.0, 0.22, y);
	}
#endif
	e *= heat;
#ifndef KOPQ
	if (e < 0.05) {
		discard;
	}
#endif
	vec4 rc = kramp(e, pal);
	float tipa = 1.0 - smoothstep(0.55, 1.0, y) * 0.55;
	ALBEDO = pow(rc.rgb, vec3(2.2)) * 1.0;
	ALPHA = rc.a * tipa * fade * smoothstep(1.0, 5.0, -VERTEX.z);
#ifdef KOPQ
	// opak alev dili (Gōkakyū tacıyla aynı dil): altı geniş, yukarı daralan, ucu titreyip 2-3 yalamaya ayrılan gerçek alev
	// şekli; dibi sarı, gövdesi turuncu, ucu kızıl; çubuk / kurşun kalem değil
	{
		vec3 k0;
		vec3 k1;
		vec3 k2;
		vec3 k3;
		vec3 k4;
		kpal(pal, k0, k1, k2, k3, k4);
		float hf = clamp(heat, 0.0, 1.25);
		float fl = kf(vec2(x * 2.2 + seed * 3.0, y * 2.4 - t * 3.4));
		// siluet: kartın kendi çok dilli, dalgalı, ucu kopan alev dilleri (koni değil) + biraz dolgun taban
		float ef = e_cel * min(hf, 1.15) - 0.08 + (fl - 0.5) * 0.12;
		ef *= smoothstep(0.0, 0.06, y);
		if (ef <= 0.0) {
			discard;
		}
		float hot = ef * (1.0 - y * 0.55) * min(hf, 1.0);
		vec3 fc = mix(k3, k2, smoothstep(0.04, 0.28, hot));
		fc = mix(fc, k1, smoothstep(0.42, 0.72, hot));
		ALBEDO = pow(fc, vec3(2.2)) * (1.0 + 0.4 * smoothstep(0.6, 0.9, hot));
		ALPHA = fade * smoothstep(1.0, 3.5, -VERTEX.z) * (1.0 - smoothstep(0.62, 0.9, vface)) * smoothstep(0.0, 0.05, ef);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ROUGHNESS = 0.02;
	}
#elif defined(KV2)
#ifndef KV4
	ALPHA *= smoothstep(0.05, 0.4, e);
#endif
	// ekseni kameraya bakan kart bozulur (düz kenarlı dikdörtgen gibi görünüyordu): o açıda saydamlaşır
	ALPHA *= 1.0 - smoothstep(0.62, 0.9, vface);
#endif
}
"""

## Yuvarlanan alev kütlesi (küre mesh): yüzey gürültüyle kabarır ve roll hızıyla yuvarlanır; kameraya bakan yüz beyaz-sarı
## çekirdek, kenarlar koyu kızıl kontur; ısı düştükçe kenarlar yırtılıp dağılır.
const MASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float roll = 1.0;

varying vec3 lp;

KNOISE
KPAL

void vertex() {
	lp = VERTEX;
	float n = kf(VERTEX.xy * 1.8 + VERTEX.zx * 1.3 + vec2(seed * 4.0, -TIME * roll * 1.4));
	float n2 = kn(VERTEX.yz * 3.5 + vec2(-TIME * roll * 2.2, seed));
	VERTEX += NORMAL * ((n - 0.5) * 0.36 + (n2 - 0.5) * 0.1);
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// düşük frekanslı, yumuşak bantlar (ince gri çizgi gürültüsü yok)
	float n = kf(lp.xy * 1.3 + lp.zz * 1.0 + vec2(seed * 6.0, -TIME * roll * 1.6));
	float n2 = kn(lp.yz * 2.2 + vec2(TIME * roll * 1.1, seed * 2.0));
	float e = (fv * 0.6 + (n - 0.5) * 0.32) * min(heat, 1.3);
	float edge = fv + (n2 - 0.5) * 0.25;
#ifdef KV4
	if (edge < 0.05) {
		discard;
	}
#elif defined(KV2)
	if (edge < 0.02 || e < 0.015) {
		discard;
	}
#else
	if (edge < 0.12 * (2.0 - min(heat, 1.0)) || e < 0.04) {
		discard;
	}
#endif
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	kpal(pal, c0, c1, c2, c3, c4);
#ifdef KV2
	vec4 rk = kramp(e * 1.15 + (fv > 0.85 ? (fv - 0.85) * heat * 1.5 : 0.0), pal);
	vec3 colv = rk.rgb;
	// soğudukça kenar dumanlı kararır
	colv = mix(colv, vec3(0.16, 0.11, 0.09), clamp((1.0 - min(heat, 1.0)) * 0.7 + (1.0 - fv) * 0.25 - 0.15, 0.0, 0.75));
	ALBEDO = pow(colv, vec3(2.2));
	ALPHA = fade * smoothstep(1.5, 7.0, -VERTEX.z) * smoothstep(0.08, 0.55, edge) * rk.a;
#ifdef KOPQ
	// opak gövde: içi dolu, siluet gürültüyle yırtık; arkası görünmez; çizgi efekti üstüne kontur çizmez (çimen işareti)
	ALPHA = fade * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.02, 0.3, edge + (kf(lp.xz * 4.0 + vec2(seed, TIME * roll)) - 0.5) * 0.35);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.02;
#endif
#ifdef KV4
	// Storm: ısı düştükçe alev kömür dumanına döner (içinde turuncu parçalar kalır); siluet topak topak, opak
	float bl = kf(lp.xy * 2.6 + lp.zz * 1.7 + vec2(seed * 2.0, -TIME * roll * 1.2));
	float cool = smoothstep(0.75, 0.25, heat + (bl - 0.5) * 0.5);
	vec3 smoke = mix(vec3(0.12, 0.11, 0.11), vec3(0.2, 0.18, 0.17), step(0.55, fv + (bl - 0.5) * 0.3));
	vec4 rk4 = kramp(0.3 + fv * 0.45 + (bl - 0.5) * 0.5 + max(heat - 1.0, 0.0), pal);
	ALBEDO = pow(mix(rk4.rgb, smoke, cool), vec3(2.2));
	ALPHA = fade * smoothstep(1.5, 7.0, -VERTEX.z) * smoothstep(0.1, 0.16, edge + (bl - 0.5) * 0.25);
#endif
#ifdef KV3
	// kabarık bulut dokusu, siluet iyice erir (katı küre okunmasın)
	float puff = kf(lp.xy * 3.4 + lp.zz * 2.1 + vec2(seed * 3.0, -TIME * roll * 2.4));
	ALPHA *= smoothstep(0.15, 0.75, fv * 0.8 + puff * 0.5) * 0.9;
#endif
#else
	// turuncu-sarı gövde, koyu kızıl kenar; beyaz yalnız sıcak küçük çekirdek
	vec3 col = c4;
	if (e > 0.13) {
		col = c3;
	}
	if (e > 0.28) {
		col = c2;
	}
	if (e > 0.5) {
		col = c1;
	}
	if (fv > 0.94 && heat > 1.05 && n > 0.45) {
		col = mix(c1, c0, 0.7);
	}
	// kameraya çok yakın kısım incelir (kamera alevin içinde kalıp ekranı kaplamasın)
	float cam_fade = smoothstep(1.5, 7.0, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2)) * 0.9;
	ALPHA = fade * cam_fade * smoothstep(0.1, 0.35, edge + 0.2) * (e > 0.13 ? 1.0 : 0.85);
#endif
}
"""

## Alev şeridi (strip mesh; UV.x boy 0..1, UV.y en): akan gürültüyle yırtık kenar, kenardan kopan yalamalar;
## head / tail görünen aralığı keser (ileri akış / arkadan toplanma).
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float flow = 2.0;
instance uniform float tiles = 4.0;
instance uniform float rag = 0.35;

KNOISE
KPAL

void fragment() {
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	if (u > head || u < tail) {
		discard;
	}
	float n = kf(vec2(u * tiles - TIME * flow, v * 1.5 + seed));
	float n2 = kn(vec2(u * tiles * 2.6 - TIME * flow * 1.7, seed * 3.0));
	float wdt = 1.0 - rag + rag * 2.0 * n2;
	float e = (1.0 - abs(v + (n - 0.5) * rag) / max(wdt, 0.05)) * (0.8 + 0.5 * n);
	float span = max(head - tail, 0.001);
	float k = (u - tail) / span;
	e *= smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.8, 1.0, k) * 0.75);
	float lk = kn(vec2(u * tiles * 5.0 - TIME * flow * 2.0, v * 2.0 + seed * 5.0));
	if (abs(v) > 0.55 && lk > 0.74) {
		e = max(e, 0.18);
	}
#ifdef KV2
	// hacimli akış: kenar gürültüyle erir, içte daha sıcak damarlar akar
	float fl = kf(vec2(u * tiles * 1.3 - TIME * flow * 1.2, v * 2.5 + seed * 2.0));
	e = e * (0.75 + 0.5 * fl) - (1.0 - abs(v)) * 0.0;
#endif
	e *= heat;
	if (e < 0.05) {
		discard;
	}
	vec4 rc = kramp(e, pal);
	ALBEDO = pow(rc.rgb, vec3(2.2)) * 1.0;
	ALPHA = rc.a * fade * smoothstep(1.0, 5.0, -VERTEX.z);
#ifdef KOPQ
	// opak alev şeridi (alev dili / ateş topu tacıyla aynı dil): kenarı yırtık, ortası sarı, kenarı turuncu-kızıl; neon tüp değil
	{
		vec3 k0;
		vec3 k1;
		vec3 k2;
		vec3 k3;
		vec3 k4;
		kpal(pal, k0, k1, k2, k3, k4);
		float hot = e * (1.0 - abs(v) * 0.5);
		vec3 rc2 = mix(k3, k2, smoothstep(0.06, 0.3, hot));
		rc2 = mix(rc2, k1, smoothstep(0.5, 0.82, hot));
		ALBEDO = pow(rc2, vec3(2.2)) * (1.0 + 0.4 * smoothstep(0.65, 0.95, hot));
		ALPHA = fade * smoothstep(1.0, 3.5, -VERTEX.z) * smoothstep(0.05, 0.12, e);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ROUGHNESS = 0.02;
	}
#elif defined(KV2)
#ifndef KV4
	ALPHA *= smoothstep(0.05, 0.5, e);
#endif
#endif
}
"""

## Kavrulmuş zemin (PlaneMesh 2x2): düzensiz kenarlı kömür lekesi + soğuyan kızgın damarlar. kind 1: girdap kolu (sarmal yanık).
const SCORCH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float grow = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float kind = 0.0;
instance uniform float pal = 0.0;

KNOISE
KPAL

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rim = grow * (0.7 + 0.3 * kf(vec2(ang * 1.5 + seed * 7.0, seed)));
	if (r > rim) {
		discard;
	}
	float k = r / max(rim, 0.001);
	vec2 sp = p * 3.0 + vec2(seed * 2.3);
	float n = kf(sp * 1.4);
	vec3 col = mix(vec3(0.05, 0.035, 0.03), vec3(0.2, 0.13, 0.09), smoothstep(0.5, 0.95, k + (n - 0.5) * 0.4));
	float vn = kf(sp * 1.1 + vec2(3.7, seed));
	float vein = 1.0 - smoothstep(0.0, 0.018, abs(vn - 0.5));
	if (kind > 0.5) {
		float sw = abs(sin(ang * 3.0 + r * 6.0 + (n - 0.5) * 1.5));
		vein = max(vein, 1.0 - smoothstep(0.0, 0.12, sw));
		col = mix(col, vec3(0.03, 0.02, 0.02), 1.0 - smoothstep(0.1, 0.4, sw));
	}
	// kor damarları: ince, kızıl-turuncu (beyaz değil: beyaz zikzak şimşek gibi okunuyordu), merkeze yakın ve sıcakken parlar
	vein *= step(k, 0.8) * step(0.03, heat) * (1.0 - smoothstep(0.35, 0.8, k)) * smoothstep(0.35, 0.7, kf(sp * 0.6 + vec2(seed)));
	vec4 rc = kramp(0.12 + heat * 0.22 + (n - 0.5) * 0.08, pal);
	col = mix(col, rc.rgb, vein * heat);
	float a = (1.0 - smoothstep(0.6, 1.0, k)) * 0.95;
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + vein * heat * 0.8);
	ALPHA = a * fade;
}
"""

## Yumuşak ışık halesi (kameraya dönük, toplamalı): alev topunun etrafındaki parlama
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec3 gcol = vec3(1.0, 0.6, 0.2);
instance uniform float fade = 1.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = pow(max(1.0 - r, 0.0), 2.2) * fade;
	ALBEDO = gcol;
	ALPHA = a;
#ifdef KV2
	ALBEDO = gcol * 2.2;
	ALPHA = min(a * 1.3, 1.0);
#endif
}
"""

## Isı dalgalanması: arkadaki görüntüyü titreyen gürültüyle kırar (kameraya dönük)
const SHIMMER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

KNOISE

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, vec4(0.0, sy, 0.0, 0.0), INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m = (1.0 - smoothstep(0.35, 1.0, length(p))) * fade;
	vec2 off = vec2(kn(UV * 7.0 + vec2(seed, TIME * 2.5)) - 0.5, kn(UV * 7.0 + vec2(4.0 + seed, TIME * 3.1)) - 0.5) * 0.022 * m;
	ALBEDO = texture(screen_tex, SCREEN_UV + off).rgb;
	ALPHA = m;
}
"""


# ================================================================== malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("KNOISE", KNOISE).replace("KPAL", KPAL)
	if STYLE >= 2:
		sh.code = sh.code.replace("shader_type spatial;", "shader_type spatial;" + char(10) + "#define KV2" + (char(10) + "#define KV3" if STYLE == 3 else "") + (char(10) + "#define KV4" if STYLE == 4 else ""))
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


## Opak varyant (içi dolu ateş gövdesi: kesik saydamlık, derinlik yazar, çizgi efekti üstüne kontur çizmez)
static func _mat_opq(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = _mat(key + "_src", code).duplicate()
	var sh = Shader.new()
	sh.code = m.shader.code.replace("depth_draw_never", "depth_draw_opaque").replace("shader_type spatial;", "shader_type spatial;" + char(10) + "#define KOPQ")
	m.shader = sh
	_cache[key] = m
	return m


static func mass_opq_mat() -> ShaderMaterial:
	return _mat_opq("mass_opq", MASS_SHADER)


static func sun_opq_mat() -> ShaderMaterial:
	return _mat_opq("sun_opq", SUN_SHADER)


## Opak alev topağı / topu (kalıcı): gövde için
static func mass_opq(r: float, pal := 0.0, heat := 1.0, roll := 1.0) -> MeshInstance3D:
	var mi = mass_mi(r, pal, heat, roll)
	mi.mesh = _sphere_hi()
	mi.material_override = mass_opq_mat()
	return mi


static func sun_opq(r: float, pal := 0.0, heat := 1.0, roll := 1.0) -> MeshInstance3D:
	var mi = sun_mi(r, pal, heat, roll)
	mi.mesh = _sphere_hi()
	mi.material_override = sun_opq_mat()
	return mi


static func ash_opq(r: float, dark := 1.0, ember := 0.0) -> MeshInstance3D:
	var mi = ash_mi(r, dark, ember)
	mi.mesh = _sphere_hi()
	mi.material_override = _mat_opq("ash_opq", ASH_SHADER)
	return mi


## Storm patlaması (ateş topu malzemesiyle): sarmal çizgili, alev taçlı topaklar; ~%60'ı yere yakın dışa yayılır, ~%40'ı
## mantar başı gibi yükselir; ısı düştükçe kurum lekeleri büyür, kömür dumanına döner, sonunda yırtılarak erir.
static func fire_burst(host: Node, p: Vector3, r0: float, r1: float, life: float, n := 14, pal := 0.0) -> void:
	for k in n:
		var cap = k >= int(n * 0.55)
		var a = randf() * TAU
		var d = Vector3(cos(a), 0.0, sin(a))
		var off = (d * randf_range(0.2, 0.6) + Vector3.UP * (randf_range(0.5, 0.9) if cap else randf_range(0.0, 0.3))) * r0
		var rr = r1 * (randf_range(0.3, 0.42) if cap else randf_range(0.26, 0.38))
		# iç içe: yere yayılan halka dar, mantar başı tepede toplanır (tek parça siluet)
		var to = p + d * r1 * (randf_range(0.1, 0.35) if cap else randf_range(0.35, 0.6)) + Vector3.UP * r1 * (randf_range(0.85, 1.25) if cap else randf_range(0.1, 0.4))
		var node = Node3D.new()
		put(host, node, p + off)
		node.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		var body = fireball_mi(1.0, pal, 1.25, randf_range(0.6, 1.4), 0.15)
		node.add_child(body)
		var cor: MeshInstance3D = null
		# patlama topağında taç yok (sönerken kırmızı daire bırakıyordu); siluet kabarık yüzeyden
		node.scale = Vector3.ONE * r0 * 0.4
		var tw = node.create_tween().set_parallel()
		tw.tween_property(node, "scale", Vector3.ONE * rr, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position", to, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(pf(body, "heat"), 1.25, 0.0, life * randf_range(0.7, 0.9)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if cor:
			tw.tween_method(pf(cor, "heat"), 1.2, 0.0, life * 0.5)
		tw.tween_method(pf(body, "fade"), 1.0, 0.0, life * 0.25).set_delay(life * 0.75)
		tw.chain().tween_callback(node.queue_free)


## Ateş topu gövdesi (Gōkakyū dili; tüm mermi ateş topları): sarmal çizgili opak gövde + siluetten yalayan taç ("Corona")
static func fireball_node(r: float, pal := 0.0, swirl := 1.0) -> Node3D:
	var root = Node3D.new()
	root.add_child(fireball_mi(r * 0.88, pal, 1.0, randf_range(0.8, 1.3), swirl))
	var cor = corona_mi(r * 0.88, 1.32, pal, 1.0)
	cor.name = "Corona"
	root.add_child(cor)
	root.add_child(glow_mi(pal_col(pal, 2) * 0.35, r * 1.6))
	return root


## Uçan ateş topunun her karesi: taç uçuşun tersine akar, arkadan küçülüp soğuyarak dumana dönen alev parçaları dökülür.
## st: mermiye özel sözlük (zamanlayıcı); r: görünen yarıçap
static func fireball_tick(host: Node, node: Node3D, pos: Vector3, vel: Vector3, r: float, st: Dictionary, dt: float, pal := 0.0) -> void:
	if not is_instance_valid(node):
		return
	var spd = vel.length()
	var bk = -vel / spd if spd > 0.5 else Vector3.ZERO
	var cor = node.get_node_or_null("Corona")
	if cor:
		cor.set_instance_shader_parameter("trail", bk * clampf(spd / 12.0, 0.3, 1.2) + Vector3.UP * 0.5)
	st["tr"] = float(st.get("tr", 0.0)) - dt
	if st["tr"] > 0.0 or spd < 2.0:
		return
	st["tr"] = 0.05 if r < 1.0 else 0.06
	var tp = pos + bk * r * 0.75 + Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)) * r * 0.35
	var fl = fireball_mi(r * randf_range(0.28, 0.4), pal, 1.05, 1.0, 0.15)
	put(host, fl, tp)
	var life = clampf(0.25 + r * 0.25, 0.3, 0.55)
	var tw = fl.create_tween().set_parallel()
	tw.tween_property(fl, "scale", Vector3.ONE * r * 0.1, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(fl, "position", tp + Vector3.UP * r * 0.6 + bk * r * 0.4, life)
	tw.tween_method(pf(fl, "heat"), 1.05, 0.05, life * 0.9)
	tw.tween_method(pf(fl, "fade"), 1.0, 0.0, life * 0.3).set_delay(life * 0.7)
	tw.chain().tween_callback(fl.queue_free)


## Ateş topu çarpması (ölçekli Storm patlaması): parlama + alev mantarı + kıvılcım; büyükse duman sütunu
static func fireball_impact(host: Node, pos: Vector3, r: float, pal := 0.0) -> void:
	r *= 1.35   # kullanıcı 2026-11-24: patlamalar küçük kalıyordu
	# yerde kalıcı iz: kavruk yanık + kızgın damarlar + bir süre yanan alev dilleri (kullanıcı: "yerde yanık yok")
	var g = floor_at(pos)
	if pos.y - g.y < r * 2.5 and host != null:
		scorch(host, g, r * 2.4, 18.0, 0.0, pal, 0.25)
		for k in clampi(int(3 + r * 2.0), 3, 10):
			var a = randf() * TAU
			var gp = floor_at(g + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.0) * r * 1.6)
			tongue(host, gp, randf_range(0.6, 1.3) * minf(r, 2.5), 0.5 * minf(r, 2.5), randf_range(2.0, 4.0), Vector3.UP, Vector3.ZERO, pal, 3, 1.1)
	flash_ball(host, pos, r * 1.4, pal)
	fire_burst(host, pos, r * 0.6, r * 1.6, clampf(0.6 + r * 0.25, 0.6, 1.4), clampi(int(5 + r * 3), 5, 14), pal)
	if r >= 0.9:
		storm_smoke(host, pos + Vector3.UP * r * 0.5, r * 1.1, 1.1, pal)
	embers(host, pos, clampi(int(14 + r * 20), 14, 70), r * 0.6, pal, {"vmin": 3.0, "vmax": 9.0, "spread": 130.0, "life": 1.2, "size": 0.1})
	light(host, pos, pal_col(pal, 1), 4.0 + r * 4.0, 6.0 + r * 8.0, 0.45)


## Alev hortumu karesi: huni yüzeyinde dönerek yükselen alev topakları (şerit yerine; Storm hortumu). Her karede çağrılır.
## R0 taban yarıçapı, R1 tepe yarıçapı, H boy, n bu karede doğan topak, spin +1 / -1 dönüş yönü
static func vortex_tick(host: Node, base: Vector3, R0: float, R1: float, H: float, n: int, pal := 0.0, spin := 1.0, szm := 1.0) -> void:
	for k in n:
		var u = pow(randf(), 0.8)
		var a = randf() * TAU
		var rr = lerpf(R0, R1, u)
		var out = Vector3(cos(a), 0, sin(a))
		var tan = Vector3(-sin(a), 0, cos(a)) * spin
		var p = base + out * rr + Vector3.UP * (0.2 + u * H)
		var sz = clampf(rr * 0.38, 0.25, 1.2) * szm
		var life = randf_range(0.45, 0.7)
		fire_puff(host, p, sz * 0.45, sz, life, tan * rr * 3.2 + Vector3.UP * H * 0.3 - out * rr * 0.25, pal, 1.15 - u * 0.1, 0.85)   # alev renginde söner (kurum kaya gibi görünüyordu)


## Tek alev topağı (alev akıntıları / dalgaları / iz): ateş topu malzemesi, kabarık yüzey; r0 → r1 büyür, vel ile süzülür,
## soğudukça kurum lekeli dumana döner ve erir
static func fire_puff(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, pal := 0.0, heat0 := 1.15, cool_to := 0.0) -> MeshInstance3D:
	var mi = fireball_mi(r0, pal, heat0, randf_range(0.6, 1.4), 0.15)
	put(host, mi, p)
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, life * 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "heat"), heat0, cool_to, life * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.3).set_delay(life * 0.7)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kalıcı alev topağı (ejder başı / gövdesi / yapı parçası): ateş topu malzemesi, kabarık yüzey, girdapsız
static func lump_mi(r: float, pal := 0.0, heat := 1.15, roll := 1.0) -> MeshInstance3D:
	return fireball_mi(r, pal, minf(heat, 1.15), roll, 0.15)


## Çarpma parlaması: topun içinden anlık büyüyüp sönen ışık saçan sarı-beyaz küre
static func flash_ball(host: Node, p: Vector3, r: float, pal := 0.0) -> void:
	var mi = fireball_mi(r * 0.5, pal, 1.35, 2.5)
	put(host, mi, p)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, 0.12).set_delay(0.12)
	tw.chain().tween_callback(mi.queue_free)


## Yerden dışa hızla yayılan gri toz halkası (alçak, opak, düz tonlu)
static func dust_ring(host: Node, p: Vector3, r: float, n := 12) -> void:
	var g = floor_at(p)
	for k in n:
		var a = k * TAU / n + randf_range(-0.25, 0.25)
		var dv = Vector3(cos(a), 0.0, sin(a))
		# yarı saydam, birbirine karışan, alçak toz bulutları (yerde yatan düz taş gibi okunmasın)
		var mi = ash_mi(r * 0.1, 0.05, 0.0)
		put(host, mi, g + dv * r * 0.35 + Vector3.UP * 0.4)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		var life = randf_range(1.0, 1.5)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "position", g + dv * r * randf_range(1.1, 1.7) + Vector3.UP * randf_range(0.6, 1.2), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(1.2, 0.7, 1.2) * r * randf_range(0.26, 0.36), life * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Kabaran, soğudukça kömür dumanına dönen opak alev bulutu (Storm patlaması): n topak r0 → r1, yukarı süzülür,
## ısı düştükçe topaklar koyulaşır, sonunda yırtılarak erir. Her yöne ışın gibi fışkıran kart yok.
static func fire_cloud(host: Node, p: Vector3, r0: float, r1: float, life: float, n := 6, vel := Vector3.UP, pal := 0.0) -> void:
	for k in n:
		var off = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized() * r0 * randf_range(0.3, 0.7)
		var mi = mass_opq(r0 * randf_range(0.6, 0.9), pal, 1.25, randf_range(1.5, 2.5))
		put(host, mi, p + off)
		var rr = r1 * randf_range(0.5, 0.75)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3.ONE * rr, life * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "position", p + off * 2.0 + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(pf(mi, "heat"), 1.25, 0.0, life * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.3).set_delay(life * 0.7)
		tw.chain().tween_callback(mi.queue_free)


static func flame_mat() -> ShaderMaterial:
	if OPAQUE_BODY and STYLE >= 2:
		return _mat_opq("flame_opq", FLAME_SHADER)
	return _mat("flame", FLAME_SHADER)


static func mass_mat() -> ShaderMaterial:
	return _mat("mass", MASS_SHADER)


static func ribbon_mat() -> ShaderMaterial:
	if OPAQUE_BODY and STYLE >= 2:
		return _mat_opq("ribbon_opq", RIBBON_SHADER)
	return _mat("ribbon", RIBBON_SHADER)


static func scorch_mat() -> ShaderMaterial:
	return _mat("scorch", SCORCH_SHADER)


static func glow_mat() -> ShaderMaterial:
	return _mat("glow", GLOW_SHADER)


static func shimmer_mat() -> ShaderMaterial:
	return _mat("shimmer", SHIMMER_SHADER)


## Köşe renkli düz (ışıksız) malzeme: MB ile kurulan küçük katı parçalar (diş, göz, şuriken, kaya)
static func flat_mat() -> StandardMaterial3D:
	if _cache.has("flat"):
		return _cache["flat"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_cache["flat"] = m
	return m


## Paletin tek rengi (ışık / hale için): 0 çekirdek … 4 kenar
static func pal_col(pal: float, i: int) -> Color:
	var tabs = [
		[Color(1.0, 0.98, 0.86), Color(1.0, 0.85, 0.3), Color(1.0, 0.52, 0.1), Color(0.86, 0.19, 0.05), Color(0.42, 0.06, 0.03)],
		[Color(0.93, 0.98, 1.0), Color(0.58, 0.86, 1.0), Color(0.3, 0.55, 1.0), Color(0.2, 0.24, 0.86), Color(0.08, 0.07, 0.38)],
		[Color(1.0, 0.9, 0.78), Color(1.0, 0.5, 0.32), Color(0.93, 0.17, 0.1), Color(0.6, 0.04, 0.06), Color(0.26, 0.02, 0.04)],
		[Color(0.1, 0.03, 0.09), Color(0.17, 0.04, 0.12), Color(0.32, 0.05, 0.12), Color(0.95, 0.24, 0.07), Color(1.0, 0.62, 0.22)],
		[Color(0.0, 0.0, 0.01), Color(0.015, 0.0, 0.025), Color(0.04, 0.008, 0.06), Color(0.2, 0.04, 0.26), Color(0.34, 0.07, 0.4)],
	]
	var row: Array = tabs[clampi(int(round(pal)), 0, 4)]
	return row[clampi(i, 0, 4)]


static func _quad_base() -> QuadMesh:
	if not _cache.has("qb"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.center_offset = Vector3(0.0, 0.5, 0.0)
		_cache["qb"] = q
	return _cache["qb"]


static func _quad_c() -> QuadMesh:
	if not _cache.has("qc"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["qc"] = q
	return _cache["qc"]


## Sık örülmüş küre (opak gövde: kenar düz, köşeli kâğıt gibi kırılmasın)
static func _sphere_hi() -> SphereMesh:
	if not _cache.has("sph_hi"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 56
		s.rings = 28
		_cache["sph_hi"] = s
	return _cache["sph_hi"]


static func _sphere() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 24
		s.rings = 12
		_cache["sph"] = s
	return _cache["sph"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


# ================================================================== temel yardımcılar
static func put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Örnek shader parametresini tween'leyen ayarlayıcı
static func pf(mi: GeometryInstance3D, k: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(k, v)


## Y ekseni a olan dik taban
static func axis_basis(a: Vector3) -> Basis:
	var y = a.normalized()
	if y.length() < 0.5:
		y = Vector3.UP
	var rf = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x = rf.cross(y).normalized()
	var z = x.cross(y)
	return Basis(x, y, z)


static func look(n: Node3D, dirv: Vector3) -> void:
	if not is_instance_valid(n) or dirv.length() < 0.0001:
		return
	var f = dirv.normalized()
	n.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)


static func floor_at(p: Vector3) -> Vector3:
	return Game.jutsu_floor_at(p)


static func side_of(d: Vector3) -> Vector3:
	var s = d.cross(Vector3.UP)
	if s.length() < 0.01:
		return Vector3.RIGHT
	return s.normalized()


# ================================================================== yapı taşları: alev
## Kalıcı alev dili yaprağı (bir düğüme iliştirmek için): h boy, w en, ax yerel yön, count dil sayısı
static func tongue_mi(h: float, w: float, ax: Vector3, pal := 0.0, count := 6, lean := 0.0, heat := 1.1) -> MeshInstance3D:
	var mi = gi(_quad_base(), flame_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("count", float(count))
	mi.set_instance_shader_parameter("lean", lean)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.basis = axis_basis(ax) * Basis.from_scale(Vector3(w, h, w))
	return mi


## Sahnede yaşayan alev dili: taban p, eksen ax; doğar, büyür, ısısı düşüp kızarır, uçlar kopar, söner
static func tongue(host: Node, p: Vector3, h: float, w: float, life: float, ax := Vector3.UP, vel := Vector3.ZERO, pal := 0.0, count := 6, heat0 := 1.15, lean := 0.0) -> MeshInstance3D:
	if OPAQUE_BODY and STYLE >= 2:
		if ax.normalized().dot(Vector3.UP) < 0.5:
			ax = (ax.normalized() + Vector3.UP * 1.3).normalized()   # alev ışın gibi aşağı / yana fışkırmaz, yukarı kıvrılır
		# yer ateşi (kullanıcı 2026-11-24 "yerdeki ateşler png ve yamuk"): yerde dimdik yanar, yerinde titrer, kaymaz,
		# basık yaprak gibi geniş olmaz
		if p.y - floor_at(p).y < 0.8:
			ax = (Vector3.UP + Vector3(randf_range(-0.1, 0.1), 0.0, randf_range(-0.1, 0.1))).normalized()
			vel = Vector3(0.0, maxf(vel.y, 0.0), 0.0)
			lean = 0.0
			w = minf(w, h * 0.7)
			if GROUND_3D:
				var fm = gi(_flame3d_mesh(), _mat("flame3d", FLAME3D_SHADER))
				fm.set_instance_shader_parameter("seed", randf() * 10.0)
				fm.set_instance_shader_parameter("heat", heat0)
				fm.set_instance_shader_parameter("pal", pal)
				fm.set_instance_shader_parameter("fade", 1.0)
				put(host, fm, floor_at(p))
				fm.rotation.y = randf() * TAU
				fm.scale = Vector3(w * 0.5, h * 0.25, w * 0.5)
				var ftw = fm.create_tween().set_parallel()
				ftw.tween_property(fm, "scale", Vector3(w, h, w), life * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				ftw.tween_method(pf(fm, "heat"), heat0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				if vel.y > 0.0:
					ftw.tween_property(fm, "position", floor_at(p) + Vector3.UP * vel.y * life * 0.3, life)
				ftw.chain().tween_callback(fm.queue_free)
				return fm
		elif Vector2(vel.x, vel.z).length() > 5.0:
			# hızla ileri fırlayan alev: düz kart havada kayan resim gibi okunur → kabaran opak alev topağı
			return fire_puff(host, p, maxf(w, h) * 0.12, minf(maxf(w, h) * 0.26, 1.1), life * 1.1, vel * 0.9 + Vector3.UP * 0.5, pal, minf(heat0, 1.15), 0.4)   # küçük, kömüre dönmeden söner
	var mi = gi(_quad_base(), flame_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat0)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("count", float(count))
	mi.set_instance_shader_parameter("lean", lean)
	mi.set_instance_shader_parameter("fade", 1.0)
	put(host, mi, p)
	mi.basis = axis_basis(ax)
	mi.scale = Vector3(w * 0.5, h * 0.25, w * 0.5)
	if STYLE == 3:
		flame_puffs(host, p, ax, h, w, life, vel, pal, heat0)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(w, h, w), life * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "heat"), heat0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kalıcı alev kütlesi (mermi çekirdeği / ejder gövdesi için): yarıçap r
static func mass_mi(r: float, pal := 0.0, heat := 1.15, roll := 1.0) -> MeshInstance3D:
	var mi = gi(_sphere_hi(), mass_opq_mat()) if OPAQUE_BODY and STYLE >= 2 else gi(_sphere(), mass_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("roll", roll)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * r
	return mi


## Sahnede kabaran, yuvarlanan, soğuyup dağılan alev kütlesi: r0 → r1
static func mass(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, pal := 0.0, heat0 := 1.25, roll := 1.0, squash := 1.0) -> MeshInstance3D:
	var mi = mass_mi(r0, pal, heat0, roll)
	var sq = Vector3(1.0, squash, 1.0)
	mi.scale = sq * r0
	put(host, mi, p)
	if STYLE == 3:
		flame_cloud(host, p, r0, r1, life, vel, pal, heat0)
	elif STYLE == 4 and r1 >= 1.2 and life >= 0.35:
		storm_smoke(host, p + vel * life * 0.7, r1, life, pal)
	elif OPAQUE_BODY and STYLE == 2 and r1 >= 1.8 and life >= 0.4:
		storm_smoke(host, p + vel * life * 0.7, r1 * 0.7, life, pal)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", sq * r1, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "heat"), heat0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Nokta dizisinden şerit mesh'i. hint verilirse şerit o eksene dik düzlemde yatar (UP → yere paralel); twin: ikinci dik düzlem
static func strip(pts: PackedVector3Array, w: float, hint := Vector3.ZERO, twin := true, widths := PackedFloat32Array()) -> ArrayMesh:
	var n = pts.size()
	if n < 2:
		return ArrayMesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tans: Array = []
	for i in n:
		var tv = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		tans.append(tv.normalized() if tv.length() > 0.00001 else Vector3.FORWARD)
	var planes = 2 if twin else 1
	for pl in planes:
		for i in n - 1:
			var w0 = w * (widths[i] if widths.size() == n else 1.0)
			var w1 = w * (widths[i + 1] if widths.size() == n else 1.0)
			var s0: Vector3 = _strip_side(tans[i], pl, hint) * w0
			var s1: Vector3 = _strip_side(tans[i + 1], pl, hint) * w1
			var u0 = float(i) / (n - 1)
			var u1 = float(i + 1) / (n - 1)
			st.set_uv(Vector2(u0, 0.0))
			st.add_vertex(pts[i] - s0)
			st.set_uv(Vector2(u0, 1.0))
			st.add_vertex(pts[i] + s0)
			st.set_uv(Vector2(u1, 1.0))
			st.add_vertex(pts[i + 1] + s1)
			st.set_uv(Vector2(u0, 0.0))
			st.add_vertex(pts[i] - s0)
			st.set_uv(Vector2(u1, 1.0))
			st.add_vertex(pts[i + 1] + s1)
			st.set_uv(Vector2(u1, 0.0))
			st.add_vertex(pts[i + 1] - s1)
	return st.commit()


static func _strip_side(tv: Vector3, pl: int, hint: Vector3) -> Vector3:
	if hint != Vector3.ZERO:
		var s = tv.cross(hint)
		if s.length() < 0.0001:
			s = tv.cross(Vector3.RIGHT)
		s = s.normalized()
		return s if pl == 0 else tv.cross(s).normalized()
	var rf = Vector3.UP if absf(tv.y) < 0.9 else Vector3.RIGHT
	var s2 = tv.cross(rf).normalized()
	return s2 if pl == 0 else tv.cross(s2).normalized()


## Alev şeridi örneği (sahneye eklenmez). o: hint, twin, flow, tiles, rag, widths, heat
static func ribbon_mi(pts: PackedVector3Array, w: float, pal := 0.0, o := {}) -> MeshInstance3D:
	var mi = gi(strip(pts, w, o.get("hint", Vector3.ZERO), bool(o.get("twin", true)), o.get("widths", PackedFloat32Array())), ribbon_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("heat", float(o.get("heat", 1.1)))
	mi.set_instance_shader_parameter("head", 1.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("flow", float(o.get("flow", 2.0)))
	mi.set_instance_shader_parameter("tiles", float(o.get("tiles", 4.0)))
	mi.set_instance_shader_parameter("rag", float(o.get("rag", 0.35)))
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


## Akan alev şeridi: travel → baş ileri akar, kuyruk arkadan toplanır; değilse yerinde yanar, soğuyup söner
static func ribbon(host: Node, pts: PackedVector3Array, w: float, life: float, pal := 0.0, o := {}) -> MeshInstance3D:
	# kalın alev akımı (en > ~1.3 m): geniş şerit düz tahta / kalas gibi okunur → yol boyunca sırayla kabaran alev topakları
	if OPAQUE_BODY and STYLE >= 2 and pts.size() >= 3:
		var wids: PackedFloat32Array = o.get("widths", PackedFloat32Array())
		var wmax = w
		for x in wids:
			wmax = maxf(wmax, w * x)
		if wmax > 1.3:
			var holder = MeshInstance3D.new()
			put(host, holder, Vector3.ZERO)
			var dl0 = float(o.get("delay", 0.0))
			var n = pts.size()
			var ww = weakref(host)
			for i in n:
				var wi = w * (float(wids[i]) if i < wids.size() else 1.0)
				var dir = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var at = pts[i]
				var tdl = dl0 + float(i) / n * minf(life * 0.4, 0.35)
				host.get_tree().create_timer(maxf(tdl, 0.0)).timeout.connect(func():
					var h = ww.get_ref()
					if h == null:
						return
					fire_puff(h, at, wi * 0.3, wi * 0.6, life * 0.8, dir * 6.0 + Vector3.UP * 0.6, pal, 1.15))
			host.get_tree().create_timer(life + dl0 + 0.5).timeout.connect(func(): if is_instance_valid(holder): holder.queue_free())
			return holder
	var mi = ribbon_mi(pts, w, pal, o)
	put(host, mi, Vector3.ZERO)
	var dl = float(o.get("delay", 0.0))
	var h0 = float(o.get("heat", 1.1))
	var tw = mi.create_tween().set_parallel()
	if bool(o.get("travel", true)):
		mi.set_instance_shader_parameter("head", 0.0)
		tw.tween_method(pf(mi, "head"), 0.0, 1.0, life * 0.4).set_delay(dl).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(pf(mi, "tail"), 0.0, 1.0, life * 0.7).set_delay(dl + life * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		mi.set_instance_shader_parameter("head", 0.0)
		tw.tween_method(pf(mi, "head"), 0.0, 1.0, minf(0.3, life * 0.3)).set_delay(dl).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(pf(mi, "heat"), h0, 0.0, life * 0.5).set_delay(dl + life * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


# ================================================================== yapı taşları: ısı, ışık, iz
static func glow_mi(col: Color, s: float) -> MeshInstance3D:
	var mi = gi(_quad_c(), glow_mat())
	mi.set_instance_shader_parameter("gcol", Vector3(col.r, col.g, col.b))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * s
	return mi


## Yumuşak parlama halesi: s boyuna açılır ve söner
static func glow(host: Node, p: Vector3, s: float, col: Color, life: float) -> MeshInstance3D:
	var mi = glow_mi(col, s * 0.4)
	put(host, mi, p)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Isı dalgalanması: sıcak havanın arkasındaki görüntü titrer (w en, h boy)
static func shimmer(host: Node, p: Vector3, w: float, h: float, life: float) -> MeshInstance3D:
	if STYLE >= 3 or OPAQUE_BODY:
		return null   # ekran kopyası saydam katmandan önce alınır: önündeki alevi silip arkadaki duvarı gösteriyordu (krem dikdörtgenler);
		# opak yapıda da düz dikdörtgen kart gibi okunuyor (kullanıcı 2026-11-24: "patlamada bariz 2D png")
	var mi = gi(_quad_c(), shimmer_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	put(host, mi, p)
	mi.scale = Vector3(w, h, w)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "fade"), 0.0, 1.0, life * 0.2)
	tw.tween_interval(life * 0.5)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.3)
	tw.tween_callback(mi.queue_free)
	return mi


## Kavrulmuş zemin izi: r yarıçap, kızgın damarlar life boyunca soğur, sonra söner. kind 1 = sarmal (girdap)
static func scorch(host: Node, p: Vector3, r: float, life: float, kind := 0.0, pal := 0.0, grow_t := 0.3) -> MeshInstance3D:
	var mi = gi(_plane(), scorch_mat())
	mi.set_instance_shader_parameter("kind", kind)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("heat", 1.0)
	put(host, mi, floor_at(p) + Vector3.UP * 0.05)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(r, 1.0, r)
	var tw = mi.create_tween()
	tw.tween_method(pf(mi, "grow"), 0.0, 1.0, grow_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(pf(mi, "heat"), 1.0, 0.0, life * 0.8)
	tw.chain().tween_method(pf(mi, "fade"), 1.0, 0.0, minf(1.5, life * 0.3))
	tw.tween_callback(mi.queue_free)
	return mi


static func _spark_tex() -> GradientTexture2D:
	if _cache.has("spark_tex"):
		return _cache["spark_tex"]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	var tx = GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 32
	tx.height = 32
	_cache["spark_tex"] = tx
	return tx


static func _spark_mat() -> StandardMaterial3D:
	if _cache.has("spark_mat"):
		return _cache["spark_mat"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _spark_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["spark_mat"] = m
	return m


## Doğal alev parçacıkları (STYLE 3): yumuşak, toplamalı alev kırıntıları eksen boyunca yükselir, kıvrılır, büyüyüp soğur:
## beyaz-sarı → turuncu → kızıl → is. Doku yok: yumuşak radyal leke + parçacığa göre dönen gürültü boyu.
static func _puff_tex() -> GradientTexture2D:
	if _cache.has("puff_tex"):
		return _cache["puff_tex"]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	var tx = GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 64
	tx.height = 64
	_cache["puff_tex"] = tx
	return tx


static func _puff_mat() -> StandardMaterial3D:
	if _cache.has("puff_mat"):
		return _cache["puff_mat"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _puff_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	_cache["puff_mat"] = m
	return m


static func c4_of(pal: float) -> Color:
	return pal_col(pal, 4)


static func _puff_ramp(pal: float) -> GradientTexture1D:
	var key = "puff_ramp_%d" % int(round(pal))
	if _cache.has(key):
		return _cache[key]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 0.75, 1.0])
	var c0 = pal_col(pal, 0)
	var c1 = pal_col(pal, 1)
	var c2 = pal_col(pal, 2)
	var c3 = pal_col(pal, 3)
	if pal > 2.5:
		c0 = pal_col(pal, 4)
		c1 = pal_col(pal, 3)
	g.colors = PackedColorArray([Color(c1 * 1.25, 0.0), Color(c1 * 1.1, 0.42), Color(c2, 0.4), Color(c3 * 0.85, 0.22), Color(c4_of(pal) * 0.6, 0.0)])
	var gt = GradientTexture1D.new()
	gt.gradient = g
	_cache[key] = gt
	return gt


static func flame_puffs(host: Node, p: Vector3, ax: Vector3, h: float, w: float, life: float, vel := Vector3.ZERO, pal := 0.0, heat := 1.1) -> GPUParticles3D:
	if heat <= 0.05 or h < 0.15:
		return null
	var a = ax.normalized() if ax.length() > 0.01 else Vector3.UP
	var pm = ParticleProcessMaterial.new()
	pm.direction = a
	pm.spread = 14.0
	var sp = clampf(h * 2.2 / maxf(life, 0.2), 1.5, 14.0)
	pm.initial_velocity_min = sp * 0.6
	pm.initial_velocity_max = sp
	pm.gravity = Vector3(0, 2.5, 0) + vel * 0.6
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.05, w * 0.3)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_noise_speed = Vector3(0, 1.5, 0)
	pm.color_ramp = _puff_ramp(pal)
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 0.45))
	cv.add_point(Vector2(0.35, 1.0))
	cv.add_point(Vector2(1.0, 0.55))
	var ct = CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var gpp = GPUParticles3D.new()
	var plife = clampf(life * 0.7, 0.3, 1.1)
	gpp.amount = clampi(int(6 + h * w * 3.0), 6, 28)
	gpp.lifetime = plife
	gpp.one_shot = true
	gpp.explosiveness = 0.35
	gpp.randomness = 0.6
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * clampf(w * 0.9, 0.25, 3.0)
	q.material = _puff_mat()
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	put(host, gpp, p)
	gpp.emitting = true
	kill(host, plife + 0.4, gpp)
	return gpp


## Kabaran alev bulutu parçacıkları (STYLE 3, patlama / kütle): r0 küresinden her yöne açılıp yükselen, soğuyup ise dönen parçalar
static func flame_cloud(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, pal := 0.0, heat := 1.2) -> GPUParticles3D:
	if heat <= 0.05:
		return null
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	var sp = clampf((r1 - r0) / maxf(life, 0.15) * 1.3, 0.8, 16.0)
	pm.initial_velocity_min = sp * 0.4
	pm.initial_velocity_max = sp
	pm.gravity = Vector3(0, 3.0, 0) + vel * 0.8
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.1, r0 * 0.8)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -60.0
	pm.angular_velocity_max = 60.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 1.2
	pm.color_ramp = _puff_ramp(pal)
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 0.5))
	cv.add_point(Vector2(0.4, 1.0))
	cv.add_point(Vector2(1.0, 0.8))
	var ct = CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var gpp = GPUParticles3D.new()
	var plife = clampf(life * 1.1, 0.35, 1.6)
	gpp.amount = clampi(int(10 + r1 * r1 * 2.5), 10, 48)
	gpp.lifetime = plife
	gpp.one_shot = true
	gpp.explosiveness = 0.75
	gpp.randomness = 0.5
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * clampf(r1 * 0.9, 0.4, 5.0)
	q.material = _puff_mat()
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-25, -25, -25), Vector3(50, 50, 50))
	put(host, gpp, p)
	gpp.emitting = true
	kill(host, plife + 0.4, gpp)
	return gpp


## Storm 4 patlama artığı: alev kütlesi sönerken yerine geçen koyu kömür dumanı topakları (yavaşça yükselip incelir) +
## zemine yakınsa yere yayılan açık gri toz bulutları. Kendi kül malzemesiyle (ash_puff).
static var _smoke_recent: Array = []   # [konum, zaman ms]


static func storm_smoke(host: Node, p: Vector3, r: float, life: float, pal := 0.0) -> void:
	if pal > 2.5:
		return   # mühür ateşi duman bırakmaz
	var now = Time.get_ticks_msec()
	_smoke_recent = _smoke_recent.filter(func(x): return now - int(x[1]) < 400)
	for x in _smoke_recent:
		if (x[0] as Vector3).distance_to(p) < r * 0.9:
			return   # aynı patlamanın parçaları ayrı ayrı duman yığmasın
	_smoke_recent.append([p, now])
	var w = weakref(host)
	host.get_tree().create_timer(life * 0.55).timeout.connect(func():
		var h = w.get_ref()
		if h == null:
			return
		var n = clampi(int(4 + r * 1.5), 4, 10)
		for k in n:
			var off = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.9), randf_range(-1, 1)) * r * 0.45
			_smoke_puff(h, p + off, r * 0.25, r * randf_range(0.42, 0.6), randf_range(1.4, 2.0), Vector3.UP * randf_range(0.6, 1.5) + off * 0.25, 1.0, 0.25)
		var g = floor_at(p)
		if false and p.y - g.y < r * 1.3 and r >= 1.6:   # yer tozu dust_ring'de (burada büyük gri kaya gibi okunuyordu)
			for k in clampi(int(2 + r * 0.6), 2, 5):
				var a = randf() * TAU
				var dv = Vector3(cos(a), 0.0, sin(a))
				_smoke_puff(h, g + dv * r * 0.5 + Vector3.UP * 0.3, r * 0.25, r * randf_range(0.4, 0.6), randf_range(1.0, 1.5), dv * randf_range(2.0, 4.0) * sqrt(r), 0.0, 0.0))


static func _smoke_puff(host: Node, p: Vector3, r0: float, r1: float, life: float, vel: Vector3, dark: float, ember: float) -> void:
	var mi = ash_opq(r0, dark, ember)
	put(host, mi, p)
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, life * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.4).set_delay(life * 0.6)
	tw.chain().tween_callback(mi.queue_free)


## Köz kıvılcımları: yükselip savrulan, küçülerek sönen kızgın zerreler. o: dir, spread, vmin, vmax, g, life, size, burst, damp
static func embers(host: Node, p: Vector3, n: int, r: float, pal := 0.0, o := {}) -> GPUParticles3D:
	var life = float(o.get("life", 1.2))
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 60.0))
	pm.initial_velocity_min = float(o.get("vmin", 1.5))
	pm.initial_velocity_max = float(o.get("vmax", 5.0))
	pm.gravity = o.get("g", Vector3(0, 1.5, 0))
	pm.damping_min = float(o.get("damp", 1.2))
	pm.damping_max = float(o.get("damp", 1.2))
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, r)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.0
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var c0 = pal_col(pal, 0) if pal < 2.5 else pal_col(pal, 4)
	var c2 = pal_col(pal, 2) if pal < 2.5 else pal_col(pal, 3)
	var c3 = pal_col(pal, 3) if pal < 2.5 else pal_col(pal, 3)
	g.colors = PackedColorArray([c0, c2, Color(c3.r, c3.g, c3.b, 0.0)])
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(1.0, 0.2))
	var ct = CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var gpp = GPUParticles3D.new()
	gpp.amount = maxi(1, n)
	gpp.lifetime = life
	gpp.one_shot = true
	gpp.explosiveness = float(o.get("burst", 0.7))
	gpp.randomness = 0.5
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.1))
	q.material = _spark_mat()
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-25, -25, -25), Vector3(50, 50, 50))
	put(host, gpp, p)
	gpp.emitting = true
	kill(host, life + 0.6, gpp)
	return gpp


static func light(host: Node, p: Vector3, col: Color, energy: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	put(host, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


## Yanan zemin: r yarıçaplı alanda dur boyunca rastgele noktalarda kısa diller yükselir, yer kavrulur, kor uçuşur
static func burn_patch(host: Node, p: Vector3, r: float, dur: float, pal := 0.0, rate := 0.12, hmax := 1.4) -> void:
	var root = Node3D.new()
	put(host, root, floor_at(p))
	scorch(host, p, r * 1.15, dur + 2.0, 0.0, pal)
	var n = maxi(1, int(dur / rate))
	var tw = root.create_tween()
	for i in n:
		tw.tween_callback(func():
			var k = float(i) / n
			var dying = clampf((1.0 - k) * 1.6, 0.25, 1.0)
			for q in 2:
				var a = randf() * TAU
				var rr = sqrt(randf()) * r
				var at = floor_at(root.global_position + Vector3(cos(a), 0, sin(a)) * rr)
				tongue(host, at, randf_range(0.5, hmax) * dying, randf_range(0.5, 0.9), randf_range(0.45, 0.7), Vector3(randf_range(-0.15, 0.15), 1, randf_range(-0.15, 0.15)), Vector3.ZERO, pal, randi_range(3, 5), 1.1)
			if i % 6 == 0:
				embers(host, root.global_position + Vector3.UP * 0.4, 5, r * 0.7, pal, {"vmin": 1.0, "vmax": 3.0, "life": 1.0}))
		tw.tween_interval(rate)
	tw.tween_callback(root.queue_free)


## Hazırlık: alev zerreleri sarmal çizerek bir noktaya akar, toplandıkça orada küçük bir dil kümesi kabarır
static func spiral_in(host: Node, to: Vector3, pal: float, t: float, n := 10, r := 1.4) -> void:
	for k in n:
		var a0 = k * TAU / n + randf() * 0.4
		var y0 = randf_range(-0.4, 0.8)
		var mi = tongue_mi(0.35, 0.18, Vector3.UP, pal, 2, 0.0, 1.2)
		put(host, mi, to + Vector3(cos(a0) * r, y0, sin(a0) * r))
		var tw = mi.create_tween()
		var dly = randf() * t * 0.3
		tw.tween_interval(dly)
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(mi):
				return
			var a = a0 + u * 3.5
			var rr = r * (1.0 - u)
			mi.global_position = to + Vector3(cos(a) * rr, y0 * (1.0 - u), sin(a) * rr)
			mi.basis = axis_basis(Vector3(-sin(a), 0.6, cos(a))) * Basis.from_scale(Vector3(0.22, 0.45, 0.22) * (0.4 + 0.8 * (1.0 - u))), 0.0, 1.0, maxf(0.05, t - dly)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	glow(host, to, 1.2, pal_col(pal, 1), t + 0.15)


## Fırlayan katı parça: yerçekimiyle düşer, döner, yere değince durup söner
static func toss(host: Node, mi: Node3D, p0: Vector3, v: Vector3, life: float, g := 16.0) -> void:
	put(host, mi, p0)
	var spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var stt = {"land": false}
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float) -> void:
		if not is_instance_valid(mi) or stt["land"]:
			return
		var pos = p0 + v * tm + Vector3.DOWN * 0.5 * g * tm * tm
		var fy = Game.jutsu_floor_at(pos).y + 0.05
		if pos.y < fy and tm > 0.05:
			pos.y = fy
			stt["land"] = true
		mi.global_position = pos
		mi.rotation = spin * tm, 0.0, life, life)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(mi.queue_free)


# ================================================================== yapı taşları: ejder
## Alev ejderi başı (-Z ileri). s: boy (1 ≈ 2.4 m uzunluk), jaw: çene açıklığı (derece), horns: geriye akan boynuz dili sayısı.
## Kafatası / üst burun / alt çene alev kütlesi; ağız içi koyu kızıl, dişler ve göz parlak; yele ve bıyık kıvrımları alev dili / şeridi.
static func dragon_head(s: float, pal := 0.0, jaw := 28.0, horns := 2, mane := 7) -> Node3D:
	var root = Node3D.new()
	var sk = lump_mi(1.0, pal, 1.2, 1.3)
	sk.scale = Vector3(0.82, 0.72, 1.0) * s
	sk.position = Vector3(0, 0.12, 0.15) * s
	root.add_child(sk)
	var sn = lump_mi(1.0, pal, 1.3, 1.5)
	sn.scale = Vector3(0.52, 0.36, 0.95) * s
	sn.position = Vector3(0, 0.16, -0.95) * s
	root.add_child(sn)
	var jw = Node3D.new()
	jw.position = Vector3(0, -0.22, -0.15) * s
	jw.rotation_degrees.x = -jaw
	root.add_child(jw)
	var lj = lump_mi(1.0, pal, 1.15, 1.5)
	lj.scale = Vector3(0.44, 0.2, 0.82) * s
	lj.position = Vector3(0, 0, -0.75) * s
	jw.add_child(lj)
	# ağız içi, dişler, göz: düz katı parçalar
	var dark = pal_col(pal, 4).darkened(0.3)
	var tooth = pal_col(pal, 0)
	var b = MB.new()
	b.add("sphere", Vector3(0, -0.1, -0.85) * s, Vector3(0.6, 0.25, 1.2) * s, dark, Vector3.ZERO, 10)
	for i in 4:
		for sx in [-1.0, 1.0]:
			var z = -0.55 - i * 0.28
			b.add("cone", Vector3(sx * (0.3 - i * 0.04), -0.08, z) * s, Vector3(0.09, 0.26, 0.09) * s, tooth, Vector3(180, 0, 0), 5)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.42, 0.42, -0.35) * s, Vector3(0.22, 0.13, 0.26) * s, tooth, Vector3(0, sx * 25.0, 0), 8)
		b.add("sphere", Vector3(sx * 0.46, 0.43, -0.4) * s, Vector3(0.07, 0.11, 0.08) * s, dark, Vector3.ZERO, 6)
	var fm = MeshInstance3D.new()
	fm.mesh = b.build(flat_mat())
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fm)
	var jb = MB.new()
	for i in 3:
		for sx in [-1.0, 1.0]:
			jb.add("cone", Vector3(sx * (0.24 - i * 0.04), 0.12, -0.6 - i * 0.26) * s, Vector3(0.08, 0.2, 0.08) * s, tooth, Vector3.ZERO, 5)
	var jm = MeshInstance3D.new()
	jm.mesh = jb.build(flat_mat())
	jm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jw.add_child(jm)
	# boynuzlar: geriye ve yukarı akan ince diller
	for k in horns:
		var sx = -1.0 if k % 2 == 0 else 1.0
		var hn = tongue_mi(1.5 * s, 0.4 * s, Vector3(sx * 0.25, 0.7, 0.75), pal, 2, 0.0, 1.25)
		hn.position = Vector3(sx * 0.32, 0.55, 0.2) * s
		root.add_child(hn)
	# yele: başın arkasından savrulan geniş diller
	for k in mane:
		var u = float(k) / maxf(1.0, mane - 1)
		var a = lerpf(-1.1, 1.1, u)
		var mn = tongue_mi(randf_range(1.6, 2.4) * s, randf_range(0.9, 1.3) * s, Vector3(sin(a) * 0.8, cos(a) * 0.5 + 0.2, 1.0), pal, 5, 0.1, 1.15)
		mn.position = Vector3(sin(a) * 0.55, cos(a) * 0.45 + 0.1, 0.6) * s
		root.add_child(mn)
	# bıyık kıvrımları: burundan geriye kıvrılan alev şeritleri (anime sarmal süs)
	for sx in [-1.0, 1.0]:
		var pts = PackedVector3Array()
		for i in 13:
			var u = float(i) / 12.0
			var a = u * 4.2
			var rr = 0.55 * (1.0 - u * 0.75)
			pts.append(Vector3(sx * (0.35 + u * 0.9 + cos(a) * rr * 0.4), -0.05 + sin(a) * rr * 0.6 - u * 0.3, -1.4 + u * 1.9) * s)
		var wid = PackedFloat32Array()
		for i in 13:
			wid.append(1.0 - float(i) / 13.0)
		var wh = ribbon_mi(pts, 0.11 * s, pal, {"flow": 3.0, "tiles": 3.0, "rag": 0.4, "widths": wid})
		root.add_child(wh)
	return root


## Ejder gövdesi: baş düğümünün izinden giden alev kütlesi halkaları (her biri yolun yönüne döner, sırtında diller).
## Baş yok olunca gövde kuyruktan başa doğru dağılarak söner.
static func serpent(host: Node, head: Node3D, n: int, spacing: float, r: float, pal := 0.0, crest := true) -> Node3D:
	var tree = host.get_tree()
	var root = Node3D.new()
	put(host, root, Vector3.ZERO)
	var segs: Array = []
	for i in n:
		var k = float(i) / maxf(1.0, n - 1)
		var sg = Node3D.new()
		root.add_child(sg)
		var rr = r * lerpf(0.95, 0.3, k)
		sg.add_child(lump_mi(rr, pal, 1.2 - k * 0.3, 1.2))
		if crest and i % 2 == 0:
			var cr = tongue_mi(rr * 2.4, rr * 1.7, Vector3(0, 0.75, 0.65), pal, 4, 0.0, 1.1)
			cr.position = Vector3(0, rr * 0.45, 0)
			sg.add_child(cr)
		if i % 3 == 1:
			for sx in [-1.0, 1.0]:
				var fin = tongue_mi(rr * 1.4, rr * 0.9, Vector3(sx * 0.8, 0.2, 0.6), pal, 3, 0.0, 1.0)
				sg.add_child(fin)
		sg.visible = false
		segs.append(sg)
	var cap = int(n * spacing / 0.25) + 8
	var stt = {"hist": [head.global_position], "gone": -1.0, "cb": Callable()}
	var cb = func() -> void:
		if not is_instance_valid(root):
			if tree.process_frame.is_connected(stt["cb"]):
				tree.process_frame.disconnect(stt["cb"])
			return
		var hist: Array = stt["hist"]
		var alive = is_instance_valid(head) and head.is_inside_tree()
		var now = Time.get_ticks_msec() / 1000.0
		if alive:
			var hp = head.global_position
			if hp.distance_to(hist[0]) > 0.25:
				hist.push_front(hp)
				if hist.size() > cap:
					hist.pop_back()
		elif stt["gone"] < 0.0:
			stt["gone"] = now
		var shrink = 1.0
		if stt["gone"] >= 0.0:
			shrink = 1.0 - (now - stt["gone"]) / 0.7
			if shrink <= 0.0:
				root.queue_free()
				if tree.process_frame.is_connected(stt["cb"]):
					tree.process_frame.disconnect(stt["cb"])
				return
		var j = 0
		var acc = 0.0
		for i in segs.size():
			var sg: Node3D = segs[i]
			var want = (i + 1) * spacing
			while j < hist.size() - 1 and acc + hist[j].distance_to(hist[j + 1]) < want:
				acc += hist[j].distance_to(hist[j + 1])
				j += 1
			if j >= hist.size() - 1:
				sg.visible = false
				continue
			var a: Vector3 = hist[j]
			var bq: Vector3 = hist[j + 1]
			var u = (want - acc) / maxf(a.distance_to(bq), 0.0001)
			sg.visible = true
			sg.global_position = a.lerp(bq, clampf(u, 0.0, 1.0))
			var dv = a - bq
			if dv.length() > 0.001:
				var f = dv.normalized()
				sg.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)
			# kuyruktan başa doğru dağılma
			var tail_k = float(i) / maxf(1.0, segs.size() - 1)
			var sk = clampf(shrink * 1.6 - tail_k * 0.6, 0.0, 1.0)
			sg.scale = Vector3.ONE * maxf(sk, 0.01)
	stt["cb"] = cb
	tree.process_frame.connect(cb)
	return root


# ================================================================== ek (Katon B): güneş topu, kül bulutu
## Dev ateş topu yüzeyi (küre mesh): turuncu gövdede yuvarlanan koyu kızıl konveksiyon lekeleri, sarı-beyaz parlak kenar
## (anime Gōkakyū: güneş gibi benekli top), siluet kenarı alevle yırtık. roll: yüzeyin akış hızı.
const SUN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float roll = 1.0;

varying vec3 lp;

KNOISE
KPAL

void vertex() {
	lp = VERTEX;
	float n = kf(VERTEX.xz * 2.2 + VERTEX.yy * 1.1 + vec2(seed * 3.0, TIME * roll * 0.8));
	VERTEX += NORMAL * (n - 0.5) * 0.12;
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float c1 = kf(lp.xy * 3.2 + lp.zz * 1.9 + vec2(seed, -TIME * roll * 1.6));
	float c2 = kn(lp.zy * 6.0 + vec2(TIME * roll * 0.9, seed * 2.0));
	float cells = smoothstep(0.5, 0.66, c1);
	float limb = pow(1.0 - fv, 2.5);
	// gövde turuncu (c2), lekeler koyu kızıl (c3), kenar sarı; beyaz yalnız ince kenar çizgisinde
	float e = 0.36 + limb * 0.4 - cells * 0.16 + (c2 - 0.5) * 0.12;
	e *= min(heat, 1.15);
	if (fv < 0.09 && c2 < 0.55) {
		discard;
	}
	if (e < 0.04) {
		discard;
	}
	vec4 rc = kramp(e, pal);
	ALBEDO = pow(rc.rgb, vec3(2.2)) * 1.0;
	ALPHA = fade * smoothstep(1.5, 7.0, -VERTEX.z);
#ifdef KV2
	ALPHA *= smoothstep(0.0, 0.3, fv + (c2 - 0.5) * 0.2);
#endif
#ifdef KV3
	ALPHA *= smoothstep(0.05, 0.6, fv + (c1 - 0.5) * 0.35);
#endif
#ifdef KV4
	ALPHA = fade * smoothstep(1.5, 7.0, -VERTEX.z) * smoothstep(0.1, 0.16, fv + (c1 - 0.5) * 0.35);
#endif
#ifdef KOPQ
	ALPHA = fade * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.02, 0.3, fv + (c1 - 0.5) * 0.4);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.02;
#endif
}
"""

## Kül / kurum bulutu topağı (küre mesh): topak topak kabaran gri cel bulut, koyu kontur; ember: içinde gizli kor beneği;
## ignite 0→1: kül gürültü eşiğiyle tutuşup alev rampasına döner (yanma lekeleri yayılır). dark: 0 açık kül, 1 kara kurum.
const ASH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float ignite = 0.0;
instance uniform float ember = 0.0;
instance uniform float dark = 0.0;

varying vec3 lp;

KNOISE
KPAL

void vertex() {
	lp = VERTEX;
	float n = kf(VERTEX.xy * 1.6 + VERTEX.zz * 1.2 + vec2(seed * 5.0, TIME * 0.15));
	float n2 = kn(VERTEX.yz * 3.0 + vec2(seed, -TIME * 0.3));
	VERTEX += NORMAL * ((n - 0.5) * 0.3 + (n2 - 0.5) * 0.08);
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 upv = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float n = kf(lp.xy * 2.0 + lp.zz * 1.3 + vec2(seed * 2.0, TIME * 0.2));
	float tone = dot(NORMAL, upv) * 0.5 + 0.5 + (n - 0.5) * 0.45;
	// kurum bile kara levha değil: koyu-orta gri, yarı saydam
	vec3 lo = mix(vec3(0.27, 0.26, 0.27), vec3(0.2, 0.19, 0.19), dark);
	vec3 mi = mix(vec3(0.42, 0.41, 0.42), vec3(0.3, 0.29, 0.29), dark);
	vec3 hi = mix(vec3(0.6, 0.59, 0.6), vec3(0.42, 0.41, 0.41), dark);
	vec3 col = lo;
	if (tone > 0.42) {
		col = mi;
	}
	if (tone > 0.68) {
		col = hi;
	}
	if (fv < 0.24 + (n - 0.5) * 0.12) {
		col = lo * 0.75;
	}
	float sp = kn(lp.xz * 9.0 + lp.yy * 4.0 + vec2(seed * 7.0, TIME * 1.5));
	if (ember > 0.0 && sp > 1.0 - ember * 0.14) {
		col = vec3(1.0, 0.55, 0.12);
	}
	float bn = kf(lp.zy * 2.6 + vec2(seed * 3.0, -TIME * 1.2));
	if (bn < ignite * 1.25 - 0.1) {
		vec4 rc = kramp(fv * 0.9 + (bn - 0.3) * 0.6 + ignite * 0.25, 0.0);
		col = rc.rgb;
	}
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + step(0.01, ignite) * 0.2);
	float soft = smoothstep(0.0, 0.35, fv);
	ALPHA = fade * mix(0.92, 0.5, dark) * mix(0.55, 1.0, soft) * smoothstep(1.5, 6.0, -VERTEX.z);
#ifdef KOPQ
	// opak duman (Storm): düz iki ton lekeli gürültüden (gölgeli kaya gibi değil), siluet yırtık, çizgi muafiyeti
	{
		vec3 o0 = mix(vec3(0.6, 0.56, 0.5), vec3(0.19, 0.17, 0.16), dark);
		vec3 o1 = mix(vec3(0.72, 0.68, 0.61), vec3(0.29, 0.26, 0.24), dark);
		float bo = kf(lp.xy * 2.4 + lp.zz * 1.6 + vec2(seed * 3.0, TIME * 0.3));
		vec3 oc = bo > 0.52 ? o1 : o0;
		if (ember > 0.0 && sp > 1.0 - ember * 0.14) {
			oc = vec3(1.0, 0.55, 0.12);
		}
		if (bn < ignite * 1.25 - 0.1) {
			// kül tutuşur (Haisekishō): yanan lekeler alev rengine döner
			vec3 q0;
			vec3 q1;
			vec3 q2;
			vec3 q3;
			vec3 q4;
			kpal(0.0, q0, q1, q2, q3, q4);
			float hb = fv * 0.8 + (0.3 - bn) * 0.8 + ignite * 0.3;
			oc = mix(q3, q2, smoothstep(0.1, 0.35, hb));
			oc = mix(oc, q1, smoothstep(0.55, 0.85, hb));
		}
		ALBEDO = pow(oc, vec3(2.2));
		ALPHA = fade * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.05, 0.3, fv + (n - 0.5) * 0.6);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ROUGHNESS = 0.02;
	}
#endif
#ifdef KV4
	// Storm 4 dumanı: opak, düz iki ton (kömür / koyu gri; toz açık gri), kenar çizgisi yok, siluet topak topak
	vec3 d0 = mix(vec3(0.5, 0.47, 0.42), vec3(0.11, 0.1, 0.1), dark);
	vec3 d1 = mix(vec3(0.62, 0.59, 0.53), vec3(0.19, 0.17, 0.16), dark);
	// gölgeli kaya gibi okunmasın: ton yüzey yönünden değil lekeli gürültüden (düz, iki ton)
	float bt = kf(lp.xy * 2.4 + lp.zz * 1.6 + vec2(seed * 3.0, TIME * 0.3));
	vec3 sc = bt > 0.52 ? d1 : d0;
	if (ember > 0.0 && sp > 1.0 - ember * 0.14) {
		sc = vec3(1.0, 0.55, 0.12);
	}
	ALBEDO = pow(sc, vec3(2.2));
	ALPHA = fade * smoothstep(1.5, 6.0, -VERTEX.z) * smoothstep(0.14, 0.2, fv + (n - 0.5) * 0.6);
#endif
}
"""


## Dev ateş topu gövdesi (Gōkakyū; kaynak Storm 4): opak, ortadan dışa sarmal dönen alev çizgileri, ışık saçan sarı-beyaz
## çekirdek, kenara doğru turuncu, içte koyu kızıl kaynama lekeleri. Görünüm uzayında hesaplanır: her açıdan girdap kameraya bakar.
const FIREBALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float spin = 1.0;
instance uniform float swirl = 1.0;   // 1: ateş topu girdabı; düşük: patlama topağı (göz gibi girdap olmasın, kaynar)
instance uniform float lump = 0.0;    // patlama topağı: yüzey karnabahar gibi kabarır (pürüzsüz top okunmasın)

varying vec3 lp;

KNOISE
KPAL

void vertex() {
	lp = VERTEX;
	float n = kf(VERTEX.xz * 2.0 + VERTEX.yy * 1.3 + vec2(seed * 3.0, TIME * 1.1));
	float n2 = kf(VERTEX.xy * 3.6 + VERTEX.zz * 2.4 + vec2(seed, -TIME * 0.7));
	VERTEX += NORMAL * ((n - 0.5) * (0.14 + lump * 0.45) + (n2 - 0.5) * lump * 0.3);
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rr = 1.0 - fv;
	float t = TIME * spin;
	// sarmal alev çizgileri (girdap): düzlem noktası yarıçapla artan açıda döndürülür (açı kullanılmaz: dikiş çizgisi olmasın)
	vec2 q = NORMAL.xy;
	float g1 = rr * 5.0 - t * 1.7;
	vec2 qa = mat2(vec2(cos(g1), sin(g1)), vec2(-sin(g1), cos(g1))) * q;
	float g2 = rr * 8.0 - t * 2.6;
	vec2 qb = mat2(vec2(cos(g2), sin(g2)), vec2(-sin(g2), cos(g2))) * q;
	float sw = kf(qa * vec2(1.4, 4.0) + vec2(seed, seed * 2.0));
	float st = smoothstep(0.48, 0.7, kf(qb * vec2(2.0, 6.0) + vec2(seed * 3.0, 1.0)));
	float boil = kf(lp.xy * 3.0 + lp.zz * 2.0 + vec2(seed, -t * 1.3));
	float e = 0.95 - rr * mix(0.55, 0.85, swirl) + (sw - 0.5) * 0.4 * swirl - st * 0.25 * swirl + (boil - 0.5) * 0.45 * (1.0 - swirl);
	e -= smoothstep(0.6, 0.75, boil) * smoothstep(0.25, 0.6, rr) * 0.25;   // kaynama lekeleri (orta halkada koyu kızıl)
	// hacim: alev yukarı akar — üst yüz daha sıcak, alt yüz koyu kızıl (düz disk değil küre okunur)
	vec3 nw = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	e += nw.y * 0.14 * swirl - max(-nw.y, 0.0) * 0.12 * swirl;
	e *= min(heat, 1.2);
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	kpal(pal, c0, c1, c2, c3, c4);
	// doygun: gövde turuncu, ortaya doğru sarı, beyaz yalnız çekirdeğin tam ortasında; dış halka ve lekeler kızıl
	vec3 col = mix(c3, c2, smoothstep(0.1, 0.38, e));
	col = mix(col, c1, smoothstep(0.55, 0.8, e));
	col = mix(col, c0, smoothstep(0.9, 1.05, e));
	// çekirdek ışık saçar (ışık taşması eşiğini geçer)
	float glow = 1.0 + 1.3 * smoothstep(0.82, 1.05, e);
	// soğuma (patlama bulutu): önce kurum lekeleri belirir, sonra tamamen kömür dumanına döner (Storm sırası)
	float cool = clamp(1.0 - heat, 0.0, 1.0);
	float soot = smoothstep(0.7 - cool * 0.75, 0.8 - cool * 0.75, boil);
	vec3 smoke = mix(vec3(0.2, 0.18, 0.17), vec3(0.3, 0.27, 0.25), step(0.5, kf(lp.xy * 2.0 + lp.zz * 1.5 + vec2(seed))));
	col = mix(col, smoke, clamp(soot * 0.95 + cool * cool * 0.8, 0.0, 1.0));
	glow = mix(glow, 1.0, cool);
	ALBEDO = pow(col, vec3(2.2)) * glow;
	ALPHA = fade * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.0, 0.2, fv + (boil - 0.5) * 0.25);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.02;
}
"""

## Ateş topunun alev tacı (gövdeden biraz büyük küre): yalnız gövde siluetinin dışındaki halkada, titreşerek yukarı ve
## dışa yalayan opak alev dilleri; uçları kızıla döner. Kart değil: topun kendi yırtık kenarı.
const CORONA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;
instance uniform float inner = 0.6;   // gövde siluetinin bu kürede düştüğü fv
instance uniform vec3 trail = vec3(0.0, 0.6, 0.0);   // dünya yönü: diller bu yöne daha uzun akar (uçuşun tersi + yukarı)

KNOISE
KPAL

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (fv > inner + 0.05) {
		discard;
	}
	float out_k = 1.0 - fv / max(inner, 0.01);          // 0 gövde kenarı … 1 taç dışı
	float up = NORMAL.y * 0.5 + 0.5;                     // görüntüde yukarıdaki kenarda diller daha uzun
	float t = TIME;
	vec2 d2 = normalize(NORMAL.xy + vec2(0.0001));      // kenar yönü (açı yerine: dikişsiz)
	float n1 = kf(d2 * 2.6 + vec2(seed - out_k * 1.2, t * 1.6 + seed));
	float n2 = kf(d2 * 6.5 + vec2(t * 2.4 - out_k * 2.5, seed * 2.0));
	vec3 nwc = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float tl = length(trail);
	float tb = tl > 0.001 ? max(dot(nwc, trail / tl), 0.0) * tl : 0.0;
	float len = ((0.25 + 0.75 * n1) * (0.5 + 0.45 * up) + (n2 - 0.5) * 0.25 + tb * (0.6 + 0.6 * n1)) * clamp(heat, 0.0, 1.2);
	float e = len - out_k;
	if (e < 0.0 || heat < 0.18) {
		discard;
	}
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	kpal(pal, c0, c1, c2, c3, c4);
	// taç: dibi turuncu-sarı, uçları kızıl
	float ek = e * min(heat, 1.2);
	vec3 col = mix(c3, c2, smoothstep(0.02, 0.25, ek));
	col = mix(col, c1, smoothstep(0.4, 0.7, ek));
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + 0.4 * smoothstep(0.45, 0.8, ek));
	ALPHA = fade * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.0, 0.08, e);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.02;
}
"""


## 3B alev gövdesi (yer ateşi): altı yuvarlak-geniş, yukarı sivrilen damla; gövde sallanır, boyu titrer, ucu yırtılıp kopar.
## Taban orijinde, boy 1, çap 1 (tongue ölçeğiyle aynı). Opak, çizgi efekti üstüne kontur çizmez.
const FLAME3D_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float pal = 0.0;

varying float hy;
varying vec3 lp;

KNOISE
KPAL

void vertex() {
	hy = VERTEX.y;
	lp = VERTEX;
	float t = TIME;
	float h2 = hy * hy;
	// gövde yukarıya doğru giderek daha çok sallanır (alev dalgalanması)
	VERTEX.x += (kf(vec2(seed * 3.0, t * 1.7 - hy * 1.6)) - 0.5) * 0.55 * h2;
	VERTEX.z += (kf(vec2(seed * 5.0 + 3.0, t * 1.5 - hy * 1.4)) - 0.5) * 0.55 * h2;
	// yüzey kabarır (yukarı akan topaklar)
	vec2 dirxz = normalize(VERTEX.xz + vec2(0.0001));
	float bulge = kf(dirxz * 1.7 + vec2(seed, hy * 3.2 - t * 4.2));
	VERTEX.xz *= 0.62 + bulge * 0.32;   // ince, gövde boyunca dalgalı (şişman çan değil)
	// boy titrer; söndükçe küçülür
	VERTEX.y *= (0.85 + 0.3 * kf(vec2(seed * 2.0, t * 3.2))) * clamp(heat, 0.25, 1.15);
}

void fragment() {
	float fv = FRONT_FACING ? clamp(dot(NORMAL, VIEW), 0.0, 1.0) : 0.15;   // yırtılan uçta görünen iç yüz: koyu turuncu
	float t = TIME;
	float tear = kf(vec2(lp.x * 3.5 + lp.z * 2.5 + seed, hy * 3.5 - t * 5.0));
	// uç yırtılır, kopar (2-3 yalamaya ayrılır); taban dolu
	float cut = hy * 1.15 - 0.45 + (tear - 0.5) * 0.9;
	if (cut > 0.42) {
		discard;
	}
	vec3 k0;
	vec3 k1;
	vec3 k2;
	vec3 k3;
	vec3 k4;
	kpal(pal, k0, k1, k2, k3, k4);
	float hot = ((1.0 - hy) * 0.55 + fv * 0.35 - (tear - 0.5) * 0.3 * hy) * min(heat, 1.1);
	vec3 col = mix(k3, k2, smoothstep(0.08, 0.3, hot));
	col = mix(col, k1, smoothstep(0.55, 0.85, hot));
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + 0.5 * smoothstep(0.7, 1.0, hot));
	ALPHA = fade * smoothstep(1.0, 3.0, -VERTEX.z) * smoothstep(0.42, 0.3, cut);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.02;
}
"""


static func _flame3d_mesh() -> ArrayMesh:
	if _cache.has("flame3d_mesh"):
		return _cache["flame3d_mesh"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var RS = 14
	var RN = 14
	var verts = []
	for j in RN + 1:
		var y = float(j) / RN
		# damla profili: yuvarlak taban, en geniş yer alt üçte birde, ucu sivri
		var r = 0.5 * pow(max(1.0 - y, 0.0), 0.75) * min(1.0, sqrt(y * 6.0 + 0.04))
		var row = []
		for i in RS:
			var a = TAU * i / RS
			row.append(Vector3(cos(a) * r, y, sin(a) * r))
		verts.append(row)
	for j in RN:
		for i in RS:
			var i2 = (i + 1) % RS
			var a = verts[j][i]
			var b = verts[j][i2]
			var c = verts[j + 1][i]
			var d = verts[j + 1][i2]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	var m = st.commit()
	_cache["flame3d_mesh"] = m
	return m


static func fireball_mi(r: float, pal := 0.0, heat := 1.0, spin := 1.0, swirl := 1.0) -> MeshInstance3D:
	var mi = gi(_sphere_hi(), _mat("fireball", FIREBALL_SHADER))
	mi.set_instance_shader_parameter("swirl", swirl)
	mi.set_instance_shader_parameter("lump", 1.0 if swirl < 0.5 else 0.0)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("spin", spin)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * r
	return mi


## r: gövde yarıçapı; taç gövdenin k katı büyüklükte
static func corona_mi(r: float, k := 1.3, pal := 0.0, heat := 1.0) -> MeshInstance3D:
	var mi = gi(_sphere_hi(), _mat("corona", CORONA_SHADER))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("inner", sqrt(1.0 - 1.0 / (k * k)))
	mi.set_instance_shader_parameter("trail", Vector3(0.0, 0.6, 0.0))
	mi.scale = Vector3.ONE * r * k
	return mi


static func sun_mat() -> ShaderMaterial:
	return _mat("sun", SUN_SHADER)


static func ash_mat() -> ShaderMaterial:
	return _mat("ash", ASH_SHADER)


## Benekli dev ateş topu yüzeyi (kalıcı; mermi gövdesi için): yarıçap r
static func sun_mi(r: float, pal := 0.0, heat := 1.1, roll := 1.0) -> MeshInstance3D:
	var mi = gi(_sphere_hi(), sun_opq_mat()) if OPAQUE_BODY and STYLE >= 2 else gi(_sphere(), sun_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("pal", pal)
	mi.set_instance_shader_parameter("roll", roll)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * r
	return mi


## Kül topağı (kalıcı): yarıçap r, dark 0 kül grisi … 1 kara kurum
static func ash_mi(r: float, dark := 0.0, ember := 0.0) -> MeshInstance3D:
	# opak duman / kül (Storm): yarı saydam gri cam baloncuk gibi görünmesin
	var mi = gi(_sphere_hi(), _mat_opq("ash_opq", ASH_SHADER)) if OPAQUE_BODY and STYLE >= 2 else gi(_sphere(), ash_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("ignite", 0.0)
	mi.set_instance_shader_parameter("ember", ember)
	mi.set_instance_shader_parameter("dark", dark)
	mi.scale = Vector3.ONE * r
	return mi


## Sahnede kabarıp sürüklenen, sonra incelip kaybolan kül / kurum topağı: r0 → r1
static func ash_puff(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, dark := 0.0, ember := 0.0) -> MeshInstance3D:
	var mi = ash_mi(r0, dark, ember)
	put(host, mi, p)
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, life * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
	tw.chain().tween_callback(mi.queue_free)
	return mi
