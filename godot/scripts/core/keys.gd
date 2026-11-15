class_name Keys
extends RefCounted
## Tuş atamaları: varsayılanlar, oyuncunun değiştirdikleri (user://tuslar.cfg), InputMap'e uygulama, tuş adları.
## Kod > 0: fiziksel tuş (klavye düzeninden bağımsız yer); kod < 0: fare düğmesi (-1 sol, -2 sağ, -3 orta, -8 / -9 yan düğmeler).
## Esc (duraklat), F3-F9 (teşhis) ve mühür örme tuşları (mühür modunda 1-9, 0, -, =) sabittir.

const PATH := "user://tuslar.cfg"
const GROUPS := [
	["Hareket", [["forward", "İleri", [KEY_W]], ["back", "Geri", [KEY_S]], ["left", "Sola", [KEY_A]], ["right", "Sağa", [KEY_D]],
		["jump", "Zıpla / çift zıplama", [KEY_SPACE]], ["leap", "Süper zıplama / duvar atılımı", [KEY_CTRL]],
		["dash", "Ninja koşusu / havada atılma", [KEY_SHIFT]], ["walk", "Yürüyüş (aç / kapa)", [KEY_CAPSLOCK]]]],
	["Dövüş", [["attack", "Saldırı", [-1]], ["guard", "Blok", [-2]], ["lock", "Hedefe kilitlen", [KEY_E, -3]],
		["substitute", "Kawarimi (genjutsu'dayken: Kai)", [KEY_Q]], ["charge", "Chakra şarjı (basılı)", [KEY_C]],
		["throw", "Alet fırlat", [KEY_R]], ["tool_next", "Fırlatılacak aleti değiştir", [KEY_T]],
		["weapon_draw", "Silahı çek / kınına sok", [KEY_N]], ["seal_mode", "Mühür modu", [KEY_G]]]],
	["Modlar ve çağrı", [["dojutsu", "Dōjutsu: gözleri aç / kapat (basılı: Susanoo)", [KEY_V]],
		["sage", "Sennin modu (gözler açıkken: sağ göz tekniği)", [KEY_Z]], ["beast", "Canavar modu (gözler açıkken: sol göz tekniği)", [KEY_X]],
		["gates", "Sekiz Kapı", [KEY_B]], ["summon_cmd", "Çağrı komutu", [KEY_J]], ["summon_special", "Çağrı özel tekniği", [KEY_U]]]],
	["Eşya ve etkileşim", [["interact", "Etkileşim / konuş", [KEY_F]], ["salve", "Merhem", [KEY_H]], ["pill", "Hap", [KEY_Y]],
		["pill_next", "Hapı değiştir", [KEY_O]]]],
	["Menüler", [["menu", "Ninja menüsü", [KEY_TAB]], ["inventory", "Envanter", [KEY_I]], ["skills", "Jutsular", [KEY_K]],
		["map", "Harita", [KEY_M]], ["track_next", "Harita işaretçisini değiştir", [KEY_L]]]],
	["Jutsu yuvaları", [["slot1", "Yuva 1", [KEY_1]], ["slot2", "Yuva 2", [KEY_2]], ["slot3", "Yuva 3", [KEY_3]], ["slot4", "Yuva 4", [KEY_4]],
		["slot5", "Yuva 5", [KEY_5]], ["slot6", "Yuva 6", [KEY_6]], ["slot7", "Yuva 7", [KEY_7]], ["slot8", "Yuva 8", [KEY_8]], ["slot9", "Yuva 9", [KEY_9]]]],
]
const RESERVED := [KEY_ESCAPE, KEY_F3, KEY_F4, KEY_F5, KEY_F8, KEY_F9, KEY_META, KEY_PRINT, -4, -5, -6, -7]
const SPECIAL := {KEY_SPACE: "Space", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab", KEY_CAPSLOCK: "Caps Lock",
	KEY_ENTER: "Enter", KEY_KP_ENTER: "Num Enter", KEY_BACKSPACE: "Backspace", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	-1: "Sol tık", -2: "Sağ tık", -3: "Orta tık", -8: "Fare 4", -9: "Fare 5"}

static var binds := {}        # eylem -> [kod, ...] (varsayılanla aynı sayıda)
static var capturing := false  # Kontroller ekranı yeni tuş bekliyor: oyun tuşları işlenmez
static var _defs := {}
static var _names := {}       # kod -> ad önbelleği
static var _custom := false   # en az bir atama varsayılandan farklı
static var _tokens := {}      # metinlerdeki "[F]" -> eylem
static var _rx: RegEx


static func defaults(action: String) -> Array:
	return _defs.get(action, [])


## Açılışta bir kez: eylemleri kur, oyuncunun atamalarını yükle, InputMap'e uygula
static func setup() -> void:
	_defs.clear()
	binds.clear()
	for g in GROUPS:
		for r in g[1]:
			_defs[r[0]] = r[2]
			binds[r[0]] = (r[2] as Array).duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for a in _defs:
			var v = cf.get_value("tuslar", a) if cf.has_section_key("tuslar", a) else null
			if v is Array and v.size() == _defs[a].size():
				var ok := true
				for c in v:
					if not (c is int or c is float) or int(c) == 0 or int(c) in RESERVED:
						ok = false
				if ok:
					binds[a] = v.map(func(c): return int(c))
	# bozuk / elle düzenlenmiş dosya: aynı tuş iki eylemdeyse sonraki varsayılanına döner
	var seen := {}
	for a in binds:
		for i in binds[a].size():
			if seen.has(binds[a][i]):
				binds[a] = (_defs[a] as Array).duplicate()
				break
		for c in binds[a]:
			seen[c] = a
	for a in binds:
		_apply(a)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	InputMap.action_erase_events("pause")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", ev)
	_refresh()


static func _apply(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for c in binds[action]:
		if c > 0:
			var ev := InputEventKey.new()
			ev.physical_keycode = c
			InputMap.action_add_event(action, ev)
		else:
			var mb := InputEventMouseButton.new()
			mb.button_index = -c
			InputMap.action_add_event(action, mb)


static func _refresh() -> void:
	_custom = false
	for a in binds:
		if binds[a] != _defs[a]:
			_custom = true
	_tokens.clear()
	for a in _defs:
		if a.begins_with("slot"):
			continue   # "[1]" gibi yazılar tuş ipucu olmayabilir
		for c in _defs[a]:
			var t = SPECIAL.get(c, OS.get_keycode_string(c) if c > 0 else "")
			if t != "" and not _tokens.has(t):
				_tokens[t] = a


static func save() -> void:
	var cf := ConfigFile.new()
	for a in binds:
		if binds[a] != _defs[a]:
			cf.set_value("tuslar", a, binds[a])
	cf.save(PATH)


## Girdi olayının kodu (tuş basışı / fare düğmesi); atanamaz olay: 0
static func event_code(e: InputEvent) -> int:
	if e is InputEventKey and e.pressed and not e.echo:
		return int(e.physical_keycode) if e.physical_keycode != 0 else int(e.keycode)
	if e is InputEventMouseButton and e.pressed:
		return -int(e.button_index)
	return 0


static func code_name(code: int) -> String:
	if _names.has(code):
		return _names[code]
	var n: String = SPECIAL.get(code, "")
	if n == "" and code > 0:
		var lab := DisplayServer.keyboard_get_label_from_physical(code)   # oyuncunun klavyesinde o tuşun üstünde yazan
		n = OS.get_keycode_string(lab if lab != 0 else code)
		if n == "":
			n = OS.get_keycode_string(code)
	if n == "":
		n = "Fare %d" % -code if code < 0 else "Tuş %d" % code
	_names[code] = n
	return n


## Eylemin (ilk) tuşunun adı: ekrandaki ipuçları için
static func name(action: String) -> String:
	var b: Array = binds.get(action, [])
	return code_name(b[0]) if not b.is_empty() else "?"


## Eylemin tuşu şu an fiziksel olarak basılı mı (eylem başka yoldan tetiklenmiş olsa bile)
static func held(action: String) -> bool:
	for c in binds.get(action, []):
		if (c > 0 and Input.is_physical_key_pressed(c)) or (c < 0 and Input.is_mouse_button_pressed(-c)):
			return true
	return false


## Bu kod kimde: [eylem, sıra] ya da []
static func owner_of(code: int) -> Array:
	for a in binds:
		var i = (binds[a] as Array).find(code)
		if i >= 0:
			return [a, i]
	return []


static func label(action: String) -> String:
	for g in GROUPS:
		for r in g[1]:
			if r[0] == action:
				return r[1]
	return action


## Eylemin idx. tuşunu değiştir. Tuş başka eylemdeyse ikisi yer değiştirir. Dönen: oyuncuya gösterilecek kısa bilgi.
static func rebind(action: String, idx: int, code: int) -> String:
	if code == 0 or code in RESERVED:
		return "%s atanamaz (oyunun kendi tuşu)." % code_name(code)
	var old: int = binds[action][idx]
	if code == old:
		return ""
	var info := "%s: %s" % [label(action), code_name(code)]
	var o = owner_of(code)
	if not o.is_empty():
		binds[o[0]][o[1]] = old
		_apply(o[0])
		info += "  •  %s artık %s" % [label(o[0]), code_name(old)]
	binds[action][idx] = code
	_apply(action)
	_refresh()
	save()
	return info


## Ayarlardan kaydetmeden çıkınca: tuşları ekran açılırkenki hâline döndür
static func restore(snap: Dictionary) -> void:
	for a in snap:
		if binds.has(a):
			binds[a] = (snap[a] as Array).duplicate()
			_apply(a)
	_refresh()
	save()


static func reset_all() -> void:
	for a in _defs:
		binds[a] = (_defs[a] as Array).duplicate()
		_apply(a)
	_refresh()
	save()


## Metindeki "[F]" gibi tuş ipuçlarını oyuncunun atadığı tuşla değiştir (atama değişmediyse metne dokunmaz)
static func fix(text: String) -> String:
	if not _custom or not "[" in text:
		return text
	if _rx == null:
		_rx = RegEx.new()
		_rx.compile("\\[([^\\[\\]]{1,10})\\]")
	var out := text
	for m in _rx.search_all(text):
		var a = _tokens.get(m.get_string(1), "")
		if a != "" and binds[a][0] != _defs[a][0]:
			out = out.replace(m.get_string(0), "[%s]" % code_name(binds[a][0]))
	return out


## Olay bir jutsu yuvası tuşuna basış mı: yuva sırası (0-8) ya da -1
static func slot_pressed(e: InputEvent) -> int:
	for i in 9:
		if e.is_action_pressed("slot%d" % (i + 1)):
			return i
	return -1
