extends Node
## Temel silahsız kombo tekmeleri: her kare sağ/sol ayağın karaktere göre yeri (ön / yan / yükseklik) + yandan ve önden görüntü.
var main: Node
var cam: Camera3D
var pl


func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true


func _rel(bone: String) -> Vector3:
	var sk: Skeleton3D = pl.model.skel
	var bi = sk.find_bone(bone)
	var w: Vector3 = (sk.global_transform * sk.get_bone_global_pose(bi)).origin - pl.global_position
	var f: Vector3 = pl.face_dir()
	var r: Vector3 = f.cross(Vector3.UP)
	return Vector3(w.dot(f), w.y, w.dot(r))   # ön, yükseklik, sağ


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/kick2"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12),
		"bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	Hud.show_game_hud(false)
	pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	WorldDay.auto = false
	var c = Missions.open_ground(pl.global_position + Vector3(0, 0, 60.0), 8.0)
	c.y = Game.ground_height(c.x, c.z) + 0.2
	pl.respawn(c)
	pl.facing = 0.0
	await get_tree().create_timer(1.5).timeout
	cam = Camera3D.new()
	cam.fov = 40
	main.add_child(cam)
	main.world.env.attach_post(cam)
	var views = OS.get_environment("VIEW").split(",") if OS.get_environment("VIEW") != "" else PackedStringArray(["side"])
	if OS.get_environment("KEYS") != "":
		var SMv = preload("res://scripts/combat/storm_moves.gd")
		for kk in OS.get_environment("KEYS").split(","):
			var br = kk.split(":")[0]
			var mv: Dictionary = SMv.moves(br, false)[int(kk.split(":")[1])]
			for view in views:
				pl.global_position = c
				pl.velocity = Vector3.ZERO
				await get_tree().create_timer(0.6).timeout
				var f: Vector3 = pl.face_dir()
				var r: Vector3 = f.cross(Vector3.UP)
				var mid: Vector3 = c + Vector3.UP * 1.0
				var mk = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.15, 1.6, 0.15)
				mk.mesh = bm
				main.add_child(mk)
				mk.global_position = c + f * 1.6 + Vector3.UP * 0.8
				if view == "top":
					cam.global_position = mid + Vector3.UP * 5.0 + f * 0.01
					cam.look_at(mid, f)
				else:
					cam.global_position = mid - f * 4.0 + r * 1.2 + Vector3.UP * 1.2
					cam.look_at(mid + f * 0.8)
				pl.model.overlay.play_keys(mv, 0.5)   # yarı hızda: düşük kare hızında da her evre görünsün
				var t0 = Time.get_ticks_msec()
				var n = 0
				while Time.get_ticks_msec() - t0 < float(mv["len"]) * 2000.0 + 200:
					await get_tree().create_timer(0.07).timeout
					await RenderingServer.frame_post_draw
					var im = get_viewport().get_texture().get_image()
					im.resize(im.get_width() / 4, im.get_height() / 4)
					im.save_png("res://../_tmp/kick2/k_%s%s_%s_%02d.png" % [br, kk.split(":")[1], view, n])
					n += 1
				mk.queue_free()
		get_tree().quit()
		return
	var styles = OS.get_environment("STYLES").split(",") if OS.get_environment("STYLES") != "" else PackedStringArray(["style_temel:3|4"])
	for sty in styles:
		var sid = sty.split(":")[0]
		var want_steps = Array(sty.split(":")[1].split("|")).map(func(x): return int(x))
		pl.combat.dbg_wid = sid
		for view in views:
			pl.combat.action = ""
			pl.combat.step = -1
			pl.global_position = c
			pl.facing = 0.0
			pl.velocity = Vector3.ZERO
			await get_tree().create_timer(0.8).timeout
			var f: Vector3 = pl.face_dir()
			var r: Vector3 = f.cross(Vector3.UP)
			var mid: Vector3 = c + Vector3.UP * 1.0
			var mk = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.15, 1.6, 0.15)
			mk.mesh = bm
			mk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mm = StandardMaterial3D.new()
			mm.albedo_color = Color(1, 0, 0)
			mk.material_override = mm
			main.add_child(mk)
			mk.global_position = c + f * 1.6 + Vector3.UP * 0.8   # hedef: karakterin tam önü
			if view == "top":
				cam.global_position = mid + Vector3.UP * 5.0 + f * 0.01
				cam.look_at(mid, -f)
			elif view == "back":
				cam.global_position = mid - f * 4.5 + Vector3.UP * 0.6
				cam.look_at(mid)
			else:
				cam.global_position = mid + r * 4.5 + Vector3.UP * 0.3
				cam.look_at(mid)
			var t0 = Time.get_ticks_msec()
			var last_step = -9
			var n = 0
			var shot_at = -1.0
			while Time.get_ticks_msec() - t0 < 4200:
				if pl.combat.action == "" or pl.combat.t > 0.25:
					pl.combat.attack()
				pl.global_position.x = c.x   # yerinde (kamera kadrajı)
				pl.global_position.z = c.z
				f = pl.face_dir()
				r = f.cross(Vector3.UP)
				mk.global_position = c + f * 1.6 + Vector3.UP * 0.8
				if view == "top":
					cam.global_position = mid + Vector3.UP * 5.0 + f * 0.01
					cam.look_at(mid, f)   # ekranın üstü = karakterin önü
				elif view == "back":
					cam.global_position = mid - f * 4.0 + r * 1.2 + Vector3.UP * 1.2
					cam.look_at(mid + f * 0.8)
				else:
					cam.global_position = mid + r * 4.5 + Vector3.UP * 0.3
					cam.look_at(mid)
				await get_tree().process_frame
				var st = pl.combat.step
				if st != last_step:
					last_step = st
				if st in want_steps:
					if pl.combat.t - shot_at > 0.04 or shot_at > pl.combat.t:
						shot_at = pl.combat.t
						await RenderingServer.frame_post_draw
						var im = get_viewport().get_texture().get_image()
						im.resize(im.get_width() / 4, im.get_height() / 4)
						im.save_png("res://../_tmp/kick2/%s_%s_%d_%02d.png" % [sid, view, st, n])
						n += 1
	get_tree().quit()
