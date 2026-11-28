extends Node
## Adım sesi denetimi: köy çatısında kiremit, köprüde tahta / taş (şıpırtı yok), yerde eski ses
var main: Node
var last := ""
var cols := {}
var wn := 0
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _deck(x: float, z: float) -> float:
	var sp = get_tree().current_scene.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -20, z), 1)
	var h = sp.intersect_ray(q)
	if h.is_empty():
		return -999.0
	var co = h["collider"]
	var nm = "%s|%s|%s" % [co.get_class(), co.name, co.get_parent().name if co.get_parent() else ""]
	var nrm = "eğimli" if float(h["normal"].y) < 0.93 else "düz"
	last = nm.rstrip("0123456789@") + "|" + nrm + "|" + str(co.get_groups())
	return float(h["position"].y)
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	await _w(2.0)
	var k = Game.village("konoha")
	var c = Game.from_map(Vector2(float(k["x"]), float(k["y"])))
	var cnt := {}
	var ex := {}
	for ix in range(-150, 151):
		for iz in range(-150, 151):
			var x = c.x + ix * 2.0
			var z = c.z + iz * 2.0
			var th = Game.terrain_height(x, z)
			var wl = Game.water_level(x, z, th)
			var dy = _deck(x, z)
			if dy < -900.0:
				continue
			if wl > th + 0.05:
				wn += 1
				if dy > wl + 0.02:
					print("ROOFW su üstü yapı h-su=%.2f su-arazi=%.2f ses=%s ıslak=%.2f yol=%.2f" % [dy - wl, wl - th, Game.step_sound(Vector3(x, dy, z)), Game.step_wetness(Vector3(x, dy, z)), Game.road_at(x, z)])
			elif Game.wet_at(x, z) > 0.6 and dy > th + 0.5 and dy < th + 3.0:
				print("ROOFW kıyı üstü yapı h-arazi=%.2f ses=%s ıslak=%.2f" % [dy - th, Game.step_sound(Vector3(x, dy, z)), Game.step_wetness(Vector3(x, dy, z))])
			var kind = ""
			if wl > th + 0.05 and dy > wl + 0.05:
				kind = "köprü(su üstü yapı)"
			elif dy > th + 3.0:
				kind = "çatı"
			elif dy < th + 0.3 and not (wl > th + 0.02):
				kind = "yer"
			else:
				continue
			var p = Vector3(x, dy, z)
			cols[kind + " " + last] = int(cols.get(kind + " " + last, 0)) + 1
			var key = "%s -> %s%s" % [kind, Game.step_sound(p).rstrip("0123456789"), " +şıpırtı" if Game.step_wetness(p) > 0.05 and Game.step_sound(p) != "step_water" else ""]
			cnt[key] = int(cnt.get(key, 0)) + 1
			if not ex.has(key):
				ex[key] = "h=%.1f arazi=%.1f su=%.1f" % [dy, th, wl]
	for key in cnt:
		print("ROOFSTEP ", key, " : ", cnt[key], "  (", ex[key], ")")
	print("ROOFSTEP sulu nokta=", wn, " hava=", Game.world.env.weather, " ", Game.world.env.overcast)
	print("ROOFSTEP kiremit varyant=", Sfx.variants.get("step_tile", []).size(), " tahta varyant=", Sfx.variants.get("step_wood", []).size())
	get_tree().quit()
