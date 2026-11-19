extends RefCounted
## Elle modellenmiş setler, parti ai: ss_sis_striker_siyah, ss_yilan_zirh, ss_yilan_kimono, ss_kurucu_palto, ss_kurucu_genc, ss_turuncu_esofman. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{mist_striker (3. görsel), mitsuki_battle_garb, mitsuki_outfit, nagato_outfit_akatsuki_founder_ver, nagato_outfit_young_ver, naruto_outfit}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), l (L), m (M), q (Q), s (S), t (T), ab (AB) dosyalarından; burada satranç piyonu kesiği, damalı kese, kayış halkası ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const AB = preload("res://scripts/actors/set_el_ab.gd")

const DONE := ["ss_sis_striker_siyah", "ss_yilan_zirh", "ss_yilan_kimono", "ss_kurucu_palto", "ss_kurucu_genc", "ss_turuncu_esofman"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_sis_striker_siyah": _kiri_kuro(k)
		"ss_yilan_zirh": _hebi_yoroi(k)
		"ss_yilan_kimono": _hebi_kimono(k)
		"ss_kurucu_palto": _soshi_gaito(k)
		"ss_kurucu_genc": _soshi_wakate(k)
		"ss_turuncu_esofman": _daidai(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Kol uzvu: omuz kökündeki ilk ölçüler gövde köşelerini de sayar; geniş kolun kökü omuz üstünde boynuz gibi kalkmasın diye sınırlanır
static func _arm(k, sd: String) -> Dictionary:
	var ar: Dictionary = P._limb(k, sd, false)
	var rad: Array = (ar["rad"] as Array).duplicate()
	var cap: float = float(rad[3]) * 1.08
	for i in 3:
		rad[i] = minf(float(rad[i]), lerpf(cap * 1.06, cap, float(i) / 2.0))
	ar["rad"] = rad
	return ar


## Satranç piyonu biçimli kabartma (yuvarlak baş + tabana genişleyen gövde). mp(u, v, kalkış) yüzey eşlemesi, v yukarı
static func _pawn(k, mp: Callable, o: Vector3, s: float, col: Color, skinf: Callable) -> void:
	var rows := []
	var yc: float = 0.036 * s
	var r: float = 0.0082 * s
	for j in 13:
		var y: float = float(j) / 12.0 * (yc + r)
		var hw: float
		if y > yc - r * 0.72:
			hw = sqrt(maxf(0.0, r * r - pow(y - yc, 2.0)))
		else:
			hw = lerpf(0.0078 * s, 0.0031 * s, smoothstep(0.0, yc - r * 0.72, y))
		hw = maxf(hw, 0.0005)
		var ro := []
		for i in 5:
			var u: float = float(i) / 4.0 * 2.0 - 1.0
			ro.append(mp.call(u * hw, y, 0.0012 + 0.0014 * (1.0 - u * u)))
		rows.append(ro)
	Q._mesh(k, rows, false, func(_i, _j, _p): return col, func(_i, _j, p): return skinf.call(p), o)


## Damalı kapak: açık zemin üstünde koyu kare kabartmalar
static func _checker(k, c: Vector3, o: Vector3, w: float, h: float, d: float, base: Color, dark: Color, bones: Array, nx := 5, ny := 3) -> void:
	var ux: Vector3 = Vector3.UP.cross(o).normalized()
	var uy: Vector3 = o.cross(ux).normalized()
	P._boxr(k, c, ux * w, uy * h, o * d, base, bones, 0.2)
	for i in nx:
		for j in ny:
			if (i + j) % 2 != 0:
				continue
			var q: Vector3 = c + o * (d * 0.92) + ux * ((float(i) + 0.5) / nx * 2.0 - 1.0) * w * 0.86 + uy * ((float(j) + 0.5) / ny * 2.0 - 1.0) * h * 0.8
			P._boxr(k, q, ux * (w * 0.86 / nx), uy * (h * 0.8 / ny), o * 0.0016, dark, bones, 0.12)


## Kayış üstünde enine halka (gövde yüzeyinde iki komşu yol noktasından)
static func _keeper(k, p0: Vector3, p1: Vector3, o: Vector3, w: float, col: Color, bones: Array) -> void:
	var d: Vector3 = (p1 - p0).normalized()
	var ux: Vector3 = o.cross(d).normalized()
	P._boxr(k, p0 + o * 0.003, ux * w, d * 0.0062, o * 0.0042, col, bones, 0.3)


## (açı, y) yolu boyunca yüzey noktaları
static func _path_pts(keys: Array, ff: Callable, ctrl: Array, lift: float, steps := 8) -> Array:
	var out := []
	for q in P._path(ctrl, steps):
		out.append(Q._spt(keys, ff, q.x, q.y, lift))
	return out


static func _box_at(k, e: Array, w: float, h: float, d: float, col: Color, bones: Array, rc := 0.3) -> void:
	var o: Vector3 = e[1]
	var ux: Vector3 = Vector3.UP.cross(o).normalized()
	P._boxr(k, (e[0] as Vector3) + o * d, ux * w, Vector3.UP * h, o * d, col, bones, rc)


# ------------------------------------------------------------------ Kiri Striker: Siyah (ref Shinobi Striker "Mist Striker" siyah renk türevi): boynu saran iri siyah atkı yaka (önde bindirme + iki çıtçıt),
## uyluğa inen tunik: önde ve arkada üç dikey dilimli gri panel (sarı biyeli), yanları siyah, etek ucunda beyaz satranç piyonu kesikleri; beyaz kabarık kısa kollar,
## dirsekten bileğe gri çizgili siyah kol ısıtıcı, açık gri kemer + sarı halkalar, sağ omuzdan sol kalçaya siyah kayış (sarı halkalı), solda damalı kapaklı kese,
## yanında gri şerit olan bol siyah pantolon, gri çizgili siyah bacak ısıtıcı
static func _kiri_kuro(k) -> void:
	var bk := Color(0.085, 0.085, 0.095)
	var gy := Color(0.58, 0.58, 0.6)
	var gl := Color(0.8, 0.8, 0.82)
	var wh := Color(0.93, 0.93, 0.92)
	var ye := Color(0.9, 0.74, 0.18)
	var bt := Color(0.84, 0.84, 0.86)
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
	K._seat(k, b, bk)
	# bol pantolon (dış yanda gri şerit) + baldırda gri çizgili ısıtıcı
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 1.3 if sd == "Left" else 0.5
		var tk: float = kn + 0.12
		var ad: Callable = AB._baggy(k, le, bk.lightened(0.03), 0.014, 0.045, tk, sv, 0.25, 0.24)
		var oa: float = J._outer_a(le, 0.25, Vector3(sg, 0.0, 0.0))
		S._lstrip(k, le, 0.07, tk - 0.045, func(_s): return oa, func(s, a): return float(ad.call(s, a)), 0.013, 0.0016, gy, 22)
		var wf := func(s: float, a: float) -> float: return 0.011 + 0.004 * (1.0 - smoothstep(tk - 0.03, tk + 0.02, s)) + 0.001 * sin(a * 8.0) + 0.002 * smoothstep(0.95, 0.99, s)
		P._lt(k, le, wf, func(_s, a, ins): return bk.darkened(0.4) if ins else bk.lightened(0.03 * sin(float(a) * 8.0)), tk - 0.035, 0.995, 18, 24)
		Q._ring_on(k, le, tk - 0.02, wf, 0.009, bk.lightened(0.07), 0.003)
		var fa: float = J._outer_a(le, kn + 0.3, Vector3(sg * 0.4, 0.0, 1.0).normalized())
		for da in [-0.36, 0.36]:
			S._lstrip(k, le, tk - 0.005, 0.955, func(_s): return fa + float(da), wf, 0.0065, 0.0016, gy, 12)
		Q._ring_on(k, le, 0.972, wf, 0.007, gy.darkened(0.1), 0.0025)
	# kollar: siyah iç kol, beyaz kabarık kısa kol, dirsekten bileğe ısıtıcı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 0.7 if sd == "Left" else 2.0
		P._lt(k, ar, func(_s, _a): return 0.003, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.25, 0.96, 16, 16)
		var s1: float = en - 0.05
		var pf := func(s: float, a: float) -> float:
			var t: float = clampf(s / s1, 0.0, 1.0)
			var dn: float = maxf(0.0, -sin(a) * sg)
			return 0.016 + 0.022 * pow(sin(t * PI * 0.62), 0.8) + 0.008 * t * dn + (0.003 + 0.005 * t) * P._lf(s, a, sv)
		P._lt(k, ar, pf, func(s, a, ins): return wh.darkened(0.16) if ins else P._fs(wh, (0.003 + 0.005 * clampf(float(s) / s1, 0.0, 1.0)) * P._lf(float(s), float(a), sv), 14.0), 0.0, s1, 28, 24, 0.04)
		K._lt_in(k, ar, func(s, a): return float(pf.call(float(s), float(a))) - 0.006, wh.darkened(0.2), s1 - 0.12, s1, 6, 24)
		P._lt(k, ar, func(s, a): return float(pf.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return wh.darkened(0.2) if ins else wh.darkened(0.08), s1 - 0.025, s1 + 0.001, 3, 24)
		var wf := func(s: float, a: float) -> float: return 0.008 + 0.003 * smoothstep(0.9, 0.94, s) + 0.0012 * sin(a * 6.0)
		P._lt(k, ar, wf, func(_s, _a, ins): return bk.darkened(0.4) if ins else bk, en - 0.12, 0.945, 20, 20)
		var oa: float = J._outer_a(ar, 0.72, Vector3(sg, 0.0, 0.35).normalized())
		for da in [-0.55, 0.0, 0.55]:
			S._lstrip(k, ar, en - 0.02, 0.93, func(_s): return oa + float(da), wf, 0.0042, 0.0014, gl, 12)
	# tunik: önde / arkada gri dilimli panel, yanlar siyah
	var hem: float = H - 0.14
	var tk2 := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.026), P._kp(hp, H - 0.04, 0.036), [hem, hp.x + 0.07, hp.y + 0.062, hp.z - 0.066]]
	var pw: float = TAU * 8.0 / 96.0
	var tf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.08 - y) / (H + 0.08 - hem), 0.0, 1.0)
		return t * (0.012 * sin(a * 7.0 + 0.5) + 0.005 * sin(a * 13.0 + 1.1)) + (1.0 - t) * 0.004 * sin(a * 5.0 + y * 12.0) * smoothstep(N - 0.05, C - 0.08, y)
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var ssk := func(p): return T._ksk(k, p, hem)
	var tcol := func(a: float) -> Color:
		var w: float = absf(a)
		return gy if w <= pw + 0.001 or w >= PI - pw - 0.001 else bk
	P._cl(k, {"keys": tk2, "ny": 40, "na": 96, "top": func(_a): return N + 0.0, "hem": func(_a): return hem, "fold": tf, "col": func(a, _y, _v): return tcol.call(float(a)), "gain": 5.0, "th": 0.006, "inner": bk.darkened(0.2), "skin": ssk})
	for ac in [0.0, PI]:
		for sg in [1.0, -1.0]:
			Q._run(k, tk2, tff, [Vector2(ac + sg * pw / 3.0, N - 0.045), Vector2(ac + sg * pw / 3.0, hem + 0.003)], 0.0017, 0.0015, 0.0012, gl, ssk, 20)
			Q._run(k, tk2, tff, [Vector2(ac + sg * (pw + 0.012), N - 0.03), Vector2(ac + sg * (pw + 0.012), hem + 0.003)], 0.0042, 0.002, 0.0022, ye, ssk, 20)
	# etek ucunda beyaz piyon kesikleri
	for a in [0.82, 1.08, -0.82, -1.08, PI - 0.84, -(PI - 0.84)]:
		var e: Array = Q._spt(tk2, tff, float(a), hem + 0.006)
		_pawn(k, Q._local(tk2, tff, float(a), hem + 0.006), e[1], 1.0, wh, ssk)
	# kemer + sarı halkalar
	var by: float = H + 0.1
	var bp := []
	for i in 96:
		bp.append(Q._spt(tk2, tff, TAU * i / 96.0 - PI, by, 0.004)[0])
	P._bd(k, bp, 0.017, 0.0045, bt, true, tsk)
	var bsk: Array = k.torso_skin(by)
	for a in [-0.36, 0.3]:
		var e: Array = Q._spt(tk2, tff, float(a), by, 0.009)
		P._boxr(k, e[0], Vector3.UP.cross(e[1]).normalized() * 0.0085, Vector3.UP * 0.022, (e[1] as Vector3) * 0.004, ye, bsk, 0.25)
	# çapraz kayış: sağ omuzdan sol kalçaya, sırtta da iner
	var sl := 0.007
	var front := [Vector2(-0.66, N - 0.06), Vector2(-0.5, N - 0.08), Vector2(-0.2, C - 0.02), Vector2(0.45, H + 0.2), Vector2(0.98, by + 0.004)]
	var back := [Vector2(-(PI - 0.66), N - 0.06), Vector2(-(PI - 0.5), N - 0.08), Vector2(-(PI - 0.12), C - 0.04), Vector2(-(PI + 0.5), H + 0.2), Vector2(-(PI + 0.98), by + 0.004)]
	var scol: Color = bk.lightened(0.07)
	Q._run(k, tk2, tff, front, 0.021, sl, 0.004, scol, tsk, 8)
	Q._run(k, tk2, tff, back, 0.021, sl, 0.004, scol, tsk, 8)
	var fp: Array = _path_pts(tk2, tff, front, sl + 0.004, 8)
	for ii in [9, 13]:
		_keeper(k, fp[ii][0], fp[ii + 1][0], fp[ii][1], 0.021, ye, k.torso_skin((fp[ii][0] as Vector3).y))
	# kese: siyah gövde, damalı kapak; yanında küçük ikinci göz
	for e2 in [[1.12, 0.03, 0.026], [1.44, 0.016, 0.022]]:
		var pe: Array = Q._spt(tk2, tff, float(e2[0]), by - 0.032, 0.012)
		var o: Vector3 = pe[1]
		var ux: Vector3 = Vector3.UP.cross(o).normalized()
		P._boxr(k, (pe[0] as Vector3) + o * 0.012, ux * float(e2[1]), Vector3.UP * float(e2[2]), o * 0.012, bk.lightened(0.05), [["Hips", 1.0]], 0.3)
		_checker(k, (pe[0] as Vector3) + o * 0.021 + Vector3.UP * (float(e2[2]) * 0.62), o, float(e2[1]) * 1.04, 0.011, 0.0035, wh, bk, [["Hips", 1.0]], 5 if float(e2[1]) > 0.02 else 3, 2)
	# atkı yaka: boynu saran iri rulo, önde bindirme + iki çıtçıt
	var q: float = Q._hq(k)
	var ytop: float = N + 0.058 * q
	var cw := [[ytop, nk.x + 0.04, nk.y + 0.045, nk.z - 0.04], [N + 0.03 * q, nk.x + 0.058, nk.y + 0.064, nk.z - 0.055], [N - 0.03, ch.x * 0.86, ch.y * 1.0, ch.z * 1.0], [N - 0.09, ch.x * 1.1, ch.y * 1.1, ch.z * 1.12]]
	var hmf := func(a: float) -> float: return N - 0.075 - 0.015 * cos(a)
	var cf := func(a: float, y: float, v: float) -> float: return 0.05 * sin(v * PI) * (0.75 + 0.25 * cos(a)) + 0.012 * sin(a * 5.0 + 0.8) * v + 0.006 * sin(a * 9.0 + y * 20.0)
	var cff := func(a, y):
		var v: float = clampf(inverse_lerp(ytop, float(hmf.call(float(a))), float(y)), 0.0, 1.0)
		return cf.call(float(a), float(y), v)
	var cg: Dictionary = P._cl(k, {"keys": cw, "ny": 16, "na": 72, "top": func(_a): return ytop, "hem": hmf, "fold": cf, "col": func(_a, _y, _v): return bk, "gain": 7.0, "th": 0.008, "inner": bk.lightened(0.04), "skin": nsk})
	P._cord(k, cg["top"], 0.0065, bk.lightened(0.04), true, nsk)
	var fg: Dictionary = P._cl(k, {"keys": cw, "ny": 14, "na": 14, "rng": func(_v): return Vector2(-0.34, 0.17), "top": func(_a): return ytop - 0.002, "hem": hmf, "fold": cf, "lift": 0.0055,
		"col": func(_a, _y, _v): return bk.lightened(0.02), "gain": 7.0, "th": 0.004, "inner": bk.darkened(0.2), "skin": nsk})
	P._cord(k, fg["eb"], 0.0024, gl.darkened(0.15), false, nsk)
	for yy in [ytop - 0.022, lerpf(ytop, N - 0.06, 0.48)]:
		var e3: Array = Q._spt(cw, cff, 0.11, yy, 0.0075)
		P._stud(k, e3[0], e3[1], 0.0045, wh, nsk.call(e3[0]))


# ------------------------------------------------------------------ Hebi Yoroi (ref Shinobi Striker "Mitsuki Battle Garb"): dik yakalı koyu gri tulum, üstünde ayrı açık gri plakalar: iki göğüs yarımı + yaka dilleri,
## iki karın bandı, kasığa doğru daralan altıgen alt plaka, sırtta levha ve bantlar, yanlarda bağ kayışı, perçinli yuvarlak omuzluklar; koyu eldiven, dize çıkan bot
static func _hebi_yoroi(k) -> void:
	var su := Color(0.227, 0.227, 0.251)
	var pl := Color(0.79, 0.79, 0.83)
	var pd := Color(0.56, 0.56, 0.62)
	var gv := Color(0.13, 0.13, 0.15)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = L._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# tulum gövdesi: dik yaka, karında kırışık
	var ik := [L._kp(nk, N + 0.072, 0.012, 0.014), L._kp(nk, N + 0.03, 0.018), [N - 0.05, ch.x * 0.86, ch.y * 0.84, ch.z * 0.93], L._kp(ch, C - 0.03, 0.012), L._kp(wa, H + 0.12, 0.013), L._kp(hp, H - 0.1, 0.013)]
	var sf := func(a: float, y: float, _v: float) -> float: return 0.007 * sin(a * 9.0 + y * 12.0) * smoothstep(C - 0.1, H + 0.1, y) + 0.004 * sin(a * 5.0 - y * 20.0) * smoothstep(N - 0.02, C, y)
	var sg0: Dictionary = P._cl(k, {"keys": ik, "ny": 30, "na": 56, "top": func(_a): return N + 0.072, "hem": func(_a): return H - 0.1, "fold": sf, "col": func(_a, _y, _v): return su, "gain": 7.0, "th": 0.0, "skin": func(p): return Q._nsk(k, p)})
	P._cord(k, sg0["top"], 0.0035, su.darkened(0.15), true, func(p): return Q._nsk(k, p))
	K._seat(k, b, su)
	# kollar + eldiven
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var sv: float = 0.6 if lk == "aL" else 1.9
		var rip := func(s: float, a: float) -> float: return 0.007 + 0.004 * P._lf(s, a, sv) * smoothstep(0.15, 0.3, s) + 0.007 * exp(-pow((s - kn) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		P._lt(k, l, rip, func(s, a, ins): return su.darkened(0.35) if ins else P._fs(su, float(rip.call(float(s), float(a))) - 0.007, 14.0), 0.0, 0.93, 32, 20)
		S._mitt(k, l["sd"], l, gv)
		P._lt(k, l, func(s, _a): return 0.012 + 0.003 * smoothstep(0.86, 0.9, float(s)), func(_s, _a, ins): return gv.darkened(0.3) if ins else gv, 0.84, 0.905, 5, 20)
	# bacaklar: düz paça, dize çıkan bot
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var sv: float = 1.6 if lk == "lL" else 0.4
		var pa: Callable = K._pant(k, l, su, 0.012, 0.022, kn + 0.12, sv)
		var bf := func(s: float, a: float) -> float: return 0.016 + 0.006 * (1.0 - smoothstep(kn + 0.06, kn + 0.12, s)) + 0.003 * cos(a) - 0.002 * smoothstep(0.9, 0.99, s)
		P._lt(k, l, bf, func(s, a, ins): return su.darkened(0.4) if ins else su.darkened(0.14 - 0.06 * cos(float(a)) * float(float(s) < kn + 0.1)), kn + 0.06, 0.995, 22, 22)
		Q._ring_on(k, l, kn + 0.075, bf, 0.01, su.darkened(0.2), 0.003)
	# zırh
	var dk: Array = L._tk(k, b, 0.024, H + 0.0, 0.0, 0.0)
	var ty := func(a: float) -> float: return N - 0.035 - 0.05 * smoothstep(0.25, 1.1, absf(sin(a)))
	for sg in [1.0, -1.0]:
		L._torso_plate(k, dk, sg * 0.535, 0.5, N - 0.035, C - 0.075, 0.004, 0.012, pl, pd, 16, 10, ty)
	L._torso_plate(k, dk, PI, 1.1, N - 0.04, C - 0.09, 0.004, 0.012, pl, pd, 28, 10, func(a): return ty.call(float(a) - PI))
	for e in [[C - 0.1, C - 0.142], [C - 0.157, C - 0.199]]:
		L._torso_plate(k, dk, 0.0, 0.64, float(e[0]), float(e[1]), 0.004, 0.011, pl, pd, 18, 5)
		L._torso_plate(k, dk, PI, 0.7, float(e[0]), float(e[1]), 0.004, 0.011, pl, pd, 18, 5)
	# yaka dilleri
	for sg in [1.0, -1.0]:
		L._torso_plate(k, ik, sg * 0.3, 0.13, N + 0.026, N - 0.03, 0.006, 0.008, pl, pd, 8, 5)
		L._rail(k, ik, [Vector2(sg * 0.3, N + 0.018), Vector2(sg * 0.3, N - 0.022)], 0.0016, 0.0145, 0.001, pd.darkened(0.3), 4)
	# yan bağ kayışları
	for sg in [1.0, -1.0]:
		L._rail(k, dk, [Vector2(sg * 1.2, N - 0.075), Vector2(sg * 1.35, C - 0.05), Vector2(sg * 1.4, C - 0.2)], 0.006, 0.006, 0.002, su.darkened(0.35), 8)
	# alt plaka: göbekten kasığa daralan altıgen (iki bacağın ortalamasını izler)
	var lk2 := [P._kp(wa, C - 0.19, 0.03), P._kp(hp, H - 0.03, 0.04), [H - 0.15, hp.x * 0.82, hp.y + 0.04, hp.z * 0.8]]
	var y0: float = C - 0.212
	var y1: float = H - 0.145
	var awf := func(v: float) -> float: return lerpf(0.74, 0.82, smoothstep(0.0, 0.3, v)) * (1.0 - 0.6 * smoothstep(0.38, 1.0, v))
	var psk := func(p: Vector3) -> Array:
		if p.y >= H:
			return k.torso_skin(p.y)
		var w: float = 0.42 * clampf((H - p.y) / (H - y1), 0.0, 1.0)
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * 0.5], ["RightUpperLeg", w * 0.5]]
	L._shell(k, func(u: float, v: float) -> Vector3:
		return L._sa(lk2, float(awf.call(v)) * (2.0 * u - 1.0), lerpf(y0, y1, v), 0.004)[0], func(u: float, v: float) -> Vector3:
		return L._sa(lk2, float(awf.call(v)) * (2.0 * u - 1.0), lerpf(y0, y1, v))[1], 20, 12, 0.012, func(_u, v, e):
		return pd if e or float(v) < 0.04 or float(v) > 0.95 else pl.darkened(0.05 * float(v)), func(_u, _v, p): return psk.call(p))
	# omuzluklar: omuz başını saran yuvarlak plaka, enine sırt + iki perçin
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var sg: float = l["sg"]
		var sj: float = l["sj"]
		var oa: float = J._outer_a(l, sj + 0.05, Vector3(sg, 0.8, 0.0).normalized())
		var s0: float = maxf(0.0, sj - 0.035)
		var s1: float = sj + 0.15
		var padf := func(s: float, a: float) -> float: return 0.02 + 0.014 * cos(a - oa) * (1.0 - smoothstep(s1 - 0.07, s1, s))
		K._shell(k, l, s0, s1, oa - 1.3, oa + 1.3, padf, 0.009, func(_u, v, e): return pd if e or float(v) > 0.92 or float(v) < 0.05 else pl.darkened(0.05 * float(v)), 12, 18)
		var rp := []
		var ro := []
		for i in 13:
			var a: float = oa + lerpf(-1.05, 1.05, float(i) / 12.0)
			var e2: Array = K._lsurf(l, sj + 0.075, a, float(padf.call(sj + 0.075, a)) + 0.009)
			rp.append(e2[0])
			ro.append(e2[1])
		k.strip(rp, ro, 0.0028, 0.0018, pd, false, func(_p): return P._lskin(l, sj + 0.075))
		for da in [-0.55, 0.55]:
			var e3: Array = K._lsurf(l, sj + 0.03, oa + float(da), float(padf.call(sj + 0.03, oa + float(da))) + 0.009)
			P._stud(k, e3[0], e3[1], 0.0045, pl.lightened(0.08), P._lskin(l, sj + 0.03))


# ------------------------------------------------------------------ Hebi Kimono (ref Shinobi Striker "Mitsuki Outfit" mavi): uyluk ortasına inen kimono, sol kanat (mavi) sağın (beyaz) üstüne biner,
## yakadan etek ucuna inen geniş beyaz yaka bandı, bileğe inen geniş kollar (sol mavi, sağ beyaz), bölmeli geniş kahve kemer + hilal plaka, sırtta kese,
## parmaksız siyah eldiven, dizde toplanan lacivert pantolon, baldıra çıkan siyah bot
static func _hebi_kimono(k) -> void:
	var bl := Color(0.165, 0.478, 0.816)
	var wt := Color(0.86, 0.9, 0.94)
	var nv := Color(0.141, 0.188, 0.416)
	var br := Color(0.58, 0.47, 0.4)
	var bd := Color(0.36, 0.27, 0.22)
	var bk := Color(0.08, 0.08, 0.09)
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
	M._inner_v(k, b, wt.darkened(0.08))
	K._seat(k, b, nv)
	# pantolon: dizde toplanır, altında bot
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 2.2 if sd == "Left" else 0.9
		var tk: float = kn + 0.16
		AB._baggy(k, le, nv, 0.016, 0.04, tk, sv, 0.3, 0.25)
		var bf := func(s: float, a: float) -> float: return 0.013 + 0.005 * (1.0 - smoothstep(tk - 0.02, tk + 0.04, s)) + 0.0016 * sin(a * 5.0 + s * 30.0) * smoothstep(tk + 0.05, 0.9, s)
		P._lt(k, le, bf, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, tk - 0.03, 0.995, 20, 22)
		Q._ring_on(k, le, tk - 0.016, bf, 0.008, bk.lightened(0.05), 0.003)
	# kimono
	var hem: float = lerpf(H, KN, 0.42)
	var keys := [P._kp(nk, N + 0.01, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.04, 0.046), [hem, hp.x + 0.075, hp.y + 0.066, hp.z - 0.075]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.02 * sin(a * 6.0 + 0.3) + 0.008 * sin(a * 11.0 + 1.2)) + 0.007 * sin(a * 5.0 + y * 12.0) * smoothstep(H + 0.3, H + 0.05, y) + 0.004 * sin(a * 4.0 - y * 18.0) * smoothstep(C - 0.02, N - 0.04, y)
	var top: float = keys[0][0]
	var wcol := func(a: float, y: float) -> Color: return bl if a > lerpf(-0.53, -0.38, smoothstep(C - 0.03, top, y)) else wt
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(a, y, v): return (wcol.call(float(a), float(y)) as Color).darkened(0.1 * smoothstep(0.95, 1.0, float(v))), "fold": fold, "band": wt.lightened(0.04), "band_w": 0.021,
		"ny": 44, "na": 62, "gain": 5.0, "low": -0.5})
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		var hm := []
		for p in g["hem"]:
			hm.append((p as Vector3) + Vector3(0, 0.007, 0))
		P._bd(k, hm, 0.004, 0.0016, (bl if lf else wt).darkened(0.18), false, func(p): return M._wrap_skin(k, p, hem, lf))
	var kff := func(a, y): return fold.call(float(a), float(y), 0.0)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, kff, [Vector2(sg * PI * 0.5, C - 0.08), Vector2(sg * PI * 0.52, H), Vector2(sg * PI * 0.53, hem + 0.02)], 0.0022, 0.0012, 0.0012, (bl if sg > 0.0 else wt).darkened(0.2), func(p): return M._wrap_skin(k, p, hem, true), 8)
	# geniş kollar + parmaksız eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = _arm(k, sd)
		var sc: Color = bl if sd == "Left" else wt
		AB._wsleeve(k, ar, func(_s, _a): return sc, sc.darkened(0.2), 0.9, 0.052, 0.032, 1.5 if sd == "Left" else 0.4)
		P._lt(k, ar, func(s, _a): return 0.004 + 0.004 * smoothstep(0.84, 0.9, float(s)), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.6, 0.93, 12, 18)
		S._mitt(k, sd, ar, bk)
	# geniş kemer: bölmeli kahve deri, önde solda hilal plakası, sırtta kese
	var by: float = H + 0.085
	var bh: float = 0.045
	var bsk: Array = k.torso_skin(by)
	var bg: Dictionary = P._cl(k, {"keys": keys, "ny": 6, "na": 88, "top": func(_a): return by + bh, "hem": func(_a): return by - bh, "lift": 0.014,
		"fold": func(a, y, v): return 0.004 * sin(float(v) * PI) + float(fold.call(float(a), float(y), 0.0)), "col": func(_a, _y, _v): return br, "gain": 4.0, "th": 0.004, "inner": bd, "skin": tsk})
	P._cord(k, bg["top"], 0.0032, bd, true, tsk)
	P._cord(k, bg["hem"], 0.0032, bd, true, tsk)
	for a in [-2.2, -1.4, -0.72, -0.1, 0.62, 1.3, 2.05, PI]:
		var pts := []
		var ou := []
		for j in 5:
			var e: Array = Q._spt(keys, kff, float(a), lerpf(by + bh - 0.004, by - bh + 0.004, float(j) / 4.0), 0.0175)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, 0.0034, 0.0026, bd, false, tsk)
	var pe: Array = Q._spt(keys, kff, 0.3, by, 0.018)
	var po: Vector3 = pe[1]
	var pux: Vector3 = Vector3.UP.cross(po).normalized()
	var pc: Vector3 = (pe[0] as Vector3) + po * 0.004
	P._boxr(k, pc, pux * 0.03, Vector3.UP * 0.036, po * 0.004, br.lightened(0.12), bsk, 0.2)
	var arc := []
	var aro := []
	for i in 15:
		var t: float = lerpf(0.75, TAU - 0.75, float(i) / 14.0)
		arc.append(pc + po * 0.0045 + pux * cos(t) * 0.0145 + Vector3.UP * sin(t) * 0.0165)
		aro.append(po)
	k.strip(arc, aro, 0.0042, 0.0022, wt, false, func(_p): return bsk)
	P._boxr(k, pc + po * 0.0045 + pux * 0.0035, pux * 0.0055, Vector3.UP * 0.0068, po * 0.0018, wt, bsk, 0.5)
	var pb: Array = Q._spt(keys, kff, PI, by - 0.005, 0.03)
	_box_at(k, pb, 0.055, 0.036, 0.016, bd.lightened(0.05), bsk, 0.35)


# ------------------------------------------------------------------ Sōshi Gaitō (ref Shinobi Striker "Nagato Outfit (Akatsuki Founder Ver.)"): baldıra inen önü kapalı siyah palto (çeneye çıkan dik yaka,
## yakadan etek ucuna inen ince kızıl şerit, mor astarlı geniş kollar), belde gri geniş kuşak + üstte katlı kapak, kahve kemer + iki ip halka, sırtta kese, sağ yanda kılıç kını,
## siyah pantolon, baldırda beyaz sargı
static func _soshi_gaito(k) -> void:
	var bk := Color(0.078, 0.078, 0.094)
	var rd := Color(0.78, 0.1, 0.12)
	var gy := Color(0.38, 0.4, 0.47)
	var br := Color(0.3, 0.15, 0.13)
	var ln := Color(0.46, 0.38, 0.64)
	var wh := Color(0.86, 0.86, 0.88)
	var tn := Color(0.78, 0.72, 0.6)
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
	var nsk := func(p): return Q._nsk(k, p)
	K._seat(k, b, bk)
	# pantolon + baldır sargısı
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.8 if sd == "Left" else 0.7
		K._pant(k, le, bk.lightened(0.02), 0.01, 0.012, 1.0, sv)
		P._lt(k, le, func(_s, _a): return 0.0105, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.14), kn + 0.1, 0.985, 16, 18)
		P._wraps(k, le, kn + 0.115, 0.97, 11, 0.012, 0.0125, wh, 0.008)
	# palto: tek parça kapalı, baldıra iner
	var hem: float = lerpf(KN, F, 0.3)
	var keys := [P._kp(nk, N + 0.012, 0.032), [N - 0.055, ch.x * 1.04, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.04), P._kp(hp, H - 0.04, 0.05),
		[KN + 0.05, hp.x + 0.07, hp.y + 0.064, hp.z - 0.085], [hem, hp.x + 0.092, hp.y + 0.074, hp.z - 0.112]]
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.02 - y) / (H + 0.02 - hem), 0.0, 1.0)
		return pow(t, 0.9) * (0.026 * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9)) * smoothstep(0.05, 0.3, absf(a)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
	var csk := func(p): return T._bsk(k, p, hem)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 54, "na": 96, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 4.5, "th": 0.006, "inner": bk.lightened(0.05), "skin": csk})
	P._cur_hem = hem
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, hm, 0.003, 0.0016, bk.lightened(0.06), true, csk)
	Q._run(k, keys, ff, [Vector2(-0.04, N + 0.01), Vector2(-0.04, hem + 0.004)], 0.0042, 0.003, 0.0022, rd, csk, 30)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.5, C + 0.0), Vector2(sg * 1.52, H + 0.0), Vector2(sg * 1.55, hem + 0.02)], 0.0024, 0.0014, 0.0014, bk.lightened(0.07), csk, 12)
	Q._run(k, keys, ff, [Vector2(PI, N - 0.02), Vector2(PI, hem + 0.02)], 0.0024, 0.0014, 0.0014, bk.lightened(0.07), csk, 20)
	# dik yaka: çeneye çıkar, ağzı dışa açılır
	var q: float = Q._hq(k)
	var kb: Array = SE.El.key_at(keys, N - 0.006)
	var ck := [[N + 0.098 * q, nk.x + 0.06, nk.y + 0.066, nk.z - 0.052], [N + 0.048 * q, nk.x + 0.045, nk.y + 0.05, nk.z - 0.044], [N - 0.006, float(kb[1]) + 0.005, float(kb[2]) + 0.006, float(kb[3]) - 0.006]]
	var clf := func(a: float, _y: float, v: float) -> float: return 0.012 * sin(a * 4.0 + 0.4) * (1.0 - float(v))
	var clg: Dictionary = P._cl(k, {"keys": ck, "ny": 12, "na": 60, "top": func(a): return N + q * lerpf(0.088, 0.1, smoothstep(0.3, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.006, "fold": clf,
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.007, "inner": bk.lightened(0.05), "skin": nsk})
	P._cord(k, clg["top"], 0.004, bk.lightened(0.06), true, nsk)
	var cff := func(a, y):
		var v: float = clampf(inverse_lerp(N + 0.095 * q, N - 0.006, float(y)), 0.0, 1.0)
		return clf.call(float(a), float(y), v)
	Q._run(k, ck, cff, [Vector2(-0.04, N + 0.085 * q), Vector2(-0.04, N - 0.004)], 0.0042, 0.0025, 0.0022, rd, nsk, 10)
	# geniş kollar: mor astar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = _arm(k, sd)
		AB._wsleeve(k, ar, func(_s, _a): return bk, ln.darkened(0.3), 0.92, 0.044, 0.026, 1.7 if sd == "Left" else 0.5)
		P._lt(k, ar, func(s, _a): return 0.004 + 0.003 * smoothstep(0.7, 0.92, float(s)), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.45, 0.965, 14, 16)
	# gri kuşak + katlı kapak, kahve kemer
	var by: float = H + 0.1
	var bsk: Array = k.torso_skin(by)
	var sgd: Dictionary = P._cl(k, {"keys": keys, "ny": 6, "na": 88, "top": func(_a): return by + 0.045, "hem": func(_a): return by - 0.045, "lift": 0.012,
		"fold": func(a, _y, v): return 0.005 * sin(float(v) * PI) + 0.003 * sin(float(a) * 6.0), "col": func(_a, y, _v): return gy.darkened(0.08 * float(absf(float(y) - by) < 0.012)), "gain": 5.0, "th": 0.004, "inner": gy.darkened(0.3), "skin": tsk})
	P._cord(k, sgd["hem"], 0.003, gy.darkened(0.2), true, tsk)
	var fl: Dictionary = P._cl(k, {"keys": keys, "ny": 5, "na": 40, "rng": func(_v): return Vector2(-1.05, 1.05), "top": func(a): return by + 0.074 - 0.03 * smoothstep(0.55, 1.05, absf(float(a))), "hem": func(_a): return by + 0.03,
		"lift": 0.02, "fold": func(a, _y, v): return 0.006 * float(v) * cos(float(a)), "col": func(_a, _y, _v): return gy.lightened(0.05), "gain": 5.0, "th": 0.004, "inner": gy.darkened(0.25), "skin": tsk})
	P._cord(k, fl["top"], 0.0028, gy.darkened(0.12), false, tsk)
	var blt := []
	for i in 96:
		blt.append(P._sa(keys, TAU * i / 96.0 - PI, by - 0.018, 0.0)[0])
	var blt2 := []
	for p in blt:
		blt2.append((p as Vector3) + Vector3((p as Vector3).x, 0.0, (p as Vector3).z).normalized() * 0.019)
	P._bd(k, blt2, 0.011, 0.0035, br, true, tsk)
	for a in [-0.42, 0.38]:
		var e: Array = P._sa(keys, float(a), by - 0.04, 0.025)
		var o: Vector3 = e[1]
		var ux: Vector3 = Vector3.UP.cross(o).normalized()
		var lp := []
		for i in 14:
			var t: float = TAU * i / 14.0
			lp.append((e[0] as Vector3) + ux * sin(t) * 0.009 + Vector3.UP * (cos(t) * 0.014 - 0.006))
		P._cord(k, lp, 0.0024, tn, true, func(_p): return bsk)
	var pb: Array = P._sa(keys, PI, by - 0.01, 0.035)
	_box_at(k, pb, 0.05, 0.034, 0.016, br.lightened(0.05), bsk, 0.35)
	# sağ yanda kılıç kını: kemerden arkaya eğik iner, palto üstüne oturur
	var sh := []
	for i in 12:
		var t: float = float(i) / 11.0
		var e: Array = P._sa(keys, lerpf(-1.3, -1.9, t), lerpf(by - 0.02, H - 0.26, t), 0.0)
		var p0: Vector3 = e[0]
		var f0: float = 1.0 + float(ff.call(lerpf(-1.3, -1.9, t), p0.y))
		sh.append(Vector3(p0.x * f0, p0.y, p0.z * f0) + (e[1] as Vector3) * 0.03)
	P._tb(k, sh, func(s, a): return 0.0125 * (1.0 + 0.15 * cos(float(a))) * (1.0 - 0.15 * float(s)), func(s, _a, _p): return br.darkened(0.3) if float(s) < 0.06 else bk.lightened(0.1), func(_s, p): return csk.call(p), 10)


# ------------------------------------------------------------------ Sōshi Wakate (ref Shinobi Striker "Nagato Outfit (Young Ver.)"): file iç, sol kanadı sağın üstüne binen kalçaya inen siyah kısa kimono
## (enseden etek ucuna geniş hardal yaka bandı, dirsekte biten geniş kol), açık mavi iki katlı obi + beyaz orta çizgi, file önkol + siyah bilek bandı,
## dizaltına inen siyah kapri, beyaz bant, baldıra çıkan siyah bot
static func _soshi_wakate(k) -> void:
	var bk := Color(0.1, 0.1, 0.115)
	var ye := Color(0.69, 0.627, 0.188)
	var ob := Color(0.62, 0.74, 0.86)
	var wh := Color(0.92, 0.93, 0.94)
	var nt := Color(0.2, 0.2, 0.24)
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
	var ik: Array = P._inner(k, b, func(_i, _j, p): return skc if p.y > C - 0.03 else bk, 0.004)
	P._net_patch(k, ik, func(a, _y): return absf(float(a)) < 0.62, -0.62, 0.62, C - 0.05, N + 0.05, 0.013, 0.0011, 0.0025, nt)
	K._seat(k, b, bk)
	# kapri + beyaz bant + bot
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.6
		var s1: float = kn + 0.17
		var pa: Callable = K._pant(k, le, bk, 0.016, 0.026, s1, sv)
		Q._ring_on(k, le, s1 - 0.012, func(s, a): return float(pa.call(s, a)) + 0.001, 0.013, bk.lightened(0.04), 0.004)
		var bf := func(s: float, a: float) -> float: return 0.012 + 0.004 * (1.0 - smoothstep(s1 + 0.03, s1 + 0.07, s)) + 0.0014 * sin(a * 5.0 + s * 26.0) * smoothstep(s1 + 0.08, 0.9, s)
		P._lt(k, le, func(s, a): return float(bf.call(float(s), float(a))) - 0.002, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, s1 - 0.025, s1 + 0.04, 6, 20)
		P._lt(k, le, bf, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, s1 + 0.03, 0.995, 18, 22)
		Q._ring_on(k, le, s1 + 0.04, bf, 0.007, bk.lightened(0.05), 0.003)
	# kollar: file önkol + bilek bandı, dirsekte biten geniş kimono kolu
	for sd in ["Left", "Right"]:
		var ar: Dictionary = _arm(k, sd)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.6 if sd == "Left" else 0.3
		P._bare(k, ar, skc, en - 0.06, 0.985)
		P._net_limb(k, ar, en - 0.04, 0.9, 0.003, 8, 0.014, 0.0011, nt)
		P._lt(k, ar, func(s, _a): return 0.008 + 0.002 * sin(clampf((float(s) - 0.895) / 0.075, 0.0, 1.0) * PI), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.895, 0.97, 6, 18)
		var s1: float = en + 0.05
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.08, 0.5, s)
			var hang: float = maxf(0.0, -sin(a) * sg)
			return 0.02 + 0.042 * fl + 0.02 * fl * hang * hang + (0.003 + 0.006 * fl) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins): return bk.lightened(0.04) if ins else P._fs(bk, float(sf.call(float(s), float(a))) - 0.02 - 0.042 * smoothstep(0.08, 0.5, float(s)), 12.0), 0.0, s1, 30, 24, 0.05)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, bk.lightened(0.05), 0.4, s1, 10, 24)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return bk.lightened(0.04) if ins else bk.lightened(0.06), s1 - 0.03, s1 + 0.001, 3, 24)
	# kısa kimono: sol kanat üstte, kalçaya iner, geniş hardal yaka bandı
	var hem: float = H - 0.15
	var keys := [P._kp(nk, N + 0.01, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.04], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.026), P._kp(hp, H - 0.04, 0.046), [hem, hp.x + 0.062, hp.y + 0.056, hp.z - 0.066]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * 0.016 * sin(a * 6.0 + 0.3) + 0.007 * sin(a * 5.0 + y * 12.0) * smoothstep(H + 0.3, H + 0.05, y)
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(_a, _y, v): return bk.darkened(0.1 * smoothstep(0.95, 1.0, float(v))), "fold": fold, "band": ye, "band_w": 0.025, "ny": 40, "na": 60, "gain": 5.0, "inner": bk.darkened(0.3), "low": -0.36})
	for lf in [true, false]:
		var g: Dictionary = wg["L" if lf else "R"]
		var nb := []
		for p in g["top"]:
			nb.append((p as Vector3) + Vector3(0, -0.013, 0))
		P._bd(k, nb, 0.014, 0.0045, ye, false, func(p): return Q._nsk(k, p), 0.3)
		P._bd(k, M._yl(g["hem"], 0.007), 0.0045, 0.002, bk.lightened(0.06), false, func(p): return M._wrap_skin(k, p, hem, lf))
	# obi: iki açık mavi kat + aradaki beyaz çizgi
	var by: float = H + 0.09
	var okeys := [P._kp(wa, by + 0.06, 0.03), P._kp(wa, by - 0.06, 0.032)]
	P._sash(k, okeys, by + 0.021, 0.019, 0.006, ob, 0.1)
	P._sash(k, okeys, by - 0.021, 0.019, 0.006, ob.darkened(0.04), 0.1)
	P._bd(k, P._ring_pts(okeys, by, 0.008, 80), 0.0055, 0.0035, wh, true, tsk)


# ------------------------------------------------------------------ Daidai Ressha (ref Shinobi Striker "Naruto Outfit"): fermuarı kapalı eşofman ceketi (siyah omuz boyunduruğu + kollar + dik yaka + lastikli etek bandı,
## turuncu gövde, yanlarda siyah şerit), sol omuzda girdaplı yama, sırtta kızıl girdap, lastikli manşet; turuncu eşofman altı, sağ uylukta beyaz sargı + siyah bant + kılıf,
## sol kalçada kahve kese, siyah bot konçu
static func _daidai(k) -> void:
	var og := Color(0.95, 0.52, 0.12)
	var bk := Color(0.12, 0.12, 0.17)
	var zp := Color(0.72, 0.72, 0.74)
	var rd := Color(0.75, 0.13, 0.11)
	var wh := Color(0.92, 0.92, 0.9)
	var bn := Color(0.42, 0.27, 0.17)
	var pt := Color(0.3, 0.3, 0.34)
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
	K._seat(k, b, og)
	# eşofman altı + bot konçu; sağ uylukta sargı ve kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 0.9 if sd == "Left" else 2.3
		var pa: Callable = K._pant(k, le, og, 0.017, 0.028, 0.9, sv)
		var bf := func(s: float, a: float) -> float: return 0.016 + 0.004 * (1.0 - smoothstep(0.85, 0.9, s)) + 0.0012 * sin(a * 5.0)
		P._lt(k, le, bf, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.darkened(0.25), 0.83, 0.995, 12, 22)
		for ss in [0.87, 0.94]:
			Q._ring_on(k, le, ss, bf, 0.008, bk.darkened(0.05), 0.0035)
		if sd == "Right":
			var wf := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.003
			P._lt(k, le, wf, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.08), 0.2, 0.31, 8, 22)
			for i in 4:
				var s: float = lerpf(0.205, 0.3, float(i) / 3.0)
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + float(pa.call(s, 0.0)) + 0.008, 0.0105, 0.004, wh.darkened(0.04 * float(i % 2)), P._lskin(le, s))
			Q._ring_on(k, le, 0.255, func(s, a): return float(wf.call(s, a)) + 0.005, 0.009, bk, 0.003)
			Q._ring_on(k, le, 0.4, func(s, a): return float(pa.call(s, a)) + 0.001, 0.008, bk, 0.003)
			var oa: float = J._outer_a(le, 0.42, Vector3(-1.0, 0.0, 0.2).normalized())
			var e: Array = K._lsurf(le, 0.44, oa, float(pa.call(0.44, oa)) + 0.02)
			var o: Vector3 = e[1]
			var d: Vector3 = P._ld(le, 0.44)
			var bo := [["RightUpperLeg", 1.0]]
			P._boxr(k, e[0], o.cross(d).normalized() * 0.033, -d * 0.05, o * 0.017, bk, bo)
			P._boxr(k, (e[0] as Vector3) + o * 0.016 - d * 0.03, o.cross(d).normalized() * 0.035, -d * 0.022, o * 0.005, bk.lightened(0.06), bo, 0.2)
			P._stud(k, (e[0] as Vector3) + o * 0.022 - d * 0.018, o, 0.004, zp, bo)
	# sol kalçada kahve kese
	var sk2 := [P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.03), P._kp(hp, H - 0.06, 0.03)]
	var pe: Array = P._sa(sk2, PI - 0.55, H - 0.035, 0.02)
	_box_at(k, pe, 0.04, 0.03, 0.015, bn, [["Hips", 1.0]], 0.35)
	# ceket gövdesi
	var hem: float = H - 0.015
	var keys := [P._kp(nk, N + 0.008, 0.034), [N - 0.055, ch.x * 1.06, ch.y * 0.99, ch.z * 1.08], P._kp(ch, C - 0.03, 0.04), P._kp(wa, H + 0.12, 0.045), P._kp(k.M(hem, 0.3), hem, 0.04)]
	var ny := 36
	var top: float = N + 0.008
	var jy: int = int(round((top - (C - 0.035)) / (top - hem) * ny))
	var yy: float = lerpf(top, hem, float(jy) / ny)
	var sa0: float = -PI + TAU * 68.0 / 96.0
	var sa1: float = -PI + TAU * 76.0 / 96.0
	var jf := func(a: float, y: float, _v: float) -> float:
		var aw: float = absf(a)
		return smoothstep(0.25, 0.6, aw) * (1.0 - smoothstep(1.9, 2.3, aw) * smoothstep(yy - 0.02, yy + 0.02, y)) * (0.009 * sin(a * 6.0 + y * 15.0) + 0.005 * sin(a * 11.0 - y * 9.0) * smoothstep(C, hem, y))
	var jff := func(a, y): return jf.call(float(a), float(y), 0.0)
	var jcol := func(a: float, y: float) -> Color:
		var aw: float = absf(a)
		if y >= yy - 0.0005 or (aw >= sa0 - 0.001 and aw <= sa1 + 0.001):
			return bk
		return og
	P._cl(k, {"keys": keys, "ny": ny, "na": 96, "top": func(_a): return top, "hem": func(_a): return hem, "fold": jf, "col": func(a, y, _v): return jcol.call(float(a), float(y)), "gain": 6.0, "th": 0.005, "inner": bk.darkened(0.2), "skin": tsk})
	var yr := []
	for i in 49:
		yr.append(Vector2(-PI + TAU * i / 48.0, yy - 0.002))
	Q._run(k, keys, jff, yr, 0.0028, 0.0018, 0.0016, bk.lightened(0.05), tsk, 2)
	for sg in [1.0, -1.0]:
		for aa in [sa0 - 0.012, sa1 + 0.012]:
			Q._run(k, keys, jff, [Vector2(sg * aa, yy - 0.004), Vector2(sg * aa, hem + 0.04)], 0.0024, 0.0016, 0.0014, bk.lightened(0.05), tsk, 10)
	# lastikli etek bandı
	var hb := [[hem + 0.05, float(keys[4][1]) + 0.004, float(keys[4][2]) + 0.004, float(keys[4][3]) - 0.004], [hem - 0.005, float(keys[4][1]) - 0.002, float(keys[4][2]) - 0.002, float(keys[4][3]) + 0.002]]
	P._cl(k, {"keys": hb, "ny": 4, "na": 96, "top": func(_a): return hem + 0.045, "hem": func(_a): return hem - 0.006, "lift": 0.006, "fold": func(a, _y, v): return 0.004 * sin(float(v) * PI) + 0.0025 * sin(float(a) * 48.0),
		"col": func(_a, _y, _v): return bk, "gain": 9.0, "th": 0.004, "inner": bk.darkened(0.3), "skin": tsk})
	# fermuar: yakadan etek ucuna
	var q: float = Q._hq(k)
	Q._run(k, keys, jff, [Vector2(0.0, N + 0.0), Vector2(0.0, hem - 0.004)], 0.0036, 0.0075, 0.0024, zp, tsk, 24)
	# dik yaka
	var kb: Array = SE.El.key_at(keys, N - 0.02)
	var ck := [[N + 0.075 * q, nk.x + 0.032, nk.y + 0.034, nk.z - 0.036], [N + 0.025 * q, nk.x + 0.034, nk.y + 0.034, nk.z - 0.038], [N - 0.02, float(kb[1]) + 0.006, float(kb[2]) + 0.006, float(kb[3]) - 0.006]]
	var clg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 56, "top": func(a): return N + q * lerpf(0.068, 0.075, smoothstep(0.3, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.02,
		"fold": func(a, _y, v): return 0.006 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.lightened(0.04), "skin": nsk})
	P._cord(k, clg["top"], 0.0036, bk.lightened(0.05), true, nsk)
	Q._run(k, ck, Callable(), [Vector2(0.0, N + 0.068 * q), Vector2(0.0, N - 0.016)], 0.0036, 0.0035, 0.0024, zp, nsk, 8)
	var zt: Array = Q._spt(ck, Callable(), 0.0, N + 0.03 * q, 0.007)
	P._boxr(k, zt[0], Vector3(0.0048, 0, 0), Vector3(0, 0.012, 0), (zt[1] as Vector3) * 0.0024, zp.lightened(0.05), [["Neck", 0.5], ["UpperChest", 0.5]], 0.3)
	# sırtta kızıl girdap (siyah boyundurukta)
	J._swirl(k, keys, 0.0, lerpf(yy, N - 0.05, 0.42), 0.052, rd, false)
	# kollar: siyah, bol, lastikli manşet; sol omuzda girdaplı yama
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.4 if sd == "Left" else 0.2
		var s1: float = 0.885
		var sf := func(s: float, a: float) -> float:
			return 0.018 + 0.01 * smoothstep(0.05, 0.4, s) - 0.006 * smoothstep(0.7, s1, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.005 * exp(-pow((s - s1 + 0.03) / 0.03, 2.0)) * sin(a * 6.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.03), float(sf.call(float(s), float(a))) - 0.024, 12.0), 0.0, s1, 34, 22, 0.02)
		var cf := func(s: float, a: float) -> float: return 0.012 + 0.002 * sin(clampf((s - s1 + 0.01) / 0.07, 0.0, 1.0) * PI) + 0.0018 * sin(a * 12.0)
		P._lt(k, ar, cf, func(_s, a, ins): return bk.darkened(0.35) if ins else bk.darkened(0.1 * float(sin(float(a) * 12.0) < 0.0)), s1 - 0.01, 0.955, 6, 24)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.005, bk.darkened(0.35), 0.9, 0.95, 4, 24)
		if sd == "Left":
			var s0: float = 0.2
			var oa: float = J._outer_a(ar, s0, Vector3(sg, 0.45, 0.2))
			var lf := func(s, a): return float(sf.call(float(s), float(a))) + 0.0032
			var prow := []
			for j in 5:
				var ss: float = lerpf(s0 - 0.075, s0 + 0.075, float(j) / 4.0)
				var ro := []
				for i in 7:
					ro.append(Vector2(ss, oa + lerpf(-0.5, 0.5, float(i) / 6.0)))
				prow.append(ro)
			T._lpatch(k, ar, prow, lf, pt)
			var mx := 0.0
			for i in 9:
				mx = maxf(mx, float(sf.call(s0 + lerpf(-0.03, 0.03, float(i % 3) / 2.0), oa + lerpf(-0.3, 0.3, floorf(float(i) / 3.0) / 2.0))))
			J._arm_swirl(k, ar, s0, 0.024, rd.darkened(0.15), mx + 0.004)
