extends RefCounted
## Elle modellenmiş setler, parti h: set_shakunetsu, set_yogan, set_awa, set_nanao, set_nekomata, set_genso. Örnek: set_el.gd içindeki _shugonin.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_shakunetsu", "set_yogan", "set_awa", "set_nanao", "set_nekomata", "set_genso"]


static func recipe(k, sid: String) -> void:
	_cur_long = false
	match sid:
		"set_shakunetsu": _shakunetsu(k)
		"set_yogan": _yogan(k)
		"set_awa": _awa(k)
		"set_nanao": _nanao(k)
		"set_nekomata": _nekomata(k)
		"set_genso": _genso(k)
	_cur_long = false


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
static var _cur_long := false


static func _hs(k, p: Vector3) -> Array:
	if _cur_robe:
		return _robe_skin(k, p, _cur_hem)
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


# ------------------------------------------------------------------ kimono / uzuv yardımcıları
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



# ------------------------------------------------------------------ parti h yardımcıları
static func _b(k) -> Dictionary:
	var b := _base(k)
	b["bl"] = k.M(k.H + 0.04, 0.3)
	b["ub"] = k.M(k.C - 0.12, k.UA)
	return b


## Gövde kesitleri (boyundan kalçaya), p kadar dışarıda
static func _tk(k, b: Dictionary, p: float) -> Array:
	var ch: Vector3 = b["ch"]
	return [_kp(b["nk"], k.N + 0.012, p + 0.016, p + 0.014), [k.N - 0.055, ch.x * 0.97 + p, ch.y * 0.9 + p, ch.z * 0.99 - p], _kp(ch, k.C - 0.03, p), _kp(b["ub"], k.C - 0.125, p), _kp(b["wa"], k.H + 0.12, p), _kp(b["bl"], k.H + 0.04, p), _kp(b["hp"], k.H - 0.05, p + 0.004)]


## Bilek boyu giysi: yalnız uyluğu izler, sağ-sol geçişi geniş; arka etek geri giden bacağa daha çok uyar
static var _cur_robe := false


static func _robe_skin(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var back: float = smoothstep(0.05, -0.09, p.z)
	var w: float = lerpf(0.62, 0.8, back) * smoothstep(0.0, 0.3, t)
	var sd: float = smoothstep(-0.13, 0.13, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * sd], ["RightUpperLeg", w * (1.0 - sd)]]


## Açık ten gövde: boyundan y1'e
static func _skin_body(k, b: Dictionary, skc: Color, y1: float) -> Array:
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var hp: Vector3 = b["hp"]
	var ub: Vector3 = b["ub"]
	var keys := [[k.N + 0.03, nk.x, nk.y, nk.z], [k.N - 0.05, ub.x * 0.62, ch.y * 0.8, ch.z * 0.88], [k.C - 0.03, ub.x + 0.002, ch.y + 0.002, ch.z - 0.002], _kp(ub, k.C - 0.125, 0.001), _kp(b["wa"], k.H + 0.12, 0.001), _kp(b["bl"], k.H + 0.04, 0.001), [y1, hp.x * 0.98, hp.y * 0.98, hp.z * 0.98]]
	SE.body_layer(k, keys, 28, 40, func(_i, _j, _p): return skc)
	return keys


## Kalça altı: bacak aralığını kapatan don
static func _pelvis(k, b: Dictionary, col: Color, p := 0.008) -> void:
	var hp: Vector3 = b["hp"]
	SE.body_layer(k, [_kp(b["bl"], k.H + 0.035, p * 0.5), _kp(hp, k.H - 0.05, p), [k.H - 0.145, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 8, 32, func(_i, _j, _p): return col)


static func _cc(c: Color) -> Callable:
	return func(_a, _y, _v): return c


static func _cy(y: float) -> Callable:
	return func(_a): return y


static func _torso(k) -> Callable:
	return func(p): return k.torso_skin(p.y)


## Geniş sargı / kuşak ucu: (açı, y) yolu boyunca, kesiti kabarık, uçları kumaşa iner
static func _wb(k, keys: Array, ctrl: Array, hw: float, lift: float, col: Color, steps := 5, nu := 6, foldf := Callable(), edge := 0.2) -> void:
	var P := _path(ctrl, steps)
	var n := P.size()
	var R0 := 0.16
	var rows := []
	var at_row = func(j: int, lf: float) -> Array:
		var a: Vector2 = P[maxi(0, j - 1)]
		var b: Vector2 = P[mini(n - 1, j + 1)]
		var no := Vector2(b.y - a.y, -(b.x - a.x) * R0).normalized()
		var ro := []
		for i in nu + 1:
			var u := lerpf(-1.0, 1.0, float(i) / nu)
			var q: Vector2 = P[j] + Vector2(no.x * hw * u / R0, no.y * hw * u)
			ro.append(_sa(keys, q.x, q.y, 0.0012 + lf * sqrt(maxf(0.0, 1.0 - u * u)), foldf)[0])
		return ro
	rows.append(at_row.call(0, 0.0))
	for j in n:
		rows.append(at_row.call(j, lift))
	rows.append(at_row.call(n - 1, 0.0))
	var a0: Vector3 = rows[1][1]
	var fn: Vector3 = -((rows[1][2] as Vector3) - a0).cross((rows[2][2] as Vector3) - a0)
	if fn.dot(_out(a0)) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(i, j, _p): return col.darkened(edge) if i == 0 or i == nu or j <= 1 or j >= n else col, func(_i, _j, p): return _hs(k, p))


## Düz (açı, y) çizgi; yalnız inside(a, y) doğru olan parçalar çizilir
static func _lc(k, keys: Array, p0: Vector2, p1: Vector2, inside: Callable, hw: float, lift: float, d: float, col: Color, n := 22) -> void:
	var pts := []
	var ou := []
	var flush = func() -> void:
		if pts.size() >= 2:
			k.strip(pts.duplicate(), ou.duplicate(), hw, d, col, false, func(p): return _hs(k, p))
		pts.clear()
		ou.clear()
	for i in n + 1:
		var q: Vector2 = p0.lerp(p1, float(i) / n)
		if bool(inside.call(q.x, q.y)):
			var e: Array = _sa(keys, q.x, q.y, lift)
			pts.append(e[0])
			ou.append(e[1])
		else:
			flush.call()
	flush.call()


## Uzuv yüzeyine oturan dil biçimli plaka (üstü yuvarlak)
static func _tongue(k, l: Dictionary, s0: float, s1: float, a0: float, ha: float, base: float, lift: float, col: Color) -> void:
	var rows := []
	var nu := 12
	var nv := 9
	for j in nv + 1:
		var v := float(j) / nv
		var ro := []
		for i in nu + 1:
			var u := lerpf(-1.0, 1.0, float(i) / nu)
			var top := 1.0 - sqrt(maxf(0.0, 1.0 - u * u))
			var s := lerpf(s0 + (s1 - s0) * 0.42 * top, s1, v)
			var ed := minf(1.0 - absf(u), minf(v * 2.0, 1.0 - v))
			var sm := smoothstep(0.0, 0.3, ed)
			ro.append(_lsurf(l, s, a0 + u * ha, base + lift * sm - 0.014 * (1.0 - sm))[0])
		rows.append(ro)
	var c0: Vector3 = rows[1][nu / 2 - 1]
	var fn: Vector3 = -((rows[1][nu / 2] as Vector3) - c0).cross((rows[2][nu / 2 - 1] as Vector3) - c0)
	if fn.dot(_lsurf(l, lerpf(s0, s1, 0.2), a0, 0.0)[1]) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(i, j, _p):
		var e := minf(float(mini(i, nu - i)) / nu, minf(float(j) / nv, float(nv - j) / nv))
		return col.darkened(0.26) if e < 0.08 else col, func(_i, j, _p): return _lskin(l, lerpf(s0, s1, float(j) / nv)))


# ------------------------------------------------------------------ Shakunetsu (ref Pakura: Scorch_Release, ParukaAnime): boyundan bağlı dik yakalı koyu üst, çıplak omuz, uzun eflatun eldiven, gri + beyaz sarılı kuşak, sağı yırtmaçlı eflatun etek + koyu ön peşkir, sağ uylukta sargı ve kese
static func _shakunetsu(k) -> void:
	var dk := Color(0.2, 0.2, 0.24)
	var li := Color(0.56, 0.5, 0.6)
	var gr := Color(0.6, 0.6, 0.64)
	var wh := Color(0.9, 0.89, 0.86)
	var bt := Color(0.16, 0.16, 0.18)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _b(k)
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	_skin_body(k, b, skc, H - 0.02)
	_pelvis(k, b, dk.darkened(0.3))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sg: float = le["sg"]
		var kn: float = le["kn"]
		var ak: float = ar["kn"]
		_bare(k, ar, skc, 0.0, 0.34)
		_bare(k, le, skc, 0.0, kn + 0.2)
		_lt(k, le, func(_s, _a): return 0.002, func(_s, _a, ins): return dk.darkened(0.45 if ins else 0.25), 0.045, 0.1, 4, 18)
		# uzun eldiven: pazu ortasından bileğe, üst ağzı dışa doğru sivri
		var gf := func(s: float, a: float) -> float: return 0.0022 * _lf(s, a, 1.4) + 0.0032 * exp(-pow((s - ak) / 0.05, 2.0)) * sin(a * 3.0 + s * 36.0)
		_lts(k, ar, func(s, a): return 0.005 + float(gf.call(s, a)) + 0.004 * smoothstep(0.8, 1.0, s), func(s, a, ins):
			return li.darkened(0.42) if ins else _fs(li, float(gf.call(s, a)), 30.0), func(a): return 0.27 - 0.035 * sin(a) * sg, 0.985, 26, 20)
		k.wrap_turn(_lp(ar, 0.975), _ld(ar, 0.975), _lr(ar, 0.975) + 0.009, 0.007, 0.0, li.darkened(0.22), _lskin(ar, 0.975))
		# konç: dizin altından, önde sivri
		_lts(k, le, func(s, a): return 0.009 + 0.012 * (1.0 - smoothstep(kn + 0.09, kn + 0.2, s)) + 0.0014 * sin(a * 3.0 + s * 24.0), func(_s, _a, ins):
			return bt.darkened(0.4) if ins else bt, func(a): return kn + 0.14 - 0.08 * pow(maxf(0.0, cos(a)), 3.0), 1.0, 20, 20)
	# sağ uyluk: sargı + kese
	var rl := _limb(k, "Right", true)
	_wraps(k, rl, 0.2, 0.3, 5, 0.008, 0.0125, wh, 0.006)
	var pe: Array = _lsurf(rl, 0.25, -0.62, 0.026)
	var po: Vector3 = pe[1]
	_boxr(k, pe[0], Vector3(po.z, 0.0, -po.x).normalized() * 0.034, Vector3(0, 0.042, 0), po * 0.02, bt.lightened(0.05), [["RightUpperLeg", 1.0]], 0.3)
	_boxr(k, (pe[0] as Vector3) + po * 0.018 + Vector3(0, 0.026, 0), Vector3(po.z, 0.0, -po.x).normalized() * 0.03, Vector3(0, 0.014, 0), po * 0.006, bt.lightened(0.12), [["RightUpperLeg", 1.0]], 0.3)
	# boyundan bağlı üst: omuzlar açık, kol oyukları boyna doğru kesilir
	var tk := _tk(k, b, 0.007)
	var ht := func(a: float) -> float:
		var q: float = absf(a)
		var d: float = minf(q, PI - q)
		return lerpf(N + 0.012, C - 0.075, smoothstep(0.3, 1.2, d))
	var fold := func(a: float, y: float, _v: float) -> float:
		return 0.006 * sin(a * 7.0 + y * 12.0) * smoothstep(C, H + 0.1, y) + 0.003 * sin(a * 4.0 - y * 22.0)
	_cl(k, {"keys": tk, "ny": 30, "na": 100, "top": ht, "hem": _cy(H + 0.03), "fold": fold, "col": _cc(dk), "skin": _torso(k), "th": 0.004, "gain": 9.0})
	for f in [[1.0, 0.0], [-1.0, 0.0], [1.0, PI], [-1.0, PI]]:
		var ctrl := []
		for i in 9:
			var d: float = lerpf(0.26, 1.42, float(i) / 8.0)
			var a: float = float(f[1]) + float(f[0]) * d * (1.0 if float(f[1]) == 0.0 else -1.0)
			ctrl.append(Vector2(a, float(ht.call(wrapf(a, -PI, PI))) - 0.004))
		_line(k, tk, ctrl, 0.0042, 0.003, 0.0028, dk.lightened(0.12), 2)
	# dik yaka: önde küçük çentik, ortadan inen kapanış ve tek düğme
	var ck := [_kp(nk, N + 0.09, 0.012), _kp(nk, N + 0.0, 0.02)]
	var cg := _cl(k, {"keys": ck, "ny": 6, "na": 48, "top": func(a): return N + 0.085 - 0.022 * exp(-pow(a / 0.2, 2.0)), "hem": _cy(N + 0.002), "col": _cc(dk), "skin": _torso(k), "th": 0.004})
	_bd(k, cg["top"], 0.003, 0.0022, dk.lightened(0.14), true, _torso(k), 0.5)
	_line(k, tk, [Vector2(0.0, N + 0.008), Vector2(0.018, N - 0.05), Vector2(-0.012, N - 0.1), Vector2(0.008, C + 0.0)], 0.0024, 0.002, 0.0016, dk.darkened(0.45), 5)
	var bq: Array = _sa(tk, 0.012, N - 0.052, 0.003)
	_stud(k, bq[0], bq[1], 0.0075, gr, [["UpperChest", 1.0]])
	# etek: sağ önden yırtmaçlı, diz altına iner
	var hem: float = K + 0.02
	_cur_long = true
	var sk := [[H + 0.05, bl.x + 0.014, bl.y + 0.014, bl.z - 0.03], [H - 0.05, hp.x + 0.022, hp.y + 0.022, hp.z - 0.06], [K + 0.16, hp.x + 0.036, hp.y + 0.038, hp.z - 0.07], [hem, hp.x + 0.042, hp.y + 0.042, hp.z - 0.07]]
	var sf := func(a: float, y: float, v: float) -> float:
		return v * v * (0.042 * sin(a * 5.0 + 0.7) + 0.02 * sin(a * 11.0 + 1.9)) + (1.0 - v) * 0.006 * sin(a * 9.0 + y * 8.0)
	var sg0 := _cl(k, {"keys": sk, "ny": 34, "na": 96, "rng": func(_v): return Vector2(-0.16, TAU - 1.2), "top": _cy(H + 0.045), "hem": func(a): return hem + 0.018 * sin(a * 2.0 + 0.6), "fold": sf, "col": _cc(li), "inner": li.darkened(0.45), "th": 0.006})
	_tr(k, sg0["ea"], 0.004, 0.002, li.darkened(0.22))
	_tr(k, sg0["eb"], 0.004, 0.002, li.darkened(0.22))
	var h2 := []
	for p in sg0["hem"]:
		h2.append(p + Vector3(0, 0.011, 0))
	_tr(k, h2, 0.0034, 0.0016, li.darkened(0.25))
	# koyu ön peşkir: kuşaktan dize, ucu verev
	var pk := [_kp(bl, H + 0.055, 0.022), _kp(hp, H - 0.05, 0.03), [K + 0.16, hp.x + 0.046, hp.y + 0.054, hp.z - 0.048], [hem, hp.x + 0.052, hp.y + 0.058, hp.z - 0.054]]
	var pf := func(a: float, _y: float, v: float) -> float: return v * 0.016 * sin(a * 9.0 + 0.4)
	var pg := _cl(k, {"keys": pk, "ny": 26, "na": 26, "rng": func(v): return Vector2(-0.44 - 0.05 * float(v), 0.42 + 0.03 * float(v)), "top": _cy(H + 0.05), "hem": func(a): return K + 0.085 - 0.06 * clampf(a + 0.3, -0.1, 0.8), "fold": pf, "col": _cc(dk), "inner": dk.darkened(0.4), "th": 0.006})
	_tr(k, pg["ea"], 0.0034, 0.0018, dk.lightened(0.1))
	_tr(k, pg["eb"], 0.0034, 0.0018, dk.lightened(0.1))
	_tr(k, pg["hem"], 0.0034, 0.0018, dk.lightened(0.1))
	_cur_long = false
	# kuşak: geniş gri bez, üstüne sarılı beyaz turlar
	var sh := _tk(k, b, 0.022)
	_sash(k, sh, H + 0.078, 0.05, 0.0, gr, 0.12)
	for e in [[H + 0.09, wh], [H + 0.058, wh.darkened(0.04)], [H + 0.04, wh]]:
		_sash(k, sh, float(e[0]), 0.0085, 0.0075, e[1], 0.06)


# ------------------------------------------------------------------ Yōgan (ref Roshi_OL, Roshi_design): eflatun çapraz üst, koyu kat yaka, file göğüs, deri göğüslük, koyu kuşak, kalçada üç katlı bağcıklı deri tasset, bol pantolon + koyu konç, kolluk
static func _yogan(k) -> void:
	var pl := Color(0.44, 0.22, 0.32)
	var pn := Color(0.4, 0.2, 0.29)
	var co := Color(0.24, 0.22, 0.24)
	var br := Color(0.37, 0.28, 0.17)
	var dg := Color(0.2, 0.21, 0.2)
	var rd := Color(0.56, 0.2, 0.2)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var chv: Vector3 = b["ch"]
	var ik := _tk(k, b, 0.006)
	SE.body_layer(k, ik, 24, 44, func(_i, _j, _p): return co.darkened(0.3))
	_pelvis(k, b, pn.darkened(0.3))
	_net_patch(k, ik, func(a, y): return absf(float(a)) < lerpf(0.05, 0.62, clampf((float(y) - (C - 0.09)) / (N - C + 0.09), 0.0, 1.0)), -0.66, 0.66, C - 0.09, N + 0.01, 0.019, 0.0017, 0.004, Color(0.42, 0.4, 0.38))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var ak: float = ar["kn"]
		# bol pantolon: diz altında büzülür; altında koyu konç
		_lts(k, le, func(s, a): return 0.008 + 0.0016 * sin(a * 3.0 + s * 22.0), func(s, _a, ins):
			return dg.darkened(0.4) if ins else dg.darkened(0.1 * smoothstep(0.88, 0.96, s)), func(_a): return kn + 0.18, 1.0, 22, 20)
		_pant(k, le, pn, 0.04, 0.8 if sd == "Left" else 2.1, 0.2, kn + 0.25)
		k.wrap_turn(_lp(le, kn + 0.245), _ld(le, kn + 0.245), _lr(le, kn + 0.245) + 0.014, 0.011, 0.003, pn.darkened(0.16), _lskin(le, kn + 0.245))
		# kol: bileğe doğru açılan yen, altında koyu kolluk
		_lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return dg.darkened(0.3 if ins else 0.0), 0.34, 1.0, 16, 14)
		var sf := func(s: float, a: float) -> float: return 0.0035 * _lf(s, a, 1.7) * (0.5 + s) + 0.005 * exp(-pow((s - ak) / 0.07, 2.0)) * sin(a * 3.0 + s * 36.0)
		_lt(k, ar, func(s, a): return 0.016 + 0.03 * smoothstep(0.12, 0.72, s) + float(sf.call(s, a)) - 0.014 * (1.0 - smoothstep(0.0, 0.11, s)), func(s, a, ins):
			return pl.darkened(0.46) if ins else _fs(pl, float(sf.call(s, a)), 24.0), 0.0, 0.74, 30, 22, 0.2)
		_lts(k, ar, func(s, _a): return 0.009 + 0.004 * smoothstep(0.9, 1.0, s), func(_s, _a, ins): return dg.darkened(0.4) if ins else dg.lightened(0.05), func(a): return 0.66 - 0.03 * cos(a), 0.985, 12, 18)
	# üst giysi: uyluk ortasına kadar, sol kanat üstte
	var hem: float = H - 0.235
	var keys := [_kp(b["nk"], N + 0.014, 0.034, 0.03), [N - 0.055, chv.x * 1.02, chv.y * 0.96, chv.z * 1.06], _kp(chv, C - 0.03, 0.03), _kp(b["ub"], C - 0.125, 0.032), _kp(b["wa"], H + 0.12, 0.034), _kp(bl, H + 0.04, 0.03), _kp(hp, H - 0.05, 0.04), [hem, hp.x + 0.075, hp.y + 0.066, hp.z - 0.066]]
	var e_top := 0.5
	var e_low := -0.42
	var y_cl: float = H + 0.08
	var y0: float = keys[0][0]
	var ee := func(y: float) -> float: return lerpf(e_top, e_low, clampf((y0 - y) / (y0 - y_cl), 0.0, 1.0))
	var fold := func(a: float, y: float) -> float:
		if y < H:
			var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
			return pow(1.0 - t, 2.0) * 0.03 * sin(a * 15.0 + 0.4) + t * t * (0.04 * sin(a * 6.0 + 0.9) + 0.02 * sin(a * 13.0 + 2.0))
		return 0.012 * sin(a * 8.0 + y * 8.0) * smoothstep(H + 0.25, H + 0.05, y) + 0.005 * sin(a * 3.0 - y * 18.0)
	var rows := _kimono(k, keys, e_top, e_low, y_cl, fold, func(a, y, _v, _p): return _fs(pl, float(fold.call(a, y)), 6.0), 50, 104, 0.007)
	_hem(k, rows[rows.size() - 1], 0.0045, 0.002, pl.darkened(0.26), 0.012)
	var pth := []
	for i in 6:
		var y: float = lerpf(hem + 0.004, y_cl, float(i) / 6.0)
		pth.append(Vector2(e_low - 0.005, y))
	for i in 9:
		var y: float = lerpf(y_cl, y0, float(i) / 8.0)
		pth.append(Vector2(float(ee.call(y)) - 0.005, y))
	for i in range(1, 10):
		pth.append(Vector2(lerpf(e_top, TAU - e_top * 0.55, float(i) / 10.0), y0 + 0.004))
	for i in range(8, 2, -1):
		var y: float = lerpf(y_cl, y0, float(i) / 8.0)
		pth.append(Vector2(TAU - float(ee.call(y)) * 0.55 + 0.005, y))
	_band(k, keys, pth, func(_t): return 0.036, 0.009, co, 3, 6, 0.08, 0.14)
	# deri göğüslük: önde ve arkada, omuz kayışlı, kalın kenarlı
	var ck := _tk(k, b, 0.052)
	for c0 in [0.0, PI]:
		var cm: float = c0
		var rn := func(_v): return Vector2(cm - 1.08, cm + 1.08)
		var tt := func(a: float) -> float:
			var q: float = absf(wrapf(a - cm, -PI, PI))
			return C + 0.05 - 0.018 * smoothstep(0.55, 1.08, q) - (0.0 if cm == 0.0 else 0.02)
		var g := _cl(k, {"keys": ck, "ny": 18, "na": 40, "rng": rn, "top": tt, "hem": _cy(H + 0.06), "fold": func(a, y, _v): return 0.004 * sin(float(a) * 6.0 + float(y) * 11.0), "col": _cc(br), "inner": br.darkened(0.5), "th": 0.008, "skin": _torso(k), "gain": 10.0})
		_bd(k, g["top"], 0.0048, 0.0028, br.lightened(0.1), false, _torso(k), 0.3)
		_bd(k, g["ea"], 0.0044, 0.0026, br.darkened(0.2), false, _torso(k))
		_bd(k, g["eb"], 0.0044, 0.0026, br.darkened(0.2), false, _torso(k))
		for u in [-0.6, 0.6]:
			_line(k, ck, [Vector2(cm + float(u), C + 0.03), Vector2(cm + float(u) * 1.05, H + 0.09)], 0.0022, 0.003, 0.0014, br.darkened(0.3), 6)
	for sx: float in [1.0, -1.0]:
		var sa0: float = sx * 0.72
		var yy: float = N - 0.03
		_wb(k, keys, [Vector2(sa0, C + 0.03), Vector2(sx * 0.88, yy - 0.03), Vector2(sx * 1.3, yy), Vector2(sx * 1.9, yy), Vector2(sx * 2.26, yy - 0.03), Vector2(sx * 2.42, C + 0.01)], 0.019, 0.012, br.darkened(0.08), 5, 4)
	# kuşak
	var ok := _tk(k, b, 0.058)
	_obi(k, ok, H + 0.045, 0.034, 0.0, co.darkened(0.1), 80)
	# tasset: her yanda üç kat, alttaki üsttekinin altından çıkar, bağcıkla asılı
	var tf := [_kp(bl, H + 0.06, 0.05), _kp(hp, H - 0.05, 0.062), [H - 0.44, hp.x + 0.11, hp.y + 0.1, hp.z - 0.1]]
	_cur_hem = H - 0.44
	for sx in [1.0, -1.0]:
		var ca: float = float(sx) * 1.5
		var leg: String = "LeftUpperLeg" if float(sx) > 0.0 else "RightUpperLeg"
		var ts := func(_p): return [["Hips", 0.55], [leg, 0.45]]   # plaka tek parça: koşarken köşeleri ayrı ayrı çekilip yırtılmaz
		for i in range(2, -1, -1):
			var y1: float = H + 0.055 - float(i) * 0.128
			var y2: float = y1 - 0.15
			var ha: float = 0.56 - float(i) * 0.02
			var tcol: Color = br.darkened(0.05 * float(i))
			var fi := float(i)
			var g := _cl(k, {"keys": tf, "ny": 8, "na": 22, "rng": func(_v): return Vector2(ca - ha, ca + ha), "top": _cy(y1), "hem": func(a): return y2 + 0.006 * sin(float(a) * 9.0), "fold": func(a, _y, _v): return 0.012 * sin(float(a) * 5.0 + fi), "col": _cc(tcol), "inner": tcol.darkened(0.5), "th": 0.009, "lift": 0.006 * (2.0 - fi) + 0.004, "gain": 4.0, "skin": ts})
			_cur_hem = H - 0.44
			_bd(k, g["top"], 0.004, 0.0024, tcol.lightened(0.08), false, ts)
			_bd(k, g["hem"], 0.004, 0.0024, tcol.darkened(0.2), false, ts)
			if i > 0:
				for u in [-0.6, 0.6]:
					var a: float = ca + float(u) * ha
					var p0: Array = _sa(tf, a, y1 + 0.022, 0.012 + 0.006 * (2.0 - fi))
					var p1: Array = _sa(tf, a, y1 - 0.018, 0.012 + 0.006 * (2.0 - fi))
					_cord(k, [p0[0], (p0[0] as Vector3).lerp(p1[0], 0.5) + (p0[1] as Vector3) * 0.003, p1[0]], 0.0036, rd, false, ts, 0.0, 6)
	_cur_hem = hem


# ------------------------------------------------------------------ Awa (ref Utakata_full): bileğe inen önü açık açık mavi giysi, koyu mavi yaka bandı, çıplak göğüs + koyu iç peşkir, çok geniş yenler, turuncu dikiş barları, kalın turuncu kuşak, ön düğüm ve uzun iki uç
static func _awa(k) -> void:
	var bl_c := Color(0.62, 0.74, 0.8)
	var in_c := Color(0.21, 0.25, 0.46)
	var or_c := Color(0.88, 0.47, 0.13)
	var dk := Color(0.15, 0.15, 0.17)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var F: float = k.F
	var b := _b(k)
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var ch: Vector3 = b["ch"]
	_skin_body(k, b, skc, H + 0.02)
	_pelvis(k, b, dk)
	var hem: float = F + 0.1
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sg: float = ar["sg"]
		var ak: float = ar["kn"]
		_bare(k, ar, skc, 0.3, 1.0)
		_lt(k, le, func(_s, _a): return 0.0015, func(_s, _a, ins): return dk.darkened(0.3 if ins else 0.0), 0.0, 1.0, 26, 16)   # uzun giysinin altı: ince, etek içinde kalır
		# geniş yen: omuzdan bileğe genişler, ağzı astarlı; alt yanı daha bol
		var sf := func(s: float, a: float) -> float: return 0.006 * _lf(s, a, 2.3) * (0.3 + s) + 0.006 * exp(-pow((s - ak) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
		var sa := func(s: float, a: float) -> float:
			var w: float = smoothstep(0.08, 0.9, s)
			return 0.016 + 0.052 * w + 0.022 * w * (0.5 - 0.5 * sin(a) * sg) + float(sf.call(s, a)) - 0.016 * (1.0 - smoothstep(0.0, 0.11, s))
		_lt(k, ar, sa, func(s, a, ins): return in_c.darkened(0.25) if ins else _fs(bl_c, float(sf.call(s, a)), 18.0), 0.0, 0.93, 36, 26, 0.3)
		_lt(k, ar, func(s, a): return float(sa.call(s, a)) + 0.0015, func(_s, _a, ins): return in_c.darkened(0.25) if ins else in_c, 0.905, 0.93, 2, 26)
		# turuncu dikiş barları: yenin dış yüzünde ve ağzına yakın
		for e in [[0.33, 0.42], [0.53, 0.62], [0.74, 0.83]]:
			var ao: float = 0.5 * sg
			var pts := []
			var ou := []
			for i in 5:
				var s: float = lerpf(float(e[0]), float(e[1]), float(i) / 4.0)
				var d := _ld(ar, s)
				var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
				var ri := (-d).cross(fw).normalized()
				var o: Vector3 = ri * sin(ao) + fw * cos(ao)
				pts.append(_lp(ar, s) + o * (_lr(ar, s) + float(sa.call(s, ao)) + 0.0012))
				ou.append(o)
			var s_mid: float = lerpf(float(e[0]), float(e[1]), 0.5)
			k.strip(pts, ou, 0.0095, 0.0022, or_c, false, func(_p): return _lskin(ar, s_mid))
	# koyu iç peşkir: göğüs altından bileğe, açıklıkta görünür
	_cur_robe = true
	var ik := [_kp(b["ub"], C - 0.1, 0.006), _kp(b["wa"], H + 0.12, 0.008), _kp(bl, H + 0.04, 0.008), _kp(hp, H - 0.05, 0.016), [k.K, hp.x + 0.03, hp.y + 0.03, hp.z - 0.03], [hem + 0.02, hp.x + 0.04, hp.y + 0.036, hp.z - 0.036]]
	_cl(k, {"keys": ik, "ny": 30, "na": 34, "rng": func(_v): return Vector2(-0.62, 0.62), "top": _cy(C - 0.1), "hem": _cy(hem + 0.03), "fold": func(a, _y, v): return float(v) * 0.012 * sin(float(a) * 8.0), "col": _cc(dk), "inner": dk, "th": 0.004})
	# ana giysi: önü açık, omuzdan bileğe
	var keys := [_kp(b["nk"], N + 0.014, 0.036, 0.03), [N - 0.055, ch.x * 1.04, ch.y * 0.98, ch.z * 1.08], _kp(ch, C - 0.03, 0.032), _kp(b["ub"], C - 0.125, 0.034), _kp(b["wa"], H + 0.12, 0.036), _kp(bl, H + 0.04, 0.03), _kp(hp, H - 0.05, 0.05), [k.K + 0.04, hp.x + 0.084, hp.y + 0.082, hp.z - 0.09], [hem, hp.x + 0.115, hp.y + 0.105, hp.z - 0.125]]
	var yt: float = N + 0.014
	var yb: float = H + 0.05
	var e_y := func(y: float) -> float:
		if y >= yb:
			return lerpf(0.13, 0.66, pow(clampf((y - yb) / (yt - yb), 0.0, 1.0), 0.75))
		return lerpf(0.13, 0.22, clampf((yb - y) / (yb - hem), 0.0, 1.0))
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		if y >= H:
			return 0.012 * sin(a * 9.0 + y * 10.0) * smoothstep(H + 0.22, H + 0.04, y) + 0.004 * sin(a * 3.0 - y * 16.0)
		return pow(1.0 - t, 3.0) * 0.024 * sin(a * 15.0 + 0.6) + t * (0.042 * sin(a * 5.0 + 0.5) + 0.018 * sin(a * 11.0 + 1.7))
	# diz üstüne kadar tek parça; altı arka yanlardan yırtmaçlı üç kanat: koşarken geri giden bacak yırtmaçtan çıkar, kumaşı delmez
	var yv: float = H - 0.14
	var rs := func(p): return _robe_skin(k, p, hem)
	var hemf := func(a): return hem + 0.012 * sin(float(a) * 3.0 + 0.7)
	_cl(k, {"keys": keys, "ny": 30, "na": 112, "rng": func(v):
			var e: float = float(e_y.call(lerpf(yt, yv, float(v))))
			return Vector2(e, TAU - e), "top": _cy(yt), "hem": _cy(yv), "fold": fold, "col": _cc(bl_c), "inner": in_c.darkened(0.12), "th": 0.007, "gain": 5.5, "skin": rs})
	var y_at := func(v) -> float: return lerpf(yv + 0.012, hem, float(v))
	var vent := 0.5
	var pans := [
		[func(v): return float(e_y.call(float(y_at.call(v)))), func(v): return PI - vent - 0.2 * float(v), 46],
		[func(v): return PI - vent + 0.2 * float(v), func(v): return PI + vent - 0.2 * float(v), 24],
		[func(v): return PI + vent + 0.2 * float(v), func(v): return TAU - float(e_y.call(float(y_at.call(v)))), 46]]
	for q in pans:
		var fa: Callable = q[0]
		var fb: Callable = q[1]
		var g := _cl(k, {"keys": keys, "ny": 38, "na": q[2], "rng": func(v): return Vector2(float(fa.call(v)), float(fb.call(v))), "top": _cy(yv + 0.012), "hem": hemf, "fold": fold, "col": _cc(bl_c), "inner": in_c.darkened(0.12), "th": 0.007, "gain": 5.5, "lift": 0.001, "skin": rs})
		_cur_hem = hem
		var hm := []
		for p in g["hem"]:
			hm.append(p + Vector3(0, 0.014, 0))
		_tr(k, hm, 0.003, 0.0015, bl_c.darkened(0.25))
		if q != pans[0]:
			_tr(k, g["ea"], 0.0034, 0.0016, bl_c.darkened(0.2))
		if q != pans[2]:
			_tr(k, g["eb"], 0.0034, 0.0016, bl_c.darkened(0.2))
	# yaka bandı: etekten yukarı, göğüste genişler, enseden geçip öbür yana iner
	var pth := []
	for i in 9:
		var y: float = lerpf(hem + 0.006, yb, float(i) / 8.0)
		pth.append(Vector2(float(e_y.call(y)) - 0.004, y))
	for i in range(1, 9):
		var y: float = lerpf(yb, yt, float(i) / 8.0)
		pth.append(Vector2(float(e_y.call(y)) - 0.004, y))
	for i in range(1, 10):
		pth.append(Vector2(lerpf(0.655, TAU - 0.655, float(i) / 10.0), yt + 0.005))
	for i in range(8, 0, -1):
		var y: float = lerpf(yb, yt, float(i) / 8.0)
		pth.append(Vector2(TAU - float(e_y.call(y)) + 0.004, y))
	for i in range(8, -1, -1):
		var y: float = lerpf(hem + 0.006, yb, float(i) / 8.0)
		pth.append(Vector2(TAU - float(e_y.call(y)) + 0.004, y))
	var nt := float(pth.size() - 1)
	var u0: float = 8.0 / nt
	var u1: float = 16.0 / nt
	var wf := func(t) -> float:
		var q: float = minf(float(t), 1.0 - float(t))
		return 0.02 if q < u0 else lerpf(0.02, 0.05, smoothstep(u0, u1, q))
	_band(k, keys, pth, wf, 0.008, in_c, 3, 6, 0.08, 0.12)
	# kuşak: geniş, önde sol yanda düğüm; iki uzun uç kumaş üstünde iner
	var ok := [_kp(b["wa"], H + 0.13, 0.05), _kp(bl, H + 0.04, 0.046), _kp(hp, H - 0.03, 0.058)]
	_sash(k, ok, H + 0.055, 0.052, 0.0, or_c, 0.1)
	var ka := 0.42
	var kq: Array = _sa(ok, ka, H + 0.05, 0.02)
	var kc: Vector3 = kq[0]
	var ko: Vector3 = kq[1]
	var kx := Vector3(ko.z, 0.0, -ko.x).normalized()
	for e in [[0.036, -0.012, or_c.darkened(0.14)], [-0.03, 0.01, or_c.darkened(0.06)]]:
		_boxr(k, kc + kx * float(e[0]) + Vector3(0, float(e[1]), 0) + ko * 0.008, kx * 0.03, Vector3(0.0, 0.03, 0.0) + kx * float(e[1]) * 1.2, ko * 0.016, e[2], [["Hips", 0.6], ["Spine", 0.4]], 0.4)
	_boxr(k, kc + ko * 0.016, kx * 0.02, Vector3(0, 0.03, 0), ko * 0.016, or_c.lightened(0.05), [["Hips", 0.6], ["Spine", 0.4]], 0.45)
	_wb(k, keys, [Vector2(ka + 0.08, H + 0.005), Vector2(ka + 0.13, H - 0.2), Vector2(ka + 0.2, H - 0.42), Vector2(ka + 0.24, k.K + 0.05)], 0.038, 0.016, or_c.darkened(0.08), 5, 6, fold)
	_wb(k, keys, [Vector2(ka - 0.05, H + 0.005), Vector2(ka - 0.1, H - 0.22), Vector2(ka - 0.1, H - 0.5), Vector2(ka - 0.14, k.K - 0.03)], 0.042, 0.022, or_c, 5, 6, fold)
	# yan bağ: sağ kalçada ince ip
	var ss := func(p): return _hs(k, p)
	for e in [[-1.2, -0.05, 0.17], [-1.27, 0.05, 0.14]]:
		var pts := []
		for i in 7:
			var t := float(i) / 6.0
			pts.append(_sa(keys, float(e[0]) + float(e[1]) * t, H - 0.002 - float(e[2]) * t, 0.012, fold)[0])
		_cord(k, pts, 0.0034, or_c.darkened(0.08), false, ss, 0.0, 6)
	_cur_robe = false


# ------------------------------------------------------------------ Nanao (ref Fu_OL): kısa beyaz askılı üst, göğüste çapraz kırmızı bant ve sırtta kırmızı bez, file göğüs altı, çıplak bel, verev kanatlı kısa beyaz etek + file şort, ayrı beyaz kolluk, koyu pazubent, beyaz bilek sargısı
static func _nanao(k) -> void:
	var wh := Color(0.9, 0.89, 0.86)
	var rd := Color(0.6, 0.16, 0.13)
	var dk := Color(0.15, 0.15, 0.17)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var sk_k := _skin_body(k, b, skc, H - 0.01)
	_pelvis(k, b, dk)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sg: float = ar["sg"]
		var ak: float = ar["kn"]
		_bare(k, ar, skc)
		_bare(k, le, skc)
		_lt(k, le, func(_s, _a): return 0.004, func(_s, _a, ins): return dk.darkened(0.3 if ins else 0.0), 0.04, 0.07, 3, 18)
		_net_limb(k, le, 0.05, 0.24, 0.005, 9, 0.024, 0.0014, dk)
		k.wrap_turn(_lp(le, 0.245), _ld(le, 0.245), _lr(le, 0.245) + 0.005, 0.0055, 0.0, dk, _lskin(le, 0.245))
		# kolluk: dirsek üstünden bileğe, ağzı dışa doğru sivri, bilekte açılır
		var cf := func(s: float, a: float) -> float: return 0.0024 * _lf(s, a, 2.2) + 0.003 * exp(-pow((s - ak) / 0.05, 2.0)) * sin(a * 3.0 + s * 34.0)
		_lts(k, ar, func(s, a): return 0.006 + 0.011 * smoothstep(0.72, 0.98, s) + float(cf.call(s, a)), func(s, a, ins):
			return wh.darkened(0.4) if ins else _fs(wh, float(cf.call(s, a)), 22.0), func(a): return 0.36 - 0.05 * sin(a) * sg, 0.965, 22, 20)
		k.wrap_turn(_lp(ar, 0.945), _ld(ar, 0.945), _lr(ar, 0.945) + 0.0175, 0.0045, 0.0, wh.darkened(0.14), _lskin(ar, 0.945))
		# ayak bileği sargısı
		_lts(k, le, func(s, a): return 0.008 + 0.009 * (1.0 - smoothstep(0.88, 0.96, s)) + 0.0012 * sin(a * 5.0), func(_s, _a, ins):
			return wh.darkened(0.4) if ins else wh, func(a): return 0.85 - 0.015 * cos(a), 1.0, 10, 18)
		k.wrap_turn(_lp(le, 0.905), _ld(le, 0.905), _lr(le, 0.905) + 0.012, 0.0055, 0.003, wh.darkened(0.1), _lskin(le, 0.905))
	# koyu pazubent: sol kol
	var la := _limb(k, "Left", false)
	_wraps(k, la, 0.2, 0.26, 3, 0.005, 0.0105, dk.lightened(0.04), 0.0)
	# kısa üst: geniş askılar boyna çıkar, göğüs altında biter
	var tk := _tk(k, b, 0.007)
	var hem_top: float = C - 0.095
	var tt := func(a: float) -> float:
		var q: float = absf(a)
		var d: float = minf(q, PI - q)
		var strap: float = exp(-pow((d - 0.62) / 0.2, 2.0))
		var base: float = lerpf(C + 0.1, C + 0.01, smoothstep(0.8, 1.45, d))
		return lerpf(base, N + 0.004, strap)
	var fo := func(a: float, y: float, _v: float) -> float: return 0.004 * sin(a * 6.0 + y * 16.0)
	var tg := _cl(k, {"keys": tk, "ny": 18, "na": 100, "top": tt, "hem": _cy(hem_top), "fold": fo, "col": _cc(wh), "skin": _torso(k), "th": 0.004, "gain": 12.0})
	_bd(k, tg["top"], 0.0032, 0.0022, wh.darkened(0.12), true, _torso(k), 0.4)
	# file göğüs altı: iki koyu biye arasında gerçek ağ
	var y_n: float = C - 0.185
	_net_patch(k, sk_k, func(_a, y): return float(y) < hem_top + 0.002 and float(y) > y_n, -PI, PI, y_n, hem_top + 0.002, 0.02, 0.0016, 0.004, dk)
	var nk2 := _tk(k, b, 0.006)
	_sash(k, nk2, hem_top - 0.001, 0.006, -0.004, dk, 0.0)
	_sash(k, nk2, y_n, 0.0055, -0.006, dk, 0.0)
	# kırmızı bant: omuzdan karşı böğre çapraz, göğüste kesişir; arkada da aynı
	var tb := _tk(k, b, 0.011)
	for sx: float in [1.0, -1.0]:
		_wb(k, tb, [Vector2(sx * 0.6, N - 0.004), Vector2(sx * 0.42, C + 0.07), Vector2(-sx * 0.1, C - 0.025), Vector2(-sx * 0.72, C - 0.09), Vector2(-sx * 1.5, C - 0.1)], 0.0135, 0.009, rd, 5, 4)
		_wb(k, tb, [Vector2(PI + sx * 0.6, N - 0.004), Vector2(PI + sx * 0.42, C + 0.07), Vector2(PI - sx * 0.1, C - 0.025), Vector2(PI - sx * 0.72, C - 0.09), Vector2(PI - sx * 1.56, C - 0.1)], 0.0135, 0.009, rd.darkened(0.06), 5, 4)
	# sırtta kırmızı bez: omuzların arasından kalça altına
	var ck := [_kp(b["ub"], C + 0.05, 0.022), _kp(b["ub"], C - 0.125, 0.024), _kp(b["wa"], H + 0.12, 0.05), _kp(bl, H + 0.04, 0.05), _kp(hp, H - 0.05, 0.06), [H - 0.3, hp.x + 0.08, hp.y + 0.08, hp.z - 0.1]]
	var cg := _cl(k, {"keys": ck, "ny": 24, "na": 22, "rng": func(v): return Vector2(PI - 0.13 - 0.05 * float(v), PI + 0.13 + 0.05 * float(v)), "top": _cy(C + 0.045), "hem": func(a): return H - 0.21 - 0.02 * cos((float(a) - PI) * 12.0), "fold": func(a, _y, v): return float(v) * 0.03 * sin(float(a) * 16.0 + 0.5), "col": _cc(rd.darkened(0.14)), "inner": rd.darkened(0.45), "th": 0.005})
	_tr(k, cg["hem"], 0.0032, 0.0016, rd.darkened(0.3))
	# etek: kısa, kalça üstünde; önde sağdan sola verev binen ikinci kanat
	var sk := [_kp(bl, H + 0.035, 0.012), _kp(hp, H - 0.05, 0.022), [H - 0.27, hp.x + 0.05, hp.y + 0.05, hp.z - 0.05]]
	var sf := func(a: float, y: float, v: float) -> float: return v * v * (0.03 * sin(a * 6.0 + 0.5) + 0.012 * sin(a * 13.0 + 1.3)) + 0.003 * sin(a * 11.0 + y * 8.0)
	var hm := func(a: float) -> float: return H - 0.2 - 0.03 * sin(a - 0.9)
	var g := _cl(k, {"keys": sk, "ny": 18, "na": 100, "rng": func(_v): return Vector2(0.72, TAU + 0.34), "top": _cy(H + 0.03), "hem": hm, "fold": sf, "col": _cc(wh), "inner": wh.darkened(0.4), "th": 0.005, "gain": 7.0})
	_tr(k, g["eb"], 0.0034, 0.0018, wh.darkened(0.16))
	_tr(k, g["ea"], 0.0034, 0.0018, wh.darkened(0.16))
	var h1 := []
	for p in g["hem"]:
		h1.append(p + Vector3(0, 0.008, 0))
	_tr(k, h1, 0.0028, 0.0014, wh.darkened(0.2))
	var ov := [_kp(bl, H + 0.035, 0.027), _kp(hp, H - 0.05, 0.04), [H - 0.27, hp.x + 0.078, hp.y + 0.078, hp.z - 0.076]]
	var og := _cl(k, {"keys": ov, "ny": 16, "na": 40, "rng": func(v): return Vector2(-0.34 - 0.06 * float(v), 1.02 + 0.1 * float(v)), "top": _cy(H + 0.03), "hem": func(a): return H - 0.215 + 0.035 * (float(a) - 0.3), "fold": func(a, _y, v): return float(v) * 0.022 * sin(float(a) * 6.0 + 2.0), "col": _cc(wh.lightened(0.02)), "inner": wh.darkened(0.14), "th": 0.005, "gain": 7.0})
	_tr(k, og["ea"], 0.0036, 0.002, wh.darkened(0.14))
	_tr(k, og["hem"], 0.0036, 0.002, wh.darkened(0.14))
	_sash(k, ov, H + 0.022, 0.016, 0.0, wh.darkened(0.05), 0.08)


# ------------------------------------------------------------------ Nekomata (ref Yugito_Full): zeytin dik yakalı kısa kol üst, leylak ön panel ve bulut arması, kızıl büzgülü bel kuşağı, baldıra inen zeytin pantolon + sol uylukta bulut plakalar, sargılı önkol, boncuk dizisi, parmaksız eldiven, sargılı baldır
static func _nekomata(k) -> void:
	var ol := Color(0.3, 0.33, 0.22)
	var li := Color(0.63, 0.56, 0.72)
	var dp := Color(0.24, 0.2, 0.34)
	var rd := Color(0.56, 0.17, 0.27)
	var wh := Color(0.88, 0.87, 0.83)
	var pa := Color(0.78, 0.8, 0.76)
	var gl := Color(0.2, 0.19, 0.26)
	var be := Color(0.34, 0.56, 0.78)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	SE.body_layer(k, _tk(k, b, 0.004), 22, 40, func(_i, _j, _p): return ol.darkened(0.25))
	_pelvis(k, b, ol.darkened(0.2))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var ak: float = ar["kn"]
		_bare(k, ar, skc, 0.2, 0.62)
		_bare(k, le, skc, kn + 0.12, 1.0)
		# kısa kol: pazu ortasında biter
		var sf := func(s: float, a: float) -> float: return 0.0028 * _lf(s, a, 0.9) + 0.002 * sin(a * 3.0 + s * 18.0)
		_lt(k, ar, func(s, a): return 0.011 + float(sf.call(s, a)) + 0.006 * smoothstep(0.1, 0.34, s) - 0.012 * (1.0 - smoothstep(0.0, 0.1, s)), func(s, a, ins):
			return ol.darkened(0.42) if ins else _fs(ol, float(sf.call(s, a)), 24.0), 0.0, 0.34, 16, 20, 0.12)
		k.wrap_turn(_lp(ar, 0.325), _ld(ar, 0.325), _lr(ar, 0.325) + 0.0195, 0.0055, 0.0, ol.darkened(0.2), _lskin(ar, 0.325))
		# önkol sargısı: dirsekten bileğe tur tur
		_lt(k, ar, func(_s, _a): return 0.002, func(_s, _a, _i): return wh.darkened(0.22), ak, 0.93, 10, 14)
		_wraps(k, ar, ak + 0.01, 0.92, 15, 0.005, 0.0125, wh, 0.005)
		# parmaksız eldiven kolluğu
		_lts(k, ar, func(s, _a): return 0.0095 + 0.003 * smoothstep(0.93, 1.0, s), func(_s, _a, ins): return gl.darkened(0.4) if ins else gl, func(a): return 0.905 - 0.018 * cos(a), 0.995, 6, 18)
		# boncuk dizisi: önkola sarmal
		var nb := 20
		for i in nb:
			var t := float(i) / (nb - 1)
			var s: float = lerpf(ak + 0.07, 0.88, t)
			var e: Array = _lsurf(ar, s, t * TAU * 2.5 + 0.8, 0.0165)
			_stud(k, e[0], e[1], 0.0078, be if i % 5 else be.lightened(0.3), _lskin(ar, s))
		# pantolon: baldır ortasına, uyluk bol
		_pant(k, le, ol, 0.018, 1.1 if sd == "Left" else 2.7, 0.32, kn + 0.24)
		k.wrap_turn(_lp(le, kn + 0.235), _ld(le, kn + 0.235), _lr(le, kn + 0.235) + 0.0125, 0.0075, 0.002, ol.darkened(0.2), _lskin(le, kn + 0.235))
		# baldır sargısı
		_lt(k, le, func(_s, _a): return 0.003, func(_s, _a, _i): return wh.darkened(0.22), kn + 0.22, 1.0, 10, 16)
		_wraps(k, le, kn + 0.25, 0.985, 13, 0.006, 0.0145, wh, 0.007)
	# sol uyluk: üst üste binen bulut plakalar
	var ll := _limb(k, "Left", true)
	var kk: float = ll["kn"]
	for i in 5:
		var t := float(i) / 4.0
		var s0: float = lerpf(0.05, kk + 0.08, t) - 0.015
		_tongue(k, ll, s0, s0 + 0.13, 1.05, lerpf(0.66, 0.52, t), 0.034 + 0.003 * float(i), 0.012, pa.darkened(0.04 * float(i % 2)))
	# üst: dik yaka, omuzdan bele
	var tk := _tk(k, b, 0.013)
	var fo := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 7.0 + y * 13.0) * smoothstep(C - 0.05, H + 0.1, y) + 0.003 * sin(a * 4.0 - y * 20.0)
	_cl(k, {"keys": tk, "ny": 30, "na": 88, "top": _cy(N + 0.012), "hem": _cy(H + 0.02), "fold": fo, "col": _cc(ol), "skin": _torso(k), "th": 0.0, "gain": 9.0})
	# leylak ön panel: göğüsten bele, kenarı dikişli
	var pk := _tk(k, b, 0.019)
	var ptop := func(a: float) -> float: return C + 0.075 - 0.05 * pow(absf(a) / 0.78, 2.0)
	var pg := _cl(k, {"keys": pk, "ny": 22, "na": 44, "rng": func(_v): return Vector2(-0.78, 0.78), "top": ptop, "hem": _cy(H + 0.03), "fold": func(a, y, _v): return 0.004 * sin(float(a) * 9.0 + float(y) * 9.0), "col": _cc(li), "skin": _torso(k), "th": 0.004, "gain": 10.0})
	_bd(k, pg["top"], 0.0042, 0.0024, dp, false, _torso(k), 0.3)
	_bd(k, pg["ea"], 0.0042, 0.0024, dp, false, _torso(k))
	_bd(k, pg["eb"], 0.0042, 0.0024, dp, false, _torso(k))
	_line(k, pk, [Vector2(0.0, C + 0.06), Vector2(0.0, H + 0.05)], 0.0022, 0.003, 0.0016, li.darkened(0.3), 10)
	# bulut arması: üst üste beş dilim
	for e in [[0.0, C + 0.012, 0.037], [-0.27, C + 0.002, 0.03], [0.27, C + 0.002, 0.03], [-0.13, C - 0.028, 0.03], [0.13, C - 0.028, 0.03]]:
		var q: Array = _sa(pk, float(e[0]), float(e[1]), 0.004)
		_fan(k, q[0], q[1], Vector3.UP, float(e[2]), Callable(), func(u, v):
			var r: float = sqrt(float(u) * float(u) + float(v) * float(v))
			return pa.darkened(0.3) if r > 0.86 or absf(r - 0.56) < 0.05 else pa, [["UpperChest", 1.0]], 4, 22)
	# dik yaka: önde kapanır, koyu mor biye
	var ck := [_kp(nk, N + 0.1, 0.014), _kp(nk, N + 0.0, 0.024)]
	var cg := _cl(k, {"keys": ck, "ny": 7, "na": 48, "top": func(a): return N + 0.092 - 0.012 * exp(-pow(float(a) / 0.3, 2.0)), "hem": _cy(N + 0.002), "fold": func(a, _y, _v): return 0.012 * sin(float(a) * 5.0 + 1.0), "col": _cc(ol), "skin": _torso(k), "th": 0.005})
	_bd(k, cg["top"], 0.0036, 0.0024, dp, true, _torso(k), 0.5)
	_line(k, tk, [Vector2(0.0, N + 0.01), Vector2(0.0, C + 0.076)], 0.0026, 0.004, 0.0018, ol.darkened(0.4), 5)
	# kızıl kuşak: kalçaya inen büzgülü bez, solda düğüm ve kısa uç
	var sk := [_kp(b["wa"], H + 0.11, 0.03), _kp(bl, H + 0.04, 0.03), _kp(hp, H - 0.05, 0.04), [H - 0.1, hp.x + 0.042, hp.y + 0.042, hp.z - 0.044]]
	var gat := func(a: float, y: float, _v: float) -> float: return 0.02 * sin(a * 3.0 + y * 34.0 + 0.5) + 0.012 * sin(y * 92.0 + a * 2.0)
	_cl(k, {"keys": sk, "ny": 14, "na": 84, "top": func(a): return H + 0.085 - 0.02 * cos(a), "hem": func(a): return H - 0.015 - 0.05 * pow(0.5 + 0.5 * cos(a), 2.0), "fold": gat, "col": _cc(rd), "inner": rd.darkened(0.4), "th": 0.005, "gain": 8.0, "skin": _torso(k)})
	var kq: Array = _sa(sk, 0.62, H + 0.035, 0.018)
	var kc: Vector3 = kq[0]
	var ko: Vector3 = kq[1]
	var kx := Vector3(ko.z, 0.0, -ko.x).normalized()
	_boxr(k, kc + kx * 0.03 + Vector3(0, 0.002, 0), kx * 0.032, Vector3(0, 0.026, 0), ko * 0.016, rd.darkened(0.1), [["Hips", 0.7], ["Spine", 0.3]], 0.42)
	_boxr(k, kc - kx * 0.024 + Vector3(0, -0.004, 0), kx * 0.03, Vector3(0, 0.023, 0), ko * 0.014, rd.darkened(0.16), [["Hips", 0.7], ["Spine", 0.3]], 0.42)
	_boxr(k, kc + ko * 0.009, kx * 0.019, Vector3(0, 0.03, 0), ko * 0.016, rd.lightened(0.05), [["Hips", 0.7], ["Spine", 0.3]], 0.42)
	_cur_hem = H - 0.28
	_wb(k, sk, [Vector2(0.72, H), Vector2(0.8, H - 0.09)], 0.034, 0.03, rd.darkened(0.06), 4, 6)


# ------------------------------------------------------------------ Genso (ref Kurenai_full): çapraz sarılı krem bez elbise, koyu çentikli dikiş çizgileri, kırmızı tek kol ve yaka, file göğüs, omuz sargısı, sargılı önkol ve uyluk, açık bacak
static func _genso(k) -> void:
	var wh := Color(0.87, 0.85, 0.79)
	var ln := Color(0.25, 0.23, 0.27)
	var rd := Color(0.45, 0.12, 0.16)
	var ba := Color(0.93, 0.92, 0.89)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var sk_k := _skin_body(k, b, skc, H - 0.02)
	_pelvis(k, b, ba.darkened(0.12))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var sg: float = ar["sg"]
		_bare(k, le, skc)
		_bare(k, ar, skc)
		# uyluk sargısı
		_lt(k, le, func(_s, _a): return 0.003, func(_s, _a, _i): return ba.darkened(0.2), 0.0, 0.3, 8, 18)
		_wraps(k, le, 0.03, 0.285, 11, 0.008, 0.0145, ba, 0.008)
		# önkol sargısı: elin üstüne kadar
		_lt(k, ar, func(_s, _a): return 0.002, func(_s, _a, _i): return ba.darkened(0.2), 0.5, 0.985, 10, 14)
		_wraps(k, ar, 0.52, 0.975, 15, 0.005, 0.0125, ba, 0.006)
		if sd == "Right":
			# kırmızı tek kol: dirseğe bol iner
			var ak: float = ar["kn"]
			var sf := func(s: float, a: float) -> float: return 0.004 * _lf(s, a, 1.3) * (0.5 + s) + 0.004 * sin(a * 4.0 + s * 12.0) * smoothstep(0.2, 0.5, s)
			_lt(k, ar, func(s, a): return 0.012 + 0.034 * smoothstep(0.14, 0.6, s) + float(sf.call(s, a)) - 0.012 * (1.0 - smoothstep(0.0, 0.1, s)), func(s, a, ins):
				return rd.darkened(0.45) if ins else _fs(rd, float(sf.call(s, a)), 22.0), 0.0, ak + 0.09, 24, 22, 0.2)
		else:
			# sol kol: pazu da sargılı
			_lt(k, ar, func(_s, _a): return 0.002, func(_s, _a, _i): return ba.darkened(0.2), 0.14, 0.52, 8, 14)
			_wraps(k, ar, 0.18, 0.52, 11, 0.005, 0.0135, ba, 0.006)
		# omuz sargısı: omuzu saran geniş kat, dış kenarı aşağı iner
		_lts(k, ar, func(s, a): return 0.021 + 0.004 * sin(a * 3.0 + s * 18.0) - 0.014 * (1.0 - smoothstep(0.0, 0.1, s)) + 0.006 * smoothstep(0.14, 0.3, s) * maxf(0.0, sin(a) * sg), func(_s, _a, ins):
			return wh.darkened(0.42) if ins else wh.darkened(0.02), func(_a): return 0.0, 0.3, 12, 24)
		for i in 2:
			var s1: float = 0.17 + float(i) * 0.085
			var pts := []
			var ou := []
			for j in 13:
				var a: float = TAU * j / 12.0
				var e: Array = _lsurf(ar, s1 + 0.02 * sin(a + 0.7), a, 0.0265 + 0.0015 * float(i))
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, 0.0024, 0.0016, ln, false, func(_p): return _lskin(ar, s1))
	# file göğüs: V içinde
	var dk_top := func(a: float) -> float:
		var d: float = absf(wrapf(a, -PI, PI))
		return lerpf(C + 0.055, N + 0.01, smoothstep(0.08, 0.72, d)) if d < 2.0 else N + 0.01
	_net_patch(k, sk_k, func(a, y): return float(y) > float(dk_top.call(float(a))) - 0.006 and float(y) < N + 0.008, -0.74, 0.74, C + 0.05, N + 0.008, 0.019, 0.0016, 0.004, Color(0.2, 0.18, 0.2))
	# elbise: tek parça sargı; bel üstünde katlar bir yöne, bel altında öbür yöne iner, her kat alttakinin üstüne biner
	var keys := _tk(k, b, 0.014)
	var low := [_kp(bl, H + 0.04, 0.014), _kp(hp, H - 0.05, 0.02), [H - 0.33, hp.x + 0.05, hp.y + 0.046, hp.z - 0.046]]
	keys = keys.slice(0, 5) + low
	var y_t: float = N + 0.008
	var yw: float = H + 0.085
	var sp := 0.074
	var sl := 0.1
	var tri := func(a: float) -> float:
		var aw: float = wrapf(a, -PI, PI)
		return aw if absf(aw) <= PI * 0.5 else (PI - aw if aw > 0.0 else -PI - aw)
	var fr := func(a: float, y: float) -> float:
		var t: float = float(tri.call(a))
		var w: float = (y + sl * t) / sp if y > yw else (y - sl * t) / sp
		return w - floor(w)
	var hemf := func(a: float) -> float:
		var d: float = absf(wrapf(a, -PI, PI))
		var q: float = float(tri.call(a)) * sl / sp
		var t: float = q - floor(q)
		return H - 0.262 + 0.045 * exp(-pow(d / 0.3, 2.0)) + 0.03 * (t / 0.78 if t < 0.78 else (1.0 - t) / 0.22)
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = float(fr.call(a, y))
		var r: float = (t / 0.3 if t < 0.3 else (1.0 - t) / 0.7)
		return 0.036 * smoothstep(0.0, 1.0, r) * smoothstep(0.0, 0.04, absf(y - yw)) + 0.004 * sin(a * 5.0 + y * 9.0)
	_cl(k, {"keys": keys, "ny": 70, "na": 132, "top": dk_top, "hem": hemf, "fold": fold, "col": func(a, y, _v): return wh.darkened(0.13 * smoothstep(0.5, 1.0, float(fr.call(a, y)))), "inner": wh.darkened(0.42), "th": 0.005, "gain": 0.0})
	_cur_hem = H - 0.33
	var inside := func(a: float, y: float) -> bool:
		var aw: float = wrapf(a, -PI, PI)
		return y > float(hemf.call(aw)) + 0.01 and y < float(dk_top.call(aw)) - 0.008 and absf(y - yw) > 0.022
	# koyu dikişler: her iki katta bir, üzerinde basamaklı çentik
	for side: float in [0.0, PI]:
		var n0: int = int(floor((H - 0.34) / sp))
		var n1: int = int(ceil((N + 0.1) / sp))
		for n in range(n0, n1 + 1):
			if n % 2 != 0:
				continue
			for zn: float in [1.0, -1.0]:
				var y_of := func(a: float) -> float: return float(n) * sp - zn * sl * float(tri.call(a))
				var ins2 := func(a: float, y: float) -> bool: return bool(inside.call(a, y)) and (y > yw) == (zn > 0.0)
				var a0: float = side - 1.5
				var a1: float = side + 1.5
				var p0 := Vector2(a0, float(y_of.call(a0)))
				var p1 := Vector2(a1, float(y_of.call(a1)))
				_lc(k, keys, p0, p1, ins2, 0.0026, 0.0085, 0.0016, ln, 26)
				var nt: float = 0.28 + 0.07 * float(posmod(n, 4))
				_lc(k, keys, p0.lerp(p1, nt), p0.lerp(p1, nt + 0.08), ins2, 0.0066, 0.0085, 0.002, ln, 4)
	# kırmızı yaka: V boyunca biye; bel bandı
	var pth := []
	for i in range(0, 13):
		var a: float = lerpf(-0.9, 0.9, float(i) / 12.0)
		pth.append(Vector2(a, float(dk_top.call(a)) - 0.002))
	_band(k, keys, pth, func(_t): return 0.022, 0.009, rd, 2, 5, 0.1, 0.14)
	var back_pts := []
	for i in 13:
		back_pts.append(Vector2(lerpf(0.9, TAU - 0.9, float(i) / 12.0), y_t - 0.002))
	_band(k, keys, back_pts, func(_t): return 0.018, 0.008, rd, 2, 4, 0.1, 0.14)
	var wb := _tk(k, b, 0.031)
	_sash(k, wb, H + 0.085, 0.017, 0.0, rd, 0.1)
