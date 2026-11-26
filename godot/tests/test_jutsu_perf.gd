extends Node
## Tüm teknikler performans taraması: her tekniği kuklaya atar, efekt süresince FPS ölçer.
## JP_FROM / JP_N: sıralı teknik listesinde aralık. JP_IDS="a,b": yalnız bunlar.
## Çıktı satırı: JP <id> | ort FPS | en kötü kare FPS | ekran kartı ms | eklenen düğüm tepe | ışık | parçacık | mesh | 4 sn sonra kalan
var main: Node
var added: Array = []


func _on_added(n: Node) -> void:
	added.append(weakref(n))


func _count_alive() -> Dictionary:
	var r = {"nodes": 0, "light": 0, "part": 0, "mesh": 0, "mm": 0}
	for w in added:
		var n = w.get_ref()
		if n == null or not n.is_inside_tree():
			continue
		r["nodes"] += 1
		if n is Light3D and n.visible:
			r["light"] += 1
		elif n is GPUParticles3D or n is CPUParticles3D:
			r["part"] += 1
		elif n is MultiMeshInstance3D:
			r["mm"] += 1
		elif n is MeshInstance3D:
			r["mesh"] += 1
	return r


func _idle_fps(sec: float) -> float:
	var t0 = Time.get_ticks_usec()
	var n = 0
	while Time.get_ticks_usec() - t0 < int(sec * 1e6):
		await get_tree().process_frame
		n += 1
	return n / ((Time.get_ticks_usec() - t0) / 1e6)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12),
		"bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	Game.profile["kd_wait"] = 99999.0
	Game.set_meta("arena", true)   # dünyada olay / doğuş yok: ölçüm gürültüsü
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vrid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	pl.max_chakra = 9999999.0
	pl.max_hp = 9999999.0
	var at = Missions.open_ground(pl.global_position + Vector3(900.0, 0, 1400.0), 80.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	var ids: Array = []
	if OS.get_environment("JP_IDS") != "":
		ids = Array(OS.get_environment("JP_IDS").split(",", false))
	else:
		ids = Data.jutsu.keys().filter(func(k): return not String(k).begins_with("_"))
		ids.sort()
		var f = int(OS.get_environment("JP_FROM")) if OS.get_environment("JP_FROM") != "" else 0
		var nn = int(OS.get_environment("JP_N")) if OS.get_environment("JP_N") != "" else ids.size()
		print("JP toplam %d teknik" % ids.size())
		ids = ids.slice(f, f + nn)
	var meas = float(OS.get_environment("JP_SEC")) if OS.get_environment("JP_SEC") != "" else 1.5
	get_tree().node_added.connect(_on_added)
	Engine.set_meta("jx", {})
	if OS.get_environment("JP_FX") != "":
		Engine.set_meta("fx_pf", {})
	pl.respawn(at)
	await get_tree().create_timer(15.0).timeout
	print("JP taban FPS %.0f" % await _idle_fps(2.0))
	var e: Node3D = null
	for jid in ids:
		if not Data.jutsu.has(jid):
			continue
		if not ("learned" in Game.profile):
			Game.profile["learned"] = []
		if not (jid in Game.profile["learned"]):
			Game.profile["learned"].append(jid)
		if pl.global_position.distance_to(at) > 3.0:
			pl.respawn(at)
		pl.hp = pl.max_hp
		pl.chakra = pl.max_chakra
		pl.facing = 0.0
		pl.yaw = 0.0
		if e == null or not is_instance_valid(e) or e.get("hp") == null or float(e.hp) <= 0.0:
			if e != null and is_instance_valid(e):
				e.queue_free()
			var a = WorldPeople.arch_of(cands[0])
			a["respawn"] = false
			a["jutsu"] = []
			e = Enemy.new()
			e.setup(a)
			get_tree().current_scene.add_child(e)
			await get_tree().create_timer(0.4).timeout
		e.global_position = at + Vector3(0, 0, -9.0)
		e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.1
		e.home = e.global_position
		e.max_hp = 9999999.0; e.hp = 9999999.0
		e.skill = 0.0
		e.attack_cd = 999.0
		e.target = null
		pl.combat.lock_target = e
		pl.combat.cooldowns.clear()
		var idle = await _idle_fps(0.4)
		added.clear()
		var t0 = Time.get_ticks_usec()
		Jutsu.execute(pl, jid, e)
		var n = 0
		var worst = 0
		var gpu = 0.0
		var peak = {"nodes": 0, "light": 0, "part": 0, "mesh": 0, "mm": 0}
		var last = Time.get_ticks_usec()
		var samples = [0.15, 0.5, 0.9, 1.4]
		while Time.get_ticks_usec() - t0 < int(meas * 1e6):
			await get_tree().process_frame
			var now = Time.get_ticks_usec()
			worst = maxi(worst, now - last)
			last = now
			n += 1
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			if not samples.is_empty() and (now - t0) / 1e6 >= samples[0]:
				samples.pop_front()
				var c = _count_alive()
				for k in peak:
					peak[k] = maxi(peak[k], c[k])
		var avg = n / ((Time.get_ticks_usec() - t0) / 1e6)
		await get_tree().create_timer(0.5).timeout
		var left = _count_alive()
		var jxr = Engine.get_meta("jx").get(jid, [0, 0, 0])
		Engine.get_meta("jx").erase(jid)
		print("JP %s | kur %.1f | idle %.0f | ort %.0f | kotu %.0f | gpu %.1f | dugum %d | isik %d | parca %d | mesh %d | mm %d | kalan %d" % [jid, jxr[1] / 1000.0, idle, avg, 1e6 / maxf(1.0, worst), gpu / maxi(1, n), peak["nodes"], peak["light"], peak["part"], peak["mesh"], peak["mm"], left["nodes"]])
	if Engine.has_meta("fx_pf"):
		var fd: Dictionary = Engine.get_meta("fx_pf")
		var fk = fd.keys()
		fk.sort_custom(func(a, b): return fd[a][1] > fd[b][1])
		for k in fk.slice(0, 150):
			print("JPX %s %d %.1f" % [k, fd[k][0], fd[k][1] / 1000.0])
	print("JP BITTI")
	get_tree().quit()
