extends Node
## Beş doğa + doğa birleştirme: ninjutsu 40 / 75 / 110 / 150'de doğa seçimi açılır; iki doğada ustalaşınca ara doğa uyanır
## (teknik atarak, gerçek oyun akışıyla), ara doğanın teknikleri öğrenilebilir olur; NPC'ler de aynı yolu yürür.
var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3),
		"bottom": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	await get_tree().create_timer(2.5).timeout
	Hud.close_dialog()
	var pr: Dictionary = Game.profile
	var pl = main.player
	ok(Mastery.el_allowed(10.0) == 1 and Mastery.el_allowed(40.0) == 2 and Mastery.el_allowed(75.0) == 3 and Mastery.el_allowed(110.0) == 4 and Mastery.el_allowed(150.0) == 5, "doğa eşikleri 40 / 75 / 110 / 150")
	# her eşikte seçim penceresi açılıyor ve seçilen doğa ekleniyor
	if not pr.has("mastery"):
		pr["mastery"] = {}
	for step in [[39.6, "suiton"], [74.6, "fuuton"], [109.6, "doton"], [149.6, "raiton"]]:
		pr["mastery"]["ninjutsu"] = float(step[0])
		for i in 400:
			Mastery.gain(pr, "ninjutsu", 1.0)
			if int(Mastery.get_v(pr, "ninjutsu")) > int(step[0]):
				break
		await frames(4)
		var picked := false
		for b in Hud.dialog_layer.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and String(b.text).to_lower() == String(step[1]):
				b.pressed.emit()
				picked = true
				break
		await frames(4)
		Hud.close_dialog()
		ok(picked and String(step[1]) in pr["elements"], "ninjutsu %d: %s seçildi → doğalar %s" % [int(Mastery.get_v(pr, "ninjutsu")), step[1], str(pr["elements"])])
	ok((pr["elements"] as Array).size() == 5, "beş doğanın hepsi alındı")
	# doğa birleştirme: gerçek teknik atarak (Katon + Suiton → Futton)
	ok(not Progress.has_nature("futton"), "başta Futton yok")
	var katon_j := ""
	var suiton_j := ""
	for jid in pr["learned"]:
		var j: Dictionary = Data.jutsu.get(jid, {})
		if String(j.get("element", "")) == "katon" and katon_j == "":
			katon_j = jid
		if String(j.get("element", "")) == "suiton" and suiton_j == "":
			suiton_j = jid
	if katon_j == "":   # yeni karakterde Katon tekniği yoksa en basitini öğrenmiş say
		var best := 999
		for jid in Data.jutsu:
			var j = Data.jutsu[jid]
			if j is Dictionary and String(j.get("element", "")) == "katon" and String(j.get("clan", "")) == "" and not String(j.get("learn", "")).begins_with("kg:") and int(j.get("level", 1)) < best:
				best = int(j.get("level", 1))
				katon_j = jid
		pr["learned"].append(katon_j)
	print("  teknikler: %s, %s" % [katon_j, suiton_j])
	pl.max_chakra = 1e7
	pl.chakra = 1e7
	pl.combat.invuln = 999.0
	# bir gerçek atış: doğa ustalığı artıyor mu
	var v0 = Mastery.el_v(pr, "katon")
	pl.combat.cooldowns.clear()
	pl.combat.begin_cast(katon_j)
	await get_tree().create_timer(3.0).timeout
	ok(Mastery.el_v(pr, "katon") > v0, "Katon tekniği atınca Katon ustalığı arttı (%.3f → %.3f)" % [v0, Mastery.el_v(pr, "katon")])
	# kalanını hızlandır (aynı işlev, aynı miktar): iki doğa da eşiğe
	var n := 0
	while (Mastery.el_v(pr, "katon") < KgPaths.FUSE_AT or Mastery.el_v(pr, "suiton") < KgPaths.FUSE_AT) and n < 20000:
		Mastery.gain_el(pr, "katon", 0.5)
		Mastery.gain_el(pr, "suiton", 0.5)
		n += 1
	print("  eşiğe kadar ~%d teknik (doğa başına)" % n)
	await frames(10)
	ok(Progress.has_nature("futton"), "Katon + Suiton ustalaşınca Futton uyandı (doğalar: %s)" % str(pr.get("natures", [])))
	var kgj: Array = []
	for jid in Data.jutsu:
		var j = Data.jutsu[jid]
		if j is Dictionary and String(j.get("learn", "")) == "kg:futton":
			kgj.append(jid)
	var learnable := 0
	for jid in kgj:
		var why = Progress.can_learn(jid)
		if jid in pr["learned"] or not ("Kekkei genkai" in why or "doğası" in why):   # güç / rütbe şartı ayrı; kan soyu engeli kalkmış olmalı
			learnable += 1
		else:
			print("    %s: %s" % [jid, why])
	print("  Futton teknikleri: %d, öğrenilmiş / öğrenilebilir: %d" % [kgj.size(), learnable])
	ok(learnable > 0, "Futton teknikleri açıldı")
	# menü satırı
	var rows = KgPaths.fuse_rows(pr)
	print("  birleştirme satırları: %d (ör. %s)" % [rows.size(), str(rows[0]) if not rows.is_empty() else "-"])
	ok(rows.size() == KgPaths.RECIPES.size(), "beş doğayla bütün birleşimler listede")
	# NPC eşitliği: güçlü bir kişi büyüme turlarında yeni doğa / birleşim kazanıyor
	var strong: Array = WorldPeople.all().values().filter(func(p): return WorldPeople.alive(p))
	strong.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	var q: Dictionary = strong[0]
	q["level"] = 210
	var e0 = (q["els"] as Array).size()
	var nat0 = (q.get("nat", []) as Array).size()
	for i in 600:
		WorldPeople._life(q)
		if not WorldPeople.alive(q) or WorldPeople.is_rogue(q):
			break
	print("  NPC %s: doğa %d → %d, kan soyu / birleşim %d → %d" % [String(q["name"]), e0, (q["els"] as Array).size(), nat0, (q.get("nat", []) as Array).size()])
	print("SONUC: %d hata" % fails)
	get_tree().quit()
