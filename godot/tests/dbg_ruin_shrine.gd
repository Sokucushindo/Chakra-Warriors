extends Node
## Harabe tapınak: oyuncunun yanına kurup dört açıdan görüntü
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var v = Game.village("konoha")
	var c0 = Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 260.0, float(v["y"]) + 120.0))
	pl.respawn(Vector3(c0.x, Game.terrain_height(c0.x, c0.z) + 1.0, c0.z))
	await _w(5.0)
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather = "açık"
	var R = load("res://scripts/world/roadside.gd")
	var holder = Node3D.new()
	get_tree().current_scene.add_child(holder)
	var b = Builder.new(holder, 0.0, 0.0, 0.0, "Deneme")
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var sx = pl.global_position.x + 14.0
	var sn = -pl.global_position.z
	R._ruined_shrine(b, sx, sn, rng)
	b.finish()
	await _w(1.5)
	var c = Vector3(sx, Game.terrain_height(sx, -sn), -sn)
	var k = 0
	for dv in [Vector3(-3, 5, 15), Vector3(13, 6, 7), Vector3(-12, 4, -9), Vector3(2, 14, 4)]:
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.fov = 55.0
		cam.current = true
		cam.global_position = c + dv
		cam.look_at(c + Vector3.UP * 1.2)
		await _w(0.5)
		get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/ruin_%d.png" % k)
		cam.queue_free()
		k += 1
	get_tree().quit()
