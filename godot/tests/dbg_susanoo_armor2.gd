extends Node
## Deney: Susanoo parçalarına 40 m görünürlük sınırı (eski NPC kırpması) konunca oyuncunun kamerası uzaklaştıkça zırh siliniyor mu
var main: Node

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	var pl = main.player
	var pr = Game.profile
	Gear.grant(pr, "goz_ems", "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "goz_ems", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.apply_look(pr)
	pl.rebuild_model()
	pl.chakra = 99999
	pl.max_chakra = 99999
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(v["x"], v["y"] + float(v["r"]) + 500)))
	await get_tree().create_timer(2.5).timeout
	Susanoo.config(pr)["tier_pref"] = 5
	# Susanoo kapalıyken Kaien: Susanoo.of açar, teknik aynı karede kol pozunu verir (katon_fx_c susanoo_kaien ile aynı)
	var sn = Susanoo.of(pl, "susanoo_kaien")
	# açılış yayının (TRANS_BACK) çukuru: Susanoo kurulumundan sonraki uzun kare (takılma) teknik pozunu bu ana düşürür
	var nf = 0
	while sn.scale.x > 1.5 and nf < 60:
		await get_tree().process_frame
		nf += 1
	print("SUSARM2 pose at frame %d scale=%.2f" % [nf, sn.scale.x])
	var fd = pl.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	sn.hide_weapons(2.0)
	sn.pose({"arms": Susanoo.arm(true, -fd * 0.5 + Vector3.UP * 0.3 + side * 0.5, fd * 0.4 + Vector3.UP * 0.2), "spine": -14.0}, 0.5, true)
	await get_tree().create_timer(2.5).timeout
	var parts = []
	for mi in sn.body.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == sn.mat or mi.material_override == sn.gmat:
			parts.append(mi)
			mi.set_meta("orig_vr", mi.visibility_range_end)
	print("SUSARM2 parts=%d with_range_now=%d cam_range=%s" % [parts.size(), parts.filter(func(m): return m.visibility_range_end > 0.0).size(), str(pl.cam_range)])
	for d in [75.0]:
		pl.cam_dist = d
		await get_tree().create_timer(0.8).timeout
		var cam = get_viewport().get_camera_3d()
		print("SUSARM2 cam=%s pl=%s sn=%s dist_cam_pl=%.1f" % [cam.get_path(), pl.global_position, sn.global_position, cam.global_position.distance_to(pl.global_position)])
		for mode in ["orig"]:
			for mi in parts:
				var sz: Vector3 = mi.get_aabb().size * mi.global_basis.get_scale()
				mi.visibility_range_end = 0.0 if mode == "norange" else float(mi.get_meta("orig_vr"))
			await get_tree().process_frame
			await get_tree().process_frame
			var far = 0
			for mi in parts:
				if mi.visibility_range_end > 0.0 and cam.global_position.distance_to(mi.global_transform * mi.get_aabb().get_center()) > 40.0:
					far += 1
			print("SUSARM2 camdist=%.0f mode=%s ranged=%d beyond40=%d" % [d, mode, parts.filter(func(m): return m.visibility_range_end > 0.0).size(), far])
			await main.shot("exp_d%d_%s" % [int(d), mode])
	get_tree().quit()
