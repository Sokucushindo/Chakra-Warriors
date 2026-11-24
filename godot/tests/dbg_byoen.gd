extends Node
## Byōen Hōka: insan hâlinde engellenir mi; İki Kuyruk tam dönüşümde canavarın ağzından dev ateş topu (geniş kamera)
var main: Node
var pl

func _process(_dt: float) -> void:
	if pl:
		pl.chakra = pl.max_chakra
		pl.hp = pl.max_hp

func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "f", "clan": "none", "village": "kumo", "element": "katon", "hair_style": "uzun", "hair": Color(0.85, 0.8, 0.5), "top": Color(0.3, 0.3, 0.35), "pants": Color(0.1, 0.1, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	await get_tree().create_timer(1.5).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	pl = main.player
	var at = Missions.open_ground(pl.global_position + Vector3(0, 0, 700.0), 120.0)
	at.y = Game.ground_height(at.x, at.z) + 0.3
	pl.respawn(at)
	await get_tree().create_timer(0.8).timeout
	Game.profile["learned"] = Game.profile.get("learned", []) + ["byoen_hoka"]
	TailedBeasts.make_jinchuriki("matatabi")
	TailedBeasts.beasts()["matatabi"]["trust"] = 100.0
	# 1) insan hâlinde (kaftansız): engellenmeli
	pl.combat.cooldowns.clear()
	pl.combat.begin_cast("byoen_hoka")
	await get_tree().create_timer(0.3).timeout
	print("BYOEN insan_hali_atis=%s" % str(pl.combat.action == "cast"))
	pl.combat.action = ""
	# 2) tam dönüşüm
	var cl: BeastCloak = pl.combat.modes.cloak
	cl.set_level(6)
	await get_tree().create_timer(1.8).timeout
	var h = cl.rig.height_m
	var f = pl.face_dir()
	var e = Enemy.new()
	var a = Enemy.archetype("kumo", 0)
	a["respawn"] = false
	e.setup(a)
	get_tree().current_scene.add_child(e)
	e.global_position = Missions.open_ground(pl.global_position + f * 55.0, 20.0)
	e.max_hp = 999999.0
	e.hp = 999999.0
	e.attack_cd = 999.0
	pl.combat.lock_target = e
	var cam = Camera3D.new()
	get_tree().current_scene.add_child(cam)
	cam.far = 4000.0
	cam.fov = 60.0
	var r = f.cross(Vector3.UP).normalized()
	cam.global_position = pl.global_position + f * 28.0 + r * h * 1.6 + Vector3.UP * h * 0.6
	cam.look_at(pl.global_position + f * 30.0 + Vector3.UP * h * 0.35)
	cam.current = true
	var hp0 = e.hp
	Jutsu.execute(pl, "byoen_hoka", e)
	var t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../_tmp/byoen"))
	var i = 0
	for tt in [0.15, 0.45, 0.8, 1.2, 1.7, 2.4]:
		while (Time.get_ticks_msec() - t0) / 1000.0 < tt:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2)
		im.save_png("res://../_tmp/byoen/b_%d.png" % i)
		i += 1
	print("BYOEN hasar=%.0f boy=%.1f" % [hp0 - e.hp, h])
	get_tree().quit()
