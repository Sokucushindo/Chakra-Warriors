extends Node
## Konoha FPS: çekirdek / koru / tarla noktalarında 4 yöne bakarak 3'er sn ortalama FPS
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	for sp in [["cekirdek", Vector2(150, 200)], ["cekirdek2", Vector2(-300, 400)], ["koru", Vector2(500, -400)], ["tarla", Vector2(0, -1150)]]:
		var at = Missions.open_ground(Vector3(c.x + sp[1].x, 0, c.z - sp[1].y), 8.0)
		at.y = Game.terrain_height(at.x, at.z) + 1.0
		main.player.respawn(at)
		await get_tree().create_timer(3.0).timeout
		var tot = 0.0
		var worst = 999.0
		for k in 4:
			main.player.yaw = k * PI * 0.5
			await get_tree().create_timer(0.6).timeout
			var t0 = Time.get_ticks_usec()
			var n = 0
			var wf = 999.0
			while Time.get_ticks_usec() - t0 < 2500000:
				var f0 = Time.get_ticks_usec()
				await get_tree().process_frame
				wf = minf(wf, 1000000.0 / maxf(1.0, Time.get_ticks_usec() - f0))
				n += 1
			tot += n / 2.5
			worst = minf(worst, wf)
		print("KFPS %s ort=%.0f en_kotu_kare=%.0f" % [sp[0], tot / 4.0, worst])
	get_tree().quit()
