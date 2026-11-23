extends Node
## Mangekyō + mühür kabındaki canavar: havuza girer, seçilir, çağrılır; gözleri Sharingan (_tmp/msjar/<id>_N.png)
var main: Node
var cam: Camera3D
func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/msjar"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.45
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(v["x"], v["y"] + float(v["r"]) + 500)))
	await get_tree().create_timer(2.0).timeout
	print("ONCE havuz=", TailedBeasts.ms_pool())
	Gear.grant(Game.profile, "goz_mangekyo", "sag_goz", null, null, {"lvl": 3})
	Gear.grant(Game.profile, "goz_mangekyo", "sol_goz", null, null, {"lvl": 3})
	Gear.apply_look(Game.profile)
	pl.rebuild_model()
	Game.profile["beast_ms"] = []
	for id in ["kurama", "isobu"]:
		TailedBeasts.beasts()[id] = {"state": "sealed_jar", "trust": 0.0}
	SpecialSlots.refresh(Game.profile)
	print("MS havuz=", TailedBeasts.ms_pool(), " yuva=", Data.jutsu.has(SpecialSlots.MS_BIJUU_ID))
	pl.combat.modes.eyes.open_ms()
	await get_tree().create_timer(1.5).timeout
	print("ms_on=", pl.combat.modes.eyes.ms_on)
	pl.max_hp = 99999.0; pl.hp = 99999.0
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 3000
	main.add_child(cam)
	main.world.env.attach_post(cam)
	for id in ["kurama", "isobu"]:
		Game.profile["beast_ms_pick"] = id
		pl.combat.cooldowns.erase(SpecialSlots.MS_BIJUU_ID)
		pl.max_chakra = 999.0
		pl.chakra = 999.0
		var ok = SpecialSlots.cast(pl, SpecialSlots.MS_BIJUU_ID)
		await get_tree().create_timer(3.0).timeout
		var b = null
		for n in get_tree().current_scene.get_children():
			if n is TailedBeast and n.ally_owner == pl:
				b = n
		print("CAGRI %s ok=%s bulundu=%s goz=%d katman=%d durum=%s" % [id, ok, b != null, b.rig.eye_slots.size() if b else -1, b.rig._shari.size() if b else -1, TailedBeasts.beast_state(id)])
		if b:
			b.set_physics_process(false)
			var hd: Vector3 = b.rig.head.global_position
			var fw: Vector3 = -b.rig.head.global_transform.basis.z
			var dist = b.height * 0.11
			for k in 4:
				var a = deg_to_rad([0.0, 180.0, 35.0, -35.0][k])
				var dir = fw.rotated(Vector3.UP, a)
				cam.global_position = hd + dir * dist + Vector3.UP * b.height * 0.03
				cam.look_at(hd, Vector3.UP)
				await get_tree().create_timer(0.4).timeout
				await RenderingServer.frame_post_draw
				var im = get_viewport().get_texture().get_image()
				im.resize(im.get_width() / 3, im.get_height() / 3)
				im.save_png("res://../_tmp/msjar/%s_%d.png" % [id, k])
			b.ally_life = 0.0
			b.set_physics_process(true)
			await get_tree().create_timer(1.5).timeout
	print("SON kap=", TailedBeasts.jarred())
	get_tree().quit()
