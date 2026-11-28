extends Node
## Ctrl (sıçrama): kısa basış ve basılı tutup şarj — eski davranış
var main: Node
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _key(down: bool) -> void:
	var e = InputEventAction.new()
	e.action = "leap"
	e.pressed = down
	Input.parse_input_event(e)
func _jump(hold: float, tag: String) -> void:
	var pl = main.player
	var p0: Vector3 = pl.global_position
	_key(true)
	await _w(hold * 0.5)
	var ck = pl.leap_charge
	if tag == "uzun":
		get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/ctrl_sarj.png")
	await _w(hold * 0.5)
	_key(false)
	var top := 0.0
	var k := 0
	var t := 0.0
	while t < 6.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		top = maxf(top, pl.global_position.y - p0.y)
		if k == 0 and t > 0.35:
			k = 1
			get_viewport().get_texture().get_image().save_png("D:/Naruto 3D Game/_tmp/ctrl_%s.png" % tag)
		if t > 0.6 and pl.grounded:
			break
	var d = Vector2(pl.global_position.x - p0.x, pl.global_position.z - p0.z).length()
	print("CTRL ", tag, ": basılı=", hold, " sn, şarj(yarıda)=", snappedf(ck, 0.01), " yükseklik=", snappedf(top, 0.1), " m, uzaklık=", snappedf(d, 0.1), " m, süre=", snappedf(t, 0.1))
func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 96, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	var pl = main.player
	pl.respawn(Missions.open_ground(pl.global_position + Vector3(0, 0, 400), 40.0))
	await _w(3.0)
	await _jump(0.06, "kisa")
	await _w(1.5)
	await _jump(0.5, "orta")
	await _w(1.5)
	await _jump(1.6, "uzun")
	await _w(1.0)
	Game.delete_slot(96)
	Game.profile = {}
	get_tree().quit()
