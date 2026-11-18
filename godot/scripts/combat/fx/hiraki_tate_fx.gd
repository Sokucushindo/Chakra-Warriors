extends RefCounted
## Hiraki-date: model, açılma, silah geri çevirme (hedef: res://scripts/combat/fx/hiraki_tate_fx.gd). Kanon (Retractable Shield): kapalıyken sıradan kolluk; açılınca kunai gibi tüm standart silahları geri çevirir.
## Kural: yalnız silah (yakın silah vuruşu, atılan araç) durur, tam durur; yüzde indirim yok. Jutsu, elementli saldırı, ağır darbe geçer. Atılan araç sahibine geri seker. Blok tuşu ya da kombo penceresinde açılır. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const ID := "hiraki_tate"
const FRESH := 0.18


class Rig extends Node3D:
	var n: MeshInstance3D
	var who: Node3D
	var opened := false

	func _process(_dt: float) -> void:
		if who == null or not is_instance_valid(who):
			var p = get_parent()
			while p != null and not p.has_method("take_hit"):
				p = p.get_parent()
			who = p as Node3D
			if who == null:
				return
		var c = who.get("combat")
		var hold = (c != null and str(c.get("action")) == "guard") or who.get("guarding") == true
		var want = hold or Game.now() <= float(who.get_meta("ht_win", 0.0))
		if want != opened:
			opened = want
			n.mesh = CharacterModel.weapon_mesh("hiraki_tate_acik" if want else "hiraki_tate")
			Sfx.play("clink", n.global_position, 1.1 if want else 0.85, 0.5)


## Ön kol çerçevesi: +Z bileğe, +X kolun dış yüzü. Kapalı: beyaz kolluk, kırmızı şerit (ref). Açık: sekiz dilimli lacivert disk, beyaz kırık halka, kırmızı + siyah çubuk.
static func model(b: MB, id: String) -> void:
	var white = Color(0.86, 0.84, 0.88)
	var red = Color(0.8, 0.13, 0.13)
	var black = Color(0.1, 0.1, 0.12)
	b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.125, 0.24, 0.125), white, Vector3(90, 0, 0), 12)
	b.add("box", Vector3(0.058, 0, 0.0), Vector3(0.016, 0.03, 0.25), red)
	b.add("box", Vector3(0.067, 0, 0.0), Vector3(0.008, 0.012, 0.2), black)
	if id != "hiraki_tate_acik":
		return
	var blue = Color(0.21, 0.27, 0.38)
	var R = 0.41
	for k in 8:
		var a0 = TAU * k / 8.0 + 0.012
		var a1 = TAU * (k + 1) / 8.0 - 0.012
		var o = PackedVector2Array([Vector2.ZERO])
		for j in 5:
			var a = lerpf(a0, a1, j / 4.0)
			o.append(Vector2(cos(a), sin(a)) * R)
		b.add_slab(o, 0.014, blue.darkened((k % 2) * 0.08), Transform3D(Basis.IDENTITY, Vector3(0.075, 0, 0)))
	for k in 20:
		if k % 7 == 3:
			continue
		var a = TAU * k / 20.0
		b.add("box", Vector3(0.084, cos(a) * 0.27, sin(a) * 0.27), Vector3(0.004, 0.018, 0.075), white, Vector3(-rad_to_deg(a), 0, 0))
	b.add("box", Vector3(0.09, 0.15, -0.08), Vector3(0.012, 0.3, 0.035), red, Vector3(28, 0, 0))
	b.add("box", Vector3(0.09, -0.15, 0.08), Vector3(0.012, 0.3, 0.035), black, Vector3(28, 0, 0))


static func attach(node: Node3D) -> void:
	if node is MeshInstance3D:
		var r = Rig.new()
		r.n = node
		node.add_child(r)


static func _open_for(who: Node3D, delay: float, dur: float) -> void:
	Yk.after(who, delay, _set_win.bind(who, dur))


static func _set_win(who: Node3D, dur: float) -> void:
	who.set_meta("ht_win", Game.now() + dur)
	who.set_meta("ht_win0", Game.now())


## Player/Enemy.take_hit: true = silah durdu
static func parry(who: Node3D, info: Dictionary) -> bool:
	if Yk.node_of(who, ID) == null:
		return false
	var now = Game.now()
	var win = now <= float(who.get_meta("ht_win", 0.0))
	var c0 = who.get("combat")
	var hold = (c0 != null and str(c0.get("action")) == "guard") or who.get("guarding") == true
	if not win and not hold:
		return false
	var thrown = info.has("tool")
	var armed = bool(info.get("melee", false)) or thrown or (info.get("attacker") != null and not info.has("tier"))   # ok, iğne gibi uzak silahlar da
	if not armed or info.get("sure", false) or int(info.get("tier", -1)) >= 0 or (not info.get("element", "") in [null, ""]):
		return false
	if not thrown and str(info.get("kind", "light")) in ["heavy", "launch"]:
		return false
	var atk = info.get("attacker")
	var f = Yk.face(who)
	var to: Vector3 = (atk.global_position - who.global_position) if atk is Node3D and is_instance_valid(atk) else -Vector3(info.get("dir", Vector3.ZERO))
	to.y = 0.0
	if to.length() < 0.05 or to.normalized().dot(f) < 0.2:
		return false
	var c = who.global_position + Vector3.UP * 1.2 + f * 0.5
	Sfx.play("clash", c, randf_range(1.15, 1.35), 0.8)
	if thrown:
		if atk is Node3D and is_instance_valid(atk):
			_bounce(who, c, atk, float(info.get("dmg", 6.0)))
		Combat.popup_text(who.global_position + Vector3.UP * 2.2, "Geri Çevrildi!", Color(0.8, 0.88, 1.0))
	elif win and now - float(who.get_meta("ht_win0", -9.0)) <= FRESH and atk is Node3D and is_instance_valid(atk):
		if atk.has_method("stagger"):
			atk.stagger(0.6)
		elif atk.has_method("apply_status"):
			atk.apply_status("stun", 0.4)
		Combat.popup_text(who.global_position + Vector3.UP * 2.2, "Çelindi!", Color(0.8, 0.88, 1.0))
	return true


static func _bounce(who: Node3D, from: Vector3, atk: Node3D, dmg: float) -> void:
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = CharacterModel.weapon_mesh("kunai")
	v.rotation.y = PI
	root.add_child(v)
	U.fire(who, from, (U.chest(atk) - from).normalized() * 46.0, {"r": 0.13, "life": 1.0, "vis": root,
		"info": {"dmg": dmg * 0.7, "knock": 1.5, "kind": "light", "hitstop": 0.02}})


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	if i == 1:
		_open_for(who, 0.1, 0.34)
	elif i == 2:
		_open_for(who, 0.08, 0.36)
	elif i == 3:
		_open_for(who, 0.06, 0.62)
	elif i == 5:
		_open_for(who, 0.1, 0.72)
