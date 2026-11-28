extends Node
## Çok çekirdek mekanik denemesi (hata ayıklama derlemesinde koşulur: iş parçacığı kuralı ihlalleri hata satırı olarak düşer).
##  1) her klandan en güçlü gerçek ninja iki takım halinde dövüşür (göz, klan tekniği, beden büyütme, kendi jutsuları)
##  2) oyundaki HER silah sırayla ninjaların eline verilir, dövüşürler
##  3) modeller iş parçacığındayken toplu doğma / silinme + çok çekirdek ayarını aç-kapa
## Satırlar "TM" ile başlar. TM_PH="1,2,3" ile aşama seçilir, TM_SEC aşama 1 süresi.
var main: Node


func _spawn(e: Enemy, at: Vector3, list: Array) -> void:
	get_tree().current_scene.add_child(e)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	e.global_position = at
	e.home = at
	e.wander_to = at
	e.max_hp = 9999999.0
	e.hp = e.max_hp
	list.append(e)


func _clear(list: Array) -> void:
	for e in list:
		if is_instance_valid(e):
			e.queue_free()
	list.clear()


func _threaded(list: Array) -> int:
	var n := 0
	for e in list:
		if is_instance_valid(e) and e.get("model") != null and is_instance_valid(e.model) and e.model.get("_thr_live"):
			n += 1
	return n


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.9, 0.4, 0.1),
		"top": Color(0.2, 0.3, 0.6), "bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	Game.profile["kd_wait"] = 99999.0
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	var at: Vector3 = Missions.open_ground(c + Vector3(120, 0, -160), 25.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	pl.respawn(at)
	pl.max_hp = 9999999.0
	pl.hp = pl.max_hp
	await get_tree().create_timer(8.0).timeout
	var ph := OS.get_environment("TM_PH") if OS.get_environment("TM_PH") != "" else "1,2,3"
	var list: Array = []
	seed(11)
	if "1" in ph:
		var best := {}
		for q in WorldPeople.all().values():
			if not WorldPeople.alive(q) or int(q["rank"]) < 1:
				continue
			var cl := String(q.get("clan", ""))
			if not best.has(cl) or float(q.get("level", 0)) > float(best[cl].get("level", 0)):
				best[cl] = q
		var ks: Array = best.keys()
		ks.sort()
		print("TM 1 klan sayisi %d: %s" % [ks.size(), ", ".join(ks)])
		var i := 0
		for cl in ks.slice(0, 30):
			var e: Enemy = Kage._real_ninja(best[cl], "enemy" if i % 2 == 0 else "player")
			_spawn(e, at + Vector3(randf_range(-12, 12), 0, -16.0 if i % 2 == 0 else 2.0), list)
			i += 1
			await get_tree().process_frame
		var sec := float(OS.get_environment("TM_SEC")) if OS.get_environment("TM_SEC") != "" else 60.0
		var t := 0.0
		while t < sec:
			await get_tree().create_timer(10.0).timeout
			t += 10.0
			print("TM 1 t=%d is parcaciginda %d / %d | FPS %d" % [int(t), _threaded(list), list.size(), Engine.get_frames_per_second()])
		_clear(list)
		await get_tree().create_timer(1.0).timeout
	if "2" in ph:
		var G = LazyFx.g("Gear")
		var wids: Array = []
		for id in G.ITEMS:
			if (G.ITEMS[id] as Dictionary).has("weapon"):
				wids.append(String(id))
		wids.sort()
		print("TM 2 silah sayisi %d" % wids.size())
		var k := 0
		while k < wids.size():
			for j in 24:
				if k >= wids.size():
					break
				var e: Enemy = Kage._ninja_of("kumo" if j % 2 == 0 else "konoha", j, 25, "enemy" if j % 2 == 0 else "player")
				e.look["weapon_r"] = wids[k]
				k += 1
				_spawn(e, at + Vector3(randf_range(-10, 10), 0, -10.0 if j % 2 == 0 else 0.0), list)
				await get_tree().process_frame
			await get_tree().create_timer(6.0).timeout
			print("TM 2 silah %d / %d | is parcaciginda %d / %d" % [k, wids.size(), _threaded(list), list.size()])
			_clear(list)
			await get_tree().create_timer(0.6).timeout
	if "3" in ph:
		for r in 12:
			for j in 8:
				var e: Enemy = Kage._ninja_of("kumo" if j % 2 == 0 else "konoha", r * 8 + j, 25, "enemy" if j % 2 == 0 else "player")
				_spawn(e, at + Vector3(randf_range(-10, 10), 0, -10.0 if j % 2 == 0 else 0.0), list)
			await get_tree().create_timer(1.2).timeout
			if r % 3 == 1:
				Game.settings["multicore"] = not bool(Game.settings.get("multicore", true))
			# yarısı silinir (iş parçacığındayken), yarısı kalır
			for j in range(list.size() - 1, -1, -2):
				if is_instance_valid(list[j]):
					list[j].queue_free()
				list.remove_at(j)
			print("TM 3 tur %d | sahnede %d | is parcaciginda %d" % [r, list.size(), _threaded(list)])
		Game.settings["multicore"] = true
		await get_tree().create_timer(3.0).timeout
		_clear(list)
		await get_tree().create_timer(1.0).timeout
	print("TM BITTI")
	get_tree().quit()
