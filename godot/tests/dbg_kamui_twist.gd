extends Node
## Kamui kendi girişi: burgaca burkularak çekilme kareleri (yandan + arkadan)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "uchiha", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.15, 0.12, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 300.0), 40.0)
	at.y = Game.ground_height(at.x, at.z)
	pl.respawn(at)
	await get_tree().create_timer(1.0).timeout
	var cam = Camera3D.new()
	main.add_child(cam)
	var KS = load("res://scripts/world/kamui_space.gd")
	for side in [["yan", Vector3(3.2, 1.6, 0.0)], ["on", Vector3(0.0, 1.6, -3.2)]]:
		pl.global_position = at
		pl.model.visible = true
		cam.global_position = at + side[1]
		cam.look_at(at + Vector3.UP * 1.2)
		cam.current = true
		await get_tree().create_timer(0.5).timeout
		KS._shrink(pl, 0.45)
		KS.node()   # düğüm hazır
		load("res://scripts/combat/ms_arts.gd").kamui_vortex(KS.eye_point(pl), 1.6, 1.0)
		for k in 4:
			await get_tree().create_timer(0.1).timeout
			await main.shot("kt_%s_%d" % [side[0], k])
		await get_tree().create_timer(0.4).timeout
		KS._shrink(pl, 0.4, true)
		await get_tree().create_timer(0.2).timeout
		await main.shot("kt_%s_cikis" % side[0])
		await get_tree().create_timer(0.4).timeout
	get_tree().quit()
