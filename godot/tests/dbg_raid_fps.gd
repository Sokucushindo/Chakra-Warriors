extends Node
## Baskın FPS: köy kapısında RF_N kişi (yarısı akıncı, yarısı muhafız; Kage baskınının kendi kurucusu _ninja_of) birbirine girer,
## oyuncu da 3 sn'de bir teknik atar. Her 2 sn: ort FPS, en kötü kare FPS, betik / fizik / çizim işlemci ms, düğüm, efekt.
## Sonda "RF OZET": tüm sürenin ort FPS + en kötü %1 kare FPS. RF_N=20, RF_SEC=60, RF_SEED=7, RF_PL=0 (oyuncu atmasın)
var main: Node
var casts := 0


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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if OS.get_environment("RF_STEPS") != "":
		Engine.max_physics_steps_per_frame = int(OS.get_environment("RF_STEPS"))
	if OS.get_environment("RF_TICKS") != "":
		Engine.physics_ticks_per_second = int(OS.get_environment("RF_TICKS"))
	var vrid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var N := int(OS.get_environment("RF_N")) if OS.get_environment("RF_N") != "" else 20
	var dur := float(OS.get_environment("RF_SEC")) if OS.get_environment("RF_SEC") != "" else 60.0
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var at: Vector3 = Missions.open_ground(c + Vector3(120, 0, -160), 25.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	pl.respawn(at)
	pl.max_hp = 9999999.0
	pl.max_chakra = 9999999.0
	var my = ["katon_goukakyuu", "katon_karyuu", "fuuton_daitoppa", "fuuton_rasenshuriken", "raiton_chidori", "suiton_suiryuudan", "doton_doryuheki", "kage_bunshin"]
	my = my.filter(func(j): return Data.jutsu.has(j))
	for j in my:
		if not (j in Game.profile["learned"]):
			Game.profile["learned"].append(j)
	await get_tree().create_timer(10.0).timeout
	var t0 = Time.get_ticks_usec()
	var nb = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		nb += 1
	print("RF taban FPS %.0f" % (nb / 3.0))
	Jutsu.jutsu_cast.connect(func(_c, _id): casts += 1)
	seed(int(OS.get_environment("RF_SEED")) if OS.get_environment("RF_SEED") != "" else 7)
	var fighters: Array = []
	var nr := N / 2
	for i in N:
		var raider := i < nr
		var e: Enemy = Kage._ninja_of("kumo" if raider else "konoha", i, 25, "enemy" if raider else "player")
		get_tree().current_scene.add_child(e)
		var off := Vector3(randf_range(-14, 14), 0, randf_range(-22, -12) if raider else randf_range(-6, 4))
		var q: Vector3 = at + off
		q.y = Game.ground_height(q.x, q.z) + 0.3
		e.global_position = q
		e.home = q
		e.wander_to = at
		e.max_hp = 9999999.0
		e.hp = e.max_hp
		fighters.append(e)
		await get_tree().process_frame
	print("RF %d kişi kuruldu (%d akıncı)" % [fighters.size(), nr])
	if OS.get_environment("RF_PF") != "":
		Engine.set_meta("pf", {})
	if OS.get_environment("RF_FX") != "":
		Engine.set_meta("fx_pf", {})
	var vt0 = Time.get_ticks_usec()
	var win0 = vt0
	var last = vt0
	var wn = 0
	var wworst = 0
	var wscr = 0.0
	var wphy = 0.0
	var wrc = 0.0
	var wgpu = 0.0
	var fts: Array = []
	var next_cast = 2.0
	var mi = 0
	var exp_on := false
	var h1: Array = []
	var h2: Array = []
	var EXP := OS.get_environment("RF_EXP")
	var kids := {}
	var EXP0 := OS.get_environment("RF_EXP0")
	while Time.get_ticks_usec() - vt0 < int(dur * 1e6):
		if EXP != "" and not exp_on and (Time.get_ticks_usec() - vt0) / 1e6 > dur * 0.5:
			exp_on = true
			_exp(EXP, true)
			print("RF DENEY %s açıldı" % EXP)
		await get_tree().process_frame
		var now = Time.get_ticks_usec()
		var ft = now - last
		last = now
		fts.append(ft)
		if (now - vt0) / 1e6 > 4.0:
			(h2 if (now - vt0) / 1e6 > dur * 0.5 + 2.0 else (h1 if (now - vt0) / 1e6 < dur * 0.5 else [])).append(ft)
		if exp_on:
			_exp(EXP, false)
		if EXP0 != "":   # koşunun başından beri açık deney (yarı karşılaştırması yanıltıyor)
			for k0 in EXP0.split(","):
				_exp(k0, fts.size() == 1)
		wn += 1
		wworst = maxi(wworst, ft)
		wscr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		wphy += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		wrc += RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
		wgpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		pl.hp = pl.max_hp
		pl.chakra = pl.max_chakra
		for e in fighters:
			if is_instance_valid(e):
				e.hp = e.max_hp
				e.dead = false
		if OS.get_environment("RF_PL") != "0" and (now - vt0) / 1e6 > next_cast and not my.is_empty():
			next_cast += 3.0
			var tgt = fighters[mi % nr]
			if is_instance_valid(tgt):
				pl.combat.lock_target = tgt
				pl.combat.cooldowns.clear()
				Jutsu.execute(pl, my[mi % my.size()], tgt)
			mi += 1
		if now - win0 > 2000000:
			print("RF t=%4.0f | ort %3.0f | kotu %3.0f | betik %.1f fizik %.1f cizim-cpu %.1f gpu %.1f | dugum %d | tween %d | teknik %d" % [(now - vt0) / 1e6, wn / ((now - win0) / 1e6), 1e6 / maxf(1.0, wworst),
				wscr / wn, wphy / wn, wrc / wn, wgpu / wn, get_tree().get_node_count(), get_tree().get_processed_tweens().size(), casts])
			# iç içe geçme denetimi: 0,45 m'den yakın dövüşçü çifti sayısı ve en yakın çift
			var close_n := 0
			var close_min := 99.0
			for ia in fighters.size():
				for ib in range(ia + 1, fighters.size()):
					if is_instance_valid(fighters[ia]) and is_instance_valid(fighters[ib]):
						var dd: float = fighters[ia].global_position.distance_to(fighters[ib].global_position)
						close_min = minf(close_min, dd)
						if dd < 0.45:
							close_n += 1
			print("RF YAKIN cift<0.45m %d | en yakin %.2f m" % [close_n, close_min])
			if OS.get_environment("RF_KIDS") != "":   # model altında kendi betiğiyle işleyen düğümler (iş parçacığı denetimi)
				for n in get_tree().get_nodes_in_group("fighters"):
					var mdl = n.get("model")
					if mdl == null or not is_instance_valid(mdl):
						continue
					for ch in mdl.find_children("*", "", true, false):
						var sc = ch.get_script()
						if sc != null and (ch.is_processing() or ch.is_physics_processing()):
							kids[String(sc.resource_path) + " | " + ch.get_class()] = int(kids.get(String(sc.resource_path) + " | " + ch.get_class(), 0)) + 1
				print("RF KIDS ", kids)
			if OS.get_environment("RF_SHOT") != "":
				get_viewport().get_texture().get_image().save_png("res://../_tmp/rf_shot_%02d.png" % int((now - vt0) / 1e6))
			win0 = now
			wn = 0
			wworst = 0
			wscr = 0.0
			wphy = 0.0
			wrc = 0.0
			wgpu = 0.0
	if Engine.has_meta("pf"):
		var pf: Dictionary = Engine.get_meta("pf")
		var ks = pf.keys()
		ks.sort_custom(func(a, b): return int(pf[a]) > int(pf[b]))
		for k in ks.slice(0, 30):
			print("RF PF %-34s %7.1f ms/sn" % [k, int(pf[k]) / 1000.0 / dur])
	if Engine.has_meta("fx_pf"):
		var fx: Dictionary = Engine.get_meta("fx_pf")
		var ks2 = fx.keys()
		ks2.sort_custom(func(a, b): return int(fx[a][1]) > int(fx[b][1]))
		for k in ks2.slice(0, 45):
			print("RF FX %-44s %8d kez %7.1f ms/sn" % [k, int(fx[k][0]), int(fx[k][1]) / 1000.0 / dur])
	var sm := func(a: Array) -> float:
		var t := 0
		for f in a:
			t += f
		return a.size() / maxf(t / 1e6, 0.001)
	print("RF YARI deney=%s | ilk yarı %.1f FPS | ikinci yarı %.1f FPS" % [EXP, sm.call(h1), sm.call(h2)])
	fts.sort()
	var tot := 0
	for f in fts:
		tot += f
	var p99 = fts[int(fts.size() * 0.99)] if fts.size() > 0 else 1
	print("RF OZET N=%d | ort FPS %.1f | en kotu %%1 FPS %.1f | kare %d | teknik %d" % [N, fts.size() / (tot / 1e6), 1e6 / float(p99), fts.size(), casts])
	get_tree().quit()


## özellik kapatma deneyi (yalnız ölçüm): first=true ilk açılış, sonra her kare (yeni doğan düğümler de)
func _exp(k: String, first: bool) -> void:
	match k:
		"anim":
			for n in get_tree().get_nodes_in_group("fighters"):
				for ap in n.find_children("*", "AnimationMixer", true, false):
					ap.active = false
		"tween":
			for tw in get_tree().get_processed_tweens():
				tw.kill()
		"dangle":
			for n in get_tree().get_nodes_in_group("fighters"):
				var m = n.get("model")
				if m and m.get("_dangles") != null:
					m._dangles = []
		"rig":
			for n in get_tree().get_nodes_in_group("fighters"):
				for sm in n.find_children("*", "SkeletonModifier3D", true, false):
					sm.active = false
		"wrig", "pose":
			for n in get_tree().get_nodes_in_group("fighters"):
				for sm in n.find_children("*", "SkeletonModifier3D", true, false):
					if (k == "wrig" and sm is WeaponRig) or (k == "pose" and sm is PoseOverlay):
						sm.active = false
		"noai":   # dövüşçü yapay zekâsı kapalı (model + iskelet + çizim yükü kalır)
			for n in get_tree().get_nodes_in_group("fighters"):
				if n is Enemy:
					n.set_physics_process(false)
		"nomodel":   # dövüşçü modelleri görünmez (çizim + iskelet yükü kalkar)
			for n in get_tree().get_nodes_in_group("fighters"):
				if n is Enemy and n.get("model") != null and n.model.visible:
					n.model.visible = false
		"thr":   # model + iskelet ayrı iş parçacığı grubunda
			for n in get_tree().get_nodes_in_group("fighters"):
				if n is Enemy and n.get("model") != null and n.model.process_thread_group != Node.PROCESS_THREAD_GROUP_SUB_THREAD:
					n.model.process_thread_group = Node.PROCESS_THREAD_GROUP_SUB_THREAD
					n.model.process_thread_messages = Node.FLAG_PROCESS_THREAD_MESSAGES
		"nojutsu":
			for n in get_tree().get_nodes_in_group("fighters"):
				if n is Enemy and n.arch.has("jutsu") and not (n.arch["jutsu"] as Array).is_empty():
					n.arch["jutsu"] = []
					n.arch["tools"] = false
		"col":   # dövüşçüler birbirine fizik çarpışması yapmaz (yalnız dünya + oyuncu)
			for n in get_tree().get_nodes_in_group("fighters"):
				if n is CharacterBody3D and n != Game.player:
					n.collision_mask = 1 | 2
		"shadow":   # dövüşçü modelleri gölge atmaz
			if first:
				for n in get_tree().get_nodes_in_group("fighters"):
					for mi in n.find_children("*", "GeometryInstance3D", true, false):
						mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"vill":
			if first:
				for n in get_tree().get_nodes_in_group("talkers").filter(func(x): return x is Villager):
					n.process_mode = Node.PROCESS_MODE_DISABLED
					n.visible = false
		"hud":
			if first:
				Hud.visible = false
				Hud.process_mode = Node.PROCESS_MODE_DISABLED
