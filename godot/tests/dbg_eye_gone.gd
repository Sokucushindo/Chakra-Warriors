extends Node
## Göz çıkarma: çıkarılan göz kapalı + kanlı mı, ekranın o yarısı kararıyor mu, ikisi de gidince tamamen mi
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _face(pl, tag: String) -> void:
	var sk: Skeleton3D = pl.model.skel
	var hd: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin + Vector3.UP * 0.07
	var fd: Vector3 = pl.face_dir()
	var k := 0
	for ang in [0.0, 35.0, -35.0]:
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.fov = 22.0
		cam.global_position = hd + (fd * 1.1).rotated(Vector3.UP, deg_to_rad(ang))
		cam.look_at(hd)
		cam.make_current()
		await get_tree().process_frame
		if Hud._blind_layer:
			Hud._blind_layer.visible = false
		await _w(0.25)
		if Hud._blind_layer:
			Hud._blind_layer.visible = false
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/eyeg_%s_f%d.png" % [tag, k])
		cam.queue_free()
		k += 1
	await _w(1.2)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/eyeg_%s_scr.png" % tag)
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.25, 0.5), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.1, 0.1, 0.1), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pl = main.player
	var v = Game.village("konoha")
	var c0 = Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 260.0, float(v["y"]) + 300.0))
	pl.respawn(Vector3(c0.x, Game.terrain_height(c0.x, c0.z) + 1.0, c0.z))
	await _w(5.0)
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather = "açık"
	var pr = Game.profile
	var G = LazyFx.g("Gear")
	for s in ["sag_goz", "sol_goz"]:
		if G.equipped(pr, s).is_empty():
			G.grant(pr, "goz_sharingan", s, null, null, {"lvl": 3, "origin": "dogustan"})
	G.apply_look(pr)
	pl.rebuild_model()
	await _w(2.0)
	print("EYEG başta takılı=", [G.equipped(pr, "sag_goz").get("id"), G.equipped(pr, "sol_goz").get("id")], " yok=", G.eyes_gone(pr), " göz malzemesi=", pl.model.eye_mat.shader.resource_path if pl.model.eye_mat else "yok")
	await _face(pl, "0")
	Menus._eye_remove(pr, "sag_goz")
	await _w(2.5)
	print("EYEG sağ çıkarıldı yok=", G.eyes_gone(pr), " bakış=", pr["look"].get("eye_gone_r"), pr["look"].get("eye_gone_l"), " karartma=", Hud._blind_k)
	await _face(pl, "1")
	Menus._eye_remove(pr, "sol_goz")
	await _w(2.5)
	print("EYEG sol çıkarıldı yok=", G.eyes_gone(pr), " karartma=", Hud._blind_k)
	await _face(pl, "2")
	# yeni göz takılınca açılır mı
	for g in pr["gear"]:
		if String(g.get("id", "")) == "goz_sharingan":
			Eyes.transplant(pr, int(g["uid"]), "sag_goz")
			break
	await _w(2.5)
	print("EYEG sağa göz takıldı yok=", G.eyes_gone(pr), " karartma=", Hud._blind_k)
	await _face(pl, "3")
	get_tree().quit()
