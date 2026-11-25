extends Node
## Bir köyde başla (VID=kumo), havadan + alçaktan çek, yapı sayısını yaz (pişirme yarıda mı kontrolü)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	var vid = OS.get_environment("VID") if OS.get_environment("VID") != "" else "kumo"
	main.creator_state = {"slot": 3, "name": "T", "gender": "m", "clan": "none", "village": vid, "element": "raiton", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var v = Game.village(vid)
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var mm = 0; var inst = 0; var bodies = 0
	for n in get_tree().current_scene.find_children("*", "MultiMeshInstance3D", true, false):
		if (n as Node3D).global_position.distance_to(c) < float(v["r"]) + 2000.0:
			mm += 1
			if n.multimesh:
				inst += n.multimesh.instance_count
	for n in get_tree().current_scene.find_children("*", "StaticBody3D", true, false):
		bodies += 1
	print("PEEK %s multimesh=%d instances=%d static_bodies=%d" % [vid, mm, inst, bodies])
	var cam = Camera3D.new()
	cam.far = 6000.0
	get_tree().current_scene.add_child(cam)
	var r = float(v["r"])
	for s in [["air", Vector3(0, r * 0.55, r * 0.6)], ["low", Vector3(r * 0.2, 25, r * 0.25)]]:
		var at: Vector3 = c + s[1]
		at.y = Game.terrain_height(at.x, at.z) + s[1].y
		cam.global_position = at
		cam.look_at(Vector3(c.x, Game.terrain_height(c.x, c.z), c.z))
		cam.current = true
		await get_tree().create_timer(1.5).timeout
		await main.shot("peek_%s_%s" % [vid, s[0]])
	get_tree().quit()
