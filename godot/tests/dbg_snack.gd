extends Node
## Sokak satıcısından al + ye: üç tezgâh türü (meyve, balık, dango), para düşüyor mu, ürün elde / ağızda mı (yakın çekim)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _shot(v, tag: String, k: int, ang: float, dist := 2.6) -> void:
	var pl = main.player
	var mid: Vector3 = pl.global_position + Vector3.UP * 1.2
	var back: Vector3 = (pl.global_position - v.global_position)
	back.y = 0
	back = back.normalized().rotated(Vector3.UP, deg_to_rad(ang))
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 38.0
	cam.global_position = mid + back * dist + Vector3.UP * 0.35
	cam.look_at(mid - back * 0.4)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/snk_%s_%d.png" % [tag, k])
	cam.queue_free()
func _wide(v, tag: String, k: int) -> void:
	var pl = main.player
	var mid: Vector3 = (pl.global_position + v.global_position) * 0.5 + Vector3.UP * 1.15
	var side: Vector3 = (pl.global_position - v.global_position)
	side.y = 0
	side = side.normalized().rotated(Vector3.UP, deg_to_rad(78.0))
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 40.0
	cam.global_position = mid + side * 5.4 + Vector3.UP * 0.5
	cam.look_at(mid)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/snk_%s_%d.png" % [tag, k])
	cam.queue_free()
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather = "açık"
	var VL = get_tree().current_scene.find_child("VillageLife", true, false)
	var stalls = []
	for s in VL.sites.get("konoha", []):
		if s["type"] == "stall":
			stalls.append(s)
	print("SNK tezgâh sayısı ", stalls.size(), " türler ", stalls.map(func(s): return s.get("kind", -1)))
	var done := {}
	for s in stalls:
		var kind = int(s.get("kind", -1))
		if done.has(kind) or not MissionWork.SNACKS.has(kind):
			continue
		pl.respawn((s["front"] as Vector3) + Vector3(0, 0.5, 0) + ((s["front"] as Vector3) - (s["back"] as Vector3)).normalized() * 2.5)
		var v = null
		for i in 40:
			await _w(0.5)
			for n in get_tree().get_nodes_in_group("talkers"):
				if n is Villager and n.role == "vendor" and n.global_position.distance_to(s["back"]) < 2.5:
					v = n
			if v != null:
				break
		if v == null:
			print("SNK tür ", kind, " satıcı gelmedi")
			continue
		done[kind] = true
		await _w(1.0)
		var tag = str(kind)
		var r0 = int(Game.profile["ryo"])
		pl.hp = pl.max_hp * 0.4
		var h0 = pl.hp
		print("SNK tür ", kind, " satıcı=", v.display, " tezgâh türü=", v.stall_kind, " ryo=", r0)
		MissionWork.I().buy_snack(v, v.stall_kind)
		await _w(0.75)
		await _wide(v, tag, 0)    # para havada
		await _w(0.85)
		await _wide(v, tag, 1)    # ürün havada
		await _w(0.75)
		await _shot(v, tag, 2, 150.0, 1.4)   # bütün ürün elde
		await _w(0.25)
		await _shot(v, tag, 3, 120.0, 1.4)   # ilk lokma
		await _w(1.2)
		await _shot(v, tag, 4, 150.0, 1.4)   # ikinci lokma
		await _w(3.0)
		await _w(3.0)
		print("SNK tür ", kind, " bitti: ryo ", r0, " -> ", int(Game.profile["ryo"]), " can ", snappedf(h0, 1), " -> ", snappedf(pl.hp, 1), " kilit=", MissionWork.I().busy_run, " oyuncu-satıcı ", snappedf(pl.global_position.distance_to(v.global_position), 0.01))
	get_tree().quit()
