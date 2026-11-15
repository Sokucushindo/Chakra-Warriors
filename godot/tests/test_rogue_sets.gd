extends Node
## Kaçak ninjaların setleri: farklı klan / köy / cinsiyetten kaçaklar karakterine uyan gerçek seti giyiyor mu.
## 1) Seçim dağılımı (her klan için 40 tohum): seçilen setler ve yasak tür (plaj, pijama...) çıkmadığı
## 2) Dünyadan gerçek kişiler kaçırılır (WorldPeople.defect) → Bingo kaydının görünüşü seti taşıyor mu
## 3) Sıra hâlinde modeller (ekran görüntüsü: _tmp/rogue_sets_N.jpg)
var main: Node
var fails := 0
const BAD := ["sahil", "pijama", "esofman", "gelinlik", "kurbaga", "okul", "tatli", "genclik", "harika", "hemsire", "onluk", "kedi"]


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["GECTI" if cond else "KALDI", what])


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 3, "name": "Test", "gender": "m", "clan": "none", "element": "katon", "village": "konoha", "hair_style": "diken", "hair": Color(0.1, 0.1, 0.1), "top": Color(0.2, 0.2, 0.3),
		"bottom": Color(0.2, 0.2, 0.3), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	await get_tree().create_timer(2.5).timeout
	Hud.close_dialog()
	Hud.show_game_hud(false)
	Game.world.env.time_of_day = 0.45
	WorldDay.auto = false
	# 1) dağılım
	var bad_hits := 0
	var no_set := 0
	for c in Data.clans.keys() + [""]:
		if c == "none":
			continue
		var vids: Array = Data.clans.get(c, {}).get("villages", ["konoha", "suna", "kiri", "kumo", "iwa"])
		var cnt := {}
		for i in 40:
			var fem = i % 3 == 0
			var sid = Outfits.rogue_set(String(c), String(vids[i % vids.size()]), [["katon", "suiton", "fuuton", "doton", "raiton"][i % 5]], [], fem, "%s%d" % [c, i])
			if sid == "":
				no_set += 1
				continue
			cnt[sid] = int(cnt.get(sid, 0)) + 1
			for b in BAD:
				if b in sid:
					bad_hits += 1
			var sx = String(Gear.item(sid).get("sex", ""))
			if sx != "" and sx != ("f" if fem else "m"):
				bad_hits += 1
				print("  CİNSİYET UYMUYOR %s %s" % [sid, sx])
		var top = cnt.keys()
		top.sort_custom(func(a, b): return int(cnt[a]) > int(cnt[b]))
		print("  %-11s %s" % [c if c != "" else "(klansız)", ", ".join(top.slice(0, 6).map(func(s): return "%s×%d" % [String(Gear.item(s).get("name", s)), int(cnt[s])]))])
	ok(bad_hits == 0, "yasak tür / yanlış cinsiyet seti çıkmadı (%d)" % bad_hits)
	ok(no_set == 0, "herkese bir set bulundu (setsiz %d)" % no_set)
	# 2) gerçek kişiler kaçar
	var people: Array = WorldPeople.all().values().filter(func(p): return WorldPeople.alive(p) and not WorldPeople.is_rogue(p) and int(p["rank"]) >= 1)
	var picked: Array = []
	var seen_clan := {}
	for p in people:
		var key = String(p["clan"]) + String(p["village"])
		if not seen_clan.has(key) and picked.size() < 10:
			seen_clan[key] = true
			picked.append(p)
	var with_set := 0
	for p in picked:
		var e = WorldPeople.defect(p, "deneme")
		var sid = String(p.get("set", ""))
		var lk: Dictionary = e.get("look", {})
		if sid != "" and String(lk.get("set_id", "")) == sid and String(lk.get("band_style", "")) == "slashed":
			with_set += 1
		print("  kaçak %-22s klan=%-9s köy=%-7s %s → %s" % [String(p["name"]), String(p["clan"]), String(p["village"]), "K" if bool(p["female"]) else "E", String(Gear.item(sid).get("name", "—"))])
	ok(with_set == picked.size(), "kaçan %d kişinin %d'i set + çizik alın koruyucu taşıyor" % [picked.size(), with_set])
	# 3) görüntü: beşerli sıralar
	var pl = main.player
	var cc = Camera3D.new()
	get_tree().current_scene.add_child(cc)
	cc.fov = 38.0
	cc.current = true
	var base: Vector3 = pl.global_position + Vector3(0, 0, -8)
	pl.visible = false
	for row in 2:
		var models: Array = []
		for i in 5:
			var idx = row * 5 + i
			if idx >= picked.size():
				break
			var m = CharacterModel.new()
			get_tree().current_scene.add_child(m)
			m.setup(WorldPeople.look_of(picked[idx]))
			var at = base + Vector3((i - 2) * 1.5, 0, 0)
			at.y = Game.ground_height(at.x, at.z)
			m.global_position = at
			m.rotation.y = PI
			models.append(m)
		await get_tree().create_timer(1.2).timeout
		cc.global_position = base + Vector3(0, 1.25, 6.2)
		cc.look_at(base + Vector3.UP * 1.0)
		await RenderingServer.frame_post_draw
		var im = get_viewport().get_texture().get_image()
		im.resize(1600, 862)
		im.save_jpg("D:/Naruto 3D Game/_tmp/rogue_sets_%d.jpg" % row, 0.88)
		for m in models:
			m.queue_free()
		await get_tree().create_timer(0.2).timeout
	# Bingo Kitabı: kayıtlar seti taşıyor mu
	var n_set := 0
	var ents: Array = Missions.bingo_entries()
	for e in ents:
		if String(e["look"].get("set_id", "")) != "":
			n_set += 1
	print("  Bingo Kitabı: %d kayıt, %d'i setli" % [ents.size(), n_set])
	ok(ents.is_empty() or n_set > 0, "Bingo Kitabı kayıtlarında set var")
	print("SONUC: %d hata" % fails)
	get_tree().quit()
