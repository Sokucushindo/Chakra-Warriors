extends RefCounted
## Kusari Fūbō (鎖風棒; hedef: res://scripts/combat/fx/kusari_fubo_fx.gd). Kanon (Narutopedia "Chain Wind Staff", yalnız ANİME, bölüm 162, Tenten):
## kısa sopa, iki ucunda ağırlıklı zincir; bumerang gibi atılır; dönen zincirler Lanetli Savaşçı'nın miğferini kesti.
## Ref: kızıl gövde, altın uçlar, kara zincir, kara çan ağırlık. Zırh kesme: bitirişte isabet alan "zırhı kırık" olur.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/kusari_fubo_anim.gd")
const Z = preload("res://scripts/combat/fx/zincir_uc.gd")

const L := 0.82
const ENDS := [Vector3(0, 0, -0.2), Vector3(0, 0, 0.3)]
const RED := Color(0.45, 0.16, 0.2)
const GOLD := Color(0.76, 0.68, 0.38)


static func model(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.05), Vector3(0.05, 0.36, 0.05), RED, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.16), Vector3(0.056, 0.08, 0.056), GOLD, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.26), Vector3(0.044, 0.07, 0.044), GOLD, Vector3(90, 0, 0), 8)


static func _bell() -> Mesh:
	return Kit.cached_mesh("fubo_can", func():
		var b = MB.new()
		var blk = Color(0.08, 0.08, 0.1)
		b.add("frustum", Vector3(0, 0, 0.065), Vector3(0.11, 0.13, 0.11), blk, Vector3(-90, 0, 0), 10)
		b.add("sphere", Vector3(0, 0, 0.13), Vector3(0.11, 0.11, 0.05), blk, Vector3.ZERO, 10)
		b.add("box", Vector3(0.03, 0.03, 0.08), Vector3(0.008, 0.012, 0.07), Color(0.42, 0.42, 0.46))
		return b.build(Props.toon()))


static func _link() -> Mesh:
	return Kit.cached_mesh("fubo_halka", func():
		var b = MB.new()
		b.add("torus", Vector3.ZERO, Vector3(0.065, 0.09, 0.03), Color(0.1, 0.1, 0.12), Vector3.ZERO, 8)
		return b.build(Props.toon()))


static func attach(node: Node3D, owner_body: Node3D) -> void:
	for k in 2:
		var c = Z.new()
		c.name = "FuboZincir%d" % k
		node.add_child(c)
		c.setup(owner_body, node, ENDS[k], _bell(), _link(), L)


static func _chains(n: Node3D) -> Array:
	return [n.get_node_or_null("FuboZincir0"), n.get_node_or_null("FuboZincir1")]


static func _axes(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized(), who.global_position + Vector3.UP * 1.25]


## El çevresinde yatay yay
static func _sweep(who: Node3D, a0: float, a1: float, r: float) -> Callable:
	return func(k: float, a: Vector3) -> Vector3:
		if not is_instance_valid(who):
			return a
		var x = _axes(who)
		var e = lerpf(a0, a1, k * k)
		return (x[2] as Vector3) + ((x[0] as Vector3) * cos(e) + (x[1] as Vector3) * sin(e)) * r


## Önde, bakış eksenine dik dönen çark
static func _wheel(who: Node3D, ph: float, turns: float) -> Callable:
	return func(k: float, a: Vector3) -> Vector3:
		if not is_instance_valid(who):
			return a
		var x = _axes(who)
		var e = ph + k * TAU * turns
		return (x[2] as Vector3) + (x[0] as Vector3) + ((x[1] as Vector3) * cos(e) + Vector3.UP * sin(e)) * 1.05


static func _drive(c, T: float, path: Callable) -> void:
	if c != null:
		c.drive(T, path)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	var n = U.weapon_node(who, "kusari_fubo")
	if n == null:
		return
	var c = _chains(n)
	var hit = float(A.HIT[clampi(i, 0, 5)]) + 0.04
	match i:
		0:
			_drive(c[1], hit, _sweep(who, 2.5, -0.7, 1.9))
		1:
			_drive(c[0], hit, _sweep(who, -2.5, 0.7, 1.9))
		2:
			_drive(c[0], hit, _sweep(who, 2.4, 0.35, 2.0))
			_drive(c[1], hit, _sweep(who, -2.4, -0.35, 2.0))
		3:
			_drive(c[0], 0.8, _wheel(who, 0.0, 4.0))
			_drive(c[1], 0.8, _wheel(who, PI, 4.0))
	Sfx.play("swing_chain", who.global_position + Vector3.UP, 1.15, 0.35)


## Bumerang: sopa uçar, kendi çevresinde döner, ağırlıklar çark olur, ele döner
static func _throw(who: Node3D, dmg: float, T: float, hold: float, armor: bool) -> void:
	var n = U.weapon_node(who, "kusari_fubo")
	if n == null or not (n is MeshInstance3D):
		return
	var tg = U.target_of(who)
	var from: Vector3 = n.global_position
	var aim = U.aim_at(who, tg)
	var d = aim - from
	if d.length() > 11.0:
		aim = from + d.normalized() * 11.0
	var body_mesh = CharacterModel.weapon_mesh("kusari_fubo")
	var fly = MeshInstance3D.new()
	fly.mesh = body_mesh
	Kit.scene().add_child(fly)
	fly.global_position = from
	(n as MeshInstance3D).mesh = null   # gizleme yerine: zincirler bu düğümün çocuğu, görünür kalmalı
	var c = _chains(n)
	for k in 2:
		if c[k] != null:
			c[k].anchor = fly
			var ph = k * PI
			var orbit = func(u: float, a: Vector3) -> Vector3:
				var e = ph + u * TAU * T * 3.2
				var o: Vector3 = fly.global_position if is_instance_valid(fly) else a
				return o + Vector3(cos(e), 0.12 * sin(e * 2.0), sin(e)) * 1.15
			c[k].drive(T, orbit)
	var st = {"n": 0, "seen": {}}
	var step = func(u: float) -> void:
		if not is_instance_valid(fly) or not is_instance_valid(who) or not is_instance_valid(n):
			return
		var out = 0.5 - hold * 0.5
		var hand: Vector3 = n.global_position
		var c2: Vector3 = U.chest(tg) if U.alive(tg) else aim
		var p: Vector3 = c2
		if u < out:
			p = from.lerp(c2, sin(u / out * PI * 0.5))
		elif u >= out + hold:
			var v = (u - out - hold) / maxf(1.0 - out - hold, 0.01)
			p = c2.lerp(hand, v * v)
		fly.global_position = p
		fly.rotation = Vector3(PI * 0.5, u * T * 24.0, 0.0)
		st["n"] = int(st["n"]) + 1
		if int(st["n"]) % 7 == 0:
			var hits = Combat.hit_sphere(who, p, 1.65, {"dmg": dmg * 0.34, "knock": 1.5, "kind": "light", "hitstop": 0.015, "melee": false})
			for h in hits:
				if armor and h.has_method("apply_status"):
					h.apply_status("armor_broken", 5.0)
					if not (st["seen"] as Dictionary).has(h):
						st["seen"][h] = true
						Combat.popup_text(h.global_position + Vector3.UP * 2.2, "Zırh kesildi!", GOLD)
	var done = func() -> void:
		if is_instance_valid(n):
			(n as MeshInstance3D).mesh = body_mesh
			for ch in _chains(n):
				if ch != null:
					ch.anchor = n
		if is_instance_valid(fly):
			fly.queue_free()
	var tw = fly.create_tween()
	tw.tween_method(step, 0.0, 1.0, T)
	tw.tween_callback(done)
	Sfx.play("wind", from, 1.5, 0.45)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	Sfx.play("hit_chain", who.global_position + Vector3.UP, 1.1, 0.35)
	match i:
		4:
			_throw(who, dmg, 0.85, 0.0, false)
		5:
			_throw(who, dmg * 1.35, 1.25, 0.32, true)
