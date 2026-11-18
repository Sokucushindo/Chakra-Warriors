extends RefCounted
## Inochi no Karē (命のカレー; hedef: res://scripts/combat/fx/inochi_kare_fx.gd). Kanon (Narutopedia "Curry of Life", anime 152, Karashi'nin tarifi): acılığı baygın ya da ölmek üzere olanı kaldırır,
## birkaç kez yenince güçlendirir; acıya dayanıksız olanı (Neji) bayıltır. Ref refs/inochi_kare/Curry_of_Life.png: krem tabak, kızıl köri, et parçaları.
## Oyunda tek kullanımlık: can verir, can azken çok daha fazla; yiyen ölmek üzere yoldaşa da verilir. Yedikçe alışırsın: bayılma şansı düşer, kısa güçlenme artar.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const T = preload("res://scripts/combat/fx/tuketim.gd")

const ALLY_R := 4.0
const LOW := 0.25


static func build(b: MB) -> void:
	var red = Color(0.86, 0.22, 0.2)
	b.add("cyl", Vector3.ZERO, Vector3(0.22, 0.012, 0.22), Color(0.93, 0.9, 0.76), Vector3.ZERO, 16)
	b.add("sphere", Vector3(0, 0.018, 0), Vector3(0.16, 0.05, 0.16), Color(0.96, 0.95, 0.92), Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.03, 0), Vector3(0.15, 0.05, 0.15), red, Vector3.ZERO, 12)
	for k in 7:
		var a = k * 2.399
		var r = 0.022 + k * 0.007
		b.add("box", Vector3(cos(a) * r, 0.056, sin(a) * r), Vector3.ONE * 0.017, red.darkened(0.25), Vector3(k * 30.0, k * 50.0, 0))


static func _steam(t: Node3D) -> void:
	var m = Kit.cached_mesh("kare_kivilcim", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.03, 0.09, 0.008), Color(1.0, 0.3, 0.14))
		return b.build(Props.toon_color(Color(1.0, 0.3, 0.14), 0.7)))
	var c: Vector3 = Kit.eye(t)
	for k in 9:
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(mi)
		var a = k * TAU / 9.0
		var d = Vector3(cos(a), 0.5, sin(a))
		var fly = func(v: float) -> void:
			if is_instance_valid(mi):
				mi.global_position = c + d * v * 0.9
				mi.scale = Vector3.ONE * (1.0 - v)
		var tw = mi.create_tween()
		tw.tween_method(fly, 0.0, 1.0, 0.42)
		tw.tween_callback(mi.queue_free)


static func _feed(t: Node3D, eater_count: int) -> void:
	if not is_instance_valid(t) or t.get("hp") == null or t.get("max_hp") == null:
		return
	_steam(t)
	Sfx.play("fire", t.global_position + Vector3.UP * 1.5, 1.7, 0.3)
	if randf() < maxf(0.04, 0.34 - eater_count * 0.05):   # kanon: acıya dayanamayan bayılır
		t.apply_status("stun", 1.8)
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Çok acı!", Color(1.0, 0.4, 0.3))
	var low = float(t.hp) < float(t.max_hp) * LOW
	t.hp = minf(float(t.max_hp), float(t.hp) + float(t.max_hp) * (0.65 if low else 0.25))
	Combat.popup_text(t.global_position + Vector3.UP * 2.0, "Hayata döndü!" if low else "Acı ama iyi geldi", Color(1.0, 0.7, 0.45))
	var mods = {"melee": 1.0 + minf(0.2, 0.06 + eater_count * 0.02)}
	if t is Player:
		Buffs.add("inochi_kare", 25.0, mods)
	elif t.has_method("add_buff"):
		t.add_buff("inochi_kare", 25.0, mods)


static func _target(who: Node3D) -> Node3D:
	if float(who.hp) < float(who.max_hp) * LOW:
		return who
	for f in Kit.fighters():
		if f != who and not f.is_dead() and not Combat.hostile(who, f) and f.get("hp") != null and f.get("max_hp") != null and float(f.hp) < float(f.max_hp) * LOW and f.global_position.distance_to(who.global_position) < ALLY_R:
			return f
	return who


static func use(who: Node3D, n: int) -> void:
	T.pose(who, "inochi_kare", {"LeftUpperArm": Vector3(0.2, -0.75, 0.62), "LeftLowerArm": Vector3(-0.35, 0.05, 0.94)}, 0.6)
	var t = _target(who)
	who.get_tree().create_timer(0.32).timeout.connect(func():
		if is_instance_valid(who):
			_feed(t, n))


static func launch(who: Node3D, _start: Vector3, _dir: Vector3, _target_n: Node3D) -> Projectile:
	who.set_meta("kare_yedi", true)
	use(who, 0)
	return null


static func player_use(p: Node3D) -> void:
	if T.gate(p, "inochi_kare", 6.0, true, 0.6):
		var n = int(Game.profile.get("kare_n", 0))
		Game.profile["kare_n"] = n + 1
		use(p, n)
