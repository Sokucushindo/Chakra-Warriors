class_name KokutoFX
extends RefCounted
## Kokutō (Raidō Namiashi) kombo görselleri — kendi gölgelendiricisi ve şekilleri. Kanon: ışık yansıtmayan kara ağız -> parlak kılıç
## izi YOK; yalnız havada kısa süre kalan koyu bir kesik gölgesi ve ince soluk kenar. Zehir: hedefte mor-yeşil damlalar ve leke.
## Kage Mawari: rakibin arkasına süzülüş (koyu yer izi). Ortak efekt kütüphanesi yok.

static var _c := {}

const SMEAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
uniform vec2 near_d = vec2(0.5, 1.8);
void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float body = 1.0 - smoothstep(0.2, 0.9, v);
	float edge = smoothstep(0.82, 0.9, v) * (1.0 - smoothstep(0.94, 1.0, v)) * step(0.5, UV.y);
	float tail = smoothstep(0.0, 0.4, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	vec3 col = mix(vec3(0.06, 0.06, 0.08), vec3(0.62, 0.66, 0.72), edge);
	ALBEDO = col;
	ALPHA = clamp((body * 0.55 + edge * 0.7) * tail * fade_k * smoothstep(near_d.x, near_d.y, -VERTEX.z), 0.0, 1.0);
}
"""

const VENOM_SH := """shader_type spatial;
render_mode unshaded, cull_back, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float fr = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 col = mix(vec3(0.45, 0.85, 0.3), vec3(0.42, 0.12, 0.5), smoothstep(0.2, 0.7, fr));
	ALBEDO = mix(col, vec3(0.08, 0.02, 0.1), step(0.82, fr));
	ALPHA = fade_k;
}
"""

const SPOT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q) + 0.12 * sin(atan(q.y, q.x) * 7.0);
	float m = 1.0 - smoothstep(0.6, 0.95, r);
	ALBEDO = mix(vec3(0.3, 0.6, 0.2), vec3(0.35, 0.1, 0.42), smoothstep(0.0, 0.7, r));
	ALPHA = m * 0.7 * fade_k;
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


## Kara kesik gölgesi (yay): merkez, başlangıç ekseni a, dik eksen b
static func smear(center: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, w: float, life := 0.3) -> void:
	var root = _root()
	if root == null:
		return
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 18
	for i in n + 1:
		var k = float(i) / n
		var ang = lerpf(a0, a1, k)
		var dir = (a * cos(ang) + b * sin(ang)).normalized()
		var ww = w * sin(k * PI) * (0.3 + 0.7 * k)
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(center + dir * (r - ww))
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(center + dir * r)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _mat("smear", SMEAR_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	_fade(mi, life * 0.4, life * 0.6)


## Zehir: hedefin üstünde damlalar düşer, ayağında mor-yeşil leke
static func venom(x: Node3D, n: int, spot := 0.7) -> void:
	var root = _root()
	if root == null or not is_instance_valid(x):
		return
	if not _c.has("mesh:drop"):
		var s = SphereMesh.new()
		s.radius = 0.03
		s.height = 0.07
		s.radial_segments = 6
		s.rings = 3
		_c["mesh:drop"] = s
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_c["mesh:quad"] = q
	var h = float(x.get("height")) if x.get("height") != null else 1.8
	for i in n:
		var mi = MeshInstance3D.new()
		mi.mesh = _c["mesh:drop"]
		mi.material_override = _mat("venom", VENOM_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var p0 = x.global_position + Vector3(randf_range(-0.25, 0.25), h * randf_range(0.45, 0.85), randf_range(-0.25, 0.25))
		mi.global_position = p0
		mi.scale = Vector3(1, 1.6, 1)
		var gy = Game.ground_height(p0.x, p0.z)
		var tw = mi.create_tween()
		tw.tween_interval(randf() * 0.25)
		tw.tween_property(mi, "global_position:y", gy + 0.02, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_fade(mi, 0.5, 0.2)
	if spot > 0.0:
		var sp = MeshInstance3D.new()
		sp.mesh = _c["mesh:quad"]
		sp.material_override = _mat("spot", SPOT_SH)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sp)
		var gp = x.global_position
		sp.global_position = Vector3(gp.x, Game.ground_height(gp.x, gp.z) + 0.04, gp.z)
		sp.rotation = Vector3(-PI * 0.5, randf() * TAU, 0)
		sp.scale = Vector3.ONE * spot * 0.3
		sp.create_tween().tween_property(sp, "scale", Vector3.ONE * spot, 0.5)
		_fade(sp, 1.5, 1.0)


## Kombo vuruş anı (oyuncu ve düşman aynı)
static func strike(who: Node3D, i: int, _dmg: float) -> void:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var side = Vector3.UP.cross(f).normalized()
	var p = who.global_position
	var h = float(who.get("height")) if who.get("height") != null else 1.8
	match i:
		0:   # baş hizasında yatay (soldan sağa)
			smear(p + Vector3.UP * h * 0.88, side, f, 1.4, -0.3, 2.2, 0.22)
		1:   # sağ alttan sol üste çapraz
			smear(p + Vector3.UP * h * 0.6, (-side - Vector3.UP).normalized(), f, 1.3, 0.0, 2.0, 0.2)
		2:   # saplama: dar ileri kama
			smear(p + Vector3.UP * h * 0.62, f, side, 1.6, -0.15, 0.15, 0.14, 0.25)
		3:   # bacak hizasında tam tur
			smear(p + Vector3.UP * 0.35, f, side, 1.7, 0.0, TAU * 0.95, 0.2, 0.35)
		4:   # sırttan çapraz iniş
			smear(p + Vector3.UP * h * 0.7, (side + Vector3.UP).normalized(), f, 1.3, 0.0, 2.2, 0.2)
		5:   # dik iniş
			smear(p + Vector3.UP * h * 0.75, Vector3.UP, f, 1.5, 0.0, 2.4, 0.26, 0.4)
	var tg = Combat.nearest_enemy(who, 3.2)
	if tg != null and is_instance_valid(tg):
		venom(tg, 6 if i < 5 else 14, 0.0 if i < 2 else (0.7 if i < 5 else 1.3))


## Kage Mawari: en yakın rakibin arkasına süzülür (adım başında), yerde koyu sürtünme izi
static func slip_behind(who: Node3D) -> void:
	var tg = Combat.nearest_enemy(who, 6.0)
	if tg == null or not is_instance_valid(tg) or not who is CharacterBody3D:
		return
	var tf: Vector3 = tg.face_dir() if tg.has_method("face_dir") else (who.global_position - tg.global_position).normalized()
	tf.y = 0.0
	if tf.length() < 0.01:
		return
	var to = tg.global_position - tf.normalized() * 1.2
	var from = who.global_position
	to.y = Game.ground_height(to.x, to.z)
	who.global_position = Vector3(to.x, maxf(to.y, from.y - 1.5), to.z)
	if who.has_method("look_at"):
		var lk = Vector3(tg.global_position.x, who.global_position.y, tg.global_position.z)
		if lk.distance_to(who.global_position) > 0.1:
			who.look_at(lk, Vector3.UP)
	var mid = (from + to) * 0.5 + Vector3.UP * 0.6
	var d = (to - from)
	d.y = 0.0
	if d.length() > 0.1:
		for k in 3:
			smear(from.lerp(to, k / 2.0) + Vector3.UP * (0.4 + k * 0.4), d.normalized(), Vector3.UP.cross(d.normalized()), 0.6, -0.4, 0.4, 0.12, 0.25)
