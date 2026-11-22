extends Node
## YouTube kanal kapağı için yatay Konoha görüntüleri (_tmp/kanal/banner_N.png).
var main: Node
var cam: Camera3D


func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: int, p: Vector3, l: Vector3) -> void:
	cam.global_position = p
	cam.look_at(l)
	await _w(2.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../_tmp/kanal/banner_%d.png" % n)
	print("SHOT ", n)


func _ready() -> void:
	await get_tree().process_frame
	Lang.apply("en")
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var env = main.world.env
	env.time_of_day = 0.40
	env.region_weather = "açık"
	env.weather_t = 9999.0
	env.overcast = 0.0
	var pl = main.player
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 6000.0
	main.add_child(cam)
	env.attach_post(cam)
	cam.current = true
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var rock: Dictionary = Game.world_info.get("hokage_rock", {})
	var cn = float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"])
	var face_z = c.z - cn
	var gy = Game.terrain_height(c.x, face_z + 200)
	var top = Game.terrain_height(c.x, face_z - 40)
	var cy = Game.terrain_height(c.x, c.z)
	pl.respawn(Vector3(c.x, gy + 2, face_z + 260))
	await _w(5.0)
	await _shot(1, Vector3(c.x - 30, cy + 130, c.z + 170), Vector3(c.x, top - 50, face_z))
	await _shot(2, Vector3(c.x - 120, cy + 90, c.z + 260), Vector3(c.x, cy + 30, c.z - 200))
	await _shot(3, Vector3(c.x + 60, cy + 60, face_z + 420), Vector3(c.x, top - 30, face_z))
	get_tree().quit()
