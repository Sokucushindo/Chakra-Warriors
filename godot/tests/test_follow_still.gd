extends Node
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.2, 0.2, 0.3)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9
	var vs = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(vs["x"]) + float(vs["r"]) + 500.0, float(vs["y"]))) + Vector3(0, 1, 0))
	await _w(10.0)
	Hud.close_dialog()
	var pr = Game.profile
	Gear.grant(pr, "goz_rinnegan", "sag_goz", null, null, {"lvl": 3, "origin": "nakil"})
	var SP = LazyFx.g("SixPaths")
	var d = SP.data()
	for i in 6:
		var a = Enemy.archetype(["kumo", "kiri", "iwa", "suna"][i % 4], i)
		Stats.npc_ninja(a, 50, 1.0)
		d["bodies"].append({"id": i + 1, "name": "B%d" % i, "level": 50, "arch": var_to_str(SP._clean(a))})
		d["slots"][SP.PATHS[i]] = i + 1
	pl.max_chakra = 1e6; pl.chakra = 1e6
	PathJutsu.cast_path(pl, "pein_rikudo", null)
	await _w(8.0)
	var p0 = {}
	for p in SP.PATHS:
		var e = SP._alive(p)
		if e: p0[p] = e.global_position
	var moved = {}
	for k in 40:
		await _w(0.25)
		for p in p0:
			var e = SP._alive(p)
			if e:
				moved[p] = float(moved.get(p, 0.0)) + e.global_position.distance_to(p0[p])
				p0[p] = e.global_position
	print("FS dururken 10 sn toplam yol: %s" % str(moved))
	# oyuncu 40 m ileri ışınlanır: koşarak yetişmeli
	pl.global_position += pl.face_dir() * 40.0
	await _w(7.0)
	var ds = []
	for p in SP.PATHS:
		var e = SP._alive(p)
		if e: ds.append(snappedf(e.global_position.distance_to(pl.global_position), 0.1))
	print("FS 40 m uzaklasinca 7 sn sonra mesafeler: %s" % str(ds))
	get_tree().quit()
