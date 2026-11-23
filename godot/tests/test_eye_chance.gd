extends Node
## Göz nakli tutma şansları: kendi naklin Iryō (tıbbi) ustalığına, takım tıp ninjasınınki onun gücüne bağlı.
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "T", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	var pr = Game.profile
	pr["learned"] = pr.get("learned", []) + ["shousen"]
	if not pr.has("mastery"):
		pr["mastery"] = {}
	for ch in [[100.0, 0.0], [100.0, 50.0], [0.0, 100.0]]:
		pr["mastery"]["chakra"] = ch[0]
		pr["mastery"]["iryo"] = ch[1]
		print("NAKIL chakra=%d iryo=%d -> yapabilir=%s sans=%%%d" % [int(ch[0]), int(ch[1]), str(EyeSurgery.can_self(pr)), int(round(EyeSurgery.self_chance(pr) * 100.0))])
	for lv in [8.0, 30.0, 60.0, 100.0]:
		print("TIP NINJASI guc=%d -> sans=%%%d" % [int(lv), int(round(EyeSurgery.medic_chance(lv) * 100.0))])
	get_tree().quit()
