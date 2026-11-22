extends Node
## Shorts RPG bölümü (yatay 1600x900 film kaydı; dikey videoya ffmpeg ile yerleşir). Her ekran "CUT <ad> a/b <kare>".
var main: Node


func _cut(n: String, e: String) -> void:
	print("CUT %s %s %d" % [n, e, Engine.get_frames_drawn()])


func _show(n: String, dur: float) -> void:
	await get_tree().create_timer(0.5).timeout   # ekran otursun
	_cut(n, "a")
	await get_tree().create_timer(dur).timeout
	_cut(n, "b")


func _ready() -> void:
	await get_tree().process_frame
	Lang.apply("en")
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "top2": Color(0.12, 0.12, 0.14), "pants": Color(0.15, 0.15, 0.17), "top_style": "ceket", "pants_style": "ninja", "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	main.world.env.time_of_day = 0.45
	var pr = Game.profile
	pr["rank"] = 3
	pr["level"] = 60
	pr["ryo"] = 12400
	for id in ["katana", "tanto", "kunai", "nodachi", "set_jonin", "set_anbu"]:
		if Gear.ITEMS.has(id):
			Gear.grant(pr, id)
	Gear.grant(pr, "goz_ems", "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "goz_ems", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "set_jonin", "set")
	Gear.apply_look(pr)
	var ids = Data.jutsu.keys()
	pr["learned"] = ids.slice(0, mini(60, ids.size()))
	for i in 6:
		pr["slots"][i] = pr["learned"][i]
	main.player.rebuild_model()
	await get_tree().create_timer(6.0).timeout   # dünya ve köylüler otursun (ilişkiler, görevler dolsun)
	main._pause()
	for t in [["jutsu", 2.4], ["skills", 2.2], ["wardrobe", 2.4], ["relations", 2.2], ["paths", 2.2], ["beasts", 2.0]]:
		Menus.ninja_menu(main, t[0])
		await _show(t[0], t[1])
	main.resume()
	await get_tree().create_timer(0.3).timeout
	Hud.show_mission_board("konoha")
	await _show("board", 2.2)
	Hud.close_dialog()
	Menus.bingo_book(main)
	await _show("bingo", 2.2)
	Hud.close_dialog()
	main._pause()
	Menus.world_map(main)
	await _show("map", 2.4)
	main.resume()
	main.to_main_menu()
	await get_tree().create_timer(1.5).timeout
	main.start_creator(3)
	await get_tree().create_timer(1.0).timeout
	await _show("creator", 2.6)
	get_tree().quit()
