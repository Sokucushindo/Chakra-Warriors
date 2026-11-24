extends Node
## 50 ev türü kataloğu: açık arazide 5 sıra x 10, her sıra önden çekilir (cat_0..4)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.42
	WorldDay.auto = false
	HouseKit.ensure()
	var base = main.player.global_position + Vector3(0, 900, 0)   # gökte: önünü hiçbir şey kesmez
	var walls_cols = [Color(0.9, 0.84, 0.72), Color(0.84, 0.86, 0.86), Color(0.84, 0.88, 0.76), Color(0.9, 0.8, 0.76)]
	var roof_cols = [Color(0.93, 0.56, 0.2), Color(0.4, 0.6, 0.85), Color(0.42, 0.66, 0.42), Color(0.82, 0.3, 0.22)]
	for i in 50:
		var t: Dictionary = HouseKit.templates[i]
		var row = i / 10
		var col = i % 10
		var p = base + Vector3(col * 34.0, 0, row * 400.0)
		var pl2 = MeshInstance3D.new()   # zemin plakası
		var bm = BoxMesh.new()
		bm.size = Vector3(32, 0.4, 40)
		pl2.mesh = bm
		get_tree().current_scene.add_child(pl2)
		pl2.global_position = p + Vector3(0, -0.2, 0)
		for pair in [["walls", walls_cols[i % 4]], ["roof", roof_cols[(i / 4) % 4]], ["detail", Color.WHITE]]:
			var mi = MeshInstance3D.new()
			mi.mesh = t[pair[0]]
			var m = StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.albedo_color = pair[1]
			mi.material_override = m
			get_tree().current_scene.add_child(mi)
			mi.global_position = p
			mi.rotation.y = PI
	var cam = Camera3D.new()
	cam.fov = 62.0
	get_tree().current_scene.add_child(cam)
	main.player.respawn(base + Vector3(150, 2, -40))
	await get_tree().create_timer(1.5).timeout
	main.player.visible = false
	for row in 5:
		var mid = base + Vector3(4.5 * 34.0, 0, row * 400.0)
		main.player.visible = false
		cam.global_position = mid + Vector3(0, 40, -175)
		cam.look_at(mid + Vector3(0, 6, 0))
		cam.current = true
		await get_tree().create_timer(0.6).timeout
		await main.shot("cat_%d" % row)
	get_tree().quit()
