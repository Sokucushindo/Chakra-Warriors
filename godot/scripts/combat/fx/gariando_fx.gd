extends RefCounted
## Gariantō (ガリアン刀; hedef: res://scripts/combat/fx/gariando_fx.gd). Kanon (Narutopedia "Garian Sword", ANİME 217; Hōki, Ryūgan, Seimei): içinden tel geçen üç çatallı kılıç;
## ağız açılıp urumi gibi uzanır, hedefi kovalar. Ağızlar chakraya tepki verir: chakrayı büyütür, ejderhaya dönüşür, kukla gibi yönetilir.
## Ref refs/gariando: mavi üç çatal, altın balçak, yeşil taş; Garian_Sword3: soluk mavi, dişli ejder başı, yeşil göz.
## Üç ağız gerçek zincir düğümleriyle uzar (zincir_uc.gd). Bitiriş chakra ister; yoksa üç ağız düz saplanır.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/gariando_anim.gd")
const Z = preload("res://scripts/combat/fx/zincir_uc.gd")

const BLUE := Color(0.25, 0.32, 0.78)
const BLUE_L := Color(0.42, 0.5, 0.88)
const GOLD := Color(0.86, 0.76, 0.46)
const PALE := Color(0.72, 0.78, 0.96)
const OFFS := [Vector3(0, 0.055, 0.2), Vector3(0, 0, 0.26), Vector3(0, -0.055, 0.2)]
const DRAGON_COST := 0.08


static func _hilt(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, -0.1), Vector3(0.032, 0.2, 0.032), Color(0.82, 0.78, 0.76), Vector3(90, 0, 0), 8)
	b.add_slab(PackedVector2Array([Vector2(-0.13, 0.05), Vector2(-0.1, 0.0), Vector2(0.1, 0.0), Vector2(0.13, 0.05), Vector2(0.05, 0.04), Vector2(-0.05, 0.04)]), 0.036, GOLD)
	b.add("torus", Vector3(0, 0, -0.215), Vector3(0.07, 0.12, 0.07), GOLD, Vector3(90, 0, 0), 12)
	b.add("sphere", Vector3(0, 0, -0.215), Vector3.ONE * 0.044, Color(0.25, 0.72, 0.56), Vector3.ZERO, 10)


## Tam kılıç: üç çatal, kademeli plakalar
static func build(b: MB) -> void:
	_hilt(b)
	b.add_slab(PackedVector2Array([Vector2(-0.085, 0.04), Vector2(0.085, 0.04), Vector2(0.09, 0.2), Vector2(0.05, 0.27), Vector2(-0.05, 0.27), Vector2(-0.09, 0.2)]), 0.018, BLUE)
	b.add_slab(PackedVector2Array([Vector2(-0.032, 0.26), Vector2(0.032, 0.26), Vector2(0.032, 0.9), Vector2(0.0, 1.06), Vector2(-0.032, 0.9)]), 0.018, BLUE)
	b.add("box", Vector3(0.0, 0, 0.62), Vector3(0.022, 0.016, 0.6), BLUE_L)
	for sy in [-1.0, 1.0]:
		b.add_slab(PackedVector2Array([Vector2(sy * 0.05, 0.22), Vector2(sy * 0.09, 0.2), Vector2(sy * 0.09, 0.62), Vector2(sy * 0.07, 0.74), Vector2(sy * 0.05, 0.62)]), 0.016, BLUE)
	for z in [0.36, 0.5, 0.64, 0.78]:
		b.add("box", Vector3(0, 0, z), Vector3(0.021, 0.064, 0.005), BLUE.darkened(0.4))


static func build_hilt(b: MB) -> void:
	_hilt(b)
	b.add_slab(PackedVector2Array([Vector2(-0.085, 0.04), Vector2(0.085, 0.04), Vector2(0.09, 0.2), Vector2(0.05, 0.27), Vector2(-0.05, 0.27), Vector2(-0.09, 0.2)]), 0.018, BLUE)


static func _tip() -> Mesh:
	return Kit.cached_mesh("garian_uc", func():
		var b = MB.new()
		b.add_slab(PackedVector2Array([Vector2(-0.032, -0.02), Vector2(0.032, -0.02), Vector2(0.032, 0.1), Vector2(0.0, 0.24), Vector2(-0.032, 0.1)]), 0.016, BLUE)
		return b.build(LazyFx.g("Props").toon()))


static func _plate() -> Mesh:
	return Kit.cached_mesh("garian_plaka", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.082, 0.05, 0.014), BLUE)
		b.add("box", Vector3(0, 0, 0.008), Vector3(0.05, 0.022, 0.004), BLUE_L)
		return b.build(LazyFx.g("Props").toon()))


static func _dragon_body() -> Mesh:
	return Kit.cached_mesh("garian_govde", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.12, 0.2, 0.2), PALE, Vector3.ZERO, 8)
		return b.build(LazyFx.g("Props").toon()))


## Ejder başı (+Z ileri): uzun yassı burun, tepe boynuzu, diş sırası, yeşil göz
static func _dragon_head() -> Mesh:
	return Kit.cached_mesh("garian_ejder", func():
		var b = MB.new()
		b.add("sphere", Vector3(0, 0.02, 0.2), Vector3(0.26, 0.2, 0.56), PALE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, -0.075, 0.24), Vector3(0.2, 0.07, 0.44), BLUE_L, Vector3.ZERO, 10)
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.07, 0.16, -0.02), Vector3(0.09, 0.3, 0.09), PALE, Vector3(-55, 0, sx * -12.0), 6)
			b.add("sphere", Vector3(sx * 0.115, 0.05, 0.2), Vector3(0.03, 0.04, 0.05), Color(0.2, 0.68, 0.46), Vector3.ZERO, 8)
			for k in 6:
				b.add("cone", Vector3(sx * (0.085 - k * 0.008), -0.05, 0.1 + k * 0.05), Vector3(0.024, 0.05, 0.024), Color(0.96, 0.97, 1.0), Vector3(180, 0, 0), 4)
		return b.build(LazyFx.g("Props").toon()))


static func _node(who: Node3D) -> MeshInstance3D:
	return U.weapon_node(who, "gariando") as MeshInstance3D


static func _rig(who: Node3D) -> Node3D:
	var n = _node(who)
	if n == null:
		return null
	var r = n.get_node_or_null("GarianRig")
	if r != null:
		return r
	r = Node3D.new()
	r.name = "GarianRig"
	r.visible = false
	n.add_child(r)
	for k in 3:
		var c = Z.new()
		c.name = "Agiz%d" % k
		r.add_child(c)
		c.setup(who, n, OFFS[k], _tip(), _plate(), 0.9)
		c.set_process(false)
	return r


static func _face(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized(), who.global_position + Vector3.UP * 1.25]


## j: -1, 0, 1 (üç ağız). hk: vuruş anının k karşılığı
static func _tip_pos(who: Node3D, i: int, j: int, k: float, hk: float, tg: Node3D) -> Vector3:
	var x = _face(who)
	var f: Vector3 = x[0]
	var s: Vector3 = x[1]
	var c: Vector3 = x[2]
	var u = minf(k / hk, 1.0)
	var e = u * u * (3.0 - 2.0 * u)
	var goal: Vector3 = U.chest(tg) if U.alive(tg) and tg.global_position.distance_to(who.global_position) < 8.0 else c + f * 5.4
	var a := 0.0
	match i:
		0:
			return c.lerp(goal + s * j * 0.22, e)
		1:
			a = lerpf(2.2, -1.0, u * u) + j * 0.18
			return c + (f * cos(a) + s * sin(a)) * 3.8
		2:
			a = k * TAU * 3.0 + j * 2.09
			return c.lerp(goal, e) + (s * cos(a) + Vector3.UP * sin(a)) * (0.42 * smoothstep(0.6, 1.0, u))
		4:
			a = k * TAU * 2.6 + (j + 1) * 2.09
			return c + Vector3.UP * j * 0.32 + (f * cos(a) + s * sin(a)) * 3.2
	# 5: yukarı kıvrılır, üç yandan hedefe iner
	var top: Vector3 = c + Vector3.UP * 2.2 + s * j * 2.0 + f * 1.2
	if u < 0.55:
		return c.lerp(top, u / 0.55)
	return top.lerp(goal + s * j * 0.14, (u - 0.55) / 0.45)


static func _open(who: Node3D, i: int, T: float, hit: float) -> void:
	var r = _rig(who)
	var n = _node(who)
	if r == null:
		return
	var tg = U.target_of(who)
	var dragon = i == 5 and U.pay(who, DRAGON_COST)
	who.set_meta("gari_ejder", dragon)
	var tok = int(who.get_meta("gari_tok", 0)) + 1
	who.set_meta("gari_tok", tok)
	r.visible = true
	n.mesh = CharacterModel.weapon_mesh("gariando_k")
	var hk = clampf(hit / T, 0.1, 1.0)
	for k in 3:
		var c = r.get_child(k)
		var j = k - 1
		c.ready_pts = false
		c.length = 3.0 if dragon else 1.0
		c.head.mesh = _dragon_head() if dragon else _tip()
		c.multimesh.mesh = _dragon_body() if dragon else _plate()
		c.set_process(true)
		var path = func(u: float, a: Vector3) -> Vector3:
			return _tip_pos(who, i, j, u, hk, tg) if is_instance_valid(who) else a
		c.drive(T, path)
	who.get_tree().create_timer(T + 0.05).timeout.connect(func():
		if is_instance_valid(who) and int(who.get_meta("gari_tok", 0)) == tok:
			_close(who))


static func _close(who: Node3D) -> void:
	var r = _rig(who)
	var n = _node(who)
	if r == null:
		return
	r.visible = false
	for c in r.get_children():
		c.set_process(false)
	n.mesh = CharacterModel.weapon_mesh("gariando")
	Sfx.play("chain", who.global_position + Vector3.UP, 1.6, 0.3)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 3:
		return
	var hit = float(A.HIT[clampi(i, 0, 5)])
	var T = {0: hit + 0.24, 1: hit + 0.18, 2: hit + 0.34, 4: 0.86, 5: hit + 0.58}.get(i, hit + 0.2)
	_open(who, i, T, hit if i != 4 else 0.3)
	Sfx.play("swing_chain", who.global_position + Vector3.UP, 1.3, 0.4)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	match i:
		2:
			if U.alive(tg) and tg.global_position.distance_to(who.global_position) < 8.0 and tg.has_method("apply_status"):
				tg.apply_status("bind", 1.0)
		5:
			var dragon = bool(who.get_meta("gari_ejder", false))
			var x = _face(who)
			var p: Vector3 = U.chest(tg) if U.alive(tg) and tg.global_position.distance_to(who.global_position) < 8.0 else (x[2] as Vector3) + (x[0] as Vector3) * 5.4
			Combat.hit_sphere(who, p, 2.0 if dragon else 1.3, {"dmg": dmg * (1.7 if dragon else 1.0), "knock": 9.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.08, "melee": false, "blade": true})
			Sfx.play("roar" if dragon else "hit_blade", p, 1.5, 0.6)
			if dragon and U.alive(tg) and tg.has_method("apply_status"):
				tg.apply_status("bind", 1.0)
