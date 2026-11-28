class_name VillageFall
extends RefCounted
## Köyü tamamen yok etme ve yeniden kurma (kullanıcı 2026-11-28).
## Akış: önce köyün Kage'sini öldürürsün, sonra köyde NEED kişi öldürünce köy düşer: bütün köy kalıcı yıkıntıya döner
## (oyundaki köy saldırısı yıkıntı sistemi: WorldAssault yıkıntı bölgesi + VillageRuin; bu bölge "perm" olduğu için kendi
## kendine onarılmaz, "total" olduğu için önemli binalar da yıkılır). Köyde kimse yaşamaz, hizmet yoktur, bölgenin adı
## "…'dan Kalanlar" olur. Köy meydanındaki sancak direğinden (F) yeniden kurarsın: yıkıntı dışından içine doğru inşa edilir
## (aynı onarım sistemi), eski klanlar geri gelmez, köyün yeni aileleri rastgele adlarla kurulur, kurucusu sensin.
## Kayıt: Game.profile["fall"] = {vid: {kage, kills, down, t, zone, rebuilt, clans: [ad...], founder}}

const NEED := 30            # Kage'den sonra köyde öldürülmesi gereken kişi
const COST := 50000         # yeniden kurma bedeli (Ryō)
const REBUILD := 450.0      # yeniden kurulma süresi (dünya saati sn; 450 = 1 yıl)
const PRE := ["Aka", "Shiro", "Kuro", "Mizu", "Hoshi", "Kaze", "Tsuki", "Yama", "Hana", "Ishi", "Take", "Mori", "Ao", "Kita", "Fuyu", "Asa", "Yoru", "Kawa", "Sora", "Toki"]
const SUF := ["gane", "mura", "zaki", "hara", "mine", "tani", "bashi", "gami", "numa", "sato", "gawa", "mori", "hime", "kage", "nishi", "date"]
static var _flag := {}      # vid -> WeakRef (sancak direği)
static var _t := 0.0


static func D() -> Dictionary:
	var pr: Dictionary = Game.profile
	if pr.is_empty():
		return {}
	if not pr.has("fall") or not pr["fall"] is Dictionary:
		pr["fall"] = {}
	return pr["fall"]


static func rec(vid: String) -> Dictionary:
	var d = D()
	if not d.has(vid):
		d[vid] = {"kage": false, "kills": 0, "down": false, "rebuilt": false}
	return d[vid]


## KUŞATMA (2026-11-28: "yeni Kage seçip duruyorlar, sonsuz döngü, köy yok olmuyor"): Kage senin elinden öldüğü andan
## köy düşene (ya da sen 20 dk boyunca o köyde kimseyi öldürmeyip kuşatmayı bırakana) kadar köy kuşatma altındadır:
##  - yeni Kage SEÇİLMEZ (köy lidersiz; kuşatma kalkarsa o zaman seçilir),
##  - köyde yeni klan üyesi yetişmez, yok olan klan geri gelmez,
##  - alarm dalgaları artık yalnız kalan klan ninjalarıdır (beşer beşer, kaç kişi kaldığı her dalgada yazılır; dostun da olsa gelir),
##  - sonuncusu düşünce köy yok olur.
const SIEGE_HOLD := 1200.0
static func siege(vid: String) -> bool:
	if vid == "" or Game.profile.is_empty() or not D().has(vid):
		return false
	var r: Dictionary = D()[vid]
	return bool(r.get("kage", false)) and not bool(r.get("down", false))


static func siege_touch(vid: String) -> void:
	if siege(vid):
		rec(vid)["siege_t"] = Game.now()


## Köy şu an yıkık mı (yeniden kurulmaya başlanmamış)
static func down(vid: String) -> bool:
	if Game.profile.is_empty() or not Game.profile.has("fall"):
		return false
	return bool((Game.profile["fall"] as Dictionary).get(vid, {}).get("down", false))


static func rebuilt(vid: String) -> bool:
	if Game.profile.is_empty() or not Game.profile.has("fall"):
		return false
	return bool((Game.profile["fall"] as Dictionary).get(vid, {}).get("rebuilt", false))


static func any_down() -> bool:
	if Game.profile.is_empty() or not Game.profile.has("fall"):
		return false
	for vid in Game.profile["fall"]:
		if bool(Game.profile["fall"][vid].get("down", false)):
			return true
	return false


static func vid_at(p: Vector3, k := 1.0) -> String:
	var m := Game.to_map(p)
	for v in Game.world_info.get("villages", []):
		if m.distance_to(Vector2(v["x"], v["y"])) < float(v["r"]) * k:
			return String(v["id"])
	return ""


## Bu nokta yıkık bir köyün içinde mi (hizmet noktaları, sakinler, muhafızlar için)
static func dead_at(p: Vector3) -> bool:
	if not any_down():
		return false
	var vid = vid_at(p, 1.05)
	return vid != "" and down(vid)


## "Konoha'dan Kalanlar": ünlü uyumuna göre ek
static func remains_name(nm: String) -> String:
	if LazyFx.g("Lang").is_en():
		return "Remains of %s" % nm
	var back := true
	for i in range(nm.length() - 1, -1, -1):
		var ch = nm.substr(i, 1).to_lower()
		if ch in ["a", "ı", "o", "u", "ā", "ō", "ū"]:
			break
		if ch in ["e", "i", "ö", "ü", "ē", "ī"]:
			back = false
			break
	var hard = nm.substr(nm.length() - 1, 1).to_lower() in ["k", "t", "p", "ç", "ş", "s", "h", "f"]
	return "%s'%s%s Kalanlar" % [nm, "t" if hard else "d", "an" if back else "en"]


static func place_name(vid: String, nm: String) -> String:
	if down(vid):
		return remains_name(nm)
	return nm


# ------------------------------------------------------------------ düşüş
static func on_kage_killed(vid: String, by_player: bool) -> void:
	if not by_player or Game.profile.is_empty() or down(vid):
		return
	var r = rec(vid)
	r["kage"] = true
	r["kills"] = 0
	r["siege_t"] = Game.now()
	var vn = String(Game.village(vid).get("name", vid))
	var left = WorldPeople.clans_left(vid)
	if left > 0:
		Hud.msg("%s lidersiz kaldı. Klanlarından %d ninja hâlâ ayakta: onlar da düşerse köy tamamen yok olur." % [vn, left], Color(0.95, 0.45, 0.35), 9.0)
	else:
		Hud.msg("%s lidersiz kaldı. Köyde %d kişi daha düşerse köy tamamen yok olur." % [vn, NEED], Color(0.95, 0.45, 0.35), 9.0)
	check(vid)


## Yok olma şartı (2026-11-28: "klanların nüfusu 0'a düşer ve Kage de ölürse yok olsun köy"): Kage senin elinden ölmüş +
## köyün klanlarında yaşayan kimse kalmamış. Hiç klanı olmayan köyde Kage'den sonra NEED kişi.
static func check(vid: String) -> void:
	if vid == "" or Game.profile.is_empty() or down(vid) or Game.village(vid).is_empty():
		return
	var r = rec(vid)
	if not bool(r.get("kage", false)):
		return
	var had: bool = (WorldPeople.data().get("extinct", {}) as Dictionary).keys().any(func(k): return String(k).ends_with("@" + vid))
	var left = WorldPeople.clans_left(vid)
	if left == 0 and (had or int(r.get("kills", 0)) >= NEED):
		destroy(vid)
	elif left > 0 and left in [20, 10, 5, 3, 1] and int(r.get("told", -1)) != left:
		r["told"] = left
		Hud.msg("%s: klanlarından %d ninja kaldı." % [String(Game.village(vid).get("name", vid)), left], Color(0.95, 0.45, 0.35), 6.0)


## Köyde biri senin elinden öldü (Crime kurbanı: köylü, köy ninjası, muhafız)
static func on_kill(vid: String) -> void:
	if vid == "" or Game.profile.is_empty() or down(vid):
		return
	var r = rec(vid)
	if not bool(r.get("kage", false)):
		return
	r["kills"] = int(r.get("kills", 0)) + 1
	r["siege_t"] = Game.now()
	check(vid)


static func center(vid: String) -> Vector3:
	var v: Dictionary = Game.village(vid)
	var c: Vector3 = Game.from_map(Vector2(float(v["x"]), float(v["y"])))
	c.y = Game.terrain_height(c.x, c.z)
	return c


static func destroy(vid: String) -> void:
	var r = rec(vid)
	if bool(r.get("down", false)):
		return
	var v: Dictionary = Game.village(vid)
	var vn = String(v.get("name", vid))
	var z = WorldAssault._add_ruin(vid, center(vid), float(v["r"]) * 1.02, String(Game.profile.get("name", "")))
	z["perm"] = true     # kendi kendine onarılmaz
	z["total"] = true    # önemli binalar da yıkılır
	r["down"] = true
	r["rebuilt"] = false
	r["zone"] = int(z["id"])
	r["t"] = Aging.clock()
	r["old_name"] = vn
	Hud.banner("%s YOK OLDU" % vn.to_upper(), "Kage'si öldü, halkı düştü. Geriye yalnız yıkıntılar kaldı.", Color(0.9, 0.2, 0.2))
	LazyFx.g("Journal").add("%s'i yok ettim. Köyden geriye yıkıntı kaldı." % vn, "milestone")
	TailedBeasts._news("HABER", "%s yok oldu! Köy tek bir ninjanın elinden düştü." % vn)
	Orgs.add_infamy(3000)
	if Game.world != null and Game.world.get("env") != null and Game.world.env.has_method("screen_flash"):
		Game.world.env.screen_flash(0.5)
	Sfx.play("thunder", Game.player.global_position if Game.player else center(vid))
	# köydekiler: sağ kalanlar kaçar (köy boşalır)
	for n in Game.get_tree().get_nodes_in_group("talkers"):
		if n is Villager and is_instance_valid(n) and vid_at(n.global_position, 1.05) == vid and not n.get("interior") == true:
			n.queue_free()
	Game.save_game()


# ------------------------------------------------------------------ yeniden kurma
static func new_clan_names(n: int) -> Array:
	var taken := {}
	for c in Data.clans:
		taken[String(Data.clans[c].get("name", c)).to_lower()] = true
	var out := []
	var guard := 0
	while out.size() < n and guard < 200:
		guard += 1
		var nm = String(PRE.pick_random()) + String(SUF.pick_random())
		if taken.has(nm.to_lower()) or nm in out:
			continue
		out.append(nm)
	return out


static func ask_rebuild(vid: String) -> void:
	var vn = String(rec(vid).get("old_name", Game.village(vid).get("name", vid)))
	var ryo = int(Game.profile.get("ryo", 0))
	var opts = []
	if ryo >= COST:
		opts.append({"label": "Köyü yeniden kur (%d Ryō)" % COST, "cb": func(): rebuild(vid)})
	else:
		opts.append({"label": "Yeniden kurmaya paran yetmiyor (%d / %d Ryō)" % [ryo, COST], "cb": func(): Hud.close_dialog()})
	opts.append({"label": "Yıkıntıları olduğu gibi bırak", "cb": func(): Hud.close_dialog()})
	Hud.dialog(remains_name(vn), "Sancak direği devrilmiş, altında köyün mührü duruyor. Yeniden kurarsan köy dışından içine doğru inşa edilir; eski klanlar geri gelmez, köyü yeni aileler doldurur ve kurucusu olarak senin adın anılır.", opts)


static func rebuild(vid: String) -> void:
	Hud.close_dialog()
	var r = rec(vid)
	if not bool(r.get("down", false)) or int(Game.profile.get("ryo", 0)) < COST:
		return
	Progress.add_ryo(-COST)
	var vn = String(r.get("old_name", Game.village(vid).get("name", vid)))
	for z in WorldAssault.D()["ruins"]:
		if int(z.get("id", 0)) == int(r.get("zone", -1)):
			z.erase("perm")
			z["t"] = Aging.clock()
			z["dur"] = REBUILD
	r["down"] = false
	r["rebuilt"] = true
	r["kage"] = false
	r["kills"] = 0
	r["founder"] = String(Game.profile.get("name", ""))
	r["clans"] = new_clan_names(4)
	var fl = _flag.get(vid)
	if fl != null and fl.get_ref() != null:
		fl.get_ref().queue_free()
	_flag.erase(vid)
	Hud.banner("%s YENİDEN KURULUYOR" % vn.to_upper(), "Kurucu: %s  •  Yeni aileler: %s" % [String(r["founder"]), ", ".join(PackedStringArray(r["clans"]))], Color(1.0, 0.85, 0.45))
	LazyFx.g("Journal").add("%s'i yeniden kurdum. Köyün yeni aileleri: %s." % [vn, ", ".join(PackedStringArray(r["clans"]))], "milestone")
	TailedBeasts._news("HABER", "%s yeniden kuruluyor. Kurucusu: %s." % [vn, String(r["founder"])])
	Game.save_game()


## Yeniden kurulan köyde tanışılan ninjanın soyadı: köyün yeni ailelerinden
static func new_surname(vid: String) -> String:
	if not rebuilt(vid):
		return ""
	var cl: Array = rec(vid).get("clans", [])
	return String(cl.pick_random()) if not cl.is_empty() else ""


# ------------------------------------------------------------------ sancak direği (yeniden kurma noktası)
static func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	if Game.player == null or Game.profile.is_empty():
		return
	# kuşatma bırakıldı: 20 dk boyunca o köyde kimse senin elinden ölmedi ve köyde değilsin -> köy toparlanır, yeni Kage seçer
	for vid0 in D():
		if siege(vid0) and Game.now() - float(D()[vid0].get("siege_t", Game.now())) > SIEGE_HOLD and vid_at(Game.player.global_position, 1.2) != vid0:
			D()[vid0]["kage"] = false
			D()[vid0]["kills"] = 0
			Kage.succeed(vid0, "savaşta öldürüldü")
	if not any_down():
		return
	var pp: Vector3 = Game.player.global_position
	for vid in D():
		if not down(vid):
			continue
		var fl = _flag.get(vid)
		var have = fl != null and fl.get_ref() != null
		var near = center(vid).distance_to(pp) < float(Game.village(vid)["r"]) + 400.0
		if near and not have:
			var n = RebuildFlag.new()
			n.vid = vid
			Game.get_tree().current_scene.add_child(n)
			n.global_position = Missions.open_ground(center(vid), 8.0)
			_flag[vid] = weakref(n)
		elif not near and have:
			fl.get_ref().queue_free()
			_flag.erase(vid)


class RebuildFlag extends Node3D:
	var vid := ""
	var catch_label := "Köyün mührü"

	func _ready() -> void:
		add_to_group("catchables")
		var b = MB.new()
		var wood = Color(0.32, 0.24, 0.17)
		var cloth = Color(0.55, 0.12, 0.1)
		# devrilmiş sancak direği: kırık kaide + yere yatmış direk + yırtık sancak, yanında taş mühür kaidesi
		b.add("cyl", Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color(0.45, 0.43, 0.4), Vector3.ZERO, 8)
		b.add("cyl", Vector3(0, 0.75, 0), Vector3(0.16, 0.6, 0.16), wood, Vector3(0, 0, deg_to_rad(8.0)), 6)
		b.add("cyl", Vector3(1.9, 0.14, 0.3), Vector3(0.14, 3.6, 0.14), wood, Vector3(0, deg_to_rad(12.0), deg_to_rad(88.0)), 6)
		b.add("box", Vector3(2.6, 0.06, 0.95), Vector3(1.5, 0.03, 1.1), cloth, Vector3(0, deg_to_rad(18.0), 0))
		b.add("box", Vector3(3.2, 0.07, 1.5), Vector3(0.5, 0.03, 0.35), cloth.darkened(0.25), Vector3(0, deg_to_rad(40.0), 0))
		b.add("box", Vector3(-0.9, 0.2, 0.5), Vector3(0.55, 0.4, 0.55), Color(0.5, 0.48, 0.45), Vector3(0, deg_to_rad(25.0), deg_to_rad(6.0)))
		b.add("cyl", Vector3(-0.9, 0.43, 0.5), Vector3(0.3, 0.06, 0.3), Color(0.75, 0.2, 0.15), Vector3(0, 0, deg_to_rad(6.0)), 8)
		var mi = MeshInstance3D.new()
		mi.mesh = b.build(LazyFx.g("Props").toon())
		add_child(mi)

	func catch() -> void:
		LazyFx.g("VillageFall").ask_rebuild(vid)
