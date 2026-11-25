extends Node
## Ön Lotus çekimi: oyuncu → düşman, sonra düşman → oyuncu (AI eşitliği). Zaman dondurularak (time_scale 0) her anda iki açıdan kare.
## Kareler: SHOTS klasörüne om_<kim>_<an>_<kamera>.png; "OMT" satırları: yükseklik / hasar ölçümleri.
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.45, 0.2),
		"bottom": Color(0.2, 0.45, 0.2), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	pl.max_chakra = 99999.0
	pl.max_hp = 99999.0
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 700.0), 80.0)
	# üstü açık yer: 16 m yukarıya ve yanlara ağaç / çatı olmasın (hedef ~10 m fırlar)
	var space = get_viewport().world_3d.direct_space_state
	var best = at
	for k in 400:
		var q = at + Vector3(randf_range(-120, 120), 0, randf_range(-120, 120))
		q.y = Game.ground_height(q.x, q.z)
		var clear = true
		for o in [Vector3.ZERO, Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4), Vector3(7, 0, 3), Vector3(-7, 0, -3)]:
			var rq = PhysicsRayQueryParameters3D.create(q + o + Vector3.UP * 0.6, q + o + Vector3.UP * 16.0)
			if not space.intersect_ray(rq).is_empty():
				clear = false
				break
		if clear:
			best = q
			break
	at = best
	at.y = Game.ground_height(at.x, at.z) + 0.3
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	var cam = Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	# test görüntüsü: ağaç / ot örnekleri (MultiMesh) gizlenir, gövdeler ve sonradan doğan efektler görünür kalır
	for mm in get_tree().current_scene.find_children("*", "MultiMeshInstance3D", true, false):
		(mm as Node3D).visible = false
	var times = [0.1, 0.55, 0.95, 1.2, 1.45, 1.65, 2.0, 2.3, 2.45, 3.0]
	for who in ["pl", "ai"]:
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
		e.global_position = at + Vector3(0, 0, -3.0)
		e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.1
		e.home = e.global_position
		await get_tree().create_timer(0.5).timeout
		e.max_hp = 999999.0; e.hp = 999999.0
		e.skill = 0.0
		e.attack_cd = 999.0
		e.target = null
		pl.combat.lock_target = e
		pl.combat.cooldowns.clear()
		var caster = pl if who == "pl" else e
		var victim = e if who == "pl" else pl
		var g0 = victim.global_position.y
		var dir = (victim.global_position - caster.global_position)
		dir.y = 0.0
		dir = dir.normalized()
		var side = dir.cross(Vector3.UP).normalized()
		var hp0 = victim.hp
		Jutsu.execute(caster, "omote_renge", victim)
		var top = -999.0
		await get_tree().process_frame
		var tk = get_tree().current_scene.find_child("OmoteRenge", true, false)
		if tk == null:
			print("OMT HATA teknik başlamadı")
		for an in times:
			while tk != null and is_instance_valid(tk) and float(tk.age) < an:
				top = maxf(top, victim.global_position.y - g0)
				await get_tree().process_frame
			Engine.time_scale = 0.0
			var md = victim.get("model")
			var mid = victim.global_position + Vector3.UP * 1.0
			if md and md.skel and md.skel.find_bone("Hips") >= 0:
				mid = (md.skel.global_transform * md.skel.get_bone_global_pose(md.skel.find_bone("Hips"))).origin
			print("OMT %s t=%.2f hedef_y=%.2f atan_y=%.2f hedef_rotx=%.2f" % [who, an, victim.global_position.y - g0, caster.global_position.y - g0, md.rotation.x if md else 0.0])
			var low = mid - dir * 3.2 + side * 2.2 + Vector3.UP * -2.2
			low.y = maxf(low.y, Game.ground_height(low.x, low.z) + 0.4)
			var cams = [["yan", mid + side * 4.6 + Vector3.UP * 0.4], ["alt", low]]
			for cv in cams:
				cam.global_position = cv[1]
				cam.look_at(mid, Vector3.UP)
				cam.current = true
				await RenderingServer.frame_post_draw
				await main.shot("om_%s_%02d_%s" % [who, int(an * 10.0), cv[0]])
			cam.current = false
			pl.cam.current = true
			Engine.time_scale = 1.0
		await get_tree().create_timer(1.0).timeout
		print("OMT %s tepe=%.2f hasar=%.0f" % [who, top, hp0 - victim.hp])
		e.queue_free()
		await get_tree().create_timer(0.5).timeout
	print("OMT BITTI")
	get_tree().quit()
