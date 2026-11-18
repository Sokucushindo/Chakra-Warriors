extends RefCounted
## Hazır setler, grup c: ref'e göre gerçek 3B ayrıntı (biye, dikiş, düğme, cep, toka, kuşak, plaka). Hedef: res://scripts/actors/set_v2_c.gd
## Ayrıntı en dıştaki uygun kabuğa derilenir (kıyafet katmanı varsa o, yoksa gövde); kumaşla birlikte bükülür.
## Ağlar set + cinsiyet başına bir kez kurulur, sonraki modeller (NPC dahil) hazır ağı kullanır.

const SETS := ["ss_orman_zirh_genc", "ss_pembe_ceket", "ss_pembe_genc", "ss_pembe_kazak", "ss_pembe_kunoichi", "ss_pembe_kunoichi2", "ss_pijama",
	"ss_ruzgar_elbise", "ss_ruzgar_elbise2", "ss_ruzgar_genc", "ss_ruzgar_kimono", "ss_ruzgar_zirh", "ss_sahil", "ss_sahil_denizci", "ss_sahil_flamingo",
	"ss_sahil_gok", "ss_sahil_hibiskus", "ss_sakaci", "ss_samuray_kuro", "ss_sari_simsek", "ss_sari_simsek_genc", "ss_savas_reisi", "ss_savas_reisi2",
	"ss_savas_reisi3", "ss_savas_reisi_genc", "ss_seytan", "ss_sigara_jonin", "ss_silah_ustasi", "ss_simsek_kiyafet", "ss_sis_striker",
	"ss_sis_striker_beyaz", "ss_sis_striker_siyah", "ss_siyah_ceket", "ss_siyah_tulum", "ss_sokak", "ss_son_savas", "ss_soylu_pelerin", "ss_su_elbise",
	"ss_su_zirh", "ss_suna_genin", "ss_tas_yasli", "ss_tatli", "ss_tatli_baklava", "ss_tatli_kultur", "ss_tavsan_tanri", "ss_tavsan_tanri2",
	"ss_tehlike_ceket", "ss_turuncu_ceket", "ss_turuncu_esofman", "ss_turuncu_genc", "ss_turuncu_maske", "ss_yaprak_striker", "ss_yaprak_striker_kovboy",
	"ss_yaprak_striker_matador", "ss_yaz", "ss_yedi_kanat", "ss_yelpaze", "ss_yelpaze_b", "ss_yelpaze_cocuk", "ss_yelpaze_genc", "ss_yelpaze_genc2",
	"ss_yelpaze_kilic", "ss_yelpaze_kolsuz", "ss_yelpaze_takim", "ss_yelpaze_yirtik", "ss_yelpaze_zirh", "ss_yemek", "ss_yeni_nesil", "ss_yeni_nesil2",
	"ss_yesil_canavar", "ss_yesil_canavar2", "ss_yilan_cubbe", "ss_yilan_kimono", "ss_yilan_sanin", "ss_yilan_zirh", "ss_yirminci", "ss_yirtik_esofman"]

const STEEL := Color(0.68, 0.7, 0.74)
const GOLD := Color(0.84, 0.66, 0.24)
const LEATHER := Color(0.36, 0.24, 0.15)
const INK := Color(0.08, 0.08, 0.1)
const WHITE := Color(0.93, 0.93, 0.9)
const RED := Color(0.72, 0.14, 0.14)

static var _cache := {}


static func C(h: String) -> Color:
	return Color.html(h)


## Ayrıntı kurucu: kabuk seçimi + ortak parçalar
class K:
	var m
	var g: Dictionary
	var n: float
	var c: float
	var h: float
	var w: float
	var kn: float
	var a: float
	var ua: float
	var la: float
	var ha: float
	var ok := false
	var meshes := []
	var dangles := []

	func _init(model, geo: Dictionary) -> void:
		m = model
		g = geo
		n = m._bp("Neck").y
		c = m._bp("UpperChest").y
		h = m._bp("Hips").y
		w = h + 0.09
		kn = m._bp("LeftLowerLeg").y
		a = m._bp("LeftFoot").y
		ua = absf(m._bp("LeftUpperArm").x)
		la = absf(m._bp("LeftLowerArm").x)
		ha = absf(m._bp("LeftHand").x)

	func flush() -> void:
		if ok:
			var mi = m._sk_end(g)
			if mi != null:
				meshes.append(mi.mesh)
		ok = false

	func use(src) -> bool:
		flush()
		ok = src != null and m._sk_begin(src)
		return ok

	func _gender() -> String:
		return str(m.look.get("gender"))

	func _pick(y0: float, y1: float):
		var ls: Array = m._layer_meshes
		for i in range(ls.size() - 1, -1, -1):
			var ab: AABB = (ls[i] as ArrayMesh).get_aabb()
			if ab.position.x < -0.08 and ab.end.x > 0.08 and ab.position.y <= y0 + 0.03 and ab.end.y >= y1 - 0.03:
				return ls[i]
		return m._shell_cache.get(_gender())

	func body() -> bool:
		return use(m._shell_cache.get(_gender()))

	## gövdeyi örten en dış katman
	func top() -> bool:
		return use(_pick(w, n - 0.12))

	## belden aşağı inen etek / cübbe
	func low() -> bool:
		return use(_pick(kn + 0.06, w - 0.04))

	func vest() -> bool:
		var v = m._shell_cache.get(_gender() + "|vest")
		return use(v) if v != null else top()

	## kol: o tarafı içeren son katman
	func arm(s := 1.0) -> bool:
		var ls: Array = m._layer_meshes
		var x = lerpf(ua, ha, 0.5)
		for i in range(ls.size() - 1, -1, -1):
			var ab: AABB = (ls[i] as ArrayMesh).get_aabb()
			if (s > 0.0 and ab.end.x > x and ab.position.x < x) or (s < 0.0 and ab.position.x < -x and ab.end.x > -x):
				return use(ls[i])
		return body()

	func ring(y: float, wd: float, col: Color, d := 0.007, lift := 0.002, a0 := -PI, a1 := PI, bins := 28) -> void:
		if not ok:
			return
		if wd > 0.012:
			m._sk_ring(1, y, wd, d, col, a0, a1, bins, lift)
			return
		var xm = _half_at(y) * 0.96
		var full = a1 - a0 > TAU - 0.01
		if not full:
			xm *= sin(minf(maxf(absf(a0), absf(a1)), PI * 0.5))
		m._sk_path(Vector2(-xm, y), Vector2(xm, y), wd, d, col, true, lift + 0.003, 12)
		if full:
			m._sk_path(Vector2(-xm, y), Vector2(xm, y), wd, d, col, false, lift + 0.003, 12)

	## o yükseklikte kabuğun yarı genişliği (bel üstünde kollar sayılmaz)
	func _half_at(y: float) -> float:
		var cap = 0.15 if y >= w - 0.02 else 0.3
		var best = 0.06
		for q in (m._sk["v"] as PackedVector3Array):
			if absf(q.y - y) < 0.02 and absf(q.x) < cap and absf(q.x) > best:
				best = absf(q.x)
		return best

	func collar(y: float, wd: float, col: Color, r := 0.14, a0 := -PI, a1 := PI) -> void:
		if ok:
			m._sk_ring(1, y, wd, 0.008, col, a0, a1, 24, 0.003, 0.0, 0.0, r)

	func cuff(t: float, wd: float, col: Color, s := 0.0, d := 0.006, lift := 0.003) -> void:
		if not ok:
			return
		var x = lerpf(ua, ha, t)
		for sg in ([1.0, -1.0] if s == 0.0 else [s]):
			m._sk_ring(0, x * sg, wd, d, col, -PI, PI, 16, lift, sg)

	func line(x0: float, y0: float, x1: float, y1: float, wd: float, col: Color, front := true, steps := 8, d := 0.003) -> void:
		if ok:
			m._sk_path(Vector2(x0, y0), Vector2(x1, y1), wd, d, col, front, 0.003, steps)

	## simetrik çift çizgi
	func pair(x0: float, y0: float, x1: float, y1: float, wd: float, col: Color, front := true, steps := 7) -> void:
		line(x0, y0, x1, y1, wd, col, front, steps)
		line(-x0, y0, -x1, y1, wd, col, front, steps)

	func both(x0: float, y0: float, x1: float, y1: float, wd: float, col: Color, steps := 7) -> void:
		line(x0, y0, x1, y1, wd, col, true, steps)
		line(x0, y0, x1, y1, wd, col, false, steps)

	func plate(x: float, y: float, pw: float, ph: float, col: Color, d := 0.007, front := true, lift := 0.002) -> void:
		if ok:
			m._sk_plate(x, y, pw, ph, d, col, lift, front)

	func btn(x: float, y: float, r: float, col: Color, front := true) -> void:
		plate(x, y, r, r, col, 0.006, front, 0.003)

	func btns(x: float, y0: float, y1: float, cnt: int, r: float, col: Color, front := true) -> void:
		for i in cnt:
			btn(x, lerpf(y0, y1, float(i) / maxf(cnt - 1, 1)), r, col, front)

	func zip(y0: float, y1: float, tape: Color, pull: Color) -> void:
		line(0.0, y0, 0.0, y1, 0.016, tape, true, 10)
		plate(0.0, y0 - 0.02, 0.014, 0.03, pull, 0.006, true, 0.004)

	func pocket(x: float, y: float, pw: float, ph: float, col: Color, flap: Color, b = null, front := true) -> void:
		plate(x, y, pw, ph, col, 0.005, front)
		plate(x, y + ph * 0.5 - 0.012, pw + 0.008, 0.026, flap, 0.006, front, 0.006)
		if b != null:
			btn(x, y + ph * 0.5 - 0.016, 0.012, b, front)

	## bel kuşağı: bant + kenar çizgileri + toka
	func sash(y: float, wd: float, col: Color, edge = null, buckle = null, bw := 0.05) -> void:
		ring(y, wd, col, 0.009, 0.003)
		if edge != null:
			ring(y + wd * 0.5 - 0.004, 0.006, edge, 0.004, 0.011)
			ring(y - wd * 0.5 + 0.004, 0.006, edge, 0.004, 0.011)
		if buckle != null:
			plate(0.0, y, bw, wd * 0.82, buckle, 0.008, true, 0.011)

	func spiral(cx: float, cy: float, r: float, col: Color, front := false) -> void:
		var prev = Vector2(cx, cy)
		for i in range(1, 15):
			var t = i / 14.0
			var ang = t * TAU * 1.7
			var q = Vector2(cx + cos(ang) * r * t, cy + sin(ang) * r * t)
			line(prev.x, prev.y, q.x, q.y, 0.009, col, front, 1)
			prev = q

	## sıra perçin
	func rivets(y: float, x0: float, x1: float, cnt: int, col: Color, front := true, r := 0.011) -> void:
		for i in cnt:
			btn(lerpf(x0, x1, float(i) / maxf(cnt - 1, 1)), y, r, col, front)

	func dangle(bone: String, p: Vector3, dir: Vector3, length: float, wd: float, col: Color, stiff := 0.2) -> void:
		dangles.append([bone, p, dir, length, wd, col, stiff])


static func build(m, sid: String, g: Dictionary) -> void:
	var key = "%s|%s" % [sid, str(m.look.get("gender"))]
	if not _cache.has(key):
		var k = K.new(m, g)
		_recipe(k, sid)
		k.flush()
		_cache[key] = [k.meshes, k.dangles]
		for e in k.dangles:
			m.dangle_strip(e[0], e[1], e[2], e[3], e[4], e[5], e[6])
		return
	var it: Array = _cache[key]
	for mesh in it[0]:
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		m.skel.add_child(mi)
		mi.skin = m.body_mesh.skin
		mi.skeleton = mi.get_path_to(m.skel)
		mi.material_override = Props.toon()
	for e in it[1]:
		m.dangle_strip(e[0], e[1], e[2], e[3], e[4], e[5], e[6])


# ------------------------------------------------------------------ ortak kalıplar (oranlar set başına verilir)
## Zırh: göğüs plakası, karın dilimleri, kordon
static func _cuirass(k: K, plate_c: Color, trim: Color, lace: Color, rows: int, hw: float) -> void:
	k.top()
	var y0 = k.n - 0.13
	var y1 = k.w + 0.02
	for i in rows:
		var y = lerpf(y0, y1, float(i) / maxf(rows - 1, 1))
		k.ring(y, 0.012, trim, 0.005, 0.012, -1.25, 1.25, 16)
	k.pair(hw, y0 + 0.02, hw * 0.9, y1, 0.012, lace)
	k.rivets(y0 + 0.015, -hw * 0.7, hw * 0.7, 4, GOLD)
	k.plate(0.0, lerpf(y0, y1, 0.5), 0.05, 0.05, plate_c.lightened(0.15), 0.008, true, 0.012)


## Geniş kollu cübbe / kimono: yaka bandı V, kol ağzı, etek biyesi
static func _robe(k: K, band: Color, hem = null, cuffc = null) -> void:
	k.top()
	k.pair(0.07, k.n - 0.03, 0.0, k.w + 0.05, 0.02, band)
	if cuffc != null:
		k.arm(1.0)
		k.cuff(0.86, 0.024, cuffc, 1.0)
		k.arm(-1.0)
		k.cuff(0.86, 0.024, cuffc, -1.0)
	if hem != null and k.low():
		k.ring(k.kn - 0.02, 0.02, hem, 0.005, 0.004)


## Eşofman ayrıntısı: fermuar, yaka, omuz dikişi, cep
static func _track(k: K, tape: Color, seam: Color, pull: Color) -> void:
	k.top()
	k.zip(k.n - 0.06, k.w - 0.04, tape, pull)
	k.pair(0.07, k.n - 0.08, 0.15, k.n - 0.13, 0.006, seam)
	k.pair(0.075, k.w + 0.03, 0.115, k.w - 0.04, 0.012, seam)


## Bağcıklı şort: bel bandı, ip, cep dikişi
static func _shorts(k: K, band: Color, cord: Color) -> void:
	k.body()
	k.ring(k.w - 0.03, 0.03, band, 0.006, 0.003)
	k.pair(0.025, k.w - 0.04, 0.03, k.w - 0.13, 0.006, cord)
	k.pair(0.1, k.w - 0.05, 0.14, k.h - 0.08, 0.005, band.darkened(0.2))


## Şişme yelek: yatay dolgu dikişleri, fermuar kenarı
static func _puffer(k: K, col: Color, tape: Color, rows: int) -> void:
	k.top()
	for i in rows:
		k.ring(lerpf(k.n - 0.14, k.w - 0.02, float(i) / maxf(rows - 1, 1)), 0.007, col.darkened(0.2), 0.004, 0.003)
	k.pair(0.055, k.n - 0.08, 0.06, k.w - 0.05, 0.012, tape)


static func _hood_ties(k: K, col: Color, x: float, L: float) -> void:
	k.pair(x, k.n - 0.05, x + 0.008, k.n - 0.05 - L, 0.006, col)
	k.btn(x + 0.008, k.n - 0.05 - L, 0.016, col)
	k.btn(-x - 0.008, k.n - 0.05 - L, 0.016, col)


static func _vest_detail(k: K, col: Color, dk: Color, zipc: Color) -> void:
	k.vest()
	k.zip(k.n - 0.09, k.w - 0.02, zipc, STEEL)
	for s in [-1.0, 1.0]:
		k.pocket(s * 0.075, k.c - 0.05, 0.06, 0.08, col, dk, STEEL)
	k.line(-0.12, k.c + 0.06, 0.12, k.c + 0.06, 0.008, dk, false, 8)
	k.line(0.0, k.c + 0.05, 0.0, k.w, 0.008, dk, false, 8)


# ------------------------------------------------------------------ setler
static func _recipe(k: K, sid: String) -> void:
	match sid:
		"ss_orman_zirh_genc":
			var ar = C("6d7b6d")
			_cuirass(k, ar, ar.darkened(0.3), C("2a2f2a"), 5, 0.11)
		"ss_pembe_ceket":
			k.top()
			k.ring(k.w + 0.04, 0.026, C("c6b4e6"), 0.006, 0.004)
			k.line(-0.03, k.n - 0.07, 0.02, k.w + 0.06, 0.006, C("c8a8d0"), true, 8)
			_hood_ties(k, C("f4f0f6"), 0.035, 0.11)
			k.body()
			k.ring(k.w - 0.03, 0.022, C("a89668"), 0.006)
			k.pocket(0.11, k.h - 0.06, 0.07, 0.06, C("bcae76"), C("6a4428"), STEEL)
			k.pocket(-0.11, k.h - 0.06, 0.07, 0.06, C("bcae76"), C("6a4428"), STEEL)
		"ss_pembe_genc":
			var wh = C("f2eeea")
			k.top()
			k.line(0.03, k.n - 0.03, 0.03, k.w - 0.02, 0.009, wh, true, 9)
			k.collar(k.n - 0.02, 0.022, wh)
			k.btn(0.03, k.n - 0.06, 0.016, GOLD)
		"ss_pembe_kazak":
			var p = C("e9b4c8")
			k.top()
			k.ring(k.w + 0.03, 0.03, WHITE, 0.007, 0.004)
			k.ring(k.c - 0.02, 0.018, WHITE, 0.005, 0.003)
			k.collar(k.n - 0.03, 0.022, p.darkened(0.12))
		"ss_pembe_kunoichi":
			k.top()
			k.zip(k.n - 0.05, k.w - 0.02, C("efe9e4"), STEEL)
			k.collar(k.n - 0.025, 0.02, C("8c1a22"))
			k.pair(0.11, k.n - 0.09, 0.12, k.w, 0.006, C("8c1a22"))
			k.body()
			k.pocket(0.15, k.h - 0.03, 0.07, 0.08, LEATHER, LEATHER.darkened(0.3), GOLD)
			k.ring(k.w - 0.02, 0.02, C("d8a0b4"), 0.005, 0.004)
		"ss_pembe_kunoichi2":
			var wh = C("efe7e0")
			k.top()
			k.line(0.05, k.n - 0.03, -0.07, k.w + 0.05, 0.01, wh, true, 9)
			k.collar(k.n - 0.02, 0.02, wh)
			k.btns(-0.03, k.n - 0.07, k.c - 0.03, 3, 0.012, wh)
			k.ring(k.w + 0.03, 0.05, INK, 0.008, 0.006)
			k.low()
			k.ring(k.w - 0.01, 0.06, INK, 0.01, 0.006)
		"ss_pijama":
			var d = C("a9a9bc")
			k.top()
			k.line(0.02, k.n - 0.05, 0.02, k.w - 0.05, 0.012, d, true, 9)
			k.btns(0.02, k.n - 0.08, k.w - 0.02, 4, 0.016, WHITE)
			k.spiral(0.0, k.c - 0.02, 0.05, C("d65a4a"))
			k.cuff(0.9, 0.02, d)
			k.body()
			k.ring(k.w - 0.03, 0.028, d, 0.006, 0.004)
		"ss_ruzgar_elbise":
			var lv = C("b6a8dc")
			k.top()
			k.ring(k.c - 0.03, 0.05, lv, 0.008, 0.004)
			k.ring(k.w + 0.02, 0.05, C("4c2c5c"), 0.009, 0.006)
			k.plate(0.0, k.w + 0.02, 0.14, 0.022, C("d07c34"), 0.006, true, 0.012)
			k.plate(0.0, k.w + 0.02, 0.05, 0.03, C("4e8a4e"), 0.006, true, 0.016)
			k.pocket(-0.13, k.w - 0.08, 0.06, 0.07, LEATHER, LEATHER.darkened(0.3), STEEL)
		"ss_ruzgar_elbise2", "ss_ruzgar_zirh":
			var pl = C("c9c6cf")
			k.top()
			k.line(-0.11, k.n - 0.09, 0.11, k.n - 0.09, 0.012, pl.darkened(0.3), true, 8)
			k.pair(0.11, k.n - 0.08, 0.1, k.w + 0.07, 0.008, pl.darkened(0.3))
			k.ring(k.w + 0.015, 0.058, C("a8303a"), 0.009, 0.008)
			k.plate(0.05, k.w + 0.015, 0.06, 0.05, C("86232d"), 0.01, true, 0.014)
			if sid != "ss_ruzgar_zirh":
				k.dangle("Hips", Vector3(0.11, k.h - 0.04, 0.09), Vector3(0.02, -1, 0.02), 0.34, 0.05, C("8c2a34"))
		"ss_ruzgar_genc":
			var r = C("a8303a")
			k.top()
			k.collar(k.n - 0.02, 0.03, C("c9b4bc"))
			k.line(0.07, k.n - 0.05, -0.05, k.w + 0.06, 0.01, C("c9b4bc"), true, 8)
			k.ring(k.w + 0.015, 0.05, r, 0.008, 0.006)
			k.plate(-0.05, k.w + 0.015, 0.07, 0.05, r.darkened(0.15), 0.01, true, 0.012)
			k.dangle("Hips", Vector3(-0.08, k.w - 0.02, 0.11), Vector3(-0.1, -1, 0.05), 0.2, 0.04, r)
		"ss_ruzgar_kimono":
			var ob = C("1b2a78")
			_robe(k, C("dfe6f6"))
			k.top()
			k.ring(k.w + 0.015, 0.075, ob, 0.009, 0.004)
			k.ring(k.w + 0.02, 0.008, C("cfd8f4"), 0.004, 0.012)
			k.line(-0.09, k.w + 0.015, 0.09, k.w + 0.015, 0.005, C("f0b4cc"), true, 6, 0.006)
			k.dangle("Hips", Vector3(0.08, k.w, 0.12), Vector3(0.05, -1, 0.05), 0.2, 0.012, C("f0b4cc"))
		"ss_sahil":
			_puffer(k, C("f08a2a"), C("c86a18"), 4)
			_shorts(k, C("16301f"), WHITE)
		"ss_sahil_denizci":
			_puffer(k, C("f2f2f2"), C("c62626"), 4)
			_shorts(k, C("5fa6d4"), WHITE)
			k.pocket(0.12, k.h - 0.1, 0.07, 0.06, C("d82828"), C("1e3a78"), WHITE)
		"ss_sahil_flamingo":
			k.top()
			k.line(-0.13, k.n - 0.1, 0.13, k.n - 0.1, 0.018, C("f06a8a"), true, 8)
			k.line(-0.13, k.n - 0.1, 0.13, k.n - 0.1, 0.018, C("f06a8a"), false, 8)
			k.ring(k.w + 0.02, 0.016, C("f06a8a"), 0.005, 0.004)
			k.btns(0.0, k.c - 0.04, k.w + 0.05, 3, 0.012, C("f6c4d2"))
		"ss_sahil_gok":
			_puffer(k, C("f8d028"), C("e4b414"), 3)
			_shorts(k, C("1e4a9a"), C("f8d028"))
			k.pocket(-0.12, k.h - 0.1, 0.07, 0.06, C("e4544e"), C("3c9a4c"))
		"ss_sahil_hibiskus":
			_puffer(k, C("4ac0e8"), C("2a8cb8"), 4)
			_shorts(k, C("2a4ab8"), WHITE)
		"ss_sakaci":
			var oj = C("c85a22")
			k.top()
			k.collar(k.n - 0.03, 0.016, C("343a56"))
			k.low()
			k.ring(k.w - 0.02, 0.05, oj, 0.01, 0.006)
			k.plate(0.0, k.w - 0.03, 0.09, 0.055, oj.darkened(0.14), 0.016, true, 0.012)
		"ss_samuray_kuro":
			_cuirass(k, C("24242c"), C("a8242a"), C("8d1f26"), 5, 0.115)
			k.top()
			k.rivets(k.c + 0.04, -0.09, 0.09, 5, C("c8ccd4"))
		"ss_sari_simsek":
			k.vest()
			k.zip(k.n - 0.09, k.w, C("3a4a38"), STEEL)
			k.pocket(0.075, k.c - 0.06, 0.06, 0.08, C("56704f"), C("3a4a38"), STEEL)
			k.pocket(-0.075, k.c - 0.06, 0.06, 0.08, C("56704f"), C("3a4a38"), STEEL)
		"ss_sari_simsek_genc":
			var tr = C("2a3466")
			k.top()
			for y in [k.c + 0.02, k.c - 0.06, k.c - 0.14]:
				k.pair(0.13, y, 0.07, y - 0.01, 0.006, C("c4c4cf"))
			k.pair(0.06, k.n - 0.05, 0.065, k.w - 0.06, 0.016, tr)
			k.ring(k.w - 0.05, 0.022, tr, 0.006, 0.004)
			k.pocket(0.11, k.w - 0.02, 0.07, 0.07, C("dcdce4"), tr)
			k.pocket(-0.11, k.w - 0.02, 0.07, 0.07, C("dcdce4"), tr)
		"ss_savas_reisi":
			var ar = C("8e1c22")
			_cuirass(k, ar, ar.darkened(0.42), INK, 5, 0.11)
			k.top()
			k.line(0.02, k.c - 0.02, -0.03, k.c - 0.1, 0.006, INK, true, 4)
		"ss_savas_reisi2":
			k.top()
			k.collar(k.n - 0.01, 0.05, C("7a1e24"), 0.2)
			k.btns(0.0, k.c, k.w, 5, 0.02, INK)
		"ss_savas_reisi3":
			var l = C("6a4426")
			k.top()
			k.plate(0.0, k.c - 0.06, 0.04, 0.04, l.darkened(0.3), 0.006, true, 0.014)
			k.ring(k.w + 0.0, 0.03, INK, 0.007, 0.004)
		"ss_savas_reisi_genc":
			var ob = C("8a7da8")
			k.top()
			k.ring(k.w + 0.02, 0.08, ob, 0.01, 0.004)
			for dy in [-0.022, 0.022]:
				k.ring(k.w + 0.02 + dy, 0.006, ob.darkened(0.3), 0.004, 0.014)
			k.collar(k.n - 0.01, 0.05, C("2f2348"), 0.2)
		"ss_seytan":
			var g1 = C("8a8a90")
			k.top()
			k.zip(k.n - 0.05, k.w - 0.02, C("6d141f"), STEEL)
			k.plate(0.0, k.n - 0.07, 0.03, 0.03, GOLD, 0.006, true, 0.007)
			for y in [k.c + 0.02, k.c - 0.05, k.c - 0.12]:
				k.rivets(y, 0.04, 0.12, 3, STEEL)
				k.rivets(y, -0.12, -0.04, 3, STEEL)
			k.body()
			k.ring(k.w - 0.02, 0.03, g1, 0.007, 0.012)
			k.plate(0.0, k.w - 0.02, 0.05, 0.035, STEEL, 0.008, true, 0.018)
			k.line(0.03, k.w - 0.05, 0.14, k.h - 0.1, 0.008, STEEL, true, 7, 0.006)
		"ss_sigara_jonin":
			_vest_detail(k, C("3f483f"), C("2c332c"), C("242a24"))
			k.body()
			k.cuff(0.18, 0.05, WHITE)
			k.cuff(0.84, 0.03, C("3a5a9a"))
			k.ring(k.w - 0.02, 0.03, INK, 0.006, 0.004)
		"ss_silah_ustasi":
			var r = C("b82020")
			k.top()
			k.line(0.0, k.n - 0.03, 0.1, k.c - 0.03, 0.012, r, true, 8)
			k.collar(k.n - 0.02, 0.03, WHITE.darkened(0.04))
			for y in [k.c + 0.03, k.c - 0.03, k.c - 0.09]:
				k.plate(0.03, y, 0.04, 0.009, r, 0.005, true, 0.003)
				k.btn(0.055, y, 0.011, r)
			k.ring(k.w + 0.0, 0.03, r, 0.007, 0.004)
			k.cuff(0.82, 0.03, r)
			k.cuff(0.93, 0.016, C("3a68c8"))
		"ss_simsek_kiyafet":
			var y1 = C("e8e830")
			k.top()
			k.line(0.1, k.n - 0.08, -0.03, k.c - 0.03, 0.022, y1, true, 6)
			k.line(-0.03, k.c - 0.03, 0.05, k.c - 0.05, 0.022, y1, true, 3)
			k.line(0.05, k.c - 0.05, -0.08, k.w + 0.02, 0.022, y1, true, 6)
			k.line(-0.1, k.n - 0.08, 0.03, k.c - 0.03, 0.012, INK, true, 6)
			k.line(0.0, k.n - 0.05, 0.08, k.c - 0.1, 0.02, y1, false, 6)
			k.ring(k.w + 0.0, 0.04, C("5a8a3a"), 0.008, 0.005)
			k.cuff(0.28, 0.04, y1)
		"ss_sis_striker":
			k.top()
			for x in [-0.09, -0.03, 0.03, 0.09]:
				k.line(x, k.n - 0.1, x, k.w - 0.06, 0.005, C("7f70b0"), true, 8)
			k.ring(k.w - 0.01, 0.026, C("6b8a3a"), 0.006, 0.006)
			k.pocket(0.1, k.w - 0.06, 0.08, 0.07, C("3a2f5a"), C("2a2244"), STEEL)
		"ss_sis_striker_beyaz", "ss_sis_striker_siyah":
			var ye = C("e4c23a")
			var dk = C("141416") if sid == "ss_sis_striker_beyaz" else C("ececea")
			k.top()
			k.pair(0.045, k.n - 0.08, 0.045, k.w - 0.06, 0.006, ye)
			k.ring(k.w - 0.01, 0.026, ye, 0.006, 0.006)
			for i in 4:
				k.plate(0.07 + (i % 2) * 0.03, k.w - 0.06 - i * 0.012, 0.024, 0.024, dk if i % 2 == 0 else ye, 0.006, true, 0.008)
		"ss_siyah_ceket":
			_track(k, C("f08a24"), C("34343c"), C("f4f0e6"))
			k.pocket(0.09, k.w + 0.02, 0.08, 0.075, C("24242c"), C("34343c"))
			k.pocket(-0.09, k.w + 0.02, 0.08, 0.075, C("24242c"), C("34343c"))
			k.arm(1.0)
			k.cuff(0.3, 0.05, C("b01c22"), 1.0, 0.007, 0.004)
			k.arm(-1.0)
			k.cuff(0.72, 0.05, C("3a3a42"), -1.0, 0.01, 0.004)
		"ss_siyah_tulum":
			k.top()
			k.plate(0.0, k.c - 0.05, 0.035, 0.035, STEEL, 0.007, true, 0.01)
			k.body()
			k.cuff(0.86, 0.03, C("3a3a44"))
		"ss_sokak":
			var d = C("2d2445")
			k.top()
			k.pair(0.055, k.n - 0.05, 0.065, k.w - 0.08, 0.008, d)
			k.btns(0.07, k.c, k.w - 0.04, 4, 0.012, STEEL)
			k.pocket(-0.1, k.c - 0.03, 0.07, 0.075, C("4a3b6e"), d)
			k.body()
			k.line(-0.06, k.n - 0.02, 0.0, k.c + 0.02, 0.004, STEEL, true, 4, 0.004)
			k.line(0.06, k.n - 0.02, 0.0, k.c + 0.02, 0.004, STEEL, true, 4, 0.004)
			k.ring(k.w - 0.03, 0.02, INK, 0.005, 0.006)
		"ss_son_savas":
			k.top()
			k.pair(0.1, k.n - 0.1, 0.11, k.w, 0.006, C("161f38"))
			k.collar(k.n - 0.02, 0.03, C("161f38"))
			k.ring(k.w - 0.02, 0.02, C("161f38"), 0.005, 0.004)
			k.dangle("LeftUpperArm", Vector3(k.ua + 0.1, k.n - 0.06, 0.03), Vector3(0.2, -1, 0.05), 0.08, 0.03, C("1e2a48"))
		"ss_soylu_pelerin":
			k.body()
			k.pair(0.06, k.n - 0.04, 0.0, k.w + 0.05, 0.016, C("dcdcd4"))
			k.ring(k.w + 0.02, 0.07, C("24306a"), 0.009, 0.012)
			k.top()
			k.pair(0.1, k.n - 0.06, 0.13, k.w - 0.1, 0.012, C("0f1b13"))
			k.cuff(0.9, 0.03, C("0f1b13"))
		"ss_su_elbise":
			k.top()
			k.pair(0.1, k.c + 0.03, 0.0, k.c - 0.1, 0.014, WHITE)
			k.ring(k.w + 0.02, 0.022, C("e6dcae"), 0.007, 0.006)
			k.plate(0.0, k.w + 0.02, 0.05, 0.03, WHITE, 0.008, true, 0.01)
		"ss_su_zirh":
			var ar = C("2a4ab8")
			_cuirass(k, ar, ar.darkened(0.35), C("9ab0f0"), 4, 0.1)
			k.body()
			k.cuff(0.5, 0.05, C("b8a8d8"))
		"ss_suna_genin":
			var v = C("5e5648")
			k.vest()
			for y in [k.c + 0.02, k.c - 0.06, k.c - 0.14]:
				k.ring(y, 0.009, v.darkened(0.25), 0.005, 0.003, -1.3, 1.3, 14)
			k.zip(k.n - 0.09, k.w, v.darkened(0.3), STEEL)
			k.rivets(k.w + 0.06, -0.1, 0.1, 4, STEEL)
			k.body()
			k.ring(k.w - 0.03, 0.022, C("1c1814"), 0.005, 0.004)
		"ss_tas_yasli":
			var gn = C("6f8f3e")
			var og = C("d0802a")
			k.top()
			k.pair(0.1, k.n - 0.08, 0.13, k.w - 0.06, 0.014, og)
			k.collar(k.n - 0.01, 0.05, C("8e2020"), 0.2)
			k.line(-0.12, k.w - 0.02, 0.12, k.w - 0.02, 0.016, og, false, 8)
			k.rivets(k.c, -0.05, 0.05, 2, GOLD)
			k.line(0.0, k.n - 0.1, 0.0, k.w, 0.008, gn.darkened(0.3), false, 8)
		"ss_tatli", "ss_tatli_baklava", "ss_tatli_kultur":
			var a1 = {"ss_tatli": C("d8c8ec"), "ss_tatli_baklava": C("f2e6d0"), "ss_tatli_kultur": C("c8d2f0")}[sid]
			k.top()
			k.ring(k.c + 0.075, 0.018, a1, 0.006, 0.004)
			k.ring(k.w + 0.08, 0.02, a1, 0.006, 0.004)
			k.cuff(0.74, 0.02, a1)
			if sid == "ss_tatli_baklava":
				for i in 5:
					k.plate(-0.1 + i * 0.05, k.c - 0.03, 0.032, 0.032, C("f2e6d0"), 0.004, true, 0.003)
			elif sid == "ss_tatli_kultur":
				k.line(-0.13, k.c - 0.02, 0.13, k.c - 0.02, 0.012, C("e8d890"), true, 8)
				k.line(-0.13, k.c - 0.05, 0.13, k.c - 0.05, 0.006, C("e8d890"), true, 8)
			else:
				k.pair(0.06, k.c + 0.05, 0.08, k.w + 0.1, 0.005, C("e0d8cc"))
			k.body()
			k.ring(k.w - 0.04, 0.024, a1.darkened(0.4), 0.005, 0.003)
		"ss_tavsan_tanri":
			k.top()
			k.btns(0.0, k.c - 0.02, k.w - 0.04, 4, 0.024, INK)
			k.low()
			k.btns(0.0, k.h - 0.06, k.kn + 0.06, 3, 0.024, INK)
		"ss_tavsan_tanri2":
			k.top()
			k.pair(0.05, k.n - 0.04, 0.06, k.w - 0.05, 0.006, INK)
			k.body()
			k.plate(0.0, k.c - 0.04, 0.05, 0.12, C("d8c060"), 0.005, true, 0.004)
		"ss_tehlike_ceket":
			var d = C("b89c74")
			k.top()
			k.pair(0.07, k.n - 0.05, 0.08, k.w - 0.1, 0.01, d)
			k.cuff(0.88, 0.05, C("e4d2b2"))
			if k.low():
				k.pocket(0.11, k.h - 0.1, 0.09, 0.1, C("cfb68e"), d)
				k.pocket(-0.11, k.h - 0.1, 0.09, 0.1, C("cfb68e"), d)
			k.body()
			k.ring(k.w - 0.01, 0.02, INK, 0.005, 0.003)
			k.line(-0.05, k.n - 0.01, 0.05, k.n - 0.01, 0.01, RED, true, 4, 0.004)
		"ss_turuncu_ceket":
			_track(k, C("23232a"), C("c86e16"), STEEL)
			k.collar(k.n - 0.01, 0.04, INK)
			k.ring(k.w - 0.05, 0.03, INK, 0.006, 0.004)
			k.cuff(0.9, 0.03, INK)
			k.body()
			k.cuff(0.2, 0.05, WHITE, -1.0)
		"ss_turuncu_esofman":
			_track(k, C("f4f0e6"), C("c86e16"), C("c63a2a"))
			k.collar(k.n - 0.01, 0.042, C("1e1e2a"))
			k.pocket(0.09, k.w + 0.02, 0.075, 0.06, C("f08a24"), C("c86e16"))
			k.pocket(-0.09, k.w + 0.02, 0.075, 0.06, C("f08a24"), C("c86e16"))
			k.ring(k.w - 0.05, 0.022, C("1e1e2a"), 0.006, 0.004)
		"ss_turuncu_genc":
			var bl = C("2a4aa0")
			_track(k, C("f4f0e6"), C("c86e16"), C("c63a2a"))
			k.collar(k.n - 0.01, 0.05, WHITE)
			k.ring(k.w - 0.04, 0.05, bl, 0.008, 0.004)
			k.cuff(0.92, 0.02, C("e87a28"), 0.0, 0.009)
		"ss_turuncu_maske":
			var d = C("1a1a2e")
			k.top()
			k.pair(0.08, k.c + 0.05, 0.1, k.w + 0.08, 0.008, d)
			k.btns(0.0, k.c, k.w + 0.08, 3, 0.016, STEEL)
			k.plate(0.0, k.w + 0.01, 0.05, 0.05, C("2a1a34"), 0.01, true, 0.012)
			k.ring(k.w + 0.01, 0.008, C("6a4a7a"), 0.004, 0.012)
		"ss_yaprak_striker", "ss_yaprak_striker_kovboy", "ss_yaprak_striker_matador":
			_striker(k, sid)
		"ss_yaz":
			k.top()
			k.zip(k.n - 0.04, k.w - 0.03, C("c86e16"), STEEL)
			k.collar(k.n - 0.01, 0.04, C("e8842a"))
			k.ring(k.w - 0.04, 0.024, C("c86e16"), 0.006, 0.004)
			k.spiral(0.0, k.c - 0.03, 0.05, C("c63a2a"))
			k.body()
			k.cuff(0.92, 0.024, WHITE)
		"ss_yedi_kanat":
			k.body()
			k.ring(k.c + 0.03, 0.09, WHITE, 0.006, 0.004)
			k.ring(k.c + 0.0, 0.008, INK, 0.004, 0.009)
			k.ring(k.w - 0.04, 0.024, C("d8d8dc"), 0.006, 0.004)
			k.cuff(0.2, 0.04, C("2a4ab8"), -1.0)
			k.plate(-k.ua - 0.1, k.n - 0.07, 0.03, 0.02, STEEL, 0.005, true, 0.012)
		"ss_yelpaze", "ss_yelpaze_kolsuz":
			var b0 = C("2c3380")
			k.top()
			k.zip(k.n - 0.02, k.c - 0.05, C("7a7a9a"), STEEL)
			k.low()
			k.pair(0.07, k.w - 0.06, 0.1, k.kn + 0.02, 0.008, b0)
			k.line(0.0, k.w - 0.06, 0.0, k.kn + 0.02, 0.009, b0)
			k.body()
			k.cuff(0.82, 0.05, INK)
			k.dangle("Hips", Vector3(0.14, k.w - 0.05, 0.08), Vector3(0.05, -1, 0.05), 0.22, 0.03, C("7a62c0"), 0.25)
		"ss_yelpaze_b":
			k.top()
			k.pair(0.015, k.n - 0.02, 0.05, k.c - 0.02, 0.012, C("6f6f90"))
			k.ring(k.w - 0.02, 0.016, C("6f6f90"), 0.005, 0.003)
			k.body()
			k.ring(k.w - 0.05, 0.03, C("172038"), 0.005, 0.004)
			k.cuff(0.9, 0.03, INK)
		"ss_yelpaze_cocuk":
			k.vest()
			k.pair(0.05, k.n - 0.06, 0.05, k.w, 0.007, C("6a6a70"))
			k.plate(0.0, k.c - 0.05, 0.05, 0.05, C("d4d4d0"), 0.012, true, 0.014)
			k.dangle("UpperChest", Vector3(0.03, k.c - 0.08, 0.15), Vector3(0.1, -1, 0.05), 0.14, 0.024, WHITE)
			k.body()
			k.pocket(0.0, k.w - 0.03, 0.09, 0.07, LEATHER, LEATHER.darkened(0.3), STEEL, false)
		"ss_yelpaze_genc":
			k.top()
			k.collar(k.n - 0.005, 0.05, C("182258"))
			k.zip(k.n - 0.05, k.c - 0.08, C("3a4896"), STEEL)
			k.body()
			k.cuff(0.86, 0.04, C("2a3a8a"))
			k.ring(k.w - 0.04, 0.024, C("cfcbbf"), 0.006, 0.004)
			k.pocket(0.12, k.h - 0.1, 0.075, 0.07, C("d6d2c6"), C("bcb8ac"))
		"ss_yelpaze_genc2":
			k.top()
			k.collar(k.n - 0.005, 0.045, C("2c2c32"))
			k.pair(0.11, k.n - 0.09, 0.12, k.w, 0.007, C("6a6a70"))
			k.ring(k.w - 0.02, 0.012, C("6a6a70"), 0.004, 0.003)
			k.body()
			k.cuff(0.5, 0.06, C("8a8a90"))
		"ss_yelpaze_kilic":
			k.top()
			k.collar(k.n - 0.005, 0.04, C("2c2c32"))
			k.plate(0.02, k.c - 0.03, 0.03, 0.04, STEEL, 0.006, true, 0.016)
			k.body()
			k.ring(k.w - 0.04, 0.02, C("161f38"), 0.005, 0.004)
		"ss_yelpaze_takim":
			var bl = C("8ca8cc")
			k.top()
			k.line(0.015, k.n - 0.05, 0.015, k.w - 0.12, 0.012, bl, true, 9)
			k.btns(0.04, k.c, k.w - 0.08, 4, 0.014, bl.darkened(0.3))
			k.ring(k.w - 0.1, 0.014, bl, 0.004, 0.004)
		"ss_yelpaze_yirtik":
			k.top()
			k.pair(0.015, k.n - 0.02, 0.05, k.c - 0.02, 0.012, C("6f6f90"))
			k.line(0.05, k.c - 0.05, 0.12, k.c - 0.1, 0.008, C("5a5a78"), true, 4)
			k.line(-0.09, k.w + 0.08, -0.04, k.w + 0.02, 0.008, C("5a5a78"), true, 4)
			k.dangle("Hips", Vector3(0.1, k.w - 0.03, 0.11), Vector3(0.1, -1, 0.05), 0.09, 0.05, C("9a9ab8"), 0.15)
			k.dangle("Hips", Vector3(-0.08, k.w - 0.03, -0.12), Vector3(-0.1, -1, -0.05), 0.1, 0.05, C("9a9ab8"), 0.15)
			k.body()
			k.cuff(0.9, 0.03, INK)
		"ss_yelpaze_zirh":
			var ar = C("8a2228")
			_cuirass(k, ar, INK, C("c8b8e8"), 6, 0.1)
			k.top()
			for i in 5:
				k.line(-0.09 + i * 0.045, k.c + 0.03, -0.09 + i * 0.045 + 0.03, k.w + 0.05, 0.004, INK, true, 6)
		"ss_yemek":
			var g2 = C("1b5126")
			k.top()
			k.pair(0.07, k.n - 0.05, 0.085, k.w - 0.08, 0.016, g2)
			k.cuff(0.62, 0.03, g2)
			k.pocket(0.11, k.w - 0.02, 0.08, 0.07, C("2d7a3a"), g2)
			k.pocket(-0.11, k.w - 0.02, 0.08, 0.07, C("2d7a3a"), g2)
			k.body()
			k.ring(k.w - 0.02, 0.03, C("9a2024"), 0.007, 0.006)
			k.plate(0.0, k.w - 0.02, 0.06, 0.03, STEEL, 0.008, true, 0.01)
		"ss_yeni_nesil":
			k.vest()
			for y in [k.c + 0.01, k.c - 0.07, k.c - 0.15]:
				k.ring(y, 0.008, C("4a7e4a"), 0.004, 0.003, -1.25, 1.25, 14)
			k.zip(k.n - 0.09, k.w, C("3e6a3e"), STEEL)
			k.rivets(k.n - 0.09, -0.12, 0.12, 4, STEEL)
			k.ring(k.w + 0.0, 0.026, C("1c2440"), 0.006, 0.006)
			k.body()
			k.cuff(0.3, 0.04, C("b02428"), 1.0)
		"ss_yeni_nesil2":
			var nv = C("262a58")
			k.top()
			k.zip(k.n - 0.05, k.w - 0.06, nv, STEEL)
			k.ring(k.w - 0.06, 0.03, nv, 0.006, 0.004)
			k.cuff(0.9, 0.03, nv)
			k.pocket(0.09, k.w - 0.0, 0.08, 0.07, C("989f90"), nv)
			k.pocket(-0.09, k.w - 0.0, 0.08, 0.07, C("989f90"), nv)
		"ss_yesil_canavar":
			_vest_detail(k, C("7aa070"), C("567a50"), C("3c5a38"))
			k.spiral(0.0, k.c + 0.02, 0.045, C("b8352e"))
			k.body()
			k.ring(k.w - 0.02, 0.04, C("b82428"), 0.008, 0.012)
			k.plate(0.0, k.w - 0.02, 0.07, 0.036, STEEL, 0.008, true, 0.018)
		"ss_yesil_canavar2":
			_vest_detail(k, C("3e7a4a"), C("2c5a36"), C("24482c"))
			k.body()
			k.cuff(0.9, 0.024, C("b02428"))
		"ss_yilan_cubbe":
			k.top()
			k.line(0.0, k.n - 0.05, 0.0, k.w, 0.012, WHITE, true, 9)
			k.low()
			k.line(0.0, k.w, 0.0, k.a + 0.08, 0.012, WHITE, true, 10)
			k.top()
			k.cuff(0.86, 0.04, C("8a9a8a"))
		"ss_yilan_kimono":
			var br = C("6a4a2c")
			k.top()
			k.ring(k.w + 0.015, 0.08, br, 0.011, 0.005)
			k.ring(k.w + 0.05, 0.006, br.darkened(0.35), 0.004, 0.016)
			k.ring(k.w - 0.02, 0.006, br.darkened(0.35), 0.004, 0.016)
			k.plate(0.0, k.w + 0.015, 0.1, 0.06, C("8a6a4a"), 0.008, true, 0.016)
			k.plate(0.0, k.w + 0.015, 0.03, 0.03, C("dce6f0"), 0.006, true, 0.024)
			k.pocket(0.0, k.w + 0.015, 0.11, 0.07, LEATHER, br.darkened(0.3), GOLD, false)
		"ss_yilan_sanin":
			k.top()
			k.pair(0.11, k.n - 0.09, 0.12, k.w + 0.04, 0.006, C("c8bc96"))
			k.collar(k.n - 0.02, 0.03, INK)
		"ss_yilan_zirh":
			var p = C("b8b8bc")
			k.top()
			k.rivets(k.c + 0.06, -0.1, 0.1, 4, p.darkened(0.3))
			k.line(0.0, k.n - 0.08, 0.0, k.w - 0.08, 0.008, p.darkened(0.3), true, 9, 0.006)
			k.line(-0.1, k.n - 0.1, 0.1, k.n - 0.1, 0.018, p, false, 7, 0.009)
			k.line(-0.1, k.c - 0.06, 0.1, k.c - 0.06, 0.018, p, false, 7, 0.009)
			k.line(-0.1, k.w + 0.02, 0.1, k.w + 0.02, 0.018, p, false, 7, 0.009)
		"ss_yirminci":
			var bk = C("141418")
			k.top()
			k.ring(k.w + 0.015, 0.05, bk, 0.009, 0.006)
			k.plate(0.0, k.w + 0.015, 0.05, 0.035, GOLD, 0.008, true, 0.012)
			k.pair(0.07, k.n - 0.05, 0.0, k.w + 0.05, 0.02, C("c03a14"))
			k.rivets(k.c - 0.02, -0.1, 0.1, 5, GOLD)
			k.dangle("Hips", Vector3(-0.1, k.w - 0.02, 0.12), Vector3(-0.1, -1, 0.05), 0.3, 0.1, WHITE)
		"ss_yirtik_esofman":
			var o2 = C("c86e16")
			k.top()
			k.pair(0.08, k.n - 0.05, 0.1, k.w - 0.05, 0.012, C("2c2c3c"))
			k.line(0.12, k.c, 0.15, k.c - 0.06, 0.008, o2, true, 3)
			k.line(-0.13, k.w, -0.09, k.w - 0.05, 0.008, C("2c2c3c"), true, 3)
			k.body()
			k.cuff(0.86, 0.03, C("2c2c3c"))
			k.ring(k.w - 0.04, 0.02, o2, 0.005, 0.003)


static func _striker(k: K, sid: String) -> void:
	var trim = {"ss_yaprak_striker": C("3c6e4c"), "ss_yaprak_striker_kovboy": C("1e3f86"), "ss_yaprak_striker_matador": GOLD}[sid]
	k.top()
	k.pair(0.075, k.n - 0.05, 0.085, k.w - 0.02, 0.01, trim)
	k.cuff(0.84, 0.024, trim)
	k.body()
	k.ring(k.w - 0.02, 0.03, WHITE if sid == "ss_yaprak_striker" else (LEATHER if sid == "ss_yaprak_striker_kovboy" else GOLD), 0.007, 0.01)
	k.plate(0.0, k.w - 0.02, 0.05, 0.034, STEEL, 0.008, true, 0.016)
	if sid == "ss_yaprak_striker_matador":
		k.rivets(k.c, 0.06, 0.12, 3, GOLD)
		k.rivets(k.c, -0.12, -0.06, 3, GOLD)
