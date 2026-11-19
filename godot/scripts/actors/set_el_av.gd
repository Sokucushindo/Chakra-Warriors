extends RefCounted
## Elle modellenmiş setler, parti av: ss_harika_yildiz, ss_kaplumbaga, ss_genclik, ss_genclik_ruh, ss_genclik_ayi, ss_genclik_kedi. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/full/{wonder_4, youth_vars, youth_1..3, cat_breeder_m}, refs/outfits_ss/all/yagura_outfit/Yagura_1, refs/kiyafet/yagura.
## Gençlik ailesi tek ortak kesimde (_youth: bol kapüşonlu + boyna düşmüş kapüşon + bağcıklar, dirsek altı kol, sağ omuz arması, sağ bilek bandı,
## botta toplanan bol pantolon, sağ uylukta kılıf + kayış, kalçada çanta); her türevin farkı ayrı kabartma parçalarla.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), r (R), y (Y), n (N2), ar (AR) dosyalarından.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const N2 = preload("res://scripts/actors/set_el_n.gd")
const AR = preload("res://scripts/actors/set_el_ar.gd")

const DONE := ["ss_harika_yildiz", "ss_kaplumbaga", "ss_genclik", "ss_genclik_ruh", "ss_genclik_ayi", "ss_genclik_kedi"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_harika_yildiz": _yildiz(k)
		"ss_kaplumbaga": _kame(k)
		"ss_genclik": _genclik(k)
		"ss_genclik_ruh": _ruh(k)
		"ss_genclik_ayi": _ayi(k)
		"ss_genclik_kedi": _kedi(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Uzvun s kesitinde dış yönü dir'e en yakın açı
static func _oa(l: Dictionary, s: float, dir: Vector3) -> float:
	var best := 0.0
	var bv := -9.0
	var dn := dir.normalized()
	for i in 72:
		var a := TAU * i / 72.0 - PI
		var o: Vector3 = Q._ls(l, s, a, 0.0)[1]
		if o.dot(dn) > bv:
			bv = o.dot(dn)
			best = a
	return best


## Uzuv yüzeyi yerel eşlemesi (u çevre metre, v yukarı metre, kalkış); kumaşın o açıdaki gerçek kabarmasını izler
static func _lm(l: Dictionary, s0: float, a0: float, addf: Callable) -> Callable:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	return func(u: float, v: float, lift: float) -> Vector3:
		var s: float = s0 - v / L
		var r0: float = P._lr(l, s) + float(addf.call(s, a0))
		var a: float = a0 + u / maxf(0.02, r0)
		return Q._ls(l, s, a, float(addf.call(s, a)) + lift)[0]


## Yıldız kenar çarpanı (th yerel açı, uç yukarıda)
static func _star(th: float, rot := 0.0, ins := 0.44) -> float:
	var f := fposmod((th - PI * 0.5 - rot) / TAU * 5.0, 1.0)
	return lerpf(ins, 1.0, absf(f * 2.0 - 1.0))


## Yıldız çevre noktaları (yerel u, v)
static func _star_pts(r: float, rot: float, ins := 0.42, sub := 3) -> Array:
	var pts := []
	for i in 10:
		var r0: float = r if i % 2 == 0 else r * ins
		var r1: float = r * ins if i % 2 == 0 else r
		var t0: float = rot + PI * 0.5 + TAU * i / 10.0
		var t1: float = rot + PI * 0.5 + TAU * (i + 1) / 10.0
		for s in sub:
			pts.append((Vector2(cos(t0), sin(t0)) * r0).lerp(Vector2(cos(t1), sin(t1)) * r1, float(s) / sub))
	return pts


## Yüzey üstünde yerel (u, v) yolu boyunca kabartma çizgi
static func _lpath(k, mp: Callable, out: Vector3, pts2: Array, hw: float, lift: float, col: Color, skinf: Callable, closed := false) -> void:
	var pts := []
	var ou := []
	for q: Vector2 in pts2:
		pts.append(mp.call(q.x, q.y, lift))
		ou.append(out)
	k.strip(pts, ou, hw, 0.0014, col, closed, skinf)


## Gövde yüzeyine oturan dikdörtgen plaka: kenarları yüzeye iner
static func _plate(k, keys: Array, ff: Callable, a0: float, y0: float, w: float, h: float, lift: float, col: Color, skinf: Callable) -> void:
	var mp: Callable = Q._local(keys, ff, a0, y0)
	var o: Vector3 = Q._spt(keys, ff, a0, y0)[1]
	var rows := []
	for j in 7:
		var v := float(j) / 6.0
		var ro := []
		for i in 11:
			var u := float(i) / 10.0
			var e: float = minf(minf(u, 1.0 - u) * w, minf(v, 1.0 - v) * h)
			ro.append(mp.call((u - 0.5) * w, (0.5 - v) * h, -0.001 + (lift + 0.001) * smoothstep(0.0, 0.004, e)))
		rows.append(ro)
	Q._mesh(k, rows, false, func(i, j, _p): return col.darkened(0.2) if i == 0 or i == 10 or j == 0 or j == 6 else col, func(_i, _j, p): return skinf.call(p), o)


## Yüzey yerel eşlemesini ölçekler (kalkış ölçeklenmez)
static func _sc(mp: Callable, f: float) -> Callable:
	return func(u: float, v: float, l: float) -> Vector3: return mp.call(u * f, v * f, l)


## Yüzey yerel eşlemesini kaydırır
static func _sh(mp: Callable, du: float, dv: float) -> Callable:
	return func(u: float, v: float, l: float) -> Vector3: return mp.call(u + du, v + dv, l)


## Kumaşa oturan yuvarlak kabartma (pati yastığı, göz, burun)
static func _dot(k, mp: Callable, out: Vector3, u: float, v: float, r: float, sy: float, lift: float, col: Color, skinf: Callable, seg := 18) -> void:
	Q._disc(k, func(x: float, y: float, l: float) -> Vector3: return mp.call(u + x, v + y * sy, l), out, r, lift, Callable(), func(_u, _v): return col, skinf, 2, seg)


## Uzvu saran file örgü: iki yöne sarmal ince şeritler
static func _limb_net(k, l: Dictionary, addf: Callable, s0: float, s1: float, n: int, col: Color) -> void:
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	for dr in [1.0, -1.0]:
		for i in n:
			var a0 := TAU * i / n
			var pts := []
			var ou := []
			for j in 9:
				var s := lerpf(s0, s1, float(j) / 8.0)
				var r0: float = P._lr(l, s) + float(addf.call(s, a0))
				var a: float = a0 + dr * (s - s0) * L / maxf(0.02, r0)
				var e: Array = Q._ls(l, s, a, float(addf.call(s, a)) + 0.0012)
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, 0.0012, 0.0009, col, false, func(p): return R._lsk(l, p))


## Uzuv üstünde açıya göre biten kat (dişli alt kenar): s0..s1f(a); alt kenar içe döner
static func _leg_layer(k, l: Dictionary, addf: Callable, s0: float, s1f: Callable, colf: Callable, n := 16, seg := 40) -> void:
	var rows := []
	var ss := []
	for j in n + 3:
		var ro := []
		var sr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var se: float = s1f.call(a)
			var s: float = lerpf(s0, se, float(mini(j, n)) / n)
			var dr := 0.0
			if j == n + 1:
				dr = -0.0035
			elif j == n + 2:
				s = se - 0.02
				dr = -0.006
			ro.append(Q._ls(l, s, a, float(addf.call(s, a)) + dr)[0])
			sr.append(s)
		rows.append(ro)
		ss.append(sr)
	k.grid(rows, true, func(i, j, _p): return colf.call(ss[j][i], TAU * i / seg - PI, j > n), func(i, j, _p): return P._lskin(l, ss[j][i]))


## Bot konçu: s0'dan bileğe, üstte kalın ağız; colf(s, a) panel rengi
static func _shaft(k, le: Dictionary, s0: float, colf: Callable, rim: Color, base := 0.012, sv := 1.0) -> void:
	var f := func(s: float, a: float) -> float:
		return base + 0.003 * smoothstep(s0 + 0.05, s0, s) + 0.0014 * sin(a * 3.0 + s * 40.0 + sv) * smoothstep(s0 + 0.03, s0 + 0.08, s) * (1.0 - smoothstep(0.9, 0.97, s)) - 0.002 * smoothstep(0.93, 1.0, s)
	P._lt(k, le, f, func(s, a, ins): return rim.darkened(0.45) if ins else (colf.call(float(s), float(a)) as Color).darkened(0.12 * maxf(0.0, -cos(float(a))) * 0.5), s0, 0.995, 16, 24, 0.03)
	P._lt(k, le, func(s, a): return float(f.call(float(s), float(a))) + 0.0028, func(_s, _a, ins): return rim.darkened(0.45) if ins else rim, s0, s0 + 0.03, 4, 24, 0.02)


## Boyna düşmüş kapüşon (Y._hood_down kesimi, daha alçak yaka): boynu saran yumuşak halka + sırtta yatan torba
static func _hood(k, b: Dictionary, hk: Array, col: Color, inner: Color) -> void:
	var N: float = k.N
	var C: float = k.C
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	var hk2 := [[N + 0.07 * q, nk.x + 0.062, nk.y + 0.05, nk.z - 0.08], [N + 0.03 * q, nk.x + 0.062, nk.y + 0.054, nk.z - 0.074], [N - 0.01, nk.x + 0.07, nk.y + 0.06, nk.z - 0.07], [N - 0.06, ch.x * 0.82, ch.y * 0.9, ch.z * 0.98]]
	var hf := func(a: float, _y: float, v: float) -> float:
		return 0.045 * sin(float(v) * PI * 2.0 + cos(a) * 1.1) * smoothstep(0.0, 0.25, float(v)) * (1.0 - float(v) * 0.6) + 0.01 * sin(a * 8.0 + 0.7) * float(v)
	var cg: Dictionary = P._cl(k, {"keys": hk2, "ny": 12, "na": 60, "rng": func(_v): return Vector2(0.34, TAU - 0.34), "top": func(a):
		return N + q * lerpf(0.025, 0.07, smoothstep(0.3, 2.4, absf(float(a)))), "hem": func(a): return N - 0.045 - 0.02 * smoothstep(1.0, 2.6, absf(float(a))), "fold": hf,
		"col": func(_a, _y, _v): return col.lightened(0.02), "gain": 6.0, "inner": inner, "skin": nsk, "th": 0.007})
	P._cord(k, cg["top"], 0.0055, col.darkened(0.04), false, nsk)
	var sk2 := []
	for e2 in hk:
		sk2.append([e2[0], float(e2[1]) + 0.016, float(e2[2]) + 0.016, float(e2[3]) - 0.018])
	var bagf := func(a: float, _y: float, v: float) -> float:
		var db: float = clampf((PI - absf(a)) / 1.0, 0.0, 1.0)
		return 0.07 * sin(float(v) * PI) * (1.0 - db * db) + 0.01 * sin(a * 7.0 + 0.3) * float(v)
	var bg: Dictionary = P._cl(k, {"keys": sk2, "ny": 14, "na": 36, "rng": func(_v): return Vector2(PI - 1.0, PI + 1.0), "top": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return N + 0.02 - 0.07 * db * db, "hem": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return C - 0.03 + 0.08 * pow(db, 1.6), "fold": bagf, "col": func(_a, _y, _v): return col, "gain": 5.0, "inner": inner, "skin": tsk, "th": 0.006})
	P._cord(k, bg["hem"], 0.0048, col.darkened(0.06), false, tsk)


## Bol pantolon (Q._baggy kesimi, renk açıya / boya göre): tk'de toplanır, altı dar
static func _bag(k, le: Dictionary, colf: Callable, low: Color, base: float, bag: float, tk: float, sv: float, s_end := 0.86) -> Callable:
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		var g: float = 1.0 - smoothstep(tk - 0.03, tk + 0.005, s)
		var cr: float = 0.009 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var ru: float = 0.011 * exp(-pow((s - tk + 0.045) / 0.045, 2.0)) * sin(a * 9.0 + sv)
		return ((0.004 + bag * 0.12) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + cr + ru) * g
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = (base + bag * smoothstep(0.0, 0.42, s) * (1.0 - 0.18 * smoothstep(0.55, tk, s))) * (1.0 - 0.42 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s)))
		var g: float = smoothstep(tk - 0.06, tk + 0.008, s)
		return lerpf(v, 0.008, g) + float(fo.call(s, a))
	P._lt(k, le, ad, func(s, a, ins):
		var c0: Color = colf.call(float(s), float(a))
		if ins:
			return c0.darkened(0.45)
		return P._fs(c0, fo.call(s, a), 13.0), 0.0, tk + 0.012, 42, 24, 0.02)
	P._lt(k, le, func(s, a): return 0.0035 + 0.0015 * sin(float(a) * 5.0 + float(s) * 20.0) - 0.0015 * smoothstep(s_end - 0.04, s_end, float(s)), func(_s, a, ins): return low.darkened(0.4) if ins else low.darkened(0.08 if sin(float(a) * 5.0) < -0.3 else 0.0), tk - 0.05, s_end, 12, 18)
	return ad


# ------------------------------------------------------------------ Gençlik ortak kesimi (ref Shinobi Striker "Youth Striker" 4 renk)
## o: body, sleeve, hood, hood_in, rib, pant, pant_low, pcol(s,a), seat, bcol(a,y), raglan, hemf, rib_fold, cord, tip, logo (Callable(k, mp, out, skinf)),
## band, band_f(s,a)->Color, wb0, wb1, pouch, pouch2, strap, bag, bag2
static func _youth(k, o: Dictionary) -> Dictionary:
	var body: Color = o["body"]
	var slv: Color = o.get("sleeve", body)
	var hood: Color = o.get("hood", body)
	var rib: Color = o.get("rib", body)
	var pant: Color = o["pant"]
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# bol pantolon: botun içinde toplanır
	K._seat(k, b, o.get("seat", pant))
	var legs := {}
	var tk: float = o.get("tk", 0.78)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.7 if sd == "Left" else 2.3
		var ad: Callable = _bag(k, le, o.get("pcol", func(_s, _a): return pant), o.get("pant_low", pant), 0.016, 0.026, tk, sv, tk + 0.08)
		_shaft(k, le, tk + 0.02, o["boot"], o["boot_rim"], 0.012, sv)
		legs[sd] = [le, ad]
	# kapüşonlu gövde: omuzdan kalçaya bol kutu kesim, etekte ribana, ribananın üstünde kabaran kumaş
	var hem: float = H - 0.07
	var rh := 0.034
	var hk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.05), P._kp(hp, H - 0.03, 0.05), [hem, hp.x + 0.052, hp.y + 0.05, hp.z - 0.052]]
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 6.0 + 0.4) + 0.007 * sin(a * 11.0 + 1.3)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 17.0) * smoothstep(N - 0.02, C - 0.04, y) + 0.016 * smoothstep(hem + rh + 0.07, hem + rh, y) * (0.6 + 0.4 * sin(a * 9.0 + 0.5))
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var hsk := func(p): return Y._msk(k, p, hem)
	var tsk := func(p): return k.torso_skin(p.y)
	var bcol: Callable = o.get("bcol", func(_a, _y): return body)
	var raglan: bool = o.get("raglan", false)
	var rag := func(y: float) -> float: return lerpf(1.32, 0.5, smoothstep(C - 0.07, N + 0.01, y))
	var colf := func(a: float, y: float) -> Color:
		var aw: float = absf(a)
		if raglan and y > C - 0.075:
			var r0: float = rag.call(y)
			if aw > r0 and aw < PI - r0:
				return slv
		return bcol.call(a, y)
	P._cl(k, {"keys": hk, "ny": 40, "na": 88, "top": func(_a): return N + 0.012, "hem": func(_a): return hem + rh - 0.004, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(a, y, _v): return colf.call(float(a), float(y)), "gain": 6.0, "th": 0.006, "skin": hsk})
	if raglan:   # raglan dikişi: boyundan koltuk altına, önde ve arkada
		for sg in [1.0, -1.0]:
			for bk in [false, true]:
				var ctrl := []
				for i in 6:
					var y: float = lerpf(N + 0.004, C - 0.075, float(i) / 5.0)
					var a0: float = rag.call(y)
					ctrl.append(Vector2(sg * (PI - a0 if bk else a0), y))
				Q._run(k, hk, ffw, ctrl, 0.0026, 0.002, 0.0016, slv.darkened(0.25), tsk, 6)
	# etek ribanası (ayıda dalgalı beyaz etek)
	var hemf: Callable = o.get("hemf", func(_a): return hem)
	var rfold: Callable = o.get("rib_fold", func(a): return -0.018 + 0.012 * maxf(0.0, sin(float(a) * 33.0)))
	P._cl(k, {"keys": hk, "ny": 5, "na": 132, "top": func(_a): return hem + rh, "hem": hemf, "fold": func(a, _y, _v): return rfold.call(float(a)),
		"col": func(_a, _y, _v): return rib, "gain": 9.0, "th": 0.006, "skin": hsk})
	# kapüşon: boynu saran bol halka + sırtta yatan torba
	_hood(k, b, hk, hood, o.get("hood_in", hood.darkened(0.38)))
	# bağcıklar: kapüşon ağzından göğse iner, kumaşa yatar; ucunda metal
	var dc: Color = o.get("cord", Color(0.92, 0.92, 0.9))
	for sg in [1.0, -1.0]:
		var pts := []
		var yl: float = C - 0.07 - (0.012 if sg > 0.0 else 0.0)
		for i in 13:
			var t := float(i) / 12.0
			var y: float = lerpf(N - 0.03, yl, t)
			pts.append(Q._spt(hk, ffw, sg * (lerpf(0.26, 0.12, smoothstep(0.0, 0.4, t)) + 0.008 * sin(t * 7.0)), y, 0.0055)[0])
		P._cord(k, pts, 0.003, dc, false, tsk)
		var e: Array = Q._spt(hk, ffw, sg * (0.12 + 0.008 * sin(7.0)), yl, 0.0055)
		P._tb(k, [(e[0] as Vector3) + Vector3(0, 0.002, 0), (e[0] as Vector3) + Vector3(0, -0.013, 0)], func(_s, _a): return 0.0036, func(_s, a, _p): return o.get("tip", Color(0.75, 0.76, 0.8)).lightened(0.15 if cos(float(a)) > 0.3 else 0.0), func(_s, p): return k.torso_skin(p.y), 8)
	# dirsek altına inen bol kol, ağzı katlı; altı çıplak ön kol
	var arms := {}
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var s1: float = en + 0.13
		var sv: float = 1.2 if sd == "Left" else 2.6
		var sf: Callable = Y._sleeve(k, ar, slv, 0.018, 0.014, s1, sv, 0.045, o.get("cuff", slv), 0.0)
		P._bare(k, ar, skc, s1 - 0.06, 1.0)
		arms[sd] = [ar, sf, s1]
	# sağ omuz arması (kabartma)
	var ra: Dictionary = arms["Right"][0]
	var rsf: Callable = arms["Right"][1]
	var ls := 0.17
	var la: float = _oa(ra, ls, Vector3(-1.0, 0.35, 0.15))
	var lsk := func(p): return R._lsk(ra, p)
	if o.has("logo"):
		(o["logo"] as Callable).call(k, _lm(ra, ls, la, rsf), Q._ls(ra, ls, la, 0.0)[1], lsk)
	# sağ bilek bandı
	var w0: float = o.get("wb0", float(arms["Right"][2]) + 0.03)
	var w1: float = o.get("wb1", 0.88)
	var bandf: Callable = o.get("band_f", func(_s, _a): return o["band"])
	P._lt(k, ra, func(s, a): return 0.0058 + 0.0022 * sin(clampf((float(s) - w0) / (w1 - w0), 0.0, 1.0) * PI) + 0.0012 * exp(-pow((float(s) - w0) / 0.012, 2.0)) * sin(float(a) * 7.0),
		func(s, a, ins):
			var c0: Color = bandf.call(float(s), float(a))
			return c0.darkened(0.4) if ins else c0.darkened(0.12 * float(absf(float(s) - (w0 + w1) * 0.5) > (w1 - w0) * 0.42)), w0, w1, 12, 22)
	# sağ uylukta kılıf: uzun kese + kapak, uyluğu saran kayış, belden inen askı
	var rl: Dictionary = legs["Right"][0]
	var rad: Callable = legs["Right"][1]
	var ps := 0.23
	var pa: float = _oa(rl, ps, Vector3(-0.85, 0.0, 0.5))
	var pe: Array = Q._ls(rl, ps, pa, float(rad.call(ps, pa)) + 0.016)
	var pc: Vector3 = pe[0]
	var on: Vector3 = pe[1]
	var dl: Vector3 = P._ld(rl, ps)
	var ux: Vector3 = on.cross(dl).normalized()
	var pbo: Array = P._lskin(rl, ps)
	var pcol: Color = o.get("pouch", Color(0.1, 0.13, 0.3))
	var p2: Color = o.get("pouch2", pcol.darkened(0.15))
	var stc: Color = o.get("strap", pcol)
	Q._ring_on(k, rl, ps + 0.035, rad, 0.0075, stc, 0.006)
	P._boxr(k, pc, ux * 0.019, -dl * 0.058, on * 0.013, pcol, pbo, 0.35)
	P._boxr(k, pc + on * 0.008 - dl * 0.04, ux * 0.021, -dl * 0.022, on * 0.0075, p2, pbo, 0.4)
	var sp := []
	for i in 9:
		var t := float(i) / 8.0
		var s: float = lerpf(0.015, ps - 0.085, t)
		var a: float = lerpf(pa + 0.55, pa + 0.08, t)
		sp.append(Vector2(s, a))
	AR._lline(k, rl, sp, func(s, a): return float(rad.call(float(s), float(a))) + 0.003, 0.0065, 0.0025, stc)
	# kalçada çanta: arkada, kapüşonlunun altından görünür
	var sb: Vector3 = k.M(H - 0.11, 0.3)
	var bgc: Color = o.get("bag", Color(0.42, 0.27, 0.15))
	var bc := Vector3(0.0, H - 0.112, sb.z - 0.016 - 0.024)
	P._boxr(k, bc, Vector3(0.062, 0, 0), Vector3(0, 0.031, 0), Vector3(0, 0, -0.022), bgc, [["Hips", 1.0]], 0.4)
	P._boxr(k, bc + Vector3(0, 0.014, -0.012), Vector3(0.064, 0, 0), Vector3(0, 0.018, 0), Vector3(0, 0, -0.014), o.get("bag2", bgc.darkened(0.12)), [["Hips", 1.0]], 0.45)
	return {"keys": hk, "ff": ffw, "skin": hsk, "tsk": tsk, "hem": hem, "legs": legs, "arms": arms, "b": b}


# ------------------------------------------------------------------ Gençlik Striker (ref youth_1): siyah kapüşonlu, sağ omuzda kızıl Uzumaki arması, pembe bileklik, beyaz bol pantolon, lacivert kılıf, kahve çanta
static func _genclik(k) -> void:
	var bk := Color(0.094, 0.094, 0.11)
	var rd := Color(0.75, 0.15, 0.15)
	var pk := Color(0.816, 0.29, 0.502)
	_youth(k, {"boot": func(_s, a): return pk if absf(sin(float(a))) < 0.4 else bk.lightened(0.04), "boot_rim": bk, "body": bk, "rib": bk.lightened(0.02), "pant": Color(0.925, 0.925, 0.918), "pant_low": Color(0.94, 0.94, 0.94), "band": Color(0.88, 0.28, 0.5),
		"logo": func(kk, mp, out, sk): _uzumaki(kk, mp, out, sk, rd, 0.021)})


## Uzumaki arması: dolu daire + içe dönen sarmal (kabartma)
static func _uzumaki(k, mp: Callable, out: Vector3, sk: Callable, col: Color, r: float) -> void:
	Q._disc(k, mp, out, r, 0.0025, Callable(), func(_u, _v): return col, sk, 3, 28)
	var pts := []
	for i in 34:
		var t := float(i) / 33.0
		var th: float = t * TAU * 1.75
		var rr: float = r * lerpf(0.12, 0.78, t)
		pts.append(Vector2(cos(th), sin(th)) * rr)
	_lpath(k, mp, out, pts, r * 0.07, 0.0045, col.darkened(0.4), sk)


# ------------------------------------------------------------------ Gençlik Striker: Ruh (ref youth_2): beyaz gövde, kırmızı raglan kol ve kapüşon, sarı biyeli cepler, sırtta ateş topu, sarı daire arma, siyah bileklik,
## lacivert bol pantolon + kırmızı askı, beyaz kılıf, siyah-beyaz-kırmızı çanta
static func _ruh(k) -> void:
	var wh := Color(0.949, 0.949, 0.941)
	var rd := Color(0.784, 0.125, 0.125)
	var ye := Color(0.95, 0.78, 0.15)
	var bl := Color(0.118, 0.165, 0.69)
	var g: Dictionary = _youth(k, {"boot": func(s, _a): return rd if float(s) > 0.89 else wh, "boot_rim": rd, "body": wh, "sleeve": rd, "hood": rd, "rib": wh.darkened(0.04), "raglan": true, "pant": bl, "band": Color(0.1, 0.1, 0.12), "cuff": rd,
		"pouch": wh, "pouch2": Color(0.86, 0.88, 0.92), "strap": rd, "bag": Color(0.1, 0.1, 0.12), "bag2": wh, "cord": Color(0.95, 0.95, 0.93),
		"logo": func(kk, mp, out, sk):
			Q._disc(kk, mp, out, 0.02, 0.0025, Callable(), func(u, v): return ye.darkened(0.2) if Vector2(float(u), float(v)).length() > 0.84 else ye, sk, 3, 28)
			Q._circle(kk, mp, 0.011, 0.0016, 0.0042, rd, sk, 28)})
	var hk: Array = g["keys"]
	var ffw: Callable = g["ff"]
	var hsk: Callable = g["skin"]
	var tsk: Callable = g["tsk"]
	var H: float = k.H
	var C: float = k.C
	# yan cepler: dikine kesik ağız, sarı biye
	for sg in [1.0, -1.0]:
		var ctrl := [Vector2(sg * 0.6, H + 0.075), Vector2(sg * 0.66, H + 0.02), Vector2(sg * 0.7, H - 0.02)]
		Q._run(k, hk, ffw, ctrl, 0.0042, 0.0005, 0.0006, wh.darkened(0.55), hsk, 6)
		Q._run(k, hk, ffw, [ctrl[0] + Vector2(sg * 0.035, 0), ctrl[1] + Vector2(sg * 0.035, 0), ctrl[2] + Vector2(sg * 0.035, 0)], 0.0034, 0.003, 0.0024, ye, hsk, 6)
	# sırtta ateş topu: kızıl alev, turuncu iç, sarı çekirdek (kat kat kabartma)
	var fl := func(sc: float) -> Callable:
		return func(th: float) -> float:
			var up: float = maxf(0.0, sin(th))
			return 1.0 + sc * pow(up, 1.4) * (0.3 + 0.7 * pow(maxf(0.0, cos(5.0 * (th - PI * 0.5))), 2.0))
	var y0: float = C - 0.115
	var bo: Vector3 = Q._spt(hk, ffw, PI, y0)[1]
	Q._disc(k, Q._local(hk, ffw, PI, y0), bo, 0.046, 0.0035, fl.call(0.85), func(_u, _v): return rd, tsk, 3, 80)
	Q._disc(k, Q._local(hk, ffw, PI, y0 - 0.008), bo, 0.032, 0.0062, fl.call(0.6), func(_u, _v): return Color(0.96, 0.45, 0.12), tsk, 3, 60)
	Q._disc(k, Q._local(hk, ffw, PI, y0 - 0.014), bo, 0.017, 0.0088, Callable(), func(_u, _v): return ye.lightened(0.1), tsk, 2, 28)


# ------------------------------------------------------------------ Gençlik Striker: Kutup Ayısı (ref youth_3): suluboya açık mavi kapüşonlu (üstü açık, yanları koyu), dalgalı beyaz etek ucu, önde ayı yüzü + pati,
## kapüşonda ayı kulakları, sırtta ponpon kuyruk, baklava desenli bileklik, mavi baklava sıralı beyaz pantolon (dizden aşağı maviye döner)
static func _ayi(k) -> void:
	var bl := Color(0.4, 0.722, 0.91)
	var lb := Color(0.62, 0.84, 0.96)
	var wh := Color(0.949, 0.965, 1.0)
	var dk := Color(0.2, 0.3, 0.42)
	var H: float = k.H
	var C: float = k.C
	var N: float = k.N
	var hem: float = H - 0.07
	var g: Dictionary = _youth(k, {"boot": func(s, _a): return Color(0.478, 0.322, 0.196) if float(s) > 0.9 else Color(0.72, 0.55, 0.36), "boot_rim": wh, "body": bl, "hood": lb, "rib": wh, "pant": wh, "pant_low": lb, "seat": wh, "cord": Color(0.25, 0.32, 0.4), "tip": Color(0.25, 0.32, 0.4),
		"bcol": func(a, y):
			var t: float = smoothstep(C + 0.04, H - 0.03, float(y))
			var sd: float = exp(-pow((absf(float(a)) - 1.55) / 0.3, 2.0))
			return lb.lerp(bl, t).darkened(0.12 * sd),
		"hemf": func(a): return hem - 0.012 * sqrt(maxf(0.0, 1.0 - pow(fposmod(float(a) * 14.0 / TAU, 1.0) * 2.0 - 1.0, 2.0))),
		"rib_fold": func(_a): return -0.004,
		"pcol": func(s, _a): return wh.lerp(lb, smoothstep(0.52, 0.72, float(s))),
		"band": wh, "pouch": Color(0.14, 0.24, 0.62), "pouch2": Color(0.18, 0.3, 0.7), "strap": Color(0.14, 0.24, 0.62),
		"logo": func(kk, mp, out, sk):
			Q._disc(kk, mp, out, 0.02, 0.0025, Callable(), func(_u, _v): return wh, sk, 3, 28)
			Q._circle(kk, mp, 0.0125, 0.0016, 0.0042, bl, sk, 28)})
	var hk: Array = g["keys"]
	var ffw: Callable = g["ff"]
	var hsk: Callable = g["skin"]
	var tsk: Callable = g["tsk"]
	# önde sağ altta ayı yüzü
	var fa := -0.52
	var fy: float = H + 0.045
	var mp: Callable = _sc(Q._local(hk, ffw, fa, fy), 1.65)
	var o: Vector3 = Q._spt(hk, ffw, fa, fy)[1]
	for sg in [1.0, -1.0]:
		_dot(k, mp, o, sg * 0.019, 0.019, 0.0095, 1.0, 0.0034, wh, hsk)
		_dot(k, mp, o, sg * 0.019, 0.019, 0.0048, 1.0, 0.0052, Color(0.96, 0.72, 0.78), hsk, 12)
	Q._disc(k, mp, o, 0.026, 0.004, func(th): return 1.0 - 0.12 * maxf(0.0, -sin(float(th))), func(_u, _v): return wh, hsk, 3, 32)
	for sg in [1.0, -1.0]:
		_dot(k, mp, o, sg * 0.0095, 0.004, 0.0034, 1.0, 0.0068, dk, hsk, 12)
	_dot(k, _sh(mp, 0.0, -0.008), o, 0.0, 0.0, 0.009, 0.75, 0.0062, wh.darkened(0.04), hsk, 16)
	_dot(k, mp, o, 0.0, -0.005, 0.0032, 0.7, 0.0092, dk, hsk, 12)
	_lpath(k, mp, o, [Vector2(-0.006, -0.013), Vector2(-0.003, -0.0145), Vector2(0.0, -0.012), Vector2(0.003, -0.0145), Vector2(0.006, -0.013)], 0.0011, 0.0078, dk, hsk)
	# önde sol altta pati
	var pmp: Callable = _sc(Q._local(hk, ffw, 0.56, H + 0.03), 1.6)
	var po: Vector3 = Q._spt(hk, ffw, 0.56, H + 0.02)[1]
	_dot(k, pmp, po, 0.0, -0.004, 0.017, 0.82, 0.004, wh, hsk, 24)
	_dot(k, pmp, po, 0.0, -0.005, 0.009, 0.75, 0.0062, lb, hsk, 16)
	for e in [[-0.016, 0.012], [-0.006, 0.019], [0.006, 0.019], [0.016, 0.012]]:
		_dot(k, pmp, po, float(e[0]), float(e[1]), 0.0058, 1.1, 0.004, wh, hsk, 14)
		_dot(k, pmp, po, float(e[0]), float(e[1]), 0.003, 1.1, 0.0058, lb, hsk, 10)
	# kapüşonda ayı kulakları (sırtta yatan torbanın üst yanlarında)
	for sg in [1.0, -1.0]:
		var ea: float = sg * (PI - 0.62)
		var ey: float = N - 0.035
		var ep: Array = Q._spt(hk, ffw, ea, ey, 0.068)
		var eo: Vector3 = (ep[1] as Vector3).normalized()
		var eup: Vector3 = (Vector3.UP - eo * eo.dot(Vector3.UP)).normalized()
		var eux: Vector3 = eup.cross(eo).normalized()
		var ec: Vector3 = (ep[0] as Vector3) + Vector3(0, 0.014, 0)
		var ebo := [["UpperChest", 0.6], ["Neck", 0.4]]
		P._boxr(k, ec, eux * 0.027, eup * 0.025, eo * 0.01, lb, ebo, 0.85)
		P._boxr(k, ec + eo * 0.008 + eup * 0.002, eux * 0.016, eup * 0.015, eo * 0.005, Color(0.96, 0.72, 0.78), ebo, 0.85)
	# sırtta ponpon kuyruk
	var tp: Array = Q._spt(hk, ffw, PI, hem + 0.075, 0.0)
	var tc: Vector3 = (tp[0] as Vector3) + (tp[1] as Vector3) * 0.012
	P._boxr(k, tc + (tp[1] as Vector3) * 0.018, Vector3(0.024, 0, 0), Vector3(0, 0.023, 0), (tp[1] as Vector3) * 0.02, wh, [["Spine", 0.5], ["Hips", 0.5]], 0.95)
	# bileklik: beyaz üstüne mavi baklavalar
	var ar: Dictionary = g["arms"]["Right"][0]
	var s1: float = g["arms"]["Right"][2]
	var w0: float = s1 + 0.03
	var wc: float = (w0 + 0.88) * 0.5
	for i in 5:
		var a: float = TAU * i / 5.0
		var wmp: Callable = _lm(ar, wc, a, func(_s, _a): return 0.0075)
		AR._dia(k, wmp, Q._ls(ar, wc, a, 0.0)[1], 0.0, 0.0, 0.0085, 0.024, 0.0022, bl, func(p): return R._lsk(ar, p))
	# pantolon: uyluk önünde mavi baklava sıraları (argyle)
	for sd in ["Left", "Right"]:
		var le: Dictionary = g["legs"][sd][0]
		var ad: Callable = g["legs"][sd][1]
		var sg: float = le["sg"]
		var lsk := func(p): return R._lsk(le, p)
		for col_i in 2:
			var dir := Vector3(sg * (0.75 if col_i == 0 else -0.1), 0.0, 1.0)
			for r in 5:
				var s: float = 0.07 + 0.088 * r + (0.044 if col_i == 1 else 0.0)
				if s > 0.5:
					continue
				var a: float = _oa(le, s, dir)
				AR._dia(k, _lm(le, s, a, ad), Q._ls(le, s, a, 0.0)[1], 0.0, 0.0, 0.022 if col_i == 0 else 0.015, 0.034 if col_i == 0 else 0.024, 0.0035, bl if col_i == 0 else lb, lsk)


# ------------------------------------------------------------------ Gençlik Striker: Kedi Bakıcısı (ref cat_breeder_m): yeşil örgü kazak, gri kapüşon (içi siyah), göğüste siyah-sarı-siyah şerit + beyaz fisto,
## iki siyah kedi patisi, kızıl arma, sağ kolda siyah kolluk, üstü dişli kenarlı gri / altı siyah bol pantolon, dizlerde kedi yüzü, kızıl kılıf
static func _kedi(k) -> void:
	var gn := Color(0.165, 0.541, 0.227)
	var gy := Color(0.478, 0.478, 0.494)
	var bk := Color(0.094, 0.094, 0.11)
	var ye := Color(0.95, 0.82, 0.25)
	var wh := Color(0.95, 0.95, 0.93)
	var rd := Color(0.82, 0.3, 0.3)
	var C: float = k.C
	var H: float = k.H
	var g: Dictionary = _youth(k, {"boot": func(_s, a): return Color(0.25, 0.75, 0.32) if absf(absf(sin(float(a))) - 0.55) < 0.06 else Color(0.118, 0.353, 0.165).darkened(0.25), "boot_rim": Color(0.118, 0.353, 0.165), "body": gn, "hood": gy, "hood_in": bk, "rib": gn.darkened(0.06), "pant": bk, "pant_low": bk, "seat": gy, "band": bk, "wb0": 0.6, "wb1": 0.95, "cord": gy.lightened(0.2),
		"bcol": func(a, y): return gn.darkened(0.07 * float(sin(float(a) * 46.0) * sin(float(y) * 260.0) > 0.25)),
		"pouch": Color(0.86, 0.42, 0.45), "pouch2": Color(0.78, 0.3, 0.32), "strap": Color(0.86, 0.42, 0.45),
		"logo": func(kk, mp, out, sk): _uzumaki(kk, mp, out, sk, Color(0.8, 0.22, 0.2), 0.02)})
	var hk: Array = g["keys"]
	var ffw: Callable = g["ff"]
	var hsk: Callable = g["skin"]
	var tsk: Callable = g["tsk"]
	# göğüs şeridi: siyah - sarı - siyah, tüm gövdeyi sarar
	var yb: float = C - 0.072
	for e in [[yb + 0.016, 0.0045, bk], [yb, 0.0105, ye], [yb - 0.016, 0.0045, bk]]:
		var ctrl := []
		for i in 24:
			ctrl.append(Vector2(TAU * i / 24.0 - PI, float(e[0])))
		ctrl.append(Vector2(PI, float(e[0])))
		Q._run(k, hk, ffw, ctrl, float(e[1]), 0.0032, 0.0022, e[2], tsk, 4)
	# fisto: şeridin altında yarım daire dilimli beyaz bant
	var yl: float = yb - 0.02
	var rows := []
	var na := 144
	for j in 4:
		var v := float(j) / 3.0
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var x: float = fposmod(a * 18.0 / TAU, 1.0) * 2.0 - 1.0
			var bot: float = yl - 0.02 - 0.009 * sqrt(maxf(0.0, 1.0 - x * x))
			ro.append(Q._spt(hk, ffw, a, lerpf(yl, bot, v), 0.0032 + 0.0012 * sin(v * PI))[0])
		rows.append(ro)
	Q._mesh(k, rows, true, func(i, j, _p): return wh.darkened(0.12) if j == 3 or (i % 8 == 4 and j == 1) else wh, func(_i, _j, p): return tsk.call(p), P._out(rows[1][0]))
	# iki siyah pati
	for sg in [1.0, -1.0]:
		var mp: Callable = _sc(Q._local(hk, ffw, sg * 0.46, H + 0.035), 1.75)
		var o: Vector3 = Q._spt(hk, ffw, sg * 0.46, H + 0.02)[1]
		_dot(k, mp, o, 0.0, -0.006, 0.02, 0.8, 0.004, bk, hsk, 24)
		for e in [[-0.019, 0.011], [-0.007, 0.02], [0.007, 0.02], [0.019, 0.011]]:
			_dot(k, mp, o, float(e[0]), float(e[1]), 0.0068, 1.15, 0.004, bk, hsk, 14)
	# pantolon: üstü dişli kenarlı gri kat, dizde kedi yüzü
	for sd in ["Left", "Right"]:
		var le: Dictionary = g["legs"][sd][0]
		var ad: Callable = g["legs"][sd][1]
		var sv: float = 0.4 if sd == "Left" else 1.9
		_leg_layer(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.0035, 0.0, func(a): return 0.3 - 0.045 * Y._teeth(float(a), 7.0, sv * 0.1),
			func(_s, a, ins): return gy.darkened(0.4) if ins else gy.darkened(0.06 * float(sin(float(a) * 40.0) > 0.4)), 18, 56)
		var kn: float = le["kn"]
		var s: float = kn - 0.015
		var fa: float = _oa(le, s, Vector3(0, 0, 1))
		var mp: Callable = _sc(_lm(le, s, fa, ad), 1.35)
		var o: Vector3 = Q._ls(le, s, fa, 0.0)[1]
		var lsk := func(p): return R._lsk(le, p)
		var fc := bk.lightened(0.07)
		Q._disc(k, mp, o, 0.03, 0.0035, func(th): return 1.0 - 0.12 * maxf(0.0, -sin(float(th))), func(_u, _v): return fc, lsk, 3, 32)
		for e2 in [-1.0, 1.0]:
			Q._disc(k, _sh(mp, e2 * 0.018, 0.024), o, 0.011, 0.0035, func(th): return 0.45 + 0.55 * pow(maxf(0.0, sin(float(th))), 3.0) * 1.0 + 0.0, func(_u, _v): return fc, lsk, 2, 16)
		var lc := Color(0.82, 0.82, 0.8)
		for e2 in [-1.0, 1.0]:
			var eye := []
			for i in 7:
				var t: float = float(i) / 6.0 * 2.0 - 1.0
				eye.append(Vector2(e2 * 0.011 + t * 0.006, 0.004 - 0.003 * (1.0 - t * t)))
			_lpath(k, mp, o, eye, 0.0011, 0.0058, lc, lsk)
			for w in 3:
				var wy: float = -0.006 + 0.004 * float(w - 1)
				_lpath(k, mp, o, [Vector2(e2 * 0.017, wy), Vector2(e2 * 0.029, wy + 0.003 * float(w - 1)), Vector2(e2 * 0.04, wy + 0.006 * float(w - 1))], 0.0009, 0.006, lc, lsk)
		_dot(k, mp, o, 0.0, -0.003, 0.0032, 0.7, 0.0058, Color(0.9, 0.55, 0.6), lsk, 10)


# ------------------------------------------------------------------ Kōkishin Striker: Yıldız (ref wonder_4): çizgi yıldızlı uzun beyaz tişört, önü açık düz siyah hırka (balon kol, bilekte manşet),
## beyaz yıldızlı mavi kapri (baldır ortasında biter), altında siyah tozluk
static func _yildiz(k) -> void:
	var wh := Color(0.933, 0.933, 0.949)
	var bk := Color(0.078, 0.078, 0.094)
	var bl := Color(0.165, 0.165, 0.604)
	var sw := Color(0.949, 0.949, 0.957)
	var ink := Color(0.094, 0.094, 0.11)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	# kapri + tozluk
	K._seat(k, b, bl)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.2
		var sv: float = 0.5 if sd == "Left" else 1.7
		var sg: float = le["sg"]
		var fo := func(s: float, a: float) -> float:
			return 0.005 * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + 0.006 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var cap := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			return (0.016 + 0.01 * smoothstep(0.0, 0.3, s)) * (1.0 - 0.4 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s))) + float(fo.call(s, a))
		P._lt(k, le, cap, func(s, a, ins): return bl.darkened(0.45) if ins else P._fs(bl, fo.call(float(s), float(a)), 12.0), 0.0, s1, 36, 24, 0.03)
		P._lt(k, le, func(s, a): return float(cap.call(float(s), float(a))) + 0.0028, func(_s, _a, ins): return bl.darkened(0.4) if ins else bl.darkened(0.06), s1 - 0.035, s1, 4, 24)
		P._lt(k, le, func(s, a): return 0.0045 + 0.0015 * sin(float(a) * 3.0 + float(s) * 30.0) * exp(-pow((float(s) - s1) / 0.05, 2.0)), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.04), s1 - 0.07, 0.995, 16, 18)
		# beyaz yıldızlar: dört sütun, sıra sıra kaydırılmış
		var lsk := func(p): return R._lsk(le, p)
		for r in 6:
			var s: float = 0.07 + 0.105 * r
			if s > s1 - 0.04:
				continue
			for c in 4:
				var dirs := [Vector3(0.0, 0.0, 1.0), Vector3(sg, 0.0, 0.25), Vector3(0.0, 0.0, -1.0), Vector3(sg * 0.6, 0.0, -0.6)]
				var d0: Vector3 = dirs[c]
				var a: float = _oa(le, s, d0) + (0.35 if r % 2 == 1 else 0.0)
				var rr: float = 0.02 + 0.007 * fposmod(float(r * 7 + c * 3) * 0.37, 1.0)
				var rot: float = 0.5 * sin(float(r * 5 + c * 11))
				Q._disc(k, _lm(le, s, a, cap), Q._ls(le, s, a, 0.0)[1], rr, 0.003, func(th): return _star(float(th), rot), func(u, v): return sw.darkened(0.12) if Vector2(float(u), float(v)).length() > 0.9 else sw, lsk, 2, 40)
	# uzun beyaz tişört
	var th: float = H - 0.1
	var tk := [P._kp(nk, N + 0.01, 0.006), [N - 0.05, ch.x * 0.98, ch.y * 0.93, ch.z * 1.0], P._kp(ch, C - 0.03, 0.014), P._kp(wa, H + 0.12, 0.024), P._kp(hp, H - 0.03, 0.03), [th, hp.x + 0.042, hp.y + 0.038, hp.z - 0.038]]
	var tf := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - th), 0.0, 1.0)
		return t * (0.02 * sin(a * 6.0 + 0.7) + 0.008 * sin(a * 13.0 + 0.2)) + (1.0 - t) * 0.004 * sin(a * 5.0 + y * 19.0)
	var tsk2 := func(p): return Y._msk(k, p, th)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 36, "na": 80, "top": func(_a): return N + 0.01, "hem": func(_a): return th, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return wh, "gain": 7.0, "th": 0.005, "skin": tsk2})
	var nb := []
	for p in tg["top"]:
		nb.append((p as Vector3) + Vector3(0, -0.006, 0))
	P._bd(k, nb, 0.0062, 0.0024, wh.darkened(0.05), true, nsk)
	var hm := []
	for p in tg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hm, 0.0035, 0.0015, wh.darkened(0.12), true, tsk2)
	# göğüste iki çizgi yıldız + aralarında kırık çizgi
	var tfw := func(a, y): return tf.call(float(a), float(y))
	for e in [[0.13, C + 0.008, 0.033, 0.15], [0.06, C - 0.095, 0.03, -0.2]]:
		var mp: Callable = Q._local(tk, tfw, float(e[0]), float(e[1]))
		var o: Vector3 = Q._spt(tk, tfw, float(e[0]), float(e[1]))[1]
		_lpath(k, mp, o, _star_pts(float(e[2]), float(e[3])), 0.0016, 0.0028, ink, tsk, true)
	var zz := []
	for i in 9:
		var t := float(i) / 8.0
		zz.append(Vector2(lerpf(0.115, 0.08, t) + (0.03 if i % 2 == 1 else 0.0) * 0.25, lerpf(C - 0.026, C - 0.064, t)))
	var zp := []
	var zo := []
	for q: Vector2 in zz:
		var e2: Array = Q._spt(tk, tfw, q.x, q.y, 0.0028)
		zp.append(e2[0])
		zo.append(e2[1])
	k.strip(zp, zo, 0.0015, 0.0014, ink, false, tsk)
	# önü açık siyah hırka: düz kenarlar, boyunda devrik bant
	var hem: float = H - 0.13
	var ck := [P._kp(nk, N + 0.014, 0.034), [N - 0.055, ch.x * 1.06, ch.y * 0.98, ch.z * 1.08], P._kp(ch, C - 0.03, 0.042), P._kp(wa, H + 0.12, 0.062), P._kp(hp, H - 0.03, 0.064), [hem, hp.x + 0.078, hp.y + 0.062, hp.z - 0.072]]
	var e_at := func(y: float) -> float: return lerpf(0.52, 0.98, smoothstep(C - 0.03, N + 0.014, y)) + 0.04 * smoothstep(H, hem, y)
	var cf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.5, 0.8, aw) * (t * (0.026 * sin(a * 7.0 + 0.5) + 0.01 * sin(a * 12.0 + 1.1)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 15.0)) + 0.012 * exp(-pow((aw - 1.55) / 0.25, 2.0)) * t
	var cfw := func(a, y): return cf.call(float(a), float(y))
	var csk := func(p): return Y._msk(k, p, hem)
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 42, "na": 90, "rng": func(v):
		var e: float = e_at.call(lerpf(N + 0.014, hem, float(v)))
		return Vector2(e, TAU - e),
		"top": func(_a): return N + 0.014, "hem": func(_a): return hem, "fold": func(a, y, _v): return cf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 5.0, "th": 0.007, "inner": bk.lightened(0.04), "skin": csk})
	for ed in [cg["ea"], cg["eb"]]:
		P._bd(k, ed, 0.011, 0.0042, bk.lightened(0.05), false, csk, 0.0)
	var cb := []
	for p in cg["top"]:
		cb.append((p as Vector3) + Vector3(0, -0.009, 0))
	P._bd(k, cb, 0.011, 0.0045, bk.lightened(0.05), false, nsk, 0.6)
	var ch2 := []
	for p in cg["hem"]:
		ch2.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, ch2, 0.0035, 0.0016, bk.darkened(0.3), false, csk)
	# yan dikişler
	for sg in [1.0, -1.0]:
		Q._run(k, ck, cfw, [Vector2(sg * 1.57, C - 0.06), Vector2(sg * 1.6, H), Vector2(sg * 1.62, hem + 0.012)], 0.0024, 0.0015, 0.0014, bk.lightened(0.07), csk, 8)
	# balon kollar, bilekte toplanan manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		Y._sleeve(k, ar, bk, 0.022, 0.03, 0.965, 1.3 if sd == "Left" else 2.4, 0.07, bk.lightened(0.04), 0.0)


# ------------------------------------------------------------------ Kame Shōzoku (ref Yagura_1, Yagura anime): file omuzlu kısa kollu mor-gri üst, sol omuzdan sağ kalçaya verev kayış + beyaz toka + göğüs plakası,
## çeneye kadar yığılan kalın yosun yeşili atkı (omuzlara dökülür), dize inen önü açık sargı örtü + turkuaz kuşak (sarkan iki uç), sol bilekte plakalı siyah bileklik,
## botun içine giren bol koyu mor pantolon
static func _kame(k) -> void:
	var sh := Color(0.29, 0.29, 0.416)
	var pc := Color(0.227, 0.227, 0.345)
	var gn := Color(0.361, 0.416, 0.188)
	var te := Color(0.2, 0.5, 0.42)
	var dk := Color(0.11, 0.11, 0.13)
	var gy := Color(0.66, 0.66, 0.7)
	var nt := sh.lightened(0.22)
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
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	# bol pantolon
	K._seat(k, b, pc)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_bag(k, le, func(_s, _a): return pc, pc.darkened(0.05), 0.018, 0.034, 0.7, 0.9 if sd == "Left" else 2.2, 0.8)
		var bn := Color(0.353, 0.227, 0.157)
		_shaft(k, le, 0.72, func(_s, a): return bn.lightened(0.05 * float(cos(float(a)) > 0.6)), bn.darkened(0.15), 0.013, 0.9 if sd == "Left" else 2.2)
	# üst: kalçaya inen düz kesim (örtünün altına girer)
	var sk := [P._kp(nk, N + 0.012, 0.008), [N - 0.05, ch.x * 0.99, ch.y * 0.93, ch.z * 1.01], P._kp(ch, C - 0.03, 0.016), P._kp(wa, H + 0.12, 0.022), P._kp(wa, H - 0.0, 0.026)]
	var sf := func(a: float, y: float) -> float: return 0.008 * sin(a * 6.0 + y * 13.0) * smoothstep(C - 0.02, H + 0.08, y) + 0.004 * sin(a * 9.0 - y * 20.0)
	P._cl(k, {"keys": sk, "ny": 28, "na": 76, "top": func(_a): return N + 0.012, "hem": func(_a): return H, "fold": func(a, y, _v): return sf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return sh, "gain": 7.0, "th": 0.005, "skin": tsk})
	# omuz fileleri
	for sg in [1.0, -1.0]:
		var a0: float = 0.62 if sg > 0.0 else -1.78
		Q._net(k, sk, a0, a0 + 1.16, C - 0.08, N - 0.012, 0.02, 0.0012, 0.0022, nt)
		var a1: float = PI - 1.78 if sg > 0.0 else -PI + 0.62
		Q._net(k, sk, a1, a1 + 1.16, C - 0.08, N - 0.012, 0.02, 0.0012, 0.0022, nt)
	# kısa file kollar, siyah ağız biyesi; altı çıplak kol
	var arms := {}
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.8 if sd == "Left" else 2.0
		var s1 := 0.34
		var af := func(s: float, a: float) -> float: return 0.012 + 0.006 * exp(-pow((s - 0.08) / 0.1, 2.0)) + 0.003 * P._lf(s, a, sv) + 0.002 * smoothstep(s1 - 0.08, s1, s)
		P._bare(k, ar, skc, s1 - 0.05, 1.0)
		P._lt(k, ar, af, func(s, a, ins): return sh.darkened(0.42) if ins else P._fs(sh, float(af.call(float(s), float(a))) - 0.014, 12.0), 0.0, s1, 16, 22, 0.025)
		_limb_net(k, ar, af, 0.02, s1 - 0.035, 12, nt)
		P._lt(k, ar, func(s, a): return float(af.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return dk.darkened(0.3) if ins else dk, s1 - 0.03, s1 + 0.001, 4, 22)
		arms[sd] = ar
	# sol bilekte plakalı siyah bileklik
	var la: Dictionary = arms["Left"]
	P._lt(k, la, func(s, _a): return 0.009 + 0.002 * sin(clampf((float(s) - 0.72) / 0.18, 0.0, 1.0) * PI), func(s, _a, ins): return dk.darkened(0.3) if ins else dk.lightened(0.05 * float(absf(float(s) - 0.81) < 0.06)), 0.72, 0.9, 8, 20)
	var wa_a: float = _oa(la, 0.8, Vector3(0.6, 0.6, 0.4))
	var we: Array = Q._ls(la, 0.8, wa_a, 0.016)
	var wd: Vector3 = P._ld(la, 0.8)
	var wo: Vector3 = we[1]
	P._boxr(k, we[0], wo.cross(wd).normalized() * 0.016, -wd * 0.03, wo * 0.0045, gy.darkened(0.15), P._lskin(la, 0.8), 0.3)
	# verev kayış: sol omuzdan sağ kalçaya (önde ve arkada)
	Q._run(k, sk, Callable(), [Vector2(0.42, N - 0.03), Vector2(0.18, C - 0.03), Vector2(-0.55, H + 0.12), Vector2(-1.15, H + 0.06)], 0.012, 0.0035, 0.0032, dk, tsk, 8)
	Q._run(k, sk, Callable(), [Vector2(PI - 0.42, N - 0.03), Vector2(PI - 0.18, C - 0.03), Vector2(PI + 0.55, H + 0.12), Vector2(PI + 1.15, H + 0.06)], 0.012, 0.0035, 0.0032, dk, tsk, 8)
	# kayışta beyaz papyon toka
	var bpos := Vector2(0.165, C - 0.04)
	var bmp: Callable = Q._local(sk, Callable(), bpos.x, bpos.y)
	var bo: Vector3 = Q._spt(sk, Callable(), bpos.x, bpos.y)[1]
	Q._disc(k, bmp, bo, 0.027, 0.0095, func(th): return 0.42 + 0.58 * pow(absf(cos(float(th) - 0.55)), 1.6), func(u, v): return gy.lightened(0.25) if Vector2(float(u), float(v)).length() < 0.32 else Color(0.93, 0.93, 0.92), tsk, 3, 32)
	# göğüs plakası
	var py: float = C - 0.085
	_plate(k, sk, Callable(), 0.0, py, 0.12, 0.042, 0.0075, gy, tsk)
	P._strap(k, sk, [Vector2(-0.036, py + 0.006), Vector2(0.036, py + 0.006)], true, 0.002, 0.0088, 0.0008, gy.darkened(0.3), 4, tsk)
	P._strap(k, sk, [Vector2(-0.026, py - 0.007), Vector2(0.026, py - 0.007)], true, 0.0018, 0.0088, 0.0008, gy.darkened(0.3), 4, tsk)
	# sargı örtü: belden dize, önde açılır; yanlardan öne inen verev kıvrımlar
	var shem: float = KN - 0.01
	var wk := [P._kp(wa, H + 0.075, 0.03), P._kp(hp, H - 0.03, 0.056), [H - 0.15, hp.x + 0.085, hp.y + 0.085, hp.z - 0.085], [shem - 0.05, hp.x + 0.115, hp.y + 0.11, hp.z - 0.11]]
	var ef := func(v: float) -> float: return lerpf(0.03, 0.36, pow(v, 1.3))
	var hemf := func(a: float) -> float: return shem + 0.05 * (1.0 - smoothstep(0.3, 1.3, absf(a))) - 0.012 * sin(a * 3.0 + 0.4)
	var wf := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - shem), 0.0, 1.0)
		var dg: float = sin(a * 5.0 * signf(a) + y * 22.0)
		return t * (0.04 * sin(a * 6.0 + 0.3) + 0.016 * sin(a * 11.0 + 1.0)) + (1.0 - t) * 0.012 * sin(a * 9.0) + 0.018 * t * dg * smoothstep(0.2, 0.9, absf(a))
	var wfw := func(a, y): return wf.call(float(a), float(y))
	var ssk := func(p): return Y._askirt(k, p, shem)
	var wg: Dictionary = P._cl(k, {"keys": wk, "ny": 30, "na": 88, "rng": func(v): return Vector2(ef.call(float(v)), TAU - float(ef.call(float(v)))), "top": func(_a): return H + 0.075,
		"hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return wf.call(float(a), float(y)), "col": func(_a, _y, _v): return gn, "gain": 6.0, "th": 0.007, "inner": gn.darkened(0.4), "skin": ssk})
	for ed in [wg["ea"], wg["eb"]]:
		P._bd(k, ed, 0.005, 0.003, gn.darkened(0.1), false, ssk)
	var wh2 := []
	for p in wg["hem"]:
		wh2.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, wh2, 0.004, 0.002, gn.darkened(0.18), false, ssk)
	# turkuaz kuşak, önde düğüm, sağ önde sarkan iki uç
	var by: float = H + 0.055
	P._sash(k, wk, by, 0.019, 0.014, te, 0.12)
	var kp: Array = Q._spt(wk, wfw, -0.14, by, 0.03)
	P._tb(k, [(kp[0] as Vector3) + Vector3(0.026, 0.012, 0), (kp[0] as Vector3) + Vector3(-0.026, -0.012, 0)], func(s, _a): return 0.016 + 0.01 * sin(float(s) * PI), func(_s, a, _p): return te.darkened(0.14 if sin(float(a) * 3.0) < -0.2 else 0.0), func(_s, _p): return [["Hips", 1.0]], 12)
	for e in [[-0.2, -0.44, KN + 0.06, 0.021], [-0.3, -0.58, KN + 0.13, 0.019]]:
		var ctrl := []
		for i in 9:
			var t := float(i) / 8.0
			ctrl.append(Vector2(lerpf(float(e[0]), float(e[1]), t), lerpf(by - 0.02, float(e[2]), t)))
		Q._run(k, wk, wfw, ctrl, float(e[3]), 0.012, 0.0045, te.darkened(0.04), ssk, 3)
	# kalın atkı: çeneye kadar yığılan rulo + omuzlara dökülen kat
	var q: float = Q._hq(k)
	var ck := [[N + 0.07 * q, nk.x + 0.045, nk.y + 0.045, nk.z - 0.045], [N + 0.0, nk.x + 0.075, nk.y + 0.075, nk.z - 0.07], [N - 0.04, ch.x * 1.04, ch.y * 1.02 + 0.02, ch.z * 1.1], [C - 0.02, ch.x * 1.18, ch.y + 0.03, ch.z * 1.14], [C - 0.1, ch.x * 1.22, ch.y + 0.032, ch.z * 1.18]]
	N2._cowl(k, ck, N + 0.07 * q, func(a): return C - 0.012 - 0.04 * pow(0.5 + 0.5 * cos(float(a)), 2.0) - 0.012 * pow(absf(sin(float(a))), 3.0), ch.x * 1.2, gn, gn.darkened(0.35), 3.2, 0.065)
	for e in [[N + 0.06 * q, 0.03, 0.024], [N + 0.018, 0.058, 0.026]]:
		var rp := []
		var yy: float = e[0]
		for i in 40:
			var a := TAU * i / 40.0 - PI
			var qq: Vector2 = SE.El.sup(a, nk.x + float(e[1]), nk.y + float(e[1]), nk.z - float(e[1]))
			rp.append(Vector3(qq.x, yy - 0.012 * cos(a) + 0.004 * sin(a * 3.0), qq.y))
		P._tb(k, rp, func(s, a): return float(e[2]) * (1.0 + 0.16 * sin(float(s) * TAU * 5.0 + 0.6) + 0.08 * sin(float(a) * 2.0)), func(s, a, _p): return gn.darkened(0.18 * maxf(0.0, -cos(float(a))) + 0.08 * float(sin(float(s) * TAU * 5.0) < -0.6)), func(_s, p): return nsk.call(p), 12, true)
