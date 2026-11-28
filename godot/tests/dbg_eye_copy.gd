extends Node
## Gardırop: "Diğer göze aktar" tuşu deseni öbür göze geçiriyor mu
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _btn(n: Node, txt: String) -> BaseButton:
	for c in n.find_children("*", "BaseButton", true, false):
		if c.is_visible_in_tree() and String(c.get("text")).strip_edges() == txt:
			return c
	return null
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "uchiha", "element": "katon", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pr = Game.profile
	Gear.grant(pr, "goz_mangekyo", "sag_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	Gear.grant(pr, "goz_mangekyo", "sol_goz", null, null, {"lvl": 3, "origin": "dogustan"})
	var a = Eyes.design_for(pr, "sag_goz")
	var b = Eyes.design_for(pr, "sol_goz")
	a["style"] = 3; a["col"] = [0.1, 0.7, 0.4]
	b["style"] = 9; b["col"] = [0.9, 0.05, 0.06]
	print("EC once sag=", a.get("style"), " sol=", b.get("style"))
	Menus._eq_slot = "sag_goz"
	Menus.ninja_menu(main, "eyes")
	await _w(1.0)
	print("EC yuva=", Menus._eq_slot)
	var bt = _btn(get_tree().root, "Diğer göze aktar")
	if bt == null:
		bt = _btn(get_tree().root, "Copy to other eye")
	print("EC tus bulundu=", bt != null, " kapali=", bt.disabled if bt else "?")
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/eye_copy0.png")
	if bt:
		bt.pressed.emit()
	await _w(0.5)
	print("EC sonra sag=", Eyes.design_for(pr, "sag_goz").get("style"), " sol=", Eyes.design_for(pr, "sol_goz").get("style"), " ileti=", Hud.msg_lbl.text)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/eye_copy1.png")
	print("bitti")
	get_tree().quit()
