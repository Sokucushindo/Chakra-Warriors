extends Node
## Binek: oyuncu hayvanın kafasına/sırtına oturuyor mu (gövdenin içinde kaybolmasın)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 700.0, float(v["y"]))) + Vector3(0, 1, 0))
	await get_tree().create_timer(2.0).timeout
	await get_tree().create_timer(20.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	LazyFx.g("DojutsuFXA").chikushodo(PathJutsu.get_pinst(), pl, null)
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.far = 3000.0
	cam.current = true
	var fd: Vector3 = pl.face_dir()
	cam.global_position = pl.global_position + fd * 38.0 + Vector3.UP * 26.0
	cam.look_at(pl.global_position + Vector3.UP * 2.0)
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/ck_1.png")
	await get_tree().create_timer(7.0).timeout
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/ck_2.png")
	var ps = []
	for s in get_tree().current_scene.get_children():
		if s is Summon:
			ps.append(s)
	var mn = 1e9
	for a in ps:
		for b in ps:
			if a != b:
				mn = minf(mn, a.global_position.distance_to(b.global_position) - (a.height + b.height) * 0.3)
	print("CK hayvan=%d en yakin ikili arasi bosluk=%.1f m" % [ps.size(), mn])
	get_tree().quit()
