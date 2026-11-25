extends Node
## Balkon / çatı hatası: Konoha'da bir evin üstüne çık, çevredeki evler kayboluyor mu? Yerde ve yukarıda aynı yönden kare.
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	Hud.close_dialog()
	var pl = main.player
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	# merkezden 300 m doğuya, bir evin üstünü ışınla bul
	var space = pl.get_world_3d().direct_space_state
	var best = null
	for i in 4000:
		var a = randf() * TAU
		var q = c + Vector3(cos(a), 0, sin(a)) * randf_range(80.0, 400.0)
		var rq = PhysicsRayQueryParameters3D.create(q + Vector3.UP * 200.0, q + Vector3.DOWN * 50.0)
		var hit = space.intersect_ray(rq)
		if hit.is_empty():
			continue
		var gy = Game.terrain_height(q.x, q.z)
		var hy = float(hit["position"].y)
		if hy - gy > 4.0 and hy - gy < 14.0:
			best = hit["position"]
			break
	if best == null:
		print("BAL çatı bulunamadı")
		get_tree().quit()
		return
	print("BAL çatı y=%.1f zemin=%.1f" % [best.y, Game.terrain_height(best.x, best.z)])
	var gpos = best + Vector3(6.0, 0, 6.0)
	gpos.y = Game.ground_height(gpos.x, gpos.z)
	for s in [["yer", gpos], ["cati", best + Vector3.UP * 0.2]]:
		pl.respawn(s[1])
		pl.global_position = s[1]
		pl.velocity = Vector3.ZERO
		pl.yaw = 0.0
		await get_tree().create_timer(2.5).timeout
		print("BAL %s oyuncu y=%.1f kamera=%s" % [s[0], pl.global_position.y, str(get_viewport().get_camera_3d().global_position)])
		await main.shot("balkon_%s" % s[0])
		for k in 3:
			pl.yaw = 90.0 * (k + 1)
			pl.pitch = -6.0
			await get_tree().create_timer(1.0).timeout
			await main.shot("balkon_%s_%d" % [s[0], k])
	get_tree().quit()
