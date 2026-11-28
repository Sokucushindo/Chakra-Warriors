extends Node
## Kaçak ninja: köydeki köylüye konuşmadan vurup öldürebiliyor mu (köyüne bağlıyken vuruş hâlâ içinden geçmeli)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _near(pl) -> Node:
	var best = null
	var bd := 1e9
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and v.visible and not v.interior and v.display_override == "" and not v.is_queued_for_deletion() and v.look.get("age", "adult") == "adult":
			var d = v.global_position.distance_to(pl.global_position)
			if d < bd:
				bd = d
				best = v
	return best
func _strike(pl, v) -> Array:
	var at: Vector3 = v.global_position
	var nm = String(v.display)
	pl.respawn(at + Vector3(0, 0.2, 1.2))
	await _w(0.4)
	var n0 = get_tree().get_nodes_in_group("fighters").size()
	Combat.hit_sphere(pl, at + Vector3.UP * 0.9, 1.5, {"dmg": 40.0, "attacker": pl})
	await _w(0.5)
	var e = null
	var vic: Array = Crime.inst().victims
	if not is_instance_valid(v) or v.is_queued_for_deletion():
		e = vic[vic.size() - 1]["node"] if not vic.is_empty() else null
	return [nm, e, n0]
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pl = main.player
	await _w(6.0)
	var v = _near(pl)
	print("ROGK en yakın köylü ", v.display if v else "YOK", " rol=", v.role if v else "")
	var r = await _strike(pl, v)
	print("ROGK bağlıyken vuruş: düşmana döndü mü=", r[1] != null, " (beklenen false) aranma=", Crime.heat())
	Orgs.flags()["rogue"] = true
	# gerçek yumruk: kaçakken başka bir köylünün yanında düz saldırı tuşu
	v = _near(pl)
	if v:
		var nm = String(v.display)
		var at: Vector3 = v.global_position
		pl.respawn(at + Vector3(0, 0.2, 1.0))
		await _w(0.4)
		pl.facing = atan2((at - pl.global_position).x, (at - pl.global_position).z)
		for i in 6:
			pl.combat.attack()
			await _w(0.5)
		var vic2: Array = Crime.inst().victims
		var gone = not is_instance_valid(v) or v.is_queued_for_deletion()
		var e2 = vic2[vic2.size() - 1]["node"] if gone and not vic2.is_empty() else null
		print("ROGK gerçek yumrukla: ", nm, " savaşçıya döndü mü=", gone, " can=", (str(snappedf(e2.hp, 1)) + "/" + str(snappedf(e2.max_hp, 1))) if e2 != null and is_instance_valid(e2) else "-", " oyuncu-köylü mesafe=", snappedf(pl.global_position.distance_to(at), 0.01), " eylem=", pl.combat.action)
	get_tree().quit()
