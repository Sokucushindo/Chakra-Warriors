extends RefCounted
## Yarım yüz parçaları: bez maske, peçe, gözlük, gaz maskesi, mempo, sargı... (MaskV2 çağırır)
## Hepsi yüz kabuğundan (face_r) üretilir: bez yüze oturur, sert parçalar yüze değen contadan çıkar, kopuk durmaz.
## Kaynak: refs/kiyafet/yy_* (bez maske, Ame solunum maskesi, samuray solunum aparatı, yarım peçe, mühürlü göz kapağı, tel gözlük)

const STYLES := ["cloth", "pece", "gas", "gaz_maskesi", "solunum_maskesi", "goggles", "koruyucu_gozluk", "yuvarlak_gozluk", "vizor", "tek_mercek", "mempo", "demir_yarim_maske", "goz_bandi", "bandaj_alt", "tam_bandaj", "yuksek_pece", "savas_boyasi", "megane", "katamen_fukumen", "fuin_gantai", "katame_hotai"]
const F := PI * 0.5
const INK := Color(0.05, 0.05, 0.06)
const STEEL := Color(0.6, 0.63, 0.68)
const DSTEEL := Color(0.3, 0.32, 0.36)
const RUBBER := Color(0.13, 0.13, 0.15)
const LEATHER := Color(0.2, 0.14, 0.1)
const BRASS := Color(0.82, 0.64, 0.28)
const LINEN := Color(0.92, 0.89, 0.81)
const GLINT := Color(0.96, 0.98, 1.0)
const CACHE_MAX := 96
static var _cache := {}


static func G(x: float, s: float) -> float:
	return exp(-x * x / (s * s))


## Renksiz (siyah / gri) varsayılan eşya renginde parçanın kendi rengi; boyanmış eşyada eşya rengi
static func _tint(fg: Color, base: Color) -> Color:
	return fg if fg.s > 0.28 and fg.v > 0.18 else base


class Y:
	var m
	var mb := MB.new()
	var post := []   # önbellekli meshten sonra da her modele uygulanacaklar (saç maskesi, sarkan kumaş)
	var ey := 0.0
	var nose := 0.0
	var chin := 0.0
	var neck := 0.0
	var cx := 0.0
	var cz := 0.0
	var ar := 0.0   # sağ göz açısı (F'den büyük)
	var al := 0.0
	var nx := 0.0   # boyun halkası: merkez ve yarıçap (gerçek gövdeden)
	var nz := 0.0
	var rn := 0.052
	var _rc := {}

	func _init(mm) -> void:
		m = mm
		ey = m.eye_center_model.y if m.face_mi != null else m._head_center().y - 0.03
		nose = ey - 0.032
		chin = ey - 0.115
		neck = m._bp("Neck").y + 0.04
		cx = m.skull_c.x
		cz = m.skull_c.z
		ar = m.eye_a(true)
		al = m.eye_a(false)
		var nb: Vector3 = m._bp("Neck")
		nx = nb.x
		nz = nb.z
		if m.body_mesh != null and m.body_mesh.mesh != null:
			var c := Vector2.ZERO
			var pts := []
			for q in m._body_vs():
				if absf(q.y - neck) < 0.014 and Vector2(q.x - nb.x, q.z - nb.z).length() < 0.085:
					pts.append(Vector2(q.x, q.z))
					c += Vector2(q.x, q.z)
			if pts.size() > 6:
				c /= pts.size()
				nx = c.x
				nz = c.y
				var mx := 0.0
				for q in pts:
					mx = maxf(mx, c.distance_to(q))
				rn = clampf(mx, 0.03, 0.075)

	func O(a: float) -> Vector3:
		return Vector3(cos(a), 0.0, sin(a))

	func at(a: float, y: float, r: float) -> Vector3:
		return Vector3(cx + cos(a) * r, y, cz + sin(a) * r)

	## Kumaşın gerildiği yüzey: burun ucu ile çene arasında köprü, çeneden boyna iniş
	func T(a: float, y: float) -> float:
		var r: float = m.face_r(a, y)
		var key := snappedf(a, 0.001)
		if not _rc.has(key):
			_rc[key] = [m.face_r(a, ey - 0.05), m.face_r(a, chin + 0.006)]
		var yn := ey - 0.05
		var yc := chin + 0.006
		var rn: float = _rc[key][0]
		var rc: float = _rc[key][1]
		if y < yc:
			return lerpf(rc, minf(r, rc), smoothstep(0.0, 1.0, (yc - y) / maxf(yc - neck, 0.012)))
		if y < yn:
			return maxf(r, lerpf(rc, rn, (y - yc) / (yn - yc)))
		return r

	## Kumaş / maske noktası: çenenin altında yüz kabuğundan boyun halkasına geçer (boyun kafa ekseninin arkasında)
	func P(a: float, y: float, pad: float) -> Vector3:
		# yanlarda ve arkada kumaş çeneden önce ayrılır: çene köşesinde kanat oluşmaz
		var yc := chin + 0.006 + 0.036 * smoothstep(0.5, 1.4, absf(wrapf(a - F, -PI, PI)))
		if y >= yc:
			return at(a, y, T(a, y) + pad)
		var w := smoothstep(0.0, 1.0, (yc - y) / maxf(yc - neck, 0.012))
		var rr := rn + pad + maxf(0.0, neck - y) * 0.42   # boyun dibi trapeze doğru genişler
		return at(a, y, T(a, yc) + pad).lerp(Vector3(nx + cos(a) * rr, y, nz + sin(a) * rr), w)

	## Çıplak yüz yüzeyi (burun köprüsü yok)
	func S(a: float, y: float, pad: float) -> Vector3:
		return at(a, y, m.face_r(a, y) + pad)

	func _cf(c) -> Callable:
		if c is Callable:
			return c
		return func(_u, _v): return c

	func _tri(a: int, b: int, c: int) -> void:
		var p: Vector3 = mb.verts[a]
		var n: Vector3 = mb.normals[a] + mb.normals[b] + mb.normals[c]
		if (mb.verts[b] - p).cross(mb.verts[c] - p).dot(n) > 0.0:
			var t := b
			b = c
			c = t
		mb.idx.append(a)
		mb.idx.append(b)
		mb.idx.append(c)

	## Izgara yüzey. G[j][i] noktalar; renk col(u, v). flat_v: satırlar arası keskin kenar. axis: dış yön baş ekseninden
	func grid(g: Array, col, closed := false, flat_v := false, smooth := true, out := Vector3.ZERO, axis := false, flip := false) -> void:
		var cf := _cf(col)
		var nj: int = g.size()
		var ni: int = g[0].size()
		var ci: int = ni if closed else ni - 1
		var nn := []
		var dd := []
		var sgn := 0.0
		for j in nj:
			var ro: Array = g[j]
			var r0: Array = g[maxi(j - 1, 0)]
			var r1: Array = g[mini(j + 1, nj - 1)]
			var c := Vector3.ZERO
			for p in ro:
				c += p
			c /= ni
			var nr := []
			var dr := []
			for i in ni:
				var ia: int = (i - 1 + ni) % ni if closed else maxi(i - 1, 0)
				var ib: int = (i + 1) % ni if closed else mini(i + 1, ni - 1)
				var du: Vector3 = ro[ib] - ro[ia]
				if du.length_squared() < 1e-11:
					du = (r1[ib] - r1[ia]) + (r0[ib] - r0[ia])
				var n: Vector3 = du.cross(r1[i] - r0[i]).normalized()
				var p: Vector3 = ro[i]
				var w: Vector3 = out
				if out == Vector3.ZERO:
					w = p - (Vector3(cx, p.y, cz) if axis else c)
				sgn += n.dot(w)
				nr.append(n)
				dr.append(du)
			nn.append(nr)
			dd.append(dr)
		var fl := -1.0 if (sgn < 0.0) != flip else 1.0
		for j in nj - 1:
			for i in ci:
				var i2: int = (i + 1) % ni
				var u0 := float(i) / ci
				var u1 := float(i + 1) / ci
				var v0 := float(j) / (nj - 1)
				var v1 := float(j + 1) / (nj - 1)
				var base: int = mb.verts.size()
				var cc = null if smooth else cf.call((u0 + u1) * 0.5, (v0 + v1) * 0.5)
				for q in [[i, j, u0, v0], [i2, j, u1, v0], [i2, j + 1, u1, v1], [i, j + 1, u0, v1]]:
					var qi: int = q[0]
					var qj: int = q[1]
					var n: Vector3 = nn[qj][qi]
					if flat_v:
						var fn: Vector3 = (dd[qj][qi] as Vector3).cross(g[j + 1][qi] - g[j][qi])
						if fn.length_squared() > 1e-14:
							n = fn.normalized()
					mb.verts.append(g[qj][qi])
					mb.normals.append(n * fl)
					mb.colors.append(cc if cc != null else cf.call(q[2], q[3]))
					mb.uvs.append(Vector2.ZERO)
				_tri(base, base + 1, base + 2)
				_tri(base, base + 2, base + 3)

	## fn(u, v) -> nokta; baş ekseninden dışa bakan yüzey
	func sheet(nu: int, nv: int, fn: Callable, col, closed := false, smooth := true, flat_v := false, flip := false) -> void:
		var g := []
		for j in nv + 1:
			var ro := []
			for i in (nu if closed else nu + 1):
				ro.append(fn.call(float(i) / nu, float(j) / nv))
			g.append(ro)
		grid(g, col, closed, flat_v, smooth, Vector3.ZERO, true, flip)

	## Parçanın arkası (boyun altından / arkadan bakınca içi boş görünmesin)
	func backing(nu: int, nv: int, fn: Callable, c := Color(0.05, 0.05, 0.06)) -> void:
		var bf = func(u: float, v: float) -> Vector3:
			var q: Vector3 = fn.call(u, v)
			return q - (q - Vector3(cx, q.y, cz)).normalized() * 0.0012
		sheet(nu, nv, bf, c, false, true, false, true)

	## Kenarları yüze gömülen sert / kalın parça: d = F'den açı farkı; t(d), b(d) üst-alt; pad(d, y); col(d, y)
	func panel(ac: float, dh: float, t: Callable, b: Callable, pad: Callable, col, nu := 30, nv := 12, tuck := 0.001) -> void:
		var cf := _cf(col)
		var fn = func(u: float, v: float) -> Vector3:
			var d := (u - 0.5) * 2.0 * dh
			var y0: float = b.call(d)
			var y1: float = t.call(d)
			var y := lerpf(y0, y1, v)
			var e := minf(minf(u, 1.0 - u) * dh * 0.2, minf(v, 1.0 - v) * maxf(y1 - y0, 0.001))
			var pd := lerpf(tuck, float(pad.call(d, y)), smoothstep(0.0, 0.0055, e))
			return P(ac + d, y, pd)
		var cc = func(u: float, v: float) -> Color:
			var d := (u - 0.5) * 2.0 * dh
			return cf.call(d, lerpf(float(b.call(d)), float(t.call(d)), v))
		sheet(nu, nv, fn, cc)
		backing(maxi(nu / 3, 6), maxi(nv / 3, 2), fn)

	## Panelin çevresini dolaşan kabarık kenar
	func bead(ac: float, dh: float, t: Callable, b: Callable, pad: float, w: float, col, n := 22) -> void:
		var pts := []
		for i in n + 1:
			var d := lerpf(-dh, dh, float(i) / n)
			pts.append(P(ac + d, t.call(d), pad))
		for i in range(1, n):
			var d := lerpf(dh, -dh, float(i) / n)
			pts.append(P(ac + d, b.call(d), pad))
		pts.append(pts[0])
		sweep(pts, w, w * 0.8, col, 5, Callable(), Vector3.ZERO, false)

	static func _cr3(p: Array, sub: int) -> Array:
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

	func _fp(q: Vector3, tent: bool) -> Vector3:
		return P(q.x, q.y, q.z) if tent else S(q.x, q.y, q.z)

	## Yüze yapışık şerit: pts = (a, y, pad); taper 1 = fırça darbesi
	func line(pts: Array, w: float, col, tent := true, taper := 0.0, sub := 4) -> void:
		var q := _cr3(pts, sub) if pts.size() > 2 else pts
		var n: int = q.size()
		var g := []
		for k in n:
			var t := float(k) / (n - 1)
			var c: Vector3 = _fp(q[k], tent)
			var c0: Vector3 = _fp(q[maxi(k - 1, 0)], tent)
			var c1: Vector3 = _fp(q[mini(k + 1, n - 1)], tent)
			var nr := c - Vector3(cx, c.y, cz)
			var sd := (c1 - c0).cross(nr).normalized()
			var ww := maxf(0.0003, w * 0.5 * lerpf(1.0, pow(sin(PI * t), 0.6), taper))
			g.append([c - sd * ww, c + nr.normalized() * ww * 0.25, c + sd * ww])
		grid(g, col, false, false, true, Vector3.ZERO, true)

	## Kesik çizgi dikiş
	func stitch(pts: Array, w: float, on: float, off: float, col, tent := true) -> void:
		var q := _cr3(pts, 8)
		var acc := 0.0
		var start := 0
		var drawing := true
		for k in range(1, q.size()):
			acc += _fp(q[k], tent).distance_to(_fp(q[k - 1], tent))
			if acc >= (on if drawing else off):
				if drawing:
					line([q[start], q[k]], w, col, tent)
				drawing = not drawing
				acc = 0.0
				start = k

	## Yol boyunca kesit süpürme. h: yüzeyden dışa (up yönü), w: yana. rf(t) kesit çarpanı
	func sweep(path: Array, w: float, h: float, col, sides := 8, rf := Callable(), up := Vector3.ZERO, cap := true, smooth := true) -> void:
		var n: int = path.size()
		var g := []
		var prev := Vector3.UP
		var mk = func(k: int, s: float) -> Array:
			var p: Vector3 = path[k]
			var tg: Vector3 = (path[mini(k + 1, n - 1)] - path[maxi(k - 1, 0)]).normalized()
			var u: Vector3 = up if up != Vector3.ZERO else (p - Vector3(cx, p.y, cz)).normalized()
			var nv: Vector3 = u - tg * u.dot(tg)
			if nv.length_squared() < 1e-5:
				nv = prev
			nv = nv.normalized()
			prev = nv
			var bv: Vector3 = tg.cross(nv)
			var ro := []
			for i in sides:
				var th := TAU * i / sides
				ro.append(p + nv * cos(th) * h * s + bv * sin(th) * w * s)
			return ro
		if cap:
			g.append(mk.call(0, 0.02))
		for k in n:
			g.append(mk.call(k, float(rf.call(float(k) / (n - 1))) if rf.is_valid() else 1.0))
		if cap:
			g.append(mk.call(n - 1, 0.02))
		grid(g, col, true, false, smooth)

	func basis(ax: Vector3) -> Array:
		var e1 := Vector3.UP.cross(ax)
		if e1.length_squared() < 1e-4:
			e1 = Vector3.RIGHT
		e1 = e1.normalized()
		return [e1, ax.cross(e1).normalized()]

	## Dönel parça: prof (r, h); cols tek renk ya da parça başına dizi; flute > 0 ise boyuna oluk
	func lathe(c: Vector3, ax: Vector3, prof: Array, cols, sides := 16, flute := 0, sq := 1.0) -> void:
		ax = ax.normalized()
		var eb := basis(ax)
		var g := []
		for q in prof:
			var ro := []
			for i in sides:
				var th := TAU * i / sides
				var r: float = q.x
				if flute > 0:
					r *= 1.0 - 0.09 * pow(0.5 + 0.5 * cos(th * flute), 4.0)
				ro.append(c + ax * q.y + eb[0] * cos(th) * r + eb[1] * sin(th) * r * sq)
			g.append(ro)
		var nseg: int = prof.size() - 1
		var cc = cols
		if cols is Array:
			cc = func(_u, v): return cols[clampi(int(v * nseg), 0, cols.size() - 1)]
		grid(g, cc, true, true, false)

	func bar(p: Vector3, x: Vector3, n: Vector3, sx: float, sy: float, sz: float, col: Color) -> void:
		x = x.normalized()
		n = (n - x * n.dot(x)).normalized()
		var y := n.cross(x)
		mb.add_xf("box", Transform3D(Basis(x * sx, y * sy, n * sz), p), col)

	func screw(p: Vector3, n: Vector3, r: float, col: Color, slot := true) -> void:
		n = n.normalized()
		lathe(p, n, [Vector2(r, -0.001), Vector2(r, r * 0.3), Vector2(r * 0.72, r * 0.62), Vector2(0.0001, r * 0.66)], col, 6)
		if slot:
			var e: Array = basis(n)
			bar(p + n * r * 0.62, e[0].rotated(n, 0.6), n, r * 1.5, r * 0.3, r * 0.14, col.darkened(0.65))

	func dot(p: Vector3, n: Vector3, r: float, col: Color) -> void:
		lathe(p, n, [Vector2(r, 0.0), Vector2(0.0001, 0.0005)], col, 6)

	## Filtre kutusu: oluklu gövde, vida bileziği, delikli kapak, yuvasına oturan boyun
	func canister(c: Vector3, ax: Vector3, r: float, h: float, body: Color, ringc: Color, capc: Color) -> void:
		ax = ax.normalized()
		lathe(c, ax, [Vector2(r * 0.72, -h * 0.34), Vector2(r * 0.72, -h * 0.02), Vector2(r * 0.94, 0.0), Vector2(r * 0.94, h * 0.1)], [ringc.darkened(0.3), ringc, ringc], 14)
		var pr := [Vector2(r * 0.94, h * 0.1), Vector2(r, h * 0.14), Vector2(r, h * 0.76), Vector2(r * 0.96, h * 0.8)]
		lathe(c, ax, pr, [body.darkened(0.12), body, body.darkened(0.2)], 24, 8)
		lathe(c, ax, [Vector2(r * 1.04, h * 0.8), Vector2(r * 1.06, h * 0.84), Vector2(r * 1.06, h * 0.94), Vector2(r * 0.98, h), Vector2(r * 0.76, h), Vector2(r * 0.72, h * 0.965), Vector2(0.0001, h * 0.965)], [ringc, ringc.lightened(0.1), ringc, ringc.lightened(0.18), ringc.darkened(0.3), capc], 20)
		var eb := basis(ax)
		var tip := c + ax * (h * 0.965 + 0.0002)
		dot(tip, ax, r * 0.1, INK)
		for ri in 2:
			var cnt := 5 if ri == 0 else 9
			var rr := r * (0.3 if ri == 0 else 0.56)
			for i in cnt:
				var th := TAU * i / cnt + ri * 0.2
				dot(tip + eb[0] * cos(th) * rr + eb[1] * sin(th) * rr, ax, r * 0.075, INK)
		for i in 4:
			var th := TAU * (i + 0.5) / 4.0
			var q: Vector3 = c + ax * h * 0.985 + (eb[0] * cos(th) + eb[1] * sin(th)) * r * 0.88
			screw(q, ax, r * 0.1, STEEL.lightened(0.15))

	## Boğumlu hortum
	func hose(path: Array, r: float, a: Color, b: Color, ribs := 16) -> void:
		var q := _cr3(path, 5)
		var rf = func(t: float) -> float: return 0.86 + 0.14 * abs(sin(t * PI * ribs))
		var cc = func(_u, v): return a if fmod(v * ribs, 1.0) < 0.5 else b
		sweep(q, r, r, cc, 6, rf, Vector3.ZERO, true, false)

	## Başı dolanan kayış: yol (a, y) -> yüzey + pad
	func strap(a0: float, a1: float, yf: Callable, pad: float, w: float, h: float, col, n := 40) -> void:
		var pts := []
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			var y: float = yf.call(a)
			pts.append(at(a, y, float(m.face_r(a, y)) + pad))
		sweep(pts, w, h, col, 6)

	## Bir yükseklik dilimindeki saçı kayışın altına bastır
	func hair_cut(y: float, h: float, pad := 0.003) -> void:
		var rl: float = m.face_r(0.0, y)
		var rr: float = m.face_r(PI, y)
		var rf: float = m.face_r(F, y)
		var rb: float = m.face_r(-F, y)
		post.append(["slab", y - h * 0.5, y + h * 0.5, Vector2(cx, cz + (rf - rb) * 0.5), minf(rl, rr) + pad, (rf + rb) * 0.5 + pad])

	func dangle(root: Vector3, dir: Vector3, length: float, w: float, col: Color, stiff := 0.18, thick := 0.003) -> void:
		post.append(["dangle", root, dir, length, w, col, stiff, thick])

	## Yüze değen göz yuvası çerçevesi: yüzey konumu + düzlem
	func cup_frame(a: float, y: float, rx: float, ry: float, pw: float, ax: Vector3, pad := 0.0) -> Dictionary:
		ax = ax.normalized()
		var eb := basis(ax)
		return {"c": S(a, y, pad), "e1": eb[0], "e2": eb[1], "ax": ax, "rx": rx, "ry": ry, "pw": pw}

	func _sq(th: float, pw: float) -> Vector2:
		var c := cos(th)
		var s := sin(th)
		return Vector2(sign(c) * pow(absf(c), 2.0 / pw), sign(s) * pow(absf(s), 2.0 / pw))

	## Satırlar: [ölçek, öne çıkış, düzlemsellik 0..1, renk]
	func cup(l: Dictionary, rows: Array, sides := 28) -> void:
		var g := []
		for ro in rows:
			var line_pts := []
			for i in sides:
				var q: Vector2 = _sq(TAU * i / sides, l["pw"])
				var f: Vector3 = l["c"] + l["e1"] * q.x * l["rx"] * ro[0] + l["e2"] * q.y * l["ry"] * ro[0]
				var a := atan2(f.z - cz, f.x - cx)
				var skin: Vector3 = S(a, f.y, -0.001)
				line_pts.append(skin.lerp(f, ro[2]) + l["ax"] * ro[1])
			g.append(line_pts)
		var cc = func(_u, v): return rows[clampi(int(v * (rows.size() - 1)), 0, rows.size() - 2)][3]
		grid(g, cc, true, true, false)

	func lpt(l: Dictionary, x: float, y: float, off: float) -> Vector3:
		return l["c"] + l["e1"] * x * l["rx"] + l["e2"] * y * l["ry"] + l["ax"] * off

	## Kubbeli cam: alt-üst renk geçişli
	func lens(l: Dictionary, off: float, dome: float, top: Color, bot: Color, s := 0.94, sides := 28) -> void:
		var g := []
		for j in 5:
			var rho := 1.0 - j / 4.0
			var ro := []
			for i in sides:
				var q: Vector2 = _sq(TAU * i / sides, l["pw"]) * rho * s
				ro.append(lpt(l, q.x, q.y, off + dome * (1.0 - rho * rho)))
			g.append(ro)
		var cc = func(_u, v): return bot.lerp(top, v * 0.4 + 0.3)
		grid(g, cc, true, false, true, l["ax"])

	## Cam üzerinde eğik parıltı şeridi (s0..s1: -1..1 arası)
	func glint(l: Dictionary, off: float, s0: float, s1: float, col := GLINT, dome := 0.0, y0 := -0.86, y1 := 0.86) -> void:
		var g := []
		for j in 7:
			var y := lerpf(y0, y1, j / 6.0)
			var xh := 0.9 * pow(maxf(0.0, 1.0 - pow(absf(y), l["pw"])), 1.0 / float(l["pw"]))
			var x0 := clampf(s0 - y * 0.55, -xh, xh)
			var x1 := clampf(s1 - y * 0.55, -xh, xh)
			var ro := []
			for x in [x0, x1]:
				var r2: float = minf(1.0, x * x + y * y)
				ro.append(lpt(l, x, y, off + dome * (1.0 - r2) + 0.0007))
			g.append(ro)
		grid(g, col, false, false, true, l["ax"])

	## Göz açıklığının yarı yüksekliği (a yönünde)
	func eye_h(a: float, h := 0.0155, w := 0.22) -> float:
		var e := 0.0
		for c in [ar, al]:
			var g: float = absf(wrapf(a - c, -PI, PI)) / w
			if g < 1.0:
				e = maxf(e, h * sqrt(1.0 - g * g))
		return e


## ---------------------------------------------------------------- bez parçalar

static func _cloth(k: Y, fg: Color) -> void:
	var top = func(a: float) -> float:
		var d: float = absf(wrapf(a - F, -PI, PI))
		return k.nose + 0.011 - 0.021 * smoothstep(0.16, 1.2, d) - 0.012 * smoothstep(1.3, 2.6, d)
	var fold = func(a: float, y: float) -> float:
		var d: float = wrapf(a - F, -PI, PI)
		var ny: float = clampf((y - k.neck) / (k.chin - k.neck), 0.0, 1.0)
		var f: float = sin(ny * PI * 3.2 + d * 1.1 + sin(d * 3.0) * 0.7) * (1.0 - ny) * 0.0024   # boyun kırışıkları
		var cheek: float = G(y - (k.ey - 0.075), 0.035) * smoothstep(0.1, 0.5, absf(d)) * (1.0 - smoothstep(1.2, 1.7, absf(d)))
		f += sin(absf(d) * 11.0 + (y - k.chin) * 75.0) * 0.0009 * cheek   # burundan yanağa gerilim çizgileri
		f += sin(absf(d) * 6.0 - (y - k.chin) * 110.0) * 0.0009 * G(y - k.chin, 0.018) * (1.0 - smoothstep(0.7, 1.2, absf(d)))
		return f
	var HEM := 0.86
	var loc = func(u: float, v: float) -> Vector3:
		var a: float = F + (u - 0.5) * TAU
		var t: float = top.call(a)
		if v < HEM:
			return Vector3(a, lerpf(k.neck - 0.03, t - 0.0125, v / HEM), 1.0)
		return Vector3(a, lerpf(t - 0.0125, t, (v - HEM) / (1.0 - HEM)), 0.0)
	var fn = func(u: float, v: float) -> Vector3:
		var q: Vector3 = loc.call(u, v)
		var pad := 0.0052 + float(fold.call(q.x, q.y)) * q.z
		if v >= HEM:
			var w: float = (v - HEM) / (1.0 - HEM)
			pad = lerpf(0.0052, 0.0075, sin(minf(w * 1.25, 1.0) * PI * 0.5)) if w < 0.8 else lerpf(0.0075, 0.0005, (w - 0.8) / 0.2)
		return k.P(q.x, q.y, pad)
	var cc = func(u: float, v: float) -> Color:
		var q: Vector3 = loc.call(u, v)
		if v >= HEM:
			return fg.lightened(0.05) if v < 0.97 else fg.darkened(0.3)
		var f: float = float(fold.call(q.x, q.y)) / 0.0026
		var c: Color = fg.darkened(clampf(-f * 0.3, 0.0, 0.3)) if f < 0.0 else fg.lightened(clampf(f * 0.1, 0.0, 0.1))
		return c.darkened(0.2) if v > HEM - 0.018 else c
	k.sheet(72, 22, fn, cc, true)
	var sc := fg.lightened(0.28) if fg.get_luminance() < 0.4 else fg.darkened(0.3)
	var hem := []
	for i in 73:
		var a: float = F + (i / 72.0 - 0.5) * TAU
		hem.append(Vector3(a, float(top.call(a)) - 0.0078, 0.0086))
	k.stitch(hem, 0.0011, 0.0042, 0.0028, sc)
	for s: float in [-1.0, 1.0]:   # yan dikiş: kulak altından boyna
		var d: float = 1.42 * s
		var y1: float = float(top.call(F + d)) - 0.016
		k.line([Vector3(F + d, y1, 0.0058), Vector3(F + d + 0.03 * s, k.chin, 0.0062), Vector3(F + d + 0.05 * s, k.neck + 0.002, 0.0062)], 0.0013, fg.darkened(0.4))
		k.stitch([Vector3(F + d - 0.05 * s, y1, 0.0064), Vector3(F + d - 0.02 * s, k.chin, 0.0068), Vector3(F + d, k.neck + 0.004, 0.0068)], 0.001, 0.0035, 0.003, sc)


static func _pece(k: Y, fg: Color) -> void:
	var DH := 1.34
	var top = func(d: float) -> float: return k.nose + 0.006 - 0.02 * smoothstep(0.12, 1.3, absf(d))
	var bot = func(d: float) -> float:
		var t: float = cos(clampf(d / DH, -1.0, 1.0) * F)
		return k.ey - 0.07 - 0.095 * pow(t, 1.5)
	var pleat = func(d: float, dep: float) -> float: return (sin(d * 15.0 + dep * 3.0) * 0.6 + sin(d * 7.0 - dep * 2.0) * 0.4) * dep
	var fn = func(u: float, v: float) -> Vector3:
		var d: float = (u - 0.5) * 2.0 * DH
		var y: float = lerpf(bot.call(d), top.call(d), v)
		var dep: float = clampf((k.chin + 0.03 - y) / 0.09, 0.0, 1.0)
		var e: float = smoothstep(0.0, 0.06, minf(u, 1.0 - u))
		var pad: float = 0.0058 + dep * dep * 0.03 + float(pleat.call(d, dep)) * 0.0042 + 0.0014 * sin(v * 26.0) * (1.0 - dep) * 0.5
		if v > 0.93:
			pad = lerpf(pad + 0.002, 0.0008, (v - 0.93) / 0.07)
		return k.P(F + d, y, lerpf(0.001, pad, e))
	var bord := fg.darkened(0.34)
	var cc = func(u: float, v: float) -> Color:
		var d: float = (u - 0.5) * 2.0 * DH
		var y: float = lerpf(bot.call(d), top.call(d), v)
		var dep: float = clampf((k.chin + 0.03 - y) / 0.09, 0.0, 1.0)
		var f: float = pleat.call(d, dep)
		var c: Color = fg.darkened(clampf(-f * 0.3, 0.0, 0.3)) if f < 0.0 else fg.lightened(f * 0.08)
		if (v > 0.035 and v < 0.06) or (v > 0.085 and v < 0.1) or (v > 0.86 and v < 0.885):
			return bord   # dokuma kenar şeritleri
		return c
	k.sheet(48, 28, fn, cc, false, false)
	k.backing(16, 8, fn, fg.darkened(0.55))
	var by := k.ey - 0.056
	var byf = func(a: float) -> float: return by + 0.006 * sin(a) + 0.003
	for s: float in [-1.0, 1.0]:   # arkaya bağ
		k.strap(F + DH * s * 0.97, F + PI * s * 0.98, byf, 0.0055, 0.0075, 0.002, fg.darkened(0.14), 22)
	var kp: Vector3 = k.S(-F, by - 0.004, 0.012)
	k.lathe(kp, Vector3(0, 0, -1), [Vector2(0.0001, -0.009), Vector2(0.008, -0.006), Vector2(0.0105, 0.0), Vector2(0.008, 0.006), Vector2(0.0001, 0.009)], fg.darkened(0.2), 10)
	for s: float in [-1.0, 1.0]:
		k.dangle(kp + Vector3(0.004 * s, -0.004, -0.004), Vector3(0.28 * s, -1.0, -0.3), 0.15 + s * 0.015, 0.03, fg.darkened(0.08), 0.15)
	var hm := []
	for i in 29:
		var d: float = lerpf(-DH * 0.92, DH * 0.92, i / 28.0)
		hm.append(Vector3(F + d, float(top.call(d)) - 0.0065, 0.0084))
	k.stitch(hm, 0.001, 0.004, 0.003, fg.lightened(0.32))


static func _yuksek_pece(k: Y, fg: Color) -> void:
	# yüksek yaka (ref: Aburame): burna kadar çıkan, ağzı dışa açılan sert huni; önde fermuar
	var top = func(a: float) -> float:
		var d: float = absf(wrapf(a - F, -PI, PI))
		return k.nose - 0.002 - 0.012 * smoothstep(0.0, 1.0, d) + 0.016 * smoothstep(1.2, 3.0, d)
	var ybot := k.neck - 0.05
	var flare = func(v: float) -> float: return 0.012 + 0.024 * v * v + 0.008 * pow(v, 6.0)
	var fn = func(u: float, v: float) -> Vector3:
		var a: float = F + (u - 0.5) * TAU
		var t: float = top.call(a)
		if v < 0.74:
			var w: float = v / 0.74
			return k.P(a, lerpf(ybot, t, w), float(flare.call(w)))
		if v < 0.84:   # yuvarlak üst kenar
			var th: float = (v - 0.74) / 0.10 * PI
			return k.P(a, t + sin(th) * 0.0046, float(flare.call(1.0)) - (1.0 - cos(th)) * 0.0046)
		var w: float = (v - 0.84) / 0.16   # içe inen astar
		return k.P(a, t - w * 0.05, lerpf(float(flare.call(1.0)) - 0.0092, 0.0015, w))
	var inner := fg.darkened(0.62)
	var cc = func(u: float, v: float) -> Color:
		var d: float = wrapf((u - 0.5) * TAU, -PI, PI)
		if v > 0.83:
			return inner
		if v > 0.70:
			return fg.lightened(0.07)
		var c: Color = fg.darkened(0.1 * (0.5 + 0.5 * sin(d * 5.0 + v * 2.0)))
		var fa: float = fmod(v * 0.74 * 7.0, 1.0)
		return c.darkened(0.2) if fa < 0.04 else c   # yatay dikiş sıraları
	k.sheet(60, 28, fn, cc, true, false)
	# fermuar
	var col_pt = func(d: float, y: float, pad: float) -> Vector3:
		var a: float = F + d
		var t: float = top.call(a)
		var w: float = clampf((y - ybot) / (t - ybot), 0.0, 1.0)
		return k.P(a, y, float(flare.call(w)) + pad)
	var yt: float = float(top.call(F)) - 0.002
	var n := 22
	for s: float in [-1.0, 1.0]:
		var pts := []
		for i in 9:
			pts.append(col_pt.call(s * 0.036, lerpf(ybot + 0.005, yt, i / 8.0), 0.0008))
		k.sweep(pts, 0.0028, 0.0012, fg.darkened(0.48), 4)
	var zc := LINEN.darkened(0.08)
	for i in n:
		var y: float = lerpf(ybot + 0.006, yt - 0.003, float(i) / (n - 1))
		var p: Vector3 = col_pt.call(0.012 if i % 2 == 0 else -0.012, y, 0.0015)
		k.bar(p, Vector3.RIGHT, Vector3(0, 0, 1), 0.0062, 0.0019, 0.0016, zc)
	var zp: Vector3 = col_pt.call(0.0, yt - 0.012, 0.004)
	k.bar(zp, Vector3.RIGHT, Vector3(0, 0, 1), 0.0074, 0.0085, 0.0034, STEEL)
	k.bar(zp + Vector3(0, -0.0105, 0.0012), Vector3.RIGHT, Vector3(0, 0.25, 1), 0.0042, 0.0135, 0.0014, STEEL.darkened(0.12))


## Sargı turu. yf(a) merkez, hw yarı genişlik
static func _strip(k: Y, a0: float, a1: float, yf: Callable, hw: float, pad: float, c: Color, na := 48, closed := false) -> void:
	var fn = func(u: float, v: float) -> Vector3:
		var a: float = lerpf(a0, a1, u)
		var pr: float = sin(v * PI)
		return k.P(a, float(yf.call(a)) + (v - 0.5) * 2.0 * hw, pad - 0.0016 + 0.0034 * pow(pr, 0.6))
	var cc = func(u: float, v: float) -> Color:
		var pr: float = sin(v * PI)
		var o: Color = c.darkened(0.2 * (1.0 - pr) + 0.05 * (0.5 + 0.5 * sin(u * 83.0)))
		return o.darkened(0.08) if absf(v - 0.33) < 0.05 or absf(v - 0.67) < 0.05 else o
	k.sheet(na, 4, fn, cc, closed)


static func _wrap_y(y: float, s: float, ph: float) -> Callable:
	return func(a: float) -> float: return y + s * 0.0065 * cos(a) + 0.0016 * sin(a * 3.0 + ph)


static func _bandaj(k: Y, fg: Color, full: bool) -> void:
	var bc := LINEN if fg.get_luminance() < 0.35 else fg
	var hw := 0.0118
	var i := 0
	var ytop: float = k.nose + 0.006
	var y := k.neck - 0.02
	var step := 0.0165
	while y < ytop - 0.002:
		var s := 1.0 if i % 2 == 0 else -1.0
		if not full or y < k.ey - 0.04:
			_strip(k, F - PI, F + PI, _wrap_y(y, s, i * 1.7), hw, 0.0045 + 0.0016 * (i % 2), bc.darkened(0.035 * (i % 3)), 44, false)
		y += step
		i += 1
	if not full:
		# burnun üstündeki son tur: yanlara inen üst kenar
		var yt = func(a: float) -> float:
			var d: float = absf(wrapf(a - F, -PI, PI))
			return k.nose + 0.002 - 0.018 * smoothstep(0.25, 1.3, d)
		_strip(k, F - PI, F + PI, yt, hw, 0.0072, bc, 44)
	else:
		var lid_h := 0.0245
		for sg: float in [-1.0, 1.0]:   # göz açıklığını çevreleyen üst / alt turlar
			var fn = func(u: float, v: float) -> Vector3:
				var a: float = F + (u - 0.5) * TAU
				var e: float = k.ey + sg * k.eye_h(a)
				var yy: float = lerpf(e, k.ey + sg * lid_h, v)
				return k.S(a, yy, 0.0035 + 0.0034 * sin(minf(v * 1.2, 1.0) * PI) if v < 0.9 else 0.004)
			var cc = func(_u: float, v: float) -> Color: return bc.darkened(0.3 * (1.0 - smoothstep(0.0, 0.28, v)) + 0.04)
			k.sheet(64, 4, fn, cc, true)
		var ys := [k.ey + 0.036, k.ey + 0.054, k.ey + 0.072, k.ey + 0.088]
		for j in ys.size():
			var s := 1.0 if j % 2 == 0 else -1.0
			_strip(k, F - PI, F + PI, _wrap_y(ys[j], s, j * 2.3), hw, 0.0155 + 0.0014 * (j % 2), bc.darkened(0.03 * (j % 3)), 40)
		# alnı çapraz geçen iki tur
		var dg = func(a: float) -> float: return k.ey + 0.054 + 0.042 * sin(wrapf(a - F, -PI, PI) * 0.5)
		_strip(k, F - 1.5, F + 1.5, dg, hw * 0.9, 0.0195, bc.lightened(0.04), 24)
		k.hair_cut(k.ey + 0.02, 0.26, 0.014)
	var tail: Vector3 = k.P(-F + 0.35, k.neck + 0.03, 0.008)
	k.dangle(tail, Vector3(0.1, -1.0, -0.3), 0.11, 0.021, bc.darkened(0.06), 0.15)
	k.dangle(tail + Vector3(-0.008, 0.006, 0), Vector3(-0.2, -1.0, -0.25), 0.075, 0.017, bc.darkened(0.12), 0.15)


## ---------------------------------------------------------------- sert maske gövdeleri

static func _head_strap(k: Y, y: float, a_front: float, pad: float, w: float, c: Color) -> void:
	var yf = func(_a: float) -> float: return y
	k.strap(F + a_front, F + PI, yf, pad, w, 0.0016, c, 26)
	k.strap(F - a_front, F - PI, yf, pad, w, 0.0016, c, 26)
	k.hair_cut(y, w * 2.0 + 0.006)


## Kayış bağlantısı: pirinç toka + perçin
static func _buckle(k: Y, a: float, y: float, pad: float, col: Color) -> void:
	var p: Vector3 = k.S(a, y, pad)
	var n: Vector3 = k.O(a)
	var t := n.cross(Vector3.UP).normalized()
	for s: float in [-1.0, 1.0]:
		k.bar(p + t * 0.0085 * s, Vector3.UP, n, 0.018, 0.0024, 0.002, col)
		k.bar(p + Vector3.UP * 0.0085 * s, t, n, 0.019, 0.0024, 0.002, col)
	k.bar(p, Vector3.UP, n + t * 0.0, 0.0145, 0.0016, 0.0028, col.lightened(0.15))


static func _gas(k: Y, fg: Color) -> void:
	var rub := fg.lerp(RUBBER, 0.25)
	var t = func(d: float) -> float: return k.nose + 0.01 - 0.026 * smoothstep(0.1, 1.05, absf(d))
	var b = func(d: float) -> float: return k.chin - 0.015 + 0.05 * smoothstep(0.55, 1.15, absf(d))
	var pad = func(d: float, y: float) -> float:
		var my: float = y - (k.ey - 0.08)
		return 0.0075 + 0.012 * G(d, 0.52) * G(my, 0.042) + 0.0012 * sin((y - k.chin) * 170.0) * G(absf(d) - 0.82, 0.16)
	var col = func(d: float, y: float) -> Color:
		var c: Color = rub.lightened(0.07 * G(d, 0.42) * G(y - (k.ey - 0.07), 0.03))
		return c.darkened(0.25) if fmod((y - k.chin) * 54.0 + 20.0, 1.0) < 0.2 and absf(d) > 0.68 else c
	k.panel(F, 1.12, t, b, pad, col, 32, 12)
	k.bead(F, 1.12, t, b, 0.0048, 0.0028, rub.darkened(0.3), 20)
	var ring := DSTEEL
	for s: float in [-1.0, 1.0]:
		var a: float = F + s * 0.66
		var y := k.ey - 0.086
		var c: Vector3 = k.P(a, y, 0.013)
		var ax := (k.O(a) * 0.82 + Vector3(0, -0.5, 0)).normalized()
		k.canister(c, ax, 0.0255, 0.043, fg.lerp(Color(0.46, 0.48, 0.42), 0.8), ring, Color(0.17, 0.18, 0.17))
		# kayış bağlantısı
		var d2: float = 1.02
		_buckle(k, F + s * d2, k.ey - 0.052, 0.0095, STEEL)
		_buckle(k, F + s * d2, k.ey - 0.092, 0.009, STEEL)
	# orta valf
	var v: Vector3 = k.P(F, k.ey - 0.097, 0.015)
	var vax := Vector3(0, -0.42, 1).normalized()
	k.lathe(v, vax, [Vector2(0.0205, -0.008), Vector2(0.0205, 0.002), Vector2(0.018, 0.005), Vector2(0.0155, 0.006), Vector2(0.0155, 0.014), Vector2(0.0125, 0.0165), Vector2(0.0001, 0.0165)], [ring, ring.lightened(0.1), ring.darkened(0.25), Color(0.25, 0.26, 0.26), Color(0.3, 0.31, 0.3), Color(0.2, 0.2, 0.2)], 18)
	var eb: Array = k.basis(vax)
	for i in 3:
		k.bar(v + vax * 0.0168 + eb[1] * (i - 1) * 0.0058, eb[0], vax, 0.0145, 0.0022, 0.0009, INK)
	for i in 6:
		var th := TAU * i / 6.0 + 0.5
		k.screw(v + vax * 0.003 + (eb[0] * cos(th) + eb[1] * sin(th)) * 0.0178, vax, 0.0016, STEEL, false)
	# hortum: valften çene altından boyna, kayışa kelepçe
	var h := [v + vax * 0.002 + Vector3(0.012, -0.01, 0.0), k.P(F - 0.4, k.chin - 0.035, 0.014), k.P(F - 1.05, k.neck + 0.006, 0.016), k.P(F - 1.75, k.neck + 0.002, 0.012), k.P(F - 2.25, k.neck + 0.012, 0.007)]
	k.hose(h, 0.0064, Color(0.09, 0.09, 0.1), Color(0.19, 0.19, 0.21), 26)
	var e: Vector3 = h[4]
	k.lathe(e, k.O(F - 2.25), [Vector2(0.0085, -0.005), Vector2(0.0085, 0.004), Vector2(0.0001, 0.005)], ring, 8)
	var yt := k.ey - 0.052
	var yb := k.ey - 0.092
	_head_strap(k, yt, 1.06, 0.0042, 0.0058, Color(0.16, 0.16, 0.17))
	var ybf = func(a: float) -> float: return lerpf(yb, k.neck + 0.03, smoothstep(0.0, 1.6, absf(wrapf(a - F, -PI, PI)) - 1.0))
	k.strap(F + 1.06, F + PI, ybf, 0.0042, 0.0058, 0.0016, Color(0.16, 0.16, 0.17), 24)
	k.strap(F - 1.06, F - PI, ybf, 0.0042, 0.0058, 0.0016, Color(0.16, 0.16, 0.17), 24)


## Göz çevresini saran bez: üst/alt iki şerit ortada göz yarığı bırakır (kaynak: Ame solunum maskesi)
static func _eye_wrap(k: Y, c: Color, up: float, dn: float, ih := 0.0155) -> void:
	for sg: float in [-1.0, 1.0]:
		var edge: float = up if sg > 0.0 else dn
		var fn = func(u: float, v: float) -> Vector3:
			var a: float = F + (u - 0.5) * TAU
			var d: float = absf(wrapf(a - F, -PI, PI))
			var e: float = k.ey + sg * k.eye_h(a, ih)
			var yy: float = lerpf(e, k.ey + sg * edge - sg * 0.004 * smoothstep(1.2, 2.4, d), v)
			var pr: float = sin(minf(v * 1.15, 1.0) * PI)
			return k.S(a, yy, 0.0026 + 0.0036 * pr)
		var cc = func(u: float, v: float) -> Color:
			var o: Color = c.darkened(0.16 * smoothstep(0.84, 1.0, v))
			return INK.lerp(o, smoothstep(0.03, 0.14, v)) if k.eye_h(F + (u - 0.5) * TAU, ih) > 0.0005 else o
		k.sheet(52, 4, fn, cc, true)


static func _gaz_maskesi(k: Y, fg: Color) -> void:
	# Ame tipi (ref yy_oboro): gözleri saran beyaz bez + sekizgen çelik solunum ağzı, dikey yarıklar, yanda asılı filtre
	_eye_wrap(k, Color(0.92, 0.91, 0.87), 0.031, 0.031)
	var back := fg.lerp(RUBBER, 0.6)
	var bt = func(d: float) -> float: return k.ey - 0.03 - 0.018 * smoothstep(0.2, 1.3, absf(d))
	var bb = func(d: float) -> float: return k.chin - 0.004 + 0.052 * smoothstep(0.5, 1.3, absf(d))
	k.panel(F, 1.3, bt, bb, func(_d, _y): return 0.0052, back, 30, 8)
	var octo = func(d: float) -> float: return 1.0 - smoothstep(0.34, 0.66, absf(d))
	var t = func(d: float) -> float: return k.ey - 0.05 - 0.016 * (1.0 - float(octo.call(d)))
	var b = func(d: float) -> float: return k.chin - 0.024 + 0.04 * (1.0 - float(octo.call(d)))
	var sc := Color(0.5, 0.51, 0.56)
	var pad = func(d: float, y: float) -> float: return 0.018 + 0.006 * G(d, 0.3) * G(y - (k.ey - 0.092), 0.03)
	var col = func(d: float, y: float) -> Color:
		var yt: float = t.call(d)
		var yb: float = b.call(d)
		var e: float = minf(yt - y, y - yb)
		return sc.lightened(0.16) if e < 0.0035 else sc.darkened(0.08 * (1.0 - (y - yb) / maxf(yt - yb, 0.001)))
	k.panel(F, 0.68, t, b, pad, col, 30, 16, 0.004)
	k.bead(F, 0.68, t, b, 0.0058, 0.0024, sc.darkened(0.4), 18)
	for i in 4:   # dikey nefes yarıkları
		var d: float = (i - 1.5) * 0.135
		var yt: float = k.ey - 0.067
		var yb: float = k.chin + 0.0
		var pts := []
		for j in 5:
			var y: float = lerpf(yb, yt, j / 4.0)
			pts.append(k.P(F + d, y, float(pad.call(d, y)) + 0.0004))
		k.sweep(pts, 0.0052, 0.0009, INK, 6)
	var s := -1.0
	var c: Vector3 = k.P(F + s * 0.56, k.ey - 0.112, 0.017)
	var ax := Vector3(s * -0.34, -0.9, 0.3).normalized()
	k.canister(c, ax, 0.0118, 0.036, Color(0.42, 0.43, 0.47), DSTEEL, Color(0.2, 0.2, 0.22))
	for q in [[-0.44, -0.058], [0.44, -0.058], [-0.57, -0.1], [0.57, -0.1]]:
		var p: Vector3 = k.P(F + q[0], k.ey + q[1], float(pad.call(q[0], k.ey + q[1])) - 0.0036)
		k.screw(p, k.O(F + q[0]), 0.0026, STEEL.lightened(0.1))
	_head_strap(k, k.ey - 0.046, 1.26, 0.0042, 0.0062, back.darkened(0.2))


static func _solunum(k: Y, _fg: Color) -> void:
	# samuray aparatı (ref yy_hanzo): ağız körüğü, iki yanda yanaktan şakağa çıkan hortum, kırmızı kapaklı dik tüpler
	var sc := Color(0.4, 0.42, 0.46)
	var t = func(d: float) -> float: return k.ey - 0.05 - 0.02 * smoothstep(0.1, 0.72, absf(d))
	var b = func(d: float) -> float: return k.chin - 0.016 + 0.042 * smoothstep(0.3, 0.78, absf(d))
	var pad = func(d: float, y: float) -> float: return 0.0085 + 0.0115 * G(d, 0.4) * G(y - (k.ey - 0.085), 0.034)
	var col = func(d: float, y: float) -> Color:
		var yy: float = fmod((y - k.chin + 0.04) * 95.0, 1.0)
		return sc.darkened(0.22) if absf(d) > 0.36 and yy < 0.2 else sc.lightened(0.05 * G(d, 0.3))
	k.panel(F, 0.8, t, b, pad, col, 30, 16)
	k.bead(F, 0.8, t, b, 0.006, 0.0026, sc.darkened(0.45), 18)
	var v: Vector3 = k.P(F, k.ey - 0.09, 0.0165)
	var vax := Vector3(0, -0.14, 1).normalized()
	var e: Array = k.basis(vax)
	k.lathe(v, vax, [Vector2(0.0225, -0.004), Vector2(0.0225, 0.004), Vector2(0.0195, 0.007), Vector2(0.0165, 0.007), Vector2(0.0165, 0.0115), Vector2(0.0001, 0.0125)], [DSTEEL, DSTEEL.lightened(0.14), DSTEEL.darkened(0.3), sc, sc.lightened(0.1)], 8, 0, 0.8)
	for i in 3:   # dikey nefes yarıkları
		k.bar(v + vax * 0.0128 + e[0] * (i - 1) * 0.008, e[1], vax, 0.0165, 0.0034, 0.0009, INK)
	var red := Color(0.7, 0.13, 0.12)
	for s: float in [-1.0, 1.0]:
		var d0: float = 0.72
		var a := F + s * 1.0
		var cb: Vector3 = k.S(a, k.ey - 0.042, 0.021)
		var ax := Vector3(k.O(a).x * 0.18, 1.0, k.O(a).z * 0.1).normalized()
		var c0: Vector3 = k.P(F + s * d0, k.ey - 0.088, 0.008)
		k.hose([c0, k.P(F + s * 0.86, k.ey - 0.09, 0.0125), k.P(F + s * 1.0, k.ey - 0.074, 0.0165), cb - ax * 0.003], 0.0058, Color(0.14, 0.14, 0.16), Color(0.33, 0.34, 0.38), 12)
		k.lathe(c0, k.O(F + s * d0), [Vector2(0.0092, -0.004), Vector2(0.0092, 0.005), Vector2(0.007, 0.0065), Vector2(0.0001, 0.0066)], DSTEEL, 10)
		k.lathe(cb, ax, [Vector2(0.0001, -0.005), Vector2(0.0085, -0.003), Vector2(0.0105, 0.0), Vector2(0.0105, 0.004), Vector2(0.0098, 0.0048), Vector2(0.0098, 0.032), Vector2(0.0108, 0.033), Vector2(0.0108, 0.038)], [DSTEEL, DSTEEL, DSTEEL.lightened(0.15), DSTEEL.darkened(0.3), Color(0.5, 0.52, 0.56), DSTEEL.darkened(0.3), DSTEEL.lightened(0.15)], 14)
		k.lathe(cb + ax * 0.038, ax, [Vector2(0.0108, 0.0), Vector2(0.0114, 0.002), Vector2(0.0114, 0.013), Vector2(0.0092, 0.0165), Vector2(0.0001, 0.018)], [red.darkened(0.3), red, red.lightened(0.12), red.lightened(0.2)], 14)
		# tüp kelepçesi: tüpten yüze
		var cl: Vector3 = cb + ax * 0.018
		var to: Vector3 = k.S(a, cl.y, 0.002)
		k.bar((cl + to) * 0.5, cl - to, k.O(a).cross(Vector3.UP), cl.distance_to(to) + 0.006, 0.0075, 0.0028, DSTEEL)
		k.lathe(cb + ax * 0.016, ax, [Vector2(0.0118, 0.0), Vector2(0.0118, 0.0052)], Color(0.2, 0.2, 0.23), 14)
	_head_strap(k, k.ey - 0.024, 1.0, 0.0042, 0.006, Color(0.17, 0.16, 0.17))
	var low = func(a: float) -> float: return lerpf(k.ey - 0.082, k.neck + 0.03, smoothstep(0.0, 1.5, absf(wrapf(a - F, -PI, PI)) - 0.75))
	k.strap(F + 0.76, F + PI, low, 0.004, 0.0055, 0.0016, Color(0.17, 0.16, 0.17), 22)
	k.strap(F - 0.76, F - PI, low, 0.004, 0.0055, 0.0016, Color(0.17, 0.16, 0.17), 22)


static func _mempo(k: Y, fg: Color) -> void:
	var gold := BRASS
	var cord := Color(0.82, 0.38, 0.12)
	var t = func(d: float) -> float:
		var e: float = absf(d)
		return k.ey - 0.044 + 0.0 * e + 0.014 * smoothstep(0.34, 0.86, e) - 0.04 * smoothstep(0.95, 1.32, e) - 0.012 * G(d, 0.2)
	var b = func(d: float) -> float: return k.chin - 0.014 + 0.016 * smoothstep(0.2, 0.75, absf(d)) + 0.04 * smoothstep(0.8, 1.32, absf(d))
	var pad = func(d: float, y: float) -> float:
		var e: float = absf(d)
		var mouth: float = y - (k.ey - 0.086)
		return 0.0095 + 0.0075 * G(e - 0.62, 0.2) * G(y - (k.ey - 0.064), 0.024) + 0.0065 * G(d, 0.26) * G(y - (k.chin - 0.004), 0.018) - 0.0042 * G(d, 0.42) * G(mouth, 0.008) + 0.003 * G(d, 0.4) * G(mouth - 0.012, 0.008)
	var col = func(d: float, y: float) -> Color:
		var h: float = float(pad.call(d, y)) / 0.0165
		var ln: float = absf(fmod(absf(d) + 0.5, 0.26) - 0.13)   # plaka birleşimleri
		var c: Color = fg.darkened(0.16 * (1.0 - clampf(h, 0.0, 1.0))).lightened(0.13 * smoothstep(0.82, 1.1, h))
		return c.darkened(0.42) if absf(d) > 0.42 and ln < 0.008 else c
	k.panel(F, 1.33, t, b, pad, col, 38, 14)
	k.bead(F, 1.33, t, b, 0.0062, 0.0021, gold, 22)
	# ağız yarığı ve dişler
	var my := k.ey - 0.087
	var smile = func(d: float) -> float: return my + 0.012 * d * d / 0.16 - 0.004 * d * d
	var mo := []
	for i in 13:
		var d := lerpf(-0.42, 0.42, i / 12.0)
		mo.append(Vector3(F + d, smile.call(d), float(pad.call(d, smile.call(d))) + 0.0002))
	k.line(mo, 0.0088, INK, true, 0.75)
	for i in 8:
		var d := (i - 3.5) * 0.074
		var y: float = float(smile.call(d)) + 0.0014
		var p: Vector3 = k.P(F + d, y, float(pad.call(d, y)) + 0.0009)
		k.bar(p, Vector3.UP, k.O(F + d), 0.0052 * (1.0 - absf(d) * 1.2), 0.0052, 0.0016, Color(0.95, 0.92, 0.82))
	# burun parçası
	var nt = func(d: float) -> float: return k.ey - 0.012 - 0.022 * smoothstep(0.03, 0.24, absf(d))
	var nb = func(d: float) -> float: return k.ey - 0.056 + 0.012 * smoothstep(0.06, 0.25, absf(d))
	var npad = func(d: float, y: float) -> float: return 0.0085 + 0.0042 * G(d, 0.1) + 0.003 * G(absf(d) - 0.14, 0.05) * G(y - (k.ey - 0.05), 0.008)
	var ncol = func(d: float, _y: float) -> Color: return fg.lightened(0.14 * G(d, 0.05)).darkened(0.08 * smoothstep(0.08, 0.22, absf(d)))
	k.panel(F, 0.25, nt, nb, npad, ncol, 14, 9)
	k.bead(F, 0.25, nt, nb, 0.0052, 0.0016, gold, 12)
	for s: float in [-1.0, 1.0]:
		k.line([Vector3(F + s * 0.05, k.ey - 0.0525, 0.0118), Vector3(F + s * 0.13, k.ey - 0.0495, 0.0118)], 0.0036, INK, true, 0.6)
		# bıyık: burnun altından yana açılan kıl demetleri
		for i in 6:
			var e := i / 5.0
			var y0 := k.ey - 0.0665 - e * 0.0065
			var d0 := 0.05 + e * 0.12
			var pts := []
			var length := 0.3 + 0.2 * sin(e * PI)
			for j in 6:
				var w := j / 5.0
				var d := d0 + w * length
				var y := y0 + 0.003 * sin(w * PI) - w * w * (0.012 + e * 0.006)
				pts.append(k.P(F + s * d, y, float(pad.call(s * d, y)) + 0.0028 - w * 0.0014))
			k.sweep(pts, 0.0021, 0.0015, Color(0.93, 0.91, 0.85).darkened(0.1 * fmod(i * 0.37, 1.0)), 4, func(q: float) -> float: return 1.0 - q * 0.85)
		# yanak kancası ve bağ ipi
		var hook: Vector3 = k.P(F + s * 1.08, k.ey - 0.068, 0.0125)
		k.lathe(hook, k.O(F + s * 1.08), [Vector2(0.0048, -0.005), Vector2(0.0048, 0.0), Vector2(0.0028, 0.002), Vector2(0.0028, 0.006), Vector2(0.0052, 0.0072), Vector2(0.0001, 0.0086)], gold, 8)
		var cy = func(a: float) -> float: return lerpf(k.ey - 0.068, k.ey - 0.03, smoothstep(0.0, 1.0, (absf(wrapf(a - F, -PI, PI)) - 1.1) / 2.0))
		k.strap(F + s * 1.1, F + s * PI, cy, 0.0042, 0.0028, 0.0024, cord, 22)
		for j in 2:   # yanak perçinleri
			var dr := 0.74 + j * 0.2
			var yr := k.ey - 0.044 - j * 0.006
			k.screw(k.P(F + s * dr, yr, float(pad.call(s * dr, yr)) - 0.0003), k.O(F + s * dr), 0.0031, gold, false)
	# çene püskülü ve ter deliği
	k.lathe(k.P(F, k.chin - 0.012, 0.0125), Vector3(0, -0.5, 1), [Vector2(0.0048, 0.0), Vector2(0.0036, 0.0008), Vector2(0.0001, 0.0009)], INK, 8)
	# boğaz koruması: üst üste binen lake sıralar + ipek bağ
	for j in 3:
		var ytop: float = k.chin - 0.003 - j * 0.0195
		var dh := 1.02 - j * 0.07
		var lt = func(d: float) -> float: return ytop + 0.03 * smoothstep(0.5, 1.2, absf(d))
		var lb = func(d: float) -> float: return ytop - 0.0275 + 0.026 * smoothstep(0.5, 1.2, absf(d))
		var base: float = 0.0125 + j * 0.0065
		var lp = func(_d: float, y: float) -> float: return base + 0.0045 * clampf((ytop - y) / 0.027, 0.0, 1.0)
		var lc = func(d: float, y: float) -> Color:
			var q: float = float(lb.call(d))
			if y - q < 0.0032:
				return gold
			var c: Color = fg.darkened(0.12 + j * 0.05)
			return c.darkened(0.3) if fmod(absf(d) + 0.04, 0.17) < 0.012 else c
		k.panel(F, dh, lt, lb, lp, lc, 26, 4, base * 0.5)
		for i in 7:   # bağ sırası
			var d: float = (i - 3.0) * (0.25 - j * 0.018)
			var cy: float = float(lb.call(d)) + 0.005
			var pts := []
			for q in 3:
				var y2: float = cy + q * 0.0105
				pts.append(k.P(F + d, y2, float(lp.call(d, y2)) + 0.001))
			k.sweep(pts, 0.0021, 0.0012, cord, 4)


static func _demir(k: Y, _fg: Color) -> void:
	var sc := STEEL
	var t = func(d: float) -> float: return k.ey - 0.038 - 0.024 * smoothstep(0.1, 0.5, absf(d)) + 0.016 * smoothstep(0.5, 0.9, absf(d)) - 0.034 * smoothstep(0.95, 1.22, absf(d))
	var b = func(d: float) -> float: return k.chin - 0.014 + 0.012 * smoothstep(0.15, 0.7, absf(d)) + 0.031 * smoothstep(0.76, 1.22, absf(d))
	var pad = func(d: float, y: float) -> float:
		return 0.009 + 0.0034 * G(d, 0.05) + 0.003 * G(absf(d) - 0.72, 0.14) * G(y - (k.ey - 0.07), 0.03) - 0.0016 * G(absf(d) - 0.38, 0.05) * G(y - (k.ey - 0.09), 0.024)
	var col = func(d: float, y: float) -> Color:
		var br: float = 0.5 + 0.5 * sin(d * 3.0 + y * 40.0)
		var c: Color = sc.darkened(0.14 * br).lightened(0.16 * G(d, 0.04))
		var sr: float = sin(d * 37.0 + y * 91.0) * sin(d * 13.0 - y * 57.0)
		if sr > 0.82:
			c = c.darkened(0.14)   # dövme izi
		return c.darkened(0.25) if float(t.call(d)) - y < 0.0024 or y - float(b.call(d)) < 0.0024 else c
	k.panel(F, 1.22, t, b, pad, col, 50, 20)
	k.bead(F, 1.22, t, b, 0.0058, 0.0019, DSTEEL, 26)
	for s: float in [-1.0, 1.0]:
		# nefes delikleri
		for j in 3:
			for i in 3 - j:
				var d: float = s * (0.12 + i * 0.075 + j * 0.03)
				var y: float = k.ey - 0.082 - j * 0.0115
				var p: Vector3 = k.P(F + d, y, float(pad.call(d, y)) + 0.0001)
				k.dot(p, k.O(F + d), 0.0032, INK)
		# perçin sırası (kenarı izler)
		for i in 7:
			var d: float = lerpf(0.48, 1.08, i / 6.0)
			var yy: float = float(t.call(d)) - 0.0065
			k.screw(k.P(F + s * d, yy, float(pad.call(s * d, yy)) - 0.0004), k.O(F + s * d), 0.0027, sc.lightened(0.2), false)
		for i in 4:
			var d: float = lerpf(0.26, 0.74, i / 3.0)
			var yy: float = float(b.call(d)) + 0.0065
			k.screw(k.P(F + s * d, yy, float(pad.call(s * d, yy)) - 0.0004), k.O(F + s * d), 0.0027, sc.lightened(0.2), false)
		# menteşe + deri kayış
		var hp: Vector3 = k.P(F + s * 1.14, k.ey - 0.078, 0.0072)
		k.lathe(hp - Vector3.UP * 0.012, Vector3.UP, [Vector2(0.0034, 0.0), Vector2(0.0034, 0.024)], [DSTEEL], 8)
		var cy = func(_a: float) -> float: return k.ey - 0.078
		k.strap(F + s * 1.16, F + s * PI, cy, 0.0042, 0.0075, 0.0018, LEATHER, 22)
		k.stitch([Vector3(F + s * 1.25, k.ey - 0.0725, 0.0065), Vector3(F + s * 1.8, k.ey - 0.0725, 0.0065)], 0.0008, 0.003, 0.0025, LEATHER.lightened(0.4), false)
	k.hair_cut(k.ey - 0.078, 0.02)


## ---------------------------------------------------------------- gözlükler

static func _eye_ax(k: Y, a: float, toward_z := 0.72) -> Vector3:
	return (k.O(a) * (1.0 - toward_z) + Vector3(0, 0, 1) * toward_z).normalized()


static func _temple_arm(k: Y, s: float, c: Color, w: float) -> void:
	# kulaç: menteşeden kulağın üstüne, arkası aşağı kıvrık
	var pts := []
	for i in 9:
		var t := i / 8.0
		var a := F + s * lerpf(0.9, 2.05, t)
		var y := k.ey + 0.012 - 0.002 * t - 0.03 * pow(maxf(0.0, (t - 0.72) / 0.28), 2.0)
		pts.append(k.at(a, y, float(k.m.face_r(a, y)) + 0.0042))
	k.sweep(pts, w, w * 0.7, c, 5)


static func _ring(k: Y, l: Dictionary, off: float, s: float, r: float, c, sides := 30) -> void:
	var pts := []
	for i in sides + 1:
		var q: Vector2 = k._sq(TAU * i / sides, l["pw"]) * s
		pts.append(k.lpt(l, q.x, q.y, off))
	k.sweep(pts, r, r, c, 5, Callable(), l["ax"], false)


static func _megane(k: Y, c: Color) -> void:
	# ince tel çerçeve (ref yy_kabuto): cam yok gibi — yalnız parıltı, göz görünür
	var ls := []
	for s: float in [-1.0, 1.0]:
		var a: float = k.ar if s > 0.0 else k.al
		var l: Dictionary = k.cup_frame(a, k.ey + 0.001, 0.0272, 0.0262, 2.0, _eye_ax(k, a), 0.0)
		ls.append(l)
		_ring(k, l, 0.0115, 1.0, 0.00125, c)
		k.glint(l, 0.0108, 0.42, 0.56, Color(0.9, 0.95, 1.0), 0.0, 0.3, 0.84)
		k.glint(l, 0.0108, 0.64, 0.7, Color(0.9, 0.95, 1.0), 0.0, 0.3, 0.7)
		_hinge(k, _outer(k, l, s, 0.0115), s, c)
	_bridge(k, ls[0], ls[1], 0.0115, 0.0013, c, 0.0055)
	for s: float in [-1.0, 1.0]:
		_temple_arm(k, s, c, 0.00125)
		var nd: Vector3 = k.S(F + s * 0.13, k.ey - 0.018, 0.0022)
		k.lathe(nd, k.O(F + s * 0.13), [Vector2(0.0001, -0.0012), Vector2(0.0024, 0.0), Vector2(0.0001, 0.0012)], Color(0.95, 0.93, 0.85), 6, 0, 1.6)


static func _hinge(k: Y, p: Vector3, s: float, c: Color) -> void:
	var a := F + s * 0.9
	var q: Vector3 = k.S(a, k.ey + 0.012, 0.0042)
	k.sweep([p, p.lerp(q, 0.5) + Vector3(0, 0.0006, 0.001), q], 0.0017, 0.0014, c, 5)
	k.lathe(q, Vector3.UP, [Vector2(0.0024, -0.0024), Vector2(0.0024, 0.0024)], c.lightened(0.14), 6)


## İki çerçeve arasında burun köprüsü
static func _bridge(k: Y, l0: Dictionary, l1: Dictionary, off: float, r: float, c: Color, rise := 0.006) -> void:
	var dir: Vector3 = (l1["c"] - l0["c"]).normalized()
	var x0: float = (l0["e1"] as Vector3).dot(dir) * l0["rx"]
	var x1: float = (l1["e1"] as Vector3).dot(-dir) * l1["rx"]
	var p0: Vector3 = l0["c"] + l0["e1"] * (1.0 if x0 > 0.0 else -1.0) * l0["rx"] + l0["e2"] * 0.15 * l0["ry"] + l0["ax"] * off
	var p1: Vector3 = l1["c"] + l1["e1"] * (1.0 if x1 > 0.0 else -1.0) * l1["rx"] + l1["e2"] * 0.15 * l1["ry"] + l1["ax"] * off
	var pts := []
	for i in 9:
		var t := i / 8.0
		pts.append(p0.lerp(p1, t) + Vector3.UP * rise * sin(t * PI) + Vector3(0, 0, 0.0035) * sin(t * PI))
	k.sweep(pts, r, r, c, 5)


## Çerçevenin dış şakak noktası
static func _outer(k: Y, l: Dictionary, s: float, off: float) -> Vector3:
	var e1: Vector3 = l["e1"]
	var sg := 1.0 if (-s if true else s) * e1.x > 0.0 else -1.0
	return k.lpt(l, sg, 0.1, off)


static func _yuvarlak(k: Y, fg: Color) -> void:
	var fr := Color(0.12, 0.12, 0.14)
	var ls := []
	var gt := Color(0.07, 0.09, 0.13)
	var gb := Color(0.015, 0.02, 0.03)
	if fg.s > 0.28:
		gt = fg.darkened(0.35)
		gb = fg.darkened(0.8)
	for s: float in [-1.0, 1.0]:
		var a: float = k.ar if s > 0.0 else k.al
		var l: Dictionary = k.cup_frame(a, k.ey + 0.001, 0.0275, 0.0265, 2.0, _eye_ax(k, a), 0.0)
		ls.append(l)
		k.lens(l, 0.0118, 0.0022, gt, gb, 0.97)
		_ring(k, l, 0.012, 1.0, 0.0019, fr)
		_ring(k, l, 0.0132, 0.93, 0.0005, STEEL)
		k.glint(l, 0.0118, 0.24, 0.42, Color(0.72, 0.8, 0.88), 0.0022)
		k.glint(l, 0.0118, 0.5, 0.57, Color(0.6, 0.68, 0.76), 0.0022)
		_hinge(k, _outer(k, l, s, 0.012), s, fr)
		_temple_arm(k, s, fr, 0.0019)
	_bridge(k, ls[0], ls[1], 0.012, 0.0018, fr, 0.005)
	for s: float in [-1.0, 1.0]:
		var nd: Vector3 = k.S(F + s * 0.13, k.ey - 0.018, 0.0022)
		k.lathe(nd, k.O(F + s * 0.13), [Vector2(0.0001, -0.0012), Vector2(0.0026, 0.0), Vector2(0.0001, 0.0012)], Color(0.3, 0.3, 0.33), 6, 0, 1.6)


## Yüze contayla oturan gözlük: lastik conta, renkli kabuk, metal bilezik, kubbeli cam, vidalar, hava delikleri
static func _goggle_pair(k: Y, y: float, rx: float, ry: float, pw: float, shell: Color, bez: Color, gt: Color, gb: Color, tilt_up: float, depth := 0.016) -> Array:
	var ls := []
	for s: float in [-1.0, 1.0]:
		var a: float = F + s * (rx * 1.2 + 0.004) / 0.09
		var ax: Vector3 = (_eye_ax(k, a, 0.62) + Vector3(0, tilt_up, 0)).normalized()
		var l: Dictionary = k.cup_frame(a, y, rx, ry, pw, ax, 0.0)
		ls.append(l)
		var rub := Color(0.11, 0.11, 0.12)
		k.cup(l, [[1.16, -0.002, 0.0, rub], [1.18, 0.0024, 0.1, rub], [1.12, 0.0046, 0.25, shell.darkened(0.3)], [1.08, depth * 0.55, 0.65, shell], [1.03, depth * 0.85, 0.95, shell.lightened(0.08)], [1.0, depth, 1.0, bez.darkened(0.12)], [1.0, depth + 0.0022, 1.0, bez], [0.93, depth + 0.0026, 1.0, bez.lightened(0.14)], [0.885, depth + 0.0012, 1.0, INK], [0.885, depth - 0.0012, 1.0, INK]])
		k.lens(l, depth - 0.0012, 0.0052, gt, gb, 0.885)
		k.glint(l, depth - 0.0012, 0.14, 0.34, Color(0.97, 0.98, 1.0, 1.0), 0.0052 * 1.0)
		k.glint(l, depth - 0.0012, 0.42, 0.5, Color(0.86, 0.92, 1.0), 0.0052)
		for i in 4:   # bilezik vidaları
			var q: Vector2 = k._sq(TAU * (i + 0.5) / 4.0, pw) * 0.965
			k.screw(k.lpt(l, q.x, q.y, depth + 0.0024), ax, 0.0018, STEEL.lightened(0.2))
		# yan hava delikleri
		var sd: Vector3 = _outer(k, l, s, 0.0)
		var e1: Vector3 = (sd - l["c"]).normalized()
		for i in 3:
			var p: Vector3 = l["c"] + e1 * rx * 1.09 + ax * (depth * (0.3 + i * 0.2)) + Vector3.UP * 0.0
			k.bar(p, l["e2"], e1 + ax * 0.15, 0.0088, 0.0016, 0.0009, INK)
	return ls


## Gözlük kayışı: şakakta metal halka, arkada başı sarar; tokalı
static func _goggle_strap(k: Y, ls: Array, y: float, c: Color, depth: float, buckle_side := 1.0) -> void:
	var w := 0.0088
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		s = 1.0 if i == 0 else -1.0
		var l: Dictionary = ls[i]
		var q: Vector3 = _outer(k, l, s, depth * 0.35)
		var yf = func(_a: float) -> float: return y
		var ah := F + s * 0.98
		k.sweep([q, k.S(F + s * 0.82, y, 0.0072), k.S(ah, y, 0.0048)], 0.0056, 0.0026, DSTEEL, 6)   # bağlantı kulağı
		k.lathe(k.S(ah, y, 0.0035), k.O(ah), [Vector2(0.0078, 0.0), Vector2(0.0078, 0.0028), Vector2(0.0056, 0.0034), Vector2(0.0001, 0.0034)], [DSTEEL, STEEL, STEEL.lightened(0.15)], 10)
		var cc = func(u: float, _v: float) -> Color:
			return c.darkened(0.3) if fmod(u * 26.0, 1.0) < 0.1 else c
		k.strap(ah, F + s * PI, yf, 0.0042, w, 0.0019, cc, 26)
		for sg: float in [-1.0, 1.0]:
			k.stitch([Vector3(ah + s * 0.1, y + sg * 0.0064, 0.0062), Vector3(F + s * 2.4, y + sg * 0.0064, 0.0062)], 0.0007, 0.0028, 0.0024, c.lightened(0.34), false)
	# ayar tokası (bir yanda)
	_buckle(k, F + buckle_side * 1.5, y, 0.0072, STEEL)
	k.hair_cut(y, w * 2.0 + 0.006)


static func _goggles(k: Y, fg: Color) -> void:
	# alna kaldırılmış ninja gözlüğü: eski yerinde durur, gözler açık
	var y := k.ey + 0.056
	var shell := fg
	var ls := _goggle_pair(k, y, 0.0295, 0.0232, 2.7, shell, Color(0.66, 0.68, 0.72), Color(0.42, 0.62, 0.72), Color(0.13, 0.24, 0.32), 0.38)
	_bridge(k, ls[0], ls[1], 0.0125, 0.0036, DSTEEL, 0.0035)
	_goggle_strap(k, ls, y, Color(0.15, 0.15, 0.17), 0.016)


static func _koruyucu(k: Y, fg: Color) -> void:
	# gözlerin üstünde büyük turuncu koruyucu (ref yy_obito): geniş kabuk, koyu cam, tek parça burun köprüsü
	var shell := _tint(fg, Color(0.95, 0.53, 0.12))
	var y := k.ey + 0.003
	var ls := _goggle_pair(k, y, 0.03, 0.0255, 3.1, shell, shell.darkened(0.3), Color(0.3, 0.24, 0.2), Color(0.06, 0.05, 0.05), 0.02, 0.0165)
	_bridge(k, ls[0], ls[1], 0.0115, 0.0052, shell.darkened(0.12), 0.0035)
	_goggle_strap(k, ls, y, Color(0.11, 0.12, 0.15), 0.0165)


static func _vizor(k: Y, fg: Color) -> void:
	# şakaktan şakağa tek parça vizör: üst çelik ray, yan menteşe kutuları, alt burun oyuğu
	var dh := 1.08
	var t = func(d: float) -> float: return k.ey + 0.026 - 0.008 * smoothstep(0.3, dh, absf(d))
	var b = func(d: float) -> float: return k.ey - 0.024 + 0.0105 * smoothstep(0.35, dh, absf(d)) + 0.016 * G(d, 0.13)
	var gl := _tint(fg, Color(0.15, 0.36, 0.56))
	var pad = func(d: float, _y: float) -> float: return 0.0105 + 0.0052 * cos(d / dh * F)
	var col = func(_d: float, y: float) -> Color:
		var yt: float = (y - k.ey + 0.024) / 0.05
		return gl.darkened(0.55).lerp(gl.lightened(0.16), clampf(yt, 0.0, 1.0))
	k.panel(F, dh, t, b, pad, col, 40, 8, 0.0015)
	var fr := Color(0.17, 0.18, 0.21)
	var edge = func(yf: Callable, off: float, wd: float, h: float, cc) -> void:
		var pts := []
		for i in 25:
			var d := lerpf(-dh, dh, i / 24.0)
			var y: float = yf.call(d)
			pts.append(k.P(F + d, y, float(pad.call(d, y)) * 0.97 + off))
		k.sweep(pts, wd, h, cc, 6)
	edge.call(t, 0.0012, 0.0034, 0.0024, STEEL)
	edge.call(b, 0.0005, 0.0023, 0.0018, fr)
	# parıltı: camın üstünde yüze uyan iki eğik şerit
	for q in [[-0.5, 0.11, Color(0.86, 0.95, 1.0)], [-0.28, 0.035, Color(0.8, 0.9, 0.98)], [0.5, 0.05, Color(0.72, 0.85, 0.95)]]:
		var fn = func(u: float, v: float) -> Vector3:
			var yy: float = lerpf(k.ey - 0.014, k.ey + 0.019, v)
			var d: float = float(q[0]) + (u - 0.5) * float(q[1]) * 2.0 + (0.5 - v) * 0.13
			return k.P(F + d, yy, float(pad.call(d, yy)) + 0.0006)
		k.sheet(1, 3, fn, q[2])
	for s: float in [-1.0, 1.0]:
		var a := F + s * (dh + 0.02)
		var c: Vector3 = k.S(a, k.ey + 0.002, 0.0075)
		var n: Vector3 = k.O(a)
		var tg := n.cross(Vector3.UP).normalized()
		k.bar(c, tg, n, 0.031, 0.031, 0.011, fr)
		k.bar(c + n * 0.0058, tg, n, 0.024, 0.024, 0.0016, DSTEEL)
		for i in 4:
			var th := TAU * (i + 0.5) / 4.0
			k.screw(c + n * 0.0065 + (tg * cos(th) + Vector3.UP * sin(th)) * 0.0135, n, 0.0014, STEEL)
		k.lathe(c + n * 0.0066, n, [Vector2(0.0058, 0.0), Vector2(0.0058, 0.0014), Vector2(0.0001, 0.0018)], [STEEL, STEEL.lightened(0.15)], 10)
	var yf = func(_a: float) -> float: return k.ey + 0.002
	k.strap(F + dh + 0.1, F + PI, yf, 0.0042, 0.0072, 0.0018, fr, 24)
	k.strap(F - dh - 0.1, F - PI, yf, 0.0042, 0.0072, 0.0018, fr, 24)
	k.hair_cut(k.ey + 0.002, 0.02)


static func _tek_mercek(k: Y, _fg: Color) -> void:
	# tek gözlük: altın çerçeve, tırtıllı bilezik, kulağa giden zincir (cam saydam: yalnız parıltı)
	var a := k.ar
	var l: Dictionary = k.cup_frame(a, k.ey + 0.001, 0.0305, 0.0305, 2.0, _eye_ax(k, a), 0.0)
	var off := 0.0102
	k.cup(l, [[1.04, -0.002, 0.0, BRASS.darkened(0.45)], [1.04, off * 0.75, 0.7, BRASS.darkened(0.2)], [1.02, off, 1.0, BRASS], [0.96, off + 0.0016, 1.0, BRASS.lightened(0.22)], [0.9, off + 0.0007, 1.0, BRASS.darkened(0.15)], [0.895, off - 0.0022, 1.0, BRASS.darkened(0.5)]], 36)
	var e1: Vector3 = l["e1"]
	var e2: Vector3 = l["e2"]
	for i in 40:   # tırtıl
		var th := TAU * i / 40.0
		var d := e1 * cos(th) + e2 * sin(th)
		k.bar(l["c"] + d * l["rx"] * 1.03 + l["ax"] * (off - 0.001), l["ax"], d, 0.0032, 0.0011, 0.0009, BRASS.lightened(0.28))
	k.glint(l, off - 0.001, 0.36, 0.52, Color(0.92, 0.96, 1.0), 0.0, 0.25, 0.8)
	k.glint(l, off - 0.001, 0.6, 0.66, Color(0.92, 0.96, 1.0), 0.0, 0.25, 0.66)
	# zincir: çerçeveden yanaktan kulak arkasına sarkar
	var s0: Vector3 = _outer(k, l, 1.0, off) - l["e2"] * l["ry"] * 0.3
	k.lathe(s0, l["ax"], [Vector2(0.0026, -0.002), Vector2(0.0026, 0.001), Vector2(0.0001, 0.0016)], BRASS.lightened(0.15), 8)
	var pts := []
	var ta := F + 1.72
	var end: Vector3 = k.S(ta, k.ey + 0.004, 0.0035)
	var n := 22
	for i in n + 1:
		var t := float(i) / n
		var q: Vector3 = s0.lerp(end, t)
		var aq: float = atan2(q.z - k.cz, q.x - k.cx)
		var yy: float = q.y - 0.058 * sin(t * PI)
		pts.append(k.at(aq, yy, float(k.m.face_r(aq, yy)) + 0.0028))
	for i in n:
		var p: Vector3 = (pts[i] + pts[i + 1]) * 0.5
		var tg: Vector3 = (pts[i + 1] - pts[i]).normalized()
		var nr: Vector3 = (p - Vector3(k.cx, p.y, k.cz)).normalized()
		var side: Vector3 = tg.cross(nr) if i % 2 == 0 else nr
		var bs := Basis(side * 0.0044, tg.cross(side).normalized() * 0.0044, tg * 0.0062)
		if bs.determinant() < 0.0:
			bs = Basis(-bs.x, bs.y, bs.z)
		k.mb.add_xf("torus", Transform3D(bs * Basis(Vector3.RIGHT, F), p), BRASS, 8)
	k.lathe(end, k.O(ta), [Vector2(0.0034, -0.002), Vector2(0.0034, 0.001), Vector2(0.0001, 0.0018)], BRASS, 8)


## ---------------------------------------------------------------- göz kapakları, boya

static func _goz_bandi(k: Y, fg: Color) -> void:
	var c := fg if fg.get_luminance() < 0.3 else INK.lightened(0.05)
	var a := k.ar
	var rf = func(th: float) -> float: return 0.0355 + 0.0035 * cos(th * 2.0 + 0.4) + 0.002 * sin(th)
	var fn = func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var r: float = float(rf.call(th)) * v
		var q := Vector2(cos(th) * r * 1.08, sin(th) * r * 0.88 - 0.0012)
		var aq: float = a + q.x / 0.098
		var e: float = 1.0 - v * v
		return k.S(aq, k.ey + q.y, 0.0012 + 0.0078 * pow(e, 0.42) + 0.0014 * e)
	var cc = func(_u: float, v: float) -> Color: return c.lightened(0.09 * (1.0 - v) * (1.0 - v)) if v < 0.82 else c.darkened(0.3) if v > 0.94 else c.lightened(0.05)
	k.sheet(30, 12, fn, cc, true)
	var st := []
	for i in 31:
		var th := TAU * i / 30.0
		var r: float = float(rf.call(th)) * 0.86
		st.append(Vector3(a + cos(th) * r * 1.08 / 0.098, k.ey + sin(th) * r * 0.88 - 0.0012, 0.0045))
	k.stitch(st, 0.0009, 0.0034, 0.0026, c.lightened(0.42), false)
	# kayış: yamanın iki ucundan; biri alnın üstünden, biri kulak altından enseye
	var strap_c := c.lightened(0.06)
	var upy = func(q: float) -> float: return lerpf(k.ey + 0.02, k.ey + 0.062, smoothstep(0.0, 1.0, q))
	var pu := []
	var pl := []
	for i in 29:
		var t := i / 28.0
		var au := a - 0.3 - t * (TAU * 0.5 - 0.3 + 0.28)   # alından sola, enseye
		var yu: float = upy.call(t * 2.2) - 0.03 * smoothstep(0.5, 1.0, t)
		pu.append(k.at(au, yu, float(k.m.face_r(au, yu)) + 0.0042))
		var al2 := a + 0.33 + t * (TAU * 0.5 - 0.61)
		var yl := k.ey - 0.008 + 0.026 * smoothstep(0.35, 1.0, t)
		pl.append(k.at(al2, yl, float(k.m.face_r(al2, yl)) + 0.0042))
	k.sweep(pu, 0.0046, 0.0016, strap_c, 6)
	k.sweep(pl, 0.0046, 0.0016, strap_c, 6)
	for q in [[a - 0.3, k.ey + 0.02], [a + 0.33, k.ey - 0.008]]:
		k.screw(k.S(q[0], q[1], 0.0065), k.O(q[0]), 0.0027, STEEL, false)
	k.hair_cut(k.ey + 0.024, 0.05)


static func _fuin_gantai(k: Y, fg: Color) -> void:
	# mühürlü göz kapağı (ref yy_ao): gözden şakağa uzanan dilimli siyah kapak + üstünde mühür kâğıdı
	var c := fg if fg.get_luminance() < 0.3 else Color(0.07, 0.07, 0.09)
	var a := k.ar
	var rf = func(th: float) -> float:
		# kulak yönüne (cos > 0) şişen, üç loblu kenar
		var side: float = maxf(0.0, cos(th))
		return 0.042 + 0.018 * side + 0.0035 * cos(th * 3.0) * side + 0.0045 * pow(absf(cos(th * 3.0 + 0.4)), 2.0) * side
	var fn = func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var r: float = float(rf.call(th)) * v
		var aq: float = a + 0.08 + cos(th) * r / 0.096
		var e: float = 1.0 - v * v
		return k.S(aq, k.ey + 0.004 + sin(th) * r * 0.92, 0.0012 + 0.0085 * pow(e, 0.4) + 0.002 * G(v - 0.62, 0.08))
	var cc = func(u: float, v: float) -> Color:
		var o: Color = c.lightened(0.1 * (1.0 - v))
		if absf(v - 0.62) < 0.04:
			return o.lightened(0.12)
		if v > 0.95:
			return c.darkened(0.4)
		return o.darkened(0.12) if fmod(u * 12.0, 1.0) < 0.05 and v > 0.66 else o
	k.sheet(42, 14, fn, cc, true)
	# mühür kâğıdı: kapağa yapışık, hafif kıvrık
	var paper := Color(0.9, 0.84, 0.66)
	var pa := a + 0.1
	var hw := 0.145
	var pf = func(u: float, v: float) -> Vector3:
		var aq: float = pa + (u - 0.5) * 2.0 * hw + (v - 0.5) * 0.05
		var yy: float = k.ey + 0.004 + (v - 0.5) * 0.054
		var dr: float = (aq - (a + 0.08)) * 0.096
		var rr: float = sqrt(dr * dr + pow((yy - k.ey - 0.004) / 0.92, 2.0))
		var e: float = maxf(0.0, 1.0 - pow(rr / 0.044, 2.0))
		return k.S(aq, yy, 0.0034 + 0.0085 * pow(e, 0.4) + 0.0006 * sin(v * 9.0))
	var pc = func(_u: float, v: float) -> Color: return paper.darkened(0.14 * (1.0 - smoothstep(0.0, 0.1, minf(v, 1.0 - v))))
	k.sheet(6, 12, pf, pc)
	var red := Color(0.68, 0.1, 0.1)
	var ink_pt = func(u: float, v: float) -> Vector3: return (pf.call(u, v) as Vector3) + (k.O(pa) * 0.0005)
	var stroke = func(pts: Array, w: float, c2: Color) -> void:
		var g := []
		for q in pts:
			var p: Vector3 = ink_pt.call(q.x, q.y)
			g.append([p + Vector3(w, 0, 0), p - Vector3(w, 0, 0)])
		k.grid(g, c2, false, false, true, Vector3.ZERO, true)
	stroke.call([Vector2(0.5, 0.9), Vector2(0.5, 0.42)], 0.0013, INK)
	stroke.call([Vector2(0.28, 0.76), Vector2(0.72, 0.72)], 0.001, INK)
	stroke.call([Vector2(0.3, 0.6), Vector2(0.5, 0.52), Vector2(0.72, 0.6)], 0.0009, INK)
	stroke.call([Vector2(0.34, 0.3), Vector2(0.66, 0.3), Vector2(0.66, 0.14), Vector2(0.34, 0.14), Vector2(0.34, 0.3)], 0.0009, red)
	stroke.call([Vector2(0.5, 0.28), Vector2(0.5, 0.16)], 0.0008, red)
	# bağ: şakaktan enseye
	var yf = func(q: float) -> float: return k.ey + 0.018 + 0.042 * smoothstep(0.3, 0.8, absf(wrapf(q - a, -PI, PI))) - 0.02 * smoothstep(1.2, 2.8, absf(wrapf(q - a, -PI, PI)))
	k.strap(a + 0.72, F + PI, yf, 0.0042, 0.0058, 0.0016, c.lightened(0.08), 20)
	k.strap(a - 0.42, F - PI, yf, 0.0042, 0.0058, 0.0016, c.lightened(0.08), 26)
	k.hair_cut(k.ey + 0.045, 0.03)


static func _katame_hotai(k: Y, fg: Color) -> void:
	# tek gözü kapatan çapraz sargı (ref yy_danzo): turlar sağ gözden sol alnın üstüne tırmanır
	var bc := LINEN if fg.get_luminance() < 0.4 else fg
	var a := k.ar
	var rise = func(q: float) -> float:
		var d: float = wrapf(q - a, -PI, PI)
		if d < 0.0:
			return 0.066 * smoothstep(0.0, 0.62, -d)
		return 0.066 * smoothstep(0.35, 3.1, d)
	var hw := 0.0122
	var n := 6
	for i in n:
		var y0: float = k.ey - 0.024 + i * 0.0178
		var ph: float = i * 1.9
		var sgn: float = 1.0 if i % 2 == 0 else -1.0
		var yf = func(q: float) -> float: return y0 + float(rise.call(q)) + sgn * 0.0035 * sin(q + ph) + 0.0012 * sin(q * 3.0 + ph)
		_strip_skin(k, yf, hw, 0.0042 + 0.0016 * (i % 2), bc.darkened(0.04 * (i % 3)))
	# gözü kapatan kalın ped ve üstünden çapraz tur
	var pf = func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var r: float = 0.031 * v
		var e: float = 1.0 - v * v
		return k.S(a + cos(th) * r / 0.098, k.ey - 0.001 + sin(th) * r * 0.86, 0.0066 + 0.0052 * pow(e, 0.5))
	var pcc = func(u: float, v: float) -> Color: return bc.darkened(0.06 + 0.1 * (0.5 + 0.5 * sin(u * TAU * 3.0 + v * 7.0)) * v)
	k.sheet(22, 6, pf, pcc, true)
	var dg = func(q: float) -> float: return k.ey + 0.004 + (q - a) * -0.1
	var fnd = func(u: float, v: float) -> Vector3:
		var q: float = a + (u - 0.5) * 1.1
		return k.S(q, float(dg.call(q)) + (v - 0.5) * 0.021, 0.0092 + 0.003 * sin(v * PI))
	var ccd = func(_u: float, v: float) -> Color: return bc.darkened(0.2 * (1.0 - sin(v * PI)))
	k.sheet(16, 3, fnd, ccd)
	var tail: Vector3 = k.S(-F - 0.25, k.ey + 0.045, 0.008)
	k.dangle(tail, Vector3(-0.2, -1.0, -0.35), 0.1, 0.02, bc.darkened(0.08), 0.15)
	k.hair_cut(k.ey + 0.045, 0.1, 0.008)


static func _strip_skin(k: Y, yf: Callable, hw: float, pad: float, c: Color) -> void:
	var fn = func(u: float, v: float) -> Vector3:
		var a: float = F + (u - 0.5) * TAU
		var y: float = float(yf.call(a)) + (v - 0.5) * 2.0 * hw
		return k.S(a, y, pad + 0.0085 * smoothstep(k.ey + 0.022, k.ey + 0.04, y) - 0.0014 + 0.0032 * pow(sin(v * PI), 0.6))   # alın bandının üstünden geçer
	var cc = func(u: float, v: float) -> Color:
		var pr: float = sin(v * PI)
		var o: Color = c.darkened(0.2 * (1.0 - pr) + 0.05 * (0.5 + 0.5 * sin(u * 83.0)))
		return o.darkened(0.08) if absf(v - 0.33) < 0.05 or absf(v - 0.67) < 0.05 else o
	k.sheet(48, 4, fn, cc, true)


static func _katamen(k: Y, fg: Color) -> void:
	# yarım yüz peçesi (ref yy_baki): alın bandından yüzün sol yarısına inen, çene altına sarkan bez
	var c := fg
	var dark := c.darkened(0.3)
	var ytop := k.ey + 0.056
	# alın sargısı
	var bf = func(a: float) -> float: return ytop + 0.002 + 0.008 * sin(a)
	_strip_skin(k, bf, 0.0125, 0.0058, c.lightened(0.03))
	var bf2 = func(a: float) -> float: return ytop + 0.016 + 0.009 * sin(a) + 0.0015 * sin(a * 3.0)
	_strip_skin(k, bf2, 0.0105, 0.0078, c.darkened(0.06))
	# peçe: burun çizgisinden şakağa, alttan sarkar; karakterin solu (d < 0)
	var D0 := 0.02
	var D1 := -1.34
	var pl = func(d: float, dep: float) -> float: return sin(d * 13.0 + dep * 2.2) * (0.25 + dep * 0.75)
	var bot = func(d: float) -> float:
		var w: float = (d - D0) / (D1 - D0)
		return k.chin - 0.05 + 0.05 * pow(w, 2.2) + 0.012 * sin(w * 8.0) * w
	var fn = func(u: float, v: float) -> Vector3:
		var d: float = lerpf(D0, D1, u)
		var y: float = lerpf(ytop - 0.002, bot.call(d), v)
		var a: float = F + d
		var dep: float = clampf((k.chin + 0.03 - y) / 0.1, 0.0, 1.0)
		var pad: float = 0.0066 + 0.002 * sin(minf(v * 7.0, PI)) + dep * dep * 0.024 + float(pl.call(d, v)) * 0.0028
		return k.P(a, y, pad)
	var cc = func(u: float, v: float) -> Color:
		var d: float = lerpf(D0, D1, u)
		var f: float = pl.call(d, v)
		var o: Color = c.darkened(clampf(-f * 0.3, 0.0, 0.3)) if f < 0.0 else c.lightened(f * 0.06)
		if u < 0.018 or v > 0.985:
			return dark
		return o
	k.sheet(30, 26, fn, cc, false, false)
	k.backing(10, 8, fn, c.darkened(0.5))
	# açık kenar dikişi + arka bağ
	var d_s := D0 - 0.05
	var y0_s := ytop - 0.006
	var y1_s: float = float(bot.call(d_s)) + 0.008
	for j in range(0, 14, 2):
		var pts := []
		for q in 2:
			var y: float = lerpf(y0_s, y1_s, (j + q * 0.8) / 14.0)
			var dep: float = clampf((k.chin + 0.03 - y) / 0.1, 0.0, 1.0)
			pts.append(k.P(F + d_s, y, 0.0072 + dep * dep * 0.024))
		k.sweep(pts, 0.0006, 0.0006, c.darkened(0.5), 3)
	var tp: Vector3 = k.S(-F + 0.1, ytop + 0.005, 0.0105)
	k.lathe(tp, Vector3(0, 0, -1), [Vector2(0.0001, -0.008), Vector2(0.0078, -0.005), Vector2(0.0095, 0.0), Vector2(0.0078, 0.005), Vector2(0.0001, 0.008)], c.darkened(0.16), 10)
	k.dangle(tp + Vector3(0.004, -0.004, -0.004), Vector3(0.15, -1.0, -0.3), 0.14, 0.026, c.darkened(0.08), 0.15)
	k.dangle(tp + Vector3(-0.004, -0.004, -0.004), Vector3(-0.2, -1.0, -0.25), 0.1, 0.022, c.darkened(0.12), 0.15)
	k.hair_cut(ytop + 0.008, 0.042, 0.007)


static func _savas_boyasi(k: Y, fg: Color) -> void:
	# yüze sürülmüş boya: fırça izli yanak pençeleri, göz altı, alın ve çene işareti
	var c := _tint(fg, Color(0.74, 0.09, 0.09))
	var dk := c.darkened(0.3)
	var p := 0.0012
	for s: float in [-1.0, 1.0]:
		var e: float = k.ar if s > 0.0 else k.al
		for i in 3:   # yanak pençesi: dışa ve aşağı inen üç darbe
			var d0: float = s * (0.15 + i * 0.1)
			var y0: float = k.ey - 0.03 - i * 0.002
			var pts := [Vector3(e + d0 - s * 0.05, y0 + 0.002, p), Vector3(e + d0 + s * 0.03, y0 - 0.022, p), Vector3(e + d0 + s * 0.14, y0 - 0.05 + i * 0.005, p)]
			k.line(pts, 0.0102 - i * 0.0012, c, false, 1.0, 5)
			k.line([pts[0] + Vector3(s * 0.012, -0.002, 0.0003), pts[1] + Vector3(s * 0.016, -0.002, 0.0003)], 0.0014, dk, false, 1.0)
		k.line([Vector3(e - s * 0.22, k.ey + 0.024, p), Vector3(e, k.ey + 0.032, p), Vector3(e + s * 0.32, k.ey + 0.014, p)], 0.0052, c, false, 1.0, 5)   # göz üstü
		k.line([Vector3(F + s * 0.03, k.ey + 0.076, p), Vector3(F + s * 0.16, k.ey + 0.056, p), Vector3(F + s * 0.32, k.ey + 0.066, p)], 0.0078, c, false, 1.0, 5)   # alın çentiği
	k.line([Vector3(F, k.ey + 0.088, p), Vector3(F, k.ey + 0.056, p)], 0.0088, c, false, 1.0)
	k.line([Vector3(F, k.ey - 0.08, p), Vector3(F, k.ey - 0.104, p)], 0.0092, c, false, 1.0)
	k.line([Vector3(F - 0.17, k.ey - 0.09, p), Vector3(F, k.ey - 0.098, p), Vector3(F + 0.17, k.ey - 0.09, p)], 0.0036, c, false, 1.0)


## ----------------------------------------------------------------

static func _design(k: Y, s: String, fg: Color) -> void:
	match s:
		"cloth": _cloth(k, fg)
		"pece": _pece(k, fg)
		"yuksek_pece": _yuksek_pece(k, fg)
		"bandaj_alt": _bandaj(k, fg, false)
		"tam_bandaj": _bandaj(k, fg, true)
		"gas": _gas(k, fg)
		"gaz_maskesi": _gaz_maskesi(k, fg)
		"solunum_maskesi": _solunum(k, fg)
		"mempo": _mempo(k, fg)
		"demir_yarim_maske": _demir(k, fg)
		"goggles": _goggles(k, fg)
		"koruyucu_gozluk": _koruyucu(k, fg)
		"yuvarlak_gozluk": _yuvarlak(k, fg)
		"vizor": _vizor(k, fg)
		"tek_mercek": _tek_mercek(k, fg)
		"goz_bandi": _goz_bandi(k, fg)
		"savas_boyasi": _savas_boyasi(k, fg)
		"megane": _megane(k, Color(0.14, 0.13, 0.13) if fg.get_luminance() < 0.3 else fg)
		"katamen_fukumen": _katamen(k, fg)
		"fuin_gantai": _fuin_gantai(k, fg)
		"katame_hotai": _katame_hotai(k, fg)


static func build(m, s, fg: Color) -> bool:
	var key := ""
	if m._sk_key != "":
		key = "%s|%s|%s" % [m._sk_key, s, fg.to_html(false)]
	var e = _cache.get(key) if key != "" else null
	if e == null:
		var k := Y.new(m)
		_design(k, String(s), fg)
		e = [k.mb.build(Props.toon()), k.post]
		if key != "":
			if _cache.size() >= CACHE_MAX:
				_cache.clear()
			_cache[key] = e
	m._mesh_on("Head", e[0], Transform3D.IDENTITY)
	for p in e[1]:
		if p[0] == "slab":
			m.hair_mask_slab(p[1], p[2], p[3], p[4], p[5])
		else:
			m.dangle_strip("Head", p[1], p[2], p[3], p[4], p[5], p[6], Vector3(1, 0, 0), p[7])
	return true
