class_name WorldJubi
extends RefCounted
## On Kuyruk (kullanıcı kararı 2026-11-14: "önce patron, sonra sayım").
## Zincir dünyanın kendi verisinden doğar, oyuncu orada olmasa da işler:
##  1. TOPLAMA  — Rinnegan'a ulaşmış güce takmış biri (WorldAmbition) emrine aldığı / bedenine mühürlediği canavarları tek tek
##                Gedō Mazō'ya mühürler, kalanların peşine düşer (taşıyıcıları öldürür; oyuncudaysa oyuncunun peşine düşer).
##  2. DİRİLİŞ  — dokuzu da heykeldeyse haber gelir; REVIVE_LEAD sonra On Kuyruk bir canavar ininde dirilir.
##  3. PATRON   — On Kuyruk gerçek yerinde durur (yaklaşan oyuncu onu görür ve dövüşebilir), STRIKE_GAP'te bir en yakın büyük
##                köye yürüyüp bir bölümünü kalıcı yıkıntıya çevirir (WorldAssault yıkıntısı), savunanları öldürür.
##                Durdurma: oyuncu diz çöktürüp canavarları çekip çıkarır (ya da Rinnegan'ı varsa kendi bedenine çeker);
##                beş köyün birleşik ordusu da küçük bir ihtimalle kendi başına durdurur.
##  4. AĞAÇ     — STRIKES_TO_TREE köyden sonra Tanrı Ağacı'na dönüşür; ay kızarmaya başlar, MOON sonra Mugen Tsukuyomi.
##                Durdurma: ağacın dibindeki bekçi (toplayan hayattaysa On Kuyruk jinchūrikisi olarak o, değilse On Kuyruk).
##  5. RÜYA     — sayım biterse herkes rüyaya hapsolur; yıllar sonra uyanılır (dünya ve oyuncu o kadar yaşlanmış).
## Oyuncunun yolu: Rinnegan + dokuz canavar mühür kabında → Gedō Mazō'yu çağırıp diriltir → Rikudō Jūbi Kyūin ile bedenine çeker.
## Kayıt: Game.profile["jubi"] = {stage, by, mazo, x, z, at, strikes, hit, moon, guard, ally_t, warn}
## Canavar durumları: "mazo" (heykelde), "jubi" (On Kuyruk'un içinde), "jubi_mine" (oyuncunun On Kuyruk'unda)

const NINE := ["shukaku", "matatabi", "isobu", "son_goku", "kokuo", "saiken", "chomei", "gyuki", "kurama"]
const REVIVE_LEAD := 360.0
const STRIKE_GAP := 540.0        # iki köy arası (dünya saati sn; 450 sn = 1 yıl)
const STRIKES_TO_TREE := 3
const MOON := 1800.0             # ağaç dikildikten Mugen Tsukuyomi'ye: 4 yıl
const SHOW_R := 2600.0           # On Kuyruk bu mesafeden sahnede (dev: uzaktan görünür)
const TREE_R := 3800.0
const GUARD_R := 520.0
const GIFTS := ["gudodama", "rikudo_sennin_modo", "rikudo_senjutsu", "rikudo_no_yo_no_chikara", "rikudo_no_in_no_chikara"]

static var actor: TailedBeast = null
static var tree: ShinjuTree = null
static var guard = null   # Enemy (toplayan) ya da TailedBeast
static var _t := 0.0
static var _ending := false
static var _tinted := false


static func D() -> Dictionary:
	var pr: Dictionary = Game.profile
	if not pr.has("jubi") or not pr["jubi"] is Dictionary:
		pr["jubi"] = {"stage": "", "by": "", "mazo": [], "x": 0.0, "z": 0.0, "at": 0.0, "strikes": 0, "hit": [], "moon": 0.0}
	return pr["jubi"]


static func stage() -> String:
	if Game.profile.is_empty() or not Game.profile.has("jubi"):
		return ""
	return String(D()["stage"])


## Toplayan: hayatta, kayıp değil, Rinnegan'ı duruyor
static func collector() -> Dictionary:
	var id = String(D()["by"])
	if id == "":
		return {}
	var p = WorldPeople.get_p(id)
	if p.is_empty() or not WorldPeople.alive(p) or p.get("missing", false) or int((p.get("eye", [0, 0]) as Array)[0]) != 6:
		return {}
	return p


static func site() -> Vector3:
	var d = D()
	return Vector3(float(d["x"]), Game.ground_height(float(d["x"]), float(d["z"])), float(d["z"]))


static func _dist() -> float:
	var s = site()
	var pp = Game.player.global_position
	return Vector2(pp.x - s.x, pp.z - s.z).length()


static func _scene() -> Node:
	return Game.player.get_tree().current_scene


# ------------------------------------------------------------------ 1. toplama (dünya turu)
static func world_tick() -> void:
	if Game.profile.is_empty():
		return
	var d = D()
	var st = String(d["stage"])
	if st != "" and st != "gather":
		return
	var p = collector()
	if p.is_empty():
		if String(d["by"]) != "":
			var old = WorldPeople.get_p(String(d["by"]))
			if not (d["mazo"] as Array).is_empty():
				WorldNews.headline("%s artık Gedō Mazō'yu tutamıyor; heykele mühürlü %d canavar zincirlerinden kurtulup inlerine döndü." % [String(old.get("name", "Heykelin sahibi")), (d["mazo"] as Array).size()], Color(0.8, 0.9, 1.0))
			_release()
			d["by"] = ""
			d["stage"] = ""
		var cs = WorldAmbition.people().filter(func(q): return not q.get("missing", false) and String(q.get("kage", "")) == "" and int((q.get("eye", [0, 0]) as Array)[0]) == 6)
		if WorldAkatsuki.exists():   # örgüt varken heykel örgütün liderinindir
			cs = cs.filter(func(q): return String(q["id"]) == String(WorldAkatsuki.D()["leader"]))
		if cs.is_empty():
			return
		cs.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
		p = cs[0]
		d["by"] = String(p["id"])
	var own: Array = WorldAmbition.ctrl_of(p).duplicate()
	var hb = WorldAmbition.beast_of(p)
	if hb != "":
		own.append(hb)
	if not own.is_empty():
		_into_mazo(p, String(own[0]))
	elif randf() < 0.5 and not WorldAkatsuki.is_member(p):   # örgüt lideri ava kendi çıkmaz, takımları çıkar
		WorldAmbition._beast(p)
	if (d["mazo"] as Array).size() >= NINE.size():
		_announce_revive(p)


static func _into_mazo(p: Dictionary, id: String) -> void:
	var d = D()
	var b: Dictionary = TailedBeasts.beasts()[id]
	if String(b.get("state", "")) == "host" and (b.get("host", {}) as Dictionary).get("rogue", false):
		Missions.remove_rogue_jinchuriki(id)
	b["state"] = "mazo"
	b.erase("ctrl_by")
	b.erase("host")
	if String(p.get("beast", "")) == id:
		p.erase("beast")
	if p.has("amb"):
		(p["amb"]["ctrl"] as Array).erase(id)
	if not id in d["mazo"]:
		(d["mazo"] as Array).append(id)
	d["stage"] = "gather"
	var n = (d["mazo"] as Array).size()
	var bn = TailedBeasts._bname(id)
	WorldAmbition._crime(p, "%s'yi Gedō Mazō'ya mühürledi (%d/9)" % [bn, n])
	var text = "%s, %s'yi Gedō Mazō'ya mühürledi. Heykelin dokuz gözünden %d'i açıldı." % [String(p["name"]), bn, n]
	WorldNews.headline(text, Color(0.85, 0.5, 0.9))
	if n == 1 or n >= 6:
		Hud.banner("GEDŌ MAZŌ", text, Color(0.8, 0.45, 0.9))
		Journal.add(text, "milestone")


static func _announce_revive(p: Dictionary) -> void:
	var d = D()
	var lair: Vector2 = TailedBeasts.LAIRS[TailedBeasts.LAIRS.keys().pick_random()]
	var at = Game.from_map(lair)
	d["x"] = at.x
	d["z"] = at.z
	d["stage"] = "revive"
	d["at"] = Aging.clock() + REVIVE_LEAD
	var text = "Dokuz canavarın dokuzu da %s'nin elinde. Gedō Mazō'nun bütün gözleri açıldı; On Kuyruk dirilmek üzere." % String(p["name"])
	WorldNews.headline(text, Color(1.0, 0.35, 0.35))
	Hud.banner("DOKUZ CANAVAR TOPLANDI", text, Color(1.0, 0.3, 0.3))
	Journal.add(text, "milestone")
	_mark("Olay: On Kuyruk'un dirilişi")


static func _mark(label: String) -> void:
	var s = site()
	Game.profile["waypoint"] = [s.x, s.y, s.z, label]
	Game.profile["track"] = "waypoint"


static func _unmark() -> void:
	if Game.profile.has("waypoint") and String(Game.profile["waypoint"][3]).begins_with("Olay: On Kuyruk"):
		Game.profile.erase("waypoint")
		Game.profile["track"] = ""


## Heykeldeki / On Kuyruk'un içindeki canavarlar serbest kalıp inlerine döner
static func _release() -> void:
	var bs = TailedBeasts.beasts()
	for id in NINE:
		var b: Dictionary = bs.get(id, {})
		if String(b.get("state", "")) in ["mazo", "jubi", "jubi_mine"]:
			b["state"] = "wild"
			b.erase("ctrl_by")
			b.erase("host")
	D()["mazo"] = []


# ------------------------------------------------------------------ her kare
static func tick(dt: float) -> void:
	if Game.profile.is_empty() or Game.player == null or not Game.profile.has("jubi"):
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var d = D()
	var now = Aging.clock()
	match String(d["stage"]):
		"revive":
			if now >= float(d["at"]):
				_revive()
		"boss":
			_sync_actor(false)
			if now >= float(d["at"]):
				_strike()
		"tree":
			_sync_tree()
			_moon()
		"dream":
			_dream()
		"mine":
			_sync_actor(true)
		_:
			_clear_nodes()


static func _clear_nodes() -> void:
	if is_instance_valid(actor) and not actor.dead:
		actor.queue_free()
	actor = null
	if is_instance_valid(guard) and guard != null and not guard.is_dead():
		guard.queue_free()
	guard = null
	if is_instance_valid(tree):
		tree.wither()
	tree = null
	_tint(0.0)
	Hud.doom("")


static func _tint(a: float) -> void:
	if Game.world == null or Game.world.env == null:
		return
	var env = Game.world.env
	if a <= 0.0:
		if _tinted:
			_tinted = false
			env.set_tint(Color(0, 0, 0, 0))
		return
	# başka bir efekt ekranı boyuyorsa onun üstüne yazma
	if _tinted or env.tint_target.a <= 0.001:
		_tinted = true
		env.set_tint(Color(0.85, 0.1, 0.08, a))


# ------------------------------------------------------------------ 2. diriliş
static func _revive() -> void:
	var d = D()
	var p = collector()
	if p.is_empty():
		WorldNews.headline("Gedō Mazō'nun sahibi diriliş tamamlanmadan öldü; dokuz canavar zincirlerinden kurtulup inlerine döndü.", Color(0.8, 0.9, 1.0))
		_release()
		_unmark()
		d["stage"] = ""
		d["by"] = ""
		return
	for id in NINE:
		TailedBeasts.beasts()[id]["state"] = "jubi"
	d["stage"] = "boss"
	d["strikes"] = 0
	d["hit"] = []
	d["at"] = Aging.clock() + STRIKE_GAP * 0.5
	WorldAmbition._crime(p, "On Kuyruk'u diriltti")
	var text = "On Kuyruk dirildi. %s onu köylerin üstüne sürüyor; durdurulmazsa Tanrı Ağacı'na dönüşecek." % String(p["name"])
	WorldNews.headline(text, Color(1.0, 0.3, 0.3))
	Hud.banner("ON KUYRUK DİRİLDİ", text, Color(1.0, 0.25, 0.25))
	Journal.add(text, "milestone")
	_mark("Olay: On Kuyruk")
	if Game.world and Game.world.env:
		Game.world.env.add_shake(1.0)
	Sfx.play("roar", null, 0.8, 0.45)


static func _spawn_jubi(at: Vector3) -> TailedBeast:
	var b = TailedBeast.new()
	b.setup("jubi")
	_scene().add_child(b)
	b.global_position = Vector3(at.x, Game.ground_height(at.x, at.z), at.z)
	b.home = b.global_position
	b.set_meta("world_jubi", true)
	return b


## On Kuyruk gerçek yerinde durur; oyuncu görüş mesafesine girince sahneye konur
static func _sync_actor(mine: bool) -> void:
	var dist = _dist()
	if actor != null and (not is_instance_valid(actor) or actor.dead):
		actor = null
	if actor != null:
		if dist > SHOW_R * 1.3 and not actor.subdued and (mine or not actor.aggro):
			actor.queue_free()
			actor = null
	elif dist < SHOW_R:
		actor = _spawn_jubi(site())
		if mine:
			actor.make_ally(Game.player, 1.0e9)
			actor.display_name = "Jūbi (emrinde)"


# ------------------------------------------------------------------ 3. patron: köyleri yıkar
static func _alliance_p() -> float:
	var tot = 0.0
	for vid in WorldPeople.MAJOR:
		tot += WorldAssault._kage_lv(vid)
	return clampf(tot / 9000.0, 0.04, 0.2)


static func _strike() -> void:
	var d = D()
	var now = Aging.clock()
	if is_instance_valid(actor) and (actor.aggro or actor.subdued):
		d["at"] = now + 60.0   # oyuncuyla dövüşüyor: köye yürümez
		return
	if int(d["strikes"]) >= STRIKES_TO_TREE:
		_plant()
		return
	var s = Game.to_map(site())
	var vids = WorldPeople.MAJOR.filter(func(v): return not v in d["hit"] and not Game.village(v).is_empty())
	if vids.is_empty():
		_plant()
		return
	vids.sort_custom(func(a, b): return s.distance_to(Vector2(Game.village(a)["x"], Game.village(a)["y"])) < s.distance_to(Vector2(Game.village(b)["x"], Game.village(b)["y"])))
	var vid = String(vids[0])
	var vn = WorldPeople.vname(vid)
	if randf() < _alliance_p():
		_stopped("alliance", "On Kuyruk %s'e yürürken beş köyün birleşik ordusu yolunu kesti." % vn)
		return
	var v = Game.village(vid)
	var c = Vector2(v["x"], v["y"])
	var vr = float(v["r"])
	var dir = WorldAssault._gate_dir(vid)
	var pos = Game.from_map(c + dir * vr * 1.4)
	d["x"] = pos.x
	d["z"] = pos.z
	if is_instance_valid(actor):
		actor.queue_free()
	actor = null
	var ruin_at = Game.from_map(c + dir * vr * 0.35)
	var defs: Array = WorldDay.war_party(vid, 9)
	defs.shuffle()
	var fallen = 0
	for q in defs.slice(0, randi_range(6, 9)):
		WorldPeople._die(q, "On Kuyruk %s'e saldırdığında köyünü savunurken öldü" % vn)
		fallen += 1
	var kage_dead = false
	if randf() < 0.6 and not (Kage.is_kage() and vid == Progress.home()):
		kage_dead = true
		Kage.kage_killed(vid, false)
	d["strikes"] = int(d["strikes"]) + 1
	(d["hit"] as Array).append(vid)
	d["at"] = now + STRIKE_GAP
	var left = STRIKES_TO_TREE - int(d["strikes"])
	var text = "On Kuyruk %s'i vurdu: köyün yarısı yıkıntı, %d ninja öldü%s. %s" % [vn, fallen, ", Kage de aralarında" if kage_dead else "",
		"Durdurulmazsa %d köy sonra Tanrı Ağacı'na dönüşecek." % left if left > 0 else "Artık kök salmaya hazırlanıyor."]
	var finish = func() -> void:
		WorldAssault._add_ruin(vid, ruin_at, minf(vr * 0.5, 190.0), "On Kuyruk")
		WorldAssault._announce(vid, "ON KUYRUK %s'DE" % vn.to_upper(), text)
		_mark("Olay: On Kuyruk")
		if WorldAssault._player_in(vid, 1.6) and Game.world and Game.world.env:
			Game.world.env.add_shake(2.0)
			Game.world.env.screen_flash(0.8)
			Sfx.play("boom", null, 1.0, 0.4)
	# oyuncu köyde ya da yakınındaysa vuruş canlı oynanır: On Kuyruk kapının dışında belirir, ağzında dev Bijūdama toplar,
	# köyün o mahallesine atar; top düşünce yıkıntı oluşur. Uzaktaysa sonuç hemen işlenir (haber gelir).
	if not (WorldAssault._player_in(vid, 2.6) and Game.world and Game.world.env and Game.player):
		finish.call()
		return
	actor = _spawn_jubi(pos)
	var to_v = ruin_at - actor.global_position
	actor.facing = atan2(to_v.x, to_v.z)
	if is_instance_valid(actor.rig):
		actor.rig.rotation.y = actor.facing
	Hud.banner("ON KUYRUK KAPIDA", "%s'in kapısının dışında belirdi. Ağzında dev bir Bijūdama toplanıyor!" % vn, Color(0.75, 0.6, 1.0))
	Sfx.play("roar", null, 1.0, 0.5)
	Game.world.env.add_shake(1.2)
	var beast = actor
	var speed = 150.0
	var tree = _scene().get_tree()
	tree.create_timer(5.0).timeout.connect(func():
		if not is_instance_valid(beast) or beast.dead:
			finish.call()
			return
		var from: Vector3 = beast.rig.mouth_pos()
		BijuuArts.use(beast, "jubi", "jubi_bijudama", {"s": clampf(beast.height / 14.0, 2.0, 3.5), "dmg": beast._dmg(30.0), "from": from, "aim": ruin_at + Vector3.UP * 3.0,
			"fixed": true, "speed": speed, "col": beast.info["chakra"]})
		Combat.popup_text(from + Vector3.UP * 6.0, "Jūbi Bijūdama", Color(0.85, 0.75, 1.0))
		tree.create_timer(1.8 + from.distance_to(ruin_at) / speed).timeout.connect(finish))


## Durduruldu: canavarlar serbest, her şey temizlenir
static func _stopped(how: String, text: String) -> void:
	var d = D()
	var p = collector()
	_release()
	if how == "alliance" and not p.is_empty():
		WorldPeople._die(p, "Birleşik ordu On Kuyruk'u durdururken öldürüldü")
		var be = WorldPeople.bingo_of(p)
		if not be.is_empty():
			be["status"] = "dead"
	text += " Dokuz canavar zincirlerinden kurtulup inlerine döndü."
	WorldNews.headline(text, Color(0.75, 0.95, 0.8))
	Hud.banner("ON KUYRUK DURDURULDU", text, Color(0.7, 0.95, 0.75))
	Journal.add(text, "milestone")
	if how == "player":
		Progress.add_xp(30000)
		Missions._rep(Progress.home(), 120)
	_unmark()
	d["stage"] = ""
	d["by"] = ""
	d["strikes"] = 0
	d["hit"] = []
	_clear_nodes()
	Game.save_game()


## Diz çöken On Kuyruk'un başında (TailedBeasts mühür penceresi yerine)
static func seal_dialog(b: TailedBeast) -> void:
	var d = D()
	var opts = []
	if b.ally_owner == Game.player:
		return
	opts.append({"label": "Canavarları çekip çıkar", "tip": "Dokuz canavarın chakrasını On Kuyruk'tan söker, hepsini serbest bırakırsın. Kabuk dağılır.", "cb": func():
		if is_instance_valid(b):
			b.sealed_away(null)
		actor = null
		guard = null
		_stopped("player", "On Kuyruk diz çöktü; içindeki dokuz canavar tek tek çekilip çıkarıldı.")})
	if Progress.has_eye("rinnegan") and "rikudo_jubi_kyuin" in Game.profile.get("learned", []):
		opts.append({"label": "Rikudō Jūbi Kyūin — kendi bedenine çek", "tip": "On Kuyruk'un jinchūrikisi olursun: Altı Yol'un gücü, yaşlanmayan beden.", "cb": func():
			if is_instance_valid(b):
				b.sealed_away(Game.player)
			absorbed()})
	Hud.dialog("Jūbi — On Kuyruk", "On Kuyruk diz çökmüş, içindeki dokuz canavarın chakrası ayrışıyor. Ne yapacaksın?", opts)
	d["at"] = Aging.clock() + 120.0


# ------------------------------------------------------------------ 4. Tanrı Ağacı + ay
static func _plant() -> void:
	var d = D()
	d["stage"] = "tree"
	d["moon"] = Aging.clock() + MOON
	d["guard"] = "by" if not collector().is_empty() else "beast"
	d["ally_t"] = Aging.clock() + 300.0
	d["warn"] = 0
	if is_instance_valid(actor):
		actor.sealed_away(null)
	actor = null
	var text = "On Kuyruk kök saldı: Tanrı Ağacı göğe yükseliyor ve ay kızarmaya başladı. Ağaç kesilmezse Mugen Tsukuyomi bütün dünyayı sonsuz rüyaya hapsedecek."
	WorldNews.headline(text, Color(1.0, 0.3, 0.3))
	Hud.banner("TANRI AĞACI", text, Color(1.0, 0.25, 0.3))
	Journal.add(text, "milestone")
	_mark("Olay: On Kuyruk — Tanrı Ağacı")
	if Game.world and Game.world.env:
		Game.world.env.add_shake(1.6)


static func _sync_tree() -> void:
	var d = D()
	var dist = _dist()
	var s = site()
	if tree != null and not is_instance_valid(tree):
		tree = null
	if tree == null and dist < TREE_R:
		tree = ShinjuTree.spawn(_scene(), s)
	elif tree != null and dist > TREE_R * 1.15:
		tree.queue_free()
		tree = null
	# birleşik ordu da ağaca yürür (küçük ihtimal)
	if Aging.clock() >= float(d.get("ally_t", 0.0)):
		d["ally_t"] = Aging.clock() + 300.0
		if dist > GUARD_R * 2.0 and randf() < _alliance_p() * 0.5:
			_stopped("alliance", "Beş köyün birleşik ordusu Tanrı Ağacı'nı kesti.")
			return
	# bekçi
	if guard != null and not is_instance_valid(guard):
		guard = null
	if String(d.get("guard", "beast")) == "by":
		var p = collector()
		if p.is_empty():
			if d.get("guard_on", false):
				d["guard_on"] = false
				guard = null
				_stopped("player", "Tanrı Ağacı'nın dibindeki On Kuyruk jinchūrikisi öldürüldü; ağaç kurudu.")
				return
			d["guard"] = "beast"   # başka yerde öldü: ağacı On Kuyruk'un kendisi bekler
		elif guard == null and dist < GUARD_R and not Missions.quiet():
			var a = WorldPeople.arch_of(p)
			Stats.npc_ninja(a, int(p["level"]) + 60)
			a["name"] = "%s — On Kuyruk Jinchūriki" % String(p["name"])
			a["respawn"] = false
			var js: Array = (a.get("jutsu", []) as Array).duplicate()
			for j in ["gudodama", "chibaku_tensei"]:
				if Data.jutsu.has(j) and not j in js:
					js.push_front(j)
			a["jutsu"] = js.slice(0, 7)
			var e = Enemy.new()
			e.setup(a)
			_scene().add_child(e)
			var q = Missions.open_ground(s + Vector3(0, 0, 90.0), 30.0)
			e.global_position = q
			e.home = q
			guard = e
			d["guard_on"] = true
			Hud.banner(String(a["name"]).to_upper(), "Ağacın dibinde bekliyor. Onu durdurmadan ağaç kesilemez.", Color(1.0, 0.3, 0.3))
	else:
		if guard == null and dist < SHOW_R:
			guard = _spawn_jubi(s + Vector3(0, 0, 170.0))
			guard.display_name = "Jūbi — Tanrı Ağacı'nın bekçisi"
		elif guard != null and dist > SHOW_R * 1.3 and not guard.aggro and not guard.subdued:
			guard.queue_free()
			guard = null


static func _moon() -> void:
	var d = D()
	if String(d["stage"]) != "tree":
		return
	var rem = float(d["moon"]) - Aging.clock()
	var k = clampf(1.0 - rem / MOON, 0.0, 1.0)
	if is_instance_valid(tree):
		tree.set_moon(k)
	_tint(0.05 + 0.2 * k)
	Hud.doom("MUGEN TSUKUYOMI  %d:%02d" % [int(maxf(rem, 0.0)) / 60, int(maxf(rem, 0.0)) % 60])
	var w = int(d.get("warn", 0))
	for i in [[600.0, 1, "Ay yarı yarıya kızardı. Tanrı Ağacı kesilmezse on dakika sonra Mugen Tsukuyomi."], [300.0, 2, "Ay kan kırmızı. Beş dakika kaldı."], [60.0, 3, "Tomurcuk açılıyor. Son bir dakika."]]:
		if rem <= float(i[0]) and w < int(i[1]):
			d["warn"] = int(i[1])
			Hud.banner("MUGEN TSUKUYOMI YAKLAŞIYOR", String(i[2]), Color(1.0, 0.25, 0.25))
			WorldNews.headline(String(i[2]), Color(1.0, 0.35, 0.35))
			break
	if rem <= 0.0:
		d["stage"] = "dream"


# ------------------------------------------------------------------ 5. rüya: yıllar sonra uyanış
## Sayım bitti: herkes kozaya hapsolur. Oyun bitmez (kullanıcı kararı 2026-11-15: "yıllar sonra uyan"): rüya DREAM_MIN..MAX yıl
## sürer, sonra kozalar çürür. Bedeli: o yıllar herkesin ömründen gider (oyuncu da yaşlanır), canavarları toplayan ağaçla
## birlikte kurur, vurulmamış büyük köyler de köklerin altında yıkıntıya döner.
const DREAM_MIN := 6.0
const DREAM_MAX := 10.0
static func _dream() -> void:
	if _ending or Hud.dialog_open():
		return
	_ending = true
	_tinted = true
	if Game.world and Game.world.env:
		Game.world.env.set_tint(Color(0.9, 0.08, 0.06, 0.45))
		Game.world.env.screen_flash(1.0)
	Hud.doom("")
	var pl = Game.player
	pl.velocity = Vector3.ZERO
	pl.input_locked = 1.0e9
	Hud.banner("MUGEN TSUKUYOMI", "Ay kızıla döndü ve gökyüzündeki göz açıldı. Tanrı Ağacı'nın kökleri herkesi tek tek sarıp kozasına aldı.", Color(1.0, 0.25, 0.25))
	Sfx.play("roar", null, 0.6, 0.4)
	await pl.get_tree().create_timer(4.5).timeout
	if not is_instance_valid(pl) or Game.player != pl:
		_ending = false
		return
	await Interiors.inst._fade(1.0, 2.0)
	var yrs = _wake()
	await pl.get_tree().create_timer(1.5).timeout
	await Interiors.inst._fade(0.0, 2.5)
	pl.input_locked = 0.0
	_ending = false
	Hud.banner("UYANIŞ", "%d yıl sonra kozalar çürüdü ve açıldı. Herkes o yılları rüyada geçirdi; dünya eskisi gibi değil." % yrs, Color(0.85, 0.85, 1.0))


## Rüyanın sonu: dünya saati ilerler, ağaç kurur, canavarlar serbest kalır. Dönüş: geçen yıl
static func _wake() -> int:
	var d = D()
	var pr: Dictionary = Game.profile
	var pl = Game.player
	var yrs = randf_range(DREAM_MIN, DREAM_MAX)
	pr["clock"] = Aging.clock() + yrs * Aging.YEAR
	var p = collector()
	if not p.is_empty():
		WorldPeople._die(p, "Tanrı Ağacı'yla birlikte kurudu")
		var be = WorldPeople.bingo_of(p)
		if not be.is_empty():
			be["status"] = "dead"
	_release()
	for vid in WorldPeople.MAJOR:
		var v = Game.village(vid)
		if v.is_empty() or vid in d["hit"]:
			continue
		var c = Vector2(v["x"], v["y"])
		WorldAssault._add_ruin(vid, Game.from_map(c + WorldAssault._gate_dir(vid) * float(v["r"]) * 0.4), minf(float(v["r"]) * 0.35, 130.0), "Tanrı Ağacı'nın kökleri")
	d["stage"] = ""
	d["by"] = ""
	d["strikes"] = 0
	d["hit"] = []
	pr.erase("ended")
	_unmark()
	_clear_nodes()
	pl.respawn(Progress.home_spawn())
	pl.hp = pl.max_hp
	pl.chakra = pl.max_chakra
	pl.rebuild_model()   # geçen yıllar yüzünde
	var text = "Mugen Tsukuyomi %d yıl sürdü. Tanrı Ağacı kurudu, dokuz canavar inlerine döndü; köyler köklerin altından yeniden kuruluyor." % int(yrs)
	WorldNews.headline(text, Color(0.85, 0.85, 1.0))
	Journal.add("Ay kızardı ve %d yılımı bir rüyanın içinde geçirdim. Uyandığımda dünya yaşlanmıştı." % int(yrs), "milestone")
	Game.save_game()
	return int(yrs)


# ------------------------------------------------------------------ oyuncunun yolu
static func can_revive() -> bool:
	return Progress.has_eye("rinnegan") and TailedBeasts.jarred().size() >= NINE.size() and stage() in ["", "gather"]


## Gedō Mazō dokuz gözü açıkken: heykel On Kuyruk'a dönüşür (oyuncunun emrinde)
static func player_revive(it: Dictionary) -> void:
	if not can_revive():
		Hud.msg("Diriliş için Rinnegan ve mühür kabında dokuz canavar gerekli.", Color(1.0, 0.6, 0.5))
		return
	var d = D()
	var statue = it.get("statue")
	var at: Vector3 = it["pos"]
	for id in TailedBeasts.jarred():
		TailedBeasts.beasts()[id]["state"] = "jubi_mine"
	Interact.items.erase(it)
	if statue != null and is_instance_valid(statue):
		statue.set_meta("end", true)
	d["stage"] = "mine"
	d["x"] = at.x
	d["z"] = at.z
	actor = _spawn_jubi(at)
	actor.make_ally(Game.player, 1.0e9)
	actor.display_name = "Jūbi (emrinde)"
	actor.rig.scale = Vector3.ONE * 0.05
	actor.rig.create_tween().tween_property(actor.rig, "scale", Vector3.ONE, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if Game.world and Game.world.env:
		Game.world.env.add_shake(2.0)
	Sfx.play("roar", at, 1.0, 0.45)
	var text = "Gedō Mazō'nun dokuz gözü açıldı ve heykel On Kuyruk'a dönüştü. Rikudō Jūbi Kyūin ile onu bedenine çekebilirsin."
	Hud.banner("ON KUYRUK DİRİLDİ", text, Color(0.85, 0.75, 1.0))
	Journal.add("Dokuz canavarı Gedō Mazō'da birleştirip On Kuyruk'u dirilttim.", "milestone")
	WorldNews.headline("%s On Kuyruk'u diriltti. Beş köy alarmda." % String(Game.profile.get("name", "Bir ninja")), Color(1.0, 0.4, 0.4))
	Game.save_game()


## Rikudō Jūbi Kyūin'in On Kuyruk üzerinde işleyip işlemeyeceği (boyun eğmiş ya da kullananın kendi On Kuyruk'u)
static func can_absorb(b: Node, c: Node) -> bool:
	return b is TailedBeast and (b.subdued or b.ally_owner == c)


## Oyuncu On Kuyruk'u bedenine çekti
static func absorbed() -> void:
	var d = D()
	var pr: Dictionary = Game.profile
	pr["jubi_jinchuriki"] = true
	for id in NINE:
		var b: Dictionary = TailedBeasts.beasts().get(id, {})
		if String(b.get("state", "")) in ["jubi", "jubi_mine", "mazo"]:
			b["state"] = "jubi_host"
			b.erase("ctrl_by")
	var got = []
	for j in GIFTS:
		if Data.jutsu.has(j) and not j in pr["learned"]:
			pr["learned"].append(j)
			got.append(String(Data.jutsu[j]["name"]))
	if not (pr["gear"] as Array).any(func(g): return String(g.get("id", "")) == "nunoboko"):
		Gear.grant(pr, "nunoboko")
		got.append("Nunoboko no Ken")
	var was_boss = String(d["stage"]) in ["boss", "tree"]
	d["stage"] = "host"
	d["mazo"] = []
	actor = null
	guard = null
	_unmark()
	if was_boss:
		if is_instance_valid(tree):
			tree.wither()
		tree = null
		_tint(0.0)
		Hud.doom("")
		WorldNews.headline("On Kuyruk durduruldu: %s onu kendi bedenine çekti." % String(pr.get("name", "Bir ninja")), Color(0.85, 0.8, 1.0))
	Hud.banner("ON KUYRUK JINCHŪRIKI", "Altı Yol'un gücü bedenine aktı. Beden artık yaşlanmıyor.%s" % ("  Öğrenildi: " + ", ".join(got) if not got.is_empty() else ""), Color(0.85, 0.8, 1.0))
	Journal.add("On Kuyruk'u kendi bedenime çektim. Artık onun jinchūrikisiyim.", "milestone")
	Game.save_game()
