extends RefCounted
## Gedokuyaku (解毒薬; hedef: res://scripts/combat/fx/gedokuyaku_fx.gd). Kanon (Narutopedia "Antidote", manga 254): zehir karşıtı ilaç, çoğu şişede
## sıvı; savaşta zehirli yoldaşı tedavi zor olduğu için tıbbi ninjalar önceden kapsül / iğne hazırlar ve hastaya enjekte eder.
## Ref refs/gedokuyaku/Antidote.png: cam kapsül, zeytin sarısı sıvı, gri metal bilezik, kızıl işaret, dipte iğne.
## Oyunda: zehirliysen kendine; değilse 8 m içindeki zehirli yoldaşa kapsül atarsın; kimse zehirli değilse önceden koruma olarak vurursun.
## Oyuncu ve düşman aynı kod. Zehir durumu DokuFX'te.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const S = preload("res://scripts/combat/samehada_anim.gd")
const Doku = preload("res://scripts/combat/fx/doku_fx.gd")

const PROTECT := 12.0
const ALLY_R := 8.0
const CD := 20.0
const LIQ := Color(0.67, 0.63, 0.33)
const METAL := Color(0.62, 0.64, 0.68)


## Uç (+Z) cam yuvarlak, dipte (-Z) iğne
static func build(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.024, 0.056, 0.024), LIQ, Vector3(90, 0, 0), 10)
	b.add("sphere", Vector3(0, 0, 0.058), Vector3(0.024, 0.024, 0.024), LIQ.lightened(0.12), Vector3.ZERO, 10)
	b.add("box", Vector3(0.0118, 0.002, 0.034), Vector3(0.0012, 0.005, 0.05), Color(0.97, 0.97, 0.94))
	b.add("cyl", Vector3(0, 0, -0.018), Vector3(0.027, 0.04, 0.027), METAL, Vector3(90, 0, 0), 10)
	b.add("cyl", Vector3(0, 0, -0.018), Vector3(0.0278, 0.0018, 0.0278), METAL.darkened(0.3), Vector3(90, 0, 0), 10)
	b.add("box", Vector3(0.0138, 0, -0.018), Vector3(0.0015, 0.011, 0.005), Color(0.68, 0.14, 0.14))
	b.add("cyl", Vector3(0, 0, -0.05), Vector3(0.0024, 0.026, 0.0024), METAL.darkened(0.15), Vector3(90, 0, 0), 4)


static func _mesh() -> Mesh:
	return Kit.cached_mesh("gedoku", func():
		var b = MB.new()
		build(b)
		return b.build(Props.toon()))


static func _spot() -> Mesh:
	return Kit.cached_mesh("gedoku_zerre", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.026, LIQ.lightened(0.3), Vector3.ZERO, 5)
		return b.build(Props.toon()))


## Zehir bedenden çıkar: açık renkli zerreler yükselir
static func _rise(t: Node3D) -> void:
	var c = Kit.chest(t)
	for k in 12:
		var mi = MeshInstance3D.new()
		mi.mesh = _spot()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(mi)
		var a = randf() * TAU
		var o = Vector3(cos(a), randf_range(-0.8, 0.6), sin(a)) * randf_range(0.14, 0.3)
		var h = randf_range(0.7, 1.2)
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.025)
		tw.tween_method(func(v: float):
			if is_instance_valid(mi):
				mi.global_position = c + o * (1.0 + v * 0.5) + Vector3.UP * h * v
				mi.scale = Vector3.ONE * (1.0 - v * v), 0.0, 1.0, 0.55)
		tw.tween_callback(mi.queue_free)


static func _apply(t: Node3D) -> void:
	if not is_instance_valid(t):
		return
	var had = Doku.cure(t, PROTECT)
	_rise(t)
	Sfx.play("heal", t.global_position + Vector3.UP, 1.35, 0.5)
	Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Zehir söndü" if had else "Panzehir", Color(0.82, 0.9, 0.55))


static func _pose(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or m.overlay == null:
		return
	var W = S.LEG_WIDE
	var r = {"RightUpperArm": Vector3(-0.25, -0.9, 0.3), "RightLowerArm": Vector3(0.1, -0.4, 0.9)}
	var l0 = {"LeftUpperArm": Vector3(0.3, -0.85, 0.42), "LeftLowerArm": Vector3(0.0, -0.3, 0.95)}
	var l1 = {"LeftUpperArm": Vector3(0.35, -0.5, 0.8), "LeftLowerArm": Vector3(-0.8, 0.55, 0.2)}   # kapsül sağ omuza
	var fw = Vector3(0, 0, 1)
	m.overlay.play_keys({"len": 0.55, "hit": 0.26, "keys": [
		S._k(0.0, 0.36, 0.0, 2.0, fw, S._a(r, l0), W),
		S._k(0.2, 0.38, 10.0, 6.0, fw, S._a(r, l1), W),
		S._k(0.4, 0.38, 10.0, 6.0, fw, S._a(r, l1), W),
		S._k(0.55, 0.36, 0.0, 2.0, fw, S._a(r, l0), W),
	]}, 1.0)
	if m.has_method("hold_temp"):
		m.hold_temp("gedokuyaku", 0.45, "Left", 1.0, 0.0, false, true)
	who.get_tree().create_timer(0.52).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.stop_keys())


## Zehirli yoldaş (kendisi hariç), en yakını
static func ally_in_need(who: Node3D) -> Node3D:
	var best: Node3D = null
	var bd = ALLY_R
	for f in Kit.fighters():
		if f == who or f.is_dead() or Combat.hostile(who, f) or Doku.left(f) <= 0.0:
			continue
		var d = f.global_position.distance_to(who.global_position)
		if d < bd:
			bd = d
			best = f
	return best


## Kapsül yoldaşa uçar
static func _toss(who: Node3D, t: Node3D) -> void:
	var from: Vector3 = who.global_position + Vector3.UP * 1.3
	var mi = MeshInstance3D.new()
	mi.mesh = _mesh()
	Kit.scene().add_child(mi)
	mi.global_position = from
	var tw = mi.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mi) and is_instance_valid(t):
			mi.global_position = from.lerp(Kit.chest(t), v) + Vector3.UP * sin(v * PI) * 0.8
			mi.rotation = Vector3(v * 14.0, v * 5.0, 0.0), 0.0, 1.0, 0.32)
	tw.tween_callback(func():
		if is_instance_valid(mi):
			mi.queue_free()
		_apply(t))


static func use(who: Node3D) -> void:
	_pose(who)
	var ally = ally_in_need(who) if Doku.left(who) <= 0.0 else null
	who.get_tree().create_timer(0.24).timeout.connect(func():
		if not is_instance_valid(who):
			return
		if ally != null and is_instance_valid(ally):
			_toss(who, ally)
		else:
			_apply(who))


## Düşman aleti (Projectile.tool -> ALET_FX). Mermi yok.
static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target: Node3D) -> Projectile:
	use(who)
	return null


static func player_use(p: Node3D) -> void:
	var c = p.combat
	if c.action != "" and c.action != "guard":
		return
	var nm = str(Data.items.get("gedokuyaku", {"name": "Gedokuyaku"})["name"])
	if not c.tool_owned("gedokuyaku"):
		Hud.msg("%s sende yok — pazardan bir kez al, sonra sınırsız." % nm, Color(1, 0.6, 0.5))
		return
	if float(c.tool_cd.get("gedokuyaku", 0.0)) > 0.0:
		Hud.msg("%s hazır değil: %d sn" % [nm, ceili(float(c.tool_cd["gedokuyaku"]))], Color(1, 0.75, 0.5))
		return
	c.tool_cd["gedokuyaku"] = CD
	c.action = "throw"
	c.t = -0.15
	use(p)
