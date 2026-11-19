extends RefCounted
## Elle modellenmiş setler, parti aj: ss_yaz, ss_kizil_takim, ss_turuncu_ceket, ss_siyah_ceket, ss_esofman_turuncu2, ss_yirtik_esofman. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), q (Q), r (R), s (S), i (I) dosyalarından; burada eşofman / ceket kesimleri (dik yaka, fermuar, lastikli bant), el sargısı, kapri, bot konçu ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const I = preload("res://scripts/actors/set_el_i.gd")

const DONE := ["ss_yaz", "ss_kizil_takim", "ss_turuncu_ceket", "ss_siyah_ceket", "ss_esofman_turuncu2", "ss_yirtik_esofman"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_yaz": _yaz(k)
		"ss_kizil_takim": _kizil(k)
		"ss_turuncu_ceket": _turuncu(k)
		"ss_siyah_ceket": _siyah(k)
		"ss_esofman_turuncu2": _kapusonlu(k)
		"ss_yirtik_esofman": _yirtik(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Ceket gövdesi anahtarları: p bolluk, ph etek bolluğu
static func _jkeys(k, b: Dictionary, top: float, hem: float, p: float, ph: float) -> Array:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var hp: Vector3 = b["hp"]
	var mid: Vector3 = k.M(k.C - 0.12, k.UA)
	return [P._kp(nk, top, p * 0.9), [k.N - 0.055, ch.x * 1.03, ch.y * 0.97 + p * 0.5, ch.z * 1.06 - p * 0.5], P._kp(ch, k.C - 0.03, p), P._kp(mid, k.C - 0.12, p * 1.1),
		P._kp(b["wa"], k.H + 0.12, p * 1.2), [hem, hp.x + ph, hp.y + ph, hp.z - ph]]


## Ceket ağırlığı: belin üstü gövdeyle, altı bacakla hafif açılır (kalkan uyluk eteği delmez)
static func _jsk(k, hem: float) -> Callable:
	var H: float = k.H
	return func(p): return k.torso_skin(maxf(float(p.y), H + 0.005)) if float(p.y) > H - 0.02 else k.cloth_skin(p, hem - 0.04, 0.4)


## Dik yaka: üstü hafif açılır; gap ön açıklık (fermuarlı kapalı yakada küçük)
static func _stand(k, nk: Vector3, h: float, gap: float, outc: Color, inc: Color, pad := 0.034, flare := 0.008) -> Dictionary:
	var N: float = k.N
	var q: float = Q._hq(k)
	var ck := [[N + h * q, nk.x + pad + flare, nk.y + pad - 0.002 + flare, nk.z - pad - 0.006 - flare], [N + h * 0.4 * q, nk.x + pad, nk.y + pad - 0.002, nk.z - pad - 0.006],
		[N - 0.025, nk.x + pad + 0.016, nk.y + pad + 0.012, nk.z - pad - 0.012]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 50, "rng": func(_v): return Vector2(gap, TAU - gap),
		"top": func(a): return N + q * h * lerpf(0.86, 1.0, smoothstep(0.4, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.02,
		"fold": func(a, _y, v): return 0.007 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.5), "col": func(_a, _y, _v): return outc, "inner": inc, "skin": func(p): return Q._nsk(k, p), "th": 0.007})
	P._cord(k, cg["top"], 0.0042, outc.lightened(0.05), false, func(p): return Q._nsk(k, p))
	return cg


## Fermuar: bant + dişler + çekme ucu, ön ortada (a = 0) yukarıdan aşağı
static func _zip(k, keys: Array, ff: Callable, y0: float, y1: float, tape: Color, teeth: Color, skinf: Callable, pull := true) -> void:
	Q._run(k, keys, ff, [Vector2(0.0, y0), Vector2(0.0, y1)], 0.0075, 0.0015, 0.0018, tape, skinf, 24)
	Q._run(k, keys, ff, [Vector2(0.0, y0), Vector2(0.0, y1)], 0.0028, 0.0035, 0.0016, teeth, skinf, 24)
	if pull:
		var e: Array = Q._spt(keys, ff, 0.0, y0 - 0.016, 0.006)
		P._boxr(k, e[0], Vector3(0.0045, 0, 0), Vector3(0, 0.012, 0), (e[1] as Vector3) * 0.0025, teeth.lightened(0.1), k.torso_skin(y0 - 0.016), 0.3)


## Lastikli bant (kol / paça): ince fitiller, içi astar
static func _rib(k, l: Dictionary, s0: float, s1: float, add: float, col: Color, ribs := 14.0) -> void:
	P._lt(k, l, func(s, a): return add + 0.0018 * sin(float(a) * ribs) - 0.002 * smoothstep(s1 - 0.035, s1, float(s)), func(_s, a, ins):
		return col.darkened(0.3) if ins else col.darkened(0.12 * float(sin(float(a) * ribs) < 0.0)), s0, s1, 6, 28)
	K._lt_in(k, l, func(s, a): return add + 0.0018 * sin(float(a) * ribs) - 0.004, col.darkened(0.3), s0 + 0.015, s1, 4, 28)


## Kol: omuzdan s1'e; dirsek kırışığı, manşet üstünde toplanma
static func _sleeve(k, ar: Dictionary, col: Color, s1: float, sv: float, add0: float, puff: float, inc := Color(0, 0, 0, 0)) -> Callable:
	var en: float = ar["kn"]
	var sf := func(s: float, a: float) -> float:
		var bunch: float = 0.006 * exp(-pow((s - (s1 - 0.05)) / 0.04, 2.0)) * (1.0 + sin(a * 8.0 + sv))
		return add0 + puff * smoothstep(0.1, 0.5, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.009 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + bunch
	var ic: Color = inc if inc.a > 0.0 else col.darkened(0.3)
	P._lt(k, ar, sf, func(s, a, ins): return ic if ins else P._fs(col, float(sf.call(float(s), float(a))) - add0 - puff * smoothstep(0.1, 0.5, float(s)), 10.0), 0.0, s1, 32, 20, 0.02)
	return sf


## Kapri / pantolon bacağı: dizde bolluk, iç yan daralır, ağız bacağa yaklaşır (koşuda boş halka görünmez)
static func _pleg(k, le: Dictionary, col: Color, s1: float, base: float, bag: float, sv: float, taper := 0.45, colf := Callable(), inc := Color(0, 0, 0, 0)) -> Callable:
	var kn: float = le["kn"]
	var sg: float = le["sg"]
	var fo := func(s: float, a: float) -> float:
		var cr: float = exp(-pow((s - kn) / 0.07, 2.0)) * sin(a * 3.0 + s * 34.0 + sv)
		return (0.004 + bag * 0.12) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + 0.005 * cr
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = base + bag * exp(-pow((s - kn + 0.08) / 0.22, 2.0)) * (1.0 - 0.35 * inn)
		var tp: float = 1.0 - taper * smoothstep(s1 - 0.08, s1, s)
		return v * tp + float(fo.call(s, a))
	var ic: Color = inc if inc.a > 0.0 else col.darkened(0.22)
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return ic
		var c0: Color = colf.call(float(s), float(a)) if colf.is_valid() else col
		return P._fs(c0, float(fo.call(float(s), float(a))), 10.0), 0.0, s1, 36, 22, 0.03)
	return ad


## Kıvrık paça: pantolonun ucuna dönen kalın kat (dışı col, kat çizgisi koyu)
static func _turnup(k, le: Dictionary, ad: Callable, s1: float, w: float, add: float, col: Color) -> void:
	var L: float = ((le["p1"] as Vector3) - (le["p0"] as Vector3)).length() + ((le["p2"] as Vector3) - (le["p1"] as Vector3)).length()
	var sw: float = w / L
	var rf := func(s, a): return float(ad.call(float(s), float(a))) + add + 0.003 * sin(clampf((float(s) - s1 + sw) / sw, 0.0, 1.0) * PI) + 0.0012 * sin(float(a) * 5.0)
	P._lt(k, le, rf, func(s, a, ins):
		if ins:
			return col.darkened(0.3)
		return col.darkened(0.18) if float(s) < s1 - sw + 0.006 else col.darkened(0.06 * float(sin(float(a) * 5.0) < 0.0)), s1 - sw, s1 + 0.004, 6, 24)


## Bot konçu: bileğe iner; üstte katlı ağız, iki kayış
static func _boot(k, le: Dictionary, s0: float, col: Color, strap: Color) -> Callable:
	var bt := func(s: float, a: float) -> float: return 0.011 + 0.004 * smoothstep(s0 + 0.06, s0, s) + 0.0015 * sin(a * 3.0 + s * 40.0) * smoothstep(s0 + 0.03, s0 + 0.1, s)
	P._lt(k, le, bt, func(s, a, ins): return col.darkened(0.35) if ins else P._fs(col, 0.0015 * sin(float(a) * 3.0 + float(s) * 40.0), 10.0), s0, 0.995, 18, 20)
	P._lt(k, le, func(s, a): return float(bt.call(s, a)) + 0.0035, func(_s, _a, ins): return col.darkened(0.35) if ins else col.lightened(0.05), s0, s0 + 0.03, 3, 20)
	for ss in [s0 + 0.08, 0.9]:
		Q._ring_on(k, le, ss, bt, 0.0075, strap, 0.0022)
	return bt


## El sargısı: el sırtını ve avucu saran eğik turlar (parmaklar açık)
static func _hand_wrap(k, sd: String, col: Color) -> void:
	var hd: Vector3 = k.m._bp(sd + "Hand")
	var el: Vector3 = k.m._bp(sd + "LowerArm")
	var d: Vector3 = (hd - el).normalized()
	var w: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri: Vector3 = (-d).cross(w).normalized()
	var prof := [[-0.04, 0.03, 0.028], [-0.012, 0.031, 0.026], [0.02, 0.043, 0.025], [0.055, 0.051, 0.024], [0.08, 0.051, 0.022]]
	var at := func(x: float) -> Vector2:
		for i in prof.size() - 1:
			if x <= float(prof[i + 1][0]):
				var t: float = clampf(inverse_lerp(float(prof[i][0]), float(prof[i + 1][0]), x), 0.0, 1.0)
				return Vector2(lerpf(prof[i][1], prof[i + 1][1], t), lerpf(prof[i][2], prof[i + 1][2], t))
		return Vector2(prof[prof.size() - 1][1], prof[prof.size() - 1][2])
	for i in 7:
		var x0: float = lerpf(-0.03, 0.066, float(i) / 6.0)
		var rows := []
		for j in 4:
			var v := float(j) / 3.0
			var ro := []
			for q in 18:
				var a := TAU * q / 18.0 - PI
				var x: float = x0 + lerpf(-0.0075, 0.0075, v) + 0.006 * sin(a + float(i) * 1.3)
				var e: Vector2 = at.call(x)
				var bl: float = 0.0032 + 0.0018 * sin(v * PI)
				ro.append(hd + d * x + w * cos(a) * (e.x + bl) + ri * sin(a) * (e.y + bl))
			rows.append(ro)
		var bo := [[sd + "Hand", 1.0]] if x0 > 0.0 else [[sd + "Hand", 0.6], [sd + "LowerArm", 0.4]]
		var tone: Color = col.darkened(0.06 * float(i % 3))
		k.grid(rows, true, func(_i, j, _p): return tone.darkened(0.12) if j in [0, 3] else tone, func(_i, _j, _p): return bo)


## Sırt yazısı / desen: mp(u, v, kalkış) üstünde çizgi listesi (kabartma)
static func _strokes(k, mp: Callable, o: Vector3, cu: float, cv: float, s: float, strokes: Array, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	for st in strokes:
		var pts := []
		var ou := []
		for si in (st as Array).size() - 1:
			var p0: Vector2 = st[si]
			var p1: Vector2 = st[si + 1]
			for t in 4:
				var q: Vector2 = p0.lerp(p1, float(t) / 4.0)
				pts.append(mp.call(cu + q.x * s, cv + q.y * s, lift))
				ou.append(o)
		var pe: Vector2 = st[(st as Array).size() - 1]
		pts.append(mp.call(cu + pe.x * s, cv + pe.y * s, lift))
		ou.append(o)
		k.strip(pts, ou, hw, 0.0016, col, false, skinf)


## Uzuv kumaşına oturan dikdörtgen yama (dikiş çizgili)
static func _lpatch(k, l: Dictionary, ad: Callable, s: float, a: float, w: float, h: float, col: Color, stitch: Color) -> void:
	var mp: Callable = R._lmap(l, ad, s, a)
	var o: Vector3 = R._out_of(mp)
	var sk := func(p): return R._lsk(l, p)
	var asp: float = h / w
	Q._disc(k, mp, o, w, 0.0022, func(th): return 1.0 / maxf(absf(cos(th)), absf(sin(th)) / asp), func(_u, _v): return col, sk, 3, 24)
	var pts := []
	for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(Vector2(e.x * w * 0.8, e.y * h * 0.8))
	var path := []
	for i in 4:
		for t in 4:
			path.append((pts[i] as Vector2).lerp(pts[(i + 1) % 4], float(t) / 4.0))
	R._lstrip(k, mp, path, 0.0011, 0.0045, 0.0008, stitch, sk, true)


# ------------------------------------------------------------------ Natsu Shōzoku (ref Shinobi Striker "Naruto Outfit (Everlasting Summer ver.)"): lacivert kısa kollu tişört, üstünde kolsuz fermuarlı turuncu yelek
## (kapalı dik yaka, eğik yan cepler, sırtta kızıl girdap), kıvrık paçalı turuncu kapri, beyaz bileklikler, sağ uylukta sargılı kılıf
static func _yaz(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var og := Color(0.91, 0.52, 0.17)
	var wh := Color(0.93, 0.93, 0.91)
	var rd := Color(0.74, 0.2, 0.12)
	var mt := Color(0.72, 0.72, 0.74)
	var bk := Color(0.11, 0.11, 0.125)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return nv.lightened(0.04) if j < 4 else nv, 0.006, H - 0.03)
	K._seat(k, b, og)
	I._seat(k, b, og)
	# kapri: baldır ortasında, kalın kıvrık paça; altı çıplak; sağ uylukta sargılı kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.2
		var sv: float = 1.3 if sd == "Left" else 2.6
		P._bare(k, le, skc, s1 - 0.04, 1.0)
		var pa: Callable = _pleg(k, le, og, s1, 0.016, 0.022, sv, 0.4)
		_turnup(k, le, pa, s1, 0.048, 0.004, og.lightened(0.04))
		if sd == "Right":
			I._holster(k, le, pa, bk, bk.lightened(0.05), true)
	# tişört kolları: dirsek üstünde, kıvrık ağız; altı çıplak; beyaz bileklik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.9 if sd == "Left" else 2.2
		var s1: float = float(ar["kn"]) - 0.08
		R._arm_skin(k, ar, s1 - 0.05)
		var sl := func(s: float, a: float) -> float: return 0.012 + 0.006 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv)
		P._lt(k, ar, sl, func(s, a, ins): return nv.darkened(0.3) if ins else P._fs(nv, float(sl.call(float(s), float(a))) - 0.016, 14.0), 0.0, s1, 18, 20, 0.03)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return nv.darkened(0.3) if ins else nv.lightened(0.05), s1 - 0.03, s1 + 0.002, 3, 20)
		_rib(k, ar, 0.86, 0.95, 0.007, wh, 16.0)
	# yelek: kalçaya iner, önü fermuarlı, kolsuz
	var hem: float = H - 0.06
	var vk: Array = _jkeys(k, b, N + 0.012, hem, 0.03, 0.036)
	var vf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.25, 0.6, aw) * (t * (0.012 * sin(a * 7.0 + 0.4) + 0.005 * sin(a * 13.0 + 1.1)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 16.0))
	var jsk: Callable = _jsk(k, hem)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 40, "na": 88, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return vf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return og, "gain": 7.0, "th": 0.006, "inner": og.darkened(0.3), "skin": jsk})
	var hm := []
	for p in vg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._cord(k, hm, 0.0022, og.darkened(0.18), true, jsk)
	var vff := func(a, y): return vf.call(float(a), float(y))
	_zip(k, vk, vff, N + 0.0, hem + 0.004, og.darkened(0.12), mt, jsk)
	# eğik yan cepler: ağız bandı + alt dikiş
	for sg in [1.0, -1.0]:
		Q._run(k, vk, vff, [Vector2(sg * 0.62, H + 0.085), Vector2(sg * 0.78, H - 0.015)], 0.0075, 0.002, 0.003, og.darkened(0.14), jsk, 8)
		Q._run(k, vk, vff, [Vector2(sg * 0.6, H + 0.098), Vector2(sg * 0.76, H - 0.0)], 0.0014, 0.0025, 0.001, og.darkened(0.3), jsk, 8)
	J._swirl(k, vk, 0.0, C - 0.04, 0.056, rd, false)
	# dik yaka: kapalı, fermuar yakaya çıkar
	var cg: Dictionary = _stand(k, nk, 0.07, 0.05, og, og.darkened(0.2), 0.03, 0.006)
	var nsk := func(p): return Q._nsk(k, p)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.003, mt, false, nsk)


# ------------------------------------------------------------------ Akagumi Ressha (ref Shinobi Striker "Naruto Outfit (Tracksuit)"): beyaz tişört + dik beyaz yaka, göğse kadar fermuarlı koyu kızıl eşofman ceketi
## (lastikli etek ve manşet, sırtta beyaz çerçeveli kızıl pano içinde 紅組 yazısı), bol kızıl eşofman altı: diz altında beyaz astarlı kıvrık paça, altı çıplak baldır
static func _kizil(k) -> void:
	var cr := Color(0.43, 0.075, 0.1)
	var wh := Color(0.95, 0.95, 0.95)
	var rb := Color(0.72, 0.1, 0.13)
	var mt := Color(0.74, 0.74, 0.76)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return wh, 0.006, H - 0.03)
	K._seat(k, b, cr)
	I._seat(k, b, cr)
	# eşofman altı: bol, diz altında kıvrılmış (beyaz astar dışa dönük)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.16
		var sv: float = 2.0 if sd == "Left" else 0.7
		P._bare(k, le, skc, s1 - 0.04, 1.0)
		var pa: Callable = _pleg(k, le, cr, s1, 0.02, 0.03, sv, 0.3, Callable(), wh.darkened(0.2))
		_turnup(k, le, pa, s1, 0.062, 0.0045, wh)
	# ceket gövdesi: göğüs altına kadar fermuarlı, üstte V açıklık
	var hem: float = H - 0.035
	var top: float = N + 0.012
	var yz: float = C + 0.02
	var jk: Array = _jkeys(k, b, top, hem, 0.036, 0.044)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.2, 0.6, aw) * (t * (0.016 * sin(a * 7.0 + 0.5) + 0.007 * sin(a * 15.0 + 1.3)) + (1.0 - t) * 0.007 * sin(a * 4.0 + y * 18.0) * smoothstep(N - 0.02, C - 0.05, y))
	var vz: float = (top - yz) / (top - hem)
	var jsk: Callable = _jsk(k, hem)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 44, "na": 92, "rng": func(v):
		var e: float = lerpf(0.36, 0.0, smoothstep(0.0, vz, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return cr, "gain": 8.0, "th": 0.006, "inner": cr.darkened(0.3), "skin": jsk})
	var jff := func(a, y): return jf.call(float(a), float(y))
	for ed in [jg["ea"], jg["eb"]]:
		var pts: Array = []
		for p in ed:
			if float(p.y) > yz - 0.004:
				pts.append(p)
		P._bd(k, pts, 0.0035, 0.0028, mt, false, jsk, 0.0)
	_zip(k, jk, jff, yz, hem + 0.004, cr.darkened(0.2), mt, jsk)
	# lastikli etek bandı
	var lo: Vector3 = k.M(hem - 0.04, 0.3)
	var rk := [P._kp(b["hp"], hem + 0.004, 0.044), P._kp(lo, hem - 0.04, 0.026)]
	P._cl(k, {"keys": rk, "ny": 5, "na": 160, "top": func(_a): return hem + 0.004, "hem": func(_a): return hem - 0.04,
		"fold": func(a, _y, _v): return 0.011 * sin(float(a) * 40.0), "col": func(_a, _y, _v): return cr.darkened(0.06), "gain": 12.0, "th": 0.006, "inner": cr.darkened(0.3), "skin": _jsk(k, hem - 0.04)})
	Q._run(k, rk, func(_a, _y): return 0.0, [Vector2(0.0, hem + 0.004), Vector2(0.0, hem - 0.04)], 0.0028, 0.006, 0.0016, mt, _jsk(k, hem - 0.04), 6)
	# beyaz dik yaka: geniş açık, üstü dışa kıvrık
	var cg: Dictionary = _stand(k, nk, 0.085, 0.42, wh, wh.darkened(0.08), 0.03, 0.016)
	var nsk := func(p): return Q._nsk(k, p)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.0032, wh.darkened(0.05), false, nsk)
	# sırt panosu: beyaz çerçeve, kızıl zemin, beyaz 紅組
	var cy: float = C - 0.05
	var mb: Callable = Q._local(jk, jff, PI, cy)
	var o: Vector3 = Q._spt(jk, jff, PI, cy)[1]
	var tsk := func(p): return k.torso_skin(p.y)
	Q._disc(k, mb, o, 0.098, 0.004, func(th): return 1.0 / maxf(absf(cos(th)), absf(sin(th)) / 0.64), func(_u, _v): return wh, tsk, 3, 32)
	Q._disc(k, mb, o, 0.088, 0.0055, func(th): return 1.0 / maxf(absf(cos(th)), absf(sin(th)) / 0.6), func(_u, _v): return rb, tsk, 3, 32)
	var ito := [[Vector2(-0.2, 0.46), Vector2(-0.4, 0.2), Vector2(-0.18, 0.2)], [Vector2(-0.12, 0.36), Vector2(-0.42, -0.02), Vector2(-0.06, 0.03)], [Vector2(-0.26, 0.02), Vector2(-0.26, -0.46)],
		[Vector2(-0.4, -0.16), Vector2(-0.47, -0.34)], [Vector2(-0.13, -0.16), Vector2(-0.06, -0.32)]]
	var ko := [[Vector2(0.06, 0.34), Vector2(0.44, 0.34)], [Vector2(0.25, 0.34), Vector2(0.25, -0.36)], [Vector2(0.02, -0.38), Vector2(0.48, -0.38)]]
	var so := [[Vector2(0.1, 0.42), Vector2(0.1, -0.34)], [Vector2(0.1, 0.42), Vector2(0.4, 0.42), Vector2(0.4, -0.34)], [Vector2(0.1, 0.14), Vector2(0.4, 0.14)], [Vector2(0.1, -0.1), Vector2(0.4, -0.1)], [Vector2(0.0, -0.38), Vector2(0.5, -0.38)]]
	var g1: Array = ito + ko
	var g2: Array = ito + so
	_strokes(k, mb, o, -0.035, 0.0, 0.062, g1, 0.0042, 0.0075, wh, tsk)
	_strokes(k, mb, o, 0.035, 0.0, 0.062, g2, 0.0042, 0.0075, wh, tsk)
	# kollar: bileğe, lastikli manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.5 if sd == "Left" else 2.8
		_sleeve(k, ar, cr, 0.9, sv, 0.016, 0.01)
		_rib(k, ar, 0.885, 0.985, 0.0095, cr.darkened(0.04))
		R._arm_skin(k, ar, 0.8)


# ------------------------------------------------------------------ Daidai Uwagi (ref Shinobi Striker "Naruto Outfit 2"): yakaya kadar fermuarlı dolgun turuncu ceket (siyah yüksek dik yaka, etekte ve manşette
## iki siyah şerit, sırtta siyah girdap), düz siyah pantolon, sağ elde beyaz sargı
static func _turuncu(k) -> void:
	var og := Color(0.941, 0.541, 0.141)
	var bk := Color(0.094, 0.094, 0.11)
	var wh := Color(0.93, 0.93, 0.91)
	var mt := Color(0.7, 0.7, 0.72)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return wh, 0.006, H - 0.03)
	K._seat(k, b, bk)
	I._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.6 if sd == "Left" else 2.1
		_pleg(k, le, bk, 0.99, 0.016, 0.016, sv, 0.3)
	# ceket: dolgun, kalçaya iner, yakaya kadar kapalı
	var hem: float = H - 0.07
	var top: float = N + 0.012
	var jk: Array = _jkeys(k, b, top, hem, 0.042, 0.05)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		var puff: float = 0.01 * pow(sin(clampf((y - hem) / (top - hem), 0.0, 1.0) * PI), 0.6)
		return puff * smoothstep(0.0, 0.25, aw) + smoothstep(0.25, 0.6, aw) * (t * (0.013 * sin(a * 6.0 + 0.3) + 0.006 * sin(a * 13.0 + 1.0)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 14.0))
	var jsk: Callable = _jsk(k, hem)
	P._cl(k, {"keys": jk, "ny": 44, "na": 92, "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return og, "gain": 7.0, "th": 0.006, "inner": og.darkened(0.3), "skin": jsk})
	var jff := func(a, y): return jf.call(float(a), float(y))
	_zip(k, jk, jff, top - 0.004, hem + 0.004, og.darkened(0.15), mt, jsk, false)
	# etek: turuncu bant üstünde iki siyah şerit (kumaşa dikili kabartma)
	for y in [hem + 0.05, hem + 0.022]:
		var pts := []
		for i in 96:
			pts.append(Q._spt(jk, jff, TAU * i / 96.0 - PI, y, 0.002)[0])
		P._bd(k, pts, 0.0115, 0.003, bk, true, jsk)
	J._swirl(k, jk, 0.0, C - 0.045, 0.06, bk, false)
	# siyah dik yaka: yüksek, kapalı (fermuar yakaya çıkar)
	var cg: Dictionary = _stand(k, nk, 0.076, 0.045, bk, bk.lightened(0.08), 0.032, 0.004)
	var nsk := func(p): return Q._nsk(k, p)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.003, mt, false, nsk)
	var zt: Vector3 = (cg["ea"][0] as Vector3).lerp(cg["eb"][0], 0.5)
	var zo: Vector3 = P._out(zt)
	P._boxr(k, zt + Vector3(0, -0.018, 0) + zo * 0.006, Vector3(0.0045, 0, 0), Vector3(0, 0.012, 0), zo * 0.0025, mt.lightened(0.1), [["Neck", 0.4], ["UpperChest", 0.6]], 0.3)
	# kollar: bileğe, bilekte iki siyah şerit, turuncu manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.2 if sd == "Left" else 2.5
		_sleeve(k, ar, og, 0.84, sv, 0.018, 0.012)
		_rib(k, ar, 0.8, 0.985, 0.0115, og.darkened(0.03), 16.0)
		R._arm_skin(k, ar, 0.76)
		for ss in [0.85, 0.895]:
			Q._ring_on(k, ar, ss, func(_s, _a): return 0.0125, 0.0105, bk, 0.0022)
	_hand_wrap(k, "Right", wh)


# ------------------------------------------------------------------ Kuro Uwagi (ref Shinobi Striker "Naruto Outfit 3"): turuncu fermuarlı dolgun siyah ceket (yüksek dik yaka), sol kolda kızıl bant + girdap,
## sol kol ön kola kadar kıvrık (gri astar dışa döner), sağ elde sargı; somon kapri, sağ uylukta kılıf, siyah bot konçu
static func _siyah(k) -> void:
	var bk := Color(0.11, 0.11, 0.133)
	var og := Color(0.94, 0.54, 0.14)
	var sa := Color(0.88, 0.47, 0.33)
	var rd := Color(0.72, 0.16, 0.3)
	var gy := Color(0.46, 0.46, 0.52)
	var wh := Color(0.9, 0.9, 0.88)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return wh, 0.006, H - 0.03)
	K._seat(k, b, sa)
	I._seat(k, b, sa)
	# kapri + bot konçu; sağ uylukta kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.2
		var sv: float = 1.8 if sd == "Left" else 0.4
		_boot(k, le, kn + 0.14, bk, bk.lightened(0.1))
		var pa: Callable = _pleg(k, le, sa, s1, 0.022, 0.024, sv, 0.0)
		P._lt(k, le, func(s, a): return float(pa.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return sa.darkened(0.25) if ins else sa.darkened(0.08), s1 - 0.022, s1 + 0.002, 3, 22)
		if sd == "Right":
			I._holster(k, le, pa, bk, bk.lightened(0.05))
			var s0: float = kn * 0.52
			for ss in [s0 - 0.006, s0 + 0.006]:
				Q._ring_on(k, le, ss, func(s, a): return float(pa.call(float(s), float(a))) + 0.0045, 0.0022, wh, 0.0012)
	# ceket: dolgun, kalçanın altına iner, yakaya kadar kapalı
	var hem: float = H - 0.09
	var top: float = N + 0.012
	var jk: Array = _jkeys(k, b, top, hem, 0.05, 0.058)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		var puff: float = 0.014 * pow(sin(clampf((y - hem) / (top - hem), 0.0, 1.0) * PI), 0.5)
		return puff * smoothstep(0.0, 0.3, aw) + smoothstep(0.25, 0.6, aw) * (t * (0.018 * sin(a * 5.0 + 0.8) + 0.008 * sin(a * 11.0 + 2.0)) + (1.0 - t) * 0.008 * sin(a * 4.0 + y * 12.0))
	var jsk: Callable = _jsk(k, hem)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 46, "na": 92, "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 7.0, "th": 0.007, "inner": bk.darkened(0.3), "skin": jsk})
	var jff := func(a, y): return jf.call(float(a), float(y))
	_zip(k, jk, jff, top - 0.004, hem + 0.004, og.darkened(0.1), og, jsk, false)
	var hm := []
	for p in jg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.013, 0))
	P._cord(k, hm, 0.0024, bk.lightened(0.08), true, jsk)
	# dik yaka: yüksek, fermuar yakaya çıkar
	var cg: Dictionary = _stand(k, nk, 0.078, 0.04, bk, bk.lightened(0.06), 0.034, 0.003)
	var nsk := func(p): return Q._nsk(k, p)
	for e2 in [cg["ea"], cg["eb"]]:
		P._cord(k, e2, 0.0028, og, false, nsk)
	# kollar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 2.3 if sd == "Left" else 0.9
		if sd == "Left":   # kıvrık kol: ön kol ortasında geniş gri kat, altı çıplak
			var s1 := 0.74
			R._arm_skin(k, ar, s1 - 0.06)
			var sf: Callable = _sleeve(k, ar, bk, s1, sv, 0.022, 0.012, gy)
			var L: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
			var cw: float = 0.055 / L
			var rf := func(s, a): return float(sf.call(float(s), float(a))) + 0.006 + 0.004 * sin(clampf((float(s) - s1 + cw) / cw, 0.0, 1.0) * PI) + 0.0015 * sin(float(a) * 4.0 + 1.0)
			var rc := func(s, a, ins): return gy.darkened(0.3) if ins else (gy.darkened(0.2) if float(s) < s1 - cw + 0.008 else gy.darkened(0.08 * float(sin(float(a) * 4.0 + 1.0) < 0.0)))
			P._lt(k, ar, rf, rc, s1 - cw, s1 + 0.006, 6, 24)
			# kızıl kol bandı + siyah girdap
			Q._ring_on(k, ar, 0.27, func(s, a): return float(sf.call(float(s), float(a))) + 0.002, 0.026, rd, 0.003)
			J._arm_swirl(k, ar, 0.27, 0.019, bk, float(sf.call(0.27, 0.0)) + 0.008)
		else:
			_sleeve(k, ar, bk, 0.9, sv, 0.022, 0.012)
			_rib(k, ar, 0.885, 0.985, 0.0115, bk.lightened(0.03))
			R._arm_skin(k, ar, 0.8)
	_hand_wrap(k, "Right", wh)


# ------------------------------------------------------------------ Daidai Undōgi (ref Shinobi Striker "Naruto Outfit 4"): beyaz tişört, göğüs altına kadar fermuarlı somon kapüşonlu ceket (sırtta yatan kapüşon,
## önde kavisli siyah biyeler, geniş siyah lastikli etek ve manşet), bağcıklı bol koyu gri eşofman altı (dış yanda turuncu şerit, bilek üstünde toplanır), sağ elde sargı
static func _kapusonlu(k) -> void:
	var sa := Color(0.91, 0.565, 0.416)
	var bk := Color(0.11, 0.11, 0.125)
	var wh := Color(0.95, 0.95, 0.94)
	var gy := Color(0.227, 0.227, 0.251)
	var st := Color(0.84, 0.33, 0.2)
	var mt := Color(0.72, 0.72, 0.74)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return wh, 0.006, H - 0.03)
	var nr := []
	for i in 44:
		nr.append(Q._spt(ik, Callable(), TAU * i / 44.0 - PI, N + 0.03, 0.003)[0])
	P._cord(k, nr, 0.005, wh.darkened(0.08), true, func(p): return Q._nsk(k, p))
	# eşofman altı: kalça + bel lastiği + bağcık
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return gy)
	I._seat(k, b, gy)
	P._sash(k, sk, H + 0.062, 0.017, 0.007, gy.lightened(0.04), 0.2)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 2.4 if sd == "Left" else 1.0
		var tk: float = 0.86
		var ad: Callable = Q._baggy(k, le, gy, skc, 0.02, 0.036, tk, sv)
		_rib(k, le, tk - 0.055, tk + 0.006, 0.012, gy.darkened(0.06), 18.0)
		var fa: float = J._outer_a(le, 0.3, Vector3(float(le["sg"]), 0.0, 0.0))
		S._lstrip(k, le, 0.03, tk - 0.07, func(_s): return fa, func(s, a): return float(ad.call(s, a)) + 0.0008, 0.0075, 0.0022, st, 26)
	# kapüşonlu ceket gövdesi: göğüs altından aşağı kapalı, üstte açık
	var hem: float = H - 0.01
	var top: float = N + 0.012
	var yz: float = C - 0.03
	var jk: Array = _jkeys(k, b, top, hem, 0.04, 0.05)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.25, 0.65, aw) * (t * (0.017 * sin(a * 6.0 + 1.1) + 0.008 * sin(a * 12.0 + 0.2)) + (1.0 - t) * 0.008 * sin(a * 4.0 + y * 15.0))
	var vz: float = (top - yz) / (top - hem)
	var jsk: Callable = _jsk(k, hem)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 44, "na": 92, "rng": func(v):
		var e: float = lerpf(0.5, 0.0, smoothstep(0.05, vz, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return top, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return sa, "gain": 7.0, "th": 0.006, "inner": sa.darkened(0.25), "skin": jsk})
	var jff := func(a, y): return jf.call(float(a), float(y))
	for ed in [jg["ea"], jg["eb"]]:
		var pts: Array = []
		for p in ed:
			if float(p.y) > yz - 0.004:
				pts.append(p)
		P._bd(k, pts, 0.0035, 0.0026, mt, false, jsk, 0.0)
	_zip(k, jk, jff, yz, hem + 0.004, sa.darkened(0.12), mt, jsk)
	# önde kavisli siyah biyeler: omuz dikişinden etek bandına
	for sg in [1.0, -1.0]:
		Q._run(k, jk, jff, [Vector2(sg * 1.05, N - 0.06), Vector2(sg * 0.8, C - 0.02), Vector2(sg * 0.6, H + 0.12), Vector2(sg * 0.52, hem + 0.004)], 0.0036, 0.003, 0.0016, bk, jsk, 8)
		Q._run(k, jk, jff, [Vector2(sg * 1.32, C - 0.06), Vector2(sg * 1.26, H + 0.08), Vector2(sg * 1.2, hem + 0.004)], 0.0032, 0.003, 0.0016, bk, jsk, 8)
	# geniş siyah lastikli etek bandı (kapalı)
	var lo: Vector3 = k.M(hem - 0.055, 0.3)
	var rk := [P._kp(b["hp"], hem + 0.004, 0.05), P._kp(lo, hem - 0.055, 0.03)]
	var rsk: Callable = _jsk(k, hem - 0.055)
	P._cl(k, {"keys": rk, "ny": 6, "na": 160, "top": func(_a): return hem + 0.004, "hem": func(_a): return hem - 0.055,
		"fold": func(a, _y, _v): return 0.011 * sin(float(a) * 40.0), "col": func(_a, _y, _v): return bk, "gain": 12.0, "th": 0.006, "inner": bk.darkened(0.3), "skin": rsk})
	Q._run(k, rk, func(_a, _y): return 0.0, [Vector2(0.0, hem + 0.004), Vector2(0.0, hem - 0.055)], 0.0028, 0.006, 0.0016, mt, rsk, 6)
	# kapüşon: sırtta yatan kalın kat, ağzı yukarı bakar; önde boynun iki yanında yükselir
	var q: float = Q._hq(k)
	var ch: Vector3 = b["ch"]
	var hk := [[N + 0.075 * q, nk.x + 0.05, nk.y + 0.045, nk.z - 0.06], [N + 0.0, nk.x + 0.07, nk.y + 0.05, nk.z - 0.085], [N - 0.08, ch.x * 0.75, ch.y * 0.9, ch.z * 1.08 - 0.065], [C - 0.08, ch.x * 0.6, ch.y * 0.8, ch.z * 1.04 - 0.06]]
	var hood_top := func(a: float) -> float: return N + q * lerpf(0.045, 0.075, smoothstep(0.5, 2.6, absf(a)))
	var hood_hem := func(a: float) -> float: return lerpf(N - 0.035, C - 0.07, smoothstep(0.9, 2.7, absf(a)))
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 16, "na": 60, "rng": func(_v): return Vector2(0.42, TAU - 0.42), "top": func(a): return hood_top.call(float(a)), "hem": func(a): return hood_hem.call(float(a)),
		"fold": func(a, y, v): return 0.3 * sin(float(v) * PI) * smoothstep(1.4, 2.8, absf(float(a))) + 0.012 * sin(float(a) * 5.0 + float(y) * 20.0), "col": func(a, _y, v): return sa.darkened(0.12 * smoothstep(0.7, 1.0, float(v)) * smoothstep(1.6, 2.8, absf(float(a)))),
		"gain": 6.0, "th": 0.008, "inner": sa.darkened(0.35), "skin": func(p): return Q._nsk(k, p)})
	P._cord(k, hg["top"], 0.005, sa.darkened(0.08), false, func(p): return Q._nsk(k, p))
	var hh: Array = []
	for p in hg["hem"]:
		if absf(atan2(float(p.x), float(p.z))) > 1.3:
			hh.append(p)
	P._cord(k, hh, 0.0045, sa.darkened(0.3), false, func(p): return k.torso_skin(p.y))
	# bağcık: etek bandının altından kalçaya inen iki beyaz ip (kumaşa oturur), uçta metal kılıf
	var dsk := func(p): return k.cloth_skin(p, H - 0.25, 0.5)
	for sg in [1.0, -1.0]:
		var pts := []
		for i in 10:
			var t: float = float(i) / 9.0
			pts.append(P._fp(sk, sg * (0.014 + 0.006 * sin(t * 2.5)), H - 0.055 - t * 0.085, true, 0.007)[0])
		P._cord(k, pts, 0.0026, wh, false, dsk, 0.0, 6)
		P._tb(k, [pts[8], pts[9], (pts[9] as Vector3) + Vector3(0, -0.01, 0.001)], func(_s, _a): return 0.0034, func(_s, _a, _p): return mt, func(_s, p): return dsk.call(p), 6)
	# kollar: bileğe, geniş siyah manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.5 if sd == "Left" else 1.9
		_sleeve(k, ar, sa, 0.86, sv, 0.02, 0.014)
		_rib(k, ar, 0.845, 0.985, 0.0105, bk, 16.0)
		R._arm_skin(k, ar, 0.78)
	_hand_wrap(k, "Right", Color(0.66, 0.66, 0.68))


# ------------------------------------------------------------------ Yabureta Daidai (ref Shinobi Striker "Naruto Outfit Last Battle Ver."): file iç üstüne önü açık yırtık eşofman ceketi (siyah omuz boyunduruğu
## ve kollar, turuncu gövde, dişli yırtık etek ve delikler, sağ kol ön kolda yırtık: altında file, sol omuzda yama), yamalı yıpranmış turuncu pantolon, sağ dizin üstünde sargı, siyah bot konçu
static func _yirtik(k) -> void:
	var bk := Color(0.11, 0.11, 0.173)
	var og := Color(0.93, 0.53, 0.13)
	var nb := Color(0.33, 0.3, 0.29)
	var nt := Color(0.1, 0.1, 0.12)
	var wh := Color(0.92, 0.92, 0.9)
	var dt := Color(0.55, 0.36, 0.16)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	# file iç: koyu zemin + çapraz iplikler, siyah yaka biyesi
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return nb, 0.006, H - 0.03)
	Q._net(k, ik, -0.75, 0.75, H - 0.02, N - 0.02, 0.026, 0.0016, 0.004, nt)
	var nr := []
	for i in 44:
		nr.append(Q._spt(ik, Callable(), TAU * i / 44.0 - PI, N + 0.03, 0.003)[0])
	P._cord(k, nr, 0.0048, nt, true, func(p): return Q._nsk(k, p))
	K._seat(k, b, og)
	I._seat(k, b, og)
	# pantolon: baldır ortasında dişli yırtık uç, yamalar, kir lekeleri; altında siyah bot konçu; sağ dizin üstünde sargı
	var dirt := func(s: float, a: float, sv: float) -> Color:
		var n: float = sin(a * 3.0 + s * 41.0 + sv) * sin(a * 5.0 - s * 23.0 + sv * 2.0)
		return og.lerp(dt, 0.22 * smoothstep(0.7, 0.95, n))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 1.1 if sd == "Left" else 2.9
		_boot(k, le, kn + 0.15, bk, bk.lightened(0.1))
		var pa := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			var cr: float = exp(-pow((s - kn) / 0.07, 2.0)) * sin(a * 3.0 + s * 34.0 + sv)
			return 0.024 + 0.024 * exp(-pow((s - kn + 0.08) / 0.22, 2.0)) * (1.0 - 0.35 * inn) + 0.007 * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + 0.005 * cr
		var s1: float = kn + 0.21
		S._lte(k, le, pa, func(s, a, ins): return og.darkened(0.3) if ins else P._fs(dirt.call(float(s), float(a), sv), 0.0, 1.0), 0.0, func(a): return s1 - 0.025 * maxf(0.0, Q._tri(float(a) * 6.0 + sv)) - 0.012 * sin(float(a) * 11.0 + sv), 40, 24)
		if sd == "Left":
			_lpatch(k, le, pa, 0.28, J._outer_a(le, 0.28, Vector3(0.4, 0.0, 1.0)), 0.034, 0.028, og.darkened(0.12), dt.darkened(0.3))
		else:
			_lpatch(k, le, pa, kn + 0.08, J._outer_a(le, kn + 0.08, Vector3(-0.3, 0.0, 1.0)), 0.03, 0.026, og.lightened(0.06), dt.darkened(0.3))
			for i in 6:
				var s: float = kn - 0.11 + 0.017 * i
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + float(pa.call(s, 0.0)) + 0.004, 0.0095, 0.004, wh.darkened(0.05 * float(i % 2)), P._lskin(le, s))
	# ceket: önü açık, eteği dişli yırtık, delikli; turuncu gövde
	var hem: float = H - 0.05
	var top: float = N + 0.012
	var jk: Array = _jkeys(k, b, top, hem - 0.03, 0.04, 0.05)
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		return smoothstep(0.35, 0.8, aw) * (0.012 * sin(a * 6.0 + y * 13.0) + 0.008 * sin(a * 11.0 - y * 9.0) * smoothstep(C, hem, y))
	var hemf := func(a: float) -> float:
		var tor: float = 1.0 - smoothstep(0.4, 1.4, absf(a - 0.8))   # sol önde en yırtık
		return hem + 0.01 * sin(a * 2.0) - (0.016 + 0.024 * tor) * maxf(0.0, Q._tri(a * 9.0 + 1.3)) * (0.5 + 0.5 * sin(a * 4.0 + 2.0)) + 0.012 * tor
	var holes := [[0.85, H + 0.07, 0.16, 0.034, 1.2], [PI - 0.6, H + 0.03, 0.2, 0.036, 2.2], [PI + 0.7, C - 0.13, 0.15, 0.03, 0.5]]
	var holef := func(a: float, y: float) -> bool:
		for hh in holes:
			var da: float = wrapf(a - float(hh[0]), -PI, PI) / float(hh[2])
			var dy: float = (y - float(hh[1])) / float(hh[3])
			if da * da + dy * dy < pow(S._jag(atan2(dy, da), float(hh[4])), 2.0):
				return true
		return false
	var jsk: Callable = _jsk(k, hem - 0.02)
	var jrg := func(v) -> Vector2:
		var e: float = lerpf(0.36, 0.52, float(v))
		return Vector2(e, TAU - e)
	var jg: Dictionary = S._clh(k, {"keys": jk, "ny": 36, "na": 96, "rng": jrg, "top": func(_a): return top, "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(a, y, _v): return dirt.call(float(y) * 2.0, float(a), 0.7), "gain": 6.0, "th": 0.006, "inner": og.darkened(0.3), "skin": jsk}, holef)
	var jff := func(a, y): return jf.call(float(a), float(y))
	for hh in holes:
		var sdv: float = hh[4]
		S._hole_rim(k, jk, jff, hh[0], hh[1], hh[2], hh[3], func(t): return S._jag(float(t), sdv), og.darkened(0.2), jsk)
	for ed in [jg["ea"], jg["eb"]]:
		P._bd(k, ed, 0.0042, 0.0025, Color(0.5, 0.5, 0.53), false, jsk, 0.0)
	P._cord(k, jg["hem"], 0.0026, og.darkened(0.15), false, jsk)
	# siyah omuz boyunduruğu: üstte ayrı kat, alt kenarı biyeli
	var yk: Array = []
	for e in jk:
		yk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	var y_hem := func(a: float) -> float: return lerpf(C - 0.035, C - 0.0, smoothstep(0.6, 2.4, absf(a)))
	var yg: Dictionary = P._cl(k, {"keys": yk, "ny": 16, "na": 96, "rng": func(v):
		var e: float = lerpf(0.36, 0.36 + 0.16 * (C - 0.035 - top) / (hem - top), float(v))
		return Vector2(e, TAU - e), "top": func(_a): return top + 0.001, "hem": func(a): return y_hem.call(float(a)), "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.005, "inner": bk.darkened(0.3), "skin": func(p): return k.torso_skin(p.y)})
	P._cord(k, yg["hem"], 0.0032, bk.darkened(0.2), false, func(p): return k.torso_skin(p.y))
	# dik yaka: siyah, önü açık
	_stand(k, nk, 0.085, 0.36, bk, bk.lightened(0.05), 0.036, 0.006)
	# kollar: siyah; sağ kol ön kolda dişli yırtık (altında file), sol kol bileğe (yıpranmış manşet), sol omuzda yama
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.0
		var sf := func(s: float, a: float) -> float:
			return 0.018 + 0.009 * smoothstep(0.1, 0.6, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		var colf := func(s, a, ins): return bk.lightened(0.05) if ins else P._fs(bk, float(sf.call(float(s), float(a))) - 0.022, 14.0)
		if sd == "Right":
			P._lt(k, ar, func(_s, _a): return 0.002, func(_s, _a, ins): return nb.darkened(0.3) if ins else nb, 0.6, 0.97, 16, 16)
			P._net_limb(k, ar, 0.62, 0.96, 0.0045, 7, 0.06, 0.0016, nt)
			R._arm_skin(k, ar, 0.95)
			S._lte(k, ar, sf, colf, 0.0, func(a): return 0.72 + 0.04 * Q._tri(float(a) * 4.0 + 0.6) + 0.02 * sin(float(a) * 9.0), 34, 24)
		else:
			S._lte(k, ar, sf, colf, 0.0, func(a): return 0.95 - 0.018 * maxf(0.0, Q._tri(float(a) * 7.0 + 1.0)), 36, 22)
			R._arm_skin(k, ar, 0.85)
			var pa0: float = J._outer_a(ar, 0.2, Vector3(1.0, 0.3, 0.0))
			_lpatch(k, ar, sf, 0.2, pa0, 0.03, 0.036, Color(0.2, 0.2, 0.25), bk.darkened(0.3))
			var mp: Callable = R._off(R._lmap(ar, sf, 0.2, pa0), 0.0, 0.0)
			var spl := []
			for i in 30:
				var v := float(i) / 29.0
				var t: float = v * TAU * 1.7 + 0.4
				var rr: float = 0.018 * lerpf(1.0, 0.12, v)
				spl.append(Vector2(cos(t) * rr, sin(t) * rr))
			R._lstrip(k, mp, spl, 0.0022, 0.0055, 0.0012, og.darkened(0.15), func(p): return R._lsk(ar, p))
