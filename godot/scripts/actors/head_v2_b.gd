extends RefCounted
## Sert başlıklar (HeadV2 çağırır): miğfer, lake, hasır koni, tören başlığı. Hepsi başın gerçek ölçüsünden (Fit) kurulur.
## Yüzey kuralı: _grid(u, v): u artan yön teta (+Z önden +X'e), v aşağı / dışa; dış yüz (dv x du) yönüne bakar.
## Kaynak: refs/kiyafet/h_* ve n_* (Hiruzen, Han, Teuchi, Land of Iron samurayları, daimyō, Tatsunami).
const Kit = preload("res://scripts/actors/head_kit.gd")

const STYLES := ["akatsuki", "han", "teuchi", "miğfer", "kabuto", "samuray_s", "samuray_k",
	"tetsu_kabuto", "tsuno_kabuto", "daimyo_kanmuri", "kozan_kabuto"]
const HIDE_HAIR := ["akatsuki", "han", "kage", "kabuto", "miğfer", "tetsu_kabuto", "tsuno_kabuto", "daimyo_kanmuri"]

const GOLD := Color(0.86, 0.68, 0.27)
const BRASS := Color(0.68, 0.52, 0.24)
const IRON := Color(0.17, 0.17, 0.19)


static func build(m, s, col: Color, L: Dictionary) -> bool:
	if not s in STYLES:
		return false
	match s:
		"akatsuki": _akatsuki(m, col)
		"han": _han(m, col)
		"teuchi": _teuchi(m, col)
		"miğfer": _migfer(m, col)
		"kabuto": _kabuto(m, col, String(L.get("crest", "")))
		"samuray_s": _samuray_s(m, col)
		"samuray_k": _samuray_k(m, col)
		"tetsu_kabuto": _tetsu(m, col, false)
		"tsuno_kabuto": _tetsu(m, col, true)
		"daimyo_kanmuri": _kanmuri(m, col)
		"kozan_kabuto": _kozan(m, col)
	return true


# ================================================================ baş ölçüsü
## Alın halkasından kafatasını içine alan kabuk: dome(teta, t) t=0 halka, t=1 tepe. teta 0 = önde (+Z), +90 = +X.
class Fit:
	var x := 0.0
	var z := 0.0
	var by := 0.0
	var top := 0.0
	var k := 1.0
	var rad := PackedFloat32Array()

	func r(th: float) -> float:
		var n := rad.size()
		var g := wrapf(PI * 1.5 - th, 0.0, TAU) / TAU * n
		var i := int(floor(g))
		return lerpf(rad[i % n], rad[(i + 1) % n], g - i) * k

	func d(th: float) -> Vector3:
		return Vector3(sin(th), 0.0, cos(th))

	func ring(th: float, y: float, pad: float) -> Vector3:
		return Vector3(x, y, z) + d(th) * (r(th) + pad)

	func dome(th: float, t: float, pad: float) -> Vector3:
		var a := t * PI * 0.5
		return Vector3(x, by + (top + pad - by) * sin(a), z) + d(th) * (r(th) + pad) * pow(maxf(cos(a), 0.0), 0.8)


static func _fit(m, dy := 0.0) -> Fit:
	m._band_ring_full()
	var f := Fit.new()
	f.x = m.skull_c.x
	f.z = m.skull_c.z
	f.top = m.head_top()
	var raw := PackedFloat32Array()
	if m.band_ring.is_empty():
		f.by = m.eye_center_model.y + 0.04 + dy
		raw.resize(24)
		raw.fill(maxf(m.skull_r.x, 0.09))
	else:
		f.by = float(m.band_ring[0]) + dy
		raw = (m.band_ring[1] as PackedFloat32Array).duplicate()
	var n := raw.size()
	for _p in 2:
		var o := raw.duplicate()
		for i in n:
			raw[i] = (o[(i + n - 1) % n] + o[i] * 2.0 + o[(i + 1) % n]) * 0.25
	f.rad = raw
	var hh := f.top - f.by
	var km := 1.0
	for q in m._head_vs():
		var h: float = q.y - f.by
		if h <= 0.0 or h >= hh * 0.98:
			continue
		var dx: float = q.x - f.x
		var dz: float = q.z - f.z
		var lim := f.r(atan2(dx, dz)) * pow(1.0 - h * h / (hh * hh), 0.4)
		if lim > 0.01:
			km = maxf(km, sqrt(dx * dx + dz * dz) / lim)
	f.k = minf(km, 1.3)
	return f


# ================================================================ yüzey araçları
static func _flat(c: Color) -> Callable:
	return func(_i: int, _j: int, _u: float, _v: float) -> Color: return c


static func _table(nu: int, nv: int, pos: Callable) -> PackedVector3Array:
	var p := PackedVector3Array()
	p.resize((nu + 1) * (nv + 1))
	for j in nv + 1:
		for i in nu + 1:
			p[i + j * (nu + 1)] = pos.call(float(i) / nu, float(j) / nv)
	return p


static func _normals(p: PackedVector3Array, nu: int, nv: int, wrap: bool, flip: bool) -> PackedVector3Array:
	var w := nu + 1
	var o := PackedVector3Array()
	o.resize(p.size())
	for j in nv + 1:
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, nv)
		for i in w:
			var i0 := (i - 1 if i > 0 else nu - 1) if wrap else maxi(i - 1, 0)
			var i1 := (i + 1 if i < nu else 1) if wrap else mini(i + 1, nu)
			var du: Vector3 = p[i1 + j * w] - p[i0 + j * w]
			var dv: Vector3 = p[i + j1 * w] - p[i + j0 * w]
			var c := dv.cross(du)
			o[i + j * w] = (c.normalized() * (-1.0 if flip else 1.0)) if c.length_squared() > 1e-14 else Vector3.ZERO
	for j in nv + 1:   # kutup: komşu sıranın ortalaması
		for i in w:
			if o[i + j * w] == Vector3.ZERO:
				var jn := j + 1 if j < nv else j - 1
				var s := Vector3.ZERO
				for q in w:
					s += o[q + jn * w]
				o[i + j * w] = s.normalized() if s.length_squared() > 1e-9 else Vector3.UP
	return o


static func _emit(mb: MB, p: PackedVector3Array, n: PackedVector3Array, nu: int, nv: int, colf: Callable, rev := false, su := 1, sv := 1) -> void:
	var w := nu + 1
	for j in range(0, nv, sv):
		var j1 := mini(j + sv, nv)
		for i in range(0, nu, su):
			var i1 := mini(i + su, nu)
			var c: Color = colf.call(i, j, float(i) / nu, float(j) / nv)
			var b: int = mb.verts.size()
			for q in [i + j * w, i1 + j * w, i1 + j1 * w, i + j1 * w]:
				mb.verts.append(p[q])
				mb.normals.append(n[q])
				mb.colors.append(c)
				mb.uvs.append(Vector2.ZERO)
			for q in ([0, 2, 1, 0, 3, 2] if rev else [0, 1, 2, 0, 2, 3]):
				mb.idx.append(b + q)


static func _grid(mb: MB, nu: int, nv: int, pos: Callable, colf: Callable, wrap := false, flip := false) -> void:
	var p := _table(nu, nv, pos)
	_emit(mb, p, _normals(p, nu, nv, wrap, flip), nu, nv, colf, flip)


static func _quad(mb: MB, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n := (d - a).cross(b - a).normalized()
	var s: int = mb.verts.size()
	for v in [a, b, c, d]:
		mb.verts.append(v)
		mb.normals.append(n)
		mb.colors.append(col)
		mb.uvs.append(Vector2.ZERO)
	for q in [0, 1, 2, 0, 2, 3]:
		mb.idx.append(s + q)


## Kalınlıklı levha: dış yüz, seyrek iç yüz, dört kenar (kenar rengi = biye)
static func _plate(mb: MB, nu: int, nv: int, pos: Callable, colf: Callable, th: float, edge: Color, wrap := false, flip := false) -> void:
	var p := _table(nu, nv, pos)
	var n := _normals(p, nu, nv, wrap, flip)
	_emit(mb, p, n, nu, nv, colf, flip)
	var q := PackedVector3Array()
	var ni := PackedVector3Array()
	q.resize(p.size())
	ni.resize(p.size())
	for i in p.size():
		q[i] = p[i] - n[i] * th
		ni[i] = -n[i]
	_emit(mb, q, ni, nu, nv, _flat(edge.darkened(0.3)), not flip, maxi(1, nu / 8), maxi(1, nv / 3))
	var w := nu + 1
	var side = func(a: int, b: int) -> void:   # a -> b kenarı; dış yüz sağda
		if flip:
			_quad(mb, q[a], q[b], p[b], p[a], edge)
		else:
			_quad(mb, p[a], p[b], q[b], q[a], edge)
	for i in nu:
		side.call(i + 1, i)
		side.call(i + nv * w, i + 1 + nv * w)
	if not wrap:
		for j in nv:
			side.call(j * w, (j + 1) * w)
			side.call(nu + (j + 1) * w, nu + j * w)


## Y ekseni çevresinde dönel gövde; prof: üstten dışa / aşağı (r, y)
static func _lathe(mb: MB, c: Vector3, prof: Array, na: int, colf: Callable, off := Callable()) -> void:
	var nv := prof.size() - 1
	var pos = func(u: float, v: float) -> Vector3:
		var j := int(round(v * nv))
		var a := u * TAU - PI
		var q: Vector2 = prof[j]
		var o: Vector2 = off.call(a, j) if off.is_valid() else Vector2(1.0, 0.0)
		return c + Vector3(sin(a) * q.x * o.x, q.y + o.y, cos(a) * q.x * o.x)
	_grid(mb, na, nv, pos, colf, true)


static func _cr(p: Array, sub: int) -> Array:
	var out := []
	for i in p.size() - 1:
		var p0: Vector3 = p[maxi(i - 1, 0)]
		var p1: Vector3 = p[i]
		var p2: Vector3 = p[i + 1]
		var p3: Vector3 = p[mini(i + 2, p.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(p[p.size() - 1])
	return out


## Boru: r0 -> r1; flat: ikinci eksende yassılık; cap: uçta kapanır
static func _tube(mb: MB, pts: Array, r0: float, r1: float, colf: Callable, sides := 6, flat := 1.0, cap := true, up := Vector3.ZERO, tp := 1.0) -> void:
	var n := pts.size()
	var rows := []
	var t0: Vector3 = (pts[1] - pts[0]).normalized()
	var ax := up if up != Vector3.ZERO else (Vector3.BACK if absf(t0.z) < 0.9 else Vector3.RIGHT)
	var nn := (ax - t0 * ax.dot(t0)).normalized()
	for j in n:
		var t: Vector3 = (pts[mini(j + 1, n - 1)] - pts[maxi(j - 1, 0)]).normalized()
		nn = (nn - t * nn.dot(t)).normalized()
		rows.append([pts[j], nn, nn.cross(t), lerpf(r0, r1, pow(float(j) / (n - 1), tp))])
	if cap:
		var e: Array = rows[n - 1].duplicate()
		e[3] = 0.0
		rows.append(e)
	var nv := rows.size() - 1
	var pos = func(u: float, v: float) -> Vector3:
		var e: Array = rows[int(round(v * nv))]
		var a := u * TAU
		return e[0] + (e[1] * cos(a) + e[2] * sin(a) * flat) * float(e[3])
	_grid(mb, sides, nv, pos, colf, true)


## Daire (hafif kubbeli); colf v = merkezden kenara
static func _disc(mb: MB, c: Vector3, n: Vector3, r: float, colf: Callable, seg := 14, rings := 2, dome := 0.0) -> void:
	var nn := n.normalized()
	var t := (Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT).cross(nn).normalized()
	var b := nn.cross(t)
	var pos = func(u: float, v: float) -> Vector3:
		var a := u * TAU
		return c + (t * cos(a) + b * sin(a)) * r * v + nn * dome * (1.0 - v * v)
	_grid(mb, seg, rings, pos, colf, true)


static func _rivet(mb: MB, p: Vector3, n: Vector3, r: float, c: Color) -> void:
	_disc(mb, p, n, r, func(_i: int, j: int, _u: float, _v: float) -> Color: return c.lightened(0.1) if j == 0 else c, 6, 1, r * 0.75)


## Bükülmüş ip görünüşü
static func _braid(mb: MB, pts: Array, r: float, c: Color) -> void:
	var c2 := c.darkened(0.28)
	_tube(mb, pts, r, r, func(i: int, j: int, _u: float, _v: float) -> Color: return c if (i + j) % 2 == 0 else c2, 4, 1.0, false)


## Alın halkası çevresinde bant
static func _ring_band(mb: MB, f: Fit, y0: float, y1: float, pad: float, colf: Callable, nu := 48, nv := 2) -> void:
	var pos = func(u: float, v: float) -> Vector3:
		return f.ring(u * TAU - PI, lerpf(y0, y1, v), pad)
	_grid(mb, nu, nv, pos, colf, true)


## Başı saran kabuk + arkada enseye inen etek. split: dome/etek sınırı (v); drop(teta)
static func _cap(mb: MB, f: Fit, pad: float, nu: int, nd: int, ns: int, drop: Callable, colf: Callable, tmax := 1.0) -> float:
	var nv := nd + ns
	var split := float(nd) / nv
	var pos = func(u: float, v: float) -> Vector3:
		var th := u * TAU - PI
		if v <= split + 1e-5:
			return f.dome(th, tmax * (1.0 - v / split), pad)
		var s := (v - split) / (1.0 - split)
		var dd: float = drop.call(th)
		return f.ring(th, f.by - dd * s, pad + 0.004 * s)
	_grid(mb, nu, nv, pos, colf, true)
	return split


static func _back_drop(amount: float, a0 := 1.0, a1 := 2.4) -> Callable:
	return func(th: float) -> float: return amount * smoothstep(a0, a1, absf(wrapf(th, -PI, PI)))


static func _put(m, mb: MB) -> MeshInstance3D:
	return Kit._put(m, mb, Vector3.ZERO)


## Mesh'i Head kemiğine sarkan parça olarak takar. chains: PackedVector3Array listesi; assign boşsa en yakın zincir.
static func _hang(m, mb: MB, chains: Array, stiff: float, nm: String, grav := 0.4, assign := Callable()) -> void:
	if mb.verts.is_empty():
		return
	var defs := []
	for pts in chains:
		var hp: Dictionary = CharacterModel.hair_profile(0.2)
		hp["stiff"] = stiff
		hp["stiff_tip"] = stiff * 0.7
		hp["grav"] = grav
		hp["col_r"] = 0.03
		hp["pts"] = pts
		defs.append(hp)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = mb.verts
	arr[Mesh.ARRAY_NORMAL] = mb.normals
	arr[Mesh.ARRAY_COLOR] = mb.colors
	arr[Mesh.ARRAY_TEX_UV] = mb.uvs
	arr[Mesh.ARRAY_INDEX] = mb.idx
	var fn := assign
	if not fn.is_valid():
		fn = func(_i: int, v: Vector3, _si: int) -> Array:
			var best := 0
			var bs := 0.0
			var bd := 1e9
			for c in chains.size():
				var r: Array = Dangle.project(chains[c], v)
				if float(r[1]) < bd:
					bd = r[1]
					bs = r[0]
					best = c
			return [[best, bs, 1.0]]
	var pack := Dangle.build(null, defs, fn, [arr])
	if not pack.is_empty():
		m.add_dangle("Head", pack, LazyFx.g("Props").toon(), Transform3D.IDENTITY, nm)


## Baş çevresinde kumaş / kâğıt perde: komşu zincirler arasında ağırlıklı, bütün halinde salınır. Açılar 0..TAU.
static func curtain(m, mb: MB, top: Vector3, a0: float, a1: float, nc: int, p_at: Callable, len_at: Callable, stiff: float, nm: String) -> void:
	var chains := []
	for c in nc:
		var a := lerpf(a0, a1, float(c) / (nc - 1))
		var pts := PackedVector3Array()
		for k in 5:
			pts.append(p_at.call(a, k / 4.0))
		chains.append(pts)
	var fn = func(_i: int, v: Vector3, _si: int) -> Array:
		var d := v - top
		var a := atan2(d.x, d.z)
		if a < 0.0:
			a += TAU
		var g := clampf((a - a0) / (a1 - a0), 0.0, 1.0) * (nc - 1)
		var c0 := mini(int(floor(g)), nc - 2)
		var w := g - c0
		var vv := clampf(-d.y / maxf(float(len_at.call(a)), 0.01), 0.0, 1.0) * 4.0
		return [[c0, vv, 1.0 - w], [c0 + 1, vv, w]]
	_hang(m, mb, chains, stiff, nm, 0.15, fn)


## Çene ipi: şapka içinden iki yandan çene altında düğüm
static func _chin_cord(mb: MB, m, f: Fit, y0: float, c: Color, r := 0.0035) -> Vector3:
	var hw := Kit._hw(m)
	var hc: Vector3 = m._head_center()
	var knot := Vector3(hc.x, m.eye_center_model.y - 0.135, hc.z + 0.055)
	for s: float in [-1.0, 1.0]:
		var top := Vector3(hc.x + s * hw * 0.55, y0, hc.z)
		var mid := Vector3(hc.x + s * hw * 0.53, hc.y - 0.07, hc.z + 0.03)
		var low := Vector3(hc.x + s * hw * 0.34, knot.y + 0.01, hc.z + 0.05)
		_braid(mb, _cr([top, mid, low, knot], 3), r, c)
	_lathe(mb, knot + Vector3(0, -0.002, 0), [Vector2(0.001, 0.008), Vector2(0.008, 0.005), Vector2(0.009, -0.002), Vector2(0.004, -0.008), Vector2(0.001, -0.009)], 8, _flat(c.darkened(0.12)))
	return knot


static func _glyph(m, mi: Node3D, ch: String, p: Vector3, th: float, roll: float, c: Color, px := 0.00105, tilt := 0.0) -> void:
	var l := Label3D.new()
	l.text = ch
	l.font = LazyFx.g("KageAttire")._font()
	l.font_size = 64
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = p
	l.rotation = Vector3(tilt, th, roll)
	mi.add_child(l)


# ================================================================ hasır koni
## Dokuma koni: ışınsal çubuklar, halka bağlar, bağlı kenar, kafes iç yüz, baş bandı
static func _straw(mb: MB, c: Vector3, R: float, H: float, col: Color, tip: Color, exp_c: float, spokes: int, hoop: int) -> void:
	var nt := 13
	var p := []
	for k in nt + 1:
		var t := float(k) / nt
		p.append(Vector2(maxf(R * t, 0.002), H * pow(1.0 - t, exp_c)))
	var n0 := p.size()
	p.append(Vector2(R + 0.004, -0.003))
	p.append(Vector2(R + 0.006, -0.009))
	p.append(Vector2(R + 0.001, -0.014))
	var na := spokes * 4
	var colf = func(i: int, j: int, _u: float, _v: float) -> Color:
		if j >= n0 - 1:
			return col.darkened(0.5) if i % 4 != 0 else col.darkened(0.3)   # bağlı kenar, dikiş
		if j < 2:
			return tip
		if j % hoop == 0:
			return col.darkened(0.3)
		if i % 4 == 0:
			return col.darkened(0.2)
		var w := col.lightened(0.07) if (i + j * 2) % 4 < 2 else col.darkened(0.05)
		return w.darkened(0.05 * float(j % 2))
	var off = func(a: float, j: int) -> Vector2:
		return Vector2(1.0, sin(a * spokes) * 0.0012 if j > 1 and j < n0 - 1 else 0.0)
	_lathe(mb, c, p, na, colf, off)
	var under := [Vector2(R + 0.001, -0.014), Vector2(R * 0.72, H * 0.2), Vector2(R * 0.42, H * 0.47), Vector2(0.01, H * 0.8)]
	_lathe(mb, c, under, spokes * 2, func(i: int, j: int, _u: float, _v: float) -> Color: return col.darkened(0.62 if i % 2 == 0 else 0.5).darkened(0.05 * j))
	_lathe(mb, c + Vector3(0, H + 0.001, 0), [Vector2(0.001, 0.016), Vector2(0.012, 0.012), Vector2(0.017, 0.002), Vector2(0.024, -0.008), Vector2(0.03, -0.014)], 12, _flat(tip.lightened(0.05)))


static func _akatsuki(m, col: Color) -> void:
	var f := _fit(m)
	var hw := Kit._hw(m)
	var ey: float = m.eye_center_model.y
	var hh := clampf(m.head_ab.size.y, 0.12, 0.26) if m.head_ab.size.y > 0.05 else 0.2
	var R := hw * 1.5
	var by0 := ey + 0.045
	var H := maxf(R * 0.68, (m.head_top() + 0.02 - by0) / 0.6)
	var c := Vector3(f.x, by0, f.z - 0.01)
	var mb := MB.new()
	_straw(mb, c, R, H, col, Color(0.12, 0.1, 0.1), 1.05, 22, 4)
	_ring_band(mb, f, by0 + 0.03, by0 - 0.008, 0.008, _flat(Color(0.13, 0.11, 0.1)), 32, 1)
	_put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, by0 + 0.01, 0))
	# kâğıt şeritler (shide): bitişik, boyları farklı, önde yüz için aralık
	var nst := 30
	var a0 := deg_to_rad(36.0)
	var a1 := deg_to_rad(324.0)
	var step := (a1 - a0) / nst
	var rr := R * 0.74
	var top := c + Vector3(0, -0.006, 0)
	var len_at = func(a: float) -> float:
		var k := clampi(int((a - a0) / step), 0, nst - 1)
		return hh * (1.22 + 0.2 * float((k * 7) % 3) / 2.0)
	var p_at = func(a: float, v: float) -> Vector3:
		var d := Vector3(sin(a), 0, cos(a))
		return top + d * (rr + 0.014 * v * v) + Vector3(0, -float(len_at.call(a)) * v, 0)
	var sm := MB.new()
	var paper := Color(0.93, 0.94, 0.95)
	for k in nst:
		var a := a0 + step * (k + 0.5)
		var hw2 := step * 0.47
		var ln: float = len_at.call(a)
		var pos = func(u: float, v: float) -> Vector3:
			var d := Vector3(sin(a + (u - 0.5) * 2.0 * hw2), 0, cos(a + (u - 0.5) * 2.0 * hw2))
			var notch := absf(u - 0.5) * 0.05 * smoothstep(0.92, 1.0, v)
			return top + d * (rr + 0.014 * v * v + (0.0015 if k % 2 == 0 else 0.0)) + Vector3(0, -ln * (v - notch), 0)
		var pc := paper.darkened(0.05 * (k % 3))
		var cf = func(i: int, j: int, _u: float, _v: float) -> Color:
			return pc.darkened(0.08 if i == 0 else 0.0).darkened(0.07 if j == 1 else 0.0)
		_grid(sm, 2, 4, pos, cf)
		_grid(sm, 1, 2, pos, _flat(pc.darkened(0.25)), false, true)
	curtain(m, sm, top, a0, a1, 11, p_at, len_at, 0.42, "AkatsukiShide")
	# ip ucunda çan
	var ba := deg_to_rad(30.0)
	var b0 := c + Vector3(sin(ba), 0, cos(ba)) * (R * 0.86) + Vector3(0, H * 0.1, 0)
	var chain := PackedVector3Array([b0, b0 + Vector3(0, -0.04, 0), b0 + Vector3(0, -0.08, 0), b0 + Vector3(0, -0.105, 0)])
	var bm := MB.new()
	_braid(bm, [b0, b0 + Vector3(0, -0.04, 0), b0 + Vector3(0, -0.075, 0)], 0.002, Color(0.62, 0.12, 0.1))
	_bell(bm, b0 + Vector3(0, -0.092, 0), 0.016)
	_hang(m, bm, [chain], 0.5, "AkatsukiBell", 0.6)


static func _bell(mb: MB, c: Vector3, r: float) -> void:
	var p := [Vector2(0.001, r * 1.25), Vector2(r * 0.3, r * 1.2), Vector2(r * 0.34, r * 1.0), Vector2(r * 0.72, r * 0.82), Vector2(r * 0.95, r * 0.25),
		Vector2(r * 1.0, -r * 0.2), Vector2(r * 0.86, -r * 0.62), Vector2(r * 0.4, -r * 0.9), Vector2(0.001, -r * 0.95)]
	var dk := BRASS.darkened(0.45)
	_lathe(mb, c, p, 12, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j >= 6 and (i % 6 == 0 or j == 7):
			return dk   # alt yarık
		return GOLD if j == 3 else BRASS)
	_tube(mb, _ring_pts(c + Vector3(0, r * 1.45, 0), Vector3.BACK, r * 0.32, 8), 0.0016, 0.0016, _flat(BRASS), 4, 1.0, false)


static func _ring_pts(c: Vector3, n: Vector3, r: float, seg: int) -> Array:
	var t := (Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).cross(n).normalized()
	var b := n.cross(t).normalized()
	var o := []
	for i in seg + 1:
		var a := TAU * i / seg
		o.append(c + (t * cos(a) + b * sin(a)) * r)
	return o


static func _han(m, col: Color) -> void:
	var f := _fit(m)
	var hw := Kit._hw(m)
	var ey: float = m.eye_center_model.y
	var hh := clampf(m.head_ab.size.y, 0.12, 0.26) if m.head_ab.size.y > 0.05 else 0.2
	var R := hw * 1.8
	var by0 := ey + 0.05
	var H := maxf(R * 0.44, (m.head_top() + 0.02 - by0) / 0.56)
	var c := Vector3(f.x, by0, f.z - 0.01)
	var straw := Color(0.72, 0.73, 0.76)
	var mb := MB.new()
	_straw(mb, c, R, H, straw, Color(0.23, 0.17, 0.13), 0.96, 26, 3)
	# alnın üstünde deri taşıyıcı bant, perçinli
	var leather := Color(0.2, 0.15, 0.13)
	_ring_band(mb, f, by0 + 0.012, by0 - 0.018, 0.009, func(_i: int, j: int, _u: float, _v: float) -> Color: return leather.lightened(0.1) if j == 0 else leather, 40, 2)
	for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		var q := f.ring(a, by0 - 0.003, 0.01)
		_rivet(mb, q, f.d(a), 0.0034, BRASS)
	# çene bağı: iki yandan çene altına inen geniş bez
	var hc: Vector3 = m._head_center()
	var chin := Vector3(hc.x, ey - 0.128, hc.z + 0.05)
	for s: float in [-1.0, 1.0]:
		_tube(mb, _cr([Vector3(hc.x + s * hw * 0.56, by0 - 0.03, hc.z - 0.005), Vector3(hc.x + s * hw * 0.54, hc.y - 0.075, hc.z + 0.03), Vector3(hc.x + s * hw * 0.3, chin.y + 0.002, hc.z + 0.055), chin], 4),
			0.012, 0.012, _flat(col.darkened(0.14)), 5, 0.3, false)
	_put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, by0 + 0.01, 0))
	# yanlardan ve arkadan inen tek parça kumaş
	var top := c + Vector3(0, -0.012, 0)
	var r_in := hw * 0.64
	var a0 := deg_to_rad(42.0)
	var a1 := deg_to_rad(318.0)
	var len_at = func(a: float) -> float:
		var fr := absf(wrapf(a, -PI, PI))
		return hh * lerpf(1.5, 1.2, smoothstep(1.2, 2.6, fr))
	var p_at = func(a: float, v: float) -> Vector3:
		var d := Vector3(sin(a), 0, cos(a))
		var fold := sin(a * 13.0 + 0.4) * 0.0055 * smoothstep(0.08, 0.5, v)
		return top + d * (r_in + 0.055 * v * v + 0.018 * v + fold) + Vector3(0, -float(len_at.call(a)) * v, 0)
	var cm := MB.new()
	var nu := 52
	var nv := 7
	var pos = func(u: float, v: float) -> Vector3: return p_at.call(lerpf(a0, a1, u), v)
	var cf = func(i: int, j: int, _u: float, _v: float) -> Color:
		if j == nv - 1:
			return col.darkened(0.3) if i % 2 == 0 else col.darkened(0.2)
		return col.darkened(0.05 * ((i / 2) % 3))
	_plate(cm, nu, nv, pos, cf, 0.003, col.darkened(0.25))
	curtain(m, cm, top, a0, a1, 9, p_at, len_at, 0.48, "HanVeil")


# ================================================================ Ichiraku kepi
static func _teuchi(m, col: Color) -> void:
	var f := _fit(m, -0.006)
	var ytop: float = m.head_top() + 0.022
	var yb := f.by
	var h := ytop - yb
	var p := [Vector2(0.0, ytop - 0.004), Vector2(0.45, ytop - 0.003), Vector2(0.8, ytop), Vector2(0.98, ytop - 0.001), Vector2(1.075, ytop - 0.007),
		Vector2(1.1, ytop - 0.02), Vector2(1.085, yb + h * 0.72), Vector2(1.05, yb + h * 0.45), Vector2(1.02, yb + h * 0.2), Vector2(1.012, yb + 0.03), Vector2(1.012, yb + 0.012), Vector2(1.02, yb), Vector2(0.98, yb - 0.004)]
	var nv := p.size() - 1
	var nu := 64
	var pos = func(u: float, v: float) -> Vector3:
		var q: Vector2 = p[int(round(v * nv))]
		var th := u * TAU - PI
		var wr := 1.0 + 0.009 * sin(th * 5.0 + 1.0) * clampf(q.x, 0.0, 1.0) * smoothstep(yb + 0.03, yb + h * 0.5, q.y)
		return Vector3(f.x, q.y, f.z) + f.d(th) * (f.r(th) + 0.008) * q.x * wr
	var hem := col.darkened(0.12) if col.v > 0.3 else col.lightened(0.07)
	var seam := col.darkened(0.3) if col.v > 0.3 else col.lightened(0.16)
	var cf = func(i: int, j: int, _u: float, _v: float) -> Color:
		if j >= 9 and j <= 10:
			if j == 9 and i % 2 == 0:
				return seam   # dikiş sırası
			return hem
		if j == 11:
			return seam
		if j >= 4 and (i == 0 or i == nu / 2 or i == nu / 2 - 1):
			return seam   # önde ve arkada dikiş
		if j == 4:
			return col.lightened(0.05)
		return col
	var mb := MB.new()
	_grid(mb, nu, nv, pos, cf, true)
	var mi := _put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, yb - 0.014, 0))
	var red := Color(0.78, 0.14, 0.11)
	var at = func(th: float, y: float) -> Vector3:
		return Vector3(f.x, y, f.z) + f.d(th) * ((f.r(th) + 0.008) * 1.05 + 0.0035)
	_glyph(m, mi, "一", at.call(-0.74, yb + h * 0.3), -0.74, 0.3, red, 0.00078)
	_glyph(m, mi, "楽", at.call(-0.26, yb + h * 0.46), -0.26, 0.3, red, 0.00088)


# ================================================================ Hiruzen savaş miğferi
static func _migfer(m, col: Color) -> void:
	var f := _fit(m, 0.03)
	var by0 := f.by - 0.03
	var drop := _back_drop(0.115, 0.9, 2.3)
	var mb := MB.new()
	var nu := 56
	var trim := col.darkened(0.2)
	var cf = func(i: int, j: int, _u: float, _v: float) -> Color:
		if j >= 8 and j <= 9:
			return trim if j == 8 else col.darkened(0.08)
		if i % 14 == 0 and j > 0:
			return col.darkened(0.16)
		return col.lightened(0.04) if j == 2 or j == 3 else col
	_cap(mb, f, 0.011, nu, 8, 3, drop, cf)
	var rim := []
	for k in 49:
		var th := TAU * k / 48.0 - PI
		rim.append(f.ring(th, f.by - float(drop.call(th)), 0.0155))
	_tube(mb, rim, 0.0036, 0.0036, _flat(trim.darkened(0.14)), 5, 1.0, false)
	for k in 12:
		var th := PI + (k - 5.5) * 0.28
		var q := f.ring(th, f.by - float(drop.call(th)) + 0.012, 0.0155)
		_rivet(mb, q, f.d(th), 0.003, trim.darkened(0.3))
	_put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, by0 - 0.02, 0))
	m._hitai("Head", Vector3(f.x, by0 + 0.014, f.z), m.band_ring[1], col.darkened(0.06), 0.04, 0.042, 0.64, 0.004, Vector3.ZERO, true, 0.0, 0.0, 0.014)
	# yanlarda birbirine bağlı dört zeytin levha + kulak kanadı
	var olive := Color(0.46, 0.45, 0.3)
	for s: float in [-1.0, 1.0]:
		var th0: float = s * deg_to_rad(101.0)
		var span := deg_to_rad(58.0)
		var sm := MB.new()
		var ytop := by0 - 0.012
		var wing = func(u: float, v: float) -> Vector3:
			var th: float = th0 + (u - 0.5) * span * (0.74 + 0.1 * v)
			return f.ring(th, by0 + 0.03 - 0.042 * v, 0.021 + 0.005 * sin(v * PI))
		_plate(sm, 10, 3, wing, func(_i: int, j: int, _u: float, _v: float) -> Color: return col.darkened(0.12) if j < 2 else trim, 0.004, trim.darkened(0.2))
		var ch := PackedVector3Array()
		for j in 5:
			ch.append(f.ring(th0, ytop - j * 0.047, 0.025 + j * 0.004))
		for j in 4:
			var yt := ytop - j * 0.046
			var pad := 0.02 + j * 0.0045
			var lame = func(u: float, v: float) -> Vector3:
				var th: float = th0 + (u - 0.5) * span * (1.0 + j * 0.03)
				return f.ring(th, yt - 0.054 * v, pad + 0.007 * v + 0.0035 * sin(v * PI))
			var lc = func(_i: int, r: int, _u: float, _v: float) -> Color:
				return olive.lightened(0.12) if r == 0 else (olive.darkened(0.3) if r == 3 else olive)
			_plate(sm, 10, 4, lame, lc, 0.004, olive.darkened(0.35))
			for u in [0.2, 0.8]:
				var q: Vector3 = lame.call(u, 0.14)
				var nn := f.d(th0 + (u - 0.5) * span)
				_rivet(sm, q + nn * 0.001, nn, 0.0038, IRON.lightened(0.15))
				var e: Vector3 = lame.call(u, 0.98)
				_tube(sm, _ring_pts(e + nn * 0.004, nn.cross(Vector3.UP).normalized(), 0.0058, 7), 0.0014, 0.0014, _flat(IRON), 4, 1.0, false)
		_hang(m, sm, [ch], 0.82, "MigferLame", 0.7)


# ================================================================ kabuto
static func _kabuto(m, col: Color, crest: String) -> void:
	var f := _fit(m, 0.012)
	var lace := Color(0.62, 0.2, 0.11) if col.r < 0.4 else Color(0.13, 0.15, 0.3)
	var mb := MB.new()
	var nu := 60
	var bright := col.lightened(0.09)
	var dark := col.darkened(0.35)
	var ridge := func(u: float) -> float: return 1.0 if posmod(int(round(u * nu)), 3) == 0 else 0.0
	# hachi: sırtlı levha çanak
	var bowl = func(u: float, v: float) -> Vector3:
		var th := u * TAU - PI
		var t := 0.93 * (1.0 - v)
		return f.dome(th, t, 0.013 + 0.0032 * float(ridge.call(u)) * smoothstep(0.0, 0.2, v))
	var bc = func(i: int, j: int, _u: float, _v: float) -> Color:
		if j >= 9:
			return GOLD if j == 10 else col.darkened(0.2)   # koshimaki
		if j == 0:
			return GOLD.darkened(0.15)
		return bright if i % 3 == 0 else (col if i % 3 == 1 else dark.lightened(0.1))
	_grid(mb, nu, 11, bowl, bc, true)
	for k in 12:
		var th := TAU * (k + 0.5) / 12.0 - PI
		for q in 3:
			var t := 0.2 + q * 0.21
			var pr := f.dome(th, t, 0.0165)
			_rivet(mb, pr, (pr - Vector3(f.x, f.by - 0.02, f.z)).normalized(), 0.0034, GOLD.darkened(0.08))
	# tehen: tepe halkası
	var tp := f.dome(0.0, 0.93, 0.013)
	_lathe(mb, Vector3(f.x, tp.y + 0.002, f.z), [Vector2(0.004, 0.003), Vector2(0.015, 0.0035), Vector2(0.024, 0.002), Vector2(0.034, -0.003), Vector2(0.042, -0.01), Vector2(0.046, -0.016)], 20,
		func(_i: int, j: int, _u: float, _v: float) -> Color: return Color(0.08, 0.07, 0.07) if j == 0 else (GOLD if j % 2 == 1 else GOLD.darkened(0.2)))
	# mabizashi: öne eğik lake siper
	var vis = func(u: float, v: float) -> Vector3:
		var a := (u - 0.5) * 2.7
		var ext := 0.056 * (1.0 - pow(absf(a / 1.35), 3.0))
		return f.ring(a, f.by + 0.008 - 0.024 * v + 0.012 * v * v, 0.012) + f.d(a) * ext * v
	_plate(mb, 18, 4, vis, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j == 3:
			return GOLD
		if j == 0:
			return GOLD.darkened(0.25) if i % 2 == 0 else col.darkened(0.25)
		return bright if j == 1 else col, 0.004, GOLD.darkened(0.2))
	# shikoro: beş kat, renkli ip dizili
	var open := 1.08
	for l in 5:
		var yt := f.by - 0.004 - l * 0.031
		var fl := 0.013 + l * 0.0105
		var lame = func(u: float, v: float) -> Vector3:
			var th := lerpf(open, TAU - open, u)
			var e := smoothstep(0.0, 0.11, minf(u, 1.0 - u))
			var y := yt - 0.041 * v * (0.6 + 0.4 * e) + (1.0 - e) * 0.008 * l
			return f.ring(th, y, fl + 0.0125 * v + 0.0035 * sin(v * PI))
		var last := l == 4
		var lc = func(i: int, j: int, _u: float, _v: float) -> Color:
			if j == 0:
				return GOLD.darkened(0.1) if l == 0 else bright
			if j == 3:
				return (Color(0.92, 0.9, 0.82) if i % 2 == 0 else Color(0.72, 0.16, 0.12)) if last else col.darkened(0.2)
			if i % 3 == 0:
				return col.darkened(0.42)
			return lace if j == 1 else lace.darkened(0.16)
		_plate(mb, 36, 4, lame, lc, 0.003, col.darkened(0.3))
	# fukigaeshi: kıvrık kanatlar
	for s: float in [-1.0, 1.0]:
		var th: float = s * open
		var d := f.d(th)
		var bk := Vector3(cos(th), 0, -sin(th)) * s
		var e1 := (d * 0.8 + bk * 0.6).normalized()
		var o := f.ring(th, f.by + 0.006, 0.016)
		var wg = func(u: float, v: float) -> Vector3:
			return o + e1 * 0.078 * u * (1.0 - 0.24 * v) + Vector3(0, -0.07 * v * (0.72 + 0.28 * u) + 0.008 * sin(u * PI), 0) + d * 0.012 * sin(u * PI)
		var gc = func(i: int, j: int, _u: float, _v: float) -> Color:
			if i >= 8 or j == 0 or j >= 5:
				return GOLD
			return col.lightened(0.05) if (i + j) % 2 == 0 else col
		_plate(mb, 9, 6, wg, gc, 0.0035, GOLD.darkened(0.2), false, s < 0.0)
		var mon: Vector3 = wg.call(0.5, 0.48)
		var nn := (d * 0.6 - bk * 0.8).normalized()
		_disc(mb, mon + nn * 0.003, nn, 0.011, func(_i: int, j: int, _u: float, _v: float) -> Color: return GOLD if j == 1 else col.darkened(0.3), 10, 2, 0.002)
	# maedate
	var base := f.ring(0.0, f.by + 0.036, 0.024)
	if crest == "kuwagata":
		for s: float in [-1.0, 1.0]:
			var bl = func(u: float, v: float) -> Vector3:
				var q := 1.0 - v
				var ctr := base + Vector3(s * (0.012 + 0.078 * q - 0.012 * q * q * q), 0.008 + 0.15 * q + 0.016 * q * q, 0.006 + 0.024 * q)
				var w := 0.017 * pow(1.0 - q, 0.62) + 0.0025
				var sd := Vector3(1.0, -s * (0.45 - 0.2 * q), 0.0).normalized()
				return ctr + sd * (u - 0.5) * w * 2.0
			_plate(mb, 4, 10, bl, func(i: int, _j: int, _u: float, _v: float) -> Color: return GOLD.lightened(0.14) if i == 1 else (GOLD if i == 2 else GOLD.darkened(0.12)), 0.003, GOLD.darkened(0.3))
	else:
		var cres = func(u: float, v: float) -> Vector3:
			var a := (u - 0.5) * 2.0 * 2.25
			var rr := 0.092
			var w := 0.03 * pow(maxf(cos(a * 0.7), 0.0), 0.8) + 0.002
			var r2 := rr - (1.0 - v) * w
			return base + Vector3(sin(a) * r2, rr * 0.78 - cos(a) * r2 * 0.78, 0.004 + 0.006 * (1.0 - cos(a)))
		_plate(mb, 24, 2, cres, func(_i: int, j: int, _u: float, _v: float) -> Color: return GOLD.lightened(0.12) if j == 1 else GOLD, 0.003, GOLD.darkened(0.3))
	_disc(mb, base + Vector3(0, 0.002, 0.004), Vector3(0, 0.1, 1), 0.021, func(_i: int, j: int, _u: float, _v: float) -> Color: return [GOLD.lightened(0.1), col.darkened(0.2), GOLD][j], 14, 3, 0.005)
	_chin_cord(mb, m, f, f.by - 0.01, lace.darkened(0.12), 0.0034)
	_put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, f.by - 0.04, 0))


# ================================================================ samuray başlıkları (Striker)
static func _samuray_s(m, col: Color) -> void:
	var f := _fit(m, 0.004)
	var hw := Kit._hw(m)
	var drop := _back_drop(0.1, 1.0, 2.4)
	var hi := col.lightened(0.1)
	var mb := MB.new()
	_cap(mb, f, 0.009, 48, 8, 3, drop, func(i: int, j: int, _u: float, _v: float) -> Color:
		if i % 8 == 0 and j > 0:
			return col.lightened(0.14)
		return hi if j == 2 or j == 3 else col)
	var rim := []
	for k in 41:
		var th := TAU * k / 40.0 - PI
		rim.append(f.ring(th, f.by - float(drop.call(th)), 0.0125))
	_tube(mb, rim, 0.0032, 0.0032, _flat(BRASS), 5, 1.0, false)
	# alında arma: pirinç halka, yelpaze
	var p0 := f.dome(0.0, 0.13, 0.014)
	var nn := Vector3(0, 0.3, 1).normalized()
	var sd := Vector3.RIGHT
	var up := nn.cross(sd).normalized() * -1.0
	if up.y < 0.0:
		up = -up
	_lathe_on(mb, p0, nn, 0.041, BRASS)
	var red := Color(0.78, 0.1, 0.1)
	var white := Color(0.93, 0.93, 0.92)
	var c0 := p0 + nn * 0.004 + up * 0.007
	_disc(mb, c0, nn, 0.027, func(i: int, j: int, _u: float, _v: float) -> Color:
		var a := TAU * (i + 0.5) / 20.0
		var q := (Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT).cross(nn).normalized()
		var bb := nn.cross(q)
		var dd := (q * cos(a) + bb * sin(a)).dot(up)
		return white if dd < -0.25 and j > 0 else red, 20, 3, 0.002)
	_tube(mb, [c0 - up * 0.024 + nn * 0.002, c0 - up * 0.043 + nn * 0.002], 0.0042, 0.0042, _flat(white), 5, 0.5, true, nn)
	_put_cords(mb, m, f, hw)
	_put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, f.by - 0.014, 0))
	# sert kenarlı yan kanatlar + püsküller
	var lav := Color(0.62, 0.55, 0.78)
	for s: float in [-1.0, 1.0]:
		var th0: float = s * deg_to_rad(104.0)
		var span := deg_to_rad(44.0)
		var sm := MB.new()
		var wing = func(u: float, v: float) -> Vector3:
			var th: float = th0 + (u - 0.5) * span * (1.0 - 0.34 * v * v)
			var e := 1.0 - 0.3 * pow(absf(u - 0.5) * 2.0, 4.0)
			return f.ring(th, f.by - 0.012 - 0.082 * v * e, 0.016 + 0.03 * v * v)
		var wc = func(i: int, j: int, _u: float, _v: float) -> Color:
			if j == 0:
				return BRASS
			if i == 0 or i == 7 or j == 5:
				return lav.darkened(0.2) if (i + j) % 2 == 0 else col.lightened(0.12)
			return col.lightened(0.05)
		_plate(sm, 8, 6, wing, wc, 0.004, col.lightened(0.14))
		var ch := PackedVector3Array()
		for j in 4:
			ch.append(wing.call(0.5, j / 3.0))
		_hang(m, sm, [ch], 0.7, "SamurayWing", 0.5)
	var hc: Vector3 = m._head_center()
	var knot := Vector3(hc.x, m.eye_center_model.y - 0.135, hc.z + 0.055)
	for s: float in [-1.0, 1.0]:
		var t0: Vector3 = knot + Vector3(s * 0.006, -0.006, 0.002)
		var ch := PackedVector3Array([t0, t0 + Vector3(s * 0.004, -0.035, 0.003), t0 + Vector3(s * 0.008, -0.07, 0.005), t0 + Vector3(s * 0.01, -0.1, 0.006)])
		var tm := MB.new()
		_lathe(tm, t0 + Vector3(0, -0.006, 0), [Vector2(0.001, 0.005), Vector2(0.006, 0.003), Vector2(0.0065, -0.006), Vector2(0.008, -0.009)], 8, _flat(BRASS))
		for k in 7:
			var a := TAU * k / 7.0
			var o := Vector3(cos(a), 0, sin(a)) * 0.0052
			_tube(tm, [t0 + o + Vector3(0, -0.014, 0), t0 + o * 1.3 + Vector3(s * 0.004, -0.055, 0.003), t0 + o * 1.5 + Vector3(s * 0.008, -0.095 - 0.004 * (k % 2), 0.005)], 0.0016, 0.0009, _flat(lav.darkened(0.06 * (k % 3))), 3, 1.0, false)
		_hang(m, tm, [ch], 0.3, "SamurayTassel", 0.7)


static func _put_cords(mb: MB, m, f: Fit, hw: float) -> void:
	var lav := Color(0.62, 0.55, 0.78)
	_chin_cord(mb, m, f, f.by - 0.018, lav, 0.0036)
	for s: float in [-1.0, 1.0]:   # şakakta pirinç halka
		var q := Vector3(m._head_center().x + s * hw * 0.56, f.by - 0.018, m._head_center().z)
		_tube(mb, _ring_pts(q, Vector3(s, 0, 0), 0.0085, 10), 0.0019, 0.0019, _flat(BRASS), 4, 1.0, false)


## Yüzeye yaslanan halka (arma çerçevesi)
static func _lathe_on(mb: MB, p: Vector3, n: Vector3, d: float, c: Color) -> void:
	_disc(mb, p + n * 0.0015, n, d * 0.5, func(_i: int, j: int, _u: float, _v: float) -> Color: return Color(0.05, 0.05, 0.06) if j == 0 else (c if j == 2 else c.darkened(0.2)), 24, 3, 0.001)


static func _samuray_k(m, col: Color) -> void:
	var f := _fit(m, 0.012)
	var h := 0.054
	var steel := Color(0.66, 0.68, 0.72)
	var tilt = func(th: float) -> float: return -0.008 * maxf(0.0, cos(th))
	var mb := MB.new()
	var nu := 72
	var band = func(u: float, v: float) -> Vector3:
		var th := u * TAU - PI
		var bulge := 0.0028 * sin(v * PI)
		return f.ring(th, f.by + float(tilt.call(th)) + h * (0.5 - v), 0.009 + bulge)
	_grid(mb, nu, 6, band, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j == 0 or j == 5:
			return steel.darkened(0.08)
		if j == 1 or j == 4:
			return col.lightened(0.12) if i % 2 == 0 else col.darkened(0.15)   # dikiş sırası
		return col if j == 3 else col.lightened(0.05), true)
	# hachigane: alında dövme çelik levha, yanlarda iki küçük levha
	for pl in [[0.0, 0.62, 0.86], [1.14, 0.3, 0.72], [-1.14, 0.3, 0.72]]:
		var c0: float = pl[0]
		var hs: float = pl[1]
		var hk: float = pl[2]
		var pos = func(u: float, v: float) -> Vector3:
			var a := (u - 0.5) * 2.0
			var th := c0 + a * hs
			var crown := (1.0 - a * a * 0.3)
			return f.ring(th, f.by + float(tilt.call(th)) + h * hk * crown * (0.5 - v), 0.0125 + 0.003 * sin(v * PI))
		_plate(mb, 18 if c0 == 0.0 else 8, 4, pos, func(i: int, j: int, _u: float, _v: float) -> Color:
			if j == 0:
				return steel.lightened(0.22)
			if j == 3:
				return steel.darkened(0.22)
			if c0 == 0.0 and (i == 8 or i == 9) and j > 0:
				return steel.darkened(0.3)   # orta sırt
			return steel, 0.004, steel.darkened(0.32))
		for ux in [0.08, 0.92]:
			for vy in [0.22, 0.78]:
				var q: Vector3 = pos.call(ux, vy)
				_rivet(mb, q, f.d(c0 + (ux - 0.5) * 2.0 * hs), 0.003, steel.darkened(0.4))
	# ensede fiyonk
	var kp := f.ring(PI, f.by + 0.002, 0.018)
	var white := Color(0.94, 0.94, 0.95)
	_lathe(mb, kp, [Vector2(0.001, 0.014), Vector2(0.012, 0.011), Vector2(0.016, 0.0), Vector2(0.012, -0.011), Vector2(0.001, -0.014)], 10, func(i: int, _j: int, _u: float, _v: float) -> Color: return white.darkened(0.08 if i % 3 == 0 else 0.02))
	for s: float in [-1.0, 1.0]:
		var loop = func(u: float, v: float) -> Vector3:
			var w := s * (0.008 + 0.054 * v)
			var y := (u - 0.5) * (0.018 + 0.03 * sin(v * PI)) * s
			return kp + Vector3(w, y + 0.008 * v, -0.008 - 0.016 * sin(v * PI))
		_plate(mb, 3, 7, loop, func(_i: int, j: int, _u: float, _v: float) -> Color: return white.darkened(0.1 if j == 0 else 0.03), 0.003, white.darkened(0.2))
	_put(m, mb)
	m.hair_mask_band(f.by, h + 0.012, 0.008)
	for k in 3:
		m.dangle_strip("Head", kp + Vector3(-0.012 + k * 0.012, -0.012, -0.012), Vector3(0.22 * (k - 1), -1.0, -0.35), 0.135 + k * 0.024, 0.042, white.darkened(0.03 * k), 0.26, Vector3(1, 0, 0), 0.003)


# ================================================================ Land of Iron samuray miğferi
static func _tetsu(m, col: Color, horned: bool) -> void:
	var f := _fit(m, 0.034)
	var ey: float = m.eye_center_model.y
	var hw := Kit._hw(m)
	var plate_c := col
	var shade := col.darkened(0.2)
	var mask_c := Color(0.27, 0.26, 0.3)
	var mb := MB.new()
	# kubbe
	_cap(mb, f, 0.018, 52, 9, 1, func(_t: float) -> float: return 0.006, func(_i: int, j: int, _u: float, _v: float) -> Color:
		return plate_c.lightened(0.09) if j == 3 or j == 4 else (shade if j >= 9 else plate_c))
	# ön alın kaşı: ortada aşağı inen sert kenar
	var brow = func(u: float, v: float) -> Vector3:
		var a := (u - 0.5) * 2.0 * 1.2
		var g := 1.0 - pow(absf(a / 1.2), 2.0)
		return f.ring(a, f.by + 0.012 - (0.018 + 0.02 * g) * v, 0.019 + 0.012 * v)
	_plate(mb, 22, 3, brow, func(_i: int, j: int, _u: float, _v: float) -> Color: return plate_c.lightened(0.1) if j == 0 else (shade.darkened(0.12) if j == 2 else plate_c), 0.005, shade.darkened(0.3))
	# yanlar + ense: tek parça, dışa açılan büyük levha
	var a0 := deg_to_rad(36.0)
	var a1 := TAU - a0
	var skirt = func(u: float, v: float) -> Vector3:
		var th := lerpf(a0, a1, u)
		var fr := minf(u, 1.0 - u)
		var side := pow(sin(clampf((absf(wrapf(th, -PI, PI)) - 0.6) / 1.6, 0.0, 1.0) * PI), 1.0)
		var dr := (0.118 + 0.048 * side) * lerpf(0.5, 1.0, smoothstep(0.0, 0.1, fr))
		var e := pow(v, 1.25)
		return f.ring(th, f.by + 0.002 - dr * v, 0.018 + 0.052 * e + 0.004 * sin(v * PI))
	_plate(mb, 54, 6, skirt, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j == 0:
			return shade
		if j == 5 or i < 2 or i > 51:
			return plate_c.lightened(0.12)
		return plate_c if j % 2 == 1 else plate_c.darkened(0.04), 0.006, shade.darkened(0.25))
	# yandaki üç çentik
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var th: float = s * (1.12 + k * 0.07)
			var q0 := f.dome(th, 0.3, 0.0195)
			var q1 := f.dome(th, 0.5, 0.0195)
			_tube(mb, [q0, q1], 0.0026, 0.0026, _flat(shade.darkened(0.45)), 4, 0.45, false, f.d(th))
	# yüz maskesi
	var zf: float = m.head_ab.position.z + m.head_ab.size.z if m.head_ab.size.z > 0.05 else f.z + 0.1
	var mc := Vector3(f.x, ey - 0.024, zf - 0.066)
	var rx := hw * 0.43 + 0.012
	var ry := 0.092
	var rz := 0.083
	var mask = func(u: float, v: float) -> Vector3:
		var a := (u - 0.5) * 2.0 * 1.45
		var la := lerpf(0.98, -0.98, v)
		var bump := 0.02 * exp(-pow((u - 0.5) / 0.17, 2.0) - pow((v - 0.74) / 0.17, 2.0))
		return mc + Vector3(sin(a) * cos(la) * rx, sin(la) * ry, cos(a) * cos(la) * (rz + bump))
	var nmu := 36
	var nmv := 22
	_grid(mb, nmu, nmv, mask, func(i: int, j: int, u: float, v: float) -> Color:
		var au := absf(u - 0.5) * 2.0
		if v > 0.17 and v < 0.38:
			return Color(0.13, 0.13, 0.16) if au < 0.78 else mask_c.darkened(0.2)   # göz yarığı
		if v >= 0.38 and v < 0.43:
			return mask_c.lightened(0.14)
		if au > 0.42 and au < 0.72 and v > 0.5 and v < 0.76:
			return Color(0.1, 0.1, 0.12) if i % 2 == 0 else mask_c.lightened(0.05)   # yan delikler
		return mask_c.lightened(0.05) if j % 7 == 0 else mask_c)
	var mnorm = func(u: float, v: float) -> Vector3:
		var p: Vector3 = mask.call(u, v)
		return (mask.call(u, v + 0.02) - mask.call(u, v - 0.02)).cross(mask.call(u + 0.02, v) - mask.call(u - 0.02, v)).normalized() if p != Vector3.ZERO else Vector3.BACK
	for s: float in [-1.0, 1.0]:   # kırmızı mercekler
		var u: float = 0.5 + s * 0.15
		var q: Vector3 = mask.call(u, 0.275)
		var n: Vector3 = mnorm.call(u, 0.275)
		_disc(mb, q + n * 0.0012, n, 0.0165, _flat(Color(0.08, 0.08, 0.1)), 14, 1)
		_disc(mb, q + n * 0.002, n, 0.0115, func(_i: int, j: int, _u: float, _v: float) -> Color: return Color(0.98, 0.3, 0.26) if j == 0 else Color(0.78, 0.08, 0.1), 12, 2, 0.002)
	var vq: Vector3 = mask.call(0.5, 0.75)
	var vn: Vector3 = mnorm.call(0.5, 0.75)
	_disc(mb, vq + vn * 0.0015, vn, 0.024, func(_i: int, j: int, _u: float, _v: float) -> Color: return [Color(0.06, 0.06, 0.07), Color(0.1, 0.1, 0.12), mask_c.lightened(0.2)][j], 16, 3)
	if horned:
		for s: float in [-1.0, 1.0]:
			var th: float = s * 1.2
			var b0 := f.dome(th, 0.4, 0.016)
			var d := f.d(th)
			var pts := _cr([b0 - d * 0.008, b0 + d * 0.04 + Vector3(0, 0.0, 0), b0 + d * 0.085 + Vector3(0, 0.04, -0.004), b0 + d * 0.098 + Vector3(0, 0.095, -0.01), b0 + d * 0.066 + Vector3(0, 0.155, -0.012)], 5)
			_tube(mb, pts, 0.033, 0.002, func(_i: int, j: int, _u: float, v: float) -> Color: return plate_c.lightened(0.14 - v * 0.05) if j % 7 != 0 else plate_c.darkened(0.06), 9, 0.68, true, Vector3(0, 0, 1), 2.4)
			var cn := (b0 - Vector3(f.x, f.by, f.z)).normalized()
			_disc(mb, b0 + cn * 0.002, cn, 0.037, func(_i: int, j: int, _u: float, _v: float) -> Color: return shade if j == 0 else shade.darkened(0.2), 14, 2)
	_put(m, mb)


# ================================================================ Daimyō başlığı
static func _kanmuri(m, col: Color) -> void:
	m.hood(col, "hafif")
	m.cloth_band(Color(0.8, 0.82, 0.8), 0.006, 0.05, 0.0, 0.0, 0.004, 0.032)
	var f := _fit(m)
	var ey: float = m.eye_center_model.y
	var hw := Kit._hw(m)
	var W := hw * 2.05
	var Ht := W * 0.66
	var lean := 0.34
	var base := Vector3(f.x, ey + 0.05, f.z - hw * 0.52)
	var uy := Vector3(0, cos(lean), -sin(lean))
	var n := Vector3(0, sin(lean), cos(lean))
	var yb := ey - 0.105
	var board = func(u: float, v: float) -> Vector3:
		var a := (u - 0.5) * 2.0
		return base + Vector3(a * W * v, 0, 0) + uy * ((1.0 - absf(a)) * Ht * v + 0.012 * (1.0 - v))
	var board_up = func(u: float, v: float) -> Vector3: return board.call(u, 1.0 - v)
	var paper := Color(0.94, 0.94, 0.92)
	var line := Color(0.5, 0.51, 0.52)
	var mb := MB.new()
	_plate(mb, 44, 9, board_up, func(i: int, j: int, _u: float, _v: float) -> Color:
		if j == 0:
			return Color(0.2, 0.2, 0.24)
		if j == 1:
			return paper.darkened(0.14)
		return line if i % 4 == 0 and j < 8 else paper, 0.007, Color(0.24, 0.22, 0.2))
	# iki yanda düz kesilmiş altın saman saçak
	var straw := Color(0.8, 0.65, 0.3)
	var nf := 64
	var fr = func(u: float, v: float) -> Vector3:
		var e: Vector3 = board.call(u, 1.0)
		var k := int(floor(u * nf * 0.5))
		var jag := 0.007 * float((k * 7) % 3)
		var y0 := e.y
		var y1 := yb - jag
		var q := e + n * 0.004
		return Vector3(q.x, lerpf(y0, y1, v), q.z + (y0 - lerpf(y0, y1, v)) * 0.14 * -1.0 + 0.012 * v)
	var fc = func(i: int, j: int, _u: float, _v: float) -> Color:
		var c := straw.lightened(0.1) if i % 3 == 0 else (straw.darkened(0.2) if i % 3 == 1 else straw)
		return c.darkened(0.14) if j == 0 else c
	_grid(mb, nf, 3, fr, fc)
	_grid(mb, nf, 1, fr, func(i: int, _j: int, _u: float, _v: float) -> Color: return straw.darkened(0.32 if i % 3 == 0 else 0.2), false, true)
	# arkada ahşap taşıyıcı çubuklar
	var wood := Color(0.27, 0.19, 0.13)
	var bk := base - n * 0.012
	for e: Vector3 in [Vector3(-W * 0.96, 0, 0), Vector3(W * 0.96, 0, 0), uy * Ht * 0.96, Vector3(-W * 0.48, 0, 0) + uy * Ht * 0.46, Vector3(W * 0.48, 0, 0) + uy * Ht * 0.46]:
		_tube(mb, [bk, bk + e], 0.008, 0.005, _flat(wood), 5, 1.0, false)
	_tube(mb, [bk + Vector3(-W * 0.8, 0, 0) + uy * 0.012, bk + Vector3(W * 0.8, 0, 0) + uy * 0.012], 0.007, 0.007, _flat(wood.lightened(0.07)), 5, 1.0, false)
	_put(m, mb)
	# başlığın omuza inen ön uçları
	var top := Vector3(f.x, ey - 0.09, f.z)
	var r0 := hw * 0.56
	var a0 := deg_to_rad(38.0)
	var a1 := TAU - a0
	var len_at = func(a: float) -> float: return lerpf(0.17, 0.115, smoothstep(0.8, 2.4, absf(wrapf(a, -PI, PI))))
	var p_at = func(a: float, v: float) -> Vector3:
		var d := Vector3(sin(a), 0, cos(a))
		return top + d * (r0 + 0.075 * v + sin(a * 11.0) * 0.003 * v) + Vector3(0, -float(len_at.call(a)) * v, 0)
	var cm := MB.new()
	_plate(cm, 40, 4, func(u: float, v: float) -> Vector3: return p_at.call(lerpf(a0, a1, u), v), func(i: int, j: int, _u: float, _v: float) -> Color:
		return col.lightened(0.14) if j == 3 else col.darkened(0.05 * (i % 3)), 0.003, col.darkened(0.25))
	curtain(m, cm, top, a0, a1, 7, p_at, len_at, 0.55, "KanmuriDrape")


# ================================================================ maden miğferi (Tatsunami)
static func _kozan(m, col: Color) -> void:
	var f := _fit(m, 0.018)
	var dark := Color(0.17, 0.16, 0.16)
	var mb := MB.new()
	_cap(mb, f, 0.016, 48, 9, 1, func(_t: float) -> float: return 0.0, func(_i: int, j: int, _u: float, _v: float) -> Color:
		return col.lightened(0.06) if j == 3 or j == 4 else (col.darkened(0.1) if j >= 8 else col))
	# çevre siperi: önde geniş, kenarı kıvrık
	var brim = func(u: float, v: float) -> Vector3:
		var th := u * TAU - PI
		var w := lerpf(0.03, 0.058, pow(maxf(cos(th), 0.0), 1.5))
		return f.ring(th, f.by - 0.003 - 0.012 * v + 0.006 * v * v * v, 0.016) + f.d(th) * w * v
	_plate(mb, 48, 3, brim, func(_i: int, j: int, _u: float, _v: float) -> Color: return col.lightened(0.08) if j == 2 else col.darkened(0.05), 0.005, dark, true)
	# önden arkaya koyu şerit
	var w := 0.024
	var strip = func(u: float, v: float) -> Vector3:
		var a := v * PI
		var th := 0.0 if a < PI * 0.5 else PI
		var t := a / (PI * 0.5) if a < PI * 0.5 else (PI - a) / (PI * 0.5)
		var q := f.dome(th, clampf(t, 0.0, 1.0), 0.0185)
		return q + Vector3((0.5 - u) * w * 2.0, 0, 0) * (-1.0 if th == 0.0 else -1.0)
	_grid(mb, 2, 24, strip, func(i: int, j: int, _u: float, _v: float) -> Color: return dark.lightened(0.08) if i == 0 and j % 4 == 0 else dark, false, true)
	# fener
	var p := f.dome(0.0, 0.2, 0.019)
	var n := (p - Vector3(f.x, f.by - 0.03, f.z)).normalized()
	var fw := (n + Vector3(0, 0.0, 0.4)).normalized()
	_lathe_on(mb, p - fw * 0.001, n, 0.05, dark.lightened(0.14))
	_tube(mb, [p, p + fw * 0.03], 0.019, 0.022, func(i: int, _j: int, _u: float, _v: float) -> Color: return dark.lightened(0.14 if i % 3 == 0 else 0.03), 12, 1.0, false)
	var e := p + fw * 0.03
	_tube(mb, _ring_pts(e, fw, 0.0225, 14), 0.003, 0.003, _flat(Color(0.62, 0.63, 0.65)), 5, 1.0, false)
	_disc(mb, e - fw * 0.001, fw, 0.0205, func(_i: int, j: int, _u: float, _v: float) -> Color: return [Color(1.0, 0.96, 0.75), Color(0.97, 0.85, 0.5), Color(0.7, 0.56, 0.3)][j], 14, 3, 0.004)
	_put(m, mb)
	m.hair_mask_plane(Vector3.UP, Vector3(0, f.by - 0.002, 0))
