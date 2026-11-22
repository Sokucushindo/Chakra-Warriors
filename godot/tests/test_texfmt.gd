extends Node
## Pakete giren dokuların (.godot/imported/*.ctex) biçim dökümü: VRAM sıkıştırmalı mı, ham mı?
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	var d := "res://.godot/imported"
	var by := {}
	var rows: Array = []
	for f in DirAccess.get_files_at(d):
		if not f.ends_with(".ctex"):
			continue
		var t := CompressedTexture2D.new()
		if t.load(d.path_join(f)) != OK:
			continue
		var img := t.get_image()
		if img == null:
			continue
		var fmt = img.get_format()
		var bytes = img.get_data().size()
		var k = "%s%s" % [("sıkıştırılmış " if img.is_compressed() else "HAM "), fmt]
		if not by.has(k):
			by[k] = [0, 0]
		by[k][0] += 1
		by[k][1] += bytes
		if not img.is_compressed():
			rows.append([bytes, f.substr(0, 70), img.get_width(), img.get_height(), fmt, img.has_mipmaps()])
	for k in by:
		print("TF %s: %d dosya, bellekte %.1f MB" % [k, by[k][0], by[k][1] / 1048576.0])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(130, rows.size()):
		print("TF HAM %5.1f MB %s %dx%d fmt %d mip %s" % [rows[i][0] / 1048576.0, rows[i][1], rows[i][2], rows[i][3], rows[i][4], rows[i][5]])
	get_tree().quit()
