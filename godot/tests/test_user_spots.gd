extends Node
## Kullanıcının şikâyet ettiği yerler, oyuncu gözüyle (kamera oyuncunun ~6 m arkasında, 2.5 m yukarıda): göller, uçurum
## merdiveni, uçurum yüzü (batı ucu), plato kenarı, sur uçları, Suna hastanesi. Satırlar "US". SPOTS=a,b,... ile süzülür.
var main: Node
var cam: Camera3D
const VX := -500.0
const VY := -750.0
const CN := 1170.0


func _w(x: float, n: float, dy := 0.0) -> Vector3:
	var p = Vector3(VX + x, 0, -(VY + n))
	p.y = Game.terrain_height(p.x, p.z) + dy
	return p


func _want(k: String) -> bool:
	var f = OS.get_environment("SPOTS")
	return f == "" or k in f.split(",")


## oyuncu p'de, hedefe bakıyor; kamera arkasında
func _pv(name: String, p: Vector3, look: Vector3, back := 7.0, up := 2.6) -> void:
	var pl = main.player
	pl.global_position = p + Vector3.UP * 0.2
	pl.velocity = Vector3.ZERO
	var dir = (look - p)
	dir.y = 0
	dir = dir.normalized()
	cam.global_position = p - dir * back + Vector3.UP * up
	cam.look_at(look, Vector3.UP)
	cam.make_current()
	await get_tree().create_timer(1.3).timeout
	await main.shot(name)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Cheats.set_time(0.45)
	if Hud.get("root"):
		Hud.root.visible = false
	cam = Camera3D.new()
	cam.far = 5000.0
	cam.fov = 70.0
	add_child(cam)
	var kv = Game.village("konoha")
	var R = BuildKonoha.R
	print("US gunbai nadirlik=%d (3 mor, 4 sari)" % UI.rarity_of_gear("uchiha_gunbai"))
	# göller
	if _want("gol"):
		var gi = 0
		for e in BuildKonoha.PONDS:
			var d: Vector2 = (e[0] as Vector2).normalized()
			var c = BuildKonoha.pond_spot(kv, d, float(e[1]), R)
			var side = Vector2(-d.y, d.x)
			var r = float(e[1])
			var lo = 1e9; var hi = -1e9
			for k in 24:
				var a = TAU * k / 24.0
				var q = c + Builder.rot(cos(a) * r, sin(a) * r * 1.25, rad_to_deg(atan2(d.x, d.y)))
				var h = _w(q.x, q.y).y
				lo = minf(lo, h); hi = maxf(hi, h)
			var wl = Game.water_level(_w(c.x, c.y).x, _w(c.x, c.y).z, -100.0)
			print("US gol %d merkez %s kiyi zemin %.2f..%.2f su %.2f (kiyida en cok %.2f m havada)" % [gi, str(c), lo, hi, wl, wl - lo])
			var s1 = c + side * r * 1.6
			await _pv("us_gol%d_kiyi" % gi, _w(s1.x, s1.y), _w(c.x, c.y))
			var s2 = c + d * r * 2.2
			await _pv("us_gol%d_karsi" % gi, _w(s2.x, s2.y), _w(c.x, c.y))
			await _pv("us_gol%d_ust" % gi, _w(c.x - d.x * r * 2.5, c.y - d.y * r * 2.5, 12.0), _w(c.x, c.y), 10.0, 14.0)
			gi += 1
	# merdiven
	if _want("merdiven"):
		var xs = -2.0 * 92.0 - 92.0 * 1.1
		await _pv("us_merdiven_dip", _w(xs + 30.0, CN - 30.0), _w(xs - 10.0, CN + 10.0, 15.0), 7.0, 2.6)
		await _pv("us_merdiven_yan", _w(xs + 90.0, CN - 70.0, 0.0), _w(xs, CN + 10.0, 60.0), 7.0, 30.0)
		await _pv("us_merdiven_uzak", _w(xs, CN - 220.0), _w(xs, CN + 20.0, 80.0), 7.0, 12.0)
		# tepe: merdivenin bittiği yer, platodan
		var rd = null
		for x in Game.roads:
			if x.has("ys"):
				rd = x
		if rd != null:
			var top_i = -1
			for k in (rd["ys"] as Array).size():
				if not is_nan(float(rd["ys"][k])):
					top_i = k
			var tp: Vector2 = rd["pts"][top_i]
			var tw = Vector3(tp.x, float(rd["ys"][top_i]), -tp.y)
			print("US merdiven tepe %s zemin %.1f basamak %.1f" % [str(tw), Game.terrain_height(tw.x, tw.z), tw.y])
			await _pv("us_merdiven_tepe_plato", tw + Vector3(0, 0, -25.0) + Vector3(0, Game.terrain_height(tw.x, tw.z - 25.0) - tw.y, 0), tw, 7.0, 3.0)
			await _pv("us_merdiven_tepe_yan", tw + Vector3(30.0, 0, -10.0), tw, 7.0, 6.0)
	# uçurum batı ucu (kullanıcı: ağaçlar, kulübe) + plato kenarı + yol
	if _want("ucurum"):
		for x in [-1100.0, -950.0, -800.0, -650.0]:
			var foot = CN - 120.0
			await _pv("us_ucurum_%d" % int(-x), _w(x, foot), _w(x, CN + 40.0, 40.0), 7.0, 3.0)
		for x in [-900.0, -500.0, -100.0, 300.0]:
			var nn = CN + 380.0
			await _pv("us_plato_%d" % int(x), _w(x, nn), _w(x, CN + 250.0), 7.0, 3.0)
	# merdiven tepesindeki sıra ağaçlar: hangi sistemden (MultiMesh örneği -> ata düğüm adları)
	if _want("agac"):
		var cnt := {}
		var cxz = Vector2(-797.5, -558.4)
		for mmi in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = mmi.multimesh
			if mm == null or mm.mesh == null or mm.mesh.get_aabb().size.y < 4.0:
				continue
			var xf: Transform3D = mmi.global_transform
			var k2 = 0
			for i in mm.instance_count:
				var o: Vector3 = xf * mm.get_instance_transform(i).origin
				if Vector2(o.x, o.z).distance_to(cxz) < 150.0:
					k2 += 1
			if k2 > 0:
				var path = "%s/%s/%s" % [mmi.get_parent().get_parent().name if mmi.get_parent().get_parent() else "", mmi.get_parent().name, mmi.name]
				cnt[path] = int(cnt.get(path, 0)) + k2
		for k in cnt:
			print("US agac kaynak %s adet %d" % [k, cnt[k]])
	# plato uçurum kenarı: kenarı bul, platodan kenara bak (göl / park / kulübe taşması)
	if _want("kenar"):
		for x in range(-1250, 450, 150):
			var nn = CN + 700.0
			var edge = -1.0
			while nn > CN - 100.0:
				if _w(x, nn).y - _w(x, nn - 12.0).y > 15.0:
					edge = nn
					break
				nn -= 4.0
			if edge < 0.0:
				continue
			await _pv("us_kenar_%d" % (x + 2000), _w(x, edge + 30.0), _w(x, edge - 5.0, -3.0), 7.0, 3.5)
	# sur uçları
	if _want("sur"):
		for sg in [1.0, -1.0]:
			var ar = deg_to_rad(37.0 * sg)
			var jp = Vector2(R * sin(ar), R * cos(ar))
			var inw = -jp.normalized()
			var side2 = Vector2(-inw.y, inw.x) * sg
			await _pv("us_sur_%s" % ("dogu" if sg > 0 else "bati"), _w(jp.x + inw.x * 60.0 - side2.x * 30.0, jp.y + inw.y * 60.0 - side2.y * 30.0), _w(jp.x, jp.y, 10.0), 7.0, 3.0)
	# Suna hastanesi
	if _want("suna"):
		var sv = Game.village("suna")
		var hp: Vector2 = BuildVillageStory._sites(sv)["hospital"]
		var rec = Game.world.find_child("VillageStream", true, false).request("suna")
		main.player.global_position = Vector3(hp.x, Game.terrain_height(hp.x, -hp.y) + 2.0, -hp.y)
		var t0 = Time.get_ticks_msec()
		while not rec["done"] and Time.get_ticks_msec() - t0 < 90000:
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(4.0).timeout
		var hn = null
		for n in get_tree().root.find_children("Story_suna_hastane*", "", true, false):
			hn = n
		for k in 4:
			var a = TAU * k / 4.0 + 0.4
			var c3 = Vector3(hp.x, 0, -hp.y)
			var p3 = c3 + Vector3(cos(a), 0, sin(a)) * 34.0
			p3.y = Game.terrain_height(p3.x, p3.z)
			var lk = c3; lk.y = Game.terrain_height(c3.x, c3.z) + 8.0
			await _pv("us_suna_hastane_%d" % k, p3, lk, 5.0, 3.0)
		await _pv("us_suna_hastane_ust", Vector3(hp.x, Game.terrain_height(hp.x, -hp.y) + 60.0, -hp.y + 50.0), Vector3(hp.x, Game.terrain_height(hp.x, -hp.y), -hp.y), 1.0, 0.0)
		print("US suna hastane merkez yol uzakligi %.1f" % Game.road_dist(hp.x, -hp.y))
	get_tree().quit()
