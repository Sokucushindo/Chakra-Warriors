extends Node
## Sis Gizlenmesi ekran pusu: uzaktaki NPC atınca ekran boyanmamalı; yakında boyanıp sis bitince / çıkınca kalkmalı
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "suiton", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.1), "top": Color(0.2, 0.3, 0.5), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	var pl = main.player
	var en = Enemy.new()
	en.setup(Enemy.archetype("genin_rival", 0))
	get_tree().current_scene.add_child(en)
	en.global_position = Missions.open_ground(pl.global_position + Vector3(80, 0, 0), 4.0)
	en.set_physics_process(false)
	await _w(0.5)
	var env = Game.world.env
	SuitonFXA.kirigakure_no_jutsu(Jutsu, en, null)
	await _w(1.0)
	print("UZAK atis tint=", env.tint_target)
	en.global_position = Missions.open_ground(pl.global_position + Vector3(6, 0, 0), 3.0)
	SuitonFXA.kirigakure_no_jutsu(Jutsu, en, null)
	await _w(1.0)
	print("YAKIN atis tint=", env.tint_target)
	pl.global_position += Vector3(0, 0, 60)
	await _w(1.0)
	print("CIKTI tint=", env.tint_target)
	pl.global_position -= Vector3(0, 0, 60)
	await _w(1.0)
	print("GERI GIRDI tint=", env.tint_target)
	await _w(11.5)
	print("SIS BITTI tint=", env.tint_target)
	get_tree().quit()
