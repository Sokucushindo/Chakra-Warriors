extends Node
## Jutsu atma pozu yakın çekim: oyuncu gerçek yoldan (begin_cast: mühür + hazırlık + salınım) atar, yandan yakın kamera
var main: Node

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.25, 0.4), "pants": Color(0.1, 0.1, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.1, 0.1, 0.1)}
	await main._start_new_game()
	await get_tree().create_timer(1.5).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	var pl = main.player
	var avg = 100.0 * pow(60.0 / 100.0, 1.0 / 0.7)
	Game.profile["mastery"] = {}
	for k in Mastery.KEYS:
		Game.profile["mastery"][k] = avg
	Mastery.refresh_level(Game.profile)
	pl.max_chakra = 99999.0
	pl.chakra = 99999.0
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 700.0), 80.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	pl.respawn(at)
	await get_tree().create_timer(1.0).timeout
	var jid = OS.get_environment("JID") if OS.get_environment("JID") != "" else "katon_goukakyuu"
	Game.profile["learned"] = Game.profile.get("learned", []) + [jid]
	pl.facing = 0.0
	pl.yaw = 0.0
	var cam = Camera3D.new()
	cam.fov = 40.0
	main.add_child(cam)
	var fwd = -pl.global_basis.z
	var side = pl.global_basis.x
	var cv = OS.get_environment("CAMV")
	if cv == "front":
		cam.global_position = pl.global_position + fwd * 2.8 - side * 1.4 + Vector3.UP * 1.5
		cam.look_at(pl.global_position + Vector3.UP * 1.25, Vector3.UP)
	elif cv == "side":
		cam.global_position = pl.global_position + side * 2.6 + Vector3.UP * 1.2
		cam.look_at(pl.global_position + Vector3.UP * 1.05, Vector3.UP)
	else:
		cam.global_position = pl.global_position + side * 3.2 + fwd * 1.2 + Vector3.UP * 1.5
		cam.look_at(pl.global_position + Vector3.UP * 1.1 + fwd * 0.6, Vector3.UP)
	cam.current = true
	pl.combat.cooldowns.clear()
	pl.combat.begin_cast(jid)
	var t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/pose"))
	var t_start = float(OS.get_environment("T0")) if OS.get_environment("T0") != "" else 0.0
	var t_step = float(OS.get_environment("TS")) if OS.get_environment("TS") != "" else 0.12
	for i in 18:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t_start + i * t_step:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 3, im.get_height() / 3)
		im.save_png("res://../_tmp/pose/p_%02d.png" % i)
	print("POSE BITTI")
	get_tree().quit()
