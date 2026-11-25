extends Node
## Boyun yakın çekim: SET kıyafeti (GEN=m/f), önden / çapraz / yandan / alttan-önden boyun
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	var gen := OS.get_environment("GEN") if OS.get_environment("GEN") != "" else "m"
	main.creator_state = {"slot": 3, "name": "Test", "gender": gen, "clan": "none", "element": "katon", "hair_style": "kisa", "hair": Color(0.1, 0.1, 0.14), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	var t0 := Time.get_ticks_msec()
	while main.loading != null and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	var pl = main.player
	var v = Game.village("konoha")
	pl.respawn(Game.from_map(Vector2(v["x"] + 300, v["y"] + float(v["r"]) + 900)))
	await get_tree().create_timer(1.0).timeout
	for sid in OS.get_environment("SET").split(","):
		Gear.grant(Game.profile, sid, "set")
		Gear.apply_look(Game.profile)
		pl.rebuild_model()
		await get_tree().create_timer(1.5).timeout
		Hud.show_game_hud(false)
		pl.set_physics_process(false)
		pl.model.play("idle")
		await get_tree().create_timer(0.5).timeout
		var sk: Skeleton3D = pl.model.skel
		var nb := sk.find_bone("Neck")
		var c: Vector3 = (sk.global_transform * sk.get_bone_global_pose(nb)).origin + Vector3.UP * 0.03
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.current = true
		cam.fov = 30
		var fw = pl.face_dir()
		var sd = fw.cross(Vector3.UP)
		var i = 0
		for o in [fw * 0.7, (fw + sd).normalized() * 0.7, sd * 0.7, (fw * 0.6 + Vector3.UP * 0.35).normalized() * 0.7, (-fw * 0.6 + Vector3.UP * 0.4).normalized() * 0.7]:
			cam.global_position = c + o
			cam.look_at(c)
			await get_tree().create_timer(0.2).timeout
			await main.shot("%s_%s_%d" % [sid, gen, i])
			i += 1
		cam.queue_free()
	get_tree().quit()
