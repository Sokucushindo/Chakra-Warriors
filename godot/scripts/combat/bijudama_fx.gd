class_name BijudamaFX
extends RefCounted
## Kuyruklu Canavar Topu (Bijūdama) — TEK görsel kaynak, KENDİ parçalarıyla (ortak halka / yıldız / moloz / çatlak / iz YOK).
## Ref: refs/bijudama (anime: Kurama / Gyūki / Ten-Tails atışları, Naruto vs Kurama patlaması).
## 1) Toplanış: ağız önünde çevreden mavi (pozitif) ve kırmızı-siyah (negatif) chakra küreleri sarmal çizerek içe akar;
##    altında zemin basınçla menekşe ışıyan yarıklarla çatlar, taş parçaları topa doğru kalkar.
## 2) Top: koyu mor-siyah, içinde dönen menekşe girdaplar, kenarında ince parlak hale (vfx_bijudama.gdshader);
##    çevresinde dönen siyah-mor chakra kıymıkları.
## 3) Atış: ağız önünde iç içe menekşe-beyaz basınç halkaları, sekiz kollu menekşe parlama, topun ardında soluk lavanta hayaletler.
## 4) Patlama: kör edici beyaz-altın küre -> yarı saydam lavanta kubbe -> göğe ışık sütunu; zeminde ardışık basınç halkaları,
##    menekşe ışıyan yarıklar, savrulan taşlar; ekran parlar, sarsar.
## Kullananlar: TailedBeasts.fire_ball (pelerin + tam dönüşüm), PathJutsu.p_bijudama, BijuuArts, dövüş tarzları.

const BLUE := Color(0.35, 0.6, 1.0)
const RED := Color(0.75, 0.08, 0.12)
const VIO := Color(0.62, 0.4, 0.95)

static var _cache := {}
static var _live := 0   # aynı anda çok fazla parça (ağır sahne) olmasın


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _scene() -> Node:
	var t := _tree()
	return t.current_scene if t and t.current_scene else (t.root if t else null)


static func _add(n: Node3D, pos: Vector3) -> bool:
	var sc := _scene()
	if sc == null:
		n.free()
		return false
	sc.add_child(n)
	n.global_position = pos
	return true


static func _sph(r: float, rings := 16) -> SphereMesh:
	var k := "sph_%d" % rings
	if not _cache.has(k):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = rings * 2
		m.rings = rings
		_cache[k] = m
	return _cache[k]


static func _mat(light := false, alpha := 1.0, hot := false) -> ShaderMaterial:
	var key = "bijudama_%s_%.2f_%s" % [light, alpha, hot]
	if _cache.has(key):
		return _cache[key]
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/vfx_bijudama.gdshader")
	if light:   # patlama kubbesi: açık lavanta, saydam
		m.set_shader_parameter("deep", Color(0.55, 0.38, 0.78))
		m.set_shader_parameter("swirl_col", Color(0.92, 0.82, 1.0))
		m.set_shader_parameter("rim_col", Color(1.0, 0.97, 1.0))
		m.set_shader_parameter("speed", 2.6)
	if hot:
		# derinlik yazan kopya: ekran çizgisi (outline) içindeki kaya/kaktüs kenarlarını beyaz ışığın üstüne çizmesin
		var sh = Shader.new()
		sh.code = m.shader.code.replace("depth_draw_opaque", "depth_draw_always")
		m.shader = sh
		m.set_shader_parameter("deep", Color(1.0, 0.98, 0.9))
		m.set_shader_parameter("swirl_col", Color(1.0, 1.0, 0.95))
		m.set_shader_parameter("rim_col", Color(1.0, 0.9, 0.6))
		m.set_shader_parameter("speed", 4.0)
	m.set_shader_parameter("alpha", alpha)
	if alpha < 0.999:
		m.render_priority = 1
	_cache[key] = m
	return m


# ------------------------------------------------------------------ Bijūdama'ya özel parçalar
## Basınç halkası: tırtıklı menekşe-beyaz chakra dalgası (iç kenar keskin, dış kenar dağınık; içinde koyu menekşe çizgiler)
const _RING_SH := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(0.62, 0.4, 0.95, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.97, 1.0, 1.0);
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float jag = 0.035 * sin(a * 23.0 + seed) + 0.025 * sin(a * 41.0 - seed * 2.0);
	float rad = mix(0.12, 0.92, t) + jag;
	float w = mix(0.16, 0.03, t);
	float band = smoothstep(rad - w, rad, r) * (1.0 - smoothstep(rad, rad + w * 0.35, r));
	float streak = 0.6 + 0.4 * sin(a * 9.0 + r * 30.0 - t * 12.0 + seed);
	float fade = 1.0 - smoothstep(0.55, 1.0, t);
	vec3 c = mix(col.rgb, core.rgb, smoothstep(rad - w * 0.4, rad, r));
	ALBEDO = c * streak;
	ALPHA = clamp(band * fade * 1.4, 0.0, 1.0);
}
"""

const _ORB_SH := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 col : source_color = vec4(0.35, 0.6, 1.0, 1.0);
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(col.rgb * 0.55, mix(col.rgb, vec3(1.0), 0.75), pow(f, 2.5)) * 1.6;
}
"""

## Parlama: sekiz kollu menekşe ışın + beyaz merkez (kameraya dönük kart)
const _FLASH_SH := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(0.62, 0.4, 0.95, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = pow(abs(cos(a * 4.0)), 18.0) * (1.0 - smoothstep(0.0, 1.0, r)) * 1.3;
	float ctr = 1.0 - smoothstep(0.0, 0.42, r);
	float fade = 1.0 - t;
	ALBEDO = mix(col.rgb, vec3(1.0, 0.98, 1.0), ctr);
	ALPHA = clamp((rays + ctr) * fade, 0.0, 1.0);
}
"""

## Yarık: zeminde ışınsal kırık çizgiler, içleri menekşe ışır (canavar chakrası toprağı yakar), sonra söner
const _CRACK_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 9.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 12.9898 + seed) * 43758.5);
	float ca = (sec + 0.5 + (off - 0.5) * 0.5) / n * 6.28318 - 3.14159;
	float wob = 0.06 * sin(r * 17.0 + off * 6.0) + 0.03 * sin(r * 41.0 + seed);
	float d = abs(sin(a - ca - wob)) * r;
	float len = mix(0.55, 1.0, off);
	float line = (1.0 - smoothstep(0.004, 0.02 + 0.02 * (1.0 - r), d)) * (1.0 - smoothstep(len * 0.85, len, r));
	float hole = 1.0 - smoothstep(0.08, 0.2, r);
	float m = max(line, hole * 0.9);
	float glow = (1.0 - smoothstep(0.0, 0.5, t)) * (1.0 - smoothstep(0.0, 0.012, d));
	ALBEDO = mix(vec3(0.07, 0.03, 0.08), vec3(0.75, 0.5, 1.0), glow);
	ALPHA = m * (1.0 - smoothstep(0.7, 1.0, t)) * 0.95;
}
"""


static func _smat(code: String, key: String) -> ShaderMaterial:
	if not _cache.has(key):
		var sh := Shader.new()
		sh.code = code
		_cache[key] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache[key]
	m.set_shader_parameter("seed", randf() * 100.0)
	return m


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		_cache["quad"] = q
	return _cache["quad"]


## Basınç halkası (size = son çap). normal = halkanın baktığı yön (yerde UP, atışta namlu yönü)
static func _ring(pos: Vector3, size: float, dur: float, normal := Vector3.UP, col := VIO) -> void:
	if _live > 60:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	var m := _smat(_RING_SH, "ring")
	m.set_shader_parameter("col", col)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(mi, pos):
		return
	_live += 1
	var n := normal.normalized()
	mi.global_transform = Transform3D(Basis(Quaternion(Vector3.BACK, n)).scaled(Vector3.ONE * size * 0.5), pos)
	var tw := mi.create_tween()
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_live -= 1
		mi.queue_free())


static func _flash(pos: Vector3, size: float, dur: float, col := VIO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	var m := _smat(_FLASH_SH, "flash")
	m.set_shader_parameter("col", col)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(mi, pos):
		return
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 0.5, dur * 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)


static func _cracks(g: Vector3, size: float, dur: float) -> void:
	GroundFX.add(g, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))   # yarık zemin: üstünden geçen yavaşlar
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	var m := _smat(_CRACK_SH, "crack")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := Game.jutsu_floor(g.x, g.z) + 0.06 + size * 0.03
	if not _add(mi, Vector3(g.x, y, g.z)):
		return
	mi.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * size * 0.5), Vector3(g.x, y, g.z))
	var tw := mi.create_tween()
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


## Kırık taş parçası ağı (sivri köşeli, toon)
static func _rock_mesh(col: Color) -> Mesh:
	var k := "rock_%s" % col.to_html()
	if _cache.has(k):
		return _cache[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var P := [Vector3(0, 1, 0), Vector3(0, -0.8, 0), Vector3(1, 0, 0.2), Vector3(-0.9, 0.1, -0.1), Vector3(0.1, 0.2, 1), Vector3(-0.2, -0.1, -0.9)]
	for i in P.size():
		P[i] = (P[i] as Vector3) * rng.randf_range(0.7, 1.15) * 0.5
	var F := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 4, 2], [1, 3, 4], [1, 5, 3], [1, 2, 5]]
	for f in F:
		var a: Vector3 = P[f[0]]
		var b: Vector3 = P[f[1]]
		var c: Vector3 = P[f[2]]
		var nn := (b - a).cross(c - a).normalized()
		for v in [a, b, c]:
			st.set_normal(nn)
			st.set_color(col)
			st.add_vertex(v)
	var m := st.commit()
	m.surface_set_material(0, Props.toon())
	_cache[k] = m
	return m


## Savrulan taşlar: up = hız yönü ağırlığı, pull: true ise topa doğru emilir (toplanış)
static func _rocks(pos: Vector3, n: int, speed: float, size: float, col := Color(0.42, 0.36, 0.3), pull_to := Vector3.INF) -> void:
	if _live > 60:
		return
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = n
	p.lifetime = 1.4
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(0.6, size * 2.0)
	pm.direction = Vector3.UP
	pm.spread = 50.0
	pm.initial_velocity_min = speed * 0.45
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -26, 0)
	if pull_to != Vector3.INF:   # toplanış: taşlar havada asılı kalıp topa doğru süzülür
		pm.gravity = (pull_to - pos).normalized() * 9.0 + Vector3(0, 2, 0)
		pm.damping_min = 2.0
		pm.damping_max = 4.0
	pm.angular_velocity_min = -300.0
	pm.angular_velocity_max = 300.0
	pm.scale_min = 0.5 * size
	pm.scale_max = 1.4 * size
	var cv := Curve.new()
	cv.add_point(Vector2(0, 1))
	cv.add_point(Vector2(0.8, 1))
	cv.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	p.process_material = pm
	p.draw_pass_1 = _rock_mesh(col)
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	if not _add(p, pos):
		return
	_live += 1
	p.emitting = true
	_tree().create_timer(p.lifetime + 0.3).timeout.connect(func():
		_live -= 1
		if is_instance_valid(p):
			p.queue_free())


static func _light(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	if not _add(l, pos):
		return
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Topun çevresinde dönen kıymıklar ve topun ardındaki hayaletler için kare kare çalışan küçük düğümler
class _Spin extends Node3D:
	var speed := 2.0
	func _process(d: float) -> void:
		rotate_y(speed * d)
		rotate_x(speed * 0.37 * d)


class _Ghosts extends Node3D:
	var target: Node3D
	var s := 1.0
	var acc := 0.0
	var life := 3.0
	var mat: Material
	func _process(d: float) -> void:
		life -= d
		if life <= 0.0 or not is_instance_valid(target) or not target.is_inside_tree():
			queue_free()
			return
		acc += d
		if acc < 0.035:
			return
		acc = 0.0
		var g := MeshInstance3D.new()
		g.mesh = BijudamaFX._sph(1.0, 10)
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(g)
		g.global_position = target.global_position
		g.scale = Vector3.ONE * s
		var tw := g.create_tween().set_parallel(true)
		tw.tween_property(g, "scale", Vector3.ONE * s * 0.15, 0.32)
		tw.tween_property(g, "transparency", 1.0, 0.32)
		tw.chain().tween_callback(g.queue_free)


# ------------------------------------------------------------------ dışa açık işlevler (eskisiyle aynı imza)
## Top görseli (çap = s metre): koyu girdaplı küre + çevresinde dönen siyah-mor chakra kıymıkları
static func ball(s: float) -> Node3D:
	var root = Node3D.new()
	var core = MeshInstance3D.new()
	core.mesh = _sph(1.0, 16)
	core.material_override = _mat()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * s
	root.add_child(core)
	var spin := _Spin.new()
	spin.speed = 3.2
	root.add_child(spin)
	if not _cache.has("shard_mat"):
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color(0.18, 0.05, 0.28)
		sm.emission_enabled = true
		sm.emission = Color(0.45, 0.2, 0.75)
		_cache["shard_mat"] = sm
	for k in 9:
		var sh := MeshInstance3D.new()
		sh.mesh = _sph(1.0, 6)
		sh.material_override = _cache["shard_mat"]
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 9.0
		var dir := Vector3(cos(a), sin(a * 2.0) * 0.45, sin(a)).normalized()
		var tan := dir.cross(Vector3.UP).normalized()   # kıymık topun çevresinde akış yönüne yatık
		sh.transform = Transform3D(Basis.looking_at(tan, Vector3.UP).scaled(Vector3(0.05, 0.05, 0.2) * s), dir * s * randf_range(0.6, 0.75))
		spin.add_child(sh)
	return root


## Toplanış (dur sn): at noktasına mavi + kırmızı chakra küreleri sarmal akar; s = son top çapı. Zemin basıncı.
static func gather(at: Vector3, s: float, dur: float) -> void:
	var tree := _tree()
	if tree == null:
		return
	var n = 26
	for k in n:
		var col = BLUE if k % 2 == 0 else RED
		var key := "orb_%d" % (k % 2)
		if not _cache.has(key):   # ışıyan chakra küresi: ortası beyaza yakın, kenarı koyu renk (düz daire gibi durmaz)
			var om := _smat(_ORB_SH, "orb_sh")
			om.set_shader_parameter("col", col)
			_cache[key] = om
		var orb := MeshInstance3D.new()
		orb.mesh = _sph(1.0, 8)
		orb.material_override = _cache[key]
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a0 = randf() * TAU
		var r0 = s * randf_range(2.2, 4.0) + 1.0
		var y0 = randf_range(-0.6, 1.0) * s
		if not _add(orb, at + Vector3(cos(a0) * r0, y0, sin(a0) * r0)):
			return
		var st = randf() * dur * 0.5
		orb.scale = Vector3.ONE * 0.01
		var sz := (s * randf_range(0.12, 0.22) + 0.08) * 0.9
		var tw = orb.create_tween()
		tw.tween_interval(st)
		tw.tween_property(orb, "scale", Vector3.ONE * sz, 0.08)
		var spin = randf_range(1.5, 3.0) * (1.0 if k % 3 else -1.0)
		tw.tween_method(func(u: float):
			if is_instance_valid(orb):
				var a = a0 + u * spin
				var rr = r0 * (1.0 - u)
				orb.global_position = at + Vector3(cos(a) * rr, y0 * (1.0 - u), sin(a) * rr)
				orb.scale = Vector3.ONE * sz * (1.0 - u * 0.6), 0.0, 1.0, maxf(0.15, dur - st - 0.05)).set_ease(Tween.EASE_IN)
		tw.tween_callback(orb.queue_free)
	# zemin basıncı: altındaki toprak menekşe ışıyan yarıklarla çöker, taşlar topa doğru kalkar
	var g = Vector3(at.x, Game.ground_height(at.x, at.z), at.z)
	if at.y - g.y < s * 4.0 + 3.0:
		_cracks(g, s * 2.5 + 2.0, 4.0)
		for k in 3:
			tree.create_timer(dur * k / 3.0).timeout.connect(func():
				_ring(g + Vector3.UP * 0.12, s * 3.0 + 3.0, 0.45, Vector3.UP, Color(0.6, 0.45, 0.8))
				_rocks(g + Vector3.UP * 0.2, 6, 5.0, 0.15 * s + 0.12, Color(0.4, 0.34, 0.3), at))
	Sfx.play("rasengan", at, 0.45)


## Atış anı: ağız önünde iç içe basınç halkaları (yön boyunca) + sekiz kollu parlama; topa lavanta hayalet izi bağlar
static func launch(at: Vector3, dir: Vector3, s: float, proj: Node3D = null) -> void:
	var tree := _tree()
	if tree == null:
		return
	for k in 4:
		tree.create_timer(k * 0.06).timeout.connect(func():
			_ring(at + dir * (k * s * 0.9), s * (3.0 + k * 1.1) + 2.0, 0.5, dir, Color(1.0, 0.95, 1.0) if k % 2 == 0 else VIO))
	_flash(at, s * 3.2 + 1.5, 0.28, VIO)
	_flash(at, s * 2.0 + 1.0, 0.18, Color(1.0, 0.97, 1.0))
	_light(at, Color(0.75, 0.6, 1.0), 10.0, s * 8.0 + 6.0, 0.35)
	var g = Vector3(at.x, Game.ground_height(at.x, at.z), at.z)
	if at.y - g.y < s * 5.0 + 4.0:
		# geri tepme: zeminde savrulan halka + yukarı fırlayan taşlar
		_ring(g + Vector3.UP * 0.15, s * 5.0 + 4.0, 0.55, Vector3.UP, Color(0.8, 0.7, 0.95))
		_rocks(g + Vector3.UP * 0.3, 12, 8.0 + s * 2.0, 0.12 * s + 0.15)
	if Game.world:
		Game.world.env.add_shake(clampf(0.3 + s * 0.1, 0.3, 1.2))
	if proj and is_instance_valid(proj):
		var gh := _Ghosts.new()
		gh.target = proj
		gh.s = s * 0.9
		gh.mat = _mat(true, 0.55)
		var sc := _scene()
		if sc:
			sc.add_child(gh)


## Patlama (R = etki yarıçapı): beyaz-altın küre -> lavanta kubbe -> ışık sütunu; basınç halkaları, yarıklar, taşlar
static func explode(pos: Vector3, R: float) -> void:
	var tree := _tree()
	if tree == null:
		return
	_flash(pos, R * 2.2, 0.3, Color(1, 0.95, 0.75))
	_flash(pos, R * 1.4, 0.2, Color(1, 1, 1))
	_light(pos, Color(1.0, 0.92, 0.75), 24.0, R * 6.0, 0.9)
	# ilk an: beyaz-altın sıcak küre hızla büyür ve söner (lavanta kubbe ardından gelir)
	var hot = MeshInstance3D.new()
	hot.mesh = _sph(1.0, 14)
	hot.material_override = _mat(false, 1.0, true)
	hot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _add(hot, pos):
		return
	hot.scale = Vector3.ONE * R * 0.3
	var th = hot.create_tween()
	th.tween_property(hot, "scale", Vector3.ONE * R * 1.7, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	th.tween_property(hot, "transparency", 1.0, 0.22)
	th.tween_callback(hot.queue_free)
	var flash = MeshInstance3D.new()
	flash.mesh = _sph(1.0, 14)
	flash.material_override = _mat(true, 0.92)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(flash, pos)
	flash.scale = Vector3.ONE * R * 1.2
	flash.visible = false   # beyaz flaş önce: kubbe onun ardından açılır
	var tw = flash.create_tween()
	tw.tween_interval(0.14)
	tw.tween_callback(func(): flash.visible = true)
	tw.tween_property(flash, "scale", Vector3.ONE * R * 2.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)   # kubbe bir an asılı kalır (anime: patlama küresi büyüyüp durur)
	tw.tween_property(flash, "scale", Vector3.ONE * R * 2.3, 0.45)
	tw.parallel().tween_property(flash, "transparency", 1.0, 0.45)
	tw.tween_callback(flash.queue_free)
	# içte koyu çekirdek bir an kalır (topun kendisi patlamanın ortasında çöker)
	var core = MeshInstance3D.new()
	core.mesh = _sph(1.0, 10)
	core.material_override = _mat()
	_add(core, pos)
	core.scale = Vector3.ONE * R * 0.35
	var tc = core.create_tween()
	tc.tween_property(core, "scale", Vector3.ONE * R * 0.05, 0.3).set_ease(Tween.EASE_IN)
	tc.tween_callback(core.queue_free)
	var g = Vector3(pos.x, Game.ground_height(pos.x, pos.z), pos.z)
	var near_ground = pos.y - g.y < R * 1.2
	var cam := tree.root.get_viewport().get_camera_3d() if tree.root else null
	_ring(pos, R * 1.6, 0.3, (cam.global_position - pos).normalized() if cam else Vector3.BACK, Color(1, 1, 1))
	if near_ground:
		_ring(g + Vector3.UP * 0.2, R * 3.2, 0.7, Vector3.UP, Color(0.75, 0.6, 0.95))
		tree.create_timer(0.12).timeout.connect(func(): _ring(g + Vector3.UP * 0.15, R * 4.2, 0.9, Vector3.UP, Color(0.55, 0.45, 0.6)))
		_cracks(g, R * 1.3, 10.0)
		_rocks(g + Vector3.UP * 0.5, 26, R * 1.6, maxf(0.3, R * 0.08))
		_rocks(g + Vector3.UP * 0.5, 14, R * 2.4, maxf(0.2, R * 0.05), Color(0.25, 0.22, 0.2))   # hızlı küçük kıymıklar
	# ref (anime): patlamadan göğe yükselen ışık sütunu + gecikmeli ikinci/üçüncü basınç dalgası
	var pil = MeshInstance3D.new()
	pil.mesh = _sph(1.0, 10)
	pil.material_override = _mat(true, 0.8)
	pil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(pil, pos + Vector3.UP * R * 1.5)
	pil.scale = Vector3(R * 0.5, R * 0.6, R * 0.5)
	var tp = pil.create_tween()
	tp.tween_property(pil, "scale", Vector3(R * 0.9, R * 7.0, R * 0.9), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tp.tween_interval(0.4)
	tp.tween_property(pil, "scale", Vector3(R * 0.1, R * 9.0, R * 0.1), 0.6)
	tp.parallel().tween_property(pil, "transparency", 1.0, 0.6)
	tp.tween_callback(pil.queue_free)
	if near_ground:
		for k2 in 2:
			tree.create_timer(0.4 + k2 * 0.3).timeout.connect(func():
				_ring(g + Vector3.UP * 0.2, R * (4.8 + k2 * 1.6), 1.0, Vector3.UP, Color(0.9, 0.85, 1.0))
				_rocks(g + Vector3.UP * 0.5, 12, R * (2.0 + k2), maxf(0.25, R * 0.06), Color(0.36, 0.3, 0.27)))
	Sfx.play("boom", pos, 0.4)
	if Game.world:
		Game.world.env.screen_flash(0.35)
		Game.world.env.add_shake(clampf(R * 0.15, 0.6, 2.5))


## Ağız önü: topun toplandığı / fırladığı nokta (çap kadar önde, hafif yukarıda)
static func muzzle(mouth: Node3D, diam: float) -> Vector3:
	var b = mouth.global_transform.basis
	return mouth.global_position - b.z.normalized() * diam * 0.6 + Vector3.UP * diam * 0.1


## Epik şarj (anime): ağız önünde koyu top büyür (mavi + kırmızı chakra küreleri dalga dalga akar, zemin çöker), sonda
## canavar topu YUTAR (top küçülüp ağza çekilir) — ardından fire_ball ile fırlatılır. diam = tam boy çap, dur = toplam süre.
static func charge(mouth: Node3D, diam: float, dur: float) -> void:
	if not is_instance_valid(mouth):
		return
	var tree := _tree()
	var root = Node3D.new()
	if not _add(root, muzzle(mouth, diam)):
		return
	root.add_child(ball(1.0))
	root.scale = Vector3.ONE * diam * 0.05
	var tw = root.create_tween()
	tw.tween_method(func(u: float):
		if not is_instance_valid(mouth) or not is_instance_valid(root):
			return
		var grow = pow(clampf(u / 0.82, 0.0, 1.0), 0.7)
		var gulp = smoothstep(0.86, 1.0, u)
		root.scale = Vector3.ONE * diam * lerpf(0.05, 1.0, grow) * lerpf(1.0, 0.4, gulp) * (1.0 + sin(u * 60.0) * 0.03)
		root.global_position = muzzle(mouth, diam * lerpf(1.0, 0.35, gulp)), 0.0, 1.0, dur)
	tw.tween_callback(root.queue_free)
	for w in 3:
		tree.create_timer(dur * 0.22 * w).timeout.connect(func():
			if is_instance_valid(mouth):
				gather(muzzle(mouth, diam), diam, dur * 0.4))
	_light(muzzle(mouth, diam), Color(0.6, 0.4, 0.95), 8.0, diam * 5.0, dur)
