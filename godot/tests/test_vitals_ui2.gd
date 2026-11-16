extends Node
## VitalsUI doğrulama: kaçak rütbe metni, Aburame / Hozuki / Inuzuka çubukları, Türkçe metin, çizim maliyeti
var main: Node


func _shot(name: String) -> void:
	var dir = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/kv/"
	get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 720, 290)).save_png(dir + name + ".png")


func _avg_frame_ms(n: int, vary: bool) -> float:
	var t0 = Time.get_ticks_usec()
	for i in n:
		if vary:
			Game.player.chakra = fposmod(Game.player.chakra + 0.9, Game.player.max_chakra)
			Game.player.hp = fposmod(Game.player.hp + 1.3, Game.player.max_hp)
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / n / 1000.0


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Deneme", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.15, 0.15, 0.17), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	var pr: Dictionary = Game.profile
	var pl = Game.player
	Lang.apply("tr")
	pr["rank"] = 5
	pr["level"] = 100
	pr["ryo"] = 123456
	pr["clan"] = "aburame"
	await get_tree().create_timer(1.2).timeout
	print("TR aburame meter=", ClanMech.meter())
	_shot("vit2_1_aburame_tr")
	pr["clan"] = "hozuki"
	await get_tree().create_timer(1.0).timeout
	print("hozuki meter=", ClanMech.meter())
	_shot("vit2_2_hozuki")
	pr["clan"] = "inuzuka"
	await get_tree().create_timer(1.5).timeout
	print("inuzuka meter=", ClanMech.meter(), " dog=", ClanMech.dog())
	_shot("vit2_3_inuzuka")
	pr["clan"] = "none"
	Orgs.flags()["rogue"] = true
	await get_tree().create_timer(1.0).timeout
	print("rogue=", Orgs.is_rogue(), " ", Orgs.rogue_rank_name())
	_shot("vit2_4_kacak")
	Orgs.flags()["rogue"] = false
	# çizim maliyeti: her karede değişen değer (en kötü durum) ve sabit
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await get_tree().create_timer(1.0).timeout
	for rep in 2:
		Hud.vit.visible = false
		var a = await _avg_frame_ms(240, true)
		Hud.vit.visible = true
		var b = await _avg_frame_ms(240, true)
		var c = await _avg_frame_ms(240, false)
		print("kare ms: gizli(değişen)=%.3f  görünür(her karede değişen)=%.3f  görünür(sabit)=%.3f" % [a, b, c])
	get_tree().quit()
