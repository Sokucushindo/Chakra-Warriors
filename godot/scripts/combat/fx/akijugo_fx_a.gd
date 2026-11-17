class_name AkijugoFXA
extends RefCounted
## Akimichi + Jūgo klan grubu A: on dokuz tekniğin görselleri, hepsi bu dosyada sıfırdan (kendi gölgelendiricileri, kendi ağları).
## Beden değiştiren teknikler GERÇEK kemiği büyütür / kalınlaştırır (ClanJutsu._aki_arm → PoseOverlay.grow / fist,
## PathJutsu._jugo_piston ve PoseOverlay.bulk, PlayerModes.set_size); kemiğe iliştirilen her parça bu büyümeyi miras alır.
##   Akimichi: anime ref — mavi chakra kurdeleleri (Baika), kıyafet renginde taranmış top + yere saçılan cel toz dikenleri
##             (Nikudan Sensha), iple sarılı kunailer + oluk / kıvılcım (Hari Sensha), kara gölge ipi (Yōyō), içinde koyu mavi alev
##             lekeleri akan camgöbeği chakra kelebek kanatları (Chō Mōdo), yumruğu saran mavi chakra alevleri (Chōdan Bakugeki),
##             turuncu kalori buharı + yanak sarmalları (Karorī Kontorōru), mavi chakra pusuyla açık avuç (Chōharite).
##   Jūgo: Senninka gri-turuncu ten + kara lanet izleri (lekeler bedende yayılır), sırttan çıkan etten jet boruları ve itki alevi,
##         ön kol jet delikleri, et balta, et top namlusu, etten jet kanatlar, ezici darbe karesi (yıldız + yönlü dalga + kaya).
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki işleyicilerden satır satır taşındı.

static var _cache := {}

const UP := Vector3.UP
const AKI_BLUE := Color(0.45, 0.8, 1.0)
const AKI_DEEP := Color(0.13, 0.38, 0.95)
const SAGE_SKIN := Color(0.66, 0.56, 0.47)
const SAGE_SKIN2 := Color(0.5, 0.45, 0.43)
const NATURE_O := Color(1.0, 0.6, 0.22)
const INK_D := Color(0.07, 0.05, 0.06)
const DUST := Color(0.86, 0.76, 0.6)
const GND := Color(0.52, 0.42, 0.31)

# ================================================================== gölgelendiriciler
const NOISE := """
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnz(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

## Kameraya dönük kart; kameraya yaklaşınca küçülür (ekranı kaplamasın)
const BBV := """
	float s_x = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float d_cam = length((VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz);
	VERTEX *= s_x * clamp(d_cam / 6.0, 0.3, 1.0);
"""

## Köşe renkli toon (kaya, kunai, ip, yanak sarmalı)
const CEL_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
instance uniform vec4 k_tint = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	ALBEDO = COLOR.rgb * k_tint.rgb;
}
"""

## Koyu kontur (ters kabuk)
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float ow = 0.02;
uniform vec4 ocol : source_color = vec4(0.06, 0.04, 0.05, 1.0);
void vertex() {
	VERTEX += NORMAL * ow;
}
void fragment() {
	ALBEDO = ocol.rgb;
}
"""

## Akimichi topu: kıyafet renginde toon küre, iki zikzak bant halinde koyu kısa tarama çizgileri (ref), bir yüzünde sivri saç tutamı
const BALL_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
instance uniform vec4 k_base = vec4(0.55, 0.18, 0.2, 1.0);
instance uniform vec4 k_hair = vec4(0.14, 0.09, 0.06, 1.0);
varying vec3 opos;
NOISE
void vertex() {
	opos = VERTEX;
}
void fragment() {
	vec3 p = normalize(opos);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float lon = atan(p.z, p.x);
	float zz = abs(fract(lon * 0.95493) - 0.5);
	float cell = floor(lon * 70.0);
	float strokes = step(0.45, fract(lon * 70.0)) * step(0.25, hsh(vec2(cell, 3.0)));
	float b1 = abs(lat - (0.18 + zz * 0.5));
	float b2 = abs(lat - (-0.42 + zz * 0.35));
	float len1 = 0.11 + 0.08 * hsh(vec2(cell, 7.0));
	float len2 = 0.08 + 0.06 * hsh(vec2(cell, 11.0));
	float hatch = max(step(b1, len1), step(b2, len2)) * strokes;
	vec3 col = mix(k_base.rgb, k_base.rgb * 0.32, hatch * 0.9);
	float jag = 0.18 * vnz(vec2(lon * 9.0, 1.0)) + 0.1 * abs(fract(lon * 4.0) - 0.5);
	float hair = step(p.z, -0.62 + jag);
	col = mix(col, k_hair.rgb, hair);
	ALBEDO = col;
}
"""

## Chō Mōdo kanadı: camgöbeği yarı saydam chakra, içinde uca doğru akan koyu mavi alev lekeleri, mor gölge, parlak tırtıklı kenar, kıvılcım
const WING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
NOISE
void fragment() {
	float along = UV.x;
	float acr = abs(UV.y * 2.0 - 1.0);
	float rag = 0.1 * vnz(vec2(along * 26.0 + TIME * 1.5, k_seed));
	if (acr > 1.0 - rag) {
		discard;
	}
	float n1 = vnz(vec2(along * 5.0 - TIME * 1.1, UV.y * 6.0 + k_seed));
	float n2 = vnz(vec2(along * 11.0 - TIME * 1.9, UV.y * 14.0 + k_seed * 2.0));
	float streak = smoothstep(0.56, 0.7, n1 * 0.68 + n2 * 0.32);
	vec3 base = mix(vec3(0.5, 0.86, 1.0), vec3(0.78, 0.97, 1.0), along * 0.7);
	vec3 col = mix(base, vec3(0.1, 0.32, 0.92), streak * 0.88);
	col = mix(col, vec3(0.47, 0.4, 0.95), smoothstep(0.66, 0.84, vnz(vec2(along * 3.0 + k_seed, UV.y * 4.0 + TIME * 0.25))) * 0.55);
	float rim = smoothstep(0.8, 0.97, acr + rag);
	col = mix(col, vec3(0.9, 1.0, 1.0), rim);
	float sp = step(0.988, hsh(floor(vec2(along * 70.0, UV.y * 35.0)) + floor(TIME * 7.0) * 0.173));
	col = mix(col, vec3(1.0), sp);
	float root = smoothstep(0.0, 0.1, along);
	ALBEDO = col;
	ALPHA = clamp(k_a * (0.5 + 0.38 * rim + 0.12 * streak + sp) * root, 0.0, 1.0) * smoothstep(0.6, 2.4, length(VERTEX));
}
"""

## Chakra kurdele (k_mode 0) / alev dili (k_mode 1): UV.x boyunca (0 kök → 1 uç), UV.y enine
const WISP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.55, 0.85, 1.0, 1.0);
instance uniform vec4 k_deep = vec4(0.15, 0.4, 0.95, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_mode = 0.0;
instance uniform float k_seed = 0.0;
NOISE
void fragment() {
	float L = UV.x;
	float acr = abs(UV.y * 2.0 - 1.0);
	vec3 col = k_col.rgb;
	float a = 1.0;
	if (k_mode < 0.5) {
		float ends = smoothstep(0.0, 0.12, L) * (1.0 - smoothstep(0.78, 1.0, L));
		float n = vnz(vec2(L * 12.0 - TIME * 3.0, k_seed + UV.y * 2.0));
		float body = 1.0 - smoothstep(0.5, 1.0, acr);
		col = mix(k_col.rgb, vec3(0.93, 1.0, 1.0), smoothstep(0.6, 0.95, n) * (1.0 - acr));
		col = mix(col, k_deep.rgb, smoothstep(0.62, 0.95, acr));
		a = body * ends * (0.6 + 0.35 * n);
	} else {
		float n = vnz(vec2(L * 5.0 - TIME * 6.0, UV.y * 3.0 + k_seed));
		float wid = pow(max(1.0 - L, 0.0), 0.7) * (0.55 + 0.55 * n);
		if (acr > wid) {
			discard;
		}
		float core = 1.0 - acr / max(wid, 0.001);
		col = mix(k_deep.rgb, k_col.rgb, smoothstep(0.1, 0.6, core));
		col = mix(col, vec3(0.92, 1.0, 1.0), smoothstep(0.75, 1.0, core) * (1.0 - L));
		float lick = smoothstep(0.55, 0.75, vnz(vec2(L * 9.0 - TIME * 8.0, UV.y * 8.0 + k_seed)));
		col = mix(col, k_deep.rgb * 0.8, lick * 0.6);
		a = 0.88;
	}
	ALBEDO = col;
	ALPHA = clamp(a * k_a, 0.0, 1.0) * smoothstep(0.6, 2.4, length(VERTEX));
}
"""

## Kart: 0 cel toz (loblu, iki ton, koyu kenar, kenardan yenilerek dağılır), 1 buhar (yumuşak kıvrımlı), 2 parıltı (dört uçlu)
const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.86, 0.76, 0.6, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
instance uniform float k_mode = 0.0;
NOISE
void vertex() {
//BB
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 col = k_col.rgb;
	float a = 1.0;
	if (k_mode < 0.5) {
		float edge = 0.74 + 0.14 * vnz(vec2(ang * 1.6 + k_seed, k_seed)) + 0.07 * sin(ang * 6.0 + k_seed * 3.0);
		if (r > edge) {
			discard;
		}
		float eat = vnz(p * 2.6 + vec2(k_seed * 7.0, 0.0));
		if (eat > k_a * 1.15 + (1.0 - r / edge) * 0.3 - 0.15) {
			discard;
		}
		float lit = step(0.05, dot(p, vec2(0.35, 0.8)) + (eat - 0.5) * 0.4);
		col = mix(k_col.rgb * 0.72, k_col.rgb, lit);
		col = mix(col, k_col.rgb * 0.45, step(edge - 0.08, r));
	} else if (k_mode < 1.5) {
		float n = vnz(vec2(ang * 1.2 + k_seed, r * 3.0 - TIME * 1.5));
		float edge = 0.5 + 0.4 * n;
		float soft = 1.0 - smoothstep(edge * 0.55, edge, r);
		a = soft * (0.5 + 0.5 * vnz(p * 4.0 + vec2(0.0, TIME * 2.0) + k_seed)) * k_a;
		col = mix(k_col.rgb, vec3(1.0, 0.95, 0.82), (1.0 - r) * 0.45);
		if (a < 0.03) {
			discard;
		}
	} else {
		float st = max(1.0 - abs(p.x) * 7.0 - abs(p.y) * 0.9, 1.0 - abs(p.y) * 7.0 - abs(p.x) * 0.9);
		st = max(st, 1.0 - r * 2.4);
		if (st <= 0.0) {
			discard;
		}
		a = clamp(st * 1.6, 0.0, 1.0) * k_a;
		col = mix(k_col.rgb, vec3(1.0), clamp(st, 0.0, 1.0));
	}
	ALBEDO = col;
	ALPHA = clamp(a * k_col.a, 0.0, 1.0) * smoothstep(0.6, 2.4, length(VERTEX));
}
"""

## Zemin izi: 0 krater + ışınsal çatlak, 1 yuvarlanma oluğu (yerel z boyunca), 2 göçük (yumruk / ayak izi),
## 3 genişleyen keskin halka dalgası, 4 önde yarım daire basınç süpürmesi, 5 kunai oyukları (paralel tırtıklı çizikler)
const DECAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(0.08, 0.06, 0.05, 1.0);
instance uniform vec4 k_gnd = vec4(0.52, 0.42, 0.31, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_mode = 0.0;
instance uniform float k_seed = 0.0;
NOISE
float crk(vec2 p, float n, float sd, float wid, float reach) {
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 * n;
	float id = floor(a);
	float wob = (vnz(vec2(r * 5.0 + sd, id * 2.3 + sd)) - 0.5) * 0.6;
	float f = abs(fract(a + wob) - 0.5) * 6.2831853 / n * r;
	float len = reach * (0.55 + 0.45 * hsh(vec2(id, sd)));
	if (r > len) {
		return 0.0;
	}
	float w = wid * (1.0 - r / len) + 0.003;
	return 1.0 - smoothstep(w * 0.5, w, f);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	int md = int(k_mode + 0.5);
	float g = k_grow;
	vec3 col = k_col.rgb;
	float a = 0.0;
	if (md == 0) {
		float bowl = 1.0 - smoothstep(0.26 * g, 0.36 * g, r);
		float lip = smoothstep(0.3 * g, 0.38 * g, r) * (1.0 - smoothstep(0.4 * g, 0.5 * g, r));
		float cc = max(crk(p, 10.0, k_seed, 0.06, g), crk(p * 1.25, 16.0, k_seed + 3.7, 0.03, g * 0.85));
		col = mix(k_gnd.rgb * 0.42, k_gnd.rgb * 0.58, vnz(p * 7.0 + k_seed));
		a = bowl * 0.9;
		col = mix(col, k_gnd.rgb * 1.18, lip);
		a = max(a, lip * 0.85);
		col = mix(col, k_col.rgb, cc);
		a = max(a, cc);
	} else if (md == 1) {
		float x = abs(p.x);
		float rut = 1.0 - smoothstep(0.06, 0.14, abs(x - 0.6));
		float band = 1.0 - smoothstep(0.55, 0.75, x);
		float hatch = step(0.6, fract(p.y * 9.0 + vnz(vec2(p.x * 3.0, k_seed)) * 0.6)) * (1.0 - smoothstep(0.3, 0.55, x));
		col = mix(k_gnd.rgb * 0.84, k_gnd.rgb * 0.62, hatch);
		col = mix(col, k_col.rgb, rut);
		a = max(band * 0.5, rut) * (1.0 - smoothstep(0.7, 1.0, abs(p.y)));
	} else if (md == 2) {
		float e = length(p * vec2(1.0, 0.8)) / max(g, 0.01);
		float sink = 1.0 - smoothstep(0.6, 0.7, e);
		float rim = smoothstep(0.6, 0.7, e) * (1.0 - smoothstep(0.7, 0.85, e));
		float cc = crk(p, 7.0, k_seed, 0.04, g * 0.95) * step(0.6, e);
		col = mix(k_gnd.rgb * 0.5, k_gnd.rgb * 0.68, smoothstep(0.0, 0.6, e));
		a = sink * 0.85;
		col = mix(col, k_col.rgb, rim * 0.8);
		a = max(a, rim * 0.9);
		col = mix(col, k_col.rgb, cc);
		a = max(a, cc);
	} else if (md == 3) {
		float dd = abs(r - g * 0.92);
		a = 1.0 - smoothstep(0.02, 0.05 + 0.05 * (1.0 - g), dd);
		a *= 0.75 + 0.25 * vnz(vec2(atan(p.y, p.x) * 6.0, k_seed));
	} else if (md == 4) {
		float front = smoothstep(0.25, -0.1, p.y);
		float ring = smoothstep(0.2, 0.35, r) * (1.0 - smoothstep(0.85 * g, g, r));
		float ang = atan(p.x, -p.y);
		float strk = step(0.55, vnz(vec2(ang * 9.0, r * 2.0 + k_seed)));
		col = mix(k_gnd.rgb * 0.72, k_col.rgb, strk * 0.7);
		a = front * ring * (0.45 + 0.4 * strk);
	} else {
		float best = 0.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float cx = (fi - 2.0) * 0.32 + (hsh(vec2(fi, k_seed)) - 0.5) * 0.12;
			float wob = (vnz(vec2(p.y * 6.0, fi * 4.0 + k_seed)) - 0.5) * 0.12;
			float w = 0.035 * (1.0 - smoothstep(0.6, 1.0, abs(p.y)));
			best = max(best, 1.0 - smoothstep(w * 0.5, w, abs(p.x - cx - wob)));
		}
		a = best;
	}
	ALBEDO = col;
	ALPHA = clamp(a * k_a, 0.0, 1.0);
}
"""

## Mürekkep parça: diken yelpazesi, darbe yıldızı, yay, hız çizgisi, gölge ipi. UV.x boyunca açılır (k_grow), UV.y enine (kenar koyu)
const INK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 k_col = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 k_edge = vec4(0.08, 0.06, 0.08, 1.0);
instance uniform float k_a = 1.0;
instance uniform float k_grow = 1.0;
instance uniform float k_tail = 0.0;
void vertex() {
//BB
}
void fragment() {
	float age = k_grow - UV.x;
	if (age < 0.0) {
		discard;
	}
	float tail = clamp(1.0 - age * k_tail, 0.0, 1.0);
	float acr = 1.0 - abs(UV.y * 2.0 - 1.0);
	vec3 col = mix(k_edge.rgb, k_col.rgb * COLOR.rgb, smoothstep(0.12, 0.3, acr));
	ALBEDO = col;
	ALPHA = clamp(k_a * COLOR.a * tail, 0.0, 1.0) * smoothstep(0.7, 2.6, length(VERTEX));
}
"""

## Jet itki alevi: ağızda beyaz-sarı çekirdek → turuncu → kızıl, titreşen dil; toplamalı
const FLARE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
instance uniform float k_a = 1.0;
instance uniform float k_seed = 0.0;
NOISE
void fragment() {
	float L = UV.x;
	float acr = abs(UV.y * 2.0 - 1.0);
	float n = vnz(vec2(L * 6.0 - TIME * 14.0, k_seed + UV.y * 3.0));
	float wid = (1.0 - L) * (0.55 + 0.45 * n) + 0.05 * (1.0 - L);
	if (acr > wid) {
		discard;
	}
	float core = 1.0 - acr / max(wid, 0.001);
	vec3 col = mix(vec3(1.0, 0.32, 0.08), vec3(1.0, 0.82, 0.42), smoothstep(0.2, 0.8, core * (1.0 - L * 0.7)));
	col = mix(col, vec3(1.0, 1.0, 0.92), smoothstep(0.75, 1.0, core) * (1.0 - L));
	ALBEDO = col;
	ALPHA = k_a * clamp(core * 1.5, 0.0, 1.0) * (1.0 - L * 0.6) * smoothstep(0.5, 2.0, length(VERTEX));
}
"""

## Senninka teni: gri-turuncu benekli et, kara üçgen lanet izleri; k_cover < 1 iken lekeler halinde yayılır (gerisi atılır)
const SAGE_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
instance uniform vec4 k_skin = vec4(0.66, 0.56, 0.47, 1.0);
instance uniform float k_cover = 1.0;
instance uniform float k_mark = 1.0;
varying vec3 lp;
NOISE
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float blot = vnz(lp.xy * 7.0 + lp.z * 5.0) * 0.6 + vnz(lp.yz * 15.0) * 0.4;
	if (k_cover < 0.99 && blot > k_cover) {
		discard;
	}
	vec3 base = COLOR.rgb * k_skin.rgb;
	base *= 0.86 + 0.24 * vnz(lp.xy * 18.0 + lp.z * 7.0);
	base = mix(base, vec3(0.92, 0.55, 0.26) * 0.8, smoothstep(0.62, 0.8, vnz(lp.yz * 9.0 + 3.0)) * 0.45);
	float m = vnz(vec2(lp.x * 22.0 + lp.z * 13.0, lp.y * 6.0));
	float tri = fract(lp.y * 7.0 + m * 0.8);
	float mk = step(0.7, m) * step(tri, 0.55 * (m - 0.7) / 0.3 + 0.1);
	base = mix(base, vec3(0.03, 0.02, 0.03), mk * k_mark);
	if (k_cover < 0.99) {
		base = mix(base, vec3(0.05, 0.03, 0.03), smoothstep(k_cover - 0.06, k_cover, blot));
	}
	ALBEDO = base;
}
"""


# ================================================================== malzemeler
static func _sh(key0: String, code: String, bb := false) -> ShaderMaterial:
	var key = "sh:" + key0
	if _cache.has(key):
		return _cache[key]
	var s = Shader.new()
	s.code = code.replace("NOISE", NOISE).replace("//BB", BBV if bb else "")
	var m = ShaderMaterial.new()
	m.shader = s
	_cache[key] = m
	return m


static func _line(ow: float) -> ShaderMaterial:
	var key = "line:%.3f" % ow
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = _sh("line_base", LINE_SHADER).shader
	m.set_shader_parameter("ow", ow)
	_cache[key] = m
	return m


static func _with_line(key0: String, code: String, ow: float) -> ShaderMaterial:
	var key = "matl:" + key0
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = _sh(key0, code).shader
	m.next_pass = _line(ow)
	_cache[key] = m
	return m


static func _cel(outline := true) -> ShaderMaterial:
	return _with_line("cel", CEL_SHADER, 0.02) if outline else _sh("cel", CEL_SHADER)


static func _sage(outline := true) -> ShaderMaterial:
	return _with_line("sage", SAGE_SHADER, 0.012) if outline else _sh("sage", SAGE_SHADER)


static func _ball_mat() -> ShaderMaterial:
	return _with_line("ball", BALL_SHADER, 0.05)


static func _wing_mat() -> ShaderMaterial:
	return _sh("wing", WING_SHADER)


static func _wisp_mat() -> ShaderMaterial:
	return _sh("wisp", WISP_SHADER)


static func _puff_mat() -> ShaderMaterial:
	return _sh("puff", PUFF_SHADER, true)


static func _decal_mat() -> ShaderMaterial:
	return _sh("decal", DECAL_SHADER)


static func _ink(bb := false) -> ShaderMaterial:
	return _sh("ink_bb" if bb else "ink", INK_SHADER, bb)


static func _flare_mat() -> ShaderMaterial:
	return _sh("flare", FLARE_SHADER)


# ================================================================== temel yardımcılar
static func _put(pj: PathJutsu, n: Node3D, pos: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = pos
	return n


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _ipar(mi: GeometryInstance3D, vals: Dictionary) -> void:
	for k in vals:
		mi.set_instance_shader_parameter(k, vals[k])


static func _pf(mi: GeometryInstance3D, key: String) -> Callable:
	return func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(key, v)


static func _flat(d: Vector3) -> Vector3:
	var f = Vector3(d.x, 0.0, d.z)
	if f.length() < 0.01:
		return Vector3.FORWARD
	return f.normalized()


static func _side(d: Vector3) -> Vector3:
	var s = d.cross(UP)
	if s.length() < 0.01:
		return Vector3.RIGHT
	return s.normalized()


static func _basis(d: Vector3) -> Basis:
	var f = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	return Basis.looking_at(f, UP if absf(f.y) < 0.97 else Vector3.RIGHT)


## Yerel +Y'yi dir'e çeviren taban
static func _yto(dir: Vector3) -> Basis:
	var d = dir.normalized() if dir.length() > 0.001 else UP
	if d.dot(UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(UP, d))


static func _rnd_dir() -> Vector3:
	var a = randf() * TAU
	return Vector3(cos(a), 0.0, sin(a))


static func _mk(v: PackedVector3Array, uv: PackedVector2Array, col: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _model_col(c: Node3D, key: String, def: Color) -> Color:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("look") is Dictionary and m.look.get(key) is Color:
		return m.look[key]
	return def


static func _bone_world(c: Node3D, bone: String, def: Vector3) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.get("skel"):
		var bi = m.skel.find_bone(bone)
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	return def


# ================================================================== geometri
## Düz kart (kameraya dönük kullanım için XY düzlemi)
static func _quad() -> QuadMesh:
	if _cache.has("mesh:quad"):
		return _cache["mesh:quad"]
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	_cache["mesh:quad"] = q
	return q


static func _plane() -> PlaneMesh:
	if _cache.has("mesh:plane"):
		return _cache["mesh:plane"]
	var p = PlaneMesh.new()
	p.size = Vector2(2, 2)
	_cache["mesh:plane"] = p
	return p


## İki dik şerit, +Y boyunca 0..1 (UV.x boyuna, UV.y enine), genişlik 1: alev dili / jet / hız çizgisi
static func _xstrip() -> ArrayMesh:
	if _cache.has("mesh:xstrip"):
		return _cache["mesh:xstrip"]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for ax in [Vector3.RIGHT, Vector3.BACK]:
		var b = v.size()
		for i in 7:
			var s = i / 6.0
			v.append(-ax * 0.5 + UP * s)
			v.append(ax * 0.5 + UP * s)
			uv.append(Vector2(s, 0.0))
			uv.append(Vector2(s, 1.0))
			col.append(Color.WHITE)
			col.append(Color.WHITE)
		for i in 6:
			var o = b + i * 2
			idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	var m = _mk(v, uv, col, idx)
	_cache["mesh:xstrip"] = m
	return m


## Merkez çizgisi + her noktada yan vektör + genişlik → şerit (UV.x boyuna, UV.y enine)
static func _strip_mesh(pts: Array, sides: Array, widths: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var n = pts.size()
	for i in n:
		var s = float(i) / maxf(1.0, n - 1)
		var p: Vector3 = pts[i]
		var sd: Vector3 = sides[i]
		var w = float(widths[i]) * 0.5
		v.append(p - sd * w)
		v.append(p + sd * w)
		uv.append(Vector2(s, 0.0))
		uv.append(Vector2(s, 1.0))
		col.append(Color.WHITE)
		col.append(Color.WHITE)
	for i in n - 1:
		var o = i * 2
		idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	return _mk(v, uv, col, idx)


## Boru: noktalar boyunca halkalar (toon / et ağları). SurfaceTool'a üçgen üçgen ekler (normal sonra üretilir)
static func _tube_add(st: SurfaceTool, pts: Array, radii: Array, sides: int, col: Color, flat := 1.0) -> void:
	var n = pts.size()
	var rings = []
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3
		if i == 0:
			tg = (pts[1] - pts[0])
		elif i == n - 1:
			tg = (pts[n - 1] - pts[n - 2])
		else:
			tg = (pts[i + 1] - pts[i - 1])
		tg = tg.normalized()
		var ref = UP if absf(tg.dot(UP)) < 0.9 else Vector3.RIGHT
		var ax = tg.cross(ref).normalized()
		var ay = tg.cross(ax).normalized()
		var r = float(radii[i])
		var ring = []
		for j in sides:
			var a = TAU * j / sides
			ring.append(p + ax * cos(a) * r + ay * sin(a) * r * flat)
		rings.append(ring)
	for i in n - 1:
		for j in sides:
			var j2 = (j + 1) % sides
			var q = [rings[i][j], rings[i + 1][j], rings[i + 1][j2], rings[i][j], rings[i + 1][j2], rings[i][j2]]
			for k in 6:
				st.set_color(col)
				st.set_uv(Vector2(float(i) / maxf(1.0, n - 1), float(j) / sides))
				st.add_vertex(q[k])
	# uç kapakları
	for e in [0, n - 1]:
		var cen: Vector3 = pts[e]
		for j in sides:
			var j2 = (j + 1) % sides
			for p in [cen, rings[e][j], rings[e][j2]]:
				st.set_color(col)
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(p)


## Kaya parçası: oynatılmış sekizyüzlü (3 çeşit, önbellekte)
static func _rock_mesh(v: int) -> ArrayMesh:
	var key = "mesh:rock%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 911 + v * 37
	var pts = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	for i in pts.size():
		pts[i] = pts[i] * rng.randf_range(0.6, 1.15) + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
	var faces = [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for f in faces:
		for i in f:
			st.set_color(Color.WHITE)
			st.add_vertex(pts[i] * 0.5)
	st.generate_normals()
	var m = st.commit()
	_cache[key] = m
	return m


## Diken yelpazesi (XY düzleminde, kökü merkezde): a0..a1 derece arası n diken (ref: topun altından saçılan cel toz)
static func _fan_mesh(n: int, a0: float, a1: float, l0: float, l1: float, w: float, sd: int) -> ArrayMesh:
	var key = "mesh:fan_%d_%d_%d_%d" % [n, int(a0), int(a1), sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 4242 + sd * 13
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for i in n:
		var a = deg_to_rad(lerpf(a0, a1, (i + rng.randf_range(0.1, 0.9)) / n))
		var dv = Vector3(cos(a), sin(a), 0.0)
		var sv = Vector3(-dv.y, dv.x, 0.0)
		var ln = rng.randf_range(l0, l1)
		var r0 = rng.randf_range(0.0, 0.25)
		var ww = w * rng.randf_range(0.6, 1.2)
		var b = v.size()
		v.append(dv * r0 - sv * ww)
		v.append(dv * r0 + sv * ww)
		v.append(dv * (r0 + ln))
		uv.append(Vector2(0.0, 0.0))
		uv.append(Vector2(0.0, 1.0))
		uv.append(Vector2(1.0, 0.5))
		for k in 3:
			col.append(Color.WHITE)
		idx.append_array([b, b + 1, b + 2])
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


## Darbe yıldızı (XY düzleminde): dolu merkez + n sivri ışın
static func _star_mesh(n: int, sd: int) -> ArrayMesh:
	var key = "mesh:star_%d_%d" % [n, sd]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 77 + sd * 5
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	v.append(Vector3.ZERO)
	uv.append(Vector2(1.0, 0.5))
	col.append(Color.WHITE)
	var r0 = 0.28
	for i in n:
		var a = TAU * i / n
		var a2 = TAU * (i + 1) / n
		var am = (a + a2) * 0.5
		var ln = rng.randf_range(0.6, 1.0) if i % 2 == 0 else rng.randf_range(0.38, 0.6)
		var b = v.size()
		v.append(Vector3(cos(a), sin(a), 0) * r0)
		v.append(Vector3(cos(am), sin(am), 0) * ln)
		v.append(Vector3(cos(a2), sin(a2), 0) * r0)
		uv.append(Vector2(1.0, 0.0))
		uv.append(Vector2(1.0, 0.5))
		uv.append(Vector2(1.0, 1.0))
		for k in 3:
			col.append(Color.WHITE)
		idx.append_array([b, b + 1, b + 2, 0, b, b + 2])
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


## Yay (XZ düzleminde, a=0 ileri -Z): r yarıçap, a0→a1 derece, w kalınlık; ortası kalın hilal (UV.x boyunca, UV.y içten dışa)
static func _arc_mesh(r: float, a0: float, a1: float, w: float, seg := 28) -> ArrayMesh:
	var key = "mesh:arc_%.2f_%d_%d_%.2f" % [r, int(a0), int(a1), w]
	if _cache.has(key):
		return _cache[key]
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var s = float(i) / seg
		var a = deg_to_rad(lerpf(a0, a1, s))
		var dv = Vector3(-sin(a), 0.0, -cos(a))
		var hw = w * (0.25 + 0.75 * sin(PI * s)) * 0.5
		v.append(dv * (r - hw))
		v.append(dv * (r + hw))
		uv.append(Vector2(s, 0.0))
		uv.append(Vector2(s, 1.0))
		col.append(Color.WHITE)
		col.append(Color.WHITE)
	for i in seg:
		var o = i * 2
		idx.append_array([o, o + 1, o + 3, o, o + 3, o + 2])
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


## Chō Mōdo kanat yaprağı (XY düzlemi, kök 0'da): uzun sivri üst kanat / kısa alt kuyruk; arka kenarı tırtıklı, uca doğru geriye kavisli
static func _wing_mesh(sx: float, lower: bool) -> ArrayMesh:
	var key = "mesh:wing_%d_%d" % [int(sx), int(lower)]
	if _cache.has(key):
		return _cache[key]
	var L = 0.95 if lower else 1.55
	var W = 0.2 if lower else 0.42
	var dir2 = (Vector2(sx * 0.42, -0.9) if lower else Vector2(sx * 0.6, 0.8)).normalized()
	var nrm = Vector2(-dir2.y, dir2.x) * (sx if not lower else -sx)
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var segs = 18
	for i in segs + 1:
		var s = float(i) / segs
		var cen = dir2 * L * s
		var half = W * pow(sin(PI * pow(s, 0.72)), 0.8) * (1.0 - 0.2 * s)
		var lead = half * 0.75
		var trail = half * (1.0 + (0.22 if i % 2 == 0 else -0.05) * (1.0 - s * 0.4))
		var z = -0.42 * s * s * L
		var pa = cen + nrm * lead
		var pb = cen - nrm * trail
		v.append(Vector3(pa.x, pa.y, z))
		v.append(Vector3(cen.x, cen.y, z - 0.03))
		v.append(Vector3(pb.x, pb.y, z))
		uv.append(Vector2(s, 0.0))
		uv.append(Vector2(s, 0.5))
		uv.append(Vector2(s, 1.0))
		for k in 3:
			col.append(Color.WHITE)
	for i in segs:
		var o = i * 3
		idx.append_array([o, o + 3, o + 4, o, o + 4, o + 1, o + 1, o + 4, o + 5, o + 1, o + 5, o + 2])
	var m = _mk(v, uv, col, idx)
	_cache[key] = m
	return m


# ================================================================== yapı taşları (sahne)
## Kart: 0 cel toz, 1 buhar, 2 parıltı. p'den vel ile kayar, büyür, söner
static func _puff(pj: PathJutsu, p: Vector3, s: float, life: float, vel: Vector3, col: Color, mode := 0, delay := 0.0) -> void:
	var mi = _gi(_quad(), _puff_mat())
	_put(pj, mi, p)
	mi.scale = Vector3.ONE * s * 0.6
	mi.visible = delay <= 0.0
	_ipar(mi, {"k_col": col, "k_a": 1.0, "k_seed": randf() * 10.0, "k_mode": float(mode)})
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): mi.visible = true)
	tw.tween_property(mi, "global_position", p + vel * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * s * (1.5 if mode != 2 else 0.9), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Yerde dışa itilen toz halkası
static func _dust_ring(pj: PathJutsu, c: Vector3, r0: float, r1: float, n: int, s: float, life: float, col := DUST, up := 0.3) -> void:
	for i in n:
		var a = TAU * (i + randf_range(-0.3, 0.3)) / n
		var dv = Vector3(cos(a), 0.0, sin(a))
		_puff(pj, c + dv * r0 + UP * s * 0.35, s * randf_range(0.75, 1.15), life * randf_range(0.8, 1.1), dv * (r1 - r0) / life + UP * up, col, 0, randf() * 0.05)


## Zemin izi. o: dir, seed, col, gnd, grow_t, a
static func _decal(pj: PathJutsu, p: Vector3, r: float, mode: int, life: float, o := {}) -> MeshInstance3D:
	var mi = _gi(_plane(), _decal_mat())
	_put(pj, mi, pj.gp(p) + UP * float(o.get("lift", 0.035)))
	var sc: Vector3 = o.get("scale", Vector3.ONE) * r
	mi.global_basis = _basis(_flat(o.get("dir", Vector3.FORWARD))) * Basis.from_scale(sc)
	_ipar(mi, {"k_mode": float(mode), "k_seed": float(o.get("seed", randf() * 20.0)), "k_col": o.get("col", Color(0.08, 0.06, 0.05)),
		"k_gnd": o.get("gnd", GND), "k_grow": 0.0, "k_a": float(o.get("a", 1.0))})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, float(o.get("grow_t", 0.2))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mode == 3:
		tw.parallel().tween_method(_pf(mi, "k_a"), float(o.get("a", 1.0)), 0.0, float(o.get("grow_t", 0.2))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_interval(life)
		tw.tween_method(_pf(mi, "k_a"), float(o.get("a", 1.0)), 0.0, 0.9)
	tw.tween_callback(mi.queue_free)
	return mi


## Balistik savrulma: yere değince durur, sonra küçülüp gider
static func _toss(pj: PathJutsu, mi: Node3D, p0: Vector3, v: Vector3, life: float, g := 22.0, spin := 9.0) -> void:
	var fl = pj.gp(p0).y
	var t_land = (v.y + sqrt(maxf(0.0, v.y * v.y + 2.0 * g * (p0.y - fl)))) / g
	var rax = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
	rax = rax.normalized() if rax.length() > 0.05 else Vector3.RIGHT
	var b0 = mi.global_basis
	var step = func(tt: float) -> void:
		if not is_instance_valid(mi):
			return
		var te = minf(tt, t_land)
		mi.global_position = p0 + v * te + Vector3.DOWN * 0.5 * g * te * te
		mi.global_basis = Basis(rax, te * spin) * b0
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(mi.queue_free)


## Kaya parçaları
static func _chunks(pj: PathJutsu, p: Vector3, n: int, s: float, spd: float, col := GND, up := 0.8, life := 1.0) -> void:
	for i in n:
		var mi = _gi(_rock_mesh(i % 3), _cel(true))
		_ipar(mi, {"k_tint": col.darkened(randf() * 0.25)})
		_put(pj, mi, p + UP * 0.2 + _rnd_dir() * randf() * 0.5)
		mi.scale = Vector3.ONE * s * randf_range(0.35, 1.0)
		var v = _rnd_dir() * spd * randf_range(0.35, 1.0) + UP * spd * up * randf_range(0.6, 1.2)
		_toss(pj, mi, mi.global_position, v, life * randf_range(0.8, 1.2))


## Yerde diken yelpazesi: ilerleme yönüne dik düzlemde iki yana ve yukarı saçılan cel toz dikenleri (ref: Nikudan Sensha)
static func _spray(pj: PathJutsu, p: Vector3, d: Vector3, s: float, col := DUST, edge := Color(0.5, 0.38, 0.26), life := 0.35) -> void:
	var mi = _gi(_fan_mesh(9, 8.0, 172.0, 0.45, 1.0, 0.08, randi() % 4), _ink(false))
	_put(pj, mi, pj.gp(p) + UP * 0.02)
	var sd = _side(_flat(d))
	mi.global_basis = Basis(sd, UP, sd.cross(UP)).orthonormalized() * Basis.from_scale(Vector3.ONE * s * 0.4)
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_a": 1.0, "k_grow": 1.0, "k_tail": 0.0})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life * 0.6)
	tw.tween_callback(mi.queue_free)


## Darbe karesi yıldızı (kameraya dönük)
static func _star(pj: PathJutsu, p: Vector3, s: float, col: Color, edge: Color, life := 0.2) -> void:
	var mi = _gi(_star_mesh(14, randi() % 5), _ink(true))
	_put(pj, mi, p)
	mi.scale = Vector3.ONE * s * 0.35
	_ipar(mi, {"k_col": col, "k_edge": edge, "k_a": 1.0, "k_grow": 1.0, "k_tail": 0.0})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s, life * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_pf(mi, "k_a"), 1.0, 0.0, life * 0.65)
	tw.tween_callback(mi.queue_free)


## Yönlü çarpma halkası: d'ye dik düzlemde açılan ince mürekkep halka, d boyunca ilerler
static func _dir_ring(pj: PathJutsu, p: Vector3, d: Vector3, r: float, col: Color, life: float, travel := 1.0, delay := 0.0) -> void:
	var mi = _gi(_arc_mesh(1.0, -180.0, 180.0, 0.12, 36), _ink(false))
	_put(pj, mi, p)
	var b0 = _yto(d)
	mi.global_basis = b0 * Basis.from_scale(Vector3.ONE * r * 0.3)
	mi.visible = delay <= 0.0
	_ipar(mi, {"k_col": col, "k_edge": col.darkened(0.55), "k_a": 1.0, "k_grow": 1.0, "k_tail": 0.0})
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): mi.visible = true)
	tw.tween_method(func(u: float):
		if is_instance_valid(mi):
			mi.global_basis = b0 * Basis.from_scale(Vector3.ONE * r * lerpf(0.3, 1.0, u))
			mi.global_position = p + d.normalized() * travel * u, 0.0, 1.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Hız çizgisi (iki dik şerit, mürekkep, kuyruktan söner)
static func _streak(pj: PathJutsu, from: Vector3, dir: Vector3, len_: float, w: float, col: Color, life: float) -> void:
	var mi = _gi(_xstrip(), _ink(false))
	_put(pj, mi, from)
	mi.global_basis = _yto(dir) * Basis.from_scale(Vector3(w, len_, w))
	_ipar(mi, {"k_col": col, "k_edge": col.darkened(0.4), "k_a": 0.9, "k_grow": 0.0, "k_tail": 1.6})
	var tw = mi.create_tween()
	tw.tween_method(_pf(mi, "k_grow"), 0.0, 1.0, life * 0.4)
	tw.tween_method(_pf(mi, "k_a"), 0.9, 0.0, life * 0.6)
	tw.tween_callback(mi.queue_free)


## Dünyada tek alev dili / kurdele parçası (WISP), dir'e doğru uzar ve söner
static func _tongue(pj: PathJutsu, p: Vector3, dir: Vector3, len_: float, w: float, life: float, col: Color, deep: Color, mode := 1, drift := Vector3.ZERO) -> void:
	var mi = _gi(_xstrip(), _wisp_mat())
	_put(pj, mi, p)
	var b0 = _yto(dir)
	mi.global_basis = b0 * Basis.from_scale(Vector3(w, len_ * 0.3, w))
	_ipar(mi, {"k_col": col, "k_deep": deep, "k_a": 1.0, "k_mode": float(mode), "k_seed": randf() * 9.0})
	var tw = mi.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(mi):
			mi.global_basis = b0 * Basis.from_scale(Vector3(w * (1.0 - 0.4 * u), len_ * lerpf(0.3, 1.0, sqrt(u)), w * (1.0 - 0.4 * u)))
			mi.global_position = p + drift * u, 0.0, 1.0, life)
	tw.parallel().tween_method(_pf(mi, "k_a"), 1.0, 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Kemiğe iliştir (yoksa karaktere), dur sonra sil
static func _on_bone(pj: PathJutsu, c: Node3D, bone: String, n: Node3D, dur: float, fallback := Vector3(0, 1.2, 0)) -> Node3D:
	var ba = pj.bone_attach(c, bone)
	if ba == null:
		c.add_child(n)
		n.position = fallback
		pj.free_after(dur, n)
		return null
	ba.add_child(n)
	pj.free_after(dur, ba)
	return ba


# ================================================================== Akimichi yapı taşları
## Mavi chakra kurdeleleri (ref Baika): bedenin çevresinde sarmal dönerek genişler, sonra dağılır
static func _chakra_coil(pj: PathJutsu, c: Node3D, n: int, rad: float, h: float, dur: float, grow := 1.8) -> void:
	var root = Node3D.new()
	c.add_child(root)
	var parts = []
	for k in n:
		var ph = TAU * k / n + randf() * 0.4
		var tilt = randf_range(-0.35, 0.35)
		var turns = randf_range(1.0, 1.4)
		var pts = []
		for i in 25:
			var s = i / 24.0
			var a = ph + s * TAU * turns
			var rr = rad * (0.85 + 0.25 * sin(s * PI))
			pts.append(Vector3(cos(a) * rr, 0.1 + s * h + sin(a) * tilt, sin(a) * rr))
		var sides = []
		var ws = []
		for i in 25:
			var tg: Vector3 = (pts[mini(i + 1, 24)] - pts[maxi(i - 1, 0)]).normalized()
			var radial = Vector3(pts[i].x, 0.0, pts[i].z).normalized()
			sides.append(tg.cross(radial).normalized())
			ws.append(0.26 * rad * (0.7 + 0.3 * sin(i / 24.0 * PI)))
		var mi = _gi(_strip_mesh(pts, sides, ws), _wisp_mat())
		_ipar(mi, {"k_col": Color(0.62, 0.9, 1.0), "k_deep": Color(0.25, 0.55, 1.0), "k_a": 0.0, "k_mode": 0.0, "k_seed": randf() * 9.0})
		root.add_child(mi)
		parts.append(mi)
	root.scale = Vector3.ONE * 0.6
	var tw = root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * 1.6, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "scale", Vector3.ONE * grow, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for mi in parts:
		var t2 = mi.create_tween()
		t2.tween_method(_pf(mi, "k_a"), 0.0, 1.0, dur * 0.2)
		t2.tween_interval(dur * 0.4)
		t2.tween_method(_pf(mi, "k_a"), 1.0, 0.0, dur * 0.4)
	tw.tween_callback(root.queue_free)


## Akimichi insan mermisi topu (ref: kıyafet renginde, iki zikzak tarama bandı, bir yüzde saç tutamı).
## spiked: iple bedene sarılı kunailer (ref Hari Sensha) — ip iki halka, kunailer dışa bakan koyu bıçaklar
static func _ball(c: Node3D, r: float, spiked: bool) -> Node3D:
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 28
	sm.rings = 16
	var mi = _gi(sm, _ball_mat())
	_ipar(mi, {"k_base": _model_col(c, "top", Color(0.55, 0.18, 0.2)), "k_hair": _model_col(c, "hair", Color(0.16, 0.1, 0.07)).darkened(0.25)})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if spiked:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rope = Color(0.42, 0.34, 0.24)
		for k in 2:
			var pts = []
			var radii = []
			var ax = Basis(Vector3.RIGHT, deg_to_rad(90.0 * k)) * Basis(UP, deg_to_rad(30.0 * k))
			for i in 33:
				var a = TAU * i / 32.0
				pts.append(ax * Vector3(cos(a), 0.0, sin(a)) * r * 1.01)
				radii.append(r * 0.035)
			_tube_add(st, pts, radii, 5, rope)
		var steel = Color(0.2, 0.2, 0.23)
		for k in 22:
			var a = k * TAU / 11.0
			var dv = Vector3(cos(a), 0, sin(a)) if k % 2 == 0 else (Basis(UP, deg_to_rad(30.0)) * Vector3(cos(a), sin(a), 0))
			dv = dv.normalized()
			var base = dv * r * 0.98
			var tip = dv * r * 1.42
			var sd = dv.cross(UP if absf(dv.y) < 0.9 else Vector3.RIGHT).normalized() * r * 0.07
			var fw = dv.cross(sd).normalized() * r * 0.025
			var quad = [base + sd, base + fw, base - sd, base - fw]
			for q in 4:
				for p in [quad[q], quad[(q + 1) % 4], tip]:
					st.set_color(steel)
					st.add_vertex(p)
		st.generate_normals()
		var sp = _gi(st.commit(), _cel(true))
		_ipar(sp, {"k_tint": Color.WHITE})
		mi.add_child(sp)
	return mi


## Yuvarlanan topun yer izi: oluk, yana saçılan toz dikenleri, arkada toz (spiked: kunai oyukları + kıvılcım + koyu toz)
static func _roll_mark(pj: PathJutsu, c: Node3D, r: float, spiked: bool) -> void:
	if not is_instance_valid(c):
		return
	var v = c.get("velocity")
	var d: Vector3 = _flat(v if v is Vector3 and Vector3(v.x, 0, v.z).length() > 0.5 else c.face_dir())
	var p = pj.gp(c.global_position)
	if spiked:
		_decal(pj, p, r * 0.75, 5, 2.4, {"dir": d, "scale": Vector3(1.0, 1.0, 1.3), "col": Color(0.12, 0.08, 0.06), "grow_t": 0.05})
		for k in 3:
			_puff(pj, p + _side(d) * randf_range(-r, r) + UP * 0.1, 0.22, 0.25, (-d + UP * randf_range(0.5, 1.2) + _side(d) * randf_range(-0.8, 0.8)) * 6.0, Color(1.0, 0.85, 0.5), 2)
		_puff(pj, p - d * r * 0.8 + UP * 0.4, r * 0.7, 0.6, -d * 2.0 + UP * 1.2, DUST.darkened(0.22))
	else:
		_decal(pj, p, r * 0.7, 1, 2.0, {"dir": d, "scale": Vector3(1.0, 1.0, 1.4), "grow_t": 0.05, "a": 0.85})
		_spray(pj, p + d * r * 0.2, d, r * 1.1)
		_puff(pj, p - d * r * 0.9 + UP * 0.35, r * 0.6, 0.55, -d * 2.5 + UP * 1.0, DUST)


## Chō Mōdo kelebek kanatları (ref): sırttan iki uzun sivri üst kanat + iki ince alt kuyruk; açılırken büyür, kanat çırpar
static func _wings(pj: PathJutsu, c: Node3D, dur: float, k := 1.0) -> Node3D:
	var root = Node3D.new()
	_on_bone(pj, c, "UpperChest", root, dur, Vector3(0, 1.35, -0.2))
	root.position += Vector3(0, 0.04, -0.17)
	for sx in [-1.0, 1.0]:
		var wing = Node3D.new()
		root.add_child(wing)
		wing.position = Vector3(sx * 0.05, 0.0, 0.0)
		for lower in [false, true]:
			var mi = _gi(_wing_mesh(sx, lower), _wing_mat())
			_ipar(mi, {"k_a": 1.0, "k_seed": randf() * 20.0})
			wing.add_child(mi)
		wing.rotation.y = 0.32 * sx
		var tw = wing.create_tween().set_loops()
		tw.tween_property(wing, "rotation:y", 0.55 * sx, 0.75).set_trans(Tween.TRANS_SINE)
		tw.tween_property(wing, "rotation:y", 0.25 * sx, 0.75).set_trans(Tween.TRANS_SINE)
	root.scale = Vector3.ONE * 0.05
	var t0 = root.create_tween()
	t0.tween_property(root, "scale", Vector3.ONE * k, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dur > 0.8:
		t0.tween_interval(dur - 0.8)
		t0.tween_property(root, "scale", Vector3(k, k * 0.6, k) * 0.05, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return root


## Yumruğu saran mavi chakra alevleri (ref Chōdan): el kemiğinde (büyümeyi alır), diller her kare dünyada yukarı/geriye bakar
static func _fist_flame(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var root = Node3D.new()
	ba.add_child(root)
	var tongues = []
	for k in 7:
		var mi = _gi(_xstrip(), _wisp_mat())
		_ipar(mi, {"k_col": Color(0.6, 0.88, 1.0), "k_deep": AKI_DEEP, "k_a": 1.0, "k_mode": 1.0, "k_seed": randf() * 9.0})
		root.add_child(mi)
		var a = TAU * k / 7.0
		mi.position = Vector3(cos(a) * 0.07, randf_range(-0.04, 0.06), sin(a) * 0.07)
		var tilt = Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35).normalized()
		mi.basis = _yto(tilt) * Basis.from_scale(Vector3(0.16, randf_range(0.28, 0.4), 0.16))
		tongues.append(mi)
	var bw = weakref(ba)
	var rw = weakref(root)
	pj.every(dur, 0.016, func(i, _k):
		var b2 = bw.get_ref()
		var r2 = rw.get_ref()
		if b2 == null or r2 == null:
			return
		var sc: Vector3 = (b2 as Node3D).global_basis.get_scale()
		(r2 as Node3D).global_basis = Basis.from_scale(sc)
		if i % 3 == 0:
			var hp: Vector3 = (b2 as Node3D).global_position
			_tongue(pj, hp + _rnd_dir() * sc.x * 0.08, UP + _rnd_dir() * 0.3, sc.x * 0.35, sc.x * 0.12, 0.3, Color(0.6, 0.88, 1.0), AKI_DEEP, 1, UP * sc.x * 0.4))
	pj.free_after(dur, ba)


# ================================================================== Jūgo yapı taşları
## Senninka etli parçalar için ten rengi (aşama 2 koyu gri)
static func _sage_set(mi: GeometryInstance3D, stage := 1, cover := 1.0) -> void:
	_ipar(mi, {"k_skin": SAGE_SKIN if stage < 2 else SAGE_SKIN2, "k_cover": cover, "k_mark": 1.0})


## Sırttan çıkan etten jet boruları (Senninka): üst göğüs kemiğine bağlı, uçlarda koyu ağızdan geriye itki alevi + duman izi
static func _jets(pj: PathJutsu, c: Node3D, dur: float, n := 4) -> void:
	var ba = pj.bone_attach(c, "UpperChest")
	if ba == null:
		return
	var root = Node3D.new()
	ba.add_child(root)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips = []
	for k in n:
		var sx = k - (n - 1) * 0.5
		var o = Vector3(sx * 0.12, 0.05 - absf(sx) * 0.05, -0.1)
		var e = o + Vector3(sx * 0.2, 0.22 - absf(sx) * 0.06, -0.52)
		var mid = o.lerp(e, 0.5) + Vector3(0, 0.08, 0)
		_tube_add(st, [o, mid, e], [0.055, 0.08, 0.1], 7, Color.WHITE)
		var ax = (e - mid).normalized()
		_tube_add(st, [e - ax * 0.03, e + ax * 0.03], [0.115, 0.1], 7, Color(0.15, 0.1, 0.1))
		tips.append([e + ax * 0.03, ax])
	st.generate_normals()
	var body = _gi(st.commit(), _sage(true))
	_sage_set(body, 1)
	root.add_child(body)
	for tp in tips:
		var fl = _gi(_xstrip(), _flare_mat())
		_ipar(fl, {"k_a": 1.0, "k_seed": randf() * 9.0})
		root.add_child(fl)
		fl.position = tp[0]
		var b0 = _yto(tp[1] + Vector3(0, -0.25, 0)) * Basis.from_scale(Vector3(0.22, 0.85, 0.22))
		fl.basis = b0
		var tw = fl.create_tween().set_loops()
		tw.tween_property(fl, "scale", Vector3(0.24, 1.0, 0.24), 0.06)
		tw.tween_property(fl, "scale", Vector3(0.2, 0.72, 0.2), 0.06)
	root.scale = Vector3.ONE * 0.05
	var t0 = root.create_tween()
	t0.tween_property(root, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t0.tween_interval(maxf(0.0, dur - 0.32))
	t0.tween_property(root, "scale", Vector3.ONE * 0.05, 0.18)
	var rw = weakref(root)
	pj.every(dur, 0.07, func(_i, _k):
		var r2 = rw.get_ref()
		if r2 == null or not (r2 as Node3D).is_inside_tree():
			return
		var xf: Transform3D = (r2 as Node3D).global_transform
		var tp = tips[randi() % tips.size()]
		var at: Vector3 = xf * tp[0]
		var bd: Vector3 = (xf.basis * tp[1]).normalized()
		_puff(pj, at + bd * 0.5, 0.45, 0.45, bd * 3.0 + UP * 0.6, Color(0.72, 0.7, 0.68, 0.85), 0))
	pj.free_after(dur + 0.05, ba)


## Dirsekten / yumruktan geriye itki patlaması (Kassokuken)
static func _thrust(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var hp = pj.hand_pos(c)
	var at = hp - d * 0.45
	var fl = _gi(_xstrip(), _flare_mat())
	_put(pj, fl, at)
	var b0 = _yto(-d)
	fl.global_basis = b0 * Basis.from_scale(Vector3(0.5, 1.6, 0.5))
	_ipar(fl, {"k_a": 1.0, "k_seed": randf() * 9.0})
	var tw = fl.create_tween()
	tw.tween_method(_pf(fl, "k_a"), 1.0, 0.0, 0.25)
	tw.parallel().tween_property(fl, "scale", Vector3(0.2, 0.6, 0.2), 0.25)
	tw.tween_callback(fl.queue_free)
	for k in 3:
		_puff(pj, at - d * (0.4 + k * 0.3), 0.4 + k * 0.1, 0.4, -d * 3.0 + UP * 0.5 + _rnd_dir() * 0.8, Color(0.74, 0.72, 0.7, 0.8), 0)
	_streak(pj, hp - d * 2.2 + UP * randf_range(-0.2, 0.2), d, 2.0, 0.05, Color(1.0, 0.9, 0.75), 0.18)


## Ezici darbe karesi (Jūgo): krem yıldız + kara kontur, yumruk yönünde ilerleyen iki halka, yakınsa yerden kaya ve toz
static func _crush(pj: PathJutsu, at: Vector3, d: Vector3, s: float, landed := true) -> void:
	var dd = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	_star(pj, at, (1.5 if landed else 0.8) * s, Color(1.0, 0.93, 0.78), INK_D, 0.2)
	_dir_ring(pj, at, dd, 1.6 * s, Color(1.0, 0.82, 0.6), 0.28, 1.2 * s)
	if landed:
		_dir_ring(pj, at + dd * 0.3, dd, 2.4 * s, Color(0.95, 0.7, 0.45), 0.34, 2.0 * s, 0.05)
	var g = pj.gp(at)
	if at.y - g.y < 1.8:
		_chunks(pj, g + dd * 0.6, int(4 * s) + 2, 0.32 * s, 6.0 * s, GND, 0.7, 0.9)
		_puff(pj, g + dd * 0.8 + UP * 0.4, 0.9 * s, 0.6, dd * 3.0 + UP * 0.8, DUST, 0)


## Senninka teni: bedenin kemiklerine yayılan gri-turuncu lekeler (kara lanet izli). Kemiğe bağlı → bulk/büyüme mirası
static func _sage_skin(pj: PathJutsu, c: Node3D, dur: float, stage := 1, spread := 0.6) -> void:
	var spec = {"UpperChest": [0.15, 0.17, 0.75], "Chest": [0.14, 0.14, 0.75], "Spine": [0.13, 0.12, 0.75], "Neck": [0.05, 0.08, 1.0],
		"LeftUpperArm": [0.055, 0.26, 1.0], "RightUpperArm": [0.055, 0.26, 1.0], "LeftLowerArm": [0.046, 0.24, 1.0], "RightLowerArm": [0.046, 0.24, 1.0],
		"LeftUpperLeg": [0.085, 0.4, 1.0], "RightUpperLeg": [0.085, 0.4, 1.0], "LeftLowerLeg": [0.06, 0.38, 1.0], "RightLowerLeg": [0.06, 0.38, 1.0]}
	var cover = 0.62 if stage < 2 else 0.85
	for bone in spec:
		var sp: Array = spec[bone]
		var key = "mesh:sleeve_%s" % bone
		var mesh: ArrayMesh
		if _cache.has(key):
			mesh = _cache[key]
		else:
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var r = float(sp[0]) * 1.12
			var pts = []
			var radii = []
			for i in 6:
				var s = i / 5.0
				pts.append(Vector3(0, s * float(sp[1]), 0))
				radii.append(r * (0.92 + 0.12 * sin(s * PI)))
			_tube_add(st, pts, radii, 12, Color.WHITE, float(sp[2]))
			st.generate_normals()
			mesh = st.commit()
			_cache[key] = mesh
		var mi = _gi(mesh, _sage(false))
		_sage_set(mi, stage, 0.0)
		var ba = _on_bone(pj, c, bone, mi, dur)
		if ba == null:
			continue
		var tw = mi.create_tween()
		tw.tween_interval(randf() * 0.15)
		tw.tween_method(_pf(mi, "k_cover"), 0.0, cover, spread).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(0.0, dur - spread - 0.75))
		tw.tween_method(_pf(mi, "k_cover"), cover, 0.0, 0.5)


## Doğa enerjisi toplanması: çevreden turuncu parıltılar hedef noktaya çekilir
static func _nature_gather(pj: PathJutsu, at_fn: Callable, dur: float, n: int, rad: float, col := NATURE_O) -> void:
	pj.every(dur, dur / maxf(1.0, n), func(_i, _k):
		var at: Vector3 = at_fn.call()
		var from = at + Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized() * rad
		_puff(pj, from, 0.28, 0.35, (at - from) / 0.35, col, 2)
		_streak(pj, from, at - from, from.distance_to(at) * 0.6, 0.03, col, 0.3))


# ================================================================== AKİMİCHİ teknikleri
## Baika no Jutsu (ref): mavi chakra kurdeleleri bedeni sarmal sarar, beden gerçekten devleşir (oyuncu boyu x3);
## devleşen beden yere çöker: krater, dışa toz halkası, kaya, bej basınç halkası
static func baika(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	# Jutsu.j_baika (yalnız oyuncu boy değiştirir) + ClanJutsu.c_baika
	if c is Player:
		c.combat.modes.set_size(3.0, 20.0)
		Buffs.add("baika", 20.0, {"melee": 1.45, "speed": 0.85, "armor": 0.85, "reach": 2.2})
		Hud.msg("Baika no Jutsu! (20 sn dev)", Color(1, 0.8, 0.5))
	_chakra_coil(pj, c, 4, 1.0, 2.2, 0.95, 2.0)
	pj.after(0.45, func():
		var p = pj.gp(c.global_position)
		_decal(pj, p, 7.0, 0, 6.0, {"seed": randf() * 20.0, "grow_t": 0.15})
		_decal(pj, p, 7.5, 3, 0.0, {"col": Color(0.95, 0.88, 0.7), "grow_t": 0.45, "a": 0.9})
		_dust_ring(pj, p, 1.5, 6.5, 14, 1.6, 0.7)
		_chunks(pj, p, 10, 0.5, 7.0)
		pj.hit(c, p + UP, 5.0, pj.inf(c, "baika", 1.4, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "element": "doton"}))
		pj.shake(0.9)
		Sfx.play("boom", p, 0.6))


## Nikudan Sensha (ref): kıyafet renginde taranmış dev top yuvarlanır; altından iki yana cel toz dikenleri saçılır, yerde oluk kalır
static func nikudan(jt, c: Node3D, t: Node3D) -> void:
	var pj = PathJutsu.get_pinst()
	var m = jt._mult(c)
	var ball = _ball(c, 1.6, false)
	c.add_child(ball)
	ball.position = Vector3(0, 1.6, 0)
	c.model.visible = false
	Sfx.play("earth", c.global_position, 0.8)
	var hits = []
	var n = {"i": 0}
	jt._dash(c, t, 1.3, 22.0, func(pt):
		ball.rotation.x -= 0.35
		n["i"] += 1
		if n["i"] % 5 == 0:
			_roll_mark(pj, c, 1.6, false)
		for h in Combat.hit_sphere(c, pt, 2.2, {"dmg": 18.0 * m, "knock": 16.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.06}, hits):
			hits.append(h), func():
		ball.queue_free()
		if is_instance_valid(c):
			c.model.visible = true
			var p = pj.gp(c.global_position)
			var d = _flat(c.face_dir())
			_spray(pj, p + d * 0.6, d, 1.6, DUST, Color(0.5, 0.38, 0.26), 0.45)
			_dust_ring(pj, p, 0.5, 2.5, 7, 0.9, 0.5))


## Nikudan Hari Sensha (ref): iple bedene sarılı kunailerle dikenli top; yerde kunai oyukları, kıvılcım, isabette kan kıymıkları
static func nikudan_hari_sensha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var ball = _ball(c, 1.6, true)
	c.add_child(ball)
	ball.position = Vector3(0, 1.6, 0)
	c.model.visible = false
	var last = {}
	var n = {"i": 0}
	Jutsu._dash(c, t, 1.6, 24.0, func(pt):
		ball.rotation.x -= 0.45
		n["i"] += 1
		if n["i"] % 4 == 0:
			_roll_mark(pj, c, 1.6, true)
		for e in pj.enemies_near(c, pt, 2.4):
			# hedef başına tek, tam darbe (dikenli top çarpıp savurur)
			if not last.has(e.get_instance_id()):
				last[e.get_instance_id()] = true
				var ep = e.global_position + UP
				var dv = _flat(e.global_position - c.global_position)
				var fm = _gi(_fan_mesh(9, 20.0, 160.0, 0.4, 0.9, 0.05, 2), _ink(true))
				_put(pj, fm, ep)
				fm.scale = Vector3.ONE * 1.2
				_ipar(fm, {"k_col": Color(0.62, 0.05, 0.06), "k_edge": Color(0.2, 0.0, 0.02), "k_a": 1.0, "k_grow": 1.0, "k_tail": 0.0})
				var tw = fm.create_tween()
				tw.tween_property(fm, "scale", Vector3.ONE * 1.8, 0.12)
				tw.tween_method(_pf(fm, "k_a"), 1.0, 0.0, 0.25)
				tw.tween_callback(fm.queue_free)
				_star(pj, ep + dv * 0.2, 1.2, Color(0.95, 0.95, 0.92), INK_D, 0.16)
				pj.hit(c, e.global_position + UP, 1.0, pj.inf(c, "nikudan_hari_sensha", 2.0, {"knock": 9.0, "launch": 3.0, "kind": "heavy", "bleed": 3.0})), func():
		ball.queue_free()
		if is_instance_valid(c):
			c.model.visible = true)
	Sfx.play("earth", c.global_position, 0.8)


## Nikudan Yōyō (ref): dev top hedefe çarpar, yerdeki kara gölge ipiyle yoyo gibi geri çekilir, üç kez
static func nikudan_yoyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 2.0)
	if tt == null:
		return
	var ball = _ball(c, 2.0, false)
	pj.get_tree().current_scene.add_child(ball)
	var home = c.global_position + UP * 2.0
	ball.global_position = home
	if c.get("model"):
		c.model.visible = false
	_shadow_line(pj, home, ball, 2.0)
	Sfx.play("th_growth", c.global_position, 0.9)
	var tw = ball.create_tween()
	for k in 3:
		var tgt_p = func(): return (tt.global_position + UP * 1.6) if pj.live(tt) else home
		tw.tween_method(func(u: float):
			if is_instance_valid(ball):
				ball.global_position = home.lerp(tgt_p.call(), u)
				ball.rotate_x(0.5), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if pj.live(tt):
				tt.take_hit(pj.inf(c, "nikudan_yoyo", 0.8, {"knock": 9.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.06}))
				var gp_t = pj.gp(tt.global_position)
				var dv = _flat(tt.global_position - home)
				_spray(pj, gp_t, dv, 2.2, DUST, Color(0.5, 0.38, 0.26), 0.4)
				_dir_ring(pj, tt.global_position + UP * 1.2, dv, 2.6, Color(0.96, 0.9, 0.75), 0.3, 1.5)
				_chunks(pj, gp_t, 6, 0.4, 5.0)
				Sfx.play("hit_heavy", tt.global_position, 0.8))
		tw.tween_method(func(u: float):
			if is_instance_valid(ball):
				ball.global_position = tgt_p.call().lerp(home, u)
				ball.rotate_x(-0.5), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(ball):
			ball.queue_free()
		if pj.live(c) and c.get("model"):
			c.model.visible = true
		var g = pj.gp(home)
		_dust_ring(pj, g, 0.5, 2.8, 8, 1.0, 0.5))


## Yerdeki kara gölge ipi (ref Yōyō): evden topa kıvrıla kıvrıla uzanır, topun altında ona doğru yükselir
static func _shadow_line(pj: PathJutsu, home: Vector3, ball: Node3D, dur: float) -> void:
	var im = ImmediateMesh.new()
	var mi = _gi(im, _ink(false))
	_put(pj, mi, Vector3.ZERO)
	_ipar(mi, {"k_col": Color(0.03, 0.03, 0.05), "k_edge": Color(0.0, 0.0, 0.0), "k_a": 0.92, "k_grow": 1.0, "k_tail": 0.0})
	var bw = weakref(ball)
	var mw = weakref(mi)
	pj.every(dur, 0.016, func(i, _k):
		var b2 = bw.get_ref()
		if b2 == null or mw.get_ref() == null:
			return
		var a = pj.gp(home) + UP * 0.06
		var bp: Vector3 = (b2 as Node3D).global_position
		var bg = pj.gp(bp) + UP * 0.06
		var span = bg - a
		if span.length() < 0.3:
			im.clear_surfaces()
			return
		var sd = _side(_flat(span))
		var pts = []
		var segs = 26
		for s_i in segs + 1:
			var s = float(s_i) / segs
			var wob = sin(s * 9.0 - i * 0.12) * 0.55 * sin(s * PI)
			var p = a.lerp(bg, s) + sd * wob
			if s > 0.85:
				p = p.lerp(bp - UP * 1.2, (s - 0.85) / 0.15)
			pts.append(p)
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for s_i in segs:
			var p0: Vector3 = pts[s_i]
			var p1: Vector3 = pts[s_i + 1]
			var w = sd
			var hw = 0.13
			var q = [p0 - w * hw, p0 + w * hw, p1 + w * hw, p0 - w * hw, p1 + w * hw, p1 - w * hw]
			var uy = [0.0, 1.0, 1.0, 0.0, 1.0, 0.0]
			for k in 6:
				im.surface_set_color(Color.WHITE)
				im.surface_set_uv(Vector2(0.5, uy[k]))
				im.surface_add_vertex(q[k])
		im.surface_end(), func():
		var m2 = mw.get_ref()
		if m2:
			m2.queue_free())
	pj.free_after(dur + 0.2, mi)


## Chōdan Bakugeki (ref): Kelebek Modu'nda kanatlar açılır, havaya fırlar; gerçek kol devleşir, yumruğu mavi chakra alevleri
## sarar ve arkasında alev dilleri bırakır; iniş: dev krater, çevrede yükselen mavi alev çemberi, toz ve kaya
static func chodan_bakugeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	# kanon: yalnız Kelebek Modu'nda — kanatlardaki chakra yumruğa toplanır; hapla girilmiş modda yumruk chakrayı tüketir
	var in_mode = (c is Player and Buffs.has("cho_modo")) or (not (c is Player) and c.get("buffs") != null and c.buffs.has("cho_modo"))
	if not in_mode:
		if c is Player:
			Hud.msg("Chōdan Bakugeki yalnız Kelebek Modu'nda (Chō Mōdo) yapılır.", Color(0.6, 0.8, 1.0))
		return
	if c is Player and Buffs.has("hap_togarashi"):
		pj.after(1.4, func():
			Buffs.remove("cho_modo")
			Hud.msg("Kanatlardaki bütün chakra yumrukta tükendi.", Color(0.6, 0.8, 1.0)))
	var at = pj.gp(Jutsu._aim_ground(c, t, 8.0, 18.0))
	_wings(pj, c, 1.6, 1.0)
	pj.busy(c, 1.2)
	c.velocity.y = 16.0
	pj.after(0.55, func():
		if not is_instance_valid(c):
			return
		c.global_position = at + UP * 8.0
		c.velocity = Vector3(0, -40, 0)
		# anime: gerçek kol ve yumruk devleşir (kemik büyümesi), kanatlardaki mavi chakrayla sarılı yumruk yere iner
		pj.anim(c, "throw", 1.3)
		pj._aki_arm(c, true, [1.5, 1.6, 3.0], 0.15, 0.45, 0.4)
		_fist_flame(pj, c, 1.0)
		for k in 6:
			_streak(pj, at + UP * randf_range(6.0, 9.0) + _rnd_dir() * randf_range(1.0, 2.6), Vector3.DOWN, randf_range(3.0, 5.0), 0.06, Color(0.75, 0.92, 1.0), 0.3)
		pj.after(0.25, func():
			_decal(pj, at, 9.0, 0, 7.0, {"grow_t": 0.12})
			_decal(pj, at, 12.0, 3, 0.0, {"col": Color(0.45, 0.78, 1.0), "grow_t": 0.5})
			for k in 12:
				var a = TAU * k / 12.0 + randf() * 0.3
				var dv = Vector3(cos(a), 0, sin(a))
				_tongue(pj, at + dv * randf_range(2.0, 4.0), (UP * 1.6 + dv).normalized(), randf_range(3.0, 4.6), randf_range(0.9, 1.3), 0.75, Color(0.6, 0.88, 1.0), AKI_DEEP, 1, dv * 2.0 + UP)
			_tongue(pj, at + UP * 0.2, UP, 5.0, 2.2, 0.6, Color(0.7, 0.92, 1.0), AKI_DEEP, 1)
			_dust_ring(pj, at, 2.0, 10.0, 16, 2.0, 0.8)
			_chunks(pj, at, 18, 0.7, 12.0, GND, 0.8, 1.2)
			_star(pj, at + UP * 1.2, 3.0, Color(0.85, 0.95, 1.0), Color(0.1, 0.25, 0.6), 0.22)
			pj.hit(c, at + UP, 9.5, pj.inf(c, "chodan_bakugeki", 2.0, {"knock": 18.0, "launch": 8.0, "kind": "heavy", "hitstop": 0.12}))
			pj.shake(1.4)
			Sfx.play("boom", at, 0.5)))


## Chō Mōdo (ref): sırttan camgöbeği kelebek kanatları (içinde akan koyu mavi alev lekeleri), kanatlardan yükselen parıltılar (25 sn);
## açılışta ayak altında mavi halka ve kelebek pulu parıltısı. Her saniye kalori (can) yanar
static func cho_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_wings(pj, c, 25.0, 1.0)
	if c is Player:
		Buffs.add("cho_modo", 25.0, {"melee": 1.6, "speed": 1.15, "armor": 0.8, "reach": 1.6})
	elif c.has_method("add_buff"):
		c.add_buff("cho_modo", 25.0, {"melee": 1.6, "speed": 1.15, "armor": 0.8})
	pj.every(25.0, 1.0, func(_i, _k):
		if is_instance_valid(c):
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.01))
	var p = pj.gp(c.global_position)
	_decal(pj, p, 5.0, 3, 0.0, {"col": Color(0.5, 0.82, 1.0), "grow_t": 0.55})
	for k in 14:
		var dv = (UP * 1.2 + _rnd_dir()).normalized()
		_puff(pj, c.global_position + UP * 1.4 + _rnd_dir() * 0.3, 0.35, 0.7, dv * randf_range(2.0, 4.0), Color(0.65, 0.92, 1.0), 2, randf() * 0.2)
	pj.every(25.0, 0.3, func(_i, _k):
		if not pj.live(c):
			return
		var ch = _bone_world(c, "UpperChest", c.global_position + UP * 1.4)
		var back = -_flat(c.face_dir())
		var q = ch + back * randf_range(0.3, 0.9) + _side(back) * randf_range(-1.4, 1.4) + UP * randf_range(-0.3, 1.4)
		_puff(pj, q, 0.22, 1.1, UP * 0.8 + back * 0.3, Color(0.7, 0.95, 1.0), 2))
	Hud.msg("Chō Mōdo! Kalorilerin yanıyor (25 sn)", Color(0.6, 0.8, 1.0))


## Karorī Kontorōru: yağ chakraya döner — bedenden fışkıran turuncu kalori buharı (sonra 15 sn ince buhar), ayak altında sıcak
## halka, yanaklarda kırmızı Akimichi sarmalları
static func karori_kontororu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var cost = c.max_hp * 0.15
	c.hp = maxf(1.0, c.hp - cost)
	pj.chakra_gain(c, cost * 2.5)
	if c is Player:
		Buffs.add("karori", 15.0, {"jutsu": 1.15, "melee": 1.1})
	Sfx.play("levelup", c.global_position, 0.8, 0.5)
	_decal(pj, c.global_position, 4.0, 3, 0.0, {"col": Color(1.0, 0.62, 0.25), "grow_t": 0.45})
	var steam = Color(1.0, 0.66, 0.3, 0.8)
	pj.every(1.6, 0.1, func(_i, _k):
		if pj.live(c):
			for k in 2:
				var q = c.global_position + UP * randf_range(0.6, 1.6) + _rnd_dir() * 0.35
				_puff(pj, q, randf_range(0.5, 0.8), 0.9, UP * randf_range(2.0, 3.5) + _rnd_dir() * 0.5, steam, 1))
	pj.every(15.0, 0.5, func(i, _k):
		if pj.live(c) and i > 3:
			var sh = _bone_world(c, "LeftShoulder" if i % 2 == 0 else "RightShoulder", c.global_position + UP * 1.4)
			_puff(pj, sh + UP * 0.1, 0.35, 1.0, UP * 1.4, Color(1.0, 0.7, 0.35, 0.5), 1))
	var hb = pj.bone_attach(c, "Head")
	if hb:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for sx in [-1.0, 1.0]:
			var pts = []
			var radii = []
			for i in 22:
				var s = i / 21.0
				var a = s * TAU * 2.1 * sx
				var rr = 0.003 + 0.017 * s
				pts.append(Vector3(sx * 0.058 + cos(a) * rr, 0.055 + sin(a) * rr, 0.085))
				radii.append(0.0022)
			_tube_add(st, pts, radii, 4, Color(0.78, 0.1, 0.1))
		st.generate_normals()
		var mk = _gi(st.commit(), _cel(false))
		_ipar(mk, {"k_tint": Color.WHITE})
		hb.add_child(mk)
		pj.free_after(15.0, hb)


## Bubun Baika (ref): gerçek kol ve yumruk devleşir; büyürken kola mavi chakra kurdeleleri dolanır;
## yumruk yere iner: yumruk göçüğü + çatlak, yükselen toz sütunu, kaya
static func bubun_baika_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var dur = 20.0 if c is Player else 8.0
	if c is Player:
		Buffs.add("bubun_baika", dur, {"reach": 2.6, "melee": 1.25})
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 14.0)
	pj.anim(c, "throw", 0.75)
	pj._aki_arm(c, true, [1.6, 1.85, 4.0], 0.3, dur, 0.45, true)   # el ~x12 (anime: yumruk gövdeden büyük)
	# kola dolanan kurdeleler: ön kol kemiğinde (büyümeyi alır)
	var root = Node3D.new()
	_on_bone(pj, c, "RightLowerArm", root, 0.8)
	for k in 3:
		var pts = []
		var sides = []
		var ws = []
		var ph = TAU * k / 3.0
		for i in 19:
			var s = i / 18.0
			var a = ph + s * TAU * 1.5
			pts.append(Vector3(cos(a) * 0.075, -0.05 + s * 0.38, sin(a) * 0.075))
		for i in 19:
			var tg: Vector3 = (pts[mini(i + 1, 18)] - pts[maxi(i - 1, 0)]).normalized()
			sides.append(tg.cross(Vector3(pts[i].x, 0, pts[i].z).normalized()).normalized())
			ws.append(0.03)
		var mi = _gi(_strip_mesh(pts, sides, ws), _wisp_mat())
		_ipar(mi, {"k_col": Color(0.62, 0.9, 1.0), "k_deep": Color(0.25, 0.55, 1.0), "k_a": 1.0, "k_mode": 0.0, "k_seed": randf() * 9.0})
		root.add_child(mi)
		var t2 = mi.create_tween()
		t2.tween_interval(0.45)
		t2.tween_method(_pf(mi, "k_a"), 1.0, 0.0, 0.3)
	var rt = root.create_tween()
	rt.tween_property(root, "rotation:y", TAU, 0.75)
	pj.after(0.58, func():
		if not pj.live(c):
			return
		var hp = pj._aki_hand(c)
		var at = pj.gp(hp)
		if hp.distance_to(at) > 4.0 and pj.live(tt):
			at = pj.gp(tt.global_position)
		_decal(pj, at, 3.4, 2, 6.0, {"dir": _flat(at - c.global_position), "grow_t": 0.1})
		_decal(pj, at, 6.0, 0, 5.0, {"grow_t": 0.2, "a": 0.8})
		for k in 9:
			_puff(pj, at + _rnd_dir() * randf_range(0.5, 1.8) + UP * 0.4, randf_range(1.2, 1.8), 1.0, UP * randf_range(3.0, 6.0) + _rnd_dir() * 1.2, DUST, 0, k * 0.02)
		_dust_ring(pj, at, 1.0, 4.0, 10, 1.1, 0.6)
		_chunks(pj, at, 12, 0.5, 9.0, GND, 1.0)
		pj.hit(c, at + UP, 3.6, pj.inf(c, "bubun_baika_no_jutsu", 1.6, {"knock": 10.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.08}))
		pj.shake(0.7)
		Sfx.play("boom", at, 0.7))


## Chō Baika: dağ gibi devleşme — iri mavi chakra kurdele sarmalı yükselir, beden x7 olur; her ağır adım yerde iz bırakır
## (ayak göçüğü, toz halkası, bej sarsıntı halkası)
static func cho_baika_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_chakra_coil(pj, c, 6, 1.4, 3.2, 1.1, 4.0)
	if not c is Player:
		return
	c.combat.modes.set_size(7.0, 15.0)
	Buffs.add("cho_baika", 15.0, {"melee": 1.8, "speed": 0.8, "armor": 0.75, "reach": 3.6})
	var p0 = pj.gp(c.global_position)
	_dust_ring(pj, p0, 1.5, 9.0, 16, 2.4, 0.9)
	_decal(pj, p0, 9.0, 3, 0.0, {"col": Color(0.95, 0.88, 0.7), "grow_t": 0.7})
	pj.every(15.0, 0.9, func(_i, _k):
		if not is_instance_valid(c):
			return
		var p = pj.gp(c.global_position)
		if Vector2(c.velocity.x, c.velocity.z).length() > 1.0:
			var d = _flat(c.velocity)
			_decal(pj, p + _side(d) * 0.9, 2.6, 2, 4.0, {"dir": d, "scale": Vector3(0.8, 1.0, 1.2), "grow_t": 0.08})
			_dust_ring(pj, p, 1.5, 5.0, 10, 1.6, 0.55)
			_decal(pj, p, 8.0, 3, 0.0, {"col": Color(0.92, 0.84, 0.66), "grow_t": 0.35, "a": 0.8})
			pj.hit(c, p + UP, 8.0, pj.inf(c, "cho_baika_no_jutsu", 0.5, {"knock": 8.0, "launch": 3.0, "kind": "heavy"}))
			pj.shake(0.35))
	Hud.msg("Chō Baika! (15 sn dağ gibi)", Color(1, 0.8, 0.5))


## Chōharite (ref): gerçek kol + açık avuç devleşir, avuç mavi chakra pusuyla sarılır; yandan savrulan tokat: önde mavi-beyaz
## basınç yayı, yerde yarım daire süpürme izi, öne savrulan toz dalgası
static func choharite(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	pj.busy(c, 1.0)
	var _tt = pj.tg(c, t, 10.0)
	pj.anim(c, "hook", 0.85)
	pj._aki_arm(c, true, [1.4, 1.7, 3.8], 0.28, 0.6, 0.4, false, true)   # açık avuç ~x9
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var bw = weakref(ba)
		pj.every(1.0, 0.05, func(_i, _k):
			var b2 = bw.get_ref()
			if b2 == null:
				return
			var hp: Vector3 = (b2 as Node3D).global_position
			var sc = (b2 as Node3D).global_basis.get_scale().x
			_puff(pj, hp + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * sc * 0.06, sc * 0.16, 0.4, UP * 0.6 + _rnd_dir() * 0.4, Color(0.55, 0.82, 1.0, 0.7), 1))
		pj.free_after(1.1, ba)
	pj.after(0.42, func():
		if not pj.live(c):
			return
		var hp = pj._aki_hand(c)
		var arc = _gi(_arc_mesh(4.0, 100.0, -100.0, 1.1, 30), _ink(false))
		_put(pj, arc, Vector3(c.global_position.x, hp.y, c.global_position.z))
		arc.global_basis = _basis(d)
		_ipar(arc, {"k_col": Color(0.82, 0.95, 1.0), "k_edge": Color(0.25, 0.5, 0.95), "k_a": 0.9, "k_grow": 0.0, "k_tail": 1.4})
		var tw = arc.create_tween()
		tw.tween_method(_pf(arc, "k_grow"), 0.0, 1.3, 0.16)
		tw.tween_method(_pf(arc, "k_a"), 0.9, 0.0, 0.25)
		tw.tween_callback(arc.queue_free)
		var g = pj.gp(c.global_position)
		_decal(pj, g, 6.0, 4, 3.0, {"dir": d, "grow_t": 0.18})
		for k in 12:
			var a = deg_to_rad(randf_range(-80.0, 80.0))
			var dv = d.rotated(UP, a)
			_puff(pj, g + dv * randf_range(1.5, 3.0) + UP * 0.4, randf_range(0.9, 1.3), 0.8, dv * randf_range(4.0, 7.0) + UP * 0.6, DUST, 0, randf() * 0.06)
		_dir_ring(pj, hp, d, 2.2, Color(0.75, 0.9, 1.0), 0.3, 2.0)
		for e in pj.enemies_near(c, c.global_position, 6.0):
			var to = e.global_position - c.global_position
			to.y = 0.0
			if to.length() < 0.5 or to.normalized().dot(d) > -0.15:   # önündeki yarım daire
				pj.hit(c, e.global_position + UP, e.radius + 0.3, pj.inf(c, "choharite", 1.3, {"knock": 14.0, "launch": 0.0, "kind": "heavy", "hitstop": 0.1}))
		pj.shake(0.6)
		Sfx.play("boom", c.global_position, 1.1))


# ================================================================== JŪGO teknikleri
## Juin: Bakusatsu Kyō (ref): sırttan jetlerle sıçrar, devleşen piston kolla tepeden iner — dev kara şok dalgası:
## art arda açılan kara halkalar, kara çatlak, kara-mor darbe yıldızı, koyu toz, kaya
static func juin_bakusatsu_kyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.15)
	var id = "juin_bakusatsu_kyo"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var L = c.global_position.distance_to(tt.global_position) if tt else 5.0
	if c is CharacterBody3D:
		c.velocity = d * clampf(L / 0.5, 4.0, 26.0) * 0.8 + UP * 13.0
	_jets(pj, c, 0.75, 4)
	pj._aki_arm(c, true, [1.25, 1.7, 1.9], 0.25, 0.55, 0.3, true)
	pj.anim(c, "slash_c", 1.1)
	Sfx.play("wind", c.global_position, 0.8)
	pj.after(0.42, func():   # tepeden dalış
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var to: Vector3 = pj.gp(cc.global_position + cc.face_dir() * 1.5)
		if x and pj.live(x):
			to = x.global_position
		var v: Vector3 = to - cc.global_position
		if cc is CharacterBody3D:
			cc.velocity = v.normalized() * maxf(v.length() / 0.16, 22.0)
		for k in 4:
			_streak(pj, cc.global_position + UP + _rnd_dir() * 0.6 - v.normalized() * 1.5, v, 2.6, 0.05, Color(0.3, 0.2, 0.35), 0.22)
		pj.anim(cc, "hook", 1.8))
	pj.after(0.62, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		var at: Vector3 = pj.gp(cc.global_position + cc.face_dir() * 1.0)
		var x = tw.get_ref() if tw else null
		if x and pj.live(x) and x.global_position.distance_to(cc.global_position) < 4.5:
			at = pj.gp(x.global_position)
		var blk = Color(0.05, 0.02, 0.07)
		for k in 3:   # kara dalga: yerde art arda açılan kara halkalar
			var ring_r = 15.0 - k * 3.0
			pj.after(k * 0.07, func():
				_decal(pj, at, ring_r, 3, 0.0, {"col": blk, "grow_t": 0.42, "lift": 0.04 + k * 0.01}))
		_decal(pj, at, 8.0, 0, 6.0, {"col": Color(0.03, 0.02, 0.04), "grow_t": 0.1})
		_star(pj, at + UP * 0.9, 2.6, Color(0.12, 0.06, 0.16), Color(0.55, 0.3, 0.6), 0.25)
		_dust_ring(pj, at, 1.0, 6.0, 12, 1.4, 0.6, Color(0.36, 0.32, 0.36))
		_chunks(pj, at, 16, 0.55, 13.0, GND, 0.7, 1.0)
		pj.shake(1.0)
		Sfx.play("boom", at, 0.6)
		pj.hit(cc, at + UP * 0.8, 5.2, pj.inf(cc, id, 3.6, {"knock": 22.0, "launch": 7.0, "kind": "heavy", "hitstop": 0.12})))


## Funsai (ref): sırtta altı jet borusu, rakibe atılır; art arda yumruk/savuruş — her vuruşta dirsekten itki + küçük darbe karesi,
## son yumrukta ezici darbe
static func funsai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 1.7)
	var id = "funsai"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	_jets(pj, c, 1.65, 6)
	pj._jugo_piston(c, 1.7, 1.5)
	if c is CharacterBody3D:
		c.velocity = d * 30.0 + UP * 1.0
	Sfx.play("wind", c.global_position, 1.1)
	var keys = ["jab", "hook", "slash_a", "jab", "slash_b", "hook"]
	for k in 6:
		pj.after(0.3 + k * 0.17, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var fd: Vector3 = cc.face_dir()
			if x and pj.live(x):
				fd = pj._face(cc, x)
				var gap = cc.global_position.distance_to(x.global_position)
				if cc is CharacterBody3D:
					cc.velocity = fd * clampf((gap - 1.3) / 0.12, 0.0, 30.0)   # jetler arayı kapatır
			pj.anim(cc, keys[k], 2.0)
			var at = cc.global_position + UP * 1.1 + fd * 1.3
			var last = k == 5
			if last:
				_thrust(pj, cc, fd)
				pj.shake(0.7)
			var hs = pj.hit(cc, at, 2.2, pj.inf(cc, id, 1.7 if last else 0.42, {"knock": 22.0 if last else 1.0, "launch": 3.0 if last else 0.0, "kind": "heavy" if last else "light", "hitstop": 0.09 if last else 0.03}))
			if last:
				_crush(pj, at, fd, 1.3, true)
			elif not hs.is_empty():
				_star(pj, at + _rnd_dir() * 0.2, 0.8, Color(1.0, 0.92, 0.78), INK_D, 0.14)
				_dir_ring(pj, at, fd, 0.9, Color(1.0, 0.82, 0.6), 0.2, 0.6)
			else:
				_streak(pj, at - fd * 1.2, fd, 1.4, 0.04, Color(1.0, 0.9, 0.75), 0.15)
			Sfx.play("punch", at, 0.7 if last else 1.1 + k * 0.05))


## Kassokuken: Reishiki (ref): piston ön kol; ilk yumrukta dirsekten itki, savrulanın peşinden kol devleşerek atılır,
## ikinci yumruk: ezici darbe karesi + uzun yönlü basınç halkaları + hız çizgileri
static func kassokuken_reishiki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.25)
	var id = "kassokuken_reishiki"
	var _d = pj._jump_at(c, tt, 0.2, 14.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	pj._jugo_piston(c, 0.5, 1.6)
	pj.anim(c, "jab", 1.6)
	Sfx.play("punch", c.global_position, 0.9)
	pj.after(0.2, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var fd: Vector3 = cc.face_dir()
		_thrust(pj, cc, fd)
		var at = cc.global_position + UP * 1.1 + fd * 1.3
		var hs = pj.hit(cc, at, 2.3, pj.inf(cc, id, 1.1, {"knock": 15.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.07, "dir": fd}))
		_crush(pj, at, fd, 0.8, not hs.is_empty()))
	pj.after(0.42, func():   # peşinden atılış: kol devleşir
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var fd: Vector3 = pj._face(cc, x) if x and pj.live(x) else cc.face_dir()
		pj._aki_arm(cc, true, [1.3, 1.75, 2.3], 0.2, 0.42, 0.3, true)
		_jets(pj, cc, 0.5, 4)
		var gap = cc.global_position.distance_to(x.global_position) if x and pj.live(x) else 6.0
		if cc is CharacterBody3D:
			cc.velocity = fd * clampf((gap - 1.6) / 0.3, 8.0, 34.0) + UP * 0.5
		for k in 5:
			_streak(pj, cc.global_position + UP * randf_range(0.6, 1.8) + _side(fd) * randf_range(-0.8, 0.8) - fd * 2.0, fd, 2.4, 0.04, Color(1.0, 0.9, 0.75), 0.25)
		pj.anim(cc, "hook", 1.2))
	pj.after(0.76, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var fd: Vector3 = cc.face_dir()
		if cc is CharacterBody3D:
			cc.velocity = fd * 3.0
		_thrust(pj, cc, fd)
		var at = cc.global_position + UP * 1.1 + fd * 1.7
		_crush(pj, at, fd, 1.6, true)
		for k in 3:
			_dir_ring(pj, at + fd * (0.8 + k * 1.1), fd, 1.8 + k * 0.6, Color(1.0, 0.85, 0.6), 0.32, 1.5, k * 0.05)
		pj.shake(0.8)
		Sfx.play("boom", at, 0.9)
		pj.hit(cc, at, 3.0, pj.inf(cc, id, 2.8, {"knock": 28.0, "launch": 3.5, "kind": "heavy", "hitstop": 0.12, "dir": fd})))


## Kassokuken (jet yumruk): ön kol gerçek kemikle kabarır (piston), ön kolda üç etten jet deliği açılır, dirseğe doğru itki
## alevi püskürtür; yumruk: ezici darbe karesi
static func jugo_jet_yumruk(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 0.7)
	pj._jugo_piston(c, 0.7, 1.6)
	_arm_vents(pj, c, 0.7)
	var d = pj._jump_at(c, tt, 0.3, 12.0)
	for k in 5:
		pj.after(k * 0.05, func():
			if pj.live(c):
				_streak(pj, pj.hand_pos(c, true) - d * 1.6 + UP * randf_range(-0.3, 0.3), d, 1.6, 0.04, Color(1.0, 0.85, 0.6), 0.16))
	pj.after(0.25, func():
		if pj.live(c):
			var at = c.global_position + UP * 1.1 + d * 1.3
			var hs = pj.hit(c, at, 2.4, pj.inf(c, "jugo_jet_yumruk", 1.8, {"knock": 22.0, "kind": "heavy", "hitstop": 0.1}))
			_crush(pj, at, d, 1.2, not hs.is_empty()))
	Sfx.play("punch", c.global_position, 0.7)


## Ön kol jet delikleri: ön kol kemiğine bağlı üç etten ağız, dirseğe doğru (kemik -Y) itki alevi
static func _arm_vents(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var root = Node3D.new()
	_on_bone(pj, c, "RightLowerArm", root, dur)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mouths = []
	for k in 3:
		var a = TAU * k / 3.0 + 0.4
		var rv = Vector3(cos(a), 0, sin(a))
		var o = rv * 0.05 + UP * 0.16
		var e = rv * 0.075 + UP * 0.03
		_tube_add(st, [o, o.lerp(e, 0.5) + rv * 0.012, e], [0.026, 0.034, 0.04], 6, Color.WHITE)
		_tube_add(st, [e + UP * 0.012, e - UP * 0.012], [0.045, 0.04], 6, Color(0.14, 0.09, 0.09))
		mouths.append(e - UP * 0.012)
	st.generate_normals()
	var body = _gi(st.commit(), _sage(true))
	_sage_set(body, 1)
	root.add_child(body)
	for mp in mouths:
		var fl = _gi(_xstrip(), _flare_mat())
		_ipar(fl, {"k_a": 1.0, "k_seed": randf() * 9.0})
		root.add_child(fl)
		fl.position = mp
		fl.basis = _yto(Vector3.DOWN) * Basis.from_scale(Vector3(0.08, 0.38, 0.08))
		var tw = fl.create_tween().set_loops()
		tw.tween_property(fl, "scale", Vector3(0.09, 0.45, 0.09), 0.05)
		tw.tween_property(fl, "scale", Vector3(0.07, 0.3, 0.07), 0.05)
	root.scale = Vector3.ONE * 0.1
	var t0 = root.create_tween()
	t0.tween_property(root, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t0.tween_interval(maxf(0.0, dur - 0.3))
	t0.tween_property(root, "scale", Vector3.ONE * 0.1, 0.16)


## Saibō Kyūin: çevreden et-turuncu hücre parçacıkları ve ince et lifleri bedene emilir; onarımda ten kısa süre Senninka lekeleriyle
## kabarır, ayak altında turuncu halka
static func jugo_cekim(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	for k in 14:
		pj.after(k * 0.06, func():
			if pj.live(c):
				var a = k * TAU / 14.0
				var q = c.global_position + Vector3(cos(a) * 4.0, 0.5 + randf() * 1.5, sin(a) * 4.0)
				var to = c.global_position + UP * 1.1
				var dv = (to - q)
				_tongue(pj, q, dv, dv.length() * 0.55, 0.14, 0.45, Color(0.95, 0.72, 0.55), Color(0.55, 0.35, 0.28), 0, dv * 0.6)
				for m in 3:
					_puff(pj, q + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), 0.24, 0.5, dv / 0.5, Color(1.0, 0.7, 0.45), 2, m * 0.04))
	pj.after(0.9, func():
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.4)
			_sage_skin(pj, c, 1.1, 1, 0.3)
			_decal(pj, c.global_position, 3.0, 3, 0.0, {"col": Color(1.0, 0.65, 0.35), "grow_t": 0.4})
			for k in 8:
				_puff(pj, c.global_position + UP * randf_range(0.5, 1.8) + _rnd_dir() * 0.4, 0.3, 0.6, UP * 1.5 + _rnd_dir(), Color(1.0, 0.8, 0.55), 2, k * 0.03))
	Sfx.play("heal", c.global_position, 0.8)


## Masakari: ön kol kabarır, üstünden etten (gri-turuncu, kara izli) hilal balta ağzı çıkar; 220° biçme: et-turuncu yay izi,
## yerde iki kesik yayı, sıçrayan taş kırıntısı
static func jugo_balta_kol(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	pj._jugo_piston(c, 0.9, 1.5)
	_axe_blade(pj, c, 0.9)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var d = c.face_dir()
		var arc = _gi(_arc_mesh(3.0, -110.0, 110.0, 0.9, 32), _ink(false))
		_put(pj, arc, c.global_position + UP * 1.1)
		arc.global_basis = _basis(_flat(d)) * Basis(Vector3.FORWARD, deg_to_rad(-8.0))
		_ipar(arc, {"k_col": Color(1.0, 0.86, 0.7), "k_edge": Color(0.55, 0.2, 0.08), "k_a": 1.0, "k_grow": 0.0, "k_tail": 1.2})
		var tw = arc.create_tween()
		tw.tween_method(_pf(arc, "k_grow"), 0.0, 1.3, 0.14)
		tw.tween_method(_pf(arc, "k_a"), 1.0, 0.0, 0.25)
		tw.tween_callback(arc.queue_free)
		var g = pj.gp(c.global_position)
		for k in 2:
			var cut = _gi(_arc_mesh(2.6 + k * 0.9, -100.0, 100.0, 0.12, 28), _ink(false))
			_put(pj, cut, g + UP * 0.04)
			cut.global_basis = _basis(_flat(d))
			_ipar(cut, {"k_col": Color(0.12, 0.08, 0.06), "k_edge": Color(0.05, 0.03, 0.02), "k_a": 0.9, "k_grow": 0.0, "k_tail": 0.0})
			var t2 = cut.create_tween()
			t2.tween_method(_pf(cut, "k_grow"), 0.0, 1.0, 0.16)
			t2.tween_interval(2.5)
			t2.tween_method(_pf(cut, "k_a"), 0.9, 0.0, 0.7)
			t2.tween_callback(cut.queue_free)
		for k in 6:
			var dv = _flat(d).rotated(UP, deg_to_rad(randf_range(-100.0, 100.0)))
			_chunks(pj, g + dv * 3.0, 1, 0.3, 5.0)
		Combat.hit_zone(c, c.global_position, d, 4.0, 220.0, 2.5, pj.inf(c, "jugo_balta_kol", 2.0, {"knock": 16.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1}))
		pj.shake(0.6))
	Sfx.play("blade", c.global_position, 0.6)


## Et balta ağzı: ön kol kemiğine bağlı, kemik boyunca uzanan hilal levha (iki yüz + kenar), kalın sırt
static func _axe_blade(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var mesh: ArrayMesh
	if _cache.has("mesh:axe"):
		mesh = _cache["mesh:axe"]
	else:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outline = []
		var n = 14
		for i in n + 1:   # dış hilal: bileğe yakın uzun, dirseğe doğru daralan
			var s = float(i) / n
			var y = lerpf(0.02, 0.36, s)
			var out = 0.08 + 0.3 * sin(PI * pow(s, 0.8))
			outline.append(Vector2(y, out))
		for i in range(n, -1, -1):
			var s = float(i) / n
			outline.append(Vector2(lerpf(0.06, 0.3, s), 0.06))
		var th = 0.018
		var cen = Vector3(0, 0.19, 0.14)
		for i in outline.size() - 1:
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[i + 1]
			var pa = Vector3(0, a.x, a.y)
			var pb = Vector3(0, b.x, b.y)
			for sx in [-1.0, 1.0]:
				var off = Vector3(sx * th, 0, 0)
				var edge_th = 0.4 if a.y > 0.12 else 1.0
				for p in [cen + off * 0.8, pa + off * edge_th, pb + off * edge_th]:
					st.set_color(Color.WHITE)
					st.add_vertex(p)
			for p in [pa + Vector3(th, 0, 0) * 0.4, pa - Vector3(th, 0, 0) * 0.4, pb - Vector3(th, 0, 0) * 0.4, pa + Vector3(th, 0, 0) * 0.4, pb - Vector3(th, 0, 0) * 0.4, pb + Vector3(th, 0, 0) * 0.4]:
				st.set_color(Color(0.95, 0.9, 0.85))
				st.add_vertex(p)
		_tube_add(st, [Vector3(0, 0.0, 0.05), Vector3(0, 0.2, 0.07), Vector3(0, 0.36, 0.06)], [0.03, 0.04, 0.025], 6, Color.WHITE)
		st.generate_normals()
		mesh = st.commit()
		_cache["mesh:axe"] = mesh
	var mi = _gi(mesh, _sage(true))
	_sage_set(mi, 1)
	_on_bone(pj, c, "RightLowerArm", mi, dur)
	mi.scale = Vector3(1, 0.2, 0.2)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, dur - 0.4))
	tw.tween_property(mi, "scale", Vector3(1, 0.2, 0.2), 0.18)


## Taren Fujizuho: sırtta jetler çoğalır, kol gerçek kemikle kalınlaşıp büyür, yumruktan etten top namlusu uzar; doğa enerjisi
## namluya toplanır, ateşte turuncu-beyaz enerji sütunu + yol boyunca açılan halkalar, sonda ezici patlama
static func jugo_top_kol(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 34.0)
	pj._jugo_piston(c, 1.0, 1.7)
	pj._aki_arm(c, true, [1.2, 1.35, 1.0], 0.2, 0.6, 0.2, true)
	_cannon(pj, c, 1.0)
	_jets(pj, c, 1.0, 6)
	_nature_gather(pj, func(): return pj.hand_pos(c, true) if is_instance_valid(c) else Vector3.ZERO, 0.5, 14, 2.6)
	pj.after(0.5, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var d = pj.aim_at(c, tt, from)
		_cannon_blast(pj, from, d, 28.0)
		Combat.hit_zone(c, from - UP * 1.1, d, 28.0, 10.0, 2.5, pj.inf(c, "jugo_top_kol", 2.6, {"knock": 18.0, "kind": "heavy", "hitstop": 0.1}))
		pj.shake(0.8))
	Sfx.play("boom", c.global_position, 1.0)


## Et top namlusu: el kemiğine bağlı (+Y parmak yönü), kalın halkalı ağız, koyu iç delik, kara izli et
static func _cannon(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var mesh: ArrayMesh
	if _cache.has("mesh:cannon"):
		mesh = _cache["mesh:cannon"]
	else:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tube_add(st, [Vector3(0, -0.06, 0), Vector3(0, 0.12, 0), Vector3(0, 0.3, 0), Vector3(0, 0.42, 0)], [0.08, 0.1, 0.105, 0.11], 10, Color.WHITE)
		_tube_add(st, [Vector3(0, 0.4, 0), Vector3(0, 0.47, 0)], [0.14, 0.135], 10, Color(0.9, 0.85, 0.8))
		_tube_add(st, [Vector3(0, 0.44, 0), Vector3(0, 0.475, 0)], [0.085, 0.085], 10, Color(0.06, 0.03, 0.03))
		for k in 3:
			_tube_add(st, [Vector3(0, 0.1 + k * 0.1, 0), Vector3(0, 0.13 + k * 0.1, 0)], [0.115, 0.115], 10, Color(0.6, 0.55, 0.52))
		st.generate_normals()
		mesh = st.commit()
		_cache["mesh:cannon"] = mesh
	var mi = _gi(mesh, _sage(true))
	_sage_set(mi, 2)
	_on_bone(pj, c, "RightHand", mi, dur)
	mi.scale = Vector3(0.6, 0.1, 0.6)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, dur - 0.5))
	tw.tween_property(mi, "scale", Vector3(0.6, 0.1, 0.6), 0.2)


## Namlu ateşi: kalın turuncu-beyaz çekirdek sütunu (kendi alev şeridi, kameraya yakın incelir), çevresinde burgulu doğa enerjisi
## dilleri, yol boyunca yönlü halkalar, sonda yıldız + kaya + toz
static func _cannon_blast(pj: PathJutsu, from: Vector3, d: Vector3, len_: float) -> void:
	var dd = d.normalized()
	var core = _gi(_xstrip(), _flare_mat())
	_put(pj, core, from)
	var b0 = _yto(dd)
	core.global_basis = b0 * Basis.from_scale(Vector3(1.6, len_ * 0.2, 1.6))
	_ipar(core, {"k_a": 1.0, "k_seed": randf() * 9.0})
	var tw = core.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(core):
			core.global_basis = b0 * Basis.from_scale(Vector3(1.6 - u * 0.6, len_ * lerpf(0.2, 1.15, sqrt(minf(1.0, u * 3.0))), 1.6 - u * 0.6)), 0.0, 1.0, 0.45)
	tw.parallel().tween_method(_pf(core, "k_a"), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(core.queue_free)
	var sd = _side(dd)
	for k in 6:
		var a = TAU * k / 6.0
		var off = (sd * cos(a) + sd.cross(dd).normalized() * sin(a)) * 0.45
		_tongue(pj, from + off, dd, len_ * randf_range(0.45, 0.7), 0.35, 0.4, Color(1.0, 0.75, 0.4), Color(0.75, 0.3, 0.08), 1, dd * 3.0)
	for k in 6:
		_dir_ring(pj, from + dd * (2.0 + k * 4.2), dd, 1.6 + k * 0.15, Color(1.0, 0.78, 0.5), 0.35, 1.5, k * 0.03)
	var end = from + dd * len_
	pj.after(0.12, func():
		_crush(pj, end, dd, 1.8, true)
		var g = pj.gp(end)
		if end.y - g.y < 3.0:
			_decal(pj, g, 4.5, 0, 5.0, {"col": Color(0.12, 0.06, 0.03), "grow_t": 0.1}))
	_puff(pj, from - dd * 0.3, 1.1, 0.5, -dd * 2.0 + UP, Color(0.75, 0.72, 0.7, 0.85), 0)


## Jet Booster Jump: sırttan etten kanatlar açılır (kemik parmaklı, arası et zar, kara izli), kökteki jet deliklerinden itki;
## dalış yolunda duman izi, iniş: krater + toz + kaya
static func jugo_kanat(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.8)
	_flesh_wings(pj, c, 0.8)
	if tt == null:
		return
	var d = pj._jump_at(c, tt, 3.0, 22.0)
	pj.every(0.6, 0.05, func(_i, _k):
		if pj.live(c):
			_puff(pj, c.global_position + UP * 1.3 - d * 0.7, 0.5, 0.45, -d * 3.0 + UP * 0.3, Color(0.74, 0.72, 0.7, 0.8), 0), Callable())
	pj.after(0.6, func():
		if pj.live(c):
			var g = pj.gp(c.global_position)
			_decal(pj, g, 4.0, 0, 5.0, {"grow_t": 0.12})
			_dust_ring(pj, g, 0.8, 4.0, 10, 1.2, 0.55)
			_chunks(pj, g, 9, 0.45, 8.0)
			var hs = pj.hit(c, c.global_position + UP, 3.0, pj.inf(c, "jugo_kanat", 1.8, {"knock": 16.0, "launch": 5.0, "kind": "heavy"}))
			if not hs.is_empty():
				_star(pj, c.global_position + UP + d * 0.8, 1.4, Color(1.0, 0.93, 0.78), INK_D, 0.2))
	Sfx.play("wind", c.global_position, 1.0)


## Etten jet kanatlar: üst göğüs kemiğine bağlı; her yanda üç kemik parmak (boru) + aralarında et zar, kökte itki alevi
static func _flesh_wings(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var root = Node3D.new()
	_on_bone(pj, c, "UpperChest", root, dur, Vector3(0, 1.35, -0.2))
	for sx in [-1.0, 1.0]:
		var key = "mesh:fwing_%d" % int(sx)
		var mesh: ArrayMesh
		if _cache.has(key):
			mesh = _cache[key]
		else:
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var o = Vector3(sx * 0.08, 0.05, -0.12)
			var tips = [Vector3(sx * 1.1, 0.55, -0.45), Vector3(sx * 1.25, 0.1, -0.55), Vector3(sx * 0.95, -0.35, -0.5)]
			for tp in tips:
				var mid = o.lerp(tp, 0.45) + Vector3(0, 0.12, -0.05)
				_tube_add(st, [o, mid, tp], [0.04, 0.03, 0.008], 6, Color(0.9, 0.86, 0.82))
			for k in 2:   # zar: iki parmak arası, aşağı sarkan kenar
				var a: Vector3 = tips[k]
				var b: Vector3 = tips[k + 1]
				var sag = a.lerp(b, 0.5).lerp(o, 0.3)
				for tri in [[o, a, sag], [o, sag, b], [a, b, sag]]:
					for p in tri:
						st.set_color(Color.WHITE)
						st.add_vertex(p)
			st.generate_normals()
			mesh = st.commit()
			_cache[key] = mesh
		var w = _gi(mesh, _sage(false))
		_sage_set(w, 1)
		root.add_child(w)
		var fl = _gi(_xstrip(), _flare_mat())
		_ipar(fl, {"k_a": 1.0, "k_seed": randf() * 9.0})
		root.add_child(fl)
		fl.position = Vector3(sx * 0.12, 0.02, -0.16)
		fl.basis = _yto(Vector3(sx * 0.2, -0.45, -1.0)) * Basis.from_scale(Vector3(0.2, 0.75, 0.2))
		var ft = w.create_tween().set_loops()
		ft.tween_property(w, "rotation:y", 0.12 * sx, 0.12)
		ft.tween_property(w, "rotation:y", -0.08 * sx, 0.12)
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, dur - 0.38))
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.18)


## Senninka (kanon): doğa enerjisi bedeni dönüştürür — gri-turuncu, kara lanet izli ten lekeleri kemikler boyunca yayılır,
## kollar gerçek kemikle kalınlaşır; açılışta turuncu doğa enerjisi dilleri ve halka. 2. aşama koyu gri, daha geniş.
## Bedel: ara ara öldürme nöbeti, en yakındakine saldırırsın (AI aynı kural)
static func jugo_ofke(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var is_p = c is Player
	var in1 = (is_p and Buffs.has("jugo_senninka")) or (not is_p and c.get("buffs") != null and c.buffs.has("jugo_senninka"))
	var stage = 2 if in1 else 1
	pj.busy(c, 0.9)
	var DUR = 18.0
	var p0 = pj.gp(c.global_position)
	_decal(pj, p0, 8.0 + stage * 4.0, 3, 0.0, {"col": Color(0.95, 0.5, 0.18) if stage == 1 else Color(0.25, 0.1, 0.08), "grow_t": 0.5})
	for k in 10:
		var a = TAU * k / 10.0
		var dv = Vector3(cos(a), 0, sin(a))
		_tongue(pj, p0 + dv * 0.6, (UP * 2.0 + dv).normalized(), randf_range(1.6, 2.4) + stage * 0.4, 0.4, 0.7, Color(1.0, 0.68, 0.32), Color(0.6, 0.22, 0.06), 1, UP * 0.8)
	_sage_skin(pj, c, DUR, stage, 0.6)
	var m = c.get("model")
	if m and m.get("overlay") != null:   # dönüşen kollar kalınlaşır (gerçek kemik)
		var bk = 1.3 if stage == 1 else 1.7
		var ov = m.overlay
		var gt = m.create_tween()
		gt.tween_method(func(u: float):
			if is_instance_valid(ov):
				ov.bulk["LeftUpperArm"] = lerpf(1.0, bk, u)
				ov.bulk["RightUpperArm"] = lerpf(1.0, bk, u), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pj.after(DUR, func():
			if is_instance_valid(m):
				m.overlay.bulk.erase("LeftUpperArm")
				m.overlay.bulk.erase("RightUpperArm"))
	var mods = {"melee": 1.35, "speed": 1.12, "armor": 0.8} if stage == 1 else {"melee": 1.7, "speed": 1.25, "armor": 0.65}
	var key = "jugo_senninka" if stage == 1 else "jugo_senninka2"
	if is_p:
		Buffs.remove("jugo_senninka")
		Buffs.add(key, DUR, mods.merged({"_name": "Senninka %d. aşama" % stage, "_desc": "doğa enerjisiyle dönüşmüş beden; öldürme nöbetleri gelebilir"}))
	elif c.has_method("add_buff"):
		c.add_buff(key, DUR, mods)
	Combat.popup_text(c.global_position + UP * 2.6, "Senninka %d" % stage, NATURE_O)
	# öldürme nöbetleri: ara ara kontrol gider, en yakındakine saldırırsın
	pj.every(DUR, 3.0, func(_i, _k):
		if not pj.live(c) or randf() > (0.25 if stage == 1 else 0.45):
			return
		var near: Node3D = null
		var bd = 9.0
		for f in pj.get_tree().get_nodes_in_group("fighters"):
			if f == c or f.is_dead() or f is TailedBeast:
				continue
			var dd = f.global_position.distance_to(c.global_position)
			if dd < bd:
				bd = dd
				near = f
		Combat.popup_text(c.global_position + UP * 2.8, "Öldürme dürtüsü!", Color(0.9, 0.25, 0.15))
		_star(pj, c.global_position + UP * 1.5, 1.6, Color(0.25, 0.05, 0.05), Color(0.95, 0.35, 0.15), 0.3)
		if is_p:
			c.input_locked = 1.6
		if near:
			var to = pj.gp(near.global_position - (near.global_position - c.global_position).normalized() * 1.0)
			var tw = c.create_tween()
			tw.tween_property(c, "global_position", to, 0.25)
			tw.tween_callback(func():
				if pj.live(near) and pj.live(c):
					pj.anim(c, "cross", 1.6)
					near.take_hit(pj.inf(c, "jugo_ofke", 0.9, {"knock": 12.0, "kind": "heavy", "melee": true, "attacker": c}))
					_crush(pj, near.global_position + UP * 1.1, _flat(near.global_position - c.global_position), 0.9, true)), Callable())
	pj.shake(0.8)
	Sfx.play("roar", c.global_position, 0.7)
