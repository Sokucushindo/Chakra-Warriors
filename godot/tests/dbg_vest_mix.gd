extends Node
## Köy chūnini: elle yapılmış yeleğin altından eski yelek kabuğu taşıyor mu (lekeli iki ton)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 700.0, float(v["y"]))) + Vector3(0, 1, 0))
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	await _w(2.0)
	var i = 0
	var cases = []
	for cl in ["hyuga", "sarutobi", "nara", "akimichi"]:
		for arch0 in ["chunin", "jonin"]:
			cases.append(["klan_%s_%s" % [cl, arch0], ClanWorld.clan_look(cl, arch0, "konoha")])
	for vid0 in ["kumo", "iwa"]:
		var lk0 = LazyFx.g("Outfits").roll("chunin", vid0)
		lk0["vest"] = Color(0.38, 0.48, 0.28)
		cases.append(["zorla_%s" % vid0, lk0])
	for cs in cases:
		for once in 1:
			var vid = String(cs[0])
			var arch = "x"
			var a = Enemy.archetype("kumo", 0)
			a["respawn"] = false
			a["no_world"] = true
			a["look"] = cs[1]
			print("VEST ", vid, " set=", a["look"].get("set_id"), " el=", CharacterModel.SetEl.has(a["look"].get("set_id")), " yelek=", a["look"].get("vest"))
			var e = Enemy.new()
			e.setup(a)
			e.team = pl.team
			get_tree().current_scene.add_child(e)
			e.global_position = pl.global_position + Vector3(6.0, 0.2, -6)
			e.home = e.global_position
			await _w(3.5)
			for k in 2:
				var cam = Camera3D.new()
				main.add_child(cam)
				cam.fov = 35.0
				cam.current = true
				for fr in 12:
					var fd: Vector3 = e.face_dir()
					var sd: Vector3 = fd.cross(Vector3.UP).normalized()
					var dv: Vector3 = [fd * 2.3, fd * -1.6 + sd * 1.6][k]
					cam.global_position = e.global_position + dv + Vector3.UP * 1.3
					cam.look_at(e.global_position + Vector3.UP * 1.15)
					await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/vest2/%s_%s_%d.png" % [vid, arch, k])
				cam.queue_free()
			e.queue_free()
			i += 1
	print("bitti")
	get_tree().quit()
