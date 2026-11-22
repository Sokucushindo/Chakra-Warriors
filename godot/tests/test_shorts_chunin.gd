extends Node
## YouTube Shorts: Chūnin Sınavı (dikey, --write-movie; pencere boyutu godot/override.cfg ile 756x1344).
## Sahneler: başlık (stadyum) → Ölüm Ormanı takım koşusu → parşömen kapma dövüşü → kule salonu ön eleme → stadyum finali → bitiş.
## Her sahne "CUT <ad> a/b <kare>"; arayüz ekranları test_shorts_chunin_ui.gd'den, kurgu _tmp/shorts_chunin/make.py.
var main: Node
var cam: Camera3D
var cap: Label
var title: Label
var sub: Label
var pl


func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true
	# rakipler teknik / alet atmasın: duman, mürekkep ve "Extinguished!" yazıları dikey kadrajı kapatıyordu
	for e in Exams.nodes + ChuninExam.rivals:
		if is_instance_valid(e) and e is Enemy:
			e.arch["jutsu"] = []
			e.arch["tools"] = false
			e.maki = 0          # yere makibishi saçmasın
			e.sub_bars = 0.0    # kawarimi dumanı + ağaca ışınlanma yok
			e.sub_cd = 99.0


func _cut(n: String, edge: String) -> void:
	print("CUT %s %s %d" % [n, edge, Engine.get_frames_drawn()])


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _move(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, dur: float, follow: Node3D = null) -> void:
	var t := 0.0
	while t < dur:
		var k := smoothstep(0.0, 1.0, t / dur)
		var base := follow.global_position if follow and is_instance_valid(follow) else Vector3.ZERO
		cam.current = true
		var cp = base + p0.lerp(p1, k)
		if follow and is_instance_valid(follow):
			# kamera ağacın / duvarın içine girmesin: takip edilenden kameraya ışın, çarparsa önüne al
			var from = follow.global_position + Vector3.UP * 1.3
			var q = PhysicsRayQueryParameters3D.create(from, cp)
			q.exclude = [follow.get_rid()]
			var hit = follow.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				cp = hit["position"] + (from - cp).normalized() * 0.4
		cam.global_position = cp
		cam.look_at(base + l0.lerp(l1, k))
		await get_tree().process_frame
		t += get_process_delta_time()


func _caption(s: String, col := Color(1.0, 0.86, 0.45)) -> void:
	cap.text = s
	cap.add_theme_color_override("font_color", col)
	cap.modulate.a = 1.0 if s != "" else 0.0


func _lbl(parent: Node, size: int, col: Color, y: float) -> Label:
	var l = Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = y
	l.anchor_bottom = y
	l.offset_top = -60
	l.offset_bottom = 60
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(8, size / 6))
	parent.add_child(l)
	return l


func _god() -> void:
	pl.max_hp = 999999.0
	pl.hp = 999999.0
	pl.max_chakra = 999999.0
	pl.chakra = 999999.0


func _calm(list: Array) -> void:
	for e in list:
		if is_instance_valid(e) and e.get("arch") != null:
			e.arch["jutsu"] = []   # rakip teknikleri dumanla kadrajı kapatmasın


func _closeui() -> void:
	Hud.close_dialog()
	ExamUI._resume()
	Hud.show_game_hud(false)


func _ready() -> void:
	process_priority = 1000
	await get_tree().process_frame
	Lang.apply("en")
	Combat.quiet = true   # hasar sayıları dikey kadrajda dev görünüyor
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	await _w(3.0)
	_closeui()
	var env = main.world.env
	env.time_of_day = 0.42
	env.region_weather = "açık"
	env.weather_t = 9999.0
	env.overcast = 0.0
	pl = main.player
	var pr = Game.profile
	pr["level"] = 40
	pl.apply_profile_stats()
	Gear.grant(pr, "goz_sharingan", "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "goz_sharingan", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.apply_look(pr)
	pl.rebuild_model()
	_god()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 62
	cam.far = 6000.0
	main.add_child(cam)
	env.attach_post(cam)
	cam.current = true
	var cl = CanvasLayer.new()
	cl.layer = 120
	add_child(cl)
	title = _lbl(cl, 50, Color(1.0, 0.82, 0.35), 0.30)
	sub = _lbl(cl, 30, Color(0.95, 0.95, 0.95), 0.37)
	cap = _lbl(cl, 36, Color(1.0, 0.86, 0.45), 0.80)
	title.modulate.a = 0.0
	sub.modulate.a = 0.0
	_caption("")
	ChuninExam.host = "konoha"
	ChuninExam.st = {"written": 8, "forest_days": 3.0, "prelim_wins": 0, "final_wins": 0, "jutsu": {}, "kawarimi": 0, "hp_lost": 0.0, "invasion": false, "mates_alive": 2}

	# --- 1) başlık: stadyum havadan
	var sp: Vector3 = ChuninExam.stadium_pos()
	sp.y = Game.terrain_height(sp.x, sp.z)
	pl.respawn(sp + Vector3(0, 1.0, 60))
	await _w(5.0)
	_cut("title", "a")
	title.text = "THE CHŪNIN EXAM"
	sub.text = "Chakra Warriors"
	var tw = create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(title, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.6)
	await _move(sp + Vector3(-170, 130, 210), sp + Vector3(-95, 85, 130), sp + Vector3(0, -10, 0), sp + Vector3(0, -5, -10), 3.0)
	_cut("title", "b")
	title.modulate.a = 0.0
	sub.modulate.a = 0.0

	# --- 2) Ölüm Ormanı: takımla koşu
	ChuninExam._forest()
	await _w(0.3)
	_closeui()
	await _w(4.0)
	_closeui()
	_god()
	var tower: Vector3 = ChuninExam.st["tower"]
	var to_t = tower - pl.global_position
	to_t.y = 0
	to_t = to_t.normalized()
	pl.yaw = rad_to_deg(atan2(-to_t.x, -to_t.z))
	Input.action_press("forward")
	await _w(1.2)
	var sd = to_t.cross(Vector3.UP).normalized()
	_cut("forest", "a")
	_caption("Forest of Death", Color(0.6, 1.0, 0.55))
	await _move(-to_t * 3.4 + sd * 0.9 + Vector3.UP * 2.0, -to_t * 3.0 - sd * 0.9 + Vector3.UP * 2.3, to_t * 6.0 + Vector3.UP * 1.3, to_t * 6.0 + Vector3.UP * 1.3, 2.4, pl)
	_cut("forest", "b")
	Input.action_release("forward")
	_caption("")

	# --- 3) parşömen kapma: kampa var, taşıyıcıyı yen
	var cp = ChuninExam.st["camps"][0]
	var tc = Vector3(cp["pos"][0], cp["pos"][1], cp["pos"][2])
	tc.y = Game.ground_height(tc.x, tc.z)
	pl.respawn(Missions.open_ground(tc + Vector3(9, 0, 0), 10.0) + Vector3.UP * 0.5)
	await _w(2.5)
	_god()
	var carrier = null
	for r in ChuninExam.rivals:
		if is_instance_valid(r) and r.has_meta("carries"):
			carrier = r
	for r in ChuninExam.rivals:
		if is_instance_valid(r) and r != carrier:
			r.queue_free()   # birebir parşömen kapışı (kalabalık kadrajı kapatıyordu)
	if carrier:
		carrier.global_position = Missions.open_ground(pl.global_position + pl.face_dir() * 6.0, 6.0)
	await _w(1.0)
	print("CAMP rivals=%d carrier=%s" % [ChuninExam.rivals.size(), carrier != null])
	if carrier:
		_cut("scroll", "a")
		_caption("Steal the enemy scroll", Color(1, 1, 1))
		await _brawl(carrier, 2.0, true)
		_cut("scroll", "b")
		await _jshot("raiton_chidori", "Chidori", carrier, 2.0, true, "j_chidori1", Color(0.7, 0.85, 1.0), 6.0)
		if is_instance_valid(carrier) and not carrier.is_dead():
			carrier.take_hit({"dmg": 1e7, "attacker": pl, "kind": "heavy", "knock": 6.0, "dir": pl.face_dir(), "melee": true})
		await _w(0.5)
		var fh = pl.face_dir()
		_cut("gotscroll", "a")
		_caption("Heaven Scroll acquired!", Color(1.0, 0.9, 0.5))
		await _move(fh * 3.0 + Vector3.UP * 2.6, fh * 2.4 + fh.cross(Vector3.UP) * 1.2 + Vector3.UP * 2.0, Vector3.UP * 1.2, Vector3.UP * 1.3, 1.1, pl)
		_cut("gotscroll", "b")
		_caption("")

	# --- 4) kule salonu: ön eleme
	pr["inventory"]["scroll_heaven"] = 1
	pr["inventory"]["scroll_earth"] = 1
	ChuninExam._prelims()
	await _w(2.5)
	_closeui()
	ChuninExam._next_prelim()
	await _w(0.5)
	_closeui()
	var duel = ChuninExam.st.get("duel")
	_calm([duel])
	await _w(1.0)
	_god()
	if duel and is_instance_valid(duel):
		var f2 = duel.global_position - pl.global_position
		f2.y = 0
		pl.global_position = duel.global_position - f2.normalized() * 5.0 + Vector3.UP * 0.3
		await _w(0.2)
		_cut("hall", "a")
		_caption("Preliminaries: 1 vs 1", Color(1, 0.65, 0.35))
		await _brawl(duel, 2.2, false)
		_cut("hall", "b")
		await _jshot("katon_goukakyuu", "Katon: Gōkakyū", duel, 2.4, false, "j_goka", Color(1.0, 0.6, 0.3), 9.0)
		_caption("")
		if is_instance_valid(duel) and not duel.is_dead():
			duel.take_hit({"dmg": 1e7, "attacker": pl, "kind": "heavy", "knock": 6.0, "dir": pl.face_dir(), "melee": true})
	await _w(3.0)
	_closeui()
	# ikinci ön eleme maçını atla: finale geç
	ChuninExam.st["prelim_i"] = 2
	var d2 = ChuninExam.st.get("duel")
	if d2 and is_instance_valid(d2):
		d2.queue_free()
	ChuninExam.st["duel"] = null
	await ChuninExam._to_finals()
	await _w(1.0)
	_closeui()

	# --- 5) stadyum finali
	pl.respawn(sp + Vector3(0, 1.0, 20))
	await _w(3.0)
	ChuninExam._finals()
	await _w(0.5)
	_closeui()
	ChuninExam._next_final()
	await _w(0.5)
	_closeui()
	var fd = ChuninExam.st.get("duel")
	_calm([fd])
	await _w(2.0)
	_god()
	if fd and is_instance_valid(fd):
		var f0 = fd.global_position - pl.global_position
		f0.y = 0
		pl.global_position = fd.global_position - f0.normalized() * 6.0 + Vector3.UP * 0.3
		await _w(0.2)
		var mid0 = (pl.global_position + fd.global_position) * 0.5 + Vector3.UP * 1.0
		_cut("finals", "a")
		_caption("The Finals", Color(1, 0.8, 0.4))
		await _move(mid0 + Vector3(-18, 20, 22), mid0 + Vector3(-7, 5, 10), mid0, mid0, 1.8)
		await _brawl(fd, 1.8, false)
		_cut("finals", "b")
		await _jshot("katon_housenka", "Katon: Hōsenka", fd, 2.2, false, "j_hosenka", Color(1.0, 0.6, 0.3), 8.0)
		await _jshot("raiton_chidori", "Chidori", fd, 2.0, false, "j_chidori2", Color(0.7, 0.85, 1.0), 6.0)
		if is_instance_valid(fd) and not fd.is_dead():
			fd.take_hit({"dmg": 1e7, "attacker": pl, "kind": "heavy", "knock": 6.0, "dir": pl.face_dir(), "melee": true})
		await _w(0.6)
		var fw = pl.face_dir()
		_cut("win", "a")
		_caption("Winner!", Color(1.0, 0.9, 0.5))
		await _move(fw * 3.0 + Vector3.UP * 1.6, fw * 4.2 + fw.cross(Vector3.UP) * 1.5 + Vector3.UP * 2.6, Vector3.UP * 1.3, Vector3.UP * 1.1, 1.4, pl)
		_cut("win", "b")
		_caption("")

	# --- 6) bitiş: Konoha havadan
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var cy = Game.terrain_height(c.x, c.z)
	var rock: Dictionary = Game.world_info.get("hokage_rock", {})
	var face_z = c.z - (float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"]))
	var top = Game.terrain_height(c.x, face_z - 40)
	pl.respawn(Vector3(c.x, Game.terrain_height(c.x, face_z + 200) + 2, face_z + 260))
	await _w(4.0)
	_cut("end", "a")
	title.text = "CHAKRA WARRIORS"
	sub.text = "Free fan game"
	title.modulate.a = 1.0
	sub.modulate.a = 1.0
	await _move(Vector3(c.x + 150, cy + 110, c.z + 250), Vector3(c.x + 60, cy + 190, c.z + 480), Vector3(c.x, cy + 10, c.z - 60), Vector3(c.x, top - 40, face_z), 3.5)
	_cut("end", "b")
	get_tree().quit()


## Yakın dövüş çekimi: oyuncu koşup kombo vurur, kamera ikisini yandan yüksekten görür (uzun çimin üstünden)
func _brawl(tgt: Node3D, dur: float, high: bool) -> void:
	if not is_instance_valid(tgt):
		return
	var f = tgt.global_position - pl.global_position
	f.y = 0
	f = f.normalized()
	var sd = f.cross(Vector3.UP).normalized()
	var h = 3.4 if high else 2.2
	tgt.max_hp = 60000.0   # çekim bitene kadar yumruklarla ölmesin (jutsu çekiminde kadrajda dursun); sonda tek darbeyle düşer
	tgt.hp = 60000.0
	pl.combat.lock_target = tgt
	_combo(tgt, dur)
	await _move(-f * 3.5 + sd * 3.5 + Vector3.UP * h, -f * 2.0 + sd * 4.5 + Vector3.UP * (h + 0.4), f * 2.5 + Vector3.UP * 0.9, f * 2.5 + Vector3.UP * 0.9, dur, pl)


## Jutsu çekimi (ilk Shorts'taki omuz üstü kadraj): rakip önde sabit durur, kamera oyuncunun arkasında yüksekte,
## teknik kadrajın ortasından rakibe gider. Çim kadrajı kapatmasın diye ormanda daha yüksek.
func _jshot(id: String, nm: String, tgt: Node3D, dur: float, high: bool, cut: String, col: Color, dist := 7.0) -> void:
	if not is_instance_valid(tgt):
		return
	_god()
	var f = tgt.global_position - pl.global_position
	f.y = 0
	f = f.normalized() if f.length() > 0.1 else pl.face_dir()
	var at = pl.global_position + f * dist
	var it = Interiors.inst
	if it and it.inside != "":
		at.y = pl.global_position.y   # kule salonu gökte kurulu: yer yüksekliği rakibi 1500 m aşağı koyuyordu
	else:
		at = Missions.open_ground(at, 3.0)
		at.y = Game.ground_height(at.x, at.z)
	tgt.global_position = at
	tgt.velocity = Vector3.ZERO
	tgt.set_physics_process(false)   # rakip yerinde dursun: teknik kadrajın ortasından ona gitsin
	pl.combat.face_to(tgt)
	pl.yaw = rad_to_deg(atan2(-f.x, -f.z))
	await _w(0.15)
	var sd = f.cross(Vector3.UP).normalized()
	var off = -f * 4.8 - sd * 1.4 + Vector3.UP * (3.2 if high else 2.6)
	var look = f * (dist * 0.6) + Vector3.UP * 1.0
	cam.global_position = pl.global_position + off
	cam.look_at(pl.global_position + look)
	_cut(cut, "a")
	_caption(nm, col)
	_cast(id, tgt)
	_watch(cut, tgt, dur)
	await _move(off, off + sd * 1.0 - f * 0.5 + Vector3.UP * 0.3, look, look + f * 1.0, dur, pl)
	_cut(cut, "b")
	_caption("")
	if is_instance_valid(tgt):
		tgt.set_physics_process(true)


## Çekim denetimi: rakip kadrajda mı, jutsu gerçekten aktif mi (kayıt bitince göz yerine sayıyla bakılır)
func _watch(cut: String, tgt: Node3D, dur: float) -> void:
	var seen := 0
	var fx_seen := 0
	var n := 0
	var t := 0.0
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		n += 1
		if is_instance_valid(tgt) and cam.is_position_in_frustum(tgt.global_position + Vector3.UP):
			seen += 1
		if get_tree().get_nodes_in_group("projectiles").size() > 0 or String(pl.combat.action) == "cast":
			fx_seen += 1
	print("SHOTCHK %s rakip_kadrajda=%d%% jutsu_aktif=%d/%d kare" % [cut, int(100.0 * seen / maxi(1, n)), fx_seen, n])


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


func _cast(id: String, tgt: Node3D) -> void:
	_god()
	if not is_instance_valid(tgt):
		return
	# önceki vuruşun toparlanması bitsin (meşgulken atış komutu yok sayılıyordu)
	for i in 40:
		if String(pl.combat.action) == "":
			break
		await get_tree().process_frame
	pl.combat.lock_target = tgt
	pl.combat.face_to(tgt)
	pl.combat.begin_cast(id)
	await get_tree().process_frame
	if String(pl.combat.action) != "cast":
		Jutsu.execute(pl, id, tgt)
		print("CASTCHK %s dogrudan" % id)
	else:
		print("CASTCHK %s muhurle" % id)
