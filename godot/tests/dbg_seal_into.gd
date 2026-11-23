extends Node
## İçine mühürleme animasyonu: canavarın ruhu emilir (_tmp/seal/s_NN.png)
var main: Node
var cam: Camera3D
func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/seal"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.9, 0.7, 0.2), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.45
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Missions.open_ground(Game.from_map(Vector2(v["x"], v["y"] + float(v["r"]) + 1400)), 40.0) + Vector3.UP)
	await get_tree().create_timer(2.0).timeout
	var id = OS.get_environment("BEAST") if OS.get_environment("BEAST") != "" else "shukaku"
	var b = TailedBeast.new()
	b.setup(id)
	get_tree().current_scene.add_child(b)
	var fd: Vector3 = pl.face_dir()
	b.global_position = Missions.open_ground(pl.global_position + fd * 45.0, 10.0)
	b.home = b.global_position
	b.set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	main.add_child(cam)
	main.world.env.attach_post(cam)
	var side = fd.cross(Vector3.UP)
	var to_b = (b.global_position - pl.global_position).normalized()
	var mid = pl.global_position.lerp(b.global_position, 0.45)
	cam.global_position = mid + to_b.cross(Vector3.UP) * 48.0 + Vector3.UP * 8.0   # yandan: ikisi birden
	cam.look_at(mid + Vector3.UP * 9.0)
	TailedBeasts._finish_seal(b, "player")
	for i in 3:
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 3, im.get_height() / 3)
		im.save_png("res://../_tmp/seal/s_%02d.png" % i)
	# karın yakın çekim (mühür sarmalı + içine giriş anı)
	print("PL ", pl.global_position, " model=", pl.model.global_position, " cam=", cam.global_position)
	var fd2: Vector3 = pl.face_dir()
	var mp: Vector3 = pl.model.global_position
	cam.global_position = mp + fd2 * 2.6 + fd2.cross(Vector3.UP) * 1.0 + Vector3.UP * 1.4
	cam.look_at(mp + Vector3.UP * 1.0)
	for i in 6:
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		var im2 = get_viewport().get_texture().get_image()
		im2.resize(im2.get_width() / 3, im2.get_height() / 3)
		im2.save_png("res://../_tmp/seal/s_%02d.png" % (3 + i))
	print("JIN=", TailedBeasts.player_jinchuriki(), " beast_valid=", is_instance_valid(b))
	get_tree().quit()
