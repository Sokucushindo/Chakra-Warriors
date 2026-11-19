extends RefCounted
## Elle modellenmiş setler, parti u: ss_seytan, ss_kok_reisi, ss_delta, ss_denki, ss_gezegen, ss_kurbaga. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), m (M), q (Q), r (R), s (S) dosyalarından; burada yıldız / hilal / gezegen kabartmaları, zincir, mini etek ağırlığı ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const S = preload("res://scripts/actors/set_el_s.gd")

const DONE := ["ss_seytan", "ss_kok_reisi", "ss_delta", "ss_denki", "ss_gezegen", "ss_kurbaga"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_seytan": _seytan(k)
		"ss_kok_reisi": _kok(k)
		"ss_delta": _delta(k)
		"ss_denki": _denki(k)
		"ss_gezegen": _gezegen(k)
		"ss_kurbaga": _kurbaga(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Düz kenarlı yıldız: n uç, iç oran; rot ilk ucun açısı (disk koordinatında PI/2 = yukarı)
static func _star(th: float, n: float, inner: float, rot := PI * 0.5) -> float:
	var al: float = PI / n
	var f: float = absf(fposmod(th - rot + al, 2.0 * al) - al)
	var py: float = inner * sin(al)
	var px: float = inner * cos(al)
	return py / (cos(f) * py - sin(f) * (px - 1.0))


## Mini etek ağırlığı: etek ucu bacakla açılır ama yanlar daha az izler (koşuda sivri kanat açılmaz)
static func _msk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var side: float = absf(p.x) / maxf(0.001, absf(p.x) + absf(p.z))
	var w: float = t * 0.55 * (1.0 - 0.45 * smoothstep(0.45, 0.85, side)) * lerpf(1.0, 0.55, smoothstep(0.0, -0.06, p.z))
	var s: float = smoothstep(-0.09, 0.09, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Yol boyunca eşit aralıklı noktalar (zincir halkası, perçin dizisi)
static func _resample(pts: Array, step: float) -> Array:
	var out := [pts[0]]
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var l: float = (b - a).length()
		var t := 0.0
		while acc + (l - t) >= step:
			t += step - acc
			acc = 0.0
			out.append(a.lerp(b, t / maxf(l, 1e-6)))
		acc += l - t
	return out


## Zincir: halkalar sırayla dik / yatık, her halka kendi kemiğinde. pts: [konum, dış yön, kemikler]
static func _chain(k, pts: Array, col: Color, lk := 0.0058) -> void:
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i][0]
		var p1: Vector3 = pts[i + 1][0]
		var o: Vector3 = pts[i][1]
		var c := (p0 + p1) * 0.5
		var tg := (p1 - p0).normalized()
		var sd: Vector3 = o if i % 2 == 0 else tg.cross(o).normalized()
		var ring := []
		for j in 10:
			var th := TAU * j / 10.0
			ring.append(c + tg * cos(th) * lk + sd * sin(th) * lk * 0.58)
		var bo: Array = pts[i][2]
		P._tb(k, ring, func(_s, _a): return 0.00135, func(_s, a, _p): return col.lightened(0.15) if cos(float(a)) > 0.4 else col, func(_s, _p): return bo, 5, true)


## Hilal: dış yay + içten kesen yay (yüzeye oturan kabartma)
static func _crescent(k, mp: Callable, r: float, rot: float, lift: float, col: Color, skinf: Callable) -> void:
	var m2: Callable = R._rot(mp, rot)
	var o: Vector3 = R._out_of(mp)
	var rows := [[], [], []]
	var n := 18
	for i in n + 1:
		var u := float(i) / n
		var t: float = lerpf(0.79, TAU - 0.79, u)
		var tau: float = lerpf(1.14, TAU - 1.14, u)
		var po := Vector2(cos(t), sin(t)) * r
		var pn := (Vector2(0.38, 0.0) + Vector2(cos(tau), sin(tau)) * 0.78) * r
		var pm := (po + pn) * 0.5
		rows[0].append(m2.call(po.x, po.y, lift))
		rows[1].append(m2.call(pm.x, pm.y, lift + 0.0016))
		rows[2].append(m2.call(pn.x, pn.y, lift))
	Q._mesh(k, rows, false, func(_i, j, _p): return col.lightened(0.06) if j == 1 else col, func(_i, _j, p): return skinf.call(p), o)


## Gezegen: kabartma küre + önünden geçen, arkası küreye gömülen eğik halka
static func _planet(k, mp: Callable, r: float, rot: float, lift: float, col: Color, skinf: Callable) -> void:
	var o: Vector3 = R._out_of(mp)
	Q._disc(k, mp, o, r, lift, Callable(), func(u, v):
		var d := Vector2(float(u), float(v)).length()
		return col.darkened(0.12) if d > 0.85 else col, skinf, 4, 28)
	var m2: Callable = R._rot(mp, rot)
	var back := []
	var front := []
	for i in 25:
		var t: float = lerpf(0.0, PI, float(i) / 24.0)
		back.append(Vector2(cos(t) * 1.75 * r, sin(t) * 0.42 * r))
		front.append(Vector2(cos(t + PI) * 1.75 * r, sin(t + PI) * 0.42 * r))
	R._lstrip(k, m2, back, r * 0.17, lift - 0.0012, 0.0014, col.darkened(0.08), skinf)
	R._lstrip(k, m2, front, r * 0.17, lift + 0.0034, 0.0016, col.lightened(0.05), skinf)


## Uzuv yüzeyinde (s, a) yolu: [konum, dış yön, kemik] listesi (zincir için)
static func _lpts(l: Dictionary, ctrl: Array, ad: Callable, lift: float, step: float) -> Array:
	var dense := []
	var sa := []
	for q in P._path(ctrl, 10):
		dense.append(Q._ls(l, q.x, q.y, float(ad.call(q.x, q.y)) + lift)[0])
		sa.append(q)
	var rs: Array = _resample(dense, step)
	var out := []
	for p: Vector3 in rs:
		var best := 0
		var bd := 99.0
		for i in dense.size():
			var d: float = (dense[i] as Vector3).distance_squared_to(p)
			if d < bd:
				bd = d
				best = i
		var q2: Vector2 = sa[best]
		out.append([p, Q._ls(l, q2.x, q2.y, 0.0)[1], P._lskin(l, q2.x)])
	return out


## Kaminarimon arması: üstte iki sarı çeyrek, altta beyaz yarım daire, siyah çerçeve ve ayraçlar
static func _kaminari(k, keys: Array, ff: Callable, a: float, y: float, r: float, skinf: Callable) -> void:
	var mp: Callable = Q._local(keys, ff, a, y)
	var o: Vector3 = Q._spt(keys, ff, a, y)[1]
	var yl := Color(1.0, 0.85, 0.33)
	var wh := Color(0.97, 0.97, 0.96)
	var ink := Color(0.08, 0.08, 0.09)
	Q._disc(k, mp, o, r * 1.08, 0.0026, Callable(), func(_u, _v): return ink, skinf, 2, 36)
	Q._disc(k, mp, o, r, 0.0042, Callable(), func(u, v):
		if float(v) < 0.0:
			return wh
		return yl.darkened(0.08) if float(u) < 0.0 else yl, skinf, 5, 36)
	R._lstrip(k, mp, [Vector2(-r * 0.98, 0.0), Vector2(r * 0.98, 0.0)], 0.0022, 0.0056, 0.0012, ink, skinf)
	R._lstrip(k, mp, [Vector2(0.0, 0.0), Vector2(0.0, r * 0.98)], 0.0022, 0.0056, 0.0012, ink, skinf)


# ------------------------------------------------------------------ Akuma Fūdo (ref Shinobi Striker "Daemon Outfit"): yeşil tişört, göbek üstünde biten kırmızı kapüşonlu (fermuar, yıldız uçlu çekme, raglan dikişte
## perçin dizisi, boyna düşmüş kapüşon, elin üstüne inen uzun kol, ribanalı etek ucu, sırtta yıldız), gri çizgili kemer + toka, sağ uyluğa sarkan zincir,
## cep ağzında perçinli kırmızı diz şortu
static func _seytan(k) -> void:
	var rd := Color(0.596, 0.125, 0.18)
	var gr := Color(0.165, 0.604, 0.416)
	var stl := Color(0.78, 0.79, 0.82)
	var gy := Color(0.66, 0.66, 0.68)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return gr.lightened(0.05) if j < 4 else gr, 0.008, H + 0.03)
	# şort
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return rd.darkened(0.03))
	var legs := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn - 0.015
		var sv: float = 0.8 if sd == "Left" else 2.2
		P._bare(k, le, skc, s1 - 0.08, 1.0)
		var ad: Callable = R._short_leg(k, le, rd, s1, 0.02, 0.028, sv)
		R._hem_roll(k, le, ad, s1, rd.darkened(0.06), 0.03, 0.003)
		legs[sd] = [le, ad, s1]
	# kemer: gri, iki koyu çizgi, toka
	var by: float = H + 0.062
	P._sash(k, sk, by, 0.017, 0.008, gy, 0.06)
	var bsk := func(p): return k.torso_skin(p.y)
	for dy in [-0.0075, 0.0075]:
		P._bd(k, P._ring_pts(sk, by + dy, 0.0185, 72), 0.0021, 0.0014, gy.darkened(0.42), true, bsk)
	var fc: Array = P._fp(sk, 0.0, by, true, 0.021)
	P._boxr(k, fc[0], Vector3(0.026, 0, 0), Vector3(0, 0.019, 0), (fc[1] as Vector3) * 0.006, stl, [["Hips", 1.0]], 0.35)
	P._boxr(k, (fc[0] as Vector3) + (fc[1] as Vector3) * 0.005, Vector3(0.016, 0, 0), Vector3(0, 0.0095, 0), (fc[1] as Vector3) * 0.0035, gy.darkened(0.3), [["Hips", 1.0]], 0.3)
	# cep ağzı perçinleri: belden yana kavis
	for sg in [1.0, -1.0]:
		for i in 7:
			var t := float(i) / 6.0
			var e: Array = Q._spt(sk, Callable(), sg * lerpf(0.5, 1.32, t), lerpf(H + 0.035, H - 0.045, t * t), 0.016)
			P._stud(k, e[0], e[1], 0.0052, stl, [["Hips", 1.0]])
	# zincir: kemerin sağ önünden sağ uyluğa sarkıp yana döner
	var rl: Dictionary = legs["Right"][0]
	var rad: Callable = legs["Right"][1]
	var cp := []
	var e0: Array = Q._spt(sk, Callable(), -0.28, by - 0.016, 0.022)
	cp.append([e0[0], e0[1], [["Hips", 1.0]]])
	var lp: Array = _lpts(rl, [Vector2(0.0, -0.36), Vector2(0.12, -0.55), Vector2(0.27, -0.9), Vector2(0.3, -1.25), Vector2(0.2, -1.55), Vector2(0.04, -1.78)], rad, 0.007, 0.0094)
	cp.append_array(lp)
	var e1: Array = Q._spt(sk, Callable(), -1.95, by - 0.016, 0.022)
	cp.append([e1[0], e1[1], [["Hips", 1.0]]])
	_chain(k, cp, stl.darkened(0.08))
	# kapüşonlu: göbek üstünde biter, altta fermuar ters V açılır
	var yh: float = H + 0.088
	var hk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.97, ch.z * 1.05], P._kp(ch, C - 0.03, 0.032), P._kp(k.M(yh, k.UA), yh, 0.036)]
	var ef := func(y: float) -> float: return 0.01 + 0.3 * pow(smoothstep(yh + 0.12, yh, y), 1.4)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / maxf(0.05, C - yh), 0.0, 1.0)
		return 0.012 * sin(a * 6.0 + y * 20.0) * t + 0.005 * sin(a * 11.0 - y * 31.0) * smoothstep(N, C - 0.02, y) + 0.016 * smoothstep(yh + 0.05, yh, y) * (0.5 + 0.5 * sin(a * 9.0))
	var tsk := func(p): return k.torso_skin(p.y)
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 30, "na": 84, "rng": func(v):
		var e: float = ef.call(lerpf(N + 0.012, yh, float(v)))
		return Vector2(e, TAU - e),
		"top": func(_a): return N + 0.012, "hem": func(_a): return yh, "fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.007, "inner": rd.darkened(0.42), "skin": tsk})
	for ed in [hg["ea"], hg["eb"]]:
		P._bd(k, ed, 0.0034, 0.0026, stl.darkened(0.35), false, tsk)
	var hm := []
	for p in hg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.0095, 0))
	P._bd(k, hm, 0.0105, 0.0042, rd.darkened(0.1), false, tsk)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# yıldız uçlu fermuar çekmesi
	var zp: Callable = Q._local(hk, ffw, 0.0, N - 0.028)
	Q._disc(k, zp, Q._spt(hk, ffw, 0.0, N - 0.028)[1], 0.019, 0.006, func(th): return _star(float(th), 5.0, 0.42), func(u, v): return stl.darkened(0.15) if Vector2(float(u), float(v)).length() > 0.8 else stl, tsk, 3, 60)
	# raglan dikişi + perçin dizisi (önde)
	for sg in [1.0, -1.0]:
		Q._run(k, hk, ffw, [Vector2(sg * 0.62, N - 0.008), Vector2(sg * 0.92, C + 0.03), Vector2(sg * 1.22, C - 0.075)], 0.0038, 0.003, 0.0024, rd.darkened(0.22), tsk, 8)
		for i in 9:
			var t := float(i) / 8.0
			var ya: float = lerpf(N - 0.02, C - 0.068, t)
			var e: Array = Q._spt(hk, ffw, sg * lerpf(0.66, 1.2, t), ya, 0.0055)
			P._stud(k, e[0], e[1], 0.0056, stl, k.torso_skin(ya))
	# sırtta yıldız
	var bp: Callable = Q._local(hk, ffw, PI, C - 0.125)
	var bo: Vector3 = Q._spt(hk, ffw, PI, C - 0.125)[1]
	Q._disc(k, bp, bo, 0.074, 0.0035, func(th): return _star(float(th), 5.0, 0.42), func(_u, _v): return rd.darkened(0.45), tsk, 2, 60)
	Q._disc(k, bp, bo, 0.064, 0.0058, func(th): return _star(float(th), 5.0, 0.42), func(u, v): return stl.lightened(0.08) if Vector2(float(u), float(v)).length() < 0.5 else stl, tsk, 4, 60)
	# boyna düşmüş kapüşon: boynu saran bol halka + sırta düşen torba
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var hk2 := [[N + 0.11 * q, nk.x + 0.07, nk.y + 0.05, nk.z - 0.088], [N + 0.05 * q, nk.x + 0.062, nk.y + 0.052, nk.z - 0.075], [N - 0.005, nk.x + 0.068, nk.y + 0.058, nk.z - 0.07], [N - 0.06, ch.x * 0.8, ch.y * 0.88, ch.z * 0.97]]
	var hf := func(a: float, _y: float, v: float) -> float:
		return 0.05 * sin(float(v) * PI * 2.0 + cos(a) * 1.1) * smoothstep(0.0, 0.25, float(v)) * (1.0 - float(v) * 0.6) + 0.012 * sin(a * 8.0 + 0.7) * float(v)
	var cg: Dictionary = P._cl(k, {"keys": hk2, "ny": 14, "na": 60, "rng": func(_v): return Vector2(0.32, TAU - 0.32), "top": func(a):
		return N + q * lerpf(0.05, 0.115, smoothstep(0.3, 2.2, absf(float(a)))), "hem": func(a): return N - 0.045 - 0.02 * smoothstep(1.0, 2.6, absf(float(a))), "fold": hf,
		"col": func(_a, _y, _v): return rd.lightened(0.02), "gain": 6.0, "inner": rd.darkened(0.38), "skin": nsk, "th": 0.007})
	P._cord(k, cg["top"], 0.0052, rd.darkened(0.05), false, nsk)
	var sk2 := []
	for e2 in hk:
		sk2.append([e2[0], float(e2[1]) + 0.014, float(e2[2]) + 0.014, float(e2[3]) - 0.016])
	var bagf := func(a: float, _y: float, v: float) -> float:
		var db: float = clampf((PI - absf(a)) / 1.0, 0.0, 1.0)
		return 0.07 * sin(float(v) * PI) * (1.0 - db * db) + 0.01 * sin(a * 7.0 + 0.3) * float(v)
	var bg: Dictionary = P._cl(k, {"keys": sk2, "ny": 14, "na": 36, "rng": func(_v): return Vector2(PI - 1.0, PI + 1.0), "top": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return N + 0.03 - 0.07 * db * db, "hem": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return C - 0.02 + 0.07 * pow(db, 1.6), "fold": bagf, "col": func(_a, _y, _v): return rd, "gain": 5.0, "inner": rd.darkened(0.35), "skin": tsk, "th": 0.006})
	P._cord(k, bg["hem"], 0.0045, rd.darkened(0.08), false, tsk)
	# kollar: elin üstüne inen uzun kol, dirsek kırışığı, bilekte toplanma, ribanalı ağız
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.5
		var sf := func(s: float, a: float) -> float:
			return 0.014 + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.007 * exp(-pow((s - 0.86) / 0.05, 2.0)) * (0.5 + 0.5 * sin(a * 5.0 + s * 40.0)) - 0.003 * smoothstep(0.92, 0.99, s) + 0.006 * exp(-pow((s - 0.1) / 0.1, 2.0))
		P._lt(k, ar, sf, func(s, a, ins): return rd.darkened(0.4) if ins else P._fs(rd, float(sf.call(float(s), float(a))) - 0.016, 12.0), 0.0, 0.94, 32, 20, 0.03)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0015 + 0.0011 * sin(float(a) * 16.0), func(_s, a, ins): return rd.darkened(0.4) if ins else rd.darkened(0.06 + 0.08 * float(sin(float(a) * 16.0) < 0.0)), 0.93, 0.987, 5, 32, 0.025)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.004, rd.darkened(0.35), 0.86, 0.985, 6, 20)
	P._cur_hem = H - 0.1


# ------------------------------------------------------------------ Ne no Osa (ref Shinobi Striker "Danzo Outfit"): beyaz sarma kimono (sol kanat üstte), mavi-leylak astarlı geniş kollar, sağ kol bilekten sargılı + altın halka,
## siyah geniş paçalı hakama, soluk mor kuşak + sol önde sarkan iki uç, sol belden sağ uyluğa verev dökülen bej örtü
static func _kok(k) -> void:
	var wh := Color(0.925, 0.918, 0.894)
	var pu := Color(0.604, 0.541, 0.69)
	var be := Color(0.902, 0.863, 0.753)
	var bk := Color(0.11, 0.11, 0.133)
	var li := Color(0.55, 0.6, 0.86)
	var gd := Color(0.86, 0.66, 0.24)
	var bn := Color(0.93, 0.92, 0.88)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	M._inner_v(k, b, wh)
	var kk := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.03], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(wa, H + 0.0, 0.034)]
	M._wrap(k, {"keys": kk, "hem": H + 0.0, "col": func(_a, _y, _v): return wh, "fold": func(a, y, _v): return 0.009 * sin(float(a) * 5.0 + float(y) * 14.0) + 0.007 * sin(float(a) * 9.0 - float(y) * 20.0) * smoothstep(C - 0.05, H + 0.05, float(y)),
		"band": wh.darkened(0.05), "band_w": 0.02, "band_y": H + 0.1, "juban": Color(0.98, 0.98, 0.97), "ny": 26, "na": 44, "gain": 4.5})
	# hakama: belden kalçaya pileli üst + iki geniş paça (bilekte yere yakın açılır)
	var hk := [P._kp(wa, H + 0.105, 0.026), P._kp(wa, H + 0.03, 0.032), P._kp(hp, H - 0.05, 0.046), [H - 0.17, hp.x + 0.05, hp.y + 0.056, hp.z - 0.06]]
	var hf := func(a: float, y: float, _u: float) -> float: return smoothstep(H + 0.03, H - 0.13, y) * 0.03 * sin(a * 8.0 + 0.3)
	P._sheet(k, hk, 16, 64, Callable(), hf, func(a, y, _u, _v, _p): return P._fs(bk, float(hf.call(float(a), float(y), 0.0)), 6.0), 0.006, 0.3)
	var hls := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = le["sg"]
		var hl := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.0, 1.0, s)
			var pl: float = sin(a * 6.0 + 0.4 * sg)
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			return (0.036 + 0.075 * fl) * (1.0 - 0.15 * inn * fl) + (0.004 + 0.012 * fl) * (signf(pl) * pow(absf(pl), 0.6)) + 0.003 * P._lf(s, a, 2.0 + sg)
		P._lt(k, le, hl, func(s, a, ins):
			if ins:
				return bk.darkened(0.3)
			var pl: float = sin(float(a) * 6.0 + 0.4 * sg)
			return P._fs(bk.lightened(0.03), (0.004 + 0.012 * smoothstep(0.0, 1.0, float(s))) * pl * 0.6 - 0.002, 9.0), 0.0, 1.0, 36, 30, 0.05)
		K._lt_in(k, le, func(s, a): return float(hl.call(float(s), float(a))) - 0.005, bk.darkened(0.2), 0.5, 1.0, 12, 30)
		hls[sd] = [le, hl]
	# mor kuşak + sol önde düğüm ve sarkan iki uç
	P._sash(k, hk, H + 0.075, 0.033, 0.014, pu, 0.14)
	var kn0: Array = P._fp(hk, 0.075, H + 0.07, true, 0.03)
	P._boxr(k, kn0[0], Vector3(0.024, -0.006, 0), Vector3(0.004, 0.02, 0), (kn0[1] as Vector3) * 0.012, pu.darkened(0.06), [["Hips", 1.0]], 0.45)
	var ll: Dictionary = hls["Left"][0]
	var lhl: Callable = hls["Left"][1]
	for e3 in [[0.2, 0.3, 0.0], [0.5, 0.25, 0.01]]:
		var pts := []
		var ou := []
		var n := 12
		for i in n + 1:
			var s: float = lerpf(0.0, float(e3[1]), float(i) / n)
			var a: float = float(e3[0]) + 0.08 * float(i) / n
			var e: Array = Q._ls(ll, s, a, float(lhl.call(s, a)) + 0.005 + float(e3[2]))
			pts.append(e[0])
			ou.append(e[1])
		var top: Vector3 = (kn0[0] as Vector3) + Vector3(0.0, -0.01, 0.0)
		pts[0] = top
		k.strip(pts, ou, 0.017, 0.004, pu.darkened(0.04 * float(e3[2]) * 100.0), false, func(p): return R._lsk(ll, p) if p.y < H - 0.01 else [["Hips", 1.0]])
	# bej örtü: sol belden sağ uyluğa verev dökülür, kat kat yatay kıvrım
	var ok := []
	for e2 in hk:
		ok.append([e2[0], float(e2[1]) + 0.018, float(e2[2]) + 0.024, float(e2[3]) - 0.02])
	ok.append([H - 0.26, hp.x + 0.13, hp.y + 0.15, hp.z - 0.12])
	ok.append([H - 0.45, hp.x + 0.16, hp.y + 0.18, hp.z - 0.14])
	var otop: float = H + 0.09
	var ohem := func(a: float) -> float: return lerpf(H - 0.33, H + 0.025, smoothstep(-0.85, 1.55, a)) if a > -0.85 else lerpf(H - 0.33, H - 0.1, smoothstep(-0.85, -1.75, a))
	var of := func(a: float, y: float, _v: float) -> float:
		var u: float = clampf((otop - y) / maxf(0.03, otop - float(ohem.call(a))), 0.0, 1.0)
		return 0.06 * pow(0.5 + 0.5 * sin(u * TAU * 2.4 + 0.6), 1.6) * smoothstep(0.0, 0.2, u) + 0.05 * sin(u * PI) * smoothstep(1.4, -0.4, a)
	var osk := func(p):
		var l0: Array = Q._csk(k, p, H - 0.33, 0.06)
		if p.y >= H:
			return l0
		var o2 := []
		for e: Array in l0:
			o2.append([e[0], float(e[1]) * 0.9 + (0.1 if String(e[0]) == "Hips" else 0.0)])
		return o2
	var og: Dictionary = P._cl(k, {"keys": ok, "ny": 30, "na": 60, "rng": func(_v): return Vector2(-1.75, 1.7), "top": func(_a): return otop, "hem": func(a): return ohem.call(float(a)), "fold": of,
		"col": func(_a, _y, _v): return be, "gain": 3.0, "th": 0.006, "inner": be.darkened(0.3), "skin": osk})
	P._cord(k, og["hem"], 0.0035, be.darkened(0.1), false, osk)
	# kollar: kimono kolu + geniş dış kol (ağzında mavi-leylak astar)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		if sd == "Right":   # sağ kol: sargılı ön kol + altın halka
			P._lt(k, ar, func(s, a): return 0.01 + 0.003 * P._lf(s, a, 1.0), func(_s, _a, ins): return wh.darkened(0.4) if ins else wh, 0.0, 0.6, 16, 16)
			P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return bn.darkened(0.4) if ins else bn.darkened(0.12), 0.5, 0.99, 16, 16)
			P._wraps(k, ar, 0.55, 0.985, 13, 0.006, 0.0105, bn, 0.009)
			var gf := func(s: float, a: float) -> float: return 0.016 + 0.0028 * pow(absf(sin(a * 9.0)), 0.6) * smoothstep(0.855, 0.87, s) * smoothstep(0.945, 0.93, s)
			P._lt(k, ar, gf, func(s, a, ins): return gd.darkened(0.4) if ins else gd.darkened(0.22 * (1.0 - pow(absf(sin(float(a) * 9.0)), 0.6))).lightened(0.12 * float(cos(float(a)) > 0.3)), 0.85, 0.95, 8, 36)
			for s0 in [0.85, 0.938]:
				P._lt(k, ar, func(_s, _a): return 0.021, func(_s, _a, ins): return gd.darkened(0.4) if ins else gd.lightened(0.08), s0, s0 + 0.013, 2, 24)
		else:
			P._lt(k, ar, func(s, a): return 0.01 + 0.003 * P._lf(s, a, 1.0), func(_s, _a, ins): return wh.darkened(0.4) if ins else wh, 0.0, 0.975, 26, 16)
		var s1 := 0.86
		var rad := func(s: float) -> float: return P._lr(ar, s) + 0.03 + 0.02 * smoothstep(0.08, 0.45, s)
		var pouch := func(s: float) -> float: return 0.034 * smoothstep(0.4, 0.75, s)
		var wf := func(s: float, a: float) -> float: return 0.05 * sin(a * 4.0 + s * 9.0) + 0.025 * sin(a * 7.0 - s * 13.0)
		M._wide(k, ar, rad, pouch, wf, func(s, a, ins):
			if ins:
				return li
			return P._fs(wh, float(wf.call(float(s), float(a))) * 0.03, 5.0), s1, 0.2, P._lr(ar, s1) + 0.034, 40, 30)
	P._cur_hem = H - 0.4


# ------------------------------------------------------------------ Sankaku Tsunagi (ref Shinobi Striker "Delta Outfit"): soluk mavi mini elbise (dik yaka, göğüste anahtar deliği + bele inen yırtmaç, omuzlar açık,
## koyu yan paneller, göğüs altı dikişleri, sırtta pembe üçgen), bilekte beyaz manşetli balon kollar, siyah-pembe çizgili tayt, uyluğa çıkan beyaz çizme
static func _delta(k) -> void:
	var dr := Color(0.455, 0.596, 0.62)
	var dp := Color(0.3, 0.42, 0.47)
	var wh := Color(0.94, 0.94, 0.95)
	var pk := Color(0.847, 0.471, 0.565)
	var tb := Color(0.094, 0.094, 0.11)
	var bo := Color(0.941, 0.941, 0.949)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# anahtar deliği ve yırtmaçta görünen ten
	var mid: Vector3 = k.M(C - 0.13, k.UA)
	var tk := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.84], [C - 0.03, ch.x + 0.002, ch.y + 0.004, ch.z * 0.9], [C - 0.13, mid.x, mid.y + 0.004, mid.z * 0.88], [H + 0.12, wa.x, wa.y + 0.004, wa.z * 0.9]]
	SE.body_layer(k, tk, 24, 40, func(_i, _j, _p): return skc)
	SE.body_layer(k, [P._kp(k.M(H + 0.04, 0.3), H + 0.04, -0.004), P._kp(hp, H - 0.05, 0.002), [H - 0.15, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 8, 34, func(_i, _j, _p): return tb)
	# elbise
	var hem: float = H - 0.17
	var dk := [P._kp(nk, N + 0.006, 0.014), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.012), P._kp(mid, C - 0.13, 0.012), P._kp(wa, H + 0.12, 0.014), P._kp(hp, H - 0.04, 0.026), [hem, hp.x + 0.055, hp.y + 0.048, hp.z - 0.05]]
	var kt: float = N - 0.035
	var kb: float = N - 0.125
	var sb: float = H + 0.13
	var kw := func(y: float) -> float:
		if y > kt or y < sb:
			return 0.0
		if y >= kb:
			var v: float = (kt - y) / (kt - kb)
			return maxf(0.042, 0.4 * (1.0 - pow(v, 1.5)) * (0.86 + 0.14 * sin(v * PI)))
		return 0.042
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 8.0 + 0.3) + 0.006 * sin(a * 15.0)) + 0.004 * sin(a * 5.0 + y * 17.0) * smoothstep(C, H + 0.1, y)
	var dsk := func(p): return _msk(k, p, hem)
	var pan := func(a: float) -> bool: return absf(a) > 1.05 and absf(a) < 2.05
	var dg: Dictionary = S._clh(k, {"keys": dk, "ny": 54, "na": 84, "rng": func(_v): return Vector2(-PI + 0.002, PI - 0.002), "top": func(_a): return N + 0.006, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(a, _y, _v): return dp if pan.call(float(a)) else dr, "gain": 5.0, "th": 0.005, "inner": dr.darkened(0.4), "skin": dsk},
		func(a, y): return absf(float(a)) < float(kw.call(float(y))))
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# deliğin kenar biyesi
	var rim := []
	var yl := []
	var y0: float = kt - 0.001
	while y0 > kb:
		yl.append(y0)
		y0 -= 0.006
	y0 = kb
	while y0 > sb:
		yl.append(y0)
		y0 -= 0.02
	yl.append(sb + 0.001)
	for y in yl:
		rim.append(Q._spt(dk, ffw, float(kw.call(float(y) - 0.0001)) + 0.004, float(y), 0.0015)[0])
	for i in range(yl.size() - 1, -1, -1):
		var y: float = yl[i]
		rim.append(Q._spt(dk, ffw, -float(kw.call(float(y) - 0.0001)) - 0.004, float(y), 0.0015)[0])
	var tsk := func(p): return k.torso_skin(p.y)
	P._cord(k, rim, 0.0028, dr.lightened(0.06), true, tsk)
	# panel dikişleri + göğüs altı dikişleri
	for sg in [1.0, -1.0]:
		for a0 in [1.05, 2.05]:
			Q._run(k, dk, ffw, [Vector2(sg * a0, C + 0.0), Vector2(sg * a0, H), Vector2(sg * a0, hem + 0.01)], 0.003, 0.002, 0.0018, dp.darkened(0.25), dsk, 10)
		Q._run(k, dk, ffw, [Vector2(sg * 0.1, C - 0.105), Vector2(sg * 0.45, C - 0.09), Vector2(sg * 0.85, C - 0.045)], 0.0028, 0.002, 0.0018, dr.darkened(0.25), tsk, 6)
	var hm := []
	for p in dg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hm, 0.003, 0.0016, dr.darkened(0.2), true, dsk)
	# dik yaka: önü dar açık
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var ck := [P._kp(nk, N + 0.07 * q, 0.009, 0.012), P._kp(nk, N + 0.025 * q, 0.013), P._kp(nk, N - 0.02, 0.02)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 44, "rng": func(_v): return Vector2(0.08, TAU - 0.08), "top": func(_a): return N + 0.062 * q, "hem": func(_a): return N - 0.012,
		"fold": func(_a, _y, _v): return 0.0, "col": func(_a, _y, _v): return dr, "gain": 4.0, "th": 0.005, "inner": dr.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.0032, dr.lightened(0.05), false, nsk)
	for e in [cg["ea"], cg["eb"]]:
		P._cord(k, e, 0.0028, dr.lightened(0.05), false, nsk)
	# sırtta pembe üçgen (ucu aşağı)
	var tp: Callable = Q._local(dk, ffw, PI, C - 0.035)
	var to: Vector3 = Q._spt(dk, ffw, PI, C - 0.035)[1]
	Q._disc(k, tp, to, 0.062, 0.003, func(th): return R._tri_r(float(th) + PI * 0.5), func(_u, _v): return pk.darkened(0.3), tsk, 2, 36)
	Q._disc(k, tp, to, 0.052, 0.0055, func(th): return R._tri_r(float(th) + PI * 0.5), func(u, v): return pk.lightened(0.1) if Vector2(float(u), float(v)).length() < 0.35 else pk, tsk, 4, 36)
	# kollar: açık omuz, balon kol, beyaz manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.7 if sd == "Left" else 1.9
		P._bare(k, ar, skc, 0.07, 0.25)
		var bal := func(s: float, a: float) -> float:
			var t: float = clampf((s - 0.21) / 0.6, 0.0, 1.0)
			var pf: float = pow(sin(t * PI), 0.75) * (0.62 + 0.38 * t)
			return 0.006 + 0.056 * pf + 0.005 * sin(a * 12.0 + sv) * (1.0 - pow(sin(t * PI), 0.5)) + 0.007 * P._lf(s, a, sv) * pf
		P._lt(k, ar, bal, func(s, a, ins): return dr.darkened(0.4) if ins else P._fs(dr, float(bal.call(float(s), float(a))) * 0.15 - 0.004 + 0.006 * P._lf(float(s), float(a), sv), 10.0), 0.21, 0.82, 32, 28, 0.03)
		P._lt(k, ar, func(s, a): return float(bal.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return dr.darkened(0.4) if ins else dr.darkened(0.1), 0.21, 0.232, 2, 28)
		var cf := func(s: float, _a: float) -> float: return 0.011 + 0.002 * smoothstep(0.81, 0.84, s)
		P._lt(k, ar, cf, func(s, _a, ins): return wh.darkened(0.35) if ins else wh.darkened(0.06 * float(float(s) > 0.955 or float(s) < 0.835)), 0.81, 0.975, 10, 22, 0.02)
	# tayt (siyah-pembe dikey çizgi, pembe çizgi kabartma) + uyluğa çıkan beyaz çizme
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.5 if sd == "Left" else 1.6
		var stp := func(_s: float, a: float) -> float: return 0.004 + 0.0012 * smoothstep(-0.2, 0.2, sin(a * 8.0))
		P._lt(k, le, stp, func(_s, a, ins): return tb.darkened(0.3) if ins else (pk if sin(float(a) * 8.0) > 0.0 else tb), 0.0, 0.4, 14, 48)
		var bs0 := 0.27
		var bt := func(s: float, a: float) -> float:
			return 0.009 + 0.007 * smoothstep(bs0 + 0.05, bs0, s) - 0.004 * smoothstep(0.86, 0.98, s) + 0.004 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.003 * P._lf(s, a, sv) * smoothstep(0.6, 0.9, s)
		P._lt(k, le, bt, func(s, a, ins): return bo.darkened(0.3) if ins else P._fs(bo, float(bt.call(float(s), float(a))) - 0.009, 10.0).darkened(0.1 * maxf(0.0, -sin(float(a)) * float(le["sg"]))), bs0, 1.0, 36, 22, 0.025)
		P._lt(k, le, func(s, a): return float(bt.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return bo.darkened(0.3) if ins else bo.darkened(0.07), bs0, bs0 + 0.022, 3, 22)
		S._lstrip(k, le, bs0 + 0.025, 0.975, func(_s): return 0.0, func(s, a): return float(bt.call(float(s), float(a))), 0.0022, 0.0013, bo.darkened(0.16), 22)
	P._cur_hem = hem


# ------------------------------------------------------------------ Denki Shōzoku (ref Shinobi Striker "Denki Outfit, Genin Ver."): mavi gömlek (sivri yaka, düğmeli pat, kapaklı iki göğüs cebi, katlı kısa kol, sırtta Kaminarimon arması),
## açık mavi fular (boyunda rulo, önde düğüm + sarkan üçgen), siyah kemer + gümüş toka, katlı paçalı diz şortu (sol yanda körüklü cep, sağ uylukta sargı + kılıf), siyah eldiven, siyah konç
static func _denki(k) -> void:
	var bl := Color(0.165, 0.353, 0.722)
	var sc := Color(0.56, 0.83, 0.93)
	var bk := Color(0.07, 0.07, 0.09)
	var bt := Color(0.15, 0.11, 0.09)
	var sv_c := Color(0.72, 0.73, 0.75)
	var wr := Color(0.92, 0.92, 0.9)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	# gömlek gövdesi: belde şorta girer, kemer üstünde hafif kabarır
	var gk := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(wa, H + 0.03, 0.03)]
	var gf := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 6.0 + y * 16.0) * smoothstep(N - 0.02, C - 0.05, y) + 0.03 * smoothstep(H + 0.13, H + 0.06, y) * (0.5 + 0.5 * sin(a * 9.0 + 0.4)) * smoothstep(H + 0.03, H + 0.06, y)
	var gfw := func(a, y): return gf.call(float(a), float(y))
	var tsk := func(p): return k.torso_skin(p.y)
	P._cl(k, {"keys": gk, "ny": 32, "na": 72, "top": func(_a): return N + 0.012, "hem": func(_a): return H + 0.03, "fold": func(a, y, _v): return gf.call(float(a), float(y)), "col": func(_a, _y, _v): return bl, "gain": 5.0, "th": 0.005, "inner": bl.darkened(0.4), "skin": tsk})
	# pat + düğmeler
	Q._run(k, gk, gfw, [Vector2(0.0, N + 0.0), Vector2(0.0, H + 0.06)], 0.011, 0.0035, 0.0028, bl.lightened(0.04), tsk, 12)
	Q._run(k, gk, gfw, [Vector2(0.075, N - 0.01), Vector2(0.075, H + 0.06)], 0.0018, 0.0062, 0.0012, bl.darkened(0.3), tsk, 12)
	var yb: float = N - 0.06
	while yb > H + 0.1:
		var e: Array = Q._spt(gk, gfw, 0.0, yb, 0.0062)
		P._stud(k, e[0], e[1], 0.0052, bl.darkened(0.25), k.torso_skin(yb))
		yb -= 0.07
	# göğüs cepleri: yama + kapak + düğme
	for sg in [1.0, -1.0]:
		var x0: float = sg * 0.038
		var x1: float = sg * minf(0.135, ch.x * 0.82)
		P._patch(k, gk, minf(x0, x1), maxf(x0, x1), C + 0.0, C - 0.085, true, 0.006, bl.darkened(0.03), 0.1, 10, 8, tsk)
		P._patch(k, gk, minf(x0, x1) - 0.004, maxf(x0, x1) + 0.004, C + 0.016, C - 0.022, true, 0.0115, bl.lightened(0.05), 0.0, 10, 4, tsk)
		var eb: Array = P._fp(gk, (x0 + x1) * 0.5, C - 0.016, true, 0.014)
		P._stud(k, eb[0], eb[1], 0.0048, bl.darkened(0.25), k.torso_skin(C))
	# sırtta Kaminarimon arması
	_kaminari(k, gk, gfw, PI, C - 0.02, 0.048, tsk)
	# sivri gömlek yakası: dik bant + devrik yaka
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var sk1 := [P._kp(nk, N + 0.045 * q, 0.012), P._kp(nk, N - 0.005, 0.02)]
	P._cl(k, {"keys": sk1, "ny": 5, "na": 40, "rng": func(_v): return Vector2(0.12, TAU - 0.12), "top": func(_a): return N + 0.042 * q, "hem": func(_a): return N - 0.004, "col": func(_a, _y, _v): return bl, "th": 0.004, "inner": bl.darkened(0.35), "skin": nsk})
	var fk := [P._kp(nk, N + 0.045 * q, 0.022, 0.024), P._kp(nk, N - 0.01, 0.03), [N - 0.07, ch.x * 0.86 + 0.02, ch.y * 0.85 + 0.03, ch.z * 0.93 - 0.02]]
	var fg: Dictionary = P._cl(k, {"keys": fk, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.07, TAU - 0.07), "top": func(_a): return N + 0.043 * q,
		"hem": func(a): return N - 0.03 - 0.045 * exp(-pow((absf(float(a)) - 0.32) / 0.2, 2.0)) * smoothstep(0.05, 0.2, absf(float(a))), "fold": func(_a, _y, v): return 0.04 * sin(float(v) * PI * 0.5),
		"col": func(_a, _y, _v): return bl.lightened(0.03), "gain": 3.0, "th": 0.004, "inner": bl.darkened(0.3), "skin": nsk})
	P._cord(k, fg["hem"], 0.0025, bl.darkened(0.15), false, nsk)
	# fular: boyun rulosu + önde düğüm + sarkan üçgen + iki uç
	var rr := []
	for i in 40:
		var a := TAU * i / 40.0 - PI
		rr.append(P._on(fk, a, N - 0.012, 0.0) + Vector3(sin(a) * 0.011, 0.0, cos(a) * 0.012))
	Q._rope(k, rr + [rr[0]], 0.012, sc, nsk, 3.0, 10)
	var kp: Array = Q._spt(gk, gfw, 0.0, N - 0.045, 0.03)
	var ko: Vector3 = kp[1]
	P._boxr(k, kp[0], Vector3(0.022, 0, 0), Vector3(0, 0.018, 0), ko * 0.014, sc.darkened(0.05), [["UpperChest", 0.7], ["Neck", 0.3]], 0.5)
	var tri := []
	for j in 9:
		var v := float(j) / 8.0
		var w: float = 0.075 * (1.0 - v) + 0.002
		var y: float = lerpf(N - 0.05, C - 0.04, v)
		var ro := []
		for i in 7:
			var u: float = lerpf(-1.0, 1.0, float(i) / 6.0)
			var x: float = u * w
			var lift: float = 0.017 + 0.005 * (1.0 - u * u) - 0.006 * v
			ro.append(P._fp(gk, x, y, true, lift)[0])
		tri.append(ro)
	Q._mesh(k, tri, false, func(i, _j, _p): return sc.darkened(0.12) if i == 0 or i == 6 else sc, func(_i, _j, p): return k.torso_skin(p.y), Vector3(0, 0, 1))
	for sg in [1.0, -1.0]:
		var tp := []
		var tou := []
		for i in 7:
			var v := float(i) / 6.0
			var e: Array = P._fp(gk, sg * (0.012 + 0.07 * v), N - 0.048 - 0.04 * v * v, true, 0.028 - 0.008 * v)
			tp.append(e[0])
			tou.append(e[1])
		k.strip(tp, tou, 0.013, 0.003, sc.darkened(0.04), false, tsk)
	# kollar: katlı kısa kol, açık kol, eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.3 if sd == "Left" else 2.4
		var sh := func(s: float, a: float) -> float: return 0.015 + 0.008 * smoothstep(0.05, 0.3, s) + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sh, func(s, a, ins): return bl.darkened(0.42) if ins else P._fs(bl, float(sh.call(float(s), float(a))) - 0.02, 14.0), 0.0, 0.34, 14, 20, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.0035, func(_s, _a, ins): return bl.darkened(0.42) if ins else bl.lightened(0.05), 0.3, 0.342, 3, 20)
		P._bare(k, ar, skc, 0.26, 0.86)
		P._lt(k, ar, func(s, a): return 0.006 + 0.003 * smoothstep(0.82, 0.76, s) + 0.0015 * sin(float(a) * 4.0 + float(s) * 30.0), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05), 0.76, 0.9, 6, 18, 0.015)
		S._mitt(k, sd, ar, bk)
	# kemer
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return bl.darkened(0.04))
	var by: float = H + 0.06
	P._sash(k, sk, by, 0.015, 0.008, bt, 0.1)
	var fc: Array = P._fp(sk, 0.0, by, true, 0.021)
	P._boxr(k, fc[0], Vector3(0.03, 0, 0), Vector3(0, 0.017, 0), (fc[1] as Vector3) * 0.006, sv_c, [["Hips", 1.0]], 0.2)
	P._boxr(k, (fc[0] as Vector3) + (fc[1] as Vector3) * 0.005, Vector3(0.02, 0, 0), Vector3(0, 0.009, 0), (fc[1] as Vector3) * 0.0035, sv_c.darkened(0.25), [["Hips", 1.0]], 0.2)
	for a0 in [0.75, -0.75, 1.9, -1.9, PI]:
		var lp := [Q._spt(sk, Callable(), a0, by + 0.022, 0.016), Q._spt(sk, Callable(), a0, by - 0.022, 0.016)]
		k.strip([lp[0][0], lp[1][0]], [lp[0][1], lp[1][1]], 0.0055, 0.003, bl.darkened(0.06), false, func(_p): return [["Hips", 1.0]])
	# şort: katlı paça, sol yanda cep, sağ uylukta sargı + kılıf, alt bacak ten + siyah konç
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.035
		var sv: float = 0.9 if sd == "Left" else 2.0
		P._bare(k, le, skc, s1 - 0.08, kn + 0.2)
		var ad: Callable = R._short_leg(k, le, bl, s1, 0.022, 0.022, sv)
		R._hem_roll(k, le, ad, s1, bl.lightened(0.03), 0.06, 0.006)
		P._lt(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.0075, func(_s, _a, ins): return bl.darkened(0.3) if ins else bl.darkened(0.12), s1 - 0.062, s1 - 0.052, 1, 26)
		if sd == "Left":
			M._lpatch(k, le, 0.2, 0.4, 1.15, 1.95, ad, bl.darkened(0.03), bl.darkened(0.3))
			M._lpatch(k, le, 0.185, 0.235, 1.1, 2.0, func(s, a): return float(ad.call(float(s), float(a))) + 0.0045, bl.lightened(0.04), bl.darkened(0.3))
		else:
			for i in 5:
				Q._ring_on(k, le, 0.22 + 0.034 * i, ad, 0.0155, wr.darkened(0.05 * float(i % 2)), 0.006)
			var hc: Array = Q._ls(le, 0.26, -PI * 0.5, float(ad.call(0.26, -PI * 0.5)) + 0.025)
			var d: Vector3 = P._ld(le, 0.26)
			var ho: Vector3 = hc[1]
			var hb := [["RightUpperLeg", 1.0]]
			P._boxr(k, hc[0], d.cross(ho).normalized() * 0.026, -d * 0.068, ho * 0.017, bk, hb, 0.3)
			P._boxr(k, (hc[0] as Vector3) - d * 0.058 + ho * 0.004, d.cross(ho).normalized() * 0.029, -d * 0.016, ho * 0.02, bk.lightened(0.06), hb, 0.3)
		# konç: diz altından bileğe, üstü kıvrık, buruşuk
		var b0: float = kn + 0.14
		var bf := func(s: float, a: float) -> float: return 0.013 + 0.006 * smoothstep(b0 + 0.05, b0, s) + 0.004 * sin(a * 3.0 + s * 46.0 + sv) * smoothstep(0.75, 0.9, s) + 0.002 * P._lf(s, a, sv)
		P._lt(k, le, bf, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.05), 0.004 * sin(float(a) * 3.0 + float(s) * 46.0 + sv) * smoothstep(0.75, 0.9, float(s)), 12.0), b0, 1.0, 22, 20, 0.02)
		P._lt(k, le, func(s, a): return float(bf.call(float(s), float(a))) + 0.004, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.1), b0, b0 + 0.035, 3, 20)
	P._cur_hem = H - 0.1


# ------------------------------------------------------------------ Hoshi Sukāto (ref Shinobi Striker "Eida Outfit"): uzun geniş boğazlı kabarık beyaz bluz (göğüste büzgü sıraları, dev balon kollar, mavi-yeşil manşet + bilezikler),
## yeşil yıldız / gezegen / hilal aplikeli siyah yüksek bel şort, çıplak bacak, bilekte siyah bot ağzı
static func _gezegen(k) -> void:
	var wh := Color(0.965, 0.965, 0.973)
	var sh := Color(0.157, 0.157, 0.173)
	var gn := Color(0.416, 0.753, 0.627)
	var tl := Color(0.22, 0.55, 0.62)
	var bkc := Color(0.08, 0.08, 0.1)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# bluz: kabarık, belde şorta girer
	var mid: Vector3 = k.M(C - 0.14, k.UA)
	var yk: float = C - 0.035
	var bk := [P._kp(nk, N + 0.0, 0.024), [N - 0.055, ch.x * 1.03, ch.y * 0.98, ch.z * 1.06], P._kp(ch, C - 0.03, 0.036), P._kp(mid, C - 0.14, 0.05), P._kp(wa, H + 0.13, 0.045), P._kp(wa, H + 0.08, 0.028)]
	var bf := func(a: float, y: float) -> float:
		var yo: float = smoothstep(yk - 0.01, yk + 0.02, y)
		var lo: float = 1.0 - yo
		return yo * 0.008 * sin(a * 26.0) + lo * (0.022 * sin(a * 9.0 + 0.5) + 0.01 * sin(a * 17.0 + 1.3)) * smoothstep(yk, yk - 0.08, y) + 0.02 * smoothstep(H + 0.14, H + 0.09, y) * (0.5 + 0.5 * sin(a * 11.0))
	var bfw := func(a, y): return bf.call(float(a), float(y))
	var tsk := func(p): return k.torso_skin(p.y)
	P._cl(k, {"keys": bk, "ny": 40, "na": 84, "top": func(_a): return N + 0.0, "hem": func(_a): return H + 0.08, "fold": func(a, y, _v): return bf.call(float(a), float(y)), "col": func(_a, _y, _v): return wh, "gain": 4.0, "th": 0.005, "inner": wh.darkened(0.35), "skin": tsk})
	# göğüste büzgü sıraları (dikiş kabartması)
	for i in 5:
		var y: float = lerpf(N - 0.035, yk, float(i) / 4.0)
		var pts := []
		for j in 72:
			var a := TAU * j / 72.0 - PI
			pts.append(Q._spt(bk, bfw, a, y + 0.002 * sin(a * 26.0), 0.0018)[0])
		P._bd(k, pts, 0.0018, 0.0014, wh.darkened(0.14), true, tsk)
	# geniş, uzun boğaz
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var ck := [[N + 0.056 * q, nk.x + 0.058, nk.y + 0.052, nk.z - 0.06], [N + 0.03 * q, nk.x + 0.044, nk.y + 0.04, nk.z - 0.045], [N + 0.0, nk.x + 0.044, nk.y + 0.044, nk.z - 0.045], [N - 0.045, nk.x + 0.072, nk.y + 0.064, nk.z - 0.062]]
	var cgf := func(a: float, y: float, _v: float) -> float: return (0.05 * sin(a * 7.0 + 0.4) + 0.02 * sin(a * 13.0 + 1.0)) * smoothstep(N + 0.005, N + 0.056 * q, y)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 14, "na": 56, "top": func(_a): return N + 0.056 * q, "hem": func(_a): return N - 0.045, "fold": cgf, "col": func(_a, _y, _v): return wh, "gain": 4.0, "th": 0.006, "inner": wh.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.0065, wh.darkened(0.03), true, nsk)
	# dev balon kollar, manşet, bilezikler
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.4 if sd == "Left" else 1.7
		var bal := func(s: float, a: float) -> float:
			var t: float = clampf(s / 0.86, 0.0, 1.0)
			var pf: float = pow(sin(clampf(t * 1.1, 0.0, 1.0) * PI * 0.5), 1.2) * (1.0 - smoothstep(0.8, 1.0, t))
			return 0.016 + 0.068 * pf + 0.008 * P._lf(s, a, sv) * pf + 0.006 * sin(a * 11.0 + sv) * smoothstep(0.75, 0.86, s)
		P._lt(k, ar, bal, func(s, a, ins): return wh.darkened(0.35) if ins else P._fs(wh, 0.008 * P._lf(float(s), float(a), sv) - 0.003 * float(sin(float(a) * 11.0 + sv) < 0.0) * smoothstep(0.75, 0.86, float(s)), 9.0), 0.0, 0.865, 34, 28, 0.03)
		P._lt(k, ar, func(s, _a): return 0.011 + 0.002 * smoothstep(0.85, 0.87, s), func(s, _a, ins): return tl.darkened(0.35) if ins else tl.darkened(0.12 * float(float(s) < 0.86 or float(s) > 0.905)), 0.845, 0.915, 6, 22, 0.015)
		for s0 in [0.93, 0.952, 0.974]:
			var rp := []
			for i in 20:
				var a := TAU * i / 20.0 - PI
				rp.append(Q._ls(ar, s0, a, 0.0115)[0])
			P._tb(k, rp, func(_s, _a): return 0.0034, func(_s, a, _p): return tl.lightened(0.15) if cos(float(a)) > 0.3 else tl, func(_s, _p): return P._lskin(ar, s0), 6, true)
	# şort: yüksek bel, A kesim kısa paça
	var sk := [P._kp(wa, H + 0.13, 0.016), P._kp(k.M(H + 0.05, 0.3), H + 0.05, 0.02), P._kp(hp, H - 0.05, 0.028), [H - 0.15, hp.x * 0.84, hp.y * 0.84, hp.z * 0.84]]
	SE.body_layer(k, sk, 22, 56, func(_i, _j, _p): return sh, func(a, y): return 0.006 * sin(a * 7.0 + 0.3) * smoothstep(H + 0.06, H - 0.04, y))
	var hsk := func(_p): return [["Hips", 1.0]]
	var top_pts := []
	for i in 72:
		var a := TAU * i / 72.0 - PI
		top_pts.append(Q._spt(sk, Callable(), a, H + 0.128, 0.0015)[0])
	P._cord(k, top_pts, 0.0042, sh.lightened(0.05), true, tsk)
	Q._run(k, sk, Callable(), [Vector2(0.0, H + 0.12), Vector2(0.0, H - 0.06)], 0.003, 0.002, 0.002, sh.darkened(0.4), hsk, 8)
	Q._run(k, sk, Callable(), [Vector2(0.09, H + 0.11), Vector2(0.09, H - 0.03), Vector2(0.0, H - 0.07)], 0.0018, 0.0015, 0.0012, sh.lightened(0.08), hsk, 8)
	for y in [H + 0.105, H + 0.075]:
		var e: Array = Q._spt(sk, Callable(), 0.05, y, 0.003)
		P._stud(k, e[0], e[1], 0.0055, sh.lightened(0.18), [["Hips", 1.0]])
	var lsv := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.6 if sd == "Left" else 1.8
		P._bare(k, le, skc, 0.0, 1.0)
		var ad: Callable = R._short_leg(k, le, sh, 0.2, 0.028, 0.05, sv)
		R._hem_roll(k, le, ad, 0.2, sh.lightened(0.04), 0.022, 0.0025)
		P._lt(k, le, func(s, _a): return 0.006 + 0.004 * smoothstep(0.96, 0.93, s), func(s, _a, ins): return bkc.darkened(0.3) if ins else bkc.lightened(0.05 * float(float(s) < 0.95)), 0.93, 1.0, 5, 18)
		lsv[sd] = [le, ad]
	# yeşil aplikeler: yıldız, gezegen, hilal, sekiz uçlu yıldız
	var star5 := func(th): return _star(float(th), 5.0, 0.42)
	var star8 := func(th): return _star(float(th), 8.0, 0.48)
	var gcol := func(u, v): return gn.lightened(0.08) if Vector2(float(u), float(v)).length() < 0.4 else gn
	for e4 in [[-0.55, H + 0.085, 0.026, 0.2], [0.55, H + 0.07, 0.024, -0.3], [2.4, H + 0.06, 0.024, 0.0], [-2.6, H + 0.02, 0.022, 0.4]]:
		var mp: Callable = R._rot(Q._local(sk, Callable(), float(e4[0]), float(e4[1])), float(e4[3]))
		Q._disc(k, mp, R._out_of(mp), float(e4[2]), 0.0035, star5, gcol, hsk, 3, 60)
	var pm: Callable = Q._local(sk, Callable(), 0.12, H + 0.0)
	_planet(k, pm, 0.019, 0.3, 0.004, gn, hsk)
	_crescent(k, Q._local(sk, Callable(), -0.95, H - 0.02), 0.024, 0.5, 0.0035, gn, hsk)
	_crescent(k, Q._local(sk, Callable(), PI, H + 0.08), 0.022, -0.6, 0.0035, gn, hsk)
	for e5 in [["Right", 0.1, -0.15, 0], ["Left", 0.11, 0.35, 1], ["Left", 0.08, 2.6, 2], ["Right", 0.12, -2.4, 3]]:
		var le: Dictionary = lsv[e5[0]][0]
		var ad: Callable = lsv[e5[0]][1]
		var mp: Callable = R._lmap(le, ad, float(e5[1]), float(e5[2]))
		var lsk := func(_p): return P._lskin(le, float(e5[1]))
		match int(e5[3]):
			0:
				Q._disc(k, mp, R._out_of(mp), 0.026, 0.004, star8, gcol, lsk, 3, 48)
			1:
				_crescent(k, mp, 0.022, -0.4, 0.004, gn, lsk)
			2:
				_planet(k, mp, 0.017, -0.35, 0.004, gn, lsk)
			3:
				Q._disc(k, mp, R._out_of(mp), 0.022, 0.004, star5, gcol, lsk, 3, 60)
	P._cur_hem = H - 0.1


# ------------------------------------------------------------------ Gama Kigurumi (ref Shinobi Striker "Frog Costume"): boğazdan bileğe tek parça kabarık yeşil tulum (dik rulo boğaz, yuvarlak karın, bol kol ve paça,
## yan / iç dikişler, ağ arası sarkık), yeşil eldiven
static func _kurbaga(k) -> void:
	var g := Color(0.322, 0.675, 0.29)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var mid: Vector3 = k.M(C - 0.14, k.UA)
	var tk := [P._kp(nk, N + 0.0, 0.022), [N - 0.055, ch.x * 0.94, ch.y * 0.97 + 0.02, ch.z * 1.05 - 0.02], P._kp(ch, C - 0.03, 0.04), P._kp(mid, C - 0.14, 0.055), P._kp(wa, H + 0.12, 0.056),
		P._kp(hp, H - 0.04, 0.05), [H - 0.13, hp.x * 0.92, hp.y * 0.94, hp.z * 0.94], [H - 0.18, hp.x * 0.55, hp.y * 0.55, hp.z * 0.55]]
	var tf := func(a: float, y: float) -> float:
		return 0.012 * sin(a * 5.0 + y * 13.0) * smoothstep(N, C, y) + 0.016 * sin(a * 7.0 + 0.6 + y * 9.0) * smoothstep(H + 0.15, H - 0.05, y) * smoothstep(H - 0.18, H - 0.06, y)
	var tfw := func(a, y): return tf.call(float(a), float(y))
	var tsk := func(p): return k.torso_skin(p.y) if p.y > k.H - 0.05 else k.cloth_skin(p, k.H - 0.2, 0.5)
	SE.body_layer(k, tk, 44, 60, func(i, _j, p): return P._fs(g, float(tf.call(TAU * float(i) / 60.0 - PI, float(p.y))), 6.0), tf)
	# dik rulo boğaz
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var ck := [[N + 0.05 * q, nk.x + 0.024, nk.y + 0.022, nk.z - 0.026], [N + 0.02 * q, nk.x + 0.026, nk.y + 0.026, nk.z - 0.028], [N - 0.02, nk.x + 0.04, nk.y + 0.04, nk.z - 0.04]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 48, "top": func(_a): return N + 0.048 * q, "hem": func(_a): return N - 0.02, "fold": func(a, y, _v): return 0.012 * sin(float(a) * 6.0 + float(y) * 30.0), "col": func(_a, _y, _v): return g, "gain": 6.0, "th": 0.005, "inner": g.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.0075, g.lightened(0.03), true, nsk)
	# yan dikişler, ön ve arka orta dikiş (ağ arasına iner)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tfw, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, H - 0.05)], 0.0028, 0.0018, 0.0018, g.darkened(0.22), tsk, 12)
	for a0 in [0.0, PI]:
		Q._run(k, tk, tfw, [Vector2(a0, H + 0.04), Vector2(a0, H - 0.15)], 0.0028, 0.0018, 0.0018, g.darkened(0.22), tsk, 8)
	# karın: açık sarı-yeşil kurbağa karnı; gövdenin üstüne dikili ayrı kat, kenarı biyeli (göğüs altından kasığa, ortası geniş oval)
	var bel := Color(0.88, 0.92, 0.6)
	var by0: float = C - 0.01
	var by1: float = H - 0.12
	var brng := func(v) -> Vector2:
		var e: float = 0.1 + 0.56 * pow(sin(clampf(float(v) * 0.9 + 0.05, 0.0, 1.0) * PI), 0.75)
		return Vector2(-e, e)
	var bg: Dictionary = P._cl(k, {"keys": tk, "ny": 22, "na": 30, "rng": brng, "top": func(_a): return by0, "hem": func(_a): return by1, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(a, y, _v): return P._fs(bel, float(tf.call(float(a), float(y))), 5.0), "gain": 0.0, "th": 0.003, "lift": 0.0035, "inner": bel.darkened(0.3), "skin": tsk})
	for e in [bg["ea"], bg["eb"], bg["top"], bg["hem"]]:
		P._cord(k, e, 0.0028, g.darkened(0.12), false, tsk)
	# raglan dikişleri: boyundan koltuk altına, önde ve arkada
	for sg in [1.0, -1.0]:
		for e2 in [[0.5, 1.0, 1.32], [PI - 0.5, PI - 1.0, PI - 1.32]]:
			Q._run(k, tk, tfw, [Vector2(sg * float(e2[0]), N - 0.008), Vector2(sg * float(e2[1]), N - 0.06), Vector2(sg * float(e2[2]), C - 0.07)], 0.0024, 0.0018, 0.0016, g.darkened(0.22), tsk, 8)
	# kollar ve paçalar: bol, eklemde kırışık; elde eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.9 if sd == "Left" else 2.1
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var af := func(s: float, a: float) -> float:
			return (0.024 - 0.012 * smoothstep(0.7, 0.92, s) + 0.005 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.006 * exp(-pow((s - 0.16) / 0.08, 2.0))) * lerpf(0.25, 1.0, smoothstep(0.0, 0.14, s)) + 0.009 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, af, func(s, a, ins): return g.darkened(0.4) if ins else P._fs(g, float(af.call(float(s), float(a))) - 0.02, 10.0), 0.0, 0.93, 32, 20, 0.02)
		S._mitt(k, sd, ar, g.darkened(0.04))
		Q._ring_on(k, ar, 0.9, func(s, a): return float(af.call(float(s), float(a))) + 0.002, 0.009, g.darkened(0.1), 0.004)   # büzgülü bilek lastiği
		var lf := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * float(le["sg"]), 0.0, 1.0)
			return (0.034 - 0.02 * smoothstep(0.1, 0.95, s)) * (1.0 - 0.35 * inn * (1.0 - smoothstep(0.0, 0.4, s))) + 0.006 * P._lf(s, a, sv) * (1.0 - smoothstep(0.85, 1.0, s)) + 0.009 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.006 * exp(-pow((s - 0.93) / 0.05, 2.0)) * (0.5 + 0.5 * sin(a * 5.0 + sv))
		P._lt(k, le, lf, func(s, a, ins): return g.darkened(0.4) if ins else P._fs(g, float(lf.call(float(s), float(a))) - 0.02, 10.0), 0.0, 1.0, 38, 22)
		S._lstrip(k, le, 0.02, 0.97, func(_s): return -PI * 0.5 * float(le["sg"]), func(s, a): return float(lf.call(float(s), float(a))), 0.0026, 0.0016, g.darkened(0.2), 24)
		S._lstrip(k, le, 0.02, 0.97, func(_s): return PI * 0.5 * float(le["sg"]), func(s, a): return float(lf.call(float(s), float(a))), 0.0026, 0.0016, g.darkened(0.2), 24)
		Q._ring_on(k, le, 0.955, func(s, a): return float(lf.call(float(s), float(a))) + 0.002, 0.011, g.darkened(0.1), 0.005)   # büzgülü bilek lastiği
	P._cur_hem = H - 0.2
