extends Node
## Ayarlar ekranı: her sekmenin ve Kontroller ekranının görüntüsü (mühürler + bölüm düzeni)
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "top2": Color(0.12, 0.12, 0.14), "pants": Color(0.15, 0.15, 0.17), "top_style": "ceket", "pants_style": "ninja", "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	main._pause()
	for t in ["general", "graphics", "sound", "controls"]:
		Menus._set_tab = t
		Menus.settings(func(): Menus.pause(main))
		await get_tree().create_timer(0.8).timeout
		await main.shot("s_" + t)
	Menus.controls(func(): Menus.pause(main))
	await get_tree().create_timer(0.8).timeout
	await main.shot("s_tuslar")
	get_tree().quit()
