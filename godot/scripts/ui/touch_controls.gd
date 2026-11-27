extends CanvasLayer
## Android dokunmatik kontroller (yalnız `android` branch'i; PC sürümünde bu dosya ve autoload yok).
## Oyunun koduna dokunmaz: dokunuşları oyunun kendi tuş eylemlerine çevirir (Input.action_press + InputEventAction).
##  - joystick (yüzen): forward/back/left/right; dış halkada ninja koşusu (ayarla kapatılır)
##  - boş alanda kaydırma: kamera; iki parmak: kamera uzaklığı (menüde / haritada: yakınlaştırma = fare tekeri)
##  - ana küme: saldırı, zıpla, blok (basılı), atılma (basılı = ninja koşusu), süper zıplama, Kawarimi, F
##  - küçük sıra: menü, harita, kilit, chakra (basılı), göz (basılı = Susanoo), çağrı komutu, duraklat, "daha fazla"
##  - "daha fazla" çekmecesi: silah, mühür modu, Sennin, canavar, kapılar, çağrı tekniği, Omori, hap, yürüyüş, envanter, jutsular, işaretçi
##  - mühür modu açıkken 12 mühür düğmesi (oyunun mühür tuşlarını gönderir)
##  - HUD'daki jutsu yuvaları ve R/T/H/Y kutuları: dokununca o tuş
##  - telefonun geri tuşu = Esc; uygulama arka plana alınınca oyun kaydedilir
## Oyun sırasında (fare yakalıyken) dokunuşun fareye çevrilmesi kapalıdır (sağa dokunmak saldırı tıklaması olmasın); menü /
## konuşma açıkken açılır ve katman gizlenir: menüler dokunuşla tıklanır.

const SEAL_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]   # PlayerModes.SEAL_KEYS
const DRAWER := [["weapon_draw", "Silah"], ["seal_mode", "Mühür"], ["sage", "Sennin"], ["beast", "Canavar"],
	["gates", "Kapılar"], ["summon_special", "Çağrı\nTekniği"], ["omori", "Omori"], ["pill_next", "Hap\nDeğiştir"],
	["walk", "Yürü"], ["inventory", "Envanter"], ["skills", "Jutsular"], ["track_next", "İşaretçi"]]

var root: Control
var on := false
var touches := {}   # dokunuş indeksi -> {"kind": "stick"/"cam"/"btn"/"menu", "act": eylem, "last": konum}
var stick_c := Vector2.ZERO
var stick_v := Vector2.ZERO
var buttons: Array = []   # [eylem, merkez, yarıçap, etiket, tür]  tür: "" basılı / "more" çekmece / "drawer" / "seal" mühür aç-kapa / "sk" mühür
var more_open := false
var seal_on := false
var _names_t := 0
var _menu_pinch := 0.0   # menüde iki parmak arası son uzaklık


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_ui)
	add_child(root)
	on = OS.has_feature("mobile") or OS.has_feature("android") or OS.get_environment("TOUCH_TEST") != ""
	if not on:
		set_process(false)
		set_process_input(false)
		root.visible = false
		return
	DisplayServer.screen_set_keep_on(true)
	if not FileAccess.file_exists(Game.SETTINGS_PATH) and OS.get_environment("TOUCH_TEST") == "":
		_mobile_defaults()


## İlk açılış (ayar dosyası yok): telefona uygun grafik — düşük kalite, %60 çözünürlük, 30 FPS sınırı (ısınma / pil), büyük arayüz
func _mobile_defaults() -> void:
	var s = Game.settings
	Game._quality_details(0)
	s["quality"] = 0
	s["view"] = 0.6
	s["shadows"] = false
	s["outline"] = true
	s["aa"] = 0
	s["ssao"] = false
	s["res_scale"] = 0.6
	s["grass"] = 0
	s["crowd"] = 0
	s["max_fps"] = 30
	s["ui_scale"] = 1.15
	Game.save_settings()
	Game.apply_graphics()


func _st(k: String, d):
	return Game.settings.get(k, d)


func _vibe(ms: int) -> void:
	if bool(_st("touch_vibe", true)):
		Input.vibrate_handheld(ms)


func _active() -> bool:
	return on and Game.player != null and is_instance_valid(Game.player) and not Game.paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _seal_active() -> bool:
	var c = Game.player.get("combat") if Game.player != null else null
	var m = c.get("modes") if c != null else null
	return m != null and bool(m.get("seal_mode"))


func _layout() -> void:
	var s: Vector2 = root.get_viewport_rect().size
	var u: float = minf(s.x, s.y)
	var k := float(_st("touch_size", 1.0))
	var left := bool(_st("touch_left", false))
	var X = func(fx: float) -> float: return s.x * (1.0 - fx if left else fx)   # solak düzen: ana küme ve joystick yer değiştirir
	if not touches.values().any(func(t): return t["kind"] == "stick"):
		stick_c = Vector2(X.call(0.12), s.y * 0.70)
	var R := u * 0.075 * k
	var r := u * 0.045 * k
	var sr := u * 0.034 * clampf(k, 0.8, 1.3)
	buttons = [
		["attack", Vector2(X.call(0.915), s.y * 0.70), R, "Saldırı", ""],
		["jump", Vector2(X.call(0.83), s.y * 0.81), r * 1.25, "Zıpla", ""],
		["guard", Vector2(X.call(0.835), s.y * 0.60), r * 1.15, "Blok", ""],
		["dash", Vector2(X.call(0.955), s.y * 0.53), r, "Atıl", ""],
		["leap", Vector2(X.call(0.75), s.y * 0.74), r, "Süper\nZıpla", ""],
		["substitute", Vector2(X.call(0.755), s.y * 0.60), r, "Kawa\nrimi", ""],
		["interact", Vector2(X.call(0.675), s.y * 0.66), r * 1.1, "F", ""],
		# küçük düğmeler: sol üst, can çubuklarının altında (pusula / hedef yazısının üstüne binmez)
		["menu", Vector2(s.x * 0.035, s.y * 0.30), sr, "Menü", ""],
		["map", Vector2(s.x * 0.085, s.y * 0.30), sr, "Harita", ""],
		["lock", Vector2(s.x * 0.135, s.y * 0.30), sr, "Kilit", ""],
		["pause", Vector2(s.x * 0.185, s.y * 0.30), sr, "II", ""],
		["charge", Vector2(s.x * 0.035, s.y * 0.39), sr, "Chakra", ""],
		["dojutsu", Vector2(s.x * 0.085, s.y * 0.39), sr, "Göz", ""],
		["summon_cmd", Vector2(s.x * 0.135, s.y * 0.39), sr, "Komut", ""],
		["", Vector2(s.x * 0.185, s.y * 0.39), sr, "Daha", "more"],
	]
	if more_open:
		var cr := u * 0.052 * clampf(k, 0.8, 1.3)
		var gap := cr * 2.5
		var o := Vector2(s.x * 0.5 - gap * 1.5, s.y * 0.26)
		for i in DRAWER.size():
			var it: Array = DRAWER[i]
			buttons.append([it[0], o + Vector2(i % 4, i / 4) * gap, cr, it[1], "seal" if it[0] == "seal_mode" else "drawer"])
	if seal_on:
		# mühür tuş takımı: 6 x 2, ekranın alt ortası; üstte "Ör" (G'yi bırakmak = örülen mühürlerle jutsuyu yap)
		var sk := u * 0.05 * clampf(k, 0.8, 1.3)
		var sg := sk * 2.3
		var mx := s.x * (0.57 if left else 0.43)   # ortanın biraz solu: sağdaki F / Kawarimi düğmelerine binmez
		var so := Vector2(mx - sg * 2.5, s.y * 0.60)
		var names: Array = Data.seals
		for i in mini(12, names.size()):
			buttons.append([str(i), so + Vector2(i % 6, i / 6) * sg, sk, String(names[i]), "sk"])
		buttons.append(["seal_mode", Vector2(mx, so.y - sg * 1.05), sk * 1.15, "Ör", "seal"])


## Ekrandaki ipuçlarında ("[Shift] ile ...") tuş yerine dokunmatik düğmenin adı
func _refresh_names() -> void:
	var d := {}
	for b in buttons:
		if String(b[0]) != "" and String(b[4]) != "sk" and not d.has(b[0]):
			d[b[0]] = _label(String(b[3])).replace("\n", "")
	for a in DRAWER:
		if not d.has(a[0]):
			d[a[0]] = _label(a[1]).replace("\n", " ")
	Keys.touch_names = d


func _hud_rect_action(p: Vector2) -> String:
	var h = Hud
	for i in (h.slot_nodes as Array).size():
		var n = h.slot_nodes[i][0]
		if n is Control and n.is_visible_in_tree() and (n as Control).get_global_rect().grow(4.0).has_point(p):
			return "slot%d" % (i + 1)
	var side := ["throw", "tool_next", "salve", "pill"]
	for i in mini((h.side_nodes as Array).size(), side.size()):
		var n = h.side_nodes[i][0]
		if n is Control and n.is_visible_in_tree() and (n as Control).get_global_rect().grow(4.0).has_point(p):
			return side[i]
	return ""


func _press(act: String, down: bool) -> void:
	if not InputMap.has_action(act):
		return
	Keys.touch_held[act] = down
	if down:
		Input.action_press(act)
		_vibe(12)
	else:
		Input.action_release(act)
	var ev := InputEventAction.new()
	ev.action = act
	ev.pressed = down
	Input.parse_input_event(ev)


func _key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)


func _set_stick(v: Vector2) -> void:
	stick_v = v
	for a in [["right", maxf(0.0, v.x)], ["left", maxf(0.0, -v.x)], ["back", maxf(0.0, v.y)], ["forward", maxf(0.0, -v.y)]]:
		if float(a[1]) > 0.05:
			Input.action_press(a[0], clampf(float(a[1]), 0.0, 1.0))
		else:
			Input.action_release(a[0])
	# dış halkaya kadar itilirse ninja koşusu (Shift)
	if v.length() > 0.97 and bool(_st("touch_run", true)):
		Input.action_press("dash")
		Keys.touch_held["dash"] = true
	elif not _btn_held("dash"):
		Input.action_release("dash")
		Keys.touch_held["dash"] = false


func _btn_held(act: String) -> bool:
	for t in touches.values():
		if t["kind"] == "btn" and t["act"] == act:
			return true
	return false


func _release_all() -> void:
	for t in touches.values():
		if t["kind"] == "btn":
			_press(t["act"], false)
	touches.clear()
	_set_stick(Vector2.ZERO)
	if seal_on:
		seal_on = false
		_press("seal_mode", false)
	more_open = false
	Keys.touch_held.clear()


func _process(_dt: float) -> void:
	var act := _active()
	# oyun sırasında dokunuş fareye çevrilmez (sağa dokunmak saldırı tıklaması olmasın); menüde çevrilir (tıklanabilir)
	Input.emulate_mouse_from_touch = not act
	if root.visible != act:
		root.visible = act
		if not act:
			_release_all()
	if act:
		if seal_on and not _seal_active():   # mühür modu oyun tarafından kapandı (jutsu / sersemleme)
			seal_on = false
		_layout()
		_names_t -= 1
		if _names_t <= 0:
			_names_t = 60
			_refresh_names()
		root.queue_redraw()


func _notification(what: int) -> void:
	if not on:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_key(KEY_ESCAPE)   # telefonun geri tuşu: duraklat / menüden çık (oyunu kapatmaz)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all()
		if what == NOTIFICATION_APPLICATION_PAUSED and Game.player != null and not Game.profile.is_empty():
			Game.save_game()   # Android arka plandaki oyunu habersiz kapatabilir


func _tap_button(b: Array, idx: int, p: Vector2) -> void:
	match String(b[4]):
		"more":
			more_open = not more_open
			_vibe(10)
		"seal":
			seal_on = not seal_on
			more_open = false
			_press("seal_mode", seal_on)
			Keys.touch_held["seal_mode"] = false
		"sk":
			_key(SEAL_KEYS[int(b[0])])
			_vibe(8)
		"drawer":
			touches[idx] = {"kind": "btn", "act": b[0], "last": p, "drawer": true}
			_press(b[0], true)
		_:
			if b[0] == "pause":
				_vibe(10)
				_key(KEY_ESCAPE)
				return
			touches[idx] = {"kind": "btn", "act": b[0], "last": p}
			_press(b[0], true)


func _input(e: InputEvent) -> void:
	if not on:
		return
	if not _active():
		_menu_input(e)
		return
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			_layout()
			var s: Vector2 = root.get_viewport_rect().size
			# üstte çizilen (sonra eklenen) düğme önce: çekmece / mühür takımı ana kümenin üstündedir
			for bi in range(buttons.size() - 1, -1, -1):
				var b: Array = buttons[bi]
				if p.distance_to(b[1]) <= float(b[2]) * 1.15:
					_tap_button(b, e.index, p)
					get_viewport().set_input_as_handled()
					return
			if more_open:   # çekmece açıkken boşa dokunmak kapatır
				more_open = false
			var left := bool(_st("touch_left", false))
			# joystick: ekranın alt yarısı, sol (solakta sağ) üçte bir (parmağın indiği yer merkez olur: yüzen joystick)
			if (p.x > s.x * 0.67 if left else p.x < s.x * 0.33) and p.y > s.y * 0.46:
				stick_c = p
				touches[e.index] = {"kind": "stick", "act": "", "last": p, "c": p}
				get_viewport().set_input_as_handled()
				return
			var ha := _hud_rect_action(p)
			if ha != "":
				touches[e.index] = {"kind": "btn", "act": ha, "last": p}
				_press(ha, true)
				get_viewport().set_input_as_handled()
				return
			touches[e.index] = {"kind": "cam", "act": "", "last": p}
		else:
			var t = touches.get(e.index)
			if t != null:
				if t["kind"] == "btn":
					_press(t["act"], false)
					if t.get("drawer", false):
						more_open = false
				elif t["kind"] == "stick":
					_set_stick(Vector2.ZERO)
				touches.erase(e.index)
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		var t = touches.get(e.index)
		if t == null:
			return
		var p: Vector2 = e.position
		if t["kind"] == "stick":
			var R: float = minf(root.get_viewport_rect().size.x, root.get_viewport_rect().size.y) * 0.13
			var d: Vector2 = (p - (t["c"] as Vector2)) / R
			_set_stick(d.limit_length(1.0))
		elif t["kind"] == "cam":
			var pl = Game.player
			var other = null
			for k in touches:
				if k != e.index and touches[k]["kind"] == "cam":
					other = touches[k]
			if other != null:
				# iki parmak: kamera uzaklığı (fare tekeri gibi)
				var o: Vector2 = other["last"]
				var dd: float = p.distance_to(o) - (t["last"] as Vector2).distance_to(o)
				var cr: Vector2 = pl.cam_range
				pl.cam_dist = clampf(float(pl.cam_dist) - dd * 0.02 * cr.y / 14.0, cr.x, cr.y)
			else:
				var rel: Vector2 = p - (t["last"] as Vector2)
				var sens = 0.22 * float(_st("touch_sens", 1.0))
				pl.yaw -= rel.x * sens
				pl.pitch -= rel.y * sens * (-1.0 if Game.settings.get("invert_y", false) else 1.0)
				pl.pitch = clampf(pl.pitch, -70, 60)
		t["last"] = p
		get_viewport().set_input_as_handled()


## Menü / harita açıkken: dokunuşlar fareye çevrilir (tıklama, kaydırma Godot'ta); iki parmak sıkıştırma = fare tekeri
## (harita, yetenek ağacı yakınlaştırması). Olay tüketilmez.
func _menu_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = {"kind": "menu", "act": "", "last": e.position}
		else:
			touches.erase(e.index)
		_menu_pinch = 0.0
	elif e is InputEventScreenDrag and touches.has(e.index):
		touches[e.index]["last"] = e.position
		var pts: Array = touches.values().filter(func(t): return t["kind"] == "menu").map(func(t): return t["last"])
		if pts.size() != 2:
			return
		var d: float = (pts[0] as Vector2).distance_to(pts[1])
		if _menu_pinch <= 0.0:
			_menu_pinch = d
			return
		var step: float = minf(root.get_viewport_rect().size.x, root.get_viewport_rect().size.y) * 0.06
		if absf(d - _menu_pinch) >= step:
			var mid: Vector2 = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
			for down in [true, false]:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_WHEEL_UP if d > _menu_pinch else MOUSE_BUTTON_WHEEL_DOWN
				mb.pressed = down
				mb.position = mid
				mb.global_position = mid
				mb.factor = 1.0
				Input.parse_input_event(mb)
			_menu_pinch = d


func _draw_ui() -> void:
	if not _active():
		return
	var s: Vector2 = root.get_viewport_rect().size
	var R: float = minf(s.x, s.y) * 0.13
	var font = ThemeDB.fallback_font
	var a := clampf(float(_st("touch_alpha", 0.6)) / 0.6, 0.3, 1.7)   # 0.6 = eski görünüm
	# joystick
	root.draw_circle(stick_c, R, Color(0, 0, 0, 0.22 * a))
	root.draw_arc(stick_c, R, 0.0, TAU, 48, Color(1, 1, 1, minf(1.0, 0.45 * a)), 3.0, true)
	root.draw_circle(stick_c + stick_v * R, R * 0.42, Color(1, 1, 1, minf(1.0, 0.38 * a)))
	if more_open or seal_on:
		# çekmece / mühür takımı arkası: hafif karartma (dokunulabilir alan seçilsin)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for b in buttons:
			if String(b[4]) in ["drawer", "sk"] or (String(b[4]) == "seal" and seal_on):
				lo = lo.min((b[1] as Vector2) - Vector2.ONE * float(b[2]) * 1.4)
				hi = hi.max((b[1] as Vector2) + Vector2.ONE * float(b[2]) * 1.4)
		if lo.x < hi.x:
			root.draw_rect(Rect2(lo, hi - lo), Color(0, 0, 0, 0.35))
	for b in buttons:
		var kind := String(b[4])
		var held := (kind == "seal" and seal_on) or (kind == "more" and more_open) or (String(b[0]) != "" and _btn_held(String(b[0])))
		var c: Vector2 = b[1]
		var r: float = b[2]
		var fill := Color(0.95, 0.55, 0.15, minf(1.0, 0.55 * a)) if held else Color(0, 0, 0, minf(0.85, 0.3 * a))
		if kind == "sk":
			fill = Color(0.12, 0.1, 0.08, minf(0.95, 0.55 * a))
		root.draw_circle(c, r, fill)
		root.draw_arc(c, r, 0.0, TAU, 36, Color(1, 1, 1, minf(1.0, 0.55 * a)), 2.5, true)
		var txt := String(b[3]) if kind == "sk" else _label(String(b[3]))
		if kind == "more":
			txt = "•••"
		var fs := int(clampf(r * 0.42, 12.0, 30.0))
		var lines := txt.split("\n")
		for li in lines.size():
			var w: float = font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			root.draw_string(font, c + Vector2(-w * 0.5, fs * 0.35 + (li - (lines.size() - 1) * 0.5) * fs * 1.05), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, minf(1.0, 0.92 * maxf(a, 0.8))))


## Düğme adları: İngilizce oyunda karşılığı (ortak çeviri dosyasına eklenmez: PC güncellemeleri birleşirken çakışmasın)
const EN := {"Saldırı": "Attack", "Zıpla": "Jump", "Blok": "Block", "Atıl": "Dash", "Süper\nZıpla": "Leap", "Kawa\nrimi": "Kawa\nrimi",
	"Menü": "Menu", "Harita": "Map", "Kilit": "Lock", "Chakra": "Chakra", "Göz": "Eyes", "Komut": "Order", "F": "F", "II": "II",
	"Daha": "More", "Silah": "Weapon", "Mühür": "Seals", "Sennin": "Sage", "Canavar": "Beast", "Kapılar": "Gates",
	"Çağrı\nTekniği": "Summon\nSkill", "Omori": "Omori", "Hap\nDeğiştir": "Next\nPill", "Yürü": "Walk", "Envanter": "Bag",
	"Jutsular": "Jutsu", "İşaretçi": "Marker", "Ör": "Cast"}


func _label(tr: String) -> String:
	var english := Lang.t("Saldırı") != "Saldırı"
	return String(EN.get(tr, tr)) if english else tr
