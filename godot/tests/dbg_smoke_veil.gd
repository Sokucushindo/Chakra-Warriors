extends Node
## Duman bombası perdesi: kamera dumanın içindeyken perde açılır; duman bulutu erken silinse de perde kendiliğinden kalkmalı
var main: Node
const KemuridamaFX = preload("res://scripts/combat/fx/kemuridama_fx.gd")
const AletKit = preload("res://scripts/combat/fx/alet_kit.gd")


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _veil() -> String:
	var v = AletKit._c.get("scr:kemuri")
	return "yok" if v == null or not is_instance_valid(v) else ("ACIK" if v.visible else "kapali")


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.1), "top": Color(0.2, 0.3, 0.5), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	var pl = main.player
	var en = Enemy.new()
	en.setup(Enemy.archetype("genin_rival", 0))
	get_tree().current_scene.add_child(en)
	en.global_position = Missions.open_ground(pl.global_position + Vector3(6, 0, 0), 3.0)
	en.set_physics_process(false)
	await _w(0.5)
	KemuridamaFX.burst(en, pl.cam.global_position - Vector3.UP * 1.6)
	await _w(1.2)
	print("DUMAN ICINDE perde=", _veil())
	for c in get_tree().get_nodes_in_group(KemuridamaFX.GROUP):
		c.queue_free()   # duman erken silindi (eski hata: perde kalıyordu)
	await _w(1.5)
	print("DUMAN SILINDI perde=", _veil())
	KemuridamaFX.burst(en, pl.cam.global_position - Vector3.UP * 1.6)
	await _w(1.0)
	print("IKINCI DUMAN perde=", _veil())
	await _w(KemuridamaFX.LIFE + 1.5)
	print("SURE BITTI perde=", _veil())
	get_tree().quit()
