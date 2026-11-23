extends Node
## Kapı etkileşim yazısı: Konoha'da en yakın 3 "enter" noktasına yürüyerek yaklaş, HUD dahil tam ekran görüntü + yazı durumu.
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/door"))
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	var pl = main.player
	var kinds := {}
	for it in Interact.items:
		kinds[String(it["kind"])] = int(kinds.get(String(it["kind"]), 0)) + 1
	print("DOOR turler=%s" % str(kinds))
	var doors = Interact.items.filter(func(it): return String(it["kind"]) == "enter")
	doors.sort_custom(func(a, b): return pl.global_position.distance_to(a["pos"]) < pl.global_position.distance_to(b["pos"]))
	var i := 0
	for it in doors.slice(0, 3):
		var p: Vector3 = it["pos"]
		var out: Vector3 = it.get("out", p + Vector3(0, 0, 3))
		var dir = (out - p) * Vector3(1, 0, 1)
		dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
		pl.respawn(p + dir * 3.0 + Vector3.UP * 0.5)
		await _w(1.5)
		var near = Interact.nearest(pl.global_position)
		print("DOOR %d etiket=%s yaricap=%.1f uzaklik=%.1f yakin=%s kutu=%s yazi=%s" % [i, String(it.get("label", "")), float(it["radius"]), pl.global_position.distance_to(p), String(near.get("label", "-")), str(Hud.prompt_box.is_visible_in_tree()), Hud.prompt_lbl.text])
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2)
		im.save_png("res://../_tmp/door/d_%d.png" % i)
		i += 1
	get_tree().quit()
