extends RefCounted
## Elle modellenmiş setler, parti m: set_ame, set_ne, set_soryo, set_ronin, set_yuki_tabi, set_matsuri.
## Kumaş / uzuv yardımcıları parti e'den (P). Burada: sarmal kimono paneli, geniş / torba kol, sırt pelerini ağırlığı, kürk.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")

const DONE := ["set_ame", "set_ne", "set_soryo", "set_ronin", "set_yuki_tabi", "set_matsuri"]


static func recipe(k, sid: String) -> void:
	P._cur_long = false
	P._cur_leg = 0.58
	match sid:
		"set_ame": _ame(k)
		"set_ne": _ne(k)
		"set_soryo": _soryo(k)
		"set_ronin": _ronin(k)
		"set_yuki_tabi": _yuki(k)
		"set_matsuri": _matsuri(k)


# ------------------------------------------------------------------ yardımcılar
static func _seat(k, b: Dictionary, col: Color) -> void:
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = k.M(k.H + 0.05, 0.3)
	SE.body_layer(k, [P._kp(bl, k.H + 0.09, 0.006), P._kp(hp, k.H - 0.05, 0.016), [k.H - 0.15, hp.x * 0.76, hp.y * 0.78, hp.z * 0.78]], 8, 34, func(_i, _j, _p): return col)


static func _yl(pts: Array, up: float) -> Array:
	var o := []
	for p: Vector3 in pts:
		o.append(p + Vector3(0, up, 0))
	return o


## Kimono altı: boyna çıkmaz, V yakanın içinde ten görünür (beden yaka altında çizilmediği için ten burada modellenir)
static func _inner_v(k, b: Dictionary, under: Color) -> void:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var skin_c: Color = k.m.look["skin"]
	var yc: float = k.C - 0.12
	var keys := [P._kp(nk, k.N + 0.022, 0.002), P._kp(nk, k.N + 0.0, 0.008), [k.N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, k.C - 0.03, 0.006), P._kp(b["wa"], k.H + 0.12, 0.008), P._kp(b["hp"], k.H - 0.09, 0.01)]
	SE.body_layer(k, keys, 28, 44, func(_i: int, _j: int, p: Vector3) -> Color: return skin_c if p.y > yc else under)


## Pantolon: base bolluk, bag dizde şişkinlik, s1 paça. Dönen işlev üstüne binen sargı için yarıçap verir
static func _pants(k, le: Dictionary, col: Color, base: float, bag: float, s1: float, sd: float, calf := 0.0) -> Callable:
	var kn: float = le["kn"]
	var pa := func(s: float, a: float) -> float:
		var fo: float = 1.0 - smoothstep(kn + 0.1, kn + 0.26, s)
		var cr: float = exp(-pow((s - kn) / 0.075, 2.0)) * sin(a * 3.0 + s * 34.0 + sd)
		return base + bag * exp(-pow((s - kn + 0.1) / 0.17, 2.0)) - 0.006 * smoothstep(kn + 0.12, kn + 0.3, s) - calf * smoothstep(kn, kn + 0.12, s) + fo * 0.005 * P._lf(s, a, sd) + 0.0042 * cr
	P._lt(k, le, pa, func(s: float, a: float, ins: bool) -> Color:
		return col.darkened(0.42) if ins else P._fs(col, float(pa.call(s, a)) - base - bag * 0.4, 9.0), 0.0, s1, 38, 20)
	return pa


## Omuza binen kumaş: gövdeyle gider, yan kanatlar üst kolu izler
static func _arm_skin(k, p: Vector3, wd: float) -> Array:
	var ts: Array = k.torso_skin(maxf(p.y, k.H + 0.02))
	var sx: float = smoothstep(0.58, 0.98, absf(p.x) / wd) * smoothstep(k.N, k.C - 0.04, p.y) * 0.62
	if sx <= 0.0:
		return ts
	var res := []
	for e: Array in ts:
		res.append([e[0], float(e[1]) * (1.0 - sx)])
	res.append([("Left" if p.x > 0.0 else "Right") + "UpperArm", sx])
	return res


## Sırtta sarkan kumaş: ağırlık boy boyunca yavaş artar, iki bacak arasında geniş geçer; geri giden bacak kumaşı ezmez, kumaş uzayarak iner
static func _rear_skin(k, p: Vector3, hem: float, wd: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return _arm_skin(k, p, wd)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var w: float = 0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85))
	var s: float = smoothstep(-0.12, 0.12, p.x)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.16, p.y) * absf(2.0 * s - 1.0) * 0.5
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Sarmal giysi ağırlığı: iki kanat aynı noktada aynı ağırlığı alır (bindirme yürürken ayrılmaz, alttaki kanat üsttekini delmez). Etek bacakları izler, iki bacak arasında kumaş uzar;
## arkada geçiş dar: geri giden bacağın iç yanı kumaşı delmez. Uçta ağırlık biraz düşer: duruşta boy çan gibi açılmaz
static func _wrap_skin(k, p: Vector3, hem: float, _left: bool) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.07, p.z)
	var wf: float = 0.95 * pow(minf(1.0, t / 0.42), 0.45) * lerpf(1.0, 0.84, smoothstep(0.55, 1.0, t))
	var wb: float = 0.93 * smoothstep(0.0, 1.0, minf(1.0, t / 0.42)) * lerpf(1.0, 0.9, smoothstep(0.6, 1.0, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.09, 0.07, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.16, p.y) * bk * absf(2.0 * s - 1.0) * 0.8
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Kimono gövdesi: sol kanat sağın üstüne biner, arka ortada dikişle birleşir. o: keys, hem, col(a,y,v), fold(a,y,v), band(yaka rengi), band_w, low (alt bindirme açısı), inner, ny, na
static func _wrap(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var hem: float = o["hem"]
	var top: float = keys[0][0]
	var C: float = k.C
	var low: float = o.get("low", -0.5)
	var e_at := func(y: float, lo: float, hi: float) -> float: return lerpf(lo, hi, smoothstep(C - 0.03, top, y))
	var yv := func(v: float) -> float: return lerpf(top, hem, v)
	var fold: Callable = o["fold"]
	var res := {}
	for left: bool in [true, false]:
		var under := func(a: float, y: float, v: float) -> float:
			var f: float = float(fold.call(a, y, v))
			return f if left else f - 0.02 * smoothstep(-0.8, -0.4, a)
		var skf: Callable = o.get("skin_fn", Callable())   # isteğe bağlı: setin kendi etek ağırlığı (verilmezse eskisi)
		var skin := func(p: Vector3) -> Array: return skf.call(p) if skf.is_valid() else _wrap_skin(k, p, hem, left)
		var rng := func(v: float) -> Vector2:
			var y: float = yv.call(v)
			if left:
				return Vector2(e_at.call(y, low, 0.4), PI + 0.015)
			return Vector2(-PI - 0.015, e_at.call(y, 0.45, -0.4))
		var g: Dictionary = P._cl(k, {"keys": keys, "ny": o.get("ny", 50), "na": o.get("na", 62), "rng": rng, "top": func(_a: float) -> float: return top, "hem": func(_a: float) -> float: return hem, "fold": under, "col": o["col"], "gain": o.get("gain", 5.0), "skin": skin, "th": 0.005, "inner": o.get("inner", null)})
		res["L" if left else "R"] = g
		# yaka bandı: kumaş kenarı boyunca kalın şerit
		var ed: Array = g["ea"] if left else g["eb"]
		var pts := []
		var by: float = o.get("band_y", -99.0)
		for i in ed.size():
			var q: Vector3 = ed[i]
			if q.y < by or (not left and float(e_at.call(q.y, 0.45, -0.4)) > float(e_at.call(q.y, low, 0.4))):   # alt kanadın bandı bindirmenin altında kalır
				break
			pts.append(q + Vector3(0.012 if left else -0.012, 0.0, 0.0))
		P._bd(k, pts, o.get("band_w", 0.016), 0.0045, o["band"], false, skin, 0.1)
		if o.has("juban"):   # iç giysinin yakası: bandın içinde ince beyaz şerit
			var jp := []
			for i in ed.size():
				var q: Vector3 = ed[i]
				if q.y < C - 0.13 or (not left and float(e_at.call(q.y, 0.45, -0.4)) > float(e_at.call(q.y, low, 0.4))):
					break
				jp.append(q + Vector3(-0.01 if left else 0.01, 0.0, -0.004))
			if jp.size() >= 2:
				P._bd(k, jp, 0.0105, 0.003, o["juban"], false, skin, 0.1)
	return res


## Geniş kol: l uzvu, rad(s) taban yarıçap, pouch(s) aşağı sarkan torba, close: ağız kapanma oranı (0 tam açık, 1 bileğe sarılı), colf(s, a, ic). Torba kolun önüne ve arkasına açılır: kol inince kumaş kolun iki yanında yassı panel olur, gövdeye girmez
static func _wide(k, l: Dictionary, rad: Callable, pouch: Callable, foldf: Callable, colf: Callable, s1: float, close: float, rw: float, n := 30, seg := 30) -> void:
	var rows := []
	var ss := []
	var ins := []
	var frame := func(s: float) -> Array:
		var d: Vector3 = P._ld(l, s)
		var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri: Vector3 = (-d).cross(fw).normalized()
		return [P._lp(l, s), ri, fw]
	var ring := func(s: float, r: float, pc: float, fs: float, closing: float) -> Array:
		var f: Array = frame.call(s)
		var ro := []
		for i in seg:
			var a: float = TAU * i / seg - PI
			var u: Vector3 = (f[1] as Vector3) * sin(a) + (f[2] as Vector3) * cos(a)
			var dd: float = u.dot(f[2])
			var rr: float = r * (1.0 + fs * float(foldf.call(s, a)))
			var q: Vector3 = (f[0] as Vector3) + u * rr + (f[2] as Vector3) * pc * signf(dd) * pow(absf(dd), 1.5)
			if closing > 0.0:
				q = q.lerp((f[0] as Vector3) + u * rw, closing)
			ro.append(q)
		return ro
	for j in n + 1:
		var s: float = lerpf(0.0, s1, float(j) / n)
		rows.append(ring.call(s, rad.call(s), pouch.call(s), 1.0, 0.0))
		ss.append(s)
		ins.append(false)
	var r1: float = rad.call(s1)
	var p1: float = pouch.call(s1)
	for t: float in [0.3, 0.62, 1.0]:
		rows.append(ring.call(s1 + 0.004 * t, r1, p1, 1.0 - t, close * t))
		ss.append(s1)
		ins.append(false)
	for b: float in [0.0, 0.04, 0.09]:   # ağızdan içeri dönen astar
		rows.append(ring.call(s1 - b, r1 * 0.9, p1 * 0.9, 0.0, close * 0.98))
		ss.append(s1 - b)
		ins.append(true)
	k.grid(rows, true, func(i: int, j: int, _p: Vector3) -> Color: return colf.call(float(ss[j]), TAU * i / seg - PI, bool(ins[j])), func(_i: int, j: int, _p: Vector3) -> Array: return P._lskin(l, float(ss[j])))


## Kürk: kapalı yol üstünde tutam tutam kabaran kalın rulo
static func _fur(k, pts: Array, R: float, col: Color, skinf: Callable, sd := 0.0, closed := true) -> void:
	var nf := func(s: float, a: float) -> float:
		return 0.5 + 0.5 * sin(s * float(pts.size()) * 1.57 + a * 2.0 + 1.7 * sin(s * 41.0 + sd) + sd)
	P._tb(k, pts, func(s: float, a: float) -> float: return R * (0.72 + 0.46 * float(nf.call(s, a))), func(s: float, a: float, _p: Vector3) -> Color:
		var n: float = nf.call(s, a)
		return col.darkened(0.3 * (1.0 - n)).lightened(0.08 * n * n), func(_s: float, p: Vector3) -> Array: return skinf.call(p), 12, closed)


## Uzuv üstü yama: s0..s1, a0..a1 arasında kenarı inen yastık + iri dikişler
static func _lpatch(k, l: Dictionary, s0: float, s1: float, a0: float, a1: float, add: Callable, col: Color, st: Color) -> void:
	var surf := func(s: float, a: float, h: float) -> Vector3:
		var d: Vector3 = P._ld(l, s)
		var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri: Vector3 = (-d).cross(fw).normalized()
		return P._lp(l, s) + (ri * sin(a) + fw * cos(a)) * (P._lr(l, s) + float(add.call(s, a)) + h)
	var rows := []
	var nu := 8
	var nv := 8
	for j in nv + 1:
		var ro := []
		for i in nu + 1:
			var e: float = minf(minf(float(i) / nu, 1.0 - float(i) / nu), minf(float(j) / nv, 1.0 - float(j) / nv))
			ro.append(surf.call(lerpf(s0, s1, float(j) / nv), lerpf(a0, a1, float(i) / nu), lerpf(-0.002, 0.0042, smoothstep(0.0, 0.16, e))))
		rows.append(ro)
	var a00: Vector3 = rows[0][0]
	var fn: Vector3 = -((rows[0][1] as Vector3) - a00).cross((rows[1][1] as Vector3) - a00)
	if fn.dot(a00 - P._lp(l, s0)) < 0.0:
		for ro: Array in rows:
			ro.reverse()
	k.grid(rows, false, func(i: int, j: int, _p: Vector3) -> Color:
		return col.darkened(0.2) if mini(mini(i, nu - i), mini(j, nv - j)) == 0 else col, func(_i: int, j: int, _p: Vector3) -> Array: return P._lskin(l, lerpf(s0, s1, float(j) / nv)))
	for e2: Array in [[s0, s1, a0 + 0.1, a0 + 0.1], [s0, s1, a1 - 0.1, a1 - 0.1]]:
		var cnt: int = 5
		for i in cnt:
			var v: float = (float(i) + 0.5) / cnt
			var s: float = lerpf(float(e2[0]), float(e2[1]), v)
			var pa: Vector3 = surf.call(s - 0.006, float(e2[2]) - 0.1, 0.0052)
			var pb: Vector3 = surf.call(s + 0.006, float(e2[2]) + 0.1, 0.0052)
			var ou: Vector3 = (pa - P._lp(l, s)).normalized()
			k.strip([pa, pb], [ou, ou], 0.0022, 0.0012, st, false, func(_p: Vector3) -> Array: return P._lskin(l, s))


## Yüzeye dikişli yama (gövde)
static func _bpatch(k, keys: Array, a0: float, a1: float, y0: float, y1: float, lift: float, col: Color, st: Color, skinf: Callable) -> void:
	var rows := []
	var nu := 10
	var nv := 8
	for j in nv + 1:
		var ro := []
		for i in nu + 1:
			var e: float = minf(minf(float(i) / nu, 1.0 - float(i) / nu), minf(float(j) / nv, 1.0 - float(j) / nv))
			ro.append(P._sa(keys, lerpf(a0, a1, float(i) / nu), lerpf(y0, y1, float(j) / nv), lerpf(-0.002, lift, smoothstep(0.0, 0.16, e)))[0])
		rows.append(ro)
	var c0: Vector3 = P._sa(keys, (a0 + a1) * 0.5, (y0 + y1) * 0.5, 0.0)[1]
	var fn: Vector3 = -((rows[0][1] as Vector3) - (rows[0][0] as Vector3)).cross((rows[1][1] as Vector3) - (rows[0][0] as Vector3))
	if fn.dot(c0) < 0.0:
		for ro: Array in rows:
			ro.reverse()
	k.grid(rows, false, func(i: int, j: int, _p: Vector3) -> Color:
		return col.darkened(0.2) if mini(mini(i, nu - i), mini(j, nv - j)) == 0 else col, func(_i: int, _j: int, p: Vector3) -> Array: return skinf.call(p))
	for side: float in [a0 + (a1 - a0) * 0.1, a1 - (a1 - a0) * 0.1]:
		for i in 4:
			var y: float = lerpf(y0, y1, (float(i) + 0.5) / 4.0)
			var pa: Array = P._sa(keys, side - 0.035, y + 0.006, lift + 0.0012)
			var pb: Array = P._sa(keys, side + 0.035, y - 0.006, lift + 0.0012)
			k.strip([pa[0], pb[0]], [pa[1], pb[1]], 0.0022, 0.0012, st, false, skinf)


static func _col_of(rows: Array, i: int, j0: int, j1: int, lift := 0.0) -> Array:
	var o := []
	for j in range(j0, j1 + 1):
		var p: Vector3 = rows[j][i]
		o.append(p + Vector3(p.x, 0.0, p.z).normalized() * lift)
	return o


# ------------------------------------------------------------------ Ame (ref refs/kiyafet/m_ame: Ajisai: gri verev gömlek, açık gri pantolon, uyluk sargısı + kılıf): gri takım, yelek, köşeli yağmur pançosu, huni yaka
static func _ame(k) -> void:
	var sh := Color(0.32, 0.34, 0.38)
	var pn := Color(0.28, 0.3, 0.34)
	var ve := Color(0.4, 0.42, 0.46)
	var po := Color(0.3, 0.32, 0.36)
	var li := Color(0.2, 0.22, 0.26)
	var wr := Color(0.74, 0.75, 0.76)
	var mt := Color(0.62, 0.64, 0.68)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return sh, 0.008)
	_seat(k, b, pn.darkened(0.12))
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.009 + 0.0035 * P._lf(s, a, 1.3) * sin(s * PI) + 0.005 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 32.0)
		P._lt(k, ar, sf, func(s: float, a: float, ins: bool) -> Color:
			return sh.darkened(0.42) if ins else P._fs(sh, float(sf.call(s, a)) - 0.009, 22.0), 0.0, 0.93, 30, 18)
		P._wraps(k, ar, 0.85, 0.965, 6, 0.008, 0.011, li.lightened(0.08), 0.006)
		var kn: float = le["kn"]
		var pa: Callable = _pants(k, le, pn, 0.015, 0.02, 1.0, 1.1 if sd == "Left" else 3.3)
		P._wraps(k, le, 0.86, 0.975, 7, float(pa.call(0.92, 0.0)) + 0.007, 0.012, li.lightened(0.08), 0.008)
		if sd == "Right":   # uyluk sargısı + kılıf (ref Ajisai)
			P._wraps(k, le, kn * 0.46, kn * 0.66, 5, 0.03, 0.0125, wr, 0.006)
			var s0: float = kn * 0.56
			var c0: Vector3 = P._lp(le, s0)
			P._boxr(k, c0 + Vector3(-P._lr(le, s0) - 0.04, -0.015, 0.012), Vector3(0, 0, 0.038), Vector3(0, 0.058, 0), Vector3(-0.017, 0, 0), li, [["RightUpperLeg", 1.0]])
	# yelek: panço altında yanlardan görünür
	var vk := [P._kp(nk, N + 0.008, 0.024), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.024), P._kp(wa, H - 0.0, 0.034)]
	var vf := func(a: float, y: float, _v: float) -> float:
		var aa: float = absf(a)
		return -0.022 * exp(-pow((aa - 1.1) / 0.06, 2.0)) - 0.022 * exp(-pow((aa - 2.05) / 0.06, 2.0)) + 0.004 * sin(a * 6.0 + y * 12.0)
	P._cl(k, {"keys": vk, "ny": 28, "na": 72, "top": func(_a: float) -> float: return N + 0.008, "hem": func(_a: float) -> float: return H + 0.0, "fold": vf, "col": func(_a: float, _y: float, _v: float) -> Color: return ve, "gain": 7.0, "th": 0.005})
	for sg: float in [1.0, -1.0]:   # yan tokalı kayışlar
		for y0: float in [C - 0.14, H + 0.12]:
			var pts := []
			for i in 9:
				pts.append(P._on(vk, sg * lerpf(1.05, 2.1, float(i) / 8.0), y0, 0.022))
			P._bd(k, pts, 0.0105, 0.0035, li, false, func(p: Vector3) -> Array: return k.torso_skin(p.y))
			var q0: Vector3 = P._on(vk, sg * 1.57, y0, 0.05)
			P._boxr(k, q0, Vector3(0, 0.0135, 0), Vector3(0, 0, 0.0135), Vector3(sg * 0.004, 0, 0), mt, k.torso_skin(y0), 0.3)
	var bk := [P._kp(wa, H + 0.1, 0.038), P._kp(wa, H - 0.04, 0.042)]
	P._sash(k, bk, H + 0.03, 0.021, 0.0, li.lightened(0.04), 0.16)
	var pq: Array = P._sa(bk, 1.05, H + 0.0, 0.03)
	P._boxr(k, (pq[0] as Vector3) + Vector3(0, -0.035, 0), (pq[1] as Vector3).cross(Vector3.UP).normalized() * 0.04, Vector3(0, 0.04, 0), (pq[1] as Vector3) * 0.022, li.lightened(0.1), [["Hips", 1.0]], 0.32)
	# panço: başlıktan geçirilen tek parça; önde ve arkada sivri uç, yanlarda kola kadar yükselir
	var wd: float = ch.x + 0.105
	var hem0: float = H - 0.27
	var ck := [[N + 0.03, nk.x + 0.05, nk.y + 0.05, nk.z - 0.055], [N - 0.006, nk.x + 0.09, nk.y + 0.07, nk.z - 0.078], [N - 0.07, wd * 0.97, ch.y + 0.045, ch.z - 0.05], [C - 0.06, wd, ch.y + 0.07, ch.z - 0.08], [H + 0.08, wd * 0.93, maxf(ch.y, wa.y) + 0.075, minf(ch.z, wa.z) - 0.09], [hem0, wd * 0.88, hp.y + 0.1, hp.z - 0.125]]
	var hf := func(a: float) -> float:
		var aw: float = absf(a)
		var sd: float = exp(-pow((aw - PI * 0.5) / 0.62, 2.0))
		var base: float = lerpf(H - 0.19, H - 0.24, smoothstep(1.2, 2.0, aw))
		var tip: float = 0.05 * exp(-pow(minf(aw, PI - aw) / 0.28, 2.0))
		return lerpf(base - tip, C - 0.1, sd)
	var ff := func(a: float, y: float, v: float) -> float:
		return v * (0.03 * sin(a * 6.0 + 0.7) + 0.014 * sin(a * 11.0 + 2.1)) + 0.004 * sin(a * 4.0 + y * 7.0)
	var cs := func(p: Vector3) -> Array:
		return _arm_skin(k, p, wd) if p.y >= H else k.cloth_skin(p, hem0, 0.42)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 44, "na": 112, "top": func(_a: float) -> float: return N + 0.03, "hem": hf, "fold": ff, "col": func(a: float, _y: float, v: float) -> Color:
		return po.lightened(0.05 * pow(absf(sin(a * 3.0 + v * 2.0)), 6.0)), "gain": 6.0, "skin": cs, "th": 0.005, "inner": li})
	P._bd(k, _yl(cg["hem"], 0.012), 0.01, 0.003, li, true, cs)
	var rows: Array = cg["rows"]
	var nn: int = rows.size() - 1
	for a0: float in [0.0, 0.3, -0.3, PI]:   # su kanalı dikişleri
		var i0: int = posmod(int(round((a0 + PI) / TAU * 112.0)), 112)
		P._bd(k, _col_of(rows, i0, 4, nn - 3, 0.001), 0.004 if a0 == 0.0 or a0 == PI else 0.0028, 0.0022, li, false, cs)
	# huni yaka + göğüs levhası: Ame'nin dört çizgisi
	var cl := [[N + 0.06, nk.x + 0.04, nk.y + 0.036, nk.z - 0.046], [N + 0.03, nk.x + 0.036, nk.y + 0.032, nk.z - 0.04], [N + 0.0, nk.x + 0.058, nk.y + 0.05, nk.z - 0.058]]
	var skt := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	var cc: Dictionary = P._cl(k, {"keys": cl, "ny": 10, "na": 44, "rng": func(_v: float) -> Vector2: return Vector2(0.2, TAU - 0.2), "top": func(a: float) -> float: return lerpf(N + 0.04, N + 0.062, smoothstep(0.2, 1.4, absf(a))), "hem": func(_a: float) -> float: return N + 0.0, "fold": func(a: float, _y: float, v: float) -> float: return 0.012 * (1.0 - v) * sin(a * 5.0), "col": func(_a: float, _y: float, _v: float) -> Color: return po.lightened(0.04), "inner": li, "skin": skt, "th": 0.005})
	P._bd(k, cc["top"], 0.004, 0.0022, li, false, skt, 0.6)
	for t: float in [0.3, 0.72]:
		var ea: Array = cc["ea"]
		var q: Vector3 = ea[int(t * (ea.size() - 1))]
		P._stud(k, q + Vector3(0.008, 0, 0.002), Vector3(0, 0, 1), 0.0058, mt, k.torso_skin(N))
	var pe: Array = P._sa(ck, 0.0, C - 0.03, 0.009)
	var ct: Vector3 = pe[0]
	var bo: Array = k.torso_skin(C - 0.03)
	P._boxr(k, ct, Vector3(0.05, 0, 0), Vector3(0, 0.032, 0), Vector3(0, 0, 0.0065), mt, bo, 0.28)
	for i in 4:
		var x: float = -0.027 + 0.018 * i
		k.strip([ct + Vector3(x, 0.021, 0.0062), ct + Vector3(x, -0.021, 0.0062)], [Vector3.BACK, Vector3.BACK], 0.0032, 0.0012, li.darkened(0.2), false, func(_p: Vector3) -> Array: return bo)


# ------------------------------------------------------------------ Ne / Kök (ref refs/kiyafet/m_ne, Sai): dar siyah takım, boğazlı yaka, kısa gri yelek, ön kol boyunca beyaz sargı, bel arkasında yatay tomar
static func _ne(k) -> void:
	var bl := Color(0.1, 0.1, 0.12)
	var pn := Color(0.08, 0.08, 0.1)
	var ve := Color(0.22, 0.22, 0.24)
	var dk := Color(0.05, 0.05, 0.06)
	var wr := Color(0.85, 0.85, 0.82)
	var mt := Color(0.5, 0.5, 0.53)
	var sc := Color(0.78, 0.73, 0.6)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return bl, 0.006)
	_seat(k, b, pn)
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.005 + 0.002 * P._lf(s, a, 0.6) * sin(s * PI) + 0.004 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s: float, a: float, ins: bool) -> Color:
			return bl.darkened(0.4) if ins else P._fs(bl.lightened(0.04), float(sf.call(s, a)) - 0.005, 26.0), 0.0, 0.97, 30, 16)
		# ön kol sargısı: dirsekten bileğe sıkı turlar; üst kolda iki tur
		P._wraps(k, ar, en + 0.05, 0.965, 15, 0.0085, 0.0115, wr, 0.0075)
		P._wraps(k, ar, en * 0.52, en * 0.62, 3, 0.0085, 0.0105, wr.darkened(0.08), 0.004)
		var kn: float = le["kn"]
		var pa: Callable = _pants(k, le, pn.lightened(0.03), 0.008, 0.012, 1.0, 2.2 if sd == "Left" else 5.0)
		P._wraps(k, le, 0.87, 0.975, 7, float(pa.call(0.92, 0.0)) + 0.007, 0.0115, dk.lightened(0.1), 0.007)
		for s2: float in [kn * 0.58, kn * 0.72]:
			if sd == "Right":
				k.wrap_turn(P._lp(le, s2), P._ld(le, s2), P._lr(le, s2) + float(pa.call(s2, 0.0)) + 0.008, 0.0105, 0.0, dk.lightened(0.08), P._lskin(le, s2))
		if sd == "Right":
			var s3: float = kn * 0.65
			P._boxr(k, P._lp(le, s3) + Vector3(-P._lr(le, s3) - 0.03, 0, 0.018), Vector3(0, 0, 0.036), Vector3(0, 0.05, 0), Vector3(-0.016, 0, 0), dk.lightened(0.07), [["RightUpperLeg", 1.0]])
	# boğazlı yaka: boyna oturan kat
	var ck := [[N + 0.085, nk.x + 0.01, nk.y + 0.012, nk.z - 0.016], [N + 0.05, nk.x + 0.014, nk.y + 0.015, nk.z - 0.018], [N + 0.0, nk.x + 0.03, nk.y + 0.024, nk.z - 0.03]]
	var skt := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	var cf: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 40, "top": func(_a: float) -> float: return N + 0.085, "hem": func(_a: float) -> float: return N + 0.0, "fold": func(a: float, _y: float, v: float) -> float: return 0.012 * sin(v * 9.0 + a * 2.0), "col": func(_a: float, _y: float, _v: float) -> Color: return bl.lightened(0.05), "inner": dk, "skin": skt, "th": 0.004})
	P._bd(k, cf["top"], 0.0035, 0.002, ve, true, skt, 0.6)
	# kısa yelek: göğüs altına oturan, panelli, önden ortada kapanır
	var hem0: float = H + 0.075
	var vk := [P._kp(nk, N + 0.006, 0.026), [N - 0.055, ch.x * 0.96, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.018), P._kp(wa, H + 0.14, 0.017), P._kp(wa, hem0, 0.02)]
	var groove := func(a: float, y: float, _v: float) -> float:
		var aa: float = absf(a)
		var g: float = -0.03 * exp(-pow((aa - 0.72) / 0.05, 2.0)) - 0.03 * exp(-pow((aa - 2.3) / 0.05, 2.0)) - 0.016 * exp(-pow((y - (C - 0.13)) / 0.009, 2.0)) * smoothstep(1.0, 0.75, aa)
		return g + 0.003 * sin(a * 7.0 + y * 16.0)
	var vw: float = ch.x + 0.02
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 34, "na": 88, "rng": func(_v: float) -> Vector2: return Vector2(0.018, TAU - 0.018), "top": func(_a: float) -> float: return N + 0.006, "hem": func(a: float) -> float: return hem0 - 0.02 * exp(-pow(a / 0.4, 2.0)) - 0.01 * cos(a), "fold": groove, "col": func(_a: float, _y: float, _v: float) -> Color: return ve, "gain": 8.0, "th": 0.005, "skin": func(p: Vector3) -> Array: return _arm_skin(k, p, vw)})   # omuz kolu izler: kol kalkınca yelek delinmez
	var sk0 := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	P._bd(k, _yl(vg["hem"], 0.008), 0.0065, 0.0026, dk.lightened(0.12), false, sk0)
	P._bd(k, _yl(vg["top"], -0.006), 0.0055, 0.002, dk.lightened(0.12), false, sk0, 0.4)
	for ed: Array in [vg["ea"], vg["eb"]]:
		P._bd(k, ed, 0.005, 0.0028, dk.lightened(0.14), false, sk0)
	# gizli kapanış tokaları
	for i in 4:
		var y: float = lerpf(N - 0.1, hem0 + 0.035, float(i) / 3.0)
		var q: Vector3 = P._sa(vk, 0.0, y, 0.006)[0]
		P._boxr(k, q, Vector3(0.016, 0, 0), Vector3(0, 0.0055, 0), Vector3(0, 0, 0.0035), mt, k.torso_skin(y), 0.28)
	# göğüs kayışı ve bel
	P._strap(k, vk, [Vector2(-ch.x * 0.62, C + 0.05), Vector2(ch.x * 0.74, H + 0.11)], true, 0.0135, 0.008, 0.004, dk.lightened(0.09), 12, sk0)
	P._strap(k, vk, [Vector2(ch.x * 0.62, C + 0.05), Vector2(-ch.x * 0.74, H + 0.11)], false, 0.0135, 0.008, 0.004, dk.lightened(0.09), 12, sk0)
	var bk := [P._kp(wa, H + 0.09, 0.016), P._kp(k.M(H + 0.0, 0.3), H - 0.03, 0.02)]
	P._sash(k, bk, H + 0.03, 0.024, 0.002, dk.lightened(0.06), 0.1)
	var bf: Array = P._sa(bk, 0.0, H + 0.03, 0.012)
	P._boxr(k, bf[0], Vector3(0.024, 0, 0), Vector3(0, 0.019, 0), (bf[1] as Vector3) * 0.0055, mt, [["Hips", 1.0]], 0.26)
	# bel arkasında yatay tomar: kapakları ve bağı ile
	var bz: Array = P._sa(bk, PI, H + 0.035, 0.05)
	var sc0: Vector3 = bz[0]
	var hip: Array = [["Hips", 1.0]]
	var pr := func(s: float, _a: float) -> float:
		return (0.03 * (0.86 + 0.14 * smoothstep(0.0, 0.03, minf(s, 1.0 - s))) + 0.006 * (smoothstep(0.09, 0.08, minf(s, 1.0 - s)))) * sqrt(smoothstep(0.0, 0.03, minf(s, 1.0 - s)))   # uçlar kapaklı
	var sp := []
	for i in 19:
		sp.append(sc0 + Vector3(lerpf(-0.17, 0.17, float(i) / 18.0), 0.0, 0.0))
	P._tb(k, sp, pr, func(s: float, a: float, _p: Vector3) -> Color:
		return ve.darkened(0.2) if minf(s, 1.0 - s) < 0.09 else sc.darkened(0.12 * absf(sin(a * 2.0))), func(_s: float, _p: Vector3) -> Array: return hip, 14)
	for sx: float in [-0.09, 0.09]:
		k.wrap_turn(sc0 + Vector3(sx, 0, 0), Vector3.RIGHT, 0.034, 0.006, 0.0, dk.lightened(0.1), hip)
	# sırtta 根
	for q2: Array in _NE_STROKES:
		var p0 := Vector2(float(q2[0]), float(q2[1])) * 0.05 + Vector2(0.0, C - 0.05)
		var p1 := Vector2(float(q2[2]), float(q2[3])) * 0.05 + Vector2(0.0, C - 0.05)
		P._strap(k, vk, [Vector2(-p0.x, p0.y), Vector2(-p1.x, p1.y)], false, 0.0034, 0.004, 0.0015, dk, 4, sk0)


const _NE_STROKES := [[-0.95, 0.5, -0.1, 0.5], [-0.52, 0.95, -0.52, -0.95], [-0.52, 0.45, -0.95, -0.25], [-0.5, 0.35, -0.15, 0.0],
	[0.15, 0.85, 0.15, -0.72], [0.15, 0.85, 0.82, 0.85], [0.82, 0.85, 0.82, 0.08], [0.15, 0.45, 0.82, 0.45], [0.15, 0.08, 0.82, 0.08], [0.15, -0.72, 0.5, -0.5], [0.4, 0.08, 0.92, -0.9], [0.86, -0.1, 0.5, -0.32]]


# ------------------------------------------------------------------ Sōryo (ref refs/kiyafet/chiriku + tapınak keşişleri): krem koromo, geniş kol, omuzdan verev yamalı kesa + altın halka, iri tespih, bol büzgülü pantolon
static func _soryo(k) -> void:
	var cr := Color(0.85, 0.82, 0.72)
	var pa_c := Color(0.82, 0.78, 0.68)
	var br := Color(0.6, 0.4, 0.2)
	var ke := Color(0.72, 0.4, 0.15)
	var dk := Color(0.15, 0.13, 0.12)
	var gd := Color(0.84, 0.68, 0.3)
	var bd := Color(0.27, 0.16, 0.1)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner_v(k, b, cr.lightened(0.1))
	_seat(k, b, pa_c.darkened(0.1))
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		# iç kol + geniş koromo kolu
		P._lt(k, ar, func(_s: float, _a: float) -> float: return 0.004, func(_s: float, _a: float, ins: bool) -> Color: return cr.darkened(0.4) if ins else cr.lightened(0.1), en * 0.6, 0.97, 16, 12)
		_wide(k, ar, func(s: float) -> float: return 0.05 + 0.024 * smoothstep(0.1, 0.5, s), func(s: float) -> float: return 0.075 * smoothstep(0.42, 0.74, s) + 0.02 * smoothstep(0.74, 0.86, s), func(s: float, a: float) -> float: return 0.06 * sin(a * 4.0 + s * 9.0) + 0.03 * sin(a * 7.0 - s * 13.0), func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return br.darkened(0.3)
			var f: float = 0.6 * sin(a * 4.0 + s * 9.0) + 0.4 * sin(a * 7.0 - s * 13.0)
			return P._fs(cr, f * 0.03, 5.0).darkened(0.3 if s > 0.86 else 0.0), 0.87, 0.14, 0.06)
		# bol pantolon: dizden aşağı balon, baldırda büzülüp kyahan içine girer
		var pf := func(s: float, a: float) -> float:
			var fl: float = sin(a * 7.0 + s * 3.0 + (0.0 if sd == "Left" else 2.0)) * 0.009 * smoothstep(0.1, 0.5, s) * (1.0 - smoothstep(0.76, 0.82, s))
			var bal: float = 0.022 + 0.05 * exp(-pow((s - (kn + 0.07)) / 0.25, 2.0))
			return (bal + fl) * (1.0 - smoothstep(0.74, 0.82, s)) + 0.012 + P._lf(s, a, 2.0) * 0.003
		P._lt(k, le, pf, func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return pa_c.darkened(0.42)
			return P._fs(pa_c, sin(a * 7.0 + s * 3.0 + (0.0 if sd == "Left" else 2.0)) * 0.012 * smoothstep(0.1, 0.5, s) * (1.0 - smoothstep(0.76, 0.82, s)), 14.0), 0.0, 1.0, 40, 26)
		P._wraps(k, le, 0.82, 0.975, 10, 0.021, 0.0125, dk.lightened(0.14), 0.009)
		k.wrap_turn(P._lp(le, 0.8), P._ld(le, 0.8), P._lr(le, 0.8) + 0.028, 0.008, 0.0, br.darkened(0.15), P._lskin(le, 0.8))
	# koromo: V bindirmeli, uyluğa inen
	var hem0: float = H - 0.24
	var keys := [P._kp(nk, N + 0.012, 0.028), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.028), P._kp(wa, H + 0.12, 0.04), P._kp(hp, H - 0.04, 0.05), [hem0, hp.x + 0.095, hp.y + 0.075, hp.z - 0.09]]
	var fold := func(a: float, y: float, v: float) -> float:
		var t: float = clampf((H + 0.06 - y) / (H + 0.06 - hem0), 0.0, 1.0)
		return t * (0.05 * sin(a * 7.0 + 0.5) + 0.022 * sin(a * 13.0 + 2.0)) + 0.008 * (1.0 - t) * sin(a * 5.0 + y * 14.0) + 0.0 * v
	_wrap(k, {"keys": keys, "hem": hem0, "col": func(_a: float, _y: float, _v: float) -> Color: return cr, "fold": fold, "band": br, "band_w": 0.018, "band_y": H + 0.03, "juban": cr.lightened(0.5), "ny": 44, "na": 58, "gain": 4.5})
	var hs := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	# siyah ip kuşak: çift tur + önde düğüm
	var bk := [P._kp(wa, H + 0.12, 0.052), P._kp(k.M(H + 0.0, 0.3), H - 0.0, 0.056)]
	var by: float = H + 0.055
	for dy: float in [0.011, -0.011]:
		P._cord(k, P._ring_pts(bk, by + dy, 0.002, 64), 0.0115, dk.lightened(0.05), true, hs, 1.2)
	var kn0: Vector3 = P._sa(bk, -0.25, by, 0.012)[0]
	P._boxr(k, kn0, Vector3(0.022, 0.006, 0), Vector3(-0.006, 0.018, 0), Vector3(0, 0, 0.014), dk.lightened(0.08), [["Hips", 1.0]], 0.45)
	for e2: Array in [[-0.012, 0.16], [0.016, 0.12]]:
		var tail := []
		for i in 9:
			var v: float = float(i) / 8.0
			var y: float = by - 0.012 - v * float(e2[1])
			var x: float = kn0.x + float(e2[0]) * (0.4 + v)
			tail.append(P._fp(keys, x, y, true, 0.016)[0])
		P._cord(k, tail, 0.0052, dk.lightened(0.05), false, func(p: Vector3) -> Array: return _wrap_skin(k, p, hem0, false), 1.5)
	# kesa: sol omuzdan sağ kol altına verev dolanan yamalı kuşak (tagasode dikişleri)
	var yt: float = N - 0.038
	var yb: float = H + 0.15
	var ym: float = (yt + yb) * 0.5
	var am: float = (yt - yb) * 0.5
	var na: int = 124
	var nv: int = 8
	var rows := []
	var cols := []
	var kk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.01, ch.y * 0.98, ch.z * 1.07], P._kp(ch, C - 0.03, 0.038), P._kp(wa, H + 0.12, 0.05), P._kp(hp, H - 0.0, 0.06)]
	for j in nv + 1:
		var v: float = float(j) / nv
		var ro := []
		var cr2 := []
		for i in na:
			var a: float = TAU * i / na - PI
			var hw: float = lerpf(0.085, 0.032, exp(-pow(wrapf(a - PI * 0.5, -PI, PI) / 0.62, 2.0)))
			var y: float = ym + am * sin(a) + hw * (1.0 - 2.0 * v)
			y = minf(y, N - 0.008)
			var lift: float = 0.004 + 0.007 * sin(v * PI)
			ro.append(P._sa(kk, a, y, lift)[0])
			var seam: bool = fposmod(a * 3.82, 1.0) < 0.14
			var edge: bool = j <= 1 or j >= nv - 1
			var mid: bool = j == nv / 2 and int(floor(a * 3.82)) % 2 == 0
			var c0: Color = ke.darkened(0.08 * float(posmod(int(floor(a * 3.82)), 3)))
			cr2.append(ke.darkened(0.34) if edge else (c0.darkened(0.28) if seam or mid else c0))
		rows.append(ro)
		cols.append(cr2)
	k.grid(rows, true, func(i: int, j: int, _p: Vector3) -> Color: return cols[j][i], func(_i: int, _j: int, p: Vector3) -> Array: return k.torso_skin(p.y))
	# altın halka + bağ
	var ra: float = 0.44
	var ry: float = ym + am * sin(ra) + 0.01
	var rc: Array = P._sa(kk, ra, ry, 0.022)
	var bo: Array = k.torso_skin(ry)
	var rp := []
	var ou: Vector3 = rc[1]
	var ux: Vector3 = ou.cross(Vector3.UP).normalized()
	for i in 22:
		var t: float = TAU * i / 22.0
		rp.append((rc[0] as Vector3) + (ux * cos(t) + Vector3.UP * sin(t)) * 0.03)
	P._tb(k, rp, func(_s: float, _a: float) -> float: return 0.0052, func(_s: float, a: float, _p: Vector3) -> Color: return gd.lightened(0.14) if cos(a) > 0.3 else gd.darkened(0.12), func(_s: float, _p: Vector3) -> Array: return bo, 8, true)
	P._stud(k, (rc[0] as Vector3) + ou * 0.0, ou, 0.012, gd.darkened(0.08), bo)
	# boyun tespihi: göğse sarkan iri boncuklar + büyük ana boncuk
	var bp := []
	var nb: int = 150
	for i in nb:
		var t: float = TAU * i / nb
		var drop: float = pow(0.5 + 0.5 * cos(t), 1.6)
		var y: float = lerpf(N + 0.012, C - 0.09, drop)
		var a: float = sin(t * 0.5) * PI * sign(cos(t * 0.5) + 0.0001)
		var w: float = lerpf(1.0, 0.72, drop)
		var q: Vector3 = P._on(keys, wrapf(t + PI * 0.0, -PI, PI), y, 0.0)
		bp.append(Vector3(q.x * w + 0.0 * a, y, q.z) + Vector3(q.x, 0.0, q.z).normalized() * 0.034)
	var nbd: float = 27.0
	P._tb(k, bp, func(s: float, _a: float) -> float: return 0.0028 + 0.0092 * sqrt(absf(sin(s * nbd * PI))), func(s: float, a: float, _p: Vector3) -> Color:
		return bd.lightened(0.16 if cos(a) > 0.4 else 0.0).darkened(0.32 * (1.0 - absf(sin(s * nbd * PI)))), func(_s: float, p: Vector3) -> Array: return k.torso_skin(minf(p.y, N)), 8, true)


# ------------------------------------------------------------------ Rōnin: yamalı verev gömlek, sıvalı kol, yamalı pantolon, ip kuşak, tek omuza atılmış yırtık yol pelerini
static func _ronin(k) -> void:
	var sh := Color(0.4, 0.36, 0.3)
	var s2 := Color(0.3, 0.26, 0.2)
	var pn := Color(0.3, 0.28, 0.24)
	var cp := Color(0.35, 0.3, 0.26)
	var pt := Color(0.3, 0.25, 0.19)
	var pt2 := Color(0.47, 0.42, 0.33)
	var st := Color(0.66, 0.6, 0.47)
	var rp := Color(0.54, 0.47, 0.33)
	var wr := Color(0.62, 0.57, 0.46)
	var skin_c: Color = k.m.look["skin"]
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner_v(k, b, s2.darkened(0.2))
	_seat(k, b, pn.darkened(0.15))
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sg: float = 1.0 if sd == "Left" else 2.7
		var sf := func(s: float, a: float) -> float:
			return 0.012 + 0.0052 * P._lf(s, a, sg) + 0.006 * exp(-pow((s - en) / 0.09, 2.0)) * sin(a * 3.0 + s * 30.0)
		var s_end: float = en + 0.1
		P._bare(k, ar, skin_c, s_end - 0.04, 0.97)
		P._lt(k, ar, sf, func(s: float, a: float, ins: bool) -> Color:
			return sh.darkened(0.42) if ins else P._fs(sh, float(sf.call(s, a)) - 0.012, 16.0), 0.0, s_end, 26, 18)
		for i in 3:   # sıvanmış kol ağzı: üst üste rulo
			var s3: float = s_end - 0.012 * i
			k.wrap_turn(P._lp(ar, s3), P._ld(ar, s3), P._lr(ar, s3) + 0.018 - 0.002 * i, 0.0115, 0.004, sh.lightened(0.05).darkened(0.08 * i), P._lskin(ar, s3))
		P._wraps(k, ar, 0.86, 0.965, 6, 0.004, 0.0115, wr, 0.008)
		var pa: Callable = _pants(k, le, pn, 0.018, 0.026, 1.0, sg)
		P._wraps(k, le, 0.77, 0.975, 11, float(pa.call(0.88, 0.0)) + 0.007, 0.0135, wr.darkened(0.08), 0.012)
		k.wrap_turn(P._lp(le, 0.78), P._ld(le, 0.78), P._lr(le, 0.78) + float(pa.call(0.78, 0.0)) + 0.012, 0.0045, 0.0, rp.darkened(0.2), P._lskin(le, 0.78))
		# pantolon ve kol yamaları
		if sd == "Left":
			_lpatch(k, le, kn * 0.62, kn * 1.02, -0.55, 0.65, func(s: float, a: float) -> float: return float(pa.call(s, a)), pt, st)
			_lpatch(k, ar, en * 0.44, en * 0.8, 0.3, 1.5, sf, pt2, st)
		else:
			_lpatch(k, le, kn * 0.18, kn * 0.42, 2.0, 3.0, func(s: float, a: float) -> float: return float(pa.call(s, a)), pt2.darkened(0.14), st)
			_lpatch(k, le, kn * 1.03, kn * 1.26, -0.5, 0.5, func(s: float, a: float) -> float: return float(pa.call(s, a)), pt, st)
	# verev gömlek
	var hem0: float = H - 0.14
	var keys := [P._kp(nk, N + 0.012, 0.024), [N - 0.055, ch.x * 0.99, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.024), P._kp(hp, H - 0.03, 0.036), [hem0, hp.x + 0.052, hp.y + 0.045, hp.z - 0.05]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.07 - y) / (H + 0.07 - hem0), 0.0, 1.0)
		return t * (0.03 * sin(a * 8.0 + 1.0) + 0.017 * sin(a * 15.0)) + (1.0 - t) * (0.011 * sin(a * 6.0 + y * 13.0) + 0.006 * sin(a * 13.0 - y * 17.0))
	_wrap(k, {"keys": keys, "hem": hem0, "col": func(_a: float, _y: float, _v: float) -> Color: return sh, "fold": fold, "band": s2, "band_w": 0.0135, "ny": 40, "na": 56, "gain": 5.5, "low": -0.5})
	var sk0 := func(p: Vector3) -> Array: return _wrap_skin(k, p, hem0, true)
	_bpatch(k, keys, 0.42, 1.0, C - 0.02, C - 0.15, 0.008, pt, st, sk0)
	_bpatch(k, keys, -0.95, -0.42, H + 0.16, H + 0.06, 0.008, pt2, st, sk0)
	_bpatch(k, keys, 2.5, 3.0, C - 0.06, C - 0.19, 0.008, pt.lightened(0.05), st, sk0)
	# ip kuşak: burgulu, yanda düğüm, sarkan uçlar kumaşa oturur
	var bk := [P._kp(wa, H + 0.1, 0.034), P._kp(k.M(H + 0.0, 0.3), H - 0.02, 0.04)]
	var by: float = H + 0.04
	P._cord(k, P._ring_pts(bk, by + 0.011, 0.002, 72), 0.0105, rp, true, func(p: Vector3) -> Array: return k.torso_skin(p.y), 1.5, 8)
	P._cord(k, P._ring_pts(bk, by - 0.011, 0.002, 72), 0.0105, rp.darkened(0.1), true, func(p: Vector3) -> Array: return k.torso_skin(p.y), 1.5, 8)
	var kq: Array = P._sa(bk, 0.72, by, 0.012)
	P._boxr(k, kq[0], (kq[1] as Vector3).cross(Vector3.UP).normalized() * 0.024, Vector3(0, 0.02, 0), (kq[1] as Vector3) * 0.015, rp.darkened(0.06), [["Hips", 1.0]], 0.45)
	for e2: Array in [[0.0, 0.17], [0.03, 0.12]]:
		var tail := []
		var x0: float = (kq[0] as Vector3).x
		for i in 9:
			var v: float = float(i) / 8.0
			tail.append(P._fp(keys, x0 + float(e2[0]) * v, by - 0.012 - v * float(e2[1]), true, 0.024)[0])
		P._cord(k, tail, 0.0058, rp, false, func(p: Vector3) -> Array: return _wrap_skin(k, p, hem0, true), 1.6, 7)
	# tek omuza atılmış yırtık pelerin: sol omuzdan sırta, sağ belde biter
	var wd: float = ch.x + 0.1
	var hem1: float = k.K + 0.03
	var ck := [[N + 0.03, nk.x + 0.055, nk.y + 0.05, nk.z - 0.06], [N - 0.01, nk.x + 0.09, nk.y + 0.06, nk.z - 0.082], [N - 0.075, wd * 0.96, ch.y + 0.035, ch.z - 0.06], [C - 0.06, wd, ch.y + 0.05, ch.z - 0.09], [H + 0.04, wd * 0.96, wa.y + 0.09, minf(ch.z, wa.z) - 0.1], [hem1, wd * 0.98, hp.y + 0.1, hp.z - 0.19]]
	var tp := func(a: float) -> float:
		return lerpf(N + 0.028, C - 0.05, smoothstep(-2.55, -1.75, a) * (1.0 if a < 0.0 else 0.0))
	var tear := func(a: float) -> float:
		var n1: float = pow(maxf(0.0, sin(a * 15.0 + 0.7)), 5.0)
		var n2: float = pow(maxf(0.0, sin(a * 23.0 + 2.4)), 7.0)
		var n3: float = pow(maxf(0.0, sin(a * 7.0 + 4.0)), 9.0)
		return 0.1 * n1 + 0.07 * n2 + 0.14 * n3 + 0.018 * sin(a * 41.0)
	var hc := func(a: float) -> float:
		var base: float = lerpf(H - 0.03, hem1, smoothstep(0.75, 2.35, absf(a)))
		base = lerpf(base, H + 0.04, smoothstep(-2.2, -1.75, a) * (1.0 if a < 0.0 else 0.0))
		return base + float(tear.call(a))
	var cf := func(a: float, y: float, v: float) -> float:
		return v * (0.05 * sin(a * 6.0 + 1.0) + 0.024 * sin(a * 11.0 + 0.4)) + 0.005 * sin(a * 4.0 + y * 8.0)
	var cs := func(p: Vector3) -> Array: return _rear_skin(k, p, hem1, wd)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 44, "na": 120, "rng": func(_v: float) -> Vector2: return Vector2(0.62, TAU - 1.75), "top": tp, "hem": hc, "fold": cf, "col": func(a: float, y: float, v: float) -> Color:
		var w: float = 0.5 + 0.5 * sin(a * 3.0 + y * 5.0)
		return cp.darkened(0.14 * w + 0.16 * smoothstep(0.82, 1.0, v)).lightened(0.04 * (1.0 - w)), "gain": 5.5, "skin": cs, "th": 0.004, "inner": cp.darkened(0.3)})
	P._bd(k, _yl(cg["top"], -0.008), 0.0075, 0.0028, cp.darkened(0.24), false, cs, 0.4)
	P._bd(k, cg["ea"], 0.008, 0.0028, cp.darkened(0.22), false, cs)
	var rows: Array = cg["rows"]
	_bpatch(k, ck, -2.75, -2.25, H + 0.1, H - 0.08, 0.012, pt.darkened(0.08), st, cs)
	_bpatch(k, ck, 2.0, 2.45, C - 0.04, C - 0.18, 0.012, pt2.darkened(0.2), st, cs)
	var _r0: Array = rows[0]
	# göğüsten geçen tutma ipi: pelerinin ön ucundan sağ koltuk altına
	var cpts := []
	var e0: Vector3 = (cg["ea"] as Array)[8]
	for i in 15:
		var v: float = float(i) / 14.0
		cpts.append(P._sa(keys, lerpf(0.62, -1.75, v), lerpf(e0.y, C - 0.1, v), 0.018)[0])
	cpts.append(P._sa(keys, -2.15, C - 0.11, 0.05)[0])
	P._cord(k, cpts, 0.0062, rp, false, func(p: Vector3) -> Array: return k.torso_skin(p.y), 1.5, 7)
	P._stud(k, e0 + Vector3(0.002, 0.0, 0.004), P._out(e0), 0.012, rp.darkened(0.25), k.torso_skin(e0.y))


# ------------------------------------------------------------------ Yuki Tabi (ref refs/kiyafet/m_yuki: Kar Ülkesi): çift sıra düğmeli deri ceket, kürk yaka + kol ağzı, sargılı pantolon, baldıra inen gece pelerini
static func _yuki(k) -> void:
	var le_c := Color(0.36, 0.26, 0.2)
	var le_d := Color(0.23, 0.16, 0.12)
	var fu := Color(0.8, 0.78, 0.74)
	var pn := Color(0.28, 0.26, 0.24)
	var nv := Color(0.22, 0.24, 0.3)
	var li := Color(0.12, 0.13, 0.18)
	var wr := Color(0.5, 0.47, 0.43)
	var mt := Color(0.7, 0.66, 0.56)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return pn.darkened(0.15), 0.006)
	_seat(k, b, pn.darkened(0.12))
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sg: float = 0.6 if sd == "Left" else 3.1
		var sf := func(s: float, a: float) -> float:
			return 0.016 + 0.003 * P._lf(s, a, sg) + 0.0075 * exp(-pow((s - en) / 0.075, 2.0)) * sin(a * 3.0 + s * 26.0) + 0.006 * exp(-pow((s - en * 0.5) / 0.14, 2.0))
		P._lt(k, ar, sf, func(s: float, a: float, ins: bool) -> Color:
			return le_d.darkened(0.3) if ins else P._fs(le_c, float(sf.call(s, a)) - 0.018, 20.0).lightened(0.05 * pow(maxf(0.0, cos(a)), 3.0)), 0.0, 0.9, 30, 18)
		# kol ağzı kürkü
		var cuff := []
		var d: Vector3 = P._ld(ar, 0.9)
		var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri: Vector3 = (-d).cross(fw).normalized()
		for i in 26:
			var t: float = TAU * i / 26.0
			cuff.append(P._lp(ar, 0.9) + (ri * sin(t) + fw * cos(t)) * (P._lr(ar, 0.9) + 0.02))
		var cb: Array = P._lskin(ar, 0.9)
		_fur(k, cuff, 0.019, fu, func(_p: Vector3) -> Array: return cb, sg)
		P._lt(k, ar, func(_s: float, _a: float) -> float: return 0.004, func(_s: float, _a: float, ins: bool) -> Color: return le_d.darkened(0.3) if ins else le_d, 0.88, 0.97, 6, 12)
		# dirsek yaması ve kol kayışı
		_lpatch(k, ar, en * 0.86, en * 1.14, 2.3, 3.9, sf, le_d, mt.darkened(0.25))
		k.wrap_turn(P._lp(ar, en * 0.58), P._ld(ar, en * 0.58), P._lr(ar, en * 0.58) + 0.022, 0.0085, 0.0, le_d, P._lskin(ar, en * 0.58))
		# pantolon: çapraz sargılı, dizde dolgu
		var pa: Callable = _pants(k, le, pn, 0.016, 0.022, 1.0, sg)
		P._wraps(k, le, kn + 0.08, 0.965, 13, float(pa.call(0.85, 0.0)) + 0.008, 0.0145, wr, 0.016)
		P._wraps(k, le, kn * 0.42, kn * 0.82, 7, float(pa.call(kn * 0.6, 0.0)) + 0.006, 0.0105, wr.darkened(0.14), 0.014)
		for s2: float in [kn + 0.08, 0.72]:
			k.wrap_turn(P._lp(le, s2), P._ld(le, s2), P._lr(le, s2) + float(pa.call(s2, 0.0)) + 0.0135, 0.0065, 0.0, le_d, P._lskin(le, s2))
		# bilekte kürk: kar çizmesinin ağzı
		var ank := []
		var d2: Vector3 = P._ld(le, 0.975)
		var f2: Vector3 = (Vector3.BACK - d2 * d2.dot(Vector3.BACK)).normalized()
		var r2: Vector3 = (-d2).cross(f2).normalized()
		for i in 26:
			var t: float = TAU * i / 26.0
			ank.append(P._lp(le, 0.975) + (r2 * sin(t) + f2 * cos(t)) * (P._lr(le, 0.975) + 0.022))
		var lb: Array = P._lskin(le, 0.975)
		_fur(k, ank, 0.02, fu, func(_p: Vector3) -> Array: return lb, sg + 1.0)
	# deri ceket: kalça boyu, çift sıra düğmeli bindirme, omuz yoku
	var hem0: float = H - 0.13
	var keys := [P._kp(nk, N + 0.01, 0.03), [N - 0.055, ch.x * 1.01, ch.y * 0.97, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(hp, H - 0.03, 0.044), [hem0, hp.x + 0.05, hp.y + 0.05, hp.z - 0.05]]
	var hs := func(p: Vector3) -> Array: return k.cloth_skin(p, hem0, 0.5)
	var ff := func(a: float, y: float, _v: float) -> float:
		var aa: float = absf(a)
		var pn2: float = -0.016 * exp(-pow((aa - 1.15) / 0.05, 2.0)) - 0.016 * exp(-pow((aa - 2.2) / 0.05, 2.0))
		var yk: float = -0.012 * exp(-pow((y - (C + 0.03)) / 0.008, 2.0))
		return pn2 + yk + 0.008 * sin(a * 5.0 + y * 9.0) * smoothstep(C, H, y)
	var jg: Dictionary = P._cl(k, {"keys": keys, "ny": 46, "na": 96, "top": func(_a: float) -> float: return N + 0.01, "hem": func(_a: float) -> float: return hem0, "fold": ff, "col": func(a: float, y: float, _v: float) -> Color:
		return le_c.lightened(0.05 * pow(maxf(0.0, sin(a * 2.0 + y * 3.0)), 3.0)), "gain": 8.0, "th": 0.006, "inner": le_d, "skin": hs})
	P._bd(k, _yl(jg["hem"], 0.011), 0.0095, 0.003, le_d, true, hs)
	# bindirme kanadı + düğmeler
	var fl := []
	var fo := []
	for i in 19:
		var y: float = lerpf(N - 0.06, hem0 + 0.004, float(i) / 18.0)
		var e: Array = P._fp(keys, 0.03, y, true, 0.003)
		fl.append(e[0])
		fo.append(e[1])
	k.strip(fl, fo, 0.05, 0.0058, le_c.lightened(0.03), false, hs)
	var el := []
	for p: Vector3 in fl:
		el.append(p + Vector3(-0.052, 0.0, 0.006))
	P._bd(k, el, 0.0034, 0.002, le_d, false, hs)
	for i in 5:
		var y: float = lerpf(N - 0.1, H + 0.01, float(i) / 4.0)
		for x: float in [-0.022, 0.066]:
			var q: Array = P._fp(keys, x, y, true, 0.0095)
			P._stud(k, q[0], q[1], 0.0088, mt, k.torso_skin(y))
	for sg: float in [1.0, -1.0]:
		var ax: float = sg * wa.x * 0.62
		P._patch(k, keys, ax - 0.052, ax + 0.052, H - 0.01, H - 0.1, true, 0.005, le_c.darkened(0.08), 0.1, 10, 8, hs)
		P._patch(k, keys, ax - 0.056, ax + 0.056, H + 0.005, H - 0.022, true, 0.0075, le_d, 0.14, 10, 4, hs)
	# kemer
	var bk := [P._kp(wa, H + 0.1, 0.044), P._kp(k.M(H + 0.0, 0.3), H - 0.02, 0.048)]
	P._sash(k, bk, H + 0.042, 0.021, 0.0, li.lightened(0.05), 0.1)
	var bf: Array = P._sa(bk, 0.0, H + 0.042, 0.012)
	P._boxr(k, bf[0], Vector3(0.026, 0, 0), Vector3(0, 0.022, 0), (bf[1] as Vector3) * 0.006, mt, [["Hips", 1.0]], 0.3)
	# gece pelerini: omuzlardan baldıra, önü açık, kol önde serbest
	var wd: float = ch.x + 0.1
	var hem1: float = lerpf(k.K, k.F, 0.5)
	var ck := [[N + 0.03, nk.x + 0.06, nk.y + 0.04, nk.z - 0.06], [N - 0.012, nk.x + 0.098, nk.y + 0.05, nk.z - 0.088], [N - 0.075, wd * 0.97, ch.y + 0.03, ch.z - 0.07], [C - 0.06, wd, ch.y + 0.035, ch.z - 0.105], [H + 0.04, wd * 0.99, wa.y + 0.09, minf(ch.z, wa.z) - 0.125], [k.K, wd * 1.07, hp.y + 0.12, hp.z - 0.2], [hem1, wd * 1.14, hp.y + 0.13, hp.z - 0.25]]
	var er := func(v: float) -> Vector2:
		var e: float = lerpf(1.08, 1.62, smoothstep(0.0, 0.24, v))
		return Vector2(e, TAU - e)
	var cf := func(a: float, y: float, v: float) -> float:
		var t: float = clampf((H + 0.2 - y) / (H + 0.2 - hem1), 0.0, 1.0)
		return t * (0.055 * sin(a * 7.0 + 0.4) + 0.026 * sin(a * 13.0 + 1.2)) + 0.004 * sin(a * 5.0 + y * 7.0) + 0.0 * v
	var cs := func(p: Vector3) -> Array: return _rear_skin(k, p, hem1, wd)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 50, "na": 92, "rng": er, "top": func(_a: float) -> float: return N + 0.03, "hem": func(a: float) -> float: return hem1 + 0.03 * sin(a * 3.0 + 1.0) * 0.4, "fold": cf, "col": func(_a: float, _y: float, _v: float) -> Color: return nv, "gain": 5.5, "skin": cs, "th": 0.005, "inner": li})
	P._bd(k, _yl(cg["hem"], 0.014), 0.012, 0.003, li.lightened(0.05), false, cs)
	for ed: Array in [cg["ea"], cg["eb"]]:
		P._bd(k, ed.slice(6), 0.008, 0.0028, li.lightened(0.05), false, cs)
	# kürk yaka: üç kat kalın rulo, pelerini boyunda tutar
	var skt := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	for e3: Array in [[N + 0.022, 0.06, 0.036, 0.0], [N - 0.022, 0.085, 0.042, 2.1], [N + 0.058, 0.04, 0.028, 4.0]]:
		var pts := []
		for i in 58:
			var t: float = TAU * i / 58.0 - PI
			var q: Vector2 = SE.El.sup(t, nk.x + float(e3[1]), nk.y + float(e3[1]) * 0.86, nk.z - float(e3[1]) * 1.05)
			var lf: float = -0.018 * exp(-pow(t / 0.42, 2.0)) * (1.0 if float(e3[0]) > N else 0.5)
			pts.append(Vector3(q.x, float(e3[0]) + lf, q.y))
		_fur(k, pts, float(e3[2]), fu.darkened(0.04 * (2.0 if float(e3[3]) > 3.0 else 0.0)), skt, float(e3[3]))


# ------------------------------------------------------------------ Matsuri yukata: çizgili lacivert, sol kanat üstte, torba kol, krem hanhaba obi ve arkada düğüm (kadında bunko fiyonk), bileğe inen düz boy
static func _matsuri(k) -> void:
	var nv := Color(0.28, 0.36, 0.62)
	var cr := Color(0.9, 0.86, 0.78)
	var ob := Color(0.9, 0.86, 0.78)
	var ln := Color(0.16, 0.2, 0.36)
	var pn := Color(0.2, 0.22, 0.3)
	var skin_c: Color = k.m.look["skin"]
	var fem: bool = String(k.m.look.get("gender", "m")) == "f"
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_inner_v(k, b, cr.lightened(0.1))
	_seat(k, b, pn)
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		_pants(k, le, pn, -0.01, 0.0, 1.0, 1.3 if sd == "Left" else 3.9, 0.012)   # etek altında ince: geri giden bacak kumaşı zorlamaz
		P._bare(k, ar, skin_c, en * 0.7, 0.97)
		# torba kol (tamoto): dikdörtgen sarkar, ağzı bileğe doğru daralır
		var stripe := func(a: float) -> bool: return fposmod((a + PI) / TAU * 10.0, 1.0) < 0.36
		_wide(k, ar, func(s: float) -> float: return 0.054 + 0.018 * smoothstep(0.05, 0.3, s), func(s: float) -> float: return 0.1 * smoothstep(0.36, 0.52, s), func(s: float, a: float) -> float: return 0.035 * sin(a * 3.0 + s * 7.0), func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return ln
			var c0: Color = cr.darkened(0.04) if stripe.call(a) else nv
			return P._fs(c0, 0.012 * sin(a * 3.0 + s * 7.0), 7.0), 0.86, 0.72, P._lr(ar, 0.86) + 0.03, 30, 60)
	# gövde: arkada dikiş, önde sol kanat sağın üstüne biner, bileğe iner
	var hem0: float = k.F + 0.135
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.02), P._kp(hp, H - 0.04, 0.042), [k.K + 0.05, hp.x + 0.012, hp.y + 0.05, hp.z - 0.09], [hem0, hp.x - 0.012, hp.y + 0.05, hp.z - 0.115]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem0), 0.0, 1.0)
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		var blouse: float = 0.026 * exp(-pow((y - (H + 0.15)) / 0.04, 2.0))
		return t * (0.022 * sin(a * 5.0 + 0.4) + 0.012 * sin(a * 9.0 + 1.7)) + (1.0 - up) * 0.006 * sin(a * 7.0 + y * 10.0) * smoothstep(0.0, 0.1, up) + blouse
	var wg: Dictionary = _wrap(k, {"keys": keys, "hem": hem0, "col": func(_a: float, _y: float, v: float) -> Color: return nv.darkened(0.12 * smoothstep(0.96, 1.0, v)), "fold": fold, "band": ln, "band_w": 0.017, "band_y": H + 0.1, "juban": cr.lightened(0.5), "ny": 70, "na": 60, "gain": 4.5, "inner": ln})
	# çizgiler: kumaşın üstünde gerçek ince şerit, kıvrımı izler
	for lf: bool in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		var rows: Array = g["rows"]
		var ny: int = rows.size() - 1
		var skin := func(p: Vector3) -> Array: return _wrap_skin(k, p, hem0, lf)
		var i := 3
		while i < 58:
			var pts := []
			var j := 1
			while j < ny:
				var p: Vector3 = rows[j][i]
				if p.y > H + 0.135 or p.y < H - 0.02:   # obi altında çizgi kurulmaz
					pts.append(p + Vector3(p.x, 0.0, p.z).normalized() * 0.0012)
				elif pts.size() >= 2:
					P._bd(k, pts, 0.0034, 0.0009, cr, false, skin)
					pts = []
				else:
					pts = []
				j += 2
			if pts.size() >= 2:
				P._bd(k, pts, 0.0034, 0.0009, cr, false, skin)
			i += 4
	# etek ucu biyesi
	for lf: bool in [true, false]:
		var g2: Dictionary = wg["L" if lf else "R"]
		P._bd(k, _yl(g2["hem"], 0.01), 0.007, 0.0022, ln, false, func(p: Vector3) -> Array: return _wrap_skin(k, p, hem0, lf))
	# obi: kalın katlı kuşak + arka düğüm
	var bk := [P._kp(wa, H + 0.15, 0.036), P._kp(wa, H + 0.0, 0.05)]
	var by: float = H + 0.075
	P._sash(k, bk, by, 0.058, 0.002, ob, 0.1)
	var tw := [P._kp(wa, H + 0.15, 0.052), P._kp(wa, H + 0.0, 0.066)]
	P._cord(k, P._ring_pts(tw, by + 0.002, 0.0, 72), 0.0042, nv.darkened(0.15), true, func(p: Vector3) -> Array: return k.torso_skin(p.y), 0.0, 6)
	var bq: Array = P._sa(bk, PI, by, 0.03)
	var c0: Vector3 = bq[0]
	var hip: Array = [["Hips", 0.4], ["Spine", 0.6]]
	if fem:   # bunko: iki kanat, ortada düğüm, aşağı sarkan iki uç
		for sg: float in [1.0, -1.0]:
			P._boxr(k, c0 + Vector3(sg * 0.1, 0.008, -0.01), Vector3(0.09, sg * 0.02, 0), Vector3(-sg * 0.012, 0.055, 0), Vector3(0, 0, -0.022), ob.darkened(0.04), hip, 0.34)
			P._boxr(k, c0 + Vector3(sg * 0.035, -0.09, -0.006), Vector3(0.036, 0, 0), Vector3(sg * 0.01, 0.075, 0), Vector3(0, 0, -0.012), ob.darkened(0.1), hip, 0.28)
		P._boxr(k, c0 + Vector3(0, 0.004, -0.024), Vector3(0.028, 0, 0), Vector3(0, 0.05, 0), Vector3(0, 0, -0.018), ob.lightened(0.04), hip, 0.3)
	else:   # kai no kuchi: yassı yatay düğüm, iki kısa kanat
		P._boxr(k, c0 + Vector3(0.0, 0.004, -0.012), Vector3(0.1, 0.014, 0), Vector3(-0.012, 0.04, 0), Vector3(0, 0, -0.02), ob.darkened(0.05), hip, 0.32)
		P._boxr(k, c0 + Vector3(-0.012, 0.004, -0.03), Vector3(0.026, 0, 0), Vector3(0.004, 0.044, 0), Vector3(0, 0, -0.012), ob.lightened(0.03), hip, 0.3)
