extends RefCounted
## Shinobigote: model, kartuş / yoğunlaştırıcı ve altı kartuşun kendi görselleri (hedef: res://scripts/combat/fx/shinobigote_fx.gd).
## Kanon (Shinobi Gauntlet): kartuşa mühürlü tekniği salar, chakrası kol düzeneğinin yoğunlaştırıcısından gelir, kullanıcınınki harcanmaz; Rasengan bile fırlatılabilir.
## Oyun karşılığı: 6 kartuşluk yük; her atış 1 harcar, ateş kesilince dolar. Boşken mekanizma tık sesi verir, teknik çıkmaz. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "shinobigote"
const LOAD_MAX := 6
const REGEN := 1.4       # kartuş başına sn
const REGEN_WAIT := 1.2  # son atıştan sonra dolum başlangıcı

const FLAME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m = 1.0 - smoothstep(0.15, 0.9, length(p) + 0.12 * sin(atan(p.y, p.x) * 6.0 + TIME * 24.0));
	ALBEDO = mix(vec3(1.0, 0.3, 0.04), vec3(1.0, 0.95, 0.6), m * m);
	ALPHA = clamp(m * 1.6, 0.0, 1.0);
	if (ALPHA < 0.02) discard;
}
"""

const BOLT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.55, 0.3, 1.0), vec3(0.95, 0.92, 1.0), smoothstep(0.4, 0.9, e));
	ALPHA = smoothstep(0.0, 0.5, e) * fade;
}
"""

const WIND_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float tip = sin(UV.x * 3.14159);
	ALBEDO = vec3(0.86, 0.97, 0.95);
	ALPHA = smoothstep(1.0 - tip, 1.0, e + 0.15) * 0.8;
}
"""

const SHADOW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.02, 0.02, 0.03);
	ALPHA = smoothstep(0.0, 0.3, e) * 0.92;
}
"""

const SPIRAL_SH := """shader_type spatial;
render_mode unshaded, cull_back, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float a = atan(n.z, n.x);
	float s = sin(a * 3.0 + n.y * 7.0 - TIME * 26.0) * 0.5 + 0.5;
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(vec3(0.2, 0.55, 1.0), vec3(0.9, 0.98, 1.0), s * (1.0 - rim * 0.6));
	ALPHA = (0.45 + 0.55 * s) * fade;
}
"""


# ------------------------------------------------------------------ model
## Ön kol çerçevesi: +Z bileğe, +X kolun dış yüzü (ref Kote_2.png: gri kumaş bant, açık metal gövde, dişli halka, kartuş ağzı, topuz, ağızda kanatçıklar)
static func model(b: MB) -> void:
	var metal = Color(0.78, 0.8, 0.84)
	var dark = Color(0.27, 0.28, 0.3)
	var black = Color(0.03, 0.03, 0.04)
	b.add("cyl", Vector3(0, 0, -0.01), Vector3(0.112, 0.25, 0.112), dark, Vector3(90, 0, 0), 14)
	b.add("sphere", Vector3(0.055, 0, -0.005), Vector3(0.07, 0.11, 0.2), metal, Vector3.ZERO, 12)
	b.add("cyl", Vector3(0.088, 0, -0.04), Vector3(0.078, 0.014, 0.078), metal.darkened(0.08), Vector3(0, 0, 90), 16)
	b.add("cyl", Vector3(0.096, 0, -0.04), Vector3(0.05, 0.006, 0.05), black, Vector3(0, 0, 90), 14)
	for k in 8:
		var a = TAU * k / 8.0
		b.add("box", Vector3(0.092, sin(a) * 0.043, -0.04 + cos(a) * 0.043), Vector3(0.012, 0.014, 0.014), metal, Vector3(a * 57.3, 0, 0))
	b.add("box", Vector3(0.07, 0, 0.075), Vector3(0.022, 0.05, 0.036), black)
	for k in 4:
		b.add("box", Vector3(0.078, 0, 0.052 + k * 0.012), Vector3(0.012, 0.056, 0.004), metal.darkened(0.15))
	b.add("cyl", Vector3(0.07, -0.05, 0.0), Vector3(0.024, 0.03, 0.024), dark, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0.086, 0.04, 0.03), Vector3(0.026, 0.026, 0.026), Color(0.75, 0.9, 0.95), Vector3.ZERO, 8)


static func _build_orca() -> Mesh:
	var b = MB.new()
	var black = Color(0.06, 0.08, 0.12)
	var white = Color(0.88, 0.95, 1.0)
	b.add("sphere", Vector3.ZERO, Vector3(0.44, 0.44, 1.2), black, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, -0.1, -0.1), Vector3(0.3, 0.26, 0.95), white, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, 0.3, 0.05), Vector3(0.05, 0.34, 0.2), black, Vector3(-18, 0, 0), 4)
	for sx in [-1.0, 1.0]:
		b.add("box", Vector3(0.26 * sx, -0.08, -0.14), Vector3(0.26, 0.02, 0.14), black, Vector3(0, 0, -20 * sx))
		b.add("sphere", Vector3(0.14 * sx, 0.07, -0.42), Vector3(0.09, 0.05, 0.11), white, Vector3.ZERO, 6)
	b.add("box", Vector3(0, 0, 0.62), Vector3(0.36, 0.025, 0.12), black)
	return b.build(Props.toon())


static func _build_crescent() -> Mesh:
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var n = 20
	for i in n + 1:
		var u = float(i) / n
		var a = lerpf(-1.1, 1.1, u)
		var d = Vector3(sin(a), 0, -cos(a))
		v.append(d * 0.72)
		v.append(d * 1.0)
		uv.append(Vector2(u, 0))
		uv.append(Vector2(u, 1))
	for i in n:
		var q = i * 2
		idx.append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _build_ball() -> Mesh:
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 20
	s.rings = 12
	return s


# ------------------------------------------------------------------ yük
static func _load(who: Node3D) -> int:
	var now = Game.now()
	var v = float(who.get_meta("sg_load", float(LOAD_MAX)))
	var wait_end = float(who.get_meta("sg_last", -99.0)) + REGEN_WAIT
	if now > wait_end:
		var from_t = maxf(wait_end, float(who.get_meta("sg_t", wait_end)))
		v = minf(float(LOAD_MAX), v + (now - from_t) / REGEN)
	who.set_meta("sg_load", v)
	who.set_meta("sg_t", now)
	return int(v + 0.001)


static func _take(who: Node3D) -> bool:
	if _load(who) <= 0:
		Sfx.play("click", who.global_position + Vector3.UP * 1.2, 0.7, 0.7)
		if who is Player:
			Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Kartuş boş", Color(0.8, 0.84, 0.9))
		return false
	who.set_meta("sg_load", float(who.get_meta("sg_load")) - 1.0)
	who.set_meta("sg_last", Game.now())
	return true


static func _muzzle(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	return n.to_global(Vector3(0.08, 0, 0.13)) if n != null else who.global_position + Vector3.UP * 1.3 + who.face_dir() * 0.5


# ------------------------------------------------------------------ kartuşlar
static func _flame_vis(size: float) -> Node3D:
	var root = Node3D.new()
	Kit.quad(root, size, Kit.shader_mat("sg_flame", FLAME_SH))
	return root


static func _katon(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var burn = func(_p: Vector3, t: Node3D) -> void:
		if t != null and is_instance_valid(t) and t.has_method("apply_status"):
			t.apply_status("burn", 2.0)
	U.fire(who, from, (to - from).normalized() * 50.0, {"r": 0.28, "life": 1.3, "vis": _flame_vis(0.85), "hit": burn,
		"info": {"dmg": dmg * 1.05, "knock": 2.0, "kind": "light", "element": "katon", "hitstop": 0.03}})
	Sfx.play("fire", from, 1.5, 0.55)


static func _suiton(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var root = Node3D.new()
	var fish = MeshInstance3D.new()
	fish.mesh = Kit.cached_mesh("sg_orca", Callable(_build_orca))
	root.add_child(fish)
	var wet = func(_p: Vector3, t: Node3D) -> void:
		if t != null and is_instance_valid(t) and t.has_method("apply_status"):
			t.apply_status("wet", 5.0)
	U.fire(who, from, (to - from).normalized() * 36.0, {"r": 0.45, "life": 1.3, "vis": root, "hit": wet,
		"info": {"dmg": dmg * 1.15, "knock": 9.0, "kind": "heavy", "element": "suiton", "hitstop": 0.05}})
	Sfx.play("water", from, 1.2, 0.7)


static func _raiton(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var root = Node3D.new()
	Kit.scene().add_child(root)
	root.global_transform = Transform3D.IDENTITY
	var d = to - from
	var L = minf(d.length(), 24.0)
	var f = d.normalized()
	var side = f.cross(Vector3.UP).normalized()
	var im = ImmediateMesh.new()
	var n = 12
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n + 1:
		var u = float(i) / n
		var jag = (side * randf_range(-0.28, 0.28) + Vector3.UP * randf_range(-0.28, 0.28)) * sin(u * PI)
		var p = from + f * L * u + jag
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(p - Vector3.UP * 0.07)
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(p + Vector3.UP * 0.07)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("sg_bolt", BOLT_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 30.0
	root.add_child(mi)
	var tw = Kit.tween_param(mi, "fade", 1.0, 0.0, 0.2)
	tw.tween_callback(root.queue_free)
	var done: Array = []
	for k in 6:
		var c = from + f * L * (k + 0.5) / 6.0
		done.append_array(Combat.hit_sphere(who, c, 0.9, {"dmg": dmg * 0.95, "knock": 1.0, "stun": 0.45, "kind": "light", "element": "raiton", "hitstop": 0.04}, done))
	Sfx.play("zap", from, 1.15, 0.7)


static func _futon(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var root = Node3D.new()
	var c = MeshInstance3D.new()
	c.mesh = Kit.cached_mesh("sg_crescent", Callable(_build_crescent))
	c.material_override = Kit.shader_mat("sg_wind", WIND_SH)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.scale = Vector3.ONE * 1.5
	c.position = Vector3(0, 0, 1.0)
	root.add_child(c)
	U.fire(who, from, (to - from).normalized() * 44.0, {"r": 0.8, "life": 0.5, "pierce": true, "vis": root,
		"info": {"dmg": dmg * 0.9, "knock": 3.0, "kind": "light", "element": "fuuton", "hitstop": 0.03, "bleed": 1.5}})
	Sfx.play("wind", from, 1.4, 0.6)


## Kagemane: gölge yerde hedefe uzanır, değerse bağlar (kanon sealed technique; oyunun bağ durumu)
static func _shadow(who: Node3D, tg) -> void:
	var from = who.global_position
	var s = {"t": 0.0, "hit": false}
	var T = 0.34
	var HOLD = 0.75
	var im = ImmediateMesh.new()
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		if t >= T + HOLD or not is_instance_valid(who):
			return true
		var end: Vector3 = U.chest(tg) if U.alive(tg) else who.global_position + who.face_dir() * 12.0
		var k = clampf(t / T, 0.0, 1.0)
		var d = end - from
		d.y = 0.0
		var L = minf(d.length(), 15.0)
		var f = d.normalized() if d.length() > 0.05 else who.face_dir()
		var side = f.cross(Vector3.UP).normalized()
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 13:
			var u = i / 12.0 * k
			var q = from + f * L * u
			q.y = Game.jutsu_floor_at(q).y + 0.04
			var w = 0.2 + 0.06 * sin(u * 14.0 + t * 8.0)
			im.surface_set_uv(Vector2(u, 0))
			im.surface_add_vertex(q - side * w)
			im.surface_set_uv(Vector2(u, 1))
			im.surface_add_vertex(q + side * w)
		im.surface_end()
		if k >= 1.0 and not bool(s["hit"]):
			s["hit"] = true
			if U.alive(tg) and d.length() <= 15.5:
				if tg.has_method("apply_status"):
					tg.apply_status("bind", 1.1)
				Combat.popup_text(tg.global_position + Vector3.UP * 2.3, "Kagemane!", Color(0.7, 0.72, 0.8))
		return false
	var root = Kit.ticker(Vector3.ZERO, fn)
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("sg_shadow", SHADOW_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 30.0
	root.add_child(mi)
	Sfx.play("th_shadow", from, 1.1, 0.6)


static func _rasengan(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var root = Node3D.new()
	var ball = MeshInstance3D.new()
	ball.mesh = Kit.cached_mesh("sg_ball", Callable(_build_ball))
	ball.material_override = Kit.shader_mat("sg_spiral", SPIRAL_SH)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.8
	root.add_child(ball)
	var burst = func(p: Vector3, _t: Node3D) -> void:
		if not is_instance_valid(who):
			return
		Combat.hit_sphere(who, p, 2.0, {"dmg": dmg * 1.5, "knock": 12.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.08})
		_pop(p)
		Sfx.play("rasengan", p, 1.15, 0.8)
	U.fire(who, from, (to - from).normalized() * 28.0, {"r": 0.42, "life": 1.3, "vis": root, "hit": burst,
		"info": {"dmg": dmg * 0.4, "knock": 1.0, "kind": "light", "hitstop": 0.03}})
	Sfx.play("rasengan", from, 1.4, 0.55)


static func _pop(p: Vector3) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = Kit.cached_mesh("sg_ball", Callable(_build_ball))
	mi.material_override = Kit.shader_mat("sg_spiral", SPIRAL_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_position = p
	mi.scale = Vector3.ONE * 0.8
	mi.create_tween().tween_property(mi, "scale", Vector3.ONE * 3.0, 0.2)
	Kit.tween_param(mi, "fade", 1.0, 0.0, 0.2, true)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, _i: int) -> void:
	if who != null and is_instance_valid(who):
		U.face(who, U.aim_at(who, U.target_of(who)))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if not _take(who):
		return
	var tg = U.target_of(who)
	var to = U.aim_at(who, tg)
	U.face(who, to)
	var from = _muzzle(who)
	Sfx.play("click", from, 1.6, 0.4)
	if i == 0:
		_katon(who, from, to, dmg)
	elif i == 1:
		_suiton(who, from, to, dmg)
	elif i == 2:
		_raiton(who, from, to, dmg)
	elif i == 3:
		_futon(who, from, to, dmg)
	elif i == 4:
		_shadow(who, tg)
	else:
		_rasengan(who, from, to, dmg)
