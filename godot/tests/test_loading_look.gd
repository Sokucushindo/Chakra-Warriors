extends Node
## Yükleme ekranı: ilerleme %35 ve %80, ipucu değişimi
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main._show_loading()
	main._loading_progress(0.35, "Köyler")
	await get_tree().create_timer(1.0).timeout
	await main.shot("y_35")
	await get_tree().create_timer(7.5).timeout
	main._loading_progress(0.8, "Ninjalar giydiriliyor")
	await get_tree().create_timer(0.6).timeout
	await main.shot("y_80")
	get_tree().quit()
