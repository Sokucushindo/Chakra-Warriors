extends RefCounted
## Elle modellenmiş setler, parti d: set_hagoromo, set_oinin, set_konoha_eski, set_iwa_eski, set_sansho, set_kumo_uta. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti a ile aynı yapıdadır (parti dosyaları birbirine bağlı kalmasın diye burada kendi kopyası var).
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_hagoromo", "set_oinin", "set_konoha_eski", "set_iwa_eski", "set_sansho", "set_kumo_uta"]


static func recipe(k, sid: String) -> void:
	_cur_leg = 0.58
	match sid:
		"set_hagoromo": _hagoromo(k)
		"set_oinin": _oinin(k)
		"set_konoha_eski": _konoha_eski(k)
		"set_iwa_eski": _iwa_eski(k)
		"set_sansho": _sansho(k)
		"set_kumo_uta": _kumo_uta(k)


# ------------------------------------------------------------------ ölçü
static func _base(k) -> Dictionary:
	return {"ch": k.M(k.C - 0.03, k.UA), "wa": k.M(k.H + 0.12, k.UA), "hp": k.M(k.H - 0.04, 0.3), "nk": k.M(k.N + 0.02, 0.09)}


static func _kp(m: Vector3, y: float, p: float, pz := -1.0) -> Array:
	var q: float = p if pz < 0.0 else pz
	return [y, m.x + p, m.y + q, m.z - q]


## Kapalı astar: boyundan kalçaya
static func _inner(k, b: Dictionary, colf: Callable, pad := 0.01, y1 := -99.0) -> Array:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := [_kp(nk, k.N + 0.06, 0.008, 0.01), _kp(nk, k.N + 0.02, 0.016), [k.N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], _kp(ch, k.C - 0.03, pad), _kp(b["wa"], k.H + 0.12, pad), _kp(b["hp"], y1 if y1 > -9.0 else k.H - 0.09, pad)]
	SE.body_layer(k, keys, 26, 44, colf)
	return keys


## Bel altı ağırlığı: çekirdeğin kumaş ağırlığı; etek ucu son kurulan kumaştan gelir (üstüne binen şerit / yama aynı ağırlığı alır)
static var _cur_hem := 0.0
static var _cur_leg := 0.58


static func _hs(k, p: Vector3) -> Array:
	return k.cloth_skin(p, _cur_hem, _cur_leg)


static func _fs(c: Color, v: float, gain := 6.0) -> Color:
	return c.darkened(clampf(-v * gain, 0.0, 0.36)) if v < 0.0 else c.lightened(clampf(v * gain * 0.4, 0.0, 0.1))


# ------------------------------------------------------------------ kumaş
## keys üzerinde yüzey. rng(y) -> Vector2(a0, a1) (yoksa kapalı), foldf(a, y, u) -> oransal kabarma, colf(a, y, u, v, p) -> renk.
## Alt uç içe katlanır ve kumaş astarla geri döner (arkadan bakınca delik yok); in_f: astarın boyu (oran).
static func _sheet(k, keys: Array, ny: int, na: int, rng: Callable, foldf: Callable, colf: Callable, th := 0.006, in_f := 1.0, skinf := Callable(), lin := Color(0, 0, 0, 0)) -> Array:
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
		return c0 if j <= ny else (lin if lin.a > 0.0 else c0.darkened(0.42)), func(_i, _j, p): return sf.call(p))
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
		var nl := maxi(4, int(lining * 40.0))
		for j in nl:
			st.append([s1 - lining * float(j) / float(nl - 1), -0.007, true])
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
	_tb(k, pts, func(_s, _a): return r, func(_s, a, _p): return col.darkened(0.12) if cos(a) < -0.3 else col, func(_s, _p): return [[sd + "UpperArm", 1.0]], 8, true)   # kemik pozunda kol yana açık: karışık ağırlık halkayı kulp gibi çeker


# ------------------------------------------------------------------ ek yardımcılar
static func _rim(k, pts: Array, r: float, col: Color, seg := 6) -> void:
	_tb(k, pts, func(_s, _a): return r, func(_s, _a, _p): return col, func(_s, p): return _hs(k, p), seg)


## Burgu ip: lobes kol, turns tur. rf2(s) kalınlık çarpanı
static func _rope(k, pts: Array, closed: bool, R: float, lobes: int, turns: float, col: Color, skinf: Callable, seg := 14, rf2 := Callable()) -> void:
	var rf := func(s: float, a: float) -> float:
		var b: float = float(rf2.call(s)) if rf2.is_valid() else 1.0
		return R * b * (1.0 + 0.16 * cos(lobes * a - TAU * turns * s))
	var cf := func(s: float, a: float, _p: Vector3) -> Color:
		var w := cos(lobes * a - TAU * turns * s)
		return col.darkened(0.34) if w < -0.5 else (col.lightened(0.12) if w > 0.62 else col)
	_tb(k, pts, rf, cf, skinf, seg, closed)


## Yüzeye oturan disk / amblem. rf(th) kenar çarpanı; colf(u, v) birim koordinat
static func _fan_on(k, keys: Array, cx: float, cy: float, front: bool, r: float, rf: Callable, colf: Callable, lift := 0.004, rings := 7, seg := 40, skinf := Callable()) -> void:
	var sg := 1.0 if front else -1.0
	var rows := []
	var uv := []
	for j in rings + 1:
		var v := float(j) / rings
		var ro := []
		var ru := []
		for i in seg:
			var th := TAU * i / seg
			var q := v * (float(rf.call(th)) if rf.is_valid() else 1.0)
			ro.append(_fp(keys, cx + sg * cos(th) * q * r, cy + sin(th) * q * r, front, lift + 0.0015 * (1.0 - v))[0])
			ru.append(Vector2(cos(th) * q, sin(th) * q))
		rows.append(ro)
		uv.append(ru)
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return _hs(k, p)
	k.grid(rows, true, func(i, j, _p): return colf.call(uv[j][i].x, uv[j][i].y), func(_i, _j, p): return sf.call(p))


# ------------------------------------------------------------------ parti d yardımcıları
## Bedene sarılan bant (kuşak, kemer): ortası kabarık, kat izli
static func _obi(k, keys: Array, y: float, hh: float, add: float, col: Color, na := 72, creased := true) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var rows := []
	for j in 7:
		var t := float(j) / 6.0
		var yy := y + hh - t * 2.0 * hh
		var bu := 0.009 * sin(t * PI) + 0.002
		var ro := []
		for i in na:
			var q: Vector2 = SE.El.sup(TAU * i / na - PI, float(s[1]) + add + bu, float(s[2]) + add + bu, float(s[3]) - add - bu)
			ro.append(Vector3(q.x, yy, q.y))
		rows.append(ro)
	k.grid(rows, true, func(i, j, _p):
		if j == 0 or j == 6:
			return col.darkened(0.2)
		return col.darkened(0.15) if creased and j in [2, 4] and (i * 2 + j) % 9 > 1 else col, func(_i, _j, p): return k.torso_skin(p.y))


## Çapraz kapanan giysi: sol kanat üstte. e_top boyundaki açıklık, e_low y_close'daki kanat ucu
static func _kimono(k, keys: Array, e_top: float, e_low: float, y_close: float, foldf: Callable, colf: Callable, ny := 44, na := 92, th := 0.006) -> Array:
	var y0: float = keys[0][0]
	var eo := func(y: float) -> float: return lerpf(e_top, e_low, clampf((y0 - y) / (y0 - y_close), 0.0, 1.0))
	var rng := func(y: float) -> Vector2:
		var e: float = eo.call(y)
		return Vector2(e, TAU - e * 0.55)
	var ff := func(a: float, y: float, u: float) -> float:
		return 0.016 * smoothstep(0.06, 0.0, u) - 0.03 * smoothstep(0.94, 1.0, u) + float(foldf.call(a, y))
	return _sheet(k, keys, ny, na, rng, ff, func(a, y, _u, v, p): return colf.call(a, y, v, p), th)


## Kumaş kenarı boyunca şerit (yaka, biye). idx: satırdaki nokta sırası
static func _edge(k, rows: Array, idx: int, hw: float, d: float, col: Color, y_stop := -9.0, skinf := Callable()) -> void:
	var pts := []
	var ou := []
	for ro in rows:
		var p: Vector3 = ro[idx]
		if p.y < y_stop:
			break
		pts.append(p)
		ou.append(Vector3(p.x * 0.6, 0.1, maxf(0.35, p.z * 4.0)).normalized())
	if pts.size() > 1:
		k.strip(pts, ou, hw, d, col, false, skinf if skinf.is_valid() else func(p: Vector3) -> Array: return _hs(k, p))


## Kumaşın alt kenarı boyunca şerit
static func _hem(k, row: Array, hw: float, d: float, col: Color, up := 0.01) -> void:
	var pts := []
	var ou := []
	for p: Vector3 in row:
		pts.append(p + Vector3(0, up, 0))
		ou.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(pts, ou, hw, d, col, false, func(p: Vector3) -> Array: return _hs(k, p))   # kumaşla aynı ağırlık: koşarken ayrılmaz


static func _bz(a: Vector2, b: Vector2, c: Vector2, d: Vector2, n := 14) -> Array:
	var o := []
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		o.append(a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t)
	return o


## Yüzeyde kabartma girdap
static func _swirl(k, keys: Array, cx: float, cy: float, r: float, turns: float, front: bool, hw: float, lift: float, d: float, col: Color, dir := 1.0) -> void:
	var c := []
	var n := int(turns * 22.0)
	for i in n + 1:
		var t := float(i) / n
		var a := t * turns * TAU * dir
		var rr := r * lerpf(0.1, 1.0, t)
		c.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
	_strap(k, keys, c, front, hw, lift, d, col, 1)


## Uzuv yüzey noktası: [konum, dış yön]
static func _lsurf(l: Dictionary, s: float, a: float, add: float) -> Array:
	var d := _ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri := (-d).cross(fw).normalized()
	var o := ri * sin(a) + fw * cos(a)
	return [_lp(l, s) + o * (_lr(l, s) + add), o]


## Uzuv üstünde şerit / ip yolu: [[s, a], ...]
static func _lstrip(k, l: Dictionary, path: Array, add: float, hw: float, d: float, col: Color) -> void:
	var pts := []
	var ou := []
	for q: Vector2 in path:
		var e: Array = _lsurf(l, q.x, q.y, add)
		pts.append(e[0])
		ou.append(e[1])
	var sp: Array = path
	k.strip(pts, ou, hw, d, col, false, func(p: Vector3) -> Array:
		var best := 0
		var bd := 99.0
		for i in pts.size():
			var dd: float = (pts[i] as Vector3).distance_squared_to(p)
			if dd < bd:
				bd = dd
				best = i
		return _lskin(l, (sp[best] as Vector2).x))


## Uzuv üstünde girdap (omuz arması)
static func _lswirl(k, l: Dictionary, s: float, a0: float, r: float, turns: float, add: float, hw: float, col: Color) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var R: float = _lr(l, s) + add
	var path := []
	var n := int(turns * 20.0)
	for i in n + 1:
		var t := float(i) / n
		var th := t * turns * TAU
		var rr := r * lerpf(0.12, 1.0, t)
		path.append(Vector2(s + sin(th) * rr / L, a0 + cos(th) * rr / R))
	_lstrip(k, l, path, add, hw, 0.0015, col)


## Küçük perçin
static func _rivet(k, e: Array, r: float, col: Color, bones: Array) -> void:
	_fan(k, e[0], e[1], Vector3.UP, r, Callable(), func(u, v):
		return col.darkened(0.3) if u * u + v * v > 0.6 else col.lightened(0.14), bones, 2, 10)


## Pantolon: dizde bolluk, baldıra doğru daralır (tuck: sargıya girdiği yer)
static func _pant(k, le: Dictionary, col: Color, bag: float, sv: float, tuck := 0.22, s1 := 1.0) -> Callable:
	var kn: float = le["kn"]
	var amp := 0.003 + bag * 0.09
	var fade := func(s: float) -> float: return 1.0 - smoothstep(kn + tuck * 0.5, kn + tuck + 0.04, s)
	var pa := func(s: float, a: float) -> float:
		var g := 0.011 + bag * exp(-pow((s - kn + 0.06) / 0.2, 2.0)) * float(fade.call(s)) - 0.003 * smoothstep(kn + tuck * 0.5, kn + tuck, s)
		var kr := 0.005 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0)
		return g + amp * _lf(s, a, sv) * float(fade.call(s)) + kr
	_lt(k, le, pa, func(s, a, ins):
		if ins:
			return col.darkened(0.4)
		var kc := 0.006 * exp(-pow((float(s) - kn) / 0.05, 2.0)) * sin(float(a) * 3.0 + float(s) * 30.0)
		return _fs(col, (0.004 * _lf(float(s), float(a), sv) + kc) * float(fade.call(float(s))), 14.0), 0.0, s1, 38, 20)
	return pa


## Kol: dirsekte kırışık
static func _sleeve(k, ar: Dictionary, col: Color, add: float, sv: float, s0 := 0.0, s1 := 1.0, bag := 0.0) -> Callable:
	var kn: float = ar["kn"]
	var pa := func(s: float, a: float) -> float:
		return add + bag * sin(clampf(s / kn, 0.0, 1.0) * PI) + 0.0032 * _lf(s, a, sv) * sin(s * PI) + 0.0055 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 34.0)
	_lt(k, ar, pa, func(s, a, ins):
		if ins:
			return col.darkened(0.42)
		var kc := 0.008 * exp(-pow((float(s) - kn) / 0.06, 2.0)) * sin(float(a) * 3.0 + float(s) * 34.0)
		return _fs(col, 0.004 * _lf(float(s), float(a), sv) + kc, 20.0), s0, s1, 30, 18)
	return pa


## Çıplak uzuv
static func _bare(k, l: Dictionary, skc: Color, s0 := 0.0, s1 := 1.0) -> void:
	_lt(k, l, func(_s, _a): return 0.001, func(_s, _a, _i): return skc, s0, s1, 24, 16)


## Serbest düşen bez: a0..a1 açı aralığı, jag(u) alt kenar uzaması. Arkası astarlı
static func _drape(k, keys: Array, a0: float, a1: float, y0: float, y1: float, jag: Callable, foldf: Callable, col: Color, lift := 0.0, nu := 26, nv := 30, th := 0.005) -> void:
	_cur_hem = y1
	var outer := []
	for j in nv + 1:
		var v := float(j) / nv
		var ro := []
		for i in nu + 1:
			var u := float(i) / nu
			var a := lerpf(a0, a1, u)
			var y := lerpf(y0, y1 - float(jag.call(u)), v)
			var e: Array = _sa(keys, a, y, lift + 0.05 * v * v * 0.0)
			var f: float = foldf.call(a, y)
			ro.append((e[0] as Vector3) + (e[1] as Vector3) * f)
		outer.append(ro)
	var rows: Array = outer.duplicate()
	var back_from := rows.size()
	for j in range(nv, -1, -1):
		var ro := []
		for p: Vector3 in outer[j]:
			ro.append(p - Vector3(p.x, 0.0, p.z).normalized() * th)
		rows.append(ro)
	k.grid(rows, false, func(i, j, p):
		var c0 := _fs(col, float(foldf.call(lerpf(a0, a1, float(i) / nu), p.y)), 6.0)
		return c0 if j < back_from else c0.darkened(0.3), func(_i, _j, p): return _hs(k, p))


# ------------------------------------------------------------------ Hagoromo (ref refs/kiyafet/hagoromo): kırmızı astarlı mavi-gri ağır pelerin, dik yaka, boyunda kızıl bağ
static func _hagoromo(k) -> void:
	var cl := Color(0.29, 0.31, 0.4)
	var red := Color(0.44, 0.13, 0.15)
	var dk := Color(0.15, 0.15, 0.19)
	var mid := Color(0.21, 0.21, 0.26)
	var wr := Color(0.6, 0.6, 0.62)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var UA: float = k.UA
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return dk)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_sleeve(k, ar, mid, 0.008, 1.3)
		_wraps(k, ar, 0.86, 0.975, 4, 0.008, 0.01, wr, 0.005)
		_pant(k, le, mid.darkened(0.08), 0.016, 2.1)
		_wraps(k, le, float(le["kn"]) + 0.27, 0.985, 8, 0.009, 0.0125, wr)
	# diz altına inen koyu iç giysi, çapraz kapanır
	var hem_t: float = H - 0.24
	var ty := [_kp(nk, N + 0.012, 0.026), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.03], _kp(ch, C - 0.03, 0.024), _kp(wa, H + 0.12, 0.026), _kp(hp, H - 0.04, 0.03), [hem_t, hp.x + 0.05, hp.y + 0.04, hp.z - 0.04]]
	var tf := func(a: float, y: float) -> float:
		return 0.012 * sin(a * 7.0 + y * 8.0) * smoothstep(C - 0.1, H, y) * (1.0 - 0.5 * smoothstep(H, hem_t, y))
	var tr := _kimono(k, ty, 0.44, -0.42, C - 0.14, tf, func(a, y, _v, _p): return _fs(mid, float(tf.call(a, y)), 7.0))
	_edge(k, tr, 0, 0.012, 0.004, dk.lightened(0.12))
	_edge(k, tr, 92, 0.012, 0.004, dk.lightened(0.12), C - 0.05)
	_hem(k, tr[tr.size() - 1], 0.009, 0.003, dk.lightened(0.1))
	_obi(k, ty, H + 0.05, 0.034, 0.009, red.darkened(0.3))
	# pelerin: omuzdan baldıra inen arka kanat
	var cb := [_kp(nk, N + 0.0, 0.05), [N - 0.06, ch.x * 1.04, ch.y * 0.98, ch.z * 1.12], _kp(ch, C - 0.03, 0.05, 0.055), [H + 0.05, wa.x + 0.07, wa.y + 0.05, wa.z - 0.075], [H - 0.1, hp.x + 0.07, hp.y + 0.05, hp.z - 0.08], [K - 0.14, hp.x + 0.12, hp.y + 0.08, hp.z - 0.15]]
	var yb0: float = cb[0][0]
	var yb1: float = cb[cb.size() - 1][0]
	var bf := func(a: float, y: float, _u := 0.0) -> float:
		var t := clampf((yb0 - y) / (yb0 - yb1), 0.0, 1.0)
		return t * t * (0.05 * sin(a * 8.0 + 0.7) + 0.022 * sin(a * 15.0 + 2.0)) + 0.006 * sin(a * 5.0 + y * 3.0)
	_cur_leg = 0.5
	var crow := _sheet(k, cb, 44, 56, func(y: float) -> Vector2:
		var w := lerpf(1.34, 1.08, clampf((yb0 - y) / (yb0 - yb1), 0.0, 1.0))
		return Vector2(PI - w, PI + w), bf, func(a, y, _u, _v, _p): return _fs(cl, float(bf.call(a, y)), 5.5), 0.007, 1.0, Callable(), red.darkened(0.12))
	_hem(k, crow[crow.size() - 1], 0.011, 0.004, cl.darkened(0.2))
	_cur_leg = 0.58
	# omuz örtüsü: duran kolun üstünü örter (kemik pozunda kol yana açık, bu yüzden gövdeye bağlı)
	var sw: float = UA + 0.125
	var mk := [_kp(nk, N + 0.012, 0.042, 0.046), [N - 0.045, ch.x + 0.115, ch.y * 0.96 + 0.055, ch.z * 1.02 - 0.065], [C + 0.05, sw + 0.012, ch.y + 0.095, ch.z - 0.118], [C - 0.17, sw + 0.04, ch.y + 0.105, ch.z - 0.13]]
	var my0: float = mk[0][0]
	var my1: float = mk[mk.size() - 1][0]
	var mf := func(a: float, y: float, _u := 0.0) -> float:
		var t := clampf((my0 - y) / (my0 - my1), 0.0, 1.0)
		return t * t * (0.034 * sin(a * 10.0 + 0.3) + 0.012 * sin(a * 19.0 + 1.0))
	var msk := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	var mrow := _sheet(k, mk, 30, 92, func(y: float) -> Vector2:
		var t := clampf((my0 - y) / (my0 - my1), 0.0, 1.0)
		var e := lerpf(0.3, 1.08, smoothstep(0.0, 0.32, t)) + 0.5 * smoothstep(0.32, 1.0, t)   # önü erken açılır: koşarken kol açıklıktan çıkar
		return Vector2(e, TAU - e), mf, func(a, y, _u, _v, _p): return _fs(cl, float(mf.call(a, y)), 6.0), 0.007, 1.0, msk, red)
	_edge(k, mrow, 0, 0.012, 0.004, red, -9.0, msk)
	_edge(k, mrow, 92, 0.012, 0.004, red, -9.0, msk)
	var hp2: Array = mrow[mrow.size() - 1]
	var hpt := []
	var hou := []
	for p: Vector3 in hp2:
		hpt.append(p + Vector3(0, 0.009, 0))
		hou.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(hpt, hou, 0.009, 0.004, cl.darkened(0.2), false, msk)
	# dik yaka: dışı pelerin rengi, içi kızıl; başa doğru açılır
	var ck := [_kp(nk, N + 0.115, 0.075, 0.08), _kp(nk, N + 0.06, 0.056, 0.06), _kp(nk, N + 0.0, 0.046, 0.05), [N - 0.03, nk.x + 0.07, nk.y + 0.055, nk.z - 0.06]]
	var cf := func(a: float, y: float, _u := 0.0) -> float:
		return 0.012 * sin(a * 6.0 + 0.8) * smoothstep(N, N + 0.1, y)
	var crw := _sheet(k, ck, 12, 52, func(_y: float) -> Vector2: return Vector2(0.4, TAU - 0.4), cf, func(a, y, _u, _v, _p): return _fs(cl.lightened(0.04), float(cf.call(a, y)), 6.0), 0.009, 1.0, func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N)), red)
	var neckf := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	_edge(k, crw, 0, 0.008, 0.004, red, -9.0, neckf)
	_edge(k, crw, 52, 0.008, 0.004, red, -9.0, neckf)
	# boyunda kızıl bağ: düğüm + iki uç
	var ke: Array = _fp(ty, 0.0, N - 0.075, true, 0.016)
	var bn: Array = k.torso_skin(N - 0.075)
	_boxr(k, ke[0], Vector3(0.019, 0, 0), Vector3(0, 0.016, 0), (ke[1] as Vector3) * 0.012, red, bn, 0.6)
	for sg in [1.0, -1.0]:
		_strap(k, ty, [Vector2(sg * 0.006, N - 0.085), Vector2(sg * 0.02, N - 0.12), Vector2(sg * 0.03, N - 0.165)], true, 0.0085, 0.008, 0.003, red, 6)
		var pts := []
		var ou := []
		for i in 9:
			var t := TAU * i / 8.0
			pts.append((ke[0] as Vector3) + Vector3(sg * (0.034 + 0.018 * cos(t + PI)), 0.012 * sin(t) + 0.002, 0.004))
			ou.append(Vector3(0, 0, 1))
		k.strip(pts, ou, 0.006, 0.003, red.lightened(0.05), false, func(_p: Vector3) -> Array: return bn)


# ------------------------------------------------------------------ Oinin (ref Anbu_Haku): gri kısa kimono, krem geniş çapraz yaka, kaburgalı kolluk, kahve kuşak, pliseli hakama
static func _oinin(k) -> void:
	var gr := Color(0.34, 0.35, 0.31)
	var cr := Color(0.83, 0.77, 0.58)
	var br := Color(0.33, 0.28, 0.2)
	var hk := Color(0.42, 0.37, 0.26)
	var dk := Color(0.17, 0.17, 0.16)
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
	_inner(k, b, func(_i, _j, _p): return cr.darkened(0.12))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var akn: float = ar["kn"]
		_bare(k, le, skc, kn + 0.02, 1.0)
		_pant(k, le, dk, 0.004, 1.6, 0.02, kn + 0.07)   # hakama altında dar iç pantolon, baldır çıplak (ref)
		# kaburgalı kolluk
		var rib := func(s: float, _a: float) -> float: return 0.009 + 0.0032 * sin(float(s) * 150.0)
		_lt(k, ar, rib, func(s, _a, ins):
			return br.darkened(0.4) if ins else (br.lightened(0.07) if sin(float(s) * 150.0) > 0.2 else br.darkened(0.16)), 0.0, 0.965, 44, 16)
		# kısa geniş kol + krem kıvrık ağız
		var se := akn * 0.86
		var sa := func(s: float, a: float) -> float:
			return 0.017 + 0.026 * smoothstep(0.05, se, s) + 0.005 * _lf(s, a, 2.4)
		_lt(k, ar, sa, func(s, a, ins): return gr.darkened(0.42) if ins else _fs(gr, 0.005 * _lf(float(s), float(a), 2.4), 20.0), 0.0, se, 18, 20, se - 0.03)
		k.wrap_turn(_lp(ar, se - 0.008), _ld(ar, se), _lr(ar, se) + 0.046, 0.018, 0.0, cr, _lskin(ar, se))
	# hakama: gerçek hakama gibi iki ayrı geniş paça (bacakla gider, diz delmez); duruşta birleşip etek gibi görünür
	var hy: float = K - 0.13
	var hkk := [_kp(wa, H + 0.075, 0.018), _kp(hp, H - 0.05, 0.016), [H - 0.13, hp.x + 0.024, hp.y + 0.022, hp.z - 0.024]]
	_cur_leg = 0.5
	var yf := func(a: float, _y: float, _u := 0.0) -> float: return 0.006 * sin(a * 14.0)
	_sheet(k, hkk, 14, 88, Callable(), yf, func(a, y, _u, _v, _p): return _fs(hk, float(yf.call(a, y)), 5.0), 0.005, 0.4)
	_cur_leg = 0.58
	var ple := {}
	for sd in ["Left", "Right"]:
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + (K - hy) / (K - float(k.F)) * (1.0 - kn)
		var pa := func(s: float, a: float) -> float:
			var t := clampf(s / s1, 0.0, 1.0)
			var saw := fposmod(a * 12.0 / TAU, 1.0)
			return 0.012 + 0.118 * pow(t, 1.25) + (0.003 + 0.017 * t) * (absf(saw - 0.5) * 4.0 - 1.0)
		_lt(k, le, pa, func(s, a, ins):
			if ins:
				return hk.darkened(0.45)
			var saw := fposmod(float(a) * 12.0 / TAU, 1.0)
			var c0: Color = _fs(hk, (absf(saw - 0.5) * 4.0 - 1.0) * 0.012, 8.0)
			return c0.darkened(0.3) if float(s) > s1 - 0.012 else c0, 0.0, s1, 26, 72, s1 - 0.02)
		ple[sd] = [le, pa, s1]
	# kimono: uyluğa inen, krem yakası çapraz boydan boya
	var hem: float = H - 0.17
	var ky := [_kp(nk, N + 0.014, 0.028), [N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.12, 0.032), _kp(hp, H - 0.04, 0.052, 0.05), [hem, hp.x + 0.085, hp.y + 0.075, hp.z - 0.075]]
	var kf := func(a: float, y: float) -> float:
		if y < H:
			var t := clampf((H - y) / (H - hem), 0.0, 1.0)
			return pow(1.0 - t, 2.0) * 0.022 * sin(a * 15.0 + 0.4) + t * 0.03 * sin(a * 7.0 + 0.6)
		return 0.012 * sin(a * 8.0 + y * 9.0) * (1.0 - smoothstep(H, C, y)) + 0.005 * sin(a * 4.0 - y * 18.0)
	_cur_leg = 0.82
	var kr := _kimono(k, ky, 0.42, -1.02, hem, kf, func(a, y, v, _p):
		var c0: Color = _fs(gr, float(kf.call(a, y)), 7.0)
		return c0.darkened(0.2) if v > 0.97 else c0, 50, 104)
	_cur_hem = hem
	# krem yaka: üst kanat kenarından eteğe kadar geniş, kalın
	_edge(k, kr, 3, 0.034, 0.008, cr)
	_edge(k, kr, 104, 0.03, 0.007, cr, C - 0.09)
	_hem(k, kr[kr.size() - 1], 0.008, 0.003, gr.darkened(0.25))
	# kahve kuşak: iki tur, yanda düğüm, hakamaya oturan uç
	var by: float = H + 0.04
	_obi(k, ky, by - 0.01, 0.043, 0.011, br)
	_obi(k, ky, by + 0.03, 0.012, 0.022, br.lightened(0.07), 72, false)
	var kx: float = -float(SE.El.key_at(ky, by)[1]) * 0.62
	var ke: Array = _fp(ky, kx, by, true, 0.03)
	_boxr(k, ke[0], Vector3(0.036, 0.008, 0), Vector3(-0.006, 0.03, 0), (ke[1] as Vector3) * 0.022, br.lightened(0.04), [["Hips", 1.0]], 0.55)
	# kuşak ucu: kimono eteğine oturur, altta paçanın üstünde devam eder
	for e2 in [[kx - 0.004, -0.012, 0.033, br], [kx + 0.03, 0.01, 0.027, br.darkened(0.1)]]:
		var tp := []
		var to := []
		for i in 11:
			var v := float(i) / 10.0
			var y2: float = lerpf(by - 0.03, hem + 0.012, v)
			var pe: Array = _fp(ky, float(e2[0]) + float(e2[1]) * v, y2, true, 0.016 + 0.05 * smoothstep(H, hem, y2))
			tp.append(pe[0])
			to.append(pe[1])
		k.strip(tp, to, float(e2[2]), 0.005, e2[3], false, func(p: Vector3) -> Array: return _hs(k, p))
	var rl: Array = ple["Right"]
	var rle: Dictionary = rl[0]
	for e3 in [[-0.42, 0.13, float(rl[2]) - 0.04, 0.034, br], [-0.66, 0.13, float(rle["kn"]) + 0.02, 0.025, br.darkened(0.1)]]:
		var path := []
		for i in 15:
			path.append(Vector2(lerpf(float(e3[1]), float(e3[2]), float(i) / 14.0), float(e3[0])))
		var pts := []
		var ou := []
		for q: Vector2 in path:
			var e: Array = _lsurf(rle, q.x, q.y, float(rl[1].call(q.x, q.y)) + 0.016)
			pts.append(e[0])
			ou.append(e[1])
		var sk := func(p: Vector3) -> Array:
			var bi := 0
			var bd := 99.0
			for i in pts.size():
				var dd: float = (pts[i] as Vector3).distance_squared_to(p)
				if dd < bd:
					bd = dd
					bi = i
			return _lskin(rle, (path[bi] as Vector2).x)
		k.strip(pts, ou, float(e3[3]), 0.005, e3[4], false, sk)
	_cur_leg = 0.58


# ------------------------------------------------------------------ Kyū Konoha (ref Konoha_flak_jacket_older): lacivert takım, açık haki yelek, omuz levhası, beyaz akış çizgileri, sırtta girdap
static func _konoha_eski(k) -> void:
	var nv := Color(0.14, 0.16, 0.27)
	var ve := Color(0.64, 0.66, 0.48)
	var tr := Color(0.53, 0.55, 0.39)
	var wh := Color(0.93, 0.92, 0.85)
	var rd := Color(0.72, 0.2, 0.16)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return nv)
	var vk := [_kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 0.99, ch.y * 0.93, ch.z * 1.05], _kp(ch, C - 0.03, 0.034), _kp(wa, H + 0.12, 0.036), _kp(wa, H + 0.03, 0.05), _kp(hp, H - 0.045, 0.05, 0.062)]
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = ar["sg"]
		var side: float = PI * 0.5
		_sleeve(k, ar, nv, 0.008, 0.8)
		var pf := _pant(k, le, nv, 0.018, 1.9, 0.2)
		_wraps(k, le, kn + 0.25, 0.985, 8, 0.009, 0.0125, wh.darkened(0.08))
		_wraps(k, ar, 0.88, 0.975, 3, 0.008, 0.009, wh.darkened(0.08), 0.004)
		# kolda iki beyaz şerit + omuzda kızıl girdap
		for s0 in [0.335, 0.375]:
			k.wrap_turn(_lp(ar, s0), _ld(ar, s0), _lr(ar, s0) + 0.008, 0.0075, 0.0, wh, _lskin(ar, s0))
		_lswirl(k, ar, 0.19, side * sg, 0.028, 1.7, 0.0105, 0.0032, rd)
		_armhole(k, ar, 0.09, 0.008, 0.007, tr)
		if sd == "Right":   # uyluk kılıfı
			var s0: float = kn * 0.56
			var c0 := _lp(le, s0)
			var rr := _lr(le, s0) + float(pf.call(s0, 0.0)) + 0.012
			for q in [0.0, 0.1]:
				k.wrap_turn(_lp(le, s0 + float(q)), _ld(le, s0), _lr(le, s0 + float(q)) + float(pf.call(s0 + float(q), 0.0)) + 0.012, 0.012, 0.0, wh.darkened(0.12), _lskin(le, s0))
			_boxr(k, c0 + Vector3(-rr - 0.022, -0.03, 0.01), Vector3(0, 0, 0.042), Vector3(0, 0.056, 0), Vector3(-0.018, 0, 0), nv.lightened(0.05), [["RightUpperLeg", 1.0]])
	# yelek: yumuşak yastıklı gövde, önde iki kanat
	_cur_leg = 0.1   # yelek eteği bacakla açılmaz
	var groove := func(a: float, y: float, _u := 0.0) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.022 * exp(-pow(aa / 0.022, 2.0)) - 0.016 * exp(-pow((y - (H + 0.075)) / 0.008, 2.0))
		return g + 0.012 * sin(a * 3.0 + y * 2.0) * smoothstep(C, H + 0.1, y) * 0.6 + 0.012 * smoothstep(H + 0.08, H + 0.05, y)
	var vr := _sheet(k, vk, 42, 88, Callable(), groove, func(a, y, _u, v, _p):
		var c0: Color = _fs(ve, float(groove.call(a, y)), 7.0)
		return c0.darkened(0.2) if v > 0.96 else c0, 0.008, 0.2)
	_hem(k, vr[vr.size() - 1], 0.011, 0.005, tr)
	# yaka bandı
	var ck := [_kp(nk, N + 0.03, 0.026, 0.03), _kp(nk, N - 0.0, 0.034), [N - 0.04, nk.x + 0.07, nk.y + 0.05, nk.z - 0.06]]
	var coll := _sheet(k, ck, 8, 52, func(_y: float) -> Vector2: return Vector2(0.26, TAU - 0.26), Callable(), func(_a, _y, _u, v, _p): return tr.lightened(0.05) if v < 0.25 else tr, 0.007, 1.0, func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N)))
	for ei in [0, 52]:
		_edge(k, coll, ei, 0.006, 0.003, tr.darkened(0.2), -9.0, func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N)))
	# omuz levhası: önden arkaya binen, köşesi pahlı, perçinli
	for sg in [1.0, -1.0]:
		_over(k, vk, sg * ch.x * 0.56, C + 0.015, C - 0.0, 0.044, 0.003, 0.013, tr)
		_over(k, vk, sg * ch.x * 0.56, C + 0.012, C + 0.003, 0.033, 0.016, 0.003, ve.lightened(0.06))
		for fr in [true, false]:
			var e: Array = _fp(vk, sg * ch.x * 0.56, C + 0.035, fr, 0.0205)
			_rivet(k, e, 0.0065, tr.darkened(0.35), k.torso_skin(C))
		# ön cep: göğüs altında yatık iki parşömen cebi
		_patch(k, vk, sg * ch.x * 0.2 if sg > 0.0 else -ch.x * 0.72, ch.x * 0.72 if sg > 0.0 else -ch.x * 0.2, H + 0.2, H + 0.105, true, 0.012, ve.darkened(0.03), 0.1)
		_strap(k, vk, [Vector2(sg * ch.x * 0.21, H + 0.195), Vector2(sg * ch.x * 0.71, H + 0.195)], true, 0.006, 0.0125, 0.003, tr, 8)
		# beyaz akış çizgileri (ref: alttan yükselip omuza kıvrılan iki kol)
		_strap(k, vk, _bz(Vector2(sg * 0.035, H + 0.1), Vector2(sg * ch.x * 0.7, H + 0.19), Vector2(sg * ch.x * 0.18, C - 0.14), Vector2(sg * ch.x * 0.62, C - 0.015)), true, 0.0042, 0.0125, 0.0018, wh, 2)
		_strap(k, vk, _bz(Vector2(sg * ch.x * 0.72, H + 0.11), Vector2(sg * ch.x * 0.95, H + 0.22), Vector2(sg * ch.x * 0.62, C - 0.16), Vector2(sg * ch.x * 0.44, C - 0.09)), true, 0.0034, 0.0045, 0.0016, wh.darkened(0.04), 2)
	# fermuar
	_strap(k, vk, [Vector2(0.0, N - 0.05), Vector2(0.0, H - 0.03)], true, 0.0052, 0.002, 0.0025, tr.darkened(0.35), 22)
	# sırtta kızıl girdap
	_swirl(k, vk, 0.0, C - 0.075, 0.066, 2.0, false, 0.0062, 0.004, 0.0025, rd)
	# bel: lacivert kemer + arka kese
	var bk := [_kp(hp, H - 0.06, 0.02)]
	var bl := _ring_pts(bk, H - 0.072, 0.0)
	_tb(k, bl, func(_s, a): return 0.016 * (0.7 + 0.3 * absf(cos(a))), func(_s, a, _p): return nv.darkened(0.2 if cos(a) > -0.4 else 0.4), func(_s, _p): return [["Hips", 1.0]], 8, true)
	var e1: Array = _fp(bk, 0.0, H - 0.072, false, 0.026)
	_boxr(k, e1[0], Vector3(0.07, 0, 0), Vector3(0, 0.04, 0), Vector3(0, 0, -0.028), nv.lightened(0.04), [["Hips", 1.0]])


# ------------------------------------------------------------------ Kyū Iwa (ref Old_Iwa_Flak_Jacket): tek kollu koyu takım, köşeli omuz plakalı kalın yelek, karında büyük cep
static func _iwa_eski(k) -> void:
	var ve := Color(0.43, 0.42, 0.37)
	var tr := Color(0.32, 0.31, 0.27)
	var dk := Color(0.2, 0.18, 0.17)
	var pu := Color(0.5, 0.46, 0.53)
	var wr := Color(0.56, 0.52, 0.46)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return dk)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		if sd == "Left":
			_sleeve(k, ar, dk.lightened(0.05), 0.012, 3.1, 0.0, 1.0, 0.009)
			_wraps(k, ar, 0.84, 0.975, 4, 0.01, 0.011, wr, 0.006)
			_armhole(k, ar, 0.09, 0.012, 0.008, tr)
		else:   # Iwa'nın tek kolu açık
			_bare(k, ar, skc)
			_wraps(k, ar, 0.8, 0.975, 5, 0.006, 0.011, wr, 0.006)
		_pant(k, le, dk.lightened(0.03), 0.026, 2.7, 0.16)
		_wraps(k, le, kn + 0.2, 0.985, 10, 0.011, 0.0125, wr)
	# yelek: geniş, kutumsu, dikey dilimli
	var vk := [_kp(nk, N + 0.0, 0.036), [N - 0.05, ch.x * 1.04, ch.y * 0.97, ch.z * 1.08], _kp(ch, C - 0.03, 0.044), _kp(wa, H + 0.12, 0.052), _kp(wa.lerp(hp, 0.6), H + 0.02, 0.058), _kp(hp, H - 0.075, 0.052, 0.058)]
	var yh: float = H + 0.03
	_cur_leg = 0.1
	var groove := func(a: float, y: float, _u := 0.0) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.02 * exp(-pow(aa / 0.022, 2.0))
		for c0 in [0.72, 1.32, 1.95, 2.55]:
			g -= 0.018 * exp(-pow((aa - c0) / 0.04, 2.0))
		return g * smoothstep(yh - 0.01, yh + 0.02, y) - 0.02 * exp(-pow((y - yh) / 0.008, 2.0)) + 0.01 * sin(y * 95.0) * (1.0 - smoothstep(yh - 0.012, yh, y))
	var vr := _sheet(k, vk, 56, 96, Callable(), groove, func(a, y, _u, v, _p):
		var c0: Color = _fs(ve, float(groove.call(a, y)), 7.0)
		return c0.darkened(0.2) if v > 0.97 else c0, 0.009, 0.2)
	_hem(k, vr[vr.size() - 1], 0.012, 0.006, tr)
	# boğazlı yaka
	var ck := [_kp(nk, N + 0.05, 0.022, 0.025), _kp(nk, N + 0.01, 0.038), [N - 0.03, nk.x + 0.07, nk.y + 0.05, nk.z - 0.05]]
	_sheet(k, ck, 8, 44, Callable(), Callable(), func(_a, y, _u, _v, _p): return tr.darkened(0.25 if y > N + 0.03 else 0.08), 0.007, 0.4, func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N)))
	# köşeli omuz plakası: yelekten kalkık, kalın, dört perçin
	for sg in [1.0, -1.0]:
		var sx: float = sg * ch.x * 0.6
		_over(k, vk, sx, C - 0.015, C - 0.04, 0.056, 0.004, 0.017, tr)
		_over(k, vk, sx, C - 0.008, C - 0.033, 0.045, 0.021, 0.004, ve.darkened(0.04))
		for fr in [true, false]:
			for dx in [-0.03, 0.03]:
				var e: Array = _fp(vk, sx + dx, C + 0.01, fr, 0.0265)
				_rivet(k, e, 0.0072, tr.darkened(0.42), k.torso_skin(C))
	# fermuar
	_strap(k, vk, [Vector2(0.0, N - 0.05), Vector2(0.0, H - 0.07)], true, 0.0058, 0.002, 0.003, tr.darkened(0.36), 24)
	# bel bandı: cebi taşıyan kalın bez
	var py: float = H + 0.105
	_obi(k, vk, py - 0.004, 0.02, 0.009, tr.lightened(0.05), 72, false)
	# karın cebi: geniş, şişkin, kapaklı
	var pw: float = float(SE.El.key_at(vk, py)[1]) * 0.8
	var pk := func(x: float, y: float, lift: float) -> Vector3: return _fp(vk, x, y, true, lift)[0]
	var rows := []
	for j in 15:
		var v := float(j) / 14.0
		var y := lerpf(py + 0.058, py - 0.058, v)
		var ro := []
		for i in 25:
			var u := float(i) / 24.0
			var sq := lerpf(0.9, 1.0, smoothstep(0.0, 0.3, minf(v, 1.0 - v) * 2.0))
			var e2 := minf(minf(u, 1.0 - u) * 5.0, minf(v, 1.0 - v) * 5.0)
			ro.append(pk.call(lerpf(-pw, pw, u) * sq, y, -0.002 + 0.042 * smoothstep(0.0, 1.0, e2)))
		rows.append(ro)
	k.grid(rows, false, func(i, j, _p):
		var fold := 0.5 + 0.5 * sin(float(i) * 1.1 + float(j) * 0.3)
		return pu.darkened(0.22) if i in [0, 24] or j in [0, 14] else pu.darkened(0.08 * fold), func(_i, _j, p): return k.torso_skin(p.y))
	_patch(k, vk, -pw * 0.98, pw * 0.98, py + 0.066, py + 0.02, true, 0.052, pu.lightened(0.07), 0.08, 18, 6)
	for sg in [1.0, -1.0]:
		_rivet(k, _fp(vk, sg * pw * 0.62, py + 0.036, true, 0.0545), 0.0075, tr.darkened(0.35), k.torso_skin(py))
	# yan bel kesesi + sırt rulosu
	var e0: Array = _fp(vk, float(SE.El.key_at(vk, H)[1]) * 0.86, H - 0.01, true, 0.03)
	_boxr(k, e0[0], Vector3(0.034, 0, -0.012), Vector3(0, 0.044, 0), (e0[1] as Vector3) * 0.024, tr, [["Hips", 1.0]])
	var e1: Array = _fp(vk, 0.0, C - 0.12, false, 0.046)
	var bk := []
	for i in 13:
		bk.append((e1[0] as Vector3) + Vector3(lerpf(-0.088, 0.088, float(i) / 12.0), 0, 0))
	var sp: Array = k.torso_skin(C - 0.12)
	_tb(k, bk, func(s, a): return 0.034 * (1.0 + 0.05 * sin(float(a) * 3.0 + float(s) * 18.0)) * sqrt(clampf((0.5 - absf(float(s) - 0.5)) * 9.0, 0.0, 1.0)), func(s, _a, _p):
		return wr.darkened(0.3) if int(float(s) * 12.0) % 4 == 1 else wr.darkened(0.1), func(_s, _p): return sp, 14)


# ------------------------------------------------------------------ Sanshō (ref Hanzo_full_appearance): mor-gri çift girdaplı yelek, yüksek yaka, omuzdan düşen kara pelerin, bol pantolon + sargı
static func _sansho(k) -> void:
	var ve := Color(0.53, 0.5, 0.5)
	var tr := Color(0.38, 0.35, 0.36)
	var dk := Color(0.15, 0.15, 0.17)
	var pa := Color(0.37, 0.38, 0.33)
	var cp := Color(0.17, 0.17, 0.2)
	var wr := Color(0.77, 0.75, 0.68)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var UA: float = k.UA
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return dk)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		_sleeve(k, ar, dk.lightened(0.08), 0.008, 1.1)
		_lt(k, ar, func(_s, _a): return 0.0145, func(_s, _a, _i): return wr.darkened(0.22), float(ar["kn"]) + 0.02, 0.97, 14, 16)
		_wraps(k, ar, float(ar["kn"]) + 0.04, 0.965, 11, 0.0165, 0.0115, wr, 0.005)
		_pant(k, le, pa, 0.04, 1.2, 0.2)
		_lt(k, le, func(_s, _a): return 0.012, func(_s, _a, _i): return wr.darkened(0.25), kn + 0.24, 0.985, 12, 16)
		_wraps(k, le, kn + 0.25, 0.975, 9, 0.0145, 0.014, wr)
		_armhole(k, ar, 0.09, 0.008, 0.007, tr)
	# yelek: yatay dikişli alt, düz göğüs
	var vk := [_kp(nk, N + 0.0, 0.032), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.06], _kp(ch, C - 0.03, 0.038), _kp(wa, H + 0.12, 0.04), _kp(wa.lerp(hp, 0.6), H + 0.02, 0.048), _kp(hp, H - 0.07, 0.048, 0.054)]
	var qy: float = C - 0.15
	_cur_leg = 0.1
	var qf := func(a: float, y: float, _u := 0.0) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		return -0.018 * exp(-pow(aa / 0.02, 2.0)) + 0.008 * absf(sin(y * 44.0)) * (1.0 - smoothstep(qy - 0.015, qy, y)) - 0.012 * exp(-pow((y - qy) / 0.007, 2.0))
	var vr := _sheet(k, vk, 60, 88, Callable(), qf, func(a, y, _u, v, _p):
		var c0: Color = ve.darkened(0.2) if absf(sin(y * 44.0)) < 0.2 and y < qy else _fs(ve, float(qf.call(a, y)) * 0.6, 7.0)
		return c0.darkened(0.2) if v > 0.97 else c0, 0.008, 0.2)
	_hem(k, vr[vr.size() - 1], 0.01, 0.005, tr)
	# yüksek katlı yaka
	var ck := [_kp(nk, N + 0.1, 0.03, 0.036), _kp(nk, N + 0.05, 0.03, 0.034), _kp(nk, N + 0.0, 0.04), [N - 0.035, nk.x + 0.075, nk.y + 0.055, nk.z - 0.06]]
	var nf := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	var cr := _sheet(k, ck, 14, 52, func(_y: float) -> Vector2: return Vector2(0.14, TAU - 0.14), Callable(), func(_a, y, _u, _v, _p):
		return tr.lightened(0.06) if absf(y - (N + 0.045)) > 0.006 else tr.darkened(0.3), 0.008, 1.0, nf)
	for ei in [0, 52]:
		_edge(k, cr, ei, 0.0065, 0.003, tr.darkened(0.25), -9.0, nf)
	# göğüste çift sarmal + fermuar
	for sg in [1.0, -1.0]:
		_swirl(k, vk, sg * ch.x * 0.48, C - 0.05, 0.058, 2.25, true, 0.0058, 0.004, 0.0028, dk, sg)
	_strap(k, vk, [Vector2(0.0, N - 0.05), Vector2(0.0, H - 0.06)], true, 0.0056, 0.002, 0.003, dk, 24)
	# kalın kemer + toka + yan keseler
	var by: float = H - 0.015
	_obi(k, vk, by, 0.031, 0.012, dk, 72, false)
	var be: Array = _fp(vk, 0.0, by, true, 0.05)
	_boxr(k, be[0], Vector3(0.036, 0, 0), Vector3(0, 0.029, 0), Vector3(0, 0, 0.009), Color(0.56, 0.57, 0.6), [["Hips", 1.0]], 0.25)
	_boxr(k, (be[0] as Vector3) + Vector3(0, 0, 0.008), Vector3(0.021, 0, 0), Vector3(0, 0.016, 0), Vector3(0, 0, 0.004), dk.lightened(0.1), [["Hips", 1.0]], 0.3)
	for sg in [1.0, -1.0]:
		var e0: Array = _fp(vk, sg * float(SE.El.key_at(vk, by)[1]) * 0.84, by - 0.052, true, 0.028)
		_boxr(k, e0[0], Vector3(0.032, 0, 0), Vector3(0, 0.044, 0), (e0[1] as Vector3) * 0.021, pa.darkened(0.3), [["Hips", 1.0]])
	# kara pelerin: omuzlardan geniş, önü tamamen açık, arkada sivri uçlu
	var ck2 := [_kp(nk, N + 0.0, 0.05), [N - 0.05, ch.x + 0.095, ch.y * 0.96 + 0.035, ch.z * 1.04 - 0.04], [C - 0.02, UA + 0.135, ch.y + 0.07, ch.z - 0.09], [C - 0.15, UA + 0.16, ch.y + 0.08, ch.z - 0.105], [H + 0.12, ch.x + 0.075, ch.y + 0.08, ch.z - 0.115], [H - 0.16, ch.x + 0.1, ch.y + 0.08, ch.z - 0.14]]
	var y0: float = ck2[0][0]
	var y1: float = ck2[5][0]
	var cf := func(a: float, y: float, _u := 0.0) -> float:
		var t := clampf((y0 - y) / (y0 - y1), 0.0, 1.0)
		return t * t * (0.05 * sin(a * 7.0 + 1.1) + 0.018 * sin(a * 16.0))
	var msk := func(p: Vector3) -> Array: return k.cloth_skin(p, y1, 0.3)
	var crow := _sheet(k, ck2, 40, 96, func(y: float) -> Vector2:
		var t := clampf((y0 - y) / (y0 - y1), 0.0, 1.0)
		var e := lerpf(0.95, 1.12, smoothstep(0.0, 0.26, t)) + 0.88 * smoothstep(0.26, 0.5, t)   # omuzda geniş, kol altından sonra yalnız sırtta
		return Vector2(e, TAU - e), cf, func(a, y, _u, _v, _p): return _fs(cp, float(cf.call(a, y)), 5.0), 0.007, 1.0, msk, Color(0.11, 0.1, 0.13))
	_edge(k, crow.slice(4), 0, 0.009, 0.004, cp.lightened(0.1), -9.0, msk)
	_edge(k, crow.slice(4), 96, 0.009, 0.004, cp.lightened(0.1), -9.0, msk)


# ------------------------------------------------------------------ Raiun (ref Killer_B): kolsuz beyaz üst, kalın boyun atkısı, kırmızı-beyaz burgu ip, yanda yırtık uçlu uzun beyaz örtü, bol koyu pantolon + beyaz bantlar
static func _kumo_uta(k) -> void:
	var wh := Color(0.9, 0.89, 0.85)
	var sh := Color(0.76, 0.75, 0.71)
	var pa := Color(0.2, 0.22, 0.31)
	var rd := Color(0.72, 0.14, 0.13)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var F: float = k.F
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return sh)
	var rle: Dictionary = {}
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		_bare(k, ar, skc)
		for i in 4:
			var s := lerpf(0.86, 0.96, float(i) / 3.0)
			k.wrap_turn(_lp(ar, s), _ld(ar, s), _lr(ar, s) + 0.007, 0.0095, 0.004, wh.darkened(0.04 * float(i % 2)), _lskin(ar, s))
		k.wrap_turn(_lp(ar, 0.28), _ld(ar, 0.28), _lr(ar, 0.28) + 0.006, 0.012, 0.0, rd, _lskin(ar, 0.28))
		var pf := _pant(k, le, pa, 0.042, 2.3, 0.26)
		# beyaz bantlar: uyluk, diz altı, baldır (ref: bol paçayı büzen sargılar)
		for e in [[kn * 0.62, 0.02], [kn + 0.09, 0.024], [kn + 0.26, 0.02]]:
			var s0: float = e[0]
			k.wrap_turn(_lp(le, s0), _ld(le, s0), _lr(le, s0) + float(pf.call(s0, 0.0)) + 0.012, float(e[1]), 0.004, wh, _lskin(le, s0))
		_wraps(k, le, 0.9, 0.985, 4, 0.01, 0.012, wh.darkened(0.04))
		if sd == "Right":
			rle = le
	# kolsuz üst: yan dikişli, belde büzgülü
	var vk := [_kp(nk, N + 0.0, 0.026), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], _kp(ch, C - 0.03, 0.022), _kp(wa, H + 0.12, 0.024), _kp(wa, H + 0.03, 0.04), _kp(hp, H - 0.07, 0.04)]
	_cur_leg = 0.1
	var vf := func(a: float, y: float, _u := 0.0) -> float:
		var g := 1.0 - smoothstep(H + 0.02, C - 0.05, y)
		return g * (0.016 * sin(a * 11.0 + y * 7.0) + 0.006 * sin(a * 23.0 - y * 14.0)) + 0.012 * smoothstep(H + 0.05, H - 0.02, y) * sin(a * 17.0)
	var vr := _sheet(k, vk, 42, 96, Callable(), vf, func(a, y, _u, v, _p):
		var c0: Color = _fs(wh, float(vf.call(a, y)), 6.0)
		return c0.darkened(0.14) if v > 0.97 else c0, 0.006, 0.2)
	_hem(k, vr[vr.size() - 1], 0.008, 0.003, sh)
	# göğüste dikiş çizgileri (ref: önde üç kısa şerit)
	for i in 3:
		var x := -0.05 + 0.05 * float(i)
		_strap(k, vk, [Vector2(x, C - 0.13), Vector2(x, C - 0.2)], true, 0.0036, 0.003, 0.002, sh.darkened(0.12), 4)
	# boyun atkısı: kalın, omuza oturan iki kat
	var nb := func(p: Vector3) -> Array:
		var t := smoothstep(N - 0.06, N + 0.03, p.y)
		return [["UpperChest", 1.0 - t * 0.5], ["Neck", t * 0.5]]
	var r1 := _ring_pts(vk, N - 0.04, 0.042, 56)
	_tb(k, r1, func(s, a): return 0.05 * (1.0 + 0.1 * sin(float(s) * TAU * 6.0 + float(a) * 2.0)), func(s, a, _p):
		return wh.darkened(0.2) if sin(float(s) * TAU * 6.0 + float(a) * 2.0) < -0.55 else wh, func(_s, p): return nb.call(p), 16, true)
	var r2 := []
	for i in 48:
		var a := TAU * i / 48.0 - PI
		var q: Vector2 = SE.El.sup(a, nk.x + 0.058, nk.y + 0.05, nk.z - 0.06)
		r2.append(Vector3(q.x, N + 0.022 + 0.012 * cos(a), q.y))
	_tb(k, r2, func(s, a): return 0.034 * (1.0 + 0.09 * sin(float(s) * TAU * 5.0 - float(a) * 2.0)), func(s, a, _p):
		return wh.darkened(0.16) if sin(float(s) * TAU * 5.0 - float(a) * 2.0) < -0.55 else wh.lightened(0.04), func(_s, p): return nb.call(p), 14, true)
	# yan örtü: sol kalçadan baldıra, ucu yırtık; arkada kısa kat
	_cur_leg = 0.62
	var dk2 := [_kp(wa, H + 0.03, 0.05), _kp(hp, H - 0.06, 0.075, 0.07), [H - 0.3, hp.x + 0.14, hp.y + 0.14, hp.z - 0.14], [K - 0.2, hp.x + 0.125, hp.y + 0.155, hp.z - 0.155]]
	var ff := func(a: float, y: float) -> float:
		var t := clampf((H - y) / (H - K + 0.2), 0.0, 1.0)
		return t * (0.022 * sin(a * 8.0 + 0.4) + 0.012 * sin(a * 15.0 + y * 3.0)) + (1.0 - t) * 0.006 * sin(a * 12.0)
	var jag := func(u: float) -> float:
		return 0.04 * absf(sin(u * 19.0)) + 0.03 * absf(sin(u * 7.3 + 1.0)) + 0.06 * (1.0 - u)
	_drape(k, dk2, 0.42, 1.5, H + 0.02, K - 0.17, jag, ff, wh)
	_drape(k, dk2, 2.15, 4.2, H + 0.02, H - 0.3, func(u: float) -> float: return 0.026 * absf(sin(u * 15.0)) + 0.02 * absf(sin(u * 6.0)), ff, sh.lightened(0.04), 0.003, 28, 16)
	_cur_leg = 0.58
	# burgu ip: kırmızı gövde, beyaz ikinci kol (iki ayrı sarmal)
	var ry: float = H + 0.04
	var rp := _ring_pts(vk, ry, 0.02, 96)
	var tsk := func(_s, p: Vector3) -> Array: return k.torso_skin(p.y)
	var twist := func(s: float, a: float) -> float: return 0.03 * (1.0 + 0.15 * cos(2.0 * a - TAU * 13.0 * s))
	_tb(k, rp, twist, func(s, a, _p):
		var w := fposmod((2.0 * float(a) - TAU * 13.0 * float(s)) / TAU, 1.0)
		var c0 := wh if w < 0.42 else rd
		var e := absf(fposmod(w * 2.0 + 0.0, 1.0) - 0.5)
		return c0.darkened(0.3) if e > 0.44 else c0, tsk, 16, true)
	# önde düğüm + bacağa inen kırmızı ip (uç kumaşa / bacağa oturur)
	var ke: Array = _fp(vk, -wa.x * 0.46, ry, true, 0.042)
	var kc: Vector3 = ke[0]
	_rope(k, _knot_pts(kc), true, 0.019, 2, 3.0, rd, func(_s, _p): return [["Hips", 1.0]], 10)
	var l2 := []
	var a2 := 0.55
	for i in 25:
		var t := float(i) / 24.0
		l2.append(Vector2(lerpf(0.02, 0.7, t), -PI * 0.5 + a2 * sin(t * 2.4)))
	var ou2 := []
	var pts2 := []
	for q: Vector2 in l2:
		var e: Array = _lsurf(rle, q.x, q.y, 0.035 + 0.02 * exp(-pow((q.x - float(rle["kn"])) / 0.2, 2.0)))
		pts2.append(e[0])
		ou2.append(e[1])
	_rope(k, pts2, false, 0.0135, 2, 12.0, rd, func(s, _p): return _lskin(rle, lerpf(0.02, 0.7, float(s))), 10, func(s): return 1.0 if float(s) < 0.96 else 0.65)
	_boxr(k, pts2[24], Vector3(0.014, 0, 0), Vector3(0, 0.024, 0), Vector3(0, 0, 0.014), wh, _lskin(rle, 0.7), 0.5)


static func _knot_pts(c: Vector3) -> Array:
	var o := []
	for i in 20:
		var a := TAU * i / 20.0
		o.append(c + Vector3(0.03 * cos(a), 0.024 * sin(a * 2.0) + 0.012 * sin(a), 0.012 * cos(a * 2.0)))
	return o
