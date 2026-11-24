extends Node
## 50 ev türü denetimi: oyunun gerçek Placer'ıyla kurulur; görünen yüzey (walls+roof+detail trimesh, katman 2) ile gerçek çarpışma
## (katman 1) ışınla karşılaştırılır. GEC = görünüyor ama içinden geçiliyor, GOR = görünmez duvar. Her tür 2 yakın çekim (hc_XX_a/b).
var main: Node
var SHOTS := true

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(960, 517)
	im.save_png(path)

func _ray(a: Vector3, b: Vector3, mask: int) -> Dictionary:
	var q = PhysicsRayQueryParameters3D.create(a, b, mask)
	q.hit_back_faces = true
	return get_viewport().world_3d.direct_space_state.intersect_ray(q)

func _ready() -> void:
	await get_tree().process_frame
	SHOTS = OS.get_environment("NOSHOT") == ""
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.42
	WorldDay.auto = false
	HouseKit.ensure()
	var only = OS.get_environment("ONLY")
	var base = main.player.global_position + Vector3(0, 900, 0)
	var host = Node3D.new()
	get_tree().current_scene.add_child(host)
	var pl = HouseKit.Placer.new(host, "")
	var vis = StaticBody3D.new()
	vis.collision_layer = 2
	vis.collision_mask = 0
	host.add_child(vis)
	var visd = StaticBody3D.new()
	visd.collision_layer = 4
	visd.collision_mask = 0
	host.add_child(visd)
	var rng = RandomNumberGenerator.new()
	var pos = {}
	var cols = [Color(0.9, 0.84, 0.72), Color(0.84, 0.86, 0.86), Color(0.84, 0.88, 0.76), Color(0.9, 0.8, 0.76)]
	var rcols = [Color(0.93, 0.56, 0.2), Color(0.4, 0.6, 0.85), Color(0.42, 0.66, 0.42), Color(0.82, 0.3, 0.22)]
	for i in HouseKit.templates.size():
		if only != "" and not (str(i) in only.split(",")):
			continue
		var p = base + Vector3((i % 10) * 70.0, 0, (i / 10) * 70.0)
		var floor_b = CSGBox3D.new()
		floor_b.size = Vector3(60, 0.4, 60)
		host.add_child(floor_b)
		floor_b.global_position = p + Vector3(0, -0.2, 0)
		pl.force_ti = i
		pl.add(p, 0.0, cols[i % 4], rcols[(i / 3) % 4], rng)
		var t: Dictionary = HouseKit.templates[i]
		var xf = Transform3D(Basis(Vector3.UP, PI), p)
		for k in ["walls", "roof", "detail"]:
			var cs = CollisionShape3D.new()
			cs.shape = (t[k] as ArrayMesh).create_trimesh_shape()
			cs.transform = xf
			(visd if k == "detail" else vis).add_child(cs)
		pos[i] = p
	pl.finish()
	for _k in 4:
		await get_tree().physics_frame
	main.player.visible = false
	var total_bad = 0
	for i in pos:
		var t: Dictionary = HouseKit.templates[i]
		var p: Vector3 = pos[i]
		var W = float(t["w"]) * 0.5 + 1.5
		var D = float(t["d"]) * 0.5 + 1.5
		var top = float(t["roof_top"]) + 8.0
		var gec = 0; var gor = 0; var n = 0
		var ex_g = []; var ex_o = []; var dg = 0; var ex_d = []
		# yukarıdan aşağı
		var x = -W
		while x <= W:
			var z = -D
			while z <= D:
				var a = p + Vector3(x, top, z)
				var bb = p + Vector3(x, 0.05, z)
				var hp = _ray(a, bb, 1); var hv = _ray(a, bb, 2); var hd = _ray(a, bb, 4)
				var yd = hd.position.y - p.y if hd else 0.0
				var ypp = hp.position.y - p.y if hp else 0.0
				if yd - maxf(ypp, (hv.position.y - p.y) if hv else 0.0) > 0.7:
					dg += 1
					if ex_d.size() < 6: ex_d.append("ust(%.0f,%.0f) %.1f" % [x, z, yd])
				var yp = hp.position.y - p.y if hp else 0.0
				var yv = maxf(hv.position.y - p.y if hv else 0.0, yd)
				n += 1
				if yv - yp > 0.7:
					gec += 1
					if ex_g.size() < 4: ex_g.append("ust(%.0f,%.0f) gor=%.1f carp=%.1f" % [x, z, yv, yp])
				elif yp - yv > 0.7:
					gor += 1
					if ex_o.size() < 4: ex_o.append("ust(%.0f,%.0f) gor=%.1f carp=%.1f" % [x, z, yv, yp])
				z += 0.8
			x += 0.8
		# yanlardan (4 yön, 3 yükseklik)
		for hgt in [1.2, 3.0, 6.0, 9.0]:
			if hgt > float(t["h"]):
				continue
			for side in 4:
				var dirv = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][side]
				var span = D if side < 2 else W
				var far = W + 3.0 if side < 2 else D + 3.0
				var u = -span
				while u <= span:
					var lat = Vector3(0, 0, u) if side < 2 else Vector3(u, 0, 0)
					var a = p + Vector3(0, hgt, 0) + lat - dirv * far
					var bb = p + Vector3(0, hgt, 0) + lat + dirv * 0.0
					var hp = _ray(a, bb, 1); var hv = _ray(a, bb, 2); var hd = _ray(a, bb, 4)
					var ddd = a.distance_to(hd.position) if hd else far
					var dpp = a.distance_to(hp.position) if hp else far
					var dvv = a.distance_to(hv.position) if hv else far
					if minf(dpp, dvv) - ddd > 0.7:
						dg += 1
						if ex_d.size() < 10: ex_d.append("yan%d h%.0f u%.0f %.1f" % [side, hgt, u, far - ddd])
					var dp = a.distance_to(hp.position) if hp else far
					var dv = minf(a.distance_to(hv.position) if hv else far, ddd)
					n += 1
					if dp - dv > 0.7:
						gec += 1
						if ex_g.size() < 8: ex_g.append("yan%d h%.0f u%.0f gor=%.1f carp=%.1f" % [side, hgt, u, far - dv, far - dp])
					elif dv - dp > 0.7:
						gor += 1
						if ex_o.size() < 8: ex_o.append("yan%d h%.0f u%.0f gor=%.1f carp=%.1f" % [side, hgt, u, far - dv, far - dp])
					u += 0.8
		var pg = 100.0 * gec / maxf(1, n); var po = 100.0 * gor / maxf(1, n)
		if pg > 2.0 or po > 2.0:
			total_bad += 1
		print("HCHK %02d %s/%s w=%.1f d=%.1f  GEC %.1f%%  GOR %.1f%%  SUS %d  %s | %s" % [i, t.get("plan", "?"), t.get("roof_t", "?"), t["w"], t["d"], pg, po, dg, str(ex_g), str(ex_o)])
		print("HDET %02d %s" % [i, str(ex_d)])
	print("HCHK kotu tur: %d" % total_bad)
	if SHOTS:
		var cam = Camera3D.new()
		cam.fov = 55.0
		get_tree().current_scene.add_child(cam)
		cam.current = true
		DirAccess.make_dir_recursive_absolute("D:/Naruto 3D Game/_tmp/hchk")
		for i in pos:
			var t: Dictionary = HouseKit.templates[i]
			var p: Vector3 = pos[i]
			var r = maxf(float(t["w"]), float(t["d"])) * 1.05 + 6.0
			var hh = float(t["roof_top"]) * 0.45
			# a: ön sol çapraz (ön cephe -z yerel, Placer PI döndürür -> dünyada +z)
			cam.global_position = p + Vector3(-r * 0.75, hh + 4.0, r * 0.95)
			cam.look_at(p + Vector3(0, hh, 0))
			await get_tree().create_timer(0.25).timeout
			await _shot("D:/Naruto 3D Game/_tmp/hchk/hc_%02d_a.png" % i)
			cam.global_position = p + Vector3(r * 0.8, hh + 7.0, -r * 0.9)
			cam.look_at(p + Vector3(0, hh, 0))
			await get_tree().create_timer(0.25).timeout
			await _shot("D:/Naruto 3D Game/_tmp/hchk/hc_%02d_b.png" % i)
	get_tree().quit()
