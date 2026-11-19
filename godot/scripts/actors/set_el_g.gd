extends RefCounted
## Elle modellenmiş setler, parti g: set_kiri_kenshi, set_kurosuki, set_kiri_kunoichi, set_kiri_atki, set_suna_rojo, set_kazekiri. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e'den gelir (aynı işi yapan ikinci kopya olmasın); bu dosyada yalnız bu setlere özgü parçalar var.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")

const DONE := ["set_kiri_kenshi", "set_kurosuki", "set_kiri_kunoichi", "set_kiri_atki", "set_suna_rojo", "set_kazekiri"]


static func recipe(k, sid: String) -> void:
	P._cur_long = false
	P._cur_leg = 0.58
	match sid:
		"set_kiri_kenshi": _kiri_kenshi(k)
		"set_kurosuki": _kurosuki(k)
		"set_kiri_kunoichi": _kiri_kunoichi(k)
		"set_kiri_atki": _kiri_atki(k)
		"set_suna_rojo": _suna_rojo(k)
		"set_kazekiri": _kazekiri(k)
	P._cur_long = false


# ------------------------------------------------------------------ ortak ölçü
static func _b(k) -> Dictionary:
	var b := P._base(k)
	b["bl"] = k.M(k.H + 0.05, 0.3)
	b["skin"] = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	return b


## Kalça dolgusu: bacak tüpleri arasında boşluk kalmaz
static func _pelvis(k, b: Dictionary, col: Color, add := 0.014) -> void:
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	SE.body_layer(k, [P._kp(bl, k.H + 0.04, 0.002), P._kp(hp, k.H - 0.05, add), [k.H - 0.13, hp.x * 0.6, hp.y * 0.62, hp.z * 0.62]], 8, 32, func(_i, _j, _p): return col)


## Boyun altı ten
static func _chest(k, b: Dictionary, col: Color) -> void:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	SE.body_layer(k, [[k.N + 0.03, nk.x, nk.y, nk.z], [k.N - 0.05, ch.x * 0.86, ch.y * 0.72, ch.z * 0.78], [k.C - 0.06, ch.x * 0.97, ch.y * 0.84, ch.z * 0.84]], 8, 28, func(_i, _j, _p): return col)


## Kol: omuz başındaki ölçü gövdeye karışmasın (kol şişmez)
static func _arm(k, sd: String) -> Dictionary:
	var l := P._limb(k, sd, false)
	var rad: Array = l["rad"]
	var m: float = rad[int(rad.size() * 0.45)]
	for i in rad.size():
		rad[i] = minf(float(rad[i]), m * 1.28)
	return l


## Eğik bel halkası noktaları: yf(a) -> y
static func _ring_t(keys: Array, yf: Callable, add: float, n := 72) -> Array:
	var pts := []
	for i in n:
		var a := TAU * i / n - PI
		var y: float = yf.call(a)
		var s: Array = SE.El.key_at(keys, y)
		var q: Vector2 = SE.El.sup(a, float(s[1]) + add, float(s[2]) + add, float(s[3]) - add)
		pts.append(Vector3(q.x, y, q.y))
	return pts


## Uzuv kesitinde bu açı ne kadar aşağı bakıyor (geniş kol yeninin sarkması)
static func _sag(l: Dictionary, s: float, a: float) -> float:
	var d := P._ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri := (-d).cross(fw).normalized()
	return maxf(0.0, -(ri * sin(a) + fw * cos(a)).y)


## Yassı kumaş sargı turu (atkı, örtü, boyun sargısı). o: tilt, ph, wob, flat, crease, n, seg, skin
static func _coil(k, y: float, w: float, zf: float, zb: float, r: float, col: Color, o := {}) -> void:
	var tilt: float = o.get("tilt", 0.0)
	var ph: float = o.get("ph", 0.0)
	var wob: float = o.get("wob", 0.0)
	var flat: float = o.get("flat", 0.72)
	var crease: float = o.get("crease", 0.14)
	var drop: float = o.get("drop", 0.0)   # önde aşağı iner: çeneyi kapatmaz
	var n: int = o.get("n", 48)
	var seg: int = o.get("seg", 10)
	var sf: Callable = o.get("skin", func(p: Vector3) -> Array: return k.torso_skin(p.y))
	var rows := []
	var cc := []
	for j in n:
		var a := TAU * j / n - PI
		var q: Vector2 = SE.El.sup(a, w, zf, zb)
		var d := Vector3(q.x, 0.0, q.y).normalized()
		var c := Vector3(q.x, y + tilt * sin(a + ph) + wob * sin(a * 2.0 + ph * 1.7) - drop * (0.5 + 0.5 * cos(a)), q.y)
		var rr := r * (1.0 + 0.1 * sin(a * 3.0 + ph * 2.0) + 0.05 * sin(a * 7.0 + ph))
		var ro := []
		var cr := []
		for i in seg:
			var t := TAU * i / seg
			var st := sin(t)
			ro.append(c + d * cos(t) * rr + Vector3.UP * st * rr * flat)
			cr.append(col.darkened(clampf((0.25 - st) * 0.22, 0.0, 0.3) + crease * (0.5 + 0.5 * sin(a * 5.0 + ph * 3.0)) * (1.0 - absf(st))))
		rows.append(ro)
		cc.append(cr)
	rows.append(rows[0])
	cc.append(cc[0])
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return sf.call(p))


## Alttaki giysinin kesitinden örtü anahtarı: üstüne biner, içinden çıkmaz
static func _ov(keys: Array, y: float, ax: float, az: float, sx := 1.0) -> Array:
	var e: Array = SE.El.key_at(keys, y)
	return [y, float(e[1]) * sx + ax, float(e[2]) + az, float(e[3]) - az]


## Boyna sarılı turlar: list [[dy, ek, r], ...]
static func _rolls(k, b: Dictionary, col: Color, list: Array, o := {}) -> void:
	var nk: Vector3 = b["nk"]
	for i in list.size():
		var e: Array = list[i]
		var oo: Dictionary = o.duplicate()
		oo["ph"] = float(i) * 1.3 + float(o.get("ph", 0.0))
		oo["tilt"] = float(o.get("tilt", 0.006)) * (1.0 if i % 2 == 0 else -1.0)
		oo["wob"] = o.get("wob", 0.003)
		var ad: float = e[1]
		_coil(k, k.N + float(e[0]), nk.x + ad, nk.y + ad, nk.z - ad, e[2], col, oo)


## Boğumlu konç (Kiri ninjalarının çizgili baldırlığı): gerçek dikey oluklar
static func _ribbed(k, l: Dictionary, s0: float, s1: float, col: Color, add: float, ribs := 11) -> void:
	var rf := func(s: float, a: float) -> float:
		return add + 0.0034 * cos(a * ribs) + 0.009 * (1.0 - smoothstep(s0, s0 + 0.04, s)) - 0.005 * smoothstep(s1 - 0.03, s1, s)
	P._lt(k, l, rf, func(s, a, ins):
		if ins:
			return col.darkened(0.45)
		return col.darkened(clampf(0.3 * (0.5 - 0.5 * cos(float(a) * ribs)), 0.0, 0.3) + 0.12 * float(s > s1 - 0.012)), s0, s1, 14, ribs * 4)


## Kese / kutu: yüzey noktasına oturur
static func _pouch(k, keys: Array, x: float, y: float, w: float, h: float, d: float, col: Color, flap: Color) -> void:
	var e: Array = P._fp(keys, x, y, true, d * 0.75)
	var o: Vector3 = e[1]
	var c: Vector3 = e[0]
	var ux := Vector3.UP.cross(o).normalized() * w
	var bo: Array = k.torso_skin(y)
	P._boxr(k, c, ux, Vector3.UP * h, o * d, col, bo, 0.24)
	P._boxr(k, c + Vector3.UP * h * 0.62 + o * d * 0.34, ux * 1.06, Vector3.UP * h * 0.42, o * d * 0.74, flap, bo, 0.3)
	P._stud(k, c + Vector3.UP * h * 0.3 + o * d * 1.06, o, 0.0062, flap.lightened(0.3), bo)


# ------------------------------------------------------------------ Kiri Kenshi (ref Mangetsu_hozuki): kolsuz koyu üst, omuza yayılan kat kat gri boyunluk, geniş deri kemer ve yan kılıf, diz altında biten düz pantolon, oluklu baldırlık
static func _kiri_kenshi(k) -> void:
	var tp := Color(0.17, 0.18, 0.15)
	var pn := Color(0.5, 0.45, 0.49)
	var rb := Color(0.5, 0.51, 0.54)
	var br := Color(0.29, 0.2, 0.14)
	var br2 := Color(0.43, 0.33, 0.25)
	var sc := Color(0.73, 0.69, 0.61)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var skc: Color = b["skin"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	_chest(k, b, skc)
	_pelvis(k, b, pn)
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var le := P._limb(k, sd, true)
		P._bare(k, ar, skc)
		var kn: float = le["kn"]
		var pf := func(s: float, a: float) -> float:
			return 0.0042 * P._lf(s, a, 1.3) * smoothstep(0.02, 0.2, s) + 0.0045 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 34.0)
		# ütü çizgisi: önde ince sırt, arkada yumuşak düşüş
		var cr := func(a: float) -> float: return exp(-pow(a / 0.13, 2.0))
		P._lt(k, le, func(s, a):
			return lerpf(0.012, 0.031, smoothstep(0.05, 0.62, float(s))) + float(pf.call(float(s), float(a))) + 0.0042 * float(cr.call(float(a))), func(s, a, ins):
			if ins:
				return pn.darkened(0.45)
			return P._fs(pn, float(pf.call(float(s), float(a))), 16.0).lightened(0.08 * float(cr.call(float(a)))), 0.0, 0.77, 36, 26, 0.2)
		_ribbed(k, le, 0.7, 1.0, rb, 0.007)
	# kolsuz üst: geniş askı, derin kol oyuğu
	var tk := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.013), P._kp(wa, H + 0.12, 0.016), P._kp(bl, H + 0.02, 0.016)]
	var g := P._cl(k, {"keys": tk, "ny": 30, "na": 88, "top": func(a):
		return lerpf(N - 0.045, C - 0.02, smoothstep(0.6, 0.92, absf(sin(float(a))))), "hem": func(_a): return H + 0.02, "fold": func(a, y, _v):
		return 0.0075 * sin(float(a) * 7.0 + float(y) * 9.0) * smoothstep(C - 0.04, H + 0.08, float(y)) + 0.003 * sin(float(a) * 4.0 + float(y) * 18.0), "col": func(_a, _y, _v): return tp, "gain": 9.0})
	P._bd(k, g["top"], 0.0045, 0.002, tp.lightened(0.12), true)
	# deri kemer: hafif eğik, üstte açık renk bağ
	var bk := [P._kp(bl, H + 0.1, 0.03), P._kp(bl, H - 0.04, 0.035)]
	var by := func(a: float) -> float: return H + 0.03 + 0.009 * sin(a + 0.5)
	var bg := P._cl(k, {"keys": bk, "ny": 8, "na": 72, "top": func(a): return float(by.call(float(a))) + 0.036, "hem": func(a): return float(by.call(float(a))) - 0.036, "fold": func(a, _y, v): return 0.004 * sin(float(a) * 9.0 + float(v) * 3.0), "col": func(_a, _y, _v): return br, "skin": func(p): return k.torso_skin(p.y), "gain": 8.0})
	P._bd(k, bg["top"], 0.0035, 0.002, br.darkened(0.3), true)
	P._bd(k, bg["hem"], 0.0035, 0.002, br.darkened(0.3), true)
	P._bd(k, _ring_t(bk, func(a): return float(by.call(float(a))) + 0.012, 0.004), 0.0125, 0.004, br2, true)
	var bf: Array = P._fp(bk, 0.0, by.call(0.0), true, 0.008)
	var bo: Array = [["Hips", 1.0]]
	P._boxr(k, bf[0], Vector3(0.034, 0, 0), Vector3(0, 0.026, 0), bf[1] * 0.009, Color(0.36, 0.37, 0.4), bo, 0.2)
	for sg in [-1.0, 1.0]:
		P._stud(k, (bf[0] as Vector3) + Vector3(0.024 * sg, 0, 0.008), bf[1], 0.0045, Color(0.62, 0.63, 0.66), bo)
	# sağ kalçada parşömen kılıfı: kemere iki bağla asılı
	var hx: float = -(bl.x + 0.04)
	var hc := Vector3(hx, H - 0.075, 0.02)
	P._boxr(k, hc, Vector3(0.024, 0, 0), Vector3(0, 0.088, 0), Vector3(0, 0, 0.022), Color(0.56, 0.59, 0.5), bo, 0.34)
	for yy in [0.06, -0.035]:
		P._boxr(k, hc + Vector3(0, float(yy), 0), Vector3(0.0265, 0, 0), Vector3(0, 0.008, 0), Vector3(0, 0, 0.0245), br.lightened(0.05), bo, 0.2)
	P._boxr(k, Vector3(hx + 0.007, H + 0.015, 0.022), Vector3(0.012, 0, 0), Vector3(0, 0.036, 0), Vector3(0, 0, 0.012), br.lightened(0.05), bo, 0.25)
	# boyunluk: omuza yayılan alt kat + kat kat turlar
	var ck := [[N + 0.03, nk.x + 0.03, nk.y + 0.03, nk.z - 0.03], _ov(tk, N - 0.018, 0.012, 0.024), _ov(tk, N - 0.048, 0.006, 0.027, 0.94), _ov(tk, N - 0.08, 0.0, 0.028, 0.88)]
	var cg := P._cl(k, {"keys": ck, "ny": 10, "na": 64, "top": func(_a): return N + 0.03, "hem": func(a): return N - 0.074 + 0.009 * cos(float(a) * 3.0 + 0.5), "fold": func(a, _y, v): return float(v) * 0.03 * sin(float(a) * 5.0 + 0.7), "col": func(_a, _y, _v): return sc, "skin": func(p): return k.torso_skin(p.y), "gain": 5.0})
	P._cord(k, cg["hem"], 0.0085, sc.darkened(0.08), true, Callable(), 0.0, 7)
	_rolls(k, b, sc, [[-0.02, 0.062, 0.021], [0.008, 0.046, 0.0195], [0.034, 0.033, 0.0175], [0.057, 0.025, 0.0155]], {"drop": 0.018})


# ------------------------------------------------------------------ Kurosuki (ref Raiga-Ranmaru, Raiga_Kurosuki): boyunda kat kat sargı, verev yakalı açık gri üst, uzun siyah açık yelek (turuncu biye, dik yaka), siyah ön peş, balon gri pantolon, baldırda beyaz sargı, siyah bilek kolluğu
static func _kurosuki(k) -> void:
	var wh := Color(0.8, 0.79, 0.76)
	var bn := Color(0.86, 0.85, 0.8)
	var pn := Color(0.57, 0.59, 0.57)
	var bk := Color(0.1, 0.1, 0.12)
	var og := Color(0.82, 0.42, 0.16)
	var pr := Color(0.56, 0.48, 0.72)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var skc: Color = b["skin"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	_pelvis(k, b, pn, 0.03)
	# göğüs sargısı: yakanın içinde görünen yatay turlar
	SE.body_layer(k, [[N + 0.02, nk.x + 0.008, nk.y + 0.008, nk.z - 0.008], [N - 0.05, ch.x * 0.76, ch.y * 0.84, ch.z * 0.88], [C - 0.08, ch.x * 0.94, ch.y, ch.z * 0.96]], 16, 36, func(_i, j, _p): return bn.darkened(0.14) if j % 2 == 1 else bn, func(_a, y): return 0.022 * sin(float(y) * 150.0))
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var le := P._limb(k, sd, true)
		var akn: float = ar["kn"]
		P._bare(k, ar, skc, akn - 0.08, 1.0)
		# yen: yatay kırışıklar, dirsek altında kıvrılmış ağız
		var sf := func(s: float, a: float) -> float:
			return 0.0042 * sin(s * 62.0 + sin(a * 2.0) * 1.3) + 0.0026 * sin(a * 4.0 + s * 9.0)
		P._lt(k, ar, func(s, a): return 0.008 + float(sf.call(float(s), float(a))) + 0.005 * smoothstep(0.1, 0.5, float(s)) + 0.009 * smoothstep(akn + 0.08, akn + 0.13, float(s)), func(s, a, ins):
			if ins:
				return wh.darkened(0.42)
			return P._fs(wh, float(sf.call(float(s), float(a))), 26.0), 0.0, akn + 0.15, 36, 20, 0.03)
		# siyah kolluk + bağ
		P._lt(k, ar, func(s, a): return 0.0085 + 0.0016 * sin(float(a) * 5.0 + float(s) * 22.0), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.03), 0.78, 0.985, 8, 16)
		P._wraps(k, ar, 0.8, 0.84, 2, 0.012, 0.008, bk.lightened(0.14), 0.004)
		# balon pantolon: diz altında büzülür
		var e_s: float = 0.64
		var pf := func(s: float, a: float) -> float:
			var gather := smoothstep(e_s - 0.22, e_s, s)
			return 0.008 * sin(a * 3.0 + s * 8.0 + 0.8) * (1.0 - gather) + 0.0048 * sin(a * 9.0 + 1.0) * gather + 0.004 * sin(a * 5.0 - s * 14.0)
		P._lt(k, le, func(s, a):
			var sv := float(s)
			return 0.016 + 0.05 * sin(clampf(sv / e_s, 0.0, 1.0) * PI * 0.92) * smoothstep(0.34, 0.52, sv) + float(pf.call(sv, float(a))) + 0.012 * smoothstep(0.2, 0.5, sv) * (1.0 - smoothstep(e_s - 0.12, e_s - 0.02, sv)) * maxf(0.0, -cos(float(a))), func(s, a, ins):
			return pn.darkened(0.45) if ins else P._fs(pn, float(pf.call(float(s), float(a))), 11.0), 0.0, e_s, 34, 28, 0.03)
		P._lt(k, le, func(_s, _a): return 0.003, func(_s, _a, _i): return bn.darkened(0.24), e_s - 0.06, 1.0, 14, 16)
		P._wraps(k, le, e_s + 0.01, 0.985, 14, 0.009, 0.0165, bn, 0.009)
	# üst: sol kanat sağın üstüne biner
	var tk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.03], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.028), P._kp(bl, H + 0.02, 0.028)]
	var top_e := func(v: float) -> float: return lerpf(0.62, -0.5, smoothstep(0.0, 0.52, v))
	var sg := P._cl(k, {"keys": tk, "ny": 32, "na": 88, "rng": func(v): return Vector2(top_e.call(float(v)), TAU - float(top_e.call(float(v))) * 0.5 - 0.3), "top": func(_a): return N + 0.012, "hem": func(_a): return H + 0.02, "fold": func(a, y, _v):
		return 0.012 * sin(float(y) * 52.0 + sin(float(a) * 2.0)) * 0.5 + 0.006 * sin(float(a) * 7.0 + float(y) * 8.0) * smoothstep(C, H + 0.1, float(y)), "col": func(_a, _y, _v): return wh, "gain": 8.0})
	P._bd(k, sg["ea"].slice(0, 20), 0.011, 0.004, wh.lightened(0.1), false, Callable(), 0.0)
	P._bd(k, sg["eb"].slice(0, 20), 0.011, 0.004, wh.lightened(0.1), false, Callable(), 0.0)
	# bel bağı
	var dr := [P._kp(bl, H + 0.09, 0.034), P._kp(hp, H - 0.04, 0.05), [H - 0.3, hp.x + 0.06, hp.y + 0.05, hp.z - 0.05], [H - 0.55, hp.x + 0.07, hp.y + 0.075, hp.z - 0.06]]
	P._sash(k, dr, H + 0.05, 0.034, 0.022, bk.lightened(0.05), 0.2)
	# ön peş: bağdan iner, turuncu kenar
	var ap := P._cl(k, {"keys": dr, "ny": 22, "na": 22, "rng": func(v): return Vector2(-0.36 - 0.03 * float(v), 0.36 + 0.03 * float(v)), "top": func(_a): return H + 0.035, "hem": func(a): return H - 0.47 + 0.08 * pow(absf(float(a)) / 0.38, 2.0), "fold": func(a, _y, v): return float(v) * 0.018 * sin(float(a) * 11.0), "col": func(_a, _y, _v): return bk, "inner": og.darkened(0.4), "skin": func(p): return k.cloth_skin(p, H - 0.47, 0.42), "gain": 7.0})
	var aps := func(p: Vector3) -> Array: return k.cloth_skin(p, H - 0.47, 0.42)
	for ed: Array in [ap["ea"], ap["eb"], ap["hem"]]:
		var ou := []
		for p: Vector3 in ed:
			ou.append(Vector3(p.x * 0.4, 0.0, 1.0).normalized())
		k.strip(ed, ou, 0.0085, 0.003, og, false, aps)
	# yelek: omuzdan uyluğa, yanlardan yırtmaçlı
	var vh: float = H - 0.33
	var vk := [P._kp(nk, N + 0.018, 0.045), [N - 0.05, ch.x * 1.03, ch.y * 1.02, ch.z * 1.1], P._kp(ch, C - 0.03, 0.044), P._kp(wa, H + 0.12, 0.052), P._kp(bl, H + 0.03, 0.06), P._kp(hp, H - 0.08, 0.075), [vh, hp.x + 0.095, hp.y + 0.09, hp.z - 0.09]]
	var v_h: float = (N - H) / (N - vh)
	var ve := func(v: float) -> float: return lerpf(0.85, 0.32, smoothstep(0.0, 0.3, v)) + 0.42 * smoothstep(v_h - 0.05, 1.0, v)
	var vg := P._cl(k, {"keys": vk, "ny": 46, "na": 92, "rng": func(v): return Vector2(ve.call(float(v)), TAU - float(ve.call(float(v)))), "top": func(a):
		return lerpf(N + 0.016, C - 0.07, smoothstep(0.58, 0.9, absf(sin(float(a))))), "hem": func(a):
		return lerpf(vh + 0.012 * sin(float(a) * 4.0), H - 0.05, exp(-pow((absf(float(a)) - PI * 0.5) / 0.13, 2.0))), "fold": func(a, y, v):
		return float(v) * float(v) * (0.03 * sin(float(a) * 6.0 + 0.4) + 0.012 * sin(float(a) * 13.0 + float(y) * 4.0)) + 0.005 * sin(float(a) * 5.0 + float(y) * 12.0), "col": func(_a, _y, _v): return bk, "inner": og.darkened(0.3), "gain": 5.0, "th": 0.007})
	var last := int(vg["ea"].size()) - 1
	for ed: Array in [vg["ea"].slice(0, last + 1), vg["eb"].slice(0, last + 1)]:
		P._tr(k, ed, 0.0095, 0.0035, og)
	var hm := []
	for p: Vector3 in vg["hem"]:
		hm.append(p + Vector3(0, 0.006, 0))
	P._tr(k, hm, 0.0055, 0.0028, og.darkened(0.08))
	P._bd(k, vg["top"], 0.0055, 0.003, bk.lightened(0.16))
	# dik yaka: siyah dış, içi turuncu; üst kenar bir yanda turuncu, bir yanda mor (ref)
	var ckk := [[N + 0.15, nk.x + 0.042, nk.y + 0.05, nk.z - 0.06], [N - 0.01, nk.x + 0.05, nk.y + 0.05, nk.z - 0.05]]
	var cg := P._cl(k, {"keys": ckk, "ny": 8, "na": 40, "rng": func(_v): return Vector2(0.55, TAU - 0.55), "top": func(a): return N + 0.075 + 0.03 * smoothstep(0.55, 2.3, absf(float(a))), "hem": func(_a): return N - 0.01, "col": func(_a, _y, _v): return bk, "inner": og, "skin": func(p): return k.torso_skin(p.y), "th": 0.007})
	var half: int = int(cg["top"].size() / 2)
	P._bd(k, cg["top"].slice(0, half + 1), 0.0065, 0.003, og, false, Callable(), 0.6)
	P._bd(k, cg["top"].slice(half), 0.0065, 0.003, pr, false, Callable(), 0.6)
	# boyun sargısı: çeneye kadar yatay turlar
	_rolls(k, b, bn, [[-0.005, 0.016, 0.0125], [0.016, 0.0125, 0.012], [0.037, 0.0095, 0.0115], [0.057, 0.0075, 0.011], [0.075, 0.006, 0.0095]], {"tilt": 0.003, "wob": 0.0015, "seg": 8, "crease": 0.08})


# ------------------------------------------------------------------ Kiri Kunoichi (ref Ameyuri_ringo): dikey pliseli zeytin tunik, bele oturan bant, geniş yenler, krem atkı, gri kolluk, çok bol siyah pantolon, oluklu gri baldırlık
static func _kiri_kunoichi(k) -> void:
	var ol := Color(0.4, 0.36, 0.22)
	var cr := Color(0.87, 0.82, 0.66)
	var gy := Color(0.46, 0.47, 0.5)
	var bk := Color(0.14, 0.145, 0.16)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	_pelvis(k, b, bk, 0.04)
	var pl := func(a: float, cnt: float) -> float: return pow(0.5 + 0.5 * cos(a * cnt), 22.0)   # pli oluğu
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var le := P._limb(k, sd, true)
		# kolluk: bilekten dirseğe gri, oluklu
		_ribbed(k, ar, 0.55, 0.985, gy, 0.006, 9)
		P._wraps(k, ar, 0.9, 0.95, 2, 0.011, 0.0075, gy.darkened(0.3), 0.003)
		# geniş yen: aşağı sarkar, pli olukları sürer
		var akn: float = ar["kn"]
		var ad := func(s: float, a: float) -> float:
			var fl := smoothstep(0.3, 0.76, s)
			return 0.012 + 0.03 * fl + 0.062 * fl * _sag(ar, s, a) - 0.0075 * float(pl.call(a, 9.0))
		P._lt(k, ar, func(s, a): return float(ad.call(float(s), float(a))), func(s, a, ins):
			if ins:
				return ol.darkened(0.46)
			return ol.darkened(0.3 * float(pl.call(float(a), 9.0)) + 0.1 * smoothstep(0.72, 0.76, float(s))), 0.0, akn + 0.26, 34, 54, 0.42)
		# çok bol pantolon: dizde şişer, baldırda toplanır
		var e_s := 0.84
		var pf := func(s: float, a: float) -> float:
			var g := smoothstep(e_s - 0.18, e_s, s)
			return 0.013 * sin(a * 3.0 + s * 7.0 + 0.5) * (1.0 - g) + 0.006 * sin(a * 7.0 - s * 11.0) * (1.0 - g * 0.5) + 0.0052 * sin(a * 11.0) * g
		P._lt(k, le, func(s, a):
			var sv := float(s)
			return 0.024 + 0.056 * pow(sin(clampf(sv / e_s, 0.0, 1.0) * PI * 0.96), 0.8) * smoothstep(0.2, 0.46, sv) - 0.018 * smoothstep(e_s - 0.14, e_s, sv) + float(pf.call(sv, float(a))) + 0.02 * smoothstep(0.3, 0.6, sv) * (1.0 - smoothstep(0.7, e_s, sv)) * maxf(0.0, -cos(float(a))), func(s, a, ins):
			return bk.darkened(0.4) if ins else P._fs(bk, float(pf.call(float(s), float(a))), 9.0), 0.0, e_s, 38, 32, 0.16)
		_ribbed(k, le, e_s - 0.09, 1.0, gy, 0.007)
	# tunik: göğüs ve bele oturur, kalçada açılır; dikey pliler gerçek oluk
	var hem: float = H - 0.23
	var tk := [P._kp(nk, N + 0.014, 0.03), [N - 0.055, ch.x * 0.99, ch.y * 0.95, ch.z * 1.03], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.018), P._kp(bl, H + 0.03, 0.05), P._kp(hp, H - 0.08, 0.082), [hem, hp.x + 0.112, hp.y + 0.104, hp.z - 0.104]]
	var v_c := func(y: float) -> float: return smoothstep(H + 0.14, H + 0.02, y)
	var tf := func(a: float, y: float, _v: float) -> float:
		return -0.05 * float(pl.call(a, 18.0)) + float(v_c.call(y)) * 0.022 * sin(a * 6.0 + 0.8)
	var g := P._cl(k, {"keys": tk, "ny": 40, "na": 180, "top": func(_a): return N + 0.014, "hem": func(a): return hem + 0.012 * cos(float(a) * 2.0), "fold": tf, "col": func(_a, _y, _v): return ol, "gain": 6.0, "th": 0.006})
	var hm := []
	for p: Vector3 in g["hem"]:
		hm.append(p + Vector3(0, 0.009, 0))
	P._tr(k, hm, 0.0048, 0.002, ol.darkened(0.22), true)
	# bel bandı + ince kuşak
	var bd := []
	for e: Array in tk:
		bd.append([e[0], float(e[1]) + 0.007, float(e[2]) + 0.008, float(e[3]) - 0.008])
	var bg := P._cl(k, {"keys": bd, "ny": 6, "na": 72, "top": func(a): return H + 0.14 + 0.004 * sin(float(a) * 2.0), "hem": func(a): return H + 0.085 + 0.004 * sin(float(a) * 2.0), "fold": func(a, _y, _v): return 0.006 * sin(float(a) * 7.0), "col": func(_a, _y, _v): return ol.lightened(0.05), "skin": func(p): return k.torso_skin(p.y), "gain": 8.0})
	P._bd(k, bg["top"], 0.003, 0.0018, ol.darkened(0.28), true)
	P._bd(k, bg["hem"], 0.003, 0.0018, ol.darkened(0.28), true)
	# krem atkı: göğse inen kat + sıkı turlar
	var ck := [[N + 0.035, nk.x + 0.03, nk.y + 0.034, nk.z - 0.03], _ov(tk, N - 0.025, 0.006, 0.016, 0.8), _ov(tk, N - 0.1, 0.0, 0.016, 0.62)]
	var cg := P._cl(k, {"keys": ck, "ny": 10, "na": 56, "top": func(_a): return N + 0.035, "hem": func(a): return N - 0.044 - 0.05 * exp(-pow((float(a) - 0.16) / 0.62, 2.0)), "fold": func(a, _y, v): return float(v) * 0.05 * sin(float(a) * 4.0 + 1.1), "col": func(_a, _y, _v): return cr, "skin": func(p): return k.torso_skin(p.y), "gain": 4.5})
	P._cord(k, cg["hem"], 0.0065, cr.darkened(0.1), true, Callable(), 0.0, 6)
	_rolls(k, b, cr, [[-0.012, 0.045, 0.0185], [0.014, 0.034, 0.0175], [0.04, 0.026, 0.016], [0.062, 0.02, 0.0135]], {"tilt": 0.009, "drop": 0.014})


# ------------------------------------------------------------------ Kiri Atki (ref Yagura_OL): gri kolsuz üst, file kısa kol + siyah ağız, omza yayılan kalın zeytin atkı, yeşil kuşak ve iki uç, kat kat sarılı zeytin etek (önü kalkık), gri büzgülü pantolon, kahve konç
static func _kiri_atki(k) -> void:
	var gy := Color(0.44, 0.45, 0.47)
	var ol := Color(0.39, 0.42, 0.21)
	var gn := Color(0.4, 0.6, 0.44)
	var pn := Color(0.37, 0.38, 0.39)
	var bt := Color(0.33, 0.24, 0.15)
	var ms := Color(0.2, 0.21, 0.23)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var skc: Color = b["skin"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	_pelvis(k, b, pn, 0.03)
	_chest(k, b, skc)
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var le := P._limb(k, sd, true)
		var akn: float = ar["kn"]
		P._bare(k, ar, skc, akn * 0.5, 1.0)
		var e_a: float = akn * 0.72
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return ms.darkened(0.3) if ins else skc.darkened(0.3), 0.0, e_a, 18, 18)
		P._net_limb(k, ar, 0.04, e_a - 0.01, 0.0055, 13, 0.024, 0.0017, ms)
		P._lt(k, ar, func(s, _a): return 0.0085 - 0.002 * absf(float(s) - e_a), func(_s, _a, ins): return ms if ins else Color(0.1, 0.1, 0.11), e_a - 0.035, e_a + 0.01, 3, 18)
		# büzgülü pantolon, kahve konç üstüne biner
		var e_s: float = 0.76
		var pf := func(s: float, a: float) -> float:
			var g := smoothstep(e_s - 0.16, e_s, s)
			return 0.006 * sin(a * 3.0 + s * 8.0) * (1.0 - g) + 0.0045 * sin(a * 8.0 + 0.6) * g + 0.003 * sin(a * 5.0 - s * 13.0)
		P._lt(k, le, func(s, a):
			var sv := float(s)
			return 0.018 + 0.016 * smoothstep(0.0, 0.3, sv) + 0.012 * smoothstep(0.42, 0.62, sv) - 0.02 * smoothstep(e_s - 0.14, e_s, sv) + float(pf.call(sv, float(a))), func(s, a, ins):
			return pn.darkened(0.42) if ins else P._fs(pn, float(pf.call(float(s), float(a))), 12.0), 0.0, e_s, 34, 26, 0.03)
		var top_s := func(a: float) -> float: return 0.72 - 0.035 * cos(a)   # konç ağzı önde yüksek
		P._lts(k, le, func(s, a): return 0.0125 + 0.0035 * sin(float(a) * 2.0 + float(s) * 18.0) * 0.5 + 0.004 * (1.0 - smoothstep(0.72, 0.8, float(s))), func(s, _a, ins):
			return bt.darkened(0.4) if ins else bt.darkened(0.12 * float(float(s) > 0.97)), top_s, 1.0, 16, 22)
	# gri üst: boyundan bele, geniş kol oyuğu
	var tk := [P._kp(nk, N + 0.01, 0.02), [N - 0.055, ch.x * 0.96, ch.y * 0.93, ch.z * 1.02], P._kp(ch, C - 0.03, 0.014), P._kp(wa, H + 0.12, 0.018), P._kp(bl, H + 0.02, 0.018)]
	var g := P._cl(k, {"keys": tk, "ny": 28, "na": 84, "top": func(a): return lerpf(N + 0.01, C - 0.01, smoothstep(0.66, 0.94, absf(sin(float(a))))), "hem": func(_a): return H + 0.02, "fold": func(a, y, _v): return 0.006 * sin(float(a) * 6.0 + float(y) * 10.0) * smoothstep(C, H + 0.08, float(y)), "col": func(_a, _y, _v): return gy, "gain": 8.0})
	P._bd(k, g["top"], 0.005, 0.0024, gy.darkened(0.25), true)
	P._line(k, tk, [Vector2(0.0, N - 0.09), Vector2(0.0, H + 0.08)], 0.0028, 0.002, 0.0018, gy.darkened(0.22), 6)
	# etek: üç kat sarma, önü kalkık, kumaş bacakla açılır
	var sk := [P._kp(bl, H + 0.07, 0.02), P._kp(hp, H - 0.04, 0.052), [H - 0.26, hp.x + 0.09, hp.y + 0.085, hp.z - 0.085], [H - 0.6, hp.x + 0.14, hp.y + 0.13, hp.z - 0.13]]
	var last_keys: Array = sk
	var sks := func(p: Vector3) -> Array: return _skirt_skin(k, p, H - 0.53)
	for t: Array in [[0.0, H - 0.53, 0.31, 0.6], [0.02, H - 0.37, 0.2, 2.0], [0.04, H - 0.2, 0.095, 3.7]]:
		var ad: float = t[0]
		var kk := []
		for e: Array in sk:
			var ae: float = ad * (0.25 if float(e[0]) > H else 1.0)
			kk.append([e[0], float(e[1]) + ae, float(e[2]) + ae, float(e[3]) - ae])
		var h0: float = t[1]
		var rise: float = t[2]
		var ph: float = t[3]
		var hf := func(a: float) -> float:
			return h0 + rise * exp(-pow(wrapf(a - 0.28, -PI, PI) / 0.82, 2.0)) + 0.022 * sin(a + ph)
		P._cl(k, {"keys": kk, "ny": 20, "na": 84, "top": func(_a): return H + 0.05, "hem": hf, "fold": func(a, y, v):
			var fv := float(v)
			return fv * 0.03 * sin(float(a) * 4.0 + float(y) * 8.0 + ph) + fv * fv * 0.016 * sin(float(a) * 9.0 + ph * 2.0), "col": func(_a, _y, _v): return ol, "inner": ol.darkened(0.45), "skin": sks, "gain": 5.2, "th": 0.006})
		last_keys = kk
	# yeşil kuşak + düğümden inen iki uç
	P._sash(k, sk, H + 0.055, 0.03, 0.016, gn, 0.16)
	var sy: float = H + 0.03
	var strs := sks
	P._strap(k, last_keys, [Vector2(0.018, sy), Vector2(0.03, H - 0.16), Vector2(0.05, H - 0.42)], true, 0.017, 0.012, 0.0028, gn, 8, strs)
	P._strap(k, last_keys, [Vector2(0.06, sy), Vector2(0.078, H - 0.1), Vector2(0.1, H - 0.31)], true, 0.016, 0.018, 0.0028, gn.darkened(0.12), 8, strs)
	var kc: Array = P._fp(last_keys, 0.038, H + 0.04, true, 0.022)
	P._boxr(k, kc[0], Vector3(0.028, 0, 0), Vector3(0, 0.02, 0), (kc[1] as Vector3) * 0.012, gn.lightened(0.06), [["Hips", 1.0]], 0.42)
	# atkı: omuzlara oturan pelerin katı + kalın rulolar
	var cp := [[N + 0.035, nk.x + 0.04, nk.y + 0.045, nk.z - 0.04], [N - 0.03, nk.x + 0.1, nk.y + 0.095, nk.z - 0.09], [N - 0.09, k.UA + 0.065, ch.y + 0.05, ch.z - 0.05], [C - 0.09, k.UA + 0.085, ch.y + 0.045, ch.z - 0.05]]
	var cg := P._cl(k, {"keys": cp, "ny": 16, "na": 72, "top": func(_a): return N + 0.035, "hem": func(a):
		var aw := float(a)
		return C - 0.005 - 0.066 * exp(-pow(aw / 0.75, 2.0)) - 0.048 * exp(-pow(absf(aw) - PI, 2.0)) + 0.01 * sin(aw * 5.0), "fold": func(a, y, v):
		return float(v) * 0.03 * sin(float(a) * 5.0 + float(y) * 6.0) + 0.012 * sin(float(a) * 3.0 - float(y) * 16.0), "col": func(_a, _y, _v): return ol, "inner": ol.darkened(0.42), "skin": func(p): return _cape_skin(k, p), "gain": 5.0, "th": 0.007})
	P._cord(k, cg["hem"], 0.0075, ol.darkened(0.12), true, func(p): return _cape_skin(k, p), 0.0, 6)
	_coil(k, N - 0.04, nk.x + 0.102, nk.y + 0.092, nk.z - 0.092, 0.029, ol, {"tilt": 0.011, "wob": 0.006, "ph": 0.4, "seg": 12, "n": 56, "flat": 0.6, "drop": 0.02})
	_rolls(k, b, ol, [[-0.008, 0.07, 0.026], [0.02, 0.052, 0.023], [0.044, 0.04, 0.019]], {"tilt": 0.01, "wob": 0.005, "ph": 1.1, "seg": 12, "crease": 0.2, "drop": 0.028})


## Diz boyu sarma etek: uyluğu tam izler, baldıra bağlanmaz (bükülen diz alt katı delmez)
static func _skirt_skin(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var kt: float = maxf(0.05, (H - k.K) / maxf(0.05, H - hem))
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var w: float = 0.96 * pow(minf(1.0, t / (kt * 0.8)), 0.3)
	var sx: float = smoothstep(-0.06, 0.06, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * sx], ["RightUpperLeg", w * (1.0 - sx)]]


## Omuz örtüsü: göğüsle gider, kol altında serbest kalır (bağ duruşu T: kola fazla bağlanırsa kol inince kenar içeri çöker)
static func _cape_skin(k, p: Vector3) -> Array:
	var ts: Array = k.torso_skin(p.y)
	var w: float = smoothstep(k.UA * 0.72, k.UA * 1.2, absf(p.x)) * 0.1
	if w <= 0.0:
		return ts
	var out := []
	for e: Array in ts:
		out.append([e[0], float(e[1]) * (1.0 - w)])
	out.append([("Left" if p.x > 0.0 else "Right") + "UpperArm", w])
	return out


# ------------------------------------------------------------------ Suna Rōjo (ref Chiyo_vs._Samurai, Chiyos_taijutsu): ayak bileğine inen koyu giysi, geniş sarkan yen, önü açılan etek altında leylak iç etek, sırtı ve omuzları örten kalın krem örtü, boyunda şişkin rulo
static func _suna_rojo(k) -> void:
	var dk := Color(0.23, 0.22, 0.25)
	var lv := Color(0.58, 0.54, 0.67)
	var cr := Color(0.86, 0.82, 0.73)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var F: float = k.F
	var Kn: float = k.K
	var b := _b(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	_pelvis(k, b, dk.darkened(0.2), 0.02)
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var le := P._limb(k, sd, true)
		P._lt(k, le, func(_s, _a): return 0.012, func(_s, _a, ins): return dk.darkened(0.4) if ins else dk.darkened(0.12), 0.0, 1.0, 22, 16)
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, _i): return lv.darkened(0.28), 0.4, 0.985, 12, 14)
		# geniş yen: dirsekten sonra sarkan torba, astarı leylak
		var ad := func(s: float, a: float) -> float:
			var fl := smoothstep(0.25, 0.8, s)
			return 0.008 + 0.04 * fl + 0.095 * fl * fl * _sag(ar, s, a) + 0.005 * sin(a * 4.0 + s * 10.0)
		P._lt(k, ar, func(s, a): return float(ad.call(float(s), float(a))), func(s, a, ins):
			if ins:
				return lv.darkened(0.15)
			return P._fs(dk, 0.005 * sin(float(a) * 4.0 + float(s) * 10.0), 24.0), 0.0, 0.93, 34, 28, 0.5)
	# leylak iç etek: önde görünür
	var low: float = F + 0.1
	var lk := [P._kp(hp, H + 0.03, 0.022), P._kp(hp, H - 0.1, 0.032), [Kn, hp.x + 0.052, hp.y + 0.05, hp.z - 0.05], [low, hp.x + 0.09, hp.y + 0.09, hp.z - 0.09]]
	P._cur_long = true
	P._cl(k, {"keys": lk, "ny": 26, "na": 40, "rng": func(_v): return Vector2(-1.15, 1.15), "top": func(_a): return H + 0.03, "hem": func(_a): return low + 0.012, "fold": func(a, _y, v): return float(v) * 0.022 * sin(float(a) * 6.0 + 0.3), "col": func(_a, _y, _v): return lv, "gain": 5.0, "th": 0.004})
	# dış giysi: tek parça, önden yan açılır; bele sıkı değil, bol iner
	var rk := [P._kp(nk, N + 0.01, 0.028), [N - 0.055, ch.x * 1.0, ch.y * 0.97, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.042), P._kp(hp, H - 0.04, 0.052), [Kn, hp.x + 0.092, hp.y + 0.09, hp.z - 0.09], [F + 0.07, hp.x + 0.136, hp.y + 0.13, hp.z - 0.13]]
	var hem: float = F + 0.075
	var vh: float = (N - H) / (N - hem)
	var en := func(v: float) -> float: return lerpf(0.1, 0.42, smoothstep(vh, 1.0, v))
	var rf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		if y > H:
			return 0.009 * sin(a * 6.0 + y * 8.0) * smoothstep(C, H, y)
		return t * (0.042 * sin(a * 5.0 + 0.7) + 0.019 * sin(a * 11.0 + 1.9)) + (1.0 - t) * 0.012 * sin(a * 9.0)
	var g := P._cl(k, {"keys": rk, "ny": 64, "na": 92, "rng": func(v): return Vector2(en.call(float(v)) - 0.08, TAU - float(en.call(float(v)))), "top": func(_a): return N + 0.01, "hem": func(a): return hem + 0.008 * sin(float(a) * 3.0), "fold": rf, "col": func(_a, _y, _v): return dk, "inner": lv.darkened(0.25), "gain": 5.2, "th": 0.007})
	P._tr(k, g["ea"], 0.008, 0.0032, dk.lightened(0.12))
	P._tr(k, g["eb"], 0.008, 0.0032, dk.lightened(0.12))
	var hm := []
	for p: Vector3 in g["hem"]:
		hm.append(p + Vector3(0, 0.011, 0))
	P._tr(k, hm, 0.006, 0.0026, dk.lightened(0.09))
	P._cur_long = false
	P._sash(k, rk, H + 0.075, 0.024, 0.006, dk.darkened(0.3), 0.2)
	# krem örtü: omuz ve sırtı yuvarlak örter, kenarı kalın
	var cp := [[N + 0.045, nk.x + 0.045, nk.y + 0.055, nk.z - 0.05], [N - 0.022, nk.x + 0.115, nk.y + 0.11, nk.z - 0.11], [N - 0.08, k.UA + 0.1, ch.y + 0.078, ch.z - 0.08], [C - 0.09, k.UA + 0.16, ch.y + 0.08, ch.z - 0.09], [C - 0.22, k.UA + 0.18, ch.y + 0.08, ch.z - 0.095]]
	var ch_y: float = C
	var cg := P._cl(k, {"keys": cp, "ny": 26, "na": 84, "top": func(_a): return N + 0.045, "hem": func(a):
		var aw := float(a)
		return ch_y - 0.09 - 0.04 * exp(-pow(aw / 0.9, 2.0)) - 0.085 * exp(-pow((absf(aw) - PI) / 1.05, 2.0)) + 0.008 * sin(aw * 4.0), "fold": func(a, y, v):
		return float(v) * (0.024 * sin(float(a) * 5.0 + 0.9) + 0.01 * sin(float(a) * 11.0 + float(y) * 7.0)), "col": func(_a, _y, _v): return cr, "inner": cr.darkened(0.3), "skin": func(p): return _cape_skin(k, p), "gain": 4.5, "th": 0.008})
	P._cord(k, cg["hem"], 0.0115, cr.darkened(0.07), true, func(p): return _cape_skin(k, p), 0.0, 8)
	_coil(k, N - 0.012, nk.x + 0.088, nk.y + 0.092, nk.z - 0.088, 0.034, cr, {"tilt": 0.008, "wob": 0.005, "ph": 0.7, "seg": 12, "n": 56, "flat": 0.72, "crease": 0.1, "drop": 0.02})
	_rolls(k, b, cr, [[0.024, 0.058, 0.028], [0.052, 0.042, 0.021]], {"tilt": 0.007, "wob": 0.004, "ph": 2.2, "seg": 12, "crease": 0.11, "drop": 0.03})


# ------------------------------------------------------------------ Kazekiri (ref Baki_Naruto_Mobile): koyu zeytin geniş yenli üst, kalın açık zeytin yelek (yüksek yaka, omuz kapağı, karında kese sırası), bol pantolon, sağ uylukta geniş sargı, baldır altında sargı
static func _kazekiri(k) -> void:
	var dk := Color(0.27, 0.26, 0.19)
	var vs := Color(0.5, 0.49, 0.34)
	var wh := Color(0.86, 0.84, 0.77)
	var mt := Color(0.62, 0.63, 0.62)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b := _b(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var bl: Vector3 = b["bl"]
	var nk: Vector3 = b["nk"]
	_pelvis(k, b, dk, 0.025)
	SE.body_layer(k, [P._kp(nk, N + 0.02, 0.012), [N - 0.05, ch.x * 0.98, ch.y * 0.9, ch.z * 0.94], P._kp(ch, C - 0.03, 0.012), P._kp(wa, H + 0.12, 0.014), P._kp(bl, H + 0.02, 0.018)], 14, 40, func(_i, _j, _p): return dk)
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var le := P._limb(k, sd, true)
		var akn: float = ar["kn"]
		# geniş yen: dirsekten sonra açılır
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, _i): return dk.darkened(0.25), 0.5, 0.985, 12, 14)
		var sf := func(s: float, a: float) -> float:
			return 0.0058 * sin(a * 3.0 + s * 14.0 + 0.5) * smoothstep(0.1, 0.4, s) + 0.0044 * exp(-pow((s - akn) / 0.07, 2.0)) * sin(a * 3.0 + s * 34.0)
		P._lt(k, ar, func(s, a):
			var fl := smoothstep(akn - 0.05, 0.93, float(s))
			return 0.015 + 0.02 * fl + 0.03 * fl * _sag(ar, float(s), float(a)) + float(sf.call(float(s), float(a))), func(s, a, ins):
			return dk.darkened(0.42) if ins else P._fs(dk, float(sf.call(float(s), float(a))), 14.0), 0.0, 0.93, 34, 24, 0.4)
		# bol pantolon: dizin altında bantla büzülür
		var e_s: float = 0.74
		var lkn: float = le["kn"]
		var wb := func(s: float) -> float:   # sağ uylukta sargının oturduğu bölge
			return 0.0 if sd != "Right" else smoothstep(lkn * 0.34, lkn * 0.4, s) * (1.0 - smoothstep(lkn * 0.82, lkn * 0.88, s))
		var pf := func(s: float, a: float) -> float:
			var g := smoothstep(e_s - 0.16, e_s - 0.03, s)
			return (0.0074 * sin(a * 3.0 + s * 9.0 + 0.3) * (1.0 - g) + 0.0034 * sin(a * 7.0 + s * 3.0) + 0.0048 * sin(a * 10.0) * g) * (1.0 - float(wb.call(s)))
		P._lt(k, le, func(s, a):
			var sv := float(s)
			return 0.021 + 0.03 * smoothstep(0.02, 0.4, sv) - 0.04 * smoothstep(e_s - 0.14, e_s - 0.02, sv) - 0.006 * float(wb.call(sv)) + float(pf.call(sv, float(a))), func(s, a, ins):
			return dk.darkened(0.42) if ins else P._fs(dk, float(pf.call(float(s), float(a))), 12.0), 0.0, e_s, 36, 28, 0.02)
		P._lt(k, le, func(_s, _a): return 0.003, func(_s, _a, _i): return wh.darkened(0.22), e_s - 0.06, 1.0, 10, 16)
		P._wraps(k, le, e_s + 0.015, 0.985, 11, 0.009, 0.0165, wh, 0.008)
		# sağ uylukta geniş sargı
		if sd == "Right":
			var kn: float = le["kn"]
			for i in 7:
				var s0: float = lerpf(kn * 0.42, kn * 0.8, float(i) / 6.0)
				k.wrap_turn(P._lp(le, s0), P._ld(le, s0), P._lr(le, s0) + 0.025 + 0.03 * smoothstep(0.02, 0.4, s0), 0.0205, 0.004, wh.darkened(0.05 * float(i % 2)), P._lskin(le, s0))
	# yelek: kalın, belde kısa
	var vk := [P._kp(nk, N + 0.02, 0.048), [N - 0.05, ch.x * 1.05, ch.y * 1.06, ch.z * 1.12], P._kp(ch, C - 0.03, 0.04), P._kp(wa, H + 0.12, 0.042), P._kp(bl, H + 0.02, 0.05)]
	var hv: float = H + 0.015
	var g := P._cl(k, {"keys": vk, "ny": 30, "na": 88, "top": func(a): return lerpf(N + 0.02, C + 0.0, smoothstep(0.72, 0.97, absf(sin(float(a))))), "hem": func(a): return hv + 0.006 * cos(float(a) * 2.0), "fold": func(a, y, _v): return 0.006 * sin(float(a) * 5.0 + float(y) * 12.0), "col": func(_a, _y, _v): return vs, "inner": vs.darkened(0.45), "skin": func(p): return k.torso_skin(p.y), "gain": 8.0, "th": 0.012})
	P._bd(k, g["hem"], 0.0065, 0.004, vs.darkened(0.16), true, Callable(), -0.5)
	# orta fermuar + sırt / göğüs dikişleri, küçük metal levha
	P._line(k, vk, [Vector2(0.03, N - 0.02), Vector2(0.03, H + 0.04)], 0.0045, 0.006, 0.003, vs.darkened(0.28), 8)
	for x: float in [-0.5, 0.5]:
		P._line(k, vk, [Vector2(x, C + 0.04), Vector2(x * 1.1, H + 0.2)], 0.0026, 0.004, 0.002, vs.darkened(0.2), 5)
	for x: float in [-0.42, 0.0, 0.42]:
		P._line(k, vk, [Vector2(PI + x, N - 0.04), Vector2(PI + x * 1.2, H + 0.04)], 0.0026, 0.004, 0.002, vs.darkened(0.2), 7)
	var tg: Array = P._fp(vk, 0.082, C + 0.012, true, 0.004)
	P._boxr(k, tg[0], Vector3(0.015, 0.004, 0), Vector3(-0.004, 0.012, 0), (tg[1] as Vector3) * 0.0034, mt, [["UpperChest", 1.0]], 0.2)
	# karın kese sırası: iki öbek
	for x: float in [-0.106, -0.052, 0.052, 0.106]:
		_pouch(k, vk, x, H + 0.08, 0.0245, 0.043, 0.0165, vs.darkened(0.08), vs.lightened(0.06))
	# omuz kapağı: yeleğe bağlı kalın parça
	for sd in ["Left", "Right"]:
		var ar := _arm(k, sd)
		var akn: float = ar["kn"]
		var e_c: float = akn * 0.5
		var pad := func(s: float, a: float) -> float: return 0.026 + 0.03 * smoothstep(0.02, e_c, s) + 0.0026 * sin(a * 5.0 + 0.8)
		P._lt(k, ar, func(s, a): return float(pad.call(float(s), float(a))), func(s, _a, ins):
			return vs.darkened(0.42) if ins else vs.darkened(0.13 * smoothstep(e_c - 0.02, e_c, float(s))), 0.0, e_c, 12, 26, 0.02)
	# yüksek yaka: arkası uzun, önü açık, dışa kıvrık ağız
	var ck := [[N + 0.15, nk.x + 0.066, nk.y + 0.062, nk.z - 0.085], [N + 0.055, nk.x + 0.05, nk.y + 0.052, nk.z - 0.062], [N - 0.03, nk.x + 0.07, nk.y + 0.068, nk.z - 0.07]]
	var cg := P._cl(k, {"keys": ck, "ny": 14, "na": 48, "rng": func(_v): return Vector2(0.32, TAU - 0.5), "top": func(a):
		return N + 0.05 + 0.086 * smoothstep(0.3, 2.3, absf(float(a))), "hem": func(_a): return N - 0.026, "fold": func(a, y, _v): return 0.012 * sin(float(a) * 4.0 + float(y) * 8.0), "col": func(_a, _y, _v): return vs, "inner": vs.darkened(0.28), "skin": func(p): return k.torso_skin(p.y), "th": 0.012})
	P._cord(k, cg["top"], 0.0075, vs.lightened(0.05), false, Callable(), 0.0, 7)
	for ed: Array in [cg["ea"], cg["eb"]]:
		P._cord(k, ed, 0.0062, vs.lightened(0.02), false, Callable(), 0.0, 6)
