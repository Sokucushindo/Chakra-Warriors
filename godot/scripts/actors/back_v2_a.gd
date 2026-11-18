extends RefCounted
## Sırt eşyaları yeniden yapımı, grup a (hedef: res://scripts/actors/back_v2_a.gd).
## Bütün parçalar model uzayında kurulur (+Z ön, -Z sırt, +X karakterin solu). Kayışlar gövde köşelerinden ölçülen
## kesit halkalarını izler. Bitmiş ağ tür + cinsiyet + renk + giysi payı başına bir kez kurulur (kalabalıkta NPC maliyeti yok).
## Kaynaklar: refs/kabak, refs/kingin, refs/dev_yelpaze, refs/parsomen, refs/bel_parsomen, refs/genis_kesici,
## refs/sargili_kilic, refs/kusarigama_bel, refs/kunai_kilif_seti, refs/joki_no_yoroi, refs/chakura_yoroi,
## refs/mugen_kogai, refs/shodai_kubikazari.

const KINDS := ["kemer", "kemer_canta", "bel_parsomen", "benihisago", "chakura_yoroi", "parsomen", "ip_kangal", "joki_ocak",
	"kin", "kohaku", "kokinjo", "kabak", "mugen_kogai", "sake", "sashimono", "shodai_kubikazari",
	"dev_yelpaze", "kunai_kilif_seti", "ikiz_katana", "nodachi", "genis_kesici", "sargili_kilic", "kusarigama_bel", "bo_asa"]

const BINS := 32
const OUT := Vector3(0, 0, -1)   # sırttan dışarı

const LEATHER := Color(0.33, 0.21, 0.12)
const LEATHER_D := Color(0.2, 0.13, 0.08)
const STRAP := Color(0.27, 0.19, 0.12)
const THREAD := Color(0.72, 0.63, 0.46)
const IRON := Color(0.27, 0.28, 0.31)
const IRON_D := Color(0.13, 0.13, 0.15)
const STEEL := Color(0.66, 0.69, 0.73)
const STEEL_L := Color(0.86, 0.88, 0.9)
const BRASS := Color(0.68, 0.52, 0.24)
const ROPE := Color(0.7, 0.61, 0.44)
const ROPE_D := Color(0.5, 0.42, 0.29)
const PAPER := Color(0.88, 0.83, 0.68)
const NAVY := Color(0.14, 0.18, 0.36)
const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_D := Color(0.24, 0.15, 0.09)
const INK := Color(0.06, 0.06, 0.07)
const SAME := Color(0.86, 0.84, 0.76)

static var _loops := {}
static var _meshes := {}


static func build(m, kind: String, bc: Color, ch: Vector3, hip: Vector3, toon: Material) -> bool:
	if not kind in KINDS:
		return false
	var pad = _pad(m)
	var key = "%s|%s|%s|%.3f" % [kind, str(m.look.get("gender", "m")), bc.to_html(), pad]
	if not _meshes.has(key):
		var c = {"m": m, "u": MB.new(), "h": MB.new(), "bc": bc, "ch": ch, "hip": hip, "pad": pad, "dg": []}
		match kind:
			"kemer": _kemer(c)
			"kemer_canta": _kemer_canta(c)
			"bel_parsomen": _bel_parsomen(c)
			"benihisago": _benihisago(c)
			"chakura_yoroi": _chakura(c)
			"parsomen": _parsomen(c)
			"ip_kangal": _ip_kangal(c)
			"joki_ocak": _joki(c)
			"kin": _kin(c)
			"kohaku": _kohaku(c)
			"kokinjo": _kokinjo(c)
			"kabak": _kabak(c)
			"mugen_kogai": _mugen(c)
			"sake": _sake(c)
			"sashimono": _sashimono(c)
			"shodai_kubikazari": _shodai(c)
			"dev_yelpaze": _yelpaze(c)
			"kunai_kilif_seti": _kunai_seti(c)
			"ikiz_katana": _ikiz(c)
			"nodachi": _nodachi(c)
			"genis_kesici": _kesici(c)
			"sargili_kilic": _sargili(c)
			"kusarigama_bel": _kusarigama(c)
			"bo_asa": _bo(c)
		var um: MB = c["u"]
		var hm: MB = c["h"]
		_meshes[key] = [null if um.is_empty() else um.build(toon), null if hm.is_empty() else hm.build(toon), c["dg"]]
	var e: Array = _meshes[key]
	if e[0] != null:
		m._mesh_on("UpperChest", e[0], Transform3D.IDENTITY)
	if e[1] != null:
		m._mesh_on("Hips", e[1], Transform3D.IDENTITY)
	for d in e[2]:
		m.dangle_strip(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])
	return true


# ------------------------------------------------------------------ gövde ölçümü
static func _pad(m) -> float:
	var p = 0.016
	if m.look.get("vest") != null:
		p += 0.03
	if m.look.get("outer_style") != null:
		p += 0.035
	return p


## c merkezli, e1-e2 düzleminde gövdenin dış kesiti. Açı: e1 yönünde 0, e2 yönünde 90 derece.
static func _loop(m, c: Vector3, e1: Vector3, e2: Vector3, xlim := 0.2, ymin := -9.0, ymax := 9.0) -> Dictionary:
	var key = "%s|%.3f|%.3f|%.3f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f" % [str(m.look.get("gender", "m")), c.x, c.y, c.z, e1.x, e1.y, e1.z, e2.x, e2.y, e2.z, xlim, ymin, ymax]
	if _loops.has(key):
		return _loops[key]
	var n: Vector3 = e1.cross(e2).normalized()
	var r := PackedFloat32Array()
	r.resize(BINS)
	r.fill(0.0)
	if m.body_mesh != null and m.body_mesh.mesh != null:
		var vs: PackedVector3Array = m._body_vs()
		for v in vs:
			if absf(v.x) > xlim or v.y < ymin or v.y > ymax:
				continue
			var d: Vector3 = v - c
			if absf(d.dot(n)) > 0.016:
				continue
			var px = d.dot(e1)
			var py = d.dot(e2)
			var q = sqrt(px * px + py * py)
			var b = int(fposmod(atan2(py, px) / TAU, 1.0) * BINS) % BINS
			if q > r[b]:
				r[b] = q
	var known := []
	for i in BINS:
		if r[i] > 0.0:
			known.append(i)
	if known.is_empty():
		r.fill(0.14)
	else:
		var src := r.duplicate()
		for i in BINS:
			if src[i] > 0.0:
				continue
			var a = 1
			while src[posmod(i - a, BINS)] <= 0.0:
				a += 1
			var b = 1
			while src[posmod(i + b, BINS)] <= 0.0:
				b += 1
			r[i] = lerpf(src[posmod(i - a, BINS)], src[posmod(i + b, BINS)], float(a) / (a + b))
	for _p2 in 2:
		var s := r.duplicate()
		for i in BINS:
			r[i] = maxf(s[i], (s[posmod(i - 1, BINS)] + s[i] * 2.0 + s[(i + 1) % BINS]) * 0.25)
	var l = {"c": c, "e1": e1, "e2": e2, "r": r}
	_loops[key] = l
	return l


static func _ring(m, y: float, xlim := 0.2) -> Dictionary:
	return _loop(m, Vector3(0, snappedf(y, 0.001), 0), Vector3.BACK, Vector3.RIGHT, xlim)


static func _dir(l: Dictionary, a: float) -> Vector3:
	return (l["e1"] as Vector3) * cos(a) + (l["e2"] as Vector3) * sin(a)


static func _lp(l: Dictionary, a: float, off := 0.0) -> Vector3:
	var r: PackedFloat32Array = l["r"]
	var t = fposmod(a / TAU * BINS - 0.5, float(BINS))
	var i = int(t) % BINS
	var rr = lerpf(r[i], r[(i + 1) % BINS], t - floorf(t))
	return (l["c"] as Vector3) + _dir(l, a) * (rr + off)


## Halka üzerinde teğet (a artarken)
static func _tan(l: Dictionary, a: float) -> Vector3:
	return (l["e2"] as Vector3) * cos(a) - (l["e1"] as Vector3) * sin(a)


static func _arc(l: Dictionary, a0: float, a1: float, n: int, off := 0.0) -> Array:
	var out := []
	for k in n + 1:
		out.append(_lp(l, lerpf(a0, a1, float(k) / n), off))
	return out


## Sırt yüzeyi z (x, y noktasında), giysi payı hariç
static func _back(m, x: float, y: float) -> float:
	return _lp(_ring(m, y), PI - atan2(x, 0.11)).z


# ------------------------------------------------------------------ yapı taşları
static func _ax(y: Vector3) -> Basis:
	var n = y.normalized()
	var r = Vector3.BACK if absf(n.z) < 0.9 else Vector3.UP
	var x = n.cross(r).normalized()   # dik eksende x = sağ/sol, z = ön/arka; sırt düzlemindeki eksende x = yan, z = derinlik
	return Basis(x, n, x.cross(n).normalized())


static func _p(mb: MB, kind: String, c: Vector3, axis: Vector3, size: Vector3, col: Color, seg := 8) -> void:
	mb.add_xf(kind, Transform3D(_ax(axis) * Basis.from_scale(size), c), col, seg)


static func _bx(mb: MB, c: Vector3, u: Vector3, v: Vector3, size: Vector3, col: Color) -> void:
	mb.add_xf("box", Transform3D(Basis(u, v, u.cross(v)) * Basis.from_scale(size), c), col, 8)


## Yassı profil düzlemi: (px, py) -> o + u px + v py, kalınlık u x v yönünde
static func _pl(o: Vector3, u: Vector3, v: Vector3) -> Transform3D:
	return Transform3D(Basis(u.cross(v), u, v), o)


static func _rr(w: float, h: float, r: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	var cs = [[w * 0.5 - r, h * 0.5 - r, 0.0], [-w * 0.5 + r, h * 0.5 - r, PI * 0.5], [-w * 0.5 + r, -h * 0.5 + r, PI], [w * 0.5 - r, -h * 0.5 + r, PI * 1.5]]
	for c in cs:
		for k in 3:
			var a = c[2] + k * PI * 0.25
			o.append(Vector2(c[0] + cos(a) * r, c[1] + sin(a) * r))
	return o


static func _circle(r: float, n := 12) -> PackedVector2Array:
	var o := PackedVector2Array()
	for k in n:
		var a = TAU * k / n
		o.append(Vector2(cos(a), sin(a)) * r)
	return o


## Yassı şerit: wd genişlik yönü
static func _rib(mb: MB, pts: Array, w: float, t: float, col, wd: Vector3, seg := 6, caps := false) -> void:
	var T: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var wn: Vector3 = (wd - T * wd.dot(T)).normalized()
	var r := []
	for _i in pts.size():
		r.append(Vector2(w * 0.5, t * 0.5))
	_loft(mb, pts, r, col, seg, 1, caps, Callable(), T.cross(wn))


## Süpürme gövdesi. Oyunun Loft'u yarıçapı 1 cm altına indirmez; kayış ve ip için bu sürüm sınırsızdır.
static func _loft(mb: MB, pts: Array, rad: Array, col, seg := 8, sub := 1, caps := true, fn := Callable(), up := Vector3.UP) -> void:
	var n = pts.size()
	if n < 2:
		return
	var R0 := []
	var C0 := []
	for i in n:
		R0.append(rad[i] if rad[i] is Vector2 else Vector2(float(rad[i]), float(rad[i])))
		C0.append(col[i] if col is Array else col)
	var P := []
	var RR := []
	var CC := []
	for i in n - 1:
		for k in sub:
			var t = float(k) / sub
			P.append(Loft._cr(pts[maxi(0, i - 1)], pts[i], pts[i + 1], pts[mini(n - 1, i + 2)], t))
			var q: Vector2 = Loft._cr(R0[maxi(0, i - 1)], R0[i], R0[i + 1], R0[mini(n - 1, i + 2)], t)
			RR.append(Vector2(maxf(q.x, 0.0005), maxf(q.y, 0.0005)))
			CC.append((C0[i] as Color).lerp(C0[i + 1], t))
	P.append(pts[n - 1])
	RR.append(R0[n - 1])
	CC.append(C0[n - 1])
	var c = P.size()
	var L := PackedFloat32Array()
	L.resize(c)
	for i in range(1, c):
		L[i] = L[i - 1] + (P[i] as Vector3).distance_to(P[i - 1])
	var total = maxf(L[c - 1], 0.0001)
	var T := []
	for i in c:
		var d: Vector3 = (P[mini(c - 1, i + 1)] as Vector3) - (P[maxi(i - 1, 0)] as Vector3)
		T.append(d.normalized() if d.length() > 0.00001 else Vector3.FORWARD)
	var side: Vector3 = up.cross(T[0])
	if side.length() < 0.1:
		side = Vector3.RIGHT.cross(T[0])
	side = side.normalized()
	var rings := []   # merkez, yan, normal, yarıçap, renk, t, uç eğimi
	for i in c:
		var ti: Vector3 = T[i]
		side = (side - ti * side.dot(ti)).normalized()
		rings.append([P[i], side, ti.cross(side).normalized(), RR[i], CC[i], L[i] / total, 0.0])
	if caps:
		var a0: Array = rings[0]
		var a1: Array = rings[-1]
		var r0: Vector2 = a0[3]
		var r1: Vector2 = a1[3]
		var h0 = minf(r0.x, r0.y) * 0.6
		var h1 = minf(r1.x, r1.y) * 0.6
		var t0: Vector3 = T[0]
		var t1: Vector3 = T[c - 1]
		rings.push_front([(a0[0] as Vector3) - t0 * h0 * 0.72, a0[1], a0[2], r0 * 0.62, a0[4], 0.0, -0.75])
		rings.push_front([(a0[0] as Vector3) - t0 * h0, a0[1], a0[2], r0 * 0.04, a0[4], 0.0, -1.0])
		rings.append([(a1[0] as Vector3) + t1 * h1 * 0.72, a1[1], a1[2], r1 * 0.62, a1[4], 1.0, 0.75])
		rings.append([(a1[0] as Vector3) + t1 * h1, a1[1], a1[2], r1 * 0.04, a1[4], 1.0, 1.0])
	var base = mb.verts.size()
	var has_fn = fn.is_valid()
	var fw: Vector3 = T[0]
	var bw: Vector3 = T[c - 1]
	for rg in rings:
		var ctr: Vector3 = rg[0]
		var sd: Vector3 = rg[1]
		var nm: Vector3 = rg[2]
		var rr: Vector2 = rg[3]
		var tilt = float(rg[6])
		for j in seg + 1:
			var a = TAU * float(j) / seg
			var ca = cos(a)
			var sa = sin(a)
			var nrm: Vector3 = (sd * ca / maxf(rr.x, 0.0005) + nm * sa / maxf(rr.y, 0.0005)).normalized()
			if tilt != 0.0:
				nrm = (nrm * (1.0 - absf(tilt)) + (bw if tilt > 0.0 else fw) * tilt).normalized()
			mb.verts.append(ctr + sd * ca * rr.x + nm * sa * rr.y)
			mb.normals.append(nrm)
			mb.colors.append(fn.call(float(rg[5]), wrapf(a, -PI, PI), sd * ca + nm * sa) if has_fn else rg[4])
			mb.uvs.append(Vector2(float(j) / seg, float(rg[5])))
	var rs = seg + 1
	for ri in rings.size() - 1:
		for j in seg:
			var q0 = base + ri * rs + j
			var q1 = q0 + rs
			mb.idx.append_array([q0, q1, q0 + 1, q0 + 1, q1, q1 + 1])


static func _tube(mb: MB, pts: Array, r: float, col, seg := 5, sub := 1) -> void:
	var rr := []
	for _i in pts.size():
		rr.append(r)
	_loft(mb, pts, rr, col, seg, sub)


## prof: [[eksen konumu, yarıçap], ...]
static func _lathe(mb: MB, o: Vector3, ax: Vector3, prof: Array, col, seg := 14, sub := 2, fn := Callable()) -> void:
	var pts := []
	var rr := []
	for q in prof:
		pts.append(o + ax * float(q[0]))
		rr.append(float(q[1]))
	_loft(mb, pts, rr, col, seg, sub, true, fn)


static func _prof_r(prof: Array, h: float) -> float:
	for i in prof.size() - 1:
		var a = prof[i]
		var b = prof[i + 1]
		if h <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0))
	return float(prof[-1][1])


## Dönel gövde üzerine yapışık çizgi; th açı (0 = ex yönü), h eksen konumu
static func _surf(mb: MB, s: Dictionary, th0: float, h0: float, th1: float, h1: float, w: float, col: Color) -> void:
	var o: Vector3 = s["o"]
	var ax: Vector3 = s["ax"]
	var ex: Vector3 = s["ex"]
	var ez: Vector3 = s["ez"]
	var prof: Array = s["prof"]
	var d0: Vector3 = ex * cos(th0) + ez * sin(th0)
	var d1: Vector3 = ex * cos(th1) + ez * sin(th1)
	var p0: Vector3 = o + ax * h0 + d0 * (_prof_r(prof, h0) + 0.002)
	var p1: Vector3 = o + ax * h1 + d1 * (_prof_r(prof, h1) + 0.002)
	var e: Vector3 = p1 - p0
	var ln = e.length()
	if ln < 0.0005:
		return
	var u: Vector3 = e / ln
	var n: Vector3 = (d0 + d1).normalized()
	n = (n - u * n.dot(u)).normalized()
	_bx(mb, (p0 + p1) * 0.5, u, n.cross(u), Vector3(ln + w * 0.7, w, 0.005), col)


static func _surf_frame(o: Vector3, ax: Vector3, prof: Array) -> Dictionary:
	var ex: Vector3 = (OUT - ax * OUT.dot(ax)).normalized()
	return {"o": o, "ax": ax, "ex": ex, "ez": ax.cross(ex).normalized(), "prof": prof}


## Bükülü ip: yol çevresinde dönen kollar
static func _rope(mb: MB, path: Array, r: float, c0: Color, c1: Color, twist: float, strands := 2, seg := 4) -> void:
	var n = path.size()
	var tang := []
	for i in n:
		tang.append(((path[mini(i + 1, n - 1)] as Vector3) - (path[maxi(i - 1, 0)] as Vector3)).normalized())
	var side: Vector3 = (tang[0] as Vector3).cross(Vector3.UP if absf((tang[0] as Vector3).y) < 0.9 else Vector3.RIGHT).normalized()
	var ss := []
	for i in n:
		var t: Vector3 = tang[i]
		side = (side - t * side.dot(t)).normalized()
		ss.append(side)
	for st in strands:
		var pts := []
		var rr := []
		var ph = TAU * st / strands
		for i in n:
			var t: Vector3 = tang[i]
			var s: Vector3 = ss[i]
			var a = ph + twist * float(i) / maxf(n - 1, 1)
			pts.append((path[i] as Vector3) + (s * cos(a) + t.cross(s) * sin(a)) * r * 0.5)
			rr.append(r * 0.66)
		_loft(mb, pts, rr, c0 if st % 2 == 0 else c1, seg, 1)


static func _dangle(c: Dictionary, bone: String, root: Vector3, dir: Vector3, ln: float, w: float, col: Color, stiff := 0.2, side := Vector3.ZERO, thick := 0.004) -> void:
	(c["dg"] as Array).append([bone, root, dir, ln, w, col, stiff, side, thick])


static func _stitch(mb: MB, a: Vector3, b: Vector3, n: int, nrm: Vector3, col := THREAD) -> void:
	var u: Vector3 = (b - a).normalized()
	var v: Vector3 = nrm.cross(u).normalized()
	var ln = a.distance_to(b) / n
	for k in n:
		_bx(mb, a.lerp(b, (k + 0.5) / n), u, v, Vector3(ln * 0.6, 0.0028, 0.002), col)


static func _rivet(mb: MB, c: Vector3, n: Vector3, r := 0.006, col := BRASS) -> void:
	_p(mb, "sphere", c, n, Vector3(r * 2.0, r, r * 2.0), col, 6)


## Kemer: gövdeyi izleyen deri, toka önde. Halkayı döndürür.
static func _belt(mb: MB, c: Dictionary, y: float, w: float, col: Color) -> Dictionary:
	var l = _ring(c["m"], y)
	var off = float(c["pad"]) * 0.75
	_rib(mb, _arc(l, 0.0, TAU, 26, off), w, 0.006, col, Vector3.UP)
	var f: Vector3 = _lp(l, 0.0, off + 0.004)
	mb.add_slab(MB.hole(_rr(w * 1.25, w * 1.3, 0.006), Vector2.ZERO, w * 0.3, 8), 0.005, BRASS, _pl(f, Vector3.RIGHT, Vector3.UP))
	_bx(mb, f + Vector3.BACK * 0.002, Vector3.RIGHT, Vector3.UP, Vector3(w * 0.75, 0.005, 0.005), BRASS.darkened(0.2))
	return l


## Kapaklı deri cep. o: arka yüz ortası, t yatay teğet, n dışa
static func _pouch(mb: MB, o: Vector3, t: Vector3, n: Vector3, w: float, h: float, d: float, col: Color) -> void:
	var up: Vector3 = n.cross(t).normalized()
	var pillow = func(p: Vector2) -> float:
		return d * (0.62 + 0.38 * (1.0 - pow(absf(p.x) / (w * 0.5), 2.0)))
	mb.add_slab(_rr(w, h, 0.012), d, col, _pl(o + n * d * 0.5, t, up), pillow, col.darkened(0.22))
	var fl := PackedVector2Array([Vector2(-w * 0.53, h * 0.53), Vector2(w * 0.53, h * 0.53), Vector2(w * 0.53, h * 0.05), Vector2(w * 0.16, -h * 0.17), Vector2(-w * 0.16, -h * 0.17), Vector2(-w * 0.53, h * 0.05)])
	var fc: Color = col.darkened(0.14)
	mb.add_slab(fl, 0.006, fc, _pl(o + n * (d + 0.003), t, up), Callable(), fc.darkened(0.25))
	_rivet(mb, o + n * (d + 0.0075) - up * h * 0.1, n, 0.0075)
	_stitch(mb, o + n * (d + 0.0065) + up * h * 0.03 - t * w * 0.46, o + n * (d + 0.0065) + up * h * 0.03 + t * w * 0.46, 7, n)


## Üzerinde kâğıt bant ve sarılı uçları olan parşömen
static func _scroll(mb: MB, a: Vector3, b: Vector3, r: float, paper: Color, band: Color) -> void:
	var ax: Vector3 = (b - a).normalized()
	var ln = a.distance_to(b)
	var fn = func(t: float, _ang: float, _d: Vector3) -> Color:
		if absf(t - 0.5) < 0.2:
			return band
		return paper if fmod(t * 9.0, 1.0) > 0.08 else paper.darkened(0.08)
	_lathe(mb, a, ax, [[0.0, r * 0.98], [ln * 0.02, r], [ln * 0.28, r], [ln * 0.3, r * 1.01], [ln * 0.5, r * 1.01], [ln * 0.7, r * 1.01], [ln * 0.72, r], [ln * 0.98, r], [ln, r * 0.98]], paper, 12, 1, fn)
	for e in [[a, -ax], [b, ax]]:
		var o: Vector3 = e[0]
		var d: Vector3 = e[1]
		_p(mb, "cyl", o + d * r * 0.42, d, Vector3(r * 1.5, 0.006, r * 1.5), paper.darkened(0.16), 10)
		_p(mb, "torus", o + d * r * 0.46, d, Vector3(r * 1.25, 0.012, r * 1.25), paper.darkened(0.34), 10)
		_p(mb, "cyl", o + d * r * 0.5, d, Vector3(r * 0.55, 0.02, r * 0.55), WOOD_D, 8)


## Sırt taşıma takımı: iki omuz kayışı + göğüs altı halkası
static func _harness(c: Dictionary, w := 0.028, col := STRAP, low := -0.13, x0 := 0.112) -> void:
	var m = c["m"]
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var off = float(c["pad"])
	for s in [-1.0, 1.0]:
		var l = _loop(m, Vector3(s * x0, ch.y - 0.02, 0.0), Vector3.BACK, Vector3.UP, 0.22, ch.y - 0.3, ch.y + 0.2)
		_rib(u, _arc(l, -0.85, PI + 0.8, 14, off), w, 0.005, col, Vector3.RIGHT, 4)
		var e: Vector3 = _lp(l, PI + 0.8, off + 0.003)
		_p(u, "torus", e, Vector3.BACK, Vector3(0.036, 0.03, 0.036), IRON, 8)
		var f: Vector3 = _lp(l, -0.85, off + 0.003)
		_p(u, "torus", f, Vector3.BACK, Vector3(0.036, 0.03, 0.036), IRON, 8)
	_rib(u, _arc(_ring(m, ch.y + low), 0.0, TAU, 18, off), w * 0.85, 0.005, col, Vector3.UP, 4)


## Çapraz kayış. sx: kayışın çıktığı omuz. Sırttaki orta nokta "b", eksen "ax" (omza doğru), "sd" yan.
static func _sling(c: Dictionary, sx: float, w: float, col: Color, seg := 6) -> Dictionary:
	var l = _sl_loop(c, sx)
	var e2: Vector3 = l["e2"]
	var off = float(c["pad"])
	var nr: Vector3 = Vector3.BACK.cross(e2).normalized()
	_rib(c["u"], _arc(l, 0.0, TAU, 26, off), w, 0.005, col, nr, seg)
	return {"l": l, "ax": e2, "sd": nr, "b": _lp(l, PI, off + 0.003)}


## Omuzdan karşı kaburgaya inen kesit (kalçaya kadar inmez)
static func _sl_loop(c: Dictionary, sx: float) -> Dictionary:
	var ch: Vector3 = c["ch"]
	return _loop(c["m"], Vector3(0.0, ch.y - 0.03, 0.0), Vector3.BACK, Vector3(sx * 0.115, 0.17, 0.0).normalized(), 0.215, ch.y - 0.3, ch.y + 0.2)


## Kın: q ağız, d uca doğru, n sırttan dışa
static func _saya(mb: MB, q: Vector3, d: Vector3, n: Vector3, ln: float, col: Color, rd := 0.017, rw := 0.03) -> void:
	var T: Vector3 = d.normalized()
	var pts := []
	var rr := []
	for e in [[0.0, 1.04], [0.03, 1.0], [0.5, 0.96], [0.93, 0.86], [1.0, 0.74]]:
		pts.append(q + T * ln * float(e[0]))
		rr.append(Vector2(rd, rw) * float(e[1]))
	_loft(mb, pts, rr, col, 8, 2, true, Callable(), T.cross(n))
	var w: Vector3 = n.cross(T).normalized()
	_p(mb, "cyl", q + T * 0.012, T, Vector3(rw * 2.25, 0.024, rd * 2.3), SAME.darkened(0.25), 8)   # ağız bileziği
	_p(mb, "cone", q + T * (ln + 0.012), T, Vector3(rw * 1.45, 0.05, rd * 1.5), IRON, 8)   # uç koruması
	_p(mb, "cyl", q + T * (ln * 0.965), T, Vector3(rw * 1.68, 0.03, rd * 1.9), IRON, 8)
	_bx(mb, q + T * 0.13 + n * (rd + 0.002), T, w, Vector3(0.03, 0.012, 0.012), col.lightened(0.15))   # kurikata
	for k in 3:
		_p(mb, "torus", q + T * (0.1 + k * 0.03), T, Vector3(rw * 2.3, 0.05, rd * 2.5), Color(0.55, 0.46, 0.3), 8)   # sageo


## Sap: q tsuba, h sap ucuna doğru
static func _tsuka(mb: MB, q: Vector3, h: Vector3, n: Vector3, ln: float, ito: Color, rd := 0.015, rw := 0.021, r_guard := 0.044) -> void:
	var T: Vector3 = h.normalized()
	var w: Vector3 = n.cross(T).normalized()
	_loft(mb, [q, q + T * ln * 0.5, q + T * ln], [Vector2(rd, rw), Vector2(rd, rw) * 0.94, Vector2(rd, rw) * 1.02], ito, 8, 2, false, Callable(), T.cross(n))
	mb.add_slab(MB.hole(_circle(r_guard, 10), Vector2(r_guard * 0.45, 0.0), r_guard * 0.14, 6), 0.007, IRON_D, _pl(q, w, n), Callable(), BRASS)
	_p(mb, "cyl", q + T * 0.012, T, Vector3(rw * 2.25, 0.022, rd * 2.3), BRASS, 8)
	_p(mb, "sphere", q + T * ln, T, Vector3(rw * 2.2, 0.03, rd * 2.3), IRON_D, 8)
	var cnt = int(ln / 0.042)
	for k in cnt:
		var c0: Vector3 = q + T * (0.04 + k * 0.042)
		for s in [-1.0, 1.0]:
			_bx(mb, c0 + n * s * rd * 0.98, (T + w).normalized(), (w - T).normalized() * s, Vector3(0.019, 0.019, 0.003), SAME)


# ------------------------------------------------------------------ bel eşyaları
static func _kemer(c: Dictionary) -> void:
	var h: MB = c["h"]
	var y = float(c["hip"].y) + 0.045
	var off = float(c["pad"]) * 0.75
	var l = _belt(h, c, y, 0.04, c["bc"])
	var bc: Color = c["bc"]
	var i = 0
	for a in [PI - 1.34, PI - 0.74, PI + 0.74, PI + 1.34]:
		var p: Vector3 = _lp(l, a, off + 0.004)
		var w = 0.07 if i == 0 or i == 3 else 0.082
		_pouch(h, p - Vector3.UP * 0.012, _tan(l, a), _dir(l, a), w, 0.09, 0.046, bc.lerp(LEATHER, 0.35))
		_bx(h, p + Vector3.UP * 0.0, _tan(l, a), Vector3.UP, Vector3(0.02, 0.052, 0.012), LEATHER_D)
		i += 1
	var o: Vector3 = _lp(l, PI, off + 0.033) - Vector3.UP * 0.006
	_scroll(h, o + Vector3.RIGHT * 0.07, o - Vector3.RIGHT * 0.07, 0.024, PAPER, Color(0.58, 0.16, 0.13))
	for s in [-1.0, 1.0]:
		var q: Vector3 = o + Vector3.RIGHT * s * 0.043
		_p(h, "cyl", q, Vector3.RIGHT, Vector3(0.054, 0.016, 0.054), LEATHER_D, 8)
		_bx(h, q + Vector3.BACK * 0.022, Vector3.RIGHT, Vector3.UP, Vector3(0.016, 0.06, 0.012), LEATHER_D)


static func _kemer_canta(c: Dictionary) -> void:
	var h: MB = c["h"]
	var bc: Color = c["bc"]
	var y = float(c["hip"].y) + 0.05
	var off = float(c["pad"]) * 0.75
	var l = _belt(h, c, y, 0.034, bc.darkened(0.2))
	# yan cep
	var a = 1.75
	_pouch(h, _lp(l, a, off + 0.004) - Vector3.UP * 0.026, _tan(l, a), _dir(l, a), 0.08, 0.1, 0.05, bc)
	# arka kese: büzgülü ağız, yuvarlak dip
	var o: Vector3 = _lp(l, PI, off + 0.045) - Vector3.UP * 0.05
	var prof = [[-0.075, 0.012], [-0.062, 0.038], [-0.03, 0.058], [0.015, 0.056], [0.05, 0.036], [0.066, 0.021], [0.08, 0.03], [0.092, 0.024]]
	var pts := []
	var rr := []
	for q in prof:
		pts.append(o + Vector3.UP * float(q[0]))
		rr.append(Vector2(float(q[1]) * 1.55, float(q[1]) * 0.8))
	_loft(h, pts, rr, bc.lerp(LEATHER, 0.3), 10, 2, true, Callable(), Vector3.BACK)
	_p(h, "torus", o + Vector3.UP * 0.066, Vector3.UP, Vector3(0.076, 0.012, 0.042), ROPE, 8)
	_bx(h, o + Vector3.UP * 0.06 + Vector3.BACK * 0.028, Vector3.RIGHT, Vector3.UP, Vector3(0.022, 0.07, 0.008), LEATHER_D)
	_dangle(c, "Hips", o + Vector3(0.022, 0.062, -0.035), Vector3(0.1, -1.0, -0.1), 0.1, 0.009, ROPE, 0.3)
	# sarkan kunai kılıfı
	a = PI + 1.3
	var p: Vector3 = _lp(l, a, off + 0.018)
	var t: Vector3 = _tan(l, a)
	var n: Vector3 = _dir(l, a)
	var dn: Vector3 = (Vector3.DOWN + t * 0.1).normalized()
	var sd: Vector3 = dn.cross(n).normalized()
	var sh := PackedVector2Array([Vector2(-0.032, 0.02), Vector2(0.032, 0.02), Vector2(0.03, -0.075), Vector2(0.012, -0.145), Vector2(-0.012, -0.145), Vector2(-0.03, -0.075)])
	h.add_slab(sh, 0.022, bc.darkened(0.12), _pl(p + n * 0.006, sd, -dn), Callable(), LEATHER_D)
	_stitch(h, p + n * 0.0185 + sd * 0.024 - dn * 0.01, p + n * 0.0185 + sd * 0.012 + dn * 0.12, 7, n)
	_stitch(h, p + n * 0.0185 - sd * 0.024 - dn * 0.01, p + n * 0.0185 - sd * 0.012 + dn * 0.12, 7, n)
	_bx(h, p + Vector3.UP * 0.018 + n * 0.0, t, Vector3.UP, Vector3(0.02, 0.05, 0.012), LEATHER_D)
	_kunai_grip(h, p + n * 0.006 - dn * 0.02, -dn, n)


## Kunai sapı: sargılı, halkalı; q kılıf ağzı, d sapa doğru
static func _kunai_grip(mb: MB, q: Vector3, d: Vector3, n: Vector3) -> void:
	_p(mb, "cyl", q + d * 0.045, d, Vector3(0.016, 0.09, 0.016), INK.lightened(0.12), 6)
	for k in 4:
		_p(mb, "cyl", q + d * (0.014 + k * 0.021), d.rotated(n, 0.32), Vector3(0.019, 0.006, 0.019), Color(0.62, 0.6, 0.55), 6)
	_p(mb, "torus", q + d * 0.108, n, Vector3(0.042, 0.034, 0.042), IRON, 8)


static func _bel_parsomen(c: Dictionary) -> void:
	var h: MB = c["h"]
	var y = float(c["hip"].y) + 0.05
	var off = float(c["pad"]) * 0.75
	var l = _belt(h, c, y, 0.034, STRAP)
	var bc: Color = c["bc"]
	for s in [-1.0, 1.0]:
		var a = PI - s * 0.72
		var n: Vector3 = _dir(l, a)
		var t: Vector3 = _tan(l, a)
		var r = 0.034
		var o: Vector3 = _lp(l, a, off + 0.012 + r) - Vector3.UP * 0.032
		var ax: Vector3 = (t * s * -1.0 + Vector3.DOWN * 0.62).normalized()
		var paper: Color = bc if s > 0.0 else NAVY
		var band: Color = Color(0.58, 0.16, 0.13) if s > 0.0 else PAPER
		_scroll(h, o - ax * 0.105, o + ax * 0.105, r, paper, band)
		var v: Vector3 = n.cross(ax).normalized()
		for e in [-0.062, 0.062]:
			_p(h, "cyl", o + ax * e, ax, Vector3(r * 2.2, 0.018, r * 2.2), LEATHER_D, 10)
		var strokes = [[-0.03, 0.018, 0.03, 0.018], [-0.04, 0.0, 0.04, 0.0], [0.0, 0.018, 0.0, 0.0], [0.0, 0.0, -0.034, -0.024], [0.0, 0.0, 0.034, -0.024]]
		var ink: Color = INK if s > 0.0 else PAPER
		for q in strokes:
			var a0: Vector3 = o + ax * float(q[0]) * 0.5 + v * float(q[1])
			var a1: Vector3 = o + ax * float(q[2]) * 0.5 + v * float(q[3])
			var m0: Vector3 = (a0 + a1) * 0.5 + n * (r + 0.0006)
			var e0: Vector3 = (a1 - a0)
			var ln = e0.length()
			_bx(h, m0, e0 / ln, n.cross(e0 / ln), Vector3(ln + 0.004, 0.006, 0.002), ink)
		# belden kaydırılan deri askı: parşömeni kemere gerçekten bağlar
		_bx(h, _lp(l, a, off + 0.012) - Vector3.UP * 0.012, t, Vector3.UP, Vector3(0.03, 0.07, 0.026), LEATHER_D)


static func _ip_kangal(c: Dictionary) -> void:
	var h: MB = c["h"]
	var bc: Color = c["bc"]
	var y = float(c["hip"].y) + 0.04
	var off = float(c["pad"]) * 0.75
	var l = _belt(h, c, y, 0.03, STRAP)
	var a = PI - 1.05
	var n: Vector3 = _dir(l, a)
	var t: Vector3 = _tan(l, a)
	var o: Vector3 = _lp(l, a, off + 0.034) - Vector3.UP * 0.075
	var pts := []
	for k in 56:
		var u = k / 55.0
		var th = u * TAU * 4.0
		var rr = 0.072 + 0.003 * sin(u * 37.0)
		pts.append(o + t * cos(th) * rr + Vector3.UP * sin(th) * rr * 0.96 + n * (u - 0.5) * 0.042)
	var stripe = func(u: float, ang: float, _d: Vector3) -> Color:
		return bc if fmod(u * 150.0 + ang * 0.32 + 20.0, 1.0) > 0.42 else bc.darkened(0.3)
	_loft(h, pts, _const(56, 0.0115), bc, 5, 1, true, stripe)
	for k in 3:   # bağ sargıları
		var th = PI * 0.5 + k * TAU / 3.0
		var q: Vector3 = o + t * cos(th) * 0.075 + Vector3.UP * sin(th) * 0.075
		_p(h, "cyl", q, t * -sin(th) + Vector3.UP * cos(th), Vector3(0.064, 0.02, 0.064), ROPE_D, 8)
	_p(h, "torus", o + Vector3.UP * 0.083 + n * 0.0, n, Vector3(0.04, 0.03, 0.04), IRON, 8)
	_bx(h, _lp(l, a, off + 0.012) - Vector3.UP * 0.002, t, Vector3.UP, Vector3(0.026, 0.06, 0.012), LEATHER_D)
	_dangle(c, "Hips", o + t * 0.06 - Vector3.UP * 0.05 + n * 0.02, Vector3(0.1, -1.0, -0.1), 0.12, 0.014, bc, 0.3, Vector3.ZERO, 0.005)


static func _const(n: int, v) -> Array:
	var a := []
	for _i in n:
		a.append(v)
	return a


static func _sake(c: Dictionary) -> void:
	var h: MB = c["h"]
	var bc: Color = c["bc"]
	var y = float(c["hip"].y) + 0.05
	var off = float(c["pad"]) * 0.75
	var l = _ring(c["m"], y)
	_rib(h, _arc(l, 0.0, TAU, 26, off), 0.018, 0.008, Color(0.45, 0.14, 0.12), Vector3.UP, 4)
	var a = PI - 0.98
	var n: Vector3 = _dir(l, a)
	var t: Vector3 = _tan(l, a)
	var top: Vector3 = _lp(l, a, off + 0.008)
	var o: Vector3 = top + n * 0.058 - Vector3.UP * 0.155
	var ax: Vector3 = (Vector3.UP + t * 0.12).normalized()
	var prof = [[-0.085, 0.006], [-0.078, 0.034], [-0.05, 0.056], [-0.018, 0.052], [0.015, 0.03], [0.028, 0.027], [0.05, 0.035], [0.07, 0.03], [0.09, 0.014], [0.108, 0.012], [0.116, 0.015]]
	_lathe(h, o, ax, prof, bc, 12, 2)
	_lathe(h, o + ax * 0.116, ax, [[0.0, 0.012], [0.014, 0.014], [0.024, 0.009]], Color(0.2, 0.08, 0.07), 8, 1)
	_p(h, "torus", o + ax * 0.022, ax, Vector3(0.068, 0.02, 0.068), Color(0.62, 0.17, 0.14), 10)
	_p(h, "torus", o + ax * 0.104, ax, Vector3(0.034, 0.018, 0.034), Color(0.62, 0.17, 0.14), 8)
	_tube(h, [top, top + n * 0.03 - Vector3.UP * 0.016, o + ax * 0.075 + n * 0.024, o + ax * 0.04 + n * 0.03], 0.0032, Color(0.62, 0.17, 0.14), 4, 2)
	# küçük sake kâsesi aynı ipte
	var q: Vector3 = o + t * 0.085 + ax * 0.03
	_tube(h, [top + t * 0.012, top + t * 0.05 + n * 0.02 - Vector3.UP * 0.05, q + ax * 0.03], 0.0028, Color(0.62, 0.17, 0.14), 4, 2)
	_lathe(h, q, ax, [[-0.016, 0.012], [-0.012, 0.016], [0.0, 0.026], [0.013, 0.033]], Color(0.5, 0.14, 0.12), 10, 1)
	_p(h, "cyl", q + ax * 0.0125, ax, Vector3(0.056, 0.002, 0.056), Color(0.86, 0.8, 0.68), 10)
	_dangle(c, "Hips", top + n * 0.012, Vector3(-0.1, -1.0, -0.15), 0.1, 0.009, Color(0.62, 0.17, 0.14), 0.3)


static func _kusarigama(c: Dictionary) -> void:
	var h: MB = c["h"]
	var bc: Color = c["bc"]
	var y = float(c["hip"].y) + 0.05
	var off = float(c["pad"]) * 0.75
	var l = _belt(h, c, y, 0.032, LEATHER_D)
	# orak: sap belden geçen deri halkada, ağız arkaya bakar
	var a = PI - 1.0
	var n: Vector3 = _dir(l, a)
	var t: Vector3 = _tan(l, a)
	var o: Vector3 = _lp(l, a, off + 0.025)
	var up: Vector3 = (Vector3.UP + t * 0.16).normalized()
	_lathe(h, o - up * 0.15, up, [[0.0, 0.016], [0.02, 0.014], [0.2, 0.0135], [0.27, 0.0165]], WOOD, 8, 1)
	for k in 7:
		_p(h, "cyl", o + up * (-0.115 + k * 0.024), up.rotated(n, 0.28), Vector3(0.031, 0.009, 0.031), bc, 8)
	_p(h, "cyl", o + up * 0.112, up, Vector3(0.038, 0.016, 0.038), IRON, 8)
	var blade := PackedVector2Array([Vector2(0.11, -0.012), Vector2(0.125, 0.012), Vector2(0.15, 0.045), Vector2(0.165, 0.09), Vector2(0.16, 0.14), Vector2(0.14, 0.185), Vector2(0.15, 0.13), Vector2(0.135, 0.085), Vector2(0.115, 0.05), Vector2(0.097, 0.026)])
	var thin = func(p: Vector2) -> float:
		return lerpf(0.006, 0.0015, clampf(p.y / 0.185, 0.0, 1.0))
	h.add_slab(blade, 0.006, STEEL, _pl(o + n * 0.0, up, n.cross(up).normalized() * -1.0), thin, STEEL_L)
	_p(h, "torus", o, up, Vector3(0.05, 0.05, 0.05), LEATHER_D, 8)
	_bx(h, o - n * 0.018, t, Vector3.UP, Vector3(0.024, 0.052, 0.012), LEATHER_D)
	# zincir: orağın dibinden çıkar, kalçanın karşı yanında sarılı
	var b = PI + 0.98
	var nb: Vector3 = _dir(l, b)
	var tb: Vector3 = _tan(l, b)
	var oc: Vector3 = _lp(l, b, off + 0.022) - Vector3.UP * 0.075
	var pts := [o - up * 0.15]
	for k in 15:
		var aa = lerpf(a + 0.1, b - 0.32, (k + 1) / 15.0)
		pts.append(_lp(l, aa, off + 0.012 + 0.012 * sin(k * 0.8)) - Vector3.UP * (0.095 + 0.03 * sin(k / 14.0 * PI)))
	for k in 40:
		var u = k / 39.0
		var th = PI * 0.75 + u * TAU * 2.6
		pts.append(oc + tb * cos(th) * 0.062 + Vector3.UP * sin(th) * 0.062 + nb * (0.005 + u * 0.03))
	var rr := []
	for k in pts.size():
		rr.append(Vector2(0.0085, 0.0038) if k % 2 == 0 else Vector2(0.0038, 0.0085))
	_loft(h, pts, rr, IRON.lightened(0.15), 4, 1)
	# ağırlık: son halkadan sarkar
	var e0: Vector3 = pts[-1]
	var dn: Vector3 = (Vector3.DOWN + nb * 0.08).normalized()
	for k in 4:
		_p(h, "torus", e0 + dn * (0.012 + k * 0.021), nb if k % 2 == 0 else tb, Vector3(0.026, 0.024, 0.026), IRON.lightened(0.15), 6)
	_lathe(h, e0 + dn * 0.1, dn, [[0.0, 0.009], [0.012, 0.018], [0.05, 0.026], [0.066, 0.016]], IRON_D, 8, 1)


# ------------------------------------------------------------------ taşınan büyük eşyalar
static func _gourd_body(mb: MB, o: Vector3, ax: Vector3, prof: Array, col: Color, seg := 16) -> void:
	_lathe(mb, o, ax, prof, col, seg, 2)


static func _kabak(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var bz: float = _back(c["m"], 0.0, ch.y - 0.15) - float(c["pad"])
	var ax: Vector3 = Vector3(0.14, 1.0, -0.06).normalized()
	var k = 0.86
	var o: Vector3 = Vector3(0.015, ch.y - 0.16, bz - 0.19)
	var prof := []
	for q in [[-0.36, 0.03], [-0.335, 0.11], [-0.27, 0.178], [-0.17, 0.208], [-0.07, 0.19], [0.03, 0.128], [0.1, 0.09], [0.15, 0.095], [0.22, 0.128], [0.29, 0.128], [0.35, 0.09], [0.4, 0.052], [0.445, 0.046], [0.47, 0.058]]:
		prof.append([float(q[0]) * k, float(q[1]) * k])
	_gourd_body(u, o, ax, prof, bc)
	var s = _surf_frame(o, ax, prof)
	var dark: Color = Color(0.2, 0.14, 0.1)
	# alt haznede kanondaki koyu meander şeridi (refs/kabak/Sand.png)
	var h0 = -0.235 * k
	var h1 = -0.135 * k
	for i in 11:
		var d = 0.255
		var t0 = (i - 5) * d
		var e = d * 0.76
		_surf(u, s, t0, h0, t0 + e, h0, 0.008, dark)
		_surf(u, s, t0 + e, h0, t0 + e, h1, 0.008, dark)
		_surf(u, s, t0 + e, h1, t0 + e * 0.2, h1, 0.008, dark)
		_surf(u, s, t0 + e * 0.2, h1, t0 + e * 0.2, h0 + 0.034, 0.008, dark)
		_surf(u, s, t0 + e * 0.2, h0 + 0.034, t0 + e * 0.54, h0 + 0.034, 0.008, dark)
	for hh in [-0.255 * k, -0.115 * k]:
		for i in 8:
			_surf(u, s, -1.4 + i * 0.35, hh, -1.05 + i * 0.35, hh, 0.006, dark)
	_lathe(u, o + ax * 0.46 * k, ax, [[0.0, 0.034], [0.026, 0.041], [0.052, 0.038], [0.065, 0.026]], Color(0.68, 0.53, 0.34), 8, 1)   # mantar tıpa
	_p(u, "cyl", o + ax * 0.43 * k, ax, Vector3(0.094, 0.014, 0.094), STRAP, 10)
	# boğazı saran kayış + çapraz kuşak (kanon: tek omuz)
	var sl = _sling(c, -1.0, 0.05, STRAP)
	var g: Vector3 = o + ax * 0.1 * k
	var ex: Vector3 = s["ex"]
	var ez: Vector3 = s["ez"]
	var rr = 0.084
	var ring := []
	for i in 15:
		var a = TAU * i / 14.0
		ring.append(g + ex * cos(a) * rr + ez * sin(a) * rr)
	_rib(u, ring, 0.034, 0.006, STRAP, ax, 4)
	var bk: Vector3 = g - ex * rr
	_rib(u, [bk, (bk + (sl["b"] as Vector3)) * 0.5 + OUT * 0.01, sl["b"]], 0.034, 0.006, STRAP, Vector3.RIGHT, 4)
	var f: Vector3 = _lp(sl["l"], 0.32, float(c["pad"]) + 0.005)
	u.add_slab(MB.hole(_rr(0.07, 0.07, 0.012), Vector2.ZERO, 0.019, 8), 0.006, BRASS, _pl(f, Vector3.RIGHT, Vector3.UP))


static func _benihisago(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var bz: float = _back(c["m"], 0.0, ch.y - 0.18) - float(c["pad"])
	# refs/kingin: iki boğumlu tek parça kabak, belinde geniş kızıl bez; sırtta dik, hafif yatık
	var ax: Vector3 = Vector3(0.36, 1.0, 0.0).normalized()
	var o: Vector3 = Vector3(0.0, ch.y - 0.2, bz - 0.132)
	var skin := Color(0.62, 0.39, 0.27)
	var prof = [[-0.2, 0.012], [-0.19, 0.06], [-0.15, 0.108], [-0.08, 0.128], [-0.015, 0.108], [0.04, 0.07], [0.075, 0.056], [0.11, 0.066], [0.16, 0.09], [0.21, 0.088], [0.25, 0.058], [0.275, 0.024], [0.287, 0.016], [0.3, 0.011]]
	_gourd_body(u, o, ax, prof, skin)
	_lathe(u, o, ax, [[0.012, 0.097], [0.045, 0.074], [0.075, 0.061], [0.11, 0.071], [0.135, 0.084]], bc, 16, 2)
	_lathe(u, o, ax, [[0.137, 0.086], [0.15, 0.094], [0.164, 0.097]], Color(0.28, 0.27, 0.33), 16, 1)
	var sl = _sling(c, 1.0, 0.026, ROPE_D, 4)
	var b: Vector3 = sl["b"]
	var w: Vector3 = o + ax * 0.075
	var e: Vector3 = w + Vector3.BACK * 0.06
	_rope(u, [b, b.lerp(e, 0.5) + OUT * 0.008, e], 0.008, ROPE, ROPE_D, 6.0)
	_p(u, "torus", b, Vector3.BACK, Vector3(0.04, 0.03, 0.04), IRON, 8)
	var k0: Vector3 = w + OUT * 0.064
	_p(u, "sphere", k0, OUT, Vector3(0.04, 0.024, 0.032), bc.darkened(0.15), 8)
	_dangle(c, "UpperChest", k0 + Vector3.DOWN * 0.01, Vector3(0.1, -1.0, -0.08), 0.1, 0.03, bc, 0.3, Vector3.RIGHT)
	_dangle(c, "UpperChest", k0 + Vector3.DOWN * 0.01, Vector3(-0.12, -1.0, -0.08), 0.08, 0.028, bc, 0.3, Vector3.RIGHT)


static func _kohaku(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var bz: float = _back(c["m"], 0.0, ch.y - 0.2) - float(c["pad"])
	var ax: Vector3 = Vector3.UP
	var o: Vector3 = Vector3(0.0, ch.y - 0.2, bz - 0.17)
	# refs/kingin/Kohaku_no_Johei.png: düz dipli, geniş omuzlu küp
	var prof = [[-0.19, 0.098], [-0.182, 0.118], [-0.12, 0.134], [-0.02, 0.158], [0.06, 0.165], [0.12, 0.148], [0.16, 0.112], [0.178, 0.094], [0.2, 0.09]]
	_lathe(u, o, ax, prof, bc, 16, 2)
	_lathe(u, o + ax * 0.2, ax, [[0.0, 0.106], [0.016, 0.11], [0.03, 0.1]], WOOD, 14, 1)   # kapak
	for s in [-1.0, 1.0]:
		_bx(u, o + ax * 0.25 + Vector3.RIGHT * s * 0.044, Vector3.RIGHT, Vector3.UP, Vector3(0.02, 0.044, 0.034), WOOD_D)
	_bx(u, o + ax * 0.276, Vector3.RIGHT, Vector3.UP, Vector3(0.128, 0.018, 0.034), WOOD)
	# ağızda beyaz kalın bükme ip + yandan sarkan örgü
	var white := Color(0.93, 0.92, 0.88)
	var ring := []
	for k in 25:
		var a = TAU * k / 24.0
		ring.append(o + ax * 0.178 + Vector3(sin(a), 0, cos(a)) * 0.108)
	_rope(u, ring, 0.021, white, white.darkened(0.1), 18.0)
	var tail := Vector3(-0.106, 0.164, -0.03) + o
	for k in 5:
		var q: Vector3 = tail + Vector3(-0.012 - 0.006 * sin(k * 0.8), -k * 0.034, 0.0)
		_p(u, "sphere", q + Vector3(0.01 if k % 2 == 0 else -0.01, 0, 0), Vector3(0.5, 1, 0), Vector3(0.036, 0.052, 0.03), white, 6)
	_dangle(c, "UpperChest", tail + Vector3(-0.012, -0.17, 0.0), Vector3(-0.04, -1.0, -0.05), 0.07, 0.032, white, 0.3, Vector3.RIGHT, 0.007)
	# «雷» amblem: baklava çerçeve + iç çizgiler
	var s0 = _surf_frame(o, ax, prof)
	var dz = func(x: float, y: float) -> Array:
		return [asin(clampf(x / _prof_r(prof, y), -0.98, 0.98)) * -1.0, y]
	var line = func(x0: float, y0: float, x1: float, y1: float, w: float, n: int) -> void:
		for k in n:
			var a0: Array = dz.call(lerpf(x0, x1, float(k) / n), lerpf(y0, y1, float(k) / n))
			var a1: Array = dz.call(lerpf(x0, x1, float(k + 1) / n), lerpf(y0, y1, float(k + 1) / n))
			_surf(u, s0, a0[0], a0[1], a1[0], a1[1], w, INK)
	var cy = 0.02
	for q in [[0.0, 0.11, 0.098, 0.0], [0.098, 0.0, 0.0, -0.11], [0.0, -0.11, -0.098, 0.0], [-0.098, 0.0, 0.0, 0.11]]:
		line.call(q[0], cy + q[1], q[2], cy + q[3], 0.012, 3)
	line.call(0.0, cy + 0.074, 0.0, cy - 0.074, 0.01, 3)
	line.call(-0.046, cy + 0.032, 0.046, cy + 0.032, 0.01, 2)
	line.call(-0.064, cy - 0.004, 0.064, cy - 0.004, 0.01, 2)
	line.call(-0.04, cy - 0.04, 0.04, cy - 0.04, 0.01, 2)
	# taşıma: küpü saran ip beşik + omuz kayışı
	var lo := []
	for k in 21:
		var a = TAU * k / 20.0
		lo.append(o + ax * -0.11 + Vector3(sin(a), 0, cos(a)) * (_prof_r(prof, -0.11) + 0.006))
	_rib(u, lo, 0.013, 0.009, ROPE_D, ax, 4)
	for a in [0.86, -0.86, 2.2, -2.2]:
		var d = Vector3(sin(a), 0, cos(a)) * -1.0
		var pts := []
		for hh in [-0.11, -0.04, 0.03, 0.09, 0.15]:
			pts.append(o + ax * float(hh) + d * (_prof_r(prof, float(hh)) + 0.006))
		_rib(u, pts, 0.011, 0.008, ROPE_D, d.cross(ax), 4)
	_harness(c, 0.03, STRAP, -0.13)


static func _kokinjo(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var dk: Color = bc.darkened(0.2)
	var bz: float = _back(c["m"], 0.0, ch.y - 0.14) - float(c["pad"])
	var o: Vector3 = Vector3(0.0, ch.y - 0.14, bz - 0.05)
	var path := []
	for k in 38:
		var v = k / 37.0
		var a = v * TAU * 2.0 + 0.5
		var r = 0.15 + 0.012 * sin(v * 9.0)
		path.append(o + Vector3(cos(a) * r, sin(a) * r * 0.94, -v * 0.054))
	_rope(u, path, 0.031, bc, dk, 38.0 * 1.7, 3, 4)
	# omuzdan göğse geçen kol: halkayı taşır
	var l = _sl_loop(c, 1.0)
	var sp := _arc(l, -0.15 + PI * 2.0 - TAU, PI + 0.16, 17, float(c["pad"]) + 0.02)
	_rope(u, sp, 0.021, bc, dk, 24.0, 2, 4)
	var e: Vector3 = sp[0]
	_p(u, "sphere", e, Vector3.UP, Vector3(0.05, 0.05, 0.045), dk, 8)
	_dangle(c, "UpperChest", o + Vector3(0.1, -0.15, -0.05), Vector3(0.1, -1.0, -0.15), 0.2, 0.045, bc, 0.22, Vector3.RIGHT, 0.012)


static func _parsomen(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var bz: float = _back(c["m"], 0.0, ch.y - 0.15) - float(c["pad"])
	var ax: Vector3 = Vector3(1.0, 0.12, 0.0).normalized()
	var r = 0.088
	var ln = 0.27   # kollar serbest kalsın: uçlar omuz genişliğini az geçer
	var o: Vector3 = Vector3(0.0, ch.y - 0.15, bz - r - 0.008)
	var green := Color(0.5, 0.52, 0.42)
	var band := Color(0.17, 0.16, 0.16)
	var prof := []
	var cols := []
	for q in [[-1.0, -0.88, bc], [-0.88, -0.8, band], [-0.8, -0.68, bc], [-0.68, -0.62, band], [-0.62, -0.42, bc], [-0.42, 0.42, green], [0.42, 0.62, bc], [0.62, 0.68, band], [0.68, 0.8, bc], [0.8, 0.88, band], [0.88, 1.0, bc]]:
		for e in [float(q[0]) + 0.004, float(q[1]) - 0.004]:
			prof.append([e * ln, r])
			cols.append(q[2])
	_lathe(u, o, ax, prof, cols, 14, 1)
	for s in [-1.0, 1.0]:
		var e: Vector3 = o + ax * s * ln
		var d: Vector3 = ax * s
		_p(u, "cyl", e + d * 0.034, d, Vector3(r * 1.72, 0.006, r * 1.72), bc.darkened(0.16), 14)
		for q in [0.72, 1.28]:
			_p(u, "torus", e + d * 0.036, d, Vector3(r * q, 0.01, r * q), bc.darkened(0.34), 12)
		_lathe(u, e, d, [[0.02, 0.03], [0.044, 0.03], [0.058, 0.038], [0.074, 0.033]], WOOD_D, 8, 1)
		var qq: Vector3 = o + ax * s * 0.14
		var ring := []
		for k in 21:
			var a = TAU * k / 20.0
			ring.append(qq + (Vector3.BACK.cross(ax).normalized() * cos(a) + Vector3.BACK * sin(a)) * (r + 0.007))
		_rope(u, ring, 0.0078, ROPE, ROPE_D, 26.0)
	_harness(c, 0.03, STRAP, -0.13)
	_dangle(c, "UpperChest", o + ax * 0.14 + Vector3.DOWN * (r + 0.006), Vector3(0.05, -1.0, -0.1), 0.1, 0.012, ROPE, 0.3, Vector3.ZERO, 0.005)


static func _joki(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var bz: float = _back(c["m"], 0.0, ch.y - 0.1) - float(c["pad"])
	var o: Vector3 = Vector3(0.0, ch.y - 0.13, bz - 0.125)
	var iron := Color(0.2, 0.19, 0.2)
	var pts := []
	var rr := []
	for q in [[-0.235, 0.82], [-0.21, 0.97], [-0.1, 1.0], [0.08, 1.0], [0.18, 0.96], [0.225, 0.78], [0.25, 0.44]]:
		pts.append(o + Vector3.UP * float(q[0]))
		rr.append(Vector2(0.158, 0.118) * float(q[1]))
	_loft(u, pts, rr, iron, 16, 2, true, Callable(), Vector3.BACK)
	for y in [-0.17, 0.0, 0.15]:
		_p(u, "torus", o + Vector3.UP * y, Vector3.UP, Vector3(0.326, 0.05, 0.244), bc, 16)
		for k in 7:
			var a = -1.25 + k * 2.5 / 6.0
			var n: Vector3 = Vector3(sin(a) * 0.118, 0.0, -cos(a) * 0.158).normalized()
			_rivet(u, o + Vector3.UP * (y + 0.032) + Vector3(sin(a) * 0.159, 0.0, -cos(a) * 0.119), n, 0.0065, BRASS)
	# ocak kapağı: menteşeli, ızgaralı, içi kor
	var f: Vector3 = o + Vector3(0.0, -0.085, -0.117)
	u.add_slab(_rr(0.13, 0.092, 0.012), 0.012, IRON_D, _pl(f, Vector3.LEFT, Vector3.UP), Callable(), BRASS.darkened(0.2))
	_bx(u, f + OUT * 0.007, Vector3.RIGHT, Vector3.UP, Vector3(0.09, 0.046, 0.002), Color(0.95, 0.38, 0.1))
	for k in 5:
		_bx(u, f + OUT * 0.01 + Vector3.RIGHT * (k - 2) * 0.02, Vector3.RIGHT, Vector3.UP, Vector3(0.006, 0.054, 0.006), iron)
	for s in [-1.0, 1.0]:
		_p(u, "cyl", f + Vector3(0.068, s * 0.03, -0.002), Vector3.UP, Vector3(0.012, 0.022, 0.012), BRASS, 6)
	# manometre
	var g: Vector3 = o + Vector3(0.09, 0.09, -0.112)
	_p(u, "cyl", g, OUT, Vector3(0.046, 0.012, 0.046), BRASS, 10)
	_p(u, "cyl", g + OUT * 0.007, OUT, Vector3(0.036, 0.002, 0.036), PAPER, 10)
	_bx(u, g + OUT * 0.009 + Vector3(0.004, 0.005, 0.0), Vector3(0.6, 0.8, 0.0), Vector3(-0.8, 0.6, 0.0), Vector3(0.016, 0.002, 0.001), INK)
	# omuz boruları: buhar salımının çıktığı yerler
	var brass := Color(0.55, 0.42, 0.22)
	for s in [-1.0, 1.0]:
		var a: Vector3 = o + Vector3(s * 0.085, 0.205, -0.004)
		var b: Vector3 = Vector3(s * 0.2, ch.y + 0.2, o.z + 0.01)
		var p2 = [a, a + Vector3(s * 0.02, 0.05, 0.0), a.lerp(b, 0.6) + Vector3(s * 0.005, 0.03, 0.0), b]
		_tube(u, p2, 0.02, brass, 8, 3)
		var d: Vector3 = (b - (p2[2] as Vector3)).normalized()
		_p(u, "cyl", a + Vector3.UP * 0.008, Vector3.UP, Vector3(0.056, 0.012, 0.056), iron, 8)
		_p(u, "cyl", (a as Vector3).lerp(b, 0.55) + Vector3(0, 0.022, 0), d, Vector3(0.05, 0.014, 0.05), iron, 8)
		_lathe(u, b, d, [[-0.012, 0.024], [0.014, 0.034], [0.034, 0.033]], iron, 8, 1)
	_harness(c, 0.034, Color(0.14, 0.12, 0.12), -0.14)


static func _sashimono(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var m = c["m"]
	var bz: float = _back(m, 0.0, ch.y - 0.1) - float(c["pad"])
	var x = 0.0
	var z = bz - 0.058
	var y0 = ch.y - 0.34
	var y1 = ch.y + 0.66
	var pole := Color(0.2, 0.13, 0.09)
	_lathe(u, Vector3(x, y0, z), Vector3.UP, [[0.0, 0.0165], [0.5, 0.0145], [1.0, 0.0125], [y1 - y0, 0.011]], pole, 8, 1)
	# sırt tahtası, alt yuva (uketsubo) ve üst bilezik (gattari)
	var tb := PackedVector2Array([Vector2(-0.03, -0.25), Vector2(0.03, -0.25), Vector2(0.036, 0.2), Vector2(0.02, 0.235), Vector2(-0.02, 0.235), Vector2(-0.036, 0.2)])
	u.add_slab(tb, 0.012, WOOD, _pl(Vector3(x, ch.y - 0.1, bz - 0.012), Vector3.LEFT, Vector3.UP), Callable(), WOOD_D)
	_lathe(u, Vector3(x, y0 - 0.012, z), Vector3.UP, [[0.0, 0.016], [0.012, 0.03], [0.07, 0.027], [0.075, 0.021]], IRON, 8, 1)
	_bx(u, Vector3(x, y0 + 0.03, (z + bz) * 0.5 - 0.004), Vector3.RIGHT, Vector3.UP, Vector3(0.028, 0.024, absf(z - bz)), IRON)
	var gy = ch.y + 0.1
	_p(u, "torus", Vector3(x, gy, z), Vector3.UP, Vector3(0.05, 0.05, 0.05), BRASS, 10)
	_bx(u, Vector3(x, gy, (z + bz) * 0.5 - 0.004), Vector3.RIGHT, Vector3.UP, Vector3(0.022, 0.018, absf(z - bz)), BRASS)
	# üst kol ve sancak (rüzgârda hafif dalgalı, çift yüz)
	var w = 0.24
	var by1 = y1 - 0.03
	var by0 = by1 - 0.5
	_tube(u, [Vector3(x, by1, z), Vector3(x + w + 0.012, by1, z)], 0.0075, pole, 6)
	_p(u, "sphere", Vector3(x + w + 0.014, by1, z), Vector3.UP, Vector3(0.022, 0.022, 0.022), BRASS, 6)
	_p(u, "cone", Vector3(x, y1 + 0.035, z), Vector3.UP, Vector3(0.026, 0.07, 0.026), BRASS, 6)
	var wave = func(a: float, b: float) -> Vector3:
		return Vector3(x + 0.008 + a * (w - 0.008), lerpf(by0, by1 - 0.004, b), z + sin(a * 8.0 + b * 3.0) * 0.012 * smoothstep(0.0, 0.2, a))
	_sheet(u, wave, 10, 8, bc)
	# armalı beyaz daire, kumaşın iki yüzünde
	var mon := Color(0.94, 0.93, 0.88)
	var bm := Vector2(0.5, 0.56)
	for fz in [-1.0, 1.0]:
		var disc = func(a: float, b: float) -> Vector3:
			var t = a * TAU
			var q = Vector2(bm.x + cos(t) * b * 0.27, bm.y + sin(t) * b * 0.27 * w / 0.5)
			var p: Vector3 = wave.call(q.x, q.y)
			return p + Vector3.BACK * fz * 0.0035
		_sheet(u, disc, 14, 2, mon)
	for k in 4:
		var q: Vector3 = Vector3(x + 0.03 + k * 0.06, by1 - 0.005, z)
		_p(u, "torus", q, Vector3.RIGHT, Vector3(0.021, 0.022, 0.021), pole.lightened(0.1), 6)
	_harness(c, 0.028, STRAP, -0.13)
	_dangle(c, "UpperChest", Vector3(x, y1 - 0.12, z - 0.012), Vector3(-0.3, -1.0, -0.1), 0.16, 0.022, bc, 0.14, Vector3.RIGHT)
	_dangle(c, "UpperChest", Vector3(x + w * 0.2, by0, z), Vector3(0.0, -1.0, -0.02), 0.08, 0.05, bc, 0.14, Vector3.RIGHT)
	_dangle(c, "UpperChest", Vector3(x + w * 0.8, by0, z), Vector3(0.0, -1.0, -0.02), 0.08, 0.05, bc, 0.14, Vector3.RIGHT)


## Çift yüzlü ızgara yüzey f(u, v)
static func _sheet(mb: MB, f: Callable, nu: int, nv: int, col: Color) -> void:
	for side in [1.0, -1.0]:
		var base = mb.verts.size()
		for j in nv + 1:
			for i in nu + 1:
				var a = float(i) / nu
				var b = float(j) / nv
				var p: Vector3 = f.call(a, b)
				var du: Vector3 = (f.call(minf(a + 0.02, 1.0), b) as Vector3) - (f.call(maxf(a - 0.02, 0.0), b) as Vector3)
				var dv: Vector3 = (f.call(a, minf(b + 0.02, 1.0)) as Vector3) - (f.call(a, maxf(b - 0.02, 0.0)) as Vector3)
				var n: Vector3 = du.cross(dv)
				mb.verts.append(p)
				mb.normals.append(n.normalized() * side if n.length() > 1e-7 else Vector3.BACK * side)
				mb.colors.append(col)
				mb.uvs.append(Vector2(a, b))
		for j in nv:
			for i in nu:
				var q0 = base + j * (nu + 1) + i
				var q1 = q0 + 1
				var q2 = q0 + nu + 1
				var q3 = q2 + 1
				if side > 0.0:
					mb.idx.append_array([q0, q2, q1, q1, q2, q3])
				else:
					mb.idx.append_array([q0, q1, q2, q1, q3, q2])


# ------------------------------------------------------------------ silahlar
static func _kin(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var sl = _sling(c, -1.0, 0.03, LEATHER_D)
	var ax: Vector3 = sl["ax"]
	var sd: Vector3 = sl["sd"]
	var o: Vector3 = (sl["b"] as Vector3) + OUT * 0.03
	var q: Vector3 = o + ax * 0.32
	var d: Vector3 = -ax
	var n: Vector3 = (OUT - d * OUT.dot(d)).normalized()
	_saya(u, q, d, n, 0.9, bc)
	_p(u, "cyl", q - d * 0.002, d, Vector3(0.044, 0.004, 0.022), INK, 8)   # boş ağız
	for t in [0.14, -0.26]:
		var e: Vector3 = o + ax * float(t)
		_p(u, "cyl", e, ax, Vector3(0.074, 0.03, 0.05), LEATHER_D, 8)
		_bx(u, e + Vector3.BACK * 0.02, sd, ax, Vector3(0.018, 0.024, 0.024), LEATHER_D)
		_rivet(u, e + OUT * 0.026, OUT)
	_dangle(c, "UpperChest", q + d * 0.17 + n * 0.022, Vector3(0.2, -1.0, -0.1), 0.2, 0.012, Color(0.55, 0.46, 0.3), 0.22, Vector3.ZERO, 0.004)


static func _ikiz(c: Dictionary) -> void:
	var u: MB = c["u"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var bz: float = _back(c["m"], 0.0, ch.y - 0.12) - float(c["pad"])
	var o: Vector3 = Vector3(0.0, ch.y - 0.12, bz - 0.022)
	for s in [-1.0, 1.0]:
		var h: Vector3 = Vector3(s * 0.4, 1.0, 0.0).normalized()
		var cz: Vector3 = o + OUT * (0.022 if s > 0.0 else 0.058)
		var q: Vector3 = cz + h * 0.27
		_saya(u, q, -h, OUT, 0.64, bc, 0.015, 0.027)
		_tsuka(u, q, h, OUT, 0.22, Color(0.1, 0.09, 0.1))
		_dangle(c, "UpperChest", q - h * 0.15 + OUT * 0.016, Vector3(s * 0.25, -1.0, -0.1), 0.16, 0.01, Color(0.55, 0.46, 0.3), 0.22, Vector3.ZERO, 0.004)
	u.add_slab(_circle(0.062, 12), 0.008, LEATHER_D, _pl(o + OUT * 0.082, Vector3.LEFT, Vector3.UP), Callable(), STRAP)
	_p(u, "torus", o + OUT * 0.088, OUT, Vector3(0.07, 0.05, 0.07), IRON, 10)
	for s in [-1.0, 1.0]:
		var v: Vector3 = Vector3(s * 0.4, 1.0, 0.0).normalized()
		for e in [-1.0, 1.0]:
			_rib(u, [o + OUT * 0.082 + v.cross(Vector3.BACK).normalized() * e * 0.05, o + v.cross(Vector3.BACK).normalized() * e * 0.09 + OUT * 0.03, o + v.cross(Vector3.BACK).normalized() * e * 0.09 + OUT * 0.004], 0.02, 0.005, STRAP, v, 4)
	_harness(c, 0.026, STRAP, -0.13)


static func _nodachi(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var sl = _sling(c, -1.0, 0.034, LEATHER_D)
	var ax: Vector3 = sl["ax"]
	var sd: Vector3 = sl["sd"]
	var o: Vector3 = (sl["b"] as Vector3) + OUT * 0.032
	var q: Vector3 = o + ax * 0.24
	var d: Vector3 = -ax
	_saya(u, q, d, OUT, 0.9, bc, 0.018, 0.033)
	_tsuka(u, q, ax, OUT, 0.33, Color(0.08, 0.08, 0.1), 0.016, 0.023, 0.05)
	for t in [0.3, 0.54, 0.76]:
		_p(u, "cyl", q + d * float(t), d, Vector3(0.074, 0.018, 0.042), BRASS.darkened(0.15), 8)
	for t in [0.12, -0.3]:
		var e: Vector3 = o + ax * float(t)
		_p(u, "cyl", e, ax, Vector3(0.082, 0.03, 0.052), LEATHER_D, 8)
		_bx(u, e + Vector3.BACK * 0.022, sd, ax, Vector3(0.02, 0.024, 0.024), LEATHER_D)
	_dangle(c, "UpperChest", q + d * 0.17 + OUT * 0.024, Vector3(0.22, -1.0, -0.1), 0.24, 0.018, Color(0.72, 0.14, 0.12), 0.2, Vector3.ZERO, 0.004)


static func _kesici(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var sl = _sling(c, -1.0, 0.044, LEATHER_D)
	var ax: Vector3 = sl["ax"]
	var sd: Vector3 = sl["sd"]
	var o: Vector3 = (sl["b"] as Vector3) + OUT * 0.03 + ax * 0.3
	# profil: x kılıç boyu (0 kabza, eksi uç), y genişlik; arkada yarım daire oyuk, uca yakın delik (refs/genis_kesici)
	var ot := PackedVector2Array([Vector2(0.0, 0.06), Vector2(-0.04, 0.095), Vector2(-0.68, 0.095)])
	for k in 9:
		var a = PI * k / 8.0
		ot.append(Vector2(-0.76 - cos(a) * 0.052 * -1.0 - 0.052 + 0.0, 0.095 - sin(a) * 0.04))
	ot.append_array(PackedVector2Array([Vector2(-0.88, 0.095), Vector2(-0.97, 0.082), Vector2(-1.03, 0.03), Vector2(-1.035, -0.05), Vector2(-0.97, -0.145), Vector2(-0.8, -0.18), Vector2(-0.4, -0.18), Vector2(-0.05, -0.165), Vector2(0.0, -0.12)]))
	var sc = 0.86
	var ot2 := PackedVector2Array()
	for q in ot:
		ot2.append(q * sc)
	var pr: PackedVector2Array = MB.hole(ot2, Vector2(-0.88, -0.012) * sc, 0.044 * sc, 12)
	var thin = func(p: Vector2) -> float:
		return lerpf(0.016, 0.003, clampf((0.0 - p.y / sc - 0.09) / 0.09, 0.0, 1.0))
	var xf: Transform3D = _pl(o, ax, sd)
	u.add_slab(pr, 0.016, STEEL, xf, thin, STEEL_L)
	# ağız şeridi iki yüzde
	var edge := PackedVector2Array([Vector2(-0.03, -0.15), Vector2(-0.4, -0.163), Vector2(-0.8, -0.163), Vector2(-0.96, -0.13), Vector2(-1.018, -0.05), Vector2(-1.035, -0.05), Vector2(-0.97, -0.145), Vector2(-0.8, -0.18), Vector2(-0.4, -0.18), Vector2(-0.05, -0.165)])
	var ed2 := PackedVector2Array()
	for q in edge:
		ed2.append(q * sc)
	for s in [-1.0, 1.0]:
		var n: Vector3 = (ax.cross(sd)).normalized()
		u.add_slab(ed2, 0.001, STEEL_L, _pl(o + n * s * 0.0035, ax, sd))
	_lathe(u, o + sd * -0.035, ax, [[-0.02, 0.019], [0.02, 0.019], [0.24, 0.0165], [0.27, 0.022], [0.29, 0.016]], IRON_D, 8, 1)
	var hc: Vector3 = o + sd * -0.035
	var helix := []
	for k in 25:
		var v = k / 24.0
		var a = v * TAU * 7.0
		helix.append(hc + ax * lerpf(0.03, 0.235, v) + (sd * cos(a) + ax.cross(sd).normalized() * sin(a)) * 0.0195)
	_tube(u, helix, 0.0048, bc, 4)
	_p(u, "torus", hc + ax * 0.31, sd, Vector3(0.05, 0.04, 0.05), IRON, 8)
	# taşıma kelepçeleri
	for t in [-0.17, -0.53]:
		var e: Vector3 = o + ax * float(t) + sd * -0.035
		var nn: Vector3 = ax.cross(sd).normalized()
		_bx(u, e, sd, ax, Vector3(0.285, 0.036, 0.022), LEATHER_D)
		_bx(u, e + Vector3.BACK * 0.018, sd, ax, Vector3(0.05, 0.03, 0.022), LEATHER_D)
		_rivet(u, e + nn * 0.012 * (1.0 if nn.dot(OUT) > 0.0 else -1.0) + sd * 0.1, OUT)
	_dangle(c, "UpperChest", hc + ax * 0.33, Vector3(0.1, -1.0, -0.1), 0.1, 0.016, bc, 0.32)


static func _sargili(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var sl = _sling(c, -1.0, 0.044, LEATHER_D)
	var ax: Vector3 = sl["ax"]
	var sd: Vector3 = sl["sd"]
	var n: Vector3 = sd.cross(ax).normalized()
	if n.dot(OUT) < 0.0:
		n = -n
	var o: Vector3 = (sl["b"] as Vector3) + OUT * 0.056
	var q: Vector3 = o + ax * 0.2   # kabza kökü yukarıda, geniş baş aşağıda
	var dn: Vector3 = -ax
	# düzgün tek gövde: bez sarılı geniş kılıç; sargı yalnız yüzeydeki dikiş çizgileriyle okunur
	var wp := [[0.0, 0.022], [0.05, 0.046], [0.18, 0.074], [0.44, 0.098], [0.62, 0.104], [0.72, 0.09], [0.78, 0.05]]
	var dp := [[0.0, 0.019], [0.05, 0.028], [0.18, 0.04], [0.44, 0.05], [0.62, 0.052], [0.72, 0.045], [0.78, 0.027]]
	var pts := []
	var rr := []
	for i in wp.size():
		pts.append(q + dn * float(wp[i][0]))
		rr.append(Vector2(float(dp[i][1]), float(wp[i][1])))
	_loft(u, pts, rr, bc, 14, 3, true, Callable(), dn.cross(n))
	var seam := []
	var cnt = 96
	for k in cnt:
		var v = k / float(cnt - 1)
		var a = v * TAU * 8.0
		var t = lerpf(0.03, 0.75, v)
		seam.append(q + dn * t + sd * cos(a) * (_prof_r(wp, t) + 0.0025) + n * sin(a) * (_prof_r(dp, t) + 0.0025))
	_tube(u, seam, 0.0026, bc.darkened(0.34), 3)
	# kabza
	var hn: Vector3 = ax
	_p(u, "cyl", q + hn * 0.006, hn, Vector3(0.1, 0.016, 0.048), IRON_D, 8)
	_lathe(u, q, hn, [[0.01, 0.018], [0.13, 0.016], [0.22, 0.018], [0.25, 0.027], [0.28, 0.018]], Color(0.09, 0.09, 0.11), 8, 1)
	var helix := []
	for k in 21:
		var v = k / 20.0
		var a = v * TAU * 6.0
		helix.append(q + hn * lerpf(0.022, 0.21, v) + (sd * cos(a) + n * sin(a)) * 0.0185)
	_tube(u, helix, 0.0045, SAME, 4)
	# iki kelepçe gövdeyi kayışa bağlar
	for t in [0.12, 0.42]:
		var e: Vector3 = q + dn * float(t)
		var ww = _prof_r(wp, float(t)) + 0.005
		var dd = _prof_r(dp, float(t)) + 0.005
		var ring := []
		for k in 17:
			var a = TAU * k / 16.0
			ring.append(e + sd * cos(a) * ww + n * sin(a) * dd)
		_rib(u, ring, 0.03, 0.005, LEATHER_D, dn, 4)
		_bx(u, e - n * (dd + 0.004), sd, ax, Vector3(0.024, 0.03, 0.02), LEATHER_D)
	# alt kelepçeden kısa bez ucu
	_dangle(c, "UpperChest", q + dn * 0.46 + sd * 0.09 + n * 0.03, Vector3(0.25, -1.0, -0.1), 0.11, 0.04, bc, 0.32, sd)


static func _yelpaze(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var sl = _sling(c, -1.0, 0.036, LEATHER_D)
	var ax: Vector3 = sl["ax"]
	var sd: Vector3 = sl["sd"]
	var o: Vector3 = (sl["b"] as Vector3) + OUT * 0.012 - ax * 0.03
	# kapalı Temari yelpazesi: dış kaburgalar + katlı kâğıt; x boy (eksen), y yan
	var paper: Color = Color(0.87, 0.8, 0.62)
	var purple: Color = Color(0.42, 0.26, 0.55)
	var layers = 7
	var by = -0.47
	for k in layers:
		var outer = k == 0 or k == layers - 1
		var off = 0.012 + k * 0.0108
		var col: Color = bc.darkened(0.32) if outer else (paper if k % 2 == 1 else paper.darkened(0.12))
		var hw = 0.04
		var tw = 0.08 if outer else 0.074 - absf(k - 3) * 0.003
		var top = 0.48 if outer else 0.473 - absf(k - 3) * 0.002
		var ol := PackedVector2Array([Vector2(by, -hw * 0.72), Vector2(by + 0.03, -hw), Vector2(top - 0.02, -tw), Vector2(top, -tw * 0.92), Vector2(top + 0.012, 0.0), Vector2(top, tw * 0.92), Vector2(top - 0.02, tw), Vector2(by + 0.03, hw), Vector2(by, hw * 0.72)])
		u.add_slab(ol, 0.0078, col, _pl(o + OUT * off, ax, sd), Callable(), col.darkened(0.2))
	# katların kenarında mor benekler (açılınca daire olan boya)
	for t in [0.1, 0.3]:
		for s in [-1.0, 1.0]:
			for k in [2, 3, 4]:
				var off = 0.012 + k * 0.0108
				var w = 0.07 * lerpf(0.54, 1.0, (float(t) - by) / 0.95)
				_bx(u, o + OUT * off + ax * float(t) + sd * s * w, ax, sd, Vector3(0.05, 0.004, 0.0066), purple)
	var piv: Vector3 = o + OUT * 0.044 + ax * (by + 0.04)
	_p(u, "cyl", piv, OUT, Vector3(0.03, 0.082, 0.03), BRASS, 10)
	for s in [-1.0, 1.0]:
		_p(u, "cyl", piv + OUT * s * 0.042, OUT, Vector3(0.042, 0.005, 0.042), BRASS.darkened(0.15), 10)
	_p(u, "torus", piv - ax * 0.05, sd, Vector3(0.05, 0.04, 0.05), IRON, 8)
	# bağ kordonu + kayış kelepçeleri
	for t in [0.24, -0.2]:
		var e: Vector3 = o + OUT * 0.044 + ax * float(t)
		var hw = lerpf(0.042, 0.084, (float(t) - by) / 0.95)
		_bx(u, e, sd, ax, Vector3(hw * 2.1, 0.03, 0.094), LEATHER_D)
		for s in [-1.0, 1.0]:
			_rivet(u, e + OUT * 0.048 + sd * s * hw * 0.8, OUT)
	# dış kaburganın ortasında kâğıt yüzey ve katlar görünür
	var fz: Vector3 = o + OUT * (0.012 + (layers - 1) * 0.0108 + 0.0045)
	var ins := PackedVector2Array([Vector2(-0.3, -0.022), Vector2(0.42, -0.048), Vector2(0.42, 0.048), Vector2(-0.3, 0.022)])
	u.add_slab(ins, 0.0012, paper, _pl(fz, ax, sd))
	for k in 5:
		var w0 = (k - 2) * 0.0095
		var a0: Vector3 = fz + OUT * 0.0009 + ax * -0.3 + sd * w0
		var a1: Vector3 = fz + OUT * 0.0009 + ax * 0.42 + sd * w0 * 2.2
		var ev: Vector3 = (a1 - a0).normalized()
		_bx(u, (a0 + a1) * 0.5, ev, OUT.cross(ev), Vector3(a0.distance_to(a1), 0.0016, 0.0008), paper.darkened(0.3))
	_dangle(c, "UpperChest", piv - ax * 0.07, Vector3(0.0, -1.0, -0.05), 0.08, 0.016, purple, 0.4)


static func _kunai_seti(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var m = c["m"]
	var ch: Vector3 = c["ch"]
	var y = ch.y - 0.075
	var off = float(c["pad"])
	var l = _ring(m, y)
	# kürek kemikleri arasında kavisli deri pano; omuz takımına bağlı
	var pa := _arc(l, PI - 0.8, PI + 0.8, 12, off + 0.006)
	var panel: Color = bc.lerp(LEATHER, 0.45)
	_rib(u, pa, 0.13, 0.007, panel, Vector3.UP, 6)
	for e in [0.06, -0.06]:
		var tr := []
		for p in pa:
			tr.append((p as Vector3) + Vector3.UP * e + OUT * 0.002)
		_rib(u, tr, 0.009, 0.008, panel.darkened(0.35), Vector3.UP, 4)
	for k in 6:
		var a = PI + lerpf(-0.62, 0.62, k / 5.0)
		var n: Vector3 = _dir(l, a)
		var t: Vector3 = _tan(l, a)
		var p: Vector3 = _lp(l, a, off + 0.02)
		var d: Vector3 = (Vector3.UP + t * ((k - 2.5) * 0.09)).normalized()
		var w: Vector3 = d.cross(n).normalized()
		var sl := PackedVector2Array([Vector2(-0.023, 0.026), Vector2(0.023, 0.026), Vector2(0.02, -0.024), Vector2(0.007, -0.058), Vector2(-0.007, -0.058), Vector2(-0.02, -0.024)])
		u.add_slab(sl, 0.016, panel.darkened(0.2), _pl(p, w, d), Callable(), LEATHER_D)
		_stitch(u, p + n * 0.0085 + w * 0.017 + d * 0.02, p + n * 0.0085 + w * 0.006 - d * 0.046, 4, n)
		_kunai_grip(u, p + d * 0.026, d, n)
	_harness(c, 0.026, STRAP, -0.15)


static func _bo(c: Dictionary) -> void:
	var u: MB = c["u"]
	var bc: Color = c["bc"]
	var sl = _sling(c, 1.0, 0.026, STRAP, 4)
	var ax: Vector3 = sl["ax"]
	var sd: Vector3 = sl["sd"]
	var o: Vector3 = (sl["b"] as Vector3) + OUT * 0.03
	var a: Vector3 = o - ax * 0.66
	var ln = 1.5
	var r = 0.0195
	var fn = func(t: float, _ang: float, _d: Vector3) -> Color:
		return bc if fmod(t * 11.0, 1.0) > 0.05 else bc.darkened(0.14)
	var prof := []
	for k in 13:
		prof.append([ln * k / 12.0, r])
	_lathe(u, a, ax, prof, bc, 8, 1, fn)
	for e in [[0.0, 1.0], [ln, -1.0]]:
		var q: Vector3 = a + ax * float(e[0])
		var s = float(e[1])
		_lathe(u, q, ax * s, [[-0.012, r * 1.02], [0.0, r * 1.24], [0.1, r * 1.16], [0.112, r * 1.34], [0.13, r * 1.34], [0.142, r * 1.14]], IRON, 8, 1)
		for k in 4:
			var g = TAU * k / 4.0 + 0.5
			var nd: Vector3 = sd * cos(g) + ax.cross(sd).normalized() * sin(g)
			_rivet(u, q + ax * s * 0.05 + nd * r * 1.2, nd, 0.0048, STEEL)
		_p(u, "torus", q + ax * s * 0.122, ax, Vector3(r * 3.3, 0.03, r * 3.3), STEEL, 8)
	# orta tutuş: deri sargı
	var helix := []
	for k in 37:
		var v = k / 36.0
		var g = v * TAU * 11.0
		helix.append(a + ax * lerpf(ln * 0.42, ln * 0.58, v) + (sd * cos(g) + ax.cross(sd).normalized() * sin(g)) * (r + 0.003))
	_tube(u, helix, 0.0052, LEATHER_D, 4)
	for t in [0.28, -0.3]:
		var e: Vector3 = o + ax * float(t)
		_p(u, "torus", e, ax, Vector3(0.058, 0.05, 0.058), LEATHER_D, 8)
		_bx(u, e + Vector3.BACK * 0.021, sd, ax, Vector3(0.018, 0.028, 0.024), LEATHER_D)
	_dangle(c, "UpperChest", a + ax * ln * 0.58 + OUT * 0.024, Vector3(0.1, -1.0, -0.1), 0.15, 0.014, LEATHER, 0.22)


# ------------------------------------------------------------------ oynanış bağı olan göğüs parçaları
static func _chakura(c: Dictionary) -> void:
	var u: MB = c["u"]
	var m = c["m"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var pad = float(c["pad"])
	var blue := Color(0.13, 0.28, 0.42)
	var white := Color(0.93, 0.95, 0.94)
	var teal := Color(0.15, 0.55, 0.65)
	# refs/chakura_yoroi: göğsün üst yanında tek yuvarlak yuva
	var y = ch.y + 0.045
	var l = _ring(m, y)
	var a = 0.62
	var n: Vector3 = (_dir(l, a) + Vector3.UP * 0.12).normalized()
	var o: Vector3 = _lp(l, a, pad + 0.012)
	_lathe(u, o, n, [[-0.012, 0.074], [0.0, 0.088], [0.016, 0.092], [0.03, 0.08], [0.036, 0.068]], bc, 18, 1)
	var fc: Vector3 = o + n * 0.0375
	_p(u, "cyl", fc, n, Vector3(0.132, 0.004, 0.132), white, 18)
	var b: Basis = _ax(n)
	var ex: Vector3 = b.x
	var ey: Vector3 = b.z
	# yin-yang: S eğrili yarım + iki göz
	var half := PackedVector2Array()
	for k in 13:
		var t = PI * k / 12.0
		half.append(Vector2(cos(t + PI * 0.5), sin(t + PI * 0.5)) * 0.062)
	for k in range(1, 7):
		var t = PI * k / 6.0
		half.append(Vector2(0.0, -0.031) + Vector2(-sin(t), -cos(t)) * 0.031)
	for k in range(1, 6):
		var t = PI * k / 6.0
		half.append(Vector2(0.0, 0.031) + Vector2(sin(t), -cos(t)) * 0.031)
	u.add_slab(half, 0.002, teal, _pl(fc + n * 0.0025, ex, ey))
	_p(u, "cyl", fc + n * 0.0042 + ey * 0.031, n, Vector3(0.02, 0.002, 0.02), teal, 8)
	_p(u, "cyl", fc + n * 0.0042 - ey * 0.031, n, Vector3(0.02, 0.002, 0.02), white, 8)
	for k in 8:
		var t = TAU * k / 8.0
		_rivet(u, o + n * 0.018 + (ex * cos(t) + ey * sin(t)) * 0.089, n, 0.0055, IRON)
	# mavi boru hatları gövdeyi izler (kanondaki giysi çizgileri)
	var low = _ring(m, ch.y - 0.15)
	_rib(u, _arc(low, 0.0, TAU, 20, pad + 0.002), 0.017, 0.006, blue, Vector3.UP, 4)
	var sh = _loop(m, Vector3(0.112, ch.y - 0.02, 0.0), Vector3.BACK, Vector3.UP, 0.22, ch.y - 0.3, ch.y + 0.2)
	_rib(u, _arc(sh, 0.55, PI + 0.8, 12, pad + 0.002), 0.017, 0.006, blue, Vector3.RIGHT, 4)
	var pts := []
	for k in 7:
		var v = k / 6.0
		var yy = lerpf(y - 0.075, ch.y - 0.15, v)
		pts.append(_lp(_ring(m, yy), lerpf(a, 0.3, v), pad + 0.002))
	_rib(u, pts, 0.015, 0.006, blue, Vector3.RIGHT, 4)
	# sırtta kristal hücre: hatların birleştiği kutu
	var bz: float = _back(m, 0.0, ch.y - 0.04) - pad
	var q: Vector3 = Vector3(0.0, ch.y - 0.05, bz - 0.022)
	u.add_slab(_rr(0.11, 0.15, 0.018), 0.036, bc, _pl(q, Vector3.LEFT, Vector3.UP), Callable(), bc.darkened(0.25))
	_lathe(u, q + OUT * 0.02, OUT, [[0.0, 0.03], [0.008, 0.032], [0.016, 0.022]], teal, 10, 1)
	_rib(u, [Vector3(0.1, ch.y + 0.08, q.z + 0.018), Vector3(0.06, ch.y + 0.03, q.z - 0.0), q + Vector3(0.04, 0.03, 0.0)], 0.015, 0.006, blue, Vector3.BACK, 4)
	_rib(u, [q - Vector3(0.0, 0.07, 0.0), q - Vector3(0.0, 0.1, -0.008)], 0.015, 0.006, blue, Vector3.RIGHT, 4)


static func _mugen(c: Dictionary) -> void:
	var u: MB = c["u"]
	var m = c["m"]
	var ch: Vector3 = c["ch"]
	var pad = float(c["pad"])
	# kaplan yüzlü göğüslüğün kendisi korunur; artık gövdeye bağlı
	var y = ch.y - 0.14
	var fz: float = 0.0
	for dy in [0.0, 0.08, 0.15, 0.21]:
		fz = maxf(fz, _lp(_ring(m, y + dy), 0.0, pad).z)
	var tmp := MB.new()
	load("res://scripts/combat/fx/mugen_kogai_fx.gd").build_chest(tmp)
	var at := Vector3(0.0, y, fz + 0.03)
	u.add_mesh(tmp, Transform3D(Basis.IDENTITY, at))
	# refs/mugen_kogai: altta geniş kahverengi kuşak, omuzlardan inen kayışlar
	var band := Color(0.42, 0.27, 0.17)
	var h: MB = c["h"]
	var low = _ring(m, float(c["hip"].y) + 0.075)
	_rib(h, _arc(low, 0.0, TAU, 24, pad * 0.8), 0.06, 0.008, band, Vector3.UP, 6)
	_rib(h, _arc(low, 0.0, TAU, 24, pad * 0.8 + 0.004), 0.01, 0.008, band.darkened(0.3), Vector3.UP, 4)
	var bk: float = _back(m, 0.0, ch.y - 0.08) - pad
	var dsk := Vector3(0.0, ch.y - 0.08, bk - 0.004)
	for s in [-1.0, 1.0]:
		var l = _loop(m, Vector3(s * 0.1, ch.y - 0.02, 0.0), Vector3.BACK, Vector3.UP, 0.22, ch.y - 0.3, ch.y + 0.2)
		var sp := _arc(l, 0.05, PI + 0.32, 12, pad + 0.001)
		sp.append(dsk)
		_rib(u, sp, 0.03, 0.006, band.darkened(0.15), Vector3.RIGHT, 4)
		var e: Vector3 = _lp(l, 0.05, pad + 0.004)
		_p(u, "torus", e, Vector3.BACK, Vector3(0.04, 0.03, 0.04), Color(0.72, 0.62, 0.32), 8)
	_lathe(u, dsk, OUT, [[-0.002, 0.04], [0.006, 0.042], [0.012, 0.03]], Color(0.72, 0.62, 0.32), 10, 1)


static func _shodai(c: Dictionary) -> void:
	var u: MB = c["u"]
	var m = c["m"]
	var ch: Vector3 = c["ch"]
	var bc: Color = c["bc"]
	var pad = float(c["pad"]) * 0.7
	var ny = ch.y + 0.158
	var neck = _loop(m, Vector3(0.0, ny, 0.015), Vector3.BACK, Vector3.RIGHT, 0.078)
	var yt = ch.y + 0.005   # kristalin üstü
	var fzt: Vector3 = _lp(_ring(m, yt), 0.0, pad + 0.006)
	var cord := Color(0.06, 0.06, 0.07)
	for s in [-1.0, 1.0]:
		var pts := []
		for q in [[PI, 0.008], [2.3, 0.004], [1.55, 0.0], [1.0, -0.012]]:
			pts.append(_lp(neck, s * float(q[0]), 0.012) + Vector3.UP * float(q[1]))
		for q in [[0.62, 0.105], [0.42, 0.07], [0.24, 0.04], [0.1, 0.018]]:
			var yy = yt + float(q[1])
			pts.append(_lp(_ring(m, yy), s * float(q[0]), pad + 0.003))
		pts.append(fzt + Vector3(s * 0.007, 0.0, 0.0))
		_tube(u, pts, 0.0028, cord, 4, 2)
		_p(u, "sphere", fzt + Vector3(s * 0.016, -0.006, 0.0), Vector3.UP, Vector3.ONE * 0.012, Color(0.84, 0.86, 0.9), 6)
	# uzun altıgen kristal, yatık (refs/shodai_kubikazari)
	var ax: Vector3 = Vector3(0.28, -1.0, 0.0).normalized()
	var w: Vector3 = Vector3.BACK.cross(ax).normalized()
	var o: Vector3 = fzt + ax * 0.075 + Vector3.BACK * 0.004
	var dk: Color = bc.darkened(0.42)
	var lt: Color = bc.lightened(0.34)
	_p(u, "cyl", o, ax, Vector3(0.033, 0.104, 0.021), dk, 6)
	_p(u, "cone", o + ax * 0.065, ax, Vector3(0.033, 0.026, 0.021), dk, 6)
	_p(u, "cone", o - ax * 0.062, -ax, Vector3(0.033, 0.02, 0.021), dk, 6)
	var face := PackedVector2Array([Vector2(-0.068, 0.0), Vector2(-0.052, 0.012), Vector2(0.056, 0.012), Vector2(0.074, 0.0), Vector2(0.056, -0.012), Vector2(-0.052, -0.012)])
	u.add_slab(face, 0.002, bc, _pl(o + Vector3.BACK * 0.0108, ax, w))
	var hi := PackedVector2Array([Vector2(-0.05, 0.002), Vector2(0.05, 0.002), Vector2(0.058, 0.009), Vector2(-0.042, 0.009)])
	u.add_slab(hi, 0.001, lt, _pl(o + Vector3.BACK * 0.0123, ax, w))
	var hj := PackedVector2Array([Vector2(0.02, -0.003), Vector2(0.056, -0.003), Vector2(0.046, -0.009), Vector2(0.01, -0.009)])
	u.add_slab(hj, 0.001, Color(0.86, 0.95, 0.95), _pl(o + Vector3.BACK * 0.0123, ax, w))
