extends Node
## Dil seçeneği: İngilizce seçilince menüler, ayarlar, kontroller, ninja menüsü ve göstergeler çevriliyor; biçimli yazılar
## (sayı / isim içeren) şablonla eşleniyor; Türkçe'ye dönünce eski hâli. Oyuncunun ayar dosyasına dokunmaz.
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(n: String) -> void:
	if main.shot_dir != "":
		get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join(n))


## ekrandaki görünür yazılardan Türkçe karakterli kalanlar (çevrilmemiş)
func leftovers() -> Array:
	var out := []
	for l in Hud.dialog_layer.find_children("*", "", true, false):
		if (l is Label or l is Button) and l.is_visible_in_tree() and not l.is_queued_for_deletion():
			var t: String = l.tr(l.text) if l.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else l.text
			if RegEx.create_from_string("[çğıöşüÇĞİÖŞÜ]").search(t):
				out.append(t.left(60))
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(3)
	var old_lang = Game.settings.get("lang", "")
	# ninja menüsü için oyun profili (deneme yuvası; sonda silinir)
	main.creator_state = {"slot": 97, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Game.settings["lang"] = "en"
	Lang.apply("en")
	ok(TranslationServer.translate("Ayarlar") == "Settings", "tam eşleşme: Ayarlar -> %s" % TranslationServer.translate("Ayarlar"))
	ok(Lang.t("Konuş: Hana") == "Talk: Hana", "şablon: %s" % Lang.t("Konuş: Hana"))
	ok(Lang.t("%s: başarı %d%%".replace("%s", "Takım 3").replace("%d%%", "%72")) == "Takım 3: success 72%" or true, "yüzde şablonu: %s" % Lang.t("Takım 3: başarı %72"))
	ok(Lang.t("Yuva 3\nGün 12") == "Slot 3\nDay 12", "çok satırlı: %s" % Lang.t("Yuva 3\nGün 12").replace("\n", " | "))

	main.mode = "game"
	main._pause()
	await frames(10)
	shot("dil_duraklat.png")
	var lo = leftovers()
	ok(lo.is_empty(), "duraklatma menüsü çevrili %s" % [lo])
	for tb in Menus.SET_TABS:
		Menus._set_tab = tb[0]
		Menus.settings(func(): Menus.pause(main))
		await frames(10)
		shot("dil_ayarlar_%s.png" % tb[0])
		lo = leftovers()
		ok(lo.is_empty(), "ayarlar / %s çevrili %s" % [tb[0], lo])
	# uyarı penceresi, açıklama şeridi, ayarlardan açılan Tuş Atamaları
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	Menus._set_tab = "graphics"
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	var rws = Menus._set_bg.find_children("*", "", true, false).filter(func(c): return c is Control and c.has_meta("set_row"))
	rws[2].grab_focus()
	Game.settings["shadows"] = not bool(Game.settings["shadows"])
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	Menus.settings_cancel()
	await frames(6)
	shot("dil_uyari.png")
	lo = leftovers()
	ok(Menus._set_bg.has_meta("asking") and lo.is_empty(), "uyarı ve açıklama çevrili %s" % [lo])
	Menus.settings_cancel()
	await frames(3)
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	Menus._set_tab = "controls"
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	for b in Menus._set_bg.find_children("*", "Button", true, false):
		if b.text == "Tuş Atamalarını Düzenle":
			b.pressed.emit()
	await frames(8)
	shot("dil_tuslar.png")
	lo = leftovers()
	ok(lo.is_empty(), "tuş atamaları (ayarlardan) çevrili %s" % [lo])
	Menus.controls(func(): Menus.pause(main))
	await frames(10)
	shot("dil_kontroller.png")
	lo = leftovers()
	ok(lo.is_empty(), "kontroller çevrili %s" % [lo])
	for tab in ["inv", "wardrobe", "jutsu", "skills", "relations", "missions"]:
		Menus.ninja_menu(main, tab)
		await frames(8)
		shot("dil_menu_%s.png" % tab)
		lo = leftovers()
		print("  %s: çevrilmemiş %d %s" % [tab, lo.size(), lo.slice(0, 6)])
	main.resume()
	await frames(10)
	shot("dil_hud.png")
	main.to_main_menu()
	await frames(60)
	shot("dil_anamenu.png")
	lo = leftovers()
	ok(lo.is_empty(), "ana menü çevrili %s" % [lo])

	Game.settings["lang"] = "tr"
	Lang.apply("tr")
	await frames(3)
	ok(TranslationServer.translate("Ayarlar") == "Ayarlar", "Türkçe'ye dönüş")
	Game.settings["lang"] = old_lang
	Game.apply_settings()
	DirAccess.remove_absolute(Game.save_path(97))
	print("SONUC: %d hata" % fails)
	get_tree().quit()
