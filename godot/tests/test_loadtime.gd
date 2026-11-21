extends Node
var main: Node


func _ready() -> void:
	print("LT motor+otomatik yüklemeler bitti: %d ms" % Time.get_ticks_msec())
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	var t0 = Time.get_ticks_msec()
	main._start_new_game()
	print("LT _start_new_game: %d ms" % (Time.get_ticks_msec() - t0))
	await get_tree().process_frame
	await get_tree().process_frame
	print("LT ilk kareler dahil: %d ms, toplam %d ms" % [Time.get_ticks_msec() - t0, Time.get_ticks_msec()])
	get_tree().quit()
