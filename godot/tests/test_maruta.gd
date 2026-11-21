extends Node
## Tsuri Maruta: vuruş -> savrulma -> geri gelip oyuncuya çarpma; dayanıklılık artışı, can 1'in altına inmez; dünyadaki yerleri + görüntü
var main: Node
var OUT := (ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/shots/maruta/")
func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.42
	await get_tree().create_timer(8.0).timeout
	var pl = main.player
	var ms = get_tree().get_nodes_in_group("fighters").filter(func(n): return n is TsuriMaruta)
	var ds = get_tree().get_nodes_in_group("fighters").filter(func(n): return n is TrainingDummy and not n is TsuriMaruta)
	print("MARUTA dünyada=", ms.size(), " kukla=", ds.size(), " spawner=", Spawner.marutas.size())
	var tm = TsuriMaruta.new()
	get_tree().current_scene.add_child(tm)
	tm.global_position = pl.global_position + Vector3(0, 0, -1.2)
	await get_tree().create_timer(0.5).timeout
	var d0 = Mastery.get_v(Game.profile, "dayaniklilik")
	var hp0 = pl.hp
	var hits = 0
	for k in 6:
		# oyuncu kütüğün önünde (+z), kütüğe -z yönünde vurur; kütük -z'ye savrulup geri +z'ye (oyuncuya) gelir
		pl.global_position = tm.global_position + Vector3(0, 0, 0.9)
		var h0 = pl.hp
		tm.take_hit({"dmg": 30.0, "attacker": pl, "kind": "heavy", "dir": Vector3(0, 0, -1)})
		await get_tree().create_timer(2.6).timeout
		if pl.hp < h0:
			hits += 1
		print("MARUTA vurus %d can %.0f -> %.0f  aci=%.2f" % [k, h0, pl.hp, tm.th.length()])
	print("MARUTA carpma=%d/6 dayaniklilik %.3f -> %.3f  can %.0f -> %.0f / %.0f" % [hits, d0, Mastery.get_v(Game.profile, "dayaniklilik"), hp0, pl.hp, pl.max_hp])
	# can bitmez: canı 2'ye indirip tekrar
	pl.hp = 2.0
	pl.global_position = tm.global_position + Vector3(0, 0, 0.9)
	tm.take_hit({"dmg": 60.0, "attacker": pl, "kind": "heavy", "dir": Vector3(0, 0, -1)})
	await get_tree().create_timer(2.6).timeout
	print("MARUTA dusuk can sonra=%.1f olu=%s" % [pl.hp, pl.hp <= 0.0])
	pl.hp = pl.max_hp
	# görüntü: savrulurken ve durgun, iki açı
	Hud.visible = false
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.fov = 50.0
	pl.global_position = tm.global_position + Vector3(2.5, 0, 3.0)
	var c = tm.global_position + Vector3(0, 1.8, 0)
	for v in [["on", Vector3(0.5, 0.6, 5.0)], ["capraz", Vector3(4.0, 1.0, 3.0)]]:
		cam.global_position = c + v[1]
		cam.look_at(c)
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png(OUT + "durgun_%s.png" % v[0])
	tm.take_hit({"dmg": 40.0, "attacker": pl, "kind": "heavy", "dir": Vector3(1, 0, 0)})
	await get_tree().create_timer(0.55).timeout
	cam.global_position = c + Vector3(0.5, 0.6, 5.0)
	cam.look_at(c)
	await get_tree().create_timer(0.05).timeout
	get_viewport().get_texture().get_image().save_png(OUT + "savrulma.png")
	if ms.size() > 0:
		var m0: Node3D = ms[0]
		cam.global_position = m0.global_position + Vector3(9, 6, 9)
		cam.look_at(m0.global_position + Vector3(0, 1.5, 0))
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(OUT + "saha.png")
	print("MARUTA bitti")
	get_tree().quit()
