extends Node
## Kamera binaya yaklaşınca etraf kayboluyor mu: kamera bir gizleyici (OccluderInstance3D) kutusunun içine düşerse Godot her şeyi
## gizler. Konoha evlerinin yanına oyuncu konur, kamera eve doğru çevrilir, birkaç kare sonra kamera kutunun içinde mi bakılır.
## Satırlar "OCC".
var main: Node
var boxes: Array = []   # [v0, ex, ey, ez] (ex/ey/ez: kenar vektörleri)


func _inside(p: Vector3, bx: Array) -> bool:
	var d: Vector3 = p - bx[0]
	for k in [1, 2, 3]:
		var e: Vector3 = bx[k]
		var t = d.dot(e) / e.length_squared()
		if t < 0.0 or t > 1.0:
			return false
	return true


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for oi in get_tree().root.find_children("*", "OccluderInstance3D", true, false):
		var oc = oi.occluder
		if not oc is ArrayOccluder3D:
			continue
		var vs: PackedVector3Array = oc.vertices
		var xf: Transform3D = oi.global_transform
		for i in range(0, vs.size() - 7, 8):
			var v0 = xf * vs[i]
			boxes.append([v0, xf * vs[i + 2] - v0, xf * vs[i + 4] - v0, xf * vs[i + 1] - v0])
	print("OCC gizleyici kutu sayisi ", boxes.size())
	var pl = main.player
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	var n := 0
	var bad := 0
	var bad_wall := 0
	var space = pl.get_world_3d().direct_space_state
	var samples = []
	for s in 120:
		var bx: Array = boxes[rng.randi() % boxes.size()]
		var c: Vector3 = bx[0] + (bx[1] + bx[3]) * 0.5
		var half = (bx[1].length() + bx[3].length()) * 0.5 / 0.78 * 0.5   # gerçek evin yarı genişliği (~)
		var a = rng.randf() * TAU
		var p = c + Vector3(cos(a), 0, sin(a)) * (half + rng.randf_range(0.6, 3.0))
		p.y = Game.ground_height(p.x, p.z)
		# oyuncu evin içine düşmesin: göğüs hizasında katı var mı
		var q = PhysicsShapeQueryParameters3D.new()
		var sph = SphereShape3D.new()
		sph.radius = 0.4
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.2)
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		pl.global_position = p + Vector3.UP * 0.1
		pl.velocity = Vector3.ZERO
		pl.cam_pivot.global_position = pl.global_position + Vector3.UP * 1.7   # ışınlanınca kamera yetişsin (yoksa yolda evlerin içinden geçiyor)
		# kamera eve doğru: oyuncu evle kamera arasında değil, kamera evin içine bakacak şekilde (geri yön = eve)
		var to_house = Vector2(c.x - p.x, c.z - p.z).normalized()
		for yv in [0.0, 35.0, -35.0]:
			pl.yaw = rad_to_deg(atan2(to_house.x, to_house.y)) + yv
			pl.pitch = rng.randf_range(-35.0, 10.0)
			for f in 30:
				await get_tree().process_frame
			var cp: Vector3 = pl.cam.global_position
			n += 1
			for b2 in boxes:
				if (b2[0] as Vector3).distance_squared_to(cp) < 2500.0 and _inside(cp, b2):
					bad += 1
					if samples.size() < 12:
						samples.append([cp, pl.cam_cur_dist, pl.cam_dist, b2])
						var G = preload("res://scripts/world/occ_guard.gd")
						print("OCC kotu: koruma kamerayi goruyor=%s pivot icinde=%s oyuncu=%s kamera=%s kutu_alt=%.1f" % [G.inside(cp, 0.0), G.inside(pl.cam_pivot.global_position, 0.0), str(pl.global_position), str(cp), b2[0].y])
					break
	print("OCC olcum %d kamera konumu, gizleyici icinde %d (%.1f%%)" % [n, bad, 100.0 * bad / maxf(1, n)])
	for sm in samples:
		var b2: Array = sm[3]
		var bc: Vector3 = b2[0] + (b2[1] + b2[3]) * 0.5 + b2[2] * 0.5
		var hx = b2[1].length() * 0.5; var hz = b2[3].length() * 0.5
		var col = []
		for ax in [b2[1].normalized(), b2[3].normalized()]:
			var ext = []
			for sg in [1.0, -1.0]:
				var q = PhysicsRayQueryParameters3D.create(bc + ax * sg * 30.0, bc, 1)
				var h = space.intersect_ray(q)
				ext.append(-1.0 if h.is_empty() else (h["position"] - bc).dot(ax * sg))
			col.append(ext)
		print("OCC ornek kamera %s cur_dist=%.2f | kutu yari %.1f x %.1f yuk %.1f | carpisma x:%s z:%s | kamera-kutu-alt %.1f" % [str(sm[0]), sm[1], hx, hz, b2[2].length(), str(col[0]), str(col[1]), sm[0].y - b2[0].y])
	get_tree().quit()
