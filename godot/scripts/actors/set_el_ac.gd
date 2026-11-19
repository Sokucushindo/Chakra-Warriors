extends RefCounted
## Elle modellenmiş setler, parti ac: ss_maskeli_gaiden, ss_ic_giysi, ss_maskeli_jonin, ss_altinci, ss_maskeli_genc, ss_bes_kalp. Örnek: set_el.gd içindeki _shugonin.
## Maskeli dört set aynı kişinin dönemleri: ortak kesim (dar gövde, maskenin altına çıkan boğaz, baldırda toplanan pantolon) _hk_* yardımcılarında,
## her dönemin kendi parçaları (kılıç koşumu + kolluk plakaları, katlı manşetli uzun gömlek, yeni yelek + çizme, kuşak yeleği, Hokage cübbesi) ayrı.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), q (Q), y (Y) dosyalarından.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")

const DONE := ["ss_maskeli_gaiden", "ss_ic_giysi", "ss_maskeli_jonin", "ss_maskeli_genc", "ss_bes_kalp"]   # ss_altinci: tarifi hazır ama koşuda öne kalkan uyluk ön ortada kısa an görünüyor, temiz değil

const NV := Color(0.118, 0.165, 0.282)


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	J.P._cur_leg = 0.58
	match sid:
		"ss_maskeli_gaiden": _gaiden(k)
		"ss_ic_giysi": _ic(k)
		"ss_maskeli_jonin": _jonin(k)
		"ss_altinci": _altinci(k)
		"ss_maskeli_genc": _genc(k)
		"ss_bes_kalp": _bes_kalp(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ortak kesim (Hatake)
## Dar gövde: boyundan kalçaya; blouse: kemer üstünde toplanan bolluk
static func _hk_body(k, b: Dictionary, col: Color, pad := 0.01, blouse := 0.0) -> Array:
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := [P._kp(nk, N + 0.06, 0.008, 0.01), P._kp(nk, N + 0.02, 0.016), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, pad), P._kp(b["wa"], H + 0.12, pad), P._kp(b["hp"], H - 0.09, pad)]
	var ff := func(a: float, y: float) -> float:
		var t: float = smoothstep(H + 0.17, H + 0.06, y) * (1.0 - smoothstep(H + 0.045, H + 0.02, y))
		return blouse * t * (0.7 * sin(a * 9.0 + 0.7) + 0.3 * sin(a * 17.0 + 2.0)) + 0.005 * sin(a * 5.0 + y * 14.0) * smoothstep(C, H + 0.12, y)
	SE.body_layer(k, keys, 30, 52, func(_i, _j, p): return P._fs(col, float(ff.call(atan2(float(p.x), float(p.z)), float(p.y))), 9.0), ff)
	return keys


## Maskenin altına çıkan boğaz: hafif buruşuk yüksek yaka (maske yüz yuvasında)
static func _hk_neck(k, b: Dictionary, col: Color, hgt := 0.075) -> void:
	var N: float = k.N
	var nk: Vector3 = b["nk"]
	var q: float = Q._hq(k)
	var ck := [[N + hgt * q, nk.x + 0.011, nk.y + 0.012, nk.z - 0.013], [N + 0.03 * q, nk.x + 0.016, nk.y + 0.017, nk.z - 0.016], [N - 0.02, nk.x + 0.03, nk.y + 0.03, nk.z - 0.028], [N - 0.06, nk.x + 0.05, nk.y + 0.045, nk.z - 0.04]]
	var ff := func(a: float, y: float, v: float) -> float: return 0.06 * sin(a * 6.0 + y * 90.0) * sin(v * PI) * 0.2 + 0.006 * sin(a * 11.0)
	var nsk := func(p): return Q._nsk(k, p)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 40, "top": func(_a): return N + hgt * q, "hem": func(_a): return N - 0.06, "fold": ff,
		"col": func(_a, _y, _v): return col, "gain": 8.0, "th": 0.004, "inner": col.darkened(0.4), "skin": nsk})
	P._cord(k, cg["top"], 0.0038, col.lightened(0.04), true, nsk)


## Uzun kol: dirsekte kırışık, omuz altında bolluk
static func _hk_sleeve(k, ar: Dictionary, col: Color, s1: float, sv: float, bag := 0.0) -> Callable:
	var ak: float = ar["kn"]
	var sl := func(s: float, a: float) -> float:
		var e: float = exp(-pow((s - ak) / 0.085, 2.0))
		return 0.008 + bag * sin(clampf(s / s1, 0.0, 1.0) * PI * 0.85) + 0.0065 * e * sin(a * 3.0 + s * 31.0 + sv) + 0.003 * P._lf(s, a, sv) * sin(s * PI) + 0.006 * exp(-pow((s - 0.1) / 0.1, 2.0))
	P._lt(k, ar, sl, func(s, a, ins): return col.darkened(0.4) if ins else P._fs(col, float(sl.call(float(s), float(a))) - 0.008 - bag * 0.6, 30.0), 0.0, s1, 34, 18, 0.02)
	return sl


## Baldırda toplanan bol pantolon + bileğe bant sargısı
static func _hk_legs(k, le: Dictionary, col: Color, bag: float, tk: float, sv: float, tape: Color) -> Callable:
	var ad: Callable = Q._baggy(k, le, col, col.darkened(0.1), 0.016, bag, tk, sv)
	J._shin_tape(k, le, func(_s, _a): return 0.008, tk - 0.02, 9, tape)
	return ad


## Sağ uyluk: kumaşın yüzeyini izleyen sargı bantları + kese
static func _hk_holster(k, le: Dictionary, ad: Callable, st: Color, box: Color, n := 2) -> void:
	var kn: float = le["kn"]
	var s0: float = kn * 0.48
	for i in n:
		Q._ring_on(k, le, s0 + 0.062 * i, func(s, a): return float(ad.call(float(s), float(a))) + 0.001, 0.0115, st.darkened(0.04 * float(i % 2)), 0.004)
	var sm: float = s0 + 0.035
	var a: float = J._outer_a(le, sm, Vector3(float(le["sg"]), 0.0, 0.25))
	var e: Array = J._lsurf(le, sm, a, float(ad.call(sm, a)) + 0.022)
	var o: Vector3 = e[1]
	var d: Vector3 = P._ld(le, sm)
	var bo := [[String(le["bo"][0]), 1.0]]
	var sx: Vector3 = o.cross(d).normalized()
	P._boxr(k, e[0], sx * 0.034, -d * 0.058, o * 0.018, box, bo)
	P._boxr(k, (e[0] as Vector3) + o * 0.017 + d * -0.032, sx * 0.036, -d * 0.022, o * 0.005, box.darkened(0.15), bo, 0.2)
	P._stud(k, (e[0] as Vector3) + o * 0.023 - d * 0.024, o, 0.005, box.lightened(0.2), bo)


## Uzuv boyunca s noktasının kemik ağırlığı (strip için konumdan)
static func _ls_of(l: Dictionary, p: Vector3) -> Array:
	var p0: Vector3 = l["p0"]
	var p1: Vector3 = l["p1"]
	var p2: Vector3 = l["p2"]
	var kn: float = l["kn"]
	var t0: float = clampf((p - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
	var s: float = t0 * kn
	if t0 >= 1.0:
		s = lerpf(kn, 1.0, clampf((p - p1).dot(p2 - p1) / (p2 - p1).length_squared(), 0.0, 1.0))
	return P._lskin(l, s)


## Uzvu saran ince bant (kumaşın yüzeyinde)
static func _ring_l(k, l: Dictionary, s: float, add: float, hw: float, col: Color) -> void:
	k.wrap_turn(P._lp(l, s), P._ld(l, s), P._lr(l, s) + add, hw, 0.0, col, P._lskin(l, s))


# ------------------------------------------------------------------ Kakashi Gaiden (ref kakashi_outfit_gaiden_vers): kısa kollu lacivert gömlek + boğaz, omuz-kol üstünde gri şerit,
## çapraz kahve kılıç koşumu + göğüste baklava levha (sırtta da çapraz), soluk kemer + arkada iki kese, plakalı kolluklar (dirsek üstü açık ten), sağ uylukta beyaz sargı + kese, baldır sargısı
static func _gaiden(k) -> void:
	var nv := NV
	var gr := Color(0.8, 0.8, 0.82)
	var br := Color(0.47, 0.26, 0.17)
	var bt := Color(0.74, 0.7, 0.68)
	var st := Color(0.74, 0.75, 0.8)
	var wh := Color(0.9, 0.9, 0.88)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var wa: Vector3 = b["wa"]
	var keys: Array = _hk_body(k, b, nv, 0.012, 0.03)
	_hk_neck(k, b, nv)
	K._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = ar["sg"]
		var sv: float = 1.2 if sd == "Left" else 2.5
		# kısa kol + ağız katı
		var sh := func(s: float, a: float) -> float: return 0.013 + 0.008 * smoothstep(0.05, 0.28, s) + 0.003 * P._lf(s, a, sv) + 0.006 * exp(-pow((s - 0.08) / 0.08, 2.0))
		P._lt(k, ar, sh, func(s, a, ins): return nv.darkened(0.45) if ins else P._fs(nv, float(sh.call(float(s), float(a))) - 0.016, 18.0), 0.0, 0.28, 16, 20, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return nv.darkened(0.45) if ins else nv.lightened(0.05), 0.255, 0.282, 3, 20)
		# omuzdan kol ağzına gri şerit: omuz üstünden kolun dış yanına döner
		var pts := []
		var ou := []
		for i in 15:
			var s: float = lerpf(0.0, 0.275, float(i) / 14.0)
			var dir := Vector3(sg * lerpf(0.35, 1.0, float(i) / 14.0), lerpf(1.0, 0.25, float(i) / 14.0), 0.0)
			var a: float = J._outer_a(ar, s, dir)
			var e: Array = K._lsurf(ar, s, a, float(sh.call(s, a)) + 0.0015)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, 0.0085, 0.0018, gr, false, func(p): return _ls_of(ar, p))
		# dirsek üstü açık ten + kolluk
		P._bare(k, ar, skc, 0.24, 0.44)
		var wf := func(s: float, a: float) -> float: return 0.006 + 0.0025 * P._lf(s, a, sv) + 0.004 * exp(-pow((s - 0.5) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, wf, func(s, a, ins): return nv.darkened(0.4) if ins else P._fs(nv, float(wf.call(float(s), float(a))) - 0.006, 22.0), 0.41, 0.93, 24, 18)
		P._lt(k, ar, func(s, a): return float(wf.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return nv.darkened(0.4) if ins else nv.lightened(0.06), 0.405, 0.43, 3, 18)
		_ring_l(k, ar, 0.565, 0.0105, 0.0085, st)
		_ring_l(k, ar, 0.895, 0.0095, 0.0075, st)
		# kolun dış yanında üst üste plakalar
		var ao: float = J._outer_a(ar, 0.72, Vector3(sg, 0.15, -0.25))
		for i in 5:
			var s0: float = 0.6 + 0.058 * i
			K._shell(k, ar, s0, s0 + 0.05, ao - 0.5, ao + 0.5, func(s, a): return float(wf.call(float(s), float(a))) + 0.002, 0.0065, func(u, v, under):
				if under:
					return st.darkened(0.45)
				return st.darkened(0.18) if minf(float(u), 1.0 - float(u)) < 0.1 or minf(float(v), 1.0 - float(v)) < 0.12 else st.lightened(0.04), 6, 10)
		J._glove(k, sd, ar, nv)
		var ad: Callable = _hk_legs(k, le, nv, 0.034, 0.73, sv, wh)
		if sd == "Right":
			_hk_holster(k, le, ad, wh, nv.darkened(0.12), 2)
	# çapraz kılıç koşumu: önde ve sırtta X, omuz üstünden geçer
	var sk_t := func(p): return k.torso_skin(p.y)
	for sg in [1.0, -1.0]:
		var x0: float = sg * minf(0.085, float(b["ch"].x) * 0.55)
		var ys: float = k.N + 0.05
		while ys > H:
			if float(SE.El.key_at(keys, ys)[1]) > absf(x0) + 0.012:
				break
			ys -= 0.004
		var pts := []
		var ou := []
		var n := 16
		for j in n + 1:   # sırt: belden omuza
			var t := float(j) / n
			var e: Array = P._fp(keys, lerpf(-sg * wa.x * 0.9, x0, t), lerpf(H + 0.075, ys, t), false, 0.006)
			pts.append(e[0])
			ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.75, 1.0, t)).normalized())
		for j in range(n, -1, -1):   # ön: omuzdan karşı bele
			var t := float(j) / n
			var e: Array = P._fp(keys, lerpf(-sg * wa.x * 0.9, x0, t), lerpf(H + 0.075, ys, t), true, 0.006)
			pts.append(e[0])
			ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.75, 1.0, t)).normalized())
		k.strip(pts, ou, 0.018, 0.0045, br, false, sk_t)
		var p2 := []
		for i in pts.size():
			p2.append((pts[i] as Vector3) + (ou[i] as Vector3) * 0.0042)
		k.strip(p2, ou, 0.0035, 0.0012, br.lightened(0.18), false, sk_t)
	# göğüste ve sırtta kesişme levhası (baklava)
	var yx: float = lerpf(H + 0.075, k.N - 0.01, 0.5)
	for fr in [true, false]:
		var e: Array = P._fp(keys, 0.0, yx, fr, 0.012)
		var o: Vector3 = e[1]
		var up := (Vector3.UP - o * Vector3.UP.dot(o)).normalized()
		var ri := up.cross(o).normalized()
		P._boxr(k, e[0], (ri + up).normalized() * 0.034, (up - ri).normalized() * 0.034, o * 0.007, st, k.torso_skin(yx), 0.15)
		for c4 in [ri, -ri, up, -up]:
			P._stud(k, (e[0] as Vector3) + o * 0.0065 + (c4 as Vector3) * 0.03, o, 0.0028, st.darkened(0.25), k.torso_skin(yx))
	# soluk kemer + toka, arkada iki kese
	var by: float = H + 0.035
	P._sash(k, keys, by, 0.017, 0.007, bt, 0.06)
	var bx: Array = P._fp(keys, 0.0, by, true, 0.02)
	P._boxr(k, bx[0], Vector3(0.026, 0, 0), Vector3(0, 0.02, 0), (bx[1] as Vector3) * 0.006, st, [["Hips", 0.6], ["Spine", 0.4]], 0.2)
	P._boxr(k, (bx[0] as Vector3) + (bx[1] as Vector3) * 0.006, Vector3(0.012, 0, 0), Vector3(0, 0.01, 0), (bx[1] as Vector3) * 0.002, bt.darkened(0.2), [["Hips", 0.6], ["Spine", 0.4]], 0.3)
	for sx in [1.0, -1.0]:
		var e2: Array = P._fp(keys, sx * wa.x * 0.45, H - 0.012, false, 0.024)
		P._boxr(k, e2[0], Vector3(0.042, 0, 0), Vector3(0, 0.034, 0), (e2[1] as Vector3) * 0.02, bt.darkened(0.14), [["Hips", 1.0]])
		var e3: Array = P._fp(keys, sx * wa.x * 0.45, H + 0.008, false, 0.044)
		P._boxr(k, e3[0], Vector3(0.043, 0, 0), Vector3(0, 0.012, 0), (e3[1] as Vector3) * 0.004, bt.darkened(0.05), [["Hips", 1.0]])


# ------------------------------------------------------------------ Shitagi Shōzoku (ref kakashi_outfit_innerwear_vers): yeleksiz uzun lacivert gömlek (kalçaya inen düzensiz etek ucu, boğaz),
## bileğe katlı geniş manşet, iki üst kolda kızıl girdap, çok bol ve baldırda toplanan pantolon, sağ uylukta üç beyaz bant + kese, baldır sargısı
static func _ic(k) -> void:
	var nv := NV
	var red := Color(0.72, 0.17, 0.14)
	var wh := Color(0.9, 0.9, 0.88)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return nv.darkened(0.05), 0.006)
	K._seat(k, b, nv.darkened(0.04))
	_hk_neck(k, b, nv)
	# gömlek: dışarıda, kalçayı örter; belde hafif bolluk, etek ucu düzensiz
	var hem: float = H - 0.085
	var gk := [P._kp(nk, N + 0.03, 0.022), [N - 0.05, ch.x * 0.9, ch.y * 0.88, ch.z * 0.97], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.026), P._kp(hp, H - 0.04, 0.03), [hem, hp.x + 0.038, hp.y + 0.036, hp.z - 0.036]]
	var gf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((C - 0.05 - y) / (C - 0.05 - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 7.0 + 0.5) + 0.008 * sin(a * 13.0 + 1.7)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 17.0) * smoothstep(N - 0.02, C - 0.05, y)
	var gsk := func(p): return k.cloth_skin(p, hem, 0.5)
	var g: Dictionary = P._cl(k, {"keys": gk, "ny": 34, "na": 80, "top": func(_a): return N + 0.03, "hem": func(a): return hem + 0.007 * Q._tri(float(a) * 7.0 + 0.4) + 0.004 * sin(float(a) * 17.0),
		"fold": gf, "col": func(_a, _y, _v): return nv, "gain": 7.0, "th": 0.006, "inner": nv.darkened(0.45), "skin": gsk})
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, hm, 0.0028, 0.0014, nv.darkened(0.3), true, gsk)
	for sg in [1.0, -1.0]:   # yan dikişler
		Q._run(k, gk, func(a, y): return gf.call(float(a), float(y), 0.0), [Vector2(sg * 1.55, C + 0.02), Vector2(sg * 1.57, H + 0.05), Vector2(sg * 1.58, hem + 0.02)], 0.0024, 0.0015, 0.0012, nv.darkened(0.25), gsk, 8)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.4 if sd == "Left" else 2.7
		var sf: Callable = Y._sleeve(k, ar, nv, 0.01, 0.006, 0.975, sv, 0.1, nv.lightened(0.03), 0.005)
		J._arm_swirl(k, ar, 0.17, 0.027, red, float(sf.call(0.17, 0.0)) + 0.003)
		var ad: Callable = _hk_legs(k, le, nv, 0.05, 0.72, sv, wh)
		if sd == "Right":
			_hk_holster(k, le, ad, wh, nv.darkened(0.12), 3)


# ------------------------------------------------------------------ Kamen Jōnin (ref kakashi_outfit_next_gen_vers): lacivert tulum + boğaz, yeni dönem cepsiz yeşil yelek (büyük omuz yastıkları, dikey dikişler, belde
## kalın bant ve altında genişleyen alt parça, sırtta girdap), sol üst kolda kırmızı bant, siyah parmaksız eldiven, sağ uylukta bant + kese, dize çıkan siyah çizme
static func _jonin(k) -> void:
	var nv := NV
	var ve := Color(0.306, 0.416, 0.282)
	var red := Color(0.74, 0.12, 0.12)
	var bk := Color(0.094, 0.094, 0.11)
	var wh := Color(0.9, 0.9, 0.88)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_hk_body(k, b, nv, 0.008)
	_hk_neck(k, b, nv)
	K._seat(k, b, nv.darkened(0.04))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.2
		var sl: Callable = _hk_sleeve(k, ar, nv, 0.93, sv)
		J._glove(k, sd, ar, bk)
		if sd == "Left":
			Q._ring_on(k, ar, 0.22, func(s, a): return float(sl.call(float(s), float(a))) + 0.002, 0.03, red, 0.005)
		var pa: Callable = K._pant(k, le, nv, 0.01, 0.016, 0.9, sv)
		# dize çıkan çizme konçu: üstte katlı ağız
		var bo := func(s: float, a: float) -> float: return 0.012 + 0.003 * smoothstep(kn + 0.1, kn + 0.05, s) + 0.0025 * sin(a * 4.0 + s * 20.0) * (1.0 - smoothstep(kn + 0.15, kn + 0.3, s)) - 0.002 * smoothstep(0.85, 1.0, s)
		P._lts(k, le, bo, func(s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.06 * float(cos(float(a)) > 0.5 and float(s) < kn + 0.3)), func(a): return kn + 0.06 - 0.02 * pow(maxf(0.0, cos(float(a))), 2.0), 1.0, 20, 20)
		P._lt(k, le, func(s, a): return float(bo.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.1), kn + 0.075, kn + 0.1, 3, 20)
		if sd == "Right":
			_hk_holster(k, le, pa, wh, nv.darkened(0.15), 2)
	# yelek üst gövde
	var vk := [J.P._kp(nk, N + 0.005, 0.032), [N - 0.055, ch.x * 1.0, ch.y * 0.93, ch.z * 1.05], J.P._kp(ch, C - 0.03, 0.032), J.P._kp(wa, H + 0.12, 0.032), J.P._kp(wa, H + 0.075, 0.03)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.028 * exp(-pow(a / 0.028, 2.0)) - 0.012 * exp(-pow((aa - 0.42) / 0.04, 2.0)) - 0.014 * exp(-pow((aa - 1.7) / 0.05, 2.0))
		return g + 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.11, y)
	J.P._sheet(k, vk, 46, 88, Callable(), fold, func(a, y, _u, _v, _p): return J.P._fs(ve, fold.call(a, y, 0.0), 7.0), 0.007, 0.25, func(p): return k.torso_skin(p.y))
	# belde kalın bant + altında genişleyen alt parça
	var lk := [P._kp(wa, H + 0.075, 0.036), P._kp(hp, H - 0.04, 0.045), [H - 0.1, hp.x + 0.056, hp.y + 0.052, hp.z - 0.05]]
	var lhem: float = H - 0.1
	var lsk := func(p): return k.cloth_skin(p, lhem, 0.6)
	var lf := func(a: float, y: float, _v: float) -> float: return -0.02 * exp(-pow(a / 0.03, 2.0)) + 0.008 * sin(a * 8.0 + 0.4) * smoothstep(H + 0.06, lhem, y)
	var lg: Dictionary = P._cl(k, {"keys": lk, "ny": 12, "na": 80, "top": func(_a): return H + 0.075, "hem": func(_a): return lhem, "fold": lf, "col": func(_a, _y, _v): return ve.darkened(0.04), "gain": 7.0, "th": 0.006, "inner": ve.darkened(0.45), "skin": lsk})
	var lh := []
	for p in lg["hem"]:
		lh.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, lh, 0.003, 0.0015, ve.darkened(0.25), true, lsk)
	P._roll(k, [P._kp(wa, H + 0.12, 0.036), P._kp(wa, H + 0.04, 0.036)], H + 0.078, 0.013, 12, 0.0, ve.darkened(0.08))
	J._collar(k, [J.P._kp(nk, N + 0.095, 0.03, 0.04), J.P._kp(nk, N + 0.05, 0.03, 0.038), J.P._kp(nk, N - 0.02, 0.05, 0.05)], 0.82, 0.3, ve, ve.lightened(0.08))
	var cc := Vector3(0.0, C, 0.0)
	for sg in [1.0, -1.0]:   # büyük omuz yastıkları + çıtçıt
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.6, 2.45, float(v))
			var y: float = lerpf(N - 0.008, N - 0.092, float(u))
			return J.P._sa(vk, a, y, 0.0)[0]
		J._pil(k, surf, 12, 14, 0.015, ve.lightened(0.04), cc, 0.16, func(p): return k.torso_skin(p.y))
		var e: Vector3 = surf.call(0.6, 0.18)
		var o: Vector3 = J._nrm(surf, 0.6, 0.18, cc)
		J.P._fan(k, e + o * 0.0175, o, Vector3.UP, 0.009, Callable(), func(u2, v2): return ve.darkened(0.42) if sqrt(u2 * u2 + v2 * v2) > 0.7 else Color(0.8, 0.8, 0.78), k.torso_skin(N - 0.04), 3, 14)
		J.P._strap(k, vk, [Vector2(sg * ch.x * 0.5, N - 0.075), Vector2(sg * ch.x * 0.55, H + 0.085)], true, 0.0025, 0.0, 0.0018, ve.darkened(0.28), 10, func(p): return k.torso_skin(p.y))
	J.P._strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.08)], true, 0.0048, 0.0, 0.0032, Color(0.82, 0.83, 0.82), 24, func(p): return k.torso_skin(p.y))
	J.P._strap(k, lk, [Vector2(0.0, H + 0.06), Vector2(0.0, lhem + 0.01)], true, 0.0048, 0.0, 0.0032, Color(0.82, 0.83, 0.82), 6, lsk)
	J._swirl(k, vk, 0.0, C - 0.07, 0.07, red, false)


# ------------------------------------------------------------------ Kamen Wakate (ref kakashi_outfit_young_vers): standart Konoha takımı — lacivert tulum + boğaz, açık yeşil kuşak yelek (iki yanda üçlü parşömen cebi,
## omuz yastıkları, iki parçalı yaka, fermuar, sırtta girdap), iki üst kolda girdap, mavi parmaksız eldiven, sağ uylukta bant + kese, baldır sargısı
static func _genc(k) -> void:
	var nv := NV
	var ve := Color(0.478, 0.604, 0.541)
	var bl := Color(0.165, 0.29, 0.541)
	var red := Color(0.72, 0.17, 0.14)
	var wh := Color(0.9, 0.9, 0.88)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	_hk_body(k, b, nv, 0.008)
	_hk_neck(k, b, nv, 0.07)
	K._seat(k, b, nv.darkened(0.04))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.7 if sd == "Left" else 0.4
		var sl: Callable = _hk_sleeve(k, ar, nv, 0.93, sv, 0.004)
		J._arm_swirl(k, ar, 0.2, 0.028, red, float(sl.call(0.2, 0.0)) + 0.004)
		J._glove(k, sd, ar, bl)
		var ad: Callable = _hk_legs(k, le, nv, 0.022, 0.75, sv, wh)
		if sd == "Right":
			_hk_holster(k, le, ad, wh, nv.darkened(0.12), 2)
	var vk := [J.P._kp(nk, N + 0.005, 0.03), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], J.P._kp(ch, C - 0.03, 0.03), J.P._kp(wa, H + 0.125, 0.03), J.P._kp(wa, H + 0.088, 0.025), J.P._kp(wa, H + 0.052, 0.054), J.P._kp(wa, H + 0.012, 0.05), J.P._kp(wa, H - 0.012, 0.024)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.03 * exp(-pow(a / 0.028, 2.0)) - 0.016 * exp(-pow((aa - 1.72) / 0.05, 2.0))
		if y > H + 0.09:
			g += 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.1, y)
		else:
			g += 0.007 * sin(a * 11.0 + 0.7)
		return g
	J.P._sheet(k, vk, 56, 88, Callable(), fold, func(a, y, _u, v, _p):
		var c0: Color = J.P._fs(ve, fold.call(a, y, 0.0), 7.0)
		if y < H + 0.1 and y > H + 0.075:
			c0 = c0.darkened(0.22)
		return c0.darkened(0.2) if v > 0.96 else c0, 0.007, 0.25, func(p): return k.torso_skin(maxf(float(p.y), H + 0.01)))
	J._collar(k, [J.P._kp(nk, N + 0.09, 0.03, 0.04), J.P._kp(nk, N + 0.05, 0.03, 0.038), J.P._kp(nk, N - 0.02, 0.05, 0.05)], 0.82, 0.3, ve, ve.lightened(0.08))
	var cc := Vector3(0.0, C, 0.0)
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.72, 2.32, float(v))
			var y: float = lerpf(N - 0.012, N - 0.078, float(u))
			return J.P._sa(vk, a, y, 0.0)[0]
		J._pil(k, surf, 12, 14, 0.012, ve.lightened(0.05), cc, 0.16, func(p): return k.torso_skin(p.y))
		var e: Vector3 = surf.call(0.66, 0.2)
		var o: Vector3 = J._nrm(surf, 0.66, 0.2, cc)
		J.P._fan(k, e + o * 0.0145, o, Vector3.UP, 0.0095, Callable(), func(u2, v2): return ve.darkened(0.42) if sqrt(u2 * u2 + v2 * v2) > 0.7 else Color(0.85, 0.85, 0.83), k.torso_skin(N - 0.04), 3, 14)
		J._pouch(k, vk, sg * ch.x * 0.48, C - 0.115, ch.x * 0.56, 0.135, 3, ve.darkened(0.06), ve.lightened(0.14), sg * -0.012)
	J.P._strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.0)], true, 0.0052, 0.0, 0.0035, Color(0.85, 0.86, 0.85), 26, func(p): return k.torso_skin(maxf(float(p.y), H + 0.01)))
	J._swirl(k, vk, 0.0, C - 0.07, 0.075, red, false)


# ------------------------------------------------------------------ Rokudaime Gaitō (ref kakashi_outfit_sixth_hokage_vers): bileğe inen önü kapalı kırık beyaz cübbe (sağ yanda bindirme), kalın sargı yaka,
## içi leylak astarlı geniş kollar, sırtta yukarıdan aşağı kızıl 六代目火影, altta lacivert takım, siyah eldiven
static func _altinci(k) -> void:
	var wh := Color(0.91, 0.91, 0.894)
	var lv := Color(0.76, 0.76, 0.92)
	var nv := NV
	var rd := Color(0.69, 0.14, 0.16)
	var bk := Color(0.09, 0.09, 0.11)
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
	P._inner(k, b, func(_i, _j, _p): return nv, 0.006)
	K._seat(k, b, wh.darkened(0.1))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, nv, 0.009, 0.01, 1.0, 1.8 if sd == "Left" else 0.7)
		P._lt(k, ar, func(s, _a): return 0.006 + 0.003 * smoothstep(0.7, 0.9, float(s)), func(_s, _a, ins): return nv.darkened(0.3) if ins else nv, 0.35, 0.92, 16, 16)
		J._glove(k, sd, ar, bk)
	var hem: float = lerpf(KN, F, 0.8)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.045), [H - 0.04, hp.x + 0.05, hp.y + 0.08, hp.z - 0.05],
		[KN + 0.05, hp.x + 0.085, hp.y + 0.115, hp.z - 0.1], [hem, hp.x + 0.12, hp.y + 0.11, hp.z - 0.145]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var flat: float = 1.0 - 0.93 * exp(-pow((aw - PI) / 0.4, 2.0))   # sırt ortası düz: yazı kıvrımda kırılmaz
		return flat * (pow(t, 0.9) * ((0.024 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y))
	var csk := func(p): return _robe_skin(k, p, hem, -9.0)
	var ny := 56
	var na := 96
	var ov := 0.5
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
			var e: Array = Q._spt(keys, ff, a, y, lift)
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
			return lv.darkened(0.25)
		var oj: int = e2[0]
		var y: float = outer[oj][0].y
		var a: float = angs[oj][i]
		var c0: Color = P._fs(wh, float(ff.call(a, y)), 4.0)
		var side: float = exp(-pow((absf(a) - 1.5) / 0.2, 2.0)) * smoothstep(H - 0.2, C - 0.05, y) * (1.0 - smoothstep(C + 0.02, N - 0.05, y))
		return c0.lerp(lv, side * 0.6), func(i, _j, p): return _robe_skin(k, p, hem, -9.0))
	var ed := []
	for j in range(2, ny + 1):
		ed.append(outer[j][0])
	P._bd(k, ed, 0.0035, 0.002, wh.darkened(0.14), false, func(p): return _robe_skin(k, p, hem, -9.0), 0.0)
	var hm := []
	for p in outer[ny]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._bd(k, hm, 0.003, 0.0016, wh.darkened(0.16), false, func(p):
		var bi := 0
		var bd := 99.0
		for i in hm.size():
			var dd: float = ((hm[i] as Vector3) - (p as Vector3)).length_squared()
			if dd < bd:
				bd = dd
				bi = i
		return _robe_skin(k, p, hem, -9.0 + 0.0 * bi))
	# ön ortada iki iç kat (ters pli gibi): her biri kendi bacağını izler ve ortayı aşıp öbür yana geçer; adımda etek kanatları ayrılınca arada pantolon değil kumaş görünür
	for sd in ["Left", "Right"]:
		var sg: float = 1.0 if sd == "Left" else -1.0
		var mid := []
		for j in 25:
			var y: float = lerpf(H + 0.1, hem + 0.09, float(j) / 24.0)
			var ro := []
			for i in 13:
				var a: float = sg * lerpf(-0.18, 0.7, float(i) / 12.0)
				ro.append(Q._spt(keys, Callable(), a, y, (-0.008 if sd == "Left" else -0.015) - 0.02 * smoothstep(H + 0.02, H - 0.15, y))[0])
			mid.append(ro)
		Q._mesh(k, mid, false, func(_i, j, _p): return wh.darkened(0.04 + 0.1 * float(j > 22)), func(_i, _j, p):
			var e: Array = _robe_skin(k, p, hem, -9.0)
			var wl: float = 1.0 - float(e[0][1])
			return [["Hips", 1.0 - wl], [sd + "UpperLeg", wl]], Vector3(0, 0, 1))
	# kalın sargı yaka: boyunu saran yatay katlı huni
	var q: float = Q._hq(k)
	var ck := [[N + 0.1 * q, nk.x + 0.04, nk.y + 0.04, nk.z - 0.045], [N + 0.045 * q, nk.x + 0.055, nk.y + 0.05, nk.z - 0.055], [N - 0.01, nk.x + 0.075, nk.y + 0.065, nk.z - 0.065], [N - 0.07, ch.x * 0.86, ch.y * 0.94, ch.z * 1.0]]
	var cf := func(a: float, _y: float, v: float) -> float:
		return 0.05 * sin(float(v) * PI * 3.2 + cos(a) * 0.9) * smoothstep(0.0, 0.2, float(v)) * (1.0 - 0.5 * float(v)) + 0.008 * sin(a * 9.0 + 0.7) * float(v)
	var nsk := func(p): return Q._nsk(k, p)
	var cgl: Dictionary = P._cl(k, {"keys": ck, "ny": 18, "na": 64, "top": func(a): return N + q * (0.1 - 0.012 * cos(float(a))), "hem": func(_a): return N - 0.07, "fold": cf,
		"col": func(_a, _y, _v): return wh, "gain": 6.0, "inner": lv.darkened(0.1), "skin": nsk, "th": 0.007})
	P._cord(k, cgl["top"], 0.0055, wh.darkened(0.05), true, nsk)
	# geniş kollar: içi leylak astar, ağız bileğe doğru biraz toplanır
	var ln := lv
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 2.0 if sd == "Left" else 0.8
		var s1 := 0.9
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.08, s1, s)
			var hang: float = maxf(0.0, -sin(a) * sg)
			var nar: float = smoothstep(s1 - 0.2, s1, s)
			return 0.018 + 0.042 * fl - 0.01 * nar + (0.026 - 0.008 * nar) * fl * hang * hang + (0.003 + 0.007 * fl) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins):
			if ins:
				return ln
			var f: float = float(sf.call(float(s), float(a))) - 0.018 - 0.042 * smoothstep(0.08, s1, float(s))
			var under: float = smoothstep(0.2, 0.9, maxf(0.0, -sin(float(a)) * sg)) * smoothstep(0.15, 0.5, float(s))
			return P._fs(wh, f, 9.0).lerp(lv, under * 0.45), 0.0, s1, 32, 26, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, ln.lightened(0.06), 0.45, s1, 12, 26)
	# sırtta 六代目火影: yukarıdan aşağı kabartma
	var gi := 0
	for gl in [A.G_ROKU, A.G_DAI, A.G_ME, A.G_HI, A.G_KAGE]:
		var cy: float = C - 0.035 - gi * 0.098
		var s := 0.042
		for st in gl:
			P._strap(k, keys, [Vector2(-float(st[0]) * s, cy + float(st[1]) * s), Vector2(-float(st[2]) * s, cy + float(st[3]) * s)], false, 0.0062, 0.0055, 0.0016, rd, 3, csk)
		gi += 1


# ------------------------------------------------------------------ Itoguchi Shōzoku (ref kakuzu_outfit): omuzları açık koyu lacivert boyun bağlı üst, kalın gri boyunluk, geniş beyaz kuşak, sırtta dört maske,
## mor-gri pantolon, baldırdan bileğe açık gri konç; ten üstünde kara dikiş izleri (omuz, üst kol, ön kol) ve bilekte iki kara halka
static func _bes_kalp(k) -> void:
	var dk := Color(0.11, 0.11, 0.157)
	var pa := Color(0.29, 0.29, 0.416)
	var gy := Color(0.55, 0.55, 0.58)
	var wh := Color(0.9, 0.9, 0.91)
	var gu := Color(0.8, 0.8, 0.82)
	var ink := Color(0.07, 0.07, 0.08)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# açık omuz ve göğüs üstü: ten
	var sk_k := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], [C - 0.0, ch.x * 0.95, ch.y + 0.003, ch.z * 0.98], P._kp(ch, C - 0.1, 0.004)]
	SE.body_layer(k, sk_k, 16, 40, func(_i, _j, _p): return skc)
	K._seat(k, b, pa.darkened(0.05))
	# boyun bağlı üst: önde boyuna çıkar, kol oyuğu boyna doğru derin kesik
	var hem: float = H - 0.085
	var tk := [P._kp(nk, N - 0.0, 0.026), [N - 0.06, ch.x * 0.92, ch.y * 0.94, ch.z * 1.0], P._kp(ch, C - 0.03, 0.016), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.04, 0.03), [hem, hp.x + 0.04, hp.y + 0.036, hp.z - 0.036]]
	var topf := func(a: float) -> float:
		var aw: float = absf(a)
		return lerpf(N - 0.01, C - 0.075, exp(-pow((aw - 1.55) / 0.55, 2.0)))
	var tf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 7.0 + 0.5) + 0.008 * sin(a * 12.0 + 1.3)) + 0.004 * sin(a * 5.0 + y * 20.0)
	var tsk := func(p): return k.cloth_skin(p, hem, 0.5)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 32, "na": 84, "top": func(a): return topf.call(float(a)), "hem": func(a): return hem + 0.005 * sin(float(a) * 9.0),
		"fold": tf, "col": func(_a, _y, _v): return dk, "gain": 6.0, "th": 0.006, "inner": dk.darkened(0.4), "skin": tsk})
	P._cord(k, tg["top"], 0.0035, dk.lightened(0.08), true, tsk)
	var hm := []
	for p in tg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hm, 0.0028, 0.0014, dk.darkened(0.3), true, tsk)
	# sırtta dört maske (kabartma): beyaz yüz, göz yarıkları, her birinin kendi işareti
	var tff := func(a, y): return tf.call(float(a), float(y), 0.5)
	var bsk := func(p): return k.torso_skin(p.y)
	var mi := 0
	for e in [[0.3, C - 0.02], [-0.3, C - 0.02], [0.3, C - 0.13], [-0.3, C - 0.13]]:
		var a0: float = PI - float(e[0])
		var mp: Callable = Q._local(tk, tff, a0, float(e[1]))
		var mo: Vector3 = Q._spt(tk, tff, a0, float(e[1]))[1]
		var mc: Color = [Color(0.95, 0.95, 0.92), Color(0.92, 0.9, 0.84), Color(0.94, 0.93, 0.95), Color(0.9, 0.92, 0.9)][mi]
		var mk: Color = [Color(0.7, 0.12, 0.12), Color(0.2, 0.35, 0.7), Color(0.85, 0.55, 0.1), Color(0.2, 0.55, 0.3)][mi]
		var kind: int = mi
		Q._disc(k, mp, mo, 0.03, 0.011, func(th): return 0.86 + 0.2 * absf(sin(float(th))), func(u, v):
			var uu: float = float(u)
			var vv: float = float(v)
			if pow(absf(uu) - 0.36, 2.0) * 2.4 + pow(vv - 0.18, 2.0) * 6.0 < 0.08:
				return ink
			if kind == 0 and absf(absf(uu) - 0.36) < 0.08 and vv < 0.05 and vv > -0.6:
				return mk
			if kind == 1 and absf(vv + 0.25) < 0.08 and absf(uu) < 0.7:
				return mk
			if kind == 2 and Vector2(uu, vv - 0.55).length() < 0.2:
				return mk
			if kind == 3 and absf(uu + vv * 0.6) < 0.08 and vv > -0.7:
				return mk
			return mc, bsk, 5, 28)
		mi += 1
	# kalın gri boyunluk: iki kat rulo + altında örtü
	var gk := [P._kp(nk, N + 0.075, 0.016, 0.018), P._kp(nk, N + 0.02, 0.03), P._kp(nk, N - 0.03, 0.05), [N - 0.07, nk.x + 0.07, nk.y + 0.06, nk.z - 0.055]]
	var nsk := func(p): return Q._nsk(k, p)
	P._cl(k, {"keys": gk, "ny": 12, "na": 48, "top": func(_a): return N + 0.07, "hem": func(a): return N - 0.065 - 0.012 * cos(float(a)), "fold": func(a, _y, v): return 0.012 * sin(float(a) * 6.0 + 0.4) * float(v),
		"col": func(_a, _y, _v): return gy, "gain": 7.0, "th": 0.006, "inner": gy.darkened(0.35), "skin": nsk})
	P._roll(k, gk, N + 0.042, 0.02, 7, 0.006, gy.lightened(0.05))
	P._roll(k, gk, N - 0.008, 0.024, 6, 0.012, gy)
	# geniş beyaz kuşak: iki kat
	var by: float = H + 0.035
	P._sash(k, tk, by, 0.045, 0.008, wh, 0.12)
	P._sash(k, tk, by - 0.012, 0.022, 0.016, wh.darkened(0.04), 0.08)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.1 if sd == "Left" else 2.6
		P._bare(k, ar, skc, 0.0, 1.0)
		# dikiş izleri: kolu saran ince çizgi + dikine kısa iğne izleri
		for s in [0.13, 0.34, 0.66]:
			_stitch(k, ar, float(s), 0.0016, ink)
		for s in [0.885, 0.915]:
			_ring_l(k, ar, float(s), 0.0018, 0.0042, ink)
		var pf: Callable = K._pant(k, le, pa, 0.013, 0.024, 1.0, sv)
		# baldırdan bileğe konç: önde sivri ağız
		var gd := func(s: float, a: float) -> float: return float(pf.call(s, a)) + 0.006 + 0.004 * pow(maxf(0.0, cos(a)), 2.0) + 0.004 * (1.0 - smoothstep(kn + 0.2, kn + 0.28, s)) - 0.003 * smoothstep(0.9, 1.0, s)
		P._lts(k, le, gd, func(s, a, ins):
			if ins:
				return gu.darkened(0.4)
			return gu.darkened(0.12 * float(cos(float(a)) < -0.4) + 0.07 * float(float(s) > 0.95)), func(a): return kn + 0.2 - 0.04 * pow(maxf(0.0, cos(float(a))), 2.0), 1.0, 20, 22)
		P._lt(k, le, func(s, a): return float(gd.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return gu.darkened(0.4) if ins else gu.darkened(0.05), kn + 0.24, kn + 0.26, 2, 22)
		# omuz önünde dikiş izi (ten üstünde)
		var pts := []
		var ou := []
		for i in 9:
			var e: Array = Q._spt(sk_k, Callable(), sg * lerpf(0.62, 1.15, float(i) / 8.0), N - 0.045 - 0.012 * float(i) / 8.0, 0.0018)
			pts.append(e[0])
			ou.append(e[1])
		k.strip(pts, ou, 0.0016, 0.001, ink, false, func(p): return k.torso_skin(p.y))
		for i in 6:
			var t: float = lerpf(0.68, 1.1, float(i) / 5.0)
			var e0: Array = Q._spt(sk_k, Callable(), sg * t, N - 0.03 - 0.012 * (t - 0.62) / 0.53, 0.0018)
			var e1: Array = Q._spt(sk_k, Callable(), sg * t, N - 0.06 - 0.012 * (t - 0.62) / 0.53, 0.0018)
			k.strip([e0[0], e1[0]], [e0[1], e1[1]], 0.0014, 0.001, ink, false, func(p): return k.torso_skin(p.y))


## Uzun kapalı cübbe ağırlığı (parti e uzun giysi yöntemi): ön ortada iki bacak arası geniş harmanlanır (öne kalkan uyluğun iç yanı kumaşı delmez)
static func _robe_skin(k, p: Vector3, hem: float, au: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var kt: float = maxf(0.05, (H - k.K) / maxf(0.05, H - hem))
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var w: float = 0.96 * pow(minf(1.0, t / (kt * 0.8)), 0.3)
	var s: float = smoothstep(-0.06, 0.06, p.x)
	if au > -5.0:   # sarılı kapanış: alt kat sağ bacağı, üst kanat sol bacağı izler (adımda kanatlar birbirinin üstünde kayar, açıklık olmaz)
		s = smoothstep(-0.06, 0.06, -sin(clampf(au, 0.3, TAU - 0.3)) * 0.16)
	var kb: float = smoothstep(k.K + 0.02, k.K - 0.12, p.y) * smoothstep(0.02, -0.06, p.z) * 0.6 * absf(2.0 * s - 1.0)
	var sd: String = "Left" if s >= 0.5 else "Right"
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * (1.0 - kb)], [sd + "LowerLeg", w * kb]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Uzvu saran dikiş: ince halka + dikine iğne izleri
static func _stitch(k, l: Dictionary, s: float, lift: float, col: Color) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var bo: Array = P._lskin(l, s)
	var pts := []
	var ou := []
	for i in 28:
		var e: Array = K._lsurf(l, s, TAU * i / 28.0 - PI, lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, 0.0016, 0.001, col, true, func(_p): return bo)
	for i in 10:
		var a: float = TAU * i / 10.0 - PI
		var e0: Array = K._lsurf(l, s - 0.014 / L * 1.0, a, lift)
		var e1: Array = K._lsurf(l, s + 0.014 / L * 1.0, a, lift)
		k.strip([e0[0], e1[0]], [e0[1], e1[1]], 0.0014, 0.001, col, false, func(_p): return bo)
