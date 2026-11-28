extends Node
## Gedō Mazō: çağır -> kendi yürür / ezer / kükrer -> [F] bin -> yönet -> in
var main: Node
var n := 0
var cam: Camera3D
var gref: Node3D
func _process(_dt: float) -> void:
	if cam and cam.current and gref and is_instance_valid(gref):
		var fw: Vector3 = gref.forward()
		var side = fw.cross(Vector3.UP)
		cam.global_position = gref.global_position + side * 190.0 + fw * 60.0 + Vector3.UP * 45.0
		cam.look_at(gref.global_position + fw * 15.0 + Vector3.UP * 45.0)
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _shot(tag: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/g2_%s.png" % tag)
func _foe(at: Vector3, i: int) -> Enemy:
	var a = Enemy.archetype(["kumo", "kiri", "iwa", "suna"][i % 4], i)
	a["respawn"] = false
	a["no_world"] = true
	Stats.npc_ninja(a, 60, 1.0)
	var e = Enemy.new()
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = Game.jutsu_floor_at(at) + Vector3.UP * 0.2
	e.home = e.global_position
	return e
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.2, 0.2, 0.3)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9
	var vs = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(vs["x"]) + float(vs["r"]) + 700.0, float(vs["y"]))) + Vector3(0, 1, 0))
	await _w(12.0)
	Hud.close_dialog()
	var GW = LazyFx.g("GedoWalker")
	var fd: Vector3 = pl.face_dir()
	var foes = []
	for i in 6:
		foes.append(_foe(pl.global_position + fd * (150.0 + i * 12.0) + fd.cross(Vector3.UP) * (i - 2.5) * 14.0, i))
	await _shot("once")
	PathJutsu.cast_path(pl, "kuchiyose_gedo_mazo", null)
	await _w(0.3)
	var gg = get_tree().get_nodes_in_group("gedo_mazo")[0]
	cam = Camera3D.new()
	add_child(cam)
	cam.far = 6000.0
	cam.fov = 55.0
	cam.current = true
	gref = gg
	await _w(0.9)
	await _shot("cikis1")
	await _w(1.0)
	await _shot("cikis2")
	await _w(1.6)
	var w = GW.active
	var g = w.g
	await _w(3.0)
	var low = 1e9
	for q in g.sole_points():
		low = minf(low, q.y - Game.jutsu_floor_at(q).y)
	print("G2 yururken en alcak taban - zemin = %.2f m" % low)
	await _shot("ayak")
	await _w(4.0)
	var GS = LazyFx.g("GiantSteps")
	print("G2 ayak izi sayisi=%d" % GS._prints.size())
	var c3 = Camera3D.new()
	add_child(c3)
	c3.far = 6000.0
	c3.fov = 50.0
	var lp: Vector3 = GS._prints[-2].global_position
	c3.global_position = lp - g.forward() * 22.0 + Vector3.UP * 26.0
	c3.look_at(lp)
	c3.current = true
	await _w(0.3)
	await _shot("iz")
	c3.queue_free()
	cam.current = true
	for nm in ([] if OS.get_environment("KISA") != "" else ["sweep", "stomp", "dragon", "chain"]):
		var t0 = Time.get_ticks_msec()
		while w.act != "" and Time.get_ticks_msec() - t0 < 5000:
			await _w(0.1)
		var hp0 = 0.0
		for e in foes:
			if is_instance_valid(e) and not e.is_dead(): hp0 += e.hp
		w._start(nm)
		await _w(0.8)
		await _shot(nm + "1")
		await _w(0.3)
		await _shot(nm + "2")
		await _w(1.6)
		var hp1 = 0.0
		for e in foes:
			if is_instance_valid(e) and not e.is_dead(): hp1 += e.hp
		print("G2 %s: dusman can %.0f -> %.0f" % [nm, hp0, hp1])
	low = 1e9
	for q in g.sole_points():
		low = minf(low, q.y - Game.jutsu_floor_at(q).y)
	print("G2 sonda taban - zemin = %.2f m" % low)
	pl.global_position = Game.jutsu_floor_at(g.global_position + g.forward().cross(Vector3.UP) * 30.0) + Vector3.UP * 0.3
	await _w(0.3)
	print("G2 binme=%s" % GW.ride_toggle(pl))
	cam.current = false
	pl.cam.current = true
	await _w(0.8)
	print("G2 binici ayak - kafa tepesi = %.2f m" % (pl.global_position.y - g.head_top().y))
	print("G2 model gorunur=%s agacta=%s model_y=%.2f oyuncu_y=%.2f gorsel_y=%.2f kafa_y=%.2f olcek=%s oyuncu gorunur=%s" % [pl.model.visible, pl.model.is_visible_in_tree(), pl.model.global_position.y, pl.global_position.y, pl.get_global_transform_interpolated().origin.y, g.head.global_position.y, pl.model.scale, pl.visible])
	var nm = 0
	var nv = 0
	for mi in pl.model.find_children("*", "MeshInstance3D", true, false):
		nm += 1
		if mi.is_visible_in_tree(): nv += 1
	var m0 = pl.model.find_children("*", "MeshInstance3D", true, false)[0]
	print("G2 kafa tepesi yerel=%s" % g._head_top_l)
	print("G2 mesh=%d gorunur=%d ilk=%s y=%.1f saydam=%.2f katman=%d" % [nm, nv, m0.name, m0.global_position.y, m0.transparency, m0.layers])
	var c2 = Camera3D.new()
	add_child(c2)
	c2.far = 6000.0
	c2.fov = 40.0
	c2.global_position = g.head_top() + g.forward().cross(Vector3.UP) * 22.0 + g.forward() * 14.0 + Vector3.UP * 3.0
	c2.look_at(g.head_top() + Vector3.UP * 0.5)
	c2.current = true
	await _w(0.3)
	await _shot("bin_yan")
	c2.global_position = g.head_top() + g.forward().cross(Vector3.UP) * 7.0 + g.forward() * 3.0 + Vector3.UP * 1.5
	c2.look_at(g.head_top() + Vector3.UP * 0.9)
	await _w(0.3)
	await _shot("bin_yan_yakin")
	pl.cam.current = true
	print("G2 binici yonu . heykel yonu = %.2f (1 = ayni yon)" % pl.face_dir().dot(g.forward()))
	pl.yaw = rad_to_deg(g.rotation.y)
	await _shot("bin_uzak")
	pl.cam_dist = 30.0
	await _w(0.6)
	await _shot("bin_orta")
	pl.cam_dist = 5.0
	await _w(0.6)
	await _shot("bin_yakin")
	pl.yaw += 150.0
	await _w(0.6)
	await _shot("bin_yakin_on")
	get_tree().quit()
