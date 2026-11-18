extends Node
## Mürekkep dili: sol üst oyuncu çerçevesi + jutsu çubuğu (tam / yarım can) ve karakter yaratma panelinin üç sekmesi
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "top2": Color(0.12, 0.12, 0.14), "pants": Color(0.15, 0.15, 0.17), "top_style": "ceket", "pants_style": "ninja", "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	main.world.env.time_of_day = 0.45
	var pr = Game.profile
	pr["rank"] = 3
	var ids = Data.jutsu.keys()
	pr["learned"] = ids.slice(0, mini(12, ids.size()))
	for i in 6:
		pr["slots"][i] = pr["learned"][i]
	await get_tree().create_timer(3.0).timeout
	await main.shot("h_tam")
	main.player.hp = main.player.max_hp * 0.4
	main.player.chakra = main.player.max_chakra * 0.6
	await get_tree().create_timer(1.5).timeout
	await main.shot("h_yarim")
	main.to_main_menu()
	await get_tree().create_timer(1.0).timeout
	for t in ["kimlik", "gorunum", "kiyafet"]:
		Menus._ctab = t
		main.start_creator(3)
		await get_tree().create_timer(1.2).timeout
		await main.shot("c_" + t)
	get_tree().quit()
