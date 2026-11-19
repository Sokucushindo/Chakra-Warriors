extends RefCounted
## Elle modellenmiş setler, parti aq: ss_golge_jonin, ss_demir_kum, ss_yelpaze_kilic, ss_yelpaze_zirh, ss_okul_mor, ss_mor_genin. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{shikamaru_outfit, shinki_outfit, shisui_style, special_outfits/Sasuke_Armor, sumire_outfit_ninja_school_version, sumire_outfit_genin_ver};
## Nara arması refs/kiyafet/nara_symbol/nara.svg (wiki çizimi, yollar birebir).
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), r (R), x (X), z (Z), aa (AA), i (I), t (T), y (Y), ag (AG), an (AN), m (M) dosyalarından.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const AN = preload("res://scripts/actors/set_el_an.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const L = preload("res://scripts/actors/set_el_l.gd")

const DONE := ["ss_golge_jonin", "ss_demir_kum", "ss_yelpaze_kilic", "ss_yelpaze_zirh", "ss_okul_mor", "ss_mor_genin"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_golge_jonin": _shikamaru(k)
		"ss_demir_kum": _shinki(k)
		"ss_yelpaze_kilic": _shisui(k)
		"ss_yelpaze_zirh": _gusoku(k)
		"ss_okul_mor": _sumire_okul(k)
		"ss_mor_genin": _sumire_genin(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Kübik bezier (2B)
static func _bz(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, n := 8) -> Array:
	var o := []
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		o.append(p0 * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + p3 * t * t * t)
	return o


## Nara arması (wiki SVG yolları): çember, içinde üç verev S kavis ve üç kısa dikey çubuk; hepsi kabartma şerit
static func _nara(k, mp: Callable, r: float, lift: float, col: Color, skinf: Callable) -> void:
	var nv := func(x: float, y: float) -> Vector2: return Vector2((x - 362.6) / 44.9, -(y - 820.9) / 44.9) * r
	var ring := []
	for i in 44:
		var t := TAU * i / 44.0
		ring.append(Vector2(cos(t), sin(t)) * r)
	var hw: float = r * 0.105
	R._lstrip(k, mp, ring, hw, lift, 0.0022, col, skinf, true)
	var curves := [
		[[401.44, 798.46], [393.24, 808.48], [385.59, 815.26], [362.58, 820.96], [339.58, 826.67], [331.92, 833.44], [323.72, 843.46]],
		[[387.78, 779.58], [379.58, 789.60], [371.93, 796.38], [348.92, 802.08], [333.04, 806.02], [324.47, 810.47], [317.99, 816.14]],
		[[407.73, 825.28], [401.18, 831.19], [392.58, 835.79], [376.24, 839.84], [353.24, 845.55], [345.58, 852.32], [337.38, 862.34]]]
	for c in curves:
		var q := []
		for e in c:
			q.append(nv.call(float(e[0]), float(e[1])))
		var pts: Array = _bz(q[0], q[1], q[2], q[3], 7)
		pts.pop_back()
		pts.append_array(_bz(q[3], q[4], q[5], q[6], 7))
		R._lstrip(k, mp, pts, hw * 0.9, lift, 0.0022, col, skinf)
	for e in [[362.29, 843.41, 362.29, 865.94], [368.88, 796.66, 368.23, 776.28], [351.83, 800.74, 351.83, 823.03]]:
		var a: Vector2 = nv.call(float(e[0]), float(e[1]))
		var b2: Vector2 = nv.call(float(e[2]), float(e[3]))
		R._lstrip(k, mp, [a, a.lerp(b2, 0.5), b2], hw * 0.9, lift, 0.0022, col, skinf)


## Ön kenar boyunca dışa dönük klapa: kenardan içe w(t) genişlikte kumaşın üstüne yatar. sg: +1 sol ön kenar (ea), -1 sağ (eb)
static func _lapel(k, ed: Array, j0: int, j1: int, wmax: float, col: Color, skinf: Callable, sg: float) -> void:
	var rows := []
	var n: int = j1 - j0
	for u in 5:
		var fu := float(u) / 4.0
		var ro := []
		for jj in n + 1:
			var p: Vector3 = ed[j0 + jj]
			var t := float(jj) / n
			var o := Vector3(p.x, 0.0, p.z).normalized()
			var tg := Vector3(o.z, 0.0, -o.x) * sg
			var w: float = wmax * pow(1.0 - t, 0.75) * (1.0 - 0.45 * exp(-pow((t - 0.12) / 0.05, 2.0))) + 0.002
			ro.append(p + tg * (w * fu - 0.002) + o * (0.0035 + 0.003 * sin(fu * PI) - 0.002 * fu))
		rows.append(ro)
	Q._mesh(k, rows, false, func(i, _j, _p): return col.darkened(0.14) if i == 0 else col, func(_i, _j, p): return skinf.call(p), Vector3(sg * 0.3, 0.0, 1.0).normalized())


## Yassı yaka (denizci / geniş yaka): gövdeye yatan kumaş. topf(a) iç kenar, hemf(a) dış kenar, e: önde açıklık yarı açısı
static func _flat_collar(k, keys: Array, e: float, topf: Callable, hemf: Callable, col: Color, lift: float) -> Dictionary:
	return P._cl(k, {"keys": keys, "ny": 12, "na": 108, "rng": func(_v): return Vector2(e, TAU - e), "top": topf, "hem": hemf,
		"fold": func(a, _y, v): return 0.004 * float(v) * sin(float(a) * 5.0), "col": func(_a, _y, _v): return col, "gain": 4.0, "th": 0.004,
		"inner": col.darkened(0.2), "lift": lift, "skin": func(p): return Q._nsk(k, p)})


## Küçük Uchiha yelpazesi (kumaş deseni): kırmızı üst, beyaz alt yarım daire + sap
static func _fan_mark(k, mp: Callable, r: float, lift: float, skinf: Callable) -> void:
	var out: Vector3 = R._out_of(mp)
	Q._disc(k, mp, out, r, lift, Callable(), func(_u, v): return Color(0.72, 0.13, 0.15) if float(v) > 0.04 else Color(0.95, 0.94, 0.92), skinf, 3, 18)
	R._lstrip(k, mp, [Vector2(0.0, -r * 0.95), Vector2(0.0, -r * 1.75)], r * 0.17, lift, 0.0012, Color(0.95, 0.94, 0.92), skinf)


# ------------------------------------------------------------------ Kage Jōnin (ref "Shikamaru Outfit"): derin V yakalı lacivert tulum (bol paça baldır ortasında büzülür), boyunda halkalı kolye,
## üstünde önü açık açık sarı ceket (yüksek dik yaka, klapa, kıvrık kısa kol, önü kalçada kavisle açılır, arkası dize inen kuyruk, sırtta Nara arması),
## kahve eldiven, siyah konçlu bot
static func _shikamaru(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var ye := Color(0.91, 0.831, 0.596)
	var br := Color(0.353, 0.227, 0.141)
	var bk := Color(0.094, 0.094, 0.11)
	var sv_c := Color(0.8, 0.81, 0.84)
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
	Z._skin_torso(k, b, C - 0.06)
	# tulum: derin V yaka, kalçada pantolona bağlanır
	var yv: float = C - 0.035
	var tk := [P._kp(nk, N + 0.012, 0.012), [N - 0.05, ch.x * 0.98, ch.y * 0.93, ch.z * 1.02], P._kp(ch, C - 0.03, 0.012), P._kp(wa, H + 0.12, 0.013), P._kp(k.M(H + 0.03, 0.3), H + 0.03, 0.016), P._kp(hp, H - 0.05, 0.017)]
	var vt := func(a: float) -> float: return lerpf(yv, N + 0.012, smoothstep(0.0, 0.62, absf(a)))
	var tf := func(a: float, y: float) -> float:
		return 0.005 * sin(a * 6.0 + y * 15.0) * smoothstep(C, H + 0.05, y) + 0.003 * sin(a * 11.0 - y * 9.0)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 30, "na": 84, "top": func(a): return vt.call(float(a)), "hem": func(_a): return H - 0.05, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return nv, "gain": 7.0, "th": 0.005, "inner": nv.darkened(0.4), "skin": tsk})
	var ve := []
	for p in tg["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.75:
			ve.append(p)
	P._bd(k, ve, 0.0042, 0.0024, nv.lightened(0.07), false, tsk, 0.4)
	Q._run(k, tk, tf, [Vector2(0.0, H + 0.06), Vector2(0.0, H - 0.045)], 0.0016, 0.0016, 0.0012, nv.darkened(0.3), tsk, 6)
	K._seat(k, b, nv.darkened(0.05))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.1
		var tkk: float = kn + 0.22
		Q._baggy(k, le, nv, bk, 0.012, 0.032, tkk, sv)
		var b0: float = kn + 0.2
		P._lt(k, le, func(s, a): return 0.0095 + 0.004 * smoothstep(b0 + 0.05, b0, float(s)) + 0.0012 * sin(float(a) * 4.0 + float(s) * 30.0) * smoothstep(b0 + 0.04, b0 + 0.1, float(s)),
			func(s, a, ins): return bk.darkened(0.2) if ins else bk.lightened(0.05 * float(cos(float(a)) > 0.5) + 0.04 * float(float(s) < b0 + 0.02)), b0, 0.99, 16, 20, 0.02)
	# halkalı kolye: boyundan V'ye inen ince zincir + halka
	var skk := [P._kp(nk, N + 0.015, 0.005), [N - 0.04, ch.x * 0.7, ch.y * 0.8, ch.z * 0.88], [C + 0.01, ch.x * 0.9, ch.y * 0.96, ch.z * 0.98]]
	var cp := []
	for i in 40:
		var a := TAU * i / 40.0 - PI
		var y: float = N + 0.008 - 0.058 * pow(maxf(0.0, cos(a)), 3.0)
		cp.append(Q._spt(skk, Callable(), a, y, 0.0035)[0])
	P._cord(k, cp, 0.0014, sv_c, true, nsk, 0.0, 5)
	var rc: Array = Q._spt(skk, Callable(), 0.0, N - 0.064, 0.005)
	var rr := []
	for i in 16:
		var t := TAU * i / 16.0
		rr.append((rc[0] as Vector3) + Vector3(cos(t) * 0.0105, sin(t) * 0.0105 - 0.004, 0.0))
	P._tb(k, rr, func(_s, _a): return 0.0021, func(_s, _a, _p): return sv_c, func(_s, _p): return [["UpperChest", 1.0]], 6, true)
	# ceket: önü açık, ön kenar kalçada kavisle yana kaçar, arkası dize iner
	var hem_b: float = KN + 0.03
	var jk := [P._kp(nk, N + 0.01, 0.034), [N - 0.055, ch.x * 1.04, ch.y * 0.98, ch.z * 1.07], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.04), [H - 0.04, hp.x + 0.05, hp.y + 0.05, hp.z - 0.055], [hem_b, hp.x + 0.085, hp.y + 0.07, hp.z - 0.1]]
	var jsk := func(p): return AG._rsk(k, p, hem_b, 0.035, 0.5)
	var jf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem_b), 0.0, 1.0)
		return 0.004 * sin(a * 5.0 + y * 13.0) * smoothstep(N - 0.04, C - 0.04, y) + t * (0.016 * sin(a * 6.0 + 0.7) + 0.007 * sin(a * 11.0 + 1.9)) * smoothstep(0.6, 1.6, absf(a)) + 0.004 * sin(a * 9.0 + y * 21.0) * smoothstep(C, H, y)
	var hemf := func(a: float) -> float:
		var u: float = absf(a)
		return lerpf(H - 0.1, hem_b, smoothstep(0.55, 2.2, u)) + 0.05 * (1.0 - smoothstep(0.36, 0.9, u))
	var eo := func(v: float) -> float: return lerpf(0.3, 0.42, smoothstep(0.2, 1.0, v))
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 46, "na": 104, "rng": func(v): return Vector2(float(eo.call(float(v))), TAU - float(eo.call(float(v)))), "top": func(_a): return N + 0.01,
		"hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return jf.call(float(a), float(y)), "col": func(_a, _y, _v): return ye, "gain": 6.0, "th": 0.007, "inner": ye.darkened(0.16), "skin": jsk})
	AA._edge_band(k, jg["ea"], 0.0065, 0.0022, ye.darkened(0.05), jsk, 1.0)
	AA._edge_band(k, jg["eb"], 0.0065, 0.0022, ye.darkened(0.05), jsk, -1.0)
	P._bd(k, AA._yl(jg["hem"], 0.009), 0.0045, 0.0018, ye.darkened(0.12), false, jsk)
	var j1: int = int(46.0 * (N + 0.01 - (C - 0.085)) / (N + 0.01 - (H - 0.05)))
	_lapel(k, jg["ea"], 0, j1, 0.036, ye.lightened(0.03), jsk, 1.0)
	_lapel(k, jg["eb"], 0, j1, 0.036, ye.lightened(0.03), jsk, -1.0)
	for sg in [1.0, -1.0]:   # yan dikiş, sırtta kuyruk ortası dikişi
		Q._run(k, jk, jf, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.52, H - 0.15)], 0.0016, 0.0016, 0.0012, ye.darkened(0.22), jsk, 8)
	Q._run(k, jk, jf, [Vector2(PI, C - 0.12), Vector2(PI, hem_b + 0.02)], 0.0016, 0.0016, 0.0012, ye.darkened(0.22), jsk, 10)
	# yüksek dik yaka: arkada ve yanda kulak hizasına kalkar, önü dik kesik
	var hq: float = Q._hq(k)
	var ck := [[N + 0.1 * hq, nk.x + 0.05, nk.y + 0.04, nk.z - 0.05], [N + 0.035 * hq, nk.x + 0.034, nk.y + 0.03, nk.z - 0.038], [N - 0.02, nk.x + 0.044, nk.y + 0.04, nk.z - 0.04]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 50, "rng": func(_v): return Vector2(0.42, TAU - 0.42), "top": func(a):
		return N + hq * lerpf(0.065, 0.1, smoothstep(0.45, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.015, "fold": func(a, _y, v): return 0.008 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.5),
		"col": func(_a, _y, _v): return ye.lightened(0.02), "inner": ye.darkened(0.14), "skin": nsk, "th": 0.006})
	P._cord(k, cg["top"], 0.004, ye.lightened(0.04), false, nsk)
	for e in [cg["ea"], cg["eb"]]:
		P._cord(k, e, 0.0034, ye.darkened(0.04), false, nsk)
	# sırtta Nara arması
	_nara(k, AA._back_mp(jk, 0.0, C - 0.055), 0.058, 0.0045, Color(0.24, 0.17, 0.1), tsk)
	# kollar: kıvrık ağızlı kısa kol, çıplak kol, kahve eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.1 if sd == "Left" else 2.6
		Z._arm_bare(k, ar, 0.2)
		var s1 := 0.36
		var sf := func(s: float, a: float) -> float: return 0.02 + 0.008 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.08, 0.25, s)
		P._lt(k, ar, sf, func(s, a, ins): return ye.darkened(0.25) if ins else P._fs(ye, 0.004 * P._lf(float(s), float(a), sv), 14.0), 0.0, s1, 16, 24, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.004, ye.darkened(0.3), s1 - 0.1, s1, 5, 24)
		X._roll(k, ar, s1 - 0.065, s1 + 0.004, sf, 0.0055, ye.lightened(0.02), sv)
		Z._glove_full(k, sd, br)
		P._lt(k, ar, func(s, a): return 0.006 + 0.007 * smoothstep(0.9, 0.84, float(s)) + 0.0018 * sin(float(a) * 3.0 + float(s) * 60.0 + sv),
			func(s, a, ins): return br.darkened(0.3) if ins else br.darkened(0.14 * maxf(0.0, sin(float(a) * 3.0 + float(s) * 60.0 + sv))), 0.84, 0.975, 10, 18)


# ------------------------------------------------------------------ Satetsu Gaitō (ref "Shinki Outfit"): bileğe inen siyah cübbe (önü kapalı, aşağı doğru genişler, düzensiz kabarık etek ucu),
## omuzları saran kabarık demir kum yaka, bileğe doğru açılan geniş kollar (kabarık ağız), altında dik boğazlı koyu iç giysi, siyah pantolon
static func _shinki(k) -> void:
	var bk := Color(0.086, 0.086, 0.102)
	var lin := Color(0.15, 0.15, 0.17)
	var fu := Color(0.13, 0.13, 0.15)
	var inn := Color(0.165, 0.165, 0.188)
	var pn := Color(0.11, 0.11, 0.125)
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
	P._inner(k, b, func(_i, j, _p): return inn.lightened(0.04) if j < 4 else inn, 0.006)
	X._neck(k, b, inn, 0.06, false)
	K._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, pn, 0.01, 0.016, 1.0, 1.2 if sd == "Left" else 2.5)
	# cübbe
	var hem: float = lerpf(KN, k.F, 0.8)
	var rk := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 1.05, ch.y * 0.98, ch.z * 1.08], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.05), [H - 0.04, hp.x + 0.07, hp.y + 0.07, hp.z - 0.07],
		[KN, hp.x + 0.12, hp.y + 0.11, hp.z - 0.13], [hem, hp.x + 0.165, hp.y + 0.14, hp.z - 0.17]]
	var csk := func(p): return Q._csk(k, p, hem)
	var rf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return pow(t, 0.9) * (0.03 * sin(a * 7.0 + 0.5) + 0.012 * sin(a * 13.0 + 1.7)) + (1.0 - t) * 0.005 * sin(a * 6.0 + y * 12.0) * smoothstep(N - 0.03, C - 0.04, y)
	var rhem := func(a: float) -> float: return hem + 0.016 * Y._teeth(a, 29.0, 0.2) + 0.008 * Y._teeth(a, 11.0, 0.6) + 0.006 * sin(a * 5.0)
	var rg: Dictionary = P._cl(k, {"keys": rk, "ny": 56, "na": 112, "top": func(_a): return N + 0.0, "hem": func(a): return rhem.call(float(a)), "fold": func(a, y, _v): return rf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 5.0, "th": 0.008, "inner": lin, "skin": csk})
	Q._run(k, rk, rf, [Vector2(0.0, C - 0.02), Vector2(0.0, hem + 0.03)], 0.0024, 0.002, 0.0016, bk.darkened(0.3), csk, 20)
	# etek ucunda kabarık iri taneler: kumaşa oturan düzensiz kenar
	P._bd(k, AA._yl(rg["hem"], 0.012), 0.012, 0.004, fu, false, csk)
	# demir kum yaka: omuzlara yayılan üç kat kabarık halka
	var fk := [P._kp(nk, N + 0.06, 0.02), P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 1.05, ch.y * 0.98, ch.z * 1.08], P._kp(ch, C - 0.03, 0.036)]
	for e in [[N + 0.045, 0.0, 0.026, 0.4, nsk], [N + 0.005, 0.012, 0.034, 1.7, nsk], [N - 0.04, 0.018, 0.04, 3.1, tsk], [N - 0.075, 0.012, 0.03, 4.6, tsk]]:
		var pts := []
		for i in 64:
			var a := TAU * i / 64.0 - PI
			var y: float = float(e[0]) - 0.008 * cos(a) + 0.006 * sin(a * 9.0 + float(e[3]))
			pts.append(Q._spt(fk, Callable(), a, y, float(e[1]) + float(e[2]) * 0.8)[0])
		M._fur(k, pts, float(e[2]), fu.lightened(0.04 * float(float(e[3]) > 2.0)), e[4], float(e[3]), true)
	# kollar: koyu iç kol, bileğe doğru açılan geniş kol, kabarık ağız
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.0 if sd == "Left" else 2.3
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return inn.darkened(0.3) if ins else inn, 0.25, 0.985, 18, 16)
		var s1 := 0.92
		var sl: Callable = AA._hang_sleeve(k, ar, bk, lin, 0.02, 0.026, 0.018, s1, sv)
		var cuff := []
		for i in 40:
			var a := TAU * i / 40.0 - PI
			cuff.append(Q._ls(ar, s1 - 0.012, a, float(sl.call(s1 - 0.012, a)) + 0.004)[0])
		M._fur(k, cuff, 0.011, fu, func(_p): return P._lskin(ar, s1), sv, true)


# ------------------------------------------------------------------ Uchiha Kenshi (ref "Shisui Style"): dik boğazlı siyah kısa kollu tişört (sırtta Uchiha yelpazesi), sağ omuzdan sol göğse verev inen
## kahve deri kılıç tutucu (perçinli, dikişli; sırtta sol omuzdan sağ kalçaya kayış), lacivert bol pantolon, baldırda beyaz sargı, siyah bot
static func _shisui(k) -> void:
	var bk := Color(0.11, 0.11, 0.125)
	var nv := Color(0.118, 0.165, 0.282)
	var br := Color(0.353, 0.227, 0.141)
	var wh := Color(0.9, 0.9, 0.88)
	var bt := Color(0.094, 0.094, 0.11)
	var mt := Color(0.82, 0.78, 0.66)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	K._seat(k, b, nv.darkened(0.05))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 2.0
		var s1: float = kn + 0.26
		var pa: Callable = K._pant(k, le, nv, 0.012, 0.026, s1, sv)
		P._lt(k, le, func(s, a): return float(pa.call(float(s), float(a))) + 0.003 * smoothstep(s1 - 0.05, s1, float(s)), func(_s, _a, ins): return nv.darkened(0.4) if ins else nv.darkened(0.06), s1 - 0.03, s1, 3, 20)
		J._shin_tape(k, le, func(s, a): return minf(float(pa.call(float(s), float(a))), 0.006), s1 - 0.02, 7, wh)
		var b0: float = 0.875
		P._lt(k, le, func(s, a): return 0.016 + 0.004 * smoothstep(b0 + 0.03, b0, float(s)) + 0.001 * sin(float(a) * 4.0), func(s, a, ins): return bt.darkened(0.2) if ins else bt.lightened(0.05 * float(float(s) < b0 + 0.015)), b0, 0.99, 8, 20, 0.015)
	# tişört: kalçaya iner
	var hem: float = H - 0.05
	var tk := [P._kp(nk, N + 0.01, 0.022), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(k.M(H + 0.02, 0.3), H + 0.02, 0.036), P._kp(k.M(hem, 0.3), hem, 0.04)]
	var tf := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 6.0 + y * 15.0) * smoothstep(C, H + 0.06, y) + 0.003 * sin(a * 11.0 - y * 9.0) + 0.004 * sin(a * 4.0 - y * 24.0) * smoothstep(C - 0.04, N, y)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 32, "na": 88, "top": func(_a): return N + 0.01, "hem": func(_a): return hem, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 7.0, "th": 0.006, "inner": bk.darkened(0.4), "skin": tsk})
	P._bd(k, AA._yl(tg["hem"], 0.009), 0.005, 0.002, bk.darkened(0.2), true, tsk)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tf, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, hem + 0.012)], 0.0016, 0.0016, 0.0012, bk.lightened(0.08), tsk, 8)
	X._neck(k, b, bk, 0.07, false)
	AG._uchiwa(k, tk, C - 0.07, 0.062, bk.lightened(0.18))
	# deri kılıç tutucu: sağ omuzda geniş, sol omuza doğru sivrilir
	var nu := 22
	var nvv := 6
	var lb := []
	for j in nvv + 3:
		var jj: int = clampi(j - 1, 0, nvv)
		var v: float = float(jj) / nvv
		var ro := []
		for i in nu + 1:
			var u := float(i) / nu
			var a: float = lerpf(-1.32, 0.98, u)
			var yt: float = lerpf(N - 0.012, N - 0.03, u)
			var yb: float = lerpf(C - 0.115, N - 0.028, pow(u, 0.85))
			var lf: float = 0.0 if j == 0 or j == nvv + 2 else 0.006
			ro.append(Q._spt(tk, tf, a, lerpf(yt, yb, v), lf)[0])
		lb.append(ro)
	Q._mesh(k, lb, false, func(_i, j, _p): return br.darkened(0.25) if j <= 1 or j >= nvv + 1 else br.darkened(0.06 * float(j % 2)), func(_i, _j, p): return tsk.call(p), Vector3(0, 0.3, 1).normalized())
	var stp := []
	for i in 12:
		var u := float(i) / 11.0 * 0.9
		stp.append(Vector2(lerpf(-1.32, 0.98, u), lerpf(C - 0.115, N - 0.028, pow(u, 0.85)) + 0.012))
	Q._run(k, tk, tf, stp, 0.0012, 0.0072, 0.0008, br.lightened(0.25), tsk, 2)
	var sp: Array = Q._spt(tk, tf, -1.05, N - 0.03, 0.009)
	P._stud(k, sp[0], sp[1], 0.0055, mt, [["UpperChest", 1.0]])
	# sırtta kayış: sol omuzdan sağ kalçaya
	Q._run(k, tk, tf, [Vector2(0.98, N - 0.03), Vector2(2.2, N - 0.06), Vector2(PI + 0.2, C - 0.07), Vector2(PI + 0.9, H + 0.07)], 0.014, 0.006, 0.003, br.darkened(0.04), tsk, 8)
	# kollar: kısa kol, çıplak kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.4 if sd == "Left" else 2.9
		Z._arm_bare(k, ar, 0.2)
		var s1 := 0.4
		var sf2 := func(s: float, a: float) -> float: return 0.015 + 0.008 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.1, 0.3, s)
		P._lt(k, ar, sf2, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk, 0.004 * P._lf(float(s), float(a), sv), 14.0), 0.0, s1, 16, 24, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf2.call(float(s), float(a))) - 0.004, bk.darkened(0.3), s1 - 0.1, s1, 5, 24)
		P._lt(k, ar, func(s, a): return float(sf2.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05), s1 - 0.025, s1 + 0.001, 3, 24)


# ------------------------------------------------------------------ Uchiha Gusoku (ref Special Outfits "Uchiha (Armored Vers.)", Sasuke_Armor): soluk mor kumaş (kol ve bol pantolonda Uchiha yelpazesi deseni),
## kafes desenli kızıl göğüslük + leylak omuz bağları, beyaz çubuklu siyah boğazlık, iki tur kalın mor burgu ip kuşak, beyaz noktalı siyah plaka etek, uylukta kare plakalı
## siyah koruma, siyah dizlik ve kaval zırhı (krem bant), mavi bantlı siyah önkol koruması
static func _gusoku(k) -> void:
	var lv := Color(0.66, 0.63, 0.82)
	var rd := Color(0.604, 0.118, 0.133)
	var cr := Color(0.9, 0.84, 0.7)
	var bk := Color(0.12, 0.12, 0.145)
	var st := Color(0.66, 0.6, 0.88)
	var rp := Color(0.58, 0.48, 0.84)
	var bl := Color(0.2, 0.32, 0.72)
	var wh := Color(0.94, 0.94, 0.92)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	var ik: Array = P._inner(k, b, func(_i, j, _p): return bk.lightened(0.04) if j < 4 else bk, 0.008)
	K._seat(k, b, lv.darkened(0.1))
	# bol pantolon: dizin altında büzülür; kaval zırhı, dizlik, uyluk plakaları
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.5 if sd == "Left" else 1.8
		var tkk: float = kn + 0.05
		var pa: Callable = Q._baggy(k, le, lv, bk, 0.012, 0.024, tkk, sv)
		var gs := func(s: float, a: float) -> float: return 0.013 + 0.004 * smoothstep(kn + 0.1, kn + 0.04, s) - 0.003 * smoothstep(0.9, 0.97, s) + 0.002 * cos(a) * smoothstep(kn + 0.1, kn + 0.2, s)
		P._lt(k, le, gs, func(s, a, ins): return bk.darkened(0.2) if ins else bk.lightened(0.06 * maxf(0.0, cos(float(a))) * float(float(s) > kn + 0.12)), kn + 0.03, 0.965, 18, 22, 0.015)
		for s in [kn + 0.055, 0.93]:
			Q._ring_on(k, le, s, func(s2, a): return float(gs.call(float(s2), float(a))) + 0.001, 0.008, cr, 0.002)
		K._shell(k, le, kn - 0.075, kn + 0.06, -1.0, 1.0, func(s, a): return maxf(float(pa.call(float(s), float(a))), 0.014) + 0.003, 0.01,
			func(u, v, ins): return bk.darkened(0.3) if ins else bk.lightened(0.08 * sin(float(v) * PI) * (1.0 - absf(2.0 * float(u) - 1.0))), 10, 14)
		# uyluk koruması: küçük kare plakalar (haidate)
		var ao: float = J._outer_a(le, kn * 0.6, Vector3(float(le["sg"]) * 0.35, 0.0, 1.0).normalized())
		for row in 4:
			for col in 3:
				var s0: float = kn * (0.42 + 0.115 * row)
				var a0: float = ao + (float(col) - 1.0) * 0.42
				K._shell(k, le, s0, s0 + kn * 0.1, a0 - 0.18, a0 + 0.18, func(s, a): return maxf(float(pa.call(float(s), float(a))), 0.01) + 0.006 + 0.003 * row, 0.006,
					func(u, v, ins): return bk.darkened(0.3) if ins else (cr if minf(float(u), 1.0 - float(u)) < 0.12 or minf(float(v), 1.0 - float(v)) < 0.12 else bk), 3, 4)
		for i in 3:
			var s0: float = kn * (0.3 + 0.25 * i)
			var a0: float = ao + PI * (0.75 + 0.3 * i) * float(le["sg"]) * (1.0 if i % 2 == 0 else -1.0)
			_fan_mark(k, R._lmap(le, func(s, a): return float(pa.call(float(s), float(a))), s0, a0), 0.022, 0.002, func(_p): return P._lskin(le, s0))
	# göğüslük: üstü düz, yanlarda koltuk altına iner
	var cy0: float = C + 0.05
	var ck := [P._kp(k.M(C + 0.07, k.UA), C + 0.07, 0.03), P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.034), P._kp(k.M(H + 0.04, 0.3), H + 0.04, 0.036)]
	var ctop := func(a: float) -> float: return cy0 + 0.012 * smoothstep(1.8, 2.6, absf(a)) - 0.055 * exp(-pow((absf(a) - PI * 0.5) / 0.42, 2.0))
	var zf := func(_a, _y): return 0.0
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 18, "na": 96, "top": func(a): return ctop.call(float(a)), "hem": func(_a): return H + 0.045, "col": func(_a, _y, _v): return rd, "gain": 4.0, "th": 0.009, "inner": bk, "skin": tsk})
	P._cord(k, cg["top"], 0.0045, bk.lightened(0.05), true, tsk)
	# kafes deseni: iki yönde verev kabartma çizgiler (eşkenar dörtgen ağ)
	var da := 0.3
	var sl: float = da / 0.056
	for fam in [1.0, -1.0]:
		for li in 21:
			var c0: float = -PI + li * da
			var pts := []
			var ou := []
			var y := H + 0.052
			while y < C + 0.06:
				var a: float = c0 + fam * sl * (y - H - 0.052)
				if y > float(ctop.call(wrapf(a, -PI, PI))) - 0.008:
					break
				var e: Array = Q._spt(ck, zf, a, y, 0.0008)
				pts.append(e[0])
				ou.append(e[1])
				y += 0.014
			if pts.size() >= 3:
				k.strip(pts, ou, 0.0019, 0.0016, cr, false, tsk)
	# omuz bağları: önde göğüslük üstünden omuzdan sırta, ikişer leylak bağ
	for x in [0.062, 0.084, -0.062, -0.084]:
		P._over(k, ik, x, cy0 - 0.004, cy0 + 0.008, 0.0045, 0.014, 0.004, st.darkened(0.08 * float(absf(x) > 0.07)))
	# boğazlık: siyah yaka + göğüs üstüne yatan bant, beyaz çubuk dizileri
	var hq: float = Q._hq(k)
	var nkk := [P._kp(nk, N + 0.04 * hq, 0.014), P._kp(nk, N + 0.0, 0.02), [N - 0.045, ch.x * 0.62, ch.y * 0.92 + 0.012, ch.z * 0.9 - 0.012], [cy0 + 0.006, ch.x * 0.66, ch.y + 0.03, ch.z - 0.03]]
	var ng: Dictionary = P._cl(k, {"keys": nkk, "ny": 14, "na": 72, "top": func(_a): return N + 0.04 * hq, "hem": func(_a): return cy0 + 0.006, "col": func(_a, _y, _v): return bk, "gain": 4.0, "th": 0.006, "inner": bk.darkened(0.2), "skin": nsk})
	P._cord(k, ng["top"], 0.0035, bk.lightened(0.08), true, nsk)
	for rw in [[N + 0.016 * hq, 0.009, 10], [N - 0.03, 0.011, 12]]:
		for i in int(rw[2]):
			var a: float = lerpf(-1.25, 1.25, float(i) / (float(rw[2]) - 1.0))
			var e: Array = Q._spt(nkk, Callable(), a, float(rw[0]), 0.0)
			var o: Vector3 = e[1]
			P._boxr(k, (e[0] as Vector3) + o * 0.001, Vector3(o.z, 0, -o.x) * 0.0028, Vector3(0, float(rw[1]), 0), o * 0.0022, wh, nsk.call(e[0]), 0.35)
	# burgu ip kuşak: iki kalın tur
	for e in [[H + 0.075, 0.006], [H + 0.034, -0.004]]:
		AN._rope_ring(k, ck, zf, float(e[0]), float(e[1]), 0.004, 0.0175, rp, tsk)
	# plaka etek: altı panel (önde ve arkada ikişer, yanlarda birer), her sırada beyaz bağ + bağ noktası
	for e in [[0.43, 0.45, 0.05], [-0.43, 0.45, 0.052], [PI * 0.5, 0.56, 0.056], [-PI * 0.5, 0.56, 0.056], [PI - 0.43, 0.45, 0.046], [-PI + 0.43, 0.45, 0.048]]:
		_kz(k, hp, H + 0.025, float(e[0]), float(e[1]), 4, 0.062, 0.016, float(e[2]), 0.14, bk, bk.lightened(0.12), wh)
	# kollar: kabarık soluk mor kol (yelpaze deseni), siyah önkol koruması (krem kenar, mavi bant), siyah el koruması
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.3 if sd == "Left" else 2.6
		var sf := func(s: float, a: float) -> float: return 0.012 + 0.014 * sin(clampf(s / 0.66, 0.0, 1.0) * PI) * smoothstep(0.0, 0.1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s)
		P._lt(k, ar, sf, func(s, a, ins): return lv.darkened(0.3) if ins else P._fs(lv, 0.004 * P._lf(float(s), float(a), sv), 12.0), 0.0, 0.66, 20, 20)
		var ao: float = J._outer_a(ar, 0.3, Vector3(float(ar["sg"]), 0.0, 0.3).normalized())
		for i in 4:
			var s0: float = 0.13 + 0.12 * i
			var a0: float = ao + (0.9 if i % 2 == 0 else -0.7) * float(ar["sg"]) + (PI * 0.35 if i == 3 else 0.0)
			_fan_mark(k, R._lmap(ar, sf, s0, a0), 0.019, 0.0015, func(_p): return P._lskin(ar, s0))
		var gf := func(s: float, a: float) -> float: return 0.009 + 0.004 * smoothstep(en + 0.08, en + 0.02, s) - 0.003 * smoothstep(0.9, 0.97, s) + 0.0012 * cos(a)
		P._lt(k, ar, gf, func(_s, a, ins): return bk.darkened(0.25) if ins else bk.lightened(0.05 * maxf(0.0, cos(float(a)))), en + 0.0, 0.975, 18, 20, 0.015)
		Q._ring_on(k, ar, en + 0.012, func(s2, a): return float(gf.call(float(s2), float(a))) + 0.001, 0.006, cr, 0.002)
		Q._ring_on(k, ar, 0.9, func(s2, a): return float(gf.call(float(s2), float(a))) + 0.0005, 0.007, bl, 0.002)
		var oa: float = J._outer_a(ar, 0.75, Vector3(float(ar["sg"]), 0.2, 0.2).normalized())
		K._shell(k, ar, en + 0.04, 0.88, oa - 0.95, oa + 0.95, func(s, a): return float(gf.call(float(s), float(a))) + 0.002, 0.005,
			func(u, v, ins): return bk.darkened(0.3) if ins else (cr if minf(float(u), 1.0 - float(u)) < 0.05 else bk.lightened(0.04 * float(v))), 12, 12)
		K._glove(k, sd, ar, bk, bk.lightened(0.1))


# ------------------------------------------------------------------ Murasaki Gakusei (ref "Sumire Outfit (Ninja School Version)"): siyah boğazlık ve uzun kol üstüne kısa kabarık kollu lavanta elbise
## (beyaz denizci yakası, V ucunda beyaz düğümlü mor fular, belde geniş koyu mor kuşak, önde ters pli açılan A etek), mor şort, uyluk ortasına çıkan siyah çorap,
## sağ uylukta beyaz sargı + siyah kılıf
static func _sumire_okul(k) -> void:
	var lv := Color(0.722, 0.659, 0.894)
	var dp := Color(0.43, 0.3, 0.7)
	var mg := Color(0.55, 0.15, 0.42)
	var wh := Color(0.95, 0.95, 0.96)
	var bk := Color(0.11, 0.11, 0.125)
	var sh := Color(0.478, 0.353, 0.722)
	var hb := Color(0.12, 0.12, 0.14)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var hp: Vector3 = b["hp"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._stand(k, b, 0.05, 0.004, bk)
	# şort + çoraplar
	AN._lowseat(k, b, H + 0.06, sh)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.6 if sd == "Left" else 1.7
		var s1: float = kn * 0.22
		var ad: Callable = R._short_leg(k, le, sh, s1, 0.01, 0.006, sv)
		R._hem_roll(k, le, ad, s1, sh.darkened(0.06), 0.018, 0.002)
		var st: float = kn * 0.46
		Y._sock_leg(k, le, bk, st, sv, 0.026)
		if sd == "Right":
			AN._thigh_wrap(k, le, st - 0.07, 3, 0.004, wh)
			I._holster(k, le, func(_s, _a): return 0.011, hb, hb)
	# elbise üstü: boyundan bele
	var tk: Array = Z._tk(k, b, H + 0.06, 0.012, 0.6)
	var tf := func(a: float, y: float) -> float: return 0.006 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.02, H + 0.08, y) + 0.0025 * sin(a * 11.0 + y * 20.0)
	P._cl(k, {"keys": tk, "ny": 26, "na": 96, "top": func(_a): return N + 0.006, "hem": func(_a): return H + 0.06, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return lv, "gain": 6.0, "th": 0.005, "inner": lv.darkened(0.35), "skin": tsk})
	# etek: kuşağın altından uyluk ortasına; önde ters pli
	var hem: float = H - 0.2
	var y0: float = H + 0.085
	var wm: Vector3 = k.M(y0, k.UA)
	var ek := [[y0, wm.x + 0.014, wm.y + 0.016, wm.z - 0.014], [H - 0.04, hp.x + 0.036, hp.y + 0.042, hp.z - 0.042], [hem, hp.x + 0.085, hp.y + 0.085, hp.z - 0.09]]
	var esk := func(p): return Y._msk(k, p, hem)
	var pw := func(y: float) -> float: return 0.1 * smoothstep(H - 0.03, hem, y)
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		var w: float = float(pw.call(y))
		var pl: float = -0.07 * exp(-pow(a / maxf(0.02, w * 0.55), 2.0)) * smoothstep(0.0, 0.25, t) + 0.025 * exp(-pow((absf(a) - w) / 0.05, 2.0)) * t
		return t * (0.016 * sin(a * 6.0 + 0.3) * smoothstep(0.35, 0.8, absf(a)) + 0.008 * sin(a * 11.0 + 1.6)) + 0.003 * sin(a * 9.0 + y * 20.0) + pl
	var eg: Dictionary = P._cl(k, {"keys": ek, "ny": 24, "na": 120, "top": func(_a): return y0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ef.call(float(a), float(y)),
		"col": func(a, y, _v): return dp if absf(float(a)) < float(pw.call(float(y))) * 0.9 else lv, "gain": 6.0, "th": 0.006, "inner": lv.darkened(0.35), "skin": esk})
	P._bd(k, AA._yl(eg["hem"], 0.008), 0.0035, 0.0016, lv.darkened(0.18), true, esk)
	# geniş koyu mor kuşak
	P._sash(k, [P._kp(k.M(H + 0.14, k.UA), H + 0.14, 0.016), P._kp(k.M(H + 0.05, 0.3), H + 0.05, 0.02)], H + 0.095, 0.03, 0.004, dp, 0.12)
	# denizci yakası: önde V'de birleşir, omuzlara yatar, arkada kare kapak
	var vy: float = C - 0.005
	var ctop := func(a: float) -> float: return lerpf(vy, N + 0.008, smoothstep(0.0, 0.95, absf(a)))
	var chem := func(a: float) -> float:
		var u: float = absf(a)
		return lerpf(lerpf(vy - 0.012, N - 0.075, smoothstep(0.0, 1.25, u)), C - 0.075, smoothstep(1.35, 1.95, u))
	var cl: Dictionary = _flat_collar(k, tk, 0.012, func(a): return ctop.call(float(a)), func(a): return chem.call(float(a)), wh, 0.006)
	P._bd(k, AA._yl(cl["hem"], 0.0), 0.003, 0.0018, wh.darkened(0.06), false, nsk)
	# fular: yakanın altından görünen mor bant, V ucunda beyaz düğüm, göğse inen iki uç
	for sg in [1.0, -1.0]:
		var path := []
		for a in [1.15, 0.85, 0.55, 0.28, 0.06]:
			path.append(Vector2(sg * a, float(chem.call(a)) - 0.007))
		Q._run(k, tk, tf, path, 0.008, 0.005, 0.002, mg, tsk, 4)
	var kp: Array = Q._spt(tk, tf, 0.0, vy - 0.016, 0.014)
	var ko: Vector3 = kp[1]
	P._boxr(k, kp[0], Vector3(0.012, 0, 0), Vector3(0, 0.009, 0), ko * 0.008, mg.darkened(0.05), [["UpperChest", 0.7], ["Chest", 0.3]], 0.45)
	var kr := []
	for i in 14:
		var t := TAU * i / 14.0
		kr.append((kp[0] as Vector3) + ko * 0.009 + Vector3(cos(t) * 0.0085, sin(t) * 0.0085, 0.0))
	P._tb(k, kr, func(_s, _a): return 0.0028, func(_s, _a, _p): return wh, func(_s, _p): return [["UpperChest", 0.7], ["Chest", 0.3]], 6, true)
	for e in [[0.02, 0.21, C - 0.165], [-0.02, -0.17, C - 0.16]]:
		var path := [Vector2(float(e[0]), vy - 0.025), Vector2(lerpf(float(e[0]), float(e[1]), 0.5), lerpf(vy - 0.025, float(e[2]), 0.5)), Vector2(float(e[1]), float(e[2]))]
		for w in [[0.017, 0.006, mg], [0.011, 0.0075, mg.lightened(0.05)], [0.005, 0.0086, mg.lightened(0.09)]]:
			Q._run(k, tk, tf, path, float(w[0]), float(w[1]), 0.0018, w[2], tsk, 6)
	# kollar: siyah uzun kol, kabarık kısa kol + beyaz çizgili manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.0 if sd == "Left" else 2.4
		P._lt(k, ar, func(s, a): return 0.004 + 0.0014 * sin(float(a) * 3.0 + float(s) * 30.0 + sv) * smoothstep(0.4, 0.5, float(s)) - 0.003 * smoothstep(0.96, 0.99, float(s)),
			func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.2, 0.985, 26, 16)
		var s1 := 0.3
		var pf := func(s: float, a: float) -> float: return 0.012 + 0.024 * pow(sin(clampf(s / s1, 0.0, 1.0) * PI * 0.85 + 0.15), 1.2) * smoothstep(0.0, 0.08, s) + 0.004 * sin(a * 7.0 + sv) * smoothstep(0.05, 0.15, s)
		P._lt(k, ar, pf, func(s, a, ins): return lv.darkened(0.3) if ins else P._fs(lv, 0.004 * sin(float(a) * 7.0 + sv) * smoothstep(0.05, 0.15, float(s)), 14.0), 0.0, s1, 18, 24, 0.02)
		P._lt(k, ar, func(_s, _a): return 0.0105, func(_s, _a, ins): return wh.darkened(0.2) if ins else wh, s1 - 0.012, s1 + 0.03, 4, 24)
		for s in [s1 + 0.002, s1 + 0.014]:
			P._lt(k, ar, func(_s, _a): return 0.012, func(_s, _a, _i): return lv, s, s + 0.0055, 1, 24)


# ------------------------------------------------------------------ Murasaki Genin (ref "Sumire Outfit Genin Ver."): mor boğazlı koyu iç üst, üstünde önü fermuarlı kolsuz lavanta üst (kalçada açılır, önde
## yırtmaç, beyaz kenar bandı, gri çift çizgili sivri uçlu beyaz geniş yaka), dize inen bol lacivert şort, sağ uylukta beyaz bantlı siyah kılıf, siyah ön kol ısıtıcısı, geniş ağızlı siyah bot
static func _sumire_genin(k) -> void:
	var lv := Color(0.784, 0.722, 0.910)
	var lvd := Color(0.5, 0.38, 0.78)
	var wh := Color(0.95, 0.95, 0.96)
	var gr := Color(0.7, 0.7, 0.75)
	var nv := Color(0.196, 0.188, 0.353)
	var bk := Color(0.11, 0.11, 0.125)
	var zp := Color(0.62, 0.6, 0.66)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var hp: Vector3 = b["hp"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	var skc: Color = Q._skc(k)
	Z._stand(k, b, 0.06, 0.004, lvd)
	# şort + bacak + bot
	AN._lowseat(k, b, H + 0.04, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.2
		var s1: float = kn - 0.03
		var ad: Callable = R._short_leg(k, le, nv, s1, 0.016, 0.018, sv)
		R._hem_roll(k, le, ad, s1, nv.darkened(0.06), 0.02, 0.002)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		var b0: float = kn + 0.24
		P._lt(k, le, func(s, a): return 0.007 + 0.016 * pow(smoothstep(b0 + 0.09, b0, float(s)), 1.5) + 0.0015 * sin(float(a) * 4.0 + float(s) * 30.0) * smoothstep(b0 + 0.06, b0 + 0.12, float(s)),
			func(s, a, ins): return bk.lightened(0.05) if ins else bk.lightened(0.05 * float(float(s) < b0 + 0.012)).darkened(0.08 * maxf(0.0, sin(float(a) * 4.0))), b0, 0.99, 18, 22, 0.03)
		if sd == "Right":
			I._holster(k, le, ad, nv, bk, true)
	# üst: kolsuz, kalçada açılır, önde yırtmaç
	var hem: float = H - 0.075
	var tk: Array = Z._tk(k, b, H + 0.04, 0.013, 0.55)
	tk.append([H - 0.02, hp.x + 0.03, hp.y + 0.038, hp.z - 0.036])
	tk.append([hem, hp.x + 0.05, hp.y + 0.058, hp.z - 0.056])
	var ik := []   # koyu mor iç üst: kol oyuğundan görünür, üstün içinde kalır
	for e in tk.slice(0, tk.size() - 2):
		ik.append([float(e[0]), float(e[1]) - 0.008, float(e[2]) - 0.008, float(e[3]) + 0.008])
	ik.append([H - 0.06, hp.x + 0.004, hp.y + 0.004, hp.z - 0.004])
	SE.body_layer(k, ik, 24, 44, func(_i, _j, _p): return lvd)
	var a0 := 0.88
	var a1 := 1.28
	var cut: float = C - 0.035
	var topf := func(a: float) -> float:
		var u: float = absf(a)
		var sdv: float = smoothstep(a0, a1, u) * (1.0 - smoothstep(PI - a1, PI - a0, u))
		return lerpf(N + 0.004, cut, sdv)
	var tf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return 0.005 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.02, H, y) + 0.0025 * sin(a * 11.0 + y * 20.0) + t * 0.012 * sin(a * 5.0 + 1.1)
	var vs: float = (N + 0.004 - (H + 0.0)) / (N + 0.004 - hem)
	var gap := func(v: float) -> float: return 0.0005 + 0.034 * smoothstep(vs - 0.01, vs + 0.02, v)
	var tsk2 := func(p): return T._ksk(k, p, hem)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 34, "na": 104, "rng": func(v): return Vector2(float(gap.call(float(v))), TAU - float(gap.call(float(v)))), "top": func(a): return topf.call(float(a)),
		"hem": func(_a): return hem, "fold": func(a, y, _v): return tf.call(float(a), float(y)), "col": func(_a, _y, _v): return lv, "gain": 6.0, "th": 0.005, "inner": lv.darkened(0.3), "skin": tsk2})
	P._bd(k, AA._yl(tg["hem"], 0.009), 0.009, 0.0026, wh, false, tsk2)
	var js: int = int(34.0 * vs)
	AA._edge_band(k, (tg["ea"] as Array).slice(js), 0.0075, 0.0022, wh, tsk2, 1.0)
	AA._edge_band(k, (tg["eb"] as Array).slice(js), 0.0075, 0.0022, wh, tsk2, -1.0)
	# fermuar: yakadan yırtmaça
	Q._run(k, tk, tf, [Vector2(0.0, N + 0.0), Vector2(0.0, H + 0.006)], 0.0036, 0.0032, 0.0018, lv.darkened(0.12), tsk, 24)
	Q._run(k, tk, tf, [Vector2(0.0, N + 0.0), Vector2(0.0, H + 0.006)], 0.0013, 0.0052, 0.001, zp, tsk, 24)
	var zt: Array = Q._spt(tk, tf, 0.0, N - 0.012, 0.006)
	P._boxr(k, zt[0], Vector3(0.0045, 0, 0), Vector3(0, 0.011, 0), (zt[1] as Vector3) * 0.0026, zp.lightened(0.15), [["Neck", 0.3], ["UpperChest", 0.7]], 0.3)
	# kol oyuğu biyesi
	for e in [tg["top"]]:
		var pts := []
		for p in e:
			if float(p.y) < N - 0.02:
				pts.append(p)
		if pts.size() > 3:
			P._cord(k, pts, 0.0026, lv.darkened(0.1), false, tsk)
	# geniş yaka: önde fermuarın iki yanında sivri uçlar, omuzlara yatar, arkada kısa kapak; dış kenara yakın iki gri çizgi
	var chem := func(a: float) -> float:
		var u: float = absf(a)
		var fr: float = lerpf(N - 0.004, C + 0.012, smoothstep(0.0, 0.58, u))
		return lerpf(fr, lerpf(C + 0.012, N - 0.055, smoothstep(0.58, 1.25, u)), smoothstep(0.5, 0.66, u)) - 0.025 * smoothstep(1.5, 2.1, u)
	var cl: Dictionary = _flat_collar(k, tk, 0.02, func(_a): return N + 0.006, func(a): return chem.call(float(a)), wh, 0.006)
	P._bd(k, AA._yl(cl["hem"], 0.0), 0.0028, 0.0018, wh.darkened(0.05), false, nsk)
	for up in [0.009, 0.016]:
		var pts := []
		for p in cl["hem"]:
			var aa: float = absf(atan2(float(p.x), float(p.z)))
			if aa > 0.66:
				pts.append((p as Vector3) + Vector3(0, up, 0) + Vector3(p.x, 0.0, p.z).normalized() * 0.0012)
		var runs := [[], []]
		for p in pts:
			runs[0 if float(p.x) > 0.0 else 1].append(p)
		for r2 in runs:
			if r2.size() > 3:
				P._bd(k, r2, 0.0018, 0.0012, gr, false, nsk)
	# kollar: çıplak, siyah ön kol ısıtıcısı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		Z._arm_bare(k, ar)
		var s0: float = en + 0.12
		P._lt(k, ar, func(s, a): return 0.006 + 0.0014 * sin(float(a) * 4.0 + float(s) * 26.0) - 0.0035 * smoothstep(0.95, 0.99, float(s)), func(_s, _a, ins): return bk.lightened(0.04) if ins else bk, s0, 0.975, 14, 18)
		P._lt(k, ar, func(_s, _a): return 0.0078, func(_s, _a, ins): return bk.lightened(0.04) if ins else bk.lightened(0.06), s0, s0 + 0.02, 2, 18)


## Plakalı etek paneli (kusazuri): üst üste binen sıralar; alt sıralar kendi uyluğuna sıkı bağlı (kalkan uyluk paneli deler geçmez, panel uyluğun üstüne yaslanır)
static func _kz(k, hp: Vector3, y0: float, ac: float, aw: float, n: int, h: float, ovl: float, add: float, flare: float, col: Color, trim: Color, lace: Color) -> void:
	var total: float = n * (h - ovl) + ovl
	var W: float = hp.x + add
	var Fz: float = hp.y + add
	var B: float = absf(hp.z) + add
	var skf := func(p: Vector3) -> Array:
		var t: float = clampf((y0 - p.y) / total, 0.0, 1.0)
		var w: float = 0.97 * smoothstep(0.0, 0.42, t)
		var sx: float = smoothstep(-0.025, 0.025, p.x)
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * sx], ["RightUpperLeg", w * (1.0 - sx)]]
	var pt := func(a: float, y: float, off: float) -> Vector3:
		var t: float = (y0 - y) / total
		var q: Vector2 = SE.El.sup(a, W, Fz, -B, 2.3)
		var sc: float = 1.0 + flare * t
		return Vector3(q.x * sc, y, q.y * sc) + Vector3(q.x, 0.0, q.y).normalized() * off
	for i in n:
		var yt: float = y0 - i * (h - ovl)
		var yb: float = yt - h
		var pf := func(u: float, v: float) -> Vector3: return pt.call(ac + aw * (2.0 * u - 1.0), lerpf(yt, yb, v), lerpf(-0.004, 0.008, v) + 0.0035 * i)
		var nf := func(u: float, _v: float) -> Vector3:
			var q: Vector2 = SE.El.sup(ac + aw * (2.0 * u - 1.0), W, Fz, -B, 2.3)
			return Vector3(q.x, 0.1, q.y).normalized()
		L._shell(k, pf, nf, 16, 5, 0.008, func(_u, v, e): return trim if e or float(v) > 0.88 else col.darkened(0.07 * float(v)), func(_u, _v, p): return skf.call(p))
		for u in [0.18, 0.5, 0.82]:
			var a: float = ac + aw * (2.0 * float(u) - 1.0)
			var ym: float = yt - h * 0.45
			if u == 0.5:
				var c: Vector3 = pt.call(a, ym, 0.0115 + 0.0035 * i)
				P._stud(k, c, Vector3(c.x, 0.0, c.z).normalized(), 0.0036, lace, skf.call(c))
			else:
				var c0: Vector3 = pt.call(a, ym + 0.012, 0.012 + 0.0035 * i)
				var c1: Vector3 = pt.call(a, ym - 0.012, 0.013 + 0.0035 * i)
				P._cord(k, [c0, c0.lerp(c1, 0.5) + Vector3(c0.x, 0.0, c0.z).normalized() * 0.002, c1], 0.003, lace, false, skf, 0.0, 6)
