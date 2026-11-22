extends Node
## Bijūgan kaldırıldı mı: eski kayıttaki kapsül + seçili alet temizleniyor mu, düşman alet listesinde var mı
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	var p = {"inventory": {"bijugan": 3, "kunai": 5}, "throw_sel": "bijugan", "seed": 1, "story": 0}
	Journal.migrate(p)
	print("BIJU inventory=%s throw_sel=%s" % [str(p["inventory"]), String(p["throw_sel"])])
	var src = FileAccess.get_file_as_string("res://scripts/combat/fx/alet_kit.gd") + FileAccess.get_file_as_string("res://scripts/core/main.gd") + FileAccess.get_file_as_string("res://scripts/core/missions.gd")
	print("BIJU kaynakta_gecis=%d" % src.count("\"bijugan\""))
	print("BIJU RESULT %s" % ("OK" if not p["inventory"].has("bijugan") and p["throw_sel"] == "kunai" and src.count("\"bijugan\"") == 0 else "FAIL"))
	get_tree().quit()
