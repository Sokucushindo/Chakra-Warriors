class_name WorldRelations
extends RefCounted
## Köyler arası ilişkiler (kullanıcı 2026-11-24: "kage sistemini geliştireceğiz köylerin birbiri ile olan ilişkileri görevler").
## Eskiden ilişki yalnız oyuncunun köyüyle öbürleri arasındaydı ve yalnız Kage masasından oynardı; dünya kendi başına hiçbir şey yapmazdı.
## Şimdi beş büyük köyün HER ikilisi arasında bir ilişki var (Kage.relation(vid) = senin köyünle o köy arası, aynı tablo).
## Başlangıç kanondan (Konoha–Suna ittifakı, Hyūga olayından kalan Konoha–Kumo soğukluğu, Üçüncü Savaş'tan kalan Iwa husumeti...),
## sonrası dünyanın kendi verisinden yürür:
##  · Kage'lerin mizacı (gerçek kişiyse WorldDay.temper: atak/temkinli, sıcak/soğuk) ilişkiyi kendi yönüne çeker
##  · olaylar gerçek insanlarla yaşanır: sınır çatışmasında iki köyün gerçek ninjaları ölür, kan soyu kaçırma (Hyūga olayı),
##    yakalanan casus, barış elçisi, ortak Chūnin sınavı, ticaret / ittifak anlaşması
##  · ilişki savaş eşiğine inince ve Kage'lerden biri atılgansa savaş ilan edilir; muharebeler iki köyün arasındaki küçük ülkede
##    olur (kanon: büyük köyler savaşlarını Ame / Kusa gibi küçük ülkelerde yaptı), iki taraftan gerçek insanlar ölür;
##    müttefikler taraf tutar; kayıplar ağırlaşınca ya da Kage değişince ateşkes
##  · senin köyün işin içindeyse olay görev panosuna düşer (WorldNews: sınır karakolu, kaçırılan varis, barış elçisi, cephe,
##    casusluk, müttefik çağrısı). Sen gitmezsen köyün başka bir takımı gider; sonucu dünyaya yazılır.
## Dünya oyuncu merkezli değil: olaylar oyuncu nerede olursa olsun yaşanır, görev sırasında pano bekler (Missions.quiet).
## Kayıt: Game.profile["wrel"] = {"pairs": {"a|b": int}, "pact": {"a|b": "ticaret"/"ittifak"}, "war": {"a|b": savaş}, "t", "hist"}

const GREAT := ["konoha", "suna", "kiri", "kumo", "iwa"]
## kanon başlangıç (Part I öncesi dünya): Konoha–Suna ittifakı, Hyūga olayı (Kumo), Üçüncü Savaş (Iwa), Kanlı Sis'in kapalılığı (Kiri)
const CANON := {"konoha|suna": 45, "konoha|kumo": -15, "iwa|konoha": -30, "kiri|konoha": 0, "kumo|suna": 0, "kiri|suna": -5,
	"iwa|suna": -15, "kiri|kumo": -10, "iwa|kumo": -25, "iwa|kiri": 0}
const CANON_PACT := {"konoha|suna": "ittifak"}
## küçük köyler (kendi ninjaları olanlar): büyük köylerle ilişkileri var, birbirleriyle yok. Kanon: Ame Hanzō'nun kapalı köyü ve büyük
## savaşların meydanı; Iwa Üçüncü Savaş'ta Kusa'yı işgal etti; Taki Konoha'ya yakın; Oto Orochimaru'nun köyü, Suna ile Konoha'yı bastı
const MINOR := ["ame", "kusa", "taki", "oto"]
const CANON_MINOR := {"ame|konoha": -10, "ame|suna": -10, "ame|iwa": -10, "ame|kiri": -5, "ame|kumo": -5,
	"konoha|kusa": 15, "iwa|kusa": -25, "kusa|suna": 0, "kiri|kusa": 0, "kumo|kusa": 0,
	"konoha|taki": 20, "iwa|taki": -5, "suna|taki": 0, "kiri|taki": 0, "kumo|taki": 0,
	"konoha|oto": -45, "oto|suna": 25, "iwa|oto": -10, "kiri|oto": -10, "kumo|oto": -15}
const REPARATION := 30000   # savaşı kaybeden köyün kazanana ödediği tazminat (Kage masası hazinesi)
## savaşların yapıldığı küçük ülkeler (Uzushio harabe, Demir Ülkesi tarafsız: savaş girmez)
const FRONTS := ["ame", "kusa", "taki", "oto", "yu", "shimo", "tani", "nami"]
const TURN := 420.0        # gerçek sn: her turda bir köy ikilisinde bir olay
const WAR_AT := -60
const TENSE_AT := -20
const TRADE_AT := 30
const ALLY_AT := 60
const PEACE_AT := -25      # ateşkesle ilişki buraya çıkar
const WAR_DEAD := 6        # bir taraf bu kadar ölü verince barış ister

static var _t := 60.0


static func D() -> Dictionary:
	var pr: Dictionary = Game.profile
	if not pr.has("wrel") or not pr["wrel"] is Dictionary:
		var d = {"pairs": {}, "pact": CANON_PACT.duplicate(), "war": {}, "hist": []}
		for k in CANON:
			d["pairs"][k] = int(CANON[k])
		# eski kayıt: Kage masasında değişmiş ilişkiler korunur (dokunulmamış 10'lar kanona döner)
		var home = Progress.home()
		var old: Dictionary = (pr.get("kage", {}) as Dictionary).get("rel", {}) if pr.get("kage") is Dictionary else {}
		for v in old:
			if String(v) in GREAT and String(v) != home and int(old[v]) != 10:
				d["pairs"][key(home, String(v))] = int(old[v])
		var kg: Dictionary = pr.get("kage", {}) if pr.get("kage") is Dictionary else {}
		for v in kg.get("trade", {}):
			d["pact"][key(home, String(v))] = "ticaret"
		for v in kg.get("alliance", {}):
			d["pact"][key(home, String(v))] = "ittifak"
		pr["wrel"] = d
	var w: Dictionary = pr["wrel"]
	if not w.has("sway"):
		w["sway"] = {}   # küçük ülke -> hakimiyetindeki büyük köy (savaşla kazanılır)
		for k in CANON_MINOR:
			if not w["pairs"].has(k):
				w["pairs"][k] = int(CANON_MINOR[k])
	return w


static func key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


static func other(k: String, v: String) -> String:
	var ab = k.split("|")
	return ab[1] if ab[0] == v else ab[0]


static func rel(a: String, b: String) -> int:
	if a == b or Game.profile.is_empty():
		return 100
	return int(D()["pairs"].get(key(a, b), 0))


static func change(a: String, b: String, n: int) -> void:
	if a == b or not a in GREAT + MINOR or not b in GREAT + MINOR or (a in MINOR and b in MINOR) or Game.profile.is_empty():
		return
	var k = key(a, b)
	D()["pairs"][k] = clampi(rel(a, b) + n, -100, 100)
	# ittifak ilişki çökünce bozulur
	if String(D()["pact"].get(k, "")) == "ittifak" and rel(a, b) < 20:
		D()["pact"].erase(k)
		_hist("%s ile %s arasındaki ittifak bozuldu." % [vn(a), vn(b)])
	elif String(D()["pact"].get(k, "")) == "ticaret" and rel(a, b) < 0:
		D()["pact"].erase(k)


static func pact(a: String, b: String) -> String:
	return String(D()["pact"].get(key(a, b), ""))


static func set_pact(a: String, b: String, what: String) -> void:
	D()["pact"][key(a, b)] = what


static func at_war(a: String, b: String) -> bool:
	return D()["war"].has(key(a, b))


static func wars_of(v: String) -> Array:
	return (D()["war"] as Dictionary).keys().filter(func(k): return v in String(k).split("|")).map(func(k): return other(String(k), v))


static func allies_of(v: String) -> Array:
	return GREAT.filter(func(o): return o != v and pact(v, o) == "ittifak")


## Durum yazısı (oyuncuya)
static func state(a: String, b: String) -> String:
	if at_war(a, b):
		return "SAVAŞ"
	var r = rel(a, b)
	if pact(a, b) == "ittifak":
		return "İttifak"
	if r <= -40:
		return "Düşmanca"
	if r <= TENSE_AT:
		return "Gergin"
	if r >= TRADE_AT:
		return "Dostane"
	return "Barışçıl"


static func vn(v: String) -> String:
	return WorldPeople.vname(v)


static func _hist(text: String) -> void:
	var h: Array = D()["hist"]
	h.push_front(text)
	if h.size() > 14:
		h.resize(14)


static func recent() -> Array:
	return D()["hist"]


static func _news(text: String, col := Color(1, 0.85, 0.6)) -> void:
	_hist(text)
	WorldNews.headline(text, col)


# ====================================================================== Kage mizacı
## x: atak (+) / temkinli (−), y: sıcak (+) / soğuk (−). Oyuncu Kage ise kendi kararlarıyla yönetir (0).
static func leader(v: String) -> Vector2:
	if Kage.is_kage() and v == Progress.home():
		return Vector2.ZERO
	var r = Kage.reign(v)
	var wp = WorldPeople.get_p(String(r.get("wid", "")))
	if not wp.is_empty():
		return WorldDay.temper(wp)
	var nm = String(r.get("name", Kage.KAGE_NAMES.get(v, v)))
	return Vector2(WorldDay._h(nm, "atak") * 2.0 - 1.0, WorldDay._h(nm, "sicak") * 2.0 - 1.0)


# ====================================================================== dünya turu
static func tick(dt: float) -> void:
	if Game.profile.is_empty() or not WorldPeople.data().get("init", false):
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = TURN * randf_range(0.8, 1.2)
	turn()


static func turn() -> void:
	var d = D()
	# 1) Kage'lerin mizacı ilişkiyi yavaşça kendi yönüne çeker; anlaşmalar ilişkiyi tutar
	for k in d["pairs"]:
		var ab = String(k).split("|")
		var la = leader(ab[0])
		var lb = leader(ab[1])
		var target = float(CANON.get(k, CANON_MINOR.get(k, 0))) * 0.5 + (la.y + lb.y) * 20.0 - (la.x + lb.x) * 10.0
		for m in ab:
			if m in MINOR and sway_of(m) != "":
				target += 25.0 if sway_of(m) == other(String(k), m) else -15.0   # hakimi ile yakın, hakiminin düşmanına soğuk
		if String(d["pact"].get(k, "")) == "ittifak":
			target = maxf(target, 50.0)
		elif String(d["pact"].get(k, "")) == "ticaret":
			target = maxf(target, 25.0)
		if d["war"].has(k):
			continue   # savaşta ilişki muharebeyle yürür
		var cur = int(d["pairs"][k])
		if absf(target - cur) >= 1.0:
			d["pairs"][k] = cur + clampi(int(target - cur), -2, 2)
	# 2) süren savaşlar: muharebe ya da ateşkes
	for k in (d["war"] as Dictionary).keys():
		_war_turn(String(k))
	# 3) bir ikilide bir olay (gerilimli / dostane olana göre)
	var ks: Array = (d["pairs"] as Dictionary).keys().filter(func(k): return not d["war"].has(k))
	ks.shuffle()
	if randf() < 0.7 and not ks.is_empty():
		var big = ks.filter(func(x): return not _has_minor(String(x)))
		_event(String(big[0]) if not big.is_empty() and randf() < 0.65 else String(ks[0]))
	# 4) savaş ilanı: ilişki eşikte ve Kage'lerden biri atılgan
	for k in ks:
		if int(d["pairs"][k]) > WAR_AT or d["war"].has(k):
			continue
		var ab = String(k).split("|")
		if maxf(leader(ab[0]).x, leader(ab[1]).x) > 0.1 or int(d["pairs"][k]) <= -85:
			declare_war(ab[0], ab[1])
	Kage.relations_changed.emit()


static func _has_minor(k: String) -> bool:
	var ab = k.split("|")
	return ab[0] in MINOR or ab[1] in MINOR


## Küçük ülkenin hakimi (savaşla aldı); yoksa ""
static func sway_of(m: String) -> String:
	return String(D()["sway"].get(m, ""))


# ====================================================================== olaylar
## Köyün görevde olmayan, sağlam gerçek ninjaları (rütbe ≥ min_rank)
static func _people(v: String, min_rank := 0) -> Array:
	return WorldPeople.all().values().filter(func(p): return String(p["village"]) == v and WorldPeople.alive(p) and not WorldPeople.is_rogue(p) \
		and not p.get("missing", false) and not p.has("kage") and int(p["rank"]) >= min_rank and not WorldDay.away(p) and not WorldDay.hurt(p))


static func _event(k: String) -> void:
	if k == "":
		return
	var ab = String(k).split("|")
	var a: String = ab[0]
	var b: String = ab[1]
	if randf() < 0.5:
		var t = a
		a = b
		b = t
	var r = rel(a, b)
	var la = leader(a)
	var lb = leader(b)
	var home = Progress.home()
	var opts = []   # [ad, ağırlık]
	if r < 15:
		opts.append(["sinir", 0.6 + maxf(0.0, la.x) * 1.5 - r / 50.0])
		opts.append(["casus", 0.8])
	if r < 25 and la.x > 0.0 and la.y < 0.2:
		opts.append(["kacirma", 0.5 + la.x])
	if r < 0 and (la.y > 0.0 or lb.y > 0.0):
		opts.append(["elci", 1.0 + maxf(la.y, lb.y)])
	if r >= 10:
		opts.append(["sinav", 0.8 + maxf(0.0, la.y)])
	if r >= TRADE_AT and pact(a, b) == "":
		opts.append(["ticaret", 1.0])
	if r >= ALLY_AT and pact(a, b) != "ittifak":
		opts.append(["ittifak", 0.6 + maxf(0.0, la.y + lb.y)])
	if opts.is_empty():
		return
	var sum = 0.0
	for o in opts:
		sum += maxf(0.05, float(o[1]))
	var x = randf() * sum
	var ev = String(opts[0][0])
	for o in opts:
		x -= maxf(0.05, float(o[1]))
		if x <= 0.0:
			ev = String(o[0])
			break
	# senin köyün işin içindeyse olay görev panosuna düşer (aynı türden açık ilan varken yenisi asılmaz)
	if home in [a, b] and (b if a == home else a) in GREAT:
		var foe = b if a == home else a
		match ev:
			"sinir":
				if _post("border", home, foe):
					return
			"kacirma":
				if a != home and _post("kidnap", home, foe):
					return
			"elci":
				if _post("envoy", home, foe):
					return
			"casus":
				if a == home and _post("spy", home, foe):
					return
	match ev:
		"sinir":
			_border_clash(a, b, false)
		"casus":
			var spies = _people(a, 1)
			if spies.is_empty():
				return
			var s: Dictionary = spies.pick_random()
			if randf() < 0.5:
				WorldPeople._die(s, "%s'de casuslukla yakalandı ve idam edildi" % vn(b))
				change(a, b, -10)
				_news("%s, topraklarında yakaladığı bir %s casusunu (%s) idam etti." % [vn(b), vn(a), String(s["name"])], Color(1, 0.65, 0.55))
			else:
				WorldPeople.log_event(s, "%s topraklarına sızıp sırlarını çaldı" % vn(b))
				change(a, b, -4)
				_hist("Söylenti: %s karargâhından gizli belgeler çalınmış." % vn(b))
		"kacirma":
			_kidnap(a, b, false)
		"elci":
			_envoy(a, b, randf() < 0.6)
		"sinav":
			change(a, b, 8)
			_news("%s ve %s ortak bir Chūnin Sınavı düzenledi; iki köyün gençleri aynı arenada yarıştı." % [vn(a), vn(b)], Color(0.75, 0.95, 1.0))
		"ticaret":
			set_pact(a, b, "ticaret")
			change(a, b, 5)
			_news("%s ile %s ticaret anlaşması imzaladı." % [vn(a), vn(b)], Color(0.75, 0.95, 0.75))
		"ittifak":
			set_pact(a, b, "ittifak")
			change(a, b, 10)
			var mn = a if a in MINOR else (b if b in MINOR else "")
			if mn != "":
				D()["sway"][mn] = other(key(a, b), mn)
				_news("%s, %s himayesine girdi." % [vn(mn), vn(other(key(a, b), mn))], Color(0.75, 0.95, 1.0))
			else:
				_news("%s ile %s resmi ittifak kurdu!" % [vn(a), vn(b)], Color(0.7, 1.0, 0.7))
			if home in [a, b]:
				Hud.banner("İTTİFAK", "%s ile %s artık müttefik." % [vn(a), vn(b)], Color(0.7, 1.0, 0.7))


## Sınır çatışması: iki köyün gerçek ninjaları karşılaşır; biri (bazen ikisi) ölür
static func _border_clash(a: String, b: String, by_player: bool) -> void:
	var pa = _people(a, 1)
	var pb = _people(b, 1)
	if pa.is_empty() or pb.is_empty():
		return
	var x: Dictionary = pa.pick_random()
	var y: Dictionary = pb.pick_random()
	var win = x if float(x["level"]) * randf_range(0.7, 1.3) > float(y["level"]) * randf_range(0.7, 1.3) else y
	var lose = y if win == x else x
	if randf() < 0.5:
		# yaralı döner (hastanede yatar); kan dökülmediği için gerilim daha az artar
		lose["hurt_t"] = Aging.clock() + randf_range(400.0, 800.0)
		WorldPeople.log_event(lose, "%s sınırında %s ninjası %s ile çatıştı; ağır yaralı döndü" % [vn(b), vn(String(win["village"])), String(win["name"])])
		change(a, b, -randi_range(4, 8))
		_news("Sınırda çatışma: %s ninjası %s, %s ninjası %s ile çatışmada ağır yaralandı." % [vn(String(lose["village"])), String(lose["name"]), vn(String(win["village"])), String(win["name"])], Color(1, 0.7, 0.55))
		return
	WorldPeople._die(lose, "%s sınırında %s ninjası %s ile çatışmada öldü" % [vn(b), vn(String(win["village"])), String(win["name"])])
	WorldPeople.log_event(win, "Sınırda %s ninjası %s öldürdü" % [vn(String(lose["village"])), WorldNews.sfx(String(lose["name"]), "i")])
	change(a, b, -randi_range(8, 15))
	_news("Sınırda çatışma: %s ninjası %s, %s ninjası %s tarafından öldürüldü." % [vn(String(lose["village"])), String(lose["name"]), vn(String(win["village"])), String(win["name"])], Color(1, 0.6, 0.5))


## Kan soyu kaçırma (kanon: Hyūga olayı). a kaçıran, b kurban köy
static func _kidnap(a: String, b: String, _by_player: bool) -> void:
	var vic = _people(b, 0).filter(func(p): return int(p["rank"]) <= 1 and (int(ClanWorld.EYE_KIND.get(String(p["clan"]), 0)) > 0 or not (p.get("nat", []) as Array).is_empty()))
	var kid = _people(a, 2)
	if vic.is_empty() or kid.is_empty():
		return
	var v: Dictionary = vic.pick_random()
	var k: Dictionary = kid.pick_random()
	if float(v["level"]) + 40.0 > float(k["level"]) * randf_range(0.8, 1.5):
		WorldPeople._die(k, "%s'de %s kaçırmaya kalkıştı; yakalanıp öldürüldü" % [vn(b), WorldNews.sfx(String(v["name"]), "i")])
		WorldPeople.log_event(v, "%s ninjası %s onu kaçırmaya kalktı; kurtarıldı" % [vn(a), String(k["name"])])
		change(a, b, -15)
		_news("%s'de kaçırma girişimi: %s ninjası %s, %s kaçırmaya çalışırken öldürüldü. %s her şeyi inkâr ediyor." % [vn(b), vn(a), String(k["name"]), WorldNews.sfx(String(v["name"]), "i"), vn(a)], Color(1, 0.6, 0.5))
	else:
		taken(v, a, String(k["name"]))
		change(a, b, -25)


## Kaçırılan kişi kaçıranın köyüne geçer (kanı orada sürer)
static func taken(v: Dictionary, to: String, by: String) -> void:
	var from = String(v["village"])
	v["village"] = to
	v["loyalty"] = 30
	WorldPeople.log_event(v, "%s tarafından kaçırılıp %s topraklarına götürüldü" % [by, vn(to)])
	_news("%s ninjası %s kaçırıldı! Kanı artık %s için akacak." % [vn(from), String(v["name"]), vn(to)], Color(1, 0.5, 0.45))


## Barış elçisi: a'nın elçisi b'ye gider
static func _envoy(a: String, b: String, ok: bool) -> void:
	var env = _people(a, 2)
	if env.is_empty():
		return
	var e: Dictionary = env.pick_random()
	if ok:
		change(a, b, 15)
		WorldPeople.log_event(e, "%s ile barış görüşmesine gitti; görüşme olumlu geçti" % vn(b))
		_news("%s elçisi %s, %s ile görüştü: iki köy arasında yumuşama." % [vn(a), String(e["name"]), vn(b)], Color(0.75, 0.95, 1.0))
	else:
		WorldPeople._die(e, "%s ile barış görüşmesine giderken pusuya düşürüldü" % vn(b))
		change(a, b, -12)
		_news("%s barış elçisi %s, %s yolunda öldürüldü. Kimin yaptığı belli değil." % [vn(a), String(e["name"]), vn(b)], Color(1, 0.6, 0.5))


# ====================================================================== savaş
## İki köy arasında savaşın yapıldığı küçük ülke: iki köyün ortasına en yakın küçük köy
static func front_of(a: String, b: String) -> String:
	if a in MINOR:
		return a
	if b in MINOR:
		return b
	var va = Game.village(a)
	var vb = Game.village(b)
	if va.is_empty() or vb.is_empty():
		return ""
	var mid = (Vector2(float(va["x"]), float(va["y"])) + Vector2(float(vb["x"]), float(vb["y"]))) * 0.5
	var best = ""
	var bd = INF
	for f in FRONTS:
		var vf = Game.village(f)
		if vf.is_empty():
			continue
		var dd = mid.distance_to(Vector2(float(vf["x"]), float(vf["y"])))
		if dd < bd:
			bd = dd
			best = f
	return best


static func declare_war(a: String, b: String) -> void:
	var d = D()
	var k = key(a, b)
	if d["war"].has(k):
		return
	d["pact"].erase(k)
	d["pairs"][k] = mini(int(d["pairs"].get(k, 0)), WAR_AT)
	var fr = front_of(a, b)
	d["war"][k] = {"since": Aging.clock(), "turns": 0, "dead": {a: 0, b: 0}, "front": fr, "intel": ""}
	var home = Progress.home()
	var txt = "%s ile %s arasında savaş başladı! Cephe: %s." % [vn(a), vn(b), vn(fr) if fr != "" else "sınır"]
	_news(txt, Color(1, 0.4, 0.35))
	if home in [a, b]:
		Hud.banner("SAVAŞ İLAN EDİLDİ", "%s ile köyün savaşta. Cephe %s topraklarında." % [vn(b if a == home else a), vn(fr) if fr != "" else "sınır"], Color(1, 0.35, 0.3))
		Journal.add(txt, "milestone")
	# müttefikler taraf tutar (kanon: ittifak savaşta birlikte durur)
	for side in [a, b]:
		var foe = b if side == a else a
		for al in allies_of(side):
			if al != foe:
				change(al, foe, -15)


## Savaş biter. Kaybeden: daha çok ölü veren (ya da barışı isteyen: loser). Sonuçlar kalıcı:
##  · kaybeden kazanana tazminat öder (oyuncu Kage ise hazineden; köyün itibarı da değişir)
##  · cephenin bulunduğu küçük ülke kazananın hakimiyetine girer (o ülkenin ninjaları sonraki muharebelerinde yanında durur)
##  · küçük köy kaybederse kazananın hakimiyetine girer; büyük köyün Kage'si kaybederse şapkasını bırakabilir (kanon: savaş sonrası istifa)
static func _end_war(k: String, why: String, loser := "") -> void:
	var d = D()
	var ab = k.split("|")
	var w: Dictionary = d["war"].get(k, {})
	d["war"].erase(k)
	d["pairs"][k] = maxi(int(d["pairs"].get(k, 0)), PEACE_AT)
	var home = Progress.home()
	var dead: Dictionary = w.get("dead", {})
	if loser == "":
		loser = ab[0] if int(dead.get(ab[0], 0)) > int(dead.get(ab[1], 0)) else (ab[1] if int(dead.get(ab[1], 0)) > int(dead.get(ab[0], 0)) else "")
	var winner = other(k, loser) if loser != "" else ""
	var out = []
	if winner != "":
		out.append("%s savaşı kazandı" % vn(winner))
		if loser in GREAT and winner in GREAT:
			out.append("%s tazminat ödeyecek" % vn(loser))
		var fr = String(w.get("front", ""))
		if fr != "" and fr != winner:
			var was = sway_of(fr)
			d["sway"][fr] = winner
			if was != winner:
				out.append("%s artık %s hakimiyetinde" % [vn(fr), vn(winner)])
		if loser in GREAT and not (Kage.is_kage() and loser == home) and randf() < 0.35:
			Kage.succeed(loser, "savaşı kaybettiği için şapkasını bıraktı")
	_news("%s ile %s ateşkes imzaladı: %s%s" % [vn(ab[0]), vn(ab[1]), why, (" " + ", ".join(out) + ".") if not out.is_empty() else ""], Color(0.75, 0.95, 0.75))
	if home in ab:
		var won = winner == home
		var lost = loser == home
		Hud.banner("ATEŞKES", ("Savaşı kazandık! " if won else ("Savaşı kaybettik. " if lost else "")) + ("%s ile savaş sona erdi." % vn(other(k, home))), Color(0.75, 0.95, 0.75) if not lost else Color(1, 0.7, 0.55))
		Missions._rep(home, 10 if won else (-5 if lost else 0))
		if Kage.is_kage() and winner in GREAT and loser in GREAT:
			var kk = Kage.st()
			kk["funds"] = maxi(0, int(kk["funds"]) + (REPARATION if won else (-REPARATION if lost else 0)))
			if won or lost:
				Kage.add_log("%s ile savaş bitti: %s tazminat (%s%d Ryō)." % [vn(other(k, home)), "alınan" if won else "ödenen", "+" if won else "−", REPARATION])


## Muharebe: iki köyden gerçek ninjalar cephede karşılaşır; kayıplar gerçek
static func _war_turn(k: String) -> void:
	var d = D()
	var w: Dictionary = d["war"][k]
	w["turns"] = int(w["turns"]) + 1
	var ab = k.split("|")
	var a: String = ab[0]
	var b: String = ab[1]
	# ateşkes: ağır kayıp, temkinli / sıcak liderler, uzun savaş
	var da = int((w["dead"] as Dictionary).get(a, 0))
	var db = int((w["dead"] as Dictionary).get(b, 0))
	if maxi(da, db) >= WAR_DEAD:
		_end_war(k, "%s ağır kayıplar verdi ve barış istedi." % vn(a if da >= db else b))
		return
	var calm = -minf(leader(a).x, leader(b).x) + maxf(leader(a).y, leader(b).y)
	if int(w["turns"]) >= 3 and randf() < 0.08 + 0.12 * maxf(0.0, calm):
		_end_war(k, "Kage'ler masaya oturdu.")
		return
	var home = Progress.home()
	if home in [a, b]:
		if _post("front", home, other(k, home)):
			return   # muharebe görev olarak bekliyor (sen gitmezsen köyün takımı gider)
	else:
		for al in allies_of(home):
			if al in [a, b] and not at_war(home, other(k, al)):
				if _post("ally", home, other(k, al), {"ally": al}):
					return
	battle(a, b)


## Muharebe sonucu (oyuncu yoksa ya da görevi almadıysa). bonus: o köyün üstünlüğü (istihbarat, müttefik yardımı)
static func battle(a: String, b: String, bonus := {}) -> Dictionary:
	var k = key(a, b)
	var w: Dictionary = D()["war"].get(k, {})
	var sa = _people(a, 1)
	var sb = _people(b, 1)
	sa.shuffle()
	sb.shuffle()
	sa = sa.slice(0, 5)
	sb = sb.slice(0, 5)
	if sa.is_empty() or sb.is_empty():
		return {}
	var pa = 0.0
	var pb = 0.0
	for p in sa:
		pa += float(p["level"])
	for p in sb:
		pb += float(p["level"])
	pa *= randf_range(0.75, 1.25) * (1.0 + float(bonus.get(a, 0.0)))
	pb *= randf_range(0.75, 1.25) * (1.0 + float(bonus.get(b, 0.0)))
	var fr0 = String(w.get("front", ""))
	if fr0 != "" and sway_of(fr0) in [a, b]:
		# hakim olduğu ülkede savaşan taraf: o ülkenin ninjaları yanında, yolları biliyor
		if sway_of(fr0) == a:
			pa *= 1.15
		else:
			pb *= 1.15
	if String(w.get("intel", "")) in [a, b]:
		if String(w["intel"]) == a:
			pa *= 1.3
		else:
			pb *= 1.3
		w["intel"] = ""
	var win = a if pa >= pb else b
	var lose = b if win == a else a
	var ls: Array = sb if win == a else sa
	var ws: Array = sa if win == a else sb
	var fr = String(w.get("front", ""))
	var place = vn(fr) if fr != "" else "sınır"
	var dead = []
	for i in mini(ls.size(), randi_range(1, 2)):
		WorldPeople._die(ls[i], "%s–%s savaşında, %s cephesinde düştü" % [vn(a), vn(b), place])
		dead.append(String(ls[i]["name"]))
	if randf() < 0.4:
		WorldPeople._die(ws[0], "%s–%s savaşında, %s cephesinde düştü" % [vn(a), vn(b), place])
		_add_dead(k, win, 1)
	_add_dead(k, lose, dead.size())
	for p in ws:
		if WorldPeople.alive(p):
			WorldPeople.log_event(p, "%s cephesinde %s ile savaştı" % [place, vn(lose)])
	_news("%s cephesi: %s üstün geldi. %s kayıpları: %s." % [place, vn(win), vn(lose), ", ".join(dead)], Color(1, 0.55, 0.45))
	# savaş yabancı bir ülkede: o ülkenin insanları arada kalır (kanon: Ame'nin savaş yetimleri)
	if fr in MINOR and not fr in [a, b] and randf() < 0.3:
		var loc = _people(fr, 0)
		if not loc.is_empty():
			var vic: Dictionary = loc.pick_random()
			WorldPeople._die(vic, "%s–%s savaşının ortasında, kendi ülkesinde öldü" % [vn(a), vn(b)])
			change(fr, a, -4)
			change(fr, b, -4)
	return {"win": win, "dead": dead}


static func _add_dead(k: String, v: String, n: int) -> void:
	var w: Dictionary = D()["war"].get(k, {})
	if w.is_empty():
		return
	w["dead"][v] = int((w["dead"] as Dictionary).get(v, 0)) + n


## Oyuncu cephede savaştı: düşmandan ölen gerçek kişiler zaten Enemy.die ile ölür; burada savaş sayımı
static func player_battle(foe: String, ok: bool, ally := "") -> void:
	var home = Progress.home()
	var side = ally if ally != "" else home
	var k = key(side, foe)
	if not D()["war"].has(k):
		return
	if ok:
		_add_dead(k, foe, 3)
		if ally != "":
			change(home, ally, 10)
	else:
		battle(side, foe, {foe: 0.3})


# ====================================================================== görev panosu (WorldNews)
## Senin köyünün panosuna ilan: true asıldı
static func _post(kind: String, home: String, foe: String, extra := {}) -> bool:
	if Orgs.is_rogue():
		return false   # köyünden kaçmış birine köyünün panosu iş vermez
	if not foe in GREAT:
		return false   # küçük köyle olanlar dünyada yaşanır (görev düşman kalıbı büyük köylerin)
	var who = ""
	match kind:
		"border", "front", "ally":
			var c = _people(foe, 2)
			if c.is_empty():
				return false
			who = String(c.pick_random()["id"])
		"kidnap":
			var vic = _people(home, 0).filter(func(p): return int(p["rank"]) <= 1 and (int(ClanWorld.EYE_KIND.get(String(p["clan"]), 0)) > 0 or not (p.get("nat", []) as Array).is_empty()))
			var kid = _people(foe, 2)
			if vic.is_empty() or kid.is_empty():
				return false
			who = String(vic.pick_random()["id"])
			extra["kidnapper"] = String(kid.pick_random()["id"])
		"envoy":
			var c2 = _people(home, 2)
			if c2.is_empty():
				c2 = _people(home, 1)
			if c2.is_empty():
				return false
			who = String(c2.pick_random()["id"])
		"spy":
			var c3 = _people(foe, 1)
			if c3.is_empty():
				return false
			who = String(c3.pick_random()["id"])
	if (WorldNews.D()["list"] as Array).any(func(x): return String(x["kind"]) == kind and String(x.get("foe", "")) == foe and String(x["state"]) != "closed"):
		return true   # aynı ilan zaten panoda: olay onu bekliyor
	extra["foe"] = foe
	if kind in ["front", "ally"]:
		extra["front"] = String(D()["war"].get(key(String(extra.get("ally", home)), foe), {}).get("front", ""))
	return not WorldNews.add(kind, home, who, extra).is_empty()
