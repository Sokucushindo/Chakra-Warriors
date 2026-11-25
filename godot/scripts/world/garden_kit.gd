extends RefCounted
## (class_name yok: kullanan dosyalar const GardenKit = preload(...) ile yükler — sınıf önbelleği yenilemeden çalışsın)
## Özel binaların ARKA BAHÇELERİ (2026-11-25, kullanıcı: "özel binaların arkası boş görünüyor, binaya uygun bahçe yap"):
## FacadeKit'in giydirdiği arka cephenin (pencere / kapı / boru / eşya — onlar kalır) önündeki boş alana binanın karakterine
## uygun bahçe: Akademi antrenman köşesi + öğrenci bahçesi, hastane iyileşme bahçesi, Hokage kulesi Japon bahçesi (gölet,
## kemerli köprü, taş fener, çam, tırmıklı çakıl), Hyūga / Naka kuru bahçe (karesansui) + bambu çit, ANBU gizli antrenman
## avlusu, polis / kütüphane okuma avlusu, diğer köylerde iklime göre (Suna kum avlu + sukulent, Kiri yosunlu gölet,
## Kumo kaya bahçesi, Iwa taş bahçe).
## Yerleşim: arka duvarın önünde 2 m ızgarayla boş alan taranır (Builder.solids: ev / duvar / ağaç / eşya, yollar, toprak
## sokaklar, su, eğim) — bahçe sığan alana göre boyutlanır, her öğe yeniden denetlenir, arazi yüksekliğini izler.
## Patika: arka kapıdan başlar, YALNIZ bahçenin içinde kıvrılır; sokak ancak birkaç metre ötedeyse bağlanır. Malzeme köyün
## zemininden: Konoha toprak ara sokak (RoadMap.add_lane dirt), Kumo taş döşeme, Suna kumtaşı plaka, Kiri ıslak taş, Iwa kaya
## plaka. Hepsi Builder kutularıyla birleşik ağa girer; bitkiler hücre başına MultiMesh; yalnız çarpılan eşya katıdır.
##
## Koordinat: x, n = arka duvar yüzünün ORTASI (Builder yereli), face = yüzün dışa bakan normali (derece), u = duvar boyunca
## (FacadeKit ile aynı), d = duvardan dışarı.

const RM = preload("res://scripts/world/road_map.gd")
const PATH_HALF := 1.1

## Testler (dbg_building_backs) için: kurulan bahçeler [{vid, ad, wall (dünya), face, center (dünya), size (u, d)}]
static var made: Array = []
static var _mesh := {}


## karşılaştırma görüntüsü için geçici kapatma (NO_GARDEN=1: bahçesiz eski hal; alan yine hesaplanır, kamera aynı yere bakar)
static func on() -> bool:
	return OS.get_environment("NO_GARDEN") == ""


## iklim -> malzeme paleti
const PAL := {
	"green": {"gravel": Color(0.84, 0.82, 0.76), "rock": Color(0.56, 0.56, 0.53), "moss": Color(0.3, 0.5, 0.25), "wood": Color(0.46, 0.32, 0.2),
		"soil": Color(0.4, 0.29, 0.2), "trees": true, "water": true, "lt": Color(0, 0, 0, 0), "mossy": true, "path": "dirt"},
	"desert": {"gravel": Color(0.9, 0.78, 0.57), "rock": Color(0.76, 0.6, 0.42), "moss": Color(0.5, 0.58, 0.36), "wood": Color(0.56, 0.42, 0.28),
		"soil": Color(0.66, 0.5, 0.33), "trees": false, "water": false, "lt": Color(0.8, 0.68, 0.5), "mossy": false, "path": "sand"},
	"mist": {"gravel": Color(0.62, 0.66, 0.68), "rock": Color(0.42, 0.46, 0.48), "moss": Color(0.22, 0.4, 0.25), "wood": Color(0.34, 0.28, 0.24),
		"soil": Color(0.3, 0.26, 0.22), "trees": true, "water": true, "lt": Color(0.46, 0.5, 0.47), "mossy": true, "path": "wet"},
	"cloud": {"gravel": Color(0.8, 0.8, 0.78), "rock": Color(0.6, 0.6, 0.6), "moss": Color(0.3, 0.46, 0.3), "wood": Color(0.42, 0.32, 0.24),
		"soil": Color(0.38, 0.3, 0.24), "trees": false, "water": true, "lt": Color(0, 0, 0, 0), "mossy": false, "path": "stone"},
	"rock": {"gravel": Color(0.62, 0.53, 0.43), "rock": Color(0.52, 0.44, 0.36), "moss": Color(0.4, 0.46, 0.3), "wood": Color(0.42, 0.3, 0.2),
		"soil": Color(0.46, 0.36, 0.27), "trees": false, "water": false, "lt": Color(0.6, 0.52, 0.44), "mossy": false, "path": "rock"},
}
## köy -> iklim
const CLIMATE := {"konoha": "green", "suna": "desert", "kiri": "mist", "kumo": "cloud", "iwa": "rock"}


# ------------------------------------------------------------------ bağlam
class G:
	var b: Builder
	var vid := ""
	var name := ""
	var x := 0.0
	var n := 0.0
	var face := 0.0
	var climate := "green"
	var pal: Dictionary
	var mat := "dirt"
	var rng := RandomNumberGenerator.new()
	var ua := 0.0
	var ub := 0.0
	var da := 2.0
	var db := 10.0
	var cols := {}          # sütun (u / 2) -> [d başı, d sonu]
	var taken: Array = []   # [Vector2(u, d), yarıçap]
	var path: Array = []    # [[Vector2 a, Vector2 e]] (u, d) çizilen patika parçaları
	var lanes: Array = []   # yakındaki toprak sokaklar (dünya xz): [a, e, yarı genişlik]
	var avoid: Array = []   # [Vector2(u, d), yarıçap] bahçe öğesi konmayacak yerler (mevcut bostan vb.)
	var limit_c := Vector2.ZERO   # yerel (x, n): bu dairenin dışına çıkma (köy evlerinin henüz kurulmadığı yerleşkeler)
	var limit_r := 0.0
	var doors: Array = []   # [Vector2(u, kapının duvar d'si)]
	var starts: Array = []  # patikaların başladığı noktalar
	var own_half := 0.0     # binanın kendi katıları: merkezi duvarın içinde (d < 0) ve |u| < own_half olanlar yok sayılır

	func p(u: float, d: float) -> Vector2:
		var f = deg_to_rad(face)
		return Vector2(x + cos(f) * u + sin(f) * d, n - sin(f) * u + cos(f) * d)

	func wxz(u: float, d: float) -> Vector2:
		var q = p(u, d)
		return Vector2(b.origin.x + q.x, b.origin.z - q.y)

	## yerel zemin yüksekliği (b.yoff 0 iken)
	func gy(u: float, d: float) -> float:
		var w = wxz(u, d)
		return Game.terrain_height(w.x, w.y) - b.origin.y

	## (u, d) düzleminde açı (u'dan d'ye, derece) -> Builder yaw: kutunun x ekseni bu yöne bakar
	func yaw_x(theta: float) -> float:
		return face - theta

	## kutunun z ekseni bu yöne bakar
	func yaw_z(theta: float) -> float:
		return face + 90.0 - theta

	## yerin kendisi uygun mu: yapı / ev / ağaç / yol / toprak sokak / su / eğim / sınır
	func site_ok(u: float, d: float, r: float) -> bool:
		var q = p(u, d)
		if limit_r > 0.0 and q.distance_to(limit_c) > limit_r - r:
			return false
		var v = Vector2(u, d)
		for a in avoid:
			if v.distance_to(a[0]) < float(a[1]) + r:
				return false
		var w = Vector2(b.origin.x + q.x, b.origin.z - q.y)
		if not open(w, r):
			return false
		if Game.road_edge_dist(w.x, w.y) < r + 0.8:
			return false
		for ln in lanes:
			if Geometry2D.get_closest_point_to_segment(w, ln[0], ln[1]).distance_to(w) < float(ln[2]) + r + 0.2:
				return false
		var th = Game.terrain_height(w.x, w.y)
		if th < -0.2:
			return false
		var wl = Game.water_level(w.x, w.y)
		if wl > -INF and wl > th - 0.6:
			return false
		var e = maxf(r, 1.2)
		var g0 = th - b.origin.y
		var dh = 0.0
		for o in [Vector2(e, 0), Vector2(-e, 0), Vector2(0, e), Vector2(0, -e)]:
			dh = maxf(dh, absf(gy(u + o.x, d + o.y) - g0))
		return dh < 0.45 * e + 0.45

	## Builder.area_free gibi; ama binanın KENDİ katıları (merkezi duvarın arkasında: çatı saçağı, kubbe / koni etek, kule
	## gövdesinin kare izi) sayılmaz — 2B ızgara yüksekte kalan saçağı yerdeki engel sanıyordu (bahçe yarıya iniyordu)
	func open(p2: Vector2, r: float) -> bool:
		var f = deg_to_rad(face)
		var cf = cos(f)
		var sf = sin(f)
		for cx in range(floori((p2.x - r) / Builder.SCELL), floori((p2.x + r) / Builder.SCELL) + 1):
			for cz in range(floori((p2.y - r) / Builder.SCELL), floori((p2.y + r) / Builder.SCELL) + 1):
				var lst = b.solids.get(Vector2i(cx, cz))
				if lst == null:
					continue
				for rec in lst:
					var lx = float(rec[0]) - b.origin.x - x
					var ln = -(float(rec[1]) - b.origin.z) - n
					var ru = lx * cf - ln * sf
					var rd = lx * sf + ln * cf
					if rd < -0.5 and absf(ru) < own_half:
						continue
					var dx: float = p2.x - rec[0]
					var dz: float = p2.y - rec[1]
					var a: float = rec[4]
					var ca = cos(a); var sa = sin(a)
					var ex = absf(ca * dx - sa * dz) - rec[2]
					var ez = absf(sa * dx + ca * dz) - rec[3]
					if Vector2(maxf(ex, 0.0), maxf(ez, 0.0)).length() < r:
						return false
		return true

	## öğe konabilir mi: yer uygun + başka öğeye / patikaya değmiyor + bahçe dikdörtgeninde
	func clear(u: float, d: float, r: float, path_pad := 0.5) -> bool:
		if u < ua + r * 0.5 - 1.0 or u > ub - r * 0.5 + 1.0 or d < da - 0.5 or d > db + 0.5:
			return false
		var v = Vector2(u, d)
		for t in taken:
			if v.distance_to(t[0]) < float(t[1]) + r:
				return false
		if path_pad >= 0.0:
			for s in path:
				if Geometry2D.get_closest_point_to_segment(v, s[0], s[1]).distance_to(v) < r + path_pad + PATH_HALF:
					return false
		return site_ok(u, d, r)

	## (u, d) yakınında r yarıçaplı boş yer (spiral arama); yoksa Vector2.INF
	func spot(u: float, d: float, r: float, path_pad := 0.5, reach := 3.0) -> Vector2:
		if clear(u, d, r, path_pad):
			return Vector2(u, d)
		var ring = 1.0
		while ring <= reach:
			for k in 8:
				var a = k * PI / 4.0 + ring * 0.7
				var c = Vector2(u + cos(a) * ring, d + sin(a) * ring)
				if clear(c.x, c.y, r, path_pad):
					return c
			ring += 1.0
		return Vector2.INF

	func take(v: Vector2, r: float) -> void:
		taken.append([v, r])

	## sütunun boş d aralığı (bahçe derinliği o noktada)
	func span(u: float) -> Vector2:
		var k = int(round(u / 2.0))
		for o in [0, 1, -1, 2, -2]:
			if cols.has(k + o):
				var c: Array = cols[k + o]
				return Vector2(c[0], c[1])
		return Vector2(da, db)

	## göreli konum: s -1..1 (ua..ub), t 0..1 (o sütunun derinliği)
	func at(s: float, t: float) -> Vector2:
		var u = lerpf(ua + 1.0, ub - 1.0, (s + 1.0) * 0.5)
		var sp = span(u)
		return Vector2(u, lerpf(sp.x + 0.5, sp.y - 0.5, t))

	## yerel konuma (y = zemin + dy) kutu: size.x theta yönünde
	func bx(u: float, d: float, dy: float, size: Vector3, col: Color, theta := 0.0, collide := false, rot := Vector3.ZERO) -> void:
		var q = p(u, d)
		b.box(Vector3(q.x, gy(u, d) + dy, q.y), size, col, yaw_x(theta), collide, rot)


# ------------------------------------------------------------------ giriş
## Bir binanın arkasına bahçe. o: x, n, face, w (duvar genişliği), side (duvar uçlarından taşma), d0 (duvardan ilk d),
## dmax, skip (sütun başında atlanabilecek dolu derinlik), doors ([Vector2(u, kapının d'si)]), style, vid, name, climate,
## avoid, limit ([yerel merkez Vector2, yarıçap]), seed, min_w, min_d
## Döner: kurulduysa true
static func build(b: Builder, o: Dictionary) -> bool:
	var yo = b.yoff
	b.yoff = 0.0
	var g = G.new()
	g.b = b
	g.vid = String(o.get("vid", ""))
	g.name = String(o.get("name", "bahce"))
	g.x = float(o["x"])
	g.n = float(o["n"])
	g.face = float(o.get("face", 0.0))
	g.climate = String(o.get("climate", CLIMATE.get(g.vid, "green")))
	g.pal = PAL.get(g.climate, PAL["green"])
	g.mat = String(o.get("mat", g.pal["path"]))
	g.rng.seed = int(o.get("seed", hash(g.vid + g.name)))
	g.avoid = o.get("avoid", [])
	g.doors = o.get("doors", [])
	g.own_half = float(o.get("w", 20.0)) * 0.5 + 1.0
	if o.has("limit"):
		g.limit_c = o["limit"][0]
		g.limit_r = float(o["limit"][1])
	var ok = _region(g, float(o.get("w", 20.0)) * 0.5, float(o.get("side", 4.0)), float(o.get("d0", 2.0)), float(o.get("dmax", 30.0)),
		float(o.get("skip", 6.0)), float(o.get("min_w", 8.0)), float(o.get("min_d", 6.0)), float(o.get("min_col", 3.9)))
	if not ok:
		print("Bahce %s/%s: yer yok" % [g.vid, g.name])
		b.yoff = yo
		return false
	var c = g.p((g.ua + g.ub) * 0.5, (g.da + g.db) * 0.5)
	var wall = g.p(0.0, 0.0)
	made.append({"vid": g.vid, "name": g.name, "face": g.face, "wall": b.w(Vector3(wall.x, g.gy(0, 0), wall.y)),
		"center": b.w(Vector3(c.x, g.gy((g.ua + g.ub) * 0.5, (g.da + g.db) * 0.5), c.y)), "size": Vector2(g.ub - g.ua, g.db - g.da),
		"u": Vector2(g.ua, g.ub), "d": Vector2(g.da, g.db)})
	if not on() or not FacadeKit_on():
		b.yoff = yo
		return true
	var t0 = Time.get_ticks_usec()
	match String(o.get("style", "")):
		"academy": _academy(g, o)
		"hospital": _hospital(g)
		"formal": _formal(g)
		"karesansui": _karesansui(g, bool(o.get("shrine", false)))
		"anbu": _anbu(g)
		"reading": _reading(g)
		"kage": _kage(g)
		_: _hospital(g)
	_fill(g, String(o.get("style", "")))
	_clear_grass(g)
	# bahçe alanı sonradan konan peyzaj / ara arsa evine kapansın (patika ve tarhların üstüne ev / sokak ağacı düşmesin)
	var cw = g.wxz((g.ua + g.ub) * 0.5, (g.da + g.db) * 0.5)
	b.add_solid(Vector3(cw.x, 0, cw.y), (g.ub - g.ua) * 0.5, (g.db - g.da) * 0.5, deg_to_rad(-g.face))
	print("Bahce %s/%s: %.0fx%.0f m, %d öğe yeri, %d patika parçası, %.0f ms" % [g.vid, g.name, g.ub - g.ua, g.db - g.da, g.taken.size(), g.path.size(),
		(Time.get_ticks_usec() - t0) / 1000.0])
	b.yoff = yo
	return true


## kurak / kayalık bahçe seyrek (her yer kaktüs / çalı olmasın)
static func _dens(g: G) -> float:
	return {"desert": 0.35, "cloud": 0.45, "rock": 0.45, "mist": 0.7}.get(g.climate, 1.0)


## Alana göre ek bitki örtüsü (büyük bahçeler seyrek kalmasın): türüne göre budanmış açelya / yosun / iklim bitkisi
static func _fill(g: G, style: String) -> void:
	if style == "anbu":
		return
	var area = (g.ub - g.ua) * (g.db - g.da)
	var dens = _dens(g)
	var n = clampi(int(area / 22.0 * dens), 3, 70)
	for k in n:
		var pp = g.spot(lerpf(g.ua + 1.2, g.ub - 1.2, g.rng.randf()), lerpf(g.da + 1.0, g.db - 0.8, g.rng.randf()), 0.8, 0.3, 2.0)
		if pp == Vector2.INF:
			continue
		if style in ["formal", "karesansui"] and g.climate in ["green", "mist"]:
			var q = g.p(pp.x, pp.y)
			if g.rng.randf() < 0.35:
				_moss(g, pp.x, pp.y, g.rng.randf_range(0.7, 1.1))
			else:
				var ac = [Color(0.3, 0.54, 0.26), Color(0.86, 0.42, 0.55), Color(0.27, 0.48, 0.24), Color(0.95, 0.9, 0.92)][g.rng.randi() % 4]
				g.b.sphere(Vector3(q.x, g.gy(pp.x, pp.y) + 0.32, q.y), Vector3(1.3, 0.8, 1.1) * g.rng.randf_range(0.8, 1.2), ac, 9)
		else:
			_plant(g, pp.x, pp.y)
		g.take(pp, 0.8)


## Bahçe öğelerinin altında / çevresinde uzun çimen çıkmasın (tarh, kaya, bank, kütük çimenin içinde kayboluyordu):
## RoadMap çimen maskesi (toprak boyamaz, zemin yeşil kalır — biçilmiş bahçe çimi)
static func _clear_grass(g: G) -> void:
	for t in g.taken:
		var r = float(t[1])
		if r < 0.5:
			continue
		var c: Vector2 = t[0]
		var w = g.wxz(c.x, c.y)
		RM.add_lane(w - Vector2(0.01, 0), w + Vector2(0.01, 0), r * 0.9, false)


static func FacadeKit_on() -> bool:
	return OS.get_environment("NO_BACKS") == ""


## Boş alan taraması: 2 m sütunlar; her sütunda duvardan dışarı ilk boş hücreden (en çok skip m atlayarak) kesintisiz boş
## aralık. Kapıyı (yoksa ortayı) içeren en geniş sütun dizisi bahçe olur.
static func _region(g: G, half: float, side: float, d0: float, dmax: float, skip: float, min_w: float, min_d: float, min_col := 3.9) -> bool:
	# yakın toprak sokaklar (Konoha ara sokakları / ev patikaları): bahçe öğesi üstlerine konmaz
	var cw = g.wxz(0.0, (d0 + dmax) * 0.5)
	var rr = half + side + dmax + 10.0
	for ln in RM.lanes:
		if ln.size() < 4 or not bool(ln[3]):
			continue
		var a: Vector2 = ln[0]
		var e: Vector2 = ln[1]
		if Geometry2D.get_closest_point_to_segment(cw, a, e).distance_to(cw) < rr:
			g.lanes.append([a, e, float(ln[2])])
	var k0 = int(ceil(-(half + side) / 2.0))
	var k1 = int(floor((half + side) / 2.0))
	for k in range(k0, k1 + 1):
		var u = k * 2.0
		var ds = -1.0
		var de = -1.0
		var d = d0
		while d <= dmax:
			if g.site_ok(u, d, 1.0):
				if ds < 0.0:
					ds = d
				de = d
			elif ds >= 0.0:
				break
			elif d - d0 >= skip:
				break
			d += 2.0
		if ds >= 0.0 and de - ds >= min_col:
			g.cols[k] = [ds, de + 1.0]
	# kesintisiz sütun dizileri
	var runs: Array = []
	var cur: Array = []
	for k in range(k0, k1 + 1):
		if g.cols.has(k):
			cur.append(k)
		elif not cur.is_empty():
			runs.append(cur)
			cur = []
	if not cur.is_empty():
		runs.append(cur)
	var pref: Array = []
	for dr in g.doors:
		pref.append(int(round((dr as Vector2).x / 2.0)))
	var best: Array = []
	var best_s = -1.0
	for r in runs:
		var area = 0.0
		for k in r:
			area += float(g.cols[k][1]) - float(g.cols[k][0])
		var s = area
		for pk in pref:
			if pk >= int(r[0]) - 1 and pk <= int(r[r.size() - 1]) + 1:
				s += 400.0
		if s > best_s:
			best_s = s
			best = r
	if best.is_empty() or best.size() * 2.0 < min_w:
		return false
	var dsum = 0.0
	var dmin = 1e9
	var dlo = 1e9
	var dhi = -1e9
	for k in best:
		var c: Array = g.cols[k]
		dsum += float(c[1]) - float(c[0])
		dmin = minf(dmin, float(c[0]))
		dlo = minf(dlo, float(c[0]))
		dhi = maxf(dhi, float(c[1]))
	if dsum / best.size() < min_d:
		return false
	# yalnız seçilen dizinin sütunları kalsın
	var keep := {}
	for k in best:
		keep[k] = g.cols[k]
	g.cols = keep
	g.ua = best[0] * 2.0 - 1.0
	g.ub = best[best.size() - 1] * 2.0 + 1.0
	g.da = dlo
	g.db = dhi
	return true


# ------------------------------------------------------------------ patika
## Kapıdan başlayıp hedef noktalardan geçen kıvrımlı patika (Catmull-Rom); her örnek yer denetiminden geçer, dolu yere
## değerse orada biter. Sonu birkaç metre ötede bir sokağa / toprak yola değiyorsa ona bağlanır.
static func _route(g: G, door: Vector2, targets: Array, link := true) -> Array:
	# başlangıç: kapı sütununda basamak / eşya ötesindeki ilk boş nokta
	var s = Vector2.INF
	var d = door.y + 0.8
	while d < door.y + 7.0:
		if g.site_ok(door.x, d, 0.7):
			s = Vector2(door.x, d)
			break
		d += 0.4
	if s == Vector2.INF:
		return []
	var ctrl: Array = [Vector2(door.x, door.y + 0.6), s]
	for t in targets:
		var tv: Vector2 = t
		if tv == Vector2.INF:
			continue
		var q = Vector2.INF
		for rr in [0.0, 1.0, 2.0, 3.0]:
			for k in (1 if rr == 0.0 else 8):
				var c = tv + Vector2(cos(k * PI / 4.0), sin(k * PI / 4.0)) * rr
				if g.site_ok(c.x, c.y, 1.0) and _free_of_taken(g, c, 0.9):
					q = c
					break
			if q != Vector2.INF:
				break
		if q != Vector2.INF:
			ctrl.append(q)
	if ctrl.size() < 3:
		return _route_retry(g, door, targets, link)
	# Catmull-Rom yumuşatma
	var pts: Array = []
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(0, i - 1)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(ctrl.size() - 1, i + 2)]
		var steps = maxi(1, int(p1.distance_to(p2) / 1.2))
		for k in steps:
			var t = float(k) / steps
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	pts.append(ctrl[ctrl.size() - 1])
	# denetim: ilk iki nokta (kapı önü) hariç her örnek boş ve bahçe içinde olmalı
	var out: Array = []
	for i in pts.size():
		var v: Vector2 = pts[i]
		if i >= 2:
			var inside = v.x > g.ua - 0.5 and v.x < g.ub + 0.5 and v.y < g.db + 0.5
			if not inside or not g.site_ok(v.x, v.y, 0.6) or not _free_of_taken(g, v, 0.3):
				break
		out.append(v)
	if out.size() < 4:
		return _route_retry(g, door, targets, link)
	# sona yakın sokak / toprak yol (en çok 6 m): bağla
	if link:
		var e: Vector2 = out[out.size() - 1]
		var ew = g.wxz(e.x, e.y)
		var best = Vector2.INF
		var bd = 6.5
		for ln in g.lanes:
			var cp = Geometry2D.get_closest_point_to_segment(ew, ln[0], ln[1])
			var dd = cp.distance_to(ew) - float(ln[2])
			if dd < bd:
				bd = dd
				best = cp
		if Game.road_edge_dist(ew.x, ew.y) < 6.5:
			for k in 16:
				var dir = Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0))
				for st in range(1, 8):
					var q = ew + dir * st
					if Game.road_edge_dist(q.x, q.y) < 0.3:
						if st < bd:
							bd = st
							best = q
						break
		if best != Vector2.INF:
			# dünya -> (u, d)
			var lq = Vector2(best.x - g.b.origin.x, -(best.y - g.b.origin.z))
			var f = deg_to_rad(g.face)
			var rel = lq - Vector2(g.x, g.n)
			var ud = Vector2(rel.x * cos(f) - rel.y * sin(f), rel.x * sin(f) + rel.y * cos(f))
			var clear = true
			for k in 5:
				var m = e.lerp(ud, (k + 1) / 6.0)
				if not g.open(g.wxz(m.x, m.y), 0.5):
					clear = false
			if clear:
				out.append(ud)
	for i in out.size() - 1:
		g.path.append([out[i], out[i + 1]])
	g.starts.append(out[0])
	return out


## Bir öğenin çevresinde yay boyunca ara noktalar (u'dan d'ye açı, derece): patika öğenin içinden kesmeden dolanır
static func _arc(c: Vector2, R: float, a0: float, a1: float, n := 3) -> Array:
	var out: Array = []
	for k in n:
		var a = deg_to_rad(lerpf(a0, a1, float(k) / maxf(1.0, n - 1)))
		out.append(c + Vector2(cos(a), sin(a)) * R)
	return out


## Patika çıkmadıysa: son hedefi bırakıp yeniden dene; hiç hedef kalmadıysa bahçenin ortasına kısa düz patika
static func _route_retry(g: G, door: Vector2, targets: Array, link: bool) -> Array:
	if targets.size() > 1:
		return _route(g, door, targets.slice(0, targets.size() - 1), link)
	var fb = g.at(lerpf(-1.0, 1.0, inverse_lerp(g.ua, g.ub, clampf(door.x, g.ua, g.ub))) * 0.5, 0.5)
	if targets.size() == 1 and (targets[0] as Vector2).distance_to(fb) > 0.5:
		return _route(g, door, [fb], link)
	return []


static func _free_of_taken(g: G, v: Vector2, pad: float) -> bool:
	for t in g.taken:
		if v.distance_to(t[0]) < float(t[1]) + pad:
			return false
	return true


## Patikayı köyün zeminine uygun malzemeyle çizer: Konoha toprak ara sokak; diğerleri taş / kumtaşı / ıslak taş / kaya plaka
## (altında çimen çıkmasın diye ince çimen maskesi). skip: [Vector2 merkez, yarıçap] (köprü / su) aralıkları çizilmez
static func _draw_path(g: G, pts: Array, skip := []) -> void:
	if pts.size() < 2:
		return
	if g.mat == "dirt":
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var e: Vector2 = pts[i + 1]
			var wet = false
			for s in skip:
				if a.lerp(e, 0.5).distance_to(s[0]) < float(s[1]):
					wet = true
			if wet:
				continue
			RM.add_lane(g.wxz(a.x, a.y), g.wxz(e.x, e.y), PATH_HALF, true)
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = g.rng.seed + 5
	var pitch = {"stone": 0.98, "sand": 1.05, "wet": 0.95, "rock": 1.15}.get(g.mat, 1.0)
	var acc = 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var e: Vector2 = pts[i + 1]
		RM.add_lane(g.wxz(a.x, a.y), g.wxz(e.x, e.y), 0.9, false)   # çimen maskesi (taşın arasından çimen fışkırmasın)
		var L = a.distance_to(e)
		var th = rad_to_deg(atan2(e.y - a.y, e.x - a.x))
		var dir = (e - a) / maxf(L, 0.001)
		var nrm = Vector2(-dir.y, dir.x)
		while acc < L:
			var c = a + dir * acc
			acc += pitch
			var wet = false
			for s in skip:
				if c.distance_to(s[0]) < float(s[1]):
					wet = true
			if wet:
				continue
			var g0 = g.gy(c.x, c.y)
			match g.mat:
				"stone":   # Kumo: kare açık gri döşeme taşı, iki sıra, derzli
					for sx in [-0.5, 0.5]:
						var q = c + nrm * sx
						var col = Color(0.8, 0.8, 0.78).darkened(rng.randf() * 0.12)
						g.bx(q.x, q.y, -0.1 + (g.gy(q.x, q.y) - g0), Vector3(0.92, 0.3, 0.92), col, th, false)
				"sand":    # Suna: enine uzun kumtaşı plaka
					var col2 = Color(0.86, 0.71, 0.5).darkened(rng.randf() * 0.1)
					g.bx(c.x, c.y, -0.12, Vector3(0.82, 0.3, 1.5), col2, th + rng.randf_range(-4, 4), false)
				"wet":     # Kiri: koyu, yuvarlak hatlı ıslak taş (basamak taşı), aralarında yosun
					var q2 = c + nrm * rng.randf_range(-0.25, 0.25)
					var pq = g.p(q2.x, q2.y)
					g.b.cyl(Vector3(pq.x, g.gy(q2.x, q2.y) - 0.02, pq.y), rng.randf_range(0.85, 1.05), 0.16, Color(0.33, 0.37, 0.4).darkened(rng.randf() * 0.15), false, 7)
					if rng.randf() < 0.35:
						var mq = g.p(q2.x + nrm.x * 0.7, q2.y + nrm.y * 0.7)
						g.b.sphere(Vector3(mq.x, g.gy(q2.x + nrm.x * 0.7, q2.y + nrm.y * 0.7), mq.y), Vector3(0.5, 0.18, 0.4), g.pal["moss"], 6)
				"rock":    # Iwa: düzensiz kahve-gri kaya plaka
					var q3 = c + nrm * rng.randf_range(-0.2, 0.2)
					var pq3 = g.p(q3.x, q3.y)
					g.b.cyl(Vector3(pq3.x, g.gy(q3.x, q3.y) - 0.04, pq3.y), rng.randf_range(1.0, 1.3), 0.2, Color(0.52, 0.45, 0.38).darkened(rng.randf() * 0.15), false, 6)
		acc -= L


# ------------------------------------------------------------------ öğeler
static func _m(key: String) -> Mesh:
	if _mesh.has(key):
		return _mesh[key]
	var m: Mesh = null
	if key.begins_with("flower"):
		m = Props.flower_mesh(int(key.substr(6)))
	elif key.begins_with("veg"):
		m = Props.vegetation_mesh(int(key.substr(3)))
	elif key == "pine":
		m = AnimeTree.mesh("pine", "pine", 1)
	elif key == "pine2":
		m = AnimeTree.mesh("pine", "pine", 2)
	elif key == "fir":
		m = AnimeTree.mesh("fir", "fir", 1)
	elif key == "maple":
		m = AnimeTree.mesh("slender", "momiji", 3)
	elif key == "sakura":
		m = AnimeTree.mesh("broad", "sakura", 2)
	elif key == "broad":
		m = AnimeTree.mesh("broad", "green", 1)
	else:
		m = CityLandscape.mesh(key)
	_mesh[key] = m
	return m


static func _pack(g: G, key: String, u: float, d: float, yaw := 0.0, s := 1.0, dy := 0.0) -> void:
	var q = g.p(u, d)
	g.b.pack_mesh(_m(key), Vector3(q.x, g.gy(u, d) + dy, q.y), yaw, s, 1.0)


## Ağaç (iklim izin veriyorsa): gövde katı, taç diğer ağaçlarla iç içe girmez
static func _tree(g: G, u: float, d: float, kind: String, s: float) -> bool:
	if not g.pal["trees"]:
		return false
	var q = g.p(u, d)
	var w = g.wxz(u, d)
	if Builder.tree_crowded(w, s, 1.6):
		return false
	Builder.tree_mark(w, s)
	g.b.pack_mesh(_m(kind), Vector3(q.x, g.gy(u, d) - 0.15, q.y), g.rng.randf() * 360.0, s, 1.0)
	g.b._collide_cyl(g.b.w(Vector3(q.x, g.gy(u, d) + 2.5 * s, q.y)), 0.32 * s, 5.0 * s)
	g.take(Vector2(u, d), 1.2 * s)
	return true


## İklime göre küçük bitki öbeği (çiçek / eğrelti / sukulent / bodur çalı / kaya)
static func _plant(g: G, u: float, d: float, big := false) -> void:
	var r = g.rng
	match g.climate:
		"green":
			var pick = r.randi() % 5
			if pick < 3:
				var fv = [0, 1, 2][pick]
				for k in 3 + r.randi() % 3:
					_pack(g, "flower%d" % fv, u + r.randf_range(-0.9, 0.9), d + r.randf_range(-0.7, 0.7), r.randf() * 360.0, r.randf_range(0.8, 1.1))
			else:
				_pack(g, "veg18", u, d, r.randf() * 360.0, r.randf_range(0.6, 0.9) * (1.3 if big else 1.0))
		"mist":
			if r.randf() < 0.5:
				_pack(g, "veg10", u, d, r.randf() * 360.0, r.randf_range(0.4, 0.55))
			else:
				_moss(g, u, d, r.randf_range(0.8, 1.3))
				_pack(g, "veg10", u + 0.8, d + 0.3, r.randf() * 360.0, 0.4)
		"desert":
			match r.randi() % 3:
				0: _agave(g, u, d, r.randf_range(0.8, 1.2))
				1: _pack(g, "veg3", u, d, r.randf() * 360.0, r.randf_range(0.35, 0.55))
				_: _pack(g, "jar", u, d, r.randf() * 360.0, r.randf_range(0.9, 1.2))
		"cloud":
			if r.randf() < 0.6:
				_pack(g, "veg18", u, d, r.randf() * 360.0, r.randf_range(0.5, 0.75))
			else:
				_pack(g, "veg19", u, d, r.randf() * 360.0, r.randf_range(0.6, 0.9))
		_:
			if r.randf() < 0.5:
				_pack(g, "veg17", u, d, r.randf() * 360.0, r.randf_range(0.6, 0.9))
			else:
				_rock(g, u, d, r.randf_range(0.6, 1.0), false)


static func _moss(g: G, u: float, d: float, s: float) -> void:
	var q = g.p(u, d)
	g.b.sphere(Vector3(q.x, g.gy(u, d) - 0.05, q.y), Vector3(1.7, 0.55, 1.4) * s, g.pal["moss"].lightened(g.rng.randf_range(-0.04, 0.06)), 8)


## Kaya (büyükse katı) + dibinde yosun (yosunlu iklimlerde)
static func _rock(g: G, u: float, d: float, s: float, moss := true) -> void:
	var q = g.p(u, d)
	var sz = Vector3(1.6, 1.2, 1.3) * s
	var col: Color = g.pal["rock"].darkened(g.rng.randf_range(-0.06, 0.12))
	g.b.boulder(Vector3(q.x, g.gy(u, d) + sz.y * 0.3, q.y), sz, col, g.rng.randi() % 16, s >= 1.0, g.rng.randf() * 360.0)
	if moss and g.pal["mossy"]:
		var mq = g.p(u + 0.5 * s, d - 0.3 * s)
		g.b.sphere(Vector3(mq.x, g.gy(u, d) + 0.02, mq.y), Vector3(1.4, 0.3, 1.0) * s, g.pal["moss"], 7)


## Sukulent (agav): tabandan dışa açılan kalın yapraklar
static func _agave(g: G, u: float, d: float, s: float) -> void:
	var gy = g.gy(u, d)
	var q = g.p(u, d)
	var col = Color(0.42, 0.58, 0.48)
	for k in 7:
		var a = k * TAU / 7.0
		var lq = g.p(u + cos(a) * 0.22 * s, d + sin(a) * 0.22 * s)
		g.b.box(Vector3(lq.x, gy + 0.32 * s, lq.y), Vector3(0.14, 0.7, 0.05) * s, col.lightened((k % 3) * 0.05), g.yaw_x(rad_to_deg(a) + 90.0), false, Vector3(0, 0, 0) + Vector3(-38.0, 0, 0))
	g.b.sphere(Vector3(q.x, gy + 0.12 * s, q.y), Vector3(0.4, 0.3, 0.4) * s, col.darkened(0.1), 6)


## Bank: oturağın önü f yönüne (u, d) bakar
static func _bench(g: G, u: float, d: float, f: Vector2, stone := false) -> void:
	var th = rad_to_deg(atan2(f.y, f.x))
	var gy = g.gy(u, d)
	var wood: Color = g.pal["wood"]
	var back = Vector2(u, d) - f.normalized() * 0.24
	var yaw = g.yaw_z(th)
	var q = g.p(u, d)
	if stone:   # taş bank (Suna / Kumo / Iwa): tek blok oturak, iki ayak
		var sc: Color = g.pal["rock"].lightened(0.15)
		g.b.box(Vector3(q.x, gy + 0.42, q.y), Vector3(2.0, 0.16, 0.6), sc, yaw, true)
		for sx in [-0.75, 0.75]:
			var lq = g.p(u + cos(deg_to_rad(th + 90.0)) * sx, d + sin(deg_to_rad(th + 90.0)) * sx)
			g.b.box(Vector3(lq.x, gy + 0.18, lq.y), Vector3(0.3, 0.4, 0.5), sc.darkened(0.15), yaw, false)
		return
	g.b.box(Vector3(q.x, gy + 0.46, q.y), Vector3(1.9, 0.08, 0.48), wood, yaw, false)
	g.b._collide(g.b.w(Vector3(q.x, gy + 0.3, q.y)), Vector3(1.9, 0.6, 0.55), -yaw)
	var bq = g.p(back.x, back.y)
	g.b.box(Vector3(bq.x, gy + 0.82, bq.y), Vector3(1.9, 0.3, 0.06), wood, yaw, false, Vector3(-10, 0, 0))
	for sx in [-0.8, 0.8]:
		var a = deg_to_rad(th + 90.0)
		var lq = g.p(u + cos(a) * sx, d + sin(a) * sx)
		g.b.box(Vector3(lq.x, gy + 0.22, lq.y), Vector3(0.1, 0.44, 0.44), wood.darkened(0.3), yaw, false)
		var lb = g.p(back.x + cos(a) * sx, back.y + sin(a) * sx)
		g.b.box(Vector3(lb.x, gy + 0.62, lb.y), Vector3(0.08, 0.42, 0.08), wood.darkened(0.3), yaw, false)


## Taş fener (Kasuga tōrō = 1, alçak yukimi = 4); iklimin taş rengiyle
static func _lantern(g: G, u: float, d: float, style := 1) -> void:
	var q = g.p(u, d)
	g.b.lantern_design(q.x, q.y, style, g.gy(u, d), g.pal["lt"], bool(g.pal["mossy"]))
	g.take(Vector2(u, d), 0.8)


## Gölet: su diski (en yüksek zemin + 6 cm), kenar taşları (patika giriş / çıkışında boşluk), nilüfer, saz
static func _pond(g: G, c: Vector2, r: float, gaps := []) -> float:
	var top = -1e9
	for k in 9:
		var a = k * TAU / 8.0
		var rr = r if k < 8 else 0.0
		top = maxf(top, g.gy(c.x + cos(a) * rr, c.y + sin(a) * rr))
	var wy = top + 0.06
	var q = g.p(c.x, c.y)
	g.b.cyl(Vector3(q.x, wy - 0.5, q.y), r * 2.0 - 0.3, 0.9, Color(0.16, 0.22, 0.2), false, 20)   # koyu havuz tabanı (su saydam)
	KageHall._water_disc(g.b, Vector3(q.x, wy, q.y), r * 2.0)
	var nst = int(TAU * r / 1.1)
	for k in nst:
		var a = k * TAU / nst
		var sp = c + Vector2(cos(a), sin(a)) * (r + 0.1)
		var gap = false
		for gp in gaps:
			if sp.distance_to(gp) < 1.6:
				gap = true
		if gap:
			continue
		var sq = g.p(sp.x, sp.y)
		var s = g.rng.randf_range(0.75, 1.15)
		g.b.sphere(Vector3(sq.x, wy + 0.02, sq.y), Vector3(1.2, 0.55, 0.95) * s, g.pal["rock"].lightened(g.rng.randf_range(-0.05, 0.12)), 7)
	for k in 3 + int(r):
		var a = g.rng.randf() * TAU
		var lr = g.rng.randf_range(0.3, 0.75) * r
		var lq = g.p(c.x + cos(a) * lr, c.y + sin(a) * lr)
		g.b.pack_mesh(_m("lily"), Vector3(lq.x, wy + 0.02, lq.y), g.rng.randf() * 360.0, g.rng.randf_range(0.8, 1.2), 1.0)
	for k in 2:
		var a = g.rng.randf() * TAU
		var rq = c + Vector2(cos(a), sin(a)) * (r + 0.6)
		var skip = false
		for gp in gaps:
			if rq.distance_to(gp) < 2.0:
				skip = true
		if not skip:
			_pack(g, "veg16", rq.x, rq.y, g.rng.randf() * 360.0, 0.8)
	g.take(c, r + 0.8)
	return wy


## Kemerli ahşap köprü a -> e (u, d): yürünür eğik tahta parçaları + kırmızı korkuluk
static func _bridge(g: G, a: Vector2, e: Vector2, wy: float, col := Color(0.72, 0.2, 0.15)) -> void:
	var L = a.distance_to(e)
	var th = rad_to_deg(atan2(e.y - a.y, e.x - a.x))
	var yaw = g.yaw_z(th)
	var ga = g.gy(a.x, a.y)
	var ge = g.gy(e.x, e.y)
	var H = clampf(L * 0.16, 0.5, 1.2)
	var N = maxi(4, int(ceil(L / 0.8)))
	var nrm = Vector2(-(e - a).y, (e - a).x).normalized()
	var deck = Color(0.5, 0.36, 0.24)
	var hf = func(t: float) -> float: return maxf(lerpf(ga, ge, t), wy - 0.1) + H * sin(PI * t) + 0.12
	for k in N:
		var t0 = float(k) / N
		var t1 = float(k + 1) / N
		var y0: float = hf.call(t0)
		var y1: float = hf.call(t1)
		var m = a.lerp(e, (t0 + t1) * 0.5)
		var q = g.p(m.x, m.y)
		var seg = L / N
		var pitch = rad_to_deg(atan2(y1 - y0, seg))
		g.b.box(Vector3(q.x, (y0 + y1) * 0.5 - 0.06, q.y), Vector3(1.7, 0.14, seg + 0.06), deck.darkened((k % 2) * 0.06), yaw, true, Vector3(-pitch, 0, 0))
		for sx in [-0.9, 0.9]:   # korkuluk: dikme + üst küpeşte
			var rq = g.p(m.x + nrm.x * sx, m.y + nrm.y * sx)
			g.b.box(Vector3(rq.x, (y0 + y1) * 0.5 + 0.45, rq.y), Vector3(0.09, 0.08, seg + 0.04), col, yaw, false, Vector3(-pitch, 0, 0))
			g.b.box(Vector3(rq.x, (y0 + y1) * 0.5 + 0.22, rq.y), Vector3(0.1, 0.6, 0.1), col.darkened(0.15), yaw, false)
	# uçta yere inen dikmeler ve kenar taşları
	for t in [0.0, 1.0]:
		var m2 = a.lerp(e, t)
		for sx in [-0.9, 0.9]:
			var rq2 = g.p(m2.x + nrm.x * sx, m2.y + nrm.y * sx)
			g.b.box(Vector3(rq2.x, g.gy(m2.x, m2.y) + 0.45, rq2.y), Vector3(0.16, 0.9, 0.16), col.darkened(0.2), yaw, true)


## Tırmıklı çakıl yatağı (karesansui): araziyi izleyen karolar + tırmık çizgileri + kenar taşı
static func _gravel(g: G, c: Vector2, w: float, dd: float, rake := true, col := Color(-1, 0, 0)) -> void:
	var gc: Color = g.pal["gravel"] if col.r < 0.0 else col
	var nu = maxi(1, int(ceil(w / 3.0)))
	var nd = maxi(1, int(ceil(dd / 3.0)))
	var tw = w / nu
	var td = dd / nd
	for i in nu:
		for j in nd:
			var tu = c.x - w * 0.5 + (i + 0.5) * tw
			var tdd = c.y - dd * 0.5 + (j + 0.5) * td
			g.bx(tu, tdd, -0.22, Vector3(tw + 0.02, 0.5, td + 0.02), gc.darkened(g.rng.randf() * 0.03), 0.0, false)
			if rake:
				var nl = int(td / 0.4)
				for l in nl:
					g.bx(tu, tdd - td * 0.5 + (l + 0.5) * td / nl, 0.035, Vector3(tw, 0.02, 0.07), gc.darkened(0.12), 0.0, false)
	# kenar taşı
	var edge = gc.darkened(0.35)
	for sz in [-1.0, 1.0]:
		for i in nu:
			g.bx(c.x - w * 0.5 + (i + 0.5) * tw, c.y + sz * (dd * 0.5 + 0.15), 0.0, Vector3(tw + 0.05, 0.22, 0.3), edge, 0.0, false)
		for j in nd:
			g.bx(c.x + sz * (w * 0.5 + 0.15), c.y - dd * 0.5 + (j + 0.5) * td, 0.0, Vector3(0.3, 0.22, td + 0.35), edge, 0.0, false)


## Çakılda kaya + çevresinde tırmık halkaları
static func _rock_ripple(g: G, c: Vector2, s: float, ring := true) -> void:
	_rock(g, c.x, c.y, s, true)
	if not ring:
		return
	var q = g.p(c.x, c.y)
	var gy = g.gy(c.x, c.y)
	var gc: Color = g.pal["gravel"]
	var rads = [s * 1.6 + 1.4, s * 1.6 + 1.15, s * 1.6 + 0.8, s * 1.6 + 0.55]
	for k in rads.size():
		g.b.cyl(Vector3(q.x, gy + 0.045 + k * 0.004, q.y), rads[k] * 2.0, 0.02, gc.darkened(0.14) if k % 2 == 0 else gc, false, 20)


## Bambu çit (kenninji-gaki): direkler, yarık bambu pano, üç kuşak, siyah ip bağları; katı
static func _bamboo_fence(g: G, a: Vector2, e: Vector2, h := 1.5) -> void:
	var L = a.distance_to(e)
	var th = rad_to_deg(atan2(e.y - a.y, e.x - a.x))
	var bam = Color(0.72, 0.64, 0.42)
	if g.climate == "mist":
		bam = Color(0.5, 0.5, 0.42)
	var nseg = maxi(1, int(ceil(L / 1.8)))
	for k in nseg:
		var m = a.lerp(e, (k + 0.5) / nseg)
		var seg = L / nseg
		var gy = g.gy(m.x, m.y)
		g.bx(m.x, m.y, h * 0.5 - 0.05, Vector3(seg + 0.02, h, 0.06), bam.darkened((k % 2) * 0.05), th, false)
		for l in int(seg / 0.16):   # dikey bambu çıtaları (pano üstünde ince çizgi)
			var lm = a.lerp(e, (k + (l + 0.5) / int(seg / 0.16)) / nseg)
			g.bx(lm.x, lm.y, h * 0.5 - 0.05, Vector3(0.03, h - 0.06, 0.08), bam.darkened(0.2), th, false)
		for yy in [0.3, 0.75, 1.2]:
			g.bx(m.x, m.y, yy * h / 1.5, Vector3(seg + 0.03, 0.07, 0.14), bam.darkened(0.12), th, false)
		var pq = g.p(a.lerp(e, float(k) / nseg).x, a.lerp(e, float(k) / nseg).y)
		var pg = g.gy(a.lerp(e, float(k) / nseg).x, a.lerp(e, float(k) / nseg).y)
		g.b.cyl(Vector3(pq.x, pg + h * 0.55, pq.y), 0.14, h * 1.1, bam.darkened(0.3), false, 6)
		var cq = g.p(m.x, m.y)
		g.b._collide(g.b.w(Vector3(cq.x, gy + h * 0.5, cq.y)), Vector3(seg, h, 0.3), -g.yaw_x(th))
		var _u = gy
	var eq = g.p(e.x, e.y)
	g.b.cyl(Vector3(eq.x, g.gy(e.x, e.y) + h * 0.55, eq.y), 0.14, h * 1.1, bam.darkened(0.3), false, 6)


## Antrenman kütüğü (katı) + saman sargısı
static func _stump(g: G, u: float, d: float, col := Color(0.45, 0.32, 0.2)) -> void:
	var q = g.p(u, d)
	var gy = g.gy(u, d)
	g.b.cyl(Vector3(q.x, gy + 0.75, q.y), 0.55, 1.6, col, true, 9)
	g.b.cyl(Vector3(q.x, gy + 1.0, q.y), 0.62, 0.42, Color(0.84, 0.76, 0.52) if col.v > 0.25 else Color(0.3, 0.28, 0.26), false, 9)
	g.b.cyl(Vector3(q.x, gy + 1.56, q.y), 0.5, 0.04, col.lightened(0.25), false, 9)
	g.take(Vector2(u, d), 0.6)


## Hedef tahtası: direk (katı) + halkalı yuvarlak tahta, yüzü f (u, d) yönüne bakar
static func _target(g: G, u: float, d: float, f: Vector2, dark := false) -> void:
	var q = g.p(u, d)
	var gy = g.gy(u, d)
	var fl = g.p(u + f.x, d + f.y) - q   # yerel (x, n) yön
	var yaw = rad_to_deg(atan2(-fl.x, -fl.y))
	var post = Color(0.3, 0.26, 0.24) if dark else Color(0.46, 0.33, 0.2)
	g.b.box(Vector3(q.x, gy + 0.85, q.y), Vector3(0.18, 1.7, 0.18), post, 0.0, true)
	var bq = g.p(u + f.normalized().x * 0.12, d + f.normalized().y * 0.12)
	var cols = [Color(0.9, 0.88, 0.82), Color(0.15, 0.15, 0.16), Color(0.9, 0.88, 0.82), Color(0.78, 0.16, 0.14)]
	if dark:
		cols = [Color(0.3, 0.3, 0.32), Color(0.85, 0.84, 0.8), Color(0.3, 0.3, 0.32), Color(0.62, 0.1, 0.1)]
	for k in cols.size():
		var off = f.normalized() * (0.12 + k * 0.025)
		var rq = g.p(u + off.x, d + off.y)
		g.b.disc(Vector3(rq.x, gy + 1.5, rq.y), 1.2 - k * 0.28, 0.06, cols[k], yaw, 16)
	var _b = bq
	g.take(Vector2(u, d), 0.7)


## Silah askısı (tahta kılıç / kunai): iki direk, iki kiriş, yaslı tahta kılıçlar; katı
static func _rack(g: G, u: float, d: float, th: float, dark := false) -> void:
	var wood: Color = Color(0.22, 0.2, 0.2) if dark else g.pal["wood"]
	var gy = g.gy(u, d)
	for sx in [-1.0, 1.0]:
		var a = deg_to_rad(th)
		g.bx(u + cos(a) * sx, d + sin(a) * sx, 0.6, Vector3(0.12, 1.2, 0.12), wood.darkened(0.2), th, false)
	g.bx(u, d, 1.05, Vector3(2.1, 0.08, 0.1), wood, th, false)
	g.bx(u, d, 0.35, Vector3(2.1, 0.08, 0.1), wood, th, false)
	for k in 5:
		var a2 = deg_to_rad(th)
		var o = -0.8 + k * 0.4
		g.bx(u + cos(a2) * o, d + sin(a2) * o, 0.62, Vector3(0.06, 1.2, 0.04), Color(0.7, 0.58, 0.4) if not dark else Color(0.5, 0.48, 0.45), th, false, Vector3(-12, 0, 0))
	var q = g.p(u, d)
	g.b._collide(g.b.w(Vector3(q.x, gy + 0.6, q.y)), Vector3(2.2, 1.2, 0.4), -g.yaw_x(th))
	g.take(Vector2(u, d), 1.2)


## Ahşap çerçeveli bitki yatağı: çerçeve, toprak, sıra sıra ot / lavanta / sebze. kind: "herb" "veg" "flower"
static func _bed(g: G, c: Vector2, w: float, dd: float, kind: String) -> void:
	var wood: Color = g.pal["wood"]
	var soil: Color = g.pal["soil"]
	g.bx(c.x, c.y, 0.06, Vector3(w - 0.2, 0.32, dd - 0.2), soil, 0.0, false)
	for sz in [-1.0, 1.0]:
		g.bx(c.x, c.y + sz * dd * 0.5, 0.12, Vector3(w + 0.14, 0.34, 0.14), wood, 0.0, false)
		g.bx(c.x + sz * w * 0.5, c.y, 0.12, Vector3(0.14, 0.34, dd), wood, 0.0, false)
	var rows = maxi(1, int(dd / 0.9))
	for r in rows:
		var rd = c.y - dd * 0.5 + (r + 0.5) * dd / rows
		var np = maxi(1, int((w - 0.4) / 0.7))
		for k in np:
			var ru = c.x - w * 0.5 + 0.35 + (k + 0.5) * (w - 0.7) / np
			match kind:
				"herb":
					if r % 3 == 1:
						_pack(g, "flower3", ru, rd, g.rng.randf() * 360.0, 0.75, 0.2)   # lavanta
					else:
						var q = g.p(ru, rd)
						var hc = [Color(0.38, 0.66, 0.3), Color(0.52, 0.7, 0.4), Color(0.3, 0.54, 0.34)][r % 3]
						g.b.sphere(Vector3(q.x, g.gy(ru, rd) + 0.32, q.y), Vector3(0.5, 0.36, 0.45), hc.lightened(g.rng.randf() * 0.06), 6)
				"veg":
					var q2 = g.p(ru, rd)
					if r % 2 == 0:   # lahana / marul
						g.b.sphere(Vector3(q2.x, g.gy(ru, rd) + 0.32, q2.y), Vector3(0.52, 0.4, 0.52), Color(0.46, 0.7, 0.34).lightened(g.rng.randf() * 0.08), 7)
					else:            # sırıklı domates
						g.b.box(Vector3(q2.x, g.gy(ru, rd) + 0.8, q2.y), Vector3(0.05, 1.2, 0.05), wood.lightened(0.2), 0.0, false)
						g.b.sphere(Vector3(q2.x, g.gy(ru, rd) + 0.62, q2.y), Vector3(0.42, 0.7, 0.42), Color(0.3, 0.55, 0.26), 6)
						g.b.sphere(Vector3(q2.x + 0.12, g.gy(ru, rd) + 0.58, q2.y), Vector3(0.14, 0.14, 0.14), Color(0.86, 0.2, 0.15), 5)
				_:
					_pack(g, "flower%d" % [0, 1, 2][(r + k) % 3], ru, rd, g.rng.randf() * 360.0, 0.85, 0.2)
	g.take(c, maxf(w, dd) * 0.5 + 0.3)


## Taş havuzlu çeşme (hastane): sekizgen havuz (katı), su, ortada kaide + kâse
static func _fountain(g: G, c: Vector2, r := 2.0) -> void:
	var q = g.p(c.x, c.y)
	var gy = g.gy(c.x, c.y)
	var st: Color = g.pal["rock"].lightened(0.2)
	g.b.cyl(Vector3(q.x, gy + 0.25, q.y), r * 2.0, 0.5, st, true, 8)   # havuz gövdesi (üstü 0.5)
	for k in 8:   # sekizgen kenar taşları (suyun çevresinde, üstü 0.72)
		var a = (k + 0.5) * TAU / 8.0
		var eq = g.p(c.x + cos(a) * (r - 0.12), c.y + sin(a) * (r - 0.12))
		g.b.box(Vector3(eq.x, gy + 0.6, eq.y), Vector3(2.0 * r * tan(PI / 8.0) + 0.1, 0.24, 0.32), st.lightened(0.08), g.yaw_z(rad_to_deg(a)), false)
	KageHall._water_disc(g.b, Vector3(q.x, gy + 0.56, q.y), r * 2.0 - 0.5)
	g.b.cyl(Vector3(q.x, gy + 1.0, q.y), 0.45, 1.2, st, false, 8)
	g.b.cyl(Vector3(q.x, gy + 1.65, q.y), 1.3, 0.25, st.lightened(0.05), false, 10)
	g.b.cyl(Vector3(q.x, gy + 1.79, q.y), 1.05, 0.04, Color(0.45, 0.62, 0.7), false, 10)
	g.take(c, r + 0.7)


## Taş su leğeni (tsukubai) + bambu oluk + kepçe
static func _tsukubai(g: G, c: Vector2) -> void:
	var q = g.p(c.x, c.y)
	var gy = g.gy(c.x, c.y)
	var st: Color = g.pal["rock"]
	g.b.cyl(Vector3(q.x, gy + 0.3, q.y), 0.9, 0.6, st, true, 10)
	g.b.cyl(Vector3(q.x, gy + 0.59, q.y), 0.55, 0.04, Color(0.22, 0.34, 0.4), false, 10)
	var sq = g.p(c.x + 0.8, c.y)
	g.b.box(Vector3(sq.x, gy + 0.5, sq.y), Vector3(0.1, 1.0, 0.1), Color(0.6, 0.56, 0.36), 0.0, false)
	g.bx(c.x + 0.5, c.y, 0.85, Vector3(0.7, 0.07, 0.07), Color(0.62, 0.6, 0.38), 0.0, false, Vector3(0, 0, 12))
	for k in 3:
		var a = k * TAU / 3.0 + 0.6
		var rq = g.p(c.x + cos(a) * 0.9, c.y + sin(a) * 0.9)
		g.b.sphere(Vector3(rq.x, gy + 0.1, rq.y), Vector3(0.6, 0.3, 0.5), st.lightened(0.08), 6)
	g.take(c, 1.2)


## Gölgelik (Suna): dört direk (katı) + gergin bez
static func _shade(g: G, c: Vector2, th: float, cloth: Color) -> void:
	var gy = g.gy(c.x, c.y)
	var a = deg_to_rad(th)
	var ax = Vector2(cos(a), sin(a))
	var az = Vector2(-sin(a), cos(a))
	for sx in [-1.4, 1.4]:
		for sz in [-1.1, 1.1]:
			var pq = c + ax * sx + az * sz
			var q = g.p(pq.x, pq.y)
			g.b.box(Vector3(q.x, g.gy(pq.x, pq.y) + 1.25, q.y), Vector3(0.14, 2.5, 0.14), g.pal["wood"], 0.0, true)
	g.bx(c.x, c.y, 2.55 + (gy - g.gy(c.x, c.y)), Vector3(3.2, 0.06, 2.6), cloth, th, false, Vector3(-6, 0, 0))


## Alçak avlu duvarı a -> e (katı): gövde + üst şapka
static func _low_wall(g: G, a: Vector2, e: Vector2, col: Color, h := 1.0) -> void:
	var L = a.distance_to(e)
	var th = rad_to_deg(atan2(e.y - a.y, e.x - a.x))
	var nseg = maxi(1, int(ceil(L / 3.0)))
	for k in nseg:
		var m = a.lerp(e, (k + 0.5) / nseg)
		g.bx(m.x, m.y, h * 0.5 - 0.3, Vector3(L / nseg + 0.04, h + 0.6, 0.5), col, th, true)
		g.bx(m.x, m.y, h + 0.04, Vector3(L / nseg + 0.1, 0.12, 0.64), col.darkened(0.15), th, false)


## Kayalık bölge zemin döşemesi (Iwa): basamaklı yassı kaya teras
static func _terrace(g: G, c: Vector2, w: float, dd: float) -> void:
	var col: Color = g.pal["rock"]
	for k in 3:
		var s = 1.0 - k * 0.28
		g.bx(c.x + k * 0.3, c.y + k * 0.2, 0.12 + k * 0.3 - 0.2, Vector3(w * s, 0.5, dd * s), col.lightened(0.05 * k), 7.0 * k, k == 2)
	g.take(c, maxf(w, dd) * 0.5)


## Taş yığını (Iwa: dengede duran yassı taşlar)
static func _cairn(g: G, c: Vector2) -> void:
	var q = g.p(c.x, c.y)
	var gy = g.gy(c.x, c.y)
	var y = gy
	for k in 5:
		var s = 0.9 - k * 0.14
		g.b.sphere(Vector3(q.x, y + 0.12 * s, q.y), Vector3(s, 0.32 * s, s * 0.85), g.pal["rock"].lightened(k * 0.04), 7)
		y += 0.24 * s
	g.take(c, 0.7)


# ------------------------------------------------------------------ bahçe türleri
## Akademi: antrenman köşesi (kütükler, hedefler, silah askısı) + öğrenci bahçesi (tarhlar / sebze, banklar, ağaç)
static func _academy(g: G, o: Dictionary) -> void:
	var r = g.rng
	var door: Vector2 = g.doors[0] if not g.doors.is_empty() else Vector2(0, 0)
	var left = door.x < (g.ua + g.ub) * 0.5   # antrenman köşesi kapının tarafında, bahçe öbür tarafta
	var sgn = -1.0 if left else 1.0
	# antrenman köşesi
	var tc = g.at(sgn * 0.55, 0.55)
	var tr = g.at(sgn * 0.85, 0.75)
	var gard = g.at(-sgn * 0.45, 0.55)
	var end = g.at(-sgn * 0.1, 0.8)
	var pts = _route(g, door, [g.at(sgn * 0.2, 0.3), tc + Vector2(-sgn * 4.0, -2.0), g.at(0.0, 0.62), end])
	_draw_path(g, pts)
	if g.doors.size() > 1 and not pts.is_empty():   # ikinci arka kapı: ana patikaya kısa bağlantı
		var d2: Vector2 = g.doors[1]
		var near = pts[mini(pts.size() - 1, pts.size() / 2)]
		var best_d = 1e9
		for v in pts:
			if (v as Vector2).distance_to(Vector2(d2.x, d2.y + 4.0)) < best_d:
				best_d = (v as Vector2).distance_to(Vector2(d2.x, d2.y + 4.0))
				near = v
		var p2 = _route(g, d2, [Vector2(d2.x, d2.y + 4.0).lerp(near, 0.5), near], false)
		_draw_path(g, p2)
	var big = g.ub - g.ua > 40.0
	var nst = 5 if big else 3
	for k in nst:   # kütük sırası
		var sp = g.spot(tc.x + (k - nst * 0.5) * 2.2, tc.y, 0.7)
		if sp != Vector2.INF:
			_stump(g, sp.x, sp.y, Color(0.45, 0.32, 0.2) if g.climate != "desert" else Color(0.6, 0.46, 0.3))
	for k in (2 if big else 1):   # hedef tahtaları: kütüklere / atış çizgisine bakar
		var sp2 = g.spot(tr.x + k * 3.0 * -sgn, tr.y + 1.0, 0.8)
		if sp2 != Vector2.INF:
			_target(g, sp2.x, sp2.y, tc - sp2)
	var rk = g.spot(tc.x - sgn * 1.0, tc.y + 4.0, 1.3)
	if rk != Vector2.INF:
		_rack(g, rk.x, rk.y, 0.0)
	# öğrenci bahçesi: tarhlar (yeşil iklimde çiçek / sebze; çölde sukulent ve küp; kayalıkta kaya + bodur ot)
	var nb = 3 if big else 1
	for k in nb:
		var bc = g.spot(gard.x + (k - (nb - 1) * 0.5) * 5.5, gard.y, 2.2)
		if bc == Vector2.INF:
			continue
		if g.climate in ["green", "mist", "cloud"]:
			_bed(g, bc, 3.6, 2.2, ["flower", "veg", "herb"][k % 3])
		else:
			g.take(bc, 2.0)
			for j in 4:
				_plant(g, bc.x + r.randf_range(-1.6, 1.6), bc.y + r.randf_range(-1.0, 1.0))
	# korkuluk kuş (bostan bekçisi) — küçük çocuk işi
	var kc = g.spot(gard.x + sgn * 3.0, gard.y + 3.0, 0.7)
	if kc != Vector2.INF and g.climate in ["green", "mist"]:
		var q = g.p(kc.x, kc.y)
		var gy = g.gy(kc.x, kc.y)
		g.b.box(Vector3(q.x, gy + 0.9, q.y), Vector3(0.1, 1.8, 0.1), g.pal["wood"], 0.0, true)
		g.bx(kc.x, kc.y, 1.35, Vector3(1.4, 0.08, 0.08), g.pal["wood"], 0.0, false)
		g.b.sphere(Vector3(q.x, gy + 1.85, q.y), Vector3(0.4, 0.4, 0.4), Color(0.86, 0.8, 0.6), 6)
		g.b.cone(Vector3(q.x, gy + 2.1, q.y), 0.9, 0.35, Color(0.78, 0.68, 0.38), 8)
		g.bx(kc.x, kc.y, 1.2, Vector3(0.7, 0.7, 0.12), Color(0.3, 0.45, 0.7), 0.0, false)
		g.take(kc, 0.8)
	# banklar (bahçeye / antrenman köşesine bakar)
	for k in (2 if big else 1):
		var bp = g.spot(end.x + (k * 2 - 1) * 3.5, end.y + 1.5, 1.1)
		if bp != Vector2.INF:
			_bench(g, bp.x, bp.y, Vector2(0, -1), g.climate in ["desert", "rock", "cloud"])
			g.take(bp, 1.2)
	# ağaçlar / bitkiler
	for k in (4 if big else 2):
		var tp = g.spot(lerpf(g.ua + 3.0, g.ub - 3.0, r.randf()), lerpf(g.da + 4.0, g.db - 1.5, r.randf()), 2.4, 0.8, 5.0)
		if tp != Vector2.INF:
			if not _tree(g, tp.x, tp.y, ["sakura", "broad", "maple"][k % 3] if g.climate == "green" else "fir", r.randf_range(0.75, 0.95)):
				_plant(g, tp.x, tp.y, true)
				g.take(tp, 1.0)
	for k in int((8 if big else 4) * _dens(g)):
		var pp = g.spot(lerpf(g.ua + 1.5, g.ub - 1.5, r.randf()), lerpf(g.da + 1.5, g.db - 1.0, r.randf()), 0.9, 0.4, 3.0)
		if pp != Vector2.INF:
			_plant(g, pp.x, pp.y)
			g.take(pp, 0.9)
	var lp = g.spot(end.x, end.y - 2.0, 0.8, 0.3)
	if lp != Vector2.INF:
		_lantern(g, lp.x, lp.y, 1)
	var _o = o


## Hastane: sessiz iyileşme bahçesi — gölet / çeşme, şifalı ot yatakları, banklar, küçük ağaçlar, fenerler
static func _hospital(g: G) -> void:
	var r = g.rng
	var door: Vector2 = g.doors[0] if not g.doors.is_empty() else Vector2(0, 0)
	var big = g.ub - g.ua > 36.0 and g.db - g.da > 14.0
	# merkez: gölet (yeşil / sisli) ya da çeşme (kurak); patikanın yanında
	var wc = g.at(0.3, 0.55)
	var wr = 4.0 if big else 2.2
	var wsp = g.spot(wc.x, wc.y, wr + 0.6, 0.5, 6.0)
	var pond = g.pal["water"] and g.climate != "cloud"
	if wsp != Vector2.INF:
		g.take(wsp, wr + 0.9)
	var sgn = 1.0 if (wsp == Vector2.INF or wsp.x < door.x) else -1.0
	var tg: Array = [Vector2(door.x, door.y + 4.0).lerp(g.at(-0.3 * sgn, 0.3), 0.5)]
	if wsp != Vector2.INF:
		tg.append_array(_arc(wsp, wr + 2.6, 0.0 if sgn > 0.0 else 180.0, 110.0 if sgn > 0.0 else 70.0, 4))
	else:
		tg.append_array([g.at(0.0, 0.5), g.at(0.3, 0.8)])
	var pts = _route(g, door, tg)
	_draw_path(g, pts)
	if wsp != Vector2.INF:
		g.taken.pop_back()
		if pond:
			_pond(g, wsp, wr)
		else:
			_fountain(g, wsp, minf(wr, 2.2))
		# gölete / çeşmeye bakan banklar
		for k in (3 if big else 2):
			var a = PI * (0.25 + k * (0.5 if big else 1.0)) + (PI if k % 2 == 1 and not big else 0.0)
			var bp = g.spot(wsp.x + cos(a) * (wr + 2.2), wsp.y + sin(a) * (wr + 2.2), 1.1, 0.3, 2.0)
			if bp != Vector2.INF:
				_bench(g, bp.x, bp.y, wsp - bp, g.climate in ["desert", "rock", "cloud"])
				g.take(bp, 1.2)
				if g.climate == "desert":
					_shade(g, bp, rad_to_deg(atan2((wsp - bp).y, (wsp - bp).x)) + 90.0, Color(0.85, 0.82, 0.72))
	# şifalı ot yatakları (lavanta, nane, adaçayı)
	var nb = 3 if big else 1
	var hb = g.at(-0.62 * sgn, 0.45)
	for k in nb:
		var bc = g.spot(hb.x, hb.y + (k - (nb - 1) * 0.5) * 3.2, 1.9, 0.4, 4.0)
		if bc != Vector2.INF:
			if g.climate == "desert":
				g.take(bc, 1.8)
				for j in 3:
					_plant(g, bc.x + r.randf_range(-1.4, 1.4), bc.y + r.randf_range(-0.8, 0.8))
			else:
				_bed(g, bc, 3.4, 2.0, "herb")
	# ağaçlar (sakura / akçaağaç — hastalar baharda çiçek görür), fenerler, bitkiler
	for k in (4 if big else 1):
		var tp = g.spot(lerpf(g.ua + 3.0, g.ub - 3.0, r.randf()), lerpf(g.da + 3.0, g.db - 1.5, r.randf()), 2.4, 0.8, 5.0)
		if tp != Vector2.INF:
			if not _tree(g, tp.x, tp.y, ["sakura", "maple", "broad", "sakura"][k] if g.climate == "green" else "fir", r.randf_range(0.7, 0.9)):
				_plant(g, tp.x, tp.y, true)
				g.take(tp, 1.0)
	for k in (3 if big else 1):
		if pts.size() > 4:
			var pv: Vector2 = pts[int(float(pts.size() - 1) * (k + 1) / 4.0)]
			var lp = g.spot(pv.x + 2.2, pv.y, 0.8, 0.3, 2.0)
			if lp != Vector2.INF:
				_lantern(g, lp.x, lp.y, 4 if k % 2 == 1 else 1)
	for k in int((10 if big else 4) * _dens(g)):
		var pp = g.spot(lerpf(g.ua + 1.5, g.ub - 1.5, r.randf()), lerpf(g.da + 1.0, g.db - 1.0, r.randf()), 0.9, 0.4, 3.0)
		if pp != Vector2.INF:
			_plant(g, pp.x, pp.y)
			g.take(pp, 0.9)


## Hokage kulesi: resmi Japon bahçesi (kaiyū) — gölet + kemerli köprü (patika üstünden geçer), taş basamaklar, Kasuga
## fenerleri, çamlar, akçaağaç, tırmıklı çakıl + kaya üçlüsü, budanmış açelya topları
static func _formal(g: G) -> void:
	var r = g.rng
	# gölet: en geniş / derin yer (kapı ortasına yakın)
	var best = Vector2.INF
	var bd = 1e9
	var pr = 5.5
	for k in g.cols:
		var c: Array = g.cols[k]
		var u = k * 2.0
		var dm = (float(c[0]) + float(c[1])) * 0.5
		if float(c[1]) - float(c[0]) < pr * 2.0 + 2.0:
			continue
		if g.site_ok(u, dm, pr + 0.4):
			var score = absf(u - lerpf(g.ua, g.ub, 0.58))
			if score < bd:
				bd = score
				best = Vector2(u, dm)
	if best == Vector2.INF:
		pr = 3.5
		for k in g.cols:
			var c2: Array = g.cols[k]
			var u2 = k * 2.0
			var dm2 = (float(c2[0]) + float(c2[1])) * 0.5
			if g.site_ok(u2, dm2, pr + 0.4) and absf(u2) < bd:
				bd = absf(u2)
				best = Vector2(u2, dm2)
	# patika: iki kapı arasında kıvrılır, gölette köprüden geçer
	var doors = g.doors.duplicate()
	doors.sort_custom(func(p, q): return (p as Vector2).x > (q as Vector2).x)
	var d0: Vector2 = doors[0]
	var tg: Array = []
	if best != Vector2.INF:
		tg = [g.at(lerpf(-1.0, 1.0, inverse_lerp(g.ua, g.ub, d0.x)) - 0.18, 0.7), best + Vector2(pr + 2.5, 0.0), best, best - Vector2(pr + 2.5, 0.0),
			g.at(-0.2, 0.4), g.at(-0.55, 0.65)]
	else:
		tg = [g.at(0.5, 0.6), g.at(0.0, 0.4), g.at(-0.5, 0.65)]
	var pts = _route(g, d0, tg)
	var wy = 0.0
	var bridge_a = Vector2.INF
	var bridge_e = Vector2.INF
	if best != Vector2.INF:
		for v in pts:
			var vv: Vector2 = v
			if vv.distance_to(best) < pr + 0.9:
				if bridge_a == Vector2.INF:
					bridge_a = vv
				bridge_e = vv
		var gaps: Array = []
		if bridge_a != Vector2.INF and bridge_a.distance_to(bridge_e) > pr:
			var dir = (bridge_e - bridge_a).normalized()
			bridge_a -= dir * 0.8
			bridge_e += dir * 0.8
			gaps = [bridge_a, bridge_e]
		else:
			bridge_a = Vector2.INF
		wy = _pond(g, best, pr, gaps)
		if bridge_a != Vector2.INF:
			_bridge(g, bridge_a, bridge_e, wy)
		else:   # patika gölete değmediyse: kıyıdan su üstünde basamak taşları
			for k in 5:
				var sq = g.p(best.x - pr * 0.6 + k * pr * 0.3, best.y + sin(k * 1.3) * 0.6)
				g.b.cyl(Vector3(sq.x, wy + 0.05, sq.y), 0.9, 0.25, g.pal["rock"].lightened(0.15), true, 7)
	_draw_path(g, pts, [[best, pr + 0.4]] if best != Vector2.INF else [])
	if g.doors.size() > 1 and not pts.is_empty():   # öbür kapıdan (arşiv) patikaya
		var d1: Vector2 = doors[doors.size() - 1]
		var near: Vector2 = pts[pts.size() - 1]
		var p2 = _route(g, d1, [Vector2(d1.x, d1.y + 3.0).lerp(near, 0.5), near], false)
		_draw_path(g, p2)
	# kaya üçlüsü + tırmıklı çakıl (sanzon): göletin öbür yanında
	var gs = g.spot(lerpf(g.ua, g.ub, 0.2), g.at(-0.6, 0.5).y, 4.5, 0.6, 8.0)
	if gs != Vector2.INF:
		var gw = minf(12.0, (g.ub - g.ua) * 0.18)
		var gd = minf(7.0, g.span(gs.x).y - g.span(gs.x).x - 2.0)
		if gd > 3.0:
			g.take(gs, maxf(gw, gd) * 0.5 + 0.5)
			_gravel(g, gs, gw, gd)
			_rock_ripple(g, gs + Vector2(-gw * 0.22, 0.2), 1.3)
			_rock_ripple(g, gs + Vector2(gw * 0.05, -gd * 0.18), 0.9)
			_rock_ripple(g, gs + Vector2(gw * 0.3, gd * 0.15), 0.7)
	# Kasuga fenerleri: köprü başları + patika dönemeçleri
	var lpts: Array = []
	if bridge_a != Vector2.INF:
		lpts = [bridge_a + Vector2(0, 2.0), bridge_e - Vector2(0, 2.0)]
	for k in 4:
		if pts.size() > 6:
			lpts.append((pts[int(float(pts.size() - 1) * (k + 0.5) / 4.0)] as Vector2) + Vector2(0, 2.4 * (1 if k % 2 == 0 else -1)))
	for lp in lpts:
		var ls = g.spot(lp.x, lp.y, 0.8, 0.25, 2.0)
		if ls != Vector2.INF:
			_lantern(g, ls.x, ls.y, 4 if ls.distance_to(best) < pr + 3.0 else 1)
	# çamlar (bahçenin iskeleti), bir akçaağaç, budanmış açelya topları
	for k in 5:
		var tp = g.spot(lerpf(g.ua + 3.0, g.ub - 3.0, (k + 0.5) / 5.0 + r.randf_range(-0.06, 0.06)), lerpf(g.da + 3.0, g.db - 2.0, r.randf()), 2.0, 0.8, 4.0)
		if tp != Vector2.INF:
			_tree(g, tp.x, tp.y, ["pine", "pine2", "maple", "pine", "pine2"][k], r.randf_range(0.8, 1.0))
	for k in 18:
		var pp = g.spot(lerpf(g.ua + 1.5, g.ub - 1.5, r.randf()), lerpf(g.da + 1.0, g.db - 1.0, r.randf()), 0.9, 0.3, 3.0)
		if pp != Vector2.INF:
			var q = g.p(pp.x, pp.y)
			var ac = [Color(0.3, 0.54, 0.26), Color(0.86, 0.42, 0.55), Color(0.27, 0.48, 0.24)][k % 3]
			g.b.sphere(Vector3(q.x, g.gy(pp.x, pp.y) + 0.35, q.y), Vector3(1.5, 0.9, 1.3) * r.randf_range(0.8, 1.2), ac, 9)   # karikomi
			g.take(pp, 0.9)


## Hyūga konağı / Naka tapınağı: kuru bahçe (karesansui) — tırmıklı çakıl, kaya grupları + halkalar, yosun tepecikleri,
## bambu çit perdesi, taş fenerler, tsukubai, akçaağaç; tapınakta patika sonunda küçük sunak (hokora)
static func _karesansui(g: G, shrine: bool) -> void:
	var r = g.rng
	var W = g.ub - g.ua
	# çakıl yatağı: en geniş derin bölgede
	var gw = clampf(W * 0.38, 8.0, 18.0)
	var mid = g.at(0.25 if not shrine else 0.0, 0.5)
	var dep = g.span(mid.x)
	var gd = clampf(dep.y - dep.x - 4.0, 4.0, 9.0)
	var gc = g.spot(mid.x, (dep.x + dep.y) * 0.5, maxf(gw, gd) * 0.5 + 0.4, 0.5, 8.0)
	if gc != Vector2.INF:
		g.take(gc, maxf(gw, gd) * 0.5 + 1.4)
	var targets: Array = []
	if gc != Vector2.INF:
		var R = maxf(gw, gd) * 0.5 + 2.9
		var west = g.doors[g.doors.size() - 1].x < gc.x if not g.doors.is_empty() else true
		targets = _arc(gc, R, 215.0 if west else -35.0, 60.0 if west else 120.0, 5)
	else:
		targets = [g.at(0.0, 0.5), g.at(0.4, 0.75)]
	var door: Vector2 = g.doors[0] if not g.doors.is_empty() else Vector2(0, 0)
	if g.doors.size() > 1:
		door = g.doors[1]   # Hyūga: doğu kapısı çakıla yakın
	var pts = _route(g, door, targets)
	_draw_path(g, pts)
	if g.doors.size() > 1:   # batı kapısından yosun bahçesine kısa patika
		var dw: Vector2 = g.doors[0]
		var p2 = _route(g, dw, [g.at(-0.45, 0.4), g.at(-0.7, 0.7)], false)
		_draw_path(g, p2)
	if gc != Vector2.INF:
		g.taken.pop_back()
		g.take(gc, maxf(gw, gd) * 0.5 + 0.4)
		_gravel(g, gc, gw, gd)
		# 7-5-3 kaya grupları
		_rock_ripple(g, gc + Vector2(-gw * 0.28, 0.1 * gd), 1.4)
		_rock_ripple(g, gc + Vector2(-gw * 0.18, -0.22 * gd), 0.7)
		_rock_ripple(g, gc + Vector2(gw * 0.12, 0.18 * gd), 1.0)
		_rock_ripple(g, gc + Vector2(gw * 0.32, -0.15 * gd), 0.8)
		# çakılın arkasında bambu çit perdesi
		var fd = gc.y + gd * 0.5 + 1.2
		if fd < g.db - 0.3 and g.site_ok(gc.x, fd, 0.5):
			_bamboo_fence(g, Vector2(gc.x - gw * 0.5, fd), Vector2(gc.x + gw * 0.5, fd))
	# yosun bahçesi + akçaağaç + fener + tsukubai
	var mz = g.at(-0.55, 0.55)
	for k in 6:
		var mp = g.spot(mz.x + r.randf_range(-5, 5), mz.y + r.randf_range(-3, 3), 1.2, 0.3, 3.0)
		if mp != Vector2.INF:
			_moss(g, mp.x, mp.y, r.randf_range(0.9, 1.5))
			if k % 2 == 0:
				_rock(g, mp.x + 0.6, mp.y - 0.3, r.randf_range(0.5, 0.8), false)
			g.take(mp, 1.1)
	var ts = g.spot(door.x - 3.0, door.y + 5.5, 1.2, 0.3, 3.0)
	if ts != Vector2.INF:
		_tsukubai(g, ts)
		var tl = g.spot(ts.x - 1.6, ts.y + 1.2, 0.8, 0.2, 2.0)
		if tl != Vector2.INF:
			_lantern(g, tl.x, tl.y, 4)
	for k in 3:
		var tp = g.spot(lerpf(g.ua + 3.0, g.ub - 3.0, r.randf()), lerpf(g.da + 3.0, g.db - 1.5, r.randf()), 2.0, 0.8, 5.0)
		if tp != Vector2.INF:
			_tree(g, tp.x, tp.y, ["maple", "pine", "maple"][k], r.randf_range(0.75, 0.95))
	if pts.size() > 4:
		for k in 2:
			var pv: Vector2 = pts[int(float(pts.size() - 1) * (0.35 + k * 0.4))]
			var lp = g.spot(pv.x + (2.2 if k == 0 else -2.2), pv.y, 0.8, 0.25, 2.0)
			if lp != Vector2.INF:
				_lantern(g, lp.x, lp.y, 1)
	# bambu öbeği + yan çitler (bahçeyi kuşatır)
	var bb = g.spot(g.ua + 2.5, g.db - 2.0, 1.2, 0.3, 3.0)
	if bb != Vector2.INF:
		for k in 5:
			var q = g.p(bb.x + r.randf_range(-0.8, 0.8), bb.y + r.randf_range(-0.8, 0.8))
			g.b.prop("bamboo", Vector3(q.x, g.gy(bb.x, bb.y), q.y), r.randf() * 360.0, r.randf_range(6.0, 9.0))
		g.take(bb, 1.4)
	if shrine and not pts.is_empty():   # patika sonunda küçük sunak (hokora), patikaya bakar
		var e: Vector2 = pts[pts.size() - 1]
		var hs = g.spot(e.x, e.y + 2.2, 1.2, 0.0, 2.0)
		if hs != Vector2.INF:
			var q2 = g.p(hs.x, hs.y)
			var fl = g.p(e.x, e.y) - q2
			g.b.pack_mesh(_m("hokora"), Vector3(q2.x, g.gy(hs.x, hs.y), q2.y), rad_to_deg(atan2(fl.x, fl.y)) + 180.0, 1.2, 1.0)
			g.b._collide(g.b.w(Vector3(q2.x, g.gy(hs.x, hs.y) + 0.6, q2.y)), Vector3(1.8, 1.2, 1.5), 0.0)
			g.take(hs, 1.4)
	for k in 6:
		var pp = g.spot(lerpf(g.ua + 1.5, g.ub - 1.5, r.randf()), lerpf(g.da + 1.0, g.db - 1.0, r.randf()), 0.9, 0.3, 3.0)
		if pp != Vector2.INF:
			var q3 = g.p(pp.x, pp.y)
			g.b.sphere(Vector3(q3.x, g.gy(pp.x, pp.y) + 0.3, q3.y), Vector3(1.3, 0.8, 1.1) * r.randf_range(0.8, 1.2), Color(0.28, 0.5, 0.25), 8)
			g.take(pp, 0.9)


## ANBU: gizli antrenman avlusu — koyu çakıl, kara kütükler, hedefler, yüksek koyu tahta perde, tahta kılıç askısı
static func _anbu(g: G) -> void:
	var door: Vector2 = g.doors[0] if not g.doors.is_empty() else Vector2(0, 0)
	var dark_g = Color(0.34, 0.34, 0.36)
	var pts = _route(g, door, [g.at(0.1, 0.5), g.at(-0.3, 0.55), g.at(-0.65, 0.5)], false)
	_draw_path(g, pts)
	# koyu çakıl antrenman zemini
	var pad = g.spot(g.at(0.55, 0.5).x, g.at(0.55, 0.5).y, 2.8, 0.3, 6.0)
	if pad != Vector2.INF:
		var dep = g.span(pad.x)
		_gravel(g, pad, minf(12.0, (g.ub - pad.x) * 2.0 - 1.0), clampf(dep.y - dep.x - 1.0, 3.0, 7.0), false, dark_g)
	var row = g.at(0.45, 0.35)
	for k in 4:
		var sp = g.spot(row.x + k * 2.0, row.y, 0.6, 0.2, 2.0)
		if sp != Vector2.INF:
			_stump(g, sp.x, sp.y, Color(0.16, 0.14, 0.13))
	var tr = g.at(0.6, 0.85)
	for k in 3:
		var t = g.spot(tr.x + (k - 1) * 2.4, tr.y, 0.7, 0.2, 2.0)
		if t != Vector2.INF:
			_target(g, t.x, t.y, Vector2(0, -1), true)
	var rk = g.spot(g.at(-0.2, 0.8).x, g.at(-0.2, 0.8).y, 1.2, 0.3, 4.0)
	if rk != Vector2.INF:
		_rack(g, rk.x, rk.y, 0.0, true)
	# perde: yüksek koyu tahta çit (avluyu batıdan saklar)
	var sx = g.at(-0.05, 0.5).x
	var sp0 = g.span(sx)
	if g.site_ok(sx, (sp0.x + sp0.y) * 0.5, 0.4):
		var a = Vector2(sx, sp0.x + 0.8)
		var e = Vector2(sx, sp0.y - 0.8)
		var L = a.distance_to(e)
		var ok = true
		for s in g.path:
			if Geometry2D.segment_intersects_segment(a, e, s[0], s[1]) != null:
				ok = false
		if ok and L > 2.0:
			var nseg = maxi(1, int(ceil(L / 2.0)))
			for k in nseg:
				var m = a.lerp(e, (k + 0.5) / nseg)
				g.bx(m.x, m.y, 1.1, Vector3(0.12, 2.6, L / nseg + 0.02), Color(0.14, 0.13, 0.13), 0.0, true)
				for j in 3:
					g.bx(m.x + 0.08, m.y, 0.4 + j * 0.8, Vector3(0.06, 0.08, L / nseg), Color(0.24, 0.22, 0.2), 0.0, false)
	var lp = g.spot(door.x + 2.5, door.y + 3.0, 0.8, 0.2, 2.0)
	if lp != Vector2.INF:
		var q = g.p(lp.x, lp.y)
		g.b.lantern_design(q.x, q.y, 1, g.gy(lp.x, lp.y), Color(0.32, 0.32, 0.34), false)
		g.take(lp, 0.8)


## Polis / Kütüphane: okuma avlusu — ince çakıl döşeme, ortada ağaç + çevresinde halka bank (ağaçsız iklimde taş saksı),
## karşılıklı banklar, çiçek kutuları, alçak çit, fener
static func _reading(g: G) -> void:
	var r = g.rng
	var door: Vector2 = g.doors[0] if not g.doors.is_empty() else Vector2(0, 0)
	var cc = g.at(lerpf(-1.0, 1.0, inverse_lerp(g.ua, g.ub, door.x)) * 0.3, 0.55)
	var dep = g.span(cc.x)
	var pw = clampf((g.ub - g.ua) * 0.6, 6.0, 12.0)
	var pd = clampf(dep.y - dep.x - 3.0, 4.0, 9.0)
	var pc = g.spot(cc.x, (dep.x + dep.y) * 0.5 + 0.5, minf(pw, pd) * 0.5, 0.0, 4.0)
	var pe = (pc if pc != Vector2.INF else cc) + Vector2(0.0, -pd * 0.5 + 0.4)
	var pts = _route(g, door, [Vector2(door.x, door.y + 3.0).lerp(pe, 0.5), pe])
	_draw_path(g, pts)
	if pc == Vector2.INF:
		pc = cc
	else:
		_gravel(g, pc, pw, pd, false, Color(0.86, 0.82, 0.72))
		g.take(pc, 1.6)
	# ortada ağaç + halka bank
	var cq = g.p(pc.x, pc.y)
	var cy = g.gy(pc.x, pc.y)
	if _tree(g, pc.x, pc.y, "broad" if g.climate == "green" else "fir", 0.8):
		for k in 8:
			var a = k * TAU / 8.0
			var bq = g.p(pc.x + cos(a) * 1.5, pc.y + sin(a) * 1.5)
			g.b.box(Vector3(bq.x, cy + 0.45, bq.y), Vector3(1.25, 0.08, 0.5), g.pal["wood"], g.yaw_z(rad_to_deg(a)), false)
			g.b.box(Vector3(bq.x, cy + 0.22, bq.y), Vector3(0.1, 0.44, 0.4), g.pal["wood"].darkened(0.3), g.yaw_z(rad_to_deg(a)), false)
		g.b._collide(g.b.w(Vector3(cq.x, cy + 0.25, cq.y)), Vector3(3.4, 0.5, 3.4), -g.face)
	else:
		g.b.cyl(Vector3(cq.x, cy + 0.35, cq.y), 2.4, 0.7, g.pal["rock"].lightened(0.15), true, 10)
		g.b.sphere(Vector3(cq.x, cy + 1.0, cq.y), Vector3(1.9, 1.1, 1.9), Color(0.32, 0.52, 0.28), 9)
		g.take(pc, 1.4)
	# karşılıklı banklar (ağaca bakar)
	for sxx in [-1.0, 1.0]:
		var bp = g.spot(pc.x + sxx * (pw * 0.5 - 1.0), pc.y, 1.0, 0.2, 1.5)
		if bp != Vector2.INF:
			_bench(g, bp.x, bp.y, pc - bp, g.climate in ["desert", "rock", "cloud"])
			g.take(bp, 1.1)
	# avlu kenarında çiçek kutuları + alçak çit
	for k in 6:
		var a = k * TAU / 6.0 + 0.4
		var fp = g.spot(pc.x + cos(a) * (pw * 0.5 + 1.2), pc.y + sin(a) * (pd * 0.5 + 1.0), 0.8, 0.3, 1.5)
		if fp != Vector2.INF:
			if g.climate in ["green", "mist"]:
				_pack(g, ["planter_w", "planter_y", "hedge"][k % 3], fp.x, fp.y, g.yaw_x(rad_to_deg(a) + 90.0))
			else:
				_plant(g, fp.x, fp.y)
			g.take(fp, 0.9)
	var lp = g.spot(pc.x + pw * 0.5 + 1.6, pc.y + pd * 0.5, 0.8, 0.3, 2.5)
	if lp != Vector2.INF:
		_lantern(g, lp.x, lp.y, 1)
	for k in 5:
		var pp = g.spot(lerpf(g.ua + 1.5, g.ub - 1.5, r.randf()), lerpf(g.da + 1.0, g.db - 1.0, r.randf()), 0.9, 0.3, 3.0)
		if pp != Vector2.INF:
			_plant(g, pp.x, pp.y)
			g.take(pp, 0.9)
	for k in 2:
		var tp = g.spot(lerpf(g.ua + 3.0, g.ub - 3.0, r.randf()), lerpf(g.da + 3.0, g.db - 1.5, r.randf()), 2.2, 0.8, 5.0)
		if tp != Vector2.INF:
			_tree(g, tp.x, tp.y, ["sakura", "maple"][k] if g.climate == "green" else "fir", r.randf_range(0.7, 0.85))


## Diğer köylerin Kage binaları: iklime göre resmi bahçe
## Suna: alçak kumtaşı duvarlı kum avlu, tırmıklı kum + kaya, sukulent / kaktüs / küp, gölgelikli taş bank
## Kiri: yosunlu gölet + ıslak basamak taşları, eğrelti, köknar, yosunlu fenerler
## Kumo: kaya bahçesi (gri kayalar, çakıl, bodur çalı), taş fener, taş bank
## Iwa: taş bahçe (kaya teras, taş yığınları, kuru çakıl, bodur ot)
static func _kage(g: G) -> void:
	var r = g.rng
	var door: Vector2 = g.doors[0] if not g.doors.is_empty() else Vector2(0, 0)
	var W = g.ub - g.ua
	var gw = clampf(W * 0.35, 7.0, 14.0)
	var mid = g.at(0.35, 0.5)
	var dep = g.span(mid.x)
	var gd = clampf(dep.y - dep.x - 4.0, 4.0, 9.0)
	var feat = Vector2.INF
	if g.climate == "mist":   # gölet
		feat = g.spot(mid.x, (dep.x + dep.y) * 0.5, 5.0, 0.5, 8.0)
	else:
		feat = g.spot(mid.x, (dep.x + dep.y) * 0.5, maxf(gw, gd) * 0.5 + 0.4, 0.5, 8.0)
	if feat != Vector2.INF:
		g.take(feat, (4.6 if g.climate == "mist" else maxf(gw, gd) * 0.5) + 1.6)
	var tg: Array = []
	if feat != Vector2.INF:
		var R = (4.6 if g.climate == "mist" else maxf(gw, gd) * 0.5) + 3.1
		var west = door.x < feat.x
		tg = _arc(feat, R, 215.0 if west else -35.0, 70.0 if west else 110.0, 5)
	else:
		tg = [g.at(-0.2, 0.35), g.at(0.3, 0.7)]
	var pts = _route(g, door, tg)
	_draw_path(g, pts)
	if feat != Vector2.INF:
		g.taken.pop_back()
		match g.climate:
			"mist":
				var wy = _pond(g, feat, 4.0)
				for k in 4:   # gölette ıslak basamak taşları
					var sq = g.p(feat.x - 2.4 + k * 1.5, feat.y - 1.0 + sin(k * 1.7) * 0.7)
					g.b.cyl(Vector3(sq.x, wy + 0.06, sq.y), 0.85, 0.3, Color(0.34, 0.38, 0.4), true, 7)
				for k in 5:
					var a = k * TAU / 5.0 + 0.3
					var mp = g.spot(feat.x + cos(a) * 6.0, feat.y + sin(a) * 6.0, 1.0, 0.3, 2.0)
					if mp != Vector2.INF:
						_moss(g, mp.x, mp.y, r.randf_range(1.0, 1.5))
						_pack(g, "veg10", mp.x + 0.6, mp.y, r.randf() * 360.0, 0.45)
						g.take(mp, 1.0)
			"desert":
				_gravel(g, feat, gw, gd, true)
				_rock_ripple(g, feat + Vector2(-gw * 0.25, 0.0), 1.2)
				_rock_ripple(g, feat + Vector2(gw * 0.2, gd * 0.15), 0.8)
				g.take(feat, maxf(gw, gd) * 0.5 + 0.3)
				# alçak kumtaşı avlu duvarı (U: duvarın karşısı ve yanları)
				var wc: Color = g.pal["rock"].lightened(0.1)
				var y0 = feat.y + gd * 0.5 + 1.6
				for seg in [[Vector2(feat.x - gw * 0.5 - 1.6, y0), Vector2(feat.x + gw * 0.5 + 1.6, y0)],
						[Vector2(feat.x + gw * 0.5 + 1.6, feat.y - gd * 0.5), Vector2(feat.x + gw * 0.5 + 1.6, y0)]]:
					var ok = true
					for k in 5:
						var m = (seg[0] as Vector2).lerp(seg[1], k / 4.0)
						if not g.site_ok(m.x, m.y, 0.4):
							ok = false
					for s in g.path:
						if Geometry2D.segment_intersects_segment(seg[0], seg[1], s[0], s[1]) != null:
							ok = false
					if ok:
						_low_wall(g, seg[0], seg[1], wc)
			"cloud":
				_gravel(g, feat, gw, gd, true)
				_rock_ripple(g, feat + Vector2(-gw * 0.28, 0.1), 1.6, false)
				_rock_ripple(g, feat + Vector2(-gw * 0.05, -gd * 0.2), 1.0, false)
				_rock_ripple(g, feat + Vector2(gw * 0.25, gd * 0.1), 1.3, false)
				g.take(feat, maxf(gw, gd) * 0.5 + 0.3)
			_:
				_gravel(g, feat, gw, gd, false)
				_terrace(g, feat + Vector2(-gw * 0.2, 0.0), gw * 0.35, gd * 0.5)
				_cairn(g, feat + Vector2(gw * 0.3, gd * 0.2))
				_cairn(g, feat + Vector2(gw * 0.15, -gd * 0.25))
				g.take(feat, maxf(gw, gd) * 0.5 + 0.3)
	# bank (iklime göre taş / ahşap; Suna'da gölgelikli), fenerler, bitkiler, ağaç (iklim izin verirse)
	if not pts.is_empty():
		var e: Vector2 = pts[pts.size() - 1]
		var bp = g.spot(e.x + 1.8, e.y + 0.5, 1.1, 0.2, 2.5)
		if bp != Vector2.INF:
			_bench(g, bp.x, bp.y, (feat if feat != Vector2.INF else g.at(0, 0.5)) - bp, g.climate != "mist")
			g.take(bp, 1.2)
			if g.climate == "desert":
				_shade(g, bp, 0.0, Color(0.16, 0.45, 0.38))
	if pts.size() > 4:
		for k in 2:
			var pv: Vector2 = pts[int(float(pts.size() - 1) * (0.3 + k * 0.45))]
			var lp = g.spot(pv.x + (2.0 if k == 0 else -2.0), pv.y, 0.8, 0.25, 2.0)
			if lp != Vector2.INF:
				_lantern(g, lp.x, lp.y, 1)
	for k in 3:
		var tp = g.spot(lerpf(g.ua + 3.0, g.ub - 3.0, r.randf()), lerpf(g.da + 3.0, g.db - 1.5, r.randf()), 2.0, 0.8, 5.0)
		if tp != Vector2.INF:
			if not _tree(g, tp.x, tp.y, "fir" if k != 1 else "pine", r.randf_range(0.8, 1.0)):
				if g.climate == "cloud" or g.climate == "rock":
					_rock(g, tp.x, tp.y, r.randf_range(1.0, 1.6), g.climate == "cloud")
				else:
					_plant(g, tp.x, tp.y, true)
				g.take(tp, 1.4)
	for k in int(10 * _dens(g)):
		var pp = g.spot(lerpf(g.ua + 1.5, g.ub - 1.5, r.randf()), lerpf(g.da + 1.0, g.db - 1.0, r.randf()), 0.9, 0.3, 3.0)
		if pp != Vector2.INF:
			_plant(g, pp.x, pp.y)
			g.take(pp, 0.9)
	if g.climate == "mist":
		var bb = g.spot(g.ub - 2.5, g.db - 2.0, 1.2, 0.3, 3.0)
		if bb != Vector2.INF:
			for k in 5:
				var q = g.p(bb.x + r.randf_range(-0.8, 0.8), bb.y + r.randf_range(-0.8, 0.8))
				g.b.prop("bamboo", Vector3(q.x, g.gy(bb.x, bb.y), q.y), r.randf() * 360.0, r.randf_range(6.0, 9.0))
