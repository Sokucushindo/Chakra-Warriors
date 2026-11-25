extends Node
## Kamui Kūkan uçtan uca: oyuncu kendi girer / çıkar (aynı yere döner), görüntüler (çok açı), FPS, NPC yutma -> tutsak boyutta,
## düşman Obito oyuncuyu çeker -> çıkış yarığı -> geri dönüş, yapay zekâ boyuta kaçıp rakibinin yanında belirir.
## --shots=<dir>   Deneme kayıt yuvası 95.
var main: Node
const SLOT := 95
const KS = preload("res://scripts/world/kamui_space.gd")
var fails := 0


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ok(name: String, cond: bool, extra := "") -> void:
	if not cond:
		fails += 1
	print("KAMUI %s %s %s" % ["OK  " if cond else "FAIL", name, extra])


func _enemy(at: Vector3, lv := 1) -> Enemy:
	var e := Enemy.new()
	var a = Enemy.archetype("rogue", 1)
	a["level"] = lv
	e.setup(a)
	main.actors.add_child(e)
	e.global_position = at
	return e


func _view(pl, yaw: float, pitch: float, dist := 6.0) -> void:
	pl.yaw = yaw
	pl.pitch = pitch
	pl.cam_dist = dist
	await _w(0.5)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": SLOT, "name": "Kamui Deneme", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(3.0)
	var t_load = Time.get_ticks_msec()
	while main.get("loading") != null and Time.get_ticks_msec() - t_load < 60000:
		await _w(0.5)
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	var pr = Game.profile
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != pl and Combat.hostile(pl, f):
			f.queue_free()
	Cheats.set_on("god", true)
	var obito = Cheats.ms_style_keys().find("obito")
	Cheats.give_eye(3, 2, obito)
	await _w(0.5)
	var ey = pl.combat.modes.eyes
	ey.toggle()
	await _w(0.5)
	ey.open_ms()
	await _w(0.6)
	_ok("slot_entry", Data.jutsu.has("kamui_kukan") and KS.has_access(pr), str(Eyes.ms_styles(pr)))
	var A: Vector3 = pl.global_position
	var yaw0 = float(pl.yaw)
	await main.shot("k00_before")

	# ---- 1) kendi girişi
	pl.chakra = pl.max_chakra
	var c0 = pl.chakra
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(0.2)
	await main.shot("k01_entering")
	await _w(2.5)
	var ks = KS.inst
	_ok("self_enter", KS.player_inside() and pl.global_position.y > A.y + 2500.0, "y=%.0f -> %.0f chakra %.0f -> %.0f cd=%.1f" % [A.y, pl.global_position.y, c0, pl.chakra, float(pl.combat.cooldowns.get("kamui_kukan", 0.0))])
	_ok("cost", c0 - pl.chakra >= KS.SELF_COST - 0.5 and float(pl.combat.cooldowns.get("kamui_kukan", 0.0)) > 15.0)
	_ok("quiet", Missions.quiet())
	await _view(pl, 0.0, -8.0, 6.0)
	await main.shot("k02_inside_a")
	await _view(pl, 90.0, -4.0, 7.0)
	await main.shot("k03_inside_b")
	await _view(pl, 200.0, -18.0, 8.0)
	await main.shot("k04_inside_c")
	await _view(pl, 300.0, 2.0, 5.0)
	await main.shot("k05_inside_d")
	# biraz ileride, kütlelerin arasında
	pl.global_position = ks.global_position + Vector3(0, 0.2, -24.0)
	pl.reset_physics_interpolation()
	await _view(pl, 30.0, -10.0, 7.0)
	await main.shot("k06_inside_edge")
	# FPS
	var fs = 0.0
	var fn = 0
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
		fs += Engine.get_frames_per_second()
		fn += 1
	print("KAMUI FPS inside avg=%.1f" % (fs / maxf(1, fn)))
	# yürüme / çarpışma: kütle tepesinde duruyor mu
	pl.global_position = ks.arrival() + Vector3(0, 3.0, 0)
	pl.reset_physics_interpolation()
	await _w(1.5)
	_ok("stands_on_block", pl.is_on_floor() and absf(pl.global_position.y - ks.global_position.y) < 1.0, "dy=%.2f" % (pl.global_position.y - ks.global_position.y))
	# ---- çıkış: aynı yere
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(1.6)
	_ok("self_exit_same_spot", not KS.player_inside() and Vector2(pl.global_position.x - A.x, pl.global_position.z - A.z).length() < 1.5 and absf(pl.global_position.y - A.y) < 2.0 and absf(float(pl.yaw) - yaw0) < 1.0,
		"back=%s A=%s" % [pl.global_position, A])
	await main.shot("k07_back")

	# ---- 2) NPC'yi yut (canı dolu, zayıf rakip) -> boyutta tutsak
	var e1 = _enemy(pl.global_position + pl.face_dir() * 3.0, 1)
	e1.set_physics_process(false)
	await _w(0.3)
	var n0 = KS.held().size()
	ey.cd["sag"] = 0.0
	ey._kamui_absorb(e1)
	await _w(1.6)
	_ok("absorb_full_hp", KS.held().size() == n0 + 1, "held %d -> %d" % [n0, KS.held().size()])
	# güçlü (senden güçlü) direnir
	var e2 = _enemy(pl.global_position + pl.face_dir() * 3.0, 400)
	e2.set_physics_process(false)
	await _w(0.3)
	ey._kamui_absorb(e2)
	await _w(1.6)
	_ok("strong_resists", is_instance_valid(e2) and not e2.dead and KS.held().size() == n0 + 1)
	if is_instance_valid(e2):
		e2.queue_free()
	pl.combat.cooldowns.erase("kamui_kukan")
	pl.chakra = pl.max_chakra
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(2.8)
	ks = KS.inst
	_ok("prisoner_inside", ks.live.size() >= 1 and is_instance_valid(ks.live[0]), "live=%d" % ks.live.size())
	if ks.live.size() >= 1:
		var pz = ks.live[0]
		pz.set_physics_process(false)
		var to = pz.global_position - ks.global_position
		print("KAMUI prisoner at local %s" % to)
		pl.global_position = pz.global_position + Vector3(0, 0.5, 4.5)
		pl.reset_physics_interpolation()
		await _w(0.8)
		var d2 = pz.global_position - pl.global_position
		pl.yaw = rad_to_deg(atan2(d2.x, d2.z))
		pl.pitch = -10.0
		await _w(0.6)
		await main.shot("k08_prisoner")
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(1.6)
	_ok("prisoner_stays", KS.held().size() == n0 + 1 and not KS.player_inside())

	# ---- 3) düşman Obito oyuncuyu çeker
	var A2: Vector3 = pl.global_position
	var ob = _enemy(pl.global_position + pl.face_dir() * 4.0, 300)
	Eyes.give_enemy_eyes(ob, 4, 3)
	ob.set_meta("kamui_user", true)
	ob.set_physics_process(false)
	await _w(0.3)
	EnemyArts._kamui_pull(ob, pl)
	await _w(0.6)
	await main.shot("k09_pulled_vortex")
	await _w(2.0)
	ks = KS.inst
	_ok("pulled_in", KS.player_inside() and ks.how == "pulled" and ks.rift == null, "how=%s" % ks.how)
	await main.shot("k10_pulled_inside")
	await _w(KS.RIFT_DELAY + 0.5)
	_ok("rift_opened", ks.rift != null and is_instance_valid(ks.rift) and not ks.exit_item.is_empty())
	if not ks.exit_item.is_empty():
		var rp: Vector3 = ks.exit_item["pos"]
		print("KAMUI rift dist from arrival %.1f" % (rp - ks.arrival()).length())
		var d = rp - pl.global_position
		d.y = 0
		pl.global_position = rp - d.normalized() * 7.0 + Vector3.UP * 0.5
		pl.reset_physics_interpolation()
		await _w(0.8)
		var d2 = rp - pl.global_position
		pl.yaw = rad_to_deg(atan2(-d2.x, -d2.z))
		pl.pitch = -6.0
		await _w(0.6)
		await main.shot("k11_rift")
		Progress.interact(ks.exit_item)
	await _w(1.8)
	_ok("pulled_exit_back", not KS.player_inside() and Vector2(pl.global_position.x - A2.x, pl.global_position.z - A2.z).length() < 2.0, "back=%s A2=%s" % [pl.global_position, A2])
	_ok("pull_immune", Game.now() < float(pl.get_meta("kamui_pull_immune", 0.0)))

	# ---- 4) yapay zekâ boyuta kaçar, sonra yanında belirir
	ob.set_physics_process(true)
	ob.target = pl
	ob.hp = ob.max_hp * 0.2
	ob.set_meta("ea_cd", 99.0)
	var t1 = Time.get_ticks_msec()
	while not ob.has_meta("kamui_away") and Time.get_ticks_msec() - t1 < 6000:
		await get_tree().physics_frame
	await _w(0.8)
	_ok("ai_retreat", ob.has_meta("kamui_away") and ob.global_position.y > A2.y + 2000.0, "y=%.0f" % ob.global_position.y)
	await _w(KS.RETREAT_TIME + 0.5)
	_ok("ai_returns", is_instance_valid(ob) and not ob.has_meta("kamui_away") and ob.global_position.distance_to(pl.global_position) < 12.0,
		"dist=%.1f" % (ob.global_position.distance_to(pl.global_position) if is_instance_valid(ob) else -1.0))
	await main.shot("k12_ai_back")
	print("KAMUI DONE fails=%d" % fails)
	get_tree().quit()
