class_name DojutsuFXC
extends RefCounted
## Dōjutsu C grubu: Susanoo / Mangekyō teknikleri (Kakashi'nin Kamui Raikiri'si, Madara'nın Susanoo kılıçları, Itachi'nin
## Totsuka'sı ve Tsukuyomi'si, Obito'nun zincir / Kamui dövüşü, Shisui'nin Shunshin'i ve Kotoamatsukami'si).
## Görseller sıfırdan bu dosyada üretilir (kendi shader'ları + kendi geometrisi); ortak efekt yardımcısı kullanılmaz.
## Susanoo teknikleri sahibinin GERÇEK Susanoo'sunu kullanır (Susanoo.of, pozları, eli, chakra malzemesi); yalnız üstündeki
## efekt buradadır. Totsuka kılıcı mevcut modelden (MsArts._blade_mesh), Mangekyō deseni oyuncunun gerçek göz tasarımından.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme) ana ağaçtaki MsArts gövdelerinden satır satır taşındı.
## Okunurluk: hiçbir parça ekranı kaplamaz (kameraya yakın kısım incelir, boyutlar sınırlı); her parça koyu konturlu.

static var _cache := {}

const INK := Color(0.05, 0.04, 0.07)
const RAI := Color(0.6, 0.82, 1.0)
const SHISUI := Color(0.3, 0.95, 0.5)
const RED := Color(0.92, 0.1, 0.16)
const GOLD := Color(1.0, 0.8, 0.38)
const DIRT := Color(0.5, 0.42, 0.32)
const DUST := Color(0.66, 0.6, 0.5)
const IRON := Color(0.26, 0.26, 0.3)
const OBI_INK := Color(0.05, 0.04, 0.09)
const OBI_PALE := Color(0.6, 0.56, 0.7)
const YEL := Color(1.0, 0.8, 0.12)
const YEL_HOT := Color(1.0, 0.97, 0.72)
const BUBBLE := Color(0.55, 0.95, 0.92)

# ================================================================== shader kodları
const NOISE := """
float hh(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hh(i), hh(i + vec2(1.0, 0.0)), f.x), mix(hh(i + vec2(0.0, 1.0)), hh(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

const BILL := """
	if (bill > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
"""

## Cel gövde (kaya, zincir, damla, toz): düz iki ton + kenar bandı; kameraya çok yakın noktalı incelir; piksel bloklu dağılma
const CEL_SH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 shade : source_color = vec3(0.6, 0.6, 0.7);
uniform vec3 rim_c : source_color = vec3(0.0);
uniform float rim_amt = 0.0;
uniform float near_fade = 1.6;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void fragment() {
	float dist = -VERTEX.z;
	if (dist < near_fade && hh(floor(FRAGCOORD.xy) + vec2(seed)) > dist / near_fade) {
		discard;
	}
	if (fade > 0.001 && hh(floor(FRAGCOORD.xy * 0.25) + vec2(seed, 3.0)) < fade) {
		discard;
	}
	vec3 base = tint * COLOR.rgb;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float l = dot(wn, normalize(vec3(0.4, 0.85, 0.35)));
	vec3 col = l < 0.05 ? base * shade : base;
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, rim_c, step(0.62, fr) * rim_amt);
	ALBEDO = col;
}
"""

## Koyu kontur: ters kabuk, dünya kalınlığı ölçekten bağımsız
const LINE_SH := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec3 col : source_color = vec3(0.0);
uniform float width = 0.03;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += NORMAL * width / max(sc, vec3(0.001));
}

void fragment() {
	float dist = -VERTEX.z;
	if (dist < 1.6 && hh(floor(FRAGCOORD.xy) + vec2(seed)) > dist / 1.6) {
		discard;
	}
	if (fade > 0.001 && hh(floor(FRAGCOORD.xy * 0.25) + vec2(seed, 3.0)) < fade) {
		discard;
	}
	ALBEDO = col;
}
"""

## Parlak şerit / düz şekil (kesik izi, şimşek, ışın, alev dili, yıldız, halka): ortası beyaz çekirdek, renkli gövde, koyu
## cel kontur; kenar gürültüyle tırtıklı ve akar; dağılma gürültüyle yenir; kameraya yaklaşınca saydamlaşır
const GLOW_SH := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 core_c : source_color = vec3(1.0);
uniform vec3 mid_c : source_color = vec3(0.5, 0.7, 1.0);
uniform vec3 line_c : source_color = vec3(0.05);
uniform float alpha = 1.0;
uniform float jag = 0.3;
uniform float flow = 1.0;
uniform float streaks = 0.0;
uniform float radial = 0.0;
uniform float bill = 0.0;
uniform float near_fade = 2.5;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void vertex() {
BILL
}

void fragment() {
	float dist = -VERTEX.z;
	float across = radial > 0.5 ? length(UV - vec2(0.5)) * 2.0 : abs(UV.y - 0.5) * 2.0;
	float along = radial > 0.5 ? atan(UV.y - 0.5, UV.x - 0.5) * 1.3 : UV.x;
	float n = vn(vec2(along * 7.0 - TIME * flow * 2.0 + seed, across * 2.0 + seed * 0.37));
	float lim = 1.0 - jag * n;
	if (across > lim) {
		discard;
	}
	float e = across / max(lim, 0.01);
	vec3 col = mix(core_c, mid_c, smoothstep(0.22, 0.42, e));
	if (streaks > 0.0) {
		float s = vn(vec2(along * 3.0 - TIME * flow * 3.0, UV.y * streaks + seed));
		col = mix(col, core_c, step(0.7, s) * (1.0 - step(0.8, e)));
	}
	col = mix(col, line_c, step(0.84, e));
	float er = vn(vec2(along * 11.0, across * 5.0) + vec2(seed * 3.1, seed));
	if (er < fade) {
		discard;
	}
	float a = alpha;
	if (dist < near_fade) {
		a *= clamp((dist - 0.3) / near_fade, 0.0, 1.0);
	}
	ALBEDO = col;
	ALPHA = a;
}
"""

## Zemin izi: 0 çatlaklı çukur, 1 ışık hüzmesi yıldızı, 2 yarık şeridi, 3 tırtıklı halka
const DECAL_SH := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform int mode = 0;
uniform vec3 dark_c : source_color = vec3(0.08, 0.06, 0.06);
uniform vec3 glow_c : source_color = vec3(0.5, 0.7, 1.0);
uniform float cracks = 9.0;
uniform float ring_w = 0.06;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
instance uniform float grow = 1.0;

NOISE

void fragment() {
	float a = 0.0;
	vec3 col = dark_c;
	if (mode == 2) {
		float acr = abs(UV.y - 0.5) * 2.0;
		if (UV.x > grow) {
			discard;
		}
		float wid = (0.45 + 0.45 * vn(vec2(UV.x * 18.0 + seed, seed))) * clamp(sin(3.1416 * UV.x) * 3.0, 0.0, 1.0);
		if (acr > wid) {
			discard;
		}
		col = mix(glow_c, dark_c, step(0.4, acr / max(wid, 0.01)));
		a = 1.0;
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (r > 1.0) {
			discard;
		}
		float ang = atan(p.y, p.x) / 6.2832 + 0.5;
		if (mode == 0) {
			float sv = ang * cracks + seed;
			float sec = floor(sv);
			float len = (0.45 + 0.55 * hh(vec2(sec, seed))) * grow;
			float wig = (vn(vec2(r * 6.0, sec * 3.7)) - 0.5) * 0.5;
			float fa = abs(fract(sv + wig) - 0.5);
			float w = clamp(0.03 * cracks / max(r * 6.2832, 0.15), 0.0, 0.4) * (1.0 - r / max(len, 0.01));
			float crk = step(fa, w) * step(r, len);
			float pr = 0.3 * grow + (vn(p * 5.0 + vec2(seed)) - 0.5) * 0.12;
			float pit = step(r, pr);
			float rimb = step(r, pr + 0.05) - pit;
			a = max(max(crk, pit * 0.8), rimb);
			col = pit > 0.5 ? mix(dark_c, glow_c, 0.25 * (1.0 - r / max(pr, 0.01))) : (rimb > 0.5 ? glow_c : dark_c);
			col = mix(col, glow_c, crk * step(r, len * 0.35) * (1.0 - pit));
		} else if (mode == 1) {
			float rays = pow(abs(sin(ang * 3.1416 * cracks + seed)), 10.0) * (0.6 + 0.4 * vn(vec2(ang * 30.0, seed)));
			float core = 1.0 - smoothstep(0.1, 0.4, r);
			float v = max(rays * (1.0 - r) * grow, core * grow);
			if (v < 0.12) {
				discard;
			}
			col = mix(glow_c, vec3(1.0), step(0.6, v));
			col = mix(dark_c, col, step(0.2, v));
			a = 1.0;
		} else {
			float rr = abs(r - (1.0 - ring_w));
			float jw = ring_w * (0.6 + 0.6 * vn(vec2(ang * 40.0, seed)));
			float band = step(rr, jw);
			a = max(band, step(r, 1.0 - ring_w) * 0.1);
			col = band > 0.5 ? mix(glow_c, dark_c, step(jw * 0.6, rr)) : glow_c;
		}
	}
	if (fade > 0.001 && vn(UV * 9.0 + vec2(seed)) < fade) {
		discard;
	}
	if (a < 0.01) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a;
}
"""

## Kamui burgacı: logaritmik sarmal mürekkep kolları, ortası kara boşluk (kameraya bakar)
const SWIRL_SH := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 ink : source_color = vec3(0.04, 0.03, 0.07);
uniform vec3 paper : source_color = vec3(0.5, 0.47, 0.58);
uniform float arms = 3.0;
uniform float spin = 5.0;
uniform float bill = 1.0;
instance uniform float strength = 0.0;
instance uniform float sdir = 1.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void vertex() {
BILL
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float tw = ang * arms + sdir * log(r + 0.03) * 5.0 * strength - TIME * spin * sdir + seed;
	float s = sin(tw) + (vn(p * 6.0 + vec2(seed)) - 0.5) * 0.6;
	float hole = 0.3 * strength;
	vec3 col = s > 0.25 ? ink : paper;
	float a = strength * (1.0 - smoothstep(0.55, 1.0, r)) * (s > 0.25 ? 0.95 : 0.4);
	if (r < hole) {
		col = ink;
		a = strength;
	} else if (r < hole + 0.05) {
		col = paper * 1.3;
		a = strength;
	}
	float dist = -VERTEX.z;
	if (dist < 2.0) {
		a *= clamp((dist - 0.4) / 1.6, 0.0, 1.0);
	}
	if (fade > 0.001 && hh(floor(FRAGCOORD.xy * 0.3) + vec2(seed)) < fade) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a;
}
"""

## Art görüntü / sıvı kılıç: saydam gövde, keskin parlak kenar, yukarı akan çizgiler
const GHOST_SH := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled;

uniform vec3 body_c : source_color = vec3(0.1, 0.3, 0.3);
uniform vec3 rim_c : source_color = vec3(0.5, 1.0, 0.9);
uniform float a_body = 0.4;
uniform float bands = 0.0;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;
varying vec3 wpos;

NOISE

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float e = step(0.55, fr);
	vec3 col = mix(body_c, rim_c, e);
	float a = mix(a_body, 1.0, e);
	if (bands > 0.0) {
		float b = step(0.8, fract(wpos.y * bands - TIME * 1.5));
		col = mix(col, rim_c, b * 0.6);
	}
	if (fade > 0.001 && hh(floor(FRAGCOORD.xy * 0.25) + vec2(seed, 1.0)) < fade) {
		discard;
	}
	float dist = -VERTEX.z;
	if (dist < 1.2) {
		a *= clamp(dist / 1.2, 0.0, 1.0);
	}
	ALBEDO = col;
	ALPHA = a;
}
"""

## Cel ateş: kaynayan kabuk, sarı çekirdek -> turuncu -> kızıl -> koyu kontur
const FIRE_SH := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 c0 : source_color = vec3(1.0, 0.97, 0.75);
uniform vec3 c1 : source_color = vec3(1.0, 0.72, 0.18);
uniform vec3 c2 : source_color = vec3(0.95, 0.3, 0.06);
uniform vec3 c3 : source_color = vec3(0.35, 0.06, 0.02);
uniform float wob = 0.22;
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void vertex() {
	float n = vn(VERTEX.xy * 2.6 + vec2(seed, -TIME * 2.2)) + vn(VERTEX.zy * 2.6 + vec2(-TIME * 1.7, seed));
	VERTEX += NORMAL * (n - 0.6) * wob;
}

void fragment() {
	float dist = -VERTEX.z;
	if (dist < 1.6 && hh(floor(FRAGCOORD.xy) + vec2(seed)) > dist / 1.6) {
		discard;
	}
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = vn(UV * vec2(12.0, 6.0) + vec2(seed, -TIME * 2.0));
	float t = fr * 0.85 + n * 0.35 + fade * 0.4;
	vec3 col = t < 0.42 ? c0 : (t < 0.68 ? c1 : (t < 0.9 ? c2 : c3));
	if (fade > 0.001 && vn(UV * vec2(9.0, 5.0) + vec2(seed * 2.0, TIME)) < fade) {
		discard;
	}
	ALBEDO = col;
}
"""

## Kibaku fuda: krem kâğıt, kızıl mürekkep yazı, kenardan yanarak (kor çizgisiyle) yok olur
const TAG_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 paper : source_color = vec3(0.93, 0.88, 0.72);
uniform vec3 ink_c : source_color = vec3(0.7, 0.08, 0.06);
instance uniform float fade = 0.0;
instance uniform float seed = 0.0;

NOISE

void fragment() {
	vec2 uv = UV;
	float burn = vn(uv * vec2(5.0, 9.0) + vec2(seed)) * 0.7 + (1.0 - uv.y) * 0.3;
	if (burn < fade) {
		discard;
	}
	vec3 col = paper;
	float border = step(uv.x, 0.07) + step(0.93, uv.x) + step(uv.y, 0.04) + step(0.96, uv.y);
	col = mix(col, vec3(0.15, 0.1, 0.08), clamp(border, 0.0, 1.0));
	float glyph = step(abs(uv.x - 0.5), 0.07) * step(0.15, uv.y) * step(uv.y, 0.85);
	float bars = step(abs(fract(uv.y * 5.0) - 0.5), 0.07) * step(abs(uv.x - 0.5), 0.26) * step(0.2, uv.y) * step(uv.y, 0.8);
	col = mix(col, ink_c, clamp(glyph + bars, 0.0, 1.0));
	if (fade > 0.001 && burn < fade + 0.07) {
		col = vec3(1.0, 0.55, 0.1);
	}
	ALBEDO = col;
}
"""


# ================================================================== malzemeler
static func _sh(key: String, code: String) -> Shader:
	var k = "sh:" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code.replace("NOISE", NOISE).replace("BILL", BILL)
		_cache[k] = s
	return _cache[k]


static func _cel(col: Color, rim := Color(0, 0, 0), rim_amt := 0.0) -> ShaderMaterial:
	var k = "mat:cel:" + col.to_html() + rim.to_html() + str(rim_amt)
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("cel", CEL_SH)
		m.set_shader_parameter("tint", col)
		m.set_shader_parameter("shade", Color(0.62, 0.6, 0.72))
		m.set_shader_parameter("rim_c", rim)
		m.set_shader_parameter("rim_amt", rim_amt)
		_cache[k] = m
	return _cache[k]


static func _line_m(col: Color, w: float) -> ShaderMaterial:
	var k = "mat:line:" + col.to_html() + str(w)
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("line", LINE_SH)
		m.set_shader_parameter("col", col)
		m.set_shader_parameter("width", w)
		_cache[k] = m
	return _cache[k]


static func _glow(core: Color, mid: Color, line: Color, alpha := 1.0, jag := 0.3, flow := 1.0, streaks := 0.0, radial := false, bill := false) -> ShaderMaterial:
	var k = "mat:glow:%s%s%s:%.2f:%.2f:%.2f:%.1f:%s:%s" % [core.to_html(), mid.to_html(), line.to_html(), alpha, jag, flow, streaks, radial, bill]
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("glow", GLOW_SH)
		m.set_shader_parameter("core_c", core)
		m.set_shader_parameter("mid_c", mid)
		m.set_shader_parameter("line_c", line)
		m.set_shader_parameter("alpha", alpha)
		m.set_shader_parameter("jag", jag)
		m.set_shader_parameter("flow", flow)
		m.set_shader_parameter("streaks", streaks)
		m.set_shader_parameter("radial", 1.0 if radial else 0.0)
		m.set_shader_parameter("bill", 1.0 if bill else 0.0)
		m.render_priority = 1
		_cache[k] = m
	return _cache[k]


static func _ghost_m(body: Color, rim: Color, a_body: float, bands := 0.0) -> ShaderMaterial:
	var k = "mat:ghost:%s%s:%.2f:%.1f" % [body.to_html(), rim.to_html(), a_body, bands]
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("ghost", GHOST_SH)
		m.set_shader_parameter("body_c", body)
		m.set_shader_parameter("rim_c", rim)
		m.set_shader_parameter("a_body", a_body)
		m.set_shader_parameter("bands", bands)
		_cache[k] = m
	return _cache[k]


static func _fire_m() -> ShaderMaterial:
	var k = "mat:fire"
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("fire", FIRE_SH)
		_cache[k] = m
	return _cache[k]


static func _decal_m(mode: int, dark: Color, glow: Color, cracks: float, ring_w: float) -> ShaderMaterial:
	var k = "mat:decal:%d:%s%s:%.1f:%.3f" % [mode, dark.to_html(), glow.to_html(), cracks, ring_w]
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("decal", DECAL_SH)
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("dark_c", dark)
		m.set_shader_parameter("glow_c", glow)
		m.set_shader_parameter("cracks", cracks)
		m.set_shader_parameter("ring_w", ring_w)
		m.render_priority = -1
		_cache[k] = m
	return _cache[k]


static func _swirl_m(ink: Color, paper: Color, bill: bool) -> ShaderMaterial:
	var k = "mat:swirl:%s%s:%s" % [ink.to_html(), paper.to_html(), bill]
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("swirl", SWIRL_SH)
		m.set_shader_parameter("ink", ink)
		m.set_shader_parameter("paper", paper)
		m.set_shader_parameter("bill", 1.0 if bill else 0.0)
		m.render_priority = 2
		_cache[k] = m
	return _cache[k]


static func _tag_m() -> ShaderMaterial:
	var k = "mat:tag"
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _sh("tag", TAG_SH)
		_cache[k] = m
	return _cache[k]


# ================================================================== örgüler
static func _quad() -> QuadMesh:
	var k = "mesh:quad"
	if not _cache.has(k):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_cache[k] = q
	return _cache[k]


static func _sphere() -> SphereMesh:
	var k = "mesh:sphere"
	if not _cache.has(k):
		var s = SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 14
		s.rings = 7
		_cache[k] = s
	return _cache[k]


static func _box() -> BoxMesh:
	var k = "mesh:box"
	if not _cache.has(k):
		_cache[k] = BoxMesh.new()
	return _cache[k]


static func _link_mesh() -> TorusMesh:
	var k = "mesh:link"
	if not _cache.has(k):
		var t = TorusMesh.new()
		t.inner_radius = 0.035
		t.outer_radius = 0.065
		t.rings = 10
		t.ring_segments = 5
		_cache[k] = t
	return _cache[k]


static func _add_quad(st: SurfaceTool, q: Array, uv: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uv[idx])
		st.add_vertex(q[idx])


static func _cres_pt(r: float, span: float, w: float, t: float, inner: float) -> Vector3:
	var a = (t - 0.5) * span
	var ww = w * pow(sin(PI * t), 0.6)
	var rr = r - ww * inner
	return Vector3(sin(a) * rr, 0.0, cos(a) * rr)


## Hilal şerit (kesik izi): XZ düzleminde, ortası +Z'de; uçlara doğru incelir. UV.x boyuna, UV.y enine
static func _crescent(r: float, span: float, w: float, n := 24) -> ArrayMesh:
	var k = "mesh:cres:%.2f:%.2f:%.2f:%d" % [r, span, w, n]
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var t0 = i / float(n)
		var t1 = (i + 1) / float(n)
		_add_quad(st, [_cres_pt(r, span, w, t0, 0.0), _cres_pt(r, span, w, t1, 0.0), _cres_pt(r, span, w, t1, 1.0), _cres_pt(r, span, w, t0, 1.0)],
			[Vector2(t0, 0), Vector2(t1, 0), Vector2(t1, 1), Vector2(t0, 1)])
	var m = st.commit()
	_cache[k] = m
	return m


## Halka (yerel XZ ya da kameraya bakan XY düzleminde), dış yarıçap 1, genişlik w
static func _annulus(w: float, xy: bool) -> ArrayMesh:
	var k = "mesh:ann:%.2f:%s" % [w, xy]
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 40
	for i in n:
		var a0 = i * TAU / n
		var a1 = (i + 1) * TAU / n
		var o0 = Vector3(cos(a0), 0, sin(a0))
		var o1 = Vector3(cos(a1), 0, sin(a1))
		if xy:
			o0 = Vector3(o0.x, o0.z, 0)
			o1 = Vector3(o1.x, o1.z, 0)
		_add_quad(st, [o0, o1, o1 * (1.0 - w), o0 * (1.0 - w)], [Vector2(i / float(n), 0), Vector2((i + 1) / float(n), 0), Vector2((i + 1) / float(n), 1), Vector2(i / float(n), 1)])
	var m = st.commit()
	_cache[k] = m
	return m


## Açık silindir bant (yarıçap 1, y 0..1): UV.y yükseklik (Tsukuyomi perdesi)
static func _band_ring() -> ArrayMesh:
	var k = "mesh:band"
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 56
	for i in n:
		var a0 = i * TAU / n
		var a1 = (i + 1) * TAU / n
		var b0 = Vector3(cos(a0), 0, sin(a0))
		var b1 = Vector3(cos(a1), 0, sin(a1))
		_add_quad(st, [b0, b1, b1 + Vector3.UP, b0 + Vector3.UP], [Vector2(i / float(n) * 4.0, 0), Vector2((i + 1) / float(n) * 4.0, 0), Vector2((i + 1) / float(n) * 4.0, 1), Vector2(i / float(n) * 4.0, 1)])
	var m = st.commit()
	_cache[k] = m
	return m


## Alev dili / ışık iğnesi: XY düzleminde, taban y=0, uç y=1; UV.x boyuna, UV.y enine
static func _tongue_mesh() -> ArrayMesh:
	var k = "mesh:tongue"
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 10
	for i in n:
		var t0 = i / float(n)
		var t1 = (i + 1) / float(n)
		var w0 = 0.5 * pow(1.0 - t0, 0.8) * (0.35 + 0.65 * sin(PI * minf(1.0, t0 * 1.6 + 0.3)))
		var w1 = 0.5 * pow(1.0 - t1, 0.8) * (0.35 + 0.65 * sin(PI * minf(1.0, t1 * 1.6 + 0.3)))
		_add_quad(st, [Vector3(-w0, t0, 0), Vector3(-w1, t1, 0), Vector3(w1, t1, 0), Vector3(w0, t0, 0)], [Vector2(t0, 0), Vector2(t1, 0), Vector2(t1, 1), Vector2(t0, 1)])
	var m = st.commit()
	_cache[k] = m
	return m


## Işın: çapraz iki şerit, y=0 (tepe) .. y=-1 (dip), tepe genişliği 1, dip 0.55
static func _beam_mesh() -> ArrayMesh:
	var k = "mesh:beam"
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 6
	for ax in [Vector3.RIGHT, Vector3.BACK]:
		for i in n:
			var t0 = i / float(n)
			var t1 = (i + 1) / float(n)
			var w0 = lerpf(0.5, 0.28, t0)
			var w1 = lerpf(0.5, 0.28, t1)
			_add_quad(st, [ax * w0 - Vector3.UP * t0, ax * w1 - Vector3.UP * t1, -ax * w1 - Vector3.UP * t1, -ax * w0 - Vector3.UP * t0],
				[Vector2(t0, 0), Vector2(t1, 0), Vector2(t1, 1), Vector2(t0, 1)])
	var m = st.commit()
	_cache[k] = m
	return m


## Kameraya bakan tırtıklı yıldız (XY), yarıçap 1; UV merkezden ışınsal
static func _star_mesh(n: int, v: int) -> ArrayMesh:
	var k = "mesh:star:%d:%d" % [n, v]
	if _cache.has(k):
		return _cache[k]
	var rng = RandomNumberGenerator.new()
	rng.seed = n * 31 + v * 7 + 3
	var ring = []
	for i in n * 2:
		var a = i * PI / n + rng.randf_range(-0.12, 0.12)
		var r = rng.randf_range(0.75, 1.0) if i % 2 == 0 else rng.randf_range(0.2, 0.36)
		ring.append(Vector3(cos(a) * r, sin(a) * r, 0))
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		for p in [Vector3.ZERO, ring[i], ring[(i + 1) % ring.size()]]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(p.x, -p.y) * 0.5 + Vector2(0.5, 0.5))
			st.add_vertex(p)
	var m = st.commit()
	_cache[k] = m
	return m


static func _strip(st: SurfaceTool, pts: Array, wid: Array, sides: Array) -> void:
	var n = pts.size()
	for i in n - 1:
		var t0 = i / float(n - 1)
		var t1 = (i + 1) / float(n - 1)
		_add_quad(st, [pts[i] + sides[i] * wid[i], pts[i + 1] + sides[i + 1] * wid[i + 1], pts[i + 1] - sides[i + 1] * wid[i + 1], pts[i] - sides[i] * wid[i]],
			[Vector2(t0, 0), Vector2(t1, 0), Vector2(t1, 1), Vector2(t0, 1)])


## Çapraz iki şerit (her açıdan görünür çizgi): şimşek, iplik, hız çizgisi
static func _xribbon(pts: Array, wid: Array) -> ArrayMesh:
	var s1 = []
	var s2 = []
	for i in pts.size():
		var a: Vector3 = pts[maxi(0, i - 1)]
		var b: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var dv = (b - a).normalized()
		var rf = Vector3.UP if absf(dv.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var x = dv.cross(rf).normalized()
		s1.append(x)
		s2.append(dv.cross(x).normalized())
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip(st, pts, wid, s1)
	_strip(st, pts, wid, s2)
	return st.commit()


## Tek düzlemde şerit (yan vektör sabit)
static func _flat_ribbon(pts: Array, wid: Array, side: Vector3) -> ArrayMesh:
	var sides = []
	for i in pts.size():
		sides.append(side)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip(st, pts, wid, sides)
	return st.commit()


static func _jag_pts(a: Vector3, b: Vector3, seg: int, jag: float) -> Array:
	var out = [a]
	var L = a.distance_to(b)
	var dv = (b - a) / L if L > 0.001 else Vector3.UP
	var rf = Vector3.UP if absf(dv.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x = dv.cross(rf).normalized()
	var y = dv.cross(x)
	for i in range(1, seg):
		out.append(a.lerp(b, i / float(seg)) + (x * randf_range(-1, 1) + y * randf_range(-1, 1)) * jag * L / seg)
	out.append(b)
	return out


## Zemine oturan disk (yerel, merkez center), UV düzlemsel
static func _gdisc(center: Vector3, R: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = 8
	var segs = 32
	var pt = func(i: int, k: int) -> Array:
		var r = R * i / float(rings)
		var a = k * TAU / segs
		var x = cos(a) * r
		var z = sin(a) * r
		var y = Game.ground_height(center.x + x, center.z + z) - center.y + 0.1
		return [Vector3(x, y, z), Vector2(x / R * 0.5 + 0.5, z / R * 0.5 + 0.5)]
	for i in rings:
		for k in segs:
			var q = [pt.call(i, k), pt.call(i + 1, k), pt.call(i + 1, k + 1), pt.call(i, k + 1)]
			_add_quad(st, [q[0][0], q[1][0], q[2][0], q[3][0]], [q[0][1], q[1][1], q[2][1], q[3][1]])
	return st.commit()


## Zemine oturan şerit a -> b (yerel, köken a), UV.x boyuna
static func _gstrip(a: Vector3, b: Vector3, w: float) -> ArrayMesh:
	var dv = b - a
	dv.y = 0.0
	var L = maxf(0.5, dv.length())
	dv = dv / L
	var sd = dv.cross(Vector3.UP).normalized()
	var n = clampi(int(L / 0.7), 2, 60)
	var gp = func(i: int, s: float) -> Vector3:
		var p = a + dv * L * i / float(n) + sd * s * w * 0.5
		return Vector3(p.x - a.x, Game.ground_height(p.x, p.z) - a.y + 0.1, p.z - a.z)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		_add_quad(st, [gp.call(i, 1.0), gp.call(i + 1, 1.0), gp.call(i + 1, -1.0), gp.call(i, -1.0)],
			[Vector2(i / float(n), 0), Vector2((i + 1) / float(n), 0), Vector2((i + 1) / float(n), 1), Vector2(i / float(n), 1)])
	return st.commit()


# ================================================================== yapı taşları
static func _mi(mesh: Mesh, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else MsArts._scene()).add_child(mi)
	mi.set_instance_shader_parameter("seed", randf() * 50.0)
	return mi


static func _iparam(n: Node, key: String, x: float) -> void:
	if n != null and is_instance_valid(n) and n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter(key, x)


## Düğüm ve altındaki bütün parçalar birlikte dağılır (0 tam, 1 yok)
static func _fade_tree(n: Node, x: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is GeometryInstance3D and not n.has_meta("nofade"):
		(n as GeometryInstance3D).set_instance_shader_parameter("fade", x)
	for ch in n.get_children():
		_fade_tree(ch, x)


static func _dissolve(n: Node3D, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(x: float): _fade_tree(n, x), 0.0, 1.0, maxf(0.02, dur))
	tw.tween_callback(n.queue_free)


static func _outline(mi: MeshInstance3D, col: Color, w: float) -> MeshInstance3D:
	var o = _mi(mi.mesh, _line_m(col, w), mi)
	return o


static func _ybasis(normal: Vector3) -> Basis:
	var y = normal.normalized()
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


static func _light(at: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = minf(rng, 40.0)
	l.shadow_enabled = false
	MsArts._scene().add_child(l)
	l.global_position = at
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


## Tırtıklı parlama yıldızı (kameraya bakar)
static func _flash(at: Vector3, size: float, core: Color, mid: Color, life := 0.16, spikes := 8, line := INK) -> MeshInstance3D:
	var mi = _mi(_star_mesh(spikes, randi() % 3), _glow(core, mid, line, 1.0, 0.15, 0.0, 0.0, true, true))
	mi.global_position = at
	var s = minf(size, 9.0)
	mi.scale = Vector3.ONE * s * 0.3
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * s * 0.5, life * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, life * 0.65)
	tw.tween_callback(mi.queue_free)
	return mi


## Genişleyen halka dalgası: normal'e dik düzlemde ya da (bill) kameraya bakan
static func _ring(at: Vector3, normal: Vector3, r0: float, r1: float, life: float, core: Color, mid: Color, bill := false, w := 0.22, alpha := 0.85, line := INK) -> MeshInstance3D:
	var mi = _mi(_annulus(w, bill), _glow(core, mid, line, alpha, 0.25, 1.0, 0.0, false, bill))
	if bill:
		mi.global_position = at
	else:
		mi.global_transform = Transform3D(_ybasis(normal), at)
	mi.scale = Vector3.ONE * r0
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * minf(r1, 40.0), life).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Kesik izi: at merkezli, dir'e bakan, roll kadar yatık hilal; büyüyüp yenerek söner. Kök Node3D döner
static func _slash(at: Vector3, dir: Vector3, r: float, roll: float, dur: float, core: Color, mid: Color, line: Color, wf := 0.18, span := 2.3, jag := 0.3, alpha := 0.95) -> Node3D:
	var h = Node3D.new()
	MsArts._scene().add_child(h)
	h.global_transform = Transform3D(MsArts._zbasis(dir) * Basis(Vector3(0, 0, 1), roll), at)
	var mi = _mi(_crescent(1.0, span, wf), _glow(core, mid, line, alpha, jag, 2.5, 3.0), h)
	mi.scale = Vector3.ONE * r * 0.6
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r * 1.08, dur * 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): _fade_tree(h, x), 0.0, 1.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(h.queue_free)
	return h


## Hilal üzerindeki bir nokta (h kökünün yerel ölçeğiyle)
static func _arc_point(at: Vector3, dir: Vector3, roll: float, r: float, t: float, span := 2.3) -> Vector3:
	var b = MsArts._zbasis(dir) * Basis(Vector3(0, 0, 1), roll)
	var a = (t - 0.5) * span
	return at + b * Vector3(sin(a) * r, 0.0, cos(a) * r)


## Şimşek: tırtıklı çizgi + dallar; kısa yanar, yenerek söner
static func _bolt(a: Vector3, b: Vector3, w: float, life: float, core: Color, mid: Color, jag := 0.35, seg := 8, branch := 1) -> void:
	var pts = _jag_pts(a, b, maxi(2, seg), jag)
	var wid = []
	for i in pts.size():
		wid.append(w * lerpf(1.0, 0.35, i / float(pts.size() - 1)))
	var mi = _mi(_xribbon(pts, wid), _glow(core, mid, INK, 1.0, 0.12, 0.0))
	_dissolve(mi, life * 0.4, life * 0.6)
	var L = a.distance_to(b)
	for k in branch:
		var p0: Vector3 = pts[randi_range(1, pts.size() - 2)]
		var bd = ((b - a).normalized() + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1))).normalized()
		var bp = _jag_pts(p0, p0 + bd * L * randf_range(0.2, 0.35), 4, jag)
		var bw = []
		for i in bp.size():
			bw.append(w * 0.5 * lerpf(1.0, 0.2, i / float(bp.size() - 1)))
		var bm = _mi(_xribbon(bp, bw), _glow(core, mid, INK, 1.0, 0.12, 0.0))
		_dissolve(bm, life * 0.3, life * 0.5)


## Hız / akış çizgisi a -> b: kısa yanar, b yönüne kayarak söner
static func _streak(a: Vector3, b: Vector3, w: float, life: float, core: Color, mid: Color, alpha := 0.85) -> void:
	var mi = _mi(_xribbon([a, a.lerp(b, 0.35), b], [w * 0.3, w, 0.0]), _glow(core, mid, INK, alpha, 0.1, 0.0))
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "position", (b - a) * 0.4, life)
	tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Yükselen alev / chakra dili (kameraya bakar)
static func _tongue(at: Vector3, h: float, w: float, core: Color, mid: Color, life: float, rise := 1.0, line := INK) -> MeshInstance3D:
	var mi = _mi(_tongue_mesh(), _glow(core, mid, line, 0.95, 0.4, 3.0, 0.0, false, true))
	mi.global_position = at
	var hh = minf(h, 16.0)
	mi.scale = Vector3(w, hh * 0.2, 1.0)
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(w * 0.8, hh, 1.0), life * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", at + Vector3.UP * rise * hh * 0.4, life)
	tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Süzülen yuvarlak parıltılar (Shisui'nin chakra kabarcıkları / ışık zerreleri)
static func _motes(at: Vector3, n: int, core: Color, mid: Color, spread: float, rise: float, life: float, size: float, line := INK, alpha := 0.85) -> void:
	for k in n:
		var mi = _mi(_quad(), _glow(core, mid, line, alpha, 0.06, 0.3, 0.0, true, true))
		var p0 = at + Vector3(randf_range(-1, 1), randf_range(-0.5, 1.0), randf_range(-1, 1)) * spread
		mi.global_position = p0
		var s = size * randf_range(0.6, 1.4)
		mi.scale = Vector3.ONE * s * 0.3
		var drift = Vector3(randf_range(-0.3, 0.3), rise * randf_range(0.6, 1.2), randf_range(-0.3, 0.3))
		var lf = life * randf_range(0.7, 1.2)
		var tw = mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * s, lf * 0.25)
		tw.tween_property(mi, "global_position", p0 + drift, lf).set_trans(Tween.TRANS_SINE)
		tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, lf * 0.5).set_delay(lf * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Yerçekimli parçalar (kaya, kıvılcım, mürekkep damlası, sıvı)
static func _chunks(at: Vector3, n: int, col: Color, spd: float, life: float, sz: float, up := 1.0, dir := Vector3.ZERO, rnd := false) -> void:
	var floor_y = at.y - 0.35
	for k in n:
		var mi = _mi(_sphere() if rnd else _box(), _cel(col, col.darkened(0.55), 1.0 if rnd else 0.0))
		mi.global_position = at
		var v = (Vector3(randf_range(-1, 1), randf_range(0.5, 1.3) * up, randf_range(-1, 1)).normalized() + dir).normalized() * spd * randf_range(0.5, 1.0)
		var s = sz * randf_range(0.6, 1.3)
		mi.scale = Vector3(s, s * randf_range(0.5, 1.0), s * randf_range(0.6, 1.2)) * (0.5 if rnd else 1.0)
		var spin = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		var lf = life * randf_range(0.75, 1.15)
		var mv = func(x: float) -> void:
			if not is_instance_valid(mi):
				return
			var tt = x * lf
			var p = at + v * tt + Vector3.DOWN * 4.9 * tt * tt
			p.y = maxf(p.y, floor_y)
			mi.global_position = p
			mi.rotation = spin * tt
			if x > 0.7:
				mi.set_instance_shader_parameter("fade", (x - 0.7) / 0.3)
		var tw = mi.create_tween()
		tw.tween_method(mv, 0.0, 1.0, lf)
		tw.tween_callback(mi.queue_free)


## Zeminde dışa yuvarlanan toz topakları (çarpma)
static func _dust(at: Vector3, r: float, n: int, col: Color, life: float) -> void:
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dv = Vector3(cos(a), 0, sin(a))
		var mi = _mi(_sphere(), _cel(col, col.lightened(0.3), 1.0))
		mi.global_position = at + dv * r * 0.2 + Vector3.UP * 0.2
		var s0 = minf(r * randf_range(0.12, 0.2), 1.6)
		mi.scale = Vector3(s0, s0 * 0.6, s0)
		var tw = mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", at + dv * r * randf_range(0.8, 1.1) + Vector3.UP * randf_range(0.2, 0.6), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(s0, s0 * 0.75, s0) * 2.0, life)
		tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, life).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)


## Zemin izi (çatlak çukur / ışık yıldızı / halka): büyüyerek açılır, life sn kalır, yenerek söner
static func _decal(center: Vector3, R: float, mode: int, dark: Color, glow: Color, life: float, cracks := 9.0, grow_t := 0.12, ring_w := 0.06) -> MeshInstance3D:
	var R2 = minf(R, 30.0)
	var mi = _mi(_gdisc(center, R2), _decal_m(mode, dark, glow, cracks, ring_w))
	mi.global_position = center
	mi.set_instance_shader_parameter("grow", 0.25)
	var tw = mi.create_tween()
	tw.tween_method(func(x: float): _iparam(mi, "grow", x), 0.25, 1.0, maxf(0.02, grow_t))
	tw.tween_interval(life)
	tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, 0.7)
	tw.tween_callback(mi.queue_free)
	return mi


## Zeminde açılan yarık a -> b: grow_t'de uca doğru açılır
static func _furrow(a: Vector3, b: Vector3, w: float, dark: Color, glow: Color, life: float, grow_t := 0.15) -> MeshInstance3D:
	var ga = Jutsu._ground(a)
	var mi = _mi(_gstrip(ga, b, w), _decal_m(2, dark, glow, 0.0, 0.0))
	mi.global_position = ga
	mi.set_instance_shader_parameter("grow", 0.0)
	var tw = mi.create_tween()
	if grow_t > 0.0:
		tw.tween_method(func(x: float): _iparam(mi, "grow", x), 0.0, 1.0, grow_t)
	else:
		tw.tween_interval(0.5)   # uç çağıranın dalgasıyla açılır
	tw.tween_interval(life)
	tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, 0.8)
	tw.tween_callback(mi.queue_free)
	return mi


## Kamui burgacı: Kamui ailesinin kendi uzay bükülmesi (MsArts.kamui_vortex, anime ref refs/kamui_anime) — sdir > 0 içe yutar,
## < 0 dışa açılır (çıkış). parent verilirse pos onun yerel ofseti, burgaç onu izler. (ink/paper eski çizim tonlarıydı: kullanılmıyor)
static func _swirl(pos: Vector3, size: float, dur: float, sdir := 1.0, _ink := OBI_INK, _paper := OBI_PALE, parent: Node = null) -> MeshInstance3D:
	var o = {"pull": 0.45 if sdir > 0.0 else -0.4}
	var p3 = parent as Node3D
	if p3 != null:
		o["follow"] = p3
		return MsArts.kamui_vortex(p3.global_transform.basis * pos, minf(size, 8.0), dur, o)
	return MsArts.kamui_vortex(pos, minf(size, 8.0), dur, o)


## Burgaca çekilen / burgaçtan saçılan zerreler (inward: içe)
static func _swirl_specks(at: Vector3, r: float, n: int, dur: float, inward: bool) -> void:
	for k in n:
		var a0 = randf() * TAU
		var y0 = randf_range(-0.6, 0.6) * r
		var mi = _mi(_quad(), _glow(Color(0.85, 0.82, 0.92), OBI_PALE, OBI_INK, 0.9, 0.05, 0.0, 0.0, true, true))
		mi.scale = Vector3.ONE * randf_range(0.06, 0.13) * maxf(1.0, r * 0.6)
		var lf = dur * randf_range(0.7, 1.0)
		var mv = func(x: float) -> void:
			if not is_instance_valid(mi):
				return
			var t = x if inward else 1.0 - x
			var rr = r * (1.0 - t)
			var aa = a0 + t * 4.0
			mi.global_position = at + Vector3(cos(aa) * rr, y0 * (1.0 - t), sin(aa) * rr)
			if x > 0.75:
				mi.set_instance_shader_parameter("fade", (x - 0.75) / 0.25)
		var tw = mi.create_tween()
		tw.tween_method(mv, 0.0, 1.0, lf).set_ease(Tween.EASE_IN if inward else Tween.EASE_OUT)
		tw.tween_callback(mi.queue_free)


## Art görüntü: sahibinin o anki pozunun kalıbı, kendi silüet malzememizle; hold sn durur, life sn'de dağılır
static func _echo(c: Node3D, body: Color, rim: Color, a_body: float, life: float, hold := 0.0, bands := 0.0) -> Node3D:
	var m = c.get("model") if is_instance_valid(c) else null
	if m == null or not is_instance_valid(m):
		return null
	var root = Node3D.new()
	MsArts._scene().add_child(root)
	var mat = _ghost_m(body, rim, a_body, bands)
	for src in m.find_children("*", "MeshInstance3D", true, false):
		var s = src as MeshInstance3D
		if s.mesh == null or not s.is_visible_in_tree():
			continue
		var mesh: Mesh = s.mesh
		if s.skin != null or s.get_node_or_null(s.skeleton) is Skeleton3D:
			var baked = s.bake_mesh_from_current_skeleton_pose()
			if baked:
				mesh = baked
		var e = MeshInstance3D.new()
		e.mesh = mesh
		e.material_override = mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(e)
		e.global_transform = s.global_transform
		e.set_instance_shader_parameter("seed", randf() * 50.0)
	_dissolve(root, hold, life)
	return root


## Model saydamlığı (Kamui geçirgenliği / burgaca çekilme)
static func _see_through(model: Node, amount: float) -> void:
	if model == null or not is_instance_valid(model):
		return
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).transparency = amount


## Kamui geçirgenliği (teknik boyunca): darbe almaz, yarı saydam; göğsünde küçük burgaç dalgalanır
static func _intangible(c: Node3D, dur: float) -> void:
	MsArts._flicker_guard(c, dur)
	_see_through(c.get("model"), 0.55)
	MsArts.kamui_ripple(c)   # anime: sürekli girdap yok, geçişte küçük burkulma
	var wr = weakref(c)
	MsArts._later(dur, func():
		var n = wr.get_ref()
		if n != null:
			_see_through(n.get("model"), 0.0))


## Kamui ile ışınlan: çıkışta içe, varışta dışa dönen burgaç
static func _kamui_hop(c: Node3D, to: Vector3) -> void:
	_swirl(MsArts.KS.eye_point(c), 0.8, 0.45, 1.0)
	MsArts._blink(c, to)
	_swirl(MsArts.KS.eye_point(c), 0.8, 0.45, -1.0)
	MsArts.KS.twist_into(c, MsArts.KS.eye_point(c), 0.22, true)   # gözdeki burgaçtan açılarak belirir (dönmez)
	Sfx.play("th_teleport", to, 1.3, 0.6)


## Kamui çekişi (MsArts.kamui_warp mekaniği aynen; görsel bizim burgacımız)
static func _kamui_take(c: Node3D, h: Node3D, info: Dictionary, at: Vector3) -> void:
	if not MsArts._alive(h):
		return
	var inf = info.duplicate()
	if h == Game.player:
		inf["dmg"] = minf(float(inf.get("dmg", 0.0)), maxf(1.0, float(h.hp) * 0.5))
	# zayıflamış (ya da bu darbeyle düşecek) hedef darbe yemez: bütünüyle boyuta akar (hasarla ölüp yerde ceset kalmasın)
	var weak = not (h is Player) and not h.has_meta("boss") and float(h.hp) - float(inf.get("dmg", 0.0)) <= float(h.max_hp) * 0.35 and h.has_method("die")
	if not weak:
		h.take_hit(inf)
		if not MsArts._alive(h):
			return
	if h == Game.player and float(h.hp) <= float(h.max_hp) * 0.35 and MsArts.pull_player(c):
		return
	if weak:
		h.apply_status("stun", 1.2)
		if c == Game.player:
			Game.profile["kamui_store"] = int(Game.profile.get("kamui_store", 0)) + 1
		# anime (Kakashi): odak noktasındaki uzay sarmal burkulur, beden oraya akıp kaybolur; ceset / düşüş karesi yok
		MsArts.KS.swallow(c, h, at, 0.9, func():
			Combat.popup_text(at + Vector3.UP, "Kamui boyutuna çekildi", Color(0.7, 0.55, 0.9))
			h.die({"execute": true, "attacker": c, "kamui": true, "dmg": 9999.0})
			if is_instance_valid(h) and h.is_dead():
				MsArts.KS.capture(c, h))   # boyutta tutsak kalır
	else:
		Combat.popup_text(MsArts._chest(h) + Vector3.UP, "Bir parçası koptu", Color(0.8, 0.6, 0.95))
		h.apply_status("bleed", 5.0)
		MsArts.kamui_vortex(at, MsArts._hh(h) * 1.4, 1.0, {"pull": 0.5})
		MsArts.KS.twist_into(h, at, 0.7, false, 0.3)   # güçlü hedef: odaktaki parça burkulup kopar, beden geri yaylanır


## Demir zincir a -> b (Obito'nun bilek zinciri): halka halka, grow sn'de uca doğru uzar; life sn sonra dağılır
static func _chain(a: Vector3, b: Vector3, life: float, sag := 0.25, grow := 0.1, sc := 1.0) -> Node3D:
	var L = maxf(0.05, a.distance_to(b))
	var n = clampi(int(L / (0.13 * sc)), 2, 90)
	var s2 = maxf(sc, L / (90.0 * 0.13))
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _link_mesh()
	mm.instance_count = n
	var dip = sag * minf(L, 12.0) * 0.25
	for i in n:
		var t0 = (i + 0.5) / n
		var p = a.lerp(b, t0) + Vector3.DOWN * dip * 4.0 * t0 * (1.0 - t0)
		var td = ((b - a) / L + Vector3.DOWN * dip * 4.0 * (1.0 - 2.0 * t0) / L).normalized()
		var bas = MsArts._zbasis(td)
		if i % 2 == 1:
			bas = bas * Basis(Vector3(0, 0, 1), PI * 0.5)
		mm.set_instance_transform(i, Transform3D(bas * Basis.from_scale(Vector3(1.0, 1.0, 1.7) * s2), p))
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _cel(IRON, Color(0.78, 0.78, 0.84), 1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MsArts._scene().add_child(mmi)
	mmi.set_instance_shader_parameter("seed", randf() * 50.0)
	if grow > 0.02:
		mm.visible_instance_count = 0
		var tw = mmi.create_tween()
		tw.tween_method(func(x: float):
			if is_instance_valid(mmi):
				mm.visible_instance_count = clampi(int(x * n), 0, n), 0.0, 1.0, grow)
		tw.tween_callback(func(): mm.visible_instance_count = -1)
	_dissolve(mmi, maxf(0.0, life - 0.12), 0.12)
	return mmi


## Hedefin gövdesine dolanan zincir halkası
static func _chain_wrap(tg: Node3D, life: float) -> void:
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var r = 0.42 * H / 1.8
	for row in 2:
		var y = tg.global_position + Vector3.UP * H * (0.5 + row * 0.16)
		for k in 6:
			var a0 = k * TAU / 6.0 + row * 0.5
			var a1 = (k + 1) * TAU / 6.0 + row * 0.5
			_chain(y + Vector3(cos(a0), 0, sin(a0)) * r, y + Vector3(cos(a1), 0, sin(a1)) * r, life, 0.0, 0.05, H / 1.8)


## Sahibinin gerçek Mangekyō deseni (oyuncu: takılı göz; NPC: Shisui'nin dört kollu çarkı) — Eyes göz tasarım sistemi
static func _eye_disc(c: Node3D, size: float, bill: bool) -> MeshInstance3D:
	var dd: Dictionary = Eyes.design_for(Game.profile, "sag_goz") if c == Game.player else {}
	if dd.is_empty():
		dd = {"style": 13, "blades": 4, "curve": 1.0, "thick": 0.55, "inner": 0.2, "spin": 0.6}
	var vv = Eyes.design_vecs(dd)
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/ms_disc.gdshader")
	m.set_shader_parameter("ms_a", vv[0])
	m.set_shader_parameter("ms_b", vv[1])
	m.set_shader_parameter("col", vv[2])
	m.set_shader_parameter("billboard", bill)
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Madara'nın Susanoo kılıcı: gerçek Susanoo chakra malzemesi + kenarında titreyen tırtıklı chakra alevi.
## kind 0 uzun nodachi (Dan), 1 geniş düz kılıç (Retsu), 2 kavisli kılıç (Nitō). Namlu -Z'ye uzanır.
static func _bend(i: float) -> float:
	return 0.45 * pow(i / 5.0, 2.0)


static func _sus_blade(sn: Susanoo, S: float, right: bool, dur: float, look_fn: Callable, kind: int) -> Node3D:
	var mb = MB.new()
	var L = 3.2
	var fw = 0.22
	var curve = false
	match kind:
		0:
			mb.add("box", Vector3(0, 0, -1.5), Vector3(0.05, 0.17, 3.0), Color.WHITE)
			mb.add("cone", Vector3(0, 0, -3.12), Vector3(0.05, 0.26, 0.17), Color.WHITE, Vector3(-90, 0, 0), 4)
			mb.add("box", Vector3(0, 0.075, -1.5), Vector3(0.06, 0.025, 2.9), Susanoo.K_LINE)
		1:
			mb.add("box", Vector3(0, 0, -1.1), Vector3(0.07, 0.3, 2.2), Color.WHITE)
			mb.add("cone", Vector3(0, 0, -2.36), Vector3(0.07, 0.3, 0.32), Color.WHITE, Vector3(-90, 0, 0), 4)
			mb.add("box", Vector3(0, 0.12, -1.1), Vector3(0.08, 0.03, 2.1), Susanoo.K_LINE)
			mb.add("box", Vector3(0, -0.12, -1.1), Vector3(0.08, 0.03, 2.1), Susanoo.K_LINE)
			L = 2.5
			fw = 0.32
		_:
			curve = true
			for i in 6:
				var slope = (_bend(i + 0.5) - _bend(i - 0.5)) / 0.42
				mb.add("box", Vector3(0, _bend(i), -0.25 - i * 0.42), Vector3(0.05, 0.16, 0.46), Color.WHITE, Vector3(rad_to_deg(atan(slope)), 0, 0))
			mb.add("cone", Vector3(0, _bend(6.0), -2.85), Vector3(0.05, 0.22, 0.16), Color.WHITE, Vector3(-90 + rad_to_deg(atan(0.36)), 0, 0), 4)
			L = 2.9
	mb.add("box", Vector3(0, 0, 0.05), Vector3(0.36, 0.08, 0.07), Susanoo.K_PLATE)
	mb.add("cyl", Vector3(0, 0, 0.32), Vector3(0.05, 0.48, 0.05), Susanoo.K_BONE, Vector3(90, 0, 0), 8)
	var root = Node3D.new()
	MsArts._scene().add_child(root)
	var sw = sn.chakra_mesh(mb, 1.7)
	sw.set_meta("nofade", true)
	root.add_child(sw)
	var col = sn.color()
	var pts = []
	var wid = []
	for i in 9:
		var tt = i / 8.0
		var y = _bend(tt * 6.0) if curve else 0.0
		pts.append(Vector3(0, y, -0.1 - tt * L))
		wid.append(fw * (0.55 + 0.45 * sin(PI * minf(1.0, tt * 1.2))))
	var fm = _glow(col.lightened(0.7), col.lightened(0.2), col.darkened(0.6), 0.7, 0.6, 3.0)
	_mi(_flat_ribbon(pts, wid, Vector3.UP), fm, root)
	var wid2 = []
	for x in wid:
		wid2.append(x * 0.45)
	_mi(_flat_ribbon(pts, wid2, Vector3.RIGHT), fm, root)
	root.scale = Vector3.ONE * S * 0.5
	sn.follow_fx(root, dur, func(): return sn.hand(right), look_fn)
	MsArts._later(dur, func():
		if is_instance_valid(root):
			root.queue_free())
	return root


## Cel ateş topu (kaynayan kabuk + beyaz-sarı göbek)
static func _fireball(r: float) -> Node3D:
	var root = Node3D.new()
	var outer = _mi(_sphere(), _fire_m(), root)
	outer.scale = Vector3.ONE * r
	var inner = _mi(_sphere(), _cel(Color(1.0, 0.95, 0.7)), root)
	inner.scale = Vector3.ONE * r * 0.55
	return root


## Ateş patlaması: kaynayan küreler + parlama + kor + yanık çukur
static func _fire_burst(p: Vector3, s: float) -> void:
	_flash(p, 2.6 * s, Color(1, 0.97, 0.8), Color(1.0, 0.6, 0.15), 0.18)
	_light(p, Color(1.0, 0.55, 0.2), 6.0, 10.0 * s, 0.45)
	for k in 6:
		var b = _fireball(1.0)
		MsArts._scene().add_child(b)
		b.global_position = p + Vector3(randf_range(-1, 1), randf_range(-0.3, 0.8), randf_range(-1, 1)) * 0.7 * s
		b.scale = Vector3.ONE * 0.2 * s
		var tw = b.create_tween()
		tw.set_parallel(true)
		tw.tween_property(b, "scale", Vector3.ONE * randf_range(0.6, 0.95) * s, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "global_position", b.global_position + Vector3.UP * 0.9 * s, 0.6)
		tw.tween_method(func(x: float): _fade_tree(b, x), 0.0, 1.0, 0.5).set_delay(0.12)
		tw.chain().tween_callback(b.queue_free)
	_chunks(p, 8, Color(0.25, 0.1, 0.05), 7.0 * s, 0.7, 0.08 * s)
	var g = Jutsu._ground(p)
	if p.y - g.y < 2.5:
		_decal(g, 1.8 * s, 0, Color(0.1, 0.05, 0.03), Color(1.0, 0.45, 0.1), 2.0, 8.0)


# ================================================================== KAKASHI
## Susanoo: Kamui Raikiri (Storm 4): Susanoo'nun elinde kara burgaçla sarılı şimşek kütlesi toplanır (yere sürten ve dışarıdan
## içe akan çatırtılar); kol öne saplanır, uçta uzay burkulur — değdiğini Kamui boyutuna çeker; yerde mavi yanık çatlak
static func susanoo_kamui_raikiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_kamui_raikiri")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var tg = Jutsu._tg(c, t, 12.0 + H * 1.3)
	var aim = MsArts._aim_fn(c, tg, 6.0 + H * 0.7)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.5)
	MsArts._anim(c, "cast", 0.9)
	sn.hide_weapons(1.9)
	sn.pose({"arms": Susanoo.arm(true, -d * 0.5 + side * 0.4 - Vector3.UP * 0.3, d * 0.3 - Vector3.UP * 0.6), "spine": -12.0}, 1.0, true)
	var col = RAI
	var core = Node3D.new()
	MsArts._scene().add_child(core)
	var orb = _mi(_sphere(), _cel(Color(0.96, 0.98, 1.0), col, 1.0), core)
	orb.scale = Vector3.ONE * S * 0.2
	_outline(orb, Color(0.05, 0.08, 0.25), 0.05)
	_swirl(Vector3.ZERO, S * 0.7, 1.5, 1.0, Color(0.02, 0.03, 0.1), Color(0.3, 0.45, 0.8), core)
	var lt = OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = 2.5
	lt.omni_range = minf(6.0 + H * 0.5, 30.0)
	lt.shadow_enabled = false
	core.add_child(lt)
	sn.follow_fx(core, 1.5, func(): return sn.hand(true))
	core.scale = Vector3.ONE * 0.2
	core.create_tween().tween_property(core, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	Sfx.play("chidori", c.global_position, 0.6)
	for k in 10:
		MsArts._later(0.1 + k * 0.07, func():
			if not is_instance_valid(core):
				return
			var hp = core.global_position
			var g = Jutsu._ground(hp + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * S * 0.6)
			_bolt(hp, g, S * 0.035, 0.16, Color(1, 1, 1), col, 0.4, 6, 1)
			if k % 3 == 0:
				var far = hp + Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized() * S * 1.3
				_bolt(far, hp, S * 0.02, 0.14, Color(1, 1, 1), col.lightened(0.2), 0.5, 5, 0)
			if k % 4 == 1:
				_chunks(g, 3, Color(0.85, 0.92, 1.0), 3.0 + S, 0.4, 0.05 * S, 1.0, Vector3.ZERO, true))
	MsArts._later(0.85, func():
		if not (is_instance_valid(sn) and MsArts._alive(c)):
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 14.0}, 0.7, true)
		MsArts._shake(0.5))
	MsArts._later(1.0, func():
		if not (is_instance_valid(sn) and MsArts._alive(c)):
			return
		var fist = sn.hand(true)
		var at = fist + (aim.call() - fist).limit_length(S * 0.8)
		var inf = MsArts._inf(c, "susanoo_kamui_raikiri", 1.0, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "hitstop": 0.1, "dir": d})
		for h in MsArts._foes(c, at, 2.2 + H * 0.14):
			_kamui_take(c, h, inf, MsArts._chest(h))
		var fd = (at - fist).normalized() if at.distance_to(fist) > 0.1 else d
		for k in 4:   # öne saplanan şimşek mızrağı
			var tip = at + fd * S * randf_range(0.8, 1.6) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * S * 0.25
			_bolt(fist, tip, S * 0.05, 0.3, Color(1, 1, 1), col, 0.3, 8, 2)
		_swirl(at, S * 0.9, 0.8, -1.0, Color(0.02, 0.03, 0.1), Color(0.3, 0.45, 0.8))
		for k in 8:   # uçtan saçılan şimşek
			_bolt(at, at + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized() * (3.0 + H * 0.25), S * 0.03, 0.25, Color(1, 1, 1), col.lightened(0.2), 0.45, 6, 1)
		_flash(at, 2.0 + S * 0.6, Color(1, 1, 1), col, 0.2)
		_light(at, col, 8.0, 14.0 + H, 0.4)
		var g = Jutsu._ground(at)
		_decal(g, 3.0 + H * 0.15, 0, Color(0.04, 0.05, 0.12), col, 2.5, 11.0)
		_chunks(g + Vector3.UP * 0.3, 8, DIRT, 6.0 + S, 0.8, 0.1 + S * 0.03)
		MsArts._shake(0.9)
		Sfx.play("zap", at, 0.7))
	MsArts._later(1.5, func():
		if is_instance_valid(core):
			core.queue_free())


# ================================================================== MADARA
## Susanoo: Dan (須佐能乎・断, Storm): dirsek darbesiyle açar; kenarı chakra alevi gibi tutuşan uzun Susanoo nodachisiyle
## ardı ardına yatay biçer (yay boyu kopan chakra dilleri), tepeden inen tek kesik yeri yarar: yarıktan mavi alev fışkırır
static func susanoo_dan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_dan")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var tg = Jutsu._tg(c, t, 8.0 + H * 1.2)
	var aim = MsArts._aim_fn(c, tg, 4.0 + H * 0.5)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 2.0)
	MsArts._anim(c, "hook", 1.6)
	sn.hide_weapons(2.3)
	var ep = c.global_position + Vector3.UP + d * 1.2
	Combat.hit_sphere(c, ep, 1.6, MsArts._inf(c, "susanoo_dan", 0.08, {"knock": 2.0, "kind": "light", "stun": 0.4, "dir": d}))
	_flash(ep, 1.3, Color(1, 1, 1), col.lightened(0.3), 0.12)
	_ring(ep, d, 0.2, 1.4, 0.25, Color(1, 1, 1), col.lightened(0.4))
	var look = {"d": d}
	_sus_blade(sn, S, true, 2.1, func(): return look["d"], 0)
	var hot = col.lightened(0.35)
	var dark = col.darkened(0.65)
	var reach = 2.0 + S * 0.9
	for k in 3:
		MsArts._later(0.3 + k * 0.3, func():
			if not (is_instance_valid(sn) and MsArts._alive(c)):
				return
			var sg = 1.0 if k % 2 == 0 else -1.0
			sn.pose({"arms": Susanoo.arm(true, d * 0.7 - side * sg * 0.7, d * 0.5 - side * sg * 0.85), "spine": 8.0, "twist": -sg * 24.0}, 0.5, true)
			look["d"] = (d - side * sg * 0.9).normalized()
			MsArts._anim(c, "slash_a" if k % 2 == 0 else "slash_b", 1.5)
			var at: Vector3 = c.global_position + d * reach + Vector3.UP * (1.0 + H * 0.12)
			var sc = at - d * reach * 0.5
			_slash(sc, d, reach * 0.9, sg * 0.25, 0.3, Color(1, 1, 1), hot, dark, 0.16, 2.3, 0.4)
			for j in 5:   # yay boyunca kopan chakra dilleri
				var p = _arc_point(sc, d, sg * 0.25, reach * 0.95, 0.15 + j * 0.175)
				_tongue(p, 0.6 + S * 0.35, 0.25 + S * 0.1, Color(1, 1, 1), hot, 0.4, 0.8, dark)
			_streak(Jutsu._ground(at - side * sg * reach * 0.6) + Vector3.UP * 0.2, Jutsu._ground(at + side * sg * reach * 0.6) + Vector3.UP * 0.2, 0.12 + S * 0.03, 0.3, Color(0.95, 0.92, 0.85), DUST)
			Combat.hit_sphere(c, at, 1.6 + S * 0.7, MsArts._inf(c, "susanoo_dan", 0.16, {"knock": 1.0, "kind": "heavy", "blade": true, "bleed": 1.5, "hitstop": 0.04, "dir": d}))
			Sfx.play("swing_sword", c.global_position, 0.7))
	MsArts._later(1.25, func():
		if is_instance_valid(sn) and MsArts._alive(c):
			look["d"] = (Vector3.UP + d * 0.2).normalized()
			sn.pose({"arms": Susanoo.arm(true, Vector3.UP * 0.95 + d * 0.2, Vector3.UP), "spine": -14.0}, 0.5, true)
			_motes(sn.hand(true) + Vector3.UP * S * 0.8, 6, Color(1, 1, 1), hot, S * 0.6, S * 1.2, 0.4, 0.12 + S * 0.04, dark))   # kılıç tepede bekler, chakra toplanır
	MsArts._later(1.6, func():
		if not (is_instance_valid(sn) and MsArts._alive(c)):
			return
		look["d"] = (d - Vector3.UP * 0.5).normalized()
		sn.pose({"arms": Susanoo.arm(true, d * 0.85 - Vector3.UP * 0.5, d * 0.8 - Vector3.UP * 0.6), "spine": 24.0}, 0.6, true)
		MsArts._anim(c, "slash_c", 1.4)
		var g0 = Jutsu._ground(c.global_position + d * 1.5)
		var Lr = reach * 1.8
		_slash(c.global_position + d * reach * 0.4 + Vector3.UP * (1.5 + H * 0.2), d, reach * 1.2, PI * 0.5, 0.35, Color(1, 1, 1), hot, dark, 0.2, 2.3, 0.45)
		_furrow(g0, g0 + d * Lr, 0.9 + S * 0.35, Color(0.05, 0.05, 0.1), hot, 2.2, 0.14)
		var got: Array = []
		var inf = MsArts._inf(c, "susanoo_dan", 0.5, {"knock": 14.0, "launch": 2.0, "kind": "heavy", "blade": true, "bleed": 3.0, "hard_down": true, "hitstop": 0.1, "dir": d})
		for u in 4:   # yarık: kesiğin indiği hat boyunca
			var p = Jutsu._ground(g0 + d * Lr * (u + 0.5) / 4.0)
			_decal(p, 2.0 + S * 0.5, 0, Color(0.06, 0.05, 0.08), hot, 2.0, 7.0)
			_chunks(p + Vector3.UP * 0.3, 6, DIRT, 9.0, 0.8, 0.12 + S * 0.03)
			for j in 3:   # yarıktan fışkıran mavi alev
				_tongue(p + side * randf_range(-0.6, 0.6) * (0.5 + S * 0.2), 2.0 + S * 1.1, 0.7 + S * 0.25, Color(1, 1, 1), hot, 0.55 + j * 0.1, 0.6, dark)
			for f in Combat.hit_sphere(c, p + Vector3.UP, 1.4 + S * 0.6, inf, got):
				got.append(f)
		_light(g0 + d * Lr * 0.5 + Vector3.UP, col, 7.0, 12.0 + H * 0.5, 0.5)
		MsArts._shake(1.0)
		Sfx.play("hit_heavy", g0, 0.7))


## Susanoo: Retsu (須佐能乎・裂, Storm): geniş Susanoo kılıcı alttan savrulur, rakibin altından yükselen chakra sütunu onu
## havaya kaldırır; ikinci kılıç belirir, ikisi havada çapraz iner: gökte bir an asılı kalan parlak X yarası, dökülen chakra kırıkları
static func susanoo_retsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_retsu")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var hot = col.lightened(0.4)
	var dark = col.darkened(0.65)
	var tg = Jutsu._tg(c, t, 8.0 + H * 1.2)
	var aim = MsArts._aim_fn(c, tg, 4.0 + H * 0.5)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	var reach = 2.0 + S * 0.9
	pj.busy(c, 1.5)
	MsArts._anim(c, "slash_b", 1.2)
	sn.hide_weapons(1.9)
	var look = {"r": (d - Vector3.UP * 0.6).normalized(), "l": (d - Vector3.UP * 0.6).normalized()}
	_sus_blade(sn, S, true, 1.6, func(): return look["r"], 1)
	sn.pose({"arms": Susanoo.arm(true, d * 0.4 - Vector3.UP * 0.85, d * 0.7 - Vector3.UP * 0.6), "spine": 18.0}, 0.4, true)
	var at: Vector3 = c.global_position + d * reach + Vector3.UP
	var up_h = 5.0 + H * 0.35
	MsArts._later(0.3, func():
		if not (is_instance_valid(sn) and MsArts._alive(c)):
			return
		look["r"] = (d + Vector3.UP * 0.8).normalized()
		sn.pose({"arms": Susanoo.arm(true, d * 0.6 + Vector3.UP * 0.7, d * 0.4 + Vector3.UP * 0.9), "spine": -10.0}, 0.5, true)
		_slash(at + Vector3.UP * H * 0.1, d, reach * 0.9, -PI * 0.5, 0.3, Color(1, 1, 1), hot, dark, 0.2, 2.1, 0.3)
		var g = Jutsu._ground(at)
		_ring(g + Vector3.UP * 0.15, Vector3.UP, 0.4, 2.6 + S * 0.6, 0.35, Color(1, 1, 1), hot)
		for k in 7:   # kaldıran chakra sütunu
			var a = k * TAU / 7.0
			var o = Vector3(cos(a), 0, sin(a)) * (0.5 + S * 0.15)
			_streak(g + o, g + o + Vector3.UP * up_h, 0.14 + S * 0.03, 0.35 + k * 0.02, Color(1, 1, 1), hot)
		_chunks(g + Vector3.UP * 0.2, 6, DIRT, 8.0, 0.7, 0.1 + S * 0.02, 1.6)
		Sfx.play("swing_sword", c.global_position, 0.7)
		for f in Combat.hit_sphere(c, at, 1.8 + S * 0.7, MsArts._inf(c, "susanoo_retsu", 0.3, {"knock": 0.0, "launch": 0.0, "kind": "heavy", "blade": true, "hitstop": 0.06, "pierce_guard": true, "dir": Vector3.UP})):
			var fh = float(f.get("height")) if f.get("height") != null else 1.8
			if fh <= 4.0 and MsArts._alive(f):
				MsArts._carry(f, f.global_position + Vector3.UP * up_h, 0.4))
	MsArts._later(0.55, func():
		if is_instance_valid(sn) and MsArts._alive(c):
			_sus_blade(sn, S, false, 1.0, func(): return look["l"], 1)
			_flash(sn.hand(false), 1.0 + S * 0.3, Color(1, 1, 1), hot, 0.16)
			look["r"] = (Vector3.UP + side * 0.5).normalized()
			look["l"] = (Vector3.UP - side * 0.5).normalized()
			sn.pose({"arms": Susanoo.arm(true, Vector3.UP * 0.8 + side * 0.5 + d * 0.2, Vector3.UP + side * 0.3) + Susanoo.arm(false, Vector3.UP * 0.8 - side * 0.5 + d * 0.2, Vector3.UP - side * 0.3), "spine": -8.0}, 0.5, true))
	MsArts._later(0.95, func():
		if not (is_instance_valid(sn) and MsArts._alive(c)):
			return
		look["r"] = (d - side * 0.7 - Vector3.UP * 0.3).normalized()
		look["l"] = (d + side * 0.7 - Vector3.UP * 0.3).normalized()
		sn.pose({"arms": Susanoo.arm(true, d * 0.8 - side * 0.5 - Vector3.UP * 0.2, d * 0.7 - side * 0.7) + Susanoo.arm(false, d * 0.8 + side * 0.5 - Vector3.UP * 0.2, d * 0.7 + side * 0.7), "spine": 20.0}, 0.6, true)
		MsArts._anim(c, "slash_c", 1.5)
		var xp = at + Vector3.UP * up_h
		for rl in [0.8, -0.8]:
			_slash(xp - d * reach * 0.4, d, reach, rl, 0.3, Color(1, 1, 1), hot, dark, 0.16, 2.3, 0.35)
		var xl = reach * 0.9
		for sg in [1.0, -1.0]:   # havada asılı kalan X yarası
			var ax = (side * sg * 0.7 + Vector3.UP * 0.7).normalized()
			var xr = _mi(_xribbon([xp - ax * xl, xp, xp + ax * xl], [0.02, 0.22 + S * 0.05, 0.02]), _glow(Color(1, 1, 1), hot, dark, 1.0, 0.25, 1.5))
			_dissolve(xr, 0.45, 0.4)
		_flash(xp, 3.0 + S * 0.5, Color(1, 1, 1), hot, 0.2)
		_chunks(xp, 10, hot, 6.0 + S, 1.0, 0.08 + S * 0.03)   # dökülen chakra kırıkları
		Combat.hit_sphere(c, xp, 2.4 + S * 0.8, MsArts._inf(c, "susanoo_retsu", 0.7, {"knock": 18.0, "launch": 2.0, "kind": "heavy", "blade": true, "bleed": 3.0, "hitstop": 0.1, "dir": d}))
		Combat.hit_sphere(c, at, 1.8 + S * 0.6, MsArts._inf(c, "susanoo_retsu", 0.7, {"knock": 18.0, "kind": "heavy", "blade": true, "bleed": 3.0, "dir": d}))   # kaldırılamayan dev hedef yerde
		_light(xp, col, 6.0, 12.0 + H * 0.4, 0.4)
		MsArts._shake(0.8)
		Sfx.play("hit_sword", xp, 0.8))


## Susanoo: Nitō no Mai (須佐能乎・二刀の舞, Storm): Susanoo iki kavisli kılıcını sırayla savurur; her savuruş uzağa giden,
## ardında iki soluk yankı taşıyan hilal chakra dalgası bırakır; dalga yerde uzayan bir yarık çizer, geçtiği yerde toz kalkar
static func susanoo_nito_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "susanoo_nito_no_mai")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var hot = col.lightened(0.45)
	var dark = col.darkened(0.65)
	var tg = Jutsu._tg(c, t, 40.0 + H)
	var aim = MsArts._aim_fn(c, tg, 20.0 + H * 0.5)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.7)
	MsArts._anim(c, "slash_a", 1.0)
	sn.hide_weapons(2.1)
	var look = {"r": (d + side).normalized(), "l": (d - side).normalized()}
	_sus_blade(sn, S, true, 1.9, func(): return look["r"], 2)
	_sus_blade(sn, S, false, 1.9, func(): return look["l"], 2)
	var inf = MsArts._inf(c, "susanoo_nito_no_mai", 0.3, {"knock": 6.0, "kind": "heavy", "blade": true, "bleed": 2.0, "dir": d})
	for k in 4:
		MsArts._later(0.25 + k * 0.33, func():
			if not (is_instance_valid(sn) and MsArts._alive(c)):
				return
			var right = k % 2 == 0
			var sg = 1.0 if right else -1.0
			var dn: Vector3 = (aim.call() - c.global_position)
			dn.y = 0.0
			dn = dn.normalized() if dn.length() > 0.5 else d
			look["r" if right else "l"] = (dn - side * sg * 0.8).normalized()
			sn.pose({"arms": Susanoo.arm(right, dn * 0.8 - side * sg * 0.6, dn * 0.6 - side * sg * 0.8), "spine": 10.0, "twist": -sg * 22.0}, 0.45, true)
			MsArts._anim(c, "slash_a" if right else "slash_b", 1.5)
			Sfx.play("swing_sword", c.global_position, 0.6 + k * 0.08)
			var from = c.global_position + Vector3.UP * (1.2 + H * 0.3) + dn * (1.5 + S * 0.6)
			var R = 2.0 + S * 0.9
			var bas = MsArts._zbasis(dn) * Basis(Vector3(0, 0, 1), sg * 0.7) * Basis.from_scale(Vector3(R, 1.0, R * 0.5))
			var dist = 34.0 + H * 0.6
			var waves = []
			for j in 3:   # ana dalga + iki soluk yankı
				var w = _mi(_crescent(1.0, 2.4, 0.4 - j * 0.08), _glow(Color(1, 1, 1), hot if j == 0 else col, dark, 1.0 - j * 0.3, 0.35, 3.0, 3.0))
				w.global_transform = Transform3D(bas, from)
				waves.append(w)
			var fur: MeshInstance3D = null
			if from.y - Jutsu._ground(from).y < R + 2.0:   # alçak dalga yerde yarık çizer
				fur = _furrow(from, from + dn * dist, 0.5 + S * 0.15, Color(0.07, 0.06, 0.1), hot, 1.2, 0.0)
			var got: Array = []
			var st = {"dust": 0.0}
			var tw = MsArts._tw()
			tw.tween_method(func(x: float):
				for j in waves.size():
					var w = waves[j]
					if not is_instance_valid(w):
						continue
					var xj = maxf(0.0, x - 0.05 * j)
					w.global_transform = Transform3D(bas, from + dn * xj * dist - Vector3.UP * xj * H * 0.25)
					w.set_instance_shader_parameter("fade", maxf(0.0, x - 0.75) * 3.2)
				_iparam(fur, "grow", x)
				var pos = from + dn * x * dist - Vector3.UP * x * H * 0.25
				if x - st["dust"] > 0.12:
					st["dust"] = x
					var gq = Jutsu._ground(pos)
					if pos.y - gq.y < R * 0.8 + 1.0:
						_dust(gq, 0.8 + S * 0.25, 4, DUST, 0.45)
				if MsArts._alive(c):
					for f in Combat.hit_sphere(c, pos + dn * R * 0.4, R * 0.7, inf, got):
						got.append(f)
						_flash(MsArts._chest(f), 1.6 + S * 0.2, Color(1, 1, 1), hot, 0.14), 0.0, 1.0, 0.5)
			tw.tween_callback(func():
				for w in waves:
					if is_instance_valid(w):
						w.queue_free()))


# ================================================================== ITACHI
## Totsuka no Tsurugi: Renzokugiri (十拳剣・連続斬り, Storm): mevcut Totsuka modeli, akan sake gibi saydam ruh sıvısıyla;
## iki yatay kesik (yay boyunca savrulan sıvı damlaları), mühür yazısı halkası büzülen bir saplama; Itachi ateş topuyla bitirir
static func totsuka_renzokugiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var sn = Susanoo.of(c, "totsuka_renzokugiri")
	if sn == null:
		return
	var H = sn.h()
	var S = H / 1.8
	var col = sn.color()
	var liq = col.lightened(0.45)
	var dark = col.darkened(0.6)
	var tg = Jutsu._tg(c, t, 9.0 + H * 1.2)
	var aim = MsArts._aim_fn(c, tg, 4.0 + H * 0.5)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	var reach = 2.0 + S * 0.9
	pj.busy(c, 2.0)
	MsArts._anim(c, "slash_a", 1.0)
	sn.hide_weapons(2.0)
	var look = {"d": (d + side).normalized()}
	var blade = Node3D.new()
	_mi(MsArts._blade_mesh(), _ghost_m(col.lightened(0.15), Color(1, 1, 1), 0.5, 7.0), blade)
	var inner = _mi(MsArts._blade_mesh(), _cel(Color(1.0, 0.97, 0.9), liq, 1.0), blade)
	inner.scale = Vector3(0.38, 0.38, 1.0)
	var holder = Node3D.new()   # model +Z'ye uzar; follow_fx -Z'yi yöne çevirir
	holder.add_child(blade)
	blade.rotation.y = PI
	MsArts._scene().add_child(holder)
	holder.scale = Vector3.ONE * S * 0.45
	sn.follow_fx(holder, 1.5, func(): return sn.hand(true), func(): return look["d"])
	for k in 10:   # kılıçtan damlayan ruh sıvısı
		MsArts._later(0.1 + k * 0.13, func():
			if is_instance_valid(blade) and blade.is_inside_tree():
				_chunks(blade.global_transform * Vector3(0, 0, randf_range(0.2, 0.95)), 1, liq, 1.0, 0.6, 0.06 * S, -0.5, Vector3.ZERO, true))
	MsArts._later(1.5, func():
		if is_instance_valid(holder):
			holder.queue_free())
	for k in 2:
		MsArts._later(0.25 + k * 0.35, func():
			if not (is_instance_valid(sn) and MsArts._alive(c)):
				return
			var sg = 1.0 if k == 0 else -1.0
			look["d"] = (d - side * sg * 0.9).normalized()
			sn.pose({"arms": Susanoo.arm(true, d * 0.7 - side * sg * 0.7, d * 0.5 - side * sg * 0.85), "spine": 8.0, "twist": -sg * 24.0}, 0.5, true)
			MsArts._anim(c, "slash_a" if k == 0 else "slash_b", 1.4)
			var at: Vector3 = c.global_position + d * reach + Vector3.UP * (1.0 + H * 0.12)
			var sc = at - d * reach * 0.5
			_slash(sc, d, reach * 0.9, 0.0, 0.28, Color(1, 1, 1), liq, dark, 0.11, 2.3, 0.15, 0.85)
			for j in 8:   # yay boyunca savrulan damlalar
				var tt = 0.1 + j * 0.1
				var p = _arc_point(sc, d, 0.0, reach * 0.95, tt)
				var tang = (_arc_point(sc, d, 0.0, reach * 0.95, tt + 0.05) - p).normalized() * -sg
				_chunks(p, 1, liq, 4.0 + S, 0.55, 0.07 * S, 0.4, tang * 1.5, true)
			Combat.hit_sphere(c, at, 1.6 + S * 0.7, MsArts._inf(c, "totsuka_renzokugiri", 0.2, {"knock": 1.0, "kind": "heavy", "blade": true, "stun": 0.4, "hitstop": 0.05, "dir": d}))
			Sfx.play("swing_sword", c.global_position, 0.75))
	MsArts._later(1.0, func():
		if not (is_instance_valid(sn) and MsArts._alive(c)):
			return
		var ad = (aim.call() - sn.bone_at("RightUpperArm")).normalized()
		look["d"] = ad
		sn.pose({"arms": Susanoo.arm(true, ad, ad, ad), "spine": 14.0}, 0.5, true)
		var at: Vector3 = aim.call()
		Combat.hit_sphere(c, at, 1.6 + S * 0.6, MsArts._inf(c, "totsuka_renzokugiri", 0.3, {"knock": 2.0, "kind": "heavy", "blade": true, "stun": 0.8, "hitstop": 0.08, "pierce_guard": true, "dir": d}))
		_seal_ring(at, d, 1.4 + S * 0.4, liq, dark)
		_flash(at, 1.6 + S * 0.4, Color(1, 1, 1), liq, 0.16)
		Sfx.play("hit_sword", at, 0.8))
	MsArts._later(1.45, func():
		if not MsArts._alive(c):
			return
		MsArts._anim(c, "cast_out", 1.4)
		var from = Jutsu._mouth(c) + d * 0.5
		var ball = _fireball(1.0)
		ball.scale = Vector3.ONE * 0.3
		ball.create_tween().tween_property(ball, "scale", Vector3.ONE * 1.5, 0.25)
		_flash(from, 1.0, Color(1, 0.97, 0.8), Color(1.0, 0.6, 0.15), 0.12)
		var dir: Vector3 = (aim.call() - from).normalized()
		var pr = pj.shot(c, from, dir, 24.0, ball, MsArts._inf(c, "totsuka_renzokugiri", 0.5, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "element": "katon", "burn": 4.0}), tg, false, 1.8, func(p, _h):
			_fire_burst(p, 1.0))
		pr.radius = 1.3
		Sfx.play("fire", from, 0.9))


## Saplamada mühür: hedefin çevresinde dönerek büzülen sıvı yazı çizgileri
static func _seal_ring(at: Vector3, normal: Vector3, r: float, liq: Color, dark: Color) -> void:
	var h = Node3D.new()
	MsArts._scene().add_child(h)
	h.global_transform = Transform3D(_ybasis(normal), at)
	var m = _glow(Color(1, 1, 1), liq, dark, 1.0, 0.1, 0.5)
	for k in 8:
		var a = k * TAU / 8.0
		var q = _mi(_quad(), m, h)
		q.position = Vector3(cos(a), 0, sin(a)) * r
		q.rotation = Vector3(-PI * 0.5, -a, 0)
		q.scale = Vector3(0.12 + 0.05 * (k % 3), 0.5 + 0.15 * (k % 2), 1.0) * (r / 1.6)
	var tw = h.create_tween()
	tw.set_parallel(true)
	tw.tween_property(h, "scale", Vector3.ONE * 0.15, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(_x: float):
		if is_instance_valid(h):
			h.rotate_object_local(Vector3.UP, 0.25), 0.0, 1.0, 0.35)
	tw.chain().tween_method(func(x: float): _fade_tree(h, x), 0.0, 1.0, 0.12)
	tw.chain().tween_callback(h.queue_free)


## Tsukuyomi Mōdo (月読モード, Ultimate Ninja): gözden kızıl parlama; kullanıcıdan dışa süpüren pembe-kızıl perde alanı kaplar,
## yerde sahibinin dönen Mangekyō'su, sınırda tırtıklı kızıl halka, tepede kızıl ay. İçindeki rakipler ağırlaşır (zihinleri
## tutulur); tutulan her rakibin ayağında kızıl dalga. Açık kaldıkça kullanıcının canı ve chakrası erir.
static func tsukuyomi_mode(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var R = 14.0
	var dur = 8.0
	pj.busy(c, 0.6)
	MsArts._anim(c, "cast", 1.0)
	_flash(Jutsu._mouth(c) + Vector3.UP * 0.12, 0.9, Color(1, 0.85, 0.85), RED, 0.3)
	Sfx.play("genjutsu", c.global_position, 0.6)
	if c == Game.player and Game.world:
		Game.world.env.set_tint(Color(0.55, 0.0, 0.06, 0.14))
		MsArts._later(dur, func():
			if Game.world:
				Game.world.env.set_tint(Color(0, 0, 0, 0)))
	# yerde dönen dev Mangekyō: alanın sınırı
	var ctr = Jutsu._ground(c.global_position)   # alan kurulduğu yerde kalır (bariyer)
	var disc = _eye_disc(c, R * 2.0, false)
	disc.mesh = _gdisc(ctr, R)
	MsArts._scene().add_child(disc)
	disc.global_position = ctr
	var dm: ShaderMaterial = disc.material_override
	dm.set_shader_parameter("fade", 0.0)
	dm.set_shader_parameter("glow", 1.0)
	# süpüren perde (kaynak: alanı tarayan pembe-kızıl yarı saydam dalga)
	var wave = _mi(_band_ring(), _glow(Color(1.0, 0.82, 0.86), RED, Color(0.3, 0.0, 0.04), 0.5, 0.45, 1.5, 4.0))
	wave.global_position = ctr
	wave.scale = Vector3(0.6, 3.2, 0.6)
	var wt = wave.create_tween()
	wt.tween_property(wave, "scale", Vector3(R, 2.2, R), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wt.tween_method(func(x: float): _fade_tree(wave, x), 0.0, 1.0, 0.6)
	wt.tween_callback(wave.queue_free)
	_decal(ctr, R, 3, Color(0.25, 0.0, 0.03), RED, dur - 1.2, 0.0, 0.7, 0.05)   # alan sınırı
	var moon = _mi(_quad(), _glow(Color(1.0, 0.72, 0.68), Color(0.82, 0.04, 0.1), Color(0.15, 0.0, 0.02), 0.95, 0.04, 0.2, 0.0, true, true))
	moon.global_position = ctr + Vector3.UP * (R + 6.0)
	moon.scale = Vector3.ONE * 7.0
	_fade_tree(moon, 1.0)
	var mt = moon.create_tween()
	mt.tween_method(func(x: float): _fade_tree(moon, 1.0 - x), 0.0, 1.0, 0.8)
	_dissolve(moon, dur - 0.8, 0.6)
	var seen = {}
	var st = {"tick": -1.0}
	var wr = weakref(c)
	var tw = disc.create_tween()
	tw.tween_method(func(x: float):
		var n = wr.get_ref()
		if n == null or n.is_dead():
			dm.set_shader_parameter("fade", 0.0)
			return
		var el = x * dur
		dm.set_shader_parameter("fade", 0.65 * minf(1.0, el * 3.0) * minf(1.0, (dur - el) * 2.0))
		if el - st["tick"] < 0.5:
			return
		st["tick"] = el
		# bedel: can ve chakra erir
		if "chakra" in n:
			n.chakra = maxf(0.0, float(n.chakra) - 3.0)
		n.hp = maxf(1.0, float(n.hp) - float(n.max_hp) * 0.006)
		for f in MsArts._foes(n, ctr, R):
			var id = f.get_instance_id()
			if not seen.has(id):
				seen[id] = Eyes.genjutsu_land(n, f, false)
				if float(seen[id]) > 0.0:
					Combat.popup_text(MsArts._chest(f) + Vector3.UP, "Tsukuyomi", Color(1.0, 0.4, 0.45))
					_ring(Jutsu._ground(f.global_position) + Vector3.UP * 0.12, Vector3.UP, 0.3, 1.8, 0.6, Color(1.0, 0.75, 0.78), RED, false, 0.3, 0.8, Color(0.25, 0.0, 0.03))
			if float(seen[id]) > 0.0:
				f.apply_status("slow", 0.8), 0.0, 1.0, dur)
	tw.tween_callback(disc.queue_free)


# ================================================================== OBITO
## Saten (鎖天, Storm): Obito geçirgen hâlde rakibin içinden geçer (rakibin göğsünde uzay dalgalanır, ardında soluk iz);
## bileklerindeki demir zincir rakibe dolanır; zincirle havaya savurur, Kamui ile tepesine ışınlanıp yumrukla yere çakar
static func saten(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 14.0)
	if tg == null:
		if c is Player:
			Hud.msg("Saten: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = MsArts._turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var big = H > 4.0   # dev hedef havaya kaldırılamaz: zincir dolanır, tepeden yumruk iner
	pj.busy(c, 1.7)
	_intangible(c, 0.45)
	MsArts._anim(c, "dash", 1.4)
	var from = c.global_position
	var past = Jutsu._ground(tg.global_position + d * (2.4 + H * 0.2))
	var tw = MsArts._tw()
	tw.tween_method(func(x: float):
		if MsArts._alive(c):
			MsArts._blink(c, from.lerp(past, x)), 0.0, 1.0, 0.3)
	_swirl(MsArts._chest(tg), 0.7, 0.5, 1.0)
	_ring(MsArts._chest(tg), d, 0.3, 1.3, 0.35, Color(0.85, 0.82, 0.92), OBI_PALE)
	_echo(c, OBI_INK, OBI_PALE, 0.3, 0.35)
	Sfx.play("whoosh", from, 1.4)
	var wr = weakref(tg)
	MsArts._later(0.32, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not MsArts._alive(c):
			return
		MsArts._turn(c, n.global_position)
		MsArts._anim(c, "cast_out", 1.5)
		_chain_wrap(n, 0.5)
		_chain(c.global_position + Vector3.UP * 1.1, MsArts._chest(n), 0.5)
		n.apply_status("bind", 0.6)
		n.take_hit(MsArts._inf(c, "saten", 0.25, {"knock": 0.0, "launch": 0.0, "kind": "light", "pierce_guard": true}))
		_flash(MsArts._chest(n), 0.8, Color(1, 1, 1), Color(0.75, 0.75, 0.82), 0.1)
		Sfx.play("chain", n.global_position, 1.0))
	MsArts._later(0.8, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not MsArts._alive(c):
			return
		MsArts._anim(c, "slash_c", 1.6)   # zinciri yukarı savurur
		if not big:
			var g0 = Jutsu._ground(n.global_position)
			MsArts._carry(n, n.global_position + Vector3.UP * 6.5, 0.32)
			_dust(g0, 1.6, 7, DUST, 0.5)
			for k in 4:
				var o = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
				_streak(g0 + o + Vector3.UP * 0.5, g0 + o + Vector3.UP * 5.5, 0.1, 0.3, Color(0.95, 0.95, 1.0), OBI_PALE)
		MsArts._later(0.12, func():
			var m = wr.get_ref()
			if m != null and MsArts._alive(c):
				_chain(c.global_position + Vector3.UP * 1.3, MsArts._chest(m), 0.3, 0.1, 0.05))
		_slash(c.global_position + Vector3.UP * 1.2, d, 2.2, -PI * 0.5, 0.25, Color(0.9, 0.9, 0.95), Color(0.5, 0.5, 0.56), INK, 0.07, 1.6, 0.1, 0.8)
		Sfx.play("swing_chain", c.global_position, 1.0))
	MsArts._later(1.25, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not MsArts._alive(c):
			return
		var top = n.global_position + Vector3.UP * (H + 0.6)
		_kamui_hop(c, top)
		MsArts._anim(c, "cross", 1.6)
		var g = Jutsu._ground(n.global_position)
		if not big:
			MsArts._carry(n, g, 0.14)
		for k in 3:
			var o = Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
			_streak(top + o + Vector3.UP * 1.5, g + o + Vector3.UP * 0.6, 0.09, 0.2, Color(1, 1, 1), OBI_PALE)
		MsArts._later(0.15, func():
			var m = wr.get_ref()
			if not MsArts._alive(c):
				return
			if m != null and not m.is_dead():
				m.take_hit(MsArts._inf(c, "saten", 0.75, {"knock": 4.0, "launch": -12.0, "kind": "heavy", "hard_down": true, "hitstop": 0.09, "dir": Vector3.DOWN}))
			_decal(g, 3.5, 0, Color(0.1, 0.08, 0.07), Color(0.55, 0.46, 0.36), 3.0, 10.0)
			_chunks(g + Vector3.UP * 0.3, 12, DIRT, 8.0, 0.9, 0.16)
			_dust(g, 3.0, 9, DUST, 0.7)
			_ring(g + Vector3.UP * 0.15, Vector3.UP, 0.5, 4.0, 0.35, Color(1, 1, 1), DUST)
			MsArts._shake(0.6)
			Sfx.play("hit_heavy", g, 0.8)
			MsArts._blink(c, Jutsu._ground(g - d * 1.6) + Vector3.UP * 0.05)))


## Sain (鎖引, Storm): bilek zinciri uzaktaki rakibe uzanıp dolanır; Obito onu zincirle iki yana yere savurur (yerde göçük,
## yana fışkıran toprak), sonra Kamui ile üstüne ışınlanıp dönen tekmeyle indirir (gövdesini saran dönme izi)
static func sain(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 18.0)
	if tg == null:
		if c is Player:
			Hud.msg("Sain: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = MsArts._turn(c, tg.global_position)
	var side = d.cross(Vector3.UP).normalized()
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var big = H > 4.0
	pj.busy(c, 2.0)
	MsArts._anim(c, "throw", 1.5)
	var hand = func() -> Vector3: return c.global_position + Vector3.UP * 1.3 + d * 0.4
	_chain(hand.call(), MsArts._chest(tg), 0.42, 0.3, 0.14)
	Sfx.play("swing_chain", c.global_position, 1.1)
	var wr = weakref(tg)
	var base = tg.global_position
	MsArts._later(0.18, func():
		var n = wr.get_ref()
		if n != null and not n.is_dead():
			_chain_wrap(n, 0.25)
			_flash(MsArts._chest(n), 0.7, Color(1, 1, 1), Color(0.75, 0.75, 0.82), 0.1)
			n.apply_status("bind", 1.6)
			Sfx.play("chain", n.global_position, 1.1))
	for k in 2:
		MsArts._later(0.42 + k * 0.5, func():
			var n = wr.get_ref()
			if n == null or n.is_dead() or not MsArts._alive(c):
				return
			MsArts._turn(c, n.global_position)
			MsArts._anim(c, "slash_a" if k == 0 else "slash_b", 1.3)
			var sgn = 1.0 if k == 0 else -1.0
			var to = Jutsu._ground(base + side * (3.2 if k == 0 else -3.2) - d * 1.0)
			if not big:
				MsArts._carry(n, to, 0.34, 3.4)
			_chain(hand.call(), n.global_position + Vector3.UP * (H * 0.5 + 2.2), 0.3, 0.2, 0.06)
			var mid = (n.global_position + to) * 0.5 + Vector3.UP * 2.0
			_slash(mid, (to - n.global_position).normalized() if (to - n.global_position).length() > 0.2 else side * sgn, 2.0, PI * 0.5, 0.3, Color(0.92, 0.92, 0.96), Color(0.5, 0.5, 0.58), INK, 0.08, 1.8, 0.1, 0.75)
			Sfx.play("swing_chain", c.global_position, 0.9 + k * 0.15)
			MsArts._later(0.35, func():
				var m = wr.get_ref()
				if m == null or m.is_dead() or not MsArts._alive(c):
					return
				m.take_hit(MsArts._inf(c, "sain", 0.3, {"knock": 0.0, "launch": 0.0, "kind": "heavy", "hitstop": 0.06, "pierce_guard": true, "dir": Vector3.DOWN}))
				m.apply_status("bind", 0.6)
				var gp = m.global_position
				_decal(gp, 2.6, 0, Color(0.1, 0.08, 0.07), Color(0.55, 0.46, 0.36), 2.5, 7.0)
				_chunks(gp + Vector3.UP * 0.3, 8, DIRT, 7.0, 0.8, 0.12, 1.0, side * sgn * 0.8)
				_dust(gp, 1.8, 6, DUST, 0.5)
				_chain(hand.call(), MsArts._chest(m), 0.12, 0.15, 0.02)
				MsArts._shake(0.4)
				Sfx.play("hit_chain", m.global_position, 0.9)))
	MsArts._later(1.5, func():
		var n = wr.get_ref()
		if n == null or n.is_dead() or not MsArts._alive(c):
			return
		var bd = n.global_position - c.global_position
		bd.y = 0.0
		bd = bd.normalized() if bd.length() > 0.2 else d
		_kamui_hop(c, n.global_position + bd * 1.0 + Vector3.UP * (H + 1.2))
		MsArts._turn(c, n.global_position)
		MsArts._anim(c, "fin_c", 1.8)
		var g = Jutsu._ground(n.global_position)
		var spin = Node3D.new()   # dönen tekmenin izi: gövdeyi saran yatay girdap
		c.add_child(spin)
		spin.position = Vector3.UP * 0.9
		var sm = _mi(_crescent(1.0, TAU * 0.85, 0.3, 36), _glow(Color(1, 1, 1), OBI_PALE, OBI_INK, 0.85, 0.3, 4.0), spin)
		sm.scale = Vector3.ONE * 1.1
		var stw = spin.create_tween()
		stw.tween_method(func(x: float):
			if is_instance_valid(spin):
				spin.rotation.y = -x * TAU * 2.0, 0.0, 1.0, 0.3)
		_dissolve(spin, 0.12, 0.2)
		var tw = MsArts._tw()
		var p0 = c.global_position
		tw.tween_method(func(x: float):
			if MsArts._alive(c):
				MsArts._blink(c, p0.lerp(g - bd * 0.2 + Vector3.UP * (H * 0.8), x))
				if c.get("model"):
					c.model.rotation.y += 0.9, 0.0, 1.0, 0.16)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if not MsArts._alive(c):
				return
			if c.get("model"):
				c.model.rotation.y = 0.0
			if m != null and not m.is_dead():
				m.take_hit(MsArts._inf(c, "sain", 0.4, {"knock": 9.0, "launch": -8.0, "kind": "heavy", "hard_down": true, "hitstop": 0.08, "dir": -bd}))
				_flash(MsArts._chest(m), 2.0, Color(1, 1, 1), Color(0.8, 0.8, 0.88), 0.14)
			_ring(g + Vector3.UP * 0.15, Vector3.UP, 0.4, 3.2, 0.3, Color(1, 1, 1), DUST)
			_dust(g, 2.2, 7, DUST, 0.55)
			Sfx.play("hit_heavy", g, 1.0)
			MsArts._blink(c, Jutsu._ground(g + bd * 1.4) + Vector3.UP * 0.05)))


## Muzan (無惨, Storm): Obito içe çeken burgaçla kaybolur (zerreler içine akar), rakibin tam tepesinde dışa açılan burgaçtan
## çıkar ve dikey hız çizgileriyle üstüne çöküp kunaiyi saplar: ince dikey kesik, kızıl damlalar, küçük çatlak
static func muzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 45.0)
	if tg == null:
		if c is Player:
			Hud.msg("Muzan: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	MsArts._turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	pj.busy(c, 0.95)
	MsArts._flicker_guard(c, 0.7)
	MsArts._anim(c, "cast", 2.0)
	_swirl(MsArts.KS.eye_point(c), 1.0, 0.5, 1.0)
	Sfx.play("th_teleport", c.global_position, 1.1, 0.7)
	MsArts.KS.twist_into(c, MsArts.KS.eye_point(c), 0.28)   # sağ gözdeki burgaca akar (dönmez)
	var wr = weakref(tg)
	MsArts._later(0.3, func():
		if not MsArts._alive(c):
			return
		var n = wr.get_ref()
		if n == null or n.is_dead():
			var mm = c.get("model")
			if mm:
				mm.visible = true
			return
		var top = n.global_position + Vector3.UP * (H + 6.0)
		MsArts._blink(c, top)
		_swirl(MsArts.KS.eye_point(c), 1.1, 0.5, -1.0)
		MsArts.KS.twist_into(c, MsArts.KS.eye_point(c), 0.22, true)
		MsArts._anim(c, "fall", 1.0)
		var tw = MsArts._tw()
		tw.tween_interval(0.12)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if m == null:
				return
			for k in 5:
				var o = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
				_streak(top + o + Vector3.UP * 1.0, m.global_position + o + Vector3.UP * H, 0.08, 0.22, Color(1, 1, 1), OBI_PALE))
		tw.tween_method(func(x: float):
			var m = wr.get_ref()
			if MsArts._alive(c) and m != null:
				MsArts._blink(c, top.lerp(m.global_position + Vector3.UP * (H * 0.75), x)), 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			var m = wr.get_ref()
			if not MsArts._alive(c) or m == null or m.is_dead():
				return
			MsArts._anim(c, "slash_c", 2.0)
			var g = Jutsu._ground(m.global_position)
			m.take_hit(MsArts._inf(c, "muzan", 1.0, {"knock": 3.0, "launch": -10.0, "kind": "heavy", "blade": true, "bleed": 4.0, "hard_down": true, "hitstop": 0.1, "dir": Vector3.DOWN}))
			var hp = MsArts._chest(m) + Vector3.UP * 0.4
			var cut = _mi(_tongue_mesh(), _glow(Color(1, 1, 1), Color(0.85, 0.85, 0.92), INK, 1.0, 0.1, 0.0, 0.0, false, true))   # dikey kunai kesiği
			cut.global_position = hp - Vector3.UP * 1.2
			cut.scale = Vector3(0.18, 2.6, 1.0)
			_dissolve(cut, 0.08, 0.2)
			_flash(hp, 1.8, Color(1, 1, 1), Color(0.8, 0.8, 0.9), 0.14)
			_chunks(hp, 7, Color(0.6, 0.03, 0.05), 4.0, 0.6, 0.05, 0.6, Vector3.ZERO, true)
			_decal(g, 2.4, 0, Color(0.1, 0.08, 0.07), Color(0.55, 0.46, 0.36), 2.0, 8.0)
			_dust(g, 1.6, 6, DUST, 0.45)
			MsArts._shake(0.5)
			Sfx.play("hit_blade", g, 0.9)
			var back = m.global_position - c.global_position
			back.y = 0.0
			MsArts._blink(c, Jutsu._ground(g - (back.normalized() if back.length() > 0.1 else c.face_dir()) * 1.4) + Vector3.UP * 0.05)))


## Mekkyaku (滅却, Storm; kaynak: gri dünyada eşmerkezli beyaz halkalar, sarı tırtıklı vuruş kıvılcımları, kara benekler):
## Obito yumruk / tekme yağdırır; her darbe sarı tırtıklı kıvılcım + kara mürekkep benekleri, aralarda geçirgenleşip
## eşmerkezli halka dalgalarıyla yer değiştirir; son darbede rakibin ardında büyük beyaz halkalar
static func mekkyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 9.0)
	if tg == null:
		if c is Player:
			Hud.msg("Mekkyaku: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d0 = MsArts._turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var reach = 1.3 + H * 0.15
	pj.busy(c, 1.75)
	MsArts._flicker_guard(c, 1.7)
	var wr = weakref(tg)
	var base = atan2(-d0.x, -d0.z)
	var angs = [0.0, 2.2, -1.9, 3.14, 1.1, -0.4]   # hedefin çevresinde: ön, sol arka, sağ arka, arka, sol, ön
	var anims = ["jab", "cross", "hook", "jab", "hook", "cross"]
	for k in 6:
		MsArts._later(0.05 + k * 0.27, func():
			var n = wr.get_ref()
			if n == null or n.is_dead() or not MsArts._alive(c):
				_see_through(c.get("model") if is_instance_valid(c) else null, 0.0)
				return
			var a = base + angs[k]
			var at = Jutsu._ground(n.global_position + Vector3(sin(a), 0, cos(a)) * reach)
			if k > 0:
				_ripples(c.global_position + Vector3.UP * 1.1, 2, 0.5, 1.1)
			MsArts._blink(c, at + Vector3.UP * 0.05)
			var d = MsArts._turn(c, n.global_position)
			_see_through(c.get("model"), 0.0)   # vururken katı
			MsArts._anim(c, anims[k], 2.0)
			var last = k == 5
			n.take_hit(MsArts._inf(c, "mekkyaku", 0.3 if last else 0.14, {"knock": 11.0 if last else 0.3, "launch": 3.0 if last else 0.0, "kind": "heavy" if last else "light",
				"stun": 0.0 if last else 0.35, "hitstop": 0.07 if last else 0.03, "dir": d}))
			_hit_burst(MsArts._chest(n) - d * 0.3, d, 1.6 if last else 1.0)
			Sfx.play("punch", n.global_position, 1.0 + k * 0.05, 0.8)
			if last:
				_ripples(MsArts._chest(n) + d * 0.6, 4, 1.0, 4.5)
				MsArts._shake(0.4)
			else:
				MsArts._later(0.13, func():
					if MsArts._alive(c):
						_see_through(c.get("model"), 0.6)))   # darbe arası geçirgen
	MsArts._later(1.75, func():
		if is_instance_valid(c):
			_see_through(c.get("model"), 0.0))


## Mekkyaku vuruşu: darbe yönüne fışkıran sarı tırtıklı kıvılcımlar + kara benekler
static func _hit_burst(at: Vector3, dir: Vector3, s: float) -> void:
	for k in 7:
		var dv = (dir + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.8), randf_range(-0.8, 0.8))).normalized()
		var pts = _jag_pts(at, at + dv * randf_range(0.8, 1.6) * s, 4, 0.6)
		var wid = []
		for i in pts.size():
			wid.append(0.13 * s * lerpf(1.0, 0.1, i / float(pts.size() - 1)))
		var mi = _mi(_xribbon(pts, wid), _glow(YEL_HOT, YEL, INK, 1.0, 0.1, 0.0))
		var tw = mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", dv * 0.4 * s, 0.2)
		tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, 0.2).set_delay(0.06)
		tw.chain().tween_callback(mi.queue_free)
	_flash(at, 1.2 * s, YEL_HOT, YEL, 0.12)
	_chunks(at, 6, Color(0.06, 0.05, 0.06), 5.0 * s, 0.45, 0.06 * s, 0.6, dir, true)


## Eşmerkezli halka dalgaları (kameraya bakan), sırayla açılır
static func _ripples(at: Vector3, n: int, r0: float, r1: float) -> void:
	for k in n:
		MsArts._later(k * 0.06, func():
			_ring(at, Vector3.UP, r0, r1 * (0.7 + 0.3 * k / maxf(1.0, n - 1.0)), 0.35, Color(0.97, 0.97, 0.97), Color(0.62, 0.62, 0.66), true, 0.12, 0.7))


## Tensō (転葬, Storm): rakip Kamui burgacına çekilir; Obito rakibin yerine halka hâlinde kibaku fuda saçar (kendi çizdiğimiz
## mühür kâğıtları kavisle uçup yere yapışır, kenarlarından yanar); rakip mühürlerin tam ortasına geri bırakılır ve hepsi patlar
static func tenso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 12.0)
	if tg == null:
		if c is Player:
			Hud.msg("Tensō: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	var d = MsArts._turn(c, tg.global_position)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var fits = H <= 4.0 and not (tg is TailedBeast)
	pj.busy(c, 1.5)
	MsArts._anim(c, "cast", 1.2)
	var P = Jutsu._ground(tg.global_position)
	var wr = weakref(tg)
	var mdl = tg.get("model")
	var tp = MsArts.KS.touch_point(c, tg)
	_swirl(tp, 1.5, 0.75, 1.0)
	Sfx.play("th_teleport", P, 0.8)
	if fits:
		tg.apply_status("bind", 1.5)
		MsArts.KS.twist_into(tg, tp, 0.5)   # burgaca akıp kaybolur (dönmez)
	# mühürler: rakibin durduğu yerin çevresine halka
	MsArts._later(0.35, func():
		if not MsArts._alive(c):
			return
		MsArts._anim(c, "throw", 1.6)
		var from = c.global_position + Vector3.UP * 1.3 + d * 0.4
		for k in 7:
			var a = k * TAU / 6.0
			var to = P + (Vector3(cos(a), 0, sin(a)) * 1.5 if k < 6 else Vector3.ZERO) + Vector3.UP * 0.03
			_fly_tag(c, from, to, 0.4 + k * 0.02)
		Sfx.play("throw", c.global_position, 1.2))
	MsArts._later(1.0, func():
		var n = wr.get_ref()
		if n == null or not fits:
			return
		if n.is_dead():
			if mdl != null and is_instance_valid(mdl):
				mdl.visible = true
			return
		n.global_position = P
		if n.has_method("reset_physics_interpolation"):
			n.reset_physics_interpolation()
		var ep = P + Vector3.UP * (float(n.get("height")) if n.get("height") != null else 1.8) * 0.62
		_swirl(ep, 1.2, 0.4, -1.0)
		MsArts.KS.twist_into(n, ep, 0.3, true))   # burgaçtan açılarak geri bırakılır
	MsArts._later(1.14, func():
		if not MsArts._alive(c):
			return
		_fire_burst(P + Vector3.UP * 0.6, 1.5)
		_ring(P + Vector3.UP * 0.2, Vector3.UP, 0.6, 5.0, 0.4, Color(1.0, 0.95, 0.8), Color(1.0, 0.55, 0.15))
		_chunks(P + Vector3.UP * 0.8, 10, Color(0.93, 0.88, 0.72), 6.0, 1.2, 0.08, 1.2)   # savrulan kâğıt külü
		_chunks(P + Vector3.UP * 0.3, 8, DIRT, 8.0, 0.8, 0.14)
		Combat.hit_sphere(c, P + Vector3.UP * 0.8, 4.2, MsArts._inf(c, "tenso", 1.0, {"knock": 13.0, "launch": 6.0, "kind": "heavy", "burn": 3.0, "hitstop": 0.08}))
		MsArts._shake(1.0)
		Sfx.play("boom", P, 1.0))


## Uçan kibaku fuda: kavisle döne döne uçar, yere yapışır, 0.35 sn sonra yanıp patlar (keyed_combos._fly_tag mekaniği aynen:
## her biri hasarsız bir itme / yakma patlaması)
static func _fly_tag(who: Node3D, from: Vector3, to: Vector3, dur: float) -> void:
	var q = _mi(_quad(), _tag_m())
	q.scale = Vector3(0.16, 0.4, 1.0)
	q.global_position = from
	var spin = randf_range(6.0, 11.0)
	var tw = q.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(q):
			q.global_position = from.lerp(to, x) + Vector3.UP * sin(x * PI) * 1.4
			q.rotation = Vector3(x * spin, x * spin * 0.6, 0.0) if x < 0.95 else Vector3(-PI * 0.5, 0, 0), 0.0, 1.0, dur)
	tw.tween_method(func(x: float): _fade_tree(q, x * 0.5), 0.0, 1.0, 0.35)   # yere yapışık bekler, kenarından tutuşur
	tw.tween_callback(func():
		if is_instance_valid(q):
			q.queue_free()
		if not is_instance_valid(who):
			return
		var pos = to + Vector3.UP * 0.3
		_flash(pos, 1.4, Color(1, 0.97, 0.8), Color(1.0, 0.55, 0.15), 0.14)
		_chunks(pos, 4, Color(0.3, 0.12, 0.05), 4.0, 0.5, 0.06)
		Combat.hit_sphere(who, pos, 1.6, {"dmg": 0.0, "knock": 7.0, "launch": 2.0, "kind": "heavy", "burn": 1.5, "hitstop": 0.03}))


# ================================================================== SHISUI
## Zanzō Bunshin (残像分身, anime 454; kaynak: tantōsunu yatay tutan art görüntüler, havada süzülen camgöbeği chakra
## kabarcıkları): Shunshin'le hedefin çevresinde beş art görüntü bırakır; her biri koyu yeşil-camgöbeği silüet olarak kalır,
## çevresinde kabarcıklar süzülür ve kendi yerinden ince tantō kesiği atar. Sonunda gerçek beden hedefin arkasında belirir.
static func zanzo_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 26.0)
	var center: Vector3 = tg.global_position if tg else Jutsu._ground(c.global_position + c.face_dir() * 8.0)
	var base = atan2(c.global_position.x - center.x, c.global_position.z - center.z)
	pj.busy(c, 1.25)
	MsArts._flicker_guard(c, 1.35)
	Sfx.play("whoosh", c.global_position, 1.8)
	var wr = weakref(tg) if tg else null
	var body = Color(0.08, 0.22, 0.2)
	var rim = Color(0.55, 1.0, 0.85)
	for k in 5:
		MsArts._later(0.06 + k * 0.22, func():
			if not MsArts._alive(c):
				return
			var tgt = wr.get_ref() if wr else null
			var ctr: Vector3 = tgt.global_position if tgt != null and not tgt.is_dead() else center
			var a = base + (k + 1) * TAU * 2.0 / 5.0   # yıldız sırası: karşıdan karşıya sıçrar
			var at = Jutsu._ground(ctr + Vector3(sin(a), 0, cos(a)) * 2.4)
			var p_old = c.global_position
			_echo(c, body, rim, 0.25, 0.25)
			MsArts._blink(c, at + Vector3.UP * 0.05)
			_streak(p_old + Vector3.UP * 1.0, at + Vector3.UP * 1.0, 0.1, 0.18, Color(0.9, 1.0, 0.97), SHISUI)
			var d = MsArts._turn(c, ctr)
			MsArts._anim(c, "slash_a" if k % 2 == 0 else "slash_b", 2.2)
			_echo(c, body, rim, 0.55, 0.45, 0.65, 3.0)   # burada kalan art görüntü
			_motes(at + Vector3.UP * 1.0, 5, Color(0.9, 1.0, 0.98), BUBBLE, 0.9, 0.7, 1.1, 0.26, Color(0.1, 0.35, 0.35), 0.7)
			_slash(at + Vector3.UP * 1.15 + d * 0.5, d, 1.5, (0.6 if k % 2 == 0 else -0.6) + k * 0.25, 0.22, Color(1, 1, 1), Color(0.75, 1.0, 0.92), Color(0.08, 0.3, 0.25), 0.1, 2.0, 0.1, 0.9)
			Sfx.play("slash", at, 1.3 + k * 0.05, 0.7)
			Combat.hit_sphere(c, ctr + Vector3.UP, 2.2, MsArts._inf(c, "zanzo_bunshin", 0.2, {"knock": 1.5, "kind": "light", "blade": true, "hitstop": 0.03, "dir": d})))
	MsArts._later(0.06 + 5 * 0.22, func():
		if not MsArts._alive(c):
			return
		var tgt = wr.get_ref() if wr else null
		var ctr: Vector3 = tgt.global_position if tgt != null and not tgt.is_dead() else center
		var back = Jutsu._ground(ctr - Vector3(sin(base), 0, cos(base)) * 2.0)
		_echo(c, body, rim, 0.3, 0.5)
		MsArts._blink(c, back + Vector3.UP * 0.05)
		MsArts._turn(c, ctr)
		_motes(ctr + Vector3.UP * 1.0, 10, Color(0.9, 1.0, 0.98), BUBBLE, 2.4, 1.0, 1.0, 0.22, Color(0.1, 0.35, 0.35), 0.65)
		_ring(back + Vector3.UP * 1.0, Vector3.UP, 0.3, 1.2, 0.25, Color(0.9, 1.0, 0.97), SHISUI, true, 0.18, 0.8))


## Bunshun (分瞬, Storm Revolution): iki kage bunshin keskin bir parlamayla belirir, hız çizgileriyle iki yandan hedefe atılıp
## çarpar (çarpma dalgası, yeşil chakra kırıntılarıyla dağılır); gerçek Shisui arkalarından geçer — gecikmeli tek iai çizgisi
static func bunshun(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 24.0)
	var aim = MsArts._aim_fn(c, tg, 10.0)
	var d = MsArts._turn(c, aim.call())
	var side = d.cross(Vector3.UP).normalized()
	pj.busy(c, 1.0)
	MsArts._anim(c, "cast", 1.6)
	Sfx.play("poof", c.global_position, 1.2)
	var look: Dictionary = c.model.look.duplicate() if c.get("model") and "look" in c.model else {}
	for sgn in [-1.0, 1.0]:
		var cl = ShadowClone.new()
		cl.team = c.team
		cl.look = look
		MsArts._scene().add_child(cl)
		var from = Jutsu._ground(c.global_position + side * sgn * 1.6)
		cl.global_position = from
		_pop(from + Vector3.UP, 0.8)
		cl.set_physics_process(false)
		cl.set_process(false)
		if cl.get("model") and cl.model:
			cl.model.play("run", 0.05, 1.8, true)
		var wcl = weakref(cl)
		MsArts._later(0.12, func():
			var n = wcl.get_ref()
			if n == null:
				return
			var to: Vector3 = aim.call() + side * sgn * 0.9
			to = Jutsu._ground(to)
			var dd = to - n.global_position
			dd.y = 0.0
			if dd.length() > 0.2:
				n.rotation.y = atan2(-dd.x, -dd.z)
			for j in 3:   # hız çizgileri
				var o = Vector3.UP * (0.5 + j * 0.45) + side * sgn * randf_range(-0.2, 0.2)
				_streak(n.global_position + o, to + o, 0.07, 0.3, Color(0.92, 1.0, 0.95), SHISUI, 0.7)
			var tw = n.create_tween()
			tw.tween_property(n, "global_position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				var m2 = wcl.get_ref()
				if m2 == null:
					return
				if MsArts._alive(c):
					Combat.hit_sphere(c, to + Vector3.UP, 1.9, MsArts._inf(c, "bunshun", 0.25, {"knock": 2.0, "kind": "heavy", "stun": 0.5, "hitstop": 0.04, "dir": d}))
				_flash(to + Vector3.UP * 1.1, 1.4, Color(1, 1, 1), Color(0.85, 1.0, 0.9), 0.12)
				_ring(to + Vector3.UP * 1.1, -side * sgn, 0.2, 1.5, 0.25, Color(1, 1, 1), SHISUI)
				Sfx.play("punch", to, 1.1)
				_pop(to + Vector3.UP, 0.9)
				m2.queue_free()))
	MsArts._later(0.5, func():
		if not MsArts._alive(c):
			return
		var to: Vector3 = aim.call()
		var stand = Jutsu._ground(to - d * 1.5)
		var p_old = c.global_position
		_echo(c, Color(0.06, 0.2, 0.12), Color(0.6, 1.0, 0.7), 0.35, 0.4)
		MsArts._blink(c, stand + Vector3.UP * 0.05)
		_streak(p_old + Vector3.UP, stand + Vector3.UP, 0.12, 0.2, Color(0.92, 1.0, 0.95), SHISUI)
		MsArts._anim(c, "slash_c", 2.0)
		Sfx.play("slash", stand, 1.0)
		Combat.hit_sphere(c, to, 2.4, MsArts._inf(c, "bunshun", 0.5, {"knock": 9.0, "kind": "heavy", "blade": true, "hitstop": 0.07, "dir": d}))
		_iai_line(to + Vector3.UP * 1.1, side, 2.6))


## Gölge klonun belirişi / dağılışı: keskin beyaz parlama, dışa fırlayan kısa çizgiler, yeşil chakra kırıntıları (duman yok)
static func _pop(at: Vector3, s: float) -> void:
	_flash(at, 1.3 * s, Color(1, 1, 1), Color(0.85, 1.0, 0.9), 0.12, 10)
	for k in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		_streak(at + dv * 0.3 * s, at + dv * 1.1 * s, 0.05, 0.16, Color(1, 1, 1), SHISUI, 0.8)
	_chunks(at, 6, SHISUI, 3.0, 0.5, 0.06, 0.4, Vector3.ZERO, true)


## İai çizgisi: geçişten bir an sonra hedefin üstünde beliren ince düz kesik; iki yarıya ayrılıp kayarak söner
static func _iai_line(at: Vector3, side: Vector3, half: float) -> void:
	MsArts._later(0.06, func():
		var m = _glow(Color(1, 1, 1), Color(0.75, 1.0, 0.85), Color(0.05, 0.25, 0.12), 1.0, 0.08, 0.0)
		var tilt = (side + Vector3.UP * 0.18).normalized()
		for sg in [1.0, -1.0]:
			var a = at
			var b = at + tilt * sg * half
			var mi = _mi(_xribbon([a, a.lerp(b, 0.5), b], [0.07, 0.05, 0.0]), m)
			var tw = mi.create_tween()
			tw.set_parallel(true)
			tw.tween_property(mi, "position", tilt * sg * 0.35 + Vector3.UP * 0.08 * sg, 0.3).set_delay(0.25)
			tw.tween_method(func(x: float): _fade_tree(mi, x), 0.0, 1.0, 0.3).set_delay(0.25)
			tw.chain().tween_callback(mi.queue_free)
		_flash(at, 1.2, Color(1, 1, 1), Color(0.75, 1.0, 0.85), 0.12, 6)
		_motes(at, 6, Color(1, 1, 1), SHISUI, 0.8, 0.4, 0.6, 0.1, Color(0.05, 0.25, 0.12), 0.9))


## Kotoamatsukami: Kōbō (別天神・光芒): hedefin tepesinde sahibinin Mangekyō'su aşağı bakar (çevresinde dönen altın halka,
## dökülen ışık zerreleri); gözden inen beş ışık hüzmesi — her biri yerde altın ışın yıldızı ve halka bırakır, sonuncusu en kalın
static func kotoamatsukami_kobo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tg = Jutsu._tg(c, t, 30.0)
	pj.busy(c, 0.9)
	MsArts._anim(c, "cast", 1.0)
	if tg == null:
		if c is Player:
			Hud.msg("Kotoamatsukami: hedef yok.", Color(0.8, 0.8, 0.8))
		return
	MsArts._turn(c, tg.global_position)
	var gm = Eyes.genjutsu_land(c, tg, true)
	if gm <= 0.0:
		return
	_flash(Jutsu._mouth(c) + Vector3.UP * 0.12, 1.0, Color(1, 0.85, 0.85), RED, 0.25)
	Sfx.play("genjutsu", tg.global_position, 0.8)
	tg.apply_status("stun", 2.4 * gm)
	var H = float(tg.get("height")) if tg.get("height") != null else 1.8
	var top = tg.global_position + Vector3.UP * (H + 9.0)
	# gökteki göz: sahibinin Mangekyō deseni, aşağı bakar
	var eye = _eye_disc(c, 9.0, false)
	MsArts._scene().add_child(eye)
	eye.global_position = top
	eye.rotation.x = PI * 0.5
	var em: ShaderMaterial = eye.material_override
	em.set_shader_parameter("fade", 0.0)
	eye.scale = Vector3.ONE * 0.2
	var et = eye.create_tween()
	et.set_parallel(true)
	et.tween_property(eye, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	et.tween_method(func(x: float): em.set_shader_parameter("fade", x), 0.0, 1.0, 0.25)
	var halo = _mi(_annulus(0.12, false), _glow(Color(1, 1, 1), GOLD, Color(0.45, 0.25, 0.05), 0.85, 0.3, 1.0))
	halo.global_position = top + Vector3.UP * 0.05
	halo.scale = Vector3.ONE * 5.4
	var ht = halo.create_tween()
	ht.tween_method(func(x: float) -> void:
		if is_instance_valid(halo):
			halo.rotation.y = x * TAU
	, 0.0, 1.0, 2.1)
	_dissolve(halo, 1.8, 0.3)
	if tg == Game.player and Game.world:
		Game.world.env.flash_tint(Color(0.85, 0.05, 0.05, 0.2), 1.6)
	var wr = weakref(tg)
	var inf = MsArts._inf(c, "kotoamatsukami_kobo", 0.2, {"knock": 0.5, "kind": "light", "hitstop": 0.02})
	for k in 5:
		MsArts._later(0.45 + k * 0.28, func():
			var n = wr.get_ref()
			if n == null or n.is_dead() or not is_instance_valid(eye):
				return
			var off = Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * (1.6 if k < 4 else 0.0)
			var hitp: Vector3 = n.global_position + off
			var src: Vector3 = eye.global_position + off * 1.4
			var wide = 0.4 if k < 4 else 1.1
			var beam = _mi(_beam_mesh(), _glow(Color(1, 1, 1), Color(1.0, 0.9, 0.6), Color(0.7, 0.35, 0.1), 0.95, 0.2, -3.0, 6.0))
			var place = func(w: float) -> void:
				if not is_instance_valid(beam):
					return
				var v = src - hitp
				var L = maxf(0.01, v.length())
				var y = v / L
				var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
				beam.global_transform = Transform3D(Basis(x * w, y * L, x.cross(y) * w), src)
			place.call(0.1)
			var bt = beam.create_tween()
			bt.tween_method(func(x: float): place.call(0.1 + x * wide * 2.0), 0.0, 1.0, 0.1)
			bt.tween_interval(0.12)
			bt.tween_method(func(x: float): place.call(0.1 + x * wide * 2.0), 1.0, 0.0, 0.14)
			bt.tween_callback(beam.queue_free)
			var g = Jutsu._ground(hitp)
			_decal(g, 2.5 * wide + 1.0, 1, Color(0.55, 0.3, 0.08), GOLD, 0.5, 7.0, 0.08)
			_ring(g + Vector3.UP * 0.12, Vector3.UP, 0.3, 2.5 * wide + 1.0, 0.3, Color(1, 1, 1), GOLD, false, 0.2, 0.85, Color(0.45, 0.25, 0.05))
			_flash(hitp + Vector3.UP, 2.0 * wide + 1.0, Color(1, 1, 1), Color(1.0, 0.88, 0.55), 0.15)
			_motes(hitp + Vector3.UP * 0.5, 4 + k, Color(1, 1, 1), GOLD, 0.8 + wide, 1.6, 0.6, 0.09, Color(0.45, 0.25, 0.05), 0.95)
			_light(hitp + Vector3.UP, GOLD, 4.0 + wide * 4.0, 8.0, 0.3)
			Sfx.play("chakra", hitp, 1.5, 0.6)
			if MsArts._alive(c):
				n.take_hit(inf.merged({"dir": Vector3.DOWN, "attacker": c}, true)))
	MsArts._later(2.1, func():
		if is_instance_valid(eye):
			var ft = eye.create_tween()
			ft.tween_method(func(x: float): em.set_shader_parameter("fade", x), 1.0, 0.0, 0.3)
			ft.tween_callback(eye.queue_free))


## Kotoamatsukami: Zankō (別天神・残光, Shinobi Striker): gözden kızıl parlama; yere yakın, ince kızıl bir ışık halkası 28 m'ye
## süpürür; tutulan her kurbanın gözüne kullanıcının gözünden kızıl bir iplik uzanır, başının üstünde Mangekyō soluk yanar
## (art ışıltı, etki sürdükçe). Hasar vermez.
static func kotoamatsukami_zanko(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	MsArts._anim(c, "cast", 1.0)
	var eyep = Jutsu._mouth(c) + Vector3.UP * 0.12
	_flash(eyep, 1.4, Color(1, 0.88, 0.88), RED, 0.3)
	_ring(Jutsu._ground(c.global_position) + Vector3.UP * 0.4, Vector3.UP, 0.6, 28.0, 0.6, Color(1.0, 0.85, 0.88), RED, false, 0.035, 0.7, Color(0.3, 0.0, 0.04))
	Sfx.play("genjutsu", c.global_position, 1.1)
	var n = 0
	for f in Jutsu.get_tree().get_nodes_in_group("fighters"):
		if not is_instance_valid(f) or f.is_dead() or not Combat.hostile(c, f):
			continue
		if f.global_position.distance_to(c.global_position) > 28.0:
			continue
		var gm = Eyes.genjutsu_land(c, f, false)
		if gm <= 0.0:
			continue
		n += 1
		var dur = (3.0 if f.has_meta("boss") or f is TailedBeast else 6.0) * gm
		if f == Game.player:
			f.apply_status("kokuangyo", dur * 0.6)
		else:
			if f.has_method("lose_target"):
				f.lose_target(dur)
			f.apply_status("slow", dur)
		var H = float(f.get("height")) if f.get("height") != null else 1.8
		# kızıl iplik: kullanıcının gözünden kurbanın gözüne
		var fe = f.global_position + Vector3.UP * (H * 0.9)
		var th = _mi(_xribbon([eyep, eyep.lerp(fe, 0.5) + Vector3.UP * 0.3, fe], [0.03, 0.045, 0.02]), _glow(Color(1.0, 0.85, 0.88), RED, Color(0.3, 0.0, 0.04), 0.9, 0.1, 2.0))
		_dissolve(th, 0.25, 0.3)
		# art ışıltı: kurbanın gözünün önünde sahibinin Mangekyō'su yanar, etki sürdükçe başının üstünde soluk durur
		var mark = _eye_disc(c, 0.7, true)
		f.add_child(mark)
		mark.position = Vector3.UP * (H * 0.9)
		var mm: ShaderMaterial = mark.material_override
		var mt = mark.create_tween()
		mt.tween_method(func(x: float):
			mm.set_shader_parameter("fade", minf(1.0, x * 3.0))
			mark.scale = Vector3.ONE * (2.2 - 1.6 * minf(1.0, x * 2.0))
			mark.position = Vector3.UP * (H * 0.9 + x * (H * 0.25 + 0.25)), 0.0, 1.0, 0.6)
		mt.tween_method(func(x: float): mm.set_shader_parameter("fade", x), 1.0, 0.45, 0.4)
		mt.tween_interval(maxf(0.1, dur - 1.4))
		mt.tween_method(func(x: float): mm.set_shader_parameter("fade", x), 0.45, 0.0, 0.4)
		mt.tween_callback(mark.queue_free)
		_flash(fe, 0.8, Color(1, 0.88, 0.88), RED, 0.2)
		Combat.popup_text(f.global_position + Vector3.UP * (H + 0.6), "Zankō", Color(1.0, 0.5, 0.5))
	if c is Player and n == 0:
		Hud.msg("Kotoamatsukami: Zankō — çevrede etkilenecek kimse yok.", Color(0.8, 0.8, 0.8))
