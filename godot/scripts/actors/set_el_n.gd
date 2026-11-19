extends RefCounted
## Elle modellenmiş setler, parti n: set_goken, set_kurenai_kenpo, set_sennin_shugyo, set_kage, set_hokage, set_kazekage.
## Kumaş / uzuv yardımcıları parti e (P) ve k (K) dosyalarından; burada önü açık uzun giysi, çan kol, hakama ve omuz örtüsü.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const D = preload("res://scripts/actors/set_v2_d.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")

const DONE := ["set_goken", "set_kurenai_kenpo", "set_sennin_shugyo", "set_kage", "set_hokage", "set_kazekage"]


static func recipe(k, sid: String) -> void:
	P._cur_long = false
	P._cur_leg = 0.58
	match sid:
		"set_goken": _goken(k)
		"set_kurenai_kenpo": _kenpo(k)
		"set_sennin_shugyo": _sennin(k)
		"set_kage": _kage(k)
		"set_hokage": _hokage(k)
		"set_kazekage": _kazekage(k)


# ------------------------------------------------------------------ ortak
static func _skin_col(k) -> Color:
	var c = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	return c if c is Color else Color(0.9, 0.72, 0.58)


static func _tri(x: float) -> float:
	return absf(fposmod(x / TAU, 1.0) * 2.0 - 1.0) * 2.0 - 1.0


## Anahtar kesitinde açıya karşılık gelen x
static func _x_at(keys: Array, a: float, y: float) -> float:
	var s: Array = SE.El.key_at(keys, y)
	return SE.El.sup(a, s[1], s[2], s[3]).x


## Beden üstü: boyundan kalçaya, gerilme kırışıklı
static func _torso(k, b: Dictionary, pad: float, col: Color, foldf := Callable(), gain := 7.0) -> Array:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := [P._kp(nk, k.N + 0.05, 0.008, 0.01), P._kp(nk, k.N + 0.015, 0.014), [k.N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.92], P._kp(ch, k.C - 0.03, pad), P._kp(b["wa"], k.H + 0.12, pad), P._kp(b["hp"], k.H - 0.09, pad)]
	var ff: Callable = foldf
	SE.body_layer(k, keys, 30, 56, func(_i, _j, p):
		if not ff.is_valid():
			return col
		return P._fs(col, float(ff.call(atan2(float(p.x), float(p.z)), float(p.y))), gain), ff)
	return keys


## Giysi ağırlığı (parti k paltosunun yöntemi): arka etek baldırı daha çok izler, geri kalkan topuk kumaşı delmez
static func _coat_sk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.04, -0.07, p.z)
	var wf: float = 0.94 * pow(minf(1.0, t / 0.5), 0.5)
	var wb: float = lerpf(0.88 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8)), 0.99, smoothstep(0.5, 0.8, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.004, 0.085, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.12, k.K - 0.1, p.y) * bk * absf(2.0 * s - 1.0)
	var sd: String = "Left" if s >= 0.5 else "Right"
	if kb > 0.0:
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Önü açık uzun giysi. o: keys, hem, e(y) yarım açıklık, fold(a, y), col, lin, ny, na, gain, th
static func _coat(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var hem: float = o["hem"]
	var top: float = keys[0][0]
	var ef: Callable = o["e"]
	var ff: Callable = o["fold"]
	var col: Color = o["col"]
	var sk := func(p: Vector3) -> Array: return _coat_sk(k, p, hem)
	var e_h: float = ef.call(hem)
	var rnd: float = o.get("round", 0.07)
	var rf := func(a: float) -> float:   # ön köşe yuvarlanır: koşuda sivri kanat olmaz
		return rnd * (1.0 - smoothstep(e_h, e_h + 0.42, absf(wrapf(a, -PI, PI))))
	var rg := func(v: float) -> Vector2:
		var e: float = ef.call(lerpf(top, hem, v))
		return Vector2(e, TAU - e)
	var cg := P._cl(k, {"keys": keys, "ny": o.get("ny", 40), "na": o.get("na", 88), "rng": rg, "top": func(_a): return top, "hem": func(a): return hem + float(rf.call(float(a))),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return col, "gain": o.get("gain", 3.6), "inner": o["lin"], "skin": sk, "th": o.get("th", 0.006)})
	P._cur_hem = hem
	cg["sk"] = sk
	cg["rf"] = rf
	cg["keys"] = keys
	cg["hem_y"] = hem
	cg["top_y"] = top
	cg["e"] = ef
	cg["fold"] = ff
	cg["pt"] = func(a: float, y: float) -> Vector3:
		var s: Array = SE.El.key_at(keys, y)
		var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
		var f: float = 1.0 + float(ff.call(wrapf(a, -PI, PI), y))
		return Vector3(q.x * f, y, q.y * f)
	return cg


## Giysinin kıvrımlarını izleyen üst kat: üst kenarı topf(a) (düz bant ya da alev dili)
static func _coat_layer(k, cg: Dictionary, topf: Callable, y1: float, col: Color, na := 88, ny := 5, lift := 0.0028) -> Dictionary:
	var ef: Callable = cg["e"]
	var ff: Callable = cg["fold"]
	var e1: float = ef.call(y1)
	var rf: Callable = cg["rf"]
	return P._cl(k, {"keys": cg["keys"], "ny": ny, "na": na, "rng": func(_v): return Vector2(e1, TAU - e1), "top": func(a): return float(topf.call(a)) + float(rf.call(float(a))), "hem": func(a): return y1 + float(rf.call(float(a))),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return col, "gain": 3.0, "lift": lift, "skin": cg["sk"], "th": 0.003, "inner": col.darkened(0.3)})


## Ön kenar pervazı: yakadan etek ucuna, kenarın iç yanında
static func _coat_edge(k, cg: Dictionary, da: float, hw: float, d: float, col: Color, y0: float) -> void:
	var pt: Callable = cg["pt"]
	var ef: Callable = cg["e"]
	var y1: float = float(cg["hem_y"]) + float((cg["rf"] as Callable).call(float(ef.call(float(cg["hem_y"]))))) + 0.004
	for sg in [1.0, -1.0]:
		var pts := []
		var ou := []
		for j in 44:
			var y: float = lerpf(y0, y1, float(j) / 43.0)
			var a: float = float(ef.call(y)) + da
			var q: Vector3 = pt.call(a * sg, y)
			pts.append(q)
			ou.append(P._out(q, 0.04))
		k.strip(pts, ou, hw, d, col, false, cg["sk"])


## Yazı: giysinin kendi ağırlığıyla (bel altında kumaştan ayrılmaz)
static func _coat_glyph(k, cg: Dictionary, cy: float, s: float, strokes: Array, w: float, col: Color, lift := 0.0065) -> void:
	for q in strokes:
		P._strap(k, cg["keys"], [Vector2(-float(q[0]) * s, cy + float(q[1]) * s), Vector2(-float(q[2]) * s, cy + float(q[3]) * s)], false, w, lift, 0.0015, col, 3, cg["sk"])


## Giysi kıvrımı: kalça altında iri dikey dalgalar, ön kenar düz kalır
static func _coat_fold(k, hem: float, amp: float, n1 := 7.0, n2 := 13.0) -> Callable:
	var H: float = k.H
	var N: float = k.N
	var C: float = k.C
	return func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var fe: float = smoothstep(0.05, 0.42, aw)
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var bk: float = smoothstep(1.2, 2.2, aw)
		var sk: float = pow(t, 0.9) * (amp * (1.0 + 0.2 * bk) * sin(a * n1 + 0.6) + amp * 0.5 * sin(a * n2 + 1.9))
		var up: float = (1.0 - t) * 0.007 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y)
		return fe * (sk + up)


static func _coat_keys(k, b: Dictionary, pu: float, hem: float, wx: float, wf: float, wb: float) -> Array:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var hp: Vector3 = b["hp"]
	return [P._kp(nk, k.N + 0.012, 0.03), [k.N - 0.055, ch.x, ch.y * 0.95, ch.z * 1.05], P._kp(ch, k.C - 0.03, pu), P._kp(b["wa"], k.H + 0.12, pu + 0.012), P._kp(hp, k.H - 0.04, pu + 0.02),
		[k.K + 0.05, hp.x + wx * 0.68, hp.y + wf * 0.8, hp.z - wb * 0.72], [hem, hp.x + wx, hp.y + wf, hp.z - wb]]


## Çan kol: omuzdan bileğe genişler, ağız bandı ayrı kat, içi astarlı
static func _bell(k, ar: Dictionary, col: Color, lin: Color, flare: float, s1: float, band: Color, bw: float, sd_v := 1.6) -> void:
	var en: float = ar["kn"]
	var fl := func(s: float) -> float: return pow(clampf((s - en + 0.16) / (s1 - en + 0.16), 0.0, 1.0), 1.4)
	var fo := func(s: float, a: float) -> float:
		var q: float = fl.call(s)
		return (0.003 + 0.008 * q) * P._lf(s, a, sd_v) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
	var sf := func(s: float, a: float) -> float: return 0.02 + flare * float(fl.call(s)) + float(fo.call(s, a))
	P._lt(k, ar, sf, func(s, a, ins): return lin if ins else P._fs(col, float(fo.call(float(s), float(a))), 16.0), 0.0, s1, 32, 24, 0.02)
	K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, lin, 0.14, s1, 18, 24)
	P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0028, func(_s, _a, ins): return band.darkened(0.3) if ins else band, s1 - bw, s1 + 0.002, 4, 24)


## Hakama paçası: dizden aşağı genişleyen, bıçak pliler; iç yan dar (iki paça birbirine girmez)
static func _hakama_leg(k, le: Dictionary, col: Color, wide: float, s1: float, sd_v: float) -> void:
	var sg: float = le["sg"]
	var pl := func(s: float, a: float) -> float: return _tri(a * 9.0 + sd_v) * smoothstep(0.03, 0.22, s)
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		return (0.02 + wide * smoothstep(0.0, 0.8, s)) * (1.0 - 0.5 * inn) + 0.0095 * float(pl.call(s, a))
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.42)
		return col.darkened(clampf(-float(pl.call(float(s), float(a))), 0.0, 1.0) * 0.2), 0.0, s1, 26, 45, 0.05)


## Kimono üstü + hakama kalçası + obi: iki Kage cübbesinin altı
static func _kimono_base(k, b: Dictionary, kim: Color, juban: Color, hak: Color, obi: Color) -> Array:
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var inn := P._inner(k, b, func(_i, _j, _p): return juban, 0.006)
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var keys := [P._kp(nk, N + 0.012, 0.02), [N - 0.055, ch.x * 0.92, ch.y * 0.9, ch.z * 0.98], P._kp(ch, C - 0.03, 0.016), P._kp(wa, H + 0.12, 0.016), P._kp(hp, H - 0.06, 0.016)]
	var yv: float = C - 0.07
	var tp := func(a: float) -> float: return lerpf(yv, N + 0.012, pow(clampf(absf(a) / 0.62, 0.0, 1.0), 1.15))
	var ff := func(a: float, y: float, _v: float) -> float:
		return 0.01 * sin(a * 7.0 + y * 9.0) * smoothstep(C, H + 0.05, y) + 0.004 * sin(a * 4.0 - y * 14.0)
	var kg := P._cl(k, {"keys": keys, "ny": 20, "na": 48, "top": func(a): return tp.call(float(a)), "hem": func(_a): return H - 0.06, "fold": ff, "col": func(_a, _y, _v): return kim, "gain": 5.0, "th": 0.0, "skin": func(p): return k.torso_skin(p.y)})
	# yaka: sağ kanat altta, sol kanat üstte biner
	P._line(k, keys, [Vector2(0.56, N - 0.02), Vector2(0.28, C - 0.0), Vector2(-0.02, yv - 0.005), Vector2(-0.3, C - 0.2), Vector2(-0.62, H + 0.1)], 0.0052, 0.002, 0.0026, kim.darkened(0.3), 6)
	P._line(k, keys, [Vector2(0.58, N - 0.0), Vector2(0.3, C + 0.03), Vector2(0.0, yv + 0.012)], 0.0115, 0.002, 0.0034, juban, 6)
	P._line(k, keys, [Vector2(-0.58, N - 0.0), Vector2(-0.3, C + 0.03), Vector2(-0.04, yv + 0.012)], 0.0115, 0.002, 0.0034, juban, 6)
	var _unused = [inn, kg]
	# hakama kalçası: belden inen pliler bacak boşluğunu kapatır
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var hk := [P._kp(bl, H + 0.1, 0.026), P._kp(hp, H - 0.05, 0.034), [H - 0.13, hp.x + 0.05, hp.y + 0.05, hp.z - 0.05]]
	var pf := func(a: float, y: float, _v: float) -> float: return 0.02 * _tri(a * 9.0 + 0.5) * smoothstep(H + 0.06, H - 0.05, y)
	P._cl(k, {"keys": hk, "ny": 10, "na": 90, "top": func(_a): return H + 0.1, "hem": func(_a): return H - 0.13, "fold": pf, "col": func(a, y, _v): return hak.darkened(clampf(-_tri(float(a) * 9.0 + 0.5), 0.0, 1.0) * 0.2 * smoothstep(H + 0.06, H - 0.03, float(y))), "gain": 0.0, "th": 0.004})
	# obi: kat kat bez (arkası cübbenin altında kalır)
	var by: float = H + 0.06
	var kb := [P._kp(bl, by + 0.06, 0.02), P._kp(bl, by - 0.06, 0.024)]
	P._sash(k, kb, by, 0.036, 0.0, obi, 0.1)
	P._sash(k, kb, by - 0.004, 0.012, 0.006, obi.darkened(0.05), 0.05)
	return keys


## Boyun örtüsü: omuza dökülen kalın sargı
static func _cowl(k, ck: Array, y0: float, hemf: Callable, wd: float, col: Color, lin: Color, swags: float, amp: float) -> Dictionary:
	var sk := func(p): return K._cape_skin(k, p, wd)
	var ff := func(a: float, _y: float, v: float) -> float:
		var w: float = sin(float(v) * PI * swags + cos(a) * 1.15)
		return amp * w * smoothstep(0.0, 0.2, float(v)) + 0.008 * sin(a * 11.0 + 0.7) * float(v)
	var cg := P._cl(k, {"keys": ck, "ny": 26, "na": 76, "top": func(_a): return y0, "hem": hemf, "fold": ff, "col": func(_a, _y, _v): return col, "gain": 7.5, "skin": sk, "th": 0.006, "inner": lin})
	# kıvrım vadileri: omuzdan omuza inen gerçek katlar (düz beyazda dökümü okutan çizgi)
	for ctr in [0.0, PI]:
		for m in 3:
			var pts := []
			for i in 25:
				var a: float = ctr + lerpf(-1.3, 1.3, float(i) / 24.0)
				var v: float = (PI * 1.5 + TAU * m - 1.15 * cos(a)) / (PI * swags)
				if v < 0.16 or v > 0.95:
					continue
				var aw: float = wrapf(a, -PI, PI)
				var y: float = lerpf(y0, float(hemf.call(aw)), v)
				pts.append(P._on(ck, a, y, float(ff.call(aw, y, v)) + 0.01))
			if pts.size() >= 6:
				P._cord(k, pts, 0.0052, col.darkened(0.2), false, sk)
	return cg


# ------------------------------------------------------------------ Gōken: kolsuz dar yeşil tulum, kırmızı bel bağı, sargılı ön kol, dilimli turuncu boyunluk, içi ağırlıklı tozluk (ref n_lee, lee_weights)
static func _goken(k) -> void:
	var gr := Color(0.13, 0.37, 0.22)
	var gd := gr.darkened(0.32)
	var org := Color(0.92, 0.5, 0.13)
	var wh := Color(0.9, 0.88, 0.82)
	var rd := Color(0.72, 0.16, 0.13)
	var gold := Color(0.8, 0.66, 0.34)
	var sk_c := _skin_col(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var keys := _torso(k, b, 0.007, gr, func(a, y):
		var t: float = clampf((C - float(y)) / maxf(0.05, C - H), 0.0, 1.0)
		return t * (0.012 * sin(float(a) * 7.0 + float(y) * 12.0) + 0.006 * sin(float(a) * 13.0 - float(y) * 20.0)))
	K._seat(k, b, gr)
	# ön dikiş + göğüs ve yan dikişleri
	P._line(k, keys, [Vector2(0.0, N - 0.045), Vector2(0.0, H + 0.08)], 0.0034, 0.0015, 0.0016, gd, 8)
	for sg in [1.0, -1.0]:
		P._line(k, keys, [Vector2(sg * 0.95, C + 0.0), Vector2(sg * 0.55, C - 0.05), Vector2(sg * 0.12, C - 0.075)], 0.0028, 0.0015, 0.0012, gd, 5)
		P._line(k, keys, [Vector2(sg * PI * 0.5, C - 0.05), Vector2(sg * PI * 0.5, H + 0.08)], 0.003, 0.0015, 0.0012, gd, 6)
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		# kolsuz omuz: tulum kolu oyuğun hemen altında biter, gerisi ten
		P._bare(k, ar, sk_c, 0.04, en + 0.08)
		P._lt(k, ar, func(s, _a): return 0.007 - 0.002 * float(s), func(s, _a, ins): return gd if ins else (gd if float(s) > 0.135 else gr), 0.0, 0.15, 8, 20)
		P._armhole(k, ar, 0.15, 0.008, 0.0042, gd)
		# ön kol sargısı + el sargısı
		P._lt(k, ar, func(_s, _a): return 0.0005, func(_s, _a, ins): return wh.darkened(0.34) if ins else wh.darkened(0.16), en - 0.03, 0.97, 16, 18)
		P._wraps(k, ar, en - 0.015, 0.955, 13, 0.0035, 0.0118, wh, 0.0075)
		K._glove(k, sd, ar, wh.darkened(0.05), wh.darkened(0.14))
		# dar paça: diz kırışığı
		var pa := func(s: float, a: float) -> float:
			return 0.0055 + 0.0036 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 34.0) + 0.0016 * P._lf(s, a, 1.3)
		P._lt(k, le, pa, func(s, a, ins): return gd if ins else P._fs(gr, float(pa.call(float(s), float(a))) - 0.0055, 26.0), 0.0, kn + 0.14, 34, 22)
		# tozluk: dikey fitil, üstte kalın ağız, ayak bileğinde yığılma, incikte levha çıkıntısı
		var lg := func(s: float, a: float) -> float:
			var u: float = clampf((s - kn - 0.07) / (0.995 - kn - 0.07), 0.0, 1.0)
			var rib: float = 0.0042 * cos(a * 9.0) * (1.0 - 0.45 * smoothstep(0.72, 0.95, u))
			var cuff: float = 0.012 * exp(-pow((u - 0.03) / 0.035, 2.0))
			var sl: float = smoothstep(0.62, 0.92, u) * (0.009 + 0.0065 * sin(u * 38.0 + a * 1.5))
			var aw: float = absf(wrapf(a, -PI, PI))
			var pla: float = 0.0085 * smoothstep(0.9, 0.62, aw) * smoothstep(0.1, 0.17, u) * smoothstep(0.56, 0.48, u)
			return 0.011 + 0.005 * u + rib + cuff + sl + pla
		P._lt(k, le, lg, func(s, a, ins):
			if ins:
				return org.darkened(0.45)
			var rb: float = cos(float(a) * 9.0)
			return org.darkened(clampf(-rb, 0.0, 1.0) * 0.2).lightened(clampf(rb, 0.0, 1.0) * 0.05), kn + 0.07, 0.995, 30, 36, 0.03)
	# sağ uyluk sargısı (kanonda kılıf bandı)
	var rl := P._limb(k, "Right", true)
	P._wraps(k, rl, 0.3, 0.37, 3, 0.0075, 0.0125, wh, 0.003)
	# kırmızı bel bağı + metal plaka
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var by: float = H + 0.055
	var kb := [P._kp(bl, by + 0.05, 0.012), P._kp(bl, by - 0.05, 0.014)]
	P._sash(k, kb, by, 0.025, 0.0, rd, 0.13)
	var fc: Array = P._sa(kb, 0.0, by, 0.012)
	P._boxr(k, fc[0], Vector3(0.05, 0, 0), Vector3(0, 0.021, 0), (fc[1] as Vector3) * 0.005, gold, [["Hips", 1.0]], 0.22)
	P._boxr(k, (fc[0] as Vector3) + (fc[1] as Vector3) * 0.0045, Vector3(0.036, 0, 0), Vector3(0, 0.0125, 0), (fc[1] as Vector3) * 0.002, gold.darkened(0.2), [["Hips", 1.0]], 0.2)
	# dilimli boyunluk: üç kat dolgu halka
	var nkk := [[N + 0.1, nk.x + 0.008, nk.y + 0.008, nk.z - 0.008], [N + 0.02, nk.x + 0.02, nk.y + 0.018, nk.z - 0.02], [N - 0.03, nk.x + 0.05, nk.y + 0.036, nk.z - 0.04], [N - 0.08, ch.x * 0.6, ch.y * 0.72, ch.z * 0.78]]
	P._roll(k, nkk, N - 0.05, 0.028, 9, 0.006, org)
	P._roll(k, nkk, N - 0.0, 0.029, 9, 0.009, org.lightened(0.03))
	P._roll(k, nkk, N + 0.048, 0.025, 9, 0.008, org)


# ------------------------------------------------------------------ Akai Kenpō: kızıl çapraz kapanışlı dövüş ceketi, siyah omuz ve bilek, kurbağa düğmeler, siyah taktik pantolon, parmaksız eldiven
static func _kenpo(k) -> void:
	var rd := Color(0.66, 0.12, 0.13)
	var blk := Color(0.1, 0.1, 0.12)
	var lin := Color(0.46, 0.09, 0.1)
	var gy := Color(0.36, 0.36, 0.4)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return blk, 0.006)
	K._seat(k, b, blk)
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sf := func(s: float, a: float) -> float:
			return 0.0035 * P._lf(s, a, 0.8) + 0.0055 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		P._lt(k, ar, func(s, a): return 0.011 + float(sf.call(float(s), float(a))), func(s, a, ins): return lin if ins else P._fs(rd, float(sf.call(float(s), float(a))), 24.0), 0.0, 0.86, 30, 20)
		# siyah bilek kapağı: dirsek altından bileğe sivrilerek
		P._lts(k, ar, func(s, a): return 0.0145 + 0.6 * float(sf.call(float(s), float(a))) * 0.5, func(_s, _a, ins): return blk.darkened(0.3) if ins else blk, func(a): return 0.68 + 0.05 * cos(a), 0.9, 12, 22)
		K._glove(k, sd, ar, blk, gy)
		var pa: Callable = K._pant(k, le, blk.lightened(0.03), 0.012, 0.018, 1.0, 1.4 if sd == "Left" else 3.2)
		# diz koruyucu
		K._shell(k, le, kn - 0.075, kn + 0.065, -0.95, 0.95, func(s, a): return float(pa.call(s, a)) + 0.002, 0.007, func(u, v, ins):
			return gy.darkened(0.45) if ins else gy.darkened(0.12 + 0.2 * absf(float(v) - 0.5) + 0.1 * absf(float(u) - 0.5)), 10, 12)
		# uyluk cebi + kayış
		var ao: float = sg * PI * 0.5
		K._shell(k, le, 0.35, 0.49, ao - 0.62, ao + 0.62, func(s, a): return float(pa.call(s, a)) + 0.001, 0.008, func(_u, v, ins):
			return blk.darkened(0.2) if ins else blk.lightened(0.09 if float(v) < 0.26 else 0.04), 8, 10)
		k.wrap_turn(P._lp(le, 0.39), P._ld(le, 0.39), P._lr(le, 0.39) + float(pa.call(0.39, 0.0)) + 0.004, 0.0065, 0.0, gy.darkened(0.3), P._lskin(le, 0.39))
	# ceket: oturan bel, kalçayı örten kısa etek
	var hem: float = H - 0.15
	P._cur_leg = 0.5
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 0.99, ch.y * 0.94, ch.z * 1.04], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.018), P._kp(hp, H - 0.03, 0.04), [hem, hp.x + 0.065, hp.y + 0.075, hp.z - 0.065]]
	var ff := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		return t * (0.02 * sin(a * 7.0 + 0.5) + 0.009 * sin(a * 13.0 + 2.1)) + (1.0 - t) * (0.0065 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.05, y))
	var jg := P._cl(k, {"keys": keys, "ny": 44, "na": 92, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": ff, "col": func(_a, _y, _v): return rd, "gain": 5.2, "th": 0.005, "inner": lin})
	# siyah omuz boyunduruğu: önde göğüse, arkada kürek hizasına iner
	var yk := func(a: float) -> float:
		var aw: float = absf(a)
		return lerpf(C + 0.035, C - 0.015, smoothstep(0.6, 2.4, aw)) - 0.03 * exp(-pow(aw / 0.3, 2.0))
	P._cl(k, {"keys": keys, "ny": 10, "na": 92, "top": func(_a): return N + 0.012, "hem": func(a): return yk.call(float(a)), "col": func(_a, _y, _v): return blk, "lift": 0.003, "th": 0.003, "skin": func(p): return k.torso_skin(p.y)})
	# çapraz kapanış: sol kanat sağa biner; biye + kurbağa düğmeler
	var cl := [Vector2(0.5, N - 0.03), Vector2(0.24, C + 0.01), Vector2(-0.12, C - 0.12), Vector2(-0.42, H + 0.13), Vector2(-0.5, H + 0.08)]
	P._line(k, keys, cl, 0.0085, 0.0035, 0.0034, blk, 7)
	for t in [[0.05, C - 0.05], [-0.16, C - 0.14], [-0.36, H + 0.17], [-0.5, H + 0.09]]:
		var a0: float = t[0]
		var y0: float = t[1]
		var e: Array = P._sa(keys, a0, y0, 0.008)
		P._stud(k, e[0], e[1], 0.0072, gy.lightened(0.2), k.torso_skin(y0))
		for sg2 in [1.0, -1.0]:
			var pts := []
			var ou := []
			for i in 7:
				var v := float(i) / 6.0
				var q: Array = P._sa(keys, a0 + sg2 * lerpf(0.05, 0.25, v), y0 + 0.011 * sin(v * PI) * sg2, 0.006)
				pts.append(q[0])
				ou.append(q[1])
			k.strip(pts, ou, 0.0026, 0.0026, blk.lightened(0.1))
	P._bd(k, K._yl(jg["hem"], 0.009), 0.0075, 0.0026, blk, true, func(p): return P._hs(k, p))
	# kemer: geniş siyah bez, yan düğümlü
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var by: float = H + 0.075
	var kb := [P._kp(bl, by + 0.05, 0.034), P._kp(bl, by - 0.05, 0.034)]
	P._sash(k, kb, by, 0.028, 0.0, blk, 0.2)
	var kn2: Array = P._sa(kb, 0.9, by, 0.01)
	P._boxr(k, kn2[0], Vector3(0.016, 0, -0.008), Vector3(0, 0.017, 0), (kn2[1] as Vector3) * 0.008, blk.lightened(0.05), [["Hips", 1.0]], 0.45)
	for e2 in [[0.86, 0.035, 0.13], [0.96, 0.06, 0.1]]:   # bağın iki ucu ceketin üstüne yatar
		P._strap(k, keys, [Vector2(0.0, by - 0.02), Vector2(0.0, by - 0.02 - float(e2[2]))].map(func(q): return Vector2(_x_at(keys, float(e2[0]), q.y) + float(e2[1]) * (by - 0.02 - q.y), q.y)), true, 0.011, 0.006, 0.003, blk.lightened(0.04), 6)
	# dik yaka
	var ck := [[N + 0.07, nk.x + 0.012, nk.y + 0.012, nk.z - 0.016], [N + 0.02, nk.x + 0.02, nk.y + 0.02, nk.z - 0.022], [N - 0.03, nk.x + 0.042, nk.y + 0.036, nk.z - 0.044]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var cg := P._cl(k, {"keys": ck, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.2, TAU - 0.2), "top": func(a): return N + 0.055 - 0.016 * smoothstep(1.0, 0.2, absf(float(a))), "hem": func(_a): return N - 0.02, "col": func(_a, _y, _v): return blk, "inner": lin, "skin": skt, "th": 0.005})
	P._bd(k, cg["top"], 0.0032, 0.002, rd, false, skt, 0.6)


# ------------------------------------------------------------------ Sennin Shugyō: turuncu-siyah gömlek ve pantolon, kısa kollu kırmızı uzun haori, eteğinde gerçek kenarlı siyah alevler (ref naruto sage mode)
static func _flame(a: float, h0: float, hm: float) -> float:
	var n := 11.0
	var x: float = (a + PI) / TAU * n
	var id: float = floor(x)
	var u: float = x - id
	u = fposmod(u + 0.13 * sin(TAU * u), 1.0)
	var tip: float = pow(1.0 - absf(2.0 * u - 1.0), 1.55)
	var va: float = 0.72 + 0.28 * sin(id * 2.4 + 0.7)
	var small: float = 0.28 * pow(1.0 - absf(fposmod(u * 2.0 + 0.5, 1.0) * 2.0 - 1.0), 2.0)
	return h0 + hm * va * maxf(tip, small)


static func _sennin(k) -> void:
	var org := Color(0.85, 0.46, 0.13)
	var blk := Color(0.11, 0.11, 0.13)
	var rd := Color(0.7, 0.16, 0.13)
	var lin := Color(0.34, 0.07, 0.07)
	var wh := Color(0.86, 0.84, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var tk := _torso(k, b, 0.012, org, func(a, y):
		return 0.009 * sin(float(a) * 6.0 + float(y) * 11.0) * smoothstep(C, H + 0.05, float(y)))
	K._seat(k, b, org.darkened(0.12))
	# siyah omuz + fermuar
	var yk := func(a: float) -> float: return lerpf(C + 0.02, C + 0.0, smoothstep(0.5, 2.4, absf(a)))
	P._cl(k, {"keys": tk, "ny": 10, "na": 72, "top": func(_a): return N + 0.03, "hem": func(a): return yk.call(float(a)), "col": func(_a, _y, _v): return blk, "lift": 0.0035, "th": 0.003, "skin": func(p): return k.torso_skin(p.y)})
	P._line(k, tk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.04)], 0.0052, 0.0035, 0.002, blk, 8)
	P._line(k, tk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.04)], 0.0016, 0.0058, 0.0012, wh, 8)
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.004 * P._lf(s, a, 1.1) + 0.0055 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		P._lt(k, ar, func(s, a): return 0.004 + float(sf.call(float(s), float(a))) * smoothstep(en + 0.02, en + 0.1, float(s)), func(s, a, ins): return org.darkened(0.4) if ins else P._fs(org, float(sf.call(float(s), float(a))), 22.0), 0.2, 0.93, 26, 20)
		P._lt(k, ar, func(_s, _a): return 0.0145, func(_s, _a, ins): return blk.darkened(0.3) if ins else blk, 0.86, 0.945, 4, 20)
		var pa: Callable = K._pant(k, le, org, 0.01, 0.012, 0.94, 2.0 if sd == "Left" else 4.1)
		P._lt(k, le, func(s, a): return float(pa.call(minf(float(s), 0.94), a)) + 0.001, func(_s, _a, _i): return blk, 0.84, 0.985, 8, 18)
		P._wraps(k, le, 0.85, 0.975, 6, float(pa.call(0.9, 0.0)) + 0.006, 0.0125, wh.darkened(0.08), 0.007)
	# haori: baldıra iner, önü açık
	var hem: float = lerpf(k.K, k.F, 0.58)
	var keys := _coat_keys(k, b, 0.036, hem, 0.15, 0.11, 0.25)
	var ef := func(y: float) -> float: return 0.26 + 0.34 * pow(smoothstep(C - 0.05, N + 0.012, y), 1.2)
	var cg := _coat(k, {"keys": keys, "hem": hem, "e": ef, "fold": _coat_fold(k, hem, 0.05), "col": rd, "lin": lin, "gain": 4.2})
	# alevler: üst kenarı alev dili olan ayrı siyah kat
	_coat_layer(k, cg, func(a): return _flame(float(a), hem + 0.05, 0.25), hem, blk, 330, 6)
	_coat_edge(k, cg, 0.05, 0.0145, 0.0034, rd.darkened(0.2), N - 0.02)
	# yaka: boyunu çeviren haori bandı
	var ck := [[N + 0.075, nk.x + 0.03, nk.y + 0.024, nk.z - 0.034], [N + 0.01, nk.x + 0.04, nk.y + 0.034, nk.z - 0.04], [N - 0.05, nk.x + 0.072, nk.y + 0.05, nk.z - 0.066]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	P._cl(k, {"keys": ck, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.12, TAU - 0.12), "top": func(a): return N + 0.07 - 0.012 * smoothstep(1.0, 0.1, absf(float(a))), "hem": func(_a): return N - 0.04, "col": func(_a, _y, _v): return blk, "inner": blk.darkened(0.3), "skin": skt, "th": 0.005})
	var ed := [[N + 0.03, nk.x + 0.058, nk.y + 0.052, nk.z - 0.058], [N - 0.03, nk.x + 0.09, nk.y + 0.06, nk.z - 0.085], [N - 0.06, ch.x * 0.72, ch.y * 0.82, ch.z * 0.92]]
	P._cl(k, {"keys": ed, "ny": 6, "na": 56, "rng": func(_v): return Vector2(0.62, TAU - 0.62), "top": func(_a): return N + 0.028, "hem": func(_a): return N - 0.055, "col": func(_a, _y, _v): return rd.darkened(0.2), "inner": lin, "skin": skt, "th": 0.005})
	# kısa geniş kol: dirsek hizasında biter
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		_bell(k, ar, rd, lin, 0.02, float(ar["kn"]) + 0.03, blk, 0.035, 2.2)


# ------------------------------------------------------------------ Kage Shōzoku (genel): lacivert gömlek ve dar pantolon üstüne kolsuz, geniş omuzlu beyaz uzun yelek-cübbe; kırmızı biye, göğüs bağı, sırtta 影
static func _kage(k) -> void:
	var nv := Color(0.15, 0.2, 0.33)
	var wh := Color(0.93, 0.93, 0.9)
	var rd := Color(0.78, 0.2, 0.15)
	var lin := Color(0.72, 0.7, 0.68)
	var wr := Color(0.84, 0.83, 0.8)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var tk := _torso(k, b, 0.01, nv, func(a, y): return 0.008 * sin(float(a) * 6.0 + float(y) * 12.0) * smoothstep(C, H + 0.05, float(y)))
	K._seat(k, b, nv.darkened(0.12))
	P._line(k, tk, [Vector2(0.0, N - 0.03), Vector2(0.0, C - 0.14)], 0.003, 0.0015, 0.0016, nv.darkened(0.3), 5)
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		var en: float = ar["kn"]
		var sf := func(s: float, a: float) -> float:
			return 0.0034 * P._lf(s, a, 0.7) + 0.005 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		P._lt(k, ar, func(s, a): return 0.009 + float(sf.call(float(s), float(a))), func(s, a, ins): return nv.darkened(0.4) if ins else P._fs(nv, float(sf.call(float(s), float(a))), 24.0), 0.0, 0.9, 30, 20)
		P._lt(k, ar, func(_s, _a): return 0.006, func(_s, _a, _i): return wr.darkened(0.16), 0.8, 0.965, 8, 16)
		P._wraps(k, ar, 0.81, 0.955, 6, 0.0095, 0.0115, wr, 0.006)
		var pa: Callable = K._pant(k, le, nv, 0.009, 0.012, 1.0, 1.8 if sd == "Left" else 3.6)
		P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.0025, func(_s, _a, _i): return wr.darkened(0.16), 0.82, 0.985, 8, 16)
		P._wraps(k, le, 0.83, 0.975, 6, float(pa.call(0.9, 0.0)) + 0.0065, 0.0125, wr, 0.007)
		P._armhole(k, ar, 0.075, 0.018, 0.0062, rd)
	var hem: float = k.K - 0.03
	var keys := _coat_keys(k, b, 0.04, hem, 0.1, 0.085, 0.13)
	keys[1] = [N - 0.055, ch.x * 1.06, ch.y * 0.97, ch.z * 1.07]
	var ef := func(y: float) -> float: return 0.3 + 0.28 * pow(smoothstep(C - 0.08, N + 0.012, y), 1.2)
	var cg := _coat(k, {"keys": keys, "hem": hem, "e": ef, "fold": _coat_fold(k, hem, 0.04), "col": wh, "lin": lin, "ny": 34, "na": 80})
	_coat_layer(k, cg, func(_a): return hem + 0.03, hem + 0.006, rd)
	_coat_edge(k, cg, 0.035, 0.0105, 0.003, rd, N - 0.02)
	# dik ince yaka: içi kırmızı
	var ck := [[N + 0.075, nk.x + 0.036, nk.y + 0.03, nk.z - 0.036], [N + 0.012, nk.x + 0.044, nk.y + 0.036, nk.z - 0.044], [N - 0.04, nk.x + 0.07, nk.y + 0.05, nk.z - 0.066]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var cl := P._cl(k, {"keys": ck, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.5, TAU - 0.5), "top": func(a): return N + 0.07 - 0.018 * smoothstep(1.4, 0.5, absf(float(a))), "hem": func(_a): return N - 0.035, "col": func(_a, _y, _v): return wh, "inner": rd.darkened(0.08), "skin": skt, "th": 0.005})
	P._bd(k, cl["top"], 0.0034, 0.002, rd, false, skt, 0.6)
	# göğüs bağı: iki kanadı tutan kırmızı ip + düğüm
	var pt: Callable = cg["pt"]
	var yb: float = C - 0.06
	var ql: Vector3 = pt.call(float(ef.call(yb)) + 0.06, yb)
	var qr: Vector3 = pt.call(-float(ef.call(yb)) - 0.06, yb)
	var mid := Vector3(0.0, yb - 0.018, maxf(ql.z, qr.z) + 0.004)
	P._cord(k, [ql, ql.lerp(mid, 0.5) + Vector3(0, -0.006, 0.004), mid, qr.lerp(mid, 0.5) + Vector3(0, -0.006, 0.004), qr], 0.0042, rd, false, func(p): return k.torso_skin(p.y), 1.2)
	P._boxr(k, mid + Vector3(0, 0, 0.004), Vector3(0.012, 0, 0), Vector3(0, 0.011, 0), Vector3(0, 0, 0.007), rd.darkened(0.08), k.torso_skin(mid.y), 0.45)
	_coat_glyph(k, cg, C - 0.13, 0.092, A.G_KAGE, 0.0058, rd)


# ------------------------------------------------------------------ Hokage (ref Hiruzen_Sarutobi_(Hokage), Hokage_Hashirama): kızıl kimono, beyaz obi ve hakama, boyna sarılı beyaz atkı, önü açık uzun beyaz cübbe ve çan kollar, kızıl bantlar, sırtta 火
static func _hokage(k) -> void:
	var kim := Color(0.6, 0.12, 0.1)
	var wh := Color(0.95, 0.94, 0.91)
	var hak := Color(0.92, 0.92, 0.89)
	var rd := Color(0.8, 0.14, 0.12)
	var lin := Color(0.74, 0.72, 0.7)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	_kimono_base(k, b, kim, Color(0.92, 0.9, 0.85), hak, wh)
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return kim.darkened(0.4) if ins else kim, 0.2, 0.965, 20, 16)
		P._lt(k, le, func(_s, _a): return 0.004, func(_s, _a, _i): return wh.darkened(0.04), 0.55, 0.99, 10, 14)
		_hakama_leg(k, le, hak, 0.058, 0.965, 0.6 if sd == "Left" else 1.9)
	var hem: float = lerpf(k.K, k.F, 0.34)
	var keys := _coat_keys(k, b, 0.042, hem, 0.15, 0.115, 0.185)
	var ef := func(y: float) -> float: return 0.3 + 0.24 * pow(smoothstep(C - 0.05, N + 0.012, y), 1.2)
	var cg := _coat(k, {"keys": keys, "hem": hem, "e": ef, "fold": _coat_fold(k, hem, 0.05), "col": wh, "lin": lin})
	_coat_layer(k, cg, func(_a): return hem + 0.075, hem + 0.004, rd)
	_coat_layer(k, cg, func(_a): return hem + 0.102, hem + 0.09, rd.darkened(0.12), 88, 2)
	_coat_edge(k, cg, 0.05, 0.0135, 0.0032, wh.darkened(0.07), N - 0.05)
	for sd in ["Left", "Right"]:
		_bell(k, P._limb(k, sd, false), wh, lin, 0.052, 0.915, rd, 0.075, 1.4 if sd == "Left" else 3.0)
	# boyun atkısı: omuza inmeyen, göğüste V ile biten sargı
	var wd: float = nk.x + 0.14
	var ck := [[N + 0.085, nk.x + 0.026, nk.y + 0.024, nk.z - 0.03], [N + 0.02, nk.x + 0.05, nk.y + 0.042, nk.z - 0.05], [N - 0.05, nk.x + 0.1, nk.y + 0.075, nk.z - 0.09], [N - 0.14, wd, ch.y * 0.96, ch.z * 1.08]]
	_cowl(k, ck, N + 0.08, func(a):
		return N - 0.135 + 0.05 * smoothstep(0.0, 1.5, absf(float(a))) - 0.02 * smoothstep(1.8, 3.0, absf(float(a))), maxf(wd, ch.x), wh, lin, 4.2, 0.04)
	P._roll(k, ck, N + 0.066, 0.017, 7, 0.003, wh)
	_coat_glyph(k, cg, C - 0.17, 0.1, A.G_HI, 0.0075, rd)


# ------------------------------------------------------------------ Kazekage (ref Kazekage_Gaara, Fourth_Kazekage): deniz yeşili kimono, beyaz hakama, omuzları ve üst kolu örten iri sargı örtü, önü dar açık baldır boyu cübbe, çift yeşil bant, sırtta 風
static func _kazekage(k) -> void:
	var kim := Color(0.11, 0.33, 0.28)
	var wh := Color(0.95, 0.94, 0.91)
	var hak := Color(0.91, 0.92, 0.89)
	var tl := Color(0.16, 0.45, 0.38)
	var lin := Color(0.72, 0.74, 0.71)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	_kimono_base(k, b, kim, Color(0.86, 0.9, 0.86), hak, tl.darkened(0.15))
	for sd in ["Left", "Right"]:
		var ar := P._limb(k, sd, false)
		var le := P._limb(k, sd, true)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return kim.darkened(0.4) if ins else kim, 0.2, 0.965, 20, 16)
		P._lt(k, le, func(_s, _a): return 0.004, func(_s, _a, _i): return wh.darkened(0.04), 0.55, 0.99, 10, 14)
		_hakama_leg(k, le, hak, 0.05, 0.975, 2.4 if sd == "Left" else 0.2)
	var hem: float = lerpf(k.K, k.F, 0.72)
	var keys := _coat_keys(k, b, 0.04, hem, 0.17, 0.12, 0.215)
	var ef := func(y: float) -> float: return 0.17 + 0.36 * pow(smoothstep(C - 0.1, N + 0.012, y), 1.2)
	var f0 := _coat_fold(k, hem, 0.056, 8.0, 15.0)
	var ff := func(a: float, y: float) -> float:   # sırt ortası düz pano: yazı kıvrımda kırılmaz
		return float(f0.call(a, y)) * (1.0 - 0.94 * exp(-pow((absf(wrapf(a, -PI, PI)) - PI) / 0.42, 2.0)))
	var cg := _coat(k, {"keys": keys, "hem": hem, "e": ef, "fold": ff, "col": wh, "lin": lin, "ny": 46})
	_coat_layer(k, cg, func(_a): return hem + 0.045, hem + 0.004, tl)
	_coat_layer(k, cg, func(_a): return hem + 0.09, hem + 0.066, tl)
	_coat_edge(k, cg, 0.035, 0.0105, 0.003, tl, N - 0.05)
	for sd in ["Left", "Right"]:
		_bell(k, P._limb(k, sd, false), wh, lin, 0.052, 0.93, tl, 0.05, 2.0 if sd == "Left" else 3.5)
	# iri omuz örtüsü: boyundan üst kola, önde ve arkada bollukla dökülür
	var wd: float = ch.x + 0.1
	var ck := [[N + 0.09, nk.x + 0.032, nk.y + 0.03, nk.z - 0.036], [N + 0.02, nk.x + 0.075, nk.y + 0.058, nk.z - 0.07], [N - 0.05, wd * 0.9, ch.y + 0.012, ch.z - 0.04], [C - 0.05, wd * 1.02, ch.y + 0.036, ch.z - 0.06], [C - 0.24, wd * 1.05, ch.y + 0.042, ch.z - 0.07]]
	_cowl(k, ck, N + 0.085, func(a):
		var aw: float = absf(float(a))
		return C - 0.115 - 0.095 * pow(cos(aw), 2.0) - 0.012 * smoothstep(1.6, 3.0, aw), wd, wh, lin, 5.5, 0.036)
	P._roll(k, ck, N + 0.07, 0.02, 6, 0.004, wh)
	_coat_glyph(k, cg, H - 0.11, 0.092, D.G_KAZE, 0.0068, tl)
