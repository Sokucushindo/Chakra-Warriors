extends RefCounted
## Elle modellenmiş setler, parti t: set_anbu_byakue, ss_bulut_striker_toprak, ss_bulut_striker_yildiz, ss_kod, ss_samuray_kuro, ss_siyah_tulum. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J) dosyalarından; zırh plakaları parti l (L) dosyasından.
## Burada: önü kapalı uzun palto ağırlığı, yüksek belli sarma etek ağırlığı, burgu halat, gül arması ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const L = preload("res://scripts/actors/set_el_l.gd")

const DONE := ["set_anbu_byakue", "ss_bulut_striker_toprak", "ss_bulut_striker_yildiz", "ss_kod", "ss_samuray_kuro", "ss_siyah_tulum"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"set_anbu_byakue": _byakue(k)
		"ss_bulut_striker_toprak": _kumo(k, false)
		"ss_bulut_striker_yildiz": _kumo(k, true)
		"ss_kod": _kod(k)
		"ss_samuray_kuro": _samuray(k)
		"ss_siyah_tulum": _tulum(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ağırlıklar
## Önü kapalı uzun palto: ön yüz iki bacak arasında geniş geçişle ortalamayı izler (ortadan yırtmaç gibi bölünmez), bacak hizasında kendi
## bacağını izler (diz kumaşı delmez); arka yüz boy boyunca yavaş artar, diz altında baldırı izler (geri kalkan topuk delmez); uçta ağırlık biraz düşer (kanat açmaz)
static func _bsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.93 * pow(minf(1.0, t / 0.55), 0.5)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.95, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.92, smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(0.095, 0.09, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.06, k.K - 0.1, p.y) * bk * absf(2.0 * s - 1.0) * 0.7
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Diz üstü etek: iki bacak arasında geniş geçiş (kumaş ortada kırılmaz), uçta ağırlık düşer (etek ucu koşuda sivri kanat olmaz)
static func _ksk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.07, p.z)
	var w: float = lerpf(0.9 * pow(minf(1.0, t / 0.6), 0.55), 0.84 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8)), bk) * lerpf(1.0, 0.86, smoothstep(0.65, 1.0, t))
	var s: float = smoothstep(-0.1, 0.1, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


# ------------------------------------------------------------------ yardımcılar
## Burgu halat (shimenawa): üç kollu, oluklarda koyulaşır
static func _twist(k, pts: Array, closed: bool, R: float, turns: float, col: Color, skinf: Callable, taper := 0.0) -> void:
	var rf := func(s: float, a: float) -> float:
		var tp: float = 1.0 - taper * smoothstep(0.6, 1.0, s)
		return R * tp * (1.0 + 0.17 * cos(3.0 * a - TAU * turns * s))
	var cf := func(s: float, a: float, _p: Vector3) -> Color:
		var w: float = cos(3.0 * a - TAU * turns * s)
		return col.darkened(0.3) if w < -0.45 else (col.lightened(0.05) if w > 0.6 else col)
	P._tb(k, pts, rf, cf, func(_s, p): return skinf.call(p), 12, closed)


## Gül arması: iki kat taç yaprak + göbek (kabartma)
static func _rose(k, c: Vector3, o: Vector3, r: float, col: Color, bones: Array) -> void:
	var up: Vector3 = Vector3.UP if absf(o.y) < 0.8 else Vector3.BACK
	P._fan(k, c, o, up, r, func(th): return 0.72 + 0.28 * absf(cos(float(th) * 2.5)), func(u, v): return col.darkened(0.3) if Vector2(float(u), float(v)).length() > 0.8 else col, bones, 3, 30)
	P._fan(k, c + o * 0.0022, o, up.rotated(o, 0.63), r * 0.64, func(th): return 0.7 + 0.3 * absf(cos(float(th) * 2.5)), func(u, v): return col.lightened(0.1) if Vector2(float(u), float(v)).length() < 0.55 else col.darkened(0.18), bones, 3, 24)
	P._stud(k, c + o * 0.0038, o, r * 0.24, col.lightened(0.12), bones)


## Uzuv yüzeyinde (s, a) yolu boyunca kabartma çizgi
static func _lline(k, l: Dictionary, ctrl: Array, lift: Callable, hw: float, col: Color, steps := 5) -> void:
	var pts := []
	var ou := []
	var ss := []
	for q in P._path(ctrl, steps):
		var e: Array = Q._ls(l, q.x, q.y, float(lift.call(q.x, q.y)))
		pts.append(e[0])
		ou.append(e[1])
		ss.append(q.x)
	var sm: float = (float(ss[0]) + float(ss[ss.size() - 1])) * 0.5
	k.strip(pts, ou, hw, 0.0015, col, false, func(_p): return P._lskin(l, sm))


## Uzuv yüzeyinde dörtgen / üçgen yama: rows [[(s, a), ...], ...]
static func _lpatch(k, l: Dictionary, rows_sa: Array, lift: Callable, col: Color) -> void:
	var rows := []
	var sm := 0.0
	var cnt := 0
	for r in rows_sa:
		var ro := []
		for q in r:
			ro.append(Q._ls(l, q.x, q.y, float(lift.call(q.x, q.y)))[0])
			sm += q.x
			cnt += 1
		rows.append(ro)
	var s0: float = sm / maxf(1.0, cnt)
	var mid: Vector2 = rows_sa[rows_sa.size() / 2][(rows_sa[0] as Array).size() / 2]
	Q._mesh(k, rows, false, func(_i, _j, _p): return col, func(_i, _j, _p): return P._lskin(l, s0), Q._ls(l, mid.x, mid.y, 0.0)[1])


## Gövde pul sırası (parti l plakası): kenar rengi yalnız üst / alt kenarda, yan ek yerleri koyu kalır
static func _plate(k, keys: Array, ac: float, aw: float, y0: float, y1: float, add: float, th: float, col: Color, trim: Color, nu := 26, nv := 8) -> void:
	L._shell(k, func(u: float, v: float) -> Vector3:
		return L._sa(keys, ac + aw * (2.0 * u - 1.0), lerpf(y0, y1, v), add)[0], func(u: float, _v: float) -> Vector3:
		return L._sa(keys, ac + aw * (2.0 * u - 1.0), lerpf(y0, y1, 0.5))[1], nu, nv, th, func(_u, v, e):
		if v < 0.06 or v > 0.92:
			return trim
		return col.darkened(0.25) if e else col.darkened(0.05 * v), func(_u, _v, p): return k.torso_skin(p.y))


# ------------------------------------------------------------------ ANBU Byakue: diz altına inen önü kapalı beyaz palto, boynu saran bol yaka, geniş düz kollar, siyah iç + koyu pantolon, baldırda koyu sargı
static func _byakue(k) -> void:
	var wh := Color(0.9, 0.88, 0.84)
	var bk := Color(0.08, 0.08, 0.1)
	var pn := Color(0.12, 0.12, 0.18)
	var wr := Color(0.16, 0.15, 0.23)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return bk.lightened(0.04) if j < 4 else bk, 0.006)
	K._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.1 if sd == "Left" else 2.3
		# koyu iç kol: bilekte görünür
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.55, 0.985, 14, 16)
		# geniş düz kol: alt yanı hafif sarkar, ağız katlı
		var adn: float = J._outer_a(ar, 0.75, Vector3.DOWN)
		var sl := func(s: float, a: float) -> float:
			var t: float = smoothstep(0.06, 0.88, s)
			var dn: float = exp(-pow(wrapf(a - adn, -PI, PI) / 1.0, 2.0))
			return 0.018 + 0.022 * t + 0.016 * t * dn + 0.005 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var slc := func(s: float, a: float) -> float:
			return 0.005 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		P._lt(k, ar, sl, func(s, a, ins): return wh.darkened(0.2) if ins else P._fs(wh, float(slc.call(float(s), float(a))), 10.0), 0.0, 0.9, 34, 24, 0.05)
		K._lt_in(k, ar, func(s, a): return float(sl.call(float(s), float(a))) - 0.005, wh.darkened(0.14), 0.74, 0.9, 6, 24)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return wh.darkened(0.2) if ins else wh.darkened(0.07), 0.865, 0.902, 4, 24)
		# pantolon + baldır sargısı (turlar sarmal gider)
		var pa: Callable = K._pant(k, le, pn, 0.01, 0.012, 1.0, sv)
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.002, func(_s, _a, ins): return wr.darkened(0.4) if ins else wr.darkened(0.22), kn + 0.07, 0.985, 14, 18)
		for i in 13:
			var s: float = lerpf(kn + 0.09, 0.965, float(i) / 12.0)
			k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + 0.008 + float(pa.call(s, 0.0)), 0.011, 0.014 * sg * (1.0 if i % 2 == 0 else -0.6), wr.darkened(0.06 * float(i % 3)), P._lskin(le, s))
	# palto gövdesi: önü kapalı, dizin biraz altına iner; dizin önünde kumaş payı
	var hem: float = KN - 0.045
	var keys := [P._kp(nk, N + 0.004, 0.034), [N - 0.055, ch.x * 1.02, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.044), P._kp(hp, H - 0.04, 0.05),
		[H - 0.2, hp.x + 0.07, hp.y + 0.055, hp.z - 0.075], [KN + 0.03, hp.x + 0.085, hp.y + 0.06, hp.z - 0.09], [hem, hp.x + 0.09, hp.y + 0.06, hp.z - 0.095]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var fe: float = smoothstep(0.08, 0.4, aw)
		return fe * pow(t, 1.1) * (0.03 * sin(a * 6.0 + 0.9) + 0.014 * sin(a * 11.0 + 2.3)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 11.0) * smoothstep(N - 0.03, C - 0.04, y)
	var csk := func(p): return _bsk(k, p, hem)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 46, "na": 88, "top": func(_a): return N + 0.004, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return wh, "gain": 4.0, "th": 0.007, "inner": wh.darkened(0.3), "skin": csk})
	# kapanış patı + dikiş, düğmeler, yan ve arka dikişler, etek ucu
	Q._run(k, keys, ff, [Vector2(0.0, N - 0.03), Vector2(0.0, hem + 0.012)], 0.011, 0.003, 0.0026, wh.darkened(0.03), csk, 14)
	Q._run(k, keys, ff, [Vector2(0.075, N - 0.03), Vector2(0.075, hem + 0.014)], 0.0016, 0.0032, 0.0011, wh.darkened(0.22), csk, 14)
	for i in 5:
		var y: float = lerpf(N - 0.07, H - 0.02, float(i) / 4.0)
		var e: Array = Q._spt(keys, ff, 0.0, y, 0.0058)
		P._stud(k, e[0], e[1], 0.0065, wh.darkened(0.1), _bsk(k, e[0], hem))
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.62, N - 0.07), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.016)], 0.0026, 0.0015, 0.0013, wh.darkened(0.16), csk, 10)
	Q._run(k, keys, ff, [Vector2(PI - 0.001, N - 0.02), Vector2(PI - 0.001, hem + 0.016)], 0.0026, 0.0015, 0.0013, wh.darkened(0.14), csk, 14)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.011, 0))
	P._bd(k, hm, 0.0032, 0.0016, wh.darkened(0.18), true, csk)
	# bol yaka: boynu saran, omza ve göğse dökülen kalın kat
	var q: float = Q._hq(k)
	var ck := [[N + 0.05 * q, nk.x + 0.058, nk.y + 0.05, nk.z - 0.068], [N + 0.012, nk.x + 0.076, nk.y + 0.074, nk.z - 0.08], [N - 0.04, ch.x * 0.84, ch.y * 0.86 + 0.034, ch.z * 0.92 - 0.034], [N - 0.13, ch.x * 1.04, ch.y * 0.98 + 0.03, ch.z * 1.06 - 0.03]]
	var kf := func(a: float, _y: float, v: float) -> float:
		return 0.07 * sin(v * PI * 2.2 + cos(a) * 1.2) * smoothstep(0.0, 0.25, v) * (1.0 - 0.5 * v) + 0.014 * sin(a * 9.0 + 0.7) * v
	var nsk := func(p): return Q._nsk(k, p)
	var cw: Dictionary = P._cl(k, {"keys": ck, "ny": 18, "na": 64, "top": func(_a): return N + 0.05 * q, "hem": func(a): return N - 0.07 - 0.045 * pow(cos(float(a)), 2.0),
		"fold": kf, "col": func(_a, _y, _v): return wh, "gain": 3.0, "th": 0.007, "inner": wh.darkened(0.3), "skin": nsk})
	P._cord(k, cw["top"], 0.009, wh.darkened(0.05), true, nsk)
	P._cur_hem = hem


# ------------------------------------------------------------------ Kumo Striker: Toprak / Takımyıldız (ref Shinobi Striker "Cloud Striker" 2. ve 3. renk): V yakalı kısa kollu tişört, boynu saran atkı, göğüs altından
## dize inen yüksek belli sarma etek (bindirmesi solda), belde kuşak, dirsekten bileğe beyaz sargı + koyu bilek bandı, toplanan pantolon + baldırda beyaz sargı.
## Toprak: yeşil tişört, kol ucunda zikzak, siyah etek + yeşil üçgen etek bandı, desenli yeşil kuşak. Takımyıldız: açık mavi tişört, lacivert obi, takımyıldız baskılı etek, dizlikli açık mavi pantolon.
static func _kumo(k, yz: bool) -> void:
	var tee: Color = Color(0.659, 0.847, 0.925) if yz else Color(0.118, 0.541, 0.416)
	var skt: Color = Color(0.118, 0.18, 0.541) if yz else Color(0.137, 0.11, 0.102)
	var obi: Color = Color(0.1, 0.11, 0.38) if yz else skt
	var blt: Color = Color(0.42, 0.68, 0.9) if yz else Color(0.12, 0.5, 0.4)
	var pat: Color = Color(0.165, 0.604, 0.502)
	var lt: Color = Color(0.86, 0.94, 1.0) if yz else Color(0.6, 0.9, 0.8)
	var scf: Color = Color(0.32, 0.7, 0.9) if yz else Color(0.91, 0.91, 0.894)
	var pnt: Color = Color(0.604, 0.784, 0.91) if yz else Color(0.17, 0.13, 0.12)
	var bnd: Color = Color(0.13, 0.17, 0.5) if yz else Color(0.2, 0.14, 0.12)
	var wt := Color(0.93, 0.93, 0.91)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# iç: V yakada beyaz
	var ik: Array = P._inner(k, b, func(_i, _j, p): return wt if p.y > C - 0.02 else tee, 0.006)
	K._seat(k, b, pnt.darkened(0.05))
	# tişört gövdesi: V yaka, göğüs altında eteğin içine girer
	var tb: float = C - 0.14
	var tk := [P._kp(nk, N + 0.012, 0.024), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.024), P._kp(k.M(tb, k.UA), tb, 0.02)]
	var vt := func(a: float) -> float: return lerpf(N - 0.1, N + 0.012, smoothstep(0.0, 0.55, absf(a)))
	var tf := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 5.0 + y * 17.0) * smoothstep(N - 0.02, C - 0.04, y) + 0.004 * sin(a * 9.0 - y * 23.0)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 22, "na": 76, "top": func(a): return vt.call(float(a)), "hem": func(_a): return tb, "fold": tf, "col": func(_a, _y, _v): return tee, "gain": 7.0, "th": 0.0, "skin": func(p): return k.torso_skin(p.y)})
	var ve := []
	for p in tg["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.62:
			ve.append(p)
	P._bd(k, ve, 0.004, 0.0024, tee.darkened(0.12), false, func(p): return k.torso_skin(p.y), 0.4)
	for sg in [1.0, -1.0]:   # reglan dikişi
		Q._run(k, tk, Callable(), [Vector2(sg * 0.62, N + 0.0), Vector2(sg * 1.0, N - 0.06), Vector2(sg * 1.32, C - 0.03)], 0.0018, 0.0015, 0.0012, tee.darkened(0.25), func(p): return k.torso_skin(p.y), 6)
	# atkı: boynu saran üç kalın kat, önde aşağı sarkar
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var rolls := [[N + 0.042 * q, 0.02, 0.0, 0.004], [N + 0.012, 0.025, 1.3, 0.016], [N - 0.016, 0.023, 2.1, 0.03]]
	for ri in rolls.size():
		var e: Array = rolls[ri]
		var pts := []
		for i in 48:
			var a: float = TAU * i / 48.0 - PI
			var y: float = float(e[0]) - float(e[3]) * pow(maxf(0.0, cos(a)), 2.0)
			pts.append(Q._spt(ik, Callable(), a, y, float(e[1]) * 0.85 + 0.004 * ri)[0])
		var R: float = e[1]
		var ph: float = e[2]
		P._tb(k, pts, func(s, a): return R * (1.0 + 0.2 * sin(float(s) * TAU * 6.0 + float(a) + ph)), func(s, a, _p):
			var w: float = sin(float(s) * TAU * 6.0 + float(a) + ph)
			return scf.darkened(0.22) if w < -0.55 else (scf.lightened(0.05) if w > 0.7 else scf), func(_s, p): return nsk.call(p), 12, true)
		if yz and ri == 1:   # atkıda yıldızlar
			for i in range(0, 48, 4):
				var p0: Vector3 = pts[i]
				var o := Vector3(p0.x, 0.15, p0.z).normalized()
				P._stud(k, p0 + o * R * 0.95, o, 0.0042, Color(0.95, 0.97, 1.0), nsk.call(p0))
	# uzuvlar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.4 if sd == "Left" else 2.5
		var s1 := 0.36
		P._bare(k, ar, skc, s1 - 0.04, 1.0)
		var sh := func(s: float, a: float) -> float: return 0.014 + 0.01 * smoothstep(0.05, s1, s) + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sh, func(s, a, ins): return tee.darkened(0.3) if ins else P._fs(tee, 0.003 * P._lf(float(s), float(a), sv), 16.0), 0.0, s1, 16, 20, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return tee.darkened(0.3) if ins else tee.darkened(0.06), s1 - 0.028, s1 + 0.001, 3, 20)
		if not yz:   # kol ucunda zikzak + noktalar
			var zz := []
			var zo := []
			var nz := 28
			for i in nz + 1:
				var a: float = TAU * float(i) / nz - PI
				var s: float = s1 - 0.045 - (0.035 if i % 2 == 1 else 0.0)
				var e2: Array = Q._ls(ar, s, a, float(sh.call(s, a)) + 0.0012)
				zz.append(e2[0])
				zo.append(e2[1])
				if i % 2 == 1 and i < nz:
					var e3: Array = Q._ls(ar, s - 0.016, a, float(sh.call(s - 0.016, a)) + 0.0012)
					P._stud(k, e3[0], e3[1], 0.0034, lt, P._lskin(ar, s))
			k.strip(zz, zo, 0.0024, 0.0012, lt, false, func(_p): return P._lskin(ar, s1 - 0.06))
		# dirsekten bileğe beyaz sargı + koyu bilek bandı
		var w0: float = en - 0.02
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return wt.darkened(0.3) if ins else wt.darkened(0.08), w0, 0.8, 12, 16)
		P._wraps(k, ar, w0 + 0.02, 0.79, 8, 0.006, 0.0115, wt, 0.006)
		var wb := func(s: float, _a: float) -> float: return 0.0085 + 0.0025 * sin(clampf((s - 0.79) / 0.16, 0.0, 1.0) * PI)
		P._lt(k, ar, wb, func(_s, a, ins): return bnd.darkened(0.35) if ins else bnd.darkened(0.08 if sin(float(a) * 6.0) < -0.6 else 0.0), 0.79, 0.95, 8, 20)
		if not yz:   # bilek bandında yeşil baklava
			var ao: float = J._outer_a(ar, 0.87, Vector3(sg, -0.3, 0.0).normalized())
			var e4: Array = Q._ls(ar, 0.87, ao, float(wb.call(0.87, 0.0)) + 0.0025)
			P._fan(k, e4[0], e4[1], -P._ld(ar, 0.87), 0.013, func(th): return 1.0 / (absf(cos(float(th))) + absf(sin(float(th)))), func(_u, _v): return pat.lightened(0.08), P._lskin(ar, 0.87), 2, 16)
		# pantolon: dizde bol, baldırda toplanır; altı beyaz sargı + koyu bant
		var tk2 := 0.76
		var pa: Callable = Q._baggy(k, le, pnt, wt, 0.012, 0.024, tk2, sv)
		P._wraps(k, le, tk2 + 0.03, 0.975, 8, 0.009, 0.012, wt, 0.006)
		P._lt(k, le, func(s, _a): return 0.012 + 0.002 * sin(clampf((s - 0.865) / 0.08, 0.0, 1.0) * PI), func(_s, a, ins): return bnd.darkened(0.35) if ins else bnd.darkened(0.08 if sin(float(a) * 5.0) < -0.6 else 0.0), 0.865, 0.945, 6, 20)
		Q._ring_on(k, le, tk2 + 0.016, func(_s, _a): return 0.011, 0.007, pat if not yz else wt.darkened(0.04), 0.003)
		if yz:   # dizlik + kabarcık baskı
			K._shell(k, le, kn - 0.1, kn + 0.08, -1.05, 1.05, func(s, a): return float(pa.call(s, a)) + 0.001, 0.007, func(_u, v, ins): return Color(0.45, 0.82, 0.95).darkened(0.3 if ins else 0.08 * v), 10, 14)
			for i in 9:
				var s: float = kn + 0.1 + 0.09 * fposmod(float(i) * 0.618, 1.0)
				var a: float = lerpf(-1.1, 1.1, fposmod(float(i) * 0.381 + 0.2, 1.0))
				var e5: Array = Q._ls(le, s, a, float(pa.call(s, a)) + 0.001)
				P._stud(k, e5[0], e5[1], 0.004 + 0.003 * fposmod(float(i) * 0.71, 1.0), Color(0.78, 0.93, 1.0), P._lskin(le, s))
	# yüksek belli sarma etek: göğüs altından dize
	var ty: float = C - 0.095
	var by: float = H + 0.105
	var hem: float = KN + 0.075
	var um: Vector3 = k.M(ty, k.UA)
	var wx: float = maxf(wa.x, um.x * 0.95)
	var sk := [P._kp(um, ty, 0.02), [H + 0.12, wx + 0.024, maxf(wa.y, um.y * 0.95) + 0.024, minf(wa.z, um.z * 0.95) - 0.024], [H - 0.04, hp.x + 0.034, hp.y + 0.03, hp.z - 0.065], [H - 0.16, hp.x + 0.06, hp.y + 0.05, hp.z - 0.092], [hem, hp.x + 0.08, hp.y + 0.06, hp.z - 0.085]]
	var sf := func(a: float, y: float) -> float:
		var t: float = clampf((by - 0.03 - y) / (by - 0.03 - hem), 0.0, 1.0)
		return t * t * (0.028 * sin(a * 7.0 + 0.5) + 0.011 * sin(a * 13.0 + 1.7))
	var sff := func(a, y): return sf.call(float(a), float(y))
	var ssk := func(p): return _ksk(k, p, hem)
	var colf := func(_a, y, _v): return obi if float(y) > by + 0.03 else skt
	P._cl(k, {"keys": sk, "ny": 34, "na": 76, "top": func(_a): return ty, "hem": func(_a): return hem, "fold": func(a, y, _v): return sf.call(float(a), float(y)),
		"col": colf, "gain": 5.0, "th": 0.006, "inner": skt.darkened(0.4), "skin": ssk})
	# üst kanat: sağ yandan dolanıp solda biter (kenarı dikey)
	var flap: Dictionary = P._cl(k, {"keys": sk, "ny": 34, "na": 52, "rng": func(_v): return Vector2(-2.2, 0.62), "top": func(_a): return ty, "hem": func(_a): return hem - 0.003, "fold": func(a, y, _v): return sf.call(float(a), float(y)),
		"col": colf, "gain": 5.0, "th": 0.005, "lift": 0.0045, "inner": skt.darkened(0.3), "skin": ssk})
	P._bd(k, flap["eb"], 0.003, 0.0018, skt.lightened(0.1), false, ssk)
	P._bd(k, flap["ea"], 0.003, 0.0018, skt.lightened(0.05), false, ssk)
	var hr := []
	for p in flap["hem"]:
		hr.append((p as Vector3) + Vector3(0, 0.004, 0))
	P._bd(k, hr, 0.0028, 0.0016, skt.darkened(0.2), false, ssk)
	# kuşak + kenar biyeleri
	P._sash(k, sk, by, 0.026, 0.009, blt, 0.08)
	for dy in [0.029, -0.029]:
		P._cord(k, P._ring_pts(sk, by + dy, 0.017, 84), 0.0028, wt if not yz else blt.lightened(0.25), true, func(p): return k.torso_skin(p.y))
	if not yz:
		_belt_motif(k, sk, by, lt)
		_hem_band(k, sk, sff, hem, pat, ssk)
	else:
		_stars(k, sk, sff, hem, by, ssk)
	P._cur_hem = hem


## Toprak kuşağı: X, çift ok, baklava + nokta dizisi (kabartma)
static func _belt_motif(k, sk: Array, by: float, col: Color) -> void:
	var bkeys := []
	for e in sk:
		bkeys.append([e[0], float(e[1]) + 0.019, float(e[2]) + 0.019, float(e[3]) - 0.019])
	var W: float = float(SE.El.key_at(bkeys, by)[1])
	var h := 0.014
	var cw := 0.046
	var sf := func(p): return k.torso_skin(p.y)
	for front in [true, false]:
		var x: float = -W * 0.8
		var i := 0
		while x < W * 0.8:
			var m: int = i % 3
			var lines := []
			if m == 0:
				lines = [[Vector2(-h, -h), Vector2(h, h)], [Vector2(-h, h), Vector2(h, -h)]]
			elif m == 1:
				lines = [[Vector2(-h, h), Vector2(-0.002, 0.0), Vector2(-h, -h)], [Vector2(0.002, h), Vector2(h, 0.0), Vector2(0.002, -h)]]
			else:
				lines = [[Vector2(0.0, h), Vector2(h, 0.0), Vector2(0.0, -h), Vector2(-h, 0.0), Vector2(0.0, h)]]
				var e: Array = P._fp(bkeys, x, by, front, 0.003)
				P._stud(k, e[0], e[1], 0.0032, col, k.torso_skin(by))
			for ln in lines:
				var ctrl := []
				for v in ln:
					ctrl.append(Vector2(x + (v as Vector2).x, by + (v as Vector2).y))
				P._strap(k, bkeys, ctrl, front, 0.0019, 0.0025, 0.0014, col, 3, sf)
			x += cw
			i += 1


## Toprak etek bandı: yeşil üçgen dişler, aralarında nokta, alt ve üst yeşil şerit
static func _hem_band(k, sk: Array, sff: Callable, hem: float, col: Color, ssk: Callable) -> void:
	var hb: float = hem + 0.012
	var tb: float = hem + 0.082
	var lift := 0.0078
	for e in [[hem + 0.009, 0.0075], [tb, 0.0032]]:
		var pts := []
		var ou := []
		for i in 96:
			var a: float = TAU * i / 96.0 - PI
			var s2: Array = Q._spt(sk, sff, a, float(e[0]), lift)
			pts.append(s2[0])
			ou.append(s2[1])
		k.strip(pts, ou, float(e[1]), 0.0014, col, true, ssk)
	var nt := 24
	var da: float = TAU / nt
	for i in nt:
		var a0: float = TAU * i / nt - PI
		var ac: float = a0 + da * 0.5
		var rows := []
		for j in 5:
			var v: float = float(j) / 4.0
			var y: float = lerpf(hb, tb - 0.012, v)
			var hw2: float = 0.5 * da * (1.0 - v) * 0.9 + 0.002
			rows.append([Q._spt(sk, sff, ac - hw2, y, lift)[0], Q._spt(sk, sff, ac, y, lift + 0.0008)[0], Q._spt(sk, sff, ac + hw2, y, lift)[0]])
		Q._mesh(k, rows, false, func(_i, _j, _p): return col, func(_i, _j, p): return ssk.call(p), Q._spt(sk, sff, ac, (hb + tb) * 0.5)[1])
		var e2: Array = Q._spt(sk, sff, a0, tb - 0.03, lift)
		P._stud(k, e2[0], e2[1], 0.0042, col, ssk.call(e2[0]))


## Takımyıldız eteği: çizgilerle bağlı yıldız kümeleri + serpili yıldızlar (kabartma)
static func _stars(k, sk: Array, sff: Callable, hem: float, by: float, ssk: Callable) -> void:
	var ln := Color(0.74, 0.84, 1.0)
	var st := Color(0.95, 0.97, 1.0)
	var cy := Color(0.55, 0.88, 1.0)
	var cons := [
		[[Vector2(0, 0.05), Vector2(0.022, 0.03), Vector2(0.0, 0.0), Vector2(0.025, -0.03), Vector2(-0.005, -0.05), Vector2(-0.02, -0.02), Vector2(-0.022, 0.025)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 2], [2, 6], [6, 0]]],
		[[Vector2(-0.05, 0.01), Vector2(-0.025, -0.012), Vector2(0.0, 0.012), Vector2(0.024, -0.01), Vector2(0.05, 0.014)], [[0, 1], [1, 2], [2, 3], [3, 4]]],
		[[Vector2(-0.045, 0.02), Vector2(-0.02, 0.025), Vector2(0.0, 0.012), Vector2(0.02, 0.0), Vector2(0.024, -0.03), Vector2(0.05, -0.026), Vector2(0.046, 0.004)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 3]]],
		[[Vector2(0, 0.04), Vector2(0, 0.012), Vector2(-0.03, 0.0), Vector2(0.028, 0.02), Vector2(-0.02, -0.04), Vector2(0.03, -0.035)], [[0, 1], [1, 2], [1, 3], [1, 4], [1, 5]]],
		[[Vector2(-0.03, 0.03), Vector2(0.025, 0.035), Vector2(0.03, -0.01), Vector2(-0.01, -0.03), Vector2(-0.035, 0.0)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 0]]],
	]
	var lift := 0.0078
	var y_lo: float = hem + 0.07
	var y_hi: float = by - 0.085
	for n in 12:
		var a0: float = -PI + TAU * (float(n) + 0.3) / 12.0 + 0.12 * sin(float(n) * 2.3)
		var y0: float = lerpf(y_lo, y_hi, fposmod(float(n) * 0.618 + 0.1, 1.0))
		var mp: Callable = Q._local(sk, sff, a0, y0)
		var c: Array = cons[n % cons.size()]
		var rot: float = float(n) * 0.9
		var pts2 := []
		for v in c[0]:
			pts2.append((v as Vector2).rotated(rot))
		for ed in c[1]:
			var p0: Vector2 = pts2[ed[0]]
			var p1: Vector2 = pts2[ed[1]]
			var pp := []
			var oo := []
			for t in 4:
				var u: Vector2 = p0.lerp(p1, float(t) / 3.0)
				var q0: Vector3 = mp.call(u.x, u.y, lift)
				pp.append(q0)
				oo.append(((q0 - (mp.call(u.x, u.y, lift - 0.01) as Vector3))).normalized())
			k.strip(pp, oo, 0.0016, 0.0011, ln, false, ssk)
		for i in pts2.size():
			var u2: Vector2 = pts2[i]
			var q1: Vector3 = mp.call(u2.x, u2.y, lift)
			var o1: Vector3 = (q1 - (mp.call(u2.x, u2.y, lift - 0.01) as Vector3)).normalized()
			P._stud(k, q1, o1, 0.0042 + 0.0018 * float(i % 2), st if i % 3 != 0 else cy, ssk.call(q1))
	for i in 30:
		var a: float = -PI + TAU * fposmod(float(i) * 0.618 + 0.05, 1.0)
		var y: float = lerpf(hem + 0.02, by - 0.045, fposmod(float(i) * 0.381 + 0.17, 1.0))
		var e: Array = Q._spt(sk, sff, a, y, lift)
		P._stud(k, e[0], e[1], 0.0024 + 0.0024 * fposmod(float(i) * 0.71, 1.0), st if i % 4 != 0 else cy, ssk.call(e[0]))


# ------------------------------------------------------------------ Kokuin Shōzoku (ref Shinobi Striker "Code Outfit"): dik yakalı koyu gömlek, dirsekte toplanan bol kol + lila çan manşet, sağ önü lila pliseli
## şeritli sivri uçlu siyah yelek, beyaz kravat, dizaltında katlı paça + lila çan paça
static func _kod(k) -> void:
	var dk := Color(0.141, 0.141, 0.173)
	var vs := Color(0.094, 0.094, 0.11)
	var li := Color(0.66, 0.565, 0.784)
	var wt := Color(0.93, 0.92, 0.95)
	var pn := Color(0.11, 0.11, 0.133)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var ik: Array = P._inner(k, b, func(_i, j, _p): return dk.lightened(0.04) if j % 6 == 2 else dk, 0.008)
	K._seat(k, b, pn)
	# dik yaka
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var ck := [P._kp(nk, N + 0.085 * q, 0.014, 0.018), P._kp(nk, N + 0.03 * q, 0.018), P._kp(nk, N - 0.03, 0.034), P._kp(nk, N - 0.06, 0.05, 0.045)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 9, "na": 44, "top": func(_a): return N + 0.08 * q, "hem": func(_a): return N - 0.055, "fold": func(a, y, _v): return 0.008 * sin(float(a) * 5.0 + float(y) * 20.0),
		"col": func(_a, _y, _v): return dk.lightened(0.03), "skin": nsk, "th": 0.006})
	P._cord(k, cg["top"], 0.004, dk.lightened(0.08), true, nsk)
	# kravat: düğüm + iki kat sivri uç
	var e0: Array = Q._spt(ik, Callable(), 0.0, N - 0.028, 0.022)
	P._boxr(k, e0[0], Vector3(0.017, 0, 0), Vector3(0, 0.014, 0), Vector3(0, 0, 0.011), wt, [["UpperChest", 0.6], ["Neck", 0.4]], 0.5)
	for e in [[-0.004, -0.024, 0.0, 0.115, -0.3], [0.006, 0.024, 0.004, 0.1, 0.25]]:
		var rows := []
		for j in 9:
			var v: float = float(j) / 8.0
			var y: float = N - 0.04 - v * float(e[3])
			var cx: float = lerpf(float(e[0]), float(e[1]), v)
			var hw: float = 0.004 + 0.026 * sin(pow(v, 0.7) * PI)
			var ro := []
			for i in 5:
				var u: float = float(i) / 4.0 * 2.0 - 1.0
				ro.append(P._fp(ik, cx + u * hw, y, true, 0.016 + float(e[2]) + 0.005 * (1.0 - u * u) + 0.004 * u * float(e[4]))[0])
			rows.append(ro)
		Q._mesh(k, rows, false, func(i, _j, _p): return wt.darkened(0.14) if i == 0 or i == 4 else wt, func(_i, _j, p): return k.torso_skin(p.y), Vector3(0, 0, 1))
	# kollar: bol üst kol dirsek altında toplanır, lila çan manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.2
		var s1: float = en + 0.1
		var pf := func(s: float, a: float) -> float:
			var bub: float = sin(clampf(s / s1, 0.0, 1.0) * PI)
			return 0.014 + 0.032 * pow(bub, 0.7) * (1.0 - smoothstep(s1 - 0.1, s1, s)) + 0.007 * P._lf(s, a, sv) * bub + 0.008 * exp(-pow((s - 0.1) / 0.1, 2.0))
		P._lt(k, ar, pf, func(s, a, ins): return dk.darkened(0.4) if ins else P._fs(dk, 0.007 * P._lf(float(s), float(a), sv) * sin(clampf(float(s) / s1, 0.0, 1.0) * PI), 12.0), 0.0, s1, 34, 22)
		P._lt(k, ar, func(s, _a): return 0.016 + 0.002 * sin(clampf((s - s1 + 0.035) / 0.04, 0.0, 1.0) * PI), func(_s, _a, ins): return dk.darkened(0.4) if ins else dk.lightened(0.05), s1 - 0.035, s1 + 0.004, 5, 22)
		var bf := func(s: float, a: float) -> float:
			var t: float = clampf((s - s1) / (0.985 - s1), 0.0, 1.0)
			return 0.011 + 0.042 * t * t + (0.003 + 0.01 * t * t) * sin(a * 7.0 + sv)
		P._lt(k, ar, bf, func(s, a, ins):
			var t: float = clampf((float(s) - s1) / (0.985 - s1), 0.0, 1.0)
			return li.darkened(0.14) if ins else P._fs(li, (0.003 + 0.01 * t * t) * sin(float(a) * 7.0 + sv), 9.0), s1 - 0.025, 0.985, 16, 28, 0.06)
		K._lt_in(k, ar, func(s, a): return float(bf.call(float(s), float(a))) - 0.005, li.darkened(0.1), 0.86, 0.985, 6, 28)
		P._lt(k, ar, func(s, a): return float(bf.call(float(s), float(a))) + 0.0022, func(_s, a, ins): return li.darkened(0.14) if ins else li.lightened(0.06 if sin(float(a) * 7.0 + sv) > 0.0 else 0.0), 0.955, 0.987, 3, 28)
		# pantolon: düz, diz altında katlı paça bandı, lila çan paça
		var sc: float = kn + 0.25
		var pf2 := func(s: float, a: float) -> float:
			return 0.016 + 0.006 * exp(-pow((s - kn + 0.1) / 0.2, 2.0)) + 0.006 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.003 * P._lf(s, a, sv) + 0.005 * smoothstep(kn + 0.05, sc, s)
		P._lt(k, le, pf2, func(s, a, ins): return pn.darkened(0.4) if ins else P._fs(pn, 0.006 * exp(-pow((float(s) - kn) / 0.05, 2.0)) * sin(float(a) * 3.0 + float(s) * 30.0 + sv) + 0.003 * P._lf(float(s), float(a), sv), 12.0), 0.0, sc, 38, 20, 0.02)
		P._lt(k, le, func(s, a): return float(pf2.call(s, a)) + 0.006 + 0.002 * sin(clampf((s - sc + 0.08) / 0.08, 0.0, 1.0) * PI), func(_s, _a, ins): return pn.darkened(0.4) if ins else pn.lightened(0.04), sc - 0.08, sc + 0.004, 6, 20)
		var lf := func(s: float, a: float) -> float:
			var t: float = clampf((s - sc) / (1.0 - sc), 0.0, 1.0)
			return 0.02 + 0.036 * t * t + (0.004 + 0.008 * t) * sin(a * 6.0 + sv)
		P._lt(k, le, lf, func(s, a, ins):
			var t: float = clampf((float(s) - sc) / (1.0 - sc), 0.0, 1.0)
			return li.darkened(0.14) if ins else P._fs(li, (0.004 + 0.008 * t) * sin(float(a) * 6.0 + sv), 9.0), sc - 0.03, 0.995, 14, 26, 0.05)
		K._lt_in(k, le, func(s, a): return float(lf.call(float(s), float(a))) - 0.005, li.darkened(0.1), 0.88, 0.995, 5, 26)
	# yelek: V açıklık, önde iki sivri uç, sırtı kapalı
	var vk := [P._kp(nk, N - 0.005, 0.03), [N - 0.06, ch.x * 0.9, ch.y * 0.95 + 0.02, ch.z * 1.02 - 0.02], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.024), P._kp(hp, H - 0.07, 0.03)]
	var vh := func(a: float) -> float: return H + 0.03 - 0.085 * exp(-pow((absf(a) - 0.2) / 0.22, 2.0))
	var vr := func(v: float) -> Vector2:
		var e: float = lerpf(0.62, 0.012, smoothstep(0.0, 0.42, v))
		return Vector2(e, TAU - e)
	var vf := func(a: float, y: float, _v: float) -> float:
		return 0.006 * sin(a * 6.0 + y * 14.0) * smoothstep(C, H + 0.04, y)
	var vff := func(a, y): return vf.call(float(a), float(y), 0.0)
	var vsk := func(p): return _ksk(k, p, H - 0.06)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 34, "na": 80, "rng": vr, "top": func(_a): return N - 0.005, "hem": func(a): return vh.call(float(a)), "fold": vf,
		"col": func(_a, _y, _v): return vs, "gain": 7.0, "th": 0.006, "inner": vs.darkened(0.3), "skin": vsk})
	for ed in [vg["ea"], vg["eb"]]:
		P._bd(k, ed, 0.0032, 0.002, vs.lightened(0.08), false, vsk, 0.1)
	var vhm := []
	for p in vg["hem"]:
		vhm.append((p as Vector3) + Vector3(0, 0.007, 0))
	P._bd(k, vhm, 0.0028, 0.0016, vs.lightened(0.06), false, vsk)
	# sağ önde lila pliseli şerit: omuzdan yelek ucuna
	var lr := func(v: float) -> Vector2:
		var e: Vector2 = vr.call(v)
		return Vector2(-(e.x + 0.4), -(e.x + 0.1))
	var plf := func(a: float, _y: float, _v: float) -> float: return 0.012 * Q._tri(a * 125.0)
	var lg: Dictionary = P._cl(k, {"keys": vk, "ny": 30, "na": 26, "rng": lr, "top": func(_a): return N - 0.01, "hem": func(a): return vh.call(float(a)) + 0.004, "fold": plf,
		"col": func(_a, _y, _v): return li, "gain": 10.0, "th": 0.003, "lift": 0.0035, "inner": li.darkened(0.3), "skin": vsk})
	for ed in [lg["ea"], lg["eb"]]:
		P._bd(k, ed, 0.0022, 0.0014, li.darkened(0.25), false, vsk)
	# düğmeler + bel cebi
	for i in 4:
		var y: float = lerpf(C - 0.07, H + 0.05, float(i) / 3.0)
		var e3: Array = Q._spt(vk, vff, 0.045, y, 0.006)
		P._stud(k, e3[0], e3[1], 0.0055, Color(0.24, 0.24, 0.29), vsk.call(e3[0]))
	P._strap(k, vk, [Vector2(wa.x * 0.38, H + 0.085), Vector2(wa.x * 0.74, H + 0.075)], true, 0.0035, 0.004, 0.002, vs.lightened(0.1), 4, vsk)


# ------------------------------------------------------------------ Kurogane Yoroi (ref Shinobi Striker "Custom Ninja Outfit: Type Three"): siyah pullu gövde zırhı (kırmızı bağcık sıraları), büyük omuzluklar,
## önde kalın beyaz shimenawa fiyonku + sarkan burgu uçlar, kalçada mavi kenarlı ve gümüş güllü etek plakaları, önde bordo önlük + püskül, omuzdan sarkan muska,
## lacivert hakama (dizaltında kırmızı bant), kavalda kırmızı çapraz bağ
static func _samuray(k) -> void:
	var b: Dictionary = L._base(k)
	var bk := Color(0.11, 0.11, 0.135)
	var nv := Color(0.13, 0.15, 0.29)
	var rd := Color(0.66, 0.13, 0.13)
	var mr := Color(0.36, 0.07, 0.09)
	var bl := Color(0.22, 0.3, 0.62)
	var sv := Color(0.76, 0.78, 0.82)
	var wt := Color(0.95, 0.94, 0.92)
	var gr := Color(0.5, 0.5, 0.53)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var hp: Vector3 = b["hp"]
	L._seat(k, b, nv)
	# iç kimono + beyaz iç yaka (sol kanat üstte)
	var ik := [L._kp(nk, N + 0.07, 0.012, 0.014), L._kp(nk, N + 0.025, 0.018), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.92], L._kp(ch, C - 0.03, 0.012), L._kp(b["wa"], H + 0.12, 0.012), L._kp(b["hp"], H - 0.1, 0.012)]
	SE.body_layer(k, ik, 24, 44, func(_i, _j, _p): return nv.darkened(0.3))
	P._line(k, ik, [Vector2(-0.64, N + 0.035), Vector2(-0.32, N - 0.03), Vector2(0.03, N - 0.085)], 0.016, 0.002, 0.0034, nv.darkened(0.1), 6)
	P._line(k, ik, [Vector2(0.64, N + 0.035), Vector2(0.32, N - 0.03), Vector2(-0.03, N - 0.09)], 0.016, 0.0035, 0.0034, nv.darkened(0.1), 6)
	P._line(k, ik, [Vector2(-0.6, N + 0.04), Vector2(-0.3, N - 0.022), Vector2(0.0, N - 0.07)], 0.0075, 0.0055, 0.0026, wt, 6)
	P._line(k, ik, [Vector2(0.6, N + 0.04), Vector2(0.3, N - 0.022), Vector2(-0.01, N - 0.076)], 0.0075, 0.0072, 0.0026, wt, 6)
	# kollar: koyu kimono kolu, kolluk plakası, omuzluk
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var en: float = l["kn"]
		var rip := func(s: float, a: float) -> float: return 0.006 * sin(a * 3.0 + s * 19.0) + 0.008 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		L._lt(k, l, func(s, a): return 0.012 + 0.016 * smoothstep(0.1, 0.45, s) * (1.0 - smoothstep(0.6, 0.7, s)) + float(rip.call(s, a)), func(s, a, ins):
			return nv.darkened(0.4) if ins else L._fs(nv.darkened(0.2), float(rip.call(s, a)), 14.0), 0.0, 1.0, 34, 20)
		L._splint(k, l, 0.62, 0.95, 0.0, 0.88, 0.01, 0.007, bk, rd, 6, 0.2)
		for s in [0.67, 0.93]:
			k.wrap_turn(L._lp(l, s), L._ld(l, s), L._lr(l, s) + 0.013, 0.005, 0.0, rd, L._lskin(l, s))
		L._sode(k, l, {"s0": 0.0, "n": 4, "ln": 0.088, "ov": 0.018, "W": 0.1, "R": 0.076, "curve": 1.5, "col": bk, "trim": rd, "lace": rd, "th": 0.009})
	# hakama + kaval
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		L._wide(k, b, l, {"col": nv, "prof": func(s): return 0.024 + 0.062 * smoothstep(0.05, kn, s) * (1.0 - smoothstep(kn + 0.1, 0.74, s)) + 0.01 * (1.0 - smoothstep(0.7, 0.75, s)), "pl": 6.0, "amp": 0.03, "s1": 0.76, "top": 0.05, "seg": 42, "n": 30, "cmax": 0.82, "pad": 0.03})
		L._lt(k, l, func(_s, _a): return 0.008, func(_s, _a, ins): return nv.darkened(0.4) if ins else nv.darkened(0.14), 0.7, 1.0, 14, 16)
		k.wrap_turn(L._lp(l, 0.765), L._ld(l, 0.765), L._lr(l, 0.765) + 0.022, 0.011, 0.0, rd, L._lskin(l, 0.765))
		for dr in [1.0, -1.0]:   # kırmızı çapraz bağ: iki ters sarmal
			var pts := []
			for i in 25:
				var t: float = float(i) / 24.0
				var s: float = lerpf(0.8, 0.965, t)
				pts.append(Q._ls(l, s, dr * t * TAU * 1.5 + 0.3, 0.0115)[0])
			P._tb(k, pts, func(_s, _a): return 0.0032, func(_s, a, _p): return rd.darkened(0.2) if cos(float(a)) < -0.3 else rd, func(s, _p): return L._lskin(l, lerpf(0.8, 0.965, float(s))), 6)
		k.wrap_turn(L._lp(l, 0.972), L._ld(l, 0.972), L._lr(l, 0.972) + 0.012, 0.007, 0.0, rd.darkened(0.1), L._lskin(l, 0.972))
	# gövde zırhı: göğüs levhası + pullu sıralar (kırmızı bağcık), beyaz bağ uçları
	var dkey: Array = L._tk(k, b, 0.03, H, 0.0, 0.0)
	var top_y: float = N - 0.072
	var mun: float = C + 0.005
	for ac in [0.0, PI]:
		_plate(k, dkey, ac, PI * 0.5 + 0.012, top_y, mun, 0.002, 0.01, bk, gr, 30, 14)
	var nr := 6
	for r in nr:
		var y0: float = lerpf(mun - 0.004, H + 0.0, float(r) / nr)
		var y1: float = lerpf(mun - 0.004, H + 0.0, float(r + 1) / nr) - 0.003
		var add: float = 0.004 + 0.0022 * r
		for ac in [0.0, PI]:
			_plate(k, dkey, ac, PI * 0.5 + 0.012, y0, y1, add, 0.008, bk, rd, 28, 10)
		var ym: float = (y0 + y1) * 0.5
		for i in 22:
			var a: float = -PI + TAU * (float(i) + 0.5 * float(r % 2)) / 22.0
			var e: Array = L._sa(dkey, a, ym, add + 0.0105)
			k.strip([(e[0] as Vector3) + Vector3(0, 0.008, 0), (e[0] as Vector3) + Vector3(0, -0.008, 0)], [e[1], e[1]], 0.0028, 0.0014, Color(0.82, 0.82, 0.84), false, func(p): return k.torso_skin(p.y))
	# göğüste gümüş gül
	var er: Array = P._fp(dkey, ch.x * 0.36, N - 0.115, true, 0.016)
	_rose(k, er[0], er[1], 0.026, sv, k.torso_skin(N - 0.115))
	# omuzdan sarkan muskalar: gümüş halka, ip, levha (sağda kırmızı, solda siyah)
	for sg in [1.0, -1.0]:
		var e1: Array = P._fp(dkey, sg * ch.x * 0.66, N - 0.06, true, 0.022)
		var c1: Vector3 = e1[0]
		var bo := [["UpperChest", 1.0]]
		var ring := []
		for i in 12:
			var th: float = TAU * i / 12.0
			ring.append(c1 + Vector3(sg * 0.002, 0.012 + sin(th) * 0.011, cos(th) * 0.011))
		P._tb(k, ring, func(_s, _a): return 0.0026, func(_s, _a, _p): return sv, func(_s, _p): return bo, 6, true)
		var tc: Vector3 = c1 + Vector3(0, -0.06, 0.004)
		P._tb(k, [c1, c1.lerp(tc, 0.5) + Vector3(0, 0, 0.002), tc + Vector3(0, 0.042, 0)], func(_s, _a): return 0.0022, func(_s, _a, _p): return rd.darkened(0.2), func(_s, _p): return bo, 5)
		var fc: Color = rd if sg < 0.0 else bk.lightened(0.06)
		var ic: Color = bk if sg < 0.0 else rd
		P._boxr(k, tc, Vector3(0.021, 0, 0), Vector3(0, 0.043, 0), Vector3(0, 0, 0.0045), ic, bo, 0.12)
		P._boxr(k, tc + Vector3(0, 0, 0.0035), Vector3(0.016, 0, 0), Vector3(0, 0.037, 0), Vector3(0, 0, 0.003), fc, bo, 0.12)
		for st in [[0.0, 0.026, 0.0, -0.026], [-0.008, 0.014, 0.008, 0.014], [-0.008, -0.004, 0.008, -0.004], [-0.006, -0.02, 0.0, -0.012]]:
			k.strip([tc + Vector3(float(st[0]), float(st[1]), 0.0072), tc + Vector3(float(st[2]), float(st[3]), 0.0072)], [Vector3.BACK, Vector3.BACK], 0.0014, 0.0008, wt if sg < 0.0 else rd.lightened(0.2), false, func(_p): return bo)
	# kalçalık plakalar: yanlar ve arka, mavi kenar + gümüş gül
	for e in [[PI * 0.5 - 0.02, 0.4, true], [-PI * 0.5 + 0.02, 0.4, true], [PI - 0.36, 0.34, false], [-PI + 0.36, 0.34, false], [0.66, 0.3, false], [-0.66, 0.3, false]]:
		var ac: float = e[0]
		var aw: float = e[1]
		var n := 4
		var h := 0.098
		var ov := 0.016
		var add := 0.05
		var flare := 0.28
		var th2 := 0.008
		var y0: float = H + 0.02
		L._tasset(k, b, {"y0": y0, "ac": ac, "aw": aw, "n": n, "h": h, "ov": ov, "flare": flare, "add": add, "col": nv.darkened(0.35), "trim": bl, "lace": rd, "th": th2})
		if bool(e[2]):
			var total: float = n * (h - ov) + ov
			var yb: float = y0 - (n - 1) * (h - ov) - h * 0.45
			var tt: float = (y0 - yb) / total
			var qq: Vector2 = SE.El.sup(ac, hp.x + add, hp.y + add, -(absf(hp.z) + add), 2.3)
			var sc: float = 1.0 + flare * tt
			var o: Vector3 = Vector3(qq.x, 0.0, qq.y).normalized()
			var c2: Vector3 = Vector3(qq.x * sc, yb, qq.y * sc) + o * (0.005 + 0.0035 * (n - 1) + th2 + 0.003)
			var gain: float = 0.72
			var w: float = gain * smoothstep(0.0, 0.85, tt)
			var lb: String = "LeftUpperLeg" if sin(ac) > 0.0 else "RightUpperLeg"
			_rose(k, c2, Vector3(o.x, 0.12, o.z).normalized(), 0.03, sv, [["Hips", 1.0 - w], [lb, w]])
	# ön: iki sıra pullu plaka + bordo önlük, gri kenar, püsküller (iki bacağın ortalamasını izler)
	var fh: float = H - 0.32
	var fk := [[H + 0.03, hp.x + 0.052, hp.y + 0.05, hp.z - 0.05], [fh, hp.x + 0.085, hp.y + 0.075, hp.z - 0.085]]
	var fsk := func(p): return _ksk(k, p, fh)
	var frg := func(_v): return Vector2(-0.36, 0.36)
	P._cl(k, {"keys": fk, "ny": 16, "na": 22, "rng": frg, "top": func(_a): return H + 0.03, "hem": func(_a): return fh, "fold": func(a, _y, v): return 0.006 * sin(float(a) * 9.0) * float(v),
		"col": func(_a, y, _v):
			var yy: float = float(y)
			if yy > H - 0.13:
				return rd if fposmod((H + 0.03 - yy) / 0.08, 1.0) > 0.86 else bk
			return gr if yy < fh + 0.022 else mr, "gain": 3.0, "th": 0.006, "inner": bk, "skin": fsk})
	for sg in [1.0, -1.0]:
		var e5: Array = Q._spt(fk, Callable(), sg * 0.33, fh + 0.004, 0.006)
		var t0: Vector3 = e5[0]
		P._tb(k, [t0, t0 + Vector3(0, -0.012, 0.002), t0 + Vector3(0, -0.034, 0.003)], func(s, _a): return 0.0025 + 0.0075 * smoothstep(0.3, 1.0, float(s)), func(_s, a, _p): return wt.darkened(0.15) if sin(float(a) * 5.0) < -0.5 else wt, func(_s, p): return fsk.call(p), 10)
	# shimenawa: bele sarılı kalın halat, önde iki büyük ilmek, düğüm, sarkan iki uç
	var by: float = H + 0.075
	var hsk := func(_p): return [["Hips", 0.5], ["Spine", 0.5]]
	var rp := []
	for p in P._ring_pts(dkey, by, 0.034, 72):
		rp.append(p)
	_twist(k, rp, true, 0.017, 9.0, wt, func(p): return k.torso_skin(maxf(p.y, H + 0.04)))
	var kc: Array = L._sa(dkey, 0.0, by, 0.058)
	var c0: Vector3 = kc[0]
	for sg in [1.0, -1.0]:
		var lp := []
		for i in 26:
			var th: float = TAU * float(i) / 26.0
			lp.append(c0 + Vector3(sg * (0.016 + 0.082 * (1.0 - cos(th))), 0.046 * sin(th) + 0.012 * (1.0 - cos(th)), 0.012 * sin(th * 0.5) - 0.012 * (1.0 - cos(th)) * 0.5))
		_twist(k, lp, true, 0.0145, 6.0, wt, hsk)
	_twist(k, [c0 + Vector3(0, 0.034, -0.004), c0 + Vector3(0, 0.0, 0.006), c0 + Vector3(0, -0.032, -0.002)], false, 0.024, 1.5, wt, hsk)
	for sg in [1.0, -1.0]:
		var tl := []
		for i in 9:
			var t: float = float(i) / 8.0
			tl.append(c0 + Vector3(sg * (0.012 + 0.03 * t), -0.03 - 0.2 * t, 0.006 - 0.008 * t + 0.01 * sin(t * PI)))
		_twist(k, tl, false, 0.0115, 4.0, wt, fsk, 0.25)
		var tp: Vector3 = tl[tl.size() - 1]
		P._tb(k, [tp + Vector3(0, 0.004, 0), tp + Vector3(0, -0.012, 0.002), tp + Vector3(0, -0.032, 0.003)], func(s, _a): return 0.006 + 0.004 * smoothstep(0.0, 1.0, float(s)), func(_s, a, _p): return wt.darkened(0.16) if sin(float(a) * 6.0) < -0.4 else wt, func(_s, p): return fsk.call(p), 10)
	L._hem = fh


# ------------------------------------------------------------------ Kurokawa (ref Shinobi Striker "Custom Ninja Outfit: Type Two"): simsiyah tulum, beyaz-lila şeritli çapraz yaka, omuzluk + beyaz kenar,
## parlayan hatlı kolluk, eldiven, göğüs kayışı + kemer, kalçada perçinli koruyucu, dizde beyaz ok, beyaz üçgenli kaval koruyucu
static func _tulum(k) -> void:
	var bk := Color(0.065, 0.065, 0.08)
	var ar_c := Color(0.12, 0.12, 0.14)
	var gl := Color(1.0, 0.93, 0.98)
	var pk := Color(1.0, 0.72, 0.9)
	var li := Color(0.62, 0.6, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var ik: Array = P._inner(k, b, func(_i, j, _p): return bk.lightened(0.03) if j % 5 == 2 else bk, 0.006)
	K._seat(k, b, bk)
	# boğazlık
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var ck := [P._kp(nk, N + 0.075 * q, 0.01, 0.013), P._kp(nk, N + 0.025 * q, 0.014), P._kp(nk, N - 0.03, 0.028)]
	P._cl(k, {"keys": ck, "ny": 7, "na": 40, "top": func(_a): return N + 0.07 * q, "hem": func(_a): return N - 0.03, "fold": func(a, y, _v): return 0.02 * sin(float(a) * 4.0 + float(y) * 60.0),
		"col": func(_a, _y, _v): return bk, "skin": nsk, "th": 0.005})
	# çapraz yaka: sol kanat üstte; beyaz zemin, ortasında lila hat
	for sg in [-1.0, 1.0]:
		var ctrl := [Vector2(sg * 0.78, N + 0.03), Vector2(sg * 0.42, N - 0.025), Vector2(-sg * 0.1, N - 0.088)]
		var lift: float = 0.004 + (0.003 if sg > 0.0 else 0.0)
		P._line(k, ik, ctrl, 0.012, lift, 0.003, gl, 6)
		P._line(k, ik, ctrl, 0.0034, lift + 0.0032, 0.0012, li, 6)
	# göğüs kayışı + toka, kemer + kare toka
	var hk: Array = []
	for e in ik:
		hk.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.006, float(e[3]) - 0.006])
	P._sash(k, hk, C - 0.04, 0.012, 0.0, ar_c, 0.06)
	P._sash(k, hk, H + 0.06, 0.017, 0.002, ar_c, 0.08)
	for e in [[ch_x(b) * 0.38, C - 0.04, 0.013], [-ch_x(b) * 0.38, C - 0.04, 0.013], [0.0, H + 0.06, 0.02]]:
		var ep: Array = P._fp(hk, float(e[0]), float(e[1]), true, 0.022)
		var hs: float = e[2]
		P._boxr(k, ep[0], Vector3(hs, 0, 0), Vector3(0, hs * 0.9, 0), (ep[1] as Vector3) * 0.005, Color(0.17, 0.17, 0.2), k.torso_skin(float(e[1])), 0.25)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.3 if sd == "Left" else 2.4
		var sl := func(s: float, a: float) -> float:
			return 0.006 + 0.004 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.002 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI)
		P._lt(k, ar, sl, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.03), float(sl.call(float(s), float(a))) - 0.006, 20.0), 0.0, 0.9, 30, 18)
		# omuzluk: üst kolu saran kabuk, alt kenarında beyaz hat, üstte beyaz çentik
		var ao: float = J._outer_a(ar, 0.15, Vector3(sg * 0.6, 1.0, 0.0).normalized())
		var pad := func(s: float, a: float) -> float: return float(sl.call(s, a)) + 0.012 + 0.012 * sin(clampf((s - 0.02) / 0.3, 0.0, 1.0) * PI)
		K._shell(k, ar, 0.02, 0.32, ao - 1.7, ao + 1.7, pad, 0.008, func(_u, v, ins): return ar_c.darkened(0.3) if ins else ar_c.darkened(0.12 * v), 12, 18)
		_lline(k, ar, [Vector2(0.305, ao - 1.45), Vector2(0.305, ao), Vector2(0.305, ao + 1.45)], func(s, a): return float(pad.call(s, a)) + 0.0085, 0.0045, gl, 8)
		_lline(k, ar, [Vector2(0.07, ao + 0.35), Vector2(0.13, ao + 0.55)], func(s, a): return float(pad.call(s, a)) + 0.0085, 0.0042, gl, 3)
		# kolluk: dirsek altında genişleyen ağız, parlayan iki hat
		var ao2: float = J._outer_a(ar, 0.75, Vector3(sg, 0.0, 0.0))
		var gd := func(s: float, a: float) -> float: return float(sl.call(s, a)) + 0.008 + 0.016 * (1.0 - smoothstep(en + 0.04, en + 0.2, s))
		K._shell(k, ar, en + 0.04, 0.88, ao2 - 1.5, ao2 + 1.5, gd, 0.007, func(_u, _v, ins): return ar_c.darkened(0.3) if ins else ar_c, 14, 18)
		_lline(k, ar, [Vector2(en + 0.12, ao2 + 0.55), Vector2(0.74, ao2 + 0.5), Vector2(0.8, ao2 + 0.95)], func(s, a): return float(gd.call(s, a)) + 0.0075, 0.0018, pk, 5)
		_lline(k, ar, [Vector2(en + 0.14, ao2 - 0.6), Vector2(0.7, ao2 - 0.55)], func(s, a): return float(gd.call(s, a)) + 0.0075, 0.0016, gl, 5)
		P._lt(k, ar, func(s, _a): return 0.015 + 0.002 * sin(clampf((s - 0.885) / 0.07, 0.0, 1.0) * PI), func(_s, _a, ins): return ar_c.darkened(0.3) if ins else ar_c, 0.885, 0.955, 6, 20)
		K._glove(k, sd, ar, bk, ar_c)
		# bacak
		var pa := func(s: float, a: float) -> float:
			return 0.007 + 0.004 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.002 * P._lf(s, a, sv) * (1.0 - smoothstep(kn + 0.1, kn + 0.3, s))
		P._lt(k, le, pa, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.03), float(pa.call(float(s), float(a))) - 0.007, 20.0), 0.0, 1.0, 40, 20)
		# kalça koruyucu + ön kenarda beyaz perçinler
		var ho: float = sg * PI * 0.5
		var hpf := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.012 + 0.006 * sin(clampf(s / 0.3, 0.0, 1.0) * PI)
		K._shell(k, le, 0.03, 0.3, ho - 0.9, ho + 0.9, hpf, 0.008, func(_u, _v, ins): return ar_c.darkened(0.3) if ins else ar_c.darkened(0.04), 12, 16)
		for i in 7:
			var s: float = lerpf(0.06, 0.27, float(i) / 6.0)
			var a: float = ho - sg * 0.78
			var e: Array = Q._ls(le, s, a, float(hpf.call(s, a)) + 0.0075)
			P._stud(k, e[0], e[1], 0.0045, gl, P._lskin(le, s))
		# dizde beyaz ok
		_lline(k, le, [Vector2(kn - 0.075, -0.32), Vector2(kn - 0.04, 0.0), Vector2(kn - 0.075, 0.32)], func(s, a): return float(pa.call(s, a)) + 0.002, 0.005, gl, 3)
		# kaval koruyucu: önde, üstte beyaz üçgen, iç yanında beyaz hat; bilek bandı + beyaz levha
		var sh := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.008 + 0.004 * (1.0 - smoothstep(kn + 0.12, kn + 0.25, s))
		K._shell(k, le, kn + 0.12, 0.9, -1.25, 1.25, sh, 0.008, func(_u, _v, ins): return ar_c.darkened(0.3) if ins else ar_c, 16, 16)
		var trs := []
		for j in 5:
			var v: float = float(j) / 4.0
			var s: float = lerpf(kn + 0.2, kn + 0.135, v)
			var w: float = 0.42 * (1.0 - v) + 0.02
			trs.append([Vector2(s, -w), Vector2(s, 0.0), Vector2(s, w)])
		_lpatch(k, le, trs, func(s, a): return float(sh.call(s, a)) + 0.0085, gl)
		_lline(k, le, [Vector2(kn + 0.22, -sg * 0.95), Vector2(0.86, -sg * 0.9)], func(s, a): return float(sh.call(s, a)) + 0.0082, 0.0016, gl, 6)
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.012 + 0.002 * sin(clampf((s - 0.9) / 0.07, 0.0, 1.0) * PI), func(_s, _a, ins): return ar_c.darkened(0.3) if ins else ar_c, 0.9, 0.97, 6, 20)
		var rs := []
		for j in 3:
			var s: float = lerpf(0.925, 0.948, float(j) / 2.0)
			rs.append([Vector2(s, -0.2), Vector2(s, 0.0), Vector2(s, 0.2)])
		_lpatch(k, le, rs, func(s, a): return float(pa.call(s, a)) + 0.0165, gl)


static func ch_x(b: Dictionary) -> float:
	return float((b["ch"] as Vector3).x)
