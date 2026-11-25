extends Node
## Zemin örtüsü testi: eğimli / engebeli bir yerde yere serili efektler önce (örtü kapalı) ve sonra (açık) çekilir.
## Sahne A: Bakusui Shōha (gerçek döküm, 20 m su). Sahne B: farklı doğaların zemin izleri ızgarada.
## Sahne C: aynı anda 5 büyük alan, örtü kapalı / açık FPS. Çıktı: "DRP ..." satırları + SHOTS klasörüne kareler.
var main: Node
const GD = preload("res://scripts/combat/fx/lib/ground_drape.gd")
const SL = preload("res://scripts/combat/fx/lib/suiton_lib.gd")
const KL = preload("res://scripts/combat/fx/lib/katon_lib.gd")
const DL = preload("res://scripts/combat/fx/lib/doton_lib.gd")
const YL = preload("res://scripts/combat/fx/lib/yoton_lib.gd")
const RL = preload("res://scripts/combat/fx/lib/raiton_lib.gd")
const FL = preload("res://scripts/combat/fx/lib/futton_lib.gd")
const JL = preload("res://scripts/combat/fx/lib/jiton_lib.gd")
const SHL = preload("res://scripts/combat/fx/lib/shakuton_lib.gd")


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _rng(p: Vector3, r: float) -> float:
	var lo = INF
	var hi = -INF
	for gx in 7:
		for gz in 7:
			var h = Game.ground_height(p.x + (gx / 3.0 - 1.0) * r, p.z + (gz / 3.0 - 1.0) * r)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "suiton", "hair_style": "diken", "hair": Color(0.2, 0.3, 0.5), "top": Color(0.3, 0.3, 0.35),
		"bottom": Color(0.3, 0.3, 0.35), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	await main._start_new_game()
	var pl = main.player
	await _w(3.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	WorldDay.auto = false
	Game.world.env.time_of_day = 0.42
	pl.max_chakra = 99999.0
	pl.max_hp = 99999.0
	# eğimli yer: oyuncudan 300-2500 m halkalarda 20 m'lik alanda 2.5-7 m fark, su değil
	var base = pl.global_position
	var spot = Vector3.ZERO
	var best = 0.0
	for r in range(300, 2600, 100):
		for k in 24:
			var a = TAU * k / 24.0
			var q = base + Vector3(cos(a), 0, sin(a)) * r
			if Game.terrain_height(q.x, q.z) < 2.0:
				continue
			var g = _rng(q, 10.0)
			if g > 4.0 and g < 9.0 and (spot == Vector3.ZERO or absf(g - 6.0) < absf(best - 6.0)):
				spot = q
				best = g
		if spot != Vector3.ZERO and absf(best - 6.0) < 0.8:
			break
	spot.y = Game.ground_height(spot.x, spot.z)
	# eğim yönü (aşağı): kamera yamaca yandan baksın
	var gx = Game.ground_height(spot.x + 3, spot.z) - Game.ground_height(spot.x - 3, spot.z)
	var gz = Game.ground_height(spot.x, spot.z + 3) - Game.ground_height(spot.x, spot.z - 3)
	var down = Vector3(-gx, 0, -gz).normalized() if Vector2(gx, gz).length() > 0.01 else Vector3.FORWARD
	var side = down.cross(Vector3.UP).normalized()
	print("DRP spot %s fark %.2f egim %.2f" % [spot, best, Vector2(gx, gz).length() / 6.0])
	pl.respawn(spot + Vector3.UP * 0.3 - down * 13.0)
	await _w(1.5)
	var cam = Camera3D.new()
	cam.fov = 55.0
	main.add_child(cam)
	var views = {"yan": spot + side * 22.0 + Vector3.UP * 3.0, "ust": spot - down * 20.0 + side * 6.0 + Vector3.UP * 13.0, "alt": spot + down * 22.0 + Vector3.UP * 2.5}
	var tags = ["once", "sonra"]
	for pass_i in 2:
		GD.enabled = pass_i == 1
		var tag = tags[pass_i]
		# --- Sahne A: gerçek döküm (Bakusui Shōha: 20 m su)
		pl.respawn(spot + Vector3.UP * 0.3)
		await _w(0.6)
		pl.chakra = pl.max_chakra
		pl.combat.cooldowns.clear()
		var keep = get_tree().current_scene.get_children()
		Jutsu.execute(pl, "hoshigaki_bakusui_shoha", null)
		await _w(2.2)
		pl.respawn(spot + Vector3.UP * 0.3 - down * 40.0)   # oyuncu kadrajdan çıksın
		if GD._mgr != null and is_instance_valid(GD._mgr):
			for it in GD._mgr._items:
				var m = it["mi"].get_ref()
				if m and is_instance_valid(m) and m.get_aabb().size.length() > 8.0:
					var t = m.global_transform
					print("DRP A buyuk %s aabb %s draped %s pending %s y-h0 %.2f" % [m.mesh, m.get_aabb().size, it["draped"], it["pending"], t.origin.y - GD.height(t.origin.x, t.origin.z)])
		await _w(0.2)
		for v in views:
			cam.global_position = views[v]
			cam.look_at(spot, Vector3.UP)
			cam.current = true
			await RenderingServer.frame_post_draw
			await main.shot("drape_bakusui_%s_%s" % [v, tag])
		cam.current = false
		pl.cam.current = true
		await _w(4.0)
		_clear(keep)
		await _w(0.5)
		if OS.get_environment("ONLYA") != "":
			continue
		# --- Sahne B: farklı doğaların zemin izleri (ızgara)
		keep = get_tree().current_scene.get_children()
		var cells = []
		for i in 3:
			for j in 3:
				cells.append(spot + side * (i - 1) * 7.0 + down * (j - 1) * 7.0)
		var g = func(p: Vector3) -> Vector3: return Game.jutsu_floor_at(p)
		SL.big_puddle(pl, cells[0], 3.0, 30.0, {"alpha": 0.72, "ripple": 0.22, "foam": 0.04, "lift": 0.06})
		KL.scorch(pl, cells[1], 3.0, 30.0)
		DL.crack(pl, cells[2], 3.0, 30.0)
		YL.lava_pool(pl, cells[3], 3.0, 30.0)
		RL.scorch(g.call(cells[4]), 3.0, RL.RAI, 30.0)
		DL.pit(pl, cells[5], 2.5, 30.0)
		FL.stain(pl, cells[6], 3.0, 30.0)
		JL.patch(pl, cells[7], 3.0, 0, 30.0)
		SHL.dry_patch(pl, cells[8], 3.0, 30.0)
		await _w(1.2)
		for v in views:
			cam.global_position = views[v]
			cam.look_at(spot, Vector3.UP)
			cam.current = true
			await RenderingServer.frame_post_draw
			await main.shot("drape_izler_%s_%s" % [v, tag])
		var nd = 0
		for it in (GD._mgr._items if GD._mgr != null and is_instance_valid(GD._mgr) else []):
			if it["draped"]:
				nd += 1
		print("DRP %s izlenen %d ortulen %d" % [tag, GD._mgr._items.size() if GD._mgr != null and is_instance_valid(GD._mgr) else 0, nd])
		cam.current = false
		pl.cam.current = true
		_clear(keep)
		await _w(0.5)
		# --- Sahne C: aynı anda 5 büyük alan, FPS
		keep = get_tree().current_scene.get_children()
		pl.respawn(spot + Vector3.UP * 0.3 - down * 14.0)
		await _w(1.0)
		var f0 = Engine.get_process_frames()
		var t0 = Time.get_ticks_msec()
		for k in 5:
			var p = spot + side * (k - 2) * 6.0
			SL.big_puddle(pl, p, 8.0, 3.0, {"alpha": 0.72, "ripple": 0.22, "foam": 0.04, "lift": 0.06})
			YL.lava_pool(pl, p + down * 6.0, 4.0, 3.0)
		await _w(0.6)
		var f1 = Engine.get_process_frames()
		var t1 = Time.get_ticks_msec()
		await _w(2.0)
		var f2 = Engine.get_process_frames()
		var t2 = Time.get_ticks_msec()
		print("DRP %s FPS acilis(0.6sn) %.1f  sonrasi %.1f" % [tag, (f1 - f0) * 1000.0 / maxf(1, t1 - t0), (f2 - f1) * 1000.0 / maxf(1, t2 - t1)])
		_clear(keep)
		await _w(0.6)
	print("DRP BITTI")
	get_tree().quit()


func _clear(keep: Array) -> void:
	for ch in get_tree().current_scene.get_children():
		if keep.has(ch) or ch.name == "GroundDrape" or ch == main.player:
			continue
		if ch is GeometryInstance3D or (ch.get_class() == "Node3D" and ch.get_script() == null):
			ch.queue_free()
