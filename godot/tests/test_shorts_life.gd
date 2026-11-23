extends "res://tests/shorts_kit.gd"
## Shorts: "Bir ninjanın hayatı" — akademi çocuğu, genin antrenmanı, chūnin, Mangekyō, evlilik, yaşlılık + miras töreni, çocukla devam.
## SCENES=kid,genin,chunin,eye,love,legacy


func scenes() -> Array:
	return ["kid", "genin", "chunin", "eye", "love", "legacy"]


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 60
	pl.apply_profile_stats()
	Game.set_meta("sandbox", true)
	for id in ["katon_goukakyuu", "katon_karyuu", "katon_goka_mekkyaku"]:
		if not id in pr["learned"]:
			pr["learned"].append(id)


func _age(rank: int, years: float, set_id: String) -> void:
	var pr = Game.profile
	pr["rank"] = rank
	Aging.set_years(pr, years)
	if set_id != "":
		Gear.grant(pr, set_id, "set")
	Gear.apply_look(pr)
	pl.rebuild_model()
	await _w(1.2)


func _field() -> Vector3:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	return field


## Oyuncu etrafında alçak, yavaş dönen kamera (yüz kameraya)
func _orbit(cut: String, cap_s: String, col: Color, dur := 2.4, dist := 2.6, h := 1.2) -> void:
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	_cut(cut, "a")
	_caption(cap_s, col)
	_watch(cut, func(): return pl.global_position + Vector3.UP * 1.0, dur)
	await _move(f * dist + sd * dist * 0.7 + Vector3.UP * h, f * dist - sd * dist * 0.5 + Vector3.UP * (h + 0.2), Vector3.UP * (h - 0.1), Vector3.UP * (h + 0.05), dur, pl)
	_cut(cut, "b")


# ------------------------------------------------------------------ 1) akademi çocuğu (sabah)
func s_kid() -> void:
	var ac = Exams.find_point(["academy"])
	await _goto(Missions.open_ground(ac + Vector3(0, 0, 18), 20.0))
	main.world.env.time_of_day = 0.33
	await _age(0, 9.0, "")
	await _orbit("kid", "Born in the Hidden Leaf.", Color(1.0, 0.86, 0.45), 2.6, 2.0, 0.9)


# ------------------------------------------------------------------ 2) genin: antrenman sahasında Gōkakyū
func s_genin() -> void:
	await _goto(_field() + Vector3(18, 0, 0))
	main.world.env.time_of_day = 0.42
	await _age(1, 13.0, "set_genin")
	await _dshot("katon_goukakyuu", "Train. Become a ninja.", 2.0, true, "genin")


# ------------------------------------------------------------------ 3) chūnin: rakiple dövüş, Karyū Endan
func s_chunin() -> void:
	await _goto(_field() + Vector3(-30, 0, 30))
	main.world.env.time_of_day = 0.55
	await _age(2, 17.0, "set_chunin")
	var f = pl.face_dir()
	var e = _foe(pl.global_position + f * 10.0, "rogue", 60000.0)
	await _w(0.8)
	pl.combat.face_to(e)
	var sd = (e.global_position - pl.global_position).cross(Vector3.UP).normalized()
	_cut("chunin", "a")
	_caption("Rise through the ranks.", Color(1.0, 0.6, 0.3))
	_cast("katon_karyuu", e)
	_watch("chunin", func(): return e.global_position + Vector3.UP, 2.6)
	var rel = e.global_position - pl.global_position
	await _move(sd * 6.0 - rel * 0.25 + Vector3.UP * 2.2, sd * 7.5 + rel * 0.1 + Vector3.UP * 3.0, rel * 0.5 + Vector3.UP * 1.4, rel * 0.6 + Vector3.UP * 1.4, 2.6, pl)
	_cut("chunin", "b")
	e.queue_free()
	_clear_fx()


# ------------------------------------------------------------------ 4) Mangekyō (alacakaranlık)
func s_eye() -> void:
	await _goto(_field() + Vector3(40, 0, -20))
	main.world.env.time_of_day = 0.78
	await _age(3, 24.0, "set_jonin")
	await _set_eye("goz_mangekyo", true)
	await _eye_shot("eye", "Awaken the Mangekyō.", Color(1.0, 0.3, 0.3), 1.6)


# ------------------------------------------------------------------ 5) evlilik: eşle yan yana, gün batımı
func s_love() -> void:
	await _goto(_field() + Vector3(-10, 0, -40))
	main.world.env.time_of_day = 0.74
	await _set_eye("goz_mangekyo", false)
	await _age(3, 28.0, "")
	var pr = Game.profile
	Kin.ensure()
	var lk = ClanWorld.clan_look("hyuga", "chunin", Progress.home(), true, "adult")
	var sid = Friends._make_friend("Hyūga Hana", "hyuga", lk, 90, "Eşin")
	Friends.all()[sid]["romance"] = "eş"
	Friends.all()[sid]["love"] = 95
	pr["spouse"] = sid
	var base = Missions.open_ground(pl.global_position + Vector3(4, 0, 4), 20.0)
	pl.global_position = base + Vector3(0, 0.3, 0)
	pl.reset_physics_interpolation()
	var sp = Friends.inst()._spawn_npc(sid, base + Vector3(1.1, 0, 0), false)
	await _w(1.6)
	_closeui()
	if is_instance_valid(sp):
		sp.set_physics_process(false)
		sp.look_at(sp.global_position + pl.face_dir(), Vector3.UP)
		sp.rotate_y(PI)
	var mid = base + Vector3(0.55, 0, 0)
	var fd = pl.face_dir()
	_cut("love", "a")
	_caption("Find someone to fight for.", Color(1.0, 0.7, 0.75))
	_watch("love", func(): return mid + Vector3.UP * 1.2, 2.6)
	await _move(mid + fd * 3.4 + Vector3(0.6, 1.5, 0), mid + fd * 2.6 + Vector3(-0.5, 1.35, 0), mid + Vector3.UP * 1.3, mid + Vector3.UP * 1.25, 2.6)
	_cut("love", "b")
	if is_instance_valid(sp):
		sp.queue_free()


# ------------------------------------------------------------------ 6) yaşlılık + miras töreni + çocukla devam (test_shorts_viral ile aynı akış)
func s_legacy() -> void:
	await _goto(_field() + Vector3(-20, 0, 10))
	main.world.env.time_of_day = 0.45
	var pr = Game.profile
	pr["kd_wait"] = 99999.0
	await _age(3, 72.0, "")
	Kin.ensure()
	if String(pr.get("spouse", "")) == "":
		var lk = ClanWorld.clan_look("hyuga", "chunin", Progress.home(), true, "adult")
		var sid = Friends._make_friend("Hyūga Hana", "hyuga", lk, 90, "Eşin")
		Friends.all()[sid]["romance"] = "eş"
		Friends.all()[sid]["love"] = 90
		pr["spouse"] = sid
	var now = Time.get_unix_time_from_system()
	pr["children"] = [{"name": "Uchiha Ren", "gender": "m", "clans": ["uchiha"], "born": now - Friends.CHILD_GROW - 60.0}]
	for k in pr["children"]:
		KidLife.ensure(k)
	pr["children"][0]["tr"] = {"shuriken": 6.0, "taijutsu": 5.0, "chakra": 4.0}
	Friends.inst().graduation()
	_closeui()
	var cid = ""
	for id in Friends.all():
		if Friends.all()[id].get("child", false):
			cid = id
	if cid == "":
		print("SHOTCHK legacy COCUK YOK")
		return
	Friends.all()[cid]["taught"] = ["katon_goukakyuu"]
	var base = Missions.open_ground(pl.global_position + Vector3(6, 0, 6), 30.0)
	pl.global_position = base + Vector3(0, 0.3, 0)
	await _w(1.0)
	var kid = Friends.inst()._spawn_npc(cid, base + Vector3(2.6, 0, 0.4), false)
	await _w(1.5)
	_closeui()
	var mid0 = base + Vector3(1.3, 0, 0.2)
	_cut("old", "a")
	_caption("Grow old...", Color(0.95, 0.9, 0.8))
	await _move(mid0 + Vector3(0.4, 1.4, 3.6), mid0 + Vector3(-0.3, 1.3, 2.9), mid0 + Vector3.UP * 1.1, mid0 + Vector3.UP * 1.0, 2.2)
	_cut("old", "b")
	Legacy.start(cid, kid)
	var t := 0.0
	var shot := 0
	_cut("cer", "a")
	_caption("Pass on the Will of Fire.", Color(1.0, 0.7, 0.35))
	while is_instance_valid(Legacy.cur) and t < 14.0:
		var sg = 1.0 if shot % 2 == 0 else -1.0
		await _move(Vector3(0.9 * sg, 1.3, 2.8), Vector3(0.6 * sg, 1.2, 2.3), Vector3.UP * 1.0, Vector3.UP * 1.0, 1.4, pl)
		t += 1.4
		shot += 1
	_cut("cer", "b")
	while is_instance_valid(Legacy.cur) and t < 40.0:
		await _w(0.25)
		t += 0.25
	_closeui()
	await _w(1.0)
	_cut("after", "a")
	_caption("...then live on as your child.", Color(1.0, 0.85, 0.5))
	var fd = pl.face_dir()
	await _move(fd * 2.4 + Vector3.UP * 1.4, fd * 1.6 + Vector3.UP * 1.45, Vector3.UP * 1.3, Vector3.UP * 1.35, 2.2, pl)
	_cut("after", "b")
	_caption("")
	_cut("end", "a")
	_titles("CHAKRA WARRIORS", "Free fan game")
	await _move(fd * 1.6 + Vector3.UP * 1.45, fd * 6.0 + Vector3.UP * 4.0, Vector3.UP * 1.35, Vector3.UP * 1.0, 2.6, pl)
	_cut("end", "b")
	print("LEGACY yeni=%s" % String(pr.get("name", "")))
