extends Node
## Pein Rikudō: ceset al -> yola ata -> çağır -> bedenler yol teknikleriyle dövüşür -> Jigokudō diriltir -> geri gönder -> kayıt biçimi
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _foe(at: Vector3, lv: int, i: int) -> Enemy:
	var a = Enemy.archetype(["kumo", "kiri", "iwa", "suna"][i % 4], i)
	a["respawn"] = false
	a["no_world"] = true
	Stats.npc_ninja(a, lv, 1.0)
	var e = Enemy.new()
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = at
	e.home = at
	return e
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.2, 0.2, 0.3)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9
	var vs = Game.village("konoha")
	pl.respawn(Game.from_map(Vector2(float(vs["x"]) + float(vs["r"]) + 400.0, float(vs["y"]))) + Vector3(0, 1, 0))
	await _w(3.0)
	Hud.close_dialog()
	var pr = Game.profile
	var SP = LazyFx.g("SixPaths")
	print("SP rinnegan once=%s" % SP.has_rinnegan())
	Gear.grant(pr, "goz_rinnegan", "sag_goz", null, null, {"lvl": 3, "origin": "nakil"})
	Gear.grant(pr, "goz_rinnegan", "sol_goz", null, null, {"lvl": 3, "origin": "nakil"})
	Gear.apply_look(pr)
	pl.rebuild_model()
	await _w(1.0)
	print("SP rinnegan=%s" % SP.has_rinnegan())
	# 7 düşman öldür, cesetleri al
	var pp: Vector3 = pl.global_position
	var foes = []
	for i in 7:
		foes.append(_foe(pp + Vector3(cos(i * 0.9), 0, sin(i * 0.9)) * 6.0, 40 + i * 6, i))
	await _w(1.5)
	for e in foes:
		e.die({"attacker": pl})
	await _w(4.5)   # eskiden ceset 3 sn'de kalkıyordu
	var left = get_tree().get_nodes_in_group("pain_corpses").size()
	print("SP 4.5 sn sonra yerdeki alinabilir ceset=%d" % left)
	var took = 0
	for e in foes:
		if not is_instance_valid(e):
			continue
		pl.global_position = e.global_position + Vector3(1.5, 0.2, 0)
		var t0 = Time.get_ticks_msec()
		while SP.corpse_target != e and Time.get_ticks_msec() - t0 < 1500:
			await get_tree().process_frame
		if SP.corpse_target == e:
			SP.take(e)
			took += 1
		await _w(0.3)
	var d = SP.data()
	print("SP alinan=%d arsiv=%d yuvalar=%s" % [took, d["bodies"].size(), JSON.stringify(d["slots"])])
	for b in d["bodies"]:
		print("SP  beden %d %s guc=%d kayit=%d karakter" % [b["id"], b["name"], b["level"], String(b["arch"]).length()])
	# kayıt gidiş dönüşü (JSON)
	var back = JSON.parse_string(JSON.stringify(pr["six_paths"]))
	pr["six_paths"] = back
	print("SP json donus: yuva tendo=%s govde=%s" % [SP.slot_id("tendo"), not SP.body(SP.slot_id("tendo")).is_empty()])
	# yol değiştir: 7. bedeni Tendō'ya
	SP.assign("tendo", int(d["bodies"][6]["id"]))
	print("SP atama sonrasi yuvalar=%s" % JSON.stringify(SP.data()["slots"]))
	await _w(1.2)
	pl.chakra = pl.max_chakra
	PathJutsu.cast_path(pl, "pein_rikudo", null)
	await _w(2.5)
	var names = []
	for p in SP.PATHS:
		var e = SP._alive(p)
		names.append("%s=%s" % [p, (e.display_name + " can " + str(int(e.max_hp)) + " jutsu " + str(e.arch.get("jutsu", []))) if e else "-"])
	print("SP sahada %d: %s" % [SP.count_out(), " | ".join(names)])
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/sp_1.png")
	# düşman dalgası
	var c0 = pl.chakra
	var wave = []
	for i in 8:
		wave.append(_foe(pl.global_position + Vector3(cos(i * 0.8), 0, sin(i * 0.8)) * 18.0, 45, i))
	var used = {}
	var t1 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 30000:
		await _w(0.5)
		for p in SP.PATHS:
			var e = SP._alive(p)
			if e:
				for id in e.jcd:
					used["%s:%s" % [p, id]] = true
				if e.has_meta("tendo_until"):
					used["tendo:itme/cekme"] = true
		if Time.get_ticks_msec() - t1 > 12000 and Time.get_ticks_msec() - t1 < 12600:
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/sp_2.png")
	var alive_w = wave.filter(func(e): return is_instance_valid(e) and not e.is_dead()).size()
	print("SP 30 sn dovus: sahada %d beden, dusman kalan %d/8, chakra %.0f -> %.0f / %.0f" % [SP.count_out(), alive_w, c0, pl.chakra, pl.max_chakra])
	print("SP kullanilan teknikler: %s" % ", ".join(used.keys()))
	for e in wave:
		if is_instance_valid(e) and not e.is_dead():
			e.queue_free()
	# Jigokudō diriltmesi: Shuradō'yu öldür
	pl.chakra = pl.max_chakra
	if SP._alive("jigokudo") == null or SP._alive("shurado") == null:
		SP.down.clear(); SP.lost.clear()
		PathJutsu.cast_path(pl, "pein_rikudo", null)
		await _w(3.0)
	var sh = SP._alive("shurado")
	if sh and SP._alive("jigokudo"):
		sh.die({})
		var t2 = Time.get_ticks_msec()
		await _w(1.0)
		while SP._alive("shurado") == null and Time.get_ticks_msec() - t2 < 20000:
			await _w(0.3)
		print("SP Jigokudo diriltme: %s, %.1f sn" % ["OK" if SP._alive("shurado") else "YOK", (Time.get_ticks_msec() - t2) / 1000.0])
	else:
		print("SP diriltme denenemedi (shurado=%s jigokudo=%s)" % [sh != null, SP._alive("jigokudo") != null])
	# geri gönder
	pl.chakra = pl.max_chakra
	var n0 = SP.count_out()
	SP.down.clear()
	PathJutsu.cast_path(pl, "pein_rikudo", null)
	await _w(3.0)
	print("SP yeniden kullanim: %d -> %d beden" % [n0, SP.count_out()])
	if SP.count_out() > 0:
		PathJutsu.cast_path(pl, "pein_rikudo", null)
		await _w(1.5)
		print("SP geri gonder: %d beden" % SP.count_out())
	# chakra bitince
	PathJutsu.cast_path(pl, "pein_rikudo", null)
	await _w(3.0)
	pl.chakra = 1.0
	await _w(2.0)
	print("SP chakra bitti: sahada %d" % SP.count_out())
	get_tree().quit()
