extends Node
## Susanoo jutsularında zırh parçaları kayboluyor mu: parça ağlarının görünürlüğü / katmanı / görünürlük menzili + uzak çekim
var main: Node
var pl

func _info(sn) -> String:
	if sn == null or not is_instance_valid(sn):
		return "NO_SUS"
	var n = 0; var vis = 0; var lay0 = 0; var vr = 0; var vr_far = 0
	var cam = get_viewport().get_camera_3d()
	for mi in sn.body.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override != sn.mat and mi.material_override != sn.gmat:
			continue
		n += 1
		if mi.is_visible_in_tree():
			vis += 1
		if mi.layers == 0:
			lay0 += 1
		if mi.visibility_range_end > 0.0:
			vr += 1
			if cam and cam.global_position.distance_to(mi.global_position) > mi.visibility_range_end:
				vr_far += 1
	return "tier=%d scale=%.2f parts=%d visible=%d layers0=%d vis_range=%d culled_by_range_now=%d" % [sn.tier, sn.scale.x, n, vis, lay0, vr, vr_far]

func _player_sn():
	var ey = pl.combat.modes.eyes
	return ey.susanoo_node if ey.susanoo and is_instance_valid(ey.susanoo_node) else null

func _far_cam(H: float) -> void:
	var fwd = pl.face_dir()
	pl.cam.global_position = pl.global_position - fwd * H * 1.6 + Vector3.UP * H * 0.9
	pl.cam.look_at(pl.global_position + Vector3.UP * H * 0.5)

func _cast(jid: String) -> void:
	pl.combat.action = ""
	pl.combat.begin_cast(jid)
	if _player_sn() == null:   # yuva / öğrenme şartı tutmazsa: jutsunun kullandığı yol (Susanoo.of) doğrudan
		Susanoo.of(pl, jid)

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	Hud.show_game_hud(false)
	pl = main.player
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
	pl.set_process(false)
	var ey = pl.combat.modes.eyes
	Susanoo.config(pr)["tier_pref"] = 5
	var H = Susanoo.TIER_HEIGHT[5]
	var e = Enemy.new()
	var a = Enemy.archetype("bandit", 0)
	a["hp"] = 999999.0
	a["respawn"] = false
	e.setup(a)
	main.add_child(e)
	var ep = pl.global_position + pl.face_dir() * 70.0
	ep.y = Game.ground_height(ep.x, ep.z)
	e.global_position = ep
	e.set_physics_process(false)
	pl.combat.lock_target = e
	var jids = ["susanoo_kaien", "susanoo_kamui_raikiri", "susanoo_kobushi", "susanoo_kai", "totsuka_no_tsurugi", "susanoo_dan"]
	var i = 0
	for jid in jids:
		if not Data.jutsu.has(jid):
			print("SUSARM skip %s" % jid)
			continue
		# baştan: Susanoo kapalı
		if ey.susanoo:
			ey._end_susanoo()
			await get_tree().create_timer(0.5).timeout
		_cast(jid)
		await get_tree().process_frame
		print("SUSARM off->%s f1 %s" % [jid, _info(_player_sn())])
		await get_tree().create_timer(1.2).timeout
		_far_cam(H)
		await get_tree().process_frame
		print("SUSARM off->%s 1.2s %s" % [jid, _info(_player_sn())])
		if i < 3:
			await main.shot("off_%s" % jid)
		# açıkken yeniden
		_cast(jid)
		await get_tree().create_timer(0.3).timeout
		_cast(jid)
		await get_tree().create_timer(1.5).timeout
		_far_cam(H)
		await get_tree().process_frame
		print("SUSARM on->%s recast %s" % [jid, _info(_player_sn())])
		i += 1
	await main.shot("final_far")
	# düşman EMS
	ey._end_susanoo()
	var e2 = Enemy.new()
	var a2 = Enemy.archetype("rogue", 0)
	a2["respawn"] = false
	e2.setup(a2)
	main.add_child(e2)
	var ep2 = pl.global_position + pl.face_dir() * 40.0
	ep2.y = Game.ground_height(ep2.x, ep2.z)
	e2.global_position = ep2
	Eyes.give_enemy_eyes(e2, 5)
	await get_tree().create_timer(1.0).timeout
	var sn2 = Susanoo.of(e2, "susanoo_kaien")
	await get_tree().create_timer(1.5).timeout
	print("SUSARM enemy %s" % _info(sn2))
	pl.cam.global_position = ep2 - pl.face_dir() * 70.0 + Vector3.UP * 40.0
	pl.cam.look_at(ep2 + Vector3.UP * 20.0)
	await get_tree().process_frame
	print("SUSARM enemy far %s" % _info(sn2))
	await main.shot("enemy_far")
	get_tree().quit()
