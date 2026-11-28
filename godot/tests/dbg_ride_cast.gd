extends Node
## Kuyrukluya binmişken kendi tekniğini atma: gövde kafaya çıkıyor mu, canavar yerinde mi, teknik kafadan mı çıkıyor
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
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 700.0, float(v["y"]))) + Vector3(0, 1, 0))
	await _w(6.0)
	Game.world.env.time_of_day = 0.45
	var bc = null
	for ch in pl.find_children("*", "", true, false):
		if ch is BeastCloak:
			bc = ch
	pl.max_hp = 1e9; pl.hp = 1e9
	pl.max_chakra = 1e9; pl.chakra = 1e9
	var jid = OS.get_environment("JID")
	if not jid in Game.profile["learned"]:
		Game.profile["learned"].append(jid)
	bc.ride_id = "kurama"
	bc.ride_life = 90.0
	bc.set_level(6)
	await _w(3.0)
	var g0: Vector3 = pl.global_position
	var r0: Vector3 = bc.rig.global_position
	print("RCAST önce gövde=", g0, " canavar=", r0, " görüntü=", pl.model.global_position)
	var h = float(bc.rig.get_meta("cam_h", 30.0))
	var fd: Vector3 = pl.face_dir()
	pl.cam_dist = float(OS.get_environment("CAMD")) if OS.get_environment("CAMD") != "" else 7.0
	pl.pitch = -22.0
	await _w(1.0)
	pl.combat.begin_cast(jid)
	print("RCAST başladı eylem=", pl.combat.action, " süre=", pl.combat.cast_time)
	var k = 0
	for i in 40:
		await _w(0.1)
		_top = bc.rig.head.global_transform * bc._ride_seat
		if i % 4 == 0:
			print("RCAST t=%.1f eylem=%s gövde-yukarı=%.1f canavar-kayma=%.2f görüntü-gövde=%.2f anim=%s ayak-kafa=%.2f" % [i * 0.1, pl.combat.action, pl.global_position.y - g0.y, bc.rig.global_position.distance_to(r0), pl.model.global_position.distance_to(pl.global_position), pl.model.current, _foot(pl) - (bc.rig.head.global_transform * bc._ride_seat).y])
		if i in [3, 8, 12, 16, 22, 36]:
			var mi: Vector3 = pl.model.get_global_transform_interpolated().origin
			var hi: Vector3 = bc.rig.head.get_global_transform_interpolated() * bc._ride_seat
			print("   çizim: görüntü-kafa fark=", (mi - hi).snapped(Vector3.ONE * 0.01))
			var fd2: Vector3 = pl.face_dir()
			var sd2: Vector3 = fd2.cross(Vector3.UP).normalized()
			var cam = Camera3D.new()
			main.add_child(cam)
			cam.far = 5000.0
			cam.fov = 9.0
			cam.global_position = mi + fd2 * 70.0 + sd2 * 70.0 + Vector3.UP * 6.0
			cam.look_at(mi + Vector3.UP * 0.5)
			cam.make_current()
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/rcast_%d.png" % k)
			k += 1
			cam.queue_free()
	print("RCAST sonra gövde=", pl.global_position, " fark=", pl.global_position.distance_to(g0))
	get_tree().quit()

func _foot(pl) -> float:
	var ov = pl.model.overlay
	ov.probe_bones = ["LeftFoot", "RightFoot", "Hips"]
	if not ov.probe.has("Hips"):
		return 0.0
	print("   son poz: solayak=%.2f sagayak=%.2f kalca=%.2f (kafa tepesine göre) grounded=%s w=%s" % [ov.probe["LeftFoot"].y - _top.y, ov.probe["RightFoot"].y - _top.y, ov.probe["Hips"].y - _top.y, pl.grounded, ov.weights])
	return minf(ov.probe["LeftFoot"].y, ov.probe["RightFoot"].y)
var _top := Vector3.ZERO
