extends Node
## Yaratıcı: ayar değişince kamera o bölgeye yaklaşır (göz, kaş, ağız, yüz, saç, üst, alt)
var main: Node


func _ready() -> void:
	await get_tree().process_frame
	main.to_main_menu()
	await get_tree().create_timer(1.0).timeout
	Menus._ctab = "gorunum"
	Menus._cfocus = ""
	main.start_creator(3)
	await get_tree().create_timer(1.2).timeout
	await main.shot("f_genel")
	for k in ["eye_art", "face_brow", "face_mouth", "skin", "hair_style", "top", "pants"]:
		Menus._cfocus = k
		main._update_preview()
		await get_tree().create_timer(1.0).timeout
		var sk: Skeleton3D = main.preview.skel
		var hp = func(n): return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin).y
		print("FOCUS ", k, " head=", hp.call("Head"), " neck=", hp.call("Neck"), " hips=", hp.call("Hips"), " base=", main.preview.global_position.y, " cam=", main.menu_cam.global_position.y)
		await main.shot("f_" + k)
	get_tree().quit()
