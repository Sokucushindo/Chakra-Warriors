extends Node
## Konoha şehir taraması: merkezden dış mahallelere 16 nokta; her noktada eğik kuşbakışı (40 m) + göz hizası.
## Kareler _tmp/kons/<tag>_NN.png. SPOTS="x,n;x,n" (köy yerel) ile belirli noktalar.
var main: Node
var cam: Camera3D


func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _shot(tag: String) -> void:
	await _w(0.5)
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2)
	im.save_png("res://../_tmp/kons/%s.png" % tag)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/kons"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var env = main.world.env
	env.time_of_day = 0.43
	env.region_weather = "açık"
	env.weather_t = 9999.0
	WorldDay.auto = false
	print("AGAC sikisik_atlanan=", Builder.crowd_skips, " kayitli_hucre=", Builder.tree_grid.size())
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 3000.0
	main.add_child(cam)
	env.attach_post(cam)
	var pts := []
	if OS.get_environment("SPOTS") != "":
		for p in OS.get_environment("SPOTS").split(";"):
			var f = p.split(",")
			pts.append(Vector2(float(f[0]), float(f[1])))
	else:
		for ring in [[120.0, 4], [380.0, 6], [700.0, 6]]:
			for i in int(ring[1]):
				var a = TAU * (i + 0.5 * (ring[0] / 380.0)) / float(ring[1])
				pts.append(Vector2(sin(a), cos(a)) * float(ring[0]))
	var i := 0
	for p in pts:
		var at = Vector3(c.x + p.x, 0, c.z - p.y)
		at = Missions.open_ground(at, 6.0)
		at.y = Game.terrain_height(at.x, at.z)
		env.time_of_day = 0.43
		main.player.respawn(at + Vector3.UP)
		await _w(2.2)
		main.player.visible = false
		var dir = (c - at)
		dir.y = 0
		dir = dir.normalized() if dir.length() > 5.0 else Vector3.FORWARD
		cam.global_position = at - dir * 30.0 + Vector3.UP * 40.0
		cam.look_at(at + dir * 25.0, Vector3.UP)
		await _shot("air_%02d" % i)
		cam.global_position = at + Vector3.UP * 1.7
		cam.look_at(at + dir * 30.0 + Vector3.UP * 3.0, Vector3.UP)
		await _shot("eye_%02d" % i)
		cam.look_at(at - dir.cross(Vector3.UP) * 30.0 + Vector3.UP * 3.0, Vector3.UP)
		await _shot("side_%02d" % i)
		print("NOKTA %02d yerel=(%.0f,%.0f)" % [i, p.x, p.y])
		main.player.visible = true
		i += 1
	get_tree().quit()
