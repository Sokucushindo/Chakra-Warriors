extends Node
## Kum kaplaması yetim kalmasın: düşman oyuncuya kum tekniği atar, hemen silinir; 30 sn sonra oyuncu bedeninde kum kaplaması sayılır
var main: Node
func _count(pl) -> int:
	var n = 0
	for mi in pl.model.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay != null and mi.material_overlay.has_meta("sand_coat"):
			n += 1
	return n
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 95, "name": "T", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	var pl = main.player
	await get_tree().create_timer(2.0).timeout
	Hud.close_dialog()
	pl.max_hp = 9999999.0; pl.hp = pl.max_hp
	var cands = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and int(q["rank"]) >= 1)
	for jid in ["sabaku_kyu", "gokusa_maiso", "sabaku_sotaiso_fuin", "sabaku_soso"]:
		var a = WorldPeople.arch_of(cands[0]); a["respawn"] = false; a["jutsu"] = []
		var e = Enemy.new(); e.setup(a)
		get_tree().current_scene.add_child(e)
		e.global_position = pl.global_position + Vector3(0, 0, -6)
		await get_tree().create_timer(0.4).timeout
		Jutsu.execute(e, jid, pl)
		await get_tree().create_timer(0.8).timeout
		print("SCO %s kaplama_sonra_0.8sn=%d" % [jid, _count(pl)])
		e.queue_free()
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(30.0).timeout
	print("SCO 30sn_sonra kalan=%d" % _count(pl))
	get_tree().quit()
