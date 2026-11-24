extends Node
## Köyler arası ilişkiler (WorldRelations): kanon başlangıç, dünya turları (olay / savaş / ittifak / ateşkes, gerçek ölümler),
## her ilan türünün görevi kurulur mu, sınır karakolu görevinde karşına o köyün gerçek ninjaları çıkar mı, Kage masası diplomasi.
var main: Node

func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/wrel"))
	im.save_png("res://../_tmp/wrel/%s.png" % name)

func _pairs() -> String:
	var out = []
	for k in WorldRelations.D()["pairs"]:
		var ab = String(k).split("|")
		out.append("%s=%d(%s)" % [k, int(WorldRelations.D()["pairs"][k]), WorldRelations.state(ab[0], ab[1])])
	return " ".join(out)

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	await main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	var pl = main.player
	for i in 20:
		if WorldPeople.data().get("init", false):
			break
		await _w(0.5)
	print("WREL init kisi=%d" % WorldPeople.all().size())
	print("WREL baslangic: " + _pairs())
	for v in WorldRelations.GREAT:
		print("WREL lider %s %s mizac=%s" % [v, Kage.kage_name(v), str(WorldRelations.leader(v))])
	# 1) dünya turları: ilanları kimse almaz (köyün takımı gider)
	var alive0 = WorldPeople.all().values().filter(func(p): return WorldPeople.alive(p)).size()
	var wars = 0
	var kinds = {}
	for t in 60:
		var w0 = (WorldRelations.D()["war"] as Dictionary).size()
		WorldRelations.turn()
		if (WorldRelations.D()["war"] as Dictionary).size() > w0:
			wars += 1
		for inc in WorldNews.D()["list"]:
			if String(inc["state"]) == "open" and inc.has("foe"):
				kinds[String(inc["kind"])] = int(kinds.get(String(inc["kind"]), 0)) + 1
				inc["left"] = 0.0
		WorldNews.tick(0.01)
	var alive1 = WorldPeople.all().values().filter(func(p): return WorldPeople.alive(p)).size()
	print("WREL 60 tur: savas_ilani=%d suren=%s olen=%d ilan_turleri=%s" % [wars, str((WorldRelations.D()["war"] as Dictionary).keys()), alive0 - alive1, str(kinds)])
	print("WREL anlasmalar: %s" % str(WorldRelations.D()["pact"]))
	print("WREL son: " + _pairs())
	for h in WorldRelations.recent():
		print("WREL haber: " + String(h))
	# 1b) zorla gerilim: Kiri–Suna −70 -> savaş, muharebeler, ateşkes
	WorldRelations.D()["pairs"][WorldRelations.key("kiri", "suna")] = -70
	for t in 30:
		WorldRelations.turn()
		for inc in WorldNews.D()["list"]:
			inc["left"] = 0.0
		WorldNews.tick(0.01)
		var wk = WorldRelations.key("kiri", "suna")
		if t < 6:
			print("WREL   son haber: " + String(WorldRelations.recent()[0]) + " | " + String(WorldRelations.recent()[1]))
		if t % 3 == 0:
			print("WREL kiri-suna tur %d: iliski=%d durum=%s savas=%s" % [t, WorldRelations.rel("kiri", "suna"), WorldRelations.state("kiri", "suna"), str(WorldRelations.D()["war"].get(wk, {}))])
	for h in WorldRelations.recent().slice(0, 8):
		print("WREL haber2: " + String(h))
	print("WREL hakimiyet: %s" % str(WorldRelations.D()["sway"]))
	# 1c) büyük–küçük: Konoha–Oto savaşı (cephe Oto'nun kendisi)
	var oto0 = WorldPeople.all().values().filter(func(p): return String(p["village"]) == "oto" and WorldPeople.alive(p)).size()
	WorldRelations.D()["pairs"][WorldRelations.key("konoha", "oto")] = -80
	for t in 25:
		WorldRelations.turn()
		for inc in WorldNews.D()["list"]:
			inc["left"] = 0.0
		WorldNews.tick(0.01)
		if not WorldRelations.at_war("konoha", "oto") and t > 0 and WorldRelations.rel("konoha", "oto") > -60:
			break
	print("WREL konoha-oto: savas=%s iliski=%d oto_nufus %d->%d hakimiyet=%s" % [str(WorldRelations.at_war("konoha", "oto")), WorldRelations.rel("konoha", "oto"), oto0, WorldPeople.all().values().filter(func(p): return String(p["village"]) == "oto" and WorldPeople.alive(p)).size(), str(WorldRelations.D()["sway"])])
	for h in WorldRelations.recent().slice(0, 14):
		if "ateşkes" in String(h) or "Otogakure" in String(h) or "hakimiyet" in String(h):
			print("WREL haber3: " + String(h))
	Hud.close_dialog()
	# 2) her ilan türü görev kurar mı
	WorldNews.D()["list"] = []
	if not WorldRelations.at_war("konoha", "iwa"):
		WorldRelations.declare_war("konoha", "iwa")
	WorldRelations.set_pact("konoha", "suna", "ittifak")
	if not WorldRelations.at_war("suna", "kumo"):
		WorldRelations.declare_war("suna", "kumo")
	var posts = [["border", "kumo", {}], ["kidnap", "kumo", {}], ["envoy", "kiri", {}], ["front", "iwa", {}], ["ally", "kumo", {"ally": "suna"}], ["spy", "iwa", {}]]
	var made = {}
	for pp in posts:
		WorldNews.D()["list"] = []
		var ok = WorldRelations._post(String(pp[0]), "konoha", String(pp[1]), (pp[2] as Dictionary).duplicate())
		var inc = {}
		for x in WorldNews.D()["list"]:
			inc = x
		var m = WorldNews.mission_for(inc) if not inc.is_empty() else {}
		made[pp[0]] = m
		print("WREL ilan %s asildi=%s gorev=%s rank=%s adimlar=%s" % [pp[0], str(ok), String(m.get("title", "-")), String(m.get("rank", "-")), str((m.get("steps", []) as Array).map(func(s): return s["kind"]))])
	# 3) sınır karakolu: karşına Kumo'nun gerçek ninjaları çıkar mı
	WorldNews.D()["list"] = []
	WorldRelations._post("border", "konoha", "kumo")
	var binc = WorldNews.D()["list"][0]
	var bm = WorldNews.mission_for(binc)
	bm["steps"].pop_front()   # nöbetçiyle konuşmayı atla
	Game.profile["level"] = 120
	Missions.accept(bm)
	await _w(1.0)
	var at = Game.from_map(Vector2(float(bm["steps"][0]["at"][0]), float(bm["steps"][0]["at"][1])))
	pl.respawn(at + Vector3(0, 1.0, 8.0))
	await _w(6.0)
	var foes = get_tree().get_nodes_in_group("fighters").filter(func(e): return is_instance_valid(e) and e is Enemy and e.global_position.distance_to(at) < 80.0)
	for e in foes:
		var wp = WorldPeople.get_p(String(e.get_meta("world_person", "")))
		print("WREL karakol dusman %s koy=%s gercek=%s" % [String(e.arch.get("name", e.name)), String(wp.get("village", "?")), str(not wp.is_empty())])
	await _shot("karakol")
	var r0 = WorldRelations.rel("konoha", "kumo")
	WorldNews.new().mission_done(bm, true)
	print("WREL karakol basari: iliski %d -> %d" % [r0, WorldRelations.rel("konoha", "kumo")])
	Missions.abandon()
	await _w(1.0)
	Hud.close_dialog()
	# 4) Kage masası diplomasi (Kage olarak)
	Game.profile["rank"] = 6
	Kage.st()["funds"] = 200000
	print("WREL baris: " + Kage.diplomacy("iwa", "baris"))
	WorldRelations.D()["pairs"][WorldRelations.key("konoha", "kiri")] = -50
	print("WREL savas ilani: " + Kage.diplomacy("kiri", "savas"))
	KageDesk.open("diplomasi")
	await _w(1.0)
	await _shot("diplomasi")
	var scs = get_tree().root.find_children("*", "ScrollContainer", true, false)
	for sc in scs:
		if sc.is_visible_in_tree():
			sc.scroll_vertical = 100000
	await _w(0.5)
	await _shot("diplomasi_alt")
	Menus.ninja_menu(main, "relations")
	await _w(1.0)
	await _shot("iliskiler_menu")
	print("WREL bitti")
	get_tree().quit()
