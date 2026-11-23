extends "res://tests/shorts_kit.gd"
## Shorts: Akatsuki'ye katılma — mühürlü mağara, torii'de sınayan üye, sınav, içeride heykel, pelerin, mühür töreni.
## Akış tek zincir (çağrı -> sınav -> giriş -> yüzük -> tören), bu yüzden tek sahne; çekimler CUT ile ayrılır.

var d: Dictionary
var sl: Array


func scenes() -> Array:
	return ["aka"]


func setup_player(pr: Dictionary) -> void:
	pr["level"] = 120
	pl.apply_profile_stats()


func _sky(tod: float, weather: String) -> void:
	var env = main.world.env
	env.time_of_day = tod
	env.region_weather = weather
	env.weather = weather
	env.weather_t = 9999.0
	WorldDay.auto = false


## Örgütü elle kur (tc.gd ile aynı): dünyanın en güçlü 8 Kage olmayan ninjası kaçak + yüzük, lider Rinnegan
func _org() -> void:
	WorldAmbition.ensure()
	var ps = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and String(q.get("kage", "")) == "" and not q.get("missing", false))
	ps.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	d = WorldAkatsuki.D()
	sl = []
	sl.resize(10)
	sl.fill("")
	for i in 8:
		var p: Dictionary = ps[i]
		if not WorldPeople.is_rogue(p):
			WorldPeople.defect(p, "deneme")
		sl[i] = String(p["id"])
	d["leader"] = sl[0]
	d["slots"] = sl
	d["phase"] = "biju"
	WorldPeople.get_p(sl[0])["eye"] = [6, 3]
	d["cave"] = WorldAkatsuki._pick_cave()
	var fl = Exams.flags()
	fl["rogue"] = true
	fl["infamy"] = 99999


func s_aka() -> void:
	process_physics_priority = 1000   # sabitleme düşmanın kendi fizik adımından sonra
	Hud.root.visible = false   # afiş / pencere kadraja girmesin (yazılar kitin kendi katmanında)
	_org()
	var cp = WorldAkatsuki.cave_pos()
	WorldAkatsuki.tick(1.0)
	_sky(0.73, "yağmur")
	await _goto(cp + Vector3(0, 0, 70.0), 5.0)
	_sky(0.73, "yağmur")
	WorldAkatsuki.tick(1.0)
	await _w(1.0)
	var gate = Interact.items.filter(func(it): return String(it.get("kind", "")) == "aka_gate")[0]
	var gp: Vector3 = AkatsukiCave.gate_pos()
	print("AKA magara=%s kapi=%s" % [str(cp.round()), str(gp.round())])
	# çağrı: simsar mağarayı işaretler, sınayan üye torii'nin altına gelir
	WorldAkatsuki.invite_dialog()
	await _w(0.3)
	Hud.last_options[0]["cb"].call()
	Hud.close_dialog()
	await _w(0.5)
	var r = WorldAkatsuki.recruiter
	pl.global_position = gp + Vector3(0, 0.3, 12.0)
	pl.reset_physics_interpolation()
	await _w(2.5)
	if is_instance_valid(r):
		r.global_position = gp + Vector3(0, 0.2, 5.0)
		r.home = r.global_position
		foes.append(r)   # kit: rakip teknik / alet kullanmaz (rüzgâr hortumu kadrajı kapatıyordu)
		r.look_at(pl.global_position * Vector3(1, 0, 1) + Vector3(0, r.global_position.y, 0))
		pl.combat.face_to(r)
	print("AKA sinayan=%s" % str(is_instance_valid(r)))

	# 1) mağara: yağmurlu alacakaranlıkta yüksekten yavaş iniş
	_cut("cave", "a")
	_caption("A sealed cave...", Color(0.95, 0.35, 0.35))
	_watch("cave", func(): return gp + Vector3.UP * 6.0, 3.2)
	await _move(gp + Vector3(-30, 42, 105), gp + Vector3(-12, 13, 44), gp + Vector3(0, 20, -25), gp + Vector3(0, 9, -10), 3.2)
	_cut("cave", "b")
	# 2) mühür: kapıdaki 禁 etiketine yaklaşma
	_cut("seal", "a")
	_caption("Gofū Kekkai", Color(0.95, 0.35, 0.35))
	_watch("seal", func(): return gp + Vector3.UP * 4.0, 2.0)
	await _move(gp + Vector3(4, 4, 18), gp + Vector3(1.5, 4.5, 9), gp + Vector3(0, 5, 0), gp + Vector3(0, 4.5, 0), 2.0)
	_cut("seal", "b")
	# 3) sınayan: oyuncunun omzu üstünden, torii altında kızıl bulutlu pelerin
	if is_instance_valid(r):
		_pin(r, gp + Vector3(0, 0, 4.0))
		pl.combat.face_to(r)
		await get_tree().physics_frame
		await get_tree().physics_frame
		print("AKA konum oyuncu=%s sinayan=%s (kapiya gore)" % [str((pl.global_position - gp).round()), str((r.global_position - gp).round())])
		_cut("recruit", "a")
		_caption("Only ring bearers may pass.", Color(0.95, 0.35, 0.35))
		_watch("recruit", func(): return r.global_position + Vector3.UP * 1.5, 2.4)
		await _move(Vector3(0.45, 2.0, 2.6), Vector3(0.35, 1.8, 1.9), (r.global_position - pl.global_position) + Vector3.UP * 1.5, (r.global_position - pl.global_position) + Vector3.UP * 1.45, 2.4, pl)
		_cut("recruit", "b")
		# 4) sınav: düello başlar, oyuncu Gōkakyū atar
		WorldAkatsuki.gate(gate)
		await _w(0.2)
		if not Hud.last_options.is_empty():
			Hud.last_options[0]["cb"].call()
		Hud.close_dialog()
		r.hp = r.max_hp
		_pin(r, gp + Vector3(0, 0, 4.0))
		pl.combat.face_to(r)
		await get_tree().physics_frame
		var mid2 = (r.global_position + pl.global_position) * 0.5
		var sd = (r.global_position - pl.global_position).cross(Vector3.UP).normalized()
		var fw = (r.global_position - pl.global_position).normalized()
		var c0 = pl.global_position - fw * 4.5 + sd * 2.2 + Vector3.UP * 2.3
		var c1 = pl.global_position - fw * 3.2 + sd * 1.4 + Vector3.UP * 1.9
		cam.global_position = c0
		cam.look_at(r.global_position + Vector3.UP * 1.3)
		await _cast("katon_goukakyuu", r)
		var tw := 0.0
		while String(pl.combat.action) == "cast" and tw < 5.0:
			await get_tree().process_frame
			tw += get_process_delta_time()
		print("AKA duello oyuncu=%s sinayan=%s kamera=%s" % [str((pl.global_position - gp).round()), str((r.global_position - gp).round()), str((cam.global_position - gp).round())])
		_cut("duel", "a")
		_caption("Prove your worth.", Color(1.0, 0.6, 0.3))
		_watch("duel", func(): return r.global_position + Vector3.UP, 2.6)
		await _move(c0, c1, r.global_position + Vector3.UP * 1.3, r.global_position + Vector3.UP * 1.2, 2.6)
		_cut("duel", "b")
		_pins.clear()
		r.hp = r.max_hp * 0.4   # sınavı geç
		await _w(0.8)
		Hud.close_dialog()
		print("AKA sinav=%s" % str(d["me"]))
		if OS.get_environment("AKA_STOP") == "duel":
			return
		if String(d["me"].get("test", "")) != "pass":
			d["me"]["test"] = "pass"
			r.team = "neutral"
	else:
		d["me"] = {"test": "pass"}
	_clear_fx()
	# 5) içerisi: heykel aşağıdan yukarı
	WorldAkatsuki.gate(gate)
	await _w(5.0)
	var I = Interiors.inst
	print("AKA iceride=%s" % I.inside)
	Hud.close_dialog()
	var o = I.origin
	var st = o + Vector3(0, 0, -AkatsukiCave.STATUE_D)
	var tips = AkatsukiCave.statue.finger_tips()
	_cut("statue", "a")
	_caption("Ten rings.", Color(0.95, 0.35, 0.35))
	_watch("statue", func(): return st + Vector3(0, 30, 0), 3.4)
	await _move(o + Vector3(0, 2.5, -14), o + Vector3(0, 20, -44), st + Vector3(0, 10, 10), st + Vector3(0, 34, 6), 3.4)
	_cut("statue", "b")
	# 6) gölgeler: parmak uçlarındaki üyeler
	_cut("shades", "a")
	_caption("Ten rogues.", Color(0.95, 0.35, 0.35))
	_watch("shades", func(): return tips[7] + Vector3.UP * 1.2, 2.2)
	await _move(tips[7] + Vector3(7, 4.5, 13), tips[7] + Vector3(4, 3.5, 9), tips[7] + Vector3(0, 2.6, 0), tips[7] + Vector3(-1, 2.6, 0), 2.2)
	_cut("shades", "b")
	# 7) yüzük ve pelerin: heykelin önünde, alçaktan dönen kamera
	WorldAkatsuki._join()
	Hud.close_dialog()
	var stand = I.L(0, 0.2, AkatsukiCave.STATUE_D - 40.0)
	pl.global_position = stand
	pl.reset_physics_interpolation()
	var to_st = (st - stand) * Vector3(1, 0, 1)
	pl.look_at(stand - to_st, Vector3.UP)   # sırtı heykele, yüzü kameraya
	await _w(2.0)
	_cut("cloak", "a")
	_caption("Join the Akatsuki.", Color(0.95, 0.3, 0.3))
	_watch("cloak", func(): return pl.global_position + Vector3.UP * 1.2, 3.2)
	var fw = -to_st.normalized()
	var sw = fw.cross(Vector3.UP)
	await _move(fw * 3.2 + sw * 2.4 + Vector3.UP * 0.5, fw * 3.6 - sw * 2.2 + Vector3.UP * 0.8, Vector3.UP * 1.5, Vector3.UP * 1.9 - fw * 4.0, 3.2, pl)
	_cut("cloak", "b")
	# 8) mühür töreni: dokuz ejder, geniş açı (canavar şimdi teslim edilir: ejderler önceki çekimleri kaplamasın)
	_caption("")
	WorldAkatsuki.capture("shukaku", "deneme", [sl[2], sl[3]])
	AkatsukiCave.gather(I)
	await _w(0.6)
	WorldAkatsuki.ritual()
	await _w(1.2)
	_cut("ritual", "a")
	_caption("Hunt the tailed beasts.", Color(0.55, 0.75, 1.0))
	_watch("ritual", func(): return st + Vector3(0, 28, 20), 3.6)
	await _move(o + Vector3(-10, 4, -4), o + Vector3(-4, 10, -16), st + Vector3(0, 26, 10), st + Vector3(0, 32, 10), 3.6)
	_cut("ritual", "b")
	# 9) bitiş
	_caption("")
	_cut("end", "a")
	_titles("CHAKRA WARRIORS", "Free fan game")
	await _move(o + Vector3(-4, 10, -16), o + Vector3(0, 14, -6), st + Vector3(0, 32, 10), st + Vector3(0, 36, 10), 2.8)
	_cut("end", "b")


## Sınayanı yerinde sabitle (yapay zekâsı yürüyüp torii direğinin arkasına geçiyordu), yüzü oyuncuya.
## Fizik açık kalır (model fizik adımında kuruluyor); her kare konum + yön yeniden yazılır.
var _pins := {}
func _pin(r: Node3D, at: Vector3) -> void:
	at.y = Game.ground_height(at.x, at.z)
	_pins[r] = at


func _physics_process(_dt: float) -> void:
	for r in _pins.keys():
		if not is_instance_valid(r):
			_pins.erase(r)
			continue
		var at: Vector3 = _pins[r]
		r.global_position = at
		r.velocity = Vector3.ZERO
		var v = pl.global_position - at
		r.facing = atan2(-v.x, -v.z)
		if r.get("model") and is_instance_valid(r.model):
			r.model.rotation.y = r.facing
