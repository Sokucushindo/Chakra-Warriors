extends RefCounted
## Elle modellenmiş setler, parti aa: ss_soylu_pelerin, ss_goksel_beyaz, ss_karga_tunik, ss_karga_cubbe, ss_kaya_paltosu, ss_kabuk_cubbe. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/{hiashi, isshiki, itachi, itachi_reanimation, iwabe_ninja_school, jigen}_outfit + refs/outfits_ss/all/<ad>/ (renk türevleri, açılar).
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), m (M) dosyalarından. Burada: uzun giysi aile ağırlığı (_fam), karga ortak parçaları, setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const G = preload("res://scripts/actors/set_el_g.gd")

const DONE := ["ss_soylu_pelerin", "ss_goksel_beyaz", "ss_karga_tunik", "ss_karga_cubbe", "ss_kaya_paltosu", "ss_kabuk_cubbe"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_soylu_pelerin": _soylu(k)
		"ss_goksel_beyaz": _goksel(k)
		"ss_karga_tunik": _karga_tunik(k)
		"ss_karga_cubbe": _karga_cubbe(k)
		"ss_kaya_paltosu": _kaya(k)
		"ss_kabuk_cubbe": _kabuk(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ağırlık
## Uzun giysi aile ağırlığı: ağırlık noktanın yarıçapından değil yönünden (açı) ve boyundan gelir. Üst üste binen katlar (kimono + cübbe,
## iç + dış kanat) aynı yükseklik ve yönde AYNI ağırlığı alır: iç kat dış katın hep içinde kalır, koşuda dışarı taşmaz.
## Ön: iki bacak arasında geniş geçiş (ortalamayı izler, ortadan yırtılmaz), bacak hizasında kendi bacağı; arka: boy boyunca yavaş artar,
## diz altında baldırı izler (geri giden topuk delmez); uçta ağırlık biraz düşer (etek kanat açmaz). hem: AİLENİN en uzun katının ucu.
static func _fam(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.11), 0.5)   # ön: boydan bağımsız, uyluk ortasında tam (kalkan uyluk delmez)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.95, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.92, smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(0.035, 0.1, bk)   # önde dar geçiş: uyluğun önü tamamen kendi bacağını izler
	var s: float = smoothstep(-hw, hw, x)
	var kb: float = smoothstep(k.K + 0.06, k.K - 0.12, p.y) * lerpf(0.5, 0.7, bk) * absf(2.0 * s - 1.0)   # diz altı: önde yarı baldırdan (etek ucu levha gibi kalkmaz, dizden sarkar)
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


# ------------------------------------------------------------------ ortak yardımcılar
static func _yl(pts: Array, up: float) -> Array:
	var o := []
	for p in pts:
		o.append((p as Vector3) + Vector3(0, up, 0))
	return o


## Önü açık uzun giysi (cübbe / palto): keys, e_at(y) ön kenar açısı, ff(a, y) kıvrım, col(a, y) renk, lin astar, th kalınlık, skin.
## Döner: {rows, ea, eb, hem, top, pt(a, y)}
static func _coat(k, keys: Array, top: float, hem: float, e_at: Callable, ff: Callable, colf: Callable, lin: Color, skinf: Callable, ny := 56, na := 100, th := 0.008) -> Dictionary:
	var H: float = k.H
	var pt := func(a: float, y: float) -> Vector3:
		var s: Array = SE.El.key_at(keys, y)
		var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
		var f: float = 1.0 + float(ff.call(a, y))
		return Vector3(q.x * f, y, q.y * f)
	var co := []
	for j in ny + 1:
		var y := lerpf(top, hem, float(j) / ny)
		var e: float = e_at.call(y)
		var ro := []
		for i in na + 1:
			ro.append(pt.call(lerpf(e, TAU - e, float(i) / na), y))
		co.append(ro)
	var rows: Array = co.duplicate()
	var src := []
	for j in ny + 1:
		src.append([j, false])
	var inw := func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
	var roll := []
	for p in co[ny]:
		roll.append(inw.call(p, th * 0.6) + Vector3(0, -th * 0.6, 0))
	rows.append(roll)
	src.append([ny, true])
	for j in range(ny, -1, -2):
		var ro := []
		for i in na + 1:
			ro.append(co[j][i] if i == 0 or i == na else inw.call(co[j][i], th))
		rows.append(ro)
		src.append([j, true])
	k.grid(rows, false, func(i, j, _p):
		var e2: Array = src[j]
		var oj: int = e2[0]
		var y: float = co[oj][0].y
		var e: float = e_at.call(y)
		var a: float = lerpf(e, TAU - e, float(i) / na)
		if e2[1]:
			return lin.darkened(0.12 * float(oj == ny))
		var f: float = ff.call(a, y)
		var c0: Color = colf.call(a, y)
		return c0.darkened(clampf(-f * 6.0, 0.0, 0.34)).lightened(clampf(f * 2.0, 0.0, 0.09)), func(_i, _j, p): return skinf.call(p))
	var ea := []
	var eb := []
	for ro in co:
		ea.append(ro[0])
		eb.append(ro[na])
	return {"rows": co, "ea": ea, "eb": eb, "hem": co[ny], "top": co[0], "pt": pt}


## Sırt yüzeyinde yerel eşleme (arma, desen): x metre (izleyene göre sağa), y boy; dairesel desen bozulmaz
static func _back_mp(keys: Array, cx: float, cy: float) -> Callable:
	return func(u: float, v: float, l: float) -> Vector3: return P._fp(keys, -(cx + u), cy + v, false, l)[0]


## Çıplak kol için uzuv: bedenden ölçülen yarıçap gövdeye yakın yerde şişer; omuzdan bileğe makul üst sınır (kol balon gibi görünmez)
static func _bare_arm(k, sd: String) -> Dictionary:
	var l: Dictionary = G._arm(k, sd)
	var rad: Array = l["rad"]
	var n: int = rad.size()
	for i in n:
		rad[i] = minf(float(rad[i]), lerpf(0.048, 0.032, float(i) / float(n - 1)))
	return l


## Kenar bandı: giysinin ön kenarı boyunca, kumaşın üstüne içe doğru binen kalın bant (yaka bandı / biye). sg: +1 sol kenar (ea), -1 sağ (eb)
static func _edge_band(k, ed: Array, w: float, d: float, col: Color, skinf: Callable, sg: float) -> void:
	var pts := []
	var ou := []
	for p: Vector3 in ed:
		var o := Vector3(p.x, 0.0, p.z).normalized()
		var tg := Vector3(o.z, 0.0, -o.x) * sg   # kumaşın içine doğru (kenardan uzağa)
		pts.append(p + tg * (w * 0.92) + o * 0.0015)
		ou.append(o)
	k.strip(pts, ou, w, d, col, false, skinf)


## Geniş, sarkan kol: ağız astarlı; alt yanı torba gibi iner. Döner: yarıçap ekleme işlevi
static func _hang_sleeve(k, ar: Dictionary, col: Color, lin: Color, base: float, wide: float, sag: float, s1: float, sv: float) -> Callable:
	var en: float = ar["kn"]
	var adn: float = J._outer_a(ar, 0.75, Vector3.DOWN)
	var sl := func(s: float, a: float) -> float:
		var t: float = smoothstep(0.04, s1, s)
		var dn: float = exp(-pow(wrapf(a - adn, -PI, PI) / 0.95, 2.0))
		return base + wide * t + sag * t * t * dn + (0.003 + 0.006 * t) * P._lf(s, a, sv) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
	var slc := func(s: float, a: float) -> float:
		var t: float = smoothstep(0.04, s1, s)
		return (0.003 + 0.006 * t) * P._lf(s, a, sv) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
	P._lt(k, ar, sl, func(s, a, ins): return lin if ins else P._fs(col, float(slc.call(float(s), float(a))), 12.0), 0.0, s1, 34, 26, 0.05)
	K._lt_in(k, ar, func(s, a): return float(sl.call(float(s), float(a))) - 0.006, lin, s1 - 0.3, s1, 10, 26)
	return sl


# ------------------------------------------------------------------ Kizoku Gaitō (ref Hiashi Outfit + renk türevleri): bileğe inen beyaz kimono (sol kanat sağın üstüne, eri yakası), lacivert obi,
## önü açık yere yakın koyu yeşil cübbe (kalın ön kenar bandı, astarlı geniş sarkan kollar), altta lacivert diz boyu şort
static func _soylu(k) -> void:
	var wh := Color(0.94, 0.94, 0.93)
	var ob := Color(0.141, 0.188, 0.416)
	var gn := Color(0.094, 0.157, 0.118)
	var gl := Color(0.13, 0.2, 0.15)
	var skc := Q._skc(k)
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
	var chem: float = F + 0.05
	var fam := func(p): return _fam(k, p, chem)
	P._inner(k, b, func(_i, _j, _p): return wh.darkened(0.06), 0.006)
	# kalça astarı yok: geri giden uyluk kimononun önünü içeri çeker, sabit astar önden görünürdü (kimono kapalı, kasık hiç görünmez)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		# şort paçası: yalnız dizin üstünde (koşuda kalkan etek ucunun altından görünen kısım); uyluk üstü kimonoyla kapalıdır, orada kumaş olsa
		# kalkan / geri giden uyluk onu kimononun önünden dışarı iterdi
		P._lt(k, le, func(s, a): return 0.006 + 0.004 * P._lf(s, a, 1.8 if sd == "Left" else 0.7), func(_s, _a, ins): return ob.darkened(0.4) if ins else ob, kn - 0.1, kn + 0.05, 12, 18)
		P._bare(k, le, skc, kn, 1.0)
	# kimono: sol kanat sağın üstüne biner, arkada dikiş; bileğe iner. Ağırlık cübbeyle aynı aileden (aynı uç boyu)
	var hem0: float = F + 0.11
	var keys := [P._kp(nk, N + 0.012, 0.024), [N - 0.055, ch.x * 0.99, ch.y * 0.94, ch.z * 1.03], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.028), [H - 0.04, hp.x + 0.036, hp.y + 0.056, hp.z - 0.036],
		[KN + 0.08, hp.x + 0.045, hp.y + 0.09, hp.z - 0.07], [hem0, hp.x + 0.06, hp.y + 0.065, hp.z - 0.09]]
	var kf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem0), 0.0, 1.0)
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return t * (0.02 * sin(a * 5.0 + 0.4) + 0.01 * sin(a * 9.0 + 1.7)) + (1.0 - up) * 0.006 * sin(a * 7.0 + y * 10.0) * smoothstep(0.0, 0.1, up)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem0, "col": func(_a, _y, v): return wh.darkened(0.1 * smoothstep(0.96, 1.0, float(v))), "fold": kf, "band": wh.darkened(0.07), "band_w": 0.02,
		"band_y": H + 0.1, "ny": 56, "na": 52, "gain": 4.0, "inner": wh.darkened(0.25), "skin_fn": fam})
	for lf in [true, false]:
		var g2: Dictionary = wg["L" if lf else "R"]
		P._bd(k, _yl(g2["hem"], 0.01), 0.006, 0.002, wh.darkened(0.12), false, fam)
	# obi: lacivert kalın kuşak, üstünde ince ikinci kat
	var obk := [P._kp(wa, H + 0.15, 0.044), P._kp(wa, H + 0.0, 0.054)]
	var by: float = H + 0.075
	P._sash(k, obk, by, 0.048, 0.004, ob, 0.12)
	P._sash(k, obk, by + 0.004, 0.034, 0.011, ob.lightened(0.05), 0.0)
	# cübbe: önü açık, yere yakın; içi astarlı
	var ck := [P._kp(nk, N + 0.03, 0.046), [N - 0.045, ch.x * 1.05, ch.y * 0.98 + 0.014, ch.z * 1.08 - 0.014], P._kp(ch, C - 0.03, 0.056), P._kp(wa, H + 0.12, 0.084), P._kp(hp, H - 0.04, 0.084),
		[KN + 0.05, hp.x + 0.125, hp.y + 0.11, hp.z - 0.14], [chem, hp.x + 0.155, hp.y + 0.12, hp.z - 0.19]]
	var e_at := func(y: float) -> float: return lerpf(0.44, 0.6, smoothstep(C, chem, y)) - 0.2 * smoothstep(N - 0.06, N + 0.03, y)
	var cf := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - chem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		return smoothstep(0.5, 0.85, aw) * (pow(t, 0.9) * ((0.036 + 0.014 * bkf) * sin(a * 7.0 + 0.6) + 0.018 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.007 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y))
	var cg: Dictionary = _coat(k, ck, N + 0.03, chem, e_at, cf, func(_a, _y): return gn, gl, fam, 50, 90, 0.008)
	_edge_band(k, cg["ea"], 0.017, 0.0045, gn.lightened(0.04), fam, 1.0)
	_edge_band(k, cg["eb"], 0.017, 0.0045, gn.lightened(0.04), fam, -1.0)
	P._bd(k, _yl(cg["hem"], 0.01), 0.005, 0.002, gn.lightened(0.06), false, fam)
	P._cord(k, cg["top"], 0.009, gn.lightened(0.04), false, func(p): return Q._nsk(k, p))
	# kollar: kimononun beyaz kolu bileğe kadar, üstte cübbenin geniş sarkan kolu
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.6 if sd == "Left" else 0.5
		var ks := func(s: float, a: float) -> float: return 0.008 + 0.01 * smoothstep(0.5, 0.95, s) + 0.003 * P._lf(s, a, sv + 1.0)
		P._lt(k, ar, ks, func(_s, _a, ins): return wh.darkened(0.25) if ins else wh.darkened(0.04), 0.3, 0.965, 18, 20, 0.02)
		_hang_sleeve(k, ar, gn, gl, 0.022, 0.034, 0.03, 0.9, sv)


# ------------------------------------------------------------------ Ten no Koromo (ref Isshiki Outfit): çıplak gövdede siyah tomoe dizisi (üstte yatık iri tomoe, aşağı inen boncuklar); önü açık beyaz palto
## (önde dize, arkada baldıra iner; kalın kırmızı ön biye, koyu kırmızı astar, yukarı açılan yüksek kırmızı yaka, kırmızı katlı manşet, kolda ve sırtta tomoe), bol siyah pantolon
static func _goksel(k) -> void:
	var wh := Color(0.933, 0.933, 0.949)
	var rd := Color(0.627, 0.078, 0.141)
	var rl := Color(0.34, 0.05, 0.08)
	var bk := Color(0.094, 0.094, 0.11)
	var ink := Color(0.05, 0.05, 0.06)
	var fem: bool = String(k.m.look.get("gender", "m")) == "f"
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
	var skc := Q._skc(k)
	var tsk := func(p): return k.torso_skin(p.y)
	# çıplak gövde (kadında göğsü saran siyah bez)
	var tk: Array = R._bare_torso(k, b, H - 0.03, not fem)
	if fem:
		var wk := []
		for y in [C + 0.06, C + 0.0, C - 0.06, C - 0.11]:
			wk.append(P._kp(k.M(y, k.UA), y, 0.007))
		SE.body_layer(k, wk, 10, 52, func(_i, j, _p): return ink.lightened(0.06) if j in [0, 10] else ink, func(a, y): return 0.012 * sin(a * 9.0 + y * 40.0))
	# tomoe dizisi: göğüste yatık iri tomoe, karına inen boncuklar, aralarında ince bağ
	var yb0: float = C + 0.005 if not fem else C - 0.13
	var ybn: float = H + 0.05
	var bead_n := 6 if not fem else 3
	var ov := func(th): return 1.0 / sqrt(pow(cos(float(th)) / 1.45, 2.0) + pow(sin(float(th)) / 0.75, 2.0))
	if not fem:
		Q._disc(k, Q._local(tk, Callable(), 0.0, yb0), Vector3(0, 0, 1), 0.026, 0.004, ov, func(_u, _v): return ink, tsk, 4, 30)
	var ys := []
	for i in bead_n:
		ys.append(lerpf(yb0 - (0.05 if not fem else 0.0), ybn, float(i) / (bead_n - 1)))
	Q._run(k, tk, Callable(), [Vector2(0.0, yb0 - 0.01), Vector2(0.0, ybn)], 0.0022, 0.003, 0.0015, ink, tsk, 12)
	for y in ys:
		Q._disc(k, Q._local(tk, Callable(), 0.0, y), Vector3(0, 0, 1), 0.0115, 0.005, Callable(), func(u, v): return ink.lightened(0.12) if Vector2(float(u) + 0.3, float(v) - 0.3).length() < 0.3 else ink, tsk, 3, 18)
	# bol siyah pantolon: kalça + düz geniş paçalar, bilekte ağız (içinde ten)
	R._seat(k, R._seat_keys(k, b), func(_i, _j, _p): return bk)
	P._sash(k, [P._kp(k.M(H + 0.05, 0.3), H + 0.1, 0.012), P._kp(k.M(H + 0.05, 0.3), H + 0.0, 0.018)], H + 0.05, 0.03, 0.0, bk.lightened(0.04), 0.1)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = le["sg"]
		var kn: float = le["kn"]
		var sv: float = 2.1 if sd == "Left" else 0.4
		var pa := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			var wd: float = 0.024 + 0.04 * smoothstep(0.05, 0.55, s)
			var fo: float = (0.004 + 0.012 * smoothstep(0.1, 0.6, s)) * P._lf(s, a, sv) + 0.008 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
			return wd * (1.0 - 0.38 * inn) + fo + 0.012 * smoothstep(0.85, 0.98, s) * maxf(0.0, cos(a))
		var pf := func(s: float, a: float) -> float:
			return (0.004 + 0.012 * smoothstep(0.1, 0.6, s)) * P._lf(s, a, sv) + 0.008 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		P._lt(k, le, pa, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.05), float(pf.call(float(s), float(a))), 9.0), 0.0, 0.975, 44, 26, 0.05)
		K._lt_in(k, le, func(s, a): return float(pa.call(float(s), float(a))) - 0.005, bk.darkened(0.2), 0.8, 0.975, 8, 26)
		P._bare(k, le, skc, 0.72, 1.0)
	# palto: önü dar açık, önde dize, arkada baldıra iner
	var hf := func(a: float) -> float: return lerpf(KN + 0.01, KN - 0.17, smoothstep(0.9, 2.6, absf(a)))
	var chem: float = KN - 0.17
	var csk := func(p): return K._coat_skin(k, p, chem)
	var ck := [P._kp(nk, N + 0.012, 0.034), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.05), P._kp(hp, H - 0.04, 0.062),
		[KN + 0.05, hp.x + 0.13, hp.y + 0.09, hp.z - 0.14], [chem, hp.x + 0.15, hp.y + 0.1, hp.z - 0.17]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - chem), 0.0, 1.0)
		return smoothstep(0.32, 0.7, aw) * (pow(t, 0.9) * ((0.04 + 0.016 * smoothstep(1.2, 2.2, aw)) * sin(a * 7.0 + 0.6) + 0.02 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.007 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y))
	var e_at := func(v: float) -> float:
		var y: float = lerpf(N + 0.012, chem, v)
		return lerpf(0.3, 0.4, smoothstep(C, KN, y)) - 0.12 * smoothstep(N - 0.06, N + 0.012, y)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 56, "na": 100, "rng": func(v): return Vector2(float(e_at.call(float(v))), TAU - float(e_at.call(float(v)))), "top": func(_a): return N + 0.012, "hem": func(a): return hf.call(float(a)),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.008, "inner": rl, "skin": csk})
	_edge_band(k, cg["ea"], 0.014, 0.0045, rd, csk, 1.0)
	_edge_band(k, cg["eb"], 0.014, 0.0045, rd, csk, -1.0)
	P._bd(k, _yl(cg["hem"], 0.009), 0.0045, 0.0018, wh.darkened(0.1), false, csk)
	# yüksek yaka: arkada başın arkasına yükselen, dışa açılan koyu kırmızı huni
	var q: float = Q._hq(k)
	var cl_k := [[N + 0.22 * q, nk.x + 0.13, nk.y + 0.1, nk.z - 0.13], [N + 0.11 * q, nk.x + 0.078, nk.y + 0.06, nk.z - 0.08], [N + 0.0, nk.x + 0.058, nk.y + 0.046, nk.z - 0.058], [N - 0.05, nk.x + 0.075, nk.y + 0.06, nk.z - 0.07]]
	var skin_t := func(p): return k.torso_skin(minf(float(p.y), N))
	var col_g: Dictionary = P._cl(k, {"keys": cl_k, "ny": 18, "na": 56, "rng": func(_v): return Vector2(0.6, TAU - 0.6), "top": func(a):
		return N + q * lerpf(0.09, 0.2, smoothstep(0.6, 2.3, absf(float(a)))), "hem": func(_a): return N - 0.04, "fold": func(a, y, v): return 0.02 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.6) + 0.006 * sin(float(a) * 9.0 + float(y) * 20.0), "col": func(_a, _y, v): return rd.lightened(0.04) if float(v) < 0.12 else rd, "inner": rl, "skin": skin_t, "th": 0.007, "gain": 5.0})
	P._cord(k, col_g["top"], 0.0055, rd.darkened(0.1), false, skin_t)
	# kollar: bileğe inen beyaz kol, kırmızı katlı manşet; üst kolda üç tomoe
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sg: float = ar["sg"]
		var sv: float = 1.3 if sd == "Left" else 2.7
		var sf: Callable = Y._sleeve(k, ar, wh, 0.016, 0.014, 0.94, sv, 0.1, rd, 0.016)
		var L: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
		for i in 3:
			var s0: float = 0.18 + 0.1 * i
			var a0: float = J._outer_a(ar, s0, Vector3(sg, 0.0, 0.0))
			var R0: float = P._lr(ar, s0) + float(sf.call(s0, a0))
			var mp := func(u: float, v: float, l: float) -> Vector3:
				var s2: float = s0 - v / L
				var a2: float = a0 + u / R0
				return Q._ls(ar, s2, a2, float(sf.call(s2, a2)) + l)[0]
			Q._tomoe(k, mp, Q._ls(ar, s0, a0, 0.0)[1], 0.015, 1.2 + i * 0.9, 0.003, rd, func(_p): return P._lskin(ar, s0))
	# sırt: ortada disk, çevresinde altı tomoe
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var yc: float = C - 0.06
	var ob := Vector3(0, 0, -1)
	var rb: float = ch.x * 0.5   # desen boyu gövde genişliğinden (kadın bedende omza taşmaz)
	Q._disc(k, _back_mp(ck, 0.0, yc), ob, rb * 0.35, 0.004, Callable(), func(u, v): return rd.darkened(0.25) if Vector2(float(u), float(v)).length() > 0.82 else rd, csk, 4, 28)
	for i in 6:
		var th: float = TAU * i / 6.0 + PI * 0.5
		Q._tomoe(k, _back_mp(ck, cos(th) * rb, yc + sin(th) * rb), ob, rb * 0.22, th + PI * 0.5, 0.004, rd, csk)


# ------------------------------------------------------------------ karga ortak parçaları (Itachi tunik ve Itachi cübbesi): tomoe kolye, kapri / dar pantolon + baldırda bol tozluk
## Boyun kökünde ip kolye, önde üç küçük tomoe sarkar. keys: altındaki gövde katmanı
static func _karga_neck(k, keys: Array, cord: Color, tm: Color) -> void:
	var N: float = k.N
	var nsk := func(_p): return [["Neck", 0.35], ["UpperChest", 0.65]]
	var yf := func(a: float) -> float: return N + 0.012 - 0.04 * pow(maxf(0.0, cos(a)), 1.6)
	var pts := []
	for i in 44:
		var a := TAU * i / 44.0 - PI
		var p: Vector3 = P._on(keys, a, yf.call(a), 0.0)
		pts.append(p + P._out(p) * 0.004)
	P._cord(k, pts, 0.0018, cord, true, nsk, 0.0, 5)
	for i in 3:
		var a: float = (float(i) - 1.0) * 0.32
		var y: float = float(yf.call(a)) - 0.011
		var p: Vector3 = P._on(keys, a, y, 0.0)
		var o: Vector3 = P._out(p)
		var ri: Vector3 = Vector3.UP.cross(o).normalized()
		var c0: Vector3 = p + o * 0.004
		var mp := func(u: float, v: float, l: float) -> Vector3: return c0 + ri * u + Vector3.UP * v + o * l
		Q._tomoe(k, mp, o, 0.0055, -1.2 + 0.4 * i, 0.0015, tm, nsk)
		var st := [c0 + Vector3(0, 0.011, 0), c0 + Vector3(0, 0.004, 0)]
		k.strip(st, [o, o], 0.0009, 0.0009, cord, false, nsk)


## Kapri / pantolon s1'de büzülür, altında baldırı saran bol tozluk (gri / beyaz) bileğe iner; tozluğun üstü kalın bant. Döner: tozluk yarıçap işlevi
static func _karga_leg(k, le: Dictionary, pn: Color, gw: Color, s1: float, bag: float, sv: float) -> Callable:
	var kn: float = le["kn"]
	var sg: float = le["sg"]
	var pa := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var g: float = smoothstep(s1 - 0.08, s1 + 0.005, s)
		var v: float = (0.012 + bag * smoothstep(0.0, 0.4, s)) * (1.0 - 0.35 * inn * (1.0 - smoothstep(0.3, 0.6, s)))
		var fo: float = (0.004 + bag * 0.15) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + 0.008 * exp(-pow((s - kn) / 0.055, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var ru: float = 0.009 * exp(-pow((s - s1 + 0.035) / 0.035, 2.0)) * absf(sin(a * 4.0 + sv))
		return lerpf(v, 0.03, g) + fo * (1.0 - g) + ru
	P._lt(k, le, pa, func(s, a, ins): return pn.darkened(0.42) if ins else P._fs(pn, float(pa.call(float(s), float(a))) - 0.012 - bag * 0.4, 10.0), 0.0, s1, 40, 22, 0.03)
	# tozluk: kapri ağzının içinden başlar, baldırda bol, bileğe kapanır
	var gt := func(s: float, a: float) -> float:
		return 0.014 + 0.006 * sin(clampf((s - s1 + 0.06) / (0.99 - s1 + 0.06), 0.0, 1.0) * PI) - 0.008 * smoothstep(0.93, 0.99, s) + 0.003 * sin(a * 5.0 + s * 41.0 + sv) * smoothstep(s1, s1 + 0.05, s)
	P._lt(k, le, gt, func(s, a, ins): return gw.darkened(0.35) if ins else gw.darkened(0.1 * float(sin(float(a) * 5.0 + float(s) * 41.0 + sv) < -0.4)), s1 - 0.06, 0.99, 22, 20)
	return gt


# ------------------------------------------------------------------ Karasu Tunikku (ref Itachi Outfit + renk türevleri): V yakada görünen file iç, kısa kollu mavimsi tunik (uyluk ortasına iner, belde
## beyaz ince kuşakla büzülür, V yaka biyeli), mavimsi kapri baldırda büzülür, altında gri bol tozluk; boyunda tomoe kolye
static func _karga_tunik(k) -> void:
	var tu := Color(0.29, 0.29, 0.471)
	var tr := Color(0.2, 0.2, 0.34)
	var pn := Color(0.235, 0.235, 0.376)
	var fl := Color(0.2, 0.2, 0.22)
	var nt := Color(0.42, 0.42, 0.46)
	var wb := Color(0.84, 0.84, 0.88)
	var gw := Color(0.58, 0.58, 0.63)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	var inn: Array = P._inner(k, b, func(_i, _j, p): return skc if p.y > N + 0.004 else fl, 0.006)
	var yv: float = N - 0.115
	var vtop := func(a: float) -> float: return lerpf(yv, N + 0.012, pow(clampf(absf(a) / 0.62, 0.0, 1.0), 0.85))
	P._net_patch(k, inn, func(a, y): return float(y) > float(vtop.call(float(a))) - 0.012, -0.66, 0.66, yv - 0.02, N + 0.03, 0.013, 0.001, 0.0015, nt)
	_karga_neck(k, inn, Color(0.08, 0.08, 0.09), Color(0.06, 0.06, 0.07))
	K._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = _bare_arm(k, sd)
		var sv: float = 1.4 if sd == "Left" else 3.1
		var kn: float = le["kn"]
		var gt: Callable = _karga_leg(k, le, pn, gw, kn + 0.21, 0.012, sv)
		Q._ring_on(k, le, kn + 0.2, func(s, a): return float(gt.call(float(s), float(a))), 0.012, gw.darkened(0.06), 0.004)
		# kısa kol: dirseğin üstünde biter, ağzı katlı; altında çıplak kol
		R._arm_skin(k, ar, 0.3)
		var en: float = ar["kn"]
		var sl := func(s: float, a: float) -> float:
			return 0.006 + 0.024 * smoothstep(0.0, 0.42, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s)
		P._lt(k, ar, sl, func(s, a, ins): return tu.darkened(0.4) if ins else P._fs(tu, float(sl.call(float(s), float(a))) - 0.006 - 0.024 * smoothstep(0.0, 0.42, float(s)), 12.0), 0.0, en * 0.86, 22, 22, 0.04)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return tu.darkened(0.4) if ins else tu.darkened(0.08), en * 0.86 - 0.035, en * 0.86, 3, 22)
	# tunik: V yaka, belde kuşakla büzülür, uyluk ortasına iner
	var hem: float = H - 0.2
	var bl: Vector3 = k.M(H + 0.06, 0.3)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.06, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.13, 0.046), P._kp(bl, H + 0.06, 0.026), P._kp(hp, H - 0.04, 0.046), [hem, hp.x + 0.062, hp.y + 0.05, hp.z - 0.062]]
	var tsk := func(p): return T._ksk(k, p, hem)
	var ff := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.04 - y) / (H + 0.04 - hem), 0.0, 1.0)
		var bl2: float = 0.022 * exp(-pow((y - (H + 0.11)) / 0.035, 2.0)) * (0.6 + 0.4 * sin(a * 9.0 + 0.5))
		var gath: float = 0.014 * exp(-pow((y - (H + 0.03)) / 0.03, 2.0)) * sin(a * 13.0 + 0.4)
		return t * t * (0.03 * sin(a * 6.0 + 0.9) + 0.014 * sin(a * 11.0 + 2.1)) + bl2 + gath + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 13.0) * smoothstep(N - 0.03, C - 0.05, y)
	var tg: Dictionary = P._cl(k, {"keys": keys, "ny": 46, "na": 92, "top": func(a): return vtop.call(float(a)), "hem": func(_a): return hem, "fold": ff, "col": func(_a, _y, _v): return tu, "gain": 6.0, "th": 0.006, "skin": tsk, "inner": tu.darkened(0.35)})
	var ve := []
	for p in tg["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.66 and float(p.y) < N - 0.004:
			ve.append(p)
	P._bd(k, ve, 0.0075, 0.0028, tr, false, func(p): return k.torso_skin(p.y))
	P._bd(k, _yl(tg["hem"], 0.012), 0.0085, 0.0024, tu.darkened(0.12), false, tsk)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, func(a, y): return ff.call(float(a), float(y), 0.0), [Vector2(sg * 1.57, C - 0.08), Vector2(sg * 1.57, H + 0.08)], 0.0022, 0.0018, 0.0012, tu.darkened(0.2), func(p): return k.torso_skin(p.y), 8)
	# beyaz ince kuşak
	var bk2 := [P._kp(bl, H + 0.1, 0.036), P._kp(bl, H + 0.02, 0.036)]
	P._sash(k, bk2, H + 0.06, 0.012, 0.0, wb, 0.08)


# ------------------------------------------------------------------ Karasu Koromo (ref Itachi Outfit Reanimation Ver.): baldıra inen bordo cübbe, boynu saran haki astarlı düşük kapüşon, göğüsten kasığa
## orta fermuar, altında dar yırtmaç (içi haki astar), haki astarlı geniş kol; içte siyah gömlek + pantolon, baldırda beyaz tozluk; tomoe kolye
static func _karga_cubbe(k) -> void:
	var mr := Color(0.27, 0.05, 0.085)
	var kh := Color(0.722, 0.659, 0.471)
	var bk := Color(0.094, 0.094, 0.11)
	var wr := Color(0.8, 0.78, 0.86)
	var zp := Color(0.8, 0.79, 0.76)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	# iç: boyun altında ten, göğüs altı siyah gömlek
	var ik := [P._kp(nk, N + 0.022, 0.002), P._kp(nk, N + 0.0, 0.008), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.006), P._kp(wa, H + 0.12, 0.008), P._kp(hp, H - 0.09, 0.01)]
	SE.body_layer(k, ik, 28, 44, func(_i, _j, p): return skc if p.y > C - 0.02 else bk)
	_karga_neck(k, ik, bk, bk)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 2.4 if sd == "Left" else 0.9
		var kn: float = le["kn"]
		var gt: Callable = _karga_leg(k, le, bk, wr, kn + 0.2, 0.004, sv)
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.45, 0.975, 16, 16)
		_hang_sleeve(k, ar, mr, kh.darkened(0.08), 0.02, 0.036, 0.022, 0.9, sv)
	# cübbe: göğüste kapanır, fermuar kasığa iner, altında dar yırtmaç
	var hem: float = KN - 0.13
	var zt: float = N - 0.075
	var ze: float = H - 0.13
	var keys := [P._kp(nk, N + 0.012, 0.036), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.04), P._kp(wa, H + 0.12, 0.052), P._kp(hp, H - 0.04, 0.06),
		[KN + 0.05, hp.x + 0.09, hp.y + 0.085, hp.z - 0.12], [hem, hp.x + 0.12, hp.y + 0.09, hp.z - 0.17]]
	var csk := func(p): return T._bsk(k, p, hem)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		return smoothstep(0.06, 0.35, aw) * pow(t, 1.0) * (0.04 * sin(a * 6.0 + 0.9) + 0.018 * sin(a * 11.0 + 2.3)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 11.0) * smoothstep(N - 0.03, C - 0.04, y)
	var e_at := func(v: float) -> float:
		var y: float = lerpf(N + 0.012, hem, v)
		return 0.012 + 0.5 * pow(smoothstep(zt, N + 0.012, y), 1.2) + 0.15 * smoothstep(ze, hem, y)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 54, "na": 100, "rng": func(v): return Vector2(float(e_at.call(float(v))), TAU - float(e_at.call(float(v)))), "top": func(_a): return N + 0.012, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return mr, "gain": 6.0, "th": 0.008, "inner": kh.darkened(0.1), "skin": csk})
	P._bd(k, _yl(cg["hem"], 0.01), 0.005, 0.002, mr.lightened(0.06), false, csk)
	_edge_band(k, cg["ea"], 0.006, 0.0025, mr.lightened(0.04), csk, 1.0)
	_edge_band(k, cg["eb"], 0.006, 0.0025, mr.lightened(0.04), csk, -1.0)
	# fermuar: dişli bant + çekme
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var zz := []
	var y := zt
	while y > ze:
		zz.append(Q._spt(keys, ffw, 0.0, y, 0.004)[0])
		y -= 0.006
	P._bd(k, zz, 0.0042, 0.0018, zp.darkened(0.15), false, csk)
	for i in zz.size():
		if i % 2 == 0:
			P._stud(k, zz[i], P._out(zz[i]), 0.0022, zp, csk.call(zz[i]))
	var t0: Array = Q._spt(keys, ffw, 0.0, zt - 0.02, 0.008)
	P._boxr(k, t0[0], Vector3(0.0045, 0, 0), Vector3(0, 0.013, 0), (t0[1] as Vector3) * 0.003, zp, k.torso_skin(zt), 0.4)
	# boynu saran kapüşon: dışı bordo, içi haki
	Y._hood_down(k, b, keys, mr, 0.34, 0.075, kh)


## Giysi yüzeyine oturan kapak / cep ağzı: kenarları kumaşa iner, alt kenarı koyu (gölge payı). keys + ff yüzeyi, a0 açı, y0 üst kenar
static func _flap(k, keys: Array, ff: Callable, a0: float, y0: float, w: float, h: float, tilt: float, col: Color, skinf: Callable, lift := 0.004) -> void:
	var mp: Callable = Q._local(keys, ff, a0, y0)
	var rows := []
	var nu := 10
	var nv := 5
	for j in nv + 1:
		var v := float(j) / nv
		var ro := []
		for i in nu + 1:
			var u := float(i) / nu
			var e: float = minf(minf(u, 1.0 - u) * w / h, minf(v, 1.0 - v)) * 2.0
			var l: float = -0.0015 + (lift + 0.0015) * smoothstep(0.0, 0.5, e)
			var x: float = (u - 0.5) * w
			ro.append(mp.call(x, -v * h + x * tilt, l))
		rows.append(ro)
	var o: Vector3 = P._out(mp.call(0.0, 0.0, 0.0))
	Q._mesh(k, rows, false, func(_i, j, _p): return col.darkened(0.22) if j == nv else col.lightened(0.03 * float(j == 0)), func(_i, _j, p): return skinf.call(p), o)


# ------------------------------------------------------------------ Iwa Sodenashi (ref Iwabe Outfit: Ninja School Version + renk türevleri): gri atlet, baldıra inen önü açık kolsuz lacivert-petrol palto
## (dik yaka, göğüste fileto cep, belde kapaklı cepler, koyu kızıl astar), kahve kemer + gümüş toka, baldırda büzülen lacivert pantolon, sağ uylukta beyaz bantlı kılıf, ön kol sargıları
static func _kaya(k) -> void:
	var gr := Color(0.541, 0.541, 0.565)
	var pn := Color(0.141, 0.188, 0.29)
	var co := Color(0.11, 0.275, 0.337)
	var li := Color(0.33, 0.07, 0.1)
	var br := Color(0.3, 0.2, 0.13)
	var mt := Color(0.74, 0.75, 0.78)
	var wr := Color(0.9, 0.9, 0.88)
	var hb := Color(0.1, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	# atlet: önde V yaka, altında ten
	var ik := [P._kp(nk, N + 0.03, 0.002), P._kp(nk, N + 0.0, 0.008), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.007), P._kp(wa, H + 0.12, 0.009), P._kp(hp, H - 0.09, 0.01)]
	var vneck := func(p: Vector3) -> bool:
		var aw: float = absf(atan2(p.x, p.z))
		return p.y > lerpf(N - 0.1, N - 0.005, clampf(aw / 0.55, 0.0, 1.0))
	SE.body_layer(k, ik, 30, 48, func(_i, _j, p): return skc if vneck.call(p) else gr.darkened(0.04 * float(p.y < C - 0.1)))
	R._seat(k, R._seat_keys(k, b), func(_i, _j, _p): return pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = _bare_arm(k, sd)
		var sv: float = 0.8 if sd == "Left" else 2.6
		var kn: float = le["kn"]
		var pa: Callable = Y._jogger(k, le, pn, 0.014, 0.024, kn + 0.27, sv)
		# kol: çıplak, ön kolda beyaz sargı
		R._arm_skin(k, ar, 0.0)
		P._lt(k, ar, func(_s, _a): return 0.003, func(_s, _a, ins): return wr.darkened(0.3) if ins else wr.darkened(0.12), 0.6, 0.93, 10, 16)
		P._wraps(k, ar, 0.61, 0.92, 9, 0.006, 0.012, wr, 0.008)
		# sağ uyluk: siyah kılıf + üç beyaz bant
		if sd == "Right":
			var s0: float = kn * 0.42
			P._lt(k, le, func(s, a): return float(pa.call(float(s), float(a))) + 0.004, func(_s, _a, ins): return hb.darkened(0.3) if ins else hb, s0 - 0.05, s0 + 0.06, 6, 22)
			for i in 3:
				var s2: float = s0 - 0.03 + 0.03 * i
				Q._ring_on(k, le, s2, func(s, a): return float(pa.call(float(s), float(a))) + 0.004, 0.0065, wr, 0.002)
	# kemer + toka (palto açıklığında görünür)
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var bk2 := [P._kp(bl, H + 0.09, 0.024), P._kp(bl, H + 0.01, 0.026)]
	P._sash(k, bk2, H + 0.05, 0.018, 0.0, br, 0.1)
	var bf: Array = P._sa(bk2, 0.0, H + 0.05, 0.014)
	Q._buckle(k, bf[0], bf[1], 0.03, 0.026, mt, [["Hips", 0.5], ["Spine", 0.5]])
	# palto: kolsuz, önü açık, baldıra iner
	var hem: float = KN - 0.12
	var keys := [P._kp(nk, N + 0.012, 0.036), [N - 0.05, ch.x * 1.06, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.04), P._kp(wa, H + 0.12, 0.05), P._kp(hp, H - 0.04, 0.062),
		[KN + 0.05, hp.x + 0.115, hp.y + 0.085, hp.z - 0.125], [hem, hp.x + 0.14, hp.y + 0.09, hp.z - 0.16]]
	var csk := func(p): return K._coat_skin(k, p, hem)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.04 - y) / (H + 0.04 - hem), 0.0, 1.0)
		return smoothstep(0.4, 0.75, aw) * pow(t, 1.1) * (0.034 * sin(a * 6.0 + 0.9) + 0.015 * sin(a * 11.0 + 2.3)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 11.0) * smoothstep(N - 0.03, C - 0.04, y)
	var e_at := func(v: float) -> float:
		var y: float = lerpf(N + 0.012, hem, v)
		return lerpf(0.34, 0.52, smoothstep(C, hem, y)) - 0.14 * smoothstep(N - 0.06, N + 0.012, y)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 54, "na": 100, "rng": func(v): return Vector2(float(e_at.call(float(v))), TAU - float(e_at.call(float(v)))), "top": func(_a): return N + 0.012, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return co, "gain": 6.0, "th": 0.008, "inner": li, "skin": csk})
	_edge_band(k, cg["ea"], 0.009, 0.003, co.lightened(0.03), csk, 1.0)
	_edge_band(k, cg["eb"], 0.009, 0.003, co.lightened(0.03), csk, -1.0)
	P._bd(k, _yl(cg["hem"], 0.011), 0.006, 0.0022, co.lightened(0.05), false, csk)
	for sd in ["Left", "Right"]:
		P._armhole(k, P._limb(k, sd, false), 0.07, 0.016, 0.009, co.lightened(0.02))
	# cepler: sol göğüste fileto cep, belde iki kapaklı cep; yan ve arka dikiş
	var ffw := func(a, y): return ff.call(float(a), float(y))
	_flap(k, keys, ffw, 0.62, C + 0.01, 0.08, 0.014, -0.15, co.lightened(0.02), func(p): return k.torso_skin(p.y), 0.003)
	for sg in [1.0, -1.0]:
		_flap(k, keys, ffw, sg * 0.82, H - 0.0, 0.1, 0.03, sg * 0.06, co.lightened(0.02), csk, 0.0045)
		Q._run(k, keys, ffw, [Vector2(sg * 1.62, C - 0.08), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.02)], 0.0024, 0.0016, 0.0012, co.darkened(0.2), csk, 10)
	Q._run(k, keys, ffw, [Vector2(PI - 0.001, N - 0.02), Vector2(PI - 0.001, hem + 0.02)], 0.0024, 0.0016, 0.0012, co.darkened(0.2), csk, 14)
	# dik yaka: boynu saran, önü açık
	var q: float = Q._hq(k)
	var clk := [[N + 0.085 * q, nk.x + 0.03, nk.y + 0.034, nk.z - 0.038], [N + 0.03, nk.x + 0.034, nk.y + 0.036, nk.z - 0.04], [N - 0.005, nk.x + 0.042, nk.y + 0.04, nk.z - 0.045], [N - 0.045, nk.x + 0.06, nk.y + 0.05, nk.z - 0.06]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var cl: Dictionary = P._cl(k, {"keys": clk, "ny": 12, "na": 56, "rng": func(_v): return Vector2(0.5, TAU - 0.5), "top": func(a): return N + q * lerpf(0.07, 0.085, smoothstep(0.5, 1.6, absf(float(a)))), "hem": func(_a): return N - 0.04,
		"fold": func(a, y, _v): return 0.004 * sin(float(a) * 6.0 + float(y) * 20.0), "col": func(_a, _y, _v): return co.lightened(0.02), "inner": co.darkened(0.3), "skin": skt, "th": 0.007, "gain": 5.0})
	P._cord(k, cl["top"], 0.0045, co.lightened(0.04), false, skt)


# ------------------------------------------------------------------ Kara Koromo (ref Jigen Outfit + renk türevleri): baldıra inen beyaz sarma cübbe (sol kanat üstte, geniş eri bandı, kuşak altında önü açılır,
## içi lila astar), etek ucunda ve dirsek altında biten geniş kol ağzında siyah dikey şeritler, halkalı püsküllü kırmızı kuşak, sırtta gri Kara arması; içte kızıl
## dik yakalı gömlek + kırmızı kol ısıtıcı, siyah pantolon
static func _kabuk(k) -> void:
	var wh := Color(0.933, 0.933, 0.925)
	var bk := Color(0.094, 0.094, 0.11)
	var rd := Color(0.627, 0.118, 0.141)
	var lv := Color(0.8, 0.8, 0.9)
	var gy := Color(0.73, 0.76, 0.8)
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
	P._inner(k, b, func(_i, _j, _p): return wh.darkened(0.06), 0.006)
	X._neck(k, b, rd.darkened(0.25), 0.075, false)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.6 if sd == "Left" else 2.2
		var kn: float = le["kn"]
		K._pant(k, le, bk, 0.01, 0.012, 1.0, sv)
		# kızıl iç kol + ön kolda kırmızı ısıtıcı
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return rd.darkened(0.4) if ins else rd.darkened(0.2), 0.0, 0.6, 14, 16)
		var wm := func(s: float, a: float) -> float: return 0.009 + 0.004 * sin(a * 4.0 + s * 38.0 + sv) * smoothstep(0.62, 0.7, s) - 0.003 * smoothstep(0.93, 0.975, s)
		P._lt(k, ar, wm, func(s, a, ins): return rd.darkened(0.4) if ins else rd.darkened(0.12 * float(sin(float(a) * 4.0 + float(s) * 38.0 + sv) < -0.5)), 0.56, 0.975, 18, 18, 0.02)
	# cübbe: iki kanat; sol kanat sağın üstüne biner, kuşak altında iki kanat ayrılır
	var hem: float = lerpf(KN, F, 0.42)
	var top: float = N + 0.012
	var by: float = H + 0.07
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.036), P._kp(hp, H - 0.04, 0.058),
		[KN + 0.05, hp.x + 0.095, hp.y + 0.085, hp.z - 0.12], [hem, hp.x + 0.12, hp.y + 0.09, hp.z - 0.16]]
	var csk := func(p): return K._coat_skin(k, p, hem)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return smoothstep(0.2, 0.55, aw) * t * (0.034 * sin(a * 6.0 + 0.9) + 0.016 * sin(a * 11.0 + 2.3)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 11.0) * smoothstep(N - 0.03, C - 0.04, y)
	var eL := func(y: float) -> float:
		if y >= by:
			return lerpf(-0.24, 0.4, smoothstep(by, top, y))
		return lerpf(-0.24, 0.26, pow(smoothstep(by, hem, y), 0.7))
	var eR := func(y: float) -> float:
		if y >= by:
			return lerpf(0.24, -0.4, smoothstep(by, top, y))
		return lerpf(0.24, -0.26, pow(smoothstep(by, hem, y), 0.7))
	var wings := []
	for lf in [true, false]:
		var fold := func(a: float, y: float, _v: float) -> float:
			var f: float = ff.call(a, y)
			return f if lf else f - 0.02 * smoothstep(-0.8, -0.4, a) * smoothstep(by - 0.12, by, y)
		var g: Dictionary = P._cl(k, {"keys": keys, "ny": 60, "na": 58, "rng": func(v):
			var y: float = lerpf(top, hem, float(v))
			return Vector2(float(eL.call(y)), PI + 0.015) if lf else Vector2(-PI - 0.015, float(eR.call(y))),
			"top": func(_a): return top, "hem": func(_a): return hem, "fold": fold, "col": func(_a, _y, _v): return wh, "gain": 5.0, "th": 0.007, "inner": lv, "skin": csk})
		wings.append(g)
		# eri: geniş yaka bandı, kuşağa iner (alt kanadınki bindirmenin altında kalır)
		var ed: Array = g["ea"] if lf else g["eb"]
		var pts := []
		for q in ed:
			var y: float = (q as Vector3).y
			if y < by + 0.03:
				break
			if not lf and float(eR.call(y)) > float(eL.call(y)) - 0.05:
				break
			pts.append(q)
		if pts.size() >= 2:
			_edge_band(k, pts, 0.02, 0.005, wh.darkened(0.03), csk, 1.0 if lf else -1.0)
		P._bd(k, _yl(g["hem"], 0.008), 0.004, 0.0018, wh.darkened(0.1), false, csk)
	# etek ucunda siyah dikey şeritler (kalın / ince sırayla)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var i := 0
	var a := 0.34
	while a < TAU - 0.34:
		var aw: float = wrapf(a, -PI, PI)
		var wide: bool = i % 3 != 1
		Q._run(k, keys, ffw, [Vector2(aw, hem + 0.02), Vector2(aw, hem + 0.15)], 0.011 if wide else 0.006, 0.0022, 0.0016, bk, csk, 6)
		a += 0.3 if wide else 0.22
		i += 1
	# kuşak: kırmızı, önde kalın düğüm bloğu + beyaz halka + aşağı inen püskül
	var obk := [P._kp(wa, H + 0.13, 0.05), P._kp(wa, H + 0.0, 0.064)]
	P._sash(k, obk, by, 0.034, 0.004, rd, 0.12)
	var bf: Array = P._sa(obk, 0.0, by, 0.012)
	var c0: Vector3 = bf[0]
	var o0: Vector3 = bf[1]
	var hb := [["Hips", 0.5], ["Spine", 0.5]]
	P._boxr(k, c0, Vector3(0.052, 0, 0), Vector3(0, 0.034, 0), o0 * 0.008, rd.darkened(0.08), hb, 0.3)
	var ring := []
	for j in 28:
		var t := TAU * j / 28.0
		ring.append(c0 + o0 * 0.012 + Vector3(cos(t) * 0.022, sin(t) * 0.022, 0))
	P._tb(k, ring, func(_s, _a): return 0.0058, func(_s, aa, _p): return wh.darkened(0.12) if cos(float(aa)) < -0.3 else wh, func(_s, _p): return hb, 8, true)
	# püskül: halkadan inen ip, sargılı baş, uzun saçaklar (kumaşa oturur, bacaklarla hafif gider)
	var tsk := [["Hips", 0.8], ["LeftUpperLeg", 0.1], ["RightUpperLeg", 0.1]]
	var pt0: Vector3 = c0 + o0 * 0.014 + Vector3(0, -0.02, 0)
	var head: Vector3 = Vector3(0.0, H - 0.04, pt0.z + 0.006)
	P._cord(k, [pt0, pt0.lerp(head, 0.5) + Vector3(0, 0, 0.004), head], 0.004, wh, false, func(_p): return tsk)
	P._tb(k, [head + Vector3(0, 0.012, 0), head + Vector3(0, -0.004, 0), head + Vector3(0, -0.026, 0)], func(s, _a): return 0.009 + 0.004 * sin(float(s) * PI), func(s, aa, _p): return wh.darkened(0.1 * float(int(float(s) * 6.0) % 2)), func(_s, _p): return tsk, 12)
	for j in 9:
		var u: float = (float(j) / 8.0 - 0.5)
		var st: Vector3 = head + Vector3(u * 0.016, -0.024, 0.002 + 0.003 * cos(u * PI))
		var en: Vector3 = Vector3(u * 0.034, H - 0.27, st.z + 0.004 + 0.004 * cos(u * PI))
		P._tb(k, [st, st.lerp(en, 0.5), en], func(s, _a): return 0.0032 * (1.0 - 0.4 * float(s)), func(_s, _a, _p): return wh.darkened(0.06 * float(j % 2)), func(_s, _p): return tsk, 5)
	# kollar: dirsek altında biten geniş kol, ağızda siyah dikey şeritler, lila astar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.7 if sd == "Left" else 0.4
		var s1: float = 0.72
		var sf: Callable = _hang_sleeve(k, ar, wh, lv, 0.02, 0.05, 0.028, s1, sv)
		var L: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
		var n_b := 9
		for j in n_b:
			var aa: float = TAU * (float(j) + 0.5) / n_b - PI
			var pts := []
			var ou := []
			for m2 in 6:
				var s: float = lerpf(s1 - 0.11, s1 - 0.008, float(m2) / 5.0)
				var e: Array = Q._ls(ar, s, aa, float(sf.call(s, aa)) + 0.0015)
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, (0.011 if j % 3 != 1 else 0.006) * (1.0 + 0.6 * smoothstep(0.0, 0.05, float(sf.call(s1, aa)))), 0.0015, bk, false, func(_p): return P._lskin(ar, s1 - 0.05))
	# sırtta Kara arması: gri halka + üstte iki göz
	var yc: float = C - 0.03
	var tskn := func(p): return k.torso_skin(p.y)
	Q._circle(k, _back_mp(keys, 0.0, yc), 0.047, 0.0058, 0.003, gy, tskn, 48)
	for sx in [-1.0, 1.0]:
		Q._disc(k, _back_mp(keys, sx * 0.013, yc + 0.028), Vector3(0, 0, -1), 0.0072, 0.003, Callable(), func(_u, _v): return gy, tskn, 3, 16)
