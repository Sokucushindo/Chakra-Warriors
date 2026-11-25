extends Node
## Bir köyün hikâye yapısına bak (VID=kumo SITE=hospital): yandan + havadan çek
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	var vid = OS.get_environment("VID") if OS.get_environment("VID") != "" else "kumo"
	var site = OS.get_environment("SITE") if OS.get_environment("SITE") != "" else "hospital"
	main.creator_state = {"slot": 3, "name": "T", "gender": "m", "clan": "none", "village": vid, "element": "raiton", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var v = Game.village(vid)
	var sp: Vector2 = BuildVillageStory._sites(v)[site]
	var c = Game.from_map(sp)
	c.y = Game.terrain_height(c.x, c.z)
	print("PEEK site %s %s at %s" % [vid, site, str(sp)])
	var cam = Camera3D.new()
	cam.far = 4000.0
	get_tree().current_scene.add_child(cam)
	for s in [["side", Vector3(45, 14, 45)], ["air", Vector3(0, 120, 80)], ["low", Vector3(-40, 6, 30)]]:
		cam.global_position = c + s[1]
		cam.look_at(c + Vector3.UP * 8.0)
		cam.current = true
		await get_tree().create_timer(1.5).timeout
		await main.shot("site_%s_%s_%s" % [vid, site, s[0]])
	get_tree().quit()
