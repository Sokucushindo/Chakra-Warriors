extends Node
## Chūnin Shorts arayüz ekranları (yatay 1600x900 film kaydı; dikey videoya ffmpeg ile yerleşir): yazılı sınav, eşleşme tablosu, jüri kararı.
var main: Node


func _cut(n: String, e: String) -> void:
	print("CUT %s %s %d" % [n, e, Engine.get_frames_drawn()])


func _show(n: String, dur: float) -> void:
	await get_tree().create_timer(0.6).timeout
	_cut(n, "a")
	await get_tree().create_timer(dur).timeout
	_cut(n, "b")


func _ready() -> void:
	await get_tree().process_frame
	Lang.apply("en")
	main.creator_state = {"slot": 3, "name": "Kaito", "gender": "m", "clan": "uchiha", "element": "katon", "village": "konoha", "hair_style": "dağınık", "hair": Color(0.08, 0.08, 0.1), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.1, 0.1, 0.1)}
	main._start_new_game()
	main.world.env.time_of_day = 0.45
	await get_tree().create_timer(5.0).timeout
	Hud.close_dialog()
	var pr = Game.profile
	pr["level"] = 40
	ChuninExam.host = "konoha"
	ChuninExam.st = {"written": 8, "forest_days": 3.2, "prelim_wins": 2, "final_wins": 2, "jutsu": {"raiton_chidori": 1, "katon_goukakyuu": 1, "katon_housenka": 1, "kawarimi": 1},
		"kawarimi": 3, "hp_lost": 0.4, "invasion": false, "mates_alive": 2, "final_i": 2}
	# 1) yazılı sınav kâğıdı
	var pool = ChuninExam.QUIZ.duplicate()
	ExamUI.written({"title": "Chūnin Selection Exam — Written", "subtitle": "Cheating is allowed... as long as you are not caught.", "questions": pool.slice(0, 9), "time": 180.0, "cheat": 2, "q10": true}, func(_r): pass)
	await _show("written", 2.4)
	ExamUI._resume()
	Hud.close_dialog()
	await get_tree().create_timer(0.4).timeout
	# 2) final eşleşmeleri
	var fld: Array = ChuninExam._build_field()
	ChuninExam.st["field"] = fld
	var n = func(t, i): return String(fld[t][i]["name"])
	ExamUI.bracket("Chūnin Final Tournament — Konohagakure", [[pr["name"], n.call(4, 0), ""], [n.call(5, 1), n.call(4, 1), ""], [n.call(6, 0), n.call(5, 2), ""]],
		"Judges: the Kage and the daimyō. Winning does not guarantee promotion; losing does not prevent it.", func(): pass)
	await _show("bracket", 2.2)
	ExamUI._resume()
	Hud.close_dialog()
	await get_tree().create_timer(0.4).timeout
	# 3) jüri kararı
	ChuninExam.st["finalists"] = []
	ChuninExam._judge()
	await _show("judge", 2.6)
	get_tree().quit()
