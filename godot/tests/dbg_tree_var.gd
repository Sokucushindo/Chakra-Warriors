extends Node
## Ağaç dal çeşitliliği: orman devinin dört çeşidi + köy ağaçları yan yana (aynı kalıp mı?), çarpışma dalı sayısı
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather = "açık"
	var base: Vector3 = pl.global_position + Vector3(0, 600.0, 0)
	pl.model.visible = false
	var AT = LazyFx.g("AnimeTree")
	var rows = [[["forest", "forest", 0], ["forest", "forest", 1], ["forest", "forest", 3], ["forest", "forest", 4]],
		[["broad", "green", 0], ["broad", "green", 3], ["oak", "green", 2], ["oak", "green", 5], ["slender", "green", 1], ["slender", "green", 4]]]
	for ri in rows.size():
		var holder = Node3D.new()
		main.add_child(holder)
		var gap = 26.0 if ri == 0 else 13.0
		var n = (rows[ri] as Array).size()
		for i in n:
			var q: Array = rows[ri][i]
			var m: ArrayMesh = AT.mesh(q[0], q[1], q[2])
			var mi = MeshInstance3D.new()
			mi.mesh = m
			holder.add_child(mi)
			mi.global_position = base + Vector3((i - (n - 1) * 0.5) * gap, 0, 0)
			print("AGAC ", q, " çarpışma dalı ", (m.get_meta("limbs", []) as Array).size(), " üçgen ", m.surface_get_array_len(0) / 3 + (m.surface_get_array_len(1) / 3 if m.get_surface_count() > 1 else 0))
		for vk in 2:
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.fov = 50.0
			var h = 16.0 if ri == 0 else 6.0
			var dist = (62.0 if ri == 0 else 44.0)
			cam.global_position = base + Vector3(0 if vk == 0 else dist * 0.55, h + (0.0 if vk == 0 else 6.0), dist if vk == 0 else dist * 0.8)
			cam.look_at(base + Vector3(0, h, 0))
			cam.make_current()
			await _w(0.5)
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/agac_%d_%d.png" % [ri, vk])
			cam.queue_free()
		holder.queue_free()
		await _w(0.2)
	get_tree().quit()
