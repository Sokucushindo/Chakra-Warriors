extends Node
## Kodla üretilen aksesuarlar (torii, küçük torii, bank, bambu): oyunda, açık havada yan yana, 3 açıdan.
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/props"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var env = main.world.env
	env.time_of_day = 0.45
	env.region_weather = "açık"
	env.weather_t = 9999.0
	WorldDay.auto = false
	var p: Vector3 = main.player.global_position + Vector3(0, 0, -14)
	p = Missions.open_ground(p, 20.0)
	p.y = Game.terrain_height(p.x, p.z)
	main.player.visible = false
	var kinds = [["torii_red", 7.0], ["torii_small", 4.5], ["bench", 1.0], ["bamboo", 7.0]]
	var i := 0
	for k in kinds:
		var mi := MeshInstance3D.new()
		if k[0] == "bamboo":
			var bm = AnimeTree.mesh("bamboo", "bamboo", 1)
			mi.mesh = bm
			mi.scale = Vector3.ONE * (float(k[1]) / bm.get_aabb().size.y)
		else:
			mi.mesh = AssetLib.prop(k[0], k[1])
		main.add_child(mi)
		mi.global_position = p + Vector3(-12 + i * 8.0, 0, 0)
		mi.global_position.y = Game.terrain_height(mi.global_position.x, mi.global_position.z)
		i += 1
	var cam := Camera3D.new()
	cam.fov = 50
	main.add_child(cam)
	env.attach_post(cam)
	cam.current = true
	var shots = [["on", Vector3(0, 3.5, 20)], ["yan", Vector3(16, 4, 12)], ["ust", Vector3(0, 14, 10)]]
	for s in shots:
		cam.global_position = p + s[1]
		cam.look_at(p + Vector3(0, 2.5, 0), Vector3.UP)
		await _w(0.6)
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2)
		im.save_png("res://../_tmp/props/%s.png" % s[0])
	# yakın: bank ve bambu
	cam.global_position = p + Vector3(5, 1.6, 4)
	cam.look_at(p + Vector3(4, 0.6, 0), Vector3.UP)
	await _w(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../_tmp/props/yakin.png")
	get_tree().quit()
