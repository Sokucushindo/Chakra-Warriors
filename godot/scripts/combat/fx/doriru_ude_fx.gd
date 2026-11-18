extends RefCounted
## Doriru Ude (mekanik matkap kol; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/doriru_ude_fx.gd). Kanon (Narutopedia "Mechanical Drilling Arm", Toki / Shinobazu, anime 209):
## eldiven gibi takılır; koni avuç ve beş uzun parmaktan oluşan el gövdeden bağımsız döner, uzun kabloyla fırlar ve geri gelir. Yeri deler, içinden dalıp rakibi şaşırtır; tek darbesi ölümcül, hendek ve mağara açar.
## Görünüş refs/doriru_ude: koyu bronz yumurta gövde, boğumlu kıvrık beş parmak.
## Oyunda: el gerçekten döner; fırlatma, yere dalma (yeraltındayken vurulamaz), hendek, uzun kurulumlu tek delme. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const ID := "doriru_ude"
const HEAD := Vector3(0, 0, 0.26)
const REACH := 11.0
const DIVE_T := 0.8

const DUST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float w = 0.5 + 0.5 * sin(UV.x * 34.0 - TIME * 40.0);
	if (v < 0.25 + 0.4 * w * UV.x) discard;
	ALBEDO = mix(vec3(0.34, 0.27, 0.2), vec3(0.62, 0.53, 0.42), w);
	ALPHA = fade_k * (1.0 - UV.x * 0.6);
}
"""


class Spin extends Node3D:
	var rate := 3.0
	var want := 3.0
	func _process(dt: float) -> void:
		rate = move_toward(rate, want, dt * 70.0)
		rotate_object_local(Vector3.BACK, rate * dt)


static func model_body(b: MB) -> void:
	var bronze = Color(0.34, 0.31, 0.26)
	var dark = Color(0.17, 0.16, 0.14)
	Loft.tube(b, [Vector3(0, 0, -0.16), Vector3(0, 0, -0.06), Vector3(0, 0, 0.08), Vector3(0, 0, 0.2), Vector3(0, 0, 0.27)], [0.07, 0.17, 0.2, 0.18, 0.13], bronze, 18, 3)
	for z in [-0.03, 0.12]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.39 if z > 0.0 else 0.36, 0.01, 0.39 if z > 0.0 else 0.36), dark, Vector3(90, 0, 0), 18)


static func model_head(b: MB) -> void:
	var c = Color(0.42, 0.38, 0.32)
	var dark = Color(0.22, 0.2, 0.17)
	b.add("cone", Vector3(0, 0, 0.08), Vector3(0.26, 0.18, 0.26), dark, Vector3(90, 0, 0), 14)
	for k in 5:
		var a = k * TAU / 5.0
		var n = Vector3(cos(a), sin(a), 0)
		var pts = [n * 0.11, n * 0.16 + Vector3(0, 0, 0.11), n * 0.14 + Vector3(0, 0, 0.27), n * 0.06 + Vector3(0, 0, 0.44)]
		Loft.tube(b, pts, [0.036, 0.034, 0.025, 0.002], c, 8, 3)
		b.add("cyl", n * 0.16 + Vector3(0, 0, 0.12), Vector3(0.078, 0.012, 0.078), dark, Vector3(90, 0, 0), 8)


static func model(b: MB) -> void:
	model_body(b)
	var h = MB.new()
	model_head(h)
	b.add_mesh(h, Transform3D(Basis.IDENTITY, HEAD))


static func _cable() -> Mesh:
	return Yk.mesh("doriru_kablo", func():
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.024, 0.08, 0.024), Color(0.12, 0.12, 0.13), Vector3(90, 0, 0), 5)
		return b.build(Props.toon()))


## Kol kurulumu: gövde sabit, el dönen ayrı düğüm
static func attach(node: Node3D) -> void:
	if not node is MeshInstance3D:
		return
	(node as MeshInstance3D).mesh = CharacterModel.weapon_mesh("doriru_ude_g")
	var sp = Spin.new()
	sp.position = HEAD
	node.add_child(sp)
	var m = MeshInstance3D.new()
	m.mesh = CharacterModel.weapon_mesh("doriru_ude_e")
	sp.add_child(m)
	node.set_meta("dr_el", sp)


static func _head(who: Node3D):
	var n = Yk.node_of(who, ID)
	if n == null or not n.has_meta("dr_el"):
		return null
	var h = n.get_meta("dr_el")
	return h if is_instance_valid(h) else null


static func _rev(who: Node3D, r: float, dur: float) -> void:
	var h = _head(who)
	if h == null:
		return
	h.want = r
	Yk.after(who, dur, func():
		var h2 = _head(who)
		if h2 != null:
			h2.want = 3.0)


static func _spray(p: Vector3, d: Vector3, n: int) -> void:
	var m = Yk.mat("doriru_toz", DUST_SH)
	for k in n:
		var dir = (d + Vector3(randf_range(-0.7, 0.7), randf_range(0.2, 1.0), randf_range(-0.7, 0.7))).normalized()
		var pts = [p, p + dir * 0.6 + Vector3.UP * 0.05, p + dir * 1.25 + Vector3.DOWN * 0.15]
		Yk.fade(Yk.strip(pts, 0.05, m, 0.5), 0.08, 0.16)


## Yere dalar, hedefin arkasından çıkar. Yeraltındayken vurulamaz (oyuncu: kaçış penceresi; düşman: yer değiştirme penceresi).
static func _dive(who: Node3D) -> void:
	var f = Yk.face(who)
	var from: Vector3 = who.global_position
	var tg = U.target_of(who)
	var dest: Vector3
	if U.alive(tg) and from.distance_to(tg.global_position) < 18.0:
		var b: Vector3 = -tg.face_dir() if tg.has_method("face_dir") else f
		dest = tg.global_position + b * 1.6
	else:
		dest = from + f * 9.0
	dest.y = Game.ground_height(dest.x, dest.z)
	var m = who.get("model")
	_spray(Yk.gp(from + f * 0.8), Vector3.UP, 10)
	Sfx.play("earth", from, 0.8, 0.8)
	Yk.after(who, 0.16, func():
		if m != null and is_instance_valid(m):
			m.visible = false)
	var tw = who.create_tween()
	tw.tween_interval(0.16)
	tw.tween_method(func(u: float):
		if not is_instance_valid(who):
			return
		if who is Player:
			who.evade_t = 0.47
			who.evade_inv = 0.47
		elif who.get("sub_inv") != null:
			who.sub_inv = 0.2
		var p = from.lerp(dest, u)
		p.y = Game.ground_height(p.x, p.z)
		who.global_position = p
		if who is CharacterBody3D:
			who.velocity = Vector3.ZERO, 0.0, 1.0, DIVE_T)
	tw.tween_callback(func():
		if m != null and is_instance_valid(m):
			m.visible = true
		if is_instance_valid(who):
			U.face(who, U.aim_at(who, tg))
			_spray(Yk.gp(who.global_position), Vector3.UP, 12)
			Sfx.play("earth", who.global_position, 1.0, 0.9))


static func _fire_hand(who: Node3D, dmg: float) -> void:
	var scene = Yk.root()
	var h = _head(who)
	if scene == null or h == null:
		return
	var f = Yk.face(who)
	var tg = U.target_of(who)
	var a: Vector3 = (h as Node3D).global_position
	var end: Vector3 = U.chest(tg) if U.alive(tg) and a.distance_to(U.chest(tg)) < REACH else a + f * REACH
	var c = MeshInstance3D.new()
	c.mesh = CharacterModel.weapon_mesh("doriru_ude_e")
	scene.add_child(c)
	(h as Node3D).visible = false
	var cable = Yk.chain(scene, _cable(), func(): return (h as Node3D).global_position if is_instance_valid(h) else a, func(): return c.global_position if is_instance_valid(c) else a, 0.62, 80, 0.14, 0.05)
	var b = Basis.looking_at(-(end - a).normalized(), Vector3.UP)
	var tw = c.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(c):
			c.global_transform = Transform3D(b * Basis(Vector3.BACK, u * 40.0), a.lerp(end, u)), 0.0, 1.0, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(who):
			for x in Combat.hit_sphere(who, end, 1.4, {"dmg": dmg, "knock": 2.0, "kind": "heavy", "hitstop": 0.06, "melee": false}):
				if x is CharacterBody3D:
					x.velocity = (who.global_position - x.global_position).normalized() * 12.0 + Vector3.UP * 2.0
		_spray(end, Vector3.UP, 5))
	tw.tween_interval(0.08)
	tw.tween_method(func(u: float):
		if is_instance_valid(c) and is_instance_valid(h):
			c.global_position = end.lerp((h as Node3D).global_position, u), 0.0, 1.0, 0.26)
	tw.tween_callback(func():
		if is_instance_valid(h):
			(h as Node3D).visible = true
		if is_instance_valid(cable):
			cable.queue_free()
		c.queue_free())
	Sfx.play("chain", a, 0.8, 0.8)


static func _trench(who: Node3D, dmg: float) -> void:
	var f = Yk.face(who)
	var o: Vector3 = who.global_position + f * 1.5
	Yk.shake(who, 0.35)
	for k in 6:
		Yk.after(who, k * 0.05, func():
			var q: Vector3 = Yk.gp(o + f * (float(k) * 1.5))
			_spray(q, Vector3.UP, 4)
			Sfx.play("earth", q, 1.1, 0.35)
			Combat.hit_sphere(who, q + Vector3.UP * 0.7, 1.4, {"dmg": dmg * 0.24, "knock": 1.5, "launch": 4.5, "kind": "heavy", "hitstop": 0.02, "melee": false}))


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	match i:
		0:
			_rev(who, 26.0, 0.7)
		1:
			_rev(who, 42.0, 1.0)
		3:
			_rev(who, 48.0, 1.3)
			Yk.after(who, 0.18, func():
				_dive(who))
		4:
			_rev(who, 42.0, 1.0)
		5:
			_rev(who, 60.0, 1.5)   # uzun kurulum: el giderek hızlanır, rakip görür
			Sfx.play("wind", who.global_position, 0.7, 0.6)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Yk.face(who)
	var h = _head(who)
	var p: Vector3 = (h as Node3D).global_position if h != null else who.global_position + Vector3.UP * 1.2 + f
	match i:
		0, 1:
			_spray(p + f * 0.4, f, 4)
		2:
			_fire_hand(who, dmg * 0.8)
		3:
			Combat.hit_sphere(who, who.global_position + Vector3.UP + f, 2.0, {"dmg": dmg * 1.1, "knock": 2.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.07, "melee": false})
		4:
			_trench(who, dmg)
		5:
			_spray(p + f * 0.5, f, 10)
			Yk.shake(who, 0.5)
			Combat.hit_zone(who, who.global_position, f, 3.0, 24.0, 2.3, {"dmg": dmg * 1.3, "knock": 6.0, "kind": "heavy", "hitstop": 0.1, "melee": false, "pierce_guard": true})
			Sfx.play("hit_heavy_weapon", p, 0.6, 1.0)
