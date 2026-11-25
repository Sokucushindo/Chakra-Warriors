extends Node
## Hokage Kulesi görsel denetimi: saçak konisi / balkon altı / 火 plakası / tepe / kaide-zemin teması, gündüz + gece.
## Çıktı: _tmp/hokage_tower/ht_<gun|gece>_NN.png ; logda HT ring = kaide çevresinde zemin yüksekliği (kule tabanına göre)
var main: Node

const TN = 600.0
# x, n (köy yerel), y (kule tabanına göre mutlak; "g+h" = o noktadaki zeminden h), bakış x, n, y (tabana göre)
const CAMS = [
	["0", "560", "50.7", "0", "600", "57"],      # kullanıcı görüntüsü: saçak konisinin üstünde, balkon altına bakış
	["0", "520", "g+1.7", "0", "600", "56"],     # meydandan yukarı: balkon altı
	["0", "340", "g+20", "0", "600", "42"],      # uzaktan ön
	["150", "450", "g+15", "0", "600", "45"],    # uzaktan çapraz
	["30", "548", "g+1.0", "-25", "566", "0.5"], # yandan, zemin hizası: kaide-zemin teması
	["-30", "548", "g+1.0", "25", "566", "0.5"],
	["14", "566", "59.2", "0", "573.6", "62.3"], # balkondan 火 plakası
	["45", "545", "86", "0", "600", "78"],       # tepe: üst kat + küçük çatı
]

func _ready() -> void:
	await get_tree().process_frame
	if main.shot_dir == "":
		main.shot_dir = ProjectSettings.globalize_path("res://").path_join("../_tmp/hokage_tower").simplify_path()
	DirAccess.make_dir_recursive_absolute(main.shot_dir)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var base = Game.terrain_height(c.x, c.z - TN)
	# kaide (r 41) çevresinde zemin: kule tabanına göre (kaide üstü +0.9, altı şimdi -3.3)
	var ring = []
	var lo = 999.0; var hi = -999.0
	for k in 24:
		var a = TAU * k / 24.0
		for r in [41.0, 46.0]:
			var d = Game.terrain_height(c.x + sin(a) * r, c.z - TN - cos(a) * r) - base
			lo = minf(lo, d); hi = maxf(hi, d)
			if r == 41.0:
				ring.append("%.2f" % d)
	print("HT base=%.2f ring41=%s min=%.2f max=%.2f" % [base, ", ".join(ring), lo, hi])
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	for tod in [[0.42, "gun"], [0.95, "gece"]]:
		main.world.env.time_of_day = tod[0]
		var i = 0
		for s in CAMS:
			var p = Vector3(c.x + float(s[0]), 0, c.z - float(s[1]))
			var t = Vector3(c.x + float(s[3]), base + float(s[5]), c.z - float(s[4]))
			main.player.respawn(Vector3(p.x, Game.terrain_height(p.x, p.z) + 1.0, p.z))
			await get_tree().create_timer(1.5).timeout
			main.player.visible = false
			var ys: String = s[2]
			p.y = (Game.terrain_height(p.x, p.z) + float(ys.substr(2))) if ys.begins_with("g+") else base + float(ys)
			cam.global_position = p
			cam.look_at(t, Vector3.UP)
			cam.current = true
			await get_tree().create_timer(0.6).timeout
			await main.shot("ht_%s_%02d" % [tod[1], i])
			print("HT shot %s_%02d" % [tod[1], i])
			i += 1
	print("HT done -> %s" % main.shot_dir)
	get_tree().quit()
