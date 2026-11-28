extends Node
## Ramen yeme: tezgâhta eller doğru mu (yakın çekim, üç açı, kaseye dalış + ağza götürme)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
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
	var tag = OS.get_environment("TAG")
	var it = {}
	for q in Interact.items:
		if String(q.get("kind", "")) == "ramen" or String(q.get("id", "")) == "ramen" or q.has("seats"):
			it = q
			break
	print("EAT ramen=", it.keys())
	pl.respawn(it["pos"] + Vector3.UP)
	await _w(4.0)
	Game.profile["ryo"] = 999
	for mode in 1:
		var fd: Vector3 = pl.face_dir()
		var sb: StaticBody3D = null
		Progress._ramen(it)
		await _w(0.2)
		var e = pl.get_node("EatAnim")
		print("EAT tezgah=", e.on_counter)
		if false:
			pass
		var k = 0
		for tt in [0.95, 0.42]:   # ilk lokma: kaseye dalış, sonra ağza
			await _w(tt)
			var right = fd.cross(Vector3.UP).normalized()
			var sk: Skeleton3D = pl.model.skel
			var hd: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
			var rhd: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
			print("EATPOS mod=", mode, " oyuncu=", pl.global_position, " kafa=", hd, " sagel=", rhd, " kase=", e.bowl.global_position, " yon=", pl.face_dir())
			e.hold = true
			await _w(0.1)
			var tg: Vector3 = e._hand_now("Right") + Vector3.UP * 0.05
			print("EATNOW el=", e._hand_now("Right"), " kemik=", e._bone("RightHand"), " model=", pl.model.global_position, " skel=", pl.model.skel.global_position, " cubuk=", e.sticks.global_position)
			for sd in ["Left", "Right"]:
				var S0: Vector3 = e._bone(sd + "UpperArm")
				print("EATIK ", sd, " omuz=", S0 - pl.global_position, " kol=", S0.distance_to(e._bone(sd + "LowerArm")), "+", e._bone(sd + "LowerArm").distance_to(e._bone(sd + "Hand")), " el=", e._hand_now(sd) - pl.global_position, " kase=", e.bowl.global_position - pl.global_position, " ik=", e._ik(sd, e.bowl.global_position, 20.0))
			var mk = MeshInstance3D.new()
			mk.visible = false
			var sm = SphereMesh.new()
			sm.radius = 0.02
			sm.height = 0.04
			mk.mesh = sm
			var mm = StandardMaterial3D.new()
			mm.albedo_color = Color(1, 0, 1)
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.no_depth_test = true
			mk.material_override = mm
			get_tree().current_scene.add_child(mk)
			mk.global_position = tg
			for ang in [0.0, 55.0, -55.0, 110.0, -110.0]:
				var dv: Vector3 = (pl.face_dir() * 1.3).rotated(Vector3.UP, deg_to_rad(ang)) + Vector3.UP * 0.3
				var cam = Camera3D.new()
				main.add_child(cam)
				cam.fov = 55.0
				cam.global_position = tg + dv
				cam.look_at(tg)
				cam.make_current()
				await _w(0.12)
				print("EATPX ", tag, " ", mode, " ", k, " ", cam.unproject_position(tg), " hoff=", cam.h_offset, " cur=", get_viewport().get_camera_3d() == cam)
				get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/eat_%s_%d_%d.png" % [tag, mode, k])
				cam.queue_free()
				k += 1
			e.hold = false
			mk.queue_free()
		await e.done
		await _w(0.5)
		if sb:
			sb.queue_free()
	get_tree().quit()
