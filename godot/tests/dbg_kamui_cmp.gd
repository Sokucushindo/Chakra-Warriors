extends Node
## Kamui anime karşılaştırma kareleri: yakın kamera ile tepe anları (kendi giriş, dokunarak yutma, Kakashi uzak Kamui
## hem oyuncu kamerasından hem yakından, geçirgenlik, Hōshutsu dönüş mermisi + tutsak çıkışı, boyutta büyük harita).
## --shots=<dir>   Deneme kayıt yuvası 95.
var main: Node
const KS = preload("res://scripts/world/kamui_space.gd")
var cam: Camera3D


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _enemy(at: Vector3, lv := 1) -> Enemy:
	var e := Enemy.new()
	var a = Enemy.archetype("rogue", 1)
	a["level"] = lv
	e.setup(a)
	main.actors.add_child(e)
	e.global_position = at
	return e


func _look(at: Vector3, off: Vector3) -> void:
	cam.global_position = at + off
	cam.look_at(at, Vector3.UP)
	cam.current = true


func _game_cam(pl) -> void:
	cam.current = false
	pl.cam.current = true


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "Kamui Cmp", "gender": "m", "clan": "uchiha", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
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
	Hud.show_game_hud(false)
	cam = Camera3D.new()
	cam.fov = 60.0
	main.add_child(cam)
	# en açık yönü bul (uzak Kamui 14 m'de bina içine düşmesin)
	var best_a = 0.0
	var best_l = 0.0
	var sp = pl.get_world_3d().direct_space_state
	for i in 12:
		var ang = i * TAU / 12.0
		var dv = Vector3(-sin(ang), 0, -cos(ang))
		var o = pl.global_position + Vector3.UP * 1.2
		var hit = sp.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dv * 30.0, 1))
		var L = 30.0 if hit.is_empty() else o.distance_to(hit["position"])
		if L > best_l:
			best_l = L
			best_a = ang
	print("KC open dir len=%.1f" % best_l)
	pl.facing = best_a
	var A: Vector3 = pl.global_position
	var F: Vector3 = pl.face_dir()
	var R: Vector3 = F.cross(Vector3.UP).normalized()

	# a) kendi girişi / çıkışı (yan + ön, ~3 m)
	for v in [["yan", R * 3.0], ["on", F * 3.0 + R * 0.6]]:
		pl.global_position = A
		pl.reset_physics_interpolation()
		_look(A + Vector3.UP * 1.1, v[1] + Vector3.UP * 0.4)
		await _w(0.4)
		MsArts.kamui_vortex(KS.eye_point(pl), 1.9, 1.0, {"pull": 0.55})
		KS._shrink(pl, 0.55)
		for k in 3:
			await _w(0.17)
			await main.shot("a_%s_%d" % [v[0], k])
		await _w(0.5)
		MsArts.kamui_vortex(KS.eye_point(pl), 1.9, 0.9, {"pull": -0.5})
		KS._shrink(pl, 0.5, true)
		await _w(0.2)
		await main.shot("a_%s_out" % v[0])
		await _w(0.6)

	# b) dokunarak yutma: hedef karenin üçte biri
	for v in [["yan", 1.0], ["on", -1.0]]:
		pl.global_position = A
		pl.reset_physics_interpolation()
		var e1 = _enemy(A + F * 2.4, 1)
		e1.apply_status("bind", 6.0)
		e1.facing = PI
		var tp = e1.global_position + Vector3.UP * 1.1
		_look(tp, (R * v[1] * 4.2 if v[0] == "yan" else F * 3.8 + R * 1.2) + Vector3.UP * 0.3)
		await _w(0.6)
		ey.cd["sag"] = 0.0
		ey._kamui_absorb(e1)
		for k in 4:
			await _w(0.26)
			await main.shot("b_%s_%d" % [v[0], k])
		await _w(0.8)

	# c) Kakashi uzak Kamui: oyuncu kamerasından (14 m) ve hedefe yakından
	pl.global_position = A
	pl.reset_physics_interpolation()
	var e3 = _enemy(A + F * minf(14.0, best_l - 3.0), 1)
	e3.apply_status("stun", 8.0)   # fizik açık kalsın (uzakta fiziği kapalı model görünmüyor)
	e3.hp = e3.max_hp * 0.2
	_game_cam(pl)
	pl.yaw = rad_to_deg(best_a) + 8.0
	pl.pitch = -4.0
	pl.cam_dist = 4.0
	await _w(0.7)
	Jutsu.j_kamui(pl, e3)
	for k in 5:
		await _w(0.4)
		await main.shot("c_player_%d" % k)
	await _w(0.8)
	var e4 = _enemy(A + F * minf(14.0, best_l - 3.0), 1)
	e4.apply_status("stun", 8.0)
	e4.hp = e4.max_hp * 0.2
	_look(e4.global_position + Vector3.UP * 1.0, -F * 5.0 + R * 2.0 + Vector3.UP * 0.6)
	await _w(0.6)
	Jutsu.j_kamui(pl, e4)
	for k in 6:
		await _w(0.33)
		await main.shot("c_close_%d" % k)
	await _w(0.6)

	# d) geçirgenlik
	pl.global_position = A
	pl.reset_physics_interpolation()
	_look(A + Vector3.UP * 1.1, F * 3.0 + R * 0.8 + Vector3.UP * 0.2)
	await _w(0.4)
	ey._phase_start()
	for k in 3:
		pl.combat.take_hit({"dmg": 10.0, "kind": "light", "attacker": null, "dir": Vector3.FORWARD})
		await _w(0.12)
		await main.shot("d_%d" % k)
	ey._phase_end()
	await _w(0.6)

	# e) Hōshutsu: yutulan kunai geri, sonra tutsak
	var e5 = _enemy(A + F * 7.0, 30)
	e5.apply_status("bind", 10.0)
	var kd = e5.global_position + Vector3.UP * 1.3
	Projectile.tool(e5, kd, (pl.global_position + Vector3.UP * 1.2 - kd).normalized(), "kunai", pl)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ey.cd["sag"] = 0.0
	ey._kamui_absorb(null)
	_look(A + F * 2.0 + Vector3.UP * 1.3, R * 3.0 + Vector3.UP * 0.3)
	await _w(0.12)
	await main.shot("e_swallow")
	await _w(0.5)
	pl.combat.lock_target = e5
	pl.chakra = pl.max_chakra
	pl.combat.cooldowns.erase("kamui_hoshutsu")
	_look(A + F * 3.5 + Vector3.UP * 1.3, R * 4.0 + Vector3.UP * 0.4)
	SpecialSlots.cast(pl, "kamui_hoshutsu")
	for k in 3:
		await _w(0.07)
		await main.shot("e_shot_%d" % k)
	await _w(0.6)
	pl.combat.cooldowns.erase("kamui_hoshutsu")
	_look(e5.global_position + Vector3.UP * 1.0, -F * 5.0 + R * 3.0 + Vector3.UP * 0.5)
	SpecialSlots.cast(pl, "kamui_hoshutsu")
	for k in 3:
		await _w(0.2)
		await main.shot("e_out_%d" % k)

	if is_instance_valid(e5):
		e5.queue_free()   # yoldan çekil (kunai ona çarpıyordu)
	# g) yapay zekâ Obito: gelen kunaiyi yutar, Hōshutsu ile geri atar; kendi tutsağını hedefin yanına çıkarır
	pl.global_position = A
	pl.reset_physics_interpolation()
	var ob = _enemy(A + F * 8.0, 300)
	Eyes.give_enemy_eyes(ob, 4, 3)
	ob.set_meta("kamui_user", true)
	ob.apply_status("bind", 20.0)
	ob.chakra = 500.0
	await _w(0.5)
	var swallowed = false
	for i in 6:
		var kp = pl.global_position + Vector3.UP * 1.3 + F * 0.5
		Projectile.tool(pl, kp, (ob.global_position + Vector3.UP * 1.2 - kp).normalized(), "kunai", ob)
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		if EnemyArts._kamui_react(ob, pl, ob.global_position.distance_to(pl.global_position)):
			swallowed = true
			break
		await _w(0.6)
	_look(ob.global_position + Vector3.UP * 1.2, -F * 3.5 + R * 2.5 + Vector3.UP * 0.3)
	await _w(0.15)
	await main.shot("g_ai_swallow")
	await _w(0.5)
	var nst = (ob.get_meta("kamui_shots", []) as Array).size()
	print("KC ai_swallow=%s stored=%d" % [str(swallowed), nst])
	var hp0 = pl.hp
	Cheats.set_on("god", false)
	pl.hp = pl.max_hp
	hp0 = pl.hp
	var fired = false
	_look(A + F * 4.0 + Vector3.UP * 1.3, R * 4.5 + Vector3.UP * 0.4)
	for i in 30:
		ob.set_meta("kamui_out_next", 0.0)
		if EnemyArts._kamui_react(ob, pl, ob.global_position.distance_to(pl.global_position)):
			fired = true
			break
	for k in 2:
		await _w(0.08)
		await main.shot("g_ai_shot_%d" % k)
	await _w(0.6)
	print("KC ai_fire_back=%s player_hp %.0f -> %.0f" % [str(fired), hp0, pl.hp])
	Cheats.set_on("god", true)
	# yapay zekânın kendi tutsağı
	var vic = _enemy(ob.global_position + R * 2.0, 1)
	vic.apply_status("bind", 5.0)
	var nh = KS.held().size()
	EnemyArts._kamui_pull(ob, vic)
	await _w(1.6)
	var mine = KS.held().filter(func(r): return String(r.get("by_id", "")) == str(ob.get_instance_id())).size()
	print("KC ai_capture held %d -> %d own=%d" % [nh, KS.held().size(), mine])
	var outd = false
	for i in 30:
		ob.set_meta("kamui_out_next", 0.0)
		if EnemyArts._kamui_react(ob, pl, ob.global_position.distance_to(pl.global_position)):
			outd = true
			break
	_look(pl.global_position + Vector3.UP * 1.0, -F * 3.0 + R * 4.0 + Vector3.UP * 0.6)
	for k in 2:
		await _w(0.25)
		await main.shot("g_ai_out_%d" % k)
	print("KC ai_release=%s held now %d own=%d" % [str(outd), KS.held().size(), KS.held().filter(func(r): return String(r.get("by_id", "")) == str(ob.get_instance_id())).size()])
	ob.queue_free()

	# f) boyutta büyük harita (M)
	_game_cam(pl)
	Hud.show_game_hud(true)
	pl.combat.cooldowns.erase("kamui_kukan")
	pl.chakra = pl.max_chakra
	SpecialSlots.cast(pl, "kamui_kukan")
	await _w(3.0)
	Menus.kamui_map(main)
	await _w(0.6)
	await main.shot("f_bigmap")
	Hud.close_dialog()
	print("KC DONE inside=%s" % str(KS.player_inside()))
	get_tree().quit()
