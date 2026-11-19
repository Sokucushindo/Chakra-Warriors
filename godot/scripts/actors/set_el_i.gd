extends RefCounted
## Elle modellenmiş setler, parti i: temel üniformalar (genin, shinobi, uchiha, suna, anbu, chūnin). Örnek: set_el.gd içindeki _shugonin.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_genin", "set_shinobi", "set_uchiha", "set_suna", "set_anbu", "set_chunin"]


static func recipe(k, sid: String) -> void:
	_cur_leg = 0.58
	match sid:
		"set_genin": _genin(k)
		"set_shinobi": _shinobi(k)
		"set_uchiha": _uchiha(k)
		"set_suna": _suna(k)
		"set_anbu": _anbu(k)
		"set_chunin": _chunin(k)


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
	var keys := [_kp(nk, k.N + 0.06, 0.008, 0.01), _kp(nk, k.N + 0.02, 0.016), [k.N - 0.05, ch.x * 0.8, ch.y * 0.8, ch.z * 0.9], [k.N - 0.13, ch.x * 0.92, ch.y * 0.93, ch.z * 0.96], _kp(ch, k.C - 0.03, pad), _kp(b["wa"], k.H + 0.12, pad), _kp(b["hp"], y1 if y1 > -9.0 else k.H - 0.09, pad)]
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
	if not leg:
		l["sj"] = (p0 - (m._bp(sd + "UpperArm") as Vector3)).length() / (la + lb)
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
	var w0: float = (1.0 - smoothstep(0.0, 0.14, s)) * 0.4 if l["leg"] else 1.0 - smoothstep(float(l["sj"]) - 0.02, float(l["sj"]) + 0.09, s)   # kol kökü eklem hizasına dek gövdeyle gider: omuzda sivri uç olmaz
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


static func _rim(k, pts: Array, r: float, col: Color, seg := 6) -> void:
	_tb(k, pts, func(_s, _a): return r, func(_s, _a, _p): return col, func(_s, p): return _hs(k, p), seg)


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


static func _crest_r(th: float) -> float:
	if sin(th) >= 0.0:
		return 1.0
	return maxf(1.0, minf(1.5, 0.15 / maxf(absf(cos(th)), 0.01)))


# ------------------------------------------------------------------ parti i ortak parçaları
static func _skin_c(k) -> Color:
	var c = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	return c if c is Color else Color(0.9, 0.72, 0.58)


## Kalça altı kapanışı: koşarken bacak arası boş görünmez
static func _seat(k, b: Dictionary, col: Color) -> void:
	var hp: Vector3 = b["hp"]
	var H: float = k.H
	SE.body_layer(k, [_kp(hp, H - 0.04, 0.009), [H - 0.1, hp.x * 0.95, hp.y * 0.97, hp.z * 0.97], [H - 0.15, hp.x * 0.62, hp.y * 0.72, hp.z * 0.72], [H - 0.18, 0.018, 0.018, -0.018]], 10, 36, func(_i, _j, _p): return col.darkened(0.08))


## Pantolon: add0 taban payı, bag diz üstü bolluğu, tuck paçanın toplandığı yer (s), blouse toplanma üstü şişlik
static func _pant(k, le: Dictionary, col: Color, add0: float, bag: float, tuck: float, blouse: float, sv: float) -> Callable:
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		var u := 1.0 - smoothstep(tuck - 0.03, tuck + 0.01, s)
		var cr := 0.008 * exp(-pow((s - kn) / 0.04, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var gat := 0.006 * exp(-pow((s - tuck + 0.05) / 0.05, 2.0)) * sin(a * 7.0 + sv)
		return ((0.0045 + bag * 0.14) * _lf(s, a, sv) * smoothstep(0.02, 0.12, s) + cr + gat) * u
	var ad := func(s: float, a: float) -> float:
		var u := smoothstep(tuck - 0.02, tuck + 0.02, s)
		var v := add0 + bag * exp(-pow((s - kn + 0.1) / 0.24, 2.0)) + blouse * exp(-pow((s - tuck + 0.055) / 0.06, 2.0))
		return lerpf(v, 0.003, u) + float(fo.call(s, a))
	_lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.4)
		return _fs(col, fo.call(s, a), 15.0).darkened(0.16 if s > tuck else 0.0), 0.0, 1.0, 40, 20)
	return ad


## Omuz kapağı: kol kökünün gövdeyle birleştiği yerde boşluk kalmaz (kol inince üstten gökyüzü görünmez)
static func _cap(k, ar: Dictionary, col: Color, add: float) -> void:
	var sj: float = ar["sj"]
	var a: Vector3 = ar["p0"]
	var j: Vector3 = _lp(ar, sj)
	var d: Vector3 = j - a
	var R0: float = _lr(ar, sj) + add
	var pts := []
	for i in 9:
		pts.append(a - d * 0.9 + d * 2.1 * float(i) / 8.0)
	_tb(k, pts, func(s, _a): return R0 * pow(clampf(sin(s * PI), 0.03, 1.0), 0.42), func(_s, _a, _p): return col, func(_s, _p): return [["UpperChest", 1.0]], 16)


## Boyun-baş mesafesine göre yaka ölçeği (kadın bedende yaka yüzü örtmez)
static func _hq(k) -> float:
	return clampf(((k.m._bp("Head") as Vector3).y - float(k.N)) / 0.092, 0.6, 1.2)


## Kol: s1'e kadar; dirsek kırışığı, omuz altı bolluk
static func _sleeve(k, ar: Dictionary, col: Color, add0: float, s1: float, sv: float, s0 := 0.0, puff := 0.0) -> Callable:
	var kn: float = ar["kn"]
	var fo := func(s: float, a: float) -> float:
		return 0.004 * _lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.006 * exp(-pow((s - kn) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
	var ad := func(s: float, a: float) -> float:
		return add0 + puff * sin(clampf(inverse_lerp(s0, s1, s), 0.0, 1.0) * PI) + float(fo.call(s, a))
	_lt(k, ar, ad, func(s, a, ins): return col.darkened(0.42) if ins else _fs(col, fo.call(s, a), 20.0), s0, s1, 30, 18, 0.03)
	if s0 <= 0.0:
		_cap(k, ar, col, add0)
	return ad


## Uzuv yüzeyinde nokta: [konum, dış yön]
static func _ls(l: Dictionary, s: float, a: float, lift: float) -> Array:
	var d := _ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri := (-d).cross(fw).normalized()
	var o: Vector3 = ri * sin(a) + fw * cos(a)
	return [_lp(l, s) + o * (_lr(l, s) + lift), o]


## Düz manşet / toplama bandı: uzvu kavrayan kalın halka
static func _cuff(k, l: Dictionary, s0: float, s1: float, add: float, col: Color, ribs := 0) -> void:
	_lt(k, l, func(s, a):
		var e := sin(clampf(inverse_lerp(s0, s1, s), 0.0, 1.0) * PI)
		return add * (0.72 + 0.28 * e) + (0.0012 * sin(a * float(ribs)) if ribs > 0 else 0.0), func(_s, a, ins):
		if ins:
			return col.darkened(0.42)
		return col.darkened(0.16) if ribs > 0 and sin(a * float(ribs)) < -0.2 else col, s0, s1, 6, 24 if ribs == 0 else 36)


## Kol üstündeki Konoha girdabı (T duruşunda kolun üstü, kol inince dış yan)
static func _arm_spiral(k, ar: Dictionary, s0: float, r: float, lift: float, col: Color) -> void:
	var L: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
	var R: float = _lr(ar, s0) + lift
	var a0: float = float(ar["sg"]) * PI * 0.5
	var bo: Array = _lskin(ar, s0)
	var path := []
	for i in 46:
		var t := float(i) / 45.0
		var th := t * TAU * 2.1
		path.append(Vector2(cos(th), sin(th)) * lerpf(0.12, 0.8, t) * r)
	var ring := []
	for i in 33:
		var th := TAU * i / 32.0
		ring.append(Vector2(cos(th), sin(th)) * r)
	for line in [path, ring]:
		var pts := []
		var ou := []
		for q in line:
			var e: Array = _ls(ar, s0 + float(q.y) / L, a0 + float(q.x) / R, lift)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, 0.0032, 0.0012, col, false, func(_p): return bo)


## Gövde üstünde girdap + çember
static func _spiral_on(k, keys: Array, cx: float, cy: float, r: float, front: bool, hw: float, lift: float, col: Color) -> void:
	var path := []
	for i in 56:
		var t := float(i) / 55.0
		var th := t * TAU * 2.25
		path.append(Vector2(cx + cos(th) * lerpf(0.1, 0.8, t) * r, cy + sin(th) * lerpf(0.1, 0.8, t) * r))
	_strap(k, keys, path, front, hw, lift, 0.0014, col, 1)
	var ring := []
	for i in 49:
		var th := TAU * i / 48.0
		ring.append(Vector2(cx + cos(th) * r, cy + sin(th) * r))
	_strap(k, keys, ring, front, hw * 1.15, lift, 0.0014, col, 1)


## Bel bandı: kalın, kenarları içe dönen kumaş / kayış
static func _band(k, keys: Array, y: float, hh: float, add: float, colf: Callable, bulge := 0.006, nj := 6, na := 72) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var rows := []
	for j in nj + 1:
		var t := float(j) / nj
		var yy := y + hh - t * hh * 2.0
		var b := bulge * sin(t * PI) + add
		var ro := []
		for i in na:
			var q: Vector2 = SE.El.sup(TAU * i / na - PI, float(s[1]) + b, float(s[2]) + b, float(s[3]) - b)
			ro.append(Vector3(q.x, yy, q.y))
		rows.append(ro)
	k.grid(rows, true, func(i, j, _p): return colf.call(TAU * i / na - PI, float(j) / nj), func(_i, _j, p): return k.torso_skin(p.y))


## Kumaşın gerçek yüzeyini izleyen bant: her açıda ad(s, a) kadar açılır (bol pantolonda boşlukta halka kalmaz)
static func _ring_on(k, l: Dictionary, s: float, ad: Callable, hw: float, col: Color) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var bo: Array = _lskin(l, s)
	var rows := []
	for j in 5:
		var v := float(j) / 4.0
		var s2: float = s + lerpf(-hw, hw, v) / L
		var ro := []
		for i in 40:
			var a := TAU * i / 40.0 - PI
			ro.append(_ls(l, s2, a, float(ad.call(s2, a)) - 0.001 + 0.0055 * sin(v * PI))[0])
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.14) if j in [0, 4] else col, func(_i, _j, _p): return bo)


## Uyluk kılıfı: kumaşa oturan kayışlar + kese, bacağın dış yanında
static func _holster(k, le: Dictionary, ad: Callable, band: Color, body: Color, white := false) -> void:
	var sd: String = le["sd"]
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var s0: float = kn * 0.52
	var bo := [[sd + "UpperLeg", 1.0]]
	var col: Color = Color(0.86, 0.85, 0.8) if white else band
	for i in (4 if white else 2):
		var s: float = s0 + (float(i) * 0.03 if white else float(i) * 0.15)
		_ring_on(k, le, s, ad, 0.0135 if white else 0.0115, col.darkened(0.05 * float(i % 2)))
	var s1: float = s0 + 0.07
	var c0: Vector3 = _lp(le, s1)
	var rr: float = _lr(le, s1) + float(ad.call(s1, sg * PI * 0.5))
	var o := Vector3(sg, 0, 0)
	var ce: Vector3 = c0 + o * (rr + 0.021) + Vector3(0, 0, 0.014)
	_boxr(k, ce, Vector3(0, 0, 0.038), Vector3(0, 0.058, 0), o * 0.018, body, bo, 0.26)
	_boxr(k, ce + Vector3(0, 0.044, 0) + o * 0.005, Vector3(0, 0, 0.041), Vector3(0, 0.017, 0), o * 0.02, body.lightened(0.09), bo, 0.3)
	_fan(k, ce + Vector3(0, 0.04, 0) + o * 0.0255, o, Vector3.UP, 0.007, Callable(), func(_u, _v): return Color(0.7, 0.71, 0.72), bo, 2, 12)


## Baldır sargısı: alt kat + turlar
static func _shin(k, le: Dictionary, s0: float, n: int, col: Color) -> void:
	_lt(k, le, func(_s, _a): return 0.006, func(_s, _a, _i): return col.darkened(0.2), s0, 1.0, 10, 18)
	_wraps(k, le, s0 + 0.015, 0.985, n, 0.0125, 0.0135, col, 0.009)


## Omuz üstünden geçen yastık (yelek omuzluğu). x sabit; ön ve arka uç incelir
static func _pad(k, keys: Array, x: float, y_f: float, y_b: float, hw: float, th: float, lift: float, col: Color) -> void:
	var ys: float = keys[0][0]
	while ys > keys[keys.size() - 1][0] and float(SE.El.key_at(keys, ys)[1]) <= absf(x) + 0.01:
		ys -= 0.004
	var pts := []
	var n := 12
	for j in n + 1:
		pts.append(_fp(keys, x, lerpf(y_f, ys, float(j) / n), true, lift)[0])
	for j in range(n, -1, -1):
		pts.append(_fp(keys, x, lerpf(y_b, ys, float(j) / n), false, lift)[0])
	_tb(k, pts, func(s, a):
		var e: float = pow(clampf(sin(s * PI) * 2.2, 0.02, 1.0), 0.55)
		var ca: float = cos(a) / th
		var sa: float = sin(a) / hw
		return e / sqrt(ca * ca + sa * sa), func(_s, a, _p): return col.darkened(0.14) if cos(a) < -0.2 else col, func(_s, p): return k.torso_skin(p.y), 18)


## Kenarı kesilmiş kabuk: üst kenar açıya göre iner (ytop(a)), alt kenar içe döner. Sert yelek / zırh
static func _shell(k, keys: Array, ytop: Callable, hem: float, ny: int, na: int, foldf: Callable, colf: Callable) -> Array:
	var rows := []
	for j in ny + 1:
		var v := float(j) / ny
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var y := lerpf(float(ytop.call(a)), hem, v)
			var s: Array = SE.El.key_at(keys, y)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f := 1.0 + float(foldf.call(a, y))
			ro.append(Vector3(q.x * f, y, q.y * f))
		rows.append(ro)
	var lip := []
	for p: Vector3 in rows[ny]:
		lip.append(p - Vector3(p.x, 0.0, p.z).normalized() * 0.009 + Vector3(0, 0.004, 0))
	var all: Array = rows.duplicate()
	all.append(lip)
	k.grid(all, true, func(i, j, p): return (colf.call(TAU * i / na - PI, p.y) as Color).darkened(0.35 if j > ny else 0.0), func(_i, _j, p): return k.torso_skin(p.y))
	return rows


## Parşömen cebi: taban + yan yana dik rulolar + üstten geçen kayış ve çıtçıt
static func _scrolls(k, keys: Array, x0: float, x1: float, y0: float, y1: float, col: Color, front := true) -> void:
	_patch(k, keys, x0 - 0.005, x1 + 0.005, y0 + 0.004, y1 - 0.004, front, 0.011, col.darkened(0.07), 0.06)
	var n := 3
	var r: float = absf(x1 - x0) / (n * 2.0) * 0.98
	for i in n:
		var x: float = lerpf(x0, x1, (float(i) + 0.5) / n)
		var pts := []
		for j in 11:
			pts.append(_fp(keys, x, lerpf(y0, y1, float(j) / 10.0), front, 0.009)[0])
		_tb(k, pts, func(s, _a): return r * (0.2 if s < 0.001 or s > 0.999 else 1.0), func(_s, a, _p): return _fs(col, cos(a) * 0.01, 6.0), func(_s, p): return k.torso_skin(p.y), 10)
	var ym: float = lerpf(y0, y1, 0.3)
	_strap(k, keys, [Vector2(x0 - 0.008, ym), Vector2(x1 + 0.008, ym)], front, 0.0115, 0.009 + r * 0.92, 0.004, col.lightened(0.09), 8)
	_strap(k, keys, [Vector2(x0 - 0.007, y1 + 0.006), Vector2(x1 + 0.007, y1 + 0.006)], front, 0.0085, 0.009 + r * 0.86, 0.004, col.lightened(0.06), 8)
	for sx in [0.28, 0.72]:
		var e: Array = _fp(keys, lerpf(x0, x1, sx), ym, front, 0.0145 + r * 0.92)
		_fan(k, e[0], e[1], Vector3.UP, 0.0062, Callable(), func(_u, _v): return col.darkened(0.3), k.torso_skin(ym), 2, 12)


## Uzvun dış yüzüne oturan sert plaka (kol koruması)
static func _guard(k, l: Dictionary, s0: float, s1: float, half: float, lift: float, col: Color) -> void:
	var a0: float = float(l["sg"]) * PI * 0.5
	var nu := 10
	var nv := 14
	var rows := []
	for j in nv + 1:
		var v := float(j) / nv
		var s := lerpf(s0, s1, v)
		var ro := []
		var hw: float = half * lerpf(1.0, 0.76, v)
		for i in nu + 1:
			var u := float(i) / nu
			var ed: float = minf(minf(u, 1.0 - u) * 2.0, minf(v, 1.0 - v) * 2.0)
			ro.append(_ls(l, s, a0 + lerpf(-hw, hw, u), -0.002 + (lift + 0.002) * smoothstep(0.0, 0.22, ed))[0])
		rows.append(ro)
	k.grid(rows, false, func(i, j, _p):
		var e3: float = minf(minf(float(i) / nu, 1.0 - float(i) / nu), minf(float(j) / nv, 1.0 - float(j) / nv))
		return col.darkened(0.26) if e3 < 0.09 else (col.lightened(0.08) if absf(float(i) / nu - 0.5) < 0.08 else col), func(_i, j, _p): return _lskin(l, lerpf(s0, s1, float(j) / nv)))


## Satırların iki yan kenarı
static func _edges(ro: Array) -> Array:
	var e0 := []
	var e1 := []
	for r2 in ro:
		e0.append(r2[0])
		e1.append(r2[(r2 as Array).size() - 1])
	return [e0, e1]


## Dik yaka: önü açık, üst kenarı rulo. ptop / pbot boyun payı, gap ön açıklık
static func _collar(k, nk: Vector3, N: float, h: float, ptop: float, pbot: float, gap: float, col: Color, roll := 0.008) -> void:
	h *= _hq(k)
	var ck := [_kp(nk, N + h, ptop, ptop), _kp(nk, N + h * 0.45, lerpf(ptop, pbot, 0.55)), _kp(nk, N - 0.03, pbot, pbot), _kp(nk, N - 0.075, pbot + 0.04, pbot + 0.03)]
	var hem: float = _cur_hem
	var ro: Array = _sheet(k, ck, 9, 44, func(_y): return Vector2(gap, TAU - gap), func(a, y, _u): return 0.012 * sin(a * 5.0 + y * 20.0), func(_a, _y, _u, v, _p): return col.lightened(0.05) if v < 0.2 else col, 0.007)
	_cur_hem = hem
	if roll > 0.0:
		_rim(k, ro[0], roll, col.lightened(0.04), 8)
		var ee := _edges(ro)
		_rim(k, ee[0], roll * 0.72, col.darkened(0.08), 6)
		_rim(k, ee[1], roll * 0.72, col.darkened(0.08), 6)


## Kumaşa oturan kuşak ucu
static func _tail(k, keys: Array, x: float, y0: float, ln: float, hw: float, drift: float, lift: float, col: Color, front := true) -> void:
	var pts := []
	var ou := []
	for i in 13:
		var v := float(i) / 12.0
		var e: Array = _fp(keys, x + drift * v + 0.004 * sin(v * 7.0), y0 - v * ln, front, lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, 0.0045, col, false, func(p): return _hs(k, p))


# ------------------------------------------------------------------ Genin Kunrengi: fermuarlı turuncu eğitim ceketi, siyah omuz boyunduruğu, lastikli etek ve manşet, sırtta girdap
static func _genin(k) -> void:
	var og := Color(0.93, 0.47, 0.12)
	var bk := Color(0.12, 0.12, 0.14)
	var nv := Color(0.15, 0.2, 0.33)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return bk)
	_seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_sleeve(k, ar, og, 0.012, 0.93, 1.3, 0.0, 0.005)
		_lt(k, ar, func(_s, a): return 0.0165 + 0.0015 * sin(a * 3.0), func(_s, _a, ins): return bk.darkened(0.4) if ins else bk, 0.0, 0.2, 8, 18)   # omuz başı: boyunduruğun devamı
		_cap(k, ar, bk, 0.0185)
		_cuff(k, ar, 0.915, 0.985, 0.012, bk, 16)
		var ad := _pant(k, le, nv, 0.012, 0.012, 0.93, 0.012, 2.1)
		_cuff(k, le, 0.915, 0.985, 0.011, bk, 18)
		if sd == "Right":
			_holster(k, le, ad, bk, bk.lightened(0.05), true)
	# ceket gövdesi
	var hem: float = H - 0.1
	var jk := [_kp(nk, N + 0.005, 0.026), [N - 0.055, ch.x * 0.85, ch.y * 0.91, ch.z * 1.0], [N - 0.13, ch.x * 0.95, ch.y * 0.98, ch.z * 1.03], _kp(ch, C - 0.03, 0.024), _kp(wa, H + 0.12, 0.03), _kp(hp, H - 0.03, 0.03), _kp(hp, hem, 0.028)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var s: float = clampf((y - hem) / (C - hem), 0.0, 1.0)
		return (0.018 * sin(a * 7.0 + y * 13.0) + 0.009 * sin(a * 13.0 - y * 19.0)) * (1.0 - s) + 0.006 * sin(a * 4.0 - y * 21.0) * s
	_sheet(k, jk, 44, 88, Callable(), fold, func(a, y, _u, v, _p): return _fs(og, fold.call(a, y, 0.0), 4.5).darkened(0.2 if v > 0.97 else 0.0), 0.007, 0.15, func(p): return k.torso_skin(p.y))
	_cur_hem = hem
	# siyah boyunduruk: üst kat, kendi kenarıyla
	var yk := [_kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 0.88, ch.y * 0.94, ch.z * 1.03], [N - 0.13, ch.x * 0.98, ch.y * 1.01, ch.z * 1.06], _kp(ch, C + 0.09, 0.03)]
	var yrow: Array = _sheet(k, yk, 12, 72, Callable(), Callable(), func(_a, _y, _u, _v, _p): return bk, 0.005, 0.25)
	_rim(k, yrow[yrow.size() - 1], 0.0042, og.darkened(0.42), 6)
	_cur_hem = hem
	# lastikli etek bandı
	_band(k, jk, hem + 0.022, 0.028, 0.006, func(a, _v): return bk.darkened(0.2) if sin(a * 56.0) < -0.15 else bk, 0.004, 5, 112)
	# yaka + fermuar
	_collar(k, nk, N, 0.075, 0.018, 0.04, 0.2, bk, 0.007)
	_strap(k, jk, [Vector2(0.0, N - 0.075), Vector2(0.0, hem + 0.006)], true, 0.0085, 0.0025, 0.0022, bk, 26)
	_strap(k, jk, [Vector2(0.0, N - 0.075), Vector2(0.0, hem + 0.006)], true, 0.0034, 0.005, 0.0022, Color(0.88, 0.86, 0.8), 26)
	var zp: Array = _fp(jk, 0.0, N - 0.085, true, 0.009)
	_boxr(k, zp[0], Vector3(0.0048, 0, 0), Vector3(0, 0.014, 0), (zp[1] as Vector3) * 0.003, Color(0.75, 0.75, 0.74), k.torso_skin(N - 0.085))
	# eğik yan cepler
	for sg in [1.0, -1.0]:
		_strap(k, jk, [Vector2(sg * wa.x * 0.42, H + 0.085), Vector2(sg * wa.x * 0.78, H - 0.02)], true, 0.0095, 0.003, 0.0035, bk, 10)
	# sırt: girdap
	_spiral_on(k, jk, 0.0, C - 0.075, 0.068, false, 0.0052, 0.004, Color(0.56, 0.15, 0.09))


# ------------------------------------------------------------------ Shinobi Shōzoku: file iç giysi üstüne çapraz kapanan lacivert uzun gömlek, siyah kuşak, kol ve baldır sargıları
static func _shinobi(k) -> void:
	var nv := Color(0.15, 0.2, 0.33)
	var pn := Color(0.13, 0.16, 0.26)
	var bk := Color(0.12, 0.12, 0.14)
	var wr := Color(0.9, 0.89, 0.85)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# file iç giysi: göğüs açıklığında görünür
	_inner(k, b, func(_i, _j, p):
		var w: float = absf(sin((p.x + p.y) * 150.0)) * absf(sin((p.x - p.y) * 150.0))
		return bk.lightened(0.28) if w < 0.12 and p.y < N + 0.01 else bk)
	_seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_lt(k, ar, func(_s, _a): return 0.003, func(_s, _a, _i): return wr.darkened(0.2), 0.66, 1.0, 12, 16)
		_sleeve(k, ar, nv, 0.013, 0.72, 0.8, 0.0, 0.006)
		_wraps(k, ar, 0.7, 0.975, 11, 0.0075, 0.0105, wr, 0.006)
		var ad := _pant(k, le, pn, 0.012, 0.016, 0.74, 0.013, 1.7)
		_shin(k, le, 0.71, 11, wr)
		if sd == "Right":
			_holster(k, le, ad, bk, bk.lightened(0.04))
	# çapraz gömlek: sol kanat sağın üstüne biner, kuşak altında kısa etek
	var hem: float = H - 0.2
	var by: float = H + 0.05
	var keys := [_kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 0.85, ch.y * 0.91, ch.z * 1.0], [N - 0.13, ch.x * 0.95, ch.y * 0.98, ch.z * 1.03], _kp(ch, C - 0.03, 0.022), _kp(wa, by + 0.04, 0.02), _kp(wa, by, 0.012), _kp(hp, H - 0.04, 0.034), [hem, hp.x + 0.062, hp.y + 0.052, hp.z - 0.052]]
	var open_a := func(y: float) -> float: return lerpf(0.5, -0.42, 1.0 - smoothstep(C - 0.1, N - 0.01, y))
	var rng := func(y: float) -> Vector2:
		var e: float = open_a.call(y)
		return Vector2(e, TAU - e * 0.55)
	var fold := func(a: float, y: float, _u: float) -> float:
		if y < by:
			var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
			return pow(1.0 - t, 2.0) * 0.03 * sin(a * 16.0 + 0.5) + t * (0.04 * sin(a * 8.0 + 0.7) + 0.018 * sin(a * 15.0 + 2.0))
		var s: float = clampf((y - by) / (N - by), 0.0, 1.0)
		return (1.0 - s) * (1.0 - s) * 0.024 * sin(a * 11.0 + y * 8.0) + 0.006 * sin(a * 4.0 - y * 23.0)
	var fold2 := func(a: float, y: float, u: float) -> float: return float(fold.call(a, y, u)) + 0.05 * smoothstep(0.86, 1.0, u)
	var ro: Array = _sheet(k, keys, 58, 96, rng, fold2, func(a, y, _u, v, _p): return _fs(nv, fold.call(a, y, 0.0), 4.0).darkened(0.22 if v > 0.975 else 0.0), 0.006, 0.2)
	_cur_hem = hem
	var ee := _edges(ro)
	var cut_a := 0
	var cut_b := 0
	for j in 59:
		var yj: float = lerpf(float(keys[0][0]), hem, float(j) / 58.0)
		if float(open_a.call(yj)) > 0.02:
			cut_a = j
		if yj > by + 0.02:
			cut_b = j
	for q in [[ee[0], cut_a], [ee[1], cut_b]]:
		var ou := []
		for p in q[0]:
			ou.append(Vector3(p.x * 0.6, 0.0, maxf(0.4, p.z * 4.0)).normalized())
		k.strip((q[0] as Array).slice(0, int(q[1]) + 1), ou.slice(0, int(q[1]) + 1), 0.016, 0.005, nv.darkened(0.3), false, func(p): return _hs(k, p))
	# dar yaka bandı arkadan dolanır
	_collar(k, nk, N, 0.042, 0.018, 0.03, 0.62, nv.darkened(0.2), 0.0055)
	# siyah kuşak, yanda düğüm, kumaşa oturan uçlar
	_band(k, keys, by, 0.036, 0.01, func(a, v): return bk.lightened(0.07).darkened(0.34 * float(absf(v - 0.5) < 0.07 and sin(a * 9.0) > -0.5)), 0.006, 8, 84)
	var kx: float = wa.x * 0.62
	var e0: Array = _fp(keys, kx, by, true, 0.024)
	_boxr(k, e0[0], Vector3(0.032, -0.008, 0), Vector3(0.006, 0.028, 0), (e0[1] as Vector3) * 0.014, bk.lightened(0.1), k.torso_skin(by), 0.42)
	_tail(k, keys, kx + 0.012, by - 0.03, 0.17, 0.021, 0.018, 0.011, bk.lightened(0.07))
	_tail(k, keys, kx - 0.018, by - 0.03, 0.125, 0.018, -0.012, 0.009, bk.lightened(0.03))
	# arka bel kesesi
	var e1: Array = _fp(keys, 0.0, by - 0.005, false, 0.038)
	_boxr(k, e1[0], Vector3(0.066, 0, 0), Vector3(0, 0.035, 0), Vector3(0, 0, -0.024), Color(0.32, 0.27, 0.21), [["Hips", 1.0]])
	_boxr(k, (e1[0] as Vector3) + Vector3(0, 0.026, -0.011), Vector3(0.07, 0, 0), Vector3(0, 0.014, 0), Vector3(0, 0, -0.022), Color(0.38, 0.32, 0.25), [["Hips", 1.0]])


# ------------------------------------------------------------------ Uchiha Shōzoku: huni gibi yüksek yaka, kısa kollu lacivert üst, sırtta yelpaze, koyu kolluk, koyu pantolon
static func _uchiha(k) -> void:
	var nv := Color(0.13, 0.15, 0.27)
	var dk := Color(0.12, 0.12, 0.14)
	var pn := Color(0.17, 0.17, 0.2)
	var wr := Color(0.88, 0.87, 0.82)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return dk)
	_seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		_lt(k, ar, func(_s, _a): return 0.0, func(_s, _a, _i): return sk, 0.2, kn + 0.08, 16, 16)   # kısa kol ile kolluk arası çıplak kol
		_sleeve(k, ar, nv, 0.016, kn * 0.62, 0.6, 0.0, 0.01)
		_cuff(k, ar, kn * 0.62 - 0.035, kn * 0.62, 0.021, nv.darkened(0.24))
		_lt(k, ar, func(s, a): return 0.006 + 0.0022 * sin(a * 3.0 + s * 26.0) * (1.0 - smoothstep(kn + 0.12, kn + 0.25, s)), func(s, a, ins):
			return dk.darkened(0.4) if ins else _fs(dk.lightened(0.05), 0.0022 * sin(a * 3.0 + s * 26.0), 30.0), kn + 0.035, 1.0, 22, 18, 0.03)
		_cuff(k, ar, kn + 0.035, kn + 0.075, 0.0095, dk.lightened(0.1), 14)
		_cuff(k, ar, 0.935, 0.99, 0.0095, dk.lightened(0.1), 14)
		var ad := _pant(k, le, pn, 0.013, 0.016, 0.8, 0.012, 0.9)
		_shin(k, le, 0.77, 9, wr)
		if sd == "Right":
			_holster(k, le, ad, dk, dk.lightened(0.05), true)
	# bol kesimli üst: belde serbest, kalçaya iner
	var hem: float = H - 0.12
	var keys := [_kp(nk, N + 0.01, 0.03), [N - 0.055, ch.x * 0.87, ch.y * 0.93, ch.z * 1.02], [N - 0.13, ch.x * 0.97, ch.y * 1.0, ch.z * 1.05], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.14, 0.038), _kp(hp, H - 0.03, 0.04), _kp(hp, hem, 0.05)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var s: float = clampf((y - hem) / (C - hem), 0.0, 1.0)
		var aa: float = absf(wrapf(a, -PI, PI))
		var back: float = smoothstep(2.05, 2.5, aa) * smoothstep(H + 0.06, H + 0.14, y)
		return ((1.0 - s) * (0.03 * sin(a * 6.0 + 0.8 + y * 5.0) + 0.012 * sin(a * 13.0 + y * 11.0)) + s * 0.007 * sin(a * 4.0 - y * 18.0)) * (1.0 - 0.85 * back)
	var ro: Array = _sheet(k, keys, 46, 92, Callable(), fold, func(a, y, _u, v, _p): return _fs(nv, fold.call(a, y, 0.0), 4.5).darkened(0.24 if v > 0.97 else 0.0), 0.007, 0.2)
	_cur_hem = hem
	var hr := []
	var ho := []
	for p: Vector3 in ro[ro.size() - 1]:
		hr.append(p + Vector3(0, 0.009, 0))
		ho.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(hr, ho, 0.009, 0.003, nv.darkened(0.28), false, func(p): return _hs(k, p))
	# huni yaka: boyun çevresinde yükselir, önde dar V, kalın kenar
	var hq := _hq(k)
	var ck := [[N + 0.112 * hq, nk.x + 0.062, nk.y + 0.07, nk.z - 0.052], [N + 0.075 * hq, nk.x + 0.04, nk.y + 0.048, nk.z - 0.04], [N + 0.03 * hq, nk.x + 0.026, nk.y + 0.032, nk.z - 0.032], [N - 0.03, nk.x + 0.058, nk.y + 0.058, nk.z - 0.058], [N - 0.075, nk.x + 0.1, nk.y + 0.08, nk.z - 0.08]]
	var gap_f := func(y: float) -> float: return lerpf(0.05, 0.62, smoothstep(N + 0.0, N + 0.11 * hq, y))
	var cr: Array = _sheet(k, ck, 16, 56, func(y): return Vector2(gap_f.call(y), TAU - float(gap_f.call(y))), func(a, y, _u): return 0.01 * sin(a * 5.0 + y * 16.0), func(_a, y, _u, _v, _p): return nv.lightened(0.04).darkened(0.16 * (1.0 - smoothstep(N, N + 0.05, y))), 0.008)
	_cur_hem = hem
	_rim(k, cr[0], 0.0075, nv.lightened(0.09), 8)
	var ee := _edges(cr)
	_rim(k, ee[0], 0.006, nv.lightened(0.05), 6)
	_rim(k, ee[1], 0.006, nv.lightened(0.05), 6)
	# sırtta uchiwa: koyu kenar, kırmızı üst, beyaz alt, sap
	var fy: float = C - 0.075
	_fan_on(k, keys, 0.0, fy, false, 0.086, func(th): return _crest_r(float(th)), func(_u, _v): return nv.darkened(0.4), 0.0045, 7, 44)
	_fan_on(k, keys, 0.0, fy, false, 0.077, func(th): return _crest_r(float(th)), func(_u, v): return Color(0.76, 0.14, 0.14) if float(v) > 0.0 else Color(0.93, 0.91, 0.86), 0.0065, 9, 56)
	# ince kordon
	_band(k, keys, H + 0.03, 0.009, 0.012, func(_a, _v): return dk.lightened(0.06), 0.003, 3, 96)


# ------------------------------------------------------------------ Suna Tabi: yüksek yakalı kum gömlek, geniş sarma kuşak, torba çöl şalvarı, sırtı örten kısa pelerin
static func _suna(k) -> void:
	var sh := Color(0.62, 0.5, 0.36)
	var sa := Color(0.8, 0.7, 0.5)
	var cp := Color(0.55, 0.3, 0.2)
	var wr := Color(0.4, 0.3, 0.22)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var UA: float = k.UA
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, p): return sa if p.y < k.H else sh.darkened(0.25))
	_seat(k, b, sa)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_sleeve(k, ar, sh, 0.016, 0.9, 2.2, 0.0, 0.012)
		_wraps(k, ar, 0.87, 0.975, 6, 0.0115, 0.01, wr, 0.005)
		var ad := _pant(k, le, sa, 0.02, 0.06, 0.82, 0.034, 2.7)
		_shin(k, le, 0.8, 8, wr)
		_cuff(k, le, 0.795, 0.83, 0.016, wr.darkened(0.08))
		if sd == "Left":
			_holster(k, le, ad, wr, wr.lightened(0.1))
	# gömlek: kuşağa girer
	var hem: float = H - 0.02
	var keys := [_kp(nk, N + 0.012, 0.024), [N - 0.055, ch.x * 0.85, ch.y * 0.91, ch.z * 1.0], [N - 0.13, ch.x * 0.95, ch.y * 0.98, ch.z * 1.03], _kp(ch, C - 0.03, 0.022), _kp(wa, H + 0.12, 0.032), _kp(hp, hem, 0.03)]
	var tk: Array = keys + [[H - 0.1, hp.x + 0.06, hp.y + 0.05, hp.z - 0.05], [H - 0.26, hp.x + 0.1, hp.y + 0.09, hp.z - 0.09]]
	var fold := func(a: float, y: float, _u: float) -> float:
		var s: float = clampf((y - H) / (C - H), 0.0, 1.0)
		return (1.0 - s) * (0.026 * sin(a * 9.0 + y * 10.0) + 0.012 * sin(a * 17.0 - y * 14.0)) + s * 0.006 * sin(a * 4.0 - y * 22.0)
	_sheet(k, keys, 40, 88, Callable(), fold, func(a, y, _u, v, _p): return _fs(sh, fold.call(a, y, 0.0), 4.5).darkened(0.2 if v > 0.97 else 0.0), 0.006, 0.2)
	_cur_hem = hem
	_strap(k, keys, [Vector2(0.018, N - 0.06), Vector2(0.03, C - 0.12)], true, 0.0048, 0.002, 0.002, sh.darkened(0.32), 12)
	# geniş sarma kuşak: üç kat
	var sy: float = H + 0.05
	for i in 3:
		var ty: float = sy + 0.05 - float(i) * 0.05
		var off := float(i) * 1.3
		var c0: Color = wr.lightened(0.12 if i == 1 else 0.05)
		_band(k, keys, ty, 0.03, 0.016 + 0.0035 * float(2 - i), func(a, v): return c0.darkened(0.26 * clampf(absf(v - 0.5) * 3.0 - 0.9, 0.0, 1.0) + 0.1 * float(sin(a * 7.0 + off) > 0.45)), 0.006, 7, 80)
	var kx: float = -wa.x * 0.55
	_cur_hem = H - 0.26
	_tail(k, tk, kx, sy - 0.07, 0.17, 0.027, -0.018, 0.017, wr.lightened(0.1))
	_tail(k, tk, kx + 0.03, sy - 0.07, 0.125, 0.022, 0.012, 0.014, wr.lightened(0.02))
	_cur_hem = hem
	# yüksek gömlek yakası
	_collar(k, nk, N, 0.082, 0.024, 0.04, 0.3, sh.darkened(0.1), 0.0075)
	# kısa pelerin: sırt paneli + üstüne binen omuz örtüsü (kollar altından serbest çıkar)
	var chem: float = H + 0.09
	var torso := func(p: Vector3) -> Array: return k.torso_skin(maxf(p.y, H + 0.05))
	var bk := [[N - 0.05, UA + 0.03, ch.y + 0.03, ch.z - 0.05], [C - 0.03, UA + 0.07, ch.y + 0.05, ch.z - 0.058], [chem, ch.x + 0.09, wa.y + 0.09, wa.z - 0.1]]
	var pf := func(a: float, y: float, _u: float) -> float:
		var t2: float = clampf((N - 0.05 - y) / (N - 0.05 - chem), 0.0, 1.0)
		return t2 * (0.032 * sin(a * 6.0 + 0.4) + 0.012 * sin(a * 13.0 + 1.1))
	var pr: Array = _sheet(k, bk, 28, 44, func(_y): return Vector2(2.2, TAU - 2.2), pf, func(a, y, _u, v, _p): return _fs(cp, pf.call(a, y, 0.0), 3.6).darkened(0.24 if v > 0.97 else 0.0), 0.007, 1.0, torso)
	var pk := [[N + 0.022, nk.x + 0.05, nk.y + 0.056, nk.z - 0.056], [N - 0.022, UA * 0.86, ch.y * 0.8, ch.z * 0.86], [N - 0.075, UA + 0.05, ch.y + 0.03, ch.z - 0.05], [N - 0.15, UA + 0.085, ch.y + 0.055, ch.z - 0.07]]
	var mf := func(a: float, y: float, _u: float) -> float: return 0.012 * sin(a * 8.0 + 0.5) * smoothstep(N - 0.04, N - 0.15, y)
	var mr: Array = _sheet(k, pk, 16, 80, func(_y): return Vector2(0.16, TAU - 0.16), mf, func(a, y, _u, v, _p): return _fs(cp.lightened(0.05), mf.call(a, y, 0.0), 5.0).darkened(0.24 if v > 0.96 else 0.0), 0.007, 1.0, torso)
	_cur_hem = hem
	for e3 in [pr[pr.size() - 1], mr[mr.size() - 1]]:
		var hm := []
		var ho := []
		for p: Vector3 in e3:
			hm.append(p + Vector3(0, 0.009, 0))
			ho.append(Vector3(p.x, 0.0, p.z).normalized())
		k.strip(hm, ho, 0.0085, 0.0028, sa.darkened(0.08), false, func(p): return k.torso_skin(p.y))
	# boyun bağı + toka
	var e2: Array = _fp(pk, 0.0, N - 0.012, true, 0.008)
	_boxr(k, e2[0], Vector3(0.018, 0, 0), Vector3(0, 0.012, 0), (e2[1] as Vector3) * 0.007, Color(0.68, 0.62, 0.47), k.torso_skin(N))


# ------------------------------------------------------------------ ANBU Shōzoku: kolsuz koyu yüksek boyunlu giysi, omuz dövmesi, geniş askılı açık gri göğüs zırhı, uzun kolluk + kol koruması, baldır sargısı
static func _anbu(k) -> void:
	var dk := Color(0.12, 0.12, 0.14)
	var pl := Color(0.76, 0.76, 0.74)
	var st := Color(0.21, 0.21, 0.24)
	var wr := Color(0.9, 0.89, 0.86)
	var red := Color(0.74, 0.16, 0.13)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return dk)
	_seat(k, b, dk)
	_collar(k, nk, N, 0.078, 0.012, 0.024, 0.02, dk, 0.0)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		_lt(k, ar, func(_s, _a): return 0.0, func(_s, _a, _i): return sk, 0.0, kn + 0.08, 22, 18)
		_lt(k, ar, func(s, a): return 0.0065 + 0.002 * sin(a * 3.0 + s * 24.0) * (1.0 - smoothstep(kn + 0.1, kn + 0.25, s)), func(_s, _a, ins): return dk.darkened(0.4) if ins else dk.lightened(0.04), kn - 0.03, 1.0, 24, 18, 0.03)
		for i in 3:
			k.wrap_turn(_lp(ar, kn - 0.012 + float(i) * 0.03), _ld(ar, kn), _lr(ar, kn) + 0.012, 0.0115, 0.003, wr if i != 1 else dk, _lskin(ar, kn + 0.01))
		_guard(k, ar, kn + 0.12, 0.92, 1.05, 0.0135, pl.darkened(0.08))
		for s in [kn + 0.15, 0.885]:
			k.wrap_turn(_lp(ar, s), _ld(ar, s), _lr(ar, s) + 0.0135, 0.0075, 0.0, st, _lskin(ar, s))
		_cuff(k, ar, 0.945, 0.995, 0.0105, st)
		if sd == "Left":
			_arm_spiral(k, ar, 0.2, 0.034, 0.0015, red)
		var ad := _pant(k, le, dk.lightened(0.03), 0.011, 0.013, 0.76, 0.012, 3.1)
		_shin(k, le, 0.73, 11, wr)
		if sd == "Right":
			_holster(k, le, ad, st, st)
	# göğüs zırhı: boyun altı oyuk, kol altı açık, belde kalın rulo
	var top_y: float = N - 0.075
	var hem: float = H + 0.035
	var keys := [[N - 0.05, ch.x * 0.66, ch.y * 0.92, ch.z * 0.98], [N - 0.13, ch.x * 0.84, ch.y + 0.012, ch.z - 0.012], _kp(ch, C - 0.03, 0.026), _kp(wa, H + 0.12, 0.026), _kp(wa, hem, 0.038)]
	var ytop := func(a: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		var scoop: float = 0.05 * exp(-pow(aa / 0.34, 2.0)) + 0.012 * exp(-pow((aa - PI) / 0.44, 2.0))
		var arm: float = 0.1 * exp(-pow((aa - PI * 0.5) / 0.6, 2.0))
		return top_y - scoop - arm
	var groove := func(a: float, y: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		var g: float = -0.024 * exp(-pow((y - (H + 0.13)) / 0.008, 2.0)) - 0.022 * exp(-pow((aa - 1.57) / 0.05, 2.0))
		g -= 0.016 * exp(-pow(aa / 0.02, 2.0)) * smoothstep(H + 0.13, H + 0.11, y)
		return g
	var rows: Array = _shell(k, keys, ytop, hem, 34, 96, groove, func(a, y): return _fs(pl, groove.call(a, y), 7.5))
	_cur_hem = hem
	_rim(k, rows[0] + [rows[0][0]], 0.0066, pl.darkened(0.22), 8)
	var wst: Array = _ring_pts(keys, hem + 0.008, 0.016, 80)
	_tb(k, wst, func(_s, a): return 0.0165 * (0.82 + 0.18 * absf(cos(a))), func(_s, a, _p): return pl.darkened(0.08 if cos(a) > -0.3 else 0.26), func(_s, p): return k.torso_skin(p.y), 10, true)
	# geniş omuz askıları (önden arkaya), metal kopçalar
	var ak := [_kp(nk, N + 0.014, 0.018), [N - 0.045, ch.x * 0.72, ch.y * 0.94, ch.z * 1.0], [N - 0.13, ch.x * 0.87, ch.y + 0.018, ch.z - 0.018], _kp(ch, C - 0.04, 0.03)]
	for sg in [1.0, -1.0]:
		_pad(k, ak, sg * ch.x * 0.5, N - 0.125, N - 0.125, 0.032, 0.0085, 0.004, pl.darkened(0.06))
		for fr in [true, false]:
			var e: Array = _fp(ak, sg * ch.x * 0.5, N - 0.128, fr, 0.0125)
			_boxr(k, e[0], Vector3(0.019, 0, 0), Vector3(0, 0.0085, 0), (e[1] as Vector3) * 0.004, st.lightened(0.28), k.torso_skin(N - 0.128))
	# kemer + iki arka kese
	var bk2 := [_kp(hp, H + 0.02, 0.03), _kp(hp, H - 0.03, 0.03)]
	_band(k, bk2, H - 0.002, 0.018, 0.004, func(_a, v): return st.darkened(0.2 if v < 0.15 or v > 0.85 else 0.0), 0.003, 4, 72)
	for sg in [1.0, -1.0]:
		var e: Array = _fp(bk2, sg * hp.x * 0.72, H - 0.005, false, 0.024)
		_boxr(k, e[0], Vector3(0.027, 0, 0), Vector3(0, 0.03, 0), (e[1] as Vector3) * 0.016, st, [["Hips", 1.0]])


# ------------------------------------------------------------------ Konoha Chūnin: lacivert dik yakalı gömlek ve pantolon, yeşil taktik yelek (rulo etek, yastık omuz, parşömen cepleri, fermuar), girdap armaları
static func _chunin(k) -> void:
	var nv := Color(0.12, 0.15, 0.3)
	var ve := Color(0.46, 0.56, 0.44)
	var red := Color(0.72, 0.17, 0.14)
	var wr := Color(0.88, 0.87, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return nv)
	_seat(k, b, nv)
	_collar(k, nk, N, 0.07, 0.012, 0.022, 0.02, nv, 0.0)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_sleeve(k, ar, nv, 0.011, 0.915, 1.1, 0.0, 0.004)
		_lt(k, ar, func(s, a): return 0.0165 + 0.0035 * sin(s * 60.0 + a), func(s, a, ins): return nv.darkened(0.42) if ins else _fs(nv, 0.0035 * sin(s * 60.0 + a), 20.0), 0.885, 0.98, 8, 18)   # kıvrılmış kol ağzı
		_arm_spiral(k, ar, 0.2, 0.032, 0.015, red)
		var ad := _pant(k, le, nv, 0.012, 0.02, 0.74, 0.02, 1.5)
		_shin(k, le, 0.71, 10, wr)
		if sd == "Right":
			_holster(k, le, ad, nv.darkened(0.3), nv.lightened(0.05), true)
	# yelek gövdesi: dolgun, omuzdan bele
	var hem: float = H + 0.02
	var vk := [_kp(nk, N + 0.005, 0.034), [N - 0.055, ch.x * 0.92, ch.y * 0.96, ch.z * 1.05], [N - 0.13, ch.x * 1.0, ch.y * 1.03, ch.z * 1.08], _kp(ch, C - 0.03, 0.036), _kp(wa, H + 0.12, 0.04), _kp(wa, hem, 0.05)]
	var quilt := func(a: float, y: float, _u: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		var g: float = -0.02 * exp(-pow((y - (H + 0.1)) / 0.009, 2.0)) - 0.012 * exp(-pow((aa - 1.75) / 0.05, 2.0))
		return g + 0.008 * sin(a * 4.0 + y * 7.0) * smoothstep(C + 0.04, C - 0.1, y)
	_sheet(k, vk, 38, 92, Callable(), quilt, func(a, y, _u, v, _p): return _fs(ve, quilt.call(a, y, 0.0), 6.5).darkened(0.2 if v > 0.97 else 0.0), 0.008, 0.18)
	_cur_hem = hem
	# rulo etek: yeleğin kalın alt kenarı
	var wst: Array = _ring_pts(vk, hem + 0.012, 0.01, 88)
	_tb(k, wst, func(_s, a): return 0.031 * (0.86 + 0.14 * absf(cos(a))), func(s, a, _p):
		var c0: Color = ve.darkened(0.04 if cos(a) > -0.3 else 0.22)
		return c0.darkened(0.1 * float(sin(s * TAU * 14.0) > 0.92)), func(_s, p): return k.torso_skin(p.y), 12, true)
	# yastık yaka: önü açık, yanlarda dik durur
	var hq := _hq(k)
	var ck := [[N + 0.078 * hq, nk.x + 0.05, nk.y + 0.05, nk.z - 0.05], [N + 0.05 * hq, nk.x + 0.058, nk.y + 0.058, nk.z - 0.056], [N + 0.008, nk.x + 0.06, nk.y + 0.06, nk.z - 0.06], [N - 0.04, nk.x + 0.078, nk.y + 0.066, nk.z - 0.068], [N - 0.08, nk.x + 0.12, nk.y + 0.09, nk.z - 0.09]]
	var cq := func(a: float, y: float, _u: float) -> float: return 0.018 * sin(a * 9.0 + 0.6) * smoothstep(N - 0.02, N + 0.05, y)
	var cr: Array = _sheet(k, ck, 12, 52, func(_y): return Vector2(0.62, TAU - 0.62), cq, func(a, y, _u, _v, _p): return _fs(ve, cq.call(a, y, 0.0), 4.0), 0.009)
	_cur_hem = hem
	_rim(k, cr[0], 0.0105, ve.lightened(0.05), 10)
	var ee := _edges(cr)
	_rim(k, ee[0], 0.0085, ve.darkened(0.03), 8)
	_rim(k, ee[1], 0.0085, ve.darkened(0.03), 8)
	# yastık omuzluklar + çıtçıt + göğüs parşömen cepleri
	for sg in [1.0, -1.0]:
		var px: float = sg * ch.x * 0.74
		_pad(k, vk, px, N - 0.105, N - 0.105, 0.05, 0.017, 0.01, ve.lightened(0.03))
		var e: Array = _fp(vk, px, N - 0.098, true, 0.03)
		_fan(k, e[0], e[1], Vector3.UP, 0.0085, Callable(), func(u, v): return Color(0.62, 0.64, 0.62).darkened(0.3 if sqrt(float(u) * float(u) + float(v) * float(v)) > 0.72 else 0.0), k.torso_skin(N - 0.098), 3, 14)
		var x0: float = sg * 0.026
		var x1: float = sg * minf(0.128, wa.x * 0.8)
		_scrolls(k, vk, minf(x0, x1), maxf(x0, x1), C + 0.085, C - 0.05, ve.darkened(0.02))
	# fermuar
	_strap(k, vk, [Vector2(0.0, N - 0.075), Vector2(0.0, hem - 0.016)], true, 0.0062, 0.002, 0.002, ve.darkened(0.32), 26)
	_strap(k, vk, [Vector2(0.0, N - 0.075), Vector2(0.0, hem - 0.016)], true, 0.0026, 0.0042, 0.002, Color(0.82, 0.84, 0.82), 26)
	var e_w: Array = _fp(vk, 0.0, hem + 0.012, true, 0.033)
	_boxr(k, e_w[0], Vector3(0.006, 0, 0), Vector3(0, 0.016, 0), (e_w[1] as Vector3) * 0.003, Color(0.78, 0.8, 0.78), k.torso_skin(hem))
	# sırt girdabı + bel kesesi
	_spiral_on(k, vk, 0.0, C - 0.075, 0.074, false, 0.0064, 0.006, red)
	var e_b: Array = _fp([_kp(hp, H, 0.02), _kp(hp, H - 0.1, 0.02)], 0.0, H - 0.05, false, 0.03)
	_boxr(k, e_b[0], Vector3(0.07, 0, 0), Vector3(0, 0.034, 0), Vector3(0, 0, -0.024), Color(0.5, 0.44, 0.33), [["Hips", 1.0]])
	_boxr(k, (e_b[0] as Vector3) + Vector3(0, 0.026, -0.01), Vector3(0.074, 0, 0), Vector3(0, 0.014, 0), Vector3(0, 0, -0.024), Color(0.56, 0.5, 0.38), [["Hips", 1.0]])
