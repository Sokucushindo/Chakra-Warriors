extends Node
## Gōkakyū / Hōsenka neden atılmıyor: oyuncunun atış durumu kare kare
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	var pl = main.player
	Game.profile["level"] = 40
	pl.apply_profile_stats()
	pl.max_chakra = 99999.0
	pl.chakra = 99999.0
	var en = Enemy.new()
	var a = Enemy.archetype("genin_rival", 0)
	a["jutsu"] = []
	en.setup(a)
	get_tree().current_scene.add_child(en)
	en.global_position = Missions.open_ground(pl.global_position + pl.face_dir() * 9.0, 3.0)
	await get_tree().create_timer(1.0).timeout
	for id in ["katon_goukakyuu", "katon_housenka"]:
		en.set_physics_process(false)
		pl.combat.lock_target = en
		pl.combat.face_to(en)
		pl.combat.begin_cast(id)
		await get_tree().process_frame
		if String(pl.combat.action) == "":
			Jutsu.execute(pl, id, en)
			print("  fallback execute")
		print("CAST %s action=%s learned=%s" % [id, str(pl.combat.action), str(id in Game.profile.get("learned", []))])
		for k in 12:
			await get_tree().create_timer(0.25).timeout
			var pr = []
			for n in get_tree().get_nodes_in_group("projectiles"):
				if n is Node3D:
					pr.append((n.global_position - pl.global_position).round())
			print("  t=%.2f action=%s hp=%.0f to_enemy=%s proj=%s" % [k * 0.25, str(pl.combat.action), en.hp, str((en.global_position - pl.global_position).round()), str(pr)])
		en.set_physics_process(true)
	get_tree().quit()
