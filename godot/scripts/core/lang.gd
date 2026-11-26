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


var _seg_rx: RegEx
var _sen_rx: RegEx
var _pc_cache := {}
var derived := {}        # "Ad: Açıklama" → "Açıklama", "Ad (ek)" → "Ad" (ekranda bölünerek gösterilenler)
var lower := {}          # küçük harfli anahtar → çeviri (BÜYÜK / küçük yazılan başlıklar)


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
		key = key.strip_edges()
		v = v.strip_edges()
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
			# yer tutucudan sonra yalnız cümle sonu ("Benim adım %s!", "Ben %s."): yer tutucu birden çok cümle yutamaz
			var tail := key.substr(last).strip_edges()
			templates.append([rx, v, key, tail != "" and tail.length() <= 3 and tail.lstrip(".!?…") == ""])
	for k in exact:
		var key := String(k)
		var v := String(exact[k])
		if "%" in key:
			continue
		var lo := _low(key)
		if not lower.has(lo):
			lower[lo] = v
		# kenarları soyulmuş hâli: "Ganimet: " → "Ganimet", " (chakra tükendi)" → "chakra tükendi"
		var sk := key.strip_edges()
		var sv := v.strip_edges()
		for pass_i in 3:
			if sk != key and sk.length() > 2 and not exact.has(sk) and not derived.has(sk):
				derived[sk] = sv
			if sk.ends_with(":") and sv.ends_with(":"):
				sk = sk.left(-1).strip_edges()
				sv = sv.left(-1).strip_edges()
			elif sk.begins_with("(") and sk.ends_with(")") and sv.begins_with("(") and sv.ends_with(")"):
				sk = sk.substr(1, sk.length() - 2)
				sv = sv.substr(1, sv.length() - 2)
			else:
				break
			if sk.length() > 2 and not exact.has(sk) and not derived.has(sk):
				derived[sk] = sv
		var ci := key.find(": ")
		var vi := v.find(": ")
		if ci > 0 and vi > 0:
			var tk := key.substr(ci + 2)
			if not exact.has(tk) and not derived.has(tk):
				derived[tk] = v.substr(vi + 2)
		var pi := key.find(" (")
		var pv := v.find(" (")
		if pi > 0 and pv > 0:
			var hk := key.substr(0, pi)
			if not exact.has(hk) and not derived.has(hk):
				derived[hk] = v.substr(0, pv)
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
		var whole := _one_c(s.strip_edges())
		if whole != "":
			return s.replace(s.strip_edges(), whole)
		var lines := s.split("\n")
		var changed := false
		var i := 0
		while i < lines.size():
			# birkaç satıra yayılan bilinen yazı (en uzun öbek önce)
			var hit := false
			for j in range(mini(lines.size() - 1, i + 5), i, -1):
				var blk := "\n".join(lines.slice(i, j + 1)).strip_edges()
				var tb := _span(blk)
				if tb != "":
					lines[i] = tb
					for k in range(j, i, -1):
						lines.remove_at(k)
					changed = true
					hit = true
					break
			if not hit:
				var tl := _translate(lines[i]) if lines[i].strip_edges() != "" else lines[i]
				if tl != lines[i]:
					lines[i] = tl
					changed = true
			i += 1
		return "\n".join(lines) if changed else s
	# baştaki / sondaki boşluk korunur
	var st := s.strip_edges()
	if st != s and st != "":
		var tt := _translate(st)
		return s.replace(st, tt) if tt != st else s
	var one := _one(s)
	if one != "":
		return one
	return _pieces(s)


## Tek parça: tam eşleşme → türetilmiş (":" sonrası / "(" öncesi) → harf büyüklüğü farkı → şablon. Bulamazsa "".
func _one(s: String) -> String:
	if exact.has(s):
		return exact[s]
	if derived.has(s):
		return derived[s]
	var lo := _low(s)
	if lower.has(lo):
		var v := String(lower[lo])
		if s == s.to_upper() and s != lo:
			return v.to_upper()
		if s == s.to_lower():
			return v.to_lower() if v.length() > 1 and v.substr(1) == v.substr(1).to_lower() else v
		return v
	var r := _tmpl(s)
	if r != "":
		return r
	# sona eklenen noktalama: "Kabuk Kalkanı!" → "Shell Shield!" (bağırış, soru, üç nokta)
	var core := s.rstrip("!?.…")
	if core != s and core.length() >= 3 and not core.ends_with(" "):
		var tc := _one(core)
		if tc != "":
			return tc + s.substr(core.length())
	return ""


## Parça sonuçları saklanır (her yeni birleşik yazıda bütün şablonlar yeniden denenmesin)
func _one_c(s: String) -> String:
	if _pc_cache.has(s):
		return _pc_cache[s]
	var r := _one(s)
	if _pc_cache.size() > 6000:
		_pc_cache.clear()
	_pc_cache[s] = r
	return r


## Küçük harfe indirger; Türkçe i / ı / İ / I ayrımı kalkar ("SICAK SU ÜLKESI" ile "Sıcak Su Ülkesi" eşleşsin)
static func _low(s: String) -> String:
	return s.to_lower().replace("ı", "i").replace("i̇", "i")


var _sfx_rx: RegEx
## Yer tutucuya giren addaki Türkçe hâl eki ('yı, 'nin, 'den, 'e...) İngilizcede atılır
func _drop_sfx(a: String) -> String:
	if _sfx_rx == null:
		_sfx_rx = RegEx.create_from_string("^(.+?)'(y?[ıiuü]|n?[ıiuü]n|y?[ae]|[dt][ae]n?|n?[ıiuü]n[ıiuü]?|[ıiuü]n[ıiuü])$")
	var m := _sfx_rx.search(a)
	return m.get_string(1) if m else a


var _send: RegEx


func _send_rx() -> RegEx:
	if _send == null:
		_send = RegEx.create_from_string("[.!?…]\\s")
	return _send


func _tmpl(s: String) -> String:
	for tp in templates:
		var m: RegExMatch = tp[0].search(s)
		if m == null:
			continue
		# "Benim adım %s!" birleşik konuşmanın tamamına uyuyordu ("Sayuri! Suyun üstünde ...") -> yarım çeviri. Bu tür kalıpta
		# son yer tutucu cümle sonu içeriyorsa eşleşme reddedilir; yazı cümlelere bölünüp parça parça çevrilir.
		if tp.size() > 3 and tp[3] and m.get_group_count() > 0 and _send_rx().search(m.get_string(m.get_group_count())) != null:
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
				arg = _drop_sfx(arg)   # "Reika'yı" -> "Reika": Türkçe hâl eki İngilizcede kalmasın
				res += _translate(arg) if arg != "" else arg
				gi += 1
				fmt_i = j + 1
				continue
			res += c
			fmt_i += 1
		return res
	return ""


## Birleşik yazı: önce cümle cümle ("Cümle. Cümle."), eşleşmeyen cümle ince ayraçlarla ("Hız +15%, Menzil +10%", "Kunai ×3"),
## o da olmazsa baştaki / sondaki bilinen söz öbeğiyle ("Kaçak Sunagakure"). Eşleşen parçalar çevrilir, kalan olduğu gibi kalır.
func _pieces(s: String) -> String:
	if _sen_rx == null:
		_sen_rx = RegEx.create_from_string("(?<=[.!?…])\\s+")
		_seg_rx = RegEx.create_from_string("\\s*(?:  +|•|—|:|,|;|\\(|\\)|\\[|\\]|\\||×|/|«|»|\"|→)\\s*|\\s*[-+]?\\d+[\\d.,]*%?\\s*")
	var ms := _sen_rx.search_all(s)
	if ms.is_empty():
		return _fine(s)
	return _join(s, ms, _sent)


func _sent(s: String) -> String:
	if s.length() < 2:
		return s
	var r := _one_c(s)
	return r if r != "" else _fine(s)


func _fine(s: String) -> String:
	var ms := _seg_rx.search_all(s)
	if ms.is_empty():
		return _words(s)
	return _join(s, ms, _part)


## Ayraçlarla bölünmüş yazı: her konumda, ayraçlarıyla birlikte en uzun bilinen öbek çevrilir ("Süre doldu. Tek başına koştunuz."
## iki cümlelik tek kayıt; "Bir yem/klon ile ..." içinde ayraç geçen kayıt); eşleşmeyen tek parça yaprak işleve gider.
func _join(s: String, ms: Array, leaf: Callable) -> String:
	var a: Array = []   # parça başlangıcı
	var e: Array = []   # parça sonu
	var pos := 0
	for m in ms:
		a.append(pos)
		e.append(m.get_start())
		pos = m.get_end()
	a.append(pos)
	e.append(s.length())
	var out := ""
	var i := 0
	var n := a.size()
	while i < n:
		var hit := false
		for j in range(mini(n - 1, i + 8), i, -1):
			var r := _span(s.substr(a[i], e[j] - a[i]))
			if r != "":
				out += r
				i = j
				hit = true
				break
		if not hit:
			out += leaf.call(s.substr(a[i], e[i] - a[i]))
		if i < n - 1:
			out += s.substr(e[i], a[i + 1] - e[i])
		i += 1
	return out


## Öbek için ucuz arama (şablon denemez): tam / türetilmiş / harf büyüklüğü farkı
func _span(s: String) -> String:
	if s.length() < 3:
		return ""
	if exact.has(s):
		return exact[s]
	if derived.has(s):
		return derived[s]
	var lo := _low(s)
	if lower.has(lo):
		var v := String(lower[lo])
		return v.to_upper() if s == s.to_upper() and s != lo else v
	return ""


func _part(s: String) -> String:
	if s.length() < 2:
		return s
	var r := _one_c(s)
	return r if r != "" else _words(s)


## Kısa söz öbeği: baştaki ya da sondaki en uzun bilinen parça çevrilir ("Kaçak Sunagakure", "Hokage Kulesi")
func _words(s: String) -> String:
	var w := s.split(" ")
	if w.size() < 2 or w.size() > 6:
		return s
	for n in range(w.size() - 1, 0, -1):
		var head := " ".join(w.slice(0, n))
		var rest := " ".join(w.slice(n))
		var th := _plain(head)
		if th != "":
			var tr2 := _plain(rest)
			if tr2 == "" and not _is_name(rest):
				continue   # kalan Türkçe söz: yarım çeviri ("Single başına") yerine dokunma
			return th + " " + (tr2 if tr2 != "" else rest)
	for n in range(1, w.size()):
		var tail := " ".join(w.slice(n))
		var tt := _plain(tail)
		if tt != "" and _is_name(" ".join(w.slice(0, n))):
			return " ".join(w.slice(0, n)) + " " + tt
	return s


## Çevrilmeden kalabilecek parça: özel ad / romaji (her sözcük büyük harfle ya da harf dışıyla başlar)
func _is_name(s: String) -> bool:
	for x in s.split(" ", false):
		var ch := x.substr(0, 1)
		if ch != ch.to_upper() or ch == ch.to_lower() and not ch.is_valid_int() and x.length() > 2:
			return false
	return true


func _plain(s: String) -> String:
	if s.length() < 3:
		return ""
	if exact.has(s):
		return exact[s]
	if derived.has(s):
		return derived[s]
	return ""
