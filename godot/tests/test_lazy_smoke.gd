extends Node
## İlk kullanımda yüklenen betikler (LazyFx) için duman testi: her jutsu bir kez atılır (hızlandırılmış), dünya / NPC / menü
## akışı da çalışır. Günlükte "base 'GDScript'" hataları tembel çağrının bozulduğunu gösterir. PART=i/N ile bölümlenir.
var main: Node

func _foe(pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.setup(Enemy.archetype("rogue", 1))
	main.actors.add_child(e)
	e.global_position = pos
	e.home = pos
	e.max_hp = 1e7
	e.hp = 1e7
	e.set_physics_process(false)
	return e

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken",
		"hair": Color(0.2, 0.2, 0.2), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await get_tree().create_timer(1.5).timeout
	Hud.close_dialog()
	Game.set_meta("sandbox", true)
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9; pl.max_chakra = 1e9; pl.chakra = 1e9
	var vs = Game.village("suna")
	var base = Game.from_map(Vector2(vs["x"] + float(vs["r"]) + 600, vs["y"]))
	pl.respawn(base)
	await get_tree().create_timer(1.0).timeout
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32
	Engine.time_scale = 4.0
	var ids: Array = []
	for id in Data.jutsu:
		if Data.jutsu[id] is Dictionary:
			ids.append(String(id))
	ids.sort()
	var pp = OS.get_environment("PART").split("/") if OS.get_environment("PART") != "" else PackedStringArray(["0", "1"])
	var n = ids.size()
	var lo = n * int(pp[0]) / int(pp[1]); var hi = n * (int(pp[0]) + 1) / int(pp[1])
	var t0 := Time.get_ticks_msec()
	for k in range(lo, hi):
		var id: String = ids[k]
		var before := {}
		for ch in get_tree().current_scene.get_children():
			before[ch] = true
		var f = _foe(base + Vector3(0, 0, -5.0))
		pl.global_position = base
		pl.combat.cooldowns.erase(id)
		pl.combat.action = ""
		print("LZ ", id)
		Jutsu.execute(pl, id, f)
		await get_tree().create_timer(1.6).timeout
		for ch in get_tree().current_scene.get_children():
			if not before.has(ch) and ch != pl:
				ch.queue_free()
		for f2 in get_tree().get_nodes_in_group("fighters"):
			if f2 != pl and is_instance_valid(f2):
				f2.queue_free()
		for b in Buffs.active.keys():
			Buffs.remove(b)
		if pl.has_method("stop_flight"):
			pl.stop_flight()
		if pl.combat.has_method("cancel"):
			pl.combat.cancel()
		pl.hp = pl.max_hp
		pl.chakra = pl.max_chakra
		if pl.get("model"):
			pl.model.position = Vector3.ZERO
			pl.model.scale = Vector3.ONE
			pl.model.visible = true
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("LZ BITTI %d-%d / %d  %.0f sn" % [lo, hi, n, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit()
