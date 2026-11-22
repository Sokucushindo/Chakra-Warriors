extends "res://tests/shorts_kit.gd"
## Shorts: Rinnegan — Chibaku Tensei + Gedō Mazō (ölçek vurgulu). SCENES=eye,chibaku,gedo ile tek tek çekilebilir.


func scenes() -> Array:
	return ["eye", "chibaku", "gedo"]


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 120
	pl.apply_profile_stats()
	Gear.grant(pr, "set_jonin", "set")


func _desert() -> Vector3:
	var sv = Game.village("suna")
	return Game.from_map(Vector2(sv["x"] + 300, sv["y"] + float(sv["r"]) + 900))


# ------------------------------------------------------------------ 1) Rinnegan uyanışı
func s_eye() -> void:
	await _goto(_desert())
	await _set_eye("goz_rinnegan", true)
	await _eye_shot("eye", "Rinnegan", Color(0.78, 0.62, 1.0), 1.3)


# ------------------------------------------------------------------ 2) Chibaku Tensei: çöl, 4 düşman çekilir; ölçek için oyuncu küçük ön planda
func s_chibaku() -> void:
	await _goto(_desert() + Vector3(60, 0, 0))
	await _set_eye("goz_rinnegan", true)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var es: Array = []
	for i in 4:
		es.append(_foe(pl.global_position + f * (15.0 + (i % 2) * 4.0) + sd * (i - 1.5) * 4.0))
	await _w(0.6)
	for e in es:
		e.set_physics_process(false)
	var ground: Vector3 = es[0].global_position
	var moon_at = ground + Vector3.UP * 32.0
	var p0 = pl.global_position
	pl.combat.face_to(es[0])
	print("POS pl=%s f=%s e0=%s" % [p0.round(), f, es[0].global_position.round()])
	# a) atış: omuz üstünden alçak, kara küre ellerden göğe fırlar
	_cut("cb_cast", "a")
	_caption("Chibaku Tensei", Color(0.85, 0.75, 1.0))
	_cast("chibaku_tensei", es[0])
	_watch("cb_cast", func(): return moon_at, 1.2)
	await _move(-f * 7.0 - sd * 3.0 + Vector3.UP * 1.2, -f * 9.0 - sd * 3.6 + Vector3.UP * 1.0, f * 4.0 + Vector3.UP * 1.5, f * 10.0 + Vector3.UP * 10.0, 1.2, pl)
	print("POS2 pl=%s" % pl.global_position.round())
	_cut("cb_cast", "b")
	# b) çekim: yandan geniş, yerden kopan kayalar sarmal çizip göğe
	_cut("cb_pull", "a")
	_watch("cb_pull", func(): return moon_at, 2.4)
	await _move(ground + sd * 55.0 - f * 25.0 + Vector3.UP * 6.0, ground + sd * 48.0 - f * 32.0 + Vector3.UP * 14.0, ground + Vector3.UP * 14.0, moon_at - Vector3.UP * 4.0, 2.4)
	_cut("cb_pull", "b")
	# c) ölçek: uzaktan alçak açı — oyuncu küçük ön planda, dev kaya ay gökte
	_cut("cb_moon", "a")
	_caption("A man-made moon", Color(0.85, 0.75, 1.0))
	_watch("cb_moon", func(): return moon_at, 1.8)
	var mf = moon_at - pl.global_position
	mf.y = 0
	mf = mf.normalized()
	var ms = mf.cross(Vector3.UP).normalized()
	await _move(ground + sd * 62.0 - f * 40.0 + Vector3.UP * 3.0, ground + sd * 70.0 - f * 48.0 + Vector3.UP * 4.0, moon_at - Vector3.UP * 14.0, moon_at - Vector3.UP * 12.0, 1.8)
	_cut("cb_moon", "b")
	# d) çöküş: kayalar yağar
	_cut("cb_fall", "a")
	_caption("")
	_watch("cb_fall", func(): return ground + Vector3.UP * 8.0, 1.8)
	await _move(ground - f * 38.0 + sd * 20.0 + Vector3.UP * 12.0, ground - f * 42.0 + sd * 26.0 + Vector3.UP * 16.0, ground + Vector3.UP * 12.0, ground + Vector3.UP * 4.0, 1.8)
	_cut("cb_fall", "b")
	await _w(2.0)
	for e in es:
		if is_instance_valid(e):
			e.queue_free()


# ------------------------------------------------------------------ 3) Gedō Mazō: Konoha antrenman sahası — evler ölçek verir
func s_gedo() -> void:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	await _goto(field)
	await _set_eye("goz_rinnegan", true)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var p0 = pl.global_position
	var at = p0 - f * 28.0   # heykel oyuncunun arkasından yükselir (jutsunun kendi yeri)
	var head = at + Vector3.UP * 88.0
	# a) yükseliş: oyuncunun önünden alçak açı, kamera oyuncudan heykelin kafasına doğru yukarı bakar
	_cut("gd_rise", "a")
	_caption("Gedō Mazō", Color(0.85, 0.75, 1.0))
	_cast("kuchiyose_gedo_mazo", null)
	_watch("gd_rise", func(): return at + Vector3.UP * 40.0, 2.4)
	await _move(p0 + f * 7.0 + sd * 1.5 + Vector3.UP * 0.8, p0 + f * 9.0 + sd * 2.0 + Vector3.UP * 0.6, p0 + Vector3.UP * 1.6, head, 2.4)
	_cut("gd_rise", "b")
	# b) çöküş: heykel öne atılıp elleriyle yeri döver — yandan geniş
	_cut("gd_slam", "a")
	_watch("gd_slam", func(): return at + Vector3.UP * 30.0, 1.8)
	await _move(p0 + sd * 170.0 + f * 20.0 + Vector3.UP * 35.0, p0 + sd * 160.0 + f * 30.0 + Vector3.UP * 40.0, at + f * 14.0 + Vector3.UP * 32.0, at + f * 16.0 + Vector3.UP * 30.0, 1.8)
	_cut("gd_slam", "b")
	# c) ölçek: oyuncunun ayağından geri ve yukarı çekilen kamera — 100 m
	_cut("gd_scale", "a")
	_caption("100 meters tall", Color(1.0, 0.85, 0.5))
	_watch("gd_scale", func(): return at + Vector3.UP * 30.0, 2.6)
	await _move(p0 + f * 5.0 - sd * 2.0 + Vector3.UP * 1.2, p0 + f * 120.0 - sd * 40.0 + Vector3.UP * 45.0, p0 + Vector3.UP * 1.2, at + Vector3.UP * 35.0, 2.6)
	_cut("gd_scale", "b")
	# d) bitiş: geniş çekim + başlık
	_caption("")
	_cut("end", "a")
	_titles("CHAKRA WARRIORS", "Free fan game")
	await _move(p0 + f * 120.0 - sd * 40.0 + Vector3.UP * 45.0, p0 + f * 150.0 - sd * 70.0 + Vector3.UP * 60.0, at + Vector3.UP * 35.0, at + Vector3.UP * 40.0, 3.0)
	_cut("end", "b")
