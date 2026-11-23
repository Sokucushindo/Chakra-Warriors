extends "res://tests/shorts_kit.gd"
## Shorts "you can do way too much": Sekiz Kapı + Hirudora, miras töreni (yolu çocuğa bırak, onunla devam et). Dikey.
## SCENES=gates,legacy


func scenes() -> Array:
	return ["gates", "legacy"]


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 90
	pl.apply_profile_stats()
	Game.set_meta("sandbox", true)
	for id in ["hachimon_tonko_no_jin", "hirudora", "ura_renge"]:
		if not id in pr["learned"]:
			pr["learned"].append(id)


func _field() -> Vector3:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	return field


# ------------------------------------------------------------------ Sekiz Kapı: üç açılış (3 -> 6 -> 7), sonra Hirudora
func s_gates() -> void:
	await _goto(_field() + Vector3(18, 0, 0))
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	_cut("gates", "a")
	_caption("The Eight Gates", Color(0.5, 1.0, 0.6))
	for k in 3:
		pl.combat.cooldowns.erase("hachimon_tonko_no_jin")
		pl.combat.action = ""
		_cast("hachimon_tonko_no_jin", null)
		var a0 = -f * 3.2 + sd * (1.4 if k % 2 == 0 else -1.4) + Vector3.UP * 1.1
		var a1 = -f * 2.4 + sd * (0.6 if k % 2 == 0 else -0.6) + Vector3.UP * 0.7
		await _move(a0, a1, Vector3.UP * 1.3, Vector3.UP * 1.2, 1.7, pl)
		_god()
	_cut("gates", "b")
	print("GATES kapi=%d" % PathJutsu.gate_level(pl))
	pl.combat.cooldowns.erase("hirudora")
	var dm = _dummy(7.0)
	await _w(0.3)
	await _jshot("hirudora", "Hirudora", dm, 2.4, "j_hirudora", Color(0.5, 1.0, 0.6), 7.0, 2.2)
	dm.queue_free()


# ------------------------------------------------------------------ Miras: eş + iki çocuk, büyük çocuk mezun; tören ve çocukla devam
func s_legacy() -> void:
	await _goto(_field() + Vector3(-20, 0, 10))
	var pr = Game.profile
	pr["rank"] = 3
	pr["kd_wait"] = 99999.0
	Aging.set_years(pr, 72.0)   # görünür yaşlanma (ak saç, kırışık)
	Gear.apply_look(pr)
	pl.rebuild_model()
	Kin.ensure()
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
	_cut("lg_meet", "a")
	_caption("Grow old...", Color(0.95, 0.9, 0.8))
	await _move(mid0 + Vector3(0.4, 1.4, 3.6), mid0 + Vector3(-0.3, 1.3, 2.9), mid0 + Vector3.UP * 1.1, mid0 + Vector3.UP * 1.0, 2.0)
	_cut("lg_meet", "b")
	Legacy.start(cid, kid)
	var t := 0.0
	var shot := 0
	_cut("lg_cer", "a")
	_caption("Grow old...", Color(0.95, 0.9, 0.8))
	while is_instance_valid(Legacy.cur) and t < 14.0:
		var fo = pl.global_position
		var sg = 1.0 if shot % 2 == 0 else -1.0
		await _move(Vector3(0.9 * sg, 1.3, 2.8), Vector3(0.6 * sg, 1.2, 2.3), Vector3.UP * 1.0, Vector3.UP * 1.0, 1.4, pl)
		t += 1.4
		shot += 1
	_cut("lg_cer", "b")
	while is_instance_valid(Legacy.cur) and t < 40.0:
		await _w(0.25)
		t += 0.25
	_closeui()
	await _w(1.0)
	# artık çocuk oynanıyor: yeni yüz
	_cut("lg_after", "a")
	_caption("...then play as your child", Color(1.0, 0.85, 0.5))
	var fd = pl.face_dir()
	await _move(fd * 2.4 + Vector3.UP * 1.4, fd * 1.6 + Vector3.UP * 1.45, Vector3.UP * 1.3, Vector3.UP * 1.35, 2.2, pl)
	_cut("lg_after", "b")
	print("LEGACY yeni=%s" % String(pr.get("name", "")))
