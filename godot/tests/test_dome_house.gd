extends Node
## Kubbeli yuvarlak ev: çatı / duvar birleşimi (üst yarım küre) görünüm testi
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken",
		"hair": Color(0.3, 0.2, 0.12), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	Hud.show_game_hud(false)
	var pl = main.player
	Game.world.env.time_of_day = 0.42
	Game.world.env.weather_t = 999
	var p = Game.from_map(Vector2(-50, -455))   # açık alan
	p.y = Game.ground_height(p.x, p.z)
	pl.respawn(p)
	pl.yaw = 0.0
	pl.pitch = -6.0
	pl.cam_dist = 5.0
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	var t: Dictionary = HouseKit._make_round(rng, 1, true)
	var root = Node3D.new()
	add_child(root)
	root.global_position = p + Vector3(0, 0, -16)
	for part in [["walls", Color(0.92, 0.92, 0.9)], ["roof", Color(0.75, 0.2, 0.1)], ["detail", Color(1, 1, 1)]]:
		var mi = MeshInstance3D.new()
		mi.mesh = t[part[0]]
		var m = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = part[1]
		mi.material_override = m
		root.add_child(mi)
	print("roof_top=", t["roof_top"], " h=", t["h"])
	await get_tree().create_timer(2.0).timeout
	await main.shot("dome_1_on")
	pl.yaw = 40.0
	root.global_position = p + Vector3(-9, 0, -14)
	await get_tree().create_timer(1.0).timeout
	await main.shot("dome_2_yan")
	get_tree().quit()
