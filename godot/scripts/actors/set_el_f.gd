extends RefCounted
## Elle modellenmiş setler, parti f: set_tetsu_sho, set_taka_kunoichi, set_taka_kenshi, set_nidaime_koromo, set_uzushio_hime, set_kumo_kyodai. Örnek: set_el.gd içindeki _shugonin.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_tetsu_sho", "set_taka_kunoichi", "set_taka_kenshi", "set_nidaime_koromo", "set_uzushio_hime", "set_kumo_kyodai"]


static func recipe(k, sid: String) -> void:
	_cur_long = false
	_cur_rear = false
	_cur_leg = 0.58
	match sid:
		"set_tetsu_sho": _tetsu_sho(k)
		"set_taka_kunoichi": _taka_kunoichi(k)
		"set_taka_kenshi": _taka_kenshi(k)
		"set_nidaime_koromo": _nidaime_koromo(k)
		"set_uzushio_hime": _uzushio_hime(k)
		"set_kumo_kyodai": _kumo_kyodai(k)


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
static var _kb_gain := 0.95
static var _cur_rear := false   # uzun cübbe / etek: arka yüz Akatsuki paltosu gibi yavaş ağırlık (yalnız açıkça isteyen setler)


static func _hs(k, p: Vector3) -> Array:
	if _cur_rear:
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
	var sk: float = smoothstep(-0.09, 0.09, p.x)
	var kb: float = smoothstep(k.K + 0.2, k.K - 0.04, p.y) * smoothstep(0.2, -0.02, p.z) * _kb_gain * absf(2.0 * sk - 1.0)   # geri savrulan baldır arka eteği yumuşakça iter
	var sd: String = "Left" if sk >= 0.5 else "Right"
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * (1.0 - kb)], [sd + "LowerLeg", w * kb]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Uzun cübbe / etek ağırlığı. Ön: uyluğu çabuk izler (kalkan diz kumaşı delmez). Arka: ağırlık boy boyunca yavaş artar, iki bacak arasında geniş geçer,
## baldıra yalnız az geçer: geri giden bacak arka eteği kalçaya doğru ezmez / yataya kaldırmaz, kumaş uzayarak iner; uçta ağırlık biraz düşer
static func _robe_skin(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.04, -0.07, p.z)
	var kt: float = clampf((H - k.K) / maxf(0.05, H - hem), 0.2, 1.0)
	var wf: float = 0.97 * pow(minf(1.0, t / (kt * 0.7)), 0.4) * lerpf(1.0, 0.9, smoothstep(kt, 1.0, t))
	var wb: float = 0.84 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.07, 0.12, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.03, k.K - 0.18, p.y) * bk * absf(2.0 * s - 1.0) * 0.45
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
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



# ------------------------------------------------------------------ parti f yardımcıları
## Uzuv kesit çerçevesi: [merkez, yön, ön, sağ eksen]
static func _fr(l: Dictionary, s: float) -> Array:
	var d := _ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	return [_lp(l, s), d, fw, (-d).cross(fw).normalized()]


## Kruvaze üst: e1 üste binen (karakterin sol) kanat kenarı, e2 alttaki kanat kenarı. o: keys, yt, yb, yc, e0, a1, a2, col, fold, gain, ny, na
static func _wrap_top(k, o: Dictionary) -> Dictionary:
	var yt: float = o["yt"]
	var yb: float = o["yb"]
	var yc: float = o["yc"]
	var e0: float = o.get("e0", 0.56)
	var a1: float = o.get("a1", -0.3)
	var a2: float = o.get("a2", -0.05)
	var pw: float = o.get("pw", 0.9)
	var e1 := func(y: float) -> float: return lerpf(a1, e0, pow(clampf((y - yc) / (yt - yc), 0.0, 1.0), pw))
	var e2 := func(y: float) -> float: return lerpf(a2, e0, pow(clampf((y - yc) / (yt - yc), 0.0, 1.0), pw))
	var d := {"keys": o["keys"], "ny": o.get("ny", 30), "na": o.get("na", 84), "rng": func(v):
		var y: float = lerpf(yt, yb, float(v))
		return Vector2(float(e1.call(y)), TAU - float(e2.call(y))), "top": func(_a): return yt, "hem": func(_a): return yb, "col": o["col"], "skin": func(p): return k.torso_skin(p.y), "gain": o.get("gain", 7.0), "th": o.get("th", 0.005)}
	if o.has("fold"):
		d["fold"] = o["fold"]
	var g := _cl(k, d)
	return {"e1": e1, "e2": e2, "rows": g["rows"]}


## Kat yaka yolu: üstteki kanat kenarından ense üzerinden alttaki kanada
static func _collar_path(w: Dictionary, yt: float, y1: float, y2: float, e0 := 0.56, up := 0.004) -> Array:
	var e1: Callable = w["e1"]
	var e2: Callable = w["e2"]
	var pth := []
	for i in 10:
		var y: float = lerpf(y1, yt, float(i) / 9.0)
		pth.append(Vector2(float(e1.call(y)), y))
	for i in range(1, 10):
		pth.append(Vector2(lerpf(e0, TAU - e0, float(i) / 10.0), yt + up))
	for i in range(9, -1, -1):
		var y: float = lerpf(y2, yt, float(i) / 9.0)
		pth.append(Vector2(TAU - float(e2.call(y)), y))
	return pth


## Geniş kol: üst kol tende / astarda kalır, ağız sarkar. o: col, in, s1, add, wide, sag, seed, gain
static func _wide_sleeve(k, ar: Dictionary, o: Dictionary) -> void:
	var col: Color = o["col"]
	var inn: Color = o.get("in", col.darkened(0.4))
	var s1: float = o.get("s1", 0.8)
	var add: float = o.get("add", 0.014)
	var wide: float = o.get("wide", 0.04)
	var sag: float = o.get("sag", 0.05)
	var sv: float = o.get("seed", 1.0)
	var sx: float = ar["sg"]
	var base := func(s: float, a: float) -> float:
		return add + wide * smoothstep(0.2, s1 * 0.85, s) + sag * smoothstep(0.26, s1 * 0.92, s) * maxf(0.0, -sin(a) * sx) - 0.022 * (1.0 - smoothstep(0.0, 0.13, s))
	var ff := func(s: float, a: float) -> float: return (0.0035 + 0.009 * s) * sin(a * 5.0 + s * 9.0 + sv) + 0.003 * sin(a * 9.0 - s * 13.0 + sv)
	_lt(k, ar, func(s, a): return float(base.call(float(s), float(a))) + float(ff.call(float(s), float(a))), func(s, a, ins):
		return inn if ins else _fs(col, float(ff.call(float(s), float(a))), 20.0), 0.0, s1, 28, 28, s1 * 0.55)
	if o.has("stripe"):
		var n: int = o.get("stripes", 12)
		for h in n:
			var a := TAU * (float(h) + 0.5) / n - PI
			var pts := []
			var ou := []
			var ss := []
			for j in 19:
				var s := lerpf(0.03, s1 - 0.006, float(j) / 18.0)
				var f: Array = _fr(ar, s)
				var q: Vector3 = (f[3] as Vector3) * sin(a) + (f[2] as Vector3) * cos(a)
				pts.append((f[0] as Vector3) + q * (_lr(ar, s) + float(base.call(s, a)) + float(ff.call(s, a)) + 0.0016))
				ou.append(q)
				ss.append(s)
			k.strip(pts, ou, 0.0017, 0.001, o["stripe"], false, func(p): return _lskin(ar, _ls_at(ar, p)))
	if o.has("hem"):
		var hw: float = o.get("hem_w", 0.022)
		_lt(k, ar, func(s, a): return float(base.call(float(s), float(a))) + float(ff.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return (o["hem"] as Color).darkened(0.3) if ins else o["hem"], s1 - hw * 2.0, s1 - 0.002, 2, 28)


## Bir yüzeye oturan sivri / düz uçlu bez şeridi. ctr: Vector2(x, y) yolu, wf(t) yarı genişlik
static func _ribbon(k, keys: Array, ctr: Array, wf: Callable, front: bool, lift: float, col: Color, foldc := 0.1) -> void:
	var rows := []
	var n := ctr.size()
	for j in n:
		var t := float(j) / (n - 1)
		var w: float = wf.call(t)
		var ro := []
		for i in 5:
			var u := float(i) / 4.0
			var x: float = (ctr[j] as Vector2).x + lerpf(-w, w, u)
			var bump := sin(u * PI) * 0.004 + 0.0015 * sin(t * 13.0 + u * 5.0)
			ro.append(_fp(keys, x, (ctr[j] as Vector2).y, front, lift + bump)[0])
		rows.append(ro)
	var a0: Vector3 = rows[0][0]
	var fn: Vector3 = -((rows[0][1] as Vector3) - a0).cross((rows[1][1] as Vector3) - a0)
	if fn.z * (1.0 if front else -1.0) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(i, j, _p): return col.darkened(foldc * 1.6) if i == 0 or i == 4 else (col.darkened(foldc) if (i + j) % 7 == 0 else col), func(_i, _j, p): return _hs(k, p))


## Noktanın uzuv boyundaki yeri
static func _ls_at(l: Dictionary, p: Vector3) -> float:
	var p0: Vector3 = l["p0"]
	var p1: Vector3 = l["p1"]
	var p2: Vector3 = l["p2"]
	var kn: float = l["kn"]
	var t0 := clampf((p - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
	var t1 := clampf((p - p1).dot(p2 - p1) / (p2 - p1).length_squared(), 0.0, 1.0)
	if (p - p0.lerp(p1, t0)).length() < (p - p1.lerp(p2, t1)).length():
		return t0 * kn
	return lerpf(kn, 1.0, t1)


## Kumaş satırlarının sütunları boyunca ince dokuma çizgisi (kıvrımı izler)
static func _stripes(k, rows: Array, step: int, hw: float, col: Color, skinf := Callable(), lift := 0.0016) -> void:
	var nc: int = (rows[0] as Array).size()
	var i := step / 2
	while i < nc - 1:
		var pts := []
		var ou := []
		var j := 0
		while j < rows.size():
			var p: Vector3 = rows[j][i]
			var o := _out(p)
			pts.append(p + o * lift)
			ou.append(o)
			j += 2 if j + 2 < rows.size() or j == rows.size() - 1 else 1
		k.strip(pts, ou, hw, 0.001, col, false, skinf if skinf.is_valid() else func(q): return _hs(k, q))
		i += step


# ------------------------------------------------------------------ Tetsu Shōgun (ref Mifune_full): siyah iç, beyaz alt yaka, gri kimono ve bol hakama, beyaz bel bağı + önde düğüm, koyu yeşil kırmızı biyeli lameli sode ve kusazuri, kırmızı bağcıklar, beyaz kolluk ve tozluk
## Kat kat lamel: yüzeyde a0..a1 yayı; her lamel altı dışa kalkık, kırmızı bağcıklı
static func _kz_panel(k, keys: Array, a0: float, a1: float, y0: float, nl: int, lh: float, lift: float, gn: Color, rd: Color, skinf: Callable) -> void:
	var nu := 18
	for l in nl:
		var yt := y0 - float(l) * lh * 0.8
		var off := lift + float(l) * 0.0065
		var outer := []
		for j in 7:
			var v := float(j) / 6.0
			var y := yt - lh * v
			var ro := []
			for i in nu + 1:
				var u := float(i) / nu
				var sq := 0.012 * float(l)   # alt lameller biraz daha geniş
				var e: Array = _sa(keys, lerpf(a0 - sq, a1 + sq, u), y, 0.0)
				var ed := minf(u, 1.0 - u)
				ro.append((e[0] as Vector3) + (e[1] as Vector3) * (off + 0.013 * v * v - 0.004 * (1.0 - smoothstep(0.0, 0.05, ed))))
			outer.append(ro)
		var rows: Array = outer.duplicate()
		var src := []
		for j in 7:
			src.append(j)
		var low := []
		for p: Vector3 in outer[6]:
			low.append(p + Vector3(0, -0.003, 0) - Vector3(p.x, 0, p.z).normalized() * 0.004)
		rows.append(low)
		src.append(6)
		for j2 in range(6, -1, -1):
			var inn := []
			for p: Vector3 in outer[j2]:
				inn.append(p - Vector3(p.x, 0, p.z).normalized() * 0.007)
			rows.append(inn)
			src.append(j2)
		var last := l == nl - 1
		k.grid(rows, false, func(i, j, _p):
			var sj: int = src[j]
			var v := float(sj) / 6.0
			var c0: Color = gn.lightened(0.06 * v).darkened(0.2 * (1.0 - smoothstep(0.0, 0.4, v)))
			if last and v > 0.72:
				c0 = rd
			if i == 0 or i == nu:
				c0 = c0.darkened(0.16)
			return c0 if j <= 6 else c0.darkened(0.4), func(_i, _j, p): return skinf.call(p))
		if l < nl - 1:   # lameli bir alttakine bağlayan bağcık çiftleri
			for u0 in [0.24, 0.76]:
				var a := lerpf(a0, a1, float(u0))
				for da in [-0.022, 0.022]:
					var pts := []
					for j in 4:
						var y := yt - lh * lerpf(0.66, 1.2, float(j) / 3.0)
						var e: Array = _sa(keys, a + da, y, 0.0)
						pts.append((e[0] as Vector3) + (e[1] as Vector3) * (off + 0.016))
					_cord(k, pts, 0.0042, rd, false, skinf, 0.0, 6)


## Sode: omuzdan sarkan yassı, hafif kavisli lamel yığını
static func _sode(k, ar: Dictionary, gn: Color, rd: Color) -> void:
	var sd: String = ar["sd"]
	var sx: float = ar["sg"]
	var nl := 4
	var skf := func(t: float) -> Array:
		var w := (1.0 - smoothstep(0.0, 0.3, t)) * 0.45
		return [[sd + "UpperArm", 1.0 - w], ["UpperChest", w]]
	for l in nl:
		var s0 := 0.06 + float(l) * 0.115
		var s1 := s0 + 0.15
		var outer := []
		var ts := []
		var nu := 20
		for j in 7:
			var v := float(j) / 6.0
			var s := lerpf(s0, s1, v)
			var f: Array = _fr(ar, s)
			var W := 0.098 + float(l) * 0.0085 + 0.008 * v
			var R := 0.098 + float(l) * 0.0085 + 0.016 * v * v
			var ro := []
			for i in nu + 1:
				var u := float(i) / nu
				var th := lerpf(-1.02, 1.02, u)
				var ed := minf(u, 1.0 - u)
				var rr := R - 0.004 * (1.0 - smoothstep(0.0, 0.05, ed))
				ro.append((f[0] as Vector3) + (f[3] as Vector3) * (sx * cos(th) * rr) + (f[2] as Vector3) * (sin(th) * W * 1.3))
			outer.append(ro)
			ts.append(float(l) / nl + v / nl)
		var rows: Array = outer.duplicate()
		var src := [0, 1, 2, 3, 4, 5, 6]
		var ct := _lp(ar, s1)
		var low := []
		for p: Vector3 in outer[6]:
			low.append(p + (p - ct).normalized() * -0.006)
		rows.append(low)
		src.append(6)
		var ct2 := _lp(ar, lerpf(s0, s1, 0.4))
		for j2 in range(6, -1, -1):
			var inn := []
			for p: Vector3 in outer[j2]:
				inn.append(p + (p - ct2).normalized() * -0.007)
			rows.append(inn)
			src.append(j2)
		var a0: Vector3 = rows[0][0]
		var fn: Vector3 = -((rows[0][1] as Vector3) - a0).cross((rows[1][1] as Vector3) - a0)
		if fn.dot(a0 + ((rows[0][1] as Vector3) - a0) * 0.5 - _lp(ar, s0)) < 0.0:
			for ro in rows:
				ro.reverse()
		var last := l == nl - 1
		k.grid(rows, false, func(i, j, _p):
			var v := float(src[j]) / 6.0
			var c0: Color = gn.lightened(0.07 * v).darkened(0.2 * (1.0 - smoothstep(0.0, 0.4, v)))
			if last and v > 0.72:
				c0 = rd
			if i == 0 or i == nu:
				c0 = c0.darkened(0.14)
			return c0 if j <= 6 else c0.darkened(0.42), func(_i, j, _p): return skf.call(ts[mini(int(src[j]), 6)]))
		if l < nl - 1:
			for th in [-0.6, 0.6]:
				for dt in [-0.035, 0.035]:
					var pts := []
					for j in 4:
						var s := lerpf(s0 + 0.09, s0 + 0.19, float(j) / 3.0)
						var f: Array = _fr(ar, s)
						var t2: float = float(th) + float(dt)
						var R2 := 0.113 + float(l) * 0.0085
						pts.append((f[0] as Vector3) + (f[3] as Vector3) * (sx * cos(t2) * R2) + (f[2] as Vector3) * (sin(t2) * (0.128 + float(l) * 0.011)))
					_tb(k, pts, func(_s, _a): return 0.0042, func(_s, a, _p): return rd.darkened(0.2) if cos(float(a)) < 0.0 else rd, func(_s, _p): return skf.call(float(l + 1) / nl), 6)
	# omuz başlığı: plakayı omuza bağlayan kavisli üst parça
	var rows2 := []
	for j in 6:
		var v := float(j) / 5.0
		var s := lerpf(0.0, 0.1, v)
		var f: Array = _fr(ar, s)
		var ro := []
		for i in 21:
			var th := lerpf(-1.08, 1.08, float(i) / 20.0)
			var R3 := lerpf(0.07, 0.105, smoothstep(0.0, 1.0, v))
			ro.append((f[0] as Vector3) + (f[3] as Vector3) * (sx * cos(th) * R3) + (f[2] as Vector3) * (sin(th) * lerpf(0.104, 0.128, v)))
		rows2.append(ro)
	var b0: Vector3 = rows2[1][0]
	var fn2: Vector3 = -((rows2[1][1] as Vector3) - b0).cross((rows2[2][1] as Vector3) - b0)
	if fn2.dot(b0 - _lp(ar, 0.03)) < 0.0:
		for ro in rows2:
			ro.reverse()
	k.grid(rows2, false, func(_i, j, _p): return gn.darkened(0.12) if j < 5 else rd, func(_i, j, _p): return skf.call(float(j) * 0.02))


static func _tetsu_sho(k) -> void:
	var gr := Color(0.41, 0.43, 0.42)
	var bk := Color(0.09, 0.095, 0.11)
	var wh := Color(0.9, 0.89, 0.84)
	var gn := Color(0.12, 0.21, 0.165)
	var rd := Color(0.5, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.06, 0.3)
	var yo: float = H + 0.075
	_inner(k, b, func(_i, _j, _p): return bk)
	# beyaz alt kimono: V kenarında ince şerit olarak görünür
	var jk := [_kp(nk, N + 0.012, 0.024), [N - 0.05, ch.x * 0.96, ch.y * 0.88, ch.z * 1.0], _kp(ch, C - 0.03, 0.024), _kp(wa, H + 0.12, 0.03)]
	var yt: float = N + 0.016
	var yc: float = C - 0.2
	_wrap_top(k, {"keys": jk, "yt": yt - 0.004, "yb": H + 0.12, "yc": yc, "e0": 0.46, "a1": -0.42, "a2": -0.2, "col": func(_a, _y, _v): return wh, "ny": 16, "na": 60, "th": 0.0})
	# gri kimono üstü
	var keys := [_kp(nk, N + 0.018, 0.036), [N - 0.05, ch.x * 1.03, ch.y * 0.93, ch.z * 1.07], _kp(ch, C - 0.03, 0.04), _kp(wa, H + 0.13, 0.054), _kp(bl, yo - 0.03, 0.03)]
	var uf := func(a: float, y: float, _v: float) -> float:
		var nr: float = smoothstep(C - 0.12, yo, y)
		return (nr * (0.03 * sin(a * 9.0 + 0.7) + 0.013 * sin(a * 15.0 + 2.0)) + 0.007 * sin(a * 3.0 + y * 9.0)) * smoothstep(yo + 0.03, yo + 0.09, y)
	var w := _wrap_top(k, {"keys": keys, "yt": yt, "yb": yo - 0.03, "yc": yc, "e0": 0.56, "a1": -0.26, "a2": -0.02, "col": func(_a, _y, _v): return gr, "fold": uf})
	_band(k, keys, _collar_path(w, yt, yo, lerpf(yc, yt, 0.2)), func(_t): return 0.03, 0.006, gr.darkened(0.14), 3, 6, 0.06, 0.12)
	# hakama: bel altından kalçayı saran bol üst
	var hk := [_kp(bl, yo, 0.034), _kp(hp, H - 0.04, 0.045), [H - 0.19, hp.x + 0.052, hp.y + 0.05, hp.z - 0.05]]
	var hf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((yo - y) / (yo - (H - 0.19)), 0.0, 1.0)
		return (0.016 + 0.03 * t) * sin(a * 8.0 + 0.9) * smoothstep(0.0, 0.4, t) + 0.012 * t * sin(a * 13.0 + 2.0)
	_cl(k, {"keys": hk, "ny": 16, "na": 72, "top": func(_a): return yo, "hem": func(_a): return H - 0.19, "fold": hf, "col": func(_a, _y, _v): return gr.darkened(0.03), "gain": 6.5, "th": 0.005})
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var se: float = kn + 0.3
		# bol hakama bacağı: dizde şişer, baldır üstünde büzülür
		var pa := func(s: float, a: float) -> float:
			var bag := 0.02 + 0.043 * exp(-pow((s - kn * 0.92) / 0.24, 2.0)) - 0.008 * smoothstep(se - 0.14, se, s)
			var fl: float = 0.008 + 0.0062 * smoothstep(0.0, kn, s)
			var pl := sin(a * 4.0 + s * 8.0 + 1.0) + 0.55 * sin(a * 7.0 - s * 15.0)
			var gather := smoothstep(se - 0.12, se - 0.01, s) * 0.006 * sin(a * 11.0)
			return bag + fl * pl * (1.0 - 0.8 * smoothstep(se - 0.1, se, s)) + gather * 0.4
		_lt(k, le, pa, func(s, a, ins):
			if ins:
				return gr.darkened(0.45)
			var pl := sin(float(a) * 4.0 + float(s) * 8.0 + 1.0) + 0.55 * sin(float(a) * 7.0 - float(s) * 15.0)
			return _fs(gr.darkened(0.03), pl * 0.012, 11.0), 0.0, se, 44, 28, 0.08)
		# beyaz tozluk ve siyah bilek bağı
		_lt(k, le, func(_s, _a): return 0.003, func(_s, a, ins): return wh.darkened(0.4) if ins else wh.darkened(0.05 + 0.05 * maxf(0.0, sin(float(a) * 3.0))), se - 0.07, 1.0, 12, 18)
		_lt(k, le, func(_s, _a): return 0.012, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.06), 0.925, 0.985, 3, 18)
		k.wrap_turn(_lp(le, se - 0.006), _ld(le, se), _lr(le, se) + 0.006, 0.01, 0.0, gr.darkened(0.3), _lskin(le, se))
		# kol: beyaz dar kolluk, üstüne gri geniş kısa yen, siyah bilek eldiveni
		_lt(k, ar, func(s, a): return 0.006 + 0.0028 * _lf(float(s), float(a), 1.5), func(_s, _a, ins): return wh.darkened(0.35) if ins else wh.darkened(0.04), 0.42, 0.98, 18, 16)
		_lt(k, ar, func(_s, _a): return 0.011, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05), 0.885, 0.985, 4, 16)
		_wide_sleeve(k, ar, {"col": gr, "s1": 0.66, "add": 0.016, "wide": 0.03, "sag": 0.04, "seed": 1.2 if sd == "Left" else 2.6})
	# kusazuri: ön, iki yan, arka
	var kk := [_kp(bl, yo - 0.015, 0.05), _kp(hp, H - 0.04, 0.075), [H - 0.32, hp.x + 0.115, hp.y + 0.095, hp.z - 0.1]]
	var y0: float = yo - 0.028
	var mk := func(sw: float, leg: float) -> Callable:
		return func(p: Vector3) -> Array:
			var t: float = clampf((yo - p.y) / 0.3, 0.0, 1.0)
			var wl := t * leg
			if sw == 0.0:
				var x: float = smoothstep(-0.07, 0.07, p.x)
				return [["Hips", 1.0 - wl], ["LeftUpperLeg", wl * x], ["RightUpperLeg", wl * (1.0 - x)]]
			return [["Hips", 1.0 - wl], ["LeftUpperLeg" if sw > 0.0 else "RightUpperLeg", wl]]
	_kz_panel(k, kk, -0.56, 0.56, y0, 4, 0.098, 0.004, gn, rd, mk.call(0.0, 0.34))
	_kz_panel(k, kk, PI - 0.62, PI + 0.62, y0, 4, 0.098, 0.004, gn, rd, mk.call(0.0, 0.34))
	for sg in [1.0, -1.0]:
		_kz_panel(k, kk, sg * 0.98 - 0.56, sg * 0.98 + 0.56, y0 - 0.006, 4, 0.098, 0.012, gn, rd, mk.call(sg, 0.62))
		_kz_panel(k, kk, sg * 2.16 - 0.5, sg * 2.16 + 0.5, y0 - 0.006, 4, 0.098, 0.012, gn, rd, mk.call(sg, 0.62))
	# bel bağı: beyaz, katlı; önde düğüm ve kusazuri üstüne oturan iki uç
	var ok := [_kp(bl, H + 0.17, 0.056), _kp(bl, H + 0.0, 0.062)]
	_sash(k, ok, yo, 0.031, 0.008, wh, 0.14)
	_sash(k, ok, yo + 0.014, 0.012, 0.014, wh.lightened(0.04), 0.06)
	var zf: float = _fp(ok, 0.03, yo, true, 0.0)[0].z + 0.018
	k.tube([Vector3(-0.012, yo + 0.018, zf), Vector3(0.05, yo - 0.016, zf)], ["Hips"], [[0.0, 0.015], [0.5, 0.025], [1.0, 0.015]], func(_t, a, _i): return wh.darkened(0.14 if sin(float(a) * 3.0) < -0.2 else 0.0), 8, 12, false)
	_cur_hem = H - 0.32
	for e in [[0.024, 0.008, 0.2, 0.03], [0.044, 0.04, 0.15, 0.024]]:
		var ctr := []
		for j in 11:
			var t := float(j) / 10.0
			ctr.append(Vector2(float(e[0]) + float(e[1]) * t, yo - 0.022 - float(e[2]) * t))
		var ew: float = e[3]
		_ribbon(k, kk, ctr, func(t): return ew * (0.72 + 0.28 * smoothstep(0.0, 0.2, float(t))) * (1.0 if float(t) < 0.86 else lerpf(1.0, 0.1, (float(t) - 0.86) / 0.14)), true, 0.036, wh, 0.1)
	# sode: omuzları örten yeşil plakalar (kolla gider)
	for sd in ["Left", "Right"]:
		_sode(k, _limb(k, sd, false), gn, rd)


# ------------------------------------------------------------------ Taka Kunoichi (ref Karin_full): dik yakalı boydan fermuarlı lavanta ceket, belden aşağı açılan etek ucu, adaçayı yeşili geniş kemer, açık bel, koyu şort, çıplak uyluk, diz üstü zeytin çorap, bilek bağlı çizme ağzı
static func _taka_kunoichi(k) -> void:
	var lv := Color(0.6, 0.52, 0.67)
	var sg := Color(0.63, 0.68, 0.58)
	var sh := Color(0.13, 0.14, 0.14)
	var st := Color(0.27, 0.245, 0.18)
	var bt := Color(0.29, 0.25, 0.23)
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
	var yb: float = H + 0.115
	var hem: float = H - 0.17
	_inner(k, b, func(_i, _j, _p): return lv.darkened(0.4), 0.004, H + 0.12)
	# açık bel ve şort
	SE.body_layer(k, [_kp(wa, H + 0.125, 0.003), _kp(bl, H + 0.015, 0.004)], 8, 36, func(_i, _j, _p): return skc)
	var sk := [_kp(bl, H + 0.025, 0.009), _kp(hp, H - 0.04, 0.016), [H - 0.13, hp.x + 0.014, hp.y + 0.014, hp.z - 0.014]]
	var sf := func(a: float, y: float, _v: float) -> float: return 0.005 * sin(a * 6.0 + y * 8.0)
	_cl(k, {"keys": sk, "ny": 12, "na": 56, "top": func(_a): return H + 0.025, "hem": func(_a): return H - 0.13, "fold": sf, "col": func(_a, _y, _v): return sh, "th": 0.0})
	_bd(k, _ring_pts(sk, H + 0.012, 0.0015, 60), 0.012, 0.003, sh.lightened(0.07), true)
	_line(k, sk, [Vector2(0.0, H + 0.0), Vector2(0.0, H - 0.08)], 0.0024, 0.002, 0.0015, sh.lightened(0.14), 3)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		_bare(k, le, skc, 0.14, 0.42)
		# şort paçası
		var sa := func(s: float, a: float) -> float: return 0.005 + 0.006 * smoothstep(0.0, 0.2, s) - 0.036 * (1.0 - smoothstep(0.02, 0.17, s)) + 0.002 * sin(a * 4.0 + s * 11.0 + 1.0)
		_lt(k, le, sa, func(s, a, ins): return sh.darkened(0.4) if ins else _fs(sh, float(sa.call(float(s), float(a))) - 0.009, 14.0).lightened(0.05 if float(s) > 0.2 else 0.0), 0.0, 0.215, 12, 22, 0.05)
		# uzun çorap: diz üstünden bileğe, dizde kırışık
		var ca := func(s: float, a: float) -> float:
			return 0.0035 + 0.0032 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 34.0) + 0.0016 * exp(-pow((s - 0.9) / 0.05, 2.0)) * sin(a * 4.0 + s * 40.0)
		_lt(k, le, ca, func(s, a, ins): return st.darkened(0.4) if ins else _fs(st, float(ca.call(float(s), float(a))) - 0.0035, 60.0), 0.385, 0.97, 30, 20)
		k.wrap_turn(_lp(le, 0.392), _ld(le, 0.392), _lr(le, 0.392) + 0.004, 0.008, 0.0, st.lightened(0.08), _lskin(le, 0.392))
		# çizme ağzı: bileği saran kalın manşet
		_lt(k, le, func(s, _a): return 0.015 - 0.005 * smoothstep(0.86, 1.0, float(s)), func(s, _a, ins): return bt.darkened(0.42) if ins else bt.darkened(0.14 * (1.0 - smoothstep(0.84, 0.88, float(s)))), 0.84, 1.0, 8, 20, 0.03)
		k.wrap_turn(_lp(le, 0.92), _ld(le, 0.92), _lr(le, 0.92) + 0.014, 0.007, 0.0, bt.darkened(0.25), _lskin(le, 0.92))
		# kol: omuzda hafif bolluk, dirsek kırışığı, bilekte düz manşet
		var kna: float = ar["kn"]
		var la := func(s: float, a: float) -> float:
			var bag := 0.011 + 0.006 * exp(-pow((s - 0.16) / 0.1, 2.0)) + 0.004 * smoothstep(0.75, 1.0, s) - 0.022 * (1.0 - smoothstep(0.0, 0.12, s))
			return bag + 0.0024 * _lf(s, a, 1.3) * sin(s * PI) + 0.0058 * exp(-pow((s - kna) / 0.07, 2.0)) * sin(a * 3.0 + s * 32.0)
		_lt(k, ar, la, func(s, a, ins): return lv.darkened(0.42) if ins else _fs(lv, float(la.call(float(s), float(a))) - 0.012, 26.0), 0.0, 0.985, 34, 20, 0.08)
		_lt(k, ar, func(s, a): return float(la.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return lv.darkened(0.3) if ins else lv.lightened(0.05), 0.915, 0.982, 3, 20)
	# ceket: üstü kapalı, kemerden aşağı önü ters V açılır
	var jk := [_kp(nk, N + 0.03, 0.016), [N - 0.05, ch.x * 0.88, ch.y * 0.9, ch.z * 1.02], _kp(ch, C - 0.03, 0.02), _kp(wa, H + 0.14, 0.018), _kp(bl, yb - 0.04, 0.03), [H - 0.04, hp.x + 0.026, hp.y + 0.046, hp.z - 0.046], [hem, hp.x + 0.044, hp.y + 0.056, hp.z - 0.058]]
	var ef := func(y: float) -> float: return lerpf(0.0, 0.56, smoothstep(yb, hem, y))
	var jf := func(a: float, y: float, _v: float) -> float:
		var u: float = smoothstep(yb + 0.11, yb + 0.01, y) * smoothstep(yb - 0.03, yb + 0.015, y)   # kemere toplanan kırışık
		var d: float = smoothstep(yb - 0.015, yb - 0.08, y)
		return u * 0.018 * sin(a * 11.0 + 0.8) + d * (0.018 * sin(a * 6.0 + 1.2) + 0.008 * sin(a * 13.0)) + 0.0035 * sin(a * 3.0 + y * 7.0) * smoothstep(N, C, y)
	var yt: float = N + 0.024
	var jr := _cl(k, {"keys": jk, "ny": 48, "na": 88, "rng": func(v):
			var e: float = ef.call(lerpf(yt, hem, float(v)))
			return Vector2(e, TAU - e), "top": func(_a): return yt, "hem": func(_a): return hem, "fold": jf, "col": func(_a, _y, _v): return lv, "gain": 8.5, "th": 0.006, "inner": lv.darkened(0.3)})
	_tr(k, (jr["ea"] as Array).slice(22), 0.0048, 0.0028, lv.lightened(0.09))
	_tr(k, (jr["eb"] as Array).slice(22), 0.0048, 0.0028, lv.lightened(0.09))
	var hm := []
	for p: Vector3 in jr["hem"]:
		hm.append(p + Vector3(0, 0.011, 0))
	_tr(k, hm, 0.0028, 0.0014, lv.darkened(0.14))
	# arka dikiş, omuz dikişi
	_line(k, jk, [Vector2(PI, N - 0.03), Vector2(PI, yb + 0.03)], 0.0022, 0.002, 0.0012, lv.darkened(0.2), 8)
	_line(k, jk, [Vector2(PI, yb - 0.04), Vector2(PI, hem + 0.01)], 0.0022, 0.012, 0.0012, lv.darkened(0.2), 5)
	# dik yaka + fermuar
	var ck := [[N + 0.085, nk.x + 0.018, nk.y + 0.016, nk.z - 0.024], [N + 0.012, nk.x + 0.027, nk.y + 0.026, nk.z - 0.03]]
	var cg := _cl(k, {"keys": ck, "ny": 6, "na": 42, "rng": func(_v): return Vector2(0.02, TAU - 0.02), "top": func(a): return N + 0.085 - 0.006 * smoothstep(1.6, 0.0, absf(float(a))), "hem": func(_a): return N + 0.012, "col": func(_a, _y, _v): return lv.lightened(0.03), "skin": func(p): return [["Neck", 0.4], ["UpperChest", 0.6]] if p.y > N else k.torso_skin(p.y), "th": 0.006})
	_bd(k, cg["top"], 0.0042, 0.0028, lv.lightened(0.1), false, func(_p): return [["Neck", 0.4], ["UpperChest", 0.6]], 0.6)
	var zp := []
	var zo := []
	for i in 24:
		var y: float = lerpf(N + 0.08, yb + 0.012, float(i) / 23.0)
		var e: Array = _sa(ck if y > N + 0.012 else jk, 0.0, y, 0.0015)
		zp.append(e[0])
		zo.append(e[1])
	k.strip(zp, zo, 0.0058, 0.0024, Color(0.67, 0.68, 0.63), false, func(p): return [["Neck", 0.4], ["UpperChest", 0.6]] if p.y > N else k.torso_skin(p.y))
	_stud(k, (zp[1] as Vector3) + Vector3(0, 0, 0.003), Vector3(0, 0, 1), 0.0055, Color(0.28, 0.28, 0.3), [["Neck", 0.4], ["UpperChest", 0.6]])
	# adaçayı kemer: geniş, üst kenarı dikişli; sol yanda katlı kapak
	var ok := [_kp(wa, H + 0.2, 0.03), _kp(bl, H + 0.06, 0.036)]
	_sash(k, ok, yb, 0.036, 0.006, sg, 0.08)
	for dy in [0.029, -0.029]:
		_bd(k, _ring_pts(ok, yb + float(dy), 0.0135, 72), 0.0024, 0.0016, sg.darkened(0.2), true)
	for i in 3:
		var x: float = wa.x * (0.32 + 0.14 * float(i))
		_patch(k, ok, x, x + 0.032, yb + 0.04, yb - 0.04, true, 0.016 + 0.003 * float(i), sg.lightened(0.05 - 0.03 * float(i)), 0.04, 6, 6, func(p): return k.torso_skin(p.y))


# ------------------------------------------------------------------ Mizukiri (ref Suigetsu_body): dik boyunlu kolsuz mor üst, göğüs kayışı + yuvarlak plaka, H tokalı kahve kemer, verev uyluk kayışı, su matarası, gri kısa pantolon, kahve konç, kemerden arkaya inen bej örtü (ucu oyuklu)
static func _taka_kenshi(k) -> void:
	var pr := Color(0.56, 0.4, 0.62)
	var br := Color(0.37, 0.27, 0.2)
	var bl2 := Color(0.5, 0.39, 0.29)
	var gy := Color(0.67, 0.69, 0.71)
	var be := Color(0.73, 0.71, 0.61)
	var te := Color(0.13, 0.42, 0.39)
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
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	# üst: boyundan bele kapalı, omuz dar kesim
	var tk := [_kp(nk, N + 0.058, 0.012, 0.014), _kp(nk, N + 0.015, 0.018), [N - 0.05, ch.x * 0.9, ch.y * 0.9, ch.z * 1.0], _kp(ch, C - 0.03, 0.014), _kp(wa, H + 0.12, 0.016), _kp(bl, H + 0.02, 0.016)]
	var tf := func(a: float, y: float, _v: float) -> float:
		var nr: float = smoothstep(C - 0.12, H + 0.06, y)
		var kr: float = exp(-pow((y - (N + 0.03)) / 0.02, 2.0))   # boyun kıvrımı
		return nr * (0.012 * sin(a * 7.0 + y * 8.0) + 0.006 * sin(a * 13.0 + 1.0)) + kr * 0.03 * sin(a * 6.0 + 0.5)
	_cl(k, {"keys": tk, "ny": 40, "na": 72, "top": func(_a): return N + 0.058, "hem": func(_a): return H + 0.02, "fold": tf, "col": func(_a, _y, _v): return pr, "skin": func(p): return [["Neck", 0.5], ["UpperChest", 0.5]] if p.y > N + 0.02 else k.torso_skin(p.y), "gain": 9.0, "th": 0.0})
	_bd(k, _ring_pts(tk, N + 0.054, 0.003, 44), 0.004, 0.002, pr.lightened(0.1), true, func(_p): return [["Neck", 0.5], ["UpperChest", 0.5]], 0.4)
	for sg in [1.0, -1.0]:
		_hole(k, tk, sg, C + 0.0, 0.56, 0.095, 0.0036, 0.0016, pr.darkened(0.2))
	# pantolon üstü
	var pk := [_kp(bl, H + 0.03, 0.018), _kp(hp, H - 0.04, 0.03), [H - 0.15, hp.x + 0.03, hp.y + 0.03, hp.z - 0.03]]
	var pf := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 5.0 + y * 11.0 + 1.0)
	_cl(k, {"keys": pk, "ny": 12, "na": 60, "top": func(_a): return H + 0.03, "hem": func(_a): return H - 0.15, "fold": pf, "col": func(_a, _y, _v): return gy, "th": 0.0})
	for sg in [1.0, -1.0]:   # cep ağızları
		_line(k, pk, [Vector2(sg * 0.5, H + 0.0), Vector2(sg * 0.86, H - 0.08)], 0.0026, 0.004, 0.0016, gy.darkened(0.24), 4)
	_line(k, pk, [Vector2(0.0, H + 0.0), Vector2(0.0, H - 0.11)], 0.0024, 0.003, 0.0014, gy.darkened(0.2), 4)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		_lt(k, ar, func(s, _a): return 0.001 - 0.02 * (1.0 - smoothstep(0.0, 0.13, float(s))), func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, 0.0, 1.0, 26, 16)
		var se: float = kn + 0.24
		var pa := func(s: float, a: float) -> float:
			var bag := 0.015 + 0.006 * smoothstep(0.1, kn, s) + 0.008 * smoothstep(kn, se, s)
			return bag + 0.0052 * sin(a * 3.0 + s * 9.0 + 0.6) + 0.0032 * sin(a * 7.0 - s * 13.0) + 0.0065 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0)
		_lt(k, le, pa, func(s, a, ins): return gy.darkened(0.42) if ins else _fs(gy, float(pa.call(float(s), float(a))) - 0.021, 15.0), 0.0, se, 36, 24, 0.06)
		_lt(k, le, func(s, a): return float(pa.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return gy.darkened(0.3) if ins else gy.darkened(0.09), se - 0.022, se - 0.002, 2, 24)
		# konç: baldır ortasından bileğe, üstü dönük
		var ca := func(s: float, a: float) -> float: return 0.009 + 0.0022 * sin(a * 4.0 + s * 20.0) - 0.003 * smoothstep(0.85, 1.0, s)
		_lt(k, le, ca, func(s, a, ins): return bl2.darkened(0.42) if ins else _fs(bl2, float(ca.call(float(s), float(a))) - 0.009, 40.0), se - 0.08, 1.0, 16, 20)
		_lt(k, le, func(s, a): return float(ca.call(float(s), float(a))) + 0.004, func(_s, _a, ins): return br.darkened(0.2) if ins else br, 0.94, 0.995, 3, 20)
	# göğüs kayışı + yuvarlak plaka
	var cy: float = C - 0.1
	var sk2 := [_kp(ch, cy + 0.1, 0.018), _kp(wa, cy - 0.12, 0.018)]
	_sash(k, sk2, cy, 0.024, 0.005, br, 0.1)
	var pl: Array = _fp(sk2, 0.0, cy, true, 0.016)
	_fan(k, pl[0], pl[1], Vector3.UP, 0.036, func(th): return 1.0 + 0.1 * pow(absf(sin(float(th))), 4.0), func(u, v):
		var r: float = sqrt(float(u) * float(u) + float(v) * float(v))
		return bl2.darkened(0.3) if r > 0.84 else bl2, k.torso_skin(cy), 5, 26)
	_stud(k, (pl[0] as Vector3) + (pl[1] as Vector3) * 0.002, pl[1], 0.011, Color(0.58, 0.56, 0.5), k.torso_skin(cy))
	# kemer: H toka
	var yb: float = H + 0.035
	var ok := [_kp(bl, H + 0.14, 0.024), _kp(bl, H - 0.04, 0.03)]
	_sash(k, ok, yb, 0.03, 0.005, br, 0.08)
	_bd(k, _ring_pts(ok, yb + 0.024, 0.012, 72), 0.002, 0.0014, br.darkened(0.3), true)
	_bd(k, _ring_pts(ok, yb - 0.024, 0.012, 72), 0.002, 0.0014, br.darkened(0.3), true)
	_patch(k, ok, -0.042, 0.042, yb + 0.034, yb - 0.034, true, 0.015, bl2, 0.06, 8, 8, func(p): return k.torso_skin(p.y))
	for q in [[-0.022, 0.026, -0.022, -0.026], [0.022, 0.026, 0.022, -0.026], [-0.022, 0.0, 0.022, 0.0]]:
		_strap(k, ok, [Vector2(q[0], yb + float(q[1])), Vector2(q[2], yb + float(q[3]))], true, 0.0042, 0.021, 0.002, br.darkened(0.35), 3, func(p): return k.torso_skin(p.y))
	# verev uyluk kayışı + mataralık
	var tk2 := [_kp(hp, H - 0.03, 0.043), [H - 0.2, hp.x + 0.052, hp.y + 0.05, hp.z - 0.05]]
	_cur_hem = H - 0.3
	var bp := []
	for i in 72:
		var a := TAU * i / 72.0 - PI
		bp.append(_on(tk2, a, H - 0.105 - 0.024 * sin(a - 0.4), 0.0))
	_bd(k, bp, 0.0185, 0.0048, br.lightened(0.05), true, func(p): return _hs(k, p))
	var e0: Array = _fp(tk2, 0.72 * (hp.x + 0.046), H - 0.1, true, 0.008)
	_boxr(k, e0[0], Vector3(0.026, 0, 0), Vector3(0, 0.024, 0), (e0[1] as Vector3) * 0.006, bl2, [["Hips", 0.5], ["LeftUpperLeg", 0.5]], 0.25)
	# su matarası: sağ uylukta
	var bo := [["RightUpperLeg", 0.6], ["Hips", 0.4]]
	var mc := Vector3(-hp.x - 0.04, H - 0.11, -hp.y * 0.72)
	k.tube([mc + Vector3(0, 0.082, 0), mc + Vector3(0, -0.082, 0)], ["RightUpperLeg"], [[0.0, 0.03], [0.05, 0.036], [0.95, 0.036], [1.0, 0.03]], func(t, a, _i):
		if float(t) < 0.09 or float(t) > 0.91:
			return Color(0.1, 0.11, 0.12)
		return te.darkened(0.2 if cos(float(a) + 0.6) < -0.2 else 0.0).lightened(0.08 if absf(float(t) - 0.5) < 0.012 else 0.0), 12, 14, false)
	_tb(k, [mc + Vector3(0.008, 0.08, 0), mc + Vector3(0.008, 0.15, 0.003)], func(_s, _a): return 0.0034, func(_s, _a, _p): return Color(0.1, 0.11, 0.12), func(_s, _p): return bo, 6)
	for dy in [0.04, -0.04]:
		var c1 := mc + Vector3(0, float(dy), 0)
		var pts := []
		for i in 13:
			var a := TAU * i / 12.0
			pts.append(c1 + Vector3(cos(a), 0, sin(a)) * 0.0385)
		_tb(k, pts, func(_s, _a): return 0.005, func(_s, _a, _p): return br, func(_s, _p): return bo, 6)
	_boxr(k, Vector3(-hp.x - 0.006, H - 0.1, -hp.y * 0.66), Vector3(0.016, 0, 0), Vector3(0, 0.016, 0), Vector3(0, 0, 0.013), br.darkened(0.1), bo)
	# bej örtü: kemerden sol arkaya, altı kavisli, ucunda oyuk
	var hem: float = K - 0.13
	var dk := [_kp(bl, yb, 0.036), _kp(hp, H - 0.04, 0.062), [H - 0.26, hp.x + 0.085, hp.y + 0.08, hp.z - 0.09], [hem, hp.x + 0.1, hp.y + 0.09, hp.z - 0.13]]
	var a0 := 1.2
	var a1 := PI + 0.3
	var uu := func(a: float) -> float: return clampf(wrapf(a - a0, 0.0, TAU) / (a1 - a0), 0.0, 1.0)
	var hf := func(a: float) -> float:
		var u: float = uu.call(a)
		var nt := 0.1 * exp(-pow((u - 0.34) / 0.075, 2.0))
		return lerpf(H - 0.2, hem, pow(sin(clampf(u * 1.1, 0.0, 1.0) * PI * 0.5), 1.4)) + 0.13 * smoothstep(0.76, 1.0, u) + nt
	var df := func(a: float, y: float, v: float) -> float:
		return float(v) * float(v) * (0.024 * sin(a * 7.0 + 0.5) + 0.012 * sin(a * 13.0 + 2.0)) + (1.0 - float(v)) * 0.008 * sin(a * 9.0 + y * 4.0)
	_cur_long = true
	var dg := _cl(k, {"keys": dk, "ny": 32, "na": 54, "rng": func(_v): return Vector2(a0, a1), "top": func(_a): return yb - 0.012, "hem": hf, "fold": df, "col": func(_a, _y, _v): return be, "gain": 6.5, "th": 0.006, "inner": be.darkened(0.1)})
	var hm := []
	for p: Vector3 in dg["hem"]:
		hm.append(p + Vector3(0, 0.012, 0))
	_tr(k, hm, 0.0034, 0.0016, be.lightened(0.1))
	_cur_long = false


# ------------------------------------------------------------------ Oboro Koromo (ref Second_Mizukage-Full): ince çizgili gri cübbe, dev dik yaka + bej astar, koyu geniş kuşak, geniş kol, önü kavisli açılan etek, koyu yeşil iç ve şalvar, kahve konç
static func _nidaime_koromo(k) -> void:
	var gr := Color(0.67, 0.68, 0.7)
	var ln := Color(0.33, 0.34, 0.38)
	var tn := Color(0.56, 0.46, 0.36)
	var dg := Color(0.1, 0.17, 0.14)
	var ob := Color(0.2, 0.21, 0.24)
	var br := Color(0.28, 0.22, 0.2)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.08, 0.3)
	var yo: float = H + 0.1
	_inner(k, b, func(_i, _j, _p): return dg)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		var se: float = kn + 0.27
		var pa := func(s: float, a: float) -> float:
			return 0.007 + 0.007 * exp(-pow((s - kn + 0.1) / 0.16, 2.0)) - 0.016 * smoothstep(kn - 0.12, kn - 0.02, s) * (1.0 - smoothstep(kn + 0.17, kn + 0.25, s)) - 0.06 * maxf(0.0, -cos(a)) * smoothstep(0.08, 0.24, s) * (1.0 - smoothstep(kn + 0.2, kn + 0.26, s)) + 0.004 * smoothstep(se - 0.09, se, s) + (0.006 * sin(a * 4.0 + s * 10.0) + 0.003 * sin(a * 7.0 - s * 16.0)) * (1.0 - 0.8 * smoothstep(se - 0.08, se, s))
		_lt(k, le, pa, func(s, a, ins): return dg.darkened(0.42) if ins else _fs(dg, float(pa.call(float(s), float(a))) - 0.012, 14.0), 0.0, se, 34, 22, 0.05)
		var ca := func(s: float, a: float) -> float: return 0.006 + 0.002 * sin(a * 3.0 + s * 26.0) - 0.002 * smoothstep(0.84, 1.0, s)
		_lt(k, le, ca, func(s, a, ins): return br.darkened(0.42) if ins else _fs(br, float(ca.call(float(s), float(a))) - 0.006, 40.0), se - 0.04, 1.0, 16, 20, 0.05)
		_lt(k, ar, func(_s, _a): return 0.006, func(_s, _a, ins): return dg.darkened(0.4) if ins else dg, 0.0, 0.98, 18, 14)
		_wide_sleeve(k, ar, {"col": gr, "in": tn, "s1": 0.88, "add": 0.024, "wide": 0.042, "sag": 0.065, "seed": 0.6 if sd == "Left" else 2.1, "stripe": ln, "stripes": 16})
	# üst: kalın, kruvaze
	var keys := [_kp(nk, N + 0.02, 0.05), [N - 0.05, ch.x * 1.07, ch.y * 0.98, ch.z * 1.1], _kp(ch, C - 0.03, 0.054), _kp(wa, H + 0.14, 0.066), _kp(bl, yo - 0.03, 0.042)]
	var yt: float = N + 0.02
	var yc: float = C - 0.05
	var uf := func(a: float, y: float, _v: float) -> float:
		var nr: float = smoothstep(C - 0.06, yo + 0.03, y)
		return nr * (0.03 * sin(a * 8.0 + 1.1) + 0.014 * sin(a * 13.0)) + 0.007 * sin(a * 3.0 + y * 8.0)
	var w := _wrap_top(k, {"keys": keys, "yt": yt, "yb": yo - 0.03, "yc": yc, "e0": 0.44, "a1": -0.2, "a2": 0.02, "pw": 1.0, "col": func(_a, _y, _v): return gr, "fold": uf, "ny": 26, "na": 96, "gain": 6.0})
	_stripes(k, w["rows"], 4, 0.0017, ln)
	# etek: önde üstten açılır, kenarları yuvarlanarak dışa kaçar
	var hem: float = K - 0.31
	var sk := [_kp(bl, yo, 0.05), _kp(hp, H - 0.04, 0.066), [H - 0.32, hp.x + 0.095, hp.y + 0.09, hp.z - 0.1], [hem, hp.x + 0.15, hp.y + 0.12, hp.z - 0.17]]
	var ys: float = H - 0.05
	var r1 := func(y: float) -> float: return lerpf(-0.16, 0.92, pow(smoothstep(ys, hem, y), 1.25))
	var r2 := func(y: float) -> float: return lerpf(0.02, 0.5, pow(smoothstep(ys, hem, y), 1.25))
	var hf := func(a: float) -> float:
		var d1: float = absf(wrapf(a - 0.92, -PI, PI))
		var d2: float = absf(wrapf(a + 0.5, -PI, PI))
		return hem + 0.14 * exp(-pow(d1 / 0.34, 2.0)) + 0.09 * exp(-pow(d2 / 0.26, 2.0))
	var sf := func(a: float, y: float, v: float) -> float:
		return float(v) * float(v) * (0.045 * sin(a * 6.0 + 1.3) + 0.018 * sin(a * 11.0 + 0.4)) + (1.0 - float(v)) * 0.014 * sin(a * 9.0 + y * 3.0)
	_cur_long = true
	_cur_rear = true
	var sg := _cl(k, {"keys": sk, "ny": 50, "na": 108, "rng": func(v):
			var y: float = lerpf(yo, hem, float(v))
			return Vector2(float(r1.call(y)), TAU - float(r2.call(y))), "top": func(_a): return yo, "hem": hf, "fold": sf, "col": func(_a, _y, _v): return gr, "gain": 5.5, "th": 0.007, "inner": tn})
	_cur_hem = hem
	_stripes(k, sg["rows"], 4, 0.0018, ln)
	var hm := []
	for p: Vector3 in sg["hem"]:
		hm.append(p + Vector3(0, 0.004, 0))
	_tr(k, hm, 0.003, 0.0016, gr.darkened(0.14))
	_tr(k, sg["ea"], 0.003, 0.0016, gr.darkened(0.14))
	_tr(k, sg["eb"], 0.003, 0.0016, gr.darkened(0.14))
	_cur_long = false
	_cur_rear = false
	# koyu kuşak: geniş iki kat
	var ok := [_kp(wa, yo + 0.1, 0.078), _kp(wa, yo - 0.1, 0.082)]
	_sash(k, ok, yo, 0.058, 0.01, ob, 0.1)
	_bd(k, _ring_pts(ok, yo + 0.016, 0.019, 80), 0.0028, 0.0018, ob.lightened(0.09), true)
	# dev dik yaka: önde iki sivri uç, içi bej
	var cskin := func(p: Vector3) -> Array:
		if p.y < N - 0.01:
			return k.torso_skin(p.y)
		return [["Neck", 0.22], ["UpperChest", 0.78]]
	var ck := [[N + 0.22, nk.x + 0.2, nk.y + 0.19, nk.z - 0.14], [N + 0.12, nk.x + 0.135, nk.y + 0.125, nk.z - 0.105], [N + 0.05, nk.x + 0.085, nk.y + 0.085, nk.z - 0.08], [N - 0.03, nk.x + 0.095, nk.y + 0.095, nk.z - 0.09]]
	var cfold := func(a: float, y: float, _v: float) -> float: return 0.016 * sin(a * 3.0 + 0.4) * smoothstep(N, N + 0.2, y)
	var cg := _cl(k, {"keys": ck, "ny": 18, "na": 62, "rng": func(v): return Vector2(lerpf(0.78, 0.26, float(v)), TAU - lerpf(0.78, 0.26, float(v))),
		"top": func(a):
			var aa := absf(float(a))
			return N + 0.09 + 0.085 * exp(-pow((aa - 0.8) / 0.38, 2.0)) + 0.012 * smoothstep(1.8, PI, aa), "hem": func(_a): return N - 0.03, "fold": cfold, "col": func(_a, _y, _v): return gr, "gain": 4.0, "th": 0.009, "inner": tn, "skin": cskin})
	_stripes(k, cg["rows"], 3, 0.0015, ln, cskin)
	_tb(k, cg["top"], func(_s, _a): return 0.0058, func(_s, a, _p): return gr.lightened(0.08) if cos(float(a)) > -0.3 else gr.darkened(0.15), func(_s, p): return cskin.call(p), 6)
	for ed in ["ea", "eb"]:
		_tb(k, cg[ed], func(_s, _a): return 0.0055, func(_s, _a, _p): return gr.lightened(0.05), func(_s, p): return cskin.call(p), 6)


# ------------------------------------------------------------------ Uzushio Hime (ref Mito, Mito_and_Kushina): yere yakın beyaz kimono, geniş deniz yeşili kat yaka + ince iç yaka, uzun sarkık yen, arduvaz geniş obi + açık bant, deniz yeşili kordon, sırtta taiko düğüm
static func _uzushio_hime(k) -> void:
	var wh := Color(0.93, 0.92, 0.88)
	var te := Color(0.17, 0.53, 0.51)
	var pa := Color(0.74, 0.86, 0.82)
	var ob := Color(0.25, 0.26, 0.31)
	var ol := Color(0.68, 0.68, 0.66)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var F: float = k.F
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.1, 0.3)
	var yo: float = H + 0.125
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	SE.body_layer(k, [[N + 0.03, nk.x, nk.y, nk.z], [N - 0.05, ch.x * 0.74, ch.y * 0.8, ch.z * 0.86], _kp(ch, C - 0.03, 0.002), _kp(wa, H + 0.14, 0.002)], 12, 34, func(_i, _j, _p): return skc)
	# iç kimono: açık yeşil yaka olarak görünür
	var yt: float = N + 0.018
	var yc: float = C - 0.1
	var jk := [_kp(nk, N + 0.014, 0.024), [N - 0.05, ch.x * 0.82, ch.y * 0.86, ch.z * 0.98], _kp(ch, C - 0.03, 0.018), _kp(wa, H + 0.14, 0.024)]
	_cl(k, {"keys": jk, "ny": 18, "na": 60, "top": func(a): return lerpf(C + 0.055, N + 0.014, clampf(absf(float(a)) / 0.42, 0.0, 1.0)), "hem": func(_a): return H + 0.13, "col": func(_a, _y, _v): return pa, "skin": func(p): return k.torso_skin(p.y), "th": 0.0})
	# üst kimono
	var keys := [_kp(nk, N + 0.018, 0.034), [N - 0.05, ch.x * 0.9, ch.y * 0.9, ch.z * 1.04], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.15, 0.04), _kp(bl, yo - 0.02, 0.024)]
	var uf := func(a: float, y: float, _v: float) -> float:
		var nr: float = smoothstep(C - 0.08, yo + 0.02, y)
		return nr * (0.02 * sin(a * 9.0 + 0.6) + 0.009 * sin(a * 15.0)) + 0.005 * sin(a * 3.0 + y * 9.0)
	var w := _wrap_top(k, {"keys": keys, "yt": yt, "yb": yo - 0.02, "yc": yc, "e0": 0.46, "a1": -0.24, "a2": -0.04, "col": func(_a, _y, _v): return wh, "fold": uf, "gain": 5.0})
	_band(k, keys, _collar_path(w, yt, yo, lerpf(yc, yt, 0.12), 0.46), func(_t): return 0.042, 0.007, te, 3, 6, 0.05, 0.14)
	# alt kat + üstte binen etek: yere kadar, geriye hafif uzar
	var hem: float = F + 0.085
	var sk := [_kp(bl, yo, 0.03), _kp(hp, H - 0.04, 0.04), [H - 0.34, hp.x + 0.03, hp.y + 0.05, hp.z - 0.07], [hem + 0.1, hp.x + 0.035, hp.y + 0.062, hp.z - 0.11], [hem, hp.x + 0.07, hp.y + 0.075, hp.z - 0.15]]
	var sku := []
	for e in sk:
		sku.append([e[0], float(e[1]) - 0.008, float(e[2]) - 0.008, float(e[3]) + 0.008])
	var hf := func(a: float) -> float: return hem - 0.03 * smoothstep(1.4, PI, absf(float(a)))
	var sf := func(a: float, y: float, v: float) -> float:
		return float(v) * (0.032 * sin(a * 7.0 + 1.0) + 0.016 * sin(a * 12.0 + 0.2)) + (1.0 - float(v)) * 0.01 * sin(a * 11.0 + y * 2.0)
	_cur_long = true
	_cl(k, {"keys": sku, "ny": 22, "na": 60, "top": func(_a): return yo, "hem": hf, "fold": sf, "col": func(_a, _y, _v): return wh.darkened(0.1), "gain": 4.0, "th": 0.0})
	var r1 := func(y: float) -> float: return lerpf(-0.3, -0.5, smoothstep(H, hem, y))
	var sg := _cl(k, {"keys": sk, "ny": 54, "na": 104, "rng": func(v):
			var y: float = lerpf(yo, hem, float(v))
			return Vector2(float(r1.call(y)), TAU - 0.72 + 0.1 * float(v)), "top": func(_a): return yo, "hem": hf, "fold": sf, "col": func(_a, _y, _v): return wh, "gain": 4.2, "th": 0.006, "inner": wh.darkened(0.08)})
	_tr(k, sg["ea"], 0.0052, 0.003, wh.lightened(0.04))
	var hm := []
	for p: Vector3 in sg["hem"]:
		hm.append(p + Vector3(0, 0.012, 0))
	_tr(k, hm, 0.0032, 0.0016, wh.darkened(0.12))
	_cur_long = false
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		_lt(k, le, func(_s, _a): return 0.004, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.08), 0.0, 1.0, 18, 14)   # alt giysi: koşarken eteğin altından bu görünür
		_lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return pa.darkened(0.3) if ins else pa, 0.0, 0.98, 14, 12)
		_wide_sleeve(k, ar, {"col": wh, "in": pa.darkened(0.12), "s1": 0.93, "add": 0.02, "wide": 0.036, "sag": 0.135, "seed": 0.9 if sd == "Left" else 2.4, "hem": te, "hem_w": 0.012})
	# obi: geniş, üst kenar açık bant, ortada kordon
	var ok := [[yo + 0.12, wa.x + 0.04, wa.y + 0.054, wa.z - 0.054], [yo - 0.12, wa.x + 0.044, wa.y + 0.058, wa.z - 0.058]]
	_sash(k, ok, yo, 0.076, 0.011, ob, 0.1)
	_sash(k, ok, yo + 0.06, 0.012, 0.016, ol, 0.05)
	_cord(k, _ring_pts(ok, yo - 0.006, 0.026, 72), 0.0052, te, true, Callable(), 1.3)
	var kq: Array = _fp(ok, 0.0, yo - 0.006, true, 0.03)
	k.tube([(kq[0] as Vector3) + Vector3(-0.018, 0, 0), (kq[0] as Vector3) + Vector3(0.018, 0, 0)], ["Hips"], [[0.0, 0.007], [0.5, 0.0115], [1.0, 0.007]], func(_t, a, _i): return te.darkened(0.2 if sin(float(a)) < 0.0 else 0.0), 6, 10, false)
	# taiko düğüm: sırtta yastık + altına kıvrılan kat + yanlardan çıkan bant
	var bq: Array = _sa(ok, PI, yo + 0.012, 0.03)
	var bc: Vector3 = bq[0]
	var bo := [["Spine", 0.5], ["Hips", 0.5]]
	_boxr(k, bc + Vector3(0, 0.012, -0.03), Vector3(0.125, 0, 0), Vector3(0, 0.084, 0), Vector3(0, 0, -0.038), ob.lightened(0.04), bo, 0.46)
	_boxr(k, bc + Vector3(0, -0.076, -0.03), Vector3(0.11, 0, 0), Vector3(0, 0.024, 0), Vector3(0, 0, -0.03), ob.darkened(0.08), bo, 0.5)
	_boxr(k, bc + Vector3(0, 0.1, -0.022), Vector3(0.094, 0, 0), Vector3(0, 0.012, 0), Vector3(0, 0, -0.024), ol, bo, 0.5)
	for sx in [1.0, -1.0]:
		_boxr(k, bc + Vector3(sx * 0.137, -0.012, -0.018), Vector3(0.03, 0, 0), Vector3(0, 0.024, 0), Vector3(0, 0, -0.014), ob.darkened(0.14), bo, 0.45)


# ------------------------------------------------------------------ Kinrai (ref Kinkaku's_Tools, Kinkaku_268): çıplak kollu, V göğüslü beyaz göğüslük + siyah biye ve çizgi işareti, üstünde önü açık mor kolsuz + sivri dik yaka, mor uzun etek ve bej ön peşkir, koyu şalvar, koyu kolluk
static func _kumo_kyodai(k) -> void:
	var pr := Color(0.31, 0.22, 0.42)
	var wh := Color(0.9, 0.89, 0.85)
	var bk := Color(0.1, 0.1, 0.13)
	var be := Color(0.73, 0.67, 0.58)
	var sl := Color(0.25, 0.27, 0.33)
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
	var bl: Vector3 = k.M(H + 0.07, 0.3)
	var yo: float = H + 0.075
	SE.body_layer(k, [[N + 0.03, nk.x, nk.y, nk.z], [N - 0.05, ch.x * 0.78, ch.y * 0.82, ch.z * 0.88], _kp(ch, C - 0.03, 0.002), _kp(wa, H + 0.13, 0.002)], 12, 36, func(_i, _j, _p): return skc)
	SE.body_layer(k, [_kp(bl, yo + 0.01, 0.004), _kp(hp, H - 0.05, 0.016), [H - 0.14, hp.x * 0.76, hp.y * 0.78, hp.z * 0.78]], 8, 32, func(_i, _j, _p): return sl.darkened(0.2))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = le["kn"]
		_bare(k, ar, skc)
		# koyu kolluk: bilekten kola, ağzı dönük, iki kayış
		var ga := func(s: float, a: float) -> float: return 0.0085 + 0.0018 * sin(a * 5.0 + s * 24.0) + 0.004 * smoothstep(0.76, 0.66, s)
		_lt(k, ar, ga, func(s, a, ins): return sl.darkened(0.45) if ins else _fs(sl, float(ga.call(float(s), float(a))) - 0.009, 40.0), 0.63, 0.965, 14, 16, 0.03)
		for s in [0.72, 0.88]:
			k.wrap_turn(_lp(ar, s), _ld(ar, s), _lr(ar, s) + 0.0105, 0.0065, 0.0, bk.lightened(0.05), _lskin(ar, s))
		# şalvar
		var pa := func(s: float, a: float) -> float:
			return 0.014 + 0.012 * exp(-pow((s - kn - 0.06) / 0.22, 2.0)) - 0.024 * smoothstep(kn - 0.12, kn - 0.02, s) * (1.0 - smoothstep(kn + 0.26, kn + 0.38, s)) - 0.06 * maxf(0.0, -cos(a)) * smoothstep(0.08, 0.24, s) * (1.0 - smoothstep(kn + 0.16, kn + 0.24, s)) - 0.012 * smoothstep(0.84, 1.0, s) + 0.006 * sin(a * 4.0 + s * 10.0 + 1.0) + 0.003 * sin(a * 7.0 - s * 14.0)
		_lt(k, le, pa, func(s, a, ins): return sl.darkened(0.42) if ins else _fs(sl, float(pa.call(float(s), float(a))) - 0.026, 12.0), 0.0, 1.0, 38, 22)
		_wraps(k, le, 0.9, 0.985, 4, 0.01, 0.0115, bk.lightened(0.08), 0.004)
		# mor omuz başlığı
		var ca := func(s: float, _a: float) -> float: return 0.018 + 0.012 * smoothstep(0.03, 0.17, s)
		_lt(k, ar, ca, func(s, _a, ins): return pr.darkened(0.42) if ins else pr.darkened(0.18 * smoothstep(0.1, 0.19, float(s))), 0.0, 0.19, 8, 22, 0.05)
		_lt(k, ar, func(s, a): return float(ca.call(float(s), float(a))) + 0.0015, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.178, 0.188, 1, 22)
	# beyaz göğüslük: boyun V, belde biter
	var tk := [_kp(nk, N + 0.015, 0.024), [N - 0.05, ch.x * 0.98, ch.y * 0.89, ch.z * 1.02], _kp(ch, C - 0.03, 0.016), _kp(wa, H + 0.13, 0.024), _kp(bl, yo - 0.02, 0.02)]
	var yv: float = C - 0.055
	var wf := func(a: float, y: float, _v: float) -> float: return 0.012 * sin(a * 8.0 + 1.0) * smoothstep(C - 0.1, yo + 0.04, y) + 0.003 * sin(a * 4.0 + y * 12.0)
	var tg := _cl(k, {"keys": tk, "ny": 26, "na": 84, "top": func(a): return lerpf(yv, N + 0.015, clampf(absf(float(a)) / 0.66, 0.0, 1.0)), "hem": func(_a): return yo - 0.02, "fold": wf, "col": func(_a, _y, _v): return wh, "skin": func(p): return k.torso_skin(p.y), "gain": 6.5, "th": 0.0})
	var ve := []
	for p: Vector3 in tg["top"]:
		if absf(atan2(p.x, p.z)) < 0.72:
			ve.append(p)
	_bd(k, ve, 0.0058, 0.0032, bk, false, func(p): return k.torso_skin(p.y))
	# çizgi işareti (sol göğüs) ve verev siyah çizgi
	var skt := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	for i in 3:
		var y: float = C - 0.1 - float(i) * 0.03
		_strap(k, tk, [Vector2(ch.x * 0.16, y + 0.004), Vector2(ch.x * 0.56, y - 0.004)], true, 0.0072, 0.0035, 0.0022, bk, 4, skt)
	_strap(k, tk, [Vector2(ch.x * 0.36, C - 0.08), Vector2(ch.x * 0.3, C - 0.19)], true, 0.0052, 0.0045, 0.0022, bk, 4, skt)
	_strap(k, tk, [Vector2(-ch.x * 0.66, C - 0.01), Vector2(-ch.x * 0.3, C - 0.13), Vector2(wa.x * 0.2, yo + 0.012)], true, 0.006, 0.0035, 0.0022, bk, 6, skt)
	# mor kolsuz: önden açık, ense ve sırtı kapatır
	var vk := [_kp(nk, N + 0.022, 0.04), [N - 0.05, ch.x * 1.05, ch.y * 0.95, ch.z * 1.09], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.13, 0.04), _kp(bl, yo - 0.02, 0.034)]
	var vf := func(a: float, y: float, _v: float) -> float: return 0.016 * sin(a * 7.0 + 0.4) * smoothstep(C - 0.1, yo + 0.04, y) + 0.004 * sin(a * 3.0 + y * 8.0)
	var ee := func(v: float) -> float: return lerpf(0.66, 0.92, smoothstep(0.0, 0.55, v))
	var vg := _cl(k, {"keys": vk, "ny": 26, "na": 74, "rng": func(v): return Vector2(float(ee.call(float(v))), TAU - float(ee.call(float(v)))), "top": func(_a): return N + 0.022, "hem": func(_a): return yo - 0.02, "fold": vf, "col": func(_a, _y, _v): return pr, "skin": skt, "gain": 7.5, "th": 0.006})
	_bd(k, vg["ea"], 0.0052, 0.0028, bk, false, skt)
	_bd(k, vg["eb"], 0.0052, 0.0028, bk, false, skt)
	# etek: mor, önde açık; bej peşkir altından sarkar
	var hem: float = K - 0.13
	var sk := [_kp(bl, yo, 0.036), _kp(hp, H - 0.04, 0.05), [K + 0.1, hp.x + 0.095, hp.y + 0.1, hp.z - 0.11], [hem, hp.x + 0.125, hp.y + 0.135, hp.z - 0.14]]
	var ap := [_kp(bl, yo, 0.03), _kp(hp, H - 0.04, 0.042), [K + 0.1, hp.x + 0.06, hp.y + 0.075, hp.z - 0.09], [K - 0.03, hp.x + 0.065, hp.y + 0.09, hp.z - 0.1]]
	var af := func(a: float, y: float, v: float) -> float: return float(v) * 0.026 * sin(a * 6.0 + 0.3) + 0.004 * sin(a * 9.0 + y * 4.0)
	_cur_long = true
	_cur_rear = true
	var ag := _cl(k, {"keys": ap, "ny": 26, "na": 34, "rng": func(_v): return Vector2(-0.62, 0.62), "top": func(_a): return yo, "hem": func(a): return K - 0.03 + 0.05 * smoothstep(0.2, 0.62, absf(float(a))), "fold": af, "col": func(_a, _y, _v): return be, "gain": 6.0, "th": 0.005})
	var hma := []
	for p: Vector3 in ag["hem"]:
		hma.append(p + Vector3(0, 0.01, 0))
	_tr(k, hma, 0.003, 0.0015, be.darkened(0.2))
	var ef := func(y: float) -> float: return lerpf(0.12, 0.42, smoothstep(H, hem, y))
	var sf := func(a: float, y: float, v: float) -> float:
		return float(v) * float(v) * (0.042 * sin(a * 6.0 + 0.9) + 0.022 * sin(a * 11.0 + 2.3)) + (1.0 - float(v)) * 0.012 * sin(a * 10.0 + y * 3.0)
	var sg := _cl(k, {"keys": sk, "ny": 40, "na": 92, "rng": func(v):
			var e: float = ef.call(lerpf(yo, hem, float(v)))
			return Vector2(e, TAU - e), "top": func(_a): return yo, "hem": func(a): return hem + 0.035 * sin(float(a) * 3.0 + 0.7) * smoothstep(0.4, 1.2, absf(float(a))), "fold": sf, "col": func(_a, _y, _v): return pr, "gain": 6.0, "th": 0.007, "inner": pr.darkened(0.1)})
	for ed in ["ea", "eb"]:
		_tr(k, sg[ed], 0.0046, 0.0024, bk)
	var hm := []
	for p: Vector3 in sg["hem"]:
		hm.append(p + Vector3(0, 0.014, 0))
	_tr(k, hm, 0.0052, 0.0024, bk)
	# kuşak: koyu mor, sağ yanda düğüm, etek üstüne oturan iki uç
	var ok := [_kp(bl, H + 0.2, 0.04), _kp(bl, H + 0.0, 0.046)]
	_sash(k, ok, yo, 0.038, 0.009, pr.darkened(0.22), 0.14)
	var kp: Array = _fp(ok, -bl.x * 0.62, yo, true, 0.022)
	var kc: Vector3 = kp[0]
	k.tube([kc + Vector3(-0.025, 0.012, 0), kc + Vector3(0.025, -0.012, 0)], ["Hips"], [[0.0, 0.014], [0.5, 0.023], [1.0, 0.014]], func(_t, a, _i): return pr.darkened(0.22 if sin(float(a) * 3.0) > -0.2 else 0.38), 7, 12, false)
	for e in [[-0.012, 0.012, 0.22, 0.021], [0.015, 0.034, 0.17, 0.017]]:
		var ctr := []
		for j in 11:
			var t := float(j) / 10.0
			ctr.append(Vector2(kc.x + float(e[0]) + float(e[1]) * t, yo - 0.03 - float(e[2]) * t))
		var ew: float = e[3]
		_ribbon(k, sk, ctr, func(t): return ew * (1.0 if float(t) < 0.88 else lerpf(1.0, 0.25, (float(t) - 0.88) / 0.12)), true, 0.022, pr.darkened(0.3), 0.12)
	_cur_long = false
	_cur_rear = false
	# sivri dik yaka
	var cskin := func(p: Vector3) -> Array: return [["Neck", 0.4], ["UpperChest", 0.6]] if p.y > N else k.torso_skin(p.y)
	var ck := [[N + 0.15, nk.x + 0.085, nk.y + 0.065, nk.z - 0.075], [N + 0.05, nk.x + 0.05, nk.y + 0.045, nk.z - 0.05], [N - 0.02, nk.x + 0.058, nk.y + 0.058, nk.z - 0.05]]
	var cg := _cl(k, {"keys": ck, "ny": 12, "na": 46, "rng": func(v): return Vector2(lerpf(0.62, 0.72, float(v)), TAU - lerpf(0.62, 0.72, float(v))),
		"top": func(a):
			var aa := absf(float(a))
			return N + 0.085 + 0.055 * exp(-pow((aa - 0.72) / 0.3, 2.0)), "hem": func(_a): return N - 0.02, "col": func(_a, _y, _v): return pr, "skin": cskin, "th": 0.007, "inner": pr.darkened(0.3)})
	_bd(k, cg["top"], 0.0044, 0.0026, bk, false, cskin, 0.5)
	for ed in ["ea", "eb"]:
		_bd(k, cg[ed], 0.0044, 0.0026, bk, false, cskin)
