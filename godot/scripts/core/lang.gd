class_name Lang
extends Translation
## Dil: Türkçe kaynak yazı -> İngilizce (data/i18n/en.json). Godot'nun kendi çeviri sistemine bağlı: ekrandaki her
## Label / Button / RichTextLabel kendiliğinden çevrilir. Biçimli yazılar ("Konuş: %s") şablon olarak eşlenir:
## ekrandaki "Konuş: Hana" -> "Talk: Hana". Türkçe seçiliyken bu sınıf hiç sorulmaz (sıfır maliyet).

const PATH := "res://data/i18n/en.json"
const NAMES := {"tr": "Türkçe", "en": "English"}
const CODES := ["tr", "en"]

static var inst: Lang = null
var exact := {}          # kaynak -> çeviri
var templates := []      # [RegEx, çeviri şablonu, kaynak şablonu]
var _cache := {}         # biçimli yazı sonuçları (her karede değişen sayılar için sınırlı)


## Dili uygula (açılışta ve Ayarlar'dan)
static func apply(code: String) -> void:
	code = code if code in CODES else "tr"
	if inst == null:
		inst = Lang.new()
		inst.locale = "en"
		inst._load()
	# Türkçe'de çeviri sunucudan çıkarılır: yoksa Godot'nun yedek dili (en) Türkçe'de de devreye giriyor
	var has := TranslationServer.get_loaded_locales().has("en")
	if code == "en" and not has:
		TranslationServer.add_translation(inst)
	elif code != "en" and has:
		TranslationServer.remove_translation(inst)
	TranslationServer.set_locale(code)
	var ml = Engine.get_main_loop()
	var data = ml.root.get_node_or_null("Data") if ml is SceneTree else null
	if data and not data.jutsu.is_empty():
		data.apply_lang()   # veri yazıları (açıklamalar, eşya adları)
	var pg = ml.root.get_node_or_null("Progress") if ml is SceneTree else null
	var gm = ml.root.get_node_or_null("Game") if ml is SceneTree else null
	if pg and gm and not gm.profile.is_empty():
		pg.refresh_story()   # hikâye hedef yazıları
		var hud = ml.root.get_node_or_null("Hud")
		if hud and hud.has_method("objective_changed"):
			hud.objective_changed()


## Oyun kapanırken: çeviri sunucusu betikli çeviriyi kapanışta tutmasın (çökme)
static func shutdown() -> void:
	if inst != null and TranslationServer.get_loaded_locales().has("en"):
		TranslationServer.remove_translation(inst)
	inst = null


static func is_en() -> bool:
	return TranslationServer.get_locale() == "en" and inst != null


## Büyük harf: Türkçe'de i -> İ
static func upper(s: String) -> String:
	return s.to_upper() if is_en() else s.replace("i", "İ").to_upper()


## Kod içinden çeviri (Label dışı yerler: 3B yazılar, çizilen yazılar)
static func t(s: String) -> String:
	if not is_en():
		return s
	var r = inst._get_message(StringName(s), &"")
	return s if r == &"" else String(r)


func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	var fmt := RegEx.new()
	fmt.compile("%(?:%|[-+ 0#]*\\d*(?:\\.\\d+)?[sdfixXc])")
	for k in d:
		var v := String(d[k])
		if v == "":
			continue
		var key := String(k)
		exact[key] = v
		if not "%" in key:
			continue
		# şablon: yer tutucular yakalayan gruba dönüşür
		var pat := "^"
		var last := 0
		var n := 0
		for m in fmt.search_all(key):
			pat += _esc(key.substr(last, m.get_start() - last))
			var spec := m.get_string()
			if spec == "%%":
				pat += "%"
			elif spec.ends_with("d") or spec.ends_with("i"):
				pat += "(-?\\d+)"
				n += 1
			elif spec.ends_with("f"):
				pat += "(-?[\\d.]+)"
				n += 1
			else:
				pat += "(.*?)"
				n += 1
			last = m.get_end()
		pat += _esc(key.substr(last)) + "$"
		var lit := fmt.sub(key, "", true)
		if n == 0 or lit.to_lower() == lit.to_upper():
			continue   # harfi olmayan şablon ("%s: %s") her şeye uyar: alma
		var rx := RegEx.new()
		if rx.compile(pat) == OK:
			templates.append([rx, v, key])
	# uzun (daha özgül) şablonlar önce
	templates.sort_custom(func(a, b): return a[2].length() > b[2].length())


static func _esc(s: String) -> String:
	var o := ""
	for ch in s:
		if ch in "\\^$.|?*+()[]{}":
			o += "\\"
		o += ch
	return o


func _get_message(src: StringName, _ctx: StringName) -> StringName:
	var s := String(src)
	if exact.has(s):
		return StringName(exact[s])
	if s.length() < 2 or _cache.has(s):
		return _cache.get(s, &"")
	var r := _translate(s)
	if _cache.size() > 4000:
		_cache.clear()
	_cache[s] = StringName(r) if r != s else &""
	return _cache[s]


func _translate(s: String) -> String:
	if exact.has(s):
		return exact[s]
	# çok satırlı birleşik yazı: satır satır
	if "\n" in s:
		var lines := s.split("\n")
		var changed := false
		for i in lines.size():
			var tl := _translate(lines[i]) if lines[i].strip_edges() != "" else lines[i]
			if tl != lines[i]:
				lines[i] = tl
				changed = true
		return "\n".join(lines) if changed else s
	# baştaki / sondaki boşluk korunur
	var st := s.strip_edges()
	if st != s and st != "":
		var tt := _translate(st)
		return s.replace(st, tt) if tt != st else s
	for tp in templates:
		var m: RegExMatch = tp[0].search(s)
		if m == null:
			continue
		var out: String = tp[1]
		var res := ""
		var gi := 1
		var fmt_i := 0
		while fmt_i < out.length():
			var c := out[fmt_i]
			if c == "%" and fmt_i + 1 < out.length():
				if out[fmt_i + 1] == "%":
					res += "%"
					fmt_i += 2
					continue
				# yer tutucunun sonuna kadar atla
				var j := fmt_i + 1
				while j < out.length() and not out[j] in "sdfixXc":
					j += 1
				var arg := m.get_string(gi) if gi <= m.get_group_count() else ""
				res += _translate(arg) if arg != "" else arg
				gi += 1
				fmt_i = j + 1
				continue
			res += c
			fmt_i += 1
		return res
	return s
