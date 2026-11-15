extends Node
## Alt çubuk: yan yuvalar (R/T/H/Y), boş yuva sönüklüğü, enerji bedeli rozeti. Görüntüler _tmp/kv/ altına.
var main: Node


func _shot(name: String) -> void:
	var dir = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/kv/"
	var img = get_viewport().get_texture().get_image()
	# yalnız alt çubuk bölgesi (yakın plan)
	var h = img.get_height()
	var w = img.get_width()
	img.get_region(Rect2i(int(w * 0.5) - 760, h - 230, 1520, 230)).save_png(dir + name + ".png")
	var full = img.duplicate()
	full.resize(w / 2, h / 2, Image.INTERPOLATE_LANCZOS)
	full.save_png(dir + name + "_tam.png")


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	var pr: Dictionary = Game.profile
	print("slots=", pr["slots"], " inv=", pr["inventory"].get("kunai", 0), "/", pr["inventory"].get("salve", 0), "/", pr["inventory"].get("pill", 0))
	_shot("bar_1_baslangic")
	# alet değiştir, hap stoğu ver, bekleme başlat
	pr["inventory"]["shuriken"] = 7
	pr["inventory"]["pill"] = 2
	pr["inventory"]["salve"] = 0
	pr["throw_sel"] = "shuriken"
	if Game.player and Game.player.combat:
		Game.player.combat.tool_cd["shuriken"] = 3.0
		Game.player.chakra = 3.0   # bedel rozeti kırmızı olmalı
	await get_tree().create_timer(0.5).timeout
	_shot("bar_2_bekleme")
	# Akimichi: hap değiştirme rozeti
	pr["clan"] = "akimichi"
	pr["pill_sel"] = "hap_horenzai"
	await get_tree().create_timer(0.5).timeout
	_shot("bar_3_akimichi")
	# jutsu yuvaları: bedel rozeti (chakra mavi, taijutsu yeşil, yetmeyen kırmızı)
	pr["slots"] = ["katon_goukakyuu", "suiton_suikoudan", "raiton_chidori", "nikudan", "gatsuga", "", "", "", ""]
	Game.player.chakra = Game.player.max_chakra
	Game.player.stamina = 4.0
	await get_tree().create_timer(0.5).timeout
	_shot("bar_4_jutsu")
	# bekleme bitiş parlaması + bekleme dairesi (yarıda)
	Game.player.stamina = Game.player.max_stamina
	Game.player.combat.cooldowns["katon_goukakyuu"] = 0.25
	Game.player.combat.cooldowns["suiton_suikoudan"] = 6.0
	Game.player.combat.cd_max["suiton_suikoudan"] = 12.0
	await get_tree().create_timer(0.38).timeout
	_shot("bar_5_parlama")
	get_tree().quit()
