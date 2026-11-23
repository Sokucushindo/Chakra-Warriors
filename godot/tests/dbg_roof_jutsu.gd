extends Node
## Çatıdan atılan jutsu: zemin hesabı çatıyı buluyor mu, zemin tekniği çatının üstünde mi çıkıyor
var main: Node
var cam: Camera3D
const ID := "doton_doryuheki"


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "doton", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.1), "top": Color(0.2, 0.3, 0.5), "skin": Color(0.95, 0.8, 0.68), "eye": Color(0.2, 0.4, 0.8)}
	main._start_new_game()
	await _w(3.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var v = Game.village("konoha")
	var c = Game.from_map(Vector2(v["x"], v["y"]))
	# çatı ara: yerden 4 m'den yüksek, düz sayılır (komşu noktalar aynı yükseklikte)
	var space = pl.get_world_3d().direct_space_state
	var roof = null
	for i in 400:
		var p = c + Vector3(randf_range(-160, 160), 0, randf_range(-160, 160))
		var th = Game.terrain_height(p.x, p.z)
		var h = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, th + 40.0, p.z), Vector3(p.x, th - 1.0, p.z), 1))
		if h.is_empty() or float(h["position"].y) < th + 4.0 or h["collider"] is CharacterBody3D:
			continue
		var ok = true
		for o in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4)]:
			var h2 = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, th + 40.0, p.z) + o, Vector3(p.x, th - 1.0, p.z) + o, 1))
			if h2.is_empty() or absf(float(h2["position"].y) - float(h["position"].y)) > 1.2:
				ok = false
		if ok:
			roof = h["position"]
			break
	if roof == null:
		print("CATI BULUNAMADI")
		get_tree().quit()
		return
	pl.respawn(roof + Vector3.UP * 0.5)
	await _w(1.5)
	var gp = pl.global_position
	print("CATI y=%.2f arazi=%.2f eski_zemin=%.2f yeni_zemin=%.2f oyuncu_y=%.2f" % [roof.y, Game.terrain_height(gp.x, gp.z), Game.jutsu_floor(gp.x, gp.z), Game.jutsu_floor_at(gp).y, gp.y])
	cam = Camera3D.new()
	main.add_child(cam)
	main.world.env.attach_post(cam)
	cam.global_position = gp + Vector3(9, 6, 9)
	cam.look_at(gp + Vector3.UP * 1.0)
	cam.current = true
	Game.profile["learned"].append(ID)
	pl.max_chakra = 1e9
	pl.chakra = 1e9
	pl.facing = 0.0
	Jutsu.execute(pl, ID, null)
	await _w(2.0)
	await RenderingServer.frame_post_draw
	var im = get_viewport().get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2)
	im.save_png("res://../_tmp/roof_jutsu.png")
	var lows := 0
	var highs := 0
	for n in get_tree().current_scene.find_children("*", "MeshInstance3D", true, false):
		if n.is_visible_in_tree() and not pl.is_ancestor_of(n) and n.global_position.distance_to(gp) < 12.0 and n.global_position.distance_to(gp) > 0.5 and n.get_aabb().size.length() < 60.0:
			if n.global_position.y < roof.y - 2.0:
				lows += 1
			else:
				highs += 1
	print("EFEKT cati_ustu=%d cati_alti=%d" % [highs, lows])
	get_tree().quit()
