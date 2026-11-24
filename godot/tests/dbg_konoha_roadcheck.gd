extends Node
## Konoha evleri: duvar ayak izi yolun görünen kenarına giriyor mu (YOLDA), evler iç içe mi (IC), tür dağılımı
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	WorldDamage._drain()
	var recs: Array = []
	for k in WorldDamage.hgrid:
		for rec in WorldDamage.hgrid[k]:
			recs.append(rec)
	var on_road = 0
	var ex: Array = []
	var types = {}
	for rec in recs:
		var t: Dictionary = HouseKit.templates[int(rec["ti"])]
		types[int(rec["ti"])] = int(types.get(int(rec["ti"]), 0)) + 1
		var b: Basis = rec["basis"]
		var p: Vector3 = rec["pos"]
		var hw = float(t["w"]) * 0.5 - 1.2
		var hd = float(t["d"]) * 0.5 - 1.2
		var worst = 1e9
		var u = -hw
		while u <= hw + 0.01:
			var v = -hd
			while v <= hd + 0.01:
				var q = p + b * Vector3(u, 0, v)
				worst = minf(worst, Game.road_edge_dist(q.x, q.z))
				v += 2.0
			u += 2.0
		if worst < -0.5:
			on_road += 1
			if ex.size() < 15:
				ex.append("(%.0f,%.0f) ti=%d derin=%.1f" % [p.x, p.z, int(rec["ti"]), -worst])
	print("ROADCHK ev=%d yolda=%d  %s" % [recs.size(), on_road, str(ex)])
	var ks = types.keys()
	ks.sort()
	var line = []
	for k in ks:
		line.append("%d:%d" % [k, types[k]])
	print("ROADCHK turler(%d): %s" % [ks.size(), " ".join(line)])
	get_tree().quit()
