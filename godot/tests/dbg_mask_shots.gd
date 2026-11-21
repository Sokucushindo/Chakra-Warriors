extends Node
## Tam yüz maskesi (anbu_kus) yakın çekim: önden, yandan, çapraz, üstten — erkek genç / yetişkin, kadın yetişkin.
var main: Node
var OUT := (ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/shots/maske/")
func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.45
	await get_tree().create_timer(5.0).timeout
	Hud.visible = false
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.fov = 30.0
	var base = main.player.global_position + Vector3(0, 0, -8)
	var i = 0
	for cfg in [["m", "teen"], ["m", "adult"], ["f", "adult"]]:
		var lk: Dictionary = main.player.model.look.duplicate()
		lk["gender"] = cfg[0]
		lk["age"] = cfg[1]
		lk["face_style"] = "anbu_kus"
		var m = CharacterModel.new()
		get_tree().current_scene.add_child(m)
		m.global_position = base + Vector3(i * 3.0, 0, 0)
		m.setup(lk)
		var t0 = Time.get_ticks_msec()
		while not m.built and Time.get_ticks_msec() - t0 < 5000:
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		var hb = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Head"))
		var tg: Vector3 = hb.origin + Vector3(0, 0.08, 0)
		var fw: Vector3 = -m.global_transform.basis.z
		var rt: Vector3 = m.global_transform.basis.x
		for v in [["on", fw * 0.9], ["yan", rt * 0.9], ["capraz", (fw + rt).normalized() * 0.9], ["ust", fw * 0.5 + Vector3(0, 0.6, 0)]]:
			cam.global_position = tg + v[1]
			cam.look_at(tg)
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png(OUT + "%s_%s_%s.png" % [cfg[0], cfg[1], v[0]])
		m.queue_free()
		i += 1
	print("MASKE bitti")
	get_tree().quit()
