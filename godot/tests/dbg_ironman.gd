extends Node
## Ironman: çocuğu olan ölünce çocuğa geçer; mirasçı kalmayınca kayıt silinir, ana menüye dönülür. Ayrıca tanışma rütbesi.
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 96, "name": "Demir", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult", "ironman": true}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pr = Game.profile
	print("IM mod=", pr.get("ironman"))
	await _w(10.0)
	Kin.ensure()
	# tanışma rütbesi: üniformaya göre
	var cnt = {}
	for v in get_tree().get_nodes_in_group("talkers"):
		if v is Villager and String(v.oarch) in ["genin", "chunin", "jonin"]:
			var k = "%s>%d" % [v.oarch, Friends._rank_of(v, String(v.look.get("age", "adult")))]
			cnt[k] = int(cnt.get(k, 0)) + 1
	print("IM rütbe ", cnt)
	pr["kd_wait"] = 99999.0
	var now = Time.get_unix_time_from_system()
	pr["children"] = [{"name": "Demir Ren", "gender": "m", "clans": [], "born": now - 90000.0, "tr": {"shuriken": 6.0, "taijutsu": 5.0, "chakra": 4.0}}]
	for k in pr["children"]:
		KidLife.ensure(k)
	Friends.inst().graduation()
	Hud.close_dialog()
	print("IM çocuklar ", pr["children"].map(func(k): return [k.get("grad"), k.get("born")]))
	print("IM mirasçı=", Legacy.heir(), " ad=", pr["name"])
	Game.save_game()
	for round in 3:
		if Game.player == null:
			break
		Progress.on_player_died()
		var t := 0.0
		while t < 25.0 and (DeathScene.cur != null and is_instance_valid(DeathScene.cur)):
			await _w(0.5)
			t += 0.5
		await _w(1.0)
		print("IM ölüm ", round, " süre=", t, " ad=", Game.profile.get("name", "-"), " ironman=", Game.profile.get("ironman", "-"), " mirasçı=", Legacy.heir() if not Game.profile.is_empty() else "-", " kayıt=", FileAccess.file_exists(Game.save_path(96)), " mod=", main.mode, " oyuncu=", Game.player != null)
		if Game.profile.is_empty():
			break
	await _w(1.0)
	get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/im_menu.png")
	get_tree().quit()
