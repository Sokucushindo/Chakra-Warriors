extends Node
## Su dalgaları: denizde ve Konoha kanalında küçük (yumruk), orta (Katon Gōkakyū), dev (bijū-dama) çarpma + Doton suda (yer izi yok)
## + su üstünde koşu. Her vaka için 2 açıdan 4 anda kare: ww_<yer>_<vaka>_<an>_<kamera>.png. FPS: dev vakadan önce / sırasında.
## Satırlar "WW ..." ile başlar.
var main: Node
var cam: Camera3D


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _fps(sec: float) -> float:
	var n := 0
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
		n += 1
	return n / ((Time.get_ticks_msec() - t0) / 1000.0)


func _shots(tag: String, at: Vector3, times: Array, far: float, t0: int) -> void:
	for an in times:
		while (Time.get_ticks_msec() - t0) / 1000.0 < an:
			await get_tree().process_frame
		for cv in [["yan", at + Vector3(far * 0.9, far * 0.38, far * 0.35)], ["ust", at + Vector3(-far * 0.25, far * 0.95, far * 0.55)]]:
			cam.global_position = cv[1]
			cam.look_at(at, Vector3.UP)
			cam.current = true
			await RenderingServer.frame_post_draw
			await main.shot("ww_%s_%02d_%s" % [tag, int(an * 10.0), cv[0]])
	main.player.cam.current = true


func _enemy(at: Vector3) -> Enemy:
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	var a = WorldPeople.arch_of(cands[0])
	a["respawn"] = false
	a["jutsu"] = []
	var e = Enemy.new()
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = at
	e.home = at
	await _wait(0.4)
	e.max_hp = 999999.0; e.hp = 999999.0
	e.skill = 0.0
	e.attack_cd = 999.0
	e.target = null
	e.set_physics_process(false)
	return e


func _case(where: String, at: Vector3, far_k: float, fwd := Vector3.FORWARD) -> void:
	var pl = main.player
	var wl = WaterWaves.surface_at(at + Vector3.UP * 0.2)
	print("WW %s su=%.2f arazi=%.2f" % [where, wl, Game.terrain_height(at.x, at.z)])
	pl.respawn(at - fwd * 4.0 + Vector3(0, 0.3, 0))
	pl.facing = atan2(-fwd.x, -fwd.z)
	pl.yaw = 0.0
	await _wait(1.5)
	var e = await _enemy(at + fwd * 5.0 + Vector3(0, 0.1, 0))
	pl.combat.lock_target = e
	var mid = at + fwd * 0.5
	# küçük: yumruk (gerçek vuruş alanı Combat.hit_sphere → WorldDamage.impact)
	WaterWaves.ripples.clear()
	var t0 = Time.get_ticks_msec()
	Combat.hit_sphere(pl, e.global_position + Vector3.UP * 0.9, 1.0, {"dmg": 12.0, "kind": "light", "melee": true, "knock": 1.0})
	print("WW %s kucuk halka=%d" % [where, WaterWaves.ripples.size()])
	await _shots(where + "_kucuk", e.global_position, [0.15, 0.6, 1.4], 7.0 * far_k, t0)
	await _wait(1.5)
	# orta: Katon Gōkakyū (suya / hedefe çarpar: buhar + halka)
	WaterWaves.ripples.clear()
	pl.combat.cooldowns.clear()
	pl.chakra = pl.max_chakra
	t0 = Time.get_ticks_msec()
	Jutsu.execute(pl, "katon_goukakyuu", e)
	var times = [0.8, 1.4, 2.2, 3.4]
	await _shots(where + "_orta", mid, times, 16.0 * far_k, t0)
	print("WW %s orta halka=%d maxR=%.1f" % [where, WaterWaves.ripples.size(), _maxr()])
	await _wait(2.0)
	# Doton suda: Doryūsō (yer çatlağı / toz yerine sıçrama)
	WaterWaves.ripples.clear()
	t0 = Time.get_ticks_msec()
	Jutsu.execute(pl, "doton_doryuusou", e)
	await _shots(where + "_doton", mid, [0.6, 1.3], 14.0 * far_k, t0)
	print("WW %s doton halka=%d" % [where, WaterWaves.ripples.size()])
	await _wait(2.5)
	# dev: bijū-dama (kanon şartı atlanır: yalnız görsel / dalga denetimi)
	WaterWaves.ripples.clear()
	await _wait(1.0)
	cam.global_position = mid + Vector3(40, 18, 20)
	cam.look_at(mid, Vector3.UP)
	cam.current = true
	var f0 = await _fps(2.0)
	pl.combat.cooldowns.clear()
	t0 = Time.get_ticks_msec()
	Jutsu.execute(pl, "bijudama", e)
	if OS.get_environment("HUGE_SIM") != "":
		WorldDamage.impact(e.global_position, 18.0, {"dmg": 600.0, "kind": "heavy"})
	await _shots(where + "_dev", mid, [1.0, 2.0, 3.2, 5.0], 45.0 * far_k, t0)
	print("WW %s dev halka=%d maxR=%.1f yamalar=%d damla=%d" % [where, WaterWaves.ripples.size(), _maxr(), WaterWaves.inst._patches.size() if WaterWaves.inst else -1, WaterWaves.inst._dp.size() if WaterWaves.inst else -1])
	cam.global_position = mid + Vector3(40, 18, 20)
	cam.look_at(mid, Vector3.UP)
	cam.current = true
	await _wait(4.0)
	# A/B: aynı kamera, aynı dev çarpma (yalnız dünya hasarı yolu) — su sistemi kapalı / açık
	WaterWaves.enabled = false
	WorldDamage.impact(e.global_position + Vector3(6, 0, 0), 16.0, {"dmg": 500.0, "kind": "heavy"})
	var fa = await _fps(2.5)
	WaterWaves.enabled = true
	await _wait(1.0)
	WorldDamage.impact(e.global_position + Vector3(-6, 0, 0), 16.0, {"dmg": 500.0, "kind": "heavy"})
	var fb = await _fps(2.5)
	print("WW %s FPS bos=%.1f dev_su_kapali=%.1f dev_su_acik=%.1f halka=%d damla=%d" % [where, f0, fa, fb, WaterWaves.ripples.size(), WaterWaves.inst._dp.size() if WaterWaves.inst else -1])
	pl.cam.current = true
	e.queue_free()
	await _wait(3.0)
	# su üstünde koşu
	WaterWaves.ripples.clear()
	pl.respawn(at - fwd * 4.0 + Vector3(0, 0.3, 0))
	await _wait(1.0)
	Input.action_press("forward")
	t0 = Time.get_ticks_msec()
	await _wait(1.8)
	print("WW %s kosu on_water=%s halka=%d" % [where, pl.on_water, WaterWaves.ripples.size()])
	var pp = pl.global_position
	Input.action_release("forward")
	await _shots(where + "_kosu", pp, [2.0], 6.0, t0)


func _maxr() -> float:
	var m = 0.0
	for r in WaterWaves.ripples:
		m = maxf(m, float(r[4]))
	return m


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.2, 0.2, 0.2), "top": Color(0.15, 0.2, 0.33),
		"bottom": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await _wait(3.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	var pl = main.player
	pl.max_chakra = 99999.0
	pl.max_hp = 99999.0
	pl.chakra = 99999.0
	pl.hp = 99999.0
	cam = Camera3D.new()
	cam.fov = 55.0
	main.add_child(cam)
	var only = OS.get_environment("WW_ONLY")
	# Konoha kanalı: kanal malzemeli kayıtlı su, arazi altında
	var canal_at = null
	var canal_fwd = Vector3.FORWARD
	# Konoha kanalı: arazi altında, köy yüksekliğinde art arda dizili kayıtlı su dilimleri; akış yönü = komşu dilime doğru
	var segs = []
	for k in Game._water_grid:
		for e in Game._water_grid[k]:
			if is_instance_valid(e[0]) and float(e[4]) > 0.5 and not segs.has(e) and Game.terrain_height(e[1].x, e[1].y) < e[4] - 0.25 					and Vector2(e[1]).distance_to(Vector2(pl.global_position.x, pl.global_position.z)) < 900.0:
				segs.append(e)
	for e in segs:
		var nb = []
		for o in segs:
			if o != e and absf(float(o[4]) - float(e[4])) < 0.05 and Vector2(o[1]).distance_to(Vector2(e[1])) < 12.0:
				nb.append(o)
		if nb.size() >= 4:   # kanalın ortası (iki yanında da dilim var)
			canal_at = Vector3(e[1].x, e[4], e[1].y)
			nb.sort_custom(func(a, b): return Vector2(a[1]).distance_to(Vector2(e[1])) > Vector2(b[1]).distance_to(Vector2(e[1])))
			var dv = Vector2(nb[0][1]) - Vector2(e[1])
			canal_fwd = Vector3(dv.x, 0, dv.y).normalized()
			break
	var near = []
	for k in Game._water_grid:
		for e in Game._water_grid[k]:
			if is_instance_valid(e[0]) and not near.has(e):
				near.append(e)
	near.sort_custom(func(a, b): return Vector2(a[1]).distance_to(Vector2(pl.global_position.x, pl.global_position.z)) < Vector2(b[1]).distance_to(Vector2(pl.global_position.x, pl.global_position.z)))
	for e in near.slice(0, 8):
		print("WW su kaydi c=%s y=%.2f hs=%s terr=%.2f sahip=%s" % [e[1], e[4], e[2], Game.terrain_height(e[1].x, e[1].y), e[0].name])
	print("WW oyuncu=", pl.global_position, " kanal=", canal_at)
	if only in ["", "kanal"] and canal_at != null:
		await _case("kanal", canal_at, 0.7, canal_fwd)
	if only in ["", "deniz"]:
		await _case("deniz", Vector3(-2720, 0, 630), 1.0)
	print("WW BITTI")
	get_tree().quit()
