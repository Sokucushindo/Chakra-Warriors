extends Node
## Köyünde dövüşürken köy ninjaları yardıma geliyor mu (kaçak değilken). Satırlar "VA".
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(10.0).timeout
	Hud.close_dialog()
	var best = null; var bn = 0
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and Friends.is_ninja(v):
			var n = 0
			for w in get_tree().get_nodes_in_group("talkers"):
				if w is Villager and Friends.is_ninja(w) and w.global_position.distance_to(v.global_position) < 45.0:
					n += 1
			if n > bn:
				bn = n; best = v
	if best == null:
		print("VA koy ninjasi yok"); get_tree().quit(); return
	var pp: Vector3 = best.global_position + Vector3(5, 0, 5)
	main.player.global_position = pp + Vector3.UP
	await get_tree().create_timer(1.0).timeout
	var a = Enemy.archetype("bandit", 0)
	var e = Enemy.new()
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = pp + Vector3(6, 1, 0)
	e.team = "enemy"
	e.target = main.player
	print("VA haydut taraf=%s, yakindaki koy ninjasi=%d" % [e.get_meta("faction", ""), bn])
	for k in 5:
		await get_tree().create_timer(1.0).timeout
		var allies = (Kage.assist.get("allies", []) as Array).filter(func(d): return is_instance_valid(d) and not d.is_dead())
		var tgt = allies.filter(func(d): return d.target == e).size()
		print("VA %d sn: yardima gelen %d, haydudu hedefleyen %d, haydut can %.0f" % [k + 1, allies.size(), tgt, e.hp if is_instance_valid(e) else -1.0])
	if is_instance_valid(e):
		e.queue_free()
	await get_tree().create_timer(8.0).timeout
	print("VA dovus bitti: yardim kaydi bos=%s" % Kage.assist.is_empty())
	get_tree().quit()
