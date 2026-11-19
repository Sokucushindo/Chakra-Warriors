extends RefCounted
## Elle modellenmiş setler, parti am: ss_kaya_striker_kurtarici, ss_kaya_striker_postaci, ss_lav_zirh, ss_murekkep_ceket, ss_pembe_kunoichi, ss_pembe_genc. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{rock_striker (Rock_2 turuncu, Rock_3 mavi), roshi_outfit, sai_outfit, sakura_outfit, sakura_outfit_young_ver}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), s (S), r (R), l (L), z (Z), aa (AA) dosyalarından; burada Iwa Striker ortak kesimi (iki türev) ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const V = preload("res://scripts/actors/set_el_v.gd")

const DONE := ["ss_kaya_striker_kurtarici", "ss_kaya_striker_postaci", "ss_lav_zirh", "ss_murekkep_ceket", "ss_pembe_kunoichi", "ss_pembe_genc"]

## 切 手 紙: kabartma çizgiler (birim kutu -1..1), etiket yazısı
const G_KIRI := [[-0.95, 0.15, -0.2, 0.35], [-0.6, 0.85, -0.6, -0.55], [-0.6, -0.55, -0.2, -0.72], [0.05, 0.62, 0.85, 0.62], [0.85, 0.62, 0.85, -0.78], [0.85, -0.78, 0.6, -0.62], [0.45, 0.62, 0.38, -0.05], [0.38, -0.05, 0.02, -0.85]]
const G_TE := [[0.6, 0.88, -0.5, 0.7], [-0.6, 0.38, 0.6, 0.38], [-0.78, 0.0, 0.78, 0.0], [0.0, 0.74, 0.0, -0.85], [0.0, -0.85, -0.22, -0.68]]
const G_KAMI := [[-0.55, 0.92, -0.85, 0.42], [-0.85, 0.42, -0.45, 0.48], [-0.42, 0.66, -0.88, -0.06], [-0.88, -0.06, -0.3, 0.0], [-0.6, 0.0, -0.6, -0.9], [-0.84, -0.4, -0.92, -0.66], [-0.36, -0.4, -0.26, -0.62],
	[0.8, 0.9, 0.08, 0.74], [0.1, 0.74, 0.1, -0.82], [0.1, 0.18, 0.92, 0.18], [0.42, 0.74, 0.56, -0.38], [0.56, -0.38, 0.92, -0.86], [0.1, -0.82, 0.36, -0.6]]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_kaya_striker_kurtarici": _iwa(k, 0)
		"ss_kaya_striker_postaci": _iwa(k, 1)
		"ss_lav_zirh": _roshi(k)
		"ss_murekkep_ceket": _sai(k)
		"ss_pembe_kunoichi": _sakura(k)
		"ss_pembe_genc": _sakura_genc(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Yüzeyde dikdörtgen plaka (etiket / plaka): mp yerel eşleme, w/h yarı ölçü
static func _rect(k, mp: Callable, out: Vector3, w: float, h: float, lift: float, col: Color, skinf: Callable, edge := Color(0, 0, 0, 0)) -> void:
	var asp: float = h / w
	var rf := func(th: float) -> float: return 1.0 / maxf(absf(cos(th)), absf(sin(th)) / asp)
	Q._disc(k, mp, out, w, lift, rf, func(u, v):
		if edge.a > 0.0 and maxf(absf(float(u)), absf(float(v))) > 0.82:
			return edge
		return col, skinf, 3, 28)


## Kabartma yazı: strokes birim kutuda, s ölçek (metre)
static func _glyph(k, mp: Callable, cx: float, cy: float, s: float, strokes: Array, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	for q in strokes:
		R._lstrip(k, mp, [Vector2(cx + float(q[0]) * s, cy + float(q[1]) * s), Vector2(cx + float(q[2]) * s, cy + float(q[3]) * s)], hw, lift, 0.0012, col, skinf)


## Uyluk kılıfı: iki bant + kutu, s0 uyluk boyunda yer (etek ucunun altında kalsın diye ayarlanır)
static func _holster(k, l: Dictionary, pf: Callable, st: Color, box: Color, s0: float) -> void:
	for s in [s0, s0 + 0.075]:
		k.wrap_turn(P._lp(l, s), P._ld(l, s), P._lr(l, s) + float(pf.call(s, 0.0)) + 0.007, 0.0115, 0.0, st, P._lskin(l, s))
	var a: float = J._outer_a(l, s0 + 0.038, Vector3(-1.0, 0.0, 0.25))
	var e: Array = J._lsurf(l, s0 + 0.038, a, float(pf.call(s0 + 0.038, a)) + 0.022)
	var o: Vector3 = e[1]
	var d: Vector3 = P._ld(l, s0)
	var bo := [[String(l["sd"]) + "UpperLeg", 1.0]]
	P._boxr(k, e[0], o.cross(d).normalized() * 0.033, -d * 0.052, o * 0.017, box, bo)
	P._boxr(k, (e[0] as Vector3) + o * 0.016 - d * 0.03, o.cross(d).normalized() * 0.035, -d * 0.022, o * 0.005, box.darkened(0.14), bo, 0.2)
	P._boxr(k, (e[0] as Vector3) + o * 0.022 - d * 0.012, o.cross(d).normalized() * 0.0065, -d * 0.0065, o * 0.002, st, bo, 0.4)


# ------------------------------------------------------------------ Iwa Striker türevleri ortak kesimi (ref Shinobi Striker "Rock Striker" Rock_2 / Rock_3): kolsuz sarmal gi (sol kanat üstte, V yaka kuşağa iner,
## eteğin bindirme kenarı sağ önde dikey), boynu saran şal, solda tek kısa kol, geniş kuşak, önde iki kese + altında basamaklı koyu önlük, dizin altında biten pantolon + file çorap,
## sağ uylukta iki bantlı kılıf. v=0 Kurtarıcı: turuncu gi + beyaz biyeler, sol göğüste çift ok, siyah dik şal, siyah kol + iki beyaz bant, kuşakta beyaz şerit, beyaz çerçeveli siyah keseler
## + turuncu çekme dilleri, turuncu uyluk bantları. v=1 Postacı: mavi gi (etek kenarı + biye beyaz), beyaz kapüşonlu bol şal, beyaz kol, siyah kuşak, beyaz biyeli mavi keseler + altın süs,
## altın iple asılı 切手 / 手紙 etiketleri, mavi uyluk bantları, beyaz bilek bandı
static func _iwa(k, v: int) -> void:
	var gc: Color = [Color(0.88, 0.36, 0.11), Color(0.15, 0.31, 0.72)][v]
	var wh := Color(0.93, 0.93, 0.91)
	var sc: Color = [Color(0.1, 0.095, 0.1), Color(0.9, 0.9, 0.92)][v]
	var slc: Color = [Color(0.085, 0.085, 0.095), Color(0.92, 0.92, 0.93)][v]
	var pn := Color(0.075, 0.075, 0.085)
	var bk := Color(0.07, 0.07, 0.08)
	var stc: Color = [Color(0.86, 0.33, 0.1), Color(0.16, 0.3, 0.7)][v]
	var apc: Color = [Color(0.075, 0.07, 0.075), Color(0.08, 0.13, 0.36)][v]
	var gd := Color(0.9, 0.7, 0.22)
	var nt := Color(0.13, 0.12, 0.13)
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
	var nsk := func(p): return Q._nsk(k, p)
	# V yakanın içi: şal gi'ye sokulur (yakada şal rengi görünür)
	P._inner(k, b, func(_i, _j, p): return sc if p.y > H + 0.05 else sc.darkened(0.25), 0.006)
	K._seat(k, b, pn)
	# pantolon: dizin altında biten manşet, altında file çorap; sağ uylukta kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.3
		P._lt(k, le, func(_s, _a): return 0.0015, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc.lerp(nt, 0.12), kn + 0.06, 1.0, 16, 16)
		P._net_limb(k, le, kn + 0.1, 0.975, 0.0034, 12, 0.032, 0.0016, nt)
		var cuff: float = kn + 0.135
		var pa: Callable = K._pant(k, le, pn, 0.014, 0.022, cuff, sv)
		Q._ring_on(k, le, cuff - 0.011, func(s, a): return float(pa.call(s, a)) + 0.0015, 0.012, pn.lightened(0.05), 0.0035)
		if v == 1:   # beyaz bilek bandı (bot ağzının üstünde)
			P._lt(k, le, func(s, a): return 0.0058 + 0.0016 * sin(clampf((float(s) - 0.925) / 0.065, 0.0, 1.0) * PI) + 0.0008 * sin(float(a) * 6.0), func(_s, a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.1 if sin(float(a) * 6.0) < -0.5 else 0.0), 0.925, 0.99, 5, 20)
		if sd == "Right":
			_holster(k, le, pa, stc, apc.darkened(0.1) if v == 1 else bk, kn * 0.66)
	# kollar: sağ açık (kol oyuğu biyeli), solda tek kısa kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		if sd == "Right":
			P._bare(k, AA._bare_arm(k, sd), skc)
			continue
		P._bare(k, AA._bare_arm(k, sd), skc, ak - 0.08, 1.0)
		var s1: float = ak - 0.035
		var bag: float = [0.007, 0.012][v]
		var sf := func(s: float, a: float) -> float: return 0.011 + bag * smoothstep(0.06, s1, s) + 0.0035 * P._lf(s, a, 1.4) * smoothstep(0.08, 0.2, s) + 0.003 * exp(-pow((s - s1 + 0.04) / 0.04, 2.0)) * sin(a * 5.0 + 0.7)
		P._lt(k, ar, sf, func(s, a, ins): return slc.darkened(0.35) if ins else P._fs(slc, float(sf.call(float(s), float(a))) - 0.011 - bag * smoothstep(0.06, s1, float(s)), 12.0), 0.0, s1, 24, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, slc.darkened(0.4), s1 - 0.06, s1 - 0.004, 5, 22)
		Q._ring_on(k, ar, s1 - 0.01, func(s, a): return float(sf.call(float(s), float(a))) + 0.0008, 0.01, slc.darkened(0.08) if v == 0 else slc.darkened(0.06), 0.0028)
		if v == 0:   # iki beyaz bant
			for ss in [0.2, 0.3]:
				Q._ring_on(k, ar, ss, func(s, a): return float(sf.call(float(s), float(a))) + 0.0012, 0.017, wh, 0.003)
	# gi: kolsuz, sol kanat sağın üstüne biner; V yaka kuşakta kapanır, altında bindirme kenarı sağ önde iner
	var hem: float = lerpf(H, KN, 0.33)
	var top: float = N + 0.006
	var keys := [P._kp(nk, top, 0.028), [N - 0.055, ch.x * 1.01, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.04, 0.042), [hem, hp.x + 0.07, hp.y + 0.08, hp.z - 0.07]]
	var fold := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 6.0 + 0.5) + 0.007 * sin(a * 11.0 + 1.4)) + 0.006 * sin(a * 5.0 + y * 13.0) * smoothstep(C, H + 0.06, y) + 0.004 * sin(a * 4.0 - y * 19.0) * smoothstep(C - 0.03, N - 0.04, y)
	var kff := func(a, y): return fold.call(float(a), float(y))
	var gsk := func(p): return Q._csk(k, p, hem, 0.008)
	var yv: float = H + 0.09   # V'nin dibi (kuşağın üstü)
	var eL := func(y: float) -> float:
		if y >= yv:
			return lerpf(-0.6, 0.38, inverse_lerp(yv, top, y))
		return lerpf(-0.6, -0.7, smoothstep(yv, hem, y))
	var eR := func(y: float) -> float:
		if y >= yv:
			return lerpf(0.52, -0.38, inverse_lerp(yv, top, y))
		return 0.52
	var gcol := func(_a, y, _v): return gc.darkened(0.06 * smoothstep(H, hem, float(y)))
	var gR: Dictionary = P._cl(k, {"keys": keys, "ny": 36, "na": 50, "rng": func(vv): return Vector2(-PI - 0.015, float(eR.call(lerpf(top, hem, float(vv))))), "top": func(_a): return top, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return float(fold.call(float(a), float(y))) - 0.02 * smoothstep(-0.8, -0.5, float(a)), "col": gcol, "gain": 5.0, "th": 0.005, "inner": gc.darkened(0.35), "skin": gsk})
	var gL: Dictionary = P._cl(k, {"keys": keys, "ny": 36, "na": 56, "rng": func(vv): return Vector2(float(eL.call(lerpf(top, hem, float(vv)))), PI + 0.015), "top": func(_a): return top, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return fold.call(float(a), float(y)), "col": gcol, "gain": 5.0, "th": 0.005, "inner": gc.darkened(0.35), "skin": gsk})
	# biyeler: üst kanadın kenarı, alt kanadın görünen kenarı, etek ucu, kol oyuğu
	var edc: Color = wh if v == 0 else gc.darkened(0.32)
	var lp := []
	var lo := []
	for p: Vector3 in gL["ea"]:
		if v == 1 and p.y < yv - 0.01:
			lo.append(p)
		else:
			lp.append(p)
	P._bd(k, lp, 0.005 if v == 0 else 0.0026, 0.0028, edc, false, gsk, 0.0)
	if v == 1:
		P._bd(k, lo, 0.0055, 0.0028, wh, false, gsk, 0.0)
	var rp := []
	for p: Vector3 in gR["eb"]:
		if float(eR.call(p.y)) < float(eL.call(p.y)) - 0.04:
			rp.append(p)
	if rp.size() >= 2:
		P._bd(k, rp, 0.005 if v == 0 else 0.0026, 0.0028, edc, false, gsk, 0.0)
	for g in [gL, gR]:
		var hm := []
		for p: Vector3 in g["hem"]:
			hm.append(p + Vector3(0, 0.009, 0))
		P._bd(k, hm, 0.0085, 0.003, wh, false, gsk)
	P._hole(k, keys, -1.0, C + 0.005, 0.42, 0.085, 0.0042, 0.003, edc if v == 0 else gc.darkened(0.25))
	# arka orta dikiş (iki kanadın birleştiği yer)
	Q._run(k, keys, kff, [Vector2(PI - 0.002, top - 0.012), Vector2(PI - 0.002, hem + 0.018)], 0.0016, 0.0035, 0.0012, gc.darkened(0.3), gsk, 16)
	# kuşak: geniş siyah bez, Kurtarıcı'da ortasında beyaz şerit
	var by: float = H + 0.065
	var bkk: Array = []
	for e in keys:
		bkk.append([e[0], float(e[1]) + 0.008, float(e[2]) + 0.01, float(e[3]) - 0.008])
	P._sash(k, bkk, by, 0.034, 0.003, bk.lightened(0.04), 0.1)
	if v == 0:
		P._sash(k, bkk, by - 0.002, 0.0125, 0.0075, wh, 0.06)
	# önde basamaklı koyu önlük (keselerin arkası): kuşaktan etek ucuna yakın
	var ay0: float = by - 0.03
	var ahf := func(a: float) -> float: return lerpf(ay0, hem, lerpf(0.7, 0.9, smoothstep(0.08, 0.16, a)))
	var ap: Dictionary = P._cl(k, {"keys": keys, "ny": 14, "na": 22, "rng": func(_v): return Vector2(-0.14, 0.74), "top": func(_a): return ay0, "hem": ahf, "fold": func(a, y, _v): return fold.call(float(a), float(y)), "lift": 0.0035,
		"col": func(_a, _y, _v): return apc, "gain": 6.0, "th": 0.003, "inner": apc.darkened(0.3), "skin": gsk})
	P._cord(k, ap["ea"], 0.0018, apc.darkened(0.3), false, gsk)
	P._cord(k, ap["eb"], 0.0018, apc.darkened(0.3), false, gsk)
	P._cord(k, ap["hem"], 0.0018, apc.darkened(0.3), false, gsk)
	if v == 0:   # alt basamakta koyu kızıl iç parça
		P._cl(k, {"keys": keys, "ny": 4, "na": 8, "rng": func(_v): return Vector2(0.3, 0.66), "top": func(_a): return lerpf(ay0, hem, 0.75), "hem": func(_a): return lerpf(ay0, hem, 0.87), "fold": func(a, y, _v): return fold.call(float(a), float(y)), "lift": 0.0055,
			"col": func(_a, _y, _v): return Color(0.34, 0.07, 0.06), "gain": 6.0, "th": 0.0, "skin": gsk})
	# iki kese: kuşaktan sarkar
	for i in 2:
		var a0: float = [0.16, 0.5][i]
		var py: float = by - 0.076
		var pe: Array = Q._spt(keys, kff, a0, py, 0.017)
		var o: Vector3 = pe[1]
		var ux: Vector3 = Vector3.UP.cross(o).normalized()
		var bo: Array = gsk.call(pe[0])
		var c0: Vector3 = pe[0]
		var pc: Color = bk if v == 0 else gc.darkened(0.08)
		P._boxr(k, c0, ux * 0.025, Vector3.UP * 0.036, o * 0.0125, pc, bo, 0.22)
		var ft: Vector3 = c0 + o * 0.0128 + Vector3.UP * 0.012
		if v == 0:   # beyaz çerçeve (kapak kenarı) + ara çubuk + turuncu çekme dili
			var fr := [ft + ux * -0.019 + Vector3.UP * -0.012, ft + ux * -0.019 + Vector3.UP * 0.022, ft + ux * 0.019 + Vector3.UP * 0.022, ft + ux * 0.019 + Vector3.UP * -0.012]
			P._cord(k, fr, 0.0028, wh, false, func(_p): return bo, 0.0, 6)
			P._boxr(k, ft + Vector3.UP * 0.0, ux * 0.02, Vector3.UP * 0.0032, o * 0.003, wh, bo, 0.3)
			P._boxr(k, ft + o * 0.002 - Vector3.UP * 0.014, ux * 0.0045, Vector3.UP * 0.011, o * 0.003, stc, bo, 0.35)
		else:   # beyaz biyeli kapak + altın kıvrık süsler + ip + etiket
			P._boxr(k, c0 + o * 0.0115 + Vector3.UP * 0.02, ux * 0.026, Vector3.UP * 0.017, o * 0.0035, pc.lightened(0.04), bo, 0.3)
			var fr2 := [ft + ux * -0.023 + Vector3.UP * 0.024, ft + ux * -0.023 + Vector3.UP * -0.006, ft + ux * 0.0 + Vector3.UP * -0.009, ft + ux * 0.023 + Vector3.UP * -0.006, ft + ux * 0.023 + Vector3.UP * 0.024]
			P._cord(k, fr2, 0.0022, wh, false, func(_p): return bo, 0.0, 6)
			for sg in [1.0, -1.0]:
				var cc: Vector3 = ft + ux * sg * 0.013 + Vector3.UP * -0.001 + o * 0.0035
				var cp := []
				for j in 9:
					var th: float = float(j) / 8.0 * 4.2
					cp.append(cc + ux * sg * cos(th) * 0.0048 * (1.0 - 0.12 * th) + Vector3.UP * sin(th) * 0.0048 * (1.0 - 0.12 * th))
				P._cord(k, cp, 0.0012, gd, false, func(_p): return bo, 0.0, 5)
			# altın ip: kapağın ortasından etikete, önlüğün üstünde durur
			var ty: float = py - 0.062 - 0.012 * float(i)
			var a1: float = a0 + 0.01
			var ct: Array = [ft + o * 0.004 + Vector3.UP * -0.008, Q._spt(keys, kff, a1, py - 0.042, 0.0105)[0], Q._spt(keys, kff, a1, ty + 0.026, 0.0085)[0]]
			P._cord(k, ct, 0.0016, gd, false, gsk, 0.0, 5)
			var mp: Callable = Q._local(keys, kff, a1, ty)
			var to: Vector3 = Q._spt(keys, kff, a1, ty)[1]
			_rect(k, mp, to, 0.016, 0.025, 0.0068, Color(0.95, 0.95, 0.96), gsk, Color(0.55, 0.6, 0.72))
			var gl: Array = [G_KIRI, G_TE] if i == 0 else [G_TE, G_KAMI]
			_glyph(k, mp, 0.0, 0.011, 0.0085, gl[0], 0.0011, 0.0085, Color(0.18, 0.24, 0.48), gsk)
			_glyph(k, mp, 0.0, -0.011, 0.0085, gl[1], 0.0011, 0.0085, Color(0.18, 0.24, 0.48), gsk)
	if v == 0:   # sol göğüste çift ok (beyaz üstte, sarı altta) + ince turuncu çizgi
		var mpc: Callable = Q._local(keys, kff, 0.56, C + 0.035)
		R._lstrip(k, mpc, [Vector2(-0.022, 0.012), Vector2(0.0, -0.004), Vector2(0.022, 0.012)], 0.0034, 0.0028, 0.0016, wh, tsk)
		R._lstrip(k, mpc, [Vector2(-0.022, 0.0), Vector2(0.0, -0.016), Vector2(0.022, 0.0)], 0.0034, 0.0028, 0.0016, Color(0.96, 0.78, 0.2), tsk)
		R._lstrip(k, mpc, [Vector2(-0.018, -0.026), Vector2(0.024, -0.026)], 0.0012, 0.0026, 0.0012, gc.darkened(0.4), tsk)
	# şal: boynu saran rulo, önde soldan sağa bindirilip gi yakasına girer (Postacı: bol kapüşonlu, kıvrımlı)
	var q: float = Q._hq(k)
	var bulk: float = [0.0, 1.0][v]
	var ytop: float = N + lerpf(0.046, 0.04, bulk) * q
	var cw := [[ytop, nk.x + 0.03 + 0.008 * bulk, nk.y + 0.032 + 0.01 * bulk, nk.z - 0.03 - 0.008 * bulk], [N + 0.012 * q, nk.x + 0.04 + 0.016 * bulk, nk.y + 0.04 + 0.02 * bulk, nk.z - 0.038 - 0.016 * bulk],
		[N - 0.035, ch.x * 0.8, ch.y * 0.96, ch.z * 0.96], [N - 0.085, ch.x * 0.98, ch.y * 1.0, ch.z * 1.04]]
	var hmf := func(a: float) -> float: return N - 0.075 - 0.02 * maxf(0.0, cos(a))
	var cf := func(a: float, y: float, vv: float) -> float:
		return (0.02 + 0.03 * bulk) * sin(vv * PI) * (0.7 + 0.3 * cos(a)) + (0.006 + 0.014 * bulk) * sin(a * 5.0 + 0.8 + y * 9.0) * vv + 0.004 * sin(a * 9.0 + y * 20.0)
	var cg: Dictionary = P._cl(k, {"keys": cw, "ny": 14, "na": 64, "top": func(_a): return ytop, "hem": hmf, "fold": cf, "col": func(_a, _y, _v): return sc, "gain": 6.0 if v == 0 else 4.0, "th": 0.007, "inner": sc.darkened(0.2), "skin": nsk})
	P._cord(k, cg["top"], 0.005 + 0.002 * bulk, sc.lightened(0.04) if v == 0 else sc.darkened(0.04), true, nsk)
	var fgc: Dictionary = P._cl(k, {"keys": cw, "ny": 14, "na": 14, "rng": func(vv): return Vector2(-0.46 + 0.28 * float(vv), 0.24 + 0.06 * float(vv)), "top": func(_a): return ytop - 0.004, "hem": func(a): return N - 0.11 + 0.035 * float(a), "fold": cf, "lift": 0.006,
		"col": func(_a, _y, _v): return sc.lightened(0.03) if v == 0 else sc, "gain": 6.0, "th": 0.005, "inner": sc.darkened(0.2), "skin": nsk})
	P._cord(k, fgc["ea"], 0.0032, sc.darkened(0.18) if v == 0 else sc.darkened(0.12), false, nsk)
	if v == 1:   # sırtta yatan kapüşon: omuz arasında kıvrımlı kat
		var hk := [[N + 0.03, nk.x + 0.06, nk.y + 0.04, nk.z - 0.05], [N - 0.04, ch.x * 0.82, ch.y * 0.9, ch.z * 1.06], [C + 0.0, ch.x * 0.72, ch.y * 0.9, ch.z * 1.08]]
		var hf := func(a: float, y: float, vv: float) -> float: return 0.05 * sin(vv * PI * 0.9) + 0.016 * sin(a * 6.0 + y * 14.0) * vv
		var hd: Dictionary = P._cl(k, {"keys": hk, "ny": 12, "na": 26, "rng": func(vv): return Vector2(PI - 0.95 + 0.25 * float(vv), PI + 0.95 - 0.25 * float(vv)), "top": func(_a): return N + 0.03, "hem": func(a): return C + 0.01 - 0.03 * cos(float(a) - PI),
			"fold": hf, "col": func(_a, _y, _v): return sc, "gain": 4.0, "th": 0.006, "inner": sc.darkened(0.15), "skin": nsk})
		P._cord(k, hd["hem"], 0.004, sc.darkened(0.06), false, tsk)


# ------------------------------------------------------------------ Yōgan Yoroi (ref Shinobi Striker "Roshi Outfit" mor): uyluk ortasına inen mor sarmal kimono (koyu mor geniş yaka bandı, sol kanat üstte),
## yakada file iç gömlek, göğüsten bele kahve göğüs zırhı (önde ve arkada levha, omuz ipleri), lacivert kuşak, iki kalçada sarkan üç sıralı kahve plaka,
## ön kol ortasında biten bol kimono kolu + altında lacivert kolluk, baldırda lacivert konçlu bota toplanan bol mor pantolon
static func _roshi(k) -> void:
	var pu := Color(0.6, 0.14, 0.48)
	var pd := Color(0.29, 0.1, 0.3)
	var br := Color(0.39, 0.27, 0.17)
	var brd := Color(0.24, 0.16, 0.1)
	var nv := Color(0.14, 0.14, 0.3)
	var ng := Color(0.52, 0.52, 0.55)
	var nt := Color(0.16, 0.16, 0.18)
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
	# file iç gömlek: yakada görünür
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return ng, 0.004)
	P._net_patch(k, ik, func(a, y): return absf(float(a)) < 0.62 and float(y) > C - 0.14, -0.66, 0.66, C - 0.15, N + 0.06, 0.016, 0.0011, 0.0032, nt)
	K._seat(k, b, pu.darkened(0.2))
	# bol pantolon: baldırda lacivert bot konçuna toplanır
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		Q._baggy(k, le, pu, nv, 0.016, 0.034, 0.74, 0.8 if sd == "Left" else 2.1)
		Q._ring_on(k, le, 0.94, func(_s, _a): return 0.0085, 0.006, nv.darkened(0.2), 0.002)
	# kollar: kimono kolunun altında mor iç kol + lacivert kolluk (dikine fitilli), açık el
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.6 if sd == "Left" else 1.8
		P._bare(k, AA._bare_arm(k, sd), skc, 0.9, 1.0)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return pu.darkened(0.45) if ins else pu.darkened(0.15), en * 0.55, 0.72, 14, 14)
		var gf := func(s: float, a: float) -> float: return 0.0055 + 0.0022 * pow(absf(sin(a * 4.0 + 0.4)), 6.0) + 0.002 * smoothstep(0.85, 0.66, s) + 0.002 * smoothstep(0.92, 0.975, s)
		P._lt(k, ar, gf, func(s, a, ins):
			if ins:
				return nv.darkened(0.4)
			return nv.lightened(0.08 * pow(absf(sin(float(a) * 4.0 + 0.4)), 6.0)).darkened(0.12 * float(float(s) > 0.955)), 0.64, 0.975, 16, 24, 0.012)
		# geniş kol: ön kol ortasında biter, ağzı kolluğa doğru kapanır (koşuda boş halka görünmez)
		M._wide(k, ar, func(s: float) -> float: return P._lr(ar, s) + 0.018 + 0.012 * smoothstep(0.08, 0.45, s), func(s: float) -> float: return 0.016 * smoothstep(0.3, 0.7, s),
			func(s: float, a: float) -> float: return 0.035 * sin(a * 4.0 + s * 9.0 + sv) + 0.018 * sin(a * 7.0 - s * 13.0), func(s: float, a: float, ins: bool) -> Color:
				if ins:
					return pu.darkened(0.3)
				var f: float = 0.6 * sin(a * 4.0 + s * 9.0 + sv) + 0.4 * sin(a * 7.0 - s * 13.0)
				return P._fs(pu, f * 0.03, 5.0), 0.78, 0.55, 0.032, 30, 30)
	# kimono: sol kanat üstte, V yaka göğüs zırhının altına iner; uyluk ortasında biter
	var hem: float = lerpf(H, KN, 0.42)
	var top: float = N + 0.012
	var keys := [P._kp(nk, top, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.98, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.04), P._kp(hp, H - 0.04, 0.05), [hem, hp.x + 0.085, hp.y + 0.075, hp.z - 0.085]]
	var fold := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		return t * (0.026 * sin(a * 6.0 + 0.7) + 0.012 * sin(a * 11.0 + 1.9)) + 0.007 * (1.0 - t) * sin(a * 5.0 + y * 14.0)
	var gsk := func(p): return T._ksk(k, p, hem)
	var yv: float = C - 0.07
	var eL := func(y: float) -> float:
		if y >= yv:
			return lerpf(-0.5, 0.3, inverse_lerp(yv, top, y))
		return lerpf(-0.5, -0.62, smoothstep(yv, hem, y))
	var eR := func(y: float) -> float:
		if y >= yv:
			return lerpf(0.5, -0.3, inverse_lerp(yv, top, y))
		return 0.5
	var gcol := func(_a, _y, _v): return pu
	var gR: Dictionary = P._cl(k, {"keys": keys, "ny": 36, "na": 50, "rng": func(vv): return Vector2(-PI - 0.015, float(eR.call(lerpf(top, hem, float(vv))))), "top": func(_a): return top, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return float(fold.call(float(a), float(y))) - 0.02 * smoothstep(-0.7, -0.4, float(a)), "col": gcol, "gain": 4.5, "th": 0.005, "inner": pu.darkened(0.35), "skin": gsk})
	var gL: Dictionary = P._cl(k, {"keys": keys, "ny": 36, "na": 56, "rng": func(vv): return Vector2(float(eL.call(lerpf(top, hem, float(vv)))), PI + 0.015), "top": func(_a): return top, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return fold.call(float(a), float(y)), "col": gcol, "gain": 4.5, "th": 0.005, "inner": pu.darkened(0.35), "skin": gsk})
	# geniş koyu mor yaka bandı: iki kanadın görünen kenarı boyunca
	var lp := []
	for p: Vector3 in gL["ea"]:
		if p.y > yv - 0.02:
			lp.append(p + Vector3(0.012, 0.0, 0.0))
	P._bd(k, lp, 0.016, 0.0045, pd, false, gsk, 0.1)
	var rp := []
	for p: Vector3 in gR["eb"]:
		if float(eR.call(p.y)) < float(eL.call(p.y)) - 0.05:
			rp.append(p + Vector3(-0.012, 0.0, 0.0))
	if rp.size() >= 2:
		P._bd(k, rp, 0.016, 0.0045, pd, false, gsk, 0.1)
	Q._run(k, keys, func(a, y): return fold.call(float(a), float(y)), [Vector2(PI - 0.002, top - 0.012), Vector2(PI - 0.002, hem + 0.016)], 0.0016, 0.004, 0.0012, pu.darkened(0.3), gsk, 16)
	for g in [gL, gR]:
		var hm := []
		for p: Vector3 in g["hem"]:
			hm.append(p + Vector3(0, 0.008, 0))
		P._bd(k, hm, 0.006, 0.0026, pu.darkened(0.12), false, gsk)
	# lacivert kuşak
	var by: float = H + 0.06
	var bkk: Array = []
	for e in keys:
		bkk.append([e[0], float(e[1]) + 0.008, float(e[2]) + 0.01, float(e[3]) - 0.008])
	P._sash(k, bkk, by, 0.024, 0.003, nv, 0.12)
	# göğüs zırhı: önde ve arkada kenarı kalın levha, alta doğru genişler
	var ak: Array = []
	for e in keys:
		ak.append([e[0], float(e[1]) + 0.016, float(e[2]) + 0.02, float(e[3]) - 0.018])
	var pt: float = C + 0.07
	var pb: float = by + 0.02
	for side in [0.0, PI]:
		var awf := func(vv: float) -> float: return lerpf(0.8, 1.06, vv) if side == 0.0 else lerpf(0.86, 1.02, vv)
		L._shell(k, func(u, vv):
			var a: float = side + float(awf.call(float(vv))) * (2.0 * float(u) - 1.0)
			return L._sa(ak, a, lerpf(pt, pb, float(vv)), 0.0)[0], func(u, vv):
			return L._sa(ak, side + float(awf.call(float(vv))) * (2.0 * float(u) - 1.0), lerpf(pt, pb, float(vv)))[1], 28, 10, 0.013, func(_u, vv, e):
			return brd if e or float(vv) < 0.04 or float(vv) > 0.96 else br.darkened(0.1 * float(vv)).lightened(0.05 * (1.0 - float(vv))), func(_u, _v, p): return k.torso_skin(p.y))
	# omuz ipleri: ön levhanın üst köşesinden omuzdan arkaya
	for sg in [1.0, -1.0]:
		L._over(k, ak, sg * 0.62, pt - 0.004, sg * (PI - 0.66), pt - 0.004, 0.009, 0.004, 0.0035, brd)
	# kalçada sarkan plakalar: iki yanda üç sıra
	for sg in [1.0, -1.0]:
		L._tasset(k, b, {"y0": by - 0.012, "ac": sg * 1.18, "aw": 0.27, "n": 3, "h": 0.082, "ov": 0.014, "flare": 0.14, "add": 0.082, "col": br, "trim": brd, "lace": brd.darkened(0.35), "th": 0.008})


# ------------------------------------------------------------------ Sumi Uwagi (ref Shinobi Striker "Sai Outfit" lacivert): gri fermuarlı dik yakalı gömlek (önde T biçiminde görünür), kemerin hemen üstünde biten önü açık kısa lacivert ceket
## (uzun kollu, omuz önünde kırmızı şerit), iki beyaz kayışlı kemer + çift kare toka, belin arkasında yatay büyük tomar, sağ uylukta iki beyaz bantlı kılıf, baldır ortasında biten lacivert pantolon
static func _sai(k) -> void:
	var gy := Color(0.47, 0.48, 0.53)
	var jk := Color(0.14, 0.14, 0.245)
	var rd := Color(0.58, 0.12, 0.14)
	var pn := Color(0.13, 0.13, 0.225)
	var wh := Color(0.93, 0.93, 0.94)
	var mt := Color(0.72, 0.72, 0.75)
	var sr := Color(0.4, 0.09, 0.08)
	var so := Color(0.9, 0.52, 0.16)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var hp: Vector3 = b["hp"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	var hsk := [["Hips", 1.0]]
	# gömlek: kemerin altına girer
	var ik: Array = Z._tk(k, b, H - 0.01, 0.01, 0.2)
	var igf := func(a: float, y: float) -> float: return 0.006 * sin(a * 6.0 + y * 21.0) * smoothstep(C - 0.05, H + 0.08, y) + 0.008 * exp(-pow((y - (H + 0.065)) / 0.03, 2.0)) * (0.6 + 0.4 * sin(a * 7.0))
	var igff := func(a, y): return igf.call(float(a), float(y))
	P._cl(k, {"keys": ik, "ny": 28, "na": 72, "top": func(_a): return N + 0.01, "hem": func(_a): return H - 0.01, "fold": func(a, y, _v): return igf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return gy, "gain": 7.0, "th": 0.004, "inner": gy.darkened(0.35), "skin": tsk})
	Z._stand(k, b, 0.056, 0.008, gy)
	# fermuar: yakanın tepesinden kemere, çekme dili göğüste
	var q: float = Q._hq(k)
	var zp := []
	var zo := []
	for i in 44:
		var y: float = lerpf(N + 0.054 * q, H + 0.05, float(i) / 43.0)
		var e: Array = Q._spt(ik, igff, 0.0, y, 0.0028) if y <= N + 0.01 else [Vector3(0, y, float(b["nk"].y) + 0.0175), Vector3(0, 0, 1)]
		zp.append(e[0])
		zo.append(e[1])
	k.strip(zp, zo, 0.0028, 0.0016, gy.darkened(0.35), false, nsk)
	var zt: Array = Q._spt(ik, igff, 0.0, C + 0.06, 0.0055)
	P._boxr(k, zt[0], Vector3(0.004, 0, 0), Vector3(0, 0.01, 0), (zt[1] as Vector3) * 0.0025, mt, k.torso_skin(C + 0.06), 0.3)
	# pantolon: baldır ortasında biter, altı ten; sağ uylukta kılıf
	K._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.3 if sd == "Left" else 0.4
		var s1: float = kn + 0.2
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		var pa: Callable = K._pant(k, le, pn, 0.014, 0.012, s1, sv)
		Q._ring_on(k, le, s1 - 0.012, func(s, a): return float(pa.call(s, a)) + 0.0012, 0.012, pn.lightened(0.04), 0.003)
		if sd == "Right":
			J._holster(k, le, pa, wh, pn.darkened(0.2))
	# kemer: iki beyaz kayış, arası boş; önde çift kare toka
	var wbk := [P._kp(k.M(H + 0.07, 0.3), H + 0.07, 0.012), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.014)]
	for yb in [H + 0.046, H + 0.02]:
		V._belt(k, wbk, yb, 0.0, 0.0072, 0.0035, wh, 0.0, 80)
	for sg in [1.0, -1.0]:
		var e2: Array = Q._spt(wbk, Callable(), sg * 0.075, H + 0.033, 0.009)
		var o2: Vector3 = e2[1]
		var r2: Vector3 = Vector3.UP.cross(o2).normalized()
		P._boxr(k, e2[0], r2 * 0.012, Vector3.UP * 0.019, o2 * 0.004, wh, hsk, 0.25)
		P._boxr(k, (e2[0] as Vector3) + o2 * 0.004, r2 * 0.005, Vector3.UP * 0.011, o2 * 0.0015, wh.darkened(0.3), hsk, 0.3)
	# kollar: bileğe uzanan dar kol + manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.7 if sd == "Left" else 2.0
		var s1 := 0.925
		var sf := func(s: float, a: float) -> float:
			return 0.015 + 0.008 * smoothstep(0.1, 0.5, s) - 0.004 * smoothstep(0.75, 0.9, s) + 0.003 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins): return jk.darkened(0.3) if ins else P._fs(jk, float(sf.call(float(s), float(a))) - 0.02, 12.0), 0.0, s1, 34, 22, 0.02)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, jk.darkened(0.4), s1 - 0.06, s1 - 0.004, 5, 22)
		Q._ring_on(k, ar, s1 - 0.012, func(s, a): return float(sf.call(float(s), float(a))) + 0.0008, 0.011, jk.lightened(0.04), 0.0025)
	# kısa ceket: önü açık, kenarlar dikey, kemerin hemen üstünde biter
	var hem: float = H + 0.085
	var keys: Array = Z._tk(k, b, hem, 0.024, 0.4)
	var ff := func(a: float, y: float) -> float:
		return smoothstep(0.35, 0.8, absf(a)) * (0.007 * sin(a * 5.0 + 0.3 + y * 6.0) * smoothstep(C, hem, y) + 0.004 * sin(a * 9.0 - y * 15.0))
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var jrg := func(vv) -> Vector2:
		var e: float = lerpf(0.7, 0.33, smoothstep(0.0, 0.32, float(vv)))
		return Vector2(e, TAU - e)
	var jg: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 84, "rng": jrg, "top": func(_a): return N + 0.006, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return jk, "gain": 6.0, "th": 0.007, "inner": jk.darkened(0.35), "skin": tsk})
	for ed in [jg["ea"], jg["eb"]]:
		P._bd(k, ed, 0.004, 0.0024, jk.darkened(0.2), false, tsk, 0.0)
	P._bd(k, K._yl(jg["hem"], 0.009), 0.0075, 0.0025, jk.lightened(0.03), false, tsk)
	P._cord(k, jg["top"], 0.0042, jk.darkened(0.12), false, nsk)
	# omuz önünde kırmızı şerit (omuz dikişinden göğse)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ffw, [Vector2(sg * 0.7, N - 0.016), Vector2(sg * 0.68, C + 0.04)], 0.0115, 0.003, 0.0024, rd, tsk, 8)
	# arka orta dikiş + omuz dikişleri
	Q._run(k, keys, ffw, [Vector2(PI - 0.001, N + 0.0), Vector2(PI - 0.001, hem + 0.012)], 0.0015, 0.003, 0.001, jk.darkened(0.3), tsk, 12)
	# belin arkasında yatay tomar: koyu kızıl rulo, uçlarda turuncu kenar + kâğıt göbeği, iki beyaz bağ
	var zc: float = float(hp.z) - 0.078
	var yc: float = H - 0.035
	var hl: float = 0.172
	var rr: float = 0.064
	var xs := [-hl - 0.004, -hl, -hl + 0.004, -hl + 0.016, -hl + 0.03, -0.1, 0.0, 0.1, hl - 0.03, hl - 0.016, hl - 0.004, hl, hl + 0.004]
	var pts := []
	var rad := []
	for x in xs:
		pts.append(Vector3(float(x), yc, zc))
		var ex: float = hl - absf(float(x))
		rad.append(0.004 if ex < -0.001 else (rr * 0.55 if ex < 0.002 else (rr * 1.04 if ex < 0.02 else rr)))
	P._tb(k, pts, func(s, _a): return float(rad[clampi(int(round(float(s) * 12.0)), 0, 12)]), func(s, a, _p):
		var ex: float = hl - absf(float(xs[clampi(int(round(float(s) * 12.0)), 0, 12)]))
		if ex < 0.0035:
			return Color(0.88, 0.84, 0.72) if sin(float(a) * 9.0) > 0.0 else Color(0.78, 0.72, 0.58)
		if ex < 0.022:
			return so if ex > 0.006 else so.darkened(0.2)
		return sr.darkened(0.12 if sin(float(a) * 3.0 + 0.6) < -0.4 else 0.0), func(_s, _p): return hsk, 20)
	for sg in [1.0, -1.0]:
		k.wrap_turn(Vector3(sg * 0.11, yc, zc), Vector3(1, 0, 0), rr + 0.003, 0.009, 0.0, wh, hsk)
		var bt: Array = Q._spt(wbk, Callable(), PI - sg * 0.38, H + 0.02, 0.006)
		k.strip([bt[0], Vector3(sg * 0.11, yc + rr * 0.6, zc + rr * 0.85)], [bt[1], Vector3(0, 0.6, -0.8).normalized()], 0.008, 0.002, wh, false, func(_p): return hsk)


# ------------------------------------------------------------------ Sakura Kunoichi (ref Shinobi Striker "Sakura Outfit"): kısa dik yakalı kolsuz kırmızı üst (yakadan inip sol yana kıvrılan fermuar), pembe dirseklik, siyah eldiven,
## iki yanı yırtmaçlı pembe panel etek (önde kısa fermuar, kalçalarda kese / klips), altında siyah şort, sağ uylukta beyaz bant + koyu kılıf, açık uyluk (siyah diz çizmesi ayak parçası)
static func _sakura(k) -> void:
	var rd := Color(0.66, 0.12, 0.15)
	var pk := Color(0.92, 0.71, 0.77)
	var bk := Color(0.09, 0.09, 0.105)
	var wh := Color(0.93, 0.93, 0.94)
	var mt := Color(0.74, 0.74, 0.77)
	var brn := Color(0.42, 0.28, 0.18)
	var nv := Color(0.13, 0.14, 0.22)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._skin_torso(k, b, H - 0.02)
	# kollar: ten + pembe dirseklik + siyah eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.5 if sd == "Left" else 1.7
		Z._arm_bare(k, ar)
		var e0: float = en - 0.15
		var e1: float = en + 0.13
		var ef := func(s: float, a: float) -> float:
			return 0.007 + 0.0035 * exp(-pow((s - en) / 0.06, 2.0)) + 0.0025 * P._lf(s, a, sv) * smoothstep(e0 + 0.02, e0 + 0.06, s) * smoothstep(e1 - 0.02, e1 - 0.06, s) - 0.003 * (smoothstep(e0 + 0.03, e0, s) + smoothstep(e1 - 0.03, e1, s))
		P._lt(k, ar, ef, func(s, a, ins): return pk.darkened(0.35) if ins else P._fs(pk, float(ef.call(float(s), float(a))) - 0.008, 14.0), e0, e1, 18, 20, 0.02)
		for ss in [e0 + 0.012, e1 - 0.012]:
			Q._ring_on(k, ar, ss, func(s, a): return float(ef.call(float(s), float(a))) + 0.0008, 0.009, pk.darkened(0.1), 0.0022)
		Z._glove_full(k, sd, bk)
		P._lt(k, ar, func(s, _a): return 0.0042 + 0.0016 * smoothstep(0.9, 0.87, float(s)), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.865, 0.985, 6, 18)
	# siyah şort + açık uyluk, sağda beyaz bant + kılıf
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.2
		var s1: float = kn * 0.44
		var ad: Callable = R._short_leg(k, le, bk, s1, 0.011, 0.008, sv)
		R._hem_roll(k, le, ad, s1, bk.lightened(0.05), 0.022, 0.002)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		if sd == "Right":
			J._holster(k, le, func(_s, _a): return 0.0, wh, nv)
	# kolsuz üst: omuzu örter, belde etek bandının üstüne biner
	var hemT: float = H + 0.035
	var keys: Array = Z._tk(k, b, hemT, 0.011, 0.75)
	var ch: Vector3 = b["ch"]
	keys[1] = [keys[1][0], ch.x * 0.9 + 0.011, ch.y * 0.86 + 0.011, ch.z * 0.94 - 0.011]
	var ff := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.04, hemT, y) + 0.0025 * sin(a * 11.0 + y * 20.0)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var tg: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 96, "top": func(_a): return N + 0.012, "hem": func(_a): return hemT, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 6.0, "th": 0.005, "inner": rd.darkened(0.4), "skin": tsk})
	P._bd(k, K._yl(tg["hem"], 0.007), 0.0035, 0.0018, rd.darkened(0.18), true, tsk)
	for sg in [1.0, -1.0]:
		P._hole(k, keys, sg, C + 0.01, 0.4, 0.078, 0.0034, 0.0025, rd.darkened(0.22))
	Z._stand(k, b, 0.036, 0.006, rd)
	# fermuar: yakadan göğse dik, sonra sol yana kıvrılır
	var zc := [Vector2(0.0, N + 0.004), Vector2(0.0, C + 0.0), Vector2(0.12, C - 0.07), Vector2(0.42, H + 0.13), Vector2(0.62, hemT + 0.012)]
	Q._run(k, keys, ffw, zc, 0.0042, 0.0022, 0.0018, rd.darkened(0.12), tsk, 8)
	Q._run(k, keys, ffw, zc, 0.0016, 0.0042, 0.0012, mt, tsk, 8)
	var zt: Array = Q._spt(keys, ffw, 0.0, N - 0.012, 0.0055)
	P._boxr(k, zt[0], Vector3(0.0042, 0, 0), Vector3(0, 0.01, 0), (zt[1] as Vector3) * 0.0025, mt, k.torso_skin(N - 0.012), 0.3)
	# panel etek: önde ve arkada, yanlarda yırtmaç (aşağı doğru açılır); önde kısa fermuar
	var ehem: float = lerpf(H, KN, 0.3)
	var hp: Vector3 = b["hp"]
	var ey0: float = H + 0.06
	var wm: Vector3 = k.M(ey0, 0.3)
	var ekeys := [[ey0, wm.x + 0.016, wm.y + 0.016, wm.z - 0.016], [H - 0.04, hp.x + 0.05, hp.y + 0.05, hp.z - 0.048], [ehem, hp.x + 0.07, hp.y + 0.066, hp.z - 0.064]]
	var ef2 := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - ehem), 0.0, 1.0)
		return t * (0.01 * sin(a * 5.0 + 0.6) + 0.005 * sin(a * 11.0 + 1.3))
	var esk := func(p): return Z._psk(k, p, ehem)
	var bsk := func(p): return T._ksk(k, p, ehem)
	for ctr in [0.0, PI]:
		var psk: Callable = esk if ctr == 0.0 else bsk
		var w0: float = 1.56 if ctr == 0.0 else 1.6
		var w1: float = 1.42 if ctr == 0.0 else 1.47
		var pg: Dictionary = P._cl(k, {"keys": ekeys, "ny": 22, "na": 56, "rng": func(vv): return Vector2(ctr - lerpf(w0, w1, smoothstep(0.0, 0.6, float(vv))), ctr + lerpf(w0, w1, smoothstep(0.0, 0.6, float(vv)))), "top": func(_a): return ey0, "hem": func(_a): return ehem,
			"fold": func(a, y, _v): return ef2.call(float(a), float(y)), "col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.006, "inner": pk.darkened(0.35), "skin": psk})
		for ed in [pg["ea"], pg["eb"]]:
			P._cord(k, ed, 0.0026, pk.darkened(0.14), false, psk)
		P._bd(k, K._yl(pg["hem"], 0.008), 0.003, 0.0015, pk.darkened(0.16), false, psk)
	var bkey := [[ey0 + 0.02, wm.x + 0.022, wm.y + 0.022, wm.z - 0.022], [ey0 - 0.04, wm.x + 0.026, wm.y + 0.026, wm.z - 0.026]]
	V._belt(k, bkey, ey0 - 0.008, 0.0, 0.012, 0.004, pk.darkened(0.05), 0.0, 96)
	var ef2w := func(a, y): return ef2.call(float(a), float(y))
	Q._run(k, ekeys, ef2w, [Vector2(0.0, ey0 - 0.02), Vector2(0.0, ey0 - 0.085)], 0.0016, 0.004, 0.0012, mt, esk, 6)
	var zs: Array = Q._spt(ekeys, ef2w, 0.0, ey0 - 0.03, 0.0055)
	P._boxr(k, zs[0], Vector3(0.0038, 0, 0), Vector3(0, 0.009, 0), (zs[1] as Vector3) * 0.0022, mt, [["Hips", 1.0]], 0.3)
	# kalçada klipsler: sağda beyaz klips, solda kahve kese
	var hb := [["Hips", 1.0]]
	var c1: Array = Q._spt(bkey, Callable(), -1.25, ey0 - 0.02, 0.008)
	P._boxr(k, c1[0], Vector3.UP.cross(c1[1]).normalized() * 0.008, Vector3.UP * 0.018, (c1[1] as Vector3) * 0.004, wh, hb, 0.3)
	var c2: Array = Q._spt(bkey, Callable(), 1.32, ey0 - 0.035, 0.02)
	var o2: Vector3 = c2[1]
	P._boxr(k, c2[0], Vector3.UP.cross(o2).normalized() * 0.022, Vector3.UP * 0.03, o2 * 0.012, brn, hb, 0.3)
	P._boxr(k, (c2[0] as Vector3) + o2 * 0.012 + Vector3.UP * 0.014, Vector3.UP.cross(o2).normalized() * 0.023, Vector3.UP * 0.014, o2 * 0.004, brn.darkened(0.15), hb, 0.3)
	P._boxr(k, (c2[0] as Vector3) + o2 * 0.016 + Vector3.UP * 0.008, Vector3.UP.cross(o2).normalized() * 0.006, Vector3.UP * 0.006, o2 * 0.002, wh, hb, 0.4)
	P._cur_hem = ehem


# ------------------------------------------------------------------ Sakura Kodomo (ref Shinobi Striker "Sakura Outfit (Young Ver.)"): dize inen kırmızı çin elbisesi (önde V çentikli dik yaka, yakadan göğse inip sol yana kıvrılan fermuar,
## iki yanda kalçadan yırtmaç, yırtmaç kenarı ve etek ucu beyaz biyeli, önde beyaz halka), beyaz ağızlı kısa kol + omuzda beyaz yay, altında lacivert şort, sağ uylukta lacivert kılıf
static func _sakura_genc(k) -> void:
	var rd := Color(0.54, 0.11, 0.2)
	var wh := Color(0.94, 0.93, 0.92)
	var nv := Color(0.12, 0.14, 0.28)
	var mt := Color(0.74, 0.74, 0.77)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var nsk := func(p): return Q._nsk(k, p)
	# lacivert şort + açık bacak, sağ uylukta kılıf
	var bl: Vector3 = k.M(H + 0.03, 0.3)
	R._seat(k, [P._kp(bl, H + 0.03, 0.002), P._kp(hp, H - 0.05, 0.012), [H - 0.15, hp.x * 0.8, hp.y * 0.8, hp.z * 0.8]], func(_i, _j, _p): return nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		var s1: float = kn * 0.48
		var ad: Callable = R._short_leg(k, le, nv, s1, 0.01, 0.006, sv)
		R._hem_roll(k, le, ad, s1, nv.lightened(0.05), 0.02, 0.002)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
	# kısa kol: beyaz ağız biyesi, omuzda beyaz yay; ön kol açık
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.3 if sd == "Left" else 1.6
		Z._arm_bare(k, ar, 0.26)
		var s1 := 0.35
		var sf := func(s: float, a: float) -> float:
			return 0.013 + 0.011 * smoothstep(0.04, s1, s) + 0.003 * P._lf(s, a, sv) * smoothstep(0.08, 0.2, s) - P._lr(ar, s) * 0.35 * (1.0 - smoothstep(0.0, 0.16, s))
		P._lt(k, ar, sf, func(s, a, ins): return rd.darkened(0.4) if ins else P._fs(rd, float(sf.call(float(s), float(a))) - 0.013 - 0.011 * smoothstep(0.04, s1, float(s)), 12.0), 0.0, s1, 22, 24, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, rd.darkened(0.45), s1 - 0.06, s1 - 0.004, 5, 24)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, s1 - 0.026, s1 + 0.001, 3, 24)
		var oa: float = J._outer_a(ar, 0.15, Vector3(float(ar["sg"]), 0.35, 0.0).normalized())
		var mp: Callable = R._lmap(ar, sf, 0.15, oa)
		var arc := []
		for i in 13:
			var th: float = lerpf(0.55, 1.45, float(i) / 12.0) * PI
			arc.append(Vector2(0.012 + cos(th) * 0.028, sin(th) * 0.028))
		R._lstrip(k, mp, arc, 0.0034, 0.0022, 0.0016, wh, func(_p): return P._lskin(ar, 0.15))
	# elbise: tek yüzey, iki yanda kalçadan inen yırtmaç (gerçek açıklık)
	var hem: float = KN + 0.025
	var ys: float = H - 0.035
	var keys: Array = Z._tk(k, b, H - 0.04, 0.012, 0.7)
	keys[1] = [keys[1][0], ch.x * 0.92 + 0.012, ch.y * 0.86 + 0.012, ch.z * 0.94 - 0.012]
	for e in keys:
		if float(e[0]) < H + 0.07:
			var g: float = 0.026 * smoothstep(H + 0.07, H - 0.02, float(e[0]))
			e[1] = float(e[1]) + g
			e[2] = float(e[2]) + g
			e[3] = float(e[3]) - g
	keys.append([hem, hp.x + 0.07, hp.y + 0.064, hp.z - 0.068])
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.014 * sin(a * 5.0 + 0.4) + 0.006 * sin(a * 9.0 + 1.1)) + 0.004 * sin(a * 7.0 + y * 15.0) * smoothstep(N - 0.02, C - 0.06, y) * smoothstep(H - 0.02, H + 0.08, y)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var dsk := func(p): return Z._gsk(k, p, hem, 0.06)
	var gw := func(y: float) -> float: return lerpf(0.035, 0.085, clampf((ys - y) / (ys - hem), 0.0, 1.0))
	var topf := func(a: float) -> float: return N + 0.004 - 0.03 * exp(-pow(a / 0.26, 2.0))
	S._clh(k, {"keys": keys, "ny": 46, "na": 112, "rng": func(_v): return Vector2(-PI, PI), "top": topf, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 6.0, "th": 0.005, "inner": rd.darkened(0.4), "skin": dsk}, func(a, y):
		return float(y) < ys and absf(absf(wrapf(float(a), -PI, PI)) - PI * 0.5) < float(gw.call(float(y))))
	# yırtmaç kenarı + üst ucu: beyaz biye (U), etek ucu biyesi (önde ve arkada ayrı)
	for sg in [1.0, -1.0]:
		var ctrl := []
		var n := 14
		for j in n + 1:
			var y: float = lerpf(hem + 0.006, ys - 0.004, float(j) / n)
			ctrl.append(Vector2(sg * (PI * 0.5 - float(gw.call(y)) - 0.012), y))
		ctrl.append(Vector2(sg * PI * 0.5, ys + 0.012))
		for j in range(n, -1, -1):
			var y: float = lerpf(hem + 0.006, ys - 0.004, float(j) / n)
			ctrl.append(Vector2(sg * (PI * 0.5 + float(gw.call(y)) + 0.012), y))
		Q._run(k, keys, ffw, ctrl, 0.0045, 0.0018, 0.0018, wh, dsk, 2)
	for ctr in [0.0, PI]:
		var w: float = PI * 0.5 - float(gw.call(hem)) - 0.004
		var hm := []
		for i in 41:
			hm.append(Vector2(ctr + lerpf(-w, w, float(i) / 40.0), hem + 0.008))
		Q._run(k, keys, ffw, hm, 0.006, 0.0016, 0.0018, wh, dsk, 1)
	# önde beyaz halka
	var yr: float = lerpf(H, hem, 0.62)
	var rsk: Array = dsk.call(Q._spt(keys, ffw, -0.3, yr)[0])
	Q._circle(k, Q._local(keys, ffw, -0.3, yr), 0.042, 0.0068, 0.0055, wh, func(_p): return rsk, 48)
	# fermuar: yakadan göğse, sonra sol yana kıvrılıp yan dikişten yırtmaca
	var zc := [Vector2(0.0, N - 0.026), Vector2(0.0, C + 0.01), Vector2(0.22, C - 0.08), Vector2(0.95, H + 0.12), Vector2(PI * 0.5 - 0.1, H + 0.03), Vector2(PI * 0.5 - 0.1, ys + 0.02)]
	Q._run(k, keys, ffw, zc, 0.0042, 0.0016, 0.0016, rd.darkened(0.15), dsk, 8)
	Q._run(k, keys, ffw, zc, 0.0015, 0.0034, 0.0012, mt, dsk, 8)
	var zt: Array = Q._spt(keys, ffw, 0.0, N - 0.04, 0.005)
	P._boxr(k, zt[0], Vector3(0.0038, 0, 0), Vector3(0, 0.009, 0), (zt[1] as Vector3) * 0.0022, mt, k.torso_skin(N - 0.04), 0.3)
	# önde çentikli dik yaka
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + 0.036 * q, 0.004, 0.007), P._kp(nk, N + 0.012 * q, 0.008), P._kp(nk, N - 0.018, 0.014)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 56, "rng": func(_v): return Vector2(0.3, TAU - 0.3), "top": func(_a): return N + 0.036 * q, "hem": func(_a): return N - 0.016,
		"col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.005, "inner": rd.darkened(0.35), "skin": nsk})
	P._cord(k, cg["top"], 0.003, rd.darkened(0.12), false, nsk)
	P._cur_hem = hem
