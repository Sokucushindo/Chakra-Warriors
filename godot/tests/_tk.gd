extends Node
## Raikage no Kote: kolda oturuş (yakın 4 açı + tam boy), 6 kombo adımı vuruş anı + hasar, yapay zekâ kolluklu düşman
var main: Node

func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "raiton", "hair_style": "diken",
		"hair": Color(0.25, 0.2, 0.15), "top": Color(0.85, 0.85, 0.8), "pants": Color(0.2, 0.2, 0.25), "skin": Color(0.6, 0.42, 0.3), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	var pl: Player = main.player
	var pr = Game.profile
	Hud.show_game_hud(false)
	Game.world.env.time_of_day = 0.45
	Game.set_meta("sandbox", true)
	var vs = Game.village("suna")
	var base = Game.from_map(Vector2(vs["x"] + float(vs["r"]) + 400, vs["y"]))
	pl.respawn(base)
	await _w(1.5)
	Hud.close_dialog()
	Gear.grant(pr, "raikage_kote", "sag")
	pr["weapon_drawn"] = true
	Gear.apply_look(pr)
	pl.rebuild_model()
	pl.model.set_drawn(true, false)
	pr["level"] = 60
	await _w(5.0)
	for mm in get_tree().current_scene.find_children("*", "MultiMeshInstance3D", true, false):
		mm.visible = false
	var ws = pl.model.weapons
	print("KT silahlar=%s" % str(ws.map(func(w): return "%s/%s/%s" % [w["id"], w["side"], w["kind"]])))
	print("KT keyed=%s wpn=%s" % [str(load("res://scripts/combat/keyed_combos.gd").has("raikage_kote")), str(Gear.weapon(pr))])
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.current = true
	var fd = pl.face_dir()
	var sd = fd.cross(Vector3.UP).normalized()
	# yakın çekim: her iki kol
	cam.fov = 30.0
	for w in (ws if OS.get_environment("SKIPC") == "" else []):
		var hp: Vector3 = (w["node"] as Node3D).global_position
		var views = [fd * 0.7 + Vector3.UP * 0.1, sd * (0.7 if w["side"] == "Right" else -0.7), fd * 0.45 + Vector3.UP * 0.55, -fd * 0.6 + sd * (0.3 if w["side"] == "Right" else -0.3)]
		for k in 4:
			cam.global_position = hp + views[k]
			cam.look_at(hp)
			await _w(0.15)
			await main.shot("kt_%s_%d" % [w["side"], k])
	# tam boy ön + yan
	cam.fov = 40.0
	var c0 = pl.global_position + Vector3.UP * 1.0
	for k in 2:
		cam.global_position = c0 + (fd * 3.2 if k == 0 else sd * 3.2) + Vector3.UP * 0.2
		cam.look_at(c0)
		await _w(0.15)
		await main.shot("kt_full_%d" % k)
	# kombo
	var b0 = pl.global_position
	pl.facing = 0.0
	var e := Enemy.new()
	e.setup(Enemy.archetype("rogue", 1))
	main.actors.add_child(e)
	e.global_position = b0 + Vector3(0, 0, -1.6)
	e.max_hp = 1e9; e.hp = 1e9
	e.set_physics_process(false)
	await _w(0.5)
	for k in 6:
		pl.global_position = b0
		pl.facing = 0.0
		e.global_position = b0 + Vector3(0, 0, -1.6)
		e.velocity = Vector3.ZERO
		pl.combat.lock_target = e
		pl.combat.attack()
		var guard = 0
		while not (pl.combat.action == "attack" and pl.combat.step == k and pl.combat.t < 0.1) and guard < 200:
			await get_tree().process_frame
			guard += 1
		var c = pl.combat._combo(k)
		var ht = float(c.get("hit", 0.2))
		while pl.combat.t < ht + 0.04 and guard < 400:
			await get_tree().process_frame
			guard += 1
		cam.global_position = pl.global_position + (Vector3(3.4, 1.5, -1.0) if k % 2 == 0 else Vector3(-2.2, 1.6, -3.4))
		cam.look_at(pl.global_position + Vector3(0, 1.1, -0.8))
		print("KT adim %d keyed=%s fist=%s hasar=%.0f stun=%s" % [k, str(c.get("keyed_id", "")), str(pl.model.overlay.fist), 1e9 - e.hp, str(e.state)])
		await main.shot("kt_combo_%d" % k)
		print("KT adim %d sonra hasar=%.0f" % [k, 1e9 - e.hp])
		while pl.combat.action == "attack" and pl.combat.t < float(c.get("dur", 0.5)) - 0.03 and guard < 600:
			await get_tree().process_frame
			guard += 1
	await _w(0.8)
	print("KT toplam hasar=%.0f" % (1e9 - e.hp))
	e.queue_free()
	# yapay zekâ: kolluklu düşman
	var a = Enemy.archetype("rogue", 1)
	a["look"] = CharacterModel.default_look()
	a["look"]["weapon_r"] = "raikage_kote"
	var f2 := Enemy.new()
	f2.setup(a)
	main.actors.add_child(f2)
	f2.global_position = b0 + Vector3(0, 0, -2.0)
	await _w(1.0)
	if f2.model:
		f2.model.set_drawn(true, false)
	print("KT AI silahlar=%s keyed=%s" % [str(f2.model.weapons.map(func(w): return "%s/%s" % [w["id"], w["kind"]])), f2._keyed_id()])
	pl.hp = 1e6; pl.max_hp = 1e6
	var h0 = pl.hp
	await _w(8.0)
	print("KT AI oyuncuya hasar=%.0f" % (h0 - pl.hp))
	cam.global_position = f2.global_position + Vector3(2.5, 1.3, 1.5)
	cam.look_at(f2.global_position + Vector3.UP)
	await main.shot("kt_ai")
	get_tree().quit()
