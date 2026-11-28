extends Node
## Çatı ninjası: konunca bekliyor mu (hiç durmadan zıplamasın)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var vv = Game.village("konoha")
	main.player.respawn(Missions.open_ground(Game.from_map(Vector2(vv["x"], float(vv["y"]) + float(vv["r"]) * 0.25)), 20.0) + Vector3(0, 1, 0))
	var rf = null
	for i in 60:
		await _w(1.0)
		for v in get_tree().get_nodes_in_group("talkers"):
			if v is Villager and v.role == "roof":
				rf = v
		if rf != null and main.loading == null:
			break
	if rf == null:
		print("ROOF cati ninjasi yok"); print("bitti"); get_tree().quit(); return
	print("ROOF nokta=", rf.points.size(), " uzaklik=", rf.global_position.distance_to(main.player.global_position), " islem=", rf.is_physics_processing(), rf.is_processing())
	main.player.max_hp = 1e9; main.player.hp = 1e9
	var air = 0.0
	var ground = 0.0
	var hops = 0
	var was = false
	var shot = false
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and is_instance_valid(rf):
		var dt = get_process_delta_time()
		if rf.global_position.distance_to(main.player.global_position) > 25.0:
			main.player.global_position = rf.global_position + Vector3(6, 1.0, 6)
			main.player.velocity = Vector3.ZERO
		var in_air = rf.hop_t >= 0.0
		if in_air and not was:
			hops += 1
		if in_air: air += dt
		else: ground += dt
		was = in_air
		if not in_air and ground > 1.0 and not shot:
			shot = true
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.current = true
			cam.global_position = rf.global_position + rf.face_dir() * 5.0 + Vector3(2, 1.6, 0)
			cam.look_at(rf.global_position + Vector3.UP * 1.0)
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/roof_wait.png")
			cam.queue_free()
		await get_tree().process_frame
	print("ROOF 30 sn: sicrama=%d havada=%.1f sn catida=%.1f sn" % [hops, air, ground])
	print("bitti")
	get_tree().quit()
