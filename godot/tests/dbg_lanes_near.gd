extends Node
## Park banklarının çevresindeki çimen maskesi şeritleri (RoadMap.lanes) sayısı
var main: Node
const VL = preload("res://scripts/world/village_life.gd")
const RM = preload("res://scripts/world/road_map.gd")
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	var bs: Array = VL.sites.get("konoha", []).filter(func(e): return String(e.get("type", "")) == "bench")
	print("LANES toplam=%d" % RM.lanes.size())
	for k in 3:
		var be: Dictionary = bs[(k * 5) % bs.size()]
		var bp: Vector3 = be["pos"]
		var near = 0; var wide = []
		for ln in RM.lanes:
			var a: Vector2 = ln[0]; var e: Vector2 = ln[1]
			var d = Geometry2D.get_closest_point_to_segment(Vector2(bp.x, bp.z), a, e).distance_to(Vector2(bp.x, bp.z))
			if d < 25.0:
				near += 1
				if float(ln[2]) > 3.0:
					wide.append("%.1f@%.0f" % [float(ln[2]), d])
		print("LANES bank%d pos=(%.0f,%.0f) yakin=%d genis=%s" % [k, bp.x, bp.z, near, str(wide)])
	get_tree().quit()
