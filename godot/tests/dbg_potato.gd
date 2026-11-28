extends Node
## Patates grafik kademesi denetimi: Yüksek -> Patates -> Yüksek; her birinde görüntü + FPS. Satırlar "PT".
var main: Node


func _fps(sec: float) -> float:
	var t0 = Time.get_ticks_usec()
	var n = 0
	while Time.get_ticks_usec() - t0 < int(sec * 1e6):
		await get_tree().process_frame
		n += 1
	return n / ((Time.get_ticks_usec() - t0) / 1e6)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.9, 0.4, 0.1),
		"top": Color(0.2, 0.3, 0.6), "bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var snap: Dictionary = Game.settings.duplicate(true)
	await get_tree().create_timer(6.0).timeout
	for q in [3, 0, 1, 3]:
		Game.set_quality4(q)
		await get_tree().create_timer(2.5).timeout
		var f = await _fps(3.0)
		print("PT kademe %d (%s) potato=%s golge=%s cimen=%d olcek=%.2f gorus=%.2f | FPS %.0f" % [q, Game.QUALITY4_NAMES[Game.quality4()], Game.settings["potato"], Game.settings["shadows"], Game.settings["grass"], Game.settings["res_scale"], Game.settings["view"], f])
		get_viewport().get_texture().get_image().save_png("res://../_tmp/potato_%d.png" % q)
	for k in snap:
		Game.settings[k] = snap[k]
	print("PT BITTI")
	get_tree().quit()
