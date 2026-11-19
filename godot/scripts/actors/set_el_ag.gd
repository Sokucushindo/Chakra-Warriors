extends RefCounted
## Elle modellenmiş setler, parti ag: ss_altinci, ss_savas_reisi, ss_savas_reisi2, ss_savas_reisi3, ss_savas_reisi_genc, ss_su_elbise. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{kakashi_outfit_sixth_hokage_vers, madara_outfit, madara_outfit_2, madara_outfit_battle_attire_ver, madara_outfit_young_ver, mei_outfit}/.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), l (L), i (I), aa (AA) dosyalarından.
## Burada: tek yüzeyli uzun giysi (bindirmeli kapalı / önü açık / yırtmaçlı aynı yüzeyden), uzun giysi ağırlığı, savaş reisi ortak kesimi
## (koyu iç + boğaz, siyah pantolon + baldır sargısı, baldıra inen önü açık cübbe, dik yaka, astarlı geniş kol, sırtta uchiwa) ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AB = preload("res://scripts/actors/set_el_ab.gd")

const DONE := ["ss_altinci", "ss_savas_reisi", "ss_savas_reisi2", "ss_savas_reisi3", "ss_savas_reisi_genc", "ss_su_elbise"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_altinci": _altinci(k)
		"ss_savas_reisi": _reisi(k)
		"ss_savas_reisi2": _reisi2(k)
		"ss_savas_reisi3": _reisi3(k)
		"ss_savas_reisi_genc": _reisi_genc(k)
		"ss_su_elbise": _mizu(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ağırlık
## Uzun giysi ağırlığı (parti aa aile ağırlığının ayarlı hali): ağırlık noktanın yönünden ve boyundan gelir, üst üste binen katlar aynı yerde aynı ağırlığı alır.
## fhw: ön geçiş genişliği (önü kapalı giyside geniş: ön orta iki bacağın ortalamasını izler, yırtmaç gibi bölünmez; önü açık giyside dar),
## kbf: diz altında önün baldıra geçen payı (etek ucu dizle levha gibi kalkmaz, baldırın önünde sarkar)
static func _rsk(k, p: Vector3, hem: float, fhw := 0.035, kbf := 0.5, xc := 0.0, bkw := 0.86) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.11), 0.5)
	var wb: float = lerpf(bkw * pow(minf(1.0, (H - p.y) / 0.32), 0.7), 0.95, smoothstep(0.55, 0.92, t))   # arka: geri giden uyluk kumaşı delmez
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.92, smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(fhw, 0.1, bk)
	var s: float = smoothstep(-hw, hw, x - xc * (1.0 - bk))
	var kb: float = smoothstep(lerpf(k.K - 0.06, k.K + 0.06, bk), lerpf(k.K - 0.24, k.K - 0.12, bk), p.y) * lerpf(kbf, 0.7, bk) * absf(2.0 * s - 1.0)   # önde dizin altından başlar: kalkan diz kumaşı delmez
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Kalçadan sarkan sert plaka ağırlığı: ön ortada iki bacağın arasında geçiş, bacak hizasında kendi bacağı
static func _plsk(p: Vector3, y0: float, ln: float, gain: float, hw: float) -> Array:
	var t: float = clampf((y0 - p.y) / maxf(0.05, ln), 0.0, 1.0)
	var w: float = gain * smoothstep(0.0, 0.8, t)
	var s: float = smoothstep(-hw, hw, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


# ------------------------------------------------------------------ uzun giysi yüzeyi
## Tek parça uzun giysi. Açı azalarak döner: au(y) alt kanadın kenarı, ao(y) üst kanadın kenarı (yüzey ao - TAU'da biter).
## au > ao: bindirme (sol kanat sağın üstüne), au < ao: önde açıklık (önü açık cübbe, yaka V'si, yırtmaç). Üst kanat bindiği yerde dışa kalkar,
## iki kat aynı noktada aynı ağırlığı aldığından koşuda ayrılmaz. İç yüz astar renginde (açıklıktan / etek ucundan bakınca boşluk görünmez).
## o: keys, top, hem, au, ao, ff(a, y), col(a, y), lin, skin(p), th, ny, na, olift
static func _robe(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var top: float = o["top"]
	var hem: float = o["hem"]
	var au: Callable = o["au"]
	var ao: Callable = o["ao"]
	var ff: Callable = o["ff"]
	var colf: Callable = o["col"]
	var lin: Color = o["lin"]
	var skf: Callable = o["skin"]
	var th: float = o.get("th", 0.008)
	var ny: int = o.get("ny", 56)
	var na: int = o.get("na", 100)
	var ol: float = o.get("olift", 0.009)
	var gain: float = o.get("gain", 6.0)
	var pt := func(a: float, y: float, lift: float) -> Vector3:
		var aw: float = wrapf(a, -PI, PI)
		var s: Array = SE.El.key_at(keys, y)
		var q: Vector2 = SE.El.sup(aw, s[1], s[2], s[3])
		var f: float = 1.0 + float(ff.call(aw, y))
		var p := Vector3(q.x * f, y, q.y * f)
		return p + Vector3(p.x, 0.0, p.z).normalized() * lift
	var co := []
	var ca := []
	var topf: Callable = o.get("topf", Callable())   # isteğe bağlı: açıya göre üst kenar (omzu açık yaka)
	for j in ny + 1:
		var v := float(j) / ny
		var y := lerpf(top, hem, v)
		var a0: float = au.call(y)
		var a1: float = float(ao.call(y)) - TAU
		var ro := []
		var ar := []
		for i in na + 1:
			var a := lerpf(a0, a1, float(i) / na)
			var dp: float = (a0 - TAU) - a   # > 0: alt kanadın üstüne binen kısım
			var lift: float = ol * smoothstep(-0.14, 0.04, dp) - 0.0025 * (1.0 - smoothstep(0.0, 0.25, a0 - a))
			var y2: float = lerpf(float(topf.call(wrapf(a, -PI, PI))), hem, v) if topf.is_valid() else y
			ro.append(pt.call(a, y2, lift))
			ar.append(wrapf(a, -PI, PI))
		co.append(ro)
		ca.append(ar)
	var rows: Array = co.duplicate()
	var src := []
	for j in ny + 1:
		src.append([j, false])
	var inw := func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
	var roll := []
	for p in co[ny]:
		roll.append(inw.call(p, th * 0.6) + Vector3(0, -th * 0.6, 0))
	rows.append(roll)
	src.append([ny, true])
	for j in range(ny, -1, -2):
		var ro := []
		for i in na + 1:
			ro.append(co[j][i] if i == 0 or i == na else inw.call(co[j][i], th))
		rows.append(ro)
		src.append([j, true])
	var rv := []   # açı azalarak dizildi: ızgaraya ters sırayla verilir (dış yüz dışa bakar)
	for ro in rows:
		var r2: Array = (ro as Array).duplicate()
		r2.reverse()
		rv.append(r2)
	k.grid(rv, false, func(i0, j, _p):
		var i: int = na - i0
		var e2: Array = src[j]
		var oj: int = e2[0]
		if e2[1]:
			return lin.darkened(0.12 * float(oj == ny))
		var a: float = ca[oj][i]
		var y: float = co[oj][i].y
		return P._fs(colf.call(a, y), float(ff.call(a, y)), gain), func(_i, _j, p): return skf.call(p))
	var ea := []
	var eb := []
	for ro in co:
		ea.append(ro[0])
		eb.append(ro[na])
	return {"rows": co, "angs": ca, "ea": ea, "eb": eb, "hem": co[ny], "top": co[0], "pt": pt}


## Kenar boyunca kumaşa oturan biye (dış yön noktadan): pts kenar, sg +1: kumaş kenarın solunda (açı azalan yönde)
static func _edge(k, pts: Array, hw: float, d: float, col: Color, skinf: Callable, inset := 0.0) -> void:
	var ps := []
	var ou := []
	for p: Vector3 in pts:
		var o := Vector3(p.x, 0.0, p.z).normalized()
		ps.append(p + o * 0.0012 + Vector3(o.z, 0.0, -o.x) * inset)
		ou.append(o)
	k.strip(ps, ou, hw, d, col, false, skinf)


## Sırt yazısı (kabartma): yukarıdan aşağı karakterler; bel üstünde kalır (bacak ağırlığı almaz, kumaş kenarından sızmaz)
static func _back_text(k, keys: Array, glyphs: Array, y_top: float, y_bot: float, col: Color, lift := 0.0065) -> void:
	var n: int = glyphs.size()
	var step: float = (y_top - y_bot) / maxf(1.0, n - 0.1)
	var s: float = clampf(step * 0.44, 0.026, 0.042)
	var sk := func(p): return k.torso_skin(maxf(float(p.y), k.H + 0.01))
	for gi in n:
		var cy: float = y_top - s - gi * step
		for st in glyphs[gi]:
			P._strap(k, keys, [Vector2(-float(st[0]) * s, cy + float(st[1]) * s), Vector2(-float(st[2]) * s, cy + float(st[3]) * s)], false, s * 0.15, lift, 0.0019, col, 3, sk)


## Parmaksız siyah eldiven (plakasız): bilek ağzı + avuç kılıfı
static func _glove(k, sd: String, ar: Dictionary, col: Color) -> void:
	var m = k.m
	var hd: Vector3 = m._bp(sd + "Hand")
	var el: Vector3 = m._bp(sd + "LowerArm")
	var d: Vector3 = (hd - el).normalized()
	P._lt(k, ar, func(s, _a): return 0.0105 + 0.004 * smoothstep(0.93, 0.985, s), func(_s, _a, ins): return col.darkened(0.4) if ins else col, 0.88, 0.99, 6, 18)
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
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.3) if j >= 4 else col.lightened(0.04 * float(j == 2)), func(_i, _j, _p): return skin_h)


## Uzvu saran sargı: sarmal turlar (çapraz eğim), altında koyu taban
static func _leg_wrap(k, le: Dictionary, pa: Callable, s0: float, s1: float, n: int, col: Color) -> void:
	var sg: float = le["sg"]
	P._lt(k, le, func(s, a): return float(pa.call(s, a)) + 0.002, func(_s, _a, ins): return col.darkened(0.45) if ins else col.darkened(0.25), s0 - 0.01, s1, 14, 18)
	for i in n:
		var s: float = lerpf(s0, s1 - 0.012, float(i) / maxf(1.0, n - 1.0))
		k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + 0.0075 + float(pa.call(s, 0.0)), 0.0115, 0.013 * sg * (1.0 if i % 2 == 0 else -0.6), col.darkened(0.05 * float(i % 3)), P._lskin(le, s))


# ------------------------------------------------------------------ savaş reisi ortak kesimi
## Koyu iç giysi + boğaza çıkan yaka, siyah pantolon, baldır sargısı (dizin altından bileğe). Döner: {sd: pantolon işlevi}
static func _mad_base(k, b: Dictionary, inner: Color, pn: Color, wrap: Color, wrap_s0 := -1.0) -> Dictionary:
	P._inner(k, b, func(_i, j, _p): return inner.lightened(0.04) if j < 4 else inner, 0.006)
	var out := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.3 if sd == "Left" else 2.4
		var pa: Callable = K._pant(k, le, pn, 0.01, 0.022, 1.0, sv)
		if wrap.a > 0.0:
			_leg_wrap(k, le, pa, kn + 0.06 if wrap_s0 < 0.0 else wrap_s0, 0.985, 13, wrap)
		out[sd] = pa
	return out


## Baldıra inen önü açık savaş cübbesi: göğüste sol kanat sağın üstüne biner, kuşaktan aşağı önü açılır (kanonda iki etek arasından pantolon görünür).
## o: col, lin, hem, e_hem (etek ucunda ön açıklık yarı açısı), y0 (açılma başlangıcı), pad
static func _mad_coat(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var hem: float = o["hem"]
	var col: Color = o["col"]
	var pd: float = o.get("pad", 0.034)
	var keys := [P._kp(nk, N + 0.012, pd), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, pd + 0.002), P._kp(wa, H + 0.12, pd + 0.012), P._kp(hp, H - 0.04, pd + 0.018),
		[KN + 0.05, hp.x + 0.09, hp.y + 0.09, hp.z - 0.125], [hem, hp.x + 0.12, hp.y + 0.1, hp.z - 0.17]]
	var y0: float = o.get("y0", H + 0.03)
	var eh: float = o.get("e_hem", 0.3)
	var ov: float = o.get("ov", 0.15)
	var e_of := func(y: float) -> float: return eh * pow(clampf((y0 - y) / (y0 - hem), 0.0, 1.0), 0.75)
	var cl_of := func(y: float) -> float: return ov * smoothstep(y0 - 0.04, y0 + 0.06, y)
	var au := func(y: float) -> float: return -float(e_of.call(y)) + float(cl_of.call(y))
	var ao := func(y: float) -> float: return float(e_of.call(y)) - float(cl_of.call(y))
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fe: float = smoothstep(0.05, 0.42, aw)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var flat: float = 1.0 - 0.9 * exp(-pow((aw - PI) / 0.45, 2.0)) * (1.0 - smoothstep(H - 0.02, H - 0.1, y))   # sırt ortası düz: arma kıvrımda kırılmaz
		var sk: float = pow(t, 0.9) * ((0.04 + 0.016 * bkf) * sin(a * 7.0 + 0.6) + 0.02 * sin(a * 13.0 + 1.9))
		var up: float = (1.0 - t) * 0.006 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y)
		return fe * flat * (sk + up)
	var csk := func(p): return AA._fam(k, p, hem)
	var r: Dictionary = _robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": au, "ao": ao, "ff": ff, "col": func(_a, _y): return col, "lin": o["lin"], "skin": csk,
		"th": 0.008, "ny": 56, "na": 104, "olift": 0.008, "gain": 6.0})
	r["keys"] = keys
	r["ff"] = ff
	r["skin"] = csk
	r["hemy"] = hem
	# etek ucu biyesi + ön kenar katı
	_edge(k, AA._yl(r["hem"], 0.009), 0.006, 0.0022, col.lightened(0.05), csk)
	var ea := []
	var eb := []
	for j in r["ea"].size():
		var q: Vector3 = r["ea"][j]
		if q.y < y0 - 0.02:
			ea.append(q)
			eb.append(r["eb"][j])
	_edge(k, ea, 0.0055, 0.0024, col.lightened(0.04), csk, -0.005)
	_edge(k, eb, 0.0055, 0.0024, col.lightened(0.04), csk, 0.005)
	return r


## Dik yaka: boyunu saran yüksek huni, önde dar açıklık; içi astar. h: yükseklik (boyun üstü), open: ön açıklık yarı açısı
static func _mad_collar(k, b: Dictionary, col: Color, lin: Color, h: float, open: float, flare := 0.0) -> void:
	var N: float = k.N
	var nk: Vector3 = b["nk"]
	var q: float = Q._hq(k)
	var ck := [[N + h * q, nk.x + 0.07 + flare, nk.y + 0.058 + flare, nk.z - 0.072 - flare], [N + h * 0.5 * q, nk.x + 0.052, nk.y + 0.045, nk.z - 0.055], [N + 0.0, nk.x + 0.05, nk.y + 0.04, nk.z - 0.05], [N - 0.05, nk.x + 0.07, nk.y + 0.056, nk.z - 0.064]]
	var skin_t := func(p): return k.torso_skin(minf(float(p.y), N))
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 16, "na": 56, "rng": func(_v): return Vector2(open, TAU - open), "top": func(a):
		return N + q * lerpf(h * 0.8, h, smoothstep(0.3, 1.4, absf(float(a)))), "hem": func(_a): return N - 0.04, "fold": func(a, y, v): return 0.012 * (1.0 - float(v)) * sin(float(a) * 5.0 + float(y) * 3.0),
		"col": func(_a, _y, _v): return col, "inner": lin, "skin": skin_t, "th": 0.006})
	P._cord(k, cg["top"], 0.0042, col.lightened(0.06), false, skin_t)


## Sırtta Uchiha arması: koyu kenar, kırmızı üst, beyaz alt, sap (kabartma)
static func _uchiwa(k, keys: Array, cy: float, r: float, rim: Color) -> void:
	var sk := func(p): return k.torso_skin(maxf(float(p.y), k.H + 0.01))
	I._fan_on(k, keys, 0.0, cy, false, r * 1.11, func(th): return I._crest_r(float(th)), func(_u, _v): return rim, 0.0045, 6, 44, sk)
	I._fan_on(k, keys, 0.0, cy, false, r, func(th): return I._crest_r(float(th)), func(_u, v): return Color(0.76, 0.12, 0.13) if float(v) > 0.0 else Color(0.94, 0.92, 0.88), 0.0068, 8, 52, sk)


# ------------------------------------------------------------------ Rokudaime Gaitō (ref kakashi_outfit_sixth_hokage_vers): bileğe inen önü kapalı kırık beyaz cübbe (sol kanat sağ yana biner, kenar
## sağda yukarıdan etek ucuna iner), kalın katlı huni yaka, içi leylak astarlı geniş kollar, sırtta yukarıdan aşağı kızıl 六代目火影, altta lacivert takım, siyah eldiven
static func _altinci(k) -> void:
	var wh := Color(0.91, 0.91, 0.894)
	var lv := Color(0.76, 0.76, 0.92)
	var nv := Color(0.118, 0.165, 0.282)
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
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, nv, 0.009, 0.01, 1.0, 1.8 if sd == "Left" else 0.7)
		P._lt(k, ar, func(s, _a): return 0.006 + 0.003 * smoothstep(0.7, 0.9, float(s)), func(_s, _a, ins): return nv.darkened(0.3) if ins else nv, 0.3, 0.92, 16, 16)
		_glove(k, sd, ar, bk)
	# cübbe: önü kapalı, bileğe iner; sol kanat sağ yanın üstüne biner (ön orta iki bacağın ortalamasını izler, yırtmaç açmaz)
	var hem: float = lerpf(KN, F, 0.8)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.045), [H - 0.04, hp.x + 0.06, hp.y + 0.085, hp.z - 0.07],
		[KN + 0.05, hp.x + 0.105, hp.y + 0.13, hp.z - 0.13], [hem, hp.x + 0.14, hp.y + 0.13, hp.z - 0.17]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var flat: float = 1.0 - 0.93 * exp(-pow((aw - PI) / 0.4, 2.0)) * (1.0 - smoothstep(H - 0.02, H - 0.12, y))
		var fe: float = 1.0 - 0.8 * exp(-pow((a + 0.42) / 0.12, 2.0))   # kanat kenarında düz: kenar dalgalanıp alt katı göstermez
		return fe * flat * (pow(t, 0.9) * ((0.024 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y))
	var csk := func(p): return AB._lsk(k, p, hem)
	var r: Dictionary = _robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": func(_y): return 0.32, "ao": func(_y): return -0.42, "ff": ff,
		"col": func(_a, _y): return wh, "lin": lv.darkened(0.2), "skin": csk, "th": 0.008, "ny": 58, "na": 104, "olift": 0.008, "gain": 4.0})
	_edge(k, r["eb"].slice(2), 0.0036, 0.002, wh.darkened(0.12), csk, 0.003)
	_edge(k, AA._yl(r["hem"], 0.011), 0.0032, 0.0016, wh.darkened(0.15), csk)
	for sg in [1.0, -1.0]:   # yan dikişler
		Q._run(k, keys, ff, [Vector2(sg * 1.6, C - 0.05), Vector2(sg * 1.58, H), Vector2(sg * 1.56, hem + 0.016)], 0.0022, 0.0014, 0.0011, wh.darkened(0.14), csk, 12)
	# kalın sargı yaka: boyunu saran yatay katlı huni
	var q: float = Q._hq(k)
	var ck := [[N + 0.1 * q, nk.x + 0.04, nk.y + 0.04, nk.z - 0.045], [N + 0.045 * q, nk.x + 0.055, nk.y + 0.05, nk.z - 0.055], [N - 0.01, nk.x + 0.075, nk.y + 0.065, nk.z - 0.065], [N - 0.07, ch.x * 0.86, ch.y * 0.94, ch.z * 1.0]]
	var cf := func(a: float, _y: float, v: float) -> float:
		return 0.05 * sin(float(v) * PI * 3.2 + cos(a) * 0.9) * smoothstep(0.0, 0.2, float(v)) * (1.0 - 0.5 * float(v)) + 0.008 * sin(a * 9.0 + 0.7) * float(v)
	var nsk := func(p): return Q._nsk(k, p)
	var cgl: Dictionary = P._cl(k, {"keys": ck, "ny": 18, "na": 64, "top": func(a): return N + q * (0.1 - 0.012 * cos(float(a))), "hem": func(_a): return N - 0.07, "fold": cf,
		"col": func(_a, _y, _v): return wh, "gain": 6.0, "inner": lv.darkened(0.1), "skin": nsk, "th": 0.007})
	P._cord(k, cgl["top"], 0.0055, wh.darkened(0.05), true, nsk)
	# geniş kollar: içi leylak astar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		AA._hang_sleeve(k, ar, wh, lv.darkened(0.06), 0.02, 0.032, 0.02, 0.9, 2.0 if sd == "Left" else 0.8)
	# sırtta 六代目火影: yukarıdan aşağı kabartma, bel üstünde
	_back_text(k, keys, [A.G_ROKU, A.G_DAI, A.G_ME, A.G_HI, A.G_KAGE], N - 0.07, H + 0.035, rd)


# ------------------------------------------------------------------ Shura Yoroi (ref madara_outfit): koyu mor yüksek yakalı cübbe (önü belden aşağı açık, baldıra iner), dar uzun kol,
## kızıl lake göğüslük (sağ üstünde çatlak), omuzdan sırta beyaz ip, önde dört sıra plakalı etek, iki yanda dize inen dar plaka dizisi, kolun dışında yukarı kalkan omuzluk,
## siyah eldiven + beyaz bilek bandı, lacivert pantolon, beyaz baldır sargısı, sırtta uchiwa
static func _reisi(k) -> void:
	var pu := Color(0.2, 0.15, 0.3)
	var rd := Color(0.6, 0.11, 0.13)
	var rdd := Color(0.36, 0.05, 0.07)
	var wh := Color(0.9, 0.89, 0.86)
	var bk := Color(0.1, 0.1, 0.12)
	var pn := Color(0.12, 0.12, 0.17)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var hp: Vector3 = b["hp"]
	_mad_base(k, b, pu.darkened(0.2), pn, wh)
	var cr: Dictionary = _mad_coat(k, b, {"col": pu, "lin": pu.darkened(0.3), "hem": lerpf(KN, F, 0.42), "e_hem": 0.22, "y0": H + 0.0, "ov": 0.15, "pad": 0.03})
	var keys: Array = cr["keys"]
	_mad_collar(k, b, pu, pu.darkened(0.3), 0.075, 0.18)
	# dar uzun kol + eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 0.7 if sd == "Left" else 1.9
		var sl := func(s: float, a: float) -> float: return 0.012 + 0.008 * smoothstep(0.05, 0.4, s) * (1.0 - smoothstep(0.7, 0.9, s)) + 0.004 * P._lf(s, a, sv) + 0.007 * exp(-pow((s - ak) / 0.08, 2.0)) * sin(a * 3.0 + s * 32.0 + sv)
		P._lt(k, ar, sl, func(s, a, ins): return pu.darkened(0.4) if ins else P._fs(pu, float(sl.call(float(s), float(a))) - 0.014, 14.0), 0.0, 0.88, 34, 20, 0.02)
		_glove(k, sd, ar, bk)
		P._lt(k, ar, func(s, a): return float(sl.call(0.86, float(a))) * 0.4 + 0.004, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, 0.84, 0.905, 4, 18)
		# omuzluk: omuz üstünde yukarı kalkan kanat + kolun dışında üç plaka
		_mad_sode(k, ar, sl, rd, rdd, wh)
	# göğüslük: ön ve arka levha + bel bandı
	var ak: Array = []
	for e in keys:
		ak.append([e[0], float(e[1]) + 0.014, float(e[2]) + 0.02, float(e[3]) - 0.016])
	var ty := func(a: float) -> float: return N - 0.085 - 0.055 * smoothstep(0.4, 1.3, absf(sin(a)))
	L._torso_plate(k, ak, 0.0, 1.5, N - 0.085, H + 0.06, 0.0, 0.011, rd, rdd, 34, 12, ty)
	L._torso_plate(k, ak, PI, 1.5, N - 0.085, H + 0.06, 0.0, 0.011, rd, rdd, 34, 12, func(a): return ty.call(a - PI))
	var bnd: Array = []
	for e in ak:
		bnd.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.006, float(e[3]) - 0.006])
	L._torso_plate(k, bnd, 0.0, PI * 0.995, H + 0.085, H + 0.04, 0.0, 0.01, rd.darkened(0.06), rdd, 60, 3)
	# çatlak: ön levhanın sol üstünden aşağı kırık çizgi (oyuk gibi koyu, levha yüzeyinde)
	for path in [[Vector2(0.62, C + 0.0), Vector2(0.4, C - 0.03), Vector2(0.24, C - 0.02), Vector2(0.1, C - 0.06), Vector2(-0.04, C - 0.08), Vector2(-0.1, C - 0.13), Vector2(-0.12, H + 0.1)],
			[Vector2(0.1, C - 0.06), Vector2(0.16, C - 0.11), Vector2(0.14, C - 0.16)]]:
		L._rail(k, ak, path, 0.0016, 0.0118, 0.0006, rdd.darkened(0.3), 4)
	# beyaz ipler: göğüslüğün üst köşesinden omuz üstünden sırta
	for sg in [1.0, -1.0]:
		var f0: Array = L._sa(ak, sg * 0.5, N - 0.1, 0.012)
		var b0: Array = L._sa(ak, sg * (PI - 0.5), N - 0.1, 0.012)
		var sh: Vector3 = k.m._bp(("Left" if sg > 0.0 else "Right") + "UpperArm")
		var top := Vector3(sg * maxf(absf(sh.x), 0.07), N + 0.012, 0.0)
		var pts := [f0[0], (f0[0] as Vector3).lerp(top, 0.5) + Vector3(0, 0.0, 0.012), top + Vector3(0, 0.006, 0), (b0[0] as Vector3).lerp(top, 0.5) + Vector3(0, 0.0, -0.012), b0[0]]
		P._cord(k, pts, 0.0034, wh, false, func(p): return k.torso_skin(p.y), 0.8, 6)
	# önde dört sıra plakalı etek (iki bacak arasında geçiş: kalkan uyluk delmez), iki yanda dize inen dar plaka dizisi
	_kusazuri(k, hp, H + 0.045, 0.0, 0.62, 4, 0.098, 0.016, 0.075, 0.12, rd, rdd, wh, 0.07)
	for sg in [1.0, -1.0]:
		L._tasset(k, b, {"y0": H + 0.035, "ac": sg * 1.22, "aw": 0.26, "n": 4, "h": 0.1, "ov": 0.016, "flare": 0.16, "add": 0.085, "col": rd, "trim": rdd, "lace": wh, "th": 0.008})
	var ck2: Array = []
	for e in ak:
		ck2.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.012, float(e[3]) - 0.012])
	_uchiwa(k, ck2, C - 0.06, 0.07, rdd.darkened(0.3))


## Omuzluk (sode): omuz üstünde yukarı kalkan kanat (gövdeyle gider) + kolun dış yanında üst üste üç plaka (kolla gider)
static func _mad_sode(k, ar: Dictionary, sl: Callable, col: Color, trim: Color, lace: Color) -> void:
	var sg: float = ar["sg"]
	var sd: String = ar["sd"]
	for i in 3:
		var s0: float = 0.07 + 0.105 * i
		var ao: float = J._outer_a(ar, s0 + 0.05, Vector3(sg, 0.25, 0.0))
		var add := func(s, a): return float(sl.call(float(s), float(a))) + 0.007 + 0.004 * i
		K._shell(k, ar, s0, s0 + 0.12, ao - 0.62, ao + 0.62, add, 0.008, func(u, v, under):
			if under:
				return trim.darkened(0.3)
			return trim if minf(float(u), 1.0 - float(u)) < 0.07 or float(v) > 0.9 else col.darkened(0.06 * float(v)), 10, 12)
		for ux in [-0.3, 0.3]:   # beyaz bağ
			var e: Array = K._lsurf(ar, s0 + 0.1, ao + ux, float(add.call(s0 + 0.1, ao + ux)) + 0.0085)
			P._stud(k, e[0], e[1], 0.0042, lace, P._lskin(ar, s0 + 0.1))
	# omuz kanadı: kol kökünün dışında dikine kalkan kavisli plaka, üstü boyna doğru kıvrılır
	var sh: Vector3 = k.m._bp(sd + "UpperArm")
	var nsk := [["UpperChest", 0.72], [sd + "UpperArm", 0.28]]
	var R: float = 0.075
	L._shell(k, func(u: float, v: float) -> Vector3:
		var z: float = (2.0 * u - 1.0) * 0.042
		var y: float = lerpf(sh.y - 0.02, sh.y + 0.105, v)
		var x: float = sh.x + sg * (R - 0.012 - 0.04 * v * v + 0.02 * pow(2.0 * u - 1.0, 2.0))
		return Vector3(x, y, sh.z + z), func(_u: float, v: float) -> Vector3:
		return Vector3(sg, 0.35 * v, 0.0).normalized(), 10, 8, 0.008, func(u, v, e):
		return trim if e or float(v) > 0.88 else col.darkened(0.08 * (1.0 - float(v))), func(_u, _v, _p): return nsk)


## Önde plakalı etek (kusazuri): üst üste binen sıralar, bağları; ağırlık iki bacak arasında geçer
static func _kusazuri(k, hp: Vector3, y0: float, ac: float, aw: float, n: int, h: float, ovl: float, add: float, flare: float, col: Color, trim: Color, lace: Color, hw: float) -> void:
	var total: float = n * (h - ovl) + ovl
	var W: float = hp.x + add
	var Fz: float = hp.y + add
	var B: float = absf(hp.z) + add
	var skf := func(p: Vector3) -> Array: return _plsk(p, y0, total, 0.84, hw)
	var pt := func(a: float, y: float, off: float) -> Vector3:
		var t: float = (y0 - y) / total
		var q: Vector2 = SE.El.sup(a, W, Fz, -B, 2.3)
		var sc: float = 1.0 + flare * t
		return Vector3(q.x * sc, y, q.y * sc) + Vector3(q.x, 0.0, q.y).normalized() * off
	for i in n:
		var yt: float = y0 - i * (h - ovl)
		var yb: float = yt - h
		var pf := func(u: float, v: float) -> Vector3: return pt.call(ac + aw * (2.0 * u - 1.0), lerpf(yt, yb, v), lerpf(-0.004, 0.008, v) + 0.0035 * i)
		var nf := func(u: float, _v: float) -> Vector3:
			var q: Vector2 = SE.El.sup(ac + aw * (2.0 * u - 1.0), W, Fz, -B, 2.3)
			return Vector3(q.x, 0.1, q.y).normalized()
		L._shell(k, pf, nf, 20, 5, 0.008, func(_u, v, e): return trim if e or float(v) > 0.88 else col.darkened(0.07 * float(v)), func(_u, _v, p): return skf.call(p))
		for u in [0.2, 0.8]:   # beyaz bağ: her sıranın üstünde iki dikine ilmik
			var a: float = ac + aw * (2.0 * float(u) - 1.0)
			var ym: float = yt - 0.018
			var c0: Vector3 = pt.call(a, ym + 0.012, 0.012 + 0.0035 * i)
			var c1: Vector3 = pt.call(a, ym - 0.012, 0.013 + 0.0035 * i)
			P._cord(k, [c0, c0.lerp(c1, 0.5) + Vector3(q_out(c0) * 0.002), c1], 0.0032, lace, false, skf, 0.0, 6)


static func q_out(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z).normalized()


# ------------------------------------------------------------------ Shura Koromo (ref madara_outfit_2): bileğe inen beyaz cübbe (sol kanat verev biner, belden aşağı kenar dikine iner, etek ucunda
## kanatlar hafif açılır), kenarlarda / etek ucunda / kol ağzında beyaz noktalı siyah magatama dizileri, yüksek koyu kızıl yaka, içi leylak geniş kollar, siyah eldiven, siyah pantolon + bot
static func _reisi2(k) -> void:
	var wh := Color(0.949, 0.941, 0.918)
	var lv := Color(0.74, 0.72, 0.9)
	var cr := Color(0.36, 0.11, 0.1)
	var bk := Color(0.08, 0.08, 0.09)
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
	var pas: Dictionary = _mad_base(k, b, bk.lightened(0.04), bk, Color(0, 0, 0, 0))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var pa: Callable = pas[sd]
		# bot konçu: baldır ortasına çıkar, ağzı katlı
		var bo := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.006 + 0.003 * smoothstep(kn + 0.2, kn + 0.16, s) - 0.003 * smoothstep(0.9, 1.0, s)
		P._lt(k, le, bo, func(_s, a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05 * float(cos(float(a)) > 0.4)), kn + 0.17, 1.0, 14, 20)
	# cübbe: verev bindirme göğüste geniş, belden aşağı ön kenar dikine; etek ucunda kanatlar açılır
	var hem: float = lerpf(KN, F, 0.86)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.045), [H - 0.04, hp.x + 0.06, hp.y + 0.085, hp.z - 0.07],
		[KN + 0.05, hp.x + 0.11, hp.y + 0.13, hp.z - 0.13], [hem, hp.x + 0.15, hp.y + 0.13, hp.z - 0.18]]
	var ao := func(y: float) -> float:   # üst kanat kenarı: boyunda solda, göğüs altında sağ yana, belden aşağı ön sağda dikine
		var t: float = smoothstep(N - 0.02, H + 0.06, y)
		var lo: float = lerpf(-0.42, -0.2, smoothstep(KN + 0.05, hem, y))
		return lerpf(lerpf(0.42, -0.78, t), lo, smoothstep(H + 0.06, H - 0.12, y))
	var au := func(y: float) -> float: return lerpf(float(ao.call(y)) + lerpf(0.24, -0.07, smoothstep(KN + 0.05, hem, y)), 0.55, smoothstep(H - 0.08, H + 0.06, y))   # belden aşağı alt kanat üst kanadın altında; yalnız etek ucunda hafif açılır
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		var rad: float = 0.0   # kalçadaki kapanıştan göğse ve eteğe yayılan kıvrımlar
		var dd := Vector2((a + 0.5) * 0.16, y - (H - 0.02))
		if dd.length() < 0.3:
			var ang: float = atan2(dd.y, dd.x)
			rad = 0.012 * sin(ang * 7.0 + 0.4) * smoothstep(0.3, 0.06, dd.length()) * smoothstep(0.0, 0.05, dd.length())
		return pow(t, 0.9) * ((0.024 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.012 * sin(a * 13.0 + 1.9)) + rad + (1.0 - t) * 0.004 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
	var csk := func(p): return AB._lsk(k, p, hem, 0.07)
	var r: Dictionary = _robe(k, {"keys": keys, "top": N + 0.012, "hem": hem, "au": au, "ao": ao, "ff": ff, "col": func(_a, _y): return wh, "lin": lv.darkened(0.15), "skin": csk,
		"th": 0.008, "ny": 60, "na": 108, "olift": 0.009, "gain": 4.0})
	_edge(k, r["eb"].slice(2), 0.0036, 0.002, wh.darkened(0.12), csk, 0.003)
	_edge(k, AA._yl(r["hem"], 0.011), 0.0032, 0.0016, wh.darkened(0.14), csk)
	# magatama: üst kanadın verev kenarı boyunca, ön kenarın altında, etek ucu çevresinde
	var tff := func(a, y): return float(ff.call(float(a), float(y)))
	var mg := func(a: float, y: float, rr: float, rot: float, sk: Callable) -> void:
		var mp: Callable = Q._local(keys, tff, a, y)
		var mo: Vector3 = Q._spt(keys, tff, a, y)[1]
		Q._tomoe(k, mp, mo, rr, rot, 0.0115, bk, sk, wh)
	var ys := []
	for i in 6:
		ys.append(lerpf(N - 0.05, H + 0.08, float(i) / 5.0))
	for y in ys:
		mg.call(float(ao.call(float(y))) - 0.11, float(y), 0.012, 2.4, func(p): return k.torso_skin(p.y))
	for i in 3:
		var y: float = lerpf(KN - 0.02, hem + 0.12, float(i) / 2.0)
		mg.call(float(ao.call(y)) - 0.1, y, 0.012, 2.4, csk)
	for i in 22:
		var a: float = wrapf(-PI + TAU * (float(i) + 0.5) / 22.0, -PI, PI)
		if a < -0.12 and a > -0.4:
			continue
		mg.call(a, hem + 0.045, 0.0125, 2.4, csk)
	# yüksek koyu kızıl yaka: boynu saran, arkada başı çerçeveleyen geniş kat
	_mad_collar(k, b, cr, cr.darkened(0.3), 0.11, 0.42, 0.03)
	# geniş kollar: içi leylak; kol ağzında magatama
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.4 if sd == "Left" else 0.3
		var sl: Callable = AA._hang_sleeve(k, ar, wh, lv.darkened(0.06), 0.02, 0.034, 0.022, 0.9, sv)
		_glove(k, sd, ar, bk)
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.45, 0.9, 12, 16)
		var L0: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
		var s0: float = 0.84
		for i in 9:
			var a0: float = TAU * float(i) / 9.0 - PI
			var R: float = P._lr(ar, s0) + float(sl.call(s0, a0))
			var mp := func(u: float, v: float, lift: float) -> Vector3:
				var s2: float = s0 - v / L0
				var a2: float = a0 + u / R
				return K._lsurf(ar, s2, a2, float(sl.call(s2, a2)) + lift)[0]
			var mo: Vector3 = K._lsurf(ar, s0, a0, float(sl.call(s0, a0)))[1]
			Q._tomoe(k, mp, mo, 0.0105, 2.4, 0.002, bk, func(_p): return P._lskin(ar, s0), wh)


# ------------------------------------------------------------------ Shura Gunpuku (ref madara_outfit_battle_attire_ver): baldıra inen lacivert savaş cübbesi (önü kuşaktan aşağı açık, açık mavi astar),
## ağzı örten yüksek dik yaka, sağ omuzdan sol kalçaya kahve kılıf kayışı (sırtta geri döner), siyah kemer + gümüş çift çubuk toka, içi açık mavi geniş kollar,
## siyah eldiven + beyaz bilek bandı, siyah pantolon + açık mavi-beyaz baldır sargısı, sırtta uchiwa
static func _reisi3(k) -> void:
	var nv := Color(0.12, 0.14, 0.33)
	var lb := Color(0.56, 0.64, 0.86)
	var br := Color(0.33, 0.22, 0.15)
	var bk := Color(0.08, 0.08, 0.1)
	var sv2 := Color(0.72, 0.74, 0.78)
	var wh := Color(0.9, 0.9, 0.92)
	var wr := Color(0.8, 0.84, 0.92)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	_mad_base(k, b, nv.darkened(0.35), bk, wr)
	var cr: Dictionary = _mad_coat(k, b, {"col": nv, "lin": lb.darkened(0.08), "hem": lerpf(KN, F, 0.48), "e_hem": 0.34, "y0": H + 0.035, "ov": 0.14, "pad": 0.034})
	var keys: Array = cr["keys"]
	_mad_collar(k, b, nv, nv.darkened(0.3), 0.17, 0.08, 0.012)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 2.1 if sd == "Left" else 0.6
		AA._hang_sleeve(k, ar, nv, lb.darkened(0.15), 0.02, 0.03, 0.02, 0.9, sv)
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.45, 0.9, 12, 16)
		_glove(k, sd, ar, bk)
		P._lt(k, ar, func(_s, _a): return 0.009, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, 0.855, 0.9, 3, 18)
	# kemer + toka
	var by: float = H + 0.035
	var bkk: Array = []
	for e in keys:
		bkk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	P._sash(k, bkk, by, 0.016, 0.004, bk, 0.1)
	var bx: Array = P._fp(bkk, 0.0, by, true, 0.016)
	P._boxr(k, bx[0], Vector3(0.026, 0, 0), Vector3(0, 0.018, 0), Vector3(0, 0, 0.004), bk.lightened(0.08), k.torso_skin(by), 0.25)
	for dx in [-0.009, 0.009]:
		P._boxr(k, (bx[0] as Vector3) + Vector3(float(dx), 0.0, 0.004), Vector3(0.0035, 0, 0), Vector3(0, 0.014, 0), Vector3(0, 0, 0.002), sv2, k.torso_skin(by), 0.3)
	# kılıf kayışı: sağ omuzdan göğüs üstünden sol kalçaya, sırtta sol kalçadan sağ omuza
	var skk: Array = []
	for e in keys:
		skk.append([e[0], float(e[1]) + 0.003, float(e[2]) + 0.003, float(e[3]) - 0.003])
	var sk_t := func(p): return k.torso_skin(maxf(float(p.y), H + 0.01))
	var ys: float = N + 0.006
	var x0: float = -minf(0.09, float(b["ch"].x) * 0.58)
	var pts := []
	var ou := []
	var n := 18
	for j in n + 1:
		var t := float(j) / n
		var e: Array = P._fp(skk, lerpf(float(b["wa"].x) * 0.92, x0, t), lerpf(H + 0.05, ys, t), false, 0.006)
		pts.append(e[0])
		ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.8, 1.0, t)).normalized())
	for j in range(n, -1, -1):
		var t := float(j) / n
		var e: Array = P._fp(skk, lerpf(float(b["wa"].x) * 0.92, x0, t), lerpf(H + 0.05, ys, t), true, 0.006)
		pts.append(e[0])
		ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.8, 1.0, t)).normalized())
	k.strip(pts, ou, 0.022, 0.0045, br, false, sk_t)
	var p2 := []
	for i in pts.size():
		p2.append((pts[i] as Vector3) + (ou[i] as Vector3) * 0.0042)
	k.strip(p2, ou, 0.0028, 0.001, br.lightened(0.14), false, sk_t)
	_uchiwa(k, keys, C - 0.05, 0.072, nv.darkened(0.45))


# ------------------------------------------------------------------ Shura Wakate (ref madara_outfit_young_ver): baldıra inen mor cübbe (önü kuşaktan aşağı açık, leylak astar), yüksek huni yaka,
## üç katlı geniş gri obi, içi leylak geniş kollar, siyah pantolon + beyaz baldır sargısı, sırtta uchiwa
static func _reisi_genc(k) -> void:
	var pu := Color(0.36, 0.27, 0.5)
	var li := Color(0.8, 0.77, 0.92)
	var gy := Color(0.66, 0.64, 0.7)
	var bk := Color(0.08, 0.08, 0.1)
	var wh := Color(0.9, 0.9, 0.9)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	_mad_base(k, b, pu.darkened(0.45), bk, wh)
	var cr: Dictionary = _mad_coat(k, b, {"col": pu, "lin": li, "hem": lerpf(KN, F, 0.5), "e_hem": 0.36, "y0": H + 0.0, "ov": 0.14, "pad": 0.034})
	var keys: Array = cr["keys"]
	_mad_collar(k, b, pu, pu.darkened(0.3), 0.13, 0.12, 0.02)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.2 if sd == "Left" else 2.8
		AA._hang_sleeve(k, ar, pu, li.darkened(0.12), 0.02, 0.032, 0.022, 0.9, sv)
		P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return pu.darkened(0.5) if ins else pu.darkened(0.3), 0.45, 0.93, 12, 16)
	# geniş obi: üç kat bant (ortadaki daha açık), kenarlarda dikiş
	var obk: Array = []
	for e in keys:
		obk.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.008, float(e[3]) - 0.006])
	var by: float = H + 0.06
	P._sash(k, obk, by, 0.06, 0.003, gy.darkened(0.06), 0.1)
	for i in 3:
		var yy: float = by + 0.04 - 0.04 * i
		P._sash(k, obk, yy, 0.016, 0.009 + 0.002 * float(i == 1), gy.lightened(0.05 * float(i == 1)), 0.05)
	_uchiwa(k, keys, C - 0.05, 0.072, pu.darkened(0.5))


# ------------------------------------------------------------------ Mizu Doresu (ref mei_outfit): boyna çıkan file üst (omuzlar açık, koyu boğaz bandı), omzu açık mavi elbise: göğüste soldan inip
## sağ bele verev giden beyaz biyeli kanat, krem kemer + beyaz kilit toka, kemerden aşağı sağ bacakta yırtmaç (ön kanat sol bacağı örter), baldır ortasına inen etek,
## kol kökünden bileğe mavi kol + fırfırlı çan ağız (koyu astar), siyah şort + file tayt, açık gri dize çıkan çizme (önde koyu şerit)
static func _mizu(k) -> void:
	var bl := Color(0.13, 0.27, 0.72)
	var bld := Color(0.07, 0.13, 0.36)
	var wh := Color(0.95, 0.95, 0.94)
	var cm := Color(0.87, 0.82, 0.62)
	var dk := Color(0.15, 0.15, 0.17)
	var nt := Color(0.1, 0.1, 0.12)
	var sh := Color(0.118, 0.141, 0.282)
	var gb := Color(0.66, 0.65, 0.72)
	var gs := Color(0.36, 0.33, 0.48)
	var skc: Color = Q._skc(k)
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
	# üst gövde: ten + file üst (boyundan göğse, omuzlar açık), koyu boğaz bandı
	var sk_k := [P._kp(nk, N + 0.06, 0.004, 0.006), P._kp(nk, N + 0.02, 0.006), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], [C + 0.0, ch.x * 0.95, ch.y + 0.003, ch.z * 0.98], P._kp(ch, C - 0.03, 0.004), P._kp(wa, H + 0.1, 0.004)]
	SE.body_layer(k, sk_k, 24, 44, func(_i, _j, _p): return skc)
	var hal := func(a: float, y: float) -> bool:   # file üstün sınırı: boyunda dar, göğse doğru genişler (omuz başı açık)
		var w: float = lerpf(0.42, 0.95, smoothstep(N + 0.0, N - 0.11, y))
		return absf(wrapf(a, -PI, PI)) < w or absf(wrapf(a - PI, -PI, PI)) < w
	for fr in [0.0, PI]:
		P._net_patch(k, sk_k, func(a, y): return bool(hal.call(float(a), float(y))), fr - 1.0, fr + 1.0, N - 0.13, N + 0.025, 0.012, 0.0011, 0.0015, nt)
	for sg in [1.0, -1.0]:   # file üstün koyu kenarı: boyundan kol altına
		for fr in [0.0, PI]:
			var pts := []
			var ou := []
			for i in 13:
				var y: float = lerpf(N + 0.0, N - 0.12, float(i) / 12.0)
				var w: float = lerpf(0.42, 0.95, smoothstep(N + 0.0, N - 0.11, y))
				var e: Array = Q._spt(sk_k, Callable(), fr + sg * w, y, 0.0022)
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, 0.0032, 0.0016, nt, false, func(p): return k.torso_skin(p.y))
	var ck := [[N + 0.075 * Q._hq(k), nk.x + 0.008, nk.y + 0.01, nk.z - 0.01], [N + 0.0, nk.x + 0.014, nk.y + 0.014, nk.z - 0.014]]
	P._cl(k, {"keys": ck, "ny": 6, "na": 40, "top": func(_a): return N + 0.075 * Q._hq(k), "hem": func(_a): return N + 0.0, "col": func(_a, _y, _v): return nt.lightened(0.05), "th": 0.004, "inner": nt, "skin": func(p): return Q._nsk(k, p)})
	# bacaklar: siyah şort, file tayt (ten üstünde ağ), dize çıkan açık gri çizme
	var ssk := [P._kp(wa, H + 0.06, 0.008), P._kp(hp, H - 0.04, 0.012), [H - 0.12, hp.x * 0.86, hp.y * 0.86, hp.z * 0.86]]
	SE.body_layer(k, ssk, 8, 40, func(_i, _j, _p): return sh)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.2
		P._lt(k, le, func(s, a): return 0.007 + 0.002 * P._lf(s, a, sv), func(_s, _a, ins): return sh.darkened(0.4) if ins else sh, 0.0, 0.17, 10, 22)
		P._lt(k, le, func(s, a): return 0.0105 + 0.002 * P._lf(s, a, sv), func(_s, _a, ins): return sh.darkened(0.4) if ins else sh.lightened(0.05), 0.155, 0.175, 2, 22)
		P._bare(k, le, skc, 0.15, kn + 0.06)
		P._net_limb(k, le, 0.16, kn + 0.08, 0.0024, 11, 0.026, 0.0012, nt)
		var bo := func(s: float, a: float) -> float: return 0.009 + 0.003 * smoothstep(kn + 0.06, kn + 0.0, s) - 0.003 * smoothstep(0.9, 1.0, s) + 0.0015 * sin(a * 4.0 + s * 18.0) * smoothstep(0.9, 0.7, s)
		P._lts(k, le, bo, func(s, a, ins):
			if ins:
				return gb.darkened(0.35)
			return gb.darkened(0.08 * float(cos(float(a)) < -0.4) + 0.05 * float(float(s) > 0.95)), func(a): return kn + 0.01 - 0.025 * pow(maxf(0.0, cos(float(a))), 2.0), 1.0, 22, 22)
		var pts := []
		var ou := []
		var sp := []
		for i in 12:
			var s: float = lerpf(kn + 0.0, 0.97, float(i) / 11.0)
			var e: Array = Q._ls(le, s, 0.0, float(bo.call(s, 0.0)) + 0.001)
			pts.append(e[0])
			ou.append(e[1])
			sp.append(s)
		k.strip(pts, ou, 0.009, 0.0016, gs, false, func(p):
			var bi := 0
			var bd := 99.0
			for i in pts.size():
				var dd: float = ((pts[i] as Vector3) - (p as Vector3)).length_squared()
				if dd < bd:
					bd = dd
					bi = i
			return P._lskin(le, float(sp[bi])))
	# elbise: omuzları açık düz üst kenar, sol kanat göğüsten sağ bele verev biner, kemerden aşağı sağ bacakta yırtmaç
	var hem: float = lerpf(KN, F, 0.45)
	var top: float = N - 0.085
	var keys := [[top, ch.x * 0.99, ch.y * 0.96 + 0.006, ch.z * 1.0 - 0.006], P._kp(ch, C - 0.03, 0.012), P._kp(wa, H + 0.12, 0.012), P._kp(wa, H + 0.03, 0.014), [H - 0.04, hp.x + 0.026, hp.y + 0.03, hp.z - 0.026],
		[KN + 0.05, hp.x + 0.05, hp.y + 0.06, hp.z - 0.07], [hem, hp.x + 0.065, hp.y + 0.065, hp.z - 0.1]]
	var topf := func(a: float) -> float: return lerpf(top, C - 0.02, exp(-pow((absf(a) - PI * 0.5) / 0.5, 2.0)))
	var yb: float = H + 0.03
	var ao := func(y: float) -> float:
		var up: float = lerpf(0.1, -1.0, smoothstep(C - 0.04, yb + 0.012, y))
		return lerpf(up, -0.08, smoothstep(yb + 0.012, yb - 0.012, y))
	var au := func(y: float) -> float: return lerpf(0.4, -1.25, smoothstep(yb + 0.012, yb - 0.012, y))
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((yb - y) / (yb - hem), 0.0, 1.0)
		return pow(t, 0.9) * (0.026 * sin(a * 6.0 + 0.7) + 0.012 * sin(a * 11.0 + 2.1)) + (1.0 - t) * 0.004 * sin(a * 5.0 + y * 12.0) * smoothstep(top, C - 0.05, y)
	var dsk := func(p): return _rsk(k, p, hem, 0.04, 0.55, -0.035)
	var r: Dictionary = _robe(k, {"keys": keys, "top": top, "topf": topf, "hem": hem, "au": au, "ao": ao, "ff": ff, "col": func(_a, _y): return bl, "lin": bld, "skin": dsk,
		"th": 0.006, "ny": 54, "na": 100, "olift": 0.006, "gain": 5.0})
	# beyaz biye: kanadın verev kenarı; yırtmacın iki kenarı ve etek ucu kendi renginde kat
	var fl := []
	var sl1 := []
	var sl2 := []
	for j in r["eb"].size():
		var q: Vector3 = r["eb"][j]
		if q.y > yb + 0.004:
			fl.append(q)
		elif q.y < yb - 0.02:
			sl1.append(q)
			sl2.append(r["ea"][j])
	P._cord(k, fl, 0.0042, wh, false, dsk, 0.0, 6)
	_edge(k, sl1, 0.005, 0.002, bl.lightened(0.06), dsk, 0.004)
	_edge(k, sl2, 0.005, 0.002, bl.lightened(0.06), dsk, -0.004)
	_edge(k, AA._yl(r["hem"], 0.009), 0.0055, 0.002, bl.lightened(0.06), dsk)
	P._cord(k, r["top"], 0.0045, bl.lightened(0.08), false, func(p): return k.torso_skin(p.y), 0.0, 6)
	# krem kemer + beyaz kilit toka
	var bk2: Array = []
	for e in keys:
		bk2.append([e[0], float(e[1]) + 0.005, float(e[2]) + 0.005, float(e[3]) - 0.005])
	P._sash(k, bk2, yb, 0.014, 0.003, cm, 0.08)
	var bx: Array = P._fp(bk2, 0.0, yb, true, 0.013)
	P._boxr(k, bx[0], Vector3(0.022, 0, 0), Vector3(0, 0.017, 0), Vector3(0, 0, 0.005), wh, k.torso_skin(yb), 0.25)
	P._boxr(k, (bx[0] as Vector3) + Vector3(0, 0, 0.005), Vector3(0.012, 0, 0), Vector3(0, 0.008, 0), Vector3(0, 0, 0.002), wh.darkened(0.18), k.torso_skin(yb), 0.3)
	# kollar: omuz başı açık ten, kol kökünden bileğe mavi kol, fırfırlı çan ağız (içi koyu)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.0
		P._bare(k, ar, skc, 0.0, 0.2)
		var sl := func(s: float, a: float) -> float:
			var bell: float = smoothstep(0.76, 0.97, s)
			return 0.007 + 0.004 * smoothstep(0.08, 0.2, s) + 0.034 * bell * bell + (0.002 + 0.004 * bell) * sin(a * 7.0 + sv) * bell + 0.003 * P._lf(s, a, sv) * (1.0 - bell) + 0.005 * exp(-pow((s - ak) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sl, func(s, a, ins): return bld if ins else P._fs(bl, float(sl.call(float(s), float(a))) - 0.009 - 0.034 * pow(smoothstep(0.76, 0.97, float(s)), 2.0), 12.0), 0.11, 0.97, 32, 26, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sl.call(float(s), float(a))) - 0.004, bld, 0.82, 0.97, 8, 26)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return bld if ins else bl.lightened(0.06), 0.11, 0.135, 3, 26)
