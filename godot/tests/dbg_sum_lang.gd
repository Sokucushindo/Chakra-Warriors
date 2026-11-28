extends Node
## Çağrıların konuşma satırları İngilizcede çevriliyor mu
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	Lang.apply("en")
	var bad = 0
	var n = 0
	var rx = RegEx.new()
	rx.compile("[çğışöüÇĞİŞÖÜ]")
	var lines = ["Anlaşıldı!", "Chakran bitti, gidiyorum!", "Kokusu buradan geliyor!", "Hedefin izi pusulanın gösterdiği yönde!", "Bölünüyorum! Herkes iyileşsin!", "Elmas asaya dönüşüyorum!"]
	var src = FileAccess.get_file_as_string("res://scripts/core/contracts.gd")
	var r2 = RegEx.new()
	r2.compile("\"lines\": .([^
]+)")
	var r3 = RegEx.new()
	r3.compile("\"([^\"]+)\"")
	for m in r2.search_all(src):
		for q in r3.search_all(m.get_string(1)):
			lines.append(q.get_string(1))
	for l in lines:
		n += 1
		var e = Lang.t(l)
		if e == l and l != "..." and not l.begins_with("Ssss...") or rx.search(e) != null:
			bad += 1
			print("SUMLANG kaldı: ", l, " -> ", e)
	print("SUMLANG satır=", n, " çevrilmeyen=", bad, " örnek=", Lang.t(lines[8]))
	Lang.apply("tr")
	get_tree().quit()
