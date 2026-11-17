extends Node
## Çimen tırtığı: aynı kare çizgi katmanı açık / kapalı (yakın, eğik bakış)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	var v = Game.village("konoha")
	var base = Game.from_map(Vector2(v["x"] + float(v["r"]) + 250, v["y"]))
	for r in range(0, 2000, 60):
		var q = base + Vector3(r, 0, 0)
		if Game.biome_at(q.x, q.z) in [7, 2] and Game.road_at(q.x, q.z) < 0.1:
			base = q
			break
	pl.respawn(base)
	main.world.env.time_of_day = 0.45
	await _w(2.0)
	var cc = Camera3D.new()
	get_tree().current_scene.add_child(cc)
	cc.global_position = pl.global_position + Vector3(0, 1.6, 0)
	cc.look_at(pl.global_position + Vector3(0, 0.2, 3.5))
	cc.current = true
	pl.visible = false
	main.world.env.attach_post(cc)
	main.world.env.post.visible = true
	print("GRASSAA msaa=%d fxaa=%d scale=%.2f" % [get_viewport().msaa_3d, get_viewport().screen_space_aa, get_viewport().scaling_3d_scale])
	await _w(0.5)
	await main.shot("grass_aa_post")
	main.world.env.post.visible = false
	await _w(0.3)
	await main.shot("grass_aa_nopost")
	# karakter çimende: kontur korunuyor mu
	pl.visible = true
	main.world.env.post.visible = true
	cc.global_position = pl.global_position + Vector3(0.6, 1.3, -2.2)
	cc.look_at(pl.global_position + Vector3(0, 0.8, 0))
	await _w(0.5)
	await main.shot("grass_aa_char")
	get_tree().quit()
