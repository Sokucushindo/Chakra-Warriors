extends Node
## YouTube Shorts çekimi (dikey 1080x1920, --write-movie ile kaydedilir). Her sahnenin başı/sonu "CUT <ad> <kare>" satırı:
## _tmp/shorts/cut.py bu satırlarla yükleme / ışınlanma aralarını atıp sahneleri birleştirir.
var main: Node
var cam: Camera3D
var cap: Label
var title: Label
var sub: Label
var pl


func _f() -> int:
	return Engine.get_frames_drawn()


func _cut(n: String, edge: String) -> void:
	print("CUT %s %s %d" % [n, edge, _f()])


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Kamera kaydırma: konum ve bakış noktası dur saniyede doğrusal (yumuşatılmış) geçer; follow verilirse hedefe göre
func _move(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, dur: float, follow: Node3D = null) -> void:
	var t := 0.0
	while t < dur:
		var k := smoothstep(0.0, 1.0, t / dur)
		var base := follow.global_position if follow else Vector3.ZERO
		cam.current = true
		cam.global_position = base + p0.lerp(p1, k)
		cam.look_at(base + l0.lerp(l1, k))
		await get_tree().process_frame
		t += get_process_delta_time()


func _caption(s: String, col := Color(1.0, 0.86, 0.45)) -> void:
	cap.text = s
	cap.add_theme_color_override("font_color", col)
	cap.modulate.a = 1.0 if s != "" else 0.0


func _ready() -> void:
	await get_tree().process_frame
	Lang.apply("en")
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var env = main.world.env
	env.time_of_day = 0.42
	env.region_weather = "açık"
	env.weather_t = 9999.0
	env.overcast = 0.0
	pl = main.player
	var pr = Game.profile
	pr["level"] = 80
	pl.apply_profile_stats()
	Gear.grant(pr, "goz_ems", "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "goz_ems", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "set_jonin", "set")
	Gear.apply_look(pr)
	pl.rebuild_model()
	Susanoo.config(pr)["mastery"] = 999.0
	_god()
	# kamera + yazı katmanı
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

	# --- 1) Konoha havadan + başlık
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var rock: Dictionary = Game.world_info.get("hokage_rock", {})
	var cn = float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"])
	var face_z = c.z - cn
	var gy = Game.terrain_height(c.x, face_z + 200)
	var top = Game.terrain_height(c.x, face_z - 40)
	pl.respawn(Vector3(c.x, gy + 2, face_z + 260))
	await _w(5.0)
	_cut("konoha", "a")
	var tw = create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(title, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.9)
	title.text = "CHAKRA WARRIORS"
	sub.text = "Open-world Naruto fan game"
	var cy = Game.terrain_height(c.x, c.z)
	await _move(Vector3(c.x - 80, cy + 170, c.z + 380), Vector3(c.x - 20, cy + 120, c.z + 120), Vector3(c.x, cy + 20, c.z - 100), Vector3(c.x, top - 50, face_z), 4.5)
	_cut("konoha", "b")
	title.modulate.a = 0.0
	sub.modulate.a = 0.0

	# --- 2) karakter yakın çekim (köy dışı açık arazi)
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	pl.respawn(field + Vector3.UP * 0.5)
	pl.yaw = 0.0
	await _w(4.0)
	_god()
	var eyes = pl.combat.modes.eyes
	eyes.toggle()
	await _w(0.5)
	pl.set_process(false)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	_cut("hero", "a")
	await _move(f * 2.2 + sd * 1.4 + Vector3.UP * 1.5, f * 1.6 - sd * 0.9 + Vector3.UP * 1.65, Vector3.UP * 1.45, Vector3.UP * 1.6, 2.6, pl)
	_cut("hero", "b")
	pl.set_process(true)

	# --- 3) gerçek dövüş: üç kaçak ninja
	var foes: Array = []
	for i in 3:
		var e = Enemy.new()
		var a = Enemy.archetype("rogue", 0)
		e.setup(a)
		get_tree().current_scene.add_child(e)
		e.global_position = pl.global_position + f * (9.0 + i * 2.5) + sd * (i - 1) * 4.0
		e.home = e.global_position
		foes.append(e)
	await _w(0.4)
	_cut("fight", "a")
	_caption("Real-time ninja combat", Color(1, 1, 1))
	pl.combat.lock_target = foes[0]
	# yakın dövüş kombosu: kamera omuz üstünden yana kayar
	_combo(foes[0], 4.0)   # arka planda sürer; kamera aynı anda kayar
	await _move(-f * 5.0 + sd * 2.2 + Vector3.UP * 2.6, -f * 3.0 - sd * 3.2 + Vector3.UP * 2.0, f * 6.0 + Vector3.UP * 1.2, f * 5.0 + Vector3.UP * 1.0, 4.2, pl)
	_caption("")
	await _cast_shot("katon_goukakyuu", "Katon: Gōkakyū no Jutsu", foes[1], 2.6, Vector3(5.5, 2.0, -4.0))
	await _cast_shot("raiton_chidori", "Chidori", foes[2], 2.2, Vector3(4.0, 1.6, 2.5))
	_cut("fight", "b")
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()

	# --- 4) jutsu kurgusu (hedef: kukla), hızlı kesmeler
	var shots := [
		["fuuton_rasenshuriken", "Fūton: Rasenshuriken", 2.3, Vector3(9.0, 3.0, -6.0)],
		["suiton_daibakufu_no_jutsu", "Suiton: Daibakufu no Jutsu", 2.6, Vector3(14.0, 6.0, -10.0)],
		["mokuton_mokuryu_no_jutsu", "Mokuton: Mokuryū no Jutsu", 2.4, Vector3(12.0, 5.0, -8.0)],
		["kirin", "Kirin", 2.4, Vector3(14.0, 6.0, -6.0)],
		["katon_goryuka_no_jutsu", "Katon: Gōryūka no Jutsu", 2.4, Vector3(10.0, 4.0, -6.0)],
		["shinra_tensei", "Shinra Tensei", 1.8, Vector3(8.0, 3.0, -5.0)],
	]
	for s in shots:
		await _dummy_shot(s[0], s[1], s[2], s[3])

	# --- 5) Susanoo (açık çöl)
	var sv = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(sv["x"] + 300, sv["y"] + float(sv["r"]) + 900)))
	await _w(4.0)
	_god()
	pl.set_process(false)
	if not eyes.active:
		eyes.toggle()
	Susanoo.config(pr).merge({"color": Susanoo.COLORS[0], "armor": 2, "face": 0, "weapon": "kilic"}, true)
	Susanoo.config(pr)["tier_pref"] = 5
	f = pl.face_dir()
	sd = f.cross(Vector3.UP).normalized()
	var h = float(Susanoo.TIER_HEIGHT[5])
	cam.global_position = pl.global_position + f * 6.0 + Vector3.UP * 1.6
	cam.look_at(pl.global_position + Vector3.UP * 1.5)
	await _w(0.3)
	_cut("susanoo", "a")
	_caption("Susanoo", Color(0.75, 0.55, 1.0))
	eyes._start_susanoo()
	await _move(f * 6.0 + Vector3.UP * 1.6, f * (h * 2.1 + 6.0) + sd * h * 0.5 + Vector3.UP * h * 0.5, Vector3.UP * 1.5, Vector3.UP * h * 0.55, 4.2, pl)
	_cut("susanoo", "b")
	_caption("")
	eyes._end_susanoo()
	pl.set_process(true)

	# --- 6) kuyruklu canavar: Shukaku
	var lair: Vector2 = TailedBeasts.LAIRS["shukaku"]
	pl.respawn(Game.from_map(lair + Vector2(0, -170)))
	await _w(3.0)
	for i in 40:
		if TailedBeasts.spawned.get("shukaku") != null:
			break
		await _w(0.5)
	await _w(2.0)
	_god()
	var b: TailedBeast = TailedBeasts.spawned.get("shukaku")
	print("BEAST var=", b != null)
	if b:
		var to_b = (b.global_position - pl.global_position)
		to_b.y = 0
		to_b = to_b.normalized()
		var bs = to_b.cross(Vector3.UP).normalized()
		var bh = float(b.height) if "height" in b else 30.0
		b.atk = ""
		b._begin("ball", 0.0)
		_cut("beast", "a")
		_caption("Tailed Beasts", Color(1.0, 0.75, 0.4))
		print("BEAST h=%.1f dist=%.1f" % [bh, b.global_position.distance_to(pl.global_position)])
		await _move(-to_b * bh * 3.4 + bs * bh * 1.2 + Vector3.UP * bh * 0.4, -to_b * bh * 3.0 - bs * bh * 0.9 + Vector3.UP * bh * 0.55, Vector3.UP * bh * 0.5, Vector3.UP * bh * 0.55, 4.0, b)
		_cut("beast", "b")
		_caption("")
		# mühürle → jinchūriki tam dönüşüm
		b.take_hit({"dmg": 1e7, "attacker": pl})
		await _w(2.5)
		TailedBeasts._finish_seal(b, "player")
		await _w(2.5)
		var clk: BeastCloak = pl.combat.modes.cloak
		TailedBeasts.add_trust(100.0)
		clk.set_level(6)
		await _w(2.2)
		pl.set_process(false)
		f = pl.face_dir()
		sd = f.cross(Vector3.UP).normalized()
		_cut("jin", "a")
		_caption("Giant battles", Color(1.0, 0.75, 0.4))
		clk.bomb_cd = 0.0
		clk._bomb()
		await _move(f * 85.0 + sd * 40.0 + Vector3.UP * 20.0, f * 95.0 - sd * 25.0 + Vector3.UP * 30.0, Vector3.UP * 12.0, f * 10.0 + Vector3.UP * 14.0, 3.6, pl)
		_cut("jin", "b")
		_caption("")
		clk.set_level(0)
		pl.set_process(true)

	# --- 7) bitiş: Konoha + başlık
	pl.respawn(Vector3(c.x, gy + 2, face_z + 260))
	await _w(5.0)
	_cut("end", "a")
	title.text = "CHAKRA WARRIORS"
	sub.text = "Free fan game\nUnofficial · not affiliated with the Naruto creators"
	title.modulate.a = 1.0
	sub.modulate.a = 1.0
	await _move(Vector3(c.x + 150, cy + 110, c.z + 250), Vector3(c.x + 60, cy + 190, c.z + 480), Vector3(c.x, cy + 10, c.z - 60), Vector3(c.x, top - 40, face_z), 3.5)
	_cut("end", "b")
	get_tree().quit()


func _lbl(parent: Node, size: int, col: Color, y: float) -> Label:
	var l = Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = y
	l.anchor_bottom = y
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.offset_left = 30
	l.offset_right = -30
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


## Oyuncu kilitli hedefe koşup kombo vurur (dövüşün kendi saldırı akışı)
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
	pl.combat.lock_target = tgt
	pl.combat.face_to(tgt)
	pl.combat.begin_cast(id)
	await get_tree().process_frame
	if String(pl.combat.action) == "":
		Jutsu.execute(pl, id, tgt)   # kapılı teknik (göz vb.): doğrudan


func _cast_shot(id: String, nm: String, tgt: Node3D, dur: float, rel: Vector3) -> void:
	if not is_instance_valid(tgt):
		return
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var off = sd * rel.x + Vector3.UP * rel.y + f * rel.z
	_caption(nm)
	_cast(id, tgt)
	var mid = (tgt.global_position - pl.global_position) * 0.5 + Vector3.UP * 1.3
	await _move(off, off * 1.15 + f * 1.5, mid, mid + f * 1.0, dur, pl)
	_caption("")


func _dummy_shot(id: String, nm: String, dur: float, rel: Vector3) -> void:
	for g in ["element_walls", "projectiles", "summons"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()
	_god()
	var dm = preload("res://scripts/actors/dummy.gd").new()
	main.actors.add_child(dm)
	var f = pl.face_dir()
	var tp = pl.global_position + f * 16.0
	tp.y = Game.ground_height(tp.x, tp.z)
	dm.global_position = tp
	pl.set_process(false)
	await _w(0.25)
	var sd = f.cross(Vector3.UP).normalized()
	var off = sd * rel.x + Vector3.UP * (rel.y + 4.0) + f * rel.z
	var look = f * 9.0 + Vector3.UP * 2.5
	cam.global_position = pl.global_position + off
	cam.look_at(pl.global_position + look)
	_cut("j_" + id, "a")
	_caption(nm)
	_cast(id, dm)
	await _move(off, off + sd * 1.5 + f * 2.0, look, look + f * 2.0, dur, pl)
	_cut("j_" + id, "b")
	_caption("")
	pl.set_process(true)
	dm.queue_free()
	await _w(1.2)
