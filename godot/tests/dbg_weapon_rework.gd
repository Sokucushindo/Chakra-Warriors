extends Node
## Silah elden geçirme denetimi (Kusanagi, Hōmatsu Kiseru, Naitosōdo, Kurosawa, Kusari-fundo).
## SECT env: "mesh" (yalnız modeller, oyun açmadan), "hand" (elde yakın çekim + kombo kareleri), boş = ikisi.
## ONLY env: virgüllü silah listesi (hand bölümü), ör. ONLY=kurosawa,kusari_fundo
## Yeni Kusanagi / Kiseru modeli henüz CharacterModel'e bağlı değilse elde mesh test içinde değiştirilir (NEWSWAP=1, varsayılan).
var main: Node
const KM = preload("res://scripts/combat/fx/kusanagi_model.gd")
const KI = preload("res://scripts/combat/fx/kiseru_model.gd")
const KS = preload("res://scripts/combat/fx/kurosawa_fx.gd")


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _new_mesh(id: String) -> ArrayMesh:
	var b = MB.new()
	if id == "kusanagi":
		KM.build(b)
	elif id == "homatsu_kiseru":
		KI.build(b)
	else:
		return CharacterModel.weapon_mesh(id)
	return b.build(Props.toon())


func _ready() -> void:
	await get_tree().process_frame
	var sect = OS.get_environment("SECT")
	if sect == "" or sect == "mesh":
		await _meshes()
	if sect == "" or sect == "hand":
		await _hand()
	get_tree().quit()


# ------------------------------------------------------------------ yalnız modeller
func _meshes() -> void:
	Menus.clear()
	var base = Vector3(0, 3000, 0)
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.fov = 30
	cam.near = 0.01
	var sun = DirectionalLight3D.new()
	main.add_child(sun)
	sun.rotation_degrees = Vector3(-50, 30, 0)
	var list = [["kusanagi_old", CharacterModel.weapon_mesh("kusanagi")], ["kusanagi_new", _new_mesh("kusanagi")],
		["kiseru_old", CharacterModel.weapon_mesh("homatsu_kiseru")], ["kiseru_new", _new_mesh("homatsu_kiseru")],
		["naito", CharacterModel.weapon_mesh("naitosodo")], ["naito_uzun", CharacterModel.weapon_mesh("naitosodo_uzun")],
		["kurosawa", CharacterModel.weapon_mesh("kurosawa")], ["kurosawa_saya", _saya_with_blade()]]
	for it in list:
		var mi = MeshInstance3D.new()
		mi.mesh = it[1]
		main.add_child(mi)
		mi.global_position = base
		var ab: AABB = mi.mesh.get_aabb()
		print("WR_MESH %s aabb=%s" % [it[0], str(ab)])
		var c = ab.get_center()
		var r = maxf(ab.size.length() * 0.75, 0.25)
		# f: yassı yüz (X'ten), e: kenardan (Y), q: çapraz, h: kabza yakın
		var views = [["f", Vector3(1, 0.05, 0.0), c, r * 1.5], ["e", Vector3(0.05, 1, 0.0), c, r * 1.5], ["q", Vector3(1, 0.6, -0.5), c, r * 1.5],
			["h", Vector3(1, 0.35, 0.25), Vector3(0, 0, 0.05), 0.42]]
		for vw in views:
			cam.global_position = base + vw[2] + (vw[1] as Vector3).normalized() * float(vw[3])
			cam.look_at(base + vw[2], Vector3.UP if absf((vw[1] as Vector3).normalized().y) < 0.9 else Vector3.FORWARD)
			await get_tree().process_frame
			await get_tree().process_frame
			await main.shot("wr_m_%s_%s" % [it[0], vw[0]])
		mi.queue_free()


func _saya_with_blade() -> ArrayMesh:
	var b = MB.new()
	KS.build_saya(b)
	var k = MB.new()
	KS.build(k)
	b.add_mesh(k)
	return b.build(Props.toon())


# ------------------------------------------------------------------ elde
func _hand() -> void:
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "suiton", "hair_style": "diken", "hair": Color(0.3, 0.2, 0.12), "top": Color(0.2, 0.3, 0.6), "pants": Color(0.15, 0.15, 0.2), "skin": Color(0.96, 0.8, 0.66), "eye": Color(0.25, 0.25, 0.25)}
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
	var cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 28
	cam.near = 0.02
	var only = OS.get_environment("ONLY")
	var ids = ["kusanagi", "homatsu_kiseru", "naitosodo", "kurosawa", "kusari_fundo"] if only == "" else Array(only.split(",", false))
	for id in ids:
		Gear.grant(Game.profile, id, "sag")
		Game.profile["weapon_drawn"] = true
		Gear.apply_look(Game.profile)
		pl.rebuild_model()
		pl.model.set_drawn(true, false)
		await _w(4.0)
		for mm in get_tree().current_scene.find_children("*", "MultiMeshInstance3D", true, false):
			if not (mm.get_class() == "MultiMeshInstance3D" and mm.get_script() != null):
				mm.visible = false
		if OS.get_environment("NEWSWAP") != "0" and id in ["kusanagi", "homatsu_kiseru"]:
			for w in pl.model.weapons:
				if w["id"] == id and w["node"] is MeshInstance3D:
					(w["node"] as MeshInstance3D).mesh = _new_mesh(id)
					if id == "homatsu_kiseru":   # CharacterModel'e önerilen ip bağı (Dangle): eklemden sarkan kahve ip
						pl.model.dangle_strip("", Vector3(0.0, 0.0145, 0.032), Vector3(0.0, 1.0, 0.15), 0.13, 0.006, Color(0.42, 0.24, 0.12), 0.16, Vector3(1, 0, 0), 0.004, w["node"])
		cam.current = true
		var fd: Vector3 = pl.face_dir()
		var sd: Vector3 = fd.cross(Vector3.UP).normalized()
		var hp: Vector3 = pl.model.weapons[0]["hand"].global_position
		# bekleme duruşu: el yakın (4 açı) + tam boy (ön, yan)
		var views = [fd * 0.55 - sd * 0.2, -sd * 0.55 + fd * 0.1, fd * 0.35 - sd * 0.35 + Vector3.UP * 0.3, -fd * 0.35 - sd * 0.45]
		for k in 4:
			cam.global_position = hp + views[k]
			cam.look_at(hp)
			await _w(0.12)
			await main.shot("wr_h_%s_grip%d" % [id, k])
		var mid = pl.global_position + Vector3.UP * 1.0
		for vv in [["front", fd * 4.2 - sd * 1.2 + Vector3.UP * 0.4], ["side", -sd * 4.2 + Vector3.UP * 0.4]]:
			cam.global_position = mid + vv[1]
			cam.look_at(mid)
			await _w(0.1)
			await main.shot("wr_h_%s_%s" % [id, vv[0]])
		if id == "kurosawa":
			await _kurosawa(pl, cam, fd, sd)
		elif id == "katana":
			_orient(pl, "katana_idle")   # karşılaştırma: yalnız bekleme duruşu
		else:
			await _combo(pl, cam, fd, sd, id)


## kombo boyunca kareler (yan-ön açı, karakteri izler); kusari-fundo için zincir verisi yazılır
func _combo(pl, cam: Camera3D, fd: Vector3, sd: Vector3, id: String) -> void:
	for k in 6:
		pl.combat.attack()
		for f in 3:
			await _w(0.14)
			var mid = pl.global_position + Vector3.UP * 1.1
			cam.global_position = mid + fd * 3.0 - sd * 2.2 + Vector3.UP * 0.5
			cam.look_at(mid + fd * 0.8)
			if id == "kusari_fundo":
				_chain_dbg(pl, "%d_%d" % [k, f])
			if id == "kurosawa":
				_orient(pl, "k%d_%d" % [k, f])
			if f != 1:
				await main.shot("wr_c_%s_%d_%d" % [id, k, f])
			if f == 2 and k < 2 and id in ["homatsu_kiseru", "kusanagi", "naitosodo"]:   # yakın çekim (ağızlık / tutuş)
				var head: Vector3 = pl.model.weapons[0]["hand"].global_position
				var ff: Vector3 = pl.face_dir()
				cam.global_position = head + ff * 0.7 - ff.cross(Vector3.UP).normalized() * 0.45 + Vector3.UP * 0.1
				cam.look_at(head)
				await _w(0.02)
				await main.shot("wr_c_%s_%d_close" % [id, k])
		await _w(0.25)
	for t in 8:
		await _w(0.5)
		if id == "kurosawa":
			_orient(pl, "after%.1f" % (0.5 * (t + 1)))
	var mid2 = pl.global_position + Vector3.UP * 1.1
	cam.global_position = mid2 + fd * 3.0 - sd * 2.2 + Vector3.UP * 0.5
	cam.look_at(mid2)
	await _w(0.05)
	await main.shot("wr_c_%s_after" % id)


## sağ eldeki kılıcın ekseni (+Z) ve keskin ağız yönü (+Y) karakter çerçevesinde: ön / sağ / yukarı
func _orient(pl, tag: String) -> void:
	var fd: Vector3 = pl.face_dir()
	fd.y = 0.0
	fd = fd.normalized()
	var rt = fd.cross(Vector3.UP).normalized()
	for w in pl.model.weapons:
		var n: Node3D = w["node"]
		if w["side"] != "Right":
			continue
		var gb = n.global_transform.basis.orthonormalized()
		var z = gb.z
		var y = gb.y
		print("WR_ORI %s vis=%s inhand=%s axis(f=%.2f r=%.2f u=%.2f) edge(f=%.2f r=%.2f u=%.2f)" % [tag, n.is_visible_in_tree(), n.get_parent() == w["hand"],
			z.dot(fd), z.dot(rt), z.y, y.dot(fd), y.dot(rt), y.y])
		print("WR_LOC %s local=%s tok=%s" % [tag, str(n.transform.basis.orthonormalized()), str(pl.get_meta("kuro_tok", -1))])


func _chain_dbg(pl, tag: String) -> void:
	for w in pl.model.weapons:
		if w["side"] != "Right":
			continue
		var ch = (w["node"] as Node3D).get_meta("kf_chain", null)
		if ch == null or not is_instance_valid(ch):
			print("WR_CHAIN %s yok" % tag)
			return
		var a = ch.a
		var b = ch.b
		print("WR_CHAIN %s vis=%s intree=%s a=%s(%s) b=%s(%s) L=%.2f inst0=%s" % [tag, ch.visible, ch.is_visible_in_tree(),
			a.name if is_instance_valid(a) else "-", str(a.is_visible_in_tree()) if is_instance_valid(a) else "-",
			b.name if is_instance_valid(b) else "-", str(b.is_visible_in_tree()) if is_instance_valid(b) else "-",
			a.global_position.distance_to(b.global_position) if is_instance_valid(a) and is_instance_valid(b) else -1.0,
			str(ch.multimesh.get_instance_transform(0).origin) if ch.multimesh else "-"])


## Kurosawa: kında (çekilmemiş) iki açı + kombo sonu duruşu
func _kurosawa(pl, cam: Camera3D, fd: Vector3, sd: Vector3) -> void:
	_orient(pl, "idle")
	Game.profile["weapon_drawn"] = false
	pl.model.set_drawn(false, false)
	await _w(0.6)
	if OS.get_environment("NEWSWAP") != "0":   # kavisli kın henüz CharacterModel'e bağlı değilse burada takılır
		for w in pl.model.weapons:
			var h = w.get("sheath")
			if h == null:
				continue
			for ch in (h as Node3D).get_children():
				if ch is MeshInstance3D and ch != w["node"] and ch.name != "KuroKin":
					var mb = MB.new()
					KS.build_saya(mb)
					(ch as MeshInstance3D).mesh = mb.build(Props.toon())
					print("WR_KURO saya değişti: ", ch.name)
	var hip = pl.global_position + Vector3.UP * 0.95
	for vv in [["kin_side", -sd * 1.8 + fd * 0.3], ["kin_back", -fd * 1.6 - sd * 0.9 + Vector3.UP * 0.3], ["kin_top", Vector3.UP * 1.6 - sd * 0.4 + fd * 0.1]]:
		cam.global_position = hip + vv[1]
		cam.look_at(hip, Vector3.UP if vv[0] != "kin_top" else fd)
		await _w(0.12)
		await main.shot("wr_h_kurosawa_%s" % vv[0])
	Game.profile["weapon_drawn"] = true
	pl.model.set_drawn(true, false)
	await _w(0.5)
	await _combo(pl, cam, fd, sd, "kurosawa")
	var mid = pl.global_position + Vector3.UP * 1.1
	for vv in [["end_front", fd * 3.0 - sd * 0.8], ["end_side", -sd * 3.0], ["end_side2", sd * 3.0]]:
		cam.global_position = mid + vv[1]
		cam.look_at(mid)
		await _w(0.1)
		await main.shot("wr_c_kurosawa_%s" % vv[0])
	for w in pl.model.weapons:
		var n: Node3D = w["node"]
		print("WR_KURO node_vis=%s parent=%s basis=%s" % [n.visible, n.get_parent().name, str(n.transform.basis)])
