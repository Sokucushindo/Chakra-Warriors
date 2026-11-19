extends RefCounted
## Elle modellenmiş setler, parti ah: ss_kara_palto, ss_metal_canavar, ss_sari_simsek, ss_sari_simsek_genc, ss_sis_striker, ss_sis_striker_beyaz. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{merz_outfit, metal_outfit, minato_outfit, minato_outfit_genin_ver, mist_striker}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), s (S), r (R), n (N), aa (AA), af (AF) dosyalarından; burada Kiri Striker ortak kesimi (iki türev) ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AF = preload("res://scripts/actors/set_el_af.gd")
const NN = preload("res://scripts/actors/set_el_n.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
## 四 (yon): dış çerçeve + içte iki bacak
const G_YON := [[-0.8, 0.75, 0.8, 0.75], [-0.8, 0.75, -0.8, -0.8], [0.8, 0.75, 0.8, -0.8], [-0.8, -0.8, 0.8, -0.8], [-0.22, 0.75, -0.38, 0.0], [0.22, 0.75, 0.22, 0.08], [0.22, 0.08, 0.55, 0.08]]

const DONE := ["ss_sis_striker", "ss_sis_striker_beyaz", "ss_metal_canavar", "ss_sari_simsek_genc", "ss_sari_simsek", "ss_kara_palto"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_sis_striker": _sis(k, 0)
		"ss_sis_striker_beyaz": _sis(k, 1)
		"ss_metal_canavar": _metal(k)
		"ss_sari_simsek_genc": _minato_genc(k)
		"ss_sari_simsek": _minato(k)
		"ss_kara_palto": _kara(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Uzuv boyunca dikey kabartma çizgiler (ısıtıcı şeritleri): angs açılar, liftf(s, a) altındaki kumaşın kalınlığı
static func _vlines(k, l: Dictionary, s0: float, s1: float, angs: Array, liftf: Callable, hw: float, col: Color, n := 18) -> void:
	for a0 in angs:
		var av: float = a0
		S._lstrip(k, l, s0, s1, func(_s): return av, liftf, hw, 0.0018, col, n)


## Kumaş yüzeyinde (açı, y) noktasında yerel eşleme + dış yön
static func _at(keys: Array, ff: Callable, a: float, y: float) -> Array:
	return [Q._local(keys, ff, a, y), Q._spt(keys, ff, a, y)[1]]


## Baldır boyu haori ağırlığı: AA._fam ile aynı, yalnız diz altında arka etek baldırı daha güçlü izler (geri kalkan baldır arka eteği delmez)
static func _hsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.11), 0.5)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.96, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.94, smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(0.035, 0.1, bk)
	var s: float = smoothstep(-hw, hw, x)
	var kb: float = smoothstep(k.K + 0.1, k.K - 0.1, p.y) * lerpf(0.5, 0.92, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


# ------------------------------------------------------------------ Kiri Striker ortak kesimi (ref Shinobi Striker "Mist Striker" 1-2): kolsuz, dikey dikişli uyluk boyu tunik, boynu saran kalın gömme atkı
## (önde yarık + iki düğme), kabarık koyu kısa kollar, dirsekten bileğe çizgili kol ısıtıcısı, sağ omuzdan sol kalçaya verev kayış (tokalı) ve bel kemeri,
## sol kalçada bölmeli kese, dizin altında toplanan bol pantolon, baldırda çizgili ısıtıcı.
## v=0 mor (lavanta tunik + sol yanda koyu mor panel, açık mavi ısıtıcılar, yeşil kayış), v=1 beyaz (önde sarı biyeli gri orta panel, etekte siyah satranç taşı kesikleri,
## siyah kayış + sarı bantlar, sarı tokalı gri kemer, damalı kese, beyaz pantolon: dış yanda siyah şerit, sağ uylukta köpekbalığı)
static func _sis(k, v: int) -> void:
	var tu: Color = [Color(0.66, 0.6, 0.82), Color(0.93, 0.93, 0.92)][v]
	var tud: Color = [Color(0.46, 0.39, 0.66), Color(0.62, 0.62, 0.64)][v]
	var sm: Color = [Color(0.4, 0.34, 0.58), Color(0.66, 0.66, 0.68)][v]
	var dk: Color = [Color(0.17, 0.14, 0.27), Color(0.08, 0.08, 0.09)][v]
	var scf: Color = [Color(0.17, 0.14, 0.27), Color(0.92, 0.92, 0.92)][v]
	var wb: Color = [Color(0.6, 0.7, 0.88), Color(0.9, 0.9, 0.91)][v]
	var wl: Color = [Color(0.3, 0.38, 0.66), Color(0.56, 0.56, 0.58)][v]
	var stc: Color = [Color(0.55, 0.72, 0.2), Color(0.09, 0.09, 0.1)][v]
	var btc: Color = [Color(0.55, 0.72, 0.2), Color(0.76, 0.76, 0.78)][v]
	var pcc: Color = [Color(0.24, 0.2, 0.4), Color(0.93, 0.93, 0.92)][v]
	var pn: Color = [Color(0.165, 0.137, 0.251), Color(0.92, 0.92, 0.92)][v]
	var yl := Color(0.92, 0.77, 0.2)
	var mt := Color(0.78, 0.79, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var hem: float = H - 0.135
	var by: float = H + 0.085
	var fam := func(p): return AA._fam(k, p, hem)
	var tsk := func(p): return k.torso_skin(p.y)
	K._seat(k, b, pn.darkened(0.08))
	# pantolon: dizin altında toplanır; altında çizgili ısıtıcı
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 1.7 if sd == "Left" else 0.5
		var tk: float = kn + 0.12
		var pa: Callable = Q._baggy(k, le, pn, wl.darkened(0.2), 0.016, 0.036, tk, sv)
		var oa: float = J._outer_a(le, 0.3, Vector3(sg, 0.0, 0.0))
		if v == 1:   # dış yanda siyah şerit (kumaşa oturan ayrı parça)
			S._lstrip(k, le, 0.03, tk - 0.03, func(_s): return oa, func(s, a): return float(pa.call(s, a)) + 0.001, 0.016, 0.0018, dk, 30)
			if sd == "Right":   # sağ uylukta köpekbalığı: burnu kasığa, kuyruğu dize
				_shark(k, le, pa, Color(0.62, 0.6, 0.8))
		# baldır ısıtıcısı: dikey fitilli, üstü kalın ağız, bilekte bant
		var wf := func(s: float, a: float) -> float:
			var u: float = clampf((s - tk) / (0.99 - tk), 0.0, 1.0)
			return 0.012 + 0.003 * u + 0.0016 * cos(a * 10.0 + sv) + 0.006 * exp(-pow((u - 0.02) / 0.05, 2.0))
		P._lt(k, le, wf, func(s, a, ins): return wb.darkened(0.45) if ins else P._fs(wb, 0.0016 * cos(float(a) * 10.0 + sv), 14.0), tk - 0.012, 0.99, 22, 30)
		var lines: Array = [oa, oa + PI, oa + PI * 0.5, oa - PI * 0.5] if v == 1 else [oa - 0.5, oa + 0.5, oa + PI * 0.5 + 0.3, oa - PI * 0.5 - 0.3, oa + PI]
		_vlines(k, le, tk + 0.01, 0.955, lines, wf, 0.011 if v == 1 else 0.0042, wl, 14)
		Q._ring_on(k, le, 0.968, wf, 0.009, wl if v == 1 else wb.darkened(0.12), 0.003)
	# tunik: kolsuz, uyluğa iner, belden aşağı hafif açılır
	var tk2 := [P._kp(nk, N + 0.02, 0.02), [N - 0.05, ch.x * 0.97, ch.y * 0.92, ch.z * 1.02], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.026), P._kp(hp, H - 0.03, 0.042), [hem, hp.x + 0.065, hp.y + 0.055, hp.z - 0.06]]
	var tf := func(a: float, y: float) -> float:
		var nb: float = 1.0 - exp(-pow((y - by) / 0.03, 2.0))   # kemer altında kıvrım yok (kemer kumaşa oturur)
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		return nb * (t * (0.016 * sin(a * 8.0 + 0.4) + 0.007 * sin(a * 13.0 + 1.3)) + (1.0 - t) * 0.005 * sin(a * 6.0 + y * 14.0) * smoothstep(N - 0.02, C - 0.04, y))
	var tff := func(a, y): return tf.call(float(a), float(y))
	var side := func(a: float, y: float) -> float:   # v0: sol yanda koyu mor panel (göğüsten etek ucuna, aşağıda öne genişler)
		var e0: float = lerpf(0.82, 0.55, smoothstep(C, hem, y))
		return smoothstep(e0 - 0.03, e0 + 0.03, a) * (1.0 - smoothstep(1.85, 1.95, a))
	P._cl(k, {"keys": tk2, "ny": 40, "na": 96, "top": func(_a): return N + 0.02, "hem": func(a): return hem + 0.008 * cos(float(a)), "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(a, y, _v): return tu.lerp(tud, float(side.call(float(a), float(y)))) if v == 0 else tu, "gain": 6.0, "th": 0.006, "inner": tu.darkened(0.35), "skin": fam})
	# dikey dikişler (tunik boyunca kabartma)
	var seams: Array = [-1.55, -1.1, -0.65, -0.22, 0.22, 0.65, 1.1, 1.55, PI - 0.5, PI, -PI + 0.5, 2.1, -2.1] if v == 0 else [-1.55, -1.05, -0.6, 0.6, 1.05, 1.55, PI - 0.5, PI, -PI + 0.5, 2.1, -2.1]
	for a0 in seams:
		Q._run(k, tk2, tff, [Vector2(a0, N - 0.035), Vector2(a0, by + 0.02)], 0.0022, 0.0012, 0.0014, sm, tsk, 10)
		Q._run(k, tk2, tff, [Vector2(a0, by - 0.02), Vector2(a0, hem + 0.012)], 0.0022, 0.0012, 0.0014, sm, fam, 6)
	if v == 0:   # koyu panelin kenarı da dikiş
		var ed := []
		for i in 12:
			var y: float = lerpf(C, hem + 0.01, float(i) / 11.0)
			ed.append(Vector2(lerpf(0.82, 0.55, smoothstep(C, hem, y)), y))
		Q._run(k, tk2, tff, ed, 0.0024, 0.0012, 0.0014, sm.darkened(0.15), fam, 2)
	else:   # gri orta panel: sarı biyeli, kendi dikişleri
		var gk := []
		for e in tk2:
			gk.append([e[0], float(e[1]) + 0.0035, float(e[2]) + 0.0035, float(e[3]) - 0.0035])
		var gp: Dictionary = P._cl(k, {"keys": gk, "ny": 40, "na": 22, "rng": func(_v): return Vector2(-0.36, 0.36), "top": func(_a): return N - 0.02, "hem": func(a): return hem + 0.008 * cos(float(a)) + 0.003,
			"fold": func(a, y, _v): return tf.call(float(a), float(y)), "col": func(_a, _y, _v): return tud, "gain": 6.0, "th": 0.003, "inner": tud.darkened(0.3), "skin": fam})
		for ed in [gp["ea"], gp["eb"]]:
			P._cord(k, ed, 0.0026, yl, false, fam)
		for a0 in [-0.12, 0.12]:
			Q._run(k, gk, tff, [Vector2(a0, N - 0.03), Vector2(a0, by + 0.02)], 0.002, 0.0012, 0.0014, tud.darkened(0.25), tsk, 10)
			Q._run(k, gk, tff, [Vector2(a0, by - 0.02), Vector2(a0, hem + 0.012)], 0.002, 0.0012, 0.0014, tud.darkened(0.25), fam, 6)
		# satranç taşı kesikleri: etekte iki yanda siyah piyon / kale
		for e in [[0.82, 0], [1.08, 1], [-0.82, 0], [-1.08, 1]]:
			var y0: float = lerpf(by, hem, 0.62)
			var at: Array = _at(tk2, tff, float(e[0]), y0)
			var mp: Callable = at[0]
			var o: Vector3 = at[1]
			Q._disc(k, func(u, w, l): return mp.call(u, float(w) + 0.034, l), o, 0.0105, 0.003, Callable(), func(_u, _w): return dk, fam, 3, 16)
			R._lstrip(k, mp, [Vector2(0.0, 0.028), Vector2(0.0, -0.026)], 0.0062 if int(e[1]) == 0 else 0.008, 0.003, 0.0016, dk, fam)
			R._lstrip(k, mp, [Vector2(-0.013, -0.03), Vector2(0.013, -0.03)], 0.005, 0.003, 0.0016, dk, fam)
	# kemer
	var bp: Array = P._ring_pts(tk2, by, 0.005, 88)
	P._bd(k, bp, 0.0145, 0.0042, btc, true, tsk)
	if v == 0:   # yeşil toka: halka + bekçi
		var e0: Array = Q._spt(tk2, tff, -0.15, by, 0.009)
		P._boxr(k, e0[0], Vector3(0.017, 0, 0), Vector3(0, 0.017, 0), (e0[1] as Vector3) * 0.0035, btc.darkened(0.15), [["Hips", 0.5], ["Spine", 0.5]], 0.25)
		P._boxr(k, (e0[0] as Vector3) + (e0[1] as Vector3) * 0.003, Vector3(0.011, 0, 0), Vector3(0, 0.011, 0), (e0[1] as Vector3) * 0.0025, btc.lightened(0.08), [["Hips", 0.5], ["Spine", 0.5]], 0.25)
		var e1: Array = Q._spt(tk2, tff, 0.12, by, 0.008)
		P._boxr(k, e1[0], Vector3(0.006, 0, 0), Vector3(0, 0.019, 0), (e1[1] as Vector3) * 0.003, btc.darkened(0.1), [["Hips", 0.5], ["Spine", 0.5]], 0.25)
	else:   # sarı kıskaçlar
		for a0 in [-0.42, 0.42]:
			var e2: Array = Q._spt(tk2, tff, a0, by, 0.009)
			var ux: Vector3 = Vector3.UP.cross(e2[1]).normalized()
			P._boxr(k, e2[0], ux * 0.011, Vector3(0, 0.02, 0), (e2[1] as Vector3) * 0.004, yl, [["Hips", 0.5], ["Spine", 0.5]], 0.3)
	# verev kayış: sağ omuzdan sol kalçaya (önde ve arkada)
	var fr := [Vector2(-1.2, N - 0.045), Vector2(-0.95, N - 0.09), Vector2(-0.45, C - 0.06), Vector2(0.3, H + 0.2), Vector2(0.95, by + 0.03)]
	var bk := [Vector2(-1.2, N - 0.045), Vector2(-1.75, N - 0.09), Vector2(-2.5, C - 0.06), Vector2(-3.35, H + 0.2), Vector2(-4.1, by + 0.03)]
	Q._run(k, tk2, tff, fr, 0.0125, 0.0045, 0.003, stc, tsk, 8)
	Q._run(k, tk2, tff, bk, 0.0125, 0.0045, 0.003, stc, tsk, 8)
	if v == 0:   # kayış üstünde iki toka
		for e in [[-0.86, N - 0.11], [-0.62, C - 0.025]]:
			var e3: Array = Q._spt(tk2, tff, float(e[0]), float(e[1]), 0.0085)
			var ux2: Vector3 = Vector3.UP.cross(e3[1]).normalized()
			P._boxr(k, e3[0], ux2 * 0.016 + Vector3(0, -0.01, 0), ux2 * 0.004 + Vector3(0, 0.007, 0), (e3[1] as Vector3) * 0.003, stc.darkened(0.12), tsk.call(e3[0]), 0.25)
	else:   # iki sarı bant
		for e in [[-0.92, N - 0.1], [-0.72, C - 0.0]]:
			var e4: Array = Q._spt(tk2, tff, float(e[0]), float(e[1]), 0.008)
			var ux3: Vector3 = Vector3.UP.cross(e4[1]).normalized()
			P._boxr(k, e4[0], ux3 * 0.0165 + Vector3(0, -0.011, 0), ux3 * 0.003 + Vector3(0, 0.0055, 0), (e4[1] as Vector3) * 0.003, yl, tsk.call(e4[0]), 0.2)
	# sol kalçada kese: gövde + iki kapaklı bölme + çıtçıt (v1: kapaklar damalı)
	var pe: Array = Q._spt(tk2, tff, 1.28, by - 0.04, 0.022)
	var po: Vector3 = pe[1]
	var pux: Vector3 = Vector3.UP.cross(po).normalized()
	var pbo := [["Hips", 1.0]]
	P._boxr(k, pe[0], pux * 0.05, Vector3(0, 0.044, 0), po * 0.022, pcc, pbo, 0.3)
	for sx in [-1.0, 1.0]:
		var fc: Vector3 = (pe[0] as Vector3) + po * 0.021 + pux * (0.025 * sx) + Vector3(0, 0.026, 0)
		P._boxr(k, fc, pux * 0.023, Vector3(0, 0.016, 0), po * 0.004, pcc.darkened(0.08), pbo, 0.25)
		if v == 1:
			for iy in 2:
				for ix in 4:
					var tc: Vector3 = fc + po * 0.004 + pux * (-0.0165 + 0.011 * ix) + Vector3(0, 0.0055 - 0.011 * iy, 0)
					P._boxr(k, tc, pux * 0.0053, Vector3(0, 0.0053, 0), po * 0.0012, dk if (ix + iy) % 2 == 0 else Color(0.95, 0.95, 0.94), pbo, 0.15)
		else:
			P._stud(k, fc + po * 0.004 + Vector3(0, -0.006, 0), po, 0.0032, mt, pbo)
	# kollar: kabarık koyu kısa kol + çizgili ısıtıcı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.3 if sd == "Left" else 2.6
		var sg: float = ar["sg"]
		var s1: float = en + 0.02
		var wf2 := func(s: float, a: float) -> float: return 0.0075 + 0.0014 * cos(a * 10.0 + sv) + 0.003 * smoothstep(0.92, 0.97, s)
		P._lt(k, ar, wf2, func(s, a, ins): return wb.darkened(0.45) if ins else P._fs(wb, 0.0014 * cos(float(a) * 10.0 + sv), 14.0), en - 0.06, 0.968, 22, 28)
		var oa: float = J._outer_a(ar, 0.75, Vector3(sg, 0.0, 0.0))
		var al: Array = [oa, oa + PI, oa + PI * 0.5, oa - PI * 0.5] if v == 1 else [oa - 0.45, oa + 0.45, oa + 1.3, oa - 1.3, oa + PI]
		_vlines(k, ar, s1 + 0.005, 0.95, al, wf2, 0.0095 if v == 1 else 0.0038, wl, 12)
		Q._ring_on(k, ar, 0.952, wf2, 0.007, wl if v == 1 else wb.darkened(0.12), 0.0025)
		var pf := func(s: float, a: float) -> float:
			var t: float = clampf(s / s1, 0.0, 1.0)
			var puff: float = 0.024 * pow(sin(t * PI * 0.92 + 0.12), 0.8)
			var ruf: float = (0.004 + 0.004 * t) * sin(a * 7.0 + sv + s * 6.0) + 0.0035 * P._lf(s, a, sv)
			return 0.012 + puff + ruf * smoothstep(0.05, 0.3, t) - 0.009 * smoothstep(0.86, 1.0, t)
		P._lt(k, ar, pf, func(s, a, ins): return dk.darkened(0.3) if ins else P._fs(dk.lightened(0.04), (0.004 + 0.004 * clampf(float(s) / s1, 0.0, 1.0)) * sin(float(a) * 7.0 + sv + float(s) * 6.0), 14.0), 0.0, s1, 26, 28, 0.03)
		K._lt_in(k, ar, func(s, a): return float(pf.call(float(s), float(a))) - 0.005, dk.darkened(0.3), s1 - 0.1, s1 - 0.004, 6, 28)
	# gömme atkı: boynu saran kalın kat, omza yayılır; önde yarık + iki düğme
	var q: float = Q._hq(k)
	var sk := [[N + 0.075 * q, nk.x + 0.03, nk.y + 0.03, nk.z - 0.034], [N + 0.035 * q, nk.x + 0.05, nk.y + 0.046, nk.z - 0.05], [N - 0.03, nk.x + 0.08, nk.y + 0.064, nk.z - 0.07], [N - 0.07, ch.x * 0.74, ch.y * 0.86, ch.z * 0.94]]
	var nsk := func(p): return Q._nsk(k, p)
	var sf := func(a: float, y: float, _v: float) -> float: return 0.035 * sin(clampf((y - (N - 0.07)) / (0.145 * q + 0.07), 0.0, 1.0) * PI * 2.0 + 0.5) * 0.35 + 0.012 * sin(a * 5.0 + y * 30.0)
	var cg: Dictionary = P._cl(k, {"keys": sk, "ny": 18, "na": 64, "rng": func(_v): return Vector2(0.04, TAU - 0.04), "top": func(_a): return N + 0.075 * q, "hem": func(a): return N - 0.07 + 0.012 * cos(float(a)),
		"fold": sf, "col": func(_a, _y, _v): return scf, "gain": 5.0, "th": 0.006, "inner": scf.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.0065, scf.darkened(0.06), false, nsk)
	# önde binen kanat: sol yandan gelir, yarığın üstünü kapatır
	var sk2 := []
	for e in sk:
		sk2.append([e[0], float(e[1]) + 0.005, float(e[2]) + 0.006, float(e[3]) - 0.005])
	var fl: Dictionary = P._cl(k, {"keys": sk2, "ny": 16, "na": 14, "rng": func(_v): return Vector2(-0.09, 0.62), "top": func(_a): return N + 0.073 * q, "hem": func(a): return N - 0.066 + 0.012 * cos(float(a)),
		"fold": sf, "col": func(_a, _y, _v): return scf.lightened(0.03), "gain": 5.0, "th": 0.005, "inner": scf.darkened(0.3), "skin": nsk})
	P._cord(k, fl["ea"], 0.0045, scf.darkened(0.12), false, nsk)
	for yy in [N + 0.04 * q, N - 0.012]:
		var e5: Array = Q._spt(sk2, func(a, y): return sf.call(float(a), float(y), 0.0), -0.0, yy, 0.004)
		P._stud(k, e5[0], e5[1], 0.0055, Color(0.12, 0.12, 0.13) if v == 1 else Color(0.85, 0.85, 0.86), [["Neck", 0.5], ["UpperChest", 0.5]])


## Köpekbalığı: uyluk önünde, burnu yukarı, kuyruğu dize (kabartma, ayrı parça)
static func _shark(k, le: Dictionary, pa: Callable, col: Color) -> void:
	var s0: float = 0.2
	var a0: float = J._outer_a(le, s0, Vector3(0.25, 0.0, 1.0).normalized())
	var mp: Callable = AF._lmap(le, s0, a0, pa)
	var o: Vector3 = Q._ls(le, s0, a0, 0.0)[1]
	var skf := func(_p): return P._lskin(le, s0)
	# gövde: iki ucu sivri uzun mekik (boy dikey, hafif eğik)
	var rot := 1.75
	var body := func(th: float) -> float:
		var x: float = cos(th - rot)
		var y: float = sin(th - rot)
		return 1.0 / sqrt(x * x + pow(y / 0.2, 2.0)) * (1.0 - 0.35 * pow(absf(x), 6.0))
	Q._disc(k, mp, o, 0.16, 0.005, body, func(u, w): return col.lightened(0.12) if float(w) * cos(rot) - float(u) * sin(rot) > 0.15 else col, skf, 3, 36)
	# yüzgeçler: sırt, iki göğüs, kuyruk çatalı
	var d := Vector2(cos(rot), sin(rot))
	var nrm := Vector2(-d.y, d.x)
	for e in [[0.02, 0.03, 0.75, 0.04], [0.05, -0.028, -0.9, 0.034], [-0.03, -0.028, -1.05, 0.028], [-0.15, 0.024, 0.65, 0.04], [-0.15, -0.024, -0.65, 0.038]]:
		var c: Vector2 = d * float(e[0]) + nrm * float(e[1])
		var fa: float = rot + float(e[2])
		var fin := func(th: float) -> float:
			var x: float = cos(th - fa)
			return 0.25 + 0.75 * pow(maxf(0.0, x), 1.5)
		Q._disc(k, func(u, w, l): return mp.call(c.x + float(u), c.y + float(w), l), o, float(e[3]), 0.0045, fin, func(_u, _w): return col.darkened(0.08), skf, 2, 18)


# ------------------------------------------------------------------ Hagane Midori (ref Shinobi Striker "Metal Outfit"): uzun kollu yeşil tulum (yan dikiş), dört sıra dolgu turuncu boyunluk, Konoha arması kazınmış
## metal plakalı siyah kemer, dirsek altından avuca beyaz sargı, sağ uylukta beyaz bant + siyah kılıf, dizin altından bileğe fitilli, ağzı kalın turuncu tozluk
static func _metal(k) -> void:
	var gr := Color(0.12, 0.4, 0.32)
	var gdk := gr.darkened(0.35)
	var og := Color(0.9, 0.5, 0.16)
	var ogd := Color(0.66, 0.3, 0.09)
	var wh := Color(0.95, 0.94, 0.92)
	var bk := Color(0.1, 0.1, 0.11)
	var mt := Color(0.7, 0.72, 0.76)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# tulum gövdesi: bedene oturur, kemere inen gerilme kırışıkları
	var by: float = H + 0.07
	var tk := [P._kp(nk, N + 0.03, 0.01), [N - 0.05, ch.x * 0.95, ch.y * 0.9, ch.z * 0.99], P._kp(ch, C - 0.03, 0.012), P._kp(wa, H + 0.12, 0.016), P._kp(hp, H - 0.04, 0.018), [H - 0.1, hp.x * 0.92, hp.y * 0.9, hp.z * 0.9]]
	var tf := func(a: float, y: float, _v: float) -> float:
		var nb: float = 1.0 - exp(-pow((y - by) / 0.03, 2.0))
		var t: float = clampf((C - y) / maxf(0.05, C - by), 0.0, 1.0)
		return nb * (t * (0.01 * sin(a * 7.0 + y * 12.0) + 0.005 * sin(a * 13.0 - y * 20.0)) + 0.004 * sin(a * 5.0 + y * 9.0))
	P._cl(k, {"keys": tk, "ny": 34, "na": 72, "top": func(_a): return N + 0.03, "hem": func(_a): return H - 0.1, "fold": tf, "col": func(_a, _y, _v): return gr, "gain": 6.0, "th": 0.0, "skin": tsk})
	K._seat(k, b, gr.darkened(0.05))
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tff, [Vector2(sg * PI * 0.5, N - 0.06), Vector2(sg * PI * 0.5, by + 0.025)], 0.0022, 0.0012, 0.0012, gdk, tsk, 8)
	# kemer + plaka (Konoha arması kazınmış)
	P._bd(k, P._ring_pts(tk, by, 0.004, 88), 0.017, 0.0045, bk, true, tsk)
	var fe: Array = Q._spt(tk, tff, 0.0, by, 0.009)
	var fo: Vector3 = fe[1]
	var ux: Vector3 = Vector3.UP.cross(fo).normalized()
	var pbo := [["Hips", 0.5], ["Spine", 0.5]]
	P._boxr(k, fe[0], ux * 0.042, Vector3(0, 0.0155, 0), fo * 0.0035, mt, pbo, 0.3)
	var pc: Vector3 = (fe[0] as Vector3) + fo * 0.0034
	var mp := func(u: float, w: float, l: float) -> Vector3: return pc + ux * u + Vector3.UP * w + fo * l
	var pk := func(_p): return pbo
	var sw := []
	for i in 22:
		var t := float(i) / 21.0
		var th := 0.3 + t * TAU * 1.3
		sw.append(Vector2(cos(th), sin(th)) * 0.0095 * lerpf(1.0, 0.15, t) + Vector2(-0.004, -0.001))
	R._lstrip(k, mp, sw, 0.0011, 0.0004, 0.0009, mt.darkened(0.5), pk)
	R._lstrip(k, mp, [Vector2(0.004, 0.0075), Vector2(0.014, 0.011), Vector2(0.019, 0.0), Vector2(0.006, -0.0085)], 0.0011, 0.0004, 0.0009, mt.darkened(0.5), pk)
	R._lstrip(k, mp, [Vector2(-0.014, 0.0), Vector2(-0.026, 0.0)], 0.0011, 0.0004, 0.0009, mt.darkened(0.5), pk)
	for sx in [-1.0, 1.0]:
		P._stud(k, pc + ux * (0.035 * sx), fo, 0.0022, mt.lightened(0.1), pbo)
	# kollar: uzun kol, dirsek altından avuca sargı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.3
		var sf := func(s: float, a: float) -> float:
			return (0.0075 + 0.0025 * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.06, 2.0)) * sin(a * 3.0 + s * 32.0)) * (1.0 - 0.6 * smoothstep(0.55, 0.62, s))
		P._lt(k, ar, sf, func(s, a, ins): return gdk if ins else P._fs(gr, float(sf.call(float(s), float(a))) - 0.0075, 16.0), 0.0, 0.63, 30, 20)
		P._lt(k, ar, func(_s, _a): return 0.0025, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.1), 0.58, 0.975, 16, 18)
		P._wraps(k, ar, 0.6, 0.955, 14, 0.0062, 0.0105, wh, 0.009)
		K._glove(k, sd, ar, wh.darkened(0.03), wh.darkened(0.1))
	# bacaklar: tulum paçası tozluğa girer; tozluk fitilli, ağzı kalın
	var leR: Dictionary = {}
	var paR: Callable
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 1.5 if sd == "Left" else 0.4
		var s1: float = kn + 0.09
		var pa := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			return (0.011 + 0.008 * exp(-pow((s - kn * 0.55) / (kn * 0.6), 2.0))) * (1.0 - 0.35 * inn * (1.0 - smoothstep(0.25, 0.5, s))) + 0.0065 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 34.0 + sv) + 0.003 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s) - 0.006 * smoothstep(kn + 0.02, s1, s)
		P._lt(k, le, pa, func(s, a, ins): return gdk if ins else P._fs(gr, float(pa.call(float(s), float(a))) - 0.012, 14.0), 0.0, s1, 34, 22)
		if sd == "Right":
			leR = le
			paR = pa
		var oa: float = J._outer_a(le, kn + 0.3, Vector3(sg, 0.0, 0.0))
		var lg := func(s: float, a: float) -> float:
			var u: float = clampf((s - kn - 0.02) / (0.995 - kn - 0.02), 0.0, 1.0)
			var rib: float = 0.0035 * cos(a * 8.0 + sv) * (1.0 - 0.75 * exp(-pow((u - 0.03) / 0.045, 2.0)))
			var cuff: float = 0.012 * exp(-pow((u - 0.03) / 0.035, 2.0))
			var sl: float = smoothstep(0.72, 0.95, u) * (0.005 + 0.004 * sin(u * 30.0 + a * 2.0))
			return 0.018 + 0.005 * u + rib + cuff + sl
		P._lt(k, le, lg, func(s, a, ins):
			if ins:
				return og.darkened(0.45)
			var rb: float = cos(float(a) * 8.0 + sv)
			var c0: Color = og.lerp(ogd, 0.35 * smoothstep(0.4, 0.95, cos(float(a) - oa)))
			return c0.darkened(clampf(-rb, 0.0, 1.0) * 0.26).lightened(clampf(rb, 0.0, 1.0) * 0.04), kn + 0.02, 0.995, 32, 48, 0.03)
		Q._ring_on(k, le, kn + 0.075, lg, 0.005, ogd, 0.0)
	J._holster(k, leR, paR, wh, bk)
	# boyunluk: dört sıra dolgu halka
	var q: float = Q._hq(k)
	var nkk := [[N + 0.1, nk.x + 0.008, nk.y + 0.008, nk.z - 0.008], [N + 0.02, nk.x + 0.018, nk.y + 0.016, nk.z - 0.018], [N - 0.03, nk.x + 0.046, nk.y + 0.036, nk.z - 0.04], [N - 0.08, ch.x * 0.62, ch.y * 0.74, ch.z * 0.8]]
	P._roll(k, nkk, N - 0.05, 0.022, 12, 0.008, ogd.lerp(og, 0.45))
	P._roll(k, nkk, N - 0.014, 0.023, 12, 0.009, og)
	P._roll(k, nkk, N + 0.024 * q, 0.021, 12, 0.009, og.lightened(0.03))
	P._roll(k, nkk, N + 0.058 * q, 0.018, 12, 0.008, og)


# ------------------------------------------------------------------ Kōsen Wakate (ref Shinobi Striker "Minato Outfit, Genin Ver."): file iç gömlek (mavi biyeli yaka), önü açık kalçaya inen açık gri ceket
## (koyu dik yaka, koyu ön kenar + etek bandı, kolun dışında iki koyu çizgi, koyu manşet, önde cep yarıkları), dizin altında bota giren bol mavi pantolon, uzun siyah bot, sol kalçada kahve kese
static func _minato_genc(k) -> void:
	var jg := Color(0.83, 0.82, 0.87)
	var tr := Color(0.13, 0.14, 0.21)
	var nb := Color(0.26, 0.27, 0.31)
	var ntc := Color(0.07, 0.07, 0.08)
	var bl := Color(0.17, 0.36, 0.62)
	var bt := Color(0.1, 0.1, 0.12)
	var br := Color(0.45, 0.3, 0.18)
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
	# file iç gömlek: koyu taban + gerçek ağ iplikleri, yakada mavi biye
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return nb, 0.006)
	P._net_patch(k, ik, func(a, _y): return absf(float(a)) < 0.8, -0.8, 0.8, H - 0.04, N + 0.02, 0.019, 0.0011, 0.0018, ntc)
	P._cord(k, P._ring_pts([P._kp(nk, N + 0.04, 0.009)], N + 0.04, 0.0, 44), 0.004, Color(0.22, 0.32, 0.62), true, nsk)
	K._seat(k, b, bl)
	# pantolon: bol, bota girer; bot dizin altına çıkar
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.9 if sd == "Left" else 0.6
		var tk: float = kn + 0.11
		Q._baggy(k, le, bl, bt, 0.016, 0.03, tk, sv)
		var bf := func(s: float, a: float) -> float: return 0.012 + 0.0045 * smoothstep(tk + 0.02, tk - 0.03, s) + 0.0012 * sin(a * 4.0 + s * 26.0) * smoothstep(tk + 0.05, 0.95, s)
		P._lt(k, le, bf, func(s, a, ins): return bt.darkened(0.4) if ins else P._fs(bt.lightened(0.04), 0.0012 * sin(float(a) * 4.0 + float(s) * 26.0), 12.0), tk - 0.035, 0.995, 22, 22)
		Q._ring_on(k, le, tk - 0.03, bf, 0.006, bt.lightened(0.07), 0.003)
	# sol kalçada kese
	var bkk := [P._kp(hp, H + 0.02, 0.016), P._kp(hp, H - 0.12, 0.02)]
	var e2: Array = P._fp(bkk, hp.x * 0.45, H - 0.075, false, 0.018)
	P._boxr(k, e2[0], Vector3(0.034, 0, 0), Vector3(0, 0.028, 0), (e2[1] as Vector3) * 0.016, br, [["Hips", 1.0]])
	P._boxr(k, (e2[0] as Vector3) + (e2[1] as Vector3) * 0.015 + Vector3(0, 0.014, 0), Vector3(0.036, 0, 0), Vector3(0, 0.012, 0), (e2[1] as Vector3) * 0.004, br.darkened(0.12), [["Hips", 1.0]], 0.25)
	# ceket: önü açık, kalçaya iner
	var hem: float = H - 0.035
	var fam := func(p): return AA._fam(k, p, hem)
	var cj := [P._kp(nk, N + 0.012, 0.034), [N - 0.055, ch.x * 1.05, ch.y * 0.98, ch.z * 1.07], P._kp(ch, C - 0.03, 0.04), P._kp(wa, H + 0.12, 0.046), [hem, hp.x + 0.05, hp.y + 0.05, hp.z - 0.05]]
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		return smoothstep(0.4, 0.8, aw) * (0.008 * sin(a * 6.0 + y * 15.0) + 0.006 * sin(a * 11.0 - y * 9.0) * smoothstep(C, hem, y))
	var jff := func(a, y): return jf.call(float(a), float(y))
	var jg2: Dictionary = P._cl(k, {"keys": cj, "ny": 34, "na": 88, "rng": func(vv): return Vector2(lerpf(0.5, 0.56, float(vv)), TAU - lerpf(0.5, 0.56, float(vv))), "top": func(_a): return N + 0.012, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return jf.call(float(a), float(y)), "col": func(_a, _y, _v): return jg, "gain": 6.0, "th": 0.006, "inner": jg.darkened(0.3), "skin": fam})
	AA._edge_band(k, jg2["ea"], 0.0095, 0.003, tr, fam, 1.0)
	AA._edge_band(k, jg2["eb"], 0.0095, 0.003, tr, fam, -1.0)
	P._bd(k, AA._yl(jg2["hem"], 0.013), 0.0135, 0.003, tr, false, fam)
	for sg in [1.0, -1.0]:   # cep yarıkları + yan dikiş
		Q._run(k, cj, jff, [Vector2(sg * 0.78, H + 0.1), Vector2(sg * 0.95, H + 0.02)], 0.0034, 0.0006, 0.0006, tr, fam, 5)
		Q._run(k, cj, jff, [Vector2(sg * 0.765, H + 0.102), Vector2(sg * 0.935, H + 0.022)], 0.0018, 0.004, 0.0022, jg.lightened(0.05), fam, 5)
		Q._run(k, cj, jff, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, hem + 0.03)], 0.002, 0.0015, 0.0012, jg.darkened(0.2), fam, 8)
	Q._run(k, cj, jff, [Vector2(PI * 0.62, C + 0.05), Vector2(PI, C + 0.04), Vector2(PI * 1.38, C + 0.05)], 0.002, 0.0015, 0.0012, jg.darkened(0.2), tsk, 8)
	# dik yaka: koyu, önü açık
	var q: float = Q._hq(k)
	var ck := [[N + 0.09 * q, nk.x + 0.034, nk.y + 0.034, nk.z - 0.038], [N + 0.025 * q, nk.x + 0.036, nk.y + 0.034, nk.z - 0.04], [N - 0.025, nk.x + 0.054, nk.y + 0.048, nk.z - 0.048]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 46, "rng": func(_v): return Vector2(0.42, TAU - 0.42), "top": func(a): return N + q * lerpf(0.065, 0.09, smoothstep(0.5, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.022,
		"fold": func(a, _y, vv): return 0.008 * (1.0 - float(vv)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return tr, "inner": tr.lightened(0.06), "skin": nsk, "th": 0.006})
	P._cord(k, cg["top"], 0.0035, tr.lightened(0.08), false, nsk)
	# kollar: bileğe, kolun dışında iki koyu çizgi, koyu manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 0.7 if sd == "Left" else 2.2
		var s1 := 0.93
		var sf := func(s: float, a: float) -> float:
			return 0.015 + 0.008 * smoothstep(0.1, 0.5, s) + 0.003 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.84) / 0.045, 2.0)) * sin(a * 5.0 + sv) - 0.005 * smoothstep(0.86, s1, s)
		P._lt(k, ar, sf, func(s, a, ins): return jg.darkened(0.3) if ins else P._fs(jg, float(sf.call(float(s), float(a))) - 0.02, 12.0), 0.0, s1 - 0.035, 34, 22, 0.02)
		var cf := func(s: float, a: float) -> float: return float(sf.call(s, a)) + 0.0015 + 0.002 * sin(clampf((s - s1 + 0.04) / 0.04, 0.0, 1.0) * PI)
		P._lt(k, ar, cf, func(_s, _a, ins): return tr.darkened(0.3) if ins else tr, s1 - 0.04, s1, 5, 22, 0.02)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, jg.darkened(0.35), s1 - 0.07, s1 - 0.004, 5, 22)
		var oa: float = J._outer_a(ar, 0.5, Vector3(sg * 0.4, 1.0, 0.0).normalized())
		for da in [-0.16, 0.16]:
			S._lstrip(k, ar, 0.06, s1 - 0.045, func(_s): return oa + da, func(s, a): return float(sf.call(float(s), float(a))), 0.0034, 0.0016, tr, 28)


# ------------------------------------------------------------------ Kōsen Haori (ref Shinobi Striker "Minato Outfit"): mavimsi siyah uzun kollu gömlek (ön kolda iki açık bağ), mavi pantolon, baldırda beyaz sargı + siyah bot konçu,
## fermuarlı yeşil Konoha yeleği (iki parçalı yaka, omuz yastıkları, parşömen cepleri), üstünde önü açık baldır boyu beyaz haori: dirsekte biten geniş kısa kol (lavanta astar),
## başın arkasına yükselen dik yaka, eteğinde kumaşa oturan ayrı kat kırmızı alev dilleri + kopuk alev damlaları, sırtta 四代目火影
## Kōsen haori ağırlığı (_hsk'den): arka etek baldırı yarı yarıya ve geniş geçişle izler (geri kalkan baldır arka eteği tek köşe gibi
## kaldırmaz, kumaş bütün olarak itilir), uçta ağırlık biraz düşer
static func _hsk2(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.11), 0.5)
	var wb: float = lerpf(0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.9, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, lerpf(0.88, 0.92, bk), smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(0.035, 0.15, bk)
	var s: float = smoothstep(-hw, hw, x)
	var kb: float = smoothstep(k.K + 0.06, k.K - 0.16, p.y) * lerpf(0.3, 0.58, bk) * smoothstep(0.0, 0.7, absf(2.0 * s - 1.0))
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


static func _minato(k) -> void:
	var nv := Color(0.12, 0.13, 0.2)
	var pn := Color(0.16, 0.22, 0.52)
	var ve := Color(0.36, 0.47, 0.36)
	var wh := Color(0.95, 0.95, 0.94)
	var lin := Color(0.8, 0.75, 0.88)
	var rd := Color(0.86, 0.2, 0.17)
	var tie := Color(0.87, 0.86, 0.8)
	var bt := Color(0.1, 0.1, 0.13)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var L: Dictionary = J._suit(k, b, nv, pn, {"bag": 0.014, "tuck": 0.2, "seed": 1.4, "cuff": nv.lightened(0.05)})
	for sd in ["Left", "Right"]:
		var e: Dictionary = L[sd]
		var ar: Dictionary = e["ar"]
		var le: Dictionary = e["le"]
		var pf: Callable = e["pf"]
		var sl: Callable = e["sl"]
		for ss in [0.64, 0.905]:
			Q._ring_on(k, ar, ss, sl, 0.0042, tie, 0.0028)
		J._shin_tape(k, le, pf, float(le["kn"]) + 0.2, 8, wh.darkened(0.04))
		var bf := func(s: float, a: float) -> float: return float(pf.call(s, a)) + 0.0135 + 0.004 * smoothstep(0.9, 0.875, s) + 0.001 * sin(a * 4.0 + s * 30.0)
		P._lt(k, le, bf, func(_s, _a, ins): return bt.darkened(0.4) if ins else bt, 0.875, 0.995, 10, 22)
	# yelek (Konoha jōnin kesimi)
	var vk := [P._kp(nk, N + 0.005, 0.03), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.125, 0.03), P._kp(wa, H + 0.088, 0.025), P._kp(wa, H + 0.052, 0.054), P._kp(wa, H + 0.012, 0.05), P._kp(wa, H - 0.012, 0.024)]
	var vf := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.03 * exp(-pow(a / 0.028, 2.0)) - 0.016 * exp(-pow((aa - 1.72) / 0.05, 2.0))
		if y > H + 0.09:
			g += 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.1, y)
		else:
			g += 0.007 * sin(a * 11.0 + 0.7)
		return g
	P._sheet(k, vk, 40, 72, Callable(), vf, func(a, y, _u, v, _p):
		var c0: Color = P._fs(ve, vf.call(a, y, 0.0), 7.0)
		if y < H + 0.1 and y > H + 0.075:
			c0 = c0.darkened(0.22)
		return c0.darkened(0.2) if v > 0.96 else c0, 0.007, 0.25)
	J._collar(k, [P._kp(nk, N + 0.092, 0.03, 0.04), P._kp(nk, N + 0.05, 0.03, 0.038), P._kp(nk, N - 0.02, 0.05, 0.05)], 0.82, 0.3, ve, ve.lightened(0.08))
	var cc := Vector3(0.0, C, 0.0)
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.72, 2.32, float(v))
			var y: float = lerpf(N - 0.012, N - 0.078, float(u))
			return P._sa(vk, a, y, 0.0)[0]
		J._pil(k, surf, 12, 14, 0.012, ve.lightened(0.05), cc, 0.16)
		J._pouch(k, vk, sg * ch.x * 0.48, C - 0.115, ch.x * 0.56, 0.135, 3, ve.darkened(0.06), ve.lightened(0.14), sg * -0.012)
	P._strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.0)], true, 0.0052, 0.0, 0.0035, Color(0.82, 0.83, 0.82), 26)
	# haori
	var hem: float = lerpf(k.K, k.F, 0.42)
	var fam := func(p): return _hsk2(k, p, hem)
	var keys: Array = NN._coat_keys(k, b, 0.058, hem, 0.15, 0.12, 0.235)
	keys[0] = P._kp(nk, N + 0.012, 0.05)
	keys[1] = [N - 0.055, ch.x * 1.1 + 0.012, ch.y * 1.0 + 0.014, ch.z * 1.08 - 0.016]
	var ef := func(y: float) -> float: return 0.34 + 0.28 * pow(smoothstep(C - 0.05, N + 0.012, y), 1.2)
	var ff: Callable = NN._coat_fold(k, hem, 0.045)
	var e_h: float = ef.call(hem)
	var rf := func(a: float) -> float: return 0.05 * (1.0 - smoothstep(e_h, e_h + 0.42, absf(wrapf(a, -PI, PI))))
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 46, "na": 88, "rng": func(v): return Vector2(float(ef.call(lerpf(N + 0.012, hem, float(v)))), TAU - float(ef.call(lerpf(N + 0.012, hem, float(v))))),
		"top": func(_a): return N + 0.012, "hem": func(a): return hem + float(rf.call(float(a))), "fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return wh, "gain": 4.0, "th": 0.007, "inner": lin, "skin": fam})
	# alevler: üst kenarı alev dili olan ayrı kırmızı kat
	P._cl(k, {"keys": keys, "ny": 6, "na": 200, "rng": func(_v): return Vector2(e_h, TAU - e_h), "top": func(a): return NN._flame(float(a), hem + 0.1, 0.22) + float(rf.call(float(a))), "hem": func(a): return hem + float(rf.call(float(a))),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return rd, "gain": 3.0, "lift": 0.0028, "skin": fam, "th": 0.003, "inner": rd.darkened(0.3)})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	for e in [[0.82, 0.42], [1.15, 0.34], [-0.84, 0.44], [-1.18, 0.35], [2.0, 0.4], [-2.05, 0.41], [PI, 0.43], [2.6, 0.37], [-2.6, 0.38]]:
		S._flame(k, keys, ffw, float(e[0]), hem + float(e[1]), 0.026, PI * 0.5, rd, rd.darkened(0.04), fam)
	AA._edge_band(k, cg["ea"], 0.011, 0.0035, wh.darkened(0.05), fam, 1.0)
	AA._edge_band(k, cg["eb"], 0.011, 0.0035, wh.darkened(0.05), fam, -1.0)
	# dik yaka: başın arkasına yükselir, dışa açılır
	var q: float = Q._hq(k)
	var cl_k := [[N + 0.17 * q, nk.x + 0.1, nk.y + 0.08, nk.z - 0.11], [N + 0.08 * q, nk.x + 0.075, nk.y + 0.06, nk.z - 0.08], [N + 0.0, nk.x + 0.066, nk.y + 0.056, nk.z - 0.07], [N - 0.05, nk.x + 0.09, nk.y + 0.07, nk.z - 0.085]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var col_g: Dictionary = P._cl(k, {"keys": cl_k, "ny": 16, "na": 56, "rng": func(_v): return Vector2(0.58, TAU - 0.58), "top": func(a): return N + q * lerpf(0.1, 0.165, smoothstep(0.6, 2.3, absf(float(a)))), "hem": func(_a): return N - 0.045,
		"fold": func(a, y, v): return 0.012 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.6) + 0.004 * sin(float(a) * 9.0 + float(y) * 20.0), "col": func(_a, _y, _v): return wh, "inner": lin, "skin": skt, "th": 0.007, "gain": 5.0})
	P._cord(k, col_g["top"], 0.0045, wh.darkened(0.08), false, skt)
	# kollar: dirsekte biten geniş kısa kol, lavanta astar
	for sd in ["Left", "Right"]:
		var ar2: Dictionary = P._limb(k, sd, false)
		NN._bell(k, ar2, wh, lin, 0.03, float(ar2["kn"]) + 0.04, wh.darkened(0.05), 0.02, 1.2 if sd == "Left" else 2.7)
	# sırtta 四代目火影
	var gi := 0
	for gl in [G_YON, A.G_DAI, A.G_ME, A.G_HI, A.G_KAGE]:
		var cy: float = C - 0.03 - gi * 0.082
		var s := 0.034
		for st in gl:
			P._strap(k, keys, [Vector2(-float(st[0]) * s, cy + float(st[1]) * s), Vector2(-float(st[2]) * s, cy + float(st[3]) * s)], false, 0.0056, 0.0068, 0.0016, rd, 3, fam)
		gi += 1


# ------------------------------------------------------------------ Kuro Nagagi (ref Shinobi Striker "Merz Outfit"): göğsü derin V ile açık, bileğe inen koyu cübbe (sol kanat sağın üstüne biner, gri astar),
## etekte ve geniş kol ağızlarında desenli gri bant (kabartma kıvrık dalga), arkada yükselen dik yaka, belde lacivert kuşak + üstünde gri bağ, önde düğüm ve sarkan uç,
## göğüste yara izleri, boyunda siyah dikenli kolye; altta siyah pantolon ve bot konçu. Kadın bedende göğüs sargılı.
static func _kara(k) -> void:
	var cb := Color(0.19, 0.19, 0.25)
	var gy := Color(0.6, 0.59, 0.57)
	var gyd := gy.darkened(0.3)
	var sb := Color(0.2, 0.22, 0.38)
	var bk := Color(0.08, 0.08, 0.09)
	var skc: Color = Q._skc(k)
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
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	var hem: float = F + 0.075
	var fam := func(p): return AA._fam(k, p, hem)
	# çıplak gövde + yara izleri (kadında göğüs sargısı)
	var tk: Array = R._bare_torso(k, b, H - 0.03, not fem)
	var scar: Color = skc.darkened(0.2).lerp(Color(0.72, 0.38, 0.36), 0.35)
	var scars: Array = [[Vector2(0.42, C + 0.035), Vector2(0.15, C - 0.04), Vector2(-0.05, C - 0.1)], [Vector2(-0.38, C + 0.01), Vector2(-0.12, C - 0.055)], [Vector2(0.12, H + 0.17), Vector2(0.3, H + 0.12)]]
	if fem:
		var wk := []
		for y in [C + 0.06, C + 0.0, C - 0.06, C - 0.11]:
			wk.append(P._kp(k.M(y, k.UA), y, 0.007))
		var wc := Color(0.86, 0.84, 0.78)
		SE.body_layer(k, wk, 10, 52, func(_i, j, _p): return wc.darkened(0.08) if j in [0, 10] else wc, func(a, y): return 0.01 * sin(a * 9.0 + y * 40.0))
		scars = [[Vector2(0.3, C + 0.1), Vector2(0.05, C + 0.075)], [Vector2(0.12, H + 0.17), Vector2(0.3, H + 0.12)]]
	for sc in scars:
		Q._run(k, tk, Callable(), sc, 0.0022, 0.0022, 0.0012, scar, tsk, 6)
	# kolye: siyah ip + aşağı bakan dikenler
	var nkk := [P._kp(nk, N + 0.0, 0.012)]
	var rp: Array = P._ring_pts(nkk, N - 0.005, 0.0, 40)
	P._cord(k, rp, 0.0032, bk, true, nsk)
	for i in 9:
		var a: float = lerpf(-1.1, 1.1, float(i) / 8.0)
		var e0: Array = P._sa(nkk, a, N - 0.008, 0.002)
		var p0: Vector3 = e0[0]
		var o0: Vector3 = e0[1]
		var ln: float = 0.022 - 0.008 * absf(a)
		P._tb(k, [p0, p0 + o0 * 0.004 + Vector3(0, -ln * 0.5, 0), p0 + o0 * 0.006 + Vector3(0, -ln, 0)], func(s, _a): return lerpf(0.0042, 0.0006, float(s)), func(_s, _a, _p): return bk.lightened(0.05), func(_s, _p): return [["Neck", 0.4], ["UpperChest", 0.6]], 6)
	# pantolon + bot konçu
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var pa: Callable = K._pant(k, le, bk.lightened(0.04), 0.009, 0.012, 0.995, 1.6 if sd == "Left" else 3.4)
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.006 + 0.003 * smoothstep(0.9, 0.88, float(s)), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.885, 0.995, 8, 20)
	# cübbe: iki kanat; sol kanat sağın üstüne biner, kuşak üstünde derin V
	var keys := [P._kp(nk, N + 0.012, 0.026), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), [H - 0.04, hp.x + 0.045, hp.y + 0.06, hp.z - 0.045],
		[KN + 0.08, hp.x + 0.065, hp.y + 0.095, hp.z - 0.085], [hem, hp.x + 0.085, hp.y + 0.08, hp.z - 0.115]]
	var sy: float = H + 0.1
	var st: float = sy + 0.05
	var eo := func(y: float) -> float: return lerpf(0.13, 0.62, smoothstep(st - 0.02, N - 0.02, y))
	var kf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return t * (0.022 * sin(a * 5.0 + 0.4) + 0.011 * sin(a * 9.0 + 1.7)) + (1.0 - up) * 0.006 * sin(a * 7.0 + y * 10.0) * smoothstep(0.0, 0.1, up)
	var uf := func(a: float, y: float) -> float: return float(kf.call(a, y)) - 0.02 * smoothstep(-0.8, -0.4, a)
	var yv := func(v: float) -> float: return lerpf(N + 0.012, hem, v)
	var rl := func(v: float) -> Vector2:
		var y: float = yv.call(v)
		if y > st:
			return Vector2(eo.call(y), PI + 0.015)
		return Vector2(lerpf(-0.45, float(eo.call(st)), smoothstep(st - 0.08, st, y)), PI + 0.015)
	var rr := func(v: float) -> Vector2:
		var y: float = yv.call(v)
		if y > st:
			return Vector2(-PI - 0.015, -float(eo.call(y)))
		return Vector2(-PI - 0.015, lerpf(0.42, -float(eo.call(st)), smoothstep(st - 0.08, st, y)))
	var colf := func(_a, _y, _v): return cb
	var gL: Dictionary = P._cl(k, {"keys": keys, "ny": 56, "na": 60, "rng": rl, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return kf.call(float(a), float(y)), "col": colf, "gain": 5.0, "th": 0.006, "inner": gy.darkened(0.15), "skin": fam})
	var gR: Dictionary = P._cl(k, {"keys": keys, "ny": 56, "na": 60, "rng": rr, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return uf.call(float(a), float(y)), "col": colf, "gain": 5.0, "th": 0.006, "inner": gy.darkened(0.15), "skin": fam})
	# V kenarı: gri astar dönüşü (kuşak üstü); sol kanadın aşağı inen kenarı koyu biye
	var la := []
	var lb := []
	for p in gL["ea"]:
		if (p as Vector3).y > sy:
			la.append(p)
		else:
			lb.append(p)
	var ra := []
	for p in gR["eb"]:
		if (p as Vector3).y > sy:
			ra.append(p)
	AA._edge_band(k, la, 0.013, 0.004, gy.darkened(0.08), fam, 1.0)
	AA._edge_band(k, ra, 0.013, 0.004, gy.darkened(0.08), fam, -1.0)
	AA._edge_band(k, lb, 0.008, 0.003, cb.lightened(0.07), fam, 1.0)
	# etek bandı: iki kanatta gri kat + kabartma dalga kıvrımları
	var bh: float = 0.13
	for e in [[gL, rl, kf, 0.0032], [gR, rr, uf, 0.0026]]:
		var ffx: Callable = e[2]
		var rgx: Callable = e[1]
		var bg: Dictionary = P._cl(k, {"keys": keys, "ny": 6, "na": 60, "rng": func(_v): return rgx.call(1.0), "top": func(_a): return hem + bh, "hem": func(_a): return hem, "fold": func(a, y, _v): return ffx.call(float(a), float(y)),
			"col": func(_a, _y, _v): return gy, "gain": 3.0, "lift": float(e[3]), "th": 0.003, "inner": gy.darkened(0.3), "skin": fam})
		P._cord(k, bg["top"], 0.0024, gyd, false, fam)
	var curl := func(mp: Callable, sc: float, fl: float, skf: Callable) -> void:
		var pts := []
		for i in 26:
			var t: float = float(i) / 25.0
			var th: float = PI * 0.2 + t * TAU * 1.35
			pts.append(Vector2(cos(th) * fl, sin(th)) * 0.02 * sc * lerpf(1.0, 0.18, t) + Vector2(-0.035 * sc * fl * (1.0 - smoothstep(0.0, 0.25, t)) * 0.0, 0.0))
		var tail := []
		for i in 10:
			var t: float = float(i) / 9.0
			tail.append(Vector2((0.02 + 0.045 * t) * fl * sc, -0.02 * sc + 0.012 * sc * sin(t * PI)))
		R._lstrip(k, mp, pts, 0.0021 * sc, 0.0058, 0.0014, gyd, skf)
		R._lstrip(k, mp, tail, 0.0021 * sc, 0.0058, 0.0014, gyd, skf)
	for a0 in [-0.3, 0.3, 0.85, 1.45, 2.05, 2.65, -2.65, -2.05, -1.45, -0.95]:
		var over: bool = a0 >= -0.4
		var ffx2: Callable = kf if over else uf
		var mp2: Callable = Q._local(keys, func(a, y): return ffx2.call(float(a), float(y)), a0, hem + bh * 0.5)
		curl.call(mp2, 1.0, 1.0 if int(round(a0 * 10.0)) % 2 == 0 else -1.0, fam)
	# geniş kollar: bileğe iner, ağzında desenli gri bant
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.4 if sd == "Left" else 2.9
		var s1 := 0.93
		var fl: float = 0.05
		var bw: float = 0.11
		NN._bell(k, ar, cb, gy.darkened(0.15), fl, s1, gy, bw, sv)
		var en: float = ar["kn"]
		var bad := func(s: float, a: float) -> float:
			var qq: float = pow(clampf((s - en + 0.16) / (s1 - en + 0.16), 0.0, 1.0), 1.4)
			return 0.02 + fl * qq + (0.003 + 0.008 * qq) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.0028
		var sg: float = ar["sg"]
		for da in [0.0, 1.9, -1.9]:
			var a1: float = J._outer_a(ar, s1 - bw * 0.5, Vector3(sg * 0.4, 1.0, 0.0).normalized()) + da
			var mp3: Callable = AF._lmap(ar, s1 - bw * 0.5, a1, bad)
			var s2: float = s1 - bw * 0.5
			curl.call(func(u, w, l): return mp3.call(float(u) * 0.75, float(w) * 0.75, float(l) - 0.0025), 0.75, 1.0 if da >= 0.0 else -1.0, func(_p): return P._lskin(ar, s2))
	# dik yaka: arkada yükselir, içi gri
	var q: float = Q._hq(k)
	var cl_k := [[N + 0.12 * q, nk.x + 0.07, nk.y + 0.06, nk.z - 0.08], [N + 0.05 * q, nk.x + 0.05, nk.y + 0.046, nk.z - 0.058], [N - 0.01, nk.x + 0.05, nk.y + 0.046, nk.z - 0.056], [N - 0.05, nk.x + 0.07, nk.y + 0.055, nk.z - 0.068]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var cgc: Dictionary = P._cl(k, {"keys": cl_k, "ny": 12, "na": 50, "rng": func(_v): return Vector2(0.8, TAU - 0.8), "top": func(a): return N + q * lerpf(0.03, 0.115, smoothstep(0.8, 2.4, absf(float(a)))), "hem": func(_a): return N - 0.04,
		"fold": func(a, _y, v): return 0.012 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.6), "col": func(_a, _y, _v): return cb, "inner": gy.darkened(0.1), "skin": skt, "th": 0.006, "gain": 5.0})
	P._cord(k, cgc["top"], 0.004, gy.darkened(0.1), false, skt)
	# kuşak: lacivert geniş bez + üstünde gri bağ; önde düğüm ve sarkan iki uç
	P._sash(k, keys, sy, 0.045, 0.008, sb, 0.12)
	P._sash(k, keys, sy + 0.01, 0.0125, 0.019, gy, 0.06)
	var kc: Array = Q._spt(keys, func(a, y): return kf.call(float(a), float(y)), 0.14, sy - 0.005, 0.03)
	P._boxr(k, kc[0], Vector3(0.026, 0.004, 0), Vector3(-0.004, 0.022, 0), (kc[1] as Vector3) * 0.014, sb.darkened(0.08), [["Hips", 0.5], ["Spine", 0.5]], 0.45)
	var kff := func(a, y): return kf.call(float(a), float(y))
	Q._run(k, keys, kff, [Vector2(0.15, sy - 0.03), Vector2(0.16, H - 0.06), Vector2(0.19, H - 0.2)], 0.03, 0.012, 0.004, sb, fam, 8)
	Q._run(k, keys, kff, [Vector2(0.07, sy - 0.03), Vector2(0.02, H - 0.07), Vector2(-0.03, H - 0.15)], 0.022, 0.017, 0.004, sb.darkened(0.08), fam, 8)
