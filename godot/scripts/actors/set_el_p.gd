extends RefCounted
## Elle modellenmiş setler, parti p: set_anbu_kasumi, set_anbu_wakate, set_anbu_byakue, ss_gunesi, ss_iryo_hemsire, ss_iryo_hemsire_bahar. Örnek: set_el.gd içindeki _shugonin.
## Yardımcılar parti i'den kopya (kendi _cur_hem / _cur_leg durumu bu dosyada); setlere özel olanlar dosyanın sonunda.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

## set_anbu_byakue: tarifi hazır (_byakue) ama koşuda palto önü bacakla açılıyor / yan etek kanatlanıyor; temiz çıkana dek listede değil
const DONE := ["set_anbu_kasumi", "set_anbu_wakate", "ss_gunesi", "ss_iryo_hemsire", "ss_iryo_hemsire_bahar"]


static func recipe(k, sid: String) -> void:
	_cur_leg = 0.58
	_cur_ramp = 1.0
	_cur_bz = 0.075
	_cur_side = 0.0
	match sid:
		"set_anbu_kasumi": _kasumi(k)
		"set_anbu_wakate": _wakate(k)
		"set_anbu_byakue": _byakue(k)
		"ss_gunesi": _gunesi(k)
		"ss_iryo_hemsire": _hemsire(k, false)
		"ss_iryo_hemsire_bahar": _hemsire(k, true)



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


## Parti p: bacak ağırlığı rampası (_cur_ramp: etek boyunun hangi oranında tam bacağa geçer) ve sağ/sol geçiş genişliği (_cur_bz).
## Uzun giyside dar geçiş: orta dikiş iki bacak arasında gerilir, iki dönüşün ortalaması kumaşı içe ezmez.
static var _cur_ramp := 1.0
static var _cur_bz := 0.075
static var _cur_side := 0.0   # yan kumaşın bacak payı azalır: adımda yan etek kanat gibi açılmaz


static func _hs(k, p: Vector3) -> Array:
	if p.y >= k.H:
		return k.torso_skin(p.y)
	var t := clampf((k.H - p.y) / maxf(0.05, k.H - _cur_hem), 0.0, 1.0)
	var w := _cur_leg * (t if _cur_ramp >= 1.0 else smoothstep(0.0, _cur_ramp, t)) * (1.0 - _cur_side * smoothstep(0.09, 0.19, absf(p.x)))
	var s := smoothstep(-_cur_bz, _cur_bz, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


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


# ------------------------------------------------------------------ parti p yardımcıları
## Üst kenarı açıya göre inen kapalı giysi (önlük, yelek): alt uç içe döner, astar yukarı çıkar. skinf(p) kemik listesi
static func _shell2(k, keys: Array, ytop: Callable, hem: float, ny: int, na: int, foldf: Callable, colf: Callable, skinf: Callable, th := 0.006, in_f := 0.25) -> Array:
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
	var all: Array = rows.duplicate()
	var src := []
	for j in ny + 1:
		src.append(j)
	var roll := []
	for p: Vector3 in rows[ny]:
		roll.append(p - Vector3(p.x, 0.0, p.z).normalized() * th * 0.5 + Vector3(0, -th * 0.6, 0))
	all.append(roll)
	src.append(ny)
	var stop := int(round(float(ny) * (1.0 - in_f)))
	for j in range(ny, stop - 1, -1):
		var ro := []
		for p: Vector3 in rows[j]:
			ro.append(p - Vector3(p.x, 0.0, p.z).normalized() * th)
		all.append(ro)
		src.append(j)
	k.grid(all, true, func(i, j, p): return (colf.call(TAU * i / na - PI, p.y) as Color).darkened(0.2 if j > ny else 0.0), func(_i, _j, p): return skinf.call(p))
	return rows


## Küçük yuvarlak top (düğme başı, magatama başı)
static func _blob(k, c: Vector3, r: float, col: Color, bones: Array, up := Vector3.UP) -> void:
	var pts := []
	for j in 7:
		pts.append(c + up * lerpf(-r, r, float(j) / 6.0))
	_tb(k, pts, func(s, _a): return r * sqrt(maxf(0.03, 1.0 - pow(2.0 * float(s) - 1.0, 2.0))), func(_s, a, _p): return col.darkened(0.18) if cos(float(a)) < -0.4 else col, func(_s, _p): return bones, 10)


## Klasik kalp eğrisi (yarıçap çarpanı, üstte çentik, altta sivri uç)
static func _heart_r(th: float) -> float:
	var s := sin(th)
	return clampf((2.0 - 2.0 * s + s * sqrt(absf(cos(th))) / (s + 1.4)) / 3.2, 0.05, 1.3)


## Elips yarıçap çarpanı (fan diskleri için): ax yatay, ay dikey
static func _ell(th: float, ax: float, ay: float) -> float:
	return 1.0 / sqrt(pow(cos(th) / ax, 2.0) + pow(sin(th) / ay, 2.0))


# ------------------------------------------------------------------ ANBU Wakate (ref Shinobi Striker "Anbu Outfit Itachi Ver."): boğazı kıvrımlı kısa kollu mor üst, düz kesik gri plaka + ince askı ve toka, kısa siyah kolluk + kısa plaka, bol pantolon, beyaz baldır sargısı
static func _wakate(k) -> void:
	var pu := Color(0.18, 0.15, 0.24)
	var pn := Color(0.2, 0.17, 0.27)
	var pl := Color(0.72, 0.7, 0.76)
	var bk := Color(0.1, 0.1, 0.12)
	var wr := Color(0.9, 0.89, 0.86)
	var mk := Color(0.4, 0.3, 0.5)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return pu)
	_seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		_lt(k, ar, func(_s, _a): return 0.0, func(_s, _a, _i): return sk, 0.2, kn + 0.14, 18, 16)
		_sleeve(k, ar, pu, 0.015, kn * 0.62, 0.9 + (0.7 if sd == "Left" else 0.0), 0.0, 0.009)
		_cuff(k, ar, kn * 0.62 - 0.03, kn * 0.62, 0.019, pu.darkened(0.12))
		# kısa kolluk: dirsek altından bileğe siyah sargı, dış yanda kısa plaka, iki bağ
		var wf := func(s: float, a: float) -> float: return 0.0055 + 0.0016 * sin(s * 140.0 + a * 0.6)
		_lt(k, ar, wf, func(s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.07 if sin(float(s) * 140.0 + float(a) * 0.6) > 0.3 else 0.0), kn + 0.11, 0.975, 28, 18)
		_guard(k, ar, kn + 0.2, 0.9, 0.95, 0.0125, pl.darkened(0.05))
		for s in [kn + 0.235, 0.865]:
			k.wrap_turn(_lp(ar, s), _ld(ar, s), _lr(ar, s) + 0.0145, 0.0075, 0.0, pu.darkened(0.25), _lskin(ar, s))
		_cuff(k, ar, 0.95, 0.995, 0.0095, bk.lightened(0.08))
		_pant(k, le, pn, 0.015, 0.028, 0.8, 0.022, 1.4 + (0.9 if sd == "Left" else 0.0))
		_shin(k, le, 0.78, 10, wr)
	# boğazlık: boyunda kıvrım kıvrım toplanan bol kumaş
	var hq := _hq(k)
	var tk := [[N + 0.072 * hq, nk.x + 0.03, nk.y + 0.034, nk.z - 0.034], [N + 0.038 * hq, nk.x + 0.026, nk.y + 0.03, nk.z - 0.03], [N - 0.005, nk.x + 0.034, nk.y + 0.038, nk.z - 0.038], [N - 0.06, ch.x * 0.8, ch.y * 0.84, ch.z * 0.93]]
	var tf := func(a: float, y: float, _u: float) -> float:
		return 0.11 * (0.5 + 0.5 * sin((y - N) * 105.0 + sin(a * 3.0 + 0.4) * 1.3)) * smoothstep(N - 0.02, N + 0.015, y)
	var nkf := func(p: Vector3) -> Array: return [["Neck", 0.6], ["UpperChest", 0.4]] if p.y > N else k.torso_skin(p.y)
	var tr: Array = _sheet(k, tk, 20, 48, Callable(), tf, func(a, y, _u, _v, _p): return _fs(pu, float(tf.call(a, y, 0.0)) - 0.055, 3.0), 0.007, 1.0, nkf)
	_tb(k, tr[0], func(_s, _a): return 0.0065, func(_s, _a, _p): return pu.lightened(0.06), func(_s, _p): return [["Neck", 0.6], ["UpperChest", 0.4]], 6, true)
	# plaka: göğüste düz kesik üst kenar, kol altında iner, belde kalın rulo
	var hem: float = H + 0.045
	var keys := [[N - 0.05, ch.x * 0.7, ch.y * 0.94, ch.z * 0.98], [N - 0.13, ch.x * 0.88, ch.y + 0.016, ch.z - 0.016], _kp(ch, C - 0.03, 0.028), _kp(wa, H + 0.12, 0.03), _kp(wa, hem, 0.036)]
	var y_top: float = N - 0.112
	var ytop := func(a: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return y_top - 0.105 * smoothstep(0.78, 1.22, aa) * (1.0 - smoothstep(1.92, 2.36, aa))
	var groove := func(a: float, y: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return -0.02 * exp(-pow(aa / 0.022, 2.0)) * smoothstep(H + 0.1, H + 0.12, y) - 0.022 * exp(-pow((y - (H + 0.1)) / 0.007, 2.0)) - 0.01 * exp(-pow((aa - PI) / 0.03, 2.0))
	var rows: Array = _shell(k, keys, ytop, hem, 32, 96, groove, func(a, y): return _fs(pl, groove.call(a, y), 7.0))
	_cur_hem = hem
	_rim(k, rows[0] + [rows[0][0]], 0.0058, pl.darkened(0.2), 8)
	var wst: Array = _ring_pts(keys, hem + 0.012, 0.014, 84)
	_tb(k, wst, func(_s, a): return 0.021 * (0.8 + 0.2 * absf(cos(a))), func(_s, a, _p): return pl.darkened(0.06 if cos(a) > -0.3 else 0.24), func(_s, p): return k.torso_skin(p.y), 10, true)
	# işaret: plakanın sol altında mor girdap
	_spiral_on(k, keys, ch.x * 0.48, H + 0.165, 0.03, true, 0.0045, 0.004, mk)
	# ince askılar + toka
	var ak := [_kp(nk, N + 0.014, 0.018), [N - 0.045, ch.x * 0.72, ch.y * 0.94, ch.z * 1.0], [N - 0.13, ch.x * 0.87, ch.y + 0.02, ch.z - 0.02], _kp(ch, C - 0.04, 0.03)]
	for sg in [1.0, -1.0]:
		var sx: float = sg * ch.x * 0.56
		_over(k, ak, sx, y_top + 0.004, y_top + 0.004, 0.0125, 0.0035, 0.0045, pl.darkened(0.14))
		for fr in [true, false]:
			var e: Array = _fp(ak, sx, y_top + 0.002, fr, 0.011)
			_boxr(k, e[0], Vector3(0.017, 0, 0), Vector3(0, 0.011, 0), (e[1] as Vector3) * 0.0045, pl.lightened(0.08), k.torso_skin(y_top))
			var e2: Array = _fp(ak, sx, y_top + 0.002, fr, 0.0158)
			_boxr(k, e2[0], Vector3(0.0085, 0, 0), Vector3(0, 0.0045, 0), (e2[1] as Vector3) * 0.0015, pl.darkened(0.35), k.torso_skin(y_top))


# ------------------------------------------------------------------ ANBU Kasumi (ref Shinobi Striker "Anbu Outfit Kakashi Ver."): kolsuz koyu mor, deniz yeşili atkı, geniş askılı plaka + çift rulo etek, kol üstüne çıkan ısıtıcı + beyaz bant + uzun plaka, arkadan sarkan peştamal, boğumlu baldır bantları
static func _kasumi(k) -> void:
	var pu := Color(0.13, 0.11, 0.18)
	var pn := Color(0.16, 0.14, 0.22)
	var pl := Color(0.72, 0.7, 0.76)
	var tl := Color(0.2, 0.42, 0.45)
	var wr := Color(0.92, 0.92, 0.9)
	var red := Color(0.74, 0.16, 0.13)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return pu)
	_seat(k, b, pn)
	_collar(k, nk, N, 0.06, 0.01, 0.022, 0.02, pu, 0.0)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		var lk: float = le["kn"]
		_lt(k, ar, func(_s, _a): return 0.0, func(_s, _a, _i): return sk, 0.0, 0.36, 20, 16)
		_cap(k, ar, sk, 0.0)
		# ısıtıcı: üst koldan bileğe, dirsekte kırışık
		var hf := func(s: float, a: float) -> float:
			return 0.0055 + 0.0035 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 40.0) + 0.0012 * sin(a * 2.0 + s * 23.0)
		_lt(k, ar, hf, func(s, a, ins): return pu.darkened(0.35) if ins else _fs(pu.lightened(0.04), float(hf.call(s, a)) - 0.0055, 40.0), 0.3, 1.0, 34, 18, 0.03)
		_cuff(k, ar, 0.3, 0.34, 0.0085, pu.lightened(0.06))
		k.wrap_turn(_lp(ar, 0.375), _ld(ar, 0.375), _lr(ar, 0.375) + 0.009, 0.016, 0.003, wr, _lskin(ar, 0.375))
		_guard(k, ar, kn + 0.05, 0.93, 1.02, 0.0155, pl.darkened(0.03))
		for s in [kn + 0.09, kn + 0.25, 0.9]:
			k.wrap_turn(_lp(ar, s), _ld(ar, s), _lr(ar, s) + 0.0175, 0.0068, 0.0, pu.darkened(0.2), _lskin(ar, s))
		_cuff(k, ar, 0.95, 0.995, 0.0095, pu.lightened(0.08))
		if sd == "Left":
			_arm_spiral(k, ar, 0.17, 0.03, 0.0015, red)
		# pantolon düz, baldırda boğum boğum bantlar
		_pant(k, le, pn, 0.012, 0.012, lk + 0.13, 0.008, 2.0 + (0.8 if sd == "Left" else 0.0))
		_lt(k, le, func(_s, _a): return 0.006, func(_s, _a, ins): return pu.darkened(0.3) if ins else pu.darkened(0.12), lk + 0.1, 1.0, 14, 18)
		for i in 5:
			var s: float = lerpf(lk + 0.14, 0.95, float(i) / 4.0)
			k.wrap_turn(_lp(le, s), _ld(le, s), _lr(le, s) + 0.0145, 0.022, 0.0, pu.lightened(0.05), _lskin(le, s))
	# plaka: hafif oyuk boyun, kol altı açık, altta iki katlı rulo
	var hem: float = H + 0.06
	var keys := [[N - 0.05, ch.x * 0.68, ch.y * 0.93, ch.z * 0.98], [N - 0.13, ch.x * 0.86, ch.y + 0.014, ch.z - 0.014], _kp(ch, C - 0.03, 0.03), _kp(wa, H + 0.12, 0.03), _kp(wa, hem, 0.034)]
	var y_top: float = N - 0.092
	var ytop := func(a: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return y_top - 0.022 * exp(-pow(aa / 0.4, 2.0)) - 0.11 * exp(-pow((aa - PI * 0.5) / 0.55, 2.0))
	var groove := func(a: float, y: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return -0.018 * exp(-pow(aa / 0.02, 2.0)) - 0.014 * exp(-pow((aa - 1.62) / 0.05, 2.0))
	var rows: Array = _shell(k, keys, ytop, hem, 30, 96, groove, func(a, y): return _fs(pl, groove.call(a, y), 8.0))
	_cur_hem = hem
	_rim(k, rows[0] + [rows[0][0]], 0.0062, pl.darkened(0.2), 8)
	for i in 2:
		var wst: Array = _ring_pts(keys, hem + 0.006 - float(i) * 0.03, 0.016 + float(i) * 0.004, 84)
		_tb(k, wst, func(_s, a): return 0.0165 * (0.82 + 0.18 * absf(cos(a))), func(_s, a, _p): return pl.darkened((0.04 if cos(a) > -0.3 else 0.24) + 0.06 * float(i)), func(_s, p): return k.torso_skin(p.y), 10, true)
	# geniş askılar, iki delikli toka
	var ak := [_kp(nk, N + 0.014, 0.018), [N - 0.045, ch.x * 0.72, ch.y * 0.94, ch.z * 1.0], [N - 0.13, ch.x * 0.87, ch.y + 0.018, ch.z - 0.018], _kp(ch, C - 0.04, 0.03)]
	for sg in [1.0, -1.0]:
		var sx: float = sg * ch.x * 0.52
		_over(k, ak, sx, y_top - 0.01, y_top - 0.01, 0.026, 0.004, 0.0055, pl.darkened(0.08))
		for fr in [true, false]:
			var e: Array = _fp(ak, sx, y_top - 0.016, fr, 0.0125)
			_boxr(k, e[0], Vector3(0.024, 0, 0), Vector3(0, 0.009, 0), (e[1] as Vector3) * 0.004, pu.lightened(0.18), k.torso_skin(y_top))
			for dx in [-0.009, 0.009]:
				var e2: Array = _fp(ak, sx + dx, y_top - 0.016, fr, 0.0168)
				_fan(k, e2[0], e2[1], Vector3.UP, 0.0035, Callable(), func(_u, _v): return pl.lightened(0.15), k.torso_skin(y_top), 1, 8)
	# kemer: peştamal bunun altından sarkar
	var bk2 := [_kp(hp, H + 0.02, 0.032), _kp(hp, H - 0.03, 0.032)]
	_band(k, bk2, H - 0.004, 0.016, 0.004, func(a, v): return pu.lightened(0.1).darkened(0.25 if v < 0.15 or v > 0.85 else 0.0), 0.003, 4, 72)
	# peştamal: belin arkasından iki bacak arasına sarkan deniz yeşili bez
	_cur_leg = 0.4
	var pk := [_kp(hp, H + 0.005, 0.036), _kp(hp, H - 0.07, 0.04), [K + 0.03, hp.x * 0.7, hp.y + 0.02, hp.z - 0.06]]
	var pr := func(y: float) -> Vector2:
		var t: float = clampf((H - y) / (H - K), 0.0, 1.0)
		var w: float = lerpf(0.5, 0.36, t)
		return Vector2(PI - w, PI + w)
	var pf := func(a: float, y: float, _u: float) -> float:
		return clampf((H - y) / (H - K), 0.0, 1.0) * (0.03 * sin(a * 11.0 + 0.6) + 0.012 * sin(a * 19.0 + 1.7))
	var prow: Array = _sheet(k, pk, 24, 28, pr, pf, func(a, y, _u, v, _p): return _fs(tl, float(pf.call(a, y, 0.0)), 7.0).darkened(0.18 if float(v) > 0.96 else 0.0), 0.006)
	var pe := _edges(prow)
	_rim(k, pe[0], 0.004, tl.darkened(0.12), 6)
	_rim(k, pe[1], 0.004, tl.darkened(0.12), 6)
	_cur_leg = 0.58
	_cur_hem = hem
	# atkı: boyunda üç kalın tur, önde toplanır; bir ucu sırtta plakanın üstüne yatar
	var sck := [_kp(nk, N + 0.09, 0.02), _kp(nk, N - 0.02, 0.03), [N - 0.07, ch.x * 0.74, ch.y * 0.82, ch.z * 0.9]]
	for t in [[N + 0.058, 0.016, 0.03, 0.4], [N + 0.018, 0.026, 0.038, 2.1], [N - 0.024, 0.044, 0.044, 3.7]]:
		var y_t: float = t[0]
		var add: float = t[1]
		var R: float = t[2]
		var ph: float = t[3]
		var pts := []
		var st: Array = SE.El.key_at(sck, y_t)
		for i in 44:
			var a: float = TAU * i / 44.0 - PI
			var q: Vector2 = SE.El.sup(a, float(st[1]) + add, float(st[2]) + add + 0.006 * maxf(0.0, cos(a)), float(st[3]) - add, 2.0)
			pts.append(Vector3(q.x, y_t - 0.01 * (1.0 + cos(a)) + 0.005 * sin(a * 3.0 + ph), q.y))
		var rf := func(s: float, a: float) -> float:
			return R * (1.0 + 0.12 * sin(s * TAU * 3.0 + ph) + 0.09 * sin(a * 2.0 + s * TAU * 5.0))
		_tb(k, pts, rf, func(s, a, _p): return _fs(tl, 0.12 * sin(float(s) * TAU * 3.0 + ph) + 0.09 * sin(float(a) * 2.0 + float(s) * TAU * 5.0), 1.0), func(_s, _p): return [["Neck", 0.4], ["UpperChest", 0.6]], 12, true)
	_strap(k, keys, [Vector2(-ch.x * 0.22, y_top - 0.004), Vector2(-ch.x * 0.27, C - 0.04), Vector2(-ch.x * 0.24, C - 0.1)], false, 0.032, 0.012, 0.007, tl.darkened(0.04), 6)


# ------------------------------------------------------------------ ANBU Byakue (ref Shinobi Striker "Anbu Outfit (Coat Ver.)"): diz altına inen önü kapalı beyaz palto, omuza dökülen bol yaka, geniş düz kollar, siyah boğazlık, koyu pantolon + koyu sargı
static func _byakue(k) -> void:
	var wh := Color(0.9, 0.88, 0.84)
	var bk := Color(0.08, 0.08, 0.1)
	var pn := Color(0.12, 0.12, 0.18)
	var wr := Color(0.17, 0.16, 0.25)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner(k, b, func(_i, _j, _p): return bk)
	_seat(k, b, pn)
	# siyah boğazlık: kısa, paltonun bol yakası içinde kalır (sırtta paltoyu delmez)
	var hq0 := _hq(k)
	var tnk := [_kp(nk, N + 0.068 * hq0, 0.011, 0.013), _kp(nk, N + 0.02, 0.015), _kp(nk, N - 0.03, 0.022)]
	var tnr: Array = _sheet(k, tnk, 8, 40, Callable(), func(a, y, _u): return 0.03 * sin(a * 4.0 + y * 60.0), func(_a, _y, _u, _v, _p): return bk, 0.0, 1.0, func(p): return [["Neck", 0.6], ["UpperChest", 0.4]] if p.y > N else k.torso_skin(p.y))
	_tb(k, tnr[0], func(_s, _a): return 0.005, func(_s, _a, _p): return bk.lightened(0.06), func(_s, _p): return [["Neck", 0.6], ["UpperChest", 0.4]], 6, true)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		var lk: float = le["kn"]
		var sg: float = ar["sg"]
		_lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, _i): return bk, 0.6, 1.0, 12, 14)
		var sl := func(s: float, a: float) -> float:
			var t := smoothstep(0.1, 0.92, s)
			return 0.02 + 0.03 * t + 0.022 * t * pow(maxf(0.0, -sin(a) * sg), 2.0) + 0.006 * _lf(s, a, 2.6) + 0.008 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + 1.0)
		_lt(k, ar, sl, func(s, a, ins): return wh.darkened(0.3) if ins else _fs(wh, 0.006 * _lf(float(s), float(a), 2.6) + 0.008 * exp(-pow((float(s) - kn) / 0.06, 2.0)) * sin(float(a) * 3.0 + 1.0), 14.0), 0.0, 0.94, 36, 24, 0.12)
		_cap(k, ar, wh, 0.02)
		_pant(k, le, pn, 0.012, 0.014, lk + 0.07, 0.01, 1.1 + (0.7 if sd == "Left" else 0.0))
		_lt(k, le, func(_s, _a): return 0.006, func(_s, _a, _i): return wr.darkened(0.25), lk + 0.05, 1.0, 14, 18)
		for i in 13:
			var s: float = lerpf(lk + 0.08, 0.965, float(i) / 12.0)
			k.wrap_turn(_lp(le, s), _ld(le, s), _lr(le, s) + 0.011, 0.0115, 0.028 * sg, wr.darkened(0.07 * float(i % 3)), _lskin(le, s))
	# palto: önü kapalı, diz altına iner, eteği hafif açılır
	var hem: float = K - 0.07
	_cur_leg = 1.0
	_cur_ramp = 0.5
	_cur_bz = 0.04
	_cur_side = 0.0
	var keys := [_kp(nk, N + 0.0, 0.038), [N - 0.055, ch.x * 1.02, ch.y * 0.97, ch.z * 1.06], _kp(ch, C - 0.03, 0.038), _kp(wa, H + 0.12, 0.046), _kp(hp, H - 0.04, 0.052), [K + 0.12, hp.x + 0.085, hp.y + 0.09, hp.z - 0.1], [hem, hp.x + 0.12, hp.y + 0.12, hp.z - 0.14]]
	var cf := func(a: float, y: float, _u: float) -> float:
		var t: float = clampf((H + 0.04 - y) / (H + 0.04 - hem), 0.0, 1.0)
		var aa: float = absf(wrapf(a, -PI, PI))
		var pin: float = 1.0 - exp(-pow(aa / 0.12, 2.0))
		return t * t * (0.036 * sin(a * 6.0 + 0.9) + 0.016 * sin(a * 11.0 + 2.3)) * pin + 0.006 * sin(a * 4.0 + y * 12.0) * (1.0 - t)
	var ro: Array = _sheet(k, keys, 52, 92, Callable(), cf, func(a, y, _u, v, _p):
		var c0: Color = _fs(wh, float(cf.call(a, y, 0.0)), 5.0)
		return c0.darkened(0.08) if float(v) > 0.97 else c0, 0.007, 0.3)
	_cur_hem = hem
	var hm := []
	var ho := []
	for p: Vector3 in ro[ro.size() - 1]:
		hm.append(p + Vector3(0, 0.01, 0))
		ho.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(hm, ho, 0.0095, 0.003, wh.darkened(0.06), true, func(p): return _hs(k, p))
	_cur_hem = hem
	# ön kapanış dikişi + arka orta dikiş
	_strap(k, keys, [Vector2(0.0, N - 0.04), Vector2(0.0, hem + 0.02)], true, 0.0045, 0.0035, 0.0022, wh.darkened(0.22), 40)
	_strap(k, keys, [Vector2(0.0, N - 0.05), Vector2(0.0, hem + 0.02)], false, 0.0035, 0.0025, 0.0015, wh.darkened(0.12), 40)
	for sgx in [1.0, -1.0]:
		_strap(k, keys, [Vector2(sgx * wa.x * 0.6, H + 0.05), Vector2(sgx * wa.x * 0.82, H - 0.09)], true, 0.0035, 0.004, 0.002, wh.darkened(0.2), 10)
	_cur_leg = 0.58
	_cur_ramp = 1.0
	_cur_bz = 0.075
	_cur_side = 0.0
	# bol yaka: boynu saran, omuza dökülen kalın kat
	var hq := _hq(k)
	var ck := [[N + 0.042 * hq, nk.x + 0.085, nk.y + 0.085, nk.z - 0.09], [N + 0.022 * hq, nk.x + 0.072, nk.y + 0.074, nk.z - 0.082], [N - 0.012, nk.x + 0.08, nk.y + 0.078, nk.z - 0.086], [N - 0.062, ch.x * 1.06, ch.y * 1.0 + 0.014, ch.z * 1.08 - 0.016]]
	var kf := func(a: float, y: float, _u: float) -> float:
		var up: float = smoothstep(N - 0.05, N + 0.03, y)
		return up * (0.075 * sin(a * 5.0 + 0.4) + 0.035 * sin(a * 9.0 + 1.5) - 0.06 * exp(-pow(wrapf(a, -PI, PI) / 0.28, 2.0)))
	var nkf := func(p: Vector3) -> Array: return [["Neck", 0.45], ["UpperChest", 0.55]] if p.y > N else k.torso_skin(p.y)
	var cr: Array = _sheet(k, ck, 18, 72, Callable(), kf, func(a, y, _u, _v, _p): return _fs(wh, float(kf.call(a, y, 0.0)), 3.0), 0.0, 1.0, nkf)
	_tb(k, cr[0], func(s, _a): return 0.016 + 0.006 * sin(float(s) * TAU * 5.0 + 0.4), func(_s, a, _p): return wh.darkened(0.12) if cos(float(a)) < -0.3 else wh, func(_s, _p): return [["Neck", 0.45], ["UpperChest", 0.55]], 10, true)
	_cur_hem = hem


# ------------------------------------------------------------------ Taiyō Kimono (ref Shinobi Striker "15-Million User Celebration Outfits"): turuncu dik yakalı tulum, sol omuzdan sağ bele çapraz turuncu kimono, sağ yarısı bele düşmüş, güneş arması, siyah obi + 9 parlak magatama, kızıl bez, bol pantolon
static func _gunesi(k) -> void:
	var og := Color(0.91, 0.5, 0.1)
	var pa := Color(0.878, 0.604, 0.157)
	var ki := Color(0.91, 0.663, 0.235)
	var tr := Color(0.847, 0.29, 0.078)
	var bk := Color(0.1, 0.09, 0.1)
	var yl := Color(1.0, 0.87, 0.32)
	var rd := Color(0.784, 0.188, 0.165)
	var wh := Color(0.97, 0.95, 0.9)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var ik: Array = _inner(k, b, func(_i, _j, _p): return og)
	_seat(k, b, pa)
	_collar(k, nk, N, 0.07, 0.016, 0.03, 0.1, og, 0.007)
	_strap(k, ik, [Vector2(0.0, N - 0.02), Vector2(0.0, C - 0.06)], true, 0.0035, 0.004, 0.002, og.darkened(0.35), 12)
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		var sg: float = ar["sg"]
		_lt(k, ar, func(_s, _a): return 0.0, func(_s, _a, _i): return sk, kn * 0.6, 1.0, 22, 16)
		_sleeve(k, ar, og, 0.014, kn * 0.74, 1.2 + (0.8 if sd == "Left" else 0.0), 0.0, 0.008)
		_cuff(k, ar, kn * 0.74 - 0.03, kn * 0.74, 0.018, og.darkened(0.12))
		if sd == "Left":   # kimononun tek giyilen kolu: geniş, alt yanı sarkık, kenarı desenli
			var kl := func(s: float, a: float) -> float:
				var t := smoothstep(0.05, 0.5, s)
				return 0.024 + 0.024 * t + 0.03 * t * pow(maxf(0.0, -sin(a) * sg), 2.0) + 0.006 * _lf(s, a, 3.3)
			_lt(k, ar, kl, func(s, a, ins): return ki.darkened(0.35) if ins else _fs(ki, 0.006 * _lf(float(s), float(a), 3.3), 16.0), 0.0, kn * 0.82, 26, 24, 0.1)
			_ring_on(k, ar, kn * 0.82 - 0.012, kl, 0.011, tr)
		else:   # sağ omuzda beyaz bağ düğümü
			var e0: Vector3 = _lp(ar, 0.08) + Vector3(0, _lr(ar, 0.08) + 0.012, 0)
			_blob(k, e0, 0.017, wh, [["UpperChest", 0.6], [sd + "UpperArm", 0.4]])
			_ring_on(k, ar, 0.1, func(_s, _a): return 0.014, 0.008, wh)
			for dz in [-1.0, 1.0]:
				var tail := [e0 + Vector3(0.0, -0.004, 0.008 * dz), e0 + Vector3(-0.012, -0.03, 0.02 * dz), e0 + Vector3(-0.016, -0.05, 0.022 * dz)]
				_tb(k, tail, func(s, _a): return 0.0085 * (1.0 - 0.6 * float(s)), func(_s, _a, _p): return wh.darkened(0.06), func(_s, _p): return [["UpperChest", 0.6], [sd + "UpperArm", 0.4]], 8)
		# bol pantolon: baldırda toplanır, altı dar
		_pant(k, le, pa, 0.022, 0.06, 0.8, 0.036, 2.2 + (0.9 if sd == "Left" else 0.0))
		_cuff(k, le, 0.795, 0.83, 0.017, pa.darkened(0.1), 18)
	# kimono üstü: sol omuzdan sağ bele çapraz
	var by: float = H + 0.06
	var uk := [_kp(nk, N + 0.008, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], _kp(ch, C - 0.03, 0.032), _kp(wa, by + 0.04, 0.036), _kp(wa, by - 0.03, 0.034)]
	var y0: float = N + 0.008
	var y1: float = by - 0.03
	var ur := func(y: float) -> Vector2:
		var t: float = pow(clampf((y0 - y) / (y0 - y1), 0.0, 1.0), 0.75)
		return Vector2(lerpf(0.32, -1.3, t), lerpf(PI - 0.3, PI + 1.3, t))
	var uf := func(a: float, y: float, u: float) -> float:
		var s: float = clampf((y - y1) / (y0 - y1), 0.0, 1.0)
		return 0.016 * sin(a * 5.0 + y * 16.0) * (1.0 - s) + 0.01 * sin(a * 9.0 - y * 22.0) + 0.02 * smoothstep(0.92, 1.0, u)
	var urow: Array = _sheet(k, uk, 36, 80, ur, uf, func(a, y, _u, _v, _p): return _fs(ki, float(uf.call(a, y, 0.5)), 6.0), 0.006, 0.15)
	_cur_hem = by
	var ue := _edges(urow)
	for e in ue:
		var ou := []
		for p: Vector3 in e:
			ou.append(Vector3(p.x, 0.15, p.z).normalized())
		k.strip(e, ou, 0.02, 0.0055, tr, false, func(p): return k.torso_skin(p.y))
		var e2 := []
		for i in (e as Array).size():
			e2.append((e[i] as Vector3) + (ou[i] as Vector3) * 0.0055)
		k.strip(e2, ou, 0.0045, 0.0018, yl.darkened(0.12), false, func(p): return k.torso_skin(p.y))
	# güneş arması: kızıl ışınlar, beyaz disk
	var sx: float = ch.x * 0.18
	var sy: float = C - 0.06
	_fan_on(k, uk, sx, sy, true, 0.1, func(th): return 0.5 + 0.5 * pow(absf(cos(float(th) * 5.0 + 0.3)), 3.0) * (0.75 + 0.25 * cos(float(th) - PI)), func(_u, _v): return tr, 0.004, 5, 60, func(p): return k.torso_skin(p.y))
	_fan_on(k, uk, sx, sy, true, 0.046, Callable(), func(u, v): return wh.darkened(0.08) if sqrt(float(u) * float(u) + float(v) * float(v)) > 0.86 else wh, 0.0065, 5, 36, func(p): return k.torso_skin(p.y))
	# alt etek: obi altından dize, önü açık, kat kat
	var hem: float = K + 0.05
	_cur_leg = 0.62
	var skk := [_kp(wa, by + 0.01, 0.036), _kp(hp, H - 0.04, 0.05), [K + 0.2, hp.x + 0.095, hp.y + 0.075, hp.z - 0.085], [hem, hp.x + 0.12, hp.y + 0.09, hp.z - 0.1]]
	var srg := func(y: float) -> Vector2:
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		var e: float = lerpf(0.16, 0.5, t)
		return Vector2(e, TAU - e)
	var sf := func(a: float, y: float, _u: float) -> float:
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		return 0.02 * sin(a * 14.0 + 0.4) * (1.0 - t) + t * (0.05 * sin(a * 7.0 + 0.6) + 0.022 * sin(a * 12.0 + 1.9))
	var srow: Array = _sheet(k, skk, 32, 84, srg, sf, func(a, y, _u, _v, _p): return _fs(ki, float(sf.call(a, y, 0.0)), 5.0), 0.007)
	var se := _edges(srow)
	for e in se:
		_rim(k, e, 0.0075, tr, 6)
	var hr := []
	var hro := []
	for p: Vector3 in srow[srow.size() - 1]:
		hr.append(p + Vector3(0, 0.012, 0))
		hro.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(hr, hro, 0.012, 0.0045, tr, false, func(p): return _hs(k, p))
	# sağ bele düşmüş yarı: belde kalın rulo + sarkan boş kol
	var roll := []
	for i in 25:
		var a: float = lerpf(-0.35, -2.75, float(i) / 24.0)
		roll.append(_sa(skk, a, by - 0.012, 0.03)[0])
	_tb(k, roll, func(s, a): return 0.032 * (1.0 + 0.18 * sin(float(s) * TAU * 3.0 + float(a) * 2.0)) * (0.35 + 0.65 * pow(sin(float(s) * PI), 0.4)), func(s, a, _p): return _fs(ki, 0.18 * sin(float(s) * TAU * 3.0 + float(a) * 2.0) * 0.06, 6.0).darkened(0.15 if cos(float(a)) < -0.5 else 0.0), func(_s, p): return k.torso_skin(maxf(p.y, H + 0.01)), 12)
	var fk := [[by - 0.02, hp.x + 0.07, hp.y + 0.08, hp.z - 0.08], [H - 0.08, hp.x + 0.085, hp.y + 0.09, hp.z - 0.095], [K + 0.12, hp.x + 0.12, hp.y + 0.11, hp.z - 0.115]]
	var fr := func(y: float) -> Vector2:
		var t: float = clampf((by - y) / (by - K - 0.12), 0.0, 1.0)
		return Vector2(-PI * 0.5 - lerpf(0.55, 0.42, t), -PI * 0.5 + lerpf(0.55, 0.38, t))
	var ff := func(a: float, y: float, _u: float) -> float:
		return clampf((by - y) / (by - K), 0.0, 1.0) * (0.04 * sin(a * 9.0 + 1.2) + 0.015 * sin(a * 17.0))
	var frow: Array = _sheet(k, fk, 24, 30, fr, ff, func(a, y, _u, _v, _p): return _fs(ki.darkened(0.04), float(ff.call(a, y, 0.0)), 6.0), 0.006)
	k.strip(frow[frow.size() - 1].map(func(p): return (p as Vector3) + Vector3(0, 0.011, 0)), frow[frow.size() - 1].map(func(p): return Vector3(p.x, 0.0, p.z).normalized()), 0.011, 0.004, tr, false, func(p): return _hs(k, p))
	# kızıl bez: obiye sıkışmış, sağ uyluk önüne sarkar
	var rk := [[by - 0.02, hp.x + 0.085, hp.y + 0.1, hp.z - 0.09], [H - 0.1, hp.x + 0.1, hp.y + 0.105, hp.z - 0.1], [K + 0.1, hp.x + 0.115, hp.y + 0.115, hp.z - 0.11]]
	var rr := func(y: float) -> Vector2:
		var t: float = clampf((by - y) / (by - K - 0.1), 0.0, 1.0)
		return Vector2(-0.98 - lerpf(0.2, 0.3, t), -0.98 + lerpf(0.2, 0.26, t))
	var rf2 := func(a: float, y: float, _u: float) -> float:
		return clampf((by - y) / (by - K), 0.0, 1.0) * 0.05 * sin(a * 16.0 + 0.7) + 0.012 * sin(a * 23.0)
	_sheet(k, rk, 22, 22, rr, rf2, func(a, y, _u, v, _p): return _fs(rd, float(rf2.call(a, y, 0.0)), 5.0).darkened(0.15 if float(v) > 0.95 else 0.0), 0.006)
	_cur_leg = 0.58
	_cur_hem = hem
	# obi + arkada düğüm
	_band(k, uk, by, 0.042, 0.016, func(a, v): return bk.lightened(0.06).darkened(0.3 * float(absf(float(v) - 0.5) < 0.08 and sin(float(a) * 7.0) > -0.6)), 0.006, 8, 88)
	var kb: Array = _fp(uk, 0.0, by, false, 0.03)
	_boxr(k, kb[0], Vector3(0.06, 0, 0), Vector3(0, 0.032, 0), Vector3(0, 0, -0.022), bk.lightened(0.04), [["Hips", 1.0]], 0.45)
	# 9 parlak magatama: obinin alt kenarından eteğin önüne dizili
	for i in 9:
		var a: float = lerpf(-0.95, 0.95, float(i) / 8.0)
		var yy: float = by - 0.06 + 0.012 * pow(float(i - 4) / 4.0, 2.0)
		var e: Array = _sa(skk, a, yy, 0.016, sf)
		var c0: Vector3 = e[0]
		var ox: Vector3 = Vector3(cos(a), 0.0, -sin(a))
		var bo := [["Hips", 1.0]]
		_blob(k, c0, 0.012, yl, bo)
		var tail := [c0 + ox * 0.004 + Vector3(0, -0.006, 0), c0 + ox * 0.011 + Vector3(0, -0.018, 0), c0 + ox * 0.008 + Vector3(0, -0.03, 0), c0 + ox * -0.001 + Vector3(0, -0.036, 0)]
		_tb(k, tail, func(s, _a): return 0.0085 * (1.0 - 0.8 * float(s)) + 0.0012, func(_s, _a, _p): return yl.lightened(0.1), func(_s, _p): return bo, 8)
		var cd: Array = _sa(skk, a, by - 0.032, 0.012, sf)
		_tb(k, [cd[0], c0 + Vector3(0, 0.01, 0)], func(_s, _a): return 0.0022, func(_s, _a, _p): return bk, func(_s, _p): return bo, 5)


# ------------------------------------------------------------------ Iryō Shōzoku (ref Shinobi Striker "Adorable Striker" / "Adorable Springtime"): kısa kollu gömlek üstüne dik yakalı kolsuz önlük-elbise, ön panel biyesi, çift sıra düğme, yan kemer + arkada fiyonk, sırtta 医 / tavşan, diz üstü çorap
static func _hemsire(k, bahar: bool) -> void:
	var gw := Color(0.29, 0.667, 0.651) if bahar else Color(0.957, 0.957, 0.965)
	var tr := Color(0.941, 0.816, 0.251) if bahar else Color(0.63, 0.094, 0.133)
	var sh := Color(0.96, 0.96, 0.97) if bahar else Color(0.91, 0.72, 0.86)
	var bt := Color(0.95, 0.95, 0.94) if bahar else Color(0.69, 0.11, 0.133)
	var bu := Color(0.94, 0.94, 0.92) if bahar else Color(0.84, 0.85, 0.87)
	var cl := gw.darkened(0.25) if bahar else gw
	var sk := _skin_c(k)
	var stc := Color(0.97, 0.96, 0.97).lerp(sk, 0.16)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var ik: Array = _inner(k, b, func(_i, _j, _p): return sh)
	_seat(k, b, Color(0.95, 0.95, 0.95) if not bahar else gw.darkened(0.1))
	for sd in ["Left", "Right"]:
		var ar := _limb(k, sd, false)
		var le := _limb(k, sd, true)
		var kn: float = ar["kn"]
		var lk: float = le["kn"]
		# kol: bahar uzun beyaz gömlek kolu; hemşirede pembe kısa kol + beyaz kol örtüsü
		if bahar:
			_sleeve(k, ar, sh, 0.01, 0.9, 1.1 + (0.8 if sd == "Left" else 0.0), 0.0, 0.006)
		else:
			_lt(k, ar, func(s, a): return 0.004 + 0.001 * _lf(s, a, 1.4), func(s, a, ins): return Color(0.95, 0.95, 0.96).darkened(0.3) if ins else _fs(Color(0.95, 0.95, 0.96), 0.001 * _lf(float(s), float(a), 1.4), 30.0), kn * 0.3, 0.9, 30, 16)
			_sleeve(k, ar, sh, 0.011, kn * 0.46, 1.1 + (0.8 if sd == "Left" else 0.0), 0.0, 0.013)
			_cuff(k, ar, kn * 0.46 - 0.025, kn * 0.46, 0.017, sh.darkened(0.1))
		# manşet: geniş bant + ince şerit
		_cuff(k, ar, 0.86, 0.95, 0.013, gw if bahar else Color(0.95, 0.95, 0.96))
		_ring_on(k, ar, 0.945, func(_s, _a): return 0.013, 0.006, sh if bahar else tr)
		if bahar:   # kalpli manşet: kabarık beyaz kalpler
			var s_h: float = 0.905
			for j in 4:
				var e: Array = _ls(ar, s_h, TAU * float(j) / 4.0 + 0.4, 0.015)
				var dd: Vector3 = -_ld(ar, s_h)
				_fan(k, e[0], e[1], dd, 0.011, func(th): return _heart_r(float(th)), func(_u, _v): return Color(0.97, 0.97, 0.98), _lskin(ar, s_h), 2, 24)
		# bacak: kısa şort + çıplak uyluk + diz üstü çorap (bantlı üst, bilekte kıvrık)
		var s_top: float = lk - 0.1
		_lt(k, le, func(_s, _a): return 0.0, func(_s, _a, _i): return sk, 0.08, s_top + 0.02, 18, 18)
		_lt(k, le, func(_s, _a): return 0.008, func(_s, _a, ins): return Color(0.9, 0.9, 0.9) if ins else (Color(0.95, 0.95, 0.95) if not bahar else gw.darkened(0.1)), 0.0, 0.13, 8, 20)
		_lt(k, le, func(s, a): return 0.0025 + 0.0012 * sin(a * 3.0 + s * 30.0) * smoothstep(lk - 0.05, lk, s) * (1.0 - smoothstep(lk + 0.05, lk + 0.1, s)), func(s, a, ins): return stc.darkened(0.2) if ins else stc.darkened(0.06 * float(sin(float(a) * 3.0 + float(s) * 30.0) > 0.5)), s_top, 1.0, 34, 18)
		_cuff(k, le, s_top - 0.002, s_top + 0.035, 0.0075, Color(0.98, 0.98, 0.98), 0)
		for j in 2:
			var s: float = 0.905 + 0.035 * float(j)
			k.wrap_turn(_lp(le, s), _ld(le, s), _lr(le, s) + 0.009 - 0.002 * float(j), 0.014, 0.004, Color(0.98, 0.98, 0.98).darkened(0.05 * float(j)), _lskin(le, s))
	# sırt: hemşirede 医, baharda tavşan (önlüğün açık sırtında gömlek üstünde)
	var gy: float = C + 0.005
	if bahar:
		var rc := Color(0.24, 0.55, 0.54)
		_fan_on(k, ik, 0.0, gy - 0.03, false, 0.03, func(th): return _ell(float(th), 1.0, 0.78), func(_u, _v): return rc, 0.004, 4, 32, func(p): return k.torso_skin(p.y))
		_fan_on(k, ik, 0.0, gy + 0.012, false, 0.019, Callable(), func(_u, _v): return rc, 0.0055, 4, 28, func(p): return k.torso_skin(p.y))
		for sg in [1.0, -1.0]:
			_strap(k, ik, [Vector2(sg * 0.006, gy + 0.026), Vector2(sg * 0.016, gy + 0.072)], false, 0.0065, 0.0055, 0.0018, rc, 4, func(p): return k.torso_skin(p.y))
		_fan_on(k, ik, -0.026, gy - 0.05, false, 0.009, Callable(), func(_u, _v): return Color(0.97, 0.97, 0.98), 0.0065, 3, 20, func(p): return k.torso_skin(p.y))
	else:
		var G_I := [[-0.8, 0.82, 0.82, 0.82], [-0.8, 0.82, -0.8, -0.85], [-0.8, -0.85, 0.85, -0.85], [-0.32, 0.62, -0.5, 0.32], [-0.46, 0.42, 0.5, 0.42], [-0.58, 0.02, 0.62, 0.02], [0.04, 0.64, 0.0, 0.02], [0.0, 0.02, -0.5, -0.6], [0.05, -0.08, 0.56, -0.6]]
		_glyph(k, ik, 0.0, gy, 0.05, G_I, 0.0062, Color(0.78, 0.1, 0.13), false, 0.004)
	# önlük-elbise: önde boyna dek panel, kol yuvası açık, sırtta kürek altından başlar; A kesim etek
	var hem: float = H - 0.22
	var leg := 1.0
	var gk := [_kp(nk, N + 0.004, 0.022), [N - 0.055, ch.x * 0.93, ch.y * 0.95, ch.z * 1.03], _kp(ch, C - 0.03, 0.022), _kp(wa, H + 0.12, 0.02), _kp(wa, H + 0.05, 0.024), _kp(hp, H - 0.04, 0.034), [hem, hp.x + 0.085, hp.y + 0.07, hp.z - 0.08]]
	var y_back: float = C - 0.12
	var ytop := func(a: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		var arm: float = smoothstep(0.98, 1.4, aa)
		return lerpf(N + 0.004, C - 0.075, arm) + (y_back - (C - 0.075)) * smoothstep(1.85, 2.3, aa)
	var gf := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var aa: float = absf(wrapf(a, -PI, PI))
		var panel: float = 1.0 - exp(-pow(aa / 0.36, 2.0))
		return t * t * (0.028 * sin(a * 7.0 + 0.5) + 0.01 * sin(a * 13.0 + 1.3)) * (0.3 + 0.7 * panel) + 0.004 * sin(a * 5.0 + y * 20.0) * (1.0 - t)
	_cur_hem = hem
	_cur_leg = leg
	_cur_ramp = 0.6
	_cur_bz = 0.05
	_cur_side = 0.5
	var gskin := func(p: Vector3) -> Array: return _hs(k, p)
	var grow: Array = _shell2(k, gk, ytop, hem, 56, 92, gf, func(a, y): return _fs(gw, float(gf.call(a, y)), 7.0), gskin, 0.006, 0.25)
	_cur_hem = hem
	_cur_leg = leg
	# üst kenar biyesi (kol yuvası + sırt), etek ucu rulosu
	var top_e := []
	for p: Vector3 in grow[0]:
		top_e.append(p)
	top_e.append(grow[0][0])
	_rim(k, top_e, 0.0045, tr if bahar else gw.darkened(0.08), 6)
	var he: Array = (grow[grow.size() - 1] as Array).duplicate()
	he.append(he[0])
	_rim(k, he, 0.0055, gw.darkened(0.1), 6)
	# omuz askıları: ön panelden sırt kenarına
	var ak := [_kp(nk, N + 0.014, 0.024), [N - 0.045, ch.x * 0.74, ch.y * 0.95, ch.z * 1.02], [N - 0.13, ch.x * 0.9, ch.y + 0.024, ch.z - 0.024], _kp(ch, C - 0.04, 0.026)]
	for sg in [1.0, -1.0]:
		_over(k, ak, sg * ch.x * 0.56, N - 0.06, y_back + 0.004, 0.024, 0.003, 0.004, gw.darkened(0.03))
	# dik yaka: önde ince açıklık
	_collar(k, nk, N, 0.058, 0.014, 0.028, 0.13, cl, 0.0055)
	if bahar:
		for sg in [1.0, -1.0]:
			_strap(k, gk, [Vector2(sg * 0.02, N + 0.003), Vector2(sg * 0.034, N - 0.03)], true, 0.007, 0.012, 0.003, gw.darkened(0.42), 4)
	# ön panel biyesi: yaka ucundan omuz altına açılır, dik iner; sağ alt uçta kızıl astar görünür
	var px: float = ch.x * 0.5
	for sg in [1.0, -1.0]:
		var ctrl := [Vector2(0.0, N - 0.018), Vector2(sg * px * 0.4, N - 0.05), Vector2(sg * px, N - 0.09), Vector2(sg * px, C - 0.06), Vector2(sg * px * 1.02, H + 0.0), Vector2(sg * px * 1.06, hem + 0.008)]
		_strap(k, gk, ctrl, true, 0.0042, 0.0045, 0.0022, tr, 10)
	_strap(k, gk, [Vector2(0.0, N - 0.006), Vector2(0.0, N - 0.024)], true, 0.003, 0.0045, 0.002, tr, 3)
	if not bahar:
		_patch(k, gk, -px * 1.06 + 0.004, -px * 1.06 + 0.04, hem + 0.07, hem + 0.004, true, 0.0045, tr, 0.5, 6, 6)
	# çift sıra düğme
	var bx: float = px * 0.6
	var brow := [C - 0.005, C - 0.085, H + 0.07]
	for yb in brow:
		for sg in [1.0, -1.0]:
			_fan_on(k, gk, sg * bx, yb, true, 0.012, Callable(), func(u, v): return bu.darkened(0.2) if sqrt(float(u) * float(u) + float(v) * float(v)) > 0.8 else bu, 0.0055, 3, 20)
			_fan_on(k, gk, sg * bx, yb, true, 0.0065, Callable(), func(_u, _v): return bu.lightened(0.05), 0.0085, 2, 16)
	if bahar:   # düğmeler arası dalgalı dantel + damla süs, etek ucu dantel bandı
		for yb in brow:
			var wv := []
			for i in 13:
				var u := float(i) / 12.0
				wv.append(Vector2(lerpf(-bx + 0.012, bx - 0.012, u), float(yb) - 0.002 + 0.005 * sin(u * TAU * 2.0)))
			_strap(k, gk, wv, true, 0.0028, 0.005, 0.0016, Color(0.96, 0.97, 0.97), 2)
			for sg in [1.0, -1.0]:
				for j in 3:
					_fan_on(k, gk, sg * bx, float(yb) - 0.022 - 0.014 * float(j), true, 0.0032, Callable(), func(_u, _v): return Color(0.95, 0.96, 0.96), 0.0055, 1, 10)
		var lace := []
		var lo := []
		var ly: float = hem + 0.035
		for i in 121:
			var a := TAU * float(i) / 120.0 - PI
			var yy: float = ly + 0.006 * sin(a * 26.0)
			var s: Array = SE.El.key_at(gk, yy)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f := 1.0 + float(gf.call(a, yy))
			var p := Vector3(q.x * f, yy, q.y * f)
			var o := Vector3(p.x, 0.0, p.z).normalized()
			lace.append(p + o * 0.004)
			lo.append(o)
		k.strip(lace, lo, 0.0032, 0.0016, Color(0.96, 0.97, 0.97), true, func(p): return _hs(k, p))
	# yan kemer: önde panelin altına girer, arkada fiyonk
	var by: float = H + 0.07
	var bk := [_kp(wa, by + 0.03, 0.024), _kp(wa, by - 0.03, 0.026)]
	var brg := func(_y: float) -> Vector2: return Vector2(0.62, TAU - 0.62)
	_sheet(k, bk, 4, 60, brg, Callable(), func(_a, _y, _u, v, _p): return bt.darkened(0.12) if float(v) < 0.12 or float(v) > 0.88 else bt, 0.004, 1.0, func(p): return k.torso_skin(p.y))
	for sg in [1.0, -1.0]:   # kemer ucu tokası (panel kenarında)
		var e: Array = _fp(bk, sg * px * 1.12, by, true, 0.006)
		_boxr(k, e[0], Vector3(0.01, 0, 0), Vector3(0, 0.025, 0), (e[1] as Vector3) * 0.004, tr if bahar else bt.lightened(0.15), k.torso_skin(by))
	var kc: Array = _fp(bk, 0.0, by, false, 0.016)
	var kp: Vector3 = kc[0]
	_boxr(k, kp, Vector3(0.016, 0, 0), Vector3(0, 0.02, 0), Vector3(0, 0, -0.012), bt.darkened(0.08), [["Hips", 1.0]], 0.5)
	for sg in [1.0, -1.0]:
		var loop := []
		for j in 21:
			var a := TAU * j / 20.0
			loop.append(kp + Vector3(sg * (0.04 + 0.036 * cos(a + PI)), 0.022 * sin(a) + 0.006, -0.004 - 0.008 * (1.0 + cos(a + PI))))
		_tb(k, loop, func(_s, a): return 0.009 * (0.55 + 0.45 * absf(cos(float(a)))), func(_s, a, _p): return bt.darkened(0.16) if cos(float(a)) < -0.3 else bt, func(_s, _p): return [["Hips", 1.0]], 8, true)
		_strap(k, gk, [Vector2(sg * 0.008, by - 0.02), Vector2(sg * 0.026, H - 0.06), Vector2(sg * 0.032, H - 0.13)], false, 0.012, 0.009, 0.0035, bt.darkened(0.04), 8)
