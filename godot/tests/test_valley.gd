extends Node
## Sonun Vadisi: kendi taş heykellerimiz (karakter modelinden) + sütunlu kanyon; oyuncu ölçek için kadrajda
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	Hud.show_game_hud(false)
	Game.world.env.time_of_day = 0.4
	Game.world.env.weather_t = 9999.0
	Game.world.env.region_weather = "açık"
	var ve = Game.village("valley_end")
	var P = func(lx: float, ly: float, ln: float) -> Vector3:
		var w = Game.from_map(Vector2(ve["x"] + lx, ve["y"] + ln))
		return Vector3(w.x, ly, w.z)
	var pl = main.player
	# 1) nehir kıyısı: oyuncu suda, iki heykel ve şelale karşıda
	pl.respawn(P.call(0, 2, 360))
	await get_tree().create_timer(6.0).timeout
	var cam = Camera3D.new()
	cam.far = 6000.0
	get_tree().current_scene.add_child(cam)
	var shots = [
		[P.call(0, 12, 300), P.call(0, 55, 470), "v1_nehir"],
		[P.call(-40, 150, 250), P.call(0, 60, 470), "v2_yukari"],
		[P.call(10, 60, 380), P.call(-66, 70, 445), "v3_sol_yakin"],
		[P.call(-10, 60, 380), P.call(66, 70, 445), "v4_sag_yakin"],
		[P.call(-20, 98, 410), P.call(-66, 92, 445), "v5_bust_sol"],
		[P.call(20, 98, 410), P.call(66, 92, 445), "v6_bust_sag"],
		[P.call(0, 330, 420), P.call(0, 0, 470), "v7_tepe"],
		[P.call(0, 120, 720), P.call(0, 40, 420), "v8_yukari_akis"],
	]
	for s in shots:
		cam.global_position = s[0]
		cam.look_at(s[1])
		cam.current = true
		pl.global_position = s[0] + (s[1] - s[0]).normalized() * 12.0
		pl.reset_physics_interpolation()
		await get_tree().create_timer(1.5).timeout
		await main.shot(s[2])
	# 2) ölçek: oyuncu sol heykelin ayağının dibinde
	pl.respawn(P.call(-66, 10, 420))
	await get_tree().create_timer(3.0).timeout
	cam.global_position = pl.global_position + Vector3(30, 8, 50)
	cam.look_at(pl.global_position + Vector3(0, 40, -20))
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	await main.shot("v9_olcek")
	# 3) oyuncu heykelin omzunda durabiliyor mu
	pl.respawn(P.call(-66, 110, 445))
	await get_tree().create_timer(3.0).timeout
	print("OMUZ y=", pl.global_position.y, " zemin? ", pl.is_on_floor())
	get_tree().quit()
