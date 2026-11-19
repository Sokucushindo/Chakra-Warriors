extends RefCounted
## Elle modellenmiş setler, parti ad: ss_kukla, ss_algi, ss_kabuk_cocuk, ss_kabuk_okul, ss_kabuk_yirtik, ss_demir_dovme. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{kankuro_outfit, karin_outfit, kawaki_outfit, kawaki_outfit_ninja_school_version, kawaki_outfit_prologue_ver, killer_bee_outfit}/.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), r (R), y (Y), t (T), x (X), g (G), z (Z), aa (AA) dosyalarından.
## Burada: Kara paltosu ortak kesimi (Kawaki'nin üç dönemi), yassı sarkan bez ucu, yırtık etek ucu, setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const G = preload("res://scripts/actors/set_el_g.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")

const DONE := ["ss_kukla", "ss_algi", "ss_kabuk_cocuk", "ss_kabuk_okul", "ss_kabuk_yirtik", "ss_demir_dovme"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_kukla": _kukla(k)
		"ss_algi": _algi(k)
		"ss_kabuk_cocuk": _kara_cocuk(k)
		"ss_kabuk_okul": _kara_okul(k)
		"ss_kabuk_yirtik": _kara_yirtik(k)
		"ss_demir_dovme": _demir(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ortak yardımcılar
## Yırtık uç: düzensiz dişler + birkaç derin yırtık yarığı (gerçek kenar açıklığı). 0 = düz, değer yukarı (metre)
static func _tear(a: float, amp: float, sv: float, slits: Array) -> float:
	var t1: float = Y._teeth(a, 23.0, sv * 0.37)
	var t2: float = Y._teeth(a, 37.0, sv * 0.71 + 0.2)
	var v: float = amp * (0.55 * pow(t1, 3.0) + 0.3 * pow(t2, 4.0) + 0.15 * (0.5 + 0.5 * sin(a * 9.0 + sv)))
	for e in slits:   # [açı, derinlik, yarı genişlik]
		var d: float = absf(wrapf(a - float(e[0]), -PI, PI))
		v = maxf(v, float(e[1]) * maxf(0.0, 1.0 - d / float(e[2])))
	return v


## Yassı sarkan bez (atkı ucu): pts boyunca ince elips kesitli şerit; uçta düzensiz yırtık (sütunlar farklı boyda biter). hwf(s) yarı genişlik
static func _flat_tail(k, pts: Array, hwf: Callable, th: float, jag: float, col: Color, skinf: Callable, sv: float, seg := 16) -> void:
	var n: int = pts.size()
	var cum := [0.0]
	for i in n - 1:
		cum.append(float(cum[i]) + ((pts[i + 1] as Vector3) - (pts[i] as Vector3)).length())
	var L: float = cum[n - 1]
	var at := func(s: float) -> Array:
		var d: float = clampf(s, 0.0, 1.0) * L
		var i := 0
		while i < n - 2 and d > float(cum[i + 1]):
			i += 1
		var u: float = clampf((d - float(cum[i])) / maxf(0.0001, float(cum[i + 1]) - float(cum[i])), 0.0, 1.0)
		return [(pts[i] as Vector3).lerp(pts[i + 1], u), ((pts[i + 1] as Vector3) - (pts[i] as Vector3)).normalized()]
	var rows := []
	var nr := 36
	for j in nr + 1:
		var s0 := float(j) / nr
		var ro := []
		for i in seg:
			var a := TAU * i / seg - PI
			var xs: float = sin(a)
			var cut: float = jag * (0.5 + 0.5 * sin(xs * 7.0 + sv)) * (0.6 + 0.4 * absf(sin(xs * 13.0 + sv * 2.0)))
			var s: float = minf(s0, 1.0 - cut)
			var e: Array = at.call(s)
			var tg: Vector3 = e[1]
			var sx := (Vector3.RIGHT - tg * tg.dot(Vector3.RIGHT)).normalized()
			var nz := tg.cross(sx).normalized()
			var hw: float = hwf.call(s)
			ro.append((e[0] as Vector3) + sx * xs * hw + nz * cos(a) * th)
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.08 * float(j % 7 == 3)), func(_i, _j, p): return skinf.call(p))


## Kara arması (sırtta): gri halka + üstte iki göz
static func _kara_mark(k, keys: Array, yc: float, r: float, col: Color) -> void:
	var tskn := func(p): return k.torso_skin(p.y)
	Q._circle(k, AA._back_mp(keys, 0.0, yc), r, r * 0.125, 0.004, col, tskn, 48)
	for sx in [-1.0, 1.0]:
		Q._disc(k, AA._back_mp(keys, sx * r * 0.28, yc + r * 0.6), Vector3(0, 0, -1), r * 0.155, 0.004, Callable(), func(_u, _v): return col, tskn, 3, 16)


## Kara paltosu (Kawaki'nin üç dönemi ortak kesim): kolsuz, önü açık, sırtta dikiş; omuzdan A kesim genişler.
## o: col, lin, hem (ön uç), hb (arka uç), wide (Vector3 etek ucu genişlemesi x, ön z, arka z), e(y) ön kenar açısı, jag / slits / sv (yırtık uç), colf(a, y)
## Döner: {keys, ff, cg, sk (ağırlık), low}
static func _kara_coat(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var col: Color = o["col"]
	var hem: float = o["hem"]
	var hb: float = o.get("hb", hem)
	var wd: Vector3 = o["wide"]
	var jag: float = o.get("jag", 0.0)
	var sv: float = o.get("sv", 0.0)
	var slits: Array = o.get("slits", [])
	var low: float = minf(hem, hb) - jag * 0.0 - 0.005
	var mid: float = lerpf(H - 0.04, low, 0.5)
	var keys := [P._kp(nk, N + 0.012, 0.036), [N - 0.05, ch.x * 1.06, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.04), P._kp(wa, H + 0.12, 0.05), P._kp(k.M(H + 0.06, 0.3), H + 0.06, 0.056), P._kp(hp, H - 0.04, 0.062),
		[mid, hp.x + 0.062 + wd.x * 0.55, hp.y + 0.062 + wd.y * 0.55, hp.z - 0.062 - wd.z * 0.55], [low, hp.x + 0.062 + wd.x, hp.y + 0.062 + wd.y, hp.z - 0.062 - wd.z]]
	var sk := func(p): return AA._fam(k, p, low)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.04 - y) / (H + 0.04 - low), 0.0, 1.0)
		return smoothstep(0.35, 0.75, aw) * pow(t, 1.1) * (0.034 * sin(a * 6.0 + 0.9 + sv) + 0.015 * sin(a * 11.0 + 2.3)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 11.0) * smoothstep(N - 0.03, C - 0.04, y)
	var e_at: Callable = o["e"]
	var hemf := func(a: float) -> float:
		var y0: float = lerpf(hem, hb, smoothstep(0.6, 2.6, absf(a)))
		return y0 + (_tear(a, jag, sv, slits) if jag > 0.0 else 0.0)
	var colf: Callable = o.get("colf", func(_a, _y): return col)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": o.get("ny", 54), "na": o.get("na", 104), "rng": func(v):
		var e: float = e_at.call(lerpf(N + 0.012, low, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return N + 0.012, "hem": func(a): return hemf.call(float(a)),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(a, y, _v): return colf.call(float(a), float(y)), "gain": 6.0, "th": 0.008, "inner": o["lin"], "skin": sk})
	return {"keys": keys, "ff": func(a, y): return ff.call(float(a), float(y)), "cg": cg, "sk": sk, "low": low}


## Dik yaka (önü açık): h yükseklik, fl dışa açılma, inner iç renk
static func _stand(k, b: Dictionary, col: Color, inner: Color, h: float, fl: float, open_a: float) -> Dictionary:
	var N: float = k.N
	var nk: Vector3 = b["nk"]
	var q: float = Q._hq(k)
	var clk := [[N + h * q, nk.x + 0.03 + fl, nk.y + 0.034 + fl, nk.z - 0.04 - fl], [N + h * q * 0.4, nk.x + 0.034, nk.y + 0.036, nk.z - 0.04], [N - 0.005, nk.x + 0.042, nk.y + 0.04, nk.z - 0.045], [N - 0.045, nk.x + 0.06, nk.y + 0.05, nk.z - 0.06]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var cl: Dictionary = P._cl(k, {"keys": clk, "ny": 12, "na": 56, "rng": func(_v): return Vector2(open_a, TAU - open_a), "top": func(a): return N + q * h * lerpf(0.8, 1.0, smoothstep(0.5, 1.6, absf(float(a)))), "hem": func(_a): return N - 0.04,
		"fold": func(a, y, _v): return 0.004 * sin(float(a) * 6.0 + float(y) * 20.0), "col": func(_a, _y, _v): return col, "inner": inner, "skin": skt, "th": 0.007, "gain": 5.0})
	P._cord(k, cl["top"], 0.0045, col.lightened(0.04), false, skt)
	return cl


## Devrik yaka (revers): ön kenardan dışa doğru üçgen kat; sg +1 sol kanat. w0 tepe genişliği (açı), y0..y1 boy
static func _revers(k, keys: Array, ff: Callable, e_at: Callable, sg: float, y0: float, y1: float, w0: float, colf: Callable) -> Array:
	var rows := []
	var nj := 16
	var nu := 8
	var outer := []
	for j in nj + 1:
		var v := float(j) / nj
		var y: float = lerpf(y0, y1, v)
		var e: float = e_at.call(y) - 0.012
		var w: float = w0 * pow(1.0 - v, 0.85) + 0.004
		var ro := []
		for i in nu + 1:
			var u := float(i) / nu
			var l: float = 0.002 + 0.004 * smoothstep(0.0, 0.25, minf(u, 1.0 - u) * 2.0)
			ro.append(Q._spt(keys, ff, sg * (e + u * w), y, l)[0])
		rows.append(ro)
		outer.append(Vector2(sg * (e + w), y))
	var o: Vector3 = Q._spt(keys, ff, sg * (e_at.call(lerpf(y0, y1, 0.3)) + w0 * 0.3), lerpf(y0, y1, 0.3))[1]
	Q._mesh(k, rows, false, func(i, j, p): return colf.call(float(i) / nu, float(j) / nj, p), func(_i, _j, p): return k.torso_skin(p.y), o)
	return outer


# ------------------------------------------------------------------ Kara Sodenashi (ref Kawaki Outfit): yeşil atlet, dize inen kolsuz iki tonlu mavi palto (dik yaka, açık mavi devrik yaka, içinde koyu bant,
## tepede perçinler, açık mavi biye), sırtta gri Kara arması, verev takılan kahve kemer, siyah kapri, sol bilekte siyah kolluk + metal plaka
static func _kara_cocuk(k) -> void:
	var gn := Color(0.227, 0.541, 0.29)
	var bl := Color(0.165, 0.29, 0.62)
	var lb := Color(0.56, 0.68, 0.86)
	var bk := Color(0.11, 0.11, 0.125)
	var br := Color(0.48, 0.25, 0.13)
	var gy := Color(0.62, 0.64, 0.68)
	var mt := Color(0.74, 0.75, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	# atlet: yuvarlak yaka, uzun (kemerin altına iner)
	var ik := [P._kp(nk, N + 0.03, 0.002), P._kp(nk, N + 0.0, 0.008), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.008), P._kp(wa, H + 0.12, 0.01), P._kp(hp, H - 0.09, 0.012)]
	var scoop := func(p: Vector3) -> bool:
		var aw: float = absf(atan2(p.x, p.z))
		return p.y > lerpf(N - 0.045, N + 0.0, smoothstep(0.0, 1.4, aw))
	SE.body_layer(k, ik, 30, 48, func(_i, _j, p): return skc if scoop.call(p) else gn.darkened(0.06 * float(sin(atan2(p.x, p.z) * 7.0 + p.y * 30.0) < -0.5)),
		func(a, y): return 0.008 * sin(a * 7.0 + y * 30.0) * smoothstep(C - 0.05, H + 0.05, y))
	var nr := []
	for i in 48:
		var a := TAU * i / 48.0 - PI
		var y: float = lerpf(N - 0.045, N + 0.0, smoothstep(0.0, 1.4, absf(a))) - 0.003
		nr.append(P._on(ik, a, y, 0.025))
	P._cord(k, nr, 0.003, gn.darkened(0.1), true, func(p): return Q._nsk(k, p))
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = AA._bare_arm(k, sd)
		var sv: float = 0.9 if sd == "Left" else 2.4
		var kn: float = le["kn"]
		R._arm_skin(k, ar, 0.0)
		# kapri: baldır ortasında biter, ağzı katlı
		var s1: float = kn + 0.2
		var pa: Callable = K._pant(k, le, bk, 0.012, 0.022, s1, sv)
		P._lt(k, le, func(s, a): return float(pa.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.04), s1 - 0.03, s1, 3, 20)
		P._bare(k, le, skc, s1 - 0.02, 1.0)
		if sd == "Left":   # siyah kolluk + metal plaka
			var cf := func(s: float, a: float) -> float: return 0.012 + 0.003 * sin(a * 5.0 + s * 60.0) * smoothstep(0.78, 0.8, s) * smoothstep(0.93, 0.91, s)
			P._lt(k, ar, cf, func(_s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.04 * float(sin(float(a) * 5.0) > 0.4)), 0.76, 0.93, 10, 20)
			var ao: float = J._outer_a(ar, 0.85, Vector3(1.0, 0.0, 0.0))
			var e: Array = Q._ls(ar, 0.85, ao, 0.016)
			var dd: Vector3 = P._ld(ar, 0.85)
			var ux: Vector3 = (e[1] as Vector3).cross(dd).normalized()
			P._boxr(k, e[0], ux * 0.014, dd * 0.026, (e[1] as Vector3) * 0.004, mt, P._lskin(ar, 0.85), 0.3)
			P._stud(k, (e[0] as Vector3) + (e[1] as Vector3) * 0.006, e[1], 0.0045, bk, P._lskin(ar, 0.85))
	# verev kemer: sağ belde yüksek, sol kalçaya iner; önde ucu sarkar
	var sk2 := [P._kp(k.M(H + 0.05, 0.3), H + 0.09, 0.016), P._kp(hp, H - 0.05, 0.022), [H - 0.12, hp.x * 0.98, hp.y * 0.96, hp.z * 0.96]]
	var byf := func(a: float) -> float: return H + 0.0 - 0.06 * sin(a)
	var bp: Array = G._ring_t(sk2, byf, 0.004, 72)
	var bsk := func(p): return k.cloth_skin(p, H - 0.25, 0.4)
	P._bd(k, bp, 0.015, 0.003, br, true, bsk)
	var tp := []
	for i in 9:
		var t := float(i) / 8.0
		var a: float = lerpf(0.1, 0.32, t)
		var y: float = float(byf.call(0.1)) - 0.01 - t * 0.13
		tp.append(P._on(sk2, a, y, 0.06 + 0.01 * t))
	P._bd(k, tp, 0.0135, 0.003, br.darkened(0.06), false, bsk)
	# palto
	var e_at := func(y: float) -> float: return lerpf(0.27, 0.33, smoothstep(C, KN, y)) - 0.1 * smoothstep(N - 0.06, N + 0.012, y)
	var hem: float = KN + 0.03
	var pc: Dictionary = _kara_coat(k, b, {"col": bl, "lin": bl.darkened(0.25), "hem": hem, "hb": hem - 0.02, "wide": Vector3(0.025, 0.02, 0.03), "e": e_at, "sv": 0.6})
	var keys: Array = pc["keys"]
	var ff: Callable = pc["ff"]
	var csk: Callable = pc["sk"]
	var cg: Dictionary = pc["cg"]
	AA._edge_band(k, cg["ea"], 0.008, 0.0028, lb, csk, 1.0)
	AA._edge_band(k, cg["eb"], 0.008, 0.0028, lb, csk, -1.0)
	P._bd(k, AA._yl(cg["hem"], 0.011), 0.008, 0.0024, lb, false, csk)
	for sd in ["Left", "Right"]:
		P._armhole(k, P._limb(k, sd, false), 0.07, 0.016, 0.008, lb)
	# devrik yaka: açık mavi, üstte koyu bant, iç kenarda ince koyu çizgi, tepe köşelerde perçin
	var yb: float = H + 0.17
	for sg in [1.0, -1.0]:
		var ol: Array = _revers(k, keys, ff, e_at, sg, N - 0.03, yb, 0.62, func(u, v, _p):
			if v > 0.16 and v < 0.25:
				return bl.lightened(0.05)
			return lb.darkened(0.25) if u < 0.13 and v > 0.25 else lb)
		Q._run(k, keys, ff, ol, 0.0026, 0.0052, 0.0016, lb.lightened(0.08), func(p): return k.torso_skin(p.y), 1)
		for q in [Vector2(sg * (float(e_at.call(N - 0.03)) + 0.07), N - 0.03), Vector2(sg * (float(e_at.call(N - 0.03)) + 0.4), N - 0.035)]:
			var e2: Array = Q._spt(keys, ff, q.x, q.y, 0.006)
			P._stud(k, e2[0], e2[1], 0.004, gy.lightened(0.15), k.torso_skin(q.y))
	# yan dikişler + sırtta Kara arması
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.6, C - 0.08), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.02)], 0.0024, 0.0016, 0.0012, bl.darkened(0.25), csk, 10)
	_kara_mark(k, keys, C - 0.04, 0.05, gy)
	_stand(k, b, bl, lb, 0.085, 0.012, 0.42)


# ------------------------------------------------------------------ Kara Gakusei (ref Kawaki Outfit Ninja School Version): beyaz V yakalı üst (gri V biye), dizin altına inen A kesim kolsuz mavi palto
## (omuzda yırtık kol kökü, çok yüksek dik yaka, göğüste kapaklı iki cep, yanlarda verev cep ağzı, koyu etek ucu, sırtta gri Kara arması),
## siyah kemer + gümüş toka, lacivert bol pantolon, baldıra çıkan siyah ayakkabı konçu
static func _kara_okul(k) -> void:
	var wh := Color(0.949, 0.941, 0.918)
	var bl := Color(0.165, 0.314, 0.533)
	var nv := Color(0.118, 0.165, 0.282)
	var bk := Color(0.1, 0.1, 0.115)
	var gy := Color(0.62, 0.64, 0.68)
	var mt := Color(0.78, 0.79, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	# beyaz V yaka üst
	var ik := [P._kp(nk, N + 0.03, 0.002), P._kp(nk, N + 0.0, 0.008), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.008), P._kp(wa, H + 0.12, 0.01), P._kp(k.M(H + 0.07, 0.3), H + 0.07, 0.01)]
	var yv: float = C - 0.03
	var vtop := func(a: float) -> float: return lerpf(yv, N + 0.0, pow(clampf(absf(a) / 0.55, 0.0, 1.0), 0.8))
	SE.body_layer(k, ik, 30, 48, func(_i, _j, p): return skc if p.y > float(vtop.call(atan2(p.x, p.z))) else wh.darkened(0.04 * float(p.y < C - 0.12)),
		func(a, y): return 0.006 * sin(a * 6.0 + y * 24.0) * smoothstep(C - 0.03, H + 0.05, y))
	for sg in [1.0, -1.0]:
		var vp := []
		for i in 12:
			var t := float(i) / 11.0
			var a: float = sg * 0.55 * pow(t, 1.0 / 0.8)
			var y: float = lerpf(yv, N + 0.0, t) - 0.006
			vp.append(P._on(ik, a, y, 0.03))
		P._bd(k, vp, 0.007, 0.0025, gy, false, func(p): return k.torso_skin(p.y))
	# pantolon: bol, baldırda ayakkabı konçunun içine girer
	K._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = AA._bare_arm(k, sd)
		var sv: float = 1.2 if sd == "Left" else 2.9
		R._arm_skin(k, ar, 0.0)
		var tk: float = 0.76
		var ad: Callable = Q._baggy(k, le, nv, bk, 0.014, 0.034, tk, sv)
		# konç: kalın siyah, üstte dönük ağız
		P._lt(k, le, func(s, a): return 0.009 + 0.004 * smoothstep(tk - 0.01, tk - 0.04, float(s)) + 0.0015 * sin(float(a) * 4.0 + float(s) * 30.0 + sv), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, tk - 0.045, 0.99, 14, 20)
		P._lt(k, le, func(_s, _a): return 0.0145, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.06), tk - 0.05, tk - 0.03, 2, 20)
	var by: float = H + 0.07
	var blk := [P._kp(k.M(H + 0.05, 0.3), H + 0.11, 0.015), P._kp(k.M(H + 0.05, 0.3), H + 0.03, 0.017)]
	P._sash(k, blk, by, 0.016, 0.0, bk, 0.08)
	var bf: Array = P._sa(blk, 0.0, by, 0.012)
	P._boxr(k, bf[0], Vector3(0.022, 0, 0), Vector3(0, 0.011, 0), (bf[1] as Vector3) * 0.004, mt, [["Hips", 0.5], ["Spine", 0.5]], 0.25)
	# palto: A kesim, dizin altına iner
	var e_at := func(y: float) -> float: return lerpf(0.4, 0.5, smoothstep(C, KN, y)) - 0.12 * smoothstep(N - 0.06, N + 0.012, y)
	var hem: float = KN - 0.1
	var pc: Dictionary = _kara_coat(k, b, {"col": bl, "lin": nv, "hem": hem, "hb": hem - 0.02, "wide": Vector3(0.11, 0.07, 0.12), "e": e_at, "sv": 1.7,
		"colf": func(_a, y): return nv if y < hem + 0.035 else bl})
	var keys: Array = pc["keys"]
	var ff: Callable = pc["ff"]
	var csk: Callable = pc["sk"]
	var cg: Dictionary = pc["cg"]
	AA._edge_band(k, cg["ea"], 0.006, 0.0022, bl.lightened(0.04), csk, 1.0)
	AA._edge_band(k, cg["eb"], 0.006, 0.0022, bl.lightened(0.04), csk, -1.0)
	P._bd(k, AA._yl(cg["hem"], 0.035), 0.0035, 0.0018, nv.darkened(0.1), false, csk)
	# göğüs cepleri (kapaklı) + yan verev cep ağızları + yan dikiş
	for sg in [1.0, -1.0]:
		AA._flap(k, keys, ff, sg * 0.72, C + 0.035, 0.085, 0.024, -sg * 0.05, bl.lightened(0.03), func(p): return k.torso_skin(p.y), 0.004)
		Q._run(k, keys, ff, [Vector2(sg * 0.78, C + 0.035 - 0.026), Vector2(sg * 0.8, C - 0.03)], 0.0018, 0.002, 0.0012, bl.darkened(0.22), func(p): return k.torso_skin(p.y), 3)
		Q._run(k, keys, ff, [Vector2(sg * 0.95, H + 0.1), Vector2(sg * 1.15, H - 0.06)], 0.0026, 0.002, 0.0014, nv, csk, 6)
		Q._run(k, keys, ff, [Vector2(sg * 1.6, C - 0.08), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.04)], 0.0024, 0.0016, 0.0012, bl.darkened(0.25), csk, 10)
	Q._run(k, keys, ff, [Vector2(PI - 0.001, N - 0.02), Vector2(PI - 0.001, hem + 0.04)], 0.0024, 0.0016, 0.0012, bl.darkened(0.22), csk, 14)
	_kara_mark(k, keys, C - 0.04, 0.05, gy)
	# yırtık kol kökü: omuzdan dışa taşan, ucu yırtık kısa kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv2: float = 0.4 if sd == "Left" else 1.9
		var s1f := func(a: float) -> float: return 0.15 - _tear(a, 0.07, sv2, [[0.4 + sv2, 0.09, 0.2], [2.2 + sv2, 0.08, 0.18]])
		P._lts(k, ar, func(s, a): return 0.016 + 0.03 * smoothstep(0.02, 0.14, float(s)) + 0.003 * sin(float(a) * 5.0 + sv2), func(_s, a, ins): return nv if ins else bl.darkened(0.06 * float(sin(float(a) * 5.0 + sv2) < -0.3)), func(a): return s1f.call(float(a)), 0.0, 10, 30)
	# çok yüksek dik yaka
	_stand(k, b, bl, nv, 0.13, 0.03, 0.5)


# ------------------------------------------------------------------ Kara Ruro (ref Kawaki Outfit: Prologue Ver.): açık gri kolsuz tulum (derin V yaka, siyah kemer + gümüş toka, bağcıklı bel, bol paça),
## yıpranmış kolsuz mor palto (yırtık etek ucu ve kol oyuğu, derin yırtık yarıkları), boynu saran kalın mor atkı (göğse düşen kat), sol ön kolda kırmızı-siyah kolluk
static func _kara_yirtik(k) -> void:
	var gy := Color(0.769, 0.769, 0.784)
	var gp := Color(0.722, 0.722, 0.737)
	var vi := Color(0.227, 0.204, 0.314)
	var pu := Color(0.29, 0.227, 0.353)
	var bk := Color(0.09, 0.09, 0.1)
	var rd := Color(0.6, 0.1, 0.13)
	var mt := Color(0.78, 0.79, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	# tulum üstü: derin V yaka
	var ik := [P._kp(nk, N + 0.03, 0.002), P._kp(nk, N + 0.0, 0.008), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.9], P._kp(ch, C - 0.03, 0.01), P._kp(wa, H + 0.12, 0.014), P._kp(hp, H - 0.09, 0.016)]
	var yv: float = H + 0.15
	var vtop := func(a: float) -> float: return lerpf(yv, N + 0.0, pow(clampf(absf(a) / 0.5, 0.0, 1.0), 0.7))
	SE.body_layer(k, ik, 32, 48, func(_i, _j, p): return skc if p.y > float(vtop.call(atan2(p.x, p.z))) else gy.darkened(0.08 * float(sin(atan2(p.x, p.z) * 6.0 + p.y * 26.0) < -0.5)),
		func(a, y): return 0.008 * sin(a * 6.0 + y * 26.0) * smoothstep(C, H + 0.05, y))
	for sg in [1.0, -1.0]:
		var vp := []
		for i in 14:
			var t := float(i) / 13.0
			vp.append(P._on(ik, sg * 0.5 * pow(t, 1.0 / 0.7), lerpf(yv, N + 0.0, t) - 0.004, 0.03))
		P._bd(k, vp, 0.006, 0.003, gy.darkened(0.08), false, func(p): return k.torso_skin(p.y))
	# bol paça
	var sk := R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return gp)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = AA._bare_arm(k, sd)
		var sv: float = 2.2 if sd == "Left" else 0.7
		var sg: float = le["sg"]
		var kn: float = le["kn"]
		R._arm_skin(k, ar, 0.0)
		var pa := func(s: float, a: float) -> float:
			var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
			var wd: float = 0.02 + 0.042 * smoothstep(0.05, 0.6, s)
			var fo: float = (0.004 + 0.013 * smoothstep(0.1, 0.6, s)) * P._lf(s, a, sv) + 0.008 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
			return wd * (1.0 - 0.38 * inn) + fo + 0.01 * smoothstep(0.85, 0.98, s) * maxf(0.0, cos(a))
		var pf := func(s: float, a: float) -> float:
			return (0.004 + 0.013 * smoothstep(0.1, 0.6, s)) * P._lf(s, a, sv) + 0.008 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		P._lt(k, le, pa, func(s, a, ins): return gp.darkened(0.3) if ins else P._fs(gp, float(pf.call(float(s), float(a))), 9.0), 0.0, 0.975, 44, 26, 0.05)
		K._lt_in(k, le, func(s, a): return float(pa.call(float(s), float(a))) - 0.005, gp.darkened(0.2), 0.8, 0.975, 8, 26)
		P._bare(k, le, skc, 0.72, 1.0)
		if sd == "Left":   # kırmızı-siyah kolluk: siyah halkalar arasında kırmızı bant
			P._lt(k, ar, func(s, _a): return 0.009 + 0.0035 * float(absf(float(s) - 0.835) < 0.04), func(s, _a, ins):
				if ins:
					return bk
				return rd if absf(float(s) - 0.835) < 0.04 else bk, 0.74, 0.93, 16, 20)
	# kemer + toka, bağcık
	var by: float = H + 0.08
	var blk := [P._kp(k.M(H + 0.05, 0.3), H + 0.12, 0.016), P._kp(k.M(H + 0.05, 0.3), H + 0.04, 0.018)]
	P._sash(k, blk, by, 0.015, 0.0, bk, 0.08)
	var bf: Array = P._sa(blk, 0.0, by, 0.012)
	Q._buckle(k, bf[0], bf[1], 0.022, 0.016, mt, [["Hips", 0.5], ["Spine", 0.5]])
	var dsk := func(p): return k.cloth_skin(p, H - 0.2, 0.3)
	for sx in [-1.0, 1.0]:
		var c0: Vector3 = P._on(sk, sx * 0.08, H + 0.02, 0.05)
		P._cord(k, [c0, c0 + Vector3(sx * 0.008, -0.03, 0.006), c0 + Vector3(sx * 0.004, -0.075, 0.006)], 0.0024, gy.darkened(0.1), false, dsk)
	# palto: yıpranmış, yırtık uç
	var e_at := func(y: float) -> float: return lerpf(0.5, 0.62, smoothstep(C, KN, y)) - 0.18 * smoothstep(N - 0.06, N + 0.012, y)
	var hem: float = KN - 0.05
	var pc: Dictionary = _kara_coat(k, b, {"col": vi, "lin": pu.darkened(0.2), "hem": hem, "hb": hem - 0.03, "wide": Vector3(0.07, 0.05, 0.09), "e": e_at, "sv": 2.6, "jag": 0.05,
		"slits": [[0.95, 0.17, 0.07], [-1.35, 0.13, 0.06], [2.5, 0.2, 0.07], [-2.75, 0.12, 0.05], [-0.7, 0.09, 0.05]]})
	var keys: Array = pc["keys"]
	var ff: Callable = pc["ff"]
	var csk: Callable = pc["sk"]
	var cg: Dictionary = pc["cg"]
	AA._edge_band(k, cg["ea"].slice(0, 44), 0.006, 0.002, vi.lightened(0.04), csk, 1.0)
	AA._edge_band(k, cg["eb"].slice(0, 44), 0.006, 0.002, vi.lightened(0.04), csk, -1.0)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.6, C - 0.08), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.2)], 0.0024, 0.0016, 0.0012, vi.darkened(0.25), csk, 10)
	# yırtık kol oyuğu: kısa, dişli kenar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv2: float = 1.1 if sd == "Left" else 2.8
		P._lts(k, ar, func(s, a): return 0.014 + 0.008 * smoothstep(0.0, 0.08, float(s)) + 0.002 * sin(float(a) * 5.0 + sv2), func(_s, _a, ins): return pu.darkened(0.2) if ins else vi,
			func(a): return 0.075 - _tear(float(a), 0.035, sv2, []), 0.0, 8, 30)
	# kalın mor atkı: boynu saran turlar + göğse düşen kat
	G._rolls(k, b, pu, [[-0.018, 0.06, 0.024], [0.01, 0.046, 0.022], [0.036, 0.034, 0.019], [0.058, 0.026, 0.016]], {"tilt": 0.008, "wob": 0.004, "ph": 0.6, "seg": 12, "crease": 0.18, "drop": 0.026})
	var bk2 := [P._kp(nk, N + 0.0, 0.05), [N - 0.06, ch.x * 0.86, ch.y * 0.9 + 0.03, ch.z * 0.9], P._kp(ch, C - 0.03, 0.035)]
	P._cl(k, {"keys": bk2, "ny": 10, "na": 30, "rng": func(_v): return Vector2(-0.75, 0.75), "top": func(_a): return N - 0.02,
		"hem": func(a): return N - 0.05 - 0.08 * pow(maxf(0.0, cos(float(a) * 1.9 + 0.15)), 1.4), "fold": func(a, _y, v): return 0.02 * float(v) * sin(float(a) * 9.0 + 0.4),
		"col": func(_a, _y, _v): return pu, "gain": 7.0, "th": 0.006, "inner": pu.darkened(0.3), "skin": func(p): return Q._nsk(k, p)})


# ------------------------------------------------------------------ Tetsu Shōzoku (ref Killer Bee Outfit): gömleksiz Kumo takımı; sol omuzdan tek kayışlı verev beyaz göğüslük (gri biye, dört çizgi),
## kalın sarılı beyaz atkı (sırttan baldıra inen yırtık ucu), burgulu kırmızı ip kemer (arkada püsküllü ucu), altında verev beyaz bez, kırmızı plakalı beyaz eldiven,
## dizde çapraz sargı, sivri dizlikli kırmızı çizgili beyaz kaval, lacivert pantolon, sağ omuzda mavi 鉄 dövmesi (kadında altında mavi atlet)
static func _demir(k) -> void:
	var nv := Color(0.118, 0.141, 0.251)
	var wh := Color(0.93, 0.93, 0.92)
	var gr := Color(0.62, 0.63, 0.67)
	var rd := Color(0.6, 0.1, 0.13)
	var bt := Color(0.16, 0.26, 0.56)
	var bg := Color(0.42, 0.31, 0.21)
	var fem: bool = String(k.m.look.get("gender", "m")) == "f"
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
	if fem:
		P._inner(k, b, func(_i, j, _p): return bt.lightened(0.04) if j < 3 else bt, 0.006)
	else:
		R._bare_torso(k, b, H - 0.03, true)
	K._seat(k, b, nv.darkened(0.1))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = AA._bare_arm(k, sd)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.3 if sd == "Left" else 2.6
		var kn: float = le["kn"]
		var sg: float = ar["sg"]
		R._arm_skin(k, ar, 0.0)
		# eldiven: bilekte beyaz ağız, dış yanda kırmızı plaka, el sırtında gümüş disk
		P._lt(k, ar, func(s, _a): return 0.009 + 0.004 * smoothstep(0.86, 0.9, float(s)), func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, 0.84, 0.985, 8, 18)
		Z._glove_full(k, sd, wh)
		var ao: float = J._outer_a(ar, 0.9, Vector3(sg, 0.0, 0.0))
		var e: Array = Q._ls(ar, 0.9, ao, 0.014)
		var dd: Vector3 = P._ld(ar, 0.9)
		P._boxr(k, e[0], (e[1] as Vector3).cross(dd).normalized() * 0.008, dd * 0.03, (e[1] as Vector3) * 0.004, rd, P._lskin(ar, 0.9), 0.25)
		var hd: Vector3 = k.m._bp(sd + "Hand")
		var hdir: Vector3 = (hd - (k.m._bp(sd + "LowerArm") as Vector3)).normalized()
		var w := (Vector3.BACK - hdir * hdir.dot(Vector3.BACK)).normalized()
		var t := hdir.cross(w).normalized()
		var o2: Vector3 = t if t.y > 0.0 else -t
		P._stud(k, hd + hdir * 0.035 + o2 * 0.02, o2, 0.0085, gr.darkened(0.2), [[sd + "Hand", 1.0]])
		# 鉄 dövmesi: sağ omuzun dış yanında kabartma çizgiler
		if sd == "Right" and not fem:
			var s0: float = 0.14
			var a0: float = J._outer_a(ar, s0, Vector3(-1.0, 0.25, 0.0).normalized())
			var mp: Callable = R._lmap(ar, func(_s, _a): return 0.001, s0, a0)
			var sc := 0.026
			for st in [[-0.55, 1.0, -0.95, 0.55], [-0.55, 1.0, -0.15, 0.55], [-0.8, 0.42, -0.3, 0.42], [-0.85, 0.08, -0.25, 0.08], [-0.55, 0.42, -0.55, -0.8], [-0.75, -0.15, -0.68, -0.42], [-0.35, -0.15, -0.42, -0.42], [-0.95, -0.85, -0.15, -0.72],
					[0.32, 0.95, 0.15, 0.62], [0.18, 0.58, 0.85, 0.58], [0.08, 0.15, 0.95, 0.15], [0.55, 0.95, 0.55, 0.15], [0.55, 0.15, 0.15, -0.9], [0.55, 0.15, 0.95, -0.9]]:
				R._lstrip(k, mp, [Vector2(-float(st[0]) * sc, float(st[1]) * sc), Vector2(-float(st[2]) * sc, float(st[3]) * sc)], 0.0021, 0.0012, 0.0009, bt, func(p): return R._lsk(ar, p))
		# pantolon + dizde çapraz sargı + kaval (parti x Kumo kesimi)
		var pa: Callable = K._pant(k, le, nv, 0.012, 0.026, 1.0, sv)
		X._xband(k, le, pa, kn - 0.075, 0.03, 0.012, wh)
		X._xband(k, le, func(s, a): return float(pa.call(s, a)) + 0.0045, kn - 0.075, -0.03, 0.012, wh.darkened(0.04))
		var ga := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.007 + 0.006 * pow(maxf(0.0, cos(a)), 4.0)
		J._lta(k, le, ga, func(s, a, ins):
			if ins:
				return wh.darkened(0.45)
			return wh.darkened(0.12 * smoothstep(0.2, -0.7, cos(float(a)))), func(a): return kn + 0.12 - 0.025 * pow(maxf(0.0, cos(float(a))), 2.0), 0.935, 24, 22)
		for ax in [-0.45, -0.15, 0.15, 0.45]:
			X._ll(k, le, [Vector2(kn + 0.16, ax), Vector2(0.89, ax)], func(s, a): return float(ga.call(s, a)) + 0.001, 0.0075, 0.0032, rd, 8)
		X._lt_ring(k, le, ga, 0.945, 0.025, wh, 0.006)
		X._lplate(k, le, -1.2, 1.2, func(a): return kn - 0.04 + 0.065 * pow(absf(float(a)) / 1.2, 1.3), kn + 0.14, func(s, a): return float(ga.call(s, a)) + 0.004, 0.01, wh.lightened(0.02), 10, 16)
	# verev beyaz bez: sağda kısa, sol uyluğa iner; üstüne binen kanadın kenarı
	var hk := [P._kp(wa, H + 0.07, 0.016), P._kp(hp, H - 0.04, 0.036), [H - 0.18, hp.x + 0.066, hp.y + 0.062, hp.z - 0.066], [H - 0.3, hp.x + 0.078, hp.y + 0.072, hp.z - 0.078]]
	var dhem := func(a: float) -> float: return H - 0.085 - 0.15 * smoothstep(-0.5, 0.95, sin(a))
	var dsk := func(p): return X._xsk(k, p, H - 0.24)
	var df := func(a, _y, v) -> float: return float(v) * (0.022 * sin(float(a) * 7.0 + 0.5) + 0.011 * sin(float(a) * 13.0 + 1.7))
	P._cl(k, {"keys": hk, "ny": 14, "na": 84, "top": func(_a): return H + 0.065, "hem": func(a): return float(dhem.call(float(a))), "fold": df,
		"col": func(_a, _y, _v): return wh.darkened(0.04), "gain": 7.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": dsk})
	var fl: Dictionary = P._cl(k, {"keys": hk, "ny": 14, "na": 60, "rng": func(v): return Vector2(lerpf(-1.3, 0.62, float(v)), 2.35), "top": func(_a): return H + 0.065,
		"hem": func(a): return float(dhem.call(float(a))) - 0.006, "fold": df, "lift": 0.007, "col": func(_a, _y, _v): return wh, "gain": 7.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": dsk})
	P._cord(k, fl["ea"], 0.004, gr, false, dsk)
	X._bag(k, hk, H - 0.045, 0.012 + 0.03, bg)
	# göğüslük: sağ koltuk altından sol omuza verev; sol omuzda kayış + çıtçıt
	var pad: float = 0.03 if not fem else 0.036
	var vk := [P._kp(nk, N + 0.012, 0.026), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, pad), P._kp(wa, H + 0.12, 0.028), P._kp(wa, H + 0.03, 0.034)]
	var top := func(a: float) -> float:
		var t: float = sin(a)
		if t < 0.72:
			return lerpf(C - 0.09, N - 0.035, smoothstep(-1.0, 0.72, t))
		return lerpf(N - 0.035, C - 0.045, smoothstep(0.72, 1.0, t))
	var vf := func(a, y, _v) -> float: return 0.004 * sin(float(a) * 4.0 + float(y) * 9.0)
	var cg: Dictionary = P._cl(k, {"keys": vk, "ny": 30, "na": 96, "top": func(a): return float(top.call(float(a))), "hem": func(_a): return H + 0.045, "fold": vf,
		"col": func(_a, _y, v): return wh.darkened(0.2) if float(v) > 0.97 else wh, "gain": 6.0, "th": 0.006, "inner": wh.darkened(0.35), "skin": tsk})
	P._cord(k, cg["top"], 0.0058, gr, true, tsk)
	P._line(k, vk, [Vector2(0.06, float(top.call(0.06)) - 0.006), Vector2(0.7, C - 0.07), Vector2(1.3, H + 0.13)], 0.0034, 0.0018, 0.0024, gr, 8)
	P._line(k, vk, [Vector2(0.86, C - 0.035), Vector2(0.3, H + 0.15), Vector2(-0.22, H + 0.06)], 0.0034, 0.0018, 0.0024, gr, 8)
	P._line(k, vk, [Vector2(PI - 0.25, float(top.call(PI - 0.25)) - 0.006), Vector2(PI - 1.1, H + 0.1)], 0.0034, 0.0018, 0.0024, gr, 8)
	for i in 4:
		var a: float = 0.1 + 0.11 * float(i)
		var yt: float = C - 0.02
		P._line(k, vk, [Vector2(a, yt), Vector2(a - 0.015, yt - 0.04)], 0.0036, 0.0018, 0.0024, gr, 4)
	var sx: float = ch.x * 0.58
	P._over(k, vk, sx, N - 0.05, N - 0.07, 0.022, 0.006, 0.006, wh.lightened(0.02))
	var sn: Array = P._fp(vk, sx, N - 0.035, true, 0.013)
	P._boxr(k, sn[0], Vector3(0.016, 0, 0), Vector3(0, 0.014, 0), ((sn[1] as Vector3) + Vector3.UP * 0.6).normalized() * 0.004, wh.darkened(0.06), k.torso_skin(N - 0.035), 0.3)
	P._stud(k, (sn[0] as Vector3) + ((sn[1] as Vector3) + Vector3.UP * 0.6).normalized() * 0.006, ((sn[1] as Vector3) + Vector3.UP * 0.6).normalized(), 0.0065, gr.darkened(0.15), k.torso_skin(N - 0.035))
	# burgulu kırmızı ip kemer
	var by: float = H + 0.04
	var rp: Array = P._ring_pts(vk, by, 0.012, 64)
	T._twist(k, rp, true, 0.016, 12.0, rd, tsk)
	# arkada sarkan ip ucu + püskül (sağ kalçanın arkası)
	# ip kemerden kalçanın arkasına iner, sonra sağ bacağın arka-iç yüzünde baldıra kadar oturur (bacakla gider, sallanıp delmez)
	var rle: Dictionary = P._limb(k, "Right", true)
	var rkn: float = rle["kn"]
	var r0: Vector3 = P._sa(vk, -2.55, by, 0.012)[0]
	var rl := [r0, P._sa(hk, -2.6, H + 0.0, 0.03)[0]]
	for i in 9:
		var s: float = lerpf(0.16, 0.86, float(i) / 8.0)
		rl.append(Q._ls(rle, s, 2.55, lerpf(0.05, 0.03, smoothstep(0.1, rkn, s)) + 0.03 * smoothstep(rkn + 0.05, rkn + 0.14, s))[0])
	var rsk := func(p: Vector3) -> Array:
		if p.y >= H + 0.01:
			return k.torso_skin(p.y)
		var w: float = smoothstep(H + 0.01, H - 0.1, p.y)
		var out := [["Hips", 1.0 - w]]
		for e2 in R._lsk(rle, p):
			out.append([e2[0], float(e2[1]) * w])
		return out
	T._twist(k, rl, false, 0.0115, 9.0, rd.darkened(0.08), rsk, 0.1)
	var tl: Vector3 = rl[rl.size() - 1]
	for j in 7:
		var u: float = float(j) / 6.0 - 0.5
		var st: Vector3 = tl + Vector3(u * 0.012, 0.004, 0.0)
		var en: Vector3 = tl + Vector3(u * 0.03, -0.075 + 0.012 * absf(u), -0.004 * cos(u * PI))
		P._tb(k, [st, st.lerp(en, 0.5), en], func(s, _a): return 0.0034 * (1.0 - 0.6 * float(s)), func(_s, _a, _p): return rd.darkened(0.1 + 0.08 * float(j % 2)), func(_s, p): return rsk.call(p), 5)
	# atkı: kalın beyaz turlar
	G._rolls(k, b, wh, [[-0.02, 0.07, 0.027], [0.012, 0.054, 0.025], [0.042, 0.04, 0.021], [0.064, 0.03, 0.017]], {"tilt": 0.007, "wob": 0.004, "ph": 2.0, "seg": 12, "crease": 0.12, "drop": 0.02})
	# sırttan inen yırtık atkı ucu: göğüslüğün ve kemerin üstünden geçer, bacaklar arasından baldıra iner
	var tp := []
	for i in 22:
		var t := float(i) / 21.0
		var y: float = lerpf(N - 0.02, KN - 0.07, t)
		var x: float = lerpf(0.03, 0.0, t)
		var z := 9.0
		if y > H - 0.02:
			z = minf(z, float(SE.El.key_at(vk, maxf(y, H + 0.03))[3]))
		if y < H + 0.08:
			z = minf(z, float(SE.El.key_at(hk, clampf(y, H - 0.3, H + 0.07))[3]))
		z -= 0.009 + 0.024 * exp(-pow((y - by) / 0.035, 2.0))
		tp.append(Vector3(x, y, z))
	_flat_tail(k, tp, func(s): return lerpf(0.05, 0.034, float(s)), 0.0045, 0.12, wh.darkened(0.03), func(p): return AA._fam(k, p, KN - 0.1), 1.3)


# ------------------------------------------------------------------ Kugutsu Shōzoku (ref Kankuro Outfit): siyah balıkçı yaka uzun kollu üst, belde kızıl kuşak, altında uyluğa inen siyah önlük (iç etek + üstte ön panel),
## omuzlardan göğsün yanlarına inen geniş beyaz kayışlar (sırtta yatay bağ), siyah tam eldiven, bilekte toplanan bol siyah pantolon + koyu bilek sargısı
static func _kukla(k) -> void:
	var bk := Color(0.11, 0.11, 0.133)
	var bd := Color(0.094, 0.094, 0.11)
	var rd := Color(0.541, 0.102, 0.165)
	var wh := Color(0.9, 0.9, 0.89)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# üst: balıkçı yaka + gövde
	var keys := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.04], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.034), P._kp(wa, H + 0.04, 0.03)]
	var tff := func(a: float, y: float) -> float:
		var s: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return (1.0 - s) * 0.014 * sin(a * 9.0 + y * 12.0) * smoothstep(0.1, 0.0, absf(y - H - 0.1) - 0.04) + s * 0.006 * sin(a * 5.0 - y * 22.0)
	SE.body_layer(k, keys, 30, 56, func(i, _j, p):
		var a: float = TAU * float(i) / 56.0 - PI
		return P._fs(bk, float(tff.call(a, p.y)), 9.0), tff)
	X._neck(k, b, bk, 0.075, false, 0.002)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.5 if sd == "Left" else 1.8
		var sl: Callable = X._sleeve(k, ar, bk, 0.96, sv, 0.012)
		Z._glove_full(k, sd, bd)
		P._lt(k, ar, func(s, _a): return float(sl.call(float(s), 0.0)) * 0.5 + 0.007 + 0.003 * smoothstep(0.88, 0.86, float(s)), func(_s, _a, ins): return bd.darkened(0.3) if ins else bd.lightened(0.03), 0.86, 0.985, 6, 18)
		Q._baggy(k, le, bk, bd, 0.016, 0.04, 0.86, sv)
		P._wraps(k, le, 0.86, 0.95, 4, 0.008, 0.011, bd.lightened(0.05), 0.006)
	# önlük: kuşak altında uyluğa inen kapalı iç etek + önde biraz daha uzun panel
	var hem: float = H - 0.2
	var sk := [P._kp(wa, H + 0.07, 0.036), P._kp(hp, H - 0.04, 0.05), [hem, hp.x + 0.07, hp.y + 0.06, hp.z - 0.07]]
	var ssk := func(p): return T._ksk(k, p, hem - 0.03)
	var sf := func(a, y, _v) -> float:
		var t: float = clampf((H + 0.05 - float(y)) / (H + 0.05 - hem), 0.0, 1.0)
		return t * (0.022 * sin(float(a) * 6.0 + 0.4) + 0.01 * sin(float(a) * 11.0 + 1.6))
	var sg0: Dictionary = P._cl(k, {"keys": sk, "ny": 20, "na": 88, "top": func(_a): return H + 0.07, "hem": func(a): return hem + 0.012 * smoothstep(0.9, 1.6, absf(float(a))), "fold": sf,
		"col": func(_a, _y, _v): return bk, "gain": 7.0, "th": 0.006, "inner": bk.darkened(0.35), "skin": ssk})
	P._bd(k, AA._yl(sg0["hem"], 0.008), 0.0045, 0.0018, bk.lightened(0.04), false, ssk)
	var sk2 := []
	for e2 in sk:
		sk2.append([e2[0], float(e2[1]) + 0.01, float(e2[2]) + 0.012, float(e2[3]) - 0.012])
	var ap: Dictionary = P._cl(k, {"keys": sk2, "ny": 18, "na": 40, "rng": func(_v): return Vector2(-1.05, 1.05), "top": func(_a): return H + 0.06, "hem": func(_a): return hem - 0.025,
		"fold": func(a, y, v): return float(sf.call(a, y, v)) * 0.7, "col": func(_a, _y, _v): return bd, "gain": 7.0, "th": 0.006, "inner": bd.darkened(0.3), "skin": ssk})
	AA._edge_band(k, ap["ea"], 0.006, 0.002, bd.lightened(0.05), ssk, 1.0)
	AA._edge_band(k, ap["eb"], 0.006, 0.002, bd.lightened(0.05), ssk, -1.0)
	P._bd(k, AA._yl(ap["hem"], 0.008), 0.005, 0.0018, bd.lightened(0.05), false, ssk)
	# kızıl kuşak
	var obk := [P._kp(wa, H + 0.12, 0.04), P._kp(wa, H + 0.02, 0.046)]
	P._sash(k, obk, H + 0.07, 0.024, 0.004, rd, 0.12)
	# beyaz kayışlar: omuzdan önde göğsün yanına iner, koltuk altına döner; sırtta iki kayış yatay bağla birleşir
	var sx: float = ch.x * 0.7
	for sg in [1.0, -1.0]:
		P._over(k, keys, sg * sx, C - 0.0, C - 0.11, 0.022, 0.006, 0.0055, wh)
		P._strap(k, keys, [Vector2(sg * sx, C + 0.005), Vector2(sg * ch.x * 0.82, C - 0.06), Vector2(sg * ch.x * 0.97, C - 0.1)], true, 0.022, 0.006, 0.0055, wh, 6, func(p): return k.torso_skin(p.y))
	P._strap(k, keys, [Vector2(-sx - 0.02, C - 0.1), Vector2(sx + 0.02, C - 0.1)], false, 0.02, 0.0115, 0.005, wh.darkened(0.04), 10, func(p): return k.torso_skin(p.y))


# ------------------------------------------------------------------ Kanchi Shōzoku (ref Karin Outfit): dik yakalı açık mor uzun kollu ceket (ortada beyaz fermuar biyesi, göğüs yanlarında koyu pens kıvrımı,
## gri kemer + toka, kemerin altında ters V açılıp göbeği gösterir, uyluk üstüne iner, sırtta gri çanta), siyah kısa şort, uyluk ortasına çıkan koyu çorap
static func _algi(k) -> void:
	var lv := Color(0.722, 0.627, 0.847)
	var ld := Color(0.47, 0.36, 0.66)
	var bk := Color(0.094, 0.094, 0.11)
	var gy := Color(0.62, 0.68, 0.68)
	var sock := Color(0.13, 0.12, 0.13)
	var zp := Color(0.92, 0.92, 0.94)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc := Q._skc(k)
	# karın: ceketin açıldığı yerde ten
	SE.body_layer(k, [P._kp(wa, H + 0.13, 0.002), P._kp(wa, H + 0.04, 0.004), P._kp(hp, H - 0.05, 0.006)], 8, 40, func(_i, _j, _p): return skc)
	var sk := R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.5 if sd == "Left" else 1.6
		var kn: float = le["kn"]
		var s1: float = kn * 0.26
		var ad: Callable = R._short_leg(k, le, bk, s1, 0.016, 0.01, sv)
		R._hem_roll(k, le, ad, s1, bk.lightened(0.05), 0.02, 0.003)
		Y._sock_leg(k, le, sock, kn * 0.62, sv, 0.022)
	# ceket
	var by: float = H + 0.1
	var hem: float = H - 0.1
	var jk := [P._kp(nk, N + 0.012, 0.024), [N - 0.05, ch.x * 1.03, ch.y * 0.97, ch.z * 1.05], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.022), [H - 0.0, hp.x + 0.04, hp.y + 0.04, hp.z - 0.036], [hem, hp.x + 0.065, hp.y + 0.06, hp.z - 0.06]]
	var jsk := func(p): return T._ksk(k, p, hem)
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		var pleat: float = -0.022 * exp(-pow((aw - lerpf(1.05, 0.78, smoothstep(C + 0.02, C - 0.12, y))) / 0.06, 2.0)) * smoothstep(C + 0.04, C - 0.02, y) * smoothstep(by - 0.01, C - 0.1, y)
		var gath: float = 0.012 * exp(-pow((y - by) / 0.03, 2.0)) * sin(a * 11.0 + 0.4)
		return t * t * (0.024 * sin(a * 6.0 + 0.9) + 0.01 * sin(a * 11.0 + 2.1)) + pleat + gath + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 13.0) * smoothstep(N - 0.03, C - 0.05, y)
	var e_at := func(y: float) -> float: return 0.012 + 0.42 * pow(smoothstep(by - 0.01, hem, y), 0.8)
	var cg: Dictionary = P._cl(k, {"keys": jk, "ny": 46, "na": 96, "rng": func(v):
		var e: float = e_at.call(lerpf(N + 0.012, hem, float(v)))
		return Vector2(e, TAU - e), "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return lv, "gain": 6.0, "th": 0.006, "inner": lv.darkened(0.3), "skin": jsk})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# fermuar biyesi: iki kenarda beyaz şerit, yakadan kemere birleşik
	for ed in [cg["ea"], cg["eb"]]:
		P._bd(k, ed, 0.0032, 0.0022, zp, false, jsk)
	P._bd(k, AA._yl(cg["hem"], 0.008), 0.0045, 0.0018, lv.darkened(0.12), false, jsk)
	# pens kıvrımlarının koyu dikişi + yan dikiş
	for sg in [1.0, -1.0]:
		Q._run(k, jk, ffw, [Vector2(sg * 1.06, C + 0.04), Vector2(sg * 0.9, C - 0.05), Vector2(sg * 0.78, C - 0.12)], 0.003, 0.001, 0.0016, ld, jsk, 6)
		Q._run(k, jk, ffw, [Vector2(sg * 1.6, C - 0.08), Vector2(sg * 1.6, H), Vector2(sg * 1.58, hem + 0.02)], 0.0022, 0.0015, 0.0012, lv.darkened(0.22), jsk, 8)
	# kemer + toka (solda), sırtta çanta
	var blk := [P._kp(wa, by + 0.04, 0.03), P._kp(wa, by - 0.04, 0.034)]
	P._sash(k, blk, by, 0.017, 0.0, gy, 0.08)
	var bf: Array = P._sa(blk, 0.75, by, 0.012)
	var bo: Vector3 = bf[1]
	P._boxr(k, bf[0], Vector3.UP.cross(bo).normalized() * 0.022, Vector3(0, 0.017, 0), bo * 0.005, gy.lightened(0.05), [["Spine", 0.5], ["Hips", 0.5]], 0.2)
	for dx in [-0.01, 0.01]:
		P._boxr(k, (bf[0] as Vector3) + Vector3.UP.cross(bo).normalized() * dx + bo * 0.007, Vector3.UP.cross(bo).normalized() * 0.0025, Vector3(0, 0.015, 0), bo * 0.002, gy.darkened(0.15), [["Spine", 0.5], ["Hips", 0.5]], 0.3)
	X._bag(k, blk, by - 0.005, 0.03, gy.darkened(0.05))
	# kollar: bileğe uzun, dirsekte kırışık, bilekte biye
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.0 if sd == "Left" else 2.3
		var sl: Callable = X._sleeve(k, ar, lv, 0.97, sv, 0.01)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return lv.darkened(0.35) if ins else lv.darkened(0.08), 0.94, 0.97, 3, 18)
	# dik yaka: önde fermuar ağzı
	X._neck(k, b, lv, 0.055, true)
