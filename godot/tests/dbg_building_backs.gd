extends Node
## Özel binaların arka + yan cephe görüntüleri (önce / sonra karşılaştırması).
## SET=konoha | suna | kiri | kumo | iwa ; TAG=once|sonra ; ONLY=ad1,ad2 (yalnız bu binalar)
## Her bina: [ad, x, n, yarı genişlik, yarı derinlik, ön yön (derece; ön yüz normali (sin, cos)), bakış yüksekliği, uzaklık]
## Görüntüler: <shots>/<TAG>_<ad>_{arka,sol,sag}.png
var main: Node


func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	await get_tree().process_frame
	var set_list = Array((OS.get_environment("SET") if OS.get_environment("SET") != "" else "konoha").split(",", false))
	var tag = OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "once"
	var only = Array(OS.get_environment("ONLY").split(",", false))
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12), "eye": Color(0.2, 0.4, 0.9), "skin": Color(0.96, 0.8, 0.66)}
	await main._start_new_game()
	await _w(2.0)
	Hud.close_dialog()
	Hud.show_game_hud(false)
	main.world.env.time_of_day = 0.42
	WorldDay.auto = false
	var cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	get_tree().current_scene.add_child(cam)
	for set_id in set_list:
		await _shoot_set(set_id, tag, only, cam)
	print("BACKS done")
	get_tree().quit()


func _shoot_set(set_id: String, tag: String, only: Array, cam: Camera3D) -> void:
	var v = Game.village(set_id)
	var specs: Array = []
	if set_id == "konoha":
		var rock: Dictionary = v.get("hokage_rock", {})
		var cliff_n = float(rock.get("y", float(v["y"]) + 1170.0)) - float(v["y"])
		specs = [
			["akademi", -540.0, 610.0, 52.0, 19.0, 180.0, 10.0, 34.0],
			["kule_dogu", 72.0, 606.0, 30.0, 20.0, 180.0, 12.0, 22.0],
			["kule_arsiv", -72.0, 606.0, 22.0, 16.0, 180.0, 10.0, 20.0],
			["hastane", 557.0, 230.0, 62.0, 21.0, 180.0, 12.0, 40.0, 18.0],
			["anbu", -480.0, cliff_n - 102.0, 22.0, 14.0, 180.0, 10.0, 34.0],
			["polis", -860.0, -558.0, 14.0, 8.0, 0.0, 6.0, 18.0],
			["kutuphane", 168.0, 460.0, 12.0, 7.5, 180.0, 5.0, 14.0, 10.0],
			["han", 230.0, 24.0, 11.0, 7.0, 180.0, 6.0, 9.0, 15.0],
			["cayevi", 250.0, -23.0, 9.0, 7.0, 0.0, 5.0, 9.0, 13.0],
			["yakiniku", -110.0, 23.0, 10.0, 7.0, 180.0, 5.0, 9.0, 13.0],
			["eczane", -170.0, -23.0, 9.0, 7.0, 0.0, 5.0, 9.0, 13.0],
			["naka", -1020.0, -640.0, 29.0, 7.0, 180.0, 6.0, 20.0],
			["hyuga", -1050.0, 265.0, 39.0, 15.0, 180.0, 8.0, 18.0],
			["stadyum_bina", 1050.0, -612.0, 38.0, 10.0, 180.0, 18.0, 55.0, 26.0],
			["ichiraku", 70.0, -30.5, 5.0, 4.0, 0.0, 2.5, 6.0, 7.0],
		]
	else:
		var sites: Dictionary = BuildVillageStory._sites(v)
		var c = Vector2(float(v["x"]), float(v["y"]))
		var ac: Vector2 = sites["academy"] - c
		var hc: Vector2 = sites["hospital"] - c
		var st: Vector2 = sites["stadium"] - c
		var kdir = rad_to_deg(atan2(-st.x, -st.y))
		var kd = Vector2(sin(deg_to_rad(kdir)), cos(deg_to_rad(kdir)))
		var sb = st + kd * (Stadium.R_OUT + 10.0)
		specs = [
			["akademi", ac.x, ac.y, 15.0, 7.5, 180.0, 6.0, 22.0],
			["hastane", hc.x, hc.y, 9.0, 6.0, 180.0, 5.0, 16.0],
			["stadyum_bina", sb.x, sb.y, 38.0, 10.0, kdir + 180.0, 18.0, 55.0, 26.0],
			["kage", 0.0, 0.0, 48.0, 48.0, 180.0, 22.0, 70.0, 34.0],
		]
		main.player.respawn(Game.from_map(c + Vector2(0, -float(v.get("r", 300)) * 0.5)) + Vector3(0, 3, 0))
		for k in 90:   # köy akışla kurulur: Kage binası + hikâye yapıları görünene dek bekle
			await _w(1.0)
			if get_tree().current_scene.find_child("Story_%s_akademi" % set_id, true, false) != null and k > 20:
				break
	var c3 = Game.from_map(Vector2(v["x"], v["y"]))
	if OS.get_environment("GARDEN") != "":
		for k in 120:   # Kage bahçesi köy akışla kurulunca kayda girer
			var has = false
			for e in GK.made:
				if String(e["vid"]) == set_id and String(e["name"]) == "kage":
					has = true
			if has or set_id == "konoha":
				break
			await _w(1.0)
		await _shoot_gardens(set_id, tag, only, cam)
		return
	for s in specs:
		if not only.is_empty() and not (String(s[0]) in only):
			continue
		var x: float = s[1]; var n: float = s[2]; var hw: float = s[3]; var hd: float = s[4]
		var f = deg_to_rad(float(s[5])); var lh: float = s[6]; var dist: float = s[7]
		var nf = Vector2(sin(f), cos(f))
		var tg = Vector2(cos(f), -sin(f))
		var views = {"arka": Vector2(x, n) - nf * (hd + dist) + tg * hw * 0.25, "sol": Vector2(x, n) + tg * (hw + dist) - nf * hd * 0.6,
			"sag": Vector2(x, n) - tg * (hw + dist) - nf * hd * 0.6}
		for vk in views:
			var cp: Vector2 = views[vk]
			var p = Vector3(c3.x + cp.x, 0, c3.z - cp.y)
			var t = Vector3(c3.x + x, 0, c3.z - n)
			main.player.respawn(Vector3(p.x, Game.terrain_height(p.x, p.z) + 1.0, p.z))
			await _w(1.6)
			main.player.visible = false
			p.y = Game.terrain_height(p.x, p.z) + (float(s[8]) if s.size() > 8 else lh * 0.6 + 1.5)
			t.y = Game.terrain_height(t.x, t.z) + lh * 0.6
			cam.global_position = p
			cam.look_at(t, Vector3.UP)
			cam.current = true
			await _w(0.5)
			await main.shot("%s_%s_%s_%s" % [tag, set_id, s[0], vk])
	print("BACKS set ", set_id)


## GARDEN=1: GardenKit'in kurduğu bahçeler (arka bahçe kaydı): bahçenin dış kenarından binaya bakış + yükseltilmiş 3/4
## Görüntüler: <TAG>_<köy>_<ad>_{bahce,ust}.png
const GK = preload("res://scripts/world/garden_kit.gd")
func _shoot_gardens(set_id: String, tag: String, only: Array, cam: Camera3D) -> void:
	for e in GK.made:
		if String(e["vid"]) != set_id:
			continue
		if not only.is_empty() and not (String(e["name"]) in only):
			continue
		var f = deg_to_rad(float(e["face"]))
		var nrm = Vector3(sin(f), 0, -cos(f))
		var tg = Vector3(cos(f), 0, sin(f))
		var c: Vector3 = e["center"]
		var wall: Vector3 = e["wall"]
		var sz: Vector2 = e["size"]
		print("GARDEN ", set_id, " ", e["name"], " size ", sz, " u ", e["u"], " d ", e["d"])
		var big = maxf(sz.x, sz.y)
		# [konum, bakılan nokta, zeminden yükseklik]
		var span = minf(sz.x, 60.0)
		if sz.x > 120.0:   # çok geniş bahçe (Hokage yerleşkesi): göletin olduğu doğu yarıya bak
			c += tg * sz.x * 0.09
		var views = {"bahce": [c + nrm * (sz.y * 0.5 - 1.0), (c + wall) * 0.5 + Vector3(0, 1.0, 0), 5.0],
			"ust": [c + nrm * (sz.y * 0.5 + 4.0) + tg * (span * 0.45 + 4.0), c, clampf(span * 0.5, 14.0, 32.0)]}
		for vk in views:
			var p: Vector3 = views[vk][0]
			var t: Vector3 = views[vk][1]
			main.player.respawn(Vector3(p.x, Game.terrain_height(p.x, p.z) + 1.0, p.z))
			await _w(1.6)
			main.player.visible = false
			p.y = maxf(Game.terrain_height(p.x, p.z), c.y) + float(views[vk][2])
			cam.global_position = p
			cam.look_at(t, Vector3.UP)
			cam.current = true
			await _w(0.5)
			await main.shot("%s_%s_%s_%s" % [tag, set_id, e["name"], vk])
	print("GARDENS set ", set_id)
