extends Node
## Tüm jutsu sayımı (denge): her jutsu duran ve yana kaçan (6 m/sn) dayanıklı hedefe atılır, 3.5 sn'deki gerçek hasar ölçülür;
## hazırlık (release_t), toparlanma (post), CD, bedel ile birlikte satır yazılır. PART=i/N ile bölümlenir.
## Çıktı: "CEN id|kategori|şekil|kanon|tier|dmg_k|bedel|cd|rt|post|duran|kaçan|need|learn"
var main: Node
var _mv: Node3D = null
var _mv_t := 0.0

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

func _process(dt: float) -> void:
	if is_instance_valid(_mv):
		_mv_t += dt
		var x = sin(_mv_t * 1.6) * 2.5   # ~4 m/sn yana kaçış, ileri geri (koşan rakip)
		_mv.global_position = Vector3(_mv.home.x + x, _mv.home.y, _mv.home.z)

func _clean(pl, before: Dictionary) -> void:
	for ch in get_tree().current_scene.get_children():
		if not before.has(ch) and ch != pl:
			ch.queue_free()
	for f2 in get_tree().get_nodes_in_group("fighters"):
		if f2 != pl and is_instance_valid(f2) and (f2.get("team") == "player" or f2 is ShadowClone or f2 is Summon):
			f2.queue_free()
	for k in Buffs.active.keys():
		Buffs.remove(k)
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

func _dmg(pl, id: String, base: Vector3, dist: float) -> float:
	var f = _foe(base + Vector3(0, 0, -dist))
	f.global_position.y = Game.terrain_height(f.global_position.x, f.global_position.z) + 0.1
	pl.global_position = base
	pl.facing = 0.0
	pl.combat.cooldowns.erase(id)
	pl.combat.action = ""
	pl.combat.lock_target = f
	await get_tree().create_timer(0.1).timeout
	var before := {}
	for ch in get_tree().current_scene.get_children():
		before[ch] = true
	var h0 = f.hp
	Jutsu.execute(pl, id, f)
	var t := 0.0
	var lim = 2.5 + dist / 18.0
	while t < lim and is_instance_valid(f) and f.hp >= h0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	var d = h0 - f.hp if is_instance_valid(f) else 0.0
	pl.combat.lock_target = null
	_clean(pl, before)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(f):
		f.queue_free()
	pl.global_position = base
	return d

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken",
		"hair": Color(0.2, 0.2, 0.2), "top": Color(0.15, 0.2, 0.33), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await get_tree().create_timer(1.5).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	Game.set_meta("sandbox", true)
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9; pl.max_chakra = 1e9; pl.chakra = 1e9
	var vs = Game.village("suna")
	var base = Game.from_map(Vector2(vs["x"] + float(vs["r"]) + 600, vs["y"]))
	pl.respawn(base)
	await get_tree().create_timer(1.0).timeout
	# hızlı ölçüm: oyun saati 4x, fizik adımı aynı kalsın diye tick de 4x (mermi tünellemesin)
	var ts = float(OS.get_environment("TS")) if OS.get_environment("TS") != "" else 4.0
	Engine.physics_ticks_per_second = int(60 * ts)
	Engine.max_physics_steps_per_frame = int(8 * ts)
	Engine.time_scale = ts
	var ids: Array = []
	for id in Data.jutsu:
		if Data.jutsu[id] is Dictionary:
			ids.append(String(id))
	ids.sort()
	var only = OS.get_environment("IDS")
	if only != "":
		ids = Array(only.split(",")).filter(func(x): return Data.jutsu.has(x))
	var pp = OS.get_environment("PART").split("/") if OS.get_environment("PART") != "" else PackedStringArray(["0", "1"])
	var pi = int(pp[0]); var pn = int(pp[1])
	var n = ids.size()
	var lo = n * pi / pn; var hi = n * (pi + 1) / pn
	var RANGED = ["projectile", "aoe", "bind", "beam", "genjutsu_stun", "field", "seal", "trap", "debuff", "line", "cone", "wall"]
	for k in range(lo, hi):
		var id: String = ids[k]
		var j: Dictionary = Data.jutsu[id]
		if not String(j.get("shape", "")) in RANGED or String(j.get("category", "")) in ["taijutsu", "kenjutsu"]:
			continue
		var r := [0.0, -1.0, -1.0, -1.0]
		var ds := [12.0, 30.0, 60.0, 110.0]
		for q in 4:
			r[q] = await _dmg(pl, id, base, ds[q])
			if r[q] <= 0.0:
				break
		print("RNG %s|%s|%s|%d|%.0f|%.0f|%.0f|%.0f" % [id, String(j.get("shape", "")), String(j.get("element", "")), int(j.get("tier", 2)), r[0], r[1], r[2], r[3]])
	print("RNG_DONE")
	get_tree().quit()
