extends Node
## Tuş atama: Kontroller ekranında tıkla -> yeni tuşa bas, çakışmada yer değiştirme, Esc ile vazgeçme, fare düğmesi,
## dosyaya yazılıp yeniden yüklenme, ekrandaki ipuçlarının yeni tuşu göstermesi. Oyuncunun tuş dosyası sonda geri konur.
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func find_btn(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		var r = find_btn(c, text)
		if r:
			return r
	return null


func key(k: int) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


func shot(n: String) -> void:
	if main.shot_dir != "":
		get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join(n))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(3)
	var had = FileAccess.file_exists(Keys.PATH)
	var orig = FileAccess.get_file_as_string(Keys.PATH) if had else ""
	Keys.reset_all()
	main.mode = "game"
	main._pause()
	Menus.controls(func(): Menus.pause(main))
	await frames(20)
	shot("kontroller_1.png")

	# 1) Zıpla'yı J'ye ata: J'deki Çağrı komutu Space'e geçmeli
	var b = find_btn(Hud.dialog_layer, "Space")
	ok(b != null, "Space düğmesi ekranda")
	b.pressed.emit()
	await frames(3)
	ok(Keys.capturing, "tıklayınca yeni tuş bekleniyor")
	get_viewport().push_input(key(KEY_J))
	await frames(4)
	ok(not Keys.capturing, "tuşa basınca bekleme bitti")
	ok(Keys.binds["jump"] == [KEY_J] and Keys.binds["summon_cmd"] == [KEY_SPACE], "çakışan tuşlar yer değiştirdi (%s / %s)" % [Keys.binds["jump"], Keys.binds["summon_cmd"]])
	ok(key(KEY_J).is_action("jump") and not key(KEY_SPACE).is_action("jump") and key(KEY_SPACE).is_action("summon_cmd"), "oyun girdisi yeni tuşla çalışıyor")
	ok(find_btn(Hud.dialog_layer, "J") != null, "ekran yenilendi, J görünüyor")
	shot("kontroller_2.png")

	# 2) Esc: vazgeç, hiçbir şey değişmez, menü açık kalır
	find_btn(Hud.dialog_layer, "R").pressed.emit()
	await frames(3)
	get_viewport().push_input(key(KEY_ESCAPE))
	await frames(4)
	ok(Keys.binds["throw"] == [KEY_R] and Game.paused and find_btn(Hud.dialog_layer, "R") != null, "Esc atamadan vazgeçiyor, Kontroller açık kalıyor")

	# 3) fare yan düğmesi
	var bm = find_btn(Hud.dialog_layer, "Sağ tık")
	bm.pressed.emit()
	await frames(3)
	var mb = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_XBUTTON1
	mb.pressed = true
	mb.position = Vector2(500, 500)
	get_viewport().push_input(mb)
	await frames(4)
	ok(Keys.binds["guard"] == [-8], "Blok fare 4'e atandı (%s)" % [Keys.binds["guard"]])

	# 4) Esc atanamaz
	ok(Keys.rebind("throw", 0, KEY_ESCAPE).contains("atanamaz") and Keys.binds["throw"] == [KEY_R], "Esc atanamıyor")

	# 5) ipuçları yeni tuşu gösteriyor
	Keys.rebind("charge", 0, KEY_P)
	ok(Keys.fix("Yeterli chakra yok! [C] ile chakra topla").contains("[P]"), "ipucu metni yeni tuşla: %s" % Keys.fix("[C] ile topla"))
	ok(Keys.fix("[S] Haydut avı") == "[S] Haydut avı", "dokunulmayan tuş ipucu değişmiyor")

	# 6) dosyadan yeniden yükle
	Keys.setup()
	ok(Keys.binds["jump"] == [KEY_J] and Keys.binds["guard"] == [-8] and Keys.binds["charge"] == [KEY_P], "atamalar kaydedilip yeniden yükleniyor")
	Menus.controls(func(): Menus.pause(main))
	await frames(10)
	shot("kontroller_3.png")

	# 7) varsayılana dön
	find_btn(Hud.dialog_layer, "Varsayılana Dön").pressed.emit()
	await frames(4)
	ok(Keys.binds["jump"] == [KEY_SPACE] and Keys.binds["guard"] == [-2] and key(KEY_SPACE).is_action("jump"), "varsayılana dön çalışıyor")

	# 8) Ayarlar'dan ve ana menüden erişim; ayarlardaki yarım değişiklik korunur
	var sens0 = float(Game.settings["sens"])
	Menus.settings(func(): Menus.pause(main))
	await frames(3)
	Game.settings["sens"] = 2.75
	var tb = find_btn(Hud.dialog_layer, "Tuş Atamaları")
	ok(tb != null, "Ayarlar'da Tuş Atamaları düğmesi var")
	tb.pressed.emit()
	await frames(4)
	ok(find_btn(Hud.dialog_layer, "Varsayılana Dön") != null and is_equal_approx(float(Game.settings["sens"]), 2.75), "Ayarlar'dan Kontroller açıldı, ayar değişikliği korunuyor")
	find_btn(Hud.dialog_layer, "Geri").pressed.emit()
	await frames(4)
	ok(Menus.settings_open() and is_equal_approx(float(Game.settings["sens"]), 2.75), "Geri: Ayarlar'a dönüldü")
	Menus.settings_cancel()
	await frames(3)
	ok(is_equal_approx(float(Game.settings["sens"]), sens0), "Ayarlar'dan kaydetmeden çıkınca değişiklik geri alınıyor")
	main.resume()
	main.to_main_menu()
	await frames(60)
	var mm = null
	for b2 in Hud.dialog_layer.find_children("*", "Button", true, false):
		if "Kontroller" in (b2 as Button).text and not b2.is_queued_for_deletion():
			mm = b2
	ok(mm != null, "ana menüde Kontroller var")
	if mm:
		mm.pressed.emit()
		await frames(10)
		ok(find_btn(Hud.dialog_layer, "Varsayılana Dön") != null, "ana menüden Kontroller açılıyor")
		shot("kontroller_anamenu.png")

	if had:
		var f = FileAccess.open(Keys.PATH, FileAccess.WRITE)
		f.store_string(orig)
		f.close()
	else:
		DirAccess.remove_absolute(Keys.PATH)
	Keys.setup()
	print("SONUC: %d hata" % fails)
	get_tree().quit()
