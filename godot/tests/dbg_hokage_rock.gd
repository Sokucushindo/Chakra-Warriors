extends Node
## Hokage Kayası yüzleri (HokageMonument) görüntü + çarpışma denetimi. Gündüz; çıktılar _tmp/hokage_rock/*.png
## Köy HokageMonument.build ile kurulduysa onu çeker; kurulmadıysa (build_konoha eski _hokage_faces'i çağırıyorsa) eski
## kabartmaları gizleyip yenisini yerinde kurar (BAKE_ANY=1 ile hızlı açılış bu durumda da doğru görüntü verir).
## Ölçüm: her yüzün burun ucuna köyden yatay ışın atılır -> çarpışma görselle aynı yerde mi (HKR ray satırları).
var main: Node
const HM = preload("res://scripts/world/hokage_monument.gd")


func _ready() -> void:
	await get_tree().process_frame
	if main.shot_dir == "":
		main.shot_dir = ProjectSettings.globalize_path("res://").path_join("../_tmp/hokage_rock").simplify_path()
	DirAccess.make_dir_recursive_absolute(main.shot_dir)
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.42
	WorldDay.auto = false
	var v = Game.village("konoha")
	var rock: Dictionary = v.get("hokage_rock", {})
	var cliff_n = float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"])
	var top = float(rock.get("top", float(v["base"]) + 165.0)) - float(v["base"])
	var H = clampf(top * 0.42, 40.0, 78.0)
	var fy = top * 0.56
	var origin = Vector3(float(v["x"]), float(v["base"]), -float(v["y"]))
	var wpos = func(x: float, y: float, n: float) -> Vector3:
		return origin + Vector3(x, y, -n)
	print("HKR cliff_n=%.1f top=%.1f H=%.1f fy=%.1f" % [cliff_n, top, H, fy])
	# kurulu mu?
	var scene = get_tree().current_scene
	var have = scene.find_children("HokageMonument*", "MeshInstance3D", true, false)
	if have.is_empty():
		var hidden = 0
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.visible:
				continue
			var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
			if absf(ab.size.x - 1.4 * H) < 4.0 and absf(ab.size.y - 1.9 * H) < 6.0:
				mi.visible = false
				hidden += 1
		var off = 0
		for cs in scene.find_children("*", "CollisionShape3D", true, false):
			if cs.shape is ConcavePolygonShape3D and (cs.shape as ConcavePolygonShape3D).get_faces().size() == 19698:
				cs.disabled = true
				off += 1
		var b = Builder.new(scene, float(v["x"]), float(v["y"]), float(v["base"]), "HokageTest")
		var t0 = Time.get_ticks_msec()
		HM.carve(b, rock, cliff_n, v)
		print("HKR standalone: eski gizlenen=%d çarpışma kapatılan=%d kurulum=%d ms" % [hidden, off, Time.get_ticks_msec() - t0])
		for eb in b.extra_bodies:
			if eb.get_parent() == null:
				b.root.add_child(eb)
	else:
		print("HKR köyde kurulu: %d baş" % have.size())
	var tris = 0
	for mi in scene.find_children("HokageMonument*", "MeshInstance3D", true, false):
		tris += mi.mesh.surface_get_array_index_len(0) / 3
	print("HKR üçgen=%d" % tris)
	main.player.respawn(wpos.call(0.0, 0.0, cliff_n - 520.0) + Vector3(0, Game.terrain_height(origin.x, origin.z - cliff_n + 520.0) - origin.y + 1.0, 0))
	await get_tree().create_timer(2.0).timeout
	main.player.visible = false
	# çarpışma ışınları: burun ucunun 60 m önünden kayaya doğru
	await get_tree().physics_frame
	var space = main.player.get_world_3d().direct_space_state
	for i in HM.probes.size():
		var p: Vector3 = HM.probes[i]
		var q = PhysicsRayQueryParameters3D.create(p + Vector3(0, 0, 60), p - Vector3(0, 0, 10))
		var hit = space.intersect_ray(q)
		if hit.is_empty():
			print("HKR ray %d: ISABET YOK (görsel burun z=%.2f)" % [i, p.z])
		else:
			print("HKR ray %d: çarpışma z=%.2f görsel z=%.2f fark=%.2f m" % [i, hit["position"].z, p.z, hit["position"].z - p.z])
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	scene.add_child(cam)
	var gap = 92.0
	var shots = [
		["hr_front", Vector3(0, fy * 1.05, cliff_n - 390), Vector3(0, fy * 0.9, cliff_n)],   # kulenin üstünde, havada
		["hr_34", Vector3(-360, fy * 0.8, cliff_n - 300), Vector3(-10, fy, cliff_n)],
		["hr_close2", Vector3(28, fy + 4, cliff_n - 150), Vector3(0, fy, cliff_n - 20)],
		["hr_close0", Vector3(-2 * gap + 70, fy + 8, cliff_n - 140), Vector3(-2 * gap, fy, cliff_n - 20)],
		["hr_close4", Vector3(2 * gap - 70, fy, cliff_n - 140), Vector3(2 * gap, fy, cliff_n - 20)],
		["hr_close1", Vector3(-gap - 20, fy - 10, cliff_n - 140), Vector3(-gap, fy, cliff_n - 20)],
		["hr_close3", Vector3(gap + 25, fy - 10, cliff_n - 140), Vector3(gap, fy, cliff_n - 20)],
		["hr_side", Vector3(-430, fy - 5, cliff_n - 75), Vector3(120, fy, cliff_n - 20)],
	]
	# oyuncu gözü: köyden, yerden 2 m
	# açık zemin ara: yukarıdan inen ışın araziye (bina / ağaç değil) çarpmalı ve yüzlere bakış 60 m boyunca engelsiz olmalı
	var found = false
	for gn in [cliff_n - 200.0, cliff_n - 240.0, cliff_n - 280.0, cliff_n - 320.0, cliff_n - 380.0, cliff_n - 450.0]:
		for gx in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 130.0, -130.0, 170.0, -170.0, 220.0, -220.0]:
			var gw: Vector3 = wpos.call(gx, 0.0, gn)
			var th = Game.terrain_height(gw.x, gw.z)
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(gw.x, th + 120.0, gw.z), Vector3(gw.x, th - 2.0, gw.z)))
			if hit.is_empty() or hit["position"].y > th + 1.2:
				continue
			var eye = Vector3(gw.x, th + 2.0, gw.z)
			var tgt: Vector3 = wpos.call(0.0, fy, cliff_n)
			var hit2 = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + (tgt - eye).normalized() * 25.0))
			if not hit2.is_empty():
				continue
			shots.append(["hr_ground", Vector3(gx, th - origin.y + 2.0, gn), Vector3(0, fy, cliff_n)])
			print("HKR zemin kamerası x=%.0f n=%.0f" % [gx, gn])
			found = true
			break
		if found:
			break
	if not found:
		print("HKR zemin kamerası: açık yer bulunamadı")
	for s in shots:
		var cp: Vector3 = s[1]
		var tp: Vector3 = s[2]
		cam.global_position = wpos.call(cp.x, cp.y, cp.z)
		cam.look_at(wpos.call(tp.x, tp.y, tp.z), Vector3.UP)
		cam.current = true
		await get_tree().create_timer(0.8).timeout
		await main.shot(s[0])
		print("HKR shot %s" % s[0])
	get_tree().quit()
