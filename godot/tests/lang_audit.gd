extends Node
## Çeviri denetçisi: oyunu İngilizce'ye alır, AUDIT_TEST ile verilen akış testini içinde koşturur ve o sırada ekrana çıkan
## bütün yazıları (Label / Button / RichTextLabel / Label3D) AUDIT_OUT dosyasına döker. Ayıklama: tools/i18n_audit.py
## Oyuncunun ayar dosyasına dokunmaz (yalnız bellekte dil değişir).
var main: Node
var seen := {}
var out: FileAccess
var acc := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Lang.apply("en")
	out = FileAccess.open(OS.get_environment("AUDIT_OUT"), FileAccess.WRITE)
	var path := OS.get_environment("AUDIT_TEST")
	var script: GDScript = load(path)
	var t: Node = script.new()
	t.set("main", main)
	main.add_child.call_deferred(t)


func _process(dt: float) -> void:
	acc += dt
	if acc < 0.12:
		return
	acc = 0.0
	if not Lang.is_en():
		Lang.apply("en")
	_scan(get_tree().root)
	out.flush()


func _scan(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is Node3D and not c.visible:
			continue
		if c is Label or c is Button or c is RichTextLabel or c is Label3D:
			var t: String = c.text
			if t.length() >= 2 and not seen.has(t):
				seen[t] = true
				var shown := t
				if not (c is RichTextLabel) and c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
					shown = c.tr(t)
				if c is Control and c.tooltip_text != "":
					out.store_line(JSON.stringify(["tip", c.tr(c.tooltip_text)]))
				out.store_line(JSON.stringify([c.get_class(), shown]))
		_scan(c)
