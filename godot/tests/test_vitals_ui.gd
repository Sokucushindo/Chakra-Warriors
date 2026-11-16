extends Node
## Sol üst oyuncu çerçevesi (VitalsUI): senaryo görüntüleri _tmp/kv/vit_*.png
var main: Node


func _shot(name: String, full := false) -> void:
	var dir = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/_tmp/kv/"
	var img = get_viewport().get_texture().get_image()
	img.get_region(Rect2i(0, 0, 720, 280)).save_png(dir + name + ".png")
	var z = img.get_region(Rect2i(20, 20, 150, 170))
	z.resize(450, 510, Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + name + "_zoom.png")
	if full:
		var f = img.duplicate()
		f.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		f.save_png(dir + name + "_tam.png")


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Deneme", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12),
		"top": Color(0.15, 0.15, 0.17), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(3.0).timeout
	var pr: Dictionary = Game.profile
	var pl = Game.player
	pr["rank"] = 5
	pr["level"] = 100
	pr["ryo"] = 9999999
	print("vit=", Hud.vit, " size=", Hud.vit.size)
	await get_tree().create_timer(1.5).timeout
	_shot("vit_1_tam", true)
	# can %20: kırmızı + düşüş izi, chakra 0, stamina düşük
	pl.hp = pl.max_hp * 0.2
	pl.chakra = 0.0
	pl.stamina = pl.max_stamina * 0.4
	await get_tree().create_timer(0.25).timeout
	_shot("vit_2_dusuk_iz")
	await get_tree().create_timer(2.0).timeout
	_shot("vit_3_dusuk")
	# can %60 + Byakugō (klan kaynağı)
	pl.hp = pl.max_hp * 0.6
	pl.chakra = pl.max_chakra * 0.5
	pl.stamina = pl.max_stamina
	pr["clan"] = "senju"
	pr["byakugo"] = 70.0
	pr["learned"].append("byakugo_no_in")
	pr["rank"] = 2
	await get_tree().create_timer(1.5).timeout
	_shot("vit_4_klan")
	# uzun isim, İngilizce, Akimichi kalorisi
	pr["name"] = "Uzunisimli Shinobi Çağlayan"
	pr["clan"] = "akimichi"
	pr["rank"] = 0
	pr["ryo"] = 1250
	Lang.apply("en")
	await get_tree().create_timer(1.5).timeout
	_shot("vit_5_uzun_isim_en")
	# kawarimi hakları
	if pl.combat:
		pl.combat.sub_bars = 2
	pr["clan"] = "none"
	pr["name"] = "Aki"
	pr["rank"] = 1
	pr["level"] = 1
	pr["ryo"] = 150
	await get_tree().create_timer(1.0).timeout
	_shot("vit_6_haklar")
	get_tree().quit()
