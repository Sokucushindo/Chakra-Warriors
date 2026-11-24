extends Node
## Jutsu çekim testi: IDS="a,b,c" teknikleri sırayla 9 m'deki hedefe atar; her biri için yan ve arka kameradan 3 anda kare.
## Kareler: SHOTS klasörüne fx_<id>_<an>_<kamera>.png. Hata satırları: "FXT HATA". Sonuç: "FXT <id> hasar".
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12),
		"bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	var avg = 100.0 * pow(60.0 / 100.0, 1.0 / 0.7)
	Game.profile["mastery"] = {}
	for k in Mastery.KEYS:
		Game.profile["mastery"][k] = avg
	Mastery.refresh_level(Game.profile)
	pl.max_chakra = 99999.0
	pl.max_hp = 99999.0
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 700.0), 80.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	var cam = Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	if OS.get_environment("AMA") != "":
		Engine.set_meta("ama_style", OS.get_environment("AMA"))
	if OS.get_environment("SUS") != "":   # Susanoo teknikleri: EMS + Susanoo açık
		var prs = Game.profile
		Gear.grant(prs, "goz_ems", "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
		Gear.grant(prs, "goz_ems", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
		Gear.apply_look(prs)
		pl.rebuild_model()
		pl.chakra = 9999999
		pl.max_chakra = 9999999
		Susanoo.config(prs)["mastery"] = 99999.0
		Susanoo.config(prs).merge({"tier_pref": 4}, true)
		await get_tree().create_timer(0.5).timeout
		pl.combat.modes.eyes.toggle()
		await get_tree().create_timer(0.4).timeout
		pl.combat.modes.eyes._start_susanoo()
		await get_tree().create_timer(2.0).timeout
	if OS.get_environment("WPN") != "":   # silaha özgü teknikler: silahı kuşan
		Gear.grant(Game.profile, OS.get_environment("WPN"), "sag")
		Gear.apply_look(Game.profile)
		pl.rebuild_model()
		await get_tree().create_timer(1.5).timeout
	for jid in OS.get_environment("IDS").split(",", false):
		if not Data.jutsu.has(jid):
			print("FXT HATA %s yok" % jid)
			continue
		Game.profile["learned"] = Game.profile.get("learned", []) + [jid]
		pl.respawn(at)
		pl.hp = pl.max_hp
		pl.chakra = pl.max_chakra
		pl.facing = 0.0
		pl.yaw = 0.0
		var a = WorldPeople.arch_of(cands[0])
		a["respawn"] = false
		a["jutsu"] = []
		var e = Enemy.new()
		e.setup(a)
		get_tree().current_scene.add_child(e)
		e.global_position = at + Vector3(0, 0, -9.0)
		e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.1
		e.home = e.global_position
		await get_tree().create_timer(0.4).timeout
		e.max_hp = 999999.0; e.hp = 999999.0
		e.skill = 0.0
		e.attack_cd = 999.0
		e.target = null
		pl.combat.lock_target = e
		pl.combat.cooldowns.clear()
		var mid = (pl.global_position + e.global_position) * 0.5 + Vector3.UP * 1.2
		var hp0 = e.hp
		if OS.get_environment("CHAIN") != "":   # önce şart tekniği (ör. Jūroku Chūshibari → Suyaki fırını)
			Jutsu.execute(pl, OS.get_environment("CHAIN"), e)
			await get_tree().create_timer(0.5).timeout
		if OS.get_environment("FORCE") != "":
			Jutsu.execute(pl, jid, e)   # kanon şartını atla (görsel denetimi)
		else:
			pl.combat.begin_cast(jid)
		var t0 = Time.get_ticks_msec()
		var times = Array(OS.get_environment("TIMES").split(",", false)).map(func(x): return float(x)) if OS.get_environment("TIMES") != "" else [0.5, 1.2, 2.2]
		mid += Vector3.UP * float(OS.get_environment("LOOKUP")) if OS.get_environment("LOOKUP") != "" else Vector3.ZERO
		for an in times:
			while (Time.get_ticks_msec() - t0) / 1000.0 < an:
				await get_tree().process_frame
			var cams = [["yan", mid + Vector3(8, 2.5, 1.5) * (3.0 if OS.get_environment("LOOKUP") != "" else 1.0)], ["arka", pl.global_position + Vector3(1.0, 2.6, 5.0)]]
			if OS.get_environment("CAMOFF") != "":   # geniş kamera (Susanoo vb.): oyuncuya göre konum
				var co = OS.get_environment("CAMOFF").split(",")
				cams[0] = ["yan", pl.global_position + Vector3(float(co[0]), float(co[1]), float(co[2]))]
			for cv in cams:
				cam.global_position = cv[1]
				cam.look_at(mid, Vector3.UP)
				cam.current = true
				await RenderingServer.frame_post_draw
				await main.shot("fx_%s_%s_%s" % [jid, ["05", "12", "22"][times.find(an)], cv[0]])
			cam.current = false
			pl.cam.current = true
		await get_tree().create_timer(1.5).timeout
		print("FXT %s hasar %.0f" % [jid, hp0 - e.hp])
		e.queue_free()
		await get_tree().create_timer(1.0).timeout
	print("FXT BITTI")
	get_tree().quit()
