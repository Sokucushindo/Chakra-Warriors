extends Node
## İngilizce seçiliyken karakter yaratma ekranı ve oyun içi bir konuşma kutusunda çevrilmemiş (Türkçe karakterli) yazı kalmasın.
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func visible_tr(root: Node) -> Array:
	var out := []
	var rx := RegEx.create_from_string("[çğıöşüÇĞİÖŞÜ]")
	for l in root.find_children("*", "", true, false):
		if (l is Label or l is Button or l is RichTextLabel) and l.is_visible_in_tree() and not l.is_queued_for_deletion():
			var t: String = l.text
			if l.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
				t = l.tr(t)
			if rx.search(t):
				out.append(t.left(160))
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(3)
	var old_lang = Game.settings.get("lang", "")
	Game.settings["lang"] = "en"
	Lang.apply("en")
	main.start_creator(97)
	await frames(30)
	var lo = visible_tr(Hud.dialog_layer)
	for c in main.get_children():
		if c is CanvasLayer or c is Control:
			lo.append_array(visible_tr(c))
	print("  yaratma ekranı: çevrilmemiş %d" % lo.size())
	for t in lo.slice(0, 12):
		print("    ", t)
	ok(lo.is_empty(), "karakter yaratma ekranı çevrili")
	# sağ ok ile birkaç seçeneği gez (◀ ▶ seçiciler): her adımdan sonra tara
	var seen := {}
	for n in 6:
		for b in Hud.dialog_layer.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and (String(b.text) == "▶" or String(b.text) == ">"):
				b.pressed.emit()
				break
		await frames(6)
		for t in visible_tr(Hud.dialog_layer):
			seen[t] = true
	print("  gezinti: çevrilmemiş %d" % seen.size())
	for t in seen.keys().slice(0, 12):
		print("    ", t)
	Game.settings["lang"] = "tr"
	Lang.apply("tr")
	Game.settings["lang"] = old_lang
	Game.apply_settings()
	print("SONUC: %d hata" % fails)
	get_tree().quit()
