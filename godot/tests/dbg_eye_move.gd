extends Node
## Sharingan açılış yakın çekimi koşarken: kamera bakışı ile gözün o anki yeri arasındaki açı (derece) kare kare
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	await get_tree().create_timer(5.0).timeout
	var pl = main.player
	var ey = pl.combat.modes.eyes
	var moving := true
	var worst := 0.0
	var n := 0
	ey._eye_closeup(1)
	var sk: Skeleton3D = pl.model.skel
	var hb = sk.find_bone("Head")
	for i in 60:
		pl.global_position += -pl.global_transform.basis.z * 0.0 + pl.face_dir() * 0.12   # ~7 m/sn koşu
		await get_tree().process_frame
		var cam = get_viewport().get_camera_3d()
		if cam == pl.cam:
			break
		var f: Vector3 = pl.face_dir(); f.y = 0; f = f.normalized()
		var head: Vector3 = (sk.global_transform * sk.get_bone_global_pose(hb)).origin
		var a = float(pl.model.age_scale)
		var ep = head + Vector3.UP * 0.075 * a + f * 0.085 * a
		var ang = rad_to_deg((-cam.global_transform.basis.z).angle_to(ep - cam.global_position))
		worst = maxf(worst, ang)
		n += 1
	print("GOZ kare=%d en_kotu_aci=%.1f derece" % [n, worst])
	get_tree().quit()
