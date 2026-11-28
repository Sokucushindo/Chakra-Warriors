extends Node
## Obito / Tobi maskeleri: her maske için uzak + yakın açılar, duruş ve koşu; sağ göz Sharingan, sol göz Rinnegan
## (delikten görünmeli). Argümanlar: --shots=<klasör> --masks=a,b --mode=quick|full --gender=m|f
var main: Node

func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k):
			return a.substr(k.length() + 3)
	return d

func _ready() -> void:
	await get_tree().process_frame
	var OUT := _arg("shots", "D:/Naruto 3D Game/_tmp/obitomask").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var masks := _arg("masks", "spiral_maske,shima_kamen,uzu_kamen,rinne_kamen,rinne_kamen_ware").split(",")
	var full := _arg("mode", "quick") == "full"
	var gen := _arg("gender", "m")
	main.creator_state = {"slot": 3, "name": "Test", "gender": gen, "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.12), "eye": Color(0.25, 0.16, 0.1), "skin": Color(0.95, 0.82, 0.72), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.45
	await get_tree().create_timer(4.0).timeout
	Hud.visible = false
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.fov = 30.0
	var base = main.player.global_position + Vector3(0, 0, -9)
	main.player.global_position += Vector3(0, 0, 30)
	for ms in masks:
		var lk: Dictionary = main.player.model.look.duplicate()
		lk["gender"] = gen
		lk["face_style"] = ms
		lk["age"] = "adult"   # ölçü anlaşılsın diye yetişkin gövdede (kullanıcı: "küçük çocuk kafasına koyma")
		lk["years"] = 26.0
		if OS.has_environment("OB_W"):   # Uchiha gunbai (OB_DRAWN=1 elde, yoksa sırtta)
			lk["weapon_r"] = "gunbai"
			lk["weapon_skin_r"] = "uchiha_gunbai"
		var m = CharacterModel.new()
		get_tree().current_scene.add_child(m)
		m.global_position = base
		var t0 = Time.get_ticks_msec()
		m.setup(lk)
		while not m.built and Time.get_ticks_msec() - t0 < 8000:
			await get_tree().process_frame
		print("MASKE %s kuruldu %d ms" % [ms, Time.get_ticks_msec() - t0])
		m.set_dojutsu_eyes(1, 3, 6, 0)
		if OS.has_environment("OB_W"):
			m.set_drawn(OS.has_environment("OB_DRAWN"), false)
		if OS.has_environment("OBDBG_HIDE"):
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				if (mi == m.body_mesh and OS.get_environment("OBDBG_HIDE") != "face") or (mi == m.face_mi and OS.get_environment("OBDBG_HIDE") != "body"):
					mi.visible = false
		m.play("idle")
		await get_tree().create_timer(0.6).timeout
		for pose in (["dur", "kos"] if full else ["dur"]):
			if pose == "kos":
				m.play("run")
				await get_tree().create_timer(0.45).timeout
			var hb = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Head"))
			var tg: Vector3 = hb.origin + Vector3(0, 0.07, 0)
			var fw: Vector3 = -m.global_transform.basis.z
			var rt: Vector3 = m.global_transform.basis.x
			var views := []
			var angs := [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0] if full else [0.0, 35.0, -35.0, 90.0]
			for a in angs:
				var d: Vector3 = (fw * cos(deg_to_rad(a)) + rt * sin(deg_to_rad(a))).normalized()
				views.append(["yakin%+04d" % int(a), d * 0.75 + Vector3(0, 0.03, 0), tg])
				if full:
					views.append(["uzak%+04d" % int(a), d * 4.2 + Vector3(0, 0.6, 0), m.global_position + Vector3(0, 1.0, 0)])
			if full:
				views.append(["yakin_ust", fw * 0.45 + Vector3(0, 0.55, 0), tg])
				views.append(["yakin_alt", fw * 0.6 + Vector3(0, -0.3, 0), tg])
			var hup := Vector3.UP
			if OS.has_environment("OB_HEAD"):   # kafanın kendi eksenine göre tam ön / yan / arka (duruşta kafa dönük olabiliyor)
				var hi: int = m.skel.find_bone("Head")
				var rw: Basis = (m.skel.global_transform * m.skel.get_bone_global_pose(hi)).basis * m.skel.get_bone_global_rest(hi).basis.inverse()
				rw = rw.orthonormalized()
				var hf: Vector3 = rw * Vector3(0, 0, 1)
				var hr: Vector3 = rw * Vector3(1, 0, 0)
				hup = rw * Vector3(0, 1, 0)
				var hc: Vector3 = hb.origin + hup * 0.06
				views = []
				for a in [0.0, 45.0, 90.0, 135.0, 180.0, -90.0]:
					views.append(["h%+04d" % int(a), (hf * cos(deg_to_rad(a)) + hr * sin(deg_to_rad(a))) * 0.8, hc])
				views.append(["h_alt", (hf * 0.75 - hup * 0.35), hc])
				views.append(["h_ust", (hf * 0.3 + hup * 0.75), hc])
				for a in [20.0, 160.0, 90.0]:
					var d2: Vector3 = (fw * cos(deg_to_rad(a)) + rt * sin(deg_to_rad(a))).normalized()
					views.append(["u%+04d" % int(a), d2 * 2.6 + Vector3(0, 0.25, 0), m.global_position + Vector3(0, 1.25, 0)])
			for v in views:
				cam.global_position = v[2] + v[1]
				cam.look_at(v[2], hup if absf((v[1] as Vector3).normalized().dot(hup)) < 0.95 else Vector3.FORWARD)
				await get_tree().create_timer(0.12 if pose == "dur" else 0.05).timeout
				var img: Image = get_viewport().get_texture().get_image()
				img.resize(img.get_width() / 2, img.get_height() / 2)
				img.save_jpg(OUT + "%s_%s_%s_%s.jpg" % [ms, gen, pose, v[0]], 0.88)
		m.queue_free()
		await get_tree().process_frame
	print("OBITO MASKE bitti")
	get_tree().quit()
