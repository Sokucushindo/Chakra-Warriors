extends Node
## Takılma kaynağı: her _process / _physics_process süresi ölçülür (geçici enstrümantasyon, _tmp/instr.py),
## 40 ms'yi aşan karelerde en pahalı kalemler yazılır. HT_SPEED (m/sn), HT_FROM, HT_DIR, HT_SEC
var main: Node
var pl: Player
var pos := Vector2.ZERO
var dir := Vector2(0, -1)
var speed := 0.0
var _lt := 0
var on := false
var tot := {}
var frames := []
var spikes := 0
var _tp := 0
var _td := 0
var _te := 0
var ph := [0.0, 0.0, 0.0]   # önceki karenin: fizik + bekleme, işleyiş, çizim (ms)
var _ph_next := [0.0, 0.0, 0.0]


var _lpf := 0
var _t_on := 0
func _on_pf() -> void:
	var nw = Time.get_ticks_usec()
	if on and _lpf > 0 and nw - _lpf > 40000:
		print("T%.2f " % ((nw - _t_on) / 1000000.0), "HF dongu %.0f | isleyis %.0f cizim %.0f fizik+bekleme %.0f | asama isi %.1f (%d adet)" % [(nw - _lpf) / 1000.0, (_td - _tp) / 1000.0, (_te - _td) / 1000.0, (nw - _te) / 1000.0, int(Engine.get_meta("stg_us", 0)) / 1000.0, int(Engine.get_meta("stg_n", 0))])
	Engine.set_meta("stg_us", 0)
	Engine.set_meta("stg_n", 0)
	_lpf = nw
	_tp = nw
	ph = _ph_next.duplicate()
	if _te > 0:
		_ph_next[0] = (_tp - _te) / 1000.0


func _on_pre() -> void:
	_td = Time.get_ticks_usec()
	_ph_next[1] = (_td - _tp) / 1000.0


func _on_post() -> void:
	_te = Time.get_ticks_usec()
	_ph_next[2] = (_te - _td) / 1000.0

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken",
		"hair": Color(0.3, 0.2, 0.12), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	pl = main.player
	Game.world.env.time_of_day = 0.4
	Game.world.env.weather_t = 999
	var v = Game.village("konoha")
	var f = OS.get_environment("HT_FROM").split(",")
	pos = Vector2(v["x"], v["y"]) + (Vector2(float(f[0]), float(f[1])) if f.size() == 2 else Vector2(0, 100))
	var d = OS.get_environment("HT_DIR").split(",")
	if d.size() == 2:
		dir = Vector2(float(d[0]), float(d[1])).normalized()
	if OS.get_environment("HT_TO") != "":   # başka bir köye doğru: yol üstünde orman, yol, öbür köy
		var v2 = Game.village(OS.get_environment("HT_TO"))
		dir = (Vector2(v2["x"], v2["y"]) - Vector2(v["x"], v["y"])).normalized()
		print("HT rota %s -> %s uzaklik %.0f m" % ["konoha", OS.get_environment("HT_TO"), Vector2(v2["x"], v2["y"]).distance_to(Vector2(v["x"], v["y"]))])
	pl.respawn(Game.from_map(pos))
	await get_tree().create_timer(5.0).timeout
	speed = float(OS.get_environment("HT_SPEED")) if OS.get_environment("HT_SPEED") != "" else 0.0
	var sec = float(OS.get_environment("HT_SEC")) if OS.get_environment("HT_SEC") != "" else 25.0
	Engine.set_meta("pf", {})
	if OS.get_environment("HT_PROF") != "":
		load("res://scripts/actors/character_model.gd").set("PROF", true)
	get_tree().process_frame.connect(_on_pf)
	RenderingServer.frame_pre_draw.connect(_on_pre)
	RenderingServer.frame_post_draw.connect(_on_post)
	on = true
	_t_on = Time.get_ticks_usec()
	if OS.get_environment("HT_REAL") != "":   # gerçek tuşlarla koşu: ileri + Shift (ninja koşusu), 2 sn'de bir Ctrl süper zıplama
		pl.facing = atan2(-dir.x, dir.y)
		Input.action_press("forward")
		Input.action_press("dash")
		var tl = sec
		while tl > 0.0:
			await get_tree().create_timer(2.0).timeout
			tl -= 2.0
			print("T%.2f LEAP" % ((Time.get_ticks_usec() - _t_on) / 1000000.0))
			Input.action_press("leap")
			await get_tree().create_timer(0.12).timeout
			Input.action_release("leap")
		Input.action_release("forward")
		Input.action_release("dash")
	else:
		await get_tree().create_timer(sec).timeout
	on = false
	frames.sort()
	var n = frames.size()
	var s = 0.0
	for x in frames:
		s += x
	for x in get_tree().root.find_children("*", "Node3D", true, false):
		if x.get_script() != null and String(x.get_script().resource_path).ends_with("village_life.gd"):
			print("HT on kurulumla giren=%d bekleyen=%d koydeki kisi=%d" % [x.staged_n, x._pend.size(), x.npcs.size()])
	print("HT hiz=%d kare=%d ort=%.1f p50=%.1f p95=%.1f p99=%.1f max=%.0f >40ms=%d >100ms=%d" % [int(speed), n, s / n, frames[n / 2], frames[int(n * 0.95)], frames[int(n * 0.99)], frames[-1], frames.filter(func(x): return x > 40.0).size(), frames.filter(func(x): return x > 100.0).size()])
	var ks = tot.keys()
	ks.sort_custom(func(a, b): return tot[a] > tot[b])
	for k in ks.slice(0, 14):
		print("HT toplam %-26s %.0f ms (kare başı %.2f)" % [k, tot[k] / 1000.0, tot[k] / 1000.0 / n])
	print("HT toplam sure %.0f ms" % s)
	get_tree().quit()


var _dr_t := 0.0
func _process(_dt: float) -> void:
	var now = Time.get_ticks_usec()
	if on and OS.get_environment("HT_DRAW") != "":
		_dr_t += _dt
		if _dr_t > 1.0 and not has_meta("census") and Engine.get_frames_drawn() > 600:
			set_meta("census", true)
			var cam = get_viewport().get_camera_3d()
			var by := {}
			var mmn := {}
			for gi in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
				if not gi.is_visible_in_tree():
					continue
				var d = gi.global_position.distance_to(cam.global_position)
				if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end + gi.visibility_range_end_margin:
					continue
				var top = gi
				var path := []
				var n = gi.get_parent()
				while n != null and n != get_tree().root and path.size() < 6:
					path.push_front(String(n.name))
					n = n.get_parent()
				var bucket = "<150" if d < 150.0 else ("<500" if d < 500.0 else (">1500" if d > 1500.0 else "<1500"))
				var key = "/".join(path.slice(0, 4)) + " :" + gi.get_class().replace("Instance3D", "") + " " + bucket + (" aralik=%d" % int(gi.visibility_range_end))
				by[key] = int(by.get(key, 0)) + 1
				if gi is MultiMeshInstance3D and gi.multimesh:
					mmn[key] = int(mmn.get(key, 0)) + gi.multimesh.visible_instance_count if gi.multimesh.visible_instance_count >= 0 else gi.multimesh.instance_count
			var ic := {}
			var meshes := {}
			for mmi in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
				if mmi.multimesh and mmi.is_visible_in_tree() and String(mmi.get_path()).contains("Sites/Konoha"):
					var c = mmi.multimesh.instance_count
					var b2 = "1" if c <= 1 else ("2-4" if c <= 4 else ("5-20" if c <= 20 else ">20"))
					ic[b2] = int(ic.get(b2, 0)) + 1
					meshes[mmi.multimesh.mesh] = true
			print("KONOHA MM ornek_sayisi ", ic, " farkli_model=", meshes.size())
			var par := {}
			var nonid := 0
			var pnames := {}
			for mmi in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
				if mmi.multimesh and String(mmi.get_path()).contains("Sites/Konoha"):
					par[mmi.get_parent()] = int(par.get(mmi.get_parent(), 0)) + 1
					if not mmi.transform.is_equal_approx(Transform3D.IDENTITY):
						nonid += 1
					var pn = String(mmi.get_parent().name).left(6) + "<" + String(mmi.get_parent().get_parent().name).left(8)
					pnames[pn] = int(pnames.get(pn, 0)) + 1
			var pk = pnames.keys()
			pk.sort_custom(func(a, b): return pnames[a] > pnames[b])
			print("KONOHA ebeveyn=%d birim_olmayan=%d ornek_ebeveyn=%s" % [par.size(), nonid, str(pk.slice(0, 8).map(func(x): return "%s:%d" % [x, pnames[x]]))])
			var ks = by.keys()
			ks.sort_custom(func(a, b): return by[a] > by[b])
			for k in ks.slice(0, 25):
				print("CIZIM %5d  %s" % [by[k], k])
		if _dr_t > 1.0:
			_dr_t = 0.0
			print("DRAW fps=%d cagri=%d nesne=%d ucgen=%dk | gorunen_mi=%d" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000), get_tree().get_nodes_in_group("fighters").size()])
	if _lt != 0 and on:
		var ms = (now - _lt) / 1000.0
		frames.append(ms)
		var d: Dictionary = Engine.get_meta("pf")
		var sum = 0.0
		for k in d:
			tot[k] = tot.get(k, 0) + d[k]
			sum += d[k]
		if ms > 40.0:
			spikes += 1
			var ks = d.keys()
			ks.sort_custom(func(a, b): return d[a] > d[b])
			var top = []
			for k in ks.slice(0, 4):
				top.append("%s=%.0f" % [k, d[k] / 1000.0])
			if spikes <= 60:
				print("HT kare %.0f ms | fizik+bekleme %.0f isleyis %.0f cizim %.0f | olculen %.0f | %s" % [ms, ph[0], ph[1], ph[2], sum / 1000.0, ", ".join(top)])
		d.clear()
		if speed > 0.0:
			pos += dir * speed * ms / 1000.0
			var p = Game.from_map(pos)
			p.y = Game.ground_height(p.x, p.z)
			pl.global_position = p
			pl.velocity = Vector3.ZERO
	_lt = now
