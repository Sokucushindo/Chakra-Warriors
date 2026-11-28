extends Node
## Binek: oyuncu hayvanın kafasına/sırtına oturuyor mu (gövdenin içinde kaybolmasın)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 700.0, float(v["y"]))) + Vector3(0, 1, 0))
	await get_tree().create_timer(2.0).timeout
	await get_tree().create_timer(6.0).timeout
	var t00 = Time.get_ticks_msec()
	while main.loading != null and Time.get_ticks_msec() - t00 < 115000:
		await get_tree().create_timer(0.5).timeout
	print("MOUNT yukleme ", (Time.get_ticks_msec() - t00) / 1000.0, " sn")
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	pl.max_hp = 1e9; pl.hp = 1e9
	var only = OS.get_environment("ONLY")
	var list = []
	for cn in Contracts.DEFS:
		for ti in Contracts.DEFS[cn]["tiers"]:
			var d = Contracts.DEFS[cn]["tiers"][ti]
			if d.get("mount", false):
				list.append([cn, ti, String(d.get("name", cn))])
	for spec in list:
		if only != "" and not (spec[2] in only.split(",")):
			continue
		var s = Summon.new()
		s.contract = spec[0]
		s.tier = spec[1]
		s.def = Contracts.DEFS[spec[0]]["tiers"][spec[1]]
		s.owner_f = pl
		s.team = pl.team
		get_tree().current_scene.add_child(s)
		s.global_position = pl.global_position + Vector3(0, 0, -6)
		await get_tree().create_timer(0.8).timeout
		s.mounted = true
		s._seat = Vector3.INF
		s._ride_cam(pl, true)
		await get_tree().create_timer(2.2).timeout
		print("MOUNT %s h=%.1f kafa=%s kafa_nokta=%s kok_nokta=%s yilan=%s" % [spec[2], s.height, s.parts.get("head") != null and s.parts.get("head") != s.parts["root"], s._seat_head, s._seat, s._seat_snake != null])
		await _views(pl.global_position, Vector3(-sin(s.facing), 0, -cos(s.facing)), "s_" + spec[2])
		s._dismount()
		s.dismiss()
		await get_tree().create_timer(0.6).timeout
	var bc = null
	for ch in pl.find_children("*", "", true, false):
		if ch is BeastCloak:
			bc = ch
	if bc and OS.get_environment("NOBIJU") == "":
		for id in LazyFx.g("BeastModels").INFO.keys():
			if only != "" and not (String(id) in only.split(",")):
				continue
			pl.max_chakra = 1e9; pl.chakra = 1e9
			bc.ride_id = String(id)
			bc.ride_life = 60.0
			bc.set_level(6)
			await get_tree().create_timer(2.6).timeout
			print("MOUNT biju %s koltuk=%s seviye=%d" % [id, bc._ride_seat, bc.level])
			if not is_instance_valid(bc.rig) or bc.rig.head == null:
				print("MOUNT   (govde yok, atlandi)")
				bc.ride_end(false)
				await get_tree().create_timer(1.6).timeout
				continue
			var bh = float(bc.rig.get_meta("cam_h", 30.0))
			var hb: Basis = bc.rig.head.global_transform.basis.orthonormalized()
			var mp: Vector3 = pl.model.global_position
			var vi = 0
			bc.rig.set("fade_near", false)
			for mi0 in bc.rig.find_children("*", "GeometryInstance3D", true, false):
				mi0.transparency = 0.0
			for dv in [hb.x * bh * 1.1 + Vector3.UP * bh * 0.15, hb.z * -bh * 1.2 + Vector3.UP * bh * 0.3, hb.x * bh * 1.3 - hb.z * bh * 0.9 + Vector3.UP * bh * 0.5]:
				var cam = Camera3D.new()
				main.add_child(cam)
				cam.far = 5000.0
				cam.fov = 14.0 if vi < 2 else 45.0
				cam.current = true
				cam.global_position = mp + dv
				cam.look_at(mp + Vector3.UP * 0.6)
				await get_tree().create_timer(0.25).timeout
				get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/mnt2/b_%s_%d.png" % [id, vi])
				cam.queue_free()
				vi += 1
			bc.ride_end(false)
			await get_tree().create_timer(1.6).timeout
	get_tree().quit()
func _views(at: Vector3, fw: Vector3, tag: String) -> void:
	var i = 0
	for dv in [fw.cross(Vector3.UP) * 5.5 + Vector3.UP * 0.9, fw * 5.5 + Vector3.UP * 0.9, fw.cross(Vector3.UP) * 22.0 + fw * 12.0 + Vector3.UP * 7.0]:
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.far = 3000.0
		cam.fov = 50.0
		cam.current = true
		cam.global_position = at + dv
		cam.look_at(at + Vector3.UP * 0.6)
		await get_tree().create_timer(0.25).timeout
		get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/mnt2/%s_%d.png" % [tag, i])
		cam.queue_free()
		i += 1
