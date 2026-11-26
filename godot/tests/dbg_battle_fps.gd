extends Node
## Kalabalık savaş FPS: köy kenarında N gerçek dünya ninjası (kendi teknikleriyle) oyuncuya saldırır, oyuncu da teknik atar.
## Her 2 sn: ort FPS, en kötü kare, savaş efekti düğümleri (ışık/parçacık/mesh). 40 ms üstü karede son 0.4 sn içinde atılan teknikler.
## BF_N=4 (düşman sayısı), BF_SEC=40, BF_AT=koy|kir (köy kenarı ya da açık arazi), BF_PL=0 (oyuncu teknik atmasın)
var main: Node
var added: Array = []
var casts: Array = []   # [ms, kim, id]


var models := {}
var exits := {}


func _on_added(n: Node) -> void:
	added.append(weakref(n))
	if n is CharacterModel:
		var par = n.get_parent()
		var k = (par.get_script().resource_path.get_file() if par and par.get_script() else (par.get_class() if par else "?"))
		models[k] = int(models.get(k, 0)) + 1
	if n is Villager:
		n.tree_exiting.connect(func():
			var why = "fading" if n.fading else "silindi"
			var dpl = n.global_position.distance_to(main.player.global_position) if is_instance_valid(main.player) else -1.0
			var kk = "%s %s %s" % [why, n.role, "yakın" if dpl < 60 else ("orta" if dpl < 150 else "uzak")]
			exits[kk] = int(exits.get(kk, 0)) + 1)


func _on_cast(c: Node, id: String) -> void:
	casts.append([Time.get_ticks_msec(), "oyuncu" if c == main.player else String(c.name), id])


func _alive() -> Dictionary:
	var r = {"nodes": 0, "light": 0, "part": 0, "mesh": 0}
	var keep = []
	for w in added:
		var n = w.get_ref()
		if n == null or not n.is_inside_tree():
			continue
		keep.append(w)
		r["nodes"] += 1
		if n is Light3D and n.visible:
			r["light"] += 1
		elif n is GPUParticles3D or n is CPUParticles3D:
			r["part"] += 1
		elif n is MeshInstance3D or n is MultiMeshInstance3D:
			r["mesh"] += 1
	added = keep
	return r


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
	var vrid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var nE = int(OS.get_environment("BF_N")) if OS.get_environment("BF_N") != "" else 4
	var dur = float(OS.get_environment("BF_SEC")) if OS.get_environment("BF_SEC") != "" else 40.0
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var at: Vector3
	if OS.get_environment("BF_AT") == "kir":
		at = Missions.open_ground(pl.global_position + Vector3(900.0, 0, 1400.0), 80.0)
	else:
		at = Missions.open_ground(c + Vector3(120, 0, -160), 25.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	pl.respawn(at)
	pl.max_hp = 9999999.0
	pl.max_chakra = 9999999.0
	# oyuncunun teknikleri: oyunda sık kullanılan, farklı doğalardan
	var my = ["katon_goukakyuu", "katon_karyuu", "fuuton_daitoppa", "fuuton_rasenshuriken", "raiton_chidori", "suiton_suiryuudan", "doton_doryuheki", "kage_bunshin", "amaterasu"]
	my = my.filter(func(j): return Data.jutsu.has(j))
	for j in my:
		if not (j in Game.profile["learned"]):
			Game.profile["learned"].append(j)
	await get_tree().create_timer(float(OS.get_environment("BF_WAIT")) if OS.get_environment("BF_WAIT") != "" else 12.0).timeout
	# taban
	var t0 = Time.get_ticks_usec()
	var nb = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		nb += 1
	print("BF taban FPS %.0f" % (nb / 3.0))
	# düşmanlar: dünyadaki gerçek ninjalar (rütbe 2+), kendi teknik listeleriyle
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 2)
	cands.sort_custom(func(a, b): return String(a.get("id", a.get("name", ""))) < String(b.get("id", b.get("name", ""))))
	seed(int(OS.get_environment("BF_SEED")) if OS.get_environment("BF_SEED") != "" else 4242)
	cands.shuffle()
	Jutsu.jutsu_cast.connect(_on_cast)
	get_tree().node_added.connect(_on_added)
	var foes = []
	# sabit kadro (karşılaştırma adil olsun): dört köy ninjası, her birinin sabit teknik listesi
	var FIX = [["kumo", ["raiton_nagashi", "raiton_chidori", "raitojutsu_rakurai", "daburu_kuropansa"]],
		["kiri", ["suiton_suiryuudan", "suiton_daibakufu_no_jutsu", "suiton_suikoudan", "mizu_tatsumaki"]],
		["iwa", ["doton_doryuusou", "doton_doryuheki", "iwao_ganseki_ame", "doton_chokeijugan"]],
		["suna", ["fuuton_daitoppa", "fuuton_shinkuu", "katon_goukakyuu", "katon_karyuu"]]]
	for i in nE:
		seed(1000 + i)
		var a = WorldPeople.arch_of(cands[i % cands.size()]) if OS.get_environment("BF_WORLD") != "" else Enemy.archetype(FIX[i % 4][0], i)
		if OS.get_environment("BF_WORLD") == "":
			a["jutsu"] = FIX[i % 4][1].filter(func(j): return Data.jutsu.has(j))
			a["level"] = 60
			a["skill"] = 0.8
		a["respawn"] = false
		var e = Enemy.new()
		e.setup(a)
		get_tree().current_scene.add_child(e)
		e.global_position = at + Vector3(randf_range(-10, 10), 0.5, randf_range(-14, -7))
		e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.3
		e.home = e.global_position
		e.max_hp = 9999999.0
		e.hp = e.max_hp
		e.target = pl
		foes.append(e)
		print("BF dusman %s: %s" % [e.name, str(a.get("jutsu", []))])
		await get_tree().process_frame
	if OS.get_environment("BF_PF") != "":
		Engine.set_meta("pf", {})
	Engine.set_meta("jx", {})
	if OS.get_environment("BF_FX") != "":
		Engine.set_meta("fx_pf", {})
	var vt0 = Time.get_ticks_usec()
	var win0 = vt0
	var wn = 0
	var wworst = 0
	var wgpu = 0.0
	var last = vt0
	var allf = 0
	var hitches = 0
	var next_cast = 2.0
	var mi = 0
	var prevpf = {}
	var prevfx = {}
	var wrc = 0.0
	while Time.get_ticks_usec() - vt0 < int(dur * 1e6):
		await get_tree().process_frame
		var now = Time.get_ticks_usec()
		var ft = now - last
		last = now
		wn += 1
		allf += 1
		wworst = maxi(wworst, ft)
		wgpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		wrc += RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
		var fxd = {}
		if Engine.has_meta("fx_pf"):
			var fcur: Dictionary = Engine.get_meta("fx_pf")
			if ft > 40000:
				for k in fcur:
					var dd2 = int(fcur[k][1]) - int(prevfx.get(k, 0))
					if dd2 > 8000:
						fxd[k] = dd2 / 1000
			prevfx = {}
			for k in fcur:
				prevfx[k] = fcur[k][1]
		var pfd = {}
		if Engine.has_meta("pf"):
			var cur: Dictionary = Engine.get_meta("pf")
			for k in cur:
				var dd = int(cur[k]) - int(prevpf.get(k, 0))
				if dd > 3000:
					pfd[k] = dd / 1000
			prevpf = cur.duplicate()
		pl.hp = pl.max_hp
		pl.chakra = pl.max_chakra
		for e in foes:
			if is_instance_valid(e):
				e.hp = e.max_hp
		if ft > 40000:
			hitches += 1
			var nowms = Time.get_ticks_msec()
			var rec = casts.filter(func(x): return nowms - x[0] < 400).map(func(x): return "%s:%s" % [x[1], x[2]])
			print("BF TAKILMA t=%.1f %d FPS | son teknikler %s | betik %s | fx %s | rcpu %.1f" % [(now - vt0) / 1e6, int(1e6 / ft), str(rec), str(pfd), str(fxd), RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()])
		if OS.get_environment("BF_PL") != "0" and (now - vt0) / 1e6 > next_cast and not my.is_empty() and not foes.is_empty():
			next_cast += 3.0
			var tgt = foes[mi % foes.size()]
			if is_instance_valid(tgt):
				pl.combat.lock_target = tgt
				pl.combat.cooldowns.clear()
				Jutsu.execute(pl, my[mi % my.size()], tgt)
			mi += 1
		if now - win0 > 2000000:
			var al = _alive()
			print("BF t=%4.0f | ort %3.0f | kotu %3.0f | gpu %.1f | rcpu %.1f | tween %d | fizik aktif %d cift %d | dugum %d | efekt" % [(now - vt0) / 1e6, wn / ((now - win0) / 1e6), 1e6 / maxf(1.0, wworst), wgpu / wn, wrc / wn, get_tree().get_processed_tweens().size(), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), get_tree().get_node_count()] + " | efekt dugum %d isik %d parcacik %d mesh %d | teknik %d" % [al["nodes"], al["light"], al["part"], al["mesh"], casts.size()])
			win0 = now
			wn = 0
			wworst = 0
			wgpu = 0.0
			wrc = 0.0
	if OS.get_environment("BF_EXP") != "":
		await _experiments(vrid)
	print("BF SONUC ort %.0f FPS | 25 FPS alti kare %d | toplam teknik %d" % [allf / dur, hitches, casts.size()])
	if Engine.has_meta("pf"):
		var d: Dictionary = Engine.get_meta("pf")
		var ks = d.keys()
		ks.sort_custom(func(a, b): return d[a] > d[b])
		var tot = 0.0
		for k in ks:
			tot += d[k]
		print("BFP toplam betik %.2f ms/kare" % (tot / 1000.0 / allf))
		for k in ks.slice(0, 30):
			print("BFP   %-36s %.2f" % [k, d[k] / 1000.0 / allf])
	if Engine.has_meta("fx_pf"):
		var fd: Dictionary = Engine.get_meta("fx_pf")
		var fk = fd.keys()
		fk.sort_custom(func(a, b): return fd[a][1] > fd[b][1])
		for k in fk.slice(0, 60):
			print("BFX %-48s x%6d toplam %7.1f ms  ort %.3f ms" % [k, fd[k][0], fd[k][1] / 1000.0, fd[k][1] / 1000.0 / fd[k][0]])
	var jx: Dictionary = Engine.get_meta("jx")
	var jk = jx.keys()
	jk.sort_custom(func(a, b): return jx[a][2] > jx[b][2])
	for k in jk:
		print("BFJ %-34s x%d ort %.0f ms en cok %.0f ms" % [k, jx[k][0], jx[k][1] / 1000.0 / jx[k][0], jx[k][2] / 1000.0])
	# yaşayan efekt düğümleri: hangi betiğin altında
	var own = {}
	for w in added:
		var n = w.get_ref()
		if n == null or not n.is_inside_tree():
			continue
		var q: Node = n
		var key = "?"
		while q != null and q != get_tree().current_scene:
			if q.get_script() != null:
				key = String(q.get_script().resource_path).get_file() + " (" + q.get_class() + ")"
				break
			if q.get_parent() == get_tree().current_scene:
				key = "sahne/" + String(q.name).left(24) + " (" + q.get_class() + ")"
				break
			q = q.get_parent()
		own[key] = int(own.get(key, 0)) + 1
	var ok = own.keys()
	ok.sort_custom(func(a, b): return own[a] > own[b])
	for k in ok.slice(0, 30):
		print("BFO %5d %s" % [own[k], k])
	var cnt = {}
	for x in casts:
		cnt[x[2]] = int(cnt.get(x[2], 0)) + 1
	print("BF teknikler ", cnt)
	print("BF yeni modeller ", models)
	print("BF koylu cikis ", exits)
	get_tree().quit()


func _win(tag: String, vrid: RID, sec := 3.0) -> float:
	await get_tree().create_timer(0.4).timeout
	var t0 = Time.get_ticks_usec()
	var n = 0
	var g = 0.0
	while Time.get_ticks_usec() - t0 < int(sec * 1e6):
		await get_tree().process_frame
		n += 1
		g += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		main.player.hp = main.player.max_hp
		for f in get_tree().get_nodes_in_group("fighters"):
			if f is Enemy:
				f.hp = f.max_hp
	var fps = n / ((Time.get_ticks_usec() - t0) / 1e6)
	print("BFE %-26s fps %5.1f gpu %.1f" % [tag, fps, g / n])
	return fps


func _experiments(vrid: RID) -> void:
	var root = get_tree().root
	var cam = get_viewport().get_camera_3d()
	for rep in 3:
		await _win("taban", vrid)
		var mix = root.find_children("*", "AnimationMixer", true, false)
		var off = []
		for m in mix:
			var o = m.get_parent()
			while o != null and not (o is Node3D):
				o = o.get_parent()
			if o is Node3D and cam and (o as Node3D).global_position.distance_to(cam.global_position) > 25.0 and m.active:
				m.active = false
				off.append(m)
		await _win("uzak animasyon kapali (%d/%d)" % [off.size(), mix.size()], vrid)
		for m in off:
			if is_instance_valid(m):
				m.active = true
		var vs = []
		for n in root.find_children("*", "CharacterBody3D", true, false):
			if n is Fighter or n == main.player:
				continue
			if n.process_mode != Node.PROCESS_MODE_DISABLED:
				n.process_mode = Node.PROCESS_MODE_DISABLED
				vs.append(n)
		await _win("koylu/ortam kisileri durduruldu (%d)" % vs.size(), vrid)
		for n in vs:
			if is_instance_valid(n):
				n.process_mode = Node.PROCESS_MODE_INHERIT
		for n in vs:
			if is_instance_valid(n):
				n.visible = false
				n.process_mode = Node.PROCESS_MODE_DISABLED
		await _win("koyluler gizli+durdu", vrid)
		for n in vs:
			if is_instance_valid(n):
				n.visible = true
				n.process_mode = Node.PROCESS_MODE_INHERIT
