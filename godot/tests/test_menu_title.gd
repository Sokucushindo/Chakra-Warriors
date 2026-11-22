extends Node
## Ana menü başlığı görüntüsü (_tmp/kanal/menu_<dil>.png).
var main: Node


func _ready() -> void:
	for lang in ["en", "tr"]:
		Lang.apply(lang)
		main.to_main_menu()
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../_tmp/kanal/menu_%s.png" % lang)
		print("SHOT ", lang)
	get_tree().quit()
