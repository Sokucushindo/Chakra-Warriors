extends Node
## Doldurma (fill rate) testi: aynı sahnede V-Sync kapalı FPS ölç; pencere küçülünce FPS çok artıyorsa GPU piksel sınırlı.
## Çözünürlüğü hd.py --resolution ile ver; çıktı: "FR <çözünürlük> <nokta>: ort FPS, en uzun kare"
var main: Node


func _measure(tag: String, secs := 8.0) -> void:
	var t0 = Time.get_ticks_msec()
	var n := 0
	var worst := 0.0
	var last = Time.get_ticks_usec()
	var vrid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var sp := 0.0
	var sc := 0.0
	var sg := 0.0
	var sx := 0.0
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await get_tree().process_frame
		var now = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		n += 1
		sp += Performance.get_monitor(Performance.TIME_PROCESS)
		sc += RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
		sg += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		sx += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("FR   ort: _process %.1f ms, fizik %.1f ms, çizim CPU %.1f ms, çizim GPU %.1f ms" % [sp / n * 1000.0, sx / n * 1000.0, sc / n, sg / n])
	var sz = get_viewport().get_visible_rect().size * get_viewport().scaling_3d_scale
	print("FR   çizim çağrısı %d, nesne %d, üçgen %.1f M | _process %.1f ms, fizik %.1f ms, düğüm %d, fizik nesnesi %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	print("FR 3B %dx%d %s: ort %.1f FPS, en uzun kare %.0f ms" % [sz.x, sz.y, tag, n / secs, worst])


func _ready() -> void:
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	Hud.show_game_hud(false)
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather_t = 9999.0
	Game.world.env.region_weather = "açık"
	await get_tree().create_timer(6.0).timeout
	var _sc = float(OS.get_environment("FR_SCALE")) if OS.get_environment("FR_SCALE") != "" else 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = _sc
	if OS.get_environment("FR_NOSHADOW") != "":
		for l in get_tree().root.find_children("*", "Light3D", true, false):
			(l as Light3D).shadow_enabled = false
		print("FR gölgeler kapalı")
	get_viewport().use_occlusion_culling = OS.get_environment("FR_NOOCC") == ""
	print("FR occlusion culling: ", get_viewport().use_occlusion_culling)
	var pl: Player = main.player
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	pl.respawn(Missions.open_ground(c, 60.0) + Vector3.UP * 0.5)
	await get_tree().create_timer(6.0).timeout
	await _measure("Konoha merkez")
	var e = Game.village("suna")
	pl.respawn(Missions.open_ground(Game.from_map(Vector2(e["x"], e["y"])), 60.0) + Vector3.UP * 0.5)
	await get_tree().create_timer(8.0).timeout
	await _measure("Suna merkez")
	pl.respawn(Game.from_map(Vector2(v["x"], v["y"] + float(v["r"]) + 1500)) + Vector3.UP * 0.5)
	await get_tree().create_timer(6.0).timeout
	await _measure("açık doğa")
	get_tree().quit()
