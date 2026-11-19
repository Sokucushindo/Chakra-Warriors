extends RefCounted
## Elle modellenmiş setler, parti o: set_mizukage, set_raikage, set_tsuchikage, set_anbu_konoha, set_anbu_kaptan, set_anbu_yami. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e'den (P), uzuv kabuğu / eldiven / pantolon parti k'den (K), sarmal kimono / geniş kol / pelerin ağırlığı parti m'den (M).
## Burada: Kage cübbesi (açık önlü uzun haori, gerçek etek bandı, sırtta kanji), hakama, kas gövde, ANBU zırh biçimleri, kaptan pelerini.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const D = preload("res://scripts/actors/set_v2_d.gd")

const DONE := ["set_mizukage", "set_raikage", "set_tsuchikage", "set_anbu_konoha", "set_anbu_kaptan", "set_anbu_yami"]


static func recipe(k, sid: String) -> void:
	P._cur_long = false
	P._cur_leg = 0.58
	match sid:
		"set_mizukage": _kage(k, true)
		"set_raikage": _raikage(k)
		"set_tsuchikage": _kage(k, false)
		"set_anbu_konoha": _gece(k)
		"set_anbu_kaptan": _kaptan(k)
		"set_anbu_yami": _yami(k)


# ------------------------------------------------------------------ yardımcılar
static func _skin_c(k) -> Color:
	return k.m.look.get("skin", Color(0.9, 0.72, 0.58))


static func _fem(k) -> bool:
	return String(k.m.look.get("gender", "m")) == "f"


## Noktanın uzuv boyundaki yeri (0 kök, 1 uç): uzuv üstüne binen şeritlerin ağırlığı için
static func _sproj(l: Dictionary, p: Vector3) -> float:
	var p0: Vector3 = l["p0"]
	var p1: Vector3 = l["p1"]
	var p2: Vector3 = l["p2"]
	var kn: float = l["kn"]
	var t0: float = clampf((p - p0).dot(p1 - p0) / (p1 - p0).length_squared(), 0.0, 1.0)
	var t1: float = clampf((p - p1).dot(p2 - p1) / (p2 - p1).length_squared(), 0.0, 1.0)
	var d0: float = (p - p0.lerp(p1, t0)).length()
	var d1: float = (p - p1.lerp(p2, t1)).length()
	return t0 * kn if d0 < d1 else lerpf(kn, 1.0, t1)


## Uzun açık cübbe ağırlığı. Belden yukarı gövde (omuz kanatları üst kolu izler). Ön kanatlar bacağı çabuk izler; arka ağırlık boy boyunca yavaş artar
## ve iki bacak arasında geniş geçer: geri giden bacak arka eteği kalçaya doğru ezmez, kumaş uzayarak iner. Uçta ağırlık biraz düşer (etek çan gibi açılmaz).
static func _robe_skin(k, p: Vector3, hem: float, wd: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return _upper_skin(k, p, wd)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.95 * pow(minf(1.0, t / 0.5), 0.45) * lerpf(1.0, 0.88, smoothstep(0.6, 1.0, t))
	var wb: float = 0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.012, 0.12, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.16, p.y) * bk * absf(2.0 * s - 1.0) * 0.45
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Kollu üst giysinin gövde ağırlığı: yalnız omuz dikişi çevresi kolu biraz izler (kol savrulunca kol altı gövdeden ayrılıp delik açmaz)
static func _upper_skin(k, p: Vector3, wd: float) -> Array:
	var ts: Array = k.torso_skin(maxf(p.y, k.H + 0.02))
	var sx: float = smoothstep(0.78, 1.0, absf(p.x) / wd) * smoothstep(k.N + 0.02, k.C - 0.01, p.y) * (1.0 - smoothstep(k.C - 0.04, k.C - 0.1, p.y)) * 0.3
	if sx <= 0.0:
		return ts
	var res := []
	for e: Array in ts:
		res.append([e[0], float(e[1]) * (1.0 - sx)])
	res.append([("Left" if p.x > 0.0 else "Right") + "UpperArm", sx])
	return res


## Kage cübbesi: açık önlü, baldıra inen beyaz haori. o: keys, hem, wd, e(y) ön açıklık, col, lin (astar), c2 (köy rengi), bh (etek bandı boyu), glyph, ny, na
## Döner: pt(a, y) yüzey noktası, skin(p), rows
static func _cloak(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var hem: float = o["hem"]
	var wd: float = o["wd"]
	var ef: Callable = o["e"]
	var wh: Color = o["col"]
	var c2: Color = o["c2"]
	var bh: float = o["bh"]
	var H: float = k.H
	var N: float = k.N
	var C: float = k.C
	var top: float = keys[0][0]
	var skin := func(p: Vector3) -> Array: return _robe_skin(k, p, hem, wd)
	var fold := func(a: float, y: float, _v: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var e: float = ef.call(y)
		var fe: float = smoothstep(e + 0.18, e + 0.55, aw)
		var t: float = clampf((H + 0.04 - y) / (H + 0.04 - hem), 0.0, 1.0)
		var bk: float = smoothstep(1.3, 2.3, aw)
		var sk: float = pow(t, 0.9) * ((0.048 + 0.016 * bk) * sin(a * 7.0 + 0.6) + 0.02 * sin(a * 13.0 + 1.9))
		var flat: float = 1.0 - exp(-pow((aw - PI) / 0.45, 2.0)) * smoothstep(H - 0.02, H + 0.1, y)
		var up: float = (1.0 - t) * 0.007 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.02, C - 0.06, y) * flat
		return fe * (sk + up)
	var pt := func(a: float, y: float) -> Vector3:
		var s: Array = SE.El.key_at(keys, y)
		var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
		var f: float = 1.0 + float(fold.call(a, y, 0.0))
		return Vector3(q.x * f, y, q.y * f)
	var rng := func(v: float) -> Vector2:
		var e: float = ef.call(lerpf(top, hem, v))
		return Vector2(e, TAU - e)
	var g: Dictionary = P._cl(k, {"keys": keys, "ny": o.get("ny", 46), "na": o.get("na", 84), "rng": rng, "top": func(_a: float) -> float: return top,
		"hem": func(_a: float) -> float: return hem, "fold": fold, "col": func(_a: float, _y: float, _v: float) -> Color: return wh, "inner": o["lin"], "skin": skin, "th": 0.006, "gain": 5.5})
	# etek bandı: kumaşın üstüne dikili ikinci kat (boya değil), üstünde ince biye
	var rng_b := func(v: float) -> Vector2:
		var e: float = ef.call(lerpf(hem + bh, hem, v))
		return Vector2(e, TAU - e)
	P._cl(k, {"keys": keys, "ny": 5, "na": o.get("na", 84), "rng": rng_b, "top": func(_a: float) -> float: return hem + bh, "hem": func(_a: float) -> float: return hem - 0.003,
		"fold": fold, "col": func(_a: float, _y: float, _v: float) -> Color: return c2, "inner": c2.darkened(0.3), "skin": skin, "th": 0.004, "gain": 4.0, "lift": 0.0032})
	var e_h: float = ef.call(hem + bh)
	var pip := []
	for i in 85:
		pip.append(pt.call(lerpf(e_h + 0.01, TAU - e_h - 0.01, float(i) / 84.0), hem + bh + 0.008))
	P._bd(k, pip, 0.0042, 0.0042, c2.lightened(0.22), false, skin)
	# arka orta dikiş
	var bs := []
	var y := N - 0.0
	while y > hem + bh + 0.01:
		bs.append(pt.call(PI, y))
		y -= 0.03
	var bo := []
	for p: Vector3 in bs:
		bo.append(Vector3(0, 0, -1))
	k.strip(bs, bo, 0.0028, 0.0018, wh.darkened(0.14), false, skin)
	# sırtta köy kanjisi
	P._glyph(k, keys, 0.0, C - 0.075, 0.075, o["glyph"], 0.0085, c2, false, 0.0045)
	return {"pt": pt, "skin": skin, "g": g, "fold": fold}


## Cübbenin ön kenarı + ense: kumaşı saran kalın şerit (hem ile top arası)
static func _edge_band(k, g: Dictionary, skin: Callable, hw: float, col: Color, up_top := 0.35) -> void:
	var ea: Array = g["ea"]
	var eb: Array = g["eb"]
	var tp: Array = g["top"]
	var pts := []
	var ou := []
	for i in range(ea.size() - 1, 0, -1):
		var p: Vector3 = ea[i]
		pts.append(p + Vector3(0.006, 0.0, 0.0))
		ou.append(Vector3(p.x, 0.0, p.z).normalized())
	for i in range(0, tp.size(), 2):
		var p: Vector3 = tp[i]
		pts.append(p + Vector3(0, -hw * 0.55, 0))
		ou.append(Vector3(p.x, up_top, p.z).normalized())
	for i in range(1, eb.size()):
		var p: Vector3 = eb[i]
		pts.append(p + Vector3(-0.006, 0.0, 0.0))
		ou.append(Vector3(p.x, 0.0, p.z).normalized())
	k.strip(pts, ou, hw, 0.0052, col, false, skin)


## Hakama: belde katlı kuşak bölümü, arkada sert koshi-ita, iki geniş pileli paça, önde bağ
static func _hakama(k, b: Dictionary, col: Color, tie: Color) -> void:
	var H: float = k.H
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var hk := [P._kp(wa, H + 0.1, 0.026), P._kp(wa, H + 0.03, 0.032), P._kp(hp, H - 0.05, 0.046), [H - 0.17, hp.x + 0.05, hp.y + 0.056, hp.z - 0.06]]
	var hf := func(a: float, y: float, _u: float) -> float: return smoothstep(H + 0.03, H - 0.13, y) * 0.032 * sin(a * 8.0 + 0.3)
	P._sheet(k, hk, 16, 64, Callable(), hf, func(a: float, y: float, _u: float, _v: float, _p: Vector3) -> Color: return P._fs(col, float(hf.call(a, y, 0.0)), 6.0), 0.006, 0.3)
	for sd: String in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = 1.0 if sd == "Left" else -1.0
		var hl := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.0, 1.0, s)
			var pl: float = sin(a * 6.0 + 0.4 * sg)
			return 0.034 + 0.068 * fl + (0.004 + 0.013 * fl) * (signf(pl) * pow(absf(pl), 0.6)) + 0.003 * P._lf(s, a, 2.0 + sg)
		P._lt(k, le, hl, func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return col.darkened(0.42)
			var pl: float = sin(a * 6.0 + 0.4 * sg)
			return P._fs(col, (0.004 + 0.013 * smoothstep(0.0, 1.0, s)) * pl * 0.6 - 0.002, 9.0), 0.0, 1.0, 36, 30)
		K._lt_in(k, le, func(s: float, a: float) -> float: return float(hl.call(s, a)) - 0.005, col.darkened(0.25), 0.45, 1.0, 14, 30)   # paça içi: açık uçtan bakınca karşı duvar görünür
	# bel bağı (himo): iki tur + önde düğüm, iki kısa uç
	var hs := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	for dy: float in [0.064, 0.038]:
		var rp: Array = P._ring_pts(hk, H + dy, 0.006, 72)
		P._tb(k, rp, func(_s: float, _a: float) -> float: return 0.0075, func(_s: float, a: float, _p: Vector3) -> Color: return tie.darkened(0.16) if cos(a) < -0.3 else tie, func(_s: float, p: Vector3) -> Array: return hs.call(p), 8, true)
	var kc: Array = P._fp(hk, 0.0, H + 0.05, true, 0.016)
	P._boxr(k, kc[0], Vector3(0.03, 0, 0), Vector3(0, 0.014, 0), (kc[1] as Vector3) * 0.01, tie.darkened(0.05), [["Hips", 1.0]], 0.45)
	for sg2: float in [1.0, -1.0]:
		var tl := []
		for i in 7:
			var v := float(i) / 6.0
			tl.append(P._fp(hk, sg2 * (0.012 + 0.014 * v), H + 0.04 - v * 0.085, true, 0.012 + 0.004 * v)[0])
		P._cord(k, tl, 0.0055, tie, false, func(p: Vector3) -> Array: return P._hs(k, p))
	# koshi-ita: arkada sert yamuk levha
	P._patch(k, hk, -0.08, 0.08, H + 0.135, H + 0.03, false, 0.011, col.lightened(0.03), 0.28, 10, 6, func(_p: Vector3) -> Array: return [["Hips", 1.0]])


# ------------------------------------------------------------------ Mizukage / Tsuchikage (ref o_summit Gokage_hats, n_kage Kage_Outfits, o_tsu Ōnoki):
# köy renginde verev kimono + obi, beyaz pileli hakama, baldıra inen beyaz Kage haorisi (etek ve kol ağzında köy rengi bant, sırtta 水 / 土).
# Mizukage: lacivert, kol ağzı uzun torba, enseden etek ucuna inen geniş mavi haori yakası. Tsuchikage (Ōnoki): kahve, kısa kol, boynu saran kızıl kabarık rulo yaka + haori bağı.
static func _kage(k, mizu: bool) -> void:
	var wh := Color(0.96, 0.95, 0.92)
	var lin := Color(0.82, 0.81, 0.78)
	var ha := Color(0.86, 0.86, 0.83)
	var c2: Color = Color(0.17, 0.35, 0.72) if mizu else Color(0.47, 0.28, 0.18)
	var ki: Color = Color(0.12, 0.22, 0.45) if mizu else Color(0.33, 0.2, 0.13)
	var rd := Color(0.6, 0.11, 0.1)
	var gd := Color(0.86, 0.68, 0.24)
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
	M._inner_v(k, b, Color(0.92, 0.91, 0.87))
	# kimono: verev bindirme, belde hakamanın içine girer
	var kk := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.03], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.022), P._kp(wa, H - 0.0, 0.026)]
	M._wrap(k, {"keys": kk, "hem": H - 0.0, "col": func(_a: float, _y: float, _v: float) -> Color: return ki, "fold": func(a: float, y: float, _v: float) -> float: return 0.008 * sin(a * 5.0 + y * 14.0),
		"band": ki.lightened(0.14), "band_w": 0.017, "band_y": H + 0.1, "juban": Color(0.94, 0.93, 0.9), "ny": 22, "na": 40, "gain": 4.5})
	P._sash(k, kk, H + 0.118, 0.022, 0.012, c2.darkened(0.25) if mizu else Color(0.42, 0.36, 0.2), 0.16)   # obi: hakamanın üstünde görünen kat
	_hakama(k, b, ha, ha.darkened(0.1))
	# cübbe
	var hem: float = lerpf(KN, F, 0.42 if mizu else 0.2)
	var wd: float = ch.x + 0.05
	var keys := [P._kp(nk, N + 0.012, 0.032), [N - 0.055, ch.x * 1.04, ch.y * 0.99, ch.z * 1.1], P._kp(ch, C - 0.03, 0.05), P._kp(wa, H + 0.12, 0.076), P._kp(hp, H - 0.04, 0.088),
		[KN + 0.05, hp.x + 0.125, hp.y + 0.115, hp.z - 0.15], [hem, hp.x + 0.15, hp.y + 0.12, hp.z - 0.185]]
	var e0: float = 0.36 if mizu else 0.4
	var cl: Dictionary = _cloak(k, {"keys": keys, "hem": hem, "wd": wd, "e": func(_y: float) -> float: return e0, "col": wh, "lin": lin, "c2": c2, "bh": 0.075 if mizu else 0.06,
		"glyph": D.G_MIZU if mizu else D.G_TSUCHI, "ny": 46 if mizu else 42, "na": 84})
	var skin: Callable = cl["skin"]
	# kollar: kimono kolu (bileğe) + cübbenin geniş kolu
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		P._lt(k, ar, func(s: float, a: float) -> float: return 0.013 + 0.004 * P._lf(s, a, 1.0), func(s: float, a: float, ins: bool) -> Color:
			return ki.darkened(0.4) if ins else P._fs(ki, 0.004 * P._lf(s, a, 1.0), 12.0), 0.0, 0.975, 26, 16)
		var s1: float = 0.87 if mizu else 0.78
		var cw: float = 0.07 if mizu else 0.06
		var rad := func(s: float) -> float: return P._lr(ar, s) + 0.028 + (0.022 if mizu else 0.016) * smoothstep(0.08, 0.45, s)
		var pouch := func(s: float) -> float: return (0.06 * smoothstep(0.42, 0.74, s) + 0.012 * smoothstep(0.74, 0.86, s)) if mizu else 0.026 * smoothstep(0.4, 0.7, s)
		var ff := func(s: float, a: float) -> float: return 0.05 * sin(a * 4.0 + s * 9.0) + 0.025 * sin(a * 7.0 - s * 13.0)
		M._wide(k, ar, rad, pouch, ff, func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return lin.darkened(0.12)
			var c0: Color = c2 if s > s1 - cw * (1.0 - 0.0) else wh
			return P._fs(c0, float(ff.call(s, a)) * 0.03, 5.0), s1, 0.22 if mizu else 0.3, P._lr(ar, s1) + 0.03, 46, 30)
	if mizu:
		# geniş haori yakası: ense üstünden dönüp iki ön kenardan etek ucuna iner
		_edge_band(k, cl["g"], skin, 0.026, c2, 0.5)
		var tp: Array = (cl["g"] as Dictionary)["top"]
		var cpts := []
		var co := []
		for i in range(0, tp.size(), 2):
			var p: Vector3 = tp[i]
			cpts.append(p + Vector3(0, 0.012, 0) + Vector3(p.x, 0.0, p.z).normalized() * 0.004)
			co.append(Vector3(p.x, 1.3, p.z).normalized())
		k.strip(cpts, co, 0.016, 0.006, c2.darkened(0.08), false, skin)   # yaka sırtı: enseden kalkan kat
	else:
		_edge_band(k, cl["g"], skin, 0.018, c2.lightened(0.05), 0.4)
		# Ōnoki'nin kızıl kabarık yakası: boynu ve omuz başını saran dolgu rulo, kenarı sarı biyeli
		var rp := []
		for i in 64:
			var a: float = TAU * i / 64.0 - PI
			var aw: float = absf(a)
			var yy: float = lerpf(N - 0.028, N + 0.006, smoothstep(0.2, 2.2, aw))
			var q: Vector3 = P._on([[N + 0.03, nk.x + 0.05, nk.y + 0.05, nk.z - 0.05], [N - 0.06, nk.x + 0.075, nk.y + 0.06, nk.z - 0.06]], a, yy, 0.0)
			rp.append(q)
		var ns: Callable = func(_s: float, p: Vector3) -> Array: return [["Neck", 0.35], ["UpperChest", 0.65]] if p.y > N - 0.01 else k.torso_skin(p.y)
		P._tb(k, rp, func(s: float, a: float) -> float: return 0.036 * (1.0 - 0.14 * pow(absf(cos(s * 64.0 * PI / 4.0)), 8.0)) * (0.92 + 0.08 * cos(a)), func(s: float, a: float, _p: Vector3) -> Color:
			var lo: float = pow(absf(cos(s * 64.0 * PI / 4.0)), 8.0)
			return rd.darkened(0.3 * lo + (0.14 if cos(a) < -0.3 else 0.0)).lightened(0.06 if cos(a) > 0.6 else 0.0), ns, 16, true)
		var yp := []
		for i in 64:
			var q: Vector3 = rp[i]
			yp.append(q + Vector3(q.x, 0.0, q.z).normalized() * 0.024 + Vector3(0, -0.026, 0))
		P._cord(k, yp, 0.006, gd, true, func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N)))
		# haori bağı: iki ön kenardan göğüste düğümlenen kalın ip + püskül
		var yh: float = C - 0.06
		var pa: Vector3 = (cl["pt"] as Callable).call(e0 + 0.02, yh) + Vector3(0, 0, 0.01)
		var pb: Vector3 = (cl["pt"] as Callable).call(-e0 - 0.02, yh) + Vector3(0, 0, 0.01)
		var mid: Vector3 = (pa + pb) * 0.5 + Vector3(0, -0.02, 0.022)
		var hp_c := []
		for i in 11:
			var t := float(i) / 10.0
			hp_c.append(pa.lerp(mid, t) + Vector3(0, 0, 0.006 * sin(t * PI)))
		for i in range(1, 11):
			var t := float(i) / 10.0
			hp_c.append(mid.lerp(pb, t) + Vector3(0, 0, 0.006 * sin(t * PI)))
		P._cord(k, hp_c, 0.0055, Color(0.88, 0.86, 0.8), false, func(p: Vector3) -> Array: return k.torso_skin(p.y), 1.4, 8)
		P._stud(k, mid + Vector3(0, 0, 0.004), Vector3(0, 0, 1), 0.013, Color(0.88, 0.86, 0.8), k.torso_skin(mid.y))
		var ts := []
		for i in 6:
			ts.append(mid + Vector3(0.002 * i, -0.012 - 0.012 * i, 0.012 + 0.002 * i))
		P._tb(k, ts, func(s: float, _a: float) -> float: return 0.004 + 0.008 * smoothstep(0.3, 1.0, s), func(_s: float, a: float, _p: Vector3) -> Color: return Color(0.86, 0.84, 0.78).darkened(0.15 if sin(a * 5.0) > 0.3 else 0.0), func(_s: float, p: Vector3) -> Array: return k.torso_skin(p.y), 10)


# ------------------------------------------------------------------ Raikage (ref o_kage2 Raikage_&_guards, Five_Kage_arrival, o_ay Fourth_Raikage_full): beyaz Kage cübbesi çıplak kaslı gövdeye,
# önü göğüsten açık, enseden kalkan dik yaka + geniş devrik klapa, dirseğe inen kısa geniş kol, sarı etek bandı ve sırtta 雷;
# yuvarlak arma levhalı altın kemer, önde zeytin bez, lacivert bol pantolon, kırmızı-beyaz çizgili baldır ısıtıcısı, altın bilek kalkanları
static func _raikage(k) -> void:
	var wh := Color(0.96, 0.95, 0.92)
	var lin := Color(0.83, 0.82, 0.79)
	var ye := Color(0.92, 0.74, 0.14)
	var gd := Color(0.84, 0.64, 0.2)
	var pn := Color(0.14, 0.15, 0.23)
	var ol := Color(0.36, 0.38, 0.22)
	var rd := Color(0.7, 0.13, 0.12)
	var sk := _skin_c(k)
	var fem := _fem(k)
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
	# çıplak gövde: göğüs kası, karın ve orta çizgi gerçek kabartma
	var mg: float = 0.3 if fem else 1.0
	var mus := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var front: float = 1.0 - smoothstep(1.1, 1.6, aw)
		var pec: float = 0.1 * exp(-pow((aw - 0.42) / 0.32, 2.0)) * exp(-pow((y - (C - 0.025)) / 0.05, 2.0))
		var pcr: float = -0.05 * exp(-pow((y - (C - 0.08)) / 0.014, 2.0)) * exp(-pow((aw - 0.42) / 0.36, 2.0))
		var mid: float = -0.045 * exp(-pow(aw / 0.05, 2.0)) * smoothstep(H + 0.0, H + 0.04, y) * (1.0 - smoothstep(C + 0.02, N - 0.03, y))
		var ab: float = 0.0
		for yi: float in [C - 0.13, H + 0.15, H + 0.08]:
			ab -= 0.03 * exp(-pow((y - yi) / 0.008, 2.0)) * exp(-pow(aw / 0.3, 2.0))
		var abb: float = 0.035 * exp(-pow(aw / 0.32, 2.0)) * smoothstep(H + 0.01, H + 0.05, y) * (1.0 - smoothstep(C - 0.11, C - 0.08, y))
		var lat: float = 0.05 * exp(-pow((aw - 1.85) / 0.4, 2.0)) * exp(-pow((y - (C - 0.06)) / 0.07, 2.0))
		return mg * (front * (pec + pcr + mid + ab + abb) + lat)
	var tk := [P._kp(nk, N + 0.03, 0.0), P._kp(nk, N - 0.0, 0.003), [N - 0.05, ch.x * 0.84, ch.y * 0.84, ch.z * 0.92], P._kp(ch, C - 0.03, 0.003), P._kp(wa, H + 0.12, 0.003), P._kp(wa, H - 0.02, 0.006)]
	SE.body_layer(k, tk, 34, 56, func(_i: int, _j: int, p: Vector3) -> Color:
		var f: float = mus.call(atan2(p.x, p.z), p.y)
		return sk.darkened(clampf(-f * 3.2, 0.0, 0.28)).lightened(clampf(f * 0.6, 0.0, 0.06)), func(a: float, y: float) -> float: return mus.call(a, y))
	if fem:   # kadında göğüs sargısı (sarashi): tur tur beyaz bez
		for i in 6:
			P._sash(k, tk, C + 0.055 - 0.034 * i, 0.017, 0.005 + 0.0015 * float(i % 2), Color(0.93, 0.92, 0.88).darkened(0.04 * float(i % 2)), 0.1)
	K._seat(k, b, pn.darkened(0.1))
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		# çıplak kol: pazı ve ön kol kası
		var am := func(s: float, a: float) -> float:
			return mg * (0.012 * exp(-pow((s - 0.27) / 0.12, 2.0)) * (0.6 + 0.4 * cos(a)) + 0.008 * exp(-pow((s - 0.12) / 0.08, 2.0)) + 0.007 * exp(-pow((s - (en + 0.12)) / 0.1, 2.0))) + 0.001
		P._lt(k, ar, am, func(s: float, a: float, ins: bool) -> Color: return sk.darkened(0.3) if ins else sk.darkened(clampf(0.06 - float(am.call(s, a)) * 4.0, 0.0, 0.1)), 0.0, 1.0, 30, 16)
		# altın bilek kalkanı: dört boğumlu kalın bant, uçlarda kalın ağız
		var bs0: float = en + 0.13
		var ba := func(s: float, _a: float) -> float:
			var u: float = clampf((s - bs0) / (0.93 - bs0), 0.0, 1.0)
			return 0.018 + 0.004 * pow(absf(sin(u * PI * 4.0)), 0.5) + 0.004 * sin(u * PI)
		P._lt(k, ar, ba, func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return gd.darkened(0.5)
			var u: float = clampf((s - bs0) / (0.93 - bs0), 0.0, 1.0)
			var gr: bool = absf(sin(u * PI * 4.0)) < 0.3
			return gd.darkened(0.3 if gr else (0.1 if cos(a) < -0.3 else 0.0)).lightened(0.1 if cos(a) > 0.55 and not gr else 0.0), bs0, 0.93, 24, 20)
		for s2: float in [bs0, 0.93]:
			k.wrap_turn(P._lp(ar, s2), P._ld(ar, s2), P._lr(ar, s2) + 0.022, 0.006, 0.0, gd.darkened(0.18), P._lskin(ar, s2))
		# bol lacivert pantolon: dizden aşağı ısıtıcının içine büzülür
		var pa: Callable = M._pants(k, le, pn, 0.018, 0.022, 0.86, 1.3 if sd == "Left" else 3.9, 0.02)
		# kırmızı-beyaz çizgili baldır ısıtıcısı: kalın üst ağız, çizgiler kabartma şerit
		var w0: float = kn + 0.1
		var wa2 := func(s: float, a: float) -> float:
			return 0.011 + 0.008 * smoothstep(w0 + 0.05, w0, s) + 0.003 * sin(a * 2.0 + s * 20.0) * smoothstep(0.9, 0.97, s)
		P._lt(k, le, wa2, func(_s: float, _a: float, ins: bool) -> Color: return wh.darkened(0.4) if ins else wh.darkened(0.04), w0, 0.985, 22, 24)
		for i in 5:
			var a0: float = TAU * (float(i) + 0.5) / 5.0 - PI
			var pts := []
			var ou := []
			for j in 9:
				var s3: float = lerpf(w0 + 0.035, 0.97, float(j) / 8.0)
				var e: Array = K._lsurf(le, s3, a0, float(wa2.call(s3, a0)) + 0.0006)
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, 0.0085, 0.0014, rd, false, func(p: Vector3) -> Array: return P._lskin(le, _sproj(le, p)))
		k.wrap_turn(P._lp(le, w0 + 0.012), P._ld(le, w0), P._lr(le, w0) + float(wa2.call(w0, 0.0)) + 0.004, 0.013, 0.0, wh.darkened(0.08), P._lskin(le, w0 + 0.01))
	# önde zeytin bez + arkada kısa kat: kemerin altından sarkar, köşeleri yuvarlak
	P._cur_leg = 0.5
	var ak := [P._kp(hp, H + 0.01, 0.04), P._kp(hp, H - 0.1, 0.056), [KN + 0.03, hp.x + 0.07, hp.y + 0.07, hp.z - 0.08]]
	var af := func(a: float, y: float, _v: float) -> float: return smoothstep(H - 0.02, H - 0.15, y) * (0.03 * sin(a * 9.0 + 0.5) + 0.012 * sin(a * 17.0))
	P._cl(k, {"keys": ak, "ny": 18, "na": 26, "rng": func(_v: float) -> Vector2: return Vector2(-0.6, 0.6), "top": func(_a: float) -> float: return H + 0.01,
		"hem": func(a: float) -> float: return KN + 0.035 + 0.06 * smoothstep(0.32, 0.6, absf(a)), "fold": af, "col": func(_a: float, _y: float, _v: float) -> Color: return ol, "inner": ol.darkened(0.3), "th": 0.004})
	P._cl(k, {"keys": ak, "ny": 12, "na": 24, "rng": func(_v: float) -> Vector2: return Vector2(PI - 0.62, PI + 0.62), "top": func(_a: float) -> float: return H + 0.01,
		"hem": func(a: float) -> float: return H - 0.2 + 0.05 * smoothstep(0.3, 0.62, absf(absf(a) - PI)), "fold": af, "col": func(_a: float, _y: float, _v: float) -> Color: return ol.darkened(0.06), "inner": ol.darkened(0.3), "th": 0.004})
	# altın kemer: kalın, kenarları kalkık, önde yuvarlak arma levhası
	var bk := [P._kp(wa, H + 0.07, 0.03), P._kp(k.M(H - 0.02, 0.3), H - 0.02, 0.046)]
	var by: float = H + 0.024
	var belt := []
	for j in 9:
		var t := float(j) / 8.0
		var yy: float = by + 0.04 - t * 0.08
		var s: Array = SE.El.key_at(bk, yy)
		var bu: float = 0.006 * sin(t * PI) + (0.005 if j in [1, 7] else 0.0)
		var ro := []
		for i in 72:
			var a := TAU * i / 72.0 - PI
			var q: Vector2 = SE.El.sup(a, float(s[1]) + bu + 0.006, float(s[2]) + bu + 0.008, float(s[3]) - bu - 0.006)
			ro.append(Vector3(q.x, yy, q.y))
		belt.append(ro)
	k.grid(belt, true, func(i: int, j: int, _p: Vector3) -> Color:
		var a: float = TAU * i / 72.0 - PI
		var c0: Color = gd.darkened(0.12 if cos(a) < -0.4 else 0.0)
		return c0.darkened(0.3) if j in [0, 8] else (c0.lightened(0.1) if j in [1, 7] else (c0.darkened(0.12) if j in [2, 6] else c0)), func(_i: int, _j: int, p: Vector3) -> Array: return k.torso_skin(p.y))
	var pc: Array = P._fp(bk, 0.0, by, true, 0.022)
	var pcn: Vector3 = pc[0]
	var po: Vector3 = pc[1]
	var bo: Array = [["Hips", 0.7], ["Spine", 0.3]]
	P._fan(k, pcn, po, Vector3.UP, 0.058, Callable(), func(u: float, v: float) -> Color:
		var r: float = sqrt(u * u + v * v)
		return gd.darkened(0.25) if r > 0.84 else (gd.lightened(0.12) if r < 0.36 else (gd.darkened(0.1) if r < 0.46 else gd)), bo, 6, 36)
	var rr := []
	for i in 36:
		var t := TAU * i / 36.0
		rr.append(pcn + (po.cross(Vector3.UP).normalized() * cos(t) + Vector3.UP * sin(t)) * 0.058)
	P._tb(k, rr, func(_s: float, _a: float) -> float: return 0.007, func(_s: float, a: float, _p: Vector3) -> Color: return gd.lightened(0.12) if cos(a) > 0.2 else gd.darkened(0.2), func(_s: float, _p: Vector3) -> Array: return bo, 8, true)
	P._fan(k, pcn + po * 0.004, po, Vector3.UP, 0.028, func(th: float) -> float: return 0.75 + 0.25 * cos(th * 4.0), func(_u: float, _v: float) -> Color: return gd.lightened(0.18), bo, 3, 32)
	# cübbe: göğüs açık, alta doğru biraz kapanır
	var hem: float = lerpf(KN, F, 0.28)
	var wd: float = ch.x + 0.06
	var keys := [P._kp(nk, N + 0.012, 0.034), [N - 0.055, ch.x * 1.06, ch.y * 1.0, ch.z * 1.12], P._kp(ch, C - 0.03, 0.06), P._kp(wa, H + 0.12, 0.085), P._kp(hp, H - 0.04, 0.1),
		[KN + 0.05, hp.x + 0.13, hp.y + 0.12, hp.z - 0.15], [hem, hp.x + 0.16, hp.y + 0.13, hp.z - 0.19]]
	var ef := func(y: float) -> float: return lerpf(0.5, 0.82, smoothstep(H - 0.05, C - 0.02, y))
	var cl: Dictionary = _cloak(k, {"keys": keys, "hem": hem, "wd": wd, "e": ef, "col": wh, "lin": lin, "c2": ye, "bh": 0.07, "glyph": D.G_KAMI, "ny": 46, "na": 84})
	var skin: Callable = cl["skin"]
	var g: Dictionary = cl["g"]
	# devrik klapa: ön kenar boyunca dışa katlanmış geniş kat, göğüste geniş
	for side: int in [0, 1]:
		var ed: Array = g["ea"] if side == 0 else g["eb"]
		var sg: float = 1.0 if side == 0 else -1.0
		var pts := []
		var ou := []
		for i in range(1, ed.size()):
			var p: Vector3 = ed[i]
			if p.y < H - 0.12:
				break
			var w: float = lerpf(0.012, 0.03, smoothstep(H - 0.1, C - 0.02, p.y))
			var o: Vector3 = Vector3(p.x, 0.0, p.z).normalized()
			var tg: Vector3 = Vector3.UP.cross(o).normalized() * sg
			pts.append(p + tg * w * 0.9 + o * 0.004)
			ou.append(o)
		k.strip(pts, ou, 0.026, 0.006, wh.darkened(0.05), false, skin)
	_edge_band(k, g, skin, 0.011, wh.darkened(0.08), 0.3)
	# enseden kalkan dik yaka: dışa açılır, önde klapaya iner
	var ck := [[N + 0.15, nk.x + 0.1, nk.y + 0.07, nk.z - 0.11], [N + 0.07, nk.x + 0.068, nk.y + 0.05, nk.z - 0.07], [N + 0.0, nk.x + 0.058, nk.y + 0.046, nk.z - 0.056], [N - 0.05, nk.x + 0.076, nk.y + 0.06, nk.z - 0.07]]
	var nsk := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 12, "na": 44, "rng": func(_v: float) -> Vector2: return Vector2(0.9, TAU - 0.9), "top": func(a: float) -> float:
		return lerpf(N + 0.02, N + 0.14, smoothstep(0.9, 2.3, absf(a))), "hem": func(_a: float) -> float: return N - 0.035, "fold": func(a: float, _y: float, v: float) -> float: return 0.012 * (1.0 - v) * sin(a * 5.0),
		"col": func(_a: float, _y: float, _v: float) -> Color: return wh, "inner": wh.darkened(0.08), "skin": nsk, "th": 0.006})
	P._bd(k, cg["top"], 0.005, 0.003, wh.darkened(0.14), false, nsk, 0.5)
	# kısa geniş kol: dirseğin hemen altında biter, ağzı sarı bantlı
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var s1: float = float(ar["kn"]) - 0.05   # dirsek kırımına girmez: bant gerilip yayılmaz
		var ff := func(s: float, a: float) -> float: return 0.045 * sin(a * 4.0 + s * 9.0) + 0.02 * sin(a * 7.0 - s * 13.0)
		M._wide(k, ar, func(s: float) -> float: return P._lr(ar, s) + 0.03 + 0.035 * smoothstep(0.05, 0.4, s), func(s: float) -> float: return 0.025 * smoothstep(0.2, 0.5, s), ff, func(s: float, a: float, ins: bool) -> Color:
			if ins:
				return lin.darkened(0.12)
			return P._fs(ye if s > s1 - 0.06 else wh, float(ff.call(s, a)) * 0.03, 5.0), s1, 0.0, 0.1, 40, 28)


# ------------------------------------------------------------------ ANBU ortakları
## Dik boğaz: boynu saran kapalı yaka, kaburgalı
static func _turtle(k, nk: Vector3, col: Color, h: float) -> void:
	var N: float = k.N
	var keys := [P._kp(nk, N + h, 0.007), P._kp(nk, N + 0.02, 0.012), [N - 0.03, nk.x + 0.032, nk.y + 0.026, nk.z - 0.026]]
	var nsk := func(p: Vector3) -> Array:
		var w: float = clampf((p.y - N + 0.01) / (h + 0.01), 0.0, 1.0) * 0.6
		return [["Neck", w], ["UpperChest", 1.0 - w]]
	P._sheet(k, keys, 8, 40, Callable(), func(a: float, y: float, _u: float) -> float: return 0.012 * sin(a * 18.0) * smoothstep(N - 0.01, N + 0.02, y) + 0.02 * exp(-pow((y - (N + h * 0.6)) / 0.012, 2.0)),
		func(a: float, _y: float, _u: float, v: float, _p: Vector3) -> Color: return col.darkened(0.12 if sin(a * 18.0) < -0.5 else 0.0).lightened(0.05 if v < 0.1 else 0.0), 0.005, 1.0, nsk)


## Sol omuzda ANBU dövmesi: kıvrık sarmal + aşağı inen kuyruk (kola gömülü ince şerit)
static func _tattoo(k, ar: Dictionary, s0: float, col: Color) -> void:
	var sd: String = ar["sd"]
	var a0: float = PI * 0.5 if sd == "Left" else -PI * 0.5
	var L: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
	var R: float = P._lr(ar, s0)
	var pts := []
	var ou := []
	for i in 34:
		var t := float(i) / 33.0
		var r: float = 0.026 * pow(t, 0.8)
		var th: float = t * TAU * 1.55 + 0.6
		var du: float = r * cos(th)
		var dv: float = r * sin(th)
		if i == 33:
			break
		var e: Array = K._lsurf(ar, s0 - dv / L, a0 + du / R, 0.0012)
		pts.append(e[0])
		ou.append(e[1])
	var tail := []
	var to := []
	for i in 7:
		var t := float(i) / 6.0
		var e: Array = K._lsurf(ar, s0 + (0.012 + 0.07 * t) , a0 + (0.03 - 0.06 * t * t) / R, 0.0012)
		tail.append(e[0])
		to.append(e[1])
	var skf := func(p: Vector3) -> Array: return P._lskin(ar, _sproj(ar, p))
	k.strip(pts, ou, 0.0026, 0.0007, col, false, skf)
	k.strip(tail, to, 0.0028, 0.0007, col, false, skf)


## Uzuv üstü perçin: uzuv yüzeyinde (s, a) noktasında
static func _lstud(k, l: Dictionary, s: float, a: float, add: float, r: float, col: Color) -> void:
	var e: Array = K._lsurf(l, s, a, add)
	P._stud(k, e[0], e[1], r, col, P._lskin(l, s))


## Kapalı zırh kabuğu kenarı: üst ve alt sıra boyunca kalın kıvrık kenar
static func _rims(k, g: Dictionary, r: float, col: Color, skinf: Callable) -> void:
	for key: String in ["top", "hem"]:
		var row: Array = (g[key] as Array).duplicate()
		P._cord(k, row, r, col, true, skinf, 0.0, 8)


# ------------------------------------------------------------------ ANBU Gece (ref yy_kakashi Kakashi_ANBU_uniform, i_anbu Konoha_Anbu, tenzo Young_ANBU_Yamato):
# kolsuz dik boğaz siyah üst, çıplak omuz + dövme, yelek biçimli gri plaka (omuz kayışı plakayla bir, belde basamak + cep kapağı, yanda tokalı kayış),
# dirsek üstüne çıkan siyah kol kılıfı + dış kolda geniş gri koruyucu ve iki kayış, parmaksız eldiven, bol siyah pantolon, sağ uylukta beyaz bant, baldırda siyah sargı
static func _gece(k) -> void:
	var dk := Color(0.1, 0.1, 0.12)
	var pl := Color(0.76, 0.76, 0.74)
	var st := Color(0.22, 0.22, 0.24)
	var wr := Color(0.9, 0.89, 0.86)
	var red := Color(0.72, 0.15, 0.13)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i: int, _j: int, _p: Vector3) -> Color: return dk)
	K._seat(k, b, dk)
	_turtle(k, nk, dk, 0.075)
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		P._bare(k, ar, sk, 0.0, en - 0.1)
		P._armhole(k, ar, 0.075, 0.008, 0.007, dk)
		if sd == "Left":
			_tattoo(k, ar, 0.2, red)
		# kol kılıfı: dirsek üstünden bileğe, üstte kıvrık ağız, dirsekte kırışık
		var g0: float = en - 0.14
		var gl := func(s: float, a: float) -> float: return 0.0045 + 0.003 * sin(a * 3.0 + s * 30.0) * exp(-pow((s - en) / 0.07, 2.0))
		P._lt(k, ar, gl, func(s: float, a: float, ins: bool) -> Color: return dk.darkened(0.4) if ins else P._fs(dk.lightened(0.04), float(gl.call(s, a)) - 0.0045, 30.0), g0, 0.97, 26, 18)
		k.wrap_turn(P._lp(ar, g0 + 0.008), P._ld(ar, g0), P._lr(ar, g0) + 0.009, 0.009, 0.0, dk.lightened(0.07), P._lskin(ar, g0 + 0.01))
		K._glove(k, sd, ar, dk, pl.darkened(0.12))
		# dış kol koruyucusu: dirseğe doğru genişleyen kavisli levha
		var ao: float = PI * 0.5 if sd == "Left" else -PI * 0.5
		K._shell(k, ar, en + 0.04, 0.9, ao - 1.2, ao + 1.2, func(s: float, _a: float) -> float: return 0.011 + 0.008 * smoothstep(en + 0.14, en + 0.04, s), 0.006, func(u: float, v: float, inner: bool) -> Color:
			if inner:
				return pl.darkened(0.4)
			return pl.darkened(0.16 if v < 0.06 or v > 0.94 or u < 0.05 or u > 0.95 else 0.0).lightened(0.06 * (1.0 - absf(u - 0.5) * 2.0)), 16, 18)
		for s2: float in [en + 0.14, 0.82]:
			k.wrap_turn(P._lp(ar, s2), P._ld(ar, s2), P._lr(ar, s2) + 0.02, 0.0065, 0.0, st, P._lskin(ar, s2))
			_lstud(k, ar, s2, ao, 0.026, 0.006, Color(0.62, 0.62, 0.6))
		# bol siyah pantolon, baldırda siyah sargının içine girer
		var pa: Callable = K._pant(k, le, dk.lightened(0.03), 0.013, 0.022, 0.8, 1.3 if sd == "Left" else 3.9)
		P._lt(k, le, func(_s: float, _a: float) -> float: return 0.006, func(_s: float, _a: float, ins: bool) -> Color: return dk.darkened(0.4) if ins else dk, kn + 0.06, 0.985, 18, 18)
		for i in 11:
			var s3: float = lerpf(kn + 0.17, 0.975, float(i) / 10.0)
			var ad: float = maxf(0.012, float(pa.call(s3, 0.0)) + 0.006) if s3 < 0.8 else 0.012
			k.wrap_turn(P._lp(le, s3), P._ld(le, s3), P._lr(le, s3) + ad, 0.0125, 0.009, dk.lightened(0.08 + 0.04 * float(i % 2)), P._lskin(le, s3))
		if sd == "Right":   # sağ uylukta beyaz bant
			for i in 4:
				var s4: float = lerpf(0.2, 0.31, float(i) / 3.0)
				k.wrap_turn(P._lp(le, s4), P._ld(le, s4), P._lr(le, s4) + float(pa.call(s4, 0.0)) + 0.005, 0.0135, 0.003, wr.darkened(0.06 * float(i % 2)), P._lskin(le, s4))
	# yelek biçimli plaka: omuz kayışı gövdeyle bir, koltuk altı oyuk, önde boyun oyuğu
	var pk := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 0.96, ch.y * 0.98, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.032), P._kp(hp, H - 0.04, 0.042)]
	var tsk := func(p: Vector3) -> Array: return k.torso_skin(maxf(p.y, H + 0.005))
	var top_f := func(a: float) -> float:
		var aw: float = absf(a)
		return N - 0.035 - (N - C + 0.05) * exp(-pow((aw - 1.57) / 0.42, 2.0)) - 0.06 * exp(-pow(aw / 0.3, 2.0)) - 0.03 * exp(-pow((aw - PI) / 0.38, 2.0))
	var pf := func(a: float, y: float, _v: float) -> float:
		var aw: float = absf(a)
		var g: float = -0.03 * exp(-pow((aw - 1.57) / 0.05, 2.0))
		g += 0.03 * (1.0 - smoothstep(H + 0.07, H + 0.085, y))
		g -= 0.02 * exp(-pow((y - (H + 0.08)) / 0.006, 2.0))
		return g
	var gp: Dictionary = P._cl(k, {"keys": pk, "ny": 26, "na": 84, "top": top_f, "hem": func(_a: float) -> float: return H - 0.035, "fold": pf,
		"col": func(_a: float, y: float, _v: float) -> Color: return pl.darkened(0.05) if y < H + 0.075 else pl, "inner": pl.darkened(0.42), "skin": tsk, "th": 0.007, "gain": 3.0})
	_rims(k, gp, 0.0055, pl.darkened(0.2), func(p: Vector3) -> Array: return tsk.call(p))
	for sg: float in [1.0, -1.0]:
		P._over(k, pk, sg * ch.x * 0.48, N - 0.06, N - 0.06, 0.03, 0.006, 0.006, pl.darkened(0.03))
		var ef: Array = P._fp(pk, sg * ch.x * 0.48, N - 0.07, true, 0.012)
		P._boxr(k, ef[0], Vector3(0.016, 0, 0), Vector3(0, 0.009, 0), (ef[1] as Vector3) * 0.004, Color(0.6, 0.6, 0.58), k.torso_skin(N - 0.07))
		for yb: float in [C - 0.1, H + 0.05]:   # yan kayış + toka: ön ve arka levhayı bağlar
			P._line(k, pk, [Vector2(sg * 1.25, yb), Vector2(sg * 1.57, yb), Vector2(sg * 1.89, yb)], 0.009, 0.012, 0.004, st, 4)
			var eb: Array = P._sa(pk, sg * 1.57, yb, 0.017)
			P._boxr(k, eb[0], (eb[1] as Vector3).cross(Vector3.UP).normalized() * 0.011, Vector3(0, 0.011, 0), (eb[1] as Vector3) * 0.004, Color(0.6, 0.6, 0.58), k.torso_skin(yb))
	P._patch(k, pk, -wa.x * 0.78, -wa.x * 0.3, H + 0.064, H + 0.012, true, 0.012, pl.darkened(0.02), 0.2, 8, 6, tsk)   # cep kapağı
	var ep: Array = P._fp(pk, -wa.x * 0.54, H + 0.052, true, 0.016)
	P._stud(k, ep[0], ep[1], 0.006, Color(0.55, 0.55, 0.53), k.torso_skin(H + 0.05))


# ------------------------------------------------------------------ ANBU Kaptan: uzun kollu dik boğaz koyu gömlek, kat kat göğüs zırhı (göğüs levhası + yanda bağcıklı üç karın lamı),
# ön kolda beyaz sargı, parmaksız eldiven, omuzlardan sırta inen kısa koyu pelerin (açık gri biye, enseden kalkık yaka, göğüste kordonla bağlı), bilekte beyaz sargı
static func _kaptan(k) -> void:
	var dk := Color(0.12, 0.12, 0.14)
	var pl := Color(0.8, 0.8, 0.78)
	var st := Color(0.22, 0.22, 0.25)
	var wr := Color(0.9, 0.9, 0.87)
	var cp := Color(0.16, 0.16, 0.18)
	var ce := Color(0.33, 0.33, 0.35)
	var red := Color(0.72, 0.15, 0.13)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i: int, _j: int, _p: Vector3) -> Color: return dk)
	K._seat(k, b, dk)
	_turtle(k, nk, dk, 0.085)
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sl := func(s: float, a: float) -> float:
			return 0.008 + 0.004 * P._lf(s, a, 1.0) * sin(s * PI) + 0.004 * sin(a * 3.0 + s * 30.0) * exp(-pow((s - en) / 0.07, 2.0)) + 0.006 * exp(-pow((s - 0.12) / 0.1, 2.0))
		P._lt(k, ar, sl, func(s: float, a: float, ins: bool) -> Color: return dk.darkened(0.4) if ins else P._fs(dk.lightened(0.04), float(sl.call(s, a)) - 0.009, 22.0), 0.0, 0.97, 32, 18)
		for i in 9:
			var s2: float = lerpf(en + 0.12, 0.88, float(i) / 8.0)
			k.wrap_turn(P._lp(ar, s2), P._ld(ar, s2), P._lr(ar, s2) + float(sl.call(s2, 0.0)) + 0.004, 0.0115, 0.008, wr.darkened(0.05 * float(i % 3)), P._lskin(ar, s2))
		K._glove(k, sd, ar, dk, pl.darkened(0.15))
		if sd == "Left":   # kol üstünde dövmenin yerine kaptan işareti: kırmızı kumaş armalı bant
			var sb: float = 0.24
			k.wrap_turn(P._lp(ar, sb), P._ld(ar, sb), P._lr(ar, sb) + float(sl.call(sb, 0.0)) + 0.004, 0.02, 0.0, red.darkened(0.1), P._lskin(ar, sb))
			_lstud(k, ar, sb, PI * 0.5, float(sl.call(sb, PI * 0.5)) + 0.024, 0.009, Color(0.75, 0.75, 0.72))
		var pa: Callable = K._pant(k, le, dk.lightened(0.03), 0.013, 0.02, 0.86, 1.3 if sd == "Left" else 3.9)
		P._lt(k, le, func(_s: float, _a: float) -> float: return 0.006, func(_s: float, _a: float, ins: bool) -> Color: return dk.darkened(0.4) if ins else dk, 0.78, 0.985, 10, 18)
		for i in 7:
			var s3: float = lerpf(0.83, 0.975, float(i) / 6.0)
			var ad: float = maxf(0.012, float(pa.call(s3, 0.0)) + 0.006) if s3 < 0.86 else 0.012
			k.wrap_turn(P._lp(le, s3), P._ld(le, s3), P._lr(le, s3) + ad, 0.0125, 0.009, wr.darkened(0.05 * float(i % 3)), P._lskin(le, s3))
	# göğüs levhası
	var tsk := func(p: Vector3) -> Array: return k.torso_skin(maxf(p.y, H + 0.005))
	var pk := [P._kp(nk, N + 0.0, 0.034), [N - 0.055, ch.x * 0.97, ch.y * 0.99, ch.z * 1.06], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.034), P._kp(hp, H - 0.04, 0.04)]
	var top_f := func(a: float) -> float:
		var aw: float = absf(a)
		return N - 0.045 - (N - C + 0.035) * exp(-pow((aw - 1.57) / 0.4, 2.0)) - 0.035 * exp(-pow(aw / 0.34, 2.0)) - 0.02 * exp(-pow((aw - PI) / 0.4, 2.0))
	var y_l: float = C - 0.1
	var gp: Dictionary = P._cl(k, {"keys": pk, "ny": 14, "na": 84, "top": top_f, "hem": func(_a: float) -> float: return y_l,
		"fold": func(a: float, y: float, _v: float) -> float: return -0.026 * exp(-pow((absf(a) - 1.57) / 0.05, 2.0)) + 0.018 * exp(-pow((absf(a) - 0.45) / 0.3, 2.0)) * exp(-pow((y - (C - 0.03)) / 0.05, 2.0)),
		"col": func(_a: float, _y: float, _v: float) -> Color: return pl, "inner": pl.darkened(0.42), "skin": tsk, "th": 0.007, "gain": 3.5})
	_rims(k, gp, 0.0055, pl.darkened(0.2), func(p: Vector3) -> Array: return tsk.call(p))
	# üç karın lamı: her biri üsttekinin altına girer, aşağı doğru hafif genişler
	var nl: int = 3
	var lh: float = (y_l - (H - 0.03)) / float(nl)
	for i in nl:
		var y0: float = y_l + 0.01 - lh * float(i)
		var y1: float = y_l - lh * float(i + 1)
		var add: float = 0.003 + 0.004 * float(i)
		var lk := []
		for e: Array in pk:
			lk.append([e[0], float(e[1]) + add, float(e[2]) + add, float(e[3]) - add])
		var gl: Dictionary = P._cl(k, {"keys": lk, "ny": 5, "na": 76, "top": func(_a: float) -> float: return y0, "hem": func(_a: float) -> float: return y1,
			"fold": func(a: float, y: float, _v: float) -> float: return -0.024 * exp(-pow((absf(a) - 1.57) / 0.05, 2.0)) + 0.01 * (1.0 - smoothstep(y1, y0, y)),
			"col": func(_a: float, _y: float, v: float) -> Color: return pl.darkened(0.04 * float(i) + (0.12 if v > 0.8 else 0.0)), "inner": pl.darkened(0.42), "skin": tsk, "th": 0.006, "gain": 3.0})
		P._cord(k, gl["hem"], 0.0045, pl.darkened(0.24), true, func(p: Vector3) -> Array: return tsk.call(p), 0.0, 6)
	# yan bağcıklar: lamları dikey bağlayan koyu ip
	for sg: float in [1.0, -1.0]:
		for a0: float in [sg * 1.3, sg * 1.84]:
			var cp_pts := []
			var yy: float = y_l + 0.02
			while yy > H - 0.03:
				cp_pts.append(P._on(pk, a0, yy, 0.0) + Vector3(sin(a0), 0.0, cos(a0)) * 0.016)
				yy -= 0.012
			P._cord(k, cp_pts, 0.0035, st, false, func(p: Vector3) -> Array: return tsk.call(p), 1.6, 6)
		P._over(k, pk, sg * ch.x * 0.5, N - 0.075, N - 0.07, 0.024, 0.006, 0.006, st.lightened(0.05))
	# kısa pelerin: omuz başından sırta, arkada bele iner; yanları üst kolu izler
	var hb: float = H - 0.12
	var wd: float = ch.x + 0.05
	var ck := [P._kp(nk, N + 0.02, 0.045), [N - 0.045, ch.x * 1.12, ch.y * 1.04, ch.z * 1.26], P._kp(ch, C - 0.03, 0.09), P._kp(wa, H + 0.12, 0.085), P._kp(hp, hb, 0.09)]
	var csk := func(p: Vector3) -> Array: return _upper_skin(k, p, wd) if p.y >= H else M._rear_skin(k, p, hb, wd)   # yanlar gövdede kalır: öne savrulan kol pelerini yırtıp zırhı açmaz
	var a_e: float = 1.38
	var cf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((N - 0.06 - y) / (N - 0.06 - hb), 0.0, 1.0)
		return t * (0.04 * sin(a * 6.0 + 0.3) + 0.016 * sin(a * 11.0 + 1.2))
	var gc: Dictionary = P._cl(k, {"keys": ck, "ny": 26, "na": 60, "rng": func(_v: float) -> Vector2: return Vector2(a_e, TAU - a_e), "top": func(_a: float) -> float: return N + 0.012,
		"hem": func(a: float) -> float: return lerpf(C - 0.06, hb, smoothstep(a_e, 2.6, absf(a))), "fold": cf, "col": func(_a: float, _y: float, _v: float) -> Color: return cp, "inner": cp.darkened(0.3), "skin": csk, "th": 0.005, "gain": 5.0})
	var outl: Array = (gc["ea"] as Array).duplicate()
	outl.reverse()
	outl.append_array(gc["top"])
	outl.append_array(gc["eb"])
	P._cord(k, outl, 0.0045, ce, false, func(p: Vector3) -> Array: return csk.call(p), 0.0, 6)
	P._cord(k, gc["hem"], 0.005, ce, false, func(p: Vector3) -> Array: return csk.call(p), 0.0, 6)
	# enseden kalkık yaka
	var nsk := func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, N))
	var kc := [[N + 0.075, nk.x + 0.06, nk.y + 0.05, nk.z - 0.07], [N + 0.0, nk.x + 0.05, nk.y + 0.045, nk.z - 0.055], [N - 0.04, nk.x + 0.07, nk.y + 0.055, nk.z - 0.07]]
	P._cl(k, {"keys": kc, "ny": 8, "na": 40, "rng": func(_v: float) -> Vector2: return Vector2(1.45, TAU - 1.45), "top": func(a: float) -> float: return lerpf(N + 0.02, N + 0.07, smoothstep(1.45, 2.4, absf(a))),
		"hem": func(_a: float) -> float: return N - 0.03, "col": func(_a: float, _y: float, _v: float) -> Color: return cp.lightened(0.04), "inner": ce, "skin": nsk, "th": 0.005})
	# göğüste kordon: pelerinin iki ön köşesinden, ortada metal halka
	var ctr: Vector3 = P._fp(pk, 0.0, N - 0.065, true, 0.03)[0]
	for sg: float in [1.0, -1.0]:
		var e0: Array = P._sa(ck, sg * (a_e + 0.04), N - 0.02, 0.004)
		var p0: Vector3 = e0[0]
		var cpts := []
		for i in 13:
			var t := float(i) / 12.0
			var q: Vector3 = p0.lerp(ctr, t)
			var on: Vector3 = P._on(pk, atan2(q.x, q.z), q.y, 0.0)
			var rr: float = Vector2(on.x, on.z).length() + 0.016
			var hz: Vector2 = Vector2(q.x, q.z).normalized() * maxf(rr, Vector2(q.x, q.z).length())
			cpts.append(Vector3(hz.x, q.y - 0.012 * sin(t * PI), hz.y))
		P._cord(k, cpts, 0.0042, ce.lightened(0.1), false, func(p: Vector3) -> Array: return k.torso_skin(p.y), 1.5, 6)
		P._stud(k, p0, (e0[1] as Vector3), 0.011, Color(0.62, 0.62, 0.6), k.torso_skin(p0.y))
	var rg := []
	for i in 20:
		var t := TAU * i / 20.0
		rg.append(ctr + Vector3(cos(t) * 0.014, sin(t) * 0.014, 0.004))
	P._tb(k, rg, func(_s: float, _a: float) -> float: return 0.0035, func(_s: float, a: float, _p: Vector3) -> Color: return Color(0.7, 0.7, 0.68).lightened(0.1 if cos(a) > 0.3 else 0.0), func(_s: float, _p: Vector3) -> Array: return k.torso_skin(N - 0.065), 6, true)


# ------------------------------------------------------------------ ANBU Yami: kolsuz dik boğaz siyah üst, ön ve arkada düz yuvarlak köşeli gri levha (ince omuz askısı + yanda iki kayış),
# dirseği aşan siyah kol ısıtıcı (kalın ağız, bilekte büzgü) + dış kolda perçinli dar metal levha, sol üst kolda beyaz bant, dar siyah pantolon,
# dizden bileğe kaburgalı siyah bacak ısıtıcı, sağ dizde beyaz sargı
static func _yami(k) -> void:
	var dk := Color(0.08, 0.08, 0.1)
	var pl := Color(0.72, 0.7, 0.76)
	var st := Color(0.2, 0.2, 0.23)
	var wr := Color(0.92, 0.92, 0.9)
	var red := Color(0.72, 0.15, 0.13)
	var sk := _skin_c(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i: int, _j: int, _p: Vector3) -> Color: return dk)
	K._seat(k, b, dk)
	_turtle(k, nk, dk, 0.095)
	for sd: String in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var w0: float = en - 0.2
		P._bare(k, ar, sk, 0.0, w0 + 0.02)
		P._armhole(k, ar, 0.075, 0.008, 0.0065, dk)
		if sd == "Left":
			_tattoo(k, ar, 0.15, red)
			for s2: float in [w0 - 0.07, w0 - 0.035]:
				k.wrap_turn(P._lp(ar, s2), P._ld(ar, s2), P._lr(ar, s2) + 0.004, 0.012, 0.004, wr, P._lskin(ar, s2))
		# kol ısıtıcı: üstte kalın kıvrık ağız, bilekte büzgü halkaları
		var wf := func(s: float, a: float) -> float:
			return 0.005 + 0.0035 * sin(s * 150.0 + a) * smoothstep(0.86, 0.95, s) + 0.0025 * sin(a * 3.0 + s * 30.0) * exp(-pow((s - en) / 0.06, 2.0))
		P._lt(k, ar, wf, func(s: float, a: float, ins: bool) -> Color: return dk.darkened(0.4) if ins else P._fs(dk.lightened(0.05), float(wf.call(s, a)) - 0.005, 30.0), w0, 0.985, 30, 18)
		k.wrap_turn(P._lp(ar, w0 + 0.01), P._ld(ar, w0), P._lr(ar, w0) + 0.011, 0.012, 0.0, dk.lightened(0.07), P._lskin(ar, w0 + 0.012))
		var ao: float = PI * 0.5 if sd == "Left" else -PI * 0.5
		var s0: float = en + 0.07
		var s1: float = 0.86
		K._shell(k, ar, s0, s1, ao - 0.62, ao + 0.62, func(_s: float, _a: float) -> float: return 0.0085, 0.0055, func(u: float, v: float, inner: bool) -> Color:
			if inner:
				return pl.darkened(0.42)
			return pl.darkened(0.18 if v < 0.05 or v > 0.95 or u < 0.06 or u > 0.94 else 0.0), 12, 12)
		for sv: float in [s0 + 0.025, s1 - 0.025]:
			for da: float in [-0.42, 0.42]:
				_lstud(k, ar, sv, ao + da, 0.0145, 0.0045, pl.lightened(0.12))
		# dar pantolon, dizde ısıtıcının içine girer
		var pa: Callable = K._pant(k, le, dk.lightened(0.03), 0.008, 0.01, 0.74, 1.3 if sd == "Left" else 3.9)
		var l0: float = kn + 0.05
		var lw := func(s: float, a: float) -> float:
			return 0.011 + 0.0016 * cos(a * 14.0) + 0.006 * exp(-pow((s - l0 - 0.012) / 0.012, 2.0)) + 0.003 * sin(s * 120.0 + a) * smoothstep(0.92, 0.97, s)
		P._lt(k, le, lw, func(s: float, a: float, ins: bool) -> Color: return dk.darkened(0.4) if ins else dk.lightened(0.05).darkened(0.25 if cos(a * 14.0) < -0.4 else 0.0), l0, 0.985, 30, 28)
		if sd == "Right":   # sağ dizde beyaz sargı
			for i in 4:
				var s4: float = lerpf(kn - 0.055, kn + 0.03, float(i) / 3.0)
				var ad: float = maxf(float(pa.call(s4, 0.0)), 0.014) + 0.006
				k.wrap_turn(P._lp(le, s4), P._ld(le, s4), P._lr(le, s4) + ad, 0.0135, 0.006, wr.darkened(0.06 * float(i % 2)), P._lskin(le, s4))
	# ön ve arka düz levha: yuvarlak köşeli, kalın kenarlı
	var tsk := func(p: Vector3) -> Array: return k.torso_skin(maxf(p.y, H + 0.005))
	var pk := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 0.96, ch.y * 0.98, ch.z * 1.04], P._kp(ch, C - 0.03, 0.028), P._kp(wa, H + 0.12, 0.03), P._kp(wa, H + 0.0, 0.034)]
	var aw0: float = 0.92
	var dd := func(a: float) -> float: return minf(absf(a), PI - absf(a))
	var top_f := func(a: float) -> float: return N - 0.085 - 0.035 * smoothstep(aw0 - 0.24, aw0, float(dd.call(a)))
	var hem_f := func(a: float) -> float: return H + 0.025 + 0.03 * smoothstep(aw0 - 0.24, aw0, float(dd.call(a)))
	for fr: bool in [true, false]:
		var c0: float = 0.0 if fr else PI
		var gp: Dictionary = P._cl(k, {"keys": pk, "ny": 20, "na": 36, "rng": func(_v: float) -> Vector2: return Vector2(c0 - aw0, c0 + aw0), "top": top_f, "hem": hem_f,
			"fold": func(_a: float, _y: float, _v: float) -> float: return 0.0, "col": func(_a: float, _y: float, _v: float) -> Color: return pl, "inner": pl.darkened(0.42), "skin": tsk, "th": 0.008, "gain": 1.0})
		var ol: Array = (gp["top"] as Array).duplicate()
		ol.append_array(gp["eb"])
		var hm: Array = (gp["hem"] as Array).duplicate()
		hm.reverse()
		ol.append_array(hm)
		var ea: Array = (gp["ea"] as Array).duplicate()
		ea.reverse()
		ol.append_array(ea)
		P._cord(k, ol, 0.0052, pl.darkened(0.2), true, func(p: Vector3) -> Array: return tsk.call(p), 0.0, 8)
	for sg: float in [1.0, -1.0]:
		P._over(k, pk, sg * ch.x * 0.42, N - 0.08, N - 0.08, 0.013, 0.006, 0.004, st)
		var ef: Array = P._fp(pk, sg * ch.x * 0.42, N - 0.1, true, 0.012)
		P._boxr(k, ef[0], Vector3(0.012, 0, 0), Vector3(0, 0.01, 0), (ef[1] as Vector3) * 0.004, Color(0.58, 0.58, 0.56), k.torso_skin(N - 0.1))
		for yb: float in [C - 0.09, H + 0.06]:
			P._line(k, pk, [Vector2(sg * (aw0 - 0.08), yb), Vector2(sg * 1.57, yb), Vector2(sg * (PI - aw0 + 0.08), yb)], 0.008, 0.01, 0.0035, st, 5)
