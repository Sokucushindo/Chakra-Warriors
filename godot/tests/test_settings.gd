extends Node
## Ayarlar ekranı: pencere boyutu hatırlanıyor mu, Esc değişiklikleri geri alıyor mu, kaydet yazıyor mu,
## küçük pencere / büyük arayüz ölçeğinde "Kaydet ve Geri" ekranda kalıyor mu. Oyuncunun ayar dosyası sonda geri konur.
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func esc() -> void:
	var ev = InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	main._route(ev)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func find_btn(n: Node, text: String) -> Button:
	if n is Button and text in (n as Button).text and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		var r = find_btn(c, text)
		if r:
			return r
	return null


func live_children() -> int:
	var k := 0
	for c in Hud.dialog_layer.get_children():
		if not c.is_queued_for_deletion():
			k += 1
	return k


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(3)
	var had = FileAccess.file_exists(Game.SETTINGS_PATH)
	var orig_text = FileAccess.get_file_as_string(Game.SETTINGS_PATH) if had else ""
	var orig = Game.settings.duplicate(true)
	var s = Game.settings

	# 1) pencere boyutu: kaydet -> unut -> yükle
	s["display"] = "1600x900"
	s["fullscreen"] = false
	Game.save_settings()
	s["display"] = ""
	Game.load_settings()
	ok(Game.display_key() == "1600x900", "pencere boyutu yeniden yüklenince hatırlanıyor (%s)" % Game.display_key())

	# 2) ana menü: ayarlarda değiştir, Esc -> eski değerler, ana menü açık
	main.to_main_menu()
	await frames(60)   # ana menünün giriş animasyonu bitsin
	var before = s.duplicate(true)
	Menus.settings(func(): Menus.main_menu(main))
	await frames(3)
	s["sens"] = 2.5
	s["fov"] = 95.0
	s["shadows"] = not bool(s["shadows"])
	Game.set_quality(0)
	s["ui_scale"] = 1.3
	Game.apply_settings()
	Menus.settings(func(): Menus.main_menu(main))   # ok tuşu gibi: ekran yeniden çizilir, geri alma OLMAMALI
	await frames(3)
	ok(is_equal_approx(float(s["sens"]), 2.5) and int(s["quality"]) == 0, "yeniden çizim değişiklikleri silmiyor")
	esc()
	await frames(3)
	ok(s == before, "ana menü: Esc değişiklikleri geri alıyor")
	ok(is_equal_approx(get_tree().root.content_scale_factor, float(before["ui_scale"])), "ana menü: Esc arayüz ölçeğini geri alıyor")
	ok(not Menus.settings_open() and live_children() > 0 and find_btn(Hud.dialog_layer, "Ayarlar") != null, "ana menü: Esc sonrası ana menü açık")
	var cf = ConfigFile.new()
	cf.load(Game.SETTINGS_PATH)
	ok(is_equal_approx(float(cf.get_value("ayarlar", "sens", -1.0)), float(before["sens"])), "ana menü: Esc dosyaya yazmıyor")

	# 3) Kaydet ve Geri: dosyaya yazar, sonra Esc bir şey bozmaz
	Menus.settings(func(): Menus.main_menu(main))
	await frames(3)
	s["sens"] = 1.75
	s["display"] = "1366x768"
	find_btn(Hud.dialog_layer, "Kaydet ve Geri").pressed.emit()
	await frames(3)
	cf = ConfigFile.new()
	cf.load(Game.SETTINGS_PATH)
	ok(is_equal_approx(float(cf.get_value("ayarlar", "sens", -1.0)), 1.75) and String(cf.get_value("ayarlar", "display", "")) == "1366x768", "Kaydet ve Geri dosyaya yazıyor")
	ok(is_equal_approx(float(s["sens"]), 1.75) and not Menus.settings_open() and find_btn(Hud.dialog_layer, "Ayarlar") != null, "kaydedince değer kalıyor, ana menüye dönülüyor")

	# 4) oyun içi duraklatma: ayarlarda Esc -> duraklatma menüsü (oyun duraklı kalır), ikinci Esc -> oyuna dön
	main.mode = "game"
	main._pause()
	Menus.pause(main)
	await frames(3)
	before = s.duplicate(true)
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	s["music"] = 0.05
	s["invert_y"] = true
	esc()
	await frames(3)
	ok(s == before, "duraklatma: Esc değişiklikleri geri alıyor")
	ok(Game.paused and find_btn(Hud.dialog_layer, "Devam") != null, "duraklatma: Esc duraklatma menüsüne dönüyor")
	# ayarlardayken başka kısayol (Tab) menüyü kapatırsa da geri alınır
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	s["sfx"] = 0.01
	main.resume()
	await frames(3)
	ok(s == before and not Game.paused, "duraklatma: menü başka yolla kapanınca da geri alınıyor")
	main.mode = "menu"
	main.to_main_menu()
	await frames(3)

	# 5) sığma: küçük pencere + büyük arayüz ölçeği
	for cfg in [[Vector2i(1280, 720), 1.0], [Vector2i(1280, 720), 1.5], [Vector2i(1920, 1080), 1.0], [Vector2i(1920, 1080), 1.5]]:
		DisplayServer.window_set_size(cfg[0])
		s["ui_scale"] = cfg[1]
		get_tree().root.content_scale_factor = cfg[1]
		await frames(4)
		Menus.settings(func(): Menus.main_menu(main))
		await frames(30)
		var bg: Control = Menus._set_bg
		var btn = find_btn(Hud.dialog_layer, "Kaydet ve Geri")
		var br = btn.get_global_rect()
		var area = bg.get_global_rect()
		var sc: ScrollContainer = bg.find_children("*", "ScrollContainer", true, false)[0]
		var tag = "%dx%d ölçek %d%%" % [cfg[0].x, cfg[0].y, int(cfg[1] * 100)]
		ok(area.encloses(br), "%s: Kaydet ve Geri ekranda (düğme %s, ekran %s)" % [tag, str(br), str(area.size)])
		var panel: Control = sc.get_parent().get_parent()
		ok(area.encloses(panel.get_global_rect()), "%s: panel ekrana sığıyor (kaydırma %s)" % [tag, "var" if sc.get_v_scroll_bar().max_value > sc.get_v_scroll_bar().page + 1.0 else "yok"])
		print("  içerik boyu %d, alan boyu %d" % [int(sc.get_child(0).size.y) if sc.get_child_count() > 0 else -1, int(sc.size.y)])
		if sc.get_v_scroll_bar().max_value > sc.get_v_scroll_bar().page + 60.0:   # kaydırılmışken yeniden çizim: konum korunur
			sc.scroll_vertical = 50
			await frames(3)
			Menus.settings(func(): Menus.main_menu(main))
			await frames(6)
			bg = Menus._set_bg
			sc = bg.find_children("*", "ScrollContainer", true, false)[0]
			ok(sc.scroll_vertical == 50, "%s: yeniden çizimde kaydırma konumu korunuyor (%d)" % [tag, sc.scroll_vertical])
			sc.scroll_vertical = 0
			await frames(3)
		if main.shot_dir != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join("ayarlar_%dx%d_%d.png" % [cfg[0].x, cfg[0].y, int(cfg[1] * 100)]))
			sc.scroll_vertical = 100000
			await frames(4)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join("ayarlar_%dx%d_%d_alt.png" % [cfg[0].x, cfg[0].y, int(cfg[1] * 100)]))
		esc()
		await frames(3)

	# oyuncunun ayarlarını geri koy
	for k in orig:
		s[k] = orig[k]
	if had:
		var f = FileAccess.open(Game.SETTINGS_PATH, FileAccess.WRITE)
		f.store_string(orig_text)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SETTINGS_PATH))
	print("AYAR TESTI: %s (%d hata)" % ["TEMIZ" if fails == 0 else "HATA VAR", fails])
	get_tree().quit()
