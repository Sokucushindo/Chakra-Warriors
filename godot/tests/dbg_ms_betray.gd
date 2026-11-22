extends Node
## 70 yakınlıktaki dosta saldırıp (yakınlık -100) öldürünce Mangekyō uyanıyor mu (3 tomoe Sharingan, nakil)
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "s2", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.2), "village": "konoha"}
	main._start_new_game()
	await get_tree().create_timer(5.0).timeout
	var pr = Game.profile
	Gear.grant(pr, "goz_sharingan", "sag_goz", null, null, {"lvl": 3, "origin": "nakil", "xp": 0.0})
	Gear.apply_look(pr)
	var fs = Friends.all()
	fs["fT"] = {"name": "Deneme Dost", "bond": 70, "ninja": true, "status": "", "log": [], "village": "konoha", "rank": 1, "look": {}}
	# Crime.attack ile aynı düşüş
	Friends.keep_peak(fs["fT"])
	fs["fT"]["bond"] = -100
	print("MS yakinlik bond=%d peak=%d closeness=%d" % [fs["fT"]["bond"], fs["fT"].get("peak", -1), Friends.closeness("fT")])
	var e = Enemy.new()
	e.setup(Enemy.archetype("rogue", 0))
	get_tree().current_scene.add_child(e)
	e.global_position = main.player.global_position + Vector3(2, 0, 0)
	e.set_meta("slain_fid", "fT")
	await get_tree().create_timer(0.5).timeout
	e.hp = 1.0
	e.take_hit({"dmg": 99999.0, "attacker": main.player, "kind": "heavy", "dir": Vector3.RIGHT, "melee": true})
	await get_tree().create_timer(1.0).timeout
	print("MS sag_goz=%s durum=%s" % [Gear.equipped(pr, "sag_goz").get("id", "-"), fs["fT"].get("status", "")])
	get_tree().quit()
