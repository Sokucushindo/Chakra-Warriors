extends Node
## Kaçak alarmı: köyde görülünce 60 m içindeki köy ninjaları (tanıdıklar dahil) saldırıya katılıyor mu; saldıranların tarafı
## köy mü (ANBU onları kaçak sanıp öldürmesin). Satırlar "RA".
var main: Node


func _count(pp: Vector3) -> Array:
	var idle = 0; var names = []
	for v in get_tree().get_nodes_in_group("talkers"):
		if is_instance_valid(v) and v.visible and (v is Villager or v is ClanResident) and Friends.is_ninja(v) and v.global_position.distance_to(pp) < 60.0:
			idle += 1
			names.append(String(v.get("display")))
	var foes = 0; var fac = {}
	for e in get_tree().get_nodes_in_group("fighters"):
		if e is Enemy and not e.dead and e.global_position.distance_to(pp) < 80.0:
			foes += 1
			var f = String(e.get_meta("faction", ""))
			fac[f] = int(fac.get(f, 0)) + 1
	return [idle, foes, fac, names]


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(10.0).timeout
	Hud.close_dialog()
	# en çok köy ninjasının toplandığı yeri bul
	var best = null; var bn = 0
	for v in get_tree().get_nodes_in_group("talkers"):
		if (v is Villager or v is ClanResident) and Friends.is_ninja(v):
			var n = 0
			for w in get_tree().get_nodes_in_group("talkers"):
				if (w is Villager or w is ClanResident) and Friends.is_ninja(w) and w.global_position.distance_to(v.global_position) < 50.0:
					n += 1
			if n > bn:
				bn = n; best = v
	if best == null:
		print("RA koy ninjasi bulunamadi")
		get_tree().quit()
		return
	var pp: Vector3 = best.global_position + Vector3(4, 0, 4)
	main.player.global_position = pp + Vector3.UP
	await get_tree().create_timer(1.5).timeout
	# bir tanesiyle tanış (eskiden tanıdıklar saldırmıyordu)
	Friends._meet(best, "", true)
	print("RA tanistik: %s friend_id=%s" % [best.get("display"), best.get_meta("friend_id", "")])
	var c0 = _count(pp)
	print("RA once: izleyen ninja %d, dusman %d, isimler %s" % [c0[0], c0[1], str(c0[3])])
	Orgs.flags()["rogue"] = true
	Orgs.flags()["rogue_from"] = "konoha"
	print("RA kacak=%s" % Orgs.is_rogue())
	Orgs._raid = {"vid": "konoha", "wave": 0, "t": 2.0, "out_t": 0.0, "nodes": [], "kage": false}
	for k in 4:
		await get_tree().create_timer(1.0).timeout
		var c = _count(pp)
		print("RA %d sn: hala izleyen ninja %d, saldiran %d, taraflar %s, izleyenler %s" % [k + 1, c[0], c[1], str(c[2]), str(c[3])])
		for e in get_tree().get_nodes_in_group("fighters"):
			if e is Enemy and e.global_position.distance_to(pp) < 400.0:
				print("RA    %s hp=%.0f olu=%s taraf=%s uzak=%.0f hedef=%s" % [e.display_name, e.hp, e.dead, e.get_meta("faction", ""), e.global_position.distance_to(pp), str(e.target.name) if e.target and is_instance_valid(e.target) else "-"])
	get_tree().quit()
