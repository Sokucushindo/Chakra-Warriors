extends Node
## Göz nakli: her dōjutsu kavanozda görünür, kanon şartı tutmayanın nedeni yazılır, uygun olanlar gerçek ameliyat olayıyla takılır.
## --shots=<dir> ile menü görüntüleri
var main: Node
const ALL := ["goz_sharingan", "goz_mangekyo", "goz_ems", "goz_byakugan", "goz_ketsuryugan", "goz_rinnegan", "goz_tenseigan", "goz_jogan"]


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _jar(pr: Dictionary) -> Dictionary:
	var out := {}
	for g in pr["gear"]:
		if Gear.is_eye(g["id"]) and not Gear.is_equipped(pr, g):
			out[String(g["id"])] = int(g["uid"])
	return out


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(2.5)
	Hud.close_dialog()
	var pr = Game.profile
	pr["ryo"] = 99999
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != main.player and Combat.hostile(main.player, f):
			f.queue_free()
	for gid in ALL:
		Gear.grant(pr, gid, "", null, null, {"lvl": 3, "origin": "nakil"})
	# kanon tablosu (oyuncu ve NPC aynı işlev)
	for c in [["none", false], ["uzumaki", false], ["hyuga", false], ["none", true], ["otsutsuki", false]]:
		var row = []
		for k in [1, 2, 3, 4, 5, 6, 7, 8]:
			row.append("%d:%s" % [k, "ok" if EyeSurgery.canon_block(k, c[0], c[1]) == "" else "X"])
		print("CANON clan=%s senju=%s  %s" % [c[0], c[1], " ".join(row)])
	var labels = EyeSurgery.options("black").map(func(o): return o["label"])
	print("OPTIONS black n=%d" % labels.size())
	for l in labels:
		print("  OPT ", l)
	# menü: Gözler sekmesi
	Menus.ninja_menu(main, "eyes")
	await _w(0.8)
	await main.shot("eyes_tab")
	Menus.clear()
	# kanonca takılamayan göz: neden
	var jar = _jar(pr)
	EyeSurgery.menu_offer(jar["goz_rinnegan"], "sag_goz")
	await _w(2.5)
	print("BLOCK rinnegan: ", Hud.last_dialog.replace("\n", " | "))
	await main.shot("offer_rinnegan_blocked")
	Hud.close_dialog()
	# takılabilir göz, kimse yok
	EyeSurgery.menu_offer(jar["goz_byakugan"], "sag_goz")
	await _w(2.5)
	print("OFFER byakugan (no surgeon) opts=%d text=%s" % [Hud.last_options.size(), Hud.last_dialog.replace("\n", " | ")])
	await main.shot("offer_byakugan_nosurgeon")
	Hud.close_dialog()
	# kendi tıbbi ninjutsun
	if not "shousen" in pr["learned"]:
		pr["learned"].append("shousen")
	if not pr.has("mastery"):
		pr["mastery"] = {}
	pr["mastery"]["iryo"] = 100.0
	EyeSurgery.menu_offer(jar["goz_sharingan"], "sol_goz")
	await _w(2.5)
	print("OFFER sharingan (self) opts=%s" % [Hud.last_options.map(func(o): return o["label"])])
	await main.shot("offer_sharingan_self")
	Hud.close_dialog()
	# Kara Cerrah yolu: göz -> yuva iki adım
	Hud.dialog("Kara Cerrah", "test", EyeSurgery.options("black"))
	await _w(1.0)
	await main.shot("black_surgeon_list")
	Hud.close_dialog()
	EyeSurgery.choose_slot(jar["goz_mangekyo"], "black")
	await _w(2.5)
	print("CHOOSE mangekyo: opts=%s" % [Hud.last_options.map(func(o): return o["label"])])
	await main.shot("black_choose_slot")
	Hud.close_dialog()
	# gerçek ameliyatlar: her göz sırayla sağ göze (Kara Cerrah, %97); şartı olanlar için beden değişir
	var plan = [["goz_sharingan", "none", false], ["goz_mangekyo", "none", false], ["goz_ems", "none", false], ["goz_byakugan", "none", false],
		["goz_ketsuryugan", "none", false], ["goz_rinnegan", "none", false], ["goz_rinnegan", "uzumaki", false], ["goz_tenseigan", "hyuga", false],
		["goz_jogan", "otsutsuki", false]]
	for st in plan:
		pr["clan"] = st[1]
		jar = _jar(pr)
		if not jar.has(st[0]):
			Gear.grant(pr, st[0], "", null, null, {"lvl": 3, "origin": "nakil"})
			jar = _jar(pr)
		var uid = int(jar[st[0]])
		var why = EyeSurgery.block_reason(pr, Gear.find(pr, uid))
		if why != "":
			print("SURGERY %s clan=%s BLOCKED: %s" % [st[0], st[1], why])
			continue
		main.player.hp = main.player.max_hp
		EyeSurgery.operate(uid, "sag_goz", "self")   # Kara Cerrah artık %35: deterministik olsun diye usta tıbbi ninja (%90)
		await _w(EyeSurgery.OP_TIME + 1.0)
		var eq = Gear.equipped(pr, "sag_goz")
		print("SURGERY %s clan=%s -> sag_goz=%s origin=%s look=%s" % [st[0], st[1], eq.get("id", "-"), eq.get("origin", "-"), pr.get("look", {}).get("eye_r")])
		Hud.close_dialog()
	await main.shot("after_surgery")
	# EMS kanonu: kendi MS + yabancı MS = MS; kendi MS + kan akrabası MS = EMS
	pr["clan"] = "uchiha"
	for kin in [false, true]:
		Gear.grant(pr, "goz_mangekyo", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
		var d = Gear.grant(pr, "goz_mangekyo", "", null, null, {"lvl": 3, "origin": "nakil", "kin": kin})
		var duid = int(d)
		print("EMS note kin=%s: %s" % [kin, EyeSurgery.notes(pr, Gear.find(pr, duid), "sol_goz")])
		Eyes.transplant(pr, duid, "sol_goz")
		print("EMS kin=%s -> sol_goz=%s" % [kin, Gear.equipped(pr, "sol_goz").get("id")])
	Menus.ninja_menu(main, "eyes")
	await _w(0.8)
	await main.shot("eyes_tab_after")
	print("DONE")
	get_tree().quit()
