extends Node
## Doku gücü A/B: Konoha'da aynı kameralardan şimdiki ve güçlendirilmiş doku (binalar, çatılar, gövdeler, çimen zemin)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _mats() -> Array:
	var out := {}
	for n in get_tree().current_scene.find_children("*", "GeometryInstance3D", true, false):
		var ms := []
		if n.material_override is ShaderMaterial:
			ms.append(n.material_override)
		var mesh = null
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
		if mesh:
			for si in mesh.get_surface_count():
				var m = mesh.surface_get_material(si)
				if m is ShaderMaterial:
					ms.append(m)
		for m in ms:
			if m.get_shader_parameter("detail_tex_amt") != null and float(m.get_shader_parameter("detail_tex_amt")) > 0.0:
				out[m] = true
	return out.keys()
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var it = {}
	for q in Interact.items:
		if q.has("seats"):
			it = q
			break
	pl.respawn(it["pos"] + Vector3(0, 1, -24))
	await _w(6.0)
	Game.world.env.time_of_day = 0.42
	Game.world.env.weather = "açık"
	await _w(1.0)
	var c: Vector3 = pl.global_position + Vector3.UP * 2.0
	pl.model.visible = false
	for pass_i in 2:
		if pass_i == 1:
			var ms = _mats()
			print("TEX malzeme sayısı ", ms.size())
			for m in ms:
				m.set_shader_parameter("detail_tex_amt", minf(1.0, float(m.get_shader_parameter("detail_tex_amt")) * 2.2))
				if m.get_shader_parameter("leaf_tex_amt") != null:
					m.set_shader_parameter("leaf_tex_amt", minf(1.0, float(m.get_shader_parameter("leaf_tex_amt")) * 1.6))
			for tm in Game.world.terrain.mats:
				tm.set_shader_parameter("grass_tex_amt", 0.6)
		var k := 0
		for a in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, -1.0]:
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.fov = 45.0
			cam.global_position = c
			if a < 0.0:
				cam.look_at(c + Vector3(2.0, -1.6, 2.0))
			else:
				cam.look_at(c + Vector3(sin(deg_to_rad(a)), 0.05, cos(deg_to_rad(a))) * 10.0)
			cam.make_current()
			await _w(0.4)
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/tex_%d_%d.png" % [pass_i, k])
			cam.queue_free()
			k += 1
	get_tree().quit()
