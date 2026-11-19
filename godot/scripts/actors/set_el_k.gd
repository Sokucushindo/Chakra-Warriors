extends RefCounted
## Elle modellenmiş setler, parti k: set_kumo_jonin, set_iwa_chunin, set_iwa_jonin, set_akatsuki, set_tabibito, set_iryonin.
## Kumaş / uzuv yardımcıları parti e'den (P); burada yalnız bu setlere özgü olanlar: uzuv kabuğu, palto ağı, gerçek kenarlı bulut.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")

const DONE := ["set_kumo_jonin", "set_iwa_chunin", "set_iwa_jonin", "set_akatsuki", "set_tabibito", "set_iryonin"]


static func recipe(k, sid: String) -> void:
	P._cur_long = false
	P._cur_leg = 0.58
	match sid:
		"set_kumo_jonin": _kumo_jonin(k)
		"set_iwa_chunin": _iwa(k, false)
		"set_iwa_jonin": _iwa(k, true)
		"set_akatsuki": _akatsuki(k)
		"set_tabibito": _tabibito(k)
		"set_iryonin": _iryonin(k)


# ------------------------------------------------------------------ uzuv yardımcıları
## Uzuv yüzeyinde nokta: [konum, dış yön]
static func _lsurf(l: Dictionary, s: float, a: float, add: float) -> Array:
	var d: Vector3 = P._ld(l, s)
	var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri: Vector3 = (-d).cross(fw).normalized()
	var o: Vector3 = ri * sin(a) + fw * cos(a)
	return [P._lp(l, s) + o * (P._lr(l, s) + add), o]


## Uzvu kısmen saran sert kabuk (kaval, kolluk, diz): kesit kapalı, kenarları gerçek kalınlıkta
static func _shell(k, l: Dictionary, s0: float, s1: float, a0: float, a1: float, addf: Callable, th: float, colf: Callable, ns := 14, na := 16) -> void:
	var rows := []
	var ss := []
	var cc := []
	for j in ns + 3:
		var e: int = clampi(j - 1, 0, ns)
		var v := float(e) / ns
		var s := lerpf(s0, s1, v)
		var cap: bool = j == 0 or j == ns + 2
		var ro := []
		var cr := []
		var nn := na + 1
		for side in 2:
			for i in nn:
				var u := float(i) / na if side == 0 else 1.0 - float(i) / na
				var a := lerpf(a0, a1, u)
				var edge := minf(u, 1.0 - u) * (a1 - a0)
				var round_e := smoothstep(0.0, 0.16, edge)
				var ad: float = float(addf.call(s, a))
				var h: float = 0.0 if side == 1 or cap else th * lerpf(0.35, 1.0, round_e)
				ro.append(_lsurf(l, s, a, ad + h)[0])
				cr.append(colf.call(u, v, side == 1 or cap))
		rows.append(ro)
		ss.append(s)
		cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, j, _p): return P._lskin(l, ss[j]))


## Uzuv tüpünün iç yüzü: içine bakınca görünen astar (normal içe)
static func _lt_in(k, l: Dictionary, addf: Callable, col: Color, s0: float, s1: float, n := 16, seg := 18) -> void:
	var rows := []
	var ss := []
	for j in n + 1:
		var s := lerpf(s1, s0, float(j) / n)
		var d: Vector3 = P._ld(l, s)
		var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri: Vector3 = (-d).cross(fw).normalized()
		var ro := []
		for i in seg:
			var a := TAU * i / seg - PI
			var r: float = P._lr(l, s) + float(addf.call(s, a))
			ro.append(P._lp(l, s) + ri * sin(a) * r + fw * cos(a) * r)
		rows.append(ro)
		ss.append(s)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.3 * float(j) / n), func(_i, j, _p): return P._lskin(l, ss[j]))


## Pantolon: dizde pay, altında daralır; addf ve renk aynı kıvrımdan
static func _pant(k, le: Dictionary, col: Color, base: float, bag: float, s1: float, sd := 2.0) -> Callable:
	var kn: float = le["kn"]
	var pa := func(s: float, a: float) -> float:
		var fo: float = 1.0 - smoothstep(kn + 0.1, kn + 0.26, s)
		var cr: float = exp(-pow((s - kn) / 0.075, 2.0)) * sin(a * 3.0 + s * 34.0 + sd)
		return base + bag * exp(-pow((s - kn + 0.1) / 0.17, 2.0)) - 0.006 * smoothstep(kn + 0.12, kn + 0.3, s) + fo * 0.005 * P._lf(s, a, sd) + 0.0042 * cr
	P._lt(k, le, pa, func(s, a, ins):
		return col.darkened(0.42) if ins else P._fs(col, float(pa.call(s, a)) - base - bag * 0.4, 9.0), 0.0, s1, 38, 20)
	return pa


## Parmaksız eldiven: bilek ağzı + el sırtı + avuç bandı
static func _glove(k, sd: String, ar: Dictionary, col: Color, pl: Color) -> void:
	var hd: Vector3 = k.m._bp(sd + "Hand")
	var el: Vector3 = k.m._bp(sd + "LowerArm")
	var d: Vector3 = (hd - el).normalized()
	P._lt(k, ar, func(s, _a): return 0.0115 + 0.0045 * smoothstep(0.9, 0.86, s), func(_s, _a, ins): return col.darkened(0.4) if ins else col, 0.84, 0.99, 8, 18)
	var w: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var t: Vector3 = d.cross(w).normalized()
	var rows := []
	var skin_h := [[sd + "Hand", 1.0]]
	for e in [[-0.012, 0.031, 0.026], [0.02, 0.043, 0.025], [0.055, 0.051, 0.024], [0.08, 0.051, 0.022], [0.09, 0.045, 0.016], [0.084, 0.03, 0.008]]:
		var ro := []
		for i in 16:
			var a := TAU * i / 16.0 - PI
			ro.append(hd + d * float(e[0]) + w * cos(a) * float(e[1]) + t * sin(a) * float(e[2]))
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.3) if j >= 4 else col, func(_i, _j, _p): return skin_h)
	var o2: Vector3 = t if t.y > 0.0 else -t
	P._boxr(k, hd + d * 0.048 + o2 * 0.0245, w * 0.03, d * 0.022, o2 * 0.0045, pl, skin_h, 0.25)


static func _torso_keys(k, b: Dictionary, p: float, y1: float, py1: float) -> Array:
	var ch: Vector3 = b["ch"]
	return [P._kp(b["nk"], k.N + 0.01, 0.03), [k.N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], P._kp(ch, k.C - 0.03, p), P._kp(b["wa"], k.H + 0.12, p), P._kp(k.M(y1, 0.3), y1, py1)]


## Kalça astarı (pantolon üstü)
static func _seat(k, b: Dictionary, col: Color) -> void:
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = k.M(k.H + 0.05, 0.3)
	SE.body_layer(k, [P._kp(bl, k.H + 0.09, 0.006), P._kp(hp, k.H - 0.05, 0.016), [k.H - 0.15, hp.x * 0.76, hp.y * 0.78, hp.z * 0.78]], 8, 34, func(_i, _j, _p): return col)


static func _yl(pts: Array, up: float) -> Array:
	var o := []
	for p in pts:
		o.append((p as Vector3) + Vector3(0, up, 0))
	return o


## 医 damgası: halka + yazı, kabartma (parça yüzeye oturur)
static func _i_mark(k, keys: Array, cx: float, cy: float, r: float, col: Color, front: bool) -> void:
	var pts := []
	var ou := []
	for i in 40:
		var t := TAU * i / 40.0
		var e: Array = P._fp(keys, cx + cos(t) * r, cy + sin(t) * r, front, 0.0025)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, r * 0.085, 0.0018, col, true, func(p: Vector3) -> Array: return k.torso_skin(p.y))
	var st := [[-0.8, 0.8, 0.8, 0.8], [-0.8, 0.8, -0.8, -0.8], [-0.8, -0.8, 0.85, -0.8], [-0.34, 0.62, -0.5, 0.28], [-0.44, 0.42, 0.55, 0.42], [-0.6, 0.03, 0.66, 0.03], [0.03, 0.42, 0.03, 0.03], [0.03, 0.03, -0.55, -0.56], [0.03, 0.03, 0.6, -0.56]]
	P._glyph(k, keys, cx, cy, r * 0.56, st, r * 0.052, col, front, 0.0028)


# ------------------------------------------------------------------ Kumo Jōnin (ref Darui, Hachibi_subduing_team): lacivert uzun kollu takım, sol omuzdan tek kayışla asılı, sağ koltuk altına verev kesilen beyaz sert göğüslük, beyaz kaval ve kolluk
static func _kumo_jonin(k) -> void:
	var nv := Color(0.12, 0.14, 0.24)
	var wh := Color(0.86, 0.86, 0.83)
	var gr := Color(0.56, 0.57, 0.58)
	var dk := Color(0.09, 0.1, 0.17)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return nv)
	_seat(k, b, nv.darkened(0.12))
	var tk := _torso_keys(k, b, 0.014, H + 0.0, 0.022)
	var tf := func(a: float, y: float, _v: float) -> float:
		return 0.005 * sin(a * 5.0 + y * 13.0) * smoothstep(N - 0.05, C - 0.05, y)
	P._cl(k, {"keys": tk, "ny": 26, "na": 72, "top": func(_a): return N + 0.01, "hem": func(_a): return H + 0.0, "fold": tf, "col": func(_a, _y, _v): return nv, "skin": func(p): return k.torso_skin(p.y), "th": 0.0})
	# dik yaka: iki kat, önde dikişli
	var ck := [P._kp(nk, N + 0.095, 0.016), P._kp(nk, N + 0.0, 0.03)]
	var cg := P._cl(k, {"keys": ck, "ny": 7, "na": 40, "rng": func(_v): return Vector2(0.1, TAU - 0.1), "top": func(a): return N + 0.075 + 0.012 * smoothstep(0.1, 1.6, absf(float(a))), "hem": func(_a): return N - 0.006, "fold": func(_a, y, _v): return 0.02 * sin((float(y) - N) * 70.0), "col": func(_a, _y, _v): return nv.lightened(0.05), "skin": func(p): return k.torso_skin(p.y), "gain": 3.0, "th": 0.005})
	P._bd(k, cg["top"], 0.0045, 0.0025, dk, false, Callable(), 0.5)
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.0026 * P._lf(s, a, 1.3) + 0.0046 * exp(-pow((s - en) / 0.075, 2.0)) * sin(a * 3.0 + s * 36.0) + 0.003 * exp(-pow((s - 0.12) / 0.1, 2.0))
		P._lt(k, ar, func(s, a): return 0.008 + float(sf.call(float(s), float(a))), func(s, a, ins):
			return nv.darkened(0.45) if ins else P._fs(nv, float(sf.call(float(s), float(a))), 30.0), 0.0, 0.965, 30, 18)
		# ön kol kolluğu ve kol bandı (rütbe)
		_shell(k, ar, en + 0.1, 0.92, -1.45, 1.45, func(s, _a): return 0.012 + 0.008 * smoothstep(0.6, 0.95, float(s)), 0.0055, func(u, v, ins):
			var ed: float = minf(minf(u, 1.0 - u) * 5.0, minf(v, 1.0 - v) * 8.0)
			return wh.darkened(0.45) if ins else (gr if ed < 0.3 else wh), 12, 14)
		P._wraps(k, ar, en + 0.14, 0.88, 2, 0.0155, 0.007, dk, 0.0)
		P._lt(k, ar, func(_s, _a): return 0.0125, func(_s, _a, ins): return gr if ins else wh, 0.25, 0.3, 3, 18)
		# bol pantolon, baldırda sıkılır
		var kn: float = le["kn"]
		var pa: Callable = _pant(k, le, nv, 0.014, 0.02, 1.0, 2.2)
		# beyaz kaval: dizden bileğe, üstü diz kapağına kavis yapar
		var sa := func(s: float, _a: float) -> float: return float(pa.call(s, 0.0)) + 0.002
		var kg := func(u: float, v: float, ins: bool) -> Color:
			if ins:
				return wh.darkened(0.45)
			var rib: float = absf(u - 0.5)
			return gr if rib < 0.018 or minf(u, 1.0 - u) < 0.07 or minf(v, 1.0 - v) < 0.05 else wh
		_shell(k, le, kn + 0.05, 0.94, -1.25, 1.25, sa, 0.0075, kg, 18, 18)
		for s2 in [kn + 0.11, 0.86]:
			k.wrap_turn(P._lp(le, s2), P._ld(le, s2), P._lr(le, s2) + float(pa.call(s2, 0.0)) + 0.0035, 0.0085, 0.0, dk, P._lskin(le, s2))
		P._wraps(k, le, 0.955, 0.985, 2, 0.008, 0.008, dk, 0.0)
		if sd == "Right":   # uyluk kılıfı
			var s0: float = kn * 0.52
			var pp: float = float(pa.call(s0, 0.0))
			for dv in [-0.05, 0.05]:
				k.wrap_turn(P._lp(le, s0 + dv), P._ld(le, s0), P._lr(le, s0 + dv) + pp + 0.006, 0.0095, 0.0, dk, P._lskin(le, s0))
			var e: Array = _lsurf(le, s0, -PI * 0.5, pp + 0.02)
			var o: Vector3 = e[1]
			var d: Vector3 = P._ld(le, s0)
			P._boxr(k, e[0], o.cross(d).normalized() * 0.04, -d * 0.062, o * 0.019, dk.lightened(0.05), [["RightUpperLeg", 1.0]])
	# göğüslük: sağ koltuk altından sol omza, oradan arkadan dolanır
	var pk := []
	for e in tk:
		pk.append([e[0], float(e[1]) + 0.013, float(e[2]) + 0.015, float(e[3]) - 0.014])
	var a0 := -1.42
	var ys := N - 0.035
	var sx: float = ch.x * 0.66   # kayış omuz eğiminde durur, yakaya çıkmaz
	var a1: float = asin(clampf(pow(sx / float(SE.El.key_at(pk, ys)[1]), 1.25), 0.0, 0.98))
	var a2: float = PI - a1
	var a3 := TAU - 1.72
	var yr := H + 0.21
	var ya := C - 0.075
	var pt := func(a: float) -> float:
		var q: float = a if a > a0 - 0.01 else a + TAU
		if q <= a1:
			return lerpf(yr, ys, pow(clampf((q - a0) / (a1 - a0), 0.0, 1.0), 1.15))
		if q <= a2:
			var m: float = absf((q - a1) / (a2 - a1) - 0.5) * 2.0
			return lerpf(ya, ys, smoothstep(0.35, 1.0, m))
		return lerpf(ys, yr, pow(clampf((q - a2) / (a3 - a2), 0.0, 1.0), 0.86))
	var yh := H + 0.065
	var af := func(a: float, y: float, _v: float) -> float:
		var aa: float = absf(a)
		var g: float = -0.05 * exp(-pow((y - (H + 0.135)) / 0.006, 2.0)) - 0.05 * exp(-pow((y - (H + 0.2)) / 0.006, 2.0))
		g += -0.04 * exp(-pow((aa - 0.92) / 0.03, 2.0)) * smoothstep(C + 0.02, C - 0.05, y)
		return g + 0.012 * smoothstep(C + 0.12, C - 0.02, y) * smoothstep(H + 0.1, C - 0.05, y) * cos(aa * 1.4)
	var pg := P._cl(k, {"keys": pk, "ny": 44, "na": 112, "rng": func(_v): return Vector2(a0, a3), "top": func(a): return pt.call(float(a)), "hem": func(_a): return yh, "fold": af, "col": func(_a, _y, _v): return wh, "gain": 6.0, "skin": func(p): return k.torso_skin(p.y), "th": 0.006, "inner": gr.darkened(0.3)})
	P._bd(k, pg["top"], 0.0065, 0.0034, gr, false, func(p): return k.torso_skin(p.y), 0.25)
	P._bd(k, pg["hem"], 0.0065, 0.0034, gr, false, func(p): return k.torso_skin(p.y))
	P._bd(k, pg["ea"], 0.0065, 0.0034, gr, false, func(p): return k.torso_skin(p.y))
	P._bd(k, pg["eb"], 0.0065, 0.0034, gr, false, func(p): return k.torso_skin(p.y))
	# yan kapanış: sağ koltuk altında iki bağ, kumaşın üstünden geçer
	for y2 in [H + 0.11, H + 0.17]:
		var q0: Vector3 = P._sa(pk, a0 + 0.1, y2, 0.004)[0]
		var q1: Vector3 = P._sa(pk, -1.57, y2 - 0.006, 0.006)[0]
		var q2: Vector3 = P._sa(pk, a3 - TAU - 0.1, y2, 0.004)[0]
		P._bd(k, [q0, q0.lerp(q1, 0.5), q1, q1.lerp(q2, 0.5), q2], 0.0085, 0.003, dk, false, func(p): return k.torso_skin(p.y))
	# tek omuz kayışı: kalın, sırtta ve önde göğüslüğe biner, tokalı
	var yo: float = N + 0.01
	while yo > ys and float(SE.El.key_at(tk, yo)[1]) < sx + 0.006:
		yo -= 0.003
	var fp0: Vector3 = P._fp(pk, sx, ys - 0.012, true, 0.001)[0]
	var bp0: Vector3 = P._fp(pk, sx, ys - 0.012, false, 0.001)[0]
	var ctl := Vector3(sx, 2.0 * (yo + 0.014) - (ys - 0.012), (fp0.z + bp0.z) * 0.5)
	var arc_c := Vector3(sx, ys - 0.045, ctl.z)
	var sp := []
	var so := []
	for j in 19:
		var t := float(j) / 18.0
		var q: Vector3 = fp0.lerp(ctl, t).lerp(ctl.lerp(bp0, t), t)
		sp.append(q)
		so.append((q - arc_c).normalized())
	k.strip(sp, so, 0.038, 0.0065, wh, false, func(p): return k.torso_skin(minf(float(p.y), N - 0.02)))
	var s2 := []
	for j in sp.size():
		s2.append((sp[j] as Vector3) + (so[j] as Vector3) * 0.0062)
	k.strip(s2, so, 0.027, 0.0014, wh.darkened(0.08), false, func(p): return k.torso_skin(minf(float(p.y), N - 0.02)))
	var bc: Array = P._fp(pk, sx, N - 0.075, true, 0.009)
	P._boxr(k, bc[0], Vector3(0.024, 0, 0), Vector3(0, 0.017, 0), (bc[1] as Vector3) * 0.0055, gr, [["UpperChest", 1.0]], 0.3)
	P._boxr(k, (bc[0] as Vector3) + (bc[1] as Vector3) * 0.0055, Vector3(0.012, 0, 0), Vector3(0, 0.0075, 0), (bc[1] as Vector3) * 0.0025, dk, [["UpperChest", 1.0]], 0.3)
	# göğüste köşeli ok şeritleri (ref: Darui göğüslüğü) + karın cebi
	for i in 3:
		var y3: float = C - 0.11 - i * 0.027
		P._line(k, pk, [Vector2(0.34, y3 + 0.024), Vector2(0.58, y3), Vector2(0.82, y3 + 0.024)], 0.0052, 0.002, 0.0026, gr, 4)
	P._patch(k, pk, -0.075, 0.075, H + 0.128, H + 0.075, true, 0.012, wh.darkened(0.04), 0.14, 12, 7, func(p): return k.torso_skin(p.y))
	var sq: Array = P._fp(pk, 0.0, H + 0.104, true, 0.0135)
	P._stud(k, sq[0], sq[1], 0.0065, gr, [["Spine", 1.0]])
	# bel kuşağı ve tepe dikişleri
	var bk := [P._kp(k.M(H + 0.05, 0.3), H + 0.1, 0.026), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.03)]
	P._sash(k, bk, H + 0.042, 0.021, 0.003, dk.lightened(0.04), 0.14)
	P._hole(k, tk, -1.0, C + 0.0, 0.46, 0.09, 0.005, 0.002, dk)


# ------------------------------------------------------------------ Iwa takımı (ref Kurotsuchi_Part_II, Kurotsuchi_Online, Akatsuchi): kızıl dik boğazlı iç, tek kızıl kol, kırmızı pantolon, file baldır, omuzlu kahve yelek + karın ruloları. Jōnin: koyu yelek, üç rulo, perçinli omuzluk, arka peşkir, parmaksız eldiven
static func _iwa(k, jonin: bool) -> void:
	var rd := Color(0.56, 0.15, 0.17) if not jonin else Color(0.48, 0.12, 0.15)
	var br := Color(0.36, 0.28, 0.19) if not jonin else Color(0.25, 0.19, 0.13)
	var bd := br.darkened(0.3)
	var nt := Color(0.13, 0.12, 0.12)
	var mt := Color(0.68, 0.62, 0.5)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return rd.darkened(0.08), 0.008)
	_seat(k, b, rd.darkened(0.16))
	# kıvrık dik boğaz
	var nc := [P._kp(nk, N + 0.1, 0.014), P._kp(nk, N + 0.0, 0.022)]
	P._cl(k, {"keys": nc, "ny": 8, "na": 40, "top": func(_a): return N + 0.088, "hem": func(_a): return N - 0.004, "fold": func(a, y, _v): return 0.03 * sin((float(y) - N) * 66.0) + 0.008 * sin(float(a) * 5.0), "col": func(_a, _y, _v): return rd, "gain": 3.0, "skin": func(p): return k.torso_skin(p.y), "th": 0.004})
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		if sd == "Left":   # tek kol kızıl
			var sf := func(s: float, a: float) -> float: return 0.0024 * P._lf(s, a, 1.1) + 0.0044 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 38.0)
			P._lt(k, ar, func(s, a): return 0.008 + float(sf.call(float(s), float(a))), func(s, a, ins):
				return rd.darkened(0.45) if ins else P._fs(rd, float(sf.call(float(s), float(a))), 32.0), 0.0, 0.965 if not jonin else 0.9, 30, 18)
			P._wraps(k, ar, 0.9 if not jonin else 0.84, 0.95 if not jonin else 0.88, 2, 0.011, 0.006, rd.darkened(0.3), 0.0)
		else:
			P._bare(k, ar, skc)
			# açık omuz: iç giysinin kısa, kola oturan ağzı
			P._lt(k, ar, func(s, _a): return 0.005 - 0.012 * (1.0 - smoothstep(0.0, 0.06, float(s))), func(_s, _a, ins): return rd.darkened(0.4) if ins else rd.darkened(0.08), 0.0, 0.14, 6, 18)
			k.wrap_turn(P._lp(ar, 0.135), P._ld(ar, 0.135), P._lr(ar, 0.135) + 0.0065, 0.0065, 0.0, rd.darkened(0.3), P._lskin(ar, 0.135))
			if not jonin:
				P._wraps(k, ar, 0.8, 0.95, 5, 0.006, 0.0115, Color(0.82, 0.79, 0.72), 0.005)
		if jonin:
			_glove(k, sd, ar, nt.lightened(0.04), mt.darkened(0.2))
		# kırmızı pantolon dizin altına iner, altı file baldır
		var kn: float = le["kn"]
		P._lt(k, le, func(_s, _a): return 0.002, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc.lerp(Color(0.46, 0.4, 0.37), 0.2), kn + 0.02, 1.0, 16, 16)
		P._net_limb(k, le, kn + 0.08, 0.975, 0.0035, 12, 0.034, 0.0017, nt)
		var cuff: float = kn + 0.115
		var pa: Callable = _pant(k, le, rd, 0.012, 0.022, cuff, 1.4 if sd == "Left" else 3.1)
		k.wrap_turn(P._lp(le, cuff - 0.012), P._ld(le, cuff), P._lr(le, cuff - 0.012) + float(pa.call(cuff, 0.0)) + 0.0035, 0.0125, 0.0, rd.darkened(0.32), P._lskin(le, cuff))
		k.wrap_turn(P._lp(le, 0.982), P._ld(le, 0.982), P._lr(le, 0.982) + 0.0045, 0.009, 0.0, nt, P._lskin(le, 0.982))
		if jonin:   # dizlik: sert deri
			_shell(k, le, kn - 0.055, kn + 0.05, -1.0, 1.0, func(s, a): return float(pa.call(s, a)) * 0.6 + 0.012, 0.0065, func(u, v, ins):
				return bd if ins or minf(minf(u, 1.0 - u) * 3.0, minf(v, 1.0 - v) * 3.0) < 0.22 else br.lightened(0.05), 8, 12)
	# yelek: dikişli yatay dolgular, kol oyukları açık
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var vk := [P._kp(nk, N + 0.012, 0.032), [N - 0.055, ch.x * 1.02, ch.y * 0.94, ch.z * 1.04], P._kp(ch, C - 0.03, 0.034), P._kp(b["wa"], H + 0.12, 0.034), P._kp(bl, H + 0.03, 0.034)]
	var yt: float = H + 0.03
	var qp := 0.05
	var vf := func(a: float, y: float, _v: float) -> float:
		var q: float = absf(sin((y - H) * PI / qp))
		var z: float = exp(-pow(a / 0.04, 2.0))
		var aa: float = absf(a)
		var side: float = 0.02 * exp(-pow((aa - 1.5) / 0.05, 2.0))
		return 0.024 * (pow(q, 0.5) - 0.74) * smoothstep(C + 0.1, C + 0.03, y) - 0.022 * z - side
	var vg := P._cl(k, {"keys": vk, "ny": 62, "na": 92, "top": func(_a): return N + 0.012, "hem": func(_a): return yt, "fold": vf, "col": func(_a, _y, _v): return br, "skin": func(p): return k.torso_skin(p.y), "gain": 5.0, "th": 0.0})
	P._bd(k, vg["top"], 0.009, 0.005, bd, true, func(p): return k.torso_skin(p.y), 0.45)
	P._bd(k, _yl(vg["hem"], 0.006), 0.0075, 0.0045, bd, true, func(p): return k.torso_skin(p.y))
	var zp := []
	for j in 24:
		zp.append(P._sa(vk, 0.0, lerpf(N - 0.012, yt + 0.02, float(j) / 23.0), 0.0015)[0])
	P._bd(k, zp, 0.0042, 0.0026, mt, false, func(p): return k.torso_skin(p.y))
	# kalkık yelek yakası, önü açık
	var vc := [[N + 0.075, nk.x + 0.055, nk.y + 0.052, nk.z - 0.06], [N + 0.0, nk.x + 0.052, nk.y + 0.046, nk.z - 0.052]]
	var cg := P._cl(k, {"keys": vc, "ny": 5, "na": 36, "rng": func(_v): return Vector2(0.48, TAU - 0.48), "top": func(a): return N + 0.03 + 0.042 * smoothstep(0.5, 1.9, absf(float(a))), "hem": func(_a): return N - 0.006, "col": func(_a, _y, _v): return br.lightened(0.04), "skin": func(p): return k.torso_skin(p.y), "th": 0.009})
	P._bd(k, cg["top"], 0.006, 0.0035, bd, false, func(p): return k.torso_skin(p.y), 0.6)
	for sg in [1.0, -1.0]:
		P._hole(k, vk, sg, C + 0.0, 0.46, 0.09, 0.0065, 0.0025, bd)
		# göğüs cebi
		P._patch(k, vk, sg * ch.x * 0.2 - 0.05, sg * ch.x * 0.2 + 0.05, C + 0.015, C - 0.06, true, 0.008, br.lightened(0.05), 0.08, 10, 7, func(p): return k.torso_skin(p.y))
		var pf: Array = P._fp(vk, sg * ch.x * 0.2, C + 0.0, true, 0.0095)
		P._stud(k, pf[0], pf[1], 0.0055, mt, [["UpperChest", 1.0]])
	# karın ruloları: kalın, boğumlu
	var rolls: Array = [H + 0.052, H + 0.095] if not jonin else [H + 0.05, H + 0.09, H + 0.13]
	for i in rolls.size():
		P._roll(k, vk, rolls[i], 0.021 - 0.0015 * i, 16 - i * 2, 0.002, br.darkened(0.03 * i))
	var ybelt: float = rolls[rolls.size() - 1]
	P._patch(k, vk, -0.055, 0.055, ybelt + 0.017, ybelt - 0.022, true, 0.036, br.lightened(0.06), 0.14, 12, 8, func(p): return k.torso_skin(p.y))
	var cf: Array = P._fp(vk, 0.0, ybelt, true, 0.038)
	P._stud(k, cf[0], cf[1], 0.0075, mt, [["Spine", 1.0]])
	# yan kese
	var pe: Array = P._sa(vk, -1.25, H + 0.03, 0.03)
	P._boxr(k, pe[0], Vector3(0.0, 0.0, 0.043).rotated(Vector3.UP, -0.2), Vector3(0, 0.038, 0), (pe[1] as Vector3) * 0.021, bd.lightened(0.08), [["Hips", 1.0]])
	if jonin:
		for sg in [1.0, -1.0]:
			var c0 := Vector3(sg * (ch.x * 0.84 + 0.018), N - 0.022, -0.002)
			var ux := Vector3(sg * 0.07, -0.024, 0.0)
			var uz := Vector3(sg * 0.007, 0.023, 0.0)
			P._boxr(k, c0, ux, Vector3(0.0, 0.0, 0.088), uz, br.lightened(0.04), [["UpperChest", 1.0]], 0.42)
			for z in [0.058, 0.0, -0.058]:
				P._stud(k, c0 + ux * 0.25 + Vector3(0.0, 0.027, z), Vector3(0.0, 1.0, 0.0), 0.0085, mt, [["UpperChest", 1.0]])
		# arka peşkir: kalçadan uyluğa, ön açık
		var lo := [P._kp(bl, H + 0.05, 0.04), P._kp(b["hp"], H - 0.05, 0.05), [H - 0.3, float(b["hp"].x) + 0.07, float(b["hp"].y) + 0.06, float(b["hp"].z) - 0.08], [H - 0.42, float(b["hp"].x) + 0.08, float(b["hp"].y) + 0.07, float(b["hp"].z) - 0.1]]
		var fl := func(a: float, _y: float, v: float) -> float: return float(v) * (0.024 * sin(a * 7.0 + 0.6) + 0.011 * sin(a * 13.0))
		var fg := P._cl(k, {"keys": lo, "ny": 22, "na": 64, "rng": func(_v): return Vector2(1.02, TAU - 1.02), "top": func(_a): return H + 0.035, "hem": func(a):
			var aa: float = PI - absf(float(a))
			return lerpf(H - 0.4, H - 0.23, smoothstep(0.75, 2.1, aa)), "fold": fl, "col": func(_a, _y, _v): return rd.darkened(0.08), "gain": 5.0, "th": 0.005})
		P._tr(k, _yl(fg["hem"], 0.01), 0.005, 0.0022, rd.darkened(0.38))
	var bk := [P._kp(bl, H + 0.07, 0.042), P._kp(bl, H + 0.0, 0.045)]
	P._sash(k, bk, H + 0.022, 0.014, 0.002, bd, 0.12)


# ------------------------------------------------------------------ Akatsuki (ref Itachi_Akatsuki_Mobile, Konan_Initial, Itachi_Joins): içi kırmızı dik yakalı, baldıra inen siyah palto, önü ortadan kapanır; geniş kol; beyaz kenarlı kabartma kızıl bulutlar
## Palto ağırlığı. Ön: bacağı çabuk izler, iki kanat ortadan ayrılır (kanonda palto önden açılır). Arka: ağırlık boy boyunca yavaş artar ve iki bacak arasında geniş geçer:
## geri giden bacak kumaşı kalçaya doğru ezmez, kumaş uzayarak iner.
static func _coat_skin(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.04, -0.07, p.z)
	var wf: float = 0.98 * pow(minf(1.0, t / 0.5), 0.42)
	var wb: float = 0.84 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.004, 0.11, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.16, p.y) * bk * absf(2.0 * s - 1.0) * 0.5
	var sd: String = "Left" if s >= 0.5 else "Right"
	if kb > 0.0:
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Bulut çevresi: daireler birleşimi + kıvrık kuyruk; merkezden ışınla en uzak çıkış
static func _cloud_r(th: float) -> float:
	var d := Vector2(cos(th), sin(th))
	var o := Vector2(0.05, 0.0)
	var best := 0.05
	for c in [[-0.18, 0.1, 0.36], [0.12, 0.34, 0.3], [0.52, 0.22, 0.28], [0.64, -0.12, 0.26], [0.3, -0.37, 0.3], [-0.12, -0.3, 0.28], [-0.46, 0.05, 0.2], [-0.66, 0.13, 0.13], [-0.82, 0.25, 0.08], [-0.93, 0.36, 0.045], [-1.0, 0.45, 0.02]]:
		var q: Vector2 = o - Vector2(c[0], c[1])
		var bb: float = q.dot(d)
		var cc: float = q.length_squared() - float(c[2]) * float(c[2])
		var h: float = bb * bb - cc
		if h >= 0.0:
			best = maxf(best, -bb + sqrt(h))
	return best


## Kızıl bulut: gerçek kalınlıkta, kenarı basamaklı (kırmızı dolgu + beyaz çerçeve + kumaşa inen dış kenar), içinde kıvrım çizgileri.
## surf(u, v, lift) -> [konum, dış yön]; skinf(p)
static func _cloud(k, surf: Callable, skinf: Callable, s: float, rd: Color, wh: Color) -> void:
	var ths := []
	for i in 60:
		ths.append(TAU * i / 60.0 - PI)
	var tail := atan2(0.45, -1.05)
	for i in 22:
		ths.append(wrapf(tail + lerpf(-0.3, 0.3, float(i) / 21.0), -PI, PI))
	ths.sort()
	var h := 0.0048
	var prof := [[0.03, 0.0, h, rd], [0.4, 0.0, h, rd], [0.75, 0.0, h, rd], [0.92, 0.0, h, rd], [0.965, 0.0, h * 0.94, rd], [0.975, 0.0, h * 0.5, wh], [1.0, 0.0065, h * 0.5, wh], [1.0, 0.0105, h * 0.22, wh.darkened(0.12)], [1.0, 0.0125, -0.0015, wh.darkened(0.3)]]
	var rows := []
	var cc := []
	var o := Vector2(0.05, 0.0)
	for e in prof:
		var ro := []
		var cr := []
		for th in ths:
			var d := Vector2(cos(th), sin(th))
			var uv: Vector2 = (o + d * _cloud_r(th) * float(e[0])) * s + d * float(e[1])
			ro.append(surf.call(uv.x, uv.y, float(e[2]))[0])
			cr.append(e[3])
		rows.append(ro)
		cc.append(cr)
	var c0: Array = surf.call(o.x * s, o.y * s, h)
	var fn: Vector3 = -((rows[1][1] as Vector3) - (rows[1][0] as Vector3)).cross((rows[2][1] as Vector3) - (rows[1][0] as Vector3))
	if fn.dot(c0[1]) < 0.0:
		for j in rows.size():
			rows[j].reverse()
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return skinf.call(p))
	for q in [[0.14, 0.34, 0.2, 0.4, 1.35], [0.54, 0.16, 0.19, 2.2, 1.3], [0.24, -0.34, 0.2, -1.4, 1.3], [-0.2, 0.02, 0.2, 2.8, 1.15]]:
		var pts := []
		var ou := []
		for i in 16:
			var v := float(i) / 15.0
			var th: float = float(q[3]) - v * TAU * float(q[4])
			var rr: float = float(q[2]) * lerpf(1.05, 0.14, v)
			var e: Array = surf.call((float(q[0]) + cos(th) * rr) * s, (float(q[1]) + sin(th) * rr) * s, h + 0.0004)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, maxf(0.0024, s * 0.03), 0.0011, wh, false, func(p): return skinf.call(p))


static func _akatsuki(k) -> void:
	var bl := Color(0.095, 0.095, 0.115)
	var rd := Color(0.68, 0.07, 0.11)
	var wh := Color(0.86, 0.82, 0.8)
	var lin := Color(0.2, 0.035, 0.055)
	var pn := Color(0.15, 0.16, 0.24)
	var wr := Color(0.84, 0.83, 0.8)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K: float = k.K
	var F: float = k.F
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var hem: float = lerpf(K, F, 0.52)
	var inn := P._inner(k, b, func(_i, _j, _p): return Color(0.2, 0.2, 0.23), 0.006)
	_seat(k, b, pn.darkened(0.15))
	P._net_patch(k, inn, func(_a, _y): return true, -0.62, 0.62, C - 0.05, N + 0.03, 0.021, 0.0013, 0.0015, Color(0.07, 0.07, 0.08))
	var keys := [P._kp(nk, N + 0.012, 0.034), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.05), P._kp(hp, H - 0.04, 0.056), [K + 0.05, hp.x + 0.095, hp.y + 0.1, hp.z - 0.135], [hem, hp.x + 0.15, hp.y + 0.12, hp.z - 0.2]]
	var skin_c := func(p: Vector3) -> Array: return _coat_skin(k, p, hem)
	var e_at := func(y: float) -> float:   # ön kenar: göğüste V, belden aşağı ortada buluşur
		return 0.014 + 0.5 * pow(smoothstep(C - 0.05, N + 0.012, y), 1.3)
	var fold := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var fe: float = smoothstep(0.03, 0.4, aw)
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var bk: float = smoothstep(1.2, 2.2, aw)
		var sk: float = pow(t, 0.9) * ((0.058 + 0.018 * bk) * sin(a * 7.0 + 0.6) + 0.03 * sin(a * 13.0 + 1.9))
		var up: float = (1.0 - t) * 0.008 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y)
		return fe * (sk + up)
	var pt := func(a: float, y: float) -> Vector3:
		var s: Array = SE.El.key_at(keys, y)
		var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
		var f: float = 1.0 + float(fold.call(a, y))
		return Vector3(q.x * f, y, q.y * f)
	# palto gövdesi: tek parça, önden açık; alt yarının içi astarlı
	var ny := 56
	var na := 108
	var top_y: float = keys[0][0]
	var outer := []
	for j in ny + 1:
		var y := lerpf(top_y, hem, float(j) / ny)
		var e: float = e_at.call(y)
		var ro := []
		for i in na + 1:
			ro.append(pt.call(lerpf(e, TAU - e, float(i) / na), y))
		outer.append(ro)
	var rows: Array = outer.duplicate()
	var src := []
	for j in ny + 1:
		src.append([j, false])
	var inw := func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
	var roll := []
	for p in outer[ny]:
		roll.append(inw.call(p, 0.004) + Vector3(0, -0.004, 0))
	rows.append(roll)
	src.append([ny, true])
	var j2: int = ny
	while float(outer[j2][0].y) < H - 0.02:
		var ro := []
		for p in outer[j2]:
			ro.append(inw.call(p, 0.008))
		rows.append(ro)
		src.append([j2, true])
		j2 -= 3
	var ang_of := func(i: int, j: int) -> float:
		var y: float = outer[j][0].y
		var e: float = e_at.call(y)
		return lerpf(e, TAU - e, float(i) / na)
	k.grid(rows, false, func(i, j, _p):
		var e2: Array = src[j]
		if e2[1]:
			return lin
		var oj: int = e2[0]
		var y: float = outer[oj][0].y
		var f: float = fold.call(ang_of.call(i, oj), y)
		var c0: Color = bl.darkened(clampf(-f * 7.0, 0.0, 0.42)).lightened(clampf(f * 1.9, 0.0, 0.1))
		return c0, func(_i, _j, p): return skin_c.call(p))
	# ön kenar biyesi (kırmızı) + etek ucu
	var ea := []
	var eb := []
	var oa := []
	for j in range(4, ny + 1):
		var pa: Vector3 = outer[j][0]
		var pb: Vector3 = outer[j][na]
		ea.append(pa + Vector3(0.0065, 0.0, 0.0))
		eb.append(pb + Vector3(-0.0065, 0.0, 0.0))
		oa.append(Vector3(0.0, 0.0, 1.0))
	k.strip(ea, oa, 0.0062, 0.0028, rd.darkened(0.08), false, skin_c)
	k.strip(eb, oa, 0.0062, 0.0028, rd.darkened(0.08), false, skin_c)
	var ho := []
	for p in outer[ny]:
		ho.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(_yl(outer[ny], 0.008), ho, 0.0075, 0.0022, bl.lightened(0.09), false, skin_c)
	# gizli kapanış: göğüs ve karında çıtçıt
	for y0 in [C - 0.09, C - 0.2, H + 0.09]:
		var q: Vector3 = pt.call(0.03, y0)
		P._stud(k, q + Vector3(-0.002, 0.0, 0.0046), Vector3(0, 0, 1), 0.0068, rd.lightened(0.05), k.torso_skin(y0))
	# yüksek yaka: dışı siyah, içi kırmızı, yukarı açılır
	var ck := [[N + 0.21, nk.x + 0.088, nk.y + 0.075, nk.z - 0.09], [N + 0.1, nk.x + 0.058, nk.y + 0.05, nk.z - 0.058], [N + 0.0, nk.x + 0.052, nk.y + 0.042, nk.z - 0.05], [N - 0.05, nk.x + 0.07, nk.y + 0.056, nk.z - 0.064]]
	var skin_t := func(p): return k.torso_skin(minf(float(p.y), N))
	var cg := P._cl(k, {"keys": ck, "ny": 16, "na": 52, "rng": func(_v): return Vector2(0.46, TAU - 0.46), "top": func(a):
		return lerpf(N + 0.095, N + 0.15, smoothstep(0.45, 1.5, absf(float(a)))), "hem": func(_a): return N - 0.04, "fold": func(a, y, v): return 0.012 * (1.0 - float(v)) * sin(float(a) * 5.0 + float(y) * 3.0), "col": func(_a, _y, _v): return bl.lightened(0.03), "inner": rd.darkened(0.14), "skin": skin_t, "th": 0.006})
	P._bd(k, cg["top"], 0.0046, 0.0024, rd.darkened(0.25), false, skin_t, 0.6)
	# kollar: omuzda dolgun, bileğe doğru genişleyen ağız; içi kırmızı
	var cl_sk: Callable = skin_c
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			var fl: float = pow(clampf((s - en + 0.12) / (0.9 - en + 0.12), 0.0, 1.0), 1.5)
			return 0.012 + 0.052 * fl + (0.003 + 0.007 * fl) * P._lf(s, a, 1.6) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins):
			return lin.lightened(0.05) if ins else P._fs(bl, float(sf.call(float(s), float(a))) - 0.012 - 0.052 * pow(clampf((float(s) - en + 0.12) / (0.9 - en + 0.12), 0.0, 1.0), 1.5), 26.0), 0.0, 0.9, 32, 22, 0.02)
		# kol içi: kumaşın ters yüzü (ağızdan bakınca gökyüzü görünmez) + koyu iç kol
		_lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, lin, 0.12, 0.9, 20, 22)
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return pn.darkened(0.3) if ins else pn.darkened(0.12), 0.2, 0.965, 20, 14)
		for q in [[0.3, 0.2 if sd == "Left" else -0.2, 0.066], [0.72, 1.6 if sd == "Left" else -1.6, 0.06]]:
			var s0: float = q[0]
			var a0: float = q[1]
			var L: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
			var R: float = P._lr(ar, s0) + float(sf.call(s0, a0))
			var sv := func(u: float, v: float, lift: float) -> Array:
				var s2: float = s0 - v / L
				var a2: float = a0 + u / R
				return _lsurf(ar, s2, a2, float(sf.call(s2, a2)) + lift)
			_cloud(k, sv, func(p): return P._lskin(ar, clampf(float((p - (ar["p0"] as Vector3)).length()) / L, 0.0, 1.0)), float(q[2]), rd, wh)
		# koyu pantolon + bilekte kanonik beyaz sargı
		var pa: Callable = _pant(k, le, pn, 0.012, 0.014, 1.0, 2.6)
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.0025, func(_s, _a, _i): return wr.darkened(0.14), 0.8, 0.985, 8, 16)
		P._wraps(k, le, 0.8, 0.975, 7, float(pa.call(0.9, 0.0)) + 0.0065, 0.0125, wr, 0.008)
	# bulutlar: sırt, omuz önü, etek önü ve arkası
	for q in [[PI, C - 0.05, 0.105], [PI + 1.0, H - 0.1, 0.082], [PI - 1.05, K + 0.08, 0.092], [PI + 0.62, K - 0.08, 0.075], [0.72, C - 0.005, 0.07], [-0.78, H + 0.04, 0.068], [0.82, K + 0.04, 0.085], [-0.7, K - 0.09, 0.08]]:
		var a0: float = q[0]
		var y0: float = q[1]
		var Ra: float = ((pt.call(a0 + 0.05, y0) as Vector3) - (pt.call(a0 - 0.05, y0) as Vector3)).length() / 0.1
		var sv := func(u: float, v: float, lift: float) -> Array:
			var p: Vector3 = pt.call(a0 + u / Ra, y0 + v)
			var o: Vector3 = Vector3(p.x, 0.0, p.z).normalized()
			return [p + o * lift, o]
		_cloud(k, sv, cl_sk, float(q[2]), rd, wh)


# ------------------------------------------------------------------ Tabibito: biyeli diz üstü tunik + deri kemer ve kese, kapişonu sırta düşmüş kısa yol pelerini + boyun tokası, bol pantolon, baldır sargıları
## Pelerin ağırlığı: gövdeyle gider, yan kanatlar üst kolu izler (kol savrulunca pelerini delmez)
static func _cape_skin(k, p: Vector3, wd: float) -> Array:
	var ts: Array = k.torso_skin(maxf(p.y, k.H + 0.02))
	var sx: float = smoothstep(0.55, 0.98, absf(p.x) / wd) * smoothstep(k.N, k.C - 0.04, p.y) * 0.62
	if sx <= 0.0:
		return ts
	var res := []
	for e in ts:
		res.append([e[0], float(e[1]) * (1.0 - sx)])
	res.append([("Left" if p.x > 0.0 else "Right") + "UpperArm", sx])
	return res


static func _tabibito(k) -> void:
	var tu := Color(0.5, 0.38, 0.27)
	var pi_c := Color(0.27, 0.2, 0.15)
	var pn := Color(0.33, 0.28, 0.22)
	var cl := Color(0.39, 0.34, 0.26)
	var wr := Color(0.74, 0.69, 0.58)
	var le_c := Color(0.23, 0.16, 0.11)
	var mt := Color(0.68, 0.58, 0.42)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return pn.darkened(0.2))
	_seat(k, b, pn.darkened(0.2))
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.0035 * P._lf(s, a, 0.8) + 0.0052 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0) + 0.006 * smoothstep(en + 0.1, en + 0.28, s) * (1.0 - smoothstep(0.82, 0.86, s))
		P._lt(k, ar, func(s, a): return 0.01 + float(sf.call(float(s), float(a))), func(s, a, ins):
			return tu.darkened(0.45) if ins else P._fs(tu, float(sf.call(float(s), float(a))), 24.0), 0.0, 0.875, 30, 18)
		P._wraps(k, ar, 0.83, 0.965, 6, 0.008, 0.0125, wr, 0.007)
		var kn: float = le["kn"]
		var pa: Callable = _pant(k, le, pn, 0.016, 0.026, 1.0, 1.7 if sd == "Left" else 4.0)
		# baldır: alt sargı + çapraz turlar + bağlama ipi
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.002, func(_s, _a, _i): return wr.darkened(0.2), kn + 0.08, 0.985, 12, 18)
		P._wraps(k, le, kn + 0.09, 0.975, 12, float(pa.call(kn + 0.4, 0.0)) + 0.007, 0.0145, wr, 0.014)
		for s2 in [kn + 0.075, 0.965]:
			k.wrap_turn(P._lp(le, s2), P._ld(le, s2), P._lr(le, s2) + float(pa.call(s2, 0.0)) + 0.0115, 0.005, 0.0, le_c, P._lskin(le, s2))
	# tunik: V yaka, verev kapanış, yanlara doğru yükselen etek
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var hem0: float = H - 0.3
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.024), P._kp(bl, H + 0.05, 0.022), P._kp(hp, H - 0.05, 0.042), [hem0 - 0.02, hp.x + 0.082, hp.y + 0.072, hp.z - 0.08]]
	var yv: float = C - 0.03
	var tp := func(a: float) -> float: return lerpf(yv, N + 0.012, clampf(absf(a) / 0.58, 0.0, 1.0))
	var hf := func(a: float) -> float:
		var sd: float = exp(-pow((absf(a) - PI * 0.5) / 0.42, 2.0))
		return hem0 + 0.1 * sd
	var ff := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem0), 0.0, 1.0)
		var bu: float = 0.03 * exp(-pow((y - (H + 0.09)) / 0.05, 2.0)) * (0.5 + 0.5 * sin(a * 11.0 + 0.8))
		return t * (0.042 * sin(a * 7.0 + 0.4) + 0.02 * sin(a * 12.0 + 2.2)) + bu + 0.005 * sin(a * 5.0 + y * 11.0) * (1.0 - t)
	var tg := P._cl(k, {"keys": keys, "ny": 54, "na": 100, "top": func(a): return tp.call(float(a)), "hem": func(a): return hf.call(float(a)), "fold": ff, "col": func(_a, _y, _v): return tu, "gain": 5.0, "th": 0.005})
	# biye: yaka, etek, verev kapanış
	var ve := []
	for p in tg["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.62:
			ve.append(p)
	P._tr(k, ve, 0.0115, 0.0035, pi_c)
	P._tr(k, _yl(tg["hem"], 0.015), 0.0115, 0.0032, pi_c, true)
	P._line(k, keys, [Vector2(-0.34, lerpf(yv, N, 0.56)), Vector2(-0.1, C - 0.06), Vector2(0.28, C - 0.17), Vector2(0.66, H + 0.11)], 0.0085, 0.003, 0.003, pi_c, 7, Callable())
	for t in [0.28, 0.56]:
		var q: Vector3 = P._sa(keys, lerpf(-0.1, 0.5, t), lerpf(C - 0.06, H + 0.14, t), 0.009)[0]
		P._stud(k, q, P._out(q), 0.006, mt, k.torso_skin(q.y))
	# deri kemer + toka + kese + düğümlü ip
	var by: float = H + 0.05
	var kb := [P._kp(bl, by + 0.05, 0.03), P._kp(bl, by - 0.05, 0.032)]
	P._sash(k, kb, by, 0.019, 0.001, le_c, 0.16)
	var bf: Array = P._sa(kb, 0.0, by, 0.012)
	P._boxr(k, bf[0], Vector3(0.024, 0, 0), Vector3(0, 0.022, 0), (bf[1] as Vector3) * 0.006, mt, [["Hips", 1.0]], 0.3)
	P._boxr(k, (bf[0] as Vector3) + (bf[1] as Vector3) * 0.005, Vector3(0.012, 0, 0), Vector3(0, 0.0115, 0), (bf[1] as Vector3) * 0.003, le_c, [["Hips", 1.0]], 0.3)
	var pc: Array = P._sa(keys, 1.28, by - 0.06, 0.032)
	var pu: Vector3 = (pc[1] as Vector3).cross(Vector3.UP).normalized()
	P._boxr(k, pc[0], pu * 0.046, Vector3(0, 0.045, 0), (pc[1] as Vector3) * 0.026, le_c.lightened(0.08), [["Hips", 0.7], ["LeftUpperLeg", 0.3]], 0.34)
	P._boxr(k, (pc[0] as Vector3) + Vector3(0, 0.024, 0) + (pc[1] as Vector3) * 0.026, pu * 0.047, Vector3(0, 0.023, 0), (pc[1] as Vector3) * 0.006, le_c, [["Hips", 0.7], ["LeftUpperLeg", 0.3]], 0.3)
	P._stud(k, (pc[0] as Vector3) + (pc[1] as Vector3) * 0.033 + Vector3(0, 0.012, 0), pc[1], 0.0055, mt, [["Hips", 1.0]])
	# yol pelerini: omuzları örter, sırtta beline iner, önü açık
	var wd: float = ch.x + 0.1
	var ck := [[N + 0.032, nk.x + 0.05, nk.y + 0.052, nk.z - 0.055], [N - 0.01, nk.x + 0.085, nk.y + 0.07, nk.z - 0.08], [N - 0.075, wd * 0.96, ch.y + 0.03, ch.z - 0.05], [C - 0.06, wd, ch.y + 0.065, ch.z - 0.075], [H + 0.08, wd * 0.94, wa.y + 0.1, wa.z - 0.11], [H - 0.04, wd * 0.96, wa.y + 0.115, wa.z - 0.13]]
	var cs := func(p): return _cape_skin(k, p, wd)
	var hc := func(a: float) -> float:
		var aa: float = absf(a)
		return lerpf(C - 0.09, H - 0.015, smoothstep(0.75, 2.5, aa))
	var cf := func(a: float, y: float, v: float) -> float:
		return float(v) * (0.04 * sin(a * 8.0 + 0.5) + 0.018 * sin(a * 15.0 + 1.3)) + 0.004 * sin(a * 4.0 + y * 8.0)
	var cg := P._cl(k, {"keys": ck, "ny": 40, "na": 104, "rng": func(_v): return Vector2(0.42, TAU - 0.42), "top": func(_a): return N + 0.03, "hem": func(a): return hc.call(float(a)), "fold": cf, "col": func(_a, _y, _v): return cl, "gain": 5.0, "skin": cs, "th": 0.006, "inner": cl.darkened(0.35)})
	P._bd(k, _yl(cg["hem"], 0.01), 0.006, 0.0024, cl.darkened(0.3), false, cs)
	var oe: Array = [cg["ea"], cg["eb"]]
	for ed in oe:
		P._bd(k, ed, 0.0065, 0.0026, cl.darkened(0.25), false, cs)
	# sırta düşmüş kapişon: boyun arkasında yığılan kalın kat
	var hk := [[N + 0.065, nk.x + 0.055, nk.y + 0.04, nk.z - 0.07], [N + 0.03, nk.x + 0.08, nk.y + 0.03, nk.z - 0.1], [N - 0.05, nk.x + 0.085, nk.y, nk.z - 0.125], [N - 0.16, nk.x + 0.03, nk.y, nk.z - 0.095]]
	var hd := P._cl(k, {"keys": hk, "ny": 16, "na": 46, "rng": func(_v): return Vector2(1.5, TAU - 1.5), "top": func(a):
		return N + 0.05 - 0.03 * smoothstep(2.6, 1.5, absf(float(a))), "hem": func(a):
		return N - 0.06 - 0.09 * pow(clampf(1.0 - (PI - absf(float(a))) / 1.5, 0.0, 1.0), 1.6), "fold": func(a, _y, v): return 0.05 * sin(float(v) * PI) * cos(float(a) * 3.0) + 0.016 * sin(float(a) * 9.0), "col": func(_a, _y, _v): return cl.lightened(0.04), "gain": 4.0, "skin": func(p): return k.torso_skin(p.y), "th": 0.005, "inner": cl.darkened(0.38)})
	P._bd(k, hd["top"], 0.0065, 0.0028, cl.darkened(0.26), false, func(p): return k.torso_skin(p.y), 0.5)
	# boyun tokası: iki kanadı bağlayan ip ve metal düğme
	var yc: float = N - 0.04
	var ql: Vector3 = P._sa(ck, 0.45, yc, 0.012)[0]
	var qr: Vector3 = P._sa(ck, -0.45, yc, 0.012)[0]
	var mid := Vector3(0.0, yc - 0.022, (ql.z + qr.z) * 0.5 + 0.008)
	P._cord(k, [ql, ql.lerp(mid, 0.5) + Vector3(0, -0.006, 0.002), mid, qr.lerp(mid, 0.5) + Vector3(0, -0.006, 0.002), qr], 0.0035, le_c, false, func(p): return k.torso_skin(p.y), 1.2)
	for q in [ql, qr]:
		P._stud(k, q, P._out(q), 0.0115, mt, [["UpperChest", 1.0]])


# ------------------------------------------------------------------ Iryō-nin (ref Medical_nin: savaş sağlık birliği): krem, yüksek yakalı gömlek, göğüste kızıl halkalı 医, fermuar çizgisi, belden aşağı açılan önlük; dirseğe katlı kol + sargılı ön kol, lacivert pantolon, sağlık kesesi
static func _iryonin(k) -> void:
	var cr := Color(0.84, 0.82, 0.75)
	var sh := Color(0.66, 0.64, 0.58)
	var rd := Color(0.66, 0.17, 0.17)
	var pn := Color(0.17, 0.19, 0.26)
	var wr := Color(0.93, 0.92, 0.88)
	var skc: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	P._inner(k, b, func(_i, _j, _p): return pn.lightened(0.05))
	_seat(k, b, pn.darkened(0.08))
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		P._lt(k, ar, func(_s, _a): return 0.001, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, en - 0.05, 1.0, 16, 16)
		P._wraps(k, ar, en + 0.012, 0.965, 12, 0.0075, 0.0125, wr, 0.008)
		var e2: float = en + 0.045
		var sf := func(s: float, a: float) -> float: return 0.009 + 0.0032 * P._lf(s, a, 0.5) + 0.0045 * smoothstep(0.1, e2, s) - 0.02 * (1.0 - smoothstep(0.0, 0.15, s))
		P._lt(k, ar, sf, func(s, a, ins):
			return sh.darkened(0.2) if ins else P._fs(cr, float(sf.call(float(s), float(a))) - 0.0115, 26.0), 0.0, e2, 22, 18)
		# katlanmış kol ağzı
		P._lt(k, ar, func(s, a): return float(sf.call(e2 - 0.01, float(a))) + 0.0055 + 0.002 * sin(float(a) * 3.0) + 0.0 * float(s), func(_s, _a, ins): return sh if ins else cr.lightened(0.05), e2 - 0.055, e2 + 0.012, 4, 18)
		var kn: float = le["kn"]
		var pa: Callable = _pant(k, le, pn, 0.008, 0.012, 1.0, 0.9 if sd == "Left" else 3.4)
		P._wraps(k, le, 0.87, 0.975, 5, float(pa.call(0.93, 0.0)) + 0.006, 0.0125, wr.darkened(0.06), 0.008)
		if sd == "Right":   # uyluk sargı bandı + küçük ilaç tüpleri
			var s0: float = kn * 0.8
			var pp: float = float(pa.call(s0, 0.0))
			k.wrap_turn(P._lp(le, s0), P._ld(le, s0), P._lr(le, s0) + pp + 0.006, 0.019, 0.0, sh.darkened(0.3), P._lskin(le, s0))
			for i in 3:
				var e: Array = _lsurf(le, s0, -PI * 0.5 + (float(i) - 1.0) * 0.42, pp + 0.016)
				var d: Vector3 = P._ld(le, s0)
				P._tb(k, [(e[0] as Vector3) - d * 0.03, e[0], (e[0] as Vector3) + d * 0.03], func(s, _a): return 0.0105 * (0.7 if s > 0.92 or s < 0.08 else 1.0), func(s, _a, _p): return rd if s < 0.3 else cr, func(_s, _p): return [["RightUpperLeg", 1.0]], 8)
	# gömlek: yüksek boyun, belden aşağı önü açılan kanatlar
	var hem: float = H - 0.27
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.94, ch.z * 1.04], P._kp(ch, C - 0.03, 0.024), P._kp(b["wa"], H + 0.12, 0.03), P._kp(bl, H + 0.05, 0.03), P._kp(hp, H - 0.05, 0.05), [hem - 0.02, hp.x + 0.075, hp.y + 0.07, hp.z - 0.078]]
	var e_at := func(v_y: float) -> float: return 0.012 + 0.2 * pow(smoothstep(H + 0.0, hem, v_y), 1.25)
	var ff := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		var fe: float = smoothstep(0.04, 0.3, absf(a))
		var pull: float = (1.0 - t) * smoothstep(C - 0.05, H + 0.1, y) * 0.016 * sin(a * 9.0 + y * 7.0)
		return fe * (t * (0.036 * sin(a * 6.0 + 1.2) + 0.016 * sin(a * 11.0)) + pull + 0.004 * sin(a * 4.0 + y * 9.0))
	var tg := P._cl(k, {"keys": keys, "ny": 56, "na": 100, "rng": func(v):
		var y: float = lerpf(N + 0.012, hem, float(v))
		var e: float = e_at.call(y)
		return Vector2(e, TAU - e), "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": ff, "col": func(_a, _y, _v): return cr, "gain": 4.5, "th": 0.005, "inner": sh.darkened(0.18)})
	# ön kapanış: fermuar + kenar biyesi
	var ea: Array = tg["ea"]
	var eb: Array = tg["eb"]
	var oz := []
	for p in ea:
		oz.append(Vector3(0, 0, 1))
	var ex := []
	var fx := []
	for j in ea.size():
		ex.append((ea[j] as Vector3) + Vector3(0.0055, 0, 0))
		fx.append((eb[j] as Vector3) + Vector3(-0.0055, 0, 0))
	k.strip(ex, oz, 0.0052, 0.0024, sh, false, func(p): return P._hs(k, p))
	k.strip(fx, oz, 0.0052, 0.0024, sh, false, func(p): return P._hs(k, p))
	var zp := []
	var zo := []
	for j in 22:   # fermuar: kapalı kısımda iki kenarın üstünden geçer
		var yz: float = lerpf(N + 0.0, H + 0.03, float(j) / 21.0)
		zp.append(P._sa(keys, 0.0, yz, 0.004)[0])
		zo.append(Vector3(0, 0, 1))
	k.strip(zp, zo, 0.0048, 0.0022, sh.darkened(0.28), false, func(p): return k.torso_skin(p.y))
	P._tr(k, _yl(tg["hem"], 0.012), 0.0078, 0.0026, sh)
	# yüksek yaka: iki katlı dik boyun, önde iki düğme
	var ck := [P._kp(nk, N + 0.095, 0.018), P._kp(nk, N + 0.0, 0.032)]
	var cg := P._cl(k, {"keys": ck, "ny": 7, "na": 44, "rng": func(_v): return Vector2(0.05, TAU - 0.05), "top": func(a): return N + 0.075 + 0.016 * smoothstep(0.1, 2.0, absf(float(a))), "hem": func(_a): return N - 0.006, "col": func(_a, _y, _v): return cr.lightened(0.04), "skin": func(p): return k.torso_skin(p.y), "th": 0.005, "inner": sh})
	P._bd(k, cg["top"], 0.0042, 0.0024, rd.darkened(0.08), false, func(p): return k.torso_skin(p.y), 0.5)
	for y0 in [N + 0.05, N + 0.015]:
		var q: Vector3 = P._on(ck, 0.08, y0, 0.05)
		P._stud(k, q, Vector3(0, 0, 1), 0.0055, sh.darkened(0.2), [["Neck", 0.5], ["UpperChest", 0.5]])
	# 医: göğüste ve sırtta kabartma damga; omuz ek yeri
	_i_mark(k, keys, ch.x * 0.42, C - 0.015, 0.05, rd, true)
	_i_mark(k, keys, 0.0, C - 0.05, 0.078, rd, false)
	for sg in [1.0, -1.0]:
		P._hole(k, keys, sg, C + 0.0, 0.46, 0.09, 0.0042, 0.0018, sh)
	# bel: gri-krem kemer, tokası, sağlık kesesi (arka sağ)
	var by: float = H + 0.055
	var kb := [P._kp(bl, by + 0.05, 0.032), P._kp(bl, by - 0.05, 0.034)]
	P._sash(k, kb, by, 0.017, 0.001, sh.darkened(0.14), 0.12)
	var bf: Array = P._sa(kb, 0.0, by, 0.012)
	P._boxr(k, bf[0], Vector3(0.024, 0, 0), Vector3(0, 0.02, 0), (bf[1] as Vector3) * 0.0055, sh.lightened(0.12), [["Hips", 1.0]], 0.3)
	var pc: Array = P._sa(keys, PI + 0.72, by - 0.052, 0.042)
	var pu: Vector3 = (pc[1] as Vector3).cross(Vector3.UP).normalized()
	var sk_p := [["Hips", 1.0]]
	P._boxr(k, pc[0], pu * 0.074, Vector3(0, 0.056, 0), (pc[1] as Vector3) * 0.036, cr.darkened(0.08), sk_p, 0.3)
	P._boxr(k, (pc[0] as Vector3) + Vector3(0, 0.03, 0) + (pc[1] as Vector3) * 0.036, pu * 0.076, Vector3(0, 0.028, 0), (pc[1] as Vector3) * 0.0075, cr.darkened(0.02), sk_p, 0.3)
	var pf: Vector3 = (pc[0] as Vector3) + (pc[1] as Vector3) * 0.0442 + Vector3(0, 0.03, 0)
	P._boxr(k, pf, pu * 0.021, Vector3(0, 0.0065, 0), (pc[1] as Vector3) * 0.002, rd, sk_p, 0.1)
	P._boxr(k, pf, pu * 0.0065, Vector3(0, 0.021, 0), (pc[1] as Vector3) * 0.0024, rd, sk_p, 0.1)
