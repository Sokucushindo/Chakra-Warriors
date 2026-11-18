extends RefCounted
## Elle modellenmiş setler, parti a: rengo, keimu, oto, aburame, kaguya, oto_yonin. Örnek: set_el.gd içindeki _shugonin.
## Yardımcılar: _sheet (katlı kenarlı kumaş), _tb (serbest boru: ip, yaka rulosu), _lt (kol / bacak), _fp (gövde yüzey noktası), _patch, _boxr, _fan.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const E = preload("res://scripts/actors/set_v2_e.gd")

const DONE := ["set_rengo", "set_keimu", "set_oto", "set_aburame", "set_kaguya", "set_oto_yonin"]


static func recipe(k, sid: String) -> void:
	_cur_leg = 0.58
	match sid:
		"set_rengo": _rengo(k)
		"set_keimu": _keimu(k)
		"set_oto": _oto(k)
		"set_aburame": _aburame(k)
		"set_kaguya": _kaguya(k)
		"set_oto_yonin": _oto_yonin(k)


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


# ------------------------------------------------------------------ Shinobi Rengō (ref refs/kiyafet/rengo): koyu lacivert takım, geniş omuz kayışlı gri yelek, çapraz kuşak + yuvarlak toka, sırtta 忍
static func _rengo(k) -> void:
	var nv := Color(0.13, 0.15, 0.24)
	var ve := Color(0.36, 0.38, 0.38)
	var st := Color(0.24, 0.25, 0.26)
	var mt := Color(0.66, 0.68, 0.7)
	var wr := Color(0.84, 0.83, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return nv)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_lt(k, ar, func(s, a): return 0.007 + 0.0035 * _lf(s, a, 1.0) * sin(s * PI), func(s, a, ins):
			return nv.darkened(0.4) if ins else _fs(nv, _lf(s, a, 1.0) * 0.012 * sin(s * PI), 14.0), 0.0, 1.0, 30, 18)
		# pantolon: dizde pay, baldırda dar, sargıya girer
		var pa := func(s: float, a: float) -> float:
			var kn: float = le["kn"]
			var bag := 0.012 + 0.012 * exp(-pow((s - kn + 0.1) / 0.16, 2.0)) - 0.008 * smoothstep(kn + 0.1, kn + 0.3, s)
			return bag + 0.0055 * _lf(s, a, 2.0) * (1.0 - smoothstep(kn + 0.1, kn + 0.25, s))
		_lt(k, le, pa, func(s, a, ins):
			return nv.darkened(0.4) if ins else _fs(nv, pa.call(s, a) - 0.016, 7.0), 0.0, 1.0, 36, 20)
		_lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.002, func(_s, _a, _i): return wr.darkened(0.14), float(le["kn"]) + 0.17, 1.0, 12, 16)
		_wraps(k, le, float(le["kn"]) + 0.2, 0.985, 9, 0.011, 0.013, wr)
		_wraps(k, ar, 0.9, 0.975, 3, 0.006, 0.009, nv.darkened(0.3), 0.004)
		# bilek bandı + uyluk kılıfı (sağ)
		if sd == "Right":
			var s0: float = float(le["kn"]) * 0.5
			var c0 := _lp(le, s0)
			var rr := _lr(le, s0)
			k.wrap_turn(c0, _ld(le, s0), rr + float(pa.call(s0, 0.0)) + 0.008, 0.014, 0.0, st.darkened(0.2), _lskin(le, s0))
			k.wrap_turn(_lp(le, s0 + 0.09), _ld(le, s0), _lr(le, s0 + 0.09) + float(pa.call(s0 + 0.09, 0.0)) + 0.008, 0.011, 0.0, st.darkened(0.2), _lskin(le, s0 + 0.09))
			_boxr(k, c0 + Vector3(-rr - 0.03, -0.03, 0.012), Vector3(0, 0, 0.04), Vector3(0, 0.05, 0), Vector3(-0.018, 0, 0), st, [["RightUpperLeg", 1.0]])
		_armhole(k, ar, 0.075, 0.018, 0.012, ve)
	# yelek gövdesi: omuzdan bele, panel oluklu
	var vk := [_kp(nk, N + 0.005, 0.03), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.12, 0.028), _kp(wa, H + 0.0, 0.04)]
	var groove := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.03 * exp(-pow((aa - 0.62) / 0.07, 2.0)) - 0.03 * exp(-pow((aa - 2.45) / 0.07, 2.0))
		g -= 0.024 * exp(-pow((y - (C - 0.13)) / 0.012, 2.0))
		return g + 0.012 * smoothstep(H + 0.08, H, y)
	_sheet(k, vk, 34, 76, Callable(), groove, func(a, y, _u, v, _p):
		var c0 := _fs(ve, groove.call(a, y, 0.0), 8.0)
		return c0.darkened(0.2) if v > 0.95 else c0, 0.007, 0.2)
	# yüksek yuvarlak yaka: önü açık, kenarı kalın
	var ck := [_kp(nk, N + 0.095, 0.022, 0.026), _kp(nk, N + 0.04, 0.03, 0.034), _kp(nk, N - 0.03, 0.058, 0.06)]
	var co_r := func(_y: float) -> Vector2: return Vector2(0.3, TAU - 0.3)
	_sheet(k, ck, 10, 40, co_r, Callable(), func(_a, _y, _u, v, _p): return ve.lightened(0.05) if v < 0.2 else ve, 0.008)
	# omuz kayışları
	for sg in [1.0, -1.0]:
		_over(k, vk, sg * ch.x * 0.56, C + 0.0, C - 0.02, 0.034, 0.003, 0.007, st)
	# çapraz kuşak ve yuvarlak toka
	var bx := 0.05 * 1.0
	var by := H + 0.13
	_strap(k, vk, [Vector2(-ch.x * 0.58, N - 0.09), Vector2(bx, by)], true, 0.027, 0.009, 0.006, st.lightened(0.08), 14)
	_strap(k, vk, [Vector2(bx, by), Vector2(wa.x * 0.82, H + 0.035)], true, 0.021, 0.009, 0.005, st.lightened(0.08), 8)
	var ce: Array = _fp(vk, bx, by, true, 0.017)
	var bn: Array = k.torso_skin(by)
	_fan(k, ce[0], ce[1], Vector3.UP, 0.036, Callable(), func(u, v):
		var r := sqrt(u * u + v * v)
		return mt.darkened(0.28) if r > 0.86 or r < 0.3 else mt, bn, 5, 28)
	# göğüs paneli + parşömen cepleri
	_patch(k, vk, -ch.x * 0.3, ch.x * 0.34, C - 0.1, C - 0.2, true, 0.007, ve.lightened(0.06), 0.12)
	for i in 2:
		var x0: float = ch.x * (0.34 + i * 0.25)
		var e0: Array = _fp(vk, x0 + 0.024, C + 0.01, true, 0.019)
		_boxr(k, e0[0], Vector3(0.025, 0, 0).rotated(Vector3.UP, 0.15), Vector3(0, 0.05, 0), (e0[1] as Vector3) * 0.017, ve.darkened(0.16), k.torso_skin(C))
		_boxr(k, (e0[0] as Vector3) + Vector3(0, 0.044, 0.006), Vector3(0.027, 0, 0), Vector3(0, 0.012, 0), (e0[1] as Vector3) * 0.02, ve.darkened(0.05), k.torso_skin(C))
	# fermuar
	_strap(k, vk, [Vector2(0.0, N - 0.1), Vector2(0.0, C - 0.09)], true, 0.004, 0.002, 0.002, st.darkened(0.3), 6)
	# kemer + arka kese
	var bl := _ring_pts(vk, H + 0.012, 0.012)
	_tb(k, bl, func(_s, a): return 0.021 * (0.72 + 0.28 * absf(cos(a))), func(_s, a, _p): return st.darkened(0.08 if cos(a) > -0.4 else 0.26), func(_s, p): return k.torso_skin(p.y), 8, true)
	var e1: Array = _fp(vk, 0.0, H + 0.0, false, 0.04)
	_boxr(k, e1[0], Vector3(0.078, 0, 0), Vector3(0, 0.045, 0), Vector3(0, 0, -0.03), Color(0.42, 0.37, 0.27), [["Hips", 1.0]])
	_boxr(k, (e1[0] as Vector3) + Vector3(0, 0.035, -0.014), Vector3(0.082, 0, 0), Vector3(0, 0.016, 0), Vector3(0, 0, -0.026), Color(0.47, 0.42, 0.31), [["Hips", 1.0]])
	# sırtta 忍
	_glyph(k, vk, 0.0, C - 0.01, 0.062, E.G_SHINOBI, 0.0052, Color(0.86, 0.87, 0.88), false)


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


static func _yinyang(u: float, v: float, wh: Color, dk: Color) -> Color:
	var p := Vector2(u, v)
	if p.length() > 0.88:
		return dk
	if p.distance_to(Vector2(0, 0.45)) < 0.13:
		return dk
	if p.distance_to(Vector2(0, -0.45)) < 0.13:
		return wh
	if p.distance_to(Vector2(0, 0.45)) < 0.44:
		return wh
	if p.distance_to(Vector2(0, -0.45)) < 0.44:
		return dk
	return wh if u > 0.0 else dk


static func _crest_r(th: float) -> float:
	if sin(th) >= 0.0:
		return 1.0
	return maxf(1.0, minf(1.5, 0.15 / maxf(absf(cos(th)), 0.01)))


static func _cam(p: Vector3) -> float:
	return sin(p.x * 34.0 + p.y * 13.0) + sin(p.y * 26.0 - p.z * 21.0 + 1.3) + sin(p.z * 39.0 + p.x * 12.0 + 2.1) + 0.6 * sin(p.y * 58.0 + p.x * 41.0 + 0.7)


# ------------------------------------------------------------------ Keimu Butai (ref Fugaku-KMPFU): huni yakalı şişkin yelek, rulo etek ucu, koyu kol + arma, baklavalı sarma etek
static func _keimu(k) -> void:
	var ol := Color(0.42, 0.45, 0.35)
	var sl := Color(0.16, 0.16, 0.24)
	var pl := Color(0.23, 0.17, 0.24)
	var pn := Color(0.11, 0.11, 0.16)
	var tn := Color(0.78, 0.73, 0.58)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return pn)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var aa := func(s: float, a: float) -> float:
			return 0.009 + 0.005 * _lf(s, a, 0.7) * sin(s * PI) - 0.004 * smoothstep(0.86, 1.0, s)
		_lt(k, ar, aa, func(s, a, ins): return sl.darkened(0.4) if ins else _fs(sl, float(aa.call(s, a)) - 0.009, 16.0), 0.0, 1.0, 32, 18)
		var pa := func(s: float, a: float) -> float:
			return 0.012 + 0.004 * _lf(s, a, 3.0) - 0.006 * smoothstep(0.75, 1.0, s)
		_lt(k, le, pa, func(s, a, ins): return pn.darkened(0.4) if ins else _fs(pn, float(pa.call(s, a)) - 0.012, 14.0), 0.0, 1.0, 34, 18)
		_wraps(k, le, 0.92, 0.985, 3, 0.008, 0.011, pn.lightened(0.14), 0.0)
		_armhole(k, ar, 0.075, 0.02, 0.013, ol)
		# kol arması: koyu mavi shuriken üstünde Uchiha yelpazesi (kol inince dışa bakan yüz)
		var s_b := 0.34
		var c0 := _lp(ar, s_b) + Vector3.UP * (_lr(ar, s_b) + 0.0135)
		var tow: Vector3 = -_ld(ar, s_b)
		var bo := _lskin(ar, s_b)
		_fan(k, c0, Vector3.UP, tow, 0.066, func(th): return 0.36 + 0.64 * pow(absf(cos(2.0 * (float(th) - 0.35))), 4.0), func(_u, _v): return Color(0.12, 0.3, 0.36), bo, 3, 40)
		_fan(k, c0 + Vector3.UP * 0.0025, Vector3.UP, tow, 0.021, func(th): return _crest_r(float(th)), func(_u, v): return Color(0.74, 0.16, 0.16) if float(v) > 0.0 else Color(0.94, 0.92, 0.88), bo, 3, 28)
	# sarma etek: bir yanı açık, kat kat düşer
	var hem: float = K - 0.1
	var sk := [_kp(wa, H + 0.07, 0.024), _kp(hp, H - 0.04, 0.032), [K + 0.14, hp.x + 0.075, hp.y + 0.1, hp.z - 0.1], [hem, hp.x + 0.1, hp.y + 0.125, hp.z - 0.125]]
	var sr := func(_y: float) -> Vector2: return Vector2(0.14, TAU - 0.5)
	var pf := func(a: float, y: float, _u: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.034 * sin(a * 6.0 + 0.8) + 0.018 * sin(a * 11.0 + 2.2))
	var srows := _sheet(k, sk, 30, 66, sr, pf, func(a, y, _u, _v, _p): return _fs(pl, float(pf.call(a, y, 0.0)), 6.0), 0.007)
	var ed0 := []
	for ro in srows:
		ed0.append(ro[0])
	_rim(k, ed0, 0.0055, pl.lightened(0.1))
	var ed1 := []
	for ro in srows:
		ed1.append(ro[ro.size() - 1])
	_rim(k, ed1, 0.0055, pl.lightened(0.1))
	# baklava dizisi: kumaşın üstüne dikili yamalar
	var dy: float = hem + 0.075
	var a_d := 0.42
	while a_d < TAU - 0.68:
		var rows := []
		for j in 7:
			var v := float(j) / 6.0 * 2.0 - 1.0
			var hw := (1.0 - absf(v)) * 0.115
			var ro := []
			for i in 3:
				ro.append(_sa(sk, a_d + hw * (float(i) - 1.0), dy - v * 0.058, 0.004, pf)[0])
			rows.append(ro)
		k.grid(rows, false, func(_i, _j, _p): return tn, func(_i, _j, p): return _hs(k, p))
		a_d += 0.31
	# yelek
	var vk := [_kp(nk, N + 0.0, 0.04), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.06], _kp(ch, C - 0.03, 0.04), _kp(wa, H + 0.12, 0.05), _kp(wa, H + 0.03, 0.056)]
	var vf := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.03 * exp(-pow(aa / 0.05, 2.0)) - 0.02 * exp(-pow((aa - 1.57) / 0.06, 2.0))
		g -= 0.022 * exp(-pow((y - (N - 0.12)) / 0.011, 2.0))
		return g + 0.008 * sin(a * 5.0 + y * 13.0) * smoothstep(C - 0.1, H + 0.08, y) * 0.0 + 0.012 * sin(y * 40.0 + a * 2.0) * (1.0 - smoothstep(H + 0.03, C - 0.06, y))
	_sheet(k, vk, 36, 78, Callable(), vf, func(a, y, _u, _v, _p): return _fs(ol, float(vf.call(a, y, 0.0)), 8.0), 0.006, 0.15)
	# şişkin rulo etek ucu: önde fermuar yarığı
	var hr := _ring_pts(vk, H + 0.035, -0.002, 84)
	var hrf := func(s: float, a: float) -> float:
		return (0.036 + 0.004 * sin(s * TAU * 7.0)) * (1.0 - 0.34 * exp(-pow((s - 0.5) / 0.012, 2.0))) * (0.92 + 0.08 * cos(a))
	_tb(k, hr, hrf, func(s, a, _p):
		var c0 := ol.lightened(0.04)
		if absf(float(s) - 0.5) < 0.012:
			return c0.darkened(0.4)
		return c0.darkened(0.2) if cos(float(a)) < -0.45 else c0, func(_s, p): return k.torso_skin(p.y), 14, true)
	# huni yaka
	var ck := [[N + 0.118, nk.x + 0.066, nk.y + 0.056, nk.z - 0.082], [N + 0.065, nk.x + 0.044, nk.y + 0.042, nk.z - 0.056], [N + 0.0, nk.x + 0.048, nk.y + 0.05, nk.z - 0.05], [N - 0.05, nk.x + 0.09, nk.y + 0.085, nk.z - 0.075]]
	var cr := func(y: float) -> Vector2:
		var e := lerpf(0.2, 0.62, smoothstep(N, N + 0.115, y))
		return Vector2(e, TAU - e)
	var cf := func(a: float, y: float, _u: float) -> float:
		return 0.022 * sin(a * 4.0 + 0.5) * smoothstep(N, N + 0.12, y)
	var crows := _sheet(k, ck, 14, 44, cr, cf, func(a, y, _u, v, _p):
		var c0 := _fs(ol, float(cf.call(a, y, 0.0)), 4.0)
		return c0.lightened(0.05) if float(v) < 0.2 else c0, 0.008, 1.0, func(p: Vector3) -> Array: return [["Neck", 0.55], ["UpperChest", 0.45]] if p.y > N else k.torso_skin(p.y))
	var top_e: Array = (crows[0] as Array).duplicate()
	_tb(k, top_e, func(_s, _a): return 0.0085, func(_s, _a, _p): return ol.lightened(0.08), func(_s, _p): return [["Neck", 0.55], ["UpperChest", 0.45]], 6)
	for ei in [0, 44]:
		var ee := []
		for ro in crows:
			ee.append(ro[ei])
		_tb(k, ee, func(_s, _a): return 0.0075, func(_s, _a, _p): return ol.lightened(0.05), func(_s, p): return [["Neck", 0.55], ["UpperChest", 0.45]] if p.y > N else k.torso_skin(p.y), 6)
	# fermuar, göğüs sekmeleri + çıtçıt, kaburgalı cep bloğu, yan kayış
	_strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.07)], true, 0.0052, 0.003, 0.002, Color(0.74, 0.74, 0.68), 10)
	for sg in [1.0, -1.0]:
		var x0: float = sg * ch.x * 0.42
		_patch(k, vk, x0 - 0.032, x0 + 0.032, N - 0.075, N - 0.125, true, 0.006, ol.lightened(0.05), 0.2)
		var e_b: Array = _fp(vk, x0, N - 0.098, true, 0.009)
		_fan(k, e_b[0], e_b[1], Vector3.UP, 0.0095, Callable(), func(_u, _v): return Color(0.66, 0.67, 0.62), k.torso_skin(N - 0.1), 2, 12)
		for i in 5:
			var x1: float = sg * (0.03 + i * 0.024)
			var y_c: float = C - 0.13
			var e_r: Array = _fp(vk, x1, y_c, true, 0.0085)
			var p_r: Vector3 = e_r[0]
			var seg_p := []
			for j in 7:
				seg_p.append(p_r + Vector3(0, 0.034 - j * 0.0113, 0))
			_tb(k, seg_p, func(s, _a): return 0.0125 * pow(maxf(0.02, sin(float(s) * PI)), 0.35), func(_s, a, _p): return ol.darkened(0.05) if cos(float(a)) > -0.2 else ol.darkened(0.28), func(_s, p): return k.torso_skin(p.y), 8)
		var yb: float = H + 0.115
		_strap(k, vk, [Vector2(sg * wa.x * 0.74, yb), Vector2(sg * (wa.x + 0.036), yb)], true, 0.011, 0.004, 0.004, ol.darkened(0.16), 6)
		var e_s: Array = _fp(vk, sg * wa.x * 0.8, yb, true, 0.0095)
		_fan(k, e_s[0], e_s[1], Vector3.UP, 0.0085, Callable(), func(_u, _v): return Color(0.6, 0.6, 0.55), k.torso_skin(yb), 2, 12)
	# sırtta Uchiha yelpazesi
	_fan_on(k, vk, 0.0, C - 0.055, false, 0.082, func(th): return _crest_r(float(th)), func(_u, v): return Color(0.72, 0.16, 0.15) if float(v) > 0.015 else Color(0.93, 0.91, 0.86), 0.005, 7, 44)


# ------------------------------------------------------------------ Oto (ref TeamDosu, Zaku): 死 yazılı bol tan üst, siyah kayış + kırmızı ip, lekeli atkı ve şalvar, siyah kolluk / tozluk
static func _oto(k) -> void:
	var tn := Color(0.77, 0.62, 0.42)
	var bk := Color(0.1, 0.1, 0.12)
	var gy := Color(0.57, 0.58, 0.68)
	var dk := Color(0.23, 0.2, 0.3)
	var rd := Color(0.68, 0.17, 0.15)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var cam := func(c0: Color, p: Vector3) -> Color: return dk if _cam(p) > 1.05 else c0
	_inner(k, b, func(_i, _j, p): return cam.call(gy, p) if p.y < H - 0.02 else bk)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_lt(k, ar, func(s, _a): return 0.005 - 0.002 * float(s), func(s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05 if sin(float(a) * 2.0 + float(s) * 16.0) > 0.4 else 0.0), 0.3, 1.0, 22, 16)
		var sa := func(s: float, a: float) -> float:
			return 0.02 + 0.05 * smoothstep(0.1, 0.56, s) + 0.009 * _lf(s, a, 4.0) * smoothstep(0.1, 0.35, s)
		_lt(k, ar, sa, func(s, a, ins): return tn.darkened(0.42) if ins else _fs(tn, float(sa.call(s, a)) - (0.02 + 0.05 * smoothstep(0.1, 0.56, float(s))), 12.0), 0.0, 0.56, 22, 20, 0.14)
		# şalvar: uylukta bol, kaval üstünde büzgülü toplanır
		var kn: float = le["kn"]
		var pa := func(s: float, a: float) -> float:
			var bag := 0.012 + 0.05 * smoothstep(0.2, 0.42, s) * (1.0 - smoothstep(kn + 0.08, kn + 0.2, s))
			var pl := 0.012 * sin(a * 7.0 + s * 3.0) * smoothstep(kn - 0.08, kn + 0.08, s) * (1.0 - smoothstep(kn + 0.13, kn + 0.2, s))
			return bag + pl + 0.009 * _lf(s, a, 2.4)
		var pr := func(s: float, a: float, ins: bool) -> Color: return gy.darkened(0.4) if ins else gy
		var ll := le
		var rows_f := func(s: float, a: float, ins: bool) -> Color:
			var pp: Vector3 = _lp(ll, s) + Vector3(sin(a), 0.0, cos(a)) * 0.08
			var c0: Color = cam.call(pr.call(s, a, ins), pp)
			return _fs(c0, float(pa.call(s, a)) - (0.012 + 0.05 * smoothstep(0.2, 0.42, s) * (1.0 - smoothstep(kn + 0.08, kn + 0.2, s))), 7.0)
		_lt(k, le, pa, rows_f, 0.0, kn + 0.2, 46, 30, 0.05)
		# tozluk: dizaltından bileğe siyah, üstü kalkık
		var ga := func(s: float, _a: float) -> float:
			return 0.01 + 0.006 * (1.0 - smoothstep(kn + 0.15, kn + 0.21, s)) - 0.003 * smoothstep(0.9, 1.0, s)
		_lt(k, le, ga, func(s, a, ins): return bk.darkened(0.3) if ins else (bk.lightened(0.08) if cos(float(a)) > 0.86 else bk), kn + 0.14, 1.0, 18, 18)
	# bol üst: belde büzülür, üstü sarkar, etek ucu açılır
	var hem: float = H - 0.17
	var by: float = H + 0.06
	var tk := [_kp(nk, N + 0.01, 0.034), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.06], _kp(ch, C - 0.03, 0.04), _kp(wa, by + 0.055, 0.044), _kp(wa, by, 0.014), _kp(hp, H - 0.04, 0.038), [hem, hp.x + 0.085, hp.y + 0.09, hp.z - 0.09]]
	var tf := func(a: float, y: float, _u: float) -> float:
		var near := exp(-pow((y - by) / 0.06, 2.0))
		var low: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		return near * 0.03 * sin(a * 11.0 + 1.0) + low * low * 0.03 * sin(a * 5.0 + 0.4) + 0.008 * sin(a * 3.0 + y * 9.0)
	_sheet(k, tk, 44, 76, Callable(), tf, func(a, y, _u, _v, _p): return _fs(tn, float(tf.call(a, y, 0.0)), 6.0), 0.007, 0.3)
	# 死 üçlüsü
	var ink := Color(0.44, 0.17, 0.12)
	_glyph(k, tk, 0.0, C + 0.012, 0.036, E.G_SHI, 0.0064, ink, true, 0.006)
	_glyph(k, tk, 0.0, C - 0.078, 0.036, E.G_SHI, 0.0064, ink, true, 0.006)
	_glyph(k, tk, 0.0, H - 0.075, 0.036, E.G_SHI, 0.0064, ink, true, 0.012)
	# siyah omuz kayışları + kuşak + kırmızı ip
	for sg in [1.0, -1.0]:
		_over(k, tk, sg * ch.x * 0.6, by + 0.03, by + 0.03, 0.0125, 0.008, 0.005, bk)
	var br := _ring_pts(tk, by, 0.006, 72)
	_tb(k, br, func(_s, a): return 0.0195 * (0.62 + 0.38 * absf(cos(float(a)))), func(_s, a, _p): return bk.lightened(0.06) if cos(float(a)) > 0.5 else bk, func(_s, p): return k.torso_skin(p.y), 8, true)
	var rr := _ring_pts(tk, by + 0.004, 0.022, 72)
	_rope(k, rr, true, 0.0062, 2, 26.0, rd, func(_s, p): return k.torso_skin(p.y), 8)
	var kn_e: Array = _fp(tk, wa.x * 0.42, by + 0.004, true, 0.03)
	_boxr(k, kn_e[0], Vector3(0.016, 0, 0), Vector3(0, 0.013, 0), Vector3(0, 0, 0.011), rd.darkened(0.1), [["Hips", 1.0]], 0.5)
	_cur_hem = hem
	var kx: float = wa.x * 0.42
	_strap(k, tk, [Vector2(kx, by - 0.008), Vector2(kx + 0.016, by - 0.07), Vector2(kx + 0.006, by - 0.15), Vector2(kx + 0.02, H - 0.13)], true, 0.0062, 0.012, 0.005, rd, 5)
	_strap(k, tk, [Vector2(kx - 0.008, by - 0.008), Vector2(kx - 0.024, by - 0.06), Vector2(kx - 0.016, by - 0.12)], true, 0.0062, 0.012, 0.005, rd.darkened(0.1), 5)
	# lekeli atkı: boyna doladıkça kalınlaşan üç tur
	var sk := [_kp(nk, N + 0.09, 0.02), _kp(nk, N - 0.02, 0.03), [N - 0.07, ch.x * 0.74, ch.y * 0.82, ch.z * 0.9]]
	var turns := [[N + 0.052, 0.018, 0.034, 1.2], [N + 0.012, 0.03, 0.042, 2.9], [N - 0.034, 0.05, 0.05, 4.4]]
	for t in turns:
		var y_t: float = t[0]
		var add: float = t[1]
		var R: float = t[2]
		var ph: float = t[3]
		var pts := []
		var st: Array = SE.El.key_at(sk, y_t)
		for i in 44:
			var a: float = TAU * i / 44.0 - PI
			var q: Vector2 = SE.El.sup(a, float(st[1]) + add, float(st[2]) + add, float(st[3]) - add, 2.0)
			pts.append(Vector3(q.x, y_t - 0.012 * (1.0 + cos(a)) + 0.006 * sin(a * 3.0 + ph), q.y))
		var rf := func(s: float, a: float) -> float:
			return R * (1.0 + 0.1 * sin(s * TAU * 3.0 + ph) + 0.08 * sin(a * 2.0 + s * TAU * 5.0))
		_tb(k, pts, rf, func(s, a, p):
			var c0: Color = cam.call(gy, (p as Vector3) * 0.72)
			return _fs(c0, 0.1 * sin(float(s) * TAU * 3.0 + ph) + 0.08 * sin(float(a) * 2.0 + float(s) * TAU * 5.0), 0.9), func(_s, _p): return [["Neck", 0.4], ["UpperChest", 0.6]], 12, true)
	# atkının sırta inen iki ucu: tuniğin üstüne yatar
	var x_t: float = -ch.x * 0.3
	_strap(k, tk, [Vector2(x_t, N - 0.075), Vector2(x_t - 0.02, C - 0.06), Vector2(x_t - 0.008, by + 0.05)], false, 0.036, 0.011, 0.008, gy, 6)
	_strap(k, tk, [Vector2(x_t + 0.058, N - 0.07), Vector2(x_t + 0.07, C - 0.04), Vector2(x_t + 0.06, C - 0.12)], false, 0.03, 0.02, 0.008, dk, 6)


# ------------------------------------------------------------------ Aburame (ref Shino_timeskip, Shibi): uzun yeşil palto, çan kol, arkaya düşmüş kapüşon, yüksek iç yaka, koyu iç etek, sırt kesesi
static func _aburame(k) -> void:
	var gr := Color(0.51, 0.58, 0.41)
	var gd := Color(0.3, 0.33, 0.22)
	var pn := Color(0.23, 0.25, 0.17)
	var wr := Color(0.87, 0.86, 0.8)
	var br := Color(0.36, 0.31, 0.2)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return gd)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sg: float = ar["sg"]
		var kn: float = le["kn"]
		_lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return gd.darkened(0.3) if ins else gd, 0.3, 1.0, 14, 14)
		# çan kol: kola doğru açılır, alt yanı sarkar
		var bell := func(s: float, a: float) -> float:
			var t := smoothstep(0.26, 0.93, s)
			var low := maxf(0.0, -sin(a) * sg)
			return 0.02 + 0.05 * t * t + 0.03 * t * low + 0.0065 * _lf(s, a, 1.9)
		_lt(k, ar, bell, func(s, a, ins):
			if ins:
				return gd.darkened(0.3)
			var c0 := _fs(gr, 0.0065 * _lf(float(s), float(a), 1.9), 18.0)
			return c0.darkened(0.14) if float(s) > 0.875 and float(s) < 0.892 else c0, 0.0, 0.93, 34, 24, 0.5)
		# kol bağı + toka
		var s_c := 0.86
		k.wrap_turn(_lp(ar, s_c), _ld(ar, s_c), _lr(ar, s_c) + float(bell.call(s_c, 0.0)) + 0.009, 0.007, 0.0, gr.darkened(0.2), _lskin(ar, s_c))
		_boxr(k, _lp(ar, s_c) + Vector3(0, 0, _lr(ar, s_c) + float(bell.call(s_c, 0.0)) + 0.018), Vector3(0.014, 0, 0), Vector3(0, 0.009, 0), Vector3(0, 0, 0.005), Color(0.55, 0.56, 0.54), _lskin(ar, s_c), 0.2)
		# bol pantolon + baldır sargısı
		var pa := func(s: float, a: float) -> float:
			return 0.012 + 0.02 * smoothstep(kn - 0.04, kn + 0.05, s) * (1.0 - smoothstep(kn + 0.09, kn + 0.2, s)) + 0.006 * _lf(s, a, 3.3)
		_lt(k, le, pa, func(s, a, ins): return pn.darkened(0.4) if ins else _fs(pn, 0.006 * _lf(float(s), float(a), 3.3), 18.0), 0.0, kn + 0.2, 34, 22, 0.05)
		_lt(k, le, func(_s, _a): return 0.003, func(_s, _a, _i): return wr.darkened(0.14), kn + 0.14, 1.0, 12, 14)
		_wraps(k, le, kn + 0.22, 0.975, 9, 0.0065, 0.0135, wr)
	# iç etek: önde ve arkada iki parça, yan yırtmaçlı
	var ik := [_kp(wa, H + 0.04, 0.02), _kp(hp, H - 0.04, 0.026), [K - 0.03, hp.x + 0.055, hp.y + 0.075, hp.z - 0.075]]
	var iff := func(a: float, y: float, _u: float) -> float:
		return clampf((H - y) / (H - K), 0.0, 1.0) * 0.02 * sin(a * 7.0 + 0.3)
	for c_a in [0.0, PI]:
		_sheet(k, ik, 20, 26, func(_y): return Vector2(float(c_a) - 1.3, float(c_a) + 1.3), iff, func(a, y, _u, _v, _p): return _fs(gd, float(iff.call(a, y, 0.0)), 8.0), 0.006)
	# palto
	var hem: float = H - 0.36
	_cur_leg = 0.8
	var ck := [_kp(nk, N + 0.005, 0.042), [N - 0.055, ch.x * 1.03, ch.y * 0.98, ch.z * 1.08], _kp(ch, C - 0.03, 0.046), _kp(wa, H + 0.12, 0.056), _kp(hp, H - 0.03, 0.056), [hem, hp.x + 0.13, hp.y + 0.145, hp.z - 0.13]]
	var cr := func(y: float) -> Vector2:
		var e := lerpf(-0.04, 0.62, smoothstep(C - 0.2, hem, y))
		return Vector2(e, TAU - e)
	var cf := func(a: float, y: float, _u: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		return t * t * (0.042 * sin(a * 5.0 + 1.1) + 0.02 * sin(a * 9.0 + 2.6)) + 0.007 * sin(a * 4.0 + y * 12.0) * (1.0 - t)
	var rows := _sheet(k, ck, 46, 80, cr, cf, func(a, y, _u, v, _p):
		var c0 := _fs(gr, float(cf.call(a, y, 0.0)), 6.0)
		return c0.darkened(0.1) if float(v) > 0.965 else c0, 0.007)
	for ei in [0, 80]:
		var ee := []
		for j in rows.size():
			if j > 3:
				ee.append(rows[j][ei])
		_rim(k, ee, 0.0065, gr.lightened(0.06))
		var z_e := []
		for p in ee:
			z_e.append((p as Vector3) + Vector3(0, 0, 0.0055))
		_rim(k, z_e, 0.0028, Color(0.86, 0.87, 0.84), 5)
	# yan cepler
	for sg in [1.0, -1.0]:
		var x0: float = sg * (hp.x * 0.62)
		_patch(k, ck, x0 - 0.052, x0 + 0.052, H - 0.11, H - 0.15, true, 0.006, gr.lightened(0.03), 0.05)
	_cur_leg = 0.58
	# yüksek iç yaka
	var ic := [_kp(nk, N + 0.125, 0.016, 0.022), _kp(nk, N + 0.07, 0.022, 0.026), _kp(nk, N - 0.02, 0.034, 0.038)]
	var ir := func(_y: float) -> Vector2: return Vector2(0.13, TAU - 0.13)
	var crows := _sheet(k, ic, 10, 40, ir, Callable(), func(_a, _y, _u, _v, _p): return gd.darkened(0.08), 0.006, 1.0, func(p: Vector3) -> Array: return [["Neck", 0.7], ["UpperChest", 0.3]] if p.y > N else k.torso_skin(p.y))
	_tb(k, crows[0], func(_s, _a): return 0.006, func(_s, _a, _p): return gd.lightened(0.05), func(_s, _p): return [["Neck", 0.7], ["UpperChest", 0.3]], 6)
	# kapüşon yakası (boyun çevresinde toplanan rulo) + sırta düşmüş kapüşon
	var hk := [_kp(nk, N + 0.02, 0.05), _kp(nk, N - 0.02, 0.05)]
	var ro_pts := _ring_pts(hk, N + 0.012, 0.0, 44)
	_tb(k, ro_pts, func(s, _a): return 0.03 * (1.0 - 0.42 * exp(-pow((float(s) - 0.5) / 0.1, 2.0))), func(s, a, _p): return gr.darkened(0.2) if cos(float(a) * 1.0 + float(s) * 9.0) < -0.75 else gr, func(_s, _p): return [["Neck", 0.3], ["UpperChest", 0.7]], 12, true)
	var hp0 := Vector3(0, N + 0.015, nk.z - 0.05)
	var hood := []
	for j in 15:
		var t := float(j) / 14.0
		hood.append(hp0 + Vector3(0, -0.3 * t, -0.075 * sin(t * PI) + 0.0 * t - 0.02 * t))
	var hrf := func(s: float, a: float) -> float:
		var r0 := 0.11 * pow(maxf(0.0, sin(PI * pow(s, 0.62))), 0.7) + 0.004
		return r0 * (0.62 + 0.45 * absf(sin(a))) * (1.0 + 0.05 * sin(a * 5.0 + s * 8.0))
	_tb(k, hood, hrf, func(s, a, _p):
		var w := cos(float(a))
		var c0 := gr.darkened(0.08) if w > 0.2 else gr
		return c0.darkened(0.16) if absf(sin(float(a) * 2.5 + float(s) * 5.0)) < 0.08 else c0, func(_s, p): return k.torso_skin(p.y), 20)
	# sırt kesesi
	var e_p: Array = _fp(ck, -hp.x * 0.34, H - 0.02, false, 0.036)
	_boxr(k, e_p[0], Vector3(0.07, 0, 0), Vector3(0, 0.08, 0), Vector3(0, 0, -0.038), br, [["Hips", 1.0]], 0.42)
	_boxr(k, (e_p[0] as Vector3) + Vector3(0, 0.05, -0.012), Vector3(0.074, 0, 0), Vector3(0, 0.028, 0), Vector3(0, 0, -0.036), br.lightened(0.07), [["Hips", 1.0]], 0.42)


# ------------------------------------------------------------------ Kaguya (ref Kaguya_Men, Kimimaro_full): gri kimono + açık yaka bandı, geniş kol, beldeki kat kat dolama, ön/arka etek, mor burgu ip ve boğumlu kuyruk
static func _kaguya(k) -> void:
	var gy := Color(0.68, 0.69, 0.75)
	var cl := Color(0.86, 0.87, 0.9)
	var pr := Color(0.4, 0.32, 0.56)
	var pn := Color(0.13, 0.13, 0.17)
	var wr := Color(0.87, 0.87, 0.85)
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
	_inner(k, b, func(_i, _j, p): return skc if p.y > H + 0.1 else pn, 0.004)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sg: float = ar["sg"]
		var kn: float = le["kn"]
		_lt(k, ar, func(_s, _a): return 0.001, func(_s, _a, _i): return skc, 0.4, 1.0, 12, 14)
		var sl := func(s: float, a: float) -> float:
			var t := smoothstep(0.08, 0.7, s)
			return 0.018 + 0.046 * t + 0.056 * t * pow(maxf(0.0, -sin(a) * sg), 2.0) + 0.006 * _lf(s, a, 5.2)
		_lt(k, ar, sl, func(s, a, ins): return gy.darkened(0.4) if ins else _fs(gy, 0.006 * _lf(float(s), float(a), 5.2), 20.0), 0.0, 0.9, 32, 24, 0.22)
		# diz altına inen bol koyu pantolon, ağzı büzgülü
		var pa := func(s: float, a: float) -> float:
			return 0.013 + 0.03 * smoothstep(kn - 0.14, kn - 0.01, s) * (1.0 - 0.5 * smoothstep(kn, kn + 0.17, s)) + 0.006 * _lf(s, a, 1.3)
		_lt(k, le, pa, func(s, a, ins): return pn.darkened(0.45) if ins else _fs(pn.lightened(0.05), 0.006 * _lf(float(s), float(a), 1.3), 18.0), 0.0, kn + 0.17, 32, 22, 0.05)
		_lt(k, le, func(_s, _a): return 0.003, func(_s, _a, _i): return wr.darkened(0.14), kn + 0.12, 1.0, 12, 14)
		k.wrap_turn(_lp(le, kn + 0.19), _ld(le, kn + 0.19), _lr(le, kn + 0.19) + 0.012, 0.018, 0.0, wr, _lskin(le, kn + 0.19))
		_wraps(k, le, kn + 0.25, 0.975, 8, 0.0065, 0.014, wr)
	# arka uzun etek: sağa doğru incelen uç
	_cur_leg = 0.85
	var bk := [_kp(wa, H + 0.05, 0.03), _kp(hp, H - 0.05, 0.052), [H - 0.6, hp.x + 0.09, hp.y + 0.1, hp.z - 0.145]]
	var bf := func(a: float, y: float, _u: float) -> float:
		return clampf((H - y) / 0.6, 0.0, 1.0) * (0.03 * sin(a * 5.0 + 0.7) + 0.015 * sin(a * 10.0))
	var br := func(y: float) -> Vector2:
		var t := pow(clampf((H - y) / 0.6, 0.0, 1.0), 1.15)
		return Vector2(PI - lerpf(1.25, 0.72, t), PI + lerpf(1.25, 0.98, t))
	_sheet(k, bk, 30, 34, br, bf, func(a, y, _u, _v, _p): return _fs(gy.darkened(0.06), float(bf.call(a, y, 0.0)), 6.0), 0.006)
	# ön etek: dize uzanan, bir yana kayan önlük
	var fk := [_kp(wa, H + 0.05, 0.032), _kp(hp, H - 0.05, 0.054), [H - 0.42, hp.x + 0.07, hp.y + 0.115, hp.z - 0.06]]
	var fr := func(y: float) -> Vector2:
		var t := pow(clampf((H - y) / 0.42, 0.0, 1.0), 1.15)
		return Vector2(lerpf(-1.05, -0.62, t), lerpf(0.92, 0.76, t))
	var ff := func(a: float, y: float, _u: float) -> float:
		return clampf((H + 0.02 - y) / 0.42, 0.0, 1.0) * (0.03 * sin(a * 6.0 + 2.1) + 0.012 * sin(a * 13.0))
	_sheet(k, fk, 26, 30, fr, ff, func(a, y, _u, _v, _p): return _fs(gy, float(ff.call(a, y, 0.0)), 6.0), 0.006)
	_fan_on(k, fk, 0.03, H - 0.2, true, 0.044, Callable(), func(u, v): return _yinyang(float(u), float(v), Color(0.94, 0.94, 0.95), Color(0.3, 0.3, 0.36)), 0.012, 9, 40)
	# kimono üstü: sol kanat sağın üstüne biner, V yaka gerçek açıklık
	var ky := [_kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.12, 0.034), _kp(wa, H + 0.04, 0.03)]
	var yc: float = C - 0.15
	var e_of := func(y: float, top: float, low: float) -> float:
		return lerpf(top, low, clampf((N + 0.012 - y) / (N + 0.012 - yc), 0.0, 1.0))
	var kr := func(y: float) -> Vector2: return Vector2(e_of.call(y, 0.56, -0.42), TAU - float(e_of.call(y, 0.56, -0.2)))
	var kf := func(a: float, y: float, u: float) -> float:
		var d := 0.018 * smoothstep(0.06, 0.0, u) - 0.03 * smoothstep(0.94, 1.0, u)
		return d + 0.012 * sin(a * 3.0 + y * 16.0) * smoothstep(C - 0.02, H + 0.05, y) + 0.008 * sin(a * 7.0 + 0.5) * smoothstep(C - 0.12, H + 0.05, y)
	var rows := _sheet(k, ky, 34, 76, kr, kf, func(a, y, _u, _v, _p): return _fs(gy, float(kf.call(a, y, 0.5)), 6.0), 0.006, 0.12)
	# yaka bandı
	for ei in [0, 76]:
		var pts := []
		var ou := []
		for j in rows.size():
			var p: Vector3 = rows[j][ei]
			if ei == 76 and p.y < yc + 0.02:
				break
			pts.append(p)
			ou.append(Vector3(p.x * 0.6, 0.12, maxf(0.35, p.z * 4.0)).normalized())
		k.strip(pts, ou, 0.019, 0.0065, cl)
	# bel dolaması: kimononun bele sarkan, kat kat katı
	var wk := [_kp(wa, H + 0.075, 0.042), _kp(hp, H - 0.03, 0.05), _kp(hp, H - 0.1, 0.062)]
	var wf := func(a: float, y: float, _u: float) -> float:
		return 0.03 * sin(y * 62.0 + a * 1.6 + 0.8) + 0.012 * sin(a * 5.0 + y * 20.0)
	_sheet(k, wk, 20, 70, Callable(), wf, func(a, y, _u, _v, _p): return _fs(gy.lightened(0.04), float(wf.call(a, y, 0.0)), 5.0), 0.007, 0.5)
	# mor burgu ip + düğüm + boğumlu kuyruk
	var ry: float = H + 0.08
	var rp := _ring_pts(wk, ry, 0.022, 96)
	var tsk := func(_s, p: Vector3) -> Array: return k.torso_skin(p.y)
	_rope(k, rp, true, 0.03, 3, 11.0, pr, tsk, 14)
	var kz: Array = _fp(wk, -wa.x * 0.34, ry, false, 0.036)
	var kc: Vector3 = kz[0]
	_boxr(k, kc, Vector3(0.042, 0, 0), Vector3(0, 0.038, 0), Vector3(0, 0, -0.03), pr.darkened(0.08), [["Spine", 1.0]], 0.55)
	var tail := []
	var c1 := kc + Vector3(-0.06, 0.1, -0.06)
	var c2 := kc + Vector3(-0.15, 0.24, -0.08)
	var c3 := kc + Vector3(-0.17, 0.37, -0.05)
	for j in 37:
		var t := float(j) / 36.0
		var u := 1.0 - t
		tail.append(kc * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + c3 * t * t * t)
	var bead := func(s: float) -> float:
		return (0.78 + 0.34 * absf(sin(s * PI * 7.5))) * (1.0 - 0.15 * s) * minf(1.0, (1.0 - s) * 22.0 + 0.1)
	_rope(k, tail, false, 0.03, 3, 5.0, pr, func(s, _p): return [["Spine", 1.0 - float(s)], ["UpperChest", float(s)]], 12, bead)
	# ipin sarkan ucu: arka eteğin üstüne yatar, kumaşla açılır
	_cur_hem = H - 0.6
	var hang := []
	for j in 19:
		var t := float(j) / 18.0
		hang.append(_fp(bk, kc.x + 0.03 + 0.05 * t + 0.012 * sin(t * 7.0), lerpf(ry - 0.03, H - 0.33, t), false, 0.03)[0])
	_rope(k, hang, false, 0.021, 3, 5.0, pr, func(_s, p): return _hs(k, p), 10, func(s): return minf(1.0, (1.0 - float(s)) * 14.0 + 0.08))


# ------------------------------------------------------------------ Oto no Yonin (ref Full_Kidomaru, Full_Tayuya): kısa kollu bej tunik, koyu iç yaka, çok kalın mor ip + arkada fiyonk ve kalkık uçlar, ön/arka peşkir, koyu şort, açık diz, bant + sargı, siyah kolluk
static func _oto_yonin(k) -> void:
	var bj := Color(0.78, 0.72, 0.6)
	var dk := Color(0.15, 0.15, 0.18)
	var pr := Color(0.5, 0.43, 0.7)
	var wr := Color(0.9, 0.89, 0.85)
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
	_inner(k, b, func(_i, _j, _p): return dk)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		# çıplak kol + kısa kol ağzı + siyah kolluk
		_lt(k, ar, func(_s, _a): return 0.001, func(_s, _a, _i): return skc, 0.1, 1.0, 22, 16)
		var sa := func(s: float, a: float) -> float:
			return 0.016 + 0.034 * smoothstep(0.08, 0.36, s) + 0.005 * _lf(s, a, 2.2)
		_lt(k, ar, sa, func(s, a, ins): return bj.darkened(0.42) if ins else _fs(bj, 0.005 * _lf(float(s), float(a), 2.2), 22.0), 0.0, 0.37, 16, 20, 0.1)
		_lt(k, ar, func(s, _a): return 0.0065 + 0.0025 * sin(float(s) * 60.0), func(s, _a, ins): return dk.darkened(0.3) if ins else (dk.lightened(0.07) if sin(float(s) * 60.0) > 0.5 else dk), 0.57, 0.965, 16, 16)
		for s_e in [0.57, 0.965]:
			k.wrap_turn(_lp(ar, s_e), _ld(ar, s_e), _lr(ar, s_e) + 0.009, 0.006, 0.0, dk.lightened(0.1), _lskin(ar, s_e))
		# şort, açık diz, baldır
		_lt(k, le, func(_s, _a): return 0.001, func(_s, _a, _i): return skc, kn * 0.7, 1.0, 26, 18)
		var pa := func(s: float, a: float) -> float:
			return 0.009 + 0.003 * _lf(s, a, 0.9) - 0.002 * smoothstep(0.2, kn * 0.88, s)
		_lt(k, le, pa, func(s, a, ins): return dk.darkened(0.4) if ins else _fs(dk.lightened(0.03), 0.003 * _lf(float(s), float(a), 0.9), 30.0), 0.0, kn * 0.88, 22, 20, 0.03)
		# bant + sargı: koyu şerit, geniş beyaz bant, sonra tur tur sargı
		_lt(k, le, func(_s, _a): return 0.005, func(s, _a, _i): return dk if float(s) < kn + 0.158 else wr.darkened(0.14), kn + 0.13, 0.99, 16, 16)
		k.wrap_turn(_lp(le, kn + 0.195), _ld(le, kn + 0.195), _lr(le, kn + 0.195) + 0.01, 0.021, 0.0, wr, _lskin(le, kn + 0.195))
		_wraps(k, le, kn + 0.26, 0.975, 8, 0.0065, 0.0135, wr)
	# arka peşkir: yana kayıp sivrilen uç
	_cur_leg = 0.85
	var bk := [_kp(wa, H + 0.06, 0.026), _kp(hp, H - 0.05, 0.03), [K + 0.02, hp.x + 0.03, hp.y + 0.05, hp.z - 0.07]]
	var bf := func(a: float, y: float, _u: float) -> float:
		return clampf((H - y) / (H - K), 0.0, 1.0) * 0.024 * sin(a * 5.0 + 1.5)
	var br := func(y: float) -> Vector2:
		var t := clampf((H - y) / (H - K - 0.02), 0.0, 1.0)
		return Vector2(PI - lerpf(0.85, 0.62, t), PI + lerpf(0.85, 0.84, t))
	_sheet(k, bk, 24, 26, br, bf, func(a, y, _u, _v, _p): return _fs(bj.darkened(0.05), float(bf.call(a, y, 0.0)), 7.0), 0.006)
	# ön peşkir: dizde biten düz kesim
	var fk := [_kp(wa, H + 0.06, 0.028), _kp(hp, H - 0.05, 0.034), [K + 0.0, hp.x + 0.02, hp.y + 0.055, hp.z - 0.05]]
	var fr := func(y: float) -> Vector2:
		var t := clampf((H - y) / (H - K), 0.0, 1.0)
		return Vector2(-lerpf(0.78, 0.62, t), lerpf(0.78, 0.62, t))
	var ff := func(a: float, y: float, _u: float) -> float:
		return clampf((H - y) / (H - K), 0.0, 1.0) * (0.012 * sin(a * 8.0 + 0.4))
	_sheet(k, fk, 24, 28, fr, ff, func(a, y, _u, _v, _p): return _fs(bj, float(ff.call(a, y, 0.0)), 8.0), 0.006)
	_fan_on(k, fk, 0.0, H - 0.21, true, 0.05, Callable(), func(u, v): return _yinyang(float(u), float(v), Color(0.95, 0.94, 0.9), Color(0.24, 0.23, 0.26)), 0.011, 9, 40)
	# tunik: kısa, çapraz, sol kanat üstte; koyu iç giysi V'de görünür
	var ty := [_kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], _kp(ch, C - 0.03, 0.032), _kp(wa, H + 0.12, 0.034), _kp(wa, H + 0.04, 0.03)]
	var yc: float = C - 0.1
	var eo := func(y: float, top: float, low: float) -> float:
		return lerpf(top, low, clampf((N + 0.012 - y) / (N + 0.012 - yc), 0.0, 1.0))
	var tr := func(y: float) -> Vector2: return Vector2(eo.call(y, 0.46, -0.3), TAU - float(eo.call(y, 0.46, -0.14)))
	var tf := func(a: float, y: float, u: float) -> float:
		return 0.016 * smoothstep(0.06, 0.0, u) - 0.03 * smoothstep(0.94, 1.0, u) + 0.009 * sin(a * 6.0 + y * 11.0) * smoothstep(C - 0.08, H + 0.05, y)
	var rows := _sheet(k, ty, 30, 72, tr, tf, func(a, y, _u, _v, _p): return _fs(bj, float(tf.call(a, y, 0.5)), 7.0), 0.006, 0.12)
	for ei in [0, 72]:
		var pts := []
		var ou := []
		for j in rows.size():
			var p: Vector3 = rows[j][ei]
			if ei == 72 and p.y < yc + 0.015:
				break
			pts.append(p)
			ou.append(Vector3(p.x * 0.6, 0.1, maxf(0.35, p.z * 4.0)).normalized())
		k.strip(pts, ou, 0.0115, 0.005, bj.darkened(0.14))
	# dev burgu ip
	var ry: float = H + 0.055
	var rp := _ring_pts(ty, ry, 0.03, 96)
	var tsk := func(_s, p: Vector3) -> Array: return k.torso_skin(p.y)
	_rope(k, rp, true, 0.047, 2, 8.0, pr, tsk, 16)
	# arkada fiyonk ve iki kalkık uç
	var kz: Array = _fp(ty, 0.0, ry, false, 0.075)
	var kc: Vector3 = kz[0]
	_boxr(k, kc, Vector3(0.05, 0, 0), Vector3(0, 0.05, 0), Vector3(0, 0, -0.04), pr.darkened(0.1), [["Spine", 1.0]], 0.6)
	for sg in [1.0, -1.0]:
		var loop := []
		for j in 21:
			var a: float = TAU * j / 20.0
			loop.append(kc + Vector3(sg * (0.1 + 0.09 * cos(a + PI)), 0.05 * sin(a) + 0.012, -0.012 - 0.018 * (1.0 + cos(a + PI))))
		_rope(k, loop, true, 0.024, 2, 3.0, pr, func(_s, _p): return [["Spine", 1.0]], 10)
		var tail := []
		var c1 := kc + Vector3(sg * 0.08, 0.1, -0.05)
		var c2 := kc + Vector3(sg * 0.2, 0.2, -0.09)
		var c3 := kc + Vector3(sg * 0.23, 0.33, -0.06)
		for j in 31:
			var t := float(j) / 30.0
			var u := 1.0 - t
			tail.append(kc * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + c3 * t * t * t)
		var bead := func(s: float) -> float:
			return (0.8 + 0.3 * absf(sin(s * PI * 5.5))) * minf(1.0, (1.0 - s) * 18.0 + 0.1)
		_rope(k, tail, false, 0.036, 2, 4.0, pr, func(s, _p): return [["Spine", 1.0 - float(s)], ["UpperChest", float(s)]], 12, bead)
