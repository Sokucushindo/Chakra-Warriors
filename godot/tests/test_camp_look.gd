extends Node
## Kamp görünüşü: haydut/kaçak görev kampı (çadırlar + ateş), borçlu kaçak kampı, mağara ağzı, antrenman kuklası; birkaç açı.
var main: Node
var OUT := (ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/shots/kamp/")
func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.8
	await get_tree().create_timer(8.0).timeout
	Hud.visible = false
	var pl = main.player
	var kv = Game.world_info["villages"][0]
	var kc = Vector3(float(kv["x"]), 0, -float(kv["y"]))
	var base = kc + Vector3(float(kv["r"]) + 160.0, 0, 40.0)
	base = Missions.open_ground(base, 30.0)
	base.y = Game.ground_height(base.x, base.z)
	pl.global_position = base + Vector3(0, 0, 60)
	await get_tree().create_timer(3.0).timeout
	var camp = Missions._camp(base, "bandit")
	var c2 = base + Vector3(40, 0, 0)
	c2.y = Game.ground_height(c2.x, c2.z)
	var cave = Missions._lair_mouth(c2, false)
	var c3 = base + Vector3(-35, 0, 0)
	c3.y = Game.ground_height(c3.x, c3.z)
	var n = Node3D.new()
	get_tree().current_scene.add_child(n)
	n.global_position = c3
	Friends.inst()._lair_props(n)
	var c4 = base + Vector3(-35, 0, 18)
	for k in 3:
		var d = TrainingDummy.new()
		get_tree().current_scene.add_child(d)
		d.global_position = c4 + Vector3(k * 2.2, 0, 0)
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.fov = 50.0
	await get_tree().create_timer(1.5).timeout
	var cf: Vector3 = cave.global_transform.basis.z
	var shots = [
		["kamp_a", base + Vector3(14, 6, 14), base + Vector3(0, 1, 0)],
		["kamp_b", base + Vector3(-5, 2.2, 6), base + Vector3(-7, 1.2, -4)],
		["magara_on", c2 + cf * 16.0 + Vector3(0, 4, 0), c2 + Vector3(0, 2.5, 0) - cf * 3.0],
		["magara_yan", c2 + cf * 10.0 + cave.global_transform.basis.x * 12.0 + Vector3(0, 5, 0), c2 + Vector3(0, 2.5, 0) - cf * 4.0],
		["magara_yakin", c2 + cf * 6.0 + Vector3(0, 1.8, 0), c2 + Vector3(0, 1.6, 0)],
		["kacak_kamp", c3 + Vector3(5, 3.5, 7), c3 + Vector3(-1, 0.8, -0.5)],
		["kacak_cadir", c3 + Vector3(0, 1.6, 2), c3 + Vector3(-3.6, 1.0, -2.4)],
		["kukla", c4 + Vector3(2.2, 1.6, 4.5), c4 + Vector3(2.2, 1.2, 0)],
		["kukla_yakin", c4 + Vector3(0.6, 1.5, 2.0), c4 + Vector3(0, 1.2, 0)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(OUT + "%s.png" % s[0])
	print("KAMP bitti")
	get_tree().quit()
