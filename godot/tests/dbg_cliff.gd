extends Node
## Konoha kuzey uçurumu teşhisi (Hokage Kayası): uçurum kenarı profili, merdiven, uçuruma giden yollar, parklar,
## dik yamaçtaki süsler (MultiMesh örnekleri + düğümler). Satırlar "CLF".
var main: Node


func _w(x: float, n: float) -> Vector3:
	return Vector3(-500.0 + x, 0.0, 750.0 - n)


func _slope(p: Vector3) -> float:
	var h = Game.terrain_height(p.x, p.z)
	var m = 0.0
	for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
		m = maxf(m, absf(Game.terrain_height(p.x + o.x, p.z + o.y) - h) / 2.0)
	return m


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	var cn = 1170.0
	# 1) uçurum kenarı: her x için tepe kenarının n'si (yükseklik tepeye ~ulaştığı ilk n) ve dibin n'si
	for x in range(-1300, 400, 100):
		var foot = -1.0; var edge = -1.0
		var h0 = Game.terrain_height(_w(x, cn - 200).x, _w(x, cn - 200).z)
		var top = -1e9
		for n in range(int(cn) - 200, int(cn) + 400, 2):
			var p = _w(x, n)
			top = maxf(top, Game.terrain_height(p.x, p.z))
		for n in range(int(cn) - 200, int(cn) + 400, 2):
			var p = _w(x, n)
			var h = Game.terrain_height(p.x, p.z)
			if foot < 0 and h > h0 + 4.0: foot = n
			if edge < 0 and h > top - 3.0: edge = n
		print("CLF kenar x=%d dip_n=%.0f tepe_n=%.0f dip_h=%.1f tepe_h=%.1f" % [x, foot, edge, h0, top])
	# 2) yollar: uçurum bandına giren yol uçları
	for ri in Game.roads.size():
		var rd: Dictionary = Game.roads[ri]
		var pts: PackedVector2Array = rd["pts"]
		var inb = 0
		var first = Vector2.INF; var last = Vector2.INF
		for q in pts:
			var lx = q.x + 500.0; var ln = q.y + 750.0
			if lx > -1450 and lx < 450 and ln > cn - 60 and ln < cn + 500:
				inb += 1
				if first == Vector2.INF: first = Vector2(lx, ln)
				last = Vector2(lx, ln)
		if inb > 0:
			print("CLF yol %d tur=%s %s->%s nokta=%d bantta ilk=%s son=%s" % [ri, rd["kind"], rd["a"], rd["b"], pts.size(), str(first), str(last)])
	# 3) parklar
	for k in CityLandscape.parks_by:
		for p in CityLandscape.parks_by[k]:
			print("CLF park %s %s" % [k, str(p)])
	# 4) dik yamaçta duran şeyler (uçurum bandında, eğim > 0.7)
	var groups := {}
	for mmi in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = mmi.multimesh
		if mm == null:
			continue
		var xf: Transform3D = mmi.global_transform
		for i in mm.instance_count:
			var p: Vector3 = xf * mm.get_instance_transform(i).origin
			var lx = p.x + 500.0; var ln = 750.0 - p.z
			if lx < -1450 or lx > 450 or ln < cn - 80 or ln > cn + 400:
				continue
			if _slope(p) > 0.7:
				var key = "%s/%s" % [mmi.get_parent().name, mmi.name]
				if not groups.has(key):
					groups[key] = [0, p]
				groups[key][0] += 1
	for k in groups:
		print("CLF dik_yamac %s adet=%d ornek=%s" % [k, groups[k][0], str(groups[k][1])])
	var ng := {}
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is MultiMeshInstance3D or not n.is_inside_tree():
			continue
		var p: Vector3 = n.global_position
		var lx = p.x + 500.0; var ln = 750.0 - p.z
		if lx < -1450 or lx > 450 or ln < cn - 60 or ln > cn + 400:
			continue
		if _slope(p) > 0.9 and absf(p.y - Game.terrain_height(p.x, p.z)) < 4.0:
			var key = "%s/%s" % [n.get_parent().name, n.get_class()]
			if not ng.has(key):
				ng[key] = [0, p, n.name]
			ng[key][0] += 1
	for k in ng:
		print("CLF dik_dugum %s adet=%d ornek=%s ad=%s" % [k, ng[k][0], str(ng[k][1]), ng[k][2]])
	get_tree().quit()
