class_name Cheats
extends RefCounted
## Hileler (Ayarlar > Hileler). Yalnız oyuncuya işler; hepsi oyunun gerçek sistemleriyle çalışır:
## göz = gerçek göz eşyası + göz yuvası (Gear / Eyes), jutsu = öğrenilenler listesi, jinchūriki = TailedBeasts.make_jinchuriki,
## rütbe = Progress.promote / Kage yemin töreni, ışınlanma = hızlı seyahat (Main.fast_travel / travel_to_map).
## Açık / kapalı hileler profilde: profile["cheats"] = {anahtar: true}. Herhangi bir hile kullanılınca kayıt işaretlenir:
## profile["flags"]["cheated"] = true. Verilen şeyler (göz, jutsu, eşya...) normal oyundaki gibi kalıcıdır.

## [anahtar, ad, açıklama]
const TOGGLES := [
	["god", "Ölümsüzlük", "Hasar almazsın, ölmezsin; canın hep dolu kalır."],
	["chakra", "Sınırsız chakra", "Chakran hiç azalmaz: jutsu, göz, mod ve uçuş bedava."],
	["stamina", "Sınırsız dayanıklılık", "Koşu, kaçış atlayışı ve tırmanış dayanıklılığı hiç bitmez."],
	["nocd", "Bekleme süresi yok", "Jutsu, göz tekniği, Kawarimi, alet, canavar bombası ve asker hapı beklemeleri sıfırlanır."],
	["onehit", "Tek vuruşta öldür", "Değen her darbe ve jutsun rakibi anında yere serer."],
	["invis", "Düşmanlara görünmez", "Düşmanlar seni fark etmez; peşindeyse izini kaybeder."],
	["ryo", "Sınırsız Ryō", "Kesende hep en az 1.000.000 Ryō olur."],
	["speed", "Süper hız", "Koşu ve depar hızın 2,5 katına çıkar."],
	["jump", "Süper zıplama", "Zıplaman iki kat yükseğe çıkar."],
	["fly", "Serbest uçuş", "Space yüksel, Ctrl alçal, Shift hızlan; duvarların ve evlerin içinden geçersin."],
	["noblind", "Mangekyō körlüğü yok", "Mangekyō gözlerini karartmaz; birikmiş körlük de silinir."],
	["nomodecost", "Mod bedelleri yok", "Sekiz Kapı can yemez, Ölüm Kapısı öldürmez, üst üste açık modlar chakra yemez, canavar pelerini bedeni yakmaz ve kontrolden çıkmaz."],
]

## [göz eşyası, ustalık (Sharingan'da tomoe), görünen ad]
const EYES := [
	["goz_sharingan", 1, "Sharingan (1 tomoe)"], ["goz_sharingan", 2, "Sharingan (2 tomoe)"], ["goz_sharingan", 3, "Sharingan (3 tomoe)"],
	["goz_mangekyo", 3, "Mangekyō Sharingan"], ["goz_ems", 3, "Ebedi Mangekyō Sharingan"], ["goz_rinnegan", 3, "Rinnegan"],
	["goz_byakugan", 3, "Byakugan"], ["goz_ketsuryugan", 3, "Ketsuryūgan"], ["goz_tenseigan", 3, "Tenseigan"], ["goz_jogan", 3, "Jōgan"],
]
const SIDES := [["Sağ göz", ["sag_goz"]], ["Sol göz", ["sol_goz"]], ["İki göz", ["sag_goz", "sol_goz"]]]
const POWER_STEPS := [1, 10, 20, 30, 45, 60, 80, 100, 130, 160, 200, 300]
const MASTERY_STEPS := [25, 50, 75, 100, 150, 200, 300]
const ITEM_CATS := [["w", "Silah"], ["set", "Kıyafet seti"], ["head", "Kafa / yüz"], ["back", "Sırt"], ["tool", "Alet ve hap"]]
const TIMES := [[0.25, "Şafak"], [0.33, "Sabah"], [0.5, "Öğle"], [0.66, "İkindi"], [0.76, "Gün batımı"], [0.9, "Gece"], [0.0, "Gece yarısı"]]
const WEATHERS := [["", "Doğal (bölgeye göre)"], ["açık", "Açık hava"], ["bulutlu", "Bulutlu"], ["yağmur", "Yağmur"], ["sis", "Sis"], ["kar", "Kar"], ["kum fırtınası", "Kum fırtınası"]]
const OVERCAST := {"açık": 0.0, "bulutlu": 0.5, "yağmur": 0.85, "sis": 0.7, "kar": 0.6, "kum fırtınası": 0.8}

static var sel := {}            # menüdeki seçici konumları (yeniden çizimde korunur)
static var weather := ""        # zorlanan hava ("" = doğal); Environment._update_weather okur
static var _items := {}         # tür -> [[kimlik, ad]] (bir kez kurulur)
static var _groups: Array = []


# ================================================================== durum
static func on(k: String) -> bool:
	var pr = Game.profile
	if pr.is_empty():
		return false
	var cs = pr.get("cheats")
	return cs is Dictionary and bool(cs.get(k, false))


static func any_on() -> bool:
	var cs = Game.profile.get("cheats") if not Game.profile.is_empty() else null
	if not cs is Dictionary:
		return false
	for k in cs:
		if cs[k]:
			return true
	return false


static func mark() -> void:
	var pr = Game.profile
	if pr.is_empty():
		return
	if not pr.has("flags"):
		pr["flags"] = {}
	pr["flags"]["cheated"] = true


static func set_on(k: String, v: bool) -> void:
	var pr = Game.profile
	if pr.is_empty():
		return
	if not pr.get("cheats") is Dictionary:
		pr["cheats"] = {}
	if v:
		pr["cheats"][k] = true
		mark()
	else:
		pr["cheats"].erase(k)
	var p = Game.player
	match k:
		"fly":
			if not v and p and is_instance_valid(p):
				if p.fly_src == "hile":
					p.stop_flight()
				p.collision_mask = 1
		"noblind":
			if v:
				pr["ms_blind"] = 0.0
		"god":
			if v and p and is_instance_valid(p):
				p.hp = p.max_hp


## Hız / zıplama çarpanları (Player hareketi okur)
static func speed_mul() -> float:
	return 2.5 if on("speed") else 1.0


static func jump_mul() -> float:
	return 2.0 if on("jump") else 1.0


## Senin darbenle mi? (tek vuruş hilesi): oyuncu ya da oyuncunun attığı şey
static func kills(atk) -> bool:
	return atk != null and is_instance_valid(atk) and atk == Game.player and on("onehit")


## Oyuncunun her fizik karesinde (Player._physics_process)
static func tick(p: Node) -> void:
	var pr = Game.profile
	var cs = pr.get("cheats") if not pr.is_empty() else null
	if not cs is Dictionary or cs.is_empty():
		return
	if cs.get("god", false) and p.hp > 0.0:
		p.hp = p.max_hp
	if cs.get("chakra", false):
		p.chakra = p.max_chakra
	if cs.get("stamina", false):
		p.stamina = p.max_stamina
	if cs.get("nocd", false):
		_clear_cooldowns(p)
	if cs.get("ryo", false) and int(pr.get("ryo", 0)) < 1000000:
		pr["ryo"] = 1000000
	if cs.get("noblind", false) and float(pr.get("ms_blind", 0.0)) > 0.0:
		pr["ms_blind"] = 0.0
	if cs.get("fly", false):
		if p.fly_src == "" and p.hp > 0.0 and not p.has_meta("dying"):
			p.start_flight("hile", {"name": "Serbest uçuş", "drain": 0.0, "speed": 30.0, "lift": 16.0})
		p.collision_mask = 0 if p.fly_src == "hile" else 1   # uçarken duvarlardan geçer (zemin altına inmez: uçuş yere yapışır)


static func _clear_cooldowns(p: Node) -> void:
	var c = p.get("combat")
	if c == null:
		return
	c.cooldowns.clear()
	c.cd_max.clear()
	c.jutsu_gcd = 0.0
	c.tool_cd.clear()
	c.fan_cd = 0.0
	c.sub_bars = 4.0
	var m = c.modes
	if m:
		m.beast_cd = 0.0
		if m.eyes:
			m.eyes.cd["sag"] = 0.0
			m.eyes.cd["sol"] = 0.0
			m.eyes.phase_cd = 0.0
		if m.cloak:
			m.cloak.bomb_cd = 0.0
			m.cloak.tech_cd.clear()
	Game.profile["pill_ready_at"] = 0.0


# ================================================================== anında
static func heal() -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	mark()
	p.hp = p.max_hp
	p.chakra = p.max_chakra
	p.stamina = p.max_stamina
	p.statuses.clear()
	Game.profile["ms_blind"] = 0.0
	FX.aura(p, Color(0.5, 1, 0.6), 0.8)
	Sfx.play("heal", p.global_position)
	Hud.msg("İyileştin: can, chakra ve dayanıklılık doldu.", Color(0.6, 1.0, 0.7))


static func add_ryo(n := 100000) -> void:
	mark()
	Game.profile["ryo"] = int(Game.profile.get("ryo", 0)) + n
	Hud.float_text("+%d Ryō" % n, Color(1, 0.85, 0.4))
	Sfx.play("coin")


# ================================================================== göz
static func eyes_node():
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.get("combat") == null or p.combat.modes == null:
		return null
	return p.combat.modes.eyes


static func ms_style_keys() -> Array:
	return Eyes.MS_STYLES.keys()


## Gerçek göz eşyası verilip göz yuvasına takılır (eski göz kavanoza: Gözler sekmesinden geri takılabilir)
static func give_eye(ei: int, side: int, style: int) -> void:
	var pr = Game.profile
	var e: Array = EYES[clampi(ei, 0, EYES.size() - 1)]
	var ey = eyes_node()
	if ey and ey.active:
		ey._close()
	mark()
	var st_keys = ms_style_keys()
	var st = String(st_keys[posmod(style, st_keys.size())])
	for slot in SIDES[clampi(side, 0, SIDES.size() - 1)][1]:
		var cur = Gear.equipped(pr, slot)
		if not cur.is_empty():
			cur["own"] = true
		var extra = {"lvl": int(e[1]), "origin": "dogustan", "xp": 0.0}
		if String(e[0]) in ["goz_mangekyo", "goz_ems"]:
			extra["ms_style"] = st
		Gear.grant(pr, String(e[0]), slot, null, null, extra)
	if String(e[0]) == "goz_ems":
		pr["ms_blind"] = 0.0
	Gear.apply_look(pr)
	if Game.player:
		Game.player.rebuild_model()
		Game.player.apply_profile_stats()
	Progress.clan_unlocks(false)   # gözün teknikleri (göz şartlı jutsular)
	SpecialSlots.refresh(pr)
	if ey:
		ey.refresh_visual()
	Hud.msg("%s takıldı: %s." % [String(e[2]), String(SIDES[side][0])], Color(1, 0.6, 0.6))
	Game.save_game()


static func eye_summary() -> String:
	var pr = Game.profile
	var parts = []
	for s in [["sag_goz", "Sağ"], ["sol_goz", "Sol"]]:
		var g = Gear.equipped(pr, s[0])
		var nm = "yok" if g.is_empty() else String(Gear.item(g["id"]).get("name", g["id"]))
		if not g.is_empty() and String(g["id"]) == "goz_sharingan":
			nm = "%s, %d tomoe" % [nm, int(g.get("lvl", 1))]
		if not g.is_empty() and Eyes.MS_STYLES.has(String(g.get("ms_style", ""))):
			nm = "%s, tarz: %s" % [nm, String(Eyes.MS_STYLES[g["ms_style"]]["name"])]
		parts.append(nm)
	return "Sağ göz: %s  ·  Sol göz: %s" % parts


# ================================================================== jutsu
## Öğrenme grupları: [kimlik, görünen ad]
static func unlock_groups() -> Array:
	if not _groups.is_empty():
		return _groups
	var out: Array = [["all", "Tüm jutsular"]]
	for e in KgPaths.BASE:
		out.append(["el:" + e, "Doğa: %s" % Elements.NAMES.get(e, e)])
	var kgs := []
	var clans := []
	for jid in Data.jutsu:
		var j = Data.jutsu[jid]
		if not j is Dictionary:
			continue
		var lp = String(j.get("learn", ""))
		if lp.begins_with("kg:") and not lp.substr(3) in kgs:
			kgs.append(lp.substr(3))
		var c = lp.substr(5) if lp.begins_with("clan:") else String(j.get("clan", ""))
		if c != "" and Data.clans.has(c) and not c in clans:
			clans.append(c)
	kgs.sort()
	for n in kgs:
		out.append(["kg:" + n, "Kekkei genkai: %s" % Menus._el_name(n)])
	clans.sort_custom(func(a, b): return String(Data.clans[a].get("name", a)) < String(Data.clans[b].get("name", b)))
	for c in clans:
		out.append(["clan:" + c, "Klan: %s" % String(Data.clans[c].get("name", c))])
	out.append(["sage", "Senjutsu (Sennin modu dahil)"])
	out.append(["eye", "Göz teknikleri (takılı gözlerin)"])
	out.append(["weapon", "Silah teknikleri"])
	_groups = out
	return out


static func _els(j: Dictionary) -> Array:
	var els: Array = j.get("elements", [])
	if els.is_empty() and String(j.get("element", "")) != "":
		els = [String(j["element"])]
	return els


static func _learn(pr: Dictionary, jid: String) -> bool:
	if jid in pr["learned"]:
		return false
	pr["learned"].append(jid)
	var slots: Array = pr["slots"]
	for i in slots.size():
		if slots[i] == "" or slots[i] == null:
			slots[i] = jid
			break
	return true


## Gruptaki teknikleri öğret; gereken doğa / kekkei genkai / sennin yeteneği de verilir. Öğrenilen sayısını döndürür.
static func unlock(gid: String) -> int:
	var pr = Game.profile
	if pr.is_empty():
		return 0
	mark()
	if gid.begins_with("el:") and not Progress.has_nature(gid.substr(3)):
		pr["elements"].append(gid.substr(3))
	if gid.begins_with("kg:"):
		Progress.awaken_nature(gid.substr(3), false)
	if gid == "sage" and not "sage" in pr["skills"]:
		pr["skills"].append("sage")   # Sennin modu (Z): kurbağa sözleşmesinin doğa enerjisi
	var n := 0
	for jid in Data.jutsu:
		var j = Data.jutsu[jid]
		if String(jid).begins_with("_") or not j is Dictionary:
			continue
		var lp = String(j.get("learn", ""))
		if lp.begins_with("locked:"):
			continue
		if Eyes.ms_tracked(jid) and not Eyes.ms_allowed(pr, jid):
			continue   # başka Mangekyō tarzının tekniği: göz değişince zaten silinir
		var ok := false
		if gid == "all":
			ok = true
		elif gid.begins_with("el:"):
			ok = gid.substr(3) in _els(j)
		elif gid.begins_with("kg:"):
			ok = lp == gid or gid.substr(3) in _els(j)
		elif gid.begins_with("clan:"):
			ok = lp == gid or String(j.get("clan", "")) == gid.substr(5)
		elif gid == "sage":
			ok = lp == "sage:any"
		elif gid == "eye":
			ok = lp.begins_with("eye:") and Progress.has_eye(lp.substr(4))
		elif gid == "weapon":
			ok = lp.begins_with("weapon:")
		if ok and _learn(pr, jid):
			n += 1
	if gid == "all":
		for e in KgPaths.BASE:
			if not Progress.has_nature(e):
				pr["elements"].append(e)
	Progress.clan_unlocks(false)
	SpecialSlots.refresh(pr)
	Game.save_game()
	return n


## Bütün Efsane Yolları: yola katılmış sayılırsın (pasif bonuslar) ve her yolun bütün tekniklerini öğrenirsin
static func learn_paths() -> int:
	var pr = Game.profile
	if pr.is_empty():
		return 0
	mark()
	var n := 0
	for pid in LegendPaths.PATHS:
		LegendPaths.set_state(pid, LegendPaths.JOINED)
		var list: Array = (LegendPaths.PATHS[pid].get("order", []) as Array).duplicate()
		for jid in Data.jutsu:
			var j = Data.jutsu[jid]
			if j is Dictionary and String(j.get("learn", "")) == "path:" + pid and not jid in list:
				list.append(jid)
		for jid in list:
			if Data.jutsu.has(jid) and _learn(pr, jid):
				n += 1
		if pid == "kapi" and not "gates" in pr["skills"]:
			pr["skills"].append("gates")   # Sekiz Kapı modu
	# yolların verdiği araçlar (LegendPaths._teach ile aynı)
	if (pr["learned"] as Array).any(func(k): return String(k).begins_with("bashosen_")) and not "bashosen" in Gear.owned_ids(pr):
		Gear.grant(pr, "bashosen")
	if "hachibi_yedi_kilic" in pr["learned"] and not "nanato" in Gear.owned_ids(pr):
		Gear.grant(pr, "nanato")
	Game.save_game()
	return n


# ================================================================== güç / ustalık / rütbe
static func _after_power() -> void:
	var pr = Game.profile
	var old = int(pr.get("level", 1))
	Mastery.refresh_level(pr)
	Progress.on_power_changed()
	if int(pr["level"]) == old and Game.player:
		Game.player.apply_profile_stats()
	if Game.player:
		Game.player.hp = Game.player.max_hp
		Game.player.chakra = Game.player.max_chakra
		Game.player.stamina = Game.player.max_stamina


## Güç = ninjutsu, en iyi dövüş dalı, chakra, dayanıklılık ortalamasından türer (Mastery.power): o dört ustalık bu Güç'e ayarlanır
static func set_power(target: int) -> void:
	var pr = Game.profile
	mark()
	if not pr.has("mastery"):
		pr["mastery"] = {}
	var avg = 100.0 * pow(maxf(1.0, float(target)) / 100.0, 1.0 / 0.7)
	for k in ["ninjutsu", "taijutsu", "chakra", "dayaniklilik"]:
		pr["mastery"][k] = avg
	pr["mastery"]["kenjutsu"] = minf(Mastery.get_v(pr, "kenjutsu"), avg)
	_after_power()
	Hud.msg("Güç %d" % int(pr["level"]), Color(0.6, 0.95, 1.0))
	Game.save_game()


static func set_all_mastery(v: float) -> void:
	var pr = Game.profile
	mark()
	if not pr.has("mastery"):
		pr["mastery"] = {}
	for k in Mastery.KEYS:
		pr["mastery"][k] = v
	_after_power()
	Hud.msg("Bütün ustalıklar %d. Güç %d" % [int(v), int(pr["level"])], Color(0.6, 0.95, 1.0))
	Game.save_game()


static func main_node() -> Node:
	var ml = Engine.get_main_loop()
	var cs = ml.current_scene if ml is SceneTree else null
	return cs if cs != null and cs.has_method("fast_travel") else null


static func set_rank(r: int) -> void:
	mark()
	if r >= 6:
		# Kage: köyün gerçek yemin töreni (şapka, cübbe, Kage masası)
		var m = main_node()
		if m:
			m.resume()
		Kage.inaugurate()
		return
	Progress.promote(clampi(r, 0, 5))


# ================================================================== kuyruklu canavar
static func beast_name(id: String) -> String:
	return String(BeastModels.INFO.get(id, {}).get("name", id)).split(" — ")[0]


static func become_jinchuriki(id: String) -> void:
	if not id in TailedBeasts.free_beasts():
		return
	mark()
	TailedBeasts.make_jinchuriki(id)


static func full_bond() -> void:
	mark()
	for id in TailedBeasts.held():
		TailedBeasts.add_trust(100.0, id)
	Hud.msg("Taşıdığın canavarlarla bağın tam.", Color(1, 0.7, 0.4))


# ================================================================== eşya
static func items(cat: String) -> Array:
	if _items.has(cat):
		return _items[cat]
	var out: Array = []
	if cat == "tool":
		for id in Data.items:
			out.append([String(id), String(Data.items[id].get("name", id))])
	else:
		var ids: Array = []
		for id in Gear.ITEMS:
			var s = String(Gear.ITEMS[id].get("slot", ""))
			if (cat == "w" and s in ["sag", "el"]) or (cat == "set" and s == "set") or (cat == "head" and s in ["kafa", "yuz"]) or (cat == "back" and s == "sirt"):
				ids.append(id)
		if cat == "set":
			ids.append_array(Gear.SETS.keys())
			ids.append_array(Gear.STRIKER.SETS.keys())
		for id in ids:
			id = String(id)
			if Gear.MERGED_SETS.has(id) or Gear.REMOVED_SETS.has(id) or Gear.is_legacy_piece(id) or Gear.item(id).is_empty():
				continue
			if out.any(func(r): return r[0] == id):
				continue
			out.append([id, String(Gear.item(id).get("name", id))])
	out.sort_custom(func(a, b): return a[1] < b[1])
	_items[cat] = out
	return out


const EQUIP_SLOT := {"w": "sag", "set": "set", "head": "kafa", "back": "sirt"}


static func give_item(cat: String, id: String, equip: bool) -> void:
	var pr = Game.profile
	mark()
	if cat == "tool":
		pr["inventory"][id] = int(pr["inventory"].get(id, 0)) + 10
		Hud.msg("+10 %s" % String(Data.items.get(id, {}).get("name", id)), Color(0.9, 0.85, 0.6))
		return
	Gear.ensure(pr)
	Gear.grant(pr, id, String(EQUIP_SLOT.get(cat, "")) if equip else "")
	if equip:
		Gear.apply_look(pr)
		if Game.player:
			Game.player.rebuild_model()
	Hud.msg(("%s verildi ve kuşanıldı." if equip else "%s verildi.") % String(Gear.item(id).get("name", id)), Color(0.9, 0.85, 0.6))
	Game.save_game()


static func give_all(cat: String) -> int:
	var pr = Game.profile
	mark()
	var n := 0
	var owned = Gear.owned_ids(pr)
	for r in items(cat):
		if cat == "tool":
			pr["inventory"][r[0]] = int(pr["inventory"].get(r[0], 0)) + 10
			n += 1
		elif not r[0] in owned:
			if Gear.grant(pr, r[0]) >= 0:
				n += 1
	Game.save_game()
	return n


# ================================================================== dünya
## Işınlanma yerleri: [tür, kimlik / harita x, y, ad]
static func places() -> Array:
	var out: Array = []
	for v in Game.world_info.get("villages", []):
		out.append(["v", String(v["id"]), 0.0, String(v["name"])])
	for l in Game.world_info.get("landmarks", []):
		out.append(["m", float(l["x"]), float(l["y"]), String(l["name"])])
	for c in Game.world_info.get("countries", []):
		out.append(["m", float(c["x"]), float(c["y"]), String(c["name"])])
	return out


static func teleport(i: int) -> void:
	var pl = places()
	var m = main_node()
	if pl.is_empty() or m == null or Game.player == null:
		return
	mark()
	var r: Array = pl[clampi(i, 0, pl.size() - 1)]
	if r[0] == "v":
		if not r[1] in Game.profile.get("visited", []):
			Game.profile["visited"].append(r[1])
		m.fast_travel(r[1])
	else:
		m.travel_to_map(r[1], r[2], r[3])


static func set_time(t: float) -> void:
	if Game.world and Game.world.get("env"):
		Game.world.env.time_of_day = t
		mark()


static func set_weather(w: String) -> void:
	weather = w
	if w != "" and Game.world and Game.world.get("env"):
		Game.world.env.overcast = float(OVERCAST.get(w, 0.0))
		mark()


# ================================================================== Ayarlar > Hileler sekmesi
static func _i(key: String, n: int) -> int:
	return clampi(int(sel.get(key, 0)), 0, maxi(0, n - 1))


static func _step(key: String, d: int, n: int) -> void:
	sel[key] = posmod(_i(key, n) + d, maxi(1, n))


## Seçicinin konum noktaları: uzun listede nokta yok (yüzlerce nokta satırı taşırır)
static func _dots(i: int, n: int) -> Vector2i:
	return Vector2i(i, n) if n <= 12 else Vector2i(0, 0)


## Satırın sonuna küçük, çevrilmeyen ek yazı (uzun listede "12/300", saatte "21:36")
static func _tail(h: HBoxContainer, text: String) -> void:
	if text == "":
		return
	var l = UI.label(text, 14, UI.MUTED)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)


static func _of(i: int, n: int) -> String:
	return "%d/%d" % [i + 1, n] if n > 12 else ""


## Satırın adının altına kısa açıklama (ve alt şeritteki açıklama)
static func _desc_under(h: HBoxContainer, text: String) -> void:
	h.set_meta("desc", text)
	var l: Label = h.get_child(0) as Label
	if l == null:
		return
	var vb = UI.vbox(1)
	vb.custom_minimum_size = Vector2(l.custom_minimum_size.x, 0)
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.remove_child(l)
	l.custom_minimum_size = Vector2(l.custom_minimum_size.x, 0)
	vb.add_child(l)
	var d = UI.label(text, 13, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(l.custom_minimum_size.x, 0)
	vb.add_child(d)
	h.add_child(vb)
	h.move_child(vb, 0)


static func _note(sec: VBoxContainer, text: String, col := UI.MUTED) -> void:
	var l = UI.label(text, 14, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_child(l)
	sec.add_child(m)


static func _btn_row(sec: VBoxContainer, lw: float, title: String, desc: String, buttons: Array) -> void:
	var h = Menus._set_row(sec, title, lw)
	for b in buttons:   # [yazı, simge, iş]
		var cb: Callable = b[2]
		var bt = UI.button(String(b[0]), func():
			Sfx.play("click")
			cb.call(), 220 if buttons.size() > 1 else 300, String(b[1]))
		bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bt)
	_desc_under(h, desc)


static func build_tab(body: Control, lw: float, pick: Callable, redraw: Callable) -> void:
	var pr = Game.profile
	if pr.is_empty() or Game.player == null or not is_instance_valid(Game.player):
		var s0 = Menus._set_section(body, "skull", "Hile Kuralları")
		_note(s0, "Hileler yalnız oyun içinde, bir kayıt yüklüyken kullanılabilir.", UI.TEXT)
		return
	var again = func(cb: Callable) -> Callable:   # işi yap, sonra ekranı yenile (yeni durum görünsün)
		return func():
			cb.call()
			redraw.call()
	# ---- açık / kapalı hileler
	var t = Menus._set_section(body, "skull", "Hile Kuralları")
	_note(t, "Hileler yalnız sana işler. Herhangi bir hileyi kullanmak kaydını \"hileli\" olarak işaretler; açık hile varken ekranın solunda \"Hile açık\" yazar.")
	if bool(pr.get("flags", {}).get("cheated", false)):
		_note(t, "Bu kayıt hileli.", Color(1.0, 0.55, 0.4))
	for row in TOGGLES:
		var k: String = row[0]
		var onv := on(k)
		var h = pick.call(t, row[1], "Açık" if onv else "Kapalı", func(_d): set_on(k, not on(k)), false, Vector2i(int(onv), 2))
		_desc_under(h, row[2])
	# ---- anında
	var a = Menus._set_section(body, "heart", "Anında")
	_btn_row(a, lw, "İyileş", "Can, chakra ve dayanıklılık dolar; yanık, zehir, sersemlik gibi durumlar ve Mangekyō körlüğü silinir.", [["Uygula", "heart", func(): heal()]])
	_btn_row(a, lw, "Ryō ekle", "Kesene 100.000 Ryō eklenir (şu an %d Ryō)." % int(pr.get("ryo", 0)), [["+100.000 Ryō", "coin", again.call(func(): add_ryo())]])
	# ---- göz
	var e = Menus._set_section(body, "eye", "Göz Ver")
	_note(e, "Şu an  ·  %s" % eye_summary())
	var ei := _i("eye", EYES.size())
	_desc_under(pick.call(e, "Göz", EYES[ei][2], func(d): _step("eye", d, EYES.size()), false, _dots(ei, EYES.size())),
		"Takılacak dōjutsu. Gerçek göz olarak takılır: göz teknikleri (V), özel göz yuvaları ve göze bağlı jutsular hemen açılır.")
	var si := _i("side", SIDES.size())
	if not sel.has("side"):
		si = 2
		sel["side"] = 2
	_desc_under(pick.call(e, "Göz yuvası", SIDES[si][0], func(d): _step("side", d, SIDES.size()), false, _dots(si, SIDES.size())),
		"Gözün takılacağı yuva. Yerinden çıkan eski göz kavanoza gider (Tab > Gözler'den geri takılabilir).")
	if String(EYES[ei][0]) in ["goz_mangekyo", "goz_ems"]:
		var sk = ms_style_keys()
		var ti := _i("style", sk.size())
		_desc_under(pick.call(e, "Mangekyō tarzı", String(Eyes.MS_STYLES[sk[ti]]["name"]), func(d): _step("style", d, sk.size()), false, _dots(ti, sk.size())),
			"%s — tarzın iki göz tekniği ve altı jutsusu açılır." % String(Eyes.MS_STYLES[sk[ti]]["theme"]))
	_btn_row(e, lw, "Gözü tak", "Seçili göz, seçili yuvaya takılır.", [["Uygula", "eye", again.call(func(): give_eye(_i("eye", EYES.size()), _i("side", SIDES.size()), _i("style", ms_style_keys().size())))]])
	# ---- jutsu
	var j = Menus._set_section(body, "scroll", "Jutsu Aç")
	_note(j, "Bildiğin jutsu: %d  ·  Güç %d" % [(pr.get("learned", []) as Array).size(), int(pr.get("level", 1))])
	var gs = unlock_groups()
	var gi := _i("group", gs.size())
	var gh = pick.call(j, "Grup", String(gs[gi][1]), func(d): _step("group", d, gs.size()), false, _dots(gi, gs.size()))
	_tail(gh, _of(gi, gs.size()))
	_desc_under(gh,
		"Öğrenilecek teknikler: hepsi, bir doğa, kekkei genkai, klan, senjutsu, göz ya da silah teknikleri. Gereken doğa / kekkei genkai de verilir.")
	_btn_row(j, lw, "Öğren", "Seçili gruptaki bütün teknikler öğrenilir. Yüksek rütbeli teknikleri atabilmek için Güç / ninjutsu ustalığı da gerekir (aşağıdan ayarla).",
		[["Uygula", "scroll", again.call(func(): Hud.msg("%d yeni jutsu öğrenildi." % unlock(String(unlock_groups()[_i("group", unlock_groups().size())][0])), Color(0.5, 0.85, 1.0)))]])
	_btn_row(j, lw, "Efsane Yolları", "Bütün Efsane Yolları'na katılırsın (pasif bonuslar) ve her yolun bütün tekniklerini öğrenirsin.",
		[["Hepsini öğren", "book", again.call(func(): Hud.msg("Efsane Yolları: %d yeni jutsu öğrenildi." % learn_paths(), Color(0.85, 0.7, 1.0)))]])
	# ---- güç / ustalık / rütbe
	var g = Menus._set_section(body, "star", "Güç ve Rütbe")
	_note(g, "Şu an  ·  Güç %d  ·  %s" % [int(pr.get("level", 1)), Data.RANKS[clampi(int(pr.get("rank", 0)), 0, Data.RANKS.size() - 1)]])
	var pi := _i("power", POWER_STEPS.size())
	if not sel.has("power"):
		pi = POWER_STEPS.find(100)
		sel["power"] = pi
	_desc_under(pick.call(g, "Güç", str(POWER_STEPS[pi]), func(d): _step("power", d, POWER_STEPS.size()), true, _dots(pi, POWER_STEPS.size())),
		"Ninjutsu, dövüş, chakra ve dayanıklılık ustalıkları bu Güç'e göre ayarlanır; can ve chakra da büyür.")
	_btn_row(g, lw, "Gücü ayarla", "Seçili Güç uygulanır.", [["Uygula", "star", again.call(func(): set_power(POWER_STEPS[_i("power", POWER_STEPS.size())]))]])
	var mi := _i("mastery", MASTERY_STEPS.size())
	if not sel.has("mastery"):
		mi = MASTERY_STEPS.find(100)
		sel["mastery"] = mi
	_desc_under(pick.call(g, "Tüm ustalıklar", str(MASTERY_STEPS[mi]), func(d): _step("mastery", d, MASTERY_STEPS.size()), true, _dots(mi, MASTERY_STEPS.size())),
		"On iki ustalığın hepsi (genjutsu, fūinjutsu, tıbbi, senjutsu, kuchiyose, shurikenjutsu...) bu değere ayarlanır.")
	_btn_row(g, lw, "Ustalıkları ayarla", "Seçili değer bütün ustalıklara uygulanır.", [["Uygula", "star", again.call(func(): set_all_mastery(MASTERY_STEPS[_i("mastery", MASTERY_STEPS.size())]))]])
	var ri := _i("rank", Data.RANKS.size())
	if not sel.has("rank"):
		ri = clampi(int(pr.get("rank", 0)), 0, Data.RANKS.size() - 1)
		sel["rank"] = ri
	_desc_under(pick.call(g, "Rütbe", Data.RANKS[ri], func(d): _step("rank", d, Data.RANKS.size()), false, _dots(ri, Data.RANKS.size())),
		"Rütbe gerçek terfiyle verilir (alın koruyucusu, rütbe kıyafeti, takım). Kage seçilirse köyde yemin töreni başlar.")
	var do_rank = func():
		var r = _i("rank", Data.RANKS.size())
		set_rank(r)
		if r < 6:
			redraw.call()
	_btn_row(g, lw, "Rütbeyi ver", "Seçili rütbe uygulanır.", [["Uygula", "check", do_rank]])
	# ---- kuyruklu canavar
	var b = Menus._set_section(body, "flame", "Kuyruklu Canavar")
	var held = TailedBeasts.held()
	_note(b, "Taşıdığın canavar: %s" % (", ".join(PackedStringArray(held.map(func(x): return beast_name(x)))) if not held.is_empty() else "yok"))
	var free = TailedBeasts.free_beasts()
	if free.is_empty():
		_note(b, "Şu an serbest kuyruklu canavar yok (hepsi bir taşıyıcıda ya da sende).", UI.TEXT)
	else:
		var bi := _i("beast", free.size())
		_desc_under(pick.call(b, "Canavar", beast_name(free[bi]), func(d): _step("beast", d, free.size()), true, _dots(bi, free.size())),
			"İninde ya da serbest dolaşan canavarlardan biri.")
		var do_jin = func():
			var fr = TailedBeasts.free_beasts()
			if not fr.is_empty():
				become_jinchuriki(fr[_i("beast", fr.size())])
		_btn_row(b, lw, "Jinchūriki ol", "Seçili canavar içine mühürlenir: [X] chakra pelerini, [X] basılı zihin dünyası, canavarın teknikleri.",
			[["Uygula", "flame", again.call(do_jin)]])
	if not held.is_empty():
		_btn_row(b, lw, "Tam bağ", "Taşıdığın canavarlarla güven tam olur: pelerin kademeleri açılır, canavar kontrolden çıkmaz.", [["Uygula", "heart", again.call(func(): full_bond())]])
	# ---- eşya
	var it = Menus._set_section(body, "bag", "Eşya Ver")
	var ci := _i("cat", ITEM_CATS.size())
	_desc_under(pick.call(it, "Tür", ITEM_CATS[ci][1], func(d):
		_step("cat", d, ITEM_CATS.size())
		sel["item"] = 0, false, _dots(ci, ITEM_CATS.size())), "Silahlar, kıyafet setleri, kafa / yüz eşyaları, sırt eşyaları ya da atılan aletler ve haplar.")
	var cat: String = ITEM_CATS[ci][0]
	var lst = items(cat)
	if not lst.is_empty():
		var ii := _i("item", lst.size())
		var ih = pick.call(it, "Eşya", String(lst[ii][1]), func(d): _step("item", d, lst.size()), false, _dots(ii, lst.size()))
		_tail(ih, _of(ii, lst.size()))
		_desc_under(ih,
			"Ok tuşları ya da fare tekeriyle hızlıca gez." if cat != "tool" else "Aletler onar onar verilir.")
		var buttons = [["Ver", "plus", again.call(func(): give_item(cat, items(cat)[_i("item", items(cat).size())][0], false))]]
		if cat != "tool":
			buttons.append(["Ver ve kuşan", "check", again.call(func(): give_item(cat, items(cat)[_i("item", items(cat).size())][0], true))])
		_btn_row(it, lw, "Seçili eşya", "Eşya envanterine eklenir (Tab > Ekipman / Envanter).", buttons)
		_btn_row(it, lw, "Bu türün hepsi", "Bu türde sahip olmadığın bütün eşyalar verilir.", [["Hepsini ver", "bag", again.call(func(): Hud.msg("%d eşya verildi." % give_all(cat), Color(0.9, 0.85, 0.6)))]])
	# ---- dünya
	var w = Menus._set_section(body, "map", "Işınlanma ve Dünya")
	var pl = places()
	if not pl.is_empty():
		var pli := _i("place", pl.size())
		var ph = pick.call(w, "Gidilecek yer", String(pl[pli][3]), func(d): _step("place", d, pl.size()), false, _dots(pli, pl.size()))
		_tail(ph, _of(pli, pl.size()))
		_desc_under(ph,
			"Köyler (keşfedilmemiş olanlar da), haritadaki önemli yerler ve ülkeler.")
		_btn_row(w, lw, "Işınlan", "Hızlı seyahatle seçili yere gidersin (menü kapanır).", [["Işınlan", "map", func(): teleport(_i("place", places().size()))]])
	var env = Game.world.get("env") if Game.world else null
	if env:
		var tod = float(env.time_of_day)
		var tn = 0
		for i in TIMES.size():
			if absf(fposmod(tod - float(TIMES[i][0]) + 0.5, 1.0) - 0.5) < absf(fposmod(tod - float(TIMES[tn][0]) + 0.5, 1.0) - 0.5):
				tn = i
		var th = pick.call(w, "Saat", TIMES[tn][1], func(d): set_time(float(TIMES[posmod(tn + d, TIMES.size())][0])), false, _dots(tn, TIMES.size()))
		_tail(th, "%02d:%02d" % [int(tod * 24.0), int(fmod(tod * 1440.0, 60.0))])
		_desc_under(th,
			"Günün saati hemen değişir; gün yine kendi akışıyla ilerler.")
		var wi := 0
		for i in WEATHERS.size():
			if WEATHERS[i][0] == weather:
				wi = i
		_desc_under(pick.call(w, "Hava", WEATHERS[wi][1], func(d): set_weather(String(WEATHERS[posmod(wi + d, WEATHERS.size())][0])), false, _dots(wi, WEATHERS.size())),
			"Hava durumu her yerde bu olur; \"Doğal\" bölgenin kendi havasına döner.")
