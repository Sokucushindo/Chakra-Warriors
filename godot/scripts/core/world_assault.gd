class_name WorldAssault
extends RefCounted
## Köy saldırısı (kullanıcı 2026-11-14: "en güçlü takıntılılar dünyayı tehdit etsin — Pain tarzı köy saldırısı, Kage suikastı,
## köy yıkımı"; karar: KALICI YIKIM + ONARIM).
## Güce takmış kişilerden köy yıkacak kadar güçlenen biri (WorldAmbition), KENDİ verisinden çıkan bir sebeple bir köye yürür:
## sırt çevirdiği köyünden hesap sormak, o köyde yaşayan bir jinchūriki'nin canavarı, bir Senju'nun hücreleri, bir Mangekyō
## sahibinin gözleri. Önce haberi gelir (gözcüler yürüyüşünü görür), LEAD kadar sonra saldırı köyün GERÇEK yerinde olur:
##  · oyuncu o köydeyse canlı sahne: saldıran kapıdan girer, köyün gerçek ninjaları ve Kage'si savunur
##  · değilse güçlere göre sonuçlanır
## Sonuç kalıcıdır: savunanlar ölür, Kage ölebilir (halef seçilir), köyün bir bölümü yıkıntıya döner (WorldDamage kalıcı
## yıkıntı bölgesi) ve REBUILD süresinde dışından içine doğru yeniden inşa edilir.
## Kayıt: Game.profile["assault"] = {"next": saat, "plan": {who, vid, why, kind, ref, at}, "ruins": [{vid, x, z, r, t, dur, by}]}

const LEAD_MIN := 300.0
const LEAD_MAX := 480.0
const GAP := 1800.0        # iki saldırı arası en az (dünya saati sn; 450 sn = 1 yıl)
const REBUILD := 1350.0    # yıkıntının tamamen onarılması: 3 yıl
const MIN_POWER := 230.0   # köy yıkacak güç (Kage ~200)
const LIVE_MAX := 420.0
static var live := {}      # canlı sahne: {who, vid, e, allies, t, zone, grow_t, max_r}


static func D() -> Dictionary:
	var pr: Dictionary = Game.profile
	if not pr.has("assault") or not pr["assault"] is Dictionary:
		pr["assault"] = {"next": Aging.clock() + GAP * randf_range(0.5, 1.0), "plan": {}, "ruins": []}
	return pr["assault"]


## Yaşayan yıkıntı bölgeleri (süresi dolan silinir). WorldDamage her yarım saniyede okur.
static func ruins() -> Array:
	if Game.profile.is_empty() or not Game.profile.has("assault"):
		return []
	var rs: Array = D()["ruins"]
	var now = Aging.clock()
	for z in rs.duplicate():
		if now - float(z["t"]) >= float(z["dur"]):
			rs.erase(z)
	return rs


## Bölgenin şu anki yarıçapı: onarım dışından içine doğru ilerler
static func ruin_r(z: Dictionary) -> float:
	return float(z["r"]) * clampf(1.0 - (Aging.clock() - float(z["t"])) / float(z["dur"]), 0.0, 1.0)


static func ruined_at(pos: Vector3) -> bool:
	for z in ruins():
		if Vector2(pos.x - float(z["x"]), pos.z - float(z["z"])).length() <= ruin_r(z):
			return true
	return false


static func _add_ruin(vid: String, at: Vector3, r: float, by: String, is_live := false) -> Dictionary:
	D()["seq"] = int(D().get("seq", 0)) + 1
	var z = {"id": int(D()["seq"]), "vid": vid, "x": at.x, "z": at.z, "r": r, "t": Aging.clock(), "dur": REBUILD, "by": by}
	if is_live:
		z["live"] = true
	(D()["ruins"] as Array).append(z)
	return z


# ------------------------------------------------------------------ kim, nereye, neden
static func power(p: Dictionary) -> float:
	var k = int((p.get("eye", [0, 0]) as Array)[0])
	var x = float(p["level"])
	if k >= 5:
		x *= 1.25
	elif k == 4:
		x *= 1.1
	if WorldAmbition.beast_of(p) != "":
		x *= 1.3
	return x * (1.0 + 0.2 * WorldAmbition.ctrl_of(p).size())


static func _great(vid: String) -> bool:
	return vid in WorldPeople.MAJOR and not Game.village(vid).is_empty()


## Kişinin kendi hayatından çıkan saldırı sebepleri: [köy, sebep metni, tür, ilgili kayıt]
static func reasons(p: Dictionary) -> Array:
	var out = []
	var home = String(p["village"])
	var k = int((p.get("eye", [0, 0]) as Array)[0])
	if WorldPeople.is_rogue(p) and _great(home):
		out.append([home, "Sırt çevirdiği köyünden hesap sormaya geliyor.", "revenge", ""])
	var bs = TailedBeasts.beasts()
	if WorldAmbition.beast_of(p) == "" or (k >= 4 and WorldAmbition.ctrl_of(p).size() < int(WorldAmbition.CTRL_MAX.get(k, 0))):
		for id in bs:
			var b: Dictionary = bs[id]
			if String(b.get("state", "")) != "host":
				continue
			var h: Dictionary = b.get("host", {})
			var hv = String(h.get("village", ""))
			if h.get("rogue", false) or not _great(hv) or String(h.get("wp", "")) == String(p["id"]):
				continue
			out.append([hv, "%s'nin taşıyıcısının peşinde." % TailedBeasts._bname(id), "beast", String(id)])
	if k == 4 or k == 5:
		for q in WorldPeople.all().values():
			if q == p or not WorldPeople.alive(q) or WorldPeople.is_rogue(q) or not _great(String(q["village"])):
				continue
			if k == 4 and int((q.get("eye", [0, 0]) as Array)[0]) in [4, 5]:
				out.append([String(q["village"]), "%s'nin gözlerini istiyor." % String(q["name"]), "eyes", String(q["id"])])
			elif k == 5 and String(q.get("clan", "")) == "senju":
				out.append([String(q["village"]), "Senju %s'nin hücrelerini istiyor." % String(q["name"]), "cells", String(q["id"])])
	return out


static func candidates() -> Array:
	return WorldAmbition.people().filter(func(p): return not p.get("missing", false) and not p.has("run") and String(p.get("kage", "")) == "" and power(p) >= MIN_POWER and not reasons(p).is_empty())


## Dünya turu: sırası gelmişse yıkacak güce ulaşmış biri bir köye yürümeye karar verir
static func world_tick() -> void:
	var d = D()
	if not (d["plan"] as Dictionary).is_empty() or not live.is_empty() or Aging.clock() < float(d["next"]):
		return
	var cs = candidates()
	if cs.is_empty():
		return
	cs.sort_custom(func(a, b): return power(a) > power(b))
	plan(cs[0], randf_range(LEAD_MIN, LEAD_MAX))


static func plan(p: Dictionary, lead: float, vid := "") -> bool:
	var rs = reasons(p)
	if vid != "":
		rs = rs.filter(func(r): return String(r[0]) == vid)
	if rs.is_empty():
		return false
	var r: Array = rs.pick_random()
	D()["plan"] = {"who": String(p["id"]), "vid": String(r[0]), "why": String(r[1]), "kind": String(r[2]), "ref": String(r[3]), "at": Aging.clock() + lead}
	var vn = WorldPeople.vname(String(r[0]))
	WorldPeople.log_event(p, "%s'e doğru yürüyüşe geçti" % vn)
	var text = "%s, %s'e doğru yürüyor. %s Köy alarmda." % [String(p["name"]), vn, String(r[1])]
	WorldNews.headline(text, Color(1.0, 0.4, 0.35))
	if String(r[0]) == Progress.home():
		Hud.banner("KÖYÜN TEHLİKEDE", "%s %s'e yürüyor. %s" % [String(p["name"]), vn, String(r[1])], Color(1.0, 0.35, 0.3))
		Journal.add("%s köyüme doğru yürüyor. %s" % [String(p["name"]), String(r[1])], "milestone")
	return true


static func _player_in(vid: String, k := 1.15) -> bool:
	var v = Game.village(vid)
	if v.is_empty() or Game.player == null:
		return false
	return Game.to_map(Game.player.global_position).distance_to(Vector2(v["x"], v["y"])) < float(v["r"]) * k


## Her kare: saldırı saati geldiyse vurur; canlı sahneyi izler
static func tick(dt: float) -> void:
	if Game.profile.is_empty() or Game.player == null:
		return
	if not live.is_empty():
		_live_tick(dt)
		return
	if not Game.profile.has("assault"):
		return
	var pl: Dictionary = D()["plan"]
	if pl.is_empty() or Aging.clock() < float(pl["at"]):
		return
	var p = WorldPeople.get_p(String(pl["who"]))
	if p.is_empty() or not WorldPeople.alive(p) or p.get("missing", false):
		D()["plan"] = {}
		return
	var vid = String(pl["vid"])
	if _player_in(vid):
		if Missions.quiet():
			return   # oyuncu o köyde bir işin ortasında: saldıran iş bitene dek kapıya dayanmaz (görev sırasında olay yok)
		_live(p, pl)
	else:
		_abstract(p, pl, 1.0, {})
	D()["plan"] = {}


# ------------------------------------------------------------------ sonuç
static func _kage_lv(vid: String) -> float:
	if Kage.is_kage() and vid == Progress.home():
		return 0.0   # Kage oyuncu ve köyde değil: köy lidersiz savunur
	for q in WorldPeople.all().values():
		if String(q.get("kage", "")) == vid and WorldPeople.alive(q):
			return maxf(200.0, float(q["level"]))
	return 200.0


static func _gate_dir(vid: String) -> Vector2:
	var gates: Array = Game.village(vid).get("gates", [180.0])
	var g = deg_to_rad(float(gates.pick_random())) if not gates.is_empty() else randf() * TAU
	return Vector2(sin(g), cos(g))


## Güçlere göre sonuç. zone verilmişse (canlı sahneden kalan) yeni bölge açılmaz, o büyür.
static func _abstract(p: Dictionary, pl: Dictionary, bonus: float, zone: Dictionary) -> void:
	var vid = String(pl["vid"])
	var v = Game.village(vid)
	var vn = WorldPeople.vname(vid)
	var nm = String(p["name"])
	var defs: Array = WorldDay.war_party(vid, 8)
	var dv = _kage_lv(vid)
	for q in defs:
		dv += float(q["level"]) * 0.3
	var ratio = power(p) * randf_range(0.8, 1.2) * bonus / maxf(1.0, dv * randf_range(0.8, 1.2))
	var vr = float(v["r"])
	var c = Vector2(v["x"], v["y"])
	var dir = _gate_dir(vid)
	var r: float
	var depth: float
	var dead_n: int
	var kage_p: float
	var die_p: float
	if ratio < 0.8:
		r = randf_range(40.0, 55.0); depth = 0.78; dead_n = randi_range(1, 2); kage_p = 0.0; die_p = 0.5
	elif ratio < 1.2:
		r = randf_range(80.0, 110.0); depth = 0.5; dead_n = randi_range(3, 5); kage_p = 0.3; die_p = 0.35
	else:
		r = minf(vr * 0.45, randf_range(140.0, 190.0)); depth = 0.2; dead_n = randi_range(6, 9); kage_p = 0.7; die_p = 0.0
	if zone.is_empty():
		zone = _add_ruin(vid, Game.from_map(c + dir * vr * depth), r, nm)
	else:
		zone["r"] = maxf(float(zone["r"]), r)
		zone["t"] = Aging.clock()
	defs.shuffle()
	var fallen = []
	for q in defs.slice(0, dead_n):
		WorldPeople._die(q, "%s saldırısında köyünü savunurken öldü" % WorldNews.sfx(nm, "in"))
		fallen.append(String(q["name"]))
	var kage_dead = false
	if randf() < kage_p and not (Kage.is_kage() and vid == Progress.home()):
		kage_dead = true
		Kage.kage_killed(vid, false)
	var txt: String
	if randf() < die_p:
		WorldPeople._die(p, "%s saldırısında öldürüldü" % vn)
		var be = WorldPeople.bingo_of(p)
		if not be.is_empty():
			be["status"] = "dead"
		txt = "%s, %s'e saldırdı ve köyün ninjaları tarafından öldürüldü. Köyün bir mahallesi yıkıldı, %d ninja öldü." % [nm, vn, fallen.size()]
	else:
		p["level"] = mini(320, int(p["level"]) + randi_range(4, 10))
		WorldAmbition._crime(p, "%s'e saldırdı; %d ninja öldü%s" % [vn, fallen.size(), ", Kage'yi öldürdü" if kage_dead else ""])
		if ratio >= 0.8:
			_spoils(p, pl)
		if ratio < 0.8:
			txt = "%s, %s'e saldırdı; püskürtüldü ama kaçmayı başardı. %d ninja öldü." % [nm, vn, fallen.size()]
		elif ratio < 1.2:
			txt = "%s, %s'e saldırdı. Köyün büyük bir bölümü yıkıldı, %d ninja öldü; saldıran çekildi." % [nm, vn, fallen.size()]
		else:
			txt = "%s, %s'i yerle bir etti. Köyün yarısı yıkıntı, %d ninja öldü. Kimse onu durduramadı." % [nm, vn, fallen.size()]
	_announce(vid, "%s SALDIRIYA UĞRADI" % vn.to_upper(), txt)
	D()["next"] = Aging.clock() + GAP * randf_range(0.8, 1.4)


## Saldıran istediğini alır: canavar (taşıyıcı ölür), gözler, hücreler
static func _spoils(p: Dictionary, pl: Dictionary) -> void:
	var ref = String(pl.get("ref", ""))
	match String(pl.get("kind", "")):
		"beast":
			var b: Dictionary = TailedBeasts.beasts().get(ref, {})
			if String(b.get("state", "")) == "host" and String((b.get("host", {}) as Dictionary).get("wp", "")) != String(p["id"]):
				WorldAmbition.claim(p, ref)
		"eyes":
			var q = WorldPeople.get_p(ref)
			if not q.is_empty() and WorldPeople.alive(q) and int(p["eye"][0]) == 4:
				p["eye"] = [5, 3]
				WorldPeople._die(q, "Gözleri için %s tarafından öldürüldü" % String(p["name"]))
				WorldAmbition._crime(p, "%s'yi öldürüp gözlerini nakletti: Ebedi Mangekyō Sharingan" % String(q["name"]))
				WorldPeople._learn(p)
		"cells":
			var q2 = WorldPeople.get_p(ref)
			if not q2.is_empty() and WorldPeople.alive(q2) and int(p["eye"][0]) == 5:
				p["eye"] = [6, 3]
				WorldPeople._die(q2, "Hücreleri için %s tarafından öldürüldü" % String(p["name"]))
				WorldAmbition._crime(p, "Senju %s'yi öldürüp hücrelerini kendine nakletti: Rinnegan uyandı" % String(q2["name"]))
				WorldPeople._learn(p)


static func _announce(vid: String, title: String, text: String) -> void:
	Hud.banner(title, text, Color(1.0, 0.35, 0.3))
	WorldNews.headline(text, Color(1.0, 0.45, 0.4))
	if vid == Progress.home():
		Journal.add(text, "milestone")


# ------------------------------------------------------------------ canlı sahne (oyuncu o köyde)
static func _live(p: Dictionary, pl: Dictionary) -> void:
	var vid = String(pl["vid"])
	var v = Game.village(vid)
	var c = Vector2(v["x"], v["y"])
	var dir = _gate_dir(vid)
	var at = Missions.open_ground(Game.from_map(c + dir * float(v["r"]) * 0.86), 40.0)
	var inward = Game.from_map(c) - at
	inward.y = 0
	inward = inward.normalized() if inward.length() > 1.0 else Vector3.FORWARD
	var zone = _add_ruin(vid, at + inward * 45.0, 42.0, String(p["name"]), true)
	zone["r_max"] = clampf(power(p) * 0.36, 70.0, 150.0)
	live = {"who": String(p["id"]), "vid": vid, "plan": pl.duplicate(), "e": null, "allies": [], "t": 0.0, "zone": zone, "grow_t": 22.0, "max_r": float(zone["r_max"]), "in": inward, "at": at, "on": false}
	Game.profile["waypoint"] = [at.x, at.y, at.z, "Olay: Köy Saldırısı"]
	Game.profile["track"] = "waypoint"
	if Game.world and Game.world.env:
		Game.world.env.add_shake(1.4)
	Sfx.play("boom", null, 1.0, 0.5)
	Hud.banner("%s SALDIRIYOR" % String(p["name"]).to_upper(), "%s'in kapısını yıktı. %s" % [WorldPeople.vname(vid), String(pl["why"])], Color(1.0, 0.3, 0.25))


## Dövüşçüler oyuncu savaş alanına yaklaşınca sahneye çıkar (uzaktaki dövüşçü işlemez: 1 km ötede kimse vuruşmuyordu).
## Oyuncu hiç gelmezse saldırı FAR_MAX sonra güçlere göre biter; o sırada yıkım büyümeye devam eder.
const NEAR := 320.0
const FAR_MAX := 150.0
static func _enter() -> void:
	var p = WorldPeople.get_p(String(live["who"]))
	var vid = String(live["vid"])
	var at: Vector3 = live["at"]
	var inward: Vector3 = live["in"]
	var tree = Game.player.get_tree()
	var e = Enemy.new()
	e.setup(WorldPeople.arch_of(p))
	tree.current_scene.add_child(e)
	var q0 = Missions.open_ground(at + inward * 30.0, 25.0)
	e.global_position = q0
	e.home = q0
	live["e"] = e
	live["on"] = true
	var guards: Array = WorldDay.war_party(vid, 8, false)
	for wp in guards:
		var d: Enemy = Kage._real_ninja(wp, "player")
		tree.current_scene.add_child(d)
		var q = Missions.open_ground(at + inward * randf_range(48.0, 62.0) + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14)), 25.0)
		d.global_position = q
		d.home = q
		d.wander_to = q0
		WorldPeople.log_event(wp, "Köyü %s saldırısına karşı savundu" % WorldNews.sfx(String(p["name"]), "in"))
		(live["allies"] as Array).append(d)
	if not (Kage.is_kage() and vid == Progress.home()):
		var kg: Enemy = Orgs.kage_fighter(vid)
		kg.team = "player"
		kg.set_meta("teammate", true)
		kg.set_meta("respawn", false)
		kg.remove_meta("village_guard")
		kg.remove_meta("faction")
		kg.display_name = Kage.kage_name(vid)
		var q2 = Missions.open_ground(at + inward * 66.0, 25.0)
		kg.global_position = q2
		kg.home = q2
		kg.wander_to = q0
		(live["allies"] as Array).append(kg)


static func _live_tick(dt: float) -> void:
	live["t"] = float(live["t"]) + dt
	# yıkım saldıranla birlikte büyür (oyuncu görse de görmese de)
	live["grow_t"] = float(live["grow_t"]) - dt
	if float(live["grow_t"]) <= 0.0:
		live["grow_t"] = 22.0
		var z: Dictionary = live["zone"]
		if float(z["r"]) < float(live["max_r"]):
			z["r"] = minf(float(live["max_r"]), float(z["r"]) + 14.0)
			z["t"] = Aging.clock()
			if Game.world and Game.world.env and (live["at"] as Vector3).distance_to(Game.player.global_position) < 250.0:
				Game.world.env.add_shake(0.6)
	if not live["on"]:
		if (live["at"] as Vector3).distance_to(Game.player.global_position) < NEAR and not Missions.quiet():
			_enter()
		elif float(live["t"]) > FAR_MAX or not _player_in(String(live["vid"]), 1.6):
			_live_end("away")
		return
	var e = live["e"]
	if not is_instance_valid(e) or e.is_dead():
		_live_end("dead")
		return
	if float(live["t"]) > LIVE_MAX or not _player_in(String(live["vid"]), 1.6):
		_live_end("away")
		return
	var allies: Array = (live["allies"] as Array).filter(func(d): return is_instance_valid(d) and not d.is_dead())
	# savunanlar boşta beklemez; saldıran da en yakın savunana / oyuncuya döner
	for d in allies:
		if d.target != null and is_instance_valid(d.target) and not d.target.is_dead():
			continue
		d.home = e.global_position
		if d.global_position.distance_to(e.global_position) < 45.0:
			d.target = e
			d.state = "chase"
		else:
			d.wander_to = e.global_position
	if e.target == null or not is_instance_valid(e.target) or e.target.is_dead():
		var best: Node3D = null
		var bd = 90.0
		for d in allies + [Game.player]:
			var dd = e.global_position.distance_to(d.global_position)
			if dd < bd:
				bd = dd
				best = d
		if best != null:
			e.target = best
			e.state = "chase"


## Oyuncu canlı sahnede yenildi: saldırı onsuz sürer ve güçlere göre biter
static func player_defeated() -> void:
	if not live.is_empty():
		_live_end("lost")


static func _live_end(kind: String) -> void:
	var lv = live
	live = {}
	var p = WorldPeople.get_p(String(lv["who"]))
	var vid = String(lv["vid"])
	var zone: Dictionary = lv["zone"]
	zone.erase("live")
	zone.erase("r_max")
	for d in lv["allies"]:
		if is_instance_valid(d) and not d.is_dead():
			d.queue_free()
	if Game.profile.has("waypoint") and String(Game.profile["waypoint"][3]) == "Olay: Köy Saldırısı":
		Game.profile.erase("waypoint")
		Game.profile["track"] = ""
	var e = lv["e"]
	if kind == "dead":
		if not p.is_empty() and WorldPeople.alive(p):
			WorldPeople._die(p, "%s saldırısında öldürüldü" % WorldPeople.vname(vid))
		var be = WorldPeople.bingo_of(p) if not p.is_empty() else {}
		if not be.is_empty():
			be["status"] = "dead"
		Missions._rep(vid, 40)
		_announce(vid, "KÖY KURTULDU", "%s, %s'e saldırırken öldürüldü. Yıkılan mahalle yeniden inşa edilecek." % [String(p.get("name", "Saldıran")), WorldPeople.vname(vid)])
		D()["next"] = Aging.clock() + GAP * randf_range(0.8, 1.4)
		return
	if e != null and is_instance_valid(e):
		e.queue_free()
	if not p.is_empty() and WorldPeople.alive(p):
		_abstract(p, lv["plan"], 1.1 if kind == "lost" else 1.0, zone)
