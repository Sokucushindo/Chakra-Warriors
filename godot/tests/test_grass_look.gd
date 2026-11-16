extends Node
## Çimen + yeşil zemin görünümü: aynı yerden yakın / orta / alçak bakış, öğle ve akşamüstü (--tag=ad)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	var tag = "once"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.7, 0.35, 0.15), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var env = main.world.env
	env.region_weather = "açık"
	env.weather_t = 9999.0
	var pl = main.player
	var v = Game.village("konoha")
	var base = Game.from_map(Vector2(v["x"] + float(v["r"]) + 250, v["y"]))
	for r in range(0, 3000, 40):
		var q = base + Vector3(r, 0, 0)
		if Game.biome_at(q.x, q.z) == 7 and Game.road_at(q.x, q.z) < 0.1:
			base = q
			break
	pl.respawn(base)
	env.time_of_day = 0.4
	await _w(6.0)
	pl.visible = false
	var cc = Camera3D.new()
	get_tree().current_scene.add_child(cc)
	cc.current = true
	env.attach_post(cc)
	var p = pl.global_position
	var views = [["yakin", Vector3(0, 1.3, 0), Vector3(0.3, 0, 2.2)], ["orta", Vector3(0, 1.8, 0), Vector3(0, 0, 8.0)], ["alcak", Vector3(0, 0.6, 0), Vector3(-1.0, 0.2, 6.0)]]
	for tod in [[0.4, "ogle"], [0.7, "aksam"]]:
		env.time_of_day = tod[0]
		await _w(1.0)
		for vw in views:
			cc.global_position = p + vw[1]
			cc.look_at(p + vw[2])
			await _w(0.5)
			await main.shot("cim_%s_%s_%s" % [tag, tod[1], vw[0]])
	if tag.begins_with("zemin"):
		for g in get_tree().root.find_children("Grass", "", true, false):
			g.visible = false
			if g.get("mat"):
				g.mat.set_shader_parameter("radius", 0.01)
		print("ZEMIN grass nodes=", get_tree().root.find_children("Grass", "", true, false).size())
		env.time_of_day = 0.4
		for vw in [["z1", Vector3(0, 1.7, 0), Vector3(0, 0, 4.0)], ["z2", Vector3(0, 1.7, 0), Vector3(0, 0, 12.0)]]:
			cc.global_position = p + vw[1]
			cc.look_at(p + vw[2])
			await _w(0.5)
			await main.shot("cim_%s_%s" % [tag, vw[0]])
	get_tree().quit()
