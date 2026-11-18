extends RefCounted
## Sırt / bel eşyaları yeniden yapımı, grup c (sirt_033 … tespih). Hedef: res://scripts/actors/back_v2_c.gd
## Tüm parçalar bağlandığı kemiğin dinlenme konumuna göre (UpperChest ya da Hips) kurulur; +Z ön, -Z sırt, +X karakterin solu.
## Kayış ve halkalar gövde köşelerinden ölçülen yüzeyi izler (Body). Yelek / pelerin varsa pay eklenir.
## Kaynak görseller: refs/shuriken, refs/chakra_bicaklari, refs/tespih, refs/savas_cekici, refs/tilki_maske_bel, refs/nuno, refs/yumi, refs/kus_kafesi.

const KINDS := ["manriki", "ikiz_kabak", "furoshiki", "harita_tupu", "kus_kafesi", "puskullu_kilic", "kunai_yelpaze", "sirt_plakasi",
	"dis_kolye", "can_kemeri", "ikiz_kama", "sadak", "savas_cekici", "tilki_maske_bel", "murekkep_kutusu", "chakra_bicaklari",
	"zincir_bel", "bambu_matara", "nuno_maki", "canta", "sepet", "shuriken", "tespih"]
const ON_HIP := ["manriki", "ikiz_kabak", "can_kemeri", "ikiz_kama", "tilki_maske_bel", "murekkep_kutusu", "chakra_bicaklari", "zincir_bel", "bambu_matara"]

const STEEL := Color(0.66, 0.68, 0.72)
const STEEL_L := Color(0.86, 0.88, 0.9)
const IRON := Color(0.2, 0.21, 0.24)
const BRASS := Color(0.72, 0.56, 0.26)
const LEATHER := Color(0.34, 0.22, 0.13)
const LEATHER_D := Color(0.2, 0.13, 0.09)
const WOOD := Color(0.46, 0.32, 0.19)
const WOOD_D := Color(0.27, 0.18, 0.11)
const ROPE := Color(0.68, 0.57, 0.4)
const PAPER := Color(0.92, 0.88, 0.77)
const BLACK := Color(0.07, 0.07, 0.08)
const RED := Color(0.66, 0.13, 0.12)
const TOXY := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))

static var _tabs := {}


## Gövde yüzeyi: dinlenme köşelerinden 2 cm'lik yükseklik dilimleri
class Body:
	var t: Dictionary
	var o: Vector3
	var pad: float
	var ny: float

	func _init(tab: Dictionary, origin: Vector3, p: float, neck: float) -> void:
		t = tab
		o = origin
		pad = p
		ny = neck - origin.y

	func _g(d: Dictionary, y: float, sg: float, df: float) -> float:
		var iy = int(floor(y / 0.02))
		var found = false
		var best = df
		for k in range(iy - 2, iy + 3):
			if d.has(k):
				var v = float(d[k])
				if not found or v * sg > best * sg:
					best = v
					found = true
		return best

	func back(y: float) -> float:
		return _g(t["b"], y + o.y, -1.0, -0.11) - o.z - pad

	func front(y: float) -> float:
		return _g(t["f"], y + o.y, 1.0, 0.11) - o.z + pad

	func half(y: float) -> float:
		return minf(_g(t["h"], y + o.y, 1.0, 0.16), 0.2) + pad

	## x hizasında omuzun üstü
	func top(x: float) -> float:
		var d: Dictionary = t["t"]
		var ix = int(absf(x) / 0.01)
		var best = -99.0
		for k in range(ix - 1, ix + 2):
			if d.has(k):
				best = maxf(best, float(d[k]))
		if best < -90.0:
			return ny - 0.03 + pad
		return best - o.y + pad

	## a: 0 sırt ortası, PI/2 sol yan (+X), PI ön; off kadar dışarıda
	func around(a: float, y: float, off := 0.0) -> Vector3:
		var s = sin(a)
		var c = cos(a)
		var sx = signf(s) * pow(absf(s), 0.75)
		var cz = signf(c) * pow(absf(c), 0.75)
		var z = (back(y) - off) * cz if cz >= 0.0 else (front(y) + off) * -cz
		return Vector3((half(y) + off) * sx, y, z)


static func _tab(m) -> Dictionary:
	var empty = {"f": {}, "b": {}, "h": {}, "t": {}}
	if m.body_mesh == null or m.body_mesh.mesh == null:
		return empty
	var vs: PackedVector3Array = m._body_vs()
	var key = "%s|%d" % [str(m.look.get("gender", "m")), vs.size()]
	if _tabs.has(key):
		return _tabs[key]
	var ny = float(m._bp("Neck").y)
	var f = {}
	var bk = {}
	var h = {}
	var tp = {}
	for v in vs:
		var ax = absf(v.x)
		if ax > 0.25:
			continue
		var iy = int(floor(v.y / 0.02))
		if ax < 0.09:
			if not f.has(iy) or v.z > f[iy]:
				f[iy] = v.z
			if not bk.has(iy) or v.z < bk[iy]:
				bk[iy] = v.z
		if absf(v.z) < 0.08:
			if not h.has(iy) or ax > h[iy]:
				h[iy] = ax
			if v.y < ny + 0.03 and v.y > ny - 0.3:
				var ix = int(ax / 0.01)
				if not tp.has(ix) or v.y > tp[ix]:
					tp[ix] = v.y
	var out = {"f": f, "b": bk, "h": h, "t": tp}
	_tabs[key] = out
	return out


static func build(m, kind: String, bc: Color, ch: Vector3, hip: Vector3, toon: Material) -> bool:
	var mb = MB.new()
	var on_hip = kind in ON_HIP
	var o: Vector3 = hip if on_hip else ch
	var bone = "Hips" if on_hip else "UpperChest"
	var pad = 0.024 if on_hip else 0.008   # bel: gömlek eteği ve karakterin kendi kemeri içinde kalmasın
	if m.look.get("vest") != null and not on_hip:
		pad += 0.042
	if m.look.get("outer_style") != null and str(m.look.get("outer_style")) != "":
		pad += 0.028
	var b = Body.new(_tab(m), o, pad, float(m._bp("Neck").y))
	var d = {"m": m, "bone": bone, "o": o}
	match kind:
		"manriki": _manriki(mb, b, bc, d)
		"ikiz_kabak": _ikiz_kabak(mb, b, bc, d)
		"furoshiki": _furoshiki(mb, b, bc, d)
		"harita_tupu": _harita(mb, b, bc)
		"kus_kafesi": _kafes(mb, b, bc, d)
		"puskullu_kilic": _kilic(mb, b, bc, d)
		"kunai_yelpaze": _kunai_yelpaze(mb, b, bc)
		"sirt_plakasi": _plaka(mb, b, bc)
		"dis_kolye": _dis_kolye(mb, b, bc, d)
		"can_kemeri": _can_kemeri(mb, b, bc, d)
		"ikiz_kama": _ikiz_kama(mb, b, bc, d)
		"sadak": _sadak(mb, b, bc)
		"savas_cekici": _cekic(mb, b, bc, d)
		"tilki_maske_bel": _maske(mb, b, bc, d)
		"murekkep_kutusu": _yatate(mb, b, bc, d)
		"chakra_bicaklari": _chakra(mb, b, bc)
		"zincir_bel": _zincir(mb, b, bc, d)
		"bambu_matara": _bambu(mb, b, bc, d)
		"nuno_maki": _nuno(mb, b, bc, d)
		"canta": _canta(mb, b, bc, d)
		"sepet": _sepet(mb, b, bc)
		"shuriken": _fuma(mb, b, bc)
		"tespih": _tespih(mb, b, bc, d)
		_:
			return false
	m._mesh_on(bone, mb.build(toon), Transform3D(Basis.IDENTITY, o))
	return true


# ------------------------------------------------------------------ yardımcılar
static func _p(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


static func _dang(d: Dictionary, p: Vector3, dir: Vector3, length: float, w: float, col: Color, stiff := 0.2, thick := 0.004, taper := 0.35) -> void:
	d["m"].dangle_strip(d["bone"], d["o"] + p, dir, length, w, col, stiff, Vector3.ZERO, thick, null, taper)


static func _perp(y: Vector3, hint := Vector3.BACK) -> Vector3:
	var z = hint - y * hint.dot(y)
	if z.length() < 0.05:
		z = Vector3.RIGHT - y * y.x
	return z.normalized()


## a'dan b'ye kutu; n geniş olmayan yüzün yönü
static func _seg(mb, a: Vector3, b: Vector3, w: float, h: float, col: Color, n := Vector3.BACK) -> void:
	var dv = b - a
	var L = dv.length()
	if L < 0.0005:
		return
	var y = dv / L
	var z = _perp(y, n)
	var x = y.cross(z)
	mb.add_xf("box", Transform3D(Basis(x * w, y * L * 1.08, z * h), (a + b) * 0.5), col)


static func _rod(mb, a: Vector3, b: Vector3, r: float, col: Color, seg := 6) -> void:
	var dv = b - a
	var L = dv.length()
	if L < 0.0005:
		return
	var y = dv / L
	var z = _perp(y)
	var x = y.cross(z)
	mb.add_xf("cyl", Transform3D(Basis(x * r * 2.0, y * L, z * r * 2.0), (a + b) * 0.5), col, seg)


## a tabanlı, b sivri koni
static func _cone(mb, a: Vector3, b: Vector3, r: float, col: Color, seg := 5) -> void:
	var dv = b - a
	var L = dv.length()
	if L < 0.0005:
		return
	var y = dv / L
	var z = _perp(y)
	var x = y.cross(z)
	mb.add_xf("cone", Transform3D(Basis(x * r * 2.0, y * L, z * r * 2.0), (a + b) * 0.5), col, seg)


## Eksen boyunca profil: Vector2(t, yarıçap) ya da Vector3(t, yan, dikey)
static func _prof(mb, a: Vector3, b: Vector3, prof: Array, col, seg := 10, sub := 2, cap_a := true, cap_b := true, fn := Callable(), up := Vector3.UP) -> void:
	var pts = []
	var rad = []
	for q in prof:
		pts.append(a.lerp(b, q.x))
		rad.append(Vector2(q.y, q.z) if q is Vector3 else q.y)
	Loft.tube(mb, pts, rad, col, seg, sub, cap_a, cap_b, fn, up)


static func _smooth(pts: Array, closed: bool, sub: int) -> Array:
	var n = pts.size()
	var out = []
	var last = n if closed else n - 1
	for i in last:
		var p0 = pts[(i - 1 + n) % n] if closed or i > 0 else pts[0]
		var p1 = pts[i]
		var p2 = pts[(i + 1) % n]
		var p3 = pts[(i + 2) % n] if closed or i + 2 < n else pts[n - 1]
		for s in sub:
			out.append(Loft._cr(p0, p1, p2, p3, float(s) / sub))
	if closed:
		out.append(out[0])
	else:
		out.append(pts[n - 1])
	return out


## Yüzeyi izleyen yassı kayış; st verilirse dikiş çizgisi
static func _band(mb, pts: Array, w: float, t: float, col: Color, closed := false, sub := 3, st = null) -> void:
	var q = _smooth(pts, closed, sub)
	for i in q.size() - 1:
		var a: Vector3 = q[i]
		var c: Vector3 = q[i + 1]
		var mid = (a + c) * 0.5
		var out = mid - Vector3(0, mid.y - 0.1, 0)
		var d = (c - a).normalized()
		var s = d.cross(out).normalized()
		var n = s.cross(d).normalized()
		mb.add_xf("box", Transform3D(Basis(s * w, (c - a) * 1.1, n * t), mid), col)
		if st != null and i % 2 == 0:
			var e = s * w * (0.36 if i % 4 == 0 else -0.36) + n * t * 0.55
			_seg(mb, a.lerp(c, 0.2) + e, a.lerp(c, 0.8) + e, 0.003, 0.002, st, n)


static func _cord(mb, pts: Array, r: float, col: Color, closed := false, sub := 3) -> void:
	var q = _smooth(pts, closed, sub)
	for i in q.size() - 1:
		_seg(mb, q[i], q[i + 1], r * 2.0, r * 2.0, col, Vector3(0.5, 0.3, 0.8))


static func _ring(mb, c: Vector3, axis: Vector3, R: float, r: float, col: Color, n := 10) -> void:
	var y = axis.normalized()
	var u = _perp(y)
	var v = y.cross(u)
	for k in n:
		var a0 = TAU * k / n
		var a1 = TAU * (k + 1) / n
		var e0 = u * cos(a0) + v * sin(a0)
		var e1 = u * cos(a1) + v * sin(a1)
		_seg(mb, c + e0 * R, c + e1 * R, r * 2.0, r * 2.0, col, e0 + e1)


## Zincir baklası: dört çubuklu halka
static func _link(mb, c: Vector3, d: Vector3, n: Vector3, L: float, W: float, r: float, col: Color) -> void:
	var y = d.normalized()
	var s = y.cross(n).normalized()
	var ax = y * L * 0.5
	var sx = s * W * 0.5
	_seg(mb, c - ax - sx, c + ax - sx, r * 2.0, r * 2.0, col, n)
	_seg(mb, c - ax + sx, c + ax + sx, r * 2.0, r * 2.0, col, n)
	_seg(mb, c - ax - sx, c - ax + sx, r * 2.0, r * 2.0, col, n)
	_seg(mb, c + ax - sx, c + ax + sx, r * 2.0, r * 2.0, col, n)


## Düz taban: Y eksenli eliptik disk
static func _disc_y(mb, c: Vector3, rx: float, rz: float, h: float, col: Color, seg := 14) -> void:
	mb.add_xf("cyl", Transform3D(Basis(Vector3.RIGHT * rx * 2.0, Vector3.UP * h, Vector3.BACK * rz * 2.0), c), col, seg)


## Vector3(t, yan, dikey) profilinde t noktasındaki yarıçaplar
static func _prof_at(pr: Array, t: float) -> Vector2:
	for i in pr.size() - 1:
		var a: Vector3 = pr[i]
		var c: Vector3 = pr[i + 1]
		if t <= c.x:
			var k = clampf((t - a.x) / maxf(c.x - a.x, 0.0001), 0.0, 1.0)
			return Vector2(lerpf(a.y, c.y, k), lerpf(a.z, c.z, k))
	var e: Vector3 = pr[pr.size() - 1]
	return Vector2(e.y, e.z)


## p merkezli, Y ve Z yönleri verilen çerçeve
static func _frame(p: Vector3, y: Vector3, z: Vector3) -> Transform3D:
	var yy = y.normalized()
	var zz = _perp(yy, z)
	return Transform3D(Basis(yy.cross(zz), yy, zz), p)


## Çerçevenin XY düzleminde profil plaka (kalınlık Z boyunca)
static func _plate(mb, pts: Array, t: float, col: Color, xf: Transform3D) -> void:
	var o = PackedVector2Array()
	for q in pts:
		o.append(Vector2(q.y, -q.x))
	mb.add_slab(o, t, col, xf * Transform3D(TOXY, Vector3.ZERO))


static func _rivet(mb, p: Vector3, n: Vector3, r: float, col: Color) -> void:
	_rod(mb, p, p + n.normalized() * r * 0.7, r, col, 5)


static func _buckle(mb, p: Vector3, n: Vector3, up: Vector3, col := BRASS) -> void:
	var y = up.normalized()
	var nn = _perp(y, n)
	_link(mb, p + nn * 0.004, y, nn, 0.04, 0.03, 0.0028, col)
	var s = y.cross(nn).normalized()
	_seg(mb, p + nn * 0.006 - s * 0.015, p + nn * 0.006 + s * 0.015, 0.004, 0.004, col, nn)


static func _belt(mb, b, y: float, w: float, col: Color, st = null, n := 16, off := 0.0) -> void:
	var pts = []
	for k in n:
		pts.append(b.around(TAU * k / n, y, off))
	_band(mb, pts, w, 0.008, col, true, 2, st)


## Bir omuzdan karşı böğre çapraz kayış
static func _sash(mb, b, s: float, w: float, col: Color, st = null) -> void:
	var y0 = b.top(0.11)
	var pts = [_p(s * 0.115, y0, 0.0),
		_p(s * 0.085, y0 - 0.08, b.front(y0 - 0.08) * 0.92),
		_p(s * -0.01, y0 - 0.17, b.front(y0 - 0.17)),
		_p(s * -0.11, y0 - 0.26, b.front(y0 - 0.26) * 0.92),
		_p(-s * b.half(y0 - 0.31), y0 - 0.31, 0.0),
		_p(s * -0.1, y0 - 0.27, b.back(y0 - 0.27) * 0.95),
		_p(s * 0.02, y0 - 0.18, b.back(y0 - 0.18)),
		_p(s * 0.09, y0 - 0.09, b.back(y0 - 0.09) * 0.95)]
	_band(mb, pts, w, 0.006, col, true, 3, st)


## Sırt çantası askıları: omuzdan öne, koltuk altından alt bağlantıya
static func _straps(mb, b, y_top: float, y_low: float, x_top: float, x_low: float, w: float, col: Color, chest := true) -> void:
	var y0 = b.top(0.11)
	var yl = maxf(y_low, -0.16)   # koşuda gövde bükülür: askı ucu bel hizasına inerse sırttan açılır
	for s in [-1.0, 1.0]:
		var pts = [_p(s * x_top, y_top, b.back(y_top)),
			_p(s * 0.1, y0 - 0.05, b.back(y0 - 0.05) * 0.82),
			_p(s * 0.115, y0, 0.0),
			_p(s * 0.105, y0 - 0.07, b.front(y0 - 0.07) * 0.88),
			_p(s * 0.125, y0 - 0.2, b.front(y0 - 0.2) * 0.96),
			_p(s * b.half(y0 - 0.28), y0 - 0.28, 0.01),
			_p(s * x_low, yl, b.back(yl))]
		_band(mb, pts, w, 0.006, col, false, 3)
		_buckle(mb, _p(s * 0.122, y0 - 0.17, b.front(y0 - 0.17) * 0.96 + 0.005), Vector3.BACK, Vector3.UP)
	if chest:
		var y = y0 - 0.17
		var f = b.front(y) + 0.003
		_seg(mb, _p(-0.12, y, f * 0.96), _p(0.0, y, f), 0.016, 0.004, col)
		_seg(mb, _p(0.0, y, f), _p(0.12, y, f * 0.96), 0.016, 0.004, col)
		_rod(mb, _p(0, y, f), _p(0, y, f + 0.008), 0.014, BRASS, 8)


# ------------------------------------------------------------------ eşyalar
## Manrikigusari: belde yan tarafta sarılı zincir, iki uçta ağırlık (gerçek silah)
static func _manriki(mb, b, bc: Color, d: Dictionary) -> void:
	var y = 0.07
	_belt(mb, b, y, 0.036, bc.darkened(0.15), LEATHER_D)
	var ang = -0.82
	var c = b.around(ang, -0.05, 0.035)
	var out = Vector3(c.x, 0, c.z * 0.8).normalized()
	var u = Vector3.UP
	var v = out.cross(u).normalized()
	for L in 2:
		var R = 0.098 - L * 0.012
		for k in 12:
			var a = TAU * (k + L * 0.5) / 12.0
			var e = u * cos(a) + v * sin(a) * 0.86
			var p = c + out * (L * 0.013) + e * R
			var t = -u * sin(a) + v * cos(a) * 0.86
			var n = out if k % 2 == 0 else e
			_link(mb, p, t, n, 0.052, 0.026, 0.0042, STEEL if k % 3 else STEEL.darkened(0.2))
	var top = c + u * 0.1
	var bt = b.around(ang, y, 0.006)
	_band(mb, [bt, top + out * 0.008], 0.024, 0.005, bc, false, 1)
	_ring(mb, top + out * 0.007, v, 0.018, 0.0042, bc.darkened(0.3), 8)
	var q = c - u * 0.1 + out * 0.012
	_link(mb, q - u * 0.022, u, out, 0.03, 0.017, 0.0034, STEEL)
	_rod(mb, q - u * 0.036, q - u * 0.098, 0.017, IRON, 6)
	_rod(mb, c - v * 0.042 + out * 0.016, c + v * 0.036 + out * 0.016, 0.015, IRON, 6)
	_dang(d, top + out * 0.014 - u * 0.004, out * 0.1 + Vector3.DOWN, 0.13, 0.016, bc, 0.25)


static func _gourd(mb, top: Vector3, dir: Vector3, L: float, cord: Color) -> void:
	var y = dir.normalized()
	var A = Color(0.76, 0.58, 0.28)
	var B = Color(0.6, 0.4, 0.17)
	var bot = top + y * L
	_prof(mb, top, bot, [Vector2(0, 0.014), Vector2(0.12, 0.017), Vector2(0.25, 0.033), Vector2(0.36, 0.024), Vector2(0.5, 0.044), Vector2(0.72, 0.056), Vector2(0.92, 0.038), Vector2(1, 0.012)],
		[A, A, A, B, A, A, B, B], 10, 2)
	_rod(mb, top - y * 0.024, top + y * 0.004, 0.0125, Color(0.72, 0.6, 0.42), 6)
	_ring(mb, top.lerp(bot, 0.36), y, 0.026, 0.0035, cord, 9)
	_ring(mb, top.lerp(bot, 0.355) + y * 0.007, y, 0.026, 0.0035, cord, 9)


## İkiz kabak: bele iple asılı iki matara, sol arka kalçada
static func _ikiz_kabak(mb, b, bc: Color, d: Dictionary) -> void:
	_belt(mb, b, 0.075, 0.024, LEATHER, LEATHER_D)
	var cord = bc.lightened(0.12)
	for s in [0, 1]:
		var a = 0.5 + s * 0.42
		var hook = b.around(a, 0.075, 0.006)
		var top = b.around(a, -0.035, 0.05 + s * 0.006)
		var dir = (b.around(a + 0.05 - s * 0.1, -0.2, 0.05) - top).normalized()
		var L = 0.2 - s * 0.022
		_gourd(mb, top, dir, L, cord)
		var w = top + dir * L * 0.36
		_cord(mb, [hook, hook.lerp(w, 0.45) + _p(0, 0, -0.016), w + _p(0, 0.012, -0.024)], 0.0035, cord, false, 3)
		_cord(mb, [hook + _p(0.008, 0, 0), top + _p(0.012, 0.03, -0.012), top + _p(0.006, -0.002, -0.012)], 0.0025, cord, false, 2)
		_ring(mb, hook, Vector3.UP, 0.016, 0.0028, BRASS, 7)
	var h2 = b.around(0.5, 0.06, 0.012)
	_dang(d, h2, _p(-0.05, -1, -0.1), 0.11, 0.009, cord, 0.25)


## Furoshiki: arabesk desenli kumaş bohça, uçları göğüste düğümlü
static func _furoshiki(mb, b, bc: Color, d: Dictionary) -> void:
	var y = -0.07
	var z = b.back(y) - 0.125
	var A = _p(-0.165, y, z)
	var C = _p(0.165, y, z)
	var pr = [Vector3(0, 0.07, 0.075), Vector3(0.1, 0.112, 0.125), Vector3(0.35, 0.13, 0.15), Vector3(0.65, 0.13, 0.15), Vector3(0.9, 0.112, 0.125), Vector3(1, 0.07, 0.075)]
	_prof(mb, A, C, pr, bc, 16, 3)
	var hi = bc.lightened(0.62)
	var deep = bc.darkened(0.28)
	var surf = func(t: float, ang: float, lift: float) -> Vector3:
		var r = _prof_at(pr, t)
		return A.lerp(C, t) + _p(0, sin(ang) * (r.y + lift), -cos(ang) * (r.x + lift))
	for i in 8:   # karakusa kıvrımları kumaşın yüzünde
		var t0 = 0.16 + (i % 4) * 0.225
		var a0 = -0.75 + floorf(i / 4.0) * 1.0 + (i % 2) * 0.28
		var q = []
		for k in 9:
			var th = k * 0.85
			var r = 0.008 + k * 0.0062
			q.append(surf.call(t0 + cos(th) * r / 0.33, a0 + sin(th) * r / 0.135, 0.002))
		for k in 8:
			_seg(mb, q[k], q[k + 1], 0.0052, 0.002, hi, (q[k] as Vector3) - A.lerp(C, t0))
	for i in 4:   # bağa doğru toplanan katlar
		var t0 = 0.3 + i * 0.133
		var q = []
		for k in 5:
			q.append(surf.call(lerpf(0.5 + (t0 - 0.5) * 0.45, t0, k / 4.0), lerpf(1.42, 0.55, k / 4.0), 0.0015))
		for k in 4:
			_seg(mb, q[k], q[k + 1], 0.006, 0.002, deep, (q[k] as Vector3) - A.lerp(C, t0))
	var y0 = b.top(0.11)
	var ky = y0 - 0.15
	var knot = _p(0.0, ky, b.front(ky) + 0.026)
	for s in [-1.0, 1.0]:
		var over = [surf.call(0.5 + s * 0.2, 1.25, 0.004), _p(s * 0.1, y0 - 0.045, b.back(y0 - 0.045) * 0.85), _p(s * 0.115, y0, 0.0), _p(s * 0.085, y0 - 0.075, b.front(y0 - 0.075) * 0.92), knot + _p(s * 0.022, 0.008, -0.006)]
		_band(mb, over, 0.042, 0.007, bc, false, 3)
		var under = [surf.call(0.5 + s * 0.42, -0.35, 0.004), _p(s * b.half(y0 - 0.26), y0 - 0.26, -0.01), _p(s * 0.09, y0 - 0.21, b.front(y0 - 0.21) * 0.98), knot + _p(s * 0.022, -0.012, -0.006)]
		_band(mb, under, 0.04, 0.007, bc.darkened(0.08), false, 3)
		var ear = Transform3D(Basis(Vector3.BACK, -s * 0.85), knot + _p(s * 0.02, 0.014, 0.01))
		_plate(mb, [Vector2(-0.02, 0), Vector2(-0.03, 0.04), Vector2(0, 0.074), Vector2(0.028, 0.04), Vector2(0.019, 0)], 0.006, bc.lightened(0.08), ear)
		_dang(d, knot + _p(s * 0.02, -0.014, 0.012), _p(s * 0.35, -1, 0.1), 0.1, 0.04, bc, 0.22, 0.003, 0.55)
	_prof(mb, knot + _p(-0.03, 0, 0), knot + _p(0.03, 0, 0), [Vector2(0, 0.014), Vector2(0.5, 0.027), Vector2(1, 0.014)], bc.darkened(0.08), 8, 2)
	_ring(mb, knot, Vector3.RIGHT, 0.027, 0.005, deep, 8)


## Harita tüpü: cilalı tüp, pirinç bilezik, kapakta bağ, çapraz kayış
static func _harita(mb, b, bc: Color) -> void:
	_sash(mb, b, 1.0, 0.03, LEATHER, LEATHER_D)
	var a = _p(-0.145, -0.31, b.back(-0.31) - 0.05)
	var c = _p(0.135, 0.3, b.back(0.12) - 0.065)
	var y = (c - a).normalized()
	_prof(mb, a, c, [Vector2(0, 0.042), Vector2(0.02, 0.05), Vector2(0.5, 0.05), Vector2(0.98, 0.05), Vector2(1, 0.046)], bc, 12, 1, true, false)
	for t in [0.035, 0.1, 0.5, 0.9]:
		_ring(mb, a.lerp(c, t), y, 0.051, 0.0042, BRASS, 12)
	var cap = c + y * 0.07
	_prof(mb, c - y * 0.008, cap, [Vector2(0, 0.055), Vector2(0.75, 0.055), Vector2(1, 0.04)], bc.darkened(0.3), 12, 1, false, true)
	_ring(mb, c + y * 0.006, y, 0.056, 0.004, BRASS, 12)
	_ring(mb, cap + y * 0.02, Vector3.BACK, 0.014, 0.003, BRASS, 8)
	var side = y.cross(Vector3.BACK).normalized()
	_cord(mb, [c - y * 0.08 + side * 0.052, c + side * 0.06 + y * 0.03, cap + y * 0.018], 0.003, RED, false, 3)
	for t in [0.28, 0.72]:   # kayışa geçen deri bilezik
		var p = a.lerp(c, t)
		_ring(mb, p, y, 0.054, 0.006, LEATHER, 10)
		_seg(mb, p + _p(0, 0, 0.05), p + _p(0, 0, 0.08), 0.022, 0.006, LEATHER, Vector3.UP)
	var tag = _frame(a.lerp(c, 0.4) + _p(0, 0, -0.053), y, Vector3.FORWARD)
	_plate(mb, [Vector2(-0.024, -0.05), Vector2(0.024, -0.05), Vector2(0.024, 0.05), Vector2(-0.024, 0.05)], 0.002, PAPER, tag)
	for k in 3:
		_seg(mb, tag * _p(-0.012 + k * 0.012, 0.035, 0.002), tag * _p(-0.012 + k * 0.012, -0.03 + k * 0.012, 0.002), 0.003, 0.001, BLACK)


## Haberci kuşu (refs/kus_kafesi: kahverengi sırtlı, açık göğüslü küçük kuş)
static func _kus(mb, p: Vector3) -> void:
	var br = Color(0.48, 0.34, 0.22)
	var cr = Color(0.9, 0.85, 0.74)
	_prof(mb, p + _p(0.0, -0.012, -0.036), p + _p(0.0, 0.034, 0.038), [Vector2(0, 0.012), Vector2(0.35, 0.03), Vector2(0.7, 0.027), Vector2(1, 0.018)], [br, cr, cr, br], 8, 2)
	mb.add("cone", p + _p(0, 0.039, 0.062), Vector3(0.012, 0.022, 0.009), Color(0.25, 0.2, 0.16), Vector3(90, 0, 0), 4)
	for s in [-1.0, 1.0]:
		_rivet(mb, p + _p(s * 0.016, 0.043, 0.042), _p(s, 0, 0.3), 0.0036, BLACK)
		var w = Transform3D(Basis(Vector3.RIGHT, 1.25) * Basis(Vector3.UP, s * 0.18), p + _p(s * 0.03, 0.008, -0.006))
		_plate(mb, [Vector2(-0.015, 0.03), Vector2(0.015, 0.03), Vector2(0.012, -0.03), Vector2(0, -0.055)], 0.005, br.darkened(0.15), w)
	_plate(mb, [Vector2(-0.012, 0), Vector2(0.012, 0), Vector2(0.018, -0.055), Vector2(-0.018, -0.055)], 0.004, br.darkened(0.25), Transform3D(Basis(Vector3.RIGHT, 1.0), p + _p(0, -0.01, -0.034)))


## Haberci kuş kafesi: bambu çubuklu kubbeli kafes, sırt tahtasında
static func _kafes(mb, b, bc: Color, d: Dictionary) -> void:
	var y = -0.1
	var bz = b.back(y)
	_straps(mb, b, 0.08, -0.26, 0.075, 0.09, 0.03, LEATHER)
	_plate(mb, [Vector2(-0.1, -0.21), Vector2(0.1, -0.21), Vector2(0.11, 0.16), Vector2(0.05, 0.2), Vector2(-0.05, 0.2), Vector2(-0.11, 0.16)], 0.016, WOOD, Transform3D(Basis.IDENTITY, _p(0, y, bz - 0.01)))
	for s in [-1.0, 1.0]:
		_seg(mb, _p(s * 0.075, 0.08, bz - 0.021), _p(s * 0.075, -0.3, bz - 0.021), 0.014, 0.006, WOOD_D)
	var c = _p(0, y, bz - 0.15)
	var rx = 0.125
	var rz = 0.115
	var bam = Color(0.72, 0.62, 0.38)
	var ell = func(a: float, h: float, k: float) -> Vector3:
		return c + _p(cos(a) * rx * k, h, sin(a) * rz * k)
	_disc_y(mb, c + _p(0, -0.156, 0), 0.134, 0.124, 0.028, WOOD_D, 16)
	_ring(mb, c + _p(0, -0.142, 0), Vector3.UP, 0.13, 0.004, BRASS.darkened(0.2), 14)
	for h in [-0.135, 0.065]:
		var pts = []
		for k in 14:
			pts.append(ell.call(TAU * k / 14.0, h, 1.0))
		_cord(mb, pts, 0.005, bam.darkened(0.12), true, 1)
	for k in 14:
		var a = TAU * k / 14.0
		var low = ell.call(a, -0.14, 1.0)
		var mid = ell.call(a, 0.065, 1.0)
		_seg(mb, low, mid, 0.0065, 0.0065, bam, Vector3.UP)
		if k % 2 == 0:
			_cord(mb, [mid, ell.call(a, 0.13, 0.76), ell.call(a, 0.165, 0.34), c + _p(0, 0.18, 0)], 0.0034, bam, false, 2)
	_prof(mb, c + _p(0, 0.17, 0), c + _p(0, 0.205, 0), [Vector2(0, 0.024), Vector2(1, 0.012)], WOOD_D, 8, 1, false, true)
	_ring(mb, c + _p(0, 0.226, 0), Vector3.BACK, 0.022, 0.0035, BRASS, 9)
	_rod(mb, c + _p(-0.105, -0.055, 0.005), c + _p(0.105, -0.055, 0.005), 0.005, WOOD)
	_kus(mb, c + _p(0.01, -0.012, 0.0))
	var dr = ell.call(-PI * 0.5, -0.04, 1.03)   # küçük kapı
	_link(mb, dr, Vector3.UP, Vector3.FORWARD, 0.11, 0.075, 0.0032, WOOD_D)
	_ring(mb, dr + _p(0.022, 0, -0.004), Vector3.UP, 0.006, 0.0018, BRASS, 6)
	var top = c + _p(0.0, 0.135, 0.0)
	var cover = []   # üstte toplanmış gece örtüsü
	for k in 9:
		var a = 0.05 + PI * 1.5 * k / 8.0
		cover.append(top + _p(cos(a) * 0.09, 0.012 * sin(a * 3.0), sin(a) * 0.08))
	_cord(mb, cover, 0.016, bc, false, 2)
	_dang(d, ell.call(0.1, 0.1, 1.0), _p(0.2, -1, -0.15), 0.16, 0.05, bc, 0.2, 0.003, 0.3)


## Düz kılıç, çapraz kayışla; kabza sol omuz arkasında, topuzdan püskül sarkar
static func _kilic(mb, b, bc: Color, d: Dictionary) -> void:
	_sash(mb, b, 1.0, 0.03, LEATHER_D, LEATHER)
	var a = _p(-0.165, -0.36, b.back(-0.25) - 0.03)
	var c = _p(0.135, 0.17, b.back(0.1) - 0.045)
	var y = (c - a).normalized()
	var xf = _frame(a.lerp(c, 0.5), y, Vector3.FORWARD)
	var lac = Color(0.11, 0.1, 0.13)
	_prof(mb, a, c, [Vector3(0, 0.016, 0.022), Vector3(0.03, 0.019, 0.03), Vector3(0.97, 0.019, 0.032), Vector3(1, 0.019, 0.033)], lac, 8, 1, true, false, Callable(), Vector3.FORWARD)
	_prof(mb, a - y * 0.006, a + y * 0.05, [Vector2(0, 0.012), Vector2(0.3, 0.03), Vector2(1, 0.031)], STEEL.darkened(0.2), 8, 1, true, false)
	for t in [0.76, 0.87]:
		_ring(mb, a.lerp(c, t), y, 0.031, 0.004, BRASS, 10)
	_ring(mb, a.lerp(c, 0.815), y, 0.033, 0.006, bc, 10)
	var cl = c - y * 0.003
	_prof(mb, cl, c + y * 0.012, [Vector3(0, 0.05, 0.062), Vector3(1, 0.05, 0.062)], BRASS.darkened(0.2), 12, 1, false, false, Callable(), Vector3.FORWARD)
	var h0 = c + y * 0.012
	var h1 = c + y * 0.22
	_prof(mb, h0, h1, [Vector3(0, 0.018, 0.024), Vector3(0.5, 0.017, 0.022), Vector3(1, 0.019, 0.025)], BLACK, 8, 1, false, false, Callable(), Vector3.FORWARD)
	var x = xf.basis.x.normalized()
	var z = xf.basis.z.normalized()
	for k in 7:   # çapraz kabza sargısı
		var t0 = k / 7.0
		var t1 = (k + 1) / 7.0
		for sg in [-1.0, 1.0]:
			_seg(mb, h0.lerp(h1, t0) + x * 0.022 * sg + z * 0.018, h0.lerp(h1, t1) - x * 0.022 * sg + z * 0.018, 0.009, 0.003, bc, z)
			_seg(mb, h0.lerp(h1, t0) + x * 0.022 * sg - z * 0.018, h0.lerp(h1, t1) - x * 0.022 * sg - z * 0.018, 0.009, 0.003, bc, -z)
	_prof(mb, h1 - y * 0.004, h1 + y * 0.024, [Vector2(0, 0.024), Vector2(0.6, 0.027), Vector2(1, 0.016)], BRASS, 8, 1, false, true)
	var rg = h1 + y * 0.03
	_ring(mb, rg, Vector3.FORWARD, 0.01, 0.0026, BRASS, 7)
	var kn = rg + _p(0.012, -0.03, -0.012)
	_cord(mb, [rg, rg + _p(0.012, 0.0, -0.01), kn], 0.0034, RED, false, 2)
	mb.add("sphere", kn, Vector3.ONE * 0.022, RED, Vector3.ZERO, 6)
	_ring(mb, kn + _p(0, -0.018, 0), Vector3.UP, 0.009, 0.0022, BRASS, 6)
	for s in [-1.0, 1.0]:   # püskül
		_dang(d, kn + _p(s * 0.004, -0.02, 0), _p(s * 0.12, -1, -0.12), 0.2, 0.021, bc, 0.14, 0.004, 0.2)
	_cord(mb, [a.lerp(c, 0.815) + _p(0, 0, -0.03), a.lerp(c, 0.68) + _p(0.05, 0, -0.04), a.lerp(c, 0.55) + _p(0.02, 0, -0.026)], 0.0032, bc, false, 3)


## Tek kunai sapı + halka (ağzı kılıfta, halkası dışarıda)
static func _kunai_top(mb, base: Vector3, y: Vector3, n: Vector3, grip: Color) -> void:
	_seg(mb, base - y * 0.022, base + y * 0.008, 0.042, 0.009, IRON, n)
	_rod(mb, base + y * 0.008, base + y * 0.09, 0.0075, IRON, 5)
	for k in 2:
		_ring(mb, base + y * (0.03 + k * 0.03), y, 0.0088, 0.0034, grip, 4)
	_ring(mb, base + y * 0.115, n, 0.023, 0.0034, STEEL, 7)


## Yelpaze kunai kılıfı: deri dilimli yay, yedi kunai
static func _kunai_yelpaze(mb, b, bc: Color) -> void:
	_straps(mb, b, 0.02, -0.25, 0.06, 0.09, 0.028, LEATHER)
	var y = -0.1
	var z = b.back(y) - 0.022
	var c = _p(0, y - 0.11, z)
	var o = []
	for k in 9:
		var a = lerpf(-1.08, 1.08, k / 8.0)
		o.append(Vector2(sin(a) * 0.215, cos(a) * 0.205))
	for k in 5:
		var a = lerpf(1.08, -1.08, k / 4.0)
		o.append(Vector2(sin(a) * 0.055, cos(a) * 0.05 - 0.01))
	var fxf = Transform3D(Basis.IDENTITY, c)
	_plate(mb, o, 0.018, LEATHER, fxf)
	var back_o = []
	for q in o:
		back_o.append(q * 0.93)
	_plate(mb, back_o, 0.006, bc.darkened(0.2), fxf * Transform3D(Basis.IDENTITY, _p(0, 0, -0.011)))
	for k in 7:
		var a = lerpf(-0.96, 0.96, k / 6.0)
		var dir = _p(sin(a), cos(a), -0.05).normalized()
		var r0 = 0.09
		var r1 = 0.2
		var pk = c + dir * r1 + _p(0, 0, -0.014)
		_seg(mb, c + dir * r0 + _p(0, 0, -0.013), pk, 0.05, 0.012, bc, Vector3.FORWARD)   # dilim cebi
		_seg(mb, c + dir * r0 + _p(0, 0, -0.02), pk + _p(0, 0, -0.006), 0.003, 0.002, LEATHER_D, Vector3.FORWARD)
		_kunai_top(mb, pk + dir * 0.012, dir, Vector3.FORWARD, bc.lightened(0.2))
		_rivet(mb, c + dir * 0.075 + _p(0, 0, -0.01), Vector3.FORWARD, 0.0065, BRASS)
	for k in 8:
		var a = lerpf(-1.04, 1.04, k / 7.0)
		_seg(mb, c + _p(sin(a), cos(a), 0) * 0.205 + _p(0, 0, -0.01), c + _p(sin(a), cos(a), 0) * 0.215 + _p(0, 0, 0.0), 0.012, 0.004, LEATHER_D, Vector3.FORWARD)


## Dilimli sırt zırhı: üst üste binen, omurga çıkıntılı plakalar, deri bağlı
static func _plaka(mb, b, bc: Color) -> void:
	_straps(mb, b, 0.1, -0.27, 0.07, 0.1, 0.034, LEATHER, false)
	var ys = [0.14, 0.06, -0.02, -0.1, -0.175]
	var hw = [0.1, 0.122, 0.128, 0.116, 0.1]
	for i in ys.size():
		var y0 = float(ys[i])
		var H = 0.05
		var z = b.back(y0) - 0.01
		var w = float(hw[i])
		var col = bc.darkened(0.04 * (i % 2))
		var tilt = Basis(Vector3.RIGHT, 0.14)
		var mid = Transform3D(tilt, _p(0, y0, z - 0.004))
		_plate(mb, [Vector2(-w * 0.46, -H), Vector2(w * 0.46, -H), Vector2(w * 0.46, H), Vector2(-w * 0.46, H)], 0.009, col, mid)
		for s in [-1.0, 1.0]:
			var wing = Transform3D(Basis(Vector3.UP, -s * 0.46) * tilt, _p(s * w * 0.46, y0, z - 0.004))
			var xs = s * w * 0.62
			_plate(mb, [Vector2(0, -H), Vector2(xs, -H * 0.9), Vector2(xs, H * 0.72), Vector2(0, H)], 0.009, col, wing)
			var e = wing * _p(xs * 0.82, 0.0, -0.007)
			_rivet(mb, e, Vector3.FORWARD, 0.0065, BRASS)
			_rivet(mb, _p(s * w * 0.3, y0 + H * 0.5, z - 0.012), Vector3.FORWARD, 0.0055, BRASS)
		_seg(mb, _p(-w * 0.46, y0 - H * 0.98, z + 0.0035), _p(w * 0.46, y0 - H * 0.98, z + 0.0035), 0.006, 0.01, col.lightened(0.28), Vector3.UP)   # kıvrık alt kenar
		_seg(mb, _p(0, y0 + H * 0.9, z - 0.012), _p(0, y0 - H * 0.9, z - 0.004), 0.022, 0.012, col.darkened(0.16), Vector3.FORWARD)   # omurga sırtı
		if i < ys.size() - 1:   # plakaları birbirine bağlayan deri ip
			for s in [-1.0, 1.0]:
				var x = s * w * 0.2
				_cord(mb, [_p(x, y0 - H * 0.72, z - 0.01), _p(x + s * 0.01, y0 - H * 1.12, z - 0.017), _p(x, float(ys[i + 1]) + H * 0.76, b.back(float(ys[i + 1])) - 0.02)], 0.003, LEATHER_D, false, 2)


## Hayvan dişi kolyesi: boyun ipi, boncuklar, irilik sırasıyla dişler
static func _boyun(b, a: float, dip: float, off := 0.0) -> Vector3:
	var y0 = b.top(0.12)
	var fr = maxf(cos(a), 0.0)
	var y = y0 + 0.012 - dip * fr * fr
	var z = cos(a) * (b.front(y) * 0.94 + off) if cos(a) >= 0.0 else cos(a) * (-b.back(y) * 0.94 + off)
	return _p(sin(a) * (0.128 + off), y, z)


static func _dis_kolye(mb, b, bc: Color, d: Dictionary) -> void:
	var pts = []
	for k in 26:
		pts.append(_boyun(b, TAU * k / 26.0, 0.19, 0.008))
	_cord(mb, pts, 0.0035, bc.darkened(0.15), true, 1)
	var bone_c = Color(0.92, 0.88, 0.76)
	var tip = Color(0.62, 0.5, 0.34)
	for k in 13:
		var u = k - 6
		var a = u * 0.135
		var p = _boyun(b, a, 0.19, 0.012)
		var L = 0.112 - absf(u) * 0.012
		var dn = _p(sin(a) * 0.35, -1.0, 0.1).normalized()
		var hook = _p(sign(u + 0.01) * 0.22 * (1.0 - (1.0 if u == 0 else 0.0)), -0.22, 0.12)
		var r0 = 0.0062 + L * 0.075
		var m0 = p + dn * L * 0.5 + hook * L * 0.12
		_cone(mb, p + dn * 0.004, p + dn * L * 0.62 + hook * L * 0.2, r0, bone_c)
		_cone(mb, m0, p + dn * L + hook * L * 0.8, r0 * 0.72, tip)
		if k < 12:
			var q = _boyun(b, a + 0.068, 0.19, 0.012)
			mb.add("sphere", q, Vector3.ONE * 0.017, WOOD_D if k % 2 else RED.darkened(0.2), Vector3.ZERO, 5)
	var kn = _boyun(b, PI, 0.19, 0.012)
	mb.add("sphere", kn, Vector3.ONE * 0.02, bc, Vector3.ZERO, 5)
	for j in 8:   # omuz ve ense boncukları
		var sg = -1.0 if j % 2 else 1.0
		var a2 = PI + sg * (1 + j / 2) * 0.36
		mb.add("sphere", _boyun(b, a2, 0.19, 0.012), Vector3.ONE * 0.021, WOOD_D if j / 2 % 2 else RED.darkened(0.2), Vector3.ZERO, 5)
	for s in [-1.0, 1.0]:
		_dang(d, kn + _p(s * 0.004, -0.004, -0.004), _p(s * 0.16, -1, -0.12), 0.08, 0.007, bc, 0.25, 0.003, 0.25)


## Çan: yarıklı küre, tepe halkası, bağ
static func _suzu(mb, p: Vector3, R: float, col: Color, cord: Color) -> void:
	mb.add("sphere", p, Vector3.ONE * R * 2.0, col, Vector3.ZERO, 8)
	_ring(mb, p, Vector3.UP, R * 0.99, 0.0026, col.darkened(0.3), 6)
	_seg(mb, p + _p(-R * 0.72, -R * 0.68, -R * 0.2), p + _p(R * 0.72, -R * 0.68, -R * 0.2), R * 0.22, R * 0.5, BLACK, Vector3.UP)
	for s in [-1.0, 1.0]:
		_rivet(mb, p + _p(s * R * 0.72, -R * 0.62, -R * 0.2), _p(s, 0, 0), R * 0.14, BLACK)
	_ring(mb, p + Vector3.UP * (R + 0.006), Vector3.BACK, 0.007, 0.0024, col.darkened(0.2), 5)
	_cord(mb, [p + Vector3.UP * (R + 0.012), p + _p(0.005, R + 0.028, 0.002), p + _p(0, R + 0.042, 0.006)], 0.0026, cord, false, 2)


## Çan kemeri: kuşak, geniş düğüm, altın çanlar
static func _can_kemeri(mb, b, bc: Color, d: Dictionary) -> void:
	var cord = RED
	var y = 0.07
	_belt(mb, b, y, 0.054, bc)
	_belt(mb, b, y - 0.022, 0.007, cord, null, 12, 0.005)
	var gold = Color(0.86, 0.68, 0.24)
	for a in [-1.02, -0.6, 0.6, 1.02]:   # orta arkada karakterin çantası var; yan uçlarda el
		var top = b.around(a, y - 0.026, 0.012)
		var R = 0.033
		var p = top + _p(0, -R - 0.045, -0.006)
		_suzu(mb, p, R, gold, cord)
	var kn = b.around(PI * 0.5 + 0.28, y, 0.016)
	_prof(mb, kn + _p(0, 0, -0.03), kn + _p(0, 0, 0.03), [Vector2(0, 0.013), Vector2(0.5, 0.026), Vector2(1, 0.013)], bc.darkened(0.12), 7, 2)
	for s in [-1.0, 1.0]:
		_dang(d, kn + _p(0.005, -0.012, s * 0.016), _p(0.08, -1, s * 0.18), 0.17, 0.042, bc, 0.2, 0.004, 0.2)


## Kama (orak): kavisli ağız, sargılı sap
static func _kama_one(mb, p: Vector3, up: Vector3, n: Vector3, s: float, grip: Color) -> void:
	var y = up.normalized()
	var x = n.cross(y).normalized()
	var top = p + y * 0.2
	_prof(mb, p, top, [Vector2(0, 0.015), Vector2(0.08, 0.018), Vector2(0.92, 0.015), Vector2(1, 0.017)], WOOD, 6, 1)
	for k in 5:
		_ring(mb, p + y * (0.04 + k * 0.024), y, 0.0165, 0.0034, grip, 6)
	_ring(mb, top - y * 0.012, y, 0.0185, 0.003, IRON, 7)
	_ring(mb, p - y * 0.012, n, 0.012, 0.0028, IRON, 7)
	var xf = Transform3D(Basis(x * s, y, x.cross(y) * s), top + y * 0.002)
	var o = [Vector2(-0.015, -0.012), Vector2(0.018, -0.012), Vector2(0.05, 0.012), Vector2(0.105, 0.034), Vector2(0.158, 0.03), Vector2(0.2, 0.0), Vector2(0.15, 0.058), Vector2(0.09, 0.07), Vector2(0.035, 0.05), Vector2(-0.004, 0.024)]
	_plate(mb, o, 0.007, STEEL.darkened(0.25), xf)
	var e = [Vector2(0.05, 0.012), Vector2(0.105, 0.034), Vector2(0.158, 0.03), Vector2(0.2, 0.0), Vector2(0.15, 0.042), Vector2(0.104, 0.05), Vector2(0.05, 0.028)]
	_plate(mb, e, 0.0085, STEEL_L, xf)
	_rivet(mb, xf * _p(0.005, 0.008, 0.004), n, 0.005, BRASS)


## İkiz kama: kemerin arkasında, ağızları dışa bakan iki orak
static func _ikiz_kama(mb, b, bc: Color, d: Dictionary) -> void:
	var y = 0.07
	_belt(mb, b, y, 0.03, LEATHER, LEATHER_D)
	var bz = b.back(y)
	for s in [-1.0, 1.0]:
		var c = _p(s * 0.085, y - 0.015, bz - 0.014)
		var p = c + _p(s * -0.045, -0.12, 0.006)
		var up = _p(s * 0.3, 1.0, -0.08)
		_kama_one(mb, p, up, Vector3.FORWARD, s, bc)
		_band(mb, [c + _p(-0.03, 0.022, 0.012), c + _p(-0.034, 0.0, -0.012), c + _p(0, -0.01, -0.024), c + _p(0.034, 0.0, -0.012), c + _p(0.03, 0.022, 0.012)], 0.018, 0.004, LEATHER_D, false, 2)
		_rivet(mb, c + _p(-0.02, 0.0, -0.022), Vector3.FORWARD, 0.0045, BRASS)
	_dang(d, _p(0.085 - 0.045, y - 0.14, bz - 0.01), _p(0.05, -1, -0.05), 0.09, 0.012, bc, 0.25)
	_dang(d, _p(-0.085 + 0.045, y - 0.14, bz - 0.01), _p(-0.05, -1, -0.05), 0.09, 0.012, bc, 0.25)


## Ok: gövde, üç sıra beyaz tüy, gez (refs/yumi: Susuki'nin omzundaki oklar)
static func _ok(mb, a: Vector3, top: Vector3, rot: float) -> void:
	var y = (top - a).normalized()
	_rod(mb, a, top, 0.0045, Color(0.72, 0.62, 0.42), 4)
	_rod(mb, top, top + y * 0.012, 0.006, RED, 4)
	var u = _perp(y)
	for k in 3:
		var ang = rot + TAU * k / 3.0
		var z = u.rotated(y, ang)
		var xf = _frame(top - y * 0.075, y, z)
		_plate(mb, [Vector2(0.002, -0.058), Vector2(0.025, -0.05), Vector2(0.027, 0.045), Vector2(0.004, 0.062)], 0.002, Color(0.95, 0.94, 0.9), Transform3D(xf.basis, xf.origin))
	_ring(mb, top - y * 0.142, y, 0.0058, 0.0016, RED, 4)


## Sadak: sağ omuz arkasında, deri ağızlı, bilezikli ok kılıfı
static func _sadak(mb, b, bc: Color) -> void:
	_sash(mb, b, -1.0, 0.03, LEATHER, LEATHER_D)
	var a = _p(0.02, -0.36, b.back(-0.3) - 0.05)
	var c = _p(-0.145, 0.18, b.back(0.1) - 0.06)
	var y = (c - a).normalized()
	_prof(mb, a, c, [Vector3(0, 0.038, 0.03), Vector3(0.05, 0.05, 0.036), Vector3(0.6, 0.056, 0.042), Vector3(1, 0.064, 0.05)], bc, 12, 1, true, false, Callable(), Vector3.BACK)
	_prof(mb, a - y * 0.008, a + y * 0.07, [Vector3(0, 0.03, 0.022), Vector3(0.3, 0.053, 0.039), Vector3(1, 0.054, 0.04)], LEATHER, 12, 1, true, false, Callable(), Vector3.BACK)
	_prof(mb, c - y * 0.075, c + y * 0.005, [Vector3(0, 0.067, 0.052), Vector3(1, 0.07, 0.056)], LEATHER, 12, 1, false, false, Callable(), Vector3.BACK)
	for t in [0.32, 0.62]:
		var k = lerpf(0.05, 0.062, t)
		_prof(mb, a.lerp(c, t) - y * 0.014, a.lerp(c, t) + y * 0.014, [Vector3(0, k, k * 0.76), Vector3(1, k, k * 0.76)], LEATHER_D, 12, 1, false, false, Callable(), Vector3.BACK)
	var s = y.cross(Vector3.BACK).normalized()
	var z = s.cross(y).normalized() * -1.0
	for k in 7:   # uzun dikiş
		var t0 = 0.12 + k * 0.1
		_seg(mb, a.lerp(c, t0) + z * 0.047, a.lerp(c, t0 + 0.06) + z * 0.05, 0.004, 0.003, PAPER, z)
	_prof(mb, c - y * 0.03, c, [Vector3(0, 0.047, 0.034), Vector3(1, 0.052, 0.04)], BLACK, 12, 1, false, true, Callable(), Vector3.BACK)
	for i in 6:
		var u = (i % 3 - 1) * 0.028
		var v = (i / 3 - 0.5) * 0.034
		var base = c + s * u + z * v
		_ok(mb, base - y * 0.03, base + y * (0.16 + (i % 2) * 0.022) + s * u * 0.4, i * 0.8)


## Savaş çekici: Kabutowari'nin çekici gibi fıçı baş, örgülü yüzey, kuşak; sapta halka
static func _cekic(mb, b, bc: Color, d: Dictionary) -> void:
	_sash(mb, b, -1.0, 0.034, LEATHER, LEATHER_D)
	var a = _p(0.15, -0.44, b.back(-0.25) - 0.03)
	var c = _p(-0.165, 0.09, b.back(0.08) - 0.095)
	var y = (c - a).normalized()
	_prof(mb, a, c, [Vector2(0, 0.019), Vector2(0.5, 0.017), Vector2(1, 0.02)], WOOD_D, 7, 1)
	for k in 8:
		_ring(mb, a.lerp(a + y * 0.32, k / 8.0) + y * 0.025, y + _p(0.14, 0.0, 0.0), 0.0195, 0.0042, bc, 5)
	_ring(mb, a + y * 0.016, y, 0.021, 0.0045, IRON, 7)
	_ring(mb, a + y * 0.35, y, 0.021, 0.0045, IRON, 7)
	_ring(mb, a - y * 0.016, Vector3.FORWARD, 0.019, 0.0038, STEEL, 9)
	for k in 2:
		_link(mb, a - y * (0.05 + k * 0.03) + _p(0.0, -0.001, 0.0), -y, Vector3.FORWARD if k % 2 else y.cross(Vector3.FORWARD), 0.034, 0.018, 0.003, STEEL)
	var ax = y.cross(Vector3.FORWARD).normalized()
	var h = c + y * 0.05
	var HL = 0.115
	var HC = Color(0.34, 0.33, 0.36)
	_prof(mb, h - ax * HL, h + ax * HL, [Vector2(0, 0.06), Vector2(0.06, 0.07), Vector2(0.5, 0.08), Vector2(0.94, 0.07), Vector2(1, 0.06)], HC, 12, 2, true, true, Callable(), y)
	for s in [-1.0, 1.0]:
		var e = h + ax * HL * s
		_prof(mb, e - ax * s * 0.016, e + ax * s * 0.02, [Vector2(0, 0.073), Vector2(1, 0.068)], IRON, 12, 1, false, false, Callable(), y)
		for k in 6:
			var ang = TAU * k / 6.0
			var off = (y * cos(ang) + y.cross(ax) * sin(ang)) * 0.06
			_rivet(mb, e + ax * s * 0.02 + off, ax * s, 0.0065, STEEL)
	var v1 = y
	var v2 = y.cross(ax).normalized()
	for row in 3:   # örgü taş / demir kaplama
		var st = lerpf(-0.072, 0.072, row / 2.0)
		for k in 9:
			var ang = TAU * (k + row * 0.5) / 9.0
			var e0 = v1 * cos(ang) + v2 * sin(ang)
			var c0 = h + ax * st + e0 * 0.079
			var t = ax.cross(e0).normalized()
			_seg(mb, c0 - ax * 0.026 + t * 0.01, c0 + ax * 0.026 - t * 0.01, 0.0035, 0.004, HC.darkened(0.35), e0)
	_ring(mb, h, ax, 0.082, 0.005, BRASS.darkened(0.25), 14)
	_prof(mb, c - y * 0.028, c + y * 0.016, [Vector2(0, 0.019), Vector2(0.7, 0.032), Vector2(1, 0.03)], IRON, 7, 1, false, false)
	_dang(d, a + y * 0.33 + _p(0, 0, -0.022), _p(0.1, -1, -0.1), 0.16, 0.022, bc, 0.2)


## Tilki maskesi: ANBU maskesi biçimi (refs/tilki_maske_bel), yan kalçada iple
static func _maske(mb, b, bc: Color, d: Dictionary) -> void:
	var y = 0.07
	_belt(mb, b, y, 0.028, LEATHER, LEATHER_D)
	var hook = b.around(0.74, y, 0.006)
	var p = b.around(0.74, -0.095, 0.036)
	var out = Vector3(p.x, 0, p.z).normalized()
	var base = _frame(p, _p(0, 1, 0.1), out)
	base.basis = base.basis * 1.32
	var W = Color(0.93, 0.93, 0.92)
	var S = Color(0.78, 0.78, 0.8)
	var blue = Color(0.14, 0.52, 0.72)
	var mid = [Vector2(-0.032, 0.088), Vector2(0.032, 0.088), Vector2(0.032, -0.086), Vector2(0.0, -0.104), Vector2(-0.032, -0.086)]
	_plate(mb, mid, 0.007, W, base)
	for s in [-1.0, 1.0]:
		var ch = base * Transform3D(Basis(Vector3.UP, s * 0.5), _p(s * 0.032, 0, -0.001))
		var o = [Vector2(0, 0.088), Vector2(s * 0.022, 0.102), Vector2(s * 0.054, 0.126), Vector2(s * 0.06, 0.066), Vector2(s * 0.06, -0.006), Vector2(s * 0.046, -0.05), Vector2(0, -0.086)]
		_plate(mb, o, 0.007, W, ch)
		_plate(mb, [Vector2(s * 0.014, 0.038), Vector2(s * 0.048, 0.052), Vector2(s * 0.042, 0.03), Vector2(s * 0.012, 0.024)], 0.0085, BLACK, ch)   # göz yarığı
		for k in 2:   # yanak çizgileri
			var yy = 0.0 - k * 0.024
			_plate(mb, [Vector2(s * 0.006, yy), Vector2(s * 0.054, yy + 0.016), Vector2(s * 0.054, yy + 0.008), Vector2(s * 0.012, yy - 0.008)], 0.0088, blue, ch)
		_plate(mb, [Vector2(s * 0.012, 0.062), Vector2(s * 0.044, 0.08), Vector2(s * 0.042, 0.072), Vector2(s * 0.014, 0.056)], 0.0088, blue, ch)
		var ear = ch * _p(s * 0.054, 0.1, 0.004)
		_rivet(mb, ear, out, 0.004, S)
	mb.add_xf("box", base * Transform3D(Basis(Vector3.RIGHT, -0.42) * Basis.from_scale(Vector3(0.018, 0.05, 0.026)), _p(0, -0.018, 0.012)), W)   # burun
	_plate(mb, [Vector2(-0.007, -0.04), Vector2(0.007, -0.04), Vector2(0, -0.05)], 0.02, BLACK, base * Transform3D(Basis.IDENTITY, _p(0, 0, 0.012)))
	_plate(mb, [Vector2(-0.036, -0.068), Vector2(-0.012, -0.076), Vector2(0.012, -0.062), Vector2(0.036, -0.072), Vector2(0.036, -0.066), Vector2(0.012, -0.056), Vector2(-0.012, -0.07), Vector2(-0.036, -0.062)], 0.0085, blue, base)
	var e0 = base * _p(0.056, 0.03, -0.012)
	var e1 = base * _p(-0.056, 0.03, -0.012)
	_cord(mb, [e0, hook.lerp(e0, 0.5) + _p(0, 0.012, 0), hook], 0.0032, bc, false, 2)
	_cord(mb, [e1, hook.lerp(e1, 0.5) + _p(0, 0.02, -0.01), hook], 0.0032, bc, false, 2)
	mb.add("sphere", hook + out * 0.006, Vector3.ONE * 0.016, bc.darkened(0.1), Vector3.ZERO, 5)
	for s in [-1.0, 1.0]:
		_dang(d, hook + out * 0.008, _p(s * 0.1, -1, 0.06), 0.1, 0.008, bc, 0.25, 0.003, 0.25)


## Yatate: fırça tüpü + kapaklı mürekkep çanağı; kuşağa netsuke ile asılır (gerçek Japon yazı takımı)
static func _yatate(mb, b, bc: Color, d: Dictionary) -> void:
	var y = 0.075
	_belt(mb, b, y, 0.03, LEATHER, LEATHER_D)
	var p = b.around(-0.95, -0.03, 0.034)
	var side = Vector3(p.x, 0, p.z).normalized()
	var dn = _p(-0.1, -1, 0.03).normalized()
	var top = p + _p(0, 0.05, 0)
	var bot = top + dn * 0.2
	_prof(mb, top, bot, [Vector2(0, 0.0145), Vector2(0.06, 0.0165), Vector2(0.94, 0.0145), Vector2(1, 0.012)], bc, 8, 1)
	for t in [0.06, 0.5, 0.94]:
		_ring(mb, top.lerp(bot, t), dn, 0.0168, 0.0024, BRASS, 8)
	_rod(mb, bot, bot + dn * 0.028, 0.006, WOOD_D, 5)
	_cone(mb, bot + dn * 0.028, bot + dn * 0.056, 0.0072, BLACK)
	var pot = top + side * 0.024 + _p(0, -0.004, 0)
	var ax = side.cross(Vector3.UP).normalized()
	_prof(mb, pot - dn * 0.024, pot + dn * 0.022, [Vector2(0, 0.026), Vector2(0.12, 0.033), Vector2(0.86, 0.035), Vector2(1, 0.024)], BRASS.darkened(0.18), 10, 1, true, true)
	_prof(mb, pot - dn * 0.03, pot - dn * 0.02, [Vector2(0, 0.024), Vector2(1, 0.036)], BRASS, 10, 1, true, false)
	_rod(mb, pot - dn * 0.026 + ax * 0.034 - side * 0.002, pot - dn * 0.026 + ax * 0.04 - side * 0.002, 0.006, BRASS.darkened(0.3), 5)
	_seg(mb, pot - side * 0.021 - dn * 0.008, top + side * 0.008, 0.012, 0.012, BRASS.darkened(0.12), ax)
	_ring(mb, pot - dn * 0.02 + side * 0.03, ax, 0.006, 0.0016, BRASS, 6)
	var ne = b.around(-0.95, y + 0.044, 0.018)
	mb.add("sphere", ne, Vector3(0.034, 0.024, 0.028), WOOD, Vector3.ZERO, 6)   # netsuke
	_ring(mb, ne, side, 0.012, 0.0022, WOOD_D, 6)
	_cord(mb, [ne, ne + side * 0.007 + _p(0, -0.05, 0), top + _p(0, 0.022, 0.0), top + _p(0, 0.002, 0.0)], 0.0028, RED, false, 3)
	var slip = _frame(top.lerp(bot, 0.56) + side * 0.016, dn, side)
	_plate(mb, [Vector2(-0.017, -0.038), Vector2(0.017, -0.038), Vector2(0.017, 0.038), Vector2(-0.017, 0.038)], 0.002, PAPER, slip)
	_dang(d, ne - side * 0.002 + _p(0, -0.014, 0), _p(0.04, -1, 0.04), 0.09, 0.008, RED, 0.25)


## Asuma tipi chakra bıçağı (refs/chakra_bicaklari): testere sırtlı kara ağız, parmak halkalı sap; bıçak aşağı, kınında
static func _chakra_one(mb, xf: Transform3D, sheath: Color) -> void:
	var dark = Color(0.16, 0.17, 0.22)
	var o = [Vector2(-0.024, 0.0), Vector2(0.024, 0.0), Vector2(0.03, -0.02), Vector2(0.018, -0.03), Vector2(0.028, -0.048), Vector2(0.014, -0.058), Vector2(0.024, -0.078), Vector2(0.01, -0.09), Vector2(0.018, -0.12), Vector2(0.006, -0.17), Vector2(-0.004, -0.205), Vector2(-0.018, -0.14), Vector2(-0.028, -0.07)]
	_plate(mb, o, 0.007, dark, xf)
	_plate(mb, [Vector2(-0.028, -0.07), Vector2(-0.018, -0.14), Vector2(-0.004, -0.205), Vector2(-0.01, -0.14), Vector2(-0.019, -0.07)], 0.009, STEEL_L, xf)
	var c = xf * _p(0, 0.05, 0)
	var y = xf.basis.y.normalized()
	var n = xf.basis.z.normalized()
	_rod(mb, xf * _p(0, 0.0, 0), xf * _p(0, 0.075, 0), 0.0115, IRON, 6)
	for k in 5:
		_ring(mb, xf * _p(0, 0.012 + k * 0.012, 0), y, 0.0128, 0.003, sheath.darkened(0.45), 6)
	_seg(mb, xf * _p(-0.03, 0.002, 0), xf * _p(0.03, 0.002, 0), 0.009, 0.012, STEEL.darkened(0.2), n)
	_ring(mb, c + y * 0.052, n, 0.03, 0.0042, IRON, 11)   # parmak halkası
	var sh = [Vector2(-0.036, -0.115), Vector2(0.034, -0.115), Vector2(0.03, -0.18), Vector2(0.01, -0.222), Vector2(-0.012, -0.222), Vector2(-0.03, -0.17)]
	_plate(mb, sh, 0.016, sheath, xf)
	_seg(mb, xf * _p(-0.036, -0.115, 0), xf * _p(0.034, -0.115, 0), 0.008, 0.019, BRASS, n)
	for k in 4:
		_seg(mb, xf * _p(0.024 - k * 0.002, -0.13 - k * 0.022, 0.009), xf * _p(0.016 - k * 0.002, -0.14 - k * 0.022, 0.009), 0.003, 0.002, LEATHER_D, n)


static func _chakra(mb, b, bc: Color) -> void:
	var y = 0.075
	_belt(mb, b, y, 0.032, LEATHER_D, LEATHER)
	for s in [-1.0, 1.0]:
		var a = s * 0.55
		var p = b.around(a, y - 0.03, 0.016)
		var n = Vector3(p.x * 0.7, 0, p.z).normalized()
		var up = _p(s * -0.42, 1.0, 0).normalized()
		var xf = _frame(p + _p(0, 0.012, 0), up, n)
		_chakra_one(mb, xf, bc.darkened(0.18))
		for k in 2:
			var e = xf * _p(0.0, -0.06 - k * 0.06, 0.0)
			_band(mb, [e - xf.basis.x * 0.042 - n * 0.008, e - xf.basis.x * 0.04 + n * 0.012, e + xf.basis.x * 0.04 + n * 0.012, e + xf.basis.x * 0.042 - n * 0.008], 0.013, 0.003, LEATHER, false, 1)
		_cord(mb, [b.around(a, y, 0.006), p + n * 0.012 + _p(0, 0.03, 0)], 0.0032, LEATHER, false, 1)


## Bele sarılı zincir: iki tur, kanca ve ağırlıklı uç
static func _zincir(mb, b, bc: Color, d: Dictionary) -> void:
	var steel = STEEL.darkened(0.14)
	_belt(mb, b, 0.06, 0.026, bc.darkened(0.2))
	var N = 17
	for L in 2:
		var y0 = 0.09 - L * 0.05
		for k in N:
			var a0 = TAU * (k + L * 0.5) / N
			var a1 = TAU * (k + 1 + L * 0.5) / N
			var yy = y0 + sin(a0 * 2.0) * 0.006
			var yy1 = y0 + sin(a1 * 2.0) * 0.006
			var p0 = b.around(a0, yy, 0.012)
			var p1 = b.around(a1, yy1, 0.012)
			var c = (p0 + p1) * 0.5
			var out = Vector3(c.x, 0, c.z).normalized()
			_link(mb, c, p1 - p0, out if k % 2 == 0 else Vector3.UP, p0.distance_to(p1) * 0.95, 0.024, 0.0035, steel)
	var h = b.around(-PI * 0.42, 0.065, 0.024)
	var out2 = Vector3(h.x, 0, h.z).normalized()
	_cord(mb, [h + _p(0, 0.028, 0), h + out2 * 0.016 + _p(0, 0.015, 0), h + out2 * 0.018 + _p(0, -0.018, 0), h + out2 * 0.004 + _p(0, -0.026, 0)], 0.0042, IRON, false, 2)
	var dn = _p(0.03, -1, 0)
	var q = h + _p(0, -0.03, 0) + out2 * 0.012
	for k in 4:
		_link(mb, q + dn * (0.028 * k + 0.014), dn, out2 if k % 2 == 0 else out2.cross(Vector3.UP), 0.032, 0.018, 0.0032, steel)
	var w = q + dn * 0.122
	_prof(mb, w, w + dn * 0.05, [Vector2(0, 0.011), Vector2(0.2, 0.017), Vector2(1, 0.014)], IRON, 6, 1)
	_dang(d, b.around(0.0, 0.06, 0.014), _p(0, -1, -0.05), 0.08, 0.018, bc, 0.25)


## Bambu matara: boğumlu gövde, tahta tıpa, deri askı
static func _bambu(mb, b, bc: Color, d: Dictionary) -> void:
	var y = 0.075
	_belt(mb, b, y, 0.024, LEATHER, LEATHER_D)
	var p = b.around(0.82, 0.0, 0.05)
	var top = p + _p(0.004, 0.035, 0)
	var dir = _p(0.05, -1, -0.03).normalized()
	var L = 0.26
	var bot = top + dir * L
	var G = Color(0.5, 0.6, 0.27)
	var G2 = Color(0.62, 0.68, 0.36)
	var pr = []
	var cols = []
	var nodes = [0.0, 0.33, 0.67, 1.0]
	for i in 3:
		var t0 = float(nodes[i])
		var t1 = float(nodes[i + 1])
		pr.append_array([Vector2(t0 + 0.012, 0.0345), Vector2(lerpf(t0, t1, 0.5), 0.0325)])
		cols.append_array([G2, G])
	pr.append(Vector2(0.985, 0.0345))
	cols.append(G2)
	_prof(mb, top, bot, pr, cols, 10, 2, false, true)
	for t in [0.33, 0.67]:
		_ring(mb, top.lerp(bot, t), dir, 0.0355, 0.0034, Color(0.4, 0.46, 0.2), 11)
	_prof(mb, top - dir * 0.006, top + dir * 0.02, [Vector2(0, 0.0345), Vector2(1, 0.0345)], G2, 10, 1, true, false)
	_prof(mb, top - dir * 0.03, top + dir * 0.008, [Vector2(0, 0.016), Vector2(0.4, 0.021), Vector2(1, 0.022)], WOOD, 8, 1, true, false)
	var side = Vector3(p.x, 0, p.z).normalized()
	_ring(mb, top.lerp(bot, 0.16), dir, 0.037, 0.006, bc.lightened(0.2), 10)
	_ring(mb, top.lerp(bot, 0.84), dir, 0.037, 0.006, bc.lightened(0.2), 10)
	var hk = b.around(0.82, y, 0.005)
	var r = dir.cross(side).normalized()
	_band(mb, [hk + r * 0.012, top.lerp(bot, 0.16) + r * 0.036 + side * 0.008], 0.014, 0.004, bc.lightened(0.2), false, 1)
	_band(mb, [hk - r * 0.012, top.lerp(bot, 0.16) - r * 0.036 + side * 0.008], 0.014, 0.004, bc.lightened(0.2), false, 1)
	_cord(mb, [top - dir * 0.022 + side * 0.022, top - dir * 0.03 + side * 0.03 + _p(0, -0.01, 0), top + dir * 0.03 + side * 0.038], 0.0026, ROPE, false, 2)
	_dang(d, top + dir * 0.03 + side * 0.04, _p(0.05, -1, 0.05), 0.1, 0.009, ROPE, 0.25)


## Nuno Maki (refs/nuno): krem rulo, uçta sarmal, çapraz kat çizgileri, kırmızı mühür; iki halat askı
static func _nuno(mb, b, bc: Color, d: Dictionary) -> void:
	var R = 0.105
	var HL = 0.29
	var line = bc.darkened(0.72)
	var c = _p(0, -0.02, b.back(-0.02) - 0.165)
	var e = _p(0.1, 1.0, -0.12).normalized()   # üst uç hafif geriye: sarmal arkadan görünür
	var v = _perp(e, Vector3.FORWARD)
	var u = e.cross(v).normalized()
	var A = c - e * HL
	var T = c + e * HL
	var at = func(t: float, a: float, lift: float) -> Vector3:
		return A.lerp(T, t) + (u * sin(a) + v * cos(a)) * (R + lift)
	_prof(mb, A, T, [Vector2(0, R), Vector2(0.5, R + 0.004), Vector2(1, R)], bc, 16, 1, false, false)
	for s in [-1.0, 1.0]:
		var E = c + e * HL * s
		_rod(mb, E - e * 0.003, E + e * 0.003, R, bc.darkened(0.06), 16)
		var pts = []
		for k in 34:
			var t = k / 33.0
			var a = t * TAU * 3.4 * s
			pts.append(E + e * s * 0.0045 + (u * sin(a) + v * cos(a)) * lerpf(0.012, R * 0.94, t))
		for k in pts.size() - 1:
			_seg(mb, pts[k], pts[k + 1], 0.0048, 0.0028, line, e)
	for k in 3:   # kumaşın çapraz katları
		var q = []
		for j in 11:
			var w = j / 10.0
			q.append(at.call(0.14 + k * 0.27 + w * 0.2, lerpf(-1.25, 1.25, w), 0.0035))
		for j in q.size() - 1:
			_seg(mb, q[j], q[j + 1], 0.0048, 0.002, line, (q[j] as Vector3) - c)
	var tp = at.call(0.62, 0.3, 0.002)
	var tag = _frame(tp, e, tp - A.lerp(T, 0.62))
	_plate(mb, [Vector2(-0.036, -0.046), Vector2(0.036, -0.046), Vector2(0.036, 0.046), Vector2(-0.036, 0.046)], 0.002, RED, tag)
	for k in 3:
		_seg(mb, tag * _p(-0.02 + k * 0.02, 0.03, 0.002), tag * _p(-0.016 + k * 0.016, -0.03, 0.002), 0.005, 0.0012, BLACK)
	var y0 = b.top(0.11)
	for t in [0.28, 0.78]:   # ruloyu saran halat
		var w = []
		for k in 8:
			w.append(at.call(t, TAU * k / 8.0, 0.006))
		_cord(mb, w, 0.0055, ROPE, true, 1)
	for s in [-1.0, 1.0]:   # omuzdan geçip alttaki halata bağlanır
		var side = -s * PI * 0.5
		_cord(mb, [at.call(0.78, side, 0.006), _p(s * 0.1, y0 - 0.045, b.back(y0 - 0.045) * 0.86), _p(s * 0.115, y0 + 0.002, 0.0), _p(s * 0.1, y0 - 0.08, b.front(y0 - 0.08) * 0.92), _p(s * 0.13, y0 - 0.19, b.front(y0 - 0.19) * 0.96), _p(s * b.half(y0 - 0.27), y0 - 0.27, 0.0), _p(s * 0.12, -0.16, b.back(-0.16) - 0.01), at.call(0.28, side, 0.006)], 0.0055, ROPE, false, 3)
	_dang(d, at.call(0.04, 0.0, 0.002), _p(0, -1, -0.08), 0.3, 0.12, bc, 0.2, 0.004, 0.15)


## Sırt çantası: kanvas gövde, kapak, cepler; üstte bağlı rulo yatak
static func _canta(mb, b, bc: Color, d: Dictionary) -> void:
	_straps(mb, b, 0.06, -0.27, 0.075, 0.095, 0.036, LEATHER)
	var y = -0.11
	var z = b.back(y) - 0.08
	var top = _p(0, y + 0.145, z)
	var bot = _p(0, y - 0.16, z)
	var body = [Vector3(0, 0.05, 0.12), Vector3(0.1, 0.078, 0.15), Vector3(0.5, 0.082, 0.155), Vector3(0.9, 0.072, 0.145), Vector3(1, 0.058, 0.12)]
	_prof(mb, bot, top, body, bc, 14, 2, true, true)
	_prof(mb, bot + _p(0, -0.004, 0), bot + _p(0, 0.03, 0), [Vector3(0, 0.054, 0.126), Vector3(1, 0.08, 0.152)], LEATHER, 14, 1, true, false)
	var bz = z - 0.08
	var flap = Transform3D(Basis(Vector3.RIGHT, -0.1), _p(0, y + 0.075, bz))
	_plate(mb, [Vector2(-0.125, 0.07), Vector2(0.125, 0.07), Vector2(0.118, -0.03), Vector2(0.06, -0.085), Vector2(-0.06, -0.085), Vector2(-0.118, -0.03)], 0.012, bc.darkened(0.16), flap)
	for k in 12:   # kapak kenar dikişi
		var t = k / 11.0
		_seg(mb, flap * _p(lerpf(-0.11, 0.11, t), -0.06 + 0.05 * absf(t * 2.0 - 1.0) ** 2 , -0.0072), flap * _p(lerpf(-0.11, 0.11, t) + 0.01, -0.06 + 0.05 * absf(t * 2.0 - 1.0) ** 2, -0.0072), 0.003, 0.0012, PAPER, Vector3.FORWARD)
	for s in [-1.0, 1.0]:
		var x = s * 0.055
		_band(mb, [_p(x, y + 0.03, bz - 0.012), _p(x, y - 0.03, bz - 0.014), _p(x, y - 0.09, bz + 0.001)], 0.02, 0.004, LEATHER, false, 2)
		_buckle(mb, _p(x, y - 0.018, bz - 0.016), Vector3.FORWARD, Vector3.UP)
		var pc = _p(s * 0.138, y - 0.075, z - 0.006)
		_prof(mb, pc + _p(0, -0.055, 0), pc + _p(0, 0.05, 0), [Vector3(0, 0.024, 0.024), Vector3(0.2, 0.038, 0.03), Vector3(0.85, 0.04, 0.032), Vector3(1, 0.03, 0.026)], bc.darkened(0.08), 8, 1)
		_seg(mb, pc + _p(-0.03, 0.05, -0.025), pc + _p(0.03, 0.05, -0.025), 0.014, 0.008, LEATHER, Vector3.FORWARD)
	var pk = Transform3D(Basis.IDENTITY, _p(0, y - 0.108, bz - 0.012))
	_plate(mb, [Vector2(-0.085, 0.03), Vector2(0.085, 0.03), Vector2(0.08, -0.04), Vector2(-0.08, -0.04)], 0.012, bc.darkened(0.08), pk)
	_seg(mb, pk * _p(-0.085, 0.03, -0.008), pk * _p(0.085, 0.03, -0.008), 0.009, 0.003, LEATHER, Vector3.FORWARD)
	# rulo yatak: ucu sarmal
	var by = y + 0.19
	var bedz = z + 0.006
	var bedc = Color(0.56, 0.2, 0.17)
	_prof(mb, _p(-0.2, by, bedz), _p(0.2, by, bedz), [Vector2(0, 0.05), Vector2(0.5, 0.054), Vector2(1, 0.05)], bedc, 12, 1, false, false)
	for s in [-1.0, 1.0]:
		var cen = _p(s * 0.2, by, bedz)
		_rod(mb, cen - _p(0.002, 0, 0), cen + _p(0.002, 0, 0), 0.05, bedc.lightened(0.1), 12)
		var pv = cen + _p(s * 0.003, 0, 0)
		for k in 12:
			var a0 = k * 1.0
			var a1 = (k + 1) * 1.0
			_seg(mb, pv + _p(0, sin(a0), cos(a0)) * (0.006 + k * 0.0034), pv + _p(0, sin(a1), cos(a1)) * (0.006 + (k + 1) * 0.0034), 0.003, 0.002, bedc.darkened(0.45), Vector3.RIGHT)
		var w = []
		for k in 8:
			var a = TAU * k / 8.0
			w.append(_p(s * 0.1, by + sin(a) * 0.057, bedz + cos(a) * 0.057))
		_band_x(mb, w, 0.02, LEATHER)
		_seg(mb, _p(s * 0.1, by - 0.054, bedz - 0.03), _p(s * 0.08, y + 0.11, bz - 0.006), 0.016, 0.004, LEATHER, Vector3.FORWARD)
		_buckle(mb, _p(s * 0.1, by + 0.0, bedz - 0.058), Vector3.FORWARD, Vector3.RIGHT)
	_ring(mb, _p(0.135, y - 0.11, z - 0.05), Vector3.FORWARD, 0.012, 0.0028, BRASS, 7)
	_dang(d, _p(0.135, y - 0.122, z - 0.052), _p(0.08, -1, -0.08), 0.1, 0.012, RED, 0.25)


## X eksenini saran kısa kayış
static func _band_x(mb, pts: Array, w: float, col: Color) -> void:
	var n = pts.size()
	for i in n:
		var a: Vector3 = pts[i]
		var c: Vector3 = pts[(i + 1) % n]
		var mid = (a + c) * 0.5
		var d = (c - a).normalized()
		var nn = Vector3.RIGHT.cross(d).normalized()
		mb.add_xf("box", Transform3D(Basis(Vector3.RIGHT * w, (c - a) * 1.12, nn * 0.005), mid), col)


## Hasır sırt sepeti: yukarı genişleyen örgü gövde, halat ağız, kuşak ve hasır askılar, içinde bohça ve otlar
static func _sepet(mb, b, bc: Color) -> void:
	var y = -0.11
	var z = b.back(y) - 0.125
	var bot = _p(0, y - 0.2, z + 0.022)
	var top = _p(0, y + 0.185, z - 0.012)
	var dk = bc.darkened(0.32)
	var lt = bc.lightened(0.14)
	var fn = func(t: float, ang: float, _s: Vector3) -> Color:
		var a = int(floor((ang + PI) / TAU * 26.0))
		var r = int(floor(t * 22.0))
		return lt if (a + r) % 2 == 0 else dk
	var pr = [Vector3(0, 0.086, 0.122), Vector3(0.08, 0.1, 0.136), Vector3(0.4, 0.122, 0.162), Vector3(0.72, 0.135, 0.182), Vector3(0.94, 0.14, 0.19), Vector3(1, 0.14, 0.19)]
	_prof(mb, bot, top, pr, bc, 20, 3, false, false, fn, Vector3.RIGHT)
	_disc_y(mb, bot, 0.124, 0.088, 0.012, bc.darkened(0.3), 14)
	for t in [0.0, 0.72]:
		var q = []
		var e: Vector3 = pr[0] if t == 0.0 else pr[3]
		var c = bot.lerp(top, 0.02 if t == 0.0 else float(e.x))
		for k in 16:
			var a = TAU * k / 16.0
			q.append(c + _p(sin(a) * (e.z + 0.004), 0, cos(a) * (e.y + 0.004)))
		_cord(mb, q, 0.0052 if t > 0.0 else 0.008, bc.darkened(0.2), true, 1)
	for k in 6:   # dış bambu dikmeler
		var a = TAU * (k + 0.5) / 6.0
		var q = []
		for e in pr:
			q.append(bot.lerp(top, e.x) + _p(sin(a) * (e.z + 0.006), 0, cos(a) * (e.y + 0.006)))
		_cord(mb, q, 0.0048, bc.lightened(0.28), false, 1)
	var rim = []
	for k in 16:
		var a = TAU * k / 16.0
		rim.append(top + _p(sin(a) * 0.198, 0.004 * sin(a * 5.0), cos(a) * 0.145))
	_cord(mb, rim, 0.0115, ROPE.darkened(0.08), true, 1)
	for k in 12:   # burgulu halat çizgisi
		var a = TAU * k / 12.0
		var p = top + _p(sin(a) * 0.204, 0.011 * sin(k * 2.4), cos(a) * 0.151)
		_seg(mb, p + _p(0, -0.006, 0), p + _p(0, 0.006, 0), 0.0035, 0.0035, ROPE.darkened(0.3), Vector3.FORWARD)
	_prof(mb, top + _p(0, -0.04, 0), top + _p(0, 0.005, 0), [Vector3(0, 0.122, 0.17), Vector3(1, 0.13, 0.18)], Color(0.09, 0.07, 0.05), 14, 1, true, false, Callable(), Vector3.RIGHT)
	var cl = Color(0.4, 0.45, 0.58)   # içindeki bohça, ot demeti
	mb.add("sphere", top + _p(-0.055, 0.03, 0.01), Vector3(0.17, 0.11, 0.14), cl, Vector3(0, 0, 8), 8)
	_cord(mb, [top + _p(-0.055, 0.086, 0.0), top + _p(-0.05, 0.06, -0.068), top + _p(-0.055, 0.0, -0.075)], 0.004, PAPER, false, 2)
	for k in 7:
		var x = 0.05 + k * 0.012
		var tip = top + _p(x + k * 0.006 - 0.02, 0.12 + (k % 3) * 0.018, 0.012 * (k % 3 - 1))
		_seg(mb, top + _p(x, -0.01, 0.01 * (k % 2)), tip, 0.0065, 0.0026, Color(0.45, 0.52, 0.24).darkened((k % 2) * 0.2), Vector3.FORWARD)
	_ring(mb, top + _p(0.085, 0.045, 0), Vector3(0.05, 1, 0), 0.03, 0.003, ROPE, 8)
	_straps(mb, b, y + 0.12, y - 0.13, 0.08, 0.09, 0.026, ROPE.darkened(0.12))
	for s in [-1.0, 1.0]:
		var q = _p(s * 0.08, y + 0.125, b.back(y + 0.125))
		_cord(mb, [q, q + _p(0, 0.02, -0.04), top + _p(s * 0.08, -0.002, 0.135)], 0.005, ROPE.darkened(0.12), false, 2)


## Fūma shuriken dalı: dar boyun, geniş karın, kancalı uç, açık renk kesici yüz (refs/shuriken)
static func _fuma_blade(mb, xf: Transform3D, L: float, col: Color) -> void:
	var k = L / 0.47
	var o = [Vector2(-0.016, 0.05), Vector2(-0.02, 0.12), Vector2(-0.05, 0.2), Vector2(-0.068, 0.29), Vector2(-0.058, 0.37), Vector2(-0.018, 0.44), Vector2(0.032, 0.47), Vector2(0.008, 0.39), Vector2(0.006, 0.3), Vector2(0.024, 0.2), Vector2(0.024, 0.13), Vector2(0.018, 0.05)]
	var e = [Vector2(0.032, 0.47), Vector2(0.008, 0.39), Vector2(0.006, 0.3), Vector2(0.024, 0.2), Vector2(0.012, 0.2), Vector2(-0.012, 0.3), Vector2(-0.014, 0.39)]
	var s1 = []
	for q in o:
		s1.append(q * k)
	var s2 = []
	for q in e:
		s2.append(q * k)
	_plate(mb, s1, 0.0095, col, xf)
	_plate(mb, s2, 0.0115, col.lightened(0.5), xf)
	for j in 3:
		_seg(mb, xf * (_p(-0.038 - j * 0.004, 0.2 + j * 0.04, 0.005) * k), xf * (_p(-0.03 - j * 0.004, 0.215 + j * 0.04, 0.005) * k), 0.002, 0.001, col.darkened(0.45), xf.basis.z)


## Sırt shurikeni: dalları makas gibi kısmen kapatılmış, göbek halkasından kayışa asılı (kanonda katlanır)
static func _fuma(mb, b, bc: Color) -> void:
	_sash(mb, b, 1.0, 0.032, LEATHER, LEATHER_D)
	var y = -0.06
	var c = _p(0, y, b.back(y) - 0.055)
	var open = 0.42
	for i in 4:
		var ang = [-open, open, PI - open, PI + open][i]
		var dz = 0.0065 if i % 2 == 0 else -0.0065
		var xf = Transform3D(Basis(Vector3.BACK, ang), c + _p(0, 0, dz))
		_fuma_blade(mb, xf, 0.36, bc)
		var r0 = xf * _p(0, 0.05, 0)
		var r1 = xf * _p(0, 0.084, 0)
		_seg(mb, r0, r1, 0.046, 0.012, bc.darkened(0.2), Vector3.BACK)
	_ring(mb, c, Vector3.BACK, 0.05, 0.012, bc.darkened(0.25), 16)
	_ring(mb, c + _p(0, 0, -0.012), Vector3.BACK, 0.059, 0.0032, bc.lightened(0.25), 16)
	for k in 4:
		var a = PI * 0.25 + k * PI * 0.5
		_rivet(mb, c + _p(cos(a) * 0.047, sin(a) * 0.047, -0.018), Vector3.FORWARD, 0.0052, IRON)
	# göbekten geçen deri bağ
	var tp = _p(0.018, y + 0.08, b.back(y + 0.08) - 0.004)
	var lw = _p(-0.024, y - 0.08, b.back(y - 0.08) - 0.004)
	_band(mb, [tp, c + _p(0.012, 0.062, -0.024), c, c + _p(-0.012, -0.062, 0.02), lw], 0.024, 0.005, LEATHER_D, false, 2, LEATHER)
	_buckle(mb, tp + _p(0.0, -0.016, -0.006), Vector3.FORWARD, Vector3.UP)


## Dev tespih (refs/tespih: on iki iri boncuk, aralarda küçük boncuklar); boyundan göğse iner, püsküllü
static func _tespih(mb, b, bc: Color, d: Dictionary) -> void:
	var N = 12
	var dip = 0.2
	var pts = []
	for k in 28:
		pts.append(_boyun(b, TAU * k / 28.0, dip, 0.012))
	_cord(mb, pts, 0.0028, Color(0.15, 0.12, 0.1), true, 1)
	for k in N:
		var a = TAU * k / float(N)
		var big = k == 0
		var R = 0.033 if big else 0.0265
		var p = _boyun(b, a, dip, 0.012 + R * 0.55)
		var col = bc.lightened(0.18) if big else bc.lerp(bc.lightened(0.12), float(k % 2))
		mb.add("sphere", p, Vector3.ONE * R * 2.0, col, Vector3(0, k * 25.0, 0), 8)
		for j in 2:
			var a2 = a + TAU / N * (j + 1) / 3.0
			mb.add("sphere", _boyun(b, a2, dip, 0.016), Vector3.ONE * 0.019, bc.darkened(0.2), Vector3.ZERO, 6)
	var f = _boyun(b, 0.0, dip, 0.012 + 0.018)
	var kn = f + _p(0, -0.05, 0.004)
	_cord(mb, [f + _p(0, -0.02, 0), kn], 0.005, RED, false, 1)
	mb.add("sphere", kn, Vector3.ONE * 0.025, RED, Vector3.ZERO, 6)
	_ring(mb, kn + _p(0, -0.014, 0), Vector3.UP, 0.009, 0.0022, BRASS, 6)
	for s in [-1.0, 1.0]:
		_dang(d, kn + _p(s * 0.003, -0.016, 0), _p(s * 0.08, -1, 0.08), 0.1, 0.018, RED, 0.16, 0.003, 0.2)
