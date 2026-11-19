extends RefCounted
## Elle modellenmiş setler, parti ao: ss_mikoshi, ss_yelpaze_kolsuz, ss_yelpaze_genc2, ss_yelpaze_takim, ss_sokak, ss_yelpaze_b. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/sasuke_outfit_{mikoshi, vs_itachi, young_ver_2, 2, 3, b}.png.
## Kumaş / uzuv yardımcıları parti e (P), i (I), k (K), q (Q), r (R), j (J), s (S), aj (AJ), aa (AA) dosyalarından.
## Burada: Uchiha yelpaze arması (kabartma katlar), yelpaze setlerinin ortak gömlek kesimi, Sasuke'nin dört dönemi + Mikoshi + Machi.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const AJ = preload("res://scripts/actors/set_el_aj.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const EA = preload("res://scripts/actors/set_el_a.gd")

const DONE := ["ss_yelpaze_b", "ss_yelpaze_genc2", "ss_yelpaze_takim", "ss_yelpaze_kolsuz", "ss_sokak", "ss_mikoshi"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	I._cur_leg = 0.58
	match sid:
		"ss_yelpaze_b": _ryoko_b(k)
		"ss_yelpaze_genc2": _kodomo2(k)
		"ss_yelpaze_takim": _seifuku(k)
		"ss_yelpaze_kolsuz": _sodenashi(k)
		"ss_sokak": _machi(k)
		"ss_mikoshi": _mikoshi(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Uchiha yelpazesi (sırt): koyu dış çerçeve, beyaz yuvarlak gövde, üstüne binen kırmızı yarım ay, altta sap. Her kat ayrı kalkışta (kabartma)
static func _crest(k, keys: Array, ff: Callable, cy: float, r: float, rim: Color, skinf: Callable) -> void:
	var mp: Callable = Q._local(keys, ff, PI, cy)
	var o: Vector3 = Q._spt(keys, ff, PI, cy)[1]
	var wh := Color(0.94, 0.93, 0.9)
	var rd := Color(0.76, 0.13, 0.13)
	# sap: çerçeve + beyaz iç
	R._lstrip(k, mp, [Vector2(0.0, -r * 0.82), Vector2(0.0, -r * 1.62)], r * 0.2, 0.0035, 0.0016, rim, skinf)
	R._lstrip(k, mp, [Vector2(0.0, -r * 0.86), Vector2(0.0, -r * 1.55)], r * 0.12, 0.0052, 0.0014, wh, skinf)
	Q._disc(k, mp, o, r * 1.1, 0.0035, Callable(), func(_u, _v): return rim, skinf, 3, 36)
	Q._disc(k, mp, o, r, 0.0052, Callable(), func(_u, _v): return wh, skinf, 4, 36)
	Q._disc(k, mp, o, r * 0.985, 0.0068, func(th): return 1.0 if sin(float(th)) >= 0.0 else minf(1.0, 0.07 / maxf(-sin(float(th)), 0.001)), func(_u, _v): return rd, skinf, 4, 36)


## Uzvu saran düz bant (bileklik / dirseklik altı): ad(s, a) altındaki kumaşın yarıçapı
static func _band_on(k, l: Dictionary, s0: float, s1: float, base: float, col: Color, ribs := 0.0) -> void:
	P._lt(k, l, func(s, a): return base + 0.002 * sin(clampf(inverse_lerp(s0, s1, float(s)), 0.0, 1.0) * PI) + (0.0012 * sin(float(a) * ribs) if ribs > 0.0 else 0.0), func(_s, a, ins):
		if ins:
			return col.darkened(0.35)
		return col.darkened(0.12) if ribs > 0.0 and sin(float(a) * ribs) < -0.3 else col, s0, s1, 6, 22)


# ------------------------------------------------------------------ yelpaze ortak kesimi
## Dik yakalı, önü fermuarlı gömlek gövdesi (yelpaze B / genç): yv fermuarın açıldığı yer (V'nin dibi), hem etek ucu. Döner: {keys, ff, sk, g}
static func _zip_shirt(k, b: Dictionary, col: Color, hem: float, yv: float, open_w: float, slack: float, sv: float) -> Dictionary:
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var top: float = N + 0.008
	var keys: Array = AJ._jkeys(k, b, top, hem, slack, slack + 0.012)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - 0.04 - y) / maxf(0.05, C - 0.04 - hem), 0.0, 1.0)
		var side: float = exp(-pow((aw - 1.45) / 0.35, 2.0))
		return t * (0.012 * sin(a * 6.0 + sv) + 0.006 * sin(a * 11.0 + sv * 1.7)) + 0.008 * side * sin(y * 46.0 + sv) * smoothstep(N - 0.02, C - 0.06, y) + 0.004 * sin(a * 5.0 + y * 17.0)
	var sk: Callable = AJ._jsk(k, hem)
	var e_at := func(v: float) -> float:
		var y: float = lerpf(top, hem, v)
		return 0.011 + open_w * smoothstep(yv, top, y)
	var g: Dictionary = P._cl(k, {"keys": keys, "ny": 40, "na": 92, "rng": func(v): return Vector2(float(e_at.call(float(v))), TAU - float(e_at.call(float(v)))),"top": func(_a): return top, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return col, "gain": 7.0, "th": 0.006, "inner": col.darkened(0.3), "skin": sk})
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._cord(k, hm, 0.0022, col.darkened(0.16), false, sk)
	return {"keys": keys, "ff": ff, "sk": sk, "g": g, "top": top}


## Açık fermuarın iki yanı: V kenarındaki bant + dişler, V'nin altında kapalı fermuar
static func _zip_v(k, sh: Dictionary, yv: float, hem: float, tape: Color, teeth: Color) -> void:
	var g: Dictionary = sh["g"]
	var sk: Callable = sh["sk"]
	for e in [g["ea"], g["eb"]]:
		var pts := []
		for p: Vector3 in e:
			if p.y > yv - 0.004:
				pts.append(p)
		if pts.size() >= 2:
			P._cord(k, pts, 0.0034, tape, false, sk)
	var ff: Callable = sh["ff"]
	AJ._zip(k, sh["keys"], func(a, y): return ff.call(float(a), float(y)), yv, hem + 0.006, tape, teeth, sk)


## Bota sokulan pantolon + açık yüzlü uzun bot konçu (Sasuke'nin çizmesi): döner pantolon yarıçapı
static func _pant_boot(k, le: Dictionary, col: Color, bk: Color, bag: float, sv: float) -> Callable:
	var kn: float = le["kn"]
	var s0: float = kn + 0.2
	var ad: Callable = I._pant(k, le, col, 0.015, bag, s0 + 0.02, 0.013, sv)
	AJ._boot(k, le, s0, bk, bk.lightened(0.07))
	return ad


# ------------------------------------------------------------------ Uchiha Ryokō B (ref sasuke_outfit_b): hafif açık dik yakalı (içi mor) kısa kollu mavimsi gri gömlek, önde göğüs ortasına dek açık fermuar,
## yanlarda mor ara parça, sırtta yelpaze; lacivert bileklik, bol lacivert pantolon, baldıra çıkan açık yüzlü siyah bot
static func _ryoko_b(k) -> void:
	var sh := Color(0.62, 0.62, 0.76)
	var pu := Color(0.47, 0.38, 0.72)
	var nv := Color(0.11, 0.13, 0.3)
	var bk := Color(0.11, 0.11, 0.125)
	var mt := Color(0.74, 0.74, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	R._bare_torso(k, b, C - 0.12, true)
	SE.body_layer(k, [P._kp(k.M(C - 0.1, k.UA), C - 0.1, 0.004), P._kp(b["wa"], H + 0.12, 0.006), P._kp(b["hp"], H - 0.04, 0.009)], 10, 44, func(_i, _j, _p): return nv)
	I._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_pant_boot(k, le, nv, bk, 0.02, 0.8 if sd == "Left" else 2.1)
		var ar: Dictionary = P._limb(k, sd, false)
		var s1: float = float(ar["kn"]) - 0.07
		R._arm_skin(k, ar, s1 - 0.06)
		AJ._sleeve(k, ar, sh, s1, 1.1 if sd == "Left" else 2.4, 0.016, 0.01, sh.darkened(0.25))
		_band_on(k, ar, 0.83, 0.975, 0.0075, nv, 14.0)
	var hem: float = H - 0.075
	var yv: float = C - 0.03
	var shd: Dictionary = _zip_shirt(k, b, sh, hem, yv, 0.42, 0.028, 0.9)
	var keys: Array = shd["keys"]
	var ff: Callable = shd["ff"]
	var sk: Callable = shd["sk"]
	_zip_v(k, shd, yv, hem, sh.darkened(0.12), mt)
	# yanlarda mor ara parça (koltuk altından etek ucuna)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, func(a, y): return ff.call(float(a), float(y)), [Vector2(sg * 1.57, C - 0.05), Vector2(sg * 1.6, H + 0.02), Vector2(sg * 1.62, hem + 0.024)], 0.016, 0.0025, 0.0024, pu, sk, 10)
	_crest(k, keys, func(a, y): return ff.call(float(a), float(y)), C - 0.07, 0.068, sh.darkened(0.45), sk)
	# dik yaka: önde açık, içi mor
	AJ._stand(k, nk, 0.088, 0.46, sh, pu, 0.032, 0.02)


## Dirseklik: dirseğin arkasını ve yanlarını saran sert yastık (iç kıvrım açık), üstünden geçen kayış, köşelerde perçin
static func _elbow_pad(k, ar: Dictionary, col: Color, strap: Color) -> void:
	var kn: float = ar["kn"]
	var ab: float = J._outer_a(ar, kn, Vector3(0.0, 0.0, -1.0))
	var s0: float = kn - 0.085
	var s1: float = kn + 0.085
	var addf := func(s: float, a: float) -> float: return 0.006 + 0.004 * sin(clampf(inverse_lerp(s0, s1, s), 0.0, 1.0) * PI) * exp(-pow(wrapf(a - ab, -PI, PI) / 1.3, 2.0))
	K._shell(k, ar, s0, s1, ab - 2.1, ab + 2.1, addf, 0.007, func(u, v, ins):
		if ins:
			return col.darkened(0.4)
		var e: float = minf(minf(float(u), 1.0 - float(u)) * 4.0, minf(float(v), 1.0 - float(v)) * 2.0)
		return col.darkened(0.22) if e < 0.12 else (col.lightened(0.06) if absf(float(v) - 0.5) < 0.12 else col), 12, 22)
	# iç kıvrımdan geçen kayış (yastığın iki ucunu bağlar)
	for s in [s0 + 0.03, s1 - 0.03]:
		P._lt(k, ar, func(ss, aa): return float(addf.call(float(ss), float(aa))) + 0.0045, func(_s, _a, ins): return strap.darkened(0.3) if ins else strap, s - 0.012, s + 0.012, 3, 22)
	for s in [s0 + 0.02, s1 - 0.02]:
		for da in [-1.2, 1.2]:
			var a: float = ab + da
			var e: Array = K._lsurf(ar, s, a, float(addf.call(s, a)) + 0.0075)
			P._stud(k, e[0], e[1], 0.0042, Color(0.42, 0.4, 0.36), P._lskin(ar, s))


## Kat kat sargı: alt bez + turlar; dark ise iki turda bir koyu bağ (ince kayış) turu
static func _wrap_run(k, l: Dictionary, s0: float, s1: float, n: int, add: float, wh: Color, dark: Color) -> void:
	P._lt(k, l, func(_s, _a): return add - 0.006, func(_s, _a, ins): return wh.darkened(0.35) if ins else wh.darkened(0.12), s0, s1, 10, 18)
	for i in n:
		var s: float = lerpf(s0 + 0.012, s1 - 0.008, float(i) / maxf(1.0, n - 1.0))
		var tn: Color = dark if i % 2 == 1 else wh.darkened(0.05 * float(i % 3))
		var hw: float = 0.0105 if i % 2 == 1 else 0.0135
		k.wrap_turn(P._lp(l, s), P._ld(l, s), P._lr(l, s) + add + (0.0015 if i % 2 == 1 else 0.0), hw, 0.008, tn, P._lskin(l, s))


# ------------------------------------------------------------------ Uchiha Kodomo Ni (ref sasuke_outfit_young_ver_2): içi gri astarlı yüksek dik yakalı kısa kollu siyah gömlek (sırtta yelpaze), iki dirsekte
## perçinli gri-bej dirseklik, sol kolda omuzdan ele beyaz sargı + siyah bağ turları, dize inen siyah şort, sağ uylukta iki beyaz bant + lacivert kese, baldırlarda siyah-beyaz sargı, siyah bot
static func _kodomo2(k) -> void:
	var bk := Color(0.1, 0.1, 0.115)
	var li := Color(0.6, 0.58, 0.53)
	var pd := Color(0.56, 0.52, 0.45)
	var wh := Color(0.9, 0.9, 0.92)
	var pc := Color(0.12, 0.13, 0.25)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return bk, 0.006, H - 0.03)
	var stk: Array = R._seat_keys(k, b)
	R._seat(k, stk, func(_i, _j, _p): return bk)
	# şort: dize iner; altı çıplak bacak, baldırda siyah-beyaz sargı, bilekte bot konçu
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 2.2
		var s1: float = kn - 0.015
		P._bare(k, le, skc, s1 - 0.06, 1.0)
		var ad: Callable = R._short_leg(k, le, bk, s1, 0.018, 0.02, sv)
		R._hem_roll(k, le, ad, s1, bk.lightened(0.03))
		_wrap_run(k, le, kn + 0.1, 0.9, 13, 0.0125, wh, bk)
		AJ._boot(k, le, 0.89, bk, bk.lightened(0.06))
		if sd == "Right":   # iki geniş beyaz bant + dış yanda lacivert kese
			var sb: float = kn * 0.5
			for s in [sb, sb + 0.085]:
				Q._ring_on(k, le, s, func(ss, aa): return float(ad.call(ss, aa)) + 0.0015, 0.0165, wh, 0.0035)
			var a: float = J._outer_a(le, sb + 0.05, Vector3(-1.0, 0.0, 0.1))
			var e: Array = J._lsurf(le, sb + 0.06, a, float(ad.call(sb + 0.06, a)) + 0.02)
			var o: Vector3 = e[1]
			var d: Vector3 = P._ld(le, sb)
			var bo := [["RightUpperLeg", 1.0]]
			P._boxr(k, (e[0] as Vector3) + d * 0.03, o.cross(d).normalized() * 0.042, -d * 0.075, o * 0.017, pc, bo, 0.22)
			P._boxr(k, (e[0] as Vector3) + o * 0.014 - d * 0.02, o.cross(d).normalized() * 0.044, -d * 0.024, o * 0.005, pc.lightened(0.08), bo, 0.25)
	# kollar: kısa kol, altı çıplak; iki dirsekte dirseklik; sol kolda sargı + el sargısı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var kn: float = ar["kn"]
		var s1: float = kn * 0.56
		R._arm_skin(k, ar, s1 - 0.06)
		AJ._sleeve(k, ar, bk, s1, 1.2 if sd == "Left" else 2.5, 0.014, 0.008, bk.lightened(0.04))
		if sd == "Left":
			_wrap_run(k, ar, kn - 0.07, 0.975, 15, 0.009, wh, bk)
			AJ._hand_wrap(k, sd, wh)
		_elbow_pad(k, ar, pd, pd.darkened(0.3))
	# gömlek: kalçaya iner, düz kesim
	var hem: float = H - 0.1
	var keys: Array = AJ._jkeys(k, b, N + 0.01, hem, 0.026, 0.04)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return t * (0.012 * sin(a * 6.0 + 0.4) + 0.005 * sin(a * 13.0 + 1.3)) + 0.004 * sin(a * 5.0 + y * 17.0)
	var sk: Callable = AJ._jsk(k, hem)
	var g: Dictionary = P._cl(k, {"keys": keys, "ny": 38, "na": 88, "top": func(_a): return N + 0.01, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.darkened(0.3), "skin": sk})
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._cord(k, hm, 0.0022, bk.lightened(0.06), true, sk)
	_crest(k, keys, func(a, y): return ff.call(float(a), float(y)), C - 0.07, 0.07, bk.lightened(0.12), sk)
	# yüksek dik yaka: önde dar aralık, içi gri astar
	AJ._stand(k, nk, 0.066, 0.12, bk, li, 0.03, 0.018)


# ------------------------------------------------------------------ Uchiha Seifuku (ref sasuke_outfit_2): alçak dik yakalı, önü fermuarlı koyu gri takım (kabarık uzun kollar), üstünde kalçaya inen açık mavi kolsuz
## sarma yelek: sol kanat boyundan sağ koltuk altına verev biner (biyeli kenar, sağ yanda koyu bağ), belin altında önde yırtmaç, sol yanda mor bağ; lacivert parmaksız eldiven,
## siyah pantolon, baldıra çıkan siyah bot
static func _seifuku(k) -> void:
	var gr := Color(0.25, 0.25, 0.29)
	var lb := Color(0.69, 0.78, 0.9)
	var nv := Color(0.12, 0.15, 0.27)
	var bk := Color(0.085, 0.085, 0.1)
	var pu := Color(0.38, 0.3, 0.62)
	var mt := Color(0.62, 0.62, 0.66)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return gr.darkened(0.2), 0.004, H - 0.03)
	I._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_pant_boot(k, le, bk, bk, 0.012, 0.6 if sd == "Left" else 1.9)
		var ar: Dictionary = P._limb(k, sd, false)
		AJ._sleeve(k, ar, gr, 0.9, 1.0 if sd == "Left" else 2.2, 0.02, 0.012, gr.darkened(0.3))
		S._mitt(k, sd, ar, nv)
	# takım gövdesi: kalçaya iner, önü fermuarlı
	var hem: float = H - 0.01
	var sh: Dictionary = _zip_shirt(k, b, gr, hem, N - 0.01, 0.0, 0.02, 1.4)
	var skeys: Array = sh["keys"]
	var sff: Callable = sh["ff"]
	AJ._zip(k, skeys, func(a, y): return sff.call(float(a), float(y)), N + 0.004, hem + 0.006, gr.darkened(0.15), mt, sh["sk"])
	AJ._stand(k, nk, 0.062, 0.06, gr, gr.darkened(0.25), 0.03, 0.006)
	# yelek: kolsuz, kalçaya iner; iki kanat
	var vhem: float = H - 0.06
	var top: float = N - 0.005
	var vk: Array = AJ._jkeys(k, b, top, vhem, 0.045, 0.06)
	var yk: float = C - 0.11
	var ys: float = H + 0.07
	var eL := func(y: float) -> float:
		if y >= yk:
			return lerpf(-0.92, 0.3, smoothstep(yk, top, y) * 0.35 + inverse_lerp(yk, top, y) * 0.65)
		return lerpf(-0.92, 0.055, smoothstep(yk, ys, y))
	var eR := func(y: float) -> float:
		if y >= ys:
			var r0: float = maxf(-0.3, float(eL.call(y)) + 0.12)
			return lerpf(-0.055, r0, smoothstep(ys, ys + 0.07, y))
		return -0.055
	var vf := func(a: float, y: float) -> float:
		var t: float = clampf((yk - y) / (yk - vhem), 0.0, 1.0)
		return t * (0.01 * sin(a * 5.0 + 0.6) + 0.004 * sin(a * 12.0 + 1.1)) + 0.004 * sin(a * 4.0 + y * 15.0)
	var vsk: Callable = AJ._jsk(k, vhem)
	var hole := func(a: float, y: float) -> float:   # kol oyuğu: omuzdan koltuk altına kesik (kolsuz)
		var aw: float = absf(wrapf(a, -PI, PI))
		return smoothstep(0.38, 0.12, absf(aw - PI * 0.5) / 1.0) * smoothstep(C - 0.07, C + 0.02, y)
	var col := func(_a, _y, _v): return lb
	var ytop := func(a: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var o: float = exp(-pow((aw - PI * 0.5) / 0.5, 2.0))
		return top - o * (top - (C - 0.06))
	var vR: Dictionary = P._cl(k, {"keys": vk, "ny": 34, "na": 56, "rng": func(v): return Vector2(-PI - 0.015, float(eR.call(lerpf(top, vhem, float(v))))), "top": ytop, "hem": func(_a): return vhem,
		"fold": func(a, y, _v): return float(vf.call(float(a), float(y))) - 0.012, "col": col, "gain": 6.0, "th": 0.006, "inner": lb.darkened(0.3), "skin": vsk})
	var vL: Dictionary = P._cl(k, {"keys": vk, "ny": 34, "na": 60, "rng": func(v): return Vector2(float(eL.call(lerpf(top, vhem, float(v)))), PI + 0.015), "top": ytop, "hem": func(_a): return vhem,
		"fold": func(a, y, _v): return vf.call(float(a), float(y)), "col": col, "gain": 6.0, "th": 0.006, "inner": lb.darkened(0.3), "skin": vsk})
	# biye: üst kanadın verev kenarı koyu kordon, sağ kanadın görünen kenarı + etek ucu + kol oyuğu ince biye
	P._cord(k, vL["ea"], 0.0035, nv.darkened(0.2), false, vsk)
	var rp := []
	for p: Vector3 in vR["eb"]:
		if float(eR.call(p.y)) < float(eL.call(p.y)) + 0.02:
			rp.append(p)
	if rp.size() >= 2:
		P._cord(k, rp, 0.0026, lb.darkened(0.18), false, vsk)
	for g in [vL, vR]:
		var hm := []
		for p: Vector3 in g["hem"]:
			hm.append(p + Vector3(0, 0.008, 0))
		P._cord(k, hm, 0.0024, lb.darkened(0.16), false, vsk)
		P._cord(k, g["top"], 0.0028, lb.darkened(0.14), false, vsk)
	# sağ yanda koyu bağ: düğüm + kumaşa oturan iki kısa uç
	var kf := func(a, y): return vf.call(float(a), float(y))
	var ke: Array = Q._spt(vk, kf, -0.98, yk + 0.005, 0.012)
	P._boxr(k, ke[0], Vector3.UP.cross(ke[1]).normalized() * 0.011, Vector3.UP * 0.009, (ke[1] as Vector3) * 0.007, nv.darkened(0.25), k.torso_skin(yk), 0.4)
	for da in [[-1.03, 0.05], [-0.95, 0.07]]:
		Q._run(k, vk, kf, [Vector2(float(da[0]), yk - 0.004), Vector2(float(da[0]) - 0.04, yk - float(da[1]))], 0.0045, 0.009, 0.0025, nv.darkened(0.25), vsk, 5)
	# sol yanda mor bağ
	Q._run(k, vk, kf, [Vector2(1.42, C - 0.07), Vector2(1.47, H + 0.06)], 0.012, 0.004, 0.003, pu, vsk, 8)
	Q._run(k, vk, kf, [Vector2(1.36, H + 0.12), Vector2(1.5, H + 0.1)], 0.008, 0.007, 0.003, pu.darkened(0.12), vsk, 5)
	_crest(k, vk, kf, C - 0.07, 0.068, lb.darkened(0.45), vsk)


# ------------------------------------------------------------------ Uchiha Sodenashi (ref sasuke_outfit_vs_itachi): kolsuz gri kimono üst (geniş yaka bandı, V belde kapanır, kürek kemikleri arasında yelpaze),
## göğüs ve karında beyaz sarashi, belde iki tur kalın mor shimenawa (sağ önde düğüm, dize sarkan ilmek + uç), dize inen lacivert bel örtüsü (sol önde açık mavi katlı kanat),
## bilekte ve elde beyaz sargı, bota sokulan lacivert pantolon, baldıra çıkan siyah bot
static func _sodenashi(k) -> void:
	var gr := Color(0.42, 0.42, 0.49)
	var nv := Color(0.12, 0.15, 0.36)
	var fl := Color(0.2, 0.3, 0.66)
	var pn := Color(0.1, 0.12, 0.27)
	var rp := Color(0.62, 0.5, 0.84)
	var wh := Color(0.93, 0.93, 0.93)
	var bk := Color(0.1, 0.1, 0.115)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var tk: Array = R._bare_torso(k, b, H + 0.02, true)
	# sarashi: göğüs altından bele, tur tur kabarık
	var sy0: float = C - 0.02
	var sk2 := [P._kp(k.M(sy0, k.UA), sy0, 0.006), P._kp(k.M(C - 0.12, k.UA), C - 0.12, 0.007), P._kp(wa, H + 0.12, 0.008), P._kp(k.M(H + 0.02, k.UA), H + 0.02, 0.009)]
	var turn := func(y: float) -> float: return fposmod((sy0 - y) / 0.026, 1.0)
	SE.body_layer(k, sk2, 30, 52, func(_i, _j, p): return wh.darkened(0.2 if float(turn.call(p.y)) < 0.16 else 0.0), func(a, y): return 0.03 * sin(float(turn.call(y)) * PI) + 0.004 * sin(a * 3.0 + y * 40.0))
	I._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_pant_boot(k, le, pn, bk, 0.022, 0.9 if sd == "Left" else 2.3)
		var ar: Dictionary = AA._bare_arm(k, sd)
		P._bare(k, ar, skc)
		_wrap_run(k, ar, 0.74, 0.975, 9, 0.008, wh, wh)
		AJ._hand_wrap(k, sd, wh)
	# kimono üst: kolsuz, sol kanat üstte, V belde kapanır
	var top: float = N + 0.008
	var hem: float = H - 0.02
	var keys := [P._kp(nk, top, 0.03), [N - 0.055, ch.x * 1.06, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(hp, hem, 0.04)]
	var ff := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 5.0 + y * 13.0) + 0.005 * sin(a * 9.0 - y * 21.0) * smoothstep(C, H + 0.06, y)
	var kf := func(a, y): return ff.call(float(a), float(y))
	var tsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.002))
	var yv: float = H + 0.1
	var eL := func(y: float) -> float: return lerpf(-0.04, 0.44, smoothstep(yv, top, y) * 0.3 + clampf(inverse_lerp(yv, top, y), 0.0, 1.0) * 0.7)
	var eR := func(y: float) -> float: return lerpf(0.04, -0.44, smoothstep(yv, top, y) * 0.3 + clampf(inverse_lerp(yv, top, y), 0.0, 1.0) * 0.7)
	var ytop := func(a: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		return top - exp(-pow((aw - PI * 0.5) / 0.42, 2.0)) * (top - (C - 0.075))
	var gcol := func(_a, _y, _v): return gr
	var gR: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 50, "rng": func(v): return Vector2(-PI - 0.015, float(eR.call(lerpf(top, hem, float(v))))), "top": ytop, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return float(ff.call(float(a), float(y))) - 0.012 * smoothstep(-0.6, -0.2, float(a)), "col": gcol, "gain": 6.0, "th": 0.006, "inner": gr.darkened(0.3), "skin": tsk})
	var gL: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 54, "rng": func(v): return Vector2(float(eL.call(lerpf(top, hem, float(v)))), PI + 0.015), "top": ytop, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": gcol, "gain": 6.0, "th": 0.006, "inner": gr.darkened(0.3), "skin": tsk})
	AA._edge_band(k, gL["ea"], 0.02, 0.005, gr.darkened(0.1), tsk, 1.0)
	AA._edge_band(k, gR["eb"], 0.02, 0.005, gr.darkened(0.1), tsk, -1.0)
	for g in [gL, gR]:
		P._cord(k, g["top"], 0.003, gr.darkened(0.12), false, tsk)
	Q._run(k, keys, kf, [Vector2(PI - 0.002, top - 0.012), Vector2(PI - 0.002, hem + 0.02)], 0.0016, 0.004, 0.0012, gr.darkened(0.3), tsk, 14)
	_crest(k, keys, kf, C - 0.03, 0.062, gr.darkened(0.45), tsk)
	# bel örtüsü: belden dizin üstüne sarılı lacivert bez; bindirme kenarı sol önde
	var ahem: float = lerpf(H, KN, 0.7)
	var fam := func(p): return AA._fam(k, p, KN + 0.0)
	var ak := [P._kp(k.M(H + 0.11, k.UA), H + 0.11, 0.05), P._kp(hp, H - 0.04, 0.05), [H - 0.16, hp.x + 0.07, hp.y + 0.075, hp.z - 0.07], [ahem, hp.x + 0.065, hp.y + 0.075, hp.z - 0.07]]
	var af := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - ahem), 0.0, 1.0)
		return t * (0.02 * sin(a * 6.0 + 0.9) + 0.012 * sin(a * 11.0 + 2.1)) + 0.006 * sin(a * 7.0 + y * 20.0)
	var hemf := func(a: float) -> float: return ahem + 0.02 * sin(a * 3.0 + 0.5) - 0.025 * exp(-pow((a - 0.55) / 0.35, 2.0))
	var ap: Dictionary = P._cl(k, {"keys": ak, "ny": 30, "na": 84, "rng": func(_v): return Vector2(0.22, TAU + 0.12), "top": func(_a): return H + 0.11, "hem": hemf,
		"fold": func(a, y, _v): return af.call(float(a), float(y)), "col": func(_a, _y, _v): return nv, "gain": 6.0, "th": 0.007, "inner": nv.darkened(0.3), "skin": fam})
	P._cord(k, ap["ea"], 0.004, nv.darkened(0.2), false, fam)
	# sol önde katlı açık mavi kanat
	var fp: Dictionary = P._cl(k, {"keys": ak, "ny": 22, "na": 26, "rng": func(v): return Vector2(0.18 + 0.06 * float(v), 1.2 - 0.08 * float(v)), "top": func(a): return H + 0.04 - 0.03 * float(a), "hem": func(a): return ahem - 0.02 - 0.03 * float(a), "lift": 0.012,
		"fold": func(a, y, _v): return float(af.call(float(a), float(y))) * 1.4 + 0.01 * sin(float(a) * 9.0), "col": func(_a, _y, _v): return fl, "gain": 5.0, "th": 0.006, "inner": nv, "skin": fam})
	P._cord(k, fp["ea"], 0.004, fl.darkened(0.15), false, fam)
	# kuşak: örtünün üstü katlanıp kıvrılır
	var bkk: Array = []
	for e in ak:
		bkk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	P._sash(k, bkk, H + 0.1, 0.035, 0.006, nv.lightened(0.04), 0.18)
	# shimenawa: iki tur, sağ önde düğüm
	var rsk := func(_s, p): return fam.call(p)
	for i in 2:
		var y: float = H + 0.118 - 0.058 * float(i)
		var pts: Array = EA._ring_pts(bkk, y, 0.034, 64)
		EA._rope(k, pts, true, 0.025, 3, 9.0, rp.darkened(0.04 * float(i)), func(_s, p): return k.torso_skin(maxf(float(p.y), H + 0.002)), 10)
	var kn0: Array = P._fp(bkk, -0.07, H + 0.09, true, 0.05)
	P._boxr(k, kn0[0], Vector3(0.03, 0, 0), Vector3(0, 0.032, 0), (kn0[1] as Vector3) * 0.022, rp.darkened(0.08), [["Hips", 1.0]], 0.45)
	# düğümden sarkan ilmek ve uç: bel örtüsünün üstünde durur (bacakla gider)
	var loop := []
	for j in 25:
		var t: float = float(j) / 24.0
		var x: float = -0.07 - 0.03 * sin(t * PI) + lerpf(0.0, -0.035, t)
		var y: float = H + 0.07 - (H + 0.07 - (KN + 0.07)) * sin(t * PI) * 0.98
		var lift: float = 0.035 + 0.01 * sin(t * PI)
		loop.append(P._fp(ak, x - 0.04 * sin(t * PI) * (1.0 - t), clampf(y, ahem + 0.02, H + 0.1), true, lift)[0])
	EA._rope(k, loop, false, 0.021, 3, 7.0, rp, rsk, 10)
	var tail := []
	for j in 16:
		var t: float = float(j) / 15.0
		tail.append(P._fp(ak, -0.13 - 0.04 * t, lerpf(H + 0.07, KN - 0.03, t), true, 0.034 - 0.006 * t)[0])
	EA._rope(k, tail, false, 0.023, 3, 6.0, rp, rsk, 10, func(s): return 1.0 - 0.15 * float(s))


## Boncuklu halka (bilezik / kolye): pts kapalı yol, boncuk sayısı n
static func _beads(k, pts: Array, r: float, n: int, col: Color, skinf: Callable, closed := true) -> void:
	P._tb(k, pts, func(s, _a): return r * (0.55 + 0.45 * absf(sin(float(s) * PI * n))), func(s, a, _p):
		var c0: Color = col.lightened(0.18) if cos(float(a)) > 0.5 else col
		return c0.darkened(0.3) if absf(sin(float(s) * PI * n)) < 0.3 else c0, func(_s, p): return skinf.call(p), 8, closed)


## Bilekte boncuk bilezik
static func _bracelet(k, ar: Dictionary, s: float, add: float, col: Color) -> void:
	var c: Vector3 = P._lp(ar, s)
	var d: Vector3 = P._ld(ar, s)
	var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri: Vector3 = (-d).cross(fw).normalized()
	var R0: float = P._lr(ar, s) + add
	var pts := []
	for i in 40:
		var a: float = TAU * i / 40.0
		pts.append(c + (ri * sin(a) + fw * cos(a)) * R0 + d * 0.004 * sin(a * 2.0))
	var bo: Array = P._lskin(ar, s)
	_beads(k, pts, 0.0048, 16, col, func(_p): return bo)


# ------------------------------------------------------------------ Machi Shōzoku (ref sasuke_outfit_3): siyah bisiklet yaka tişört, üstünde önü açık kısa kollu mor gömlek (arkası dik kalkık yaka, düğmeli
## pat, kıvrık kol ağzı), boyunda gümüş boncuk kolye, iki bilekte gümüş boncuk bilezik, bol düz haki-gri pantolon, sol uylukta beyaz-lacivert bant + lacivert kese
static func _machi(k) -> void:
	var pu := Color(0.3, 0.22, 0.44)
	var bk := Color(0.09, 0.09, 0.1)
	var ol := Color(0.41, 0.42, 0.36)
	var nv := Color(0.14, 0.15, 0.36)
	var wh := Color(0.9, 0.9, 0.92)
	var sv := Color(0.78, 0.79, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var bt: Array = R._bare_torso(k, b, C - 0.02, true)
	K._seat(k, b, ol)
	# pantolon: bol, düz iner, ayakkabıya dek; sol uylukta bant + kese
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv2: float = 0.5 if sd == "Left" else 1.8
		var ad: Callable = I._pant(k, le, ol, 0.024, 0.026, 0.955, 0.012, sv2)
		if sd == "Left":
			var sb: float = float(le["kn"]) * 0.55
			Q._ring_on(k, le, sb, func(ss, aa): return float(ad.call(ss, aa)) + 0.0012, 0.022, nv, 0.003)
			Q._ring_on(k, le, sb - 0.022, func(ss, aa): return float(ad.call(ss, aa)) + 0.0024, 0.0075, wh, 0.003)
			Q._ring_on(k, le, sb + 0.022, func(ss, aa): return float(ad.call(ss, aa)) + 0.0024, 0.0075, wh, 0.003)
			var a: float = J._outer_a(le, sb + 0.04, Vector3(1.0, 0.0, 0.0))
			var e: Array = J._lsurf(le, sb + 0.05, a, float(ad.call(sb + 0.05, a)) + 0.018)
			var o: Vector3 = e[1]
			var d: Vector3 = P._ld(le, sb)
			var bo := [["LeftUpperLeg", 1.0]]
			P._boxr(k, (e[0] as Vector3) + d * 0.03, o.cross(d).normalized() * 0.026, -d * 0.07, o * 0.015, nv, bo, 0.25)
			P._boxr(k, (e[0] as Vector3) + o * 0.012 - d * 0.03, o.cross(d).normalized() * 0.028, -d * 0.02, o * 0.005, nv.lightened(0.1), bo, 0.3)
	# tişört: bisiklet yaka, kalçaya iner
	var thm: float = H - 0.05
	var tk: Array = AJ._jkeys(k, b, N - 0.01, thm, 0.012, 0.05)
	var tff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - thm), 0.0, 1.0)
		return t * (0.01 * sin(a * 6.0 + 0.3) + 0.004 * sin(a * 13.0)) + 0.003 * sin(a * 5.0 + y * 19.0)
	var tsk: Callable = AJ._jsk(k, thm)
	var ntop := func(a: float) -> float: return N - 0.012 - 0.045 * pow(maxf(0.0, cos(a)), 2.0)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 32, "na": 80, "top": ntop, "hem": func(_a): return thm, "fold": func(a, y, _v): return tff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.005, "inner": bk.darkened(0.2), "skin": tsk})
	P._cord(k, tg["top"], 0.0042, bk.lightened(0.05), true, func(p): return k.torso_skin(p.y))
	var hm := []
	for p in tg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._cord(k, hm, 0.002, bk.lightened(0.05), true, tsk)
	# kolye: boyun dibinde gümüş boncuk dizisi
	var cp := []
	for i in 41:
		var a: float = lerpf(-PI, PI, float(i) / 41.0)
		var y: float = N - 0.006 - 0.05 * pow(maxf(0.0, cos(a)), 3.0)
		cp.append(Q._spt(bt, Callable(), a, y, 0.006)[0])
	_beads(k, cp, 0.0042, 34, sv, func(p): return k.torso_skin(p.y))
	# gömlek: önü açık, beli örter
	var hem: float = H - 0.01
	var gk: Array = AJ._jkeys(k, b, N + 0.004, hem, 0.034, 0.05)
	var gff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return t * (0.014 * sin(a * 5.0 + 0.8) + 0.006 * sin(a * 11.0 + 1.6)) + 0.005 * sin(a * 4.0 + y * 15.0)
	var gsk: Callable = AJ._jsk(k, hem)
	var e_at := func(v: float) -> float: return lerpf(0.5, 0.6, float(v))
	var g: Dictionary = P._cl(k, {"keys": gk, "ny": 34, "na": 90, "rng": func(v): return Vector2(float(e_at.call(float(v))), TAU - float(e_at.call(float(v)))), "top": func(_a): return N + 0.004, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return gff.call(float(a), float(y)), "col": func(_a, _y, _v): return pu, "gain": 6.0, "th": 0.006, "inner": pu.darkened(0.3), "skin": gsk})
	AA._edge_band(k, g["ea"], 0.014, 0.004, pu.lightened(0.04), gsk, 1.0)
	AA._edge_band(k, g["eb"], 0.014, 0.004, pu.lightened(0.04), gsk, -1.0)
	var ghm := []
	for p in g["hem"]:
		ghm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._cord(k, ghm, 0.0024, pu.darkened(0.15), false, gsk)
	var ea: Array = g["ea"]
	for i in 5:
		var p: Vector3 = ea[mini(ea.size() - 1, 8 + i * 6)]
		var o: Vector3 = Vector3(p.x, 0.0, p.z).normalized()
		var tgv: Vector3 = Vector3(o.z, 0.0, -o.x)
		P._stud(k, p + tgv * 0.012 + o * 0.0045, o, 0.0042, Color(0.2, 0.17, 0.27), gsk.call(p))
	# kalkık yaka: arkada dik, önde açık
	AJ._stand(k, nk, 0.072, 0.78, pu, pu.darkened(0.2), 0.036, 0.024)
	# kollar: dirseğin üstünde biten kısa kol (kıvrık ağız), çıplak ön kol, bilekte bilezik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var s1: float = float(ar["kn"]) - 0.06
		R._arm_skin(k, ar, s1 - 0.06)
		var sf: Callable = AJ._sleeve(k, ar, pu, s1, 0.7 if sd == "Left" else 2.0, 0.018, 0.01, pu.darkened(0.25))
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return pu.darkened(0.3) if ins else pu.lightened(0.04), s1 - 0.035, s1 + 0.002, 3, 20)
		_bracelet(k, ar, 0.935, 0.004, sv)


# ------------------------------------------------------------------ Mikoshi Shōzoku (ref sasuke_outfit_mikoshi): önü göğüsten açık uzun kollu kısa siyah ceket (göğüs üstünde iki yakayı bağlayan ip + toka),
## göğüs altından bele gri sarashi, ön kolda ve elde gri sargı, kalçayı saran kabarık kırmızı örtü (koyu kızıl blok desen, haki biyeli M bel ağzı, önde çapraz haki kenarlar,
## arkada dize sarkan kuyruk), diz altında haki manşetli siyah kapri, çıplak baldır
## Mikoshi kalça örtüsü ağırlığı: ön ve yan yüz uyluğu hemen ve tam izler (kalkan diz örtüyü önüne itmez, örtü uylukla kalkar),
## arkada ağırlık yavaş artar ve iki bacak arasına geniş yayılır (sarkan arka uç bölünmez)
static func _mksk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var bk: float = smoothstep(0.2, -0.6, cos(th))
	var d: float = H - p.y
	var t: float = clampf(d / maxf(0.05, H - hem), 0.0, 1.0)
	var wf: float = 0.98 * pow(minf(1.0, d / 0.07), 0.6)
	var wb: float = lerpf(0.78 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8)), 0.9, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.018, 0.12, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


static func _mikoshi(k) -> void:
	var bk := Color(0.085, 0.085, 0.1)
	var gy := Color(0.55, 0.56, 0.6)
	var rd := Color(0.62, 0.11, 0.1)
	var dr := Color(0.4, 0.06, 0.07)
	var kh := Color(0.8, 0.68, 0.45)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var bt: Array = R._bare_torso(k, b, C - 0.1, true)
	# sarashi: göğüs altından kalçaya, tur tur
	var sy0: float = C - 0.07
	var sk2 := [P._kp(k.M(sy0, k.UA), sy0, 0.006), P._kp(k.M(C - 0.12, k.UA), C - 0.12, 0.007), P._kp(wa, H + 0.12, 0.008), P._kp(k.M(H + 0.01, k.UA), H + 0.01, 0.009)]
	var turn := func(y: float) -> float: return fposmod((sy0 - y) / 0.024, 1.0)
	SE.body_layer(k, sk2, 30, 52, func(_i, _j, p): return gy.darkened(0.22 if float(turn.call(p.y)) < 0.15 else 0.0).lightened(0.05 * sin(p.x * 40.0 + p.y * 9.0)), func(a, y): return 0.028 * sin(float(turn.call(y)) * PI) + 0.004 * sin(a * 3.0 + y * 40.0))
	K._seat(k, b, bk)
	# kapri: diz altında haki manşet; altı çıplak baldır
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.13
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		var pa: Callable = AJ._pleg(k, le, bk, s1, 0.018, 0.024, 0.8 if sd == "Left" else 2.1, 0.35)
		AJ._turnup(k, le, pa, s1, 0.026, 0.004, kh)
	# ceket kolları: bileğe uzun, ön kolda gri sargının altına girer; elde gri sargı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sf: Callable = AJ._sleeve(k, ar, bk, 0.72, 1.1 if sd == "Left" else 2.3, 0.016, 0.008, bk.lightened(0.05))
		R._arm_skin(k, ar, 0.66)
		_wrap_run(k, ar, 0.66, 0.975, 12, 0.012, gy, gy)
		AJ._hand_wrap(k, sd, gy)
	# ceket gövdesi: önü göğüsten aşağı açık (yuvarlak köşe), yanlarda ve arkada bele iner
	var top: float = N + 0.006
	var jk: Array = AJ._jkeys(k, b, top, H + 0.03, 0.026, 0.03)
	var yc: float = C - 0.06
	var hemf := func(a: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		return lerpf(yc, H + 0.03, smoothstep(0.55, 1.25, aw))
	var jff := func(a: float, y: float) -> float: return 0.006 * sin(a * 5.0 + y * 14.0) + 0.004 * sin(a * 9.0 - y * 23.0)
	var jsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.002))
	var e_at := func(v: float) -> float: return lerpf(0.2, 0.62, smoothstep(0.0, 0.7, float(v)))
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 32, "na": 86, "rng": func(v): return Vector2(float(e_at.call(float(v))), TAU - float(e_at.call(float(v)))), "top": func(_a): return top, "hem": hemf,
		"fold": func(a, y, _v): return jff.call(float(a), float(y)), "col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.lightened(0.04), "skin": jsk})
	for e in [jg["ea"], jg["eb"]]:
		P._cord(k, e, 0.0032, bk.lightened(0.07), false, jsk)
	P._cord(k, jg["top"], 0.0034, bk.lightened(0.07), false, jsk)
	P._cord(k, jg["hem"], 0.0032, bk.lightened(0.07), false, jsk)
	# göğüs ipi: iki yakayı bağlar, sağda küçük toka
	var yr: float = N - 0.065
	var ea: Array = jg["ea"]
	var eb: Array = jg["eb"]
	var pick := func(ed: Array) -> Vector3:
		var best: Vector3 = ed[0]
		for p: Vector3 in ed:
			if absf(p.y - yr) < absf(best.y - yr):
				best = p
		return best
	var pl: Vector3 = pick.call(ea)
	var pr: Vector3 = pick.call(eb)
	var rope := []
	for i in 13:
		var t: float = float(i) / 12.0
		var x: float = lerpf(pl.x, pr.x, t)
		rope.append(P._fp(bt, x, yr - 0.004 * sin(t * PI), true, 0.006)[0])
	P._cord(k, rope, 0.0024, bk.lightened(0.04), false, func(p): return k.torso_skin(p.y))
	var cl: Vector3 = (rope[10] as Vector3) + Vector3(0, 0, 0.003)
	P._boxr(k, cl, Vector3(0.006, 0, 0), Vector3(0, 0.011, 0), Vector3(0, 0, 0.004), Color(0.3, 0.3, 0.32), k.torso_skin(yr), 0.3)
	# kırmızı örtü: kalçayı saran kabarık bez, önde uyluk ortasına, arkada dize sarkan kuyruk
	var rtop: float = H + 0.055
	var fhem: float = H - 0.26
	var bhem: float = KN + 0.11
	var fam := func(p): return _mksk(k, p, bhem)
	# ref ölçüsü: kalçadan bir parmak bol, uyluk ortasında bacaklara oturur (balon / bez gibi şişmez)
	var rk := [P._kp(k.M(rtop, k.UA), rtop, 0.026), [H + 0.0, hp.x + 0.045, hp.y + 0.055, hp.z - 0.05], [H - 0.11, hp.x + 0.062, hp.y + 0.07, hp.z - 0.068], [fhem, hp.x + 0.044, hp.y + 0.05, hp.z - 0.062], [bhem, hp.x + 0.01, hp.y + 0.035, hp.z - 0.05]]
	var rhem := func(a: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		return lerpf(fhem, bhem, pow(smoothstep(2.35, PI, aw), 0.8)) + 0.012 * sin(a * 4.0)
	var rff := func(a: float, y: float) -> float:
		var t: float = clampf((rtop - y) / (rtop - fhem), 0.0, 1.0)
		return sin(t * PI) * (0.03 * sin(a * 7.0 + 0.5) + 0.016 * sin(a * 13.0 + 1.9)) + 0.012 * sin(a * 9.0 + y * 25.0) * t
	var rg: Dictionary = P._cl(k, {"keys": rk, "ny": 36, "na": 96, "top": func(_a): return rtop, "hem": rhem, "fold": func(a, y, _v): return rff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.007, "inner": dr, "skin": fam})
	var rkf := func(a, y): return rff.call(float(a), float(y))
	# koyu kızıl blok desen: kumaşa dikili yamalar (kabartma)
	var seeds := [[0.35, H - 0.02, 0.03, 0.018], [-0.5, H - 0.09, 0.04, 0.014], [0.9, H - 0.13, 0.022, 0.02], [-1.1, H - 0.03, 0.03, 0.016], [1.5, H - 0.06, 0.035, 0.015], [-1.7, H - 0.12, 0.028, 0.02],
		[2.3, H - 0.02, 0.032, 0.016], [-2.5, H - 0.1, 0.03, 0.018], [3.0, H - 0.2, 0.026, 0.022], [0.05, H - 0.16, 0.03, 0.014], [-0.15, H + 0.0, 0.024, 0.012], [1.15, H - 0.0, 0.02, 0.014], [-2.0, H - 0.22, 0.03, 0.016], [2.0, H - 0.18, 0.028, 0.014]]
	for e in seeds:
		e[2] = float(e[2]) * 1.5
		e[3] = float(e[3]) * 1.5
		var mp: Callable = Q._local(rk, rkf, float(e[0]), float(e[1]))
		var o: Vector3 = Q._spt(rk, rkf, float(e[0]), float(e[1]))[1]
		var asp: float = float(e[3]) / float(e[2])
		Q._disc(k, mp, o, float(e[2]), 0.003, func(th): return 1.0 / maxf(absf(cos(float(th))), absf(sin(float(th))) / asp), func(_u, _v): return dr, fam, 2, 16)
		R._lstrip(k, mp, [Vector2(-float(e[2]) * 1.4, -float(e[3]) - 0.008), Vector2(float(e[2]) * 1.6, -float(e[3]) - 0.008)], 0.0028, 0.003, 0.0012, dr, fam)
	# haki biyeler: M bel ağzı, çapraz ön kenarlar, etek ucu
	Q._run(k, rk, rkf, [Vector2(-PI, rtop - 0.01), Vector2(-1.4, rtop - 0.008), Vector2(-0.55, rtop - 0.02), Vector2(0.0, rtop - 0.03), Vector2(0.55, rtop - 0.02), Vector2(1.4, rtop - 0.008), Vector2(PI, rtop - 0.01)], 0.014, 0.004, 0.004, kh, fam, 8)
	Q._run(k, rk, rkf, [Vector2(-1.0, H + 0.0), Vector2(-0.35, H - 0.08), Vector2(0.25, H - 0.15), Vector2(0.75, fhem + 0.035)], 0.011, 0.006, 0.0035, kh, fam, 8)
	Q._run(k, rk, rkf, [Vector2(0.95, H + 0.01), Vector2(0.3, H - 0.1), Vector2(-0.3, H - 0.16), Vector2(-0.7, fhem + 0.035)], 0.011, 0.009, 0.0035, kh, fam, 8)
	var rh := []
	for p: Vector3 in rg["hem"]:
		rh.append(p + Vector3(0, 0.012, 0))
	P._bd(k, rh, 0.011, 0.004, kh, true, fam)
