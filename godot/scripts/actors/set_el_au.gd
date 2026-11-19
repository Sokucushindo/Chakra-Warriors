extends RefCounted
## Elle modellenmiş setler, parti au: ss_antrenman_geishun, ss_naginata, ss_kumarbaz, ss_kopuk, ss_kedi, ss_harika. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{training_clothes/WTNY, tsubaki_outfit/Tsubaki_1, tsunade_outfit, utakata_outfit/Utakata_1, wasabi_outfit, wonder_striker}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), m (M), q (Q), r (R), y (Y), z (Z), aa (AA), i (I) dosyalarından; burada fiyonk, pli etek ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const J = preload("res://scripts/actors/set_el_j.gd")

const DONE := ["ss_antrenman_geishun", "ss_naginata", "ss_kumarbaz", "ss_kopuk", "ss_kedi", "ss_harika"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_antrenman_geishun": _geishun(k)
		"ss_naginata": _naginata(k)
		"ss_kumarbaz": _kumarbaz(k)
		"ss_kopuk": _kopuk(k)
		"ss_kedi": _kedi(k)
		"ss_harika": _harika(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Fiyonk ilmeği: düğümden yana çıkan, arkaya dönüp düğüme geri gelen kurdele (yüzü öne bakar, dış ucu geniş).
## c düğüm merkezi, o dış yön (öne), side yan yön (±), ln ilmek boyu, w dış uç yarı yüksekliği, dep ilmek derinliği
static func _bow_loop(k, c: Vector3, o: Vector3, side: Vector3, ln: float, w: float, dep: float, droop: float, col: Color, skinf: Callable) -> void:
	var up: Vector3 = side.cross(o).normalized()
	if up.y < 0.0:
		up = -up
	var pts := []
	var ou := []
	var n := 20
	for i in n + 1:
		var t := TAU * float(i) / n
		var x: float = ln * 0.5 * (1.0 - cos(t))   # 0 düğüm, ln dış uç
		var z: float = dep * 0.5 * sin(t) * (0.55 + 0.45 * sin(t * 0.5))
		var p: Vector3 = c + side * x + o * (z + dep * 0.12) - up * droop * pow(x / ln, 2.0)
		pts.append(p)
		var nrm: Vector3 = (side * (-cos(t) / maxf(0.01, ln * 0.5)) + o * (sin(t) / maxf(0.01, dep * 0.5))).normalized()
		if i == 0 or i == n:
			nrm = -side
		ou.append(nrm)
	Y._ribbon(k, pts, ou, func(t): return lerpf(w * 0.35, w, pow(sin(float(t) * PI), 0.7)), 0.0025, col, skinf)


## Fiyonk: iki ilmek + ortada sıkı düğüm + kumaşa oturan iki uç (uçlar yüzey yolunu izler)
static func _bow(k, keys: Array, ff: Callable, a0: float, y0: float, sz: float, col: Color, skinf: Callable, tails := 0.12) -> void:
	var e: Array = Q._spt(keys, ff, a0, y0, 0.024)
	var c: Vector3 = e[0]
	var o: Vector3 = e[1]
	var sd: Vector3 = Vector3.UP.cross(o).normalized()
	for sg in [1.0, -1.0]:
		_bow_loop(k, c, o, sd * sg, sz * 1.05, sz * 0.6, sz * 0.5, sz * 0.15, col.darkened(0.04 * (1.0 + sg)), skinf)
	P._boxr(k, c + o * sz * 0.12, sd * sz * 0.17, Vector3.UP * sz * 0.22, o * sz * 0.13, col.darkened(0.06), skinf.call(c), 0.45)
	# uçlar: düğümden kumaş üstünde aşağı, uçta geniş ve verev kesik
	if tails <= 0.0:
		return
	for e2 in [[0.06, 1.0], [-0.04, 0.82]]:
		var pts := []
		var ou := []
		for j in 9:
			var t := float(j) / 8.0
			var q: Array = Q._spt(keys, ff, a0 + float(e2[0]) * t * 1.6 + float(e2[0]) * 0.2, y0 - 0.01 - tails * float(e2[1]) * t, 0.006 + 0.004 * (1.0 - t))
			pts.append(q[0])
			ou.append(q[1])
		Y._ribbon(k, pts, ou, func(t): return sz * lerpf(0.13, 0.24, float(t)), 0.0025, col.darkened(0.03), skinf)


# ------------------------------------------------------------------ Keiko-gi: Geishun (ref Shinobi Striker "Training Clothes: Welcome the New Year"): geniş kısa kollu beyaz gi (sol kanat sağın üstüne,
## içte kırmızı yaka), omuzlardan geçip sırtta çaprazlanan sarı tasuki, yüksek belli bıçak pli kırmızı etek (önde sağda büyük fiyonk, uçta beyaz bant + ince çizgi),
## açık uyluk, ağzı kırmızı-siyah çizgili diz üstü beyaz çorap (zōri ayak parçası)
static func _geishun(k) -> void:
	var wh := Color(0.957, 0.957, 0.965)
	var rd := Color(0.69, 0.094, 0.125)
	var ye := Color(0.96, 0.78, 0.2)
	var og := Color(0.93, 0.56, 0.16)
	var bk := Color(0.12, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	M._inner_v(k, b, rd)
	M._seat(k, b, rd.darkened(0.25))
	# bacaklar: açık uyluk + diz üstü beyaz çorap, ağzında kırmızı ve siyah kabartma çizgi
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var st: float = kn * 0.78
		Y._sock_leg(k, le, wh, st, 0.7 if sd == "Left" else 2.1, 0.024)
		for e in [[st + 0.034, rd, 0.0052], [st + 0.05, bk, 0.0036]]:
			Q._ring_on(k, le, float(e[0]), func(_s, _a): return 0.0058, float(e[2]), e[1], 0.0016)
	# gi gövdesi: sol kanat sağın üstüne biner, eteğin içine girer
	var ht: float = H + 0.15
	var hm0: float = H + 0.05
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.012), [hm0, wa.x + 0.006, wa.y + 0.006, wa.z - 0.006]]
	var gfold := func(a: float, y: float, _v: float) -> float:
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		var blouse: float = 0.016 * exp(-pow((y - (ht + 0.03)) / 0.028, 2.0)) * (0.6 + 0.4 * sin(a * 7.0 + 0.8))
		return 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(0.2, 0.5, up) + 0.009 * sin(a * 5.0 - y * 16.0) * (1.0 - smoothstep(0.3, 0.6, up)) + blouse
	M._wrap(k, {"keys": keys, "hem": hm0, "col": func(_a, _y, _v): return wh, "fold": gfold, "band": wh.darkened(0.03), "band_w": 0.016, "juban": rd,
		"ny": 40, "na": 60, "gain": 4.5, "inner": wh.darkened(0.22)})
	# kollar: dirseğe inen geniş kısa kol (astarlı ağız), altı açık ten
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.5
		R._arm_skin(k, ar, 0.2)
		M._wide(k, ar, func(s: float) -> float: return 0.056 + 0.022 * smoothstep(0.05, 0.4, s), func(s: float) -> float: return 0.012 + 0.016 * smoothstep(0.15, 0.8, s / en),
			func(s: float, a: float) -> float: return 0.03 * sin(a * 3.0 + s * 9.0 + sv) + 0.016 * sin(a * 5.0 + sv), func(s: float, a: float, ins: bool) -> Color:
				if ins:
					return wh.darkened(0.16)
				return P._fs(wh, 0.01 * sin(a * 3.0 + s * 9.0 + sv), 7.0), en - 0.01, 0.04, 0.06, 26, 36)
	# tasuki: önde koltuk altından omuz üstüne, arkada çapraz
	var tk2 := [keys[0], keys[1], keys[2], keys[3]]
	for sg in [1.0, -1.0]:
		P._over(k, keys, sg * ch.x * 0.92, C - 0.085, C - 0.06, 0.012, 0.009, 0.004, ye)
		P._strap(k, tk2, [Vector2(sg * ch.x * 0.92, C - 0.06), Vector2(0.0, C - 0.11), Vector2(-sg * ch.x * 0.86, C - 0.15)], false, 0.012, 0.0095 + 0.001 * sg, 0.004, ye.darkened(0.03 * (1.0 + sg)), 10, tsk)
	# etek: yüksek bel, kalçadan açılan bıçak pliler, uyluk ortasında biter
	var y0: float = ht
	var hem: float = H - 0.27
	var wm: Vector3 = k.M(y0, k.UA)
	var tw := Vector3(maxf(wm.x, wa.x), maxf(wm.y, wa.y), minf(wm.z, wa.z))
	var ek := [[y0, tw.x + 0.02, tw.y + 0.022, tw.z - 0.02], [H + 0.04, tw.x + 0.024, tw.y + 0.026, tw.z - 0.026], [H - 0.06, hp.x + 0.034, hp.y + 0.04, hp.z - 0.04], [hem, hp.x + 0.1, hp.y + 0.095, hp.z - 0.1]]
	var esk := func(p): return Y._msk(k, p, hem)
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((y0 - 0.03 - y) / (y0 - 0.03 - hem), 0.0, 1.0)
		return Y._pleat(a, 11.0, 0.045) * smoothstep(0.0, 0.3, t) + t * 0.01 * sin(a * 3.0 + 0.6) + 0.002 * sin(a * 9.0 + y * 22.0)
	var eg: Dictionary = P._cl(k, {"keys": ek, "ny": 26, "na": 132, "top": func(_a): return y0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ef.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 7.0, "th": 0.007, "inner": rd.darkened(0.3), "skin": esk})
	var eff := func(a, y): return ef.call(float(a), float(y))
	# uçta beyaz bant + üstünde ince beyaz çizgi (pliyi izleyen kabartma)
	for e in [[hem + 0.022, 0.0115, wh], [hem + 0.05, 0.0032, wh]]:
		var pts := []
		for i in 133:
			pts.append(Vector2(TAU * i / 132.0 - PI, float(e[0])))
		Q._run(k, ek, eff, pts, float(e[1]), 0.0028, 0.0016, e[2], esk, 1, false)
	# bel: üstte kalın kuşak bandı, önde sağda büyük fiyonk
	P._sash(k, [P._kp(k.M(y0 + 0.02, k.UA), y0 + 0.02, 0.022), P._kp(k.M(y0 - 0.05, k.UA), y0 - 0.05, 0.024)], y0 - 0.012, 0.02, 0.006, rd.darkened(0.06), 0.16)
	_bow(k, ek, eff, -0.32, y0 - 0.02, 0.075, rd.lightened(0.1), esk, 0.13)
	# arkada koshi-ita yerine sırtta düz kat: kuşağın altında iki kısa dikiş
	for sg in [1.0, -1.0]:
		Q._run(k, ek, eff, [Vector2(PI - sg * 0.25, y0 - 0.035), Vector2(PI - sg * 0.27, H - 0.0)], 0.0016, 0.002, 0.0012, rd.darkened(0.2), esk, 4)


## Kimono yaka bandının üstünde ince renk şeridi (M._wrap'in bant yolunu izler; alttaki kanadın şeridi bindirmenin altında kesilir)
static func _wrap_stripe(k, wg: Dictionary, top: float, low: float, hem: float, col: Color, hw: float, y_min: float) -> void:
	var C: float = k.C
	for left: bool in [true, false]:
		var g: Dictionary = wg["L" if left else "R"]
		var ed: Array = g["ea"] if left else g["eb"]
		var pts := []
		for q: Vector3 in ed:
			var s: float = smoothstep(C - 0.03, top, q.y)
			if q.y < y_min or (not left and lerpf(0.45, -0.4, s) > lerpf(low, 0.4, s)):
				break
			pts.append(q + Vector3(0.012 if left else -0.012, 0.0, 0.0))
		if pts.size() >= 2:
			P._bd(k, pts, hw, 0.0068, col, false, func(p): return M._wrap_skin(k, p, hem, left), 0.1)


# ------------------------------------------------------------------ Naginata Hakama (ref Shinobi Striker "Tsubaki Outfit: Naginata"): siyah boğazlı iç giysi, pembe çizgili yakalı geniş kısa kollu beyaz kimono,
## göğüs altında geniş pembe bel bandı + önde büyük fiyonk, baldır ortasında büzgüyle toplanan pembe balon hakama (büzgüde fırfır), altında siyah tayt,
## dirsekten bileğe siyah kol koruyucu + parmaksız eldiven (kahve bot ayak parçası)
static func _naginata(k) -> void:
	var wh := Color(0.949, 0.941, 0.925)
	var pk := Color(0.784, 0.333, 0.541)
	var bk := Color(0.11, 0.11, 0.125)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# siyah iç giysi + boğaz
	SE.body_layer(k, [P._kp(nk, N + 0.06, 0.008, 0.01), P._kp(nk, N + 0.02, 0.016), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.006), P._kp(wa, H + 0.12, 0.006),
		P._kp(k.M(H + 0.07, 0.3), H + 0.07, 0.004)], 24, 44, func(_i, _j, _p): return bk)
	Z._stand(k, b, 0.045, 0.006, bk)
	M._seat(k, b, pk.darkened(0.2))
	# balon hakama: kalçadan şişer, baldır ortasında büzgü, altta siyah tayt
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.3
		var tk: float = kn + 0.25
		var ad: Callable = Q._baggy(k, le, pk, bk, 0.028, 0.046, tk, sv)
		# büzgü fırfırı: toplanan ağızdan taşan dalgalı kısa kat
		P._lt(k, le, func(s, a): return 0.012 + 0.012 * smoothstep(tk - 0.005, tk + 0.04, float(s)) + 0.007 * sin(float(a) * 9.0 + sv) * smoothstep(tk, tk + 0.04, float(s)),
			func(s, a, ins): return pk.darkened(0.35) if ins else P._fs(pk, 0.007 * sin(float(a) * 9.0 + sv) * smoothstep(tk, tk + 0.04, float(s)), 9.0), tk - 0.008, tk + 0.045, 6, 36, 0.012)
		Q._ring_on(k, le, tk - 0.004, func(_s, _a): return 0.012, 0.0055, pk.darkened(0.12), 0.003)
	# kimono üstü: kısa, hakamanın içine girer
	var hm0: float = H + 0.08
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.014), [hm0, wa.x + 0.01, wa.y + 0.01, wa.z - 0.01]]
	var gfold := func(a: float, y: float, _v: float) -> float:
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(0.2, 0.5, up) + 0.008 * sin(a * 5.0 - y * 16.0) * (1.0 - smoothstep(0.3, 0.6, up))
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hm0, "col": func(_a, _y, _v): return wh, "fold": gfold, "band": wh.darkened(0.02), "band_w": 0.018, "juban": bk,
		"ny": 36, "na": 60, "gain": 4.5, "inner": wh.darkened(0.22)})
	_wrap_stripe(k, wg, N + 0.012, -0.5, hm0, pk, 0.0045, H + 0.2)
	# kollar: siyah iç kol, dirsek üstünde biten geniş kısa kol (ağızda pembe çizgi), dirsekten bileğe kol koruyucu + eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.6
		P._lt(k, ar, func(s, a): return 0.003 + 0.0012 * P._lf(float(s), float(a), sv) - 0.003 * smoothstep(0.96, 0.99, float(s)), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.3, 0.985, 24, 16)
		var gf := func(s: float, a: float) -> float: return 0.0068 + 0.003 * smoothstep(en + 0.06, en + 0.02, s) + 0.0012 * sin(a * 3.0 + s * 40.0 + sv) * smoothstep(en + 0.06, en + 0.12, s)
		P._lt(k, ar, gf, func(s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05 * float(float(s) < en + 0.035)).darkened(0.12 * maxf(0.0, sin(float(a) * 3.0 + float(s) * 40.0 + sv))), en + 0.0, 0.88, 22, 18, 0.015)
		K._glove(k, sd, ar, bk, bk.lightened(0.06))
		var s1: float = en - 0.06
		M._wide(k, ar, func(s: float) -> float: return 0.05 + 0.014 * smoothstep(0.05, 0.4, s), func(s: float) -> float: return 0.006 + 0.01 * smoothstep(0.15, 0.8, s / en),
			func(s: float, a: float) -> float: return 0.026 * sin(a * 3.0 + s * 9.0 + sv) + 0.014 * sin(a * 5.0 + sv), func(s: float, a: float, ins: bool) -> Color:
				if ins:
					return wh.darkened(0.16)
				if s > s1 - 0.075 and s < s1 - 0.05:
					return pk
				return P._fs(wh, 0.01 * sin(a * 3.0 + s * 9.0 + sv), 7.0), s1, 0.1, 0.058, 26, 36)
	# bel bandı: göğüs altından kalçaya geniş pembe kat + önde büyük fiyonk
	var bt: float = H + 0.2
	var bkeys := [P._kp(k.M(bt, k.UA), bt, 0.022), P._kp(wa, H + 0.12, 0.026), P._kp(k.M(H + 0.04, 0.3), H + 0.04, 0.03)]
	var bff := func(a: float, y: float) -> float: return 0.006 * sin(a * 7.0 + y * 30.0) * smoothstep(bt, H + 0.06, y)
	P._cl(k, {"keys": bkeys, "ny": 10, "na": 96, "top": func(_a): return bt, "hem": func(_a): return H + 0.045, "fold": func(a, y, _v): return bff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.006, "inner": pk.darkened(0.3), "skin": tsk})
	var bffv := func(a, y): return bff.call(float(a), float(y))
	P._cord(k, P._ring_pts(bkeys, bt, 0.0, 72), 0.003, pk.darkened(0.08), true, tsk)
	_bow(k, bkeys, bffv, 0.0, bt - 0.05, 0.085, pk.lightened(0.14), tsk, 0.0)


## 賭 (Kake): sol 貝, sağ 者 — birim kare içinde çizgiler (arkadan bakana göre x sağa)
const G_KAKE := [[-0.9, 0.8, -0.9, -0.35], [-0.35, 0.8, -0.35, -0.35], [-0.9, 0.8, -0.35, 0.8], [-0.9, 0.42, -0.35, 0.42], [-0.9, 0.04, -0.35, 0.04], [-0.9, -0.35, -0.35, -0.35],
	[-0.75, -0.45, -0.95, -0.85], [-0.5, -0.45, -0.3, -0.85],
	[0.0, 0.62, 0.7, 0.62], [0.35, 0.95, 0.35, 0.3], [-0.15, 0.3, 0.95, 0.3], [0.85, 0.72, 0.0, -0.1],
	[0.15, -0.05, 0.15, -0.9], [0.8, -0.05, 0.8, -0.9], [0.15, -0.05, 0.8, -0.05], [0.15, -0.47, 0.8, -0.47], [0.15, -0.9, 0.8, -0.9]]


# ------------------------------------------------------------------ Kake Haori (ref Shinobi Striker "Tsunade Outfit"): dize inen önü açık yeşil haori (boyundan etek ucuna geniş siyah yaka bandı, bileğe inen kollar,
## sırtta kırmızı halka içinde 賭), derin V yakalı açık gri kimono üst (önde uyluğa inen kat), göğüs altından bele geniş lacivert obi, baldır ortasında biten lacivert pantolon (siyah sandalet ayak parçası)
static func _kumarbaz(k) -> void:
	var gy := Color(0.847, 0.847, 0.863)
	var nv := Color(0.141, 0.157, 0.29)
	var pn := Color(0.118, 0.165, 0.282)
	var gn := Color(0.18, 0.416, 0.227)
	var bk := Color(0.1, 0.1, 0.11)
	var rd := Color(0.66, 0.12, 0.14)
	var cr := Color(0.93, 0.91, 0.85)
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
	var tsk := func(p): return k.torso_skin(p.y)
	var hem: float = KN - 0.03
	var fam := func(p): return AA._fam(k, p, hem)
	M._inner_v(k, b, gy.darkened(0.1))
	K._seat(k, b, pn.darkened(0.05))
	# pantolon: baldır ortasında biter, altı açık ten
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.3
		var pa: Callable = K._pant(k, le, pn, 0.012, 0.014, s1, 1.2 if sd == "Left" else 2.7)
		R._hem_roll(k, le, pa, s1, pn.darkened(0.06), 0.03, 0.0025)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
	# kimono üstü: derin V, önde uyluğa inen kat (haori ile aynı ağırlık ailesi: dışına taşmaz)
	var khem: float = H - 0.17
	var keys := [P._kp(nk, N + 0.012, 0.026), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.02), [H - 0.04, hp.x + 0.022, hp.y + 0.026, hp.z - 0.024], [khem, hp.x + 0.03, hp.y + 0.034, hp.z - 0.03]]
	var kf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - khem), 0.0, 1.0)
		return 0.005 * sin(a * 6.0 + y * 13.0) * smoothstep(H + 0.2, C, y) + t * 0.008 * sin(a * 5.0 + 0.4)
	M._wrap(k, {"keys": keys, "hem": khem, "col": func(_a, _y, _v): return gy, "fold": kf, "band": gy.darkened(0.08), "band_w": 0.016, "low": -0.35,
		"ny": 44, "na": 60, "gain": 4.5, "inner": gy.darkened(0.25), "skin_fn": fam})
	# obi: göğüs altından bele, katlı, üstünde ince ip
	var ot: float = C - 0.1
	var ob: float = H + 0.04
	var okeys := [P._kp(k.M(ot, k.UA), ot, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(k.M(ob, 0.3), ob, 0.036)]
	var off := func(a: float, y: float) -> float: return 0.004 * sin(a * 5.0 + y * 40.0) + 0.006 * exp(-pow((y - (ot + ob) * 0.5) / 0.012, 2.0))
	P._cl(k, {"keys": okeys, "ny": 14, "na": 96, "top": func(_a): return ot, "hem": func(_a): return ob, "fold": func(a, y, _v): return off.call(float(a), float(y)),
		"col": func(_a, y, _v): return nv.darkened(0.12 * exp(-pow((float(y) - (ot + ob) * 0.5) / 0.006, 2.0))), "gain": 6.0, "th": 0.006, "inner": nv.darkened(0.3), "skin": tsk})
	for y in [ot - 0.002, ob + 0.002]:
		P._cord(k, P._ring_pts(okeys, y, 0.0, 72), 0.0026, nv.lightened(0.06), true, tsk)
	# kollar: altı açık ten (haori kolu bileğe iner)
	for sd in ["Left", "Right"]:
		R._arm_skin(k, P._limb(k, sd, false), 0.15)
	# haori: önü açık, dize iner
	var hk := [P._kp(nk, N + 0.012, 0.04), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.044), P._kp(wa, H + 0.12, 0.06), [H - 0.04, hp.x + 0.07, hp.y + 0.06, hp.z - 0.06],
		[KN + 0.08, hp.x + 0.085, hp.y + 0.07, hp.z - 0.085], [hem, hp.x + 0.092, hp.y + 0.075, hp.z - 0.092]]
	var ef := func(y: float) -> float: return 0.36 + 0.26 * pow(smoothstep(C - 0.06, N + 0.012, y), 1.2)
	var hf := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var fe: float = smoothstep(0.38, 0.75, aw)
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var flat: float = 1.0 - 0.85 * exp(-pow((aw - PI) / 0.5, 2.0)) * (1.0 - smoothstep(H - 0.02, H - 0.1, y))
		return fe * flat * (pow(t, 0.9) * (0.034 * sin(a * 7.0 + 0.6) + 0.014 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y))
	var cg: Dictionary = AA._coat(k, hk, N + 0.012, hem, ef, hf, func(_a, _y): return gn, gn.darkened(0.2), fam, 46, 88, 0.008)
	# siyah yaka bandı: boyundan etek ucuna, kumaşın üstüne içe binen geniş bant
	AA._edge_band(k, cg["ea"], 0.016, 0.004, bk, fam, 1.0)
	AA._edge_band(k, cg["eb"], 0.016, 0.004, bk, fam, -1.0)
	P._bd(k, AA._yl(cg["hem"], 0.008), 0.004, 0.002, gn.darkened(0.12), false, fam)
	# yaka arkası: boynu çeviren siyah bant
	var ck := [[N + 0.06, nk.x + 0.045, nk.y + 0.04, nk.z - 0.05], [N + 0.01, nk.x + 0.05, nk.y + 0.044, nk.z - 0.054], [N - 0.045, ch.x * 0.75, ch.y * 0.8, ch.z * 0.9]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	P._cl(k, {"keys": ck, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.62, TAU - 0.62), "top": func(a): return N + 0.055 - 0.02 * smoothstep(1.4, 0.6, absf(float(a))), "hem": func(_a): return N - 0.04,
		"col": func(_a, _y, _v): return bk, "inner": bk.darkened(0.3), "skin": skt, "th": 0.005})
	# kollar: bileğe inen, hafif genişleyen, astarlı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.4 if sd == "Left" else 2.9
		AA._hang_sleeve(k, ar, gn, gn.darkened(0.25), 0.024, 0.02, 0.012, 0.86, sv)
	# sırtta kırmızı halka içinde 賭
	var cy: float = C - 0.06
	var bmp: Callable = AA._back_mp(hk, 0.0, cy)
	var bsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.01))
	Q._disc(k, bmp, Vector3(0, 0, -1), 0.07, 0.0085, Callable(), func(u, v): return rd if Vector2(float(u), float(v)).length() > 0.75 else cr, bsk, 6, 40)
	for q in G_KAKE:
		P._strap(k, hk, [Vector2(-float(q[0]) * 0.046, cy + float(q[1]) * 0.046), Vector2(-float(q[2]) * 0.046, cy + float(q[3]) * 0.046)], false, 0.0042, 0.0105, 0.0016, bk, 3, bsk)


# ------------------------------------------------------------------ Awa Kimono (ref Shinobi Striker "Utakata Outfit (Bubbled Camellia)"): göğsü açık, bileğe inen açık mavi bol cübbe (boyundan etek ucuna geniş
## koyu mavi yaka bandı, sol kanat sağın üstüne biner, etek ucunda hafif açılır), bileğe inen geniş kollar (ağza yakın turuncu çizgiler), içte lacivert obi,
## önde düğümlü dize sarkan uzun uçlu turuncu kuşak, sırtta üç köpük arması, altta lacivert pantolon (zōri ayak parçası)
const PANT_ADD := 0.012


static func _kopuk(k) -> void:
	var lb := Color(0.478, 0.722, 0.91)
	var db := Color(0.118, 0.227, 0.604)
	var og := Color(0.91, 0.408, 0.118)
	var nv := Color(0.118, 0.165, 0.416)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# açık göğüs (erkek: göğüs kası geometriden) + lacivert pantolon
	R._bare_torso(k, b, H + 0.02, true)
	# lacivert pantolon kalçadan bileğe tam (cübbe açılınca boşluk kalmaz); uylukta dar: cübbe ağırlığı uyluğu izlediği için önden dışarı itilmez
	K._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.4
		var pf := func(s: float, a: float) -> float: return PANT_ADD - 0.004 * (1.0 - smoothstep(kn - 0.25, kn - 0.05, s)) + 0.004 * P._lf(s, a, sv) + 0.0042 * exp(-pow((s - kn) / 0.075, 2.0)) * sin(a * 3.0 + s * 34.0 + sv) - 0.004 * smoothstep(kn + 0.12, kn + 0.3, s)
		P._lt(k, le, pf, func(s, a, ins): return nv.darkened(0.42) if ins else P._fs(nv, float(pf.call(float(s), float(a))) - PANT_ADD, 9.0), 0.0, 1.0, 40, 20)
	# içte lacivert obi (V'nin dibinde görünür)
	var yb: float = H + 0.07
	var okeys := [P._kp(k.M(H + 0.16, k.UA), H + 0.16, 0.018), P._kp(wa, H + 0.12, 0.02), P._kp(k.M(H + 0.02, 0.3), H + 0.02, 0.024)]
	P._cl(k, {"keys": okeys, "ny": 8, "na": 72, "top": func(_a): return H + 0.155, "hem": func(_a): return H + 0.03, "fold": func(a, y, _v): return 0.004 * sin(float(a) * 5.0 + float(y) * 40.0),
		"col": func(_a, _y, _v): return nv, "gain": 6.0, "th": 0.005, "inner": nv.darkened(0.3), "skin": tsk})
	# cübbe: V göğüs, kuşakta sol kanat sağın üstüne biner, dizden sonra bindirme azalır, etek ucunda hafif aralanır
	var hem: float = lerpf(KN, F, 0.8)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.04), P._kp(wa, H + 0.04, 0.042),
		[H - 0.04, hp.x + 0.05, hp.y + 0.065, hp.z - 0.05], [KN + 0.05, hp.x + 0.085, hp.y + 0.1, hp.z - 0.15], [hem, hp.x + 0.12, hp.y + 0.1, hp.z - 0.19]]
	var tt := func(y: float) -> float: return clampf((yb - 0.02 - y) / (yb - 0.02 - hem), 0.0, 1.0)
	var vv := func(y: float) -> float: return smoothstep(yb + 0.01, yb + 0.05, y)
	var au := func(y: float) -> float:
		var e: float = lerpf(0.06, 0.62, pow(smoothstep(yb, N, y), 0.8))
		return lerpf(lerpf(0.4, -0.42, float(tt.call(y))), -e, float(vv.call(y)))
	var ao := func(y: float) -> float:
		var e: float = lerpf(0.06, 0.62, pow(smoothstep(yb, N, y), 0.8))
		return lerpf(lerpf(-0.36, -0.34, float(tt.call(y))), e, float(vv.call(y)))
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.02 - y) / (H + 0.02 - hem), 0.0, 1.0)
		var fe: float = smoothstep(0.1, 0.5, aw)
		var flat: float = 1.0 - 0.85 * exp(-pow((aw - PI) / 0.45, 2.0)) * (1.0 - smoothstep(H - 0.02, H - 0.1, y))
		var blouse: float = 0.014 * exp(-pow((y - (yb + 0.04)) / 0.03, 2.0)) * smoothstep(0.3, 0.9, aw)
		return fe * flat * (pow(t, 0.85) * (0.034 * sin(a * 7.0 + 0.6) + 0.016 * sin(a * 12.0 + 1.9)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 8.0) * smoothstep(N - 0.03, C - 0.05, y)) + blouse
	var csk := func(p): return _usk(k, p, hem)
	var r: Dictionary = AG._robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": au, "ao": ao, "ff": ff, "col": func(_a, _y): return lb, "lin": lb.darkened(0.14), "skin": csk,
		"th": 0.008, "ny": 60, "na": 104, "olift": 0.009, "gain": 5.5})
	# yaka bandı: üst kanadın kenarı boydan boya; alt kanadın kenarı yalnız açık göğüste
	var e_b := []
	var e_a := []
	for j in (r["eb"] as Array).size():
		e_b.append(r["eb"][j])
		var q: Vector3 = r["ea"][j]
		if q.y > yb + 0.03:
			e_a.append(q)
	AA._edge_band(k, e_b, 0.022, 0.0042, db, csk, -1.0)
	AA._edge_band(k, e_a, 0.022, 0.0042, db, csk, 1.0)
	AG._edge(k, AA._yl(r["hem"], 0.009), 0.0055, 0.002, lb.darkened(0.08), csk)
	# kollar: bileğe inen geniş kimono kolu, ağza yakın iki turuncu çizgi
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.2 if sd == "Left" else 2.7
		R._arm_skin(k, ar, 0.25)
		var s1 := 0.87
		var sl: Callable = _kimono_sleeve(k, ar, lb, lb.darkened(0.16), 0.026, 0.04, 0.03, s1, sv)
		for s in [s1 - 0.09, s1 - 0.065]:
			Q._ring_on(k, ar, s, func(s2, a2): return float(sl.call(float(s2), float(a2))) + 0.0015, 0.0045, og, 0.0022)
	# turuncu kuşak: sarılı kalın bant, önde düğüm, dize sarkan iki uç (kumaşa oturur)
	var ff2 := func(a, y): return ff.call(float(a), float(y))
	var bk2: Array = []
	for e in keys:
		bk2.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.012, float(e[3]) - 0.012])
	P._sash(k, bk2, yb, 0.02, 0.004, og, 0.12)
	var kx: Array = P._fp(bk2, -0.02, yb, true, 0.012)
	var ko: Vector3 = kx[1]
	P._boxr(k, (kx[0] as Vector3) + ko * 0.004, Vector3(0.026, -0.004, 0), Vector3(0.004, 0.024, 0), ko * 0.014, og.darkened(0.05), k.torso_skin(yb), 0.4)
	for e2 in [[-0.06, -0.03, 0.42, 0.021], [0.0, 0.05, 0.36, 0.019]]:
		var pts := []
		var ou := []
		for j in 15:
			var t := float(j) / 14.0
			var y: float = yb - 0.02 - float(e2[2]) * t
			var x: float = lerpf(float(e2[0]), float(e2[1]), t)
			var s2: Array = SE.El.key_at(keys, y)
			var a: float = asin(clampf(x / maxf(0.05, float(s2[1])), -0.9, 0.9))
			var q: Array = Q._spt(keys, ff2, a, y, 0.012 + 0.006 * (1.0 - t))
			pts.append(q[0])
			ou.append(q[1])
		Y._ribbon(k, pts, ou, func(t): return float(e2[3]) * lerpf(0.85, 1.0, float(t)), 0.0035, og.darkened(0.04 * float(e2[0] < 0.0)), csk)
	# sırtta üç köpük arması (kabartma halkalar)
	var bmp: Callable = AA._back_mp(keys, 0.0, C - 0.02)
	for e3 in [[-0.018, 0.012, 0.016], [0.016, 0.016, 0.012], [0.0, -0.016, 0.013]]:
		var mp2: Callable = R._off(bmp, float(e3[0]), float(e3[1]))
		Q._disc(k, mp2, Vector3(0, 0, -1), float(e3[2]), 0.007, Callable(), func(u, v): return db if Vector2(float(u), float(v)).length() > 0.72 else lb.lightened(0.18), tsk, 3, 24)


# ------------------------------------------------------------------ Neko Fūdo (ref Shinobi Striker "Wasabi Outfit"): fermuarlı kolsuz açık yeşil kapüşonlu üst (beyaz kürk yaka ve etek ucu, sırta düşmüş kapüşon),
## altında desenli mor bel kuşağı, dizde büzgüyle toplanan haki bol şort (sağ paçada bağ), sağ uylukta beyaz sargı + lacivert kılıf, arkada kahve kuyruk kayışı,
## dizden aşağı file, dirsek altına çıkan gri parmaksız eldiven (kahve diz çizmesi ayak parçası)
static func _kedi(k) -> void:
	var gn := Color(0.541, 0.722, 0.29)
	var fur := Color(0.95, 0.94, 0.89)
	var pu := Color(0.29, 0.227, 0.416)
	var ol := Color(0.478, 0.478, 0.165)
	var gy := Color(0.541, 0.541, 0.565)
	var br := Color(0.48, 0.32, 0.18)
	var nv := Color(0.16, 0.18, 0.36)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var tsk := func(p): return k.torso_skin(p.y)
	# alt gövde ten (üstün ve kuşağın altında kalır) + kalça
	Z._skin_torso(k, b, H + 0.02)
	M._seat(k, b, ol.darkened(0.08))
	# şort: dizde toplanır, altı ten + file
	var ads := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 2.0
		var tk: float = kn + (0.03 if sd == "Left" else -0.01)
		ads[sd] = [le, Z._baggy_net(k, le, ol, 0.02, 0.028, tk, sv, Color(0.2, 0.17, 0.26), Color(0.2, 0.17, 0.26)), tk]
	# sağ paça: büzgünün üstünde sarılı bağ
	var rl: Array = ads["Right"]
	var rle: Dictionary = rl[0]
	var rad: Callable = rl[1]
	Q._ring_on(k, rle, float(rl[2]) - 0.035, func(s, a): return float(rad.call(float(s), float(a))) * 0.6 + 0.004, 0.006, ol.darkened(0.25), 0.0035)
	var tb: Array = Q._ls(rle, float(rl[2]) - 0.035, -PI * 0.5, float(rad.call(float(rl[2]) - 0.035, -PI * 0.5)) * 0.6 + 0.01)
	P._boxr(k, tb[0], Vector3(0, 0, 0.011), Vector3(0, 0.008, 0), (tb[1] as Vector3) * 0.006, ol.darkened(0.25), P._lskin(rle, float(rl[2]) - 0.035), 0.45)
	# sağ uyluk: beyaz sargı + lacivert kılıf (şortun üstüne oturur)
	I._holster(k, rle, func(s, a): return float(rad.call(float(s), float(a))) + 0.002, nv, nv, true)
	# kuyruk kayışı: kuşaktan sağ uyluğun arkasına iner (uyluğa bağlı: savrulmaz)
	var tp := []
	var ts := []
	for j in 13:
		var t := float(j) / 12.0
		var s: float = lerpf(0.04, float(rl[2]) - 0.09, t)
		var e: Array = Q._ls(rle, s, PI + 0.35, float(rad.call(s, PI + 0.35)) + 0.009)
		tp.append(e[0])
		ts.append(s)
	tp[0] = Vector3(-0.03, H - 0.01, (tp[0] as Vector3).z - 0.012)
	P._tb(k, tp, func(s, a): return 0.015 * (1.0 - 0.3 * float(s)) * (1.0 + 0.08 * sin(float(a) * 3.0 + float(s) * 20.0)), func(s, a, _p): return br.darkened(0.12 * float(sin(float(a) * 3.0 + float(s) * 20.0) < -0.3)),
		func(s, _p): return [["Hips", 1.0 - smoothstep(0.0, 0.12, float(s))], ["RightUpperLeg", smoothstep(0.0, 0.12, float(s))]], 10)
	# kuşak: desenli mor bant (açık mor kabartma noktalar)
	var bt: float = H + 0.07
	var bb: float = H - 0.02
	var bkeys := [P._kp(b["wa"], bt, 0.026), P._kp(b["hp"], bb, 0.034)]
	var bsk := func(p): return k.cloth_skin(p, H - 0.1, 0.58)
	P._cl(k, {"keys": bkeys, "ny": 6, "na": 80, "top": func(_a): return bt, "hem": func(_a): return bb, "col": func(_a, _y, _v): return pu, "gain": 5.0, "th": 0.005, "inner": pu.darkened(0.3), "skin": bsk})
	for i in 30:
		var a := TAU * i / 30.0 - PI
		for e2 in [[bt - 0.017, 0.0], [bb + 0.017, 0.5]]:
			var q: Array = P._sa(bkeys, a + float(e2[1]) * TAU / 30.0, float(e2[0]), 0.0)
			P._stud(k, (q[0] as Vector3) + (q[1] as Vector3) * 0.001, q[1], 0.0042, pu.lightened(0.35), bsk.call(q[0]))
	# kolsuz kapüşonlu üst: kuşağın üstünde biter, önde fermuar
	var hem: float = H + 0.085
	var tk: Array = Z._tk(k, b, hem, 0.016, 0.5)
	var tff := func(a: float, y: float) -> float: return 0.006 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.02, hem, y) + 0.0025 * sin(a * 11.0 + y * 20.0)
	var vg: Dictionary = P._cl(k, {"keys": tk, "ny": 26, "na": 100, "top": func(_a): return N + 0.006, "hem": func(_a): return hem, "fold": func(a, y, _v): return tff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return gn, "gain": 6.0, "th": 0.006, "inner": gn.darkened(0.35), "skin": tsk})
	var tffv := func(a, y): return tff.call(float(a), float(y))
	Q._run(k, tk, tffv, [Vector2(0.0, N - 0.01), Vector2(0.0, hem + 0.02)], 0.0045, 0.0025, 0.0016, gn.darkened(0.18), tsk, 20)
	Q._run(k, tk, tffv, [Vector2(0.0, N - 0.01), Vector2(0.0, hem + 0.02)], 0.0017, 0.0042, 0.0012, Color(0.78, 0.8, 0.8), tsk, 20)
	var zp: Array = Q._spt(tk, tffv, 0.0, N - 0.03, 0.007)
	P._boxr(k, zp[0], Vector3(0.0045, 0, 0), Vector3(0, 0.011, 0), (zp[1] as Vector3) * 0.0025, Color(0.78, 0.8, 0.8), tsk.call(zp[0]), 0.3)
	# kürk etek ucu ve kol oyukları
	M._fur(k, AA._yl(vg["hem"], 0.004), 0.011, fur, tsk, 0.7)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		Z._arm_bare(k, ar, 0.0)
		var hp: Array = []
		var l2: Dictionary = ar
		var c0: Vector3 = P._lp(l2, 0.07)
		var d: Vector3 = P._ld(l2, 0.07)
		var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri: Vector3 = (-d).cross(fw).normalized()
		var rr: float = P._lr(l2, 0.07) + 0.008
		for i in 24:
			var a := TAU * i / 24.0
			hp.append(c0 + (ri * sin(a) + fw * cos(a)) * rr)
		M._fur(k, hp, 0.0085, fur, func(_p): return [["UpperChest", 0.55], [sd + "UpperArm", 0.45]], 1.3 if sd == "Left" else 2.1)
		# gri parmaksız eldiven: dirsek altına çıkar, ağzı kıvrık
		var en: float = ar["kn"]
		var g0: float = en + 0.1
		P._lt(k, ar, func(s, a): return 0.004 + 0.003 * smoothstep(g0 + 0.03, g0, float(s)) + 0.0012 * sin(float(a) * 3.0 + float(s) * 40.0) * smoothstep(g0 + 0.05, g0 + 0.1, float(s)),
			func(s, _a, ins): return gy.darkened(0.3) if ins else gy.lightened(0.05 * float(float(s) < g0 + 0.025)), g0, 0.9, 16, 18, 0.015)
		K._glove(k, sd, ar, gy, gy.darkened(0.12))
	# sırta düşmüş kapüşon + kürk yaka
	var hg: Dictionary = Y._hood_down(k, b, tk, gn, 0.32, 0.06, fur.darkened(0.06))
	M._fur(k, AA._yl(hg["top"], -0.002), 0.012, fur, func(p): return Q._nsk(k, p), 1.7, false)


## Örgü bant: kenar boyunca kumaşa oturan kalın bant + üstünde enine kabartma kaburgalar (boya değil)
static func _rib_band(k, pts: Array, outs: Array, side: Array, w: float, col: Color, skinf: Callable, pitch := 0.009) -> void:
	k.strip(pts, outs, w, 0.0035, col, false, skinf)
	var L := 0.0
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg: float = ((pts[i] as Vector3) - (pts[i - 1] as Vector3)).length()
		acc += seg
		L += seg
		if acc < pitch:
			continue
		acc = 0.0
		var p: Vector3 = pts[i]
		var o: Vector3 = outs[i]
		var sd: Vector3 = side[i]
		k.strip([p - sd * w * 0.85 + o * 0.0035, p + sd * w * 0.85 + o * 0.0035], [o, o], 0.0018, 0.0013, col.darkened(0.08), false, skinf)


# ------------------------------------------------------------------ Kōkishin Striker (ref Shinobi Striker "Wonder Striker"): boncuk baskılı mavi tişört, üstünde önü açık uyluğa inen açık gri hırka (kalın örgü ön ve etek bandı,
## bilekte örgü manşetle toplanan bol kollar), baldır ortasında biten siyah pantolon (açık burunlu gri bot ayak parçası)
static func _harika(k) -> void:
	var bl := Color(0.188, 0.706, 0.847)
	var db := Color(0.118, 0.353, 0.706)
	var gy := Color(0.894, 0.894, 0.91)
	var bk := Color(0.094, 0.094, 0.11)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# pantolon: baldır ortasında biter
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.3
		var pa: Callable = K._pant(k, le, bk, 0.012, 0.012, s1, 0.8 if sd == "Left" else 2.2)
		R._hem_roll(k, le, pa, s1, bk.lightened(0.04), 0.028, 0.0022)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
	# tişört: yuvarlak yaka, kalçaya iner
	var th: float = H - 0.1
	var tk := [P._kp(nk, N + 0.012, 0.008, 0.01), [N - 0.05, ch.x * 0.86, ch.y * 0.86, ch.z * 0.94], P._kp(ch, C - 0.03, 0.014), P._kp(wa, H + 0.12, 0.018), [H - 0.04, hp.x + 0.016, hp.y + 0.02, hp.z - 0.02], [th, hp.x + 0.022, hp.y + 0.024, hp.z - 0.024]]
	var tf := func(a: float, y: float) -> float: return 0.006 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.02, th, y) + 0.003 * sin(a * 11.0 + y * 20.0)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 30, "na": 88, "top": func(_a): return N + 0.012, "hem": func(_a): return th, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bl, "gain": 6.0, "th": 0.005, "inner": bl.darkened(0.3), "skin": func(p): return k.cloth_skin(p, th, 0.4)})
	P._cord(k, tg["top"], 0.0042, bl.darkened(0.06), true, func(p): return Q._nsk(k, p))
	P._cord(k, AA._yl(tg["hem"], 0.004), 0.003, bl.darkened(0.08), true, func(p): return k.cloth_skin(p, th, 0.4))
	# boncuk baskısı: göğüste yay çizen oval taneler (lacivert, beyaz, açık mavi) kabartma
	var tfv := func(a, y): return tf.call(float(a), float(y))
	var beads := [[-0.5, 0.0, 0.016, 0.012, Color(0.1, 0.16, 0.36)], [-0.36, 0.008, 0.012, 0.016, Color(0.94, 0.95, 0.96)], [-0.22, 0.012, 0.014, 0.012, Color(0.45, 0.85, 0.92)],
		[-0.08, 0.016, 0.017, 0.017, db], [0.08, 0.016, 0.014, 0.012, Color(0.94, 0.95, 0.96)], [0.22, 0.012, 0.016, 0.012, Color(0.1, 0.16, 0.36)], [0.36, 0.008, 0.012, 0.015, Color(0.45, 0.85, 0.92)],
		[0.5, 0.0, 0.015, 0.012, Color(0.1, 0.16, 0.36)], [-0.29, -0.022, 0.011, 0.009, Color(0.45, 0.85, 0.92)], [0.0, -0.016, 0.013, 0.01, Color(0.94, 0.95, 0.96)], [0.29, -0.022, 0.011, 0.009, db]]
	for e in beads:
		var a: float = float(e[0]) * 1.12
		var y: float = C - 0.07 + float(e[1]) * 1.5
		var mp: Callable = Q._local(tk, tfv, a, y)
		var o2: Vector3 = Q._spt(tk, tfv, a, y)[1]
		var rx: float = float(e[2]) * 1.5
		var ry: float = float(e[3]) * 1.5
		var col: Color = e[4]
		Q._disc(k, mp, o2, rx, 0.0045, func(t): return R._ell(float(t), ry / rx), func(u, v): return col.darkened(0.15) if Vector2(float(u), float(v)).length() > 0.85 else col.lightened(0.06 * float(float(u) < -0.3 and float(v) > 0.2)), tsk, 3, 20)
	# hırka: önü açık, uyluk üstüne iner
	var hem: float = H - 0.17
	var fam := func(p): return AA._fam(k, p, hem)
	var hk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.04), [H - 0.04, hp.x + 0.046, hp.y + 0.042, hp.z - 0.04], [hem, hp.x + 0.06, hp.y + 0.05, hp.z - 0.05]]
	var ef := func(y: float) -> float: return 0.5 + 0.22 * pow(smoothstep(C - 0.02, N + 0.012, y), 1.3)
	var hf := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		return smoothstep(0.5, 0.8, aw) * (0.012 * sin(a * 7.0 + y * 6.0) * (0.4 + t) + 0.004 * sin(a * 13.0 + 1.9))
	var cg: Dictionary = AA._coat(k, hk, N + 0.012, hem, ef, hf, func(_a, _y): return gy, gy.darkened(0.12), fam, 44, 96, 0.009)
	# örgü bantlar: ön kenar boyunca + etek ucunda
	for e in [[cg["ea"], 1.0], [cg["eb"], -1.0]]:
		var ed: Array = e[0]
		var sg: float = e[1]
		var pts := []
		var ou := []
		var sdv := []
		for p: Vector3 in ed:
			var o := Vector3(p.x, 0.0, p.z).normalized()
			var tg2 := Vector3(o.z, 0.0, -o.x) * sg
			pts.append(p + tg2 * 0.016 + o * 0.0015)
			ou.append(o)
			sdv.append(tg2)
		_rib_band(k, pts, ou, sdv, 0.016, gy.darkened(0.03), fam, 0.008)
	var hm := []
	var ho := []
	var hs := []
	for p: Vector3 in cg["hem"]:
		var o := Vector3(p.x, 0.0, p.z).normalized()
		hm.append(p + Vector3(0, 0.017, 0) + o * 0.0015)
		ho.append(o)
		hs.append(Vector3.UP)
	_rib_band(k, hm, ho, hs, 0.017, gy.darkened(0.03), fam, 0.008)
	# yaka arkası: boynu çeviren örgü bant
	var ck := [[N + 0.035, nk.x + 0.036, nk.y + 0.03, nk.z - 0.04], [N - 0.01, nk.x + 0.046, nk.y + 0.036, nk.z - 0.05], [N - 0.05, ch.x * 0.76, ch.y * 0.82, ch.z * 0.92]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	P._cl(k, {"keys": ck, "ny": 8, "na": 64, "rng": func(_v): return Vector2(0.72, TAU - 0.72), "top": func(_a): return N + 0.03, "hem": func(_a): return N - 0.045,
		"fold": func(a, _y, _v): return 0.012 * (0.5 + 0.5 * cos(float(a) * 40.0)), "col": func(a, _y, _v): return gy.darkened(0.03 + 0.06 * (0.5 - 0.5 * cos(float(a) * 40.0))), "inner": gy.darkened(0.2), "skin": skt, "th": 0.005})
	# kollar: bol, bilekte örgü manşetle toplanır
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.4
		var s1 := 0.84
		var sf := func(s: float, a: float) -> float:
			var puff: float = 0.016 * sin(clampf((s - 0.05) / (s1 - 0.08), 0.0, 1.0) * PI * 0.9 + 0.2)
			var g: float = smoothstep(s1 - 0.08, s1 - 0.01, s)
			return lerpf(0.012 + puff + 0.004 * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.005 * sin(a * 7.0 + sv) * smoothstep(s1 - 0.2, s1 - 0.08, s), 0.006, g)
		P._lt(k, ar, sf, func(s, a, ins): return gy.darkened(0.3) if ins else P._fs(gy, float(sf.call(float(s), float(a))) - 0.02, 10.0), 0.0, s1, 34, 24, 0.02)
		P._lt(k, ar, func(s, a): return 0.0085 + 0.0025 * (0.5 + 0.5 * cos(float(a) * 14.0)), func(_s, a, ins): return gy.darkened(0.3) if ins else gy.darkened(0.03 + 0.07 * (0.5 - 0.5 * cos(float(a) * 14.0))), s1 - 0.012, 0.93, 8, 42, 0.02)


## Geniş kimono kolu (parti aa'nın sarkan kolu gibi) + omuz kökünde incelme: kol kökü omuzdan sivri çıkmaz
static func _kimono_sleeve(k, ar: Dictionary, col: Color, lin: Color, base: float, wide: float, sag: float, s1: float, sv: float) -> Callable:
	var en: float = ar["kn"]
	var adn: float = J._outer_a(ar, 0.75, Vector3.DOWN)
	var slc := func(s: float, a: float) -> float:
		var t: float = smoothstep(0.04, s1, s)
		return (0.003 + 0.006 * t) * P._lf(s, a, sv) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
	var sl := func(s: float, a: float) -> float:
		var t: float = smoothstep(0.04, s1, s)
		var dn: float = exp(-pow(wrapf(a - adn, -PI, PI) / 0.95, 2.0))
		var root: float = (1.0 - smoothstep(0.0, 0.18, s))
		return (base + wide * t + sag * t * t * dn) * (1.0 - 0.75 * root) - P._lr(ar, s) * 0.35 * root + float(slc.call(s, a))
	P._lt(k, ar, sl, func(s, a, ins): return lin if ins else P._fs(col, float(slc.call(float(s), float(a))), 12.0), 0.0, s1, 34, 26, 0.05)
	K._lt_in(k, ar, func(s, a): return float(sl.call(float(s), float(a))) - 0.006, lin, s1 - 0.3, s1, 10, 26)
	return sl


## Bileğe inen önü bindirmeli cübbe ağırlığı (parti ag'nin _rsk yöntemi): ön ortada geniş geçiş (iki bacak arasında yırtılmaz);
## arkada diz hizasından itibaren baldırı daha çok izler (geri kalkan baldır arka eteği delmez), uçta biraz bırakır (astar kalkmaz)
static func _usk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.05), 0.5)
	var wb: float = lerpf(0.86 * pow(minf(1.0, (H - p.y) / 0.32), 0.7), 0.95, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.92, smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(0.055, 0.1, bk)
	var s: float = smoothstep(-hw, hw, x)
	var bs: float = smoothstep(0.09, -0.03, z)   # yan-arka da baldırı izler: geri kalkan baldır yandan çıkmaz
	# arka yarı diz hizasında kalçadan tamamen kopar (dört kemik sınırı: iki uyluk + iki baldır), sonra iki baldırı kendi payıyla izler;
	# arka ortada da baldır izlenir (geri kalkan baldır arka orta kumaşı delmez, kumaş yarılmaz)
	w = lerpf(w, 1.0, smoothstep(k.K + 0.22, k.K + 0.08, p.y) * smoothstep(0.2, 0.5, bs))
	var kb0: float = smoothstep(lerpf(k.K - 0.06, k.K + 0.07, bs), lerpf(k.K - 0.24, k.K - 0.02, bs), p.y) * lerpf(0.55, 1.0, bs) * lerpf(1.0, 0.85, smoothstep(0.85, 1.0, t))
	if bs >= 0.5:
		return [["LeftUpperLeg", s * (1.0 - kb0)], ["LeftLowerLeg", s * kb0], ["RightUpperLeg", (1.0 - s) * (1.0 - kb0)], ["RightLowerLeg", (1.0 - s) * kb0]] if p.y < k.K + 0.08 else [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
	var kb: float = kb0 * smoothstep(0.0, 0.6, absf(2.0 * s - 1.0))
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
