extends Node
## Sonun Vadisi önce/sonra: 6 açı (göl seviyesi, yan duvar, heykel yüzleri, şelale tepesi, kuşbakışı, aşağı akıştan uzun bakış) + FPS
var main: Node


func _fps(tag: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var t0 = Time.get_ticks_usec()
	var n = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		n += 1
	print("VFPS %s: %.0f fps" % [tag, n / ((Time.get_ticks_usec() - t0) / 1e6)])


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	Hud.show_game_hud(false)
	Game.world.env.time_of_day = 0.42
	Game.world.env.weather_t = 9999.0
	Game.world.env.region_weather = "açık"
	var ve = Game.village("valley_end")
	var P = func(lx: float, ly: float, ln: float) -> Vector3:
		var w = Game.from_map(Vector2(ve["x"] + lx, ve["y"] + ln))
		return Vector3(w.x, ly, w.z)
	var pl = main.player
	pl.respawn(P.call(0, 2, 300))
	await get_tree().create_timer(9.0).timeout
	Hud.close_dialog()
	var cam = Camera3D.new()
	cam.far = 8000.0
	get_tree().current_scene.add_child(cam)
	var only = OS.get_environment("VSHOT")
	var shots = [
		[P.call(0, 7, 250), P.call(0, 55, 520), "a_gol"],
		[P.call(25, 6, 170), P.call(-95, 45, 120), "b_duvar"],
		[P.call(0, 126, 385), P.call(-66, 122, 445), "c_yuz_sol"],
		[P.call(0, 126, 385), P.call(66, 122, 445), "c_yuz_sag"],
		[P.call(0, 112, 600), P.call(0, 30, 250), "d_selale_tepe"],
		[P.call(260, 430, 80), P.call(0, 0, 420), "e_kusbakisi"],
		[P.call(0, 35, -320), P.call(0, 60, 420), "f_asagi_akis"],
		[P.call(-60, 20, 260), P.call(95, 60, 330), "g_sag_duvar"],
	]
	for s in shots:
		if only != "" and not (String(s[2]) in only):
			continue
		cam.global_position = s[0]
		cam.look_at(s[1])
		cam.current = true
		pl.global_position = s[0] + (s[1] - s[0]).normalized() * 14.0
		pl.reset_physics_interpolation()
		await get_tree().create_timer(1.6).timeout
		await main.shot(s[2])
	# çarpışma: duvarın dibinde yüzeye çık + duvara yürüyünce duruyor mu
	var q = PhysicsRayQueryParameters3D.create(P.call(0, 40, 200), P.call(-200, 40, 200))
	var hit = get_tree().current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	print("VWALL sol duvar ışını: ", (hit["position"] - P.call(0, 40, 200)).length() if hit else -1.0, " ", hit.get("collider"))
	q = PhysicsRayQueryParameters3D.create(P.call(0, 40, 300), P.call(200, 40, 300))
	hit = get_tree().current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	print("VWALL sag duvar ışını: ", (hit["position"] - P.call(0, 40, 300)).length() if hit else -1.0, " ", hit.get("collider"))
	if OS.get_environment("VFPS") != "":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		cam.global_position = P.call(0, 7, 250)
		cam.look_at(P.call(0, 55, 520))
		await _fps("gol")
		cam.global_position = P.call(260, 430, 80)
		cam.look_at(P.call(0, 0, 420))
		await _fps("kusbakisi")
		cam.global_position = P.call(25, 6, 170)
		cam.look_at(P.call(-95, 45, 120))
		await _fps("duvar")
	get_tree().quit()
