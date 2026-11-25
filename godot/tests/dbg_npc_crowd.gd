extends Node
## Köylü kalabalığı: iç içe geçme + konuşma balonu üst üste binmesi + gece feneri.
## 1) Konoha'da bir tezgâh önü (öğlen), 20 sn: en yakın iki köylü arası (min), 0.5 m'den yakın çift sayısı,
##    üst üste binen görünür balon çifti. 5. sn'de 4 kişi aynı noktaya ışınlanır (ayrılıyorlar mı), her 2 sn'de yakın
##    3 kişiye söz söyletilir (önemli + ortam karışık).
## 2) Gece: fenerli nöbetçi + devriye yakın çekim.
## Çıktı: CROWD ... satırları, görüntüler: crowd_00, crowd_01, lantern_00..02
var main: Node
const VL = preload("res://scripts/world/village_life.gd")


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.5
	WorldDay.auto = false
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	# kalabalık yeri: merkeze en yakın tezgâh (yoksa merkez)
	var spot: Vector3 = c
	var bd = 1e9
	for s in VL.sites.get("konoha", []):
		if String(s.get("type", "")) in ["stall", "crowd"]:
			var sp: Vector3 = s.get("front", s["pos"])
			var d = sp.distance_to(c)
			if d < bd:
				bd = d
				spot = sp
	spot.y = Game.terrain_height(spot.x, spot.z)
	print("CROWD spot=%s" % str(spot))
	main.player.respawn(spot + Vector3(3, 1, 3))
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	await get_tree().create_timer(6.0).timeout   # kalabalık dolsun
	main.player.visible = false
	cam.global_position = spot + Vector3(7, 3.2, 7)
	cam.look_at(spot + Vector3(0, 1.4, 0), Vector3.UP)
	cam.current = true
	var t := 0.0
	var min_d := 1e9
	var close_n := 0
	var bub_ov := 0
	var said_t := 0.0
	var stacked := false
	var samples := 0
	while t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		var vs: Array = Villager._all.filter(func(n): return is_instance_valid(n) and not n.fading and n.role != "roof" and n.global_position.distance_to(spot) < 40.0)
		if t >= 5.0 and not stacked:
			stacked = true
			# zorlama: 4 kişiyi aynı noktaya koy
			var k = 0
			for n in vs:
				if n.role in ["walker", "shopper", "kid", "patrol"] and k < 4:
					n.global_position = spot + Vector3(1.5, 0.05, 1.5)
					n.reset_physics_interpolation()
					k += 1
			print("CROWD stacked=%d at t=5" % k)
		said_t -= 0.25
		if said_t <= 0.0:
			said_t = 2.0
			var near = vs.filter(func(n): return n.global_position.distance_to(spot) < 12.0)
			near.shuffle()
			for i in mini(3, near.size()):
				near[i].say(["Bugün pazar çok kalabalık, değil mi? Fiyatlar yine artmış.", "Taze sebze!", "Hokage Kulesi'nde görev kuyruğu var."][i], 3.0, i != 1)
		# ölçüm (zorlamadan sonraki ilk 2 sn ayrılma süresi sayılmaz)
		if t > 2.0 and not (t > 5.0 and t < 7.5):
			samples += 1
			for i in vs.size():
				for j in range(i + 1, vs.size()):
					var a: Vector3 = vs[i].global_position
					var b: Vector3 = vs[j].global_position
					if absf(a.y - b.y) > 1.6:
						continue
					var d = Vector2(a.x - b.x, a.z - b.z).length()
					if vs[i].role in ["sitter", "customer"] and vs[j].role in ["sitter", "customer"]:
						continue   # bankta yan yana oturanlar
					min_d = minf(min_d, d)
					if d < 0.5:
						close_n += 1
		var bs: Array = vs.filter(func(n): return n.bubble != null and n.bubble.visible)
		for i in bs.size():
			for j in range(i + 1, bs.size()):
				var a = bs[i]
				var b = bs[j]
				var dh = Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
				if dh > 3.0:
					continue
				var ay: float = a.bubble.global_position.y
				var by: float = b.bubble.global_position.y
				if ay < by + b._bub_h and by < ay + a._bub_h:
					bub_ov += 1
		if is_equal_approx(t, 9.0):
			await main.shot("crowd_00")
		if is_equal_approx(t, 15.0):
			await main.shot("crowd_01")
	print("CROWD npcs_near=%d samples=%d min_dist=%.2f close_pairs(<0.5m)=%d bubble_overlaps=%d" % [Villager._all.size(), samples, min_d, close_n, bub_ov])
	# ---- dağılım: 3 yerde (merkez tezgâhı, köy merkezinden 250 m, köy kenarına yakın) 15 sn sonra 50 m hücre histogramı
	var vr = float(v["r"])
	var places = [spot, c + Vector3(250, 0, 0), c + (Vector3(0, 0, -1) * maxf(300.0, vr * 0.8))]
	for pi in places.size():
		var pl: Vector3 = places[pi]
		pl.y = Game.terrain_height(pl.x, pl.z)
		main.player.respawn(pl + Vector3(0, 1, 0))
		await get_tree().create_timer(15.0).timeout
		_dist_report("p%d" % pi, main.player.global_position)
		cam.global_position = main.player.global_position + Vector3(0, 30, 25)
		cam.look_at(main.player.global_position, Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		await main.shot("crowd_dist_%d" % pi)
	# ---- gece feneri
	main.world.env.time_of_day = 0.93
	var gp = spot + Vector3(-4, 0, 6)
	gp.y = Game.terrain_height(gp.x, gp.z)
	var g = Villager.new()
	g.role = "guard"
	g.night = true
	get_tree().current_scene.add_child(g)
	g.global_position = gp
	g.home = gp
	g.goal = gp
	g.stand_face = 0.0
	g.fixed_face = true
	var pt = Villager.new()
	pt.role = "patrol"
	pt.night = true
	pt.points = [gp + Vector3(10, 0, 0), gp + Vector3(-10, 0, 2), gp + Vector3(0, 0, 12)]
	get_tree().current_scene.add_child(pt)
	pt.global_position = gp + Vector3(3, 0, 0)
	pt.home = pt.global_position
	pt.goal = gp + Vector3(12, 0, 0)
	main.player.respawn(gp + Vector3(2, 1, -3))
	await get_tree().create_timer(3.0).timeout
	main.player.visible = false
	print("CROWD lantern guard=%s patrol=%s" % [str(g.lantern != null), str(pt.lantern != null)])
	var gpos = g.global_position
	# önden-yandan, yandan, arkadan-yandan (nöbetçi -Z'ye bakar)
	var views = [Vector3(1.2, 1.4, -2.2), Vector3(2.4, 1.2, 0.2), Vector3(-1.6, 1.6, 2.0)]
	for i in views.size():
		cam.global_position = gpos + views[i]
		cam.look_at(gpos + Vector3(0.25, 0.9, -0.3), Vector3.UP)
		await get_tree().create_timer(0.6).timeout
		await main.shot("lantern_%02d" % i)
	# yürüyen devriye: fener sallanıyor mu
	var pp = pt.global_position
	cam.global_position = pp + Vector3(3.0, 1.6, 3.0)
	cam.look_at(pp + Vector3(0, 1.0, 0), Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await main.shot("lantern_03")
	if pt.lantern != null:
		print("CROWD patrol lamp sway=%.3f" % pt.lantern.sw.length())
	get_tree().quit()


## 50 m hücre başına köylü sayısı (oyuncu çevresi 175 m) + herhangi bir köylünün 15 m çevresindeki en kalabalık sayı
func _dist_report(tag: String, p: Vector3) -> void:
	var vs: Array = Villager._all.filter(func(n): return is_instance_valid(n) and not n.fading and n.global_position.distance_to(p) < 175.0)
	var cells := {}
	for n in vs:
		var q: Vector3 = n.global_position - p
		var k = Vector2i(floori(q.x / 50.0), floori(q.z / 50.0))
		cells[k] = int(cells.get(k, 0)) + 1
	var hist := {}
	for k in cells:
		var cn = int(cells[k])
		hist[cn] = int(hist.get(cn, 0)) + 1
	var max15 = 0
	for n in vs:
		var cnt = 0
		for o in vs:
			if o.global_position.distance_to(n.global_position) < 15.0:
				cnt += 1
		max15 = maxi(max15, cnt)
	var near30 = vs.filter(func(n): return n.global_position.distance_to(p) < 30.0).size()
	print("CROWD dist %s total=%d cells=%d hist(count:cells)=%s max_in_15m=%d within30m_of_player=%d" % [tag, vs.size(), cells.size(), str(hist), max15, near30])
