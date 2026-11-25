extends Node
## Haydut Kampı (harita: bandit_camp) görüntü denetimi. Kamera kamp merkezine göre yerel (x doğu, n kuzey) konumlardan bakar.
## CAMS="x,n,yükseklik,hx,hn;..." ile özel açılar; yoksa 6 çevre açısı + 1 kuşbakışı + 3 yakın çekim.
## GRID=1: kamp çevresinde arazi yüksekliği tablosu yazdırır.
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.42
	WorldDay.auto = false
	var v = Game.village("bandit_camp")
	var poi_id = OS.get_environment("POI")
	if poi_id != "":   # vahşi doğadaki POI kampı (akışla kurulur)
		for q in Game.pois:
			if String(q["id"]) == poi_id:
				v = {"x": q["x"], "y": q["y"], "base": Game.terrain_height(float(q["x"]), -float(q["y"]))}
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	if poi_id != "":
		main.player.respawn(Vector3(c.x + 40, Game.terrain_height(c.x + 40, c.z) + 1.0, c.z))
		await get_tree().create_timer(8.0).timeout
	if OS.get_environment("GRID") != "":
		for n in range(60, -61, -15):
			var row = ""
			for x in range(-60, 61, 15):
				row += "%7.1f" % (Game.terrain_height(c.x + x, c.z - n) - float(v["base"]))
			print("BCGRID n=%4d %s" % [n, row])
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	var specs: Array = Array(OS.get_environment("CAMS").split(";", false))
	# FR=1: CAMS kamp düzleminde (f: kapıya doğru, r: sağa) verilir; kapı yönü kampın kurduğu gibi yoldan
	var Fd = Vector2(0, 1)
	for rd in Game.roads:
		if String(rd.get("b", "")) == "bandit_camp" or String(rd.get("a", "")) == "bandit_camp":
			var pts: PackedVector2Array = rd["pts"]
			var cm = Vector2(float(v["x"]), float(v["y"]))
			var far_pt = pts[pts.size() - 2] if pts[pts.size() - 1].distance_to(cm) < pts[0].distance_to(cm) else pts[1]
			Fd = (far_pt - cm).normalized()
			break
	var Rd = Vector2(Fd.y, -Fd.x)
	if OS.get_environment("FR") != "":
		var conv: Array = []
		for spec in specs:
			var q = spec.split(",")
			var a = Fd * float(q[0]) + Rd * float(q[1])
			var t2 = Fd * float(q[3]) + Rd * float(q[4])
			conv.append("%f,%f,%s,%f,%f" % [a.x, a.y, q[2], t2.x, t2.y])
		specs = conv
	if specs.is_empty():
		for k in 6:
			var a = TAU * k / 6.0 + 0.4
			specs.append("%f,%f,7,0,0" % [cos(a) * 55.0, sin(a) * 55.0])
		specs.append("0,-48,42,0,0")
		specs.append("-14,-4,2.2,-6,6")
		specs.append("10,-12,2.0,4,-2")
		specs.append("8,10,2.6,0,0")
	main.player.respawn(Vector3(c.x + 80, Game.terrain_height(c.x + 80, c.z) + 1.0, c.z))
	await get_tree().create_timer(3.0).timeout
	var en = 0
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Enemy and nd.global_position.distance_to(c) < 60.0:
			en += 1
			print("BCAMP enemy at %s" % str(nd.global_position - c))
		stack.append_array(nd.get_children())
	print("BCAMP enemies_near=%d" % en)
	if OS.get_environment("COLTEST") != "" and poi_id == "":
		await get_tree().physics_frame
		var sp = get_tree().current_scene.get_world_3d().direct_space_state
		var hits = 0; var gate_open = 0
		for k in 72:   # çit: dışarıdan merkeze 1.5 m yükseklikte ışın
			var a = TAU * k / 72.0
			var d2 = Fd.rotated(-a)   # yerel (x, n)
			var o = c + Vector3(d2.x, 0, -d2.y) * 36.0
			o.y = Game.terrain_height(o.x, o.z) + 1.5
			var e = c + Vector3(d2.x, 0, -d2.y) * 20.0
			e.y = Game.terrain_height(e.x, e.z) + 1.5
			var h = sp.intersect_ray(PhysicsRayQueryParameters3D.create(o, e, 1))
			if not h.is_empty():
				hits += 1
			elif absf(a) < 0.2 or absf(a - TAU) < 0.2:
				gate_open += 1
			else:
				print("BCOL palisade gap at deg %d" % int(rad_to_deg(a)))
		print("BCOL palisade hits=%d/72 gate_open=%d" % [hits, gate_open])
		for tw in [[25.8, -7.0], [25.8, 7.0], [-25.5, 9.0]]:   # kule döşemesi: yukarıdan aşağı
			var q = Fd * tw[0] + Rd * tw[1]
			var o2 = c + Vector3(q.x, 0, -q.y)
			var g = Game.terrain_height(o2.x, o2.z)
			var h2 = sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(o2.x, g + 7.3, o2.z), Vector3(o2.x, g - 1, o2.z), 1))
			print("BCOL tower %s floor_h=%s" % [str(tw), str(h2.get("position", Vector3(0, -999, 0)).y - g)])
		for tn in [[60.0, 12.5], [-100.0, 13.5]]:   # çadır kapısından içeri (ateşten çadır ortasına, 0.9 m)
			var a3 = deg_to_rad(tn[0])
			var q0 = Fd * 3.0 * cos(a3) + Rd * 3.0 * sin(a3)
			var q1 = Fd * tn[1] * cos(a3) + Rd * tn[1] * sin(a3)
			var o3 = c + Vector3(q0.x, 0, -q0.y); var e3 = c + Vector3(q1.x, 0, -q1.y)
			o3.y = Game.terrain_height(o3.x, o3.z) + 0.9; e3.y = Game.terrain_height(e3.x, e3.z) + 0.9
			var h3 = sp.intersect_ray(PhysicsRayQueryParameters3D.create(o3, e3, 1))
			print("BCOL tent door %s blocked=%s" % [str(tn), str(not h3.is_empty())])
	var i = 0
	for spec in specs:
		var f = spec.split(",")
		var p = Vector3(c.x + float(f[0]), 0, c.z - float(f[1]))
		var t = Vector3(c.x + float(f[3]), 0, c.z - float(f[4]))
		main.player.respawn(Vector3(c.x + 90, Game.terrain_height(c.x + 90, c.z) + 1.0, c.z))
		main.player.visible = false
		p.y = Game.terrain_height(p.x, p.z) + float(f[2])
		t.y = Game.terrain_height(t.x, t.z) + (1.0 if float(f[2]) < 4.0 else 3.0)
		cam.global_position = p
		cam.look_at(t, Vector3.UP)
		cam.current = true
		await get_tree().create_timer(1.2).timeout
		await main.shot("bc_%02d" % i)
		i += 1
	get_tree().quit()
