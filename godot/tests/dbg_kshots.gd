extends Node
## Konoha serbest kamera: CAMS="x,n,yükseklik,hx,hn;..." (köy yerel; kamera (x,n)'de zeminden yükseklikte, (hx,hn)'ye bakar)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.42
	WorldDay.auto = false
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	var i = 0
	for spec in OS.get_environment("CAMS").split(";", false):
		var f = spec.split(",")
		var p = Vector3(c.x + float(f[0]), 0, c.z - float(f[1]))
		var t = Vector3(c.x + float(f[3]), 0, c.z - float(f[4]))
		main.player.respawn(Vector3(p.x, Game.terrain_height(p.x, p.z) + 1.0, p.z))
		await get_tree().create_timer(2.0).timeout
		main.player.visible = false
		p.y = Game.terrain_height(p.x, p.z) + float(f[2])
		t.y = Game.terrain_height(t.x, t.z) + 4.0
		cam.global_position = p
		cam.look_at(t, Vector3.UP)
		cam.current = true
		await get_tree().create_timer(0.5).timeout
		await main.shot("kc_%02d" % i)
		i += 1
	get_tree().quit()
