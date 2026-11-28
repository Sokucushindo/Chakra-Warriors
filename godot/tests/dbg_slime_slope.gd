extends Node
## Saiken sümük seli / sümük gölü / mürekkep: eğimli arazide yere oturuyor mu
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
	var v = Game.village("konoha")
	var c0 = Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 500.0, float(v["y"])))
	# en eğimli yer: 40 m'de en çok yükseklik farkı
	var best = c0
	var bs = 0.0
	for ix in range(-30, 31):
		for iz in range(-30, 31):
			var q = c0 + Vector3(ix * 20.0, 0, iz * 20.0)
			var h0 = Game.terrain_height(q.x, q.z)
			var sl = absf(Game.terrain_height(q.x + 30.0, q.z) - h0)
			if sl > bs and sl < 14.0 and h0 > 2.0:
				bs = sl
				best = q
	print("SLIME eğim (30 m'de) = ", bs)
	pl.respawn(Vector3(best.x, Game.terrain_height(best.x, best.z) + 1.0, best.z))
	await _w(5.0)
	Game.world.env.time_of_day = 0.5
	pl.yaw = -90.0
	var BA = LazyFx.g("BijuuArts")
	var k = 0
	for key in ["nenko_shinshoku", "sumi"]:
		BA.use(pl, "saiken" if key != "sumi" else "gyuki", key, {"aim": pl.global_position + Vector3(25, 0, 0)})
		await _w(1.6)
		for dv in [Vector3(-6, 9, 22), Vector3(14, 3, -26)]:
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.fov = 60.0
			cam.current = true
			var tg = pl.global_position + Vector3(16, 0, 0)
			tg.y = Game.terrain_height(tg.x, tg.z)
			cam.global_position = tg + dv
			cam.look_at(tg)
			await _w(0.4)
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/slime_%d.png" % k)
			cam.queue_free()
			k += 1
		await _w(1.0)
	get_tree().quit()
