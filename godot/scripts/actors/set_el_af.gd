extends RefCounted
## Elle modellenmiş setler, parti af: ss_onluk, ss_yaprak_striker, ss_yaprak_striker_matador, ss_yaprak_striker_kovboy, ss_genc_canavar, ss_simsek_kiyafet. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), q (Q), r (R), s (S), t (T) dosyalarından; burada Konoha Striker ortak kesimi (üç türev) ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")

const DONE := ["ss_yaprak_striker", "ss_yaprak_striker_matador", "ss_yaprak_striker_kovboy", "ss_genc_canavar", "ss_onluk", "ss_simsek_kiyafet"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_yaprak_striker": _striker(k, 0)
		"ss_yaprak_striker_matador": _striker(k, 1)
		"ss_yaprak_striker_kovboy": _striker(k, 2)
		"ss_genc_canavar": _genc(k)
		"ss_onluk": _onluk(k)
		"ss_simsek_kiyafet": _simsek(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Uzuv yüzeyi yerel eşlemesi: (u çevre metre, v boy metre, kalkış) -> konum
static func _lmap(l: Dictionary, s0: float, a0: float, addf: Callable) -> Callable:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	return func(u: float, v: float, lift: float) -> Vector3:
		var s: float = s0 - v / L
		var R0: float = P._lr(l, s) + float(addf.call(s, a0))
		return Q._ls(l, s, a0 + u / maxf(0.02, R0), float(addf.call(s, a0)) + lift)[0]


## Yaprak dalı: kıvrık sap + karşılıklı yapraklar + uç yaprak (kabartma). mp yerel eşleme, rot sapın yönü
static func _sprig(k, mp: Callable, o: Vector3, sc: float, rot: float, col: Color, skinf: Callable) -> void:
	var dr := Vector2(cos(rot), sin(rot))
	var nr := Vector2(-dr.y, dr.x)
	var L := 0.055 * sc
	var stem := []
	for i in 7:
		var t := float(i) / 6.0
		stem.append(dr * (t - 0.5) * L + nr * 0.004 * sc * sin(t * PI))
	R._lstrip(k, mp, stem, 0.0016 * sc, 0.0035, 0.0012, col.darkened(0.12), skinf)
	for i in 3:
		var t: float = 0.42 - 0.3 * float(i)
		var c0: Vector2 = dr * t * L
		for sg in [1.0, -1.0]:
			var ang: float = rot + sg * 0.95
			var ln: float = 0.0115 * sc * (1.0 - 0.12 * float(i))
			var cc: Vector2 = c0 + Vector2(cos(ang), sin(ang)) * ln * 0.9
			_leaf(k, mp, o, cc, ang, ln, ln * 0.42, col, skinf)
	_leaf(k, mp, o, dr * (0.5 * L + 0.0095 * sc), rot, 0.0105 * sc, 0.0044 * sc, col, skinf)


## Yaprak: sivri uçlu elips disk, orta damarı açık
static func _leaf(k, mp: Callable, o: Vector3, c: Vector2, ang: float, ln: float, wd: float, col: Color, skinf: Callable) -> void:
	var m2 := func(u: float, v: float, lift: float) -> Vector3: return mp.call(c.x + u, c.y + v, lift)
	var rf := func(th: float) -> float:
		var x: float = cos(th - ang)
		var y: float = sin(th - ang)
		return 1.0 / sqrt(x * x + pow(y * ln / wd, 2.0)) * (1.0 - 0.25 * maxf(0.0, -x))
	var cf := func(u: float, v: float) -> Color: return col.lightened(0.07) if absf(u * sin(ang) - v * cos(ang)) < 0.12 else col
	Q._disc(k, m2, o, ln, 0.0032, rf, cf, skinf, 2, 12)


## Kesik köşeli çizgi (devre izi): (açı, y) noktaları arasında düz parçalar, köşe keskin kalır
static func _poly(k, keys: Array, ff: Callable, ctrl: Array, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	var pts := []
	var ou := []
	for i in ctrl.size() - 1:
		var a0: Vector2 = ctrl[i]
		var a1: Vector2 = ctrl[i + 1]
		var n: int = maxi(2, int(ceil(absf(a1.y - a0.y) / 0.012 + absf(a1.x - a0.x) / 0.08)))
		for j in n + (1 if i == ctrl.size() - 2 else 0):
			var q: Vector2 = a0.lerp(a1, float(j) / n)
			var e: Array = Q._spt(keys, ff, q.x, q.y, lift)
			pts.append(e[0])
			ou.append(e[1])
	k.strip(pts, ou, hw, 0.0016, col, false, skinf)


## Konoha Striker paçası: s0f(u) çaps (deri bacaklık) üst sınırı; u = a * sg (+ dış yan)
static func _chap_top(u: float) -> float:
	var w := wrapf(u, -PI, PI)
	if w >= 0.0:
		return lerpf(0.26, -0.03, smoothstep(0.1, 1.0, w))
	var q := -w
	if q < 1.1:
		return lerpf(0.26, 0.38, smoothstep(0.0, 1.1, q))
	return lerpf(0.38, -0.03, smoothstep(1.1, 2.6, q))


# ------------------------------------------------------------------ Konoha Striker ortak kesimi (ref Shinobi Striker "Leaf Striker" 3 renk): önü açık dik yakalı kısa ceket (omuz boyunduruğu dikişi, katlı manşet,
## sol omuzda arma), gömlek yakası görünen yelek + karın kayışı ve tokası, beldeki kemer (köprüler + toka), bol kot pantolon üstüne önü sivri pencereli çaps,
## botun üstünde toplanan paça. v=0 asıl (yaprak dallı açık yeşil ceket, lacivert yelek, kot + lacivert çaps, sırtta yeşil kese),
## v=1 matador (siyah ceket + altın biye, kol ucu altın şeritler, altın arma, beyaz yelek + kırmızı kayış, altın plakalı kemer, kırmızı kot + altın biyeli siyah çaps, kırmızı bot + altın bant),
## v=2 kovboy (kot ceket: göğüs cep kapakları + düğme, dikiş hatları; beyaz yelek + kahve kayış, sarı gömlek, kahve kemer + mavi köprü, mavi kot + yan cepli kızıl kahve çaps, perçinli bot bandı)
static func _striker(k, v: int) -> void:
	var jc: Color = [Color(0.651, 0.804, 0.722), Color(0.094, 0.094, 0.11), Color(0.18, 0.353, 0.722)][v]
	var vc: Color = [Color(0.102, 0.133, 0.267), Color(0.933, 0.933, 0.918), Color(0.933, 0.933, 0.918)][v]
	var shc: Color = [Color(0.72, 0.74, 0.78), Color(0.1, 0.1, 0.11), Color(0.95, 0.78, 0.18)][v]
	var stc: Color = [Color(0.102, 0.133, 0.267), Color(0.69, 0.133, 0.165), Color(0.5, 0.2, 0.16)][v]
	var bkc: Color = [Color(0.93, 0.93, 0.92), Color(0.86, 0.69, 0.27), Color(0.42, 0.2, 0.15)][v]
	var jn: Color = [Color(0.353, 0.478, 0.69), Color(0.69, 0.133, 0.165), Color(0.227, 0.384, 0.69)][v]
	var cp: Color = [Color(0.102, 0.149, 0.322), Color(0.078, 0.078, 0.086), Color(0.416, 0.196, 0.149)][v]
	var bt: Color = [Color(0.086, 0.086, 0.1), Color(0.69, 0.133, 0.165), Color(0.09, 0.09, 0.1)][v]
	var gd := Color(0.88, 0.7, 0.26)
	var mt := Color(0.72, 0.73, 0.76)
	var lg: Color = [Color(0.72, 0.12, 0.14), gd, Color(0.72, 0.12, 0.14)][v]
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# gömlek (yakada görünür) + yelek
	var by: float = H + 0.115
	SE.body_layer(k, [P._kp(nk, N + 0.06, 0.008, 0.01), P._kp(nk, N + 0.02, 0.016), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.004), P._kp(k.M(by - 0.01, 0.3), by - 0.01, 0.002)], 22, 40, func(_i, _j, _p): return shc)
	var vk := [P._kp(nk, N + 0.005, 0.012), [N - 0.05, ch.x * 0.93, ch.y * 0.9, ch.z * 0.98], P._kp(ch, C - 0.03, 0.012), P._kp(wa, H + 0.12, 0.014), P._kp(k.M(by - 0.04, 0.3), by - 0.04, 0.016)]
	var vf := func(a: float, y: float, _v: float) -> float: return 0.005 * sin(a * 6.0 + y * 15.0) * smoothstep(C, H + 0.15, y)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 24, "na": 64, "top": func(a): return lerpf(N - 0.032, N + 0.004, smoothstep(0.0, 1.7, absf(float(a)))), "hem": func(_a): return by - 0.04, "fold": vf,
		"col": func(_a, _y, _v): return vc, "gain": 7.0, "th": 0.004, "inner": vc.darkened(0.3), "skin": tsk})
	P._cord(k, vg["top"], 0.004, vc.darkened(0.08), true, tsk)
	var nsk := func(p): return Q._nsk(k, p)
	P._cord(k, P._ring_pts([P._kp(nk, N + 0.03, 0.007)], N + 0.03, 0.0, 40), 0.0042, shc.darkened(0.06), true, nsk)
	# karın kayışı + tokası (ceketin açığında görünür)
	var sy: float = H + 0.235
	var vff := func(a, y): return vf.call(float(a), float(y), 0.0)
	var srp := []
	for i in 64:
		srp.append(Q._spt(vk, vff, TAU * i / 64.0 - PI, sy, 0.0035)[0])
	P._bd(k, srp, 0.011, 0.003, stc, true, tsk)
	var se: Array = Q._spt(vk, vff, 0.0, sy, 0.007)
	if v == 0:
		P._boxr(k, se[0], Vector3(0.026, 0, 0), Vector3(0, 0.016, 0), (se[1] as Vector3) * 0.004, Color(0.92, 0.92, 0.9), [["Spine", 1.0]], 0.25)
		P._boxr(k, (se[0] as Vector3) + (se[1] as Vector3) * 0.0035, Vector3(0.017, 0, 0), Vector3(0, 0.008, 0), (se[1] as Vector3) * 0.0015, Color(0.82, 0.83, 0.85), [["Spine", 1.0]], 0.25)
	else:
		P._boxr(k, se[0], Vector3(0.028, 0, 0), Vector3(0, 0.015, 0), (se[1] as Vector3) * 0.0045, stc.lightened(0.04), [["Spine", 1.0]], 0.25)
		Q._buckle(k, (se[0] as Vector3) + (se[1] as Vector3) * 0.005, se[1], 0.014, 0.009, gd if v == 1 else mt, [["Spine", 1.0]])
	# kot: kalça + ön detaylar
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var jk := [P._kp(k.M(by + 0.03, 0.3), by + 0.03, 0.01), P._kp(bl, H + 0.05, 0.012), P._kp(hp, H - 0.05, 0.014), [H - 0.125, hp.x * 0.72, hp.y * 0.74, hp.z * 0.74]]
	SE.body_layer(k, jk, 14, 44, func(_i, _j, _p): return jn)
	P._line(k, jk, [Vector2(0.06, by - 0.015), Vector2(0.075, H - 0.02), Vector2(0.0, H - 0.075)], 0.0028, 0.002, 0.0018, jn.darkened(0.22), 6)
	for sg in [1.0, -1.0]:
		P._line(k, jk, [Vector2(sg * 0.45, by - 0.018), Vector2(sg * 0.62, H + 0.03), Vector2(sg * 1.05, H + 0.0)], 0.0028, 0.002, 0.0018, jn.darkened(0.25), 6)
		P._line(k, jk, [Vector2(sg * (PI - 0.35), H + 0.04), Vector2(sg * (PI - 0.35), H - 0.06), Vector2(sg * (PI - 0.85), H - 0.06), Vector2(sg * (PI - 0.85), H + 0.04)], 0.0026, 0.0025, 0.0018, jn.darkened(0.25), 4)
	# kemer
	var bpts: Array = P._ring_pts(jk, by, 0.006, 80)
	P._bd(k, bpts, 0.0155, 0.0042, bkc, true, tsk)
	for a0 in [0.5, -0.5, 1.25, -1.25, 2.2, -2.2, PI]:
		var e0: Array = P._sa(jk, a0, by, 0.009)
		var lp := [(e0[0] as Vector3) + Vector3(0, 0.02, 0), (e0[0] as Vector3) + Vector3(0, -0.02, 0)]
		k.strip(lp, [e0[1], e0[1]], 0.0058, 0.002, (cp if v == 1 else (Color(0.2, 0.35, 0.75) if v == 2 else jn)), false, tsk)
	var fe: Array = P._sa(jk, 0.0, by, 0.012)
	var fo: Vector3 = fe[1]
	if v == 1:
		for i in 7:
			var a1: float = (float(i) - 3.0) * 0.32
			var e1: Array = P._sa(jk, a1, by, 0.011)
			P._boxr(k, e1[0], (e1[1] as Vector3).cross(Vector3.UP).normalized() * 0.019, Vector3(0, 0.0125, 0), (e1[1] as Vector3) * 0.0035, gd.darkened(0.04 * float(i % 2)), [["Hips", 1.0]], 0.2)
	else:
		Q._buckle(k, fe[0], fo, 0.02, 0.014, mt if v == 0 else gd, [["Hips", 1.0]])
		for i in 4:
			var e2: Array = P._sa(jk, -0.42 - 0.13 * float(i), by, 0.011)
			P._stud(k, e2[0], e2[1], 0.0026, bkc.darkened(0.45), [["Hips", 1.0]])
	if v == 0:   # sırtta yeşil bel çantası
		var pe: Array = P._sa(jk, PI, by - 0.045, 0.026)
		P._boxr(k, pe[0], Vector3(0.062, 0, 0), Vector3(0, 0.032, 0), (pe[1] as Vector3) * 0.022, Color(0.18, 0.33, 0.22), [["Hips", 1.0]], 0.4)
		P._boxr(k, (pe[0] as Vector3) + (pe[1] as Vector3) * 0.018 + Vector3(0, 0.014, 0), Vector3(0.064, 0, 0), Vector3(0, 0.02, 0), (pe[1] as Vector3) * 0.006, Color(0.15, 0.29, 0.19), [["Hips", 1.0]], 0.4)
		P._stud(k, (pe[0] as Vector3) + (pe[1] as Vector3) * 0.024 + Vector3(0, 0.004, 0), pe[1], 0.004, mt, [["Hips", 1.0]])
	# paça: bol kot + önü sivri pencereli çaps + bot konçu
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = le["sg"]
		var kn: float = le["kn"]
		var sv: float = 1.7 if sd == "Left" else 0.6
		var tk := 0.86
		var fo2 := func(s: float, a: float) -> float:
			var g: float = 1.0 - smoothstep(tk - 0.03, tk + 0.005, s)
			var cr: float = 0.008 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
			var ru: float = 0.008 * exp(-pow((s - tk + 0.035) / 0.035, 2.0)) * sin(a * 8.0 + sv)
			return (0.0065 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s) + cr + ru) * g
		var ad := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			var base: float = (0.014 + 0.022 * smoothstep(0.0, 0.4, s) * (1.0 - 0.25 * smoothstep(0.55, tk, s))) * (1.0 - 0.4 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s)))
			return lerpf(base, 0.017, smoothstep(tk - 0.05, tk + 0.006, s)) + float(fo2.call(s, a))
		# tek tüp: pencerede kot, gerisinde çaps (çaps kenarında gerçek kalınlık basamağı; iki kat iç içe geçmez)
		var s0f := func(a: float) -> float: return _chap_top(a * sg)
		var cm := func(s: float, a: float) -> float: return smoothstep(-0.008, 0.008, s - float(s0f.call(a)))
		var cad := func(s: float, a: float) -> float: return float(ad.call(s, a)) + 0.0045 * float(cm.call(s, a))
		P._lt(k, le, cad, func(s, a, ins):
			if ins:
				return cp.darkened(0.45)
			var c0: Color = jn.lerp(cp, clampf(float(cm.call(float(s), float(a))) * 2.0 - 0.5, 0.0, 1.0))
			return P._fs(c0, float(fo2.call(float(s), float(a))), 12.0), 0.0, tk + 0.012, 64, 40, 0.02)
		# pencere kenarı biyesi (çaps ağzı)
		var ep := []
		var eo := []
		for i in 33:
			var a: float = sg * lerpf(0.98, -2.6, float(i) / 32.0)
			var s: float = s0f.call(a)
			var e3: Array = Q._ls(le, s, a, float(cad.call(s, a)) + 0.0006)
			ep.append(e3[0])
			eo.append(e3[1])
		k.strip(ep, eo, 0.0045 if v == 1 else 0.004, 0.0018, gd if v == 1 else cp.darkened(0.28), false, func(p): return P._lskin(le, S._sproj(le, p)))
		if v == 2:   # çapsın dış yanında cep: kapak + perçin
			var oa: float = sg * 1.45
			T._lpatch(k, le, [[Vector2(0.24, oa - 0.42), Vector2(0.24, oa + 0.42)], [Vector2(0.38, oa - 0.42), Vector2(0.38, oa + 0.42)]], func(s, a): return float(cad.call(s, a)) + 0.0028, cp.darkened(0.06))
			T._lpatch(k, le, [[Vector2(0.235, oa - 0.45), Vector2(0.235, oa + 0.45)], [Vector2(0.27, oa - 0.45), Vector2(0.28, oa), Vector2(0.27, oa + 0.45)]], func(s, a): return float(cad.call(s, a)) + 0.0048, cp.darkened(0.15))
			var e4: Array = Q._ls(le, 0.27, oa, float(cad.call(0.27, oa)) + 0.006)
			P._stud(k, e4[0], e4[1], 0.003, mt, P._lskin(le, 0.27))
		# paça bandı: bot ağzının üstünde toplanan kumaş
		Q._ring_on(k, le, tk + 0.004, func(s, a): return float(cad.call(s, a)) - 0.001, 0.008, cp.darkened(0.1), 0.004)
		# bot konçu
		var bf := func(s: float, a: float) -> float: return 0.0085 + 0.004 * smoothstep(tk + 0.06, tk - 0.01, s) + 0.0014 * sin(a * 4.0 + s * 30.0) * smoothstep(tk + 0.02, 0.95, s)
		P._lt(k, le, bf, func(s, a, ins): return bt.darkened(0.45) if ins else P._fs(bt, 0.0014 * sin(float(a) * 4.0 + float(s) * 30.0), 10.0), tk - 0.02, 0.995, 14, 20)
		if v == 1:   # altın bant: iki çizgi + aralarında meander kabartma
			for ss in [tk + 0.022, tk + 0.062]:
				Q._ring_on(k, le, ss, bf, 0.0042, gd, 0.0025)
			for i in 12:
				var a: float = TAU * float(i) / 12.0 - PI
				var e5: Array = Q._ls(le, tk + 0.042, a, float(bf.call(tk + 0.042, a)) + 0.0022)
				P._boxr(k, e5[0], (e5[1] as Vector3).cross(P._ld(le, tk + 0.042)).normalized() * 0.0065, -(P._ld(le, tk + 0.042) as Vector3) * 0.0045, (e5[1] as Vector3) * 0.0016, gd.darkened(0.05), P._lskin(le, tk + 0.042), 0.2)
		elif v == 2:   # perçinli bant
			Q._ring_on(k, le, tk + 0.03, bf, 0.0075, Color(0.13, 0.13, 0.14), 0.0028)
			for i in 16:
				var a: float = TAU * float(i) / 16.0 - PI
				var e6: Array = Q._ls(le, tk + 0.03, a, float(bf.call(tk + 0.03, a)) + 0.0045)
				P._stud(k, e6[0], e6[1], 0.0028, mt, P._lskin(le, tk + 0.03))
	# ceket: kısa, önü açık, dik yaka
	var hem: float = by + 0.085
	var cj := [P._kp(nk, N + 0.012, 0.036), [N - 0.055, ch.x * 1.05, ch.y * 0.99, ch.z * 1.08], P._kp(ch, C - 0.03, 0.042), P._kp(wa, H + 0.12, 0.05), [hem, wa.x + 0.052, wa.y + 0.05, wa.z - 0.05]]
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		return smoothstep(0.3, 0.75, aw) * (0.008 * sin(a * 6.0 + y * 15.0) + 0.005 * sin(a * 11.0 - y * 9.0) * smoothstep(C, hem, y))
	var jff := func(a, y): return jf.call(float(a), float(y))
	var jrg := func(vv) -> Vector2:
		var e: float = lerpf(0.36, 0.42, float(vv))
		return Vector2(e, TAU - e)
	var jg: Dictionary = P._cl(k, {"keys": cj, "ny": 30, "na": 84, "rng": jrg, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return jc, "gain": 6.0, "th": 0.006, "inner": jc.darkened(0.3), "skin": tsk})
	var edc: Color = gd if v == 1 else jc.darkened(0.16)
	for ed in [jg["ea"], jg["eb"]]:
		P._bd(k, ed, 0.0055 if v == 1 else 0.0045, 0.0026, edc, false, tsk, 0.0)
	var jhm := []
	for p in jg["hem"]:
		jhm.append((p as Vector3) + Vector3(0, 0.013, 0))
	P._bd(k, jhm, 0.013, 0.003, jc.lightened(0.03) if v != 1 else jc.lightened(0.04), false, tsk)
	if v == 1:
		var jh2 := []
		for p in jg["hem"]:
			jh2.append((p as Vector3) + Vector3(0, 0.002, 0))
		P._bd(k, jh2, 0.0032, 0.003, gd, false, tsk)
	# omuz boyunduruğu dikişi: önde iki yanda, arkada boydan boya
	for sg in [1.0, -1.0]:
		Q._run(k, cj, jff, [Vector2(sg * 0.45, C + 0.02), Vector2(sg * 0.9, C + 0.025), Vector2(sg * 1.3, C + 0.035)], 0.0022, 0.002, 0.0015, jc.darkened(0.25), tsk, 6)
	Q._run(k, cj, jff, [Vector2(PI * 0.62, C + 0.05), Vector2(PI * 0.82, C + 0.045), Vector2(PI, C + 0.045), Vector2(-PI * 0.82, C + 0.045), Vector2(-PI * 0.62, C + 0.05)], 0.0022, 0.002, 0.0015, jc.darkened(0.25), tsk, 6)
	if v == 2:   # kot ceket: göğüs cep kapakları + düğme, dikey dikişler
		for sg in [1.0, -1.0]:
			var a0: float = sg * 0.78
			var mp: Callable = Q._local(cj, jff, a0, C - 0.01)
			var o: Vector3 = Q._spt(cj, jff, a0, C - 0.01)[1]
			var rows := []
			for j in 4:
				var vv := float(j) / 3.0
				var ro := []
				for i in 9:
					var u := float(i) / 8.0
					var w: float = lerpf(0.03, 0.022, vv) if j == 3 else 0.03
					ro.append(mp.call((u - 0.5) * 2.0 * w + 0.0, -vv * 0.022 - (0.008 * (1.0 - absf(u - 0.5) * 2.0) if j == 3 else 0.0), 0.0045 * sin(minf(vv, 0.9) * PI * 0.7) + 0.002))
				rows.append(ro)
			Q._mesh(k, rows, false, func(_i, j, _p): return jc.darkened(0.12) if j == 0 or j == 3 else jc.lightened(0.04), func(_i, _j, p): return k.torso_skin(p.y), o)
			P._stud(k, mp.call(0.0, -0.022, 0.006), o, 0.0042, mt, k.torso_skin(C - 0.03))
			Q._run(k, cj, jff, [Vector2(sg * 0.5, C - 0.035), Vector2(sg * 0.5, H + 0.18), Vector2(sg * 0.5, hem + 0.02)], 0.002, 0.002, 0.0014, jc.darkened(0.28), tsk, 6)
			Q._run(k, cj, jff, [Vector2(sg * 1.05, C - 0.035), Vector2(sg * 1.05, H + 0.18), Vector2(sg * 1.05, hem + 0.02)], 0.002, 0.002, 0.0014, jc.darkened(0.28), tsk, 6)
	if v == 0:   # yaprak dalları: önde ve sırtta
		var sp := [[0.72, C + 0.055, 1.9, 1.0], [0.62, C - 0.06, 1.3, 1.1], [1.05, H + 0.22, 1.7, 1.0], [0.55, hem + 0.06, 1.4, 1.0], [1.15, C + 0.03, 2.2, 0.85],
			[-0.66, C + 0.05, 1.3, 1.0], [-0.7, C - 0.07, 1.8, 1.1], [-1.1, H + 0.2, 1.4, 1.0], [-0.52, hem + 0.06, 1.9, 1.0],
			[PI - 0.4, C + 0.0, 1.6, 1.1], [PI + 0.45, C - 0.03, 1.4, 1.1], [PI, H + 0.21, 1.7, 1.0], [PI - 0.95, H + 0.18, 1.3, 0.95], [PI + 1.0, H + 0.2, 1.9, 0.95], [PI - 0.15, C + 0.08, 1.5, 0.9]]
		for e in sp:
			var mp2: Callable = Q._local(cj, jff, float(e[0]), float(e[1]))
			var o2: Vector3 = Q._spt(cj, jff, float(e[0]), float(e[1]))[1]
			_sprig(k, mp2, o2, float(e[3]) * 1.3, float(e[2]), jc.darkened(0.5).lerp(Color(0.2, 0.42, 0.28), 0.6), tsk)
	# dik yaka
	var q: float = Q._hq(k)
	var ck := [[N + 0.085 * q, nk.x + 0.032, nk.y + 0.032, nk.z - 0.036], [N + 0.025 * q, nk.x + 0.034, nk.y + 0.032, nk.z - 0.038], [N - 0.025, nk.x + 0.052, nk.y + 0.046, nk.z - 0.046]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 46, "rng": func(_v): return Vector2(0.34, TAU - 0.34), "top": func(a): return N + q * lerpf(0.06, 0.085, smoothstep(0.4, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.022,
		"fold": func(a, _y, vv): return 0.008 * (1.0 - float(vv)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return jc, "inner": jc.darkened(0.2), "skin": nsk, "th": 0.006})
	P._cord(k, cg["top"], 0.0036, gd if v == 1 else jc.darkened(0.1), false, nsk)
	if v == 1:
		for ed in [cg["ea"], cg["eb"]]:
			P._cord(k, ed, 0.0034, gd, false, nsk)
	# kollar: bileğe, katlı manşet; sol omuzda arma
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		var s1 := 0.905
		var sf := func(s: float, a: float) -> float:
			return 0.016 + 0.009 * smoothstep(0.1, 0.5, s) + 0.0035 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.8) / 0.04, 2.0)) * sin(a * 5.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins): return jc.darkened(0.3) if ins else P._fs(jc, float(sf.call(float(s), float(a))) - 0.02, 12.0), 0.0, s1 - 0.06, 34, 22, 0.02)
		var cf := func(s: float, a: float) -> float: return 0.026 + 0.003 * sin(clampf((s - s1 + 0.075) / 0.075, 0.0, 1.0) * PI) + 0.0015 * sin(a * 5.0 + sv)
		P._lt(k, ar, cf, func(s, _a, ins): return jc.darkened(0.3) if ins else (jc.darkened(0.12) if absf(float(s) - (s1 - 0.0375)) > 0.032 else jc), s1 - 0.075, s1, 8, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.006, jc.darkened(0.35), s1 - 0.07, s1 - 0.004, 5, 22)
		if v == 1:
			for ss in [s1 - 0.13, s1 - 0.115, s1 - 0.1]:
				Q._ring_on(k, ar, ss, sf, 0.0032, gd, 0.0022)
		elif v == 0:
			var oa0: float = J._outer_a(ar, 0.6, Vector3(float(ar["sg"]) * 0.6, 0.0, 0.8))
			for e in [[0.6, oa0, 2.0], [0.75, oa0 + 1.6, 1.1], [0.38, oa0 - 1.4, 1.5]]:
				var mp3: Callable = _lmap(ar, float(e[0]), float(e[1]), sf)
				_sprig(k, mp3, Q._ls(ar, float(e[0]), float(e[1]), 0.0)[1], 1.1, float(e[2]), jc.darkened(0.5).lerp(Color(0.2, 0.42, 0.28), 0.6), func(_p): return P._lskin(ar, float(e[0])))
		if sd == "Left":   # sol omuzda arma: dolu disk + girdap
			var s0 := 0.17
			var a0: float = J._outer_a(ar, s0, Vector3(1.0, 0.25, 0.0).normalized())
			var mp4: Callable = _lmap(ar, s0, a0, sf)
			Q._disc(k, mp4, Q._ls(ar, s0, a0, 0.0)[1], 0.03, 0.002, Callable(), func(_u, _v): return lg, func(_p): return P._lskin(ar, s0), 3, 26)
			if v != 1:
				var pp := []
				for i in 22:
					var t := float(i) / 21.0
					var th := 0.4 + t * TAU * 1.6
					pp.append(Vector2(cos(th), sin(th)) * 0.03 * lerpf(0.7, 0.08, t))
				R._lstrip(k, mp4, pp, 0.0028, 0.0042, 0.0012, lg.darkened(0.35), func(_p): return P._lskin(ar, s0))
			else:
				Q._circle(k, mp4, 0.024, 0.0022, 0.0042, gd.darkened(0.3), func(_p): return P._lskin(ar, s0), 30)
				Q._circle(k, mp4, 0.012, 0.0022, 0.0042, gd.darkened(0.3), func(_p): return P._lskin(ar, s0), 22)


# ------------------------------------------------------------------ Wakai Midori (ref Shinobi Striker "Lee Outfit"): kolsuz koyu yeşil tulum (kol oyuğu yırtık saçaklı, karında iki verev cep yarığı, koyu ağ parçası),
## boyunda iki sıra dilimli dolgu turuncu boyunluk, dirsekten parmaklara beyaz sargı, dizaltından bileğe dikey fitilli turuncu tozluk (üst ağzı kalın)
static func _genc(k) -> void:
	var gr := Color(0.118, 0.29, 0.165)
	var gdk := gr.darkened(0.35)
	var og := Color(0.93, 0.56, 0.18)
	var orr := Color(0.8, 0.3, 0.1)
	var wh := Color(0.95, 0.94, 0.92)
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
	# gövde: biraz bol, belde hafif büzgü, aşağı inen gerilme kırışıkları
	var tk := [P._kp(nk, N + 0.03, 0.012), [N - 0.05, ch.x * 0.96, ch.y * 0.9, ch.z * 1.0], P._kp(ch, C - 0.03, 0.016), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.04, 0.02), [H - 0.1, hp.x * 0.92, hp.y * 0.9, hp.z * 0.9]]
	var tf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((C - y) / maxf(0.05, C - H), 0.0, 1.0)
		return t * (0.012 * sin(a * 7.0 + y * 12.0) + 0.006 * sin(a * 13.0 - y * 20.0)) + 0.008 * exp(-pow((y - H - 0.12) / 0.03, 2.0)) * sin(a * 11.0 + 0.4)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 34, "na": 72, "top": func(_a): return N + 0.03, "hem": func(_a): return H - 0.1, "fold": tf,
		"col": func(_a, _y, _v): return gr, "gain": 6.0, "th": 0.0, "skin": tsk})
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	# yan dikişler + cep yarıkları (koyu yarık + üstte kalkık dudak)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tff, [Vector2(sg * PI * 0.5, C - 0.05), Vector2(sg * PI * 0.5, H + 0.05), Vector2(sg * PI * 0.5, H - 0.08)], 0.0024, 0.0015, 0.0012, gdk, tsk, 6)
		Q._run(k, tk, tff, [Vector2(sg * 0.6, H + 0.11), Vector2(sg * 0.74, H + 0.04), Vector2(sg * 0.86, H - 0.03)], 0.0042, 0.0005, 0.0006, gr.darkened(0.6), tsk, 5)
		Q._run(k, tk, tff, [Vector2(sg * 0.58, H + 0.112), Vector2(sg * 0.72, H + 0.042), Vector2(sg * 0.84, H - 0.028)], 0.0022, 0.004, 0.0024, gr.lightened(0.12), tsk, 5)
	# kasık: koyu ağ parçası
	SE.body_layer(k, [P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.016), P._kp(hp, H - 0.06, 0.018), [H - 0.14, hp.x * 0.78, hp.y * 0.78, hp.z * 0.78]], 8, 40, func(_i, _j, p): return gr if absf(p.x) > 0.05 else gdk)
	# kollar: kolsuz, yırtık oyuk; dirsekten parmaklara sargı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.1
		P._bare(k, ar, skc, 0.06, en + 0.02)
		var st := func(s: float, a: float) -> float: return 0.008 + 0.003 * P._lf(s, a, sv) - 0.002 * smoothstep(0.05, 0.14, s)
		S._lte(k, ar, st, func(_s, a, ins): return gdk if ins else gr.darkened(0.1 * float(sin(float(a) * 7.0) < -0.3)), 0.0, func(a): return 0.105 + 0.022 * Q._tri(float(a) * 9.0 + sv) + 0.01 * sin(float(a) * 4.0 + sv), 10, 30)
		P._lt(k, ar, func(_s, _a): return 0.0008, func(_s, _a, ins): return wh.darkened(0.34) if ins else wh.darkened(0.14), en - 0.04, 0.975, 16, 18)
		P._wraps(k, ar, en - 0.025, 0.955, 15, 0.0034, 0.0112, wh, 0.0072)
		K._glove(k, sd, ar, wh.darkened(0.04), wh.darkened(0.12))
	# bacaklar: tulum paçası dizin altında tozluğa girer
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.5 if sd == "Left" else 0.4
		var sg: float = le["sg"]
		var s1: float = kn + 0.085
		var pa := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			return (0.012 + 0.012 * exp(-pow((s - kn + 0.05) / 0.2, 2.0))) * (1.0 - 0.35 * inn * (1.0 - smoothstep(0.25, 0.5, s))) + 0.006 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 34.0 + sv) + 0.003 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s) - 0.006 * smoothstep(kn + 0.04, s1, s)
		P._lt(k, le, pa, func(s, a, ins): return gdk if ins else P._fs(gr, float(pa.call(float(s), float(a))) - 0.014, 14.0), 0.0, s1, 34, 22)
		# tozluk: geniş düz tüp, dikey fitil, kalın üst ağız, bilekte hafif yığılma; dış yanı kızıl gölgeli
		var oa: float = J._outer_a(le, kn + 0.3, Vector3(sg, 0.0, 0.0))
		var lg := func(s: float, a: float) -> float:
			var u: float = clampf((s - kn - 0.05) / (0.995 - kn - 0.05), 0.0, 1.0)
			var rib: float = 0.004 * cos(a * 7.0 + sv)
			var cuff: float = 0.011 * exp(-pow((u - 0.025) / 0.03, 2.0))
			var sl: float = smoothstep(0.7, 0.95, u) * (0.006 + 0.004 * sin(u * 34.0 + a * 1.5))
			return 0.017 + 0.006 * u + rib + cuff + sl
		P._lt(k, le, lg, func(s, a, ins):
			if ins:
				return og.darkened(0.45)
			var rb: float = cos(float(a) * 7.0 + sv)
			var c0: Color = og.lerp(orr, 0.55 * smoothstep(0.45, 0.9, cos(float(a) - oa)))
			return c0.darkened(clampf(-rb, 0.0, 1.0) * 0.24).lightened(clampf(rb, 0.0, 1.0) * 0.05), kn + 0.05, 0.995, 30, 42, 0.03)
	# boyunluk: iki sıra dilimli dolgu halka + altta koyu kat
	var q: float = Q._hq(k)
	var nkk := [[N + 0.1, nk.x + 0.008, nk.y + 0.008, nk.z - 0.008], [N + 0.02, nk.x + 0.02, nk.y + 0.018, nk.z - 0.02], [N - 0.03, nk.x + 0.05, nk.y + 0.04, nk.z - 0.042], [N - 0.08, ch.x * 0.62, ch.y * 0.74, ch.z * 0.8]]
	P._roll(k, nkk, N - 0.045, 0.026, 10, 0.006, orr.lerp(og, 0.3))
	P._roll(k, nkk, N - 0.002, 0.036, 10, 0.012, og)
	P._roll(k, nkk, N + 0.05 * q, 0.03, 10, 0.012, og.lightened(0.04))


# ------------------------------------------------------------------ Daidokoro Shōzoku (ref Shinobi Striker "Kushina Outfit"): fermuarlı beyaz dik yakalı gömlek (kısa büzgülü kol), geniş askılı yuvarlak yakalı
## kolsuz koyu yeşil önlük elbise (bedene oturan üst, belden aşağı A kesim, baldırın üst üçte birinde biter), sol bilekte siyah bilezik, açık bacak
static func _onluk(k) -> void:
	var wh := Color(0.949, 0.949, 0.949)
	var gn := Color(0.141, 0.29, 0.188)
	var bk := Color(0.08, 0.08, 0.09)
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
	P._inner(k, b, func(_i, _j, p): return wh.darkened(0.03 * float(p.y < C - 0.1)), 0.006)
	SE.body_layer(k, [P._kp(hp, H + 0.02, 0.004), P._kp(hp, H - 0.05, 0.01), [H - 0.14, hp.x * 0.74, hp.y * 0.76, hp.z * 0.76]], 6, 32, func(_i, _j, _p): return gn.darkened(0.5))
	# dik yaka: boynu saran, önde fermuar + çekme
	var q: float = Q._hq(k)
	var ck := [[N + 0.085 * q, nk.x + 0.018, nk.y + 0.018, nk.z - 0.02], [N + 0.02 * q, nk.x + 0.024, nk.y + 0.022, nk.z - 0.026], [N - 0.03, nk.x + 0.044, nk.y + 0.04, nk.z - 0.04]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 48, "rng": func(_v): return Vector2(0.05, TAU - 0.05), "top": func(a): return N + q * lerpf(0.07, 0.085, smoothstep(0.3, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.028,
		"fold": func(a, y, _v): return 0.006 * sin(float(a) * 3.0 + 0.6) * smoothstep(N, N + 0.06, float(y)), "col": func(_a, _y, _v): return wh, "gain": 6.0, "inner": wh.darkened(0.2), "skin": nsk, "th": 0.006})
	P._cord(k, cg["top"], 0.0036, wh.darkened(0.07), false, nsk)
	var zq := []
	var zo := []
	for j in 12:
		var e: Array = Q._spt(ck, Callable(), 0.0, lerpf(N + 0.08 * q, N - 0.025, float(j) / 11.0), 0.002)
		zq.append(e[0])
		zo.append(e[1])
	k.strip(zq, zo, 0.0032, 0.0018, Color(0.55, 0.55, 0.57), false, nsk)
	var zt: Array = Q._spt(ck, Callable(), 0.0, N + 0.03, 0.0045)
	P._boxr(k, zt[0], Vector3(0.0042, 0, 0), Vector3(0, 0.0105, 0), (zt[1] as Vector3) * 0.0022, Color(0.6, 0.6, 0.62), [["Neck", 0.5], ["UpperChest", 0.5]], 0.3)
	# kollar: büzgülü kısa kol, altı açık ten; sol bilekte bilezik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.9 if sd == "Left" else 2.2
		P._bare(k, ar, skc, 0.22, 1.0)
		P._bare(k, le, skc)
		var sf := func(s: float, a: float) -> float: return 0.01 + 0.016 * exp(-pow((s - 0.1) / 0.09, 2.0)) + 0.008 * smoothstep(0.12, 0.3, s) + 0.003 * sin(a * 7.0 + sv) * smoothstep(0.15, 0.3, s)
		S._lte(k, ar, sf, func(s, a, ins): return wh.darkened(0.25) if ins else P._fs(wh, 0.003 * sin(float(a) * 7.0 + sv) * smoothstep(0.15, 0.3, float(s)) - 0.004 * float(absf(float(s) - 0.1) < 0.012), 12.0), 0.0, func(a): return 0.3 + 0.012 * sin(float(a) * 7.0 + sv), 16, 28)
	var lw: Dictionary = P._limb(k, "Left", false)
	var bf := func(s: float, _a: float) -> float: return 0.009 + 0.004 * sin(clampf((s - 0.905) / 0.035, 0.0, 1.0) * PI)
	P._lt(k, lw, bf, func(_s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.06 * float(cos(float(a)) > 0.4)), 0.905, 0.94, 4, 20)
	# önlük elbise: geniş askı, yuvarlak yaka, belde oturur, A kesim
	var hem: float = KN - 0.1
	var keys := [P._kp(nk, N + 0.01, 0.04, 0.034), [N - 0.055, ch.x * 0.99, ch.y * 0.92, ch.z * 1.03], P._kp(ch, C - 0.03, 0.016), [C - 0.13, wa.x + 0.04, ch.y + 0.008, wa.z - 0.03], P._kp(wa, H + 0.12, 0.034),
		P._kp(hp, H - 0.04, 0.05), [KN + 0.05, hp.x + 0.062, hp.y + 0.06, hp.z - 0.07], [hem, hp.x + 0.075, hp.y + 0.068, hp.z - 0.08]]
	var nf: float = N - 0.065
	var ns: float = N - 0.03
	var nb: float = N - 0.055
	var top := func(a: float) -> float:
		var w: float = absf(a)
		if w < 0.62:
			return lerpf(nf, ns, pow(smoothstep(0.0, 0.62, w), 1.6))
		if w < 1.05:
			return ns
		if w < 2.15:
			return ns - (ns - (C - 0.085)) * pow(sin(clampf((w - 1.05) / 1.1, 0.0, 1.0) * PI), 0.8)
		return lerpf(ns, nb, smoothstep(2.15, 2.6, w))
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.12 - y) / (H + 0.12 - hem), 0.0, 1.0)
		var bust: float = exp(-pow((y - (C - 0.125)) / 0.03, 2.0)) * exp(-pow(a / 0.8, 2.0))
		return t * t * (0.03 * sin(a * 6.0 + 0.9) + 0.014 * sin(a * 11.0 + 2.3)) + t * 0.006 * sin(a * 4.0 + 1.4) - bust * 0.006 + (1.0 - t) * 0.004 * sin(a * 9.0 + y * 12.0) * smoothstep(C, H + 0.12, y)
	var dsk := func(p): return AA._fam(k, p, hem)
	var g: Dictionary = P._cl(k, {"keys": keys, "ny": 62, "na": 112, "top": top, "hem": func(a): return hem + 0.01 * cos(float(a)), "fold": fold,
		"col": func(a, y, _v): return gn.lightened(0.035 * sin(float(a) * 23.0 + float(y) * 7.0) * smoothstep(H, hem, float(y))), "gain": 7.0, "th": 0.006, "inner": gn.darkened(0.42), "skin": dsk})
	P._bd(k, g["top"], 0.0055, 0.0028, gn.darkened(0.2), true, func(p): return k.torso_skin(p.y), 0.3)
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.014, 0))
	P._bd(k, hm, 0.0028, 0.0014, gn.darkened(0.3), true, dsk)
	# yan dikişler + sırtta beli oturtan pens
	var ffw := func(a, y): return fold.call(float(a), float(y), 0.0)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ffw, [Vector2(sg * PI * 0.5, C - 0.1), Vector2(sg * PI * 0.5, H + 0.1), Vector2(sg * PI * 0.5, H - 0.1), Vector2(sg * PI * 0.5, hem + 0.02)], 0.0024, 0.0016, 0.0012, gn.darkened(0.28), dsk, 8)
		Q._run(k, keys, ffw, [Vector2(sg * (PI - 0.55), C - 0.08), Vector2(sg * (PI - 0.5), H + 0.12), Vector2(sg * (PI - 0.55), H + 0.0)], 0.0022, 0.0014, 0.0011, gn.darkened(0.26), dsk, 6)


# ------------------------------------------------------------------ Raimei Shōzoku (ref Shinobi Striker "Light Outfit Thunderclap"): gri iç giysi, uyluğa inen kruvaze beyaz tunik (sol kanat sağın üstüne biner,
## yeşil + sarı biyeli kenar, eteğinde sarı devre çizgileri), belde düğümlü koyu yeşil ip kuşak (iki halka + püsküllü uç), önde dökülen soluk yeşil bez, yanlarda dize inen koyu yeşil alt etek,
## sağ omuzda sarı çizgili siyah omuzluk + sarı püskül ve altında gri dilimli kol plakaları, sol kolda siyah biyeli kısa kol, dirsekten bileğe gri sargı + sarı parlak kolluk,
## dize kadar bol gri pantolon (dizde sarı çapraz bağ), baldırda gri sargı + sarı ok çizgileri
static func _simsek(k) -> void:
	var wh := Color(0.9, 0.9, 0.92)
	var gy := Color(0.6, 0.61, 0.63)
	var lg := Color(0.8, 0.81, 0.8)
	var dg := Color(0.22, 0.31, 0.19)
	var pg := Color(0.72, 0.77, 0.7)
	var yl := Color(0.93, 0.93, 0.19)
	var bk := Color(0.1, 0.1, 0.11)
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
	P._inner(k, b, func(_i, _j, _p): return gy, 0.005)
	K._seat(k, b, lg)
	# pantolon: bol, dizin altında toplanır; dizde sarı çapraz bağ; baldırda sargı + sarı ok çizgileri
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.6
		var tk2: float = kn + 0.1
		var pa: Callable = Q._baggy(k, le, lg, gy.lightened(0.15), 0.016, 0.034, tk2, sv)
		var oa: float = J._outer_a(le, kn, Vector3(0.0, 0.0, 1.0))
		for sg in [1.0, -1.0]:
			T._lline(k, le, [Vector2(kn - 0.1, oa - sg * 1.25), Vector2(kn - 0.04, oa - sg * 0.3), Vector2(kn + 0.02, oa + sg * 0.6), Vector2(kn + 0.07, oa + sg * 1.4)], func(s, a): return float(pa.call(s, a)) + 0.0012, 0.0042, yl, 5)
		Q._ring_on(k, le, kn - 0.1, pa, 0.005, yl, 0.0025)
		var sw := func(s: float, a: float) -> float: return 0.009 + 0.0015 * sin(a * 3.0 + s * 60.0)
		P._lt(k, le, sw, func(s, a, ins): return gy.darkened(0.3) if ins else lg.darkened(0.08 + 0.1 * float(sin(float(s) * 120.0 + float(a) * 0.6) < -0.5)), tk2 - 0.02, 0.99, 22, 20)
		Q._ring_on(k, le, tk2 + 0.006, sw, 0.007, yl, 0.003)
		for i in 4:
			var s: float = tk2 + 0.05 + 0.055 * float(i)
			T._lline(k, le, [Vector2(s, oa - 0.95), Vector2(s + 0.035, oa), Vector2(s, oa + 0.95)], func(s2, a2): return float(sw.call(s2, a2)) + 0.0012, 0.0028, yl, 4)
		T._lline(k, le, [Vector2(tk2 + 0.04, oa), Vector2(0.97, oa)], func(s2, a2): return float(sw.call(s2, a2)) + 0.0012, 0.0024, yl.darkened(0.1), 6)
	# alt etek: yanlarda ve arkada dize iner (koyu yeşil)
	var uh: float = KN + 0.06
	var uk := [P._kp(k.M(H + 0.1, 0.3), H + 0.1, 0.018), P._kp(hp, H - 0.04, 0.03), [H - 0.2, hp.x + 0.052, hp.y + 0.04, hp.z - 0.05], [uh, hp.x + 0.08, hp.y + 0.055, hp.z - 0.08]]
	var usk := func(p): return AA._fam(k, p, uh)
	var uf := func(a: float, y: float, _v: float) -> float: return 0.02 * sin(a * 6.0 + 0.3) * smoothstep(H - 0.2, uh, y)
	P._cl(k, {"keys": uk, "ny": 26, "na": 50, "rng": func(_v): return Vector2(1.1, TAU - 1.1), "top": func(_a): return H + 0.1, "hem": func(a): return uh + 0.03 * cos(float(a)) - 0.02, "fold": uf,
		"col": func(_a, _y, _v): return dg, "gain": 6.0, "th": 0.005, "inner": dg.darkened(0.35), "skin": usk})
	# tunik: omuzdan uyluğa, kruvaze
	var hem: float = H - 0.2
	var tk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(hp, H - 0.04, 0.05), [hem, hp.x + 0.075, hp.y + 0.065, hp.z - 0.07]]
	var tf := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.08 - y) / (H + 0.08 - hem), 0.0, 1.0)
		return t * (0.022 * sin(a * 7.0 + 0.5) + 0.01 * sin(a * 13.0 + 1.6)) + (1.0 - t) * 0.007 * sin(a * 5.0 + y * 16.0) * smoothstep(N - 0.02, C - 0.04, y)
	var tff := func(a, y): return tf.call(float(a), float(y))
	var ksk := func(p): return AA._fam(k, p, uh)
	var vt := func(_a: float) -> float: return N + 0.012
	P._cl(k, {"keys": tk, "ny": 46, "na": 92, "top": func(a): return vt.call(float(a)), "hem": func(a): return hem + 0.012 * cos(float(a)), "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return wh, "gain": 5.0, "th": 0.006, "inner": wh.darkened(0.3), "skin": ksk})
	# üst kanat: sol yakadan aşağı, sağ yana dolanır (kalkık kenar)
	var ef := func(y: float) -> float: return lerpf(0.36, 0.06, smoothstep(N, H - 0.05, y))
	var fl: Dictionary = P._cl(k, {"keys": tk, "ny": 40, "na": 40, "rng": func(vv):
		var y: float = lerpf(N + 0.006, hem, float(vv))
		return Vector2(-1.75, float(ef.call(y))), "top": func(_a): return N + 0.008, "hem": func(a): return hem + 0.012 * cos(float(a)) - 0.004,
		"fold": func(a, y, _v): return tf.call(float(a), float(y)), "col": func(_a, _y, _v): return wh.lightened(0.02), "gain": 5.0, "th": 0.004, "lift": 0.005, "inner": wh.darkened(0.25), "skin": ksk})
	var edge: Array = fl["eb"]
	P._bd(k, edge, 0.0085, 0.0034, dg, false, ksk, 0.0)
	var fr: Array = fl["rows"]
	var ye := []
	for ro in fr:
		var e0: Vector3 = ro[ro.size() - 1]
		var e1: Vector3 = ro[ro.size() - 2]
		ye.append(e0.lerp(e1, 0.55) + Vector3(e0.x, 0.0, e0.z).normalized() * 0.0062)
	P._cord(k, ye, 0.0019, yl, false, ksk)
	# yakalık: boyunda yeşil biye
	P._cord(k, P._ring_pts([P._kp(nk, N + 0.02, 0.024)], N + 0.02, 0.0, 44), 0.0045, dg, true, nsk)
	# sarı devre çizgileri: sol göğüs kenarı ve etek önü
	for e in [[[Vector2(0.5, C - 0.06), Vector2(0.5, H + 0.2), Vector2(0.62, H + 0.2), Vector2(0.62, H + 0.13)], 0.0024, 0.0045],
			[[Vector2(0.3, H + 0.03), Vector2(0.3, H - 0.08), Vector2(0.44, H - 0.08), Vector2(0.44, hem + 0.03)], 0.0028, 0.0045],
			[[Vector2(0.55, H + 0.03), Vector2(0.55, H - 0.04), Vector2(0.68, H - 0.04)], 0.0026, 0.0045],
			[[Vector2(0.2, H - 0.11), Vector2(0.2, hem + 0.025)], 0.0024, 0.0045],
			[[Vector2(-0.3, H + 0.03), Vector2(-0.3, H - 0.09), Vector2(-0.46, H - 0.09), Vector2(-0.46, hem + 0.03)], 0.0026, 0.0115]]:
		_poly(k, tk, tff, e[0], float(e[1]), float(e[2]), yl, ksk)
	# önde dökülen soluk yeşil bez: sağ kalçadan sola kemerin altında sarkar
	var dk2 := [[H + 0.1, wa.x + 0.042, wa.y + 0.042, wa.z - 0.042], P._kp(hp, H - 0.04, 0.06), [H - 0.14, hp.x + 0.075, hp.y + 0.07, hp.z - 0.07]]
	var dr: Dictionary = P._cl(k, {"keys": dk2, "ny": 12, "na": 44, "rng": func(_v): return Vector2(-1.75, 0.5), "top": func(_a): return H + 0.085,
		"hem": func(a): return H + 0.06 - 0.13 * pow(sin(clampf((float(a) + 1.75) / 2.25, 0.0, 1.0) * PI), 0.9) * (1.0 - 0.3 * smoothstep(0.0, 0.5, float(a))),
		"fold": func(a, _y, vv): return 0.012 * sin(float(vv) * PI * 3.0) * float(vv) + 0.005 * sin(float(a) * 9.0) * float(vv), "col": func(_a, _y, vv): return pg.darkened(0.14 * maxf(0.0, -sin(float(vv) * PI * 3.0)) * float(vv)), "gain": 6.0, "th": 0.005, "inner": pg.darkened(0.3), "skin": ksk})
	P._cord(k, dr["hem"], 0.004, pg.darkened(0.12), false, ksk)
	# ip kuşak: iki tur burgu ip, önde düğüm + iki halka + püsküllü uçlar (tuniğin önüne oturur)
	var by: float = H + 0.09
	var rk := [P._kp(wa, by + 0.04, 0.05), P._kp(wa, by - 0.04, 0.05)]
	for dy in [0.012, -0.012]:
		var rp: Array = P._ring_pts(rk, by + dy, 0.006, 72)
		T._twist(k, rp, true, 0.0085, 22.0, dg, tsk)
	var kc: Array = P._sa(rk, 0.18, by, 0.02)
	P._boxr(k, kc[0], Vector3(0.022, 0.006, 0), Vector3(-0.004, 0.019, 0), (kc[1] as Vector3) * 0.012, dg.darkened(0.06), [["Hips", 1.0]], 0.45)
	var loops := [[0.1, 0.075, 0.14], [0.26, 0.085, 0.18]]
	for e in loops:
		var a0: float = e[0]
		var pts := []
		for i in 15:
			var t: float = float(i) / 14.0
			var aa: float = a0 + float(e[1]) * sin(t * PI) * 0.5 * (1.0 if t < 0.5 else 1.0) - float(e[1]) * 0.25 + float(e[1]) * 0.5 * t
			var y: float = by - 0.02 - float(e[2]) * sin(t * PI)
			pts.append(Q._spt(tk, tff, aa, y, 0.016)[0])
		T._twist(k, pts, false, 0.0062, 8.0, dg, ksk)
	for e in [[0.12, H - 0.13], [0.2, H - 0.1]]:
		var pts2 := []
		for i in 10:
			var t: float = float(i) / 9.0
			pts2.append(Q._spt(tk, tff, lerpf(0.18, float(e[0]), t), lerpf(by - 0.02, float(e[1]), t), 0.017)[0])
		T._twist(k, pts2, false, 0.0062, 6.0, dg, ksk, 0.0)
		var tp: Array = Q._spt(tk, tff, float(e[0]), float(e[1]) - 0.025, 0.018)
		P._tb(k, [(tp[0] as Vector3) + Vector3(0, 0.026, 0), (tp[0] as Vector3) + Vector3(0, 0.0, 0), (tp[0] as Vector3) + Vector3(0, -0.02, 0)], func(s, _a): return lerpf(0.009, 0.013, float(s)), func(_s, a, _p): return dg.darkened(0.15 if sin(float(a) * 6.0) < 0.0 else 0.0), func(_s, p): return ksk.call(p), 12)
	# kollar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.4 if sd == "Left" else 0.3
		var sg: float = ar["sg"]
		# gri iç kol: dirseğe kadar, sonra sargı
		var gs := func(s: float, a: float) -> float: return 0.007 + 0.002 * P._lf(s, a, sv) + 0.005 * exp(-pow((s - en) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, gs, func(s, a, ins): return gy.darkened(0.3) if ins else P._fs(gy, float(gs.call(float(s), float(a))) - 0.007, 18.0), 0.0, en + 0.02, 26, 18)
		P._lt(k, ar, func(_s, _a): return 0.0035, func(_s, _a, ins): return lg.darkened(0.3) if ins else lg.darkened(0.06), en, 0.95, 14, 18)
		P._wraps(k, ar, en + 0.02, 0.93, 9, 0.006, 0.012, lg, 0.008)
		K._glove(k, sd, ar, gy.lightened(0.1), gy)
		# sarı parlak kolluk: ön kolun dışında dikey levha
		var oa: float = J._outer_a(ar, (en + 0.9) * 0.5, Vector3(sg, 0.0, 0.25).normalized())
		K._shell(k, ar, en + 0.06, 0.86, oa - 0.55, oa + 0.55, func(_s, _a): return 0.013, 0.006, func(_u, vv, ins): return yl.darkened(0.25) if ins else yl.lightened(0.08 * float(vv)), 10, 10)
		# tunik kolu: kısa, geniş
		var s1: float = 0.34
		var sf := func(s: float, a: float) -> float: return 0.02 + 0.016 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv)
		P._lt(k, ar, sf, func(s, a, ins): return wh.darkened(0.3) if ins else P._fs(wh, 0.004 * P._lf(float(s), float(a), sv), 14.0), 0.0, s1, 16, 22, 0.04)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, wh.darkened(0.35), s1 - 0.08, s1 - 0.004, 5, 22)
		if sd == "Left":
			P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, s1 - 0.03, s1 + 0.002, 3, 22)
		else:   # omuzluk: siyah kabuk + sarı çizgiler + gri dilimli plakalar + sarı püskül
			var ua: float = J._outer_a(ar, 0.12, Vector3(-1.0, 0.45, 0.0).normalized())
			for i in 3:
				var s0: float = 0.2 + 0.07 * float(i)
				K._shell(k, ar, s0, s0 + 0.09, ua - 1.25, ua + 1.25, func(s, a): return float(sf.call(s, a)) + 0.004 + 0.003 * float(i), 0.007, func(_u, vv, ins): return gy.darkened(0.35) if ins else (bk if vv > 0.85 else gy.lightened(0.12)), 8, 14)
			var pf := func(s: float, a: float) -> float: return float(sf.call(s, a)) + 0.018 + 0.012 * (1.0 - smoothstep(0.0, 0.2, s))
			K._shell(k, ar, -0.02, 0.24, ua - 1.45, ua + 1.45, pf, 0.012, func(_u, _v, ins): return bk.lightened(0.1) if ins else bk, 14, 18)
			for i in 3:
				var a1: float = ua - 0.9 + 0.55 * float(i)
				T._lline(k, ar, [Vector2(0.0, a1 - 0.2), Vector2(0.12, a1 + 0.05), Vector2(0.22, a1 + 0.25)], func(s, a): return float(pf.call(s, a)) + 0.013, 0.0045, yl, 4)
			var ke: Array = Q._ls(ar, 0.08, ua + 0.95, float(pf.call(0.08, ua + 0.95)) + 0.014)
			var ko: Vector3 = ke[1]
			P._stud(k, ke[0], ko, 0.009, yl, P._lskin(ar, 0.08))
			var tp0: Vector3 = (ke[0] as Vector3) + ko * 0.004
			P._tb(k, [tp0, tp0 + Vector3(0, -0.03, 0) + ko * 0.01, tp0 + Vector3(0, -0.06, 0) + ko * 0.012], func(s, _a): return lerpf(0.004, 0.012, smoothstep(0.3, 1.0, float(s))), func(s, a, _p): return yl.darkened(0.18 if sin(float(a) * 7.0) < -0.2 and float(s) > 0.4 else 0.0), func(_s, _p): return P._lskin(ar, 0.12), 14)
