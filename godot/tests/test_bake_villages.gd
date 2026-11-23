extends Node
## Dünyadaki BÜTÜN köyleri (world.json) sırayla kurdurup önbelleğe pişirir; build.py bunu çağırır ve sonucu pakete koyar
## (oyuncu hiçbir köyü oyun sırasında kurmaz: ilk yaklaşmada takılma olmaz).
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	for vd in Game.world_info["villages"]:
		var id = String(vd["id"])
		if id == "konoha":
			continue
		print("BV %s başlıyor" % id)
		await main.fast_travel(id)
		await get_tree().create_timer(4.0).timeout   # pişirme kaydı kurulumdan sonra
	print("BV bitti")
	get_tree().quit()
