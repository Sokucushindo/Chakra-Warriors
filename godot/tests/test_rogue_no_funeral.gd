extends Node
## Kaçakken dost ölürse: ulak çağırmaz, mezarlıkta tören başlamaz. Karşılaştırma: kaçak değilken çağırır.
var main: Node

func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	var pl = main.player
	for rogue in [false, true]:
		if rogue:
			Orgs._defect_apply()
			await _w(1.0)
			Hud.close_dialog()
		var id = Friends._make_friend("Test Dost %s" % str(rogue), "", {"gender": "m"}, 60, "Dost")
		Friends.all()[id]["village"] = "konoha"
		Friends.all()[id]["status"] = "öldü"
		await _w(2.5)
		var invited = Hud.dialog_open()
		Hud.close_dialog()
		pl.respawn(Graveyard.pos_of("konoha") + Vector3(0, 0.3, 6.0))
		await _w(6.0)
		print("CENAZE kacak=%s ulak=%s tören=%s" % [str(Orgs.is_rogue()), str(invited), str(not Friends.inst().funeral.is_empty())])
		if not Friends.inst().funeral.is_empty():
			Friends.inst()._end_funeral(Friends.inst().funeral["id"], "test")
		Hud.close_dialog()
		await _w(1.0)
	get_tree().quit()
