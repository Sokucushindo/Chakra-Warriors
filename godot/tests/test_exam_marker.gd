extends Node
## Chūnin Sınavı 2. aşama: ok kuleyi gösteriyor mu (Konoha + Suna, takip otomatik / hikâye). Satırlar "EXM".
var main: Node


func _check(tag: String) -> void:
	var tw: Vector3 = ChuninExam.st["tower"]
	for k in 4:
		await get_tree().create_timer(0.5).timeout
		var d = Vector2(Missions.target_marker.x - tw.x, Missions.target_marker.z - tw.z).length()
		print("EXM %s ok=%s isim='%s' kuleye_uzaklik=%.0f m oyuncu-kule=%.0f m pusula=%s" % [tag, Missions.has_marker, Missions.target_name, d,
			Vector2(Game.player.global_position.x - tw.x, Game.player.global_position.z - tw.z).length(), Hud.compass.visible])


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.12), "top": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	for host in ["konoha", "suna"]:
		for tr in ["", "story"]:
			Game.profile["track"] = tr
			ChuninExam.host = host
			ChuninExam._forest()
			await get_tree().create_timer(1.0).timeout
			Hud.close_dialog()
			await _check("%s takip='%s'" % [host, tr])
			# parşömenler tamam: ok yine kulede mi
			Game.profile["inventory"]["scroll_heaven"] = 1
			Game.profile["inventory"]["scroll_earth"] = 1
			await _check("%s takip='%s' iki parsomen" % [host, tr])
			ChuninExam.stage = 0
			Game.profile.erase("active_mission")
			Exams._clear_nodes()
	var old_lang = Game.lang()
	Lang.apply("en")
	print("EXM harita harfi EN: cay=%s antrenman=%s hoca=%s gorev=%s" % [Interact.glyph("teahouse"), Interact.glyph("training"), Interact.glyph("trainer"), Interact.glyph("mission_board")])
	Lang.apply("tr")
	print("EXM harita harfi TR: cay=%s antrenman=%s" % [Interact.glyph("teahouse"), Interact.glyph("training")])
	Lang.apply(old_lang)
	get_tree().quit()
