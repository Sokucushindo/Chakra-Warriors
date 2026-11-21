class_name Clan5FXA
extends RefCounted
## Klan grubu 5-A: Gekkō (ay ışığı kılıcı), Chinoike (Ketsuryūgan kan teknikleri), Mitarashi (gölge yılanları),
## Namikaze (Hiraishin / Raikō / Rasengan). Her tekniğin görünüşü bu dosyada sıfırdan üretilir: şerit, hilal, kan ejderi,
## kara madde, mühür formülü, Rasengan, zemin yarığı hepsi burada. Ortak efekt kütüphanesi kullanılmaz.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, Hiraishin işaret sistemi, yılanlar, kopyalar, gerçek göz sistemi)
## ana ağaçtaki işleyicilerden satır satır taşındı.

const MOON := Color(0.82, 0.88, 1.0)
const MOON_EDGE := Color(0.45, 0.58, 0.98)
const MOON_INK := Color(0.1, 0.13, 0.32)
const BLOOD := Color(0.75, 0.05, 0.08)
const BLOOD_DK := Color(0.32, 0.02, 0.04)
const EARTH := Color(0.55, 0.42, 0.3)
const DIRT := Color(0.2, 0.15, 0.11)
const VENOM := Color(0.5, 0.72, 0.2)
const VENOM_DK := Color(0.42, 0.16, 0.5)
const SKIN := Color(0.85, 0.82, 0.7)
const SHADE := Color(0.08, 0.05, 0.12)
const BOLT_Y := Color(1.0, 0.84, 0.22)
const BOLT_W := Color(1.0, 0.97, 0.75)
const RASEN := Color(0.45, 0.75, 1.0)
const STEEL := Color(0.74, 0.76, 0.8)
const DARK_MATTER := Color(0.2, 0.06, 0.24)

static var _shs := {}
static var _cache := {}


# ================================================================== gölgelendiriciler (kendi)
## Şerit: ortada açık çekirdek, kenar kuşağı, istenirse koyu dış çizgi; kameraya yakın kısım yumuşakça söner
const SWEEP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 edge_col : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform vec4 line_col : source_color = vec4(0.1, 0.12, 0.3, 1.0);
uniform float core_w = 0.35;
uniform float line_w = 0.0;
uniform float fade = 1.0;
void fragment() {
	float v = abs(UV.y - 0.5) * 2.0;
	float inner = 1.0 - step(core_w, v);
	vec3 c = mix(edge_col.rgb, core_col.rgb, inner);
	float ln = step(1.0 - line_w, v) * step(0.001, line_w);
	c = mix(c, line_col.rgb, ln);
	float a = mix(edge_col.a, core_col.a, inner);
	a = mix(a, line_col.a, ln);
	float near = smoothstep(0.5, 1.8, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(COLOR.a * fade * near * a, 0.0, 1.0);
}
"""

## Rasengan küresi: dönen girdap bantları, ak çekirdek, koyu mavi kenar çizgisi
const ORB_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec4 core_col : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 mid_col : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform vec4 rim_col : source_color = vec4(0.1, 0.28, 0.8, 1.0);
uniform float spin = 9.0;
uniform float fade = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 n = normalize(lp);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	float lon = atan(n.z, n.x);
	float b1 = sin(lon * 3.0 + lat * 6.0 - TIME * spin);
	float b2 = sin(lon * 5.0 - lat * 4.0 + TIME * spin * 1.4);
	float swirl = step(0.55, b1 * 0.6 + b2 * 0.4);
	vec3 c = mix(core_col.rgb, mid_col.rgb, smoothstep(0.15, 0.6, fr));
	c = mix(c, vec3(1.0), swirl * (1.0 - fr) * 0.8);
	c = mix(c, rim_col.rgb, step(0.82, fr));
	float near = smoothstep(0.4, 1.4, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp((0.78 + 0.22 * swirl) * fade * near, 0.0, 1.0);
}
"""

## Kan: yarı saydam pembe-kızıl gövde, iki ton cel, akan ak parıltılar, kırmızı kenar çizgisi (ref: Ketsuryū Shōten)
const BLOOD_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix;
uniform vec4 body_col : source_color = vec4(0.82, 0.36, 0.4, 0.88);
uniform vec4 deep_col : source_color = vec4(0.46, 0.05, 0.09, 1.0);
uniform vec4 edge_col : source_color = vec4(0.88, 0.05, 0.1, 1.0);
uniform float fade = 1.0;
uniform float flow = 2.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.3, 0.9, 0.3, 0.0)).xyz);
	float lit = dot(NORMAL, ld);
	vec3 c = mix(deep_col.rgb, body_col.rgb, step(0.0, lit));
	float sh = sin(wp.x * 3.1 + wp.y * 4.3 - TIME * flow) * sin(wp.z * 3.7 - wp.y * 2.2 + TIME * flow * 0.7);
	c = mix(c, vec3(1.0, 0.86, 0.86), step(0.8, sh) * step(0.15, lit));
	c = mix(c, edge_col.rgb, step(0.66, fr));
	float near = smoothstep(0.5, 1.6, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(body_col.a * fade * near * (0.8 + 0.2 * fr), 0.0, 1.0);
}
"""

## Koyu dış çizgi (ters kabuk)
const HULL_SH := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix;
uniform vec4 ink : source_color = vec4(0.1, 0.0, 0.02, 1.0);
uniform float width = 0.03;
uniform float fade = 1.0;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	float near = smoothstep(0.5, 1.6, -VERTEX.z);
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * fade * near, 0.0, 1.0);
}
"""

## Bakujin kara maddesi: mor hücreler, koyu damar ağı, ısındıkça kızıl-turuncu çatlaklar ve sarı çekirdek (ref)
const BLOAT_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix;
uniform float heat = 0.0;
uniform float fade = 1.0;
varying vec3 lp;
vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
vec2 vor(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int a = -1; a <= 1; a++) {
		for (int b = -1; b <= 1; b++) {
			for (int k = -1; k <= 1; k++) {
				vec3 g = vec3(float(a), float(b), float(k));
				vec3 r = g + h3(i + g) - f;
				float d = dot(r, r);
				if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
			}
		}
	}
	return vec2(sqrt(d1), sqrt(d2));
}
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec3 n = normalize(lp);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 v = vor(n * 3.2 + vec3(0.0, TIME * 0.05, 0.0));
	float border = 1.0 - smoothstep(0.05, 0.14, v.y - v.x);
	vec3 cell = mix(vec3(0.5, 0.22, 0.58), vec3(0.76, 0.46, 0.82), smoothstep(0.0, 0.7, v.x));
	float speck = step(0.86, fract(sin(dot(floor(n * 26.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453));
	cell = mix(cell, vec3(0.33, 0.12, 0.45), speck * 0.6);
	vec3 c = mix(cell, vec3(0.16, 0.04, 0.18), border);
	vec2 v2 = vor(n * 1.6 + vec3(3.1));
	float crack = 1.0 - smoothstep(0.0, 0.02 + 0.05 * heat, v2.y - v2.x);
	c = mix(c, vec3(1.0, 0.42, 0.14), crack * smoothstep(0.15, 0.6, heat));
	float core = 1.0 - step(heat * 0.55 - 0.12, fr);
	c = mix(c, vec3(1.0, 0.86, 0.45), core * smoothstep(0.55, 0.9, heat));
	c = mix(c, vec3(0.1, 0.02, 0.12), step(0.86, fr));
	float near = smoothstep(0.4, 1.4, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(0.96 * fade * near, 0.0, 1.0);
}
"""

## Hiraishin mühür formülü: halka, iç halka, yazı kümeleri, ortada üç kollu işaret (kunai kabzasındaki formül)
const SEAL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 glow : source_color = vec4(1.0, 0.86, 0.3, 1.0);
uniform vec4 ink : source_color = vec4(0.12, 0.08, 0.02, 1.0);
uniform float fade = 1.0;
uniform float seed = 0.0;
uniform float spin = 0.4;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + spin * TIME;
	float ring1 = 1.0 - smoothstep(0.0, 0.035, abs(r - 0.86));
	float ring2 = 1.0 - smoothstep(0.0, 0.025, abs(r - 0.34));
	float sec = a / 6.2831853 * 14.0 + seed;
	float fs = fract(sec);
	float band = r * 7.0;
	float fb = fract(band);
	float h = fract(sin(floor(sec) * 12.9898 + floor(band) * 78.233 + seed) * 43758.5453);
	float glyph = step(0.42, r) * step(r, 0.78) * step(0.18, fs) * step(fs, 0.82) * step(0.25, fb) * step(fb, 0.75) * step(0.35, h);
	float hollow = step(0.32, fs) * step(fs, 0.68) * step(0.4, fb) * step(fb, 0.6) * step(0.7, h);
	glyph *= 1.0 - hollow;
	float prong = (1.0 - smoothstep(0.0, 0.05, abs(sin(a * 1.5)) * r)) * step(r, 0.3);
	float lines = max(max(ring1, ring2), max(glyph, prong));
	float rim = (1.0 - smoothstep(0.0, 0.06, abs(r - 0.92))) * 0.9;
	float halo = (1.0 - smoothstep(0.2, 1.0, r)) * 0.16;
	vec3 c = mix(glow.rgb, vec3(1.0, 1.0, 0.92), lines * 0.5);
	c = mix(c, ink.rgb, rim * (1.0 - lines));
	float near = smoothstep(0.5, 1.6, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp((max(lines * 0.95, rim * 0.6) + halo) * fade * near * step(r, 1.0), 0.0, 1.0);
}
"""

## Zemin halkası / şok dalgası: iç-dış iki ton, istenirse kırık
const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 col_a : source_color = vec4(1.0);
uniform vec4 col_b : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float inner = 0.7;
uniform float fade = 1.0;
uniform float broken = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float bnd = smoothstep(inner, inner + 0.06, r) * (1.0 - smoothstep(0.93, 1.0, r));
	float gap = step(broken, fract(sin(floor((a + 3.15) * 9.0) * 7.31 + seed) * 437.58));
	float near = smoothstep(0.5, 1.6, -VERTEX.z);
	ALBEDO = mix(col_a.rgb, col_b.rgb, smoothstep(inner, 1.0, r));
	ALPHA = clamp(bnd * gap * fade * near * col_a.a, 0.0, 1.0);
}
"""

## Kıvrık kenarlı yer gölü (kan gölü, gölge havuzu, kavrulmuş iz): dalgalanan kenar, kenar kuşağı, ıslak parıltı
const POOL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 col : source_color = vec4(0.4, 0.02, 0.05, 0.9);
uniform vec4 rim : source_color = vec4(0.8, 0.05, 0.1, 1.0);
uniform float fade = 1.0;
uniform float seed = 0.0;
uniform float gloss = 1.0;
uniform float wave = 0.8;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = 0.82 + 0.1 * sin(a * 5.0 + seed) + 0.06 * sin(a * 11.0 - seed * 2.0 + TIME * wave);
	float inside = 1.0 - step(edge, r);
	float rb = step(edge - 0.07, r) * inside;
	vec3 c = mix(col.rgb, rim.rgb, rb);
	float hl = step(0.93, sin(p.x * 6.0 + seed) * sin(p.y * 5.0 - seed)) * gloss * (1.0 - rb);
	c = mix(c, vec3(1.0, 0.82, 0.82), hl * 0.6);
	ALBEDO = c;
	ALPHA = clamp(inside * col.a * fade, 0.0, 1.0);
}
"""

## İnce kan sisi tabakası (parçacık billboard): taneli damlacık lekeleri, kenarda söner; kameraya yakın kısım erken söner
const MIST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 col_dark : source_color = vec4(0.32, 0.02, 0.05, 1.0);
uniform vec4 col_lite : source_color = vec4(0.62, 0.08, 0.12, 1.0);
uniform float fade = 1.0;
varying float sd;
void vertex() {
	sd = INSTANCE_CUSTOM.x;
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = sin(UV.x * 9.0 + sd * 3.0 + TIME * 0.7) * sin(UV.y * 7.0 - sd + TIME * 0.5) + 0.5 * sin((UV.x + UV.y) * 17.0 + sd * 5.0);
	float speck = step(0.9, fract(sin(dot(floor(UV * 34.0), vec2(12.9898, 78.233)) + sd) * 43758.5453));
	float body = (1.0 - smoothstep(0.3, 1.0, r)) * (0.45 + 0.25 * n);
	vec3 c = mix(col_dark.rgb, col_lite.rgb, step(0.15, n));
	c = mix(c, vec3(0.9, 0.1, 0.14), speck);
	float near = smoothstep(1.2, 3.5, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp((body + speck * 0.45 * (1.0 - r)) * COLOR.a * fade * near, 0.0, 1.0);
}
"""

## Kabarık kan damarları: modelin üstüne bindirilen nabız gibi atan kırmızı damar ağı (Ketsueki Henge)
const VEIN_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform float amt = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float l1 = abs(sin(lp.x * 23.0 + sin(lp.y * 9.0) * 1.7 + lp.z * 11.0));
	float l2 = abs(sin(lp.y * 19.0 + sin(lp.z * 13.0) * 1.3 - lp.x * 7.0));
	float vein = (1.0 - smoothstep(0.0, 0.09, l1)) + (1.0 - smoothstep(0.0, 0.07, l2));
	float pulse = 0.6 + 0.4 * sin(TIME * 7.0 - lp.y * 4.0);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(vec3(0.45, 0.0, 0.04), vec3(0.95, 0.06, 0.1), pulse);
	ALPHA = clamp((min(vein, 1.0) * 0.85 * pulse + step(0.72, fr) * 0.45) * amt, 0.0, 1.0);
}
"""


# ================================================================== temel yapı taşları
static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _root() -> Node:
	return _tree().current_scene


static func _put(n: Node3D, pos: Vector3) -> Node3D:
	_root().add_child(n)
	n.global_position = pos
	return n


static func _kill(n: Node, sec: float) -> void:
	var w = weakref(n)
	_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func _cam() -> Vector3:
	var cam = _tree().root.get_camera_3d()
	return cam.global_position if cam else Vector3(0, 60, 0)


static func _flr(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z) + 0.04, p.z)


static func _sh(key: String) -> Shader:
	if _shs.has(key):
		return _shs[key]
	var s = Shader.new()
	match key:
		"sweep":
			s.code = SWEEP_SH
		"sweep_add":
			s.code = SWEEP_SH.replace("blend_mix", "blend_add")
		"orb":
			s.code = ORB_SH
		"blood":
			s.code = BLOOD_SH
		"hull":
			s.code = HULL_SH
		"bloat":
			s.code = BLOAT_SH
		"seal":
			s.code = SEAL_SH
		"ring":
			s.code = RING_SH
		"pool":
			s.code = POOL_SH
		"mist":
			s.code = MIST_SH
		"vein":
			s.code = VEIN_SH
	_shs[key] = s
	return s


static func _sm(key: String, params: Dictionary) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _sh(key)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _sweep(core: Color, edge: Color, core_w := 0.35, add := false, ink := Color(0, 0, 0, 0), ink_w := 0.0) -> ShaderMaterial:
	return _sm("sweep_add" if add else "sweep", {"core_col": core, "edge_col": edge, "core_w": core_w, "line_col": ink, "line_w": ink_w})


## Malzemenin fade parametresini 1→0 indirip düğümü siler
static func _fade_free(n: Node, mat: ShaderMaterial, hold: float, dur: float) -> void:
	var tw = n.create_tween()
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


static func _flat(col: Color, add := false, cull := BaseMaterial3D.CULL_DISABLED) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = cull
	m.albedo_color = col
	return m


static func _sphere_mesh() -> SphereMesh:
	if not _cache.has("mesh:sphere"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 24
		s.rings = 12
		_cache["mesh:sphere"] = s
	return _cache["mesh:sphere"]


static func _quad_mesh() -> QuadMesh:
	if not _cache.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(2, 2)
		_cache["mesh:quad"] = q
	return _cache["mesh:quad"]


static func _soft_tex() -> Texture2D:
	if not _cache.has("tex:soft"):
		var g = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_cache["tex:soft"] = t
	return _cache["tex:soft"]


static func _grad(cols: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func _basis_facing(nrm: Vector3) -> Basis:
	var z = nrm.normalized()
	var up = Vector3.UP if absf(z.y) < 0.95 else Vector3.FORWARD
	var x = up.cross(z).normalized()
	var y = z.cross(x).normalized()
	return Basis(x, y, z)


## Kendi parçacıklarım: o = n, life, size, r / box / pts, dir, spread, vmin, vmax, grav, damp, radial, tan, cols, add, loop, expl,
## parent, local, quad (kare parça), spin, mat (özel malzeme)
static func _motes(pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = maxi(1, int(o.get("n", 16)))
	p.lifetime = float(o.get("life", 0.8))
	p.one_shot = not o.get("loop", false)
	p.explosiveness = float(o.get("expl", 0.9))
	p.randomness = 0.5
	p.lifetime_randomness = 0.35
	p.local_coords = false
	var qm = QuadMesh.new()
	var sz = float(o.get("size", 0.3))
	qm.size = Vector2(sz, sz)
	if o.has("mat"):
		qm.material = o["mat"]
	else:
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if o.get("add", false) else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if not o.get("quad", false):
			m.albedo_texture = _soft_tex()
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.4
		qm.material = m
	p.mesh = qm
	if o.has("pts"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		p.emission_points = o["pts"]
	elif o.has("box"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = o["box"]
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(o.get("r", 0.3))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 60.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("grav", Vector3(0, 0.3, 0))
	p.damping_min = float(o.get("damp", 1.5))
	p.damping_max = float(o.get("damp", 1.5)) * 1.4
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0)) * 1.2
	p.tangential_accel_min = float(o.get("tan", 0.0))
	p.tangential_accel_max = float(o.get("tan", 0.0)) * 1.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -float(o.get("spin", 0.0))
	p.angular_velocity_max = float(o.get("spin", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.6))
	p.scale_amount_max = float(o.get("smax", 1.2))
	var cv = Curve.new()
	cv.max_value = 3.0
	cv.add_point(Vector2(0.0, float(o.get("s0", 0.5))))
	cv.add_point(Vector2(0.3, 1.0))
	cv.add_point(Vector2(1.0, float(o.get("s1", 0.7))))
	p.scale_amount_curve = cv
	p.color_ramp = _grad(o.get("cols", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent = o.get("parent", null)
	if parent != null and is_instance_valid(parent):
		parent.add_child(p)
		p.position = o.get("local", Vector3.ZERO)
	else:
		_put(p, pos)
	p.emitting = true
	if not o.get("loop", false):
		_kill(p, p.lifetime * 1.5 + 0.3)
	return p


## Fırlayan katı parçalar (toprak, kabuk, metal): kutu, cel, yerçekimiyle düşer
static func _chunks(pos: Vector3, n: int, col: Color, spd: float, sz := 0.2, dir := Vector3.UP, spread := 50.0, grav := -20.0) -> void:
	var p = CPUParticles3D.new()
	p.amount = maxi(1, n)
	p.lifetime = 0.95
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime_randomness = 0.3
	p.local_coords = false
	var bm = BoxMesh.new()
	bm.size = Vector3(sz, sz * 0.7, sz * 0.85)
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	bm.material = m
	p.mesh = bm
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = spd * 0.5
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, grav, 0)
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(0.75, 1.0))
	cv.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = cv
	_put(p, pos)
	p.emitting = true
	_kill(p, 1.6)


## İz şeridi: path_fn(q) yolu; baş ilerler, kuyruk izler, sonra kuyruktan yenerek söner.
## o: n, tail (0..1), taper, wfn(q, p) genişlik yönü (yoksa kameraya dönük), shape(q) genişlik çarpanı
static func _ribbon(path_fn: Callable, w: float, mat: Material, grow: float, hold: float, fade: float, o := {}) -> MeshInstance3D:
	var n: int = int(o.get("n", 16))
	var tail: float = float(o.get("tail", 1.0))
	var taper: float = float(o.get("taper", 0.7))
	var wfn: Callable = o.get("wfn", Callable())
	var shp: Callable = o.get("shape", Callable())
	var cam: Vector3 = _cam()
	var mi = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	mi.mesh = im
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	var draw = func(h: float, t0: float, a: float) -> void:
		im.clear_surfaces()
		if h - t0 < 0.003 or a < 0.004:
			return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n + 1:
			var u = float(i) / n
			var q = lerpf(t0, h, u)
			var p: Vector3 = path_fn.call(q)
			var pa: Vector3 = path_fn.call(maxf(0.0, q - 0.01))
			var pb: Vector3 = path_fn.call(minf(1.0, q + 0.01))
			var tg = pb - pa
			if tg.length() < 0.00001:
				tg = Vector3.FORWARD
			var sd: Vector3
			if wfn.is_valid():
				sd = wfn.call(q, p)
			else:
				sd = tg.cross(cam - p).normalized()
			var ww = w * lerpf(1.0 - taper, 1.0, u) * clampf((1.0 - u) * 8.0 + 0.25, 0.0, 1.0)
			if shp.is_valid():
				ww *= float(shp.call(q))
			var al = a * lerpf(0.25, 1.0, u)
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(p - sd * ww * 0.5)
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(p + sd * ww * 0.5)
		im.surface_end()
	var tw = mi.create_tween()
	tw.tween_method(func(k: float): draw.call(k, maxf(0.0, k - tail), 1.0), 0.0, 1.0, maxf(grow, 0.01))
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(func(k: float): draw.call(1.0, lerpf(maxf(0.0, 1.0 - tail), 1.0, k * 0.8), 1.0 - k), 0.0, 1.0, maxf(fade, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


static func _streak(a: Vector3, b: Vector3, w: float, mat: Material, grow: float, hold: float, fade: float, o := {}) -> MeshInstance3D:
	return _ribbon(func(q: float) -> Vector3: return a.lerp(b, q), w, mat, grow, hold, fade, o)


## cen çevresinde f (0 açı) ile sv (90°) düzleminde a0→a1 süpürülen yay
static func _arc(cen: Vector3, f: Vector3, sv: Vector3, r: float, a0: float, a1: float, w: float, mat: Material, grow: float, hold: float, fade: float, o := {}) -> MeshInstance3D:
	return _ribbon(func(q: float) -> Vector3:
		var a = lerpf(a0, a1, q)
		return cen + (f * cos(a) + sv * sin(a)) * r, w, mat, grow, hold, fade, o)


## Düz yer / hava plakası (QuadMesh, normal nrm): büyür, bekler, söner
static func _plate(pos: Vector3, nrm: Vector3, radius: float, mat: ShaderMaterial, grow: float, hold: float, fade: float, parent: Node3D = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _quad_mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null and is_instance_valid(parent):
		parent.add_child(mi)
		mi.global_position = pos
	else:
		_put(mi, pos)
	mi.global_basis = _basis_facing(nrm)
	mi.scale = Vector3.ONE * radius * 0.15
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius, maxf(grow, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, maxf(fade, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


static func _ring(pos: Vector3, nrm: Vector3, radius: float, ca: Color, cb: Color, inner: float, grow: float, fade: float, broken := 0.0) -> void:
	var m = _sm("ring", {"col_a": ca, "col_b": cb, "inner": inner, "broken": broken, "seed": randf() * 10.0})
	_plate(pos, nrm, radius, m, grow, 0.0, fade)


static func _pool(pos: Vector3, radius: float, col: Color, rim: Color, grow: float, hold: float, fade: float, gloss := 1.0) -> void:
	var m = _sm("pool", {"col": col, "rim": rim, "seed": randf() * 20.0, "gloss": gloss})
	_plate(_flr(pos), Vector3.UP, radius, m, grow, hold, fade)


static func _light(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_put(l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, maxf(dur, 0.01))
	tw.tween_callback(l.queue_free)


## Kırık çatlak çizgisi: yere yapışık daralan dörtgenler, ortada dallanır
static func _crack_line(im: ImmediateMesh, p: Vector3, dir: Vector3, L: float, w: float, depth: int, col: Color) -> void:
	var steps = 4
	var cur = p
	var d = dir
	for s in steps:
		d = d.rotated(Vector3.UP, randf_range(-0.45, 0.45)).normalized()
		var nx = cur + d * (L / steps)
		var a = _flr(cur) + Vector3.UP * 0.012
		var b = _flr(nx) + Vector3.UP * 0.012
		var side = d.cross(Vector3.UP).normalized()
		var w0 = w * (1.0 - float(s) / steps) + 0.006
		var w1 = w * (1.0 - float(s + 1) / steps) + 0.004
		for v in [a - side * w0, a + side * w0, b + side * w1, a - side * w0, b + side * w1, b - side * w1]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
		if depth > 0 and s == 1 and randf() < 0.75:
			_crack_line(im, nx, d.rotated(Vector3.UP, randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0)), L * 0.45, w0 * 0.6, depth - 1, col)
		cur = nx


static func _cracks(cen: Vector3, r: float, n: int, life: float, col := DIRT, bias := Vector3.ZERO) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a = TAU * float(i) / n + randf_range(-0.3, 0.3)
		var dd = (Vector3(cos(a), 0, sin(a)) + bias).normalized()
		_crack_line(im, cen, dd, r * randf_range(0.55, 1.0), r * 0.05, 2, col)
	im.surface_end()
	_root().add_child(mi)
	var tw = mi.create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.4)
	tw.tween_callback(mi.queue_free)


## Darbe kıvılcımı: kısa ışınsal çizgiler + çok kısa ışık (kendi)
static func _nick(pos: Vector3, col: Color, s := 1.0, rays := 5) -> void:
	var m = _sweep(Color(1, 1, 1, 1), Color(col.r, col.g, col.b, 0.9), 0.35, true)
	for i in rays:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		_streak(pos + dv * 0.1 * s, pos + dv * randf_range(0.5, 0.9) * s, 0.07 * s, m, 0.04, 0.0, 0.12, {"n": 3, "taper": 0.9})
	_light(pos, col, 2.0 * s, 3.0 * s, 0.12)


# ================================================================== GEKKŌ — ay ışığı kılıcı
## Avuçtan çekilen soluk ay ışığı kılıcı: ak çekirdek, mavi hale, koyu lacivert dış çizgi; bıçaktan ay tozu dökülür
static func _moon_blade(pj: PathJutsu, c: Node3D, dur: float, len_: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var mid = Vector3(0, 0, len_ * 0.55)
	var core = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.022, 0.06, len_)
	core.mesh = bm
	core.material_override = _flat(Color(0.95, 0.97, 1.0, 1.0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ba.add_child(core)
	core.position = mid
	var ink = MeshInstance3D.new()
	var im_ = BoxMesh.new()
	im_.size = Vector3(0.04, 0.085, len_ + 0.03)
	ink.mesh = im_
	ink.material_override = _flat(Color(MOON_INK.r, MOON_INK.g, MOON_INK.b, 0.9), false, BaseMaterial3D.CULL_FRONT)
	ba.add_child(ink)
	ink.position = mid
	var halo = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(0.09, 0.17, len_ + 0.14)
	halo.mesh = hm
	halo.material_override = _flat(Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.3), true)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ba.add_child(halo)
	halo.position = mid
	_motes(Vector3.ZERO, {"parent": ba, "local": mid, "loop": true, "n": 14, "life": 0.6, "size": 0.08, "box": Vector3(0.02, 0.03, len_ * 0.5),
		"vmin": 0.2, "vmax": 0.6, "grav": Vector3(0, 0.7, 0), "add": true, "expl": 0.0, "cols": [Color(0.9, 0.95, 1.0, 0.9), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.0)]})
	pj.free_after(dur, ba)


## Hilal mesh'i: XZ düzleminde, -Z yönüne kabaran, uçları sivri; UV.y iç→dış (şerit gölgelendiricisiyle çizgili kenar)
static func _crescent_mesh() -> ArrayMesh:
	if _cache.has("mesh:cres"):
		return _cache["mesh:cres"]
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var cols = PackedColorArray()
	var nrms = PackedVector3Array()
	var idx = PackedInt32Array()
	var n = 28
	for i in n + 1:
		var u = float(i) / n
		var a = lerpf(-1.25, 1.25, u)
		var cl = Vector3(sin(a), 0, -cos(a))
		var t = pow(sin(PI * u), 0.8) * 0.24
		verts.append(cl * (1.0 - t))
		uvs.append(Vector2(u, 0.0))
		verts.append(cl * (1.0 + t * 0.3))
		uvs.append(Vector2(u, 1.0))
		for j in 2:
			cols.append(Color(1, 1, 1, 1))
			nrms.append(Vector3.UP)
	for i in n:
		var k = i * 2
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_INDEX] = idx
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cache["mesh:cres"] = am
	return am


## Hilal düğümü: f yönüne kabarır, nrm hilal düzleminin normali; r yarıçap
static func _crescent(pos: Vector3, f: Vector3, nrm: Vector3, r: float, mat: ShaderMaterial) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _crescent_mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(mi, pos)
	var z = -f.normalized()
	var y = nrm.normalized()
	var x = y.cross(z).normalized()
	y = z.cross(x).normalized()
	mi.global_basis = Basis(x, y, z)
	mi.scale = Vector3.ONE * r
	return mi


static func _moon_mat(alpha := 1.0, add := false) -> ShaderMaterial:
	return _sweep(Color(1, 1, 1, alpha), Color(MOON.r, MOON.g, MOON.b, 0.95 * alpha), 0.42, add, Color(MOON_INK.r, MOON_INK.g, MOON_INK.b, 0.9 * alpha), 0.0 if add else 0.16)


## Ay ışığının avuçta toplanışı: içe çekilen soluk zerreler
static func _moon_gather(pj: PathJutsu, c: Node3D) -> void:
	_motes(pj.hand_pos(c), {"n": 18, "life": 0.35, "size": 0.12, "r": 0.9, "vmin": 0.0, "vmax": 0.2, "radial": -9.0, "grav": Vector3.ZERO, "add": true,
		"cols": [Color(MOON.r, MOON.g, MOON.b, 0.0), Color(0.95, 0.97, 1.0, 0.9), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.0)]})


## Gekkō: Mikazukigiri — tepeden iniş kesiği; bıçaktan kopan dik hilal, arkasında iki soluk hayalet hilal ve yerde ince
## biçme izi bırakarak 14 m uçar
static func gekko_mikazukigiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "gekko_mikazukigiri"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	_moon_blade(pj, c, 0.6, 1.0)
	_moon_gather(pj, c)
	pj.anim(c, "slash_c", 2.0)
	var cw = weakref(c)
	pj.after(0.18, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var from: Vector3 = cc.global_position + Vector3.UP * 1.2 + d * 0.8
		var sd = d.cross(Vector3.UP).normalized()
		_arc(cc.global_position + Vector3.UP * 1.1, d, Vector3.UP, 1.15, 1.7, -0.6, 0.26, _moon_mat(), 0.07, 0.0, 0.2, {"n": 14, "tail": 0.8})
		var cres = _crescent(from, d, sd, 1.3, _moon_mat())
		var ghosts = []
		for g in 2:
			ghosts.append(_crescent(from, d, sd, 1.3 * (1.0 - 0.1 * (g + 1)), _moon_mat(0.45 - g * 0.15, true)))
		_motes(Vector3.ZERO, {"parent": cres, "loop": true, "n": 22, "life": 0.5, "size": 0.12, "r": 0.6, "vmin": 0.1, "vmax": 0.5, "expl": 0.0, "add": true,
			"cols": [Color(0.95, 0.97, 1.0, 0.8), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.0)]})
		var all = [cres] + ghosts
		var tw = cres.create_tween()
		tw.tween_method(func(k: float):
			if is_instance_valid(cres):
				cres.global_position = from + d * 14.0 * k
			for g in ghosts.size():
				if is_instance_valid(ghosts[g]):
					ghosts[g].global_position = from + d * 14.0 * maxf(0.0, k - 0.07 * (g + 1)), 0.0, 1.0, 0.45)
		tw.tween_method(func(v: float):
			for n in all:
				if is_instance_valid(n):
					(n.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.15)
		tw.tween_callback(func():
			for n in all:
				if is_instance_valid(n):
					n.queue_free())
		var g0: Vector3 = _flr(from)
		_ribbon(func(q: float) -> Vector3: return _flr(g0.lerp(g0 + d * 14.0, q)) + Vector3.UP * 0.02, 0.08,
			_sweep(Color(0.95, 0.97, 1.0, 0.9), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.7), 0.3, false, Color(MOON_INK.r, MOON_INK.g, MOON_INK.b, 0.8), 0.25),
			0.45, 0.5, 0.7, {"n": 24, "taper": 0.2, "wfn": func(_q: float, _p: Vector3) -> Vector3: return sd})
		Sfx.play("swing_sword", from, 1.3)
		var hitk = {}
		pj.every(0.45, 0.03, func(_i, k):
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			for e in pj.enemies_near(c2, from + d * 14.0 * k, 1.5):
				if hitk.has(e.get_instance_id()):
					continue
				hitk[e.get_instance_id()] = true
				_nick(e.global_position + Vector3.UP * 1.1, MOON, 0.8)
				e.take_hit(pj.inf(c2, id, 1.3, {"knock": 6.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.06, "dir": d}))))


## Gekkō: Getsuei Bunshin — ay ışığı soluğunda üç kopya; altlarında soluk ay halesi, sonra üçü birden içeri keser:
## hedefte buluşan üç ışık kesiği üç kollu bir yıldız çizer, yerde üçgen iz kalır
static func gekko_getsuei_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.0)
	var id = "gekko_getsuei_bunshin"
	pj._face(c, tt)
	pj._yama_seal(c)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var clones = []
	for k in 3:
		var a = k * TAU / 3.0 + 0.5
		var p: Vector3 = pj.gp(tt.global_position + Vector3(cos(a), 0, sin(a)) * 1.6)
		var cl = pj.decoy(c, p, 1.2)
		if cl:
			var cm = cl.get("model")
			if cm and is_instance_valid(cm):   # ay ışığı soluklukta kopya
				var ov = StandardMaterial3D.new()
				ov.albedo_color = Color(0.8, 0.86, 1.0, 0.4)
				ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ov.emission_enabled = true
				ov.emission = Color(0.4, 0.45, 0.6)
				for mi in (cm as Node).find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_overlay = ov
			clones.append([weakref(cl), p])
			_ring(_flr(p), Vector3.UP, 0.9, Color(0.95, 0.97, 1.0, 0.8), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.6), 0.78, 0.25, 0.9)
			_motes(p + Vector3.UP * 0.9, {"n": 16, "life": 1.0, "size": 0.1, "r": 0.5, "vmin": 0.3, "vmax": 1.0, "dir": Vector3.UP, "spread": 25.0, "add": true,
				"grav": Vector3(0, 0.8, 0), "cols": [Color(0.95, 0.97, 1.0, 0.9), Color(MOON.r, MOON.g, MOON.b, 0.0)]})
	pj.after(0.45, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var q: Vector3 = x.global_position + Vector3.UP * 1.1
		var pts = []
		for pair in clones:
			var p: Vector3 = pair[1]
			pts.append(p)
			var a: Vector3 = p + Vector3.UP * 1.1
			var dir: Vector3 = (q - a).normalized()
			_streak(a, q + dir * 1.3, 0.2, _moon_mat(), 0.06, 0.05, 0.25, {"n": 8, "tail": 0.9, "taper": 0.6})
		for k in 3:   # buluşma noktasında dışa açılan üç küçük hilal
			var aa = k * TAU / 3.0
			var od = Vector3(cos(aa), 0.25, sin(aa)).normalized()
			var mc = _crescent(q, od, Vector3.UP.cross(od).normalized() if absf(od.y) < 0.9 else Vector3.RIGHT, 0.35, _moon_mat())
			var mtw = mc.create_tween()
			mtw.tween_property(mc, "global_position", q + od * 0.8, 0.25)
			mtw.parallel().tween_method(func(v: float): (mc.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
			mtw.tween_callback(mc.queue_free)
		if pts.size() >= 2:
			for k in pts.size():
				var a0: Vector3 = _flr(pts[k]) + Vector3.UP * 0.02
				var b0: Vector3 = _flr(pts[(k + 1) % pts.size()]) + Vector3.UP * 0.02
				var sd = (b0 - a0).cross(Vector3.UP).normalized()
				_streak(a0, b0, 0.06, _sweep(Color(0.95, 0.97, 1.0, 0.8), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.6), 0.4), 0.12, 0.9, 0.6,
					{"n": 6, "taper": 0.0, "wfn": func(_q: float, _p: Vector3) -> Vector3: return sd})
		_light(q, MOON, 2.5, 5.0, 0.25)
		Sfx.play("swing_sword", x.global_position, 1.2)
		_nick(q, MOON, 1.3, 7)
		x.take_hit(pj.inf(cc, id, 1.2, {"knock": 4.0, "kind": "heavy", "bleed": 3.0, "stun": 0.4, "hitstop": 0.1, "pierce_guard": true})))


## Dişli ay halkası: düz halka + altı kancalı diş, koyu dış çizgili
static func _wheel_mesh(ink: bool) -> ArrayMesh:
	var key = "mesh:wheel_ink" if ink else "mesh:wheel"
	if _cache.has(key):
		return _cache[key]
	var s = 1.08 if ink else 1.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ci = Color(MOON_INK.r, MOON_INK.g, MOON_INK.b, 0.9) if ink else Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.95)
	var co = Color(MOON_INK.r, MOON_INK.g, MOON_INK.b, 0.9) if ink else Color(0.97, 0.98, 1.0, 1.0)
	var r0 = 0.55 * (0.95 if ink else 1.0)
	var r1 = 0.78 * s
	var seg = 36
	for i in seg:
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		var i0 = Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var i1 = Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var o0 = Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var o1 = Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		for v in [[i0, ci], [o0, co], [o1, co], [i0, ci], [o1, co], [i1, ci]]:
			st.set_color(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	for k in 6:
		var a0 = TAU * k / 6.0
		var b0 = Vector3(cos(a0) * r1 * 0.98, 0, sin(a0) * r1 * 0.98)
		var b1 = Vector3(cos(a0 + 0.42) * r1 * 0.98, 0, sin(a0 + 0.42) * r1 * 0.98)
		var md = Vector3(cos(a0 + 0.3) * 0.9 * s, 0, sin(a0 + 0.3) * 0.9 * s)
		var tip = Vector3(cos(a0 + 0.62) * 1.12 * s, 0, sin(a0 + 0.62) * 1.12 * s)
		for v in [b0, b1, md, b0, md, tip]:
			st.set_color(co)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var am = st.commit()
	_cache[key] = am
	return am


## Gekkō: Tsuki no Wa — avuçta sıkışan ay ışığı dişli bir halka bıçağa dönüşür; dönerek gider, geri döner, arkasında ay tozu
static func gekko_tsuki_no_wa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "gekko_tsuki_no_wa"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.8)
	var cw = weakref(c)
	var start: Vector3 = pj.hand_pos(c)
	var end: Vector3 = (tt.global_position + Vector3.UP * 1.0) if tt else start + d * 14.0
	_moon_gather(pj, c)
	var ring = Node3D.new()
	var body = MeshInstance3D.new()
	body.mesh = _wheel_mesh(false)
	var bmat = StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.vertex_color_use_as_albedo = true
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material_override = bmat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(body)
	var ink = MeshInstance3D.new()
	ink.mesh = _wheel_mesh(true)
	ink.material_override = bmat
	ink.position = Vector3.DOWN * 0.012
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(ink)
	pj.scene_add(ring, start)
	ring.scale = Vector3.ONE * 0.9
	ring.rotation.x = 0.18
	_motes(Vector3.ZERO, {"parent": ring, "loop": true, "n": 30, "life": 0.45, "size": 0.14, "r": 0.85, "vmin": 0.0, "vmax": 0.3, "expl": 0.0, "add": true,
		"grav": Vector3.ZERO, "cols": [Color(0.95, 0.97, 1.0, 0.85), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.0)]})
	var hits = {}
	Sfx.play("whoosh", start, 1.4)
	pj.every(1.2, 1.0 / 30.0, func(_i, k):
		var cc = cw.get_ref()
		if not is_instance_valid(ring):
			return
		var back_to: Vector3 = pj.hand_pos(cc) if cc != null and is_instance_valid(cc) else start
		var p: Vector3 = start.lerp(end, sin(k * PI)) if k < 0.5 else end.lerp(back_to, (k - 0.5) * 2.0)
		ring.global_position = p
		ring.rotate_y(0.8)
		if cc == null or not pj.live(cc):
			return
		var leg = 0 if k < 0.5 else 1
		for e in pj.enemies_near(cc, p, 1.3):
			var key = "%d_%d" % [e.get_instance_id(), leg]
			if hits.has(key):
				continue
			hits[key] = true
			_nick(p, MOON, 0.8)
			var nd = (e.global_position - p)
			nd.y = 0
			if nd.length() > 0.01:
				_arc(e.global_position + Vector3.UP * 1.0, nd.normalized(), nd.normalized().cross(Vector3.UP), 0.6, -1.2, 1.2, 0.12, _moon_mat(), 0.05, 0.0, 0.18, {"n": 8})
			e.take_hit(pj.inf(cc, id, 0.9, {"knock": 3.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.05})), func():
		if is_instance_valid(ring):
			_motes(ring.global_position, {"n": 14, "life": 0.35, "size": 0.12, "r": 0.3, "vmin": 1.0, "vmax": 2.5, "add": true,
				"cols": [Color(0.95, 0.97, 1.0, 0.9), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.0)]})
			ring.queue_free())


## Ay ışığıyla dolan dik yarık: koyu zemin yarığı, içinde soluk mavi parıltı
static func _fissure(a: Vector3, b: Vector3, w: float, life: float) -> void:
	var dd = b - a
	dd.y = 0
	var sd = dd.normalized().cross(Vector3.UP).normalized()
	var sdv = randf() * 10.0
	var path = func(q: float) -> Vector3:
		return _flr(a.lerp(b, q) + sd * sin(q * 21.0 + sdv) * w * 0.35) + Vector3.UP * 0.015
	var shape = func(q: float) -> float: return pow(sin(PI * q), 0.6)
	_ribbon(path, w, _sweep(Color(0.05, 0.04, 0.04, 0.95), Color(DIRT.r, DIRT.g, DIRT.b, 0.9), 0.5, false, Color(0.45, 0.36, 0.26, 0.9), 0.18),
		0.08, life * 0.6, life * 0.4, {"n": 26, "taper": 0.0, "shape": shape, "wfn": func(_q: float, _p: Vector3) -> Vector3: return sd})
	_ribbon(func(q: float) -> Vector3: return path.call(q) + Vector3.UP * 0.01, w * 0.3, _sweep(Color(0.95, 0.97, 1.0, 0.9), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.8), 0.4, true),
		0.1, 0.5, 0.6, {"n": 26, "taper": 0.0, "shape": shape, "wfn": func(_q: float, _p: Vector3) -> Vector3: return sd})


## Gekkō: Kagetsuki Otoshi — sıçrayışta soluk iz; tepede rakibin üstünde dev bir azalan ay belirir, kılıçla birlikte iner:
## yer boydan boya yarılır, yarığın içinde ay ışığı söner, kopan toprak
static func gekko_kagetsuki_otoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.1)
	var id = "gekko_kagetsuki_otoshi"
	var d = pj._face(c, tt)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 5.0)
	var p0: Vector3 = c.global_position
	var cw = weakref(c)
	var sd = d.cross(Vector3.UP).normalized()
	_moon_blade(pj, c, 1.0, 1.2)
	pj.anim(c, "jump", 1.4)
	var em = _motes(c.global_position + Vector3.UP, {"loop": true, "n": 40, "life": 0.4, "size": 0.16, "r": 0.25, "vmin": 0.0, "vmax": 0.2, "expl": 0.0, "add": true,
		"grav": Vector3.ZERO, "cols": [Color(0.95, 0.97, 1.0, 0.8), Color(MOON_EDGE.r, MOON_EDGE.g, MOON_EDGE.b, 0.0)]})
	_kill(em, 1.0)
	var moon = {"n": null}
	pj.after(0.33, func():   # tepede: hedefin üstünde dev hilal belirir
		var mc = _crescent(at + Vector3.UP * 3.0 - d * 0.6, Vector3.DOWN.lerp(d, 0.2).normalized(), sd, 1.8, _moon_mat())
		mc.scale = Vector3.ONE * 0.4
		var mt = mc.create_tween()
		mt.tween_property(mc, "scale", Vector3.ONE * 1.8, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		moon["n"] = mc
		_kill(mc, 1.2)
		_light(at + Vector3.UP * 3.0, MOON, 2.0, 7.0, 0.5))
	pj.every(0.6, 1.0 / 60.0, func(_i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var top = p0.lerp(at - d * 1.2, 0.6) + Vector3.UP * 5.0
		cc.global_position = p0.lerp(top, k / 0.6) if k < 0.6 else top.lerp(at - d * 1.2, (k - 0.6) / 0.4)
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		if is_instance_valid(em):
			em.global_position = cc.global_position + Vector3.UP * 1.0, func():
		var mc = moon["n"]
		if mc != null and is_instance_valid(mc):   # hilal kılıçla birlikte yere iner, saplanıp söner
			var dt = mc.create_tween()
			dt.tween_property(mc, "global_position", at + Vector3.UP * 0.9, 0.08)
			dt.tween_method(func(v: float): (mc.material_override as ShaderMaterial).set_shader_parameter("fade", v), 1.0, 0.0, 0.45)
			dt.tween_callback(mc.queue_free)
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj.anim(cc, "slash_c", 2.2)
		_arc(at + Vector3.UP * 1.4 - d * 0.6, Vector3.UP, d, 1.5, 0.2, 2.6, 0.3, _moon_mat(), 0.08, 0.0, 0.22, {"n": 14, "tail": 0.8})
		_fissure(at - d * 3.2, at + d * 3.2, 0.5, 2.6)
		_cracks(at, 2.4, 6, 2.4, DIRT, Vector3.ZERO)
		_chunks(at, 12, EARTH, 7.0, 0.22, Vector3.UP, 40.0)
		_motes(at + Vector3.UP * 0.2, {"n": 18, "life": 0.9, "size": 0.7, "r": 1.2, "vmin": 1.5, "vmax": 3.5, "dir": Vector3.UP, "spread": 75.0, "grav": Vector3(0, -0.4, 0),
			"cols": [Color(0.7, 0.6, 0.48, 0.7), Color(0.6, 0.52, 0.42, 0.0)]})
		_light(at + Vector3.UP * 0.5, MOON, 3.0, 6.0, 0.3)
		Sfx.play("swing_sword", at, 0.9)
		pj.shake(0.4)
		for e in pj.enemies_near(cc, at, 2.4):
			e.take_hit(pj.inf(cc, id, 1.6, {"knock": 4.0, "launch": -4.0, "kind": "heavy", "bleed": 3.0, "stun": 0.5, "hitstop": 0.12, "pierce_guard": true})))


# ================================================================== CHINOIKE — Ketsuryūgan kan teknikleri
## Gerçek göz sistemi: modelin kendi Ketsuryūgan görünümü (kızıl göz akı + göz izi) dur sn açılır, sonra eski göze döner
static func _ketsu_eyes(c: Node3D, dur: float) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or not m.has_method("set_dojutsu_eyes"):
		return
	if not m.has_meta("c5_keye_prev"):
		var prev = [0, 0, 0, 0]
		var em = m.get("eye_mat")
		if em != null and em is ShaderMaterial:
			var names = ["dojutsu", "tomoe", "dojutsu_l", "tomoe_l"]
			for i in 4:
				var v = (em as ShaderMaterial).get_shader_parameter(names[i])
				prev[i] = int(v) if v != null else 0
		m.set_meta("c5_keye_prev", prev)
	var until = Time.get_ticks_msec() + int(dur * 1000.0)
	m.set_meta("c5_keye_until", until)
	m.set_dojutsu_eyes(3, 3, 3, 3)
	var mw = weakref(m)
	_tree().create_timer(dur).timeout.connect(func():
		var mm = mw.get_ref()
		if mm == null or not is_instance_valid(mm) or not mm.has_meta("c5_keye_until"):
			return
		if Time.get_ticks_msec() < int(mm.get_meta("c5_keye_until")) - 30:
			return
		var pv: Array = mm.get_meta("c5_keye_prev", [0, 0, 0, 0])
		mm.set_dojutsu_eyes(int(pv[0]), int(pv[1]), int(pv[2]), int(pv[3]), int(pv[0]) == 2 or int(pv[2]) == 2)
		mm.remove_meta("c5_keye_prev")
		mm.remove_meta("c5_keye_until"))
	_light(c.global_position + Vector3.UP * 1.7, Color(1.0, 0.1, 0.12), 1.2, 2.0, 0.35)


## Kan damlaları (yerçekimli, kızıl, koyulaşarak düşer)
static func _drops(pos: Vector3, n: int, spd: float, dir := Vector3.UP, spread := 60.0, life := 0.7, sz := 0.09) -> void:
	_motes(pos, {"n": n, "life": life, "size": sz, "r": 0.12, "vmin": spd * 0.4, "vmax": spd, "dir": dir, "spread": spread, "grav": Vector3(0, -12, 0), "damp": 0.3,
		"quad": false, "s0": 1.0, "s1": 0.8, "cols": [Color(0.9, 0.1, 0.14, 1.0), BLOOD, Color(BLOOD_DK.r, BLOOD_DK.g, BLOOD_DK.b, 0.0)]})


## Kan kaynağı (kanon: kanı yaralı rakiplerden ya da kendi bileğinden çeker) — mekanik aynen; görsel: bilek kesiği + fışkırma
static func _blood_draw(pj: PathJutsu, c: Node3D, r: float) -> Array:
	var pts = []
	for e in pj.enemies_near(c, c.global_position, r):
		var wounded = (e.has_method("has_status") and e.has_status("bleed")) or (e.has_meta("last_wound") and Time.get_ticks_msec() - int(e.get_meta("last_wound")) < 20000)
		if wounded:
			pts.append(e.global_position + Vector3.UP * 1.0)
	if pts.is_empty():   # kendi kanı: bileğini keser
		if "hp" in c:
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.06)
		var hp: Vector3 = pj.hand_pos(c, false)
		pts.append(hp)
		var fd: Vector3 = c.face_dir()
		_streak(hp - fd.cross(Vector3.UP) * 0.12, hp + fd.cross(Vector3.UP) * 0.12, 0.04, _sweep(Color(1.0, 0.3, 0.3, 1.0), Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.9), 0.3), 0.04, 0.05, 0.15, {"n": 3})
		_drops(hp, 10, 2.5, fd + Vector3.UP * 0.5, 30.0)
	return pts


## Kan ejderi başı: kafatası, açık çene, geriye kıvrık boynuzlar, sarı gözler; koyu kızıl dış çizgi
static func _dragon_head(size: float, mat: ShaderMaterial) -> Node3D:
	var key = "mesh:dhead"
	if not _cache.has(key):
		var b = MB.new()
		b.add("sphere", Vector3(0, 0, 0), Vector3(0.7, 0.55, 0.8), BLOOD)
		b.add("box", Vector3(0, -0.02, -0.5), Vector3(0.42, 0.22, 0.6), BLOOD)
		b.add("box", Vector3(0, -0.26, -0.42), Vector3(0.36, 0.1, 0.55), BLOOD_DK, Vector3(-18, 0, 0))
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(0.18 * sx, 0.3, 0.2), Vector3(0.1, 0.55, 0.1), BLOOD, Vector3(-55, 0, 18 * sx), 5)
			b.add("cone", Vector3(0.3 * sx, 0.0, 0.12), Vector3(0.06, 0.32, 0.06), BLOOD, Vector3(-80, 0, 60 * sx), 4)
			b.add("cone", Vector3(0.13 * sx, -0.15, -0.72), Vector3(0.045, 0.14, 0.045), BLOOD, Vector3(180, 0, 0), 4)
		_cache[key] = b.build(null)
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = _cache[key]
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var ink = MeshInstance3D.new()
	ink.mesh = _cache[key]
	ink.material_override = _sm("hull", {"ink": Color(0.35, 0.0, 0.03, 1.0), "width": 0.035})
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ink)
	var em = _flat(Color(1.0, 0.85, 0.3, 1.0))
	for sx in [-1.0, 1.0]:
		var e = MeshInstance3D.new()
		e.mesh = _sphere_mesh()
		e.material_override = em
		e.scale = Vector3(0.1, 0.06, 0.08)
		e.position = Vector3(0.22 * sx, 0.12, -0.3)
		root.add_child(e)
	root.scale = Vector3.ONE * size
	return root


## Tüp gövde: pts boyunca halkalar, radii yarıçap
static func _tube(im: ImmediateMesh, pts: Array, radii: Array, sides: int) -> void:
	im.clear_surfaces()
	if pts.size() < 2:
		return
	var rings = []
	var nrms = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tg: Vector3 = (pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		if tg.length() < 0.0001:
			tg = Vector3.UP
		tg = tg.normalized()
		var ax = tg.cross(Vector3.UP if absf(tg.y) < 0.95 else Vector3.RIGHT).normalized()
		var ay = ax.cross(tg).normalized()
		var ring = []
		var nr = []
		for s in sides:
			var a = TAU * s / sides
			var nn = ax * cos(a) + ay * sin(a)
			ring.append(p + nn * float(radii[i]))
			nr.append(nn)
		rings.append(ring)
		nrms.append(nr)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		for s in sides:
			var s2 = (s + 1) % sides
			for v in [[i, s], [i + 1, s], [i + 1, s2], [i, s], [i + 1, s2], [i, s2]]:
				im.surface_set_normal(nrms[v[0]][v[1]])
				im.surface_set_color(Color(1, 1, 1, 1))
				im.surface_add_vertex(rings[v[0]][v[1]])
	im.surface_end()


## Kan ejderi: kaynaktan kalkan kalın, dalgalı kan gövdesi + baş; varınca ısırır (kanon: ısırınca buhar), sonra gövde
## çöker, damlalar düşer
static func _blood_dragon(pj: PathJutsu, from: Vector3, to_fn: Callable, dur: float, size: float, on_bite: Callable) -> void:
	var mat = _sm("blood", {"flow": 2.0 + randf()})
	var head = _dragon_head(size, mat)
	_put(head, from)
	var im = ImmediateMesh.new()
	var body = MeshInstance3D.new()
	body.mesh = im
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(body)
	var ink = MeshInstance3D.new()
	ink.mesh = im
	ink.material_override = _sm("hull", {"ink": Color(0.4, 0.0, 0.04, 1.0), "width": 0.03})
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ink)
	_motes(Vector3.ZERO, {"parent": head, "loop": true, "n": 10, "life": 0.6, "size": 0.08, "r": 0.25, "vmin": 0.0, "vmax": 0.4, "expl": 0.0, "grav": Vector3(0, -10, 0),
		"s0": 1.0, "s1": 0.8, "cols": [BLOOD, Color(BLOOD_DK.r, BLOOD_DK.g, BLOOD_DK.b, 0.0)]})
	var hw = weakref(head)
	var bw = weakref(body)
	var ph = randf() * TAU
	var last = {"pts": []}
	var go = func(_i, k):
		var h = hw.get_ref()
		if h == null:
			return
		var to: Vector3 = to_fn.call()
		var mid: Vector3 = from.lerp(to, 0.5) + Vector3.UP * (2.5 * size) + Vector3(cos(ph), 0, sin(ph)) * 1.5
		var u = minf(1.0, k * 1.25)
		var p: Vector3 = from.lerp(mid, u).lerp(mid.lerp(to, u), u)
		var dv: Vector3 = p - h.global_position
		if dv.length() > 0.02:
			var dn = dv.normalized()
			h.global_basis = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.97 else Vector3.FORWARD).scaled(Vector3.ONE * size)
		h.global_position = p
		var b = bw.get_ref()
		if b == null:
			return
		var tnow = Time.get_ticks_msec() / 1000.0
		var side = (to - from).cross(Vector3.UP).normalized()
		var pts = []
		var radii = []
		var nseg = 13
		for j in nseg + 1:
			var s = u * float(j) / nseg
			var q: Vector3 = from.lerp(mid, s).lerp(mid.lerp(to, s), s)
			var wob = sin(s * 9.0 + tnow * 6.0 + ph) * 0.25 * size * sin(PI * float(j) / nseg)
			pts.append(q + side * wob)
			var rr = lerpf(0.55, 0.3, float(j) / nseg) * size * (1.0 + 0.12 * sin(j * 1.7 + tnow * 5.0))
			if j == 0:
				rr *= 1.45
			radii.append(rr)
		pts[nseg] = p - (h.global_basis.z.normalized() * -0.35 * size)
		_tube(im, pts, radii, 8)
		last["pts"] = pts
	pj.every(dur, 0.03, go, func():
		var h = hw.get_ref()
		if h != null:
			var hp: Vector3 = h.global_position
			on_bite.call(hp)
			_drops(hp, 22, 6.0, Vector3.UP, 80.0, 0.8, 0.11)
			_motes(hp, {"n": 8, "life": 0.9, "size": 0.7, "r": 0.4, "vmin": 1.0, "vmax": 2.5, "dir": Vector3.UP, "spread": 45.0,
				"cols": [Color(1.0, 0.9, 0.9, 0.55), Color(1.0, 0.95, 0.95, 0.0)]})   # ısırınca buhar (kanon)
			_ring(hp, (_cam() - hp).normalized(), 0.9, Color(1.0, 0.4, 0.45, 0.85), Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.6), 0.75, 0.12, 0.15)
			h.queue_free()
		var b = bw.get_ref()
		if b != null:   # gövde çöker: aşağı süzülür, söner, damlalar düşer
			var lp: Array = last["pts"]
			for j in range(2, lp.size(), 4):
				_drops(lp[j], 6, 1.0, Vector3.DOWN, 40.0, 0.6)
			var tw = b.create_tween()
			tw.tween_property(b, "position:y", -0.7, 0.45)
			tw.parallel().tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.45)
			tw.tween_callback(b.queue_free))


## Ketsuryū Shōten (ref: Chino — kandan sekiz başlı ejder): yerde kan gölü, yaralılardan çekilen kan iplikleri; gölden sekiz
## yarı saydam, kızıl çizgili ejder başı kalkıp hedeflere dağılır, ısırınca buhar ve kan sıçrar
static func ketsuryu_shoten(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var id = "ketsuryu_shoten"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	_ketsu_eyes(c, 2.5)
	pj._yama_seal(c)
	var cw = weakref(c)
	var src: Array = _blood_draw(pj, c, 20.0)
	var base: Vector3 = pj.gp(c.global_position + d * 2.0)
	_pool(base, 2.4, Color(0.42, 0.02, 0.05, 0.92), Color(0.85, 0.06, 0.12, 1.0), 0.3, 2.2, 0.6)
	for s in src:
		var sp: Vector3 = s
		if sp.distance_to(base) > 1.0:
			_ribbon(func(q: float) -> Vector3: return sp.lerp(base + Vector3.UP * 0.3, q) + Vector3.UP * sin(PI * q) * 1.2, 0.12,
				_sweep(Color(0.95, 0.3, 0.32, 1.0), Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.9), 0.3, false, Color(0.35, 0.0, 0.03, 0.9), 0.2), 0.25, 0.15, 0.3, {"n": 14, "taper": 0.3})
	_drops(base, 18, 5.0, Vector3.UP, 50.0)
	Sfx.play("water", base, 0.5)
	var list = pj.enemies_near(c, c.global_position, 24.0)
	if tt and not tt in list:
		list.push_front(tt)
	for k in 8:   # sekiz baş: hedeflere dağılır, ısırır; ısırılan bağlanır
		var x = list[k % list.size()] if not list.is_empty() else null
		var xw = weakref(x) if x else null
		var from: Vector3 = (src[k % src.size()] as Vector3) if k < 2 else base + Vector3.UP * 0.5
		var off = Vector3(cos(k * 0.8), 0, sin(k * 0.8)) * 0.6
		var fallback: Vector3 = base + d * 8.0 + off * 4.0 + Vector3.UP
		pj.after(0.2 + k * 0.1, func():
			_blood_dragon(pj, from, func() -> Vector3:
				var xx = xw.get_ref() if xw else null
				return (xx.global_position + Vector3.UP * 1.1 + off * 0.5) if xx != null and pj.live(xx) else fallback, 0.6, 0.8, func(p: Vector3):
				var cc = cw.get_ref()
				if cc == null or not pj.live(cc):
					return
				Sfx.play("bite", p, 0.8 + k * 0.04)
				for e in pj.enemies_near(cc, p, 1.8):
					if not is_instance_valid(e) or e.is_dead():
						continue
					e.take_hit(pj.inf(cc, id, 0.6, {"knock": 3.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.04}))
					pj.st(e, "bind", 0.8)))


## Model üstüne kan damarı katmanı (dur sn); eski katman geri konur
static func _vein_overlay(x: Node3D, dur: float) -> void:
	var m = x.get("model")
	if m == null or not is_instance_valid(m):
		return
	var ov = _sm("vein", {"amt": 0.0})
	var meshes = (m as Node).find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var g = mi as MeshInstance3D
		if not g.has_meta("c5_vein_prev"):
			g.set_meta("c5_vein_prev", [g.material_overlay])
		g.material_overlay = ov
	var tw = (m as Node).create_tween()
	tw.tween_method(func(v: float): ov.set_shader_parameter("amt", v), 0.0, 1.0, 0.4)
	tw.tween_interval(maxf(0.0, dur - 0.8))
	tw.tween_method(func(v: float): ov.set_shader_parameter("amt", v), 1.0, 0.0, 0.4)
	tw.tween_callback(func():
		for mi in meshes:
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == ov:
				var pv: Array = (mi as MeshInstance3D).get_meta("c5_vein_prev", [null])
				(mi as MeshInstance3D).material_overlay = pv[0]
				(mi as MeshInstance3D).remove_meta("c5_vein_prev"))


## Ketsueki Henge — kan şişer: çevreden bedene çekilen damlalar, derinin altında nabız gibi atan kızıl damarlar, ayak altında
## kızıl nabız halkası; süre bitince bilekten fazla kan boşalır (kanon) ve yerde gölcük kalır
static func ketsueki_henge_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.9)
	var id = "ketsueki_henge_no_jutsu"
	_ketsu_eyes(c, 1.5)
	var wounded = tt != null and ((tt.has_method("has_status") and tt.has_status("bleed")) or (tt.has_meta("last_wound") and Time.get_ticks_msec() - int(tt.get_meta("last_wound")) < 20000))
	var x: Node3D = tt if wounded else c   # kanına chakra karışmış rakip yoksa kendine (kılık)
	var DUR = 8.0 if x == c else 5.0
	var m = x.get("model")
	if m and is_instance_valid(m) and m.get("overlay") != null:   # gerçek kemikler şişer
		var bones = {"UpperChest": 1.35, "Chest": 1.3, "LeftUpperArm": 1.45, "RightUpperArm": 1.45, "LeftUpperLeg": 1.35, "RightUpperLeg": 1.35, "Neck": 1.3}
		var tw0 = m.create_tween()
		tw0.tween_method(func(u: float):
			if is_instance_valid(m):
				for bn in bones:
					m.overlay.bulk[bn] = lerpf(1.0, float(bones[bn]), u), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw0.tween_interval(DUR)
		tw0.tween_method(func(u: float):
			if is_instance_valid(m):
				for bn in bones:
					m.overlay.bulk[bn] = lerpf(float(bones[bn]), 1.0, u), 0.0, 1.0, 0.4)
		tw0.tween_callback(func():
			if is_instance_valid(m):
				for bn in bones:
					m.overlay.bulk.erase(bn))
	var xp: Vector3 = x.global_position
	_vein_overlay(x, DUR + 0.4)
	_motes(xp + Vector3.UP * 1.0, {"n": 40, "life": 0.5, "size": 0.09, "r": 1.6, "vmin": 0.0, "vmax": 0.2, "radial": -14.0, "grav": Vector3.ZERO, "quad": false,
		"cols": [Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.0), Color(0.9, 0.1, 0.14, 1.0), BLOOD_DK]})
	_ring(_flr(xp), Vector3.UP, 1.4, Color(0.95, 0.15, 0.2, 0.85), Color(BLOOD_DK.r, BLOOD_DK.g, BLOOD_DK.b, 0.7), 0.72, 0.35, 0.5)
	_ring(_flr(xp), Vector3.UP, 0.9, Color(0.95, 0.15, 0.2, 0.7), Color(BLOOD_DK.r, BLOOD_DK.g, BLOOD_DK.b, 0.5), 0.8, 0.25, 0.4)
	Sfx.play("th_flesh", x.global_position, 0.8)
	var xw0 = weakref(x)
	pj.after(DUR, func():   # fazla kan bilekten atılır
		var xx = xw0.get_ref()
		if xx == null or not is_instance_valid(xx):
			return
		var hp: Vector3 = pj.hand_pos(xx, false)
		var xf: Vector3 = xx.face_dir() if xx.has_method("face_dir") else Vector3.FORWARD
		_drops(hp, 18, 3.5, Vector3.DOWN.lerp(xf, 0.5), 35.0, 0.7)
		_pool(xx.global_position + xf * 0.4, 0.7, Color(0.42, 0.02, 0.05, 0.9), Color(0.8, 0.05, 0.1, 1.0), 0.4, 1.5, 0.8))
	if x == c:
		if "hp" in c:
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.08)
		var hc: Vector3 = pj.hand_pos(c, false)
		_drops(hc, 10, 2.5, c.face_dir() + Vector3.UP * 0.3, 30.0)
		var mods = {"armor": 0.7, "melee": 1.25, "speed": 0.9, "_name": "Ketsueki Henge", "_desc": "kan şişirilmiş iri beden: darbeler hafifler, yumruk ağırlaşır"}
		if c is Player:
			Buffs.add(id, DUR, mods)
		elif c.has_method("add_buff"):
			c.add_buff(id, DUR, mods)
		return
	var cw = weakref(c)
	var xw = weakref(x)
	pj.st(x, "slow", DUR)
	Combat.popup_text(x.global_position + Vector3.UP * 2.8, "Kanı şişti!", Color(0.85, 0.1, 0.12))
	pj.every(DUR, 0.5, func(_i, _k):
		var cc = cw.get_ref()
		var xx = xw.get_ref()
		if cc == null or xx == null or not pj.live(xx):
			return
		xx.take_hit(pj.inf(cc, id, 0.22, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "pierce_guard": true})))


## Bakujin patlaması: sarı-turuncu çekirdek, savrulan mor-kara kabuk parçaları, köz, zemin şok halkası ve kavrulmuş iz
static func _bakujin_blast(p: Vector3) -> void:
	var core = MeshInstance3D.new()
	core.mesh = _sphere_mesh()
	var cm = _flat(Color(1.0, 0.88, 0.5, 1.0))
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(core, p)
	core.scale = Vector3.ONE * 0.4
	var tw = core.create_tween()
	tw.tween_property(core, "scale", Vector3.ONE * 2.6, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cm, "albedo_color", Color(1.0, 0.45, 0.15, 0.9), 0.14)
	tw.tween_property(cm, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(core.queue_free)
	_chunks(p, 22, DARK_MATTER, 12.0, 0.26, Vector3.UP, 100.0, -14.0)
	_chunks(p, 10, Color(0.55, 0.25, 0.6), 9.0, 0.18, Vector3.UP, 110.0, -14.0)
	_motes(p, {"n": 26, "life": 0.7, "size": 0.12, "r": 0.4, "vmin": 4.0, "vmax": 9.0, "spread": 180.0, "add": true, "grav": Vector3(0, -3, 0), "damp": 2.0,
		"cols": [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.35, 0.1, 0.8), Color(0.4, 0.05, 0.1, 0.0)]})
	var g = _flr(p)
	_ring(g, Vector3.UP, 4.2, Color(1.0, 0.55, 0.25, 0.9), Color(DARK_MATTER.r, DARK_MATTER.g, DARK_MATTER.b, 0.8), 0.82, 0.25, 0.3)
	_pool(g, 1.8, Color(0.1, 0.03, 0.1, 0.85), Color(0.45, 0.1, 0.12, 0.9), 0.15, 2.5, 1.0, 0.0)
	_light(p, Color(1.0, 0.55, 0.25), 7.0, 9.0, 0.4)


## Bakujin no Jutsu (ref: Chino "Exploding Human") — dokunuşta mor-kara zehirli chakra iğnesi damarlara yayılır; rakip kanarsa
## beden mor hücreli kara bir maddeyle kaplanıp şişer, çatlaklarından kızıl-sarı ışık sızar ve patlar
static func bakujin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 4.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Bakujin: dokunacak kadar yakın hedef yok", Color(0.85, 0.1, 0.12))
		return
	pj.busy(c, 0.6)
	var id = "bakujin_no_jutsu"
	pj._face(c, tt)
	_ketsu_eyes(c, 1.0)
	pj.anim(c, "jab", 1.8)
	var cw = weakref(c)
	var tw = weakref(tt)
	var aura = {"n": null}
	pj.after(0.15, func():   # dokunuş: chakra aşılanır
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		x.take_hit(pj.inf(cc, id, 0.3, {"knock": 0.0, "kind": "light", "hitstop": 0.04, "pierce_guard": true}))
		x.set_meta("bakujin_by", cc.get_instance_id())
		x.set_meta("bakujin_until", Time.get_ticks_msec() + 12000)
		Combat.popup_text(x.global_position + Vector3.UP * 2.6, "Zehirli chakra!", Color(0.7, 0.1, 0.25))
		Sfx.play("seal", x.global_position, 1.2)
		var cp: Vector3 = x.global_position + Vector3.UP * 1.1 + (cc.global_position - x.global_position).normalized() * 0.35
		_nick(cp, Color(0.6, 0.15, 0.7), 0.7, 6)
		var xc: Vector3 = x.global_position
		var vm = _sweep(Color(0.75, 0.3, 0.85, 1.0), Color(0.25, 0.04, 0.3, 0.9), 0.3, false, Color(0.08, 0.0, 0.1, 0.9), 0.25)
		for k in 4:   # damarlara yayılan zehirli chakra
			var a0 = k * TAU / 4.0
			_ribbon(func(q: float) -> Vector3:
				var a = a0 + q * 2.4
				return xc + Vector3(cos(a) * 0.38, 1.1 + (q - 0.5) * 1.1 * (1.0 if k % 2 == 0 else -1.0), sin(a) * 0.38), 0.05, vm, 0.35, 0.2, 0.3, {"n": 10, "taper": 0.6})
		aura["n"] = _motes(Vector3.ZERO, {"parent": x, "local": Vector3.UP * 1.0, "loop": true, "n": 8, "life": 0.9, "size": 0.12, "r": 0.4, "vmin": 0.1, "vmax": 0.4, "expl": 0.0,
			"grav": Vector3(0, 0.5, 0), "cols": [Color(0.5, 0.1, 0.55, 0.0), Color(0.35, 0.05, 0.4, 0.8), Color(0.1, 0.0, 0.12, 0.0)]})
		_kill(aura["n"], 12.0))
	var fired = {"v": false}
	var watch = func(i, _k):   # kanarsa tetiklenir
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if fired["v"] or cc == null or x == null or not pj.live(x) or not x.has_meta("bakujin_until"):
			return
		var bleeding = (x.has_method("has_status") and x.has_status("bleed")) or (x.has_meta("last_wound") and Time.get_ticks_msec() - int(x.get_meta("last_wound")) < 400)
		if i < 3 or not bleeding:
			return
		fired["v"] = true
		Combat.popup_text(x.global_position + Vector3.UP * 2.6, "Kan tetikledi!", Color(0.2, 0.0, 0.05))
		var au = aura["n"]
		if au != null and is_instance_valid(au):
			au.queue_free()
		var m = x.get("model")
		if m and is_instance_valid(m) and m.get("overlay") != null:   # kara madde: beden şişer
			var tw0 = m.create_tween()
			tw0.tween_method(func(u: float):
				if is_instance_valid(m):
					for bn in ["UpperChest", "Chest", "Spine", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"]:
						m.overlay.bulk[bn] = lerpf(1.0, 1.9, u), 0.0, 1.0, 0.7)
			tw0.tween_callback(func():
				if is_instance_valid(m):
					for bn in ["UpperChest", "Chest", "Spine", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"]:
						m.overlay.bulk.erase(bn))
		pj.st(x, "bind", 0.75)
		# beden mor hücreli kara maddeyle kaplanır, şişer, çatlakları kızarır
		var hgt = float(x.get("height")) if x.get("height") != null else 1.8
		var ball = MeshInstance3D.new()
		ball.mesh = _sphere_mesh()
		var bm = _sm("bloat", {"heat": 0.0})
		ball.material_override = bm
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x.add_child(ball)
		ball.position = Vector3.UP * hgt * 0.55
		ball.scale = Vector3.ONE * hgt * 0.35
		var bt = ball.create_tween()
		bt.tween_property(ball, "scale", Vector3(hgt * 0.95, hgt * 1.05, hgt * 0.95), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		bt.parallel().tween_method(func(v: float): bm.set_shader_parameter("heat", v), 0.0, 1.0, 0.72)
		_kill(ball, 0.75)
		_motes(Vector3.ZERO, {"parent": x, "local": Vector3.UP * hgt * 0.5, "n": 14, "life": 0.6, "size": 0.14, "r": hgt * 0.35, "vmin": 0.0, "vmax": 0.3,
			"expl": 0.2, "grav": Vector3(0, -8, 0), "cols": [Color(0.12, 0.02, 0.12, 1.0), Color(0.05, 0.0, 0.05, 0.0)]})   # sızan kara madde
		pj.after(0.75, func():   # patlar
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if x2 == null or not is_instance_valid(x2):
				return
			var p: Vector3 = x2.global_position + Vector3.UP * 1.0
			_bakujin_blast(p)
			pj.shake(0.8)
			Sfx.play("boom", p, 0.8)
			x2.remove_meta("bakujin_until")
			if c2 == null or not pj.live(c2) or not pj.live(x2):
				return
			var mx = float(x2.get("max_hp")) if x2.get("max_hp") != null else 100.0
			var ex = pj.inf(c2, id, 1.0, {"knock": 8.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.12, "pierce_guard": true})
			ex["dmg"] = mx * 0.7   # kurbanı yok eder; Combat.cap_one_shot güçlü hedefte kırpar
			ex["execute"] = true
			x2.take_hit(ex)
			for e in pj.enemies_near(c2, p, 3.5):
				if e != x2 and is_instance_valid(e) and not e.is_dead():
					e.take_hit(pj.inf(c2, id, 1.2, {"knock": 14.0, "launch": 4.0, "kind": "heavy"})))
	pj.every(12.0, 0.1, watch, func():
		var x = tw.get_ref()
		if x != null and is_instance_valid(x) and x.has_meta("bakujin_until"):
			x.remove_meta("bakujin_until"))


## Kan sisi kümesi: taneli kızıl tabakalar (kendi gölgelendiricim), içinde yavaş düşen damlacıklar
static func _blood_haze(pos: Vector3, r: float, life: float) -> void:
	var mat = _sm("mist", {})
	_motes(pos, {"n": 12, "life": life, "size": 2.6, "r": r, "vmin": 0.1, "vmax": 0.5, "spread": 180.0, "grav": Vector3.ZERO, "damp": 0.4, "expl": 0.7,
		"s0": 0.5, "s1": 1.2, "mat": mat, "cols": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)]})
	_motes(pos + Vector3.UP * 0.8, {"n": 24, "life": life * 0.8, "size": 0.06, "r": r, "vmin": 0.0, "vmax": 0.2, "grav": Vector3(0, -0.6, 0), "damp": 0.2, "expl": 0.3,
		"s0": 1.0, "s1": 1.0, "cols": [Color(0.85, 0.08, 0.12, 0.0), Color(0.85, 0.08, 0.12, 0.9), Color(0.4, 0.02, 0.05, 0.0)]})


## Sisin içinde beliren kızıl göz parıltısı (Ketsuryūgan genjutsusu)
static func _eye_glint(pos: Vector3) -> void:
	var cam = _cam()
	var side = (cam - pos).cross(Vector3.UP).normalized()
	var m = _sweep(Color(1.0, 0.6, 0.6, 1.0), Color(0.95, 0.05, 0.1, 0.95), 0.3, true)
	for sx in [-1.0, 1.0]:
		var e: Vector3 = pos + side * 0.13 * sx
		_streak(e - side * 0.08, e + side * 0.08, 0.05, m, 0.08, 0.25, 0.3, {"n": 3, "taper": 0.0, "shape": func(q: float) -> float: return sin(PI * q)})


## Ketsumu no Jutsu — avuçtan ince kan spreyi; önünde asılı kalan taneli kızıl sis, içinde süzülen damlacıklar ve yer yer yanıp
## sönen kızıl göz parıltıları (genjutsu); yerde kan serpintisi
static func ketsumu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "ketsumu_no_jutsu"
	var tt = pj.tg(c, t, 14.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.4)
	_blood_draw(pj, c, 1.0)   # kendi bileği (yakın yaralı yoksa)
	_ketsu_eyes(c, 3.2)
	var cw = weakref(c)
	var at: Vector3 = c.global_position + d * 4.5
	var R = 5.0
	Sfx.play("wind", c.global_position, 1.2)
	_motes(pj.hand_pos(c), {"n": 60, "life": 0.6, "size": 0.07, "r": 0.1, "vmin": 6.0, "vmax": 11.0, "dir": d + Vector3.UP * 0.1, "spread": 22.0, "damp": 3.0,
		"grav": Vector3(0, -2, 0), "s0": 1.0, "s1": 0.6, "cols": [Color(0.9, 0.1, 0.14, 1.0), Color(0.6, 0.04, 0.08, 0.7), Color(0.4, 0.02, 0.05, 0.0)]})
	for k in 4:
		pj.after(k * 0.25, func():
			_blood_haze(at + Vector3.UP * 0.8 + d * (k - 1.5) * 1.2, R * 0.6, 2.6))
	_pool(at, R * 0.55, Color(0.4, 0.02, 0.05, 0.35), Color(0.6, 0.04, 0.08, 0.45), 0.8, 1.8, 1.0, 0.0)
	for k in 5:
		pj.after(0.5 + k * 0.5, func():
			_eye_glint(at + Vector3(randf_range(-R, R) * 0.45, randf_range(1.2, 2.0), randf_range(-R, R) * 0.45)))
	pj.every(3.0, 0.3, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, R):
			if not is_instance_valid(e) or e.is_dead():
				continue
			if e.has_method("lose_target"):
				e.lose_target(0.6)
			pj.st(e, "blind", 0.6)
			if i % 3 == 0:
				e.take_hit(pj.inf(cc, id, 0.25, {"knock": 0.0, "kind": "light", "bleed": 2.0, "hitstop": 0.0, "sure": true})))


# ================================================================== MITARASHI — gölge yılanları
## Zehir (mekanik aynen: burn süresi) — görsel: yeşilden mora dönen zehir damlaları
static func _venom(pj: PathJutsu, c: Node3D, e: Node3D, id: String, mul: float, dur := 4.0) -> void:
	pj.hit(c, e.global_position + Vector3.UP * e.height * 0.6, e.radius + 0.6, pj.inf(c, id, mul, {"knock": 1.0, "kind": "light", "burn": dur, "hitstop": 0.03}))
	_motes(e.global_position + Vector3.UP * e.height * 0.6, {"n": 10, "life": 0.6, "size": 0.12, "r": 0.25, "vmin": 1.0, "vmax": 2.5, "grav": Vector3(0, -6, 0),
		"s0": 1.0, "s1": 0.7, "cols": [Color(0.6, 0.85, 0.25, 1.0), Color(VENOM_DK.r, VENOM_DK.g, VENOM_DK.b, 0.8), Color(0.2, 0.05, 0.25, 0.0)]})


## Diş izi + damarlara tırmanan zehir (bacaktan yukarı sarmal çizgiler)
static func _venom_crawl(x: Node3D, deep: bool) -> void:
	var xc: Vector3 = x.global_position
	var hgt = float(x.get("height")) if x.get("height") != null else 1.8
	var vm = _sweep(Color(0.75, 0.95, 0.4, 1.0) if not deep else Color(0.8, 0.45, 0.95, 1.0), Color(VENOM.r, VENOM.g, VENOM.b, 0.85) if not deep else Color(VENOM_DK.r, VENOM_DK.g, VENOM_DK.b, 0.9),
		0.3, false, Color(0.1, 0.12, 0.04, 0.9), 0.25)
	var n = 3 if not deep else 5
	for k in n:
		var a0 = k * TAU / n + randf() * 0.5
		var top = hgt * (0.55 if not deep else 0.85)
		_ribbon(func(q: float) -> Vector3:
			var a = a0 + q * 3.0
			return xc + Vector3(cos(a) * 0.3, 0.15 + q * top, sin(a) * 0.3), 0.045, vm, 0.4, 0.3, 0.4, {"n": 12, "taper": 0.7})
	var fm = _sweep(Color(1, 1, 1, 1), Color(0.85, 0.1, 0.15, 0.95), 0.3)
	for sx in [-1.0, 1.0]:
		var fp: Vector3 = xc + Vector3.UP * 0.45 + Vector3(sx * 0.08, 0, 0)
		_streak(fp + Vector3.UP * 0.06, fp - Vector3.UP * 0.06, 0.035, fm, 0.03, 0.2, 0.2, {"n": 3})


## Senei Dokuga — ayak dibinde gölge halkası, kollardan fırlayan gerçek yılanlar; ısırıkta diş izi ve bacaktan yukarı tırmanan
## zehir çizgileri, düşen zehir damlaları (zehir sürerken ikinci ısırık morlaşır, daha yükseğe tırmanır)
static func senei_dokuga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "senei_dokuga"
	var tt = pj.tg(c, t, 12.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	_ring(_flr(c.global_position), Vector3.UP, 1.3, Color(SHADE.r, SHADE.g, SHADE.b, 0.75), Color(0.25, 0.2, 0.15, 0.4), 0.55, 0.2, 0.5)
	for k in 2:
		var sn = pj.sleeve_snake(c, k == 0, tt if tt and pj.live(tt) else null, k, 2, d * 8.0)
		sn.extend(0.22)
		pj.after(0.75, func():
			if is_instance_valid(sn):
				sn.retract(0.25))
	Sfx.play("whoosh", c.global_position, 0.8)
	pj.after(0.25, func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var deep = x.has_meta("anko_poison_until") and float(x.get_meta("anko_poison_until")) > Game.now()
		Sfx.play("bite", x.global_position, 0.9)
		_venom_crawl(x, deep)
		_venom(pj, cc, x, id, 1.0 if not deep else 1.8, 6.0)
		x.set_meta("anko_poison_until", Game.now() + 6.0)
		pj.st(x, "slow", 3.0)
		x.take_hit(pj.inf(cc, id, 0.7 if not deep else 1.2, {"knock": 2.0, "kind": "heavy", "hitstop": 0.06})))


## Kunai modeli (uç -Z): çelik bıçak, sargılı sap, halka
static func _kunai_mesh() -> ArrayMesh:
	if not _cache.has("mesh:kunai"):
		var b = MB.new()
		b.add("prism", Vector3(0, 0, -0.18), Vector3(0.09, 0.02, 0.3), STEEL, Vector3(-90, 0, 0), 4)
		b.add("cyl", Vector3(0, 0, 0.08), Vector3(0.035, 0.22, 0.035), Color(0.25, 0.2, 0.18), Vector3(90, 0, 0), 6)
		b.add("torus", Vector3(0, 0, 0.23), Vector3(0.08, 0.08, 0.08), Color(0.3, 0.3, 0.32), Vector3(90, 0, 0), 8)
		var m = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.6
		m.roughness = 0.35
		_cache["mesh:kunai"] = b.build(m)
	return _cache["mesh:kunai"]


## Kushi Kunai — dango şişi: üç kunai tek hatta; aralarında gümüş şiş çizgisi; ilki rakibi çiviler (ayak dibine saplanan kunai
## ve toz halkası), arkadakiler aynı noktaya metal kıvılcımıyla saplanır
static func kushi_kunai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "kushi_kunai"
	var tt = pj.tg(c, t, 26.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 2.0)
	var cw = weakref(c)
	for k in 3:
		pj.after(0.05 + k * 0.07, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var from: Vector3 = pj.hand_pos(cc)
			var kn = Node3D.new()
			var km = MeshInstance3D.new()
			km.mesh = _kunai_mesh()
			kn.add_child(km)
			var dirv: Vector3 = pj.aim_at(cc, tt, from)
			_streak(from, from + dirv * 7.0, 0.035, _sweep(Color(1, 1, 1, 0.95), Color(0.7, 0.75, 0.82, 0.6), 0.4), 0.14, 0.0, 0.18, {"n": 6, "tail": 0.6})
			var pr = pj.shot(cc, from, dirv, 48.0, kn, pj.inf(cc, id, 0.45, {"knock": 1.0, "kind": "light", "bleed": 2.0, "hitstop": 0.03}), tt, false, 1.0, func(p, h):
				_nick(p, Color(1, 0.95, 0.8), 0.6, 4)
				if k == 0 and h and is_instance_valid(h) and pj.live(h):
					pj.st(h, "bind", 0.9)   # ilki çiviler
					var g: Vector3 = _flr(h.global_position)
					var pin = MeshInstance3D.new()
					pin.mesh = _kunai_mesh()
					_put(pin, g + Vector3.UP * 0.12 + dirv * 0.25)
					pin.look_at(pin.global_position + Vector3(dirv.x, -1.4, dirv.z).normalized(), Vector3.UP if absf(dirv.y) < 0.9 else Vector3.FORWARD)
					_kill(pin, 0.9)
					_ring(g, Vector3.UP, 0.8, Color(0.75, 0.65, 0.5, 0.7), Color(0.55, 0.45, 0.35, 0.4), 0.6, 0.15, 0.4)
					_chunks(g, 5, EARTH, 3.0, 0.1))
			pr.radius = 0.3)
	Sfx.play("throw_kunai", c.global_position, 1.0)


## Jakage Shibari — rakibin altında dalgalanan kara gölge havuzu; havuzun kenarından toprağı yararak dört gerçek yılan çıkar,
## sıkıştıkça daralan boğum halkaları ve zehir, sonunda ısırık
static func jakage_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "jakage_shibari"
	var tt = pj.tg(c, t, 16.0)
	pj._face(c, tt)
	pj.anim(c, "seal", 1.4)
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var at: Vector3 = pj.gp(tt.global_position)
	var sp = _sm("pool", {"col": Color(SHADE.r, SHADE.g, SHADE.b, 0.85), "rim": Color(0.3, 0.18, 0.35, 0.9), "seed": randf() * 20.0, "gloss": 0.0, "wave": 3.0})
	_plate(_flr(at), Vector3.UP, 2.1, sp, 0.25, 2.3, 0.4)
	for k in 4:
		var a = k * TAU / 4.0 + 0.4
		var p0: Vector3 = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 1.6)
		var sn = SleeveSnake.new()
		sn.anchor = func(): return p0 + Vector3.UP * 0.02
		sn.aim_dir = (at - p0).normalized() + Vector3.UP * 0.6
		sn.target = tt
		sn.free_to = at + Vector3.UP
		sn.side = (k - 1.5) * 0.15
		sn.lift = 0.3
		sn.phase = k * 1.3
		sn.coil_y0 = 0.1 + k * 0.12
		sn.coil_y1 = sn.coil_y0 + 0.35
		sn.coil_turns = 1.5
		pj.get_tree().current_scene.add_child(sn)
		sn.set_head(pj.snake_head(Color(0.24, 0.26, 0.17), 0.28))
		sn.extend(0.3 + k * 0.05)
		pj.after(2.4, func():
			if is_instance_valid(sn):
				sn.retract(0.3))
		_cracks(p0, 0.8, 4, 2.5, DIRT)
		_chunks(p0, 5, EARTH, 3.5, 0.12, Vector3.UP, 35.0)
	Sfx.play("whoosh", at, 0.6)
	pj.after(0.4, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj.st(x, "bind", 2.0)
		_venom(pj, cc, x, id, 0.8, 4.0)
		var xc: Vector3 = x.global_position
		var lm = _sweep(Color(0.6, 0.62, 0.45, 0.9), Color(0.24, 0.26, 0.17, 0.9), 0.35, false, Color(0.06, 0.06, 0.03, 0.9), 0.25)
		for h in [0.35, 0.75, 1.15]:   # sıkışan boğum halkaları
			var hh: float = h
			var ring_m = _ribbon(func(q: float) -> Vector3:
				var a = q * TAU
				return Vector3(cos(a) * 0.55, hh, sin(a) * 0.55), 0.06, lm, 0.15, 0.3, 0.3, {"n": 20, "taper": 0.0, "tail": 1.0,
					"wfn": func(_q: float, _p: Vector3) -> Vector3: return Vector3.UP})
			ring_m.global_position = xc
			var rt = ring_m.create_tween()
			rt.tween_property(ring_m, "scale", Vector3(0.6, 1.0, 0.6), 0.3)
		x.take_hit(pj.inf(cc, id, 0.6, {"knock": 0.0, "kind": "heavy", "hitstop": 0.05})))
	pj.after(2.3, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc != null and x != null and pj.live(cc) and pj.live(x):
			Sfx.play("bite", x.global_position, 0.8)
			_venom_crawl(x, true)
			_nick(x.global_position + Vector3.UP * 1.0, VENOM, 0.8, 5)
			x.take_hit(pj.inf(cc, id, 0.9, {"knock": 4.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.08})))


## Hebi Nukegara — soluk deri kabuk yerinde kalır (gerçek kopya), dökülen pullar süzülür; yerin altında kayışın kabaran toprak
## sırtı ve oluk izi; rakibin arkasında toprağı yararak çıkış, gerçek yılanla ısırık
static func hebi_nukegara(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.9)
	var id = "hebi_nukegara"
	var p0: Vector3 = c.global_position
	var shell = pj.decoy(c, p0, 3.0)
	if shell:   # soluk, yarı saydam deri kabuğu
		var sm = shell.get("model")
		if sm and is_instance_valid(sm):
			var ov = StandardMaterial3D.new()
			ov.albedo_color = Color(0.85, 0.82, 0.7, 0.55)
			ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ov.roughness = 0.4
			for mi in (sm as Node).find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = ov
	_motes(p0 + Vector3.UP * 1.0, {"n": 16, "life": 1.4, "size": 0.09, "r": 0.45, "vmin": 0.3, "vmax": 1.2, "spread": 120.0, "grav": Vector3(0, -1.2, 0), "damp": 1.0,
		"quad": true, "spin": 300.0, "s0": 1.0, "s1": 1.0, "cols": [SKIN, Color(SKIN.r, SKIN.g, SKIN.b, 0.8), Color(SKIN.r, SKIN.g, SKIN.b, 0.0)]})   # kopan deri pulları
	if tt == null:
		return
	var back: Vector3 = tt.global_position - p0
	back.y = 0
	back = back.normalized()
	var p1: Vector3 = pj.gp(tt.global_position + back * 1.4)
	var sd = back.cross(Vector3.UP).normalized()
	_ribbon(func(q: float) -> Vector3: return _flr(p0.lerp(p1, q) + sd * sin(q * 12.0) * 0.25) + Vector3.UP * 0.015, 0.3,
		_sweep(Color(0.25, 0.19, 0.13, 0.9), Color(0.45, 0.36, 0.26, 0.8), 0.45, false, Color(0.12, 0.09, 0.06, 0.8), 0.2), 0.15, 1.4, 0.6,
		{"n": 20, "taper": 0.3, "wfn": func(_q: float, _p: Vector3) -> Vector3: return sd})   # yerin altından kayış oluğu
	var hemi = MB.new()
	hemi.add("hemi", Vector3.ZERO, Vector3(0.7, 0.35, 0.9), EARTH.darkened(0.1))
	var lmat = StandardMaterial3D.new()
	lmat.vertex_color_use_as_albedo = true
	lmat.roughness = 1.0
	var hm = hemi.build(lmat)
	for k in 5:   # toprak sırtı kabarıp söner
		var u = (k + 0.5) / 5.0
		var hp: Vector3 = _flr(p0.lerp(p1, u) + sd * sin(u * 12.0) * 0.25)
		var lump = MeshInstance3D.new()
		lump.mesh = hm
		_put(lump, hp - Vector3.UP * 0.3)
		lump.look_at(hp + back - Vector3.UP * 0.3, Vector3.UP)
		var lt = lump.create_tween()
		lt.tween_interval(k * 0.025)
		lt.tween_property(lump, "position:y", hp.y, 0.06)
		lt.tween_interval(0.25)
		lt.tween_property(lump, "position:y", hp.y - 0.35, 0.35)
		lt.tween_callback(lump.queue_free)
	c.global_position = p1
	if c is CharacterBody3D:
		c.velocity = Vector3.ZERO
	pj._face(c, tt)
	_chunks(p1, 10, EARTH, 6.0, 0.18, Vector3.UP, 40.0)
	_cracks(p1, 1.0, 5, 2.0, DIRT)
	_ring(_flr(p1), Vector3.UP, 1.2, Color(0.6, 0.5, 0.38, 0.7), Color(0.4, 0.32, 0.24, 0.4), 0.6, 0.2, 0.4)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.15, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var sn = pj.sleeve_snake(cc, true, x, 0, 1, cc.face_dir() * 4.0)
		sn.extend(0.15)
		pj.after(0.5, func():
			if is_instance_valid(sn):
				sn.retract(0.2))
		Sfx.play("bite", x.global_position, 0.9)
		_venom(pj, cc, x, id, 1.0, 4.0)
		_venom_crawl(x, false)
		x.take_hit(pj.inf(cc, id, 1.0, {"knock": 9.0, "kind": "heavy", "hitstop": 0.08, "pierce_guard": true, "dir": -back})))


# ================================================================== NAMIKAZE — Hiraishin / Raikō / Rasengan
## Mühür formülü parlaması (yerde ya da havada kameraya dönük)
static func _seal_flash(pos: Vector3, nrm: Vector3, r: float, hold := 0.08, fade := 0.3) -> void:
	var m = _sm("seal", {"seed": randf() * 10.0, "spin": 0.6})
	_plate(pos, nrm, r, m, 0.06, hold, fade)


## Hiraishin işareti: hedefin göğsünde formül belirir (dur sn), hedefle birlikte hareket eder
static func _mark_glyph(x: Node3D, toward: Vector3, dur: float) -> void:
	var m = _sm("seal", {"seed": randf() * 10.0, "spin": 0.0})
	var nrm = toward - x.global_position
	nrm.y = 0
	if nrm.length() < 0.01:
		nrm = Vector3.FORWARD
	var mi = _plate(x.global_position + Vector3.UP * 1.1 + nrm.normalized() * 0.3, nrm.normalized(), 0.35, m, 0.08, dur, 0.4, x)
	mi.set_meta("c5", true)


## Sarı flaş ardıl görüntüsü: ayaktan başa dikey sarı kıymık, yukarı uçuşan kıvılcımlar
static func _afterimage(pos: Vector3) -> void:
	var m = _sweep(Color(1, 1, 0.9, 0.95), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.8), 0.3, true)
	_streak(pos, pos + Vector3.UP * 1.9, 0.6, m, 0.03, 0.02, 0.2, {"n": 4, "taper": 0.0, "shape": func(q: float) -> float: return 0.4 + 0.6 * sin(PI * q)})
	_motes(pos + Vector3.UP * 0.9, {"n": 12, "life": 0.35, "size": 0.09, "r": 0.4, "vmin": 1.0, "vmax": 3.0, "spread": 50.0, "add": true, "quad": true, "spin": 200.0,
		"cols": [BOLT_W, Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.0)]})


## İki nokta arası şimşek-sarısı zikzak iz (ışınlanma hattı)
static func _bolt_line(a: Vector3, b: Vector3, w := 0.12) -> void:
	var sdv = randf() * 50.0
	var dv = b - a
	if dv.length() < 0.2:
		return
	var sd = dv.cross(Vector3.UP).normalized()
	if sd.length() < 0.1:
		sd = Vector3.RIGHT
	var up = sd.cross(dv).normalized()
	var amp = clampf(dv.length() * 0.06, 0.1, 0.5)
	var path = func(q: float) -> Vector3:
		var z = floor(q * 9.0)
		var j1 = fmod(sin(z * 12.9898 + sdv) * 43758.5453, 1.0)
		var j2 = fmod(sin(z * 78.233 + sdv) * 12345.678, 1.0)
		return a.lerp(b, q) + (sd * j1 + up * j2) * amp * sin(PI * q)
	_ribbon(path, w * 2.2, _sweep(Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.7), Color(1.0, 0.6, 0.1, 0.4), 0.4, true), 0.04, 0.03, 0.18, {"n": 18, "taper": 0.4})
	_ribbon(path, w, _sweep(Color(1, 1, 0.95, 1.0), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.95), 0.45, false, Color(0.45, 0.28, 0.0, 0.8), 0.15), 0.04, 0.03, 0.18, {"n": 18, "taper": 0.4})


## Sarı flaşla bir noktaya ışınlan (mekanik oyunun Hiraishin sıçrayışıyla aynı: yere/havaya, hız sıfır, hedefe dön, ses)
static func _flash_hop(who: Node3D, p: Vector3, tgt: Node3D, ground := true) -> void:
	var a: Vector3 = who.global_position
	_afterimage(a)
	var to = p
	if ground:
		to.y = Game.ground_height(to.x, to.z)
	who.global_position = to
	if who is CharacterBody3D:
		who.velocity = Vector3.ZERO
	if tgt and is_instance_valid(tgt) and "facing" in who:
		var d = tgt.global_position - to
		d.y = 0
		if d.length() > 0.01:
			who.facing = atan2(-d.x, -d.z)
			if who.get("model"):
				who.model.rotation.y = who.facing
	Sfx.play("whoosh", to, 1.6, 0.5)
	_bolt_line(a + Vector3.UP * 1.0, to + Vector3.UP * 1.0)
	if ground:
		_seal_flash(Vector3(to.x, Game.jutsu_floor(to.x, to.z) + 0.05, to.z), Vector3.UP, 1.0)
	else:
		_seal_flash(to + Vector3.UP * 1.0, (_cam() - to).normalized(), 0.8)
	_light(to + Vector3.UP, BOLT_Y, 2.2, 5.0, 0.2)


## Rasengan düğümü: girdaplı küre + üç eğik yörünge halkası (döner)
static func _rasen_node(size: float) -> Node3D:
	var root = Node3D.new()
	var core = MeshInstance3D.new()
	core.mesh = _sphere_mesh()
	core.material_override = _sm("orb", {})
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * size * 0.9
	root.add_child(core)
	var rm = _flat(Color(0.85, 0.95, 1.0, 0.7), true)
	for k in 3:
		var piv = Node3D.new()
		root.add_child(piv)
		piv.rotation = Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2))
		var ring = MeshInstance3D.new()
		var tm = TorusMesh.new()
		tm.inner_radius = 0.56
		tm.outer_radius = 0.6
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3.ONE * size
		piv.add_child(ring)
	return root


## Yörünge halkalarını döndürür (düğüm sahnedeyken çağrılır: tween ağaç ister)
static func _rasen_spin(root: Node3D) -> void:
	var k = 0
	for piv in root.get_children():
		if piv.get_child_count() == 0:
			continue
		var ring = piv.get_child(0)
		if not (ring is MeshInstance3D) or not ((ring as MeshInstance3D).mesh is TorusMesh):
			continue
		var tw = Game.safe_loops(ring.create_tween())
		tw.tween_property(ring, "rotation:y", TAU, 0.22 + k * 0.05).from(0.0)
		k += 1


## Elde Rasengan (KeyedCombos'taki gibi el kemiğine): dur sn, büyüyerek belirir; uzun yüklemede çevreden mavi zerre çeker
static func _rasen_hand(pj: PathJutsu, c: Node3D, right: bool, size: float, dur: float) -> Node3D:
	var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
	if ba == null:
		return null
	var r = _rasen_node(size)
	ba.add_child(r)
	_rasen_spin(r)
	r.position = Vector3(0, 0.12, 0.1)
	r.scale = Vector3.ONE * 0.2
	var tw = r.create_tween()
	tw.tween_property(r, "scale", Vector3.ONE, minf(0.25, dur * 0.5))
	if dur >= 0.5:
		_motes(Vector3.ZERO, {"parent": r, "n": 16, "life": 0.3, "size": 0.08, "r": size * 1.6, "vmin": 0.0, "vmax": 0.1, "radial": -12.0, "grav": Vector3.ZERO, "add": true,
			"cols": [Color(RASEN.r, RASEN.g, RASEN.b, 0.0), Color(0.85, 0.95, 1.0, 0.9), Color(RASEN.r, RASEN.g, RASEN.b, 0.0)]})
	pj.free_after(dur, ba)
	return r


## Rasengan çarpması: küre şişip çöker, çevresinde açılan sarmal rüzgâr çizgileri, darbe yönüne dik öğüten halka
static func _rasen_burst(at: Vector3, s: float, dir := Vector3.ZERO) -> void:
	var r = _rasen_node(s)
	_put(r, at)
	_rasen_spin(r)
	var tw = r.create_tween()
	tw.tween_property(r, "scale", Vector3.ONE * 1.6, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "scale", Vector3.ONE * 0.05, 0.14)
	tw.tween_callback(r.queue_free)
	var nrm = dir.normalized() if dir != Vector3.ZERO else Vector3.UP
	var b = _basis_facing(nrm)
	var wm = _sweep(Color(1, 1, 1, 0.95), Color(RASEN.r, RASEN.g, RASEN.b, 0.8), 0.35, false, Color(0.1, 0.25, 0.7, 0.8), 0.18)
	for k in 6:
		var a0 = TAU * k / 6.0
		_ribbon(func(q: float) -> Vector3:
			var a = a0 + q * 3.5
			var rr = (0.5 + q * 2.0) * s
			return at + (b.x * cos(a) + b.y * sin(a)) * rr + b.z * sin(q * 6.0 + k) * 0.15 * s, 0.1 * s, wm, 0.22, 0.0, 0.2, {"n": 14, "taper": 0.8, "tail": 0.7})
	if dir != Vector3.ZERO:
		_ring(at, nrm, 2.0 * s, Color(0.9, 0.97, 1.0, 0.9), Color(RASEN.r, RASEN.g, RASEN.b, 0.7), 0.7, 0.28, 0.25, 0.35)
	_light(at, RASEN, 3.0 * s, 6.0 * s, 0.3)
	Sfx.play("rasengan", at, 1.0)


## Rasengan'ın yere gömüldüğü krater: çatlaklar, kopan kaya, alçak toz halkası, çökük iz
static func _crater(at: Vector3, r: float) -> void:
	var g = _flr(at)
	_cracks(g, r, 8, 3.0, Color(0.12, 0.09, 0.07, 0.95))
	_pool(g, r * 0.4, Color(0.18, 0.14, 0.11, 0.9), Color(0.42, 0.33, 0.24, 0.9), 0.12, 2.5, 0.8, 0.0)
	_chunks(g, int(r * 4.0), EARTH, r * 2.2, 0.24, Vector3.UP, 45.0)
	_motes(g + Vector3.UP * 0.2, {"n": 22, "life": 1.0, "size": 0.9, "r": r * 0.3, "vmin": r * 0.6, "vmax": r * 1.2, "dir": Vector3.UP, "spread": 85.0, "grav": Vector3(0, -0.5, 0),
		"damp": 2.5, "cols": [Color(0.68, 0.58, 0.46, 0.7), Color(0.6, 0.52, 0.42, 0.0)]})
	_ring(g, Vector3.UP, r * 1.1, Color(0.75, 0.65, 0.5, 0.6), Color(0.6, 0.5, 0.38, 0.3), 0.8, 0.3, 0.4)


## Hiraishin: Ren no Dan — işaretle birlikte göğüste formül belirir, yukarı tekme yayı; havada arkasına zikzak sarı ışınlanma,
## aşağı öğüten Rasengan; düşen rakibin yanına yeniden ışınlanma, dev Rasengan krateri
static func hiraishin_ren_no_dan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Hiraishin: Ren no Dan: işaret konacak hedef yok", Color(1.0, 0.9, 0.35))
		return
	pj.busy(c, 1.6)
	var id = "hiraishin_ren_no_dan"
	var cw = weakref(c)
	var tw = weakref(tt)
	if c.global_position.distance_to(tt.global_position) > 2.0:
		_flash_hop(c, tt.global_position - pj._face(c, tt) * 1.1, tt)
	pj._face(c, tt)
	pj._kick_pose(c, 0.25)
	pj.after(0.12, func():   # işaret + tekme
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		x.apply_status("marked", 12.0)
		x.set_meta("hiraishin_by", cc.get_instance_id())
		_mark_glyph(x, cc.global_position, 1.4)
		var fd: Vector3 = cc.face_dir()
		_arc(cc.global_position + Vector3.UP * 0.9, fd, Vector3.UP, 1.1, -0.9, 1.5, 0.22, _sweep(Color(1, 1, 0.9, 1), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.9), 0.35, true),
			0.07, 0.0, 0.18, {"n": 12, "tail": 0.8})
		_nick(x.global_position + Vector3.UP * 0.9, BOLT_Y, 0.9)
		Sfx.play("punch", x.global_position, 1.0)
		x.take_hit(pj.inf(cc, id, 0.45, {"knock": 0.0, "launch": 11.0, "kind": "heavy", "hitstop": 0.05})))
	_rasen_hand(pj, c, true, 0.55, 0.75)
	pj.after(0.45, func():   # havada arkasına
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var bd: Vector3 = -pj._face(cc, x)
		_flash_hop(cc, x.global_position + bd * 0.0 + Vector3.UP * 1.2 - cc.face_dir() * 1.0, x, false)
		pj.anim(cc, "push", 1.8)
		_rasen_burst(x.global_position + Vector3.UP * 1.0, 0.7, Vector3.DOWN)
		x.take_hit(pj.inf(cc, id, 1.0, {"knock": 0.0, "launch": -14.0, "kind": "heavy", "hitstop": 0.08}))
		if x is CharacterBody3D:
			x.velocity = Vector3.DOWN * 16.0)
	pj.after(0.5, func():
		var cc = cw.get_ref()
		if cc != null and pj.live(cc):
			_rasen_hand(pj, cc, true, 0.8, 0.6))
	pj.after(1.0, func():   # yere düşen rakibin yanına: yüklü Rasengan yere gömer
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var at: Vector3 = pj.gp(x.global_position if x != null and pj.live(x) else cc.global_position + cc.face_dir() * 2.0)
		_flash_hop(cc, at - cc.face_dir() * 1.0, x)
		pj.anim(cc, "push", 1.6)
		_rasen_burst(at + Vector3.UP * 0.5, 1.3, Vector3.UP)
		_crater(at, 6.0 * 0.55)
		pj.shake(0.9)
		Sfx.play("boom", at, 0.8)
		pj.hit(cc, at + Vector3.UP * 0.6, 3.4, pj.inf(cc, id, 2.3, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "stun": 0.8, "hitstop": 0.12})))


## Raikō — Hiraishin kunaisiyle ince sarı kesikler, dizden diz altına yatay dönen tekme halkaları, çeneye yükselen diz izi,
## tepeden inen topukla dikey yay ve yerde şok halkası; her adımda ayak dibinde şimşek kıymıkları
static func raiko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.7)
	var id = "raiko"
	if tt and tt.global_position.distance_to(c.global_position) > 2.2:   # uzaktaysa sarı flaşla yanına
		_flash_hop(c, tt.global_position - pj._face(c, tt) * 1.2, tt)
	pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var steps = [["slash_a", 0.1, 0.32, 0], ["slash_b", 0.28, 0.32, 0], ["kick", 0.5, 0.4, 1], ["kick", 0.7, 0.4, 1], ["knee", 0.98, 0.7, 2], ["heel", 1.3, 1.2, 3]]
	var slash_m = _sweep(Color(1, 1, 0.92, 1), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.9), 0.3, false, Color(0.4, 0.25, 0.0, 0.85), 0.16)
	var kick_m = _sweep(Color(1, 0.98, 0.85, 0.95), Color(1.0, 0.7, 0.2, 0.75), 0.3, true)
	for k in steps.size():
		pj.after(float(steps[k][1]), func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var f: Vector3 = pj._face(cc, x) if x != null and pj.live(x) else cc.face_dir()
			if x != null and pj.live(x) and cc is CharacterBody3D and int(steps[k][3]) < 2:
				cc.velocity = f * clampf((cc.global_position.distance_to(x.global_position) - 1.2) / 0.12, 0.0, 14.0)
			var kind = int(steps[k][3])
			var sv: Vector3 = f.cross(Vector3.UP).normalized()
			var cp: Vector3 = cc.global_position
			if kind == 0:
				pj.anim(cc, String(steps[k][0]), 2.6)
				var tilt = 0.5 if k == 0 else -0.5
				_arc(cp + Vector3.UP * 1.15, f, (sv * (1.0 if k == 0 else -1.0) + Vector3.UP * tilt).normalized(), 1.0, -1.3, 1.3, 0.16, slash_m, 0.06, 0.0, 0.16, {"n": 12, "tail": 0.85})
				Sfx.play("slash", cc.global_position, 1.2 + k * 0.05)
			elif kind == 1:   # dönen tekme
				pj._kick_pose(cc, 0.2)
				if cc.get("model"):
					var mt = cc.model.create_tween()
					mt.tween_property(cc.model, "rotation:y", TAU, 0.18).from(0.0)
					mt.tween_callback(func(): cc.model.rotation.y = 0.0)
				var hh = 0.7 if k == 2 else 1.1
				_arc(cp + Vector3.UP * hh, f, sv, 1.15, 0.0, TAU * 0.95, 0.24, kick_m, 0.16, 0.0, 0.18, {"n": 22, "tail": 0.6,
					"wfn": func(_q: float, _p: Vector3) -> Vector3: return Vector3.UP})
				Sfx.play("punch", cc.global_position, 1.1)
			elif kind == 2:   # diz çeneye: sıçrar
				if cc is CharacterBody3D:
					cc.velocity = Vector3.UP * 8.0 + f * 2.0
				pj.anim(cc, "hook", 2.0)
				_streak(cp + Vector3.UP * 0.6 + f * 0.6, cp + Vector3.UP * 2.6 + f * 0.9, 0.3, kick_m, 0.08, 0.0, 0.2, {"n": 6, "taper": 0.8})
				Sfx.play("punch", cc.global_position, 0.9)
			else:   # dönen topuk tekmesi: yukarıdan aşağı
				if x != null and pj.live(x):
					_flash_hop(cc, x.global_position + Vector3.UP * 2.0 - f * 0.8, x, false)
				pj._kick_pose(cc, 0.3)
				var ip: Vector3 = (x.global_position if x != null and pj.live(x) else cc.global_position) + Vector3.UP * 1.6
				_arc(ip + Vector3.UP * 0.4 - f * 0.3, Vector3.UP, f, 1.3, -0.3, 2.4, 0.32, slash_m, 0.08, 0.0, 0.22, {"n": 14, "tail": 0.8})
				_nick(ip, BOLT_Y, 1.4, 8)
				var gx: Vector3 = _flr(x.global_position if x != null and pj.live(x) else cc.global_position)
				_ring(gx, Vector3.UP, 2.4, Color(1.0, 0.95, 0.7, 0.85), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.5), 0.8, 0.2, 0.25, 0.3)
				_cracks(gx, 1.4, 5, 1.6)
				pj.shake(0.6)
				Sfx.play("punch", cc.global_position, 0.7)
			for z in 2:   # ayak dibinde şimşek kıymıkları
				var zp: Vector3 = _flr(cc.global_position) + Vector3.UP * 0.1
				var zd = Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)).normalized()
				_bolt_line(zp, zp + zd * 0.7, 0.04)
			var p = cc.global_position + Vector3.UP * (1.6 if kind >= 2 else 1.1) + f * 1.2
			var info = pj.inf(cc, id, float(steps[k][2]), {"knock": 2.0, "kind": "light" if kind < 2 else "heavy", "hitstop": 0.04 if kind < 2 else 0.08, "bleed": 2.0 if kind == 0 else 0.0})
			if kind == 2:
				info["launch"] = 8.0
			if kind == 3:
				info["launch"] = -14.0
				info["stun"] = 0.8
			var hs = pj.hit(cc, p, 2.2 if kind < 3 else 2.8, info)
			if not hs.is_empty():
				_nick(hs[0].global_position + Vector3.UP * 1.0, BOLT_Y if kind > 0 else BOLT_W, 0.7 if kind < 2 else 1.1))


## Hiraishin kunaisi düğümü (uç -Z): kunai + sapta parlayan formül kâğıdı, arkasında sarı iz zerreleri
static func _hira_knife(trail := true) -> Node3D:
	var n = Node3D.new()
	var km = MeshInstance3D.new()
	km.mesh = _kunai_mesh()
	n.add_child(km)
	for sx in [-1.0, 1.0]:   # üç kollu: yan kollar
		var pr = MeshInstance3D.new()
		var cm = PrismMesh.new()
		cm.size = Vector3(0.05, 0.16, 0.012)
		pr.mesh = cm
		var sm = StandardMaterial3D.new()
		sm.albedo_color = STEEL
		sm.metallic = 0.6
		sm.roughness = 0.35
		pr.material_override = sm
		pr.position = Vector3(0.07 * sx, 0, -0.06)
		pr.rotation = Vector3(-PI * 0.5, 0, -0.6 * sx)
		n.add_child(pr)
	var tag = MeshInstance3D.new()
	var tq = BoxMesh.new()
	tq.size = Vector3(0.05, 0.004, 0.13)
	tag.mesh = tq
	tag.material_override = _flat(Color(1.0, 0.95, 0.7, 1.0))
	tag.position = Vector3(0, 0.03, 0.08)
	n.add_child(tag)
	var glow = MeshInstance3D.new()
	var gq = BoxMesh.new()
	gq.size = Vector3(0.12, 0.04, 0.2)
	glow.mesh = gq
	glow.material_override = _flat(Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.45), true)
	glow.position = tag.position
	n.add_child(glow)
	if trail:
		_motes(Vector3.ZERO, {"parent": n, "loop": true, "n": 24, "life": 0.25, "size": 0.1, "r": 0.04, "vmin": 0.0, "vmax": 0.1, "expl": 0.0, "add": true, "grav": Vector3.ZERO,
			"cols": [Color(1, 1, 0.85, 0.9), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.0)]})
	return n


## Kiiroi Senkō — yukarı açılan mavi sarmal Rasengan savuruşu; işaretli kunai sarı izle rakibin arkasına; havada formül
## parlayarak belirip sırtına büyüyen dev Rasengan, yere inen dikey öğütme ve krater
static func kiiroi_senko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.55)
	var id = "kiiroi_senko"
	pj._jump_at(c, tt, 0.0, 12.0 if tt and tt.global_position.distance_to(c.global_position) > 2.0 else 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	_rasen_hand(pj, c, true, 0.6, 0.3)
	pj.after(0.25, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj.anim(cc, "push", 1.8)
		var p = cc.global_position + Vector3.UP * 1.1 + cc.face_dir() * 1.1
		_rasen_burst(p, 0.6, Vector3.UP)
		var hs = pj.hit(cc, p, 2.0, pj.inf(cc, id, 1.2, {"knock": 3.0, "launch": 14.0, "kind": "heavy", "hitstop": 0.08}))
		if not hs.is_empty():
			_nick(hs[0].global_position + Vector3.UP, RASEN, 1.0))
	var mark = {"p": Vector3.ZERO}
	pj.after(0.5, func():   # arkasına kunai
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj.anim(cc, "throw", 2.2)
		mark["p"] = x.global_position + Vector3.UP * 1.0 + cc.face_dir() * 1.6
		var from: Vector3 = pj.hand_pos(cc)
		var to: Vector3 = mark["p"]
		var kn = _hira_knife()
		_put(kn, from)
		if from.distance_to(to) > 0.05:
			kn.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.FORWARD)
		var ktw = kn.create_tween()
		ktw.tween_property(kn, "global_position", to, 0.15)
		ktw.tween_callback(func(): _seal_flash(to, (_cam() - to).normalized(), 0.45, 0.25, 0.3))
		ktw.tween_interval(0.25)
		ktw.tween_callback(kn.queue_free)
		_streak(from, to, 0.05, _sweep(Color(1, 1, 0.9, 0.9), Color(BOLT_Y.r, BOLT_Y.g, BOLT_Y.b, 0.6), 0.4, true), 0.15, 0.0, 0.2, {"n": 6, "tail": 0.7})
		Sfx.play("throw_kunai", cc.global_position, 1.3))
	pj.after(0.62, func():
		var cc = cw.get_ref()
		if cc != null and pj.live(cc):
			_rasen_hand(pj, cc, true, 0.9, 0.5))
	pj.after(0.8, func():   # ışınlanır, sırtına dev Rasengan
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x) or mark["p"] == Vector3.ZERO:
			return
		_flash_hop(cc, mark["p"], x, false)
		pj.anim(cc, "push", 1.6)
		var p: Vector3 = x.global_position + Vector3.UP * 1.0
		_rasen_burst(p, 1.4, Vector3.DOWN)
		var wm = _sweep(Color(1, 1, 1, 0.9), Color(RASEN.r, RASEN.g, RASEN.b, 0.7), 0.35, true)
		for k in 4:   # aşağı çakılış: dikey öğütme çizgileri
			var o = Vector3(cos(k * TAU / 4.0), 0, sin(k * TAU / 4.0)) * 0.6
			_streak(p + o + Vector3.UP * 1.2, pj.gp(p) + o * 1.4, 0.14, wm, 0.1, 0.0, 0.2, {"n": 6, "taper": 0.7})
		pj.shake(0.7)
		x.take_hit(pj.inf(cc, id, 3.0, {"knock": 6.0, "launch": -16.0, "kind": "heavy", "hitstop": 0.12, "dir": -cc.face_dir()}))
		if x is CharacterBody3D:
			x.velocity = Vector3.DOWN * 22.0
		pj.after(0.3, func():
			var x2 = tw.get_ref() if tw else null
			var at: Vector3 = pj.gp(x2.global_position if x2 != null and is_instance_valid(x2) else p)
			_crater(at, 4.5 * 0.55)))


## Jikūkan Ninjutsu: Shinsoku — formül kâğıdı parlayan kunai sarı izle uçar; isabette rakibin göğsünde formül, kunaiye
## şimşek-sarısı hattan ışınlanıp arkasından çapraz kızıl-sarı kesik
static func jikukan_ninjutsu_shinsoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.85)
	var id = "jikukan_ninjutsu_shinsoku"
	var _d = pj._face(c, tt)
	pj.anim(c, "throw", 1.8)
	var cw = weakref(c)
	var from = pj.hand_pos(c)
	_seal_flash(from, (_cam() - from).normalized(), 0.3, 0.05, 0.2)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 44.0, _hira_knife(), pj.inf(c, id, 0.7, {"knock": 1.0, "kind": "light", "bleed": 2.0}), tt, false, 1.2, func(p, h):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if h and is_instance_valid(h) and h.has_method("apply_status"):
			h.apply_status("marked", 12.0)
			h.set_meta("hiraishin_by", cc.get_instance_id())
			_mark_glyph(h, cc.global_position, 0.6)
		_nick(p, BOLT_Y, 0.6, 4)
		var hw = weakref(h) if h else null
		pj.after(0.12, func():   # kunainin mührüne ışınlanır, arkasından saplar
			var c2 = cw.get_ref()
			var x = hw.get_ref() if hw else null
			if c2 == null or not pj.live(c2):
				return
			if x != null and pj.live(x):
				var back: Vector3 = x.global_position + (x.global_position - c2.global_position).normalized() * 1.1
				_flash_hop(c2, back, x)
				pj.anim(c2, "slash_c", 2.4)
				var q: Vector3 = x.global_position + Vector3.UP * 1.1
				var f: Vector3 = c2.face_dir()
				var sv: Vector3 = f.cross(Vector3.UP).normalized()
				var xm = _sweep(Color(1, 1, 0.9, 1), Color(1.0, 0.35, 0.15, 0.9), 0.3, false, Color(0.35, 0.05, 0.0, 0.85), 0.15)
				for sgn in [-1.0, 1.0]:
					var dd: Vector3 = (sv * sgn + Vector3.UP).normalized() * 0.75
					_streak(q - dd, q + dd, 0.14, xm, 0.05, 0.05, 0.2, {"n": 6, "taper": 0.5})
				_nick(q, BOLT_Y, 1.1, 6)
				Sfx.play("slash", x.global_position, 1.0)
				x.take_hit(pj.inf(c2, id, 1.6, {"knock": 9.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1, "pierce_guard": true}))
			else:
				_flash_hop(c2, pj.gp(p), null)))
	pr.radius = 0.4
