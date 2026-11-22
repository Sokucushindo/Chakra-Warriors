extends Node
## Müzik durumu: köyler, doğa, gece, mağara, savaş; her durumda çalan parça
var main: Node
func _say(tag: String) -> void:
	await get_tree().create_timer(2.5).timeout
	var st = Sfx.music_a.stream
	print("MUZIK %-12s durum=%-8s calan=%s caliyor=%s" % [tag, Sfx.music_name, st.resource_path.get_file() if st else "-", Sfx.music_a.playing])
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	Game.world.env.time_of_day = 0.45
	await get_tree().create_timer(4.0).timeout
	print("MUZIK gruplar=", Sfx.music_groups.keys(), " toplam=", Sfx.music_groups.values().reduce(func(a, x): return a + x.size(), 0))
	for vid in ["konoha", "suna", "kiri", "kumo", "iwa"]:
		var v = Game.village(vid)
		main.player.global_position = Game.from_map(Vector2(v["x"], v["y"])) + Vector3(0, 60, 0)
		await _say(vid)
	var v0 = Game.village("konoha")
	main.player.global_position = Game.from_map(Vector2(v0["x"] + float(v0["r"]) + 400.0, v0["y"])) + Vector3(0, 60, 0)
	await _say("doga")
	Game.world.env.time_of_day = 0.9
	await _say("gece")
	Game.world.env.time_of_day = 0.45
	var p = main.player.global_position
	Interiors.inst.enter({"pos": p, "out": p + Vector3(0, 0, 3), "room": "rogue_hideout", "kind": "enter"})
	await get_tree().create_timer(3.0).timeout
	await _say("magara")
	Interiors.inst.exit()
	await get_tree().create_timer(2.0).timeout
	var e = Enemy.new()
	e.setup(Enemy.archetype("rogue", 0))
	get_tree().current_scene.add_child(e)
	e.global_position = main.player.global_position + Vector3(6, 0, 0)
	await _say("savas")
	e.queue_free()
	await get_tree().create_timer(8.0).timeout
	await _say("savas_sonu")
	print("MUZIK bitti")
	get_tree().quit()
