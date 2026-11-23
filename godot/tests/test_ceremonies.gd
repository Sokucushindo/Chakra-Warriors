extends Node
## Tören sahneleri uçtan uca: mezuniyet, chūnin, jōnin, kaçak olma, af, Kage yemini — oyundaki gerçek giriş noktalarından.
## Her törenden sonra: rütbe, bant stili, arayüz / kamera geri geldi mi, oyuncu serbest mi. Kareler: _tmp/toren/<tür>_NN.png
## ONLY=genin,kage gibi seçilebilir.
var main: Node
var pl


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _shot(tag: String, n: int) -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 3, im.get_height() / 3)
	im.save_png("res://../_tmp/toren/%s_%02d.png" % [tag, n])


func _watch(tag: String) -> void:
	var t0 = Time.get_ticks_msec()
	var n = 0
	await _w(0.3)
	while is_instance_valid(Ceremony.cur) and Time.get_ticks_msec() - t0 < 90000:
		await _shot(tag, n)
		n += 1
		await _w(2.0)
	await _w(1.5)
	var lk: Dictionary = Game.profile.get("look", {})
	print("TOREN %s: sure=%.1f kare=%d rutbe=%d bant=%s/%s kacak=%s hud=%s pcam=%s kilit=%.1f hold=%s dialog=%s" % [tag, (Time.get_ticks_msec() - t0) / 1000.0, n,
		int(Game.profile.get("rank", 0)), str(lk.get("band") != null), String(lk.get("band_style", "-")), str(Orgs.is_rogue()), str(Hud.game_hud.visible),
		str(get_viewport().get_camera_3d() == pl.cam), float(pl.input_locked), str(pl.get("scene_hold")), str(Hud.dialog_open())])
	Hud.close_dialog()
	await _w(1.0)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/toren"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	pl = main.player
	var env = main.world.env
	env.time_of_day = 0.45
	env.region_weather = "açık"
	env.weather_t = 9999.0
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var field = Missions.open_ground(c + Vector3(60, 0, 140), 6.0)
	pl.respawn(field)
	await _w(3.0)
	var only = OS.get_environment("ONLY")
	var kinds = ["genin", "chunin", "jonin", "rogue", "pardon", "kage"] if only == "" else Array(only.split(","))
	for k in kinds:
		Hud.close_dialog()
		pl.respawn(field)
		await _w(1.5)
		print("BASLA ", k)
		match k:
			"genin":
				Exams._bell_result(true, "scroll")
			"chunin":
				Ceremony.start("chunin", {"grant": func(): Progress.promote(2)})
			"jonin":
				Exams.jonin_done({"flags": {"votes": 2}}, true)
			"rogue":
				if int(Game.profile.get("rank", 0)) < 1:
					Progress.promote(1)
				print("  sakin=", Ceremony.calm())
				Orgs.defect()
			"pardon":
				for f in get_tree().get_nodes_in_group("fighters"):   # kaçak sahnesinin peşe düşen nöbetçileri test için kaldırılır
					if f is Enemy and is_instance_valid(f) and not f.has_meta("teammate"):
						f.queue_free()
				pl.hp = pl.max_hp
				pl.respawn(Missions.open_ground(field + Vector3(0, 0, 40), 6.0))
				await _w(1.0)
				Orgs.pardon_done({}, true)
			"kage":
				Game.profile["level"] = 200
				Kage.inaugurate()
		await _watch(k)
		if k == "rogue":   # kaçak olunca köyde peşe düşen nöbetçiler test için kaldırılır (sıradaki törenler ölüm sahnesine denk gelmesin)
			for f in get_tree().get_nodes_in_group("fighters"):
				if f is Enemy and is_instance_valid(f) and not f.has_meta("teammate"):
					f.queue_free()
			pl.hp = pl.max_hp
	get_tree().quit()
