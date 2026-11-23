extends Node
## Yaşlılıktan ölüm seremonisi (köyde, eş + mirasçı + bir çocuk) kare kare: _tmp/yasli/y_N.png; ardından eski bedenin cenazesi:
## mezarlığa gidince tören hemen başlıyor mu.
var main: Node
var n := 0


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 3, im.get_height() / 3)
	im.save_png("res://../_tmp/yasli/y_%02d.png" % n)
	print("SHOT %02d %s anim=%s" % [n, tag, main.player.model.current])
	n += 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/yasli"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test Baba", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	var env = main.world.env
	env.time_of_day = 0.45
	env.region_weather = "açık"
	env.weather_t = 9999.0
	var pl: Player = main.player
	var p: Dictionary = Game.profile
	p["rank"] = 3
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	pl.respawn(Missions.open_ground(c + Vector3(60, 0, 140), 6.0) if OS.get_environment("SOLO") == "" else Missions.open_ground(Game.from_map(Vector2(v["x"], float(v["y"]) - float(v["r"]) - 500.0)), 20.0))
	var kid = Friends._make_friend("Test Kenta", "", {"gender": "m", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12)}, 80, "Oğlun")
	var kf: Dictionary = Friends.all()[kid]
	kf["child"] = true
	kf["rank"] = 1
	kf["element"] = "katon"
	kf["village"] = "konoha"
	var kid2 = Friends._make_friend("Test Hana", "", {"gender": "f", "hair_style": "uzun", "hair": Color(0.85, 0.3, 0.12)}, 70, "Kızın")
	Friends.all()[kid2]["child"] = true
	Friends.all()[kid2]["village"] = "konoha"
	var sp = Friends._make_friend("Test Emi", "", {"gender": "f", "hair_style": "uzun", "hair": Color(0.1, 0.1, 0.12)}, 95, "Eşin")
	Friends.all()[sp]["village"] = "konoha"
	p["spouse"] = sp
	await _w(2.0)
	print("HEIRS ", Lineage.heirs(), " spouse=", Friends.spouse_id())
	Hud.close_dialog()
	Legacy._die_with(kid)
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(Legacy.cur) and Time.get_ticks_msec() - t0 < 120000:
		await _w(2.2)
		await _shot("sahne")
	print("SCENE END name=%s yas=%d lock=%.1f hud=%s pcam=%s" % [p["name"], int(Aging.player_years()), float(pl.input_locked), str(Hud.game_hud.visible), str(get_viewport().get_camera_3d() == pl.cam)])
	if OS.get_environment("SOLO") != "":
		get_tree().quit()
		return
	# cenaze: eski bedenin mezarlığına git
	await _w(3.0)
	var dlg = Hud.dialog_open()
	print("ULAK dialog=", dlg)
	Hud.close_dialog()
	var gp = Graveyard.pos_of("konoha")
	pl.respawn(gp + Vector3(0, 0.3, 8.0))
	var t1 = Time.get_ticks_msec()
	while Friends.inst().funeral.is_empty() and Time.get_ticks_msec() - t1 < 30000:
		await _w(0.5)
	print("FUNERAL started=%s after %.1f s" % [str(not Friends.inst().funeral.is_empty()), (Time.get_ticks_msec() - t1) / 1000.0])
	await _w(6.0)
	await _shot("cenaze")
	get_tree().quit()
