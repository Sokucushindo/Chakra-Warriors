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
	var mods := []
	for i in 6:
		# köylü / düşman gibi: kimlik sözlüğüne üniforma birleştirilir
		var lk: Dictionary = CharacterModel.default_look()
		lk["gender"] = "f" if i == 3 else "m"
		lk["age"] = "adult"; lk["years"] = 27.0
		lk["hair"] = Color(0.2 + 0.1 * i, 0.15, 0.1)
		var u: Dictionary = LazyFx.g("SecretUnits").look("konoha" if i < 4 else ["kiri", "kumo"][i - 4], i)
		lk.merge(u, true)
		print("ANBU %d set=%s yuz=%s sac=%s cins=%s" % [i, lk.get("set_id", "-"), lk.get("face_style", "-"), lk.get("hair_style", "-"), lk.get("gender", "-")])
		var m = CharacterModel.new()
		get_tree().current_scene.add_child(m)
		m.global_position = base + Vector3((i - 2.5) * 1.1, 0, 0)
		m.setup(lk)
		mods.append(m)
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000:
		var ok := true
		for m in mods:
			ok = ok and m.built
		if ok:
			break
		await get_tree().process_frame
	for m in mods:
		m.play("idle")
	await get_tree().create_timer(0.8).timeout
	var c: Vector3 = base + Vector3(0, 1.0, 0)
	var fw: Vector3 = -mods[0].global_transform.basis.z
	for v in [["on", fw * 9.5 + Vector3(0, 0.5, 0)], ["arka", -fw * 9.5 + Vector3(0, 0.5, 0)]]:
		cam.global_position = c + v[1]
		cam.look_at(c)
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_jpg(OUT + "anbu_%s.jpg" % v[0], 0.9)
	print("ANBU bitti")
	get_tree().quit()
