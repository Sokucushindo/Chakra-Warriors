extends Node
## Dövüş tarzı duruşları: her tarz yetişkin karakterde önden / yandan / çaprazdan (savaş hâli zorlanır)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	var g0 = Game.settings.get("grass", 3)
	Game.settings["grass"] = 0
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var v = Game.village("konoha")
	var c0 = Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 600.0, float(v["y"])))
	pl.respawn(Vector3(c0.x, Game.terrain_height(c0.x, c0.z) + 1.0, c0.z))
	await _w(5.0)
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather = "açık"
	pl.set_process(false)   # tarzı deneme seçer (oyuncunun kendi seçici işi dursun)
	var ids = OS.get_environment("IDS").split(",") if OS.get_environment("IDS") != "" else PackedStringArray(pl.model.overlay.FSTANCE.keys())
	var k := 0
	for id in ids:
		pl.model.fstyle = id
		pl.model.fight_on = true
		await _w(0.9)
		var hd: Vector3 = pl.global_position + Vector3.UP * 0.95
		var fd: Vector3 = pl.face_dir()
		var j := 0
		for ang in [0.0, 55.0, -90.0]:
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.fov = 30.0
			cam.global_position = hd + (fd * 4.6).rotated(Vector3.UP, deg_to_rad(ang)) + Vector3.UP * 0.25
			cam.look_at(hd)
			cam.make_current()
			await _w(0.25)
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/fst_%d_%d.png" % [k, j])
			cam.queue_free()
			j += 1
		print("FST ", id, " ağırlık ", snappedf(pl.model.overlay.weights.get("fstance", 0.0), 0.01), " anim ", pl.model.current)
		k += 1
	Game.settings["grass"] = g0
	get_tree().quit()
