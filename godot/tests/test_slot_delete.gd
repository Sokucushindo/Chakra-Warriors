extends Node
## Kayıt silme: gerçek yuvalara dokunmaz (yuva 9 geçici dosyayla denenir); arayüz yalnız görüntülenir, onay basılmaz
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	var p = Game.save_path(9)
	var f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"name\": \"Deneme\"}")
	f = null
	print("SLOTDEL once=", FileAccess.file_exists(p))
	Game.delete_slot(9)
	print("SLOTDEL sonra=", FileAccess.file_exists(p))
	main.to_main_menu()
	await get_tree().create_timer(1.0).timeout
	Menus.slot_select(main, false)
	await get_tree().create_timer(0.8).timeout
	await main.shot("k_yuvalar")
	var who = Game.slot_summary(1).split("(")[0].strip_edges()
	if who != "":
		Menus._slot_delete_ask(main, false, 1, who)
		await get_tree().create_timer(0.8).timeout
		await main.shot("k_onay")
	Menus.settings(func(): Menus.main_menu(main))
	await get_tree().create_timer(0.8).timeout
	await main.shot("k_ayarlar")
	get_tree().quit()
