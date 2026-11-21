extends Node
## Pirinç tarlası başındaki çiftçi evleri: en yakın 4 tarla, iki açıdan; kaç tarlada ev kuruldu sayımı
var main: Node
var OUT := (ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/shots/tarla/")
func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.42
	await get_tree().create_timer(5.0).timeout
	Hud.visible = false
	var list = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/features.json"))
	var ps = []
	for f in list:
		if String(f["t"]) == "paddy":
			ps.append(f)
	ps.sort_custom(func(a, b): return Vector2(a["x"], a["y"]).length() < Vector2(b["x"], b["y"]).length())
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.fov = 55.0
	for i in 4:
		var f = ps[i]
		var c = Vector3(float(f["x"]), 0, -float(f["y"]))
		c.y = Game.terrain_height(c.x, c.z)
		main.player.global_position = c + Vector3(0, 2, 0)
		await get_tree().create_timer(6.0).timeout
		for v in [["a", Vector3(45, 28, 45)], ["b", Vector3(-45, 22, -30)]]:
			cam.global_position = c + v[1]
			cam.look_at(c)
			await get_tree().create_timer(0.8).timeout
			get_viewport().get_texture().get_image().save_png(OUT + "t%d_%s.png" % [i, v[0]])
	print("TARLA bitti")
	get_tree().quit()
