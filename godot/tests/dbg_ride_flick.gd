extends Node
## Kuyrukluya binişte karakter titriyor mu: her karenin sonunda görünürlük + kafadaki yerinden sapma ölçülür
var main: Node
var pl
var bc
var log := []
var on := false
func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout
func _process(_dt: float) -> void:
	if not on or not is_instance_valid(bc.rig) or bc.rig.head == null:
		return
	var top: Vector3 = bc.rig.head.get_global_transform_interpolated() * bc._ride_seat
	var m = pl.model
	var tr := 0.0
	var hid := 0
	var n := 0
	for mi in m.find_children("*", "GeometryInstance3D", true, false):
		n += 1
		if not mi.is_visible_in_tree():
			hid += 1
		tr = maxf(tr, mi.transparency)
	log.append([m.visible, m.is_visible_in_tree(), snappedf(m.get_global_transform_interpolated().origin.distance_to(top), 0.01), String(m.current), hid, n, snappedf(tr, 0.01), snappedf(m.scale.x, 0.01)])
func _ready() -> void:
	process_priority = 100000
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.9, 0.4, 0.1), "bottom": Color(0.1, 0.15, 0.3), "skin": Color(0.9, 0.75, 0.6), "eye": Color(0.2, 0.2, 0.2), "village": "konoha", "age": "adult"}
	main._start_new_game()
	await _w(6.0)
	while main.loading != null:
		await _w(0.5)
	Hud.close_dialog()
	pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(float(v["x"]) + float(v["r"]) + 700.0, float(v["y"]))) + Vector3(0, 1, 0))
	await _w(6.0)
	for ch in pl.find_children("*", "", true, false):
		if ch is BeastCloak:
			bc = ch
	pl.max_hp = 1e9; pl.hp = 1e9
	for id in OS.get_environment("IDS").split(","):
		pl.max_chakra = 1e9; pl.chakra = 1e9
		bc.ride_id = String(id)
		bc.ride_life = 60.0
		bc.set_level(6)
		await _w(2.5)
		for ph in ["dur", "yürü", "koş+zıpla", "saldır"]:
			log.clear()
			on = true
			if ph != "dur":
				Input.action_press("forward")
			if ph == "koş+zıpla":
				Input.action_press("dash")
				Input.action_press("jump")
			if ph == "saldır":
				Input.action_press("attack")
			await _w(0.3)
			Input.action_release("jump")
			Input.action_release("attack")
			await _w(1.7)
			on = false
			for a in ["forward", "dash"]:
				Input.action_release(a)
			var kinds := {}
			var flips := 0
			var prev = null
			var maxd := 0.0
			for r in log:
				var key = str([r[0], r[1], r[3], r[4], r[6], r[7]])
				kinds[key] = int(kinds.get(key, 0)) + 1
				if prev != null and key != prev:
					flips += 1
				prev = key
				maxd = maxf(maxd, r[2])
			print("FLICK %s %s kare=%d değişim=%d en_sapma=%.2f durumlar=%s" % [id, ph, log.size(), flips, maxd, kinds])
		bc.ride_end(false)
		await _w(1.6)
	get_tree().quit()
