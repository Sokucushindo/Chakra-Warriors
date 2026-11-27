extends RefCounted
## Senbon Hasshaki: model, hareketli namlu ve teller, zehirli iğneler (hedef: res://scripts/combat/fx/bilek_senbon_fx.gd).
## Kanon (Narutopedia "Wrist-Mounted Senbon Launcher", manga 156, anime 89; adı kanonda YOK, "Hasshaki" bizim adımız): Shizune kimono
## kolunun altında sağ kolunda taşır. Beş parçalı düzenek; üstteki namlularda iğneler zehre batırılmış bekler, teller çekilince fırlar.
## Zehri sıyrıkla bile zayıflatıp felç eder (Shizune, manga 485). Ref: beş gri gövde + kara kayış + toka, tel başına bir namlu.
## Zayıflık: beş atış; boşken tel boşa çekilir, doldurmak kombonun bir adımı. Yakın dövüş yeteneği yok.
## Silah uzayı (ön kol çerçevesi): +Z bileğe, +X kolun dış yüzü. Atışta düzenek kol çevresinde döner, namlular hedefe bakar.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const SPEED := 80.0
const GRAV := 0.8
const SHOTS := 5
const REFILL := 3.5     # kombo dışında kendiliğinden dolma süresi
const DOSE := 1.3       # iğne başına zehir süresi (sn), birikir
const DOSE_MAX := 9.0
const Z := [-0.128, -0.086, -0.044, -0.002, 0.04]
const TOP := 0.068

const STEEL := Color(0.52, 0.54, 0.6)
const STEEL_D := Color(0.33, 0.34, 0.39)
const STRAP := Color(0.07, 0.07, 0.08)
const POISON := Color(0.36, 0.2, 0.46)

static var _c := {}


class Rig extends Node3D:
	const U2 = preload("res://scripts/combat/fx/uzak_nisan.gd")
	var who: Node3D
	var n: Node3D
	var wires: MultiMesh
	var wire_mi: MultiMeshInstance3D
	var barrels: Array = []
	var tips: Array = []
	var kick := [0.0, 0.0, 0.0, 0.0, 0.0]
	var wire_k := 0.0
	var aim := Vector3.ZERO

	static func seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
		var y = b - a
		if y.length() < 0.0005:
			y = Vector3(0, 0, 0.0005)
		var yn = y.normalized()
		var xn = yn.cross(Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).normalized()
		return Transform3D(Basis(xn * w, y, xn.cross(yn) * w), (a + b) * 0.5)

	func setup(w: Node3D, node: Node3D, barrel: Mesh, tip: Mesh, wire: Mesh, zs: Array, top: float) -> void:
		who = w
		n = node
		name = "BilekRig"
		process_priority = 60
		wires = MultiMesh.new()
		wires.transform_format = MultiMesh.TRANSFORM_3D
		wires.mesh = wire
		wires.instance_count = zs.size()
		wire_mi = MultiMeshInstance3D.new()
		wire_mi.multimesh = wires
		wire_mi.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		wire_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wire_mi.visible = false
		add_child(wire_mi)
		for z in zs:
			var b = MeshInstance3D.new()
			b.mesh = barrel
			b.position = Vector3(top, 0.0, z)
			add_child(b)
			barrels.append(b)
			var t = MeshInstance3D.new()
			t.mesh = tip
			t.position = Vector3(0.026, 0, 0)
			b.add_child(t)
			tips.append(t)

	## Dolu namlular bilek tarafında kalır: atış dirsekten bileğe ilerler
	func show_loaded(count: int) -> void:
		for k in tips.size():
			tips[k].visible = k >= tips.size() - count

	func engage(a: Vector3) -> void:
		aim = a

	func _process(dt: float) -> void:
		if who == null or not is_instance_valid(who) or not is_instance_valid(n) or not n.is_visible_in_tree():
			return
		var m = who.get("model")
		if m == null or m.overlay == null:
			return
		var acting = m.drawn and m.overlay.key_t >= 0.0
		var roll = 0.0
		if acting and aim != Vector3.ZERO:   # namlular hedefe dönsün (kol kemiğinin kendi dönüşü belirsiz)
			var l: Vector3 = (n.get_parent() as Node3D).global_transform.basis.orthonormalized().inverse() * aim
			if Vector2(l.x, l.y).length() > 0.2:
				roll = atan2(l.y, l.x)
		n.rotation.z = lerp_angle(n.rotation.z, roll, minf(1.0, dt * 14.0))
		for k in barrels.size():
			if kick[k] > 0.0:
				kick[k] = maxf(0.0, kick[k] - dt * 5.0)
				var bn: Node3D = barrels[k]
				bn.position.x = 0.068 - 0.018 * kick[k]
		wire_k = move_toward(wire_k, 1.0 if acting else 0.0, dt * (9.0 if acting else 5.0))
		wire_mi.visible = wire_k > 0.01
		if wire_mi.visible:
			var hand: Vector3 = n.to_local(U2.fingers(who, "Left"))
			for k in barrels.size():
				var base: Vector3 = (barrels[k] as Node3D).position + Vector3(-0.012, 0.012, 0.0)
				wires.set_instance_transform(k, seg_xf(base, base.lerp(hand, wire_k), 0.0028))


# ------------------------------------------------------------------ modeller
static func _barrel_mb(b: MB, o: Vector3) -> void:
	b.add("cyl", o, Vector3(0.026, 0.038, 0.026), STEEL, Vector3(0, 0, 90), 10)
	b.add("cyl", o + Vector3(0.019, 0, 0), Vector3(0.019, 0.004, 0.019), STEEL_D, Vector3(0, 0, 90), 10)


static func _tip_mb(b: MB, o: Vector3) -> void:
	b.add("cone", o, Vector3(0.007, 0.024, 0.007), POISON.lightened(0.45), Vector3(0, 0, -90), 5)


## Kayışlar, gri gövdeler, tokalar (ref: gövde kolun üstünde, toka altında)
static func build_body(b: MB) -> void:
	for z in Z:
		b.add("torus", Vector3(0, 0, z), Vector3(0.106, 0.2, 0.106), STRAP, Vector3(90, 0, 0), 16)
		b.add("box", Vector3(0.056, 0, z), Vector3(0.016, 0.032, 0.03), STEEL)
		b.add("box", Vector3(0.056, 0, z + 0.012), Vector3(0.018, 0.034, 0.004), STEEL_D)
		b.add("box", Vector3(-0.056, 0, z), Vector3(0.006, 0.03, 0.026), STEEL_D)
		b.add("box", Vector3(-0.059, 0, z), Vector3(0.004, 0.018, 0.016), STRAP)


static func build_full(b: MB) -> void:
	build_body(b)
	for z in Z:
		_barrel_mb(b, Vector3(TOP, 0, z))
		_tip_mb(b, Vector3(TOP + 0.026, 0, z))


static func _mesh(key: String, fn: Callable) -> Mesh:
	return Kit.cached_mesh("bilek_" + key, func():
		var b = MB.new()
		fn.call(b)
		return b.build(LazyFx.g("Props").toon()))


static func _needle_mesh() -> Mesh:
	return _mesh("igne", func(b: MB):
		b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.006, 0.2, 0.006), Color(0.78, 0.8, 0.85), Vector3(90, 0, 0), 4)
		b.add("cyl", Vector3(0, 0, 0.185), Vector3(0.0072, 0.05, 0.0072), POISON, Vector3(90, 0, 0), 4))


static func rig_of(who: Node3D) -> Rig:
	var n = U.weapon_node(who, "bilek_senbon")
	if n == null or not (n is MeshInstance3D):
		return null
	var r = n.get_node_or_null("BilekRig")
	if r != null:
		return r
	var rig = Rig.new()
	n.add_child(rig)
	(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("bilek_senbon_k")
	rig.setup(who, n,
		_mesh("namlu", func(b: MB): _barrel_mb(b, Vector3.ZERO)),
		_mesh("uc", func(b: MB): _tip_mb(b, Vector3.ZERO)),
		_mesh("tel", func(b: MB): b.add("cyl", Vector3.ZERO, Vector3.ONE, Color(0.22, 0.24, 0.2), Vector3.ZERO, 4)),
		Z, TOP)
	rig.show_loaded(_ammo(who))
	return rig


# ------------------------------------------------------------------ cephane
static func _ammo(who: Node3D) -> int:
	if Game.now() - float(who.get_meta("bs_t", -99.0)) > REFILL:
		who.set_meta("bs_dolu", SHOTS)
	return int(who.get_meta("bs_dolu", SHOTS))


static func _reload(who: Node3D, delay: float, dur: float) -> void:
	who.set_meta("bs_dolu", 0)
	who.set_meta("bs_t", Game.now() + delay + dur)
	var r0 = rig_of(who)
	if r0 != null:
		r0.show_loaded(0)
	for k in SHOTS:
		who.get_tree().create_timer(delay + dur * float(k + 1) / SHOTS).timeout.connect(func():
			if not is_instance_valid(who):
				return
			var c = mini(SHOTS, int(who.get_meta("bs_dolu", 0)) + 1)
			who.set_meta("bs_dolu", c)
			who.set_meta("bs_t", Game.now())
			var r = rig_of(who)
			if r != null:
				r.show_loaded(c)
			Sfx.play("click", who.global_position + Vector3.UP * 1.2, 1.5 + k * 0.08, 0.25))


# ------------------------------------------------------------------ zehir (oyuncu + düşman aynı)
static func dose(t: Node3D, d: float) -> void:
	if t == null or not is_instance_valid(t) or not t.has_method("apply_status") or t.get("statuses") == null:
		return
	load("res://scripts/combat/fx/doku_fx.gd").add(t, d)
	var now = Game.now()
	var nd = (int(t.get_meta("bs_doz", 0)) if now - float(t.get_meta("bs_doz_t", -99.0)) < 6.0 else 0) + 1
	t.set_meta("bs_doz_t", now)
	if nd >= 5:   # kanon: zehir felç eder
		t.apply_status("stun", 1.1)
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Felç!", POISON.lightened(0.5))
		nd = 0
	elif nd >= 3:
		t.apply_status("slow", 2.5)
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Zehir", POISON.lightened(0.5))
	t.set_meta("bs_doz", nd)


static func _needle(who: Node3D, k: int, to: Vector3, dmg: float, d: float) -> void:
	var n = U.weapon_node(who, "bilek_senbon")
	var from: Vector3 = n.to_global(Vector3(TOP + 0.04, 0, Z[k])) if n != null else who.global_position + Vector3.UP * 1.3 + who.face_dir() * 0.4
	var m = _needle_mesh()
	var dir: Vector3 = (to - from).normalized()
	var cb = func(pos: Vector3, tgt: Node3D) -> void:
		if tgt == null or not is_instance_valid(tgt):
			return
		Sfx.play("hit_claw", pos, 1.8, 0.28)
		var mi = MeshInstance3D.new()
		mi.mesh = m
		U.pin(mi, tgt, pos - dir * 0.14, dir, 2.2)
		dose(tgt, d)
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = m
	v.rotation.y = PI
	v.position = Vector3(0, 0, 0.1)
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(v)
	U.fire(who, from, U.solve(from, to, SPEED, GRAV), {"g": GRAV, "r": 0.09, "life": 1.6, "stick": true, "vis": root, "hit": cb,
		"info": {"dmg": dmg, "knock": 0.5, "kind": "light", "hitstop": 0.0}})


## count namluyu ateşler; off(j) nişan kayması. Dolu namlu yoksa tel boşa çekilir.
static func _volley(who: Node3D, count: int, gap: float, aim: Vector3, tg: Node3D, off: Callable, dmg: float, d: float) -> void:
	var have = _ammo(who)
	var rig = rig_of(who)
	if have <= 0:
		Sfx.play("click", who.global_position + Vector3.UP * 1.3, 0.6, 0.6)
		if who is Player:
			Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Namlular boş", Color(0.8, 0.82, 0.88))
		return
	var n = mini(count, have)
	who.set_meta("bs_t", Game.now())
	for j in n:
		var fire_one = func():
			if not is_instance_valid(who):
				return
			var left = int(who.get_meta("bs_dolu", 0))
			if left <= 0:
				return
			var k = SHOTS - left
			who.set_meta("bs_dolu", left - 1)
			who.set_meta("bs_t", Game.now())
			if rig != null and is_instance_valid(rig):
				rig.kick[k] = 1.0
				rig.show_loaded(left - 1)
			var p: Vector3 = U.chest(tg) if U.alive(tg) else aim
			_needle(who, k, p + (off.call(j) as Vector3), dmg, d)
			Sfx.play("chain", who.global_position + Vector3.UP * 1.3, 2.3, 0.14)   # sessize yakın tel sesi
		if j == 0 or gap <= 0.0:
			fire_one.call()
		else:
			who.get_tree().create_timer(j * gap).timeout.connect(fire_one)


# ------------------------------------------------------------------ kombo bağlantıları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var p = U.aim_at(who, U.target_of(who))
	U.face(who, p)
	var rig = rig_of(who)
	if rig != null:
		rig.engage((p - (who.global_position + Vector3.UP * 1.3)).normalized())
		rig.show_loaded(_ammo(who))
	match i:
		3:
			_reload(who, 0.12, 0.42)
			if who is CharacterBody3D:   # dolum sırasında mesafe açar
				var f: Vector3 = who.face_dir()
				who.velocity.x = -f.x * 7.0
				who.velocity.z = -f.z * 7.0
				who.velocity.y = 4.0
		5:
			_reload(who, 0.12, 0.45)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if i == 3:
		return
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var f = (aim - who.global_position)
	f.y = 0.0
	var side: Vector3 = Vector3.UP.cross(f.normalized() if f.length() > 0.05 else who.face_dir()).normalized()
	var none = func(_j: int) -> Vector3: return Vector3.ZERO
	match i:
		0, 1:
			_volley(who, 1, 0.0, aim, tg, none, dmg * 0.8, DOSE)
		2:   # Mitsu-uchi: kalan namlular yelpaze
			var fan = func(j: int) -> Vector3:
				return side * (j - 1) * 0.85
			_volley(who, 3, 0.0, aim, tg, fan, dmg * 0.55, DOSE * 0.8)
		4:   # Renpatsu: dirsekten bileğe art arda
			_volley(who, SHOTS, 0.075, aim, tg, none, dmg * 0.42, DOSE * 0.7)
		5:   # Gorenshi: beşi aynı noktaya
			_volley(who, SHOTS, 0.0, aim, tg, none, dmg * 0.62, DOSE * 1.1)
