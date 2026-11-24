extends Node
## Patlama çekimi: KatonFXB._goukakyuu_impact sabit noktada, sabit kamerayla 6 anda (BOOM_T env ile değişir)
var main: Node

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	await get_tree().create_timer(1.5).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	var pl = main.player
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 700.0), 80.0)
	at.y = Game.ground_height(at.x, at.z)
	pl.respawn(at + Vector3(-4, 0.3, 0))
	await get_tree().create_timer(1.0).timeout
	var cam = Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	cam.global_position = at + Vector3(0, 4.0, 16.0)
	cam.look_at(at + Vector3.UP * 3.0, Vector3.UP)
	cam.current = true
	var times = Array(OS.get_environment("BOOM_T").split(",", false)).map(func(x): return float(x)) if OS.get_environment("BOOM_T") != "" else [0.06, 0.25, 0.55, 0.9, 1.4, 2.1]
	KatonFXB._goukakyuu_impact(get_tree().current_scene, at + Vector3.UP * 1.6, 1.9)
	var t0 = Time.get_ticks_msec()
	var i = 0
	for tt in times:
		while (Time.get_ticks_msec() - t0) / 1000.0 < tt:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/boom"))
		im.save_png("res://../_tmp/boom/b_%d.png" % i)
		i += 1
	print("BOOM BITTI")
	get_tree().quit()
