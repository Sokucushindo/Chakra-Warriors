extends RefCounted
## Elle modellenmiş setler, parti al: ss_maske_pelerin, ss_gozluk_genc, ss_on_kuyruk, ss_tas_yasli, ss_yilan_sanin, ss_kaya_striker. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{obito_outfit, obito_outfit_gaiden_ver, obito_outfit_ten_tails_ver, ohnoki_outfit, orochimaru_outfit, rock_striker (Rock_1)}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), s (S), t (T), m (M), aa (AA), ab (AB), ag (AG), o (O) dosyalarından; burada bu setlere özgü parçalar.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AB = preload("res://scripts/actors/set_el_ab.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const O = preload("res://scripts/actors/set_el_o.gd")
const AH = preload("res://scripts/actors/set_el_ah.gd")

const DONE := ["ss_maske_pelerin", "ss_gozluk_genc", "ss_on_kuyruk", "ss_tas_yasli", "ss_yilan_sanin", "ss_kaya_striker"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_maske_pelerin": _kamen(k)
		"ss_yilan_sanin": _hebi_sannin(k)
		"ss_kaya_striker": _iwa_striker(k)
		"ss_gozluk_genc": _goguru(k)
		"ss_on_kuyruk": _jubi(k)
		"ss_tas_yasli": _ronin_iwa(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Yırtık kumaş ucu: açıya göre düzensiz dişler (tekrarsız)
static func _jag(a: float, sd: float, n := 7.0) -> float:
	return 0.5 + 0.32 * sin(a * n + sd) + 0.18 * sin(a * n * 2.3 + sd * 1.7) + 0.12 * absf(sin(a * n * 0.5 + sd * 0.4))


## Yüzeye oturan çerçeve + iç çizgiler (toka, plaka işareti): mp(u, v, kalkış) yerel eşleme, strokes [[u0, v0, u1, v1]...] metre
static func _strokes(k, mp: Callable, o: Vector3, strokes: Array, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	for st in strokes:
		var pts := []
		var ou := []
		for i in 4:
			var t := float(i) / 3.0
			pts.append(mp.call(lerpf(float(st[0]), float(st[2]), t), lerpf(float(st[1]), float(st[3]), t), lift))
			ou.append(o)
		k.strip(pts, ou, hw, 0.0016, col, false, skinf)


# ------------------------------------------------------------------ Kamen Gaitō (ref Shinobi Striker "Obito Outfit"): baldıra inen koyu mor cübbe (çeneye çıkan huni yaka, içi taba astar),
## sağ kol omuzdan yırtılıp kopmuş (yırtık diş kenar), altta açık kol: omuzda ve bilekte beyaz Zetsu dokusu; sol geniş kol (taba astar), kahve-siyah eldivenler,
## belde dolgulu beyaz obi + üstünde açık lavanta kemer (I biçimli beyaz toka), obiden aşağı önü dar açık etek (beyaz biye, taba astar), sırtta Uchiha arması,
## belin arkasında verev kın (sarı-beyaz sargılarla bağlı), koyu pantolon + beyaz bacak koruyucu sargı
static func _kamen(k) -> void:
	var pu := Color(0.19, 0.17, 0.45)
	var tn := Color(0.72, 0.55, 0.3)
	var wh := Color(0.91, 0.9, 0.93)
	var lv := Color(0.6, 0.56, 0.86)
	var gl := Color(0.22, 0.2, 0.2)
	var pn := Color(0.1, 0.1, 0.12)
	var lg := Color(0.8, 0.79, 0.86)
	var bw := Color(0.86, 0.82, 0.62)
	var skc: Color = Q._skc(k)
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
	AG._mad_base(k, b, pu.darkened(0.45), pn, lg)
	K._seat(k, b, pn)
	# cübbe: göğüste kapalı (sol kanat sağın üstüne), obinin altından önü dar açılır
	var hem: float = lerpf(KN, F, 0.52)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.042), P._kp(hp, H - 0.04, 0.05),
		[KN + 0.05, hp.x + 0.11, hp.y + 0.095, hp.z - 0.14], [hem, hp.x + 0.13, hp.y + 0.1, hp.z - 0.175]]
	var y0: float = H + 0.0
	var e_of := func(y: float) -> float: return 0.02 + 0.085 * pow(clampf((y0 - y) / (y0 - hem), 0.0, 1.0), 0.8)
	var cl_of := func(y: float) -> float: return 0.2 * smoothstep(y0 - 0.03, y0 + 0.06, y)
	var au := func(y: float) -> float: return -float(e_of.call(y)) + float(cl_of.call(y))
	var ao := func(y: float) -> float: return float(e_of.call(y)) - float(cl_of.call(y))
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fe: float = smoothstep(0.08, 0.4, aw)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var flat: float = 1.0 - 0.9 * exp(-pow((aw - PI) / 0.45, 2.0)) * (1.0 - smoothstep(H - 0.02, H - 0.1, y))
		var sk: float = pow(t, 0.9) * ((0.034 + 0.014 * bkf) * sin(a * 7.0 + 0.6) + 0.016 * sin(a * 13.0 + 1.9))
		var up: float = (1.0 - t) * 0.006 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y)
		return fe * flat * (sk + up)
	var csk := func(p): return AB._lsk(k, p, hem, 0.008)
	var r: Dictionary = AG._robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": au, "ao": ao, "ff": ff, "col": func(_a, _y): return pu, "lin": tn.darkened(0.1), "skin": csk,
		"th": 0.008, "ny": 56, "na": 104, "olift": 0.008, "gain": 5.0})
	AG._edge(k, AA._yl(r["hem"], 0.009), 0.005, 0.002, pu.lightened(0.05), csk)
	var ea := []
	var eb := []
	for j in r["ea"].size():
		var q: Vector3 = r["ea"][j]
		if q.y < y0 - 0.03:
			ea.append(q)
			eb.append(r["eb"][j])
	AG._edge(k, ea, 0.0052, 0.0026, wh, csk, -0.0045)
	AG._edge(k, eb, 0.0052, 0.0026, wh, csk, 0.0045)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.58, C - 0.04), Vector2(sg * 1.57, H), Vector2(sg * 1.55, hem + 0.016)], 0.0022, 0.0014, 0.0011, pu.darkened(0.2), csk, 12)
	# huni yaka: çeneye çıkar, içi taba
	AG._mad_collar(k, b, pu, tn, 0.125, 0.1, 0.022)
	# sol geniş kol (taba astar) + eldiven
	var arl: Dictionary = P._limb(k, "Left", false)
	AA._hang_sleeve(k, arl, pu, tn, 0.02, 0.036, 0.024, 0.9, 1.5)
	P._lt(k, arl, func(_s, _a): return 0.005, func(_s, _a, ins): return pn.darkened(0.3) if ins else pn, 0.45, 0.9, 12, 16)
	AG._glove(k, "Left", arl, gl)
	# sağ kol: açık ten, omuzda ve bilekte beyaz Zetsu dokusu, omuzda yırtılmış kol kökü
	var arr: Dictionary = AA._bare_arm(k, "Right")
	P._bare(k, arr, skc, 0.0, 0.9)
	S._lte(k, arr, func(_s, _a): return 0.0028, func(_s, a, ins): return wh.darkened(0.25) if ins else wh.darkened(0.04 * sin(float(a) * 5.0)), 0.0, func(a): return 0.17 + 0.07 * _jag(float(a), 1.3, 5.0), 18, 22)
	J._lta(k, arr, func(_s, _a): return 0.0028, func(_s, a, ins): return wh.darkened(0.25) if ins else wh.darkened(0.04 * sin(float(a) * 4.0)), func(a): return 0.7 - 0.06 * _jag(float(a), 0.4, 4.0), 0.9, 12, 22)
	AG._glove(k, "Right", arr, gl)
	S._lte(k, arr, func(s, a): return 0.012 + 0.03 * smoothstep(0.04, 0.16, float(s)) * (0.6 + 0.4 * sin(float(a) * 3.0 + 1.0)), func(_s, _a, ins): return pu.darkened(0.35) if ins else pu.darkened(0.05),
		0.0, func(a): return 0.06 + 0.1 * _jag(float(a), 2.1, 6.0), 14, 26)
	# obi: dolgulu beyaz bant, ortasında lavanta kemer + I biçimli toka
	var obk: Array = []
	for e in keys:
		obk.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.008, float(e[3]) - 0.006])
	var by: float = H + 0.075
	P._sash(k, obk, by, 0.055, 0.004, wh.darkened(0.04), 0.08)
	for yy in [by + 0.04, by - 0.04]:
		P._sash(k, obk, yy, 0.016, 0.011, wh, 0.04)
	var lbk: Array = []
	for e in obk:
		lbk.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.014, float(e[3]) - 0.012])
	P._sash(k, lbk, by, 0.015, 0.002, lv, 0.06)
	var bsk: Array = k.torso_skin(by)
	var bf: Array = P._fp(lbk, 0.0, by, true, 0.016)
	var bo: Vector3 = bf[1]
	P._boxr(k, (bf[0] as Vector3) + bo * 0.003, Vector3(0.026, 0, 0), Vector3(0, 0.02, 0), bo * 0.0045, wh, bsk, 0.2)
	var mp := func(u: float, v: float, l: float) -> Vector3: return (bf[0] as Vector3) + bo * (0.0075 + l) + Vector3(u, v, 0.0)
	_strokes(k, mp, bo, [[-0.02, 0.015, 0.02, 0.015], [0.02, 0.015, 0.02, -0.015], [0.02, -0.015, -0.02, -0.015], [-0.02, -0.015, -0.02, 0.015],
		[-0.011, 0.008, 0.011, 0.008], [-0.011, -0.008, 0.011, -0.008], [0.0, 0.008, 0.0, -0.008]], 0.0018, 0.0, pu.darkened(0.2), func(_p): return bsk)
	# sırtta Uchiha arması
	AG._uchiwa(k, keys, C - 0.05, 0.072, pu.darkened(0.5))
	# belin arkasında verev kın: obinin üstünde, sargılarla bağlı
	var kb: Array = []
	for e in obk:
		kb.append([e[0], float(e[1]) + 0.03, float(e[2]) + 0.03, float(e[3]) - 0.034])
	var shp := []
	for i in 13:
		var t := float(i) / 12.0
		var x: float = lerpf(-0.17, 0.16, t)
		var y: float = lerpf(by + 0.13, by - 0.02, t)
		shp.append(P._fp(kb, x, y, false, 0.0)[0])
	P._tb(k, shp, func(s, a): return 0.016 * (1.0 + 0.18 * cos(float(a))) * (1.0 - 0.2 * float(s)), func(s, _a, _p): return Color(0.12, 0.1, 0.1) if float(s) > 0.06 else Color(0.3, 0.26, 0.2), func(_s, p): return k.torso_skin(maxf(float(p.y), H + 0.02)), 10)
	for ii in [3, 9]:
		var c0: Vector3 = shp[ii]
		var dd: Vector3 = ((shp[ii + 1] as Vector3) - (shp[ii - 1] as Vector3)).normalized()
		for w in 2:
			k.wrap_turn(c0 + dd * (0.012 * w - 0.006), dd, 0.019, 0.0065, 0.0, bw.darkened(0.06 * w), k.torso_skin(maxf(c0.y, H + 0.02)))


# ------------------------------------------------------------------ Hebi Sannin (ref Shinobi Striker "Orochimaru Outfit"): siyah balıkçı yaka + uzun siyah kollu iç, üstünde U yakalı kısa kollu krem tunik
## (önü ve arkası dize yakın iner, yanları kalçadan yırtmaçlı), belde kalın mor burgu ip + sırtta büyük fiyonk, gri-lacivert bol pantolon, baldırda beyaz sargı
static func _hebi_sannin(k) -> void:
	var cr := Color(0.9, 0.85, 0.7)
	var bk := Color(0.1, 0.1, 0.11)
	var pu := Color(0.48, 0.33, 0.73)
	var pn := Color(0.26, 0.3, 0.43)
	var wr := Color(0.9, 0.89, 0.86)
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
	# siyah iç + balıkçı yaka
	P._inner(k, b, func(_i, _j, _p): return bk, 0.006)
	O._turtle(k, nk, bk, 0.075)
	K._seat(k, b, pn)
	# pantolon: dizaltında toplanır, baldırda beyaz sargı
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.4 if sd == "Left" else 2.7
		var tk: float = kn + 0.16
		var ad: Callable = AB._baggy(k, le, pn, 0.014, 0.036, tk, sv, 0.28, 0.2)
		AG._leg_wrap(k, le, ad, tk - 0.01, 0.985, 12, wr)
	# uzun siyah kollar (iç giysi)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.2
		var sl := func(s: float, a: float) -> float: return 0.006 + 0.0028 * P._lf(s, a, sv) * smoothstep(0.3, 0.5, s) + 0.005 * exp(-pow((s - ak) / 0.07, 2.0)) * sin(a * 3.0 + s * 33.0 + sv) + 0.003 * smoothstep(0.9, 0.95, s)
		P._lt(k, ar, sl, func(s, a, ins): return bk.darkened(0.4) if ins else P._fs(bk.lightened(0.04), float(sl.call(float(s), float(a))) - 0.006, 30.0), 0.0, 0.965, 30, 18)
	# tunik: U yaka, önde ve arkada dize yakın panel, yanlarda kalçadan yırtmaç
	var hem: float = lerpf(H, KN, 0.72)
	var keys := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(hp, H - 0.04, 0.046),
		[H - 0.15, hp.x + 0.066, hp.y + 0.08, hp.z - 0.078], [hem, hp.x + 0.08, hp.y + 0.095, hp.z - 0.09]]
	var slit := func(a: float) -> float: return 1.0 - smoothstep(0.17, 0.27, absf(absf(a) - PI * 0.5))
	var topf := func(a: float) -> float:
		var aw: float = absf(a)
		return N + 0.004 - 0.085 * exp(-pow(aw / 0.62, 2.0)) - 0.035 * exp(-pow((aw - PI) / 0.62, 2.0))
	var hemf := func(a: float) -> float: return lerpf(hem, H - 0.03, float(slit.call(a)))
	var tf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.012 * sin(a * 6.0 + 0.4) + 0.006 * sin(a * 11.0 + 1.3)) + 0.005 * sin(a * 5.0 + y * 13.0) * smoothstep(N - 0.04, C - 0.06, y) + 0.008 * sin(a * 9.0 - y * 20.0) * smoothstep(C - 0.1, H + 0.09, y) * smoothstep(H + 0.02, H + 0.1, y)
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var ssk := func(p): return AG._rsk(k, p, hem, 0.08)
	var tg: Dictionary = P._cl(k, {"keys": keys, "ny": 44, "na": 104, "top": topf, "hem": hemf, "fold": tf, "col": func(_a, _y, _v): return cr, "gain": 5.0, "th": 0.006, "inner": cr.darkened(0.3), "skin": ssk})
	P._cord(k, tg["top"], 0.0038, cr.darkened(0.08), true, func(p): return Q._nsk(k, p))
	var hm := []
	for p in tg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hm, 0.003, 0.0016, cr.darkened(0.18), true, ssk)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, tff, [Vector2(sg * 1.57, C - 0.04), Vector2(sg * 1.57, H + 0.0)], 0.0022, 0.0014, 0.0011, cr.darkened(0.2), tsk, 8)
	# kısa kollar: pazının ortasına iner, ağız hafif açılır
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.5 if sd == "Left" else 1.8
		var s1: float = float(ar["kn"]) * 0.62
		var sf := func(s: float, a: float) -> float: return 0.016 + 0.014 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s)
		P._lt(k, ar, sf, func(s, a, ins): return cr.darkened(0.3) if ins else P._fs(cr, float(sf.call(float(s), float(a))) - 0.016 - 0.014 * smoothstep(0.05, s1, float(s)), 12.0), 0.0, s1, 18, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, cr.darkened(0.35), s1 - 0.1, s1, 6, 22)
	# mor burgu ip kuşak + sırtta fiyonk
	var by: float = H + 0.075
	var rp := []
	for i in 72:
		rp.append(Q._spt(keys, tff, TAU * i / 72.0 - PI, by, 0.022)[0])
	T._twist(k, rp, true, 0.024, 26.0, pu, tsk)
	var bs: Array = Q._spt(keys, tff, PI, by, 0.044)
	var bc: Vector3 = bs[0]
	var bsk: Array = k.torso_skin(by)
	for sg in [1.0, -1.0]:
		var lp := []
		for i in 18:
			var t := TAU * i / 18.0
			lp.append(bc + Vector3(-sg * (0.055 + 0.05 * cos(t)), 0.03 * sin(t) + 0.004 * cos(t), -0.006 * (1.0 + cos(t))))
		T._twist(k, lp, true, 0.017, 9.0, pu, func(_p): return bsk)
	T._twist(k, [bc + Vector3(0.0, 0.026, -0.004), bc + Vector3(0.0, 0.0, -0.012), bc + Vector3(0.0, -0.026, -0.004)], false, 0.024, 1.4, pu.darkened(0.05), func(_p): return bsk)
	# fiyonk uçları: tunik sırtına oturarak iner
	for e2 in [[0.18, 0.2], [-0.16, 0.16]]:
		var tp := []
		for i in 9:
			var t := float(i) / 8.0
			var a: float = PI + float(e2[0]) * t * 1.0 + 0.04 * float(e2[0]) / absf(float(e2[0]))
			tp.append(Q._spt(keys, tff, a, by - 0.025 - t * float(e2[1]), 0.02 - 0.006 * t)[0])
		T._twist(k, tp, false, 0.015, 3.0, pu, ssk, 0.5)


# ------------------------------------------------------------------ Iwa Striker (ref Shinobi Striker "Rock Striker" kızıl): boynu saran koyu kahve şal (önde bindirilip gi yakasına sokulur), kolsuz kızıl gi
## (sol kanat sağın üstüne, ince beyaz yaka biyesi, uyluğun üstünde sarı etek bandı), solda soluk kırmızı tek kısa kol, geniş siyah kuşak, önde sarkan iki kahve kese (kilit yarıklı kapak),
## sırtta kahve çanta, dizin hemen altına inen açık kırmızı pantolon, sağ uylukta beyaz-siyah-beyaz bant + kahve kılıf, file çorap
static func _iwa_striker(k) -> void:
	var rg := Color(0.4, 0.075, 0.12)
	var sl := Color(0.72, 0.2, 0.24)
	var pr := Color(0.55, 0.13, 0.18)
	var sh := Color(0.17, 0.12, 0.11)
	var ye := Color(0.92, 0.72, 0.13)
	var wh := Color(0.93, 0.92, 0.9)
	var bk := Color(0.09, 0.085, 0.085)
	var br := Color(0.34, 0.26, 0.21)
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
	P._inner(k, b, func(_i, _j, _p): return sh.darkened(0.1), 0.004)
	K._seat(k, b, pr)
	# pantolon: dizin hemen altında manşet, altı file çorap
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.9
		P._lt(k, le, func(_s, _a): return 0.002, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc.lerp(Color(0.46, 0.4, 0.37), 0.2), kn + 0.05, 1.0, 16, 16)
		P._net_limb(k, le, kn + 0.1, 0.975, 0.0035, 12, 0.034, 0.0017, nt)
		var cuff: float = kn + 0.13
		var pa: Callable = K._pant(k, le, pr, 0.013, 0.024, cuff, sv)
		Q._ring_on(k, le, cuff - 0.012, func(s, a): return float(pa.call(s, a)) + 0.0015, 0.014, pr.darkened(0.12), 0.004)
		if sd == "Right":
			var s0: float = kn * 0.5
			for e in [[s0, wh], [s0 + 0.045, bk], [s0 + 0.09, wh]]:
				var s: float = e[0]
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + float(pa.call(s, 0.0)) + 0.006, 0.0125, 0.0, e[1], P._lskin(le, s))
			var a: float = J._outer_a(le, s0 + 0.045, Vector3(-1.0, 0.0, 0.2))
			var e2: Array = J._lsurf(le, s0 + 0.045, a, float(pa.call(s0 + 0.045, a)) + 0.026)
			var o: Vector3 = e2[1]
			var d: Vector3 = P._ld(le, s0)
			P._boxr(k, e2[0], o.cross(d).normalized() * 0.03, -d * 0.06, o * 0.017, br, [["RightUpperLeg", 1.0]])
			P._boxr(k, (e2[0] as Vector3) + o * 0.017 + d * 0.035, o.cross(d).normalized() * 0.032, -d * 0.024, o * 0.0045, br.darkened(0.15), [["RightUpperLeg", 1.0]], 0.2)
	# kollar: sağ açık (kol oyuğu biyeli), solda soluk kırmızı kısa kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		if sd == "Right":
			P._bare(k, AA._bare_arm(k, sd), skc)
			P._armhole(k, ar, 0.07, 0.006, 0.0045, rg.darkened(0.15))
		else:
			P._bare(k, AA._bare_arm(k, sd), skc, ak - 0.06, 1.0)
			var s1: float = ak - 0.03
			var sf := func(s: float, a: float) -> float: return 0.012 + 0.008 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, 1.3) * smoothstep(0.08, 0.2, s)
			P._lt(k, ar, sf, func(s, a, ins): return sl.darkened(0.35) if ins else P._fs(sl, float(sf.call(float(s), float(a))) - 0.012 - 0.008 * smoothstep(0.05, s1, float(s)), 14.0), 0.0, s1, 22, 20, 0.03)
			Q._ring_on(k, ar, s1 - 0.012, func(s, a): return float(sf.call(float(s), float(a))) + 0.001, 0.011, sl.darkened(0.1), 0.003)
	# gi: kolsuz sarmal üst, uyluğun üstünde biter
	var hem: float = lerpf(H, KN, 0.3)
	var keys := [P._kp(nk, N + 0.008, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.028), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.04, 0.042), [hem, hp.x + 0.065, hp.y + 0.06, hp.z - 0.066]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 6.0 + 0.3) + 0.007 * sin(a * 11.0 + 1.2)) + 0.006 * sin(a * 5.0 + y * 12.0) * smoothstep(H + 0.3, H + 0.06, y) + 0.004 * sin(a * 4.0 - y * 18.0) * smoothstep(C - 0.02, N - 0.04, y)
	var gsk := func(p): return T._ksk(k, p, hem)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(_a, _y, v): return rg.darkened(0.08 * smoothstep(0.95, 1.0, float(v))), "fold": fold, "band": wh, "band_w": 0.004,
		"ny": 40, "na": 60, "gain": 5.0, "low": -0.45, "skin_fn": gsk})
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		var hm := []
		for p in g["hem"]:
			hm.append((p as Vector3) + Vector3(0, 0.011, 0))
		P._bd(k, hm, 0.011, 0.003, ye, false, gsk)
	for sg in [1.0, -1.0]:
		P._hole(k, keys, sg, C + 0.0, 0.44, 0.085, 0.004, 0.003, rg.darkened(0.2))
	# geniş siyah kuşak
	var by: float = H + 0.07
	var bkk: Array = []
	for e in keys:
		bkk.append([e[0], float(e[1]) + 0.008, float(e[2]) + 0.01, float(e[3]) - 0.008])
	P._sash(k, bkk, by, 0.036, 0.003, bk.lightened(0.04), 0.1)
	# önde sarkan iki kese (kuşaktan uyluğa, kilit yarıklı kapak) + sırtta çanta
	var kff := func(a, y): return fold.call(float(a), float(y), 0.0)
	for e3 in [[0.22, 0.0], [0.62, 0.014]]:
		var pe: Array = Q._spt(keys, kff, float(e3[0]), by - 0.085 - float(e3[1]), 0.022)
		var o: Vector3 = pe[1]
		var ux: Vector3 = Vector3.UP.cross(o).normalized()
		var bo: Array = gsk.call(pe[0])
		P._boxr(k, pe[0], ux * 0.03, Vector3.UP * 0.07, o * 0.012, br, bo, 0.22)
		P._boxr(k, (pe[0] as Vector3) + o * 0.012 + Vector3.UP * 0.044, ux * 0.032, Vector3.UP * 0.028, o * 0.004, br.lightened(0.06), bo, 0.25)
		var c0: Vector3 = (pe[0] as Vector3) + o * 0.017 + Vector3.UP * 0.022
		P._boxr(k, c0, ux * 0.0028, Vector3.UP * 0.011, o * 0.0012, bk, bo, 0.4)
		P._boxr(k, c0 + Vector3.UP * 0.004, ux * 0.006, Vector3.UP * 0.002, o * 0.0012, bk, bo, 0.4)
		P._boxr(k, (pe[0] as Vector3) + o * 0.006 + Vector3.UP * 0.078, ux * 0.008, Vector3.UP * 0.012, o * 0.004, br.darkened(0.2), k.torso_skin(by), 0.3)
	var pb: Array = Q._spt(bkk, Callable(), PI, by - 0.005, 0.02)
	var po: Vector3 = pb[1]
	P._boxr(k, (pb[0] as Vector3) + po * 0.016, Vector3.UP.cross(po).normalized() * 0.065, Vector3.UP * 0.04, po * 0.018, br.darkened(0.1), k.torso_skin(by), 0.32)
	P._boxr(k, (pb[0] as Vector3) + po * 0.034 + Vector3.UP * 0.02, Vector3.UP.cross(po).normalized() * 0.067, Vector3.UP * 0.022, po * 0.005, br, k.torso_skin(by), 0.25)
	# şal: boynu saran kalın koyu kahve rulo, önde soldan sağa bindirilip gi yakasına girer
	var q: float = Q._hq(k)
	var ytop: float = N + 0.06 * q
	var cw := [[ytop, nk.x + 0.036, nk.y + 0.04, nk.z - 0.036], [N + 0.03 * q, nk.x + 0.054, nk.y + 0.06, nk.z - 0.05], [N - 0.03, ch.x * 0.84, ch.y * 0.98, ch.z * 0.98], [N - 0.09, ch.x * 1.08, ch.y * 1.08, ch.z * 1.1]]
	var hmf := func(a: float) -> float: return N - 0.06 - 0.03 * cos(a) * float(cos(a) > 0.0)
	var cf := func(a: float, y: float, v: float) -> float: return 0.046 * sin(v * PI) * (0.75 + 0.25 * cos(a)) + 0.014 * sin(a * 5.0 + 0.8) * v + 0.007 * sin(a * 9.0 + y * 20.0)
	var cg: Dictionary = P._cl(k, {"keys": cw, "ny": 16, "na": 72, "top": func(_a): return ytop, "hem": hmf, "fold": cf, "col": func(_a, _y, _v): return sh, "gain": 7.0, "th": 0.008, "inner": sh.lightened(0.04), "skin": nsk})
	P._cord(k, cg["top"], 0.006, sh.lightened(0.04), true, nsk)
	var fg: Dictionary = P._cl(k, {"keys": cw, "ny": 16, "na": 16, "rng": func(v): return Vector2(-0.42 + 0.3 * float(v), 0.2 + 0.1 * float(v)), "top": func(_a): return ytop - 0.003, "hem": func(a): return N - 0.115 + 0.03 * float(a), "fold": cf, "lift": 0.006,
		"col": func(_a, _y, _v): return sh.lightened(0.03), "gain": 7.0, "th": 0.005, "inner": sh.darkened(0.2), "skin": nsk})
	P._cord(k, fg["ea"], 0.003, sh.darkened(0.15), false, nsk)


# ------------------------------------------------------------------ Gōguru Wakate (ref Shinobi Striker "Obito Outfit Gaiden Ver."): lacivert tulum, üstünde göğüs altında biten önü açık kısa ceket
## (içi turuncu astar: ön kenarlarda ve etek ucunda turuncu bant görünür, dik turuncu yaka + iki çıtçıt, bileğe inen kol + turuncu manşet, sırtta Uchiha arması),
## beyaz kemer + gri toka, el koruyucu plakalı lacivert eldiven, sağ uylukta beyaz-lacivert-beyaz bant + lacivert kılıf, baldırda beyaz sargı
static func _goguru(k) -> void:
	var nv := Color(0.118, 0.165, 0.32)
	var og := Color(0.82, 0.4, 0.15)
	var wh := Color(0.94, 0.94, 0.94)
	var gy := Color(0.5, 0.5, 0.53)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	P._inner(k, b, func(_i, _j, _p): return nv, 0.008)
	K._seat(k, b, nv)
	# pantolon + baldır sargısı + sağ uylukta kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.6 if sd == "Left" else 0.5
		var pa: Callable = K._pant(k, le, nv, 0.012, 0.026, 1.0, sv)
		AG._leg_wrap(k, le, pa, kn + 0.2, 0.985, 10, wh)
		if sd == "Right":
			var s0: float = kn * 0.5
			for e in [[s0, wh], [s0 + 0.038, nv.lightened(0.08)], [s0 + 0.076, wh]]:
				var s: float = e[0]
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + float(pa.call(s, 0.0)) + 0.006, 0.012, 0.0, e[1], P._lskin(le, s))
			var a: float = J._outer_a(le, s0 + 0.04, Vector3(-1.0, 0.0, 0.2))
			var e2: Array = J._lsurf(le, s0 + 0.04, a, float(pa.call(s0 + 0.04, a)) + 0.024)
			var o: Vector3 = e2[1]
			var d: Vector3 = P._ld(le, s0)
			P._boxr(k, e2[0], o.cross(d).normalized() * 0.026, -d * 0.066, o * 0.016, nv.darkened(0.15), [["RightUpperLeg", 1.0]])
			P._boxr(k, (e2[0] as Vector3) + o * 0.016 + d * 0.04, o.cross(d).normalized() * 0.028, -d * 0.022, o * 0.004, nv.darkened(0.3), [["RightUpperLeg", 1.0]], 0.2)
	# kollar: bileğe inen ceket kolu + turuncu manşet, plakalı eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.3
		var sl := func(s: float, a: float) -> float: return 0.013 + 0.004 * smoothstep(0.1, 0.5, s) + 0.0035 * P._lf(s, a, sv) * smoothstep(0.15, 0.3, s) + 0.006 * exp(-pow((s - ak) / 0.07, 2.0)) * sin(a * 3.0 + s * 33.0 + sv)
		P._lt(k, ar, sl, func(s, a, ins): return og.darkened(0.2) if ins else P._fs(nv, float(sl.call(float(s), float(a))) - 0.015, 22.0), 0.0, 0.9, 32, 20, 0.02)
		Q._ring_on(k, ar, 0.88, func(s, a): return float(sl.call(float(s), float(a))) + 0.001, 0.012, og, 0.004)
		K._glove(k, sd, ar, nv.darkened(0.1), gy)
	# kısa ceket: göğüs altında biter, önü açık
	var jh: float = C - 0.13
	var jk := [P._kp(nk, N + 0.006, 0.028), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), [jh, ch.x + 0.026, ch.y + 0.03, ch.z - 0.026]]
	var e0 := 0.36
	var jf := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 5.0 + y * 14.0) * smoothstep(N - 0.03, C - 0.06, y) * smoothstep(0.42, 0.7, absf(a))
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 22, "na": 90, "rng": func(v): return Vector2(e0 + 0.06 * float(v), TAU - e0 - 0.06 * float(v)), "top": func(_a): return N + 0.006, "hem": func(_a): return jh,
		"fold": jf, "col": func(_a, _y, _v): return nv, "gain": 6.0, "th": 0.006, "inner": og.darkened(0.15), "skin": tsk})
	AA._edge_band(k, jg["ea"], 0.0085, 0.0035, og, tsk, 1.0)
	AA._edge_band(k, jg["eb"], 0.0085, 0.0035, og, tsk, -1.0)
	P._bd(k, AA._yl(jg["hem"], 0.007), 0.0075, 0.0032, og, false, tsk)
	for sg in [1.0, -1.0]:
		P._hole(k, jk, sg, C + 0.0, 0.46, 0.09, 0.0035, 0.004, nv.darkened(0.25))
	AG._uchiwa(k, jk, C - 0.04, 0.058, nv.darkened(0.45))
	# dik turuncu yaka, önü açık, iki çıtçıt
	var q: float = Q._hq(k)
	var ck := [[N + 0.07 * q, nk.x + 0.045, nk.y + 0.04, nk.z - 0.045], [N + 0.0, nk.x + 0.042, nk.y + 0.036, nk.z - 0.042], [N - 0.03, nk.x + 0.06, nk.y + 0.05, nk.z - 0.055]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 48, "rng": func(_v): return Vector2(0.42, TAU - 0.42), "top": func(a): return N + q * lerpf(0.055, 0.07, smoothstep(0.4, 1.4, absf(float(a)))), "hem": func(_a): return N - 0.025,
		"fold": func(a, _y, v): return 0.006 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return og, "gain": 5.0, "th": 0.006, "inner": nv, "skin": nsk})
	P._cord(k, cg["top"], 0.0035, og.darkened(0.2), false, nsk)
	for sg in [1.0, -1.0]:
		var e3: Array = Q._spt(ck, Callable(), sg * 0.62, N + 0.025 * q, 0.004)
		P._stud(k, e3[0], e3[1], 0.0055, nv, nsk.call(e3[0]))
	# beyaz kemer + gri toka
	var bk2 := [P._kp(wa, H + 0.08, 0.016), P._kp(wa, H + 0.0, 0.018)]
	P._sash(k, bk2, H + 0.04, 0.012, 0.002, wh, 0.06)
	var bf: Array = P._fp(bk2, 0.0, H + 0.04, true, 0.014)
	P._boxr(k, bf[0], Vector3(0.022, 0, 0), Vector3(0, 0.014, 0), Vector3(0, 0, 0.005), gy, k.torso_skin(H + 0.04), 0.25)
	P._boxr(k, (bf[0] as Vector3) + Vector3(0, 0, 0.005), Vector3(0.012, 0, 0), Vector3(0, 0.006, 0), Vector3(0, 0, 0.002), gy.darkened(0.3), k.torso_skin(H + 0.04), 0.3)


# ------------------------------------------------------------------ Jūbi Koromo (ref Shinobi Striker "Obito Outfit Ten Tails Ver."): soluk yeşil-beyaz beden kopyası (göğüs ve karında kabarık kas, yanlarda kaburga),
## göğüste altı, sırtta dokuz siyah tomoe, boyun çevresinde yukarı kalkan dört diken, omuzlardan yere inen önü açık pullu cübbe (alt ucu yırtık dişli), soluk kollar,
## paçası yırtık dişli lacivert bol pantolon
static func _jubi(k) -> void:
	var pc := Color(0.84, 0.89, 0.85)
	var pd := Color(0.64, 0.72, 0.67)
	var bk := Color(0.05, 0.05, 0.06)
	var pn := Color(0.12, 0.13, 0.27)
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
	# beden kopyası: kas kabartması (göğüs alt çizgisi, karın dilimleri, kaburga)
	var mus := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fr: float = 1.0 - smoothstep(0.55, 0.85, aw)
		var g := 0.0
		g -= 0.03 * exp(-pow(a / 0.05, 2.0)) * smoothstep(N - 0.06, C - 0.02, y) * smoothstep(H - 0.02, H + 0.06, y) * fr
		g -= 0.024 * exp(-pow((y - (C - 0.075)) / 0.012, 2.0)) * (1.0 - smoothstep(0.75, 0.95, aw))
		for yy in [C - 0.135, C - 0.195, H + 0.08]:
			g -= 0.018 * exp(-pow((y - float(yy)) / 0.009, 2.0)) * fr * smoothstep(0.04, 0.1, aw)
		var rb: float = smoothstep(0.75, 1.0, aw) * (1.0 - smoothstep(1.35, 1.6, aw)) * smoothstep(C - 0.2, C - 0.12, y) * (1.0 - smoothstep(C + 0.02, C + 0.06, y))
		g -= 0.014 * rb * pow(maxf(0.0, sin((y - C) * 95.0 - aw * 2.0)), 6.0)
		return g
	var bkeys := [P._kp(nk, N + 0.03, 0.004, 0.006), P._kp(nk, N + 0.0, 0.008), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.92], P._kp(ch, C - 0.03, 0.007), P._kp(wa, H + 0.12, 0.008), P._kp(hp, H - 0.09, 0.008)]
	SE.body_layer(k, bkeys, 44, 72, func(i, j, p):
		var a: float = TAU * float(i) / 72.0 - PI
		return P._fs(pc, float(mus.call(a, p.y)), 9.0), func(a, y): return float(mus.call(float(a), float(y))))
	K._seat(k, b, pn)
	# kollar: soluk beden kopyası
	for sd in ["Left", "Right"]:
		var ar: Dictionary = AA._bare_arm(k, sd)
		var ak: float = ar["kn"]
		P._lt(k, ar, func(s, a): return 0.0025 + 0.003 * exp(-pow((float(s) - ak * 0.45) / 0.1, 2.0)) * maxf(0.0, cos(float(a))), func(_s, _a, ins): return pd if ins else pc, 0.0, 0.97, 28, 18)
	# bol lacivert pantolon, paça yırtık dişli
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.7 if sd == "Left" else 0.6
		var ad := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * float(le["sg"]), 0.0, 1.0)
			return (0.016 + 0.024 * smoothstep(0.0, 0.4, s) - 0.012 * smoothstep(kn + 0.05, kn + 0.25, s)) * (1.0 - 0.4 * inn * (1.0 - smoothstep(0.3, 0.6, s))) + (0.006 + 0.008 * s) * P._lf(s, a, sv) + 0.008 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		S._lte(k, le, ad, func(s, a, ins): return pn.darkened(0.45) if ins else P._fs(pn, float(ad.call(float(s), float(a))) - 0.03, 10.0), 0.0, func(a): return 0.93 + 0.055 * _jag(float(a), sv, 6.0), 40, 24)
	# göğüste altı, sırtta dokuz tomoe
	var mff := func(a, y): return float(mus.call(float(a), float(y)))
	for i in 6:
		var a: float = lerpf(-0.78, 0.78, float(i) / 5.0)
		var y: float = C + 0.035 - 0.02 * cos(a * 1.6)
		var e: Array = Q._spt(bkeys, mff, a, y)
		Q._tomoe(k, Q._local(bkeys, mff, a, y), e[1], 0.012, -1.6, 0.003, bk, tsk)
	for i in 9:
		var a: float = PI + lerpf(-0.95, 0.95, float(i) / 8.0)
		var y: float = C + 0.03 - 0.025 * cos((a - PI) * 1.4)
		var e: Array = Q._spt(bkeys, mff, wrapf(a, -PI, PI), y)
		Q._tomoe(k, Q._local(bkeys, mff, wrapf(a, -PI, PI), y), e[1], 0.011, 1.6, 0.003, bk, tsk)
	# pullu cübbe: omuzlardan yere iner, önü geniş açık, alt ucu yırtık dişli
	var hem: float = lerpf(KN, F, 0.82)
	var ck := [[N - 0.005, nk.x + 0.06, nk.y + 0.03, nk.z - 0.06], [N - 0.055, ch.x * 1.06, ch.y * 0.98, ch.z * 1.08], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.04), P._kp(hp, H - 0.04, 0.05),
		[KN + 0.05, hp.x + 0.11, hp.y + 0.08, hp.z - 0.185], [hem, hp.x + 0.14, hp.y + 0.09, hp.z - 0.24]]
	var e_at := func(y: float) -> float: return lerpf(1.05, 0.8, smoothstep(N - 0.02, H, y))
	var scl := func(a: float, y: float) -> float:
		var row: float = floor((y - hem) * 30.0)
		var u: float = a * 13.0 + 1.57 * fposmod(row, 2.0)
		var v: float = (y - hem) * 30.0 - row
		return 0.006 * pow(maxf(0.0, sin(v * PI)), 0.5) * pow(absf(sin(u * 0.5)), 0.4) * smoothstep(C - 0.05, H, y)
	var cff := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		return pow(t, 0.9) * (0.022 * sin(a * 7.0 + 0.6) + 0.01 * sin(a * 12.0 + 1.9)) + float(scl.call(a, y))
	var csk := func(p): return AB._lsk(k, p, hem, 0.014)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 60, "na": 112, "rng": func(v):
		var e: float = e_at.call(lerpf(N - 0.005, hem, float(v)))
		return Vector2(e, TAU - e), "top": func(a): return N - 0.005 - 0.03 * smoothstep(1.4, 1.05, absf(float(a))), "hem": func(a): return hem + 0.07 * _jag(float(a), 0.7, 9.0) - 0.02,
		"fold": func(a, y, _v): return cff.call(float(a), float(y)), "col": func(_a, _y, _v): return pc, "gain": 8.0, "th": 0.007, "inner": pd, "skin": csk})
	P._cord(k, cg["top"], 0.005, pd, false, tsk)
	# dört diken: omuz başlarının önünde ve arkasında yukarı-dışa kalkar
	for sg in [1.0, -1.0]:
		for e4 in [[0.62, 0.15], [PI - 0.7, -0.12]]:
			var a: float = sg * float(e4[0])
			var e: Array = Q._spt(ck, Callable(), a, N - 0.035, 0.0)
			var base: Vector3 = e[0]
			var o: Vector3 = e[1]
			var dir: Vector3 = (Vector3.UP * 1.0 + o * 0.45 + Vector3(sg * 0.2, 0.0, float(e4[1]))).normalized()
			var pts := []
			for i in 8:
				var t := float(i) / 7.0
				pts.append(base + dir * 0.2 * t + o * 0.025 * sin(t * PI) - Vector3(0, 0.02, 0) * (1.0 - t))
			P._tb(k, pts, func(s, a2): return 0.026 * pow(1.0 - float(s), 0.9) * (1.0 + 0.25 * cos(float(a2))) + 0.0008, func(s, _a, _p): return pc.darkened(0.12 * (1.0 - float(s))), func(_s, _p): return [["UpperChest", 1.0]], 10)


# ------------------------------------------------------------------ Iwa Rōjin (ref Shinobi Striker "Ohnoki Outfit"): uzun kollu siyah Iwa tulumu, koyu yelek (fermuar + gri göğüs ve karın plakaları),
## omuzları saran kızıl yaka (ensede kalkık), önünde sarmal kıvrımlı uçları olan turuncu bant + küçük toka, banttan dize yakın inen turuncu çerçeveli yeşil şal panelleri (önde iki, arkada bir),
## baldırda toplanan bol siyah pantolon, altında kırmızı bantlı file çorap
static func _ronin_iwa(k) -> void:
	var bk := Color(0.11, 0.11, 0.125)
	var vs := Color(0.22, 0.23, 0.23)
	var gp := Color(0.62, 0.63, 0.64)
	var rd := Color(0.5, 0.09, 0.12)
	var og := Color(0.9, 0.58, 0.2)
	var gn := Color(0.6, 0.7, 0.45)
	var nt := Color(0.18, 0.18, 0.22)
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
	P._inner(k, b, func(_i, _j, _p): return bk, 0.006)
	K._seat(k, b, bk)
	# bol pantolon baldırda toplanır, altı file çorap + kırmızı bant
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 2.0 if sd == "Left" else 0.8
		var tk: float = kn + 0.22
		P._lt(k, le, func(_s, _a): return 0.002, func(_s, _a, ins): return skc.darkened(0.3) if ins else skc.lerp(Color(0.46, 0.4, 0.37), 0.2), tk - 0.04, 1.0, 12, 16)
		P._net_limb(k, le, tk - 0.02, 0.95, 0.0035, 12, 0.034, 0.0017, nt)
		k.wrap_turn(P._lp(le, 0.968), P._ld(le, 0.968), P._lr(le, 0.968) + 0.006, 0.011, 0.0, rd, P._lskin(le, 0.968))
		var ad: Callable = AB._baggy(k, le, bk, 0.016, 0.042, tk, sv, 0.3, 0.2)
		Q._ring_on(k, le, tk - 0.012, ad, 0.012, bk.lightened(0.05), 0.004)
	# uzun siyah kollar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.6
		var sl := func(s: float, a: float) -> float: return 0.009 + 0.003 * P._lf(s, a, sv) * smoothstep(0.2, 0.35, s) + 0.006 * exp(-pow((s - ak) / 0.07, 2.0)) * sin(a * 3.0 + s * 33.0 + sv) + 0.003 * smoothstep(0.88, 0.94, s)
		P._lt(k, ar, sl, func(s, a, ins): return bk.darkened(0.4) if ins else P._fs(bk.lightened(0.03), float(sl.call(float(s), float(a))) - 0.009, 26.0), 0.0, 0.955, 30, 18)
		Q._ring_on(k, ar, 0.93, sl, 0.012, bk.lightened(0.07), 0.004)
	# yelek: fermuar, göğüste dikey gri plaka, karında ikiye bölünmüş plaka
	var vk := [P._kp(nk, N + 0.01, 0.024), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.022), P._kp(wa, H + 0.0, 0.026)]
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 30, "na": 72, "top": func(_a): return N + 0.01, "hem": func(_a): return H + 0.0, "fold": func(a, y, _v): return 0.005 * sin(float(a) * 5.0 + float(y) * 11.0) - 0.012 * exp(-pow(float(a) / 0.03, 2.0)),
		"col": func(_a, _y, _v): return vs, "gain": 6.0, "th": 0.004, "skin": tsk})
	P._bd(k, AA._yl(vg["hem"], 0.006), 0.006, 0.003, vs.darkened(0.3), true, tsk)
	var zp := []
	for j in 20:
		zp.append(P._sa(vk, 0.0, lerpf(N - 0.02, H + 0.012, float(j) / 19.0), 0.002)[0])
	P._bd(k, zp, 0.0035, 0.0022, gp.darkened(0.25), false, tsk)
	P._patch(k, vk, -0.032, 0.032, C - 0.03, C - 0.14, true, 0.007, gp, 0.3, 10, 9, tsk)
	for sg in [1.0, -1.0]:
		P._patch(k, vk, sg * 0.004, sg * 0.042, H + 0.085, H + 0.035, true, 0.007, gp, 0.45, 8, 6, tsk)
	for sg in [1.0, -1.0]:
		P._hole(k, vk, sg, C + 0.0, 0.44, 0.088, 0.004, 0.003, vs.darkened(0.3))
	# kızıl yaka: omuzları saran kalın kat, ensede kalkık, önde V açık
	var q: float = Q._hq(k)
	var wd: float = k.UA + 0.06
	var rk := [[N + 0.075 * q, nk.x + 0.05, nk.y + 0.035, nk.z - 0.06], [N + 0.0, nk.x + 0.07, nk.y + 0.05, nk.z - 0.07], [N - 0.05, wd * 0.92, ch.y * 1.08, ch.z * 1.12], [C - 0.0, wd, ch.y * 1.12, ch.z * 1.16]]
	var rtop := func(a: float) -> float: return N + q * lerpf(0.0, 0.075, smoothstep(0.6, 2.3, absf(a)))
	var rhem := func(a: float) -> float: return lerpf(C - 0.015, C + 0.01, smoothstep(0.6, 1.4, absf(a)))
	var rf := func(a: float, y: float, v: float) -> float: return 0.02 * sin(float(v) * PI) + 0.006 * sin(a * 6.0 + y * 8.0) * float(v)
	var ask := func(p): return M._arm_skin(k, p, wd)
	var rg: Dictionary = P._cl(k, {"keys": rk, "ny": 18, "na": 80, "rng": func(v): return Vector2(lerpf(0.3, 0.42, float(v)), TAU - lerpf(0.3, 0.42, float(v))), "top": rtop, "hem": rhem, "fold": rf,
		"col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.008, "inner": rd.darkened(0.35), "skin": ask})
	P._cord(k, rg["top"], 0.005, rd.darkened(0.15), false, ask)
	# turuncu bant: yakanın alt kenarı boyunca önden omza, iç uçları sarmal kıvrım
	var rfo := func(a, y): return float(rf.call(float(a), float(y), 1.0))
	for sg in [1.0, -1.0]:
		var pts := []
		var ou := []
		for i in 16:
			var a: float = sg * lerpf(0.36, 1.55, float(i) / 15.0)
			var e: Array = Q._spt(rk, rfo, a, float(rhem.call(a)) + 0.012, 0.02 + 0.006)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, 0.021, 0.008, og, false, ask)
		var e5: Array = Q._spt(rk, rfo, sg * 0.42, float(rhem.call(sg * 0.42)) + 0.032, 0.034)
		var o5: Vector3 = e5[1]
		var ux: Vector3 = Vector3.UP.cross(o5).normalized()
		var sp := []
		var so := []
		for i in 22:
			var t := float(i) / 21.0
			var th: float = -PI * 0.5 + t * TAU * 1.15
			var rr: float = lerpf(0.03, 0.006, t)
			sp.append((e5[0] as Vector3) + ux * (-sg) * cos(th) * rr + Vector3.UP * sin(th) * rr)
			so.append(o5)
		k.strip(sp, so, 0.0065, 0.008, og.darkened(0.06), false, ask)
	var cc: Array = Q._spt(rk, rfo, 0.0, C + 0.006, 0.03)
	P._boxr(k, cc[0], Vector3(0.016, 0, 0), Vector3(0, 0.01, 0), (cc[1] as Vector3) * 0.006, og.darkened(0.1), k.torso_skin(C), 0.3)
	# yeşil şal panelleri: önde iki (banttan dize yakın), arkada bir; turuncu çerçeve + içte ince koyu çizgi
	var ph: float = lerpf(H, KN, 0.78)
	var sk := [[C + 0.0, wd * 0.98, ch.y * 1.14, ch.z * 1.18], [C - 0.1, ch.x + 0.05, ch.y + 0.055, ch.z - 0.06], P._kp(wa, H + 0.12, 0.06), P._kp(hp, H - 0.04, 0.075), [ph, hp.x + 0.1, hp.y + 0.09, hp.z - 0.1]]
	var psk := func(p): return AG._rsk(k, p, ph, 0.07)
	var pf := func(a: float, y: float, _v: float) -> float: return 0.008 * sin(a * 9.0 + 0.4) * clampf((H + 0.1 - y) / 0.5, 0.0, 1.0)
	for pn in [[0.36, 1.12, false], [-1.12, -0.36, false], [PI - 1.0, PI + 1.0, true]]:
		var a0: float = pn[0]
		var a1: float = pn[1]
		var bkp: bool = pn[2]
		var pg: Dictionary = P._cl(k, {"keys": sk, "ny": 40, "na": 26 if not bkp else 40, "rng": func(v):
			var fl: float = 0.12 * float(v)
			return Vector2(a0 - (fl if bkp else (fl if a0 < 0.0 else 0.0)), a1 + (fl if bkp else (fl if a0 > 0.0 else 0.0))),
			"top": func(_a): return C + 0.0, "hem": func(_a): return ph, "fold": pf, "col": func(_a, _y, _v): return gn, "gain": 6.0, "th": 0.006, "inner": gn.darkened(0.35), "skin": psk})
		for ed in [pg["ea"], pg["eb"]]:
			P._bd(k, ed, 0.011, 0.004, og, false, psk)
		P._bd(k, AA._yl(pg["hem"], 0.01), 0.011, 0.004, og, false, psk)
		var rows: Array = pg["rows"]
		var nj: int = rows.size()
		var ni: int = (rows[0] as Array).size()
		var ln := []
		for j in range(2, nj - 3):
			ln.append(rows[j][2])
		P._bd(k, ln, 0.0016, 0.0042, gn.darkened(0.4), false, psk)
		ln = []
		for j in range(2, nj - 3):
			ln.append(rows[j][ni - 3])
		P._bd(k, ln, 0.0016, 0.0042, gn.darkened(0.4), false, psk)
		ln = []
		for i in range(2, ni - 2):
			ln.append(rows[nj - 4][i])
		P._bd(k, ln, 0.0016, 0.0042, gn.darkened(0.4), false, psk)
