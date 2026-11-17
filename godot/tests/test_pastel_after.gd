extends Node
## Pastel görünüm karşılaştırması: aynı sahne, farklı ortam ayarı (oyun varsayılanları değişmez)
var main: Node

const SPOTS := [
	["konoha_ust", -60, -260, 0.0, -28.0, 40.0, 14.0],
	["konoha_sokak", -50, -200, 20.0, -10.0, 0.0, 9.0],
	["konoha_yan", 40, -120, 270.0, -14.0, 0.0, 12.0],
	]


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken",
		"hair": Color(0.3, 0.2, 0.12), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	Hud.show_game_hud(false)
	var pl = main.player
	var w = Game.world.env
	w.time_of_day = 0.42
	for s in SPOTS:
		var p = Game.from_map(Vector2(s[1], s[2]))
		p.y = Game.ground_height(p.x, p.z) + s[5]
		pl.respawn(p)
		pl.yaw = s[3]
		pl.pitch = s[4]
		pl.cam_dist = s[6]
		w.weather_t = 999
		await get_tree().create_timer(2.5).timeout
		await main.shot("sonra_%s" % s[0])
	get_tree().quit()
