class_name FlowFX
extends RefCounted
## Akış grubu (15 teknik): su, kan, mürekkep, et, saç, duman, kara fırtına (Ranton), oyma tahta (Kanzeon), senjutsu kapısı.
## Ortak efekt yardımcısı yok: kendi akışkan shader'ı (su / kan / mürekkep / et / saç: düz cel tonlar, koyu kenar çizgisi,
## akan parlak çizgiler, gürültüyle eriyerek sönme), kendi ışıma, kara şimşek, oyma tahta, yer izi ve hava şeridi shader'ları;
## kendi tüp / şerit / halka / disk / yıldız geometrisi ve kendi ayarlı CPUParticles3D parçacıkları.

static var _cache := {}

# ================================================================== shader'lar
## Akışkan: üç tonlu cel gölge (sabit ışık yönü), akan parlak çizgiler, koyu dış çizgi, gürültülü erime (fade + köşe alfası)
const FLUID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 c_hi : source_color = vec3(0.93, 0.99, 1.0);
uniform vec3 c_mid : source_color = vec3(0.45, 0.78, 0.97);
uniform vec3 c_dark : source_color = vec3(0.17, 0.44, 0.74);
uniform vec3 c_line : source_color = vec3(0.05, 0.16, 0.36);
uniform float flow_speed = 2.5;
uniform float streak_freq = 6.0;
uniform float gloss = 1.0;
uniform float wob = 0.03;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 wn;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	float t = TIME * 3.0 + seed * 7.0;
	VERTEX += NORMAL * sin(UV.y * 9.0 - t + UV.x * 6.2832) * wob;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float dn = vn(vec2(UV.x * 7.0 + seed, UV.y * 4.0 - TIME * flow_speed * 0.5));
	if (dn * 0.98 > fade * COLOR.a) {
		discard;
	}
	vec3 lv = normalize(vec3(0.35, 0.85, 0.25));
	float ndl = dot(wn, lv);
	vec3 col = ndl > 0.3 ? c_mid : (ndl > -0.3 ? mix(c_mid, c_dark, 0.5) : c_dark);
	float sn = vn(vec2(UV.x * 2.5 + seed * 3.0, UV.y * streak_freq - TIME * flow_speed));
	col = mix(col, c_hi, step(1.0 - 0.2 * gloss, sn));
	float fres = 1.0 - abs(dot(NORMAL, VIEW));
	col = mix(col, c_line, step(0.8, fres));
	ALBEDO = col;
}
"""

## Işıma (toplamalı): kenara doğru sönen çekirdek, isteğe bağlı kare kare titreme
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 core : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 edge : source_color = vec3(1.0, 0.7, 0.3);
uniform float power = 1.5;
uniform float flick = 0.0;
uniform float boost = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float k = pow(f, power);
	float fl = 1.0 - flick * step(0.5, fract(sin(floor(TIME * 20.0) * 12.9898 + seed * 78.233) * 43758.5453));
	ALBEDO = mix(edge, core, k) * (0.25 + 0.75 * k) * boost * fade * COLOR.a * fl;
}
"""

## Kara fırtına (Ranton): kapkara gövde, üstünde kare kare yer değiştiren beyaz şimşek damarları + beyaz kenar
const STORM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 body : source_color = vec3(0.02, 0.02, 0.035);
uniform vec3 vein : source_color = vec3(0.96, 0.97, 1.0);
uniform float vein_scale = 2.4;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float stp = floor(TIME * 12.0 + seed);
	vec2 q = (lp.xy + lp.z * vec2(0.7, -0.5)) * vein_scale + vec2(stp * 0.37 + seed, stp * 0.61);
	float e = vor_edge(q);
	float v = 1.0 - smoothstep(0.03, 0.08, e);
	v *= step(0.35, h21(floor(q * 0.5) + vec2(stp)));
	float fres = 1.0 - abs(dot(NORMAL, VIEW));
	float rim = step(0.7, fres);
	float d = h21(floor(lp.xz * 9.0) + vec2(floor(lp.y * 9.0), seed));
	if (d > fade) {
		discard;
	}
	ALBEDO = mix(body, vein, max(v, rim));
}
"""

## Oyma tahta / boyalı ahşap (Kanzeon, torii, et kolu): köşe rengi, yıllık halka çizgileri, üç bantlı ışık, koyu kenar
const CARVE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 line_col : source_color = vec3(0.12, 0.08, 0.05);
uniform float grain = 1.0;
uniform float grain_freq = 18.0;
uniform float lum = 1.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 cell = floor(lp * 8.0);
	float d = fract(sin(dot(cell.xy + vec2(cell.z * 1.7, seed), vec2(12.9898, 78.233))) * 43758.5453);
	if (d > fade) {
		discard;
	}
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2)) * lum;
	float g = sin(lp.y * grain_freq + sin(lp.x * 3.1 + lp.z * 2.3) * 2.5);
	c *= 1.0 - grain * 0.22 * step(0.85, g);
	float fres = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	c = mix(c, line_col, step(0.8, fres));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
	EMISSION = c * 0.22;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.25 ? 1.0 : (ndl > -0.15 ? 0.55 : 0.28);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
"""

## Yer izi / düz boya (gölcük, çatlak, kurum, mürekkep lekesi, fırça darbesi, sıçrama yıldızı): köşe rengi, gürültülü erime
const DECAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

varying vec3 wp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vn(wp.xz * 2.5 + vec2(wp.y * 1.7 + seed));
	if (n > fade * COLOR.a) {
		discard;
	}
	ALBEDO = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
}
"""

## Hava şeridi (basınç / savuruş izi / duman şeridi): şerit ortasında yoğun, kenara sönen, akan kesik çizgiler
const AIR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float strength = 0.7;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float lines = 0.45 + 0.55 * step(0.45, vn(vec2(UV.x * 9.0 + seed, UV.y * 1.5 - TIME * 6.0)));
	ALBEDO = tint;
	ALPHA = clamp((1.0 - x * x) * lines * strength * fade * COLOR.a, 0.0, 1.0);
}
"""

# ================================================================== malzemeler
static func _shader(key: String, code: String) -> Shader:
	var k = "sh_" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code
		_cache[k] = s
	return _cache[k]


## Akışkan türleri: [parlak, orta, koyu, çizgi, akış hızı, çizgi sıklığı, parlaklık, dalgalanma]
static func _fluid_def(kind: String) -> Array:
	match kind:
		"edge":
			return [Color(1, 1, 1), Color(0.82, 0.95, 1.0), Color(0.55, 0.8, 0.98), Color(0.1, 0.3, 0.55), 4.0, 8.0, 1.2, 0.0]
		"vortex":
			return [Color(0.96, 1.0, 1.0), Color(0.62, 0.9, 1.0), Color(0.3, 0.62, 0.88), Color(0.12, 0.3, 0.55), 5.0, 10.0, 1.3, 0.05]
		"blood":   # koyu kızıl, ağır akan, ıslak parlak çizgi
			return [Color(0.78, 0.26, 0.28), Color(0.38, 0.02, 0.045), Color(0.19, 0.0, 0.022), Color(0.06, 0.0, 0.01), 0.5, 3.0, 0.8, 0.02]
		"rain":
			return [Color(1.0, 0.55, 0.55), Color(0.82, 0.08, 0.14), Color(0.5, 0.02, 0.06), Color(0.2, 0.0, 0.03), 3.0, 5.0, 0.8, 0.0]
		"ink":     # kara mürekkep, morumsu gri parlak çizgi
			return [Color(0.46, 0.44, 0.56), Color(0.07, 0.065, 0.09), Color(0.025, 0.022, 0.035), Color(0.0, 0.0, 0.0), 1.2, 4.0, 0.9, 0.025]
		"flesh":   # Jūgo'nun et uzantısı
			return [Color(0.9, 0.78, 0.68), Color(0.72, 0.58, 0.5), Color(0.5, 0.37, 0.32), Color(0.17, 0.1, 0.08), 1.6, 3.0, 0.4, 0.02]
	return [Color(0.93, 0.99, 1.0), Color(0.45, 0.78, 0.97), Color(0.17, 0.44, 0.74), Color(0.05, 0.16, 0.36), 2.6, 6.0, 1.0, 0.03]


static func _fluid(kind: String) -> ShaderMaterial:
	var k = "fl_" + kind
	if _cache.has(k):
		return _cache[k]
	var d = _fluid_def(kind)
	var m = ShaderMaterial.new()
	m.shader = _shader("fluid", FLUID_SHADER)
	m.set_shader_parameter("c_hi", d[0])
	m.set_shader_parameter("c_mid", d[1])
	m.set_shader_parameter("c_dark", d[2])
	m.set_shader_parameter("c_line", d[3])
	m.set_shader_parameter("flow_speed", d[4])
	m.set_shader_parameter("streak_freq", d[5])
	m.set_shader_parameter("gloss", d[6])
	m.set_shader_parameter("wob", d[7])
	_cache[k] = m
	return m


## Saç: kişinin kendi saç renginden cel tonlar (akmaz, dalgalanmaz)
static func _hair_mat(col: Color) -> ShaderMaterial:
	var k = "hair_" + col.to_html()
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader("fluid", FLUID_SHADER)
	m.set_shader_parameter("c_hi", col.lightened(0.35))
	m.set_shader_parameter("c_mid", col)
	m.set_shader_parameter("c_dark", col.darkened(0.3))
	m.set_shader_parameter("c_line", col.darkened(0.75))
	m.set_shader_parameter("flow_speed", 0.0)
	m.set_shader_parameter("streak_freq", 2.0)
	m.set_shader_parameter("gloss", 0.6)
	m.set_shader_parameter("wob", 0.0)
	_cache[k] = m
	return m


static func _glow(core: Color, edge: Color, power := 1.5, flick := 0.0, boost := 1.0) -> ShaderMaterial:
	var k = "gl_%s_%s_%.2f_%.2f_%.2f" % [core.to_html(), edge.to_html(), power, flick, boost]
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader("glow", GLOW_SHADER)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("flick", flick)
	m.set_shader_parameter("boost", boost)
	_cache[k] = m
	return m


static func _white_arc() -> ShaderMaterial:
	return _glow(Color(1, 1, 1), Color(0.72, 0.8, 1.0), 0.8, 0.4, 1.4)


static func _storm() -> ShaderMaterial:
	if not _cache.has("storm"):
		var m = ShaderMaterial.new()
		m.shader = _shader("storm", STORM_SHADER)
		_cache["storm"] = m
	return _cache["storm"]


static func _carve(lum := 1.0) -> ShaderMaterial:
	var k = "carve_%.2f" % lum
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _shader("carve", CARVE_SHADER)
		m.set_shader_parameter("lum", lum)
		_cache[k] = m
	return _cache[k]


static func _decal() -> ShaderMaterial:
	if not _cache.has("decal"):
		var m = ShaderMaterial.new()
		m.shader = _shader("decal", DECAL_SHADER)
		_cache["decal"] = m
	return _cache["decal"]


static func _air(tint := Color(1, 1, 1), strength := 0.7) -> ShaderMaterial:
	var k = "air_%s_%.2f" % [tint.to_html(), strength]
	if not _cache.has(k):
		var m = ShaderMaterial.new()
		m.shader = _shader("air", AIR_SHADER)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("strength", strength)
		_cache[k] = m
	return _cache[k]


## Parçacık kartı: "puff" yumuşak bulut, "cel" düz dolgulu koyu çizgili topak (duman / toz), "dot" sert damla, "glow" toplamalı ışık
static func _soft(kind: String) -> StandardMaterial3D:
	var k = "soft_" + kind
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g = Gradient.new()
	match kind:
		"cel":
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			g.offsets = PackedFloat32Array([0.0, 0.6, 0.8, 0.9])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.84, 0.84, 0.86, 1), Color(0.42, 0.42, 0.45, 1), Color(1, 1, 1, 0)])
		"dot":
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			g.offsets = PackedFloat32Array([0.0, 0.8])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"glow":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_:
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	_cache[k] = m
	return m


# ================================================================== geometri
static func _basis_y(y: Vector3) -> Basis:
	var yy = y.normalized()
	var ref = Vector3.UP if absf(yy.y) < 0.92 else Vector3.RIGHT
	var xx = ref.cross(yy).normalized()
	var zz = xx.cross(yy).normalized()
	return Basis(xx, yy, zz)


## Tüp: noktalar boyunca halkalar (paralel taşıma), u = çevre, v = uzunluk (metre); alfa köşe renginde (erime için)
static func _tube_mb(b: MB, pts: Array, rads, col := Color(1, 1, 1, 1), sides := 6, alphas = null) -> void:
	var n = pts.size()
	if n < 2:
		return
	var base = b.verts.size()
	var sd = Vector3.ZERO
	var L = 0.0
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tn.length_squared() < 0.000001:
			tn = Vector3.FORWARD
		tn = tn.normalized()
		var ref = Vector3.UP if absf(tn.y) < 0.92 else Vector3.RIGHT
		if sd == Vector3.ZERO:
			sd = ref.cross(tn)
		sd = sd - tn * sd.dot(tn)
		if sd.length_squared() < 0.000001:
			sd = ref.cross(tn)
		sd = sd.normalized()
		var up = tn.cross(sd)
		if i > 0:
			L += p.distance_to(pts[i - 1])
		var r = float(rads[i]) if rads is Array else float(rads)
		var a = float(alphas[i]) if alphas is Array else col.a
		var cc = Color(col.r, col.g, col.b, a)
		for j in sides + 1:
			var an = TAU * j / sides
			var nn = sd * cos(an) + up * sin(an)
			b.verts.append(p + nn * r)
			b.normals.append(nn)
			b.colors.append(cc)
			b.uvs.append(Vector2(float(j) / sides, L))
	for i in n - 1:
		for j in sides:
			var a0 = base + i * (sides + 1) + j
			var b0 = a0 + sides + 1
			b.idx.append_array(PackedInt32Array([a0, b0, b0 + 1, a0, b0 + 1, a0 + 1]))


static func _tube(pts: Array, rads, col := Color(1, 1, 1, 1), sides := 6, alphas = null) -> ArrayMesh:
	var b = MB.new()
	_tube_mb(b, pts, rads, col, sides, alphas)
	return b.build(null)


## Şerit: her noktada verilen yan yön (yarı genişlik) boyunca; u = enine 0..1, v = uzunluk
static func _ribbon_mb(b: MB, pts: Array, sides_v, widths, col := Color(1, 1, 1, 1), alphas = null) -> void:
	var n = pts.size()
	if n < 2:
		return
	var base = b.verts.size()
	var L = 0.0
	for i in n:
		var p: Vector3 = pts[i]
		var s: Vector3 = sides_v[i] if sides_v is Array else sides_v
		var w = float(widths[i]) if widths is Array else float(widths)
		var a = float(alphas[i]) if alphas is Array else col.a
		if i > 0:
			L += p.distance_to(pts[i - 1])
		var tn: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var nn = tn.cross(s).normalized() if tn.length_squared() > 0.000001 else Vector3.UP
		var cc = Color(col.r, col.g, col.b, a)
		b.verts.append(p - s * w)
		b.normals.append(nn)
		b.colors.append(cc)
		b.uvs.append(Vector2(0.0, L))
		b.verts.append(p + s * w)
		b.normals.append(nn)
		b.colors.append(cc)
		b.uvs.append(Vector2(1.0, L))
	for i in n - 1:
		var l0 = base + i * 2
		b.idx.append_array(PackedInt32Array([l0, l0 + 1, l0 + 3, l0, l0 + 3, l0 + 2]))


## Halka bant: iç çember (r_in, h_in) → dış çember (r_out, h_out); düz şok halkası ya da yukarı açılan su tacı
static func _band_mb(b: MB, r_in: float, r_out: float, h_in: float, h_out: float, seg: int, col: Color, a_in := 1.0, a_out := 1.0, center := Vector3.ZERO) -> void:
	var base = b.verts.size()
	for j in seg + 1:
		var an = TAU * j / seg
		var dv = Vector3(cos(an), 0, sin(an))
		b.verts.append(center + dv * r_in + Vector3.UP * h_in)
		b.normals.append(Vector3.UP)
		b.colors.append(Color(col.r, col.g, col.b, a_in))
		b.uvs.append(Vector2(0.0, float(j) / seg * 6.0))
		b.verts.append(center + dv * r_out + Vector3.UP * h_out)
		b.normals.append(Vector3.UP)
		b.colors.append(Color(col.r, col.g, col.b, a_out))
		b.uvs.append(Vector2(1.0, float(j) / seg * 6.0))
	for j in seg:
		var l0 = base + j * 2
		b.idx.append_array(PackedInt32Array([l0, l0 + 1, l0 + 3, l0, l0 + 3, l0 + 2]))


## Düzensiz kenarlı yer diski (gölcük, leke, kurum): ortası dolu, kenarı önce erir
static func _disc_mb(b: MB, r: float, seg: int, col: Color, a_c := 1.0, a_e := 0.55, jag := 0.3, center := Vector3.ZERO) -> void:
	var base = b.verts.size()
	b.verts.append(center)
	b.normals.append(Vector3.UP)
	b.colors.append(Color(col.r, col.g, col.b, a_c))
	b.uvs.append(Vector2(0.5, 0.5))
	var k0 = randf() * 10.0
	for j in seg + 1:
		var an = TAU * j / seg
		var rr = r * (1.0 - jag + jag * (0.5 + 0.5 * sin(an * 3.0 + k0) * cos(an * 5.0 + k0 * 1.3)))
		b.verts.append(center + Vector3(cos(an), 0, sin(an)) * rr)
		b.normals.append(Vector3.UP)
		b.colors.append(Color(col.r, col.g, col.b, a_e))
		b.uvs.append(Vector2(cos(an) * 0.5 + 0.5, sin(an) * 0.5 + 0.5))
	for j in seg:
		b.idx.append_array(PackedInt32Array([base, base + 1 + j, base + 2 + j]))


## Düz yıldız (anime su sıçraması): XY düzleminde dişli yelpaze; lens = her dişin boyu
static func _star_mb(b: MB, lens: Array, r_in: float, k: float, col: Color, z: float) -> void:
	var n = lens.size()
	var base = b.verts.size()
	b.verts.append(Vector3(0, 0, z))
	b.normals.append(Vector3.BACK)
	b.colors.append(col)
	b.uvs.append(Vector2(0.5, 0.5))
	for j in n * 2 + 1:
		var an = PI * j / n
		var rr = (float(lens[(j / 2) % n]) if j % 2 == 0 else r_in) * k
		b.verts.append(Vector3(cos(an) * rr, sin(an) * rr, z))
		b.normals.append(Vector3.BACK)
		b.colors.append(col)
		b.uvs.append(Vector2(cos(an) * 0.5 + 0.5, sin(an) * 0.5 + 0.5))
	for j in n * 2:
		b.idx.append_array(PackedInt32Array([base, base + 1 + j, base + 2 + j]))


static func _circle(c: Vector3, ru: Vector3, rv: Vector3, n: int) -> Array:
	var out = []
	for i in n + 1:
		var an = TAU * i / n
		out.append(c + ru * cos(an) + rv * sin(an))
	return out


## Kırık şimşek yolu (uçlar sabit, ortası saçılır)
static func _jag(a: Vector3, b: Vector3, segs: int, amp: float) -> Array:
	var pts = [a]
	var dv = b - a
	var s1 = dv.cross(Vector3.UP)
	if s1.length_squared() < 0.0001:
		s1 = dv.cross(Vector3.RIGHT)
	s1 = s1.normalized()
	var s2 = dv.cross(s1).normalized()
	for i in range(1, segs):
		var u = float(i) / segs
		var env = sin(u * PI)
		pts.append(a + dv * u + (s1 * randf_range(-1.0, 1.0) + s2 * randf_range(-1.0, 1.0)) * amp * env)
	pts.append(b)
	return pts


static func _chip_mesh(col: Color) -> ArrayMesh:
	var k = "chip_" + col.to_html()
	if not _cache.has(k):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(1.0, 0.6, 0.8), col, Vector3(12, 30, 8))
		_cache[k] = b.build(null)
	return _cache[k]


# ================================================================== sahne / yaşam süresi
static func _scene(pj: PathJutsu) -> Node:
	return pj.get_tree().current_scene


static func _root(pj: PathJutsu, pos: Vector3) -> Node3D:
	var r = Node3D.new()
	_scene(pj).add_child(r)
	r.global_position = pos
	return r


static func _geo(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if mat is ShaderMaterial:
		mi.set_meta("ffx", true)
		mi.set_instance_shader_parameter("seed", randf() * 40.0)
		mi.set_instance_shader_parameter("fade", 1.0)
	return mi


## Dünya koordinatlı geometri (düğüm başlangıçta): noktalar doğrudan dünya konumu
static func _wgeo(pj: PathJutsu, mesh: Mesh, mat: Material) -> MeshInstance3D:
	return _geo(_scene(pj), mesh, mat)


static func _set_fade(n: Node, v: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is GeometryInstance3D and n.has_meta("ffx"):
		n.set_instance_shader_parameter("fade", v)
	for ch in n.get_children():
		_set_fade(ch, v)


## delay sonra dur sürede eriyip silinir
static func _fade_free(n: Node, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): _set_fade(n, v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


static func _on_enter(n: Node, fn: Callable) -> void:
	if n.is_inside_tree():
		fn.call()
	else:
		n.tree_entered.connect(fn, CONNECT_ONE_SHOT)


static func _spin(n: Node3D, period: float, prop := "rotation:y") -> void:
	_on_enter(n, func():
		var tw = Game.safe_loops(n.create_tween())
		tw.tween_property(n, prop, TAU, period).as_relative())


## Kameraya dönük düzlem (yıldız sıçrama, fırça)
static func _face_cam(pj: PathJutsu, n: Node3D) -> void:
	var cam = pj.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(n.global_position) > 0.05:
		n.look_at(cam.global_position, Vector3.UP)


# ================================================================== parçacıklar (kendi ayarlı CPUParticles3D)
static func _parts(pj: PathJutsu, pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	var kind = String(o.get("kind", "puff"))
	var sz = float(o.get("size", 0.3))
	match kind:
		"drop", "blood", "ink", "rain", "flesh":
			var cm = CapsuleMesh.new()
			cm.radius = 0.5
			cm.height = 2.4
			cm.radial_segments = 6
			cm.rings = 2
			p.mesh = cm
			p.material_override = _fluid("water" if kind == "drop" else kind)
			p.particle_flag_align_y = true
		"spark":
			var bm = BoxMesh.new()
			bm.size = Vector3(0.25, 3.0, 0.25)
			p.mesh = bm
			p.material_override = o.get("mat", _white_arc())
			p.particle_flag_align_y = true
		"chip":
			p.mesh = o.get("mesh", _chip_mesh(Color(0.5, 0.42, 0.34)))
			p.material_override = o.get("mat", _carve())
		_:
			p.mesh = QuadMesh.new()
			p.material_override = _soft(kind)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, int(o.get("amount", 12)))
	var life = float(o.get("life", 0.8))
	p.lifetime = life
	var loop = bool(o.get("loop", false))
	p.one_shot = not loop
	p.explosiveness = 0.0 if loop else float(o.get("burst", 0.92))
	p.randomness = 0.5
	p.lifetime_randomness = 0.35
	p.local_coords = false
	var box: Vector3 = o.get("box", Vector3.ZERO)
	if box != Vector3.ZERO:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = box
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(o.get("radius", 0.15))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 45.0))
	p.flatness = float(o.get("flat", 0.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("gravity", Vector3(0, -9.8, 0))
	var damp = float(o.get("damp", 0.0))
	p.damping_min = damp
	p.damping_max = damp
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.tangential_accel_min = float(o.get("tangent", 0.0))
	p.tangential_accel_max = float(o.get("tangent", 0.0))
	p.angle_min = 0.0
	p.angle_max = 360.0
	var grow = float(o.get("grow", 0.2))
	var cv = Curve.new()
	if grow >= 1.0:
		p.scale_amount_min = sz * grow * 0.7
		p.scale_amount_max = sz * grow * 1.3
		cv.add_point(Vector2(0.0, 1.0 / grow))
		cv.add_point(Vector2(1.0, 1.0))
	else:
		var g0 = maxf(grow, 0.0)
		p.scale_amount_min = sz * 0.7
		p.scale_amount_max = sz * 1.3
		cv.add_point(Vector2(0.0, 1.0))
		cv.add_point(Vector2(0.7, g0 + (1.0 - g0) * 0.5))
		cv.add_point(Vector2(1.0, g0))
	p.scale_amount_curve = cv
	var cols: Array = o.get("colors", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var offs = PackedFloat32Array()
	var pc = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		pc.append(cols[i])
	var g = Gradient.new()
	g.offsets = offs
	g.colors = pc
	p.color_ramp = g
	_scene(pj).add_child(p)
	p.global_position = pos
	p.emitting = true
	if not loop:
		pj.free_after(life * 1.5 + 0.4, p)
	return p


## Sürekli yayıcıyı delay sonra kapatıp son parçacıklar sönünce siler
static func _stop_emit(p: CPUParticles3D, delay: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	_on_enter(p, func():
		var tw = p.create_tween()
		tw.tween_interval(maxf(delay, 0.01))
		tw.tween_callback(func(): p.emitting = false)
		tw.tween_interval(p.lifetime * 1.5 + 0.3)
		tw.tween_callback(p.queue_free))


# ================================================================== ortak yer izleri (yalnız bu dosyanın)
static func _puddle(pj: PathJutsu, pos: Vector3, r: float, col: Color, linger: float, grow := 0.25) -> MeshInstance3D:
	var b = MB.new()
	_disc_mb(b, r, 22, col, 1.0, 0.55, 0.3)
	var mi = _wgeo(pj, b.build(null), _decal())
	mi.global_position = pj.gp(pos) + Vector3.UP * 0.035
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, grow).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade_free(mi, linger, 0.9)
	return mi


## Yer çatlağı: merkezden dallanan kırık çizgiler, hızla yayılır, sonra erir
static func _cracks(pj: PathJutsu, pos: Vector3, R: float, n := 7, linger := 3.0) -> void:
	var b = MB.new()
	var col = Color(0.13, 0.1, 0.08)
	var wk = clampf(R / 3.0, 0.5, 2.5)
	for k in n:
		var a = TAU * k / n + randf_range(-0.3, 0.3)
		var L = R * randf_range(0.55, 1.0)
		var dir = Vector3(cos(a), 0, sin(a))
		var p = dir * R * 0.08
		var pts = []
		var sv = []
		var ws = []
		for s in 6:
			pts.append(p)
			sv.append(dir.cross(Vector3.UP).normalized())
			ws.append(lerpf(0.06, 0.008, s / 5.0) * wk)
			dir = dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))
			p += dir * L / 5.0
		_ribbon_mb(b, pts, sv, ws, col)
		if randf() < 0.6:   # yan dal
			var bd = (pts[3] - pts[2]).normalized().rotated(Vector3.UP, randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0))
			var bp = []
			var bs = []
			for s in 3:
				bp.append(pts[2] + bd * L * 0.14 * s)
				bs.append(bd.cross(Vector3.UP).normalized())
			_ribbon_mb(b, bp, bs, [0.03 * wk, 0.018 * wk, 0.004 * wk], col)
	var mi = _wgeo(pj, b.build(null), _decal())
	mi.global_position = pj.gp(pos) + Vector3.UP * 0.045
	mi.scale = Vector3(0.3, 1, 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_free(mi, linger, 0.8)


## Toz: düz dolgulu koyu çizgili topaklar yere yakın dışa savrulur + taş kırıkları
static func _dust(pj: PathJutsu, pos: Vector3, s: float, col := Color(0.62, 0.55, 0.45), chips := true) -> void:
	var g = pj.gp(pos)
	_parts(pj, g + Vector3.UP * 0.3, {"kind": "cel", "amount": int(10 * s) + 4, "life": 1.1, "size": 0.8 * s, "grow": 1.8, "radius": 0.4 * s,
		"dir": Vector3.UP, "spread": 85.0, "flat": 0.5, "vmin": 1.5 * s, "vmax": 4.0 * s, "damp": 3.0, "gravity": Vector3(0, 0.4, 0),
		"colors": [Color(col.r, col.g, col.b, 1.0), Color(col.r, col.g, col.b, 0.9), Color(col.r, col.g, col.b, 0.0)]})
	if chips:
		_parts(pj, g + Vector3.UP * 0.2, {"kind": "chip", "mesh": _chip_mesh(col.darkened(0.25)), "amount": int(6 * s) + 3, "life": 0.9, "size": 0.12 * s,
			"grow": 0.9, "dir": Vector3.UP, "spread": 40.0, "vmin": 3.0 * s, "vmax": 7.0 * s, "gravity": Vector3(0, -16, 0)})


## Genişleyen halka (şok dalgası / dalga / damla halkası)
static func _ring_wave(pj: PathJutsu, pos: Vector3, r0: float, r1: float, dur: float, mat: Material, col := Color(1, 1, 1, 1), width := 0.18, h := 0.0) -> MeshInstance3D:
	var b = MB.new()
	_band_mb(b, 1.0 - width, 1.0, 0.0, h, 40, col, 1.0, 0.7)
	var mi = _wgeo(pj, b.build(null), mat)
	mi.global_position = pos
	mi.scale = Vector3(r0, 1.0, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 1.0, r1), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_free(mi, dur * 0.35, dur * 0.65)
	return mi


## Anime su sıçraması: dişli düz yıldız (koyu çizgi + açık dolgu), kameraya döner, patlar ve erir
static func _star_splash(pj: PathJutsu, pos: Vector3, size: float, fill := Color(0.86, 0.96, 1.0), line := Color(0.12, 0.3, 0.52), life := 0.22) -> void:
	var lens = []
	for j in 11:
		lens.append(randf_range(0.55, 1.0))
	var b = MB.new()
	_star_mb(b, lens, 0.42, 1.0, line, 0.0)
	_star_mb(b, lens, 0.34, 0.82, fill, 0.015)
	var root = _root(pj, pos)
	_geo(root, b.build(null), _decal())
	_face_cam(pj, root)
	root.rotate_object_local(Vector3.BACK, randf() * TAU)
	root.scale = Vector3.ONE * size * 0.3
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * size, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_free(root, life * 0.4, life * 0.6)


static func _drops(pj: PathJutsu, pos: Vector3, kind: String, n: int, vmin: float, vmax: float, dir := Vector3.UP, spread := 180.0, size := 0.07, life := 0.8) -> void:
	_parts(pj, pos, {"kind": kind, "amount": n, "life": life, "size": size, "grow": 0.6, "radius": 0.15, "dir": dir, "spread": spread,
		"vmin": vmin, "vmax": vmax, "gravity": Vector3(0, -15, 0), "colors": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.2)]})


## Her karede yeniden kurulan tüp: fn(k) -> [noktalar, yarıçap(lar), alfalar ya da null]; boş dizi = gizle
static func _live_tube(pj: PathJutsu, mat: Material, dur: float, fn: Callable, sides := 5, out := 0.15) -> MeshInstance3D:
	var mi = _wgeo(pj, null, mat)
	var mw = weakref(mi)
	var upd = func(_i, k):
		var m = mw.get_ref()
		if m == null:
			return
		var r: Array = fn.call(k)
		if r.size() < 2:
			m.mesh = null
			return
		m.mesh = _tube(r[0], r[1], Color(1, 1, 1, 1), sides, r[2] if r.size() > 2 else null)
	var done = func():
		var m = mw.get_ref()
		if m != null:
			_fade_free(m, 0.0, out)
	pj.every(dur, 1.0 / 30.0, upd, done)
	pj.free_after(dur + out + 1.5, mi)
	return mi


static func _taper(n: int, head := 0.15, tail := 0.15) -> Array:
	var out = []
	for i in n:
		var u = float(i) / maxf(1.0, n - 1.0)
		out.append(clampf(minf(u / maxf(head, 0.001), (1.0 - u) / maxf(tail, 0.001)), 0.0, 1.0))
	return out


# ================================================================== 1) Suiton: Teppōkyū Kaiten — su kılıcıyla dönerek girdap olup dalar
static func _spin_spiral(pj: PathJutsu, g: Vector3, ph: float) -> void:
	for q in 2:
		var pts = []
		var rs = []
		for s in 12:
			var u = s / 11.0
			var an = ph + q * PI + u * 4.0
			pts.append(g + Vector3(cos(an), 0, sin(an)) * (1.0 + u * 0.6) + Vector3.UP * (0.15 + u * 1.5))
			rs.append(0.05 + 0.08 * sin(u * PI))
		var mi = _wgeo(pj, _tube(pts, rs, Color(1, 1, 1, 1), 5, _taper(12, 0.2, 0.35)), _fluid("water"))
		_fade_free(mi, 0.06, 0.18)


static func _spin_blade(pj: PathJutsu, g: Vector3, a0: float) -> void:
	var pts = []
	var sv = []
	var ws = []
	for s in 12:
		var u = s / 11.0
		var an = a0 + u * 2.2
		var rd = Vector3(sin(an), 0, cos(an))
		pts.append(g + Vector3.UP * 1.1 + rd * 1.7)
		sv.append(rd)
		ws.append(0.02 + 0.13 * sin(u * PI) * u)
	var b = MB.new()
	_ribbon_mb(b, pts, sv, ws, Color(1, 1, 1, 1), _taper(12, 0.1, 0.4))
	_fade_free(_wgeo(pj, b.build(null), _fluid("edge")), 0.04, 0.14)


static func _water_crown(pj: PathJutsu, g: Vector3) -> void:
	var b = MB.new()
	_band_mb(b, 0.85, 1.25, 0.0, 1.3, 36, Color(1, 1, 1, 1), 1.0, 0.45)
	var crown = _wgeo(pj, b.build(null), _fluid("water"))
	crown.global_position = g + Vector3.UP * 0.05
	var tw = crown.create_tween()
	tw.tween_property(crown, "scale", Vector3(6.0, 0.45, 6.0), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_free(crown, 0.12, 0.3)
	var cp = []
	var cr = []
	for s in 7:
		var u = s / 6.0
		cp.append(Vector3(sin(u * 9.0) * 0.12, u * 3.6, cos(u * 7.0) * 0.12))
		cr.append(lerpf(0.65, 0.12, u))
	var col = _wgeo(pj, _tube(cp, cr, Color(1, 1, 1, 1), 10, _taper(7, 0.05, 0.4)), _fluid("water"))
	col.scale = Vector3(1, 0.15, 1)
	col.global_position = g
	var tw2 = col.create_tween()
	tw2.tween_property(col, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_free(col, 0.18, 0.35)
	_drops(pj, g + Vector3.UP * 0.6, "drop", 30, 6.0, 11.0, Vector3.UP, 60.0, 0.08, 1.2)
	_parts(pj, g + Vector3.UP * 0.8, {"kind": "puff", "amount": 10, "life": 1.2, "size": 1.0, "grow": 2.2, "radius": 1.2, "spread": 80.0,
		"vmin": 1.0, "vmax": 2.5, "damp": 1.5, "gravity": Vector3(0, 0.3, 0), "colors": [Color(0.9, 0.97, 1.0, 0.7), Color(0.85, 0.95, 1.0, 0.35), Color(1, 1, 1, 0)]})
	_puddle(pj, g, 3.5, Color(0.36, 0.6, 0.78), 3.0)


static func _gather_water(pj: PathJutsu, pos: Vector3, r: float, n: int) -> void:
	_parts(pj, pj.gp(pos) + Vector3.UP * 0.2, {"kind": "drop", "amount": n, "life": 0.45, "size": 0.05, "radius": r, "dir": Vector3.UP, "spread": 20.0,
		"vmin": 1.5, "vmax": 3.0, "radial": -12.0, "gravity": Vector3(0, -2, 0), "burst": 0.6, "colors": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]})


static func suiton_teppunokyu_kaiten(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var id = "suiton_teppunokyu_kaiten"
	var tt = pj.tg(c, t, 18.0)
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	pj.anim(c, "slash_c", 1.4)
	Sfx.play("water", c.global_position, 0.9)
	_gather_water(pj, c.global_position, 1.6, 18)   # hazırlık: yerden su toplanır
	var hitk = {}
	var ride = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var fd: Vector3 = d
		if x != null and pj.live(x):
			fd = x.global_position - cc.global_position
			fd.y = 0
			fd = fd.normalized() if fd.length() > 0.3 else d
		if cc is CharacterBody3D:
			cc.velocity = fd * 15.0 + Vector3.UP * (2.0 if i < 8 else 0.0)
		if cc.get("model"):
			cc.model.rotation.y += 0.75   # girdapla birlikte döner
		var g: Vector3 = cc.global_position
		_spin_spiral(pj, g, i * 0.75)
		if i % 2 == 0:   # dönen kılıç ağzı
			var a0 = cc.model.rotation.y if cc.get("model") else 0.0
			_spin_blade(pj, g, a0)
		if i % 3 == 1:   # savrulan damlalar
			var an = i * 0.75
			_drops(pj, g + Vector3.UP * 1.0, "drop", 5, 5.0, 8.0, Vector3(cos(an), 0.3, sin(an)), 35.0, 0.06, 0.6)
		if i % 5 == 0:   # geçtiği yerde ıslak iz
			_puddle(pj, g, 0.9, Color(0.4, 0.62, 0.78), 1.6)
		if i % 3 == 2:
			for e in pj.enemies_near(cc, g, 2.3):
				var key = e.get_instance_id()
				hitk[key] = int(hitk.get(key, 0)) + 1
				if int(hitk[key]) > 5:
					continue
				e.take_hit(pj.inf(cc, id, 0.36, {"knock": 1.0, "kind": "light", "element": "suiton", "bleed": 2.0, "hitstop": 0.02}))
				Sfx.play("slash", g, 1.2)
	var fin = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc.get("model"):
			cc.model.rotation.y = 0.0
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		var g: Vector3 = pj.gp(cc.global_position)
		_water_crown(pj, g)
		pj.hit(cc, g + Vector3.UP, 3.0, pj.inf(cc, id, 1.3, {"knock": 16.0, "launch": 4.0, "kind": "heavy", "element": "suiton", "hitstop": 0.08}))
		Sfx.play("water", g, 0.6)
	pj.every(1.1, 0.04, ride, fin)


# ================================================================== 2) Chigiri Kyūshū — kan sisi emilimi (ref: kızıl sis, gökte kızıl damarlar)
static func _blood_veins(pj: PathJutsu, from: Vector3, rr: float) -> void:
	var b = MB.new()
	for k in 3:
		var a = randf() * TAU
		var to = from + Vector3(cos(a) * rr * 0.75, randf_range(4.0, 7.0), sin(a) * rr * 0.75)
		var pts = _jag(from, to, 8, 0.9)
		_tube_mb(b, pts, 0.07, Color(1, 1, 1, 1), 4, _taper(pts.size(), 0.05, 0.5))
		for q in 2:   # dallar
			var s0: Vector3 = pts[3 + q * 2]
			var bt = s0 + (to - from).normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2)) * rr * 0.3 + Vector3.UP * randf_range(0.5, 2.0)
			var bp = _jag(s0, bt, 5, 0.5)
			_tube_mb(b, bp, 0.04, Color(1, 1, 1, 1), 4, _taper(bp.size(), 0.05, 0.6))
	var mi = _wgeo(pj, b.build(null), _glow(Color(1.0, 0.42, 0.45), Color(0.62, 0.02, 0.08), 0.7, 0.35, 1.6))
	_fade_free(mi, 0.25, 0.45)


static func _blood_thread(pj: PathJutsu, from: Vector3, cc: Node3D) -> void:
	var cw = weakref(cc)
	var last = {"to": cc.global_position + Vector3.UP * 1.2}
	var fn = func(k: float) -> Array:
		var c2 = cw.get_ref()
		if c2 != null and is_instance_valid(c2):
			last["to"] = c2.global_position + Vector3.UP * 1.2
		var to: Vector3 = last["to"]
		var u1 = clampf(k * 1.5, 0.0, 1.0)
		var u0 = clampf(k * 1.5 - 0.55, 0.0, 1.0)
		if u1 - u0 < 0.02:
			return []
		var pts = []
		for s in 10:
			var u = lerpf(u0, u1, s / 9.0)
			pts.append(from.lerp(to, u) + Vector3.UP * sin(u * PI) * 0.8)
		return [pts, 0.05, _taper(10, 0.2, 0.3)]
	_live_tube(pj, _fluid("blood"), 0.7, fn, 5)
	pj.after(0.45, func():
		var c2 = cw.get_ref()
		if c2 != null and is_instance_valid(c2):
			_parts(pj, c2.global_position + Vector3.UP * 1.1, {"kind": "glow", "amount": 8, "life": 0.4, "size": 0.12, "radius": 0.9, "vmin": 0.0, "vmax": 0.3,
				"radial": -14.0, "gravity": Vector3.ZERO, "colors": [Color(1.0, 0.25, 0.3, 0.0), Color(1.0, 0.2, 0.25, 1.0), Color(0.6, 0.0, 0.05, 0.0)]}))


static func chigiri_kyushu_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "chigiri_kyushu_no_jutsu"
	pj.anim(c, "slash_a", 1.2)
	# kan bedeli: avucunu kılıca sürer
	_drops(pj, pj.hand_pos(c, false), "blood", 10, 0.5, 1.6, Vector3.UP, 180.0, 0.05, 0.5)
	if "hp" in c:
		c.hp = maxf(1.0, c.hp - c.max_hp * 0.03)
	Sfx.play("th_steam", c.global_position, 0.7)
	var cen = pj.gp(c.global_position)
	var cw = weakref(c)
	var R := 12.0
	# sis: kızıl, kutu yayıcı (yarıçapla genişler) + ince kan zerreleri; yerde koyu kızıl çiy
	var fog = _parts(pj, cen + Vector3.UP * 1.4, {"kind": "puff", "loop": true, "amount": 70, "life": 2.4, "size": 3.0, "grow": 1.5, "box": Vector3(R * 0.25, 1.0, R * 0.25),
		"dir": Vector3.UP, "spread": 180.0, "vmin": 0.2, "vmax": 0.7, "damp": 0.4, "gravity": Vector3(0, 0.15, 0), "tangent": 0.8,
		"colors": [Color(0.55, 0.05, 0.08, 0.0), Color(0.5, 0.04, 0.07, 0.42), Color(0.32, 0.02, 0.05, 0.3), Color(0.3, 0.02, 0.04, 0.0)]})
	var motes = _parts(pj, cen + Vector3.UP * 1.2, {"kind": "dot", "loop": true, "amount": 50, "life": 2.0, "size": 0.05, "box": Vector3(R * 0.25, 1.0, R * 0.25),
		"dir": Vector3.UP, "spread": 60.0, "vmin": 0.1, "vmax": 0.5, "gravity": Vector3(0, 0.1, 0),
		"colors": [Color(0.6, 0.03, 0.06, 0.0), Color(0.75, 0.08, 0.1, 0.9), Color(0.4, 0.0, 0.03, 0.0)]})
	var dew = _puddle(pj, cen, 1.0, Color(0.3, 0.03, 0.05), 7.6, 0.2)
	var fw = weakref(fog)
	var mw = weakref(motes)
	var dw = weakref(dew)
	var mist = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var rr = R * minf(1.0, 0.25 + k * 4.0)
		var f = fw.get_ref()
		if f != null:
			f.emission_box_extents = Vector3(rr * 0.8, 1.0, rr * 0.8)
		var m = mw.get_ref()
		if m != null:
			m.emission_box_extents = Vector3(rr * 0.8, 1.0, rr * 0.8)
		var dd = dw.get_ref()
		if dd != null:
			dd.scale = Vector3(rr * 0.9, 1.0, rr * 0.9)
		if i % 10 == 0:   # havaya kaldırılan kılıçtan gökyüzüne kızıl damarlar
			_blood_veins(pj, cc.global_position + Vector3.UP * 2.6, rr)
		if i % 5 != 4:
			return
		var got := 0
		for e in pj.enemies_near(cc, cen, rr):
			var wounded = false
			if e.has_meta("last_wound"):
				wounded = Time.get_ticks_msec() - int(e.get_meta("last_wound")) < 30000
			elif e is Player:
				wounded = e.hp < e.max_hp * 0.9
			if not wounded:
				continue
			got += 1
			e.take_hit(pj.inf(cc, id, 0.07, {"knock": 0.0, "launch": 0.0, "kind": "light", "chakra_drain": 7.0, "hitstop": 0.0, "pierce": true}))
			_blood_thread(pj, e.global_position + Vector3.UP * 1.1, cc)
		if got > 0:
			pj.chakra_gain(cc, 5.0 * got)
	var end = func():
		_stop_emit(fw.get_ref(), 0.0)
		_stop_emit(mw.get_ref(), 0.0)
	pj.every(8.0, 0.1, mist, end)


# ================================================================== 3) Chi no Kusari — kan zinciri
## Kan kaynağı: yaralı rakiplerin kanı, yoksa kendi bileğini keser (mekanik ana ağaçtaki kan kaynağı yardımcısıyla aynı)
static func _blood_src(pj: PathJutsu, c: Node3D, r: float) -> Array:
	var pts = []
	for e in pj.enemies_near(c, c.global_position, r):
		var wounded = (e.has_method("has_status") and e.has_status("bleed")) or (e.has_meta("last_wound") and Time.get_ticks_msec() - int(e.get_meta("last_wound")) < 20000)
		if wounded:
			pts.append(e.global_position + Vector3.UP * 1.0)
	if pts.is_empty():   # kendi kanı: bileğini keser
		if "hp" in c:
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.06)
		pts.append(pj.hand_pos(c, false))
		_drops(pj, pj.hand_pos(c, false), "blood", 8, 1.0, 2.5, Vector3.UP, 120.0, 0.05, 0.6)
	return pts


static func _blood_reach(pj: PathJutsu, p0: Vector3, tw: WeakRef, o: Vector3) -> void:
	var x0 = tw.get_ref()
	var last = {"to": (x0.global_position + Vector3.UP * 1.0) if x0 != null else p0}
	var fn = func(k: float) -> Array:
		var x = tw.get_ref()
		if x != null and is_instance_valid(x):
			last["to"] = x.global_position + Vector3.UP * 1.0
		var p1: Vector3 = last["to"]
		var u1 = clampf(k * 1.7, 0.0, 1.0)
		var u0 = clampf(k * 1.7 - 0.9, 0.0, 1.0)
		if u1 - u0 < 0.02:
			return []
		var pts = []
		for s in 12:
			var u = lerpf(u0, u1, s / 11.0)
			pts.append(p0.lerp(p1, u) + o * sin(u * PI))
		return [pts, 0.075, _taper(12, 0.08, 0.25)]
	_live_tube(pj, _fluid("blood"), 0.55, fn, 6)


static func _link_mb(b: MB, ctr: Vector3, ax: Vector3, ay: Vector3) -> void:
	var pts = []
	for i in 11:
		var an = TAU * i / 10.0
		pts.append(ctr + ax * cos(an) * 0.11 + ay * sin(an) * 0.065)
	_tube_mb(b, pts, 0.028, Color(1, 1, 1, 1), 5)


static func _blood_chain() -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	for r in 3:   # bedene çapraz dolanan üç sıra zincir, halkalar dönüşümlü dik / yatık
		for q in 12:
			var a = q * TAU / 12.0 + r * 0.6
			var pos = Vector3(cos(a) * 0.42, 0.45 + r * 0.38 + sin(a) * 0.12, sin(a) * 0.42)
			var tn = Vector3(-sin(a), cos(a) * 0.12 * 0.95, cos(a)).normalized()
			var rad = Vector3(cos(a), 0, sin(a))
			var other = rad if q % 2 == 0 else Vector3.UP
			other = (other - tn * other.dot(tn)).normalized()
			_link_mb(b, pos, tn, other)
	for k in 5:   # alt halkadan sarkan kan sapları
		var a = randf() * TAU
		var top = Vector3(cos(a) * 0.43, 0.42, sin(a) * 0.43)
		_tube_mb(b, [top, top + Vector3(0, -0.12, 0), top + Vector3(0, -0.26, 0)], [0.03, 0.022, 0.0], Color(1, 1, 1, 1), 5)
	_geo(root, b.build(null), _fluid("blood"))
	return root


static func _chain_break(pj: PathJutsu, pos: Vector3) -> void:
	var lb = MB.new()
	_link_mb(lb, Vector3.ZERO, Vector3.RIGHT * 2.0, Vector3.UP * 2.0)
	_parts(pj, pos, {"kind": "chip", "mesh": lb.build(null), "mat": _fluid("blood"), "amount": 14, "life": 0.9, "size": 1.0, "grow": 0.9,
		"radius": 0.4, "spread": 180.0, "vmin": 3.0, "vmax": 6.0, "gravity": Vector3(0, -14, 0)})
	_drops(pj, pos, "blood", 16, 2.0, 5.0, Vector3.UP, 180.0, 0.08, 0.9)
	_puddle(pj, pos, 1.3, Color(0.32, 0.02, 0.05), 3.0, 0.15)


static func chi_no_kusari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "chi_no_kusari"
	var tt = pj.tg(c, t, 18.0)
	pj._face(c, tt)
	pj.anim(c, "seal", 1.4)
	if tt == null:
		return
	var src = _blood_src(pj, c, 18.0)
	var cw = weakref(c)
	var tw = weakref(tt)
	for p in src:   # kan kaynağından hedefe kıvrılan ağır kan akıntıları
		var p0: Vector3 = p
		for q in 2:
			var o = Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 0.9), randf_range(-0.5, 0.5))
			_blood_reach(pj, p0, tw, o)
	pj.after(0.35, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var root = _blood_chain()   # bedene çapraz dolanan kan zinciri
		pj.attach(x, root, 2.2)
		var sc = root.scale
		root.scale = sc * 1.35
		var tq = root.create_tween()
		tq.tween_property(root, "scale", sc, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pj.st(x, "bind", 2.2)
		x.take_hit(pj.inf(cc, id, 0.9, {"knock": 0.0, "kind": "heavy", "bleed": 5.0, "hitstop": 0.06}))
		Sfx.play("bite", x.global_position, 0.6)
		_puddle(pj, x.global_position, 0.7, Color(0.3, 0.02, 0.045), 2.6, 1.6)   # zincirden damlayan kan gölü
		var drip = func(_i, _k):
			var x2 = tw.get_ref()
			if x2 != null and is_instance_valid(x2):
				_drops(pj, x2.global_position + Vector3.UP * randf_range(0.5, 1.3), "blood", 2, 0.6, 1.5, Vector3.DOWN, 30.0, 0.05, 0.6)
		var snap = func():
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 != null and x2 != null and pj.live(c2) and pj.live(x2):   # zincir sıkışıp kırılır
				_chain_break(pj, x2.global_position + Vector3.UP)
				x2.take_hit(pj.inf(c2, id, 0.8, {"knock": 3.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.06}))
		pj.every(2.2, 0.4, drip, snap))


# ================================================================== 4) Suiryū Hōsha — iki avuçtan ince basınçlı su ışını (ref: dişli sıçrama ağzı)
static func _jet(pj: PathJutsu, c: Node3D, right: bool, from: Vector3, dir: Vector3, speed: float, radius: float, info: Dictionary, homing: Node3D, life: float) -> void:
	var head = Node3D.new()
	var dm = CapsuleMesh.new()
	dm.radius = 0.11
	dm.height = 0.5
	var drop = _geo(head, dm, _fluid("water"))
	drop.rotation.x = PI * 0.5
	var pr = pj.shot(c, from, dir, speed, head, info, homing, false, life, func(p, _h):
		_star_splash(pj, p, 1.5)
		_drops(pj, p, "drop", 18, 3.0, 7.0, -dir, 70.0, 0.07, 0.8)
		_puddle(pj, p, 1.0, Color(0.4, 0.62, 0.8), 1.8))
	pr.radius = maxf(0.5, radius)
	var prw = weakref(pr)
	var cw = weakref(c)
	var stt = {"head": from, "tail": from, "t": 0.0}
	var rk = radius / 0.2
	_star_splash(pj, from, 0.75)
	var fn = func(k: float) -> Array:
		stt["t"] = k * (life + 0.3)
		var p = prw.get_ref()
		var alive = p != null and is_instance_valid(p)
		if alive:
			stt["head"] = p.global_position
		var cc = cw.get_ref()
		if alive and cc != null and pj.live(cc) and float(stt["t"]) < 0.4:
			stt["tail"] = pj.hand_pos(cc, right)
		else:
			stt["tail"] = (stt["tail"] as Vector3).lerp(stt["head"], 0.3)
		var a: Vector3 = stt["tail"]
		var b2: Vector3 = stt["head"]
		if a.distance_to(b2) < 0.15:
			return []
		var sd = (b2 - a).cross(Vector3.UP).normalized()
		var pts = []
		var rs = []
		for s in 10:
			var u = s / 9.0
			pts.append(a.lerp(b2, u) + sd * sin(u * 11.0 + k * 40.0) * 0.025 * sin(u * PI))
			rs.append(lerpf(0.09, 0.13, u) * rk)
		return [pts, rs, _taper(10, 0.04, 0.12)]
	_live_tube(pj, _fluid("water"), life + 0.3, fn, 7)
	for q in 3:   # ağızda dişli sıçrama tekrar tekrar patlar
		pj.after(0.08 + q * 0.09, func():
			var cc = cw.get_ref()
			if cc != null and pj.live(cc):
				_star_splash(pj, pj.hand_pos(cc, right) + dir * 0.25, randf_range(0.55, 0.8)))


static func suiryu_hosha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.9)
	for right in [true, false]:   # hazırlık: avuçlarda su toplanır
		_parts(pj, pj.hand_pos(c, right), {"kind": "drop", "amount": 8, "life": 0.3, "size": 0.035, "radius": 0.6, "spread": 180.0, "vmin": 0.2, "vmax": 0.6,
			"radial": -16.0, "gravity": Vector3.ZERO, "burst": 0.5, "colors": [Color(1, 1, 1, 1), Color(1, 1, 1, 0.6)]})
	pj.after(0.3, func():
		for right in [true, false]:
			if pj.live(c):
				var o = pj.hand_pos(c, right)
				_jet(pj, c, right, o, pj.aim_at(c, tt, o), 44.0, 0.2, pj.inf(c, "suiryu_hosha", 0.9, {"knock": 5.0, "kind": "heavy", "element": "suiton", "bleed": 2.0}), tt, 0.9))
	Sfx.play("water", c.global_position, 1.4)


# ================================================================== 5) Gūfū Suika — su akıntısını yutan girdap, buhar hortumu (ref: tepesi geniş parlak hortum, tabanında halkalar)
static func _water_orb(s: float) -> Node3D:
	var root = Node3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.32 * s
	sm.height = 0.64 * s
	sm.radial_segments = 20
	sm.rings = 10
	_geo(root, sm, _fluid("vortex"))
	var rings = Node3D.new()
	root.add_child(rings)
	var b = MB.new()
	for k in 3:
		var tilt = Basis(Vector3.RIGHT, 0.5 + k * 0.9) * Basis(Vector3.UP, k * 1.1)
		var pts = _circle(Vector3.ZERO, tilt * Vector3.RIGHT * 0.5 * s, tilt * Vector3.BACK * 0.5 * s, 20)
		_tube_mb(b, pts, 0.035 * s, Color(1, 1, 1, 1), 4, _taper(pts.size(), 0.0, 0.6))
	_geo(rings, b.build(null), _fluid("edge"))
	_spin(rings, 0.22)
	return root


static func _vortex(pj: PathJutsu, at: Vector3, dur: float) -> void:
	var root = _root(pj, at)
	var H = 6.5
	for layer in 2:   # iki kat, ters yönde dönen sarmal su şeritleri (tepesi geniş)
		var node = Node3D.new()
		root.add_child(node)
		var b = MB.new()
		var nr = 7 if layer == 0 else 5
		for k in nr:
			var pts = []
			var sv = []
			var ws = []
			for s in 16:
				var u = s / 15.0
				var h = u * H
				var rr = (0.5 + pow(u, 1.7) * 4.2) * (1.0 if layer == 0 else 0.7)
				var an = k * TAU / nr + u * (5.0 if layer == 0 else -4.0)
				var rd = Vector3(cos(an), 0, sin(an))
				pts.append(rd * rr + Vector3.UP * h)
				sv.append((Vector3.UP * 0.8 + rd.cross(Vector3.UP) * 0.3).normalized())
				ws.append(lerpf(0.25, 0.7, u))
			_ribbon_mb(b, pts, sv, ws, Color(1, 1, 1, 1), _taper(16, 0.06, 0.2))
		_geo(node, b.build(null), _fluid("vortex"))
		_spin(node, 0.9 if layer == 0 else -1.3)
	var base = Node3D.new()   # tabanda dönen halkalar
	root.add_child(base)
	var rb = MB.new()
	for k in 3:
		var pts = []
		var rr = 1.6 + k * 1.0
		for s in 25:
			var an = s / 24.0 * TAU * 0.75 + k * 2.0
			pts.append(Vector3(cos(an) * rr, 0.15 + k * 0.08, sin(an) * rr))
		_tube_mb(rb, pts, 0.05, Color(1, 1, 1, 1), 4, _taper(25, 0.2, 0.3))
	_geo(base, rb.build(null), _fluid("edge"))
	_spin(base, 0.7)
	root.scale = Vector3(0.3, 0.05, 0.3)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - 0.9, 0.1))
	tw.tween_property(root, "scale", Vector3(1.4, 0.05, 1.4), 0.55).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): _set_fade(root, v), 1.0, 0.0, 0.55)
	tw.tween_callback(root.queue_free)
	var mist = _parts(pj, at + Vector3.UP * 2.0, {"kind": "puff", "loop": true, "amount": 46, "life": 1.8, "size": 2.4, "grow": 1.6, "box": Vector3(4.5, 1.8, 4.5),
		"spread": 180.0, "vmin": 0.5, "vmax": 1.6, "gravity": Vector3(0, 0.8, 0), "tangent": 6.0, "damp": 0.6,
		"colors": [Color(0.95, 0.97, 1.0, 0.0), Color(0.93, 0.96, 1.0, 0.55), Color(0.88, 0.92, 0.96, 0.35), Color(0.85, 0.88, 0.92, 0.0)]})
	_stop_emit(mist, dur - 0.4)
	_puddle(pj, at, 4.2, Color(0.38, 0.6, 0.76), dur + 2.0, 0.4)


static func gufu_suika_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 1.0)
	pj.anim(c, "push", 1.1)
	var at = pj.gp(tt.global_position if tt else c.global_position + c.face_dir() * 9.0)
	var from = pj.hand_pos(c, true)
	var core = _water_orb(1.4)
	var _pr = pj.shot(c, from, (at + Vector3.UP - from).normalized(), 22.0, core, pj.inf(c, "gufu_suika_no_jutsu", 0.3, {"knock": 3.0, "kind": "light"}), null, false, 1.2, Callable())
	var a0: Vector3 = c.global_position + Vector3.UP * 1.0 + c.face_dir() * 0.8
	var a1: Vector3 = at + Vector3.UP * 0.8
	var stream = func(k: float) -> Array:   # orbun peşinden giden kıvrık su akıntısı
		var u1 = clampf(k * 1.4, 0.0, 1.0)
		var u0 = clampf(k * 1.4 - 0.7, 0.0, 1.0)
		if u1 - u0 < 0.02:
			return []
		var pts = []
		var sd = (a1 - a0).cross(Vector3.UP).normalized()
		for s in 12:
			var u = lerpf(u0, u1, s / 11.0)
			pts.append(a0.lerp(a1, u) + sd * sin(u * 8.0 + k * 10.0) * 0.25 + Vector3.UP * sin(u * PI) * 0.4)
		return [pts, 0.18, _taper(12, 0.1, 0.25)]
	_live_tube(pj, _fluid("water"), 0.6, stream, 6)
	Sfx.play("water", c.global_position, 0.8)
	pj.after(0.5, func():
		Sfx.play("th_steam", at, 0.7)
		var dur = 6.0
		_vortex(pj, at, dur)
		var tick = func(_i, _k):
			for e in pj.enemies_near(c, at, 6.0):
				pj.st(e, "slow", 0.6)
				if randf() < 0.15:
					e.take_hit(pj.inf(c, "gufu_suika_no_jutsu", 0.08, {"knock": 2.0, "kind": "light", "element": "suiton"}))
		pj.every(dur, 0.3, tick, Callable()))


# ================================================================== 6) Kaatsu — dev avuçla basınç savuruşu (taijutsu: hız izi, basınç dalgası, toz, çatlak)
static func _sweep_arcs(pj: PathJutsu, o: Vector3, fd: Vector3, sd: Vector3) -> void:
	for q in 6:
		var h = 0.5 + q * 0.28
		var rr = 3.4 + q * 0.25
		var dl = 0.15 + q * 0.012
		var fn = func(k: float) -> Array:
			var u1 = clampf(k * 2.2, 0.0, 1.0)
			var pts = []
			for s in 14:
				var a = lerpf(-1.25, lerpf(-1.25, 1.25, u1), s / 13.0)
				pts.append(o + (fd * cos(a) + sd * sin(a)) * rr + Vector3.UP * (h - 1.3))
			return [pts, 0.07 + q * 0.01, _taper(14, 0.1, 0.5)]
		pj.after(dl, func(): _live_tube(pj, _air(Color(1, 1, 1), 0.55), 0.3, fn, 4, 0.2))


static func _pressure_impact(pj: PathJutsu, g: Vector3, fd: Vector3, sd: Vector3, hit_any: bool) -> void:
	_ring_wave(pj, g + Vector3.UP * 0.12, 0.6, 5.5, 0.35, _air(Color(1, 1, 1), 0.85), Color(1, 1, 1, 1), 0.22)
	var pts = []   # ileri itilen dikey basınç duvarı
	var sv = []
	for s in 9:
		var a = lerpf(-0.9, 0.9, s / 8.0)
		pts.append(fd * cos(a) * 1.5 + sd * sin(a) * 2.2 + Vector3.UP * 1.4)
		sv.append(Vector3.UP)
	var b = MB.new()
	_ribbon_mb(b, pts, sv, 1.3, Color(1, 1, 1, 1), _taper(9, 0.3, 0.3))
	var wall = _wgeo(pj, b.build(null), _air(Color(0.95, 0.95, 0.92), 0.5))
	wall.global_position = g
	var tw = wall.create_tween()
	tw.tween_property(wall, "global_position", g + fd * 4.0, 0.3).set_ease(Tween.EASE_OUT)
	_fade_free(wall, 0.08, 0.22)
	_dust(pj, g, 1.6 if hit_any else 1.2)
	_cracks(pj, g, 3.0, 6, 2.5)


static func kaatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	pj.busy(c, 1.0)
	var id = "kaatsu"
	var _d = pj._jump_at(c, tt, 0.0, 9.0 if tt and tt.global_position.distance_to(c.global_position) > 3.5 else 2.0)
	pj._aki_arm(c, true, [1.35, 1.6, 4.2], 0.26, 0.62, 0.35, false, true)   # açık dev avuç (gerçek kemik)
	var cw = weakref(c)
	Sfx.play("whoosh", c.global_position, 0.6)
	_parts(pj, pj.hand_pos(c, true), {"kind": "puff", "amount": 10, "life": 0.3, "size": 0.5, "radius": 1.6, "spread": 180.0, "vmin": 0.0, "vmax": 0.3,
		"radial": -20.0, "gravity": Vector3.ZERO, "burst": 0.7, "colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)]})   # hava avuca çekilir
	pj.after(0.3, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj.anim(cc, "hook", 1.5)
		var fd: Vector3 = cc.face_dir()
		var sd = fd.cross(Vector3.UP).normalized()
		var o = cc.global_position + Vector3.UP * 1.3
		_sweep_arcs(pj, o, fd, sd)   # savruluşun havada bıraktığı basınç izleri
		pj.after(0.22, func():
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var hits = Combat.hit_zone(c2, c2.global_position, fd, 5.6, 72.0, 3.4, pj.inf(c2, id, 2.9, {"knock": 24.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.1, "dir": (fd - sd * 0.7).normalized()}))
			_pressure_impact(pj, pj.gp(c2.global_position + fd * 3.0), fd, sd, not hits.is_empty())
			pj.shake(0.6 if hits else 0.3)
			Sfx.play("punch", c2.global_position, 0.55)))


# ================================================================== 7) Saihō Kyūin — et uzantısıyla hücre emme (ref: elden uzanan et sapı bedene yapışır)
static func _flesh_latch(pj: PathJutsu, c: Node3D, e: Node3D, dur: float) -> void:
	var cw = weakref(c)
	var ew = weakref(e)
	var last = {"a": pj.hand_pos(c, true), "b": e.global_position + Vector3.UP * 1.1}
	var fn = func(k: float) -> Array:
		var cc = cw.get_ref()
		var ee = ew.get_ref()
		if cc != null and is_instance_valid(cc):
			last["a"] = pj.hand_pos(cc, true)
		if ee != null and is_instance_valid(ee):
			last["b"] = ee.global_position + Vector3.UP * 1.1
		var a: Vector3 = last["a"]
		var b2: Vector3 = last["b"]
		var reach = clampf(k * 8.0, 0.0, 1.0) * clampf((1.0 - k) * 6.0, 0.0, 1.0)   # uzanır, sonunda ele geri çekilir
		if reach < 0.03:
			return []
		var end = a.lerp(b2, reach)
		var pts = []
		var rs = []
		for s in 14:
			var u = s / 13.0
			pts.append(a.lerp(end, u) + Vector3.DOWN * sin(u * PI) * 0.15)
			rs.append(0.05 + 0.045 * maxf(0.0, sin(u * 9.0 + k * 30.0)))   # ete doğru akan şişkinlikler
		return [pts, rs, null]
	_live_tube(pj, _fluid("flesh"), dur + 0.15, fn, 7)
	# hedefin bedenine yayılan kök gibi et damarları
	var root = Node3D.new()
	var b = MB.new()
	var ctr = Vector3(0, 1.1, 0)
	for k in 5:
		var a = k * TAU / 5.0 + randf() * 0.4
		var tip = ctr + Vector3(cos(a) * 0.32, sin(a) * 0.45, -0.25 + randf() * 0.1)
		var mid = ctr.lerp(tip, 0.5) + Vector3(0, 0, -0.08)
		_tube_mb(b, [ctr + Vector3(0, 0, -0.3), mid, tip], [0.045, 0.03, 0.008], Color(1, 1, 1, 1), 5)
	_geo(root, b.build(null), _fluid("flesh"))
	pj.attach(e, root, dur + 0.1)
	var dv = c.global_position - e.global_position
	if Vector2(dv.x, dv.z).length() > 0.05:
		root.global_rotation.y = atan2(-dv.x, -dv.z)
	_drops(pj, e.global_position + Vector3.UP * 1.1, "flesh", 8, 1.0, 3.0, (c.global_position - e.global_position).normalized(), 70.0, 0.05, 0.5)


static func _drain_bead(pj: PathJutsu, a: Vector3, b2: Vector3) -> void:
	var sm = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var bead = _wgeo(pj, sm, _glow(Color(1.0, 0.85, 0.7), Color(0.95, 0.5, 0.35), 1.2, 0.0, 1.3))
	bead.global_position = a
	var tw = bead.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(bead):
			bead.global_position = a.lerp(b2, u) + Vector3.UP * sin(u * PI) * 0.3, 0.0, 1.0, 0.24)
	tw.tween_callback(bead.queue_free)
	_parts(pj, b2, {"kind": "glow", "amount": 4, "life": 0.35, "size": 0.1, "radius": 0.6, "vmin": 0.0, "vmax": 0.2, "radial": -10.0,
		"gravity": Vector3.ZERO, "colors": [Color(1.0, 0.6, 0.45, 0.0), Color(1.0, 0.7, 0.55, 0.9), Color(1.0, 0.5, 0.4, 0.0)]})


static func saiho_kyuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.4)
	if tt:
		pj._jump_at(c, tt, 0.0, 6.0)
	_parts(pj, pj.hand_pos(c, true), {"kind": "dot", "amount": 6, "life": 0.3, "size": 0.06, "radius": 0.15, "vmin": 0.3, "vmax": 0.8,
		"gravity": Vector3.ZERO, "colors": [Color(0.9, 0.72, 0.62, 1.0), Color(0.8, 0.6, 0.52, 0.0)]})   # el kabarır
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var d = c.face_dir()
		var at = c.global_position + Vector3.UP * 1.1 + d * 1.0
		var vic = pj.hit(c, at, 1.4, pj.inf(c, "saiho_kyuin", 0.4, {"knock": 0.0, "kind": "heavy"}))
		for e in vic:
			pj.st(e, "bind", 1.2)
			var src = e
			_flesh_latch(pj, c, src, 1.0)
			var drain = func(_i, _k):
				if pj.live(c) and pj.live(src):
					var a = src.global_position + Vector3.UP * 1.1
					var b2 = c.global_position + Vector3.UP * 1.1
					_drain_bead(pj, a, b2)
					src.take_hit(pj.inf(c, "saiho_kyuin", 0.15, {"knock": 0.0, "kind": "light"}))
					pj.heal(c, c.max_hp * 0.025)
			pj.every(1.0, 0.12, drain))
	Sfx.play("absorb", c.global_position, 0.8)


# ================================================================== 8) Tarenpū Jirenpō — lanet mühürlü kol topu (ref: bulut gibi kabaran kol, çok namlu, parlak krem toplar, mavi kıvrım)
static func _cannon_arm() -> Node3D:
	var b = MB.new()
	var sk = Color(0.76, 0.7, 0.66)
	var dk = Color(0.16, 0.13, 0.12)
	b.add("cyl", Vector3(0, 0.2, 0), Vector3(0.24, 0.42, 0.24), sk, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 0.42, 0), Vector3(0.3, 0.22, 0.3), sk, Vector3.ZERO, 12)
	for k in 7:   # bulut gibi kabarık loblar, her birinin ucunda koyu namlu ağzı + kenar halkası
		var a = k * TAU / 7.0
		var dv = Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6).normalized()
		var pos = Vector3(0, 0.38, 0) + Vector3(cos(a), 0, sin(a)) * 0.1
		b.add("sphere", pos, Vector3(0.14, 0.16, 0.14), sk.darkened(0.05 * (k % 2)), Vector3.ZERO, 10)
		var bs = _basis_y(dv)
		b.add_xf("torus", Transform3D(bs * Basis.from_scale(Vector3(0.1, 0.25, 0.1)), pos + dv * 0.07), sk.darkened(0.15), 12)
		b.add_xf("cyl", Transform3D(bs * Basis.from_scale(Vector3(0.065, 0.02, 0.065)), pos + dv * 0.075), dk, 10)
	b.add_xf("cyl", Transform3D(Basis.from_scale(Vector3(0.08, 0.02, 0.08)), Vector3(0, 0.53, 0)), dk, 10)
	for k in 4:   # mühür lekeleri (koyu benekler)
		var a = k * 1.7
		b.add("sphere", Vector3(cos(a) * 0.12, 0.12 + k * 0.06, sin(a) * 0.12), Vector3(0.03, 0.05, 0.02), dk, Vector3.ZERO, 6)
	var root = Node3D.new()
	_geo(root, b.build(null), _carve())
	return root


static func _curse_ball() -> Node3D:
	var root = Node3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	_geo(root, sm, _glow(Color(1.0, 1.0, 0.95), Color(1.0, 0.9, 0.6), 1.0, 0.0, 1.5))
	var hm = SphereMesh.new()
	hm.radius = 0.55
	hm.height = 1.1
	_geo(root, hm, _glow(Color(1.0, 0.85, 0.55), Color(1.0, 0.55, 0.2), 3.0, 0.0, 0.6))
	var arc = Node3D.new()
	root.add_child(arc)
	var pts = []
	for s in 16:
		var u = s / 15.0
		var an = u * TAU * 1.3
		pts.append(Vector3(cos(an) * 0.42, sin(u * TAU) * 0.15, sin(an) * 0.42 + (u - 0.5) * 0.4))
	_geo(arc, _tube(pts, 0.03, Color(1, 1, 1, 1), 4, _taper(16, 0.2, 0.3)), _glow(Color(0.85, 0.93, 1.0), Color(0.3, 0.5, 1.0), 0.8, 0.3, 1.5))
	_spin(arc, 0.2, "rotation:z")
	return root


static func _curse_blast(pj: PathJutsu, pp: Vector3) -> void:
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	var ball = _wgeo(pj, sm, _glow(Color(1.0, 0.98, 0.88), Color(1.0, 0.7, 0.35), 1.4, 0.0, 1.4))
	ball.global_position = pp
	ball.scale = Vector3.ONE * 0.4
	var tw = ball.create_tween()
	tw.tween_property(ball, "scale", Vector3.ONE * 2.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_free(ball, 0.06, 0.22)
	_ring_wave(pj, pj.gp(pp) + Vector3.UP * 0.1, 0.5, 3.2, 0.28, _air(Color(1.0, 0.95, 0.8), 0.9), Color(1, 1, 1, 1), 0.25)
	_parts(pj, pp, {"kind": "spark", "amount": 14, "life": 0.4, "size": 0.12, "grow": 0.3, "spread": 180.0, "vmin": 5.0, "vmax": 10.0,
		"gravity": Vector3(0, -6, 0), "mat": _glow(Color(1.0, 0.97, 0.85), Color(1.0, 0.6, 0.25), 0.6, 0.0, 1.4)})
	_puddle(pj, pp, 0.9, Color(0.17, 0.13, 0.11), 2.2, 0.08)
	_dust(pj, pp, 0.7, Color(0.55, 0.5, 0.45), false)


static func tarenpu_jirenpo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 1.6)
	var arm = _cannon_arm()
	arm.scale = Vector3.ONE * 0.2
	var ba = pj.bone_attach(c, "RightLowerArm")   # kola bağlanır (mekanik: ana ağaçtaki kol bağlama yardımcısıyla aynı)
	if ba == null:
		arm.queue_free()
	else:
		ba.add_child(arm)
		pj.free_after(1.6, ba)
		var tg_ = arm.create_tween()
		tg_.tween_property(arm, "scale", Vector3.ONE * 1.0, 0.25).set_trans(Tween.TRANS_BACK)
	for k in 9:
		pj.after(0.35 + k * 0.12, func():
			if not pj.live(c):
				return
			var o = pj.hand_pos(c)
			var dir = pj.aim_at(c, tt, o).rotated(Vector3.UP, randf_range(-0.12, 0.12))
			var ball = _curse_ball()
			pj.shot(c, o, dir, 30.0, ball, pj.inf(c, "tarenpu_jirenpo", 0.35, {"knock": 5.0, "kind": "heavy"}), tt, false, 1.2, func(pp, _h):
				_curse_blast(pj, pp))
			var sm = SphereMesh.new()   # namlu ağzı parlaması
			sm.radius = 0.45
			sm.height = 0.9
			var fl = _wgeo(pj, sm, _glow(Color(1, 1, 0.92), Color(1.0, 0.75, 0.4), 1.0, 0.0, 1.2))
			fl.global_position = o
			_fade_free(fl, 0.02, 0.1)
			Sfx.play("boom", o, 1.5))


# ================================================================== 9) Senpō: Myōjinmon Futō — gökten düşen torii kapıları rakibi yere çakar
static func _torii(s: float) -> Node3D:
	var b = MB.new()
	var red = Color(0.82, 0.22, 0.12)
	var blk = Color(0.12, 0.1, 0.09)
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(sx * 2.0, 2.4, 0) * s, Vector3(0.42, 4.8, 0.42) * s, red, Vector3.ZERO, 12)
		b.add("cyl", Vector3(sx * 2.0, 0.18, 0) * s, Vector3(0.54, 0.36, 0.54) * s, blk, Vector3.ZERO, 12)   # kamaki
	b.add("box", Vector3(0, 3.85, 0) * s, Vector3(5.4, 0.28, 0.3) * s, red)   # nuki
	b.add("box", Vector3(0, 4.6, 0) * s, Vector3(5.8, 0.24, 0.42) * s, red)   # shimaki
	for k in 9:   # kasagi: uçları yukarı kıvrık kara üst kiriş
		var x = lerpf(-3.4, 3.4, k / 8.0)
		var y = 4.88 + pow(absf(x) / 3.4, 2.0) * 0.4
		var slope = rad_to_deg(atan(2.0 * x / (3.4 * 3.4) * 0.4))
		b.add("box", Vector3(x, y, 0) * s, Vector3(0.9, 0.3, 0.56) * s, blk, Vector3(0, 0, slope))
	b.add("box", Vector3(0, 4.22, 0) * s, Vector3(0.5, 0.7, 0.14) * s, blk)   # gakuzuka
	b.add("box", Vector3(0, 4.22, -0.08) * s, Vector3(0.36, 0.54, 0.02) * s, Color(0.86, 0.7, 0.3))
	b.add("box", Vector3(0, 4.22, 0.08) * s, Vector3(0.36, 0.54, 0.02) * s, Color(0.86, 0.7, 0.3))
	var root = Node3D.new()
	var mi = _geo(root, b.build(null), _carve())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


static func _gate_impact(pj: PathJutsu, at: Vector3, gate: Node3D) -> void:
	_cracks(pj, at, 2.4, 8, 4.4)
	_dust(pj, at, 1.2)
	var b = MB.new()   # senjutsu mührü: yerde turuncu halka
	_band_mb(b, 1.5, 1.8, 0.0, 0.0, 40, Color(0.98, 0.62, 0.15), 1.0, 1.0)
	_band_mb(b, 0.9, 1.0, 0.0, 0.0, 30, Color(0.98, 0.62, 0.15), 1.0, 1.0)
	var seal = _wgeo(pj, b.build(null), _decal())
	seal.global_position = pj.gp(at) + Vector3.UP * 0.05
	_fade_free(seal, 4.0, 0.4)
	if not is_instance_valid(gate):
		return
	var gb = MB.new()   # direklerde yukarı tırmanan doğa enerjisi çizgileri
	for sx in [-1.0, 1.0]:
		for q in 2:
			var p0 = Vector3(sx * 1.5 + q * 0.12 * sx, 0.1, 0.22 * (1.0 if q == 0 else -1.0))
			var pts = _jag(p0, p0 + Vector3(0, 3.4, 0), 9, 0.08)
			_tube_mb(gb, pts, 0.035, Color(1, 1, 1, 1), 4, _taper(pts.size(), 0.1, 0.3))
	var lines = _geo(gate, gb.build(null), _glow(Color(1.0, 0.92, 0.6), Color(1.0, 0.5, 0.1), 0.8, 0.3, 1.3))
	_fade_free(lines, 0.6, 0.6)
	var motes = _parts(pj, pj.gp(at) + Vector3.UP * 0.5, {"kind": "glow", "loop": true, "amount": 24, "life": 1.2, "size": 0.1, "radius": 1.6,
		"dir": Vector3.UP, "spread": 15.0, "vmin": 0.6, "vmax": 1.4, "gravity": Vector3.ZERO, "colors": [Color(1.0, 0.7, 0.2, 0.0), Color(1.0, 0.75, 0.3, 0.9), Color(1.0, 0.5, 0.1, 0.0)]})
	_stop_emit(motes, 4.0)


static func senpo_myojinmon_futo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.9)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var d = (at - c.global_position).normalized()
	var warn = MB.new()   # hazırlık: düşeceği yerde beliren ince turuncu çember
	_band_mb(warn, 1.6, 1.75, 0.0, 0.0, 40, Color(1.0, 0.6, 0.15), 1.0, 1.0)
	var wm = _wgeo(pj, warn.build(null), _decal())
	wm.global_position = at + Vector3.UP * 0.05
	_fade_free(wm, 0.2, 0.15)
	pj.after(0.3, func():
		var gate = _torii(0.75)
		pj.get_tree().current_scene.add_child(gate)
		gate.global_position = at + Vector3.UP * 12.0
		gate.rotation.y = atan2(d.x, d.z) + PI * 0.5
		var tw = gate.create_tween()
		tw.tween_property(gate, "global_position", at - Vector3.UP * 0.35, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			_gate_impact(pj, at, gate)
			pj.shake(0.4)
			for e in pj.enemies_near(c, at, 1.8):
				pj.st(e, "bind", 4.5)
				pj.st(e, "stun", 1.5)
				e.take_hit(pj.inf(c, "senpo_myojinmon_futo", 0.7, {"knock": 0.0, "kind": "heavy"})))
		tw.tween_interval(4.3)
		tw.tween_method(func(v: float): _set_fade(gate, v), 1.0, 0.0, 0.3)
		tw.parallel().tween_property(gate, "global_position", at - Vector3.UP * 1.5, 0.3)
		tw.tween_callback(gate.queue_free))
	Sfx.play("earth", at, 0.8)


# ================================================================== 10) Kanzeon Renge-Ō — dev çok kollu tahta Buda heykeli (ref: hale, ışın gibi açılan el sıraları, dua eden eller)
static func _hand_mb(b: MB, at: Vector3, dir: Vector3, s: float, col: Color) -> void:
	var y = dir.normalized()
	var ref = Vector3.BACK if absf(y.z) < 0.9 else Vector3.UP
	var x = ref.cross(y).normalized()
	var z = x.cross(y).normalized()
	b.add_xf("box", Transform3D(Basis(x * 0.5 * s, y * 0.55 * s, z * 0.16 * s), at + y * 0.25 * s), col)
	for f in 4:   # parmaklar
		var fx = lerpf(-0.18, 0.18, f / 3.0) * s
		var p0 = at + y * 0.5 * s + x * fx
		var p1 = p0 + (y * 0.4 + x * fx * 0.6) * s - z * 0.05 * s
		_tube_mb(b, [p0, p1], [0.06 * s, 0.045 * s], col, 4)
	_tube_mb(b, [at + y * 0.2 * s + x * 0.25 * s, at + y * 0.4 * s + x * 0.45 * s], [0.06 * s, 0.045 * s], col, 4)   # başparmak


static func _kz_data() -> Array:
	if _cache.has("kz"):
		return _cache["kz"]
	var W = Color(0.52, 0.41, 0.33)
	var D = Color(0.34, 0.26, 0.2)
	var b = MB.new()
	# uzun cüppe: yerde geniş etekten yukarı daralan sütun + dikey kıvrım çizgileri
	var ry = [0.0, 1.5, 3.5, 5.5, 6.6]
	var rr = [1.55, 1.12, 0.86, 0.8, 0.95]
	_tube_mb(b, [Vector3(0, -0.6, 0), Vector3(0, 0.0, 0), Vector3(0, 1.5, 0), Vector3(0, 3.5, 0), Vector3(0, 5.5, 0), Vector3(0, 6.6, 0)], [1.6, 1.55, 1.12, 0.86, 0.8, 0.95], W, 22)
	for k in 9:
		var a = lerpf(-1.2, 1.2, k / 8.0)
		var fp = []
		for i in 4:
			var yy = [0.05, 2.0, 3.8, 5.3][i]
			var r0 = 0.0
			for j in 4:
				if yy >= ry[j] and yy <= ry[j + 1]:
					r0 = lerpf(rr[j], rr[j + 1], (yy - ry[j]) / (ry[j + 1] - ry[j]))
			fp.append(Vector3(sin(a) * (r0 + 0.02), yy, -cos(a) * (r0 + 0.02)))
		_tube_mb(b, fp, 0.035, D, 4)
	_tube_mb(b, _circle(Vector3(0, 5.6, 0), Vector3(0.83, 0, 0), Vector3(0, 0, 0.83), 28), 0.07, D, 5)   # kuşak
	_tube_mb(b, [Vector3(0, 6.4, 0), Vector3(0, 7.3, 0), Vector3(0, 7.7, 0)], [1.0, 1.08, 0.45], W, 18)   # göğüs
	_tube_mb(b, [Vector3(0.85, 7.45, -0.4), Vector3(0.25, 6.85, -0.95), Vector3(-0.45, 6.1, -0.92), Vector3(-0.82, 5.65, -0.55)], 0.12, W.darkened(0.08), 6)   # omuz örtüsü
	for s in [-1.0, 1.0]:   # göğüs önünde dua eden ana kollar
		_tube_mb(b, [Vector3(s * 1.02, 7.3, 0), Vector3(s * 1.15, 6.75, -0.3), Vector3(s * 0.75, 6.75, -0.78), Vector3(s * 0.16, 7.0, -0.98)], [0.27, 0.24, 0.2, 0.15], W, 10)
		b.add("box", Vector3(s * 0.06, 7.32, -1.02), Vector3(0.1, 0.56, 0.3), W, Vector3(-10, 0, s * 8.0))
	# baş: sakin yüz, topuz, kıvırcık saç taneleri, uzun kulaklar, kapalı gözler
	_tube_mb(b, [Vector3(0, 7.6, 0), Vector3(0, 7.95, -0.03)], [0.3, 0.28], W, 12)
	b.add("sphere", Vector3(0, 8.3, -0.05), Vector3(1.0, 1.15, 1.0), W, Vector3.ZERO, 16)
	b.add("sphere", Vector3(0, 8.95, 0.02), Vector3(0.46, 0.5, 0.46), D, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 9.25, 0.02), Vector3(0.22, 0.25, 0.22), D, Vector3.ZERO, 10)
	for k in 14:
		var a = k * TAU / 14.0
		b.add("sphere", Vector3(cos(a) * 0.4, 8.72, sin(a) * 0.4 - 0.05), Vector3(0.14, 0.12, 0.14), D, Vector3.ZERO, 6)
	for s in [-1.0, 1.0]:
		_tube_mb(b, [Vector3(s * 0.08, 8.3, -0.53), Vector3(s * 0.2, 8.28, -0.52), Vector3(s * 0.3, 8.31, -0.47)], 0.02, D, 4)
		b.add("sphere", Vector3(s * 0.5, 8.12, 0.0), Vector3(0.12, 0.52, 0.18), W, Vector3.ZERO, 8)
	b.add("box", Vector3(0, 8.15, -0.56), Vector3(0.08, 0.18, 0.08), W)
	b.add("box", Vector3(0, 7.97, -0.52), Vector3(0.16, 0.02, 0.02), D)
	b.add("sphere", Vector3(0, 8.45, -0.55), Vector3(0.06, 0.06, 0.04), D, Vector3.ZERO, 6)
	# taç gibi beş küçük baş (Issai Kaiku çıkış noktaları)
	var heads = []
	for k in 5:
		var a = lerpf(-1.25, 1.25, k / 4.0)
		var hp = Vector3(sin(a) * 0.64, 8.62, -cos(a) * 0.52)
		b.add("sphere", hp, Vector3(0.26, 0.3, 0.26), W.lightened(0.05), Vector3.ZERO, 10)
		b.add("sphere", hp + Vector3(0, 0.2, 0), Vector3(0.1, 0.12, 0.1), D, Vector3.ZERO, 6)
		heads.append(hp + Vector3(sin(a) * 0.14, 0, -cos(a) * 0.14))
	_tube_mb(b, _circle(Vector3(0, 8.5, 0), Vector3(0.66, 0, 0), Vector3(0, 0, 0.55), 26), 0.04, D, 4)
	# hale: gövdenin ardında büyük disk + iki halka + ışınlar
	var hc = Vector3(0, 7.4, 0.6)
	b.add("cyl", hc + Vector3(0, 0, 0.05), Vector3(9.2, 0.08, 9.2), W.darkened(0.12), Vector3(90, 0, 0), 40)
	_tube_mb(b, _circle(hc, Vector3(4.75, 0, 0), Vector3(0, 4.75, 0), 48), 0.18, D, 6)
	_tube_mb(b, _circle(hc + Vector3(0, 0, -0.05), Vector3(2.35, 0, 0), Vector3(0, 2.35, 0), 32), 0.1, D, 5)
	for k in 12:
		var a = k * TAU / 12.0
		var dv = Vector3(cos(a), sin(a), 0)
		_tube_mb(b, [hc + dv * 2.45 + Vector3(0, 0, -0.06), hc + dv * 4.6 + Vector3(0, 0, -0.06)], 0.04, D, 4)
	# haleden ışın gibi açılan iki sıra kol
	var hands = []
	for r in 2:
		var n = 22 + r * 8
		var L = 2.6 + r * 1.4
		for k in n:
			var a = (k + 0.5 * r) / float(n) * TAU
			var dv = Vector3(cos(a), sin(a), 0.12 + r * 0.08).normalized()
			var o = hc + Vector3(cos(a), sin(a), 0) * (2.3 + r * 0.25) + Vector3(0, 0, 0.2 + r * 0.15)
			var tip = o + dv * L
			var colr = W if (k + r) % 2 == 0 else W.darkened(0.07)
			_tube_mb(b, [o, o + dv * L * 0.5 + Vector3(0, 0, -0.1), tip], [0.16, 0.13, 0.1], colr, 6)
			_hand_mb(b, tip, dv, 0.55, colr)
			hands.append(tip + dv * 0.3)
	for s in [-1.0, 1.0]:   # öne uzanan dört uzun kol (ref)
		for h in 2:
			var o = Vector3(s * 0.95, 7.2 - h * 0.6, 0.15)
			var pts = [o, o + Vector3(s * 2.0, 0.8 - h * 1.6, -0.6), o + Vector3(s * 4.2, 1.0 - h * 2.6, -1.4), o + Vector3(s * 5.6, 0.6 - h * 3.4, -2.2)]
			_tube_mb(b, pts, [0.2, 0.18, 0.15, 0.12], W, 8)
			_hand_mb(b, pts[3], (pts[3] - pts[2]).normalized(), 0.75, W)
			hands.append(pts[3])
	var data = [b.build(null), heads, hands]
	_cache["kz"] = data
	return data


static func _kanzeon(pj: PathJutsu, pos: Vector3, yaw: float) -> Node3D:
	var data = _kz_data()
	var root = _root(pj, pos)
	root.rotation.y = yaw
	var body = Node3D.new()
	root.add_child(body)
	body.scale = Vector3.ONE * 16.0   # tasarım boyu 10 → ~160 m
	var mi = _geo(body, data[0], _carve())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.set_meta("body", body)
	root.set_meta("heads", data[1])
	root.set_meta("hands", data[2])
	return root


static func _kz_world(kz: Node3D, p: Vector3) -> Vector3:
	var body: Node3D = kz.get_meta("body")
	return body.global_transform * p


static func _wood_arm_mesh() -> ArrayMesh:
	if _cache.has("kz_arm"):
		return _cache["kz_arm"]
	var W = Color(0.52, 0.41, 0.33)
	var b = MB.new()
	_tube_mb(b, [Vector3(0, 0, 0), Vector3(0.004, 0.4, 0), Vector3(0, 0.82, 0)], [0.05, 0.046, 0.04], W, 10)
	_tube_mb(b, _circle(Vector3(0, 0.8, 0), Vector3(0.044, 0, 0), Vector3(0, 0, 0.044), 12), 0.008, W.darkened(0.25), 4)   # bilek bandı
	_hand_mb(b, Vector3(0, 0.82, 0), Vector3.UP, 0.18, W)
	for k in 3:   # tahta lif çizgileri
		var a = k * 2.1
		_tube_mb(b, [Vector3(cos(a) * 0.049, 0.05, sin(a) * 0.049), Vector3(cos(a + 0.2) * 0.045, 0.45, sin(a + 0.2) * 0.045), Vector3(cos(a) * 0.041, 0.78, sin(a) * 0.041)], 0.004, W.darkened(0.3), 3)
	_cache["kz_arm"] = b.build(null)
	return _cache["kz_arm"]


static func _earth_burst(pj: PathJutsu, at: Vector3, s: float) -> void:
	_cracks(pj, at, 2.2 * s, 7, 3.0)
	_parts(pj, pj.gp(at) + Vector3.UP * 0.3, {"kind": "chip", "mesh": _chip_mesh(Color(0.45, 0.38, 0.3)), "amount": int(12 * s), "life": 1.2, "size": 0.35 * s,
		"grow": 0.9, "spread": 40.0, "vmin": 4.0 * s, "vmax": 9.0 * s, "gravity": Vector3(0, -18, 0)})
	_ring_wave(pj, pj.gp(at) + Vector3.UP * 0.3, 0.5 * s, 3.0 * s, 0.6, _air(Color(0.66, 0.56, 0.44), 0.8), Color(1, 1, 1, 1), 0.35, 0.5 * s)
	_dust(pj, at, s * 0.8, Color(0.6, 0.5, 0.4), false)


static func _kz_fire(pj: PathJutsu, from: Vector3, d: Vector3, L: float) -> void:
	for k in 16:
		pj.after(k * 0.035, func():
			var sm = SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			var fb = _wgeo(pj, sm, _glow(Color(1.0, 0.95, 0.6), Color(1.0, 0.35, 0.05), 1.1, 0.2, 1.3))
			fb.global_position = from
			var sz = 0.8 + 5.0 * k / 16.0
			fb.scale = Vector3.ONE * sz * 0.5
			var end = from + d * (L * (0.35 + 0.65 * k / 16.0))
			var tw = fb.create_tween()
			tw.tween_property(fb, "global_position", end, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(fb, "scale", Vector3.ONE * sz * 1.3, 0.35)
			tw.tween_property(fb, "scale", Vector3.ONE * 0.05, 0.3)
			tw.tween_callback(fb.queue_free)
			if k % 4 == 0:
				_parts(pj, end, {"kind": "cel", "amount": 5, "life": 1.2, "size": 2.0 + k * 0.2, "grow": 1.6, "radius": 1.0, "vmin": 1.0, "vmax": 3.0,
					"gravity": Vector3(0, 1.0, 0), "colors": [Color(0.3, 0.24, 0.22, 0.0), Color(0.3, 0.24, 0.22, 0.85), Color(0.2, 0.18, 0.17, 0.0)]}))
	_parts(pj, from + d * L * 0.6, {"kind": "glow", "amount": 40, "life": 1.0, "size": 0.25, "radius": 3.0, "spread": 180.0, "vmin": 3.0, "vmax": 9.0,
		"gravity": Vector3(0, 2.0, 0), "colors": [Color(1.0, 0.85, 0.3, 1.0), Color(1.0, 0.4, 0.05, 0.8), Color(0.6, 0.1, 0.0, 0.0)]})


static func _kz_water(pj: PathJutsu, from: Vector3, goal: Vector3) -> void:
	var fn = func(k: float) -> Array:
		var u1 = clampf(k * 2.4, 0.0, 1.0)
		var u0 = clampf(k * 2.4 - 1.4, 0.0, 1.0)
		if u1 - u0 < 0.02:
			return []
		var pts = []
		var sd = (goal - from).cross(Vector3.UP).normalized()
		for s in 14:
			var u = lerpf(u0, u1, s / 13.0)
			pts.append(from.lerp(goal, u) + sd * sin(u * 7.0 + k * 9.0) * 1.2)
		return [pts, 1.1, _taper(14, 0.05, 0.2)]
	_live_tube(pj, _fluid("water"), 0.9, fn, 10, 0.25)
	pj.after(0.4, func():
		_star_splash(pj, goal, 6.0)
		_drops(pj, goal, "drop", 30, 6.0, 12.0, Vector3.UP, 70.0, 0.25, 1.2)
		_puddle(pj, goal, 6.0, Color(0.38, 0.6, 0.78), 3.0))


static func _kz_bolt(pj: PathJutsu, from: Vector3, goal: Vector3) -> void:
	var mi = _wgeo(pj, null, _glow(Color(1, 1, 1), Color(0.45, 0.65, 1.0), 0.7, 0.3, 1.8))
	var mw = weakref(mi)
	var flick = func(_i, _k):
		var m = mw.get_ref()
		if m == null:
			return
		var b = MB.new()
		var pts = _jag(from, goal, 14, 3.0)
		_tube_mb(b, pts, 0.35, Color(1, 1, 1, 1), 5)
		for q in 3:
			var s0: Vector3 = pts[3 + q * 3]
			var bp = _jag(s0, s0 + Vector3(randf_range(-6, 6), randf_range(-5, 2), randf_range(-6, 6)), 5, 1.0)
			_tube_mb(b, bp, 0.15, Color(1, 1, 1, 1), 4, _taper(bp.size(), 0.0, 0.7))
		m.mesh = b.build(null)
	pj.every(0.9, 0.06, flick, func():
		var m = mw.get_ref()
		if m != null:
			m.queue_free())
	_ring_wave(pj, pj.gp(goal) + Vector3.UP * 0.2, 1.0, 7.0, 0.4, _glow(Color(0.9, 0.95, 1.0), Color(0.4, 0.6, 1.0), 0.5, 0.3, 1.2))


static func _kz_wind(pj: PathJutsu, from: Vector3, goal: Vector3) -> void:
	var dv = goal - from
	var s1 = dv.cross(Vector3.UP).normalized()
	var s2 = dv.cross(s1).normalized()
	for q in 4:
		var ph = q * TAU / 4.0
		var fn = func(k: float) -> Array:
			var u1 = clampf(k * 2.5, 0.0, 1.0)
			if u1 < 0.02:
				return []
			var pts = []
			for s in 18:
				var u = u1 * s / 17.0
				var an = ph + u * 9.0 + k * 6.0
				pts.append(from.lerp(goal, u) + (s1 * cos(an) + s2 * sin(an)) * (0.6 + u * 2.4))
			return [pts, 0.3 + q * 0.05, _taper(18, 0.1, 0.3)]
		_live_tube(pj, _air(Color(0.92, 0.96, 1.0), 0.65), 0.6, fn, 4, 0.3)
	pj.after(0.35, func(): _dust(pj, goal, 3.0, Color(0.7, 0.65, 0.58), false))


static func _kz_rocks(pj: PathJutsu, from: Vector3, goal: Vector3) -> void:
	for q in 6:
		pj.after(q * 0.07, func():
			var b = MB.new()
			b.add("boulder", Vector3.ZERO, Vector3.ONE * randf_range(2.5, 4.0), Color(0.5, 0.42, 0.33), Vector3(randf() * 90.0, randf() * 360.0, 0), q + 3)
			var rock = _wgeo(pj, b.build(null), _carve())
			rock.global_position = from
			var to = goal + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			var tw = rock.create_tween()
			tw.tween_property(rock, "global_position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(rock, "rotation", Vector3(randf() * 6.0, randf() * 6.0, 0), 0.4)
			tw.tween_callback(func():
				_dust(pj, to, 2.0, Color(0.55, 0.47, 0.38))
				_cracks(pj, to, 3.0, 6, 2.5))
			tw.tween_method(func(v: float): _set_fade(rock, v), 1.0, 0.0, 0.5)
			tw.tween_callback(rock.queue_free))


static func _arm_slam(pj: PathJutsu, q: Vector3) -> void:
	_cracks(pj, q, 5.0, 9, 3.5)
	_dust(pj, q, 2.2, Color(0.6, 0.52, 0.42))
	_parts(pj, q + Vector3.UP * 0.8, {"kind": "chip", "mesh": _chip_mesh(Color(0.5, 0.39, 0.3)), "amount": 12, "life": 1.0, "size": 0.35, "grow": 0.8,
		"spread": 70.0, "vmin": 4.0, "vmax": 9.0, "gravity": Vector3(0, -16, 0)})   # tahta kıymıkları


static func kanzeon_renge_o(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var tt = pj.tg(c, t, 70.0)
	var fd = pj.fwd(c, t)
	var goal0 = pj.gp(tt.global_position if tt else c.global_position + fd * 35.0)
	var at = pj.gp(c.global_position - fd * 70.0)
	var kz = _kanzeon(pj, at - Vector3.UP * 170.0, atan2(-(goal0 - at).x, -(goal0 - at).z))
	for k in 8:
		_earth_burst(pj, at + Vector3(cos(k * 0.8) * 20.0, 0, sin(k * 0.8) * 20.0), 4.0)
	var rise = _parts(pj, at + Vector3.UP * 3.0, {"kind": "cel", "loop": true, "amount": 40, "life": 2.0, "size": 7.0, "grow": 1.6, "box": Vector3(26.0, 2.0, 26.0),
		"spread": 70.0, "vmin": 2.0, "vmax": 6.0, "damp": 1.0, "gravity": Vector3(0, 0.5, 0),
		"colors": [Color(0.6, 0.52, 0.42, 0.0), Color(0.6, 0.52, 0.42, 0.95), Color(0.5, 0.44, 0.36, 0.0)]})   # yükselirken taban tozu
	_stop_emit(rise, 1.6)
	pj.shake(1.6)
	Sfx.play("earth", at, 0.35)
	var tw = kz.create_tween()
	tw.tween_property(kz, "global_position", at, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():   # Issai Kaiku: beş baş, beş doğa
		var goal = pj.gp(tt.global_position if tt and pj.live(tt) else goal0) + Vector3.UP * 1.0
		var kinds = ["katon", "suiton", "raiton", "fuuton", "doton"]
		var heads: Array = kz.get_meta("heads")
		for i in 5:
			var from = _kz_world(kz, heads[i])
			var d = (goal - from).normalized()
			var L = from.distance_to(goal) + 6.0
			match kinds[i]:
				"katon":
					_kz_fire(pj, from, d, L)
				"suiton":
					_kz_water(pj, from, goal)
				"raiton":
					_kz_bolt(pj, from, goal)
				"fuuton":
					_kz_wind(pj, from, goal)
				"doton":
					_kz_rocks(pj, from, goal)
			pj.after(0.5, func():
				if pj.live(c):
					pj.hit(c, goal, 7.0, pj.inf(c, "kanzeon_renge_o", 0.45, {"knock": 8.0, "kind": "heavy", "element": kinds[i], "burn": 2.0 if kinds[i] == "katon" else 0.0, "stun": 0.4 if kinds[i] == "raiton" else 0.0})))
		pj.shake(1.0))
	tw.tween_interval(1.4)
	tw.tween_callback(func():   # Chōjō Kebutsu: haleden kollar
		for k in 18:
			pj.after(k * 0.08, func():
				if not is_instance_valid(kz):
					return
				var goal = pj.gp(tt.global_position if tt and pj.live(tt) else goal0)
				var q = goal + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
				var hands: Array = kz.get_meta("hands")
				var src = _kz_world(kz, hands[randi() % hands.size()])
				var hand = _wgeo(pj, _wood_arm_mesh(), _carve())
				hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				hand.global_position = src
				hand.look_at(q + Vector3(0.001, 0, 0), Vector3.UP)
				hand.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
				hand.scale = Vector3.ONE * 22.0
				var tw2 = hand.create_tween()
				tw2.tween_property(hand, "global_position", q - (q - src).normalized() * 20.0, clampf(src.distance_to(q) / 260.0, 0.3, 0.7)).set_ease(Tween.EASE_IN)
				tw2.tween_callback(func():
					_arm_slam(pj, q)
					pj.hit(c, q + Vector3.UP, 4.5, pj.inf(c, "kanzeon_renge_o", 0.3, {"knock": 10.0, "kind": "heavy"})))
				tw2.tween_interval(0.4)
				tw2.tween_method(func(v: float): _set_fade(hand, v), 1.0, 0.0, 0.25)
				tw2.tween_callback(hand.queue_free)))
	tw.tween_interval(2.6)
	tw.tween_property(kz, "global_position", at - Vector3.UP * 170.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(kz.queue_free)


# ================================================================== 11) Senpō: Sumi San Rasenshuriken — kara mürekkep rasenshuriken
static func _ink_shuriken(s: float) -> Node3D:
	var k = s / 2.6
	var root = Node3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.42 * k
	sm.height = 0.84 * k
	sm.radial_segments = 20
	sm.rings = 10
	_geo(root, sm, _fluid("ink"))
	var blades = Node3D.new()
	root.add_child(blades)
	var b = MB.new()
	for q in 4:   # dört kıvrık mürekkep kanadı, uçları damlayarak incelir
		var pts = []
		var sv = []
		var ws = []
		for i in 12:
			var u = i / 11.0
			var an = q * TAU / 4.0 + u * 1.15
			var rd = Vector3(cos(an), 0, sin(an))
			pts.append(rd * lerpf(0.42, 1.32, u) * k + Vector3.UP * sin(u * PI * 2.0) * 0.03 * k)
			sv.append(rd.cross(Vector3.UP).normalized())
			ws.append(lerpf(0.2, 0.0, pow(u, 0.8)) * k)
		_ribbon_mb(b, pts, sv, ws, Color(1, 1, 1, 1))
	_tube_mb(b, _circle(Vector3.ZERO, Vector3(0.75 * k, 0, 0), Vector3(0, 0, 0.75 * k), 32), 0.03 * k, Color(1, 1, 1, 1), 4, null)
	_geo(blades, b.build(null), _fluid("ink"))
	_spin(blades, 0.22)
	return root


static func _ink_burst(pj: PathJutsu, c: Node3D, pos: Vector3, m: float, rad: float, hold: float) -> void:
	var root = _root(pj, pos)
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	var dome = _geo(root, sm, _fluid("ink"))
	dome.scale = Vector3.ONE * 0.3
	var ring = Node3D.new()   # küreyi saran dev mürekkep kanatları
	root.add_child(ring)
	var b = MB.new()
	for q in 6:
		var pts = []
		var sv = []
		var ws = []
		for i in 14:
			var u = i / 13.0
			var an = q * TAU / 6.0 + u * 1.3
			var rd = Vector3(cos(an), 0, sin(an))
			pts.append(rd * lerpf(0.85, 1.3, u))
			sv.append(Vector3.UP)
			ws.append(lerpf(0.12, 0.0, u))
		_ribbon_mb(b, pts, sv, ws, Color(1, 1, 1, 1))
	_geo(ring, b.build(null), _fluid("ink"))
	ring.scale = Vector3.ONE * 0.3
	_spin(ring, 0.35)
	var tw = root.create_tween()
	tw.tween_property(dome, "scale", Vector3.ONE * rad, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "scale", Vector3.ONE * rad, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float): _set_fade(root, v), 1.0, 0.0, 0.45)
	tw.parallel().tween_property(dome, "scale", Vector3.ONE * rad * 1.15, 0.45)
	tw.tween_callback(root.queue_free)
	var gy = Game.jutsu_floor(pos.x, pos.z)
	var base = Vector3(pos.x, gy, pos.z)
	_cracks(pj, base, rad * 1.2, 9, 4.0)
	for q in 7:   # yerde kara mürekkep lekeleri
		var a = randf() * TAU
		_puddle(pj, base + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, rad * 0.9), randf_range(0.8, 2.0), Color(0.05, 0.045, 0.07), 5.0, 0.35)
	_drops(pj, pos, "ink", 40, 4.0, 10.0, Vector3.UP, 180.0, 0.12, 1.0)
	_parts(pj, base + Vector3.UP * 0.4, {"kind": "cel", "amount": 18, "life": 1.0, "size": 1.4, "grow": 1.8, "radius": rad, "spread": 80.0, "flat": 0.7,
		"vmin": 3.0, "vmax": 7.0, "damp": 3.0, "gravity": Vector3(0, 0.3, 0), "colors": [Color(0.12, 0.11, 0.15, 1.0), Color(0.1, 0.1, 0.13, 0.85), Color(0.1, 0.1, 0.12, 0.0)]})
	Sfx.play("wind", pos, 0.6)
	Sfx.play("rasengan", pos, 0.7)
	pj.shake(1.0)
	# içeridekiler çok sayıda küçük darbeyle tutulur (mekanik: ana ağaçtaki Rasenshuriken patlamasıyla aynı)
	var ht = root.create_tween()
	ht.tween_interval(0.15)
	for i in 9:
		ht.tween_callback(func():
			if is_instance_valid(c):
				Combat.hit_sphere(c, pos, rad, {"dmg": 8.0 * m, "element": "fuuton", "knock": 0.5, "kind": "light", "hitstop": 0.02}))
		ht.tween_interval(0.12)


static func senpo_sumisan_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 34.0)
	pj.busy(c, 1.0)
	pj.anim(c, "cast", 0.9)
	var body = _ink_shuriken(2.6)
	pj.scene_add(body, pj.hand_pos(c, true) + Vector3.UP * 0.8)
	body.scale = Vector3.ONE * 0.2
	var gt = body.create_tween()
	gt.tween_property(body, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_parts(pj, body.global_position, {"kind": "ink", "amount": 16, "life": 0.5, "size": 0.05, "radius": 1.8, "spread": 180.0, "vmin": 0.0, "vmax": 0.4,
		"radial": -14.0, "gravity": Vector3.ZERO, "burst": 0.4, "colors": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.3)]})   # mürekkep toplanır
	pj.free_after(3.0, body)
	Sfx.play("th_ink", c.global_position, 0.8)
	pj.after(0.55, func():
		if not pj.live(c):
			body.queue_free()
			return
		var from = body.global_position
		body.queue_free()
		var b2 = _ink_shuriken(2.6)
		pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, b2, pj.inf(c, "senpo_sumisan_rasenshuriken", 0.2, {"knock": 2.0, "kind": "light"}), tt, false, 2.0, func(p, _h):
			_ink_burst(pj, c, p, pj._mult_of(c) * 0.8, 6.0, 0.9)
			# mürekkep saçılması: içindekiler yapışır ve görmez
			for e in pj.enemies_near(c, p, 6.5):
				pj.st(e, "slow", 4.0)
				pj.st(e, "fear", 1.5)   # mürekkep gözü kapatır: kısa panik
				Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Mürekkep!", Color(0.6, 0.6, 0.7)))
		Sfx.play("whoosh", from, 0.8))


# ================================================================== 12) Ranjishigami — saç aslan yelesi ağzına dönüp yutar, sarar (ref: dişli saç ağzı)
static func _maw(col: Color, s: float) -> Node3D:
	var root = Node3D.new()
	var tooth = col.lightened(0.45)
	var parts = []
	for side in 2:   # 0 = üst çene, 1 = alt çene; menteşe arkada, çene ileri (-Z)
		var jaw = Node3D.new()
		root.add_child(jaw)
		var b = MB.new()
		var sg = 1.0 if side == 0 else -1.0
		b.add("hemi", Vector3(0, 0, -0.9) * s, Vector3(1.5, 0.75, 1.9) * s, col, Vector3.ZERO if side == 0 else Vector3(0, 0, 180.0), 14)
		for k in 9:   # ağız kenarı boyunca zikzak dişler
			var a = lerpf(-1.3, 1.3, k / 8.0)
			var tp = Vector3(sin(a) * 0.7, 0, -0.9 - cos(a) * 0.9) * s
			var tl = (0.32 if k % 2 == 0 else 0.22) * s
			b.add("cone", tp - Vector3.UP * sg * tl * 0.5, Vector3(0.12 * s, tl, 0.12 * s), tooth, Vector3(180.0 if side == 0 else 0.0, 0, 0), 6)
		_geo(jaw, b.build(null), _carve())
		if side == 0:   # tepede geriye savrulan saç tutamları
			var hb = MB.new()
			for k in 7:
				var x = lerpf(-0.5, 0.5, k / 6.0) * s
				_tube_mb(hb, [Vector3(x, 0.6 * s, -1.2 * s), Vector3(x * 1.2, 0.85 * s, -0.4 * s), Vector3(x * 1.4, 0.75 * s, 0.4 * s), Vector3(x * 1.5, 0.5 * s, 0.9 * s)],
					[0.07 * s, 0.06 * s, 0.04 * s, 0.0], col, 5)
			_geo(jaw, hb.build(null), _hair_mat(col))
		parts.append(jaw)
	root.set_meta("jaws", parts)
	return root


static func ranjishigami_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.2)
	if tt == null:
		return
	var hair: Color = c.model.look.get("hair", Color(0.9, 0.9, 0.88)) if c.get("model") else Color(0.9, 0.9, 0.88)
	var strand = hair.lightened(0.12)
	var hm = _hair_mat(strand)
	var hb = pj.bone_attach(c, "Head")
	var head_at = func() -> Vector3:
		return (hb.global_position + Vector3.UP * 0.12) if is_instance_valid(hb) else c.global_position + Vector3.UP * 1.75
	var h0: Vector3 = head_at.call()
	var side = (tt.global_position - h0).cross(Vector3.UP).normalized()
	# uzanma: 16 tel kafadan dalga dalga hedefe (her biri kendi dalgası), uçta yele ağzına toplanır
	for k in 16:
		var off = Vector3(randf_range(-0.35, 0.35), randf_range(0.3, 1.5), randf_range(-0.35, 0.35))
		var ph = randf() * TAU
		var amp = randf_range(0.2, 0.5)
		var end0: Vector3 = tt.global_position + off
		var dl = k * 0.012
		var fn = func(kk: float) -> Array:
			var u1 = clampf((kk - dl) * 3.2, 0.0, 1.0)
			if u1 < 0.03:
				return []
			var pts = []
			for s in 22:
				var q = u1 * s / 21.0
				var env = sin(q * PI)
				pts.append(h0.lerp(end0, q) + side * sin(q * 10.0 + ph) * amp * env + Vector3.UP * cos(q * 8.0 + ph) * amp * 0.6 * env)
			return [pts, 0.03, _taper(22, 0.05, 0.25)]
		_live_tube(pj, hm, 0.5, fn, 4, 0.12)
	var maw = _maw(strand, 0.95)   # ref: saç dişli dev bir ağıza dönüşür
	pj.scene_add(maw, tt.global_position + Vector3.UP * 1.0 + (h0 - tt.global_position).normalized() * Vector3(1, 0, 1) * 0.6)
	var look = Vector3(tt.global_position.x, maw.global_position.y, tt.global_position.z)
	if maw.global_position.distance_to(look) > 0.05:
		maw.look_at(look, Vector3.UP)
	var jaws: Array = maw.get_meta("jaws")
	maw.scale = Vector3.ONE * 0.2
	var mt = maw.create_tween()
	mt.tween_property(maw, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.parallel().tween_property(jaws[0], "rotation:x", 0.75, 0.18)
	mt.parallel().tween_property(jaws[1], "rotation:x", -0.5, 0.18)
	mt.tween_property(jaws[0], "rotation:x", 0.0, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	mt.parallel().tween_property(jaws[1], "rotation:x", 0.0, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	mt.tween_method(func(v: float): _set_fade(maw, v), 1.0, 0.0, 0.25)
	mt.tween_callback(maw.queue_free)
	Sfx.play("whoosh", c.global_position, 0.8)
	pj.after(0.35, func():
		if not pj.live(tt):
			return
		# sarma: ince halkalar (farklı yükseklik ve eğim) + bedeni dolanan sarmal tel
		var coc = Node3D.new()
		var hgt: float = float(tt.get("height")) if tt.get("height") != null else 1.8
		var b = MB.new()
		for j in 9:
			var r = randf_range(0.36, 0.5)
			var bs = Basis.from_euler(Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6)))
			var ctr = Vector3.UP * (0.25 + j * hgt * 0.1)
			_tube_mb(b, _circle(ctr, bs * Vector3.RIGHT * r, bs * Vector3.BACK * r, 24), 0.022, Color(1, 1, 1, 1), 4)
		var hp = []   # sarmal tel: bedeni aşağıdan yukarı 4 tur dolanır
		for i in 49:
			var a0 = TAU * 4.0 * i / 48.0
			hp.append(Vector3(cos(a0) * 0.45, 0.2 + hgt * 0.85 * i / 48.0, sin(a0) * 0.45))
		_tube_mb(b, hp, 0.02, Color(1, 1, 1, 1), 4)
		_geo(coc, b.build(null), hm)
		tt.add_child(coc)
		coc.scale = Vector3(1.5, 1.0, 1.5)
		var tw = coc.create_tween()
		tw.tween_property(coc, "scale", Vector3.ONE, 0.25)   # sıkar
		tw.tween_interval(2.0)
		tw.tween_callback(coc.queue_free)
		var cw2 = weakref(coc)
		for k in 5:   # bağ: kafadan hedefe gerili dalgalı teller
			var off2 = Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.3), randf_range(-0.3, 0.3))
			var ph2 = randf() * TAU
			var tie = func(kk: float) -> Array:
				var a: Vector3 = head_at.call()
				var e2: Vector3 = tt.global_position + off2 if pj.live(tt) else a
				var sd2 = (e2 - a).cross(Vector3.UP).normalized()
				var pts = []
				for s in 14:
					var q = s / 13.0
					pts.append(a.lerp(e2, q) + sd2 * sin(q * 12.0 + ph2 + kk * 30.0) * 0.18 * sin(q * PI))
				return [pts, 0.03, null]
			_live_tube(pj, hm, 2.3, tie, 4, 0.15)
		pj.free_after(2.4, hb)
		pj.st(tt, "bind", 2.4)
		var squeeze = func(_i, _k):
			if pj.live(tt):
				var cq = cw2.get_ref()
				if cq != null:   # sıkıştırma nabzı + kopan saç teli
					var pt = cq.create_tween()
					pt.tween_property(cq, "scale", Vector3(0.88, 1.0, 0.88), 0.07)
					pt.tween_property(cq, "scale", Vector3.ONE, 0.12)
				_parts(pj, tt.global_position + Vector3.UP, {"kind": "spark", "amount": 6, "life": 0.4, "size": 0.05, "spread": 180.0, "vmin": 1.5, "vmax": 3.0,
					"gravity": Vector3(0, -4, 0), "mat": hm})
				tt.take_hit(pj.inf(c, "ranjishigami_no_jutsu", 0.25, {"knock": 0.0, "kind": "light"}))
		pj.every(2.0, 0.5, squeeze, Callable())
		Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Yeleye sarıldı!", Color(0.95, 0.9, 0.8)))


# ================================================================== 13) Iburi: Kemuri Senzan — duman bedenle geçip kesmek
static func _smoke_cloud(pj: PathJutsu, pos: Vector3, r: float, n := 30, dir := Vector3.UP, speed := 1.5) -> void:
	_parts(pj, pos, {"kind": "cel", "amount": n, "life": 0.9, "size": r * 2.2, "grow": 1.7, "radius": r, "dir": dir, "spread": 55.0,
		"vmin": speed * 0.4, "vmax": speed, "damp": 2.0, "gravity": Vector3(0, 0.5, 0),
		"colors": [Color(0.84, 0.84, 0.87, 1.0), Color(0.72, 0.72, 0.76, 0.9), Color(0.62, 0.62, 0.66, 0.0)]})


static func _smoke_slash(pj: PathJutsu, ep: Vector3, sd: Vector3) -> void:
	var fwd2 = sd.cross(Vector3.UP).normalized()
	var b = MB.new()
	for layer in 2:   # koyu çizgi + beyaz kesik
		var pts = []
		var sv = []
		var ws = []
		for i in 12:
			var u = i / 11.0
			var p = ep + sd * lerpf(-0.9, 0.9, u) + Vector3.UP * lerpf(0.45, -0.45, u) + fwd2 * sin(u * PI) * 0.25 - fwd2 * 0.01 * layer
			pts.append(p)
			var tn = (sd * 1.8 + Vector3.DOWN * 0.9).normalized()
			sv.append(fwd2.cross(tn).normalized())
			ws.append(sin(u * PI) * (0.1 if layer == 0 else 0.065))
		_ribbon_mb(b, pts, sv, ws, Color(0.2, 0.2, 0.24, 1.0) if layer == 0 else Color(1, 1, 1, 1))
	_fade_free(_wgeo(pj, b.build(null), _decal()), 0.06, 0.12)


static func iburi_kemuri_senzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.2)
	var id = "iburi_kemuri_senzan"
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	_smoke_cloud(pj, c.global_position + Vector3.UP * 1.0, 0.45, 14, Vector3.UP, 1.0)   # beden dumana çözülür
	var m = c.get("model")
	if m:
		m.visible = false
	c.set_meta("kemuri_tai_until", Time.get_ticks_msec() / 1000.0 + 1.2)   # geçerken duman beden: fiziksel darbe değmez
	for k in 3:
		pj.after(0.05 + k * 0.32, func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			if cc == null or x == null or not is_instance_valid(cc) or not pj.live(x):
				return
			var a = k * 2.1 + 0.5
			var p0: Vector3 = cc.global_position
			var p1: Vector3 = pj.gp(x.global_position + Vector3(cos(a), 0, sin(a)) * 2.2)
			var trail = func(_i, kk):
				_smoke_cloud(pj, p0.lerp(p1, kk) + Vector3.UP * 1.0, 0.3, 4, (p1 - p0).normalized(), 1.2)
			pj.every(0.2, 0.025, trail)
			var sw = []   # duman bedenin geçiş izi: yassı gri şerit
			var ss = []
			for s in 8:
				sw.append(p0.lerp(p1, s / 7.0) + Vector3.UP * (1.0 + sin(s * 1.3) * 0.15))
				ss.append(Vector3.UP)
			var rb = MB.new()
			_ribbon_mb(rb, sw, ss, 0.45, Color(1, 1, 1, 1), _taper(8, 0.2, 0.2))
			_fade_free(_wgeo(pj, rb.build(null), _air(Color(0.75, 0.75, 0.8), 0.6)), 0.05, 0.3)
			cc.global_position = p1
			Sfx.play("smoke", x.global_position, 1.4)
			if pj.live(cc):
				var ep: Vector3 = x.global_position + Vector3.UP * 1.1
				var sd = (p1 - p0).normalized().cross(Vector3.UP)
				_smoke_slash(pj, ep, sd)
				x.take_hit(pj.inf(cc, id, 0.38, {"knock": 2.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.05})))
	pj.after(1.05, func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			if cc.get("model"):
				cc.model.visible = true
			_smoke_cloud(pj, cc.global_position + Vector3.UP, 0.5, 18)
			var x = tw.get_ref()
			if x != null and pj.live(x):
				pj._face(cc, x))


# ================================================================== 14) Kurama Genjutsu: Akai Ame — resmedilen kızıl yağmur gerçek olur
static func _paint_canvas(pj: PathJutsu, c: Node3D, col: Color, dur: float) -> void:
	var root = Node3D.new()
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(1.3, 0.95, 0.03), Color(0.93, 0.9, 0.8))
	for sy in [-1.0, 1.0]:
		b.add("cyl", Vector3(0, 0.5 * sy, 0), Vector3(0.07, 1.46, 0.07), Color(0.33, 0.21, 0.12), Vector3(0, 0, 90), 8)
	_geo(root, b.build(null), _decal())
	pj.scene_add(root, c.global_position + c.face_dir() * 0.9 + Vector3.UP * 1.3)
	root.global_basis = Basis.looking_at(c.face_dir(), Vector3.UP)
	var ink = Color(0.08, 0.05, 0.06)
	for k in 7:   # fırça darbeleri tuvale akar: üstte kara bulut, altına düşen kızıl çizgiler
		var tw = root.create_tween()
		tw.tween_interval(0.05 + k * 0.05)
		tw.tween_callback(func():
			if not is_instance_valid(root):
				return
			var sb = MB.new()
			var pts = []
			var sv = []
			var ws = []
			if k < 2:
				var y0 = 0.3 - k * 0.08
				for i in 8:
					var u = i / 7.0
					var p = Vector3(lerpf(-0.5, 0.5, u), y0 + sin(u * 9.0 + k) * 0.05, -0.022)
					pts.append(p)
					sv.append(Vector3.UP)
					ws.append(lerpf(0.06, 0.012, u))
				_ribbon_mb(sb, pts, sv, ws, ink)
			else:
				for q in 3:
					var x0 = randf_range(-0.5, 0.5)
					var p0 = Vector3(x0, 0.15, -0.022)
					var p1 = Vector3(x0 - 0.08, -0.38, -0.022)
					_ribbon_mb(sb, [p0, p0.lerp(p1, 0.5), p1], Vector3.RIGHT, [0.014, 0.012, 0.004], col)
			_geo(root, sb.build(null), _decal()))
	pj.free_after(dur, root)


static func _red_drop(pj: PathJutsu, p: Vector3) -> void:
	var g = pj.gp(p)
	var mi = _wgeo(pj, _tube([Vector3(0, 0, 0), Vector3(0, 0.9, 0)], [0.025, 0.012], Color(1, 1, 1, 1), 4), _fluid("rain"))
	mi.global_position = g + Vector3.UP * 6.0
	var tw = mi.create_tween()
	tw.tween_property(mi, "global_position", g, 0.22)
	tw.tween_callback(func():
		var b = MB.new()
		_band_mb(b, 0.82, 1.0, 0.0, 0.0, 20, Color(0.75, 0.06, 0.12), 1.0, 1.0)
		var rp = _wgeo(pj, b.build(null), _decal())
		rp.global_position = g + Vector3.UP * 0.04
		rp.scale = Vector3(0.1, 1.0, 0.1)
		var rt = rp.create_tween()
		rt.tween_property(rp, "scale", Vector3(0.55, 1.0, 0.55), 0.3).set_ease(Tween.EASE_OUT)
		_fade_free(rp, 0.1, 0.2))
	tw.tween_callback(mi.queue_free)


static func _red_daze(pj: PathJutsu, x: Node3D, dur: float) -> void:
	var root = Node3D.new()
	var b = MB.new()
	for k in 5:   # baş üstünde dönen kızıl yaprak halkası
		var a = k * TAU / 5.0
		b.add("sphere", Vector3(cos(a) * 0.38, 0, sin(a) * 0.38), Vector3(0.12, 0.04, 0.22), Color(0.82, 0.1, 0.16), Vector3(0, -rad_to_deg(a), 20), 8)
	_geo(root, b.build(null), _decal())
	pj.attach(x, root, dur, Vector3.UP * 2.3)
	_spin(root, 0.6)


static func kurama_akai_ame(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.9)
	var id = "kurama_akai_ame"
	pj._face(c, tt)
	_paint_canvas(pj, c, Color(0.85, 0.15, 0.2), 1.0)
	Sfx.play("genjutsu", c.global_position, 0.9)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		# gerçeklik genjutsusu isabeti: göz teması + Sharingan direnci (ortak kapı; ana ağaçtaki Kurama isabet yardımcısıyla aynı)
		var gm = Eyes.genjutsu_land(cc, x, true)
		if gm > 0.0:
			_red_daze(pj, x, 2.0)
			if x == Game.player and Game.world:
				Game.world.env.flash_tint(Color(0.35, 0.1, 0.4, 0.22), 1.2)
		if gm <= 0.0:
			return
		var cloud = _parts(pj, x.global_position + Vector3.UP * 6.3, {"kind": "cel", "loop": true, "amount": 26, "life": 1.4, "size": 1.6, "grow": 1.4,
			"box": Vector3(1.8, 0.3, 1.8), "spread": 180.0, "vmin": 0.1, "vmax": 0.4, "gravity": Vector3.ZERO,
			"colors": [Color(0.4, 0.05, 0.08, 0.0), Color(0.42, 0.06, 0.09, 0.95), Color(0.3, 0.03, 0.06, 0.0)]})   # hedefin üstünde kızıl bulut
		var clw = weakref(cloud)
		var rain = func(i, _k):
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if c2 == null or x2 == null or not pj.live(x2):
				return
			var cl = clw.get_ref()
			if cl != null:
				cl.global_position = x2.global_position + Vector3.UP * 6.3
			for q in 3:   # kızıl yağmur damlaları hedefin üstünden düşer
				var p: Vector3 = x2.global_position + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
				_red_drop(pj, p)
			if i % 8 == 0 and c2 != null and pj.live(c2):
				pj.st(x2, "slow", 0.6)
				x2.take_hit(pj.inf(c2, id, 0.22 * gm, {"knock": 0.0, "kind": "light", "burn": 1.0, "hitstop": 0.0, "sure": true}))
		pj.every(3.0 * gm, 0.06, rain, func(): _stop_emit(clw.get_ref(), 0.0)))


# ================================================================== 15) Ranton: Burakku Hantingu — kara şimşek panterler (ref: kapkara gövde, beyaz şimşek kenarı, beyaz dişli ağız)
static func _panther_data() -> Array:
	if _cache.has("panther"):
		return _cache["panther"]
	var b = MB.new()
	var W = Color(1, 1, 1, 1)
	# gövde (kuyruk +Z → göğüs -Z), boyun-baş, açık çene, kulaklar, bacaklar, kuyruk
	_tube_mb(b, [Vector3(0, 0.7, 0.75), Vector3(0, 0.76, 0.35), Vector3(0, 0.72, -0.1), Vector3(0, 0.8, -0.5), Vector3(0, 0.88, -0.75)], [0.17, 0.26, 0.23, 0.29, 0.24], W, 9)
	_tube_mb(b, [Vector3(0, 0.88, -0.75), Vector3(0, 0.98, -0.95), Vector3(0, 1.0, -1.15), Vector3(0, 0.95, -1.34)], [0.2, 0.22, 0.17, 0.08], W, 9)
	_tube_mb(b, [Vector3(0, 0.86, -0.98), Vector3(0, 0.72, -1.2), Vector3(0, 0.62, -1.34)], [0.13, 0.09, 0.04], W, 7)   # alt çene
	for sx in [-1.0, 1.0]:
		_tube_mb(b, [Vector3(sx * 0.11, 1.12, -0.92), Vector3(sx * 0.16, 1.3, -0.86)], [0.07, 0.0], W, 5)
		_tube_mb(b, [Vector3(sx * 0.15, 0.75, -0.55), Vector3(sx * 0.22, 0.42, -0.78), Vector3(sx * 0.19, 0.05, -0.9)], [0.11, 0.08, 0.07], W, 6)
		_tube_mb(b, [Vector3(sx * 0.15, 0.7, 0.45), Vector3(sx * 0.22, 0.42, 0.72), Vector3(sx * 0.18, 0.24, 0.52), Vector3(sx * 0.2, 0.03, 0.64)], [0.13, 0.09, 0.07, 0.06], W, 6)
	_tube_mb(b, [Vector3(0, 0.72, 0.8), Vector3(0, 0.88, 1.12), Vector3(0, 1.1, 1.36), Vector3(0, 1.28, 1.3)], [0.08, 0.06, 0.045, 0.0], W, 5)
	for k in 5:   # sırt dikenleri (şimşek parçaları gibi)
		var z = 0.4 - k * 0.25
		_tube_mb(b, [Vector3(0, 0.95 - k * 0.01, z), Vector3(0, 1.15, z + 0.12)], [0.06, 0.0], W, 4)
	var body_mesh = b.build(null)
	var tb = MB.new()   # beyaz dişler + göz yarıkları
	var wt = Color(0.97, 0.98, 1.0)
	for k in 6:
		var z = lerpf(-1.02, -1.3, k / 5.0)
		var x = (0.08 if k % 2 == 0 else -0.08) * (1.0 - k * 0.1)
		tb.add("cone", Vector3(x, 0.88, z), Vector3(0.05, 0.14, 0.05), wt, Vector3(180, 0, 0), 5)
		tb.add("cone", Vector3(-x, 0.73 - k * 0.02, z + 0.02), Vector3(0.045, 0.12, 0.045), wt, Vector3.ZERO, 5)
	for sx in [-1.0, 1.0]:
		tb.add("sphere", Vector3(sx * 0.1, 1.05, -1.08), Vector3(0.07, 0.03, 0.05), wt, Vector3(0, 0, sx * -18.0), 6)
	var data = [body_mesh, tb.build(null)]
	_cache["panther"] = data
	return data


static func _panther(s: float) -> Node3D:
	var data = _panther_data()
	var root = Node3D.new()
	var inner = Node3D.new()
	root.add_child(inner)
	inner.scale = Vector3.ONE * s
	_geo(inner, data[0], _storm())
	_geo(inner, data[1], _decal())
	var arcs = _geo(inner, null, _white_arc())   # gövdede kare kare yer değiştiren beyaz şimşek kıvılcımları
	var aw = weakref(arcs)
	_on_enter(root, func():
		var tw = Game.safe_loops(root.create_tween())
		tw.tween_callback(func():
			var a = aw.get_ref()
			if a == null:
				return
			var b = MB.new()
			for q in 3:
				var p0 = Vector3(randf_range(-0.35, 0.35), randf_range(0.4, 1.2), randf_range(-1.3, 1.0))
				var p1 = p0 + Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.5), randf_range(-0.6, 0.6))
				_tube_mb(b, _jag(p0, p1, 5, 0.12), 0.022, Color(1, 1, 1, 1), 4)
			a.mesh = b.build(null))
		tw.tween_interval(0.07))
	return root


static func _black_bolt(pj: PathJutsu, a: Vector3, b2: Vector3, w: float, life: float, branches := 1) -> void:
	var root = _root(pj, Vector3.ZERO)
	var core = MB.new()
	var halo = MB.new()
	var pts = _jag(a, b2, 9, a.distance_to(b2) * 0.12)
	_tube_mb(core, pts, w, Color(1, 1, 1, 1), 5)
	_tube_mb(halo, pts, w * 2.2, Color(1, 1, 1, 1), 5)
	for q in branches:
		var s0: Vector3 = pts[randi_range(2, pts.size() - 3)]
		var bp = _jag(s0, s0 + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * a.distance_to(b2) * 0.5, 5, 0.2)
		_tube_mb(core, bp, w * 0.6, Color(1, 1, 1, 1), 4, _taper(bp.size(), 0.0, 0.6))
		_tube_mb(halo, bp, w * 1.3, Color(1, 1, 1, 1), 4, _taper(bp.size(), 0.0, 0.6))
	_geo(root, core.build(null), _storm())
	_geo(root, halo.build(null), _white_arc())
	_fade_free(root, life * 0.6, life * 0.4)


static func _black_burst(pj: PathJutsu, o: Vector3, s: float) -> void:
	var root = _root(pj, o)
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	var ball = _geo(root, sm, _storm())
	var shell = _geo(root, sm, _glow(Color(1, 1, 1), Color(0.7, 0.75, 1.0), 3.0, 0.4, 1.5))
	shell.scale = Vector3.ONE * 1.12
	root.scale = Vector3.ONE * 0.2
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * s, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_property(root, "scale", Vector3.ONE * s * 0.05, 0.18).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): _set_fade(ball, v), 1.0, 0.2, 0.18)
	tw.tween_callback(root.queue_free)
	for k in 8:
		var a = k * TAU / 8.0 + randf() * 0.4
		_black_bolt(pj, o, o + Vector3(cos(a), randf_range(-0.3, 0.6), sin(a)) * s * 1.8, 0.09 * s, 0.35, 1)
	_parts(pj, o, {"kind": "glow", "amount": 22, "life": 0.5, "size": 0.15, "spread": 180.0, "vmin": 5.0, "vmax": 11.0, "gravity": Vector3(0, -4, 0),
		"colors": [Color(1, 1, 1, 1), Color(0.8, 0.85, 1.0, 0.8), Color(0.6, 0.65, 1.0, 0.0)]})
	_puddle(pj, o, s * 0.9, Color(0.06, 0.06, 0.08), 3.0, 0.1)
	_cracks(pj, o, s * 1.1, 8, 3.0)


static func ranton_burakku_hantingu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	for k in 3:   # hazırlık: avuçlar arasında kara şimşek çakar, çevrede kara bulut
		pj.after(k * 0.05, func():
			if pj.live(c):
				_black_bolt(pj, pj.hand_pos(c, true), pj.hand_pos(c, false) + Vector3.UP * randf_range(-0.2, 0.3), 0.04, 0.14, 1))
	_parts(pj, c.global_position + Vector3.UP * 1.2, {"kind": "cel", "amount": 10, "life": 0.9, "size": 0.9, "grow": 1.5, "radius": 0.8, "spread": 180.0,
		"vmin": 0.5, "vmax": 1.5, "gravity": Vector3(0, 0.6, 0), "colors": [Color(0.12, 0.12, 0.15, 1.0), Color(0.1, 0.1, 0.13, 0.8), Color(0.1, 0.1, 0.12, 0.0)]})
	for k in 4:
		var launch = func():
			if not pj.live(c):
				return
			var head = Node3D.new()
			var pa = _panther(1.5)
			pa.position.y = -0.9
			head.add_child(pa)
			var dir = d.rotated(Vector3.UP, (k - 1.5) * 0.5)
			var from = pj.gp(c.global_position + dir * 1.2) + Vector3.UP * 0.9
			var pr = pj.shot(c, from, dir, 24.0, head, pj.inf(c, "ranton_burakku_hantingu", 0.2, {"knock": 2.0, "kind": "light", "element": "ranton", "bleed": 1.0}), tt, true, 1.25,
				func(p, _h): _black_bolt(pj, p + Vector3.UP * 0.2, p + Vector3.UP * 1.6, 0.15, 0.2, 1))
			if pr:
				pr.homing_turn = 5.0
				pr.radius = 0.9
				pr.on_tick = func(p, _dt):
					p.global_position.y = Game.jutsu_floor(p.global_position.x, p.global_position.z) + 0.9
			Sfx.play("roar", from, 1.3, 0.5)
		pj.after(0.15 + k * 0.12, launch)
	var merge = func():
		if not pj.live(c):
			return
		var tp: Vector3 = tt.global_position if pj.live(tt) else c.global_position + d * 14.0
		var back = pj.gp(tp + d * 5.0)
		var big = _panther(4.6)
		pj.scene_add(big, back)
		if back.distance_to(Vector3(tp.x, back.y, tp.z)) > 0.1:
			big.look_at(Vector3(tp.x, back.y, tp.z), Vector3.UP)
		for n in 4:
			var s = tp + Vector3(randf_range(-6, 6), randf_range(0.5, 3.0), randf_range(-6, 6))
			_black_bolt(pj, s, back + Vector3.UP * 2.0, 0.22, 0.3, 2)
		Sfx.play("roar", back, 0.7, 1.0)
		var lunge = func(_i, k):
			if is_instance_valid(big):
				var goal: Vector3 = (pj.gp(tt.global_position) if pj.live(tt) else pj.gp(tp)) + d * 1.6
				big.global_position = back.lerp(goal, ease(k, 0.5))
		var bite = func():
			if not is_instance_valid(big):
				return
			var o = big.global_position + Vector3.UP * 1.6 - d * 1.6
			if pj.live(tt) and pj.live(c):
				tt.take_hit(pj.inf(c, "ranton_burakku_hantingu", 0.6, {"knock": 0.0, "kind": "heavy", "element": "ranton", "stun": 0.8, "bleed": 2.0, "hitstop": 0.12}))
			var boom = func():
				if is_instance_valid(big):
					big.queue_free()
				_black_burst(pj, o, 2.4)
				if pj.live(c):
					pj.hit(c, o, 4.6, pj.inf(c, "ranton_burakku_hantingu", 0.9, {"knock": 16.0, "launch": 5.0, "kind": "heavy", "element": "ranton", "stun": 0.8}))
				pj.shake(0.9)
				Sfx.play("thunder", o, 0.8, 1.0)
			pj.after(0.35, boom)
		pj.every(0.35, 1.0 / 60.0, lunge, bite)
	pj.after(1.45, merge)
