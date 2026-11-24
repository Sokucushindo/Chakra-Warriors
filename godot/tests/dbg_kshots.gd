extends Node
## Konoha serbest kamera: CAMS="x,n,yükseklik,hx,hn;..." (köy yerel; kamera (x,n)'de zeminden yükseklikte, (hx,hn)'ye bakar)
var main: Node
const VL = preload("res://scripts/world/village_life.gd")
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.42
	WorldDay.auto = false
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	var i = 0
	var specs = Array(OS.get_environment("CAMS").split(";", false))
	var npk = int(OS.get_environment("PARKS")) if OS.get_environment("PARKS") != "" else 0
	var pks: Array = CityLandscape.parks_by.get("konoha", [])
	for k in mini(npk, pks.size()):
		var pp: Vector2 = pks[(k * 7) % pks.size()]
		specs.append("%f,%f,7,%f,%f" % [pp.x - 22.0, pp.y - 22.0, pp.x, pp.y])
	print("KSHOT parks=%d" % pks.size())
	# ROADS=N: köy içi sokak noktaları (sokağın ortasında, sokak boyunca bakar); BENCH=N: park bankları
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	var nroad = int(OS.get_environment("ROADS")) if OS.get_environment("ROADS") != "" else 0
	var tries = 0
	while nroad > 0 and tries < 5000:
		tries += 1
		var rl: Dictionary = Game.roads[rng.randi() % Game.roads.size()]
		var pts: PackedVector2Array = rl["pts"]
		if pts.size() < 2:
			continue
		var k2 = rng.randi() % (pts.size() - 1)
		var m = pts[k2].lerp(pts[k2 + 1], 0.5)
		var lx = m.x - float(v["x"]); var ln = m.y - float(v["y"])
		if Vector2(lx, ln).length() > 900.0:
			continue
		var dd = (pts[k2 + 1] - pts[k2]).normalized() * 40.0
		specs.append("%f,%f,2.2,%f,%f" % [lx, ln, lx + dd.x, ln + dd.y])
		nroad -= 1
	var nb = int(OS.get_environment("BENCH")) if OS.get_environment("BENCH") != "" else 0
	var bs: Array = VL.sites.get("konoha", []).filter(func(e): return String(e.get("type", "")) == "bench")
	print("KSHOT bench=%d" % bs.size())
	for k in mini(nb, bs.size()):
		var be: Dictionary = bs[(k * 5) % bs.size()]
		var bp: Vector3 = be["pos"]
		var f = float(be.get("face", 0.0))
		var fd = Vector2(-sin(f), cos(f))   # bank -> park ortası (yerel x, n)
		var lx2 = bp.x - c.x; var ln2 = -(bp.z - c.z)
		specs.append("%f,%f,5,%f,%f" % [lx2 - fd.x * 6.0, ln2 - fd.y * 6.0, lx2 + fd.x * 9.0, ln2 + fd.y * 9.0])
	for spec in specs:
		var f = spec.split(",")
		var p = Vector3(c.x + float(f[0]), 0, c.z - float(f[1]))
		var t = Vector3(c.x + float(f[3]), 0, c.z - float(f[4]))
		main.player.respawn(Vector3(p.x, Game.terrain_height(p.x, p.z) + 1.0, p.z))
		await get_tree().create_timer(2.0).timeout
		main.player.visible = false
		p.y = Game.terrain_height(p.x, p.z) + float(f[2])
		t.y = Game.terrain_height(t.x, t.z) + 4.0
		cam.global_position = p
		cam.look_at(t, Vector3.UP)
		cam.current = true
		await get_tree().create_timer(0.5).timeout
		await main.shot("kc_%02d" % i)
		i += 1
	get_tree().quit()
