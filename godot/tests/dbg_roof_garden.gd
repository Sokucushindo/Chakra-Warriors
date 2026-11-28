extends Node
## Çatı bahçesi: saksılar su deposuna / bacaya giriyor mu, çiçekler nasıl görünüyor (evler tek başına kurulur)
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
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 700.0, float(v["y"]))) + Vector3(0, 1, 0))
	await _w(5.0)
	Game.world.env.time_of_day = 0.42
	Game.world.env.weather = "açık"
	var HV = load("res://scripts/world/house_variety.gd")
	var idx := []
	for i in HV.SPECS.size():
		if "g" in String(HV.SPECS[i][4]) and String(HV.SPECS[i][1]) == "flat":
			idx.append(i)
	print("ROOF bahçeli tür: ", idx)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	var base: Vector3 = pl.global_position + Vector3(0, 0, -60)
	var n := 0
	for sd in [3, 11, 27, 40, 58, 73]:
		var rng = RandomNumberGenerator.new()
		rng.seed = sd
		var hi: int = idx[n % idx.size()]
		var h: Dictionary = HV.make(rng, hi)
		var root = Node3D.new()
		get_tree().current_scene.add_child(root)
		root.global_position = base + Vector3(n * 40.0, 0, 0)
		for key in ["walls", "roof", "detail"]:
			var mi = MeshInstance3D.new()
			mi.mesh = h[key]
			mi.material_override = mat
			root.add_child(mi)
		var top := float(h["h"])
		var c: Vector3 = root.global_position + Vector3(0, top, 0)
		for vi in 2:
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.fov = 50.0 if vi == 0 else 30.0
			cam.global_position = c + (Vector3(-4, 9, float(h["d"]) * 0.5 + 9) if vi == 0 else Vector3(3, 3.2, float(h["d"]) * 0.3 + 7))
			cam.look_at(c + Vector3(0, 0.8, float(h["d"]) * 0.2))
			cam.make_current()
			await _w(0.3)
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/roofg_%d_%d.png" % [n, vi])
			cam.queue_free()
		n += 1
	get_tree().quit()
