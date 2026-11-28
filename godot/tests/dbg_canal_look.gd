extends Node
## Kanal suyu görünüşü: su üstünde durup yukarıdan bakış (köşeli leke / ek çizgisi var mı)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var best = Vector3.ZERO
	var bd = 1e9
	for ix in range(-150, 151):
		for iz in range(-150, 151):
			var q = pl.global_position + Vector3(ix * 4.0, 0, iz * 4.0)
			var th = Game.terrain_height(q.x, q.z)
			var wl = Game.water_level(q.x, q.z, th)
			if wl > -1000.0 and Vector2(ix, iz).length() < bd:
				bd = Vector2(ix, iz).length()
				best = Vector3(q.x, wl, q.z)
	print("CANAL su noktası uzaklık=", bd * 4.0, " ", best)
	var env = Game.world.env
	env.time_of_day = 0.5
	env.weather = "açık"
	pl.respawn(best + Vector3(0, 0.5, 0))
	await _w(5.0)
	env.time_of_day = 0.5
	var k = 0
	for dv in [Vector3(10, 9, 10), Vector3(-14, 6, 3), Vector3(2, 16, -3)]:
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.fov = 60.0
		cam.current = true
		cam.global_position = best + dv
		cam.look_at(best + Vector3(-dv.x, 0, -dv.z) * 0.6)
		await _w(0.6)
		get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/canal_%d.png" % k)
		cam.queue_free()
		k += 1
	get_tree().quit()
