extends Node
## Occlusion culling görsel denetimi: aynı noktalardan kapatıcı açık / kapalı görüntü al; fark (yanlışlıkla kaybolan nesne) var mı?
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	Hud.show_game_hud(false)
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather_t = 9999.0
	Game.world.env.region_weather = "açık"
	await get_tree().create_timer(6.0).timeout
	var pl: Player = main.player
	var v = Game.village("konoha")
	var base = Game.from_map(Vector2(v["x"], v["y"]))
	var spots = [Vector2(0, 0), Vector2(180, 90), Vector2(-250, 150), Vector2(120, -260), Vector2(-120, -120), Vector2(380, 0)]
	var i := 0
	for sp in spots:
		var p = base + Vector3(sp.x, 0, sp.y)
		pl.respawn(Missions.open_ground(p, 40.0) + Vector3.UP * 0.5)
		pl.cam_dist = 9.0
		await get_tree().create_timer(2.5).timeout
		for occ in [true, false]:
			get_viewport().use_occlusion_culling = occ
			await get_tree().process_frame
			await get_tree().process_frame
			main.shot("occ_%d_%s" % [i, "acik" if occ else "kapali"])
			await get_tree().process_frame
		i += 1
	print("OCC TEST BITTI")
	get_tree().quit()
