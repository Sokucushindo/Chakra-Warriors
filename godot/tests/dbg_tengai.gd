extends Node
## Tengai Shinsei denetimi: oyuncu 30 m ve 40 m'deki hedefe atar (oyun kamerası + geniş yan kamera + alttan bakış),
## sonra Rinnegan'lı düşman oyuncuya atar. Kareler SHOTS klasörüne ts_<durum>_<an>_<kamera>.png.
## Çıktı: "TSG <durum> hasar", "TSG FPS min/ort", hata satırları "TSG HATA".
var main: Node
var cam: Camera3D


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12),
		"bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	pl.max_chakra = 99999.0
	pl.max_hp = 99999.0
	# açık, düz çöl (anime: savaş alanı) — yoksa düz otlak
	var at = Vector3.INF
	var o = pl.global_position
	for want in [[3], [0, 2, 4, 5, 6, 7]]:
		for r in range(1500, 14000, 500):
			for k in 24:
				var q = o + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * float(r)
				if not (Game.biome_at(q.x, q.z) in want):
					continue
				var h = Game.terrain_height(q.x, q.z)
				if Game.ground_height(q.x, q.z) > h + 0.05:
					continue
				var flat = true
				for d in [Vector3(60, 0, 0), Vector3(-60, 0, 0), Vector3(0, 0, 60), Vector3(0, 0, -60), Vector3(0, 0, -160)]:
					if absf(Game.ground_height(q.x + d.x, q.z + d.z) - h) > 7.0:
						flat = false
				if flat:
					at = q
					break
			if at != Vector3.INF:
				break
		if at != Vector3.INF:
			break
	if at == Vector3.INF:
		at = o + Vector3(0, 0, 700)
	print("TSG yer %s biyom %d" % [str(at), Game.biome_at(at.x, at.z)])
	pl.respawn(at + Vector3.UP)
	await get_tree().create_timer(5.0).timeout
	at = Missions.open_ground(at, 60.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	main.add_child(cam)
	var only = OS.get_environment("ONLY")
	for cfg in [["p30", 30.0, false], ["p40", 40.0, false], ["ai", 25.0, true]]:
		if only != "" and only != cfg[0]:
			continue
		pl.respawn(at)
		pl.hp = pl.max_hp
		pl.chakra = pl.max_chakra
		var a = WorldPeople.arch_of(cands[0])
		a["respawn"] = false
		a["jutsu"] = []
		var e = Enemy.new()
		e.setup(a)
		get_tree().current_scene.add_child(e)
		e.global_position = at + Vector3(0, 0, -float(cfg[1]))
		e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.1
		e.home = e.global_position
		await get_tree().create_timer(0.5).timeout
		e.max_hp = 999999.0
		e.hp = 999999.0
		e.skill = 0.0
		e.attack_cd = 999.0
		e.target = null
		pl.facing = 0.0
		pl.yaw = 0.0
		pl.pitch = -8.0
		pl.combat.lock_target = e
		pl.combat.cooldowns.clear()
		await get_tree().create_timer(0.6).timeout
		var victim = e
		var goal = e.global_position
		var hp0 = e.hp
		if cfg[2]:   # düşman atar, hedef oyuncu
			victim = pl
			goal = pl.global_position
			hp0 = pl.hp
			Jutsu.execute(e, "tengai_shinsei", pl)
		else:
			Jutsu.execute(pl, "tengai_shinsei", e)
		var el = 0.0
		var noshot = OS.get_environment("NOSHOT") != ""
		var fps = []
		var times = [0.9, 2.0, 3.0, 3.6, 4.4, 5.5, 6.3, 7.4, 10.5]
		var shots_at = {}
		for an in times:
			shots_at[an] = false
		while el < 11.0:
			if el > 3.2 and el < 8.0:
				fps.append(1.0 / maxf(0.001, get_process_delta_time()))
				if get_process_delta_time() > 0.05:
					print("TSG takilma %.2f sn: %.0f ms" % [el, get_process_delta_time() * 1000.0])
			for an in times:
				if not noshot and not shots_at[an] and el >= an:
					shots_at[an] = true
					await _snap(pl, goal, "%s_%04.1f" % [cfg[0], an], an)
			await get_tree().process_frame
			el += get_process_delta_time()
		var lo = 999.0
		var sm = 0.0
		for f in fps:
			lo = minf(lo, f)
			sm += f
		print("TSG %s hasar %.0f  FPS min %.0f ort %.0f" % [cfg[0], hp0 - victim.hp, lo, sm / maxf(1.0, fps.size())])
		e.queue_free()
		for n in get_tree().get_nodes_in_group("tengai_fx"):   # önceki atışın enkazı / kraterleri sonraki kareye girmesin
			n.queue_free()
		await get_tree().create_timer(1.0).timeout
	print("TSG BITTI")
	get_tree().quit()


func _snap(pl: Node3D, goal: Vector3, tag: String, an: float) -> void:
	# 1) oyun kamerası (oyuncunun gördüğü)
	await main.shot("ts_%s_oyun" % tag)
	# 2) geniş yan kamera: hedef bölgeye 120 m yandan
	var views = [["yan", goal + Vector3(330, 30, 120), goal + Vector3(0, 110, 0)]]
	var aw = goal - pl.cam.global_position
	aw.y = 0.0
	aw = aw.normalized()
	if an <= 3.0:
		views.append(["alt", goal - aw * 70.0 + Vector3(0, 2, 0), goal + aw * 140.0 + Vector3(0, 90, 0)])
	else:
		views.append(["yakin", goal + Vector3(110, 8, 150), goal + Vector3(0, 40, 0)])
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		cam.current = true
		await RenderingServer.frame_post_draw
		await main.shot("ts_%s_%s" % [tag, v[0]])
	cam.current = false
	pl.cam.current = true
