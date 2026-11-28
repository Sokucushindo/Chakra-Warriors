extends Node
## Çift zıplama + ileri atılış: gövde hareketi kare kare (yandan)
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
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 300.0, float(v["y"]))) + Vector3(0, 1, 0))
	await _w(5.0)
	Game.world.env.time_of_day = 0.5
	pl.chakra = 999.0
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 40.0
	cam.current = true
	for rep in 2:
		pl.velocity = Vector3.ZERO
		await _w(1.2)
		pl._jump()
		await _w(0.22)
		var ok = pl._ninja_dash()
		var d: Vector3 = pl.velocity.normalized()
		d.y = 0.0
		var side = d.cross(Vector3.UP).normalized()
		print("NDASH ", rep, " oldu=", ok, " tür=", pl.flip_kind, " hız=", pl.velocity.length())
		var p0: Vector3 = pl.global_position
		cam.global_position = p0 + side * 5.5 + Vector3.UP * 1.0
		cam.look_at(p0 + Vector3.UP * 0.9)
		for f in 8:
			for q in 3:
				pl.velocity = Vector3.ZERO
				pl.global_position = p0
				cam.current = true
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/nd_%d_%d.png" % [rep, f])
		print("NDASH son tür=", pl.flip_kind, " flip_t=", pl.flip_t, " yerde=", pl.grounded)
	get_tree().quit()
