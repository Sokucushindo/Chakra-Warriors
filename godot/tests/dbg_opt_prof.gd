extends Node
## Optimizasyon profili: birkaç yerde sınırsız FPS + ekran kartı / işlemci süresi + çizim sayıları.
## OP_X=1: her noktada görünümü bozmayan deneyleri tek tek aç/kapa (fark = kazanç)
var main: Node
class First extends Node:
	static var t0 := 0
	func _process(_d):
		t0 = Time.get_ticks_usec()
class Last extends Node:
	static var sum := 0
	static var n := 0
	func _process(_d):
		sum += Time.get_ticks_usec() - First.t0
		n += 1


func _measure(tag: String, yaw: float, sec := 2.5) -> void:
	main.player.yaw = yaw
	await get_tree().create_timer(0.8).timeout
	var t0 = Time.get_ticks_usec()
	var n = 0
	var gpu = 0.0
	var cpu = 0.0
	var proc = 0.0
	var phys = 0.0
	var draws = 0.0
	var objs = 0.0
	var prim = 0.0
	var vrid = get_viewport().get_viewport_rid()
	Last.sum = 0
	Last.n = 0
	var pfon = OS.get_environment("OP_PF") != ""
	if pfon:
		Engine.set_meta("pf", {})
	while Time.get_ticks_usec() - t0 < int(sec * 1000000.0):
		await get_tree().process_frame
		n += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ms = (Time.get_ticks_usec() - t0) / 1000.0 / n
	if pfon:
		var d: Dictionary = Engine.get_meta("pf")
		Engine.remove_meta("pf")
		var ks = d.keys()
		ks.sort_custom(func(a, b): return d[a] > d[b])
		var tot = 0.0
		for k in ks:
			tot += d[k]
		print("OPF %s toplam betik %.2f ms/kare" % [tag, tot / 1000.0 / n])
		for k in ks.slice(0, 18):
			print("OPF    %-34s %.2f" % [k, d[k] / 1000.0 / n])
	print("OP %-28s span %.2f ms" % [tag, Last.sum / 1000.0 / maxi(1, Last.n)])
	print("OP %-28s fps %5.1f | gpu %5.1f | rcpu %5.1f | proc %5.1f | phys %5.1f | draws %5.0f | objs %5.0f | tris %.2fM" % [tag, 1000.0 / ms, gpu / n, cpu / n, proc / n, phys / n, draws / n, objs / n, prim / n / 1e6])


func _go(at: Vector3, wait := 10.0) -> void:
	var q = Missions.open_ground(at, 30.0)
	q.y = Game.ground_height(q.x, q.z) + 0.5
	main.player.global_position = q
	main.player.velocity = Vector3.ZERO
	await get_tree().create_timer(wait).timeout


func _spot(tag: String) -> void:
	await _measure(tag + " a", 0.0)
	await _measure(tag + " b", PI * 0.5)
	await _measure(tag + " c", PI)
	if OS.get_environment("OP_A") != "":
		var root = get_tree().root
		var mix = root.find_children("*", "AnimationMixer", true, false)
		var sk = root.find_children("*", "Skeleton3D", true, false)
		var gp = root.find_children("*", "GPUParticles3D", true, false)
		var cp = root.find_children("*", "CPUParticles3D", true, false)
		var bodies = root.find_children("*", "CharacterBody3D", true, false)
		var areas = root.find_children("*", "Area3D", true, false)
		var lights = root.find_children("*", "Light3D", true, false)
		var onl = 0
		for l in lights:
			if l.visible and l.is_visible_in_tree():
				onl += 1
		var act = 0
		for m in mix:
			if m.active:
				act += 1
		print("OPA %s mixer %d (aktif %d) skel %d gpup %d cpup %d body %d area %d isik %d (acik %d) dugum %d" % [tag, mix.size(), act, sk.size(), gp.size(), cp.size(), bodies.size(), areas.size(), lights.size(), onl, get_tree().get_node_count()])
		var cnt = {}
		var cls = {}
		var st = [root]
		while not st.is_empty():
			var nd: Node = st.pop_back()
			for ch in nd.get_children():
				st.append(ch)
			var key = nd.get_class()
			var sc = nd.get_script()
			if sc:
				key += ":" + String(sc.resource_path).get_file()
			cls[nd.get_class()] = int(cls.get(nd.get_class(), 0)) + 1
			var flags = ""
			if nd.is_processing():
				flags += "P"
			if nd.is_physics_processing():
				flags += "F"
			if nd.is_processing_internal():
				flags += "i"
			if nd.is_physics_processing_internal():
				flags += "f"
			if flags != "":
				var k2 = flags + " " + key
				cnt[k2] = int(cnt.get(k2, 0)) + 1
		var ks = cnt.keys()
		ks.sort_custom(func(a, b): return cnt[a] > cnt[b])
		for k in ks.slice(0, 30):
			print("OPN   %5d %s" % [cnt[k], k])
		var kc = cls.keys()
		kc.sort_custom(func(a, b): return cls[a] > cls[b])
		for k in kc.slice(0, 15):
			print("OPC   %6d %s" % [cls[k], k])
		for b in bodies:
			if b != main.player:
				b.process_mode = Node.PROCESS_MODE_DISABLED
		await _measure(tag + " A govdeler durduruldu", PI)
		for b in bodies:
			b.process_mode = Node.PROCESS_MODE_INHERIT
		await _measure(tag + " A geri", PI)
	if OS.get_environment("OP_X") == "":
		return
	var vp = get_viewport()
	var env = Game.world.env
	env.post.visible = false
	await _measure(tag + " X cizgi yok", PI)
	env.post.visible = true
	var e: Environment = env.get("env")
	var s0 = e.ssao_enabled
	e.ssao_enabled = false
	await _measure(tag + " X ssao yok", PI)
	e.ssao_enabled = s0
	var g0 = e.glow_enabled
	e.glow_enabled = false
	await _measure(tag + " X glow yok", PI)
	e.glow_enabled = g0
	var m0 = vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await _measure(tag + " X msaa yok", PI)
	vp.msaa_3d = m0
	var sun: DirectionalLight3D = null
	for nd in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if nd.shadow_enabled:
			sun = nd
	if sun:
		sun.shadow_enabled = false
		await _measure(tag + " X gunes golgesi yok", PI)
		sun.shadow_enabled = true
	var grass = Game.world.get_node_or_null("Grass")
	if grass:
		grass.visible = false
		await _measure(tag + " X cim yok", PI)
		grass.visible = true
	var veg = Game.world.vegetation
	for k in veg.chunks:
		veg.chunks[k]["node"].visible = false
	await _measure(tag + " X bitki yok", PI)
	for k in veg.chunks:
		veg.chunks[k]["node"].visible = true
	vp.scaling_3d_scale = 0.5
	await _measure(tag + " X yari cozunurluk", PI)
	vp.scaling_3d_scale = 1.0
	var hidden = []
	for nd in get_tree().get_nodes_in_group("fighters") + get_tree().get_nodes_in_group("talkers"):
		if nd is Node3D and nd.visible and nd != main.player:
			nd.visible = false
			hidden.append(nd)
	await _measure(tag + " X kisiler gizli (%d)" % hidden.size(), PI)
	for nd in hidden:
		nd.visible = true


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	var f1 = First.new()
	f1.process_priority = -1000000
	get_tree().root.add_child(f1)
	var l1 = Last.new()
	l1.process_priority = 1000000
	get_tree().root.add_child(l1)
	await main._start_new_game()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().create_timer(4.0).timeout
	Hud.close_dialog()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Game.world.env.time_of_day = 0.45
	WorldDay.auto = false
	Game.profile["kd_wait"] = 99999.0
	if OS.get_environment("OP_Q") != "":
		Game.set_quality(int(OS.get_environment("OP_Q")))
	print("OP settings q=", Game.settings.get("quality"), " win=", get_window().size, " scale=", get_viewport().scaling_3d_scale)
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var r = float(v["r"])
	var only = OS.get_environment("OP_ONLY")
	if only == "" or only.contains("k"):
		await _go(c + Vector3(150, 0, -200), 8.0)
		await _spot("konoha cekirdek")
	if only == "" or only.contains("o"):
		await _go(c + Vector3(0.7, 0, -0.7) * (r + 400.0), 10.0)
		await _spot("orman")
	if only == "" or only.contains("s"):
		var vs = Game.village("suna")
		var cs = Game.from_map(Vector2(float(vs["x"]), float(vs["y"])))
		await _go(cs + Vector3(60, 0, -60), 25.0)
		await _spot("suna")
	print("OP done")
	get_tree().quit()
