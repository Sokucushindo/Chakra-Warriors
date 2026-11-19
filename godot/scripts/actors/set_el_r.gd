extends RefCounted
## Elle modellenmiş setler, parti r: ss_sahil, ss_sahil_hibiskus, ss_sahil_denizci, ss_sahil_gok, ss_sahil_flamingo, ss_esofman. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q) dosyalarından; burada çıplak gövde, şort, şişme yelek ve yüzeye oturan desen parçaları (çiçek, yaprak, balık, flamingo, karpuz).
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")

const DONE := ["ss_sahil", "ss_sahil_hibiskus", "ss_sahil_denizci", "ss_sahil_gok", "ss_sahil_flamingo", "ss_esofman"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_sahil": _sahil(k)
		"ss_sahil_hibiskus": _hibiskus(k)
		"ss_sahil_denizci": _denizci(k)
		"ss_sahil_gok": _gok(k)
		"ss_sahil_flamingo": _flamingo(k)
		"ss_esofman": _esofman(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ortak: ten, şort, yüzey eşlemeleri
## Çıplak gövde: bedenin kendi kesitinden ten; erkekte göğüs kası, göğüs altı çizgisi ve karın oluğu geometriden
static func _bare_torso(k, b: Dictionary, y1: float, male: bool) -> Array:
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.02, 0.005), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.9], P._kp(ch, C - 0.03, 0.003)]
	for y in [C - 0.12, H + 0.12, H + 0.04]:
		if y > y1 + 0.02:
			keys.append(P._kp(k.M(y, k.UA), y, 0.003))
	keys.append(P._kp(k.M(y1, k.UA if y1 > H else 0.3), y1, 0.004))
	var skc: Color = Q._skc(k)
	var ff := func(a: float, y: float) -> float:
		if not male:
			return 0.0
		var aw := absf(a)
		var pec: float = 0.05 * exp(-pow((aw - 0.5) / 0.3, 2.0)) * exp(-pow((y - (C - 0.04)) / 0.045, 2.0))
		var pl: float = -0.022 * exp(-pow((aw - 0.48) / 0.36, 2.0)) * exp(-pow((y - (C - 0.095)) / 0.014, 2.0))
		var ab: float = -0.024 * exp(-pow(a / 0.07, 2.0)) * smoothstep(C - 0.03, C - 0.09, y) * smoothstep(H + 0.02, H + 0.09, y)
		var st: float = -0.018 * exp(-pow(a / 0.08, 2.0)) * exp(-pow((y - C) / 0.06, 2.0))
		return pec + pl + ab + st
	var na := 52
	SE.body_layer(k, keys, 40, na, func(i, _j, p):
		var f: float = ff.call(TAU * float(i) / na - PI, float(p.y))
		return skc.darkened(clampf(-f * 6.0, 0.0, 0.14)), ff)
	return keys


## Açık kol: bedenin kalınlığında ten; bilekte uç kapanarak elin içine girer (boş halka görünmez)
static func _arm_skin(k, ar: Dictionary, s0 := 0.0) -> void:
	var skc: Color = Q._skc(k)
	P._lt(k, ar, func(s, _a): return 0.001 - P._lr(ar, float(s)) * 0.9 * smoothstep(0.955, 0.99, float(s)), func(_s, _a, ins): return skc.darkened(0.3) if ins else skc, s0, 0.99, 30, 16)


static func _bare_limbs(k, arms: bool, legs: bool) -> void:
	var skc: Color = Q._skc(k)
	for sd in ["Left", "Right"]:
		if arms:
			_arm_skin(k, P._limb(k, sd, false))
		if legs:
			P._bare(k, P._limb(k, sd, true), skc, 0.0, 1.0)


## Şort kalçası (pantolon gövdesi): bedenden biraz bol
static func _seat_keys(k, b: Dictionary) -> Array:
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = k.M(k.H + 0.05, 0.3)
	return [P._kp(bl, k.H + 0.085, 0.008), P._kp(bl, k.H + 0.04, 0.014), P._kp(hp, k.H - 0.05, 0.02), [k.H - 0.15, hp.x * 0.8, hp.y * 0.8, hp.z * 0.8]]


static func _seat(k, keys: Array, colf: Callable) -> void:
	SE.body_layer(k, keys, 14, 48, colf)


## Şort paçası: kalçadan uyluğa; iç yan (öbür bacağa bakan) daralır. colf(s, a) -> desen rengi. Döner: ek yarıçap ad(s, a)
static func _short_leg(k, le: Dictionary, col: Color, s1: float, base: float, flare: float, sv: float, colf := Callable(), lin := Color(0, 0, 0, 0)) -> Callable:
	var sg: float = le["sg"]
	var fo := func(s: float, a: float) -> float:
		return (0.003 + flare * 0.14) * P._lf(s, a, sv) * smoothstep(0.03, 0.14, s)
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var tp: float = 1.0 - 0.62 * smoothstep(s1 - 0.11, s1, s)   # paça ağzı uyluğa yaklaşır: koşuda kalkan bacakta boş halka görünmez
		return ((base + flare * smoothstep(0.0, s1, s)) * (1.0 - 0.45 * inn) + float(fo.call(s, a))) * tp
	var inner: Color = lin if lin.a > 0.0 else col.darkened(0.14)
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return inner
		var c0: Color = colf.call(float(s), float(a)) if colf.is_valid() else col
		return P._fs(c0, float(fo.call(float(s), float(a))), 10.0), 0.0, s1, 24, 26, 0.03)
	return ad


## Paça ucu kıvrımı (dikişli katlı kenar)
static func _hem_roll(k, le: Dictionary, ad: Callable, s1: float, col: Color, w := 0.028, add := 0.0025) -> void:
	P._lt(k, le, func(s, a): return float(ad.call(float(s), float(a))) + add, func(_s, _a, ins): return col.darkened(0.15) if ins else col, s1 - w, s1 + 0.002, 4, 26)


## Uzuv ağırlığı: noktanın uzuv eksenindeki yeri
static func _lsk(l: Dictionary, p: Vector3) -> Array:
	var p0: Vector3 = l["p0"]
	var p1: Vector3 = l["p1"]
	var p2: Vector3 = l["p2"]
	var kn: float = l["kn"]
	var t0 := clampf((p - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
	var t1 := clampf((p - p1).dot(p2 - p1) / (p2 - p1).length_squared(), 0.0, 1.0)
	var d0 := (p - p0.lerp(p1, t0)).length()
	var d1 := (p - p1.lerp(p2, t1)).length()
	return P._lskin(l, t0 * kn if d0 <= d1 else lerpf(kn, 1.0, t1))


## Uzuv kumaşı üstünde yerel eşleme: (u yatay metre, v yukarı metre, kalkış) -> konum
static func _lmap(l: Dictionary, ad: Callable, s0: float, a0: float) -> Callable:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var R: float = P._lr(l, s0) + float(ad.call(s0, a0))
	return func(u: float, v: float, lift: float) -> Vector3:
		var s: float = s0 - v / L
		var a: float = a0 + u / maxf(0.03, R)
		return Q._ls(l, s, a, float(ad.call(s, a)) + lift)[0]


static func _rot(mp: Callable, r: float, fl := 1.0) -> Callable:
	var c := cos(r)
	var s := sin(r)
	return func(u: float, v: float, l: float) -> Vector3: return mp.call((u * c - v * s) * fl, u * s + v * c, l)


static func _off(mp: Callable, du: float, dv: float) -> Callable:
	return func(u: float, v: float, l: float) -> Vector3: return mp.call(u + du, v + dv, l)


static func _out_of(mp: Callable) -> Vector3:
	return ((mp.call(0.0, 0.0, 0.01) as Vector3) - (mp.call(0.0, 0.0, 0.0) as Vector3)).normalized()


## Yüzeyde 2B yol boyunca kabartma şerit
static func _lstrip(k, mp: Callable, pts2: Array, hw: float, lift: float, d: float, col: Color, skinf: Callable, closed := false) -> void:
	var pts := []
	var ou := []
	for q in pts2:
		var p: Vector3 = mp.call(q.x, q.y, lift)
		var p0: Vector3 = mp.call(q.x, q.y, lift - 0.01)
		pts.append(p)
		ou.append((p - p0).normalized())
	k.strip(pts, ou, hw, d, col, closed, skinf)


static func _tri_r(th: float) -> float:
	return 0.5 / cos(fposmod(th, TAU / 3.0) - PI / 3.0)


static func _ell(th: float, ry: float) -> float:
	return ry / sqrt(pow(ry * cos(th), 2.0) + pow(sin(th), 2.0))


## Bağcık: bel bandındaki iki kuşgözünden sarkan iki ip + fiyonk ilmekleri
static func _drawstring(k, keys: Array, y: float, col: Color, len := 0.075) -> void:
	var hb := [["Hips", 1.0]]
	var sk := func(_p): return hb
	for sg in [1.0, -1.0]:
		var e0: Array = P._fp(keys, sg * 0.011, y, true, 0.006)
		P._stud(k, e0[0], e0[1], 0.0042, col.darkened(0.35), hb)
		var pts := []
		for i in 9:
			var t := float(i) / 8.0
			var x: float = sg * (0.011 + 0.012 * sin(t * 2.2) + 0.004 * t)
			pts.append(P._fp(keys, x, y - 0.004 - t * len, true, 0.0075)[0])
		P._cord(k, pts, 0.0024, col, false, sk, 0.0, 6)
		P._tb(k, [pts[7], pts[8], (pts[8] as Vector3) + Vector3(0, -0.009, 0)], func(_s, _a): return 0.0032, func(_s, _a, _p): return col.darkened(0.2), func(_s, _p): return hb, 6)
		var lp := []
		for i in 11:
			var th := TAU * i / 10.0
			lp.append(P._fp(keys, sg * (0.026 + 0.014 * cos(th)), y - 0.006 + 0.007 * sin(th), true, 0.0085)[0])
		P._cord(k, lp, 0.0022, col, true, sk, 0.0, 6)


## Şortun kalça kısmı + bel lastiği + bağcık; döner: kalça anahtarları
static func _short_top(k, b: Dictionary, colf: Callable, band: Color, cord: Color) -> Array:
	var sk: Array = _seat_keys(k, b)
	_seat(k, sk, colf)
	var y: float = k.H + 0.062
	P._sash(k, sk, y, 0.017, 0.007, band, 0.22)
	_drawstring(k, sk, y - 0.004, cord)
	return sk


# ------------------------------------------------------------------ şişme yelek (sahil setlerinin ortak kesimi)
## Önü açık, kolsuz; omuz boyunduruğu + yatay dolgu bölmeleri (gerçek kabarık, dikiş çukurunda koyulaşır), kabarık dik yaka.
## o: band(i) -> Color (i = -1 boyunduruk, 0..nb-1 bölmeler), inner, cin (yaka içi), trim, nb
static func _puffer(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var mid: Vector3 = k.M(C - 0.12, k.UA)
	var hem: float = H + 0.015
	var lo: Vector3 = k.M(hem, 0.3)
	var keys := [P._kp(nk, N + 0.012, 0.034), [N - 0.055, ch.x * 1.02 + 0.014, ch.y * 0.97 + 0.03, ch.z * 1.05 - 0.03], P._kp(ch, C - 0.03, 0.036), P._kp(mid, C - 0.12, 0.04), P._kp(wa, H + 0.12, 0.042), P._kp(lo, hem, 0.04)]
	var band: Callable = o["band"]
	var nb: int = o.get("nb", 4)
	var yb: float = C + 0.01
	var pitch: float = (yb - hem) / nb
	var top: float = N + 0.012
	var e_at := func(y: float) -> float: return lerpf(0.4, 0.6, smoothstep(C - 0.02, top, y))
	var pu := func(y: float) -> float:
		if y >= yb:
			return 0.55 * pow(sin(clampf((y - yb) / (top - yb), 0.0, 1.0) * PI), 0.7)
		return pow(sin(fposmod((yb - y) / pitch, 1.0) * PI), 0.55)
	var ff := func(a: float, y: float) -> float:
		var aw := absf(a)
		var fe: float = lerpf(0.4, 1.0, smoothstep(float(e_at.call(y)), float(e_at.call(y)) + 0.3, aw))
		var seam: float = 1.0 - 0.7 * exp(-pow((aw - 1.62) / 0.09, 2.0))
		return 0.13 * float(pu.call(y)) * fe * seam
	var tsk := func(p): return k.torso_skin(p.y)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 64, "na": 104, "rng": func(v):
		var e: float = e_at.call(lerpf(top, hem, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, y, _v):
			var yy := float(y)
			var i: int = -1 if yy >= yb else mini(nb - 1, int(floor((yb - yy) / pitch)))
			return (band.call(i) as Color).darkened((1.0 - float(pu.call(yy))) * 0.3), "gain": 3.0, "th": 0.014, "inner": o["inner"], "skin": tsk})
	var trim: Color = o["trim"]
	for ed in [cg["ea"], cg["eb"]]:
		P._cord(k, ed, 0.0055, trim, false, tsk)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.004, 0))
	P._cord(k, hm, 0.006, trim, false, tsk)
	# kol oyuğu biyesi
	for sd in ["Left", "Right"]:
		P._armhole(k, P._limb(k, sd, false), 0.07, 0.014, 0.0075, trim)
	# kabarık dik yaka: dışı yelek rengi, içi ayrı renk
	var q: float = Q._hq(k)
	var ck := [[N + 0.085 * q, nk.x + 0.048, nk.y + 0.044, nk.z - 0.05], [N + 0.03 * q, nk.x + 0.04, nk.y + 0.036, nk.z - 0.042], [N - 0.02, nk.x + 0.056, nk.y + 0.05, nk.z - 0.05]]
	var yc: Color = band.call(-1)
	var cc: Dictionary = P._cl(k, {"keys": ck, "ny": 12, "na": 52, "rng": func(_v): return Vector2(0.55, TAU - 0.55), "top": func(a): return N + q * lerpf(0.07, 0.085, smoothstep(0.6, 2.0, absf(float(a)))),
		"hem": func(_a): return N - 0.016, "fold": func(_a, _y, v): return 0.07 * pow(sin(float(v) * PI), 0.6), "col": func(_a, _y, v): return yc.darkened(0.2 * (1.0 - pow(sin(float(v) * PI), 0.6))),
		"inner": o["cin"], "skin": func(p): return Q._nsk(k, p), "th": 0.01, "gain": 3.0})
	P._cord(k, cc["top"], 0.0055, o["cin"], false, func(p): return Q._nsk(k, p))
	return {"keys": keys, "ff": func(a, y): return ff.call(float(a), float(y)), "yb": yb, "pitch": pitch, "hem": hem, "e": e_at}


# ------------------------------------------------------------------ desen parçaları (her biri gerçek kabartma)
## Hibiskus: beş yapraklı taç, mor kenar halkası, koyu göbek ve sarı başçıklı erkek organ
static func _hibiscus(k, mp: Callable, s: float, rot: float, skinf: Callable) -> void:
	var lil := Color(0.88, 0.8, 0.94)
	var pur := Color(0.6, 0.38, 0.7)
	var mg := Color(0.72, 0.22, 0.5)
	var m2: Callable = _rot(mp, rot)
	var o := _out_of(mp)
	var pr := func(th): return 0.6 + 0.4 * pow(absf(cos(2.5 * float(th))), 0.6)
	Q._disc(k, m2, o, s, 0.003, pr, func(u, v):
		var r := Vector2(float(u), float(v)).length()
		return pur if r > 0.86 else (lil.darkened(0.08) if r < 0.4 else lil), skinf, 4, 40)
	var rim := []
	for i in 40:
		var th := TAU * i / 40.0
		var r: float = s * float(pr.call(th)) * 0.93
		rim.append(Vector2(cos(th) * r, sin(th) * r))
	_lstrip(k, m2, rim, 0.0016, 0.0042, 0.001, pur, skinf, true)
	Q._disc(k, m2, o, s * 0.22, 0.0052, Callable(), func(_u, _v): return mg, skinf, 2, 12)
	var tip: Vector3 = m2.call(s * 0.5, s * 0.25, 0.0062)
	_lstrip(k, m2, [Vector2(0.0, 0.0), Vector2(s * 0.5, s * 0.25)], 0.0012, 0.0058, 0.0008, mg.lightened(0.2), skinf)
	P._stud(k, tip, o, 0.0028, Color(0.98, 0.84, 0.3), skinf.call(tip))


## Monstera yaprağı: tırtıklı kenar, açık yeşil orta damar ve yan damarlar
static func _leaf(k, mp: Callable, s: float, rot: float, skinf: Callable) -> void:
	var gr := Color(0.18, 0.6, 0.3)
	var lg := Color(0.55, 0.85, 0.5)
	var m2: Callable = _rot(mp, rot)
	Q._disc(k, m2, _out_of(mp), s, 0.0028, func(th):
		var t := float(th)
		return _ell(t, 0.62) * (0.86 + 0.14 * absf(cos(t * 6.0))), func(u, v): return gr.darkened(0.12) if Vector2(float(u), float(v)).length() > 0.88 else gr, skinf, 4, 36)
	_lstrip(k, m2, [Vector2(-s * 0.85, 0.0), Vector2(0.0, s * 0.03), Vector2(s * 0.85, 0.0)], 0.0017, 0.0042, 0.001, lg, skinf)
	for sg in [1.0, -1.0]:
		for x in [-0.4, 0.0, 0.4]:
			_lstrip(k, m2, [Vector2(s * x, sg * s * 0.04), Vector2(s * (x + 0.22), sg * s * 0.42)], 0.0012, 0.0041, 0.0008, lg, skinf)


static func _star(k, mp: Callable, s: float, rot: float, col: Color, skinf: Callable) -> void:
	Q._disc(k, _rot(mp, rot), _out_of(mp), s, 0.0032, func(th): return 0.42 + 0.58 * pow(absf(cos(2.5 * float(th))), 4.0), func(_u, _v): return col, skinf, 2, 30)


## Karpuz dilimi: kırmızı üçgen, kalın yeşil kabuk şeridi, siyah çekirdekler
static func _melon(k, mp: Callable, s: float, rot: float, skinf: Callable) -> void:
	var rd := Color(0.86, 0.2, 0.2)
	var gr := Color(0.2, 0.55, 0.3)
	var m2: Callable = _rot(mp, rot)
	var o := _out_of(mp)
	Q._disc(k, m2, o, s, 0.0032, func(th): return _tri_r(float(th) + PI * 0.5), func(_u, _v): return rd, skinf, 3, 30)
	var a0 := Vector2(cos(PI / 6.0), sin(PI / 6.0)) * s
	var a1 := Vector2(-cos(PI / 6.0), sin(PI / 6.0)) * s
	_lstrip(k, m2, [a0 * 1.02, a1 * 1.02], 0.0035, 0.0034, 0.002, gr, skinf)
	for q in [Vector2(-0.18, 0.08), Vector2(0.16, 0.12), Vector2(0.0, -0.18)]:
		var p: Vector3 = m2.call(q.x * s, q.y * s, 0.0052)
		P._stud(k, p, o, 0.0016, Color(0.08, 0.06, 0.06), skinf.call(p))


## Balık: gövde, kuyruk yelpazesi, göz
static func _fish(k, mp: Callable, s: float, fl: float, col: Color, eye: Color, skinf: Callable, lift := 0.004) -> void:
	var m2: Callable = _rot(mp, 0.0, fl)
	var o := _out_of(mp)
	Q._disc(k, m2, o, s, lift, func(th): return _ell(float(th), 0.52), func(_u, _v): return col, skinf, 3, 22)
	Q._disc(k, _off(m2, -s * 1.15, 0.0), o, s * 0.55, lift, func(th): return _tri_r(float(th)), func(_u, _v): return col, skinf, 2, 15)
	var ep: Vector3 = m2.call(s * 0.5, s * 0.12, lift + 0.0016)
	P._stud(k, ep, o, s * 0.13, eye, skinf.call(ep))
	_lstrip(k, m2, [Vector2(s * 0.15, s * 0.42), Vector2(s * 0.25, 0.0), Vector2(s * 0.15, -s * 0.42)], 0.0011, lift + 0.0016, 0.0008, eye, skinf)


## Flamingo: gövde + kanat, S boyun, baş, gaga, biri bükük iki ince bacak
static func _flamingo_m(k, mp: Callable, s: float, fl: float, skinf: Callable) -> void:
	var pk := Color(0.94, 0.45, 0.58)
	var pw := Color(0.86, 0.36, 0.5)
	var gy := Color(0.42, 0.42, 0.46)
	var bk := Color(0.12, 0.1, 0.12)
	var m2: Callable = _rot(mp, 0.0, fl)
	var o := _out_of(mp)
	Q._disc(k, m2, o, s, 0.0034, func(th):
		var t := float(th)
		return _ell(t, 0.52) * (1.0 + 0.4 * pow(maxf(0.0, -cos(t)), 6.0)), func(_u, _v): return pk, skinf, 3, 24)
	Q._disc(k, _off(m2, -s * 0.12, s * 0.06), o, s * 0.62, 0.0049, func(th): return _ell(float(th), 0.45), func(_u, _v): return pw, skinf, 2, 16)
	var nk := [Vector2(0.72, 0.18), Vector2(0.98, 0.55), Vector2(0.8, 0.95), Vector2(0.62, 1.35), Vector2(0.76, 1.68), Vector2(0.98, 1.74)]
	var np := []
	for q in nk:
		np.append(q * s)
	_lstrip(k, m2, np, s * 0.11, 0.0038, 0.0016, pk, skinf)
	Q._disc(k, _off(m2, s * 1.0, s * 1.74), o, s * 0.2, 0.0046, Callable(), func(_u, _v): return pk, skinf, 2, 10)
	_lstrip(k, m2, [Vector2(s * 1.16, s * 1.76), Vector2(s * 1.34, s * 1.58)], s * 0.06, 0.0048, 0.0012, bk, skinf)
	_lstrip(k, m2, [Vector2(s * 0.12, -s * 0.42), Vector2(s * 0.1, -s * 2.1)], 0.0011, 0.0036, 0.0008, gy, skinf)
	_lstrip(k, m2, [Vector2(-s * 0.06, -s * 0.42), Vector2(-s * 0.05, -s * 1.15), Vector2(s * 0.42, -s * 0.95)], 0.0011, 0.0036, 0.0008, gy, skinf)


# ------------------------------------------------------------------ Sahil Striker (ref Shinobi Striker "Beach Striker" Beach_1): çıplak gövde, önü açık turuncu şişme yelek, bağcıklı koyu yeşil şort
static func _sahil(k) -> void:
	var og := Color(0.941, 0.541, 0.165)
	var ro := Color(0.82, 0.32, 0.16)
	var gr := Color(0.118, 0.227, 0.157)
	var b: Dictionary = P._base(k)
	_bare_torso(k, b, k.H + 0.03, true)
	_bare_limbs(k, true, true)
	var sk: Array = _short_top(k, b, func(_i, _j, _p): return gr, gr.lightened(0.04), Color(0.88, 0.9, 0.86))
	_shorts_detail(k, sk, gr.darkened(0.3))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var s1 := 0.36
		var ad: Callable = _short_leg(k, le, gr, s1, 0.02, 0.011, 1.3 if sd == "Left" else 2.5)
		_hem_roll(k, le, ad, s1, gr.darkened(0.1))
		_side_seam(k, le, ad, s1, gr.darkened(0.35))
	_puffer(k, b, {"band": func(_i): return og, "inner": ro.darkened(0.2), "cin": ro, "trim": og.lightened(0.12)})


## Şort önü: çapraz cep ağızları (kalça yüzeyinde dikişli şerit)
static func _shorts_detail(k, sk: Array, col: Color) -> void:
	var H: float = k.H
	for sg in [1.0, -1.0]:
		P._strap(k, sk, [Vector2(sg * 0.075, H + 0.045), Vector2(sg * 0.1, H + 0.0), Vector2(sg * 0.125, H - 0.045)], true, 0.0032, 0.003, 0.0018, col, 6, func(_p): return [["Hips", 1.0]])


## Paça dış yan dikişi
static func _side_seam(k, le: Dictionary, ad: Callable, s1: float, col: Color) -> void:
	var a: float = float(le["sg"]) * PI * 0.5
	var pts := []
	var ou := []
	for i in 13:
		var s: float = lerpf(0.02, s1 - 0.03, float(i) / 12.0)
		var e: Array = Q._ls(le, s, a, float(ad.call(s, a)) + 0.0012)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, 0.0028, 0.0012, col, false, func(p): return _lsk(le, p))


# ------------------------------------------------------------------ Sahil Striker: Hibiskus (ref Beach_2): açık mavi yelek (alt bölmesi daha açık, beyaz yaka içi ve biye), beyaz şortta hibiskus, monstera yaprağı, altın yıldız
static func _hibiskus(k) -> void:
	var bl := Color(0.29, 0.753, 0.91)
	var pb := Color(0.62, 0.88, 0.95)
	var wh := Color(0.949, 0.949, 0.933)
	var gd := Color(0.95, 0.8, 0.32)
	var b: Dictionary = P._base(k)
	var H: float = k.H
	_bare_torso(k, b, H + 0.03, true)
	_bare_limbs(k, true, true)
	var sk: Array = _short_top(k, b, func(_i, _j, _p): return wh, wh.darkened(0.03), bl)
	_shorts_detail(k, sk, wh.darkened(0.2))
	var hsk := func(_p): return [["Hips", 1.0]]
	# kalçada: önde çiçek + yaprak, arkada çiçek + yaprak + yıldız
	var nf := func(_a, _y): return 0.0
	for e in [[0.62, H - 0.02, 0], [-0.7, H - 0.0, 1], [0.35, H + 0.02, 2], [PI - 0.5, H - 0.03, 0], [-PI + 0.55, H - 0.01, 1], [PI, H + 0.015, 2], [-1.25, H - 0.06, 2]]:
		var mp: Callable = Q._local(sk, nf, float(e[0]), float(e[1]))
		match int(e[2]):
			0: _hibiscus(k, mp, 0.042, 0.4, hsk)
			1: _leaf(k, mp, 0.046, -0.5, hsk)
			_: _star(k, mp, 0.01, 0.2, gd, hsk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = le["sg"]
		var s1 := 0.36
		var ad: Callable = _short_leg(k, le, wh, s1, 0.02, 0.011, 0.8 if sd == "Left" else 1.9)
		_hem_roll(k, le, ad, s1, wh.darkened(0.06))
		var lsk := func(p): return _lsk(le, p)
		var mot := [[0.12, 0.3, 0], [0.27, -0.55, 1], [0.1, 1.55, 1], [0.26, 1.15, 0], [0.13, 2.7, 0], [0.28, 2.25, 1], [0.12, -1.7, 0], [0.27, -1.9, 1], [0.08, -0.9, 2], [0.3, 0.35, 2], [0.2, 3.1, 2], [0.2, -2.6, 2]]
		for e in mot:
			var s: float = float(e[0])
			var a: float = sg * float(e[1])
			var mp: Callable = _lmap(le, ad, s, a)
			match int(e[2]):
				0: _hibiscus(k, mp, 0.04, a * 1.7, lsk)
				1: _leaf(k, mp, 0.045, 0.6 + a, lsk)
				_: _star(k, mp, 0.011, a, gd, lsk)
	_puffer(k, b, {"band": func(i): return pb if int(i) == 3 else bl, "inner": bl.darkened(0.3), "cin": wh, "trim": wh.darkened(0.04)})


# ------------------------------------------------------------------ Sahil Striker: Denizci (ref Beach_3): mavi omuz boyunduruğu (beyaz ok işaretleri), beyaz-kırmızı-beyaz-mavi bölmeli yelek, mavi bölmede balıklı cepler, sırtta çapa,
## mavi kabarık şeritli beyaz şort
static func _denizci(k) -> void:
	var wh := Color(0.949, 0.949, 0.949)
	var rd := Color(0.847, 0.157, 0.157)
	var nv := Color(0.14, 0.24, 0.66)
	var lb := Color(0.478, 0.753, 0.91)
	var b: Dictionary = P._base(k)
	var H: float = k.H
	_bare_torso(k, b, H + 0.03, true)
	_bare_limbs(k, true, true)
	var sk: Array = _short_top(k, b, func(_i, _j, _p): return wh, wh.darkened(0.03), Color(0.3, 0.32, 0.4))
	var hsk := func(_p): return [["Hips", 1.0]]
	# kalça şeritleri: belden uyluğa dikey kabartma
	for i in 14:
		var a: float = -PI + TAU * (float(i) + 0.5) / 14.0
		Q._run(k, sk, Callable(), [Vector2(a, H + 0.045), Vector2(a, H - 0.14)], 0.011, 0.0035, 0.0018, lb, hsk, 8)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var s1 := 0.37
		var ad: Callable = _short_leg(k, le, wh, s1, 0.02, 0.011, 1.1 if sd == "Left" else 2.2)
		for j in 10:
			var a: float = -PI + TAU * (float(j) + 0.25) / 10.0
			var pts := []
			var ou := []
			for i in 11:
				var s: float = lerpf(0.0, s1 - 0.01, float(i) / 10.0)
				var e: Array = Q._ls(le, s, a, float(ad.call(s, a)) + 0.0015)
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, 0.011, 0.0018, lb, false, func(p): return _lsk(le, p))
		_hem_roll(k, le, ad, s1, wh.darkened(0.05), 0.022, 0.004)
	var pf: Dictionary = _puffer(k, b, {"band": func(i):
		match int(i):
			-1: return nv
			1: return rd
			3: return nv
		return wh, "inner": nv.darkened(0.2), "cin": wh, "trim": wh.darkened(0.03)})
	var keys: Array = pf["keys"]
	var ff: Callable = pf["ff"]
	var yb: float = pf["yb"]
	var pt: float = pf["pitch"]
	var tsk := func(p): return k.torso_skin(p.y)
	# omuz boyunduruğunda beyaz ok işaretleri
	for sg in [1.0, -1.0]:
		for j in 3:
			var a: float = sg * (1.0 + 0.11 * j)
			var y: float = k.N - 0.035
			Q._run(k, keys, ff, [Vector2(a - sg * 0.07, y + 0.014), Vector2(a, y), Vector2(a - sg * 0.07, y - 0.014)], 0.0028, 0.004, 0.0014, wh, tsk, 3)
	# mavi bölmede balıklı cepler (önde iki yan)
	var yc: float = yb - pt * 3.5
	for sg in [1.0, -1.0]:
		var a0: float = sg * 0.95
		Q._pocket(k, keys, ff, a0, yc, 0.1, pt * 0.86, nv.lightened(0.06), tsk)
		var mp: Callable = Q._local(keys, ff, a0, yc - 0.004)
		var lm := func(u, v, l): return mp.call(u, v, float(l) + 0.006)
		_fish(k, _off(lm, sg * 0.016, -0.004), 0.016, sg, wh, nv, tsk, 0.004)
		_fish(k, _off(lm, -sg * 0.03, 0.014), 0.01, -sg, wh, nv, tsk, 0.004)
	# sırtta çapa (kırmızı bölmenin üstünde lacivert)
	var ya: float = yb - pt * 1.5
	var mb: Callable = Q._local(keys, ff, PI, ya)
	var ab := func(u, v, l): return mb.call(u, v, float(l) + 0.004)
	_lstrip(k, ab, [Vector2(0.0, 0.05), Vector2(0.0, -0.055)], 0.0045, 0.002, 0.002, nv, tsk)
	_lstrip(k, ab, [Vector2(-0.03, 0.03), Vector2(0.03, 0.03)], 0.004, 0.002, 0.002, nv, tsk)
	Q._circle(k, _off(ab, 0.0, 0.062), 0.011, 0.0032, 0.002, nv, tsk, 24)
	var arc := []
	for i in 13:
		var t: float = lerpf(-1.25, 1.25, float(i) / 12.0)
		arc.append(Vector2(sin(t) * 0.045, -0.055 + (1.0 - cos(t)) * 0.045))
	_lstrip(k, ab, arc, 0.004, 0.002, 0.002, nv, tsk)
	for sg in [1.0, -1.0]:
		Q._disc(k, _rot(_off(ab, sg * 0.043, -0.016), sg * 0.5), _out_of(ab), 0.011, 0.0025, func(th): return _tri_r(float(th) + PI * 0.5), func(_u, _v): return nv, tsk, 2, 15)


# ------------------------------------------------------------------ Sahil Striker: Gök Mavisi (ref Sky_Blue): sarı-beyaz-sarı kapüşonlu kolsuz yelek (dolgusuz), lacivert bel / gök mavisi / beyaz bulut katmanlı şort,
## camgöbeği paça bandı ve yan cepler, karpuz dilimleri
static func _gok(k) -> void:
	var ye := Color(0.973, 0.816, 0.157)
	var wh := Color(0.957, 0.957, 0.949)
	var nv := Color(0.14, 0.16, 0.36)
	var sky := Color(0.2, 0.55, 0.88)
	var tl := Color(0.227, 0.753, 0.69)
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var b: Dictionary = P._base(k)
	_bare_torso(k, b, H + 0.03, true)
	_bare_limbs(k, true, true)
	var sk: Array = _short_top(k, b, func(_i, _j, _p): return nv, wh, tl)
	var hsk := func(_p): return [["Hips", 1.0]]
	for e in [[0.55, H - 0.04], [-0.45, H + 0.0], [PI - 0.6, H - 0.02], [-PI + 0.4, H - 0.06], [1.3, H + 0.01]]:
		_melon(k, Q._local(sk, Callable(), float(e[0]), float(e[1])), 0.023, float(e[0]) * 2.0, hsk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = le["sg"]
		var sv: float = 0.7 if sd == "Left" else 2.0
		var s1 := 0.36
		var ad: Callable = _short_leg(k, le, nv, s1, 0.02, 0.011, sv, Callable(), wh.darkened(0.12))
		# gök katmanı: düzensiz üst kenar
		P._lts(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.0025, func(_s, a, ins): return sky.darkened(0.35) if ins else sky.darkened(0.08 * float(sin(float(a) * 5.0 + sv) > 0.6)),
			func(a): return 0.06 + 0.025 * sin(float(a) * 3.0 + sv) + 0.012 * sin(float(a) * 7.0), s1, 14, 30)
		# bulut katmanı: kabarık yuvarlak tepeler
		P._lts(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.0048, func(_s, _a, ins): return wh.darkened(0.12) if ins else wh,
			func(a): return 0.2 - 0.045 * pow(absf(sin(float(a) * 2.5 + sv)), 0.6), s1, 10, 34)
		# camgöbeği paça bandı
		P._lt(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.0072, func(_s, a, ins): return wh.darkened(0.12) if ins else tl.darkened(0.1 * float(sin(float(a) * 9.0) > 0.7)), s1 - 0.035, s1 + 0.002, 4, 30, 0.02)
		# yan cep: beyaz kutu, camgöbeği kapak
		var a0: float = sg * PI * 0.5
		var cs := 0.25
		var e0: Array = Q._ls(le, cs, a0, float(ad.call(cs, a0)) + 0.0145)
		var d: Vector3 = P._ld(le, cs)
		var o: Vector3 = e0[1]
		var ux: Vector3 = o.cross(d).normalized()
		var bo: Array = P._lskin(le, cs)
		P._boxr(k, e0[0], ux * 0.038, -d * 0.045, o * 0.01, wh.darkened(0.03), bo, 0.35)
		P._boxr(k, (e0[0] as Vector3) - d * 0.032 + o * 0.004, ux * 0.04, -d * 0.012, o * 0.008, tl, bo, 0.4)
		var lsk := func(p): return _lsk(le, p)
		for e in [[0.1, 0.2], [0.17, -0.8], [0.27, 0.6], [0.3, -0.25], [0.14, 2.4], [0.26, 2.0], [0.22, -2.6], [0.08, -1.6]]:
			var s: float = float(e[0])
			var a: float = sg * float(e[1])
			var lay: float = 0.0048 if s > 0.2 else (0.0025 if s > 0.08 else 0.0)
			_melon(k, _lmap(le, func(s2, a2): return float(ad.call(float(s2), float(a2))) + lay, s, a), 0.022, a * 2.3 + s * 9.0, lsk)
	# yelek: dolgusuz kumaş, renk blokları ayrı panel (aralarında dikiş biyesi)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var mid: Vector3 = k.M(C - 0.12, k.UA)
	var hem: float = H + 0.015
	var lo: Vector3 = k.M(hem, 0.3)
	var keys := [P._kp(nk, N + 0.012, 0.026), [N - 0.055, ch.x * 1.02 + 0.008, ch.y * 0.97 + 0.02, ch.z * 1.05 - 0.02], P._kp(ch, C - 0.03, 0.022), P._kp(mid, C - 0.12, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(lo, hem, 0.03)]
	var top: float = N + 0.012
	var e_at := func(y: float) -> float: return lerpf(0.4, 0.62, smoothstep(C - 0.02, top, y))
	var y1: float = C - 0.05
	var y2: float = H + 0.06
	var ff := func(a: float, y: float) -> float:
		var aw := absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.4, 0.8, aw) * (t * (0.02 * sin(a * 6.0 + 0.4) + 0.008 * sin(a * 13.0 + 1.2)) + (1.0 - t) * 0.006 * sin(a * 4.0 + y * 20.0))
	var tsk := func(p): return k.torso_skin(p.y)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 46, "na": 92, "rng": func(v):
		var e: float = e_at.call(lerpf(top, hem, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, y, _v): return ye if float(y) > y1 or float(y) < y2 else wh, "gain": 6.0, "th": 0.008, "inner": wh.darkened(0.2), "skin": tsk})
	var fv := func(a, y): return ff.call(float(a), float(y))
	for yy in [y1, y2]:
		var e: float = e_at.call(yy)
		Q._run(k, keys, fv, [Vector2(e + 0.02, yy), Vector2(PI, yy), Vector2(TAU - e - 0.02, yy)], 0.0035, 0.002, 0.0018, ye.darkened(0.12), tsk, 18)
	for ed in [cg["ea"], cg["eb"]]:
		P._cord(k, ed, 0.0042, ye.darkened(0.05), false, tsk)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.004, 0))
	P._cord(k, hm, 0.0042, ye.darkened(0.12), false, tsk)
	for sd in ["Left", "Right"]:
		P._armhole(k, P._limb(k, sd, false), 0.07, 0.008, 0.006, ye)
	# yan cep ağzı (beyaz panelde verev fileto)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, fv, [Vector2(sg * 0.75, H + 0.17), Vector2(sg * 1.0, H + 0.09)], 0.005, 0.003, 0.0022, wh.darkened(0.14), tsk, 5)
	# kapüşon: boyunda bol halka + sırta düşmüş torba, içi beyaz
	var q: float = Q._hq(k)
	var hk := [[N + 0.12 * q, nk.x + 0.075, nk.y + 0.05, nk.z - 0.09], [N + 0.05 * q, nk.x + 0.062, nk.y + 0.05, nk.z - 0.075], [N - 0.0, nk.x + 0.066, nk.y + 0.055, nk.z - 0.066], [N - 0.06, ch.x * 0.8, ch.y * 0.86, ch.z * 0.95]]
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 16, "na": 64, "rng": func(_v): return Vector2(0.45, TAU - 0.45), "top": func(a): return N + q * lerpf(0.05, 0.11, smoothstep(0.5, 2.2, absf(float(a)))),
		"hem": func(a): return N - 0.045 - 0.02 * smoothstep(1.0, 2.6, absf(float(a))), "fold": func(a, _y, v): return 0.05 * sin(float(v) * PI * 2.0 + cos(float(a)) * 1.1) * smoothstep(0.0, 0.25, float(v)) * (1.0 - float(v) * 0.6),
		"col": func(_a, _y, _v): return ye, "gain": 6.0, "inner": wh, "skin": func(p): return Q._nsk(k, p), "th": 0.007})
	P._cord(k, hg["top"], 0.0045, wh, false, func(p): return Q._nsk(k, p))
	var sk2 := []
	for e2 in keys:
		sk2.append([e2[0], float(e2[1]) + 0.01, float(e2[2]) + 0.01, float(e2[3]) - 0.012])
	var bg: Dictionary = P._cl(k, {"keys": sk2, "ny": 14, "na": 36, "rng": func(_v): return Vector2(PI - 1.0, PI + 1.0), "top": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return N + 0.03 - 0.07 * db * db, "hem": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return C - 0.08 + 0.11 * pow(db, 1.6), "fold": func(a, _y, v):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return 0.1 * sin(float(v) * PI) * (1.0 - db * db) + 0.01 * sin(float(a) * 7.0 + 0.3) * float(v), "col": func(_a, _y, _v): return ye, "gain": 5.0, "inner": wh, "skin": tsk, "th": 0.006})
	P._cord(k, bg["hem"], 0.0042, ye.darkened(0.1), false, tsk)


# ------------------------------------------------------------------ Sahil Striker: Flamingo (ref Flamingo): omzu açık straplez beyaz elbise (flamingo kabartmalı), kolları ve göğüs üstünü saran çizgili pembe bant,
## önü yarık kloş üst etek, altında üç kat fırfırlı kırmızı-pembe etek, beyaz kısa şort
static func _flamingo(k) -> void:
	var wh := Color(0.957, 0.949, 0.949)
	var pk := Color(0.941, 0.416, 0.541)
	var dr := Color(0.6, 0.1, 0.16)
	var rd := Color(0.86, 0.28, 0.36)
	var lp := Color(0.96, 0.66, 0.74)
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	_bare_torso(k, b, C - 0.1, false)
	_bare_limbs(k, true, true)
	# beyaz kısa şort
	var sk: Array = _seat_keys(k, b)
	_seat(k, sk, func(_i, _j, _p): return wh.darkened(0.04))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ad: Callable = _short_leg(k, le, wh.darkened(0.04), 0.09, 0.012, 0.004, 1.0)
		_hem_roll(k, le, ad, 0.09, wh.darkened(0.1), 0.015, 0.002)
	# korsaj: kalp yaka, bele oturur
	var tm: Vector3 = k.M(C + 0.05, k.UA)
	var mid: Vector3 = k.M(C - 0.12, k.UA)
	var lo: Vector3 = k.M(H + 0.02, 0.3)
	var bk := [P._kp(tm, C + 0.07, 0.008), P._kp(ch, C - 0.03, 0.009), P._kp(mid, C - 0.12, 0.008), P._kp(wa, H + 0.12, 0.008), P._kp(lo, H + 0.02, 0.012)]
	var b_top := func(a: float) -> float:
		var aw := absf(a)
		return C + 0.045 - 0.032 * exp(-pow(a / 0.11, 2.0)) + 0.01 * exp(-pow((aw - 0.42) / 0.2, 2.0)) - 0.012 * smoothstep(1.0, 2.0, aw)
	var bff := func(a: float, _y: float) -> float: return 0.006 * sin(a * 6.0 + 0.5)
	var tsk := func(p): return k.torso_skin(p.y)
	var bg: Dictionary = P._cl(k, {"keys": bk, "ny": 28, "na": 76, "top": func(a): return b_top.call(float(a)), "hem": func(_a): return H + 0.02,
		"fold": func(a, y, _v): return bff.call(float(a), float(y)), "col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.005, "inner": wh.darkened(0.25), "skin": tsk})
	P._cord(k, bg["top"], 0.0032, wh.darkened(0.08), true, tsk)
	var bfv := func(a, y): return bff.call(float(a), float(y))
	for e in [[0.34, C - 0.03, 1.0, 1.0], [-0.4, C - 0.05, -1.0, 0.95], [0.05, C - 0.15, -1.0, 1.0], [-0.62, C - 0.19, 1.0, 0.9], [0.66, C - 0.2, -1.0, 0.9],
			[PI - 0.4, C - 0.05, 1.0, 1.0], [-PI + 0.45, C - 0.12, -1.0, 1.0], [PI, H + 0.09, 1.0, 0.95]]:
		var mp: Callable = Q._local(bk, bfv, float(e[0]), float(e[1]))
		_flamingo_m(k, mp, 0.016 * float(e[3]), float(e[2]), tsk)
	# fırfırlı alt etek: üç kat, aşağı doğru genişler, kenarı dalgalı
	var dsk := func(p): return k.cloth_skin(p, H - 0.13, 0.5)
	var tiers := [[H + 0.04, H - 0.075, dr, 0.05, 1.1], [H - 0.03, H - 0.105, rd, 0.075, 2.3], [H - 0.065, H - 0.13, lp, 0.095, 0.4]]
	for i in 3:
		var t: Array = tiers[i]
		var y0: float = t[0]
		var y1: float = t[1]
		var fl: float = t[3]
		var sv: float = t[4]
		var tk := [P._kp(wa, y0 + 0.01, 0.012 + 0.006 * i), P._kp(lo, minf(y0 - 0.02, H + 0.0), 0.024 + 0.01 * i), [y1, hp.x + fl, hp.y + fl * 0.85, hp.z - fl * 0.85]]
		var rf := func(a: float, y: float, v: float) -> float:
			var g: float = smoothstep(0.15, 1.0, float(v))
			return g * (0.05 * sin(a * 13.0 + sv) + 0.022 * sin(a * 23.0 + sv * 2.0)) + (1.0 - g) * 0.012 * sin(a * 26.0)
		var col: Color = t[2]
		var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 10, "na": 96, "top": func(_a): return y0, "hem": func(a): return y1 + 0.008 * absf(sin(float(a) * 6.5 + sv)),
			"fold": rf, "col": func(_a, _y, _v): return col, "gain": 5.0, "th": 0.004, "inner": col.darkened(0.3), "skin": dsk})
		P._cord(k, tg["hem"], 0.0026, col.lightened(0.12), true, dsk)
	# üst etek: belden kloş, önü ters V yarık
	var oh: float = H - 0.06
	var ok := [P._kp(wa, H + 0.09, 0.014), P._kp(lo, H + 0.0, 0.042), [oh, hp.x + 0.085, hp.y + 0.075, hp.z - 0.075]]
	var orf := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.06 - y) / (H + 0.06 - oh), 0.0, 1.0)
		return t * (0.035 * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9))
	var orng := func(v) -> Vector2:
		var e: float = 0.03 + 0.36 * pow(smoothstep(0.1, 1.0, float(v)), 1.2)
		return Vector2(e, TAU - e)
	var og: Dictionary = P._cl(k, {"keys": ok, "ny": 16, "na": 84, "rng": orng, "top": func(_a): return H + 0.09, "hem": func(a): return oh + 0.012 * sin(float(a) * 4.0),
		"fold": func(a, y, _v): return orf.call(float(a), float(y)), "col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.005, "inner": wh.darkened(0.2), "skin": dsk})
	for ed in [og["ea"], og["eb"]]:
		P._cord(k, ed, 0.0025, wh.darkened(0.1), false, dsk)
	P._cord(k, og["hem"], 0.0025, wh.darkened(0.12), false, dsk)
	P._sash(k, ok, H + 0.085, 0.008, 0.004, wh.darkened(0.04), 0.1)
	var ofv := func(a, y): return orf.call(float(a), float(y))
	for e in [[0.8, H - 0.0, 1.0], [-0.85, H - 0.01, -1.0], [1.6, H - 0.03, 1.0], [-1.7, H + 0.0, -1.0], [2.5, H - 0.01, -1.0], [-2.55, H - 0.03, 1.0]]:
		_flamingo_m(k, Q._local(ok, ofv, float(e[0]), float(e[1])), 0.014, float(e[2]), dsk)
	# omzu açık bant: göğüs üstünde kalp yakaya inen kısım + iki üst kolu saran halkalar, beyaz çizgiler kabartma
	var tk2 := [P._kp(tm, C + 0.1, 0.014), P._kp(tm, C + 0.05, 0.016), P._kp(ch, C - 0.0, 0.018)]
	var bt := func(a: float) -> float: return C + 0.088 - 0.042 * exp(-pow(a / 0.3, 2.0))
	var bh := 0.042
	var bnd: Dictionary = P._cl(k, {"keys": tk2, "ny": 8, "na": 80, "top": func(a): return bt.call(float(a)), "hem": func(a): return float(bt.call(float(a))) - bh,
		"fold": func(_a, _y, v): return 0.02 * sin(float(v) * PI), "col": func(_a, _y, _v): return pk, "gain": 4.0, "th": 0.006, "inner": pk.darkened(0.3), "skin": tsk})
	for f in [0.33, 0.66]:
		var pts := []
		for i in 80:
			var a := TAU * i / 80.0 - PI
			pts.append(Vector2(a, float(bt.call(a)) - bh * f))
		pts.append(pts[0])
		Q._run(k, tk2, func(_a, _y): return 0.02 * sin(f * PI), pts, 0.0042, 0.0026, 0.0015, wh, tsk, 1)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var aad := func(s, a): return 0.0075 + 0.0035 * sin(clampf((float(s) - 0.05) / 0.2, 0.0, 1.0) * PI) + 0.001 * sin(float(a) * 5.0)
		P._lt(k, ar, aad, func(_s, _a, ins): return pk.darkened(0.3) if ins else pk, 0.05, 0.25, 10, 22, 0.015)
		for s in [0.115, 0.185]:
			Q._ring_on(k, ar, s, aad, 0.0042, wh, 0.0022)
	P._cur_hem = H - 0.13


# ------------------------------------------------------------------ Kuro Ressha (ref Shinobi Striker "Boruto Outfit" Boruto_1): biyeli beyaz tişört, önü açık siyah eşofman ceketi (içi pembe dik yaka, kolda pembe şerit, sırtta girdap,
## lastikli etek ve manşet), siyah kemer, bota sokulup baldırda toplanan siyah eşofman altı, sağ uylukta sargı + lacivert kılıf
static func _esofman(k) -> void:
	var bk := Color(0.094, 0.094, 0.11)
	var pk := Color(0.847, 0.29, 0.416)
	var wh := Color(0.949, 0.949, 0.949)
	var mt := Color(0.6, 0.61, 0.64)
	var nv := Color(0.12, 0.15, 0.32)
	var bw := Color(0.92, 0.91, 0.88)
	var N: float = k.N
	var C: float = k.C
	var H: float = k.H
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	# tişört + siyah yaka biyesi
	var ik: Array = P._inner(k, b, func(_i, j, _p): return wh.darkened(0.04) if j % 9 == 4 else wh, 0.006, H + 0.05)
	var nr := []
	for i in 44:
		nr.append(Q._spt(ik, Callable(), TAU * i / 44.0 - PI, N + 0.03, 0.003)[0])
	P._cord(k, nr, 0.0055, bk.lightened(0.06), true, func(p): return Q._nsk(k, p))
	# eşofman altı
	var sk: Array = _seat_keys(k, b)
	_seat(k, sk, func(_i, _j, _p): return bk)
	P._sash(k, sk, H + 0.062, 0.016, 0.008, Color(0.16, 0.16, 0.18), 0.12)
	_shorts_detail(k, sk, bk.lightened(0.1))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.6 if sd == "Left" else 0.5
		var pa: Callable = K._pant(k, le, bk, 0.013, 0.016, 1.0, sv)
		# bota sokulan paça: baldırda büzgülü kabarık bolluk
		var s0: float = kn + 0.22
		var s2: float = kn + 0.4
		var bl := func(s: float, a: float) -> float:
			var t: float = clampf((s - s0) / (s2 - s0), 0.0, 1.0)
			return float(pa.call(s, a)) + 0.002 + 0.01 * pow(sin(t * PI), 0.8) * (1.0 + 0.35 * sin(a * 7.0 + s * 46.0 + sv))
		P._lt(k, le, bl, func(s, a, ins):
			if ins:
				return bk.darkened(0.3)
			return bk.darkened(0.2 * maxf(0.0, -sin(float(a) * 7.0 + float(s) * 46.0 + sv)) * sin(clampf((float(s) - s0) / (s2 - s0), 0.0, 1.0) * PI)), s0, s2, 16, 28)
		if sd == "Right":   # sağ uyluk: sargı, lacivert bant, kılıf
			var sg: float = le["sg"]
			for i in 4:
				var s: float = 0.25 + 0.019 * i
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + float(pa.call(s, 0.0)) + 0.005, 0.0105, 0.004, bw.darkened(0.06 * float(i % 2)), P._lskin(le, s))
			Q._ring_on(k, le, 0.278, func(s, a): return float(pa.call(float(s), float(a))) + 0.009, 0.0085, nv, 0.003)
			var a0: float = sg * (PI * 0.5 + 0.12)
			var cs := 0.31
			var e0: Array = Q._ls(le, cs, a0, float(pa.call(cs, a0)) + 0.024)
			var d: Vector3 = P._ld(le, cs)
			var o: Vector3 = e0[1]
			var ux: Vector3 = o.cross(d).normalized()
			var bo: Array = P._lskin(le, cs)
			P._boxr(k, e0[0], ux * 0.03, -d * 0.058, o * 0.016, nv, bo, 0.3)
			P._boxr(k, (e0[0] as Vector3) - d * 0.04 + o * 0.006, ux * 0.032, -d * 0.02, o * 0.014, nv.lightened(0.06), bo, 0.35)
			P._stud(k, (e0[0] as Vector3) - d * 0.03 + o * 0.022, o, 0.004, mt, bo)
	# ceket gövdesi: önü açık, belde lastikli bant
	var mid: Vector3 = k.M(C - 0.12, k.UA)
	var hb: float = H + 0.045
	var top: float = N + 0.012
	var jk := [P._kp(nk, top, 0.03), [N - 0.055, ch.x * 1.02 + 0.01, ch.y * 0.96 + 0.026, ch.z * 1.05 - 0.026], P._kp(ch, C - 0.03, 0.034), P._kp(mid, C - 0.12, 0.042), P._kp(wa, H + 0.12, 0.05), P._kp(wa, hb, 0.052)]
	var e_at := func(y: float) -> float: return lerpf(0.33, 0.6, smoothstep(C - 0.04, top, y))
	var jf := func(a: float, y: float) -> float:
		var aw := absf(a)
		var bl2: float = 0.055 * exp(-pow((y - (hb + 0.03)) / 0.03, 2.0)) * (1.0 + 0.3 * sin(a * 9.0 + 0.4))
		var t: float = clampf((C - y) / (C - hb), 0.0, 1.0)
		return smoothstep(0.3, 0.7, aw) * (bl2 + t * (0.016 * sin(a * 7.0 + 0.5) + 0.007 * sin(a * 15.0 + 1.3)) + (1.0 - t) * 0.006 * sin(a * 4.0 + y * 18.0) * smoothstep(N - 0.02, C - 0.05, y))
	var tsk := func(p): return k.torso_skin(p.y)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 46, "na": 92, "rng": func(v):
		var e: float = e_at.call(lerpf(top, hb, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return top, "hem": func(_a): return hb, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 8.0, "th": 0.006, "inner": bk.darkened(0.3), "skin": tsk})
	# lastikli etek bandı: dikey fitiller
	var lo: Vector3 = k.M(H - 0.0, 0.3)
	var rk := [P._kp(wa, hb + 0.004, 0.05), P._kp(lo, H - 0.004, 0.028)]
	var e_b: float = e_at.call(hb)
	var rg: Dictionary = P._cl(k, {"keys": rk, "ny": 5, "na": 180, "rng": func(_v): return Vector2(e_b, TAU - e_b), "top": func(_a): return hb + 0.004, "hem": func(_a): return H - 0.004,
		"fold": func(a, _y, _v): return 0.012 * sin(float(a) * 44.0), "col": func(_a, _y, _v): return bk.lightened(0.03), "gain": 12.0, "th": 0.006, "inner": bk.darkened(0.3), "skin": tsk})
	# fermuar şeritleri + çekme ucu
	var zp := []
	for ed in [jg["ea"], jg["eb"]]:
		var pts: Array = ed.duplicate()
		pts.append((rg["ea"] if zp.is_empty() else rg["eb"]).back())
		P._bd(k, pts, 0.0035, 0.0028, mt, false, tsk, 0.0)
		zp.append(pts[pts.size() - 1])
	var zpo: Vector3 = P._out(zp[0])
	P._boxr(k, (zp[0] as Vector3) + Vector3(0, 0.012, 0) + zpo * 0.004, Vector3(0.004, 0, 0), Vector3(0, 0.011, 0), zpo * 0.0025, mt.lightened(0.1), [["Hips", 0.5], ["Spine", 0.5]], 0.3)
	# dik yaka: dışı siyah, içi pembe
	var q: float = Q._hq(k)
	var ck := [[N + 0.08 * q, nk.x + 0.042, nk.y + 0.04, nk.z - 0.046], [N + 0.03 * q, nk.x + 0.034, nk.y + 0.032, nk.z - 0.04], [N - 0.02, nk.x + 0.05, nk.y + 0.046, nk.z - 0.046]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 50, "rng": func(_v): return Vector2(0.6, TAU - 0.6), "top": func(a): return N + q * lerpf(0.06, 0.08, smoothstep(0.6, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.016,
		"fold": func(a, _y, v): return 0.008 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return bk.lightened(0.03), "inner": pk, "skin": func(p): return Q._nsk(k, p), "th": 0.007})
	P._cord(k, cg["top"], 0.004, pk.lightened(0.05), false, func(p): return Q._nsk(k, p))
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.0035, pk, false, func(p): return Q._nsk(k, p))
	# sırtta girdap: halka + içe sarılan sarmal
	var fv := func(a, y): return jf.call(float(a), float(y))
	var mb: Callable = Q._local(jk, fv, PI, C - 0.07)
	var lm := func(u, v, l): return mb.call(u, v, float(l) + 0.003)
	Q._circle(k, lm, 0.062, 0.0055, 0.0, pk, tsk, 44)
	var sp := []
	for i in 46:
		var v := float(i) / 45.0
		var t: float = v * TAU * 1.8 + 0.4
		var rr: float = 0.046 * lerpf(1.0, 0.08, v)
		sp.append(Vector2(cos(t) * rr, sin(t) * rr))
	_lstrip(k, lm, sp, 0.005, 0.0, 0.0022, pk, tsk)
	# kollar: bileğe, dirsekte kırışık, lastikli manşet, dış-arka yanda pembe şerit
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.4 if sd == "Left" else 2.7
		var sf := func(s: float, a: float) -> float:
			return 0.016 + 0.01 * smoothstep(0.1, 0.5, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.009 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.008 * exp(-pow((s - 0.12) / 0.1, 2.0)) + 0.006 * exp(-pow((s - 0.86) / 0.035, 2.0)) * (1.0 + sin(a * 8.0))
		P._lt(k, ar, sf, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.02), float(sf.call(float(s), float(a))) - 0.016 - 0.01 * smoothstep(0.1, 0.5, float(s)), 10.0), 0.0, 0.9, 32, 20, 0.02)
		P._lt(k, ar, func(s, a): return 0.009 + 0.0018 * sin(float(a) * 14.0) - 0.002 * smoothstep(0.95, 0.985, float(s)), func(_s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05).darkened(0.12 * float(sin(float(a) * 14.0) < 0.0)), 0.885, 0.985, 6, 28)
		_arm_skin(k, ar, 0.8)   # manşet içinden görünen bilek
		K._lt_in(k, ar, func(s, a): return 0.009 + 0.0018 * sin(float(a) * 14.0) - 0.004, bk.darkened(0.35), 0.9, 0.985, 4, 28)
		var ast: float = sg * (PI * 0.5 + 0.55)
		var pts := []
		var ou := []
		for i in 30:
			var s: float = lerpf(0.04, 0.88, float(i) / 29.0)
			var e: Array = Q._ls(ar, s, ast, float(sf.call(s, ast)) + 0.0012)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, 0.0095, 0.0016, pk, false, func(p): return _lsk(ar, p))
