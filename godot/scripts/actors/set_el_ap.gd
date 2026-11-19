extends RefCounted
## Elle modellenmiş setler, parti ap: ss_gezgin_palto, ss_yelpaze_cocuk, ss_yelpaze_yirtik, ss_yelpaze_genc, ss_mevsim, ss_golge_genc. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), i (I), j (J), r (R), s (S), x (X), z (Z), aa (AA), ag (AG), aj (AJ) dosyalarından; burada yalnız bu setlere özgü parçalar.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const AJ = preload("res://scripts/actors/set_el_aj.gd")

const DONE := ["ss_gezgin_palto", "ss_yelpaze_cocuk", "ss_yelpaze_yirtik", "ss_yelpaze_genc", "ss_mevsim", "ss_golge_genc"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_gezgin_palto": _gezgin(k)
		"ss_yelpaze_cocuk": _cocuk(k)
		"ss_yelpaze_yirtik": _yirtik(k)
		"ss_yelpaze_genc": _genc(k)
		"ss_mevsim": _mevsim(k)
		"ss_golge_genc": _golge(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Sırtta Uchiha yelpazesi (kabartma): koyu kenar, kırmızı üst, beyaz alt, altta beyaz sap
static func _uchiwa(k, keys: Array, cy: float, r: float, rim: Color, skinf: Callable) -> void:
	var wh := Color(0.94, 0.92, 0.88)
	P._strap(k, keys, [Vector2(0.0, cy - r * 0.9), Vector2(0.0, cy - r * 1.55)], false, r * 0.15, 0.0045, 0.0016, rim, 4, skinf)
	P._strap(k, keys, [Vector2(0.0, cy - r * 0.95), Vector2(0.0, cy - r * 1.5)], false, r * 0.1, 0.0062, 0.0016, wh, 4, skinf)
	I._fan_on(k, keys, 0.0, cy, false, r * 1.1, func(th): return I._crest_r(float(th)), func(_u, _v): return rim, 0.0045, 6, 44, skinf)
	I._fan_on(k, keys, 0.0, cy, false, r, func(th): return I._crest_r(float(th)), func(_u, v): return Color(0.76, 0.12, 0.13) if float(v) > 0.0 else wh, 0.0068, 8, 52, skinf)


## Yüzey yerel eşlemesi üstünde kısa paralel çizik demeti (yıpranmış kumaşın sökük iplikleri, kabartma)
static func _scratch(k, mp: Callable, n: int, ln: float, rot: float, gap: float, col: Color, skinf: Callable) -> void:
	var d := Vector2(cos(rot), sin(rot))
	var nn := Vector2(-d.y, d.x)
	for i in n:
		var c: Vector2 = nn * gap * (float(i) - (n - 1) * 0.5)
		var l2: float = ln * (0.7 + 0.3 * sin(float(i) * 2.3 + rot))
		var pts := []
		for t in 4:
			pts.append(c + d * lerpf(-l2 * 0.5, l2 * 0.5, float(t) / 3.0))
		R._lstrip(k, mp, pts, 0.0012, 0.0022, 0.0008, col, skinf)


## Üç toplu dango şişi (kabartma): çubuk + pembe / beyaz / yeşil toplar
static func _dango(k, mp: Callable, rot: float, r: float, skinf: Callable) -> void:
	var m2: Callable = R._rot(mp, rot)
	var o: Vector3 = R._out_of(m2)
	R._lstrip(k, m2, [Vector2(-3.3 * r, 0.0), Vector2(0.0, 0.0), Vector2(3.5 * r, 0.0)], r * 0.17, 0.0028, 0.0012, Color(0.78, 0.6, 0.38), skinf)
	var cols := [Color(0.62, 0.82, 0.35), Color(0.98, 0.97, 0.95), Color(0.97, 0.66, 0.74)]
	for i in 3:
		var c: Color = cols[i]
		Q._disc(k, R._off(m2, (float(i) - 1.0) * 2.05 * r, 0.0), o, r, 0.0042, Callable(), func(u, v): return c.lightened(0.18) if float(u) < -0.2 and float(v) > 0.25 else (c.darkened(0.12) if Vector2(float(u), float(v)).length() > 0.86 else c), skinf, 3, 14)


## Uzvun dış yüzüne oturan metal plaka + üstünde kabartma Konoha girdabı
static func _leaf_plate(k, ar: Dictionary, s: float, ad: Callable, col: Color) -> void:
	var sg: float = ar["sg"]
	var a0: float = J._outer_a(ar, s, Vector3(sg, 0.0, 0.35))
	var e: Array = Q._ls(ar, s, a0, float(ad.call(s, a0)) + 0.009)
	var c0: Vector3 = e[0]
	var o: Vector3 = e[1]
	var dv: Vector3 = P._ld(ar, s)
	var tx: Vector3 = dv.cross(o).normalized()
	var bo: Array = P._lskin(ar, s)
	P._boxr(k, c0, tx * 0.021, dv * 0.0165, o * 0.0035, col, bo, 0.3)
	var mp := func(u: float, v: float, l: float) -> Vector3: return c0 + tx * u - dv * v + o * (0.0034 + l)
	var sp := []
	for i in 26:
		var t := float(i) / 25.0
		var th := t * TAU * 1.9 + 0.5
		var rr: float = lerpf(0.0018, 0.0105, t)
		sp.append(Vector2(cos(th) * rr, sin(th) * rr))
	sp.append(Vector2(0.0155, -0.006))
	R._lstrip(k, mp, sp, 0.0011, 0.0009, 0.0008, col.darkened(0.35), func(_p): return bo)


# ------------------------------------------------------------------ Rurō Gaitō (ref Shinobi Striker "Sasuke Outfit Back in Time Ver."): dize inen koyu gri palto (alçak dik yaka, önü belin altına kadar kapalı,
## kemerin altından etek ucuna açılır), sağ omuzdan sol kalçaya inen mor kılıç kayışı + belde mor kemer ve sol kalçada kılıf tokası, siyah tam eldiven, düz koyu gri pantolon
static func _gezgin(k) -> void:
	var co := Color(0.3, 0.295, 0.33)
	var lin := Color(0.19, 0.185, 0.21)
	var pn := Color(0.24, 0.235, 0.265)
	var ink := Color(0.12, 0.12, 0.135)
	var st := Color(0.29, 0.227, 0.408)
	var gl := Color(0.09, 0.09, 0.1)
	var mt := Color(0.55, 0.55, 0.6)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return ink, 0.006)
	K._seat(k, b, pn)
	I._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, pn, 0.016, 0.012, 1.0, 1.4 if sd == "Left" else 2.5)
	# palto: dize iner; belin altına kadar sol kanat sağın üstüne biner, altında önü açılır
	var hem: float = KN + 0.075
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.036), P._kp(hp, H - 0.04, 0.044),
		[KN + 0.14, hp.x + 0.05, hp.y + 0.055, hp.z - 0.065], [hem, hp.x + 0.062, hp.y + 0.062, hp.z - 0.075]]
	var y0: float = H + 0.03
	var gt := func(y: float) -> float: return smoothstep(y0 + 0.03, y0 - 0.05, y)
	var ev := func(y: float) -> float: return 0.085 * pow(clampf((y0 - y) / (y0 - hem), 0.0, 1.0), 0.75)
	var au := func(y: float) -> float: return lerpf(0.075, -0.02, float(gt.call(y))) - float(ev.call(y))
	var ao := func(y: float) -> float: return lerpf(-0.075, 0.02, float(gt.call(y))) + float(ev.call(y))
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fe: float = smoothstep(0.08, 0.4, aw)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var lo: float = pow(t, 0.9) * ((0.024 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.011 * sin(a * 13.0 + 1.9))
		var up: float = (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
		return fe * (lo + up)
	var csk := func(p): return AA._fam(k, p, hem)
	var r: Dictionary = AG._robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": au, "ao": ao, "ff": ff, "col": func(_a, _y): return co, "lin": lin, "skin": csk,
		"th": 0.008, "ny": 54, "na": 100, "olift": 0.008, "gain": 5.0})
	AG._edge(k, AA._yl(r["hem"], 0.01), 0.0065, 0.0022, co.lightened(0.04), csk)
	var ea := []
	var eb := []
	for j in r["ea"].size():
		var q: Vector3 = r["ea"][j]
		if q.y < y0 - 0.03:
			ea.append(q)
			eb.append(r["eb"][j])
	AG._edge(k, ea, 0.005, 0.0022, co.lightened(0.03), csk, -0.004)
	AG._edge(k, eb, 0.005, 0.0022, co.lightened(0.03), csk, 0.004)
	# gizli pat: üst kanadın kenarı boyunca dikiş
	Q._run(k, keys, ff, [Vector2(-0.062, N - 0.02), Vector2(-0.062, y0 + 0.02)], 0.0025, 0.0095, 0.0012, co.darkened(0.16), csk, 14)
	for sg in [1.0, -1.0]:   # yan dikişler + bel kıskacı
		Q._run(k, keys, ff, [Vector2(sg * 1.62, C - 0.05), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.02)], 0.0022, 0.0015, 0.0011, co.darkened(0.15), csk, 12)
		Q._run(k, keys, ff, [Vector2(sg * 0.62, C - 0.02), Vector2(sg * 0.66, H + 0.12), Vector2(sg * 0.7, y0 - 0.04)], 0.002, 0.0015, 0.001, co.darkened(0.1), csk, 10)
	# alçak dik yaka
	var cg: Dictionary = AJ._stand(k, nk, 0.06, 0.035, co, lin, 0.032, 0.004)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.0026, co.lightened(0.04), false, func(p): return Q._nsk(k, p))
	# kollar: bileğe dar, siyah tam eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sv: float = 0.7 if sd == "Left" else 2.0
		AJ._sleeve(k, ar, co, 0.925, sv, 0.019, 0.007, lin)
		I._cap(k, ar, co, 0.019)
		P._lt(k, ar, func(s, _a): return 0.0085 + 0.003 * smoothstep(0.9, 0.86, float(s)), func(_s, _a, ins): return gl.darkened(0.3) if ins else gl, 0.84, 0.985, 8, 18)
		Z._glove_full(k, sd, gl)
	# kılıç kayışı: sağ omuzdan sol kalçaya, sırtta da iner; belde kemer, sol kalçada kılıf tokası
	var bsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.005))
	P._over(k, keys, -0.085, N - 0.065, N - 0.065, 0.012, 0.009, 0.003, st)
	P._strap(k, keys, [Vector2(-0.085, N - 0.065), Vector2(-0.02, C - 0.03), Vector2(0.075, C - 0.13), Vector2(0.13, H + 0.06)], true, 0.012, 0.0105, 0.003, st, 8, bsk)
	P._strap(k, keys, [Vector2(-0.085, N - 0.065), Vector2(0.0, C - 0.06), Vector2(0.13, H + 0.06)], false, 0.012, 0.009, 0.003, st, 8, bsk)
	var by: float = H + 0.085
	P._sash(k, keys, by, 0.011, 0.01, st, 0.08)
	var bx: Array = P._fp(keys, -0.075, by, true, 0.022)
	P._boxr(k, bx[0], Vector3(0.012, 0, 0), Vector3(0, 0.013, 0), (bx[1] as Vector3) * 0.003, mt, k.torso_skin(by), 0.3)
	P._boxr(k, (bx[0] as Vector3) + (bx[1] as Vector3) * 0.003, Vector3(0.006, 0, 0), Vector3(0, 0.008, 0), (bx[1] as Vector3) * 0.0015, st.darkened(0.2), k.torso_skin(by), 0.3)
	var hx: Array = P._fp(keys, 0.14, H + 0.05, true, 0.024)
	var ho: Vector3 = hx[1]
	var hup: Vector3 = Vector3(-0.35, 1.0, 0.0).normalized()
	var hri: Vector3 = hup.cross(ho).normalized()
	P._boxr(k, hx[0], hri * 0.017, hup * 0.034, ho * 0.011, st.darkened(0.12), k.torso_skin(H + 0.05), 0.3)
	P._boxr(k, (hx[0] as Vector3) + ho * 0.011 + hup * 0.012, hri * 0.012, hup * 0.007, ho * 0.003, mt, k.torso_skin(H + 0.05), 0.3)
	P._boxr(k, (hx[0] as Vector3) + ho * 0.011 - hup * 0.016, hri * 0.012, hup * 0.006, ho * 0.003, mt, k.torso_skin(H + 0.05), 0.3)


# ------------------------------------------------------------------ Uchiha Osanai (ref Shinobi Striker "Sasuke Outfit Childhood Ver."): boğazı saran yüksek mor yaka, kısa kollu mor üst, fermuarlı gri yelek
## (alt kenarı kalın rulo, omuz yastıkları), sağ omuzdan göğse inip düğümlenen beyaz kol askısı, dirsek altından ele mor kolluk, toplanan bol mor pantolon + bilekte beyaz sargı, kalçada kahve çanta
static func _cocuk(k) -> void:
	var pu := Color(0.227, 0.165, 0.353)
	var gy := Color(0.541, 0.541, 0.565)
	var wh := Color(0.91, 0.91, 0.894)
	var br := Color(0.45, 0.31, 0.19)
	var mt := Color(0.74, 0.74, 0.76)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return pu.lightened(0.04) if j < 4 else pu, 0.006, H - 0.06)
	K._seat(k, b, pu)
	I._seat(k, b, pu)
	X._neck(k, b, pu, 0.088, false, 0.0035)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		R._arm_skin(k, ar, kn * 0.45)
		I._sleeve(k, ar, pu, 0.015, kn * 0.62, sv, 0.0, 0.008)
		I._cuff(k, ar, kn * 0.62 - 0.03, kn * 0.62, 0.02, pu.darkened(0.12))
		# kolluk: dirsek altından ele; üst ağzı hafif bol, bilekte kırışık
		var gf := func(s: float, a: float) -> float:
			return 0.0075 + 0.0035 * smoothstep(kn + 0.12, kn + 0.05, s) + 0.0022 * sin(a * 3.0 + s * 34.0 + sv) * smoothstep(0.7, 0.85, s)
		P._lt(k, ar, gf, func(s, a, ins): return pu.darkened(0.35) if ins else P._fs(pu, 0.0022 * sin(float(a) * 3.0 + float(s) * 34.0 + sv), 25.0), kn + 0.045, 0.93, 22, 18, 0.02)
		P._lt(k, ar, func(s, a): return float(gf.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return pu.darkened(0.35) if ins else pu.lightened(0.06), kn + 0.045, kn + 0.075, 3, 18)
		AG._glove(k, sd, ar, pu)
		I._pant(k, le, pu, 0.016, 0.022, 0.83, 0.016, sv)
		I._shin(k, le, 0.81, 6, wh)
	# yelek: göğüs üstünden bele, kalın rulo etek, önü fermuarlı
	var hem: float = H + 0.035
	var vk := [P._kp(nk, N - 0.0, 0.034), [N - 0.055, ch.x * 0.94, ch.y * 0.97 + 0.014, ch.z * 1.04 - 0.014], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.032), P._kp(wa, hem, 0.038)]
	var vf := func(a: float, y: float, _v: float) -> float:
		var aa: float = absf(a)
		return smoothstep(0.08, 0.3, aa) * (0.006 * sin(a * 5.0 + y * 9.0) + 0.004 * sin(a * 11.0 + 0.6)) - 0.01 * exp(-pow((aa - 1.7) / 0.05, 2.0))
	var vtop := func(a: float) -> float: return N - 0.04 + 0.03 * smoothstep(0.35, 1.25, absf(a)) - 0.005 * smoothstep(2.0, 2.8, absf(a))
	var tsk := func(p): return k.torso_skin(p.y)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 34, "na": 88, "top": func(a): return vtop.call(float(a)), "hem": func(_a): return hem, "fold": vf,
		"col": func(_a, _y, _v): return gy, "gain": 7.0, "th": 0.007, "inner": gy.darkened(0.35), "skin": tsk})
	P._cord(k, vg["top"], 0.0045, gy.lightened(0.04), true, tsk)
	var vff := func(a, y): return vf.call(float(a), float(y), 0.0)
	AJ._zip(k, vk, vff, N - 0.045, hem + 0.012, gy.darkened(0.12), mt, tsk)
	var rp: Array = I._ring_pts(vk, hem + 0.012, 0.012, 88)
	P._tb(k, rp, func(_s, a): return 0.024 * (0.86 + 0.14 * absf(cos(float(a)))), func(s, a, _p):
		var c0: Color = gy.darkened(0.04 if cos(float(a)) > -0.3 else 0.2)
		return c0.darkened(0.1 * float(sin(float(s) * TAU * 12.0) > 0.92)), func(_s, p): return k.torso_skin(p.y), 12, true)
	for sg in [1.0, -1.0]:
		I._pad(k, vk, sg * ch.x * 0.7, N - 0.09, N - 0.09, 0.044, 0.014, 0.008, gy.lightened(0.03))
		Q._run(k, vk, vff, [Vector2(sg * 1.57, C - 0.02), Vector2(sg * 1.57, hem + 0.03)], 0.0022, 0.0015, 0.0011, gy.darkened(0.16), tsk, 8)
		Q._run(k, vk, vff, [Vector2(sg * 0.5, C + 0.02), Vector2(sg * 0.42, C - 0.08), Vector2(sg * 0.45, hem + 0.03)], 0.002, 0.0015, 0.001, gy.darkened(0.12), tsk, 10)
	# beyaz kol askısı: sağ omzun üstünden göğse iner, ortada düğüm; sol koltuk altına gider, sırttan omza döner
	P._over(k, vk, -0.07, N - 0.07, N - 0.07, 0.019, 0.011, 0.004, wh)
	P._strap(k, vk, [Vector2(-0.07, N - 0.07), Vector2(-0.035, C - 0.0), Vector2(0.0, C - 0.04)], true, 0.019, 0.012, 0.004, wh, 8, tsk)
	P._strap(k, vk, [Vector2(0.0, C - 0.04), Vector2(0.07, C - 0.03), Vector2(0.135, C - 0.01)], true, 0.016, 0.012, 0.004, wh.darkened(0.04), 8, tsk)
	P._strap(k, vk, [Vector2(-0.07, N - 0.07), Vector2(0.03, C - 0.02), Vector2(0.135, C - 0.01)], false, 0.017, 0.011, 0.004, wh.darkened(0.03), 10, tsk)
	var kc: Array = P._fp(vk, 0.005, C - 0.042, true, 0.022)
	var kd: Vector3 = kc[1]
	var kx: Vector3 = Vector3.UP.cross(kd).normalized()
	P._tb(k, [(kc[0] as Vector3) - kx * 0.02 + Vector3(0, 0.006, 0), kc[0], (kc[0] as Vector3) + kx * 0.02 - Vector3(0, 0.006, 0)], func(s, a): return 0.013 * (0.55 + 0.45 * sin(clampf(float(s), 0.0, 1.0) * PI)) * (1.0 + 0.12 * sin(float(a) * 3.0)),
		func(_s, a, _p): return wh.darkened(0.14) if sin(float(a) * 3.0) < -0.3 else wh, func(_s, p): return k.torso_skin(p.y), 12)
	for e3 in [[0.05, 0.08, 0.014, 0.0], [0.075, 0.06, 0.012, 0.02]]:   # düğümün iki ucu: yeleğin üstüne yatar
		P._strap(k, vk, [Vector2(0.012, C - 0.052), Vector2(float(e3[0]) * 0.6 + float(e3[3]) * 0.5, C - 0.052 - float(e3[1]) * 0.55), Vector2(float(e3[0]), C - 0.05 - float(e3[1]))], true, float(e3[2]), 0.012, 0.004, wh.darkened(0.06), 6, tsk)
	# kalçada kahve alet çantası
	X._bag(k, R._seat_keys(k, b), H - 0.035, 0.028, br)


# ------------------------------------------------------------------ Uchiha Saigo (ref Shinobi Striker "Sasuke Outfit Last Battle Ver."): göğse kadar açık fermuarlı mavimsi gri kısa kollu gömlek
## (içi mor yüksek açık yaka, eteği ve kol ağızları dişli yırtık, yanlarda morun göründüğü yırtıklar, sökük iplik izleri), toplanan lacivert bol pantolon + siyah baldır sargısı,
## sağ bilekte beyaz çizgili gri bant, solda siyah bant
static func _yirtik(k) -> void:
	var sh := Color(0.604, 0.604, 0.722)
	var pu := Color(0.34, 0.27, 0.56)
	var nv := Color(0.118, 0.165, 0.282)
	var bk := Color(0.1, 0.1, 0.12)
	var gb := Color(0.5, 0.5, 0.54)
	var wh := Color(0.92, 0.92, 0.92)
	var dt := Color(0.36, 0.36, 0.5)
	var mt := Color(0.3, 0.3, 0.36)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	# V yakada ten, altta koyu mor astar (yırtıklardan görünür)
	P._inner(k, b, func(_i, _j, p): return skc if float(p.y) > C - 0.06 else pu.darkened(0.3), 0.004, H - 0.06)
	K._seat(k, b, nv)
	I._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.7
		var tk: float = kn + 0.13
		Q._baggy(k, le, nv, bk, 0.018, 0.034, tk, sv)
		P._wraps(k, le, tk - 0.02, 0.975, 11, 0.009, 0.0135, bk.lightened(0.06), 0.008)
	# gömlek: önü göğüs ortasına kadar açık, aşağısı fermuarlı; etek ucu dişli yırtık, delikli
	var hem: float = H - 0.045
	var top: float = N + 0.012
	var yz: float = C - 0.025
	var jk: Array = AJ._jkeys(k, b, top, hem - 0.035, 0.034, 0.05)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.3, 0.7, aw) * (t * (0.016 * sin(a * 6.0 + 0.4) + 0.008 * sin(a * 11.0 + 1.3)) + (1.0 - t) * 0.006 * sin(a * 4.0 + y * 14.0))
	var hemf := func(a: float) -> float:
		var tor: float = 0.6 + 0.4 * sin(a * 2.0 + 0.7)
		return hem + 0.008 * sin(a * 3.0) - (0.014 + 0.022 * tor) * maxf(0.0, Q._tri(a * 10.0 + 1.3)) * (0.55 + 0.45 * sin(a * 5.0 + 2.0))
	var holes := [[1.52, C - 0.11, 0.1, 0.075, 1.0], [-1.52, C - 0.1, 0.1, 0.07, 2.0], [0.62, C - 0.13, 0.1, 0.022, 0.4], [PI - 0.45, H + 0.06, 0.14, 0.03, 1.7], [-0.75, H + 0.01, 0.09, 0.02, 2.6]]
	var holef := func(a: float, y: float) -> bool:
		for hh in holes:
			var da: float = wrapf(a - float(hh[0]), -PI, PI) / float(hh[2])
			var dy: float = (y - float(hh[1])) / float(hh[3])
			if da * da + dy * dy < pow(S._jag(atan2(dy, da), float(hh[4])), 2.0):
				return true
		return false
	var jsk: Callable = AJ._jsk(k, hem - 0.03)
	var vz: float = (top - yz) / (top - hem)
	var jrg := func(v) -> Vector2:
		var e: float = maxf(lerpf(0.4, 0.0, smoothstep(0.02, vz, float(v))), 0.07 * smoothstep(0.86, 1.0, float(v)))
		return Vector2(e, TAU - e)
	var jg: Dictionary = S._clh(k, {"keys": jk, "ny": 36, "na": 96, "rng": jrg, "top": func(_a): return top, "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return sh, "gain": 6.0, "th": 0.006, "inner": pu.darkened(0.15), "skin": jsk}, holef)
	var jff := func(a, y): return jf.call(float(a), float(y))
	for hh in holes:
		var sdv: float = hh[4]
		S._hole_rim(k, jk, jff, hh[0], hh[1], hh[2], hh[3], func(t): return S._jag(float(t), sdv), sh.darkened(0.2), jsk)
	for ed in [jg["ea"], jg["eb"]]:
		P._bd(k, ed, 0.0038, 0.0024, mt, false, jsk, 0.0)
	AJ._zip(k, jk, jff, yz, hem + 0.025, sh.darkened(0.12), Color(0.72, 0.72, 0.76), jsk)
	P._cord(k, jg["hem"], 0.0024, sh.darkened(0.14), false, jsk)
	# sökük iplik izleri: gövdede çizik demetleri (kabartma)
	for e3 in [[0.75, C - 0.03, 4, -0.5], [-0.55, C - 0.16, 5, 0.6], [0.35, H + 0.04, 6, -0.3], [-0.95, H + 0.06, 4, 0.4], [PI - 0.6, C - 0.05, 5, 0.5], [-(PI - 0.9), H + 0.1, 4, -0.6], [1.0, H + 0.0, 5, 0.2]]:
		var mp: Callable = Q._local(jk, jff, float(e3[0]), float(e3[1]))
		_scratch(k, mp, int(e3[2]), 0.026, float(e3[3]), 0.006, dt, jsk)
	# yüksek açık yaka: dışı ve içi mor
	var cg: Dictionary = AJ._stand(k, nk, 0.105, 0.4, pu.lightened(0.05), pu.darkened(0.12), 0.036, 0.026)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.003, pu.lightened(0.1), false, func(p): return Q._nsk(k, p))
	# kollar: dirsek üstünde yırtık kısa kol, altı çıplak; bilek bantları
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.6 if sd == "Left" else 1.8
		I._cap(k, ar, sh, 0.017)
		R._arm_skin(k, ar, en * 0.55)
		var sf := func(s: float, a: float) -> float:
			return 0.017 + 0.009 * smoothstep(0.08, 0.5, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI)
		S._lte(k, ar, sf, func(s, a, ins): return pu.darkened(0.1) if ins else P._fs(sh, float(sf.call(float(s), float(a))) - 0.017 - 0.009 * smoothstep(0.08, 0.5, float(s)), 14.0), 0.0,
			func(a): return en * 0.84 - 0.04 * maxf(0.0, Q._tri(float(a) * 5.0 + sv)) - 0.012 * sin(float(a) * 9.0 + sv), 30, 24)
		if sd == "Right":
			I._cuff(k, ar, 0.8, 0.95, 0.0095, gb)
			for ss in [0.81, 0.824, 0.926, 0.94]:
				Q._ring_on(k, ar, ss, func(_s, _a): return 0.0098, 0.0028, wh, 0.0012)
		else:
			I._cuff(k, ar, 0.79, 0.95, 0.0095, bk)


# ------------------------------------------------------------------ Uchiha Kodomo (ref Shinobi Striker "Sasuke Outfit Young Vers."): çeneye çıkan yüksek dik yakalı (içi açık leylak) kısa kollu lacivert gömlek,
## sırtta Uchiha yelpazesi, beyaz diz üstü şort, sağ uylukta beyaz sargı + siyah kılıf, ön kolda iki ucu lacivert bantlı beyaz kolluk, dizin altından bileğe lacivert bantlı beyaz baldır sargısı
static func _genc(k) -> void:
	var nv := Color(0.118, 0.165, 0.416)
	var wh := Color(0.91, 0.894, 0.855)
	var aw := Color(0.949, 0.941, 0.918)
	var lv := Color(0.82, 0.82, 0.94)
	var bk := Color(0.11, 0.11, 0.125)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return nv.darkened(0.2), 0.006, H - 0.04)
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return wh)
	I._seat(k, b, wh)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.2
		var s1: float = kn - 0.035
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		var ad: Callable = R._short_leg(k, le, wh, s1, 0.018, 0.018, sv, func(s, a): return wh.lerp(lv.darkened(0.1), 0.35 * smoothstep(0.2, 0.9, -sin(float(a)) * float(le["sg"])) * smoothstep(0.1, 0.5, float(s))))
		R._hem_roll(k, le, ad, s1, wh.darkened(0.05))
		if sd == "Right":
			I._holster(k, le, ad, bk, bk.lightened(0.05), true)
		# baldır: dizin altında lacivert bant, beyaz sargı turları, bilekte lacivert bant
		I._cuff(k, le, kn + 0.045, kn + 0.09, 0.0125, nv)
		I._shin(k, le, kn + 0.085, 9, aw)
		I._cuff(k, le, 0.915, 0.965, 0.0175, nv)
	# gömlek: bol kutu kesim, kalçaya iner
	var hem: float = H - 0.035
	var top: float = N + 0.012
	var jk: Array = AJ._jkeys(k, b, top, hem, 0.036, 0.05)
	var jf := func(a: float, y: float, _v: float) -> float:
		var aw2: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		var flat: float = 1.0 - 0.9 * exp(-pow((aw2 - PI) / 0.5, 2.0)) * smoothstep(H + 0.05, H + 0.12, y)   # sırt ortası düz: arma kırılmaz
		return flat * (t * (0.02 * sin(a * 6.0 + 0.9) + 0.009 * sin(a * 13.0 + 0.2)) + (1.0 - t) * 0.006 * sin(a * 4.0 + y * 12.0))
	var jsk: Callable = AJ._jsk(k, hem)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 40, "na": 92, "top": func(_a): return top, "hem": func(_a): return hem, "fold": jf, "col": func(_a, _y, _v): return nv, "gain": 6.0, "th": 0.006,
		"inner": nv.darkened(0.3), "skin": jsk})
	var hm := []
	for p in jg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.011, 0))
	P._cord(k, hm, 0.0024, nv.darkened(0.2), true, jsk)
	var jff := func(a, y): return jf.call(float(a), float(y), 0.0)
	for sg in [1.0, -1.0]:
		Q._run(k, jk, jff, [Vector2(sg * 1.58, C - 0.04), Vector2(sg * 1.56, hem + 0.02)], 0.0022, 0.0015, 0.0011, nv.darkened(0.2), jsk, 8)
	_uchiwa(k, jk, C - 0.075, 0.074, nv.darkened(0.45), func(p): return k.torso_skin(maxf(float(p.y), H + 0.01)))
	# yüksek dik yaka: çeneye çıkar, içi açık leylak
	var cg: Dictionary = AJ._stand(k, nk, 0.1, 0.05, nv, lv, 0.04, 0.014)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.003, nv.lightened(0.05), false, func(p): return Q._nsk(k, p))
	# kollar: dirsek üstünde kısa kol; ön kolda beyaz kolluk, iki ucunda lacivert bant
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var kn: float = ar["kn"]
		var sv: float = 1.5 if sd == "Left" else 0.4
		R._arm_skin(k, ar, kn * 0.45)
		I._sleeve(k, ar, nv, 0.018, kn * 0.66, sv, 0.0, 0.012)
		I._cuff(k, ar, kn * 0.66 - 0.03, kn * 0.66, 0.024, nv.darkened(0.12))
		var gf := func(s: float, a: float) -> float:
			return 0.009 + 0.004 * sin(clampf(inverse_lerp(kn + 0.08, 0.92, s), 0.0, 1.0) * PI) + 0.0025 * sin(a * 3.0 + s * 30.0 + sv)
		P._lt(k, ar, gf, func(s, a, ins): return aw.darkened(0.3) if ins else P._fs(aw, 0.0025 * sin(float(a) * 3.0 + float(s) * 30.0 + sv), 20.0), kn + 0.07, 0.93, 20, 18, 0.02)
		I._cuff(k, ar, kn + 0.045, kn + 0.09, 0.0125, nv)
		I._cuff(k, ar, 0.915, 0.975, 0.0115, nv)


# ------------------------------------------------------------------ Kisetsu Shōzoku (ref Shinobi Striker "Seasonal Outfits" Chōji Dumplings): limon yeşili yakalı, göğsünde koyu kızıl 食 damgalı pembe tişört,
## üstünde önü açık pembe kısa haori (geniş yeşil ön bantlar ve etek bandı, dirsek altına inen geniş kol + iki yeşil bant ve yeşil manşet, sırtta ve önde kabartma dango şişleri),
## beyaz kemer + yeşil plaka, diz altında toplanan pembe-beyaz-yeşil çizgili bol kapri (çizgiler kumaşa dikili şerit), altı çıplak baldır
static func _mevsim(k) -> void:
	var pk := Color(0.94, 0.62, 0.69)
	var hk := Color(0.93, 0.6, 0.68)
	var lm := Color(0.74, 0.92, 0.32)
	var em := Color(0.55, 0.1, 0.14)
	var wb := Color(0.95, 0.95, 0.93)
	var pp := Color(0.95, 0.68, 0.75)
	var ws := Color(0.98, 0.97, 0.95)
	var dp := Color(0.82, 0.4, 0.48)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# boyun teni + tişört
	var sk_k := [P._kp(nk, N + 0.04, 0.004, 0.006), P._kp(nk, N + 0.0, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9]]
	SE.body_layer(k, sk_k, 8, 32, func(_i, _j, _p): return skc)
	K._seat(k, b, pp)
	I._seat(k, b, pp)
	var tk := [P._kp(nk, N + 0.025, 0.012), [N - 0.05, ch.x * 0.88, ch.y * 0.86, ch.z * 0.95], P._kp(ch, C - 0.03, 0.014), P._kp(wa, H + 0.12, 0.016), P._kp(hp, H - 0.06, 0.016)]
	var tf := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 7.0 + y * 12.0) * smoothstep(C, H, y)
	var tsk := func(p): return k.torso_skin(p.y)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 26, "na": 64, "top": func(a): return lerpf(N - 0.014, N + 0.022, smoothstep(0.0, 1.8, absf(float(a)))), "hem": func(_a): return H - 0.06, "fold": tf,
		"col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.004, "inner": pk.darkened(0.3), "skin": tsk})
	var nb := []
	for p in tg["top"]:
		nb.append((p as Vector3) + Vector3(0, -0.006, 0))
	P._bd(k, nb, 0.008, 0.004, lm, true, func(p): return Q._nsk(k, p), 0.2)
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var cy: float = lerpf(C, H + 0.12, 0.3)
	S._shoku(k, Q._local(tk, tff, 0.0, cy), Q._spt(tk, tff, 0.0, cy)[1], 0.068, em, tsk)
	# beyaz kemer + yeşil plaka
	var bk2 := [P._kp(wa, H + 0.07, 0.022), P._kp(hp, H - 0.05, 0.022)]
	var by: float = H + 0.015
	P._sash(k, bk2, by, 0.022, 0.006, wb, 0.1)
	var pe: Array = P._fp(bk2, 0.0, by, true, 0.03)
	P._boxr(k, pe[0], Vector3(0.05, 0, 0), Vector3(0, 0.019, 0), (pe[1] as Vector3) * 0.006, lm, [["Hips", 1.0]], 0.4)
	for sx in [-0.02, 0.02]:
		P._stud(k, (pe[0] as Vector3) + Vector3(sx, 0.004, 0) + (pe[1] as Vector3) * 0.006, pe[1], 0.0034, lm.darkened(0.45), [["Hips", 1.0]])
	# çizgili kapri: diz altında toplanır, çizgiler kumaşa dikili şerit
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.2
		var sv: float = 0.9 if sd == "Left" else 2.1
		P._bare(k, le, skc, s1 - 0.04, 1.0)
		var pa: Callable = AJ._pleg(k, le, pp, s1, 0.022, 0.03, sv, 0.42)
		Q._ring_on(k, le, s1 - 0.014, func(s, a): return float(pa.call(float(s), float(a))) + 0.001, 0.015, pp.darkened(0.05), 0.004)
		var lift := func(s, a): return float(pa.call(float(s), float(a))) + 0.0005
		for i in 12:
			var a0: float = TAU * float(i) / 12.0 - PI + 0.13
			var c: Color = ws if i % 3 == 0 else (dp if i % 3 == 1 else lm)
			var hw: float = 0.0062 if i % 3 == 0 else (0.0042 if i % 3 == 1 else 0.0022)
			S._lstrip(k, le, 0.035, s1 - 0.03, func(_s): return a0, lift, hw, 0.0014, c, 18)
	# haori: uyluğa iner, önü açık; geniş yeşil ön bantlar + etek bandı
	var hem: float = H - 0.16
	var box: float = maxf(wa.x + 0.055, ch.x * 1.0)
	var hk2 := [P._kp(nk, N + 0.012, 0.036), [N - 0.055, ch.x * 1.05, ch.y * 0.99, ch.z * 1.08], P._kp(ch, C - 0.03, 0.044), [H + 0.12, box, maxf(wa.y + 0.06, ch.y * 0.95), minf(wa.z - 0.06, ch.z * 0.97)],
		[H - 0.04, maxf(box, hp.x + 0.06), hp.y + 0.07, hp.z - 0.07], [hem, maxf(box, hp.x + 0.07), hp.y + 0.075, hp.z - 0.075]]
	var hf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.55, 0.95, aw) * (t * (0.018 * sin(a * 7.0 + 0.5) + 0.008 * sin(a * 13.0 + 1.6)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 14.0))
	var hsk := func(p): return Q._csk(k, p, hem, 0.08)
	var hrg := func(v) -> Vector2:
		var e: float = lerpf(0.3, 0.46, smoothstep(0.0, 0.5, float(v)))
		return Vector2(e, TAU - e)
	var hg: Dictionary = P._cl(k, {"keys": hk2, "ny": 34, "na": 84, "rng": hrg, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return hf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return hk, "gain": 5.0, "th": 0.006, "inner": hk.darkened(0.25), "skin": hsk})
	for ed in [hg["ea"], hg["eb"]]:
		P._bd(k, ed, 0.017, 0.0045, lm, false, hsk, 0.0)
	var neckb := []
	for p in hg["top"]:
		neckb.append((p as Vector3) + Vector3(0, -0.012, 0))
	P._bd(k, neckb, 0.014, 0.0045, lm, false, func(p): return Q._nsk(k, p), 0.3)
	var hm := []
	for p in hg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.036, 0))
	P._bd(k, hm, 0.034, 0.0045, lm, false, hsk)
	var hff := func(a, y): return hf.call(float(a), float(y))
	for sg in [1.0, -1.0]:
		Q._run(k, hk2, hff, [Vector2(sg * (PI * 0.5 + 0.08), C - 0.06), Vector2(sg * (PI * 0.5 + 0.05), H), Vector2(sg * (PI * 0.5 + 0.03), hem + 0.075)], 0.0025, 0.001, 0.0014, hk.darkened(0.2), hsk, 8)
	# dango şişleri: önde iki kanatta, sırtta dağınık
	var dsk := func(p): return Q._csk(k, p, hem, 0.08)
	for e3 in [[0.75, C + 0.03, 0.5], [1.15, C - 0.1, -0.4], [0.7, H + 0.08, -0.3], [1.2, H - 0.03, 0.6], [-0.75, C + 0.0, -0.5], [-1.2, C - 0.12, 0.3], [-0.72, H + 0.05, 0.4], [-1.18, H - 0.05, -0.6],
		[PI, C + 0.0, 0.3], [PI - 0.6, C - 0.06, -0.5], [-(PI - 0.6), C - 0.04, 0.6], [PI - 0.3, H + 0.03, -0.2], [-(PI - 0.35), H + 0.06, 0.45], [PI - 0.95, H - 0.04, 0.2], [-(PI - 0.95), H - 0.02, -0.4], [PI + 0.0, H - 0.07, 0.7]]:
		var mp: Callable = Q._local(hk2, hff, float(e3[0]), float(e3[1]))
		_dango(k, mp, float(e3[2]), 0.013, dsk)
	# kollar: tişört kısa kolu, haori geniş kolu (dirsek altı) + iki yeşil bant + yeşil manşet, altında çıplak ön kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv3: float = 1.4 if sd == "Left" else 0.3
		I._cap(k, ar, hk, 0.022)
		R._arm_skin(k, ar, 0.3)
		P._lt(k, ar, func(s, a): return 0.009 + 0.003 * P._lf(float(s), float(a), sv3), func(_s, _a, ins): return pk.darkened(0.35) if ins else pk, 0.0, 0.34, 10, 18)
		var s1 := 0.7
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.1, 0.5, s)
			var hang: float = maxf(0.0, -sin(a) * sg)
			return 0.022 + 0.034 * fl + 0.016 * fl * hang * hang + (0.003 + 0.005 * fl) * P._lf(s, a, sv3) + 0.006 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins): return hk.darkened(0.25) if ins else P._fs(hk, float(sf.call(float(s), float(a))) - 0.022 - 0.034 * smoothstep(0.1, 0.5, float(s)), 12.0), 0.0, s1, 30, 24, 0.05)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, hk.darkened(0.25), 0.4, s1, 10, 24)
		for e4 in [[0.33, 0.017], [0.53, 0.017], [s1 - 0.024, 0.024]]:
			Q._ring_on(k, ar, float(e4[0]), func(s, a): return float(sf.call(float(s), float(a))) + 0.001, float(e4[1]), lm, 0.0035)
		var lsk := func(p): return R._lsk(ar, p)
		for e5 in [[0.2, Vector3(sg, 0.3, 0.2), 0.4], [0.43, Vector3(sg, -0.2, 0.5), -0.5], [0.44, Vector3(sg * 0.2, 0.0, -1.0), 0.2]]:
			var s5: float = e5[0]
			var a5: float = J._outer_a(ar, s5, e5[1])
			_dango(k, R._lmap(ar, func(s, a): return float(sf.call(float(s), float(a))), s5, a5), float(e5[2]), 0.0095, lsk)


# ------------------------------------------------------------------ Kage Wakate (ref Shinobi Striker "Shikadai Outfit"): kalçaya inen soluk sarı fermuarlı ceket (dik yaka, yakadan koltuk altına reglan dikiş,
## sırtta Nara arması), sol üst kolda Konoha plakalı siyah kol bandı, bileğe uzun kol; toplanan lacivert bol pantolon, sağ uylukta beyaz sargı + siyah kılıf, kalçada kahve çanta
static func _golge(k) -> void:
	var ye := Color(0.91, 0.878, 0.659)
	var nv := Color(0.118, 0.165, 0.282)
	var bk := Color(0.165, 0.165, 0.188)
	var br := Color(0.45, 0.31, 0.19)
	var mt := Color(0.72, 0.73, 0.76)
	var dk := Color(0.24, 0.21, 0.15)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return nv.darkened(0.2), 0.006, H - 0.04)
	K._seat(k, b, nv)
	I._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.6 if sd == "Left" else 0.5
		var ad: Callable = I._pant(k, le, nv, 0.013, 0.026, 0.82, 0.018, sv)
		if sd == "Right":
			I._holster(k, le, ad, bk, bk.lightened(0.05), true)
	X._bag(k, R._seat_keys(k, b), H - 0.035, 0.028, br)
	# ceket: kalçaya iner, yakaya kadar fermuarlı
	var hem: float = H - 0.065
	var top: float = N + 0.012
	var jk: Array = AJ._jkeys(k, b, top, hem, 0.03, 0.058)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		var flat: float = 1.0 - 0.9 * exp(-pow((aw - PI) / 0.55, 2.0)) * smoothstep(H + 0.06, H + 0.14, y)
		return flat * smoothstep(0.12, 0.5, aw) * (t * (0.018 * sin(a * 5.0 + 0.8) + 0.008 * sin(a * 11.0 + 2.0)) + (1.0 - t) * 0.007 * sin(a * 4.0 + y * 12.0))
	var jsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.005)) if float(p.y) > H - 0.005 else Q._csk(k, p, hem, 0.07)   # etek önü uyluğu izler: kalkan uyluk ceketi delmez
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 44, "na": 92, "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return ye, "gain": 6.0, "th": 0.007, "inner": ye.darkened(0.3), "skin": jsk})
	var jff := func(a, y): return jf.call(float(a), float(y))
	AJ._zip(k, jk, jff, top - 0.004, hem + 0.004, ye.darkened(0.12), mt, jsk)
	var hm := []
	for p in jg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._cord(k, hm, 0.0026, ye.darkened(0.14), true, jsk)
	for sg in [1.0, -1.0]:   # reglan dikişi: yakadan koltuk altına; yan dikiş
		Q._run(k, jk, jff, [Vector2(sg * 0.62, N + 0.0), Vector2(sg * 0.95, N - 0.06), Vector2(sg * 1.3, C - 0.06)], 0.0022, 0.0015, 0.0012, ye.darkened(0.25), jsk, 8)
		Q._run(k, jk, jff, [Vector2(sg * (PI - 0.62), N + 0.0), Vector2(sg * (PI - 0.95), N - 0.06), Vector2(sg * (PI - 1.3), C - 0.06)], 0.0022, 0.0015, 0.0012, ye.darkened(0.25), jsk, 8)
		Q._run(k, jk, jff, [Vector2(sg * 1.57, C - 0.06), Vector2(sg * 1.57, hem + 0.02)], 0.0022, 0.0015, 0.0011, ye.darkened(0.2), jsk, 8)
	# sırtta Nara arması: çember + iki S kavis + iki kısa çubuk (kabartma)
	var nsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.01))
	var mp: Callable = Q._local(jk, jff, PI, C - 0.07)
	var rr: float = 0.06
	Q._circle(k, mp, rr, rr * 0.13, 0.0045, dk, nsk, 44)
	for cv in [[Vector2(-0.9, 0.1), Vector2(-0.3, 0.2), Vector2(0.15, 0.45), Vector2(0.42, 0.86)], [Vector2(-0.74, -0.5), Vector2(-0.2, -0.4), Vector2(0.3, -0.05), Vector2(0.9, 0.18)],
		[Vector2(-0.3, 0.2), Vector2(-0.3, 0.52)], [Vector2(-0.02, -0.4), Vector2(-0.02, -0.88)]]:
		var pts := []
		for q in P._path(cv, 5):
			pts.append(q * rr)
		R._lstrip(k, mp, pts, rr * 0.1, 0.0045, 0.0016, dk, nsk)
	# dik yaka: fermuar yakaya çıkar
	var cg: Dictionary = AJ._stand(k, nk, 0.07, 0.035, ye, ye.darkened(0.15), 0.032, 0.006)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.0028, mt, false, func(p): return Q._nsk(k, p))
	# kollar: bileğe; sol üst kolda siyah bant + Konoha plakası
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sv: float = 0.4 if sd == "Left" else 1.7
		var sf: Callable = AJ._sleeve(k, ar, ye, 0.935, sv, 0.015, 0.004)
		I._cap(k, ar, ye, 0.015)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0015, func(_s, _a, ins): return ye.darkened(0.3) if ins else ye.darkened(0.06), 0.9, 0.937, 4, 20)
		R._arm_skin(k, ar, 0.85)
		if sd == "Left":
			Q._ring_on(k, ar, 0.3, func(s, a): return float(sf.call(float(s), float(a))) + 0.002, 0.024, bk, 0.003)
			_leaf_plate(k, ar, 0.3, sf, mt)
