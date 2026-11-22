extends Node
## YouTube Shorts v2 (dikey, --write-movie; pencere boyutu godot/override.cfg ile 756x1344). Hızlı kesmeler:
## köy → gözler → kısa dövüş → el mühürleri → epik teknikler → düğün ara sahnesi → Susanoo → kuyruklu canavar → bitiş.
## Her sahne "CUT <ad> a/b <kare>"; RPG ekranları test_shorts_rpg.gd'den, kurgu _tmp/shorts/make.py.
var main: Node
var cam: Camera3D
var cap: Label
var title: Label
var sub: Label
var pl
var eyes


func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true


func _cut(n: String, edge: String) -> void:
	print("CUT %s %s %d" % [n, edge, Engine.get_frames_drawn()])


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


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


func _clear_fx() -> void:
	for g in ["element_walls", "projectiles", "summons"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()


func _ready() -> void:
	process_priority = 1000
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
	Gear.grant(pr, "set_jonin", "set")
	Susanoo.config(pr)["mastery"] = 999.0
	await _set_eye("goz_sharingan", false)
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

	# --- 1) Konoha havadan + başlık
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var rock: Dictionary = Game.world_info.get("hokage_rock", {})
	var cn = float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"])
	var face_z = c.z - cn
	var gy = Game.terrain_height(c.x, face_z + 200)
	var top = Game.terrain_height(c.x, face_z - 40)
	var cy = Game.terrain_height(c.x, c.z)
	pl.respawn(Vector3(c.x, gy + 2, face_z + 260))
	await _w(5.0)
	_cut("konoha", "a")
	title.text = "CHAKRA WARRIORS"
	sub.text = "Open-world Naruto fan game"
	var tw = create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(title, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.7)
	await _move(Vector3(c.x - 80, cy + 170, c.z + 380), Vector3(c.x - 30, cy + 130, c.z + 170), Vector3(c.x, cy + 20, c.z - 100), Vector3(c.x, top - 50, face_z), 3.2)
	_cut("konoha", "b")
	title.modulate.a = 0.0
	sub.modulate.a = 0.0

	# --- 2) gözler: yakın çekim, her göz 1 sn
	var field = Exams.find_point(["training"]) + Vector3(0, 0, 6)
	field.y = Game.ground_height(field.x, field.z)
	pl.respawn(field + Vector3.UP * 0.5)
	await _w(4.0)
	_god()
	for e in [["goz_sharingan", "Sharingan", Color(1, 0.45, 0.4)], ["goz_ems", "Mangekyō Sharingan", Color(1, 0.4, 0.35)],
			["goz_byakugan", "Byakugan", Color(0.85, 0.85, 1.0)], ["goz_rinnegan", "Rinnegan", Color(0.75, 0.6, 1.0)]]:
		await _set_eye(e[0], true)
		pl.set_process(false)
		var em: MeshInstance3D = pl.model.eyes_mesh
		var hp = em.global_transform * em.get_aabb().get_center()
		var fd = pl.face_dir()
		var sdd = fd.cross(Vector3.UP).normalized()
		_cut("eye_" + e[0], "a")
		_caption(e[1], e[2])
		await _move(hp + fd * 0.62 + sdd * 0.08, hp + fd * 0.45 - sdd * 0.04, hp, hp, 1.0)
		_cut("eye_" + e[0], "b")
		pl.set_process(true)
	_caption("")
	await _set_eye("goz_ems", true)   # Mangekyō açık kalsın (Amaterasu / Susanoo)

	# --- 3) kısa dövüş
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var foes: Array = []
	for i in 2:
		var en = Enemy.new()
		var a = Enemy.archetype("rogue", 0)
		a["jutsu"] = []
		en.setup(a)
		get_tree().current_scene.add_child(en)
		en.global_position = pl.global_position + f * (5.0 + i * 2.0) + sd * (i * 2 - 1) * 2.5
		en.home = en.global_position
		foes.append(en)
	await _w(0.3)
	_cut("fight", "a")
	_caption("Fast ninja combat", Color(1, 1, 1))
	pl.combat.lock_target = foes[0]
	_combo(foes[0], 2.4)
	await _move(-f * 4.0 + sd * 2.4 + Vector3.UP * 2.2, -f * 2.6 - sd * 2.8 + Vector3.UP * 1.8, f * 4.0 + Vector3.UP * 1.1, f * 4.0 + Vector3.UP * 1.0, 2.4, pl)
	await _cast_shot("raiton_chidori", "Chidori", foes[1], 1.8, Vector3(3.5, 1.5, 2.0))
	_cut("fight", "b")
	for en in foes:
		if is_instance_valid(en):
			en.queue_free()

	# --- 4) el mühürleri yakın çekim → Gōkakyū
	_clear_fx()
	var dm = _dummy()
	await _w(0.3)
	pl.set_process(true)
	f = pl.face_dir()
	sd = f.cross(Vector3.UP).normalized()
	_cut("seals", "a")
	_caption("Weave hand seals")
	_cast("katon_goukakyuu", dm)
	await _move(f * 1.7 + sd * 0.6 + Vector3.UP * 1.35, f * 2.6 + sd * 1.2 + Vector3.UP * 1.5, Vector3.UP * 1.15, Vector3.UP * 1.25, 2.4, pl)
	_cut("seals", "b")
	dm.queue_free()

	# --- 5) epik teknikler (dövüş kanından uzak temiz yer)
	pl.respawn(field + sd * 18.0 + Vector3.UP * 0.5)
	await _w(1.5)
	var shots := [
		["fuuton_rasenshuriken", "Fūton: Rasenshuriken", 1.8, Vector3(9.0, 3.0, -6.0)],
		["amaterasu", "Amaterasu", 1.8, Vector3(5.0, 1.0, 9.0)],
		["mokuton_mokuryu_no_jutsu", "Mokuton: Mokuryū", 1.9, Vector3(12.0, 5.0, -8.0)],
		["kirin", "Kirin", 2.2, Vector3(14.0, 6.0, -6.0)],
		["suiton_daibakufu_no_jutsu", "Suiton: Daibakufu", 2.0, Vector3(14.0, 6.0, -10.0)],
		["katon_goryuka_no_jutsu", "Katon: Gōryūka", 1.9, Vector3(10.0, 4.0, -6.0)],
		["shinra_tensei", "Shinra Tensei", 1.5, Vector3(8.0, 3.0, -5.0)],
	]
	for s in shots:
		await _dummy_shot(s[0], s[1], s[2], s[3])

	# --- 7) Susanoo (açık çöl)
	var sv = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(sv["x"] + 300, sv["y"] + float(sv["r"]) + 900)))
	await _w(4.0)
	_god()
	pl.set_process(false)
	eyes = pl.combat.modes.eyes
	if not eyes.active:
		eyes.toggle()
	Susanoo.config(pr).merge({"color": Susanoo.COLORS[0], "armor": 2, "face": 0, "weapon": "kilic"}, true)
	Susanoo.config(pr)["tier_pref"] = 5
	f = pl.face_dir()
	sd = f.cross(Vector3.UP).normalized()
	var h = float(Susanoo.TIER_HEIGHT[5])
	_cut("susanoo", "a")
	_caption("Susanoo", Color(0.75, 0.55, 1.0))
	eyes._start_susanoo()
	await _move(f * 6.0 + Vector3.UP * 1.6, f * (h * 2.1 + 6.0) + sd * h * 0.5 + Vector3.UP * h * 0.5, Vector3.UP * 1.5, Vector3.UP * h * 0.55, 3.0, pl)
	_cut("susanoo", "b")
	_caption("")
	eyes._end_susanoo()
	pl.set_process(true)

	# --- 8) kuyruklu canavar
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
	if b:
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
		await _move(-to_b * bh * 3.4 + bs * bh * 1.2 + Vector3.UP * bh * 0.4, -to_b * bh * 3.0 - bs * bh * 0.9 + Vector3.UP * bh * 0.55, Vector3.UP * bh * 0.5, Vector3.UP * bh * 0.55, 2.8, b)
		_cut("beast", "b")
		_caption("")

	# --- 9) düğün ara sahnesi (oyunun kendi tören sahnesi; görev sessizliği canavar doğuşunu durdurduğu için en sonda)
	await _wedding()

	# --- 10) bitiş
	pl.respawn(Vector3(c.x, gy + 2, face_z + 260))
	await _w(5.0)
	_cut("end", "a")
	title.text = "CHAKRA WARRIORS"
	sub.text = "Free fan game"
	title.modulate.a = 1.0
	sub.modulate.a = 1.0
	await _move(Vector3(c.x + 150, cy + 110, c.z + 250), Vector3(c.x + 60, cy + 190, c.z + 480), Vector3(c.x, cy + 10, c.z - 60), Vector3(c.x, top - 40, face_z), 3.5)
	_cut("end", "b")
	get_tree().quit()


## Göz tak (iki göz) ve isteğe göre aç
func _set_eye(id: String, on: bool) -> void:
	var pr = Game.profile
	var ey = pl.combat.modes.eyes if pl.combat and pl.combat.modes else null
	if ey and ey.active:
		ey.toggle()
		await _w(0.15)
	Gear.grant(pr, id, "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, id, "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.apply_look(pr)
	pl.rebuild_model()
	await _w(0.4)
	eyes = pl.combat.modes.eyes
	if on and not eyes.active:
		eyes.toggle()
		if id in ["goz_ems", "goz_mangekyo"] and "ms_on" in eyes:
			eyes.ms_on = true
		await _w(1.1)


func _wedding() -> void:
	var pr = Game.profile
	pl.model.apply_age("adult")
	var lk = ClanWorld.clan_look("", "genin", Progress.home(), true, "adult")
	var id = Friends._make_friend("Hana", "", lk, 90, "Sevgilin")
	var fr: Dictionary = Friends.all()[id]
	fr["romance"] = "sevgili"
	fr["love"] = 95
	fr["family"] = [{"rel": "Babası", "name": "Daichi", "alive": true}, {"rel": "Annesi", "name": "Yuki", "alive": true}]
	Wedding.plan(id)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var s = Wedding.site()
	pl.respawn(s + (pl.global_position - s).normalized() * 40.0 + Vector3.UP)
	await _w(2.5)
	Hud.close_dialog()
	var wd = Wedding.cur
	print("WED cur=", wd)
	if wd == null:
		return
	pl.global_position = wd.P(0, 14.0, 0.3)
	await _w(35.0)   # çift sunakta
	_cut("wed1", "a")
	_caption("Story cutscenes", Color(1, 0.8, 0.85))
	await _move(wd.P(0.0, 1.5, 2.0), wd.P(0.6, 2.6, 2.3), wd.P(0.0, -6.0, 1.5), wd.P(0.0, -5.0, 1.5), 1.8)
	_cut("wed1", "b")
	_caption("")
	await _w(23.0)   # kutlama
	_cut("wed2", "a")
	_caption("Marriage, family, legacy", Color(1, 0.8, 0.85))
	await _move(wd.P(0.0, 10.0, 4.0), wd.P(1.5, 8.0, 3.4), wd.P(0.0, -3.0, 1.4), wd.P(0.0, -3.0, 1.4), 1.8)
	_cut("wed2", "b")
	_caption("")
	Hud.close_dialog()


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


func _dummy() -> Node3D:
	var dm = preload("res://scripts/actors/dummy.gd").new()
	main.actors.add_child(dm)
	var f = pl.face_dir()
	var tp = pl.global_position + f * 11.0
	tp.y = Game.ground_height(tp.x, tp.z)
	dm.global_position = tp
	return dm


func _dummy_shot(id: String, nm: String, dur: float, rel: Vector3) -> void:
	_clear_fx()
	_god()
	var dm = _dummy()
	pl.set_process(false)
	await _w(0.25)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	# omuz üstü: karakter kadrajın altında önde, teknik ileri gider; büyük tekniklerde kamera geri ve yüksek
	var big = rel.x >= 12.0
	var off = -f * (9.0 if big else 5.5) - sd * (1.6 if big else 1.0) + Vector3.UP * (5.0 if big else 3.0)
	var look = f * (10.0 if big else 6.0) + Vector3.UP * (3.0 if big else 0.6)
	cam.global_position = pl.global_position + off
	cam.look_at(pl.global_position + look)
	_cut("j_" + id, "a")
	_caption(nm)
	_cast(id, dm)
	await _move(off, off + sd * 1.2 - f * 0.8 + Vector3.UP * 0.4, look, look + f * 1.5, dur, pl)
	_cut("j_" + id, "b")
	_caption("")
	pl.set_process(true)
	dm.queue_free()
	await _w(1.0)
