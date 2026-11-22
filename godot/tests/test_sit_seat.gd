extends Node
## Oturan NPC'ler havada kalmasın: düz oturan (sitter) + oturup konuşan (eat_mode döngüsü: sit / Sitting_Talking); kalça - oturak farkı, görüntü
var main: Node
var OUT := (ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/shots/oturma/")
func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.42
	await get_tree().create_timer(6.0).timeout
	var pl = main.player
	var kv = Game.world_info["villages"][0]
	var base = Missions.open_ground(Vector3(float(kv["x"]) + float(kv["r"]) + 120.0, 0, -float(kv["y"])), 20.0)
	base.y = Game.ground_height(base.x, base.z)
	pl.global_position = base + Vector3(0, 0, 8)
	await get_tree().create_timer(3.0).timeout
	var vs = []
	for i in 4:
		var vg = Villager.new()
		vg.role = "sitter" if i < 2 else "customer"
		if i >= 2:
			vg.eat_mode = true
		get_tree().current_scene.add_child(vg)
		var q = base + Vector3(-3.0 + i * 2.0, 0, 0)
		q.y = Game.ground_height(q.x, q.z)
		vg.global_position = q
		vg.home = q
		vs.append(vg)
	await get_tree().create_timer(3.0).timeout
	var worst := 0.0
	for t in 24:
		await get_tree().create_timer(0.5).timeout
		for vg in vs:
			if not is_instance_valid(vg) or is_nan(vg._seat_y):
				continue
			var gap = vg._hips_w().y - (vg._seat_y + 0.07 * vg.model.age_scale)
			worst = maxf(worst, absf(gap))
	for vg in vs:
		print("OTUR %s anim=%s tabure=%s kalca-oturak=%.3f" % [vg.role, vg.model.current, vg._stool != null, vg._hips_w().y - vg._seat_y])
	print("OTUR en_kotu_sapma=%.3f m" % worst)
	Hud.visible = false
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.fov = 45.0
	var c = base + Vector3(0, 0.8, 0)
	for v in [["on", Vector3(0, 1.0, 6.0)], ["yan", Vector3(6.5, 0.8, 0.5)], ["capraz", Vector3(4.0, 1.5, 4.5)]]:
		cam.global_position = c + v[1]
		cam.look_at(c)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(OUT + "%s.png" % v[0])
	print("OTUR bitti")
	get_tree().quit()
