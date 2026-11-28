extends Node
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.2, 0.2, 0.3)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pr = Game.profile
	Gear.grant(pr, "goz_rinnegan", "sag_goz", null, null, {"lvl": 3, "origin": "nakil"})
	Gear.grant(pr, "goz_rinnegan", "sol_goz", null, null, {"lvl": 3, "origin": "nakil"})
	var SP = LazyFx.g("SixPaths")
	var d = SP.data()
	for i in 8:
		var a = Enemy.archetype(["kumo", "kiri", "iwa", "suna"][i % 4], i)
		d["seq"] = i + 1
		d["bodies"].append({"id": i + 1, "name": String(a["name"]) + " " + str(i), "level": 40 + i * 9, "arch": var_to_str(SP._clean(a))})
		if i < 5:
			d["slots"][SP.PATHS[i]] = i + 1
	await _w(7.0)
	Hud.close_dialog()
	Menus._eyes_paths = false
	Menus.ninja_menu(main, "eyes")
	await _w(1.0)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/spm_0.png")
	Menus._eyes_paths = true
	Menus.ninja_menu(main, "eyes")
	await _w(1.0)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/spm_1.png")
	SP.assign("jigokudo", 2)   # 2 numara shurado'daydı: oradan alınmalı
	print("SPM yuvalar=%s" % JSON.stringify(d["slots"]))
	SP.discard(1)
	print("SPM silince yuvalar=%s arsiv=%d" % [JSON.stringify(d["slots"]), d["bodies"].size()])
	get_tree().quit()
