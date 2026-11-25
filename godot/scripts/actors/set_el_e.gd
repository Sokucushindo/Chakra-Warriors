extends RefCounted
## Elle modellenmiş setler, parti e: set_kumo_kenshi, set_kumo_kunoichi, set_aogiri, set_iwa_kunoichi, set_kuro_iryo, set_uzumaki_haha. Örnek: set_el.gd içindeki _shugonin.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_kumo_kenshi", "set_kumo_kunoichi", "set_aogiri", "set_iwa_kunoichi", "set_kuro_iryo", "set_uzumaki_haha"]


static func recipe(k, sid: String) -> void:
	match sid:
		"set_kumo_kenshi": _kumo_kenshi(k)
		"set_kumo_kunoichi": _kumo_kunoichi(k)
		"set_aogiri": _aogiri(k)
		"set_iwa_kunoichi": _iwa_kunoichi(k)
		"set_kuro_iryo": _kuro_iryo(k)
		"set_uzumaki_haha": _uzumaki_haha(k)


# ------------------------------------------------------------------ ölçü
static func _base(k) -> Dictionary:
	return {"ch": k.M(k.C - 0.03, k.UA), "wa": k.M(k.H + 0.12, k.UA), "hp": k.M(k.H - 0.04, 0.3), "nk": k.M(k.N + 0.02, 0.09)}


static func _kp(m: Vector3, y: float, p: float, pz := -1.0) -> Array:
	var q: float = p if pz < 0.0 else pz
	return [y, m.x + p, m.y + q, m.z - q]


## Boyun halkaları (N+0.06 .. N): üst ikisi gerçek boyundan (b["nk"] trapez kasını da ölçüyor: boyun iki kat geniş kare kutu oluyordu),
## N+0.012'de yaka ağzında trapez üstünü örten kat (lp: yan / arka pay; altındaki gövde boyası görünmesin), N'de boyun dibi (önü gerçek gırtlaktan)
static func _neck_keys(k, nk: Vector3, lp := 0.024, top := 0.06) -> Array:
	var N: float = k.N
	var n0: Vector3 = k.M(N + 0.06, 0.09)
	var n1: Vector3 = k.M(N + 0.03, n0.x * 1.3)
	var n2: Vector3 = k.M(N, 0.09)
	return [_kp(n0, N + top, 0.004, 0.005), _kp(n1, N + 0.03, 0.005), [N + 0.012, nk.x + lp, nk.y + 0.016, nk.z - lp], [N, nk.x + lp - 0.002, maxf(n2.y + 0.006, nk.y + 0.016), nk.z - lp + 0.002]]


## Kapalı astar: boyundan kalçaya
static func _inner(k, b: Dictionary, colf: Callable, pad := 0.01, y1 := -99.0, ny := 26) -> Array:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := _neck_keys(k, nk) + [[k.N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], _kp(ch, k.C - 0.03, pad), _kp(b["wa"], k.H + 0.12, pad), _kp(b["hp"], y1 if y1 > -9.0 else k.H - 0.09, pad)]
	SE.body_layer(k, keys, ny, 44, colf)
	return keys


## Bel altı ağırlığı: çekirdeğin kumaş ağırlığı; etek ucu son kurulan kumaştan gelir (üstüne binen şerit / yama aynı ağırlığı alır)
static var _cur_hem := 0.0
static var _cur_leg := 0.58
static var _cur_long := false


static func _hs(k, p: Vector3) -> Array:
	if _cur_long:
		return _long_skin(k, p, _cur_hem)
	return k.cloth_skin(p, _cur_hem, _cur_leg)


static func _fs(c: Color, v: float, gain := 6.0) -> Color:
	return c.darkened(clampf(-v * gain, 0.0, 0.36)) if v < 0.0 else c.lightened(clampf(v * gain * 0.4, 0.0, 0.1))


# ------------------------------------------------------------------ kumaş
## keys üzerinde yüzey. rng(y) -> Vector2(a0, a1) (yoksa kapalı), foldf(a, y, u) -> oransal kabarma, colf(a, y, u, v, p) -> renk.
## Alt uç içe katlanır ve kumaş astarla geri döner (arkadan bakınca delik yok); in_f: astarın boyu (oran).
static func _sheet(k, keys: Array, ny: int, na: int, rng: Callable, foldf: Callable, colf: Callable, th := 0.006, in_f := 1.0, skinf := Callable()) -> Array:
	var closed := not rng.is_valid()
	var y0: float = keys[0][0]
	var y1: float = keys[keys.size() - 1][0]
	_cur_hem = y1
	var outer := []
	var ang := []
	var cnt: int = na if closed else na + 1
	for j in ny + 1:
		var y := lerpf(y0, y1, float(j) / ny)
		var s: Array = SE.El.key_at(keys, y)
		var r: Vector2 = Vector2(-PI, PI) if closed else rng.call(y)
		var ro := []
		var an := []
		for i in cnt:
			var a := lerpf(r.x, r.y, float(i) / na)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f := 1.0 + (float(foldf.call(a, y, float(i) / na)) if foldf.is_valid() else 0.0)
			ro.append(Vector3(q.x * f, y, q.y * f))
			an.append(a)
		outer.append(ro)
		ang.append(an)
	var rows: Array = outer.duplicate()
	var src := []
	for j in ny + 1:
		src.append(j)
	if th > 0.0:
		var inw = func(p: Vector3, d: float) -> Vector3:
			return p - Vector3(p.x, 0.0, p.z).normalized() * d
		var roll := []
		for p in outer[ny]:
			roll.append(inw.call(p, th * 0.5) + Vector3(0, -th * 0.6, 0))
		rows.append(roll)
		src.append(ny)
		var stop := int(round(float(ny) * (1.0 - in_f)))
		for j in range(ny, stop - 1, -1):
			var ro := []
			for p in outer[j]:
				ro.append(inw.call(p, th))
			rows.append(ro)
			src.append(j)
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return _hs(k, p)
	k.grid(rows, closed, func(i, j, p):
		var oj: int = src[j]
		var c0: Color = colf.call(ang[oj][i], lerpf(y0, y1, float(oj) / ny), float(i) / na, float(oj) / ny, p)
		return c0 if j <= ny else c0.darkened(0.42), func(_i, _j, p): return sf.call(p))
	return outer


## keys yüzeyinde x, y noktası: [konum, dış yön]
static func _fp(keys: Array, x: float, y: float, front: bool, lift := 0.0) -> Array:
	var s: Array = SE.El.key_at(keys, y)
	var w: float = s[1]
	var zm: float = s[2] if front else s[3]
	var n := 2.5
	var rx := clampf(absf(x) / w, 0.0, 0.985)
	var rz := pow(1.0 - pow(rx, n), 1.0 / n)
	var o := Vector3(signf(x) * pow(rx, n - 1.0) / w, 0.0, (1.0 if front else -1.0) * pow(rz, n - 1.0) / absf(zm)).normalized()
	return [Vector3(x, y, zm * rz) + o * lift, o]


## Açıya göre yüzey noktası (sarılı etek üstü ayrıntı)
static func _sa(keys: Array, a: float, y: float, lift := 0.0, foldf := Callable()) -> Array:
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
	var f := 1.0 + (float(foldf.call(a, y, 0.5)) if foldf.is_valid() else 0.0)
	var o := Vector3(q.x / (float(s[1]) * float(s[1])), 0.0, q.y / (absf(float(s[2] if q.y > 0.0 else s[3])) * absf(float(s[2] if q.y > 0.0 else s[3])))).normalized()
	return [Vector3(q.x * f, y, q.y * f) + o * lift, o]


## Yüzeye oturan, kenarı yüzeye inen yastık parça (cep, plaka). cham: üst/alt köşe pahı (oran)
static func _patch(k, keys: Array, x0: float, x1: float, y0: float, y1: float, front: bool, lift: float, col: Color, cham := 0.0, nu := 10, nv := 8, skinf := Callable()) -> void:
	var rows := []
	var cx := (x0 + x1) * 0.5
	for j in nv + 1:
		var v := float(j) / nv
		var ed := minf(v, 1.0 - v) * 2.0
		var sq := lerpf(1.0 - cham, 1.0, smoothstep(0.0, 0.45, ed))
		var ro := []
		for i in nu + 1:
			var u := float(i) / nu
			if not front:
				u = 1.0 - u
			var x := cx + (lerpf(x0, x1, u) - cx) * sq
			var e2 := minf(minf(float(i) / nu, 1.0 - float(i) / nu) * 2.0, ed)
			var l := -0.002 + (lift + 0.002) * smoothstep(0.0, 0.3, e2)
			ro.append(_fp(keys, x, lerpf(y0, y1, v), front, l)[0])
		rows.append(ro)
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return _hs(k, p)
	k.grid(rows, false, func(i, j, _p):
		var e3 := minf(minf(float(i) / nu, 1.0 - float(i) / nu), minf(float(j) / nv, 1.0 - float(j) / nv))
		return col.darkened(0.2) if e3 < 0.09 else col, func(_i, _j, p): return sf.call(p))


## Yüzey üstünde şerit: ctrl [Vector2(x, y)...]
static func _strap(k, keys: Array, ctrl: Array, front: bool, hw: float, lift: float, d: float, col: Color, steps := 8, skinf := Callable()) -> void:
	var pts := []
	var outs := []
	for s in ctrl.size() - 1:
		for t in steps + (1 if s == ctrl.size() - 2 else 0):
			var q: Vector2 = (ctrl[s] as Vector2).lerp(ctrl[s + 1], float(t) / steps)
			var e: Array = _fp(keys, q.x, q.y, front, lift)
			pts.append(e[0])
			outs.append(e[1])
	k.strip(pts, outs, hw, d, col, false, skinf if skinf.is_valid() else func(p: Vector3) -> Array: return _hs(k, p))


## Omuz üstünden önden arkaya geçen kayış
static func _over(k, keys: Array, x: float, y_f: float, y_b: float, hw: float, lift: float, d: float, col: Color) -> void:
	var yt: float = keys[0][0]
	var ys := yt
	while ys > keys[keys.size() - 1][0]:
		if float(SE.El.key_at(keys, ys)[1]) > absf(x) + 0.012:
			break
		ys -= 0.004
	var pts := []
	var outs := []
	var n := 12
	for j in n + 1:
		var e: Array = _fp(keys, x, lerpf(y_f, ys, float(j) / n), true, lift)
		var t := float(j) / n
		pts.append(e[0])
		outs.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.55, 1.0, t)).normalized())
	for j in range(n, -1, -1):
		var e: Array = _fp(keys, x, lerpf(y_b, ys, float(j) / n), false, lift)
		var t := float(j) / n
		pts.append(e[0])
		outs.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.55, 1.0, t)).normalized())
	k.strip(pts, outs, hw, d, col)


## Yazı / damga: çizgiler kabartma
static func _glyph(k, keys: Array, cx: float, cy: float, s: float, strokes: Array, w: float, col: Color, front := true, lift := 0.004) -> void:
	var sg := 1.0 if front else -1.0
	for q in strokes:
		_strap(k, keys, [Vector2(cx + sg * float(q[0]) * s, cy + float(q[1]) * s), Vector2(cx + sg * float(q[2]) * s, cy + float(q[3]) * s)], front, w, lift, 0.0015, col, 3)


## Serbest boru. rf(s, a) -> yarıçap, colf(s, a, p), skinf(s, p)
static func _tb(k, pts: Array, rf: Callable, colf: Callable, skinf: Callable, seg := 12, closed := false) -> void:
	var n := pts.size()
	var rows := []
	var ss := []
	var fw := Vector3.ZERO
	for j in n:
		var p0: Vector3 = pts[(j - 1 + n) % n] if closed or j > 0 else pts[j]
		var p1: Vector3 = pts[(j + 1) % n] if closed or j < n - 1 else pts[j]
		var t := (p1 - p0).normalized()
		if j == 0:
			fw = Vector3.BACK - t * t.dot(Vector3.BACK)
			if fw.length() < 0.2:
				fw = Vector3.UP - t * t.dot(Vector3.UP)
		else:
			fw -= t * t.dot(fw)
		fw = fw.normalized()
		var ri := (-t).cross(fw).normalized()
		var s := float(j) / float(n if closed else n - 1)
		var ro := []
		for i in seg:
			var a := TAU * i / seg - PI
			var r: float = rf.call(s, a)
			ro.append((pts[j] as Vector3) + ri * sin(a) * r + fw * cos(a) * r)
		rows.append(ro)
		ss.append(s)
	if closed:
		rows.append(rows[0])
		ss.append(1.0)
	k.grid(rows, true, func(i, j, p): return colf.call(ss[j], TAU * i / seg - PI, p), func(_i, j, p): return skinf.call(ss[j], p))


## Bel halkası noktaları
static func _ring_pts(keys: Array, y: float, add: float, n := 72) -> Array:
	var s: Array = SE.El.key_at(keys, y)
	var pts := []
	for i in n:
		var q: Vector2 = SE.El.sup(TAU * i / n - PI, float(s[1]) + add, float(s[2]) + add, float(s[3]) - add)
		pts.append(Vector3(q.x, y, q.y))
	return pts


## Yuvarlatılmış kutu (kese, toka). ux, uy, uz yarı eksenler; uz dışa
static func _boxr(k, c: Vector3, ux: Vector3, uy: Vector3, uz: Vector3, col: Color, bones: Array, round_c := 0.3) -> void:
	var seg := 16
	var ring = func(h: float, sc: float) -> Array:
		var ro := []
		for i in seg:
			var a := TAU * i / seg - PI
			var sx := signf(sin(a)) * pow(absf(sin(a)), 0.45)
			var sz := signf(cos(a)) * pow(absf(cos(a)), 0.45)
			ro.append(c + uy * h + ux * sx * sc + uz * sz * sc)
		return ro
	var rows := [ring.call(1.0, 0.001), ring.call(1.0, 1.0 - round_c), ring.call(1.0 - round_c * 0.45, 1.0), ring.call(-1.0 + round_c * 0.45, 1.0), ring.call(-1.0, 1.0 - round_c), ring.call(-1.0, 0.001)]
	k.grid(rows, true, func(_i, j, _p): return col.lightened(0.05) if j <= 1 else (col.darkened(0.14) if j >= 4 else col), func(_i, _j, _p): return bones)


## Yelpaze disk. o: dış yön, up: yaklaşık yukarı; rf(th) -> yarıçap; colf(u, v) -> renk (-1..1)
static func _fan(k, c: Vector3, o: Vector3, up: Vector3, r: float, rf: Callable, colf: Callable, bones: Array, rings := 4, seg := 32) -> void:
	var uy := (up - o * up.dot(o)).normalized()
	var ux := uy.cross(o).normalized()
	var rows := []
	for j in rings + 1:
		var v := float(j) / rings
		var ro := []
		for i in seg:
			var th := TAU * i / seg
			var rr: float = r * v * (float(rf.call(th)) if rf.is_valid() else 1.0)
			ro.append(c + (ux * cos(th) + uy * sin(th)) * rr + o * 0.0015 * (1.0 - v))
		rows.append(ro)
	k.grid(rows, true, func(i, j, _p):
		var th: float = TAU * i / seg
		var v: float = float(j) / rings
		return colf.call(cos(th) * v, sin(th) * v), func(_i, _j, _p): return bones)


# ------------------------------------------------------------------ uzuvlar
static func _limb(k, sd: String, leg: bool) -> Dictionary:
	var m = k.m
	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var bo: Array
	if leg:
		p0 = m._bp(sd + "UpperLeg") + Vector3(0, 0.05, 0)
		p1 = m._bp(sd + "LowerLeg")
		p2 = m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		bo = [sd + "UpperLeg", sd + "LowerLeg"]
	else:
		var ch: Vector3 = m._bp("UpperChest")
		p0 = (m._bp(sd + "UpperArm") as Vector3).lerp(Vector3(0.0, ch.y, ch.z), 0.2)
		p1 = m._bp(sd + "LowerArm")
		p2 = (m._bp(sd + "Hand") as Vector3).lerp(p1, -0.05)
		bo = [sd + "UpperArm", sd + "LowerArm"]
	var la := (p1 - p0).length()
	var lb := (p2 - p1).length()
	var l := {"p0": p0, "p1": p1, "p2": p2, "bo": bo, "kn": la / (la + lb), "leg": leg, "sd": sd, "sg": 1.0 if sd == "Left" else -1.0}
	# yarıçap: bedenin o kesitteki ortalama uzaklığı
	var nb := 14
	var sum := []
	var cnt := []
	sum.resize(nb)
	cnt.resize(nb)
	sum.fill(0.0)
	cnt.fill(0)
	var cap := 0.13 if leg else 0.095
	var V: PackedVector3Array = k.c["V"]
	var sx: float = l["sg"]
	for q: Vector3 in V:
		if q.x * sx < 0.01:
			continue
		for seg in 2:
			var a: Vector3 = p0 if seg == 0 else p1
			var b: Vector3 = p1 if seg == 0 else p2
			var ab := b - a
			var t := (q - a).dot(ab) / ab.length_squared()
			if t < 0.0 or t > 1.0:
				continue
			var dd := (q - a - ab * t).length()
			if dd > cap:
				continue
			var s: float = t * l["kn"] if seg == 0 else lerpf(l["kn"], 1.0, t)
			var bi := mini(nb - 1, int(s * nb))
			sum[bi] += dd
			cnt[bi] += 1
			break
	var rad := []
	var fall := 0.09 if leg else 0.05
	for i in nb:
		if cnt[i] > 0:
			fall = float(sum[i]) / cnt[i] * 1.1
		rad.append(fall)
	l["rad"] = rad
	return l


static func _lp(l: Dictionary, s: float) -> Vector3:
	var kn: float = l["kn"]
	if s < kn:
		return (l["p0"] as Vector3).lerp(l["p1"], s / kn)
	return (l["p1"] as Vector3).lerp(l["p2"], (s - kn) / (1.0 - kn))


static func _ld(l: Dictionary, s: float) -> Vector3:
	var d0: Vector3 = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).normalized()
	var d1: Vector3 = ((l["p2"] as Vector3) - (l["p1"] as Vector3)).normalized()
	return d0.lerp(d1, smoothstep(float(l["kn"]) - 0.06, float(l["kn"]) + 0.06, s)).normalized()


static func _lr(l: Dictionary, s: float) -> float:
	var rad: Array = l["rad"]
	var f := clampf(s * rad.size() - 0.5, 0.0, rad.size() - 1.001)
	var i := int(f)
	return lerpf(rad[i], rad[i + 1], f - i)


static func _lskin(l: Dictionary, s: float) -> Array:
	var bo: Array = l["bo"]
	var kn: float = l["kn"]
	var w := smoothstep(kn - 0.07, kn + 0.07, s)
	if w > 0.0:
		return [[bo[0], 1.0 - w], [bo[1], w]]
	var w0 := (1.0 - smoothstep(0.0, 0.14, s)) * 0.4
	if w0 > 0.0:
		return [[bo[0], 1.0 - w0], ["Hips" if l["leg"] else "UpperChest", w0]]
	return [[bo[0], 1.0]]


## Uzuv tüpü: addf(s, a) yarıçapa eklenir, colf(s, a, ic). s0..s1 aralığı; lining: uçtan içe dönen astar boyu
static func _lt(k, l: Dictionary, addf: Callable, colf: Callable, s0 := 0.0, s1 := 1.0, n := 30, seg := 18, lining := 0.0) -> void:
	var st := []
	for j in n + 1:
		st.append([lerpf(s0, s1, float(j) / n), 0.0, false])
	if lining > 0.0:
		st.append([s1, -0.004, true])
		for j in 4:
			st.append([s1 - lining * float(j) / 3.0, -0.007, true])
	else:
		st.append([s1, -0.003, true])
		st.append([s1 - 0.004, -0.012, true])
	var rows := []
	for e in st:
		var s: float = e[0]
		var d := _ld(l, s)
		var c := _lp(l, s)
		var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri := (-d).cross(fw).normalized()
		var ro := []
		for i in seg:
			var a := TAU * i / seg - PI
			var r := maxf(0.006, _lr(l, s) + float(addf.call(s, a)) + float(e[1]))
			ro.append(c + ri * sin(a) * r + fw * cos(a) * r)
		rows.append(ro)
	k.grid(rows, true, func(i, j, _p): return colf.call(st[j][0], TAU * i / seg - PI, st[j][2]), func(_i, j, _p): return _lskin(l, st[j][0]))


static func _lf(s: float, a: float, seed_v: float) -> float:
	return 0.5 * sin(a * 2.0 + s * 17.0 + seed_v) + 0.5 * sin(a * 3.0 - s * 29.0 + seed_v * 2.3)


## Uzvu saran sargı dizisi
static func _wraps(k, l: Dictionary, s0: float, s1: float, n: int, add: float, hw: float, col: Color, tilt := 0.01) -> void:
	for i in n:
		var s := lerpf(s0, s1, float(i) / maxf(1.0, n - 1.0))
		k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + add, hw, tilt, col.darkened(0.05 * float(i % 3)), _lskin(l, s))


## Uzvun kol yuvası halkası (yelek / kolsuz üst)
static func _armhole(k, l: Dictionary, s: float, add: float, r: float, col: Color) -> void:
	var c := _lp(l, s)
	var d := _ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri := (-d).cross(fw).normalized()
	var R := _lr(l, s) + add
	var pts := []
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + (ri * sin(a) + fw * cos(a)) * R)
	var sd: String = l["sd"]
	_tb(k, pts, func(_s, _a): return r, func(_s, a, _p): return col.darkened(0.12) if cos(a) < -0.3 else col, func(_s, _p): return [["UpperChest", 0.6], [sd + "UpperArm", 0.4]], 8, true)



# ------------------------------------------------------------------ kumaş ayrıntı yardımcıları
## Anahtar kesitinde yüzey noktası: a açısı (0 ön, +PI/2 karakterin solu), lift bağıl kabarma
static func _on(keys: Array, a: float, y: float, lift := 0.0) -> Vector3:
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
	return Vector3(q.x * (1.0 + lift), y, q.y * (1.0 + lift))


static func _out(p: Vector3, up := 0.0) -> Vector3:
	return Vector3(p.x, up, p.z).normalized()

## Yüzeyden hafif kalkık şerit: dış yön noktadan hesaplanır
static func _bd(k, pts: Array, hw: float, d: float, col: Color, closed := false, skinf := Callable(), up := 0.0) -> void:
	var ou := []
	for p in pts:
		ou.append(_out(p, up))
	k.strip(pts, ou, hw, d, col, closed, skinf)


## Yuvarlak ip / biye: pts boyunca tüp; tw > 0 ise burgulu
static func _cord(k, pts: Array, r: float, col: Color, closed := false, skinf := Callable(), tw := 0.0, seg := 6) -> void:
	var n := pts.size()
	var rows := []
	var cc := []
	var count: int = n + 1 if closed else n
	for j in count:
		var i0: int = j % n
		var a: Vector3 = pts[(i0 - 1 + n) % n] if closed or i0 > 0 else pts[i0]
		var b: Vector3 = pts[(i0 + 1) % n] if closed or i0 < n - 1 else pts[i0]
		var t: Vector3 = (b - a).normalized()
		var p: Vector3 = pts[i0]
		var fw: Vector3 = _out(p, 0.2)
		fw = (fw - t * t.dot(fw)).normalized()
		var ri: Vector3 = (-t).cross(fw).normalized()
		var ro := []
		var cr := []
		for i in seg:
			var q := TAU * i / seg - PI
			var w := sin(float(j) * tw + q * 2.0) if tw > 0.0 else 0.0
			ro.append(p + (ri * sin(q) + fw * cos(q)) * r * (1.0 + 0.2 * w))
			cr.append(col.darkened(clampf(-w * 0.28, 0.0, 0.28)))
		rows.append(ro)
		cc.append(cr)
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return k.torso_skin(p.y)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return sf.call(p))


## Kuşak: katlı kalın bez halkası (kesitten alır)
static func _sash(k, keys: Array, y: float, h: float, lift: float, col: Color, crease := 0.14) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var rows := []
	var cc := []
	var na := 56
	for j in 7:
		var t := float(j) / 6.0
		var b := 0.008 * sin(t * PI) + lift
		var ro := []
		var cr := []
		for i in na:
			var a := TAU * i / na - PI
			var wob := 0.004 * sin(a * 5.0 + t * 7.0)
			var yy := y + h * (1.0 - 2.0 * t) + 0.004 * sin(a * 3.0 + 1.0)
			var q: Vector2 = SE.El.sup(a, float(s[1]) + b + wob, float(s[2]) + b + wob, float(s[3]) - b - wob)
			ro.append(Vector3(q.x, yy, q.y))
			var cre: bool = (j == 2 or j == 4) and sin(a * 4.0 + float(j)) > -0.4
			cr.append(col.darkened(crease) if cre else col)
		rows.append(ro)
		cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return k.torso_skin(p.y))



# ------------------------------------------------------------------ parti e yardımcıları
## Serbest kenarlı kumaş: her açıda üst ve alt kenar ayrı (V yaka, verev etek, kolsuz oyuk tek yüzeyden çıkar).
## o: keys, top(a)->y, hem(a)->y, rng(v)->Vector2 (yoksa kapalı), fold(a,y,v)->oran, col(a,y,v)->Color, ny, na, th, gain, lift, inner(Color), skin(p)
static func _cl(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var top: Callable = o["top"]
	var hem: Callable = o["hem"]
	var ny: int = o.get("ny", 30)
	var na: int = o.get("na", 80)
	var closed: bool = not o.has("rng")
	var rng: Callable = o.get("rng", Callable())
	var fold: Callable = o.get("fold", Callable())
	var col: Callable = o["col"]
	var th: float = o.get("th", 0.005)
	var gain: float = o.get("gain", 6.5)
	var lift: float = o.get("lift", 0.0)
	var cnt: int = na if closed else na + 1
	var outer := []
	var cols := []
	var low := 99.0
	for j in ny + 1:
		var v := float(j) / ny
		var r: Vector2 = Vector2(-PI, PI) if closed else rng.call(v)
		var ro := []
		var cr := []
		for i in cnt:
			var a := lerpf(r.x, r.y, float(i) / na)
			var aw := wrapf(a, -PI, PI)
			var y := lerpf(float(top.call(aw)), float(hem.call(aw)), v)
			var s: Array = SE.El.key_at(keys, y)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f: float = float(fold.call(aw, y, v)) if fold.is_valid() else 0.0
			var d := Vector3(q.x, 0.0, q.y).normalized()
			ro.append(Vector3(q.x * (1.0 + f), y, q.y * (1.0 + f)) + d * lift)
			cr.append(_fs(col.call(aw, y, v), f, gain))
			low = minf(low, y)
		outer.append(ro)
		cols.append(cr)
	_cur_hem = low
	var rows: Array = outer.duplicate()
	var cc: Array = cols.duplicate()
	if th > 0.0:
		var ic = o.get("inner", null)
		var inw = func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
		var roll := []
		var rc := []
		for i in cnt:
			roll.append(inw.call(outer[ny][i], th * 0.5) + Vector3(0, -th * 0.5, 0))
			rc.append((cols[ny][i] as Color).darkened(0.25))
		rows.append(roll)
		cc.append(rc)
		for j in range(ny, -1, -1):
			var ro := []
			var cr := []
			for i in cnt:
				var edge: bool = not closed and (i == 0 or i == cnt - 1)
				ro.append(inw.call(outer[j][i], 0.0 if edge else th))
				cr.append(ic if ic != null else (cols[j][i] as Color).darkened(0.42))
			rows.append(ro)
			cc.append(cr)
		rows.append(outer[0])
		cc.append(cols[0])
	var sf: Callable = o.get("skin", func(p: Vector3) -> Array: return _hs(k, p))
	k.grid(rows, closed, func(i, j, _p): return cc[j][i], func(_i, _j, p): return sf.call(p))
	var ea := []
	var eb := []
	for ro in outer:
		ea.append(ro[0])
		eb.append(ro[cnt - 1])
	return {"rows": outer, "top": outer[0], "hem": outer[ny], "ea": ea, "eb": eb, "low": low}


## Uzun kapalı giysi ağırlığı: diz hizasına kadar uyluğa tam geçer (kalkan diz kumaşı delmez), arka etek baldırı da izler (geri savrulan topuk delmez)
static func _long_skin(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var kt: float = maxf(0.05, (H - k.K) / maxf(0.05, H - hem))
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var w: float = 0.96 * pow(minf(1.0, t / (kt * 0.8)), 0.3)
	var s: float = smoothstep(-0.06, 0.06, p.x)
	var kb: float = smoothstep(k.K + 0.02, k.K - 0.12, p.y) * smoothstep(0.02, -0.06, p.z) * 0.6 * absf(2.0 * s - 1.0)
	var sd: String = "Left" if s >= 0.5 else "Right"
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * (1.0 - kb)], [sd + "LowerLeg", w * kb]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Kumaşa oturan biye / dikiş (bel altında kumaşla birlikte açılır)
static func _tr(k, pts: Array, hw: float, d: float, col: Color, closed := false, up := 0.0) -> void:
	_bd(k, pts, hw, d, col, closed, func(p): return _hs(k, p), up)


## Catmull-Rom ile (açı, y) yolu sıklaştırma
static func _path(ctrl: Array, steps := 6) -> Array:
	var out := []
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(0, i - 1)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(n - 1, i + 2)]
		for s in steps:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / steps))
	out.append(ctrl[n - 1])
	return out


## Kumaş yüzeyinde (açı, y) yolu boyunca dikiş / şerit
static func _line(k, keys: Array, ctrl: Array, hw: float, lift: float, d: float, col: Color, steps := 6, foldf := Callable()) -> void:
	var pts := []
	var ou := []
	for q in _path(ctrl, steps):
		var e: Array = _sa(keys, q.x, q.y, lift, foldf)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, d, col, false, func(p): return _hs(k, p))


## Yaka / devrik bant: (açı, y) yolunun dış yanına doğru genişler, ortası kabarık. wf(t)->genişlik
static func _band(k, keys: Array, ctrl: Array, wf: Callable, lift: float, col: Color, steps := 5, nu := 6, under := 0.1, edge := 0.16) -> Array:
	var P := _path(ctrl, steps)
	var R0 := 0.16
	var rows := []
	var outer_e := []
	var n := P.size()
	for j in n:
		var a: Vector2 = P[maxi(0, j - 1)]
		var b: Vector2 = P[mini(n - 1, j + 1)]
		var t := Vector2((b.x - a.x) * R0, b.y - a.y)
		var no := Vector2(t.y, -t.x).normalized()
		var w: float = float(wf.call(float(j) / (n - 1)))
		var ro := []
		for i in nu + 1:
			var u := lerpf(-under, 1.0, float(i) / nu)
			var bump := sin(clampf(float(i) / nu, 0.0, 1.0) * PI)
			var q: Vector2 = P[j] + Vector2(no.x * w * u / R0, no.y * w * u)
			q.y = minf(q.y, float(keys[0][0]) + 0.004)   # yaka üst sınırı aşıp boynun yanında sivrilmesin
			ro.append(_sa(keys, q.x, q.y, 0.0015 + lift * bump)[0])
		rows.append(ro)
		outer_e.append(ro[nu])
	var a0: Vector3 = rows[0][0]
	var fn: Vector3 = -((rows[0][1] as Vector3) - a0).cross((rows[1][1] as Vector3) - a0)
	if fn.dot(_out(a0)) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(i, _j, _p): return col.darkened(edge) if i == 0 or i == nu else col, func(_i, _j, p): return _hs(k, p))
	return outer_e


## Uzuv tüpü, başlangıcı açıya bağlı (sivri konç, kolluk ağzı). s0f(a)->s
static func _lts(k, l: Dictionary, addf: Callable, colf: Callable, s0f: Callable, s1: float, n := 16, seg := 20) -> void:
	var rows := []
	var ss := []
	for j in n + 3:
		var v := minf(1.0, float(j) / n)
		var ro := []
		var sr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var s: float = lerpf(float(s0f.call(a)), s1, v)
			if j == n + 2:
				s = float(s0f.call(a)) + 0.004
			var d := _ld(l, s)
			var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
			var ri := (-d).cross(fw).normalized()
			var r := _lr(l, s) + float(addf.call(s, a)) - (0.004 if j == n + 1 else (0.012 if j == n + 2 else 0.0))
			ro.append(_lp(l, s) + ri * sin(a) * r + fw * cos(a) * r)
			sr.append(s)
		rows.append(ro)
		ss.append(sr)
	k.grid(rows, true, func(i, j, _p): return colf.call(ss[j][i], TAU * i / seg - PI, j > n), func(i, j, _p): return _lskin(l, ss[j][i]))


## File: uzvu iki yönde saran ince iplikler (boya değil, gerçek ağ)
static func _net_limb(k, l: Dictionary, s0: float, s1: float, add: float, n: int, dh: float, r: float, col: Color) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var rate := TAU / (n * dh) * L
	var m := int(ceil(rate * (s1 - s0) / 0.3))
	for dr in [1.0, -1.0]:
		for h in n:
			var rows := []
			var ss := []
			for j in m + 1:
				var s := lerpf(s0, s1, float(j) / m)
				var a: float = TAU * h / n + dr * rate * (s - s0)
				var d := _ld(l, s)
				var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
				var ri := (-d).cross(fw).normalized()
				var o := ri * sin(a) + fw * cos(a)
				var rr := _lr(l, s) + add
				var c := _lp(l, s) + o * rr
				var tg := d.cross(o).normalized()
				rows.append([c + o * r * 0.9, c + tg * r - o * r * 0.3, c - tg * r - o * r * 0.3])
				ss.append(s)
			k.grid(rows, true, func(_i, _j, _p): return col, func(_i, j, _p): return _lskin(l, ss[j]))


## File yama: inside(a, y) içinde kalan çapraz iplikler
static func _net_patch(k, keys: Array, inside: Callable, a0: float, a1: float, y0: float, y1: float, pitch: float, hw: float, lift: float, col: Color) -> void:
	var R0 := 0.15
	for dr in [1.0, -1.0]:
		var c := -(y1 - y0) - (a1 - a0) * R0
		while c < (y1 - y0) + (a1 - a0) * R0:
			var run := []
			var w := 0.0
			while w <= (a1 - a0):
				var a := a0 + w
				var y: float = y0 + (y1 - y0) * 0.5 + w * R0 * dr + c
				if y >= y0 and y <= y1 and bool(inside.call(a, y)):
					run.append(Vector2(a, y))
				else:
					if run.size() >= 2:
						_net_run(k, keys, run, hw, lift, col)
					run = []
				w += 0.035
			if run.size() >= 2:
				_net_run(k, keys, run, hw, lift, col)
			c += pitch


static func _net_run(k, keys: Array, run: Array, hw: float, lift: float, col: Color) -> void:
	var pts := []
	var ou := []
	for q in run:
		var e: Array = _sa(keys, q.x, q.y, lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, 0.0012, col)


## Bel rulosu: dikişlerle boğumlanan kalın dolgu halka
static func _roll(k, keys: Array, y: float, R: float, lobes: int, add: float, col: Color) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var na := 96
	var rows := []
	var cc := []
	for j in 9:
		var v := float(j) / 8.0
		var ro := []
		var cr := []
		for i in na:
			var a := TAU * i / na - PI
			var p := 1.0 - 0.34 * pow(absf(cos(a * lobes * 0.5)), 16.0)
			var o: float = add + R * sin(v * PI) * p
			var q: Vector2 = SE.El.sup(a, float(s[1]) + o, float(s[2]) + o, float(s[3]) - o)
			ro.append(Vector3(q.x, y + R * 1.05 * cos(v * PI), q.y))
			cr.append(col.darkened(clampf((1.0 - p) * 1.1 + (1.0 - sin(v * PI)) * 0.14, 0.0, 0.42)))
		rows.append(ro)
		cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return k.torso_skin(p.y))


## Küçük düğme / perçin: yüzeyden kabaran kubbe
static func _stud(k, c: Vector3, o: Vector3, r: float, col: Color, bones: Array) -> void:
	var up := Vector3.UP - o * Vector3.UP.dot(o)
	if up.length() < 0.1:
		up = Vector3.BACK - o * Vector3.BACK.dot(o)
	up = up.normalized()
	var ri := up.cross(o).normalized()
	var rows := []
	for j in 5:
		var t := float(j) / 4.0
		var rr := r * cos(t * PI * 0.5)
		var h := r * 0.55 * sin(t * PI * 0.5)
		var ro := []
		for i in 12:
			var a := TAU * i / 12.0
			ro.append(c + o * h + (ri * cos(a) + up * sin(a)) * maxf(rr, 0.0003))
		rows.append(ro)
	var fn: Vector3 = -((rows[0][1] as Vector3) - (rows[0][0] as Vector3)).cross((rows[1][1] as Vector3) - (rows[0][0] as Vector3))
	if fn.dot((rows[0][0] as Vector3) - c) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, true, func(_i, j, _p): return col.lightened(0.14) if j >= 3 else col, func(_i, _j, _p): return bones)


## Kol oyuğu biyesi: gövde yüzeyinde kolu çevreleyen dikiş
static func _hole(k, keys: Array, sg: float, y: float, ha: float, hy: float, hw: float, lift: float, col: Color) -> void:
	var pts := []
	var ou := []
	for i in 28:
		var t := TAU * i / 28.0
		var e: Array = _sa(keys, sg * (PI * 0.5 + ha * cos(t)), y + hy * sin(t), lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, 0.003, col, true)


## Açık bacak / kol: bedenin kendi kalınlığında ten
static func _bare(k, l: Dictionary, col: Color, s0 := 0.0, s1 := 1.0) -> void:
	_lt(k, l, func(_s, _a): return 0.001, func(_s, _a, ins): return col.darkened(0.3) if ins else col, s0, s1, 26, 16)


# ------------------------------------------------------------------ Kumo Kenshi (ref Darui_full_body): koyu kolsuz üst + dik yaka, tek omuzdan verev inen beyaz göğüslük, kalçaya sarılı bez + açık kahve astar kanadı, bol pantolon, bilek sargısı
static func _kumo_kenshi(k) -> void:
	var dk := Color(0.27, 0.27, 0.25)
	var wh := Color(0.87, 0.86, 0.82)
	var tr := Color(0.58, 0.53, 0.43)
	var pn := Color(0.22, 0.22, 0.19)
	var tn := Color(0.42, 0.36, 0.26)
	var wr := Color(0.88, 0.86, 0.8)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	SE.body_layer(k, [[N + 0.03, nk.x, nk.y, nk.z], [N - 0.05, ch.x * 0.74, ch.y * 0.8, ch.z * 0.86], [C - 0.06, ch.x * 0.92, ch.y * 0.98, ch.z * 0.95]], 8, 28, func(_i, _j, _p): return skc)
	SE.body_layer(k, [_kp(bl, H + 0.09, 0.004), _kp(hp, H - 0.05, 0.014), [H - 0.14, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 8, 32, func(_i, _j, _p): return pn.darkened(0.2))
	var tk := [_kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], _kp(ch, C - 0.03, 0.022), _kp(wa, H + 0.12, 0.03), _kp(bl, H + 0.04, 0.028)]
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_bare(k, ar, skc)
		_wraps(k, ar, 0.83, 0.97, 6, 0.008, 0.0125, wr, 0.006)
		var kn: float = le["kn"]
		var pf := func(s: float, a: float) -> float:
			return 0.0055 * sin(a * 3.0 + s * 4.0 + 0.7) + 0.0028 * sin(a * 7.0 - s * 6.0) + 0.0035 * exp(-pow((s - kn) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		_lt(k, le, func(s, a): return lerpf(0.014, 0.03, smoothstep(0.1, 0.72, float(s))) - 0.008 * smoothstep(0.95, 1.0, float(s)) + float(pf.call(float(s), float(a))), func(s, a, ins):
			return pn.darkened(0.45) if ins else _fs(pn, float(pf.call(float(s), float(a))), 16.0), 0.0, 1.0, 38, 24)
	# koyu üst: V yaka tek yüzey
	var yv: float = C - 0.015
	var tf := func(a: float, y: float, _v: float) -> float:
		return 0.006 * sin(a * 5.0 + y * 13.0) + 0.004 * sin(a * 9.0 + 1.0) * smoothstep(C - 0.05, H + 0.1, y)
	var g := _cl(k, {"keys": tk, "ny": 30, "na": 92, "top": func(a): return lerpf(yv, N + 0.012, clampf(absf(float(a)) / 0.62, 0.0, 1.0)), "hem": func(_a): return H + 0.04, "fold": tf, "col": func(_a, _y, _v): return dk})
	var ve := []
	for p in g["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.66:
			ve.append(p)
	_tr(k, ve, 0.0055, 0.003, dk.lightened(0.16))
	# dik yaka: arkası yüksek, önü açık
	var ck := [[N + 0.115, nk.x + 0.03, nk.y + 0.03, nk.z - 0.05], [N + 0.0, nk.x + 0.036, nk.y + 0.032, nk.z - 0.04]]
	var cg := _cl(k, {"keys": ck, "ny": 7, "na": 34, "rng": func(_v): return Vector2(0.66, TAU - 0.66), "top": func(a): return N + 0.04 + 0.04 * smoothstep(0.7, 2.5, absf(float(a))), "hem": func(_a): return N - 0.008, "col": func(_a, _y, _v): return dk.lightened(0.05), "skin": func(p): return k.torso_skin(p.y), "th": 0.006})
	_bd(k, cg["top"], 0.005, 0.003, dk.lightened(0.2), false, Callable(), 0.5)
	# beyaz göğüslük: sol omuzdan sağ bele verev kesim
	var pk := []
	for e in tk:
		pk.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.013, float(e[3]) - 0.012])
	var a0 := -1.5
	var a1 := 1.08
	var a2 := PI - 0.2
	var pt := func(a: float) -> float:
		if a <= a1:
			return lerpf(H + 0.075, N - 0.012, clampf((a - a0) / (a1 - a0), 0.0, 1.0))
		return lerpf(N - 0.012, H + 0.09, clampf((a - a1) / (a2 - a1), 0.0, 1.0))
	var pg := _cl(k, {"keys": pk, "ny": 26, "na": 84, "rng": func(_v): return Vector2(a0, a2), "top": func(a): return pt.call(float(a)), "hem": func(_a): return H + 0.04, "fold": func(a, y, _v): return 0.004 * sin(float(a) * 6.0 + float(y) * 11.0), "col": func(_a, _y, _v): return wh, "th": 0.004, "gain": 9.0})
	_tr(k, pg["top"], 0.0075, 0.0034, tr)
	var y_e: float = pt.call(-0.08)
	var ln := [Vector2(-0.08, y_e), Vector2(0.72, lerpf(y_e, H + 0.12, 0.55)), Vector2(1.58, H + 0.115)]
	_line(k, pk, ln, 0.0055, 0.002, 0.003, tr, 8)
	var mid := Vector2(0.56, lerpf(y_e, H + 0.12, 0.43))
	_line(k, pk, [Vector2(-0.5, H + 0.05), mid.lerp(Vector2(-0.5, H + 0.05), 0.5), mid], 0.0055, 0.002, 0.003, tr, 6)
	for i in 4:
		var q0 := Vector2(0.1 + 0.105 * i, lerpf(y_e, H + 0.12, 0.2 + 0.075 * i) + 0.022)
		_line(k, pk, [q0, q0 + Vector2(0.085, 0.036)], 0.004, 0.002, 0.0024, tr.darkened(0.12), 3)
	var be: Array = _sa(pk, a1 - 0.08, N - 0.058, 0.004)
	_stud(k, be[0], be[1], 0.015, tr.lightened(0.18), [["UpperChest", 1.0]])
	_stud(k, (be[0] as Vector3) + (be[1] as Vector3) * 0.006, be[1], 0.0075, wh, [["UpperChest", 1.0]])
	# kalçaya sarılı bez: sağda kısa, solda uzun, verev çekme kıvrımları
	var dr := [_kp(bl, H + 0.06, 0.03), _kp(hp, H - 0.04, 0.042), [H - 0.2, hp.x + 0.058, hp.y + 0.056, hp.z - 0.056], [H - 0.44, hp.x + 0.075, hp.y + 0.07, hp.z - 0.07]]
	var dh := func(a: float) -> float:
		return H - 0.165 - 0.19 * exp(-pow((a - 1.05) / 0.72, 2.0)) - 0.05 * exp(-pow(a / 0.65, 2.0)) - 0.05 * exp(-pow(absf(a) - PI, 2.0))
	var dt := func(a: float) -> float: return H + 0.05 + 0.003 * sin(a * 2.0 + 0.6)
	var df := func(a: float, y: float, v: float) -> float:
		return (0.3 + 0.7 * v) * (0.022 * sin(a * 3.2 + (y - H) * 17.0 + 0.5) + 0.011 * sin(a * 7.0 - y * 12.0)) + 0.012 * pow(1.0 - v, 3.0) * sin(a * 13.0)
	# açık kahve astar kanadı: bezin altından sol yana iner
	var fl := []
	for e in dr:
		fl.append([e[0], float(e[1]) - 0.006, float(e[2]) - 0.006, float(e[3]) + 0.006])
	var fg := _cl(k, {"keys": fl, "ny": 16, "na": 26, "rng": func(_v): return Vector2(1.15, 2.4), "top": func(_a): return H + 0.01, "hem": func(a):
		var t: float = clampf((float(a) - 1.15) / 1.25, 0.0, 1.0)
		return lerpf(H - 0.2, H - 0.43, smoothstep(0.0, 0.42, t)) if t < 0.42 else lerpf(H - 0.43, H - 0.2, (t - 0.42) / 0.58), "fold": func(a, _y, v): return 0.012 * float(v) * sin(float(a) * 5.0), "col": func(_a, _y, _v): return tn, "inner": tn.darkened(0.35)})
	_tr(k, fg["hem"], 0.005, 0.0025, tn.darkened(0.2))
	var dg := _cl(k, {"keys": dr, "ny": 30, "na": 100, "top": dt, "hem": dh, "fold": df, "col": func(_a, _y, _v): return pn.lightened(0.05), "gain": 5.5, "th": 0.006})
	var hm := []
	for p in dg["hem"]:
		hm.append(p + Vector3(0, 0.009, 0))
	_tr(k, hm, 0.0032, 0.0016, pn.darkened(0.25), true)
	_sash(k, dr, H + 0.05, 0.014, 0.003, tr, 0.1)
	_hole(k, pk, 1.0, C + 0.0, 0.5, 0.095, 0.0065, 0.002, tr)
	_hole(k, tk, -1.0, C + 0.0, 0.5, 0.095, 0.0055, 0.002, dk.lightened(0.12))


# ------------------------------------------------------------------ Kumo Kunoichi (ref Samui_full_body): geniş V yakalı gri kısa üst + yarım geniş kol, göğüste file, açık renk bel parçası, verev gri üst etek + koyu dar etek, bordo kolluk ve bağ, sivri ağızlı koyu konç
static func _kumo_kunoichi(k) -> void:
	var gy := Color(0.5, 0.5, 0.52)
	var dg := Color(0.26, 0.28, 0.27)
	var wm := Color(0.84, 0.83, 0.88)
	var mr := Color(0.5, 0.1, 0.2)
	var bt := Color(0.29, 0.31, 0.3)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var ub: Vector3 = k.M(C - 0.12, k.UA)
	var sk_k := [[N + 0.03, nk.x, nk.y, nk.z], [N - 0.05, ch.x * 0.76, ch.y * 0.8, ch.z * 0.88], [C - 0.03, ch.x + 0.002, ch.y + 0.002, ch.z], [C - 0.125, ub.x, ub.y, ub.z]]
	SE.body_layer(k, sk_k, 14, 36, func(_i, _j, _p): return skc)
	SE.body_layer(k, [_kp(bl, H + 0.03, 0.002), _kp(hp, H - 0.05, 0.01), [H - 0.14, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 8, 32, func(_i, _j, _p): return dg.darkened(0.25))
	# koyu göğüslük: ortası filelik açıklıkla
	var ik := [[C + 0.04, ch.x * 0.96, ch.y * 0.93, ch.z * 0.98], _kp(ch, C - 0.03, 0.006), _kp(ub, C - 0.125, 0.006)]
	var yo: float = C - 0.1
	var it := func(a: float) -> float: return lerpf(yo, C + 0.032, clampf(absf(a) / 0.46, 0.0, 1.0))
	_cl(k, {"keys": ik, "ny": 10, "na": 64, "top": it, "hem": func(_a): return C - 0.125, "col": func(_a, _y, _v): return dg, "skin": func(p): return k.torso_skin(p.y), "th": 0.0})
	_net_patch(k, sk_k, func(a, y): return float(y) > float(it.call(float(a))) - 0.004 and float(y) < C + 0.03, -0.5, 0.5, yo, C + 0.03, 0.021, 0.0016, 0.004, dg.darkened(0.3))
	_line(k, ik, [Vector2(-0.5, C + 0.03), Vector2(0.0, C + 0.024), Vector2(0.5, C + 0.03)], 0.006, 0.003, 0.003, dg, 6)
	# uzuvlar
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_bare(k, ar, skc)
		_bare(k, le, skc)
		var kn: float = le["kn"]
		var sf := func(s: float, a: float) -> float: return (0.0015 + 0.005 * s) * sin(a * 4.0 + s * 3.0 + 0.6)
		_lt(k, ar, func(s, a): return 0.01 + 0.04 * smoothstep(0.14, 0.46, float(s)) + float(sf.call(float(s), float(a))) - 0.014 * (1.0 - smoothstep(0.0, 0.11, float(s))), func(s, a, ins):
			return gy.darkened(0.42) if ins else _fs(gy, float(sf.call(float(s), float(a))), 26.0), 0.0, 0.5, 20, 22, 0.28)
		# bordo kolluk: dirsek tarafı sivri
		_lts(k, ar, func(s, _a): return 0.006 + 0.012 * (1.0 - smoothstep(0.72, 0.84, float(s))), func(_s, _a, ins): return mr.darkened(0.45) if ins else mr, func(a): return 0.72 - 0.035 * pow(maxf(0.0, cos(float(a))), 2.0), 0.965, 10, 18)
		k.wrap_turn(_lp(ar, 0.955), _ld(ar, 0.955), _lr(ar, 0.955) + 0.008, 0.007, 0.0, mr.darkened(0.2), _lskin(ar, 0.955))
		# konç: diz altında önde sivri, ayağa iner
		_lts(k, le, func(s, a): return 0.012 + 0.016 * (1.0 - smoothstep(kn + 0.08, kn + 0.3, float(s))) + 0.0016 * sin(float(a) * 3.0 + float(s) * 22.0) - 0.002 * smoothstep(0.9, 1.0, float(s)), func(s, _a, ins):
			return bt.darkened(0.4) if ins else bt.darkened(0.08 * smoothstep(0.86, 0.95, float(s))), func(a): return kn + 0.15 - 0.105 * pow(maxf(0.0, cos(float(a))), 3.0), 1.0, 22, 22)
	# gri üst: V yaka, göğüs altında biter
	var kt := [_kp(nk, N + 0.012, 0.028), [N - 0.055, ch.x * 0.98, ch.y * 0.9, ch.z * 1.03], _kp(ch, C - 0.03, 0.02), _kp(ub, C - 0.135, 0.02)]
	var e0 := 1.2
	var yap: float = C - 0.1
	var vt := func(a: float) -> float:
		var x: float = clampf(absf(a) / e0, 0.0, 1.0)   # omuza yumuşak varır: kenar boyna doğru sivrilmez
		return lerpf(yap, N + 0.012, 0.5 * x + 0.5 * smoothstep(0.0, 1.0, x))
	_cl(k, {"keys": kt, "ny": 20, "na": 92, "top": vt, "hem": func(_a): return C - 0.135, "fold": func(a, y, _v): return 0.007 * sin(float(a) * 7.0 + float(y) * 14.0), "col": func(_a, _y, _v): return gy, "skin": func(p): return k.torso_skin(p.y)})
	var pth := []
	for i in 8:   # omuz köşesi yuvarlak geçer: bant sivrilmez
		var a: float = lerpf(0.02, e0 * 0.8, float(i) / 7.0)
		pth.append(Vector2(a, float(vt.call(a))))
	for i in range(0, 11):
		pth.append(Vector2(lerpf(e0 + 0.22, TAU - e0 - 0.22, float(i) / 10.0), N + 0.014))
	for i in range(7, -1, -1):
		var a: float = lerpf(0.02, e0 * 0.8, float(i) / 7.0)
		pth.append(Vector2(TAU - a, float(vt.call(a))))
	_band(k, kt, pth, func(_t): return 0.024, 0.006, gy.darkened(0.12), 3, 5)
	# bel parçası + iki verev dikiş
	var mk := [_kp(ub, C - 0.115, 0.012), _kp(wa, H + 0.12, 0.012), _kp(bl, H + 0.035, 0.016)]
	_cl(k, {"keys": mk, "ny": 16, "na": 72, "top": func(_a): return C - 0.115, "hem": func(_a): return H + 0.035, "fold": func(a, y, _v): return 0.006 * sin(float(a) * 8.0 + float(y) * 20.0), "col": func(_a, _y, _v): return wm, "skin": func(p): return k.torso_skin(p.y), "th": 0.0, "gain": 9.0})
	_line(k, mk, [Vector2(-1.15, C - 0.125), Vector2(-0.1, H + 0.15), Vector2(0.72, H + 0.06)], 0.0042, 0.002, 0.0026, wm.darkened(0.32), 6)
	_line(k, mk, [Vector2(-0.1, H + 0.15), Vector2(0.32, H + 0.2), Vector2(1.05, C - 0.125)], 0.0042, 0.002, 0.0026, wm.darkened(0.32), 6)
	# koyu dar etek
	var sk2 := [_kp(bl, H + 0.03, 0.014), _kp(hp, H - 0.05, 0.018), [H - 0.32, hp.x + 0.03, hp.y + 0.032, hp.z - 0.032]]
	var sg := _cl(k, {"keys": sk2, "ny": 16, "na": 72, "top": func(_a): return H + 0.025, "hem": func(_a): return H - 0.31, "fold": func(a, _y, v): return 0.009 * float(v) * sin(float(a) * 6.0 + 0.8), "col": func(_a, _y, _v): return dg})
	var h2 := []
	for p in sg["hem"]:
		h2.append(p + Vector3(0, 0.008, 0))
	_tr(k, h2, 0.0028, 0.0014, dg.darkened(0.3), true)
	# gri üst etek: sağda kısa, solda uzun verev uç
	var ov := [_kp(bl, H + 0.056, 0.02), _kp(hp, H - 0.05, 0.036), [H - 0.32, hp.x + 0.062, hp.y + 0.056, hp.z - 0.056]]
	var oh := func(a: float) -> float: return H - 0.185 - 0.085 * sin(a + 0.15) * (0.55 + 0.45 * cos(a * 0.5))
	var of := func(a: float, y: float, v: float) -> float:
		return v * (0.03 * sin(a * 3.4 + (y - H) * 15.0 + 1.0) + 0.014 * sin(a * 7.0 + 0.5))
	var og := _cl(k, {"keys": ov, "ny": 20, "na": 92, "top": func(_a): return H + 0.05, "hem": oh, "fold": of, "col": func(_a, _y, _v): return gy, "gain": 7.0, "th": 0.006})
	var h3 := []
	for p in og["hem"]:
		h3.append(p + Vector3(0, 0.009, 0))
	_tr(k, h3, 0.0034, 0.0016, gy.darkened(0.28), true)
	_sash(k, ov, H + 0.05, 0.017, 0.004, gy.darkened(0.08), 0.12)
	# yan bağ: bordo sert kısa kuşak ucu
	var kq: Array = _sa(ov, 1.5, H + 0.05, 0.016)
	var kc: Vector3 = kq[0]
	_boxr(k, kc + Vector3(0.012, -0.002, 0.0), Vector3(0.0, 0.0, 0.034), Vector3(0.006, 0.021, 0.0), Vector3(0.015, -0.002, 0.0), mr, [["Hips", 0.5], ["Spine", 0.5]], 0.4)


# ------------------------------------------------------------------ Aogiri (ref Ao's_Appearance): baldıra inen deniz yeşili palto, krem şal yaka ve ön pervaz, tek düğme, koyu fitilli boğazlı kazak, dar koyu pantolon
static func _aogiri(k) -> void:
	var tl := Color(0.09, 0.3, 0.33)
	var cr := Color(0.86, 0.82, 0.68)
	var sw := Color(0.24, 0.23, 0.22)
	var pn := Color(0.13, 0.14, 0.18)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# fitilli kazak + katlı boğaz
	var rib := func(a: float, _y: float) -> float: return 0.012 * sin(a * 42.0)
	SE.body_layer(k, [_kp(nk, N + 0.03, 0.012), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.92], _kp(ch, C - 0.03, 0.01), _kp(wa, H + 0.12, 0.012), _kp(hp, H - 0.09, 0.012)], 24, 84, func(i, _j, _p): return sw.darkened(0.2) if i % 2 == 1 else sw.lightened(0.05), rib)
	var nk_k := [_kp(nk, N + 0.1, 0.018), _kp(nk, N + 0.0, 0.024)]
	_cl(k, {"keys": nk_k, "ny": 8, "na": 60, "top": func(_a): return N + 0.092, "hem": func(_a): return N + 0.005, "fold": func(a, y, _v): return 0.03 * sin(float(a) * 18.0) + 0.02 * sin((float(y) - N) * 78.0), "col": func(_a, _y, _v): return sw, "skin": func(p): return k.torso_skin(p.y), "gain": 4.0, "th": 0.004})
	var hem: float = K - 0.17
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var pf := func(s: float, a: float) -> float: return 0.0028 * _lf(s, a, 0.7) + 0.003 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 34.0)
		_lt(k, le, func(s, a): return 0.009 + float(pf.call(float(s), float(a))), func(s, a, ins):
			return pn.darkened(0.4) if ins else _fs(pn, float(pf.call(float(s), float(a))), 34.0), 0.0, 1.0, 34, 18)
		_lt(k, ar, func(_s, _a): return 0.003, func(_s, _a, ins): return sw.darkened(0.3) if ins else sw, 0.35, 1.0, 16, 14)   # kazak kolu: yen ağzından bakınca boşluk kalmaz
		# palto kolu: omuzdan bileğe bol, bilekte dönük manşet
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.0022 * _lf(s, a, 1.9) * (0.6 + s) + 0.0045 * exp(-pow((s - en) / 0.075, 2.0)) * sin(a * 3.0 + s * 38.0)
		_lt(k, ar, func(s, a): return 0.016 + 0.014 * smoothstep(0.1, 0.9, float(s)) + float(sf.call(float(s), float(a))) - 0.014 * (1.0 - smoothstep(0.0, 0.11, float(s))), func(s, a, ins):
			return tl.darkened(0.48) if ins else _fs(tl, float(sf.call(float(s), float(a))), 26.0), 0.0, 0.93, 32, 22, 0.45)
		_lt(k, ar, func(s, a): return 0.0345 + 0.0015 * sin(float(a) * 5.0 + float(s)), func(_s, _a, ins): return tl.darkened(0.45) if ins else tl.darkened(0.1), 0.865, 0.93, 3, 22)
	# palto
	var keys := [_kp(nk, N + 0.015, 0.036, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.07], _kp(ch, C - 0.03, 0.04), _kp(wa, H + 0.12, 0.042), _kp(hp, H - 0.04, 0.046), [K + 0.05, hp.x + 0.072, hp.y + 0.075, hp.z - 0.08], [hem, hp.x + 0.098, hp.y + 0.09, hp.z - 0.1]]
	var yb: float = H + 0.145
	var yt: float = N + 0.015
	var e_y := func(y: float) -> float:
		if y >= yb:
			return lerpf(0.0, 0.64, pow(clampf((y - yb) / (yt - yb), 0.0, 1.0), 0.8))
		return lerpf(0.0, 0.2, clampf((yb - y) / (yb - hem), 0.0, 1.0))
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var w: float = exp(-pow((y - (H + 0.13)) / 0.07, 2.0))
		return t * t * (0.05 * sin(a * 5.0 + 0.8) + 0.024 * sin(a * 11.0 + 2.1)) + w * 0.016 * sin(a * 9.0 + 0.4) + (1.0 - t) * 0.005 * sin(a * 4.0 + y * 12.0)
	_cur_long = true
	var g := _cl(k, {"keys": keys, "ny": 64, "na": 112, "rng": func(v):
			var e: float = float(e_y.call(lerpf(yt, hem, float(v))))
			return Vector2(e, TAU - e), "top": func(_a): return yt, "hem": func(_a): return hem, "fold": fold, "col": func(_a, _y, _v): return tl, "inner": tl.darkened(0.4), "th": 0.007, "gain": 6.0})
	var hm := []
	for p in g["hem"]:
		hm.append(p + Vector3(0, 0.014, 0))
	_tr(k, hm, 0.003, 0.0015, tl.darkened(0.3))
	# krem şal yaka: etekten düğmeye dar pervaz, göğüste genişler, ense üzerinden geçer
	var pth := []
	for i in 8:
		var y: float = lerpf(hem + 0.004, yb, float(i) / 7.0)
		pth.append(Vector2(float(e_y.call(y)) - 0.005, y))
	for i in range(1, 9):
		var y: float = lerpf(yb, yt, float(i) / 8.0)
		pth.append(Vector2(float(e_y.call(y)) - 0.005, y))
	var nb := 10
	for i in range(1, nb):
		pth.append(Vector2(lerpf(0.635, TAU - 0.635, float(i) / nb), yt + 0.006))
	for i in range(8, 0, -1):
		var y: float = lerpf(yb, yt, float(i) / 8.0)
		pth.append(Vector2(TAU - float(e_y.call(y)) + 0.005, y))
	for i in range(7, -1, -1):
		var y: float = lerpf(hem + 0.004, yb, float(i) / 7.0)
		pth.append(Vector2(TAU - float(e_y.call(y)) + 0.005, y))
	var nt := float(pth.size() - 1)
	var u0: float = 7.0 / nt
	var u1: float = 14.0 / nt
	var wf := func(t: float) -> float:
		var q: float = minf(t, 1.0 - t)
		if q < u0:
			return 0.024
		return lerpf(0.024, 0.078, smoothstep(u0, u1, q)) - 0.022 * smoothstep(u1 + 0.02, 0.36, q)
	_band(k, keys, pth, wf, 0.01, cr, 3, 7, 0.08, 0.12)
	# düğme + cepler + arka dikiş
	var bq: Array = _sa(keys, 0.05, yb, 0.008)
	_stud(k, bq[0], bq[1], 0.014, Color(0.62, 0.6, 0.52), [["Spine", 0.5], ["Hips", 0.5]])
	for sg in [1.0, -1.0]:
		var a: float = sg * 0.98
		_line(k, keys, [Vector2(a - 0.14 * sg, H - 0.03), Vector2(a + 0.14 * sg, H - 0.07)], 0.0085, 0.003, 0.003, tl.darkened(0.14), 3, fold)
	_line(k, keys, [Vector2(PI, N - 0.03), Vector2(PI, H), Vector2(PI, hem + 0.02)], 0.0024, 0.002, 0.0014, tl.darkened(0.32), 8)
	_cur_long = false


# ------------------------------------------------------------------ Iwa Kunoichi (ref Kurotsuchi_Online, Part_II): kızıl boğazlı iç + tek kol, dikişli kahve yelek + perçinli omuzluk, bel rulosu ve kese, kızıl ön etek + yan peşkir, arkada arduvaz peşkir, file çorap
static func _iwa_kunoichi(k) -> void:
	var rd := Color(0.46, 0.15, 0.16)
	var rm := Color(0.39, 0.13, 0.15)
	var br := Color(0.34, 0.29, 0.19)
	var bd := Color(0.25, 0.21, 0.13)
	var sl := Color(0.22, 0.31, 0.34)
	var nt := Color(0.15, 0.14, 0.14)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	_inner(k, b, func(_i, _j, _p): return rd, 0.008)
	SE.body_layer(k, [_kp(bl, H + 0.05, 0.008), _kp(hp, H - 0.05, 0.012), [H - 0.13, hp.x * 0.76, hp.y * 0.78, hp.z * 0.78]], 8, 32, func(_i, _j, _p): return nt)
	# dik boğaz: iki kat kıvrık
	var nc := [_kp(nk, N + 0.1, 0.014), _kp(nk, N + 0.0, 0.022)]
	_cl(k, {"keys": nc, "ny": 8, "na": 40, "top": func(_a): return N + 0.092, "hem": func(_a): return N - 0.004, "fold": func(a, y, _v): return 0.03 * sin((float(y) - N) * 66.0) + 0.01 * sin(float(a) * 5.0), "col": func(_a, _y, _v): return rd, "gain": 3.0, "skin": func(p): return k.torso_skin(p.y), "th": 0.004})
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		if sd == "Left":   # kaynakta tek kol kızıl, diğer omuz açık
			var en: float = ar["kn"]
			var sf := func(s: float, a: float) -> float: return 0.0022 * _lf(s, a, 1.1) + 0.0042 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 38.0)
			_lt(k, ar, func(s, a): return 0.008 + float(sf.call(float(s), float(a))), func(s, a, ins):
				return rd.darkened(0.45) if ins else _fs(rd, float(sf.call(float(s), float(a))), 34.0), 0.0, 0.965, 30, 18)
		else:
			_bare(k, ar, skc)
			_armhole(k, ar, 0.13, 0.005, 0.007, rd)
		_lt(k, le, func(_s, _a): return 0.002, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc.lerp(Color(0.5, 0.44, 0.4), 0.16), 0.0, 1.0, 26, 16)
		_net_limb(k, le, 0.03, 0.985, 0.0035, 13, 0.036, 0.0017, nt)
		k.wrap_turn(_lp(le, 0.985), _ld(le, 0.985), _lr(le, 0.985) + 0.004, 0.007, 0.0, nt, _lskin(le, 0.985))
	# dikişli yelek
	var vk := [_kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 0.99, ch.y * 0.92, ch.z * 1.03], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.12, 0.03), _kp(bl, H + 0.075, 0.03)]
	var qp: float = 0.058
	var vf := func(a: float, y: float, _v: float) -> float:
		var q: float = absf(sin((y - H) * PI / qp))
		var z: float = exp(-pow(a / 0.045, 2.0))
		return 0.026 * (pow(q, 0.45) - 0.72) * smoothstep(N - 0.03, N - 0.08, y) - 0.02 * z
	var vg := _cl(k, {"keys": vk, "ny": 56, "na": 84, "top": func(_a): return N + 0.012, "hem": func(_a): return H + 0.075, "fold": vf, "col": func(_a, _y, _v): return br, "skin": func(p): return k.torso_skin(p.y), "gain": 5.0, "th": 0.0})
	_bd(k, vg["top"], 0.009, 0.005, bd, true, Callable(), 0.45)
	var zp := []
	for j in 22:
		zp.append(_sa(vk, 0.0, lerpf(N - 0.012, H + 0.09, float(j) / 21.0), 0.0015)[0])
	_tr(k, zp, 0.0042, 0.0026, Color(0.66, 0.64, 0.6))
	# dik yelek yakası: omuzdan boyna kalkar
	var vc := [[N + 0.062, nk.x + 0.05, nk.y + 0.05, nk.z - 0.055], [N + 0.002, nk.x + 0.05, nk.y + 0.046, nk.z - 0.05]]
	var cg := _cl(k, {"keys": vc, "ny": 5, "na": 34, "rng": func(_v): return Vector2(0.42, TAU - 0.42), "top": func(a): return N + 0.03 + 0.03 * smoothstep(0.5, 1.8, absf(float(a))), "hem": func(_a): return N - 0.004, "col": func(_a, _y, _v): return br, "skin": func(p): return k.torso_skin(p.y), "th": 0.009})
	_bd(k, cg["top"], 0.006, 0.0035, bd, false, Callable(), 0.6)
	# omuzluk: kalın, önde ve arkada perçin
	for sg in [1.0, -1.0]:
		var c0 := Vector3(sg * (ch.x * 0.82 + 0.018), N - 0.02, -0.002)
		var ux := Vector3(sg * 0.062, -0.019, 0.0)
		var uz := Vector3(sg * 0.006, 0.02, 0.0)
		_boxr(k, c0, ux, Vector3(0.0, 0.0, 0.083), uz, br.darkened(0.05), [["UpperChest", 1.0]], 0.46)
		var rq: Vector3 = c0 + ux * 0.2 + Vector3(0.0, 0.006, 0.0)
		for z in [0.052, -0.052]:
			_stud(k, rq + Vector3(0.0, 0.023, z), Vector3(0.0, 1.0, 0.25 * signf(z)).normalized(), 0.0095, Color(0.68, 0.66, 0.6), [["UpperChest", 1.0]])
		# kol yuvası kenarı
		_tr(k, [_sa(vk, sg * 1.25, C + 0.05, 0.002)[0], _sa(vk, sg * 1.45, C - 0.03, 0.003)[0], _sa(vk, sg * 1.5, C - 0.1, 0.003)[0], _sa(vk, sg * 1.5, H + 0.13, 0.003)[0]], 0.006, 0.003, bd)
	# kısa kızıl iç etek: yanlarda kalçayı kapatır, peşkirler üstüne biner
	var ue := [_kp(bl, H + 0.09, 0.012), _kp(hp, H - 0.05, 0.018), [H - 0.2, hp.x + 0.02, hp.y + 0.02, hp.z - 0.02]]
	_cl(k, {"keys": ue, "ny": 12, "na": 64, "top": func(_a): return H + 0.08, "hem": func(_a): return H - 0.17, "col": func(_a, _y, _v): return rd.darkened(0.08)})
	# etek parçaları
	var lo := [_kp(bl, H + 0.1, 0.022), _kp(hp, H - 0.05, 0.03), [H - 0.3, hp.x + 0.062, hp.y + 0.06, hp.z - 0.06], [H - 0.56, hp.x + 0.08, hp.y + 0.075, hp.z - 0.075]]
	var pc := [[-0.82, 0.82, H - 0.215, rd, 0.0], [-1.72, -0.72, H - 0.52, rm, 0.006], [PI - 0.86, PI + 0.86, H - 0.5, sl, 0.0]]
	for e in pc:
		var a0: float = e[0]
		var a1: float = e[1]
		var c0: float = (a0 + a1) * 0.5
		var hy: float = e[2]
		var cc: Color = e[3]
		var ad: float = e[4]
		var pg := _cl(k, {"keys": lo, "ny": 22, "na": 34, "lift": ad, "rng": func(_v): return Vector2(a0, a1), "top": func(_a): return H + 0.085, "hem": func(a):
				var w: float = wrapf(float(a) - c0, -PI, PI)
				return hy + 0.018 * pow(w / 0.9, 2.0), "fold": func(a, y, v): return float(v) * (0.018 * sin(float(a) * 6.0 + c0 * 3.0) + 0.008 * sin(float(a) * 13.0 + float(y) * 6.0)), "col": func(_a, _y, _v): return cc, "th": 0.005})
		var hm := []
		for p in pg["hem"]:
			hm.append(p + Vector3(0, 0.011, 0))
		_tr(k, hm, 0.003, 0.0015, cc.darkened(0.3))
	# bel rulosu ve kese
	_roll(k, vk, H + 0.082, 0.021, 14, 0.002, br.darkened(0.04))
	_patch(k, vk, -0.085, 0.085, H + 0.112, H + 0.05, true, 0.036, br.lightened(0.04), 0.14, 14, 9, func(p): return k.torso_skin(p.y))
	var pf: Array = _sa(vk, 0.0, H + 0.094, 0.04)
	_bd(k, [_fp(vk, -0.078, H + 0.094, true, 0.036)[0], _fp(vk, 0.0, H + 0.094, true, 0.04)[0], _fp(vk, 0.078, H + 0.094, true, 0.036)[0]], 0.0028, 0.0016, bd)
	_stud(k, pf[0], pf[1], 0.0075, Color(0.68, 0.66, 0.6), [["Hips", 0.5], ["Spine", 0.5]])


# ------------------------------------------------------------------ Kuro Iryō (ref Shizune_full, Shizune_Infobox): siyah kimono, krem kat yaka, göğüste kızıl bant + file iç, geniş kol, açık mor geniş obi, önü yırtmaçlı uzun etek
static func _kuro_iryo(k) -> void:
	var kd := Color(0.13, 0.13, 0.16)
	var cr := Color(0.86, 0.82, 0.72)
	var ob := Color(0.64, 0.59, 0.74)
	var rj := Color(0.5, 0.16, 0.17)
	var ng := Color(0.56, 0.54, 0.54)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.06, 0.3)
	var yo: float = H + 0.095
	var sk_k := [[N + 0.03, nk.x, nk.y, nk.z], [N - 0.05, ch.x * 0.76, ch.y * 0.8, ch.z * 0.88], _kp(ch, C - 0.03, 0.002), _kp(wa, H + 0.12, 0.004)]
	SE.body_layer(k, sk_k, 14, 36, func(_i, _j, _p): return skc)
	SE.body_layer(k, [_kp(bl, H + 0.08, 0.002), _kp(hp, H - 0.05, 0.012), [H - 0.14, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 8, 32, func(_i, _j, _p): return kd.darkened(0.2))
	# file iç giysi: kızıl bant altında göğsü örter
	var ik := [[C + 0.05, ch.x * 0.93, ch.y * 0.92, ch.z * 0.96], _kp(ch, C - 0.03, 0.006), _kp(wa, H + 0.12, 0.008)]
	var yb: float = C + 0.03
	_cl(k, {"keys": ik, "ny": 14, "na": 56, "top": func(_a): return yb, "hem": func(_a): return H + 0.12, "col": func(_a, _y, _v): return ng.darkened(0.45), "skin": func(p): return k.torso_skin(p.y), "th": 0.0})
	_net_patch(k, ik, func(_a, _y): return true, -0.7, 0.7, C - 0.14, yb - 0.004, 0.019, 0.0017, 0.003, ng)
	_line(k, ik, [Vector2(-0.8, yb + 0.002), Vector2(0.0, yb - 0.002), Vector2(0.8, yb + 0.002)], 0.0095, 0.003, 0.0034, rj, 6)
	# kimono üstü: sol kanat sağın üstüne biner
	var keys := [_kp(nk, N + 0.018, 0.034), [N - 0.05, ch.x * 1.02, ch.y * 0.92, ch.z * 1.06], _kp(ch, C - 0.03, 0.036), _kp(wa, H + 0.13, 0.05), _kp(bl, yo - 0.03, 0.024)]
	var yt: float = N + 0.018
	var yc: float = C - 0.16
	var e1 := func(y: float) -> float: return lerpf(-0.3, 0.56, pow(clampf((y - yc) / (yt - yc), 0.0, 1.0), 0.9))
	var e2 := func(y: float) -> float: return lerpf(-0.05, 0.56, pow(clampf((y - yc) / (yt - yc), 0.0, 1.0), 0.9))
	var uf := func(a: float, y: float, _v: float) -> float:
		var nr: float = smoothstep(C - 0.1, yo, y)
		return (nr * (0.028 * sin(a * 9.0 + 1.0) + 0.012 * sin(a * 16.0)) + 0.006 * sin(a * 3.0 + y * 9.0)) * smoothstep(yo + 0.05, yo + 0.11, y)
	_cl(k, {"keys": keys, "ny": 30, "na": 84, "rng": func(v):
			var y: float = lerpf(yt, yo - 0.03, float(v))
			return Vector2(float(e1.call(y)), TAU - float(e2.call(y))), "top": func(_a): return yt, "hem": func(_a): return yo - 0.03, "fold": uf, "col": func(_a, _y, _v): return kd, "skin": func(p): return k.torso_skin(p.y), "gain": 7.5, "th": 0.005})
	# krem kat yaka: sol kanat kuşağa iner, ense üzerinden geçer
	var pth := []
	for i in 10:
		var y: float = lerpf(yo, yt, float(i) / 9.0)
		pth.append(Vector2(float(e1.call(y)), y))
	for i in range(1, 10):
		pth.append(Vector2(lerpf(0.56, TAU - 0.56, float(i) / 10.0), yt + 0.004))
	for i in range(9, 0, -1):
		var y: float = lerpf(lerpf(yc, yt, 0.22), yt, float(i) / 9.0)
		pth.append(Vector2(TAU - float(e2.call(y)), y))
	_band(k, keys, pth, func(_t): return 0.036, 0.007, cr, 3, 6, 0.06, 0.1)
	# etek: obi altından, önde açılan uzun yırtmaç
	var hem: float = K - 0.2
	var sk := [_kp(bl, yo, 0.034), _kp(hp, H - 0.04, 0.04), [H - 0.32, hp.x + 0.06, hp.y + 0.06, hp.z - 0.065], [hem, hp.x + 0.075, hp.y + 0.07, hp.z - 0.09]]
	var ys: float = H - 0.09
	var r1 := func(y: float) -> float: return lerpf(-0.03, 0.46, smoothstep(ys, hem, y))
	var r2 := func(y: float) -> float: return lerpf(-0.03, 0.24, smoothstep(ys, hem, y))
	var sf := func(a: float, y: float, v: float) -> float:
		return v * v * (0.04 * sin(a * 5.0 + 1.3) + 0.018 * sin(a * 11.0 + 0.4)) + (1.0 - v) * 0.012 * sin(a * 9.0 + y * 3.0)
	_cur_long = true
	var sg := _cl(k, {"keys": sk, "ny": 48, "na": 92, "rng": func(v):
			var y: float = lerpf(yo, hem, float(v))
			return Vector2(float(r1.call(y)), TAU - float(r2.call(y))), "top": func(_a): return yo, "hem": func(_a): return hem, "fold": sf, "col": func(_a, _y, _v): return kd, "gain": 6.5, "th": 0.006})
	var hm := []
	for p in sg["hem"]:
		hm.append(p + Vector3(0, 0.012, 0))
	_tr(k, hm, 0.003, 0.0014, kd.lightened(0.14))
	var pa := []
	var pb := []
	for i in 12:
		var y: float = lerpf(hem + 0.006, yo - 0.01, float(i) / 11.0)
		pa.append(Vector2(float(r1.call(y)), y))
		pb.append(Vector2(TAU - float(r2.call(y)), y))
	pb.reverse()
	_band(k, sk, pa, func(_t): return 0.026, 0.004, cr, 3, 4, 0.08, 0.1)
	_band(k, sk, pb, func(_t): return 0.026, 0.004, cr, 3, 4, 0.08, 0.1)
	_cur_long = false
	# kollar: ten + geniş sarkık yen, ağızda krem şerit
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sx: float = ar["sg"]
		_bare(k, ar, skc)
		_bare(k, le, skc)
		var df := func(s: float, a: float) -> float:
			return 0.014 + 0.04 * smoothstep(0.24, 0.68, s) + 0.044 * smoothstep(0.3, 0.74, s) * maxf(0.0, -sin(a) * sx)
		var ff := func(s: float, a: float) -> float: return (0.004 + 0.008 * s) * sin(a * 5.0 + s * 9.0)
		_lt(k, ar, func(s, a): return float(df.call(float(s), float(a))) + float(ff.call(float(s), float(a))) - 0.014 * (1.0 - smoothstep(0.0, 0.11, float(s))), func(s, a, ins):
			return kd.darkened(0.4) if ins else _fs(kd, float(ff.call(float(s), float(a))), 22.0), 0.0, 0.8, 26, 26, 0.5)
		_lt(k, ar, func(s, a): return float(df.call(float(s), float(a))) + float(ff.call(float(s), float(a))) + 0.0035, func(_s, _a, ins): return cr.darkened(0.3) if ins else cr, 0.74, 0.785, 2, 26)
	# obi: geniş, iki kat; önde kordon, arkada yassı düğüm
	var ok := [_kp(bl, H + 0.17, 0.03), _kp(bl, H + 0.02, 0.036)]
	_sash(k, ok, yo, 0.058, 0.01, ob, 0.13)
	_sash(k, ok, yo + 0.02, 0.03, 0.014, ob.lightened(0.07), 0.05)
	_cord(k, _ring_pts(ok, yo - 0.014, 0.021, 64), 0.0042, ob.darkened(0.38), true, Callable(), 1.4)
	var bq: Array = _sa(ok, PI, yo + 0.012, 0.03)
	var bc: Vector3 = bq[0]
	_boxr(k, bc + Vector3(0, 0, -0.008), Vector3(0.1, 0, 0), Vector3(0, 0.05, 0), Vector3(0, 0, -0.024), ob.lightened(0.03), [["Spine", 0.5], ["Hips", 0.5]], 0.42)
	_boxr(k, bc + Vector3(0, 0, -0.032), Vector3(0.024, 0, 0), Vector3(0, 0.054, 0), Vector3(0, 0, -0.01), ob.darkened(0.14), [["Spine", 0.5], ["Hips", 0.5]], 0.4)


# ------------------------------------------------------------------ Uzumaki Kateigi (ref Kushina_Uzumaki_full): krem bluz, kıvrık fermuarlı yaka, kısa kapak kol, geniş askılı uzun A kesim yeşil elbise, sol bilekte koyu bileklik
static func _uzumaki_haha(k) -> void:
	var cm := Color(0.93, 0.91, 0.84)
	var gn := Color(0.31, 0.41, 0.23)
	var nv := Color(0.12, 0.22, 0.3)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return cm, 0.006)
	SE.body_layer(k, [_kp(hp, H + 0.02, 0.004), _kp(hp, H - 0.05, 0.01), [H - 0.14, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 6, 32, func(_i, _j, _p): return gn.darkened(0.5))
	# kıvrık yaka: boynu saran kat + dışa dönük kanat
	var nc := [_kp(nk, N + 0.085, 0.016), _kp(nk, N + 0.0, 0.024), [N - 0.06, ch.x * 0.72, ch.y * 0.8, ch.z * 0.88]]
	_cl(k, {"keys": nc, "ny": 6, "na": 40, "top": func(_a): return N + 0.075, "hem": func(_a): return N + 0.0, "col": func(_a, _y, _v): return cm.darkened(0.04), "skin": func(p): return k.torso_skin(p.y), "th": 0.004})
	var cp := []
	for i in 21:
		cp.append(Vector2(lerpf(0.05, TAU - 0.05, float(i) / 20.0), N + 0.078))
	_band(k, nc, cp, func(t): return 0.075 + 0.03 * pow(cos(float(t) * PI), 6.0), 0.008, cm, 2, 5, 0.04, 0.08)
	var zq := []
	for j in 9:
		zq.append(_sa(nc, 0.0, lerpf(N + 0.075, N - 0.016, float(j) / 8.0), 0.002)[0])
	_bd(k, zq, 0.0032, 0.002, Color(0.55, 0.53, 0.5))
	var zt: Array = _sa(nc, 0.0, N + 0.02, 0.004)
	_boxr(k, zt[0], Vector3(0.004, 0, 0), Vector3(0, 0.009, 0), Vector3(0, 0, 0.002), Color(0.62, 0.6, 0.56), [["Neck", 1.0]], 0.3)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_bare(k, ar, skc)
		_bare(k, le, skc)
		var sf := func(s: float, a: float) -> float: return 0.0026 * sin(a * 5.0 + s * 16.0)
		_lt(k, ar, func(s, a): return 0.012 + 0.024 * smoothstep(0.08, 0.28, float(s)) + float(sf.call(float(s), float(a))), func(s, a, ins):
			return cm.darkened(0.3) if ins else _fs(cm, float(sf.call(float(s), float(a))), 20.0), 0.0, 0.33, 14, 22, 0.2)
	var lw := _limb(k, "Left", false)
	_lt(k, lw, func(_s, _a): return 0.012, func(_s, _a, ins): return nv.darkened(0.4) if ins else nv.lightened(0.05), 0.915, 0.955, 3, 18)
	# elbise: yaka ve kol oyuğu üst kenardan, A kesim tek yüzey
	var hem: float = K - 0.16
	var keys := [_kp(nk, N + 0.01, 0.042, 0.036), [N - 0.055, ch.x * 0.99, ch.y * 0.92, ch.z * 1.03], _kp(ch, C - 0.03, 0.018), [C - 0.13, wa.x + 0.046, ch.y + 0.012, wa.z - 0.034], _kp(wa, H + 0.12, 0.05), _kp(hp, H - 0.04, 0.05), [K + 0.05, hp.x + 0.105, hp.y + 0.1, hp.z - 0.11], [hem, hp.x + 0.115, hp.y + 0.105, hp.z - 0.115]]
	var ns: float = N - 0.012
	var nf: float = C + 0.055
	var nb: float = C + 0.085
	var top := func(a: float) -> float:
		var q: float = absf(a)
		if q < 1.15:
			return lerpf(nf, ns, pow(smoothstep(0.42, 1.0, q), 0.9))
		return lerpf(ns, nb, pow(smoothstep(1.55, 2.5, q), 0.9))
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.1 - y) / (H + 0.1 - hem), 0.0, 1.0)
		var bust: float = exp(-pow((y - (C - 0.125)) / 0.03, 2.0)) * exp(-pow(a / 0.8, 2.0))
		return t * t * (0.046 * sin(a * 6.0 + 0.9) + 0.02 * sin(a * 11.0 + 2.3)) + t * 0.006 * sin(a * 4.0 + 1.4) - bust * 0.008
	_cur_long = true
	var g := _cl(k, {"keys": keys, "ny": 60, "na": 112, "top": top, "hem": func(a): return hem + 0.012 * cos(float(a)), "fold": fold, "col": func(_a, _y, _v): return gn, "gain": 7.0, "th": 0.006})
	_tr(k, g["top"], 0.0065, 0.003, gn.darkened(0.16), true, 0.3)
	var hm := []
	for p in g["hem"]:
		hm.append(p + Vector3(0, 0.016, 0))
	_tr(k, hm, 0.0028, 0.0014, gn.darkened(0.28), true)
	_cur_long = false
