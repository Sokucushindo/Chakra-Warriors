extends RefCounted
## Kumaş başlıklar (HeadV2 çağırır). Hepsi kafanın ölçülmüş yüzeyine (yön başına deri yarıçapı) oturan gerçek kabuk:
## kıvrım / dikiş / kat / örgü geometriden gelir, sarkan uçlar ikincil hareketlidir. Araçlar: Kit (head_kit.gd).
const Kit = preload("res://scripts/actors/head_kit.gd")
const AH = preload("res://scripts/actors/anime_hair.gd")

const STYLES := ["kapuson", "bandaj", "bere", "basortusu", "iwabe", "uyku", "kurbaga", "kardan", "gelin", "hachimaki", "basortu", "sarik",
	"tsuribo", "shudo", "okina", "mekakushi"]
const HIDE_HAIR := ["kapuson", "kurbaga", "kardan", "gelin", "shudo", "mekakushi"]
const HOODED := ["kurbaga", "shudo"]

const NY := 48
const NP := 30
static var _fc := {}   # kafa ölçüsü
static var _mc := {}   # hazır mesh / sarkan parça paketi


static func build(m, s, col: Color, L: Dictionary) -> bool:
	if not s in STYLES:
		return false
	if m.body_mesh == null or m.body_mesh.mesh == null or m.band_ring.is_empty():
		return true
	var F := _field(m)
	match s:
		"kapuson": _kapuson(m, F, col, String(L.get("hood", "")))
		"bandaj": _bandaj(m, F, col)
		"bere": _bere(m, F, col)
		"basortusu": _basortusu(m, F, col)
		"iwabe": _iwabe(m, F, col)
		"uyku": _uyku(m, F, col)
		"kurbaga": _kurbaga(m, F, col)
		"kardan": _kardan(m, F)
		"gelin": _gelin(m, F, col)
		"hachimaki": _hachimaki(m, F, col)
		"basortu": _basortu(m, F, col)
		"sarik": _sarik(m, F, col)
		"tsuribo": _tsuribo(m, F, col)
		"shudo": _shudo(m, F, col)
		"okina": _okina(m, F, col)
		"mekakushi": _mekakushi(m, F, col)
	return true


# ================================================================ kafa ölçüsü
static func _field(m) -> Dictionary:
	m._band_ring_full()
	var k := "%s|%s" % [m._sk_key, m.look.get("gender", "m")]
	if m._sk_key != "" and _fc.has(k):
		return _fc[k]
	var sg = m._radial_cached()
	var g := PackedFloat32Array()
	g.resize((NP + 1) * NY)
	for j in NP + 1:
		for i in NY:
			var d = AH._dir(float(i) / NY * 360.0 - 180.0, float(j) / NP * 180.0)
			g[j * NY + i] = AH.real_r_of(d, m.skull_r, sg)
	var o := g.duplicate()   # çıkıntılar içeride kalsın: genişlet, sonra yumuşat (yumru olmasın)
	for j in NP + 1:
		for i in NY:
			var v := 0.0
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					v = maxf(v, o[clampi(j + dj, 0, NP) * NY + posmod(i + di, NY)])
			g[j * NY + i] = v
	for it in 4:
		o = g.duplicate()
		for j in NP + 1:
			for i in NY:
				var v := 0.0
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						v += o[clampi(j + dj, 0, NP) * NY + posmod(i + di, NY)]
				g[j * NY + i] = v / 9.0
	var e: Vector3 = m.eye_center_model
	var F := {"g": g, "c": m.skull_c, "eye": e.y, "by": float(m.band_ring[0]), "brow": e.y + 0.05, "chin": e.y - 0.11,
		"neck": m._bp("Neck").y, "top": m.head_top(), "hw": Kit._hw(m)}
	if m._sk_key != "":
		_fc[k] = F
	return F


static func _r(F: Dictionary, a: float, p: float) -> float:
	var g: PackedFloat32Array = F["g"]
	var fy := fposmod((a + PI) / TAU * NY, float(NY))
	var fp := clampf(p / PI * NP, 0.0, NP - 0.001)
	var y0 := int(fy) % NY
	var p0 := int(fp)
	var ty := fy - floorf(fy)
	var tp := fp - p0
	var y1 := (y0 + 1) % NY
	return lerpf(lerpf(g[p0 * NY + y0], g[p0 * NY + y1], ty), lerpf(g[(p0 + 1) * NY + y0], g[(p0 + 1) * NY + y1], ty), tp)


static func _d(a: float, p: float) -> Vector3:
	return Vector3(sin(a) * sin(p), cos(p), cos(a) * sin(p))


static func _pt(F: Dictionary, a: float, p: float, off := 0.0) -> Vector3:
	return (F["c"] as Vector3) + _d(a, p) * (_r(F, a, p) + off)


## a yönünde deri yüzeyinin y yüksekliğine geldiği tepe açısı
static func _py(F: Dictionary, a: float, y: float) -> float:
	var lo := 0.05
	var hi := 2.95
	var cy: float = (F["c"] as Vector3).y
	for it in 13:
		var p := (lo + hi) * 0.5
		if cy + cos(p) * _r(F, a, p) > y:
			lo = p
		else:
			hi = p
	return (lo + hi) * 0.5


static func _ya(i: int, n: int) -> float:
	return TAU * float(i) / n - PI


## a açısında (a = 0 ön) arkaya yakınlık 0..1
static func _bk(a: float) -> float:
	return maxf(0.0, -cos(a))


static func _bell(x: float, c: float, w: float) -> float:
	var t := (x - c) / w
	return maxf(0.0, 1.0 - t * t)


## Keskin kıvrım çizgisi: 0 düz, 1 kıvrımın dibi
static func _crease(x: float, sharp := 3.0) -> float:
	return pow(1.0 - absf(sin(x)), sharp)


## v > 0 gölge (kıvrım içi), v < 0 ışık (kıvrım sırtı); koyu kumaşta da okunur
static func _sh(c: Color, v: float) -> Color:
	if v >= 0.0:
		return c.lerp(Color(c.r * 0.55, c.g * 0.55, c.b * 0.58), clampf(v, 0.0, 1.0))
	return c.lerp(c.lightened(0.2), clampf(-v, 0.0, 1.0))


# ================================================================ geometri araçları
## Izgara yüzey. C: Color ya da satır dizisi. O: satır başına dış yön (yoksa ref'ten dışa)
static func _grid(mb: MB, P: Array, C, wrap := false, ref := Vector3.ZERO, flip := false, O: Array = [], NN: Array = []) -> void:
	var nj: int = P.size()
	var ni: int = (P[0] as Array).size()
	var b: int = mb.verts.size()
	var sg := -1.0 if flip else 1.0
	var N := []
	for j in nj:
		var row: Array = P[j]
		var up: Array = P[maxi(j - 1, 0)]
		var dn: Array = P[mini(j + 1, nj - 1)]
		for i in ni:
			var im := i - 1
			var ip := i + 1
			if wrap:
				im = ni - 2 if i == 0 else im
				ip = 1 if i == ni - 1 else ip
			else:
				im = maxi(im, 0)
				ip = mini(ip, ni - 1)
			var p: Vector3 = row[i]
			var out: Vector3 = (O[j][i] as Vector3) if not O.is_empty() else (p - ref)
			var n: Vector3 = ((row[ip] as Vector3) - (row[im] as Vector3)).cross((dn[i] as Vector3) - (up[i] as Vector3))
			if not NN.is_empty():
				n = NN[j][i]
			if n.length_squared() < 1e-14:
				n = out
			n = n.normalized()
			if n.dot(out) < 0.0:
				n = -n
			n *= sg
			N.append(n)
			mb.verts.append(p)
			mb.normals.append(n)
			mb.colors.append(C if C is Color else (C[j][i] as Color))
			mb.uvs.append(Vector2.ZERO)
	for j in nj - 1:
		for i in ni - 1:
			var a := b + j * ni + i
			var q := a + 1
			var c := a + ni + 1
			var d := a + ni
			var pa: Vector3 = mb.verts[a]
			var ok: bool = ((mb.verts[c] - pa).cross(mb.verts[q] - pa)).dot(N[j * ni + i] + N[(j + 1) * ni + i + 1]) > 0.0
			if not ok and ((mb.verts[c] - pa).length_squared() < 1e-14):
				ok = ((mb.verts[d] - pa).cross(mb.verts[c] - pa)).dot(N[j * ni + i]) > 0.0
			if ok:
				mb.idx.append_array([a, q, c, a, c, d])
			else:
				mb.idx.append_array([a, c, q, a, d, c])


## Yüzey üstünde şerit (sargı, kenar, kayış): ortası kabarık, kenarı yüzeye iner
static func _rib(mb: MB, pts: Array, nrs: Array, w, col, thick := 0.003, nx := 4, closed := false, colf := Callable()) -> void:
	var P := []
	var C := []
	var O := []
	var n := pts.size()
	for k in n:
		var a: Vector3 = pts[(k - 1 + n) % n] if closed else pts[maxi(k - 1, 0)]
		var b: Vector3 = pts[(k + 1) % n] if closed else pts[mini(k + 1, n - 1)]
		var nr: Vector3 = nrs[k]
		var s := (b - a).cross(nr).normalized()
		var ww: float = float(w[k]) if w is Array else float(w)
		var rp := []
		var rc := []
		var ro := []
		for q in nx + 1:
			var x := float(q) / nx * 2.0 - 1.0
			var h := thick * (1.0 - x * x * x * x) - thick * 0.45 * (1.0 if q == 0 or q == nx else 0.0)
			rp.append((pts[k] as Vector3) + s * x * ww * 0.5 + nr * h)
			rc.append(colf.call(k, q, x) if colf.is_valid() else (col if col is Color else col[k]))
			ro.append(nr)
		P.append(rp)
		C.append(rc)
		O.append(ro)
	if closed:
		P.append(P[0])
		C.append(C[0])
		O.append(O[0])
	_grid(mb, P, C, false, Vector3.ZERO, false, O)


## Yol boyunca dikiş sırası (yüzeyden hafif kalkık küçük ilmekler)
static func _stitch(mb: MB, pts: Array, nrs: Array, col: Color, sl := 0.0065, gap := 0.0055, w := 0.0017) -> void:
	var run := 0.0
	var on := true
	var start := 0.0
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var L := a.distance_to(b)
		if L < 1e-6:
			continue
		var t := (b - a) / L
		var u := 0.0
		while u < L:
			var need := (sl if on else gap) - (run - start)
			if u + need > L:
				run += L - u
				break
			u += need
			run += need
			start = run
			if not on:
				var n: Vector3 = nrs[k]
				var s := t.cross(n).normalized() * w * 0.5
				var e := a + t * u + n * 0.0014
				var f := e + t * minf(sl, L)
				var o := mb.verts.size()
				for v in [e - s, f - s, f + s, e + s]:
					mb.verts.append(v)
					mb.normals.append(n)
					mb.colors.append(col)
					mb.uvs.append(Vector2.ZERO)
				var ok := ((f - s) - (e - s)).cross((f + s) - (e - s)).dot(n) < 0.0
				mb.idx.append_array([o, o + 1, o + 2, o, o + 2, o + 3] if ok else [o, o + 2, o + 1, o, o + 3, o + 2])
			on = not on


## Kafa çevresinde, y(a) yüksekliğinde yol
static func _ring(F: Dictionary, yf: Callable, off: float, a0 := -PI, a1 := PI, n := 72) -> Array:
	var pts := []
	var nrs := []
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / n)
		var p := _py(F, a, float(yf.call(a)))
		pts.append(_pt(F, a, p, off))
		nrs.append(_d(a, p))
	return [pts, nrs]


## Boru (kordon, sap, havuç): yol + yarıçaplar
static func _tube(mb: MB, pts: Array, rad, col, seg := 7) -> void:
	var P := []
	var O := []
	var C := []
	var up := Vector3(0.31, 0.87, 0.38).normalized()
	for k in pts.size():
		var t: Vector3 = ((pts[mini(k + 1, pts.size() - 1)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var x := t.cross(up).normalized()
		var y := x.cross(t).normalized()
		var rr: float = float(rad[k]) if rad is Array else float(rad)
		var rp := []
		var ro := []
		var rc := []
		for i in seg + 1:
			var e := TAU * float(i % seg) / seg
			var d := x * cos(e) + y * sin(e)
			rp.append((pts[k] as Vector3) + d * rr)
			ro.append(d)
			rc.append(col if col is Color else col.call(k, i))
		P.append(rp)
		O.append(ro)
		C.append(rc)
	_grid(mb, P, C, true, Vector3.ZERO, false, O)


## Bez düğüm: ortası sarılı, kıvrımlı yastık
static func _knot(mb: MB, p: Vector3, ax: Vector3, up: Vector3, sz: float, col: Color) -> void:
	var x := ax.normalized()
	var z := x.cross(up).normalized()
	var y := z.cross(x).normalized()
	var P := []
	var C := []
	var O := []
	for j in 15:
		var t := float(j) / 14.0 * 2.0 - 1.0
		var r := sz * sqrt(maxf(0.0, 1.0 - t * t * t * t)) * (0.62 + 0.3 * absf(t))
		var rp := []
		var rc := []
		var ro := []
		for i in 15:
			var e := TAU * float(i % 14) / 14.0
			var d := y * cos(e) + z * sin(e) * 0.8
			var v := _crease(e * 1.5 + t * 2.6)
			rp.append(p + x * t * sz * 1.3 + d * r * (1.0 - 0.14 * v))
			rc.append(_sh(col, 0.2 + 0.6 * v - 0.2 * absf(t)))
			ro.append(d + x * t)
		P.append(rp)
		C.append(rc)
		O.append(ro)
	_grid(mb, P, C, true, Vector3.ZERO, false, O)
	var pp := []
	var nn := []
	for k in 20:
		var e := TAU * k / 20.0
		var d := y * cos(e) + z * sin(e) * 0.8
		pp.append(p + d * sz * 0.72)
		nn.append(d)
	_rib(mb, pp, nn, sz * 0.62, col, sz * 0.14, 4, true, func(_k, _q, ex): return _sh(col, 0.1 + 0.5 * absf(ex) * absf(ex)))


## Kafa yüzeyine oturan yama (göz, yanak, yamalık). ra / rp: yatay / dikey yarıçap (radyan)
static func _patch(mb: MB, F: Dictionary, a0: float, p0: float, ra: float, rp: float, off: float, h: float, col: Color, rim := Color(0, 0, 0, 0)) -> void:
	var P := []
	var C := []
	var O := []
	var nj := 6
	for j in nj + 1:
		var e := float(j) / nj
		var rw := []
		var rc := []
		var ro := []
		for i in 25:
			var t := TAU * float(i % 24) / 24.0
			var a := a0 + e * cos(t) * ra / maxf(sin(p0), 0.3)
			var p := p0 + e * sin(t) * rp
			rw.append(_pt(F, a, p, off + h * sqrt(maxf(0.0, 1.0 - e * e)) - (0.002 if j == nj else 0.0)))
			rc.append(rim if rim.a > 0.0 and j >= nj - 1 else col)
			ro.append(_d(a, p))
		P.append(rw)
		C.append(rc)
		O.append(ro)
	_grid(mb, P, C, true, Vector3.ZERO, false, O)


## Kafaya oturan kabuk: edge(a) alt kenar y; off(a, s, p) dış pay; colf(a, s, p) renk. s: 0 tepe, 1 kenar
static func _cap(mb: MB, F: Dictionary, na: int, nr: int, edge: Callable, off: Callable, colf: Callable) -> Dictionary:
	var pe := []
	for i in na + 1:
		pe.append(_py(F, _ya(i % na, na), float(edge.call(_ya(i % na, na)))))
	var P := []
	var C := []
	for j in nr + 1:
		var s := float(j) / nr
		var rp := []
		var rc := []
		for i in na + 1:
			var a := _ya(i % na, na)
			var p := maxf(0.012, s * float(pe[i]))
			rp.append(_pt(F, a, p, float(off.call(a, s, p))))
			rc.append(colf.call(a, s, p))
		P.append(rp)
		C.append(rc)
	var rl := []   # kenar içe kıvrılır: alttan bakınca boşluk görünmez
	var cl := []
	for i in na + 1:
		var a := _ya(i % na, na)
		rl.append(_pt(F, a, float(pe[i]) + 0.012, -0.004))
		cl.append(Color(0.05, 0.05, 0.06))
	P.append(rl)
	C.append(cl)
	_grid(mb, P, C, true, F["c"])
	return {"pe": pe}


## Dönel gövde (r, y); xf ile yerleşir
static func _lathe(mb: MB, prof: Array, n: int, xf: Transform3D, colf: Callable, off := Callable()) -> void:
	var P := []
	var C := []
	var O := []
	var nj := prof.size()
	for j in nj:
		var q: Vector2 = prof[j]
		var dv: Vector2 = (prof[mini(j + 1, nj - 1)] as Vector2) - (prof[maxi(j - 1, 0)] as Vector2)
		var nn := Vector2(-dv.y, dv.x).normalized()
		var rp := []
		var rc := []
		var ro := []
		for i in n + 1:
			var a := TAU * float(i % n) / n
			var f: Vector2 = off.call(a, j) if off.is_valid() else Vector2.ONE
			var d := Vector3(sin(a), 0, cos(a))
			rp.append(xf * (d * q.x * f.x + Vector3.UP * (q.y + f.y - 1.0)))
			rc.append(colf.call(a, j))
			ro.append(xf.basis * (d * nn.x + Vector3.UP * nn.y))
		P.append(rp)
		C.append(rc)
		O.append(ro)
	_grid(mb, P, C, true, Vector3.ZERO, false, O)


## Kafa çevresinin (bant hizası) yatay yarıçapına göre dönel gövde: rows = [k, dr, y]
static func _crown(mb: MB, F: Dictionary, na: int, rows: Array, disp: Callable, colf: Callable) -> void:
	var c: Vector3 = F["c"]
	var ring := []
	for i in na + 1:
		var a := _ya(i % na, na)
		var q := _pt(F, a, _py(F, a, F["by"]), 0.0)
		ring.append(Vector2(q.x - c.x, q.z - c.z).length())
	var P := []
	var C := []
	var O := []
	var nj := rows.size()
	for j in nj:
		var e: Array = rows[j]
		var rp := []
		var rc := []
		for i in na + 1:
			var a := _ya(i % na, na)
			var f: Vector2 = disp.call(a, j)
			var r: float = float(ring[i]) * float(e[0]) + float(e[1]) + f.x
			rp.append(Vector3(c.x + sin(a) * r, float(e[2]) + f.y, c.z + cos(a) * r))
			rc.append(colf.call(a, j))
		P.append(rp)
		C.append(rc)
	for j in nj:
		var ro := []
		var e0: Array = rows[maxi(j - 1, 0)]
		var e1: Array = rows[mini(j + 1, nj - 1)]
		var dv := Vector2(float(e1[1]) - float(e0[1]) + 0.1 * (float(e1[0]) - float(e0[0])), float(e1[2]) - float(e0[2]))
		var nn := Vector2(-dv.y, dv.x).normalized()
		if nj > 1 and nn.length_squared() < 0.5:
			nn = Vector2(0, 1)
		for i in na + 1:
			var a := _ya(i % na, na)
			ro.append(Vector3(sin(a) * nn.x, nn.y, cos(a) * nn.x))
		O.append(ro)
	_grid(mb, P, C, true, Vector3.ZERO, false, O)


## Hazır mesh (aynı başlık + kafa için bir kez kurulur: kalabalıkta takılma olmasın)
static func _put(m, key: String, make: Callable) -> MeshInstance3D:
	var k := "%s|%s|%s" % [key, m._sk_key, m.look.get("gender", "m")]
	if m._sk_key == "" or not _mc.has(k):
		if _mc.size() > 160:
			_mc.clear()
		var mb := MB.new()
		make.call(mb)
		_mc[k] = mb.build(Props.toon())
	return m._mesh_on("Head", _mc[k], Transform3D.IDENTITY)


static func _hang(m, pack: Dictionary) -> void:
	var d = Dangle.make(pack, Props.toon())
	if d == null:
		return
	m._attach("Head", Transform3D.IDENTITY).get_child(0).add_child(d)
	m._dangles.append(d)


## Sarkan kumaş ucu: iki yüzlü, ortası kıvrımlı, kenarı dikişli; o: taper, fray (saçaklı uç), tri (üçgen), stiff, wave, seam
static func _tail(m, root: Vector3, dir: Vector3, side: Vector3, L: float, w: float, col: Color, o := {}) -> void:
	if m.skel == null or m.skel.find_bone("Head") < 0:
		return
	var key := "t|%s|%s|%s|%.3f|%.3f|%s|%s|%s" % [root, dir, side, L, w, col.to_html(), o, m.look.get("gender", "m")]
	if not _mc.has(key):
		if _mc.size() > 160:
			_mc.clear()
		var d := dir.normalized()
		var sd := (side - d * side.dot(d)).normalized()
		var nr := d.cross(sd).normalized()
		var NR := 14
		var NX := 6
		var taper: float = o.get("taper", 0.25)
		var fray: bool = o.get("fray", false)
		var tri: bool = o.get("tri", false)
		var wave: float = o.get("wave", 0.007)
		var seam: bool = o.get("seam", true)
		var ch := PackedVector3Array()
		var F1 := []
		var B1 := []
		var C1 := []
		var O1 := []
		var O2 := []
		for j in NR + 1:
			var t := float(j) / NR
			var c := root + d * L * t + nr * sin(t * 4.2 + w * 40.0) * wave * smoothstep(0.0, 0.4, t)
			if j % 2 == 0:
				ch.append(c)
			var ww := w * lerpf(0.5, 1.0, smoothstep(0.0, 0.22, t)) * (1.0 - taper * t)
			if tri:
				ww = w * (1.0 - t * 0.97)
			var rf := []
			var rb := []
			var rc := []
			var r1 := []
			var r2 := []
			for q in NX + 1:
				var x := float(q) / NX * 2.0 - 1.0
				var fold := sin(x * 2.4 + t * 5.0) * 0.0045 * smoothstep(0.05, 0.5, t) - absf(x) * 0.002
				var dn := 0.0
				if fray and j >= NR - 1:
					dn = (0.022 if q % 2 == 0 else -0.004) * (float(j) - NR + 2.0) * 0.5
				var e := c + sd * x * ww * 0.5 + nr * fold + d * dn
				rf.append(e + nr * 0.0016)
				rb.append(e - nr * 0.0016)
				var v := 0.45 * _crease(x * 2.4 + t * 5.0 + 0.8, 2.0)
				if seam and absf(x) > 0.72:
					v += 0.28
				rc.append(_sh(col, v))
				r1.append(nr)
				r2.append(-nr)
			F1.append(rf)
			B1.append(rb)
			C1.append(rc)
			O1.append(r1)
			O2.append(r2)
		var mb := MB.new()
		_grid(mb, F1, C1, false, Vector3.ZERO, false, O1)
		_grid(mb, B1, C1, false, Vector3.ZERO, false, O2)
		var stf: float = o.get("stiff", 0.22)
		_mc[key] = Dangle.build(mb.build(Props.toon()), [{"pts": ch, "stiff": stf + 0.06, "stiff_tip": stf * 0.4, "damp": 0.82, "grav": 0.7, "drag": 1.2, "air": 0.3, "follow": 0.5, "col_r": 0.012, "col_from": 1}],
			func(_i, v, _si): return [[0, Dangle.project(ch, v)[0], 1.0]])
	_hang(m, _mc[key])


## Tek parça sarkan örtü: üst kenar tops[], her sütunda dış yön outs[], boy lens[]; colf(c, t) renk
static func _curtain(m, key: String, tops: Array, outs: Array, lens: Array, flare: float, colf: Callable, stiff := 0.32, famp := 0.012, heads: Array = []) -> void:
	if m.skel == null or m.skel.find_bone("Head") < 0:
		return
	var k := "c|%s|%s|%s" % [key, m._sk_key, m.look.get("gender", "m")]
	if not _mc.has(k):
		var NC: int = tops.size() - 1
		var NR := 16
		var P := []
		var Q := []
		var C := []
		var O1 := []
		var O2 := []
		var NF: int = (heads[0] as Array).size() if not heads.is_empty() else 0
		for j in NF:   # başın üstünde kalan sabit kısım
			var rp := []
			var rq := []
			var rc := []
			var r1 := []
			var r2 := []
			for c in NC + 1:
				var e: Array = heads[c][j]
				var q: Vector3 = e[0]
				var o: Vector3 = e[1]
				rp.append(q + o * 0.0014)
				rq.append(q - o * 0.0014)
				rc.append(colf.call(c, 0.0))
				r1.append(o)
				r2.append(-o)
			P.append(rp)
			Q.append(rq)
			C.append(rc)
			O1.append(r1)
			O2.append(r2)
		for j in NR + 1:
			var t := float(j) / NR
			var rp := []
			var rq := []
			var rc := []
			var r1 := []
			var r2 := []
			for c in NC + 1:
				var o: Vector3 = outs[c]
				var ph := float(c) * 1.05
				var f := sin(ph + sin(ph * 0.37) * 1.4)
				var hem := 0.008 * sin(float(c) * 1.57) * smoothstep(0.9, 1.0, t)
				var e: Vector3 = (tops[c] as Vector3) + Vector3.DOWN * (float(lens[c]) * t + hem) + o * (flare * smoothstep(0.0, 0.5, t) + f * famp * smoothstep(0.03, 0.6, t))
				rp.append(e + o * 0.0014)
				rq.append(e - o * 0.0014)
				rc.append(_sh(colf.call(c, t), 0.55 * pow(0.5 - 0.5 * f, 2.0) * smoothstep(0.03, 0.5, t) - 0.08 * maxf(f, 0.0)))
				r1.append(o)
				r2.append(-o)
			P.append(rp)
			Q.append(rq)
			C.append(rc)
			O1.append(r1)
			O2.append(r2)
		var mb := MB.new()
		_grid(mb, P, C, false, Vector3.ZERO, false, O1)
		_grid(mb, Q, C, false, Vector3.ZERO, false, O2)
		var defs := []
		var cols := []
		var c := 0
		while true:
			cols.append(mini(c, NC))
			if c >= NC:
				break
			c += maxi(3, NC / 10)
		for cc in cols:
			var pts := PackedVector3Array()
			for r in 7:
				var i: int = int(float(r) / 6.0 * NR)
				pts.append((P[NF + i][cc] as Vector3))
			defs.append({"pts": pts, "stiff": stiff + 0.08, "stiff_tip": stiff * 0.45, "damp": 0.84, "grav": 0.6, "drag": 1.1, "air": 0.2, "follow": 0.6, "col_r": 0.02, "col_from": 1})
		var nv := (NC + 1) * (NR + 1 + NF)
		var nx := NC + 1
		var sect := cols.size()
		var assign = func(i, _v, _si):
			var u: int = i % nv
			var cu: int = u % nx
			var r: int = maxi(u / nx - NF, 0)
			var s := float(r) / NR * 6.0
			var e := float(cu) / maxf(1.0, float(cols[sect - 1])) * (sect - 1)
			var a0 := clampi(int(floor(e)), 0, sect - 1)
			var a1 := mini(a0 + 1, sect - 1)
			var f := clampf(e - a0, 0.0, 1.0)
			if a0 == a1:
				return [[a0, s, 1.0]]
			return [[a0, s, 1.0 - f], [a1, s, f]]
		if _mc.size() > 160:
			_mc.clear()
		_mc[k] = Dangle.build(mb.build(Props.toon()), defs, assign)
	_hang(m, _mc[k])


## Saç: başlığın üstünde kalan kısım kesilir (önde yf, arkada yb hizası)
static func _mask(m, F: Dictionary, yf: float, yb: float) -> void:
	var fp := _pt(F, 0.0, _py(F, 0.0, yf), 0.01)
	var bp := _pt(F, PI, _py(F, PI, yb), 0.01)
	var v := bp - fp
	var n := Vector3(0, -v.z, v.y).normalized()
	if n.y < 0.0:
		n = -n
	m.hair_mask_plane(n, fp)


# ================================================================ kapüşon iskeleti
## Yüz açıklığına göre dizilmiş ızgara: sütunlar açıklık kenarından başlar, kenar pürüzsüz bir eğri olur
## o: pad, back, brim, W, up, dn, lip, fold, peak, cord
static func _hood(mb: MB, F: Dictionary, cc: Color, o: Dictionary) -> Dictionary:
	var pad: float = o.get("pad", 0.03)
	var back: float = o.get("back", 0.02)
	var brim: float = o.get("brim", 0.0)
	var W: float = o.get("W", 1.15)
	var fold: float = o.get("fold", 1.0)
	var peak: float = o.get("peak", 0.0)
	var lip: float = o.get("lip", 0.018)
	var ylo: float = float(F["neck"]) + 0.02
	var pb := _py(F, 0.0, float(F["brow"]) + float(o.get("up", 0.02)))
	var pc := _py(F, 0.0, float(F["chin"]) - float(o.get("dn", 0.015)))
	var pm := (pb + pc) * 0.5
	var ph := (pc - pb) * 0.5
	var plow := []
	for i in 73:
		plow.append(_py(F, _ya(i % 72, 72), ylo))
	var pl = func(a: float) -> float:
		var f := fposmod((a + PI) / TAU * 72.0, 72.0)
		var i0 := int(f) % 72
		return lerpf(float(plow[i0]), float(plow[i0 + 1]), f - floorf(f))
	var pf: float = pl.call(0.0)
	var opn = func(s: float) -> float:
		var q := (s * pf - pm) / ph
		return W * pow(1.0 - q * q, 0.8) if absf(q) < 1.0 else 0.0
	var off = func(a: float, s: float, u: float) -> float:
		var b := _bk(a)
		var e := minf(u, 1.0 - u)
		var r := pad + back * b * _bell(s, 0.45, 0.5) + peak * _bell(s, 0.0, 0.2) * (1.0 - b)
		r += brim * exp(-e * 16.0) * smoothstep(pm / pf + 0.08, pm / pf - 0.2, s) * smoothstep((pm - ph) / pf - 0.1, (pm - ph) / pf + 0.04, s)
		r += 0.01 * smoothstep(0.7, 1.0, s)   # boyunda bolluk
		var gather := smoothstep(0.62, 1.0, s)
		r -= fold * 0.005 * gather * _crease(a * 5.5 + 1.2 * sin(a * 3.0) + s * 2.0, 2.0)
		r -= fold * 0.0035 * _bell(s, 0.64, 0.24) * _crease(a * 3.0 + s * 7.0, 4.0)
		r -= fold * 0.0035 * _bell(s, 0.6, 0.24) * _crease(a * 3.0 - s * 6.0 + 1.0, 4.0)
		r -= 0.004 * smoothstep(0.03, 0.0, absf(wrapf(a - PI, -PI, PI)))   # orta dikiş oluğu
		return r
	var pos = func(a: float, s: float, u: float, ex := 0.0) -> Vector3:
		return _pt(F, a, maxf(0.012, s * float(pl.call(a))), float(off.call(a, s, u)) + ex)
	var NC: int = o.get("nc", 128)
	var NR: int = o.get("nr", 52)
	var P := []
	var C := []
	var I := []
	var NN := []
	for j in NR + 1:
		var s := float(j) / NR
		var w: float = opn.call(s)
		var rp := []
		var rc := []
		var ri := []
		var rn := []
		for i in NC + 1:
			var u := float(i) / NC
			var a := wrapf(w + u * (TAU - 2.0 * w), -PI, PI)
			var q: Vector3 = pos.call(a, s, u)
			rp.append(q)
			# normal yüzeyin kendisinden: açıklık çevresinde eğilen ızgara gölgede leke yapmasın
			var qa: Vector3 = pos.call(a + 0.02, s, u)
			var qs: Vector3 = pos.call(a, minf(s + 0.012, 1.0) if s < 0.99 else s - 0.012, u)
			rn.append((qa - q).cross(qs - q))
			var v := 0.5 * fold * smoothstep(0.62, 1.0, s) * _crease(a * 5.5 + 1.2 * sin(a * 3.0) + s * 2.0, 2.0)
			v += 0.34 * fold * _bell(s, 0.64, 0.24) * _crease(a * 3.0 + s * 7.0, 4.0) + 0.34 * fold * _bell(s, 0.6, 0.24) * _crease(a * 3.0 - s * 6.0 + 1.0, 4.0)
			v += 0.14 * smoothstep(0.75, 1.0, s) - 0.08 * smoothstep(0.5, 0.1, s)
			v += 0.5 * smoothstep(0.026, 0.0, absf(wrapf(a - PI, -PI, PI)))
			rc.append(_sh(cc, v))
			var e := minf(u, 1.0 - u)
			if e < 0.17:
				ri.append(_pt(F, a, maxf(0.012, s * float(pl.call(a))), float(off.call(a, s, u)) - lerpf(0.003, 0.016, smoothstep(0.0, 0.05, e))))
			else:
				ri.append(q)
		P.append(rp)
		C.append(rc)
		I.append(ri)
		NN.append(rn)
	_grid(mb, P, C, false, F["c"], false, [], NN)
	# açıklıktan görünen iç yüz
	var nin := int(NC * 0.17)
	for side in 2:
		var iP := []
		for j in NR + 1:
			var r: Array = I[j]
			iP.append(r.slice(0, nin + 1) if side == 0 else r.slice(NC - nin, NC + 1))
		_grid(mb, iP, cc.darkened(0.62), false, F["c"], true)
	# yüz kenarı: yuvarlak kıvrık kenar + dikiş
	var L0 := []
	var R0 := []
	var Ls := []
	var Rs := []
	for j in NR + 1:
		var s := float(j) / NR
		var w: float = opn.call(s)
		if w <= 0.0:
			continue
		L0.append(pos.call(wrapf(w, -PI, PI), s, 0.0))
		R0.append(pos.call(wrapf(-w, -PI, PI), s, 1.0))
		Ls.append(pos.call(wrapf(w + 0.17, -PI, PI), s, 0.03, 0.0015))
		Rs.append(pos.call(wrapf(-w - 0.17, -PI, PI), s, 0.97, 0.0015))
	var hem := L0.duplicate()
	var R1 := R0.duplicate()
	R1.reverse()
	hem.append_array(R1)
	var st := Ls.duplicate()
	var R2 := Rs.duplicate()
	R2.reverse()
	st.append_array(R2)
	var cen := Vector3((F["c"] as Vector3).x, (F["eye"] as float) - 0.03, (F["c"] as Vector3).z)
	var hn := []
	for q in hem:
		hn.append(((q as Vector3) - cen).normalized())
	var sn := []
	for q in st:
		sn.append(((q as Vector3) - cen).normalized())
	if lip > 0.0:
		var lc: Color = o.get("lip_col", cc)
		_rib(mb, hem, hn, lip, lc, lip * 0.42, 5, true, func(_k, _q, x): return _sh(lc, 0.4 * x * x - 0.28 * (1.0 - absf(x))))
		_stitch(mb, st, sn, _stitch_col(cc))
	# tepe ve ense boyunca çift dikiş
	for sd in [-0.045, 0.045]:
		var pp := []
		var nn := []
		for j in 40:
			var s := lerpf(0.02, 0.9, float(j) / 39.0)
			var a: float = wrapf(PI + float(sd), -PI, PI)
			var q: Vector3 = pos.call(a, s, 0.5, 0.0005)
			pp.append(q)
			nn.append(_d(a, s * float(pl.call(a))))
		_stitch(mb, pp, nn, _stitch_col(cc))
	return {"hem": hem, "hn": hn, "n": L0.size(), "pos": pos, "pf": pf, "pm": pm, "ph": ph}


static func _stitch_col(c: Color) -> Color:
	return c.lightened(0.28) if c.get_luminance() < 0.42 else c.darkened(0.3)


# ================================================================ kapüşon
static func _kapuson(m, F: Dictionary, cc: Color, deep: String) -> void:
	var o := {"pad": 0.03, "back": 0.02, "W": 1.15, "up": 0.02, "lip": 0.019}
	if deep == "derin":
		o = {"pad": 0.036, "back": 0.03, "brim": 0.05, "W": 1.0, "up": 0.04, "dn": 0.03, "lip": 0.022, "peak": 0.012, "fold": 1.2}
	elif deep == "hafif":
		o = {"pad": 0.022, "back": 0.008, "W": 1.2, "up": 0.012, "lip": 0.012, "fold": 0.65}
	var key := "kapuson|%s|%s" % [deep, cc.to_html()]
	var ck := "kord|%s|%s|%s" % [key, m._sk_key, m.look.get("gender", "m")]
	_put(m, key, func(mb):
		var h := _hood(mb, F, cc, o)
		if deep != "hafif":
			var hem: Array = h["hem"]
			var n: int = h["n"]
			var roots := []
			for side in 2:
				var i: int = int(n * 0.74) if side == 0 else hem.size() - 1 - int(n * 0.74)
				var q: Vector3 = hem[i]
				roots.append(q)
				mb.add("torus", q + Vector3(0, 0, 0.002), Vector3(0.012, 0.004, 0.012), Color(0.72, 0.68, 0.55), Vector3(90, 0, 0), 10)
			_mc[ck] = roots)
	if deep != "hafif" and _mc.has(ck):
		var cord := cc.lightened(0.3) if cc.get_luminance() < 0.4 else cc.darkened(0.35)
		var roots: Array = _mc[ck]
		for side in 2:
			var q: Vector3 = roots[side]
			_tail(m, q + Vector3(0, -0.002, 0.004), Vector3(0.04 * (1.0 if side == 0 else -1.0), -1.0, 0.1), Vector3(1, 0, 0), 0.15 + 0.012 * side, 0.0075, cord, {"taper": 0.0, "wave": 0.003, "seam": false, "stiff": 0.3})


# ================================================================ bandaj
## Alnı saran gazlı bez: üst üste binen turlar, çapraz bir kat, sıkıştırılmış uç, ensede saçaklı kısa uç
static func _bandaj(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	_put(m, "bandaj|" + cc.to_html(), func(mb):
		var gz = func(base: Color, seed_: int):
			return func(k, q, x):
				var c := _sh(base, 0.12 if (int(k) + int(q) + seed_) % 2 == 0 else -0.08)
				return _sh(c, 0.42 * x * x * x * x)
		var turns := [[-0.012, 0.004, 0.024, 0.012], [0.008, -0.006, 0.026, 0.0155], [0.024, 0.011, 0.02, 0.019]]
		for i in turns.size():
			var t: Array = turns[i]
			var r := _ring(F, func(a): return by + float(t[0]) + float(t[1]) * sin(a + 0.7 * float(i)) + 0.0018 * sin(a * 7.0 + float(i)), float(t[3]), -PI, PI, 96)
			r[0].pop_back()
			r[1].pop_back()
			_rib(mb, r[0], r[1], float(t[2]), cc, 0.0034, 6, true, gz.call(cc.darkened(0.05 * float(i)), i))
		# yandan çapraz geçen kat ve sıkıştırılmış uç
		var pp := []
		var nn := []
		for k in 14:
			var e := float(k) / 13.0
			var a := lerpf(0.65, 1.55, e)
			var p := _py(F, a, by + 0.032 - 0.05 * e)
			pp.append(_pt(F, a, p, 0.023))
			nn.append(_d(a, p))
		_rib(mb, pp, nn, 0.018, cc, 0.003, 4, false, gz.call(cc.darkened(0.1), 3))
		_stitch(mb, pp, nn, cc.darkened(0.32), 0.004, 0.004, 0.0012)
	)
	m.hair_mask_band(by + 0.006, 0.07, 0.008)
	var kp := _pt(F, PI, _py(F, PI, by), 0.024)
	_tail(m, kp + Vector3(0.012, 0, -0.002), Vector3(0.25, -1.0, -0.4), Vector3(1, 0, 0), 0.1, 0.024, cc.darkened(0.03), {"fray": true, "taper": 0.1})
	_tail(m, kp + Vector3(-0.008, 0.004, -0.002), Vector3(-0.3, -1.0, -0.35), Vector3(1, 0, 0), 0.07, 0.02, cc.darkened(0.08), {"fray": true, "taper": 0.1})


# ================================================================ örgü bere
static func _knit_cap(mb: MB, F: Dictionary, cc: Color, cuff: Color, ef: float, eb: float, ribs: int, puff: float, cs := 0.79) -> void:
	var sc := cs
	var edge = func(a: float) -> float:
		return ef - (ef - eb) * pow(_bk(a), 1.5) - 0.012 * smoothstep(0.5, 0.95, absf(sin(a)))
	var off = func(a: float, s: float, _p: float) -> float:
		var rb := cos(a * ribs)
		var top := smoothstep(0.1, 0.34, s)
		var r := 0.013 + puff * _bell(s, 0.22, 0.42) + 0.006 * smoothstep(0.55, 0.3, s)
		var dec := smoothstep(0.42, 0.05, s) * pow(absf(cos(a * 3.0)), 8.0)   # tepede daralma dikişleri
		r -= 0.003 * dec
		if s >= sc:
			var e := (s - sc) / (1.0 - sc)
			r += 0.004 + 0.0075 * sin(e * PI) + 0.0022 * rb
		else:
			r += 0.0011 * rb * top - 0.003 * smoothstep(sc - 0.03, sc, s)
		return r
	var colf = func(a: float, s: float, _p: float) -> Color:
		var rb := cos(a * ribs) * 0.5 + 0.5
		if s >= sc:
			var e := (s - sc) / (1.0 - sc)
			return _sh(cuff, 0.42 * (1.0 - rb) + 0.28 * pow(absf(e * 2.0 - 1.0), 4.0) - 0.1)
		var row := 0.09 if int(s * 54.0) % 2 == 0 else -0.05
		var v := row + 0.28 * (1.0 - rb) * smoothstep(0.08, 0.3, s)
		v += 0.45 * smoothstep(sc - 0.05, sc, s) + 0.34 * smoothstep(0.42, 0.05, s) * pow(absf(cos(a * 3.0)), 8.0)
		return _sh(cc, v)
	_cap(mb, F, ribs * 4, 40, edge, off, colf)


static func _bere(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	_put(m, "bere|" + cc.to_html(), func(mb): _knit_cap(mb, F, cc, cc, by - 0.008, by - 0.075, 44, 0.02))
	_mask(m, F, by - 0.03, by - 0.075)


# ================================================================ uyku kepi
static func _uyku(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var wh := Color(0.93, 0.93, 0.92)
	_put(m, "uyku|" + cc.to_html(), func(mb):
		var edge = func(a: float) -> float: return by - 0.012 - 0.06 * pow(_bk(a), 1.5)
		var off = func(a: float, s: float, _p: float) -> float:
			var r := 0.016 + 0.024 * _bell(s, 0.3, 0.4) - 0.003 * _crease(a * 4.0 + s * 5.0, 5.0) * _bell(s, 0.5, 0.3)
			if s > 0.74:
				var e := (s - 0.74) / 0.26
				r += 0.012 * pow(sin(e * PI), 0.6) + 0.0028 * sin(a * 26.0 + sin(a * 5.0) * 2.0) * sin(e * PI)
			return r
		var colf = func(a: float, s: float, _p: float) -> Color:
			if s > 0.74:
				var e := (s - 0.74) / 0.26
				return _sh(wh, 0.34 * pow(absf(e * 2.0 - 1.0), 3.0) + 0.16 * (0.5 + 0.5 * sin(a * 26.0 + sin(a * 5.0) * 2.0 + PI)))
			return _sh(cc, 0.45 * smoothstep(0.69, 0.74, s) + 0.3 * _crease(a * 4.0 + s * 5.0, 5.0) * _bell(s, 0.5, 0.3) - 0.12 * smoothstep(0.5, 0.1, s))
		_cap(mb, F, 112, 34, edge, off, colf)
		var py := _py(F, 0.0, by + 0.058)
		for sx in [-1.0, 1.0]:
			var a: float = float(sx) * 0.4
			_patch(mb, F, a, py, 0.36, 0.25, 0.036, 0.005, wh, wh.darkened(0.34))
			_patch(mb, F, a + float(sx) * -0.05, py + 0.035, 0.15, 0.14, 0.042, 0.004, Color(0.04, 0.04, 0.06))
			_patch(mb, F, a + float(sx) * -0.1, py - 0.01, 0.04, 0.04, 0.047, 0.0015, Color(0.95, 0.95, 0.95))
		_patch(mb, F, 0.0, _py(F, 0.0, by + 0.014), 0.13, 0.085, 0.031, 0.011, Color(0.06, 0.06, 0.08), Color(0.02, 0.02, 0.03))
	)
	_mask(m, F, by - 0.03, by - 0.07)


# ================================================================ baş örtüsü (ensede bağlı beyaz bez)
static func _gather(a: float, p: float, pk: float, n: float) -> float:
	var x := wrapf(a - PI, -PI, PI) * sin(clampf(p, 0.4, 2.6))
	var y := p - pk
	var dist := sqrt(x * x + y * y)
	var e := atan2(y, x)
	return _crease(e * n * 0.5 + 0.8 * sin(e * 2.0)) * smoothstep(0.08, 0.4, dist) * smoothstep(1.5, 0.45, dist)


static func _basortusu(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var ky := by - 0.095
	var pk := _py(F, PI, ky)
	_put(m, "basortusu|" + cc.to_html(), func(mb):
		var edge = func(a: float) -> float: return by + 0.018 - 0.125 * pow(_bk(a), 1.3) - 0.012 * smoothstep(0.45, 0.9, absf(sin(a)))
		var off = func(a: float, s: float, p: float) -> float:
			return 0.0125 + 0.01 * _bell(s, 0.35, 0.5) - 0.0034 * _gather(a, p, pk, 9.0)
		var colf = func(a: float, s: float, p: float) -> Color:
			return _sh(cc, 0.46 * _gather(a, p, pk, 9.0) - 0.08 * smoothstep(0.5, 0.1, s) + 0.1 * smoothstep(0.92, 1.0, s))
		var d := _cap(mb, F, 120, 34, edge, off, colf)
		var pe: Array = d["pe"]
		var pp := []
		var nn := []
		var sp := []
		for i in 121:
			var a := _ya(i % 120, 120)
			var p: float = float(pe[i])
			pp.append(_pt(F, a, p - 0.02, 0.0135))
			nn.append(_d(a, p))
			sp.append(_pt(F, a, p - 0.085, 0.0145))
		_rib(mb, pp, nn, 0.016, cc, 0.0028, 4, false, func(_k, _q, x): return _sh(cc, 0.35 * x * x - 0.08))
		_stitch(mb, sp, nn, _stitch_col(cc))
		var kp := _pt(F, PI, pk, 0.026)
		_knot(mb, kp, Vector3(1, 0.1, 0), Vector3(0, 0.3, -1), 0.021, cc)
	)
	_mask(m, F, by - 0.005, ky)
	var kp := _pt(F, PI, pk, 0.03)
	_tail(m, kp + Vector3(0.014, -0.004, -0.004), Vector3(0.45, -1.0, -0.3), Vector3(1, 0.3, 0), 0.125, 0.05, cc, {"taper": 0.45})
	_tail(m, kp + Vector3(-0.014, -0.004, -0.004), Vector3(-0.42, -1.0, -0.26), Vector3(1, -0.3, 0), 0.105, 0.046, cc.darkened(0.04), {"taper": 0.45})
	_tail(m, kp + Vector3(0, 0.008, 0.002), Vector3(0, -1.0, -0.2), Vector3(1, 0, 0), 0.085, 0.082, cc.darkened(0.07), {"tri": true, "stiff": 0.36, "seam": false})


# ================================================================ haydut bandanası
static func _basortu(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var ka := PI - 0.32
	var ky := by - 0.07
	var pk := _py(F, ka, ky)
	_put(m, "basortu|" + cc.to_html(), func(mb):
		var edge = func(a: float) -> float: return by + 0.006 - 0.09 * pow(_bk(a), 1.5)
		var wr = func(a: float, s: float) -> float:
			return _crease(a * 2.5 + s * 8.0 + 1.6 * sin(a * 2.0), 3.0) * _bell(s, 0.45, 0.45)
		var off = func(a: float, s: float, p: float) -> float:
			return 0.0125 + 0.016 * _bell(s, 0.3, 0.45) - 0.004 * wr.call(a, s) - 0.003 * _gather(a - (ka - PI), p, pk, 7.0)
		var colf = func(a: float, s: float, p: float) -> Color:
			var g := hash(Vector2i(int((a + PI) * 14.0), int(s * 26.0))) % 5
			return _sh(cc, 0.5 * float(wr.call(a, s)) + 0.42 * _gather(a - (ka - PI), p, pk, 7.0) + 0.035 * g - 0.08)
		_cap(mb, F, 112, 34, edge, off, colf)
		# alında kalın katlanmış kenar
		var r := _ring(F, func(a): return by + 0.005 - 0.09 * pow(_bk(a), 1.5) + 0.0016 * sin(a * 6.0), 0.015, -PI, PI, 88)
		r[0].pop_back()
		r[1].pop_back()
		_rib(mb, r[0], r[1], 0.033, cc, 0.0055, 6, true, func(k, _q, x): return _sh(cc, 0.46 * x * x + 0.14 * _crease(float(k) * 0.42, 3.0) - 0.08))
		var s1 := []
		var n1 := []
		for k in 44:
			var a := lerpf(-1.25, 1.25, float(k) / 43.0)
			var p := _py(F, a, by + 0.0155)
			s1.append(_pt(F, a, p, 0.0165))
			n1.append(_d(a, p))
		_stitch(mb, s1, n1, _stitch_col(cc), 0.008, 0.006, 0.0019)
		# yamalık: elle dikilmiş koyu parça
		var pa := -0.85
		var pp := 0.62
		var pc := cc.darkened(0.3)
		_patch(mb, F, pa, pp, 0.2, 0.17, 0.02, 0.0028, pc, pc.darkened(0.2))
		var sq := []
		var sn := []
		for k in 29:
			var t := TAU * float(k) / 28.0
			var aa: float = pa + cos(t) * 0.21 / sin(pp)
			var qq: float = pp + sin(t) * 0.18
			sq.append(_pt(F, aa, qq, 0.0225))
			sn.append(_d(aa, qq))
		_stitch(mb, sq, sn, cc.lightened(0.38), 0.008, 0.007, 0.0022)
		_knot(mb, _pt(F, ka, pk, 0.028), Vector3(0.75, 0.55, 0.2), Vector3(0, 0.3, -1), 0.027, cc)
	)
	_mask(m, F, by - 0.018, ky)
	var kp := _pt(F, ka, pk, 0.034)
	var side := Vector3(1, 0.2, 0)
	_tail(m, kp + Vector3(0.02, 0, -0.002), Vector3(0.68, -1.0, -0.28), side, 0.15, 0.052, cc, {"fray": true, "taper": 0.35})
	_tail(m, kp + Vector3(-0.012, -0.008, -0.002), Vector3(-0.22, -1.0, -0.42), side, 0.115, 0.044, cc.darkened(0.08), {"fray": true, "taper": 0.3})


# ================================================================ üst üste binen sargı kabuğu (ortak: sargı kep, göz bağlı sargı)
static func _lap(a: float, p: float, tilt: float, hp: float) -> float:
	return fposmod((p + tilt * sin(a + 0.6) + 0.04 * sin(a * 3.0)) / hp, 1.0)


static func _wrap_cap(mb: MB, F: Dictionary, cc: Color, edge: Callable, base: float, puff: float, tilt: float, hp: float) -> void:
	var off = func(a: float, s: float, p: float) -> float:
		var f := _lap(a, p, tilt, hp)
		return base + puff * _bell(s, 0.3, 0.5) + (0.0042 * f + 0.0009 * sin(f * TAU)) * smoothstep(0.05, 0.24, s)
	var colf = func(a: float, s: float, p: float) -> Color:
		var f := _lap(a, p, tilt, hp)
		return _sh(cc, (0.6 * smoothstep(0.17, 0.0, f) + 0.1 * smoothstep(0.75, 1.0, f)) * smoothstep(0.05, 0.24, s) - 0.06)
	_cap(mb, F, 120, 64, edge, off, colf)


# ================================================================ sargı kep (kaynak: Iwabe)
static func _iwabe(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var top: float = F["top"]
	var dk := Color(0.1, 0.11, 0.16)
	var c0: Vector3 = F["c"]
	_put(m, "iwabe|" + cc.to_html(), func(mb):
		_wrap_cap(mb, F, cc, func(a): return by - 0.014 - 0.06 * pow(_bk(a), 1.4), 0.018, 0.012, 0.13, 0.27)
		for sg in [1.0, -1.0]:
			var r := _ring(F, func(a): return by + 0.022 + float(sg) * 0.023 * sin(a + 0.25), 0.027, -PI, PI, 84)
			r[0].pop_back()
			r[1].pop_back()
			_rib(mb, r[0], r[1], 0.019, dk, 0.0032, 4, true, func(_k, _q, x): return _sh(dk, 0.3 * x * x - 0.3 * (1.0 - absf(x))))
		var tp := Vector3(c0.x + 0.008, top + 0.036, c0.z - 0.012)
		_knot(mb, tp, Vector3(1, 0.22, 0.25), Vector3(0, 1, 0), 0.03, cc.lightened(0.02))
		for sx in [-1.0, 1.0]:   # düğümün dik kulakları
			var base := tp + Vector3(float(sx) * 0.028, 0.002, 0)
			var dir := Vector3(float(sx) * 0.72, 0.62, -0.1).normalized()
			var pts := []
			var rad := []
			for k in 8:
				var e := float(k) / 7.0
				pts.append(base + dir * e * 0.046 + Vector3(0, -0.012 * e * e, 0))
				rad.append(0.013 * sin(minf(e + 0.18, 1.0) * PI) + 0.002)
			_tube(mb, pts, rad, func(k, i): return _sh(cc, 0.3 * _crease(float(i) * 0.9 + float(k) * 0.4, 2.0)), 8)
	)
	_mask(m, F, by - 0.03, by - 0.07)
	var a0 := 1.42
	var sp := _pt(F, a0, _py(F, a0, by), 0.03)
	for q in 2:
		_tail(m, sp + Vector3(0, -0.002, -0.006 * q), Vector3(0.14 + 0.13 * q, -1.0, -0.2), Vector3(0, 0, 1), 0.15 + 0.03 * q, 0.0085, dk, {"taper": 0.1, "wave": 0.003, "seam": false})


# ================================================================ kurbağa kapüşonu
static func _kurbaga(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var top: float = F["top"]
	var c0: Vector3 = F["c"]
	var belly := cc.lightened(0.5)
	_put(m, "kurbaga|" + cc.to_html(), func(mb):
		var h := _hood(mb, F, cc, {"pad": 0.05, "back": 0.03, "W": 1.05, "up": 0.018, "dn": 0.005, "lip": 0.021, "fold": 0.4, "lip_col": cc.lightened(0.1), "nc": 104, "nr": 44})
		var pos: Callable = h["pos"]
		# göz tümsekleri: göz kapağı halkası + göz akı + bebek
		for sx in [-1.0, 1.0]:
			var e := Vector3(c0.x + float(sx) * float(F["hw"]) * 0.4, top + 0.036, c0.z + 0.03)
			var xf := Transform3D(Basis.IDENTITY.rotated(Vector3(0, 0, 1), -float(sx) * 0.16), e)
			var prof := []
			for k in 13:
				var t := float(k) / 12.0 * PI * 0.92
				prof.append(Vector2(sin(t) * 0.05 + 0.0005, cos(t) * 0.046))
			_lathe(mb, prof, 26, xf, func(_a, j): return _sh(cc, -0.12 + 0.3 * smoothstep(8.0, 12.0, float(j))))
			var zf := xf.basis.z
			var f := e + zf * 0.036 + Vector3(0, 0.006, 0)
			mb.add("sphere", f, Vector3(0.056, 0.056, 0.034), Color(0.95, 0.94, 0.86), Vector3.ZERO, 16)
			mb.add("sphere", f + zf * 0.014, Vector3(0.03, 0.034, 0.012), Color(0.05, 0.05, 0.07), Vector3.ZERO, 12)
			mb.add("sphere", f + zf * 0.02 + Vector3(-0.006, 0.009, 0), Vector3(0.008, 0.008, 0.003), Color(0.97, 0.97, 0.97), Vector3.ZERO, 6)
			# göz kapağı kenarı
			var rim := []
			var rn := []
			for k in 25:
				var t := TAU * float(k % 24) / 24.0
				var dd := Vector3(cos(t), sin(t), 0)
				rim.append(f + zf * 0.003 + dd * 0.029)
				rn.append((dd + zf * 0.7).normalized())
			rim.pop_back()
			rn.pop_back()
			_rib(mb, rim, rn, 0.009, cc.lightened(0.14), 0.0035, 3, true)
		# yanaklarda pembe daire, iki yanda dikişli karın parçası
		for sx in [-1.0, 1.0]:
			var a: float = float(sx) * 1.5
			var p := _py(F, a, float(F["eye"]) - 0.035)
			_patch(mb, F, a, p, 0.25, 0.25, 0.053, 0.004, Color(0.98, 0.62, 0.62), Color(0.86, 0.46, 0.48))
		# ağız: açıklığın altından iki yana uzanan dikiş
		for sx in [-1.0, 1.0]:
			var pp := []
			var nn := []
			for k in 15:
				var t := float(k) / 14.0
				var a: float = float(sx) * lerpf(1.3, 2.25, t)
				var s := lerpf(0.67, 0.6, t)
				var u := 0.5 - float(sx) * (0.5 - (absf(a) - 1.05) / TAU)
				pp.append(pos.call(a, s, u, 0.001))
				nn.append(_d(a, s * float(h["pf"])))
			_rib(mb, pp, nn, 0.006, cc.darkened(0.5), 0.0014, 2)
		_patch(mb, F, PI, _py(F, PI, by - 0.1), 0.42, 0.28, 0.06, 0.0032, belly, belly.darkened(0.2))
	)


# ================================================================ kardan adam
static func _kardan(m, F: Dictionary) -> void:
	var c0: Vector3 = F["c"]
	var cen := Vector3(c0.x, float(F["eye"]) - 0.005, c0.z + 0.012)
	var R := 0.0
	for j in range(1, 24):
		for i in 16:
			R = maxf(R, (_pt(F, _ya(i, 16), float(j) / 24.0 * 2.05, 0.0) - cen).length())
	R += 0.018
	_put(m, "kardan", func(mb):
		var snow := Color(0.96, 0.97, 0.99)
		var P := []
		var C := []
		var nj := 46
		var ni := 92
		for j in nj + 1:
			var p := maxf(0.01, float(j) / nj * PI)
			var rp := []
			var rc := []
			for i in ni + 1:
				var a := _ya(i % ni, ni)
				var d := _d(a, p)
				var v := 0.0060 * sin(d.x * 11.0 + d.y * 7.0 + 1.0) * sin(d.z * 10.0 - d.y * 5.0) + 0.0035 * sin(d.x * 23.0 - d.z * 19.0 + d.y * 17.0) + 0.0016 * sin(d.x * 47.0 + d.y * 41.0 + d.z * 37.0)
				rp.append(cen + d * (R + v))
				rc.append(_sh(snow, 0.22 * smoothstep(0.0, -0.8, d.y) + 0.1 * smoothstep(0.002, -0.006, v)).lerp(Color(0.72, 0.8, 0.95), 0.1 * smoothstep(0.1, -0.8, d.y)))
			P.append(rp)
			C.append(rc)
		_grid(mb, P, C, true, cen)
		# kömür gözler, gülüş
		var coal := Color(0.055, 0.055, 0.065)
		for sx in [-1.0, 1.0]:
			mb.add("boulder", cen + Vector3(float(sx) * R * 0.37, R * 0.27, R * 0.875), Vector3(0.05, 0.052, 0.034), coal, Vector3(0, float(sx) * 20.0, 0), 3 + int(sx))
		for k in 7:
			var t := (float(k) - 3.0) / 3.0
			var a := t * 0.62
			var e := -0.36 - 0.17 * (1.0 - t * t)
			var d := Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e))
			mb.add("boulder", cen + d * (R + 0.001), Vector3(0.023, 0.023, 0.018), coal, Vector3(float(k) * 40.0, float(k) * 70.0, 0), 5 + k)
		# havuç: halkalı, ucu hafif aşağı
		var pts := []
		var rad := []
		var nos := cen + Vector3(0, 0.004, R - 0.012)
		for k in 15:
			var t := float(k) / 14.0
			pts.append(nos + Vector3(0.002 * t, -0.016 * t * t, 0.105 * t))
			rad.append(lerpf(0.026, 0.002, pow(t, 0.8)) * (1.0 - 0.1 * _crease(t * 11.0, 4.0)))
		var org := Color(0.95, 0.42, 0.1)
		_tube(mb, pts, rad, func(k, _i): return _sh(org, 0.5 * _crease(float(k) / 14.0 * 11.0, 4.0)), 10)
		# sarı kova: eğik, kenar halkası, kulp, ezik yanak
		var y0 := Color(0.93, 0.76, 0.22)
		var B := Basis.IDENTITY.rotated(Vector3(0, 0, 1), -0.2).rotated(Vector3(1, 0, 0), -0.08)
		var xf := Transform3D(B, cen + B * Vector3(0, R * 0.74, 0) + Vector3(0.008, 0, -0.008))
		var hb := R * 0.52
		var rb := R * 0.64
		var rt := R * 0.47
		var pr := [Vector2(0.001, hb), Vector2(rt * 0.96, hb), Vector2(rt, hb - 0.004), Vector2(rt + 0.004, hb - 0.012)]
		for k in 9:
			var t := float(k) / 8.0
			pr.append(Vector2(lerpf(rt + 0.002, rb, t), lerpf(hb - 0.016, 0.012, t)))
		pr.append_array([Vector2(rb + 0.009, 0.01), Vector2(rb + 0.011, 0.0), Vector2(rb + 0.009, -0.01), Vector2(rb - 0.003, -0.012)])
		_lathe(mb, pr, 40, xf, func(a, j):
			var ridge := 0.34 if j == 4 or j == 7 or j == 10 else 0.0
			return _sh(y0, ridge + 0.12 * (0.5 + 0.5 * sin(a * 3.0 + 1.0)) - 0.14 * pow(maxf(0.0, cos(a - 0.7)), 10.0)))
		for sx in [-1.0, 1.0]:
			mb.add("sphere", xf * Vector3(float(sx) * (lerpf(rb, rt, 0.34) + 0.004), hb * 0.34, 0), Vector3(0.016, 0.016, 0.012), y0.darkened(0.3), Vector3.ZERO, 8)
		var hh := []
		var rh := lerpf(rb, rt, 0.34) + 0.006
		for k in 21:
			var t := float(k) / 20.0 * PI
			hh.append(xf * Vector3(cos(t) * rh, hb * 0.34 - sin(t) * 0.032, sin(t) * rh))
		_tube(mb, hh, 0.0032, Color(0.62, 0.64, 0.68), 5)
	)


# ================================================================ gelin duvağı
static func _gelin(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var green := Color(0.2, 0.3, 0.24)
	_put(m, "gelin|" + cc.to_html(), func(mb):
		_knit_cap(mb, F, green, green.lightened(0.1), by + 0.018, by - 0.05, 40, 0.008, 0.84)
		# duvağı tutan örgülü kordon
		var r := _ring(F, func(a): return by + 0.03 + 0.05 * smoothstep(1.5, 0.5, absf(a)), 0.03, -1.0, 1.0, 40)
		_rib(mb, r[0], r[1], 0.014, cc, 0.0055, 4, false, func(k, _q, x): return _sh(cc, 0.42 * _crease(float(k) * 0.7 + x * 1.3, 2.0) - 0.1))
	)
	_mask(m, F, by - 0.005, by - 0.05)
	var tops := []
	var outs := []
	var lens := []
	var heads := []
	var N := 40
	for c in N + 1:
		var deg := lerpf(38.0, 322.0, float(c) / N)
		var a := wrapf(deg_to_rad(deg), -PI, PI)
		var p := _py(F, a, by + 0.03 - 0.05 * _bk(a))
		var p0 := lerpf(0.5, 0.82, smoothstep(1.9, 0.7, absf(a)))
		var hd := []
		for k in 6:
			var e := float(k) / 6.0
			var q := lerpf(p0, p, e)
			hd.append([_pt(F, a, q, lerpf(0.03, 0.046, e) + 0.004 * sin(a * 9.0 + e * 3.0) * e), _d(a, q)])
		heads.append(hd)
		tops.append(_pt(F, a, p, 0.046))
		outs.append(Vector3(sin(a), 0, cos(a)))
		lens.append(0.38 + 0.22 * _bk(a))
	var ivory := cc
	_curtain(m, "gelin|" + cc.to_html(), tops, outs, lens, 0.05, func(c, t):
		var q := _sh(ivory, 0.18 * smoothstep(0.82, 0.84, t) * smoothstep(0.9, 0.88, t) + 0.1 * smoothstep(0.96, 1.0, t))
		return q.lightened(0.14) if t > 0.9 and (c % 2 == 0) else q, 0.32, 0.021, heads)


# ================================================================ hachimaki
static func _hachimaki(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var yf = func(a: float) -> float: return by + 0.002 - 0.008 * _bk(a) + 0.0012 * sin(a * 9.0) * smoothstep(0.3, 0.9, absf(sin(a)))
	_put(m, "hachimaki|" + cc.to_html(), func(mb):
		var r := _ring(F, yf, 0.013, -PI, PI, 112)
		r[0].pop_back()
		r[1].pop_back()
		var pts: Array = r[0]
		var nrs: Array = r[1]
		_rib(mb, pts, nrs, 0.045, cc, 0.0036, 8, true, func(k, _q, x):
			var a := _ya(int(k), 112)
			var wr := _crease(a * 8.0 + x * 1.6, 5.0) * smoothstep(0.25, 0.85, absf(sin(a)))   # şakakta bant büzülür
			var edge := smoothstep(0.76, 0.8, absf(x)) * 0.16
			var mid := 0.34 * smoothstep(0.1, 0.0, absf(x + 0.1))   # boyuna kat izi
			return _sh(cc, wr * 0.42 + edge + mid - 0.04))
		for sg in [-1.0, 1.0]:
			var up := float(sg) * 0.0178
			var sp := []
			var sn := []
			for k in pts.size():
				var pa: Vector3 = pts[k]
				sp.append(pa + Vector3(0, up, 0) + (nrs[k] as Vector3) * 0.0034)
				sn.append(nrs[k])
			_stitch(mb, sp, sn, _stitch_col(cc), 0.0055, 0.0045, 0.0014)
		var kp := _pt(F, PI, _py(F, PI, by - 0.006), 0.027)
		_knot(mb, kp, Vector3(1, 0.14, 0), Vector3(0, 0.25, -1), 0.024, cc)
	)
	m.hair_mask_band(by, 0.058, 0.008)
	var kp := _pt(F, PI, _py(F, PI, by - 0.006), 0.031)
	_tail(m, kp + Vector3(0.016, -0.002, -0.004), Vector3(0.3, -1.0, -0.42), Vector3(1, 0.2, 0), 0.27, 0.034, cc, {"taper": 0.12})
	_tail(m, kp + Vector3(-0.016, -0.002, -0.004), Vector3(-0.2, -1.0, -0.5), Vector3(1, -0.2, 0), 0.235, 0.032, cc.darkened(0.05), {"taper": 0.12})


# ================================================================ çöl sarığı
static func _sarik(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	_put(m, "sarik|" + cc.to_html(), func(mb):
		var inner := cc.darkened(0.14)
		var edge = func(a: float) -> float: return by + 0.018 - 0.05 * _bk(a)
		var off = func(a: float, s: float, _p: float) -> float:
			return 0.02 + 0.03 * _bell(s, 0.2, 0.55) - 0.003 * _crease(atan2(sin(a), cos(a)) * 4.0 + s * 3.0, 3.0)
		var colf = func(a: float, s: float, _p: float) -> Color:
			return _sh(inner, 0.45 * _crease(a * 4.0 + s * 3.0, 3.0) - 0.05)
		_cap(mb, F, 96, 22, edge, off, colf)
		# çapraz binen kat kat sargı: her tur önde öbürünü keser
		var N := 9
		for i in N:
			var u := float(i) / (N - 1)
			var sg := 1.0 if i % 2 == 0 else -1.0
			var y0 := by - 0.008 + u * 0.102
			var amp := 0.024 * (1.0 - 0.42 * u)
			var drop := 0.03 * (1.0 - u)
			var pad := 0.022 + 0.012 * sin(u * PI) + 0.0022 * i
			var r := _ring(F, func(a): return y0 + sg * amp * sin(a) - drop * _bk(a), pad, -PI, PI, 92)
			r[0].pop_back()
			r[1].pop_back()
			var w := 0.041 - 0.009 * u
			var tone := cc.darkened(0.035 * float((i * 3) % 3))
			_rib(mb, r[0], r[1], w, tone, 0.0085, 8, true, func(k, _q, x):
				var a := _ya(int(k), 92)
				var f := _crease(x * 3.4 + a * 2.0 + float(i) * 1.3, 3.0)
				return _sh(tone, 0.34 * f + 0.34 * x * x * x * x - 0.13 * (1.0 - absf(x))))
	)
	_mask(m, F, by - 0.02, by - 0.05)
	var a0 := PI - 0.5
	var tp := _pt(F, a0, _py(F, a0, by + 0.018), 0.046)
	_tail(m, tp, Vector3(0.28, -1.0, -0.32), Vector3(1, 0.1, -0.2), 0.36, 0.062, cc, {"taper": 0.18, "fray": true, "wave": 0.012})


# ================================================================ Tsuri Bōshi (kaynak: Inari)
static func _tsuribo(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var top: float = F["top"] + 0.016
	var blue := Color(0.1, 0.27, 0.58)
	_put(m, "tsuribo|" + cc.to_html(), func(mb):
		var H := top - by
		var rows := []
		for k in 7:
			var t := float(k) / 6.0
			rows.append([t * 0.84, 0.0, top + 0.004 * (1.0 - t * t)])
		var nc := 16
		for k in range(1, nc + 1):
			var t := float(k) / nc
			rows.append([lerpf(0.84, 1.0, pow(t, 0.8)), 0.017 * t, top - (H - 0.01) * t])
		var nb := 12
		for k in range(1, nb + 1):
			var t := float(k) / nb
			rows.append([1.0, 0.017 + 0.068 * t, by + 0.01 - 0.03 * t - 0.01 * t * t])
		rows.append([1.0, 0.088, by - 0.033])
		rows.append([1.0, 0.084, by - 0.038])
		rows.append([1.0, 0.03, by + 0.002])
		var n0 := 7
		var n1 := n0 + nc
		var disp = func(a: float, j: int) -> Vector2:
			var v := Vector2.ZERO
			if j >= n1:
				var t := clampf(float(j - n1) / nb, 0.0, 1.0)
				v.y = 0.006 * t * sin(a * 3.0 + 0.8) + 0.003 * t * sin(a * 7.0) + 0.016 * t * maxf(cos(a), 0.0)
				if j % 3 == 0:
					v.y -= 0.0009
			elif j >= n0:
				v.x = -0.0014 * _crease(a * 3.0 + float(j) * 0.14, 6.0)
			return v
		var colf = func(a: float, j: int) -> Color:
			if j < n0:
				return _sh(cc, 0.34 if j == n0 - 1 else (0.05 if j % 2 == 0 else -0.04))
			if j >= n1 + nb + 2:
				return cc.darkened(0.5)
			if j >= n1:
				var stitch := 0.26 if (j - n1) % 3 == 2 else 0.0
				return _sh(cc, stitch + 0.1 * smoothstep(0.0, 1.0, float(j - n1) / nb) * (0.5 + 0.5 * sin(a * 3.0 + 0.8)))
			var t := float(j - n0) / nc
			var c := cc
			if (t > 0.3 and t < 0.46) or (t > 0.6 and t < 0.76):
				c = blue
			var v := 0.36 * _crease(a * 3.0 + float(j) * 0.14, 6.0)
			v += 0.34 if abs(t - 0.98) < 0.03 else 0.0
			return _sh(c, v)
		_crown(mb, F, 96, rows, disp, colf)
		# havalandırma delikleri
		var c0: Vector3 = F["c"]
		for sx in [-1.0, 1.0]:
			for k in 2:
				var yy := top - H * 0.2
				var a: float = float(sx) * (1.3 + float(k) * 0.42)
				var q := _pt(F, a, _py(F, a, by), 0.0)
				var rr := Vector2(q.x - c0.x, q.z - c0.z).length() * 0.885 + 0.0042
				mb.add("cyl", Vector3(c0.x + sin(a) * rr, yy, c0.z + cos(a) * rr), Vector3(0.0085, 0.002, 0.0085), Color(0.1, 0.1, 0.12), Vector3(90, rad_to_deg(a), 0), 8)
	)
	_mask(m, F, by + 0.004, by + 0.004)


# ================================================================ Shūdō Zukin (kaynak: Nonō)
static func _shudo(m, F: Dictionary, cc: Color) -> void:
	_put(m, "shudo|" + cc.to_html(), func(mb):
		_hood(mb, F, cc, {"pad": 0.03, "back": 0.012, "peak": 0.02, "W": 1.28, "up": 0.03, "dn": 0.02, "lip": 0.012, "fold": 0.55}))


# ================================================================ Okina Zukin (kaynak: Ebizō)
static func _okina(m, F: Dictionary, cc: Color) -> void:
	var by: float = F["by"]
	var top: float = float(F["top"]) + 0.024
	var yb := by + 0.002
	_put(m, "okina|" + cc.to_html(), func(mb):
		var H := top - yb
		var rows := []
		for k in 6:
			var t := float(k) / 5.0
			rows.append([t * 0.8, 0.0, top + 0.003 * (1.0 - t * t)])
		var nr := 44
		for k in range(1, nr + 1):
			var t := float(k) / nr
			rows.append([lerpf(0.8, 1.0, sqrt(t)), 0.019 * smoothstep(0.0, 0.22, t), top - H * t])
		var n0 := 6
		var lap = func(a: float, j: int) -> float:
			var t := float(j - n0 + 1) / nr
			return fposmod(t * 5.0 + 0.09 * sin(a + 0.5) + 0.05 * sin(a * 2.0), 1.0)
		var disp = func(a: float, j: int) -> Vector2:
			if j < n0:
				return Vector2.ZERO
			var f: float = lap.call(a, j)
			return Vector2(0.0058 * f + 0.0014 * sin(f * TAU), 0.0)
		var colf = func(a: float, j: int) -> Color:
			if j < n0:
				return _sh(cc, 0.22 * _crease(a * 2.5 + float(j) * 0.7, 3.0) + 0.14 * float(j == n0 - 1))
			var f: float = lap.call(a, j)
			return _sh(cc, 0.62 * smoothstep(0.16, 0.0, f) + 0.1 * smoothstep(0.7, 1.0, f) - 0.05)
		_crown(mb, F, 104, rows, disp, colf)
		# önde çapraz sokulmuş kat ucu
		var pp := []
		var nn := []
		var c0: Vector3 = F["c"]
		for k in 12:
			var t := float(k) / 11.0
			var a := lerpf(-0.42, 0.34, t)
			var q := _pt(F, a, _py(F, a, by), 0.0)
			var rr := Vector2(q.x - c0.x, q.z - c0.z).length() + 0.0265
			var y := yb + H * lerpf(0.2, 0.62, t)
			var d := Vector3(sin(a), 0.0, cos(a))
			pp.append(Vector3(c0.x + d.x * rr, y, c0.z + d.z * rr))
			nn.append(d)
		_rib(mb, pp, nn, 0.021, cc.lightened(0.04), 0.0028, 4, false, func(_k, _q, x): return _sh(cc, 0.42 * x * x * x * x - 0.12))
		_stitch(mb, pp, nn, cc.darkened(0.35), 0.005, 0.005, 0.0014)
	)
	m.hair_mask_plane(Vector3.UP, Vector3(0, yb - 0.004, 0))


# ================================================================ Mekakushi Hōtai (kaynak: Tonbo Tobitake)
static func _mekakushi(m, F: Dictionary, cc: Color) -> void:
	var eye: float = F["eye"]
	var by: float = F["by"]
	var dk := Color(0.1, 0.1, 0.13)
	var yf = func(a: float) -> float: return eye + 0.004 - 0.018 * _bk(a) + 0.0012 * sin(a * 7.0)
	_put(m, "mekakushi|" + cc.to_html(), func(mb):
		var edge = func(a: float) -> float:
			var b := smoothstep(0.85, 1.75, absf(wrapf(a, -PI, PI)))
			return lerpf(eye - 0.036, float(F["neck"]) + 0.03, b)
		_wrap_cap(mb, F, cc, edge, 0.0165, 0.022, 0.17, 0.25)
		var r := _ring(F, yf, 0.0285, -PI, PI, 96)
		r[0].pop_back()
		r[1].pop_back()
		_rib(mb, r[0], r[1], 0.054, dk, 0.0052, 8, true, func(k, q, x):
			var a := _ya(int(k), 96)
			var v := 0.38 * _crease(a * 5.0 + x * 1.6, 4.0) * smoothstep(0.35, 1.0, absf(sin(a))) + 0.34 * smoothstep(0.72, 0.78, absf(x)) + 0.28 * smoothstep(0.1, 0.0, absf(x - 0.2))
			return _sh(dk, v - 0.42 + (0.1 if int(q) % 2 == 0 else 0.0)))
		var kp := _pt(F, PI + 0.16, _py(F, PI + 0.16, eye - 0.012), 0.04)
		_knot(mb, kp, Vector3(0.95, 0.25, 0.1), Vector3(0, 0.25, -1), 0.024, dk.lightened(0.05))
	)
	var kp := _pt(F, PI + 0.16, _py(F, PI + 0.16, eye - 0.012), 0.046)
	var sd := Vector3(0.3, 1, 0.1)
	_tail(m, kp + Vector3(-0.018, 0.004, -0.004), Vector3(-1.0, 0.5, -0.5), sd, 0.11, 0.042, dk, {"taper": 0.55, "stiff": 0.42})
	_tail(m, kp + Vector3(-0.016, -0.006, -0.004), Vector3(-0.9, -0.62, -0.4), sd, 0.12, 0.042, dk, {"taper": 0.55, "stiff": 0.42})
