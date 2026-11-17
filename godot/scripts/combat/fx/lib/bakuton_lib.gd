class_name BakutonLib
extends RefCounted
## Patlama doğası (Bakuton / patlayıcı kil) malzeme + yapı taşı kütüphanesi. Ortak efekt yardımcısı kullanmaz; her şey bu
## dosyanın kendi shader'ları ve kendi geometrisi. Kompozisyon (şekil, hareket, sahne) her tekniğin kendi dosyasındadır.
##
## MALZEMELER
##   clay_mat()   : krem-beyaz kil — cel ışık bantları, hafif parlaklık bandı, ince parmak izi gürültüsü, yumuşak koyu kontur
##                  (ters kabuk, ekranda sabit kalınlık). Örnek parametreleri (sp / tp ile kökten tüm parçalara):
##                    glow  0..1  patlamadan önce kilin içten beyaz-sarı kızarması (fitil)
##                    crack 0..1  yüzeyde parlayan çatlak damarları
##                    melt  0..1  kil ufalanıp dağılır (kenarı kızgın)
##                    near  m     kameraya bu mesafeden yakın kısım dither ile silinir (ekranı kaplamaz)
##                    ow    çarpan kontur kalınlığı
##                  Renk köşe renginden gelir (MB / Loft rengi): CLAY, EYE, LIP, STONE ...
##   blast_mat()  : kabaran patlama topu (küre): beyaz-sarı çekirdek → şeftali → soğuyunca krem / gri cel duman, koyu kenar,
##                  gürültüyle yenilerek söner. pal: PAL_CLAY / PAL_SMOKE / PAL_WHITE / PAL_ORB
##   flash_mat()  : ani çekirdek parlaması (kameraya dönük): beyaz merkez, sivri yıldız kenarı, yumuşak hale
##   puff_mat()   : cel duman topağı (kameraya dönük): loblu siluet, iki ton, koyu kontur, aşınarak söner
##   ring_mat()   : şok halkası: tırtıklı iç kenarlı beyaz bant + kontur (herhangi bir düzlemde)
##   soot_mat()   : zeminde kurum / yanık izi: düzensiz kenar, ışınsal çizikler, isteğe bağlı çatlak + soğuyan kor
##   flake mat    : kül / pul / mikro bomba zerreleri (GPU parçacık)
##
## YAPI TAŞLARI (hepsi statik; host = sahnede bir düğüm, ör. PathJutsu örneği)
##   yaratıklar (-Z ileri, kök düğüm döner):  bird, spider, beetle, missile, dragon, c3_doll, giant, mine, lump, stone
##     dragon(): meta "head" (baş pivotu), "mouth" (ağız ucu işaretçisi); giant(): meta "hands" [sol, sağ]
##   ağızlar: palm_mouth (avuç ağzı çiğner, kil topağı belirir), chest_mouth (göğüs ağzı, dikişli dudak, yavaşça açılır)
##   patlama parçaları: flash, fireball, puff, ring, soot, shrapnel, toss, sparks, flakes, light, converge, orb_mi
##   explode(): parçalardan kurulu örnek Bakuton patlaması (başlangıç kompozisyonu; teknikler kendi şeklini kurmalı)
##   yardımcılar: put, kill, gi, pf, sp, tp, fuse, pop_in, flap, bone, look, axis_basis, floor_at

const CLAY := Color(0.96, 0.94, 0.88)
const CLAY_SHADE := Color(0.8, 0.79, 0.77)
const EYE := Color(0.09, 0.08, 0.09)
const LIP := Color(0.74, 0.32, 0.36)
const TONGUE := Color(0.88, 0.48, 0.52)
const GUM := Color(0.22, 0.06, 0.08)
const TOOTH := Color(0.98, 0.97, 0.93)
const STONE := Color(0.52, 0.45, 0.38)
const STITCH := Color(0.12, 0.1, 0.1)

const PAL_CLAY := 0.0    # beyaz-sarı çekirdek → şeftali → krem / gri duman
const PAL_SMOKE := 1.0   # yalnız gri duman (yıkıcı olmayan)
const PAL_WHITE := 2.0   # beyaz-camgöbeği (en büyük patlama)
const PAL_ORB := 3.0     # soluk sarı parlayan küre

const MAX_R := 13.0      # hiçbir patlama topu bundan büyümez

static var _cache := {}

# ================================================================== shader parçaları
const BNOISE := """
float bh(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float bn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(bh(i), bh(i + vec2(1.0, 0.0)), f.x);
	float b = mix(bh(i + vec2(0.0, 1.0)), bh(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float bf(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * bn(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

float bdith(vec2 fc) {
	return fract(52.9829189 * fract(dot(floor(fc), vec2(0.06711056, 0.00583715))));
}
"""

## Kil malzemesinin ve konturunun ORTAK örnek parametreleri (aynı sırayla: iki geçiş aynı yuvaları okur)
const CLAY_INST := """
instance uniform float glow = 0.0;
instance uniform float near = 1.2;
instance uniform float crack = 0.0;
instance uniform float ow = 1.0;
instance uniform float melt = 0.0;
"""

const CLAY_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

CLAY_INST
varying vec3 lp;

BNOISE

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float dep = -VERTEX.z;
	float vis = smoothstep(near * 0.5, near, dep);
	if (vis < bdith(FRAGCOORD.xy)) {
		discard;
	}
	float mn = bf(lp.xy * 3.1 + lp.zx * 2.3);
	if (melt > 0.001 && mn < melt * 1.05) {
		discard;
	}
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// el ile yoğrulmuş kil: ince parmak izi gürültüsü (büyük yüzeyde düz plastik görünmesin)
	float th = bn(lp.xy * 21.0 + lp.zz * 15.0) * 0.6 + bn(lp.zy * 37.0) * 0.4;
	base *= 0.94 + 0.09 * th;
	float cr = 0.0;
	if (crack > 0.001) {
		float v = abs(bn(lp.xz * 4.0 + lp.yy * 2.5) - 0.5) + abs(bn(lp.zy * 6.5 + lp.xx * 3.0) - 0.5) * 0.5;
		cr = (1.0 - smoothstep(0.015, 0.03 + 0.06 * crack, v)) * min(crack * 2.0, 1.0);
	}
	float me = 0.0;
	if (melt > 0.001) {
		me = 1.0 - smoothstep(0.0, 0.07, mn - melt * 1.05);
	}
	float hotk = max(cr, me);
	ALBEDO = mix(base, vec3(1.0, 0.86, 0.5), hotk);
	ROUGHNESS = 0.72;
	SPECULAR = 0.25;
	vec3 hot = mix(vec3(1.0, 0.7, 0.32), vec3(1.0, 0.98, 0.86), clamp(glow, 0.0, 1.0));
	EMISSION = hot * (glow * 1.7 + cr * 3.2 + me * 2.4);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.3 ? 1.0 : (ndl > -0.12 ? 0.74 : 0.54);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
	vec3 hv = normalize(VIEW + LIGHT);
	float s = pow(max(dot(NORMAL, hv), 0.0), 48.0);
	SPECULAR_LIGHT += step(0.55, s) * 0.3 * ATTENUATION * LIGHT_COLOR / PI;
}
"""

## Kil konturu: ters kabuk, görüş derinliğiyle ölçeklenir (ekranda sabit, yumuşak, sıcak koyu gri)
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

CLAY_INST
varying vec3 lp;

BNOISE

void vertex() {
	lp = VERTEX;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	float d = max(-vp.z, 0.3);
	vp.xyz += vn * ow * clamp(d * 0.0042, 0.004, 0.07);
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float dep = -VERTEX.z;
	float vis = smoothstep(near * 0.5, near, dep);
	if (vis < bdith(FRAGCOORD.xy)) {
		discard;
	}
	if (melt > 0.001 && bf(lp.xy * 3.1 + lp.zx * 2.3) < melt * 1.05) {
		discard;
	}
	vec3 ink = vec3(0.31, 0.28, 0.27);
	ink = mix(ink, vec3(1.0, 0.78, 0.4), clamp(glow, 0.0, 1.0) * 0.55);
	ALBEDO = pow(ink, vec3(2.2));
}
"""

## Patlama renk takımları: h0..h3 sıcak (çekirdek → kenar), s0..s2 soğumuş duman, ink kontur
const BPAL := """
void bpal(float p, out vec3 h0, out vec3 h1, out vec3 h2, out vec3 h3, out vec3 s0, out vec3 s1, out vec3 s2, out vec3 ink) {
	if (p < 0.5) {
		h0 = vec3(1.0, 1.0, 0.95);
		h1 = vec3(1.0, 0.94, 0.62);
		h2 = vec3(1.0, 0.75, 0.44);
		h3 = vec3(0.93, 0.52, 0.3);
		s0 = vec3(0.93, 0.9, 0.84);
		s1 = vec3(0.74, 0.71, 0.68);
		s2 = vec3(0.55, 0.52, 0.51);
		ink = vec3(0.3, 0.27, 0.27);
	} else if (p < 1.5) {
		h0 = vec3(0.8, 0.79, 0.78);
		h1 = vec3(0.7, 0.69, 0.69);
		h2 = vec3(0.6, 0.59, 0.6);
		h3 = vec3(0.5, 0.49, 0.51);
		s0 = vec3(0.78, 0.77, 0.76);
		s1 = vec3(0.6, 0.59, 0.6);
		s2 = vec3(0.47, 0.46, 0.48);
		ink = vec3(0.24, 0.23, 0.25);
	} else if (p < 2.5) {
		h0 = vec3(1.0, 1.0, 1.0);
		h1 = vec3(0.9, 0.98, 1.0);
		h2 = vec3(0.72, 0.92, 0.98);
		h3 = vec3(0.52, 0.8, 0.92);
		s0 = vec3(0.86, 0.88, 0.9);
		s1 = vec3(0.66, 0.68, 0.72);
		s2 = vec3(0.48, 0.5, 0.55);
		ink = vec3(0.25, 0.27, 0.32);
	} else {
		h0 = vec3(1.0, 1.0, 0.9);
		h1 = vec3(1.0, 0.96, 0.7);
		h2 = vec3(0.98, 0.88, 0.56);
		h3 = vec3(0.92, 0.76, 0.44);
		s0 = vec3(0.86, 0.84, 0.76);
		s1 = vec3(0.66, 0.63, 0.58);
		s2 = vec3(0.45, 0.42, 0.4);
		ink = vec3(0.32, 0.28, 0.24);
	}
}
"""

## Kabaran patlama topu (küre): düşük frekanslı loblar kabarır; kameraya bakan yüz sıcak, kenar koyu kontur.
## heat 1 → 0: sıcak bantlar gürültülü bir cephe ile soğuk cel dumana döner. fade 1 → 0: gürültüyle yenip söner.
const BLAST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float near = 7.0;
instance uniform float pal = 0.0;
instance uniform float lump = 1.0;
varying vec3 lp;

BNOISE
BPAL

void vertex() {
	lp = VERTEX;
	float n = bf(VERTEX.xy * 1.3 + VERTEX.zx * 1.1 + vec2(seed * 3.0, -TIME * 0.5));
	float n2 = bn(VERTEX.yz * 2.6 + vec2(seed * 1.7, TIME * 0.35));
	VERTEX += NORMAL * ((n - 0.5) * 0.5 + (n2 - 0.5) * 0.16) * lump;
}

void fragment() {
	float dep = -VERTEX.z;
	float vis = smoothstep(near * 0.55, near, dep);
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = bf(lp.xy * 1.4 + lp.zz * 1.1 + vec2(seed * 5.0, -TIME * 0.7));
	float fine = bn(lp.xy * 13.0 + lp.zx * 11.0 + vec2(seed, TIME * 0.4));
	float keep = n * 0.75 + fine * 0.12 + fv * 0.3;
	float cut = (1.0 - fade) * 1.17;
	if (keep < cut || vis < bdith(FRAGCOORD.xy)) {
		discard;
	}
	float e = fv * 0.8 + (n - 0.5) * 0.45 + (fine - 0.5) * 0.06;
	vec3 h0;
	vec3 h1;
	vec3 h2;
	vec3 h3;
	vec3 s0;
	vec3 s1;
	vec3 s2;
	vec3 ink;
	bpal(pal, h0, h1, h2, h3, s0, s1, s2, ink);
	vec3 hot = h3;
	if (e > 0.3) {
		hot = h2;
	}
	if (e > 0.5) {
		hot = h1;
	}
	if (e > 0.7) {
		hot = h0;
	}
	vec3 smk = s2;
	if (e > 0.38) {
		smk = s1;
	}
	if (e > 0.62) {
		smk = s0;
	}
	float hz = heat + (n - 0.5) * 0.6 + (fv - 0.5) * 0.3;
	vec3 col = hz > 0.55 ? hot : smk;
	if (abs(hz - 0.55) < 0.035) {
		col = h2;
	}
	float edge = fv + (fine - 0.5) * 0.1;
	if (edge < 0.22) {
		col = ink;
	}
	if (fade < 0.99 && keep < cut + 0.035) {
		col = ink;
	}
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + max(heat - 0.6, 0.0) * 0.8);
}
"""

## Kameraya dönük dörtgen (ölçek korunur): parlama, duman topağı
const BILL_VERTEX := """
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
"""

## Ani çekirdek parlaması: beyaz merkez, sivri yıldız kenarı (spikes), dışta yumuşak hale. warm 0 sarı, 1 şeftali kenar.
const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float near = 6.0;
instance uniform float spikes = 9.0;
instance uniform float warm = 0.0;

BNOISE
BILL_VERTEX

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float sp = pow(abs(cos(a * spikes * 0.5 + seed * 3.0)), 6.0);
	float jag = bn(vec2(a * 4.0 + seed * 7.0, TIME * 4.0 + seed));
	float R = 0.4 + 0.52 * sp * (0.5 + 0.5 * jag) + (jag - 0.5) * 0.06;
	float core = 0.3 + 0.08 * jag;
	vec3 rim = mix(vec3(1.0, 0.93, 0.56), vec3(1.0, 0.72, 0.52), warm);
	vec3 col = rim;
	float al = 0.0;
	if (r < R) {
		al = 1.0;
		col = r < core ? vec3(1.0, 1.0, 0.98) : (r < R * 0.8 ? mix(vec3(1.0, 0.99, 0.9), rim, 0.35) : rim);
	} else {
		al = (1.0 - smoothstep(R, 1.0, r)) * 0.32;
	}
	float vis = smoothstep(near * 0.5, near, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + heat * 0.7);
	ALPHA = al * fade * vis;
}
"""

## Cel duman topağı: beş loblu siluet, üst açık / alt koyu iki ton, koyu kontur; fade düştükçe gürültüyle aşınır.
## gray 0 krem, 1 koyu gri; hot alt tarafta sıcak turuncu yansıma; tone.rgb renk, tone.a karışım (toz / toprak)
const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float near = 5.0;
instance uniform float gray = 0.0;
instance uniform float hot = 0.0;
instance uniform vec4 tone = vec4(0.0, 0.0, 0.0, 0.0);

BNOISE
BILL_VERTEX

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q) - 0.48;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float ang = fi * 1.2566 + seed * 2.3;
		vec2 c = vec2(cos(ang), sin(ang)) * (0.34 + 0.08 * sin(seed * 5.0 + fi * 2.0));
		float rr = 0.36 + 0.1 * cos(seed * 3.0 + fi * 1.7);
		d = min(d, length(q - c) - rr);
	}
	float n = bf(q * 3.0 + vec2(seed * 4.0, TIME * 0.25));
	d += (n - 0.5) * 0.12 + (1.0 - fade) * 0.85 * n;
	if (d > 0.0) {
		discard;
	}
	if (smoothstep(near * 0.5, near, -VERTEX.z) < bdith(FRAGCOORD.xy)) {
		discard;
	}
	vec3 lt = mix(vec3(0.95, 0.93, 0.88), vec3(0.6, 0.58, 0.59), gray);
	vec3 md = mix(vec3(0.77, 0.75, 0.72), vec3(0.44, 0.42, 0.44), gray);
	vec3 ink = mix(vec3(0.36, 0.33, 0.32), vec3(0.22, 0.21, 0.23), gray);
	lt = mix(lt, tone.rgb, tone.a);
	md = mix(md, tone.rgb * 0.75, tone.a);
	float sh = -q.y * 0.9 - q.x * 0.3 + (n - 0.5) * 0.5;
	vec3 col = sh > -0.12 ? lt : md;
	col = mix(col, vec3(1.0, 0.7, 0.4), hot * smoothstep(-0.1, 0.8, q.y));
	if (d > -0.075) {
		col = ink;
	}
	ALBEDO = pow(col, vec3(2.2));
}
"""

## Şok halkası (dörtgen düzleminde): dış kenar ince tırtıklı, iç kenar derin yırtık; beyaz bant + kontur
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float near = 6.0;
instance uniform float w = 0.25;
instance uniform float white = 1.0;

BNOISE

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float j1 = bn(vec2(a * 9.0 + seed * 5.0, seed));
	float j2 = bn(vec2(a * 4.0 - seed * 3.0, seed * 2.0));
	float outer = 0.97 - j1 * 0.05;
	float inner = outer - w * (0.45 + 0.75 * j2);
	if (r > outer || r < inner) {
		discard;
	}
	float n = bn(vec2(a * 14.0, r * 6.0) + vec2(seed));
	if (n < (1.0 - fade) * 1.05) {
		discard;
	}
	if (smoothstep(near * 0.5, near, -VERTEX.z) < bdith(FRAGCOORD.xy)) {
		discard;
	}
	vec3 c0 = mix(vec3(0.82, 0.72, 0.58), vec3(1.0, 0.99, 0.95), white);
	vec3 c1 = mix(vec3(0.62, 0.52, 0.42), vec3(0.86, 0.85, 0.82), white);
	vec3 ink = mix(vec3(0.3, 0.24, 0.2), vec3(0.32, 0.3, 0.3), white);
	float mid = (inner + outer) * 0.5;
	vec3 col = r > mid ? c0 : c1;
	if (r > outer - 0.022 || r < inner + 0.03) {
		col = ink;
	}
	ALBEDO = pow(col, vec3(2.2));
}
"""

## Zeminde kurum: düzensiz kenar, ışınsal yanık çizikleri, merkezde krem kil kalıntısı; cracks > 0 ışınsal yarıklar,
## heat > 0 yarıklarda / merkezde soğuyan kor
const SOOT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float heat = 0.0;
instance uniform float cracks = 0.0;

BNOISE

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float edge = 0.82 + (bn(vec2(a * 3.0 + seed * 4.0, seed)) - 0.5) * 0.3 + (bn(vec2(a * 11.0, seed * 3.0)) - 0.5) * 0.08;
	if (r > edge) {
		discard;
	}
	float streak = bn(vec2(a * 18.0 + seed * 2.0, r * 1.5));
	vec3 soot = vec3(0.11, 0.1, 0.09);
	vec3 col = mix(soot, vec3(0.24, 0.21, 0.18), step(0.62, streak) * smoothstep(0.2, 0.6, r));
	float residue = 1.0 - smoothstep(0.1, 0.24, r + (bn(q * 6.0 + vec2(seed)) - 0.5) * 0.1);
	col = mix(col, vec3(0.86, 0.83, 0.76), residue * 0.85);
	float al = (1.0 - smoothstep(edge - 0.22, edge, r)) * 0.88;
	if (cracks > 0.001) {
		float ca = abs(fract(a / 6.2832 * 9.0 + bn(vec2(r * 3.0, seed)) * 0.35 + seed) - 0.5);
		float cl = 1.0 - smoothstep(0.0, 0.03 * (1.2 - r), ca);
		cl *= step(r, edge * (0.6 + 0.6 * cracks)) * step(0.12, r);
		col = mix(col, vec3(0.05, 0.04, 0.035), cl);
		col = mix(col, vec3(1.0, 0.62, 0.25), cl * heat);
		al = max(al, cl * 0.95);
	}
	col = mix(col, vec3(1.0, 0.7, 0.35), heat * (1.0 - smoothstep(0.0, 0.35, r)) * 0.7);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = al * fade;
}
"""

## Kül / pul / mikro bomba zerresi (GPU parçacık, kameraya dönük, açısı döner): düzensiz loblu pul, koyu kenar.
## Renk + saydamlık parçacığın renk rampasından (COLOR.a düştükçe gürültüyle yenir). ember: kenar koyu yerine kızgın.
const FLAKE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform float ember = 0.0;
varying float sd;

BNOISE

void vertex() {
	sd = float(INSTANCE_ID) * 0.37;
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mw = mw * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float n = bn(q * 2.2 + vec2(sd * 3.1, sd * 1.7));
	float d = length(q * vec2(1.0, 1.4)) - (0.62 + (n - 0.5) * 0.55);
	if (d > 0.0) {
		discard;
	}
	if (bn(q * 4.0 + vec2(sd, -sd)) > COLOR.a + 0.04) {
		discard;
	}
	vec3 c = COLOR.rgb;
	if (d > -0.14) {
		c = mix(c * 0.42, vec3(1.0, 0.55, 0.2), ember);
	} else if (q.y > 0.12 + (n - 0.5) * 0.3) {
		c *= 0.78;
	}
	ALBEDO = pow(c, vec3(2.2)) * (1.0 + ember * step(-0.14, d) * 1.5);
}
"""


# ================================================================== malzemeler
static func _mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("CLAY_INST", CLAY_INST).replace("BNOISE", BNOISE).replace("BPAL", BPAL).replace("BILL_VERTEX", BILL_VERTEX)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


## Kil (gövde + kontur geçişi)
static func clay_mat() -> ShaderMaterial:
	if _cache.has("clay_full"):
		return _cache["clay_full"]
	var m = _mat("clay", CLAY_SHADER)
	m.next_pass = _mat("clay_ol", OUTLINE_SHADER)
	_cache["clay_full"] = m
	return m


static func blast_mat() -> ShaderMaterial:
	return _mat("blast", BLAST_SHADER)


static func flash_mat() -> ShaderMaterial:
	return _mat("flash", FLASH_SHADER)


static func puff_mat() -> ShaderMaterial:
	return _mat("puff", PUFF_SHADER)


static func ring_mat() -> ShaderMaterial:
	return _mat("ring", RING_SHADER)


static func soot_mat() -> ShaderMaterial:
	return _mat("soot", SOOT_SHADER)


static func flake_mat(ember := false) -> ShaderMaterial:
	var key = "flake_e" if ember else "flake"
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = FLAKE_SHADER.replace("BNOISE", BNOISE)
	var m = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("ember", 1.0 if ember else 0.0)
	_cache[key] = m
	return m


## Köşe renkli düz (ışıksız) malzeme: ince koyu parçalar (şok kıymıkları, dikiş)
static func flat_mat() -> StandardMaterial3D:
	if _cache.has("flat"):
		return _cache["flat"]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	_cache["flat"] = m
	return m


static func _spark_mat() -> StandardMaterial3D:
	if _cache.has("spark"):
		return _cache["spark"]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var tx = GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 32
	tx.height = 32
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = tx
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["spark"] = m
	return m


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_cache["quad"] = q
	return _cache["quad"]


static func _sphere() -> SphereMesh:
	if not _cache.has("sph"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 28
		s.rings = 14
		_cache["sph"] = s
	return _cache["sph"]


# ================================================================== temel yardımcılar
static func put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func kill(host: Node, sec: float, n: Node) -> void:
	var wr = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = wr.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Örnek shader parametresini tween'leyen ayarlayıcı (tek geometri)
static func pf(mi: GeometryInstance3D, k: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(k, v)


## Kökün altındaki tüm kil parçalarına örnek parametresi yazar (glow / crack / melt / near / ow)
static func sp(root: Node, key: String, v) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is GeometryInstance3D and (root as GeometryInstance3D).material_override == clay_mat():
		(root as GeometryInstance3D).set_instance_shader_parameter(key, v)
	for ch in root.get_children():
		sp(ch, key, v)


## Kökün tüm kil parçalarında parametreyi a → b süre t içinde değiştirir
static func tp(root: Node3D, key: String, a: float, b: float, t: float) -> Tween:
	var tw = root.create_tween()
	tw.tween_method(func(v: float) -> void:
		sp(root, key, v), a, b, maxf(t, 0.01))
	return tw


## Fitil: patlamadan önce kil içten beyaz-sarı kızarır, yüzeyde çatlak damarları belirir
static func fuse(root: Node3D, t: float, crack_to := 0.6) -> void:
	if not is_instance_valid(root):
		return
	var tw = root.create_tween().set_parallel()
	tw.tween_method(func(v: float) -> void:
		sp(root, "glow", v), 0.0, 1.0, maxf(t, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(v: float) -> void:
		sp(root, "crack", v), 0.0, crack_to, maxf(t, 0.01))


## Yaratık doğuşu: küçücükten s1 ölçeğine esneyerek şişer
static func pop_in(n: Node3D, t: float, s1 := 1.0) -> void:
	if not is_instance_valid(n):
		return
	n.scale = Vector3.ONE * 0.05 * s1
	var tw = n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * s1, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kanat çırpma (pivot Z ekseninde); sx: +1 sağ kanat, -1 sol
static func flap(piv: Node3D, sx: float, amp := 0.5, period := 0.5) -> void:
	piv.rotation.z = -sx * amp * 0.6
	var tw = piv.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(piv, "rotation:z", sx * amp, period * 0.45)
	tw.tween_property(piv, "rotation:z", -sx * amp * 0.6, period * 0.55)


static func _scuttle(piv: Node3D, g: int) -> void:
	var sg = 1.0 if g == 0 else -1.0
	piv.rotation.y = 0.16 * sg
	var tw = piv.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(piv, "rotation:y", -0.16 * sg, 0.09)
	tw.tween_property(piv, "rotation:y", 0.16 * sg, 0.09)


## Kemik eki (kendi kopyası): modelin iskeletine BoneAttachment3D; yoksa null
static func bone(c: Node3D, bone_name: String) -> Node3D:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.skel == null or m.skel.find_bone(bone_name) < 0:
		return null
	var ba = BoneAttachment3D.new()
	ba.bone_name = bone_name
	m.skel.add_child(ba)
	return ba


## Z ekseni n olan dik taban (dörtgen yüzü n'e bakar)
static func axis_basis(n: Vector3) -> Basis:
	var z = n.normalized()
	if z.length() < 0.5:
		z = Vector3.UP
	var rf = Vector3.RIGHT if absf(z.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var y = z.cross(rf).normalized()
	var x = y.cross(z)
	return Basis(x, y, z)


static func look(n: Node3D, dirv: Vector3) -> void:
	if not is_instance_valid(n) or dirv.length() < 0.0001:
		return
	var f = dirv.normalized()
	var sc = n.scale
	n.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT) * Basis.from_scale(sc)


static func floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z), p.z)


static func _sc(arr: Array, s: float) -> Array:
	var out = []
	for v in arr:
		out.append(v * s)
	return out


## Karın tarafı hafif koyu (hacim okunsun): Loft col_fn
static func _belly(_t: float, ang: float, _sd) -> Color:
	return CLAY.lerp(CLAY_SHADE, clampf(-sin(ang), 0.0, 1.0) * 0.7)


## MB'den kil parçası (köşe renkleri korunur)
static func clay_mi(b: MB, near := 1.2) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = b.build()
	mi.material_override = clay_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.set_instance_shader_parameter("near", near)
	return mi


# ================================================================== yaratıklar (-Z ileri)
## C1 kuşu: ince gövde, küçük baş + kısa gaga, kara nokta gözler, parmak tüylü kanatlar (çırpar), yelpaze kuyruk. s=1 ≈ 1.1 m
static func bird(s := 1.0, near := 1.2) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	var pts = [Vector3(0, 0.06, -0.66), Vector3(0, 0.09, -0.56), Vector3(0, 0.11, -0.45), Vector3(0, 0.07, -0.3), Vector3(0, 0.0, -0.1),
		Vector3(0, 0.0, 0.14), Vector3(0, 0.03, 0.34), Vector3(0, 0.05, 0.46)]
	var rad = [Vector2(0.012, 0.01), Vector2(0.045, 0.04), Vector2(0.11, 0.105), Vector2(0.085, 0.085), Vector2(0.16, 0.15),
		Vector2(0.14, 0.13), Vector2(0.07, 0.055), Vector2(0.03, 0.02)]
	Loft.tube(b, _sc(pts, s), _sc(rad, s), CLAY, 16, 3, true, true, _belly)
	for k in 3:
		var a = (k - 1) * 0.38
		var r0 = Vector3(0, 0.05, 0.42)
		var tip = r0 + Vector3(sin(a) * 0.26, 0.02, cos(a) * 0.34)
		Loft.tube(b, _sc([r0, r0.lerp(tip, 0.5), tip], s), _sc([Vector2(0.045, 0.012), Vector2(0.07, 0.013), Vector2(0.028, 0.01)], s), CLAY, 8, 2, true, true, _belly)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.075, 0.14, -0.47) * s, Vector3.ONE * 0.04 * s, EYE, Vector3.ZERO, 10)
	root.add_child(clay_mi(b, near))
	for sx in [-1.0, 1.0]:
		var piv = Node3D.new()
		piv.position = Vector3(sx * 0.09, 0.08, -0.1) * s
		piv.add_child(_bird_wing(s, sx, near))
		root.add_child(piv)
		flap(piv, sx, 0.55, 0.42)
	return root


static func _bird_wing(s: float, sx: float, near: float) -> MeshInstance3D:
	var b = MB.new()
	var m = Vector3(sx, 1, 1)
	var pts = [Vector3(0, 0, 0), Vector3(0.3, 0.05, 0.02), Vector3(0.6, 0.07, 0.08), Vector3(0.86, 0.04, 0.2)]
	Loft.tube(b, _sc([pts[0] * m, pts[1] * m, pts[2] * m, pts[3] * m], s), _sc([Vector2(0.14, 0.04), Vector2(0.17, 0.036), Vector2(0.12, 0.03), Vector2(0.04, 0.015)], s), CLAY, 12, 3, true, true, _belly)
	# arka kenarda ayrık parmak tüyler (anime kuşunun tırtıklı kanat ucu)
	for k in 3:
		var r0 = Vector3(0.4 + k * 0.15, 0.05, 0.1 + k * 0.03) * m
		var tip = r0 + Vector3((0.08 + k * 0.05) * sx, -0.01, 0.2 + k * 0.03)
		Loft.tube(b, _sc([r0, r0.lerp(tip, 0.5), tip], s), _sc([Vector2(0.06, 0.016), Vector2(0.055, 0.014), Vector2(0.02, 0.01)], s), CLAY, 8, 2, true, true, _belly)
	return clay_mi(b, near)


## C1 örümceği: iri karın + küçük baş, iki kara göz, sekiz dirsekli bacak (iki grup sırayla tıpışlar). s=1 ≈ 0.9 m
static func spider(s := 1.0, near := 1.2) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	Loft.tube(b, _sc([Vector3(0, 0.16, -0.36), Vector3(0, 0.17, -0.24), Vector3(0, 0.18, -0.04), Vector3(0, 0.22, 0.18), Vector3(0, 0.2, 0.4), Vector3(0, 0.16, 0.5)], s),
		_sc([Vector2(0.08, 0.07), Vector2(0.12, 0.1), Vector2(0.1, 0.09), Vector2(0.22, 0.19), Vector2(0.2, 0.17), Vector2(0.07, 0.06)], s), CLAY, 16, 3, true, true, _belly)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.045, 0.22, -0.37) * s, Vector3.ONE * 0.035 * s, EYE, Vector3.ZERO, 8)
	root.add_child(clay_mi(b, near))
	for g in 2:
		var lb = MB.new()
		for sx in [-1.0, 1.0]:
			for q in 4:
				if (q + (0 if sx > 0.0 else 1)) % 2 != g:
					continue
				var a = Vector3(sx * 0.09, 0.17, -0.14 + q * 0.09)
				var kn = a + Vector3(sx * 0.2, 0.17, -0.04 + (q - 1.5) * 0.06)
				var f = kn + Vector3(sx * 0.15, -0.33, (q - 1.5) * 0.06)
				Loft.tube(lb, _sc([a, kn, f], s), _sc([Vector2(0.028, 0.028), Vector2(0.024, 0.024), Vector2(0.01, 0.01)], s), CLAY, 7, 3, true, true)
		var piv = Node3D.new()
		piv.position = Vector3(0, 0.17, 0) * s
		var mi = clay_mi(lb, near)
		mi.position = Vector3(0, -0.17, 0) * s
		piv.add_child(mi)
		root.add_child(piv)
		_scuttle(piv, g)
	return root


## C1 böceği (anime "Explosive Clay Bug"): yuvarlak kabuk, üstte çizgi çizgi kabuk dilimleri, kırmızı küçük göz,
## arkada dalgalanan dört yassı şerit, altta kısa ayaklar. s=1 ≈ 0.7 m
static func beetle(s := 1.0, near := 1.2) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(0.62, 0.56, 0.66) * s, CLAY, Vector3.ZERO, 22)
	# kabuk dilim çizgileri (üstte yay yay)
	for k in 3:
		var arc = []
		var rr = []
		var z0 = -0.12 + k * 0.12
		for q in 7:
			var a = (q - 3) * 0.32
			arc.append(Vector3(sin(a) * 0.3, 0.06 + cos(a) * 0.24, z0 + absf(a) * 0.05) * s)
			rr.append(Vector2(0.008, 0.008) * s)
		Loft.tube(b, arc, rr, Color(0.55, 0.53, 0.52), 5, 2, true, true)
	b.add("sphere", Vector3(-0.12, 0.02, -0.3) * s, Vector3(0.06, 0.07, 0.03) * s, Color(0.62, 0.08, 0.06), Vector3.ZERO, 8)
	for sx in [-1.0, 1.0]:
		for q in 2:
			var a0 = Vector3(sx * 0.15, -0.22, -0.08 + q * 0.18)
			Loft.tube(b, _sc([a0, a0 + Vector3(sx * 0.04, -0.07, -0.02)], s), _sc([Vector2(0.03, 0.03), Vector2(0.02, 0.02)], s), CLAY, 6, 2, true, true)
	root.add_child(clay_mi(b, near))
	var tail = Node3D.new()
	tail.position = Vector3(0, 0.05, 0.28) * s
	var tb = MB.new()
	for k in 4:
		var y = 0.1 - k * 0.07
		var r0 = Vector3((k - 1.5) * 0.04, y, 0.0)
		var tip = r0 + Vector3((k - 1.5) * 0.06, -0.02, 0.36)
		Loft.tube(tb, _sc([r0, r0.lerp(tip, 0.5), tip], s), _sc([Vector2(0.035, 0.008), Vector2(0.04, 0.008), Vector2(0.03, 0.006)], s), CLAY, 6, 2, true, true)
	tail.add_child(clay_mi(tb, near))
	root.add_child(tail)
	var tw = tail.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tail, "rotation:x", 0.25, 0.12)
	tw.tween_property(tail, "rotation:x", -0.2, 0.12)
	return root


## C2 güdümlü füze (ejderin ağzından): torpido gövde, küt ejder burnu, kara göz noktaları, ağız çizgisi, iki küt yüzgeç kanat,
## arkada üç boğumlu kısa kuyruk. s=1 ≈ 1.5 m
static func missile(s := 1.0, near := 1.6) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	Loft.tube(b, _sc([Vector3(0, -0.02, -0.78), Vector3(0, 0.0, -0.66), Vector3(0, 0.04, -0.46), Vector3(0, 0.03, -0.2), Vector3(0, 0.0, 0.12), Vector3(0, 0.0, 0.36)], s),
		_sc([Vector2(0.07, 0.05), Vector2(0.13, 0.1), Vector2(0.2, 0.18), Vector2(0.18, 0.17), Vector2(0.15, 0.14), Vector2(0.08, 0.08)], s), CLAY, 16, 3, true, true, _belly)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.13, 0.11, -0.46) * s, Vector3(0.05, 0.06, 0.04) * s, EYE, Vector3.ZERO, 8)
		b.add("sphere", Vector3(sx * 0.035, 0.05, -0.74) * s, Vector3.ONE * 0.025 * s, EYE, Vector3.ZERO, 6)
		# küt yüzgeç kanat
		var w0 = Vector3(sx * 0.14, 0.04, -0.12)
		Loft.tube(b, _sc([w0, w0 + Vector3(sx * 0.2, 0.04, 0.1), w0 + Vector3(sx * 0.36, 0.02, 0.24)], s), _sc([Vector2(0.1, 0.025), Vector2(0.09, 0.02), Vector2(0.03, 0.012)], s), CLAY, 8, 2, true, true, _belly)
	# ağız çizgisi
	var ml = []
	var mr = []
	for q in 5:
		var a = (q - 2) * 0.5
		ml.append(Vector3(sin(a) * 0.12, -0.05 - absf(a) * 0.02, -0.62 + absf(a) * 0.07) * s)
		mr.append(Vector2(0.012, 0.012) * s)
	Loft.tube(b, ml, mr, EYE, 5, 2, true, true)
	for k in 3:
		b.add("sphere", Vector3(0, 0.0, 0.44 + k * 0.11) * s, Vector3(0.13 - k * 0.03, 0.13 - k * 0.03, 0.11) * s, CLAY, Vector3.ZERO, 12)
	root.add_child(clay_mi(b, near))
	return root


## C2 ejderi (anime): şişkin gövde, aşağı kavisli kalın boyun, küt kutu burunlu baş (iki burun deliği, yanda kara göz,
## dudak boyunca kare dişler), baş ve boyunda kesik boynuz kütükleri, insan elli dört bacak, yumrulu geniş kanatlar
## (+ küçük arka çift), boğum boğum uzun kuyruk. s=1 ≈ 8 m (burun -Z ≈ -4.5)
static func dragon(s := 1.0, near := 8.0) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	var pts = [Vector3(0, 0.6, -2.7), Vector3(0, 0.5, -2.2), Vector3(0, 0.22, -1.5), Vector3(0, 0.0, -0.75), Vector3(0, -0.05, 0.15), Vector3(0, 0.0, 1.0), Vector3(0, 0.05, 1.65)]
	var rad = [Vector2(0.42, 0.4), Vector2(0.4, 0.38), Vector2(0.66, 0.6), Vector2(1.0, 0.86), Vector2(1.1, 0.94), Vector2(0.95, 0.8), Vector2(0.6, 0.54)]
	Loft.tube(b, _sc(pts, s), _sc(rad, s), CLAY, 24, 4, true, true, _belly)
	# boyun boyunca çift kütük
	for k in 3:
		var p: Vector3 = (pts[1] as Vector3).lerp(pts[3], k / 2.0)
		var rr: Vector2 = (rad[1] as Vector2).lerp(rad[3], k / 2.0)
		for sx in [-1.0, 1.0]:
			b.add("cyl", (p + Vector3(sx * rr.x * 0.45, rr.y * 0.92, 0)) * s, Vector3(0.16, 0.34, 0.16) * s, CLAY, Vector3(-25, 0, sx * -12), 10)
	# bacaklar: aşağı sarkan kalın kol + dört parmaklı el
	for lz in [-0.85, 0.95]:
		for sx in [-1.0, 1.0]:
			var a0 = Vector3(sx * 0.78, -0.35, lz)
			var kn = a0 + Vector3(sx * 0.12, -0.55, -0.12)
			var hd = kn + Vector3(sx * 0.02, -0.5, 0.05)
			Loft.tube(b, _sc([a0, kn, hd], s), _sc([Vector2(0.3, 0.3), Vector2(0.24, 0.24), Vector2(0.26, 0.22)], s), CLAY, 12, 3, true, true, _belly)
			for f in 4:
				var fa = (f - 1.5) * 0.35
				var f0 = hd + Vector3(sin(fa) * 0.14, -0.08, -cos(fa) * 0.1)
				var f1 = f0 + Vector3(sin(fa) * 0.12, -0.22, -cos(fa) * 0.08)
				Loft.tube(b, _sc([f0, f1], s), _sc([Vector2(0.07, 0.07), Vector2(0.055, 0.055)], s), CLAY, 7, 2, true, true)
	root.add_child(clay_mi(b, near))
	# baş (ayrı pivot: tükürürken öne eğilir)
	var head = Node3D.new()
	head.position = Vector3(0, 0.6, -2.7) * s
	var hb = MB.new()
	Loft.tube(hb, _sc([Vector3(0, 0.15, 0.25), Vector3(0, 0.16, -0.2), Vector3(0, 0.05, -0.62), Vector3(0, -0.08, -1.02), Vector3(0, -0.2, -1.38), Vector3(0, -0.27, -1.52)], s),
		_sc([Vector2(0.5, 0.42), Vector2(0.55, 0.46), Vector2(0.48, 0.36), Vector2(0.42, 0.3), Vector2(0.33, 0.23), Vector2(0.18, 0.13)], s), CLAY, 22, 3, true, true, _belly)
	Loft.tube(hb, _sc([Vector3(0, -0.3, -1.46), Vector3(0, -0.48, -1.55), Vector3(0, -0.68, -1.58)], s), _sc([Vector2(0.15, 0.12), Vector2(0.1, 0.08), Vector2(0.03, 0.03)], s), CLAY, 10, 3, true, true, _belly)
	for sx in [-1.0, 1.0]:
		# göz: kil kenarlı kara çukur
		hb.add("torus", Vector3(sx * 0.4, 0.1, -0.42) * s, Vector3(0.32, 0.32, 0.32) * s, CLAY_SHADE, Vector3(0, 0, 90), 16)
		hb.add("sphere", Vector3(sx * 0.42, 0.1, -0.42) * s, Vector3(0.1, 0.24, 0.24) * s, EYE, Vector3.ZERO, 12)
		hb.add("sphere", Vector3(sx * 0.11, 0.02, -1.3) * s, Vector3(0.09, 0.05, 0.09) * s, EYE, Vector3.ZERO, 8)
		# başta kesik boynuz kütükleri
		for k in 2:
			hb.add("cyl", Vector3(sx * (0.24 - k * 0.04), 0.52 - k * 0.04, 0.05 + k * 0.26) * s, Vector3(0.17, 0.36, 0.17) * s, CLAY, Vector3(-30, 0, sx * -15), 10)
		# dudak çizgisi + sarkan kare dişler
		var ml = []
		var mr = []
		for q in 6:
			var z = -0.35 - q * 0.2
			ml.append(Vector3(sx * (0.42 - q * 0.035), -0.2 - q * 0.02, z) * s)
			mr.append(Vector2(0.022, 0.022) * s)
		Loft.tube(hb, ml, mr, EYE, 5, 2, true, true)
		for q in 5:
			var z = -0.42 - q * 0.2
			hb.add("box", Vector3(sx * (0.4 - q * 0.035), -0.27 - q * 0.02, z) * s, Vector3(0.05, 0.12, 0.11) * s, CLAY_SHADE, Vector3.ZERO)
	head.add_child(clay_mi(hb, near))
	var mouth = Node3D.new()
	mouth.position = Vector3(0, -0.5, -1.6) * s
	head.add_child(mouth)
	root.add_child(head)
	root.set_meta("head", head)
	root.set_meta("mouth", mouth)
	# kanatlar: ön kenarda yumrular, arka kenarda yuvarlak loblar; yavaş süzülme çırpışı
	for pair in 2:
		var ws = 1.0 if pair == 0 else 0.5
		for sx in [-1.0, 1.0]:
			var piv = Node3D.new()
			piv.position = (Vector3(sx * 0.7, 0.75, -0.55) if pair == 0 else Vector3(sx * 0.6, 0.6, 0.75)) * s
			piv.add_child(_dragon_wing(s * ws, sx, near))
			root.add_child(piv)
			flap(piv, sx, 0.26, 1.6 + pair * 0.3)
	# boğumlu kuyruk (ayrı pivot: yavaş sallanır)
	var tail = Node3D.new()
	tail.position = Vector3(0, 0.05, 1.65) * s
	var tb = MB.new()
	for i in 13:
		var u = i / 12.0
		var r = lerpf(0.56, 0.16, u)
		var pz = 0.25 + i * 0.42 * (1.0 - u * 0.3)
		var px = sin(u * 3.6) * 0.9 * u
		var py = -u * 0.9 + sin(u * 2.0) * 0.2
		tb.add("sphere", Vector3(px, py, pz) * s, Vector3(r * 2.0, r * 1.9, r * 1.55) * s, CLAY, Vector3(0, rad_to_deg(px * 0.5), 0), 14)
	tail.add_child(clay_mi(tb, near))
	root.add_child(tail)
	var tw = tail.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tail, "rotation:y", 0.22, 1.3)
	tw.tween_property(tail, "rotation:y", -0.22, 1.3)
	return root


static func _dragon_wing(s: float, sx: float, near: float) -> MeshInstance3D:
	var b = MB.new()
	var m = Vector3(sx, 1, 1)
	var pts = [Vector3(0, 0, 0), Vector3(1.1, 0.28, 0.25), Vector3(2.4, 0.38, 0.55), Vector3(3.6, 0.22, 1.05)]
	Loft.tube(b, _sc([pts[0] * m, pts[1] * m, pts[2] * m, pts[3] * m], s), _sc([Vector2(0.55, 0.13), Vector2(0.72, 0.12), Vector2(0.55, 0.1), Vector2(0.1, 0.05)], s), CLAY, 14, 3, true, true, _belly)
	for k in 5:
		var u = (k + 0.5) / 5.0
		var p = (pts[0] as Vector3).lerp(pts[3], u) * m + Vector3(0, 0.12 + sin(u * PI) * 0.22, -0.32 - u * 0.1)
		b.add("sphere", p * s, Vector3(0.24, 0.2, 0.22) * s, CLAY, Vector3.ZERO, 10)
	for k in 3:
		var u = 0.25 + k * 0.25
		var r0 = (pts[0] as Vector3).lerp(pts[3], u) * m + Vector3(0, 0.0, 0.35)
		var tip = r0 + Vector3(sx * 0.12, -0.04, 0.55 - k * 0.08)
		Loft.tube(b, _sc([r0, r0.lerp(tip, 0.5), tip], s), _sc([Vector2(0.22, 0.06), Vector2(0.24, 0.055), Vector2(0.12, 0.04)], s), CLAY, 10, 2, true, true, _belly)
	return clay_mi(b, near)


## C3 küçük formu (anime): damla gövde (tepesi geriye sivrilen başlık), yuvarlak yüzde iki kara göz ve büyük "O" ağız,
## karnını saran iki kol, karnın üstünde açık parmaklı el, minik ayaklar. s=1 ≈ 1.75 m
static func c3_doll(s := 1.0, near := 6.0) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	Loft.tube(b, _sc([Vector3(0, 0.06, 0), Vector3(0, 0.36, 0), Vector3(0, 0.76, 0), Vector3(0, 1.1, 0.0), Vector3(0, 1.4, 0.03), Vector3(0, 1.62, 0.08), Vector3(0, 1.74, 0.14)], s),
		_sc([Vector2(0.32, 0.28), Vector2(0.46, 0.4), Vector2(0.48, 0.42), Vector2(0.4, 0.36), Vector2(0.3, 0.27), Vector2(0.14, 0.12), Vector2(0.03, 0.03)], s), CLAY, 22, 3, true, true, Callable(), Vector3.FORWARD)
	# yüz: hafif kabarık açık oval, iki göz, büyük O ağız (kara iç + kil dudak halkası)
	b.add("sphere", Vector3(0, 1.12, -0.24) * s, Vector3(0.44, 0.5, 0.26) * s, CLAY, Vector3.ZERO, 16)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.09, 1.24, -0.36) * s, Vector3(0.05, 0.06, 0.03) * s, EYE, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0, 1.03, -0.36) * s, Vector3(0.11, 0.18, 0.05) * s, GUM, Vector3.ZERO, 12)
	b.add("torus", Vector3(0, 1.03, -0.355) * s, Vector3(0.15, 0.24, 0.15) * s, CLAY_SHADE, Vector3(90, 0, 0), 14)
	# kollar: omuzdan karnın önüne sarılır, sağ el karında açık parmaklı
	for sx in [-1.0, 1.0]:
		var sh = Vector3(sx * 0.4, 0.98, 0.0)
		var el = Vector3(sx * 0.5, 0.68, -0.22)
		var wr = Vector3(-sx * 0.05, 0.6, -0.44)
		Loft.tube(b, _sc([sh, el, wr], s), _sc([Vector2(0.09, 0.09), Vector2(0.08, 0.08), Vector2(0.07, 0.065)], s), CLAY, 10, 3, true, true, _belly)
		if sx > 0.0:
			for f in 5:
				var fa = (f - 2.0) * 0.4
				var f0 = wr + Vector3(-0.04, 0.0, -0.02)
				var f1 = f0 + Vector3(-cos(fa) * 0.14, sin(fa) * 0.14, -0.02)
				Loft.tube(b, _sc([f0, f1], s), _sc([Vector2(0.03, 0.025), Vector2(0.024, 0.02)], s), CLAY, 6, 2, true, true)
		b.add("sphere", Vector3(sx * 0.16, 0.03, -0.14) * s, Vector3(0.18, 0.1, 0.24) * s, CLAY, Vector3.ZERO, 10)
	root.add_child(clay_mi(b, near))
	return root


## C4 için dev kil kopya: armut biçimli şişkin gövde, yuvarlak baş + tepede at kuyruğu tutamı + bir gözü örten perçem,
## kalın kollar ve eldiven eller (avuçlarında ağız), kısa bacaklar. s = boy (m)
static func giant(s := 9.0, near := 7.0) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	Loft.tube(b, _sc([Vector3(0, 0.16, 0), Vector3(0, 0.32, 0), Vector3(0, 0.52, 0), Vector3(0, 0.7, 0), Vector3(0, 0.79, 0)], s),
		_sc([Vector2(0.22, 0.2), Vector2(0.36, 0.33), Vector2(0.38, 0.35), Vector2(0.26, 0.24), Vector2(0.11, 0.1)], s), CLAY, 24, 3, true, true, Callable(), Vector3.FORWARD)
	b.add("sphere", Vector3(0, 0.88, 0) * s, Vector3(0.24, 0.25, 0.24) * s, CLAY, Vector3.ZERO, 18)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.05, 0.9, -0.11) * s, Vector3(0.025, 0.03, 0.015) * s, EYE, Vector3.ZERO, 8)
	Loft.tube(b, _sc([Vector3(-0.05, 0.83, -0.115), Vector3(0.0, 0.825, -0.12), Vector3(0.05, 0.83, -0.115)], s), _sc([Vector2(0.006, 0.006), Vector2(0.006, 0.006), Vector2(0.006, 0.006)], s), EYE, 5, 2, true, true)
	# perçem (bir gözü örter) + tepede at kuyruğu tutamı
	Loft.tube(b, _sc([Vector3(0.02, 1.0, -0.06), Vector3(0.06, 0.95, -0.12), Vector3(0.07, 0.86, -0.13)], s), _sc([Vector2(0.06, 0.02), Vector2(0.05, 0.02), Vector2(0.02, 0.01)], s), CLAY_SHADE, 8, 2, true, true)
	Loft.tube(b, _sc([Vector3(0, 0.99, 0.05), Vector3(0, 1.06, 0.1), Vector3(0, 1.02, 0.2), Vector3(0, 0.92, 0.24)], s), _sc([Vector2(0.04, 0.04), Vector2(0.05, 0.05), Vector2(0.035, 0.035), Vector2(0.01, 0.01)], s), CLAY_SHADE, 8, 3, true, true)
	var hands = []
	for sx in [-1.0, 1.0]:
		var sh = Vector3(sx * 0.3, 0.66, 0)
		var el = Vector3(sx * 0.44, 0.48, -0.04)
		var hd = Vector3(sx * 0.42, 0.32, -0.12)
		Loft.tube(b, _sc([sh, el, hd], s), _sc([Vector2(0.09, 0.09), Vector2(0.08, 0.08), Vector2(0.07, 0.07)], s), CLAY, 12, 3, true, true, _belly)
		b.add("sphere", hd * s, Vector3(0.14, 0.11, 0.12) * s, CLAY, Vector3.ZERO, 12)
		b.add("sphere", (hd + Vector3(-sx * 0.05, 0.0, -0.03)) * s, Vector3(0.05, 0.02, 0.03) * s, GUM, Vector3(0, 0, 90), 8)
		var lg = Vector3(sx * 0.13, 0.18, 0)
		Loft.tube(b, _sc([lg, lg + Vector3(sx * 0.02, -0.1, 0), lg + Vector3(sx * 0.02, -0.18, -0.03)], s), _sc([Vector2(0.11, 0.11), Vector2(0.1, 0.1), Vector2(0.1, 0.08)], s), CLAY, 12, 3, true, true, _belly)
		var hn = Node3D.new()
		hn.position = hd * s
		root.add_child(hn)
		hands.append(hn)
	root.add_child(clay_mi(b, near))
	root.set_meta("hands", hands)
	return root


## Kil mayın (C2 mayınları): yuvarlak top, önde iki kara göz deliği + ağız noktası, gövdede dalgalı dikiş. s = çap
static func mine(s := 1.0, near := 1.5) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.94, 1.0) * s, CLAY, Vector3.ZERO, 18)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.16, 0.08, -0.44) * s, Vector3(0.11, 0.13, 0.06) * s, EYE, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0, -0.14, -0.46) * s, Vector3(0.07, 0.05, 0.04) * s, EYE, Vector3.ZERO, 6)
	var wv = []
	var wr = []
	for q in 15:
		var a = q / 14.0 * PI * 1.2 - 0.2
		wv.append(Vector3(cos(a) * 0.5, sin(q * 1.3) * 0.05 + 0.18, sin(a) * 0.5 + 0.02) * s)
		wr.append(Vector2(0.01, 0.01) * s)
	Loft.tube(b, wv, wr, Color(0.55, 0.53, 0.52), 5, 2, true, true)
	root.add_child(clay_mi(b, near))
	return root


## Çiğnenmiş kil topağı (avuçta / ağızda): basık, parmak çukurlu. s = çap
static func lump(s := 0.1, near := 0.4) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.8, 0.9) * s, CLAY, Vector3(0, 0, 12), 12)
	b.add("sphere", Vector3(0.3, 0.12, 0.1) * s, Vector3(0.55, 0.45, 0.5) * s, CLAY, Vector3.ZERO, 8)
	b.add("sphere", Vector3(-0.28, -0.1, -0.12) * s, Vector3(0.5, 0.4, 0.45) * s, CLAY, Vector3.ZERO, 8)
	root.add_child(clay_mi(b, near))
	return root


## Patlayıcı chakra yüklü kaya: düzensiz taş, çatlaklarında içten parlayan damarlar (crack). s = çap
static func stone(s := 0.6, near := 1.5, charged := true) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	b.add("boulder", Vector3.ZERO, Vector3(s, s * 0.8, s), STONE, Vector3(randf() * 360.0, randf() * 360.0, 0.0), randi_range(1, 6))
	var mi = clay_mi(b, near)
	if charged:
		mi.set_instance_shader_parameter("crack", 0.75)
		mi.set_instance_shader_parameter("glow", 0.15)
	root.add_child(mi)
	return root


# ================================================================== ağızlar
## Avuç ağzı: elin içinde dudaklar açılıp kapanır (çiğneme), dişler ve dil görünür, dudaklar arasında kil topağı büyür.
## dur sonunda kendi silinir. Dönen düğüm kemiğe iliştirilmiştir (kemik yoksa null).
static func palm_mouth(host: Node, c: Node3D, right := true, dur := 0.8, lump_s := 0.045) -> Node3D:
	var ba = bone(c, "RightHand" if right else "LeftHand")
	if ba == null:
		return null
	var m = Node3D.new()
	ba.add_child(m)
	# insansı iskelette avuç içi kemiğin yerel -X (sağ) / +X (sol) yanında
	var sx = 1.0 if right else -1.0
	m.position = Vector3(-sx * 0.03, 0.075, 0.0)
	m.basis = Basis(Vector3.UP, -sx * PI * 0.5)
	var ib = MB.new()
	ib.add("sphere", Vector3.ZERO, Vector3(0.05, 0.026, 0.016), GUM, Vector3.ZERO, 10)
	m.add_child(clay_mi(ib, 0.2))
	var up = Node3D.new()
	var lo = Node3D.new()
	m.add_child(up)
	m.add_child(lo)
	var ub = MB.new()
	Loft.tube(ub, [Vector3(-0.028, 0.0, 0.004), Vector3(0.0, 0.009, 0.009), Vector3(0.028, 0.0, 0.004)], [Vector2(0.006, 0.006), Vector2(0.007, 0.007), Vector2(0.006, 0.006)], LIP, 6, 3, true, true)
	for k in 4:
		ub.add("box", Vector3(-0.012 + k * 0.008, 0.002, 0.008), Vector3(0.006, 0.006, 0.003), TOOTH, Vector3.ZERO)
	up.add_child(clay_mi(ub, 0.2))
	var lb = MB.new()
	Loft.tube(lb, [Vector3(-0.028, 0.0, 0.004), Vector3(0.0, -0.009, 0.009), Vector3(0.028, 0.0, 0.004)], [Vector2(0.006, 0.006), Vector2(0.007, 0.007), Vector2(0.006, 0.006)], LIP, 6, 3, true, true)
	lb.add("sphere", Vector3(0.0, -0.003, 0.006), Vector3(0.028, 0.008, 0.02), TONGUE, Vector3.ZERO, 8)
	lo.add_child(clay_mi(lb, 0.2))
	var lmp = lump(lump_s, 0.2)
	lmp.position = Vector3(0, 0, 0.012)
	lmp.scale = Vector3.ONE * 0.1
	m.add_child(lmp)
	var tw = m.create_tween().set_loops(maxi(1, int(dur / 0.2)))
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(up, "position:y", 0.007, 0.1)
	tw.parallel().tween_property(lo, "position:y", -0.007, 0.1)
	tw.tween_property(up, "position:y", 0.0, 0.1)
	tw.parallel().tween_property(lo, "position:y", 0.0, 0.1)
	var tl = lmp.create_tween()
	tl.tween_property(lmp, "scale", Vector3.ONE, dur * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kill(host, dur, ba)
	return m


## Göğüs ağzı (C0): koyu yıldız lekesi üstünde dikişli dudaklar; dikişler kopar, dudaklar dur boyunca aralanır, dişler görünür.
## Bedenin önünde her kare yeniden konumlanır; s boy çarpanı. dur sonunda silinir.
static func chest_mouth(host: Node, c: Node3D, dur := 1.4, s := 1.0) -> Node3D:
	var m = Node3D.new()
	var st = MB.new()
	for k in 10:
		var a = k * TAU / 10.0 + 0.2
		var ln = 0.13 + 0.07 * float(k % 2)
		st.add("prism", Vector3(cos(a) * ln * 0.55, sin(a) * ln * 0.55, -0.005) * s, Vector3(0.05, ln, 0.005) * s, Color(0.2, 0.15, 0.13), Vector3(0, 0, rad_to_deg(a) - 90.0))
	st.add("sphere", Vector3(0, 0, -0.004) * s, Vector3(0.2, 0.17, 0.01) * s, Color(0.2, 0.15, 0.13), Vector3.ZERO, 12)
	var star = gi(st.build(), flat_mat())
	m.add_child(star)
	var ib = MB.new()
	ib.add("sphere", Vector3(0, 0, 0.005) * s, Vector3(0.15, 0.06, 0.02) * s, GUM, Vector3.ZERO, 10)
	m.add_child(clay_mi(ib, 0.3))
	var up = Node3D.new()
	var lo = Node3D.new()
	m.add_child(up)
	m.add_child(lo)
	for pair in 2:
		var sg = 1.0 if pair == 0 else -1.0
		var lbm = MB.new()
		Loft.tube(lbm, _sc([Vector3(-0.09, 0.0, 0.012), Vector3(0.0, 0.016 * sg, 0.02), Vector3(0.09, 0.0, 0.012)], s), _sc([Vector2(0.014, 0.014), Vector2(0.018, 0.018), Vector2(0.014, 0.014)], s), LIP, 6, 3, true, true)
		for k in 6:
			lbm.add("box", Vector3(-0.05 + k * 0.02, 0.007 * sg, 0.018) * s, Vector3(0.015, 0.015, 0.006) * s, TOOTH, Vector3.ZERO)
		(up if pair == 0 else lo).add_child(clay_mi(lbm, 0.3))
	# dikişler: dudakları bağlayan kara iplikler (ağız açılırken kopar)
	var sb = MB.new()
	for k in 5:
		sb.add("box", Vector3(-0.06 + k * 0.03, 0.0, 0.034) * s, Vector3(0.006, 0.05, 0.004) * s, STITCH, Vector3(0, 0, 8.0 * (k - 2)))
	var stitches = gi(sb.build(), flat_mat())
	m.add_child(stitches)
	host.get_tree().current_scene.add_child(m)
	var follow = func(u: float) -> void:
		if not is_instance_valid(m) or not is_instance_valid(c):
			return
		var fd: Vector3 = c.face_dir()
		var hs = 1.0
		var md = c.get("model")
		if md and is_instance_valid(md):
			hs = (md as Node3D).scale.y
		m.global_position = c.global_position + Vector3.UP * 1.3 * hs + fd * 0.3 * hs
		m.global_basis = Basis.looking_at(-fd, Vector3.UP) * Basis.from_scale(Vector3.ONE * hs)
		var op = clampf((u - 0.25) / 0.6, 0.0, 1.0)
		up.position.y = 0.035 * op * s
		lo.position.y = -0.035 * op * s
		if is_instance_valid(stitches):
			stitches.visible = op < 0.3
	follow.call(0.0)
	var tw = m.create_tween()
	tw.tween_method(follow, 0.0, 1.0, dur)
	tw.tween_callback(m.queue_free)
	return m


# ================================================================== patlama parçaları
## Kalıcı küçük parlak çekirdek (iliştirmek için): sivri kenarlı beyaz-sarı ışık topu. size = çap
static func orb_mi(size: float, warm := 0.0, spikes := 6.0) -> MeshInstance3D:
	var mi = gi(_quad(), flash_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("spikes", spikes)
	mi.set_instance_shader_parameter("warm", warm)
	mi.set_instance_shader_parameter("near", 0.6)
	mi.set_instance_shader_parameter("heat", 1.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.scale = Vector3.ONE * size
	return mi


## Ani çekirdek parlaması: hızla açılır, sonra küçülerek söner. o: spikes (9), warm (0), near (6), stretch (Vector2)
static func flash(host: Node, p: Vector3, size: float, life: float, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), flash_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("spikes", float(o.get("spikes", 9.0)))
	mi.set_instance_shader_parameter("warm", float(o.get("warm", 0.0)))
	mi.set_instance_shader_parameter("near", float(o.get("near", 6.0)))
	mi.set_instance_shader_parameter("heat", 1.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	var st: Vector2 = o.get("stretch", Vector2.ONE)
	var full = Vector3(st.x, st.y, 1.0) * minf(size, MAX_R * 2.0)
	put(host, mi, p)
	mi.scale = full * 0.3
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", full, life * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", full * 0.55, life * 0.6).set_delay(life * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(pf(mi, "heat"), 1.0, 0.2, life)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.55).set_delay(life * 0.45)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kabaran patlama topu r0 → r1 (MAX_R ile sınırlı). Sıcak başlar, soğuyup cel dumana döner, yükselir, yenilerek söner.
## o: pal, near (7), lump (1), heat (1.0 başlangıç), rise (m/sn), vel (Vector3), squash (Vector3 yerel ölçek), dir (squash ekseni z),
##    grow (büyüme süresinin ömre oranı 0.35), cool (soğuma süresi oranı 0.7)
static func fireball(host: Node, p: Vector3, r0: float, r1: float, life: float, o := {}) -> MeshInstance3D:
	var mi = gi(_sphere(), blast_mat())
	var heat0 = float(o.get("heat", 1.0))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat0)
	mi.set_instance_shader_parameter("pal", float(o.get("pal", PAL_CLAY)))
	mi.set_instance_shader_parameter("near", float(o.get("near", 7.0)))
	mi.set_instance_shader_parameter("lump", float(o.get("lump", 1.0)))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.extra_cull_margin = 2.0
	var ra = minf(r0, MAX_R)
	var rb = minf(r1, MAX_R)
	var sq: Vector3 = o.get("squash", Vector3.ONE)
	var bas = axis_basis(o["dir"]) if o.has("dir") else Basis.IDENTITY
	put(host, mi, p)
	mi.basis = bas * Basis.from_scale(sq * ra)
	var vel: Vector3 = o.get("vel", Vector3.ZERO) + Vector3.UP * float(o.get("rise", 0.8))
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(func(r: float) -> void:
		if is_instance_valid(mi):
			mi.basis = bas * Basis.from_scale(sq * r), ra, rb, life * float(o.get("grow", 0.35))).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "heat"), heat0, 0.0, life * float(o.get("cool", 0.7))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.45).set_delay(life * 0.55)
	if vel.length() > 0.001:
		tw.tween_property(mi, "global_position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Cel duman topağı: r → r*grow, vel ile süzülür, aşınarak söner. o: gray (0), hot (0), near (5), grow (1.6), tone (Color, a = karışım)
static func puff(host: Node, p: Vector3, r: float, life: float, vel := Vector3.ZERO, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), puff_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("gray", float(o.get("gray", 0.0)))
	mi.set_instance_shader_parameter("hot", float(o.get("hot", 0.0)))
	mi.set_instance_shader_parameter("near", float(o.get("near", 5.0)))
	mi.set_instance_shader_parameter("fade", 1.0)
	var tn: Color = o.get("tone", Color(0, 0, 0, 0))
	mi.set_instance_shader_parameter("tone", tn)
	var d0 = minf(r, MAX_R * 0.5) * 2.0
	put(host, mi, p)
	mi.scale = Vector3.ONE * d0 * 0.5
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * d0 * float(o.get("grow", 1.6)), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "hot"), float(o.get("hot", 0.0)), 0.0, life * 0.5)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.6).set_delay(life * 0.4)
	if vel.length() > 0.001:
		tw.tween_property(mi, "global_position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Şok halkası: nrm'e dik düzlemde r0 → r1 genişler, bant incelir, söner. o: w (0.25), white (1), near (6)
static func ring(host: Node, p: Vector3, r0: float, r1: float, life: float, nrm := Vector3.UP, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), ring_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("w", float(o.get("w", 0.25)))
	mi.set_instance_shader_parameter("white", float(o.get("white", 1.0)))
	mi.set_instance_shader_parameter("near", float(o.get("near", 6.0)))
	mi.set_instance_shader_parameter("fade", 1.0)
	var bas = axis_basis(nrm)
	var ra = minf(r0, MAX_R * 2.0)
	var rb = minf(r1, MAX_R * 2.0)
	put(host, mi, p)
	mi.basis = bas * Basis.from_scale(Vector3(ra * 2.0, ra * 2.0, 1.0))
	var w0 = float(o.get("w", 0.25))
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(func(r: float) -> void:
		if is_instance_valid(mi):
			mi.basis = bas * Basis.from_scale(Vector3(r * 2.0, r * 2.0, 1.0)), ra, rb, life * 0.75).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(pf(mi, "w"), w0, w0 * 0.3, life)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Zeminde kurum / yanık izi. o: heat (soğuyan kor 0..1), cracks (0..1 ışınsal yarık), grow (0.25 sn)
static func soot(host: Node, p: Vector3, r: float, life: float, o := {}) -> MeshInstance3D:
	var mi = gi(_quad(), soot_mat())
	var h0 = float(o.get("heat", 0.0))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", h0)
	mi.set_instance_shader_parameter("cracks", float(o.get("cracks", 0.0)))
	mi.set_instance_shader_parameter("fade", 1.0)
	var bas = axis_basis(Vector3.UP).rotated(Vector3.UP, randf() * TAU)
	var rr = minf(r, 24.0)
	put(host, mi, floor_at(p) + Vector3.UP * 0.05)
	mi.basis = bas * Basis.from_scale(Vector3(rr * 0.8, rr * 0.8, 1.0))
	var tw = mi.create_tween().set_parallel()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(mi):
			mi.basis = bas * Basis.from_scale(Vector3(v * 2.0, v * 2.0, 1.0)), rr * 0.4, rr, float(o.get("grow", 0.25))).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if h0 > 0.0:
		tw.tween_method(pf(mi, "heat"), h0, 0.0, life * 0.5)
	tw.tween_method(pf(mi, "fade"), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Fırlayan katı parça: yerçekimiyle düşer, döner, yere değince durur, küçülerek söner
static func toss(host: Node, n: Node3D, p0: Vector3, v: Vector3, life: float, g := 18.0) -> void:
	put(host, n, p0)
	var spin = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	var stt = {"land": false}
	var tw = n.create_tween()
	tw.tween_method(func(tm: float) -> void:
		if not is_instance_valid(n) or stt["land"]:
			return
		var pos = p0 + v * tm + Vector3.DOWN * 0.5 * g * tm * tm
		var fy = Game.jutsu_floor(pos.x, pos.z) + 0.04
		if pos.y < fy and tm > 0.05:
			pos.y = fy
			stt["land"] = true
		n.global_position = pos
		n.rotation = spin * tm, 0.0, life, life)
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(n.queue_free)


## Kil / taş kıymığı (savrulan parça): düzensiz, birkaç primitiften
static func chip(s: float, col := CLAY, near := 1.0) -> MeshInstance3D:
	var b = MB.new()
	var kind = ["prism", "box", "sphere"][randi() % 3]
	b.add(kind, Vector3.ZERO, Vector3(s, s * randf_range(0.4, 0.9), s * randf_range(0.5, 1.1)), col, Vector3(randf() * 360.0, randf() * 360.0, 0.0), 6)
	if randf() < 0.5:
		b.add("sphere", Vector3(s * 0.3, 0.0, 0.0), Vector3.ONE * s * 0.6, col.darkened(0.08), Vector3.ZERO, 6)
	var mi = clay_mi(b, near)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Patlamadan savrulan kil/taş parçaları. o: col (CLAY), dir (eğilim yönü), bias (eğilim gücü 0..1), up (yukarı eğilim 0.5), life (1.2)
static func shrapnel(host: Node, p: Vector3, n: int, spd: float, s: float, o := {}) -> void:
	var col: Color = o.get("col", CLAY)
	var dirb: Vector3 = o.get("dir", Vector3.ZERO)
	var bias = float(o.get("bias", 0.6))
	var upb = float(o.get("up", 0.5))
	var life = float(o.get("life", 1.2))
	for i in mini(n, 60):
		var d = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0) + upb, randf_range(-1, 1)).normalized()
		if dirb.length() > 0.01:
			d = d.lerp(dirb.normalized(), bias).normalized()
		var v = d * spd * randf_range(0.45, 1.0)
		toss(host, chip(s * randf_range(0.5, 1.25), col), p + d * 0.2, v, life * randf_range(0.7, 1.15))


static func _ramp(cols: Array) -> GradientTexture1D:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	var gt = GradientTexture1D.new()
	gt.gradient = g
	return gt


static func _pmat(o: Dictionary, r: float) -> ParticleProcessMaterial:
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 2.0))
	pm.initial_velocity_max = float(o.get("vmax", 6.0))
	pm.gravity = o.get("g", Vector3(0, -2.0, 0))
	pm.damping_min = float(o.get("damp", 1.5))
	pm.damping_max = float(o.get("damp", 1.5))
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, r)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	return pm


## Kızgın zerreler (eklemeli): beyaz → sarı → şeftali, küçülerek söner. o: dir, spread, vmin, vmax, g, damp, life (0.6), size (0.12), burst (0.85)
static func sparks(host: Node, p: Vector3, n: int, r: float, o := {}) -> GPUParticles3D:
	var life = float(o.get("life", 0.6))
	var pm = _pmat(o, r)
	pm.color_ramp = _ramp([Color(1, 1, 0.95, 1), Color(1, 0.9, 0.55, 1), Color(1, 0.62, 0.38, 0)])
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(1.0, 0.15))
	var ct = CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var gpp = GPUParticles3D.new()
	gpp.amount = clampi(n, 1, 200)
	gpp.lifetime = life
	gpp.one_shot = true
	gpp.explosiveness = float(o.get("burst", 0.85))
	gpp.randomness = 0.5
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.12))
	q.material = _spark_mat()
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-25, -25, -25), Vector3(50, 50, 50))
	put(host, gpp, p)
	gpp.emitting = true
	kill(host, life + 0.5, gpp)
	return gpp


## Pullar / kül / mikro bomba zerreleri. o: col0, col1 (renk rampası), ember (kenar kızgın), dir, spread, vmin, vmax, g, damp,
##    life (1.4), size (0.16), burst (0.8), spin (açısal hız derece/sn, 220)
static func flakes(host: Node, p: Vector3, n: int, r: float, o := {}) -> GPUParticles3D:
	var life = float(o.get("life", 1.4))
	var pm = _pmat(o, r)
	var c0: Color = o.get("col0", Color(0.3, 0.29, 0.28))
	var c1: Color = o.get("col1", Color(0.45, 0.43, 0.42))
	pm.color_ramp = _ramp([Color(c0.r, c0.g, c0.b, 1.0), Color(c1.r, c1.g, c1.b, 0.9), Color(c1.r, c1.g, c1.b, 0.0)])
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var spn = float(o.get("spin", 220.0))
	pm.angular_velocity_min = -spn
	pm.angular_velocity_max = spn
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = float(o.get("turb", 0.6))
	pm.turbulence_noise_scale = 2.5
	var gpp = GPUParticles3D.new()
	gpp.amount = clampi(n, 1, 400)
	gpp.lifetime = life
	gpp.one_shot = true
	gpp.explosiveness = float(o.get("burst", 0.8))
	gpp.randomness = 0.6
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.16))
	q.material = flake_mat(bool(o.get("ember", false)))
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	put(host, gpp, p)
	gpp.emitting = true
	kill(host, life + 0.6, gpp)
	return gpp


static func light(host: Node, p: Vector3, col: Color, energy: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = minf(rng, 60.0)
	l.shadow_enabled = false
	put(host, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


## Hazırlık: patlayıcı chakra kıvılcımları sarmal çizerek bir noktaya akar; orada küçük çekirdek kabarır (t sn)
static func converge(host: Node, to: Vector3, t: float, n := 10, r := 1.2, o := {}) -> void:
	for k in mini(n, 24):
		var a0 = k * TAU / n + randf() * 0.5
		var y0 = randf_range(-0.5, 0.7)
		var mi = orb_mi(randf_range(0.12, 0.22), float(o.get("warm", 0.3)), 4.0)
		put(host, mi, to + Vector3(cos(a0) * r, y0, sin(a0) * r))
		var dly = randf() * t * 0.3
		var tw = mi.create_tween()
		tw.tween_interval(dly)
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(mi):
				return
			var a = a0 + u * 3.2
			var rr = r * (1.0 - u)
			mi.global_position = to + Vector3(cos(a) * rr, y0 * (1.0 - u), sin(a) * rr), 0.0, 1.0, maxf(0.05, t - dly)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	var core = orb_mi(0.1, float(o.get("warm", 0.3)), 7.0)
	put(host, core, to)
	var tc = core.create_tween()
	tc.tween_property(core, "scale", Vector3.ONE * float(o.get("core", 0.6)), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tc.tween_callback(core.queue_free)


## Örnek Bakuton patlaması (parçalardan): parlama → kabaran top + topaklar + halka + kıymık + kurum + ışık.
## Başlangıç kompozisyonudur — teknikler kendi şeklini kurmalı. o: dir (yönlü), ring (true), soot (true), chips (sayı),
## puffs (sayı), pal, rise, near, ground (zemin halkası yükseklik eşiği 1.5)
static func explode(host: Node, p: Vector3, R: float, o := {}) -> void:
	var near = float(o.get("near", 7.0))
	var pal = float(o.get("pal", PAL_CLAY))
	flash(host, p, R * 2.4, 0.3, {"spikes": 9.0, "near": near * 0.8})
	var fo = {"pal": pal, "near": near, "rise": float(o.get("rise", R * 0.4))}
	if o.has("dir"):
		fo["dir"] = o["dir"]
		fo["squash"] = Vector3(0.8, 0.8, 1.5)
	fireball(host, p, R * 0.25, R, 1.0 + R * 0.12, fo)
	for k in int(o.get("puffs", 3)):
		var a = randf() * TAU
		var off = Vector3(cos(a), randf_range(0.1, 0.6), sin(a)) * R * 0.7
		puff(host, p + off, R * 0.35, 1.4 + R * 0.1, off.normalized() * R * 0.3 + Vector3.UP * R * 0.25, {"gray": 0.35, "hot": 0.6, "near": near * 0.7})
	var fl = floor_at(p)
	if bool(o.get("ring", true)) and p.y - fl.y < float(o.get("ground", 1.5)) + R * 0.5:
		ring(host, fl + Vector3.UP * 0.1, R * 0.3, R * 2.0, 0.55, Vector3.UP, {"near": near})
	if bool(o.get("soot", true)) and p.y - fl.y < 1.5 + R * 0.5:
		soot(host, fl, R * 1.1, 6.0 + R, {"heat": 0.6})
	shrapnel(host, p, int(o.get("chips", 8)), 6.0 + R * 2.0, 0.1 + R * 0.03)
	sparks(host, p, 18, R * 0.3, {"vmin": R * 2.0, "vmax": R * 5.0})
	light(host, p, Color(1.0, 0.85, 0.6), 4.0 + R, R * 6.0, 0.5)


# ================================================================== BakutonFXB eklemeleri
# BakutonFXB
## Koşan kil bebek (anime "Explosive Clay Dolls"): ince bel, öne düşük iri fasulye baş (iki kara nokta göz, burun çıkıntısı),
## topuz gibi şişkin ön kollar ince bileğe iner, şişkin baldırlı ince bilekli bacaklar. Kökün y=0 ayak tabanı, -Z ileri.
## meta "legs" [sol, sağ], "arms" [sol, sağ] (kalça / omuz pivotları). s = boy (m)
# BakutonFXB
static func runner_doll(s := 1.3, near := 1.4) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	# gövde: dar kalça → ince bel → geniş göğüs → kısa boyun
	Loft.tube(b, _sc([Vector3(0, 0.4, 0.01), Vector3(0, 0.48, 0.0), Vector3(0, 0.58, -0.01), Vector3(0, 0.68, -0.02), Vector3(0, 0.75, -0.04), Vector3(0, 0.8, -0.07)], s),
		_sc([Vector2(0.09, 0.08), Vector2(0.075, 0.07), Vector2(0.1, 0.085), Vector2(0.135, 0.1), Vector2(0.08, 0.07), Vector2(0.05, 0.05)], s), CLAY, 16, 3, true, true, Callable(), Vector3.FORWARD)
	# baş: öne eğik iri fasulye + alında kabarık sırt + burun çıkıntısı (anime bebeğin "kaş" kıvrımı)
	b.add("sphere", Vector3(0, 0.88, -0.1) * s, Vector3(0.3, 0.17, 0.26) * s, CLAY, Vector3(-18, 0, 0), 16)
	b.add("sphere", Vector3(0, 0.93, -0.06) * s, Vector3(0.24, 0.1, 0.2) * s, CLAY, Vector3(-10, 0, 0), 12)
	b.add("sphere", Vector3(0, 0.84, -0.21) * s, Vector3(0.09, 0.07, 0.07) * s, CLAY_SHADE, Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.075, 0.9, -0.215) * s, Vector3(0.028, 0.032, 0.02) * s, EYE, Vector3.ZERO, 8)
	root.add_child(clay_mi(b, near))
	var legs = []
	var arms = []
	for sx in [-1.0, 1.0]:
		# bacak: kalçada pivot; şişkin uyluk → ince diz → şişkin baldır → çok ince bilek → küçük ayak
		var lp = Node3D.new()
		lp.position = Vector3(sx * 0.055, 0.42, 0.0) * s
		var lb = MB.new()
		Loft.tube(lb, _sc([Vector3(0, 0, 0), Vector3(sx * 0.01, -0.1, -0.01), Vector3(0, -0.2, 0.0), Vector3(0, -0.28, 0.01), Vector3(0, -0.36, 0.01), Vector3(0, -0.41, 0.0)], s),
			_sc([Vector2(0.06, 0.06), Vector2(0.075, 0.075), Vector2(0.04, 0.04), Vector2(0.055, 0.055), Vector2(0.02, 0.02), Vector2(0.018, 0.018)], s), CLAY, 10, 3, true, true, _belly, Vector3.FORWARD)
		lb.add("sphere", Vector3(0, -0.415, -0.035) * s, Vector3(0.045, 0.02, 0.08) * s, CLAY, Vector3.ZERO, 8)
		lp.add_child(clay_mi(lb, near))
		root.add_child(lp)
		legs.append(lp)
		# kol: omuzda pivot; ince üst kol → topuz gibi şişkin ön kol → ince bilek → iki kısa parmak
		var ap = Node3D.new()
		ap.position = Vector3(sx * 0.15, 0.71, -0.02) * s
		var ab = MB.new()
		var w = Vector3(sx * 0.07, -0.33, -0.02)
		Loft.tube(ab, _sc([Vector3(0, 0, 0), Vector3(sx * 0.03, -0.08, 0), Vector3(sx * 0.06, -0.19, -0.01), Vector3(sx * 0.07, -0.27, -0.02), w], s),
			_sc([Vector2(0.035, 0.035), Vector2(0.04, 0.04), Vector2(0.075, 0.07), Vector2(0.05, 0.05), Vector2(0.016, 0.016)], s), CLAY, 10, 3, true, true, _belly, Vector3.FORWARD)
		for f in 2:
			var f0 = w + Vector3(0, -0.005, 0)
			var f1 = f0 + Vector3(sx * (0.01 + f * 0.025), -0.05, -0.01)
			Loft.tube(ab, _sc([f0, f1], s), _sc([Vector2(0.012, 0.012), Vector2(0.008, 0.008)], s), CLAY, 6, 2, true, true, Callable(), Vector3.FORWARD)
		ap.add_child(clay_mi(ab, near))
		root.add_child(ap)
		arms.append(ap)
	root.set_meta("legs", legs)
	root.set_meta("arms", arms)
	return root


## Koşu döngüsü: bacaklar ve kollar ters fazda savrulur, gövde öne eğik (period = tam adım)
# BakutonFXB
static func run_cycle(doll: Node3D, period := 0.34) -> void:
	if not is_instance_valid(doll):
		return
	var legs: Array = doll.get_meta("legs", [])
	var arms: Array = doll.get_meta("arms", [])
	for i in legs.size():
		var sg = 1.0 if i == 0 else -1.0
		var lg: Node3D = legs[i]
		lg.rotation.x = 0.75 * sg
		var tl = lg.create_tween().set_loops()
		tl.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tl.tween_property(lg, "rotation:x", -0.75 * sg, period * 0.5)
		tl.tween_property(lg, "rotation:x", 0.75 * sg, period * 0.5)
	for i in arms.size():
		var sg = -1.0 if i == 0 else 1.0
		var am: Node3D = arms[i]
		am.rotation.x = 0.9 * sg
		am.rotation.z = (0.35 if i == 0 else -0.35)
		var ta = am.create_tween().set_loops()
		ta.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ta.tween_property(am, "rotation:x", -0.9 * sg, period * 0.5)
		ta.tween_property(am, "rotation:x", 0.9 * sg, period * 0.5)


## Kil ikiz (Nendo Kawarimi): kaba yoğrulmuş insan biçimi — yuvarlak baş, omuzlu gövde, yanlara düşen kollar, iki bacak;
## yüzde yalnız iki parmak çukuru göz. Kök y=0 ayak tabanı, -Z ileri. s = boy (m)
# BakutonFXB
static func clay_twin(s := 1.75, near := 1.6) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	Loft.tube(b, _sc([Vector3(0, 0.46, 0), Vector3(0, 0.56, 0), Vector3(0, 0.68, -0.01), Vector3(0, 0.78, 0.0), Vector3(0, 0.83, 0.0)], s),
		_sc([Vector2(0.1, 0.07), Vector2(0.095, 0.065), Vector2(0.12, 0.075), Vector2(0.13, 0.08), Vector2(0.05, 0.045)], s), CLAY, 16, 3, true, true, Callable(), Vector3.FORWARD)
	b.add("sphere", Vector3(0, 0.9, -0.005) * s, Vector3(0.12, 0.13, 0.12) * s, CLAY, Vector3.ZERO, 14)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.035, 0.91, -0.055) * s, Vector3(0.022, 0.016, 0.012) * s, CLAY_SHADE.darkened(0.35), Vector3.ZERO, 8)
		Loft.tube(b, _sc([Vector3(sx * 0.12, 0.77, 0), Vector3(sx * 0.16, 0.64, 0.005), Vector3(sx * 0.17, 0.52, -0.02), Vector3(sx * 0.165, 0.45, -0.02)], s),
			_sc([Vector2(0.04, 0.04), Vector2(0.034, 0.034), Vector2(0.03, 0.03), Vector2(0.034, 0.03)], s), CLAY, 10, 3, true, true, _belly, Vector3.FORWARD)
		Loft.tube(b, _sc([Vector3(sx * 0.055, 0.48, 0), Vector3(sx * 0.06, 0.3, 0.0), Vector3(sx * 0.06, 0.1, 0.01), Vector3(sx * 0.06, 0.02, -0.02)], s),
			_sc([Vector2(0.055, 0.055), Vector2(0.045, 0.045), Vector2(0.038, 0.038), Vector2(0.04, 0.05)], s), CLAY, 10, 3, true, true, _belly, Vector3.FORWARD)
	# yoğrulma izleri: gövdeye yapışık birkaç kil topağı (kaba, aceleyle yapılmış kopya)
	for k in 5:
		b.add("sphere", Vector3(randf_range(-0.08, 0.08), randf_range(0.5, 0.78), randf_range(-0.06, 0.06)) * s, Vector3.ONE * randf_range(0.03, 0.05) * s, CLAY, Vector3.ZERO, 8)
	root.add_child(clay_mi(b, near))
	return root
