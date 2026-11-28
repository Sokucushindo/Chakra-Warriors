class_name SixPaths
extends Node
## Pein Rikudō (kanon: Nagato'nun altı bedeni ölmüş ninjaların cesetleridir; her bedene kara alıcılar saplanır, tek bir
## yol verilir, hepsi tek zihin ve ortak görüşle hareket eder; düşen bedenin yerine başka bir ceset konabilir).
## Rinnegan sahibi öldürdüğü kişinin cesedine [F] ile alıcı saplar -> beden arşive girer. Arşivdeki bedenler altı yola
## atanır (Tab > Gözler > Pein Rikudō, ◀ ▶), istenince değiştirilir. "Pein Rikudō" tekniği atanmış bedenleri çağırır.
## Beden kendi görünüşü ve gücüyle gelir; teknikleri atandığı yolunkilerdir.
## Kanon kurallar: ortak görüş, Jigokudō düşen bedeni diriltir, Chikushōdō uzakta kalanı yanına çağırır, bedenler sahadayken
## chakra akar, asıl beden düşerse hepsi düşer.

const PATHS := ["tendo", "shurado", "ningendo", "chikushodo", "gakido", "jigokudo"]
const NAMES := {"tendo": "Tendō", "shurado": "Shuradō", "ningendo": "Ningendō", "chikushodo": "Chikushōdō", "gakido": "Gakidō", "jigokudo": "Jigokudō"}
const INFO := {
	"tendo": "İtme ve çekme: Shinra Tensei, Banshō Ten'in",
	"shurado": "Mekanik beden: ek kollar, füzeler, çakra topu",
	"ningendo": "Ruhu bedenden söker",
	"chikushodo": "Dev hayvanlar çağırır; uzakta kalan bedenleri yanına çağırır",
	"gakido": "Ninjutsuyu ve chakrayı emer",
	"jigokudo": "Cehennem Kralı: düşen bedenleri diriltir",
}
## Yolun teknikleri (Tendō'nun itme / çekmesi EnemyArts'ta: oyuncuyla aynı 5 sn dolum)
const PATH_JUTSU := {
	"tendo": [],
	"shurado": ["shurado", "kaiwan_no_hiya", "shura_no_ko", "danto_no_hiya"],
	"ningendo": ["ningendo"],
	"chikushodo": ["chikushodo"],
	"gakido": ["gakido", "fujutsu_kyuin"],
	"jigokudo": ["jigokudo"],
}
const ARCHIVE_MAX := 12
const DRAIN := 0.002       # sahadaki beden başına saniyede azami chakranın payı...
const DRAIN_FLAT := 0.5    # ...artı sabit akış (chakra yenilenmesi sabit sayı: yalnız yüzde olsaydı düşük chakrada bedava kalırdı).
                           # Altı beden: yeni başlayan ~30 sn, chakra ustası ~100 sn; bir iki beden süresiz taşınabilir
const DOWN_T := 120.0      # düşen beden bu süre çağrılamaz (Jigokudō diriltirse hemen döner)
const REVIVE_WAIT := 5.0
const REVIVE_CD := 25.0
const LAV := Color(0.8, 0.7, 1.0)

static var out := {}       # yol -> Enemy (oyuncunun sahadaki bedenleri)
static var down := {}      # yol -> yeniden çağrılabileceği an (sn)
static var lost := {}      # yol -> {t, pos}: düştü, Jigokudō diriltebilir
static var corpse_target: Node3D = null
static var _node: Node = null
static var _rev_cd := 0.0
static var _slow := 0.0


static func ensure() -> void:
	if _node == null or not is_instance_valid(_node):
		_node = new()
		_node.name = "SixPaths"
		Game.add_child(_node)


static func data() -> Dictionary:
	var pr: Dictionary = Game.profile
	if not pr.has("six_paths"):
		pr["six_paths"] = {"bodies": [], "slots": {}, "seq": 0}
	return pr["six_paths"]


static func has_rinnegan() -> bool:
	if Game.profile.is_empty():
		return false
	for sl in ["sag_goz", "sol_goz"]:
		if String(LazyFx.g("Gear").equipped(Game.profile, sl).get("id", "")) == "goz_rinnegan":
			return true
	return false


static func body(id: int) -> Dictionary:
	for b in data()["bodies"]:
		if int(b["id"]) == id:
			return b
	return {}


static func slot_id(path: String) -> int:
	return int(data()["slots"].get(path, 0))


## Yolun bedenine giydirilen set ("" = bedenin kendi kıyafeti). Kanon: Pain altı bedenine de Akatsuki cübbesi giydirmişti.
static func wear_id(path: String) -> String:
	return String((data().get("wear", {}) as Dictionary).get(path, ""))


static func set_wear(path: String, sid: String) -> void:
	var d := data()
	if not d.has("wear"):
		d["wear"] = {}
	if sid == "":
		d["wear"].erase(path)
	else:
		d["wear"][path] = sid
	_recall(path)   # sahadaysa geri çekilir: yeniden çağrılınca yeni kıyafetiyle gelir


## Bedenlere giydirilebilecek setler: sahip olduğun kıyafet setleri (her biri bir kez)
static func wear_choices() -> Array:
	var out := []
	for g in LazyFx.g("Gear").owned_for(Game.profile, "set"):
		var id := String(g["id"])
		if not id in out:
			out.append(id)
	return out


## Bu ceset beden olarak alınabilir mi: insan boyunda, senin tarafında olmayan, klon / çağrı / başka birinin bedeni olmayan
static func wants_corpse(e: Node) -> bool:
	if not (e is Enemy) or e is ShadowClone or not has_rinnegan():
		return false
	if float(e.size) >= 2.0 or e.arch.has("beast") or e.has_meta("teammate") or String(e.team) == "player":
		return false
	if e.has_meta("pain_path") or e.has_meta("summon") or e.has_meta("clone") or not (e.arch.get("look") is Dictionary):
		return false
	return true


static func _clean(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			var x = v[k]
			if x is Object or x is Callable or x is Signal or x is RID:
				continue
			o[k] = _clean(x)
		return o
	if v is Array:
		var o2 := []
		for x in v:
			if x is Object or x is Callable or x is Signal or x is RID:
				continue
			o2.append(_clean(x))
		return o2
	return v


## Cesede kara alıcılar saplanır: beden arşive girer, boş yol varsa ona atanır
static func take(f: Node3D) -> void:
	corpse_target = null
	if not is_instance_valid(f) or f.has_meta("pain_taken"):
		return
	f.set_meta("pain_taken", true)
	f.remove_from_group("pain_corpses")
	var pl = Game.player
	var d := data()
	var a: Dictionary = _clean(f.arch)
	for k in ["world_person", "bingo_id", "auto_jutsu", "auto_lv", "legend", "boss"]:
		a.erase(k)
	a["no_world"] = true
	a["respawn"] = false
	a["xp"] = 0
	a["ryo"] = 0
	d["seq"] = int(d["seq"]) + 1
	var rec := {"id": int(d["seq"]), "name": String(f.display_name), "level": int(f.level), "arch": var_to_str(a)}
	var bodies: Array = d["bodies"]
	if bodies.size() >= ARCHIVE_MAX:   # arşiv dolu: yola atanmamış en eski beden bırakılır
		var used := []
		for p in PATHS:
			used.append(slot_id(p))
		for i in bodies.size():
			if not int(bodies[i]["id"]) in used:
				bodies.remove_at(i)
				break
	bodies.append(rec)
	var got := ""
	for p in PATHS:
		if body(slot_id(p)).is_empty():
			d["slots"][p] = int(rec["id"])
			got = p
			break
	LazyFx.g("Crime").on_eyes_taken(f)   # köy ninjasının bedenine dokunmak: aynı suç
	var pj = LazyFx.g("PathJutsu").get_pinst()
	var fxb = LazyFx.g("DojutsuFXB")
	var at: Vector3 = f.global_position
	if pl:
		pl.model.play("cast_out", 0.05, 1.0, true)
		fxb._rod_volley(pj, fxb._host(pj), pl, at + Vector3.UP * 0.4, 0.0)
	Sfx.play("seal", at, 0.7)
	# beden alıcılarla birlikte yere gömülür (arşive)
	var tw = f.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func(): fxb._puppet_rise(fxb._host(pj), at))
	tw.tween_property(f, "global_position:y", at.y - 1.2, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(f.queue_free)
	if got != "":
		Hud.banner("PEIN RIKUDŌ", LazyFx.g("Lang").t("%s bedeni alındı: %s yoluna atandı") % [rec["name"], NAMES[got]], LAV)
	else:
		Hud.banner("PEIN RIKUDŌ", LazyFx.g("Lang").t("%s bedeni arşive alındı (%d / %d)") % [rec["name"], bodies.size(), ARCHIVE_MAX], LAV)


## Yola beden ata (0 = boş). Beden başka yoldaysa oradan alınır; sahadaki eski beden geri çekilir.
static func assign(path: String, id: int) -> void:
	var d := data()
	for p in PATHS:
		if p != path and id != 0 and slot_id(p) == id:
			d["slots"].erase(p)
			_recall(p)
	if id == 0:
		d["slots"].erase(path)
	else:
		d["slots"][path] = id
	_recall(path)


## Arşivden beden sil (yoldaysa yol boşalır)
static func discard(id: int) -> void:
	var d := data()
	for p in PATHS:
		if slot_id(p) == id:
			d["slots"].erase(p)
			_recall(p)
	var bodies: Array = d["bodies"]
	for i in bodies.size():
		if int(bodies[i]["id"]) == id:
			bodies.remove_at(i)
			break


static func _alive(path: String) -> Enemy:
	var e = out.get(path)
	if e != null and is_instance_valid(e) and not e.is_dead():
		return e
	return null


static func count_out() -> int:
	var n := 0
	for p in PATHS:
		if _alive(p) != null:
			n += 1
	return n


static func _recall(path: String) -> void:
	var e := _alive(path)
	out.erase(path)
	if e == null:
		return
	var pj = LazyFx.g("PathJutsu").get_pinst()
	var fxb = LazyFx.g("DojutsuFXB")
	fxb._puppet_rise(fxb._host(pj), e.global_position)
	e.set_meta("pain_gone", true)
	e.remove_from_group("fighters")
	e.collision_layer = 0
	var tw = e.create_tween()   # geldiği gibi yere gömülür (gövdeyi ölçeklemek fizik hatası veriyor)
	tw.tween_property(e, "global_position:y", e.global_position.y - 2.2, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(e.queue_free)


static func recall_all() -> void:
	for p in PATHS:
		_recall(p)


## Yolun teknikleriyle donatılmış beden kalıbı (NPC çağıranlar da kullanır: AI eşitliği)
static func path_arch(src: Dictionary, path: String) -> Dictionary:
	var a: Dictionary = src.duplicate(true)
	a["jutsu"] = (PATH_JUTSU.get(path, []) as Array).duplicate()
	a.erase("auto_jutsu")
	a.erase("auto_lv")
	a["no_world"] = true
	a["no_clan"] = true   # beden kendi klan tekniklerini kullanmaz (yeniden klan zarı da atılmaz): yalnız yolunkiler
	a.erase("clan_force")
	a["respawn"] = false
	return a


static func _slot_off(path: String) -> Vector3:
	var i := PATHS.find(path)
	return Vector3(cos(i * 1.05 + 0.5), 0, sin(i * 1.05 + 0.5)) * 3.6


static func _spawn(path: String, c: Node3D, at: Vector3) -> Enemy:
	var rec := body(slot_id(path))
	if rec.is_empty():
		return null
	var src = str_to_var(String(rec["arch"]))
	if not (src is Dictionary):
		return null
	var a := path_arch(src, path)
	a["name"] = "%s · %s" % [NAMES[path], rec["name"]]
	var sid := wear_id(path)
	if sid != "" and sid in wear_choices() and a.get("look") is Dictionary:
		var vil = a["look"].get("village")
		a["look"] = LazyFx.g("Outfits").wear_set(a["look"], sid)   # kimlik (saç, yüz, ten) kalır, kıyafet setten
		if vil != null:
			a["look"]["village"] = vil
	var e := Enemy.new()
	e.setup(a)
	e.team = c.team
	e.set_meta("respawn", false)
	e.set_meta("teammate", true)
	e.set_meta("pain_path", path)
	var pj = LazyFx.g("PathJutsu").get_pinst()
	var fxb = LazyFx.g("DojutsuFXB")
	fxb._host(pj).add_child(e)
	e.global_position = at
	e.home = at
	Eyes.give_enemy_eyes(e, 6, 3)   # kontrol edilen bedenin gözleri çağıranınki gibi Rinnegan
	if e.nameplate:
		e.nameplate.modulate = LAV
	e.set_meta("pain_studs", path)   # yüz piercingleri model hazır olunca takılır (_studs)
	fxb._puppet_rise(fxb._host(pj), at)
	out[path] = e
	return e


## Oyuncunun "Pein Rikudō" tekniği: atanmış bedenleri çağırır; hepsi yanındaysa geri gönderir
static func player_cast(pj, c: Node3D) -> void:
	ensure()
	var now := Time.get_ticks_msec() / 1000.0
	var assigned := []
	for p in PATHS:
		if not body(slot_id(p)).is_empty():
			assigned.append(p)
	if assigned.is_empty():
		Hud.msg("Pein Rikudō: yola atanmış beden yok. Öldürdüğün birinin cesedine [F] ile kara alıcı sapla.", LAV, 6.0)
		return
	var missing := []
	var waiting := 0
	var far := false
	for p in assigned:
		var e := _alive(p)
		if e == null:
			if float(down.get(p, 0.0)) > now:
				waiting += 1
			else:
				missing.append(p)
		elif e.global_position.distance_to(c.global_position) > 25.0:
			far = true
	pj.busy(c, 1.2)
	pj.anim(c, "cast", 1.0)
	var fxb = LazyFx.g("DojutsuFXB")
	fxb._eye_glint(pj, c, LAV, 2.0)
	Sfx.play("seal", c.global_position, 0.7)
	if missing.is_empty() and not far:
		if count_out() == 0:
			Hud.msg("Pein Rikudō: bedenlerin onarılıyor (Jigokudō ayaktaysa diriltir).", LAV, 4.0)
			return
		recall_all()
		Hud.msg("Bedenler geri gönderildi.", LAV)
		return
	# uzakta kalanlar yanına çekilir
	for p in assigned:
		var e2 := _alive(p)
		if e2 != null and e2.global_position.distance_to(c.global_position) > 25.0:
			var q: Vector3 = c.global_position + _slot_off(p)
			q.y = Game.jutsu_floor_at(q).y
			e2.global_position = q
			e2.target = null
			fxb._puppet_rise(fxb._host(pj), q)
	var i := 0
	for p in missing:
		var q2: Vector3 = c.global_position + _slot_off(p)
		q2.y = Game.jutsu_floor_at(q2).y
		fxb._rod_volley(pj, fxb._host(pj), c, q2 + Vector3.UP * 1.3, i * 0.2)
		pj.after(0.2 + i * 0.2, func():
			if pj.live(c) and _alive(p) == null:
				var e3 := _spawn(p, c, q2)
				if e3:
					Combat.popup_text(q2 + Vector3.UP * 2.6, NAMES[p], LAV))
		i += 1
	if waiting > 0:
		Hud.msg(LazyFx.g("Lang").t("%d beden henüz onarılmadı.") % waiting, LAV, 4.0)


func _process(dt: float) -> void:
	if Game.paused or Game.profile.is_empty():
		return
	var pl = Game.player
	if pl == null or not is_instance_valid(pl):
		return
	var now := Time.get_ticks_msec() / 1000.0
	for p0 in out:
		var e0 = out[p0]
		if is_instance_valid(e0) and e0.has_meta("pain_studs") and e0.model != null and e0.model.built and e0.model.skel != null:
			_studs(e0, String(e0.get_meta("pain_studs")))
			e0.remove_meta("pain_studs")
	# düşenler
	for p in PATHS:
		if out.has(p) and _alive(p) == null:
			var e0 = out[p]
			out.erase(p)
			if e0 != null and is_instance_valid(e0) and not e0.has_meta("pain_gone"):
				down[p] = now + DOWN_T
				lost[p] = {"t": now, "pos": (e0 as Node3D).global_position}
	var n := count_out()
	if n > 0:
		if pl.is_dead():
			_collapse("")
			return
		pl.chakra -= (pl.max_chakra * DRAIN + DRAIN_FLAT) * n * dt
		if pl.chakra <= 0.0:
			pl.chakra = 0.0
			_collapse("Chakra bitti: bedenler yığıldı.")
			return
	_slow -= dt
	if _slow > 0.0:
		return
	_slow = 0.4
	_rev_cd -= 0.4
	_corpse_scan(pl)
	if n == 0:
		if not lost.is_empty() and _alive("jigokudo") == null:
			for p in lost.keys():
				if now - float(lost[p]["t"]) > DOWN_T:
					lost.erase(p)
		return
	if not has_rinnegan():
		_collapse("Rinnegan olmadan bedenler hareket edemez.")
		return
	# ortak görüş: bir bedenin gördüğünü hepsi görür
	var seen: Node3D = null
	for p in PATHS:
		var e := _alive(p)
		if e != null and e.target != null and is_instance_valid(e.target) and not e.target.is_dead():
			seen = e.target
			break
	var chiku := _alive("chikushodo")
	for p in PATHS:
		var x := _alive(p)
		if x == null:
			continue
		var q: Vector3 = pl.global_position + _slot_off(p)
		x.home = q
		var idle: bool = x.target == null or not is_instance_valid(x.target) or x.target.is_dead()
		if idle and seen != null and Combat.hostile(x, seen) and x.global_position.distance_to(seen.global_position) < 60.0:
			x.target = seen
			idle = false
		if idle and x.get("state") in ["idle", "patrol"]:
			x.wander_to = q
		var dd := x.global_position.distance_to(q)
		# Chikushōdō ayaktaysa geride kalanı yanına çağırır (kanon); yoksa beden ancak çok uzaklaşınca alıcılardan yeniden bağlanır
		if dd > (40.0 if chiku != null and x != chiku else 80.0):
			q.y = Game.jutsu_floor_at(q).y
			x.global_position = q
			x.target = null
			var pj = LazyFx.g("PathJutsu").get_pinst()
			var fxb = LazyFx.g("DojutsuFXB")
			fxb._puppet_rise(fxb._host(pj), q)
			if chiku != null and x != chiku:
				Combat.popup_text(chiku.global_position + Vector3.UP * 2.6, "Kuchiyose no Jutsu!", LAV)
	# Jigokudō: düşen bedeni Cehennem Kralı'ndan geri çıkarır
	var jig := _alive("jigokudo")
	if jig != null and _rev_cd <= 0.0 and not (jig.get("state") in ["hitstun", "knockdown", "cast"]):
		for p in lost.keys():
			if p == "jigokudo" or now - float(lost[p]["t"]) < REVIVE_WAIT or body(slot_id(p)).is_empty():
				continue
			_rev_cd = REVIVE_CD
			lost.erase(p)
			down.erase(p)
			Combat.popup_text(jig.global_position + Vector3.UP * 2.6, "Jigokudō!", LAV)
			LazyFx.g("PathJutsu").cast_path(jig, "jigokudo", null)
			var at: Vector3 = jig.global_position + jig.face_dir() * 4.5
			at.y = Game.jutsu_floor_at(at).y
			var pth: String = p
			get_tree().create_timer(2.2).timeout.connect(func():
				if _alive("jigokudo") != null and _alive(pth) == null and Game.player and is_instance_valid(Game.player):
					var e4 := _spawn(pth, Game.player, at)
					if e4:
						e4.hp = e4.max_hp * 0.6
						Combat.popup_text(at + Vector3.UP * 2.6, NAMES[pth], LAV))
			break


static func _collapse(msg: String) -> void:
	for p in PATHS:
		var e := _alive(p)
		out.erase(p)
		if e != null:
			e.set_meta("pain_gone", true)
			e.die({"execute": true, "no_blood": true})
	if msg != "":
		Hud.msg(msg, LAV, 5.0)


static func _corpse_scan(pl: Node3D) -> void:
	corpse_target = null
	if not has_rinnegan():
		return
	for f in pl.get_tree().get_nodes_in_group("pain_corpses"):
		if not is_instance_valid(f) or f.has_meta("pain_taken") or f.is_queued_for_deletion():
			continue
		if f.global_position.distance_to(pl.global_position) < 4.5:
			corpse_target = f
			if not f.has_meta("pain_prompt"):
				f.set_meta("pain_prompt", true)
				Combat.popup_text(f.global_position + Vector3.UP * 1.2, "[F] Kara alıcı sapla (bedeni al)", LAV)
			break


## Yüz piercingleri (kanon: Pain'in bedenlerindeki kara alıcılar yüze gömülü küçük çivilerdir; gövdeden çıkan kazık yoktur).
## Her yolun deseni ayrı. Nokta = [yatay konum (göz aralığı birimi, 0 = yüz ortası, 1 = göz hizası), göz hizasına göre yükseklik (m), boy].
## boy 0 = düğme çivi, >0 = dışarı uzanan kısa çubuk (m). Yüzün kendi yüzeyine oturur (CharacterModel.face_pt), Head kemiğiyle döner.
const STUDS := {
	"tendo": [[-0.42, -0.012, 0.0], [-0.42, -0.026, 0.0], [-0.42, -0.04, 0.0], [0.42, -0.012, 0.0], [0.42, -0.026, 0.0], [0.42, -0.04, 0.0],
		[-0.3, -0.088, 0.018], [0.3, -0.088, 0.018]],   # burun kemerinde üçer çivi, alt dudakta iki çubuk (Yahiko)
	"shurado": [[-0.4, -0.02, 0.0], [0.4, -0.02, 0.0], [-1.2, -0.045, 0.0], [1.2, -0.045, 0.0], [-1.2, -0.065, 0.0], [1.2, -0.065, 0.0], [0.0, -0.108, 0.03]],   # alın sırası + çene çivisi
	"ningendo": [[-0.4, -0.02, 0.0], [0.4, -0.02, 0.0], [-1.45, -0.03, 0.0], [-1.45, -0.05, 0.0], [1.45, -0.03, 0.0], [1.45, -0.05, 0.0], [0.0, -0.092, 0.016]],   # burun çubuğu, yanaklarda ikişer, dudak altı
	"chikushodo": [[-0.35, -0.008, 0.0], [0.35, -0.008, 0.0], [-0.35, -0.03, 0.0], [0.35, -0.03, 0.0], [-1.3, -0.06, 0.012], [1.3, -0.06, 0.012], [-0.6, -0.1, 0.0], [0.6, -0.1, 0.0]],   # burun dört, yanak çubukları, çene iki
	"gakido": [[0.0, -0.022, 0.0], [-0.45, -0.035, 0.0], [0.45, -0.035, 0.0], [-0.5, -0.1, 0.014], [0.0, -0.106, 0.014], [0.5, -0.1, 0.014]],   # burun üçgeni, çenede üç çubuk
	"jigokudo": [[-1.5, 0.03, 0.0], [-1.15, 0.0, 0.0], [-0.5, -0.03, 0.0], [0.5, -0.03, 0.0], [1.15, 0.0, 0.0], [1.5, 0.03, 0.0], [0.0, -0.09, 0.0]],   # yanaktan buruna inen V sırası
}
static func _studs(e, path: String) -> void:
	var m = e.model
	var b = MB.new()
	var col := Color(0.035, 0.03, 0.045)
	var ar: float = m.eye_a(true)
	var al: float = m.eye_a(false)
	var mid := (ar + al) * 0.5
	var half := absf(al - ar) * 0.5
	var ey: float = m.eye_center_model.y
	for sp in STUDS.get(path, STUDS["tendo"]):
		var a := mid + half * float(sp[0])
		var y := ey + float(sp[1])
		var p: Vector3 = m.face_pt(a, y, 0.002)
		var len := float(sp[2])
		if len <= 0.0:
			b.add("sphere", p, Vector3(0.0075, 0.0075, 0.0075), col, Vector3.ZERO, 6)
		else:
			var q: Vector3 = m.face_pt(a, y, 0.002 + len)
			var dirv := (q - p).normalized()
			for k in 4:
				var r := lerpf(0.0065, 0.003, k / 3.0)
				b.add("sphere", p.lerp(q, k / 3.0), Vector3(r, r, r) + Vector3(absf(dirv.x), absf(dirv.y), absf(dirv.z)) * len * 0.18, col, Vector3.ZERO, 6)
	var holder: Node3D = m._attach("Head", Transform3D.IDENTITY).get_child(0)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(LazyFx.g("Props").toon())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
