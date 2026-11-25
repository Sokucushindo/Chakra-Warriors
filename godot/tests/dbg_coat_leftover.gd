extends Node
## Bedende kalan kaplama avı: IDS teknikleri hem oyuncu düşmana hem düşman oyuncuya atar; her atıştan sonra iki bedenin modeline
## eklenen düğümler / değişen material_overlay kaydedilir. 30 sn sonra hâlâ duranlar hangi teknikten geldiğiyle yazılır.
var main: Node

func _snap(root: Node) -> Dictionary:
	var o := {}
	if root == null or not is_instance_valid(root):
		return o
	for n in root.find_children("*", "", true, false):
		var ov = ""
		if n is GeometryInstance3D:
			ov = str((n as GeometryInstance3D).material_overlay) + str((n as GeometryInstance3D).material_override)
		o[n.get_instance_id()] = ov
	return o

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "none", "village": "konoha", "element": "doton", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	pl.max_chakra = 99999.0
	pl.max_hp = 9999999.0
	pl.hp = pl.max_hp
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 700.0), 80.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	pl.respawn(at)
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1 and String(q.get("clan", "")) in ["", "none"])
	var a = WorldPeople.arch_of(cands[0])
	a["respawn"] = false
	a["jutsu"] = []
	var e = Enemy.new()
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = at + Vector3(0, 0, -7.0)
	e.global_position.y = Game.ground_height(e.global_position.x, e.global_position.z) + 0.1
	e.home = e.global_position
	await get_tree().create_timer(0.6).timeout
	e.max_hp = 9999999.0; e.hp = e.max_hp
	e.skill = 0.0
	e.attack_cd = 9999.0
	var base_p = _snap(pl)
	var base_e = _snap(e)
	var src := {}   # instance id -> [jutsu, hangi beden, overlay mi]
	for jid in OS.get_environment("IDS").split(",", false):
		if not Data.jutsu.has(jid):
			continue
		for dir in 2:
			if not (is_instance_valid(pl) and is_instance_valid(e)):
				break
			pl.hp = pl.max_hp; pl.chakra = pl.max_chakra
			e.hp = e.max_hp
			pl.statuses.clear(); e.statuses.clear()
			pl.combat.cooldowns.clear()
			pl.combat.lock_target = e
			e.target = null
			var before_p = _snap(pl)
			var before_e = _snap(e)
			if dir == 0:
				Jutsu.execute(pl, jid, e)
			else:
				Jutsu.execute(e, jid, pl)
			await get_tree().create_timer(1.2).timeout
			for pair in [["pl", pl, before_p], ["en", e, before_e]]:
				var now = _snap(pair[1])
				for id in now:
					if not pair[2].has(id):
						if not src.has(id):
							src[id] = [jid, pair[0], "yeni", dir]
					elif now[id] != pair[2][id]:
						src[id] = [jid, pair[0], "kaplama", dir]
		# sahnede uzaklaşıp kaybolmasınlar
		if is_instance_valid(pl):
			pl.global_position = at
		if is_instance_valid(e):
			e.global_position = at + Vector3(0, 0, -7.0)
	print("COAT atışlar bitti, 30 sn bekleniyor")
	await get_tree().create_timer(30.0).timeout
	var left := {}
	for pair in [["pl", pl, base_p], ["en", e, base_e]]:
		if not is_instance_valid(pair[1]):
			continue
		var now = _snap(pair[1])
		for id in now:
			var changed = (not pair[2].has(id)) or now[id] != pair[2][id]
			if changed and src.has(id):
				var n = instance_from_id(id)
				var k = "%s %s %s %s" % [src[id][0], "oyuncu->düşman" if src[id][3] == 0 else "düşman->oyuncu", pair[0], src[id][2]]
				left[k] = int(left.get(k, 0)) + 1
				if left[k] == 1:
					print("COAT KALAN %s  düğüm=%s yol=%s" % [k, n.name if n else "?", str(n.get_path()) if n else ""])
	print("COAT sonuc kalan_tur=%d" % left.size())
	get_tree().quit()
