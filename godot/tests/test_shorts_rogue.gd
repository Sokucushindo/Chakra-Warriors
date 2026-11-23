extends "res://tests/shorts_kit.gd"
## Shorts "POV: you betrayed your village" — sinematik: gece + yağmur, Hokage Kayası'ndan fenerli Konoha, alın koruyucusu
## yakın çekim (sağlam -> çizik), karanlığa yürüyüş; ay ışığında av-ninjaları (Sharingan -> geri çekilen kamera -> Chidori).
## SCENES=night,hunt (dikey). RUI=1: yalnız yeraltı panosu (yatay).


func scenes() -> Array:
	if OS.get_environment("RUI") != "":
		return ["board"]
	return ["night", "hunt"]


func landscape() -> bool:
	return OS.get_environment("RUI") != ""


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 90
	pr["rank"] = 2
	pl.apply_profile_stats()
	Gear.grant(pr, "alin_koruyucu", "kafa", Color(0.15, 0.22, 0.55))
	pr["band_wear"] = "alin"
	Gear.apply_look(pr)
	pl.rebuild_model()


func _mood(tod: float, rain: bool) -> void:
	var env = main.world.env
	env.time_of_day = tod
	env.region_weather = "yağmur" if rain else "açık"
	env.weather_t = 9999.0
	env.overcast = 0.65 if rain else 0.0


## Karakterin gerçek önü: gövde merkezinden gözlere (yüz yönü; face_dir sahne başında ters çıkabiliyor)
func _front() -> Vector3:
	var em: MeshInstance3D = pl.model.eyes_mesh
	var e = em.global_transform * em.get_aabb().get_center()
	var d = e - pl.global_position
	d.y = 0
	return -d.normalized() if d.length() > 0.01 else pl.face_dir()   # göz ağı başın arkasına taşıyor: işaret ters


func _head() -> Vector3:
	var em: MeshInstance3D = pl.model.eyes_mesh
	return em.global_transform * em.get_aabb().get_center()


func _turn_to(dir: Vector3) -> void:
	dir.y = 0
	dir = dir.normalized()
	pl.yaw = rad_to_deg(atan2(-dir.x, -dir.z))
	pl.facing = atan2(-dir.x, -dir.z)


# ------------------------------------------------------------------ 1) gece, yağmur: Hokage Kayası'nın tepesinden köy
func s_night() -> void:
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var rock: Dictionary = Game.world_info.get("hokage_rock", {})
	var face_z = c.z - (float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"]))
	var top_p = Vector3(c.x + 20, 0, face_z - 7)
	top_p.y = Game.terrain_height(top_p.x, top_p.z)
	await _goto(top_p, 5.0)
	_mood(0.93, true)
	await _w(1.5)
	var to_v = Vector3(c.x, 0, c.z) - Vector3(pl.global_position.x, 0, pl.global_position.z)
	to_v = to_v.normalized()
	_turn_to(to_v)
	await _w(0.6)
	var sd = to_v.cross(Vector3.UP).normalized()
	# a) sırtı bize dönük, aşağıda fenerli köy — kamera yavaşça yaklaşır
	_cut("ov_back", "a")
	await _move(-to_v * 5.0 + sd * 1.6 + Vector3.UP * 3.6, -to_v * 3.2 + sd * 0.8 + Vector3.UP * 3.0, to_v * 30.0 - Vector3.UP * 14.0, to_v * 24.0 - Vector3.UP * 10.0, 3.4, pl)
	_cut("ov_back", "b")
	# b) yüz: yağmurda alın koruyucusu (sağlam)
	pl.set_process(false)
	var fr = _front()
	var fs = fr.cross(Vector3.UP).normalized()
	var hd = _head() + Vector3.UP * 0.07
	_cut("band_before", "a")
	await _move(hd + fr * 0.95 + fs * 0.3 + Vector3.UP * 0.05, hd + fr * 0.62 + fs * 0.12, hd, hd, 1.8)
	_cut("band_before", "b")
	pl.set_process(true)
	# c) sembol çizilir
	Orgs.defect()
	_closeui()
	_mood(0.93, true)
	pl.set_process(false)
	await _w(0.5)
	fr = _front()
	fs = fr.cross(Vector3.UP).normalized()
	hd = _head() + Vector3.UP * 0.07
	_cut("band_after", "a")
	await _move(hd + fr * 0.55 - fs * 0.12, hd + fr * 0.42 - fs * 0.05, hd, hd + Vector3.UP * 0.01, 1.8)
	_cut("band_after", "b")
	pl.set_process(true)
	# d) köye sırtını döner, karanlığa yürür (kamera önden alçak, köyün ışıkları arkada)
	_turn_to(-to_v)
	await _w(0.3)
	Input.action_press("forward")
	await _w(0.5)
	_cut("walk", "a")
	await _move(-to_v * 4.2 + sd * 0.8 + Vector3.UP * 1.6, -to_v * 3.4 - sd * 0.8 + Vector3.UP * 1.8, Vector3.UP * 1.2, to_v * 20.0 - Vector3.UP * 4.0, 2.2, pl)
	_cut("walk", "b")
	Input.action_release("forward")


# ------------------------------------------------------------------ 2) ay ışığında av-ninjaları
func s_hunt() -> void:
	if not Orgs.is_rogue():
		Orgs.defect()
		_closeui()
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var wild = Missions.open_ground(c + Vector3(float(v["r"]) + 160.0, 0, 120.0), 40.0)
	wild.y = Game.ground_height(wild.x, wild.z)
	await _goto(wild, 5.0)
	_mood(0.84, false)
	await _set_eye("goz_sharingan", true)
	var hs: Array = []
	for k in 3:   # tek oyuncuya tek (güçlendirilmiş) av-ninjası geliyor; sahne için üçü de
		for h in Orgs.hunters_at(pl.global_position, 8.0):
			hs.append(h)
	await _w(0.2)
	var fr = _front()
	for i in hs.size():   # yarım çember: oyuncunun önünde ve yanlarında
		var a = (i - 1) * 0.9
		var at = pl.global_position + fr.rotated(Vector3.UP, a) * 7.0
		at = Missions.open_ground(at, 2.0)
		at.y = Game.ground_height(at.x, at.z)
		hs[i].global_position = at
		hs[i].max_hp = 60000.0
		hs[i].hp = 60000.0
		hs[i].set_physics_process(false)
		foes.append(hs[i])
	print("HUNTERS n=%d" % hs.size())
	await _w(0.4)
	# e) kızıl Sharingan
	pl.set_process(false)
	var hd = _head()
	var fs = fr.cross(Vector3.UP).normalized()
	_cut("eyes", "a")
	await _move(hd + fr * 0.5 + fs * 0.06, hd + fr * 0.36, hd, hd, 1.3)
	_cut("eyes", "b")
	# f) kamera yüzden geri çekilir: etrafında üç ANBU maskesi
	_cut("reveal", "a")
	_watch("reveal", func(): return hs[0].global_position + Vector3.UP if is_instance_valid(hs[0]) else null, 2.8)
	await _move(hd + fr * 0.5, hd - fr * 6.5 + Vector3.UP * 2.8 + fs * 1.5, hd, pl.global_position + fr * 6.0 + Vector3.UP * 1.0, 2.8)
	_cut("reveal", "b")
	pl.set_process(true)
	for h in hs:
		h.set_physics_process(true)
	# g) dövüş
	var t = hs[1] if hs.size() > 1 else hs[0]
	var d = t.global_position - pl.global_position
	d.y = 0
	d = d.normalized()
	var sd = d.cross(Vector3.UP).normalized()
	_cut("hunt_fight", "a")
	pl.combat.lock_target = t
	_combo(t, 1.8)
	await _move(-d * 3.0 + sd * 2.0 + Vector3.UP * 1.5, -d * 2.0 - sd * 2.2 + Vector3.UP * 1.3, d * 3.0 + Vector3.UP * 1.1, d * 3.0 + Vector3.UP * 1.0, 1.8, pl)
	_cut("hunt_fight", "b")
	# h) gecede Chidori
	await _jshot("raiton_chidori", "", hs[0], 2.0, "j_chidori", Color.WHITE, 6.0, 1.9)
	# i) kapanış: ay ışığında ormanın üstüne yükselen kamera
	var p0 = pl.global_position
	_cut("end", "a")
	_titles("CHAKRA WARRIORS", "Free fan game")
	await _move(p0 - fr * 4.0 + Vector3.UP * 2.0, p0 - fr * 14.0 + Vector3.UP * 26.0, p0 + Vector3.UP * 1.0, p0 + fr * 40.0 + Vector3.UP * 10.0, 3.2)
	_cut("end", "b")


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


# ------------------------------------------------------------------ yatay: yeraltı panosu (başındaki ödül)
func s_board() -> void:
	Orgs.defect()
	Orgs.state()["bounty"] = 61650
	_closeui()
	await _w(1.0)
	Hud.show_mission_board(RogueJobs.BOARD)
	await _w(0.6)
	_cut("board", "a")
	await _w(2.4)
	_cut("board", "b")
	Hud.close_dialog()
