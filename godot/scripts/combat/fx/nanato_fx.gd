class_name NanatoFX
extends RefCounted
## Nanatō (Killer B, Akurobatto) kombo görselleri — kendi gölgelendiricisi ve şekilleri: ince çelik kesik yayları (beyaz çekirdek,
## soğuk mavi kenar, mürekkep dış çizgi), saplama çizgileri, fırlatılan kılıçlar, kan damlaları. Ortak efekt kütüphanesi yok.

static var _c := {}

const ARC_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
uniform vec2 near_d = vec2(0.5, 1.8);
void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.0, 0.35, v);
	float rim = smoothstep(0.55, 0.75, v) * (1.0 - smoothstep(0.85, 1.0, v));
	float tail = smoothstep(0.0, 0.35, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
	vec3 col = mix(vec3(0.62, 0.78, 1.0), vec3(1.0), core);
	col = mix(col, vec3(0.05, 0.05, 0.08), rim);
	ALBEDO = col;
	ALPHA = clamp((core + rim * 0.9 + 0.35 * (1.0 - v)) * tail * fade_k * smoothstep(near_d.x, near_d.y, -VERTEX.z), 0.0, 1.0);
}
"""

const DROP_SH := """shader_type spatial;
render_mode unshaded, cull_back, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float fr = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = mix(vec3(0.75, 0.04, 0.06), vec3(0.18, 0.0, 0.02), step(0.7, fr));
	ALPHA = fade_k;
}
"""


static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[k] = m
	return _c[k]


static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _fade(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## Kesik yayı: merkez, iki eksen (a: başlangıç yönü, b: dik yön), yarıçap, açı aralığı, kalınlık
static func arc(center: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, w: float, life := 0.22) -> void:
	var root = _root()
	if root == null:
		return
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 20
	var nrm = a.cross(b).normalized()
	for i in n + 1:
		var k = float(i) / n
		var ang = lerpf(a0, a1, k)
		var dir = (a * cos(ang) + b * sin(ang)).normalized()
		var ww = w * sin(k * PI) * (0.4 + 0.6 * k)
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(center + dir * (r - ww * 0.5) + nrm * 0.0)
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(center + dir * (r + ww * 0.5))
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _mat("arc", ARC_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_fade(mi, life * 0.3, life * 0.7)


## Saplama çizgisi: düz ince kama (öne uzayan çelik iz)
static func thrust(from: Vector3, to: Vector3, w: float, life := 0.18) -> void:
	var root = _root()
	if root == null:
		return
	var d = to - from
	var cam = root.get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam else from + Vector3.UP * 5.0
	var side = d.normalized().cross((eye - from).normalized()).normalized() * w
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [[from - side * 0.2, Vector2(0, 0)], [from + side * 0.2, Vector2(0, 1)], [to, Vector2(1, 0.5)]]:
		im.surface_set_uv(v[1])
		im.surface_add_vertex(v[0])
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _mat("arc", ARC_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_fade(mi, life * 0.3, life * 0.7)


## Kan damlaları (saplamada)
static func blood(at: Vector3, dir: Vector3, n: int) -> void:
	var root = _root()
	if root == null:
		return
	if not _c.has("mesh:drop"):
		var s = SphereMesh.new()
		s.radius = 0.022
		s.height = 0.044
		s.radial_segments = 6
		s.rings = 3
		_c["mesh:drop"] = s
	for i in n:
		var mi = MeshInstance3D.new()
		mi.mesh = _c["mesh:drop"]
		mi.material_override = _mat("drop", DROP_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = at
		var v = (dir + Vector3(randf_range(-0.6, 0.6), randf_range(0.1, 0.9), randf_range(-0.6, 0.6))).normalized() * randf_range(2.0, 4.5)
		var end = at + v * 0.35 + Vector3.DOWN * 0.6
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "global_position", at + v * 0.18 + Vector3.UP * 0.1, 0.12)
		tw.chain().tween_property(mi, "global_position", end, 0.3).set_ease(Tween.EASE_IN)
		_fade(mi, 0.25, 0.2)


## Kombo adımının vuruş anı (oyuncu ve düşman aynı)
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side = Vector3.UP.cross(f).normalized()
	var p = who.global_position
	var h = float(who.get("height")) if who.get("height") != null else 1.8
	match i:
		0:   # ağız kılıcı: baş hizasında yatay yay (soldan sağa)
			arc(p + Vector3.UP * h * 0.9, side, f, 1.3, -0.2, 2.6, 0.16)
		1:   # dirsek saplamaları: göğüs hizasında iki öne kama
			thrust(p + Vector3.UP * h * 0.7 - side * 0.3, p + Vector3.UP * h * 0.72 + f * 1.9 - side * 0.15, 0.09)
			who.get_tree().create_timer(0.26).timeout.connect(func():
				if is_instance_valid(who):
					var q = who.global_position
					thrust(q + Vector3.UP * h * 0.7 + side * 0.3, q + Vector3.UP * h * 0.72 + f * 1.9 + side * 0.15, 0.09))
		2:   # diz kılıcı: yerden biçen tam halka
			arc(p + Vector3.UP * 0.45, f, side, 1.8, 0.0, TAU, 0.2, 0.3)
		3:   # breakdance dönüşü: üç seviyede çember
			for k in 3:
				var hk = [0.45, 0.95, 1.55][k]
				arc(p + Vector3.UP * hk, f, side, 1.5 + k * 0.15, k * 1.2, k * 1.2 + TAU * 0.85, 0.15, 0.32)
		4:   # Nage Ken: iki kılıç fırlatılır (orta menzil)
			_throw(who, f, side, h, dmg)
		5:   # Hachi no Hari: dört ağız birden saplanır + kan
			for k in 4:
				var o = side * [-0.35, 0.35, -0.15, 0.2][k] + Vector3.UP * h * [0.72, 0.72, 0.9, 0.4][k]
				thrust(p + o, p + o + f * 2.2, 0.11, 0.26)
			blood(p + Vector3.UP * h * 0.7 + f * 1.6, f, 10)


static func _throw(who: Node3D, f: Vector3, side: Vector3, h: float, dmg: float) -> void:
	var pj = PathJutsu.get_pinst()
	var tg = Combat.nearest_enemy(who, 16.0)
	for k in 2:
		var from = who.global_position + Vector3.UP * h * 0.85 + side * (0.25 if k == 0 else -0.25)
		var aim = f
		if tg != null and is_instance_valid(tg):
			aim = (tg.global_position + Vector3.UP * h * 0.6 + side * (0.2 if k == 0 else -0.2) - from).normalized()
		var holder = Node3D.new()
		var mi = MeshInstance3D.new()
		mi.mesh = CharacterModel.weapon_mesh("nanato")
		mi.rotation.y = PI   # kılıcın ucu (+Z) mermi önüne (-Z)
		holder.add_child(mi)
		var info = {"dmg": dmg * 0.6, "knock": 3.0, "kind": "light", "bleed": 2.0, "hitstop": 0.03, "attacker": who, "melee": false}
		pj.shot(who, from, aim, 34.0, holder, info, null, false, 0.9, func(at: Vector3, _t = null):
			blood(at, -aim, 5))
		var st = from
		thrust(st, st + aim * 3.0, 0.05, 0.15)


# ================================================================== Nanatō teknikleri (oyundaki gerçek kılıç modeliyle)
## Akurobatto stilinin gerçek yedi kılıcını çek (kuşanmışsa): kılıçlar gövdedeki yerlerine geçer
static func draw_real(who: Node3D) -> bool:
	var m = who.get("model")
	if m == null or not is_instance_valid(m) or m.get("weapons") == null:
		return false
	for w in m.weapons:
		if String(w.get("id", "")) == "nanato":
			if who is Player:
				Game.profile["weapon_drawn"] = true
			m.set_drawn(true, false)
			return true
	return false


## Kombo adımının pozunu oynat (Akurobatto: 3 = breakdance dönüşü); süre: vuruş anına kadar
static func play_step(who: Node3D, i: int, spd := 1.0) -> float:
	var K = preload("res://scripts/combat/keyed_combos.gd")
	var st: Array = K.steps("nanato")
	var m = who.get("model")
	if st.is_empty() or m == null or m.get("overlay") == null:
		return 0.25
	var ks: Dictionary = st[clampi(i, 0, st.size() - 1)]
	var sp = K.speed("nanato") * spd
	m.overlay.play_keys(ks, sp)
	return float(ks["hit"]) / sp


## Yedi gerçek kılıç gövdenin çevresinde ağızları dışa dönük döner (kılıç kuşanılmamış dövüş tarzında da aynı model)
static func orbit(who: Node3D, dur: float, turns: float, h := 1.2) -> void:
	var root = Node3D.new()
	who.add_child(root)
	root.position = Vector3.UP * h
	var mesh = CharacterModel.weapon_mesh("nanato")
	var spots = [[0.0, 0.25], [0.9, -0.1], [1.8, 0.35], [2.7, -0.3], [3.6, 0.1], [4.5, -0.2], [5.4, 0.4]]   # ağız, koltuk altı, dirsekler, diz, karın hizaları
	for s in spots:
		var a: float = s[0]
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		root.add_child(mi)
		mi.position = Vector3(sin(a), float(s[1]), cos(a)) * Vector3(0.32, 1.0, 0.32)
		mi.rotation = Vector3(float(s[1]) * -0.6, a, 0.0)
	var tw = root.create_tween()
	tw.tween_property(root, "rotation:y", TAU * turns, dur)
	tw.tween_callback(root.queue_free)
