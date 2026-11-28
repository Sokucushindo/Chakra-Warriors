extends Node
## Kedi / köpek sevme: [F] akışı, el hayvanın sırtında mı, hayvan tepki veriyor mu (yakın çekim)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _shot(an, tag: String, k: int, ang: float) -> void:
	var pl = main.player
	var mid: Vector3 = (pl.global_position + an.global_position) * 0.5 + Vector3.UP * 0.55
	var side: Vector3 = (an.global_position - pl.global_position)
	side.y = 0
	side = side.normalized().rotated(Vector3.UP, deg_to_rad(ang))
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 35.0
	cam.global_position = mid + side * 3.2 + Vector3.UP * 0.7
	cam.look_at(mid)
	cam.make_current()
	await _w(0.2)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/pet_%s_%d.png" % [tag, k])
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
	var v = Game.village("konoha")
	var c0 = Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 260.0, float(v["y"]) + 300.0))
	pl.respawn(Vector3(c0.x, Game.terrain_height(c0.x, c0.z) + 1.0, c0.z))
	await _w(5.0)
	Game.world.env.time_of_day = 0.45
	Game.world.env.weather = "açık"
	for dog in [false, true]:
		var an = LazyFx.g("CatNPC").new()
		an.ambient = true
		an.is_dog = dog
		get_tree().current_scene.add_child(an)
		an.global_position = pl.global_position + Vector3(2.0, 0.3, 1.5)
		await _w(1.5)
		var tag = "dog" if dog else "cat"
		print("PET ", tag, " grupta=", an.is_in_group("catchables"), " yazı=", an.catch_label, " yakın bulundu=", Hud._near_catchable(pl) == an or an.global_position.distance_to(pl.global_position) > 2.5)
		pl.respawn(an.global_position + Vector3(1.6, 0.2, 0.0))
		await _w(0.5)
		var c = Hud._near_catchable(pl)
		print("PET ", tag, " F hedefi=", c == an)
		pl.model.overlay.probe_bones = ["RightHand"]
		an.catch()
		await _w(2.3)
		var hand: Vector3 = pl.model.overlay.probe.get("RightHand", Vector3.INF)
		print("PET ", tag, " durum=", an.pet, " el-hayvan yatay ", snappedf(Vector2(hand.x - an.global_position.x, hand.z - an.global_position.z).length(), 0.01), " el yüksekliği (hayvan zeminine göre) ", snappedf(hand.y - an.global_position.y, 0.01), " oyuncu-hayvan ", snappedf(pl.global_position.distance_to(an.global_position), 0.01), " oyuncu anim=", pl.model.current)
		await _shot(an, tag, 0, 90.0)
		await _shot(an, tag, 1, -90.0)
		await _shot(an, tag, 2, 20.0)
		await _w(3.0)
		print("PET ", tag, " bitti durum=", an.pet, " kilit=", MissionWork.I().busy_run)
		var p0: Vector3 = an.global_position
		pl.respawn(pl.global_position + Vector3(6, 0.2, 0))
		await _w(2.5)
		print("PET ", tag, " sonra: hayvan-oyuncu ", snappedf(an.global_position.distance_to(pl.global_position), 0.1), " hayvanın gittiği ", snappedf(an.global_position.distance_to(p0), 0.1))
		an.queue_free()
		await _w(0.5)
	get_tree().quit()
