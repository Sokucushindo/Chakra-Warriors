extends Node
## İngilizce modda dünya olaylarını hızla ilerlet: haber + kişi günlüğü + arkadaş günlüğü metinlerini çevir, Türkçe kalanı yaz
var main: Node
const TR := "ışğİŞĞçÇöÖüÜ"
func _has_tr(s: String) -> bool:
	for ch in TR:
		if ch in s:
			return true
	for w in [" ve ", " bir ", " ile ", "'in ", "'nin ", "'ın ", "'yi ", "'ye ", " öldü", " oldu"]:
		if w in s:
			return true
	return false
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "uchiha", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Lang.apply("en")
	var seen := {}
	var heard: Array = []
	var ticks = int(OS.get_environment("TICKS")) if OS.get_environment("TICKS") != "" else 300
	var wp: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() == preload("res://scripts/core/world_people.gd"):
			wp = n
			break
	print("NEWSLANG wp=", wp)
	for i in ticks:
		if wp:
			wp.world_tick()
		WorldKin.world_tick(30.0)
		WorldAmbition.world_tick()
		WorldDay.tick(30.0)
		WorldNews.tick(30.0)
		if i % 20 == 0:
			await get_tree().process_frame
	for p in WorldPeople.all().values():
		for e in p.get("log", []):
			var t = String(e[1]) if e is Array and e.size() > 1 else String(e)
			heard.append(t)
	for t in WorldNews.D()["news"]:
		heard.append(String(t))
	if Engine.has_singleton("Friends") or true:
		for f in Friends.all().values():
			for e in f.get("log", []):
				heard.append(String(e[1]) if e is Array and e.size() > 1 else String(e))
	var bad := {}
	for t in heard:
		var en = Lang.t(t)
		if _has_tr(en):
			# kalıbı tekilleştir: rakamları ve özel adları kabaca at
			var key = en.substr(0, 70)
			if not seen.has(key):
				seen[key] = true
				bad[t] = en
	print("NEWSLANG toplam=%d turkce_kalan=%d" % [heard.size(), bad.size()])
	var n = 0
	for k in bad:
		print("NEWSLANG TR: %s  ||  EN: %s" % [k, bad[k]])
		n += 1
		if n >= 120:
			break
	Lang.apply("tr")
	get_tree().quit()
