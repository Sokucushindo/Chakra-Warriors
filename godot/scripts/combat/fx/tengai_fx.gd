class_name TengaiFX
extends RefCounted
## Tengai Shinsei (Madara, Rinnegan) — anime kaynağına göre (Shippūden 322-323, refs/tengai_shinsei):
##  · gök kararır; göktaşı uzakta, bulut katmanını delerek belirir (etrafında beyaz bulut halkası açılır)
##  · dev, yuvarlak, gri-yeşil benekli kaya; ÖN (iniş) yüzü sıkışmış havayla kara lekeli hücreler + açık hücre sınırları
##    + sınırdan içe ak çizgi tüyleri; kenarında ak hava yayları; arka / üst yüzü pürüzlü, ufalanıp parça saçar
##  · yerde büyüyüp koyulaşan gölge (vuruş alanı), son anda zemin basınç halkası
##  · çarpış: parlama, krater + uzun yarıklar, kalkan kaya levhaları, balistik taşlar, yere yapışık katmanlı gri toz dalgası
##  · kanon: ikinci (daha büyük) göktaşı aynı yörüngeden gelir, gömülü birincinin tepesine çarpar: temas çizgisinden yatay
##    katmanlı toz çiçeği + kara taş zerreleri, ikisinde de ak çatlaklar yayılır, kayalar dikey levhalara ayrılıp çöker,
##    tepeden toz sütunu yükselir; enkaz ve krater bir süre kalır.
## Görünen her şey bu dosyanın kendi gölgelendiricileri ve geometrisiyle sıfırdan üretilir (ortak / hazır efekt yok).
## Oynanış eski işleyiciden: hedef 40 m, 1. çarpış 14 m yarıçap (x5, knock 30), 2. çarpış 20 m (x5, knock 36); AI aynı yoldan atar.

static var _cache := {}

const ROCK_COL := Color(0.36, 0.38, 0.33)
const EARTH_COL := Color(0.42, 0.35, 0.27)
const R1 := 80.0          # birinci göktaşı yarıçapı (m): 160 m çap, gökyüzünü kaplar (ref kare 1-3)
const R2 := 95.0          # ikinci göktaşı (daha büyük)
const FOOT1 := 14.0       # birincinin zemine gömülen tabanı = vuruş yarıçapı
const FOOT2 := 20.0       # ikinci çarpışın vuruş yarıçapı
const DUR1 := 3.3         # iniş süresi
const DUR2 := 3.6
const SPAWN2 := 1.7       # ikincinin belirdiği an


# ================================================================== gölgelendiriciler
const NOISE3 := """
float h13(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
vec3 h33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 4; i++) { s += a * vn(p); p = p * 2.03 + vec3(1.7, 9.2, 3.1); a *= 0.5; } return s; }
vec2 vor(vec3 p, out vec3 fp) {
	vec3 i = floor(p); vec3 f = fract(p); float d1 = 8.0; float d2 = 8.0; fp = vec3(0.0);
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z)); vec3 o = h33(i + g); vec3 r = g + o - f; float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; fp = i + g + o; } else if (d < d2) { d2 = d; }
	}
	return vec2(sqrt(d1), sqrt(d2));
}
"""

const NOISE2 := """
float h12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn2(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1, 0)), f.x), mix(h12(i + vec2(0, 1)), h12(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 4; i++) { s += a * vn2(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; } return s; }
"""

## Cel ışık (oyunun toon gölgesiyle aynı iki bant + soğuk gölge tonu)
const CEL_LIGHT := """
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.03, 0.05, ndl) * 0.6 + smoothstep(0.42, 0.5, ndl) * 0.4;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 shade = mix(vec3(0.29, 0.31, 0.43), vec3(1.0), t * ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * shade / PI;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * (0.35 + 0.65 * t) * ATTENUATION / PI;
	}
}
"""

## Göktaşı kayası: benekli gri-yeşil, krater içleri koyu / dudakları açık (köşe rengi), ön yüzde basınç hücreleri (press),
## ak çatlaklar (crack, crack_from yönünden yayılır), noktalı çözülme (fade). +Y = arka (iz) yüzü, -Y = iniş yüzü.
const ROCK_SHADER := """
shader_type spatial;
render_mode cull_disabled;
instance uniform vec4 base_col : source_color = vec4(0.36, 0.38, 0.33, 1.0);
instance uniform float press = 0.0;
instance uniform float crack = 0.0;
instance uniform vec3 crack_from = vec3(0.0, -1.0, 0.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying vec3 op;
varying float v_cr;
varying float v_rim;
%s
void vertex() {
	op = VERTEX;
	v_cr = COLOR.r;
	v_rim = COLOR.g;
}
void fragment() {
	vec3 n = normalize(op);
	float lf = -n.y;
	float m = fbm(op * 2.3 + seed);
	float sp = vn(op * 11.0 + seed * 1.7);
	vec3 col = base_col.rgb * (0.72 + m * 0.55);
	col *= mix(1.0, 0.62, smoothstep(0.62, 0.78, sp));
	col = mix(col, col * 0.42, v_cr);
	col = mix(col, min(col * 1.4, vec3(1.0)), v_rim * 0.8);
	if (press > 0.001) {
		float cap = smoothstep(-0.05, 0.42, lf) * press;
		if (cap > 0.001) {
			vec3 fp;
			vec3 vp = op * 1.55 + vec3(seed) + vec3(vn(op * 3.0), vn(op * 3.0 + 7.0), vn(op * 3.0 + 13.0)) * 0.55;
			vec2 v = vor(vp, fp);
			float e = (v.y - v.x) + (vn(op * 9.0 + 2.0) - 0.5) * 0.06;
			vec3 d = vp - fp;
			vec3 t = normalize(cross(n, vec3(0.0, 0.0, 1.0)) + vec3(1e-4, 2e-4, 0.0));
			vec3 b = cross(n, t);
			float ang = atan(dot(d, b), dot(d, t)) / 6.2831853 + 0.5;
			float bins = 46.0;
			float bi = floor(ang * bins);
			float hh = h13(vec3(bi, fp.x * 7.3, fp.z * 3.1 + fp.y));
			float hair = 1.0 - smoothstep(0.08, 0.32, abs(fract(ang * bins) - 0.5));
			hair *= 1.0 - smoothstep(0.04 + hh * 0.06, 0.07 + hh * 0.08, e);
			hair *= step(0.4, hh);
			float inner = smoothstep(0.03, 0.07, e);
			vec3 cc = mix(vec3(0.6, 0.63, 0.58), vec3(0.06, 0.07, 0.06), inner);
			cc = mix(cc, vec3(0.5, 0.53, 0.5), hair * inner * 0.6);
			col = mix(col, cc, cap);
		}
	}
	if (crack > 0.001) {
		vec3 fp2;
		vec2 v2 = vor(op * 1.7 + vec3(seed * 3.0) + vec3(vn(op * 5.0) * 0.45, vn(op * 7.0 + 3.0) * 0.45, 0.0), fp2);
		float e2 = v2.y - v2.x;
		float line = (1.0 - smoothstep(0.008, 0.022, e2)) * step(0.4, h13(floor(fp2 * 3.0) + vec3(seed)));
		float dd = (1.0 - dot(n, normalize(crack_from))) * 0.5;
		float mask = 1.0 - smoothstep(crack * 1.12 - 0.08, crack * 1.12, dd + vn(op * 4.0) * 0.12);
		col = mix(col, vec3(0.9, 0.91, 0.88), line * mask);
	}
	if (fade < 0.999 && vn(op * 5.0 + vec3(seed)) > fade) discard;
	if (!FRONT_FACING) { col = vec3(0.04, 0.04, 0.035); }
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
%s
"""

## Ak hava yayları: kabuk yalnız siluet bandında, ön yarıda, kesik kesik akan beyaz yaylar çizer (geometri görünmez)
const AIR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
varying vec3 op;
%s
void vertex() { op = VERTEX; }
void fragment() {
	vec3 n = normalize(op);
	float lf = -n.y;
	float f = abs(dot(NORMAL, VIEW));
	float band = (1.0 - smoothstep(0.1, 0.26, f)) * smoothstep(0.015, 0.06, f);
	float hf = smoothstep(-0.35, 0.1, lf) * (1.0 - smoothstep(0.85, 0.98, lf));
	float seg = vn(vec3(n.xz * 3.2 + vec2(seed), n.y * 7.0 + TIME * 2.6));
	float dash = step(0.52, seg);
	ALBEDO = mix(vec3(0.82, 0.88, 0.96), vec3(1.0), step(0.62, seg));
	ALPHA = band * hf * dash * fade * 0.95;
}
"""

## Arkaya uzanan ince hız çizgisi: dörtgen, köşe gölgelendiricisinde eksen boyunca (axis) kameraya dönük gerilir
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float fade = 1.0;
instance uniform vec3 axis = vec3(0.0, 1.0, 0.0);
instance uniform float len = 20.0;
instance uniform float wid = 0.6;
instance uniform float seed = 0.0;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 ax = normalize(axis);
	vec3 side = normalize(cross(ax, normalize(cam - o)));
	float u = VERTEX.y + 0.5;
	vec3 w = o + ax * u * len + side * VERTEX.x * wid * (1.0 - u * 0.85);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	float u = 1.0 - UV.y;
	float flick = 0.65 + 0.35 * sin(TIME * 23.0 + seed * 9.0);
	float a = (1.0 - smoothstep(0.55, 1.0, u)) * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5)));
	ALBEDO = vec3(0.92, 0.95, 1.0);
	ALPHA = a * fade * flick * 0.75;
}
"""

## Bulut katmanında açılan halka (gökten bakınca beyaz, kabarık kenarlı; open ile delik büyür)
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float open = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
%s
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ri = mix(0.16, 0.5, open) + (fbm2(p * 3.0 + seed) - 0.5) * 0.16;
	float ro = mix(0.34, 0.96, open) * (0.86 + fbm2(p * 2.0 + seed + 4.0) * 0.18);
	float inside = smoothstep(ri, ri + 0.015, r) * (1.0 - smoothstep(ro - 0.02, ro, r));
	float puff = fbm2(p * 7.0 + seed * 2.0);
	vec3 c = mix(vec3(0.74, 0.79, 0.88), vec3(0.97, 0.98, 1.0), step(0.47, puff));
	c = mix(c, vec3(1.0), 1.0 - smoothstep(ri, ri + 0.06, r));
	ALBEDO = c;
	ALPHA = inside * fade * 0.94;
}
"""

## Zemindeki gölge: koyulaşan yumuşak daire + içte vuruş alanı (core)
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float dark = 0.0;
instance uniform float core = 0.5;
%s
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p) + (vn2(p * 4.0) - 0.5) * 0.08;
	float s = (1.0 - smoothstep(0.55, 1.0, r)) * dark;
	float cr = (1.0 - smoothstep(core - 0.03, core, r)) * dark * 0.35;
	ALBEDO = vec3(0.02, 0.02, 0.05);
	ALPHA = clamp(s * 0.62 + cr, 0.0, 0.85);
}
"""

## Basınç halkası: göktaşı yere değmeden önce dışa yatan toz / ot çizgileri
const PRESS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
%s
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float u = a * 70.0;
	float hh = h12(vec2(floor(u), seed));
	float line = 1.0 - smoothstep(0.12, 0.4, abs(fract(u) - 0.5));
	float r0 = mix(0.3, 1.0, prog);
	float band = smoothstep(r0 - 0.22 - hh * 0.18, r0 - 0.04, r) * (1.0 - smoothstep(r0 - 0.03, r0, r));
	ALBEDO = mix(vec3(0.8, 0.74, 0.64), vec3(0.95, 0.92, 0.86), line);
	ALPHA = (band * line * step(0.3, hh) * 0.85 + band * 0.22) * fade;
}
"""

## Krater: gölgeli çanak, açık dudak, dışa uzanan kara yarıklar, çevrede koyu toz halkası (prog büyür, fade söner)
const CRATER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float bowl = 0.36;
%s
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float rb = bowl * prog * (1.0 + (vn2(p * 3.0 + seed) - 0.5) * 0.14);
	vec3 c = vec3(0.33, 0.29, 0.25);
	float al = step(rb * 1.15, r) * (1.0 - smoothstep(rb * 1.4, min(0.98, rb * 2.5), r)) * 0.42;
	float K = 15.0;
	float u = a * K;
	float bi = floor(u);
	float hh = h12(vec2(bi, seed));
	float jit = (vn2(vec2(r * 9.0, bi * 3.1)) - 0.5) * 0.4;
	float w = mix(0.2, 0.05, clamp((r - rb) / max(0.01, 1.0 - rb), 0.0, 1.0));
	float fl = 1.0 - smoothstep(w * 0.5, w, abs(fract(u + jit) - 0.5));
	float flen = rb + (0.98 - rb) * (0.35 + hh * 0.65) * prog;
	fl *= step(rb, r) * (1.0 - smoothstep(flen - 0.05, flen, r)) * step(0.22, hh);
	float edge = (1.0 - smoothstep(w * 0.9, w * 1.5, abs(fract(u + jit) - 0.5))) * step(rb, r) * (1.0 - smoothstep(flen - 0.05, flen, r)) * step(0.22, hh) - fl;
	c = mix(c, vec3(0.7, 0.63, 0.52), clamp(edge, 0.0, 1.0));
	al = max(al, clamp(edge, 0.0, 1.0) * 0.8);
	c = mix(c, vec3(0.07, 0.055, 0.05), fl);
	al = max(al, fl * 0.95);
	float rim = smoothstep(rb * 0.96, rb * 1.02, r) * (1.0 - smoothstep(rb * 1.1, rb * 1.2, r));
	c = mix(c, vec3(0.66, 0.58, 0.46), rim);
	al = max(al, rim);
	if (r < rb) {
		vec2 q = p / max(rb, 0.001);
		float lit = dot(q, normalize(vec2(0.6, 0.8)));
		float depth = 1.0 - dot(q, q);
		vec3 bc = mix(vec3(0.17, 0.14, 0.12), vec3(0.36, 0.3, 0.24), step(0.25, lit));
		bc = mix(bc, vec3(0.09, 0.075, 0.065), step(0.8, depth));
		float fr = 1.0 - smoothstep(0.02, 0.06, abs(fract(u * 0.5 + jit) - 0.5));
		bc = mix(bc, vec3(0.05), fr * 0.6 * step(0.3, hh));
		c = bc;
		al = 1.0;
	}
	ALBEDO = c;
	ALPHA = al * fade;
}
"""

## Toz topağı: opak cel (gri katmanlı anime tozu), gürültüyle aşınarak yok olur (erode); saydam bulut / duman kartı değil
const DUST_SHADER := """
shader_type spatial;
render_mode cull_back;
instance uniform vec4 col : source_color = vec4(0.62, 0.6, 0.56, 1.0);
instance uniform float erode = 0.0;
instance uniform float seed = 0.0;
varying vec3 op;
%s
void vertex() { op = VERTEX; }
void fragment() {
	float nn = fbm(op * 2.2 + vec3(seed));
	float th = mix(0.05, 0.95, erode);
	if (nn < th) discard;
	// kameraya çok yakın toz seyrelir (ekranı kaplayan tek topak olmasın)
	if (-VERTEX.z < 2.5) discard;
	vec3 c = col.rgb;
	c = mix(c * 0.7, c, smoothstep(th, th + 0.05, nn));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.05, 0.05, ndl) * 0.55 + smoothstep(0.45, 0.52, ndl) * 0.45;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(vec3(0.45, 0.47, 0.58), vec3(1.0), t * ATTENUATION) / PI;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * t * ATTENUATION * 0.6 / PI;
	}
}
"""


## Toz levhası (ref kare 4): yassı, katmanlı, yana fışkıran gri cel toz; kenarı tırtıklı, gürültüyle delinerek söner
const SHEET_SHADER := """
shader_type spatial;
render_mode cull_disabled;
instance uniform vec4 col : source_color = vec4(0.7, 0.7, 0.68, 1.0);
instance uniform float erode = 0.0;
instance uniform float seed = 0.0;
varying vec3 op;
%s
void vertex() { op = VERTEX; }
void fragment() {
	float r = length(op.xz);
	vec2 ap = op.xz / max(r, 0.001);
	float edge = 0.8 + (fbm(vec3(ap * 2.2, seed)) - 0.45) * 0.45 + (vn(vec3(ap * 13.0, seed + 5.0)) - 0.5) * 0.1;
	if (r > edge) discard;
	float hole = fbm(vec3(op.x * 3.0, op.y * 5.0, op.z * 3.0) + vec3(seed));
	if (hole + (1.0 - r / max(edge, 0.01)) * 0.45 < erode * 1.15) discard;
	if (-VERTEX.z < 2.5) discard;
	float band = step(0.5, vn(vec3(ap * 4.0, r * 6.0 + seed)));
	vec3 c = col.rgb * mix(0.86, 1.04, band);
	if (!FRONT_FACING) { c *= 0.7; }
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.05, 0.05, ndl) * 0.55 + smoothstep(0.45, 0.52, ndl) * 0.45;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR * mix(vec3(0.5, 0.52, 0.6), vec3(1.0), t * ATTENUATION) / PI;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * t * ATTENUATION * 0.6 / PI;
	}
}
"""

## Uzun düz yer yarığı (ref son kare): kara çekirdek, açık dudak, tırtıklı, uca doğru incelir; prog ile boyu uzar
const FISSURE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
%s
void fragment() {
	float u = UV.y;
	float x = (UV.x - 0.5) * 2.0;
	float w = (0.3 + 0.7 * (1.0 - u)) * (0.65 + 0.35 * vn2(vec2(u * 25.0, seed)));
	float jag = (vn2(vec2(u * 70.0, seed + 3.0)) - 0.5) * 0.5 + (vn2(vec2(u * 9.0, seed + 8.0)) - 0.5) * 0.5;
	float d = abs(x - jag);
	float core = 1.0 - smoothstep(w * 0.3, w * 0.4, d);
	float lip = 1.0 - smoothstep(w * 0.5, w * 0.75, d);
	vec3 c = mix(vec3(0.6, 0.53, 0.43), vec3(0.05, 0.04, 0.035), core);
	ALBEDO = c;
	ALPHA = lip * step(u, prog) * fade * (1.0 - smoothstep(0.92, 1.0, u));
}
"""


# ================================================================== küçük yardımcılar
static func _mat(key: String) -> ShaderMaterial:
	if _cache.has("m_" + key):
		return _cache["m_" + key]
	var code := ""
	match key:
		"rock": code = ROCK_SHADER % [NOISE3, CEL_LIGHT]
		"air": code = AIR_SHADER % NOISE3
		"streak": code = STREAK_SHADER
		"cloud": code = CLOUD_SHADER % NOISE2
		"shadow": code = SHADOW_SHADER % NOISE2
		"press": code = PRESS_SHADER % NOISE2
		"crater": code = CRATER_SHADER % NOISE2
		"dust": code = DUST_SHADER % NOISE3
		"sheet": code = SHEET_SHADER % NOISE3
		"fissure": code = FISSURE_SHADER % NOISE2
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["m_" + key] = m
	return m


static func _gi(mesh: Mesh, key: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _put(host: Node, n: Node3D, p: Vector3) -> Node3D:
	host.add_child(n)
	n.add_to_group("tengai_fx")
	n.global_position = p
	return n


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	var w = weakref(mi)
	return func(x):
		var o = w.get_ref()
		if o != null and is_instance_valid(o):
			o.set_instance_shader_parameter(pname, x)


static func _plane() -> PlaneMesh:
	if not _cache.has("plane"):
		var p = PlaneMesh.new()
		p.size = Vector2(2, 2)
		p.subdivide_width = 24
		p.subdivide_depth = 24
		_cache["plane"] = p
	return _cache["plane"]


static func _ball() -> SphereMesh:
	if not _cache.has("ball"):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 48
		s.rings = 24
		_cache["ball"] = s
	return _cache["ball"]


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_cache["quad"] = q
	return _cache["quad"]


## Zemine serilen düzlem (engebeye oturtulur)
static func _decal(host: Node, key: String, pos: Vector3, r: float, params: Dictionary) -> MeshInstance3D:
	var mi = _gi(_plane(), key)
	for k in params:
		mi.set_instance_shader_parameter(k, params[k])
	_put(host, mi, pos)
	mi.scale = Vector3(r, 1.0, r)
	preload("res://scripts/combat/fx/lib/ground_drape.gd").auto(mi)   # yalnız geometri: engebeli araziye oturur
	return mi


static func _cam(host: Node) -> Camera3D:
	return host.get_viewport().get_camera_3d() if host and host.is_inside_tree() else null


## Uzaklığa göre sarsıntı / parlama katsayısı (yakında 1, ~14 R ötede 0.12)
static func _near_k(host: Node, at: Vector3, R: float) -> float:
	var cam = _cam(host)
	if cam == null:
		return 1.0
	var d = cam.global_position.distance_to(at)
	return clampf(1.0 - (d - R) / (R * 14.0), 0.12, 1.0)


static func _quake(host: Node, at: Vector3, R: float, shake: float, flash: float) -> void:
	if Game.world == null:
		return
	var k = _near_k(host, at, R)
	Game.world.env.add_shake(shake * k)
	if flash > 0.0:
		Game.world.env.screen_flash(flash * k)


# ================================================================== geometri
## Küre tabanlı ağ: hfn(yön) -> Vector3(yükseklik, renk r, renk g). Normaller yükseklik alanından (dikiş yok); ön yüz saat yönü.
static func _sphere_mesh(RA: int, RI: int, hfn: Callable, stretch := Vector3.ONE) -> ArrayMesh:
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var cols = PackedColorArray()
	var idx = PackedInt32Array()
	for j in RI + 1:
		var phi = PI * j / RI
		for i in RA + 1:
			var th = TAU * i / RA
			var d = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			if j == 0:
				d = Vector3.UP
			elif j == RI:
				d = Vector3.DOWN
			var h: Vector3 = hfn.call(d)
			var p = d * (1.0 + h.x) * stretch
			var t1 = d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
			var t2 = d.cross(t1)
			var d1 = (d + t1 * 0.012).normalized()
			var d2 = (d + t2 * 0.012).normalized()
			var p1 = d1 * (1.0 + (hfn.call(d1) as Vector3).x) * stretch
			var p2 = d2 * (1.0 + (hfn.call(d2) as Vector3).x) * stretch
			var n = (p1 - p).cross(p2 - p).normalized()
			if n.dot(d) < 0.0:
				n = -n
			verts.append(p)
			norms.append(n)
			cols.append(Color(h.y, h.z, 0.0, 1.0))
	for j in RI:
		for i in RA:
			var a = j * (RA + 1) + i
			var b = a + 1
			var c = a + RA + 1
			var e = c + 1
			for tri in [[a, c, b], [b, c, e]]:
				var pa = verts[tri[0]]
				var pb = verts[tri[1]]
				var pc = verts[tri[2]]
				if (pb - pa).cross(pc - pa).dot(pa + pb + pc) > 0.0:
					idx.append_array([tri[0], tri[2], tri[1]])
				else:
					idx.append_array([tri[0], tri[1], tri[2]])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Göktaşı kayası (yarıçap ~1): ön (-Y) yüz pürüzsüze yakın + kraterler, arka (+Y) yüz sırt sırt kırık bloklar (ufalanıyor)
static func _rock_mesh() -> ArrayMesh:
	if _cache.has("rock"):
		return _cache["rock"]
	var nz = FastNoiseLite.new()
	nz.seed = 731
	nz.frequency = 1.6
	nz.fractal_octaves = 4
	var rz = FastNoiseLite.new()
	rz.seed = 112
	rz.frequency = 2.4
	rz.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	rz.fractal_octaves = 3
	var rng = RandomNumberGenerator.new()
	rng.seed = 9061
	var craters = []
	for q in 26:
		var cd = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		craters.append([cd, rng.randf_range(0.07, 0.26)])
	var hfn = func(d: Vector3) -> Vector3:
		var top = clampf(d.y, 0.0, 1.0)
		var h = nz.get_noise_3dv(d) * 0.05 + rz.get_noise_3dv(d) * (0.015 + top * top * 0.1)
		var cr = 0.0
		var rim = 0.0
		for c in craters:
			var dd = d.dot(c[0])
			if dd < 0.9:
				continue
			var a = acos(clampf(dd, -1.0, 1.0)) / c[1]
			if a < 1.0:
				h -= (1.0 - a * a) * c[1] * 0.3
				cr = maxf(cr, 1.0 - a)
			elif a < 1.5:
				var k = maxf(0.0, 1.0 - absf(a - 1.15) / 0.35)
				h += k * c[1] * 0.08
				rim = maxf(rim, k)
		return Vector3(h, cr, rim)
	_cache["rock"] = _sphere_mesh(88, 44, hfn)
	return _cache["rock"]


## Toz topağı ağı (3 çeşit): yumuşak, kabarık yumru
static func _lobe_mesh(v: int) -> ArrayMesh:
	var key = "lobe%d" % v
	if _cache.has(key):
		return _cache[key]
	var nz = FastNoiseLite.new()
	nz.seed = 300 + v * 41
	nz.frequency = 1.1
	nz.fractal_octaves = 2
	var hfn = func(d: Vector3) -> Vector3:
		return Vector3(nz.get_noise_3dv(d * 1.4) * 0.28 + maxf(0.0, d.y) * 0.08, 0.0, 0.0)
	_cache[key] = _sphere_mesh(18, 12, hfn)
	return _cache[key]


## Köşeli taş parçası (4 çeşit, düz yüzlü)
static func _chunk_mesh(v: int) -> ArrayMesh:
	var key = "chunk%d" % v
	if _cache.has(key):
		return _cache[key]
	var nz = FastNoiseLite.new()
	nz.seed = 50 + v * 13
	nz.frequency = 1.3
	var RA = 7
	var RI = 5
	var grid = []
	for j in RI + 1:
		var row = []
		var phi = PI * j / RI
		for i in RA:
			var th = TAU * i / RA + (0.35 if j % 2 == 1 else 0.0)
			var d = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			row.append(d * (1.0 + nz.get_noise_3dv(d * 1.5) * 0.4))
		grid.append(row)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.0, 0.0, 0.0, 1.0))
	for j in RI:
		for i in RA:
			var i2 = (i + 1) % RA
			_tri(st, grid[j][i], grid[j + 1][i], grid[j][i2])
			_tri(st, grid[j][i2], grid[j + 1][i], grid[j + 1][i2])
	_cache[key] = st.commit()
	return _cache[key]


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cr = (b - a).cross(c - a)
	if cr.length() < 1e-6:
		return
	var ctr = (a + b + c) / 3.0
	if cr.dot(ctr) > 0.0:
		var t = b
		b = c
		c = t
		cr = -cr
	var n = -cr.normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


# ================================================================== ana akış
static func cast(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 40.0)
	var goal: Vector3 = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 20.0)
	var host: Node = pj.get_tree().current_scene
	DojutsuFXB._eye_glint(pj, c, Color(0.8, 0.72, 1.0), 3.0)   # Rinnegan parıltısı
	# yörünge: göktaşı izleyen kameranın baktığı yönde, hedefin ardından alçalarak gelir (görüş içinde iner)
	var cam = _cam(host)
	var cpos: Vector3 = cam.global_position if cam else c.global_position - c.face_dir() * 5.0
	var away = goal - cpos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.5 else c.face_dir()
	away = away.rotated(Vector3.UP, randf_range(-0.22, 0.22))
	var sink1 = R1 - sqrt(R1 * R1 - FOOT1 * FOOT1)
	var E1 = goal + Vector3.UP * (R1 - sink1)
	var S1 = goal + away * 360.0 + Vector3.UP * 170.0   # ~400 m ötede, kameranın üst yarısında: ilk saniyeden çerçevenin üçte biri
	var top1 = E1 + Vector3.UP * R1
	var E2 = top1 + Vector3.UP * (R2 * 0.92)
	var S2 = goal + away * 520.0 + Vector3.UP * 420.0
	var st = {"m1": null, "m2": null, "shat": false}
	# gök kararır (izleyen yakınsa)
	if Game.world and cpos.distance_to(goal) < 800.0:
		Game.world.env.flash_tint(Color(0.03, 0.04, 0.09, 0.3), SPAWN2 + DUR2 + 0.5)
	Sfx.play("boom", goal, 0.3, 0.6)
	# yerdeki gölge: büyüyüp koyulaşır, iç halka vuruş alanı
	var sh = _decal(host, "shadow", goal + Vector3.UP * 0.06, R1 * 1.3, {"dark": 0.0, "core": FOOT1 / (R1 * 1.3)})
	var shtw = sh.create_tween()
	shtw.tween_method(_pf(sh, "dark"), 0.0, 1.0, DUR1 + 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shtw.tween_method(_pf(sh, "dark"), 1.0, 0.0, 0.25)
	shtw.tween_callback(sh.queue_free)
	# birinci göktaşı
	pj.after(0.15, func():
		var md = _meteor(host, R1, S1, E1, 11.0)
		st["m1"] = md
		_cloud_ring(host, S1 + Vector3.UP * R1 * 0.3, R1)
		_drop(host, md, S1, E1, DUR1, func(): _land1(pj, c, host, st, goal)))
	# ikinci (daha büyük) göktaşı aynı yörüngeden, birincinin tepesine
	pj.after(SPAWN2, func():
		var md2 = _meteor(host, R2, S2, E2, 27.0)
		st["m2"] = md2
		_cloud_ring(host, S2 + Vector3.UP * R2 * 0.3, R2)
		_drop(host, md2, S2, E2, DUR2, func(): _collide(pj, c, host, st, goal, top1)))
	# kırılma dilimlerinin ağları iniş sırasında karede bir tane hazırlanır (çarpış anında takılma olmasın)
	for i in SLICES:
		host.get_tree().create_timer(0.6 + i * 0.12).timeout.connect(func(): _slice_mesh(i))
	# güvenlik: ikincisi hiç gelmezse (atan öldü) birincisi kendi dağılır
	host.get_tree().create_timer(SPAWN2 + DUR2 + 3.0).timeout.connect(func():
		if not st["shat"] and st["m1"] != null:
			st["shat"] = true
			_shatter(host, st["m1"], goal))


## Göktaşı düğümü: kök (ölçek R, +Y arkaya), kaya, hava yayı kabukları, arkaya uzanan hız çizgileri, arka yüzde gevşek bloklar
static func _meteor(host: Node, R: float, S: Vector3, E: Vector3, seed: float) -> Dictionary:
	var lead = (E - S).normalized()
	var root = Node3D.new()
	host.add_child(root)
	root.add_to_group("tengai_fx")
	root.global_position = S
	var y = -lead
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	root.global_basis = Basis(x, y, z)
	root.scale = Vector3.ONE * R
	var rock = _gi(_rock_mesh(), "rock")
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(rock)
	rock.rotation.y = randf() * TAU
	rock.set_instance_shader_parameter("base_col", ROCK_COL)
	rock.set_instance_shader_parameter("seed", seed)
	rock.set_instance_shader_parameter("press", 0.0)
	rock.set_instance_shader_parameter("crack", 0.0)
	rock.set_instance_shader_parameter("crack_from", Vector3(0, -1, 0))
	rock.set_instance_shader_parameter("fade", 1.0)
	var bits = []
	for k in 16:   # arka yüzde kopmak üzere olan iri bloklar (ref: üstü dağılıyor)
		var d = Vector3(randf_range(-0.8, 0.8), randf_range(0.35, 1.0), randf_range(-0.8, 0.8)).normalized()
		var b = _gi(_chunk_mesh(k % 4), "rock")
		b.set_instance_shader_parameter("base_col", ROCK_COL.darkened(randf_range(0.05, 0.25)))
		b.set_instance_shader_parameter("seed", seed + k)
		b.set_instance_shader_parameter("fade", 1.0)
		root.add_child(b)
		b.position = d * randf_range(1.03, 1.15)
		b.rotation = Vector3(randf(), randf(), randf()) * TAU
		b.scale = Vector3.ONE * randf_range(0.06, 0.14)
		bits.append(b)
	var air = []
	for s in [1.05, 1.13]:
		var a = _gi(_ball(), "air")
		a.set_instance_shader_parameter("fade", 1.0)
		a.set_instance_shader_parameter("seed", seed + s * 10.0)
		root.add_child(a)
		a.scale = Vector3.ONE * s
		air.append(a)
	var streaks = Node3D.new()
	root.add_child(streaks)
	for k in 9:
		var an = TAU * k / 9.0 + randf_range(-0.2, 0.2)
		var q = _gi(_quad(), "streak")
		q.custom_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
		q.set_instance_shader_parameter("axis", -lead)
		q.set_instance_shader_parameter("len", R * randf_range(1.6, 3.4))
		q.set_instance_shader_parameter("wid", R * randf_range(0.03, 0.06))
		q.set_instance_shader_parameter("seed", float(k))
		q.set_instance_shader_parameter("fade", 1.0)
		streaks.add_child(q)
		q.position = Vector3(cos(an) * 1.0, -0.05, sin(an) * 1.0)
	return {"root": root, "rock": rock, "air": air, "streaks": streaks, "bits": bits, "R": R, "lead": lead, "landed": false, "seed": seed}


## İniş: yavaş başlayıp hızlanır (ease-in); ön yüz basıncı artar, arka yüzden parçalar kopar
static func _drop(host: Node, md: Dictionary, S: Vector3, E: Vector3, dur: float, on_land: Callable) -> void:
	var root: Node3D = md["root"]
	root.global_position = S
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", E, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(md["rock"], "press"), 0.0, 1.0, dur * 0.55)
	tw.tween_callback(on_land)
	var tree = host.get_tree()
	var n = int(dur / 0.16)
	for k in n:
		tree.create_timer(0.05 + k * 0.16).timeout.connect(func():
			if is_instance_valid(root) and not md["landed"]:
				_shed(host, md, k))
	# yere değmeden önce zemin basınç halkası
	var goal_g = E - Vector3.UP * (md["R"] as float)
	tree.create_timer(maxf(0.0, dur - 0.55)).timeout.connect(func():
		if is_instance_valid(root):
			_pressure(host, Game.jutsu_floor_at(goal_g + Vector3.UP * 2.0), md["R"]))


## Arka yüzden kopan taşlar: göktaşı hızlanınca geride iz gibi kalır
static func _shed(host: Node, md: Dictionary, k: int) -> void:
	var root: Node3D = md["root"]
	var R: float = md["R"]
	var lead: Vector3 = md["lead"]
	var bits: Array = md["bits"]
	if k % 2 == 0 and not bits.is_empty():   # gövdedeki gevşek blok kopar
		var b = bits.pop_back()
		if is_instance_valid(b):
			var gp = b.global_position
			var gs = b.global_transform.basis.get_scale()
			b.get_parent().remove_child(b)
			_put(host, b, gp)
			b.scale = gs
			var tw = b.create_tween().set_parallel()
			tw.tween_property(b, "global_position", gp - lead * R * 0.6 + (gp - root.global_position).normalized() * R * 0.25, 2.0).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "rotation", b.rotation + Vector3(2.0, 1.5, 0.7), 2.0)
			tw.tween_property(b, "scale", gs * 0.02, 0.8).set_delay(1.4)
			tw.chain().tween_callback(b.queue_free)
	for q in 3:
		var dv = (-lead + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.8).normalized()
		if dv.dot(-lead) < 0.2:
			dv = (dv - lead * 0.7).normalized()
		var p = root.global_position + dv * R * 1.02
		var mi = _gi(_chunk_mesh((k + q) % 4), "rock")
		mi.set_instance_shader_parameter("base_col", ROCK_COL.darkened(randf_range(0.0, 0.3)))
		mi.set_instance_shader_parameter("seed", float(k * 3 + q))
		mi.set_instance_shader_parameter("fade", 1.0)
		_put(host, mi, p)
		var sz = R * randf_range(0.025, 0.07)
		mi.scale = Vector3.ONE * sz
		mi.rotation = Vector3(randf(), randf(), randf()) * TAU
		var life = randf_range(1.4, 2.2)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p + dv * R * 0.35 - lead * R * 0.25, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mi, "rotation", mi.rotation + Vector3(3, 2, 1) * randf_range(0.5, 1.5), life)
		tw.tween_property(mi, "scale", Vector3.ONE * sz * 0.02, 0.5).set_delay(life - 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Gökte açılan bulut halkası (göktaşı bulut katmanını delerek belirir)
static func _cloud_ring(host: Node, at: Vector3, R: float) -> void:
	var mi = _gi(_plane(), "cloud")
	mi.set_instance_shader_parameter("open", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	mi.set_instance_shader_parameter("seed", randf() * 20.0)
	_put(host, mi, at)
	mi.scale = Vector3(R * 7.0, 1.0, R * 7.0)
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "open"), 0.0, 1.0, 3.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 1.4).set_delay(2.4)
	tw.tween_callback(mi.queue_free)


## Çarpış öncesi: zeminde dışa yatan basınç çizgileri + tabanda savrulan küçük toz
static func _pressure(host: Node, g: Vector3, R: float) -> void:
	var mi = _decal(host, "press", g + Vector3.UP * 0.08, R * 2.6, {"prog": 0.0, "fade": 1.0, "seed": randf() * 10.0})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "prog"), 0.0, 1.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, 0.5).set_delay(0.6)
	tw.tween_callback(mi.queue_free)


# ================================================================== çarpışlar
## Birinci göktaşı yere gömülür
static func _land1(pj: PathJutsu, c: Node3D, host: Node, st: Dictionary, goal: Vector3) -> void:
	var md: Dictionary = st["m1"]
	md["landed"] = true
	var rock = md["rock"]
	var tw = rock.create_tween()
	tw.tween_method(_pf(rock, "press"), 1.0, 0.0, 0.35)
	tw.parallel().tween_method(_pf(rock, "crack"), 0.0, 0.3, 0.45)
	_calm(md)
	# gömülü kaya katı (kural 18): görselin kendi küresi; altında kalanlar dışarı itilir
	var C: Vector3 = md["root"].global_position
	_impact(host, goal, R1, FOOT1, ROCK_COL)
	var sph = SphereShape3D.new()
	sph.radius = R1 * 0.97
	md["body"] = _solid(host, sph, Transform3D(Basis(), C), C)
	if pj.live(c):
		pj.hit(c, goal + Vector3.UP, FOOT1, pj.inf(c, "tengai_shinsei", 5.0, {"knock": 30.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.2}))
	Sfx.play("boom", goal, 0.35, 1.0)
	_quake(host, goal, R1, 2.8, 0.45)


## Hava yayları ve hız çizgileri söner
static func _calm(md: Dictionary) -> void:
	for a in md["air"]:
		if is_instance_valid(a):
			var t = a.create_tween()
			t.tween_method(_pf(a, "fade"), 1.0, 0.0, 0.15)
			t.tween_callback(a.queue_free)
	var s = md["streaks"]
	if is_instance_valid(s):
		s.queue_free()


## Yere çarpış: ışık, krater + yarıklar, dudakta kalkan levhalar, balistik taşlar, yere yapışık katmanlı toz dalgası
static func _impact(host: Node, g: Vector3, R: float, foot: float, rock_col: Color) -> void:
	var lt = OmniLight3D.new()
	lt.light_color = Color(1.0, 0.95, 0.86)
	lt.light_energy = 6.0
	lt.omni_range = R * 4.0
	_put(host, lt, g + Vector3.UP * R * 0.6)
	var ltw = lt.create_tween()
	ltw.tween_property(lt, "light_energy", 0.0, 0.45)
	ltw.tween_callback(lt.queue_free)
	var P = foot / 0.36
	var cr = _decal(host, "crater", g + Vector3.UP * 0.09, P, {"prog": 0.0, "fade": 1.0, "seed": randf() * 10.0, "bowl": 0.36})
	var ctw = cr.create_tween()
	ctw.tween_method(_pf(cr, "prog"), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ctw.tween_interval(18.0)
	ctw.tween_method(_pf(cr, "fade"), 1.0, 0.0, 2.0)
	ctw.tween_callback(cr.queue_free)
	for q in 14:   # krater dudağında dışa yatarak kalkan zemin levhaları
		var a = TAU * q / 14.0 + randf_range(-0.12, 0.12)
		var dv = Vector3(cos(a), 0, sin(a))
		var p = Game.jutsu_floor_at(g + dv * foot * randf_range(1.0, 1.15) + Vector3.UP * 3.0)
		var mi = _gi(_chunk_mesh(q % 4), "rock")
		mi.set_instance_shader_parameter("base_col", EARTH_COL.darkened(randf_range(0.0, 0.2)))
		mi.set_instance_shader_parameter("seed", float(q))
		mi.set_instance_shader_parameter("fade", 1.0)
		_put(host, mi, p)
		mi.global_basis = Basis.looking_at(dv, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, randf_range(0.5, 0.95))
		var sz = Vector3(randf_range(0.11, 0.16), randf_range(0.08, 0.13), randf_range(0.04, 0.06)) * foot
		mi.scale = Vector3(sz.x, 0.01, sz.z)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", sz, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(16.0 + randf() * 3.0)
		tw.tween_property(mi, "scale", Vector3(sz.x, 0.01, sz.z), 1.5)
		tw.tween_callback(mi.queue_free)
	for q in 26:   # savrulan taşlar (zemin + göktaşı)
		var a = randf() * TAU
		var dv = Vector3(cos(a), 0, sin(a))
		var v = dv * randf_range(14.0, 30.0) + Vector3.UP * randf_range(10.0, 24.0)
		var col = EARTH_COL if q % 3 != 0 else rock_col
		_toss(host, g + dv * foot * 0.9 + Vector3.UP * 1.5, v, randf_range(0.6, 2.2), col.darkened(randf_range(0.0, 0.25)), q)
	for q in 11:   # kraterden dışa uzanan uzun düz yarıklar (ref: sonrası)
		var a = TAU * q / 11.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		var L = R * randf_range(0.8, 1.7)
		var wdt = foot * randf_range(0.16, 0.3)
		var f0 = g + dv * foot * 0.85
		var fi = _gi(_plane(), "fissure")
		fi.set_instance_shader_parameter("prog", 0.0)
		fi.set_instance_shader_parameter("fade", 1.0)
		fi.set_instance_shader_parameter("seed", randf() * 40.0)
		_put(host, fi, f0 + dv * L * 0.5 + Vector3.UP * 0.1)
		fi.global_basis = Basis.looking_at(-dv, Vector3.UP)
		fi.scale = Vector3(wdt, 1.0, L * 0.5)
		preload("res://scripts/combat/fx/lib/ground_drape.gd").auto(fi)
		var ft = fi.create_tween()
		ft.tween_method(_pf(fi, "prog"), 0.0, 1.0, randf_range(0.35, 0.7)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ft.tween_interval(18.0)
		ft.tween_method(_pf(fi, "fade"), 1.0, 0.0, 2.0)
		ft.tween_callback(fi.queue_free)
	# yere yapışık, dışa fışkıran katmanlı gri toz levhaları
	_sheet(host, g + Vector3.UP * 3.0, R * 0.35, 10.0, R * randf_range(1.35, 1.6), 3.0, Color(0.68, 0.65, 0.6), 0.0)
	_sheet(host, g + Vector3.UP * 7.0, R * 0.3, 8.0, R * randf_range(1.0, 1.2), 3.2, Color(0.6, 0.58, 0.55), 0.05)


## İkinci göktaşı birincinin tepesine çarpar: temas çizgisinden yatay katmanlı toz çiçeği + kara taş zerreleri, ak çatlaklar
static func _collide(pj: PathJutsu, c: Node3D, host: Node, st: Dictionary, goal: Vector3, top1: Vector3) -> void:
	var m2: Dictionary = st["m2"]
	m2["landed"] = true
	_calm(m2)
	var r2 = m2["rock"]
	r2.set_instance_shader_parameter("press", 0.0)
	var t2 = r2.create_tween()
	t2.tween_method(_pf(r2, "crack"), 0.0, 1.0, 0.55)
	var m1 = st["m1"]
	if m1 != null and is_instance_valid(m1["rock"]):
		var r1 = m1["rock"]
		r1.set_instance_shader_parameter("crack_from", Vector3(0, 1, 0))
		var t1 = r1.create_tween()
		t1.tween_method(_pf(r1, "crack"), 0.0, 1.0, 0.55)
	# temas çizgisinden yana fışkıran yassı, katmanlı gri toz levhaları (ref kare 4)
	_sheet(host, top1 + Vector3.UP * 2.0, R1 * 0.3, 18.0, R1 * 1.9, 2.6, Color(0.76, 0.76, 0.74), 0.07)
	_sheet(host, top1 + Vector3.UP * 8.0, R1 * 0.25, 14.0, R1 * 1.45, 2.4, Color(0.64, 0.64, 0.62), 0.1)
	_sheet(host, top1 - Vector3.UP * 4.0, R1 * 0.25, 12.0, R1 * 1.6, 2.8, Color(0.55, 0.55, 0.53), 0.06)
	for q in 34:   # kara taş zerreleri yatay saçılır
		var a = randf() * TAU
		var dv = Vector3(cos(a), randf_range(-0.15, 0.35), sin(a))
		_toss(host, top1 + dv * R1 * 0.25, dv * randf_range(35.0, 60.0), randf_range(0.3, 1.0), ROCK_COL.darkened(0.45), q)
	Sfx.play("boom", top1, 0.45, 1.0)
	_quake(host, top1, R2, 3.0, 0.3)
	pj.after(0.6, func():
		if st["shat"]:
			return
		st["shat"] = true
		if m1 != null:
			_shatter(host, m1, goal)
		_shatter(host, m2, goal)
		_impact(host, goal, R2, FOOT2, ROCK_COL)
		_dust_column(host, goal + Vector3.UP * R1 * 1.6, R1)
		if pj.live(c):
			pj.hit(c, goal + Vector3.UP, FOOT2, pj.inf(c, "tengai_shinsei", 5.0, {"knock": 36.0, "launch": 14.0, "kind": "heavy", "hitstop": 0.2}))
		WorldDamage.impact(goal, 36.0, {"dmg": 300.0, "kind": "heavy"})   # göktaşı ayak izi: ağaç / ev devrilir (oyunun dünya hasarı)
		Sfx.play("boom", goal, 0.25, 1.0)
		_quake(host, goal, R2, 3.4, 0.55))
	# güvenlik: atan bu arada öldüyse (after çalışmaz) yine dağılır
	host.get_tree().create_timer(1.2).timeout.connect(func():
		if not st["shat"]:
			st["shat"] = true
			if m1 != null:
				_shatter(host, m1, goal)
			_shatter(host, m2, goal))


## Kaya dikey dilimlere ayrılıp dışa devrilerek çöker (ref: ak yarıklarla dilimlenen küre); enkaz bir süre kalır
static func _shatter(host: Node, md: Dictionary, goal: Vector3) -> void:
	var root: Node3D = md["root"]
	if not is_instance_valid(root):
		return
	var R: float = md["R"]
	var C = root.global_position
	var rock = md["rock"]
	_calm(md)
	if md.has("body") and is_instance_valid(md["body"]):
		md["body"].queue_free()
	var tw = rock.create_tween()
	tw.tween_method(_pf(rock, "fade"), 1.0, 0.0, 0.12)
	tw.tween_callback(root.queue_free)
	var yaw = randf() * TAU
	var gy = Game.jutsu_floor(C.x, C.z)
	for i in SLICES:
		var mi = _gi(_slice_mesh(i), "rock")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.set_instance_shader_parameter("base_col", ROCK_COL.darkened(randf_range(0.0, 0.12)))
		mi.set_instance_shader_parameter("seed", md["seed"] + i)
		mi.set_instance_shader_parameter("crack", 0.55)
		mi.set_instance_shader_parameter("crack_from", Vector3(0, 1, 0))
		mi.set_instance_shader_parameter("fade", 1.0)
		_put(host, mi, C)
		var b0 = Basis(Vector3.UP, yaw)
		mi.global_basis = b0
		mi.scale = Vector3.ONE * R
		var thm = TAU * (i + 0.5) / SLICES
		var dv = b0 * Vector3(cos(thm), 0, sin(thm))
		var q0 = mi.quaternion
		var tilt = Basis(dv.cross(Vector3.UP).normalized(), -randf_range(1.0, 1.45))
		var q1 = (tilt * b0).get_rotation_quaternion()
		var rest = C + dv * R * randf_range(0.45, 0.8)
		rest.y = gy + R * randf_range(0.02, 0.12)
		var dur = randf_range(1.1, 1.6) + clampf((C.y - gy) / 110.0, 0.0, 1.6)
		var w = weakref(mi)
		var mt = mi.create_tween()
		var C0 = C + dv * R * 0.05   # önce ak yarıklar açılır (dilimler arası boşluk), sonra devrilir
		mt.tween_property(mi, "global_position", C0, 0.3).set_ease(Tween.EASE_OUT)
		mt.tween_interval(0.15 + randf() * 0.2)
		mt.tween_method(func(x: float):
			var o = w.get_ref()
			if o == null:
				return
			o.global_position = C0.lerp(rest, x)
			o.quaternion = q0.slerp(q1, x), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var hold = {"b": null}
		var ii = i
		mt.tween_callback(func():   # devrilen dilim durunca katı olur (kural 18): görselin kendi dışbükey şekli
			var o = w.get_ref()
			if o == null:
				return
			var xf = Transform3D(o.global_basis.orthonormalized(), o.global_position)
			hold["b"] = _solid(host, _slice_shape(ii, R), xf, C))
		mt.tween_interval(14.0 + randf() * 3.0)
		mt.tween_callback(func():
			if hold["b"] != null and is_instance_valid(hold["b"]):
				hold["b"].queue_free())
		mt.tween_property(mi, "global_position", rest + Vector3.DOWN * R * 0.9, 2.0)
		mt.tween_callback(mi.queue_free)


const SLICES := 9


## Dilimin çarpışma şekli: kendi ağının dışbükey zarfı, ölçeğe göre
static func _slice_shape(i: int, R: float) -> ConvexPolygonShape3D:
	var key = "sshape%d" % i
	if not _cache.has(key):
		_cache[key] = _slice_mesh(i).create_convex_shape(true, true)
	var pts = PackedVector3Array()
	for q in (_cache[key] as ConvexPolygonShape3D).points:
		pts.append(q * R)
	var sh = ConvexPolygonShape3D.new()
	sh.points = pts
	return sh


## Katı enkaz gövdesi (dünya katmanı 1); içinde kalan dövüşçüler bir fizik karesi sonra yatayda dışarı itilir (sıkışma yok)
static func _solid(host: Node, shape: Shape3D, xf: Transform3D, center: Vector3) -> StaticBody3D:
	var b = StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs = CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	host.add_child(b)
	b.add_to_group("tengai_fx")
	b.global_transform = xf
	var wb = weakref(b)
	host.get_tree().create_timer(0.06).timeout.connect(func():
		var bb = wb.get_ref()
		if bb == null or not bb.is_inside_tree():
			return
		var space = bb.get_world_3d().direct_space_state
		var q = PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = xf
		q.collision_mask = 2 | 4
		var cap = CapsuleShape3D.new()
		cap.radius = 0.45
		cap.height = 1.8
		var cq = PhysicsShapeQueryParameters3D.new()
		cq.shape = cap
		cq.collision_mask = 1
		for hit in space.intersect_shape(q, 48):
			var f = hit.get("collider")
			if f == null or not (f is Node3D) or not f.is_in_group("fighters"):
				continue
			var dir = (f as Node3D).global_position - center
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
			var p: Vector3 = f.global_position
			for k in 90:
				p += dir * 2.0
				p.y = Game.jutsu_floor(p.x, p.z)
				cq.transform = Transform3D(Basis(), p + Vector3.UP * 1.3)
				var blocked = false
				for h2 in space.intersect_shape(cq, 8):
					if h2.get("collider") == bb:
						blocked = true
						break
				if not blocked:
					f.global_position = p + Vector3.UP * 0.1
					break)
	return b


## Toz levhası ağı: iç kenarı kalın, dışa doğru incelen yassı halka (üst yüz kabarık, alt yüz düz); düz gölgeli değil yumuşak
static func _sheet_mesh(v: int) -> ArrayMesh:
	var key = "sheet%d" % v
	if _cache.has(key):
		return _cache[key]
	var nz = FastNoiseLite.new()
	nz.seed = 600 + v * 17
	nz.frequency = 2.0
	nz.fractal_octaves = 3
	var RA = 56
	var RJ = 9
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos = []
	var T = []
	var B = []
	for j in RJ + 1:
		var r = lerpf(0.2, 1.0, float(j) / RJ)
		var tr = []
		var br = []
		for i in RA:
			var a = TAU * i / RA
			var d = Vector3(cos(a), 0, sin(a))
			var n = nz.get_noise_3dv(d * 1.2 + Vector3(0, r * 2.0, 0))
			var th = 0.32 * pow(1.03 - r, 0.8) * (0.7 + n * 0.6) + 0.015
			tr.append(pos.size())
			pos.append(d * r + Vector3.UP * th)
			br.append(pos.size())
			pos.append(d * r - Vector3.UP * th * 0.35)
		T.append(tr)
		B.append(br)
	for p in pos:
		st.add_vertex(p)
	var tri = func(a: int, b: int, c: int, out: Vector3):
		var pa: Vector3 = pos[a]
		var pb: Vector3 = pos[b]
		var pc: Vector3 = pos[c]
		if (pb - pa).cross(pc - pa).dot(out) > 0.0:
			st.add_index(a); st.add_index(c); st.add_index(b)
		else:
			st.add_index(a); st.add_index(b); st.add_index(c)
	for j in RJ:
		for i in RA:
			var i2 = (i + 1) % RA
			tri.call(T[j][i], T[j + 1][i], T[j][i2], Vector3.UP)
			tri.call(T[j][i2], T[j + 1][i], T[j + 1][i2], Vector3.UP)
			tri.call(B[j][i], B[j + 1][i], B[j][i2], Vector3.DOWN)
			tri.call(B[j][i2], B[j + 1][i], B[j + 1][i2], Vector3.DOWN)
	for i in RA:   # iç ve dış kenar duvarları
		var i2 = (i + 1) % RA
		var din = -(pos[T[0][i]] as Vector3)
		din.y = 0.0
		tri.call(T[0][i], B[0][i], T[0][i2], din)
		tri.call(T[0][i2], B[0][i], B[0][i2], din)
		var dout = (pos[T[RJ][i]] as Vector3)
		dout.y = 0.0
		tri.call(T[RJ][i], B[RJ][i], T[RJ][i2], dout)
		tri.call(T[RJ][i2], B[RJ][i], B[RJ][i2], dout)
	st.generate_normals()
	_cache[key] = st.commit()
	return _cache[key]


## Yassı toz levhası: r0 yarıçaptan r1'e yana fışkırır (hızla, sonra yavaşlar), kalınlaşır, gürültüyle delinip söner
static func _sheet(host: Node, p: Vector3, r0: float, thick: float, r1: float, life: float, col: Color, tilt := 0.0) -> void:
	var mi = _gi(_sheet_mesh(randi() % 3), "sheet")
	mi.set_instance_shader_parameter("col", col)
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	_put(host, mi, p)
	mi.rotation = Vector3(randf_range(-tilt, tilt), randf() * TAU, randf_range(-tilt, tilt))
	var ty = thick / 0.33
	mi.scale = Vector3(r0, ty * 0.6, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, ty * 1.3, r1), life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "erode"), 0.0, 1.0, life * 0.5).set_delay(life * 0.5)
	tw.tween_callback(mi.queue_free)

## Kürenin boylamsal kabuk dilimi (dış yüz kaya, iç yüz kırık çekirdek, yan yüzler pürüzlü kırık); dilimler arası boşluk
static func _slice_mesh(i: int) -> ArrayMesh:
	var key = "slice%d" % i
	if _cache.has(key):
		return _cache[key]
	var nz = FastNoiseLite.new()
	nz.seed = 900 + i * 7
	nz.frequency = 2.2
	var gap = 0.035
	var th0 = TAU * i / SLICES + gap
	var th1 = TAU * (i + 1) / SLICES - gap
	var RI = 14
	var K = 4
	var O = []
	var I = []
	for j in RI + 1:
		var phi = PI * lerpf(0.13, 0.93, float(j) / RI)
		var ro = []
		var ri = []
		var jit0 = nz.get_noise_2d(float(j) * 3.0, float(i) * 11.0) * 0.06
		var jit1 = nz.get_noise_2d(float(j) * 3.0, float(i + 1) * 11.0) * 0.06
		for k in K + 1:
			var th = lerpf(th0 + jit0, th1 + jit1, float(k) / K)
			var d = Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			ro.append(d * (1.0 + nz.get_noise_3dv(d * 2.0) * 0.05))
			ri.append(d * (0.42 + nz.get_noise_3dv(d * 3.0 + Vector3(5, 5, 5)) * 0.12))
		O.append(ro)
		I.append(ri)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.0, 0.0, 0.0, 1.0))
	var side0 = Vector3(sin(th0), 0, -cos(th0))
	var side1 = Vector3(-sin(th1), 0, cos(th1))
	for j in RI:
		for k in K:
			var a = O[j][k]; var b = O[j][k + 1]; var c = O[j + 1][k]; var e = O[j + 1][k + 1]
			var out = (a + b + c + e).normalized()
			_tri_o(st, a, c, b, out)
			_tri_o(st, b, c, e, out)
			a = I[j][k]; b = I[j][k + 1]; c = I[j + 1][k]; e = I[j + 1][k + 1]
			_tri_o(st, a, c, b, -out)
			_tri_o(st, b, c, e, -out)
		_tri_o(st, O[j][0], I[j][0], O[j + 1][0], side0)
		_tri_o(st, I[j][0], I[j + 1][0], O[j + 1][0], side0)
		_tri_o(st, O[j][K], I[j][K], O[j + 1][K], side1)
		_tri_o(st, I[j][K], I[j + 1][K], O[j + 1][K], side1)
	for k in K:   # kırık uç yüzleri (kutuplara varmayan dilimin üst / alt kesiti)
		for jj in [0, RI]:
			var up = Vector3.UP if jj == 0 else Vector3.DOWN
			_tri_o(st, O[jj][k], O[jj][k + 1], I[jj][k], up)
			_tri_o(st, O[jj][k + 1], I[jj][k + 1], I[jj][k], up)
	_cache[key] = st.commit()
	return _cache[key]


## Üçgen: ön yüz (saat yönü) verilen dış yöne bakar
static func _tri_o(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var cr = (b - a).cross(c - a)
	if cr.length() < 1e-7:
		return
	if cr.dot(out) > 0.0:
		var t = b
		b = c
		c = t
		cr = -cr
	var n = -cr.normalized()
	for p in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)


## Kırılan kayaların tepesinden yükselen gri toz sütunu
static func _dust_column(host: Node, at: Vector3, R: float) -> void:
	for q in 14:
		var dv = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var s = R * randf_range(0.2, 0.32)
		var col = Color(0.76, 0.75, 0.72).lerp(Color(0.58, 0.57, 0.55), randf())
		_lobe(host, at + dv * R * randf_range(0.1, 0.6) + Vector3.UP * randf_range(-R * 0.3, R * 0.3), Vector3(s, s * 0.8, s), dv * R * 0.5 + Vector3.UP * R * randf_range(0.5, 1.1), randf_range(2.6, 3.4), col, 2.1, randf() * 0.25)


# ================================================================== parçacıklar (kendi hareketleri)
## Toz topağı: büyüyerek yavaşlayan itki, ömrün ikinci yarısında gürültüyle aşınır
static func _lobe(host: Node, p: Vector3, size: Vector3, vel: Vector3, life: float, col: Color, grow := 1.8, delay := 0.0) -> void:
	var mi = _gi(_lobe_mesh(randi() % 3), "dust")
	mi.set_instance_shader_parameter("col", col)
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("seed", randf() * 30.0)
	_put(host, mi, p)
	mi.rotation = Vector3(0, randf() * TAU, 0)
	mi.scale = size * 0.35
	mi.visible = delay <= 0.0
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): mi.visible = true)
	tw.tween_property(mi, "global_position", p + vel, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "scale", size * grow, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "erode"), 0.0, 1.0, life * 0.55).set_delay(life * 0.45)
	tw.tween_callback(mi.queue_free)


## Balistik taş: yerçekimiyle uçar, zemine konar, bir süre durup küçülerek gider
static func _toss(host: Node, p0: Vector3, v: Vector3, size: float, col: Color, k: int) -> void:
	var mi = _gi(_chunk_mesh(k % 4), "rock")
	mi.set_instance_shader_parameter("base_col", col)
	mi.set_instance_shader_parameter("seed", float(k))
	mi.set_instance_shader_parameter("fade", 1.0)
	_put(host, mi, p0)
	mi.scale = Vector3.ONE * size
	var r0 = Vector3(randf(), randf(), randf()) * TAU
	var spin = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	mi.rotation = r0
	var g = 26.0
	var floor_y = p0.y
	var s = {"land": false}
	var w = weakref(mi)
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		var o = w.get_ref()
		if o == null or s["land"]:
			return
		var p = p0 + v * t + Vector3.DOWN * (0.5 * g * t * t)
		if p.y < floor_y + 30.0 and v.y - g * t < 0.0:
			var gy = Game.ground_height(p.x, p.z)
			if p.y < gy + size * 0.4:
				p.y = gy + size * 0.4
				s["land"] = true
		o.global_position = p
		o.rotation = r0 + spin * t, 0.0, 4.0, 4.0)
	tw.tween_interval(randf_range(6.0, 10.0))
	tw.tween_property(mi, "scale", Vector3.ONE * size * 0.02, 1.0)
	tw.tween_callback(mi.queue_free)
