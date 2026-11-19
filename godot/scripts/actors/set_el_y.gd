extends RefCounted
## Elle modellenmiş setler, parti y: ss_gunebakan, ss_lavanta_ceket, ss_pembe_ceket, ss_acik_ceket, ss_mor_kemer, ss_pembe_kazak. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), r (R), u (U) dosyalarından; burada boyna düşmüş kapüşon, kapüşonlu ceket gövdesi, örgü dokusu, file sütyen ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")

const DONE := ["ss_gunebakan", "ss_lavanta_ceket", "ss_pembe_ceket", "ss_acik_ceket", "ss_mor_kemer", "ss_pembe_kazak"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_gunebakan": _gunebakan(k)
		"ss_lavanta_ceket": _lavanta(k)
		"ss_pembe_ceket": _pembe(k)
		"ss_acik_ceket": _acik(k)
		"ss_mor_kemer": _mor_kemer(k)
		"ss_pembe_kazak": _pembe_kazak(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Kısa etek ağırlığı: etek ucu bacakla açılır ama yanlar daha az izler (koşuda sivri kanat açılmaz); arkada geçiş geniş (geri giden bacak kumaşı ezmez)
static func _msk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var side: float = absf(p.x) / maxf(0.001, absf(p.x) + absf(p.z))
	var bk: float = smoothstep(0.02, -0.08, p.z)
	var w: float = t * 0.6 * (1.0 - 0.45 * smoothstep(0.45, 0.85, side)) * lerpf(1.0, 0.6, bk)
	var hw: float = lerpf(0.08, 0.13, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Diz altına inen A kesim etek ağırlığı: ön yüz uyluğu izler ama baldırı izlemez (kalkan diz kumaşı delmez, diz altı ön kumaş bacakla geri kaçmaz);
## arka yüzde ağırlık yavaş artar ve iki bacak arasına geniş yayılır, yalnız arkada baldırı biraz izler (geri savrulan topuk delmez)
static func _askirt(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.02, -0.08, p.z)
	var wf: float = 0.95 * pow(minf(1.0, t / 0.4), 0.45)
	var wb: float = lerpf(0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.9)), 0.94, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.05, 0.11, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var sd: String = "Left" if s >= 0.5 else "Right"
	var os: String = "Right" if s >= 0.5 else "Left"
	var ws: float = maxf(s, 1.0 - s)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.14, p.y) * 0.45 * smoothstep(0.5, 1.0, bk) * absf(2.0 * s - 1.0)
	return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]


## Üçgen dalga: x açısında n diş, 0..1 (1 = diş ucu)
static func _teeth(a: float, n: float, ph := 0.0) -> float:
	return absf(fposmod(a * n / TAU + ph, 1.0) * 2.0 - 1.0)


## Boyna düşmüş kapüşon: boynu saran bol halka (önde iki kanat kesişir) + sırta düşen torba. hk: gövde anahtarları
static func _hood_down(k, b: Dictionary, hk: Array, col: Color, open_a := 0.32, bag := 0.07, lin := Color(0, 0, 0, 0)) -> Dictionary:
	var N: float = k.N
	var C: float = k.C
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var q: float = Q._hq(k)
	var nsk := func(p): return Q._nsk(k, p)
	var tsk := func(p): return k.torso_skin(p.y)
	var inner: Color = lin if lin.a > 0.0 else col.darkened(0.38)
	var hk2 := [[N + 0.11 * q, nk.x + 0.07, nk.y + 0.05, nk.z - 0.088], [N + 0.05 * q, nk.x + 0.064, nk.y + 0.054, nk.z - 0.077], [N - 0.005, nk.x + 0.07, nk.y + 0.06, nk.z - 0.072], [N - 0.06, ch.x * 0.82, ch.y * 0.9, ch.z * 0.98]]
	var hf := func(a: float, _y: float, v: float) -> float:
		return 0.05 * sin(float(v) * PI * 2.0 + cos(a) * 1.1) * smoothstep(0.0, 0.25, float(v)) * (1.0 - float(v) * 0.6) + 0.012 * sin(a * 8.0 + 0.7) * float(v)
	var cg: Dictionary = P._cl(k, {"keys": hk2, "ny": 14, "na": 60, "rng": func(_v): return Vector2(open_a, TAU - open_a), "top": func(a):
		return N + q * lerpf(0.05, 0.115, smoothstep(0.3, 2.2, absf(float(a)))), "hem": func(a): return N - 0.045 - 0.02 * smoothstep(1.0, 2.6, absf(float(a))), "fold": hf,
		"col": func(_a, _y, _v): return col.lightened(0.02), "gain": 6.0, "inner": inner, "skin": nsk, "th": 0.007})
	P._cord(k, cg["top"], 0.0055, col.darkened(0.04), false, nsk)
	var sk2 := []
	for e2 in hk:
		sk2.append([e2[0], float(e2[1]) + 0.016, float(e2[2]) + 0.016, float(e2[3]) - 0.018])
	var bagf := func(a: float, _y: float, v: float) -> float:
		var db: float = clampf((PI - absf(a)) / 1.0, 0.0, 1.0)
		return bag * sin(float(v) * PI) * (1.0 - db * db) + 0.01 * sin(a * 7.0 + 0.3) * float(v)
	var bg: Dictionary = P._cl(k, {"keys": sk2, "ny": 14, "na": 36, "rng": func(_v): return Vector2(PI - 1.0, PI + 1.0), "top": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return N + 0.03 - 0.07 * db * db, "hem": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.0, 0.0, 1.0)
		return C - 0.03 + 0.08 * pow(db, 1.6), "fold": bagf, "col": func(_a, _y, _v): return col, "gain": 5.0, "inner": inner, "skin": tsk, "th": 0.006})
	P._cord(k, bg["hem"], 0.0048, col.darkened(0.06), false, tsk)
	return cg


## Uzun bol kol + ağızda katlı manşet. Döner: kol yarıçap ekleme işlevi
static func _sleeve(k, ar: Dictionary, col: Color, base: float, bag: float, s1: float, sv: float, cuff_w := 0.08, cuff := Color(0, 0, 0, 0), bell := 0.0) -> Callable:
	var en: float = ar["kn"]
	var cc: Color = cuff if cuff.a > 0.0 else col
	var sf := func(s: float, a: float) -> float:
		var b0: float = base + bag * sin(clampf(s / s1, 0.0, 1.0) * PI * 0.8) + bell * smoothstep(s1 - cuff_w - 0.15, s1, s)
		return b0 + 0.005 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s) + 0.009 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.008 * exp(-pow((s - 0.1) / 0.1, 2.0)) + 0.006 * exp(-pow((s - s1 + cuff_w + 0.03) / 0.04, 2.0)) * (0.5 + 0.5 * sin(a * 6.0 + sv))
	P._lt(k, ar, sf, func(s, a, ins): return col.darkened(0.42) if ins else P._fs(col, float(sf.call(float(s), float(a))) - base - bag * 0.5, 11.0), 0.0, s1 - cuff_w + 0.01, 34, 22, 0.02)
	var cf := func(s: float, a: float) -> float: return float(sf.call(s, a)) + 0.004 + 0.002 * sin(clampf((s - s1 + cuff_w) / cuff_w, 0.0, 1.0) * PI)
	P._lt(k, ar, cf, func(s, _a, ins): return cc.darkened(0.4) if ins else cc.darkened(0.12 * float(absf(float(s) - (s1 - cuff_w * 0.5)) > cuff_w * 0.42)), s1 - cuff_w, s1, 8, 22, 0.03)
	K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.006, cc.darkened(0.35), s1 - 0.12, s1 - 0.004, 6, 22)
	return sf


## Açık bacak + uzun çorap (s_top'tan bileğe), üstte kalın bant
static func _sock_leg(k, le: Dictionary, sock: Color, s_top: float, sv: float, band := 0.02) -> void:
	var skc: Color = Q._skc(k)
	var kn: float = le["kn"]
	if s_top > 0.01:
		P._bare(k, le, skc, 0.0, s_top + 0.015)
	var sk2 := func(s: float, a: float) -> float:
		return 0.0038 + 0.0016 * sin(a * 3.0 + s * 30.0 + sv) * exp(-pow((s - kn) / 0.06, 2.0)) + 0.0022 * smoothstep(s_top + band + 0.01, s_top + band, s) + 0.0012 * exp(-pow((s - 0.93) / 0.03, 2.0)) * sin(a * 4.0 + sv)
	P._lt(k, le, sk2, func(s, a, ins):
		if ins:
			return sock.darkened(0.3)
		return sock.lightened(0.05 * float(float(s) < s_top + band)).darkened(0.12 * maxf(0.0, -cos(float(a))) * exp(-pow((float(s) - kn) / 0.08, 2.0))), s_top, 0.99, 30, 18)


## Bilekte toplanan bol ninja pantolonu: uyluk ve baldır bol, tk'de lastikle bileğe kapanır (büzgü kıvrımı), altı açık ten. Döner: yarıçap ekleme işlevi
static func _jogger(k, le: Dictionary, col: Color, base: float, bag: float, tk: float, sv: float) -> Callable:
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		var g: float = 1.0 - smoothstep(tk - 0.02, tk + 0.004, s)
		var cr: float = 0.009 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var ru: float = 0.012 * exp(-pow((s - tk + 0.04) / 0.04, 2.0)) * sin(a * 8.0 + sv)
		return ((0.006 + bag * 0.18) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + cr + ru) * g
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = (base + bag * smoothstep(0.0, 0.4, s) * (1.0 - 0.25 * smoothstep(0.55, tk, s))) * (1.0 - 0.42 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s)))
		var g: float = smoothstep(tk - 0.05, tk + 0.004, s)
		return lerpf(v, 0.006, g) + float(fo.call(s, a))
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.45)
		return P._fs(col, fo.call(s, a), 13.0), 0.0, tk + 0.01, 44, 24, 0.02)
	P._lt(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return col.darkened(0.4) if ins else col.darkened(0.12), tk - 0.018, tk + 0.012, 3, 24)
	P._bare(k, le, Q._skc(k), tk - 0.01, 1.0)
	return ad


## Hinata ceketi gövdesi (kapüşonlu, raglan kollu): ön / yan paneller lavanta, raglan omuz beyaz. o: open (fermuar açık), hem, flare, lav, wh, zip
static func _hjacket(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var lav: Color = o["lav"]
	var wh: Color = o["wh"]
	var hem: float = o["hem"]
	var fl: float = o.get("flare", 0.1)
	var open: bool = o.get("open", false)
	var jk := [P._kp(nk, N + 0.012, 0.03), [N - 0.05, ch.x * 1.04, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.04),
		[H - 0.0, hp.x + 0.03 + fl * 0.5, hp.y + 0.03 + fl * 0.45, hp.z - 0.03 - fl * 0.4], [hem, hp.x + 0.03 + fl, hp.y + 0.03 + fl * 0.8, hp.z - 0.03 - fl * 0.7]]
	var rag := func(y: float) -> float:   # raglan dikişinin önden açısı: boyundan koltuk altına
		return lerpf(1.32, 0.5, smoothstep(C - 0.07, N + 0.01, y))
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.1 - y) / (H + 0.1 - hem), 0.0, 1.0)
		var aw: float = absf(a)
		return t * t * (0.03 * sin(a * 7.0 + 0.4) + 0.012 * sin(a * 13.0 + 1.3)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 17.0) * smoothstep(N - 0.02, C - 0.04, y) - 0.008 * exp(-pow((aw - float(rag.call(y))) / 0.05, 2.0)) * smoothstep(C - 0.08, C - 0.05, y)
	var colf := func(a: float, y: float) -> Color:
		var aw: float = absf(a)
		var r0: float = rag.call(y)
		if y > C - 0.07 and aw > r0 and aw < PI - r0:
			return wh
		if aw > 1.3 and aw < 1.95:
			return lav.darkened(0.08)
		return lav
	var e_at := func(y: float) -> float:
		if not open:
			return 0.012
		return lerpf(0.42, 0.62, smoothstep(N - 0.02, C - 0.08, y)) + 0.06 * smoothstep(H + 0.15, hem, y)
	var jsk: Callable = o.get("skin", func(p): return P._hs(k, p))
	var g: Dictionary = P._cl(k, {"keys": jk, "ny": 44, "na": 92, "rng": func(v):
		var e: float = e_at.call(lerpf(N + 0.012, hem, float(v)))
		return Vector2(e, TAU - e),
		"top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(a, y, _v): return colf.call(float(a), float(y)), "gain": 6.0, "th": 0.006, "inner": lav.darkened(0.3) if open else lav.darkened(0.42), "skin": jsk})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# raglan dikişleri (önde ve arkada)
	for sg in [1.0, -1.0]:
		for bk in [false, true]:
			var ctrl := []
			for i in 6:
				var y: float = lerpf(N + 0.005, C - 0.07, float(i) / 5.0)
				var a0: float = rag.call(y)
				ctrl.append(Vector2(sg * (PI - a0 if bk else a0), y))
			Q._run(k, jk, ffw, ctrl, 0.0028, 0.002, 0.0018, lav.darkened(0.25), jsk, 6)
		Q._run(k, jk, ffw, [Vector2(sg * 1.3, C - 0.07), Vector2(sg * 1.3, H), Vector2(sg * 1.3, hem + 0.01)], 0.0024, 0.002, 0.0016, lav.darkened(0.25), jsk, 8)
		Q._run(k, jk, ffw, [Vector2(sg * 1.95, C - 0.07), Vector2(sg * 1.95, H), Vector2(sg * 1.95, hem + 0.01)], 0.0024, 0.002, 0.0016, lav.darkened(0.25), jsk, 8)
	# etek ucu biyesi
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, hm, 0.004, 0.0018, lav.darkened(0.16), false, jsk)
	# fermuar: kapalıysa ortada dişli bant + çekme, açıksa iki kenarda ayrı bant
	var zp: Color = o.get("zip", Color(0.82, 0.83, 0.86))
	if open:
		for ed in [g["ea"], g["eb"]]:
			P._bd(k, ed, 0.0042, 0.0022, zp.darkened(0.1), false, jsk)
	else:
		var zz := []
		var y := N + 0.006
		while y > hem + 0.004:
			zz.append(Q._spt(jk, ffw, 0.0, y, 0.004)[0])
			y -= 0.006
		P._bd(k, zz, 0.0048, 0.0018, lav.darkened(0.25), false, jsk)
		for i in zz.size():
			if i % 2 == 0:
				P._stud(k, zz[i], P._out(zz[i]), 0.0026, zp, jsk.call(zz[i]))
		var t0: Array = Q._spt(jk, ffw, 0.0, N - 0.03, 0.009)
		P._boxr(k, t0[0], Vector3(0.005, 0, 0), Vector3(0, 0.014, 0), (t0[1] as Vector3) * 0.003, zp, k.torso_skin(N - 0.03), 0.4)
	return {"keys": jk, "ff": ffw, "g": g, "skin": jsk}


# ------------------------------------------------------------------ Fuji Fūdo (ref Shinobi Striker "Hinata Outfit"): boyunda görünen file atlet, lavanta önlü / yan panelli, raglan beyaz omuzlu ve beyaz kollu A kesim kapüşonlu ceket
## (ortada kapalı dişli fermuar, dolgun beyaz kapüşon yaka, lavanta çan manşetler), bilekte toplanan lacivert bol ninja pantolonu (kalçada koyu yaka parça), sağ uylukta beyaz-siyah sargı
static func _lavanta(k) -> void:
	var lav := Color(0.66, 0.62, 0.88)
	var wh := Color(0.93, 0.93, 0.95)
	var nv := Color(0.17, 0.23, 0.55)
	var nt := Color(0.13, 0.13, 0.16)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# file atlet: ten + çapraz iplikler, boyun ağzı biyeli
	var tk := [P._kp(nk, N + 0.05, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], P._kp(ch, C - 0.03, 0.004), P._kp(wa, H + 0.12, 0.004), P._kp(hp, H - 0.06, 0.006)]
	SE.body_layer(k, tk, 20, 40, func(_i, _j, _p): return skc.darkened(0.12))
	Q._net(k, tk, -0.9, 0.9, C - 0.06, N + 0.045, 0.024, 0.0015, 0.0035, nt)
	var nr := []
	for i in 40:
		nr.append(Q._spt(tk, Callable(), TAU * i / 40.0 - PI, N + 0.045, 0.003)[0])
	P._cord(k, nr, 0.0028, nt, true, func(p): return Q._nsk(k, p))
	K._seat(k, b, nv.darkened(0.06))
	# pantolon: bol, bilekte toplanır; kalçada koyu yaka parçası; sağ uylukta sargı
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.8 if sd == "Left" else 2.0
		var ad: Callable = _jogger(k, le, nv, 0.014, 0.014, 0.9, sv)
		var sg: float = le["sg"]
		var mp: Callable = R._lmap(le, ad, 0.1, sg * 0.35)
		var yk := []
		for i in 13:
			var t := float(i) / 12.0
			yk.append(Vector2(lerpf(-0.07, 0.08, t) * sg, -0.02 - 0.05 * sin(t * PI) + 0.03 * t))
		R._lstrip(k, mp, yk, 0.0032, 0.003, 0.0018, nv.darkened(0.3), func(p): return R._lsk(le, p))
		if sd == "Right":
			var s0: float = float(le["kn"]) * 0.62
			var tones := [wh, nt, wh, wh.darkened(0.06)]
			for i in 4:
				Q._ring_on(k, le, s0 + float(i) * 0.03, ad, 0.013 if i != 1 else 0.009, tones[i], 0.005)
	# ceket
	var hem: float = H - 0.085
	var jt: Dictionary = _hjacket(k, b, {"lav": lav, "wh": wh, "hem": hem, "flare": 0.1, "open": false, "skin": func(p): return _msk(k, p, hem)})
	_hood_down(k, b, jt["keys"], wh, 0.42, 0.06, wh.darkened(0.12))
	# kollar: beyaz, bol; lavanta çan manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		_sleeve(k, ar, wh, 0.022, 0.012, 0.975, 0.7 if sd == "Left" else 1.8, 0.09, lav, 0.022)
	P._cur_hem = hem


## File sütyen: iki üçgen kap (ağ + siyah kenar), göğüs altı bandı ve boyna çıkan askılar. keys: çıplak gövde anahtarları
static func _net_bra(k, keys: Array, col: Color) -> void:
	var N: float = k.N
	var C: float = k.C
	var yb: float = C - 0.085
	var yt: float = N - 0.035
	var tsk := func(p): return k.torso_skin(p.y)
	for sg in [1.0, -1.0]:
		var a_in: float = sg * 0.06
		var a_out: float = sg * 0.92
		var a_top: float = sg * 0.36
		var inside := func(a: float, y: float) -> bool:
			if y < yb or y > yt:
				return false
			var t: float = (y - yb) / (yt - yb)
			var l: float = lerpf(a_in if sg > 0.0 else a_out, a_top, t)
			var r: float = lerpf(a_out if sg > 0.0 else a_in, a_top, t)
			return a > l and a < r
		var a0: float = minf(a_in, a_out)
		var a1: float = maxf(a_in, a_out)
		P._net_patch(k, keys, inside, a0, a1, yb, yt, 0.018, 0.0013, 0.0045, col)
		# kap kenarları: alt, iç ve dış
		Q._run(k, keys, Callable(), [Vector2(a_in, yb), Vector2(a_top, yt)], 0.0028, 0.0045, 0.002, col, tsk, 8)
		Q._run(k, keys, Callable(), [Vector2(a_out, yb), Vector2(a_top, yt)], 0.0028, 0.0045, 0.002, col, tsk, 8)
		# askı: kap ucundan boynun arkasına
		var sp := []
		for i in 9:
			var t := float(i) / 8.0
			sp.append(Q._spt(keys, Callable(), sg * lerpf(0.36, 1.5, t * t), lerpf(yt, N + 0.03, sqrt(t)), 0.004)[0])
		for i in 7:
			var t := float(i + 1) / 7.0
			sp.append(Q._spt(keys, Callable(), sg * lerpf(1.5, PI - 0.02, t), N + 0.03 - 0.005 * t, 0.004)[0])
		P._cord(k, sp, 0.0022, col, false, func(p): return Q._nsk(k, p))
	# göğüs altı bandı: sırtta da devam eder
	var bp := []
	for i in 72:
		bp.append(Q._spt(keys, Callable(), TAU * i / 72.0 - PI, yb - 0.004, 0.0035)[0])
	P._bd(k, bp, 0.0055, 0.002, col, true, tsk)


## Kot şort + kemer: çok kısa paça, kıvrık açık kot paça ucu, önde cep ağızları ve fermuar dikişi, siyah kemer + gümüş toka + kemer köprüleri
static func _jean_shorts(k, b: Dictionary, dn: Color, belt: Color, mt: Color, s1f: float) -> Array:
	var H: float = k.H
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return dn)
	var hb := [["Hips", 1.0]]
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var s1: float = float(le["kn"]) * s1f
		var sv: float = 0.4 if sd == "Left" else 1.5
		var ad: Callable = R._short_leg(k, le, dn, s1, 0.018, 0.012, sv)
		R._hem_roll(k, le, ad, s1, dn.lightened(0.28), 0.032, 0.004)
		R._side_seam(k, le, ad, s1, dn.lightened(0.22))
	var by: float = H + 0.06
	P._sash(k, sk, by, 0.013, 0.006, belt, 0.08)
	var fc: Array = P._fp(sk, 0.0, by, true, 0.022)
	Q._buckle(k, fc[0], fc[1], 0.019, 0.014, mt, hb)
	for a in [0.55, 1.3, -0.55, -1.3]:
		var e: Array = Q._spt(sk, Callable(), a, by, 0.016)
		var o: Vector3 = e[1]
		P._boxr(k, e[0], Vector3.UP.cross(o).normalized() * 0.006, Vector3(0, 0.017, 0), o * 0.003, dn.darkened(0.06), hb, 0.3)
	# cep ağızları + fermuar dikişi (açık kot iplik)
	var stc: Color = dn.lightened(0.38)
	var ssk := func(p): return P._hs(k, p)
	for sg in [1.0, -1.0]:
		Q._run(k, sk, Callable(), [Vector2(sg * 0.42, H + 0.045), Vector2(sg * 0.62, H + 0.0), Vector2(sg * 0.95, H - 0.02)], 0.0018, 0.0035, 0.0012, stc, ssk, 6)
	Q._run(k, sk, Callable(), [Vector2(0.11, H + 0.045), Vector2(0.11, H - 0.04), Vector2(0.0, H - 0.07)], 0.0018, 0.0035, 0.0012, stc, ssk, 6)
	return sk


## Diz altı çorap / çizme konçu (açık bacak üstünde)
static func _knee_sock(k, le: Dictionary, col: Color, s0: float, sv: float, thick := 0.004) -> void:
	var kn: float = le["kn"]
	P._bare(k, le, Q._skc(k), 0.0, s0 + 0.015)
	var ad := func(s: float, a: float) -> float:
		return thick + 0.003 * smoothstep(s0 + 0.04, s0 + 0.01, s) + 0.0016 * sin(a * 4.0 + s * 40.0 + sv) * smoothstep(s0 + 0.05, s0 + 0.12, s) * smoothstep(0.98, 0.9, s)
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.35)
		var cr: float = 0.1 * maxf(0.0, sin(float(a) * 4.0 + float(s) * 40.0 + sv)) * float(float(s) > s0 + 0.05) + 0.08 * exp(-pow((float(s) - kn) / 0.05, 2.0)) * maxf(0.0, -cos(float(a)))
		return col.lightened(0.06 * float(float(s) < s0 + 0.035)).darkened(cr), s0, 0.99, 22, 18)


# ------------------------------------------------------------------ Fuji Fūdo Kai (ref Shinobi Striker "Hinata Outfit 3"): fermuarı açık lavanta-beyaz kapüşonlu ceket (önler düz düşer, dönük lavanta astar,
## kenarlarda ayrı fermuar bantları), file üçgen sütyen + açık karın, siyah kemerli gümüş tokalı kısa kot şort (kıvrık açık paça, cep ve fermuar dikişi), lacivert diz altı çorap
static func _acik(k) -> void:
	var lav := Color(0.66, 0.62, 0.88)
	var wh := Color(0.93, 0.93, 0.95)
	var dn := Color(0.23, 0.41, 0.69)
	var nt := Color(0.1, 0.1, 0.12)
	var mt := Color(0.8, 0.81, 0.84)
	var sock := Color(0.12, 0.13, 0.28)
	var H: float = k.H
	var b: Dictionary = P._base(k)
	var tk: Array = R._bare_torso(k, b, H - 0.02, false)
	_net_bra(k, tk, nt)
	_jean_shorts(k, b, dn, nt, mt, 0.3)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_knee_sock(k, le, sock, float(le["kn"]) + 0.08, 0.6 if sd == "Left" else 1.6)
	var hem: float = H - 0.06
	var jt: Dictionary = _hjacket(k, b, {"lav": lav, "wh": wh, "hem": hem, "flare": 0.07, "open": true, "skin": func(p): return _msk(k, p, hem)})
	_hood_down(k, b, jt["keys"], wh, 0.5, 0.06, wh.darkened(0.12))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		_sleeve(k, ar, wh, 0.024, 0.016, 0.975, 0.9 if sd == "Left" else 2.2, 0.1, lav, 0.026)
	P._cur_hem = hem


## Küre (ponpon, boncuk): fuzz > 0 ise yüzeyi tüylü pürüzlü
static func _ball(k, c: Vector3, r: float, col: Color, bones: Array, fuzz := 0.0) -> void:
	var pts := []
	for i in 9:
		pts.append(c + Vector3(0, r - 2.0 * r * float(i) / 8.0, 0))
	P._tb(k, pts, func(s, a): return maxf(0.0004, r * pow(sin(clampf(float(s), 0.0, 1.0) * PI), 0.6)) * (1.0 + fuzz * sin(float(a) * 5.0 + float(s) * 17.0)), func(s, a, _p):
		return col.darkened(0.1 * float(sin(float(a) * 5.0 + float(s) * 17.0) < -0.3) + 0.12 * float(s)), func(_s, _p): return bones, 10)


## Uca doğru incelen / sivrilen kumaş şerit: wf(t) yarı genişlik
static func _ribbon(k, pts: Array, outs: Array, wf: Callable, d: float, col: Color, skinf: Callable) -> void:
	var n := pts.size()
	var rows := []
	for i in n:
		var a: Vector3 = pts[maxi(0, i - 1)]
		var bb: Vector3 = pts[mini(n - 1, i + 1)]
		var o: Vector3 = outs[i]
		var t := float(i) / (n - 1)
		var w: Vector3 = (bb - a).normalized().cross(o).normalized() * float(wf.call(t))
		var p: Vector3 = pts[i]
		rows.append([p + w - o * 0.002, p + w * 0.8 + o * d, p - w * 0.8 + o * d, p - w - o * 0.002])
	var t0: Vector3 = rows[0][1]
	var fn: Vector3 = -(rows[0][2] - t0).cross(rows[1][2] - t0)
	if fn.dot(outs[0]) < 0.0:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(_i, j, _p): return col.darkened(0.12 * float(j == n - 1)), func(_i, _j, p): return skinf.call(p))


# ------------------------------------------------------------------ Momo Uwagi (ref Shinobi Striker "Hinata Outfit 2"): lavanta iç atlet (boyunda ve belde görünür), beyaz uzun kollu gömlek (etek ucu kısa ceketin
## altından taşar), göğüs altında biten kutu kesim pembe kısa kapüşonlu: sol kanat verev biner (boyundan sağ göğse, sonra dikey), sağ göğüste iki beyaz ponpon + mor boncuklu
## bağcık, dikey prenses dikişler, katlı ağızlı kısa kol, boyna düşmüş kapüşon; kıvrık paçalı geniş haki şort (önde kahve bağlama uçları), mor diz çizmesi konçu
static func _pembe(k) -> void:
	var pk := Color(0.91, 0.78, 0.91)
	var wh := Color(0.95, 0.95, 0.96)
	var lv := Color(0.44, 0.3, 0.66)
	var kh := Color(0.78, 0.72, 0.5)
	var br := Color(0.42, 0.27, 0.16)
	var bt := Color(0.29, 0.17, 0.36)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# lavanta atlet + boyunda lavanta biye
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return lv, 0.006, H + 0.06)
	var nr := []
	for i in 40:
		nr.append(Q._spt(ik, Callable(), TAU * i / 40.0 - PI, N + 0.035, 0.004)[0])
	P._cord(k, nr, 0.0045, lv.lightened(0.06), true, nsk)
	# beyaz gömlek: göğüsten kalçaya, etek ucu atletin üstünde biter
	var wy: float = H + 0.13
	var wk := [P._kp(nk, N + 0.03, 0.014), [N - 0.05, ch.x * 0.98, ch.y * 0.94, ch.z * 1.0], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.024), P._kp(k.M(wy, k.UA), wy, 0.026)]
	var wg: Dictionary = P._cl(k, {"keys": wk, "ny": 22, "na": 60, "top": func(_a): return N + 0.03, "hem": func(_a): return wy, "fold": func(a, y, _v): return 0.012 * sin(float(a) * 7.0 + 0.4) * smoothstep(C - 0.1, wy, float(y)),
		"col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": tsk})
	P._cord(k, wg["top"], 0.0035, wh.darkened(0.08), true, nsk)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.5 if sd == "Left" else 1.4
		var en: float = ar["kn"]
		var af := func(s: float, a: float) -> float:
			return 0.009 + 0.004 * P._lf(s, a, sv) * smoothstep(0.3, 0.45, s) + 0.007 * exp(-pow((s - en) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.9) / 0.05, 2.0)) * (0.5 + 0.5 * sin(a * 5.0 + sv)) - 0.003 * smoothstep(0.93, 0.99, s)
		P._lt(k, ar, af, func(s, a, ins): return wh.darkened(0.35) if ins else P._fs(wh, float(af.call(float(s), float(a))) - 0.01, 12.0), 0.0, 0.985, 32, 18, 0.02)
	# şort: geniş paça, kıvrık ağız, önde fermuar dikişi
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return kh)
	P._sash(k, sk, H + 0.065, 0.014, 0.006, kh.darkened(0.04), 0.1)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var s1: float = kn * 0.62
		var sv: float = 0.9 if sd == "Left" else 2.3
		var ad: Callable = R._short_leg(k, le, kh, s1, 0.022, 0.014, sv)
		R._hem_roll(k, le, ad, s1, kh.darkened(0.05), 0.04, 0.004)
		P._bare(k, le, Q._skc(k), s1 - 0.08, kn + 0.06)
		var bk := func(s: float, a: float) -> float:
			return 0.006 + 0.004 * smoothstep(kn + 0.09, kn + 0.05, s) + 0.002 * sin(a * 3.0 + s * 30.0 + sv) * smoothstep(kn + 0.1, kn + 0.2, s) * smoothstep(0.97, 0.88, s)
		P._lt(k, le, bk, func(s, a, ins): return bt.darkened(0.35) if ins else P._fs(bt, float(bk.call(float(s), float(a))) - 0.007, 14.0), kn + 0.045, 0.99, 22, 20, 0.02)
		P._lt(k, le, func(s, a): return float(bk.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return bt.darkened(0.35) if ins else bt.lightened(0.06), kn + 0.045, kn + 0.065, 2, 20)
	var ssk := func(p): return P._hs(k, p)
	Q._run(k, sk, Callable(), [Vector2(0.1, H + 0.05), Vector2(0.1, H - 0.04), Vector2(0.0, H - 0.075)], 0.002, 0.004, 0.0014, kh.darkened(0.25), ssk, 6)
	Q._run(k, sk, Callable(), [Vector2(0.0, H + 0.05), Vector2(0.0, H - 0.075)], 0.0016, 0.004, 0.0012, kh.darkened(0.3), ssk, 4)
	# kahve bağlama uçları: belin önünden sarkan iki sivri uç (biri dikey, biri sola kıvrık)
	for e in [[0.02, -0.01, 0.13, 0.018], [-0.03, 0.05, 0.1, 0.014]]:
		var pts := []
		var ou := []
		for i in 12:
			var t := float(i) / 11.0
			var y: float = H + 0.05 - t * float(e[2])
			var a: float = float(e[0]) + float(e[1]) * t * t * 8.0
			var sp: Array = Q._spt(sk, Callable(), a, y, 0.009 + 0.004 * t)
			pts.append(sp[0])
			ou.append(sp[1])
		var w0: float = e[3]
		_ribbon(k, pts, ou, func(t): return w0 * (1.0 - pow(float(t), 3.0) * 0.92), 0.004, br, ssk)
	var kp: Array = Q._spt(sk, Callable(), 0.0, H + 0.052, 0.014)
	P._boxr(k, kp[0], Vector3(0.016, 0, 0), Vector3(0, 0.012, 0), (kp[1] as Vector3) * 0.008, br.lightened(0.05), [["Hips", 1.0]], 0.4)
	# pembe kısa kapüşonlu: göğüs altında biter
	var py: float = C - 0.15
	var hk := [P._kp(nk, N + 0.014, 0.036), [N - 0.05, ch.x * 1.08, ch.y * 0.99, ch.z * 1.08], P._kp(ch, C - 0.03, 0.045), P._kp(k.M(py, k.UA), py, 0.055)]
	var ff := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 5.0 + y * 17.0) * smoothstep(N - 0.02, C - 0.05, y) + 0.01 * smoothstep(py + 0.04, py, y) * (0.5 + 0.5 * sin(a * 7.0 + 0.3))
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 22, "na": 84, "top": func(_a): return N + 0.014, "hem": func(_a): return py, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.007, "inner": pk.darkened(0.38), "skin": tsk})
	var hm := []
	for p in hg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._bd(k, hm, 0.012, 0.003, pk.darkened(0.05), true, tsk)
	# verev bindirme kanadı: sol kanat boyundan sağ göğse iner, sonra dikey düşer
	var fk := []
	for e in hk:
		fk.append([e[0], float(e[1]) + 0.007, float(e[2]) + 0.007, float(e[3]) - 0.007])
	var y_e0: float = N + 0.008
	var edge := func(y: float) -> float: return lerpf(0.06, -0.36, smoothstep(0.0, 1.0, clampf((y_e0 - y) / (y_e0 - (C - 0.02)), 0.0, 1.0)))
	var fg: Dictionary = P._cl(k, {"keys": fk, "ny": 22, "na": 30, "rng": func(v): return Vector2(edge.call(lerpf(y_e0, py, float(v))), 1.05), "top": func(_a): return y_e0, "hem": func(_a): return py - 0.002,
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.005, "inner": pk.darkened(0.3), "skin": tsk})
	P._cord(k, fg["ea"], 0.0032, pk.darkened(0.14), false, tsk)
	# prenses dikişleri (önde iki, arkada iki) + omuz dikişi
	for a0 in [0.62, -0.62, PI - 0.5, -(PI - 0.5)]:
		Q._run(k, hk, ffw, [Vector2(a0 * 0.85, N - 0.02), Vector2(a0, C - 0.05), Vector2(a0, py + 0.02)], 0.0026, 0.0075 if absf(a0) < 1.0 else 0.002, 0.0018, pk.darkened(0.22), tsk, 6)
	# bağcık: sağ göğüste düğüm, iki beyaz ponpon + mor boncuk
	var kc: Array = Q._spt(fk, ffw, -0.36, C - 0.005, 0.013)
	var kpos: Vector3 = kc[0]
	var ko: Vector3 = kc[1]
	var cb: Array = k.torso_skin(C - 0.01)
	P._tb(k, [kpos + Vector3(0.012, 0.006, 0), kpos, kpos + Vector3(-0.012, -0.004, 0)], func(_s, _a): return 0.0045, func(_s, _a, _p): return lv.darkened(0.3), func(_s, _p): return cb, 8)
	for e in [[0.006, 0.05, wh, 0.0105], [-0.008, 0.062, wh, 0.0105], [0.0, 0.09, lv, 0.0065]]:
		var bp: Vector3 = kpos + Vector3(float(e[0]), -float(e[1]), 0) + ko * 0.006
		var hang := []
		for i in 5:
			var t := float(i) / 4.0
			hang.append(kpos.lerp(bp + Vector3(0, float(e[3]), 0), t) + ko * 0.004 * sin(t * PI))
		P._cord(k, hang, 0.0018, lv.darkened(0.35), false, func(_p): return cb)
		_ball(k, bp, float(e[3]), e[2], cb, 0.08 if e[2] == wh else 0.0)
	# kapüşon
	_hood_down(k, b, hk, pk, 0.36, 0.065)
	# kısa kol: geniş, katlı ağız
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.2 if sd == "Left" else 2.6
		var s1 := 0.4
		var sf := func(s: float, a: float) -> float:
			return 0.026 + 0.012 * smoothstep(0.05, s1, s) + 0.005 * P._lf(s, a, sv) * smoothstep(0.05, 0.2, s) + 0.008 * exp(-pow((s - 0.1) / 0.1, 2.0))
		P._lt(k, ar, sf, func(s, a, ins): return pk.darkened(0.42) if ins else P._fs(pk, float(sf.call(float(s), float(a))) - 0.03, 12.0), 0.0, s1, 16, 22, 0.03)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.003, func(s, _a, ins): return pk.darkened(0.4) if ins else pk.darkened(0.04 + 0.1 * float(absf(float(s) - s1 + 0.03) > 0.025)), s1 - 0.06, s1, 5, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.004, pk.darkened(0.35), s1 - 0.12, s1 - 0.003, 6, 22)
	P._cur_hem = H - 0.15


## Bıçak pleli kumaş profili: her plenin bir kenarı keskin basamak, diğeri yatık (pli sayısı n, yarım tur başına)
static func _pleat(a: float, n: float, amp: float) -> float:
	var u: float = fposmod(a * n / PI, 1.0)
	return amp * (u - 0.5) - amp * 0.5 * smoothstep(0.88, 1.0, u)


# ------------------------------------------------------------------ Murasaki Obi (ref Shinobi Striker "Hinata Outfit 4"): bıçak pleli kolsuz lavanta üst (dik yaka + orta fermuar, kısa kep omuz, yan koyu mor panel,
## obinin altında önden yırtmaçla iki kanada ayrılır), geniş koyu mor obi (üst bant + orta kat), kıvrık paçalı koyu mor şort, sağ uylukta beyaz sargı + siyah kılıf,
## uyluk ortasından dize gri şeffaf çorap, diz altında siyah çizme konçu
static func _mor_kemer(k) -> void:
	var lv := Color(0.8, 0.77, 0.92)
	var lp := Color(0.58, 0.5, 0.78)
	var ob := Color(0.25, 0.19, 0.33)
	var sh := Color(0.24, 0.18, 0.36)
	var wh := Color(0.93, 0.93, 0.94)
	var gy := Color(0.4, 0.37, 0.42)
	var bk := Color(0.1, 0.1, 0.12)
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
	var nsk := func(p): return Q._nsk(k, p)
	# şort + bacaklar
	var sk: Array = R._seat_keys(k, b)
	R._seat(k, sk, func(_i, _j, _p): return sh)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 1.9
		var s1: float = kn * 0.42
		var ad: Callable = R._short_leg(k, le, sh, s1, 0.02, 0.02, sv)
		R._hem_roll(k, le, ad, s1, sh.lightened(0.05), 0.04, 0.0045)
		var st0: float = kn * 0.66
		P._bare(k, le, skc, s1 - 0.08, st0 + 0.015)
		# gri şeffaf çorap: altından ten tonu sızar, üstte koyu bant
		var gs := func(s: float, a: float) -> float: return 0.0035 + 0.002 * smoothstep(st0 + 0.03, st0, s) + 0.0012 * sin(a * 3.0 + s * 30.0 + sv) * exp(-pow((s - kn) / 0.05, 2.0))
		var sheer: Color = gy.lerp(skc, 0.18)
		P._lt(k, le, gs, func(s, a, ins):
			if ins:
				return gy.darkened(0.3)
			if float(s) < st0 + 0.025:
				return bk.lightened(0.08)
			return sheer.darkened(0.16 * absf(sin(float(a))) + 0.1 * exp(-pow((float(s) - kn) / 0.05, 2.0))), st0, kn + 0.09, 18, 20)
		var bs: float = kn + 0.07
		var bt := func(s: float, a: float) -> float: return 0.008 + 0.004 * smoothstep(bs + 0.035, bs, s) + 0.0025 * sin(a * 3.0 + s * 26.0 + sv) * smoothstep(bs + 0.08, bs + 0.15, s) * smoothstep(0.97, 0.9, s)
		P._lt(k, le, bt, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.04), float(bt.call(float(s), float(a))) - 0.008, 14.0), bs, 0.99, 22, 20, 0.025)
		P._lt(k, le, func(s, a): return float(bt.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.1), bs, bs + 0.022, 2, 20)
		if sd == "Right":
			var s0: float = kn * 0.5
			for i in 3:
				var s: float = s0 + float(i) * 0.034
				k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + 0.006, 0.0155, 0.006, wh.darkened(0.05 * float(i % 2)), P._lskin(le, s))
			J._holster(k, le, func(_s, _a): return 0.0, bk.lightened(0.05), bk.lightened(0.02))
	# kollar: açık, kısa kep omuz
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		R._arm_skin(k, ar, 0.06)
		var sg: float = ar["sg"]
		var cp := func(s: float, a: float) -> float: return 0.012 + 0.01 * smoothstep(0.0, 0.1, s) + 0.004 * maxf(0.0, sin(a) * sg)
		P._lt(k, ar, cp, func(_s, _a, ins): return lv.darkened(0.35) if ins else lv, 0.0, 0.11, 6, 22, 0.025)
		P._lt(k, ar, func(s, a): return float(cp.call(s, a)) + 0.002, func(_s, _a, ins): return lv.darkened(0.35) if ins else lv.darkened(0.12), 0.092, 0.111, 2, 22)
	# üst: bıçak pleli, obinin altında önden ayrılır
	var hem: float = H - 0.12
	var uk := [P._kp(nk, N + 0.012, 0.024), [N - 0.045, ch.x * 1.06, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.022), P._kp(hp, H - 0.03, 0.045), [hem, hp.x + 0.06, hp.y + 0.06, hp.z - 0.055]]
	var pf := func(a: float, y: float) -> float:
		var p0: float = _pleat(a, 9.0, 0.03)
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		return p0 * (0.6 + 0.4 * t) + t * 0.02 * sin(a * 3.0 + 0.4)
	var colf := func(a: float, _y: float, _v: float) -> Color:
		var aw: float = absf(float(a))
		return lp if aw > 1.3 and aw < 1.95 else lv
	var top_y: float = N + 0.012
	var mid: float = H + 0.02
	var usk := func(p): return _msk(k, p, hem)
	P._cl(k, {"keys": uk, "ny": 34, "na": 126, "top": func(_a): return top_y, "hem": func(_a): return mid, "fold": func(a, y, _v): return pf.call(float(a), float(y)),
		"col": colf, "gain": 4.0, "th": 0.005, "inner": lv.darkened(0.35), "skin": usk})
	var lg: Dictionary = P._cl(k, {"keys": uk, "ny": 14, "na": 126, "rng": func(v): return Vector2(0.045 + 0.05 * float(v), TAU - 0.045 - 0.05 * float(v)), "top": func(_a): return mid + 0.03, "hem": func(_a): return hem,
		"fold": func(a, y, _v): return pf.call(float(a), float(y)), "col": colf, "gain": 4.0, "th": 0.005, "inner": lv.darkened(0.35), "skin": usk})
	var hm := []
	for p in lg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hm, 0.004, 0.0018, lv.darkened(0.14), false, usk)
	for ed in [lg["ea"], lg["eb"]]:
		P._cord(k, ed, 0.003, lv.darkened(0.1), false, usk)
	var pfw := func(a, y): return pf.call(float(a), float(y))
	# yan panel dikişleri + orta fermuar dikişi
	for sg in [1.0, -1.0]:
		for a0 in [1.3, 1.95]:
			Q._run(k, uk, pfw, [Vector2(sg * a0, N - 0.06), Vector2(sg * a0, C - 0.1), Vector2(sg * a0, hem + 0.01)], 0.0024, 0.003, 0.0016, lp.darkened(0.2), usk, 8)
	Q._run(k, uk, pfw, [Vector2(0.0, N + 0.005), Vector2(0.0, mid + 0.02)], 0.0028, 0.004, 0.002, lv.darkened(0.3), usk, 8)
	# dik yaka
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + 0.075 * q, 0.012, 0.016), P._kp(nk, N + 0.03 * q, 0.016), P._kp(nk, N - 0.02, 0.026)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.06, TAU - 0.06), "top": func(_a): return N + 0.07 * q, "hem": func(_a): return N - 0.012,
		"fold": func(a, _y, _v): return 0.004 * sin(float(a) * 3.0), "col": func(_a, _y, _v): return lv, "gain": 4.0, "th": 0.006, "inner": lp, "skin": nsk})
	P._cord(k, cg["top"], 0.0036, lv.darkened(0.06), false, nsk)
	for e in [cg["ea"], cg["eb"]]:
		P._cord(k, e, 0.0032, lv.darkened(0.12), false, nsk)
	# obi: geniş koyu mor; üstte ince bant, ortada kat izi; arkada katlı düğüm
	var ok := []
	for e in uk:
		if float(e[0]) < N - 0.03 and float(e[0]) > hem:
			ok.append([e[0], float(e[1]) + 0.02, float(e[2]) + 0.022, float(e[3]) - 0.022])
	var oy0: float = C - 0.1
	var oy1: float = H + 0.035
	var og: Dictionary = P._cl(k, {"keys": ok, "ny": 12, "na": 96, "top": func(_a): return oy0, "hem": func(_a): return oy1, "fold": func(a, y, _v):
		return 0.012 * sin(clampf((oy0 - float(y)) / (oy0 - oy1), 0.0, 1.0) * PI) - 0.008 * exp(-pow((float(y) - (oy0 + oy1) * 0.5) / 0.006, 2.0)) + 0.003 * sin(float(a) * 5.0),
		"col": func(_a, _y, _v): return ob, "gain": 6.0, "th": 0.006, "inner": ob.darkened(0.3), "skin": tsk})
	P._cord(k, og["top"], 0.004, ob.lightened(0.08), true, tsk)
	P._cord(k, og["hem"], 0.004, ob.lightened(0.04), true, tsk)
	var by: float = (oy0 + oy1) * 0.5
	var bp: Array = Q._spt(ok, Callable(), PI, by, 0.02)
	var bo2: Array = k.torso_skin(by)
	var bpo: Vector3 = bp[1]
	P._boxr(k, bp[0], Vector3(0.045, 0, 0), Vector3(0, 0.028, 0), bpo * 0.012, ob.lightened(0.04), bo2, 0.45)
	P._boxr(k, (bp[0] as Vector3) + bpo * 0.011, Vector3(0.016, 0, 0), Vector3(0, 0.031, 0), bpo * 0.006, ob.darkened(0.12), bo2, 0.4)
	P._cur_hem = hem


# ------------------------------------------------------------------ Momo Sētā (ref Shinobi Striker "Hinata Outfit 5"): gri uzun kollu iç gömlek (boyunda görünen gri yaka), kayık yakalı pembe örgü kazak (örgü sütunları ve
## sıraları geometride, kısa kol ağzında ve bel ribanasında beyaz-pembe şeritler), belden diz altına inen A kesim gri etek (pembe bel bandı, ortada ve uçta iki pembe kabartma şerit),
## baldır ortasında biten koyu gri kapri, açık bilek
## Momo uzun etek ağırlığı (Matsuri / Hime hakama yolu): önde uyluğu izler ama dizin altında kendi yanındaki baldıra yarı yarıya geçer
## (öne kalkan diz eteğin önünü levha gibi kaldırmaz, kumaş dizden aşağı sarkar), iki bacak arası geniş geçiş, uçta ağırlık biraz düşer;
## arkada ağırlık yavaş artar, diz altında baldırı izler (geri giden topuk arka eteği delmez)
static func _kzsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.04, -0.07, p.z)
	var wf: float = 0.99 * pow(minf(1.0, t / 0.35), 0.4) * lerpf(1.0, 0.9, smoothstep(0.75, 1.0, t))
	var wb: float = lerpf(0.84 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8)), 0.93, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.05, 0.1, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kbf: float = smoothstep(k.K - 0.015, k.K - 0.13, p.y) * 0.6   # önde diz kapağının altından başlar: dizin önündeki kumaş uylukta kalır (diz delmez)
	var kbb: float = smoothstep(k.K + 0.06, k.K - 0.1, p.y) * 0.62
	var kb: float = lerpf(kbf, kbb, bk) * smoothstep(0.0, 0.6, absf(2.0 * s - 1.0))
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


static func _pembe_kazak(k) -> void:
	var pk := Color(0.92, 0.72, 0.8)
	var gy := Color(0.42, 0.42, 0.45)
	var sg_c := Color(0.86, 0.85, 0.86)
	var pkl := Color(0.78, 0.5, 0.62)
	var wh := Color(0.95, 0.94, 0.95)
	var cp := Color(0.23, 0.22, 0.28)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var K0: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# gri iç gömlek + yaka
	var ik: Array = P._inner(k, b, func(_i, _j, _p): return gy, 0.006, H - 0.02)
	var nr := []
	for i in 40:
		nr.append(Q._spt(ik, Callable(), TAU * i / 40.0 - PI, N + 0.04, 0.004)[0])
	P._cord(k, nr, 0.005, gy.lightened(0.05), true, nsk)
	K._seat(k, b, cp)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.4 if sd == "Left" else 1.3
		var en: float = ar["kn"]
		var af := func(s: float, a: float) -> float:
			return 0.008 + 0.003 * P._lf(s, a, sv) * smoothstep(0.35, 0.5, s) + 0.007 * exp(-pow((s - en) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.9) / 0.05, 2.0)) * (0.5 + 0.5 * sin(a * 5.0 + sv)) - 0.003 * smoothstep(0.93, 0.99, s)
		P._lt(k, ar, af, func(s, a, ins): return gy.darkened(0.35) if ins else P._fs(gy, float(af.call(float(s), float(a))) - 0.009, 12.0), 0.0, 0.985, 32, 18, 0.02)
	# kapri: baldır ortasında biter, dizde kırışık
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		var s1: float = kn + (1.0 - kn) * 0.5
		var pa := func(s: float, a: float) -> float:
			return 0.012 + 0.006 * exp(-pow((s - kn + 0.08) / 0.15, 2.0)) - 0.004 * smoothstep(s1 - 0.1, s1, s) + 0.006 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.003 * P._lf(s, a, sv)
		P._lt(k, le, pa, func(s, a, ins): return cp.darkened(0.4) if ins else P._fs(cp, float(pa.call(float(s), float(a))) - 0.013, 12.0), 0.0, s1, 36, 20, 0.02)
		P._lt(k, le, func(s, a): return float(pa.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return cp.darkened(0.4) if ins else cp.lightened(0.05), s1 - 0.03, s1, 3, 20)
		P._bare(k, le, Q._skc(k), s1 - 0.03, 1.0)
	# A kesim uzun etek
	var hem: float = K0 - 0.13
	var ek := [P._kp(k.M(H + 0.075, 0.3), H + 0.075, 0.016), P._kp(hp, H - 0.04, 0.035), [K0 + 0.1, hp.x + 0.08, hp.y + 0.075, hp.z - 0.075], [hem, hp.x + 0.11, hp.y + 0.1, hp.z - 0.095]]
	var esk := func(p): return _kzsk(k, p, hem)
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.03 * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 12.0 + 1.9)) + 0.005 * sin(a * 16.0) * (1.0 - t) * smoothstep(H + 0.07, H - 0.02, y)
	var efw := func(a, y): return ef.call(float(a), float(y))
	var eg: Dictionary = P._cl(k, {"keys": ek, "ny": 40, "na": 96, "top": func(_a): return H + 0.075, "hem": func(_a): return hem, "fold": func(a, y, _v): return ef.call(float(a), float(y)),
		"col": func(_a, _y, _v): return sg_c, "gain": 6.0, "th": 0.006, "inner": sg_c.darkened(0.35), "skin": esk})
	for yy in [K0 + 0.045, hem + 0.07, hem + 0.035]:
		var rp := []
		for i in 96:
			rp.append(Q._spt(ek, efw, TAU * i / 96.0 - PI, yy, 0.0035)[0])
		P._bd(k, rp, 0.0045, 0.0022, pkl, true, esk)
	var hm := []
	for p in eg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hm, 0.0035, 0.0018, sg_c.darkened(0.12), true, esk)
	# bel bandı: pembe, iki beyaz çizgi
	var wbk := [P._kp(k.M(H + 0.1, 0.3), H + 0.1, 0.022), P._kp(k.M(H + 0.05, 0.3), H + 0.05, 0.024)]
	P._sash(k, wbk, H + 0.075, 0.016, 0.006, pkl.lightened(0.1), 0.06)
	for dy in [-0.007, 0.007]:
		P._bd(k, P._ring_pts(wbk, H + 0.075 + dy, 0.0175, 72), 0.0022, 0.0014, wh, true, tsk)
	# örgü kazak: kayık yaka, belde ribana; örgü sütunları (gerçek kabartma) ve sıra izleri
	var ky: float = H + 0.1
	var kk := [P._kp(nk, N + 0.0, 0.05, 0.04), [N - 0.045, ch.x * 1.08, ch.y * 0.98, ch.z * 1.06], P._kp(ch, C - 0.03, 0.035), P._kp(wa, H + 0.12, 0.04), P._kp(k.M(ky, k.UA), ky, 0.034)]
	var nc := 44.0
	var rowp := 0.017
	var knit := func(a: float, y: float) -> float:
		var xc: float = fposmod(a / TAU * nc, 1.0) * 2.0 - 1.0
		var col: float = pow(1.0 - absf(xc), 0.7)
		var v: float = fposmod(y / rowp + absf(xc) * 0.5, 1.0)
		return 0.0065 * col + 0.0035 * sin(v * PI) * col - 0.004
	var kf := func(a: float, y: float) -> float:
		return knit.call(a, y) * 1.0 + 0.01 * sin(a * 4.0 + y * 13.0) * smoothstep(C - 0.02, ky, y)
	var kcol := func(a: float, y: float) -> Color:
		var v: float = float(knit.call(a, y))
		return pk.darkened(clampf(-v * 40.0, 0.0, 0.22)).lightened(clampf(v * 12.0, 0.0, 0.05))
	var kg: Dictionary = P._cl(k, {"keys": kk, "ny": 52, "na": 160, "top": func(a): return N - 0.01 - 0.02 * exp(-pow(float(a) / 0.7, 2.0)), "hem": func(_a): return ky,
		"fold": func(a, y, _v): return kf.call(float(a), float(y)), "col": func(a, y, _v): return kcol.call(float(a), float(y)), "gain": 0.0, "th": 0.0, "skin": tsk})
	P._cord(k, kg["top"], 0.0055, pk.darkened(0.06), true, nsk)
	# bel ribanası: dikey ribana + iki beyaz şerit
	var rbk := [P._kp(k.M(ky, k.UA), ky + 0.004, 0.036), P._kp(k.M(ky - 0.04, k.UA), ky - 0.04, 0.032)]
	P._cl(k, {"keys": rbk, "ny": 6, "na": 132, "top": func(_a): return ky + 0.004, "hem": func(_a): return ky - 0.04, "fold": func(a, _y, _v): return 0.014 * absf(sin(float(a) * 33.0)) - 0.007,
		"col": func(_a, y, _v): return wh if absf(float(y) - (ky - 0.012)) < 0.006 or absf(float(y) - (ky - 0.03)) < 0.004 else pk, "gain": 8.0, "th": 0.006, "inner": pk.darkened(0.4), "skin": tsk})
	# kısa kol: örgü, ağızda beyaz-pembe şeritli ribana
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.9 if sd == "Left" else 2.0
		var s1 := 0.44
		var sf := func(s: float, a: float) -> float:
			var xc: float = fposmod((a + PI) / TAU * 22.0, 1.0) * 2.0 - 1.0
			var cl: float = pow(1.0 - absf(xc), 0.7)
			var v: float = fposmod(s * 0.3 / rowp + absf(xc) * 0.5, 1.0)
			return 0.024 + 0.008 * smoothstep(0.05, s1, s) + 0.006 * exp(-pow((s - 0.1) / 0.1, 2.0)) + 0.005 * cl + 0.003 * sin(v * PI) * cl + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sf, func(s, a, ins):
			if ins:
				return pk.darkened(0.42)
			var xc: float = fposmod((float(a) + PI) / TAU * 22.0, 1.0) * 2.0 - 1.0
			return pk.darkened(0.18 * smoothstep(0.55, 1.0, absf(xc))), 0.0, s1 - 0.06, 20, 88, 0.0)
		var cf := func(s: float, a: float) -> float: return 0.034 + 0.008 * smoothstep(0.05, s1, s) + 0.007 * absf(sin(a * 22.0)) + 0.002
		P._lt(k, ar, cf, func(s, _a, ins):
			if ins:
				return pk.darkened(0.4)
			var d: float = float(s) - (s1 - 0.06)
			return wh if (d > 0.012 and d < 0.024) or (d > 0.036 and d < 0.044) else pk, s1 - 0.065, s1, 10, 44, 0.03)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.006, pk.darkened(0.35), s1 - 0.1, s1 - 0.004, 5, 22)
	P._cur_hem = hem


# ------------------------------------------------------------------ Himawari Fūdo (ref Shinobi Striker "Himawari Outfit"): uyluğa inen bol sarı kapüşonlu (düşük omuz, kanguru cebi, metal uçlu büzgü ipleri,
## ribanalı etek ucu ve elin üstüne inen katlı manşetli kol, boyna düşmüş kapüşon), altında açık mavi gömlek (boyunda sivri yaka, kapüşonun altından taşan dişli etek ucu),
## kırmızı astar üstünde iki kat pembe fırfırlı mini etek (üst katta kırmızıyı gösteren V kesikler), diz üstü siyah çorap
static func _gunebakan(k) -> void:
	var yl := Color(0.96, 0.85, 0.56)
	var bl := Color(0.74, 0.88, 0.93)
	var pk := Color(0.93, 0.6, 0.7)
	var rd := Color(0.86, 0.2, 0.25)
	var sk := Color(0.1, 0.1, 0.12)
	var mt := Color(0.62, 0.6, 0.56)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	# açık mavi gömlek: boyundan kalçaya; boyunda öne sivrilen yaka
	P._inner(k, b, func(_i, _j, _p): return bl, 0.008, H + 0.0)
	K._seat(k, b, rd.darkened(0.35))
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + 0.05 * q, 0.012, 0.016), P._kp(nk, N + 0.015, 0.018), P._kp(nk, N - 0.03, 0.03)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 48, "top": func(_a): return N + 0.05 * q, "hem": func(a): return N - 0.012 - 0.05 * exp(-pow(float(a) / 0.42, 2.0)),
		"fold": func(_a, _y, _v): return 0.0, "col": func(_a, _y, _v): return bl, "gain": 4.0, "th": 0.004, "inner": bl.darkened(0.25), "skin": nsk})
	P._cord(k, cg["top"], 0.003, bl.darkened(0.06), true, nsk)
	# dişli gömlek ucu: kapüşonlunun altından taşar
	var zk := [P._kp(hp, H + 0.02, 0.04), P._kp(hp, H - 0.05, 0.088), [H - 0.18, hp.x + 0.135, hp.y + 0.128, hp.z - 0.122]]
	var zhem := func(a: float) -> float: return H - 0.16 + 0.045 * _teeth(a, 9.0, 0.5)
	var zg: Dictionary = P._cl(k, {"keys": zk, "ny": 10, "na": 90, "top": func(_a): return H + 0.02, "hem": func(a): return zhem.call(float(a)),
		"fold": func(a, y, _v): return 0.006 * sin(float(a) * 9.0) * clampf((H - float(y)) / 0.12, 0.0, 1.0), "col": func(_a, _y, _v): return bl, "gain": 5.0, "th": 0.004, "inner": bl.darkened(0.3),
		"skin": func(p): return _msk(k, p, H - 0.18)})
	P._cord(k, zg["hem"], 0.0022, bl.darkened(0.08), true, func(p): return _msk(k, p, H - 0.18))
	# etek: kırmızı astar + iki kat pembe fırfır
	var hem2: float = H - 0.27
	var ek := [P._kp(wa, H + 0.04, 0.02), P._kp(hp, H - 0.04, 0.05), [hem2, hp.x + 0.105, hp.y + 0.1, hp.z - 0.095]]
	var msk := func(p): return _msk(k, p, hem2)
	var ruf := func(a: float, y: float, amp: float) -> float:
		var t: float = clampf((H - y) / (H - hem2), 0.0, 1.0)
		return t * t * amp * (sin(a * 13.0 + 0.4) * 0.7 + 0.3 * sin(a * 23.0 + 1.1))
	P._cl(k, {"keys": ek, "ny": 16, "na": 84, "top": func(_a): return H + 0.04, "hem": func(_a): return hem2 + 0.035, "fold": func(a, y, _v): return ruf.call(float(a), float(y), 0.03) - 0.04,
		"col": func(_a, _y, _v): return rd, "gain": 6.0, "th": 0.004, "inner": rd.darkened(0.35), "skin": msk})
	var t2k := []
	for e in ek:
		t2k.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.012, float(e[3]) - 0.012])
	var sc := func(a: float) -> float: return 0.012 * (1.0 - pow(_teeth(a, 14.0, 0.0), 2.0))
	var g2: Dictionary = P._cl(k, {"keys": t2k, "ny": 10, "na": 100, "top": func(_a): return H - 0.13, "hem": func(a): return hem2 + float(sc.call(float(a))),
		"fold": func(a, y, _v): return ruf.call(float(a), float(y), 0.05), "col": func(_a, _y, _v): return pk, "gain": 5.0, "th": 0.005, "inner": pk.darkened(0.3), "skin": msk})
	P._cord(k, g2["hem"], 0.003, pk.lightened(0.06), true, msk)
	var t1k := []
	for e in ek:
		t1k.append([e[0], float(e[1]) + 0.022, float(e[2]) + 0.022, float(e[3]) - 0.022])
	var h1 := H - 0.2
	var vn := func(a: float) -> float:   # V kesik: kesik ortasında kumaş belden biraz aşağıda biter, kırmızı astar görünür
		var d: float = _teeth(a, 7.0, 0.5)
		return pow(maxf(0.0, (d - 0.62) / 0.38), 1.3)
	var g1: Dictionary = P._cl(k, {"keys": t1k, "ny": 14, "na": 120, "top": func(_a): return H + 0.035, "hem": func(a): return h1 + 0.12 * float(vn.call(float(a))),
		"fold": func(a, y, _v): return ruf.call(float(a), float(y), 0.04) * (H - h1) / (H - hem2), "col": func(_a, _y, _v): return pk, "gain": 5.0, "th": 0.005, "inner": pk.darkened(0.3), "skin": msk})
	P._cord(k, g1["hem"], 0.003, pk.lightened(0.08), true, msk)
	# bacaklar: açık uyluk, diz üstü siyah çorap
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_sock_leg(k, le, sk, float(le["kn"]) * 0.8, 0.6 if sd == "Left" else 1.7, 0.025)
	# kapüşonlu gövde: düşük omuz, bol kutu kesim, uçta ribana toplanır
	var hy: float = H - 0.05
	var box: float = maxf(wa.x + 0.065, ch.x * 1.0)
	var hk := [P._kp(nk, N + 0.014, 0.032), [N - 0.05, ch.x * 1.1, ch.y * 0.98, ch.z * 1.08], P._kp(ch, C - 0.03, 0.05), [H + 0.12, box, maxf(wa.y + 0.06, ch.y * 0.95), minf(wa.z - 0.06, ch.z * 0.96)],
		[H + 0.0, maxf(box, hp.x + 0.07), hp.y + 0.075, hp.z - 0.07], [hy, hp.x + 0.06, hp.y + 0.062, hp.z - 0.06]]
	var vt := func(a: float) -> float: return lerpf(N - 0.035, N + 0.014, smoothstep(0.0, 0.42, absf(a)))
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - 0.02 - y) / (C - 0.02 - hy), 0.0, 1.0)
		var blouse: float = 0.03 * smoothstep(H + 0.06, H - 0.01, y) * smoothstep(hy - 0.01, hy + 0.035, y)
		return t * (0.02 * sin(a * 5.0 + 0.5) + 0.009 * sin(a * 11.0 + 1.7)) + (1.0 - t) * 0.006 * sin(a * 4.0 + y * 19.0) * smoothstep(N - 0.02, C - 0.05, y) + blouse
	var hsk := func(p): return _msk(k, p, H - 0.15)
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 40, "na": 92, "top": func(a): return vt.call(float(a)), "hem": func(_a): return hy, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return yl, "gain": 6.0, "th": 0.006, "inner": yl.darkened(0.4), "skin": hsk})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# ribanalı etek bandı: bedene toplanır
	var rk := [[hy + 0.006, hp.x + 0.052, hp.y + 0.055, hp.z - 0.052], [hy - 0.05, hp.x + 0.046, hp.y + 0.05, hp.z - 0.046]]
	P._cl(k, {"keys": rk, "ny": 5, "na": 96, "top": func(_a): return hy + 0.006, "hem": func(_a): return hy - 0.05, "fold": func(a, _y, _v): return 0.012 * absf(sin(float(a) * 36.0)) - 0.006,
		"col": func(_a, _y, _v): return yl.darkened(0.04), "gain": 9.0, "th": 0.006, "inner": yl.darkened(0.4), "skin": hsk})
	# V yaka kenarı
	var ve := []
	for p in hg["top"]:
		ve.append(p)
	P._cord(k, ve, 0.0042, yl.darkened(0.05), true, nsk)
	# kanguru cebi: üstü dar, altı geniş; yanlarda eğik el ağzı
	var py: float = H + 0.07
	var mp: Callable = Q._local(hk, ffw, 0.0, py)
	var po: Vector3 = Q._spt(hk, ffw, 0.0, py)[1]
	var pw0 := 0.085
	var pw1 := 0.125
	var ph := 0.068
	var rows := []
	for j in 11:
		var v := float(j) / 10.0
		var hw: float = lerpf(pw0, pw1, smoothstep(0.0, 0.6, v))
		var ro := []
		for i in 15:
			var u := float(i) / 14.0
			var ed: float = minf(minf(u, 1.0 - u) * hw * 2.0, minf(v, 1.0 - v) * ph * 2.0)
			ro.append(mp.call((u - 0.5) * 2.0 * hw, ph - v * ph * 2.0, -0.001 + 0.009 * smoothstep(0.0, 0.016, ed) + 0.003 * sin(u * PI) * sin(v * PI)))
		rows.append(ro)
	Q._mesh(k, rows, false, func(i, j, _p):
		var e3: float = minf(minf(float(i) / 14.0, 1.0 - float(i) / 14.0), minf(float(j) / 10.0, 1.0 - float(j) / 10.0))
		return yl.darkened(0.16) if e3 < 0.06 else yl, func(_i, _j, p): return hsk.call(p), po)
	for sg in [1.0, -1.0]:
		var mo := []
		for i in 9:
			var t := float(i) / 8.0
			mo.append(mp.call(sg * lerpf(pw0 - 0.004, pw1 - 0.006, smoothstep(0.0, 0.6, lerpf(0.05, 0.62, t))), lerpf(ph * 0.9, -ph * 0.25, t), 0.0105))
		P._cord(k, mo, 0.003, yl.darkened(0.22), false, hsk)
	# büzgü ipleri: boyundaki iki kuşgözünden göğse, metal uçlu
	for sg in [1.0, -1.0]:
		var e0: Array = Q._spt(hk, ffw, sg * 0.2, N - 0.022, 0.006)
		P._stud(k, e0[0], e0[1], 0.005, mt, k.torso_skin(N - 0.022))
		var cp := []
		for i in 12:
			var t := float(i) / 11.0
			cp.append(Q._spt(hk, ffw, sg * (0.2 + 0.03 * sin(t * 2.5)), lerpf(N - 0.026, C - 0.075, t), 0.0085)[0])
		P._cord(k, cp, 0.0028, yl.darkened(0.42), false, tsk)
		var ce: Vector3 = cp[11]
		P._tb(k, [ce, ce + Vector3(0, -0.016, 0.001)], func(_s, _a): return 0.0034, func(_s, _a, _p): return mt, func(_s, _p): return k.torso_skin(C - 0.08), 6)
	# yan dikiş + omuz dikişi (düşük omuz)
	for sg in [1.0, -1.0]:
		Q._run(k, hk, ffw, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, H), Vector2(sg * PI * 0.5, hy + 0.005)], 0.0026, 0.002, 0.0016, yl.darkened(0.2), hsk, 8)
	# kapüşon
	_hood_down(k, b, hk, yl, 0.3, 0.075)
	# kollar: bol, elin üstüne inen katlı manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		_sleeve(k, ar, yl, 0.024, 0.016, 1.0, 0.9 if sd == "Left" else 2.1, 0.11, yl.darkened(0.03), 0.004)
	P._cur_hem = hem2
