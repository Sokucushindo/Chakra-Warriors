extends Node
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "suna", "hair_style": "s2", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	var p = main.player.global_position
	print("STEP baslangic=", Game.step_sound(p), " sfx_ok=", Sfx.has_method("play"))
	# Konoha: sokak üstü ve sokak dışı ayrı ayrı
	var kv = Game.world_info["villages"][0]
	var kc = Vector3(float(kv["x"]), 0, -float(kv["y"]))
	var tally = {}
	for r in range(5, int(float(kv["r"]) * 0.9), 6):
		for k in 24:
			var q = kc + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * r
			var key = ("sokak " if Game.road_at(q.x, q.z) > 0.3 else "disi ") + Game.step_sound(q).rstrip("0123456789")
			tally[key] = tally.get(key, 0) + 1
	print("STEP konoha dagilim=", tally)
	for v in Game.world_info["villages"]:
		var q = Vector3(float(v["x"]), 0, -float(v["y"]))
		print("STEP ", v.get("id", ""), " -> ", Game.step_sound(q), " wet=", snappedf(Game.step_wetness(q), 0.01), " biome=", Game.biome_at(q.x, q.z))
		Game.play_step(q, 1.0, 0.3)
	main.world.env.weather = "yağmur"
	main.world.env.overcast = 0.9
	var kq = Vector3(float(Game.world_info["villages"][0]["x"]), 0, -float(Game.world_info["villages"][0]["y"]))
	print("STEP yagmur konoha wet=", Game.step_wetness(kq), " ", Game.step_sound(kq))
	Game.play_step(p, 1.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	for k in ["step_grass", "step_dirt", "step_stone", "step_wood"]:
		var arr: Array = Sfx.variants.get(k, [])
		print("STEP varyant ", k, " ", arr.size(), " ", arr[0].resource_path if arr.size() > 0 else "-")
	print("STEP bitti")
	get_tree().quit()
