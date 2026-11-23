extends Node
## Ölüm ara sahnesi: oyuncu ölür, sahne kare kare kaydedilir (_tmp/olum/d_N.png); uyanışta konum/kilit kontrolü.
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _shot(n: int) -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 3, im.get_height() / 3)
	im.save_png("res://../_tmp/olum/d_%d.png" % n)
	var pl = main.player
	var sk = pl.model.skel
	var hi = sk.find_bone("DEF-hips") if sk.find_bone("DEF-hips") >= 0 else sk.find_bone("Hips")
	print("  ANIM ", pl.model.anim.current_animation, " pos=", pl.model.anim.current_animation_position, " spd=", pl.model.anim.speed_scale, " hips_y=", (sk.global_transform * sk.get_bone_global_pose(hi)).origin.y - pl.global_position.y if hi >= 0 else -1.0)
	print("SHOT %d t=%.1f anim=%s cine=%s y=%.2f gy=%.2f lock=%.1f hp=%.0f" % [n, Time.get_ticks_msec() / 1000.0, pl.model.current, str(get_viewport().get_camera_3d() != pl.cam), pl.global_position.y, Game.terrain_height(pl.global_position.x, pl.global_position.z), pl.input_locked, pl.hp])


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/olum"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	var env = main.world.env
	env.time_of_day = 0.42
	env.region_weather = "açık"
	env.weather_t = 9999.0
	var pl = main.player
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var p0 = Missions.open_ground(c + Vector3(60, 0, 140), 6.0)
	pl.respawn(p0)
	await _w(4.0)
	print("START pos=", pl.global_position)
	pl.hp = 0.0
	Progress.on_player_died()
	var times = [0.3, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 6.8, 7.6, 8.5, 9.5, 11.0]
	var t0 = 0.0
	for i in times.size():
		await _w(times[i] - t0)
		t0 = times[i]
		await _shot(i)
	await _w(1.0)
	print("END pos=", pl.global_position, " lock=", pl.input_locked, " ts=", Engine.time_scale, " pcam=", get_viewport().get_camera_3d() == pl.cam, " hud=", Hud.game_hud.visible, " scene=", DeathScene.cur, " anim=", pl.model.current)
	get_tree().quit()
