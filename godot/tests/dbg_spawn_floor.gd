extends Node
## Doğuş / ışınlanma / Kage töreni: oyuncu ve tören kişileri gerçek zeminin üstünde mi (arazi + ışınla bulunan üst yüzey)
var main: Node
var pl


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _top(p: Vector3, up := 3.0) -> Dictionary:
	var q = PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p + Vector3.DOWN * 30.0, 1)
	q.exclude = [pl.get_rid()]
	var h = pl.get_world_3d().direct_space_state.intersect_ray(q)
	return h


func _rep(tag: String, n: Node3D) -> void:
	var p = n.global_position
	var gh = Game.ground_height(p.x, p.z)
	var h = _top(p, 2.5)
	var ty = float(h["position"].y) if not h.is_empty() else -INF
	var cn = str(h["collider"].name) if not h.is_empty() else "-"
	var cp = str(h["collider"].get_parent().name) if not h.is_empty() and h["collider"].get_parent() else "-"
	print("SPF %s: y=%.2f arazi=%.2f ust=%.2f (%s/%s) fark=%.2f zeminde=%s" % [tag, p.y, gh, ty, cn, cp, p.y - maxf(ty, gh), str(n.is_on_floor()) if n is CharacterBody3D else "-"])


func _probe(p: Vector3) -> void:
	var q = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 5.0, 0xFFFFFFFF)
	q.exclude = [pl.get_rid()]
	for i in 8:
		var h = pl.get_world_3d().direct_space_state.intersect_ray(q)
		if h.is_empty():
			break
		var c = h["collider"]
		var path = str(c.get_path()) if c is Node else str(c)
		var sh = ""
		if c is CollisionObject3D:
			sh = str(c.shape_owner_get_owner(c.shape_find_owner(int(h["shape"]))))
		print("SPF probe y=%.2f layer=%d %s %s" % [h["position"].y, c.collision_layer if c is CollisionObject3D else -1, path, sh])
		q.exclude = q.exclude + [h["rid"]]
	var q2 = PhysicsRayQueryParameters3D.create(p + Vector3.DOWN * 0.3, p + Vector3.UP * 3.0, 0xFFFFFFFF)
	q2.exclude = [pl.get_rid()]
	q2.hit_back_faces = true
	var h2 = pl.get_world_3d().direct_space_state.intersect_ray(q2)
	print("SPF probe_up ", "-" if h2.is_empty() else "%.2f n=%s %s" % [h2["position"].y, str(h2["normal"]), str(h2["collider"])])
	var q3 = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 1.0, 0xFFFFFFFF)
	q3.exclude = [pl.get_rid()]
	q3.hit_back_faces = true
	q3.hit_from_inside = true
	var h3 = pl.get_world_3d().direct_space_state.intersect_ray(q3)
	print("SPF probe_dn_inside ", "-" if h3.is_empty() else "%.2f n=%s %s" % [h3["position"].y, str(h3["normal"]), str(h3["collider"])])
	var b = pl.get_last_slide_collision()
	print("SPF slide ", b.get_collider() if b else null)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	pl = main.player
	var t0 = Time.get_ticks_msec()
	while (main.loading != null or main.mode != "game") and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	pl = main.player
	print("SPF yeni oyun basladi %.1f sn" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_rep("yeni_oyun_t0", pl)
	_probe(pl.global_position)
	for k in 4:
		await _w(0.5)
		_rep("yeni_oyun_t%d" % (k + 1), pl)
		_probe(pl.global_position)
	Hud.close_dialog()
	var env = main.world.env
	env.time_of_day = 0.45
	await main.shot("spawn_new")
	if OS.get_environment("ONLYSPAWN") != "" and OS.get_environment("ONLYHOSP") == "":
		get_tree().quit()
		return
	# hastane (ölünce)
	pl.respawn(Progress._hospital_pos())
	await _w(2.0)
	_rep("hastane", pl)
	_probe(pl.global_position)
	if OS.get_environment("ONLYHOSP") != "":
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.current = true
		cam.global_position = pl.global_position + Vector3(4.0, 0.6, 0.5)
		cam.look_at(pl.global_position + Vector3.UP * 0.5)
		await _w(0.3)
		await main.shot("spawn_hosp_side")
		get_tree().quit()
		return
	await main.shot("spawn_hosp")
	pl.respawn(Progress.home_spawn())
	await _w(2.0)
	_rep("home_spawn", pl)
	# kayıt yükleme: kaydı al, aynı yerden yeniden yükle
	if OS.get_environment("SKIPTRAVEL") == "":
		for vid in ["suna", "kumo", "konoha"]:
			if not vid in Game.profile.get("visited", []):
				Game.profile["visited"].append(vid)
			await main.fast_travel(vid)
			await _w(2.5)
			_rep("hizli_" + vid, pl)
	# Kage töreni
	Hud.close_dialog()
	Game.profile["level"] = 200
	Kage.inaugurate()
	await _w(5.0)
	_rep("toren_oyuncu", pl)
	if is_instance_valid(Ceremony.cur):
		var i = 0
		for n in Ceremony.cur.people:
			if is_instance_valid(n) and n.global_position.distance_to(pl.global_position) < 4.0:
				_rep("toren_kisi%d" % i, n)
			i += 1
	await main.shot("toren_a")
	await _w(3.0)
	await main.shot("toren_b")
	await _w(6.0)
	await main.shot("toren_c")
	get_tree().quit()
