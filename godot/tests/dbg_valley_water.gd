extends Node
## Sonun Vadisi: oyuncuyu nehre koy, 40 sn bekle; yakındaki karakterlerin y'si ile su yüzeyi / arazi / ground_height'i yaz + kare
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	var l = {}
	for x in Game.world_info["landmarks"]:
		if String(x.get("id", "")) == "valley_end":
			l = x
	print("VW landmark=", l.get("name", "?"), " type=", l.get("type", "?"))
	var spec: Dictionary = l.get("spec", {"river": -3.0, "fall_dy": 520.0})
	var c = Game.from_map(Vector2(l["x"], l["y"]))
	var pl = main.player
	var p = c + Vector3(0, 0, -(float(spec["fall_dy"]) - 200.0))
	p.y = Game.ground_height(p.x, p.z) + 0.5
	pl.respawn(p)
	await get_tree().create_timer(40.0).timeout
	pl = main.player
	print("VW player y=%.2f terr=%.2f wl=%.2f gh=%.2f" % [pl.global_position.y, Game.terrain_height(pl.global_position.x, pl.global_position.z), Game.water_level(pl.global_position.x, pl.global_position.z), Game.ground_height(pl.global_position.x, pl.global_position.z)])
	var n = 0
	for f in get_tree().current_scene.find_children("*", "CharacterBody3D", true, false):
		var q: Vector3 = f.global_position
		if q.distance_to(pl.global_position) > 400.0 or f == pl:
			continue
		var terr = Game.terrain_height(q.x, q.z)
		var wl = Game.water_level(q.x, q.z, terr)
		print("VW npc %s cls=%s y=%.2f terr=%.2f wl=%.2f gh=%.2f state=%s" % [f.name, f.get_script().resource_path.get_file() if f.get_script() else "?", q.y, terr, wl, Game.ground_height(q.x, q.z), str(f.get("state"))])
		n += 1
		if n > 25:
			break
	await main.shot("valley_water")
	get_tree().quit()
