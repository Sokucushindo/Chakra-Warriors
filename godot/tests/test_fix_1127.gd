extends Node
## 2026-11-27 düzeltmeleri: Hyūga avlu duvarı zemine iner, Suna arenasında park yok, Suna hastanesi kule, yükleme yazısı İngilizce.
## Satırlar "FIX" ile başlar; görüntüler --shots klasörüne.
var main: Node
var cam: Camera3D


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	cam.make_current()
	for i in 6:
		await get_tree().process_frame
	await main.shot(name)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Cheats.set_time(12.0)
	if Hud.get("root"):
		Hud.root.visible = false
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	var pl = main.player
	# 1) yükleme yazısı
	var old_lang = Game.lang()
	Lang.apply("en")
	print("FIX yukleme Ormanlar -> ", Lang.t("Ormanlar"), " | Köyler -> ", Lang.t("Köyler"), " | kuruluyor -> ", Lang.t("%s kuruluyor") % "Suna")
	Lang.apply(old_lang)
	# 2) Konoha su kapıları (Naka Nehri güneybatı, doğu deresi güneydoğu): içeriden ve dışarıdan
	var kv = Game.village("konoha")
	var vx = float(kv["x"]); var vy = float(kv["y"])
	var R = BuildKonoha.R
	var gi = 0
	for d in [Vector2(-900, -1150), Vector2(720, -1270)]:
		var a = atan2(d.x, d.y)
		for side in [["ic", R - 70.0], ["dis", R + 70.0]]:
			var rr: float = side[1]
			var cp = Vector2(vx + sin(a) * rr, vy + cos(a) * rr)
			var gp = Vector2(vx + sin(a) * R, vy + cos(a) * R)
			var gy = Game.terrain_height(gp.x, -gp.y)
			pl.global_position = Vector3(cp.x, Game.terrain_height(cp.x, -cp.y) + 1.0, -cp.y)
			await get_tree().create_timer(2.5).timeout
			await _shot("fix_sukapisi_%d_%s" % [gi, side[0]], Vector3(cp.x, Game.terrain_height(cp.x, -cp.y) + 6.0, -cp.y), Vector3(gp.x, gy + 6.0, -gp.y))
		gi += 1
	# 3) Suna: köyü kur, arena + hastane
	var sv = Game.village("suna")
	var sites = BuildVillageStory._sites(sv)
	var hp: Vector2 = sites["hospital"]
	pl.global_position = Vector3(hp.x, Game.terrain_height(hp.x, -hp.y) + 2.0, -hp.y + 40.0)
	var vs = Game.world.find_child("VillageStream", true, false)
	var rec = vs.request("suna")
	var t0 = Time.get_ticks_msec()
	while not rec["done"] and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(6.0).timeout
	print("FIX suna kuruldu=", rec["done"], " sure ", Time.get_ticks_msec() - t0, " ms")
	var parks: Array = CityLandscape.parks_by.get("suna", [])
	var bad := 0
	for k in BuildSites._site_clear(sv):
		for p in parks:
			if (p as Vector2).distance_to(Vector2(k[0], k[1])) < float(k[2]):
				bad += 1
	print("FIX suna park sayisi=%d, onemli yapi alaninda park=%d" % [parks.size(), bad])
	var sp: Vector2 = sites["stadium"]
	var sg = Game.terrain_height(sp.x, -sp.y)
	await _shot("fix_suna_arena", Vector3(sp.x + 30.0, sg + 22.0, -sp.y + 30.0), Vector3(sp.x - 10.0, sg, -sp.y - 10.0))
	await _shot("fix_suna_arena_top", Vector3(sp.x, sg + 110.0, -sp.y + 20.0), Vector3(sp.x, sg, -sp.y))
	var hg = Game.terrain_height(hp.x, -hp.y)
	# hastane: ön (yerel -n = dünya +z), yan, yakın arma
	await _shot("fix_suna_hosp_front", Vector3(hp.x + 8.0, hg + 9.0, -hp.y + 52.0), Vector3(hp.x, hg + 14.0, -hp.y))
	await _shot("fix_suna_hosp_side", Vector3(hp.x - 50.0, hg + 12.0, -hp.y + 22.0), Vector3(hp.x, hg + 14.0, -hp.y))
	await _shot("fix_suna_hosp_back", Vector3(hp.x + 30.0, hg + 20.0, -hp.y - 45.0), Vector3(hp.x, hg + 14.0, -hp.y))
	await _shot("fix_suna_hosp_door", Vector3(hp.x + 3.0, hg + 3.0, -hp.y + 26.0), Vector3(hp.x, hg + 4.0, -hp.y))
	# hastane kapısı etkileşimi
	var found = false
	for it in Interact.items:
		if String(it.get("label", "")).contains("Hastanesi") and Vector2(it["pos"].x, it["pos"].z).distance_to(Vector2(hp.x, -hp.y)) < 30.0:
			found = true
			print("FIX hastane kapisi ", it["label"], " uzaklik ", Vector2(it["pos"].x, it["pos"].z).distance_to(Vector2(hp.x, -hp.y)))
	print("FIX hastane kapisi bulundu=", found)
	get_tree().quit()
