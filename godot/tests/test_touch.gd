extends Node
## Android dokunmatik katman sınaması (PC'de TOUCH_TEST=1 ile): joystick + ninja koşusu, çekmece, mühür takımı, duraklat,
## geri tuşu, iki parmak kamera uzaklığı, ayarlar Dokunmatik bölümü. Satırlar "TCH" ile başlar.
var main: Node
var tc


func _t(i: int, p: Vector2, down: bool) -> void:
	var e = InputEventScreenTouch.new()
	e.index = i
	e.position = get_viewport().get_final_transform() * p
	e.pressed = down
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _d(i: int, p: Vector2) -> void:
	var e = InputEventScreenDrag.new()
	e.index = i
	e.position = get_viewport().get_final_transform() * p
	Input.parse_input_event(e)
	await get_tree().process_frame


func _btn(act: String) -> Vector2:
	tc._layout()
	for b in tc.buttons:
		if String(b[0]) == act or (act == "more" and String(b[4]) == "more"):
			return b[1]
	print("TCH HATA düğme yok: ", act)
	return Vector2(-100, -100)


func _tap(act: String) -> void:
	var p = _btn(act)
	await _t(5, p, true)
	await _t(5, p, false)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	Hud.close_dialog()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(1.5).timeout
	var pl = main.player
	tc = get_tree().root.get_node("TouchControls")
	var s = get_viewport().get_visible_rect().size
	print("TCH aktif=", tc._active(), " adlar=", Keys.name("dash"), "/", Keys.name("seal_mode"))
	# 1) joystick yarım / uçta (ninja koşusu)
	var sc = Vector2(s.x * 0.12, s.y * 0.70)
	for tip in [0.6, 1.0]:
		var p0 = pl.global_position
		await _t(0, sc, true)
		for k in 8:
			await _d(0, sc + Vector2(0, -tip * minf(s.x, s.y) * 0.13 * (k + 1) / 8.0))
		await get_tree().create_timer(1.5).timeout
		print("TCH joystick %.1f: yol=%.1f m dash_tutulu=%s" % [tip, Vector2(p0.x, p0.z).distance_to(Vector2(pl.global_position.x, pl.global_position.z)), Keys.held("dash")])
		await _t(0, sc, false)
		await get_tree().create_timer(0.6).timeout
	# 2) iki parmak kamera uzaklığı
	var d0 = pl.cam_dist
	var c = Vector2(s.x * 0.5, s.y * 0.3)
	await _t(1, c - Vector2(40, 0), true)
	await _t(2, c + Vector2(40, 0), true)
	for k in 8:
		await _d(1, c - Vector2(40 + k * 20, 0))
		await _d(2, c + Vector2(40 + k * 20, 0))
	await _t(1, c, false)
	await _t(2, c, false)
	print("TCH iki parmak kamera %.2f -> %.2f" % [d0, pl.cam_dist])
	# 3) çekmece
	await _tap("more")
	print("TCH cekmece acik=", tc.more_open, " dugme=", tc.buttons.size())
	await main.shot("touch_drawer")
	# 4) mühür: çekmeceden Mühür -> 3 mühür -> Ör
	await _tap("seal_mode")
	await get_tree().create_timer(0.3).timeout
	print("TCH muhur modu=", pl.combat.modes.seal_mode, " takim=", tc.seal_on)
	await main.shot("touch_seals")
	for i in [2, 0, 4]:
		await _tap(str(i))
	print("TCH muhurler=", pl.combat.modes.seal_seq)
	await _tap("seal_mode")
	await get_tree().create_timer(0.3).timeout
	print("TCH muhur bitti modu=", pl.combat.modes.seal_mode, " takim=", tc.seal_on)
	await get_tree().create_timer(2.5).timeout
	# 5) çekmeceden envanter, geri tuşu ile kapat
	await _tap("more")
	await _tap("inventory")
	await get_tree().create_timer(0.5).timeout
	print("TCH envanter ui_open=", Game.ui_open, " paused=", Game.paused)
	tc._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().create_timer(0.5).timeout
	print("TCH geri sonra ui_open=", Game.ui_open, " paused=", Game.paused)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(0.3).timeout
	# 6) duraklat düğmesi
	await _tap("pause")
	await get_tree().create_timer(0.5).timeout
	print("TCH duraklat paused=", Game.paused, " ui_open=", Game.ui_open)
	tc._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().create_timer(0.5).timeout
	print("TCH geri sonra paused=", Game.paused)
	# 7) ayarlar: Kontrol sekmesi
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Menus.settings(func(): pass)
	await get_tree().create_timer(0.3).timeout
	Menus._set_tab = "controls"
	Menus.settings(func(): pass)
	await get_tree().create_timer(0.8).timeout
	await main.shot("touch_settings")
	var found = []
	for l in Hud.dialog_layer.find_children("*", "Label", true, false):
		if is_instance_valid(l) and not l.is_queued_for_deletion() and (l as Label).text in ["Dokunmatik", "Touch", "Düğme boyutu", "Button size", "El düzeni", "Hand layout"]:
			found.append(l.text)
	print("TCH ayarlar satirlari=", found)
	Menus._set_tab = "graphics"
	Menus.settings(func(): pass)
	await get_tree().create_timer(0.8).timeout
	var scr = []
	for l in Hud.dialog_layer.find_children("*", "Label", true, false):
		if is_instance_valid(l) and not l.is_queued_for_deletion() and (l as Label).text in ["Ekran modu", "Screen mode", "Çözünürlük", "Resolution"]:
			scr.append(l.text)
	print("TCH ekran satirlari (bos olmali)=", scr)
	await main.shot("touch_graphics")
	get_tree().quit()
