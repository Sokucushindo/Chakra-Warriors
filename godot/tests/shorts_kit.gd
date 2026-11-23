extends Node
## Shorts / fragman kiti: her fragman testi bunu genişletir (extends "res://tests/shorts_kit.gd").
## - Sahneler ayrı fonksiyon (s_<ad>); SCENES=ad1,ad2 ortam değişkeniyle yalnız seçilenler çekilir (bozuk sahne tek başına yeniden).
## - Her çekim "CUT <ad> a/b <kare>" basar; kurgu tools/shorts_make.py (json sahne listesi).
## - Denetim: _watch her çekimde "SHOTCHK <ad> hedef_kadrajda=% jutsu_aktif=..." basar; jutsu atılmadıysa / hedef kadraj dışıysa sayıyla görünür.
## - Kamera takipte engel ışını: ağaç / duvar içine girmez. Rakipler teknik / alet / kawarimi kullanmaz (duman kadrajı kapatmasın).
var main: Node
var cam: Camera3D
var cap: Label
var title: Label
var sub: Label
var pl
var calm := true
var foes: Array = []


func landscape() -> bool:
	return false   # alt sınıf: yatay fragman (1920x1080) için true


func scenes() -> Array:
	return []   # alt sınıf: ["eye", "chibaku", ...] (s_<ad> fonksiyonları)


func _process(_dt: float) -> void:
	if cam and is_instance_valid(cam) and not cam.current:
		cam.current = true
	if calm:
		for e in foes + Exams.nodes + ChuninExam.rivals:
			if is_instance_valid(e) and e is Enemy:
				e.arch["jutsu"] = []
				e.arch["tools"] = false
				e.maki = 0
				e.sub_bars = 0.0
				e.sub_cd = 99.0
				if e.get("nameplate") and is_instance_valid(e.nameplate):
					e.nameplate.visible = false   # büyük kırmızı isim yazıları dikey kadrajı kaplıyordu


func _ready() -> void:
	process_priority = 1000
	await get_tree().process_frame
	Lang.apply("en")
	Combat.quiet = true
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
	setup_player(Game.profile)
	_god()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT if landscape() else Camera3D.KEEP_WIDTH
	cam.fov = 52.0 if landscape() else 62.0
	cam.far = 8000.0
	main.add_child(cam)
	env.attach_post(cam)
	cam.current = true
	var cl = CanvasLayer.new()
	cl.layer = 120
	add_child(cl)
	var L = landscape()
	title = _lbl(cl, 96 if L else 50, Color(1.0, 0.82, 0.35), 0.40 if L else 0.30)
	sub = _lbl(cl, 40 if L else 30, Color(0.95, 0.95, 0.95), 0.52 if L else 0.37)
	cap = _lbl(cl, 44 if L else 36, Color(1.0, 0.86, 0.45), 0.86 if L else 0.80)
	_titles("", "")
	_caption("")
	var want = OS.get_environment("SCENES")
	for s in scenes():
		if want != "" and not String(s) in want.split(","):
			continue
		print("SCENE ", s)
		await call("s_" + String(s))
		_caption("")
		_titles("", "")
		_clear_fx()
	get_tree().quit()


func setup_player(_pr: Dictionary) -> void:
	pass   # alt sınıf: seviye, göz, kıyafet


# ------------------------------------------------------------------ temel
func _cut(n: String, edge: String) -> void:
	print("CUT %s %s %d" % [n, edge, Engine.get_frames_drawn()])


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _god() -> void:
	pl.max_hp = 999999.0
	pl.hp = 999999.0
	pl.max_chakra = 999999.0
	pl.chakra = 999999.0


func _closeui() -> void:
	Hud.close_dialog()
	ExamUI._resume()
	Hud.show_game_hud(false)


func _clear_fx() -> void:
	for g in ["element_walls", "projectiles", "summons"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()


func _goto(at: Vector3, settle := 4.0) -> void:
	pl.respawn(at + Vector3.UP * 0.5)
	await _w(settle)
	_closeui()
	_god()


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


func _caption(s: String, col := Color(1.0, 0.86, 0.45)) -> void:
	cap.text = s
	cap.add_theme_color_override("font_color", col)
	cap.modulate.a = 1.0 if s != "" else 0.0


func _titles(t1: String, t2: String) -> void:
	title.text = t1
	sub.text = t2
	title.modulate.a = 1.0 if t1 != "" else 0.0
	sub.modulate.a = 1.0 if t2 != "" else 0.0


## Kamera yolu: p0->p1 konum, l0->l1 bakış; follow verilirse göreli ve engel ışınlı (ağaç / duvar içine girmez)
func _move(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, dur: float, follow: Node3D = null) -> void:
	var t := 0.0
	while t < dur:
		var k := smoothstep(0.0, 1.0, t / dur)
		var base := follow.global_position if follow and is_instance_valid(follow) else Vector3.ZERO
		var cp = base + p0.lerp(p1, k)
		if follow and is_instance_valid(follow):
			var from = follow.global_position + Vector3.UP * 1.3
			var q = PhysicsRayQueryParameters3D.create(from, cp)
			q.exclude = [follow.get_rid()]
			var hit = follow.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				cp = hit["position"] + (from - cp).normalized() * 0.4
		cam.current = true
		cam.global_position = cp
		cam.look_at(base + l0.lerp(l1, k))
		await get_tree().process_frame
		t += get_process_delta_time()


# ------------------------------------------------------------------ göz / düşman
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
	var eyes = pl.combat.modes.eyes
	if on and not eyes.active:
		eyes.toggle()
		if id in ["goz_ems", "goz_mangekyo"] and "ms_on" in eyes:
			eyes.ms_on = true
		await _w(1.1)


## Göz yakın çekimi (1 sn)
func _eye_shot(cut: String, nm: String, col: Color, dur := 1.2) -> void:
	pl.set_process(false)
	var em: MeshInstance3D = pl.model.eyes_mesh
	var hp = em.global_transform * em.get_aabb().get_center()
	var fd = pl.face_dir()
	var sdd = fd.cross(Vector3.UP).normalized()
	_cut(cut, "a")
	_caption(nm, col)
	var d0 = 0.40 if landscape() else 0.62
	var d1 = 0.30 if landscape() else 0.45
	await _move(hp + fd * d0 + sdd * 0.08, hp + fd * d1 - sdd * 0.04, hp, hp, dur)
	_cut(cut, "b")
	_caption("")
	pl.set_process(true)


## Eğitim kuklası (jutsu çekimlerinde hedef: kıpırdamaz, ölmez)
func _dummy(dist := 11.0) -> Node3D:
	var dm = preload("res://scripts/actors/dummy.gd").new()
	main.actors.add_child(dm)
	var tp = pl.global_position + pl.face_dir() * dist
	tp.y = Game.ground_height(tp.x, tp.z)
	dm.global_position = tp
	return dm


## Kuklaya jutsu (ilk Shorts'taki omuz üstü kadraj; büyük tekniklerde kamera geri ve yüksek)
func _dshot(id: String, nm: String, dur: float, big: bool, cut: String, col := Color(1.0, 0.86, 0.45)) -> void:
	_clear_fx()
	_god()
	var dm = _dummy(8.0 if landscape() else 11.0)
	await _w(0.25)
	var f = pl.face_dir()
	var sd = f.cross(Vector3.UP).normalized()
	var off = -f * (9.0 if big else 5.5) - sd * (1.6 if big else 1.0) + Vector3.UP * (5.0 if big else 3.0)
	var look = f * (10.0 if big else 6.0) + Vector3.UP * (3.0 if big else 0.6)
	if landscape():   # yatay kadraj geniş: kamera daha yakın ve alçak (karakter ve teknik büyük görünsün)
		off = -f * (4.6 if big else 2.9) - sd * (1.1 if big else 0.75) + Vector3.UP * (2.9 if big else 1.8)
		look = f * (6.5 if big else 4.6) + Vector3.UP * (1.9 if big else 1.1)
	cam.global_position = pl.global_position + off
	cam.look_at(pl.global_position + look)
	_cut(cut, "a")
	_caption(nm, col)
	await _cast(id, dm)
	# mühürlü teknik: el mühürleri bitip teknik çıkana kadar kamera yerinde bekler (süre mühürde dolup teknik kadraja girmiyordu)
	var tw := 0.0
	while String(pl.combat.action) == "cast" and tw < 5.0:
		cam.global_position = pl.global_position + off
		cam.look_at(pl.global_position + look)
		await get_tree().process_frame
		tw += get_process_delta_time()
	_cut(cut, "r")   # teknik çıktı (kurgu buradan biraz önce başlatır)
	_watch(cut, func(): return dm.global_position + Vector3.UP if is_instance_valid(dm) else null, dur)
	await _move(off, off + sd * 1.2 - f * 0.8 + Vector3.UP * 0.4, look, look + f * 1.5, dur, pl)
	_cut(cut, "b")
	_caption("")
	dm.queue_free()
	await _w(0.8)


func _foe(at: Vector3, kind := "rogue", hp := 60000.0) -> Enemy:
	var en = Enemy.new()
	var a = Enemy.archetype(kind, 0)
	a["jutsu"] = []
	a["respawn"] = false
	en.setup(a)
	get_tree().current_scene.add_child(en)
	var q = Missions.open_ground(at, 4.0)
	q.y = Game.ground_height(q.x, q.z)
	en.global_position = q
	en.home = q
	en.max_hp = hp
	en.hp = hp
	foes.append(en)
	return en


# ------------------------------------------------------------------ atış + denetim
func _cast(id: String, tgt: Node3D) -> void:
	_god()
	for i in 40:   # önceki vuruşun toparlanması bitsin (meşgulken atış komutu yok sayılıyordu)
		if String(pl.combat.action) == "":
			break
		await get_tree().process_frame
	if tgt and is_instance_valid(tgt):
		pl.combat.lock_target = tgt
		pl.combat.face_to(tgt)
	pl.combat.begin_cast(id)
	await get_tree().process_frame
	if String(pl.combat.action) != "cast":
		Jutsu.execute(pl, id, tgt)
		print("CASTCHK %s dogrudan" % id)
	else:
		print("CASTCHK %s muhurle" % id)


## Çekim denetimi: hedef (nokta) kadrajda mı, jutsu aktif mi — kayıt bitince sayıyla bakılır
func _watch(cut: String, look_at_fn: Callable, dur: float) -> void:
	var seen := 0
	var n := 0
	var t := 0.0
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		n += 1
		var p = look_at_fn.call()
		if p is Vector3 and cam.is_position_in_frustum(p):
			seen += 1
	print("SHOTCHK %s hedef_kadrajda=%d%%" % [cut, int(100.0 * seen / maxi(1, n))])


## Omuz üstü jutsu çekimi: hedef önde sabit, kamera arkada yüksek, teknik kadraj ortasından gider
func _jshot(id: String, nm: String, tgt: Node3D, dur: float, cut: String, col: Color, dist := 7.0, h := 2.6) -> void:
	if not is_instance_valid(tgt):
		return
	_god()
	var f = tgt.global_position - pl.global_position
	f.y = 0
	f = f.normalized() if f.length() > 0.1 else pl.face_dir()
	var at = Missions.open_ground(pl.global_position + f * dist, 3.0)
	at.y = Game.ground_height(at.x, at.z)
	tgt.global_position = at
	tgt.set_physics_process(false)
	pl.combat.face_to(tgt)
	pl.yaw = rad_to_deg(atan2(-f.x, -f.z))
	await _w(0.15)
	var sd = f.cross(Vector3.UP).normalized()
	var off = -f * 4.8 - sd * 1.4 + Vector3.UP * h
	var look = f * (dist * 0.6) + Vector3.UP * 1.0
	_cut(cut, "a")
	_caption(nm, col)
	await _cast(id, tgt)
	var tw := 0.0
	while String(pl.combat.action) == "cast" and tw < 5.0:   # mühürler bitene kadar bekle
		cam.global_position = pl.global_position + off
		cam.look_at(pl.global_position + look)
		await get_tree().process_frame
		tw += get_process_delta_time()
	_cut(cut, "r")
	_watch(cut, func(): return tgt.global_position + Vector3.UP if is_instance_valid(tgt) else null, dur)
	await _move(off, off + sd * 1.0 - f * 0.5 + Vector3.UP * 0.3, look, look + f * 1.0, dur, pl)
	_cut(cut, "b")
	_caption("")
	if is_instance_valid(tgt):
		tgt.set_physics_process(true)
