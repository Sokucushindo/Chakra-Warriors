extends Node
## Hile ile Obito Mangekyō ver -> jutsu menüsünde "Kamui: içine çek" görünüyor mu
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "uchiha", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	var C = load("res://scripts/core/cheats.gd")
	var keys = Eyes.MS_STYLES.keys()
	for ei in [3, 4]:
		C.give_eye(ei, 2, keys.find("obito"))
		await get_tree().create_timer(0.5).timeout
		var pr = Game.profile
		var ids = SpecialSlots.refresh(pr)
		var names = []
		for id in ids:
			names.append("%s=%s" % [id, Data.jutsu.get(id, {}).get("name", "?")])
		print("KS göz=%d stiller=%s sag=%s özel=%s" % [ei, str(Eyes.ms_styles(pr)), str(Gear.equipped(pr, "sag_goz").get("ms_style", "")), str(names)])
	Menus.ninja_menu(main, "jutsu")
	await get_tree().create_timer(1.0).timeout
	await main.shot("kamui_jutsu_menu")
	get_tree().quit()
