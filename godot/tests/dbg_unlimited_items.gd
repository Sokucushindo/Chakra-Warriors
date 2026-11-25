extends Node
## Sınırsız eşyalar (fırlatma aletleri, Asker Hapı) + eski tek parça kıyafetler: kullan / kayıt-yükle / eski kayıt göçü.
## Kullanıcının kayıt klasörüne dokunmaz: eski kayıt örneği _tmp/save_copy/kayit_1.json (kopya) okunur; yuva 97.
var main: Node
var pl


func _out(s: String) -> void:
	print("UNL ", s)


func _legacy_count(p: Dictionary) -> int:
	var n := 0
	for g in p.get("gear", []):
		if Gear.is_legacy_piece(String(g.get("id", ""))):
			n += 1
	return n


func _inv_line(p: Dictionary, ids: Array) -> String:
	var inv: Dictionary = p.get("inventory", {})
	var parts := []
	for k in ids:
		parts.append("%s=%s" % [k, str(inv.get(k, "-"))])
	return " ".join(parts)


func _ready() -> void:
	await get_tree().process_frame
	main.creator_state = {"slot": 97, "name": "Test", "gender": "m", "clan": "none", "village": "konoha", "element": "katon", "hair_style": "diken", "hair": Color(0.85, 0.3, 0.12), "top": Color(0.9, 0.45, 0.12),
		"bottom": Color(0.9, 0.45, 0.12), "skin": Color(1.0, 0.86, 0.72), "eye": Color(0.2, 0.4, 0.9)}
	main._start_new_game()
	pl = main.player
	await get_tree().create_timer(3.0).timeout
	Hud.close_dialog()
	var pr: Dictionary = Game.profile
	_out("NEW inv: " + _inv_line(pr, ["kunai", "shuriken", "pill", "salve", "tag"]) + " legacy_gear=%d" % _legacy_count(pr))
	# her sınırsız aleti 25 kez kullan
	var bad := 0
	var c = pl.combat
	for id in Data.items:
		if not Stats.unlimited(id) or id == "pill":
			continue
		pr["inventory"][id] = 1
	pr["inventory"]["tag"] = 1
	for id in ["kunai", "shuriken", "senbon", "tag", "makibishi", "smoke", "hikaridama"]:
		pr["throw_sel"] = id
		var thrown := 0
		for i in 25:
			c.action = ""
			c.tool_cd.clear()
			c.throw_tool()
			if c.action == "throw":
				thrown += 1
			await get_tree().process_frame
		var left = int(pr["inventory"].get(id, 0))
		if thrown != 25 or left != 1:
			bad += 1
		_out("THROW %s used=%d/25 count_after=%d" % [id, thrown, left])
	# Kawarimi tuzağı etiket kunai harcıyordu
	for i in 5:
		PathJutsu.kawa_trap(pl, pl.global_position + Vector3(3, 0, 0))
	_out("KAWA tag after 5 traps=%d" % int(pr["inventory"].get("tag", 0)))
	if int(pr["inventory"].get("tag", 0)) != 1:
		bad += 1
	# Asker Hapı 10 kez (bekleme sıfırlanarak)
	var pills := 0
	for i in 10:
		pr["pill_ready_at"] = 0.0
		main.use_item("pill")
		if float(pr.get("pill_ready_at", 0.0)) > 0.0:
			pills += 1
	_out("PILL used=%d/10 count_after=%s" % [pills, str(pr["inventory"].get("pill", "-"))])
	if pills != 10:
		bad += 1
	# HUD rozetleri
	pr["throw_sel"] = "kunai"
	Hud._update_side(pl, pr)
	_out("HUD badges tool='%s' pill='%s' pill_ok=%s" % [Hud.side_state[0]["badge"], Hud.side_state[3]["badge"], str(Hud.side_state[3]["ok"])])
	# ödül havuzu ve grant: eski parça çıkmaz / verilmez
	var leg_rw := 0
	for i in 2000:
		var g = Gear.random_reward(5)
		if g != "" and Gear.is_legacy_piece(g):
			leg_rw += 1
	_out("REWARD legacy picks in 2000=%d grant(hakama)=%d grant(ninja_pant)=%d grant(set_genin)>0=%s" % [leg_rw, Gear.grant(pr, "hakama"), Gear.grant(pr, "ninja_pant"), str(Gear.grant(pr, "set_genin") > 0)])
	# kayıt-yükle (bellekte JSON gidiş-dönüş, oyunun yükleme yolundaki göçlerle)
	var rt = JSON.parse_string(JSON.stringify(pr))
	Game.profile = rt
	Gear.ensure(Game.profile)
	Stats.normalize_unlimited(Game.profile)
	_out("RELOAD inv: " + _inv_line(Game.profile, ["kunai", "shuriken", "pill", "salve", "tag"]) + " legacy_gear=%d" % _legacy_count(Game.profile))
	# eski kayıt örneği (kullanıcı kaydının _tmp kopyası)
	var old_path = ProjectSettings.globalize_path("res://../_tmp/save_copy/kayit_1.json")
	if FileAccess.file_exists(old_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(old_path))
		d["slot"] = 97
		var ryo0 = int(d.get("ryo", 0))
		_out("OLD before: " + _inv_line(d, ["kunai", "shuriken", "pill", "salve", "kosen"]) + " legacy_gear=%d ryo=%d" % [_legacy_count(d), ryo0])
		Gear.ensure(d)
		Stats.normalize_unlimited(d)
		_out("OLD after: " + _inv_line(d, ["kunai", "shuriken", "pill", "salve", "kosen"]) + " legacy_gear=%d ryo=%d (+%d) msg=%s set_equipped=%s" % [_legacy_count(d), int(d.get("ryo", 0)), int(d.get("ryo", 0)) - ryo0, str(d.get("_legacy_sold", [])), str(d.get("equip", {}).has("set"))])
		var d2 = JSON.parse_string(JSON.stringify(d))
		Gear.ensure(d2)
		Stats.normalize_unlimited(d2)
		_out("OLD reload: legacy_gear=%d ryo=%d" % [_legacy_count(d2), int(d2.get("ryo", 0))])
	else:
		_out("OLD sample missing")
	_out("RESULT bad=%d" % bad)
	Game.delete_slot(97)
	get_tree().quit()
