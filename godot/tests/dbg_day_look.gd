extends Node
## Gündüz / akşam görünüş karşılaştırması: aynı yerde iki saat, gölge koyuluğu ölçümü için görüntü
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var best = pl.global_position
	var bd = 1e9
	for ix in range(-40, 41):
		for iz in range(-40, 41):
			var q = pl.global_position + Vector3(ix * 4.0, 0, iz * 4.0)
			if Game.road_at(q.x, q.z, "street") > 0.9 and Vector2(ix, iz).length() < bd and Vector2(ix, iz).length() > 6.0:
				bd = Vector2(ix, iz).length()
				best = q
	pl.respawn(Vector3(best.x, Game.terrain_height(best.x, best.z) + 1.0, best.z))
	await _w(3.0)
	var env = Game.world.env
	var tag = OS.get_environment("TAG")
	for t in [0.42, 0.5, 0.6, 0.72]:
		env.time_of_day = t
		env.weather = "açık"
		env.overcast = 0.0
		Game.paused = false
		await _w(2.5)
		env.time_of_day = t
		await _w(0.3)
		print("DAY t=", t, " güneş=", env.sun.light_energy, " ortam=", env.env.ambient_light_energy, " renk=", env.env.ambient_light_color, " poz=", env.env.tonemap_exposure, " gölge=", env.sun.shadow_enabled)
		get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/day_%s_%d.png" % [tag, int(t * 100)])
	get_tree().quit()
