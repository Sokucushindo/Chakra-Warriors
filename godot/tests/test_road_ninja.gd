extends Node
## Yoldaki ninja kafilesi: kaçak değilken konuşur, kaçağı görünce saldırır (aynı görünüşle gerçek savaşçı olur)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _enemies() -> Array:
	return get_tree().get_nodes_in_group("fighters").filter(func(e): return is_instance_valid(e) and e is Enemy and e.has_meta("faction") and not e.is_dead())
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.2, 0.2, 0.3)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9
	# köy dışında bir yol noktası
	var vs = Game.village("konoha")
	var c = Vector2(float(vs["x"]), float(vs["y"]))
	var best = null
	for e in Game.road_segments_near(c, float(vs["r"]) + 900.0):
		var rl: Dictionary = Game.roads[e.x]
		if rl["kind"] != "road":
			continue
		var q: Vector2 = (rl["pts"][e.y] as Vector2).lerp(rl["pts"][e.y + 1], 0.5)
		if q.distance_to(c) > float(vs["r"]) + 250.0:
			best = e; break
	if best == null:
		print("RN yol bulunamadı"); get_tree().quit(); return
	var tr = Game.world.get_node("RoadTraffic")
	var scr = tr.get_script()
	var g = scr.TravelGroup.new()
	g.road = best.x; g.seg = best.y; g.t = 0.5; g.dir = 1; g.kind = "ninja"
	var mq: Vector2 = (Game.roads[best.x]["pts"][best.y] as Vector2).lerp(Game.roads[best.x]["pts"][best.y + 1], 0.5)
	pl.respawn(Game.from_map(mq) + Vector3(0, 0.5, 0))
	await _w(2.0)
	Hud.close_dialog()
	tr.add_child(g)
	var t0 = Time.get_ticks_msec()
	while g.members.size() < 2 and Time.get_ticks_msec() - t0 < 15000:
		await _w(0.3)
	print("RN kafile uye=%d koy=%s gorunus=%d" % [g.members.size(), g.vid, g.looks.size()])
	var before = _enemies().size()
	pl.global_position = g.members[0][0].global_position + Vector3(1.5, 0.3, 0)
	await _w(2.0)
	print("RN kacak degil: dusman +%d, avlar=%s" % [_enemies().size() - before, g._hunts_rogue()])
	g.talk(); await _w(0.3)
	print("RN konusma yapildi"); Hud.close_dialog()
	Orgs.flags()["rogue"] = true
	Orgs.flags()["rogue_from"] = "konoha"
	pl.global_position = g.members[0][0].global_position + Vector3(-sin(g.members[0][0].rotation.y), 0.1, -cos(g.members[0][0].rotation.y)) * 12.0
	t0 = Time.get_ticks_msec()
	while _enemies().size() == before and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	var es = _enemies()
	print("RN kacak: dusman +%d, %.2f sn" % [es.size() - before, (Time.get_ticks_msec() - t0) / 1000.0])
	await _w(1.0)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/road_ninja.png")
	pl.max_hp = 3000; pl.hp = 3000
	await _w(8.0)
	for e in _enemies():
		print("RN  %s guc=%s durum=%s hedef=%s mesafe=%.1f" % [e.display_name if "display_name" in e else e.name, e.level, e.state, e.target == pl, e.global_position.distance_to(pl.global_position)])
	print("RN oyuncu can %.0f/3000 | kafile silindi=%s" % [pl.hp, not is_instance_valid(g) or g.is_queued_for_deletion()])
	get_tree().quit()
