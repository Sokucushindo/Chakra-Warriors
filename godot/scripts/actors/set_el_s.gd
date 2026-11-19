extends RefCounted
## Elle modellenmiş setler, parti s: ss_esofman2, ss_esofman_yirtik, ss_kutlama, ss_kimono_etek, ss_yemek, ss_bulut_striker. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J) ve q (Q) dosyalarından; burada yırtık kenarlı yüzey, uzuv üstü şerit ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")

const DONE := ["ss_esofman2", "ss_esofman_yirtik", "ss_kutlama", "ss_kimono_etek", "ss_yemek", "ss_bulut_striker"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_esofman2": _esofman2(k)
		"ss_esofman_yirtik": _yirtik(k)
		"ss_kutlama": _kutlama(k)
		"ss_kimono_etek": _kimono_etek(k)
		"ss_yemek": _yemek(k)
		"ss_bulut_striker": _bulut(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Noktanın uzuv boyundaki yeri (0 kök, 1 uç)
static func _sproj(l: Dictionary, p: Vector3) -> float:
	var p0: Vector3 = l["p0"]
	var p1: Vector3 = l["p1"]
	var p2: Vector3 = l["p2"]
	var kn: float = l["kn"]
	var t0: float = clampf((p - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
	var t1: float = clampf((p - p1).dot(p2 - p1) / (p2 - p1).length_squared(), 0.0, 1.0)
	var d0: float = (p0.lerp(p1, t0) - p).length()
	var d1: float = (p1.lerp(p2, t1) - p).length()
	return t0 * kn if d0 < d1 else lerpf(kn, 1.0, t1)


## Uzuv kumaşı üstünde boyuna kabartma şerit: af(s) açı, liftf(s, a) kumaş kalınlığı
static func _lstrip(k, l: Dictionary, s0: float, s1: float, af: Callable, liftf: Callable, hw: float, d: float, col: Color, n := 20) -> void:
	var pts := []
	var ou := []
	for i in n + 1:
		var s: float = lerpf(s0, s1, float(i) / n)
		var a: float = af.call(s)
		var e: Array = Q._ls(l, s, a, float(liftf.call(s, a)) + 0.0015)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, d, col, false, func(p): return P._lskin(l, _sproj(l, p)))


## Ucu açıya göre değişen uzuv tüpü (yırtık kol ağzı): s1f(a) -> uç; iç yüz kısa astarla döner
static func _lte(k, l: Dictionary, addf: Callable, colf: Callable, s0: float, s1f: Callable, n := 24, seg := 22) -> void:
	var rows := []
	var ss := []
	for j in n + 3:
		var v := minf(1.0, float(j) / n)
		var ro := []
		var sr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var e1: float = s1f.call(a)
			var s: float = lerpf(s0, e1, v)
			if j == n + 2:
				s = e1 - 0.035
			var d: Vector3 = P._ld(l, s)
			var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
			var ri := (-d).cross(fw).normalized()
			var r: float = P._lr(l, s) + float(addf.call(s, a)) - (0.0035 if j == n + 1 else (0.006 if j == n + 2 else 0.0))
			ro.append(P._lp(l, s) + ri * sin(a) * r + fw * cos(a) * r)
			sr.append(s)
		rows.append(ro)
		ss.append(sr)
	k.grid(rows, true, func(i, j, _p): return colf.call(ss[j][i], TAU * i / seg - PI, j > n), func(i, j, _p): return P._lskin(l, ss[j][i]))


## Delikli serbest kenarlı kumaş (P._cl ile aynı kurulum): hole(a, y) -> true olan dörtgenler çizilmez (gerçek yırtık açıklık).
## Dış + iç yüz; delik kenarı ayrıca ipliksi biye ile kapatılır.
static func _clh(k, o: Dictionary, hole: Callable) -> Dictionary:
	var keys: Array = o["keys"]
	var top: Callable = o["top"]
	var hem: Callable = o["hem"]
	var ny: int = o.get("ny", 30)
	var na: int = o.get("na", 80)
	var rng: Callable = o["rng"]
	var fold: Callable = o.get("fold", Callable())
	var col: Callable = o["col"]
	var th: float = o.get("th", 0.005)
	var gain: float = o.get("gain", 6.5)
	var ic: Color = o["inner"]
	var cnt: int = na + 1
	var outer := []
	var cols := []
	var angs := []
	var low := 99.0
	for j in ny + 1:
		var v := float(j) / ny
		var r: Vector2 = rng.call(v)
		var ro := []
		var cr := []
		var ar := []
		for i in cnt:
			var a := lerpf(r.x, r.y, float(i) / na)
			var aw := wrapf(a, -PI, PI)
			var y := lerpf(float(top.call(aw)), float(hem.call(aw)), v)
			var s: Array = SE.El.key_at(keys, y)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f: float = float(fold.call(aw, y, v)) if fold.is_valid() else 0.0
			ro.append(Vector3(q.x * (1.0 + f), y, q.y * (1.0 + f)))
			cr.append(P._fs(col.call(aw, y, v), f, gain))
			ar.append(aw)
			low = minf(low, y)
		outer.append(ro)
		cols.append(cr)
		angs.append(ar)
	P._cur_hem = low
	var sf: Callable = o.get("skin", func(p: Vector3) -> Array: return P._hs(k, p))
	var inw = func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
	var inner := []
	for j in ny + 1:
		var ro := []
		for i in cnt:
			var edge: bool = i == 0 or i == cnt - 1
			ro.append(inw.call(outer[j][i], 0.0 if edge else th))
		inner.append(ro)
	var mask = func(i: int, j: int) -> bool:
		var am: float = (float(angs[j][i]) + float(angs[j + 1][mini(i + 1, cnt - 1)])) * 0.5
		var ym: float = ((outer[j][i] as Vector3).y + (outer[j + 1][i] as Vector3).y) * 0.5
		return not bool(hole.call(am, ym))
	for side in 2:
		var src: Array = outer if side == 0 else inner
		var sk: Dictionary = k.sk
		var base: int = (sk["ov"] as PackedVector3Array).size()
		for j in ny + 1:
			for i in cnt:
				var p: Vector3 = src[j][i]
				var i0: int = maxi(0, i - 1)
				var i1: int = mini(cnt - 1, i + 1)
				var j0: int = maxi(0, j - 1)
				var j1: int = mini(ny, j + 1)
				var n0: Vector3 = ((src[j][i1] as Vector3) - (src[j][i0] as Vector3)).cross((src[j1][i] as Vector3) - (src[j0][i] as Vector3))
				var nn: Vector3 = Vector3(p.x, 0.0, p.z).normalized()
				if n0.length_squared() > 1e-12:
					nn = n0.normalized()
					if nn.dot(Vector3(p.x, 0.0, p.z)) < 0.0:
						nn = -nn
				sk["ov"].append(p)
				sk["on"].append(nn if side == 0 else -nn)
				sk["oc"].append(cols[j][i] if side == 0 else ic)
				k.skin(sf.call(p))
		for j in ny:
			for i in cnt - 1:
				if not mask.call(i, j):
					continue
				var q0 := base + j * cnt + i
				var q1 := base + j * cnt + i + 1
				var q2 := base + (j + 1) * cnt + i + 1
				var q3 := base + (j + 1) * cnt + i
				var fn: Vector3 = ((src[j][i + 1] as Vector3) - (src[j][i] as Vector3)).cross((src[j + 1][i] as Vector3) - (src[j][i] as Vector3))
				var want: Vector3 = Vector3((src[j][i] as Vector3).x, 0.0, (src[j][i] as Vector3).z)
				var fwd: bool = (fn.dot(want) < 0.0) == (side == 0)
				if fwd:
					sk["oi"].append_array(PackedInt32Array([q0, q1, q2, q0, q2, q3]))
				else:
					sk["oi"].append_array(PackedInt32Array([q0, q2, q1, q0, q3, q2]))
	# alt uç kıvrımı: dış ile iç arasında kalınlık
	var hm := []
	var hi := []
	for i in cnt:
		hm.append(outer[ny][i])
		hi.append(inner[ny][i])
	k.grid([hm, hi], false, func(i, _j, _p): return (cols[ny][i] as Color).darkened(0.25), func(_i, _j, p): return sf.call(p))
	var ea := []
	var eb := []
	for ro in outer:
		ea.append(ro[0])
		eb.append(ro[cnt - 1])
	return {"rows": outer, "top": outer[0], "hem": outer[ny], "ea": ea, "eb": eb, "low": low}


## Yırtık deliğin kenarı: (a, y) merkezli, düzensiz yarıçaplı ince iplik halka
static func _hole_rim(k, keys: Array, ff: Callable, a0: float, y0: float, ra: float, ry: float, rr: Callable, col: Color, skinf: Callable) -> void:
	var pts := []
	for i in 30:
		var t := TAU * i / 30.0
		var f: float = rr.call(t)
		pts.append(Q._spt(keys, ff, a0 + cos(t) * ra * f, y0 + sin(t) * ry * f, 0.0025)[0])
	P._cord(k, pts, 0.0022, col, true, skinf, 0.0, 5)


static func _jag(t: float, sd: float) -> float:
	return 0.78 + 0.22 * Q._tri(t * 5.0 + sd) + 0.08 * sin(t * 11.0 + sd * 2.0)


## Pembe / kırmızı elmas amblem
static func _diamond(k, keys: Array, ff: Callable, a: float, y: float, r: float, c0: Color, c1: Color) -> void:
	var mp: Callable = Q._local(keys, ff, a, y)
	var o: Vector3 = Q._spt(keys, ff, a, y)[1]
	var rf := func(th: float) -> float: return 1.0 / (absf(cos(th)) + absf(sin(th)))
	var sk := func(p): return k.torso_skin(p.y)
	Q._disc(k, mp, o, r, 0.003, rf, func(_u, _v): return c0, sk, 3, 24)
	Q._disc(k, mp, o, r * 0.62, 0.0048, rf, func(_u, _v): return c1, sk, 2, 24)
	Q._disc(k, mp, o, r * 0.3, 0.0062, rf, func(_u, _v): return c0, sk, 2, 16)


# ------------------------------------------------------------------ Kuro Ressha Ni (ref Shinobi Striker "Boruto Outfit 2"): uyluğa inen beyaz V yakalı tunik, önü açık siyah eşofman ceketi
## (dik yaka içi pembe, kolun dışından inen pembe şerit, pembe ribanalı manşet + iki siyah çizgi, sol göğüste pembe elmas, sırtta girdap),
## diz altına inen bol siyah kapri + pembe ribanalı paça, sağ uylukta sarkan kahve kemer ucu
static func _esofman2(k) -> void:
	var bk := Color(0.1, 0.1, 0.12)
	var pk := Color(0.8, 0.24, 0.47)
	var wh := Color(0.93, 0.93, 0.9)
	var gy := Color(0.7, 0.7, 0.72)
	var br := Color(0.56, 0.37, 0.2)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return gy.lightened(0.12) if j < 6 else wh.darkened(0.05), 0.006)
	K._seat(k, b, bk)
	# kapri: dizin altında toplanan bol paça, ribanalı pembe paça bandı, altında çıplak baldır
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.2
		var sv: float = 1.4 if sd == "Left" else 2.7
		P._bare(k, le, skc, s1 - 0.03, 1.0)
		var pa: Callable = K._pant(k, le, bk, 0.015, 0.024, s1 - 0.02, sv)
		var cf := func(s: float, a: float) -> float: return 0.009 + 0.0012 * cos(a * 22.0) + 0.002 * sin(clampf((s - s1 + 0.06) / 0.075, 0.0, 1.0) * PI)
		P._lt(k, le, cf, func(s, a, ins):
			if ins:
				return pk.darkened(0.35)
			var st: bool = absf(float(s) - (s1 - 0.038)) < 0.005 or absf(float(s) - (s1 - 0.02)) < 0.005
			return bk.lightened(0.04) if st else pk.darkened(0.1 * float(cos(float(a) * 22.0) < 0.0)), s1 - 0.065, s1 + 0.012, 10, 44)
		Q._ring_on(k, le, s1 - 0.038, cf, 0.0045, bk, 0.0018)
		Q._ring_on(k, le, s1 - 0.02, cf, 0.0045, bk, 0.0018)
		if sd == "Right":   # sağ uylukta tunik altından sarkan kahve kemer ucu
			var fa: float = J._outer_a(le, 0.3, Vector3(-0.35, 0.0, 1.0))
			_lstrip(k, le, 0.17, 0.5, func(_s): return fa, func(s, a): return float(pa.call(s, a)) + 0.001, 0.011, 0.0035, br, 14)
			var tip: Array = Q._ls(le, 0.5, fa, float(pa.call(0.5, fa)) + 0.006)
			P._boxr(k, tip[0], (P._ld(le, 0.5) as Vector3).cross(tip[1]).normalized() * 0.012, -(P._ld(le, 0.5) as Vector3) * 0.008, (tip[1] as Vector3) * 0.0025, Color(0.62, 0.62, 0.64), P._lskin(le, 0.5), 0.3)
	# tunik: uyluğa iner, V yaka, aşağıda dikey kıvrımlar
	var th_hem: float = H - 0.22
	var tk := [P._kp(nk, N + 0.015, 0.02), [N - 0.05, ch.x * 0.92, ch.y * 0.88, ch.z * 0.97], P._kp(ch, C - 0.03, 0.018), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.04, 0.03), [th_hem, hp.x + 0.055, hp.y + 0.045, hp.z - 0.05]]
	var vt := func(a: float) -> float: return lerpf(C - 0.02, N + 0.015, smoothstep(0.0, 0.5, absf(a)))
	var tf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - th_hem), 0.0, 1.0)
		return t * (0.022 * sin(a * 8.0 + 0.4) + 0.01 * sin(a * 15.0 + 1.3)) + (1.0 - t) * 0.005 * sin(a * 6.0 + y * 14.0)
	var tsk := func(p): return Q._csk(k, p, th_hem, 0.03)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 38, "na": 76, "top": func(a): return vt.call(float(a)), "hem": func(_a): return th_hem, "fold": tf,
		"col": func(_a, _y, _v): return wh, "gain": 5.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": tsk})
	var ve := []
	for p in tg["top"]:
		if absf(atan2(float(p.x), float(p.z))) < 0.62:
			ve.append(p)
	P._bd(k, ve, 0.011, 0.0035, gy.darkened(0.1), false, func(p): return k.torso_skin(p.y), 0.4)
	var thm := []
	for p in tg["hem"]:
		thm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, thm, 0.003, 0.0014, wh.darkened(0.14), true, tsk)
	# ceket: kalçada biter, önü açık, fermuar kenarları
	var hem: float = H - 0.025
	var jk := [P._kp(nk, N + 0.012, 0.034), [N - 0.055, ch.x * 1.03, ch.y * 0.98, ch.z * 1.07], P._kp(ch, C - 0.03, 0.038), P._kp(wa, H + 0.12, 0.044), [hem, hp.x + 0.048, hp.y + 0.05, hp.z - 0.05]]
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		return smoothstep(0.3, 0.7, aw) * (0.008 * sin(a * 6.0 + y * 15.0) + 0.006 * sin(a * 11.0 - y * 9.0) * smoothstep(C, H, y))
	var jrg := func(v) -> Vector2:
		var e: float = lerpf(0.26, 0.4, float(v))
		return Vector2(e, TAU - e)
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 30, "na": 80, "rng": jrg, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.darkened(0.3), "skin": func(p): return k.torso_skin(maxf(float(p.y), H + 0.005))})
	for ed in [jg["ea"], jg["eb"]]:
		P._bd(k, ed, 0.0042, 0.0025, Color(0.55, 0.55, 0.58), false, func(p): return k.torso_skin(maxf(float(p.y), H + 0.005)), 0.0)
	var jhm := []
	for p in jg["hem"]:
		jhm.append((p as Vector3) + Vector3(0, 0.014, 0))
	P._bd(k, jhm, 0.012, 0.003, bk.lightened(0.03), false, func(p): return k.torso_skin(maxf(float(p.y), H + 0.005)))
	var jff := func(a, y): return jf.call(float(a), float(y))
	_diamond(k, jk, jff, 0.62, C + 0.005, 0.02, pk, bk)
	J._swirl(k, jk, 0.0, C - 0.03, 0.052, pk, false)
	# dik yaka: içi pembe
	var q: float = Q._hq(k)
	var ck := [[N + 0.08 * q, nk.x + 0.03, nk.y + 0.03, nk.z - 0.035], [N + 0.025 * q, nk.x + 0.032, nk.y + 0.03, nk.z - 0.036], [N - 0.025, nk.x + 0.05, nk.y + 0.045, nk.z - 0.045]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 46, "rng": func(_v): return Vector2(0.3, TAU - 0.3), "top": func(a): return N + q * lerpf(0.055, 0.08, smoothstep(0.4, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.022,
		"fold": func(a, _y, v): return 0.008 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return bk.lightened(0.02), "inner": pk, "skin": func(p): return Q._nsk(k, p), "th": 0.006})
	P._cord(k, cg["top"], 0.0042, pk.darkened(0.08), false, func(p): return Q._nsk(k, p))
	# kollar: bileğe, dışta pembe şerit, ribanalı manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		var sg: float = ar["sg"]
		var sf := func(s: float, a: float) -> float:
			return 0.013 + 0.006 * smoothstep(0.1, 0.5, s) + 0.003 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.005 * exp(-pow((s - 0.85) / 0.05, 2.0)) * sin(a * 5.0)
		P._lt(k, ar, sf, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk, float(sf.call(float(s), float(a))) - 0.016, 14.0), 0.0, 0.9, 32, 20, 0.02)
		var cf := func(s: float, a: float) -> float: return 0.008 + 0.0012 * cos(a * 20.0) + 0.0015 * sin(clampf((s - 0.86) / 0.125, 0.0, 1.0) * PI)
		P._lt(k, ar, cf, func(s, a, ins):
			if ins:
				return pk.darkened(0.35)
			return pk.darkened(0.1 * float(cos(float(a) * 20.0) < 0.0)), 0.86, 0.985, 8, 40)
		Q._ring_on(k, ar, 0.915, cf, 0.0045, bk, 0.0018)
		Q._ring_on(k, ar, 0.94, cf, 0.0045, bk, 0.0018)
		var oa: float = J._outer_a(ar, 0.45, Vector3(sg * 0.8, 0.0, -0.6))
		_lstrip(k, ar, 0.06, 0.87, func(_s): return oa, sf, 0.0075, 0.0025, pk, 24)


# ------------------------------------------------------------------ Yabureta Ressha (ref Shinobi Striker "Boruto Outfit: Prologue Ver."): ucu yırtık beyaz tişört, önü açık bol siyah eşofman ceketi:
## eteği dişli yırtık, sağ kolu ön kolda yırtılıp kopmuş (gerçek açık kenar), sırtta ve önde yırtık delikler; üst kollarda ve sol bilekte çift kırmızı bant,
## içi kırmızı dik yaka, sırtta kırmızı girdap; diz altına inen siyah eşofman altı + çift kırmızı bant, altında kahve konçlu bot
static func _yirtik(k) -> void:
	var bk := Color(0.1, 0.095, 0.11)
	var rd := Color(0.77, 0.14, 0.2)
	var wh := Color(0.93, 0.92, 0.89)
	var br := Color(0.42, 0.27, 0.16)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return wh.darkened(0.04), 0.006)
	K._seat(k, b, bk)
	# eşofman altı + kahve bot konçu
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.19
		var sv: float = 2.2 if sd == "Left" else 0.9
		var bt := func(s: float, a: float) -> float: return 0.017 + 0.004 * smoothstep(s1 + 0.06, s1 - 0.02, s) + 0.0025 * sin(a * 3.0 + s * 40.0) * smoothstep(s1 + 0.02, s1 + 0.12, s) * smoothstep(0.98, 0.9, s)
		P._lt(k, le, bt, func(s, a, ins): return br.darkened(0.4) if ins else P._fs(br, 0.0025 * sin(float(a) * 3.0 + float(s) * 40.0), 10.0), s1 - 0.05, 0.99, 22, 20)
		P._lt(k, le, func(s, a): return float(bt.call(s, a)) + 0.005, func(_s, _a, ins): return br.darkened(0.4) if ins else br.lightened(0.06), s1 - 0.055, s1 - 0.02, 3, 20)
		var pa: Callable = K._pant(k, le, bk, 0.02, 0.022, s1, sv)
		for ss in [s1 - 0.045, s1 - 0.018]:
			Q._ring_on(k, le, ss, pa, 0.0065, rd, 0.002)
	# tişört: kalçaya iner, ucu yırtık (dişli gerçek kenar)
	var t_hem: float = H - 0.1
	var tk := [P._kp(nk, N + 0.02, 0.016), [N - 0.05, ch.x * 0.9, ch.y * 0.86, ch.z * 0.96], P._kp(ch, C - 0.03, 0.016), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.04, 0.028), [t_hem - 0.04, hp.x + 0.036, hp.y + 0.034, hp.z - 0.036]]
	var tsk := func(p): return Q._csk(k, p, t_hem - 0.04, 0.03)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 30, "na": 72, "top": func(a): return lerpf(N - 0.015, N + 0.02, smoothstep(0.0, 1.6, absf(float(a)))),
		"hem": func(a): return t_hem + 0.03 * Q._tri(float(a) * 7.0 + 0.3) * (0.6 + 0.4 * sin(float(a) * 3.0)) - 0.015 * cos(float(a)), "fold": func(a, y, _v): return 0.012 * sin(float(a) * 7.0 + 0.4) * smoothstep(H + 0.05, t_hem, float(y)),
		"col": func(_a, _y, _v): return wh, "gain": 5.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": tsk})
	P._cord(k, tg["top"], 0.0045, wh.darkened(0.08), true, func(p): return Q._nsk(k, p))
	# ceket: bol, önü açık, eteği dişli; delikler gerçek açıklık
	var hem: float = H - 0.07
	var jk := [P._kp(nk, N + 0.012, 0.036), [N - 0.055, ch.x * 1.05, ch.y * 1.0, ch.z * 1.08], P._kp(ch, C - 0.03, 0.044), P._kp(wa, H + 0.12, 0.056), [hem - 0.04, hp.x + 0.062, hp.y + 0.06, hp.z - 0.065]]
	var jf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		return smoothstep(0.35, 0.8, aw) * (0.012 * sin(a * 6.0 + y * 13.0) + 0.008 * sin(a * 11.0 - y * 9.0) * smoothstep(C, hem, y))
	var hemf := func(a: float) -> float:
		var tor: float = 1.0 - smoothstep(0.4, 1.6, absf(a + 0.9))   # sağ önde en yırtık
		return hem + 0.012 * sin(a * 2.0) - (0.02 + 0.03 * tor) * maxf(0.0, Q._tri(a * 10.0 + 0.7)) * (0.5 + 0.5 * sin(a * 5.0 + 1.0)) + 0.012 * tor
	var holes := [[PI - 0.5, C - 0.06, 0.24, 0.05, 0.4], [PI + 0.4, H + 0.06, 0.2, 0.04, 1.7], [-1.0, H + 0.04, 0.17, 0.038, 2.9]]
	var holef := func(a: float, y: float) -> bool:
		for hh in holes:
			var da: float = wrapf(a - float(hh[0]), -PI, PI) / float(hh[2])
			var dy: float = (y - float(hh[1])) / float(hh[3])
			var t: float = atan2(dy, da)
			if da * da + dy * dy < pow(_jag(t, float(hh[4])), 2.0):
				return true
		return false
	var jsk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.005)) if float(p.y) > H - 0.02 else k.cloth_skin(p, hem - 0.04, 0.4)
	var jrg := func(v) -> Vector2:
		var e: float = lerpf(0.3, 0.5, float(v))
		return Vector2(e, TAU - e)
	var jg: Dictionary = _clh(k, {"keys": jk, "ny": 34, "na": 96, "rng": jrg, "top": func(_a): return N + 0.012, "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.lightened(0.04), "skin": jsk}, holef)
	var jff := func(a, y): return jf.call(float(a), float(y))
	for hh in holes:
		var sdv: float = hh[4]
		_hole_rim(k, jk, jff, hh[0], hh[1], hh[2], hh[3], func(t): return _jag(float(t), sdv), bk.lightened(0.08), jsk)
	for ed in [jg["ea"], jg["eb"]]:
		P._bd(k, ed, 0.0042, 0.0025, Color(0.5, 0.5, 0.53), false, jsk, 0.0)
	P._cord(k, jg["hem"], 0.0026, bk.lightened(0.07), false, jsk)
	J._swirl(k, jk, 0.0, C + 0.0, 0.05, rd, false)
	# dik yaka: içi kırmızı
	var q: float = Q._hq(k)
	var ck := [[N + 0.075 * q, nk.x + 0.034, nk.y + 0.032, nk.z - 0.038], [N + 0.02 * q, nk.x + 0.036, nk.y + 0.034, nk.z - 0.04], [N - 0.025, nk.x + 0.056, nk.y + 0.05, nk.z - 0.05]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 46, "rng": func(_v): return Vector2(0.36, TAU - 0.36), "top": func(a): return N + q * lerpf(0.05, 0.075, smoothstep(0.4, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.022,
		"fold": func(a, _y, v): return 0.01 * (1.0 - float(v)) * sin(float(a) * 4.0 + 1.0), "col": func(_a, _y, _v): return bk.lightened(0.02), "inner": rd.darkened(0.15), "skin": func(p): return Q._nsk(k, p), "th": 0.006})
	P._cord(k, cg["top"], 0.0042, rd.darkened(0.25), false, func(p): return Q._nsk(k, p))
	# kollar: sağ kol ön kolda dişli yırtık (altı çıplak), sol kol bileğe; üst kolda çift kırmızı bant, sol bilekte çift bant
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.7 if sd == "Left" else 1.9
		var sf := func(s: float, a: float) -> float:
			return 0.016 + 0.008 * smoothstep(0.1, 0.6, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.88) / 0.05, 2.0)) * sin(a * 5.0)
		var colf := func(s, a, ins): return bk.lightened(0.04) if ins else P._fs(bk, float(sf.call(float(s), float(a))) - 0.02, 14.0)
		if sd == "Right":
			P._bare(k, ar, skc, 0.6, 1.0)
			_lte(k, ar, sf, colf, 0.0, func(a): return 0.72 + 0.045 * Q._tri(float(a) * 4.0 + 0.6) + 0.02 * sin(float(a) * 9.0), 34, 24)
		else:
			P._lt(k, ar, sf, colf, 0.0, 0.93, 34, 20, 0.03)
			P._lt(k, ar, func(s, a): return float(sf.call(s, a)) - 0.004, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.03), 0.9, 0.985, 4, 20)
			for ss in [0.8, 0.845]:
				Q._ring_on(k, ar, ss, sf, 0.011, rd, 0.0025)
		for ss in [0.2, 0.25]:
			Q._ring_on(k, ar, ss, sf, 0.011, rd, 0.0025)


## 食 damgası: çift halka + yazı (kabartma şeritler); mp(u, v, kalkış) yüzey eşlemesi
static func _shoku(k, mp: Callable, o: Vector3, r: float, col: Color, skinf: Callable) -> void:
	Q._circle(k, mp, r, r * 0.06, 0.004, col, skinf, 44)
	Q._circle(k, mp, r * 0.84, r * 0.035, 0.004, col, skinf, 40)
	var st := [[-0.62, 0.22, 0.0, 0.7], [0.0, 0.7, 0.62, 0.22], [-0.16, 0.36, 0.16, 0.36], [-0.4, 0.16, 0.4, 0.16], [-0.4, 0.16, -0.4, -0.42], [0.4, 0.16, 0.4, -0.2],
		[-0.4, -0.12, 0.4, -0.12], [-0.4, -0.2, 0.4, -0.2], [-0.4, -0.42, -0.06, -0.3], [-0.06, -0.3, -0.5, -0.66], [0.06, -0.26, 0.52, -0.66], [0.06, -0.26, 0.4, -0.2]]
	for e in st:
		var p0 := Vector2(float(e[0]), float(e[1])) * r
		var p1 := Vector2(float(e[2]), float(e[3])) * r
		var pts := []
		var ou := []
		for i in 4:
			var pp: Vector2 = p0.lerp(p1, float(i) / 3.0)
			pts.append(mp.call(pp.x, pp.y, 0.0045))
			ou.append(o)
		k.strip(pts, ou, r * 0.05, 0.0016, col, false, skinf)


# ------------------------------------------------------------------ Shoku Haori (ref Shinobi Striker "Choji Outfit"): 食 damgalı kırık beyaz tişört, önü geniş açık kutu kesim kısa yeşil haori
## (koyu yeşil yaka bandı, dirsek altına inen geniş kol), gümüş plakalı kırmızı kemer, baldır ortasına inen bol koyu bordo kapri, altı çıplak baldır
static func _yemek(k) -> void:
	var gr := Color(0.15, 0.42, 0.2)
	var ow := Color(0.9, 0.89, 0.86)
	var mr := Color(0.2, 0.08, 0.09)
	var rb := Color(0.62, 0.13, 0.15)
	var em := Color(0.5, 0.12, 0.12)
	var sv := Color(0.76, 0.77, 0.8)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# boyun teni + tişört (yuvarlak yaka)
	var sk_k := [P._kp(nk, N + 0.04, 0.004, 0.006), P._kp(nk, N + 0.0, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9]]
	SE.body_layer(k, sk_k, 8, 32, func(_i, _j, _p): return skc)
	K._seat(k, b, mr)
	var tk := [P._kp(nk, N + 0.025, 0.012), [N - 0.05, ch.x * 0.88, ch.y * 0.86, ch.z * 0.95], P._kp(ch, C - 0.03, 0.014), P._kp(wa, H + 0.12, 0.016), P._kp(hp, H - 0.07, 0.016)]
	var tf := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 7.0 + y * 12.0) * smoothstep(C, H, y)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 28, "na": 64, "top": func(a): return lerpf(N - 0.012, N + 0.022, smoothstep(0.0, 1.8, absf(float(a)))), "hem": func(_a): return H - 0.07, "fold": tf,
		"col": func(_a, _y, _v): return ow, "gain": 6.0, "th": 0.004, "inner": ow.darkened(0.3), "skin": func(p): return k.torso_skin(p.y)})
	P._cord(k, tg["top"], 0.0048, ow.darkened(0.1), true, func(p): return Q._nsk(k, p))
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var cy: float = lerpf(C, H + 0.12, 0.35)
	var mp: Callable = Q._local(tk, tff, 0.0, cy)
	_shoku(k, mp, Q._spt(tk, tff, 0.0, cy)[1], 0.07, em, func(p): return k.torso_skin(p.y))
	# kırmızı kemer + gümüş plaka
	var bk2 := [P._kp(wa, H + 0.07, 0.022), P._kp(hp, H - 0.05, 0.022)]
	var by: float = H + 0.015
	P._sash(k, bk2, by, 0.022, 0.006, rb, 0.12)
	var pe: Array = P._fp(bk2, 0.0, by, true, 0.03)
	P._boxr(k, pe[0], Vector3(0.05, 0, 0), Vector3(0, 0.02, 0), (pe[1] as Vector3) * 0.006, sv, [["Hips", 1.0]], 0.35)
	for sx in [-0.042, 0.042]:
		P._stud(k, (pe[0] as Vector3) + Vector3(sx, 0, 0) + (pe[1] as Vector3) * 0.006, pe[1], 0.0035, sv.lightened(0.1), [["Hips", 1.0]])
	# kapri: bol, baldır ortasında toplanır, kıvrık paça; altı çıplak
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.22
		var sv2: float = 0.6 if sd == "Left" else 1.9
		P._bare(k, le, skc, s1 - 0.03, 1.0)
		var pa: Callable = K._pant(k, le, mr, 0.022, 0.03, s1, sv2)
		Q._ring_on(k, le, s1 - 0.012, func(s, a): return float(pa.call(s, a)) + 0.001, 0.014, mr.lightened(0.04), 0.004)
	# haori: kutu kesim, uyluğa iner, önü geniş açık
	var hem: float = H - 0.18
	var box: float = maxf(wa.x + 0.06, ch.x * 1.0)
	var hk := [P._kp(nk, N + 0.012, 0.036), [N - 0.055, ch.x * 1.05, ch.y * 0.99, ch.z * 1.08], P._kp(ch, C - 0.03, 0.044), [H + 0.12, box, maxf(wa.y + 0.06, ch.y * 0.95), minf(wa.z - 0.06, ch.z * 0.97)],
		[H - 0.04, maxf(box, hp.x + 0.06), hp.y + 0.07, hp.z - 0.07], [hem, maxf(box, hp.x + 0.07), hp.y + 0.075, hp.z - 0.075]]
	var hf := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return smoothstep(0.4, 0.9, aw) * (t * (0.02 * sin(a * 7.0 + 0.5) + 0.009 * sin(a * 13.0 + 1.6)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 14.0))
	var hsk := func(p): return Q._csk(k, p, hem, 0.08)
	var hrg := func(v) -> Vector2:
		var e: float = lerpf(0.34, 0.62, smoothstep(0.0, 0.6, float(v)))
		return Vector2(e, TAU - e)
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 36, "na": 84, "rng": hrg, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return hf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return gr, "gain": 5.0, "th": 0.006, "inner": gr.darkened(0.3), "skin": hsk})
	# yaka bandı: boyundan etek ucuna, kumaşın üstüne kat
	for ed in [hg["ea"], hg["eb"]]:
		P._bd(k, ed, 0.016, 0.004, gr.darkened(0.18), false, hsk, 0.0)
	var neckb := []
	for p in hg["top"]:
		neckb.append((p as Vector3) + Vector3(0, -0.012, 0))
	P._bd(k, neckb, 0.014, 0.004, gr.darkened(0.18), false, func(p): return Q._nsk(k, p), 0.3)
	var hm := []
	for p in hg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.011, 0))
	P._bd(k, hm, 0.003, 0.0016, gr.darkened(0.25), false, hsk)
	for sg in [1.0, -1.0]:
		Q._run(k, hk, func(a, y): return hf.call(float(a), float(y)), [Vector2(sg * (PI * 0.5 + 0.08), C - 0.06), Vector2(sg * (PI * 0.5 + 0.05), H), Vector2(sg * (PI * 0.5 + 0.03), hem + 0.02)], 0.0025, 0.001, 0.0014, gr.darkened(0.22), hsk, 8)
	# kollar: tişört kısa kolu, haori geniş kolu (dirsek altı), altında çıplak ön kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv3: float = 1.6 if sd == "Left" else 0.4
		P._bare(k, ar, skc, 0.3, 1.0)
		P._lt(k, ar, func(s, a): return 0.009 + 0.003 * P._lf(float(s), float(a), sv3), func(_s, _a, ins): return ow.darkened(0.35) if ins else ow, 0.0, 0.34, 10, 18)
		var s1 := 0.72
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.1, 0.55, s)
			var hang: float = maxf(0.0, -sin(a) * sg)
			return 0.022 + 0.04 * fl + 0.022 * fl * hang * hang + (0.003 + 0.006 * fl) * P._lf(s, a, sv3) + 0.006 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins): return gr.darkened(0.12) if ins else P._fs(gr, float(sf.call(float(s), float(a))) - 0.022 - 0.04 * smoothstep(0.1, 0.55, float(s)), 12.0), 0.0, s1, 30, 24, 0.05)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, gr.darkened(0.12), 0.4, s1, 10, 24)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return gr.darkened(0.15) if ins else gr.darkened(0.18), s1 - 0.03, s1 + 0.001, 3, 24)


# ------------------------------------------------------------------ Kumo Striker (ref Shinobi Striker "Cloud Striker"): gri tişört (önde beyaz V parça), boynu saran kırık beyaz atkı, göğüs altından dize inen
## kırmızı sargı etek (üstte bindirilen ön kanat; beyaz biyeli üst kenar, dikey kanat kenarı, verev biyeler), gri-beyaz kuşak, beyaz bilek ve baldır sargıları, diz altında toplanan lacivert pantolon
static func _bulut(k) -> void:
	var gy := Color(0.62, 0.63, 0.65)
	var wh := Color(0.93, 0.93, 0.91)
	var rd := Color(0.6, 0.11, 0.13)
	var nv := Color(0.17, 0.22, 0.4)
	var sh := Color(0.86, 0.86, 0.88)
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
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return gy, 0.008)
	K._seat(k, b, nv)
	# tişört gövdesi: göğüste bol, kollar dirsek üstünde
	var tk := [P._kp(nk, N + 0.012, 0.018), [N - 0.05, ch.x * 0.95, ch.y * 0.9, ch.z * 1.0], P._kp(ch, C - 0.03, 0.024), P._kp(ch, C - 0.1, 0.022)]
	var tf := func(a: float, y: float, _v: float) -> float: return 0.007 * sin(a * 6.0 + y * 17.0) + 0.004 * sin(a * 11.0)
	P._cl(k, {"keys": tk, "ny": 14, "na": 64, "top": func(_a): return N + 0.012, "hem": func(_a): return C - 0.1, "fold": tf, "col": func(_a, _y, _v): return gy, "gain": 7.0, "th": 0.0, "skin": func(p): return k.torso_skin(p.y)})
	# önde beyaz V parça
	var vk := []
	for e in tk:
		vk.append([e[0], float(e[1]) + 0.003, float(e[2]) + 0.003, float(e[3]) - 0.003])
	P._cl(k, {"keys": vk, "ny": 6, "na": 20, "rng": func(_v): return Vector2(-0.5, 0.5), "top": func(_a): return N + 0.0, "hem": func(a): return N - 0.085 + 0.085 * absf(float(a)) / 0.5,
		"col": func(_a, _y, _v): return wh, "th": 0.0, "skin": func(p): return k.torso_skin(p.y)})
	# atkı: boynu iki tur saran kalın yumuşak sargı + önde düşen kat
	var nsk := func(p): return Q._nsk(k, p)
	for e in [[N + 0.005, 0.032, 0.0], [N + 0.04, 0.026, 1.3], [N - 0.03, 0.026, 2.6]]:
		var pts := []
		for i in 32:
			var a := TAU * i / 32.0 - PI
			var y: float = float(e[0]) - 0.02 * pow(maxf(0.0, cos(a)), 2.0) * float(float(e[0]) < N)
			var q2: Vector2 = SE.El.sup(a, nk.x + float(e[1]) * 0.7, nk.y + float(e[1]) * 0.8, nk.z - float(e[1]) * 0.6)
			pts.append(Vector3(q2.x, y, q2.y))
		var ph: float = e[2]
		P._tb(k, pts, func(s, a): return float(e[1]) * (1.0 + 0.12 * sin(float(s) * TAU * 3.0 + ph) + 0.08 * sin(float(a) * 2.0 + float(s) * 20.0)), func(s, a, _p):
			return wh.darkened(0.14) if sin(float(s) * TAU * 3.0 + ph + float(a)) < -0.6 else wh, func(_s, p): return nsk.call(p), 10, true)
	# kollar: kısa gri kol, çıplak ön kol, bilek sargısı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.2 if sd == "Left" else 2.5
		P._bare(k, ar, skc, 0.3, 1.0)
		var sl := func(s: float, a: float) -> float: return 0.016 + 0.008 * smoothstep(0.05, 0.36, s) + 0.004 * P._lf(s, a, sv)
		P._lt(k, ar, sl, func(s, a, ins): return gy.darkened(0.35) if ins else P._fs(gy, float(sl.call(float(s), float(a))) - 0.02, 14.0), 0.0, 0.38, 16, 20, 0.03)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return gy.darkened(0.35) if ins else gy.darkened(0.1), 0.355, 0.381, 3, 20)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.12), 0.79, 0.965, 6, 16)
		P._wraps(k, ar, 0.8, 0.95, 6, 0.006, 0.013, wh, 0.006)
	# pantolon: diz altında toplanır, altında baldır sargısı
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn + 0.13
		var sv: float = 2.1 if sd == "Left" else 0.8
		P._lt(k, le, func(_s, _a): return 0.004, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.14), s1 - 0.04, 0.99, 14, 18)
		P._wraps(k, le, s1 + 0.0, 0.975, 10, 0.006, 0.0145, wh, 0.008)
		var pa: Callable = K._pant(k, le, nv, 0.016, 0.03, s1, sv)
		Q._ring_on(k, le, s1 - 0.022, func(s, a): return float(pa.call(s, a)) + 0.002 + 0.003 * sin(float(a) * 5.0), 0.016, nv.darkened(0.06), 0.006)
	# etek: göğüs altından dize, A kesim, sert kumaş
	var top: float = C - 0.085
	var hem: float = KN + 0.075
	var sk := [[top, ch.x * 0.98 + 0.012, ch.y * 0.93 + 0.012, ch.z * 1.0 - 0.012], P._kp(wa, H + 0.12, 0.03), P._kp(hp, H + 0.02, 0.05), P._kp(hp, H - 0.04, 0.056), [hem, hp.x + 0.095, hp.y + 0.075, hp.z - 0.09]]
	var ff := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.018 * sin(a * 6.0 + 0.8) + 0.008 * sin(a * 11.0 + 0.2))
	var csk := func(p): return Q._csk(k, p, hem, 0.008)
	var sg0: Dictionary = P._cl(k, {"keys": sk, "ny": 40, "na": 84, "top": func(_a): return top, "hem": func(_a): return hem, "fold": ff, "col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.006, "inner": rd.darkened(0.35), "skin": csk})
	# ön kanat: sağ yandan sola, kenarı sol önde dikey
	var fk := []
	for e in sk:
		fk.append([e[0], float(e[1]) + 0.007, float(e[2]) + 0.007, float(e[3]) - 0.007])
	var fg: Dictionary = P._cl(k, {"keys": fk, "ny": 40, "na": 40, "rng": func(_v): return Vector2(-1.35, 0.52), "top": func(_a): return top, "hem": func(_a): return hem, "fold": ff, "col": func(_a, _y, _v): return rd.lightened(0.02), "gain": 5.0, "th": 0.005, "inner": rd.darkened(0.3), "skin": csk})
	P._bd(k, fg["eb"], 0.008, 0.003, wh, false, csk, 0.0)
	for gg in [sg0, fg]:
		var hm := []
		for p in gg["hem"]:
			hm.append((p as Vector3) + Vector3(0, 0.008, 0))
		P._bd(k, hm, 0.0075, 0.003, wh, false, csk)
	var tp := []
	for p in sg0["top"]:
		tp.append((p as Vector3) + Vector3(0, -0.008, 0))
	P._bd(k, tp, 0.0075, 0.003, wh, true, func(p): return k.torso_skin(p.y))
	# verev biyeler (ön kanadın üstünde)
	var fff := func(a, y): return ff.call(float(a), float(y), 0.0)
	Q._run(k, fk, fff, [Vector2(-1.0, H - 0.04), Vector2(-0.4, lerpf(H, hem, 0.45)), Vector2(0.3, lerpf(H, hem, 0.82)), Vector2(0.5, hem + 0.012)], 0.0065, 0.004, 0.003, wh, csk, 10)
	Q._run(k, fk, fff, [Vector2(-0.15, lerpf(H, hem, 0.63)), Vector2(-0.6, lerpf(H, hem, 0.85)), Vector2(-0.95, hem + 0.012)], 0.0065, 0.004, 0.003, wh, csk, 8)
	# kuşak
	var by: float = H + 0.13
	P._sash(k, sk, by, 0.026, 0.012, sh, 0.1)
	var bp := []
	for p in P._ring_pts(sk, by + 0.026, 0.02, 64):
		bp.append(p)
	P._bd(k, bp, 0.0025, 0.0015, sh.darkened(0.2), true, func(p): return k.torso_skin(p.y))


## Uzuv kumaşı üstünde (s, a) yolu boyunca kabartma şerit (çapraz bağ, alev kıvrımı)
static func _lpath(k, l: Dictionary, ctrl: Array, liftf: Callable, hw: float, col: Color, steps := 5) -> void:
	var pts := []
	var ou := []
	var bo: Array = P._lskin(l, (ctrl[0] as Vector2).x)
	for q in P._path(ctrl, steps):
		var e: Array = Q._ls(l, q.x, q.y, float(liftf.call(q.x, q.y)) + 0.0015)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, 0.0022, col, false, func(p): return P._lskin(l, _sproj(l, p)))


## Eldiven: avucu ve el sırtını saran koyu kılıf (elin kendi köşelerinden ölçülür), bilek ağzı
static func _mitt(k, sd: String, ar: Dictionary, col: Color) -> void:
	var m = k.m
	var hd: Vector3 = m._bp(sd + "Hand")
	var el: Vector3 = m._bp(sd + "LowerArm")
	var d: Vector3 = (hd - el).normalized()
	P._lt(k, ar, func(s, _a): return 0.009 + 0.004 * smoothstep(0.93, 0.985, s), func(_s, _a, ins): return col.darkened(0.4) if ins else col, 0.88, 0.99, 6, 18)
	var w := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var t := d.cross(w).normalized()
	var skin_h := [[sd + "Hand", 1.0]]
	var hs := [-0.014, 0.004, 0.02, 0.034, 0.046, 0.052]
	var nb := 16
	var V: PackedVector3Array = k.c["V"]
	var rad := []
	for h in hs:
		var ro := []
		ro.resize(nb)
		ro.fill(0.0)
		rad.append(ro)
	for q: Vector3 in V:
		var rel := q - hd
		var h0 := rel.dot(d)
		if h0 < -0.03 or h0 > 0.075:
			continue
		var x := rel.dot(w)
		var y := rel.dot(t)
		var r0 := sqrt(x * x + y * y)
		if r0 > 0.08:
			continue
		var bi: int = posmod(int(round((atan2(y, x) + PI) / TAU * nb)), nb)
		for j in hs.size():
			if absf(h0 - float(hs[j])) < 0.014:
				rad[j][bi] = maxf(rad[j][bi], r0)
	var rows := []
	for j in hs.size():
		var src: Array = rad[j]
		var ro := []
		for i in nb:
			var a := TAU * i / nb - PI
			var best: float = maxf(float(src[i]), maxf(float(src[(i + 1) % nb]), float(src[(i + nb - 1) % nb])) * 0.96)
			var e_max: float = 1.0 / sqrt(pow(cos(a) / 0.05, 2.0) + pow(sin(a) / 0.03, 2.0))
			var e_min: float = 1.0 / sqrt(pow(cos(a) / 0.036, 2.0) + pow(sin(a) / 0.02, 2.0))
			best = clampf(best, e_min, e_max)
			var rr: float = best + (0.0035 if j < hs.size() - 1 else -0.002)
			ro.append(hd + d * float(hs[j]) + w * cos(a) * rr + t * sin(a) * rr)
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.3) if j >= 4 else col, func(_i, _j, _p): return skin_h)


## Alev dili: kumaşa oturan sivri uçlu kabartma (dış sarı, iç turuncu)
static func _flame(k, keys: Array, ff: Callable, a: float, y: float, r: float, rot: float, c0: Color, c1: Color, skinf: Callable) -> void:
	var mp: Callable = Q._local(keys, ff, a, y)
	var o: Vector3 = Q._spt(keys, ff, a, y)[1]
	var rf := func(th: float) -> float:
		var c: float = cos(th - rot)
		return 0.42 + 0.58 * pow(maxf(0.0, c), 2.5) + 0.12 * sin(th * 3.0 + rot)
	Q._disc(k, mp, o, r, 0.0035, rf, func(_u, _v): return c0, skinf, 3, 24)
	Q._disc(k, mp, o, r * 0.55, 0.0052, rf, func(_u, _v): return c1, skinf, 2, 20)


# ------------------------------------------------------------------ Shukuen Kimono (ref Shinobi Striker "Celebratory Outfits" / Fire Wave): siyah dik yakalı tulum + boğazda kırmızı fiyonk,
## mavi yaka bantlı derin V kırmızı kimono (yalnız sağ kol: geniş, ağzı mavi-beyaz biyeli, alev desenli), sol omuzda üç lamalı gümüş omuzluk,
## iki omuzda beyaz kürk + camgöbeği boncuk ve beyaz püskül, siyah obi + bej ip kemer, sol önde alev desenli kırmızı önlük (iç kenarı beyaz),
## altında bulut girdaplı mavi hakama, yanlarda baldıra inen kırmızı paneller + bej püsküller, sağ kalçada bej halat, siyah eldiven, beyaz çapraz bağlı diz çizmesi
## Shukuen alt eteği ağırlığı (mavi hakama paneli + üstündeki kırmızı etek aynı ağırlıkla: biri ötekini delmez). Önde iki bacak arası geniş geçiş
## (ön panel ortadan bölünmez) ve önde baldıra geçmez (panelin ucu sivri kanat gibi baldırla kalkmaz); arkada Q._csk gibi
static func _hksk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.96 * pow(minf(1.0, (H - p.y) / 0.1), 0.5) * lerpf(1.0, 0.6, smoothstep(0.5, 1.0, t))   # alt uçta kalçaya pay: panel ucu bacakla sivri kanat gibi savrulmaz, dökülür
	var wb: float = lerpf(0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.9)), 0.96, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.06, 0.1, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var sd: String = "Left" if s >= 0.5 else "Right"
	var os: String = "Right" if s >= 0.5 else "Left"
	var ws: float = maxf(s, 1.0 - s)
	var kb: float = smoothstep(k.K + 0.08, k.K - 0.14, p.y) * 0.55 * smoothstep(0.3, 1.0, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


static func _kutlama(k) -> void:
	var bk := Color(0.09, 0.09, 0.11)
	var rd := Color(0.8, 0.14, 0.11)
	var bl := Color(0.16, 0.26, 0.68)
	var wh := Color(0.95, 0.94, 0.92)
	var fur := Color(0.9, 0.9, 0.93)
	var cy := Color(0.22, 0.76, 0.9)
	var gd := Color(1.0, 0.8, 0.22)
	var og := Color(0.98, 0.48, 0.1)
	var bg := Color(0.9, 0.72, 0.56)
	var sv := Color(0.84, 0.85, 0.88)
	var cg := Color(0.72, 0.75, 0.82)
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
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return bk, 0.006)
	K._seat(k, b, bk)
	# boğazda kırmızı fiyonk
	var fb: Array = Q._spt(ik, Callable(), 0.0, N + 0.03, 0.006)
	var nb := [["Neck", 0.5], ["UpperChest", 0.5]]
	for sx in [-1.0, 1.0]:
		var lp := []
		for i in 9:
			var th := TAU * i / 8.0
			lp.append((fb[0] as Vector3) + Vector3(sx * (0.012 + 0.011 * cos(th)), 0.009 * sin(th), 0.004 * (1.0 + cos(th))))
		P._tb(k, lp, func(_s, _a): return 0.004, func(_s, a, _p): return rd.darkened(0.2) if cos(float(a)) < -0.3 else rd, func(_s, _p): return nb, 8, true)
	P._boxr(k, (fb[0] as Vector3) + Vector3(0, 0, 0.004), Vector3(0.006, 0, 0), Vector3(0, 0.007, 0), Vector3(0, 0, 0.004), rd.darkened(0.1), nb, 0.4)
	# bacaklar: siyah pantolon, diz çizmesi, dizin altında beyaz çapraz bağ
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv2: float = 1.5 if sd == "Left" else 0.5
		var pa: Callable = K._pant(k, le, bk.lightened(0.03), 0.009, 0.012, 0.99, sv2)
		var bt := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.005 + 0.004 * smoothstep(kn + 0.08, kn + 0.02, s)
		P._lt(k, le, bt, func(s, a, ins): return bk.darkened(0.3) if ins else bk.darkened(0.15 * float(sin(float(a) * 3.0 + float(s) * 30.0) < -0.6)), kn + 0.02, 0.99, 18, 20)
		P._lt(k, le, func(s, a): return float(bt.call(s, a)) + 0.004, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05), kn + 0.015, kn + 0.045, 3, 20)
		var fa: float = J._outer_a(le, kn + 0.07, Vector3(0.0, 0.0, 1.0))
		var lf := func(s, a): return float(bt.call(float(s), float(a))) + 0.0015
		_lpath(k, le, [Vector2(kn + 0.045, fa - 0.42), Vector2(kn + 0.1, fa + 0.42)], lf, 0.0045, wh, 4)
		_lpath(k, le, [Vector2(kn + 0.045, fa + 0.42), Vector2(kn + 0.1, fa - 0.42)], lf, 0.0045, wh, 4)
	# kimono üstü: derin V, obinin altına girer
	var tk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(wa, H + 0.05, 0.036)]
	var vt := func(a: float) -> float: return lerpf(C - 0.1, N + 0.012, smoothstep(0.02, 0.62, absf(a + 0.03)))
	var tf := func(a: float, y: float, _v: float) -> float: return 0.007 * sin(a * 6.0 + y * 15.0) + 0.006 * sin(a * 3.0 - y * 9.0) * smoothstep(C, H + 0.06, y)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 30, "na": 76, "top": func(a): return vt.call(float(a)), "hem": func(_a): return H + 0.05, "fold": tf, "col": func(_a, _y, _v): return rd, "gain": 6.0, "th": 0.005, "inner": rd.darkened(0.35), "skin": func(p): return k.torso_skin(p.y)})
	# mavi yaka bantları: boyundan V'ye çapraz iner (sağ kanat üstte)
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var ce := []
	for p in tg["top"]:
		ce.append(p)
	var cbo := []
	for p in ce:
		cbo.append((p as Vector3) + Vector3(0, -0.013, 0))
	P._bd(k, cbo, 0.016, 0.0045, bl, true, func(p): return Q._nsk(k, p), 0.35)
	P._bd(k, ce, 0.0035, 0.002, rd.darkened(0.15), true, func(p): return Q._nsk(k, p), 0.35)
	Q._run(k, tk, tff, [Vector2(-0.62, N - 0.03), Vector2(-0.3, C + 0.0), Vector2(0.12, C - 0.11)], 0.016, 0.009, 0.004, bl.lightened(0.04), func(p): return k.torso_skin(p.y), 8)
	# obi + bej ip kemer, camgöbeği boncuk
	var obk := [P._kp(wa, H + 0.14, 0.046), P._kp(wa, H + 0.03, 0.05)]
	var by: float = H + 0.085
	P._sash(k, obk, by, 0.05, 0.008, bk, 0.18)
	var cord := []
	for i in 21:
		var x: float = lerpf(-0.09, 0.09, float(i) / 20.0)
		cord.append(P._fp(obk, x, by, true, 0.022)[0])
	P._cord(k, cord, 0.0028, cy.darkened(0.1), false, func(_p): return [["Hips", 0.5], ["Spine", 0.5]])
	for sx in [-1.0, 1.0]:
		var e: Array = P._fp(obk, sx * 0.105, by, true, 0.02)
		var o: Vector3 = e[1]
		var tx: Vector3 = Vector3.UP.cross(o).normalized()
		P._boxr(k, e[0], tx * 0.04, Vector3(0, 0.016, 0), o * 0.008, bg, [["Hips", 0.5], ["Spine", 0.5]], 0.45)
		P._boxr(k, (e[0] as Vector3) + o * 0.007, tx * 0.022, Vector3(0, 0.01, 0), o * 0.003, bg.darkened(0.3), [["Hips", 0.5], ["Spine", 0.5]], 0.45)
	var cb: Array = P._fp(obk, 0.0, by, true, 0.024)
	P._stud(k, cb[0], cb[1], 0.016, cy, [["Hips", 0.5], ["Spine", 0.5]])
	# alt etek: önde mavi hakama (bulut girdabı), üstünde sol önden dolanan kırmızı etek
	var hemL: float = lerpf(KN, F, 0.5)
	var lk := [P._kp(wa, H + 0.06, 0.05), [H - 0.04, hp.x + 0.062, hp.y + 0.052, hp.z - 0.07], [KN + 0.1, hp.x + 0.092, hp.y + 0.075, hp.z - 0.11], [hemL, hp.x + 0.11, hp.y + 0.088, hp.z - 0.135]]
	var bkk := []
	for e in lk:
		bkk.append([e[0], float(e[1]) - 0.01, float(e[2]) - 0.01, float(e[3]) + 0.01])
	var csk := func(p): return _hksk(k, p, hemL)
	var bf := func(a: float, y: float, _v: float) -> float: return 0.012 * sin(a * 9.0 + 0.3) * clampf((H - y) / (H - hemL), 0.0, 1.0)
	P._cl(k, {"keys": bkk, "ny": 30, "na": 40, "rng": func(_v): return Vector2(-0.95, 0.7), "top": func(_a): return H + 0.06, "hem": func(a): return hemL + 0.03 + 0.05 * smoothstep(-0.25, -0.75, float(a)), "fold": bf, "col": func(_a, _y, _v): return bl, "gain": 6.0, "th": 0.005, "inner": bl.darkened(0.35), "skin": csk})
	var bff := func(a, y): return bf.call(float(a), float(y), 0.0)
	for e in [[-0.42, KN - 0.07, 1.0], [-0.18, lerpf(KN, hemL, 0.62), -1.0]]:
		var ctr := []
		for i in 15:
			var t := float(i) / 14.0
			var th: float = t * TAU * 1.4 * float(e[2])
			var rr: float = lerpf(0.045, 0.006, t)
			ctr.append(Vector2(float(e[0]) + cos(th) * rr / 0.18, float(e[1]) + sin(th) * rr))
		ctr.reverse()
		ctr.insert(0, Vector2(float(e[0]) - 0.35 * float(e[2]), float(e[1]) - 0.02))
		Q._run(k, bkk, bff, ctr, 0.0055, 0.004, 0.0025, cg, csk, 4)
	# kırmızı etek
	var rf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hemL), 0.0, 1.0)
		return smoothstep(0.1, 0.4, absf(a)) * t * (0.024 * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.006 * sin(a * 9.0)
	var hemf := func(a: float) -> float:
		if a > -0.2 and a < 1.3:
			return lerpf(KN + 0.01, KN - 0.07, clampf(a / 1.1, 0.0, 1.0))
		return hemL + 0.02 * sin(a * 3.0)
	var rgf := func(_v) -> Vector2: return Vector2(-0.04, TAU - 0.62)
	var rg: Dictionary = P._cl(k, {"keys": lk, "ny": 40, "na": 92, "rng": rgf, "top": func(_a): return H + 0.06, "hem": func(a): return hemf.call(float(a)), "fold": rf, "col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.006, "inner": rd.darkened(0.3), "skin": csk})
	P._cord(k, rg["hem"], 0.0028, rd.darkened(0.2), false, csk)
	# önlüğün iç kenarı: dışa kıvrılmış beyaz astar (aşağı doğru genişler)
	var wk := []
	for e in lk:
		wk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	P._cl(k, {"keys": wk, "ny": 22, "na": 8, "rng": func(v): return Vector2(-0.03, -0.03 + 0.04 + 0.3 * float(v)), "top": func(_a): return H + 0.0, "hem": func(a): return hemf.call(float(a)) + 0.005, "fold": rf,
		"col": func(_a, _y, _v): return wh, "gain": 5.0, "th": 0.0, "skin": csk})
	var rff := func(a, y): return rf.call(float(a), float(y), 0.0)
	# beyaz dalga çizgileri + alev deseni (sol önlük)
	Q._run(k, lk, rff, [Vector2(0.15, H - 0.02), Vector2(0.45, H - 0.06), Vector2(0.3, H - 0.12), Vector2(0.62, H - 0.16), Vector2(0.95, H - 0.13)], 0.0045, 0.004, 0.0022, wh, csk, 6)
	Q._run(k, lk, rff, [Vector2(0.35, H - 0.21), Vector2(0.7, H - 0.24), Vector2(1.05, H - 0.2)], 0.0045, 0.004, 0.0022, wh, csk, 6)
	for e in [[0.62, H - 0.3, 0.05, 2.2], [0.82, H - 0.36, 0.045, 1.6], [0.5, H - 0.42, 0.042, 2.6], [0.78, KN + 0.05, 0.04, 1.9], [0.98, H - 0.27, 0.035, 1.4], [0.62, KN - 0.01, 0.034, 2.3]]:
		_flame(k, lk, rff, e[0], e[1], e[2], e[3], gd, og, csk)
	Q._run(k, lk, rff, [Vector2(0.45, H - 0.33), Vector2(0.6, H - 0.38), Vector2(0.72, H - 0.33), Vector2(0.66, H - 0.28)], 0.004, 0.006, 0.002, gd, csk, 5)
	# püsküller: yan panellerin ucunda (kumaşa sabit)
	for a in [-1.35, 1.75]:
		var e: Array = Q._spt(lk, rff, a, hemf.call(a) + 0.01, 0.006)
		var p0: Vector3 = e[0]
		var bo: Array = csk.call(p0)
		P._tb(k, [p0 + Vector3(0, 0.012, 0), p0, p0 + Vector3(0, -0.02, 0), p0 + Vector3(0, -0.05, 0)], func(s, _a): return lerpf(0.004, 0.013, smoothstep(0.25, 1.0, float(s))) if float(s) > 0.2 else 0.003,
			func(s, a, _p): return bg.darkened(0.2) if float(s) > 0.3 and sin(float(a) * 7.0) < -0.3 else bg, func(_s, _p): return bo, 12)
	# sağ kalçada bej halat: iki tur
	var rp := []
	for i in 40:
		var t := float(i) / 39.0
		var th: float = t * TAU * 1.85 + 0.6
		rp.append(Q._spt(lk, rff, -1.35 + 0.42 * cos(th), H - 0.13 + 0.1 * sin(th) - 0.06 * t, 0.024 + 0.008 * t)[0])
	Q._rope(k, rp, 0.0105, bg, csk, 18.0, 8)
	# kollar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sg: float = ar["sg"]
		var en: float = ar["kn"]
		var sl := func(s: float, a: float) -> float: return 0.006 + 0.0025 * P._lf(s, a, 1.3) + 0.004 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sl, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.03), float(sl.call(float(s), float(a))) - 0.006, 20.0), 0.0, 0.92, 30, 18)
		_mitt(k, sd, ar, bk)
		if sd == "Left":   # gümüş omuzluk: üç lama, üstteki alttakinin üstüne biner, kenarları bej
			var oa: float = J._outer_a(ar, 0.16, Vector3(sg, 0.35, 0.0))
			for i in 3:
				var s0: float = 0.01 + 0.105 * i
				var add: float = 0.03 + 0.012 * (2 - i) + 0.012 * i * 0.6
				K._shell(k, ar, s0, s0 + 0.14, oa - 1.35, oa + 1.35, func(s, _a): return add + 0.025 * smoothstep(s0, s0 + 0.14, float(s)), 0.007, func(u, v, und):
					if und:
						return sv.darkened(0.4)
					var e2: float = minf(minf(float(u), 1.0 - float(u)), minf(float(v), 1.0 - float(v)) * 2.5)
					return bg.darkened(0.08) if e2 < 0.07 else sv.darkened(0.06 * float(float(v) > 0.6)), 12, 18)
			var ab := [[sd + "UpperArm", 0.7], ["UpperChest", 0.3]]
			var t0: Array = Q._ls(ar, 0.02, oa, 0.06)
			var t1: Array = Q._ls(ar, 0.02, oa + 1.1, 0.05)
			P._tb(k, [(t0[0] as Vector3), ((t0[0] as Vector3) + (t1[0] as Vector3)) * 0.5 + Vector3(0, 0.012, 0), t1[0]], func(_s, _a): return 0.005, func(_s, _a, _p): return bg.darkened(0.15), func(_s, _p): return ab, 8)
		else:   # tek geniş kimono kolu: alt yanı sarkık, ağzı mavi + beyaz biyeli, dışında alev
			var s1 := 0.86
			var kl := func(s: float, a: float) -> float:
				var t: float = smoothstep(0.04, 0.5, s)
				return 0.03 + 0.03 * t + 0.05 * t * pow(maxf(0.0, -sin(a) * sg), 2.0) + 0.006 * P._lf(s, a, 2.7)
			P._lt(k, ar, kl, func(s, a, ins): return rd.darkened(0.25) if ins else P._fs(rd, 0.006 * P._lf(float(s), float(a), 2.7), 14.0), 0.0, s1, 30, 26, 0.05)
			K._lt_in(k, ar, func(s, a): return float(kl.call(float(s), float(a))) - 0.006, rd.darkened(0.25), s1 - 0.3, s1, 10, 26)
			Q._ring_on(k, ar, s1 - 0.034, kl, 0.017, bl, 0.004)
			Q._ring_on(k, ar, s1 - 0.008, func(s, a): return float(kl.call(float(s), float(a))) + 0.003, 0.008, wh, 0.003)
			var oa: float = J._outer_a(ar, 0.6, Vector3(sg, 0.0, 0.4))
			var klf := func(s, a): return float(kl.call(float(s), float(a))) + 0.001
			_lpath(k, ar, [Vector2(0.14, oa - 0.6), Vector2(0.24, oa - 0.1), Vector2(0.32, oa - 0.5), Vector2(0.44, oa + 0.2)], klf, 0.0045, wh, 5)
			_lpath(k, ar, [Vector2(0.18, oa + 0.6), Vector2(0.3, oa + 0.9), Vector2(0.5, oa + 0.7)], klf, 0.0045, wh, 5)
			for e in [[0.62, oa - 0.25, 0.012], [0.7, oa + 0.15, 0.011], [0.66, oa - 0.65, 0.01], [0.74, oa - 0.35, 0.009]]:
				_lpath(k, ar, [Vector2(float(e[0]) + 0.06, float(e[1]) - 0.1), Vector2(float(e[0]), float(e[1])), Vector2(float(e[0]) - 0.04, float(e[1]) + 0.25), Vector2(float(e[0]) - 0.09, float(e[1]) + 0.1)], klf, float(e[2]), gd, 4)
				_lpath(k, ar, [Vector2(float(e[0]) + 0.04, float(e[1]) - 0.05), Vector2(float(e[0]) - 0.02, float(e[1]) + 0.12)], func(s, a): return float(klf.call(s, a)) + 0.0015, float(e[2]) * 0.45, og, 3)
	# kürk: iki omuzda arkadan göğse inen kabarık tutam, ucunda camgöbeği boncuk ve beyaz püskül
	for sg in [1.0, -1.0]:
		var ctrl := [Vector2(sg * 2.5, N - 0.005), Vector2(sg * 1.75, N - 0.03), Vector2(sg * 1.0, N - 0.04), Vector2(sg * 0.6, N - 0.085), Vector2(sg * 0.48, C - 0.04)]
		var pts := []
		for q2 in P._path(ctrl, 6):
			pts.append(Q._spt(tk, tff, q2.x, q2.y, 0.024)[0])
		var fsk := func(p): return k.torso_skin(p.y)
		P._tb(k, pts, func(s, a): return (0.034 - 0.012 * float(s)) * (1.0 + 0.16 * sin(float(s) * 47.0 + float(a) * 3.0) + 0.1 * sin(float(a) * 5.0 + float(s) * 23.0)),
			func(s, a, _p): return fur.darkened(0.16) if sin(float(s) * 47.0 + float(a) * 3.0) < -0.5 else fur, func(_s, p): return fsk.call(p), 12)
		var e3: Array = Q._spt(tk, tff, sg * 0.48, C - 0.06, 0.03)
		var bo2: Array = k.torso_skin(C - 0.06)
		P._stud(k, (e3[0] as Vector3) - (e3[1] as Vector3) * 0.006, e3[1], 0.02, cy, bo2)
		var tp := []
		for i in 5:
			tp.append(Q._spt(tk, tff, sg * 0.48, lerpf(C - 0.08, H + 0.14, float(i) / 4.0), 0.026)[0])
		P._tb(k, tp, func(s, _a): return lerpf(0.007, 0.017, smoothstep(0.0, 0.8, float(s))), func(_s, a, _p): return wh.darkened(0.12) if sin(float(a) * 6.0) < -0.2 else wh, func(_s, p): return k.torso_skin(p.y), 14)


# ------------------------------------------------------------------ Shiro Kimono Hakama (ref Shinobi Striker "Cho-Cho Outfit"): file iç (boyunda V, üst kolda kısa file kol), omuzu kep kollu kolsuz beyaz sarma üst
## (sağ kanat sola biner), turuncu obi + önde katlı fiyonk, altında ince kahve kemer ve sırtta sarı çanta, beyaz mini etek, üst kolda beyaz bant, siyah kolluk,
## açık uyluk, siyah diz üstü çorap
static func _kimono_etek(k) -> void:
	var wh := Color(0.95, 0.95, 0.96)
	var nt := Color(0.15, 0.15, 0.18)
	var bk := Color(0.1, 0.1, 0.12)
	var og := Color(0.92, 0.52, 0.14)
	var yo := Color(0.97, 0.74, 0.3)
	var yl := Color(0.95, 0.8, 0.3)
	var bn := Color(0.42, 0.27, 0.15)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# file iç: ten + iplikler (V yakada görünür)
	var tk := [P._kp(nk, N + 0.05, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], P._kp(ch, C - 0.03, 0.004), P._kp(wa, H + 0.12, 0.004), P._kp(hp, H - 0.06, 0.006)]
	SE.body_layer(k, tk, 20, 40, func(_i, _j, _p): return skc.darkened(0.14))
	Q._net(k, tk, -0.8, 0.8, C - 0.02, N + 0.04, 0.026, 0.0015, 0.0035, nt)
	var nr := []
	for i in 40:
		nr.append(Q._spt(tk, Callable(), TAU * i / 40.0 - PI, N + 0.04, 0.003)[0])
	P._cord(k, nr, 0.0028, nt, true, func(p): return Q._nsk(k, p))
	K._seat(k, b, bk)
	# kollar: kısa file kol + kep omuz altında beyaz bant + siyah kolluk
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		P._bare(k, ar, skc.darkened(0.1), 0.0, 0.34)
		P._net_limb(k, ar, 0.08, 0.27, 0.003, 12, 0.026, 0.0014, nt)
		P._lt(k, ar, func(s, _a): return 0.006 + 0.002 * sin(clampf((float(s) - 0.25) / 0.085, 0.0, 1.0) * PI), func(s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.08 * float(absf(float(s) - 0.29) > 0.035)), 0.25, 0.335, 6, 20)
		var wm := func(s: float, a: float) -> float: return 0.006 + 0.0025 * sin(a * 3.0 + s * 26.0) * smoothstep(0.4, 0.5, s) * smoothstep(0.95, 0.85, s) + 0.002 * smoothstep(0.37, 0.335, s)
		P._lt(k, ar, wm, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.03), 0.0025 * sin(float(a) * 3.0 + float(s) * 26.0), 14.0), 0.33, 0.985, 24, 18)
		P._lt(k, ar, func(s, a): return float(wm.call(s, a)) + 0.002, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.07), 0.33, 0.35, 2, 18)
	# bacaklar: açık uyluk, diz üstü siyah çorap
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var st0: float = kn * 0.55
		P._bare(k, le, skc, 0.0, st0 + 0.02)
		var sk2 := func(s: float, a: float) -> float: return 0.004 + 0.0015 * sin(a * 3.0 + s * 30.0) * exp(-pow((s - kn) / 0.06, 2.0)) + 0.002 * smoothstep(st0 + 0.035, st0, s)
		P._lt(k, le, sk2, func(s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.04 * float(float(s) < st0 + 0.03)), st0, 0.99, 30, 18)
	# beyaz üst: kep omuzlu kolsuz, belde obi altına iner
	var top_hem: float = H - 0.035
	var uk := [P._kp(nk, N + 0.012, 0.028), [N - 0.045, ch.x * 1.1, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.024), P._kp(hp, top_hem, 0.03)]
	var uf := func(a: float, y: float, _v: float) -> float: return 0.006 * sin(a * 6.0 + y * 15.0) * smoothstep(N - 0.02, C, y)
	var vt := func(a: float) -> float: return lerpf(C + 0.02, N + 0.012, smoothstep(0.05, 0.45, absf(a - 0.08)))
	P._cl(k, {"keys": uk, "ny": 30, "na": 76, "top": func(a): return vt.call(float(a)), "hem": func(_a): return top_hem, "fold": uf, "col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": func(p): return k.torso_skin(maxf(float(p.y), H + 0.001))})
	# sağ kanat: sağ boyundan sol bele verev biner (gerçek kat)
	var fk := []
	for e in uk:
		fk.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.006, float(e[3]) - 0.006])
	var y_e0: float = N + 0.012
	var edge := func(y: float) -> float: return lerpf(-0.3, 0.85, smoothstep(0.0, 1.0, clampf((y_e0 - y) / (y_e0 - (H + 0.12)), 0.0, 1.0)))
	var fg: Dictionary = P._cl(k, {"keys": fk, "ny": 26, "na": 34, "rng": func(v): return Vector2(-1.3, edge.call(lerpf(y_e0, top_hem, float(v)))), "top": func(_a): return y_e0, "hem": func(_a): return top_hem, "fold": uf,
		"col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.004, "inner": wh.darkened(0.25), "skin": func(p): return k.torso_skin(maxf(float(p.y), H + 0.001))})
	P._cord(k, fg["eb"], 0.0026, wh.darkened(0.12), false, func(p): return k.torso_skin(maxf(float(p.y), H + 0.001)))
	# kep omuz: kolun üstüne taşan kısa kanat
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sg: float = ar["sg"]
		var cp := func(s: float, a: float) -> float: return 0.02 + 0.012 * smoothstep(0.02, 0.13, s) + 0.006 * maxf(0.0, sin(a) * sg)
		P._lt(k, ar, cp, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, 0.0, 0.14, 8, 22, 0.03)
		P._lt(k, ar, func(s, a): return float(cp.call(s, a)) + 0.002, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.08), 0.12, 0.141, 2, 22)
	# mini etek
	var hem: float = H - 0.2
	var mk := [P._kp(wa, H + 0.02, 0.026), P._kp(hp, H - 0.04, 0.034), [hem, hp.x + 0.052, hp.y + 0.044, hp.z - 0.046]]
	var mf := func(a: float, y: float, _v: float) -> float: return clampf((H - y) / (H - hem), 0.0, 1.0) * (0.012 * sin(a * 8.0 + 0.3) + 0.005 * sin(a * 15.0))
	var msk := func(p: Vector3) -> Array:
		if p.y >= H:
			return k.torso_skin(p.y)
		var t: float = clampf((H - p.y) / (H - hem), 0.0, 1.0)
		var side: float = absf(p.x) / maxf(0.001, absf(p.x) + absf(p.z))
		var w: float = t * 0.55 * (1.0 - 0.45 * smoothstep(0.45, 0.85, side))
		var s: float = smoothstep(-0.09, 0.09, p.x)
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
	var mg: Dictionary = P._cl(k, {"keys": mk, "ny": 18, "na": 76, "top": func(_a): return H + 0.02, "hem": func(_a): return hem, "fold": mf, "col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": msk})
	var hm := []
	for p in mg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, hm, 0.003, 0.0015, wh.darkened(0.12), true, msk)
	# obi + önde katlı fiyonk, kahve kemer, sırtta sarı çanta
	var ok := [P._kp(wa, H + 0.15, 0.036), P._kp(wa, H + 0.03, 0.04)]
	var by: float = H + 0.09
	P._sash(k, ok, by, 0.05, 0.01, yo, 0.12)
	P._sash(k, ok, by, 0.03, 0.016, og, 0.16)
	P._sash(k, ok, H + 0.032, 0.007, 0.012, bn, 0.1)
	var ob := [["Hips", 0.4], ["Spine", 0.6]]
	var fc: Array = P._fp(ok, 0.0, by, true, 0.03)
	var o: Vector3 = fc[1]
	var c0: Vector3 = fc[0]
	for e in [[0.0, 0.0, 0.0, 0.022, 0.03, 0.014], [-0.045, 0.006, 0.45, 0.038, 0.024, 0.009], [0.045, 0.006, -0.45, 0.038, 0.024, 0.009], [-0.02, -0.035, -0.35, 0.014, 0.032, 0.008], [0.022, -0.035, 0.4, 0.014, 0.03, 0.008]]:
		var ang: float = e[2]
		var ux := Vector3(cos(ang), sin(ang), 0.0)
		var uy := Vector3(-sin(ang), cos(ang), 0.0)
		P._boxr(k, c0 + Vector3(float(e[0]), float(e[1]), 0.0) + o * float(e[5]) * 0.4, ux * float(e[3]), uy * float(e[4]), o * float(e[5]), og.darkened(0.05) if absf(float(e[0])) > 0.0 else og.lightened(0.04), ob, 0.4)
	var bkp: Array = P._fp(ok, 0.0, H + 0.04, false, 0.03)
	var bo2 := [["Hips", 0.7], ["Spine", 0.3]]
	P._boxr(k, (bkp[0] as Vector3) + Vector3(0, -0.02, -0.006), Vector3(0.06, 0, 0), Vector3(0, 0.04, 0), Vector3(0, 0, -0.026), yl, bo2, 0.35)
	P._boxr(k, (bkp[0] as Vector3) + Vector3(0, 0.003, -0.03), Vector3(0.062, 0, 0), Vector3(0, 0.02, 0), Vector3(0, 0, -0.006), yl.darkened(0.1), bo2, 0.3)
	P._stud(k, (bkp[0] as Vector3) + Vector3(0, -0.006, -0.037), Vector3(0, 0, -1), 0.006, bn, bo2)
