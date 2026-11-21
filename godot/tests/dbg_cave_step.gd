extends Node
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	await get_tree().create_timer(4.0).timeout
	print("CAVE varyant=", (Sfx.variants.get("step_cave", []) as Array).size())
	var p = main.player.global_position
	Interiors.inst.enter({"pos": p, "out": p + Vector3(0, 0, 3), "room": "rogue_hideout", "kind": "enter"})
	await get_tree().create_timer(3.0).timeout
	print("CAVE icerde=", Interiors.inst.inside, " ses=", Game.step_sound(main.player.global_position))
	for k in 6:
		Game.play_step(main.player.global_position, 1.0, 0.5)
		await get_tree().create_timer(0.3).timeout
	print("CAVE bitti")
	get_tree().quit()
