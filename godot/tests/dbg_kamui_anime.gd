extends Node
## Kamui anime görünüşü: kendi giriş burgacı (yan/ön), dokunarak yutma (yan/ön, ceset karesi yok), Kakashi uzak Kamui,
## geçirgenlik dalgası, boyutta tutsakların kütlede durması (y ölçümü), tutsağı yeniden Kamui'ye alınca dünyadaki eski yerine
## dönmesi, boyut mini haritası + çıkınca dünya haritası. --shots=<dir>   Deneme kayıt yuvası 95.
var main: Node
const KS = preload("res://scripts/world/kamui_space.gd")
var fails := 0
var rel_pos = null


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ok(name: String, cond: bool, extra := "") -> void:
	if not cond:
		fails += 1
	print("KA %s %s %s" % ["OK  " if cond else "FAIL", name, extra])


func _enemy(at: Vector3, lv := 1) -> Enemy:
	var e := Enemy.new()
	var a = Enemy.archetype("rogue", 1)
	a["level"] = lv
	e.setup(a)
	main.actors.add_child(e)
	e.global_position = at
	return e


func _cam(pl, yaw: float, pitch: float, dist: float) -> void:
	pl.yaw = yaw
	pl.pitch = pitch
	pl.cam_dist = dist


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "Kamui Anime", "gender": "m", "clan": "uchiha", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(3.0)
	var t_load = Time.get_ticks_msec()
	while main.get("loading") != null and Time.get_ticks_msec() - t_load < 60000:
		await _w(0.5)
	await _w(1.5)
	Hud.close_dialog()
	var pl = main.player
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 300.0), 40.0)
	at.y = Game.ground_height(at.x, at.z)
	pl.respawn(at)
	await _w(1.0)
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != pl and Combat.hostile(pl, f):
			f.queue_free()
	Cheats.set_on("god", true)
	Cheats.give_eye(3, 2, Cheats.ms_style_keys().find("obito"))
	await _w(0.4)
	var ey = pl.combat.modes.eyes
	ey.toggle()
	await _w(0.4)
	ey.open_ms()
	await _w(0.5)
	pl.facing = 0.0
	Hud.show_game_hud(false)
	var A: Vector3 = pl.global_position

	# ---- a) kendi girişi: sağ gözdeki burgaca akış (yan + ön), dönme yok
	for v in [["yan", 90.0], ["on", 180.0]]:
		pl.global_position = A
		pl.facing = 0.0
		_cam(pl, v[1], -4.0, 3.6)
		await _w(0.5)
		var r0 = pl.model.rotation.y
		MsArts.kamui_vortex(KS.eye_point(pl), 1.6, 1.0, {"pull": 0.55})
		KS._shrink(pl, 0.45)
		var maxrot = 0.0
		for k in 5:
			await _w(0.09)
			maxrot = maxf(maxrot, absf(pl.model.rotation.y - r0))
			await main.shot("a_self_%s_%d" % [v[0], k])
		_ok("self_no_spin_" + v[0], maxrot < 0.05, "rot=%.3f" % maxrot)
		await _w(0.4)
		MsArts.kamui_vortex(KS.eye_point(pl), 1.6, 0.8, {"pull": -0.5})
		KS._shrink(pl, 0.4, true)
		await _w(0.15)
		await main.shot("a_self_%s_cikis" % v[0])
		await _w(0.5)

	# ---- b) dokunarak yutma (yan + ön): beden temas noktasına akar; ceset / kan / düşüş karesi yok
	var P1 := Vector3.ZERO
	for v in [["yan", 90.0], ["on", 220.0]]:
		pl.global_position = A
		pl.facing = 0.0
		var e1 = _enemy(A + pl.face_dir() * 2.6, 1)
		e1.set_physics_process(false)
		e1.facing = PI
		_cam(pl, v[1], -6.0, 5.0)
		await _w(0.6)
		if v[0] == "yan":
			P1 = e1.global_position
		var n0 = KS.held().size()
		ey.cd["sag"] = 0.0
		var r0 = e1.model.rotation.y
		ey._kamui_absorb(e1)
		var maxrot = 0.0
		for k in 5:
			await _w(0.22)
			if is_instance_valid(e1) and e1.model:
				maxrot = maxf(maxrot, absf(e1.model.rotation.y - r0))
			await main.shot("b_touch_%s_%d" % [v[0], k])
		await _w(0.2)
		await main.shot("b_touch_%s_after" % v[0])
		var vis = is_instance_valid(e1) and e1.model.visible
		_ok("touch_no_spin_" + v[0], maxrot < 0.05, "rot=%.3f" % maxrot)
		_ok("touch_gone_" + v[0], KS.held().size() == n0 + 1 and not vis, "held %d->%d vis=%s" % [n0, KS.held().size(), vis])
		await _w(0.9)
		var pools = 0
		for n in get_tree().current_scene.find_children("*", "", true, false):
			if String(n.name).to_lower().contains("blood"):
				pools += 1
		await main.shot("b_touch_%s_late" % v[0])
		print("KA blood-ish nodes %d" % pools)

	# ---- c) Kakashi uzak Kamui: odaktaki uzay burkulur, zayıf hedef akıp kaybolur
	pl.global_position = A
	pl.facing = 0.0
	var e3 = _enemy(A + pl.face_dir() * 7.0, 1)
	e3.apply_status("bind", 12.0)   # yerinde dursun (fizik açık: model / görünürlük güncellensin)
	e3.hp = e3.max_hp * 0.2
	_cam(pl, 22.0, -3.0, 3.5)
	await _w(0.6)
	Jutsu.j_kamui(pl, e3)
	for k in 7:
		await _w(0.3)
		await main.shot("c_long_%d" % k)
	await _w(0.4)
	_ok("long_gone", not is_instance_valid(e3) or not e3.model.visible)
	_cam(pl, 60.0, -4.0, 4.0)
	var e4 = _enemy(A + pl.face_dir() * 7.0, 300)   # güçlü: parça kopar, beden geri yaylanır
	e4.apply_status("bind", 12.0)   # yerinde dursun (fizik açık: model / görünürlük güncellensin)
	await _w(0.6)
	Jutsu.j_kamui(pl, e4)
	for k in 4:
		await _w(0.35)
		await main.shot("c_strong_%d" % k)
	if is_instance_valid(e4):
		_ok("strong_back", e4.model.visible and e4.model.scale.y > 0.5, "sy=%.2f" % e4.model.scale.y)
		e4.queue_free()

	# ---- d) geçirgenlik: darbe geçince küçük burkulma
	pl.global_position = A
	_cam(pl, 150.0, -5.0, 3.6)
	await _w(0.5)
	ey._phase_start()
	await _w(0.15)
	for k in 3:
		pl.combat.take_hit({"dmg": 10.0, "kind": "light", "attacker": null, "dir": Vector3.FORWARD})
		await _w(0.12)
		await main.shot("d_phase_%d" % k)
	ey._phase_end()

	# ---- e) boyut: tutsaklar kütlede durur (y ölçümü), mini harita
	Hud.show_game_hud(true)
	Cheats.set_on("god", true)
	pl.combat.cooldowns.erase("kamui_kukan")
	pl.chakra = pl.max_chakra
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(3.0)
	var ks = KS.inst
	_ok("inside", KS.player_inside(), "live=%d" % ks.live.size())
	await main.shot("e_inside_hud")
	print("KA region=%s" % Game.region_name(pl.global_position))
	if ks.live.size() > 0:
		var pz: Enemy = ks.live[0]
		# tutsağın yanına git (physics açık kalsın: ölçüm)
		pl.global_position = pz.global_position + Vector3(0, 0.5, 6.0)
		pl.reset_physics_interpolation()
		var miny = 1e9
		var maxdy = 0.0
		var t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 8000:
			await get_tree().physics_frame
			for e in ks.live:
				if is_instance_valid(e):
					var dd = float(e.home.y) - e.global_position.y
					if dd > 1.5 and not e.has_meta("ka_drop"):
						e.set_meta("ka_drop", true)
						print("KA drop: %s state=%s dy=%.2f dist_pl=%.1f tgt=%s" % [e.display_name, e.state, dd, e.global_position.distance_to(pl.global_position), str(e.target)])
					maxdy = maxf(maxdy, dd)
			miny = minf(miny, pz.global_position.y - float(pz.home.y))
		print("KA prisoner mask=%d layer_ok=%s state=%s" % [pz.collision_mask, str(pz.collision_mask & 1 != 0), pz.state])
		_ok("prisoners_stay_on_blocks", maxdy < 1.5, "max drop=%.2f m (pz min dy %.2f)" % [maxdy, miny])
		await main.shot("e_prisoners")
		# ---- f) tutsağı yeniden Kamui'ye al -> dünyada eski yerine döner
		var n0 = KS.held().size()
		var rec_pos = null
		for r in KS.held():
			if int(r.get("uid", -1)) == int(pz.get_meta("kamui_prisoner", -2)):
				rec_pos = str_to_var(String(r.get("pos", "")))
		pz.set_physics_process(false)
		pl.global_position = pz.global_position + Vector3(0, 0.3, 2.5)
		pl.reset_physics_interpolation()
		var d2 = pz.global_position - pl.global_position
		pl.facing = atan2(-d2.x, -d2.z)
		_cam(pl, rad_to_deg(pl.facing) + 90.0, -6.0, 5.0)
		await _w(0.5)
		ey.cd["sag"] = 0.0
		ey._kamui_absorb(pz)
		for k in 3:
			await _w(0.35)
			await main.shot("f_release_in_%d" % k)
		await _w(0.6)
		_ok("release_record_removed", KS.held().size() == n0 - 1, "held %d->%d" % [n0, KS.held().size()])
		var back: Enemy = null
		if rec_pos is Vector3:
			for f in get_tree().get_nodes_in_group("fighters"):
				if f is Enemy and not f.is_dead() and f.global_position.distance_to(rec_pos) < 3.0:
					back = f
		rel_pos = rec_pos
		_ok("released_at_original_spot", back != null, "rec=%s P1=%s" % [str(rec_pos), P1])
		await main.shot("e_map_after_release")
	# çık
	pl.combat.cooldowns.erase("kamui_kukan")
	pl.chakra = pl.max_chakra
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(2.5)
	_ok("exited", not KS.player_inside())
	print("KA region_after=%s" % Game.region_name(pl.global_position))
	await main.shot("g_back_hud")
	# dünyada eski yerdeki adam
	var near = null
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and not f.is_dead() and rel_pos is Vector3 and f.global_position.distance_to(rel_pos) < 3.0:
			near = f
	if near:
		near.set_physics_process(false)
		pl.global_position = near.global_position + Vector3(0, 0.3, 5.0)
		pl.reset_physics_interpolation()
		pl.facing = 0.0
		_cam(pl, 30.0, -8.0, 6.0)
		await _w(0.8)
		await main.shot("g_released_in_world")
	_ok("released_visible_in_world", near != null and near.model.visible)
	if near:
		near.queue_free()

	# ---- h) Kamui: Hōshutsu — yutulan saldırı hedefe geri, sonra tutsak hedefin yanına
	Hud.show_game_hud(false)
	pl.global_position = A
	pl.reset_physics_interpolation()
	pl.facing = 0.0
	var e5 = _enemy(A + pl.face_dir() * 7.0, 30)
	e5.apply_status("bind", 12.0)   # yerinde dursun (fizik açık: model / görünürlük güncellensin)
	e5.facing = PI
	_cam(pl, 22.0, -4.0, 3.5)
	await _w(0.6)
	var ok_slot = Data.jutsu.has("kamui_hoshutsu")
	_ok("hoshutsu_slot", ok_slot)
	var kd = e5.global_position + Vector3.UP * 1.3
	Projectile.tool(e5, kd, (pl.global_position + Vector3.UP * 1.2 - kd).normalized(), "kunai", pl)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var npr = 0
	for q in get_tree().get_nodes_in_group("projectiles"):
		npr += 1
		print("KA proj d=%.1f shooter=%s dead=%s" % [q.global_position.distance_to(pl.global_position + Vector3.UP), str(q.get("shooter")), str(q.get("dead"))])
	ey.cd["sag"] = 0.0
	ey._kamui_absorb(null)
	await _w(0.1)
	await main.shot("h_swallow_0")
	await _w(0.3)
	_ok("projectile_stored", KS.stored_shots.size() == 1, "n=%d" % KS.stored_shots.size())
	pl.combat.lock_target = e5
	var hp0 = e5.hp
	pl.chakra = pl.max_chakra
	pl.combat.cooldowns.erase("kamui_hoshutsu")
	SpecialSlots.cast(pl, "kamui_hoshutsu")
	for k in 3:
		await _w(0.1)
		await main.shot("h_shot_back_%d" % k)
	await _w(0.6)
	_ok("shot_back_hits", e5.hp < hp0, "hp %.0f -> %.0f" % [hp0, e5.hp])
	var nh = KS.held().size()
	pl.combat.cooldowns.erase("kamui_hoshutsu")
	SpecialSlots.cast(pl, "kamui_hoshutsu")
	for k in 3:
		await _w(0.18)
		await main.shot("h_prisoner_out_%d" % k)
	_ok("prisoner_out", KS.held().size() == nh - 1, "held %d->%d" % [nh, KS.held().size()])
	print("KA DONE fails=%d" % fails)
	get_tree().quit()
