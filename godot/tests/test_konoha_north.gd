extends Node
## 2026-11-27 Konoha kuzey düzeltmeleri: sur-kaya birleşimi, su kapısı parmaklığı + göller, seyir terası, merdiven yolu,
## uçurum yüzü, kanal-yol köprüleri, köprüde adım sesi. Satırlar "KN"; görüntüler --shots.
var main: Node
var cam: Camera3D
const VX := -500.0
const VY := -750.0
const CN := 1170.0


func _w(x: float, n: float, dy := 0.0) -> Vector3:
	var p = Vector3(VX + x, 0, -(VY + n))
	p.y = Game.terrain_height(p.x, p.z) + dy
	return p


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	cam.make_current()
	main.player.global_position = Vector3(to.x, Game.terrain_height(to.x, to.z) + 1.0, to.z) + (from - to).normalized() * 8.0
	await get_tree().create_timer(1.2).timeout
	await main.shot(name)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Cheats.set_time(11.0)
	if Hud.get("root"):
		Hud.root.visible = false
	cam = Camera3D.new()
	cam.far = 5000.0
	add_child(cam)
	var R = BuildKonoha.R
	var space = main.player.get_world_3d().direct_space_state
	# 1) sur-kaya birleşimi: kuzey boşluğunun iki ucu
	for sg in [1.0, -1.0]:
		var a = 0.0
		while a < 90.0:
			var ar = deg_to_rad(a * sg)
			if Game.terrain_height(VX + R * sin(ar), -(VY + R * cos(ar))) - 8.0 < BuildKonoha.WALL_H * 0.6:
				break
			a += 0.3
		var ar2 = deg_to_rad(a * sg)
		var jp = Vector2(R * sin(ar2), R * cos(ar2))
		var inward = -jp.normalized()
		var tgt = _w(jp.x, jp.y, 10.0)
		await _shot("kn_sur_kaya_%s_ic" % ("dogu" if sg > 0 else "bati"), _w(jp.x + inward.x * 90.0, jp.y + inward.y * 90.0, 25.0), tgt)
		await _shot("kn_sur_kaya_%s_yuk" % ("dogu" if sg > 0 else "bati"), _w(jp.x + inward.x * 150.0, jp.y + inward.y * 150.0, 120.0), tgt)
		await _shot("kn_sur_kaya_%s_dis" % ("dogu" if sg > 0 else "bati"), _w(jp.x - inward.x * 80.0, jp.y - inward.y * 80.0, 25.0), tgt)
		print("KN sur ucu %s: %.1f° yerel %s" % ["dogu" if sg > 0 else "bati", a, str(jp)])
	# 2) su kapıları + göller
	var gi = 0
	for d in [Vector2(-900, -1150), Vector2(720, -1270)]:
		var dn = d.normalized()
		var gp = dn * R
		var tg = _w(gp.x, gp.y, 6.0)
		await _shot("kn_sukapisi_%d_ic" % gi, _w(gp.x - dn.x * 45.0, gp.y - dn.y * 45.0, 8.0), tg)
		await _shot("kn_sukapisi_%d_dis" % gi, _w(gp.x + dn.x * 45.0, gp.y + dn.y * 45.0, 8.0), tg)
		var pc = dn * (R + 62.0 + (26.0 if gi == 0 else 18.0) * 0.8)
		await _shot("kn_gol_%d" % gi, _w(pc.x + dn.x * 70.0, pc.y + dn.y * 70.0, 30.0), _w(pc.x, pc.y))
		# parmaklıktan geçilebiliyor mu: kapı merkezinde surun içinden dışına yatay ışın
		var a3 = _w(gp.x - dn.x * 6.0, gp.y - dn.y * 6.0, 1.2)
		var b3 = _w(gp.x + dn.x * 6.0, gp.y + dn.y * 6.0, 1.2)
		var h = space.intersect_ray(PhysicsRayQueryParameters3D.create(a3, b3, 1))
		print("KN su kapisi %d parmaklik engel=%s su_seviyesi_gol=%.2f zemin=%.2f" % [gi, not h.is_empty(), Game.water_level(_w(pc.x, pc.y).x, _w(pc.x, pc.y).z, -100.0), _w(pc.x, pc.y).y])
		gi += 1
	if OS.get_environment("KN_QUICK") != "":
		get_tree().quit()
		return
	# 3) seyir terası (Hokage yüzlerinin üstü, x=0)
	var edge = CN + 35.0
	var nn = CN
	while nn < CN + 450.0:
		var hh = _w(0, nn).y - 8.0
		if hh > 165.0 - 14.0 and absf(_w(0, nn + 4.0).y - _w(0, nn).y) / 4.0 < 0.35:
			edge = nn
			break
		nn += 2.0
	print("KN teras kenari n=%.0f" % edge)
	await _shot("kn_teras_arka", _w(0, edge + 60.0, 25.0), _w(0, edge + 5.0))
	await _shot("kn_teras_yan", _w(45.0, edge + 10.0, 12.0), _w(0, edge + 5.0))
	await _shot("kn_teras_koyden", _w(0, CN - 160.0, 60.0), _w(0, edge, 0.0))
	var rq = space.intersect_ray(PhysicsRayQueryParameters3D.create(_w(5.0, edge + 4.0, 1.0), _w(5.0, edge - 6.0, 1.0) + Vector3(0, _w(5.0, edge + 4.0).y - _w(5.0, edge - 6.0).y, 0), 1))
	print("KN teras on korkuluk engel=%s" % [not rq.is_empty()])
	# 4) merdiven yolu
	for ri in Game.roads.size():
		var rd: Dictionary = Game.roads[ri]
		if rd.has("ys"):
			var bad = 0; var n_st = 0
			for k in (rd["pts"] as PackedVector2Array).size():
				var y = float(rd["ys"][k])
				if is_nan(y):
					continue
				n_st += 1
				var m: Vector2 = rd["pts"][k]
				var hq = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(m.x, y + 2.0, -m.y), Vector3(m.x, y - 3.0, -m.y), 1))
				if hq.is_empty() or absf(hq["position"].y - y) > 1.6:
					bad += 1
			print("KN merdiven yolu %d (%s->%s): merdiven noktasi %d, basamak tutmayan %d, boyanmayan parca %d" % [ri, rd["a"], rd["b"], n_st, bad, rd["nopaint"].size()])
	await _shot("kn_merdiven", _w(-285.0, CN - 120.0, 40.0), _w(-285.0, CN + 10.0, 60.0))
	await _shot("kn_ucurum_eski_yol", _w(250.0, CN - 150.0, 50.0), _w(250.0, CN + 20.0, 60.0))
	await _shot("kn_ucurum_tepe", _w(250.0, CN + 420.0, 40.0), _w(250.0, CN + 300.0, 0.0))
	# 6) kanal-yol kesişimleri: köprü tabliyesi var mı
	var crosses = 0; var nobr = 0
	var cans = [[Vector2(-640, CN - 14.0), Vector2(-700, 960), Vector2(-705, 790), Vector2(-655, 640), Vector2(-600, 470), Vector2(-520, 330), Vector2(-430, 170), Vector2(-380, 0), Vector2(-380, -180), Vector2(-405, -360), Vector2(-520, -520), Vector2(-680, -700), Vector2(-770, -900), Vector2(-860, -1080)],
		[Vector2(1124, 500), Vector2(1135, 380), Vector2(1090, 220), Vector2(1000, 40), Vector2(930, -180), Vector2(900, -420), Vector2(840, -620), Vector2(800, -850), Vector2(760, -1060)]]
	for cpts in cans:
		for i in cpts.size() - 1:
			var A: Vector2 = cpts[i] + Vector2(VX, VY)
			var B: Vector2 = cpts[i + 1] + Vector2(VX, VY)
			for e in Game.road_segments_near((A + B) * 0.5, A.distance_to(B)):
				var rd2: Dictionary = Game.roads[e.x]
				var hit = Geometry2D.segment_intersects_segment(A, B, rd2["pts"][e.y], rd2["pts"][e.y + 1])
				if hit == null:
					continue
				crosses += 1
				var top = Game.terrain_height(hit.x, -hit.y)
				var hb = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(hit.x, top + 3.0, -hit.y), Vector3(hit.x, top - 1.0, -hit.y), 1))
				var ok = not hb.is_empty() and hb["position"].y > Game.water_level(hit.x, -hit.y, top) + 0.1
				if not ok:
					nobr += 1
					if nobr <= 3:
						await _shot("kn_kopru_yok_%d" % nobr, Vector3(hit.x + 18.0, top + 9.0, -hit.y + 18.0), Vector3(hit.x, top, -hit.y))
				print("KN kanal-yol kesisim %s tur=%s kopru=%s ses=%s" % [str(hit), rd2["kind"], ok, Game.step_sound(Vector3(hit.x, (hb["position"].y if not hb.is_empty() else top) + 0.05, -hit.y))])
	print("KN kanal-yol kesisim toplam %d, koprusuz %d" % [crosses, nobr])
	# 8) ANBU av ekibi kıyafeti (Konoha kaçağı)
	Game.profile["flags"] = Game.profile.get("flags", {})
	Game.profile["flags"]["rogue_from"] = "konoha"
	var hs = Orgs.hunters_at(main.player.global_position, 30.0)
	for e in hs:
		var lk: Dictionary = e.arch["look"] if e.get("arch") else {}
		print("KN av ekibi %s yuz=%s yelek=%s ust=%s set=%s koy=%s" % [e.display_name, lk.get("face_style"), str(lk.get("vest")), str(lk.get("top")), lk.get("set_id", ""), lk.get("village")])
		e.queue_free()
	# 9) Mangekyō tarzı süzgeci
	var en = Enemy.new()
	en.setup(Enemy.archetype("rogue", 0))
	get_tree().current_scene.add_child(en)
	for st in ["itachi", "obito", "kakashi", "sasuke"]:
		en.set_meta("eyes", {"kind": 4})
		en.set_meta("ms_style", st)
		en.remove_meta("kamui_user")
		print("KN MS %s: amaterasu=%s kamui=%s tsukuyomi=%s susanoo=%s" % [st, en._ms_ok("amaterasu"), en._ms_ok("kamui"), en._ms_ok("tsukuyomi"), en._ms_ok("susanoo")])
	en.queue_free()
	get_tree().quit()
