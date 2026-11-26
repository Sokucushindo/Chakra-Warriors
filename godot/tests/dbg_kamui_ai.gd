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
		for q in get_tree().get_nodes_in_group("projectiles"):
			print("KC try%d proj d=%.1f shooter=%s hostile=%s dead=%s" % [i, q.global_position.distance_to(ob.global_position + Vector3.UP), str(q.get("shooter")), str(Combat.hostile(ob, q.get("shooter"))) if q.get("shooter") else "-", str(q.get("dead"))])
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

	print("KC DONE")
	get_tree().quit()
