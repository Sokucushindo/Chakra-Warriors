extends Node
## Ekran modu + çözünürlük: ayarlar menüsündeki ◀ ▶ seçicileriyle sırayla değiştir, pencere modu / boyutu / 3B çizim ölçeği doğrula.
## --onscreen ile koşulmalı (test kipinde pencere ekran dışına zorlanmasın; hd.py ayrı masaüstünde açar)
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func shot(n: String) -> void:
	if main.shot_dir != "":
		get_viewport().get_texture().get_image().save_png(main.shot_dir.path_join(n))


## Ayarlar satırındaki ▶ (d = 1) ya da ◀ (d = -1) düğmesine bas
func _press(title: String, d: int) -> bool:
	for r in Menus._set_bg.find_children("*", "HBoxContainer", true, false):
		var lbls = r.find_children("*", "Label", true, false)
		if lbls.is_empty() or not String(lbls[0].text).to_upper().begins_with(title.to_upper()):
			continue
		var bs = r.find_children("*", "Button", true, false)
		if bs.size() < 2:
			continue
		(bs[bs.size() - 1] if d > 0 else bs[0]).emit_signal("pressed")
		return true
	return false


func _report(tag: String) -> void:
	await _w(1.0)
	var vp = get_viewport()
	print("DM %s: mod=%s ayar=%s/%s pencere=%s ekran=%s 3B ölçek=%.2f" % [tag, DisplayServer.window_get_mode(), Game.settings.get("win_mode"), Game.settings.get("resolution"),
		DisplayServer.window_get_size(), DisplayServer.screen_get_size(), vp.scaling_3d_scale])
	shot("dm_%s.png" % tag)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.7, 0.35, 0.15), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	Game.settings["win_mode"] = "window"
	Game.settings["resolution"] = ""
	Game.apply_settings()
	main.mode = "game"
	main._pause()
	await _w(0.5)
	Menus._set_tab = "general"
	Menus.settings(func(): Menus.pause(main))
	await _report("0_pencere_kapla")
	print("DM secenekler=", Game.resolution_options())
	for i in 2:
		print("DM bas mod ", _press("Ekran modu", 1))
		await _report("mod_%d" % (i + 1))
	# tam ekranda çözünürlük düşür (3B ölçek düşmeli)
	print("DM bas coz ", _press("Çözünürlük", 1))
	await _report("tam_coz1")
	# pencere + 1280x720
	print("DM bas mod ", _press("Ekran modu", 1))
	await _report("pencere_coz1")
	# kaydetmeden çık: geri dönmeli
	Menus.settings_cancel()
	await _w(0.3)
	Menus.settings_cancel()
	await _report("iptal")
	get_tree().quit()
