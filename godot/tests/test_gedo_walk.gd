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
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/gw_%s.png" % tag)
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
	PathJutsu.cast_path(pl, "kuchiyose_gedo_mazo", null)
	await _w(3.6)
	var w = GW.active
	print("GW yuruyen=%s" % (w != null))
	var g = w.g
	cam = Camera3D.new()
	add_child(cam)
	cam.far = 6000.0
	cam.fov = 55.0
	cam.current = true
	gref = g
	var p0: Vector3 = g.global_position
	var seen = {}
	var hp0 = 0.0
	for e in foes: hp0 += e.hp
	var t0 = Time.get_ticks_msec()
	var shots = 0
	while Time.get_ticks_msec() - t0 < 22000 and is_instance_valid(g):
		await _w(0.25)
		if w.act != "": seen[w.act] = true
		var el = (Time.get_ticks_msec() - t0) / 1000.0
		if shots == 0 and el > 2.5 and w.act == "" and w.amp > 0.9:
			shots = 1; await _shot("yuru"); await _w(0.5); await _shot("yuru2")
		if shots == 1 and w.act == "smash" and w.act_t > 0.55:
			shots = 2; await _shot("ezme0"); await _w(0.55); await _shot("ezme")
		if not seen.has("r_shot") and w.act == "roar" and w.act_t > 1.0:
			seen["r_shot"] = true; await _shot("kukreme")
	var hp1 = 0.0
	var alive = 0
	for e in foes:
		if is_instance_valid(e) and not e.is_dead():
			hp1 += e.hp; alive += 1
	print("GW yapay zeka 22 sn: yol=%.0f m, eylemler=%s, dusman can %.0f -> %.0f (ayakta %d/6), zemin farki=%.1f" % [Vector2(g.global_position.x - p0.x, g.global_position.z - p0.z).length(), seen.keys(), hp0, hp1, alive, g.global_position.y - Game.jutsu_floor_at(g.global_position).y])
	# bin
	pl.global_position = Game.jutsu_floor_at(g.global_position + g.forward().cross(Vector3.UP) * 30.0) + Vector3.UP * 0.3
	await _w(0.3)
	var ok = GW.ride_toggle(pl)
	await _w(0.6)
	print("GW binme=%s oyuncu yuksekligi=%.0f m (zeminden), kamera=%.0f" % [ok, pl.global_position.y - Game.jutsu_floor_at(pl.global_position).y, pl.cam_dist])
	cam.current = false
	pl.cam.current = true
	await _w(0.2)
	await _shot("bin")
	var p1: Vector3 = g.global_position
	Input.action_press("forward")
	await _w(5.0)
	Input.action_release("forward")
	print("GW binici W 5 sn: %.0f m" % Vector2(g.global_position.x - p1.x, g.global_position.z - p1.z).length())
	await _shot("surus")
	w._want_act = "smash"
	await _w(1.2)
	print("GW binici ezme: eylem=%s" % w.act)
	await _w(2.0)
	w._want_act = "roar"
	await _w(1.0)
	print("GW binici kukreme: eylem=%s" % w.act)
	await _w(2.5)
	GW.ride_toggle(pl)
	await _w(0.5)
	print("GW inme: yukseklik=%.1f m kamera=%.1f meta=%s" % [pl.global_position.y - Game.jutsu_floor_at(pl.global_position).y, pl.cam_dist, pl.has_meta("gedo_ride")])
	# süre sonu: binili iken heykel çözülürse
	GW.ride_toggle(pl)
	await _w(0.5)
	g.set_meta("end", true)
	await _w(3.5)
	print("GW heykel bitti: binili meta=%s yukseklik=%.1f heykel=%s" % [pl.has_meta("gedo_ride"), pl.global_position.y - Game.jutsu_floor_at(pl.global_position).y, is_instance_valid(g)])
	get_tree().quit()
