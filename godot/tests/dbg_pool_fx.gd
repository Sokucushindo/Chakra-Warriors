extends Node
## Parçacık havuzu denetimi: aynı ayarlı patlama / topak art arda 3 kez atılır, her birinin ortasında görüntü alınır.
## Üçü de aynı görünmeli (2. ve 3. havuzdan gelir). Çıktı: _tmp/pool_N.png + "POOL" satırları.
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.9, 0.4, 0.1),
		"top": Color(0.2, 0.3, 0.6), "bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	Hud.visible = false
	var gc := get_viewport().get_camera_3d()
	var at: Vector3 = gc.global_position - gc.global_transform.basis.z * 7.0
	for i in 3:
		var a = FX.burst(at + Vector3(-2, 0, 0), {"amount": 40, "life": 0.8, "tex": FX.tex_spark, "size": 0.6, "vmin": 3, "vmax": 7, "colors": [Color(1, 0.9, 0.4, 1), Color(1, 0.4, 0.1, 0)]})
		FX.blood(at, Vector3.RIGHT, 0.8)
		FX.dust(at + Vector3(2, -1.2, 0), 1.5)
		FX.hit_spark(at + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 1.4)
		await get_tree().create_timer(0.22).timeout
		get_viewport().get_texture().get_image().save_png("res://../_tmp/pool_%d.png" % i)
		print("POOL %d dugum %d havuz %d anahtar %d ayni dugum id %d" % [i, get_tree().get_node_count(), FX._burst_pooled, FX._burst_pool.size(), a.get_instance_id()])
		await get_tree().create_timer(2.6).timeout
	get_tree().quit()
