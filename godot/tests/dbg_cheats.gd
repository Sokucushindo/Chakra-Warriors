extends Node
## Ayarlar > Hileler: sekme görüntüleri (TR + EN) ve her hilenin gerçek etkisi. Deneme kayıt yuvası 96 (sonunda silinir).
## --shots=<dir>
var main: Node
const SLOT := 96
var fails := 0


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ok(name: String, cond: bool, extra := "") -> void:
	if not cond:
		fails += 1
	print("CHEAT %s %s %s" % ["OK  " if cond else "FAIL", name, extra])


func _settings_shots(tag: String) -> void:
	Menus._set_tab = "cheats"
	for i in 5:
		Menus._set_scroll = i * 820
		Menus.settings(func(): main.resume())
		await _w(0.6)
		await main.shot("cheats_%s_%d" % [tag, i])


func _enemy(at: Vector3) -> Node:
	var e := Enemy.new()
	e.setup(Enemy.archetype("rogue", 1))
	main.actors.add_child(e)
	e.global_position = at
	return e


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": SLOT, "name": "Hile Deneme", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(3.0)
	var t_load = Time.get_ticks_msec()
	while main.get("loading") != null and Time.get_ticks_msec() - t_load < 60000:
		await _w(0.5)
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	var pr = Game.profile
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != pl and Combat.hostile(pl, f):
			f.queue_free()
	# ---- menü: Ayarlar > Hileler (TR)
	var lang0 = Game.lang()
	Lang.apply("tr")
	Menus.settings(func(): main.resume())
	await _w(0.4)
	await _settings_shots("tr")
	# arayüzden aç: Ölümsüzlük satırının sağ oku
	Menus._set_scroll = 0
	Menus.settings(func(): main.resume())
	await _w(0.4)
	var pressed := false
	for l in Hud.dialog_layer.find_children("*", "Label", true, false):
		if l.text == "Ölümsüzlük":
			var row = l.get_parent().get_parent()
			var bs = row.find_children("*", "Button", true, false)
			if not bs.is_empty():
				bs[bs.size() - 1].pressed.emit()
				pressed = true
			break
	await _w(0.3)
	_ok("ui_toggle_god", pressed and Cheats.on("god"))
	# ---- EN
	Lang.apply("en")
	await _w(0.3)
	await _settings_shots("en")
	Lang.apply(lang0)
	main.resume()
	await _w(0.5)

	# ---- açık / kapalı hileler
	# ölümsüzlük
	var e0 = _enemy(pl.global_position + Vector3(0, 0, -3))
	e0.set_physics_process(false)
	pl.hp = pl.max_hp
	pl.take_hit({"dmg": 80.0, "attacker": e0, "kind": "heavy", "knock": 8.0})
	pl.combat.take_hit({"dmg": 80.0, "attacker": e0})
	await get_tree().physics_frame
	_ok("god_hit", pl.hp >= pl.max_hp, "hp=%.0f/%.0f" % [pl.hp, pl.max_hp])
	pl.hp = 0.0
	Progress.on_player_died()
	_ok("god_no_death", pl.hp >= pl.max_hp)
	await main.shot("hud_cheat_indicator")
	# tek vuruş
	Cheats.set_on("onehit", true)
	e0.max_hp = 50000.0; e0.hp = 50000.0
	e0.take_hit({"dmg": 1.0, "attacker": pl, "kind": "light", "sure": true})
	await _w(0.2)
	_ok("onehit", e0.dead or e0.hp <= 0.0, "hp=%.0f" % e0.hp)
	var e1 = _enemy(pl.global_position + Vector3(0, 0, -3))
	e1.set_physics_process(false)
	Cheats.set_on("onehit", false)
	e1.take_hit({"dmg": 1.0, "attacker": pl, "kind": "light", "sure": true})
	_ok("onehit_off", not e1.dead, "hp=%.0f" % e1.hp)
	e1.queue_free()
	# chakra / dayanıklılık / bekleme
	Cheats.set_on("chakra", true)
	Cheats.set_on("stamina", true)
	Cheats.set_on("nocd", true)
	var n_k = Cheats.unlock("el:katon")
	var jid := ""
	for k in pr["learned"]:
		if String(Data.jutsu.get(k, {}).get("element", "")) == "katon" and int(Data.jutsu[k].get("level", 99)) <= 10 and float(Data.jutsu[k].get("cost", 0)) > 5.0:
			jid = k
			break
	pl.chakra = 5.0
	pl.spend_stamina(60.0)
	pl.combat.cooldowns["deneme"] = 30.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("inf_chakra", pl.chakra >= pl.max_chakra, "%.0f/%.0f" % [pl.chakra, pl.max_chakra])
	_ok("inf_stamina", pl.stamina >= pl.max_stamina)
	_ok("no_cd", pl.combat.cooldowns.is_empty())
	if jid != "":
		Cheats.set_power(100)
		pl.combat.begin_cast(jid)
		await _w(2.0)
		_ok("cast_" + jid, pl.chakra >= pl.max_chakra and float(pl.combat.cooldowns.get(jid, 0.0)) <= 0.0, "chakra=%.0f cd=%s" % [pl.chakra, str(pl.combat.cooldowns.get(jid, 0.0))])
	else:
		_ok("cast_found_jutsu", false)
	# görünmezlik (önce kapalıyken fark eder mi)
	var e2 = _enemy(pl.global_position + Vector3(12, 0, 0))
	await _w(2.5)
	var seen_off = e2.target == pl
	Cheats.set_on("invis", true)
	await _w(1.5)
	_ok("invisible", seen_off and e2.target != pl, "kapalıyken gördü=%s açıkken hedef=%s" % [seen_off, e2.target])
	Cheats.set_on("invis", false)
	e2.queue_free()
	# Ryō
	Cheats.set_on("ryo", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("inf_ryo", int(pr["ryo"]) >= 1000000)
	Cheats.add_ryo()
	# hız / zıplama
	Cheats.set_on("speed", true)
	Cheats.set_on("jump", true)
	pl.grounded = true
	pl.wall_n = Vector3.ZERO
	pl.input_locked = 0.0
	pl._jump()
	_ok("super_jump", absf(pl.velocity.y - Player.JUMP * 2.0) < 0.1, "vy=%.1f" % pl.velocity.y)
	_ok("super_speed", Cheats.speed_mul() == 2.5)
	Cheats.set_on("jump", false)
	Cheats.set_on("speed", false)
	await _w(1.5)
	# uçuş
	Cheats.set_on("fly", true)
	await _w(0.4)
	_ok("fly_on", pl.fly_src == "hile" and pl.collision_mask == 0)
	await main.shot("fly")
	Cheats.set_on("fly", false)
	await _w(0.2)
	_ok("fly_off", pl.fly_src == "" and pl.collision_mask == 1)
	# mod bedeli (Sekiz Kapı can yemesin): ölümsüzlük kapalıyken
	Cheats.set_on("god", false)
	Cheats.set_on("nomodecost", true)
	pr["skills"].append("gates")
	pl.combat.modes.gates = 5
	pl.hp = pl.max_hp * 0.5
	var h0 = pl.hp
	await _w(1.0)
	_ok("gates_free", pl.hp >= h0 and pl.combat.modes.gates == 5, "hp %.1f -> %.1f" % [h0, pl.hp])
	Cheats.set_on("nomodecost", false)
	var h1 = pl.hp
	await _w(1.0)
	_ok("gates_cost_back", pl.hp < h1 or pl.combat.modes.gates == 0, "hp %.1f -> %.1f" % [h1, pl.hp])
	pl.combat.modes.gates = 0
	Buffs.remove("gates")
	Cheats.set_on("god", true)

	# ---- gözler
	var ey = pl.combat.modes.eyes
	for i in Cheats.EYES.size():
		var e: Array = Cheats.EYES[i]
		Cheats.give_eye(i, 2, i)
		var r = Gear.equipped(pr, "sag_goz")
		var l = Gear.equipped(pr, "sol_goz")
		var kind = int(Gear.item(e[0]).get("eye", {}).get("kind", 0))
		_ok("eye_" + String(e[2]), r.get("id") == e[0] and l.get("id") == e[0] and int(r.get("lvl", 0)) == int(e[1]) and ey._raw_kind("sag") == kind,
			"look=%s style=%s eyejutsu=%d" % [str(pr["look"].get("eye_r", {}).get("kind") if pr["look"].get("eye_r") is Dictionary else null), r.get("ms_style", "-"),
			(pr["learned"] as Array).filter(func(k): return String(Data.jutsu.get(k, {}).get("learn", "")).begins_with("eye:")).size()])
		if i == 3:
			ey.toggle()
			await _w(0.6)
			ey.open_ms()
			await _w(0.8)
			await main.shot("eye_ms")
			Cheats.set_on("noblind", true)
			pr["ms_blind"] = 0.5
			await get_tree().physics_frame
			await get_tree().physics_frame
			ey.add_blind(0.3)
			_ok("no_blind", float(pr.get("ms_blind", 0.0)) == 0.0)
			Cheats.set_on("noblind", false)
			ey._close()
		if i == 5:
			await _w(0.3)
			await main.shot("eye_rinnegan_given")
	# tek göz
	Cheats.give_eye(6, 1, 0)
	_ok("eye_left_only", Gear.equipped(pr, "sol_goz").get("id") == "goz_byakugan" and Gear.equipped(pr, "sag_goz").get("id") == "goz_jogan")

	# ---- jutsu
	print("CHEAT katon grubu: +%d" % n_k)
	for gid in ["kg:mokuton", "clan:uchiha", "sage", "eye", "weapon"]:
		var b = (pr["learned"] as Array).size()
		var n = Cheats.unlock(gid)
		print("CHEAT unlock %s +%d (toplam %d -> %d)" % [gid, n, b, (pr["learned"] as Array).size()])
	_ok("kg_mokuton_nature", Progress.has_nature("mokuton"))
	_ok("sage_skill", "sage" in pr["skills"])
	var np = Cheats.learn_paths()
	var joined = LegendPaths.PATHS.keys().filter(func(p): return LegendPaths.joined(p)).size()
	_ok("paths", joined == LegendPaths.PATHS.size() and np > 0, "+%d jutsu, %d/%d yol" % [np, joined, LegendPaths.PATHS.size()])
	var na = Cheats.unlock("all")
	var total = Data.jutsu.keys().filter(func(k): return not String(k).begins_with("_") and Data.jutsu[k] is Dictionary).size()
	_ok("unlock_all", (pr["learned"] as Array).size() >= total - 60, "+%d -> %d / %d" % [na, (pr["learned"] as Array).size(), total])

	# ---- güç / ustalık / rütbe
	Cheats.set_power(60)
	_ok("power60", int(pr["level"]) == 60, "Güç %d hp=%.0f" % [int(pr["level"]), pl.max_hp])
	Cheats.set_power(200)
	_ok("power200", int(pr["level"]) == 200, "Güç %d hp=%.0f chakra=%.0f" % [int(pr["level"]), pl.max_hp, pl.max_chakra])
	Cheats.set_all_mastery(150.0)
	_ok("mastery_all", Mastery.KEYS.all(func(k): return Mastery.get_v(pr, k) == 150.0), "Güç %d" % int(pr["level"]))
	Cheats.set_rank(3)
	await _w(0.5)
	_ok("rank_jonin", int(pr["rank"]) == 3)
	Hud.close_dialog()

	# ---- jinchūriki
	var free = TailedBeasts.free_beasts()
	if free.is_empty():
		_ok("jinchuriki (serbest canavar yok)", true)
	else:
		Cheats.become_jinchuriki(free[0])
		Cheats.full_bond()
		_ok("jinchuriki_" + free[0], TailedBeasts.player_jinchuriki() == free[0] and "jinchuriki" in pr["skills"] and TailedBeasts.trust(free[0]) >= 100.0)
	await _w(0.5)
	Hud.close_dialog()

	# ---- eşya
	var ws = Cheats.items("w")
	Cheats.give_item("w", ws[0][0], true)
	_ok("give_weapon_equip", Gear.equipped(pr, "sag").get("id") == ws[0][0], ws[0][1])
	var k0 = int(pr["inventory"].get("kunai", 0))
	Cheats.give_item("tool", "kunai", false)
	_ok("give_tool", int(pr["inventory"].get("kunai", 0)) == k0 + 10)
	var nb = Cheats.give_all("back")
	_ok("give_all_back", nb > 0, "%d sırt eşyası" % nb)
	for c in Cheats.ITEM_CATS:
		print("CHEAT eşya türü %s: %d" % [c[1], Cheats.items(c[0]).size()])

	# ---- dünya
	Cheats.set_time(0.9)
	Cheats.set_weather("yağmur")
	await _w(1.0)
	_ok("time", absf(Game.world.env.time_of_day - 0.9) < 0.01)
	_ok("weather", Game.world.env.weather == "yağmur")
	await main.shot("night_rain")
	Cheats.set_weather("")
	Cheats.set_time(0.45)
	var places = Cheats.places()
	var mi := -1
	for i in places.size():
		if places[i][0] == "m":
			mi = i
			break
	var p0 = pl.global_position
	Cheats.teleport(mi)
	await _w(1.0)
	var want = Game.from_map(Vector2(places[mi][1], places[mi][2]))
	_ok("teleport_landmark", Vector2(pl.global_position.x - want.x, pl.global_position.z - want.z).length() < 150.0 and pl.global_position.distance_to(p0) > 200.0, String(places[mi][3]))
	var vi := -1
	for i in places.size():
		if places[i][0] == "v" and places[i][1] == "suna":
			vi = i
	Cheats.teleport(vi)
	var t0 = Time.get_ticks_msec()
	var vc = Game.village("suna")
	var vpos = Game.from_map(Vector2(vc["x"], vc["y"]))
	while Time.get_ticks_msec() - t0 < 60000 and Vector2(pl.global_position.x - vpos.x, pl.global_position.z - vpos.z).length() > float(vc["r"]) * 2.0 + 100.0:
		await _w(0.5)
	_ok("teleport_suna", Vector2(pl.global_position.x - vpos.x, pl.global_position.z - vpos.z).length() < float(vc["r"]) * 2.0 + 100.0, "%.1f sn" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await _w(1.5)
	await main.shot("suna_after_teleport")
	print("CHEAT kayıt hileli=%s" % pr["flags"].get("cheated", false))
	print("CHEAT SONUÇ fails=%d" % fails)
	Game.delete_slot(SLOT)
	get_tree().quit()
