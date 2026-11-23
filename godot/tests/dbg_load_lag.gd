extends Node
## Kayıt yükledikten sonraki dakikalarda FPS: kullanıcının kaydının kopyası (yuva 97) yüklenir, oyuncu LL_AT köyünün dışına konur,
## saniyelik FPS + en pahalı _process'ler (instr.py açıkken) yazılır.
var main: Node
var _n := 0
var _t := 0.0
var _el := 0.0
var _worst := 0.0


func _ready() -> void:
	var src = ProjectSettings.globalize_path("user://kayitlar/kayit_1.json")
	DirAccess.copy_absolute(src, ProjectSettings.globalize_path("user://kayitlar/kayit_97.json"))
	await get_tree().process_frame
	var at = OS.get_environment("LL_AT")
	if at != "":
		var p97 = ProjectSettings.globalize_path("user://kayitlar/kayit_97.json")
		var d = JSON.parse_string(FileAccess.get_file_as_string(p97))
		var v = Game.village(at)
		var c = Game.from_map(Vector2(v["x"], v["y"] + float(v.get("r", 400)) + 300.0))
		c.y = Game.terrain_height(c.x, c.z) + 1.0
		d["pos"] = [c.x, c.y, c.z]
		var f = FileAccess.open(p97, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
	Engine.set_meta("pf", {})
	var t0 = Time.get_ticks_msec()
	await main.load_slot(97)
	print("LL yukleme ekrani bitti %.1f sn" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if OS.get_environment("LL_SHOT") != "":
		await _shots()
		get_tree().quit()
		return
	print("LL basladi")


func _process(dt: float) -> void:
	if main == null or main.player == null:
		return
	_n += 1
	_t += dt
	_el += dt
	_worst = maxf(_worst, dt)
	if _t >= 2.0:
		var line = "LL T%03d FPS %d en kotu %d" % [int(_el), int(_n / _t), int(1.0 / _worst)]
		if Engine.has_meta("pf"):
			var d: Dictionary = Engine.get_meta("pf")
			var ks = d.keys()
			ks.sort_custom(func(a, b): return d[a] > d[b])
			var top = []
			for k in ks.slice(0, 6):
				top.append("%s %d" % [k, int(d[k] / 1000.0 / _t * 1.0)])   # saniyede harcanan (binde saniye)
			line += " | " + ", ".join(top)
			Engine.set_meta("pf", {})
		print(line)
		_n = 0
		_t = 0.0
		_worst = 0.0
	if _el > float(OS.get_environment("LL_SEC") if OS.get_environment("LL_SEC") != "" else "240"):
		get_tree().quit()


## Yakındaki dünya bölgesi yerleşimlerini havadan çek (peyzaj merkez kayması kontrolü)
func _shots() -> void:
	var cam := Camera3D.new()
	cam.far = 3000.0
	main.add_child(cam)
	cam.current = true
	var hs := []
	for b in get_tree().root.find_children("Yapilar", "", true, false):
		var mis = b.find_children("K*", "MeshInstance3D", false, false)
		if mis.size() > 0:
			hs.append((mis[0] as Node3D).get_parent())
	var i := 0
	for n in get_tree().root.find_children("Bolge_*", "", true, false):
		var aabb := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var a2: AABB = (mi as MeshInstance3D).get_aabb()
			if a2.size.length() > 400.0 or a2.size.length() < 1.0:
				continue
			var g = (mi as MeshInstance3D).global_transform * a2
			aabb = g if first else aabb.merge(g)
			first = false
		if first:
			continue
		var c := aabb.get_center()
		print("LL bolge %s merkez %s boy %s" % [n.name, c, aabb.size])
		cam.global_position = c + Vector3(0, 160, 120)
		cam.look_at(c, Vector3.UP)
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2)
		im.save_png("res://../_tmp/ll_%d.png" % i)
		i += 1
		if i >= 4:
			break
