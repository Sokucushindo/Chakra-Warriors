extends CanvasLayer
## Android dokunmatik kontroller (yalnız `android` branch'i; PC sürümünde bu dosya ve autoload yok).
## Oyunun koduna dokunmaz: dokunuşları oyunun kendi tuş eylemlerine çevirir (Input.action_press + InputEventAction).
##  - sol alt joystick: forward/back/left/right (eğim kadar güç; dış halkada koşu)
##  - boş alanda kaydırma: kamera (oyuncunun yaw/pitch'i, fare hassasiyeti ayarıyla)
##  - sağ küme: saldırı, zıpla, blok (basılı), atılma (basılı = ninja koşusu), süper zıplama, Kawarimi
##  - üst sıra: etkileşim (F), kilit, chakra (basılı), göz, çağrı komutu, menü, harita
##  - HUD'daki jutsu yuvaları ve R/T/H/Y kutuları: dokununca o tuş
## Oyun sırasında (fare yakalıyken) dokunuşun fareye çevrilmesi kapalıdır (sağa dokunmak saldırı tıklaması olmasın); menü /
## konuşma açıkken açılır ve katman gizlenir: menüler dokunuşla tıklanır.

var root: Control
var on := false
var touches := {}   # dokunuş indeksi -> {"kind": "stick"/"cam"/"btn", "act": eylem, "last": konum}
var stick_c := Vector2.ZERO
var stick_v := Vector2.ZERO
var buttons: Array = []   # [eylem, merkez, yarıçap, etiket, basılı]


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


func _active() -> bool:
	return on and Game.player != null and is_instance_valid(Game.player) and not Game.paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _layout() -> void:
	var s: Vector2 = root.get_viewport_rect().size
	var u: float = minf(s.x, s.y)
	stick_c = Vector2(s.x * 0.12, s.y * 0.70)
	var R := u * 0.075
	var r := u * 0.045
	buttons = [
		["attack", Vector2(s.x * 0.915, s.y * 0.70), R, "Saldırı", false],
		["jump", Vector2(s.x * 0.83, s.y * 0.81), r * 1.25, "Zıpla", false],
		["guard", Vector2(s.x * 0.835, s.y * 0.60), r * 1.15, "Blok", false],
		["dash", Vector2(s.x * 0.955, s.y * 0.53), r, "Atıl", false],
		["leap", Vector2(s.x * 0.75, s.y * 0.74), r, "Süper
Zıpla", false],
		["substitute", Vector2(s.x * 0.755, s.y * 0.60), r, "Kawa
rimi", false],
		["interact", Vector2(s.x * 0.675, s.y * 0.66), r * 1.1, "F", false],
		# küçük düğmeler: sol üst, can çubuklarının altında (pusula / hedef yazısının üstüne binmez)
		["menu", Vector2(s.x * 0.035, s.y * 0.30), r * 0.75, "Menü", false],
		["map", Vector2(s.x * 0.085, s.y * 0.30), r * 0.75, "Harita", false],
		["lock", Vector2(s.x * 0.135, s.y * 0.30), r * 0.75, "Kilit", false],
		["charge", Vector2(s.x * 0.035, s.y * 0.39), r * 0.75, "Chakra", false],
		["dojutsu", Vector2(s.x * 0.085, s.y * 0.39), r * 0.75, "Göz", false],
		["summon_cmd", Vector2(s.x * 0.135, s.y * 0.39), r * 0.75, "Komut", false],
	]


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
	if down:
		Input.action_press(act)
	else:
		Input.action_release(act)
	var ev := InputEventAction.new()
	ev.action = act
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
	if v.length() > 0.97:
		Input.action_press("dash")
	elif not _btn_held("dash"):
		Input.action_release("dash")


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


func _process(_dt: float) -> void:
	var act := _active()
	# oyun sırasında dokunuş fareye çevrilmez (sağa dokunmak saldırı tıklaması olmasın); menüde çevrilir (tıklanabilir)
	Input.emulate_mouse_from_touch = not act
	if root.visible != act:
		root.visible = act
		if not act:
			_release_all()
	if act:
		_layout()
		root.queue_redraw()


func _input(e: InputEvent) -> void:
	if not _active():
		return
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			_layout()
			# joystick: ekranın sol alt çeyreği (stick merkezi parmağın indiği yere taşınır: yüzen joystick)
			var s: Vector2 = root.get_viewport_rect().size
			for b in buttons:
				if p.distance_to(b[1]) <= float(b[2]) * 1.15:
					touches[e.index] = {"kind": "btn", "act": b[0], "last": p}
					_press(b[0], true)
					get_viewport().set_input_as_handled()
					return
			if p.x < s.x * 0.33 and p.y > s.y * 0.46:
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
			var rel: Vector2 = p - (t["last"] as Vector2)
			var sens = 0.22 * float(Game.settings.get("sens", 1.0))
			pl.yaw -= rel.x * sens
			pl.pitch -= rel.y * sens * (-1.0 if Game.settings.get("invert_y", false) else 1.0)
			pl.pitch = clampf(pl.pitch, -70, 60)
		t["last"] = p
		get_viewport().set_input_as_handled()


func _draw_ui() -> void:
	if not _active():
		return
	var s: Vector2 = root.get_viewport_rect().size
	var R: float = minf(s.x, s.y) * 0.13
	var font = ThemeDB.fallback_font
	# joystick
	root.draw_circle(stick_c, R, Color(0, 0, 0, 0.22))
	root.draw_arc(stick_c, R, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	root.draw_circle(stick_c + stick_v * R, R * 0.42, Color(1, 1, 1, 0.38))
	for b in buttons:
		var held := _btn_held(String(b[0]))
		var c: Vector2 = b[1]
		var r: float = b[2]
		root.draw_circle(c, r, Color(0.95, 0.55, 0.15, 0.55) if held else Color(0, 0, 0, 0.3))
		root.draw_arc(c, r, 0.0, TAU, 36, Color(1, 1, 1, 0.55), 2.5, true)
		var txt := _label(String(b[3]))
		var fs := int(clampf(r * 0.42, 12.0, 30.0))
		var lines := txt.split("\n")
		for li in lines.size():
			var w: float = font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			root.draw_string(font, c + Vector2(-w * 0.5, fs * 0.35 + (li - (lines.size() - 1) * 0.5) * fs * 1.05), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))


## Düğme adları: İngilizce oyunda karşılığı (ortak çeviri dosyasına eklenmez: PC güncellemeleri birleşirken çakışmasın)
const EN := {"Saldırı": "Attack", "Zıpla": "Jump", "Blok": "Block", "Atıl": "Dash", "Süper
Zıpla": "Leap", "Kawa
rimi": "Kawa
rimi",
	"Menü": "Menu", "Harita": "Map", "Kilit": "Lock", "Chakra": "Chakra", "Göz": "Eyes", "Komut": "Order", "F": "F"}


func _label(tr: String) -> String:
	var english := Lang.t("Saldırı") != "Saldırı"
	return String(EN.get(tr, tr)) if english else tr
