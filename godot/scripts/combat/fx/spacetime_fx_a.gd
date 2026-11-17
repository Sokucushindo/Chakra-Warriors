class_name SpacetimeFXA
extends RefCounted
## Uzay-zaman + tıbbi + yılan grubu A: on yedi tekniğin görselleri. Tüm görünüş bu dosyada sıfırdan üretilir:
## Hiraishin sarı yarık flaşı + ışın çatlağı (duman yok), dondurulmuş beden pozundan ardıl görüntü, yerde yazılan Hiraishin
## formülü, hedefteki shiki işareti, Minato'nun üç uçlu formül kunaisi (sapı parlar), mor bulut küre + kara yazı zinciri,
## kendi Rasengan küresi, altıgen-yıldız ışın ağı, kabak kurbağa (Hyōtan Gama) cel modeli, su halkaları, beyaz yılan bakışı,
## zehir sisi (cel bulut), mavi chakra neşteri alevi, Byakugō elması + yenilenme buharı, bölünen hücreler, su kabarcığı +
## zehir iplikleri, mezar çatlağı + beyaz ölü gözleri. Kameraya yakın kısımlar dağılarak incelir (ekranı kaplamaz).
## Gerçek oyun sistemleri: Hiraishin işaret meta'sı (hiraishin_by), SleeveSnake / make_snake / snake_head yılanları,
## SummonModels kurbağası, ShadowClone ceset, ten shader mühür çizgileri (seal_marks / sage_marks), Buffs, mermi (shot).
## Oynanış (hasar, durum, süre, menzil, hedefleme, bedel) ana ağaçtaki işleyicilerden satır satır taşındı.

const UP := Vector3.UP
const GOLD := Color(1.0, 0.84, 0.28)
const GOLD_W := Color(1.0, 0.98, 0.8)
const INK := Color(0.05, 0.04, 0.06)
const MEDC := Color(0.42, 0.95, 0.6)
const MEDW := Color(0.88, 1.0, 0.9)
const SCALPEL_W := Color(0.86, 0.96, 1.0)
const SCALPEL := Color(0.38, 0.68, 1.0)
const VENOM := Color(0.52, 0.24, 0.64)
const VENOM_D := Color(0.24, 0.08, 0.3)
const SNAKE_W := Color(0.92, 0.92, 0.95)

static var _cache := {}


# ================================================================== gölgelendiriciler
const COMMON := """
float fh1(float n) { return fract(sin(n * 127.1 + 0.3) * 43758.5453); }
float fh2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fh2(i), fh2(i + vec2(1.0, 0.0)), f.x), mix(fh2(i + vec2(0.0, 1.0)), fh2(i + vec2(1.0, 1.0)), f.x), f.y);
}
bool cam_cut(vec3 vpos, vec2 fc, float nfd) {
	return smoothstep(nfd * 0.35, nfd, length(vpos)) < fh2(floor(fc));
}
"""

const BB_VERTEX := """
void vertex() {
	if (bb > 0.5) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		if (bb < 1.5) {
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * sc.x, 0.0), vec4(INV_VIEW_MATRIX[1].xyz * sc.y, 0.0), vec4(INV_VIEW_MATRIX[2].xyz * sc.z, 0.0), MODEL_MATRIX[3]);
		} else {
			vec3 org = MODEL_MATRIX[3].xyz;
			vec3 fw = INV_VIEW_MATRIX[3].xyz - org;
			fw.y = 0.0;
			fw = normalize(fw + vec3(0.0001, 0.0, 0.0));
			vec3 rt = normalize(cross(vec3(0.0, 1.0, 0.0), fw));
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rt * sc.x, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(fw * sc.z, 0.0), MODEL_MATRIX[3]);
		}
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}
"""

## Düz şekiller (dörtgen): kind 0 Hiraishin yarık flaşı, 1 ışın çatlağı, 2 Hiraishin formülü (zemin), 3 shiki işareti,
## 4 su halkası, 5 zemin çatlağı, 6 leke, 7 mürekkep çağırma çemberi, 8 sürüklenme izi, 9 yılan gözü, 10 Byakugō elması,
## 11 bölünen hücre, 12 ölü göz akı. bb: 0 sabit, 1 kameraya dönük, 2 dik eksenli dönük
const FLAT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform vec4 c1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c2 : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform float alpha = 1.0;
instance uniform float prog = 1.0;
instance uniform float seed = 0.0;
instance uniform float nf = 1.5;
instance uniform float bb = 0.0;

COMMON
BB_VERTEX

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float an = atan(p.y, p.x);
	float a01 = an / 6.2831853 + 0.5;
	vec3 col = c1.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		float hw = mix(0.05, 0.42, prog) * max(0.0, 1.0 - p.y * p.y);
		float ax = abs(p.x);
		if (ax < hw * 0.4) { col = c1.rgb; a = 1.0; }
		else if (ax < hw) { col = c2.rgb; a = 0.85; }
		if (a < 0.5 && abs(p.y) < 0.025 && ax < 0.15 + 0.85 * prog) { col = c2.rgb; a = 0.8; }
	} else if (kind < 1.5) {
		float n = 12.0;
		float sec = floor(a01 * n);
		float fa = fract(a01 * n) - 0.5;
		float len_ = 0.5 + 0.5 * fh1(sec + seed * 13.0);
		float w = 0.22 * max(0.0, 1.0 - r / len_);
		float hd = len_ * min(1.0, prog * 1.8);
		float tl = len_ * max(0.0, prog * 1.4 - 0.4);
		if (r < hd && r > tl && abs(fa) < w) { col = abs(fa) < w * 0.4 ? c1.rgb : c2.rgb; a = 1.0; }
		if (r < 0.22 * (1.0 - prog)) { col = c1.rgb; a = 1.0; }
	} else if (kind < 2.5) {
		float ln = 0.0;
		if (abs(r - 0.88) < 0.02 || abs(r - 0.56) < 0.016 || abs(r - 0.1) < 0.02) { ln = 1.0; }
		if (r > 0.62 && r < 0.82) {
			float cell = floor(a01 * 40.0);
			float cf = fract(a01 * 40.0);
			float rr = (r - 0.62) / 0.2;
			float g = fh1(cell + seed * 3.0);
			if (abs(cf - 0.5) < 0.09 && abs(rr - 0.5) < 0.2 + 0.25 * g) { ln = 1.0; }
			if (abs(rr - 0.3 - 0.4 * g) < 0.08 && abs(cf - 0.5) < 0.32) { ln = 1.0; }
		}
		for (int i = 0; i < 3; i++) {
			float sa = float(i) * 2.0944 + seed;
			vec2 dv = vec2(cos(sa), sin(sa));
			float al = dot(p, dv);
			float pe = abs(p.x * dv.y - p.y * dv.x);
			if (al > 0.12 && al < 0.56 && pe < 0.02) { ln = 1.0; }
		}
		if (a01 > prog) { ln = 0.0; }
		if (ln > 0.5) { col = mix(c2.rgb, c1.rgb, step(0.5, fract(TIME * 3.0 + r * 2.0))); a = 1.0; }
		else if (r < 0.9 && a01 <= prog) { col = c2.rgb; a = 0.1 * (1.0 - r); }
	} else if (kind < 3.5) {
		float ln = 0.0;
		if (abs(r - 0.26) < 0.05) { ln = 1.0; }
		for (int i = 0; i < 3; i++) {
			float sa = float(i) * 2.0944 + 0.4 + r * 1.4;
			vec2 dv = vec2(cos(sa), sin(sa));
			float al = dot(p, dv);
			float pe = abs(p.x * dv.y - p.y * dv.x);
			if (al > 0.3 && al < 0.9 && pe < 0.06 * (1.0 - al * 0.7)) { ln = 1.0; }
		}
		if (ln > 0.5) { col = c1.rgb; a = 1.0; }
		else if (r < 1.0) { col = c2.rgb; a = 0.45 * (1.0 - r) * prog; }
	} else if (kind < 4.5) {
		float wob = 0.025 * sin(an * 7.0 + seed * 5.0);
		float dash = step(0.22, fract(a01 * 5.0 + seed));
		if ((abs(r + wob - 0.9) < 0.02 || abs(r - wob - 0.64) < 0.016) && dash > 0.5) { col = c1.rgb; a = 1.0; }
	} else if (kind < 5.5) {
		float n = 9.0;
		float sec = floor(a01 * n);
		float fa = fract(a01 * n) - 0.5;
		float jag = 0.18 * (vn(vec2(r * 9.0, sec * 3.1 + seed)) - 0.5);
		float len_ = 0.55 + 0.45 * fh1(sec + seed);
		float pe = abs(fa - jag) * max(r, 0.05) * 6.2831853 / n;
		if (r < len_ * prog && pe < 0.03 * (1.0 - r / len_) + 0.004) { col = c1.rgb; a = 1.0; }
		if (r < 0.12 * prog + vn(p * 6.0 + seed) * 0.05) { col = c1.rgb; a = 1.0; }
	} else if (kind < 6.5) {
		float edge = (0.62 + 0.3 * vn(p * 2.5 + seed * 7.0)) * prog;
		if (r < edge) { col = r > edge - 0.08 ? c2.rgb : c1.rgb; a = 0.85; }
		float dots = vn(p * 9.0 + seed);
		if (r > edge && r < edge + 0.25 && dots > 0.78) { col = c1.rgb; a = 0.85; }
	} else if (kind < 7.5) {
		float ln = 0.0;
		if (abs(r - 0.92) < 0.025 || abs(r - 0.8) < 0.012 || abs(r - 0.36) < 0.02) { ln = 1.0; }
		if (r > 0.42 && r < 0.76) {
			float cell = floor(a01 * 24.0);
			float cf = fract(a01 * 24.0);
			float g = fh1(cell + seed);
			float rr = (r - 0.42) / 0.34;
			float rw = fract(rr * 4.0);
			if (abs(cf - 0.5) < 0.08 && rw > 0.15 && rw < 0.85 && fh1(cell * 5.0 + floor(rr * 4.0)) > 0.25) { ln = 1.0; }
			if (abs(rw - 0.5) < 0.1 && abs(cf - 0.5) < 0.28 * g + 0.05) { ln = 1.0; }
		}
		if ((abs(p.x) < 0.025 && r < 0.36) || (abs(p.y) < 0.025 && r < 0.36)) { ln = 1.0; }
		if (a01 > prog) { ln = 0.0; }
		if (ln > 0.5) { col = c1.rgb; a = 1.0; }
	} else if (kind < 8.5) {
		float ln = 0.0;
		for (int i = 0; i < 3; i++) {
			float x0 = (float(i) - 1.0) * 0.38 + 0.06 * (vn(vec2(p.y * 3.0, float(i) * 7.0 + seed)) - 0.5);
			float w = 0.045 * (1.0 - abs(p.y) * 0.8);
			if (abs(p.x - x0) < w) { ln = 1.0; }
		}
		if ((1.0 - p.y) * 0.5 > prog) { ln = 0.0; }
		if (ln > 0.5) { col = c1.rgb; a = 0.9; }
	} else if (kind < 9.5) {
		float oy = 0.42 * max(prog, 0.02);
		float el = (p.x * p.x) / 0.81 + (p.y * p.y) / (oy * oy);
		if (el < 1.0) {
			col = c1.rgb;
			a = 1.0;
			if (abs(p.x) < 0.12 * (1.0 - abs(p.y) / oy)) { col = vec3(0.04, 0.03, 0.02); }
			if (el > 0.72) { col = c2.rgb; }
		}
	} else if (kind < 10.5) {
		float dm = abs(p.x) * 1.35 + abs(p.y);
		if (dm < 0.6) { col = dm < 0.45 ? c1.rgb : c2.rgb; a = 1.0; }
		else if (dm < 1.0) { col = c1.rgb; a = (1.0 - dm) * prog; }
	} else if (kind < 11.5) {
		float sx = 0.36 * prog;
		float d1 = length(p - vec2(sx, 0.0));
		float d2 = length(p + vec2(sx, 0.0));
		float rr = 0.48 - 0.08 * prog;
		float dm = min(d1, d2);
		if (dm < rr) {
			col = c1.rgb;
			a = 0.45;
			if (dm > rr - 0.07) { col = c2.rgb; a = 0.95; }
			if (dm < 0.1) { col = c2.rgb; a = 0.9; }
		}
	} else {
		float el = (p.x * p.x) / 0.81 + (p.y * p.y) / 0.25;
		if (el < 1.0) { col = el > 0.7 ? c2.rgb : c1.rgb; a = 1.0; }
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Cel bulut parçası (toz, zehir sisi, toprak): tırtıklı kenar, iki ton + ince koyu kontur, dis ile delik delik dağılır
const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 lit : source_color = vec4(0.8, 0.75, 0.65, 1.0);
instance uniform vec4 shade : source_color = vec4(0.55, 0.5, 0.42, 1.0);
instance uniform vec4 line : source_color = vec4(0.2, 0.17, 0.14, 1.0);
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float dis = 0.0;
instance uniform float nf = 2.5;
instance uniform float bb = 1.0;

COMMON
BB_VERTEX

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float an = atan(p.y, p.x);
	float edge = 0.74 + 0.08 * sin(an * 5.0 + seed * 6.0) + 0.1 * vn(vec2(an * 2.0 + seed, TIME * 0.4));
	if (r > edge) { discard; }
	float hole = vn(p * 3.0 + vec2(seed * 4.0, TIME * 0.3));
	if (hole < dis) { discard; }
	vec2 ld = normalize(vec2(-0.5, 0.75));
	float sh = dot(p / edge, ld);
	vec3 col = (sh > -0.15 - 0.15 * hole) ? lit.rgb : shade.rgb;
	if (r > edge - 0.07 || hole < dis + 0.05) { col = line.rgb; }
	ALBEDO = col;
	ALPHA = alpha;
}
"""

## Ardıl görüntü (dondurulmuş beden pozu): içi saydam, kenar bandı dolu, yatay hız çizgileri
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.4, 1.0);
instance uniform float alpha = 0.6;
instance uniform float nf = 1.5;

COMMON

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	float fr = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 col = tint.rgb;
	float a = alpha * (fr > 0.55 ? 1.0 : 0.38);
	if (fr > 0.82) { col = tint.rgb * 0.45; }
	if (fract(FRAGCOORD.y * 0.2) < 0.3) { a *= 0.5; }
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Küreler: kind 0 Rasengan (bakışa göre dönen sarmal + koyu kontur), 1 su kabarcığı, 2 mor bulut küre (benekli), 3 şifa ışığı
const ORB_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

instance uniform float kind = 0.0;
instance uniform vec4 c1 : source_color = vec4(0.85, 0.95, 1.0, 1.0);
instance uniform vec4 c2 : source_color = vec4(0.3, 0.6, 1.0, 1.0);
instance uniform vec4 c3 : source_color = vec4(0.05, 0.1, 0.3, 1.0);
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float nf = 2.0;

COMMON

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	vec3 nv = normalize(NORMAL);
	float fr = 1.0 - abs(dot(nv, normalize(VIEW)));
	vec3 col = c1.rgb;
	float a = 1.0;
	if (kind < 0.5) {
		float ang = atan(nv.y, nv.x);
		float rr = length(nv.xy);
		float sp = fract(ang / 6.2831853 * 3.0 + rr * 2.2 - TIME * 3.5 + seed);
		col = sp < 0.35 ? c1.rgb : c2.rgb;
		if (rr < 0.45) { col = c1.rgb; }
		a = fr > 0.8 ? 0.6 : 0.93;
		if (fr > 0.93) { col = c3.rgb; a = 1.0; }
	} else if (kind < 1.5) {
		col = c1.rgb;
		a = fr > 0.7 ? 0.8 : 0.32;
		if (fr > 0.7) { col = c2.rgb; }
		vec3 hv = normalize(vec3(-0.4, 0.6, 0.7));
		if (dot(nv, hv) > 0.93) { col = vec3(1.0); a = 0.95; }
		if (fr > 0.95) { col = c3.rgb; a = 0.9; }
	} else if (kind < 2.5) {
		vec3 n = normalize(lp);
		float m = vn(n.xy * 3.0 + vec2(TIME * 0.3, seed)) * 0.6 + vn(n.yz * 5.0 - vec2(TIME * 0.2, 0.0)) * 0.4;
		col = m > 0.6 ? c1.rgb : (m > 0.42 ? c2.rgb : c3.rgb);
		a = 0.93;
		if (fr > 0.9) { col = c3.rgb * 0.5; a = 1.0; }
	} else {
		col = mix(c2.rgb, c1.rgb, step(0.45, 1.0 - fr));
		a = (1.0 - fr) * 0.85;
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Şerit: UV.x boy, UV.y en. pat 0 kesik hilali, 1 iz (eskiye doğru incelir), 2 kara yazı zinciri, 3 zehir ipliği,
## 4 buhar kıvrımı, 5 neşter alevi, 6 düz çizgi (dolu, kenarı koyu)
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float pat = 0.0;
instance uniform vec4 c1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 c2 : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform float alpha = 1.0;
instance uniform float reveal = 1.0;
instance uniform float tail = 0.0;
instance uniform float seed = 0.0;
instance uniform float nf = 1.5;

COMMON

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	float u = UV.x;
	float v = UV.y;
	float ac = abs(v - 0.5) * 2.0;
	if (u > reveal || u < tail) { discard; }
	vec3 col = c1.rgb;
	float a = 1.0;
	if (pat < 0.5) {
		float th = sin(clamp((u - tail) / max(reveal - tail, 0.001), 0.0, 1.0) * 3.14159);
		if (ac > th) { discard; }
		col = ac < th * 0.45 ? c1.rgb : c2.rgb;
		if (ac > th * 0.85) { col = c2.rgb * 0.45; }
	} else if (pat < 1.5) {
		float k = clamp((u - tail) / max(reveal - tail, 0.001), 0.0, 1.0);
		if (ac > k) { discard; }
		col = ac < k * 0.4 ? c1.rgb : c2.rgb;
		a = 0.35 + 0.65 * k;
	} else if (pat < 2.5) {
		if (ac > 0.85) { discard; }
		col = c2.rgb;
		float cell = floor(u * 40.0);
		float cf = fract(u * 40.0);
		float g = fh1(cell + seed);
		if (ac < 0.6 && ((abs(cf - 0.5) < 0.12 && ac < 0.2 + 0.3 * g) || (abs(ac - 0.3 * g) < 0.12 && abs(cf - 0.5) < 0.35))) { col = c1.rgb; }
	} else if (pat < 3.5) {
		float w = 0.55 + 0.35 * sin(u * 30.0 - TIME * 8.0 + seed);
		if (ac > w) { discard; }
		col = ac < w * 0.4 ? c1.rgb : c2.rgb;
		a = 0.9;
	} else if (pat < 4.5) {
		float wv = sin(u * 9.0 - TIME * 2.0 + seed) * 0.25;
		float d = abs((v - 0.5) * 2.0 - wv);
		float w = 0.55 * sin(u * 3.14159);
		if (d > w) { discard; }
		col = c1.rgb;
		a = (d < w * 0.5 ? 0.42 : 0.2) * (1.0 - u * 0.5);
	} else if (pat < 5.5) {
		float fl = vn(vec2(u * 6.0 - TIME * 9.0, v * 3.0 + seed));
		float w = (1.0 - u * 0.8) * (0.55 + 0.5 * fl);
		if (ac > w) { discard; }
		col = ac < w * 0.35 ? c1.rgb : c2.rgb;
		a = ac < w * 0.35 ? 0.95 : 0.6;
	} else {
		col = ac < 0.55 ? c1.rgb : c2.rgb;
	}
	a *= alpha;
	if (a < 0.01) { discard; }
	ALBEDO = col;
	ALPHA = a;
}
"""

## Katı cel şekil (köşe rengi × tint, iki ton). pat 1 = formül kunaisi: sap kâğıdı ve yazısı glow_k ile parlar
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 glow : source_color = vec4(1.0, 0.9, 0.35, 1.0);
instance uniform float glow_k = 0.0;
instance uniform float pat = 0.0;
instance uniform float alpha = 1.0;
instance uniform float seed = 0.0;
instance uniform float nf = 1.5;

COMMON

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	if (fh2(floor(FRAGCOORD.xy) + vec2(seed)) > alpha) { discard; }
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float sh = dot(wn, normalize(vec3(0.4, 0.85, 0.35))) > -0.1 ? 1.0 : 0.7;
	vec3 col = COLOR.rgb * tint.rgb * sh;
	if (pat > 0.5 && glow_k > 0.0) {
		bool paper = COLOR.r > 0.8 && COLOR.g > 0.75 && COLOR.b > 0.55;
		bool inkm = COLOR.r < 0.12 && COLOR.r > COLOR.g + 0.02;
		if (paper) { col = mix(col, glow.rgb, glow_k * 0.6); }
		if (inkm) { col = mix(col, vec3(1.0, 0.98, 0.85), glow_k); }
	}
	ALBEDO = col;
}
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform float ow = 0.03;
instance uniform float alpha = 1.0;
instance uniform float nf = 1.5;
instance uniform float seed = 0.0;
instance uniform float glow_k = 0.0;
instance uniform vec4 glow : source_color = vec4(1.0, 0.9, 0.35, 1.0);
instance uniform vec4 oc : source_color = vec4(0.04, 0.03, 0.05, 1.0);

COMMON

void vertex() {
	VERTEX += NORMAL * ow;
}

void fragment() {
	if (cam_cut(VERTEX, FRAGCOORD.xy, nf)) { discard; }
	if (fh2(floor(FRAGCOORD.xy) + vec2(seed)) > alpha) { discard; }
	ALBEDO = mix(oc.rgb, glow.rgb, glow_k * 0.7);
}
"""


# ================================================================== malzeme / düğüm yardımcıları
static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if _cache.has(k):
		return _cache[k]
	var sh = Shader.new()
	sh.code = code.replace("BB_VERTEX", BB_VERTEX).replace("COMMON", COMMON)
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[k] = m
	return m


static func _flat_mat() -> ShaderMaterial:
	return _mat("flat", FLAT_SHADER)


static func _puff_mat() -> ShaderMaterial:
	return _mat("puff", PUFF_SHADER)


static func _ghost_mat() -> ShaderMaterial:
	return _mat("ghost", GHOST_SHADER)


static func _orb_mat() -> ShaderMaterial:
	return _mat("orb", ORB_SHADER)


static func _ribbon_mat() -> ShaderMaterial:
	return _mat("ribbon", RIBBON_SHADER)


static func _cel_mat() -> ShaderMaterial:
	return _mat("cel", CEL_SHADER)


static func _outline_mat() -> ShaderMaterial:
	return _mat("outline", OUTLINE_SHADER)


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _params(mi: GeometryInstance3D, prm: Dictionary) -> void:
	for k in prm:
		mi.set_instance_shader_parameter(k, prm[k])


## Düğüm ve altındaki tüm görsellere aynı örnek parametresi
static func _all(n: Node, key: String, val) -> void:
	if not is_instance_valid(n):
		return
	if n is GeometryInstance3D:
		n.set_instance_shader_parameter(key, val)
	for ch in n.get_children():
		_all(ch, key, val)


static func _tp(n: Node, key: String, a: float, b: float, dur: float, delay := 0.0) -> Tween:
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(n):
			_all(n, key, v), a, b, maxf(dur, 0.01))
	return tw


static func _fade_free(n: Node, delay: float, dur: float) -> void:
	var tw = _tp(n, "alpha", 1.0, 0.0, dur, delay)
	tw.tween_callback(n.queue_free)


static func _add(pj: PathJutsu, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _quad() -> QuadMesh:
	if not _cache.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache["mesh:quad"] = q
	return _cache["mesh:quad"]


static func _sphere() -> SphereMesh:
	if not _cache.has("mesh:sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 24
		s.rings = 12
		_cache["mesh:sphere"] = s
	return _cache["mesh:sphere"]


static func _h(t: Node3D) -> float:
	return float(t.get("height")) if t.get("height") != null else 1.8


static func _rad(t: Node3D) -> float:
	return float(t.get("radius")) if t.get("radius") != null else 0.4


static func _bone(c: Node3D, bone: String, fb: Vector3) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel") != null and m.skel:
		var bi = m.skel.find_bone(bone)
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	return c.global_position + fb


static func _fdir(c: Node3D) -> Vector3:
	if c.has_method("face_dir"):
		return c.face_dir()
	return -c.global_transform.basis.z


static func _flatv(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD


## Düz şekil dörtgeni (sahneye eklenmemiş)
static func _flat(kind: float, size: Vector2, prm: Dictionary, bb := 0.0) -> MeshInstance3D:
	var mi = _mi(_quad(), _flat_mat())
	var p = {"kind": kind, "bb": bb, "seed": randf() * 10.0}
	p.merge(prm, true)
	_params(mi, p)
	mi.scale = Vector3(size.x, size.y, 1.0)
	return mi


## Düz şekil: grow sn'de çizilir (prog 0→1), hold bekler, fade'de söner ve silinir
static func _pop(pj: PathJutsu, kind: float, pos: Vector3, size: Vector2, grow: float, hold: float, fade: float, prm := {}, bb := 1.0) -> MeshInstance3D:
	var mi = _flat(kind, size, prm, bb)
	_add(pj, mi, pos)
	mi.set_instance_shader_parameter("prog", 0.0)
	var a0 = float(prm.get("alpha", 1.0))
	var tw = _tp(mi, "prog", 0.0, 1.0, grow)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("alpha", v), a0, 0.0, maxf(fade, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Yere yatırılmış düz şekil (çember, çatlak, leke, halka)
static func _decal(pj: PathJutsu, kind: float, at: Vector3, r: float, grow: float, hold: float, fade: float, prm := {}) -> MeshInstance3D:
	var mi = _pop(pj, kind, at + UP * 0.05, Vector2(r * 2.0, r * 2.0), grow, hold, fade, prm, 0.0)
	mi.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	return mi


static func _light(pj: PathJutsu, pos: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_add(pj, l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Cel bulut parçası: pos'tan vel yönüne kayar, büyür, delik delik dağılır
static func _puff(pj: PathJutsu, pos: Vector3, size: float, vel: Vector3, life: float, cols: Array, a := 1.0, grow := 1.6, nf := 2.5) -> MeshInstance3D:
	var mi = _mi(_quad(), _puff_mat())
	_params(mi, {"lit": cols[0], "shade": cols[1], "line": cols[2], "alpha": a, "seed": randf() * 10.0, "nf": nf, "dis": 0.0, "bb": 1.0})
	mi.scale = Vector3.ONE * size
	_add(pj, mi, pos)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position", pos + vel * life, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi, "scale", Vector3.ONE * size * grow, life).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("dis", v), 0.0, 1.0, life * 0.55).set_delay(life * 0.45)
	tw.chain().tween_callback(mi.queue_free)
	return mi


static func _shrink_curve() -> Curve:
	if not _cache.has("curve:shrink"):
		var cv = Curve.new()
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(1.0, 0.0))
		_cache["curve:shrink"] = cv
	return _cache["curve:shrink"]


static func _drop_mesh() -> SphereMesh:
	if not _cache.has("mesh:drop"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 6
		sm.rings = 3
		_cache["mesh:drop"] = sm
	return _cache["mesh:drop"]


## Kendi ayarlı parçacık püskürtmesi (kıvılcım, damla, toprak topağı). parent verilirse onu izler.
static func _spray(pj: PathJutsu, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var one: bool = o.get("one_shot", true)
	p.one_shot = one
	p.amount = int(o.get("n", 16))
	p.lifetime = float(o.get("life", 0.8))
	p.explosiveness = float(o.get("expl", 0.9 if one else 0.0))
	var mesh: Mesh = o.get("mesh", null)
	p.mesh = mesh if mesh else _drop_mesh()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = o.get("col", Color.WHITE)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.15))
	p.direction = o.get("dir", UP)
	p.spread = float(o.get("spread", 60.0))
	p.initial_velocity_min = float(o.get("v0", 2.0))
	p.initial_velocity_max = float(o.get("v1", 5.0))
	p.gravity = Vector3(0, -float(o.get("grav", 9.8)), 0)
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.angular_velocity_min = -float(o.get("spin", 0.0))
	p.angular_velocity_max = float(o.get("spin", 0.0))
	p.scale_amount_min = float(o.get("s0", 0.05))
	p.scale_amount_max = float(o.get("s1", 0.1))
	p.scale_amount_curve = _shrink_curve()
	if o.get("align", false):
		p.particle_flag_align_y = true
	var parent: Node3D = o.get("parent", null)
	if parent:
		p.local_coords = false
		parent.add_child(p)
		p.position = o.get("off", Vector3.ZERO)
	else:
		_add(pj, p, pos)
	p.emitting = true
	if one:
		pj.free_after(p.lifetime + 0.5, p)
	return p


# ================================================================== geometri
static func _arrays(v: PackedVector3Array, nr: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, cols := PackedColorArray()) -> Array:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	if cols.size() == v.size():
		arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Tüp: pts boyunca yarıçaplar; UV.x boy, UV.y çevre. col_fn(u, along_dir_y_down) verilirse köşe rengi
static func _tube(pts: Array, radii: Array, sides := 8, col_fn := Callable()) -> Array:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	var n = pts.size()
	var prev := Vector3.ZERO
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tn.length() < 1e-5:
			tn = Vector3.FORWARD
		tn = tn.normalized()
		var s1: Vector3 = tn.cross(UP if absf(tn.y) < 0.9 else Vector3.RIGHT).normalized()
		if prev != Vector3.ZERO:
			var pt = prev - tn * prev.dot(tn)
			if pt.length() > 1e-3:
				s1 = pt.normalized()
		prev = s1
		var s2 = tn.cross(s1).normalized()
		for j in sides + 1:
			var a = TAU * j / sides
			var dn = s1 * cos(a) + s2 * sin(a)
			v.append(p + dn * float(radii[i]))
			nr.append(dn)
			var u = float(i) / maxf(n - 1, 1)
			uv.append(Vector2(u, float(j) / sides))
			if col_fn.is_valid():
				cl.append(col_fn.call(u, dn))
	for i in n - 1:
		for j in sides:
			var a0 = i * (sides + 1) + j
			var b0 = a0 + sides + 1
			idx.append_array(PackedInt32Array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1]))
	return _arrays(v, nr, uv, idx, cl)


## Şerit: nrms verilirse tek yüzey o normale dik; yoksa her açıdan görünen çapraz çift şerit
static func _ribbon(pts: Array, ws: Array, nrms: Array = []) -> Array:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var n = pts.size()
	var strips = 1 if not nrms.is_empty() else 2
	for s in strips:
		var base = v.size()
		for i in n:
			var p: Vector3 = pts[i]
			var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			if tn.length() < 1e-5:
				tn = Vector3.FORWARD
			tn = tn.normalized()
			var nm: Vector3
			if not nrms.is_empty():
				nm = nrms[i]
			else:
				nm = tn.cross(UP if absf(tn.y) < 0.9 else Vector3.RIGHT).normalized()
				if s == 1:
					nm = tn.cross(nm).normalized()
			var side = tn.cross(nm).normalized() * float(ws[i]) * 0.5
			v.append(p - side)
			v.append(p + side)
			nr.append(nm)
			nr.append(nm)
			var u = float(i) / maxf(n - 1, 1)
			uv.append(Vector2(u, 0.0))
			uv.append(Vector2(u, 1.0))
		for i in n - 1:
			var a0 = base + i * 2
			idx.append_array(PackedInt32Array([a0, a0 + 2, a0 + 1, a0 + 1, a0 + 2, a0 + 3]))
	return _arrays(v, nr, uv, idx)


static func _mesh(surfaces: Array) -> ArrayMesh:
	var am = ArrayMesh.new()
	for arr in surfaces:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## Sabit şerit düğümü (dünya koordinatında)
static func _ribbon_node(pj: PathJutsu, pts: Array, ws: Array, prm: Dictionary, nrms: Array = []) -> MeshInstance3D:
	var mi = _mi(_mesh([_ribbon(pts, ws, nrms)]), _ribbon_mat())
	_params(mi, prm)
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


## İki hareketli uç arasında her kare yeniden kurulan şerit (iplik, ip). bend(u, t, a, b) -> sapma
static func _strand(pj: PathJutsu, prm: Dictionary, a_fn: Callable, b_fn: Callable, dur: float, w: float, n := 12, bend := Callable()) -> MeshInstance3D:
	var am = ArrayMesh.new()
	var mi = _mi(am, _ribbon_mat())
	_params(mi, prm)
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		if a == Vector3.ZERO or b == Vector3.ZERO or a.distance_to(b) < 0.02:
			mi.visible = false
			return
		mi.visible = true
		var pts: Array = []
		var ws: Array = []
		for i in n:
			var u = float(i) / float(n - 1)
			var p = a.lerp(b, u)
			if bend.is_valid():
				p += bend.call(u, t, a, b)
			pts.append(p)
			ws.append(w)
		am.clear_surfaces()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _ribbon(pts, ws)), 0.0, dur, maxf(dur, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Hareketli düğümün arkasında incelerek kalan iz
static func _trail(pj: PathJutsu, node: Node3D, c1: Color, c2: Color, w: float, dur: float, keep := 10) -> void:
	var am = ArrayMesh.new()
	var mi = _mi(am, _ribbon_mat())
	_params(mi, {"pat": 1.0, "c1": c1, "c2": c2, "nf": 2.0})
	pj.get_tree().current_scene.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var hist: Array = []
	var tw = mi.create_tween()
	tw.tween_method(func(_v: float):
		if not is_instance_valid(mi):
			return
		if is_instance_valid(node) and node.is_inside_tree():
			hist.append(node.global_position)
		elif hist.size() > 0:
			hist.remove_at(0)
		while hist.size() > keep:
			hist.remove_at(0)
		am.clear_surfaces()
		if hist.size() >= 2 and (hist[0] as Vector3).distance_to(hist[hist.size() - 1]) > 0.05:
			var ws: Array = []
			for i in hist.size():
				ws.append(w)
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _ribbon(hist, ws)), 0.0, 1.0, maxf(dur, 0.01))
	tw.tween_callback(mi.queue_free)


## Cel katı şekil + koyu kontur kabuğu
static func _cel(mesh: Mesh, ow: float, prm := {}) -> Node3D:
	var root = Node3D.new()
	var m = _mi(mesh, _cel_mat())
	_params(m, prm)
	root.add_child(m)
	if ow > 0.0:
		var ol = _mi(mesh, _outline_mat())
		var q = {"ow": ow}
		for k in ["alpha", "nf", "seed", "glow", "glow_k"]:
			if prm.has(k):
				q[k] = prm[k]
		_params(ol, q)
		root.add_child(ol)
	return root


## Ardıl görüntü: o anki beden pozu dondurulur, offs'taki her konuma bir kopya. real = gerçek renkli saydam kopya,
## yoksa tint renkli kenar bantlı hayalet. grow > 1: kopya biraz şişirilir (dış ışık kabuğu)
static func _ghost(pj: PathJutsu, c: Node3D, tint: Color, a: float, life: float, offs: Array, real := false, grow := 1.0) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return
	var parts := []
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var src = node as MeshInstance3D
		if src == null or src.mesh == null or not src.is_visible_in_tree():
			continue
		var mesh: Mesh = src.mesh
		if src.skin != null or src.get_node_or_null(src.skeleton) is Skeleton3D:
			var baked = src.bake_mesh_from_current_skeleton_pose()
			if baked:
				mesh = baked
		var mats := []
		if real:
			for si in mesh.get_surface_count():
				mats.append(src.get_active_material(si))
		parts.append([mesh, src.global_transform, mats])
		if parts.size() >= 24:
			break
	for i in offs.size():
		var off: Vector3 = offs[i]
		var ka = a * (1.0 - 0.6 * float(i) / maxf(1.0, offs.size()))
		for pr in parts:
			var e = MeshInstance3D.new()
			e.mesh = pr[0]
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if real:
				var ms: Array = pr[2]
				for si in ms.size():
					if ms[si]:
						e.set_surface_override_material(si, ms[si])
				e.transparency = 1.0 - ka
			else:
				e.material_override = _ghost_mat()
				_params(e, {"tint": tint, "alpha": ka})
			pj.get_tree().current_scene.add_child(e)
			var xf: Transform3D = pr[1]
			e.global_transform = Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * grow), xf.origin + off)
			var tw = e.create_tween()
			if real:
				tw.tween_property(e, "transparency", 1.0, life).set_ease(Tween.EASE_IN)
			else:
				tw.tween_method(func(v: float):
					if is_instance_valid(e):
						e.set_instance_shader_parameter("alpha", v), ka, 0.0, life).set_ease(Tween.EASE_IN)
			tw.tween_callback(e.queue_free)


## Yakın dövüş vuruşunun oyun tarafı (eski ortak vuruş yardımcısının oyun tarafı): isabet + vuruş ağırlığına göre sarsıntı. Görsel tekniğin kendisinde.
static func _mhit(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, info: Dictionary) -> Array:
	var hs = pj.hit(c, pos, r, info)
	if not hs.is_empty():
		var heavy = String(info.get("kind", "")) == "heavy"
		var s = clampf(0.8 + float(info.get("knock", 4.0)) * 0.04 + absf(float(info.get("launch", 0.0))) * 0.03, 0.8, 1.8)
		pj.shake(0.2 + 0.3 * (s if heavy else s * 0.7))
	return hs


# ================================================================== ortak yapı taşları (bu grubun kendi görünüşü)
## Hiraishin flaşı: dikey sarı ışık yarığı açılıp kapanır + ışın çatlağı + kısa ışık + birkaç altın kıvılcım (duman yok)
static func _flash(pj: PathJutsu, pos: Vector3, s: float) -> void:
	var slit = _flat(0.0, Vector2(0.9 * s, 2.7 * s), {"c1": GOLD_W, "c2": GOLD, "prog": 0.0, "nf": 2.0}, 2.0)
	_add(pj, slit, pos)
	var tw = slit.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(slit):
			slit.set_instance_shader_parameter("prog", v), 0.0, 1.0, 0.05)
	tw.tween_property(slit, "scale", Vector3(0.02, 3.6 * s, 1.0), 0.13).set_ease(Tween.EASE_IN)
	tw.tween_callback(slit.queue_free)
	_pop(pj, 1.0, pos, Vector2(2.4 * s, 2.4 * s), 0.2, 0.0, 0.08, {"c1": GOLD_W, "c2": GOLD, "nf": 2.0}, 1.0)
	_light(pj, pos, GOLD, 3.0 * s, 6.0 * s, 0.18)
	var bx = BoxMesh.new()
	bx.size = Vector3(0.03, 0.3, 0.03)
	_spray(pj, pos, {"n": 10, "life": 0.25, "col": GOLD_W, "mesh": bx, "spread": 180.0, "v0": 6.0, "v1": 12.0, "grav": 0.0, "s0": 0.6, "s1": 1.0, "align": true, "r": 0.2})


## Yerde kendini yazan Hiraishin formülü (altın yazı halkası + üç kol), yavaş söner
static func _formula(pj: PathJutsu, at: Vector3, r: float, life: float, col := GOLD) -> MeshInstance3D:
	return _decal(pj, 2.0, at, r, 0.14, life * 0.4, life * 0.6, {"c1": GOLD_W, "c2": col, "nf": 3.0})


## Hiraishin işareti: hedef senin işaretinle işaretliyse (hiraishin_by) göğsünde shiki işareti parlar
static func _mark_glow(pj: PathJutsu, c: Node3D, e: Node3D) -> void:
	if e == null or not is_instance_valid(e):
		return
	if not (e.has_meta("hiraishin_by") and int(e.get_meta("hiraishin_by")) == c.get_instance_id()):
		return
	var mk = _flat(3.0, Vector2(0.55, 0.55), {"c1": GOLD_W, "c2": GOLD, "prog": 1.0, "nf": 1.2}, 1.0)
	e.add_child(mk)
	mk.position = Vector3(0, _h(e) * 0.62, 0)
	var tw = mk.create_tween()
	tw.tween_property(mk, "scale", Vector3(0.9, 0.9, 1.0), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.35)
	tw.tween_method(func(v: float):
		if is_instance_valid(mk):
			mk.set_instance_shader_parameter("alpha", v), 1.0, 0.0, 0.4)
	tw.tween_callback(mk.queue_free)


## Minato'nun üç uçlu kunaisi (ileri = -Z): orta bıçak + iki yan diş, kâğıt sargılı sap üstünde formül yazısı, halka
static func _kunai_mesh() -> ArrayMesh:
	if _cache.has("mesh:kunai"):
		return _cache["mesh:kunai"]
	var b = MB.new()
	var steel = Color(0.3, 0.31, 0.36)
	var edge = Color(0.72, 0.74, 0.8)
	b.add("cone", Vector3(0, 0, -0.24), Vector3(0.085, 0.3, 0.022), steel, Vector3(-90, 0, 0), 4)
	b.add("cone", Vector3(0, 0.006, -0.25), Vector3(0.03, 0.28, 0.012), edge, Vector3(-90, 0, 0), 4)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.055, 0, -0.12), Vector3(0.035, 0.17, 0.014), steel, Vector3(-90, sx * 32.0, 0), 4)
	b.add("box", Vector3(0, 0, -0.085), Vector3(0.13, 0.024, 0.022), steel)
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.032, 0.19, 0.032), Color(0.93, 0.88, 0.72), Vector3(90, 0, 0), 8)
	for k in 6:
		b.add("box", Vector3(0, 0.016, -0.04 + k * 0.026), Vector3(0.014, 0.006, 0.012 + (k % 2) * 0.006), Color(0.09, 0.02, 0.02))
		b.add("box", Vector3(0, -0.016, -0.03 + k * 0.026), Vector3(0.012, 0.006, 0.01), Color(0.09, 0.02, 0.02))
	for k in 10:
		var a = TAU * k / 10.0
		b.add("sphere", Vector3(0, sin(a) * 0.035, 0.165 + cos(a) * 0.035), Vector3(0.016, 0.016, 0.016), steel, Vector3.ZERO, 5)
	var mesh = b.build(null)
	_cache["mesh:kunai"] = mesh
	return mesh


static func _kunai_node(s: float) -> Node3D:
	var n = _cel(_kunai_mesh(), 0.012, {"pat": 1.0, "glow": GOLD, "glow_k": 0.0, "nf": 0.8})
	n.scale = Vector3.ONE * s
	return n


## Kunainin formülü parlar: sap sarıya döner, kontur altınlaşır, üstünde formül halkası çakar
static func _kunai_flare(pj: PathJutsu, kun: Node3D) -> void:
	if not is_instance_valid(kun):
		return
	_all(kun, "glow_k", 1.0)
	_tp(kun, "glow_k", 1.0, 0.0, 0.5, 0.25)
	_pop(pj, 3.0, kun.global_position + UP * 0.2, Vector2(1.1, 1.1), 0.08, 0.1, 0.25, {"c1": GOLD_W, "c2": GOLD, "nf": 1.5}, 1.0)


## Yayı çizen kesik hilali (yatay düzlem, tilt derece eğik)
static func _slash(pj: PathJutsu, at: Vector3, d: Vector3, a0: float, a1: float, r: float, c1: Color, c2: Color, w: float, tilt := 18.0, life := 0.22) -> void:
	var fd = _flatv(d)
	var side = fd.cross(UP).normalized()
	var nrm = UP.rotated(fd, deg_to_rad(tilt))
	var pts: Array = []
	var ws: Array = []
	var ns: Array = []
	var n = 18
	for i in n:
		var u = float(i) / float(n - 1)
		var ang = deg_to_rad(lerpf(a0, a1, u))
		var dir = (fd * cos(ang) + side * sin(ang)).rotated(fd, deg_to_rad(tilt))
		pts.append(at + dir * r)
		ws.append(w)
		ns.append(nrm)
	var mi = _ribbon_node(pj, pts, ws, {"pat": 0.0, "c1": c1, "c2": c2, "reveal": 0.0, "tail": 0.0, "nf": 1.5}, ns)
	var tw = _tp(mi, "reveal", 0.0, 1.0, life * 0.35)
	tw.parallel().tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("tail", v), 0.0, 1.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Cel toz halkası (yerden dışa savrulan bulutçuklar)
static func _dust(pj: PathJutsu, at: Vector3, s: float, col: Color, n := 7) -> void:
	var cols = [col, col.darkened(0.25), col.darkened(0.62)]
	for i in n:
		var a = TAU * i / n + randf_range(-0.3, 0.3)
		var dv = Vector3(cos(a), 0.0, sin(a))
		_puff(pj, at + dv * 0.3 * s + UP * 0.25 * s, randf_range(0.5, 0.8) * s, dv * 1.6 * s + UP * 0.5 * s, randf_range(0.6, 0.9), cols, 0.95, 1.7)


## Zehirli ısırık: oyun tarafı (eski poison yardımcısı: hasar + yanma) + iki diş deliğinden mor zehir damlası
static func _venom(pj: PathJutsu, c: Node3D, e: Node3D, id: String, mul: float, dur := 4.0) -> void:
	var at = e.global_position + UP * _h(e) * 0.6
	pj.hit(c, at, _rad(e) + 0.6, pj.inf(c, id, mul, {"knock": 1.0, "kind": "light", "burn": dur, "hitstop": 0.03}))
	_spray(pj, at, {"n": 9, "life": 0.6, "col": VENOM, "dir": Vector3.DOWN, "spread": 55.0, "v0": 0.6, "v1": 2.0, "grav": 7.0, "s0": 0.04, "s1": 0.08, "r": 0.2})
	_pop(pj, 6.0, at, Vector2(0.45, 0.45), 0.08, 0.15, 0.3, {"c1": VENOM, "c2": VENOM_D, "nf": 1.2}, 1.0)


# ================================================================== Hiraishin no Jutsu
## Ref (Minato): sarı flaşla yok olur, geride bir an sarı ardıl görüntü kalır; hedefin arkasında yarık ışıkla belirir,
## ayağının altında formül çakar; hedef işaretliyse üstündeki shiki işareti parlar. Duman yok.
## Mekanik: Jutsu.j_hiraishin_no_jutsu satır satır (hedefin 1.6 m arkası, vuruş, yön); hedef yoksa 18 m ileri ışınlanma.
static func hiraishin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var a = c.global_position
	_ghost(pj, c, GOLD, 0.75, 0.4, [Vector3.ZERO])
	_flash(pj, a + UP, 1.0)
	var tg = Jutsu._tg(c, t, 40.0)
	var from = c.global_position
	if tg:
		var behind = tg.global_position - (tg.global_position - from).normalized() * -1.6
		c.global_position = Jutsu._ground(behind)
		if c.has_method("reset_physics_interpolation"):
			c.reset_physics_interpolation()
		var dd = (tg.global_position - c.global_position)
		dd.y = 0
		if c is Player:
			c.facing = atan2(-dd.x, -dd.z)
		_mark_glow(pj, c, tg)
		var hp_at = tg.global_position + UP * _h(tg) * 0.55
		tg.take_hit(Jutsu._inf(c, "hiraishin_no_jutsu", 1.6, {"knock": 10.0, "dir": dd.normalized(), "attacker": c, "hitstop": 0.12}))
		# vuruş: hedefin sırtında kısa altın ışın çatlağı + sarı kesik
		_pop(pj, 1.0, hp_at, Vector2(1.8, 1.8), 0.16, 0.0, 0.08, {"c1": GOLD_W, "c2": GOLD}, 1.0)
		_slash(pj, c.global_position + UP * 1.15, dd, -60.0, 70.0, 1.3, GOLD_W, GOLD, 0.22, -25.0, 0.2)
	else:
		var dir: Vector3 = Jutsu._aim_flat(c, t)
		c.global_position = Jutsu._ground(c.global_position + dir * 18.0)
	_flash(pj, c.global_position + UP, 1.15)
	_formula(pj, c.global_position, 1.3, 0.9)
	Sfx.play("whoosh", c.global_position, 1.8)


# ================================================================== Hiraishingiri
## Ref (Tobirama): ışınlanıp kesme — gerçek renkli saydam ardıl kopyalar yol boyunca dizilir, arkasında yatay hız
## çizgileri; varışta toz tekmesi, ardından geniş beyaz-mavi kılıç hilali, isabette kan kıymıkları.
static func hiraishingiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 0.5)
	if tt == null:
		return
	var start = c.global_position
	var away = tt.global_position - start
	away.y = 0
	var end = pj.gp(tt.global_position - away.normalized() * 1.2)
	var path = end - start
	_ghost(pj, c, Color.WHITE, 0.6, 0.32, [path * 0.12, path * 0.42, path * 0.7], true)
	for k in 7:
		var hgt = randf_range(0.25, 1.9)
		var sd = _flatv(path).cross(UP) * randf_range(-0.6, 0.6)
		var p0 = start + UP * hgt + sd
		var p1 = end + UP * hgt + sd - _flatv(path) * randf_range(0.5, 1.5)
		var ln = _ribbon_node(pj, [p0, p0.lerp(p1, 0.5), p1], [0.05, 0.05, 0.05], {"pat": 1.0, "c1": Color(0.95, 0.97, 1.0), "c2": Color(0.62, 0.68, 0.78), "nf": 2.0})
		_fade_free(ln, 0.04, 0.22)
	c.global_position = end
	if c is Player:
		c.combat.face_to(tt)
	_dust(pj, end, 0.6, Color(0.72, 0.7, 0.66), 5)
	pj.after(0.08, func():
		if pj.live(c):
			pj.anim(c, "slash_a", 2.0)
			var dir = (tt.global_position - c.global_position).normalized() if pj.live(tt) else c.face_dir()
			_slash(pj, c.global_position + UP * 1.2, dir, -80.0, 80.0, 1.6, Color(0.97, 0.99, 1.0), Color(0.55, 0.72, 0.95), 0.34, 12.0, 0.24)
			var hs = _mhit(pj, c, tt.global_position + UP if pj.live(tt) else c.global_position, 1.6, pj.inf(c, "hiraishingiri", 1.7, {"knock": 8.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1}))
			if not hs.is_empty():
				var h0: Node3D = hs[0]
				_spray(pj, h0.global_position + UP * 1.1, {"n": 14, "life": 0.5, "col": Color(0.55, 0.05, 0.06), "dir": _flatv(dir).cross(UP), "spread": 35.0, "v0": 3.0, "v1": 7.0, "grav": 9.0, "s0": 0.03, "s1": 0.07}))
	Sfx.play("thunder", end, 2.0, 0.4)


# ================================================================== Hiraishin: Ni no Dan
## Ref: Minato'nun üç uçlu, sapı formül yazılı kunaisi. Kunai fırlar (ince altın iz), 0.35 sn sonra sapındaki formül
## parlar, kullanıcı geride sarı ardıl görüntü bırakıp kunainin yanında belirir ve ters tutuşla yatay keser.
static func hiraishin_ni_no_dan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 30.0)
	var from = pj.hand_pos(c, true)
	var kun = _kunai_node(1.6)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 40.0, kun, pj.inf(c, "hiraishin_ni_no_dan", 0.3, {"knock": 1.0, "kind": "light"}), null, false, 0.9)
	_trail(pj, pr, GOLD_W, GOLD, 0.05, 0.6, 9)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var dest = pr.global_position if is_instance_valid(pr) else (tt.global_position if tt and pj.live(tt) else c.global_position + c.face_dir() * 10.0)
		var start = c.global_position
		if is_instance_valid(pr):
			_kunai_flare(pj, kun)
		else:
			_pop(pj, 3.0, dest + UP * 0.3, Vector2(1.1, 1.1), 0.08, 0.1, 0.25, {"c1": GOLD_W, "c2": GOLD}, 1.0)
		_ghost(pj, c, GOLD, 0.7, 0.35, [Vector3.ZERO])
		_flash(pj, start + UP, 0.85)
		c.global_position = pj.gp(dest)
		_flash(pj, c.global_position + UP, 1.0)
		if tt and pj.live(tt):
			if c is Player:
				c.combat.face_to(tt)
			var dd = (tt.global_position - c.global_position).normalized()
			_slash(pj, c.global_position + UP * 1.2, dd, 70.0, -90.0, 1.8, GOLD_W, GOLD, 0.3, -8.0, 0.24)
			_mhit(pj, c, tt.global_position + UP, 2.0, pj.inf(c, "hiraishin_ni_no_dan", 1.8, {"knock": 10.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1})))
	Sfx.play("thunder", from, 2.0, 0.4)


# ================================================================== Hiraishin Dōrai
## Ref (Kage yüzlerinin önünde): benekli mor bulut küre, çevresinde kara mühür yazısı zincirleri. Küre hedefi sarıp
## küçülür; hedef 14 m yukarıda ikinci, patlayan bir mor kürenin içinden çıkar, zincirler kopup mürekkep olarak saçılır.
static func hiraishin_dorai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.7)
	if tt == null:
		return
	var p1 = Color(0.62, 0.45, 0.9)
	var p2 = Color(0.42, 0.26, 0.66)
	var p3 = Color(0.22, 0.12, 0.36)
	var ground_at = pj.gp(tt.global_position)
	_decal(pj, 7.0, ground_at, 2.6, 0.2, 0.4, 0.5, {"c1": p3, "nf": 3.0})
	var sph = Node3D.new()
	var core = _mi(_sphere(), _orb_mat())
	_params(core, {"kind": 2.0, "c1": p1, "c2": p2, "c3": p3, "seed": randf() * 10.0, "nf": 3.0})
	sph.add_child(core)
	for k in 3:
		var tilt = Basis.from_euler(Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2)))
		var pts: Array = []
		var ws: Array = []
		for i in 25:
			var a = TAU * i / 24.0
			pts.append(tilt * Vector3(cos(a), 0.0, sin(a)) * 0.56)
			ws.append(0.06)
		var ch = _mi(_mesh([_ribbon(pts, ws)]), _ribbon_mat())
		_params(ch, {"pat": 2.0, "c1": Color(0.55, 0.45, 0.7), "c2": INK, "seed": k * 3.0, "nf": 3.0})
		sph.add_child(ch)
		var spin = ch.create_tween().set_loops(4)
		spin.tween_property(ch, "rotation:y", ch.rotation.y + TAU * (1.0 if k % 2 == 0 else -1.0), 0.6).as_relative()
	_add(pj, sph, tt.global_position + UP)
	sph.scale = Vector3.ONE * 6.0
	var tw = sph.create_tween()
	tw.tween_property(sph, "scale", Vector3.ONE * 2.6, 0.3)
	tw.tween_callback(func():
		if pj.live(tt):
			var up = tt.global_position + UP * 14.0
			tt.global_position = up
			_dorai_exit(pj, up + UP, p1, p2, p3)
			pj.st(tt, "stun", 1.4)
			tt.take_hit(pj.inf(c, "hiraishin_dorai", 1.6, {"knock": 0.0, "launch": -12.0, "kind": "heavy"})))
	tw.tween_property(sph, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(sph.queue_free)
	Sfx.play("seal", tt.global_position, 1.8, 0.6)


## Yukarıdaki çıkış: mor küre açılıp dağılır, kopan zincir mürekkebi saçılır
static func _dorai_exit(pj: PathJutsu, at: Vector3, p1: Color, p2: Color, p3: Color) -> void:
	var o = _mi(_sphere(), _orb_mat())
	_params(o, {"kind": 2.0, "c1": p1, "c2": p2, "c3": p3, "seed": randf() * 10.0, "nf": 3.0})
	_add(pj, o, at)
	o.scale = Vector3.ONE * 0.4
	var tw = o.create_tween()
	tw.tween_property(o, "scale", Vector3.ONE * 3.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float):
		if is_instance_valid(o):
			o.set_instance_shader_parameter("alpha", v), 1.0, 0.0, 0.3)
	tw.tween_callback(o.queue_free)
	var bx = BoxMesh.new()
	bx.size = Vector3(0.05, 0.22, 0.05)
	_spray(pj, at, {"n": 22, "life": 0.7, "col": INK, "mesh": bx, "spread": 180.0, "v0": 5.0, "v1": 10.0, "grav": 6.0, "s0": 0.6, "s1": 1.2, "align": true, "r": 0.8})


# ================================================================== Rasen Senkō Chō Rinbukō Sanshiki
## Ref (Minato, kurama çakrasıyla): altı formül kunaisi hedefin çevresine çember hâlinde saplanır; her ışınlanmada
## sarı ardıl görüntü + yarık flaş, kunainin formülü parlar, elde dönen Rasengan vurur. Sonda kunailer arasında altın
## altıgen + yıldız ağı çakar, merkezde dev ışın çatlağı ve yerde formül; herkes savrulur.
static func rasen_senko_cho_rinbuko_sanshiki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 1.8)
	var cen = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 8.0)
	var spots = []
	for k in 6:
		var a = TAU * k / 6.0
		spots.append(pj.gp(cen + Vector3(cos(a), 0, sin(a)) * 5.0))
	pj.anim(c, "throw", 1.4)
	var kunais: Array = []
	for k in 6:
		var sp: Vector3 = spots[k]
		var pr_from = c.global_position + UP * 1.3
		var kun = _kunai_node(1.5)
		pj.scene_add(kun, pr_from)
		var to = sp + UP * 0.2
		var kd = to - pr_from
		if kd.length() > 0.05 and absf(kd.normalized().y) < 0.95:
			kun.look_at(to, UP)
		kunais.append(kun)
		_trail(pj, kun, GOLD_W, GOLD, 0.04, 0.45 + k * 0.03, 8)
		var tw = kun.create_tween()
		tw.tween_property(kun, "global_position", to, 0.25 + k * 0.03)
		tw.tween_interval(1.6)
		tw.tween_callback(kun.queue_free)
	Sfx.play("whoosh", c.global_position, 1.3)
	var hits = {}
	for k in 6:
		pj.after(0.4 + k * 0.17, func():
			if not pj.live(c):
				return
			var sp: Vector3 = spots[k]
			_ghost(pj, c, GOLD, 0.55, 0.3, [Vector3.ZERO])
			_flash(pj, c.global_position + UP, 0.7)
			c.global_position = sp
			_flash(pj, sp + UP, 0.8)
			var kn = kunais[k]
			if is_instance_valid(kn):
				_kunai_flare(pj, kn)
			if "facing" in c:
				var dd = cen - sp
				c.facing = atan2(-dd.x, -dd.z)
			_rasengan(pj, sp + UP * 1.1 + (cen - sp).normalized() * 0.8, (cen - sp).normalized(), 0.2)
			for h in pj.hit(c, sp + UP + (cen - sp).normalized() * 2.0, 3.0, pj.inf(c, "rasen_senko_cho_rinbuko_sanshiki", 0.35, {"knock": 4.0, "kind": "heavy", "hitstop": 0.03})):
				hits[h] = true
			Sfx.play("th_teleport", sp, 1.2, 0.5))
	pj.after(0.4 + 6 * 0.17, func():
		if not pj.live(c):
			return
		_light(pj, cen + UP, GOLD, 9.0, 18.0, 0.3)
		_pop(pj, 1.0, cen + UP * 1.2, Vector2(9.0, 9.0), 0.28, 0.0, 0.12, {"c1": GOLD_W, "c2": GOLD, "nf": 4.0}, 1.0)
		_formula(pj, cen, 6.5, 1.1)
		_hexagram(pj, spots)
		for e in pj.enemies_near(c, cen, 7.0):
			var away = (e.global_position - cen)
			away.y = 0
			e.take_hit(pj.inf(c, "rasen_senko_cho_rinbuko_sanshiki", 1.0, {"knock": 18.0, "launch": 5.0, "dir": away.normalized(), "kind": "heavy", "hitstop": 0.08}))
		pj.shake(0.7))


## Elde dönen Rasengan (kendi küresi): bakışa göre dönen mavi-beyaz sarmal + iki ince dönen halka; çarpışta ileri
## doğru açılan rüzgâr kesme halkası
static func _rasengan(pj: PathJutsu, at: Vector3, d: Vector3, life: float) -> void:
	var root = Node3D.new()
	var orb = _mi(_sphere(), _orb_mat())
	_params(orb, {"kind": 0.0, "c1": Color(0.9, 0.97, 1.0), "c2": Color(0.32, 0.62, 1.0), "c3": Color(0.06, 0.14, 0.4), "seed": randf() * 6.0, "nf": 1.5})
	orb.scale = Vector3.ONE * 0.9
	root.add_child(orb)
	for k in 2:
		var pts: Array = []
		var ws: Array = []
		for i in 21:
			var a = TAU * i / 20.0
			pts.append(Vector3(cos(a), 0.0, sin(a)) * 0.62)
			ws.append(0.03)
		var rg = _mi(_mesh([_ribbon(pts, ws)]), _ribbon_mat())
		_params(rg, {"pat": 6.0, "c1": Color(0.85, 0.95, 1.0), "c2": Color(0.4, 0.7, 1.0), "nf": 1.5})
		rg.rotation = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		root.add_child(rg)
		var spin = rg.create_tween()
		spin.tween_property(rg, "rotation:y", TAU * 2.0, life + 0.1).as_relative()
	_add(pj, root, at)
	root.scale = Vector3.ONE * 0.5
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.05)
	tw.tween_interval(life)
	tw.tween_property(root, "scale", Vector3.ONE * 0.1, 0.08)
	tw.tween_callback(root.queue_free)
	# çarpma: ileri yönde açılan ince kesme halkası
	var fd = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var s1 = fd.cross(UP if absf(fd.y) < 0.9 else Vector3.RIGHT).normalized()
	var s2 = fd.cross(s1).normalized()
	var pts2: Array = []
	var ws2: Array = []
	var ns2: Array = []
	for i in 25:
		var a = TAU * i / 24.0
		pts2.append(at + fd * 0.9 + (s1 * cos(a) + s2 * sin(a)) * 0.5)
		ws2.append(0.12)
		ns2.append(fd)
	var ring = _ribbon_node(pj, pts2, ws2, {"pat": 6.0, "c1": Color(0.9, 0.97, 1.0), "c2": Color(0.35, 0.6, 1.0), "nf": 1.5}, ns2)
	var center = at + fd * 0.9
	var rt = ring.create_tween()
	rt.tween_method(func(v: float):
		if is_instance_valid(ring):
			ring.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * v), center - center * v)
			ring.set_instance_shader_parameter("alpha", 1.0 - (v - 1.0) / 2.5), 1.0, 3.5, 0.2)
	rt.tween_callback(ring.queue_free)


## Altı kunai arasında altın altıgen + yıldız (iki üçgen) çizgileri yerde çakar
static func _hexagram(pj: PathJutsu, spots: Array) -> void:
	var pairs: Array = []
	for i in 6:
		pairs.append([i, (i + 1) % 6])
		pairs.append([i, (i + 2) % 6])
	for pr in pairs:
		var a: Vector3 = spots[pr[0]] + UP * 0.07
		var b: Vector3 = spots[pr[1]] + UP * 0.07
		var pts: Array = []
		var ws: Array = []
		var ns: Array = []
		for i in 8:
			pts.append(a.lerp(b, i / 7.0))
			ws.append(0.16)
			ns.append(UP)
		var ln = _ribbon_node(pj, pts, ws, {"pat": 6.0, "c1": GOLD_W, "c2": GOLD, "reveal": 0.0, "nf": 3.0}, ns)
		var tw = _tp(ln, "reveal", 0.0, 1.0, 0.12)
		tw.tween_interval(0.25)
		tw.tween_method(func(v: float):
			if is_instance_valid(ln):
				ln.set_instance_shader_parameter("alpha", v), 1.0, 0.0, 0.6)
		tw.tween_callback(ln.queue_free)


# ================================================================== Kekkai: Gama Hyōro
## Ref (Hyōtan Gama): kırmızı armut gövdeli, kulak çıkıntılı, sarı gözlü kabak kurbağa; ağzında 酒 yazılı mantar tıpa,
## belinde yeşil şerit (köşeli desen), pullu kollar. Yerde mürekkep çağırma çemberi yazılır, kurbağa hedefin üstüne
## oturur, hedef midesinde kaybolur (nefes alır gibi şişip iner); süre bitince tıpadan mide sıvısıyla tükürülür.
static func kekkai_gama_hyoro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	_decal(pj, 7.0, at, 2.2, 0.25, 0.5, 0.6, {"c1": INK, "nf": 3.0})
	var gourd = Node3D.new()
	var breath = _cel(_gourd_mesh(), 0.035, {"nf": 3.0})
	gourd.add_child(breath)
	pj.get_tree().current_scene.add_child(gourd)
	gourd.global_position = at
	var fd = _flatv(c.global_position - at)
	gourd.look_at(at + fd, UP)
	gourd.scale = Vector3.ONE * 0.05
	var tw = gourd.create_tween()
	tw.tween_property(gourd, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(5.0)
	tw.tween_callback(func():
		var mouth = gourd.global_position + (-gourd.global_transform.basis.z) * 1.0 + UP * 1.85 if is_instance_valid(gourd) else at + UP * 1.8
		_decal(pj, 7.0, at, 2.0, 0.15, 0.2, 0.4, {"c1": INK, "nf": 3.0})
		_spray(pj, mouth, {"n": 26, "life": 0.8, "col": Color(0.85, 0.82, 0.55), "dir": UP, "spread": 70.0, "v0": 3.0, "v1": 7.0, "grav": 9.0, "s0": 0.06, "s1": 0.14, "r": 0.4})
		_decal(pj, 6.0, at, 1.6, 0.2, 1.0, 1.0, {"c1": Color(0.72, 0.68, 0.42), "c2": Color(0.5, 0.46, 0.26), "nf": 3.0}))
	tw.tween_property(gourd, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(gourd.queue_free)
	pj.every(5.3, 0.1, func(_i, k):
		if is_instance_valid(breath):
			var s = 1.0 + sin(k * 5.3 * 2.2) * 0.035
			breath.scale = Vector3(1.0 / s, s, 1.0 / s))
	var body = tt.get("model") if tt.get("model") else null
	if body:
		body.visible = false
		pj.after(5.3, func():
			if is_instance_valid(body):
				body.visible = true)
	pj.st(tt, "bind", 5.3)
	Combat.popup_text(at + UP * 4.0, "Kabağa hapsedildi!", Color(0.95, 0.5, 0.4))
	Sfx.play("poof", at, 0.7)


## Kabak kurbağa modeli (ileri = -Z, yükseklik ~3.4 m)
static func _gourd_mesh() -> ArrayMesh:
	if _cache.has("mesh:gourd"):
		return _cache["mesh:gourd"]
	var b = MB.new()
	var red = Color(0.6, 0.2, 0.25)
	var red_l = Color(0.7, 0.27, 0.31)
	var dark = Color(0.18, 0.05, 0.07)
	b.add_grad("sphere", Vector3(0, 1.15, 0), Vector3(2.5, 2.3, 2.3), red_l, red, Vector3.ZERO, 18)       # alt gövde
	b.add_grad("sphere", Vector3(0, 2.2, -0.1), Vector3(1.9, 1.6, 1.8), red_l, red, Vector3.ZERO, 16)     # baş-gövde
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.62, 3.0, 0.0), Vector3(0.42, 0.75, 0.45), red, Vector3(0, 0, -sx * 28.0), 8)        # kulak çıkıntısı
		b.add("sphere", Vector3(sx * 0.62, 2.0, -0.62), Vector3(0.9, 0.75, 0.8), red_l, Vector3.ZERO, 12)               # yanak
		b.add("sphere", Vector3(sx * 0.36, 2.45, -0.82), Vector3(0.4, 0.34, 0.2), dark, Vector3.ZERO, 10)               # göz kenarı
		b.add("sphere", Vector3(sx * 0.36, 2.45, -0.88), Vector3(0.32, 0.27, 0.16), Color(0.95, 0.88, 0.4), Vector3.ZERO, 10)   # sarı göz
		b.add("sphere", Vector3(sx * 0.36, 2.45, -0.95), Vector3(0.12, 0.12, 0.06), dark, Vector3.ZERO, 6)               # bebek
		b.add("sphere", Vector3(sx * 0.55, 2.6, -0.7), Vector3(0.36, 0.08, 0.1), dark, Vector3(0, 0, sx * 25.0), 6)      # kaş çizgisi
		b.add("cyl", Vector3(sx * 0.82, 0.95, -0.92), Vector3(0.32, 1.25, 0.32), red, Vector3(-18, 0, sx * 8.0), 8)       # kol
		for k in 4:
			b.add("box", Vector3(sx * 0.85, 1.35 - k * 0.24, -1.1 + k * 0.06), Vector3(0.22, 0.04, 0.04), dark, Vector3(0, 0, sx * 35.0))   # pul köşesi
		for f in 3:
			b.add("cone", Vector3(sx * (0.7 + f * 0.11), 0.25, -1.18), Vector3(0.08, 0.36, 0.08), red, Vector3(-120, 0, sx * (f - 1) * 14.0), 5)   # pençe
		b.add("sphere", Vector3(sx * 1.05, 0.35, 0.35), Vector3(0.7, 0.55, 1.1), red, Vector3.ZERO, 10)                  # arka bacak
	# ağız tıpası (酒) + mühür yazısı
	b.add("cyl", Vector3(0, 1.85, -1.02), Vector3(0.5, 0.3, 0.5), Color(0.88, 0.72, 0.42), Vector3(90, 0, 0), 12)
	b.add("box", Vector3(-0.12, 1.92, -1.18), Vector3(0.05, 0.04, 0.02), dark)
	b.add("box", Vector3(-0.13, 1.84, -1.18), Vector3(0.05, 0.04, 0.02), dark)
	b.add("box", Vector3(-0.14, 1.76, -1.18), Vector3(0.06, 0.035, 0.02), dark, Vector3(0, 0, 30))
	b.add("box", Vector3(0.06, 1.9, -1.18), Vector3(0.18, 0.025, 0.02), dark)
	b.add("box", Vector3(0.06, 1.78, -1.18), Vector3(0.16, 0.12, 0.02), Color(0.25, 0.12, 0.08))
	# yeşil bel şeridi + köşeli desen
	b.add("cyl", Vector3(0, 1.3, 0), Vector3(2.55, 0.38, 2.35), Color(0.45, 0.5, 0.36), Vector3.ZERO, 20)
	for k in 14:
		var a = TAU * k / 14.0
		var pnt = Vector3(sin(a) * 1.29, 1.3, cos(a) * 1.19)
		b.add("box", pnt, Vector3(0.18, 0.04, 0.04), Color(0.22, 0.26, 0.17), Vector3(0, rad_to_deg(a), 35))
		b.add("box", pnt, Vector3(0.18, 0.04, 0.04), Color(0.22, 0.26, 0.17), Vector3(0, rad_to_deg(a), -35))
	var mesh = b.build(null)
	_cache["mesh:gourd"] = mesh
	return mesh


# ================================================================== Gamagakure no Jutsu
## Ref (Jiraiya, yağmurda): avuç yere dokununca su halkaları açılır; yanından yeşil kurbağa (çağırma kurbağası) çıkar,
## ağzını açar, kullanıcı içine dalar, kurbağa halkaların içine geri gömülür. Gizlilik bitince aynı yerde halkalar.
## Mekanik: JutsuEngine gizlenme (stealth) dalı satır satır: gizlilik buff'ı, yakın düşmanlar hedefi kaybeder,
## beden en çok 4 sn görünmez. Duman yok.
static func gamagakure_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("gamagakure_no_jutsu", {})
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	var g0 = pj.gp(c.global_position)
	_ripples(pj, g0, 1.0, 4)
	var side = _fdir(c).cross(UP).normalized()
	var toad_at = g0 + side * 0.9 + _fdir(c) * 0.4
	var sm = SummonModels.build("toad_small", 1.3, 1.3)
	var toad: Node3D = sm["root"]
	_add(pj, toad, toad_at + Vector3.DOWN * 0.8)
	var look = c.global_position
	look.y = toad.global_position.y
	if look.distance_to(toad.global_position) > 0.05:
		toad.look_at(look, UP)
	toad.scale = Vector3.ONE * 0.3
	var tw = toad.create_tween()
	tw.tween_property(toad, "global_position", toad_at, 0.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(toad, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(toad, "scale", Vector3(1.15, 0.85, 1.15), 0.12)      # yutar
	tw.tween_property(toad, "scale", Vector3(0.95, 1.08, 0.95), 0.1)
	tw.tween_interval(0.25)
	tw.tween_property(toad, "global_position", toad_at + Vector3.DOWN * 1.4, 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(toad, "scale", Vector3.ONE * 0.3, 0.3)
	tw.tween_callback(toad.queue_free)
	_spray(pj, toad_at, {"n": 14, "life": 0.6, "col": Color(0.62, 0.72, 0.8), "dir": UP, "spread": 50.0, "v0": 2.0, "v1": 4.5, "grav": 9.0, "s0": 0.04, "s1": 0.08, "r": 0.4})
	if c.get("model"):
		var m = c.model
		pj.after(0.3, func():
			if is_instance_valid(m) and is_instance_valid(c):
				_spray(pj, c.global_position + UP * 0.2, {"n": 10, "life": 0.5, "col": Color(0.62, 0.72, 0.8), "dir": UP, "spread": 40.0, "v0": 1.5, "v1": 3.5, "grav": 9.0, "s0": 0.04, "s1": 0.07, "r": 0.3})
				m.visible = false)
		pj.get_tree().create_timer(minf(dur, 4.0)).timeout.connect(func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = true
				_ripples(pj, pj.gp(c.global_position), 0.9, 3))
	Sfx.play("poof", c.global_position)


## Su halkaları: kesik kesik açılan anime halka çizgileri
static func _ripples(pj: PathJutsu, at: Vector3, s: float, n: int) -> void:
	for k in n:
		pj.after(k * 0.14, func():
			var mi = _decal(pj, 4.0, at, 0.4 * s, 0.01, 0.0, 0.7, {"c1": Color(0.88, 0.94, 1.0), "nf": 2.5})
			var tw = mi.create_tween()
			tw.tween_property(mi, "scale", Vector3(2.4 * s * (1.0 + k * 0.25), 2.4 * s * (1.0 + k * 0.25), 1.0) * 1.0, 0.7).set_ease(Tween.EASE_OUT))


# ================================================================== Jagei Jubaku
## Ref (Sasuke'nin bakışı): bakış — kullanıcının yüzünde iki sarı yarık yılan gözü açılır, bakış çizgileri kurbanlara
## uzanır; her kurbanın yanından yerden iki beyaz pullu yılan (gerçek yılan modeli) çıkıp bedenine sarılır ve 3.5 sn
## sıkar (illüzyon), sonra çözülüp geri çekilir.
static func jagei_jubaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	pj.busy(c, 0.8)
	var victims = pj.cone_enemies(c, d, 18.0, 110.0)
	var head = _bone(c, "Head", UP * 1.65) + d * 0.18 + UP * 0.04
	var side = d.cross(UP).normalized()
	for sx in [-1.0, 1.0]:
		_pop(pj, 9.0, head + side * sx * 0.075, Vector2(0.12, 0.12), 0.12, 0.6, 0.3, {"c1": Color(1.0, 0.86, 0.18), "c2": Color(0.3, 0.2, 0.05), "nf": 0.6}, 1.0)
	# bakışın arkasında beliren dev yılan gözleri (yarı saydam, kullanıcının üstünde)
	for sx in [-1.0, 1.0]:
		_pop(pj, 9.0, c.global_position + UP * 3.2 - d * 0.6 + side * sx * 0.7, Vector2(1.0, 1.0), 0.18, 0.5, 0.4, {"c1": Color(1.0, 0.86, 0.18), "c2": Color(0.3, 0.2, 0.05), "alpha": 0.75, "nf": 2.0}, 1.0)
	for e in victims:
		var eh = e.global_position + UP * _h(e) * 0.85
		var ln = _ribbon_node(pj, [head, head.lerp(eh, 0.5), eh], [0.03, 0.03, 0.03], {"pat": 1.0, "c1": Color(1.0, 0.93, 0.5), "c2": Color(0.85, 0.6, 0.15), "nf": 1.2})
		_fade_free(ln, 0.1, 0.3)
	if Game.world and c is Player:
		Game.world.env.flash_tint(Color(0.35, 0.1, 0.45, 0.18), 1.4)
	Sfx.play("genjutsu", c.global_position, 0.6)
	for e in victims:
		pj.st(e, "stun", 3.5)
		pj.st(e, "fear", 3.5)
		Combat.popup_text(e.global_position + UP * (e.height + 0.8), "Dehşet!", Color(0.85, 0.6, 1.0))
		pj.hit(c, e.global_position + UP, e.radius + 0.4, pj.inf(c, "jagei_jubaku", 0.2, {"knock": 0.0, "kind": "light"}))
		_bind_snakes(pj, e)


## Kurbanın iki yanından yerden çıkıp bedene sarılan beyaz yılanlar (SleeveSnake: kuyruk yerde, gövde sarmal)
static func _bind_snakes(pj: PathJutsu, e: Node3D) -> void:
	for k in 2:
		var off = Vector3(cos(k * PI + 0.6), 0.0, sin(k * PI + 0.6)) * (_rad(e) + 0.9)
		var sn = SleeveSnake.new()
		sn.anchor = func():
			if not is_instance_valid(e):
				return Vector3.ZERO
			return pj.gp(e.global_position + off) + Vector3.DOWN * 0.1
		sn.aim_dir = UP
		sn.target = e
		sn.free_to = e.global_position + UP * 1.2
		sn.side = (k - 0.5) * 0.6
		sn.lift = 0.4
		sn.phase = float(k) * 2.3
		sn.coil_y0 = 0.15 + 0.2 * k
		sn.coil_y1 = sn.coil_y0 + 0.5
		sn.coil_turns = 1.6
		sn.radius = 0.11
		sn.back_col = SNAKE_W
		sn.belly_col = Color(0.98, 0.95, 0.95)
		pj.get_tree().current_scene.add_child(sn)
		sn.set_head(pj.snake_head(SNAKE_W, 0.38))
		_spray(pj, pj.gp(e.global_position + off), {"n": 8, "life": 0.5, "col": Color(0.4, 0.36, 0.3), "dir": UP, "spread": 40.0, "v0": 2.0, "v1": 4.0, "s0": 0.05, "s1": 0.1})
		sn.extend(0.35 + k * 0.08)
		pj.after(3.5, func():
			if is_instance_valid(sn):
				sn.retract(0.3))


# ================================================================== Sen'ei Jashu
## Ref (Anko): kol hedefe uzatılır, yenin içinden dört koyu pullu yılan (gerçek SleeveSnake) fırlar, sarılır ve ısırır
## (mor zehir damlası); sonra hedef kullanıcıya çekilir — çekilirken ayaklarının altında sürüklenme izi kalır.
static func sen_ei_jashu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.2)
	Sfx.play("whoosh", c.global_position, 0.7)
	var d = pj.fwd(c, t)
	var snakes = []
	var right = pj.fore_hand(c)
	for k in 4:
		var sn = pj.sleeve_snake(c, right, tt, k, 4, d * 16.0)
		snakes.append(sn)
		sn.extend(0.32 + k * 0.03, func():
			if k == 0:
				if tt and pj.live(tt):
					_venom(pj, c, tt, "sen_ei_jashu", 0.45, 4.0)
					pj.st(tt, "bind", 2.4)
					Combat.popup_text(tt.global_position + UP * (tt.height + 0.8), "Yılanlar sardı!", Color(0.7, 0.75, 0.5))
				else:
					_dust(pj, pj.gp(c.global_position + d * 16.0), 0.6, Color(0.66, 0.6, 0.5), 5))
	if tt:
		pj.after(0.55, func():
			if pj.live(tt):
				var a0 = pj.gp(tt.global_position)
				pj.pull_to(c, tt, 0.5)
				var drag = (c.global_position - a0)
				drag.y = 0
				if drag.length() > 1.0:
					var mid = a0 + drag * 0.5
					var mk = _flat(8.0, Vector2(0.8, drag.length()), {"c1": Color(0.3, 0.26, 0.2), "prog": 0.0, "nf": 3.0}, 0.0)
					_add(pj, mk, mid + UP * 0.05)
					mk.look_at(mid + UP * 0.05 + UP, drag.normalized())
					var tw = _tp(mk, "prog", 0.0, 1.0, 0.5)
					tw.tween_interval(1.0)
					tw.tween_method(func(v: float):
						if is_instance_valid(mk):
							mk.set_instance_shader_parameter("alpha", v), 1.0, 0.0, 0.8)
					tw.tween_callback(mk.queue_free))
	pj.after(2.0, func():
		for sn in snakes:
			if is_instance_valid(sn):
				sn.retract(0.3))


# ================================================================== Sen'ei Ranjashu
## Ref: beyaz, pembe ağızlı yılan sürüsü yerden fışkırır, dibinde kabaran toz; üç dalga koni boyunca ilerler.
## Yılanlar gerçek yılan modeli (make_snake); zeminde çatlak ve fırlayan toprak topakları.
static func sen_ei_ranjashu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	pj.busy(c, 0.7)
	_decal(pj, 5.0, pj.gp(c.global_position + d * 2.0), 4.0, 0.2, 1.4, 0.8, {"c1": Color(0.16, 0.13, 0.1), "nf": 3.0})
	var hits = {}
	for wave in 3:
		for k in 7:
			var ang = deg_to_rad(-26.0 + 52.0 * float(k) / 6.0 + randf_range(-4, 4))
			var dist = 6.0 + wave * 7.0 + randf_range(-1.5, 1.5)
			var g = pj.gp(c.global_position + d.rotated(UP, ang) * dist)
			pj.after(0.1 + wave * 0.22 + k * 0.02, func():
				var head = pj.make_snake(g - UP * 1.0, SNAKE_W.lerp(Color(0.8, 0.8, 0.84), randf()), 0.75, 9)
				var top = g + UP * randf_range(3.5, 5.5) + d * 1.5
				var land = g + d * 4.5 - UP * 1.2
				_dust(pj, g, 0.75, Color(0.74, 0.68, 0.56), 6)
				_decal(pj, 5.0, g, 0.9, 0.1, 1.2, 0.6, {"c1": Color(0.16, 0.13, 0.1), "nf": 3.0})
				var bx = BoxMesh.new()
				bx.size = Vector3(0.12, 0.1, 0.12)
				_spray(pj, g + UP * 0.2, {"n": 6, "life": 0.7, "col": Color(0.42, 0.36, 0.3), "mesh": bx, "dir": UP, "spread": 35.0, "v0": 3.0, "v1": 6.0, "spin": 8.0, "s0": 0.6, "s1": 1.1, "r": 0.3})
				pj.slither(head, g - UP * 1.0, top, 0.22, 0.3, func():
					pj.slither(head, top, land, 0.3, 0.3))
				for e in pj.enemies_near(c, g, 2.6):
					if not hits.has(e):
						hits[e] = true
						_venom(pj, c, e, "sen_ei_ranjashu", 0.55, 4.0)
						pj.st(e, "slow", 4.0)
						pj.hit(c, e.global_position + UP, e.radius + 0.4, pj.inf(c, "sen_ei_ranjashu", 0.25, {"knock": 3.0, "launch": 7.0, "kind": "heavy"}))
				pj.fade_free(head, 0.9, 0.2))
	pj.shake(0.4)
	Sfx.play("earth", c.global_position, 0.8)


# ================================================================== Mandara no Jin
## Ref (Orochimaru): ağızdan kahverengi yılan seli — on altı yılan (gerçek yılan modeli) yelpaze gibi yere dökülüp ileri
## akar; ağızda kıvranan yavru yılan fışkırması; geçtiği yolda üst üste kıvranan yılan halısı kalır, yavaşça söner.
static func mandara_no_jin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	pj.busy(c, 1.6)
	var mouth = Jutsu._mouth(c)
	pj.shake(0.6)
	Sfx.play("roar", mouth, 0.6)
	var cap = CapsuleMesh.new()
	cap.radius = 0.05
	cap.height = 0.45
	cap.radial_segments = 6
	cap.rings = 2
	_spray(pj, mouth + d * 0.4, {"n": 26, "life": 0.6, "col": Color(0.4, 0.3, 0.2), "mesh": cap, "dir": d, "spread": 30.0, "v0": 4.0, "v1": 11.0, "grav": 9.0, "spin": 10.0, "s0": 0.7, "s1": 1.2, "align": true, "r": 0.2})
	var hits = {}
	for k in 16:
		var ang = deg_to_rad(-35.0 + 70.0 * float(k) / 15.0)
		var dd = d.rotated(UP, ang)
		var start = mouth + dd * 0.8
		var g0 = pj.gp(c.global_position + dd * 3.0) + UP * 0.5
		var end_ = pj.gp(c.global_position + dd * randf_range(30.0, 38.0)) + UP * 0.5
		pj.after(k * 0.04, func():
			var head = pj.make_snake(start, Color(0.45, 0.34, 0.22).lerp(Color(0.33, 0.25, 0.16), randf()), 0.8, 12)
			pj.slither(head, start, g0, 0.12, 0.2, func():
				pj.slither(head, g0, end_, 1.4, 2.2))
			pj.every(1.6, 0.1, func(_i, _k):
				if not is_instance_valid(head):
					return
				for e in pj.enemies_near(c, head.global_position, 2.4):
					if not hits.has(e):
						hits[e] = true
						_venom(pj, c, e, "mandara_no_jin", 0.7, 5.0)
						pj.st(e, "slow", 5.0)
					if pj.live(e):
						e.global_position = pj.gp(e.global_position + dd * 0.6), Callable())
			pj.fade_free(head, 1.8, 0.3))
	for k in 10:
		pj.after(0.2 + k * 0.12, func():
			_snake_carpet(pj, pj.gp(c.global_position + d * (4.0 + k * 3.2)), d, 3))


## Yerde kıvranan küçük yılanlar (cel tüp + kontur): S kıvrımıyla süzülür, kıvrılır, kaybolur
static func _snakelet_mesh(v: int) -> ArrayMesh:
	var key = "mesh:snakelet%d" % v
	if _cache.has(key):
		return _cache[key]
	var pts: Array = []
	var rads: Array = []
	var n = 16
	var ph = v * 1.3
	for i in n:
		var u = float(i) / float(n - 1)
		pts.append(Vector3(sin(u * TAU * 1.2 + ph) * 0.18, 0.06, -0.8 + u * 1.7))
		rads.append(lerpf(0.075, 0.012, u) if u > 0.08 else 0.085)
	var back = Color(0.44, 0.33, 0.21)
	var belly = Color(0.8, 0.72, 0.52)
	var col_fn = func(u: float, dn: Vector3) -> Color:
		if dn.y < -0.35:
			return belly
		return back.darkened(0.25) if fposmod(u * 18.0, 1.0) < 0.22 else back
	var arr = _tube(pts, rads, 7, col_fn)
	var mesh = _mesh([arr])
	_cache[key] = mesh
	return mesh


static func _snake_carpet(pj: PathJutsu, at: Vector3, d: Vector3, n: int) -> void:
	for i in n:
		var sn = _cel(_snakelet_mesh(randi() % 4), 0.018, {"seed": randf() * 5.0, "nf": 2.5})
		var p = at + d.cross(UP).normalized() * randf_range(-1.6, 1.6) + d * randf_range(-1.0, 1.0)
		_add(pj, sn, p)
		sn.rotation.y = atan2(-d.x, -d.z) + randf_range(-0.9, 0.9)
		sn.scale = Vector3.ONE * randf_range(1.1, 1.6)
		var tw = sn.create_tween().set_parallel(true)
		tw.tween_property(sn, "global_position", p + d * randf_range(0.8, 1.8), 2.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(sn, "rotation:y", sn.rotation.y + randf_range(-0.8, 0.8), 2.2)
		var ft = _tp(sn, "alpha", 1.0, 0.0, 0.6, 1.8 + randf() * 0.6)
		ft.tween_callback(sn.queue_free)


# ================================================================== Chakura no Mesu
## Ref (Kabuto): parmaklardan öne alev gibi titreşen açık mavi chakra bıçağı + ön kolu saran ince alev, içinde parlak
## ince çekirdek; uçtan seyrek mavi kıvılcım. Yakındaki düşmanın kası kesildiğinde (yavaşlama) üstünde ince mavi kesik.
static func chakura_no_mesu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.anim(c, "cast", 1.4)
	var blades = []
	for right in [true, false]:
		var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
		if ba == null:
			continue
		ba.add_child(_flame_blade(Vector3(0, 0.05, 0.02), Vector3(0, 0.42, 0.03), 0.11, 5.0, 0.0, 0.9))
		ba.add_child(_flame_blade(Vector3(0, 0.06, 0.02), Vector3(0, 0.34, 0.03), 0.016, 6.0, 0.0, 1.0))
		_spray(pj, Vector3.ZERO, {"one_shot": false, "n": 6, "life": 0.35, "col": SCALPEL_W, "dir": UP, "spread": 25.0, "v0": 0.4, "v1": 1.2, "grav": -1.0, "s0": 0.015, "s1": 0.03, "r": 0.05, "parent": ba, "off": Vector3(0, 0.36, 0.03)})
		blades.append(ba)
		var fa = pj.bone_attach(c, "RightLowerArm" if right else "LeftLowerArm")
		if fa:
			fa.add_child(_flame_blade(Vector3(0, 0.0, 0.0), Vector3(0, 0.26, 0.0), 0.13, 5.0, 2.0, 0.45))
			blades.append(fa)
	Sfx.play("chidori", c.global_position, 2.0, 0.3)
	if c is Player:
		Buffs.add("chakura_no_mesu", 12.0, {"melee": 1.25, "_name": "Chakra Neşteri", "_desc": "vurduğun düşman yavaşlar (kas kesildi)"})
	pj.every(12.0, 0.25, func(_i, _k):
		for e in pj.enemies_near(c, c.global_position, 2.2):
			if randf() < 0.25:
				pj.st(e, "slow", 2.0)
				_slash(pj, e.global_position + UP * _h(e) * 0.5, _flatv(e.global_position - c.global_position), -40.0, 40.0, 0.35, SCALPEL_W, SCALPEL, 0.06, randf_range(-50.0, 50.0), 0.18), func():
		for ba in blades:
			if is_instance_valid(ba):
				ba.queue_free())


## Kemiğe bağlı titreşen alev bıçağı (çapraz çift şerit)
static func _flame_blade(a: Vector3, b: Vector3, w: float, pat: float, seed: float, alpha: float) -> MeshInstance3D:
	var pts: Array = []
	var ws: Array = []
	for i in 6:
		pts.append(a.lerp(b, i / 5.0))
		ws.append(w)
	var mi = _mi(_mesh([_ribbon(pts, ws)]), _ribbon_mat())
	_params(mi, {"pat": pat, "c1": SCALPEL_W, "c2": SCALPEL, "alpha": alpha, "seed": seed + randf() * 4.0, "nf": 0.9})
	return mi


# ================================================================== Sōzō Saisei
## Ref (Tsunade): alındaki Byakugō elması parlar, mühür çizgileri yüze/bedene yayılır (gerçek ten shader'ı), bedenin
## çevresinde kızıl-turuncu ışık konturu atar; yaralar buharlaşarak kapanır — 10 sn boyunca bedenin farklı yerlerinden
## kıvrılarak yükselen beyaz yenilenme buharı (ilk saniyelerde yoğun).
static func sozo_saisei(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 0.9)
	var m = c.get("model")
	var parts = []
	var bm = m.get("body_mesh") if m else null
	var smat = bm.get_surface_override_material(0) if bm else null
	var fmat = m.get("face_skin_mat") if m else null
	if fmat is ShaderMaterial:
		fmat.set_shader_parameter("seal_marks", 1.0)
		pj.after(10.0, func():
			if is_instance_valid(fmat):
				fmat.set_shader_parameter("seal_marks", 0.0))
	if smat is ShaderMaterial:
		smat.set_shader_parameter("sage_marks", 4)
		pj.after(10.0, func():
			if is_instance_valid(smat) and int(smat.get_shader_parameter("sage_marks")) == 4:
				smat.set_shader_parameter("sage_marks", 0))
	# Byakugō elması: alında çakar, sonra küçük kalır
	var dia = _flat(10.0, Vector2(0.14, 0.14), {"c1": Color(0.78, 0.45, 0.95), "c2": Color(0.35, 0.12, 0.5), "prog": 1.0, "nf": 0.5}, 1.0)
	_add(pj, dia, c.global_position + UP * 1.7)
	parts.append(dia)
	pj.every(10.0, 1.0 / 30.0, func(_i, k):
		if not is_instance_valid(dia) or not pj.live(c):
			return
		dia.global_position = _bone(c, "Head", UP * 1.62) + _fdir(c) * 0.12 + UP * 0.1
		var fl = 1.0 + 3.0 * maxf(0.0, 1.0 - k * 10.0 / 0.6)
		dia.scale = Vector3(0.14 * fl, 0.14 * fl, 1.0))
	# kızıl-turuncu ışık konturu (iki atım)
	_ghost(pj, c, Color(1.0, 0.45, 0.2), 0.7, 0.45, [Vector3.ZERO], false, 1.05)
	pj.after(0.35, func():
		if pj.live(c):
			_ghost(pj, c, Color(1.0, 0.6, 0.25), 0.55, 0.5, [Vector3.ZERO], false, 1.08))
	_light(pj, c.global_position + UP * 1.2, Color(1.0, 0.55, 0.3), 2.0, 5.0, 0.8)
	Sfx.play("heal", c.global_position, 0.8)
	pj.heal(c, c.max_hp)
	if c is Player:
		Buffs.add("sozo_saisei", 10.0, {"armor": 0.92, "_name": "Yaradılış Yenilenmesi", "_desc": "tam iyileşme + 10 sn her sn canın %2'si yenilenir (ömürden yer)"})
	pj.every(10.0, 1.0, func(_i, _k):
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.02), func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free())
	var bones = ["UpperChest", "Hips", "Neck", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"]
	pj.every(10.0, 0.25, func(i, _k):
		if not pj.live(c):
			return
		var n = 3 if i < 6 else 1
		for j in n:
			var bp = _bone(c, bones[randi() % bones.size()], UP * randf_range(0.4, 1.5)) + Vector3(randf_range(-0.12, 0.12), 0.0, randf_range(-0.12, 0.12))
			_steam(pj, bp))


## Kıvrılarak yükselen beyaz buhar şeridi
static func _steam(pj: PathJutsu, at: Vector3) -> void:
	var pts: Array = []
	var ws: Array = []
	var hgt = randf_range(0.5, 0.9)
	for i in 6:
		var u = i / 5.0
		pts.append(at + UP * u * hgt + Vector3(sin(u * 4.0 + randf()) * 0.06, 0.0, cos(u * 3.0) * 0.06))
		ws.append(0.22)
	var mi = _ribbon_node(pj, pts, ws, {"pat": 4.0, "c1": Color(1.0, 1.0, 1.0), "seed": randf() * 10.0, "nf": 1.4, "alpha": 0.0})
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position", UP * 0.5, 1.2).as_relative().set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("alpha", sin(v * PI)), 0.0, 1.0, 1.2)
	tw.chain().tween_callback(mi.queue_free)


# ================================================================== Shikon no Jutsu
## Ref: canlandırılan cesedin gözleri bembeyaz, bakışı boş. Kullanıcının elinden yere soluk yeşil can ipliği uzanır,
## zemin mezar gibi çatlar, toprak topakları fırlar, ceset yerden ağır ağır doğrulur; gözlerinde beyaz ölü bakışı.
static func shikon_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at = pj.gp(c.global_position + pj.fwd(c, t) * 3.0)
	_decal(pj, 5.0, at, 1.5, 0.4, 2.0, 1.0, {"c1": Color(0.14, 0.11, 0.08), "nf": 3.0})
	var a_fn = func() -> Vector3:
		return pj.hand_pos(c, true) if pj.live(c) else Vector3.ZERO
	var b_fn = func() -> Vector3:
		return at + UP * 0.1
	var bend = func(u: float, tt: float, _a: Vector3, _b: Vector3) -> Vector3:
		return UP * sin(u * PI) * 0.5 + Vector3(0, sin(u * 12.0 - tt * 20.0) * 0.05, 0)
	_strand(pj, {"pat": 3.0, "c1": Color(0.85, 1.0, 0.85), "c2": Color(0.4, 0.62, 0.45), "nf": 1.2}, a_fn, b_fn, 0.55, 0.05, 10, bend)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var d = ShadowClone.new()
		d.team = c.team
		var lk = CharacterModel.default_look()
		lk.merge({"skin": Color(0.72, 0.74, 0.7), "top": Color(0.35, 0.33, 0.3), "top2": Color(0.3, 0.28, 0.26), "pants": Color(0.25, 0.24, 0.22),
			"hair": Color(0.3, 0.3, 0.3), "face_mark": "kırışık", "band_style": "slashed"}, true)
		d.look = lk
		d.life = 20.0
		pj.get_tree().current_scene.add_child(d)
		d.global_position = at
		d.max_hp = 1.0
		var dm = d.get("model")
		if dm:
			dm.position.y = -1.6
			dm.create_tween().tween_property(dm, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
		var bx = BoxMesh.new()
		bx.size = Vector3(0.14, 0.11, 0.13)
		_spray(pj, at + UP * 0.2, {"n": 16, "life": 0.9, "col": Color(0.3, 0.24, 0.18), "mesh": bx, "dir": UP, "spread": 55.0, "v0": 2.5, "v1": 5.5, "spin": 9.0, "s0": 0.6, "s1": 1.2, "r": 0.5})
		_dust(pj, at, 0.8, Color(0.5, 0.44, 0.36), 6)
		_dead_eyes(pj, d)
		Combat.popup_text(at + UP * 2.4, "Ceset kalktı!", Color(0.6, 0.85, 0.6)))


## Cesedin gözlerinde beyaz ölü bakışı (baş kemiğini izler, ceset yaşadıkça)
static func _dead_eyes(pj: PathJutsu, d: Node3D) -> void:
	var eyes: Array = []
	for sx in [-1.0, 1.0]:
		var e = _flat(12.0, Vector2(0.06, 0.06), {"c1": Color(0.97, 0.97, 0.95), "c2": Color(0.3, 0.3, 0.32), "nf": 0.4}, 1.0)
		_add(pj, e, d.global_position + UP * 1.6)
		eyes.append(e)
	pj.every(20.0, 1.0 / 20.0, func(_i, _k):
		if not is_instance_valid(d) or (d.has_method("is_dead") and d.is_dead()):
			for e in eyes:
				if is_instance_valid(e):
					e.queue_free()
			return
		var f = _fdir(d)
		var sd = f.cross(UP).normalized()
		var hp = _bone(d, "Head", UP * 1.6) + f * 0.11 + UP * 0.06
		for i in eyes.size():
			if is_instance_valid(eyes[i]):
				eyes[i].global_position = hp + sd * (0.035 if i == 0 else -0.035), func():
		for e in eyes:
			if is_instance_valid(e):
				e.queue_free())


# ================================================================== Saikan Chūshutsu no Jutsu
## Ref (Sakura): avuçtaki su kabarcığı bedenden koyu mor zehri çeker — bedenden kabarcığa kıvranan mor iplikler,
## kabarcığın içinde zehir çekirdeği büyür; sonra kirli su yere dökülür, mor damlalar ve yerde mor leke.
static func saikan_chushutsu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	pj.anim(c, "cast", 1.0)
	var orb = _mi(_sphere(), _orb_mat())
	_params(orb, {"kind": 1.0, "c1": Color(0.55, 0.85, 0.95), "c2": Color(0.3, 0.65, 0.85), "c3": Color(0.08, 0.25, 0.4), "nf": 0.8})
	pj.get_tree().current_scene.add_child(orb)
	orb.global_position = pj.hand_pos(c, true) + UP * 0.15
	var core = _mi(_sphere(), _cel_mat())
	_params(core, {"tint": Color(0.3, 0.08, 0.38), "nf": 0.6})
	orb.add_child(core)
	core.scale = Vector3.ONE * 0.05
	for k in 3:
		var bone = ["UpperChest", "Hips", "LeftLowerArm"][k]
		var a_fn = func() -> Vector3:
			return _bone(c, bone, UP) if pj.live(c) else Vector3.ZERO
		var b_fn = func() -> Vector3:
			return orb.global_position if is_instance_valid(orb) else Vector3.ZERO
		var bend = func(u: float, tt: float, _a: Vector3, _b: Vector3) -> Vector3:
			return Vector3(sin(u * 9.0 + tt * 14.0 + k) * 0.04, sin(u * PI) * 0.12, cos(u * 7.0 - tt * 11.0) * 0.04)
		_strand(pj, {"pat": 3.0, "c1": Color(0.5, 0.2, 0.62), "c2": VENOM_D, "seed": k * 2.0, "nf": 0.8}, a_fn, b_fn, 1.1, 0.035, 10, bend)
	pj.every(1.1, 1.0 / 30.0, func(_i, k):
		if is_instance_valid(orb) and pj.live(c):
			orb.global_position = pj.hand_pos(c, true) + UP * 0.15
			orb.scale = Vector3.ONE * 0.44 * (0.6 + k * 0.8)
			core.scale = Vector3.ONE * (0.1 + k * 0.6) * Vector3(1.0 + sin(k * 20.0) * 0.12, 1.0, 1.0 - sin(k * 20.0) * 0.12), func():
		if is_instance_valid(orb):
			var p = orb.global_position
			_spray(pj, p, {"n": 20, "life": 0.6, "col": Color(0.3, 0.08, 0.38), "dir": Vector3.DOWN, "spread": 40.0, "v0": 1.0, "v1": 2.5, "grav": 9.0, "s0": 0.05, "s1": 0.1, "r": 0.1})
			_spray(pj, p, {"n": 10, "life": 0.5, "col": Color(0.6, 0.85, 0.95), "dir": Vector3.DOWN, "spread": 60.0, "v0": 0.8, "v1": 2.0, "grav": 9.0, "s0": 0.03, "s1": 0.06, "r": 0.1})
			_decal(pj, 6.0, pj.gp(p), 0.55, 0.3, 2.0, 1.0, {"c1": Color(0.3, 0.1, 0.36), "c2": Color(0.18, 0.05, 0.22), "nf": 2.0})
			orb.queue_free()
		if pj.live(c):
			for s in ["poison", "slow", "bind", "stun", "burn"]:
				if c.has_method("clear_status"):
					c.clear_status(s)
				elif "statuses" in c:
					c.statuses.erase(s)
			pj.heal(c, c.max_hp * 0.25)
			Combat.popup_text(c.global_position + UP * 2.6, "Zehir çekildi", MEDC))


# ================================================================== Dokugiri
## Ref: ağızdan koyu mor, yoğun zehir bulutu fışkırır (cel bulut: düz ton, koyu kontur). 7 sn boyunca hedef bölgede
## yere çöken mor sis kalır (alçak kıvrılan bulutçuklar + yerde mor leke); içindekiler yavaşlar ve zehir alır.
static func dokugiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d = pj.fwd(c, t)
	var center = pj.gp(c.global_position + d * 6.0)
	var mouth = pj._mouth_pos(c)
	var mist = [Color(0.6, 0.38, 0.72), Color(0.42, 0.24, 0.55), Color(0.2, 0.1, 0.28)]
	Sfx.play("wind", c.global_position, 0.6)
	for k in 5:
		pj.after(k * 0.08, func():
			if not is_instance_valid(c):
				return
			for j in 4:
				var jit = Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.25), randf_range(-0.3, 0.3)) * (1.0 + k * 0.4)
				var p0 = mouth + d * (0.5 + k * 0.6) + jit
				var vel = (d * randf_range(3.5, 5.5) + Vector3.DOWN * 0.5 + jit)
				_puff(pj, p0, 0.5 + k * 0.22 + randf() * 0.2, vel, randf_range(1.1, 1.5), mist, 0.92, 2.4, 2.5))
	_decal(pj, 6.0, center, 5.0, 0.8, 5.6, 1.2, {"c1": Color(0.4, 0.22, 0.48), "c2": Color(0.26, 0.12, 0.32), "alpha": 0.45, "nf": 3.0})
	pj.every(7.0, 0.5, func(_i, _k):
		for j in 2:
			var a = randf() * TAU
			var p = center + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 4.0) + UP * randf_range(0.3, 0.9)
			_puff(pj, p, randf_range(1.2, 1.9), Vector3(randf_range(-0.4, 0.4), 0.15, randf_range(-0.4, 0.4)), 1.4, mist, 0.6, 1.4, 3.0)
		for e in pj.enemies_near(c, center, 5.0):
			pj.st(e, "slow", 1.0)
			e.take_hit(pj.inf(c, "dokugiri", 0.12, {"knock": 0.0, "kind": "light", "element": ""})), Callable())


# ================================================================== In'yu Shōmetsu
## Hücre bölünmesiyle onarım (kaynak yok, kendi tasarım): avuçlarda yeşil şifa ışığı toplanır; 15 sn boyunca bedenin
## üstünde ikiye bölünen yeşil hücre zarları belirip söner, ilk saniyelerde bedenden yükselen yeşil şifa zerreleri.
static func in_yu_shometsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.anim(c, "cast", 1.2)
	var palms: Array = []
	for right in [true, false]:
		var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
		if ba == null:
			continue
		var g = _mi(_sphere(), _orb_mat())
		_params(g, {"kind": 3.0, "c1": MEDW, "c2": MEDC, "nf": 0.8})
		g.position = Vector3(0, 0.09, 0.03)
		g.scale = Vector3.ONE * 0.05
		ba.add_child(g)
		var tw = g.create_tween()
		tw.tween_property(g, "scale", Vector3.ONE * 0.26, 0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_property(g, "scale", Vector3.ONE * 0.2, 0.4)
		tw.tween_interval(2.0)
		tw.tween_property(g, "scale", Vector3.ONE * 0.02, 0.3)
		palms.append(ba)
	var motes = _spray(pj, Vector3.ZERO, {"one_shot": false, "n": 14, "life": 1.0, "col": MEDC, "dir": UP, "spread": 15.0, "v0": 0.3, "v1": 0.9, "grav": -0.6, "s0": 0.03, "s1": 0.06, "r": 0.3, "parent": c, "off": UP * 1.0})
	pj.after(3.0, func():
		if is_instance_valid(motes):
			motes.emitting = false
		for ba in palms:
			if is_instance_valid(ba):
				ba.queue_free())
	pj.free_after(4.5, motes)
	if c is Player:
		Buffs.add("in_yu_shometsu", 15.0, {"_name": "Hücre Yenileme", "_desc": "her sn canın %4'ü yenilenir"})
	var bones = ["UpperChest", "Hips", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Neck"]
	pj.every(15.0, 1.0, func(_i, _k):
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.04)
			for j in 3:
				var bp = _bone(c, bones[randi() % bones.size()], UP) + Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), randf_range(-0.15, 0.15))
				var s = randf_range(0.16, 0.26)
				var cell = _pop(pj, 11.0, bp, Vector2(s, s), 0.7, 0.1, 0.3, {"c1": Color(0.6, 1.0, 0.7), "c2": Color(0.2, 0.7, 0.4), "nf": 0.8}, 1.0)
				cell.create_tween().tween_property(cell, "global_position", UP * 0.15, 1.1).as_relative(), Callable())
