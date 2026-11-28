extends Node
## Kan alarmı + köy yok etme: köylüye vurunca alarm, ninjalar saldırır, siviller kaçar, konuşma kapanır; Kage + NEED ölüm -> köy düşer
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _shot(nm: String) -> void:
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/bl_%s.png" % nm)
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 96, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pl = main.player
	pl.max_hp = 1e8; pl.hp = 1e8
	Game.profile["ryo"] = 90000
	var c = LazyFx.g("VillageFall").center("konoha")
	pl.respawn(Missions.open_ground(c, 30.0))
	await _w(12.0)
	# 1) gizli öldürme: köyün ıssız kenarında, kimse görmeden -> alarm çalmamalı
	var all: Array = []
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and not v.interior and not LazyFx.g("Friends").is_ninja(v):
			all.append(v)
	print("BL sivil sayısı=", all.size())
	if all.size() >= 2:
		var civ0: Villager = all[0]
		var far = c
		var best = 0.0
		for a8 in 16:
			var q = c + Vector3(cos(a8 * 0.39), 0, sin(a8 * 0.39)) * 300.0
			var m = 1e9
			for v in get_tree().get_nodes_in_group("talkers"):
				if v is Node3D and v != civ0:
					m = minf(m, v.global_position.distance_to(q))
			if m > best and LazyFx.g("VillageFall").vid_at(q, 1.0) == "konoha":
				best = m; far = q
		pl.respawn(Missions.open_ground(far, 6.0))
		await _w(1.0)
		civ0.global_position = pl.global_position + Vector3(2, 0, 0)
		await _w(0.2)
		LazyFx.g("Crime").on_struck(civ0)
		await _w(0.1)
		for vc in LazyFx.g("Crime").inst().victims:
			if is_instance_valid(vc["node"]):
				vc["node"].take_hit({"dmg": 1e9, "attacker": pl})
		await _w(1.0)
		print("BL gizli: kurban=", LazyFx.g("Crime").inst().victims.map(func(vc): return [is_instance_valid(vc["node"]), vc["dead"]]), " bekleyen=", LazyFx.g("Crime").inst()._pend.size(), " gören=", Orgs._spotted_by("konoha"))
		for q8 in 10:
			await _w(0.5)
			if Orgs.blood_on():
				var nr: Array = []
				for v in get_tree().get_nodes_in_group("talkers"):
					if v is Node3D and v.global_position.distance_to(pl.global_position) < 50.0:
						nr.append([v.get_class(), v.name, v.get("role"), v.visible, snappedf(v.global_position.distance_to(pl.global_position), 0.1), v.get_meta_list()])
				print("BL alarm çaldı t=", q8 * 0.5 + 1.0, " yakındakiler=", nr, " gören=", Orgs._spotted_by("konoha"), " kurban=", LazyFx.g("Crime").inst().victims.map(func(vc): return [is_instance_valid(vc["node"]), vc["dead"]]))
				break
		print("BL gizli öldürme: en yakın kişi=", snappedf(best, 1.0), " m, alarm=", Orgs.blood_on(), " (false olmalı)")
		Orgs._blood = {}
		Orgs._end_raid()
	# 2) kalabalıkta saldırı
	pl.respawn(Missions.open_ground(c, 30.0))
	await _w(6.0)
	var civs: Array = []
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and not v.interior and not LazyFx.g("Friends").is_ninja(v):
			civs.append(v)
	civs.sort_custom(func(x, y): return x.global_position.distance_to(pl.global_position) < y.global_position.distance_to(pl.global_position))
	var watch: Array = civs.slice(1, 6)
	for w in watch:
		w.global_position = Missions.open_ground(pl.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(12.0, 20.0), 6.0)
	await _w(0.3)
	var d0 = watch.map(func(v): return snappedf(v.global_position.distance_to(pl.global_position), 0.1))
	Orgs.flags()["rogue"] = true
	await _w(3.0)
	var dr = watch.filter(func(v): return is_instance_valid(v)).map(func(v): return snappedf(v.global_position.distance_to(pl.global_position), 0.1))
	print("BL kaçakken sivil uzaklık önce=", d0, " 3 sn sonra=", dr)
	Orgs.flags()["rogue"] = false
	print("BL kalabalık: sivil=", civs.size())
	var vic = null
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and not v.interior and not LazyFx.g("Friends").is_ninja(v) and not v.is_queued_for_deletion() and not watch.has(v):
			vic = v
			break
	print("BL kurban bulundu=", vic != null)
	if vic != null:
		vic.global_position = pl.global_position + Vector3(2, 0, 0)
		await _w(0.2)
		LazyFx.g("Crime").on_struck(vic)
		await _w(5.0)
		print("BL kalabalıkta: alarm=", Orgs.blood_on(), " baskın=", not Orgs._raid.is_empty())
		var foes := 0
		for f in get_tree().get_nodes_in_group("fighters"):
			if f is Enemy and not f.dead and f.target == pl:
				foes += 1
		print("BL bana saldıran=", foes, " sivil uzaklık=", watch.filter(func(v): return is_instance_valid(v)).map(func(v): return snappedf(v.global_position.distance_to(pl.global_position), 0.1)))
	_shot("alarm")
	if OS.get_environment("ONLY") != "":
		for f in get_tree().get_nodes_in_group("fighters"):
			if f is Enemy:
				f.queue_free()
		await _w(0.3)
		Orgs._raid["nodes"] = []
		Orgs._raid_wave("konoha", Orgs.RAID_WAVES[2])
		await _w(3.0)
		var cl: Array = []
		for f in get_tree().get_nodes_in_group("fighters"):
			if f is Enemy and f.has_meta("world_person"):
				var wp = WorldPeople.get_p(String(f.get_meta("world_person")))
				cl.append("%s (%s, Güç %d) hedef=%s" % [wp.get("name"), wp.get("clan"), int(wp.get("level", 0)), f.target == pl])
		print("BL klan dalgası: ", cl)
		_shot("klan")
		if not watch.is_empty() and is_instance_valid(watch[0]):
			watch[0].talk()
			await _w(0.3)
			print("BL konuşma açıldı mı=", Hud.dialog_layer.get_child_count() > 0)
		Game.delete_slot(96); Game.profile = {}
		get_tree().quit(); return
	# köy yok etme
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy:
			f.queue_free()
	print("BL klan nüfusu=", WorldPeople.clans_left("konoha"), " Uchiha=", WorldPeople.clan_alive("uchiha", "konoha"))
	var kn0 = Kage.kage_name("konoha")
	Kage.kage_killed("konoha", true)
	await _w(0.5)
	print("BL Kage öldü: düştü=", LazyFx.g("VillageFall").down("konoha"), " kuşatma=", LazyFx.g("VillageFall").siege("konoha"), " yeni Kage seçildi mi=", Kage.kage_name("konoha") != kn0)
	Orgs.blood_alarm("konoha")
	var rounds := 0
	while not LazyFx.g("VillageFall").down("konoha") and rounds < 12:
		rounds += 1
		Orgs._raid["t"] = 0.0
		await _w(1.5)
		var got := 0
		for f in get_tree().get_nodes_in_group("fighters"):
			if f is Enemy and not f.dead and f.has_meta("world_person") and f.has_meta("village_guard"):
				got += 1
				f.take_hit({"dmg": 1e9, "attacker": pl})
				if not f.dead:
					WorldPeople.on_enemy_died(f, {"attacker": pl})
					f.queue_free()
		await _w(0.6)
		Orgs._raid["nodes"] = (Orgs._raid.get("nodes", []) as Array).filter(func(n): return is_instance_valid(n) and not n.dead and not n.is_queued_for_deletion()) if not Orgs._raid.is_empty() else []
		print("BL kuşatma dalgası ", rounds, ": gelen=", got, " kalan=", WorldPeople.clans_left("konoha"), " düştü=", LazyFx.g("VillageFall").down("konoha"))
	print("BL yok olan klanlar=", WorldPeople.data().get("extinct", {}).keys().size(), " Kage adı değişti mi=", Kage.kage_name("konoha") != kn0)
	await _w(1.0)
	print("BL düştü=", LazyFx.g("VillageFall").down("konoha"), " bölge=", Game.region_name(pl.global_position), " yıkıntı=", WorldAssault.ruins().size())
	Orgs._blood = {}
	Orgs._end_raid()
	Hud.show_game_hud(false)
	await _w(25.0)
	var left := 0
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and LazyFx.g("VillageFall").vid_at(v.global_position, 1.05) == "konoha":
			left += 1
	print("BL köyde kalan köylü=", left, " direk=", LazyFx.g("VillageFall")._flag.has("konoha"))
	# ayakta kalan büyük parçalar (tüm sahne)
	var n := 0
	for mi in get_tree().current_scene.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		var cc = ab.get_center()
		if ab.size.y < 6.0 or minf(ab.size.x, ab.size.z) < 3.0 or Vector2(cc.x - c.x, cc.z - c.z).length() > 520.0:
			continue
		n += 1
		if n <= 30:
			print("BL ayakta ", String(mi.get_path()).right(60), " boy=", ab.size.snapped(Vector3.ONE), " uzak=", int(Vector2(cc.x - c.x, cc.z - c.z).length()))
	var k := 0
	for off in [Vector3(0, 60, 90), Vector3(120, 45, 0), Vector3(-40, 12, 30)]:
		var cam = Camera3D.new()
		main.add_child(cam)
		cam.far = 3000.0
		cam.global_position = c + off
		cam.look_at(c + Vector3(0, 5, 0))
		cam.make_current()
		await _w(1.5)
		_shot("ruin%d" % k)
		cam.queue_free()
		k += 1
	LazyFx.g("VillageFall").rebuild("konoha")
	await _w(1.0)
	print("BL yeniden: düştü=", LazyFx.g("VillageFall").down("konoha"), " kuruldu=", LazyFx.g("VillageFall").rebuilt("konoha"), " aileler=", LazyFx.g("VillageFall").rec("konoha").get("clans"), " para=", Game.profile["ryo"], " bölge=", Game.region_name(pl.global_position))
	Game.delete_slot(96)
	Game.profile = {}
	get_tree().quit()
