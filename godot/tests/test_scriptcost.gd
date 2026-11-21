extends Node
## Her .gd dosyasının kendi derleme süresi (CACHE_MODE_IGNORE ile yeniden yükle): açılış yükü hangi betiklerde?
var main: Node


func _scan(d: String, out: Array) -> void:
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".gd"):
			out.append(d.path_join(f))
	for s in DirAccess.get_directories_at(d):
		_scan(d.path_join(s), out)


func _ready() -> void:
	await get_tree().process_frame
	var files: Array = []
	_scan("res://scripts", files)
	var rows: Array = []
	var total := 0.0
	for p in files:
		var t0 = Time.get_ticks_usec()
		var s = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
		var dt = (Time.get_ticks_usec() - t0) / 1000.0
		total += dt
		rows.append([dt, p, FileAccess.get_file_as_bytes(p).size() / 1024])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("SC toplam %d dosya, %.0f ms" % [files.size(), total])
	for i in rows.size():
		print("SC %7.1f ms  %5d KB  %s" % [rows[i][0], rows[i][2], rows[i][1]])
	var by := {}
	for r in rows:
		var k = String(r[1]).get_base_dir()
		by[k] = float(by.get(k, 0.0)) + r[0]
	for k in by:
		print("SC klasör %7.0f ms %s" % [by[k], k])
	get_tree().quit()
