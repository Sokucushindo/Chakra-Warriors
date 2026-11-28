extends Node
## Kaçak: surun DIŞINDA köy ninjası görünce saldırıyor mu, konuşmaya kalkınca tanışma yerine saldırı mı
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _foes() -> int:
	var n = 0
	for c in get_tree().current_scene.get_children():
		if c is Enemy and not c.dead:
			n += 1
	return n
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	await _w(4.0)
	Hud.close_dialog()
	var pl = main.player
	pl.max_hp = 1e9; pl.hp = 1e9
	var vv = Game.village("konoha")
	var c = Vector2(vv["x"], vv["y"])
	var nin = []
	pl.respawn(Missions.open_ground(Game.from_map(c + Vector2(0, float(vv["r"]) * 0.25)), 20.0) + Vector3(0, 1, 0))
	for tryi in 50:
		await _w(1.0)
		if main.loading != null:
			continue
		nin = []
		for v in get_tree().get_nodes_in_group("talkers"):
			if (v is Villager or v is ClanResident) and LazyFx.g("Friends").is_ninja(v):
				nin.append(v)
		if nin.size() >= 2 or (nin.size() >= 1 and tryi > 15):
			break
	print("RG koy ninjasi=", nin.size(), " kacak=", Orgs.is_rogue())
	if nin.size() < 1:
		print("bitti"); get_tree().quit(); return
	Orgs.flags()["rogue"] = true
	Orgs.flags()["rogue_from"] = "kumo"
	print("RG kacak=", Orgs.is_rogue(), " avci mi=", Orgs._hunter(nin[0]))
	# 1) "sur dışı": köy sınırı geçici küçültülür (oyuncu köy yarıçapının dışında sayılır), ninjalar yerinde kalır
	var r0 = float(vv["r"])
	Game.village("konoha")["r"] = 4.0
	print("RG sinir kuculdu mu=", float(Game.village("konoha")["r"]))
	pl.global_position = nin[0].global_position + Vector3(0, 0.5, 10)
	await get_tree().process_frame
	var m = Game.to_map(pl.global_position)
	print("RG baskin=", not Orgs._raid.is_empty())
	var a = nin[0]
	var b = nin[1] if nin.size() > 1 else null
	print("RG avci a=", Orgs._hunter(a), " rol=", a.get("role"), " uzaklik=", a.global_position.distance_to(pl.global_position))
	var f0 = _foes()
	for fr in 240:
		if not is_instance_valid(a) or _foes() > f0:
			break
		if fr < 40:
			pl.global_position = a.global_position + a.face_dir() * 8.0 + Vector3(0, 0.4, 0)
			pl.velocity = Vector3.ZERO
		await get_tree().process_frame
	if is_instance_valid(a):
		print("RG son uzaklik=", a.global_position.distance_to(pl.global_position))
	print("RG gorunce: dusman once=", f0, " sonra=", _foes(), " ninja hala koylu=", is_instance_valid(a) and a.visible and a.is_inside_tree(), " baskin=", not Orgs._raid.is_empty())
	# 2) konuşmaya kalk (uzaktaki, görmeyen ninja)
	var f1 = _foes()
	if b != null and is_instance_valid(b):
		pl.global_position = b.global_position + Vector3(0, 0.3, 1.5)
		b.talk()
		await _w(1.5)
		print("RG konusunca: dusman once=", f1, " sonra=", _foes(), " pencere acik=", Hud.dialog_open() if Hud.has_method("dialog_open") else "?")
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/rogue_see.png")
	print("bitti")
	get_tree().quit()
