extends Node
## Arayüz sekmeleri denetimi: ninja menüsünün her sekmesi + Kontroller + Ses ayarları, Türkçe ve İngilizce, görüntü + anahtar değerler.
## Kullanım: --test=res://tests/dbg_ui_tabs.gd --shots=<dizin>
var main: Node
const TABS := ["inv", "wardrobe", "eyes", "jutsu", "skills", "beasts", "summons", "relations", "missions", "paths"]


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "s1", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(2.5)
	for i in 180:   # dünya / çevre yüklenene kadar (yükleme ekranı her şeyi örter)
		if main.loading == null or not is_instance_valid(main.loading):
			break
		await _w(0.5)
	await _w(1.5)
	Hud.close_dialog()
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != main.player and Combat.hostile(main.player, f):
			f.queue_free()
	var pr = Game.profile
	pr["ryo"] = 12345
	if not pr.has("mastery"):
		pr["mastery"] = {}
	for k in ["ninjutsu", "taijutsu", "chakra", "dayaniklilik"]:
		pr["mastery"][k] = 42.3
	pr["mastery"]["kenjutsu"] = 26.0
	pr["mastery"]["hiz"] = 12.0
	Mastery.refresh_level(pr)
	pr["rank"] = 2
	main.player.apply_profile_stats()
	Gear.grant(pr, "goz_sharingan", "sag_goz", null, null, {"lvl": 2, "origin": "dogustan"})
	Gear.grant(pr, "tonfa", "", null, null)
	if not "konoha_senpu" in pr["learned"] and Data.jutsu.has("konoha_senpu"):
		pr["learned"].append("konoha_senpu")
	# --- anahtar değerler (gerçek formüllerle karşılaştırma)
	print("VAL power=%d (Mastery.power=%d) power_progress=%.3f mastery_total=%.1f" % [int(pr["level"]), Mastery.power(pr), Mastery.power_progress(pr), Mastery.total(pr)])
	print("VAL hp=%d/%d Stats.max_hp=%d  chakra=%d/%d Stats.max_chakra=%d  stamina_max=%d Stats.max_stamina=%d" % [int(main.player.hp), int(main.player.max_hp), int(Stats.max_hp(pr)), int(main.player.chakra), int(main.player.max_chakra), int(Stats.max_chakra(pr)), int(main.player.max_stamina), int(Stats.max_stamina(pr))])
	print("VAL rank=%s eff_rank=%d elements=%s" % [Data.RANKS[int(pr["rank"])], Gear.eff_rank(pr), ", ".join((pr["elements"] as Array).map(func(e): return Menus._el_name(String(e))))])
	print("VAL unlimited kunai=%s pill=%s salve=%s" % [Stats.unlimited("kunai"), Stats.unlimited("pill"), Stats.unlimited("salve")])
	print("VAL tonfa stats_text=%s desc=%s" % [Gear.stats_text("tonfa"), Gear.item("tonfa").get("desc", "")])
	for a in ["sage", "beast", "dojutsu", "substitute", "charge", "throw"]:
		print("KEY %s = %s  (%s)" % [a, Keys.name(a), Keys.label(a)])
	for t in LoadingScreen.tips():
		print("TIP %s: %s" % [t[0], t[1]])
	# jutsu şart metinleri: her öğrenme türünden bir örnek
	var seen := {}
	for jid in Data.jutsu.keys():
		var j = Data.jutsu[jid]
		if not j is Dictionary or jid in pr["learned"]:
			continue
		var lp = String(j.get("learn", ""))
		var kind = lp.split(":")[0]
		if seen.has(kind):
			continue
		seen[kind] = true
		print("LEARN [%s] %s -> %s" % [lp, String(j.get("name", jid)), Progress.can_learn(jid)])
	if Data.jutsu.has("konoha_senpu"):
		print("COST taijutsu konoha_senpu = %s ; katon_goukakyuu = %s" % [Menus._cost_text(Data.jutsu["konoha_senpu"]), Menus._cost_text(Data.jutsu.get("katon_goukakyuu", {}))])
	print("FX katon effects: %s" % Menus._jutsu_effects("katon_goukakyuu", Data.jutsu.get("katon_goukakyuu", {})))
	for lang in ["tr", "en"]:
		Lang.apply(lang)
		await _w(0.4)
		for tab in TABS:
			var picked = ""
			if tab == "jutsu":
				for jid in Data.jutsu.keys():
					if String(Data.jutsu[jid].get("learn", "") if Data.jutsu[jid] is Dictionary else "").begins_with("path:"):
						picked = jid
						break
			Menus.ninja_menu(main, tab, picked)
			await _w(0.9)
			await main.shot("%s_%s" % [lang, tab])
			print("SHOT %s_%s" % [lang, tab])
			Menus.clear()
		Menus.controls(func(): pass)
		await _w(0.8)
		await main.shot("%s_controls" % lang)
		Menus.clear()
		Menus._set_tab = "general"
		Menus.settings(func(): pass)
		await _w(0.3)
		Menus.settings_tab(2)
		await _w(0.8)
		await main.shot("%s_sound" % lang)
		Menus.clear()
		Game.settings["lang"] = lang
		main.resume()
		await _w(0.8)
		await main.shot("%s_hud" % lang)
	Lang.apply("tr")
	print("DONE")
	get_tree().quit()
