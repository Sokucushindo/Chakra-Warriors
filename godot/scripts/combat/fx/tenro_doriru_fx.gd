extends RefCounted
## Tenrō Doriru (kol matkabı; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/tenro_doriru_fx.gd). Kaynak YALNIZ OYUN (Narutopedia "Arm-mounted Drill", Kizuna Drive, Yumegakure Tenrō klanı):
## ön kola, genelde iki kola takılan büyük matkap; dönerek saplanır, yeraltında hızlı gidip alttan pusu kurar. Sayfada görsel YOK: biçim tariften.
## Yere dalış Doriru Ude'nin işlevini kullanır. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const D = preload("res://scripts/combat/fx/doriru_ude_fx.gd")
const ID := "tenro_doriru"


static func model_cuff(b: MB) -> void:
	var c = Color(0.3, 0.3, 0.34)
	Loft.tube(b, [Vector3(0, -0.075, -0.12), Vector3(0, -0.085, 0.06)], [0.05, 0.075], c, 10, 1)
	for z in [-0.09, 0.03]:
		b.add("torus", Vector3(0, 0, z), Vector3(0.14, 0.05, 0.14), Color(0.14, 0.14, 0.16), Vector3(90, 0, 0), 12)


static func model_bit(b: MB) -> void:
	var s = Color(0.62, 0.64, 0.68)
	var d = Color(0.32, 0.33, 0.37)
	b.add("cone", Vector3(0, 0, 0.27), Vector3(0.15, 0.54, 0.15), s, Vector3(90, 0, 0), 10)
	for k in 16:   # sarmal diş
		var u = k / 15.0
		var a = u * TAU * 3.0
		var r = lerpf(0.074, 0.008, u)
		b.add("sphere", Vector3(cos(a) * r, sin(a) * r, 0.02 + u * 0.48), Vector3(0.034, 0.034, 0.05) * (1.0 - u * 0.65), d, Vector3.ZERO, 5)


static func model(b: MB) -> void:
	model_cuff(b)
	var h = MB.new()
	model_bit(h)
	b.add_mesh(h, Transform3D(Basis.IDENTITY, Vector3(0, -0.085, 0.06)))


static func attach(node: Node3D) -> void:
	if not node is MeshInstance3D:
		return
	(node as MeshInstance3D).mesh = CharacterModel.weapon_mesh("tenro_doriru_k")
	var sp = D.Spin.new()
	sp.position = Vector3(0, -0.085, 0.06)
	node.add_child(sp)
	var m = MeshInstance3D.new()
	m.mesh = CharacterModel.weapon_mesh("tenro_doriru_u")
	sp.add_child(m)
	node.set_meta("tn_u", sp)


static func _rev(who: Node3D, r: float, t: float) -> void:
	var m = who.get("model")
	if m == null or not m is CharacterModel:
		return
	var sp := []
	for w in m.weapons:
		if str(w["id"]) == ID and is_instance_valid(w["node"]) and w["node"].has_meta("tn_u"):
			sp.append(w["node"].get_meta("tn_u"))
	for s in sp:
		s.want = r
	Yk.after(who, t, func():
		for s in sp:
			if is_instance_valid(s):
				s.want = 3.0)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	_rev(who, 46.0 if i != 5 else 64.0, 0.9)
	if i == 3:
		Yk.after(who, 0.18, func():
			D._dive(who))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Yk.face(who)
	var p: Vector3 = who.global_position + Vector3.UP * 1.2 + f * 0.9
	if i == 3:
		Combat.hit_sphere(who, who.global_position + Vector3.UP + f, 2.0, {"dmg": dmg * 1.1, "knock": 2.0, "launch": 8.0, "kind": "heavy", "hitstop": 0.06, "melee": false})
	D._spray(p, f, 4 if i != 5 else 9)
	Sfx.play("hit_heavy_weapon", p, 1.4, 0.35)
