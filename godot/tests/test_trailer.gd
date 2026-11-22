extends "res://tests/shorts_kit.gd"
## 2 dakikalık yatay fragman (1920x1080). SCENES=intro,world,eyes,fight,jutsu,susanoo,beast,chibaku,gedo,end ile sahne sahne çekilir.
## Kurgu: _tmp/trailer/plan.json + tools/shorts_make.py (yatay mod).


func landscape() -> bool:
	return true


func scenes() -> Array:
	return ["intro", "world", "eyes", "fight", "jutsu", "susanoo", "beast", "chibaku", "gedo", "end"]


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 120
	pl.apply_profile_stats()
	Gear.grant(pr, "set_jonin", "set")
	Susanoo.config(pr)["mastery"] = 999.0


func _vc(vid: String) -> Vector3:
	var v = Game.village(vid)
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	c.y = Game.terrain_height(c.x, c.z)
	return c


func _konoha_rock() -> Array:
	var v = Game.village("konoha")
	var c = _vc("konoha")
	var rock: Dictionary = Game.world_info.get("hokage_rock", {})
	var face_z = c.z - (float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"]))
	return [c, face_z, Game.terrain_height(c.x, face_z - 40)]


## Köy havadan: kamera yavaşça süzülür
func _aerial(vid: String, cut: String, nm: String, dur := 3.0) -> void:
	var v = Game.village(vid)
	var c = _vc(vid)
	var r = float(v.get("r", 500.0))
	await _goto(c + Vector3(0, 0, r * 0.3), 4.0)
	_cut(cut, "a")
	_caption(nm, Color(1, 1, 1))
	await _move(c + Vector3(-r * 0.45, r * 0.2, r * 0.55), c + Vector3(-r * 0.2, r * 0.16, r * 0.45), c + Vector3(0, 10, 0), c + Vector3(r * 0.1, 0, -r * 0.1), dur)
	_cut(cut, "b")
	_caption("")


# ------------------------------------------------------------------ 1) giriş: Konoha
func s_intro() -> void:
	var kr = _konoha_rock()
	var c: Vector3 = kr[0]
	var face_z: float = kr[1]
	var top: float = kr[2]
	await _goto(Vector3(c.x, Game.terrain_height(c.x, face_z + 200) + 2, face_z + 260), 5.0)
	main.world.env.time_of_day = 0.40
	await _w(0.5)
	_cut("in_wide", "a")
	await _move(Vector3(c.x - 120, c.y + 170, c.z + 380), Vector3(c.x - 40, c.y + 130, c.z + 200), Vector3(c.x, c.y + 20, c.z - 100), Vector3(c.x, top - 60, face_z), 4.5)
	_cut("in_wide", "b")
	_cut("in_rock", "a")
	await _move(Vector3(c.x - 120, top - 30, face_z + 160), Vector3(c.x + 80, top - 20, face_z + 140), Vector3(c.x - 40, top - 45, face_z), Vector3(c.x + 40, top - 45, face_z), 4.0)
	_cut("in_rock", "b")
	# sokak: kalabalık köy yaşamı (yer seviyesi)
	var st = c + Vector3(40, 0, 120)
	st = Missions.open_ground(st, 30.0)
	st.y = Game.ground_height(st.x, st.z)
	await _goto(st, 4.0)
	main.world.env.time_of_day = 0.42
	_cut("in_street", "a")
	await _move(st + Vector3(-6, 2.0, 10), st + Vector3(6, 2.4, 6), st + Vector3(0, 1.6, -20), st + Vector3(4, 1.6, -24), 4.0)
	_cut("in_street", "b")
	_cut("in_title", "a")
	_titles("CHAKRA WARRIORS", "An open-world Naruto fan game")
	await _move(Vector3(c.x + 200, c.y + 140, c.z + 360), Vector3(c.x + 120, c.y + 190, c.z + 520), Vector3(c.x, c.y + 10, c.z - 60), Vector3(c.x, top - 40, face_z), 4.5)
	_cut("in_title", "b")
	_titles("", "")


# ------------------------------------------------------------------ 2) dünya: beş büyük köy + Sonun Vadisi
func s_world() -> void:
	await _aerial("suna", "w_suna", "Sunagakure")
	await _aerial("kiri", "w_kiri", "Kirigakure")
	await _aerial("kumo", "w_kumo", "Kumogakure")
	await _aerial("iwa", "w_iwa", "Iwagakure")
	var ve = Game.village("valley_end")
	if not ve.is_empty():
		var P = func(lx: float, ly: float, ln: float) -> Vector3:
			var w = Game.from_map(Vector2(ve["x"] + lx, ve["y"] + ln))
			return Vector3(w.x, ly, w.z)
		await _goto(P.call(0, 2, 360), 5.0)
		_cut("w_valley", "a")
		_caption("The Valley of the End", Color(1, 1, 1))
		await _move(P.call(0, 14, 290), P.call(-30, 70, 260), P.call(0, 55, 470), P.call(0, 62, 470), 3.5)
		_cut("w_valley", "b")
		_caption("")


# ------------------------------------------------------------------ 3) gözler
func s_eyes() -> void:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	await _goto(field)
	for e in [["goz_sharingan", "Sharingan", Color(1, 0.45, 0.4)], ["goz_ems", "Mangekyō Sharingan", Color(1, 0.4, 0.35)],
			["goz_byakugan", "Byakugan", Color(0.85, 0.85, 1.0)], ["goz_rinnegan", "Rinnegan", Color(0.75, 0.6, 1.0)]]:
		await _set_eye(e[0], true)
		await _eye_shot("eye_" + e[0], e[1], e[2], 1.1)


# ------------------------------------------------------------------ 4) dövüş: iki kaçak ninja, kombo + Chidori
func s_fight() -> void:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	await _goto(field + Vector3(0, 0, -30))
	await _set_eye("goz_sharingan", true)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var a = _foe(pl.global_position + f * 6.0 - sd * 2.0)
	var b = _foe(pl.global_position + f * 8.0 + sd * 2.5)
	await _w(0.4)
	_cut("fight", "a")
	_caption("Fast ninja combat", Color(1, 1, 1))
	pl.combat.lock_target = a
	_combo(a, 3.0)
	await _move(-f * 3.2 + sd * 2.0 + Vector3.UP * 1.7, -f * 2.2 - sd * 2.4 + Vector3.UP * 1.5, f * 3.5 + Vector3.UP * 1.1, f * 3.5 + Vector3.UP * 1.0, 3.0, pl)
	_cut("fight", "b")
	await _jshot("raiton_chidori", "Chidori", b, 2.0, "f_chidori", Color(0.7, 0.85, 1.0), 6.0)
	for e in [a, b]:
		if is_instance_valid(e):
			e.queue_free()


func _combo(tgt: Node3D, dur: float) -> void:
	var t := 0.0
	while t < dur and is_instance_valid(tgt):
		_god()
		var d = tgt.global_position - pl.global_position
		d.y = 0
		if d.length() > 2.2:
			pl.global_position += d.normalized() * minf(d.length() - 2.0, 9.0 * get_process_delta_time())
		pl.combat.face_to(tgt)
		pl.combat.attack()
		await get_tree().process_frame
		t += get_process_delta_time()


# ------------------------------------------------------------------ 5) jutsu dizisi (kuklaya, temiz alan)
func s_jutsu() -> void:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	await _goto(field + pl.face_dir().cross(Vector3.UP) * 18.0)
	await _set_eye("goz_ems", true)
	var shots := [
		["katon_goukakyuu", "Katon: Gōkakyū", 2.4, false],
		["fuuton_rasenshuriken", "Fūton: Rasenshuriken", 1.8, false],
		["amaterasu", "Amaterasu", 1.8, false],
		["mokuton_mokuryu_no_jutsu", "Mokuton: Mokuryū", 1.9, true],
		["kirin", "Kirin", 2.2, true],
		["suiton_daibakufu_no_jutsu", "Suiton: Daibakufu", 2.0, true],
		["katon_goryuka_no_jutsu", "Katon: Gōryūka", 1.9, true],
		["shinra_tensei", "Shinra Tensei", 1.5, false],
	]
	for s in shots:
		await _dshot(s[0], s[1], s[2], s[3], "j_" + String(s[0]))


# ------------------------------------------------------------------ 6) Susanoo (açık çöl)
func s_susanoo() -> void:
	var sv = Game.village("suna")
	await _goto(Game.from_map(Vector2(sv["x"] + 300, sv["y"] + float(sv["r"]) + 900)))
	await _set_eye("goz_ems", true)
	_god()
	pl.set_process(false)
	var eyes = pl.combat.modes.eyes
	if not eyes.active:
		eyes.toggle()
	Susanoo.config(Game.profile).merge({"color": Susanoo.COLORS[0], "armor": 2, "face": 0, "weapon": "kilic"}, true)
	Susanoo.config(Game.profile)["tier_pref"] = 5
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var h = float(Susanoo.TIER_HEIGHT[5])
	_cut("susanoo", "a")
	_caption("Susanoo", Color(0.75, 0.55, 1.0))
	eyes._start_susanoo()
	await _move(f * 6.0 + Vector3.UP * 1.6, f * (h * 2.1 + 6.0) + sd * h * 0.5 + Vector3.UP * h * 0.5, Vector3.UP * 1.5, Vector3.UP * h * 0.55, 3.5, pl)
	_cut("susanoo", "b")
	eyes._end_susanoo()
	pl.set_process(true)


# ------------------------------------------------------------------ 7) kuyruklu canavar
func s_beast() -> void:
	var lair: Vector2 = TailedBeasts.LAIRS["shukaku"]
	await _goto(Game.from_map(lair + Vector2(0, -170)), 3.0)
	for i in 90:
		if TailedBeasts.spawned.get("shukaku") != null:
			break
		await _w(0.5)
	await _w(2.0)
	_god()
	var b = TailedBeasts.spawned.get("shukaku")
	if b == null:
		print("SHOTCHK beast YOK")
		return
	var to_b = (b.global_position - pl.global_position)
	to_b.y = 0
	to_b = to_b.normalized()
	var bs = to_b.cross(Vector3.UP).normalized()
	var bh = float(b.height) if "height" in b else 30.0
	b.atk = ""
	b._begin("ball", 0.0)
	await _w(0.6)
	_cut("beast", "a")
	_caption("Tailed Beasts", Color(1.0, 0.75, 0.4))
	await _move(-to_b * bh * 3.4 + bs * bh * 1.2 + Vector3.UP * bh * 0.4, -to_b * bh * 3.0 - bs * bh * 0.9 + Vector3.UP * bh * 0.55, Vector3.UP * bh * 0.5, Vector3.UP * bh * 0.55, 3.2, b)
	_cut("beast", "b")


# ------------------------------------------------------------------ 8) Chibaku Tensei (Rinnegan Shorts'taki onaylı açılar)
func s_chibaku() -> void:
	var sv = Game.village("suna")
	await _goto(Game.from_map(Vector2(sv["x"] + 360, sv["y"] + float(sv["r"]) + 900)))
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
	pl.combat.face_to(es[0])
	_cut("cb_cast", "a")
	_caption("Chibaku Tensei", Color(0.85, 0.75, 1.0))
	_cast("chibaku_tensei", es[0])
	await _move(-f * 7.0 - sd * 3.0 + Vector3.UP * 1.2, -f * 9.0 - sd * 3.6 + Vector3.UP * 1.0, f * 4.0 + Vector3.UP * 1.5, f * 10.0 + Vector3.UP * 10.0, 1.2, pl)
	_cut("cb_cast", "b")
	_cut("cb_pull", "a")
	await _move(ground + sd * 55.0 - f * 25.0 + Vector3.UP * 6.0, ground + sd * 48.0 - f * 32.0 + Vector3.UP * 14.0, ground + Vector3.UP * 14.0, moon_at - Vector3.UP * 4.0, 2.4)
	_cut("cb_pull", "b")
	_cut("cb_moon", "a")
	await _move(ground + sd * 62.0 - f * 40.0 + Vector3.UP * 3.0, ground + sd * 70.0 - f * 48.0 + Vector3.UP * 4.0, moon_at - Vector3.UP * 14.0, moon_at - Vector3.UP * 12.0, 1.8)
	_cut("cb_moon", "b")
	_caption("")
	_cut("cb_fall", "a")
	await _move(ground - f * 38.0 + sd * 20.0 + Vector3.UP * 12.0, ground - f * 42.0 + sd * 26.0 + Vector3.UP * 16.0, ground + Vector3.UP * 12.0, ground + Vector3.UP * 4.0, 1.8)
	_cut("cb_fall", "b")
	await _w(2.0)
	for e in es:
		if is_instance_valid(e):
			e.queue_free()


# ------------------------------------------------------------------ 9) Gedō Mazō (Konoha)
func s_gedo() -> void:
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	await _goto(field)
	await _set_eye("goz_rinnegan", true)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var p0 = pl.global_position
	var at = p0 - f * 28.0
	var head = at + Vector3.UP * 88.0
	_cut("gd_rise", "a")
	_caption("Gedō Mazō", Color(0.85, 0.75, 1.0))
	_cast("kuchiyose_gedo_mazo", null)
	await _move(p0 + f * 7.0 + sd * 1.5 + Vector3.UP * 0.8, p0 + f * 9.0 + sd * 2.0 + Vector3.UP * 0.6, p0 + Vector3.UP * 1.6, head, 2.4)
	_cut("gd_rise", "b")
	_cut("gd_slam", "a")
	await _move(p0 + sd * 170.0 + f * 20.0 + Vector3.UP * 35.0, p0 + sd * 160.0 + f * 30.0 + Vector3.UP * 40.0, at + f * 14.0 + Vector3.UP * 32.0, at + f * 16.0 + Vector3.UP * 30.0, 2.0)
	_cut("gd_slam", "b")
	_cut("gd_scale", "a")
	await _move(p0 + f * 5.0 - sd * 2.0 + Vector3.UP * 1.2, p0 + f * 120.0 - sd * 40.0 + Vector3.UP * 45.0, p0 + Vector3.UP * 1.2, at + Vector3.UP * 35.0, 3.0)
	_cut("gd_scale", "b")
	_caption("")


# ------------------------------------------------------------------ 10) bitiş: Konoha gün batımı + başlık
func s_end() -> void:
	var kr = _konoha_rock()
	var c: Vector3 = kr[0]
	var face_z: float = kr[1]
	var top: float = kr[2]
	await _goto(Vector3(c.x, Game.terrain_height(c.x, face_z + 200) + 2, face_z + 260), 5.0)
	main.world.env.time_of_day = 0.62   # akşamüstü altın ışık
	await _w(1.0)
	_cut("end", "a")
	_titles("CHAKRA WARRIORS", "Free download on GitHub")
	await _move(Vector3(c.x + 150, c.y + 110, c.z + 250), Vector3(c.x + 60, c.y + 190, c.z + 480), Vector3(c.x, c.y + 10, c.z - 60), Vector3(c.x, top - 40, face_z), 5.0)
	_cut("end", "b")
