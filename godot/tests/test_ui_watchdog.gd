extends Node
## Arayüz bekçisi: takılı kalan durumlar 1 sn içinde toparlanır; gerçek menü / pencere açıkken dokunulmaz
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout
func _st(tag: String) -> void:
	print("%s: duraklama=%s agac=%s ui=%s fare=%d pencere=%d" % [tag, str(Game.paused), str(get_tree().paused), str(Game.ui_open), Input.mouse_mode, Hud.dialog_layer.get_child_count()])
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "T", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	await _w(1.0)
	for case in ["ui", "fare", "duraklama", "agac"]:
		match case:
			"ui": Game.ui_open = true
			"fare": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			"duraklama": main._pause()
			"agac": get_tree().paused = true
		var t0 = Time.get_ticks_msec()
		var ok = false
		while Time.get_ticks_msec() - t0 < 3000:
			await _w(0.05)
			if not Game.ui_open and not Game.paused and not get_tree().paused and (case != "fare" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not DisplayServer.window_is_focused()):
				ok = true
				break
		print("TAKILI %s: toparlandi=%s sure=%.2f sn" % [case, str(ok), (Time.get_ticks_msec() - t0) / 1000.0])
		main.resume()
		await _w(0.5)
	# 3) meşru: ESC menüsü açık -> dokunulmamalı
	main._pause()
	Menus.pause(main)
	await _w(2.0)
	_st("MESRU esc menusu")
	main.resume()
	await _w(0.5)
	# 4) meşru: konuşma penceresi açık -> ui_open kalmalı
	Hud.dialog("Test", "Pencere açık kalmalı.", [{"label": "Tamam", "cb": func(): pass}])
	await _w(2.0)
	_st("MESRU pencere")
	Hud.close_dialog()
	await _w(0.6)
	# 5) Rinnegan uyanışı gerçek akış
	Progress.rinnegan_done({}, true)
	await _w(3.0)
	_st("RINNEGAN sonra")
	get_tree().quit()
