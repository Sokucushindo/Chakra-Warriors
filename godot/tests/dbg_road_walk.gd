extends Node
## Yol NPC'leri: gezen takım yolun üstünde mi yürüyor; olayı biten tüccar yola çıkıp yürüyor mu (yola uzaklık ölçümü)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _road_d(p: Vector3) -> float:
	var m = Vector2(p.x, -p.z)
	var best := 9999.0
	for e in Game.road_segments_near(m, 300.0):
		var pts: PackedVector2Array = Game.roads[e.x]["pts"]
		if Game.roads[e.x]["kind"] != "road":
			continue
		best = minf(best, Geometry2D.get_closest_point_to_segment(m, pts[e.y], pts[e.y + 1]).distance_to(m))
	return best
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pl = main.player
	# köy dışında bir yol noktası bul
	var v = Game.village("konoha")
	var vc = Vector2(float(v["x"]), float(v["y"]))
	var spot = Vector2.INF
	for rl in Game.roads:
		if rl["kind"] != "road":
			continue
		for q in rl["pts"]:
			var d = (q as Vector2).distance_to(vc)
			if d > float(v["r"]) + 500.0 and d < float(v["r"]) + 1400.0:
				spot = q
				break
		if spot != Vector2.INF:
			break
	var w = Game.from_map(spot)
	pl.respawn(Vector3(w.x + 6.0, Game.ground_height(w.x, w.z) + 1.0, w.z + 6.0))
	await _w(6.0)
	print("YOLW oyuncunun yola uzaklığı ", snappedf(_road_d(pl.global_position), 0.1))
	var at = get_tree().current_scene.get_node_or_null("AmbientTeams")
	if at == null:
		at = get_tree().current_scene.find_child("AmbientTeams", true, false)
	for tm in at.teams.duplicate():
		for n in tm["nodes"]:
			if is_instance_valid(n):
				n.queue_free()
	at.teams.clear()
	at.t = 999.0
	await at._spawn(pl.global_position)
	print("YOLW takım sayısı ", at.teams.size(), " rota noktası ", (at.teams[0].get("path", []) as Array).size() if at.teams.size() > 0 else -1)
	if at.teams.size() > 0:
		var lead = at.teams[0]["nodes"][0]
		var cam = Camera3D.new()
		main.add_child(cam)
		for i in 8:
			await _w(3.0)
			if not is_instance_valid(lead):
				break
			var ds = []
			for n in at.teams[0]["nodes"] if at.teams.size() > 0 else []:
				if is_instance_valid(n):
					ds.append(snappedf(_road_d(n.global_position), 0.1))
			print("YOLW takım t=", (i + 1) * 3, " sn yola uzaklık ", ds, " lider-oyuncu ", snappedf(lead.global_position.distance_to(pl.global_position), 1), " anim=", lead.model.current)
			if i == 3:
				cam.global_position = lead.global_position + Vector3(9, 7, 9)
				cam.look_at(lead.global_position + Vector3.UP)
				cam.make_current()
				await _w(0.3)
				get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/yolw_takim.png")
		cam.queue_free()
	# olay: tüccar kurtarıldı → yola çıkıp yürümeli
	var c = pl.global_position + Vector3(45, 0, 30)
	c.y = Game.ground_height(c.x, c.z)
	Encounters.cur = {"kind": "merchant", "nodes": [], "t": 0.0, "center": c}
	Encounters._start_merchant(c)
	await _w(2.0)
	var m = Encounters.cur["npc"]
	for e in Encounters.cur["foes"]:
		if is_instance_valid(e):
			e.queue_free()
	m.mode = "idle"
	var p0: Vector3 = m.global_position
	print("YOLW tüccar başta yola uzaklık ", snappedf(_road_d(p0), 0.1))
	Encounters.finish()
	for i in 8:
		await _w(4.0)
		if not is_instance_valid(m):
			print("YOLW tüccar silindi t=", (i + 1) * 4)
			break
		if i == 4:
			var col = m.get_last_slide_collision()
			print("YOLW TEŞHİS konum ", m.global_position, " hız ", m.velocity, " duvarda=", m.is_on_wall(), " normal=", m.get_wall_normal(), " çarpan=", (str(col.get_collider()) + " " + str(col.get_collider().get_parent())) if col else "yok", " sıradaki nokta uzaklık ", snappedf(m.global_position.distance_to(m.path[m.path_i]), 0.1) if m.path_i < m.path.size() else -1, " nav=", m.nav, " zemin=", Game.ground_height(m.global_position.x, m.global_position.z), " arazi=", Game.terrain_height(m.global_position.x, m.global_position.z))
			var cam2 = Camera3D.new()
			main.add_child(cam2)
			cam2.global_position = m.global_position + Vector3(8, 6, 8)
			cam2.look_at(m.global_position + Vector3.UP)
			cam2.make_current()
			await _w(0.3)
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/yolw_tuccar.png")
			cam2.queue_free()
		print("YOLW tüccar t=", (i + 1) * 4, " sn mod=", m.mode, " yola uzaklık ", snappedf(_road_d(m.global_position), 0.1), " gittiği yol ", snappedf(m.global_position.distance_to(p0), 0.1), " anim=", m.model.current)
	get_tree().quit()
