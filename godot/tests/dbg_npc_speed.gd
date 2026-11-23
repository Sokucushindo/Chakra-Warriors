extends Node
## Şehirde aşırı hızlı köylü avı: oyuncu sokaklarda dolaşır; her fizik karesinde köylülerin yer değiştirmesi ölçülür,
## 9 m/sn üstü (çatı ninjası hariç) yazılır: rol, durum, hedef, oyuncuya uzaklık
var main: Node
var last := {}
var hits := 0
var seen := {}

func _physics_process(dt: float) -> void:
	if main == null or main.player == null:
		return
	var pp = main.player.global_position
	for n in get_tree().get_nodes_in_group("villagers") if get_tree().has_group("villagers") else []:
		pass
	for n in get_tree().current_scene.find_children("*", "Villager", true, false):
		if not is_instance_valid(n):
			continue
		var p: Vector3 = n.global_position
		var id = n.get_instance_id()
		if last.has(id):
			var d = Vector2(p.x - last[id].x, p.z - last[id].z).length()
			var sp = d / dt
			if sp > 9.0 and sp < 5000.0 and String(n.role) != "roof":
				hits += 1
				var key = "%s|%s" % [n.role, n.get_class()]
				seen[key] = int(seen.get(key, 0)) + 1
				if hits <= 25 and sp < 200.0:
					print("  vel=%.1f fizik=%s durum=%s bekle=%.2f goal=%s pos=%s once=%s" % [Vector2(n.velocity.x, n.velocity.z).length(), str(n.is_physics_processing()), n.state, n.wait, str(n.goal), str(p), str(last[id])])
				if hits <= 25:
					print("HIZLI %.1f m/sn rol=%s sinif=%s ad=%s oyuncuya=%.0f goal_d=%.1f going_home=%s dest=%s follow=%s meta=%s" % [sp, n.role, n.get_script().get_global_name(), n.display_override, p.distance_to(pp), p.distance_to(n.goal), str(n.going_home), str(n.dest != Vector3.INF), str(n.follow != null), str(n.get_meta_list())])
		last[id] = p

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	var v = Game.village(OS.get_environment("VIL") if OS.get_environment("VIL") != "" else "konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	var pts = []
	for i in 8:
		var a = TAU * i / 8.0
		var r = [60.0, 160.0, 300.0][i % 3]
		pts.append(c + Vector3(sin(a) * r, 0, cos(a) * r))
	for p in pts:
		var q = Missions.open_ground(p, 8.0)
		main.player.respawn(q + Vector3.UP)
		last.clear()
		# yürüyerek yaklaş: oyuncu yavaşça ilerler (köylüler uzaktan yakına girer)
		for k in 40:
			main.player.global_position += Vector3(1.2, 0, 0.6)
			await get_tree().create_timer(0.1).timeout
		await get_tree().create_timer(1.0).timeout
		print("NOKTA bitti hizli=", hits)
	print("TOPLAM hızlı kare=", hits, " ", seen)
	get_tree().quit()
