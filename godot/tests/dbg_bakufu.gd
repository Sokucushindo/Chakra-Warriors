extends Node
## Bakufū Ranbu çekimi: hedef 24 m ileride; TIMES anlarında oyuncu kamerası + geniş yan + alçak (hedefin arkasından, animedeki çekim)
## + yukarıdan kare. Teknik boyunca FPS ölçülür ("BKR FPS"). Hasar: "BKR hasar".
var main: Node
var gt := 0.0


func _process(dt: float) -> void:
	gt += dt


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
	Game.world.env.time_of_day = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.42
	pl.max_chakra = 99999.0
	pl.max_hp = 99999.0
	var aoff = Vector3(0, 0, 700.0)
	if OS.get_environment("AT") != "":
		var ao = OS.get_environment("AT").split(",")
		aoff = Vector3(float(ao[0]), 0.0, float(ao[1]))
	var at = Missions.open_ground(pl.global_position + aoff, 80.0)
	print("BKR yer ", at)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	var cam = Camera3D.new()
	cam.fov = 55.0
	main.add_child(cam)
	var jid = "katon_bakufu_ranbu"
	if OS.get_environment("HIDEVEG") != "" and Game.world.vegetation:
		Game.world.vegetation.visible = false
	var reps = int(OS.get_environment("REPS")) if OS.get_environment("REPS") != "" else 1
	for rep in reps:
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
		e.global_position = at + Vector3(0, 0, -24.0)
		e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.1
		e.home = e.global_position
		await get_tree().create_timer(0.6).timeout
		e.max_hp = 999999.0; e.hp = 999999.0
		e.skill = 0.0
		e.attack_cd = 999.0
		e.target = null
		pl.combat.lock_target = e
		pl.combat.cooldowns.clear()
		await get_tree().create_timer(0.8).timeout
		var hp0 = e.hp
		var pp = pl.global_position
		var ep = e.global_position
		Jutsu.execute(pl, jid, e)
		var t0 = gt
		var fps: Array = []
		var times = Array(OS.get_environment("TIMES").split(",", false)).map(func(x): return float(x)) if OS.get_environment("TIMES") != "" else [0.6, 1.1, 1.6, 2.1, 3.0]
		var shots = OS.get_environment("NOSHOT") == ""
		if not shots:
			times = []
			while (gt - t0) < 5.0:
				await get_tree().process_frame
				fps.append(Engine.get_frames_per_second())
		for an in times:
			while (gt - t0) < an:
				await get_tree().process_frame
			print("BKR an %.2f gercek %.2f" % [an, (gt - t0)])
			var mid = (pp + ep) * 0.5
			var cams = [
				["oyuncu", null, null],
				["genis", pp + Vector3(-9, 8, 18), mid + Vector3(0, 6, 0)],
				["alcak", ep + Vector3(-2.0, 1.0, -7.0), pp + Vector3(0, 7.0, 0)],
				["ust", mid + Vector3(-6, 45, 14), mid + Vector3(0, 2, 0)]]
			for cv in cams:
				if cv[1] == null:
					pl.cam.current = true
				else:
					# ağaç / bina arkasında kalmasın: hedef noktadan kameraya ışın, engel varsa önüne çek
					var sp = Game.world.get_world_3d().direct_space_state
					var rq = PhysicsRayQueryParameters3D.create(cv[2], cv[1])
					var hr = sp.intersect_ray(rq)
					cam.global_position = (hr["position"] + (cv[2] - cv[1]).normalized() * 1.0) if not hr.is_empty() else cv[1]
					cam.look_at(cv[2], Vector3.UP)
					cam.current = true
				await RenderingServer.frame_post_draw
				await main.shot("bkr_%d_%s_%s" % [rep, str(an).replace(".", "_"), cv[0]])
			cam.current = false
			pl.cam.current = true
		await get_tree().create_timer(2.5).timeout
		if not fps.is_empty():
			var mn = 999.0
			var sm = 0.0
			for f in fps:
				mn = minf(mn, f)
				sm += f
			print("BKR FPS ort %.0f en dusuk %.0f" % [sm / fps.size(), mn])
		print("BKR hasar %.0f" % [hp0 - e.hp])
		e.queue_free()
		await get_tree().create_timer(1.0).timeout
	print("BKR BITTI")
	get_tree().quit()
