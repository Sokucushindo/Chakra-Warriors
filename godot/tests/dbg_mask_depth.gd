extends Node
## Tam yüz maskesi yüze giriyor mu: yüz köşelerinin maske kabuğunun önüne taşma miktarı (cm), yaş / cinsiyete göre.
var main: Node
const MV = preload("res://scripts/actors/mask_v2.gd")
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	for g in ["m", "f"]:
		for age in ["teen", "adult", "elder"]:
			var lk: Dictionary = main.player.model.look.duplicate()
			lk["gender"] = g
			lk["age"] = age
			lk["face_style"] = "anbu_kus"
			var m = CharacterModel.new()
			add_child(m)
			m.setup(lk)
			var t0 = Time.get_ticks_msec()
			while not m.built and Time.get_ticks_msec() - t0 < 5000:
				await get_tree().process_frame
			if m._face_src.is_empty():
				print("MASK ", g, age, " yuz yok")
				continue
			var mesh: Mesh = m._face_src[0]
			var place: Transform3D = m._face_src[1]
			var hc: Vector3 = m._head_center()
			var ab: AABB = m.head_ab
			var hw := clampf(ab.size.x, 0.16, 0.26) if ab.size.x > 0.05 else 0.2
			var ey: float = m.eye_center_model.y
			var sc := clampf(hw / 0.19, 0.85, 1.15) * 0.8
			var org := Vector3(hc.x, ey - 0.012, hc.z + 0.075 * sc)
			var k = MV.Mk.new(Color.WHITE)
			var worst := -1.0
			var wat := Vector2.ZERO
			var n_in := 0
			for si in mesh.get_surface_count():
				var vs: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for v in vs:
					var q: Vector3 = place * v
					var lx := (q.x - org.x) / sc
					var ly := (q.y - org.y) / sc
					# maske dış çizgisinin içinde mi
					var t := atan2(lx, ly)
					var e: Vector2 = k.edge(t)
					if Vector2(lx, ly).length() > e.length() * 0.97:
						continue
					var mz := org.z + k.S(lx, ly) * sc
					var pen := q.z - mz
					if pen > 0.0:
						n_in += 1
					if pen > worst:
						worst = pen
						wat = Vector2(lx, ly)
			print("MASK %s %s hw=%.3f sc=%.3f  en_cok_tasma=%.1f cm  (x=%.3f y=%.3f)  tasan_kose=%d" % [g, age, hw, sc, worst * 100.0, wat.x, wat.y, n_in])
			m.queue_free()
	print("MASK bitti")
	get_tree().quit()
