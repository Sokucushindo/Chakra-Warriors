extends Node
## Köyde iş yapanlar (VillagerJobs) denetimi: Konoha'nın iş yerlerine (tarla, hastane, ANBU, polis, akademi, Kage meydanı,
## Hyūga dōjō'su, dükkân önü, nehir kıyısı) gündüz ve gece ışınlanır, yakındaki rol / iş sayılarını yazar, görüntü alır,
## en kalabalık yerde FPS ölçer. Kullanım: --test=res://tests/dbg_village_jobs.gd --shots="D:/.../_tmp/jobs"
## JOBS_ONLY="hospital,anbu" yalnız bu yerler; JOBS_NIGHT=0 gece turu yok.
var main: Node
const VL = preload("res://scripts/world/village_life.gd")


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	print("JOBS quiet=", Missions.quiet())
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	var list: Array = VL.sites.get("konoha", [])
	var cnt := {}
	for s in list:
		cnt[String(s["type"])] = int(cnt.get(String(s["type"]), 0)) + 1
	print("JOBS sites ", cnt)
	var only = Array(OS.get_environment("JOBS_ONLY").split(",", false))
	var picks: Array = []   # [ad, site]
	for ty in ["hospital", "anbu", "police", "drill", "messenger", "dojo", "farm", "sweep", "fish"]:
		if not only.is_empty() and not ty in only:
			continue
		var best = null
		var bd = 1e9
		for s in list:
			if String(s["type"]) != ty:
				continue
			if ty == "farm" and not WorldDay.vl._staffed(s):
				continue
			var d = (s["pos"] as Vector3).distance_to(c)
			if ty in ["drill", "messenger"]:
				d = d   # Konoha'nın kendi akademi / meydanı (en yakın)
			if d < bd:
				bd = d
				best = s
		if best != null:
			picks.append([ty, best])
	var night_types = ["hospital", "anbu", "police"]
	var busiest := ""
	var bn := -1
	for pass_i in [0, 1]:
		var night = pass_i == 1
		if night and OS.get_environment("JOBS_NIGHT") == "0":
			break
		main.world.env.time_of_day = 0.93 if night else 0.47
		for pk in picks:
			var ty: String = pk[0]
			if night and not ty in night_types:
				continue
			var s: Dictionary = pk[1]
			var sp: Vector3 = s["pos"]
			# oyuncu yerin 14 m güneyinde (görüş içinde), kamera yukarıdan
			var pp = sp + Vector3(6.0, 0, 14.0)
			main.player.respawn(Vector3(pp.x, Game.terrain_height(pp.x, pp.z) + 1.0, pp.z))
			main.player.visible = true
			await get_tree().create_timer(float(OS.get_environment("JOBS_WAIT")) if OS.get_environment("JOBS_WAIT") != "" else 18.0).timeout
			main.player.visible = false
			var roles := {}
			var total = 0
			for n in get_tree().get_nodes_in_group("talkers"):
				if n is Villager and not n.fading and n.global_position.distance_to(sp) < 45.0:
					var k = String(n.role) + (":" + String(n.job) if String(n.job) != "" else "")
					roles[k] = int(roles.get(k, 0)) + 1
					total += 1
			var allv = 0
			for n in get_tree().get_nodes_in_group("talkers"):
				if n is Villager and not n.fading and n.global_position.distance_to(main.player.global_position) < 150.0:
					allv += 1
			print("JOBS %s %s near=%d (150m=%d) %s" % ["gece" if night else "gunduz", ty, total, allv, roles])
			for k2 in 2:
				var off = [Vector3(9.0, 7.0, 16.0), Vector3(-12.0, 4.0, -8.0)][k2]
				var cp = sp + off
				cp.y = Game.terrain_height(cp.x, cp.z) + off.y
				cam.global_position = cp
				cam.look_at(sp + Vector3(0, 1.2, 0), Vector3.UP)
				cam.current = true
				await get_tree().create_timer(0.6).timeout
				await main.shot("%s_%s_%d" % ["n" if night else "d", ty, k2])
			# yakın çekim: en yakın işçi
			var near_n = null
			var nd = 1e9
			for n in get_tree().get_nodes_in_group("talkers"):
				if n is Villager and n.role == "job" and not n.fading:
					var d2 = n.global_position.distance_to(sp)
					if d2 < nd:
						nd = d2
						near_n = n
			if near_n != null and nd < 40.0:
				var f: float = near_n.facing
				var fd = Vector3(-sin(f), 0, -cos(f))
				var rt = fd.cross(Vector3.UP)
				cam.global_position = near_n.global_position + fd * 3.2 + rt * 1.6 + Vector3.UP * 1.9
				cam.look_at(near_n.global_position + Vector3.UP * 1.0, Vector3.UP)
				await get_tree().create_timer(0.6).timeout
				await main.shot("%s_%s_close" % ["n" if night else "d", ty])
				print("JOBS close %s job=%s anim=%s" % [ty, near_n.job, near_n.model.current])
			if not night and total > bn:
				bn = total
				busiest = ty
			cam.current = false
	# en kalabalık iş yerinde FPS (oyuncu kamerası, 2560x1380)
	for pk in picks:
		if pk[0] == busiest:
			main.world.env.time_of_day = 0.47
			var sp2: Vector3 = pk[1]["pos"]
			var pp2 = sp2 + Vector3(6.0, 0, 14.0)
			main.player.visible = true
			main.player.respawn(Vector3(pp2.x, Game.terrain_height(pp2.x, pp2.z) + 1.0, pp2.z))
			await get_tree().create_timer(10.0).timeout
			var fs: Array = []
			for k3 in 10:
				await get_tree().create_timer(1.0).timeout
				fs.append(Engine.get_frames_per_second())
			fs.sort()
			print("JOBS FPS at %s: min=%d med=%d max=%d" % [busiest, fs[0], fs[5], fs[9]])
	print("JOBS done")
	get_tree().quit()
