class_name ElementFX
extends RefCounted
## Ateş / Kristal (Shōton) / Buz (Hyōton) tekniklerinin görselleri — on üç teknik, hepsi bu dosyanın kendi shader'ları ve geometrisiyle.
## Ortak efekt yardımcısı yok. Yapı taşları:
##   ateş   : katmanlı cel alev dili (eksenli billboard; beyaz-sarı çekirdek → sarı → turuncu → koyu kızıl kenar → koyu kontur,
##            yükselen gürültüyle sallanan uç), hacimli alev topu (yüzey açısı + gürültü bantları), köz kıvılcımı, kavrulmuş zemin
##   kristal: yüzlü (türev normalli) pembe-mor yarı saydam taş, keskin beyaz kenar parlaması, iç kırılma bantları
##   buz    : aynı taş shader'ı soluk camgöbeği + kırağı lekeleri / çatlakları; ayna kipi sahte gök yansıması + kayan parıltı
##   diğer  : yırtık kenarlı şerit (rüzgâr / su / tel / şimşek), cel bulut (toz, buhar, sis, kar), zemin izi (kavruk / kırağı / yağ)
## Oynanış (hasar, durum, süre, menzil) eski işleyicilerden satır satır taşındı.

static var _cache := {}

const PINK := Color(0.96, 0.62, 0.9)
const VIOLET := Color(0.78, 0.6, 1.0)
const ICEC := Color(0.74, 0.93, 1.0)
const EMBER_COLS := [Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.6, 0.12, 1.0), Color(0.75, 0.15, 0.04, 0.0)]

# ================================================================== shader'lar
const NOISE_FN := """
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

float vor_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			float dd = length(g + o - f);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	return d2 - d1;
}
"""

## Alev: vol=0 → eksenli billboard dil (QuadMesh, taban orijinde; düğümün Y ekseni dilin yönü), vol=1 → hacimli top.
## heat ömür boyunca düşer: dil kısalır, çekirdek söner, kızıla döner, kenarlardan dağılır.
const FIRE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float seed = 0.0;
instance uniform float fade = 1.0;
instance uniform float vol = 0.0;
instance uniform float lava = 0.0;

NOISE_FN

void vertex() {
	if (vol < 0.5) {
		vec3 up = MODEL_MATRIX[1].xyz;
		float sy = max(length(up), 0.0001);
		up /= sy;
		float sx = length(MODEL_MATRIX[0].xyz);
		vec3 tocam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
		vec3 right = cross(up, tocam);
		float rl = length(right);
		right = rl > 0.0001 ? right / rl : vec3(1.0, 0.0, 0.0);
		vec3 fw = cross(right, up);
		mat4 m = mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(fw * sx, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * m;
	} else {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float tm = TIME;
	float e = -1.0;
	float tipfade = 1.0;
	if (vol < 0.5) {
		// beş ince, kıvrılan, ayrı ayrı titreyen alev dili; dipte kaynaşık gövde; uçlar ayrılıp kopar ve saydamlaşır
		float y = 1.0 - UV.y;
		float x = UV.x * 2.0 - 1.0;
		float n = fbm(vec2(x * 1.6 + seed * 7.1, y * 2.4 - tm * 3.0 + seed * 3.3));
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float hh = h21(vec2(seed * 7.0 + fi, 1.3));
			float cx = (fi - 2.0) * 0.2 + (hh - 0.5) * 0.15;
			float ht = (0.5 + 0.5 * h21(vec2(fi + 3.1, seed))) * (1.0 - abs(cx) * 0.6);
			ht *= 0.8 + 0.2 * sin(tm * (7.0 + fi * 1.9) + seed * 5.0 + fi * 2.3);
			float yy = y / max(ht, 0.05);
			if (yy < 1.0) {
				float bend = sin(yy * 3.2 - tm * (5.0 + fi) + seed * 3.0 + fi * 2.0) * 0.18 * yy * yy + (n - 0.5) * 0.45 * yy;
				float w = 0.24 * pow(1.0 - yy, 0.65) * (0.7 + 0.5 * hh) * smoothstep(-0.1, 0.2, yy);
				float ei = 1.0 - abs(x - cx - bend) / max(w, 0.0001);
				e = max(e, ei * (1.0 - yy * 0.5));
			}
		}
		float bw = 0.55 * max(1.0 - y * 1.7, 0.0001);
		e = max(e, (1.0 - abs(x + (n - 0.5) * 0.3) / bw) * max(1.0 - y * 2.4, 0.0));
		float er = fbm(vec2(x * 3.0 + seed, y * 4.0 - tm * 4.0));
		e = e * (0.7 + 0.6 * er);
		tipfade = 1.0 - smoothstep(0.5, 1.0, y);
	} else {
		// kabaran alev kütlesi: gürültüyle bükülen yuvarlak, üst kenarında yalayan diller
		vec2 p = UV * 2.0 - 1.0;
		p.y = -p.y;
		float n = fbm(p * 1.8 + vec2(seed * 3.0, -tm * 2.2));
		float n2 = fbm(p * 3.6 + vec2(-seed * 2.0, -tm * 3.4));
		vec2 q = p + (vec2(n, n2) - 0.5) * 0.8;
		float r = length(q * vec2(1.0, 0.9));
		e = (1.0 - r) * 1.35 * (0.65 + 0.6 * n2);
		e += max(p.y, 0.0) * (n2 - 0.5) * 0.9;
		tipfade = 1.0 - smoothstep(0.3, 1.0, p.y);
	}
	e *= heat;
	if (e < 0.04) {
		discard;
	}
	vec3 c0 = vec3(1.0, 0.98, 0.84);
	vec3 c1 = vec3(1.0, 0.84, 0.25);
	vec3 c2 = vec3(1.0, 0.5, 0.08);
	vec3 c3 = vec3(0.85, 0.16, 0.04);
	vec3 c4 = vec3(0.45, 0.07, 0.03);
	if (lava > 0.5) {
		c1 = vec3(1.0, 0.88, 0.38);
		c2 = vec3(1.0, 0.64, 0.14);
		c3 = vec3(0.92, 0.34, 0.06);
		c4 = vec3(0.5, 0.15, 0.03);
	}
	vec3 col = c4;
	float a = 0.35;
	if (e > 0.12) {
		col = c3;
		a = 0.7;
	}
	if (e > 0.24) {
		col = c2;
		a = 0.92;
	}
	if (e > 0.42) {
		col = c1;
		a = 1.0;
	}
	if (e > 0.62) {
		col = c0;
	}
	a *= mix(0.45, 1.0, tipfade);
	ALBEDO = pow(col, vec3(2.2)) * 1.25;
	ALPHA = a * fade;
}
"""

## Kristal / buz / ayna: yüzlü taş. Yüz normali türevden (her yüz düz renk bloğu), yüze göre ton farkı, iç kırılma bantları,
## keskin beyaz kenar; frost → kırağı lekeleri + ince çatlak; mirror → sahte gök yansıması + kayan parıltı çizgisi.
const GEM_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_schlick_ggx;

instance uniform vec3 tint = vec3(0.96, 0.62, 0.9);
instance uniform float frost = 0.0;
instance uniform float glow = 0.3;
instance uniform float fade = 1.0;
instance uniform float mirror = 0.0;

varying vec3 lp;

NOISE_FN

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	float fv = clamp(dot(fn, VIEW), 0.0, 1.0);
	float fr = 1.0 - fv;
	float fh = h31(floor(fn * 5.0 + 0.5));
	vec3 base = pow(tint, vec3(2.2));
	vec3 deep = base * base * vec3(0.75, 0.6, 0.95);
	vec3 col = mix(deep, base, 0.3 + 0.55 * fh);
	float band = step(0.82, fract(lp.y * 2.3 + lp.x * 1.3 - lp.z * 0.7 + fh * 3.0));
	col = mix(col, base * 1.35 + vec3(0.12), band * 0.5);
	float fz = vnoise(lp.xy * 6.0 + lp.zz * 3.0);
	float cr = step(0.9, fract(vnoise(lp.xz * 3.0 + lp.yy * 2.0) * 6.0));
	col = mix(col, vec3(0.9, 0.96, 1.0), clamp(frost * (smoothstep(0.45, 0.75, fz) * 0.7 + cr * 0.6), 0.0, 1.0));
	if (mirror > 0.5) {
		vec3 rv = reflect(-VIEW, fn);
		vec3 wr = (INV_VIEW_MATRIX * vec4(rv, 0.0)).xyz;
		float sk = wr.y;
		vec3 sky = mix(vec3(0.55, 0.76, 0.9), vec3(0.94, 0.98, 1.0), smoothstep(-0.2, 0.3, sk));
		sky = mix(sky, vec3(0.32, 0.52, 0.72), step(sk, -0.15));
		float sh = step(0.86, fract(lp.x * 0.9 + lp.y * 1.1 + TIME * 0.15));
		col = mix(pow(sky, vec3(2.2)), vec3(1.0), sh * 0.6);
	}
	float edgeh = step(0.78, fr);
	col = mix(col, vec3(1.0), edgeh * 0.8);
	ALBEDO = col;
	EMISSION = col * glow;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	ALPHA = clamp(mix(0.5, 0.92, fr) + mirror * 0.4 + frost * 0.25, 0.0, 1.0) * fade;
}
"""

## Şerit (rüzgâr çizgisi, su akımı, tel, şimşek, ışık kavisi): UV.x boyunca head/tail arası görünür (iz kayar),
## eni sinüs profiliyle sivrilir (taper), kenarı gürültüyle yırtılır (rag), ortası beyaz çekirdek (core). Renk köşe renginden.
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, BLENDMODE;

instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float fade = 1.0;
instance uniform float core = 0.4;
instance uniform float rag = 0.3;
instance uniform float taper = 1.0;
instance uniform float seed = 0.0;

NOISE_FN

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float k = clamp((u - tail) / max(head - tail, 0.0001), 0.0, 1.0);
	float prof = mix(1.0, sin(3.14159 * pow(k, 0.75)), taper);
	prof *= 1.0 - rag * vnoise(vec2(u * 22.0 + seed * 13.0, seed * 3.0 + TIME * 2.0));
	float v = abs(UV.y * 2.0 - 1.0);
	if (v > prof) {
		discard;
	}
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	c = mix(c, vec3(1.0), step(v, prof * core) * 0.85);
	ALBEDO = c;
	ALPHA = COLOR.a * fade;
}
"""

## Işıma: star=0 → yüzey açısıyla yumuşayan hacim (ışın, küre), star=1 → kameraya dönük yıldız parıltısı (ışın sayısı rays)
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_add;

instance uniform vec3 gcol = vec3(1.0, 0.9, 0.7);
instance uniform float fade = 1.0;
instance uniform float star = 0.0;
instance uniform float rays = 6.0;

void vertex() {
	if (star > 0.5) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec3 c = pow(gcol, vec3(2.2));
	float a;
	if (star > 0.5) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float spikes = pow(abs(cos(ang * rays * 0.5)), 14.0);
		float body = 1.0 - smoothstep(0.0, 0.3, r);
		float ray = spikes * (1.0 - smoothstep(0.08, 1.0, r));
		a = clamp(body + ray, 0.0, 1.0);
		c = mix(c, vec3(1.0), body);
	} else {
		float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		a = smoothstep(0.05, 0.75, fv);
		c = mix(c, vec3(1.0), step(0.8, fv) * 0.7);
	}
	ALBEDO = c * 1.3;
	ALPHA = a * fade;
}
"""

## Cel bulut (toz, buhar, sis, kar, klon dumanı): iki ton (üst aydınlık / alt gölge), siluette koyu bant, fade ile gürültüden erir
const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform vec3 lit = vec3(1.0, 1.0, 1.0);
instance uniform vec3 shade = vec3(0.7, 0.7, 0.75);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float opa = 1.0;

varying vec3 lp;

NOISE_FN

void vertex() {
	lp = VERTEX;
	// topak topak kabaran bulut (düz küre değil)
	float n = vnoise(VERTEX.xy * 2.3 + VERTEX.zz * 1.7 + vec2(seed * 3.0, TIME * 0.4));
	float n2 = vnoise(VERTEX.yz * 4.1 + vec2(seed, -TIME * 0.6));
	VERTEX += NORMAL * ((n - 0.5) * 0.55 + (n2 - 0.5) * 0.2);
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float n = vnoise(lp.xy * 3.0 + lp.zz * 2.0 + vec2(seed * 7.0));
	if (n > fade + 0.15 || fv < 0.3 * (1.0 - fade) + 0.12 * n) {
		discard;
	}
	vec3 c = mix(shade, lit, step(0.1, wn.y + (n - 0.5) * 0.5));
	ALBEDO = pow(c, vec3(2.2));
	ALPHA = opa;
}
"""

## Zemin izi (PlaneMesh 2x2): kind 0 kavruk toprak + kızgın köz çatlakları, 1 kırağı + beyaz çatlak ağı,
## 2 kaynar kurbağa yağı (amber, parlayan sarı damarlar, ıslak parlama). grow kenarı açar, heat damarları söndürür.
const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform float grow = 1.0;
instance uniform float fade = 1.0;
instance uniform float heat = 1.0;
instance uniform float seed = 0.0;

NOISE_FN

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float edge = grow * (0.72 + 0.28 * fbm(vec2(ang * 1.6 + seed * 9.0, seed)));
	if (r > edge) {
		discard;
	}
	float k = r / max(edge, 0.001);
	vec2 sp = p * 3.2 + vec2(seed * 3.7);
	// çatlak ağı: gürültüyle bükülmüş, yer yer kopuk (bal peteği düzeni olmasın)
	vec2 wq = sp + (vec2(fbm(sp * 0.8), fbm(sp * 0.8 + vec2(7.3, 1.9))) - 0.5) * 2.2;
	float ve = vor_edge(wq);
	float keep = step(0.42, vnoise(sp * 0.9 + vec2(3.0, seed)));
	float n = fbm(sp * 1.3);
	vec3 col;
	float g = 0.0;
	float a;
	if (kind < 0.5) {
		col = mix(vec3(0.07, 0.05, 0.04), vec3(0.22, 0.15, 0.1), smoothstep(0.45, 0.9, k + (n - 0.5) * 0.5));
		float crack = (1.0 - step(0.035, ve)) * keep * step(k, 0.8);
		vec3 hot = mix(vec3(1.0, 0.38, 0.06), vec3(1.0, 0.85, 0.32), step(0.55, n));
		col = mix(col, hot, crack * step(0.05, heat));
		g = crack * heat * 1.6;
		a = (1.0 - smoothstep(0.6, 1.0, k)) * 0.85;
	} else if (kind < 1.5) {
		col = mix(vec3(0.74, 0.89, 0.97), vec3(0.95, 0.99, 1.0), step(0.55, n));
		float crack = (1.0 - step(0.03, ve)) * keep;
		col = mix(col, vec3(1.0), crack);
		a = (0.8 - 0.2 * step(0.55, n)) * (1.0 - smoothstep(0.8, 1.0, k) * 0.6);
	} else {
		vec3 oil = mix(vec3(0.74, 0.52, 0.15), vec3(0.92, 0.72, 0.3), smoothstep(0.4, 0.6, n + 0.1 * sin(TIME * 2.0 + r * 8.0)));
		float vein = (1.0 - step(0.03, vor_edge(wq * 0.7 + vec2(TIME * 0.1)))) * keep;
		col = mix(oil, vec3(1.0, 0.88, 0.3), vein * step(0.05, heat));
		g = vein * heat * 1.4;
		col = mix(col, vec3(1.0, 0.95, 0.75), step(0.82, n) * 0.6);
		a = 0.9 * (1.0 - smoothstep(0.85, 1.0, k) * 0.5);
	}
	ALBEDO = pow(col, vec3(2.2)) * (1.0 + g);
	ALPHA = a * fade;
}
"""

## Kalın kontur (ters gövde): kara kar ejderinin soluk beyaz dış çizgisi
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform vec3 ocol = vec3(0.05, 0.05, 0.05);
instance uniform float width = 0.03;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = pow(ocol, vec3(2.2));
}
"""

## Kara kar ejderi gövdesi: koyu gri cel + lekeli kar dokusu; kırmızı köşe rengi (göz / ağız) kendinden ışır
const DRAGON_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

instance uniform float fade = 1.0;

varying vec3 lp;

NOISE_FN

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float hot = step(0.45, COLOR.r - COLOR.g);
	// pul sırası: gövde boyunca (UV.x) kavisli pul kenarları; lekeli kara kar dokusu
	float sc = fract(UV.x * 26.0 + abs(UV.y - 0.5) * 3.0);
	float scale_line = step(0.86, sc) * step(UV.x, 0.999) * step(0.001, UV.x);
	float n = vnoise(lp.xz * 1.6 + lp.yy * 1.2);
	c = mix(c, c * 0.5, step(0.62, n) * (1.0 - hot));
	c = mix(c, c * 0.45, scale_line * (1.0 - hot));
	ALBEDO = c;
	EMISSION = c * hot * 2.5;
	ROUGHNESS = 0.9;
}
"""

## Kurbağa yağı: amber, alt yarı gölge, üstte ıslak parlak leke, koyu kahve kenar; hot → kaynarken sarı parlar
const OIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float hot = 0.0;
instance uniform float lump = 0.0;
instance uniform float seed = 0.0;

NOISE_FN

void vertex() {
	if (lump > 0.0) {
		float n = vnoise(VERTEX.xz * 2.2 + VERTEX.yy * 1.5 + vec2(seed * 3.0, TIME * 0.8));
		VERTEX += NORMAL * (n - 0.5) * lump;
	}
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 c = vec3(0.88, 0.64, 0.22);
	c = mix(c * 0.75, c, step(0.0, wn.y));
	c = mix(c, vec3(1.0, 0.93, 0.66), step(0.6, wn.y) * step(0.55, fv) * 0.85);
	c = mix(vec3(0.6, 0.38, 0.1), c, step(0.2, fv));
	c = mix(c, vec3(1.0, 0.82, 0.3), hot * step(0.6, fv));
	ALBEDO = pow(c, vec3(2.2)) * (1.0 + hot * 0.8);
	ALPHA = fade;
}
"""


# ================================================================== malzeme / mesh önbelleği
static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code.replace("NOISE_FN", NOISE_FN)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func fire_mat() -> ShaderMaterial:
	return _shader_mat("fire", FIRE_SHADER)


static func gem_mat() -> ShaderMaterial:
	return _shader_mat("gem", GEM_SHADER)


static func ribbon_mat(add: bool) -> ShaderMaterial:
	if add:
		return _shader_mat("rib_add", RIBBON_SHADER.replace("BLENDMODE", "blend_add"))
	return _shader_mat("rib_mix", RIBBON_SHADER.replace("BLENDMODE", "blend_mix"))


static func glow_mat() -> ShaderMaterial:
	return _shader_mat("glow", GLOW_SHADER)


static func puff_mat() -> ShaderMaterial:
	return _shader_mat("puff", PUFF_SHADER)


static func ground_mat() -> ShaderMaterial:
	return _shader_mat("ground", GROUND_SHADER)


static func outline_mat() -> ShaderMaterial:
	return _shader_mat("outline", OUTLINE_SHADER)


static func dragon_mat() -> ShaderMaterial:
	return _shader_mat("dragon", DRAGON_SHADER)


static func oil_mat() -> ShaderMaterial:
	return _shader_mat("oil", OIL_SHADER)


static func _flat_mat(col: Color) -> StandardMaterial3D:
	var key = "flat_%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	_cache[key] = m
	return m


static func _dot_tex() -> GradientTexture2D:
	if _cache.has("dot_tex"):
		return _cache["dot_tex"]
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.95])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tx = GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 32
	tx.height = 32
	_cache["dot_tex"] = tx
	return tx


static func _dot_mat(add: bool) -> StandardMaterial3D:
	var key = "dot_add" if add else "dot_mix"
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _dot_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


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


static func _ball() -> SphereMesh:
	if not _cache.has("ball"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 18
		s.rings = 10
		_cache["ball"] = s
	return _cache["ball"]


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["plane"] = p
	return _cache["plane"]


static func _box() -> BoxMesh:
	if not _cache.has("box"):
		var b = BoxMesh.new()
		b.size = Vector3.ONE
		_cache["box"] = b
	return _cache["box"]


## Birim silindir (yarıçap 1, boy 1, Y ekseni): ışın ve ışık çizgileri
static func _rod() -> CylinderMesh:
	if not _cache.has("rod"):
		var cm = CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 12
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		_cache["rod"] = cm
	return _cache["rod"]


static func _needle_mesh() -> CylinderMesh:
	if not _cache.has("needle"):
		var cm = CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.05
		cm.height = 0.95
		cm.radial_segments = 4
		cm.rings = 1
		_cache["needle"] = cm
	return _cache["needle"]


# ================================================================== temel yardımcılar
static func _mouth(c: Node3D) -> Vector3:
	return c.global_position + Vector3.UP * 1.55 + c.face_dir() * 0.4


static func _put(host: Node, n: Node3D, pos: Vector3) -> Node3D:
	host.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _kill(host: Node, sec: float, n: Node) -> void:
	var w = weakref(n)
	host.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Örnek shader parametresini tween'leyen ayarlayıcı
static func _pf(mi: GeometryInstance3D, k: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(k, v)


## Y ekseni a olan dik taban
static func _axis_basis(a: Vector3) -> Basis:
	var y = a.normalized()
	if y.length() < 0.5:
		y = Vector3.UP
	var rf = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x = rf.cross(y).normalized()
	var z = x.cross(y)
	return Basis(x, y, z)


static func _look(n: Node3D, dirv: Vector3) -> void:
	if not is_instance_valid(n) or dirv.length() < 0.0001:
		return
	var f = dirv.normalized()
	n.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)


static func _path(fn: Callable, n: int) -> PackedVector3Array:
	var out = PackedVector3Array()
	for i in n + 1:
		out.append(fn.call(float(i) / n))
	return out


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _v(st: SurfaceTool, p: Vector3, uv: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_uv(uv)
	st.add_vertex(p)


static func _side(tv: Vector3, pl: int, hint: Vector3) -> Vector3:
	if hint != Vector3.ZERO:
		var s = tv.cross(hint)
		if s.length() < 0.0001:
			s = tv.cross(Vector3.RIGHT)
		s = s.normalized()
		return s if pl == 0 else tv.cross(s).normalized()
	var rf = Vector3.UP if absf(tv.y) < 0.9 else Vector3.RIGHT
	var s2 = tv.cross(rf).normalized()
	return s2 if pl == 0 else tv.cross(s2).normalized()


## Nokta dizisinden şerit mesh'i (iki dik düzlem: her açıdan görünür). UV.x boyunca 0..1, UV.y enine.
static func _strip(pts: PackedVector3Array, w: float, col: Color, twin := true, cols := PackedColorArray(), hint := Vector3.ZERO) -> ArrayMesh:
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
			var s0: Vector3 = _side(tans[i], pl, hint) * w
			var s1: Vector3 = _side(tans[i + 1], pl, hint) * w
			var c0: Color = cols[i] if cols.size() == n else col
			var c1: Color = cols[i + 1] if cols.size() == n else col
			var u0 = float(i) / (n - 1)
			var u1 = float(i + 1) / (n - 1)
			_v(st, pts[i] - s0, Vector2(u0, 0.0), c0)
			_v(st, pts[i] + s0, Vector2(u0, 1.0), c0)
			_v(st, pts[i + 1] + s1, Vector2(u1, 1.0), c1)
			_v(st, pts[i] - s0, Vector2(u0, 0.0), c0)
			_v(st, pts[i + 1] + s1, Vector2(u1, 1.0), c1)
			_v(st, pts[i + 1] - s1, Vector2(u1, 0.0), c1)
	return st.commit()


## Yüzlü kristal / buz sütunu (birim: taban y=0 yarıçap ~0.5, tepe y=1, altta kısa sivri kök)
static func gem_mesh(variant: int, sides := 6, tip := 0.32) -> ArrayMesh:
	var key = "gem%d_%d_%d" % [variant, sides, int(tip * 100.0)]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 1000 + variant * 37 + sides
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0 = []
	var r1 = []
	var sh = 1.0 - tip
	for i in sides:
		var a = TAU * i / sides + rng.randf_range(-0.2, 0.2)
		var rr = 0.5 * rng.randf_range(0.8, 1.15)
		r0.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
		r1.append(Vector3(cos(a) * rr * 0.9, sh + rng.randf_range(-0.06, 0.06), sin(a) * rr * 0.9))
	var apex = Vector3(rng.randf_range(-0.08, 0.08), 1.0, rng.randf_range(-0.08, 0.08))
	var root = Vector3(0.0, -0.22, 0.0)
	for i in sides:
		var j = (i + 1) % sides
		_tri(st, r0[i], r1[i], r1[j])
		_tri(st, r0[i], r1[j], r0[j])
		_tri(st, r1[i], apex, r1[j])
		_tri(st, r0[i], r0[j], root)
	st.generate_normals()
	var m = st.commit()
	_cache[key] = m
	return m


## Kristal şuriken: dört kavisli sivri kanat + ortada yüzlü göbek (düz XZ düzleminde, yarıçap 1)
static func _xstar_mesh() -> ArrayMesh:
	if _cache.has("xstar"):
		return _cache["xstar"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th = 0.09
	var cu = Vector3(0, th, 0)
	var cd = Vector3(0, -th, 0)
	var s1s = []
	var s2s = []
	for k in 4:
		var a = k * TAU / 4.0
		var dv = Vector3(cos(a), 0, sin(a))
		var sv = Vector3(-sin(a), 0, cos(a))
		s1s.append(dv * 0.3 + sv * 0.2)
		s2s.append(dv * 0.3 - sv * 0.2)
	for k in 4:
		var a = k * TAU / 4.0
		var dv = Vector3(cos(a), 0, sin(a))
		var sv = Vector3(-sin(a), 0, cos(a))
		var tip = dv * 1.0 + sv * 0.2
		_tri(st, cu, s1s[k], tip)
		_tri(st, cu, tip, s2s[k])
		_tri(st, cd, tip, s1s[k])
		_tri(st, cd, s2s[k], tip)
		var nk = (k + 1) % 4
		_tri(st, cu, s2s[k], s1s[nk])
		_tri(st, cd, s1s[nk], s2s[k])
	st.generate_normals()
	var m = st.commit()
	_cache["xstar"] = m
	return m


# ================================================================== yapı taşları: ateş
## Alev dili: taban p, ekseni ax (dik yükselen ya da rüzgârla yatan); ısı ömür boyunca düşer → kızarıp söner
static func tongue(host: Node, p: Vector3, h: float, w: float, life: float, ax := Vector3.UP, vel := Vector3.ZERO, heat0 := 1.15, lava := false) -> MeshInstance3D:
	var mi = _gi(_quad_base(), fire_mat())
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat0)
	mi.set_instance_shader_parameter("lava", 1.0 if lava else 0.0)
	mi.set_instance_shader_parameter("vol", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, p)
	mi.basis = _axis_basis(ax)
	mi.scale = Vector3(w * 0.45, h * 0.3, w * 0.45)
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(w, h, w), life * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "heat"), heat0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Hacimli alev topu: r0 → r1 büyür, ısısı düşer (beyaz çekirdek küçülür, kızıl kenar yırtılır)
static func fire_blob(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, lava := false, heat0 := 1.25) -> MeshInstance3D:
	var mi = _gi(_quad_c(), fire_mat())   # kameraya dönük kabaran alev kütlesi (küre değil)
	mi.set_instance_shader_parameter("vol", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("heat", heat0)
	mi.set_instance_shader_parameter("lava", 1.0 if lava else 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, p)
	mi.scale = Vector3.ONE * r0 * 2.0
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "heat"), heat0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


static func embers(host: Node, p: Vector3, n: int, spread_r: float, up := 3.0) -> void:
	sparks(host, p, {"n": n, "life": 1.1, "r": spread_r, "dir": Vector3.UP, "spread": 70.0, "vmin": up * 0.4, "vmax": up * 1.3,
		"g": Vector3(0, 1.2, 0), "damp": 1.5, "size": 0.11, "burst": 0.6, "cols": EMBER_COLS})


## Ağızdan fışkıran alev akımı: hacimli alev topları ağızdan ileri akıp büyür, çevresinde öne yatık diller yalar, köz saçılır
static func flame_stream(pj: PathJutsu, c: Node3D, from: Vector3, d: Vector3, L: float, W: float, dur: float, lava := false) -> void:
	var dd = d.normalized()
	var sd = dd.cross(Vector3.UP).normalized()
	if sd.length() < 0.5:
		sd = Vector3.RIGHT
	var tick = func(i, _k):
		var mo = _mouth(c) if pj.live(c) else from
		var spd = L / 0.45
		var jit = (sd * randf_range(-1.0, 1.0) + Vector3.UP * randf_range(-0.4, 0.6)) * W * 0.25
		fire_blob(pj, mo + dd * 0.4, 0.22, W * 0.5 * randf_range(0.8, 1.1), 0.45, dd * spd * randf_range(0.85, 1.0) + jit, lava)
		for q in 2:
			var u = randf()
			var p = mo + dd * (0.8 + u * L * 0.8) + sd * randf_range(-1.0, 1.0) * W * 0.3 * u
			tongue(pj, p, (0.8 + u * 2.2) * (0.6 + W * 0.12), 0.5 + u * W * 0.35, 0.35, (dd + Vector3.UP * 0.6).normalized(), dd * L * 0.5, 1.1, lava)
		if i % 4 == 0:
			embers(pj, mo + dd * L * 0.5, 8, W * 0.5, 3.0)
	pj.every(dur, 0.045, tick)
	light(pj, from + dd * L * 0.4, Color(1.0, 0.6, 0.2), 6.0, L, dur + 0.3)


# ================================================================== yapı taşları: genel
static func light(host: Node, p: Vector3, col: Color, energy: float, rng: float, life: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_put(host, l, p)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l


## Kendi kıvılcım / damla / kar tanesi parçacıkları (keskin kenarlı yuvarlak nokta, renk rampası, küçülerek söner)
static func sparks(host: Node, p: Vector3, o: Dictionary) -> GPUParticles3D:
	var life = float(o.get("life", 0.8))
	var pm = ParticleProcessMaterial.new()
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = float(o.get("spread", 180.0))
	pm.initial_velocity_min = float(o.get("vmin", 2.0))
	pm.initial_velocity_max = float(o.get("vmax", 6.0))
	pm.gravity = o.get("g", Vector3(0, -3.0, 0))
	pm.damping_min = float(o.get("damp", 0.0))
	pm.damping_max = float(o.get("damp", 0.0))
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.01, float(o.get("r", 0.2)))
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var cols: Array = o.get("cols", EMBER_COLS)
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var pc = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1))
		pc.append(cols[i])
	g.offsets = offs
	g.colors = pc
	var gt = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(1.0, 0.25))
	var ct = CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var gpp = GPUParticles3D.new()
	gpp.amount = maxi(1, int(o.get("n", 16)))
	gpp.lifetime = life
	gpp.one_shot = true
	gpp.explosiveness = float(o.get("burst", 0.9))
	gpp.process_material = pm
	var q = QuadMesh.new()
	q.size = Vector2.ONE * float(o.get("size", 0.12))
	q.material = _dot_mat(bool(o.get("add", true)))
	gpp.draw_pass_1 = q
	gpp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpp.visibility_aabb = AABB(Vector3(-25, -25, -25), Vector3(50, 50, 50))
	_put(host, gpp, p)
	gpp.emitting = true
	_kill(host, life + 0.5, gpp)
	return gpp


static func ribbon_mi(pts: PackedVector3Array, w: float, col: Color, add := false, o := {}) -> MeshInstance3D:
	var mi = _gi(_strip(pts, w, col, bool(o.get("twin", true)), PackedColorArray(), o.get("hint", Vector3.ZERO)), ribbon_mat(add))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("core", float(o.get("core", 0.35)))
	mi.set_instance_shader_parameter("rag", float(o.get("rag", 0.25)))
	mi.set_instance_shader_parameter("taper", float(o.get("taper", 1.0)))
	mi.set_instance_shader_parameter("head", 1.0)
	mi.set_instance_shader_parameter("tail", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


## Kayan şerit: baş öne akar, kuyruk arkadan toplanır (travel) ya da yerinde durup söner
static func streak(host: Node, pts: PackedVector3Array, w: float, col: Color, life: float, add := false, o := {}) -> MeshInstance3D:
	var mi = ribbon_mi(pts, w, col, add, o)
	_put(host, mi, Vector3.ZERO)
	var dl = float(o.get("delay", 0.0))
	var tw = mi.create_tween().set_parallel()
	if bool(o.get("travel", true)):
		mi.set_instance_shader_parameter("head", 0.0)
		tw.tween_method(_pf(mi, "head"), 0.0, 1.0, life * 0.45).set_delay(dl).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_pf(mi, "tail"), 0.0, 1.0, life * 0.75).set_delay(dl + life * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life * 0.35).set_delay(dl + life * 0.65)
	tw.chain().tween_callback(mi.queue_free)
	return mi


static func _jag(a: Vector3, b: Vector3, n: int, jag: float) -> PackedVector3Array:
	var out = PackedVector3Array()
	var dv = b - a
	var L = dv.length()
	var tv = dv / maxf(L, 0.0001)
	var s1 = _side(tv, 0, Vector3.ZERO)
	var s2 = _side(tv, 1, Vector3.ZERO)
	for i in n + 1:
		var u = float(i) / n
		var amp = jag * sin(u * PI) * minf(1.0, L / 6.0)
		out.append(a + dv * u + (s1 * randf_range(-1.0, 1.0) + s2 * randf_range(-1.0, 1.0)) * amp)
	return out


## Kırık şimşek: kısa ömür içinde iki kez yeniden kırılır (titreşir)
static func bolt(host: Node, a: Vector3, b: Vector3, w: float, col: Color, life: float, n := 10, jag := 0.6) -> void:
	var mi = ribbon_mi(_jag(a, b, n, jag), w, col, true, {"taper": 0.25, "rag": 0.0, "core": 0.6})
	_put(host, mi, Vector3.ZERO)
	var regen = func():
		if is_instance_valid(mi):
			mi.mesh = _strip(_jag(a, b, n, jag), w, col)
	var tw = mi.create_tween()
	tw.tween_interval(life * 0.33)
	tw.tween_callback(regen)
	tw.tween_interval(life * 0.33)
	tw.tween_callback(regen)
	tw.tween_interval(life * 0.34)
	tw.tween_callback(mi.queue_free)


static func puff(host: Node, p: Vector3, r: float, life: float, lit: Color, shade: Color, vel := Vector3.ZERO, opa := 1.0) -> MeshInstance3D:
	var mi = _gi(_ball(), puff_mat())
	mi.set_instance_shader_parameter("lit", Vector3(lit.r, lit.g, lit.b))
	mi.set_instance_shader_parameter("shade", Vector3(shade.r, shade.g, shade.b))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("opa", opa)
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, p)
	mi.scale = Vector3.ONE * r * 0.35
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "position", p + vel * life, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Gölge klonu belirme / dağılma: kısa beyaz cel bulut halkası
static func poof(host: Node, p: Vector3, s := 0.8) -> void:
	puff(host, p, s * 0.9, 0.45, Color(1, 1, 1), Color(0.72, 0.74, 0.8))
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.4
		var o = Vector3(cos(a), randf_range(-0.6, 0.8), sin(a))
		puff(host, p + o * s * 0.35, s * randf_range(0.45, 0.65), 0.5, Color(1, 1, 1), Color(0.72, 0.74, 0.8), o * s * 1.4)


## Zemin izi: rx/rz yarıçaplı düzensiz leke, yaw açısında; kind 0 kavruk, 1 kırağı, 2 yağ
static func ground_mark(host: Node, p: Vector3, rx: float, rz: float, yaw: float, kind: float, life: float, grow_t := 0.3) -> MeshInstance3D:
	var mi = _gi(_plane(), ground_mat())
	mi.set_instance_shader_parameter("kind", kind)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("heat", 1.0)
	_put(host, mi, Vector3(p.x, Game.jutsu_floor_at(p).y + 0.06, p.z))
	mi.rotation.y = yaw
	mi.scale = Vector3(rx, 1.0, rz)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "grow"), 0.0, 1.0, grow_t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "heat"), 1.0, 0.0, life * 0.8)
	tw.chain().tween_method(_pf(mi, "fade"), 1.0, 0.0, minf(1.2, life * 0.3))
	tw.tween_callback(mi.queue_free)
	return mi


## Merkezden dışa zikzak zemin çatlakları (büyüyerek açılır, sonra söner)
static func cracks(host: Node, p: Vector3, R: float, n: int, col: Color, life: float) -> void:
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dv = Vector3(cos(a), 0, sin(a))
		var sv = dv.cross(Vector3.UP)
		var L = R * randf_range(0.5, 1.0)
		var pts = PackedVector3Array()
		for s in 8:
			var u = float(s) / 7.0
			var pp = p + dv * (L * u) + sv * randf_range(-0.35, 0.35) * u * 2.0
			pp.y = Game.jutsu_floor_at(pp).y + 0.08
			pts.append(pp)
		var mi = ribbon_mi(pts, 0.06, col, false, {"taper": 1.0, "rag": 0.3, "core": 0.0, "twin": false, "hint": Vector3.UP})
		_put(host, mi, Vector3.ZERO)
		mi.set_instance_shader_parameter("head", 0.0)
		var tw = mi.create_tween()
		tw.tween_method(_pf(mi, "head"), 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.1, life - 1.2))
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, 1.0)
		tw.tween_callback(mi.queue_free)


## Genişleyen basınç halkası (eksen hint: UP → yere paralel)
static func shock_ring(host: Node, p: Vector3, r0: float, r1: float, t: float, col: Color, w: float, axis := Vector3.UP) -> void:
	var pts = PackedVector3Array()
	for i in 41:
		var a = TAU * i / 40.0
		pts.append(Vector3(cos(a), 0, sin(a)))
	var mi = ribbon_mi(pts, w / r1, col, false, {"taper": 0.0, "rag": 0.45, "core": 0.0, "hint": Vector3.UP})
	_put(host, mi, p)
	mi.basis = _axis_basis(axis)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


static func _glow_mi(mesh: Mesh, col: Color, starry := false, rays := 6.0) -> MeshInstance3D:
	var mi = _gi(mesh, glow_mat())
	mi.set_instance_shader_parameter("gcol", Vector3(col.r, col.g, col.b))
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("star", 1.0 if starry else 0.0)
	mi.set_instance_shader_parameter("rays", rays)
	return mi


static func star(host: Node, p: Vector3, s: float, col: Color, life: float, rays := 6.0) -> MeshInstance3D:
	var mi = _glow_mi(_quad_c(), col, true, rays)
	_put(host, mi, p)
	mi.scale = Vector3.ONE * s * 0.3
	var tw = mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Hazırlık: renkli chakra zerreleri bir noktaya akar, sonunda küçük parıltı
static func gather(host: Node, to: Vector3, col: Color, t: float, n := 12, r := 1.5) -> void:
	for k in n:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()
		var mi = _glow_mi(_ball(), col)
		_put(host, mi, to + dv * r * randf_range(0.6, 1.0))
		mi.scale = Vector3.ONE * randf_range(0.05, 0.09)
		var tw = mi.create_tween()
		tw.tween_property(mi, "global_position", to, t * randf_range(0.6, 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	star(host, to, 0.9, col, t + 0.2, 4.0)


## Fırlayan parça: yerçekimiyle düşer, yere oturur (on_land verilirse orada biter), dönerek; sonda söner / küçülür
static func _toss(host: Node, mi: MeshInstance3D, p0: Vector3, v: Vector3, life: float, g := 18.0, fade_key := "", on_land := Callable()) -> void:
	_put(host, mi, p0)
	var spin = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	var stt = {"land": -1.0}
	var step = func(tm: float) -> void:
		if not is_instance_valid(mi) or stt["land"] >= 0.0:
			return
		var q = p0 + v * tm + Vector3.DOWN * 0.5 * g * tm * tm
		var fl = Game.jutsu_floor_at(q).y
		if tm > 0.05 and q.y <= fl + 0.04:
			q.y = fl + 0.04
			stt["land"] = tm
			if on_land.is_valid():
				on_land.call(q)
				mi.queue_free()
				return
		mi.global_position = q
		mi.rotation = spin * tm
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	if fade_key != "":
		tw.parallel().tween_method(_pf(mi, fade_key), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
	else:
		tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.01, life * 0.3).set_delay(life * 0.7)
	tw.chain().tween_callback(mi.queue_free)


static func rock_mi(s: float) -> MeshInstance3D:
	var vv = randi() % 5
	var key = "rock%d" % vv
	if not _cache.has(key):
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE, Color(0.5, 0.4, 0.3), Vector3.ZERO, vv + 1)
		_cache[key] = b.build(Props.toon())
	var mi = MeshInstance3D.new()
	mi.mesh = _cache[key]
	mi.scale = Vector3.ONE * s
	return mi


## Saçılan kaya parçaları + toz bulutu
static func rubble(host: Node, p: Vector3, n: int, spd: float, size: float) -> void:
	for k in n:
		var dv = Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)).normalized()
		_toss(host, rock_mi(size * randf_range(0.4, 1.0)), p, dv * spd * randf_range(0.6, 1.1), 1.4)
	puff(host, p, size * 2.0, 0.8, Color(0.8, 0.7, 0.56), Color(0.52, 0.43, 0.33), Vector3.UP * 1.0)


# ================================================================== yapı taşları: kristal / buz
static func gem(mesh: Mesh, tint: Color, frost := 0.0, glow := 0.3) -> MeshInstance3D:
	var mi = _gi(mesh, gem_mat())
	mi.set_instance_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mi.set_instance_shader_parameter("frost", frost)
	mi.set_instance_shader_parameter("glow", glow)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("mirror", 0.0)
	return mi


## Yerden fışkıran sivri kristal / buz: gecikme → yaylanarak büyür → bekler → parçalanır
static func spike(host: Node, p: Vector3, w: float, h: float, tint: Color, frost: float, ax: Vector3, delay: float, grow_t: float, hold: float, n_shards := 4) -> MeshInstance3D:
	var mi = gem(gem_mesh(randi() % 6), tint, frost, 0.35)
	_put(host, mi, p)
	mi.basis = _axis_basis(ax)
	mi.scale = Vector3(w * 0.5, 0.01, w * 0.5)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mi, "scale", Vector3(w, h, w), grow_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_callback(func():
		if n_shards > 0 and is_instance_valid(mi):
			shards(host, mi.global_position + ax.normalized() * h * 0.5, n_shards, 4.0, w * 0.6, tint, frost))
	tw.tween_property(mi, "scale", Vector3(w * 0.3, 0.01, w * 0.3), 0.15)
	tw.tween_callback(mi.queue_free)
	return mi


## Kırılan taş: yüzlü parçalar dönerek saçılır, yere düşüp söner; ince parıltı tozu
static func shards(host: Node, p: Vector3, n: int, spd: float, size: float, tint: Color, frost := 0.0, up := 0.7, life := 1.3) -> void:
	for k in n:
		var mi = gem(gem_mesh(randi() % 6, 5, 0.45), tint, frost, 0.5)
		var s = size * randf_range(0.45, 1.2)
		mi.scale = Vector3(s * 0.45, s, s * 0.45)
		var a = randf() * TAU
		var v = Vector3(cos(a), 0, sin(a)) * spd * randf_range(0.4, 1.0) + Vector3.UP * spd * up * randf_range(0.5, 1.2)
		_toss(host, mi, p + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2)), v, life, 18.0, "fade")
	sparks(host, p, {"n": n * 2, "life": 0.45, "vmin": spd * 0.5, "vmax": spd * 1.3, "size": 0.09, "g": Vector3(0, -6, 0),
		"cols": [Color(1, 1, 1, 1), tint, Color(tint.r, tint.g, tint.b, 0)]})


## Kar savrulması (beyaz ya da kara kar)
static func snow(host: Node, p: Vector3, s: float, black := false, n := 26) -> void:
	var c0 = Color(0.06, 0.06, 0.09, 1.0) if black else Color(1, 1, 1, 1)
	var c1 = Color(0.16, 0.16, 0.22, 0.0) if black else Color(0.86, 0.92, 1.0, 0.0)
	sparks(host, p, {"n": n, "life": 0.9, "r": 0.6 * s, "vmin": 2.0 * s, "vmax": 7.0 * s, "g": Vector3(0, -6.0, 0), "damp": 1.0,
		"size": minf(0.5, 0.17 * s), "add": false, "cols": [c0, c0, c1]})


# ================================================================== 1) Goton Dairendan no Jutsu
const ELCOL := [Color(0.85, 1.0, 0.92), Color(0.3, 0.6, 1.0), Color(0.75, 0.88, 1.0), Color(0.62, 0.48, 0.32)]


## ref: kullanıcının alevi ortada kalın turuncu akım; klonlardan beyaz yırtık rüzgâr şeridi, mavi su yayı, mavi-beyaz şimşek,
## içinde kaya parçaları olan kahverengi toprak seli — beşi hedefte birleşip beş renkli dev patlamaya döner
static func goton_dairendan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var id = "goton_dairendan_no_jutsu"
	pj.busy(c, 1.8)
	var tt = pj.tg(c, t, 34.0)
	var d = pj.fwd(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	var at = c.global_position
	var goal = pj.gp(tt.global_position if tt else at + d * 22.0) + Vector3.UP
	# dört gölge klon kullanıcının iki yanında belirir (içinde doğan klon yok), hepsi aynı anda aynı el pozunu verir;
	# kullanıcı ateşi, klonlar rüzgâr / su / şimşek / toprağı atar — beş element hedefte birleşip dev patlamaya döner
	var els = ["fuuton", "suiton", "raiton", "doton"]
	var offs = [-2.6, -1.3, 1.3, 2.6]
	var clones = []
	var mdl = c.get("model")
	for k in 4:
		var q = pj.gp(at + side * offs[k] - d * 0.4)
		poof(pj, q + Vector3.UP, 0.8)
		if mdl and "look" in mdl:
			var cm = CharacterModel.new()
			pj.get_tree().current_scene.add_child(cm)
			cm.setup(mdl.look)
			cm.global_position = q
			cm.rotation.y = mdl.global_rotation.y
			cm.scale = Vector3.ONE * float(cm.age_scale)
			cm.play("cast_in", 0.05, 1.2, true)
			clones.append(cm)
		else:
			clones.append(null)
	pj.anim(c, "cast_in", 1.2)
	# hazırlık: her elementin chakrası kendi renginde ağza / klonların ellerine toplanır
	gather(pj, _mouth(c), Color(1.0, 0.6, 0.15), 0.45)
	for k in 4:
		gather(pj, pj.gp(at + side * offs[k] - d * 0.4) + Vector3.UP * 1.4 + d * 0.6, ELCOL[k], 0.45, 8, 1.1)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		pj.anim(c, "push", 1.3)
		var from = _mouth(c)
		flame_stream(pj, c, from, (goal - from).normalized(), from.distance_to(goal), 3.5, 0.8)
		for k in 4:
			var cm = clones[k]
			var src = (cm.global_position + Vector3.UP * 1.4 + d * 0.6) if cm and is_instance_valid(cm) else from + side * offs[k]
			if cm and is_instance_valid(cm):
				cm.play("cast_out", 0.05, 1.3, true)
			match els[k]:
				"fuuton":
					_dr_wind(pj, src, goal, side)
				"suiton":
					_dr_water(pj, src, goal)
				"raiton":
					_dr_lightning(pj, src, goal)
				"doton":
					_dr_earth(pj, src, goal)
		# birleşme: hedefte beş renkli dev patlama
		pj.after(0.45, func():
			_dr_burst(pj, goal)
			for h in pj.hit(c, goal, 7.5, pj.inf(c, id, 3.4, {"knock": 26.0, "launch": 7.0, "kind": "heavy", "burn": 3.0, "stun": 0.8, "hitstop": 0.14})):
				pj.st(h, "slow", 2.0)
			if Game.world:
				Game.world.env.screen_flash(0.2)
			pj.shake(1.5))
		Combat.hit_zone(c, at, d, at.distance_to(goal) + 4.0, 40.0, 4.0, pj.inf(c, id, 1.0, {"knock": 8.0, "kind": "heavy"})))
	pj.after(1.6, func():
		for cm in clones:
			if cm and is_instance_valid(cm):
				poof(pj, cm.global_position + Vector3.UP, 0.8)
				cm.queue_free())
	Sfx.play("boom", c.global_position, 0.7)


static func _dr_wind(pj: PathJutsu, src: Vector3, goal: Vector3, side: Vector3) -> void:
	for q in 5:
		var ph = q * TAU / 5.0
		var pts = _path(func(u: float) -> Vector3:
			var a = ph + u * 9.0
			return src.lerp(goal, u) + (side * cos(a) + Vector3.UP * sin(a)) * (0.25 + u * 0.7), 18)
		streak(pj, pts, 0.14, Color(0.92, 1.0, 0.96, 0.9), 0.5, false, {"rag": 0.5, "core": 0.0, "delay": q * 0.03})
	# ref: beyaz, kenarı tırtıklı kalın rüzgâr yaprağı
	streak(pj, _path(func(u: float) -> Vector3: return src.lerp(goal, u) + Vector3.UP * sin(u * PI) * 0.6, 14), 0.55,
		Color(0.95, 0.97, 0.97, 0.85), 0.55, false, {"rag": 0.65, "core": 0.25})


static func _dr_water(pj: PathJutsu, src: Vector3, goal: Vector3) -> void:
	var dirv = (goal - src).normalized()
	for q in 3:
		var off = Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
		var pts = _path(func(u: float) -> Vector3: return src.lerp(goal, u) + off * sin(u * PI) + Vector3.UP * sin(u * PI) * 0.8, 16)
		streak(pj, pts, 0.42 - q * 0.1, Color(0.25, 0.55, 0.95, 0.95), 0.55, false, {"core": 0.45, "rag": 0.15, "delay": q * 0.05})
	sparks(pj, src, {"n": 16, "life": 0.5, "dir": dirv, "spread": 20.0, "vmin": 8.0, "vmax": 14.0, "g": Vector3(0, -12, 0), "size": 0.14,
		"add": false, "cols": [Color(1, 1, 1, 1), Color(0.5, 0.8, 1, 0.9), Color(0.3, 0.6, 1, 0)]})


static func _dr_lightning(pj: PathJutsu, src: Vector3, goal: Vector3) -> void:
	for q in 6:
		pj.after(q * 0.08, func():
			bolt(pj, src, goal, 0.12, Color(0.7, 0.85, 1.0), 0.2, 12, 1.2))


static func _dr_earth(pj: PathJutsu, src: Vector3, goal: Vector3) -> void:
	# ref: içinde iri taşlar olan kahverengi toprak seli
	streak(pj, _path(func(u: float) -> Vector3: return src.lerp(goal, u) - Vector3.UP * sin(u * PI) * 0.3, 12), 0.5,
		Color(0.6, 0.47, 0.32, 0.9), 0.5, false, {"rag": 0.5, "core": 0.0})
	for q in 6:
		pj.after(q * 0.06, func():
			var rk = rock_mi(randf_range(0.5, 1.0))
			_put(pj, rk, src)
			var end = goal + Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5))
			var tw = rk.create_tween().set_parallel()
			tw.tween_property(rk, "global_position", end, 0.4)
			tw.tween_property(rk, "rotation", Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 0.4)
			tw.chain().tween_callback(func():
				if is_instance_valid(rk):
					rubble(pj, rk.global_position, 5, 5.0, 0.35)
					rk.queue_free()))


static func _dr_burst(pj: PathJutsu, p: Vector3) -> void:
	fire_blob(pj, p, 1.0, 5.0, 0.9)
	fire_blob(pj, p + Vector3.UP * 1.4, 0.8, 3.4, 0.75)
	star(pj, p, 7.0, Color(1, 1, 0.9), 0.3, 8.0)
	light(pj, p + Vector3.UP, Color(1.0, 0.7, 0.4), 10.0, 22.0, 1.0)
	for k in 14:   # rüzgârla dışa savrulan alev dilleri
		var a = k * TAU / 14.0
		var o = Vector3(cos(a), 0, sin(a))
		tongue(pj, pj.gp(p + o * 2.0), randf_range(2.5, 4.0), 1.6, 0.8, (o + Vector3.UP * 0.9).normalized(), o * 6.0)
	for k in 6:   # şimşek kolları
		var dv = Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)).normalized()
		bolt(pj, p, p + dv * randf_range(4.0, 7.0), 0.1, Color(0.75, 0.88, 1.0), 0.3, 8, 0.9)
	shock_ring(pj, pj.gp(p) + Vector3.UP * 0.4, 1.0, 9.0, 0.45, Color(0.92, 1.0, 0.96, 0.9), 0.5)
	sparks(pj, p, {"n": 30, "life": 0.8, "vmin": 6.0, "vmax": 12.0, "g": Vector3(0, -14, 0), "size": 0.16, "add": false,
		"cols": [Color(1, 1, 1, 1), Color(0.5, 0.8, 1, 0.9), Color(0.3, 0.6, 1, 0)]})
	rubble(pj, p, 8, 9.0, 0.5)
	embers(pj, p, 30, 3.0, 6.0)
	ground_mark(pj, p, 7.0, 7.0, randf() * TAU, 0.0, 6.0)
	cracks(pj, pj.gp(p), 10.0, 9, Color(0.08, 0.05, 0.04, 1.0), 6.0)


# ================================================================== 2) Kimen no Bakuen
## ref (Kakuzu): sırttaki kara iplik yığınından iki beyaz dikişli maske çıkar — biri ağzından sarı-turuncu ateş topu, öbürü beyaz
## dönen rüzgâr küresi tükürür; rüzgâr ateşi sarar, hedefte rüzgârla şişen dev patlama
static func kimen_no_bakuen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	var at = (tt.global_position + Vector3.UP if tt else c.global_position + pj.fwd(c, t) * 12.0 + Vector3.UP)
	var from0 = _mouth(c)
	var dd = (at - from0).normalized()
	var sd = dd.cross(Vector3.UP).normalized()
	var upv = sd.cross(dd).normalized()
	var back = c.global_position + Vector3.UP * 1.25 - c.face_dir() * 0.25
	var fmask = _mask(pj, back, from0 - sd * 0.9 + Vector3.UP * 0.35, dd, true)
	var wmask = _mask(pj, back, from0 + sd * 0.9 + Vector3.UP * 0.35, dd, false)
	var f0: Vector3 = fmask["mouth"]
	var w0: Vector3 = wmask["mouth"]
	# ateş topu: hacimli alev küresi, arkasında kuyruklu yıldız gibi yatık diller
	var fb = Node3D.new()
	_put(pj, fb, f0)
	var core = _gi(_quad_c(), fire_mat())
	core.set_instance_shader_parameter("vol", 1.0)
	core.set_instance_shader_parameter("heat", 1.35)
	core.set_instance_shader_parameter("seed", randf() * 10.0)
	core.set_instance_shader_parameter("fade", 1.0)
	core.set_instance_shader_parameter("lava", 0.0)
	fb.add_child(core)
	core.scale = Vector3.ONE * 1.3
	var fl = OmniLight3D.new()
	fl.light_color = Color(1.0, 0.6, 0.25)
	fl.light_energy = 3.0
	fl.omni_range = 7.0
	fb.add_child(fl)
	var tw = fb.create_tween()
	tw.tween_property(fb, "global_position", at, 0.6)
	tw.parallel().tween_property(fb, "scale", Vector3.ONE * 4.0, 0.6)
	tw.tween_callback(func():
		_bakuen_burst(pj, at)
		if is_instance_valid(c):
			pj.hit(c, at, 6.0, pj.inf(c, "kimen_no_bakuen", 2.2, {"knock": 18.0, "launch": 6.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
		pj.shake(1.0)
		fb.queue_free())
	pj.every(0.6, 0.04, func(_i, _k):
		if is_instance_valid(fb):
			var s = fb.scale.x
			tongue(pj, fb.global_position - dd * s * 0.35, s * 0.9, s * 0.55, 0.3, (-dd + Vector3.UP * 0.4).normalized(), -dd * 2.0))
	# rüzgâr küresi: soluk saydam küre + çevresinde dönen beyaz rüzgâr halkaları
	var wb = Node3D.new()
	_put(pj, wb, w0)
	var wg = _glow_mi(_ball(), Color(0.7, 0.8, 0.9))
	wg.set_instance_shader_parameter("fade", 0.5)
	wb.add_child(wg)
	wg.scale = Vector3.ONE * 0.7
	for q in 3:
		var pts = PackedVector3Array()
		for i in 25:
			var a = TAU * i / 24.0 * 0.85
			pts.append(Vector3(cos(a), 0, sin(a)) * (0.8 + q * 0.12))
		var rg = ribbon_mi(pts, 0.1, Color(0.95, 0.98, 1.0, 0.85), false, {"taper": 1.0, "rag": 0.5, "core": 0.0})
		wb.add_child(rg)
		rg.rotation = Vector3(q * 1.05, q * 0.7, q * 0.4)
	var tw2 = wb.create_tween()
	tw2.tween_property(wb, "global_position", at, 0.55)
	tw2.parallel().tween_property(wb, "scale", Vector3.ONE * 2.4, 0.55)
	tw2.parallel().tween_property(wb, "rotation", Vector3(0.0, TAU * 3.0, TAU * 1.5), 0.55)
	tw2.tween_callback(wb.queue_free)
	# rüzgâr ateşi besler: ağızdan hedefe sarmal rüzgâr çizgileri ateş topunu sarar
	for k in 6:
		var ph = k * TAU / 6.0
		var pts = _path(func(q: float) -> Vector3:
			var a = ph + q * 9.0
			return from0.lerp(at, q) + (sd * cos(a) + upv * sin(a)) * (0.6 + q * 1.8), 20)
		streak(pj, pts, 0.07, Color(0.88, 0.96, 1.0, 0.9), 0.6, false, {"rag": 0.4, "core": 0.0, "delay": k * 0.04})
	Sfx.play("wind", c.global_position, 0.9)
	Sfx.play("fire", c.global_position, 0.6)


## Dikişli beyaz maske: sırttan kara ipliklerle uzanır, ağız açık (ateş: turuncu dudak, rüzgâr: soluk mavi)
static func _mask(pj: PathJutsu, back: Vector3, pos: Vector3, look: Vector3, fire: bool) -> Dictionary:
	var mi = MeshInstance3D.new()
	mi.mesh = _mask_mesh(fire)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(pj, mi, back)
	mi.global_basis = Basis.looking_at(-look, Vector3.UP)
	mi.scale = Vector3.ONE * 0.1
	var tw = mi.create_tween()
	tw.tween_property(mi, "global_position", pos, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.85, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(mi, "global_position", back, 0.2).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * 0.05, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	# kara iplikler: sırttan maskenin kenarına kıvrılarak uzanan ince siyah teller
	for k in 7:
		var bend = Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.5), randf_range(-0.5, 0.5))
		var tip = pos + Vector3(randf_range(-0.3, 0.3), randf_range(-0.35, 0.35), randf_range(-0.3, 0.3))
		var pts = _path(func(u: float) -> Vector3: return back.lerp(tip, u) + bend * sin(u * PI), 10)
		streak(pj, pts, 0.03, Color(0.05, 0.04, 0.04, 1.0), 1.0, false, {"taper": 0.0, "rag": 0.3, "core": 0.0, "travel": false})
	return {"mi": mi, "mouth": pos + look * 0.12 - Vector3.UP * 0.16}


static func _mask_mesh(fire: bool) -> ArrayMesh:
	var key = "mask_f" if fire else "mask_w"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var white = Color(0.94, 0.93, 0.88)
	var ink = Color(0.12, 0.1, 0.1)
	b.add("sphere", Vector3.ZERO, Vector3(0.62, 0.74, 0.2), white, Vector3.ZERO, 16)
	b.add("sphere", Vector3(0, 0, -0.02), Vector3(0.6, 0.72, 0.1), Color(0.82, 0.8, 0.76), Vector3.ZERO, 16)   # arka yüz de beyaz (arkadan kara disk görünmesin)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.15, 0.12, 0.085), Vector3(0.12, 0.17, 0.05), ink)
		b.add("box", Vector3(sx * 0.15, 0.25, 0.09), Vector3(0.16, 0.022, 0.02), ink, Vector3(0, 0, sx * -12.0))
	var lip = Color(0.95, 0.42, 0.15) if fire else Color(0.62, 0.76, 0.9)
	b.add("sphere", Vector3(0, -0.19, 0.08), Vector3(0.3, 0.22, 0.06), lip)
	b.add("sphere", Vector3(0, -0.19, 0.096), Vector3(0.22, 0.15, 0.05), Color(0.05, 0.03, 0.03))
	for k in 14:   # kenar dikişleri
		var a = k * TAU / 14.0
		b.add("box", Vector3(cos(a) * 0.31, sin(a) * 0.37, 0.02), Vector3(0.014, 0.08, 0.02), ink, Vector3(0, 0, rad_to_deg(a) - 90.0))
	var m = b.build(Props.toon())
	_cache[key] = m
	return m


static func _bakuen_burst(pj: PathJutsu, at: Vector3) -> void:
	fire_blob(pj, at, 1.2, 6.5, 0.9)
	fire_blob(pj, at + Vector3.UP * 1.5, 1.0, 4.5, 0.75)
	star(pj, at, 6.0, Color(1.0, 0.95, 0.8), 0.3, 8.0)
	light(pj, at, Color(1.0, 0.6, 0.25), 12.0, 20.0, 1.0)
	shock_ring(pj, at, 1.0, 10.0, 0.5, Color(0.95, 0.98, 1.0, 0.9), 0.6)
	for k in 18:   # rüzgârla dışa savrulan alev dilleri
		var a = k * TAU / 18.0
		var o = Vector3(cos(a), 0, sin(a))
		tongue(pj, at + o * 1.5 - Vector3.UP * 0.6, randf_range(3.0, 4.5), 1.8, 0.7, (o + Vector3.UP * 0.5).normalized(), o * 9.0)
	for k in 6:   # patlamayı saran rüzgâr sarmalı
		var ph = k * TAU / 6.0
		var pts = _path(func(u: float) -> Vector3:
			var a = ph + u * 5.0
			return at + Vector3(cos(a), 0, sin(a)) * (1.0 + u * 7.0) + Vector3.UP * u * 3.0, 16)
		streak(pj, pts, 0.18, Color(0.92, 0.97, 1.0, 0.85), 0.6, false, {"rag": 0.5, "core": 0.0, "delay": k * 0.02})
	embers(pj, at, 40, 3.0, 8.0)
	if at.y - Game.jutsu_floor_at(at).y < 3.0:
		ground_mark(pj, at, 6.0, 6.0, randf() * TAU, 0.0, 6.0)


# ================================================================== 3) Uzusenpuhi no Jutsu
## ref: yerden yükselen göz kamaştırıcı alev perdesi (beyaz-sarı göbek, kızıl kenarlı diller), rüzgâr yumruğuyla
## öne savrulup genişleyen alev fırtınasına döner; arkada kavrulmuş toprak kalır
## Ateş teknikleri (Uzusenpūhi, Kaenbu, Ryūka) Katon'un kendi kütüphanesini kullanır: opak alev dili / alev topağı / kor
static func _kt(host: Node, p: Vector3, h: float, w: float, life: float, ax := Vector3.UP, vel := Vector3.ZERO, heat0 := 1.15, _oily := false) -> MeshInstance3D:
	return KatonLib.tongue(host, p, h, w, life, ax, vel, KatonLib.PAL_FIRE, 4, minf(heat0, 1.2))


static func _kb(host: Node, p: Vector3, r0: float, r1: float, life: float, vel := Vector3.ZERO, _x := false, _h := 1.25) -> MeshInstance3D:
	return KatonLib.fire_puff(host, p, r0, r1, life, vel, KatonLib.PAL_FIRE, 1.15, 0.6)


static func _ke(host: Node, p: Vector3, n: int, spread_r: float, up := 3.0) -> void:
	KatonLib.embers(host, p, n, spread_r, KatonLib.PAL_FIRE, {"vmin": up * 0.5, "vmax": up * 1.3, "life": 0.9})


## Ağızdan fışkıran alev akımı (Katon kütüphanesiyle): yol boyunca hızla öne akan, büyüyüp kabaran alev topakları; eski ortak
## alev akımı yerine (yağlı ateş tekniklerinin akımı)
static func _kstream(pj: PathJutsu, c: Node3D, from: Vector3, d: Vector3, L: float, W: float, dur: float, _oily := false) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var spd = L / 0.3
	pj.every(dur, 0.035, func(i, _k):
		var src = KatonLib_src(pj, c, from)
		var reach = minf(L, (i + 1) * 0.035 * spd)
		# akım: ağızdan uca kadar yol boyunca dağılan, uca doğru büyüyüp kabaran alev topakları (kopuk top değil, kesintisiz sel)
		for q in 6 + int(W * 0.5):   # geniş akımda daha çok topak (sel boşluksuz)
			var u = pow(randf(), 0.8)
			var sz = lerpf(0.35, W * 0.42, u)
			var p = src + d * (u * reach) + side * randf_range(-0.5, 0.5) * sz + Vector3.UP * randf_range(-0.3, 0.3) * sz
			KatonLib.fire_puff(pj, p, sz * 0.45, sz, 0.32, d * 9.0 + Vector3.UP * 0.8, KatonLib.PAL_FIRE, 1.15, 0.6), Callable())


static func KatonLib_src(pj: PathJutsu, c: Node3D, from: Vector3) -> Vector3:
	return _mouth(c) if pj.live(c) else from


static func uzusenpuhi_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.5)
	var id = "uzusenpuhi_no_jutsu"
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	d.y = 0.0
	d = d.normalized()
	var side = d.cross(Vector3.UP).normalized()
	var wc: Vector3 = pj.gp(c.global_position + d * 3.2)
	var cw = weakref(c)
	pj._yama_seal(c)
	Sfx.play("fire", c.global_position, 0.9)
	light(pj, wc + Vector3.UP * 1.5, Color(1.0, 0.6, 0.2), 6.0, 12.0, 1.4)
	ground_mark(pj, wc, 3.8, 1.0, atan2(-side.z, side.x), 0.0, 3.0, 0.3)
	# 1) alev duvarı: yerden yükselen alev perdesi
	var wall = func(i, k):
		var hgt = 3.4 * minf(1.0, k * 3.0)
		for j in 1:
			var p = wc + side * randf_range(-3.2, 3.2)
			p.y = Game.jutsu_floor_at(p).y
			_kt(pj, p, maxf(0.8, hgt * randf_range(0.6, 0.9)), randf_range(0.9, 1.3), 0.5, Vector3.UP, Vector3.UP * 0.8, 1.2)
		for j in 2:   # perde gövdesi: yükselen alev topakları (dik kart dizisi düz görünüyordu)
			var bp2 = wc + side * randf_range(-3.0, 3.0)
			bp2.y = Game.jutsu_floor_at(bp2).y + randf_range(0.3, maxf(0.4, hgt * 0.8))
			_kb(pj, bp2, 0.3, randf_range(0.7, 1.0), 0.5, Vector3.UP * 2.8)
		if i % 2 == 0:
			var bp = wc + side * randf_range(-2.8, 2.8)
			bp.y = Game.jutsu_floor_at(bp).y + randf_range(0.5, maxf(0.6, hgt * 0.7))
			_kb(pj, bp, 0.3, 0.9, 0.45, Vector3.UP * 2.5)
		if i % 4 == 0:
			_ke(pj, wc + Vector3.UP * 1.5, 8, 3.0, 5.0)
		var cc = cw.get_ref()
		if cc != null and pj.live(cc) and i % 5 == 0:
			for e in pj.enemies_near(cc, wc, 3.6):
				var v: Vector3 = e.global_position - wc
				if absf(v.dot(d)) < 1.1:
					e.take_hit(pj.inf(cc, id, 0.2, {"knock": 2.0, "kind": "light", "element": "katon", "burn": 2.0}))
	pj.every(0.75, 0.04, wall, Callable())
	# 2) rüzgâr yumruğu: alev öne savrulur
	var punch = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj.anim(cc, "cross", 1.8)
		var from = cc.global_position + Vector3.UP * 1.1 + d * 0.8
		for q in 12:   # yumruğun basınç çizgileri perdeyi iter
			var o = side * randf_range(-2.5, 2.5) + Vector3.UP * randf_range(-0.8, 1.6)
			var pts = _path(func(u: float) -> Vector3: return from + o * u + d * (u * 16.0), 8)
			streak(pj, pts, 0.12, Color(1.0, 0.97, 0.92, 0.85), 0.4, false, {"rag": 0.4, "core": 0.0, "delay": q * 0.012})
		Sfx.play("wind", from, 0.7)
		Sfx.play("fire", wc, 0.5)
		pj.shake(0.7)
		var storm = func(i, k):
			var front = 3.0 + k * 14.0
			for j in 1:
				var u = randf()
				var p = wc + d * (u * front) + side * randf_range(-1.0, 1.0) * (2.0 + u * front * 0.22)
				p.y = Game.jutsu_floor_at(p).y
				_kt(pj, p, randf_range(2.4, 4.2), randf_range(1.6, 2.4), 0.45, (d * 1.1 + Vector3.UP).normalized(), d * 12.0, 1.25)
			var bp = wc + d * front * randf_range(0.5, 1.0) + side * randf_range(-1.5, 1.5) * (1.0 + front * 0.15)
			bp.y = Game.jutsu_floor_at(bp).y + 1.2
			for j2 in 3:   # ateş fırtınası gövdesi: öne savrulan kabaran alev topakları
				var bp3 = wc + d * front * randf_range(0.2, 1.0) + side * randf_range(-1.5, 1.5) * (1.0 + front * 0.15)
				bp3.y = Game.jutsu_floor_at(bp3).y + randf_range(0.6, 2.0)
				_kb(pj, bp3, 0.6, randf_range(1.6, 2.4), 0.5, d * 12.0 + Vector3.UP * 1.5)
			if i % 3 == 0:
				_ke(pj, wc + d * front * 0.6 + Vector3.UP, 10, 3.0, 9.0)
			var c2 = cw.get_ref()
			if c2 != null and pj.live(c2) and i % 4 == 1:
				Combat.hit_zone(c2, wc - d * 0.5, d, front + 2.0, 24.0, 4.0, pj.inf(c2, id, 0.5, {"knock": 6.0, "kind": "heavy", "element": "katon", "burn": 3.0, "hitstop": 0.02}))
		var scorch = func():
			for k in 4:   # kavrulan zemin
				var p = pj.gp(wc + d * (2.0 + k * 4.0))
				ground_mark(pj, p, 2.8 + k * 0.4, 2.2, randf() * TAU, 0.0, 6.0)
		pj.every(0.8, 0.05, storm, scorch)
	pj.after(0.7, punch)


# ================================================================== 4) Katon: Kaenbu no Jutsu
## Ateş dansı: kullanıcının çevresinde dönen alev kurdeleleri, savrulan alevli sis (yarı saydam sıcak turuncu cel sis),
## teğet yönde yalayan diller, yükselen kül ve köz; yerde halka biçimli kavruk iz
static func katon_kaenbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(c.global_position)
	ground_mark(pj, at, 4.5, 4.5, randf() * TAU, 0.0, 4.0, 0.6)
	light(pj, at + Vector3.UP * 1.2, Color(1.0, 0.55, 0.2), 4.0, 9.0, 3.2)
	var rig = Node3D.new()
	_put(pj, rig, at)
	for q in 0:   # şerit kurdele kaldırıldı (düz boru gibi): dans eden alev = vortex_tick topakları (aşağıda)
		var ph = q * TAU / 3.0
		var pts = _path(func(u: float) -> Vector3:
			var a = ph + u * TAU * 1.2
			var r = 1.6 + u * 2.2
			return Vector3(cos(a) * r, 0.3 + u * 2.4 + sin(u * 9.0) * 0.25, sin(a) * r), 28)
		var rb = ribbon_mi(pts, 0.22, Color(1.0, 0.45, 0.08, 0.7), true, {"taper": 1.0, "rag": 0.55, "core": 0.18})
		rig.add_child(rb)
		var tf = rb.create_tween()
		tf.tween_interval(2.5)
		tf.tween_method(_pf(rb, "fade"), 1.0, 0.0, 0.5)
	var tr = rig.create_tween()
	tr.tween_property(rig, "rotation:y", TAU * 2.5, 3.0)
	tr.tween_callback(rig.queue_free)
	pj.every(3.0, 0.1, func(_i, _k):
		KatonLib.vortex_tick(pj, at, 1.4, 4.0, 2.6, 4, KatonLib.PAL_FIRE, 1.0, 0.55)
		if _i % 2 == 1:
			return
		for q in 2:
			var a = randf() * TAU
			var r = randf_range(1.2, 4.0)
			var p = at + Vector3(cos(a), 0, sin(a)) * r
			p.y = Game.jutsu_floor_at(p).y
			var tg_v = Vector3(-sin(a), 0, cos(a))
			_kt(pj, p, randf_range(1.2, 2.4), 0.9, 0.6, (tg_v * 0.7 + Vector3.UP).normalized(), tg_v * 4.0)
		for q in 2:   # alevli sis: düşük ısılı, yarı saydam kızıl-turuncu alev kütleleri teğet savrulur
			var a2 = randf() * TAU
			var r2 = randf_range(1.5, 4.0)
			var tg2 = Vector3(-sin(a2), 0, cos(a2))
			_kb(pj, at + Vector3(cos(a2), 0, sin(a2)) * r2 + Vector3.UP * randf_range(0.5, 1.6), 0.5, randf_range(1.0, 1.5), 1.1,
				tg2 * 2.5 + Vector3.UP * 0.6, false, 0.62)
		sparks(pj, at + Vector3.UP * 0.8, {"n": 10, "life": 1.4, "r": 3.5, "dir": Vector3.UP, "spread": 60.0, "vmin": 0.8, "vmax": 2.2,
			"g": Vector3(0, 0.6, 0), "size": 0.1, "burst": 0.3, "add": false,
			"cols": [Color(1.0, 0.6, 0.2, 1.0), Color(0.3, 0.27, 0.25, 0.9), Color(0.2, 0.18, 0.17, 0.0)]})
		for e in pj.enemies_near(c, at, 4.5):
			if pj.live(e):
				if e.has_method("lose_target"):
					e.lose_target(0.6)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "katon_kaenbu", 0.15, {"knock": 0.0, "kind": "light", "element": "katon", "burn": 1.0})), Callable())
	Sfx.play("fire", at, 0.9)


# ================================================================== 5) Katon: Ryūka no Jutsu
## Ağızdan hedefe uzanan ince çelik tel; alev telin ÜSTÜNDEN koşar (önde parlak alev başı, arkasında yükselen küçük diller),
## geçtiği yerde tel kızarır; uçta alev patlaması
static func katon_ryuka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	var st0 = {"u": 0.0, "done": false}
	var end_of = func() -> Vector3:
		if tt and pj.live(tt):
			return tt.global_position + Vector3.UP
		return _mouth(c) + c.face_dir() * 20.0 if pj.live(c) else c.global_position
	var wire = _gi(ArrayMesh.new(), ribbon_mat(false))
	wire.set_instance_shader_parameter("taper", 0.0)
	wire.set_instance_shader_parameter("rag", 0.0)
	wire.set_instance_shader_parameter("core", 0.35)
	wire.set_instance_shader_parameter("head", 1.0)
	wire.set_instance_shader_parameter("tail", 0.0)
	wire.set_instance_shader_parameter("fade", 1.0)
	wire.set_instance_shader_parameter("seed", 0.0)
	_put(pj, wire, Vector3.ZERO)
	var tick = func(_i, _k):
		if not pj.live(c):
			return
		var mo = _mouth(c)
		var end: Vector3 = end_of.call()
		var mid = mo.lerp(end, 0.5) - Vector3.UP * 0.3
		var u: float = st0["u"]
		var pts = PackedVector3Array()
		var cols = PackedColorArray()
		for s in 17:
			var w = s / 16.0
			pts.append(mo.lerp(mid, w).lerp(mid.lerp(end, w), w))
			cols.append(Color(1.0, 0.45, 0.12, 1.0) if w < u else Color(0.78, 0.8, 0.86, 1.0))
		if is_instance_valid(wire):
			wire.mesh = _strip(pts, 0.016, Color.WHITE, true, cols)
		if st0["done"]:
			return
		st0["u"] = minf(1.0, u + 0.075)
		u = st0["u"]
		for q in 2:
			var w2 = clampf(u - randf() * 0.12, 0.0, 1.0)
			var p = mo.lerp(mid, w2).lerp(mid.lerp(end, w2), w2)
			_kt(pj, p, randf_range(0.5, 0.9), 0.4, 0.32, Vector3.UP, Vector3.UP * 0.8)
		_kb(pj, mo.lerp(mid, u).lerp(mid.lerp(end, u), u), 0.22, 0.45, 0.14)
		if _i % 5 == 0:
			_ke(pj, mo.lerp(end, u), 5, 0.3, 2.0)
		if u >= 1.0:
			st0["done"] = true
			_ryuka_burst(pj, end)
			pj.hit(c, end, 2.8, pj.inf(c, "katon_ryuka", 1.8, {"knock": 10.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
	var done = func():
		if is_instance_valid(wire):
			var tw = wire.create_tween()
			tw.tween_method(_pf(wire, "fade"), 1.0, 0.0, 0.4)
			tw.tween_callback(wire.queue_free)
	pj.every(1.0, 0.03, tick, done)
	Sfx.play("fire", c.global_position, 0.8)


static func _ryuka_burst(pj: PathJutsu, p: Vector3) -> void:
	_kb(pj, p, 0.4, 2.2, 0.55)
	for k in 9:
		var a = k * TAU / 9.0
		var o = Vector3(cos(a), 0, sin(a))
		_kt(pj, p - Vector3.UP * 0.6 + o * 0.6, 1.6, 0.9, 0.5, (o + Vector3.UP * 1.2).normalized(), o * 3.0)
	KatonLib.fireball_impact(pj, p, 1.0, KatonLib.PAL_FIRE)
	_ke(pj, p, 16, 1.0, 4.0)
	light(pj, p, Color(1.0, 0.55, 0.2), 5.0, 8.0, 0.6)
	if p.y - Game.jutsu_floor_at(p).y < 2.5:
		ground_mark(pj, p, 1.8, 1.8, randf() * TAU, 0.0, 4.0)


# ================================================================== 6) Fūton: Gamayu Endan
## Kurbağa yağı mermisi (parlak amber damla, arkasında yere düşen yağ damlaları) → rüzgâr şeritleri yağı ateşle birlikte
## dev, yağlı (sarı-turuncu) alev fırtınasına çevirir; yolda yağ lekeleri yanmaya devam eder
static func futon_gamayu_endan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var id = "futon_gamayu_endan"
	var d = pj.fwd(c, t)
	var head = Node3D.new()
	var blob = _gi(_ball(), oil_mat())
	blob.set_instance_shader_parameter("fade", 1.0)
	blob.set_instance_shader_parameter("hot", 0.0)
	head.add_child(blob)
	blob.scale = Vector3(0.6, 0.6, 1.2)
	var trail = ribbon_mi(PackedVector3Array([Vector3(0, 0, 0.4), Vector3(0, 0, 2.6)]), 0.45, Color(0.88, 0.62, 0.2, 1.0), false, {"taper": 1.0, "rag": 0.2, "core": 0.25, "hint": Vector3.UP})
	head.add_child(trail)
	var pr = pj.shot(c, _mouth(c), d, 30.0, head, pj.inf(c, id, 0.1, {"element": "katon"}), null, false, 0.7, func(p, _h):
		_oil_splash(pj, p, 1.6))
	pr.radius = maxf(0.5, 1.0)
	var pw = weakref(pr)
	pj.every(0.7, 0.05, func(_i, _k):
		var x = pw.get_ref()
		if x != null and is_instance_valid(x) and not x.dead:
			oil_drop(pj, x.global_position, x.vel * 0.25))
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var mo = _mouth(c)
		var sd = d.cross(Vector3.UP).normalized()
		for q in 10:   # rüzgâr: kalın, sıcak beyaz basınç şeritleri
			var o = sd * randf_range(-2.4, 2.4) + Vector3.UP * randf_range(-0.6, 1.8)
			var base = c.global_position + Vector3.UP * 1.2
			streak(pj, _path(func(u: float) -> Vector3: return base + o * u + d * (u * 32.0), 10), 0.14, Color(1.0, 0.93, 0.78, 0.85), 0.5, false,
				{"rag": 0.45, "core": 0.0, "delay": q * 0.02})
		_kstream(pj, c, mo, d, 34.0, 10.0, 1.1, true)   # dev alev fırtınası (kullanıcı: basic kalıyordu)
		pj.after(0.45, func():
			_kb(pj, mo + d * 32.0, 1.0, 4.0, 0.7, Vector3.ZERO, true)
			_ke(pj, mo + d * 32.0, 30, 3.0, 6.0)
			Combat.hit_zone(c, c.global_position, d, 32.0, 20.0, 4.0 * 1.5, pj.inf(c, id, 3.0, {"knock": 8.0, "kind": "heavy", "element": "katon", "burn": 3.0, "dir": d})))
		for k in 4:
			GroundFX.add(c.global_position + d * (8.0 + k * 6.0), "burning", 5.0, 5.0, c)
			_burning_oil(pj, c.global_position + d * (8.0 + k * 6.0), 3.5, 5.0)
		pj.shake(1.4))
	Sfx.play("fire", c.global_position, 0.4)


static func oil_drop(host: Node, p: Vector3, v: Vector3) -> void:
	var mi = _gi(_ball(), oil_mat())
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("hot", 0.0)
	mi.scale = Vector3.ONE * randf_range(0.08, 0.16)
	_toss(host, mi, p, v + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)), 1.5, 18.0, "", func(lp: Vector3):
		ground_mark(host, lp, 0.5, 0.5, randf() * TAU, 2.0, 3.0, 0.1))


static func _oil_splash(pj: PathJutsu, p: Vector3, s: float) -> void:
	for k in 10:
		var a = randf() * TAU
		oil_drop(pj, p, Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 5.0) + Vector3.UP * randf_range(2.0, 5.0))
	ground_mark(pj, p, s, s, randf() * TAU, 2.0, 3.0, 0.15)
	puff(pj, p, s * 0.7, 0.5, Color(0.98, 0.84, 0.5), Color(0.78, 0.52, 0.16), Vector3.UP * 1.0)


## Yanan yağ birikintisi: amber leke, üstünde kaynayan kabarcıklar ve yer yer fışkıran alev dilleri
static func _burning_oil(pj: PathJutsu, p: Vector3, r: float, dur: float) -> void:
	var at = pj.gp(p)
	ground_mark(pj, at, r, r * 0.8, randf() * TAU, 2.0, dur + 0.5, 0.4)
	pj.every(dur, 0.25, func(i, _k):
		var q = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * r * 0.7
		q.y = Game.jutsu_floor_at(q).y
		_kt(pj, q, randf_range(1.0, 2.0), randf_range(0.7, 1.1), 0.6, Vector3.UP, Vector3.UP * 0.6, 1.1, true)
		if i % 2 == 0:
			bubble(pj, q + Vector3.UP * 0.05)
		if i % 5 == 0:
			_ke(pj, at + Vector3.UP * 0.5, 6, r * 0.6, 3.0), Callable())


## Kaynar yağ sırtı: yassı, topaklı amber kütle yerden kabarır, ileri yuvarlanır, sıcak parlayıp yere çöker
static func oil_crest(host: Node, p: Vector3, s: float, d: Vector3) -> void:
	var mi = _gi(_ball(), oil_mat())
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("hot", 0.25)
	mi.set_instance_shader_parameter("lump", 0.5)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	var g = Game.jutsu_floor_at(p)
	_put(host, mi, g)
	_look(mi, d)
	mi.scale = Vector3(s * 1.2, 0.05, s * 0.7)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(s * 1.5, s * 0.55, s * 0.9), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "global_position", g + d * 1.2, 0.8)
	tw.tween_property(mi, "scale", Vector3(s * 1.8, 0.03, s * 1.1), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


static func bubble(host: Node, p: Vector3, s := 0.25) -> void:
	var mi = _gi(_ball(), oil_mat())
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("hot", 0.4)
	_put(host, mi, p)
	mi.scale = Vector3.ONE * 0.02
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(s, s * 0.7, s), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(s * 1.3, s * 0.15, s * 1.3), 0.06)
	tw.tween_callback(mi.queue_free)


# ================================================================== 7) Senpō: Goemon
## ref: omuzlardaki iki yaşlı kurbağa; beyaz rüzgâr şeridi + kızgın alev akımı + yere yayılan amber kaynar yağ (ref 1),
## kabarıp ilerleyen bej-sarı yağ dalgası, üstünde parlayan sarı damarlar ve közler (ref 2)
static func senpo_goemon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var d = pj.fwd(c, t)
	var elders = []
	for sx in [-1.0, 1.0]:   # omuzlarda iki yaşlı kurbağa
		var ba = pj.bone_attach(c, "LeftShoulder" if sx > 0 else "RightShoulder")
		if ba:
			var mi = MeshInstance3D.new()
			mi.mesh = _toad_mesh(sx < 0)
			ba.add_child(mi)
			mi.position = Vector3(0, 0.08, 0)
			mi.scale = Vector3.ONE * 0.05
			mi.create_tween().tween_property(mi, "scale", Vector3.ONE * 1.1, 0.3).set_trans(Tween.TRANS_BACK)   # kullanıcı: kurbağalar çok küçük
			poof(pj, ba.global_position + Vector3.UP * 0.2, 0.35)
			elders.append(ba)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var o = _mouth(c)
		var side = d.cross(Vector3.UP).normalized()
		# kaynar yağ + rüzgâr + ateş: kurbağaların yağ yayları, alev akımı, beyaz rüzgâr şeritleri
		for sx in [-1.0, 1.0]:
			_oil_arc(pj, c.global_position + Vector3.UP * 1.6 + side * sx * 0.3, d, 0.5)
		_kstream(pj, c, o, d, 34.0, 11.0, 1.4)   # yağ + rüzgâr + ateş: önü kaplayan dev alev seli (kullanıcı: epic değil)
		for q in 8:
			var off = side * randf_range(-1.6, 1.6) + Vector3.UP * randf_range(-0.6, 0.8)
			streak(pj, _path(func(u: float) -> Vector3: return o + off * u + d * (u * 20.0), 10), 0.13, Color(1.0, 0.95, 0.85, 0.85), 0.5, false,
				{"rag": 0.5, "core": 0.0, "delay": q * 0.025})
		for k in 14:   # kaynar yağ dalgası: kabaran amber sırtlar, kaynayan kabarcıklar, sarı damarlı yağ zemini
			pj.after(k * 0.06, func():
				var p = pj.gp(c.global_position + d * (3.0 + k * 2.3))
				ground_mark(pj, p, 2.6, 2.6, randf() * TAU, 2.0, 4.5, 0.15)
				for q in 3:   # kabarıp çöken yağ sırtı: yassı, topaklı amber yağ kütleleri
					oil_crest(pj, p + side * randf_range(-2.0, 2.0), randf_range(0.6, 1.0), d)
				_kt(pj, p + side * randf_range(-1.5, 1.5), 1.6, 1.0, 0.5, (d * 0.4 + Vector3.UP).normalized(), d * 2.0, 1.1, true)
				bubble(pj, p + side * randf_range(-1.5, 1.5), 0.35)
				if k % 3 == 0:
					_ke(pj, p + Vector3.UP * 0.5, 8, 1.5, 3.0))
		_oil_pool(pj, c, c.global_position + d * 16.0, 7.0, 5.0)
		GroundFX.add(c.global_position + d * 16.0, "burning", 7.0, 5.0, c)
		KatonLib.scorch(pj, c.global_position + d * 16.0, 9.0, 20.0)
		Combat.hit_zone(c, c.global_position, d, 34.0, 24.0, 5.0, pj.inf(c, "senpo_goemon", 1.8, {"knock": 14.0, "kind": "heavy", "element": "katon", "burn": 5.0}))
		Sfx.play("fire", c.global_position, 0.5)
		Sfx.play("water", c.global_position, 0.7))
	pj.after(1.8, func():
		for ba in elders:
			if is_instance_valid(ba):
				ba.queue_free())


## Kurbağanın ağzından kalın amber yağ yayı: parlak yağ şeridi + yere düşüp leke bırakan yağ damlaları
static func _oil_arc(pj: PathJutsu, src: Vector3, d: Vector3, dur: float) -> void:
	var pts = _path(func(u: float) -> Vector3:
		var tm = u * 0.58
		return src + d * 16.0 * tm + Vector3.UP * (2.5 * tm - 9.0 * tm * tm), 14)
	streak(pj, pts, 0.24, Color(0.9, 0.66, 0.2, 1.0), 0.75, false, {"core": 0.25, "rag": 0.15, "taper": 0.6})
	pj.every(dur, 0.05, func(_i, _k):
		var mi = _gi(_ball(), oil_mat())
		mi.set_instance_shader_parameter("fade", 1.0)
		mi.set_instance_shader_parameter("hot", 0.0)
		mi.scale = Vector3.ONE * randf_range(0.1, 0.2)
		var v = d * randf_range(14.0, 18.0) + Vector3.UP * randf_range(2.0, 3.0) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		_toss(pj, mi, src, v, 1.2, 18.0, "", func(lp: Vector3):
			ground_mark(pj, lp, 0.7, 0.7, randf() * TAU, 2.0, 3.0, 0.1)))


## Kurbağa yağı birikintisi: yağ zemini + kaynayıp patlayan kabarcıklar; içindekiler yavaşlar (eski _oil_pool mekaniği aynen)
static func _oil_pool(pj: PathJutsu, c: Node3D, at: Vector3, r: float, dur: float) -> void:
	at = pj.gp(at)
	ground_mark(pj, at, r * 1.3, r * 1.1, randf() * TAU, 2.0, dur + 1.0, 0.8)
	pj.every(dur, 0.15, func(i, _k):
		var b = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * r * 0.7
		bubble(pj, pj.gp(b) + Vector3.UP * 0.05)
		if i % 3 == 0:
			for e in pj.enemies_near(c, at, r):
				pj.st(e, "slow", 1.0), Callable())


## Omuzda oturan yaşlı bilge kurbağa (+Z öne): yüksek yakalı cüppe, kulak diski, iri gözler;
## erkek: beyaz diken saç / kaş / keçi sakal, dişi: kıvırcık mor saç, mor dudak
static func _toad_mesh(female: bool) -> ArrayMesh:
	var key = "toad_f" if female else "toad_m"
	if _cache.has(key):
		return _cache[key]
	var b = MB.new()
	var skin = Color(0.6, 0.66, 0.38) if female else Color(0.55, 0.62, 0.3)
	var robe = Color(0.5, 0.45, 0.38)
	b.add("sphere", Vector3(0, 0.18, 0), Vector3(0.42, 0.36, 0.38), robe, Vector3.ZERO, 12)
	b.add("cyl", Vector3(0, 0.32, 0), Vector3(0.36, 0.08, 0.34), Color(0.75, 0.7, 0.6), Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.44, 0.02), Vector3(0.4, 0.3, 0.36), skin, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.38, 0.12), Vector3(0.34, 0.14, 0.2), skin.lightened(0.15), Vector3.ZERO, 12)
	b.add("box", Vector3(0, 0.37, 0.215), Vector3(0.2, 0.012, 0.01), Color(0.2, 0.15, 0.1))
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.11, 0.53, 0.14), Vector3(0.1, 0.1, 0.08), Color(0.95, 0.92, 0.75))
		b.add("box", Vector3(sx * 0.11, 0.53, 0.18), Vector3(0.07, 0.02, 0.01), Color(0.05, 0.05, 0.05))
		b.add("cyl", Vector3(sx * 0.21, 0.47, 0.0), Vector3(0.08, 0.02, 0.08), Color(0.55, 0.4, 0.3), Vector3(0, 0, 90))
	if female:
		var hair = Color(0.55, 0.3, 0.6)
		for k in 7:
			var a = k * TAU / 7.0
			b.add("sphere", Vector3(cos(a) * 0.12, 0.6 + sin(k * 1.7) * 0.02, sin(a) * 0.1 - 0.02), Vector3(0.12, 0.1, 0.12), hair)
		b.add("sphere", Vector3(0, 0.36, 0.205), Vector3(0.12, 0.04, 0.03), Color(0.5, 0.25, 0.55))
	else:
		var white = Color(0.95, 0.95, 0.92)
		for k in 5:
			var a = -60.0 + k * 30.0
			b.add("cone", Vector3(sin(deg_to_rad(a)) * 0.08, 0.6, -0.04), Vector3(0.07, 0.2, 0.07), white, Vector3(-25, 0, -a * 0.8), 5)
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.13, 0.61, 0.12), Vector3(0.04, 0.12, 0.04), white, Vector3(0, 0, -sx * 70.0), 4)
		b.add("cone", Vector3(0, 0.27, 0.16), Vector3(0.06, 0.14, 0.06), white, Vector3(180, 0, 0), 5)
	var m = b.build(Props.toon())
	_cache[key] = m
	return m


# ================================================================== 8) Shōton: Shuriken Ranbu
## Kristal şurikenler kurdele gibi bedenin etrafında döner (pembe parıltılı sarmal iz), sonra her yöne fırlar;
## çarptığı yerde pembe kristal kırıntısı
static func shoton_shuriken_ranbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 20.0)
	var stars = []
	for k in 12:
		var sh = gem(_xstar_mesh(), PINK, 0.0, 0.5)
		pj.scene_add(sh, c.global_position)
		sh.scale = Vector3.ONE * 0.01
		sh.create_tween().tween_property(sh, "scale", Vector3.ONE * 0.26, 0.18).set_delay(k * 0.025).set_trans(Tween.TRANS_BACK)
		stars.append(sh)
	pj.every(0.7, 0.03, func(_i, _k):
		for k in stars.size():
			var sh = stars[k]
			if is_instance_valid(sh) and pj.live(c):
				var a = _k * TAU * 3.0 + k * TAU / stars.size()
				sh.global_position = c.global_position + Vector3(cos(a) * 1.3, 0.3 + fmod(k * 0.17 + _k * 2.0, 2.0), sin(a) * 1.3)
				sh.rotation.y += 0.6
		if _i % 4 == 0 and not stars.is_empty():
			var s0 = stars[randi() % stars.size()]
			if is_instance_valid(s0):
				star(pj, s0.global_position, 0.6, Color(1.0, 0.85, 0.97), 0.18, 4.0))
	# kurdele: yıldızların arkasında dönen pembe ışık şeritleri
	var rig = Node3D.new()
	_put(pj, rig, c.global_position)
	for q in 2:
		var ph = q * PI
		var pts = _path(func(u: float) -> Vector3:
			var a = ph + u * TAU * 1.6
			return Vector3(cos(a) * 1.3, 0.3 + u * 2.0, sin(a) * 1.3), 36)
		var rb = ribbon_mi(pts, 0.09, Color(1.0, 0.7, 0.95, 0.85), true, {"taper": 1.0, "rag": 0.2, "core": 0.5})
		rig.add_child(rb)
	var tr = rig.create_tween()
	tr.tween_property(rig, "rotation:y", TAU * 2.0, 0.75)
	tr.tween_callback(rig.queue_free)
	sparks(pj, c.global_position + Vector3.UP * 1.0, {"n": 30, "life": 0.7, "r": 1.3, "dir": Vector3.UP, "spread": 80.0, "vmin": 0.5, "vmax": 2.0,
		"g": Vector3.ZERO, "size": 0.07, "burst": 0.2, "cols": [Color(1, 1, 1, 1), PINK, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0)]})
	pj.after(0.75, func():
		for k in stars.size():
			var sh = stars[k]
			if not is_instance_valid(sh):
				continue
			var from = sh.global_position
			sh.queue_free()
			if not pj.live(c):
				continue
			var dir = (pj.aim_at(c, tt, from) if is_instance_valid(tt) and k % 2 == 0 else Vector3(cos(k * 0.52), 0.05, sin(k * 0.52)))
			var pm = _xstar_proj()
			pj.shot(c, from, dir, 30.0, pm, pj.inf(c, "shoton_shuriken_ranbu", 0.3, {"knock": 3.0, "kind": "light", "bleed": 1.5}), null, false, 0.9, func(p, _h):
				shards(pj, p, 4, 3.5, 0.18, PINK, 0.0, 0.5, 0.8))
			var spn: Node3D = pm.get_child(0)
			var tws = Game.safe_loops(spn.create_tween())
			tws.tween_property(spn, "rotation:y", TAU, 0.16).from(0.0)
		if pj.live(c):
			star(pj, c.global_position + Vector3.UP * 1.2, 2.5, Color(1.0, 0.85, 0.97), 0.25, 8.0))
	Sfx.play("whoosh", c.global_position, 1.4)


## Uçan kristal şuriken: düz dönen yıldız + arkasında ince pembe iz
static func _xstar_proj() -> Node3D:
	var root = Node3D.new()
	var sh = gem(_xstar_mesh(), PINK, 0.0, 0.6)
	root.add_child(sh)
	sh.scale = Vector3.ONE * 0.26
	var tr = ribbon_mi(PackedVector3Array([Vector3(0, 0, 0.1), Vector3(0, 0, 0.8), Vector3(0, 0, 1.5)]), 0.06, Color(1.0, 0.7, 0.95, 0.8), true,
		{"taper": 1.0, "rag": 0.0, "core": 0.5, "hint": Vector3.UP})
	root.add_child(tr)
	return root


# ================================================================== 9) Shōton: Suishō Sharin
## ref: insan boyunda, ışıl ışıl beyaz-mor kavisli kesen kristal çark; yerde sürtünerek kıvılcım çizgileri saçar,
## ardında sivri kristal izi bırakır; sonunda parçalanır
static func shoton_suisho_sharin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var wheel = Node3D.new()
	pj.scene_add(wheel, c.global_position + Vector3.UP * 1.4 + d * 1.5)
	wheel.look_at(wheel.global_position + d, Vector3.UP)
	var wtint = Color(0.92, 0.82, 1.0)
	for k in 10:   # tekerlek düzlemi (YZ) üzerinde dışa yatık kesici kristal dişler
		var a = k * TAU / 10.0
		var bl = gem(gem_mesh(k % 6, 5, 0.5), wtint, 0.0, 0.9)
		wheel.add_child(bl)
		bl.position = Vector3(0, sin(a) * 1.55, cos(a) * 1.55)
		var ax = (Vector3(0, sin(a), cos(a)) * 0.6 + Vector3(0, cos(a), -sin(a))).normalized()
		bl.basis = _axis_basis(ax)
		bl.scale = Vector3(0.45, 1.2, 0.3)
	var rim_pts = PackedVector3Array()
	for i in 41:
		var a = TAU * i / 40.0
		rim_pts.append(Vector3(0, sin(a) * 1.95, cos(a) * 1.95))
	var rim = ribbon_mi(rim_pts, 0.3, Color(0.95, 0.88, 1.0, 1.0), true, {"taper": 0.0, "rag": 0.35, "core": 0.55, "hint": Vector3.RIGHT})
	wheel.add_child(rim)
	var hub = gem(gem_mesh(3, 6, 0.5), wtint, 0.0, 1.0)
	wheel.add_child(hub)
	hub.rotation = Vector3(0, 0, PI * 0.5)
	hub.scale = Vector3(0.7, 0.5, 0.7)
	var hl = OmniLight3D.new()
	hl.light_color = Color(0.9, 0.75, 1.0)
	hl.light_energy = 2.5
	hl.omni_range = 6.0
	wheel.add_child(hl)
	var hit_ids = []
	var tw = wheel.create_tween().set_parallel()
	tw.tween_property(wheel, "global_position", wheel.global_position + d * 18.0, 1.2)
	tw.tween_property(wheel, "rotation:x", wheel.rotation.x - TAU * 4.0, 1.2)
	pj.every(1.2, 0.08, func(_i, _k):
		if is_instance_valid(wheel):
			var wp = pj.gp(wheel.global_position)
			for q in 3:   # ref: temas noktasından geriye savrulan ince ışık çizgileri
				var a0 = wp + Vector3.UP * 0.05 + side * randf_range(-0.3, 0.3)
				var a1 = a0 - d * randf_range(1.2, 2.2) + Vector3.UP * randf_range(0.3, 1.4) + side * randf_range(-0.6, 0.6)
				streak(pj, PackedVector3Array([a0, a0.lerp(a1, 0.5), a1]), 0.04, Color(0.97, 0.92, 1.0, 1.0), 0.25, true, {"taper": 1.0, "rag": 0.0, "core": 0.6})
			if _i % 2 == 0:
				spike(pj, wp - d * 0.6 + side * randf_range(-0.6, 0.6), 0.35, randf_range(0.7, 1.3), PINK, 0.0,
					(Vector3.UP - d * 0.4 + side * randf_range(-0.3, 0.3)).normalized(), 0.0, 0.12, 1.2, 3)
			sparks(pj, wp + Vector3.UP * 0.1, {"n": 6, "life": 0.4, "dir": (-d + Vector3.UP).normalized(), "spread": 35.0, "vmin": 3.0, "vmax": 7.0,
				"g": Vector3(0, -10, 0), "size": 0.08, "cols": [Color(1, 1, 1, 1), VIOLET, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0)]})
			for e in pj.enemies_near(c, wheel.global_position, 1.6):
				if not e in hit_ids:
					hit_ids.append(e)
					e.take_hit(pj.inf(c, "shoton_suisho_sharin", 1.2, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "bleed": 2.0})), func():
		if is_instance_valid(wheel):
			var wpos = wheel.global_position
			shards(pj, wpos, 14, 7.0, 0.5, wtint, 0.0, 0.6, 1.4)
			star(pj, wpos, 3.0, Color(0.95, 0.88, 1.0), 0.3, 6.0)
			wheel.queue_free())
	Sfx.play("whoosh", c.global_position, 1.0)


# ================================================================== 10) Shōton: Isshi Kōmyō
## ref: kullanıcıyı ince ışık çizgilerinden bir sekizyüzlü sarar (köşelerde yıldız patlamaları, içinde soluk kristal),
## bir köşesinden uzun beyaz-mavi ışık oku fırlar
static func shoton_isshi_komyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 34.0)
	pj.busy(c, 1.6)
	var oct = Node3D.new()
	pj.scene_add(oct, c.global_position + Vector3.UP * 1.1)
	_octa_build(oct)
	oct.scale = Vector3.ONE * 0.1
	oct.create_tween().tween_property(oct, "scale", Vector3.ONE * 1.3, 0.3).set_trans(Tween.TRANS_BACK)
	oct.create_tween().tween_property(oct, "rotation:y", 1.2, 1.8)
	Buffs.add("isshi_komyo", 1.6, {"armor": 0.2, "_name": "Kristal Kalkan", "_desc": "kristal sekizyüzlü"})
	pj.after(0.9, func():
		if not pj.live(c):
			return
		var o = c.global_position + Vector3.UP * 1.3 + c.face_dir() * 1.3
		var e = (tt.global_position + Vector3.UP if is_instance_valid(tt) else o + pj.fwd(c, t) * 30.0)
		var d = (e - o).normalized()
		var end = o + d * 34.0
		_light_beam(pj, o, end, d)
		Combat.hit_zone(c, o - Vector3.UP * 1.3, d, 34.0, 4.0, 2.5, pj.inf(c, "shoton_isshi_komyo", 2.6, {"knock": 18.0, "kind": "heavy"})))
	# kendi sönüşü (çağırandan bağımsız): sekizyüzlü küçülür, içteki kristaller parçalanır
	var ow = weakref(oct)
	pj.get_tree().create_timer(1.5).timeout.connect(func():
		var x = ow.get_ref()
		if x == null or not is_instance_valid(x):
			return
		shards(pj, x.global_position, 8, 3.0, 0.35, Color(0.8, 0.9, 1.0), 0.0, 0.5, 1.0)
		var tw = x.create_tween()
		tw.tween_property(x, "scale", x.scale * 0.05, 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(x.queue_free))
	Sfx.play("chakra", c.global_position, 1.4)


static func _rod_between(parent: Node3D, a: Vector3, b: Vector3, r: float, col: Color) -> MeshInstance3D:
	var mi = _glow_mi(_rod(), col)
	parent.add_child(mi)
	var dv = b - a
	mi.transform = Transform3D(_axis_basis(dv) * Basis.from_scale(Vector3(r, dv.length(), r)), (a + b) * 0.5)
	return mi


static func _octa_build(oct: Node3D) -> void:
	var R = 1.6
	var V = [Vector3(0, R, 0), Vector3(0, -R, 0), Vector3(R, 0, 0), Vector3(-R, 0, 0), Vector3(0, 0, R), Vector3(0, 0, -R)]
	var eq = [2, 4, 3, 5]
	for k in 4:   # 12 kenar: tepe / dip → ekvator, ekvator halkası
		_rod_between(oct, V[0], V[eq[k]], 0.035, Color(0.82, 0.93, 1.0))
		_rod_between(oct, V[1], V[eq[k]], 0.035, Color(0.82, 0.93, 1.0))
		_rod_between(oct, V[eq[k]], V[eq[(k + 1) % 4]], 0.035, Color(0.82, 0.93, 1.0))
	for pr in [[0, 1], [2, 3], [4, 5]]:   # ref: içten geçen ince sıcak renkli çizgiler
		_rod_between(oct, V[pr[0]], V[pr[1]], 0.012, Color(1.0, 0.78, 0.5))
	for v in V:   # köşelerde yıldız patlaması
		var s = _glow_mi(_quad_c(), Color(0.8, 0.92, 1.0), true, 10.0)
		oct.add_child(s)
		s.position = v
		s.scale = Vector3.ONE * 1.1
		var g = _glow_mi(_ball(), Color(0.85, 0.95, 1.0))
		oct.add_child(g)
		g.position = v
		g.scale = Vector3.ONE * 0.16
	for k in 8:   # içte büyüyen soluk kristaller (kullanıcının çevresinde)
		var a = k * TAU / 8.0
		var dv = Vector3(cos(a), randf_range(-0.3, 0.6), sin(a)).normalized()
		var cr = gem(gem_mesh(k % 6, 6, 0.4), Color(0.82, 0.9, 1.0), 0.0, 0.7)
		oct.add_child(cr)
		cr.position = dv * 0.55 - Vector3.UP * 0.2
		cr.basis = _axis_basis(dv + Vector3.UP * 0.6)
		cr.scale = Vector3(0.18, 0.01, 0.18)
		cr.create_tween().tween_property(cr, "scale", Vector3(0.22, randf_range(0.6, 1.1), 0.22), 0.35).set_delay(0.1 + k * 0.03).set_trans(Tween.TRANS_BACK)


static func _light_beam(pj: PathJutsu, o: Vector3, end: Vector3, d: Vector3) -> void:
	var L = o.distance_to(end)
	var layers = [[0.75, Color(0.6, 0.8, 1.0), 0.5], [0.24, Color(1, 1, 1), 0.4]]
	for ly in layers:
		var r: float = ly[0]
		var life: float = ly[2]
		var mi = _glow_mi(_rod(), ly[1])
		_put(pj, mi, o + d * L * 0.5)
		mi.basis = _axis_basis(d)
		mi.scale = Vector3(r, L, r)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(0.02, L, 0.02), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
	var sd = _side(d, 0, Vector3.ZERO)
	var su = _side(d, 1, Vector3.ZERO)
	for q in 6:   # ışının çevresinde akan ince çizgiler
		var off = (sd * cos(q * 1.05) + su * sin(q * 1.05)) * 0.45
		streak(pj, PackedVector3Array([o + off, o + off + d * L * 0.5, end + off]), 0.05, Color(0.85, 0.93, 1.0, 1.0), 0.35, true,
			{"taper": 1.0, "rag": 0.0, "core": 0.6, "delay": q * 0.02})
	star(pj, o, 3.5, Color(0.95, 0.98, 1.0), 0.4, 8.0)
	star(pj, end, 4.5, Color(0.95, 0.98, 1.0), 0.5, 8.0)
	light(pj, o, Color(0.8, 0.9, 1.0), 8.0, 14.0, 0.5)
	for k in 5:
		sparks(pj, o.lerp(end, (k + 0.5) / 5.0), {"n": 8, "life": 0.5, "vmin": 1.0, "vmax": 3.0, "g": Vector3.ZERO, "size": 0.08,
			"cols": [Color(1, 1, 1, 1), Color(0.75, 0.88, 1.0, 1), Color(0.75, 0.88, 1.0, 0)]})
	var fl = Game.jutsu_floor_at(end).y
	if end.y - fl < 4.0:   # ışığın değdiği yerde kristal filizlenir
		var gpos = Vector3(end.x, fl, end.z)
		for k in 5:
			var a = k * TAU / 5.0 + randf() * 0.4
			var o2 = Vector3(cos(a), 0, sin(a))
			spike(pj, gpos + o2 * randf_range(0.3, 1.0), randf_range(0.4, 0.7), randf_range(1.0, 2.2), Color(0.85, 0.9, 1.0), 0.0,
				(Vector3.UP + o2 * 0.5).normalized(), 0.0, 0.18, 1.6, 4)
	else:
		shards(pj, end, 10, 5.0, 0.35, Color(0.85, 0.9, 1.0))


# ================================================================== 11) Hyōton: Sōryū Bōfūsetsu
## ref: iki kara kar ejderi — koyu gri lekeli gövde, soluk beyaz dış çizgi, kırmızı yanan göz ve ağız; birbirine dolanarak
## gidip hedefin çevresinde kara bir kar kasırgasına döner
static func hyoton_soryu_bofusetsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 30.0)
	_frost_source(pj, c, 4.0)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var d = pj.fwd(c, tt)
		var from = c.global_position + Vector3.UP * 1.4 + d * 1.2
		var P = pj.gp(tt.global_position) if pj.live(tt) else pj.gp(c.global_position + d * 16.0)
		var fly = clampf(from.distance_to(P) / 24.0, 0.35, 1.2)
		var spin = 3.4   # kasırga süresi
		var drs = []
		for k in 2:
			drs.append(_dragon(pj, from, 1.7, 17, 1.15, d))
		var axis = (P + Vector3.UP * 1.4 - from).normalized()
		var sd = axis.cross(Vector3.UP).normalized()
		var up = sd.cross(axis)
		var total = fly + spin
		var s_tick = func(_i, k):
			var tm = k * total
			for q in 2:
				var h: Node3D = drs[q]["head"]
				if not is_instance_valid(h):
					continue
				var np: Vector3
				if tm < fly:   # birbirine dolanan çift sarmal
					var a = tm * 9.0 + q * PI
					np = from.lerp(P + Vector3.UP * 1.4, tm / fly) + (sd * cos(a) + up * sin(a)) * 1.5
				else:   # kasırga: hedefin çevresinde dönerek yükselir, yarıçap yukarı doğru açılır
					var u = (tm - fly) / spin
					var a2 = (tm - fly) * 7.5 + q * PI
					var hh = 0.8 + fposmod(u * 2.0 + q * 0.5, 1.0) * 10.0
					var rr = 2.0 + hh * 0.32
					np = P + Vector3(cos(a2) * rr, hh, sin(a2) * rr)
				if np.distance_to(h.global_position) > 0.01:
					_look(h, np - h.global_position)
				h.global_position = np
				_dragon_follow(drs[q])
				if _i % 6 == q * 3:
					snow(pj, np, 0.6, true, 6)
		var s_done = func():
			for dr in drs:
				_dragon_free(pj, dr)
			snow(pj, P + Vector3.UP * 3.0, 3.0, true, 60)
			for q in 4:
				shards(pj, P + Vector3(cos(q * TAU / 4.0), 0.3, sin(q * TAU / 4.0)) * 3.0, 10, 6.0, 0.6, ICEC, 0.8)
			if is_instance_valid(c):
				pj.hit(c, P + Vector3.UP * 2.0, 6.5, pj.inf(c, "hyoton_soryu_bofusetsu", 1.6, {"knock": 16.0, "launch": 9.0, "kind": "heavy", "element": "hyoton", "slow": 3.0, "hitstop": 0.12}))
			pj.shake(0.9)
		pj.every(total, 1.0 / 60.0, s_tick, s_done)
		pj.after(fly, func():
			# kasırga: kara kar perdeleri + içine çeken, havaya kaldıran ardışık vuruşlar
			_blizzard(pj, P, spin)
			Sfx.play("wind", P, 0.55)
			pj.every(spin, 0.28, func(_i, _k):
				snow(pj, P + Vector3.UP * randf_range(1.0, 8.0), 2.2, true, 14)
				for e in pj.enemies_near(c, P, 8.5):
					if not pj.live(e):
						continue
					var to = P - e.global_position
					to.y = 0.0
					if to.length() > 1.2:   # merkeze çeker
						e.global_position += to.normalized() * minf(1.6, to.length() - 1.0)
				pj.hit(c, P + Vector3.UP * 2.0, 5.5, pj.inf(c, "hyoton_soryu_bofusetsu", 0.22, {"knock": 0.0, "launch": 6.5, "kind": "light", "element": "hyoton", "slow": 1.0})), Callable())))
	Sfx.play("clink", c.global_position, 0.6)


## Buz kaynağı: ayak dibi kırağı tutar, soğuk buhar ve parıltı
static func _frost_source(pj: PathJutsu, c: Node3D, r: float) -> void:
	var at = pj.gp(c.global_position)
	ground_mark(pj, at, r, r, randf() * TAU, 1.0, 2.4, 0.3)
	sparks(pj, at + Vector3.UP * 0.2, {"n": 14, "life": 0.7, "r": r * 0.6, "dir": Vector3.UP, "spread": 50.0, "vmin": 0.5, "vmax": 2.5, "size": 0.1,
		"g": Vector3.ZERO, "cols": [Color(1, 1, 1, 1), ICEC, Color(ICEC.r, ICEC.g, ICEC.b, 0)]})
	for k in 4:
		var a = k * TAU / 4.0 + randf() * 0.5
		puff(pj, at + Vector3(cos(a), 0.3, sin(a)) * r * 0.5, 0.55, 1.0, Color(0.95, 0.98, 1.0), Color(0.7, 0.82, 0.92), Vector3.UP * 0.6)


static func _hull(parent: Node3D, mesh: Mesh, s: float, ocol: Color, width: float) -> Array:
	var body = _gi(mesh, dragon_mat())
	parent.add_child(body)
	body.scale = Vector3.ONE * s
	var hull = _gi(mesh, outline_mat())
	hull.set_instance_shader_parameter("ocol", Vector3(ocol.r, ocol.g, ocol.b))
	hull.set_instance_shader_parameter("width", width)
	parent.add_child(hull)
	hull.scale = Vector3.ONE * s
	return [body, hull]


# ------------------------------------------------------------------ loft: kesitlerden pürüzsüz gövde
## Çizgi boyunca kaymasız (paralel taşınan) çerçeveler: [teğet, üst, yan]
static func _frames(pts: Array) -> Array:
	var n = pts.size()
	var out = []
	var prev_n = Vector3.UP
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var tv = b - a
		tv = tv.normalized() if tv.length() > 0.00001 else Vector3.FORWARD
		var nv: Vector3 = prev_n - tv * tv.dot(prev_n)
		if nv.length() < 0.01:
			nv = Vector3.RIGHT - tv * tv.dot(Vector3.RIGHT)
		nv = nv.normalized()
		prev_n = nv
		out.append([tv, nv, tv.cross(nv)])
	return out


static func _lv(st: SurfaceTool, p: Vector3, nrm: Vector3, uv: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_normal(nrm)
	st.set_uv(uv)
	st.add_vertex(p)


## Kesitlerden loft (elips kesit; rad[i] = Vector2(yan, üst) yarıçap); xf ile dönüştürülür
static func _loft(st: SurfaceTool, pts: Array, rad: Array, col: Color, sides := 10, xf := Transform3D.IDENTITY) -> void:
	var fr = _frames(pts)
	var n = pts.size()
	var rings = []
	var norms = []
	for i in n:
		var f: Array = fr[i]
		var rv: Vector2 = rad[i]
		rv = Vector2(maxf(rv.x, 0.002), maxf(rv.y, 0.002))
		var ring = []
		var nr = []
		for s in sides + 1:
			var a = TAU * s / sides
			var off: Vector3 = f[2] * cos(a) * rv.x + f[1] * sin(a) * rv.y
			ring.append(xf * (Vector3(pts[i]) + off))
			nr.append((xf.basis * (f[2] * cos(a) * rv.y + f[1] * sin(a) * rv.x)).normalized())
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		for s in sides:
			var v0 = float(s) / sides
			var v1 = float(s + 1) / sides
			# Godot ön yüzü saat yönünde: dış yüz dışa baksın (ters gövde kontur bunu ister)
			_lv(st, rings[i][s], norms[i][s], Vector2(u0, v0), col)
			_lv(st, rings[i + 1][s + 1], norms[i + 1][s + 1], Vector2(u1, v1), col)
			_lv(st, rings[i + 1][s], norms[i + 1][s], Vector2(u1, v0), col)
			_lv(st, rings[i][s], norms[i][s], Vector2(u0, v0), col)
			_lv(st, rings[i][s + 1], norms[i][s + 1], Vector2(u0, v1), col)
			_lv(st, rings[i + 1][s + 1], norms[i + 1][s + 1], Vector2(u1, v1), col)


## Kara kar ejderi başı (-Z ileri, boy ~2): loft kafatası + uzun burun, aşağı açılmış alt çene, kırmızı ağız içi ve gözler,
## beyaz dişler, geriye kıvrık boynuzlar, sarkan bıyıklar, yele dikenleri
static func _dragon_head_mesh() -> ArrayMesh:
	if _cache.has("dhead2"):
		return _cache["dhead2"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_head_geom(st, Color(0.13, 0.13, 0.16), Color(0.22, 0.22, 0.27), Color(1.0, 0.08, 0.06), Color(0.92, 0.92, 0.96))
	var m = st.commit()
	_cache["dhead2"] = m
	return m


static func _head_geom(st: SurfaceTool, k1: Color, k2: Color, red: Color, tooth: Color) -> void:
	_loft(st, [Vector3(0, 0.05, 0.55), Vector3(0, 0.1, 0.3), Vector3(0, 0.1, 0.0), Vector3(0, 0.05, -0.35), Vector3(0, 0.0, -0.7),
		Vector3(0, -0.02, -1.05), Vector3(0, -0.04, -1.3), Vector3(0, -0.05, -1.38)],
		[Vector2(0.2, 0.18), Vector2(0.46, 0.36), Vector2(0.5, 0.38), Vector2(0.38, 0.27), Vector2(0.3, 0.2), Vector2(0.25, 0.16),
		Vector2(0.16, 0.1), Vector2(0.01, 0.01)], k1, 12)
	_loft(st, [Vector3(0, -0.12, 0.2), Vector3(0, -0.18, -0.4), Vector3(0, -0.22, -1.0)], [Vector2(0.3, 0.1), Vector2(0.24, 0.08), Vector2(0.1, 0.04)], red, 10)
	var pv = Vector3(0, -0.1, 0.25)
	var jaw = Transform3D(Basis.IDENTITY, pv) * Transform3D(Basis(Vector3.RIGHT, -0.45), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pv)
	_loft(st, [Vector3(0, -0.15, 0.35), Vector3(0, -0.2, 0.0), Vector3(0, -0.22, -0.45), Vector3(0, -0.22, -0.85), Vector3(0, -0.22, -1.1), Vector3(0, -0.22, -1.18)],
		[Vector2(0.3, 0.14), Vector2(0.36, 0.16), Vector2(0.28, 0.12), Vector2(0.2, 0.09), Vector2(0.12, 0.06), Vector2(0.01, 0.01)], k2, 10, jaw)
	for sx in [-1.0, 1.0]:
		for i in 5:
			var z = -0.35 - i * 0.17
			_loft(st, [Vector3(sx * 0.19, -0.1, z), Vector3(sx * 0.19, -0.28, z)], [Vector2(0.04, 0.04), Vector2(0.004, 0.004)], tooth, 5)
			_loft(st, [Vector3(sx * 0.17, -0.13, z + 0.05), Vector3(sx * 0.17, 0.02, z + 0.05)], [Vector2(0.035, 0.035), Vector2(0.004, 0.004)], tooth, 5, jaw)
		_loft(st, [Vector3(sx * 0.38, 0.22, -0.06), Vector3(sx * 0.4, 0.23, -0.2), Vector3(sx * 0.37, 0.21, -0.36)],
			[Vector2(0.01, 0.01), Vector2(0.06, 0.08), Vector2(0.01, 0.01)], red, 8)
		_loft(st, [Vector3(sx * 0.3, 0.33, 0.08), Vector3(sx * 0.3, 0.32, -0.15), Vector3(sx * 0.26, 0.27, -0.42)],
			[Vector2(0.09, 0.06), Vector2(0.07, 0.05), Vector2(0.01, 0.01)], k2, 8)
		_loft(st, [Vector3(sx * 0.25, 0.3, 0.3), Vector3(sx * 0.32, 0.55, 0.75), Vector3(sx * 0.3, 0.72, 1.25), Vector3(sx * 0.25, 0.78, 1.6)],
			[Vector2(0.11, 0.11), Vector2(0.08, 0.08), Vector2(0.05, 0.05), Vector2(0.005, 0.005)], k2, 7)
		_loft(st, [Vector3(sx * 0.22, -0.02, -1.0), Vector3(sx * 0.6, -0.1, -0.6), Vector3(sx * 0.9, -0.35, 0.0), Vector3(sx * 1.0, -0.6, 0.6)],
			[Vector2(0.035, 0.035), Vector2(0.025, 0.025), Vector2(0.015, 0.015), Vector2(0.003, 0.003)], k2, 5)
		for k in 3:
			var b = Vector3(sx * 0.36, 0.08 - k * 0.04, 0.35 + k * 0.2)
			_loft(st, [b, b + Vector3(sx * 0.35, 0.1, 0.4)], [Vector2(0.08, 0.05), Vector2(0.004, 0.004)], k2, 5)
	for k in 5:
		var b2 = Vector3(0, 0.36 - k * 0.03, 0.2 + k * 0.22)
		_loft(st, [b2, b2 + Vector3(0, 0.45 - k * 0.05, 0.35)], [Vector2(0.06, 0.1), Vector2(0.004, 0.004)], k2, 5)


## Ejder: loft baş + her karede başın izinden yeniden örülen pürüzsüz, incelen gövde (pullu, sırtında yüzgeç dikenleri)
static func _dragon(host: Node, at: Vector3, size: float, n: int, r: float, d: Vector3) -> Dictionary:
	var oc = Color(0.85, 0.9, 0.96)
	var head = Node3D.new()
	_put(host, head, at)
	_look(head, d)
	_hull(head, _dragon_head_mesh(), size, oc, 0.025)
	var im = ImmediateMesh.new()
	var root = Node3D.new()
	_put(host, root, Vector3.ZERO)
	var nodes = _hull(root, im, 1.0, oc, 0.06)
	var fim = ImmediateMesh.new()
	var fmi = _gi(fim, dragon_mat())
	root.add_child(fmi)
	nodes.append(fmi)
	for x in nodes:
		x.extra_cull_margin = 60.0
	return {"head": head, "root": root, "im": im, "fim": fim, "hist": [at], "len": n * r * 0.8, "r": r, "size": size}


## Gövde: baş izinden eşit aralıklı örnekler → incelen yarıçapla loft (ImmediateMesh), alt karın açık, sırt yüzgeci
static func _dragon_follow(dr: Dictionary) -> void:
	var head: Node3D = dr["head"]
	if not is_instance_valid(head):
		return
	var hist: Array = dr["hist"]
	var hp = head.global_position + head.global_basis.z * float(dr["size"]) * 0.3
	if hist.is_empty() or Vector3(hist[0]).distance_to(hp) > 0.05:
		hist.push_front(hp)
	if hist.size() > 800:
		hist.pop_back()
	var L: float = dr["len"]
	var R: float = dr["r"]
	var ns = 26
	var step = L / ns
	var pts = []
	var idx = 0
	var acc = 0.0
	for i in ns + 1:
		var want = step * i
		while idx < hist.size() - 1 and acc + Vector3(hist[idx]).distance_to(hist[idx + 1]) < want:
			acc += Vector3(hist[idx]).distance_to(hist[idx + 1])
			idx += 1
		if idx >= hist.size() - 1:
			break
		var sl = Vector3(hist[idx]).distance_to(hist[idx + 1])
		pts.append(Vector3(hist[idx]).lerp(hist[idx + 1], clampf((want - acc) / maxf(sl, 0.0001), 0.0, 1.0)))
	var im: ImmediateMesh = dr["im"]
	var fim: ImmediateMesh = dr["fim"]
	im.clear_surfaces()
	fim.clear_surfaces()
	if pts.size() < 3:
		return
	var rads = []
	for i in pts.size():
		var u = float(i) / ns
		var rr = lerpf(0.72, 1.0, clampf(u / 0.15, 0.0, 1.0)) if u < 0.15 else lerpf(1.0, 0.06, (u - 0.15) / 0.85)
		rads.append(R * rr)
	_tube_im(im, pts, rads, 12, Color(0.13, 0.13, 0.16), Color(0.3, 0.3, 0.35), Color(0.22, 0.22, 0.27), fim)


## Gövde tüpü (dünya koordinatı): pürüzsüz halkalar + karın rengi + sırtta testere yüzgeç
static func _tube_im(im: ImmediateMesh, pts: Array, rads: Array, sides: int, back: Color, belly: Color, fin: Color, fim: ImmediateMesh) -> void:
	var fr = _frames(pts)
	var n = pts.size()
	var rings = []
	var norms = []
	var cols = []
	for i in n:
		var f: Array = fr[i]
		var r: float = rads[i]
		var ring = []
		var nr = []
		var cl = []
		for s in sides + 1:
			var a = TAU * s / sides
			var dv: Vector3 = f[2] * cos(a) + f[1] * sin(a)
			ring.append(Vector3(pts[i]) + dv * r)
			nr.append(dv)
			cl.append(belly if sin(a) < -0.45 else back)
		rings.append(ring)
		norms.append(nr)
		cols.append(cl)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		for s in sides:
			var v0 = float(s) / sides
			var v1 = float(s + 1) / sides
			for q in [[i, s, u0, v0], [i + 1, s + 1, u1, v1], [i + 1, s, u1, v0], [i, s, u0, v0], [i, s + 1, u0, v1], [i + 1, s + 1, u1, v1]]:
				im.surface_set_color(cols[q[0]][q[1]])
				im.surface_set_normal(norms[q[0]][q[1]])
				im.surface_set_uv(Vector2(q[2], q[3]))
				im.surface_add_vertex(rings[q[0]][q[1]])
	im.surface_end()
	# sırt yüzgeci (konturdan ayrı mesh: ters gövde ince yüzgeçte gölge kopyası yapmasın): her iki halkada bir geriye yatık diken
	fim.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var top = sides / 4
	for i in range(1, n - 1, 2):
		var f: Array = fr[i]
		var r: float = rads[i]
		var a0: Vector3 = rings[i][top]
		var a1: Vector3 = rings[i + 1][top]
		var tip: Vector3 = a0 + f[1] * r * 0.9 - f[0] * r * 0.6
		for p in [a0, a1, tip]:
			fim.surface_set_color(fin)
			fim.surface_set_normal(f[2])
			fim.surface_set_uv(Vector2(0.0, 0.5))
			fim.surface_add_vertex(p)
	fim.surface_end()


static func _dragon_free(host: Node, dr: Dictionary) -> void:
	var hist: Array = dr["hist"]
	var L: float = dr["len"]
	var acc = 0.0
	var nxt = 0.0
	for i in hist.size() - 1:
		acc += Vector3(hist[i]).distance_to(hist[i + 1])
		if acc >= nxt and acc <= L:
			nxt += L / 7.0
			puff(host, hist[i], 0.8, 0.6, Color(0.36, 0.37, 0.43), Color(0.14, 0.14, 0.19), Vector3.UP * 1.0)
			snow(host, hist[i], 0.8, true, 8)
	for key in ["head", "root"]:
		var x = dr[key]
		if is_instance_valid(x):
			x.queue_free()


## Kara kar kasırgası: dönen koyu kar perdeleri (sarmal şeritler), yükselen kara kar bulutları, donmuş zemin
static func _blizzard(pj: PathJutsu, P: Vector3, spin: float) -> void:
	var rig = Node3D.new()
	_put(pj, rig, P)
	for q in 4:
		var ph = q * TAU / 4.0
		var pts = _path(func(u: float) -> Vector3:
			var a = ph + u * TAU * 1.6
			var hh = 0.3 + u * 10.0
			var rr = 2.0 + hh * 0.32
			return Vector3(cos(a) * rr, hh, sin(a) * rr), 40)
		var col = Color(0.1, 0.1, 0.14, 0.8) if q % 2 == 0 else Color(0.85, 0.88, 0.95, 0.55)
		var mi = ribbon_mi(pts, 0.55 if q % 2 == 0 else 0.25, col, false, {"taper": 1.0, "rag": 0.5, "core": 0.0})
		rig.add_child(mi)
		var tf = mi.create_tween()
		tf.tween_interval(maxf(0.1, spin - 0.5))
		tf.tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.5)
	var tw = rig.create_tween()
	tw.tween_property(rig, "rotation:y", TAU * 2.6, spin)
	tw.tween_callback(rig.queue_free)
	ground_mark(pj, P, 6.5, 6.5, randf() * TAU, 1.0, spin + 2.0, 0.5)
	pj.every(spin, 0.18, func(_i, _k):
		var a = randf() * TAU
		var r = randf_range(2.5, 5.0)
		var tg_v = Vector3(-sin(a), 0, cos(a))
		puff(pj, P + Vector3(cos(a) * r, randf_range(0.4, 2.0), sin(a) * r), randf_range(0.5, 0.85), 0.9,
			Color(0.36, 0.37, 0.43), Color(0.14, 0.14, 0.19), tg_v * 4.0 + Vector3.UP * 2.0), Callable())


# ================================================================== 12) Hijutsu: Makyō Hyōshō
## Hedefin çevresinde soluk camgöbeği buz aynalardan iglo kubbe (gök yansıtan yüzey, kırağılı çerçeve), tabanı donar,
## içeride kar savrulur; yansıma aynadan aynaya geçip gümüş senbon yağdırır; sonunda aynalar parçalanır
static func makyo_hyosho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	var dur = 4.5
	pj.busy(c, dur + 0.3)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 7.0)
	# anime Haku: hedefin çevresinde buz aynaları iglo gibi içe kapanan bir kubbe kurar; kullanıcı aynalardan birine girer
	ground_mark(pj, at, 4.8, 4.8, randf() * TAU, 1.0, dur + 0.8, 0.5)
	var mirrors = []
	var rings = [[10, 4.2, 1.25, 0.0], [8, 3.6, 3.45, 0.55], [5, 2.1, 5.0, 1.05]]
	var idx = 0
	for ri in rings.size():
		var cnt: int = rings[ri][0]
		for k in cnt:
			var a = (k + 0.5 * ri) * TAU / cnt
			var p = at + Vector3(cos(a) * rings[ri][1], rings[ri][2], sin(a) * rings[ri][1])
			var m = _mirror(1.7 if ri < 2 else 1.5, 2.3)
			pj.scene_add(m, p)
			m.look_at(Vector3(at.x, p.y, at.z), Vector3.UP)
			m.rotate_object_local(Vector3.RIGHT, -rings[ri][3])
			m.scale = Vector3(0.05, 0.05, 1)
			m.create_tween().tween_property(m, "scale", Vector3.ONE, 0.18).set_delay(idx * 0.02).set_trans(Tween.TRANS_BACK)
			mirrors.append(m)
			idx += 1
	var cap = _mirror(1.8, 1.8)
	pj.scene_add(cap, at + Vector3.UP * 5.9)
	cap.rotation.x = -PI * 0.5
	mirrors.append(cap)
	sparks(pj, at + Vector3.UP * 2.0, {"n": 50, "life": 0.8, "r": 4.0, "vmin": 1.0, "vmax": 3.0, "size": 0.12, "g": Vector3.ZERO,
		"cols": [Color(1, 1, 1, 1), Color(0.75, 0.92, 1.0, 0.8), Color(0.7, 0.9, 1.0, 0)]})
	# kullanıcı halkadaki bir aynanın içine girer (görünmez olur); saldırılar aynalardan gelir
	var mdl: Node3D = c.model if "model" in c and c.model else null
	var home = mirrors[0]
	pj.after(0.3, func():
		if not pj.live(c):
			return
		sparks(pj, c.global_position + Vector3.UP, {"n": 20, "life": 0.4, "vmin": 2.0, "vmax": 5.0, "size": 0.12, "g": Vector3.ZERO,
			"cols": [Color(1, 1, 1, 1), Color(0.7, 0.9, 1.0, 0)]})
		if is_instance_valid(home):
			c.global_position = pj.gp(home.global_position)
		if mdl:
			mdl.visible = false)
	# aynadaki yansıma: 3B klon değil — aynanın düzlemine yassılaşmış, yarı saydam soluk mavi görüntü; aynadan aynaya geçer
	var refl: CharacterModel = null
	if mdl and "look" in mdl:
		refl = CharacterModel.new()
		pj.get_tree().current_scene.add_child(refl)
		refl.setup(mdl.look)
		for mi in refl.find_children("*", "GeometryInstance3D", true, false):
			mi.transparency = 0.3
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		refl.visible = false
	var hop = mirrors.slice(0, 18)   # alt iki halka (dik aynalar)
	var st0 = {"m": null}
	pj.every(dur, 0.32, func(i, _k):
		if not pj.live(c) or i < 1:
			return
		if i % 2 == 0:   # kubbenin içinde savrulan kar ve tabanda soğuk sis
			snow(pj, at + Vector3.UP * 4.5, 1.0, false, 10)
			puff(pj, at + Vector3(randf_range(-2.5, 2.5), 0.3, randf_range(-2.5, 2.5)), 0.7, 1.2, Color(0.96, 0.99, 1.0), Color(0.72, 0.84, 0.94), Vector3.UP * 0.3)
		var m = hop[randi() % hop.size()]
		if m == st0["m"] or not is_instance_valid(m):
			m = hop[(hop.find(m) + 3) % hop.size()]
		if not is_instance_valid(m):
			return
		st0["m"] = m
		var tgt = at + Vector3.UP
		var list = pj.enemies_near(c, at, 4.5)
		if not list.is_empty():
			tgt = list[randi() % list.size()].global_position + Vector3.UP
		var mb: Basis = m.global_transform.basis.orthonormalized()
		var hand = m.global_position - mb.z * 0.1 + Vector3.UP * 0.2
		if refl and is_instance_valid(refl):
			# yansıma bu aynada belirir (parıltıyla), aynanın içinde fırlatma hareketi yapar
			refl.visible = true
			refl.global_transform = Transform3D(mb.rotated(mb.y, PI) * Basis.from_scale(Vector3(1, 1, 0.08)) * float(refl.age_scale), m.global_position - mb.y * 1.12 + mb.z * 0.02)
			refl.play("throw", 0.03, 1.8, true)
			for mi in refl.find_children("*", "GeometryInstance3D", true, false):
				mi.transparency = 0.9
				mi.create_tween().tween_property(mi, "transparency", 0.3, 0.08)
			hand = refl.global_position + Vector3.UP * 1.3 - mb.z * 0.1
			# aynanın içinde yansımanın ardında soluk mavi parıltı (görüntü aynada okunur)
			star(pj, m.global_position + mb.z * 0.04, 2.0, Color(0.85, 0.95, 1.0), 0.3, 4.0)
		sparks(pj, m.global_position, {"n": 10, "life": 0.25, "r": 0.8, "vmin": 0.5, "vmax": 1.5, "size": 0.12, "g": Vector3.ZERO,
			"cols": [Color(1, 1, 1, 1), Color(0.8, 0.93, 1.0, 0.6), Color(0.7, 0.9, 1.0, 0)]})
		# fırlatma: aynadan fırlayan gümüş senbon iğneleri (ince parlak çizgi + iz), ortadakine saplanır
		pj.after(0.12, func():
			if not pj.live(c):
				return
			for q in 4:
				var off = Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
				var p0 = hand + off * 0.4
				var p1 = tgt + off
				var nd = MeshInstance3D.new()
				var cm = CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.018
				cm.height = 0.55
				cm.radial_segments = 4
				nd.mesh = cm
				nd.material_override = _flat_mat(Color(0.92, 0.96, 1.0))
				nd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pj.scene_add(nd, p0)
				nd.look_at(p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.95 else Vector3.RIGHT)
				nd.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
				var tw = nd.create_tween()
				tw.tween_property(nd, "global_position", p1, 0.13 + q * 0.02)
				tw.tween_callback(nd.queue_free)
				streak(pj, PackedVector3Array([p0, p0.lerp(p1, 0.5), p1]), 0.02, Color(0.95, 0.97, 1.0, 0.9), 0.18, true, {"taper": 0.5, "rag": 0.0, "core": 0.6})
			for e in list:
				if not is_instance_valid(e) or e.is_dead() or not is_instance_valid(c):
					continue   # aynalar içinde ölen / silinen hedef (eski kodda da yoktu: hata veriyordu)
				pj.st(e, "slow", 0.4)
				e.take_hit(pj.inf(c, "makyo_hyosho", 0.16, {"knock": 0.0, "kind": "light", "element": "hyoton", "bleed": 1.0}))
			Sfx.play("clink", tgt, 1.4, 0.4)), func():
		if refl and is_instance_valid(refl):
			refl.queue_free()
		for m in mirrors:
			if is_instance_valid(m):
				shards(pj, m.global_position - Vector3.UP * 0.6, 4, 3.5, 0.5, ICEC, 0.5, 0.5, 1.2)
				m.queue_free()
		snow(pj, at + Vector3.UP * 2.5, 2.0, false, 40)
		if is_instance_valid(c):
			if mdl and is_instance_valid(mdl):
				mdl.visible = true
			sparks(pj, c.global_position + Vector3.UP, {"n": 20, "life": 0.4, "vmin": 2.0, "vmax": 5.0, "size": 0.12, "g": Vector3.ZERO,
				"cols": [Color(1, 1, 1, 1), Color(0.7, 0.9, 1.0, 0)]}))
	Sfx.play("clink", at, 0.6)


## Buz aynası (merkez orijinde, yüzü ±Z): gök yansıtan ince buz levha + kırağılı buz çerçeve
static func _mirror(w: float, h: float) -> Node3D:
	var root = Node3D.new()
	var slab = gem(_box(), Color(0.78, 0.93, 1.0), 0.15, 0.25)
	slab.set_instance_shader_parameter("mirror", 1.0)
	root.add_child(slab)
	slab.scale = Vector3(w, h, 0.07)
	var fw = 0.12
	var frame = [[Vector3(0, h * 0.5, 0), Vector3(w + fw, fw, 0.14)], [Vector3(0, -h * 0.5, 0), Vector3(w + fw, fw, 0.14)],
		[Vector3(w * 0.5, 0, 0), Vector3(fw, h, 0.14)], [Vector3(-w * 0.5, 0, 0), Vector3(fw, h, 0.14)]]
	for fr in frame:
		var bar = gem(_box(), Color(0.9, 0.97, 1.0), 1.0, 0.35)
		root.add_child(bar)
		bar.position = fr[0]
		bar.scale = fr[1]
	return root


# ================================================================== 13) Sensatsu Suishō (hyoton_spears)
## Kanon (Haku): yakındaki sudan damlalar yükselir, hedefin çevresinde küre biçiminde bin buz iğnesine donar ve hepsi birden
## içe saplanır; hedef iğnelerle donmuş buz kümesinin içinde kalır, zemin kırağı tutar; süre bitince buz parçalanır
static func hyoton_spears(js, c: Node3D, t: Node3D) -> void:
	if not (c is Player) and not ClanMech.water_near(c.global_position):   # oyuncuyla aynı: yakında su şart
		return
	var m = js._mult(c)
	var center = js._ground(js._aim_ground(c, t, 8.0))
	Sfx.play("clink", center, 0.6)
	ground_mark(js, center, 4.2, 4.2, randf() * TAU, 1.0, 3.5, 0.2)
	# su yükselir: yerden fışkıran damlalar
	sparks(js, center + Vector3.UP * 0.1, {"n": 40, "life": 0.45, "r": 2.6, "dir": Vector3.UP, "spread": 15.0, "vmin": 3.0, "vmax": 6.0,
		"g": Vector3(0, -8, 0), "size": 0.12, "add": false, "cols": [Color(0.9, 0.97, 1.0, 1), Color(0.5, 0.78, 1.0, 0.9), Color(0.5, 0.8, 1.0, 0)]})
	_needle_sphere(js, center + Vector3.UP * 1.0, 2.6, 72)
	for k in 7:   # iğnelerin saplandığı yerde içe eğik buz kümesi
		var a = k * TAU / 7.0 + randf() * 0.3
		var o = Vector3(cos(a), 0, sin(a))
		spike(js, center + o * randf_range(0.8, 1.1), randf_range(0.5, 0.75), randf_range(1.8, 2.8), ICEC, 0.6,
			(Vector3.UP - o * 0.45).normalized(), 0.22 + k * 0.01, 0.18, 2.3, 3)
	for k in 4:   # soğuk sis
		var a2 = k * TAU / 4.0 + 0.4
		puff(js, center + Vector3(cos(a2), 0.3, sin(a2)) * 2.4, 0.55, 1.2, Color(0.96, 0.99, 1.0), Color(0.72, 0.84, 0.94), Vector3(cos(a2), 0.4, sin(a2)) * 1.2)
	# önce dondur (donmuş hedef blok yapamaz), sonra hasar
	for f in js.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and not f.is_dead() and Combat.capsule_hit(center + Vector3.UP, f, 2.6) and f.has_method("apply_status"):
			f.apply_status("stun", 2.5)
	for h in Combat.hit_sphere(c, center + Vector3.UP, 2.6, {"dmg": 22.0 * m, "knock": 0.0, "kind": "light", "element": "hyoton", "hitstop": 0.06}):
		Combat.popup_text(h.global_position + Vector3.UP * 2.4, "DONDU!", Color(0.7, 0.9, 1))
	sparks(js, center + Vector3.UP, {"n": 30, "life": 0.6, "vmin": 5.0, "vmax": 12.0, "size": 0.14, "g": Vector3.ZERO,
		"cols": [Color(1, 1, 1, 1), Color(0.7, 0.9, 1, 0)]})


## Küre biçiminde dizilen buz iğneleri (tek MultiMesh): belirir → içe saplanır → bekler → parçalanır
static func _needle_sphere(host: Node, center: Vector3, R: float, n: int) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _needle_mesh()
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = gem_mat()
	mmi.set_instance_shader_parameter("tint", Vector3(ICEC.r, ICEC.g, ICEC.b))
	mmi.set_instance_shader_parameter("frost", 0.2)
	mmi.set_instance_shader_parameter("glow", 0.8)
	mmi.set_instance_shader_parameter("fade", 1.0)
	mmi.set_instance_shader_parameter("mirror", 0.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(host, mmi, center)
	var dirs = []
	for i in n:   # Fibonacci küresi (yerin altı hariç)
		var y = 1.0 - 1.35 * (i + 0.5) / n
		var rr = sqrt(maxf(0.0, 1.0 - y * y))
		var a = i * 2.39996
		dirs.append(Vector3(cos(a) * rr, y, sin(a) * rr))
	var place = func(rad: float, s: float) -> void:
		for i in n:
			var dv: Vector3 = dirs[i]
			mm.set_instance_transform(i, Transform3D(_axis_basis(-dv).scaled(Vector3.ONE * s), dv * rad))
	place.call(R, 0.01)
	var tw = mmi.create_tween()
	tw.tween_method(func(k: float) -> void: place.call(R, k), 0.01, 1.0, 0.12)
	tw.tween_method(func(k: float) -> void: place.call(lerpf(R, 0.5, k * k), 1.0), 0.0, 1.0, 0.14)
	tw.tween_interval(2.3)
	tw.tween_callback(func(): shards(host, center, 14, 5.0, 0.4, ICEC, 0.7))
	tw.tween_callback(mmi.queue_free)
