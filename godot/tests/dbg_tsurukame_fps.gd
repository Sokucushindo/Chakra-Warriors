extends Node
## Tsurukame kombosu FPS: her adımda (özellikle 6. bitiriş Renpatsu) kare süresi, mermi / düğüm sayısı
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "suiton", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.2, 0.3, 0.6), "pants": Color(0.15, 0.15, 0.2), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.25, 0.25)}
	main._start_new_game()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _w(3.0)
	Hud.close_dialog()
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(v["x"], v["y"] + float(v["r"]) + 500)))
	await _w(3.0)
	Game.profile["level"] = 40
	Gear.grant(Game.profile, "tsurukame", "sag")
	Game.profile["weapon_drawn"] = true
	Gear.apply_look(Game.profile)
	pl.rebuild_model()
	pl.model.set_drawn(true, false)
	await _w(3.0)
	var en = Enemy.new()
	var a = Enemy.archetype("genin_rival", 0)
	a["jutsu"] = []
	en.setup(a)
	get_tree().current_scene.add_child(en)
	en.global_position = Missions.open_ground(pl.global_position + pl.face_dir() * 5.0, 3.0)
	en.max_hp = 999999.0
	en.hp = 999999.0
	await _w(1.0)
	en.set_physics_process(false)
	pl.set_physics_process(false)
	var TK = load("res://scripts/combat/fx/tsurukame_fx.gd")
	print("TK fighters=%d" % get_tree().get_nodes_in_group("fighters").size())
	# saf CPU ölçümü: 60 iğne mermisinin bir fizik karesi (yarışan başka süreçlerden bağımsız karşılaştırma)
	var U = load("res://scripts/combat/fx/uzak_nisan.gd")
	var prs = []
	var c0 = pl.global_position + Vector3.UP * 1.15
	for j in 60:
		var ang = TAU * j / 60.0
		var pr = U.fire(pl, c0, Vector3(cos(ang), 0.3, sin(ang)) * 58.0, {"g": 0.0, "r": 0.1, "life": 99.0, "stick": true, "info": {"dmg": 1.0, "kind": "light"}})
		pr.set_physics_process(false)
		prs.append(pr)
	var tb = Time.get_ticks_usec()
	for it in 30:
		for pr in prs:
			pr.global_position = c0
			pr._physics_process(1.0 / 60.0)
	print("TK_BENCH 60 igne bir fizik karesi: %.2f ms" % ((Time.get_ticks_usec() - tb) / 30000.0))
	# parça parça: eski (alt adım başına grup + düşmanlık) / yeni (karede bir aday listesi) / ışın / arazi
	var from = c0
	var to = c0 + Vector3(1, 0.3, 0).normalized() * (58.0 / 60.0)
	print("TK ambient=%d" % get_tree().get_nodes_in_group("ambient_team").size())
	for rnd in 2:
		tb = Time.get_ticks_usec()
		for k in 60 * 10:
			for i in 4:
				var pt = from.lerp(to, float(i + 1) / 4)
				for f in get_tree().get_nodes_in_group("fighters"):
					if f == en or not Combat.hostile(pl, f) or f.is_dead():
						continue
					Combat.capsule_hit(pt, f, 0.1)
		var t_old = (Time.get_ticks_usec() - tb) / 10000.0
		tb = Time.get_ticks_usec()
		for k in 60 * 10:
			var cands = []
			for f in get_tree().get_nodes_in_group("fighters"):
				if not f.has_method("hit_test"):
					var fh = f.get("height")
					var fr = f.get("radius")
					if fh != null and fr != null and from.distance_to(f.global_position) > 1.07 + float(fh) + float(fr):
						continue
				if not Combat.hostile(pl, f) or f.is_dead():
					continue
				cands.append(f)
			for i in 4:
				var pt = from.lerp(to, float(i + 1) / 4)
				for f in cands:
					Combat.capsule_hit(pt, f, 0.1)
		var t_new = (Time.get_ticks_usec() - tb) / 10000.0
		tb = Time.get_ticks_usec()
		var space = pl.get_world_3d().direct_space_state
		for k in 60 * 10:
			space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			Game.terrain_height(to.x, to.z)
		var t_ray = (Time.get_ticks_usec() - tb) / 10000.0
		tb = Time.get_ticks_usec()
		for k in 60 * 10:
			for an in get_tree().get_nodes_in_group("ambient_team"):
				if is_instance_valid(an) and not an.dead and Combat.capsule_hit(to, an, 0.4):
					pass
		var t_amb = (Time.get_ticks_usec() - tb) / 10000.0
		print("TK_PARTS 60 igne/kare: savasci eski %.2f ms | yeni %.2f ms | isin+arazi %.2f ms | ambient %.2f ms" % [t_old, t_new, t_ray, t_amb])
	for pr in prs:
		pr.queue_free()
	if OS.get_environment("BENCH") == "1":
		get_tree().quit()
		return
	for rep in 3:
		for i in [0, 1, 2, 4, 5]:
			pl.combat.lock_target = en
			pl.combat.face_to(en)
			pl.set_meta("tk_ammo", 24)
			en.hp = en.max_hp
			var t0 = Time.get_ticks_usec()
			var last = t0
			var n = 0
			var worst = 0
			var phys = 0.0
			var physmax = 0.0
			var maxproj = 0
			TK.strike(pl, i, 30.0)
			while Time.get_ticks_usec() - t0 < 1500000:
				await get_tree().process_frame
				var now = Time.get_ticks_usec()
				worst = maxi(worst, now - last)
				last = now
				n += 1
				var ph = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
				phys += ph
				physmax = maxf(physmax, ph)
				maxproj = maxi(maxproj, get_tree().get_nodes_in_group("projectiles").size())
			print("TK rep=%d hit=%d avg %.0f FPS min %.0f FPS | fizik ort %.1f / en %.1f | proj %d" % [rep, i, n * 1000000.0 / (last - t0), 1000000.0 / maxf(1.0, worst), phys / n, physmax, maxproj])
			await _w(0.5)
	get_tree().quit()
