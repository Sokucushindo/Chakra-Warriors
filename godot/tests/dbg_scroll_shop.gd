extends Node
## Parşömenci: doğana uygun tüm genel element jutsuları (parşömeni olmayan eğitmen teknikleri dahil), rütbe şartı, satın alma
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.45, 0.12), "pants": Color(0.15, 0.15, 0.17), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.45, 0.8)}
	main._start_new_game()
	await get_tree().create_timer(2.0).timeout
	var pr = Game.profile
	print("SCROLL natures=%s learned=%s" % [pr.get("elements"), pr["learned"]])
	for lr in [[1, 1], [6, 1], [10, 2], [18, 3], [30, 3]]:
		pr["level"] = lr[0]
		pr["rank"] = lr[1]
		var sc = Progress.scroll_shop_items(999)
		print("SCROLL katon P%d r%d n=%d %s" % [lr[0], lr[1], sc.size(), sc.map(func(i): return Data.items[i]["jutsu"])])
	pr["level"] = 10
	pr["rank"] = 2
	pr["ryo"] = 99999
	var sc2 = Progress.scroll_shop_items(999)
	var auto = sc2.filter(func(i): return Data.items[i].has("_auto"))
	print("SCROLL auto item sample=%s" % [Data.items[auto[0]]])
	Hud.shop("Parşömenci — Element Jutsuları", sc2)
	await get_tree().create_timer(0.5).timeout
	var before = pr["learned"].size()
	Hud._buy(auto[0], "Parşömenci — Element Jutsuları", sc2)
	print("SCROLL bought %s learned %d->%d ryo=%d" % [Data.items[auto[0]]["jutsu"], before, pr["learned"].size(), int(pr["ryo"])])
	print("SCROLL after-buy n=%d" % Progress.scroll_shop_items(999).size())
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://../_tmp/scroll_shop.png")
	get_tree().quit()
