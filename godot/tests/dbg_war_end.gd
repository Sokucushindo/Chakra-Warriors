extends Node
## Konoha–Oto savaşı: cephe Oto, sonuç (hakimiyet, tazminat, itibar), Oto nüfusu
var main: Node

func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Kaito Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.1, 0.1, 0.12), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	await main._start_new_game()
	await _w(1.0)
	var oto = func(): return WorldPeople.all().values().filter(func(p): return String(p["village"]) == "oto" and WorldPeople.alive(p)).size()
	print("WEND oto nufus=%d rep=%d" % [oto.call(), Missions.rep("konoha")])
	WorldRelations.declare_war("konoha", "oto")
	print("WEND cephe=%s" % String(WorldRelations.D()["war"][WorldRelations.key("konoha", "oto")]["front"]))
	for t in 30:
		WorldRelations.turn()
		for inc in WorldNews.D()["list"]:
			inc["left"] = 0.0
		WorldNews.tick(0.01)
		if not WorldRelations.at_war("konoha", "oto"):
			print("WEND tur %d bitti" % t)
			break
	print("WEND oto nufus=%d rep=%d hakimiyet=%s iliski=%d" % [oto.call(), Missions.rep("konoha"), str(WorldRelations.D()["sway"]), WorldRelations.rel("konoha", "oto")])
	for h in WorldRelations.recent():
		if "Otogakure" in String(h):
			print("WEND haber: " + String(h))
	get_tree().quit()
