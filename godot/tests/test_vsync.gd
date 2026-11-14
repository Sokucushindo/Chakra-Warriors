extends Node
## Ayarlar > Görüntü: dikey eşitleme ve FPS sınırı ◀ ▶ ile hemen uygulanıyor, Esc geri alıyor, kaydedilip yükleniyor.
## Oyuncunun ayar dosyası sonda geri konur.
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


## başlık etiketinin satırındaki ◀ / ▶ düğmesi
func arrow(title: String, right: bool) -> Button:
	for l in Hud.dialog_layer.find_children("*", "Label", true, false):
		if (l as Label).text == title and not l.is_queued_for_deletion():
			var bs = l.get_parent().find_children("*", "Button", false, false)
			return bs[1] if right else bs[0]
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(3)
	var had = FileAccess.file_exists(Game.SETTINGS_PATH)
	var orig_text = FileAccess.get_file_as_string(Game.SETTINGS_PATH) if had else ""
	var s = Game.settings
	for k in Game.settings_defaults:
		s[k] = Game.settings_defaults[k]
	Game.apply_graphics()
	Game.apply_frame()
	main.mode = "game"
	main._pause()
	Menus.settings(func(): Menus.pause(main))
	await frames(5)
	ok(arrow("Dikey eşitleme (VSync)", true) != null and arrow("FPS sınırı", true) != null, "Ayarlar'da dikey eşitleme ve FPS sınırı satırları var")
	arrow("Dikey eşitleme (VSync)", true).pressed.emit()
	await frames(3)
	ok(not s["vsync"] and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "dikey eşitleme kapandı ve hemen uygulandı")
	arrow("FPS sınırı", true).pressed.emit()
	await frames(2)
	arrow("FPS sınırı", true).pressed.emit()
	await frames(3)
	ok(int(s["max_fps"]) == 60 and Engine.max_fps == 60, "FPS sınırı 60 (%d)" % Engine.max_fps)
	arrow("FPS sınırı", false).pressed.emit()
	await frames(3)
	ok(Engine.max_fps == 30, "◀ geri: 30")
	if main.shot_dir != "":
		get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join("ayarlar_vsync.png"))
	# ayrıntılı grafik
	var vp = Game.world.get_viewport()
	arrow("Kenar yumuşatma", true).pressed.emit()
	await frames(3)
	ok(int(s["aa"]) == 3 and vp.msaa_3d == Viewport.MSAA_4X, "kenar yumuşatma MSAA 4x uygulandı")
	arrow("Kenar yumuşatma", true).pressed.emit()
	await frames(3)
	ok(int(s["aa"]) == 0 and vp.msaa_3d == Viewport.MSAA_DISABLED and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "kenar yumuşatma kapalı")
	arrow("Çözünürlük ölçeği", false).pressed.emit()
	await frames(3)
	ok(is_equal_approx(vp.scaling_3d_scale, 0.9), "çözünürlük ölçeği %%90 (%.2f)" % vp.scaling_3d_scale)
	arrow("Ortam gölgesi (SSAO)", true).pressed.emit()
	await frames(3)
	var ee = Game.world.get("env").get("env")
	ok(not s["ssao"] and not ee.ssao_enabled, "ortam gölgesi kapandı")
	arrow("Çimen yoğunluğu", false).pressed.emit()
	await frames(3)
	var gr = Game.world.get_node_or_null("Grass")
	ok(int(s["grass"]) == 2 and (gr == null or is_equal_approx(float(gr.mat.get_shader_parameter("radius")), 42.0)), "çimen yoğunluğu Orta")
	arrow("Kalabalık yoğunluğu", false).pressed.emit()
	await frames(3)
	ok(is_equal_approx(Game.npc_scale, 0.8), "kalabalık Orta")
	# ana ses
	var msl = null
	for l in Hud.dialog_layer.find_children("*", "Label", true, false):
		if (l as Label).text == "Ana ses" and not l.is_queued_for_deletion():
			msl = l.get_parent().find_children("*", "HSlider", false, false)[0]
	ok(msl != null, "Ana ses sürgüsü var")
	msl.value = 0.25
	await frames(2)
	var mb = AudioServer.get_bus_index("Master")
	ok(absf(AudioServer.get_bus_volume_db(mb) - linear_to_db(0.25)) < 0.1, "ana ses hemen uygulandı (%.1f dB)" % AudioServer.get_bus_volume_db(mb))
	if main.shot_dir != "":
		var sc = Hud.dialog_layer.find_children("*", "ScrollContainer", true, false)[0]
		sc.scroll_vertical = 100000
		await frames(3)
		get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join("ayarlar_grafik.png"))
	# varsayılana dön
	find_btn(Hud.dialog_layer, "Varsayılana Dön").pressed.emit()
	await frames(3)
	ok(int(s["aa"]) == 2 and s["ssao"] and is_equal_approx(float(s["master"]), 1.0) and vp.msaa_3d == Viewport.MSAA_2X, "Varsayılana Dön çalışıyor")
	s["max_fps"] = 30
	Game.apply_frame()
	# kaydetmeden çık
	find_btn(Hud.dialog_layer, "Kaydetmeden Çık").pressed.emit()
	await frames(3)
	ok(not Menus.settings_open() and s["vsync"] and Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED, "Kaydetmeden Çık: tüm değişiklikler geri alındı")
	# kaydet -> yükle
	s["vsync"] = false
	s["max_fps"] = 144
	Game.save_settings()
	s["vsync"] = true
	s["max_fps"] = 0
	Game.load_settings()
	ok(not s["vsync"] and Engine.max_fps == 144 and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "kaydedilip yeniden yükleniyor")

	if had:
		var f = FileAccess.open(Game.SETTINGS_PATH, FileAccess.WRITE)
		f.store_string(orig_text)
		f.close()
	else:
		DirAccess.remove_absolute(Game.SETTINGS_PATH)
	Game.load_settings()
	print("SONUC: %d hata" % fails)
	get_tree().quit()
