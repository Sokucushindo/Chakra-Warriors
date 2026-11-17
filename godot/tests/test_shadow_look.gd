extends Node
## Güneş gölgesi keskinliği: çimende duran karakter, üstten (oyuncu kamerası gibi) ve yandan iki kare.
## --tag=deney: aynı karede ayar ayar varyant (hangi ayar gölgeyi bulandırıyor)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	var tag = "once"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.7, 0.35, 0.15), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var env = main.world.env
	env.region_weather = "açık"
	env.weather_t = 9999.0
	var pl = main.player
	pl.respawn(pl.global_position + Vector3(3, 0, 0))   # başlangıç çayırı (güneşli, yolun yanı)
	env.time_of_day = 0.4
	await _w(10.0)
	var sun: DirectionalLight3D = env.sun
	print("SHADOW blur=%.2f ang=%.2f splits=%.3f/%.2f/%.2f dist=%.0f" % [sun.shadow_blur, sun.light_angular_distance, sun.directional_shadow_split_1, sun.directional_shadow_split_2, sun.directional_shadow_split_3, sun.directional_shadow_max_distance])
	var cc = Camera3D.new()
	get_tree().current_scene.add_child(cc)
	cc.current = true
	env.attach_post(cc)
	var p = pl.global_position
	if tag == "deney":
		cc.global_position = p + Vector3(1.2, 3.2, -1.6)
		cc.look_at(p + Vector3(0.6, 0, 1.2))
		pl.set_process(false)
		pl.set_physics_process(false)
		var vars = [
			["0_simdiki", func(): pass],
			["1_sert_filtre", func(): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)],
			["2_blur0_ang0", func():
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
				sun.shadow_blur = 0.0
				sun.light_angular_distance = 0.0],
			["3_atlas8k", func():
				RenderingServer.directional_shadow_atlas_set_size(8192, true)],
			["4_kademe2m", func():
				RenderingServer.directional_shadow_atlas_set_size(4096, true)
				sun.directional_shadow_split_1 = 0.012],
			["5_mesafe40", func():
				sun.directional_shadow_split_1 = 0.04
				sun.directional_shadow_max_distance = 40.0],
		]
		for v in vars:
			v[1].call()
			await _w(0.6)
			await main.shot("deney_%s" % v[0])
		get_tree().quit()
		return
	var views = [[Vector3(1.2, 3.2, -1.6), Vector3(0.6, 0, 1.2)], [Vector3(-3.5, 2.2, -4.0), Vector3(0, 0.6, 0)], [Vector3(6, 6, -12), Vector3(0, 0, 4)], [Vector3(0.5, 1.4, -1.0), Vector3(-2.0, 0, 6.0)], [Vector3(2.0, 0.9, 3.0), Vector3(-3.0, 0, -4.0)]]
	for i in views.size():
		cc.global_position = p + views[i][0]
		cc.look_at(p + views[i][1])
		await _w(0.6)
		await main.shot("shadow_%s_%d" % [tag, i])
	get_tree().quit()
