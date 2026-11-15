extends Node
## İngilizce seçiliyken oyun içi göstergeler (can çevresi, etkiler, alet / hap satırı, görev, pusula) çevrili mi: ekrandaki bütün yazıları döker.
var main: Node


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func dump(tag: String) -> void:
	var seen := {}
	var rx := RegEx.create_from_string("[çğıöşüÇĞİÖŞÜ]")
	var bad := 0
	for l in Hud.find_children("*", "", true, false):
		if (l is Label or l is Button or l is RichTextLabel) and l.is_visible_in_tree() and not l.is_queued_for_deletion():
			var t: String = l.text
			if not (l is RichTextLabel) and l.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
				t = l.tr(t)
			t = t.strip_edges()
			if t == "" or seen.has(t):
				continue
			seen[t] = true
			var tr_left = rx.search(t) != null
			if tr_left:
				bad += 1
			print("%s %s| %s" % [tag, "TR " if tr_left else "   ", t.replace("\n", " ⏎ ").left(200)])
	print("%s SONUC: Türkçe karakterli %d" % [tag, bad])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(3)
	var old_lang = Game.settings.get("lang", "")
	main.creator_state = {"slot": 97, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.25), "bottom": Color(0.2, 0.2, 0.25), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Game.settings["lang"] = "en"
	Lang.apply("en")
	Hud.show_game_hud(true)
	await frames(20)
	dump("A")
	for q in ["Yakın dövüş 12", "+1 Merhem", "Hız +15%, Menzil +10%", "Asker Hapı ×3", "Ganimet: Merhem ×2, Kunai ×3", "Ganimet: boş çıktı", "Uçuş bitti (chakra tükendi)", "Kaçak Sunagakure", "Asit Baloncukları", "Rüzgar Ülkesi", "RÜZGAR ÜLKESİ", "Haber: Rüzgar Ülkesi", "Kişilik: sessiz", "Hokage Kulesi", "Güç 12", "✓ Güç 12", "Slottan kullanılabilir: Fukuso: Asit Baloncukları  •  Fukuso Arashi", "İpucu: tuhaf izler. Yeri kendin bulmalısın."]:
		print("C ", q, " => ", Lang.t(q))
	# etkiler: bilinen bütün adlar
	var i := 0
	for n in Buffs.NAMES:
		Buffs.active[n] = {"t": 60.0, "mods": {["melee", "jutsu", "speed", "reach", "armor", "katon"][i % 6]: 1.2}}
		i += 1
	Buffs.active["henge"] = {"t": 60.0, "mods": {"stealth": true}}
	Hud.msg("Kunai alındı — artık sınırsız! [R] fırlat, [T] değiştir.")
	Hud.float_text("Kritik!", Color(1, 1, 1))
	await frames(20)
	dump("B")
	var d = OS.get_environment("SHOT")
	if d != "":
		get_viewport().get_texture().get_image().save_png(d)
	Buffs.active.clear()
	Game.settings["lang"] = "tr"
	Lang.apply("tr")
	Game.settings["lang"] = old_lang
	Game.apply_settings()
	get_tree().quit()
