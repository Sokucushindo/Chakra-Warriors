extends Node
## Köyler arası görevler oyunda: kaçırılan varis (gerçek kaçıran + bağlı rehine), barış elçisi (yürür, pusuda karşı köyün
## ninjaları), cephe (küçük ülkede düşman karakolu, o köyün gerçek ninjaları)
var main: Node

func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/wrel"))
	im.save_png("res://../_tmp/wrel/%s.png" % name)

func _foes(at: Vector3, r: float) -> Array:
	return get_tree().get_nodes_in_group("fighters").filter(func(e): return is_instance_valid(e) and e is Enemy and not e.dead and e.global_position.distance_to(at) < r)

func _say(tag: String, at: Vector3) -> void:
	for e in _foes(at, 90.0):
		var wp = WorldPeople.get_p(String(e.get_meta("world_person", "")))
		print("WREL2 %s dusman %s koy=%s gercek=%s" % [tag, String(e.arch.get("name", e.name)), String(wp.get("village", "?")), str(not wp.is_empty())])

func _mis(kind: String, foe: String, extra := {}) -> Dictionary:
	WorldNews.D()["list"] = []
	WorldRelations._post(kind, "konoha", foe, extra)
	return WorldNews.mission_for(WorldNews.D()["list"][0])

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	await main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	Game.profile["level"] = 120
	pl.max_hp = 99999.0
	pl.hp = pl.max_hp
	# A) kaçırılan varis: kaçıranla karşılaşma adımı
	var km = _mis("kidnap", "kumo")
	var kp = WorldPeople.get_p(String(WorldNews.D()["list"][0].get("kidnapper", "")))
	print("WREL2 kacirma %s kaciran=%s (%s)" % [String(km.get("title", "-")), String(kp.get("name", "?")), String(kp.get("village", "?"))])
	km["steps"] = (km["steps"] as Array).slice(2)
	Missions.accept(km)
	await _w(1.0)
	var at = Game.from_map(Vector2(float(km["steps"][0]["at"][0]), float(km["steps"][0]["at"][1])))
	pl.respawn(at + Vector3(0, 1.0, 9.0))
	await _w(5.0)
	_say("kacirma", at)
	print("WREL2 kacirma yer koy=%s" % WorldDay.village_of(at))
	print("WREL2 kacirma npcs=%s adim=%s" % [str(Missions.npcs.keys()), str(Missions._cur().get("kind", "-"))])
	var h = Missions.npcs.get("rehine")
	print("WREL2 kacirma rehine=%s ad=%s" % [str(h != null and is_instance_valid(h)), String(h.display) if h != null and is_instance_valid(h) else "-"])
	pl.look_at(at + Vector3(0, 1, 0))
	await _shot("kacirma")
	Missions.abandon()
	await _w(1.5)
	# B) barış elçisi: elçiyle konuş, yürüsün, pusu
	var em = _mis("envoy", "kiri")
	Missions.accept(em)
	await _w(1.0)
	var st0 = Game.from_map(Vector2(float(em["steps"][0]["at"][0]), float(em["steps"][0]["at"][1])))
	pl.respawn(st0 + Vector3(0, 1.0, 4.0))
	await _w(3.0)
	var env = Missions.npcs.get("eskort")
	print("WREL2 elci npc=%s ad=%s" % [str(env != null and is_instance_valid(env)), String(env.display) if env != null and is_instance_valid(env) else "-"])
	if env != null and is_instance_valid(env):
		Missions._after_talk(env, Missions._cur())
		await _w(1.0)
		Hud.close_dialog()
		await _w(2.0)
		print("WREL2 elci mod=%s yol=%d" % [String(env.mode), env.path.size()])
		if env.path.is_empty():
			Missions.abandon()
			print("WREL2 elci yol yok")
			get_tree().quit()
			return
		env.path_i = int(env.path.size() * 0.45)
		env.global_position = Missions.open_ground(env.path[env.path_i], 10.0)
		pl.respawn(env.global_position + Vector3(0, 1.0, 5.0))
		await _w(4.0)
		_say("elci_pusu", env.global_position)
		await _shot("elci_pusu")
	Missions.abandon()
	await _w(1.5)
	# C) cephe: Iwa ile savaşta, küçük ülkedeki karakol
	if not WorldRelations.at_war("konoha", "iwa"):
		WorldRelations.declare_war("konoha", "iwa")
	Hud.close_dialog()
	var fm = _mis("front", "iwa")
	print("WREL2 cephe %s" % String(fm.get("title", "-")))
	fm["steps"] = (fm["steps"] as Array).slice(1)
	Missions.accept(fm)
	await _w(1.0)
	var cs = Missions._cur()
	var fa = Game.from_map(Vector2(float(cs["at"][0]), float(cs["at"][1])))
	pl.respawn(fa + Vector3(0, 1.0, 14.0))
	await _w(6.0)
	cs = Missions._cur()
	fa = Game.from_map(Vector2(float(cs["at"][0]), float(cs["at"][1])))
	_say("cephe", fa)
	pl.look_at(fa + Vector3(0, 1, 0))
	await _shot("cephe")
	Missions.abandon()
	print("WREL2 bitti")
	get_tree().quit()
