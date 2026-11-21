class_name SwiftFX
extends RefCounted
## Jinton / Hız (Swift) görselleri — sıfırdan, kendi yapı taşlarıyla. Rüzgâr / tayfun DEĞİL: hız bir bulanıklıktır.
##   ARDIL GÖRÜNTÜ: kişinin o anki pozundan alınmış soluk, yarı saydam beyaz-mavi kopya; yatay şeritler halinde yırtılıp hareketin
##       tersine doğru tel tel soyulur (ref: Jinton anime karesi — koşucunun arkasında yırtık, pürüzlü beyaz iz).
##   YIRTIK İZ: geçilen hat boyunca gövde boyunda ve yerde pürüzlü kenarlı beyaz şeritler; kuyruktan başa doğru parçalanıp söner,
##       kopan beyaz kıymıklar havada savrulur.
##   AYAK İZİ: kalkışta / frende yerden kalkan toz topakları, çakıl, koyu sürtünme izi.
##   SIKIŞMIŞ HAVA: ekran görüntüsünü büken görünmez bir halka (yalnız kırılma; geometrik kabuk görünmez).
##   SES HALKASI: yalnız kanonda ses duvarı olan yerde (Onsoku Hakushu çırpışı, Ikkōsen'in çıkışı): harekete dik, buhar konisi gibi
##       geriye yatık, yırtık kenarlı beyaz yaka.
## Hazır / ortak efekt yardımcısı kullanılmaz. Oynanış path_jutsu.gd'deki eski işleyişten satır satır taşındı; yalnız görünüş değişti.

const PALE := Color(0.93, 0.95, 1.0)
const WARM := Color(1.0, 0.97, 0.9)
const DUST_TOP := Color(0.86, 0.8, 0.68)
const DUST_BOT := Color(0.62, 0.55, 0.44)
const SKID := Color(0.3, 0.24, 0.18)
const CRACK := Color(0.14, 0.11, 0.09)

## Ardıl görüntü: soluk gövde, kenarda (fresnel) parlak çizgi; "tear" arttıkça yatay şeritler halinde delinir ve şeritler "drift"
## yönünde (hareketin tersi, yerel uzayda) farklı miktarlarda çekilir → tel tel soyulma
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec3 c_body = vec3(0.84, 0.89, 0.97);
uniform vec3 c_rim = vec3(1.0, 1.0, 1.0);
instance uniform float alpha = 0.6;
instance uniform float tear = 0.0;
instance uniform vec3 drift = vec3(0.0);
instance uniform float seed = 0.0;
varying vec3 wp;
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = vn(vec2(wp.y * 6.0 + seed, seed * 0.7));
	float pull = tear * tear * (0.25 + band * 1.3);
	VERTEX += drift * pull;
}
void fragment() {
	float n = vn(vec2(wp.y * 10.0 + seed, (wp.x + wp.z) * 1.5));
	float n2 = vn(wp.xz * 6.0 + vec2(wp.y * 3.0, seed));
	float rip = n * 0.72 + n2 * 0.28;
	if (rip < tear * 1.15 - 0.05) { discard; }
	float fres = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = step(0.58, fres);
	ALBEDO = mix(c_body, c_rim, rim);
	ALPHA = clamp(alpha * (0.4 + 0.6 * rim) * (1.0 - tear * 0.45), 0.0, 1.0);
}
"""

## Yırtık iz şeridi: köşeli (basamaklı) pürüzlü kenar, ince hız çizgileri; "tear" ile kuyruktan (UV.x = 0) başa doğru parçalanır.
## COLOR: renk tonu (toz / çatlak için koyu) ve uçlarda sönme
const WISP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 c_hi = vec3(0.97, 0.98, 1.0);
uniform vec3 c_lo = vec3(0.72, 0.77, 0.87);
instance uniform float fade = 1.0;
instance uniform float tear = 0.0;
instance uniform float seed = 0.0;
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float across = 1.0 - abs(v * 2.0 - 1.0);
	float j = vn(vec2(floor(u * 22.0) * 0.41 + seed, 0.5));
	float j2 = h21(vec2(floor(u * 55.0), floor(v * 5.0) + seed));
	float edge = 0.12 + j * 0.5 + j2 * 0.14;
	if (across < edge || COLOR.a < j2 * 0.5 + 0.03) { discard; }
	float peel = tear * 1.5 - u * 0.95;
	float hole = vn(vec2(u * 16.0 + seed, v * 3.5 + seed));
	if (hole < peel) { discard; }
	if (length(VERTEX) < 1.0 + j * 1.2) { discard; }
	float core = step(edge + 0.22, across);
	float line = step(0.88, fract(v * 7.0 + j * 0.4)) * (1.0 - core * 0.5);
	vec3 col = mix(c_lo, c_hi, core);
	col = mix(col, c_lo * 0.9, line * 0.6);
	ALBEDO = col * COLOR.rgb;
	ALPHA = (0.5 + 0.38 * core) * fade;
}
"""

## Sıkışmış hava: ekranı halka boyunca dışa doğru büker (yalnız kırılma + çok hafif parlama)
const DISTORT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform float fade = 1.0;
instance uniform float power = 0.03;
varying vec2 vr;
void vertex() {
	vec2 d = (MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xy;
	vr = d / max(length(d), 0.0001);
}
void fragment() {
	float ring = sin(clamp(UV.y, 0.0, 1.0) * 3.14159);
	vec2 off = vr * power * ring * fade;
	vec3 sc = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	ALBEDO = sc * (1.0 + ring * 0.05 * fade);
	ALPHA = ring * fade;
}
"""

static var _m_ghost: ShaderMaterial
static var _m_wisp: ShaderMaterial
static var _m_dist: ShaderMaterial
static var _m_pa: StandardMaterial3D
static var _m_po: StandardMaterial3D
static var _mesh_dust: Mesh
static var _mesh_chip: Mesh
static var _mesh_shard: Mesh
static var _curve_shrink: Curve
static var _g_shard: Gradient
static var _g_dust: Gradient
static var _g_chip: Gradient
static var _gcache := {}


# ================================================================== malzemeler / parçacık şekilleri (kendi)
static func _shader_mat(code: String) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	return m


static func _ghost_mat() -> ShaderMaterial:
	if _m_ghost == null:
		_m_ghost = _shader_mat(GHOST_SHADER)
	return _m_ghost


static func _wisp_mat() -> ShaderMaterial:
	if _m_wisp == null:
		_m_wisp = _shader_mat(WISP_SHADER)
	return _m_wisp


static func _dist_mat() -> ShaderMaterial:
	if _m_dist == null:
		_m_dist = _shader_mat(DISTORT_SHADER)
	return _m_dist


static func _pmat(alpha: bool) -> StandardMaterial3D:
	if alpha and _m_pa != null:
		return _m_pa
	if not alpha and _m_po != null:
		return _m_po
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_m_pa = m
	else:
		_m_po = m
	return m


## Ayak tozu topağı: küçük, yuvarlak, üstü açık altı koyu
static func _dust_mesh() -> Mesh:
	if _mesh_dust == null:
		var b = MB.new()
		b.add_grad("sphere", Vector3.ZERO, Vector3(0.2, 0.13, 0.18), Color.WHITE, Color(0.72, 0.7, 0.66), Vector3.ZERO, 10)
		b.add_grad("sphere", Vector3(0.07, 0.04, 0.02), Vector3(0.12, 0.1, 0.11), Color.WHITE, Color(0.75, 0.72, 0.68), Vector3.ZERO, 8)
		_mesh_dust = b.build(_pmat(false))
	return _mesh_dust


## Çakıl: küçük köşeli taş
static func _chip_mesh() -> Mesh:
	if _mesh_chip == null:
		var b = MB.new()
		b.add("prism", Vector3.ZERO, Vector3(0.05, 0.035, 0.045), Color.WHITE, Vector3(15, 40, 10))
		b.add("prism", Vector3(0.018, 0.01, 0.0), Vector3(0.03, 0.025, 0.03), Color(0.8, 0.8, 0.8), Vector3(-20, 80, 25))
		_mesh_chip = b.build(_pmat(false))
	return _mesh_chip


## Kopan beyaz kıymık: köşeli, yırtık kâğıt gibi ince yassı parça
static func _shard_mesh() -> Mesh:
	if _mesh_shard == null:
		var r = Rib.new()
		r.strip([Vector3(-0.09, 0, 0), Vector3(-0.03, 0.01, 0.02), Vector3(0.03, -0.01, -0.01), Vector3(0.1, 0, 0.01)],
			[Vector3(0, 0.012, 0), Vector3(0, 0.03, 0), Vector3(0, 0.022, 0), Vector3(0, 0.006, 0)],
			[Color.WHITE, Color.WHITE, Color(0.9, 0.92, 0.96), Color.WHITE], [0.0, 0.33, 0.66, 1.0])
		_mesh_shard = r.mesh()
		_mesh_shard.surface_set_material(0, _pmat(true))
	return _mesh_shard


static func _shrink() -> Curve:
	if _curve_shrink == null:
		_curve_shrink = Curve.new()
		_curve_shrink.add_point(Vector2(0.0, 0.5))
		_curve_shrink.add_point(Vector2(0.15, 1.0))
		_curve_shrink.add_point(Vector2(0.7, 1.0))
		_curve_shrink.add_point(Vector2(1.0, 0.0))
	return _curve_shrink


static func _grad(cols: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func _shard_ramp() -> Gradient:
	if _g_shard == null:
		_g_shard = _grad([Color(1, 1, 1, 0.0), Color(0.96, 0.97, 1.0, 0.75), Color(0.86, 0.9, 0.97, 0.45), Color(0.8, 0.85, 0.95, 0.0)])
	return _g_shard


static func _dust_ramp() -> Gradient:
	if _g_dust == null:
		_g_dust = _grad([DUST_TOP, DUST_TOP.darkened(0.12), Color(0.78, 0.72, 0.6)])
	return _g_dust


static func _chip_ramp() -> Gradient:
	if _g_chip == null:
		_g_chip = _grad([Color(0.5, 0.42, 0.33), Color(0.38, 0.32, 0.26), Color(0.6, 0.55, 0.48)])
	return _g_chip


# ================================================================== şerit kurucu (kendi ArrayMesh'i)
class Rib extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var ix := PackedInt32Array()

	func strip(pts: Array, sides: Array, cols: Array, us: Array) -> void:
		var m := pts.size()
		if m < 2:
			return
		var base := v.size()
		for k in m:
			var p: Vector3 = pts[k]
			var sd: Vector3 = sides[k]
			var tng: Vector3 = pts[mini(k + 1, m - 1)] - pts[maxi(k - 1, 0)]
			var nr: Vector3 = tng.cross(sd)
			nr = nr.normalized() if nr.length_squared() > 0.000001 else Vector3.UP
			v.append(p - sd)
			v.append(p + sd)
			n.append(nr)
			n.append(nr)
			uv.append(Vector2(us[k], 0.0))
			uv.append(Vector2(us[k], 1.0))
			c.append(cols[k])
			c.append(cols[k])
		for k in m - 1:
			var a := base + k * 2
			ix.append(a)
			ix.append(a + 1)
			ix.append(a + 2)
			ix.append(a + 1)
			ix.append(a + 3)
			ix.append(a + 2)

	func mesh() -> ArrayMesh:
		var am := ArrayMesh.new()
		if v.is_empty():
			return am
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = ix
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am


static func _ca(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0))


static func _lin(n: int) -> Array:
	var out = []
	for k in n:
		out.append(float(k) / maxf(1.0, n - 1.0))
	return out


# ================================================================== sahne / yaşam
static func _root(pj: PathJutsu, pos: Vector3) -> Node3D:
	var r = Node3D.new()
	pj.get_tree().current_scene.add_child(r)
	r.global_position = pos
	return r


static func _mi(parent: Node, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.set_meta("sfx", true)
	if mat == _wisp_mat():
		mi.set_instance_shader_parameter("seed", randf() * 50.0)
		mi.set_instance_shader_parameter("tear", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


static func _geos(n: Node, out: Array) -> Array:
	for ch in n.get_children():
		if ch is MeshInstance3D and ch.has_meta("sfx"):
			out.append(ch)
		_geos(ch, out)
	return out


static func _set_param(geos: Array, key: String, f: float) -> void:
	for g in geos:
		if is_instance_valid(g):
			g.set_instance_shader_parameter(key, f)


static func _stop(n: Node) -> void:
	for ch in n.get_children():
		if ch is CPUParticles3D:
			ch.emitting = false
		_stop(ch)


## Bekle → yırtıl (tear 0→1) ve sön → parçacıklar dinsin → sil. Atandan bağımsız.
static func _life(root: Node3D, hold: float, out: float, tail := 0.6) -> void:
	var geos = _geos(root, [])
	var tw = root.create_tween()
	tw.tween_interval(maxf(0.01, hold))
	tw.tween_callback(func(): _stop(root))
	tw.tween_method(func(f: float):
		_set_param(geos, "tear", f)
		_set_param(geos, "fade", 1.0 - f * f), 0.0, 1.0, maxf(0.02, out))
	tw.tween_interval(tail)
	tw.tween_callback(root.queue_free)


static func _emit(parent: Node, pts: PackedVector3Array, nrm: PackedVector3Array, mesh: Mesh, cfg: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.mesh = mesh
	p.amount = maxi(1, int(cfg.get("amount", 12)))
	p.lifetime = cfg.get("life", 0.6)
	p.lifetime_randomness = cfg.get("life_rand", 0.35)
	p.one_shot = cfg.get("one_shot", true)
	p.explosiveness = cfg.get("explos", 0.9 if p.one_shot else 0.0)
	p.local_coords = cfg.get("local", false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	p.emission_points = pts
	p.emission_normals = nrm
	p.direction = Vector3(0, 0, 1)
	p.spread = cfg.get("spread", 20.0)
	p.gravity = cfg.get("grav", Vector3(0, -6.0, 0))
	p.initial_velocity_min = cfg.get("vmin", 2.0)
	p.initial_velocity_max = cfg.get("vmax", 4.0)
	p.damping_min = cfg.get("damp", 0.0)
	p.damping_max = cfg.get("damp", 0.0)
	p.scale_amount_min = cfg.get("smin", 0.8)
	p.scale_amount_max = cfg.get("smax", 1.2)
	if cfg.has("ramp"):
		p.color_ramp = cfg["ramp"]
	if cfg.has("init_ramp"):
		p.color_initial_ramp = cfg["init_ramp"]
	if cfg.get("shrink", false):
		p.scale_amount_curve = _shrink()
	var sp: float = cfg.get("spin", 0.0)
	if sp > 0.0:
		p.angular_velocity_min = -sp
		p.angular_velocity_max = sp
		p.angle_min = -180.0
		p.angle_max = 180.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


# ================================================================== yapı taşları
## ARDIL GÖRÜNTÜ: kişinin şu anki pozunun kopyası (iskelet pozundan pişirilmiş), soluk beyaz-mavi; "hold" sonra yatay şeritler
## halinde "move" yönünün tersine soyulup söner. reuse > 0: aynı modelin yakın zamanda pişmiş pozunu yeniden kullanır (sık iz)
static func _ghost(pj: PathJutsu, c: Node3D, move: Vector3, alpha := 0.6, hold := 0.08, life := 0.45, reuse := 0.0, offset := Vector3.ZERO) -> Node3D:
	if c == null or not is_instance_valid(c):
		return null
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return null
	var now = Time.get_ticks_msec()
	for ck in _gcache.keys():
		if now - int(_gcache[ck][1]) > 3000:
			_gcache.erase(ck)
	var root = _root(pj, c.global_position)
	var parts = []
	var mv = move
	mv.y = 0.0
	var drift: Vector3 = -mv.normalized() * 1.1 if mv.length() > 0.01 else Vector3.UP * 0.3
	var sd = randf() * 50.0
	for node in (m as Node).find_children("*", "MeshInstance3D", true, false):
		var src = node as MeshInstance3D
		if src.mesh == null or not src.is_visible_in_tree():
			continue
		var mesh: Mesh = src.mesh
		if src.skin != null or src.get_node_or_null(src.skeleton) is Skeleton3D:
			var ck = src.get_instance_id()
			var hit = _gcache.get(ck)
			if reuse > 0.0 and hit != null and now - int(hit[1]) < int(reuse * 1000.0):
				mesh = hit[0]
			else:
				var baked = src.bake_mesh_from_current_skeleton_pose()
				if baked:
					mesh = baked
					_gcache[ck] = [baked, now]
		var e = MeshInstance3D.new()
		e.mesh = mesh
		e.material_override = _ghost_mat()
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(e)
		e.global_transform = src.global_transform
		e.global_position += offset
		e.set_instance_shader_parameter("alpha", alpha)
		e.set_instance_shader_parameter("tear", 0.0)
		e.set_instance_shader_parameter("seed", sd)
		e.set_instance_shader_parameter("drift", e.global_transform.basis.inverse() * drift)
		parts.append(e)
	var tw = root.create_tween()
	tw.tween_interval(maxf(0.01, hold))
	tw.tween_method(func(f: float):
		for e in parts:
			if is_instance_valid(e):
				e.set_instance_shader_parameter("tear", f)
				e.set_instance_shader_parameter("alpha", alpha * (1.0 - f * f)), 0.0, 1.0, maxf(0.05, life))
	tw.tween_callback(root.queue_free)
	# soyulan beyaz kıymıklar
	var sp = PackedVector3Array()
	var sn = PackedVector3Array()
	for i in 8:
		sp.append(Vector3(randf_range(-0.25, 0.25), randf_range(0.3, 1.7), randf_range(-0.25, 0.25)))
		sn.append((drift.normalized() + Vector3.UP * randf_range(0.1, 0.5)).normalized())
	_emit(root, sp, sn, _shard_mesh(), {"amount": 6, "life": life + 0.2, "vmin": 1.0, "vmax": 2.5, "grav": Vector3(0, 0.5, 0),
		"ramp": _shard_ramp(), "spin": 400.0, "damp": 1.0, "explos": 0.3, "smin": 0.8, "smax": 1.4})
	return root


## YIRTIK İZ: a → b boyunca gövde boyunda üç kat pürüzlü beyaz şerit + yerde yassı iz + kopan kıymıklar; kuyruktan başa yırtılır
static func _tear_trail(pj: PathJutsu, a: Vector3, b: Vector3, hold := 0.08, out := 0.45, alpha := 1.0, ground := true, heights := [0.4, 0.95, 1.5]) -> void:
	var ab = b - a
	if ab.length() < 0.2:
		return
	var root = _root(pj, a)
	var d = ab.normalized()
	var sd = d.cross(Vector3.UP).normalized() if absf(d.y) < 0.95 else Vector3.RIGHT
	var r = Rib.new()
	for h in heights:
		var start = randf_range(0.0, 0.2)
		var pts = []
		var sides = []
		var cols = []
		var us = []
		for k in 14:
			var u = lerpf(start, 1.0, k / 13.0)
			var jit = Vector3.UP * sin(u * 13.0 + h * 7.0) * 0.06 + sd * sin(u * 9.0 + h) * 0.05
			pts.append(ab * u + Vector3.UP * h + jit)
			sides.append((Vector3.UP * 0.9 + sd * 0.2).normalized() * (0.07 + u * 0.2) * (0.8 + randf() * 0.4))
			cols.append(_ca(Color.WHITE, alpha * minf(1.0, (1.0 - u) * 10.0 + 0.4)))
			us.append(u)
		r.strip(pts, sides, cols, us)
	if ground:   # yerdeki yassı iz (ref: zeminde sürünen yırtık beyaz şerit)
		var gp0 = pj.gp(a)
		var gp1 = pj.gp(b)
		var pts = []
		var sides = []
		var cols = []
		var us = []
		for k in 16:
			var u = k / 15.0
			pts.append(gp0.lerp(gp1, u) - a + Vector3.UP * 0.05 + sd * sin(u * 11.0) * 0.12)
			sides.append(sd * (0.12 + u * 0.32) * (0.7 + randf() * 0.6))
			cols.append(_ca(Color(0.95, 0.96, 1.0), alpha * 0.9))
			us.append(u)
		r.strip(pts, sides, cols, us)
	_mi(root, r.mesh(), _wisp_mat())
	var sp = PackedVector3Array()
	var sn = PackedVector3Array()
	for i in 10:
		var u = randf()
		sp.append(ab * u + Vector3.UP * randf_range(0.3, 1.7))
		sn.append((-d * 0.4 + Vector3.UP * randf_range(0.3, 1.0) + sd * randf_range(-0.8, 0.8)).normalized())
	_emit(root, sp, sn, _shard_mesh(), {"amount": int(clampf(ab.length() * 1.5, 4.0, 14.0)), "life": 0.7, "vmin": 0.6, "vmax": 2.0,
		"grav": Vector3(0, 0.6, 0), "ramp": _shard_ramp(), "spin": 500.0, "damp": 1.2, "explos": 0.2})
	_life(root, hold, out, 0.6)


## AYAK İZİ: kalkış / fren — koyu sürtünme izi, yerden kalkan toz topakları, çakıl
static func _scuff(pj: PathJutsu, pos: Vector3, dir: Vector3, power := 1.0) -> void:
	var at = pj.gp(pos)
	var root = _root(pj, at)
	var d = dir
	d.y = 0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var sd = d.cross(Vector3.UP).normalized()
	var r = Rib.new()
	for s in [-1.0, 1.0]:
		var pts = []
		var sides = []
		var cols = []
		for k in 8:
			var u = k / 7.0
			pts.append(sd * s * 0.14 - d * u * 0.9 * power + Vector3.UP * 0.03)
			sides.append(sd * (0.05 + (1.0 - u) * 0.05))
			cols.append(_ca(SKID, 1.0))
		r.strip(pts, sides, cols, _lin(8))
	var skid = _mi(root, r.mesh(), _wisp_mat())
	var tw = skid.create_tween()   # sürtünme izi biraz kalır, sonra söner
	tw.tween_interval(0.9)
	tw.tween_method(func(f: float): skid.set_instance_shader_parameter("fade", f), 1.0, 0.0, 0.6)
	var dp = PackedVector3Array()
	var dn = PackedVector3Array()
	for i in 10:
		var a = randf() * TAU
		dp.append(Vector3(cos(a), 0, sin(a)) * 0.2 + Vector3.UP * 0.05)
		dn.append((-d * 1.2 + Vector3(cos(a), 0, sin(a)) * 0.5 + Vector3.UP * randf_range(0.3, 0.8)).normalized())
	_emit(root, dp, dn, _dust_mesh(), {"amount": int(6 * power) + 3, "life": 0.6, "vmin": 1.5 * power, "vmax": 3.5 * power, "grav": Vector3(0, -1.0, 0),
		"damp": 3.0, "init_ramp": _dust_ramp(), "shrink": true, "spin": 90.0, "smin": 0.7, "smax": 1.3})
	_emit(root, dp, dn, _chip_mesh(), {"amount": int(3 * power) + 1, "life": 0.5, "vmin": 2.0, "vmax": 4.0, "grav": Vector3(0, -12.0, 0),
		"init_ramp": _chip_ramp(), "shrink": true, "spin": 600.0})
	var lt = root.create_tween()
	lt.tween_interval(1.7)
	lt.tween_callback(root.queue_free)


## SIKIŞMIŞ HAVA: dir'e dik açılan kırılma halkası (görünmez kabuk; yalnız arkadaki görüntü bükülür)
static func _distort(pj: PathJutsu, pos: Vector3, dir: Vector3, r0: float, r1: float, dur := 0.3, power := 0.035) -> void:
	var root = _root(pj, pos)
	var d = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	var a = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var b = d.cross(a).normalized()
	var r = Rib.new()
	var pts = []
	var sides = []
	var cols = []
	var us = []
	for k in 33:
		var t = TAU * k / 32.0
		var rad = a * cos(t) + b * sin(t)
		pts.append(rad * 1.0)
		sides.append(rad * 0.35)
		cols.append(Color.WHITE)
		us.append(k / 32.0)
	r.strip(pts, sides, cols, us)
	var mi = _mi(root, r.mesh(), _dist_mat())
	mi.set_instance_shader_parameter("power", power)
	root.scale = Vector3.ONE * r0
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * r1, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(f: float): mi.set_instance_shader_parameter("fade", f), 1.0, 0.0, dur)
	tw.tween_callback(root.queue_free)


## SES HALKASI (buhar konisi): dir'e dik, geriye yatık yırtık beyaz yaka; genişleyip yırtılarak söner + kırılma halkası
static func _vapor_ring(pj: PathJutsu, pos: Vector3, dir: Vector3, rad: float, dur := 0.35) -> void:
	var root = _root(pj, pos)
	var d = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var a = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var b = d.cross(a).normalized()
	var r = Rib.new()
	for layer in 2:
		var arcs = 5 + layer * 2
		for j in arcs:
			var t0 = TAU * j / arcs + randf_range(-0.15, 0.15)
			var t1 = t0 + TAU / arcs * randf_range(0.7, 0.95)
			var pts = []
			var sides = []
			var cols = []
			for k in 9:
				var u = k / 8.0
				var t = lerpf(t0, t1, u)
				var rv = a * cos(t) + b * sin(t)
				pts.append(rv * (1.0 + layer * 0.12) - d * (0.15 + layer * 0.25))
				sides.append((rv * 0.45 - d * 0.9).normalized() * (0.16 - layer * 0.05))   # geriye yatık yaka (buhar konisi)
				cols.append(_ca(Color.WHITE, minf(u, 1.0 - u) * 6.0 * (1.0 - layer * 0.3)))
			r.strip(pts, sides, cols, _lin(9))
	_mi(root, r.mesh(), _wisp_mat())
	root.scale = Vector3.ONE * rad * 0.5
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * rad * 1.5, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "global_position", pos - d * rad * 0.4, dur)
	_life(root, dur * 0.35, dur * 0.65, 0.05)
	_distort(pj, pos, d, rad * 0.6, rad * 2.2, dur * 1.1, 0.03)


## DARBE YILDIZI: ince sivri beyaz ışınlar (darbe yönüne dik düzlemde yoğun), ortada kısa parlama + kırılma halkası
static func _impact(pj: PathJutsu, pos: Vector3, dir: Vector3, size := 1.0, tint := WARM) -> void:
	var root = _root(pj, pos)
	var d = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var a = d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var b = d.cross(a).normalized()
	var r = Rib.new()
	var n = 9 + int(size * 3.0)
	for q in n:
		var t = TAU * q / n + randf_range(-0.2, 0.2)
		var ray = (a * cos(t) + b * sin(t) + d * randf_range(-0.35, 0.5)).normalized()
		var side = ray.cross(d).normalized()
		if side.length() < 0.5:
			side = a
		var L = size * randf_range(0.5, 1.15)
		r.strip([ray * 0.08, ray * L * 0.45, ray * L], [side * 0.012 * size, side * 0.06 * size, side * 0.004], [_ca(tint, 1.0), _ca(tint, 1.0), _ca(tint, 0.8)], [0.0, 0.5, 1.0])
		r.strip([ray * 0.08, ray * L * 0.45, ray * L], [d * 0.012 * size, d * 0.05 * size, d * 0.004], [_ca(tint, 1.0), _ca(tint, 1.0), _ca(tint, 0.8)], [0.0, 0.5, 1.0])
	_mi(root, r.mesh(), _wisp_mat())
	root.scale = Vector3.ONE * 0.3
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_life(root, 0.06, 0.14, 0.02)
	_distort(pj, pos, d, 0.2 * size, 1.4 * size, 0.22, 0.025)


## Yumruk bulanıklığı: omuzdan hedefe incelip kalınlaşan soluk sürtme + uçta yarı saydam yumruk hayaleti
static func _smear(pj: PathJutsu, s0: Vector3, s1: Vector3) -> void:
	var root = _root(pj, s0)
	var ab = s1 - s0
	var d = ab.normalized()
	var a = d.cross(Vector3.UP).normalized()
	if a.length() < 0.5:
		a = Vector3.RIGHT
	var b = d.cross(a).normalized()
	var r = Rib.new()
	var pts = []
	var sa = []
	var sb = []
	var cols = []
	for k in 8:
		var u = k / 7.0
		pts.append(ab * u)
		sa.append(a * (0.015 + u * u * 0.09))
		sb.append(b * (0.015 + u * u * 0.09))
		cols.append(_ca(WARM, 0.3 + u))
	r.strip(pts, sa, cols, _lin(8))
	r.strip(pts, sb, cols, _lin(8))
	_mi(root, r.mesh(), _wisp_mat())
	var fist = MB.new()   # yumruk: avuç bloğu + dört boğum
	fist.add("box", Vector3.ZERO, Vector3(0.1, 0.09, 0.11), Color.WHITE)
	for q in 4:
		fist.add("sphere", Vector3((q - 1.5) * 0.026, 0.03, 0.06), Vector3(0.03, 0.03, 0.03), Color.WHITE, Vector3.ZERO, 6)
	var fm = MeshInstance3D.new()
	fm.mesh = fist.build()
	fm.material_override = _ghost_mat()
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fm)
	fm.position = ab * 0.92
	fm.basis = Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	fm.set_instance_shader_parameter("alpha", 0.75)
	fm.set_instance_shader_parameter("tear", 0.0)
	fm.set_instance_shader_parameter("seed", randf() * 30.0)
	fm.set_instance_shader_parameter("drift", Vector3(0, 0, -0.2))
	var tw = root.create_tween()
	tw.tween_method(func(f: float):
		if is_instance_valid(fm):
			fm.set_instance_shader_parameter("tear", f), 0.0, 1.0, 0.16)
	_life(root, 0.03, 0.12, 0.05)


## Kesik çizgisi (Shinsokuzan): ince uzun beyaz yarık önce açılır, sonra iki yarıya ayrılıp yırtılarak söner
static func _cut_line(pj: PathJutsu, ep: Vector3, sd: Vector3, d: Vector3) -> void:
	for half in 2:
		var root = _root(pj, ep)
		var r = Rib.new()
		var pts = []
		var sides = []
		var cols = []
		var nrm = (sd * 0.5 + Vector3.UP).cross(d).normalized()
		for k in 10:
			var u = k / 9.0
			var uu = lerpf(0.0 if half == 0 else 0.5, 0.5 if half == 0 else 1.0, u)
			pts.append(sd * lerpf(-1.0, 1.0, uu) + Vector3.UP * lerpf(0.55, -0.55, uu))
			sides.append(d * (0.01 + sin(uu * PI) * 0.06) + nrm * 0.0)
			cols.append(_ca(Color.WHITE, minf(uu, 1.0 - uu) * 8.0))
		r.strip(pts, sides, cols, _lin(10))
		_mi(root, r.mesh(), _wisp_mat())
		var sep = (Vector3.UP * 0.6 + sd * 0.6).normalized() * (0.25 if half == 0 else -0.25)
		var tw = root.create_tween()
		tw.tween_interval(0.08)
		tw.tween_property(root, "global_position", ep + sep, 0.3).set_ease(Tween.EASE_OUT)
		_life(root, 0.1, 0.3, 0.02)


## Dikey hız çizgileri (havaya fırlayan hedefin çevresinde yukarı kayan ince yırtık çizgiler)
static func _rise_lines(pj: PathJutsu, pos: Vector3, h: float) -> void:
	var root = _root(pj, pos)
	var r = Rib.new()
	for q in 10:
		var a = TAU * q / 10.0 + randf_range(-0.2, 0.2)
		var rad = Vector3(cos(a), 0, sin(a))
		var y0 = randf_range(0.0, 0.8)
		var L = randf_range(1.2, h)
		var pts = []
		var sides = []
		var cols = []
		for k in 6:
			var u = k / 5.0
			pts.append(rad * randf_range(0.55, 0.75) + Vector3.UP * (y0 + u * L))
			sides.append(rad.cross(Vector3.UP).normalized() * (0.025 + sin(u * PI) * 0.03))
			cols.append(_ca(Color.WHITE, minf(u, 1.0 - u) * 5.0))
		r.strip(pts, sides, cols, _lin(6))
	_mi(root, r.mesh(), _wisp_mat())
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", pos + Vector3.UP * 2.5, 0.35).set_ease(Tween.EASE_OUT)
	_life(root, 0.12, 0.25, 0.02)


## Çakılma krateri: zikzak koyu çatlaklar (kalıcıca 2.5 sn), yassı toz halkası dışa, çakıl ve toz, yere yatık kırılma halkası
static func _crater(pj: PathJutsu, at: Vector3, R: float) -> void:
	var root = _root(pj, at)
	var r = Rib.new()
	for q in 8:
		var a = TAU * q / 8.0 + randf_range(-0.25, 0.25)
		var dir = Vector3(cos(a), 0, sin(a))
		var side = dir.cross(Vector3.UP)
		var L = R * randf_range(0.55, 1.0)
		var pts = []
		var sides = []
		var cols = []
		for k in 7:
			var u = k / 6.0
			pts.append(dir * (0.2 + u * L) + side * (randf_range(-0.12, 0.12) * u) + Vector3.UP * 0.04)
			sides.append(side * (0.07 * (1.0 - u) + 0.012))
			cols.append(_ca(CRACK, 1.0))
		r.strip(pts, sides, cols, _lin(7))
	var cr = _mi(root, r.mesh(), _wisp_mat())
	var ctw = cr.create_tween()
	ctw.tween_interval(2.5)
	ctw.tween_method(func(f: float): cr.set_instance_shader_parameter("fade", f), 1.0, 0.0, 0.8)
	var ring = Node3D.new()   # yassı toz halkası (yırtık kenarlı), dışa kayar
	root.add_child(ring)
	var rr = Rib.new()
	for j in 9:
		var t0 = TAU * j / 9.0
		var pts = []
		var sides = []
		var cols = []
		for k in 6:
			var u = k / 5.0
			var t = t0 + u * TAU / 9.0 * 0.85
			var rad = Vector3(cos(t), 0, sin(t))
			pts.append(rad + Vector3.UP * 0.12)
			sides.append((rad + Vector3.UP * 0.6).normalized() * 0.18)
			cols.append(_ca(DUST_TOP, minf(u, 1.0 - u) * 6.0))
		rr.strip(pts, sides, cols, _lin(6))
	var rm = _mi(ring, rr.mesh(), _wisp_mat())
	ring.scale = Vector3.ONE * 0.5
	var rtw = ring.create_tween()
	rtw.tween_property(ring, "scale", Vector3(R * 1.3, 1.6, R * 1.3), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_method(func(f: float):
		rm.set_instance_shader_parameter("tear", f)
		rm.set_instance_shader_parameter("fade", 1.0 - f), 0.0, 1.0, 0.55)
	var dp = PackedVector3Array()
	var dn = PackedVector3Array()
	for i in 14:
		var a = TAU * i / 14.0
		dp.append(Vector3(cos(a), 0.05, sin(a)) * 0.4)
		dn.append((Vector3(cos(a), 0, sin(a)) + Vector3.UP * randf_range(0.3, 1.2)).normalized())
	_emit(root, dp, dn, _dust_mesh(), {"amount": 16, "life": 0.9, "vmin": 3.0, "vmax": 6.0, "grav": Vector3(0, -2.0, 0), "damp": 3.0,
		"init_ramp": _dust_ramp(), "shrink": true, "spin": 60.0, "smin": 1.0, "smax": 1.8})
	_emit(root, dp, dn, _chip_mesh(), {"amount": 12, "life": 0.8, "vmin": 4.0, "vmax": 8.0, "grav": Vector3(0, -14.0, 0),
		"init_ramp": _chip_ramp(), "shrink": true, "spin": 700.0, "smin": 0.9, "smax": 1.5})
	_distort(pj, at + Vector3.UP * 0.2, Vector3.UP, 0.5, R * 1.8, 0.35, 0.04)
	var lt = root.create_tween()
	lt.tween_interval(3.5)
	lt.tween_callback(root.queue_free)


## Hareketin yönü (iz için): iki nokta farkı; çok kısaysa kişinin baktığı yön
static func _dir(a: Vector3, b: Vector3, c: Node3D) -> Vector3:
	var v = b - a
	v.y = 0
	if v.length() > 0.05:
		return v.normalized()
	return c.face_dir() if c != null and is_instance_valid(c) and c.has_method("face_dir") else Vector3.FORWARD


## Bir noktadan ötekine "ışınlanma" görünüşü: çıkışta ardıl görüntü (kişi taşınmadan ÖNCE çağrılır), yırtık iz, iki uçta ayak izi
static func _blink(pj: PathJutsu, c: Node3D, a: Vector3, b: Vector3, alpha := 0.75, ghost := true) -> void:
	var d = _dir(a, b, c)
	if ghost:
		_ghost(pj, c, d, 0.55 * alpha + 0.15, 0.06, 0.4, 0.1)
	_tear_trail(pj, a, b, 0.06, 0.4, alpha)
	_scuff(pj, a, d, 0.8)
	_scuff(pj, b, -d, 0.6)


# ================================================================== 1) Kōsoku — 7 sn bulanıklık hızı
static func kosoku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.3)
	var id = "jinsoku_kosoku"
	var DUR = 7.0
	var mods = {"speed": 1.9, "armor": 0.55, "_name": "Jinton: Kōsoku", "_desc": "bulanıklık hızında hareket: çok hızlısın, sana yetişemeyenin vuruşları boşa gider"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)
	var cw = weakref(c)
	var last = {"p": c.global_position}
	Sfx.play("whoosh", c.global_position, 1.6)
	# açılış: bedenden dışa sıkışan hava, ayaklardan kalkan toz
	_distort(pj, c.global_position + Vector3.UP * 1.0, Vector3.UP, 0.4, 2.6, 0.35, 0.04)
	_scuff(pj, c.global_position, c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD, 1.2)
	var acc = {"g": 0, "s": 0}
	pj.every(DUR, 0.05, func(_i, _k):   # arkasında yırtılan bulanık iz + ardıl görüntüler + ayak tozu
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var p: Vector3 = cc.global_position
		if p.distance_to(last["p"]) > 0.4:
			var a: Vector3 = last["p"]
			_tear_trail(pj, a, p, 0.05, 0.3, 0.7, true, [0.55, 1.2])
			acc["g"] += 1
			acc["s"] += 1
			if acc["g"] >= 4:   # her ~0.2 sn bir ardıl görüntü
				acc["g"] = 0
				_ghost(pj, cc, p - a, 0.4, 0.04, 0.35, 0.15)
			if acc["s"] >= 6:
				acc["s"] = 0
				_scuff(pj, p, p - a, 0.6)
		last["p"] = p)


# ================================================================== 2) Shunjin — rakibin çevresinde bulanık dönüş
static func shunjin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.3)
	var id = "jinsoku_shunjin"
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var prev = {"p": c.global_position}
	for k in 7:
		pj.after(0.05 + k * 0.14, func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			if cc == null or x == null or not pj.live(cc) or not pj.live(x):
				return
			var a = k * 2.3
			var p: Vector3 = pj.gp(x.global_position + Vector3(cos(a), 0, sin(a)) * 1.2)
			var a0: Vector3 = prev["p"]
			# bırakılan ardıl görüntü daha uzun kalır: hedefin çevresinde halka halka beliren kopyalar
			_ghost(pj, cc, p - a0, 0.6, 0.25, 0.45, 0.0)
			_tear_trail(pj, a0, p, 0.08, 0.4, 0.85, true)
			cc.global_position = p
			prev["p"] = p
			if cc is CharacterBody3D:
				cc.velocity = Vector3.ZERO
			pj._face(cc, x)
			var last = k == 6
			if last:
				pj._kick_pose(cc, 0.25)
			else:
				pj.anim(cc, ["jab", "hook"][k % 2], 2.6)
			_scuff(pj, p, p - a0, 0.7)
			_impact(pj, x.global_position + Vector3.UP * 1.1, cc.face_dir(), 1.3 if last else 0.6)
			Sfx.play("punch", x.global_position, 1.0 + k * 0.05)
			x.take_hit(pj.inf(cc, id, 1.3 if last else 0.4, {"knock": 18.0 if last else 0.5, "launch": 4.0 if last else 0.0, "kind": "heavy" if last else "light", "hitstop": 0.08 if last else 0.02, "dir": cc.face_dir()})))


# ================================================================== 3) Shinsokuzan — düz hatta geçiş, gecikmeli kesik
static func shinsokuzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.8)
	var id = "jinsoku_shinsokuzan"
	var d: Vector3 = pj._face(c, tt)
	var p0: Vector3 = c.global_position
	var L = clampf((p0.distance_to(tt.global_position) + 3.0) if tt else 12.0, 6.0, 18.0)
	var p1: Vector3 = p0 + d * L
	p1.y = Game.ground_height(p1.x, p1.z)
	_ghost(pj, c, d, 0.65, 0.3, 0.5)   # çıkış anının ardıl görüntüsü (kişi taşınmadan önce)
	c.global_position = p1
	if c is CharacterBody3D:
		c.velocity = Vector3.ZERO
	pj.anim(c, "slash_c", 2.0)
	_tear_trail(pj, p0, p1, 0.25, 0.5, 1.0, true, [0.35, 0.8, 1.25, 1.7])
	_distort(pj, p0 + Vector3.UP * 1.1 + d * 0.8, d, 0.4, 2.2, 0.3, 0.045)   # sıkışan hava (görünür halka yok)
	_scuff(pj, p0, d, 1.3)
	_scuff(pj, p1, -d, 1.0)
	Sfx.play("whoosh", p1, 1.8)
	var cw = weakref(c)
	var victims = []
	for e in pj.enemies_near(c, p0.lerp(p1, 0.5), L * 0.5 + 1.0):
		var v: Vector3 = e.global_position - p0
		var along = v.dot(d)
		var perp = (v - d * along)
		perp.y = 0
		if along > -0.5 and along < L + 0.5 and perp.length() < 1.6 + e.radius:
			victims.append(weakref(e))
	pj.after(0.35, func():   # gecikmeli kesik: hepsi aynı anda
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		Sfx.play("swing_sword", cc.global_position, 1.6)
		for w in victims:
			var e = w.get_ref()
			if e != null and pj.live(e):
				var ep: Vector3 = e.global_position + Vector3.UP * 1.1
				var sd = d.cross(Vector3.UP).normalized()
				_cut_line(pj, ep, sd, d)
				_impact(pj, ep, d, 0.8, PALE)
				e.take_hit(pj.inf(cc, id, 1.7, {"knock": 6.0, "launch": 2.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1, "pierce_guard": true, "dir": d})))


# ================================================================== 4) Zanzō — ardıl görüntü bırakıp arkadan dirsek
static func zanzo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.7)
	var id = "jinsoku_zanzo"
	pj._face(c, tt)
	var p0: Vector3 = c.global_position
	pj.decoy(c, p0, 3.0)   # oynanış: rakiplerin saldırdığı ardıl görüntü (yem)
	if tt == null:
		var f: Vector3 = c.face_dir()
		var p2: Vector3 = p0 - f * 6.0
		p2.y = Game.ground_height(p2.x, p2.z)
		_ghost(pj, c, -f, 0.5, 0.15, 0.4)
		c.global_position = p2
		_tear_trail(pj, p0, p2, 0.06, 0.4, 0.8)
		_scuff(pj, p0, -f, 1.0)
		_scuff(pj, p2, f, 0.8)
		return
	var back: Vector3 = tt.global_position - p0
	back.y = 0
	back = back.normalized()
	var p1: Vector3 = tt.global_position + back * 1.3
	p1.y = Game.ground_height(p1.x, p1.z)
	# geçiş yolu hedefin yanından kıvrılır: iki parçalı iz (ardıl görüntü yem tarafından gösterilir)
	var side = back.cross(Vector3.UP).normalized() * 1.4
	var mid: Vector3 = tt.global_position + side
	mid.y = p0.y
	c.global_position = p1
	if c is CharacterBody3D:
		c.velocity = Vector3.ZERO
	pj._face(c, tt)
	_tear_trail(pj, p0, mid, 0.05, 0.4, 0.6)
	_tear_trail(pj, mid, p1, 0.1, 0.4, 0.6)
	_scuff(pj, p0, back, 1.0)
	_scuff(pj, p1, -back, 0.9)
	Sfx.play("whoosh", p1, 1.9)
	var cw = weakref(c)
	var tw = weakref(tt)
	pj.after(0.12, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj.anim(cc, "hook", 2.4)
		_impact(pj, x.global_position + Vector3.UP * 1.2, -back, 1.3)
		Sfx.play("punch", x.global_position, 0.8)
		pj.shake(0.25)
		x.take_hit(pj.inf(cc, id, 1.8, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "stun": 0.5, "hitstop": 0.1, "pierce_guard": true, "dir": -back})))


# ================================================================== 5) Hyakuretsuken — yüz yumruk
static func hyakuretsuken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.5)
	var id = "jinsoku_hyakuretsuken"
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var p0: Vector3 = c.global_position
	var v0: Vector3 = tt.global_position - p0
	v0.y = 0
	if v0.length() > 2.0:   # bir anda dibine
		var p1: Vector3 = tt.global_position - v0.normalized() * 1.3
		p1.y = Game.ground_height(p1.x, p1.z)
		_blink(pj, c, p0, p1)
		c.global_position = p1
	pj._face(c, tt)
	pj.every(1.2, 0.05, func(i, _k):
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		var f: Vector3 = pj._face(cc, x)
		var sd = f.cross(Vector3.UP).normalized()
		if i % 2 == 0:
			pj.anim(cc, ["jab", "cross"][(i / 2) % 2], 4.0)
		for q in 2:   # bulanık yumruk izleri: omuzdan hedefe, her biri farklı yükseklik / yan
			var s0: Vector3 = cc.global_position + Vector3.UP * randf_range(1.1, 1.5) + sd * randf_range(-0.35, 0.35)
			var s1: Vector3 = x.global_position + Vector3.UP * randf_range(0.9, 1.6) + sd * randf_range(-0.4, 0.4)
			_smear(pj, s0, s1)
		if i % 6 == 0:   # kolların yelpazesi: gövdenin hafif kayık ardıl görüntüsü
			_ghost(pj, cc, -f, 0.3, 0.02, 0.2, 0.25, sd * randf_range(-0.12, 0.12))
		if i % 2 == 0:
			_impact(pj, x.global_position + Vector3.UP * randf_range(0.9, 1.6), f, 0.45)
			Sfx.play("punch", x.global_position, 1.4 + randf() * 0.3)
			pj.st(x, "stun", 0.2)
			x.take_hit(pj.inf(cc, id, 0.09, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "pierce_guard": true})), func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var f: Vector3 = pj._face(cc, x)
		pj.anim(cc, "cross", 2.0)
		_smear(pj, cc.global_position + Vector3.UP * 1.3, x.global_position + Vector3.UP * 1.2)
		_impact(pj, x.global_position + Vector3.UP * 1.2, f, 1.7)
		_distort(pj, x.global_position + Vector3.UP * 1.2, f, 0.5, 3.0, 0.35, 0.05)
		_scuff(pj, x.global_position, f, 1.4)
		Sfx.play("boom", x.global_position, 1.3, 0.6)
		pj.shake(0.35)
		x.take_hit(pj.inf(cc, id, 1.2, {"knock": 20.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.12, "pierce_guard": true, "dir": f})))


# ================================================================== 6) Tensōkyaku — göğe tekme, tepeden topuk
static func tensokyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 1.2)
	var id = "jinsoku_tensokyaku"
	if tt == null:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var p0: Vector3 = c.global_position
	var v0: Vector3 = tt.global_position - p0
	v0.y = 0
	if v0.length() > 2.0:
		var p1: Vector3 = tt.global_position - v0.normalized() * 1.2
		p1.y = Game.ground_height(p1.x, p1.z)
		_blink(pj, c, p0, p1)
		c.global_position = p1
	var f: Vector3 = pj._face(c, tt)
	pj._kick_pose(c, 0.3)
	Sfx.play("punch", tt.global_position, 0.9)
	_impact(pj, tt.global_position + Vector3.UP * 0.8, Vector3.UP, 1.1)
	_rise_lines(pj, tt.global_position, 3.0)
	_scuff(pj, c.global_position, f, 1.0)
	tt.take_hit(pj.inf(c, id, 0.6, {"knock": 0.5, "launch": 12.0, "kind": "heavy", "hitstop": 0.06, "pierce_guard": true, "dir": Vector3.UP}))
	pj.after(0.35, func():   # hedefin tepesinde belirir
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var top: Vector3 = x.global_position + Vector3.UP * 2.6 - f * 0.4
		_ghost(pj, cc, top - cc.global_position, 0.55, 0.1, 0.4)
		_tear_trail(pj, cc.global_position, top, 0.05, 0.35, 0.8, false, [0.6, 1.2])
		cc.global_position = top
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		pj._kick_pose(cc, 0.3)
		Sfx.play("whoosh", top, 1.8))
	pj.after(0.48, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var at: Vector3 = pj.gp(x.global_position if x != null and is_instance_valid(x) else cc.global_position)
		var from_top: Vector3 = cc.global_position
		if x != null and pj.live(x):
			x.global_position = at
			_impact(pj, at + Vector3.UP * 0.6, Vector3.DOWN, 1.8)
			x.take_hit(pj.inf(cc, id, 1.6, {"knock": 2.0, "launch": -10.0, "kind": "heavy", "stun": 0.9, "hitstop": 0.14, "pierce_guard": true, "dir": f}))
		cc.global_position = at - f * 1.0 + Vector3.UP * 0.2
		_tear_trail(pj, from_top, at + Vector3.UP * 0.3, 0.05, 0.3, 0.9, false, [0.0, 0.6])
		_crater(pj, at, 2.6)
		Sfx.play("boom", at, 0.9)
		pj.shake(0.5))


# ================================================================== 7) Ikkōsen — ses hızını aşan kunai
static func ikkosen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "jinsoku_ikkosen"
	var tt = pj.tg(c, t, 40.0)
	var d: Vector3 = pj._face(c, tt)
	pj.anim(c, "throw", 2.4)
	var cw = weakref(c)
	pj.after(0.12, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var from: Vector3 = pj.hand_pos(cc)
		var dir: Vector3 = pj.aim_at(cc, tt, from)
		var k = Node3D.new()
		var b = MB.new()
		b.add("prism", Vector3(0, 0, -0.2), Vector3(0.09, 0.02, 0.32), Color(0.75, 0.77, 0.8), Vector3(-90, 0, 0), 4)
		b.add("cyl", Vector3(0, 0, 0.08), Vector3(0.035, 0.24, 0.035), Color(0.2, 0.18, 0.18), Vector3(90, 0, 0), 6)
		b.add("box", Vector3(0, 0, 0.24), Vector3(0.08, 0.08, 0.02), Color(0.3, 0.3, 0.32))
		var km = MeshInstance3D.new()
		km.mesh = b.build(Props.toon())
		k.add_child(km)
		for q in 3:   # çıkışta art arda ses halkaları (buhar konisi yakaları)
			_vapor_ring(pj, from + dir * (0.6 + q * 1.4), dir, 0.5 + q * 0.35, 0.3 + q * 0.06)
		_scuff(pj, cc.global_position, -dir, 0.9)   # savuruşun tepkisi: ayaklar geri kayar
		Sfx.play("boom", from, 1.8, 0.6)
		pj.shake(0.2)
		var pr = pj.shot(cc, from, dir, 95.0, k, pj.inf(cc, id, 1.6, {"knock": 8.0, "launch": 1.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.08, "pierce_guard": true}), null, true, 0.6, func(p, _h):
			_impact(pj, p, dir, 0.9, PALE)
			Sfx.play("throw_kunai", p, 0.8))
		pr.radius = 0.4
		var last = {"p": from}
		var pw = weakref(pr)
		pj.every(0.6, 1.0 / 60.0, func(i, _k):   # arkasında incelen basınç izi + aralıklı küçük buhar halkaları
			var pp = pw.get_ref()
			if pp == null or not is_instance_valid(pp):
				return
			var p: Vector3 = pp.global_position
			if i % 2 == 0:
				var a: Vector3 = last["p"]
				_tear_trail(pj, a - Vector3.UP * 0.0, p, 0.04, 0.3, 0.8, false, [0.0])
				last["p"] = p
			if i % 6 == 0:
				_vapor_ring(pj, p - dir * 0.5, dir, 0.35, 0.25)))


# ================================================================== 8) Mikiri — bulanık tetik
static func mikiri(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.3)
	var DUR = 6.0
	c.set_meta("mikiri_n", 3)
	c.set_meta("mikiri_t", Game.now() + DUR)
	_ghost(pj, c, c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD, 0.5, 0.1, 0.3)
	_distort(pj, c.global_position + Vector3.UP * 1.0, Vector3.UP, 0.3, 1.8, 0.25, 0.03)
	Sfx.play("whoosh", c.global_position, 1.5)
	var cw = weakref(c)
	pj.every(DUR, 0.1, func(i, _k):   # tetikte: bedenin iki yanında titreşen soluk çift görüntü + ince titreme çizgileri (hak bittiyse söner)
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc) or int(cc.get_meta("mikiri_n", 0)) <= 0:
			return
		if i % 3 == 0:
			var a = randf() * TAU
			var p: Vector3 = cc.global_position + Vector3(cos(a) * 0.6, randf_range(0.4, 1.7), sin(a) * 0.6)
			var tg = Vector3(-sin(a), 0, cos(a))
			_tear_trail(pj, p - Vector3.UP * 0.0, p + tg * 0.6, 0.02, 0.2, 0.6, false, [0.0])
		if i % 5 == 0:
			var sd = cc.face_dir().cross(Vector3.UP).normalized() if cc.has_method("face_dir") else Vector3.RIGHT
			var s = 1.0 if (i / 5) % 2 == 0 else -1.0
			_ghost(pj, cc, -sd * s, 0.22, 0.05, 0.22, 0.45, sd * s * 0.22), func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			cc.remove_meta("mikiri_n"))


# ================================================================== 9) Renshunshin — beş rakip arasında ışınlanma
static func renshunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var id = "jinsoku_renshunshin"
	var foes = pj.enemies_near(c, c.global_position, 16.0)
	var tt = pj.tg(c, t, 16.0)
	if tt and not tt in foes:
		foes.push_front(tt)
	foes = foes.slice(0, 5)
	if foes.is_empty():
		return
	var cw = weakref(c)
	var home: Vector3 = c.global_position
	var prev = {"p": home}
	var n = foes.size()
	var hits = n if n > 2 else n * 2   # tek-iki rakipte her birine iki kez
	_distort(pj, home + Vector3.UP * 1.0, Vector3.UP, 0.3, 2.2, 0.3, 0.04)
	for k in hits:
		var ew = weakref(foes[k % n])
		pj.after(k * 0.16, func():
			var cc = cw.get_ref()
			var x = ew.get_ref()
			if cc == null or x == null or not pj.live(cc) or not pj.live(x):
				return
			var a = randf() * TAU
			var p: Vector3 = x.global_position + Vector3(cos(a), 0, sin(a)) * 1.2
			p.y = Game.ground_height(p.x, p.z)
			_blink(pj, cc, prev["p"], p, 0.7)
			cc.global_position = p
			prev["p"] = p
			if cc is CharacterBody3D:
				cc.velocity = Vector3.ZERO
			var f: Vector3 = pj._face(cc, x)
			if k % 2 == 0:
				pj.anim(cc, "hook", 2.8)
			else:
				pj._kick_pose(cc, 0.14)
			_impact(pj, x.global_position + Vector3.UP * 1.1, f, 0.9)
			Sfx.play("punch", x.global_position, 1.1 + k * 0.05)
			x.take_hit(pj.inf(cc, id, 0.85, {"knock": 9.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.05, "pierce_guard": true, "dir": f})))
	pj.after(hits * 0.16 + 0.05, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		_blink(pj, cc, prev["p"], home, 0.6)
		cc.global_position = home
		Sfx.play("whoosh", home, 1.6))


# ================================================================== 10) Onsoku Hakushu — ses hızında avuç çırpışı
static func onsoku_hakushu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "jinsoku_onsoku_hakushu"
	var tt = pj.tg(c, t, 14.0)
	var d: Vector3 = pj._face(c, tt)
	pj.anim(c, "cross", 1.4)
	var cw = weakref(c)
	# toplanma: avuçlar açılırken önündeki hava içe çekilir (ters kırılma)
	_distort(pj, c.global_position + Vector3.UP * 1.3 + d * 0.6, d, 1.4, 0.3, 0.18, 0.03)
	pj.after(0.18, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var o: Vector3 = cc.global_position + Vector3.UP * 1.3 + d * 0.6
		_impact(pj, o, d, 1.6, Color.WHITE)
		Sfx.play("boom", o, 1.6, 0.8)
		pj.shake(0.4)
		for q in 4:   # art arda genişleyen ses halkaları (koni biçiminde büyür)
			pj.after(q * 0.05, func(): _vapor_ring(pj, o + d * (1.0 + q * 2.2), d, 0.8 + q * 0.9, 0.35 + q * 0.05))
		# yerde koni biçiminde savrulan toz ve yatan toz çizgileri
		var g0: Vector3 = pj.gp(o)
		var sd = d.cross(Vector3.UP).normalized()
		var dp = PackedVector3Array()
		var dn = PackedVector3Array()
		for i in 12:
			var ang = randf_range(-0.6, 0.6)
			var dd = d.rotated(Vector3.UP, ang)
			dp.append(pj.gp(o + dd * randf_range(1.0, 4.0)) - g0 + Vector3.UP * 0.05)
			dn.append((dd + Vector3.UP * randf_range(0.15, 0.5)).normalized())
		var groot = _root(pj, g0)
		_emit(groot, dp, dn, _dust_mesh(), {"amount": 14, "life": 0.8, "vmin": 4.0, "vmax": 9.0, "grav": Vector3(0, -1.5, 0), "damp": 3.0,
			"init_ramp": _dust_ramp(), "shrink": true, "spin": 80.0, "smin": 1.0, "smax": 1.7})
		var r = Rib.new()
		for q in 7:
			var dd = d.rotated(Vector3.UP, lerpf(-0.55, 0.55, q / 6.0))
			var side = dd.cross(Vector3.UP)
			var pts = []
			var sides = []
			var cols = []
			for k in 8:
				var u = k / 7.0
				pts.append(pj.gp(o + dd * (1.0 + u * 7.5)) - g0 + Vector3.UP * 0.06)
				sides.append(side * (0.03 + u * 0.12))
				cols.append(_ca(DUST_TOP, minf(u * 4.0, 1.0)))
			r.strip(pts, sides, cols, _lin(8))
		_mi(groot, r.mesh(), _wisp_mat())
		_life(groot, 0.25, 0.6, 0.6)
		_scuff(pj, cc.global_position, -d, 1.0)
		Combat.hit_zone(cc, pj.gp(cc.global_position), d, 9.0, 35.0, 3.0, pj.inf(cc, id, 1.1, {"knock": 16.0, "launch": 2.0, "kind": "heavy", "stun": 1.0, "hitstop": 0.08, "pierce_guard": true})))
