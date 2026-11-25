extends Node
## Dükkâna eşya satma: kopya biriktir, envanter + satış ekranları (görüntü), sat (Ryō önce/sonra), yasak satışlar (neden), kayıt-yükle.
## Kullanım: --test=res://tests/dbg_sell_items.gd --shots=<dizin>   (test yuvası 96; kullanıcı kayıtlarına dokunmaz)
var main: Node
const SELL := preload("res://scripts/core/shop_sell.gd")
const SLOT := 96


func _out(s: String) -> void:
	print("SELL ", s)


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _gear_n(pr: Dictionary, id: String) -> int:
	var n := 0
	for g in pr.get("gear", []):
		if String(g.get("id", "")) == id:
			n += 1
	return n


func _counts(pr: Dictionary) -> String:
	var inv: Dictionary = pr["inventory"]
	return "ryo=%d set_genin=%d tonfa=%d kama=%d kitsune_maske=%d salve=%s zoketsugan=%s herb=%s kunai=%s" % [int(pr["ryo"]), _gear_n(pr, "set_genin"), _gear_n(pr, "tonfa"),
		_gear_n(pr, "kama"), _gear_n(pr, "kitsune_maske"), str(int(inv.get("salve", -1))), str(int(inv.get("zoketsugan", -1))), str(int(inv.get("herb", -1))), str(int(inv.get("kunai", -1)))]


func _find_entry(buyer: String, id: String) -> Dictionary:
	for e in SELL.entries(Game.profile, buyer):
		if e["id"] == id:
			return e
	return {}


## Satış ekranındaki "Sat — N Ryō" düğmesine bas (gerçek arayüz akışı)
func _press_sell() -> bool:
	for b in Hud.dialog_layer.find_children("*", "Button", true, false):
		if String(b.text).begins_with("Sat —") or String(b.text).begins_with("Sell —"):
			b.pressed.emit()
			return true
	return false


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": SLOT, "name": "Test", "gender": "m", "clan": "hatake", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.85, 0.9), "top": Color(0.2, 0.25, 0.3),
		"bottom": Color(0.2, 0.25, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.2, 0.2)}
	main._start_new_game()
	await _w(3.0)
	await _w(8.0)   # yeni oyun yükleme ekranı kalksın
	Hud.close_dialog()
	var pr: Dictionary = Game.profile
	pr["ryo"] = 1000
	# kopya biriktir
	for i in 3:
		Gear.grant(pr, "set_genin")
	for i in 2:
		Gear.grant(pr, "tonfa")
		Gear.grant(pr, "kitsune_maske")
	Gear.grant(pr, "kama", "sag")   # takılı tek kopya
	Gear.grant(pr, "samehada")
	Gear.grant(pr, "set_kage")
	pr["inventory"]["salve"] = 6
	pr["inventory"]["zoketsugan"] = 3
	pr["inventory"]["herb"] = 2
	pr["inventory"]["kunai"] = 1
	_out("START " + _counts(pr) + " equipped_set=%s" % String(Gear.equipped(pr, "set").get("id", "-")))
	Menus._inv_filter = "all"
	Menus.ninja_menu(main, "inv")
	await _w(1.0)
	await main.shot("1_inventory")
	Menus.clear()
	# dükkânlar: alış ekranı (Eşya sat düğmesi) + satış ekranı
	Hud.gear_shop("Terzi", Gear.shop_stock("c", "konoha"))
	await _w(0.8)
	await main.shot("2_tailor_buy")
	Menus._sell_sel = "gear:set_genin"
	Menus.sell_screen("Terzi", "cloth", func(): Hud.gear_shop("Terzi", Gear.shop_stock("c", "konoha")))
	await _w(0.8)
	Menus._sell_qty = 2
	Menus.sell_screen("Terzi", "cloth", func(): Hud.gear_shop("Terzi", Gear.shop_stock("c", "konoha")))
	await _w(0.6)
	await main.shot("3_tailor_sell")
	var r0 = int(pr["ryo"])
	var e = _find_entry("cloth", "set_genin")
	_out("TAILOR set_genin entry count=%d owned=%d eq=%d price=%d reason='%s'" % [int(e.get("count", 0)), int(e.get("owned", 0)), int(e.get("equipped", 0)), int(e.get("price", 0)), String(e.get("reason", ""))])
	var pressed = _press_sell()
	await _w(0.5)
	_out("TAILOR sold 2 via UI pressed=%s ryo %d -> %d (+%d)  %s" % [pressed, r0, int(pr["ryo"]), int(pr["ryo"]) - r0, _counts(pr)])
	await main.shot("4_tailor_after")
	# silahçı
	Menus._sell_sel = "gear:tonfa"
	Menus._sell_qty = 1
	Menus.sell_screen("Silahçı", "weapon", func(): pass)
	await _w(0.8)
	await main.shot("5_weapon_sell")
	r0 = int(pr["ryo"])
	_press_sell()
	await _w(0.3)
	_out("WEAPON sold tonfa x1 ryo %d -> %d  %s" % [r0, int(pr["ryo"]), _counts(pr)])
	# eczane
	Menus._sell_sel = "item:salve"
	Menus._sell_qty = 4
	Menus.sell_screen("Eczane", "general", func(): Hud.shop("Eczane", ["salve", "zoketsugan", "smoke"]))
	await _w(0.8)
	await main.shot("6_pharmacy_sell")
	r0 = int(pr["ryo"])
	_press_sell()
	await _w(0.3)
	_out("PHARMACY sold salve x4 ryo %d -> %d  %s" % [r0, int(pr["ryo"]), _counts(pr)])
	# kara pazar: her şeyi alır, ucuza
	Menus._sell_sel = "gear:kitsune_maske"
	Menus._sell_qty = 1
	Menus.sell_screen("Kara Silahçı", "black", func(): pass)
	await _w(0.8)
	await main.shot("7_black_sell")
	var en = _find_entry("cloth", "kitsune_maske")
	var eb = _find_entry("black", "kitsune_maske")
	_out("PRICE kitsune_maske buy=%d tailor=%d black=%d" % [int(Gear.item("kitsune_maske").get("price", 0)), int(en.get("price", 0)), int(eb.get("price", 0))])
	# yasak satışlar
	for bt in [["black", "kama"], ["black", "samehada"], ["black", "hakko_chakura_to"], ["black", "set_kage"], ["black", "herb"], ["black", "kunai"], ["black", "pill"], ["general", "pill"]]:
		var x = _find_entry(bt[0], bt[1])
		var got = SELL.sell(pr, x, 1) if not x.is_empty() else 0
		_out("FORBID %s/%s listed=%s reason='%s' sell_gain=%d" % [bt[0], bt[1], str(not x.is_empty()), String(x.get("reason", "")), got])
	_out("CROSS tailor lists tonfa=%s weapon lists salve=%s pharmacy lists set_genin=%s scrollshop buyer='%s'" % [str(not _find_entry("cloth", "tonfa").is_empty()),
		str(not _find_entry("weapon", "salve").is_empty()), str(not _find_entry("general", "set_genin").is_empty()), SELL.buyer_of("Parşömenci — Element Jutsuları")])
	# fazla satma denemesi
	var ez = _find_entry("general", "zoketsugan")
	_out("OVERSELL zoketsugan ask 99 -> gain=%d left=%s" % [SELL.sell(pr, ez, 99), str(pr["inventory"].get("zoketsugan", "-"))])
	# İngilizce satış ekranı
	Lang.apply("en")
	await _w(0.3)
	Menus._sell_sel = "gear:set_genin"
	Menus.sell_screen("Terzi", "cloth", func(): pass)
	await _w(0.8)
	await main.shot("8_tailor_sell_en")
	Lang.apply("tr")
	Hud.close_dialog()
	# kayıt-yükle
	var before = _counts(pr)
	Game.save_game()
	Game.profile = {}
	var ok = Game.load_game(SLOT)
	_out("RELOAD ok=%s before: %s" % [ok, before])
	_out("RELOAD after : %s" % _counts(Game.profile))
	_out("RESULT match=%s" % str(before == _counts(Game.profile)))
	Game.delete_slot(SLOT)
	get_tree().quit()
