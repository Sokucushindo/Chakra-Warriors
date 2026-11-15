extends Node
## Statik oyun verisi (autoload "Data"). Jutsu/klan/eşya tabloları research/ JSON'larından derlenmiş data/*.json'dan yüklenir.

const RANKS := ["Akademi Öğrencisi", "Genin", "Chunin", "Jonin", "ANBU", "Kage Adayı", "Kage"]

var jutsu = {}
var clans = {}
var items = {}
var skills = {}   # yetenek ağacı: {branches, nodes, sp_per_level, ...}
var seals: Array = []


func _ready() -> void:
	for pair in [["jutsu", "res://data/jutsu.json"], ["clans", "res://data/clans.json"], ["items", "res://data/items.json"], ["skills", "res://data/skills.json"]]:
		if FileAccess.file_exists(pair[1]):
			var d = JSON.parse_string(FileAccess.get_file_as_string(pair[1]))
			if d != null:
				set(pair[0], d)
	for k in LegendPaths.EXTRA_JUTSU:   # efsane yollarının veri dosyasında olmayan teknikleri
		if not jutsu.has(k):
			jutsu[k] = LegendPaths.EXTRA_JUTSU[k].duplicate(true)
			jutsu[k]["id"] = k
	if jutsu.has("_seals"):
		seals = jutsu["_seals"]
	apply_lang()


## Dil: veri yazılarını (açıklama, eşya adı...) seçili dile çevir. Jutsu adları (romaji) değişmez; jutsunun anlamı
## İngilizcede verideki İngilizce adıdır. Türkçe asıllar "_tr" altında saklanır: dil her değiştiğinde yerinde döner.
const LANG_FIELDS := {"jutsu": ["desc", "meaning"], "items": ["name", "desc"], "clans": ["name", "desc", "kg"]}
func apply_lang() -> void:
	var en := Lang.is_en()
	for table in LANG_FIELDS:
		var tb: Dictionary = get(table)
		for id in tb:
			if tb[id] is Dictionary:
				_lang_entry(tb[id], LANG_FIELDS[table], en, table == "jutsu")
	for id in skills.get("nodes", {}):
		if skills["nodes"][id] is Dictionary:
			_lang_entry(skills["nodes"][id], ["name", "desc"], en, false)
	for b in skills.get("branches", []):
		if b is Dictionary:
			_lang_entry(b, ["name"], en, false)


func _lang_entry(e: Dictionary, fields: Array, en: bool, is_jutsu: bool) -> void:
	if not e.has("_tr"):
		var keep := {}
		for f in fields:
			if e.get(f) is String:
				keep[f] = e[f]
		e["_tr"] = keep
	var tr: Dictionary = e["_tr"]
	for f in tr:
		if not en:
			e[f] = tr[f]
		elif is_jutsu and f == "meaning" and String(e.get("name_en", "")) != "":
			e[f] = e["name_en"]
		else:
			e[f] = Lang.t(tr[f])


## 100 seviye uzun vadeli hedef: erken seviyeler hızlı, 50'den sonra yavaşlar
const MAX_LEVEL := 100
func xp_for_level(lv: int) -> int:
	# yumuşak eğri: düşman ve görev XP'si de seviyeyle büyüdüğü için yüksek seviyeler tıkanmaz
	return int(40.0 + 11.0 * pow(lv, 1.55))   # Sv.10 ~430, Sv.24 ~1.5k, Sv.50 ~4.6k, Sv.99 ~13.5k
