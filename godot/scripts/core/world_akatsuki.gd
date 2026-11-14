class_name WorldAkatsuki
extends RefCounted
## Akatsuki — animedeki işleyişiyle, dünyanın kendi verisinden (kullanıcı 2026-11-15: "lore accurate Akatsuki sistemi, katılma,
## mağarası; şimdikinden farklı olarak"). Eski sabit dokuz kişilik liste (Orgs.AKATSUKI) yalnız eski hikâye görevlerinde kalır.
##  · KURULUŞ  — güce takmış güçlü bir kaçak (WorldAmbition) örgütü kurar; S-rütbe GERÇEK kaçakları (WorldPeople) tek tek alır.
##  · YÜZÜKLER — on yüzük, on yer (零 lider). Üyeler ikişerli takım; ölenin yüzüğü boşalır, yerine yenisi alınır.
##  · PARA     — lider Rinnegan'a ulaşana dek örgüt ödül avcılığıyla para toplar (kanon: Kakuzu'nun kasası).
##  · AV       — lider Rinnegan sahibi olunca her takıma bir canavar düşer. Yakalanan canavar (taşıyıcı sökülürken ölür) mağarada
##               SEAL_T süren mühürle Gedō Mazō'ya girer (WorldJubi "mazo"); dokuzu dolunca On Kuyruk zinciri başlar.
##  · MAĞARA   — Ateş ile Rüzgâr ülkeleri arasında (kanon: Nehir Ülkesi); mühürlü kaya kapı, içeride heykel (world/akatsuki_cave.gd).
##  · OYUNCU   — yeterince ünlü kaçaksa çağrılır; kapıdaki üye dövüşle sınar; yüzük + pelerin + gerçek ortak. Ayrılan hain sayılır.
## Kayıt: Game.profile["aka"] = {leader, slots[10] (kişi kimliği | "" | "player"), cave [x, z], phase, assign {takım: canavar},
##        funds, me {ring, partner, test}, traitor}
## Canavar durumu: "aka_seal" (mağarada mühürleniyor; kayıtta seal_end)

const RINGS := ["Rei", "Sei", "Byaku", "Shu", "Gen", "Kū", "Nan", "Hoku", "San", "Gyoku"]
const KANJI := ["零", "青", "白", "朱", "玄", "空", "南", "北", "三", "玉"]
const FOUND_LV := 180       # kurucu: bu Güç'e ulaşmış güce takmış kaçak
const MEMBER_LV := 95       # jōnin üstü: S-rütbe kaçak olacak güç
const HUNT_MIN := 4         # canavar avı için en az üye
const SEAL_T := 270.0       # üç gün üç gece süren mühür (dünya saati sn)

static var _t := 0.0
static var _come_t := 0.0
static var _come_next := 1500.0


static func D() -> Dictionary:
	var pr: Dictionary = Game.profile
	if not pr.has("aka") or not pr["aka"] is Dictionary:
		pr["aka"] = {"leader": "", "slots": [], "cave": [], "phase": "", "assign": {}, "funds": 0, "me": {}}
	return pr["aka"]


static func exists() -> bool:
	return not Game.profile.is_empty() and Game.profile.has("aka") and String(D()["leader"]) != ""


static func _ok(id: String) -> bool:
	if id == "" or id == "player":
		return false
	var p = WorldPeople.get_p(id)
	return not p.is_empty() and WorldPeople.alive(p) and not p.get("missing", false)


static func leader() -> Dictionary:
	return WorldPeople.get_p(String(D()["leader"])) if exists() else {}


## Yaşayan üyeler (oyuncu hariç): kişi kayıtları
static func members() -> Array:
	var out = []
	if exists():
		for id in D()["slots"]:
			if _ok(String(id)):
				out.append(WorldPeople.get_p(String(id)))
	return out


static func slot_of(id: String) -> int:
	return (D()["slots"] as Array).find(id) if exists() else -1


static func is_member(p: Dictionary) -> bool:
	return exists() and slot_of(String(p.get("id", "?"))) >= 0


static func ring(i: int) -> String:
	return "%s (%s)" % [RINGS[i], KANJI[i]]


## Takım arkadaşı: 0-1, 2-3, 4-5 ... (kimlik ya da "")
static func partner_of(id: String) -> String:
	var i = slot_of(id)
	if i < 0:
		return ""
	return String(D()["slots"][i ^ 1])


static func player_in() -> bool:
	return exists() and slot_of("player") >= 0


static func cave_pos() -> Vector3:
	var c: Array = D()["cave"]
	if c.size() < 2:
		return Vector3.ZERO
	return Vector3(float(c[0]), Game.ground_height(float(c[0]), float(c[1])), float(c[1]))


static func _news(text: String, big := false) -> void:
	WorldNews.headline(text, Color(0.9, 0.3, 0.32))
	if big:
		Hud.banner("AKATSUKI", text, Color(0.85, 0.15, 0.18))
		Journal.add(text, "milestone")


# ------------------------------------------------------------------ dünya turu
static func world_tick() -> void:
	if Game.profile.is_empty():
		return
	if not exists():
		_found()
		return
	_cleanup()
	if not exists():
		return
	_recruit()
	_phase()
	_seals()
	if String(D()["phase"]) == "biju":
		_hunt()
	else:
		_bounty()


static func _candidates(min_lv: int) -> Array:
	return WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and WorldPeople.is_rogue(q) and not q.get("missing", false) and not q.has("run") and String(q.get("kage", "")) == "" and int(q["level"]) >= min_lv and not is_member(q) and WorldAmbition.beast_of(q) == "")


static func _found() -> void:
	var cs = _candidates(FOUND_LV).filter(func(q): return WorldAmbition.is_amb(q))
	if cs.is_empty():
		return
	cs.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	var p: Dictionary = cs[0]
	var d = D()
	d["leader"] = String(p["id"])
	var sl = []
	sl.resize(10)
	sl.fill("")
	sl[0] = String(p["id"])
	d["slots"] = sl
	d["phase"] = "kane"
	d["assign"] = {}
	d["funds"] = 0
	d["cave"] = _pick_cave()
	WorldAmbition._crime(p, "Akatsuki'yi kurdu")
	_news("%s, kızıl bulutlu siyah pelerinler giyen bir kaçaklar örgütü kurdu: Akatsuki. En tehlikeli kaçakları yanına çağırıyor." % String(p["name"]), true)


## Mağara: Ateş ile Rüzgâr ülkeleri arasında, köylerin dışında karada bir yer
static func _pick_cave() -> Array:
	var a = Game.village("konoha")
	var b = Game.village("suna")
	var mid = Vector2(a["x"], a["y"]).lerp(Vector2(b["x"], b["y"]), 0.5) if not a.is_empty() and not b.is_empty() else Vector2.ZERO
	var at = Game.from_map(mid)
	for k in 400:   # karada bir yer: sarmal arama (nehir / deniz üstüne kurulmaz)
		var ang = k * 2.4
		var q = Game.from_map(mid) + Vector3(cos(ang), 0, sin(ang)) * (k * 12.0)
		var h = Game.ground_height(q.x, q.z)
		if h < 8.0:
			continue
		var rough = 0.0   # düzlük: kaya kütlesi yamaca / kıyıya gömülmesin
		for j in 12:
			var o = Vector3(cos(j * TAU / 12.0), 0, sin(j * TAU / 12.0)) * (55.0 if j % 2 == 0 else 110.0)
			rough = maxf(rough, absf(Game.ground_height(q.x + o.x, q.z + o.z) - h))
		if rough < 7.0 or k > 360:
			at = q
			break
	return [at.x, at.z]


static func _cleanup() -> void:
	var d = D()
	var sl: Array = d["slots"]
	for i in sl.size():
		var id = String(sl[i])
		if id == "" or id == "player":
			continue
		if not _ok(id):
			var q = WorldPeople.get_p(id)
			sl[i] = ""
			(d["assign"] as Dictionary).erase(str(i / 2))
			if i > 0:
				_news("Akatsuki üyesi %s öldü; %s yüzüğü sahipsiz kaldı." % [String(q.get("name", "biri")), ring(i)])
	if not _ok(String(d["leader"])):
		var old = WorldPeople.get_p(String(d["leader"]))
		var ms = members()
		if ms.is_empty():
			_dissolve("Akatsuki'nin lideri %s öldü ve örgüt dağıldı." % String(old.get("name", "")))
			return
		ms.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
		var nl: Dictionary = ms[0]
		sl[slot_of(String(nl["id"]))] = ""
		sl[0] = String(nl["id"])
		d["leader"] = String(nl["id"])
		_news("Akatsuki'nin lideri %s öldü. Örgütün başına %s geçti." % [String(old.get("name", "")), String(nl["name"])], true)


static func _dissolve(text: String) -> void:
	var d = D()
	var bs = TailedBeasts.beasts()
	for id in bs:
		if String(bs[id].get("state", "")) == "aka_seal":
			bs[id]["state"] = "wild"
			bs[id].erase("seal_end")
	var was_in = player_in()
	d["leader"] = ""
	d["slots"] = []
	d["phase"] = ""
	d["assign"] = {}
	d["me"] = {}
	if was_in:
		Exams.flags()["akatsuki_member"] = false
	_news(text, true)


static func _recruit() -> void:
	var d = D()
	var sl: Array = d["slots"]
	var free = sl.find("", 1)
	if free < 0 or randf() > 0.15:
		return
	var cs = _candidates(MEMBER_LV)
	if cs.is_empty():
		# hazır kaçak yok: lider, köyüne bağı zayıf (yaslı, sadakatsiz) güçlü bir ninjayı ikna eder; o da köyünden kaçar
		var vs = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and not WorldPeople.is_rogue(q) and not q.get("missing", false) and String(q.get("kage", "")) == "" and int(q["level"]) >= MEMBER_LV and WorldAmbition.beast_of(q) == "" and (int(q.get("loyalty", 50)) < 45 or q.get("grief", false)))
		if vs.is_empty():
			return
		vs.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
		var v: Dictionary = vs[0]
		if WorldPeople.defect(v, "Akatsuki'nin çağrısına uyup köyüne sırt çevirdi").is_empty() and not WorldPeople.is_rogue(v):
			return
		cs = [v]
	cs.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	var p: Dictionary = cs[0]
	sl[free] = String(p["id"])
	WorldPeople.log_event(p, "Akatsuki'ye katıldı; %s yüzüğünü taktı" % ring(free))
	var mate = partner_of(String(p["id"]))
	_news("%s Akatsuki'ye katıldı ve %s yüzüğünü taktı%s." % [String(p["name"]), ring(free), ". Takım arkadaşı: %s" % String(WorldPeople.get_p(mate)["name"]) if _ok(mate) else ""])


static func _phase() -> void:
	var d = D()
	var l = leader()
	if String(d["phase"]) != "biju" and int((l.get("eye", [0, 0]) as Array)[0]) == 6 and members().size() >= HUNT_MIN:
		d["phase"] = "biju"
		_news("Akatsuki'nin lideri %s Rinnegan'a ulaştı. Örgüt artık kuyruklu canavarların peşinde: her takıma bir canavar düştü." % String(l["name"]), true)


## Para dönemi: takımlar ödül avına çıkar (Bingo Kitabı'ndaki başka kaçaklar, yüksek ödüllü ninjalar)
static func _bounty() -> void:
	if randf() > 0.12:
		return
	var d = D()
	var ms = members()
	if ms.size() < 2:
		return
	var hunter: Dictionary = ms.pick_random()
	var lv = int(hunter["level"])
	var prey = WorldPeople.all().values().filter(func(q): return WorldPeople.alive(q) and not is_member(q) and not q.get("missing", false) and String(q.get("kage", "")) == "" and int(q["rank"]) >= 2 and int(q["level"]) < lv - 20 and not WorldAmbition.is_amb(q))
	if prey.is_empty():
		return
	var q: Dictionary = prey.pick_random()
	WorldPeople._die(q, "Başına konan ödül için Akatsuki'den %s tarafından öldürüldü" % String(hunter["name"]))
	d["funds"] = int(d["funds"]) + 3000 + int(q["level"]) * 150
	WorldAmbition._crime(hunter, "%s'yi başındaki ödül için öldürdü" % String(q["name"]))
	_news("Akatsuki'den %s, %s'yi öldürüp cesedini ödül karşılığı teslim etti." % [String(hunter["name"]), String(q["name"])])


## Takımların avlayabileceği canavarlar (oyuncunun elindekiler hariç: onlar için oyuncuya gelinir)
static func _free_beasts() -> Array:
	var out = []
	var bs = TailedBeasts.beasts()
	for id in TailedBeasts.LAIRS:
		var b: Dictionary = bs.get(id, {})
		var st = String(b.get("state", "wild"))
		if not st in ["wild", "free", "host"] or (TailedBeasts.spawned.has(id) and is_instance_valid(TailedBeasts.spawned[id])):
			continue
		if st == "host" and (Missions.bingo_host_spawned(id) or is_member(WorldPeople.get_p(String((b.get("host", {}) as Dictionary).get("wp", ""))))):
			continue
		out.append(String(id))
	return out


static func _hunt() -> void:
	var d = D()
	var sl: Array = d["slots"]
	if not sealing().is_empty():
		return   # mühür töreni bütün üyeleri mağaraya bağlar (kanon): o sürerken ava çıkılmaz
	var free = _free_beasts()
	var asg: Dictionary = d["assign"]
	for pair in range(1, 5):   # lider takımı ava çıkmaz (kanon: Pain ve Konan Ame'de kalır)
		var team = [String(sl[pair * 2]), String(sl[pair * 2 + 1])].filter(func(id): return _ok(id))
		if team.is_empty():
			continue
		var key = str(pair)
		var tgt = String(asg.get(key, ""))
		if tgt == "" or not tgt in free:
			var open = free.filter(func(id): return not id in asg.values())
			if open.is_empty():
				asg.erase(key)
				continue
			tgt = String(open.pick_random())
			asg[key] = tgt
		var pw = 0.0
		for id in team:
			pw += float(WorldPeople.get_p(id)["level"])
		if randf() > 0.15:
			continue
		var names = " ve ".join(team.map(func(id): return String(WorldPeople.get_p(id)["name"])))
		var bn = TailedBeasts._bname(tgt)
		if randf() > clampf((pw - 180.0) / 500.0, 0.05, 0.6):
			if randf() < 0.3:
				_news("Akatsuki'den %s, %s'nin peşinde; bu kez eli boş döndü." % [names, bn])
			continue
		capture(tgt, names, team)
		asg.erase(key)
		return


## Canavar örgütün elinde: taşıyıcısı varsa sökülürken ölür; mağarada mühürleme başlar
static func capture(id: String, by_names: String, by_ids: Array = []) -> void:
	var b: Dictionary = TailedBeasts.beasts()[id]
	var bn = TailedBeasts._bname(id)
	if String(b.get("state", "")) == "host":
		var h: Dictionary = b["host"]
		var hw = WorldPeople.get_p(String(h.get("wp", "")))
		if not hw.is_empty() and WorldPeople.alive(hw):
			hw.erase("beast")
			WorldPeople._die(hw, "İçindeki %s Akatsuki tarafından söküldü" % bn)
		if h.get("rogue", false):
			Missions.remove_rogue_jinchuriki(id)
		b.erase("host")
	b.erase("ctrl_by")
	b["state"] = "aka_seal"
	b["seal_end"] = Aging.clock() + SEAL_T
	b["seal_by"] = by_ids
	var n = sealed_n() + 1
	_news("Akatsuki %s'yi ele geçirdi (%s). Mağaralarında üç gün sürecek mühürleme başladı — örgütün elindeki %d. canavar." % [bn, by_names, n], n == 1 or n >= 6)


static func sealed_n() -> int:
	var n = 0
	var bs = TailedBeasts.beasts()
	for id in bs:
		if String(bs[id].get("state", "")) in ["mazo", "aka_seal"]:
			n += 1
	return n


## Mühürlemesi süren canavarlar: [kimlik, kalan sn]
static func sealing() -> Array:
	var out = []
	var bs = TailedBeasts.beasts()
	for id in bs:
		if String(bs[id].get("state", "")) == "aka_seal":
			out.append([String(id), float(bs[id].get("seal_end", 0.0)) - Aging.clock()])
	return out


## Süresi dolan mühür: canavar Gedō Mazō'da (On Kuyruk zincirine girer)
static func _seals() -> void:
	var l = leader()
	if l.is_empty():
		return
	for s in sealing():
		if float(s[1]) <= 0.0:
			TailedBeasts.beasts()[s[0]].erase("seal_end")
			TailedBeasts.beasts()[s[0]].erase("seal_by")
			WorldJubi.D()["by"] = String(l["id"])
			WorldJubi._into_mazo(l, String(s[0]))


# ------------------------------------------------------------------ görünüş
## WorldPeople.arch_of: üye sahneye kızıl bulutlu pelerin ve çizik alın koruyucusuyla çıkar
static func dress(a: Dictionary, p: Dictionary) -> void:
	if not is_member(p):
		return
	var lk: Dictionary = a.get("look", {})
	lk["outer_style"] = "org_pelerin"
	lk["outer"] = Color(0.13, 0.14, 0.26)
	lk["outer_pattern"] = 6
	lk["outer_accent"] = Color(0.72, 0.07, 0.14)
	lk["band_style"] = "slashed"
	a["look"] = lk
	a["faction"] = "akatsuki"
	a["akatsuki"] = slot_of(String(p["id"]))


# ================================================================== sahne: mağara kapısı, sınav, katılma, tören, baskın
static var recruiter: Enemy = null
static var _cleared := Vector3.INF
static var mate: Enemy = null
static var raid: Array = []
static var hunters: Array = []


static func _inside() -> String:
	return Interiors.inst.inside if Interiors.inst else ""


static func _spawn(p: Dictionary, at: Vector3, team: String, parent: Node = null) -> Enemy:
	var e = Enemy.new()
	e.setup(WorldPeople.arch_of(p))
	(parent if parent != null else Game.player.get_tree().current_scene).add_child(e)
	e.global_position = at
	e.home = at
	e.team = team
	return e


static func tick(dt: float) -> void:
	if Game.profile.is_empty() or Game.player == null or not Game.profile.has("aka"):
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	if exists() and _cleared != cave_pos():   # mağaranın çevresinde ağaç çıkmaz (bitki örtüsü parçaları kurulmadan önce)
		_cleared = cave_pos()
		Roadside._add_clear(_cleared.x, -(_cleared.z - 15.0), 125.0)
	AkatsukiCave.sync()
	if not exists():
		return
	var d = D()
	var fl: Dictionary = Exams.flags()
	if player_in() != bool(fl.get("akatsuki_member", false)):
		if player_in():
			fl["akatsuki_member"] = true
		else:   # eski kayıt (tek tıkla katılmış) ya da örgüt yeniden kuruldu: boş yüzük varsa onu takar
			var free = (d["slots"] as Array).find("", 1)
			if free >= 0 and not d.get("traitor", false):
				d["slots"][free] = "player"
				d["me"] = {"ring": free}
			else:
				fl["akatsuki_member"] = false
	if player_in():   # üyeler üye oyuncuya saldırmaz
		for f in Game.player.get_tree().get_nodes_in_group("fighters"):
			if f is Enemy and f.team == "enemy" and int((f.arch as Dictionary).get("akatsuki", -1)) >= 0:
				f.team = "neutral"
	_gate_tick()
	_raid_tick()
	_come_tick()


# ------------------------------------------------------------------ çağrı
static func can_invite() -> bool:
	if not exists() or player_in() or D().get("traitor", false) or String((D()["me"] as Dictionary).get("test", "")) != "":
		return false
	return (D()["slots"] as Array).find("", 1) >= 0 and Orgs.is_rogue() and Orgs.rogue_rank() >= 3


## Yeni üyeyi, ortağı olacak kişi karşılar (kanon); o yoksa lider dışındaki en güçlü üye
static func _recruiter_p() -> Dictionary:
	var sl: Array = D()["slots"]
	var free = sl.find("", 1)
	if free >= 0 and (free ^ 1) != 0 and _ok(String(sl[free ^ 1])):
		return WorldPeople.get_p(String(sl[free ^ 1]))
	var ms = members().filter(func(q): return String(q["id"]) != String(D()["leader"]))
	if ms.is_empty():
		return leader()
	ms.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	return ms[0]


static func _mark() -> void:
	var c = AkatsukiCave.gate_pos() if is_instance_valid(AkatsukiCave.ext) else cave_pos() + Vector3(0, 0, 20.0)
	Game.profile["waypoint"] = [c.x, c.y, c.z, "Akatsuki mağarası"]
	Game.profile["track"] = "waypoint"


## Simsar aracılığıyla gelen çağrı (Orgs simsar penceresi)
static func invite_dialog() -> void:
	var l = leader()
	var r = _recruiter_p()
	if l.is_empty() or r.is_empty():
		return
	Hud.dialog("Yeraltı Simsarı", "Simsar sesini alçaltıyor: \"Kızıl bulutlular seni soruyor. Başlarında %s var; şu an %d kişiler ve bir yüzükleri sahipsiz. Seni görmek isteyen %s. Ateş ile Rüzgâr ülkeleri arasındaki mağaralarının önünde, torii'nin altında bekleyecek. Gidersen sınanırsın; gitmezsen bir daha sormazlar.\"" % [String(l["name"]), members().size(), String(r["name"])], [
		{"label": "Gideceğim", "tip": "Haritada mağara işaretlenir. Kapıda dövüşle sınanırsın.", "cb": func():
			D()["me"] = {"test": "go", "by": String(r["id"])}
			_mark()
			Hud.msg("Akatsuki mağarası haritada işaretlendi.", Color(0.9, 0.4, 0.4))},
		{"label": "İlgilenmiyorum", "cb": func(): pass}])


static func _gate_tick() -> void:
	var d = D()
	var me: Dictionary = d["me"]
	var st = String(me.get("test", ""))
	var out = _inside() == "" and is_instance_valid(AkatsukiCave.ext)
	var gp = AkatsukiCave.gate_pos() if out else Vector3.ZERO
	var near = out and Game.player.global_position.distance_to(gp) < 260.0
	if st == "go" or st == "duel":
		if not _ok(String(me.get("by", ""))):
			var r = _recruiter_p()
			if st == "duel" or r.is_empty():   # sınayan dövüşte öldü: yüzüğü boşaldı, yer senin
				me["test"] = "pass"
				Hud.banner("AKATSUKI", "Seni sınayan öldü. Mağaranın kapısı sana açık; içeride lider bekliyor.", Color(0.85, 0.15, 0.18))
				return
			me["by"] = String(r["id"])
		if near and not is_instance_valid(recruiter):
			if st == "duel":
				me["test"] = "go"
			recruiter = _spawn(WorldPeople.get_p(String(me["by"])), Missions.open_ground(gp + Vector3(3.0, 0, 2.0), 12.0), "neutral")
		elif st == "duel" and is_instance_valid(recruiter) and recruiter.hp <= recruiter.max_hp * 0.5:
			recruiter.team = "neutral"
			recruiter.hp = recruiter.max_hp
			me["test"] = "pass"
			Hud.dialog("%s — Akatsuki" % String(recruiter.arch.get("name", "")), "Elini kaldırıp dövüşü kesiyor: \"Yeter. Yüzüğü taşıyabilirsin. İçeri gir; lider seni bekliyor.\"", [])
	# üye oyuncunun ortağı: av görevi varken torii'nin altında bekler, oyuncuyla yola çıkar
	if player_in() and near and not is_instance_valid(mate) and (d["assign"] as Dictionary).has(str(slot_of("player") / 2)):
		var pid = partner_of("player")
		if _ok(pid):
			mate = Kage._real_ninja(WorldPeople.get_p(pid), "player")
			Game.player.get_tree().current_scene.add_child(mate)
			var q = Missions.open_ground(gp + Vector3(-3.0, 0, 2.0), 12.0)
			mate.global_position = q
			mate.home = q
			Hud.msg("Ortağın %s torii'nin altında seni bekliyor." % String(mate.arch.get("name", "")), Color(0.9, 0.4, 0.4))


## Kaya kapı ([F]): üyeye / sınavı geçene / bariyeri kırana açılır
static func gate(it: Dictionary) -> void:
	var me: Dictionary = D()["me"]
	var st = String(me.get("test", ""))
	if player_in() or st == "pass" or AkatsukiCave.broken:
		if Interiors.inst:
			Interiors.inst.enter({"pos": it["pos"], "out": (it["pos"] as Vector3) + Vector3(0, 0, 7.0), "room": "akatsuki_cave", "kind": "enter"})
	elif st == "go" and is_instance_valid(recruiter):
		Hud.dialog("%s — Akatsuki" % String(recruiter.arch.get("name", "")), "Kızıl bulutlu pelerinli ninja torii'nin altından sana bakıyor: \"Lider seni istiyor. Ben henüz ikna olmadım. Bu kayanın ardına yalnız yüzük taşıyanlar geçer; taşıyabilecek misin, göreceğiz.\"", [
			{"label": "Dövüş", "tip": "Onu canının yarısına indirirsen sınavı geçersin.", "cb": func():
				if is_instance_valid(recruiter):
					recruiter.team = "enemy"
					me["test"] = "duel"
					Hud.banner("SINAV", "%s seni sınıyor" % String(recruiter.arch.get("name", "")), Color(0.85, 0.15, 0.18))},
			{"label": "Henüz değil", "cb": func(): pass}])
	elif st == "duel":
		Hud.msg("Önce sınavı bitir.", Color(0.9, 0.4, 0.4))
	else:
		Hud.dialog("Mühürlü Kaya", "Dev bir kaya mağaranın ağzını tıkıyor; üstündeki 禁 etiketi chakrayla yanıyor: Gofū Kekkai. Kaya itmekle kıpırdamıyor.\n\nBu bariyer beş etiketle kurulur: biri burada, dördü çevredeki kayalarda. Dışarıdaki dördü birlikte sökülmeden kapıdaki düşmez.", [])


# ------------------------------------------------------------------ içerisi
## AkatsukiCave._dress bitince çağırır
static func inside_built(I: Interiors) -> void:
	raid = []
	var me: Dictionary = D()["me"]
	if player_in() or String(me.get("test", "")) == "pass":
		I.act(0, AkatsukiCave.STATUE_D - 48.0, 8.0, "aka_leader", "[F] Lidere seslen")
		if not player_in():
			leader_dialog()
		return
	# baskın (bariyeri kıran yabancı): mühür sürüyorsa canavarı getiren takım bedenen buradadır (ötekiler yalnız gölge)
	var ids = []
	var bs = TailedBeasts.beasts()
	for s in sealing():
		for id in bs[s[0]].get("seal_by", []):
			if _ok(String(id)) and not id in ids:
				ids.append(String(id))
	var k = 0
	for id in ids:
		raid.append(_spawn(WorldPeople.get_p(id), I.L(-6.0 + k * 12.0, 0.1, AkatsukiCave.STATUE_D - 52.0), "enemy", I.room))
		k += 1
	if not raid.is_empty():
		Hud.banner("AKATSUKI", "Mühür töreni sürüyor. Canavarı getirenler seni karşılıyor; onları durdurursan tören bozulur.", Color(0.85, 0.15, 0.18))
	elif not sealing().is_empty():
		_break_seal()
	else:
		Hud.msg("Salon boş. Heykelin açık gözleri: %d." % sealed_n(), Color(0.8, 0.75, 0.9))


static func _raid_tick() -> void:
	if raid.is_empty() or _inside() != "akatsuki_cave":
		raid = []
		return
	raid = raid.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	if raid.is_empty():
		_break_seal()


## Tören bozuldu: yarım kalan canavar heykelden kurtulur
static func _break_seal() -> void:
	var bs = TailedBeasts.beasts()
	var names = []
	for s in sealing():
		bs[s[0]]["state"] = "wild"
		bs[s[0]].erase("seal_end")
		bs[s[0]].erase("seal_by")
		names.append(TailedBeasts._bname(String(s[0])))
	AkatsukiCave.seal_fx_off()
	if not names.is_empty():
		_news("Akatsuki'nin mağarası basıldı ve mühür töreni bozuldu: %s heykelden kurtulup inine döndü." % ", ".join(names), true)


static func _join() -> void:
	var d = D()
	var sl: Array = d["slots"]
	var free = sl.find("", 1)
	if free < 0:
		Hud.msg("Sahipsiz yüzük kalmadı.", Color(0.9, 0.4, 0.4))
		return
	sl[free] = "player"
	d["me"] = {"ring": free}
	d.erase("traitor")
	Exams.flags()["akatsuki_member"] = true
	Gear.grant(Game.profile, "set_akatsuki", "set")
	Gear.apply_look(Game.profile)
	Game.player.rebuild_model()
	Orgs.add_infamy(300)
	var pid = partner_of("player")
	var pn = String(WorldPeople.get_p(pid)["name"]) if _ok(pid) else ""
	Hud.banner("AKATSUKI", "%s yüzüğü artık senin. %s" % [ring(free), ("Ortağın: %s." % pn) if pn != "" else "Ortağın henüz yok; yüzüğü sahipsiz."], Color(0.85, 0.15, 0.18))
	_news("%s Akatsuki'ye katıldı ve %s yüzüğünü taktı." % [String(Game.profile.get("name", "Bir kaçak")), ring(free)])
	if Game.profile.has("waypoint") and String(Game.profile["waypoint"][3]) == "Akatsuki mağarası":
		Game.profile.erase("waypoint")
		Game.profile["track"] = ""
	Game.save_game()


## Liderin gölgesiyle konuşma (heykelin önünde [F])
static func leader_dialog() -> void:
	var d = D()
	var l = leader()
	if l.is_empty():
		return
	var ln = String(l["name"])
	if not player_in():
		Hud.dialog("%s — Akatsuki'nin lideri" % ln, "Heykelin parmak ucundaki gölge sana dönüyor: \"Sınandın ve geçtin. Akatsuki'de herkes bir yüzük taşır, bir ortakla yürür. Yüzüğü takan geri çıkaramaz: ayrılan haindir ve peşine düşülür.\"", [
			{"label": "Yüzüğü tak", "cb": _join},
			{"label": "Vazgeç ve çık", "cb": func(): pass}])
		return
	var opts = []
	var seal = sealing()
	for id in TailedBeasts.jarred():
		var bid = String(id)
		opts.append({"label": "Teslim et: %s" % TailedBeasts._bname(bid), "tip": "Kaptaki canavar heykelin önüne bırakılır; mühür töreni başlar.", "cb": func():
			capture(bid, String(Game.profile.get("name", "Sen")), ["player"])
			d["funds"] = int(d["funds"]) + 20000
			if Interiors.inst and _inside() == "akatsuki_cave":
				AkatsukiCave.gather(Interiors.inst)})
	if not seal.is_empty():
		opts.append({"label": "Mühür törenine katıl", "tip": "Genryū Kyū Fūjin: bütün üyeler toplanır, tören bitene dek mağaradan çıkılmaz (dünyada zaman geçer).", "cb": ritual})
	elif String(d["phase"]) == "biju":
		var key = str(slot_of("player") / 2)
		var cur = String((d["assign"] as Dictionary).get(key, ""))
		opts.append({"label": "Av görevi iste" if cur == "" else "Avım neredeydi? (%s)" % TailedBeasts._bname(cur), "tip": "Takımına bir canavar düşer. Onu yen, mühür kabına al ve buraya getir.", "cb": func():
			var free = _free_beasts().filter(func(id): return not id in (d["assign"] as Dictionary).values())
			var tgt = cur if cur != "" else (String(free.pick_random()) if not free.is_empty() else "")
			if tgt == "":
				Hud.msg("%s: \"Şu an boşta canavar yok. Bekle.\"" % ln, Color(0.9, 0.4, 0.4))
				return
			d["assign"][key] = tgt
			var lp = Game.from_map(TailedBeasts.LAIRS[tgt])
			Game.profile["waypoint"] = [lp.x, Game.ground_height(lp.x, lp.z), lp.z, "Av: %s" % TailedBeasts._bname(tgt)]
			Game.profile["track"] = "waypoint"
			var pid = partner_of("player")
			Hud.msg("%s: \"%s senin. %s\"" % [ln, TailedBeasts._bname(tgt), ("Ortağın %s kapıda bekliyor." % String(WorldPeople.get_p(pid)["name"])) if _ok(pid) else "Ortağın yok; yalnız gideceksin."], Color(0.9, 0.4, 0.4))})
	else:
		opts.append({"label": "Şimdi ne yapıyoruz?", "cb": func():
			Hud.msg("%s: \"Önce para. Bingo Kitabı'ndaki ödüllü başlar kasamızı doldurur. Canavarların sırası sonra gelecek.\" (Kasa: %d Ryō)" % [ln, int(d["funds"])], Color(0.9, 0.4, 0.4))})
	opts.append({"label": "Örgütten ayrıl", "tip": "Yüzüğü bırakan haindir: üyeler seni gördüğü yerde saldırır, peşine takım yollanır.", "cb": func():
		Hud.dialog("%s — Akatsuki'nin lideri" % ln, "\"Akatsuki'den ayrılan olmaz. Yalnız hainler olur.\"", [{"label": "Yüzüğü çıkar", "cb": leave}, {"label": "Kalıyorum", "cb": func(): pass}])})
	Hud.dialog("%s — Akatsuki'nin lideri" % ln, "Gölge konuşuyor: \"%s.\"\n\nHeykeldeki canavar: %d / 9    Kasa: %d Ryō    Üye: %d" % ["Canavarları topluyoruz" if String(d["phase"]) == "biju" else "Örgüt güç ve para topluyor", sealed_n(), int(d["funds"]), members().size() + 1], opts)


static func leave() -> void:
	var d = D()
	var i = slot_of("player")
	if i >= 0:
		d["slots"][i] = ""
		(d["assign"] as Dictionary).erase(str(i / 2))
	d["me"] = {}
	d["traitor"] = true
	Exams.flags()["akatsuki_member"] = false
	for f in Game.player.get_tree().get_nodes_in_group("fighters"):
		if f is Enemy and int((f.arch as Dictionary).get("akatsuki", -1)) >= 0 and f.team != "enemy":
			f.team = "enemy"
	_news("%s Akatsuki'ye sırt çevirdi. Örgüt hainin peşinde." % String(Game.profile.get("name", "Bir üye")), true)
	Game.save_game()


## Mühür töreni: üyeler parmak uçlarında toplanır, dokuz ejder canavarı heykele çeker; tören bitene dek zaman geçer
static func ritual() -> void:
	var I = Interiors.inst
	if I == null or _inside() != "akatsuki_cave" or sealing().is_empty():
		return
	Hud.close_dialog()
	AkatsukiCave.gather(I)
	Hud.banner("GENRYŪ KYŪ FŪJIN", "Dokuz hayalet ejder canavarın chakrasını heykele çekiyor. Üç gün, üç gece.", Color(0.4, 0.65, 1.0))
	await I.get_tree().create_timer(7.0).timeout
	await I._fade(1.0, 1.4)
	var left = 0.0
	for s in sealing():
		left = maxf(left, float(s[1]))
	Game.profile["clock"] = Aging.clock() + maxf(0.0, left) + 1.0
	_seals()
	AkatsukiCave.seal_fx_off()
	if is_instance_valid(AkatsukiCave.statue):
		AkatsukiCave.statue.shake = 1.5
	Progress.add_ryo(12000)
	await I._fade(0.0, 1.4)
	Hud.banner("MÜHÜR TAMAMLANDI", "Heykelde %d canavar var. Payın: 12000 Ryō." % sealed_n(), Color(0.4, 0.65, 1.0))
	Game.save_game()


# ------------------------------------------------------------------ örgütün hedefi oyuncuysa
## Oyuncu jinchūriki ise (ya da hainse) bir takım onun için yola çıkar: önce haber, sonra gerçek üyeler gelir
static func _come_tick() -> void:
	var d = D()
	hunters = hunters.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	var want = d.get("traitor", false) or (String(d["phase"]) == "biju" and not player_in() and not TailedBeasts.held().is_empty())
	if not want:
		d.erase("come")
		return
	if not hunters.is_empty():
		return
	var now = Aging.clock()
	if not d.has("come"):
		if now < float(d.get("come_cd", 0.0)) or not sealing().is_empty():
			return
		var sl: Array = d["slots"]
		var pairs = [1, 2, 3, 4].filter(func(k): return _ok(String(sl[k * 2])) or _ok(String(sl[k * 2 + 1])))
		if pairs.is_empty():
			return
		var k: int = pairs.pick_random()
		var ids = [String(sl[k * 2]), String(sl[k * 2 + 1])].filter(func(id): return _ok(id))
		d["come"] = {"ids": ids, "at": now + 240.0}
		var names = " ve ".join(ids.map(func(id): return String(WorldPeople.get_p(id)["name"])))
		_news("Akatsuki'den %s yola çıktı: hedef sensin (%s)." % [names, "örgüte ihanet" if d.get("traitor", false) else "içindeki canavar"], true)
		return
	var c: Dictionary = d["come"]
	if now < float(c["at"]) or Missions.quiet() or _inside() != "":
		return
	var m = Game.to_map(Game.player.global_position)
	for v in Game.world_info.get("villages", []):
		if m.distance_to(Vector2(v["x"], v["y"])) < float(v["r"]) * 1.2:
			return   # köyün içinde gelmezler: dışarıda beklerler
	var pp = Game.player.global_position
	var dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var n = 0
	for id in c["ids"]:
		if _ok(String(id)):
			hunters.append(_spawn(WorldPeople.get_p(String(id)), Missions.open_ground(pp + dir * 85.0 + Vector3(n * 5.0, 0, 0), 30.0), "enemy"))
			n += 1
	d.erase("come")
	d["come_cd"] = now + 1500.0
	if n > 0:
		Hud.banner("KIZIL BULUTLAR", "Akatsuki seni buldu.", Color(0.85, 0.15, 0.18))
