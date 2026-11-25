extends Node
## Konoha 2B harita dökümü (köy yerel x doğu, n kuzey): evler, ağaçlar, sokaklar, patikalar, parklar -> _tmp/kmap/map.json
## Python: python _tmp/kmap/plot.py  (kuşbakışı yerleşim haritası)
var main: Node
const RM = preload("res://scripts/world/road_map.gd")
const VLX = preload("res://scripts/world/village_life.gd")
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	WorldDamage._drain()
	var v = Game.village("konoha")
	var vc = Vector2(float(v["x"]), float(v["y"]))
	var c = Game.from_map(vc)
	var loc = func(wx: float, wz: float) -> Array: return [snappedf(wx - c.x, 0.1), snappedf(-(wz - c.z), 0.1)]
	var houses: Array = []
	for k in WorldDamage.hgrid:
		for rec in WorldDamage.hgrid[k]:
			var t: Dictionary = HouseKit.templates[int(rec["ti"])]
			var p: Vector3 = rec["pos"]
			if Vector2(p.x - c.x, p.z - c.z).length() > 1600.0:
				continue
			var bs: Basis = rec["basis"]
			var xa = bs.x
			houses.append(loc.call(p.x, p.z) + [float(t["w"]), float(t["d"]), snappedf(atan2(-xa.z, xa.x), 0.01), int(rec["ti"])])
	var trees: Array = []
	for k in Builder.tree_grid:
		for t in Builder.tree_grid[k]:
			var tp: Vector2 = t[0]
			if Vector2(tp.x - c.x, tp.y - c.z).length() < 1600.0:
				trees.append(loc.call(tp.x, tp.y))
	var roads: Array = []
	for rd in Game.roads:
		var pts: PackedVector2Array = rd["pts"]
		var near = false
		var arr: Array = []
		for pp in pts:
			var lp = pp - vc
			arr.append([snappedf(lp.x, 0.1), snappedf(lp.y, 0.1)])
			if lp.length() < 1600.0:
				near = true
		if near:
			roads.append({"kind": rd["kind"], "pts": arr})
	var lanes: Array = []
	for ln in RM.lanes:
		var a: Vector2 = ln[0]
		var e: Vector2 = ln[1]
		if Vector2(a.x - c.x, a.y - c.z).length() < 1600.0:
			lanes.append(loc.call(a.x, a.y) + loc.call(e.x, e.y) + [float(ln[2]), bool(ln[3])])
	var parks: Array = []
	for pk in CityLandscape.parks_by.get("konoha", []):
		parks.append([pk.x, pk.y])
	var sites: Array = []
	for s in VLX.sites.get("konoha", []):
		var sp: Vector3 = s["pos"]
		sites.append(loc.call(sp.x, sp.z) + [String(s.get("type", ""))])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/kmap"))
	var f = FileAccess.open("res://../_tmp/kmap/map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"r": float(v["r"]), "houses": houses, "trees": trees, "roads": roads, "lanes": lanes, "parks": parks, "sites": sites}))
	f.close()
	print("KMAP ev=%d agac=%d yol=%d serit=%d park=%d site=%d" % [houses.size(), trees.size(), roads.size(), lanes.size(), parks.size(), sites.size()])
	get_tree().quit()
