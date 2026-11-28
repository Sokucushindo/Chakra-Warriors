extends Node
## Dövüş duruşu gerçek akışta: düşman hedef alınca oyuncu ve düşman duruşa geçiyor mu; hareket ediyor mu (kalça / el yer değişimi)
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var v = Game.village("konoha")
	var c0 = Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 262.0, float(v["y"]) + 300.0))
	pl.respawn(Vector3(c0.x, Game.terrain_height(c0.x, c0.z) + 1.0, c0.z))
	await _w(4.0)
	print("FS2 önce oyuncu savaş=", pl.model.fight_on, " ağırlık=", pl.model.overlay.weights.get("fstance", 0.0))
	var e = Enemy.new()
	var a = Enemy.archetype("rogue", 0)
	a["hp"] = 99999.0
	a["clan"] = "hyuga"
	a["level"] = 40
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = pl.global_position + pl.face_dir() * 7.0
	e.home = e.global_position
	e.target = pl
	e.state = "guard"
	e.set_physics_process(true)
	await _w(1.0)
	pl.fight_until = Game.now() + 30.0
	var sk: Skeleton3D = pl.model.skeleton if pl.model.get("skeleton") != null else null
	var hb = sk.find_bone("Hips") if sk else -1
	var lo := 9.0
	var hi := -9.0
	for i in 40:
		await _w(0.05)
		if hb >= 0:
			var y = sk.get_bone_global_pose(hb).origin.y
			lo = minf(lo, y); hi = maxf(hi, y)
	print("FS2 oyuncu savaş=", pl.model.fight_on, " tarz=", pl.model.fstyle, " ağırlık=", snappedf(pl.model.overlay.weights.get("fstance", 0.0), 0.01), " anim=", pl.model.current, " kalça oynama cm=", snappedf((hi - lo) * 100.0, 0.1))
	print("FS2 düşman savaş=", e.model.fight_on, " tarz=", e.model.fstyle, " ağırlık=", snappedf(e.model.overlay.weights.get("fstance", 0.0), 0.01), " anim=", e.model.current, " durum=", e.state, " silah=", e.look.get("weapon_r"))
	get_tree().quit()
