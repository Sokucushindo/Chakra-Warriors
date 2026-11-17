extends Node
## Kabarık taç (kameraya dönen yaprak kartları): orman halkasında aynı kareler kartlar dönmez / döner + GPU süresi; bir ağacın çevresinde dönerek 3 açı
var main: Node
var mats := []
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _bb(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("billboard", v)
func _gpu() -> float:
	var rid = get_viewport().get_viewport_rid()
	await _w(0.8)
	var g = 0.0
	for i in 90:
		await get_tree().process_frame
		g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return g / 90.0
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _w(3.0)
	Hud.close_dialog()
	var env = main.world.env
	env.region_weather = "açık"
	env.weather_t = 9999.0
	env.time_of_day = 0.42
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var q = Missions.open_ground(c + Vector3(0.7, 0, -0.7) * (float(v["r"]) + 330.0), 40.0)
	q.y = Game.ground_height(q.x, q.z) + 0.5
	main.player.global_position = q
	await _w(12.0)
	main.player.visible = false
	for mi in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var ms = []
		if mi is MeshInstance3D and mi.mesh:
			for s in mi.mesh.get_surface_count():
				ms.append(mi.mesh.surface_get_material(s))
		if mi is MultiMeshInstance3D and mi.multimesh and mi.multimesh.mesh:
			for s in mi.multimesh.mesh.get_surface_count():
				ms.append(mi.multimesh.mesh.surface_get_material(s))
		for m in ms:
			if m is ShaderMaterial and m.shader and m.shader.resource_path.ends_with("anime_leaf.gdshader") and not m in mats:
				mats.append(m)
	print("FL leaf mats=", mats.size())
	var cc = Camera3D.new()
	get_tree().current_scene.add_child(cc)
	cc.current = true
	env.attach_post(cc)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var p = main.player.global_position
	var views = [["genel", Vector3(0, 2.0, 0), Vector3(0, 6, 30)], ["yakin", Vector3(0, 3.0, 0), Vector3(8, 9, 14)]]
	for a in 3:
		var ang = a * TAU / 3.0
		views.append(["donus%d" % a, Vector3(cos(ang) * 16.0, 7.0, sin(ang) * 16.0) + Vector3(0, 0, 18), Vector3(0, 7, 18)])
	for vw in views:
		cc.global_position = p + vw[1]
		cc.look_at(p + vw[2])
		for bb in [0.0, 1.0]:
			_bb(bb)
			var g = await _gpu()
			print("FL %s bb=%.0f gpu %.2f" % [vw[0], bb, g])
			await main.shot("fl_%s_%d" % [vw[0], int(bb)])
	get_tree().quit()
