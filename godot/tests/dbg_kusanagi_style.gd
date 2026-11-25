extends Node
## Kusanagi dövüş tarzı denetimi: her adım birkaç anda DONDURULUR (play_keys hız 0) ve iki açıdan çekilir
## (A: silah tarafından ön-çapraz, B: sol yandan profil). Her karede kılıç ekseni / keskin ağız yönü (karakter çerçevesi)
## ve ağızın gövdeye girip girmediği (kemik kapsüllerine en yakın uzaklık) yazılır. Sonra gerçek kombo oynatılır,
## bitişte kılıcın elde bekleme yönüne (kimlik) döndüğü ölçülür.
var main: Node
const KA = preload("res://scripts/combat/kusanagi_anim.gd")

const TIMES := [[0.1, 0.2, 0.24, 0.34], [0.12, 0.2, 0.26], [0.2, 0.32, 0.45], [0.26, 0.38, 0.42, 0.5], [0.3, 0.6, 0.7, 0.85], [0.3, 0.44, 0.74, 0.92]]
# gövde kapsülleri: [kemik a, kemik b, yarıçap]
const BODY := [["Hips", "Spine", 0.15], ["Spine", "Chest", 0.15], ["Chest", "Neck", 0.14], ["Neck", "Head", 0.08],
	["LeftUpperLeg", "LeftLowerLeg", 0.08], ["RightUpperLeg", "RightLowerLeg", 0.08], ["LeftLowerLeg", "LeftFoot", 0.06], ["RightLowerLeg", "RightFoot", 0.06],
	["LeftUpperArm", "LeftLowerArm", 0.05], ["LeftLowerArm", "LeftHand", 0.045]]


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "raiton", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.14), "top": Color(0.85, 0.85, 0.88), "pants": Color(0.15, 0.15, 0.25), "skin": Color(0.96, 0.82, 0.7), "eye": Color(0.15, 0.15, 0.15)}
	main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	var pl = main.player
	var v = Game.village("suna")
	pl.respawn(Game.from_map(Vector2(v["x"], v["y"] + float(v["r"]) + 500)))
	await _w(2.0)
	Game.profile["level"] = 40
	Game.profile["rank"] = 4
	Gear.grant(Game.profile, "kusanagi", "sag")
	Game.profile["weapon_drawn"] = true
	Gear.apply_look(Game.profile)
	pl.rebuild_model()
	pl.model.set_drawn(true, false)
	await _w(4.0)
	for mm in get_tree().current_scene.find_children("*", "MultiMeshInstance3D", true, false):
		if mm.get_script() == null:
			mm.visible = false
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 34
	cam.near = 0.02
	cam.current = true
	_orient(pl, "idle")
	var only = OS.get_environment("PART")
	if only == "" or only == "freeze":
		await _freeze(pl, cam)
	if only == "" or only == "live":
		await _live(pl, cam)
	get_tree().quit()


func _frame(pl) -> Array:
	var fd: Vector3 = pl.model.skel.global_transform.basis.z
	fd.y = 0
	fd = fd.normalized()
	var rt = fd.cross(Vector3.UP).normalized()   # karakterin sağı
	return [fd, rt]


func _freeze(pl, cam: Camera3D) -> void:
	pl.set_physics_process(false)
	await _w(1.0)
	var st: Array = KA.steps()
	for k in 6:
		for t in TIMES[k]:
			pl.model.play("idle", 0.0)
			pl.model.overlay.play_keys(st[k], 0.0)
			pl.model.overlay.key_t = float(t)
			for f in 8:
				await get_tree().process_frame
			var fr = _frame(pl)
			var fd: Vector3 = fr[0]
			var rt: Vector3 = fr[1]
			var mid = pl.global_position + Vector3.UP * 1.0
			var tag = "s%d_%02d" % [k + 1, int(round(float(t) * 100))]
			_orient(pl, tag)
			_clip(pl, tag)
			for vw in [["A", fd * 3.3 + rt * 1.9 + Vector3.UP * 0.35], ["B", -rt * 3.6 + fd * 0.4 + Vector3.UP * 0.25]]:
				cam.global_position = mid + vw[1]
				cam.look_at(mid + fd * 0.3)
				await get_tree().process_frame
				await main.shot("kst_%s_%s" % [tag, vw[0]])
	pl.model.overlay.stop_keys()
	await _w(0.6)
	_orient(pl, "after_freeze(beklenen: düzeltilmemiş, on_start yok)")
	pl.set_physics_process(true)


func _live(pl, cam: Camera3D) -> void:
	# gerçek akış: 6 adım art arda (oyuncu kombo yolu = düşmanla ortak KeyedCombos)
	var st: Array = KA.steps()
	for k in 6:
		pl.combat.attack()
		var ln = float(st[k]["len"])
		for f in 2:
			await _w(ln * (0.35 if f == 0 else 0.3))
			var fr = _frame(pl)
			var mid = pl.global_position + Vector3.UP * 1.0
			cam.global_position = mid + fr[0] * 3.3 + fr[1] * 1.9 + Vector3.UP * 0.35
			cam.look_at(mid)
			_orient(pl, "live%d_%d" % [k + 1, f])
			await main.shot("kst_live_%d_%d" % [k + 1, f])
		await _w(ln * 0.2)
	await _w(1.6)
	_orient(pl, "after_combo")
	var fr2 = _frame(pl)
	var mid2 = pl.global_position + Vector3.UP * 1.0
	for vw in [["A", fr2[0] * 3.0 + fr2[1] * 1.6 + Vector3.UP * 0.3], ["B", -fr2[1] * 3.2 + Vector3.UP * 0.2], ["C", fr2[1] * 1.2 + fr2[0] * 0.9 + Vector3.UP * 0.1]]:
		cam.global_position = mid2 + vw[1]
		cam.look_at(mid2 if vw[0] != "C" else pl.model.weapons[0]["hand"].global_position)
		await _w(0.05)
		await main.shot("kst_after_%s" % vw[0])


## kılıç ekseni (+Z) ve keskin ağız (+Y) karakter çerçevesinde (ön / sağ / yukarı) + yerel basis
func _orient(pl, tag: String) -> void:
	var fr = _frame(pl)
	for w in pl.model.weapons:
		if w["side"] != "Right":
			continue
		var n: Node3D = w["node"]
		var gb = n.global_transform.basis.orthonormalized()
		var z = gb.z
		var y = gb.y
		var lb = n.transform.basis.orthonormalized()
		print("KS_ORI %s axis(f=%.2f r=%.2f u=%.2f) edge(f=%.2f r=%.2f u=%.2f) local_id_err=%.3f roll=%.0f" % [tag,
			z.dot(fr[0]), z.dot(fr[1]), z.y, y.dot(fr[0]), y.dot(fr[1]), y.y,
			(lb.x - Vector3.RIGHT).length() + (lb.y - Vector3.UP).length() + (lb.z - Vector3.BACK).length(), pl.model.overlay.key_roll])


## ağız noktalarının gövde kapsüllerine en yakın uzaklığı (negatif = içinde)
func _clip(pl, tag: String) -> void:
	var sk: Skeleton3D = pl.model.skel
	var n: Node3D = null
	for w in pl.model.weapons:
		if w["side"] == "Right":
			n = w["node"]
	if n == null:
		return
	var worst = 9.0
	var wname = ""
	for kz in 9:
		var p: Vector3 = n.to_global(Vector3(0, 0, 0.2 + kz * 0.105))
		for c in BODY:
			var ia = sk.find_bone(c[0])
			var ib = sk.find_bone(c[1])
			if ia < 0 or ib < 0:
				continue
			var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(ia).origin
			var b: Vector3 = sk.global_transform * sk.get_bone_global_pose(ib).origin
			var q = Geometry3D.get_closest_point_to_segment(p, a, b)
			var d = p.distance_to(q) - float(c[2])
			if d < worst:
				worst = d
				wname = "%s z=%.2f" % [c[0], 0.2 + kz * 0.105]
	print("KS_CLIP %s min=%.3f (%s)%s" % [tag, worst, wname, "  <-- GİRİYOR" if worst < 0.0 else ""])
