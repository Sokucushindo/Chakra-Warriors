extends RefCounted
## Elle modellenmiş setler, parti q: ss_genis_yaka, ss_anbu_kapuson, ss_yirminci, ss_tehlike_ceket, ss_sigara_jonin, ss_alti_yol. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K) ve j (J) dosyalarından; burada uzun giysi ağırlığı, yüzey üstü disk / tomoe / zincir ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")

const DONE := ["ss_genis_yaka", "ss_anbu_kapuson", "ss_yirminci", "ss_tehlike_ceket", "ss_sigara_jonin", "ss_alti_yol"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_genis_yaka": _genis(k)
		"ss_anbu_kapuson": _kapuson(k)
		"ss_yirminci": _yirminci(k)
		"ss_tehlike_ceket": _tehlike(k)
		"ss_sigara_jonin": _sigara(k)
		"ss_alti_yol": _alti(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
static func _skc(k) -> Color:
	var c = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	return c if c is Color else Color(0.9, 0.72, 0.58)


## Boyun-baş mesafesine göre yaka ölçeği (kadın bedende yaka yüzü örtmez)
static func _hq(k) -> float:
	return clampf(((k.m._bp("Head") as Vector3).y - float(k.N)) / 0.092, 0.6, 1.2)


## Uzun giysi ağırlığı. Ön yüz bacağı çabuk izler (kalkan diz kumaşı delmez); arka yüzde ağırlık boy boyunca yavaş artar ve
## iki bacak arasına geniş yayılır (geri giden bacak kumaşı kalçaya doğru ezmez, kumaş uzayarak iner); diz altı baldırı da izler.
static func _csk(k, p: Vector3, hem: float, fhw := 0.006) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.95 * pow(minf(1.0, t / 0.45), 0.45)
	var wb: float = lerpf(0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.9)), 0.96, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(fhw, 0.1, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var sd: String = "Left" if s >= 0.5 else "Right"
	var os: String = "Right" if s >= 0.5 else "Left"
	var ws: float = maxf(s, 1.0 - s)
	var kb: float = smoothstep(k.K + 0.08, k.K - 0.14, p.y) * lerpf(0.25, 0.55, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


static func _tri(x: float) -> float:
	return absf(fposmod(x / TAU, 1.0) * 2.0 - 1.0) * 2.0 - 1.0


## Boyun / göğüs geçişi: yaka boyunla döner
static func _nsk(k, p: Vector3) -> Array:
	if p.y > k.N:
		return [["Neck", 0.5], ["UpperChest", 0.5]]
	return k.torso_skin(p.y)


## keys + kıvrım yüzeyinde (açı, y) noktası: [konum, dış yön]
static func _spt(keys: Array, ff: Callable, a: float, y: float, lift := 0.0) -> Array:
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
	var f: float = 1.0 + (float(ff.call(wrapf(a, -PI, PI), y)) if ff.is_valid() else 0.0)
	var p := Vector3(q.x * f, y, q.y * f)
	var o := Vector3(p.x, 0.0, p.z).normalized()
	return [p + o * lift, o]


## Yüzeyde (açı, y) yolu boyunca kabartma şerit
static func _run(k, keys: Array, ff: Callable, ctrl: Array, hw: float, lift: float, d: float, col: Color, skinf: Callable, steps := 6, closed := false) -> void:
	var pts := []
	var ou := []
	var path: Array = P._path(ctrl, steps)
	if closed:
		path.pop_back()
	for q in path:
		var e: Array = _spt(keys, ff, q.x, q.y, lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, d, col, closed, skinf)


## Satırları dış yöne bakacak şekilde ızgaraya yazar
static func _mesh(k, rows: Array, closed: bool, colf: Callable, skinf: Callable, out: Vector3) -> void:
	var j0: int = mini(1, rows.size() - 2)
	var a: Vector3 = rows[j0][0]
	var fn: Vector3 = -((rows[j0][1] as Vector3) - a).cross((rows[j0 + 1][1] as Vector3) - a)
	if fn.dot(out) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, closed, colf, skinf)


## Yüzey yerel eşlemesi: (u yatay metre, v dikey metre, kalkış) -> konum
static func _local(keys: Array, ff: Callable, a0: float, y0: float) -> Callable:
	var R: float = ((_spt(keys, ff, a0 + 0.05, y0)[0] as Vector3) - (_spt(keys, ff, a0 - 0.05, y0)[0] as Vector3)).length() / 0.1
	return func(u: float, v: float, l: float) -> Vector3: return _spt(keys, ff, a0 + u / maxf(0.03, R), y0 + v, l)[0]


## Yüzeye oturan disk / amblem: rf(th) kenar çarpanı; colf(u, v) birim koordinat
static func _disc(k, mp: Callable, out: Vector3, r: float, lift: float, rf: Callable, colf: Callable, skinf: Callable, rings := 4, seg := 28) -> void:
	var rows := []
	var uv := []
	for j in rings + 1:
		var v := float(j) / rings
		var ro := []
		var ru := []
		for i in seg:
			var th := TAU * i / seg
			var q: float = v * (float(rf.call(th)) if rf.is_valid() else 1.0)
			ro.append(mp.call(cos(th) * q * r, sin(th) * q * r, lift + 0.0015 * (1.0 - v * v)))
			ru.append(Vector2(cos(th) * q, sin(th) * q))
		rows.append(ro)
		uv.append(ru)
	var a: Vector3 = rows[1][0]
	var fn: Vector3 = -((rows[1][1] as Vector3) - a).cross((rows[2][1] as Vector3) - a)
	if fn.dot(out) < 0.0:
		for ro in rows:
			ro.reverse()
		for ru in uv:
			ru.reverse()
	k.grid(rows, true, func(i, j, _p): return colf.call(uv[j][i].x, uv[j][i].y), func(_i, _j, p): return skinf.call(p))


## Tomoe: dolgun baş + kıvrılan, incelen kuyruk (kabartma). rot: kuyruğun çıktığı açı
static func _tomoe(k, mp: Callable, out: Vector3, r: float, rot: float, lift: float, col: Color, skinf: Callable, dot := Color(0, 0, 0, 0)) -> void:
	_disc(k, mp, out, r, lift, Callable(), func(u, v):
		if dot.a > 0.0 and Vector2(float(u), float(v)).length() < 0.32:
			return dot
		return col, skinf, 3, 16)
	var rows := []
	var n := 9
	for j in n + 1:
		var t := float(j) / n
		var ph: float = rot - t * 2.1
		var rho: float = r * lerpf(0.55, 1.75, t)
		var c := Vector2(cos(ph), sin(ph)) * rho
		var d := Vector2(sin(ph), -cos(ph)) * r * 1.2 + Vector2(cos(ph), sin(ph)) * r * 1.2 * 0.55
		var nn := Vector2(-d.y, d.x).normalized()
		var w: float = r * 0.78 * pow(1.0 - t, 0.85) + 0.0006
		rows.append([mp.call(c.x - nn.x * w, c.y - nn.y * w, lift), mp.call(c.x, c.y, lift + 0.0016 * (1.0 - t)), mp.call(c.x + nn.x * w, c.y + nn.y * w, lift)])
	_mesh(k, rows, false, func(_i, _j, _p): return col, func(_i, _j, p): return skinf.call(p), out)


## Halka (yüzey üstü kabartma çember)
static func _circle(k, mp: Callable, r: float, hw: float, lift: float, col: Color, skinf: Callable, n := 40) -> void:
	var pts := []
	var ou := []
	for i in n:
		var th := TAU * i / n
		var p: Vector3 = mp.call(cos(th) * r, sin(th) * r, lift)
		var p0: Vector3 = mp.call(cos(th) * r, sin(th) * r, lift - 0.01)
		pts.append(p)
		ou.append((p - p0).normalized())
	k.strip(pts, ou, hw, 0.0016, col, true, skinf)


## Burgu ip
static func _rope(k, pts: Array, R: float, col: Color, skinf: Callable, turns := 4.0, seg := 10) -> void:
	P._tb(k, pts, func(s, a): return R * (1.0 + 0.18 * cos(3.0 * float(a) - TAU * turns * float(s))) * (0.55 + 0.45 * pow(sin(clampf(float(s), 0.0, 1.0) * PI), 0.25)), func(s, a, _p):
		var w := cos(3.0 * float(a) - TAU * turns * float(s))
		return col.darkened(0.3) if w < -0.5 else (col.lightened(0.1) if w > 0.6 else col), func(_s, p): return skinf.call(p), seg)


## Uzvun yüzeyinde nokta (açı, kalkış)
static func _ls(l: Dictionary, s: float, a: float, lift: float) -> Array:
	var d: Vector3 = P._ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri := (-d).cross(fw).normalized()
	var o: Vector3 = ri * sin(a) + fw * cos(a)
	return [P._lp(l, s) + o * (P._lr(l, s) + lift), o]


## Uzuv kumaşının gerçek yüzeyini izleyen bant (bol pantolonda boşlukta halka kalmaz)
static func _ring_on(k, l: Dictionary, s: float, ad: Callable, hw: float, col: Color, bulge := 0.005) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var bo: Array = P._lskin(l, s)
	var rows := []
	for j in 5:
		var v := float(j) / 4.0
		var s2: float = s + lerpf(-hw, hw, v) / L
		var ro := []
		for i in 36:
			var a := TAU * i / 36.0 - PI
			ro.append(_ls(l, s2, a, float(ad.call(s2, a)) - 0.001 + bulge * sin(v * PI))[0])
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.14) if j in [0, 4] else col, func(_i, _j, _p): return bo)


## Bol pantolon: tk'de toplanır (ağız bacağa kapanır, içi görünmez); altı dar, kendi renginde
static func _baggy(k, le: Dictionary, col: Color, low: Color, base: float, bag: float, tk: float, sv: float) -> Callable:
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		var g: float = 1.0 - smoothstep(tk - 0.03, tk + 0.005, s)
		var cr: float = 0.009 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var ru: float = 0.011 * exp(-pow((s - tk + 0.045) / 0.045, 2.0)) * sin(a * 9.0 + sv)
		return ((0.006 + bag * 0.16) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + cr + ru) * g
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = (base + bag * smoothstep(0.0, 0.42, s) * (1.0 - 0.18 * smoothstep(0.55, tk, s))) * (1.0 - 0.42 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s)))
		var g: float = smoothstep(tk - 0.06, tk + 0.008, s)
		return lerpf(v, 0.008, g) + float(fo.call(s, a))
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.45)
		return P._fs(col, fo.call(s, a), 13.0), 0.0, tk + 0.012, 42, 24, 0.02)
	P._lt(k, le, func(s, a): return 0.006 + 0.002 * sin(float(a) * 5.0 + float(s) * 20.0) - 0.002 * smoothstep(0.95, 1.0, float(s)), func(_s, a, ins): return low.darkened(0.4) if ins else low.darkened(0.08 if sin(float(a) * 5.0) < -0.3 else 0.0), tk - 0.05, 1.0, 14, 18)
	return ad


# ------------------------------------------------------------------ Kuro Hiroeri (ref Shinobi Striker "Amado Outfit"): bol kutu kesim siyah gömlek, geniş dik yaka + V yaka, yakada altın zincir, dirsek altına inen geniş kol, toplanan krem bol pantolon + koyu alt paça
static func _genis(k) -> void:
	var bk := Color(0.118, 0.133, 0.188)
	var cr := Color(0.902, 0.875, 0.784)
	var tn := Color(0.66, 0.56, 0.4)
	var gd := Color(0.95, 0.76, 0.27)
	var skc := _skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# V yakadan görünen boyun ve göğüs
	var sk_k := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], [C - 0.0, ch.x * 0.95, ch.y + 0.003, ch.z * 0.98], P._kp(ch, C - 0.08, 0.004)]
	SE.body_layer(k, sk_k, 14, 36, func(_i, _j, _p): return skc)
	K._seat(k, b, cr.darkened(0.08))
	# gömlek: omuzdan kalçaya kutu kesim, V yaka, aşağı doğru dökülen dikey kıvrımlar
	var hem: float = H - 0.15
	var box: float = maxf(wa.x + 0.05, ch.x * 0.98)
	var gk := [P._kp(nk, N + 0.012, 0.026), [N - 0.05, ch.x * 1.03, ch.y * 0.97, ch.z * 1.07], P._kp(ch, C - 0.03, 0.038), [H + 0.12, box, maxf(wa.y + 0.05, ch.y * 0.92), minf(wa.z - 0.05, ch.z * 0.95)], [H - 0.04, maxf(box, hp.x + 0.05), hp.y + 0.06, hp.z - 0.06], [hem, maxf(box, hp.x + 0.06) + 0.01, hp.y + 0.07, hp.z - 0.07]]
	var yv: float = C + 0.005
	var vt := func(a: float) -> float: return lerpf(yv, N + 0.012, smoothstep(0.0, 1.0, clampf(absf(a) / 0.6, 0.0, 1.0)))
	var gf := func(a: float, y: float) -> float:
		var t: float = clampf((C - 0.05 - y) / (C - 0.05 - hem), 0.0, 1.0)
		return t * (0.022 * sin(a * 7.0 + 0.5) + 0.01 * sin(a * 13.0 + 1.7)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 17.0) * smoothstep(N - 0.02, C - 0.05, y)
	var g: Dictionary = P._cl(k, {"keys": gk, "ny": 34, "na": 84, "top": func(a): return vt.call(float(a)), "hem": func(_a): return hem, "fold": func(a, y, _v): return gf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.darkened(0.45)})
	var ve := []
	for p in g["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.64:
			ve.append(p)
	P._bd(k, ve, 0.0055, 0.003, bk.lightened(0.08), false, func(p): return k.torso_skin(p.y), 0.4)
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.011, 0))
	P._bd(k, hm, 0.003, 0.0016, bk.darkened(0.3), true, func(p): return P._hs(k, p))
	# geniş dik yaka: arkada yüksek, önde yana açılır
	var q: float = _hq(k)
	var ck := [[N + 0.1 * q, nk.x + 0.06, nk.y + 0.05, nk.z - 0.065], [N + 0.035 * q, nk.x + 0.034, nk.y + 0.03, nk.z - 0.04], [N - 0.02, nk.x + 0.044, nk.y + 0.04, nk.z - 0.04]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 46, "rng": func(_v): return Vector2(0.5, TAU - 0.5), "top": func(a):
		return N + q * lerpf(0.045, 0.1, smoothstep(0.45, 2.3, absf(float(a)))), "hem": func(a): return N - 0.012 - 0.012 * (1.0 - smoothstep(0.5, 1.3, absf(float(a)))), "fold": func(a, _y, v): return 0.01 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.5),
		"col": func(_a, _y, _v): return bk.lightened(0.03), "inner": bk.darkened(0.3), "skin": func(p): return _nsk(k, p), "th": 0.006})
	P._cord(k, cg["top"], 0.0045, bk.lightened(0.1), false, func(p): return _nsk(k, p))
	for e in [cg["ea"], cg["eb"]]:
		P._cord(k, e, 0.0038, bk.lightened(0.06), false, func(p): return _nsk(k, p))
	# altın zincir: halka halka, boyundan V yakaya iner
	var cp := []
	var nl := 46
	for i in nl:
		var a: float = lerpf(-1.5, 1.5, float(i) / (nl - 1))
		var y: float = N + 0.01 - 0.072 * pow(cos(a * 1.0), 3.0)
		cp.append(_spt(sk_k, Callable(), a, y, 0.005))
	for i in nl - 1:
		var p0: Vector3 = cp[i][0]
		var p1: Vector3 = cp[i + 1][0]
		var o: Vector3 = cp[i][1]
		var c := (p0 + p1) * 0.5
		var tg := (p1 - p0).normalized()
		var sd := o if i % 2 == 0 else tg.cross(o).normalized()
		var lk := []
		for j in 8:
			var th := TAU * j / 8.0
			lk.append(c + tg * cos(th) * 0.0052 + sd * sin(th) * 0.0028)
		P._tb(k, lk, func(_s, _a): return 0.0012, func(_s, _a, _p): return gd, func(_s, p): return k.torso_skin(p.y), 4, true)
	# kollar: düşük omuz, dirsek altında geniş ağız; altı çıplak ön kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.3 if sd == "Left" else 2.4
		var s1 := 0.7
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.12, s1, s)
			return 0.02 + 0.038 * fl + (0.003 + 0.006 * fl) * P._lf(s, a, sv) + 0.012 * exp(-pow((s - 0.12) / 0.1, 2.0)) + 0.007 * exp(-pow((s - float(ar["kn"])) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins):
			return bk.darkened(0.5) if ins else P._fs(bk, float(sf.call(float(s), float(a))) - 0.02 - 0.038 * smoothstep(0.12, s1, float(s)), 14.0), 0.0, s1, 30, 22, 0.035)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, bk.darkened(0.4), 0.45, s1, 10, 22)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return bk.darkened(0.45) if ins else bk.lightened(0.05), s1 - 0.035, s1 + 0.001, 4, 22)
		P._bare(k, ar, skc, 0.48, 1.0)
		_baggy(k, le, cr, tn, 0.02, 0.05, 0.8, sv)


# ------------------------------------------------------------------ Kakure Gaitō (ref Shinobi Striker "Anbu Outfit: Coat Ver."): yırtık kenarlı kapüşonu boyna düşmüş, önü ortadan kapanan krem uzun palto, siyah iç + pantolon, baldırda koyu sargı
static func _kapuson(k) -> void:
	var cr := Color(0.878, 0.863, 0.8)
	var bk := Color(0.11, 0.11, 0.125)
	var wr := Color(0.17, 0.17, 0.21)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return bk.lightened(0.04) if j < 4 else bk, 0.006)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var pa: Callable = K._pant(k, le, bk, 0.01, 0.012, 1.0, 1.4 if sd == "Left" else 2.6)
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.002, func(_s, _a, ins): return wr.darkened(0.4) if ins else wr.darkened(0.25), kn + 0.06, 0.985, 14, 18)
		P._wraps(k, le, kn + 0.08, 0.975, 12, 0.017, 0.0125, wr, 0.009)
	# palto gövdesi
	var hem: float = KN - 0.07
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.042), P._kp(hp, H - 0.04, 0.048),
		[KN + 0.05, hp.x + 0.07, hp.y + 0.06, hp.z - 0.085], [hem, hp.x + 0.09, hp.y + 0.07, hp.z - 0.105]]
	var e := 0.012
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fe: float = smoothstep(0.03, 0.35, aw)
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var lo: float = pow(t, 0.9) * ((0.03 + 0.012 * bkf) * sin(a * 7.0 + 0.6) + 0.016 * sin(a * 13.0 + 1.9))
		var up: float = (1.0 - t) * 0.006 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
		return fe * (lo + up)
	var csk := func(p): return _csk(k, p, hem, 0.06)
	var rnd := 0.0
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 46, "na": 92, "rng": func(_v): return Vector2(e, TAU - e), "top": func(_a): return N + 0.012,
		"hem": func(a): return hem + rnd * (1.0 - smoothstep(e, e + 0.35, absf(float(a)))), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return cr, "gain": 4.0, "th": 0.006, "inner": cr.darkened(0.3), "skin": csk})
	# ön kenar biyesi, üstte kapanış patı, yan dikişler, etek ucu
	for ed in [cg["ea"], cg["eb"]]:
		P._bd(k, ed, 0.004, 0.0022, cr.darkened(0.12), false, csk, 0.0)
	_run(k, keys, ff, [Vector2(0.0, N - 0.02), Vector2(0.0, H - 0.02)], 0.009, 0.004, 0.003, cr.darkened(0.05), csk, 10)
	for sg in [1.0, -1.0]:
		_run(k, keys, ff, [Vector2(sg * 0.95, C + 0.04), Vector2(sg * 1.0, H + 0.1), Vector2(sg * 1.02, hem + 0.02)], 0.0028, 0.0015, 0.0015, cr.darkened(0.16), csk, 8)
		_run(k, keys, ff, [Vector2(sg * (PI - 0.42), C + 0.0), Vector2(sg * (PI - 0.4), H + 0.1), Vector2(sg * (PI - 0.36), hem + 0.02)], 0.0028, 0.0015, 0.0015, cr.darkened(0.16), csk, 8)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._bd(k, hm, 0.003, 0.0016, cr.darkened(0.2), false, csk)
	# kollar: bileğe uzun, hafif genişleyen; ağız katlı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.1
		var sf := func(s: float, a: float) -> float:
			return 0.014 + 0.018 * smoothstep(en - 0.1, 0.95, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.12) / 0.1, 2.0))
		P._lt(k, ar, sf, func(s, a, ins): return cr.darkened(0.35) if ins else P._fs(cr, float(sf.call(float(s), float(a))) - 0.014 - 0.018 * smoothstep(float(en) - 0.1, 0.95, float(s)), 12.0), 0.0, 0.96, 32, 20, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, cr.darkened(0.3), 0.8, 0.96, 6, 20)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return cr.darkened(0.35) if ins else cr.darkened(0.06), 0.885, 0.962, 5, 20)
	# kapüşon: boyunda bol halka (yırtık üst kenar) + sırta düşmüş torba
	var q: float = _hq(k)
	var tear := func(a: float) -> float: return 0.009 * _tri(a * 11.0 + 0.4) + 0.006 * sin(a * 23.0 + 1.1) + 0.004 * sin(a * 37.0)
	var hk := [[N + 0.15 * q, nk.x + 0.085, nk.y + 0.06, nk.z - 0.1], [N + 0.07 * q, nk.x + 0.07, nk.y + 0.058, nk.z - 0.085], [N - 0.0, nk.x + 0.075, nk.y + 0.065, nk.z - 0.075], [N - 0.06, ch.x * 0.78, ch.y * 0.86, ch.z * 0.95]]
	var hf := func(a: float, _y: float, v: float) -> float:
		return 0.06 * sin(float(v) * PI * 2.2 + cos(a) * 1.1) * smoothstep(0.0, 0.25, float(v)) * (1.0 - float(v) * 0.6) + 0.012 * sin(a * 9.0 + 0.7) * float(v)
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 18, "na": 70, "rng": func(_v): return Vector2(0.36, TAU - 0.36), "top": func(a):
		return N + q * lerpf(0.06, 0.13, smoothstep(0.4, 2.2, absf(float(a)))) + float(tear.call(float(a))), "hem": func(a): return N - 0.05 - 0.02 * smoothstep(1.0, 2.6, absf(float(a))), "fold": hf,
		"col": func(_a, _y, _v): return cr.lightened(0.02), "gain": 6.0, "inner": cr.darkened(0.32), "skin": func(p): return _nsk(k, p), "th": 0.007})
	P._cord(k, hg["top"], 0.0045, cr.darkened(0.06), false, func(p): return _nsk(k, p))
	var sk2 := []
	for e2 in keys:
		sk2.append([e2[0], float(e2[1]) + 0.012, float(e2[2]) + 0.012, float(e2[3]) - 0.014])
	var bagf := func(a: float, _y: float, v: float) -> float:
		var db: float = clampf((PI - absf(a)) / 1.05, 0.0, 1.0)
		return 0.11 * sin(float(v) * PI) * (1.0 - db * db) + 0.01 * sin(a * 7.0 + 0.3) * float(v)
	var bg: Dictionary = P._cl(k, {"keys": sk2, "ny": 16, "na": 40, "rng": func(_v): return Vector2(PI - 1.05, PI + 1.05), "top": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.05, 0.0, 1.0)
		return N + 0.03 - 0.07 * db * db, "hem": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.05, 0.0, 1.0)
		return C - 0.1 + 0.12 * pow(db, 1.6), "fold": bagf, "col": func(_a, _y, _v): return cr, "gain": 5.0, "inner": cr.darkened(0.3), "skin": func(p): return k.torso_skin(p.y), "th": 0.006})
	P._cord(k, bg["hem"], 0.0042, cr.darkened(0.1), false, func(p): return k.torso_skin(p.y))
	P._cur_hem = hem


# ------------------------------------------------------------------ Hōshuku Kimono (ref Shinobi Striker "Anime Series 20th Anniversary Costumes"): koyu dik yakalı kısa kollu tulum, sol omuzdan sağ bele verev turuncu kimono (sağ yarısı bele düşmüş),
## sol göğüste güneş, siyah obi + 9 parlak magatama, sağ kalçada beyaz bez, sağ omuzda sarı düğüm, toplanan lacivert bol pantolon
static func _yirminci(k) -> void:
	var dk := Color(0.141, 0.141, 0.212)
	var nv := Color(0.141, 0.165, 0.314)
	var og := Color(0.91, 0.478, 0.165)
	var rd := Color(0.753, 0.227, 0.078)
	var yl := Color(1.0, 0.84, 0.3)
	var gl := Color(1.0, 0.93, 0.45)
	var wh := Color(0.96, 0.95, 0.97)
	var lv := Color(0.78, 0.72, 0.9)
	var ob := Color(0.09, 0.08, 0.09)
	var skc := _skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var ik: Array = P._inner(k, b, func(_i, j, _p): return dk.lightened(0.05) if j % 7 == 3 else dk, 0.008)
	K._seat(k, b, nv.darkened(0.05))
	# dik yaka + fermuar
	var q: float = _hq(k)
	var ck := [P._kp(nk, N + 0.08 * q, 0.016, 0.02), P._kp(nk, N + 0.03 * q, 0.02), P._kp(nk, N - 0.03, 0.036), P._kp(nk, N - 0.07, 0.06, 0.05)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 9, "na": 44, "rng": func(_v): return Vector2(0.09, TAU - 0.09), "top": func(_a): return N + 0.075 * q, "hem": func(_a): return N - 0.065,
		"fold": func(a, y, _v): return 0.012 * sin(float(a) * 5.0 + float(y) * 20.0), "col": func(_a, _y, _v): return dk.lightened(0.04), "skin": func(p): return _nsk(k, p), "th": 0.006})
	P._cord(k, cg["top"], 0.005, dk.lightened(0.1), false, func(p): return _nsk(k, p))
	P._strap(k, ik, [Vector2(0.0, N + 0.07 * q), Vector2(0.0, C - 0.05)], true, 0.0035, 0.008, 0.002, Color(0.55, 0.55, 0.6), 12)
	# uzuvlar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.2 if sd == "Left" else 2.3
		P._bare(k, ar, skc, 0.22, 1.0)
		var sh := func(s: float, a: float) -> float: return 0.012 + 0.006 * smoothstep(0.05, 0.3, s) + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sh, func(s, a, ins): return dk.darkened(0.45) if ins else P._fs(dk, float(sh.call(float(s), float(a))) - 0.015, 18.0), 0.0, 0.3, 14, 18, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return dk.darkened(0.45) if ins else dk.lightened(0.07), 0.27, 0.302, 3, 18)
		if sd == "Left":   # kimononun tek giyilen kolu: geniş, alt yanı sarkık, ağzı desenli
			var kl := func(s: float, a: float) -> float:
				var t: float = smoothstep(0.04, 0.5, s)
				return 0.028 + 0.022 * t + 0.04 * t * pow(maxf(0.0, -sin(a) * sg), 2.0) + 0.006 * P._lf(s, a, 3.3)
			var s1: float = kn + 0.1
			P._lt(k, ar, kl, func(s, a, ins): return og.darkened(0.4) if ins else P._fs(og, 0.006 * P._lf(float(s), float(a), 3.3), 16.0), 0.0, s1, 26, 26, 0.06)
			K._lt_in(k, ar, func(s, a): return float(kl.call(float(s), float(a))) - 0.006, og.darkened(0.35), s1 - 0.2, s1, 8, 26)
			_ring_on(k, ar, s1 - 0.022, kl, 0.022, rd, 0.0045)
			_ring_on(k, ar, s1 - 0.006, func(s, a): return float(kl.call(float(s), float(a))) + 0.004, 0.0045, yl, 0.002)
		else:   # sağ omuzda sarı ip düğümü: kolu saran tur + omuzdan inen burgu + iki ilmek
			var ab := [[sd + "UpperArm", 1.0]]
			_ring_on(k, ar, 0.15, func(s, a): return float(sh.call(float(s), float(a))) + 0.004, 0.009, yl.darkened(0.05), 0.006)
			var t0: Vector3 = _ls(ar, 0.05, sg * 1.9, 0.012)[0]
			var t1: Vector3 = _ls(ar, 0.15, sg * 1.2, 0.016)[0]
			var t2: Vector3 = _ls(ar, 0.3, sg * 0.9, 0.012)[0]
			var t3: Vector3 = _ls(ar, 0.42, sg * 0.8, 0.008)[0]
			_rope(k, [t0, t0.lerp(t1, 0.5) + Vector3(0, 0.004, 0), t1, t1.lerp(t2, 0.5), t2, t3], 0.0075, yl, func(_p): return ab, 3.0, 10)
			for dz in [-1.0, 1.0]:
				var lp := []
				for i in 9:
					var th := TAU * i / 8.0
					lp.append(t1 + Vector3(0, sin(th) * 0.016, 0) + Vector3(0, 0, dz) * (0.012 + 0.012 * cos(th)) + Vector3(-sg * 0.006, 0, 0))
				P._tb(k, lp, func(_s, _a): return 0.0045, func(_s, a, _p): return yl.darkened(0.15) if cos(float(a)) < -0.3 else yl, func(_s, _p): return ab, 8)
			P._stud(k, t1 + Vector3(-sg * 0.006, 0, 0), Vector3(-sg, 0, 0), 0.009, yl.darkened(0.08), ab)
		var pad: Callable = _baggy(k, le, nv, nv.darkened(0.25), 0.018, 0.046, 0.74, sv)
		_ring_on(k, le, 0.748, func(s, a): return float(pad.call(float(s), float(a))) + 0.002, 0.014, nv.darkened(0.12), 0.004)
	# üst kimono: sol omuzdan sağ bele verev
	var by: float = H + 0.06
	var uk := [P._kp(nk, N + 0.008, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.034), P._kp(wa, by + 0.04, 0.036), P._kp(wa, by - 0.035, 0.036)]
	var y0: float = N + 0.008
	var y1: float = by - 0.035
	var ur := func(v: float) -> Vector2:
		var t: float = pow(v, 0.8)
		return Vector2(lerpf(0.2, -1.25, t), lerpf(PI - 0.18, PI + 1.25, t))
	var uf := func(a: float, y: float, v: float) -> float:
		return 0.016 * sin(a * 5.0 + y * 16.0) * float(v) + 0.009 * sin(a * 9.0 - y * 22.0) + 0.012 * float(v) * sin(a * 3.0 + 1.0)
	var ug: Dictionary = P._cl(k, {"keys": uk, "ny": 32, "na": 70, "rng": ur, "top": func(_a): return y0, "hem": func(_a): return y1, "fold": uf, "col": func(_a, _y, _v): return og, "gain": 5.0, "th": 0.006, "inner": og.darkened(0.4), "skin": func(p): return k.torso_skin(p.y)})
	for ed in [ug["ea"], ug["eb"]]:
		var e2 := []
		for p in ed:
			e2.append(p)
		P._bd(k, e2, 0.016, 0.005, rd, false, func(p): return k.torso_skin(p.y), 0.15)
		var e3 := []
		for p in ed:
			e3.append((p as Vector3) + P._out(p, 0.15) * 0.005)
		P._bd(k, e3, 0.004, 0.0016, yl, false, func(p): return k.torso_skin(p.y), 0.15)
	# güneş arması: beyaz disk, çevresinde alev dilleri ve sarı kıvrımlar
	var sun_a: float = 0.48
	var sun_y: float = C - 0.035
	var sk_t := func(p): return k.torso_skin(p.y)
	var uff := func(a, y): return uf.call(float(a), float(y), 0.5)
	var mp: Callable = _local(uk, uff, sun_a, sun_y)
	var so: Vector3 = _spt(uk, uff, sun_a, sun_y)[1]
	_disc(k, mp, so, 0.064, 0.004, func(th): return 0.55 + 0.45 * pow(absf(cos(float(th) * 3.5 + 0.3)), 2.5) * (0.7 + 0.3 * cos(float(th) - 0.4)), func(u, v):
		var r: float = Vector2(float(u), float(v)).length()
		return yl if r > 0.8 else rd, sk_t, 5, 56)
	_disc(k, mp, so, 0.032, 0.0068, Callable(), func(u, v): return wh.darkened(0.08) if Vector2(float(u), float(v)).length() > 0.86 else wh, sk_t, 4, 32)
	# alt kimono: obiden dize, önü açık, kat kat düşer
	var hem: float = KN + 0.02
	var skk := [P._kp(wa, by + 0.02, 0.04), [H - 0.04, hp.x + 0.072, hp.y + 0.056, hp.z - 0.082], [KN + 0.2, hp.x + 0.115, hp.y + 0.085, hp.z - 0.125], [hem, hp.x + 0.125, hp.y + 0.1, hp.z - 0.14]]
	var srg := func(v: float) -> Vector2:
		var e: float = lerpf(0.18, 0.55, v)
		return Vector2(e, TAU - e)
	var sf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		return smoothstep(0.1, 0.5, absf(a)) * (0.018 * sin(a * 14.0 + 0.4) * (1.0 - t) + t * (0.045 * sin(a * 7.0 + 0.6) + 0.02 * sin(a * 12.0 + 1.9)))
	var csk := func(p): return _csk(k, p, hem)
	var rnd := 0.03
	var sg2: Dictionary = P._cl(k, {"keys": skk, "ny": 30, "na": 84, "rng": srg, "top": func(_a): return by + 0.02, "hem": func(a): return hem + rnd * (1.0 - smoothstep(0.55, 1.0, absf(float(a)))),
		"fold": sf, "col": func(_a, _y, _v): return og, "gain": 5.0, "th": 0.006, "inner": og.darkened(0.42), "skin": csk})
	for ed in [sg2["ea"], sg2["eb"]]:
		P._bd(k, ed, 0.013, 0.005, rd, false, csk, 0.0)
	var hr := []
	for p in sg2["hem"]:
		hr.append((p as Vector3) + Vector3(0, 0.013, 0))
	P._bd(k, hr, 0.013, 0.005, rd, false, csk)
	var hr2 := []
	for p in sg2["hem"]:
		hr2.append((p as Vector3) + Vector3(0, 0.027, 0) + P._out(p) * 0.004)
	P._bd(k, hr2, 0.0035, 0.0014, yl, false, csk)
	# sağ bele düşmüş yarı: belde kalın rulo
	var roll := []
	for i in 23:
		var a: float = lerpf(-0.3, -2.8, float(i) / 22.0)
		roll.append(_spt(skk, Callable(), a, by - 0.01, 0.028)[0])
	P._tb(k, roll, func(s, a): return 0.03 * (1.0 + 0.2 * sin(float(s) * TAU * 3.0 + float(a) * 2.0)) * (0.3 + 0.7 * pow(sin(float(s) * PI), 0.4)), func(s, a, _p):
		return og.darkened(0.12 + 0.18 * float(cos(float(a)) < -0.5)).lightened(0.06 * float(sin(float(s) * TAU * 3.0 + float(a) * 2.0) > 0.6)), func(_s, p): return k.torso_skin(maxf(float(p.y), H + 0.01)), 12)
	# beyaz bez: obiye sıkışmış, sağ uyluk önüne dökülür (leylak gölgeli kıvrımlar)
	var wk := []
	for e2 in skk:
		wk.append([e2[0], float(e2[1]) + 0.026, float(e2[2]) + 0.03, float(e2[3]) - 0.026])
	var wf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((by - y) / 0.3, 0.0, 1.0)
		return t * (0.06 * sin(a * 15.0 + 0.7) + 0.02 * sin(a * 27.0)) + 0.01 * sin(a * 9.0)
	P._cl(k, {"keys": wk, "ny": 20, "na": 26, "rng": func(v): return Vector2(-1.45 - 0.2 * float(v), -0.55 + 0.15 * float(v)), "top": func(_a): return by - 0.015, "hem": func(a):
		var u: float = clampf((float(a) + 1.45) / 0.9, 0.0, 1.0)
		return H - 0.26 + 0.08 * sin(u * PI * 1.5), "fold": wf,
		"col": func(a, y, _v): return wh.lerp(lv, clampf(-float(wf.call(float(a), float(y), 0.0)) * 22.0, 0.0, 0.8)), "gain": 2.0, "th": 0.005, "inner": lv.darkened(0.15), "skin": csk})
	# obi + arkada düğüm
	P._sash(k, uk, by, 0.045, 0.012, ob.lightened(0.05), 0.2)
	var kb: Array = P._fp(uk, 0.0, by, false, 0.034)
	P._boxr(k, kb[0], Vector3(0.065, 0, 0), Vector3(0, 0.034, 0), Vector3(0, 0, -0.024), ob.lightened(0.06), [["Hips", 1.0]], 0.45)
	P._boxr(k, (kb[0] as Vector3) + Vector3(0, 0, -0.02), Vector3(0.022, 0, 0), Vector3(0, 0.036, 0), Vector3(0, 0, -0.012), ob.lightened(0.1), [["Hips", 1.0]], 0.4)
	# 9 parlak magatama: obinin altında sol öne dizili
	for i in 9:
		var a: float = lerpf(-0.12, 1.25, float(i) / 8.0)
		var e3: Array = _spt(skk, Callable(), a, by - 0.058 + 0.008 * sin(float(i) * 2.1), 0.016)
		var c0: Vector3 = e3[0]
		var o: Vector3 = e3[1]
		var tx: Vector3 = Vector3.UP.cross(o).normalized()
		var bo := [["Hips", 1.0]]
		var pts := [c0 + Vector3(0, 0.012, 0), c0 + Vector3(0, 0.004, 0), c0 + Vector3(0, -0.006, 0) + tx * 0.004, c0 + Vector3(0, -0.017, 0) + tx * 0.01, c0 + Vector3(0, -0.028, 0) + tx * 0.008, c0 + Vector3(0, -0.034, 0) + tx * 0.001]
		P._tb(k, pts, func(s, _a):
			var sv := float(s)
			return 0.0125 * sqrt(maxf(0.05, 1.0 - pow((sv - 0.25) / 0.25, 2.0))) if sv < 0.25 else 0.0125 * (1.0 - (sv - 0.25) / 0.75 * 0.88), func(s, a, _p): return gl.lightened(0.12) if cos(float(a)) > 0.4 and float(s) < 0.35 else gl, func(_s, _p): return bo, 10)
		var cd: Array = _spt(skk, Callable(), a, by - 0.032, 0.012)
		P._tb(k, [cd[0], c0 + Vector3(0, 0.012, 0)], func(_s, _a): return 0.002, func(_s, _a, _p): return ob, func(_s, _p): return bo, 5)
	P._cur_hem = hem


# ------------------------------------------------------------------ Kiken Haori (ref Shinobi Striker "Anko Outfit"): file tulum (gövde + uyluk), kırmızı kolye, siyah kemer + tokalı kayış, koyu kahve mini etek, mor şort,
## dize inen açık kahve önü açık palto (dik yaka, geniş katlı manşet, büyük yama cepler), açık renk kaval
static func _tehlike(k) -> void:
	var nt := Color(0.165, 0.149, 0.133)
	var sk_c := Color(0.353, 0.227, 0.157)
	var co := Color(0.847, 0.753, 0.604)
	var bl := Color(0.07, 0.07, 0.08)
	var mt := Color(0.7, 0.71, 0.74)
	var rdc := Color(0.66, 0.1, 0.1)
	var pu := Color(0.27, 0.13, 0.27)
	var gu := Color(0.82, 0.8, 0.78)
	var skc := _skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# file altından görünen ten + file iplikleri (önde, paltonun açıklığında)
	var tk := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], P._kp(ch, C - 0.03, 0.004), P._kp(wa, H + 0.12, 0.004), P._kp(hp, H - 0.06, 0.006)]
	SE.body_layer(k, tk, 24, 40, func(_i, _j, _p): return skc.darkened(0.12))
	_net(k, tk, -0.78, 0.78, H + 0.02, N + 0.035, 0.03, 0.0016, 0.0035, nt)
	var nr := []
	for i in 40:
		var a := TAU * i / 40.0 - PI
		nr.append(_spt(tk, Callable(), a, N + 0.035, 0.003)[0])
	P._cord(k, nr, 0.0028, nt.lightened(0.05), true, func(p): return k.torso_skin(p.y))
	# kırmızı kolye: ip + damla taş
	var kc := []
	for i in 31:
		var a: float = lerpf(-1.6, 1.6, float(i) / 30.0)
		kc.append(_spt(tk, Callable(), a, N + 0.01 - 0.05 * pow(cos(a), 4.0), 0.006)[0])
	P._cord(k, kc, 0.0018, Color(0.2, 0.12, 0.1), false, func(p): return k.torso_skin(p.y), 0.0, 5)
	var pe: Array = _spt(tk, Callable(), 0.0, N - 0.052, 0.012)
	P._tb(k, [(pe[0] as Vector3) + Vector3(0, 0.012, 0), pe[0], (pe[0] as Vector3) + Vector3(0, -0.018, 0)], func(s, _a): return 0.009 * sin(clampf(float(s) * 0.9 + 0.1, 0.0, 1.0) * PI) + 0.001, func(_s, a, _p): return rdc.lightened(0.1) if cos(float(a)) > 0.3 else rdc, func(_s, p): return k.torso_skin(p.y), 10)
	# mor şort + etek
	var bl_y: float = H + 0.04
	var st := [P._kp(wa, bl_y + 0.02, 0.008), P._kp(hp, H - 0.04, 0.014), [H - 0.12, hp.x + 0.02, hp.y + 0.016, hp.z - 0.016], [H - 0.15, hp.x * 0.7, hp.y * 0.72, hp.z * 0.72]]
	SE.body_layer(k, st, 10, 40, func(_i, _j, _p): return pu)
	var mh: float = H - 0.17
	var mk := [P._kp(wa, bl_y + 0.03, 0.016), P._kp(hp, H - 0.04, 0.03), [mh, hp.x + 0.06, hp.y + 0.05, hp.z - 0.055]]
	var mf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - mh), 0.0, 1.0)
		return t * (0.02 * sin(a * 8.0 + 0.3) + 0.008 * sin(a * 15.0))
	P._cur_leg = 0.66
	var mg: Dictionary = P._cl(k, {"keys": mk, "ny": 14, "na": 72, "top": func(_a): return bl_y + 0.03, "hem": func(_a): return mh, "fold": mf, "col": func(_a, _y, _v): return sk_c, "gain": 6.0, "th": 0.005, "inner": sk_c.darkened(0.4)})
	var mhm := []
	for p in mg["hem"]:
		mhm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, mhm, 0.0028, 0.0014, sk_c.darkened(0.3), true)
	# siyah kemer + toka, eteğin üstünden verev geçen ikinci kayış
	P._sash(k, mk, bl_y + 0.012, 0.015, 0.004, bl, 0.1)
	var bx: Array = P._fp(mk, -0.03, bl_y + 0.012, true, 0.02)
	_buckle(k, bx[0], bx[1], 0.022, 0.016, mt, [["Hips", 1.0]])
	var mhf := func(a, y): return mf.call(float(a), float(y), 0.0)
	_run(k, mk, mhf, [Vector2(-1.3, H - 0.02), Vector2(-0.4, H - 0.055), Vector2(0.5, H - 0.075), Vector2(1.4, H - 0.05)], 0.011, 0.006, 0.004, bl, func(p): return P._hs(k, p), 8)
	var b2: Array = _spt(mk, mhf, 0.08, H - 0.066, 0.016)
	_buckle(k, b2[0], b2[1], 0.018, 0.013, mt, P._hs(k, b2[0]))
	P._cur_leg = 0.58
	# bacaklar: ten, uyluğa inen file, açık renk kaval
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		P._bare(k, le, skc, 0.0, 1.0)
		P._lt(k, le, func(_s, _a): return 0.006, func(_s, _a, ins): return pu.darkened(0.4) if ins else pu, 0.0, 0.17, 6, 20)
		P._net_limb(k, le, 0.12, kn - 0.07, 0.003, 14, 0.026, 0.0014, nt)
		k.wrap_turn(P._lp(le, kn - 0.075), P._ld(le, kn - 0.075), P._lr(le, kn - 0.075) + 0.003, 0.005, 0.0, nt, P._lskin(le, kn - 0.075))
		var gd := func(s: float, a: float) -> float: return 0.012 + 0.004 * pow(maxf(0.0, cos(a)), 2.0) - 0.004 * smoothstep(0.9, 1.0, s) + 0.003 * (1.0 - smoothstep(kn + 0.05, kn + 0.12, s))
		P._lts(k, le, gd, func(s, a, ins):
			if ins:
				return gu.darkened(0.4)
			return gu.darkened(0.12 * float(cos(float(a)) < -0.4) + 0.08 * float(float(s) > 0.94)), func(a): return kn + 0.035 - 0.03 * pow(maxf(0.0, cos(float(a))), 2.0), 1.0, 22, 22)
		P._lt(k, le, func(s, a): return float(gd.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return gu.darkened(0.4) if ins else gu.darkened(0.06), kn + 0.075, kn + 0.1, 3, 22)
	# palto: dize iner, önü açık
	var hem: float = KN + 0.03
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.05), [H - 0.04, hp.x + 0.066, hp.y + 0.066, hp.z - 0.085],
		[KN + 0.15, hp.x + 0.08, hp.y + 0.06, hp.z - 0.085], [hem, hp.x + 0.09, hp.y + 0.065, hp.z - 0.1]]
	var e_at := func(y: float) -> float: return lerpf(0.66, 0.42, smoothstep(C - 0.1, N, y)) + 0.08 * smoothstep(H, hem, y)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fe: float = smoothstep(0.55, 0.95, aw)
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		return fe * (pow(t, 0.9) * ((0.03 + 0.012 * bkf) * sin(a * 7.0 + 0.6) + 0.015 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 9.0))
	var csk := func(p): return _csk(k, p, hem)
	var top_y: float = N + 0.012
	var e_h: float = e_at.call(hem)
	var rgf := func(v) -> Vector2:
		var e: float = e_at.call(lerpf(top_y, hem, float(v)))
		return Vector2(e, TAU - e)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 44, "na": 84, "rng": rgf, "top": func(_a): return top_y,
		"hem": func(a): return hem + 0.03 * (1.0 - smoothstep(e_h, e_h + 0.4, absf(float(a)))), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return co, "gain": 4.0, "th": 0.006, "inner": co.darkened(0.25), "skin": csk})
	for ed in [cg["ea"], cg["eb"]]:
		P._bd(k, ed, 0.0055, 0.003, co.darkened(0.06), false, csk, 0.0)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._bd(k, hm, 0.003, 0.0016, co.darkened(0.2), false, csk)
	# yama cepler: kalçanın iki yanında, üstü açık
	for sg in [1.0, -1.0]:
		var a0: float = sg * 1.12
		_pocket(k, keys, ff, a0, H - 0.04, 0.125, 0.15, co.lightened(0.02), csk)
	# dik yaka: önü açık, ağzı rulo
	var q: float = _hq(k)
	var ck := [[N + 0.1 * q, nk.x + 0.055, nk.y + 0.05, nk.z - 0.06], [N + 0.04 * q, nk.x + 0.042, nk.y + 0.04, nk.z - 0.05], [N - 0.03, nk.x + 0.06, nk.y + 0.05, nk.z - 0.05]]
	var kg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 48, "rng": func(_v): return Vector2(0.62, TAU - 0.62), "top": func(a): return N + q * lerpf(0.06, 0.1, smoothstep(0.6, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.025,
		"fold": func(a, _y, v): return 0.01 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return co.lightened(0.02), "inner": co.darkened(0.25), "skin": func(p): return _nsk(k, p), "th": 0.006})
	P._cord(k, kg["top"], 0.0045, co.darkened(0.04), false, func(p): return _nsk(k, p))
	# kollar: bileğe, geniş katlı manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.7 if sd == "Left" else 0.6
		var sf := func(s: float, a: float) -> float:
			return 0.014 + 0.01 * smoothstep(en, 0.85, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.12) / 0.1, 2.0))
		P._lt(k, ar, sf, func(s, a, ins): return co.darkened(0.35) if ins else P._fs(co, float(sf.call(float(s), float(a))) - 0.014 - 0.01 * smoothstep(float(en), 0.85, float(s)), 12.0), 0.0, 0.95, 30, 20, 0.02)
		var cf := func(s: float, a: float) -> float: return float(sf.call(s, a)) + 0.012 + 0.006 * smoothstep(0.82, 0.95, s) + 0.0015 * sin(a * 6.0)
		P._lt(k, ar, cf, func(s, _a, ins): return co.darkened(0.3) if ins else co.darkened(0.04 + 0.12 * float(float(s) < 0.835)), 0.82, 0.955, 6, 22, 0.08)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.006, co.darkened(0.3), 0.86, 0.955, 4, 22)
	P._cur_hem = hem


## File yama (adımı seyrek düz parçalar: köşe bütçesi): a0..a1 açı, y0..y1 boy
static func _net(k, keys: Array, a0: float, a1: float, y0: float, y1: float, pitch: float, hw: float, lift: float, col: Color) -> void:
	var R0 := 0.15
	var step := 0.075
	for dr in [1.0, -1.0]:
		var c: float = -(y1 - y0) - (a1 - a0) * R0
		while c < (y1 - y0) + (a1 - a0) * R0:
			var run := []
			var w := 0.0
			while w <= (a1 - a0) + 0.0001:
				var y: float = y0 + (y1 - y0) * 0.5 + w * R0 * dr + c
				if y >= y0 and y <= y1:
					run.append(Vector2(a0 + w, y))
				elif run.size() >= 2:
					break
				w += step
			if run.size() >= 2:
				var pts := []
				var ou := []
				for q in run:
					var e: Array = _spt(keys, Callable(), q.x, q.y, lift)
					pts.append(e[0])
					ou.append(e[1])
				k.strip(pts, ou, hw, 0.0012, col, false, func(p): return k.torso_skin(p.y))
			c += pitch


## Kemer tokası: çerçeve + dil
static func _buckle(k, c: Vector3, o: Vector3, w: float, h: float, col: Color, bones: Array) -> void:
	var up := (Vector3.UP - o * Vector3.UP.dot(o)).normalized()
	var ri := up.cross(o).normalized()
	var pts := [c + ri * w + up * h, c - ri * w + up * h, c - ri * w - up * h, c + ri * w - up * h]
	var lp := []
	for i in 4:
		for t in 4:
			lp.append((pts[i] as Vector3).lerp(pts[(i + 1) % 4], float(t) / 4.0))
	P._tb(k, lp, func(_s, _a): return 0.0032, func(_s, a, _p): return col.lightened(0.15) if cos(float(a)) > 0.3 else col, func(_s, _p): return bones, 6, true)
	P._tb(k, [c + up * h * 0.9, c - up * h * 0.9], func(_s, _a): return 0.0022, func(_s, _a, _p): return col.darkened(0.1), func(_s, _p): return bones, 6)


## Palto yama cebi: kumaşa oturan yastık + üst ağız bandı
static func _pocket(k, keys: Array, ff: Callable, a0: float, y0: float, w: float, h: float, col: Color, skinf: Callable) -> void:
	var mp: Callable = _local(keys, ff, a0, y0)
	var o: Vector3 = _spt(keys, ff, a0, y0)[1]
	var rows := []
	var nu := 10
	var nv := 10
	for j in nv + 1:
		var v := float(j) / nv
		var ro := []
		for i in nu + 1:
			var u := float(i) / nu
			var ed: float = minf(minf(u, 1.0 - u) * w, minf(v, 1.0 - v) * h)
			var cham: float = 1.0 - 0.12 * smoothstep(0.6, 1.0, v) * (1.0 - smoothstep(0.0, 0.35, minf(u, 1.0 - u)))
			ro.append(mp.call((u - 0.5) * w * cham, (0.5 - v) * h, -0.001 + 0.006 * smoothstep(0.0, 0.012, ed)))
		rows.append(ro)
	_mesh(k, rows, false, func(i, j, _p):
		var e3: float = minf(minf(float(i) / nu, 1.0 - float(i) / nu), minf(float(j) / nv, 1.0 - float(j) / nv))
		return col.darkened(0.2) if e3 < 0.08 else col, func(_i, _j, p): return skinf.call(p), o)
	var bp := []
	var bo := []
	for i in 13:
		var u := float(i) / 12.0
		var p: Vector3 = mp.call((u - 0.5) * w, h * 0.5 - 0.012, 0.007)
		bp.append(p)
		bo.append(o)
	k.strip(bp, bo, 0.011, 0.002, col.darkened(0.05), false, skinf)


# ------------------------------------------------------------------ Kemuri Jōnin (ref Shinobi Striker "Asuma Outfit"): lacivert takım + Konoha yeleği (parti j yardımcılarıyla), üst kolda beyaz sargı bandı ve kızıl girdap,
## belde 火 dairesi işli açık mavi üçgen örtü, koyu bilezikler, baldır sargısı
static func _sigara(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var ve := Color(0.3, 0.335, 0.3)
	var red := Color(0.72, 0.17, 0.14)
	var wh := Color(0.9, 0.9, 0.88)
	var lb := Color(0.82, 0.86, 0.92)
	var dk := Color(0.13, 0.11, 0.13)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = J.P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	J.P._cur_leg = 0.58
	var L: Dictionary = J._suit(k, b, nv, nv.darkened(0.04), {"bag": 0.016, "tuck": 0.24, "seed": 2.2, "cuff": nv.lightened(0.05)})
	# yelek: kalın alt rulo, panel oluğu
	var vk := [J.P._kp(nk, N + 0.005, 0.032), [N - 0.055, ch.x * 0.99, ch.y * 0.93, ch.z * 1.05], J.P._kp(ch, C - 0.03, 0.032), J.P._kp(wa, H + 0.13, 0.032), J.P._kp(wa, H + 0.095, 0.028), J.P._kp(wa, H + 0.06, 0.06), J.P._kp(wa, H + 0.02, 0.056), J.P._kp(wa, H - 0.008, 0.028)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.03 * exp(-pow(a / 0.028, 2.0)) - 0.014 * exp(-pow((aa - 1.68) / 0.05, 2.0)) - 0.012 * exp(-pow((aa - 2.6) / 0.05, 2.0))
		if y > H + 0.1:
			g += 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.11, y)
		else:
			g += 0.009 * sin(a * 12.0 + 0.4) * smoothstep(H + 0.1, H + 0.04, y)
		return g
	J.P._sheet(k, vk, 56, 88, Callable(), fold, func(a, y, _u, v, _p):
		var c0: Color = J.P._fs(ve, fold.call(a, y, 0.0), 7.0)
		if y < H + 0.105 and y > H + 0.082:
			c0 = c0.darkened(0.25)
		return c0.darkened(0.2) if v > 0.96 else c0, 0.007, 0.25)
	J._collar(k, [J.P._kp(nk, N + 0.095, 0.03, 0.04), J.P._kp(nk, N + 0.05, 0.03, 0.038), J.P._kp(nk, N - 0.02, 0.05, 0.05)], 0.82, 0.3, ve, ve.lightened(0.08))
	var cc := Vector3(0.0, C, 0.0)
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.72, 2.32, float(v))
			var y: float = lerpf(N - 0.012, N - 0.08, float(u))
			return J.P._sa(vk, a, y, 0.0)[0]
		J._pil(k, surf, 12, 14, 0.013, ve.lightened(0.04), cc, 0.16)
		var e: Vector3 = surf.call(0.66, 0.2)
		var o: Vector3 = J._nrm(surf, 0.66, 0.2, cc)
		J.P._fan(k, e + o * 0.0155, o, Vector3.UP, 0.0095, Callable(), func(u2, v2): return ve.darkened(0.42) if sqrt(u2 * u2 + v2 * v2) > 0.7 else Color(0.82, 0.82, 0.8), k.torso_skin(N - 0.04), 3, 14)
		J._pouch(k, vk, sg * ch.x * 0.47, C - 0.11, ch.x * 0.54, 0.125, 3, ve.darkened(0.05), ve.lightened(0.12), sg * -0.01)
	J.P._strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.0)], true, 0.0052, 0.0, 0.0035, Color(0.86, 0.87, 0.86), 26)
	J._swirl(k, vk, 0.0, C - 0.07, 0.075, red, false)
	# kollar: beyaz sargı bandı, girdap, bilezik; bacaklar: baldır sargısı
	for sd in ["Left", "Right"]:
		var e2: Dictionary = L[sd]
		var ar: Dictionary = e2["ar"]
		var sl: Callable = e2["sl"]
		J._arm_swirl(k, ar, 0.15, 0.028, red, 0.013)
		for i in 4:
			var s: float = 0.3 + 0.026 * i
			k.wrap_turn(P._lp(ar, s), P._ld(ar, s), P._lr(ar, s) + float(sl.call(s, 0.0)) + 0.006, 0.0115, 0.003, wh.darkened(0.06 * float(i % 2)), P._lskin(ar, s))
		var sb: float = 0.92
		k.wrap_turn(P._lp(ar, sb), P._ld(ar, sb), P._lr(ar, sb) + float(sl.call(sb, 0.0)) + 0.009, 0.011, 0.0, dk, P._lskin(ar, sb))
		k.wrap_turn(P._lp(ar, sb - 0.022), P._ld(ar, sb), P._lr(ar, sb - 0.022) + float(sl.call(sb - 0.022, 0.0)) + 0.008, 0.007, 0.0, dk.lightened(0.08), P._lskin(ar, sb - 0.022))
		J._shin_tape(k, e2["le"], e2["pf"], float(e2["le"]["kn"]) + 0.28, 10, wh)
	# 火 örtüsü: belde ince kuşak, önde üçgen sarkar
	var fk := [J.P._kp(wa, H + 0.0, 0.03), J.P._kp(hp, H - 0.04, 0.032), [H - 0.2, hp.x + 0.03, hp.y + 0.034, hp.z - 0.03]]
	var tri_h: float = 0.19
	var tf := func(a: float, _y: float, _v: float) -> float: return 0.003 * sin(a * 9.0)
	J.P._cur_hem = H - tri_h
	P._cur_hem = H - tri_h
	var tg: Dictionary = P._cl(k, {"keys": fk, "ny": 14, "na": 44, "rng": func(_v): return Vector2(-0.95, 0.95), "top": func(_a): return H + 0.0, "hem": func(a): return H - 0.01 - tri_h * pow(1.0 - clampf(absf(float(a)) / 0.95, 0.0, 1.0), 0.9),
		"fold": tf, "col": func(_a, _y, _v): return lb, "gain": 5.0, "th": 0.004, "inner": lb.darkened(0.3)})
	P._bd(k, tg["hem"], 0.0032, 0.0016, lb.darkened(0.22), false, func(p): return P._hs(k, p))
	P._sash(k, fk, H + 0.0, 0.012, 0.004, lb.darkened(0.04), 0.1)
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var mp: Callable = _local(fk, tff, 0.0, H - 0.075)
	var mo: Vector3 = _spt(fk, tff, 0.0, H - 0.075)[1]
	var hs := func(p): return P._hs(k, p)
	_disc(k, mp, mo, 0.042, 0.003, Callable(), func(u, v): return dk.lightened(0.1) if Vector2(float(u), float(v)).length() > 0.88 else dk, hs, 4, 32)
	_circle(k, mp, 0.031, 0.0022, 0.0062, red, hs, 32)
	for st in A.G_HI:
		var p0 := Vector2(float(st[0]), float(st[1])) * 0.021
		var p1 := Vector2(float(st[2]), float(st[3])) * 0.021
		var pts := []
		var ou := []
		for i in 4:
			var t := float(i) / 3.0
			var pp: Vector2 = p0.lerp(p1, t)
			pts.append(mp.call(pp.x, pp.y, 0.0062))
			ou.append(mo)
		k.strip(pts, ou, 0.0032, 0.0016, red, false, hs)
	P._cur_hem = H - tri_h


# ------------------------------------------------------------------ Rokudō Koromo (ref Shinobi Striker "Asura Outfit"): yüksek dik yakalı beyaz cübbe, göğüste 6 / sırtta Rinnegan halkası altında 9 tomoe, geniş lacivert obi,
## içi koyu çok geniş kollar, sol üstte biten kruvaze göğüs, siyah pantolon
static func _alti(k) -> void:
	var wh := Color(0.933, 0.933, 0.949)
	var lv := Color(0.8, 0.76, 0.92)
	var ob := Color(0.13, 0.15, 0.32)
	var bk := Color(0.094, 0.094, 0.11)
	var tm := Color(0.06, 0.06, 0.07)
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
	P._inner(k, b, func(_i, _j, _p): return wh.darkened(0.1), 0.006)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, bk, 0.009, 0.01, 1.0, 1.8 if sd == "Left" else 0.7)
	var hem: float = lerpf(KN, F, 0.48)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.045), P._kp(hp, H - 0.04, 0.05),
		[KN + 0.05, hp.x + 0.085, hp.y + 0.075, hp.z - 0.1], [hem, hp.x + 0.12, hp.y + 0.09, hp.z - 0.14]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		return pow(t, 0.9) * ((0.026 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.013 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
	var csk := func(p): return _csk(k, p, hem)
	# cübbe: tek parça, sol kanat sağın üstüne biner (önde kayık kapanış); bindirmenin üst kanadı hafif kalkık
	var ny := 52
	var na := 96
	var ov := 0.34
	var top_y: float = N + 0.012
	var rows := []
	var angs := []
	for j in ny + 1:
		var y := lerpf(top_y, hem, float(j) / ny)
		var ro := []
		var ar2 := []
		for i in na + 1:
			var u := float(i) / na
			var a := lerpf(-0.1, TAU - 0.1 + ov, u)
			var lift: float = 0.011 * smoothstep(TAU - 0.2, TAU - 0.05, a)
			var e: Array = _spt(keys, ff, a, y, lift)
			var p: Vector3 = e[0]
			ro.append(Vector3(-p.x, p.y, p.z))
			ar2.append(-wrapf(a, -PI, PI))
		ro.reverse()
		ar2.reverse()
		rows.append(ro)
		angs.append(ar2)
	var outer: Array = rows.duplicate()
	var src := []
	for j in ny + 1:
		src.append([j, false])
	var inw := func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
	var roll := []
	for p in outer[ny]:
		roll.append(inw.call(p, 0.004) + Vector3(0, -0.004, 0))
	rows.append(roll)
	src.append([ny, true])
	var j2: int = ny
	while float(outer[j2][0].y) < H - 0.02:
		var ro := []
		for p in outer[j2]:
			ro.append(inw.call(p, 0.008))
		rows.append(ro)
		src.append([j2, true])
		j2 -= 3
	k.grid(rows, false, func(i, j, _p):
		var e2: Array = src[j]
		if e2[1]:
			return wh.darkened(0.3)
		var oj: int = e2[0]
		var y: float = outer[oj][0].y
		var a: float = angs[oj][i]
		var f: float = ff.call(a, y)
		var c0: Color = P._fs(wh, f, 4.0)
		var side: float = exp(-pow((absf(a) - 1.45) / 0.22, 2.0)) * smoothstep(H - 0.1, C - 0.05, y) * (1.0 - smoothstep(C + 0.02, N - 0.05, y))
		return c0.lerp(lv, side * 0.7), func(_i, _j, p): return csk.call(p))
	# bindirme kenarı: sağ yanda yakadan etek ucuna; göğüste sola kayan çapraz kat
	var ed := []
	for j in range(2, ny + 1):
		ed.append(outer[j][0])
	P._bd(k, ed, 0.0035, 0.002, wh.darkened(0.14), false, csk, 0.0)
	_run(k, keys, ff, [Vector2(-0.42, C + 0.025), Vector2(-0.2, C + 0.045), Vector2(0.05, C + 0.075)], 0.0028, 0.002, 0.0018, wh.darkened(0.25), csk, 6)
	var hm := []
	for p in outer[ny]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._bd(k, hm, 0.003, 0.0016, wh.darkened(0.16), false, csk)
	# geniş obi + önde dikiş
	var obk := [P._kp(wa, H + 0.12, 0.05), P._kp(wa, H + 0.0, 0.06)]
	var by: float = H + 0.065
	P._sash(k, obk, by, 0.042, 0.008, ob, 0.14)
	P._sash(k, obk, by + 0.004, 0.034, 0.014, ob.lightened(0.04), 0.0)
	# yüksek dik yaka: önü V açık, içi leylak
	var q: float = _hq(k)
	var ck := [[N + 0.14 * q, nk.x + 0.06, nk.y + 0.05, nk.z - 0.065], [N + 0.06 * q, nk.x + 0.042, nk.y + 0.036, nk.z - 0.048], [N - 0.0, nk.x + 0.042, nk.y + 0.036, nk.z - 0.044], [N - 0.05, nk.x + 0.07, nk.y + 0.06, nk.z - 0.055]]
	var crg := func(v) -> Vector2:
		var e: float = lerpf(0.66, 0.2, float(v))
		return Vector2(e, TAU - e)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 14, "na": 52, "rng": crg, "top": func(a): return N + q * lerpf(0.1, 0.14, smoothstep(0.6, 2.2, absf(float(a)))), "hem": func(_a): return N - 0.045,
		"fold": func(a, _y, v): return 0.006 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return wh, "inner": lv, "skin": func(p): return _nsk(k, p), "th": 0.007})
	P._cord(k, cg["top"], 0.004, wh.darkened(0.08), false, func(p): return _nsk(k, p))
	for e3 in [cg["ea"], cg["eb"]]:
		P._cord(k, e3, 0.0035, wh.darkened(0.1), false, func(p): return _nsk(k, p))
	# göğüste 6 tomoe: iki yanda yakayı izleyen yay
	var tsk := func(p): return k.torso_skin(p.y)
	for sg in [1.0, -1.0]:
		for e4 in [[1.02, N - 0.035, 0.9], [0.84, N - 0.075, 1.3], [0.62, C + 0.025, 1.7]]:
			var a: float = sg * float(e4[0])
			var mp: Callable = _local(keys, ff, a, float(e4[1]))
			_tomoe(k, mp, _spt(keys, ff, a, float(e4[1]))[1], 0.0125, 0.2, 0.004, tm, tsk, wh)
	# sırtta Rinnegan halkası ve altında 9 tomoe
	var mb: Callable = _local(keys, ff, PI, C + 0.0)
	var bo: Vector3 = _spt(keys, ff, PI, C)[1]
	for r in [0.07, 0.052, 0.034, 0.016]:
		_circle(k, mb, r, 0.0028, 0.004, tm, tsk, 44)
	_disc(k, mb, bo, 0.006, 0.004, Callable(), func(_u, _v): return tm, tsk, 2, 12)
	for i in 9:
		var t := float(i) / 8.0
		var u: float = lerpf(-0.12, 0.12, t)
		var v: float = -0.11 - 0.02 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		var mp2: Callable = _local(keys, ff, PI - u / 0.16, C + v)
		_tomoe(k, mp2, _spt(keys, ff, PI - u / 0.16, C + v)[1], 0.011, 0.2, 0.004, tm, tsk, wh)
	# çok geniş kollar: alt yanı sarkık torba, içi leylak-gri astar, altta koyu gri iç kol
	var ln: Color = wh.darkened(0.3).lerp(lv, 0.45)
	var ia := Color(0.3, 0.29, 0.34)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 2.0 if sd == "Left" else 0.8
		var s1 := 0.93
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.08, s1, s)
			var hang: float = maxf(0.0, -sin(a) * sg)
			var nar: float = smoothstep(s1 - 0.2, s1, s)   # ağız bileğe doğru biraz toplanır: koşuda kameraya dönünce kocaman delik açmaz
			return 0.018 + 0.052 * fl - 0.012 * nar + (0.034 - 0.01 * nar) * fl * hang * hang + (0.003 + 0.008 * fl) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins):
			if ins:
				return ln   # astar: açık leylak-gri (ağızdan bakınca kara delik değil kumaş)
			var f: float = float(sf.call(float(s), float(a))) - 0.018 - 0.052 * smoothstep(0.08, s1, float(s))
			var under: float = smoothstep(0.2, 0.9, maxf(0.0, -sin(float(a)) * sg)) * smoothstep(0.15, 0.5, float(s))
			return P._fs(wh, f, 9.0).lerp(lv, under * 0.55), 0.0, s1, 32, 26, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, ln.lightened(0.08), 0.45, s1, 12, 26)
		P._lt(k, ar, func(s, _a): return 0.006 + 0.004 * smoothstep(0.7, 0.95, float(s)), func(_s, _a, ins): return ia.darkened(0.3) if ins else ia, 0.4, 0.975, 16, 16)
	P._cur_hem = hem
