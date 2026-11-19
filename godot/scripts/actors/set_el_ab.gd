extends RefCounted
## Elle modellenmiş setler, parti ab: ss_kurbaga_bilge, ss_kurbaga_bilge2, ss_yilan_cubbe, ss_kizil_zirh, ss_tavsan_tanri, ss_tavsan_tanri2. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), l (L), n (NN), q (Q) dosyalarından; burada uzun kapalı cübbe, geniş kol, file, kurbağa kuklaları ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const NN = preload("res://scripts/actors/set_el_n.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const W = preload("res://scripts/actors/set_el_w.gd")
const FF = preload("res://scripts/actors/set_el_f.gd")

const DONE := ["ss_kurbaga_bilge", "ss_kurbaga_bilge2", "ss_yilan_cubbe", "ss_kizil_zirh", "ss_tavsan_tanri", "ss_tavsan_tanri2"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_kurbaga_bilge": _gama(k, false)
		"ss_kurbaga_bilge2": _gama(k, true)
		"ss_yilan_cubbe": _hebi(k)
		"ss_kizil_zirh": _shinku(k)
		"ss_tavsan_tanri": _megami(k)
		"ss_tavsan_tanri2": _megami2(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
static func _tsk(k, p: Vector3) -> Array:
	return k.torso_skin(p.y)


## Uzun etek / cübbe ağırlığı (bileğe ya da yere inen giysiler; parti al, ag, ab, at ortak). Ağırlık noktanın yönünden (açı) ve boyundan gelir:
## üst üste binen katlar (biye, bant, düğme) aynı yerde aynı ağırlığı alır. Ön: kalçanın hemen altından uyluğu tam izler (kalkan diz pantolonu
## kumaştan çıkarmaz); fhw ön geçiş genişliği: dar tutulur (geniş geçişte ön orta iki bacağın ortalamasında kalır, öne atılan baldır onu deler).
## Diz altında ön çoğunlukla baldırı izler (etek ucu uylukla levha gibi öne kalkmaz, dizden baldır boyunca sarkar). Arka: boy boyunca artar; baldır payı
## baldır kalınlığında en çok, etek ucuna doğru azalır (geri kalkan topuk arka eteği delmez ama etek ucunu da yukarı savurmaz, astar
## yalnız doğal açılma kadar görünür); bh: etek ucunda baldır payı (çok geniş çan etekte düşük). hem: ailenin en uzun katının ucu.
static func _lsk(k, p: Vector3, hem: float, fhw := 0.028, bh := 0.5) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var KN: float = k.K
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.11), 0.5)
	var wb: float = lerpf(0.86 * pow(minf(1.0, (H - p.y) / 0.32), 0.7), 0.94, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.92, smoothstep(0.75, 1.0, t))
	var hw: float = lerpf(fhw, 0.08, bk)
	var s: float = smoothstep(-hw, hw, x)
	var kf: float = smoothstep(KN + 0.03, KN - 0.1, p.y) * 0.6
	var kbk: float = smoothstep(KN + 0.08, KN - 0.08, p.y) * lerpf(0.85, bh, smoothstep(0.0, 1.0, clampf((KN - 0.12 - p.y) / maxf(0.05, KN - 0.12 - hem), 0.0, 1.0)))
	var kb: float = lerpf(kf, kbk, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Bol paça: dizaltında toplanır, iç yanı ve kıvrım vadileri koyulaşır (ref: Jiraiya pantolonunun koyu iç gölgeleri)
static func _baggy(k, le: Dictionary, col: Color, base: float, bag: float, tk: float, sv: float, inner_dk := 0.3, top_s := 0.0) -> Callable:
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		var g: float = 1.0 - smoothstep(tk - 0.03, tk + 0.005, s)
		var cr: float = 0.01 * exp(-pow((s - kn) / 0.05, 2.0)) * sin(a * 3.0 + s * 30.0 + sv)
		var ru: float = 0.012 * exp(-pow((s - tk + 0.045) / 0.045, 2.0)) * sin(a * 9.0 + sv)
		return ((0.007 + bag * 0.2) * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + cr + ru) * g
	var ad := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = (base + 0.012 * smoothstep(0.0, 0.3, s) + bag * smoothstep(top_s, top_s + 0.2, s) * (1.0 - 0.15 * smoothstep(0.6, tk, s))) * (1.0 - 0.42 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s)))
		var g: float = smoothstep(tk - 0.06, tk + 0.008, s)
		return lerpf(v, 0.008, g) + float(fo.call(s, a))
	P._lt(k, le, ad, func(s, a, ins):
		if ins:
			return col.darkened(0.45)
		var inn: float = clampf(-sin(float(a)) * sg, 0.0, 1.0) * 0.6 + clampf(-cos(float(a)), 0.0, 1.0) * 0.25
		return P._fs(col, fo.call(s, a), 16.0).darkened(inner_dk * inn * smoothstep(0.05, 0.3, float(s))), 0.0, tk + 0.012, 42, 24, 0.02)
	return ad


## Izgara satırları üzerinde yerel eşleme: (u yatay metre, v dikey metre, kalkış) -> nokta. fi, fj: merkez sütun / satır
static func _gmap(rows: Array, fi: float, fj: float) -> Callable:
	var nj: int = rows.size()
	var ni: int = (rows[0] as Array).size()
	var at := func(x: float, y: float) -> Vector3:
		var xc: float = clampf(x, 0.0, ni - 1.001)
		var yc: float = clampf(y, 0.0, nj - 1.001)
		var i0: int = int(xc)
		var j0: int = int(yc)
		var fx: float = xc - i0
		var fy: float = yc - j0
		var a: Vector3 = (rows[j0][i0] as Vector3).lerp(rows[j0][i0 + 1], fx)
		var b: Vector3 = (rows[j0 + 1][i0] as Vector3).lerp(rows[j0 + 1][i0 + 1], fx)
		return a.lerp(b, fy)
	var si: float = ((at.call(fi + 1.0, fj) as Vector3) - (at.call(fi, fj) as Vector3)).length()
	var sj: float = ((at.call(fi, fj + 1.0) as Vector3) - (at.call(fi, fj) as Vector3)).length()
	return func(u: float, v: float, l: float) -> Vector3:
		var p: Vector3 = at.call(fi + u / maxf(0.0005, si), fj - v / maxf(0.0005, sj))
		return p + Vector3(p.x, 0.0, p.z).normalized() * l


## Kol: omuzdan bileğe genişleyen geniş kol. Alt yanı sarkık torba, ağız bileğe doğru biraz toplanır (koşuda kocaman koyu halka açmaz).
## colf(s, a) dış renk; lin: astar; s1 ağız
static func _wsleeve(k, ar: Dictionary, colf: Callable, lin: Color, s1: float, flare: float, hangv: float, sv: float) -> Callable:
	var en: float = ar["kn"]
	var sg: float = ar["sg"]
	var sf := func(s: float, a: float) -> float:
		var fl: float = smoothstep(0.08, s1, s)
		var hang: float = maxf(0.0, -sin(a) * sg)
		var nar: float = smoothstep(s1 - 0.2, s1, s)
		return 0.018 + flare * fl - 0.22 * flare * nar + (hangv - 0.25 * hangv * nar) * fl * hang * hang + (0.003 + 0.008 * fl) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
	P._lt(k, ar, sf, func(s, a, ins):
		if ins:
			return lin
		var f: float = float(sf.call(float(s), float(a))) - 0.018 - flare * smoothstep(0.08, s1, float(s))
		return P._fs(colf.call(float(s), float(a)), f, 9.0), 0.0, s1, 32, 26, 0.03)
	K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, lin, 0.45, s1, 12, 26)
	return sf


## Önü açık uzun giysi (parti n _coat yöntemi) ama ağırlık dışarıdan: skin(p)
static func _coat2(k, o: Dictionary, skin: Callable) -> Dictionary:
	var keys: Array = o["keys"]
	var hem: float = o["hem"]
	var top: float = keys[0][0]
	var ef: Callable = o["e"]
	var ff: Callable = o["fold"]
	var col: Color = o["col"]
	var e_h: float = ef.call(hem)
	var rnd: float = o.get("round", 0.07)
	var rf := func(a: float) -> float:
		return rnd * (1.0 - smoothstep(e_h, e_h + 0.42, absf(wrapf(a, -PI, PI))))
	var rg := func(v: float) -> Vector2:
		var e: float = ef.call(lerpf(top, hem, v))
		return Vector2(e, TAU - e)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": o.get("ny", 40), "na": o.get("na", 88), "rng": rg, "top": func(_a): return top, "hem": func(a): return hem + float(rf.call(float(a))),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return col, "gain": o.get("gain", 3.6), "inner": o["lin"], "skin": skin, "th": o.get("th", 0.006)})
	P._cur_hem = hem
	cg["sk"] = skin
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


# ------------------------------------------------------------------ Gama Sennin (ref Shinobi Striker "Jiraiya Outfit" / "(Sage)"): file iç giysi, soluk yeşil sarmal kısa kimono + önde sarkan peş,
## dizaltında toplanan bol yeşil pantolon, file ön kol ve baldır, yeşil el koruyucu, dize inen önü açık kolsuz kırmızı yelek (göğüste iki sarı yuvarlak).
## Kai (Sage): omuzlarda Fukasaku (sağ) ve Shima (sol) kuklaları
static func _gama(k, sage: bool) -> void:
	var gn := Color(0.5, 0.63, 0.52)
	var rd := Color(0.54, 0.09, 0.11)
	var lin := Color(0.36, 0.06, 0.07)
	var yl := Color(0.95, 0.82, 0.42)
	var nb := Color(0.17, 0.18, 0.26)
	var nt := Color(0.6, 0.64, 0.78)
	var bk := Color(0.1, 0.1, 0.12)
	var mt := Color(0.62, 0.74, 0.66)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# file iç giysi: V yakadan görünen ağ (gerçek iplik)
	var inn: Array = P._inner(k, b, func(_i, _j, _p): return nb, 0.006)
	K._seat(k, b, nb)
	P._net_patch(k, inn, func(_a, _y): return true, -0.75, 0.75, C - 0.16, N + 0.05, 0.02, 0.0013, 0.0018, nt)
	# kısa sarmal kimono: V yaka, bele sokulu
	var kk := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 0.94, ch.y * 0.92, ch.z * 1.0], P._kp(ch, C - 0.03, 0.02), P._kp(wa, H + 0.12, 0.02), P._kp(hp, H - 0.03, 0.022)]
	var yv: float = C - 0.13
	var tp := func(a: float) -> float: return lerpf(yv, N + 0.012, pow(clampf(absf(a) / 0.64, 0.0, 1.0), 1.1))
	var kf := func(a: float, y: float, _v: float) -> float:
		return 0.012 * sin(a * 7.0 + y * 9.0) * smoothstep(C, H + 0.05, y) + 0.005 * sin(a * 4.0 - y * 14.0)
	P._cl(k, {"keys": kk, "ny": 22, "na": 56, "top": func(a): return tp.call(float(a)), "hem": func(_a): return H - 0.03, "fold": kf, "col": func(_a, _y, _v): return gn, "gain": 6.0, "th": 0.0, "skin": func(p): return _tsk(k, p)})
	# yaka: sol kanat sağın üstüne biner; kalın devrik bant + alttaki kanadın bandı
	var cw := func(_t): return 0.026
	P._band(k, kk, [Vector2(-0.6, N + 0.005), Vector2(-0.4, C + 0.02), Vector2(-0.12, yv + 0.01), Vector2(0.1, C - 0.2)], cw, 0.006, gn.lightened(0.04), 6, 6, 0.1, 0.22)
	P._band(k, kk, [Vector2(0.6, N + 0.005), Vector2(0.38, C + 0.03), Vector2(0.1, yv - 0.005), Vector2(-0.22, C - 0.2), Vector2(-0.62, H + 0.1)], func(t): return 0.028 * (1.0 - 0.15 * float(t)), 0.009, gn.lightened(0.07), 6, 6, 0.1, 0.22)
	P._line(k, kk, [Vector2(-0.4, C - 0.13), Vector2(-0.7, H + 0.08), Vector2(-0.9, H + 0.02)], 0.003, 0.004, 0.002, gn.darkened(0.28), 6)
	# kuşak: ince koyu bez
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var kb := [P._kp(bl, H + 0.11, 0.026), P._kp(bl, H - 0.01, 0.03)]
	P._sash(k, kb, H + 0.045, 0.02, 0.002, bk.lightened(0.06), 0.18)
	# önde sarkan peş (kimononun ön paneli): kuşaktan uyluk ortasına
	var hm: float = H - 0.24
	var pk := [P._kp(bl, H + 0.05, 0.034), P._kp(hp, H - 0.04, 0.038), [hm, hp.x + 0.03, hp.y + 0.05, hp.z - 0.04]]
	var fsk := func(p): return k.cloth_skin(p, hm, 0.5)
	var pf := func(a: float, y: float, _v: float) -> float: return 0.012 * sin(a * 11.0 + 0.4) * smoothstep(H, hm, y)
	var fl: Dictionary = P._cl(k, {"keys": pk, "ny": 14, "na": 22, "rng": func(_v): return Vector2(-0.42, 0.42), "top": func(_a): return H + 0.035, "hem": func(_a): return hm, "fold": pf,
		"col": func(_a, _y, _v): return gn, "gain": 6.0, "th": 0.005, "inner": gn.darkened(0.35), "skin": fsk})
	for e in [fl["ea"], fl["eb"], fl["hem"]]:
		P._bd(k, e, 0.003, 0.002, gn.lightened(0.12), false, fsk)
	# uzuvlar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sg: float = ar["sg"]
		var sv: float = 1.2 if sd == "Left" else 2.6
		var en: float = ar["kn"]
		# yeşil kol: dolgun, ön kolun ortasında büzgülü ağız
		var s1 := 0.78
		var sf := func(s: float, a: float) -> float:
			var bul: float = 0.012 + 0.018 * smoothstep(0.1, 0.5, s) * (1.0 - smoothstep(s1 - 0.12, s1, s))
			return bul + (0.003 + 0.006 * smoothstep(0.2, 0.6, s)) * P._lf(s, a, sv) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - s1 + 0.04) / 0.03, 2.0)) * sin(a * 9.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins): return gn.darkened(0.4) if ins else P._fs(gn, float(sf.call(float(s), float(a))) - 0.012 - 0.018 * smoothstep(0.1, 0.5, float(s)) * (1.0 - smoothstep(s1 - 0.12, s1, float(s))), 14.0), 0.0, s1, 32, 22, 0.02)
		# file ön kol: koyu taban + iki yönde iplik, bilekte koyu bant
		P._lt(k, ar, func(_s, _a): return 0.0035, func(_s, _a, ins): return nb.darkened(0.3) if ins else nb, s1 - 0.06, 0.975, 14, 16)
		P._net_limb(k, ar, s1 - 0.01, 0.95, 0.0058, 9, 0.024, 0.0013, nt)
		P._lt(k, ar, func(_s, _a): return 0.0068, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05), 0.945, 0.985, 4, 16)
		# el koruyucu: bileğin dışında bombeli yeşil plaka + kayış
		K._shell(k, ar, 0.875, 0.995, sg * PI * 0.5 - 0.55, sg * PI * 0.5 + 0.55, func(s, _a): return 0.009 + 0.004 * smoothstep(0.9, 0.99, float(s)), 0.0055, func(_u, _v, e): return mt.darkened(0.25) if e else mt, 8, 12)
		k.wrap_turn(P._lp(ar, 0.9), P._ld(ar, 0.9), P._lr(ar, 0.9) + 0.008, 0.0045, 0.0, bk, P._lskin(ar, 0.9))
		# bol yeşil pantolon: dizaltında toplanır; altta file baldır, bilekte koyu bant
		var tk := 0.74
		_baggy(k, le, gn, 0.014, 0.05, tk, sv, 0.34, float(le["kn"]) - 0.2)
		P._lt(k, le, func(s, _a): return 0.004 - 0.001 * float(s), func(_s, _a, ins): return nb.darkened(0.3) if ins else nb, tk - 0.06, 0.985, 14, 18)
		P._net_limb(k, le, tk + 0.005, 0.945, 0.0068, 11, 0.026, 0.0014, nt)
		P._lt(k, le, func(_s, _a): return 0.0075, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.05), 0.935, 0.99, 4, 18)
		Q._ring_on(k, le, tk + 0.004, func(_s, _a): return 0.012, 0.012, gn.darkened(0.12), 0.004)
	# kırmızı yelek: kolsuz, önü açık, dize iner; kanatlar düz sarkar
	var hem: float = k.K + 0.06
	var keys: Array = NN._coat_keys(k, b, 0.04, hem, 0.13, 0.11, 0.135)
	keys[1] = [N - 0.055, ch.x * 1.08, ch.y * 0.97, ch.z * 1.07]
	var ef := func(y: float) -> float: return 0.36 + 0.24 * pow(smoothstep(C - 0.02, N + 0.012, y), 1.3)
	var cg: Dictionary = NN._coat(k, {"keys": keys, "hem": hem, "e": ef, "fold": NN._coat_fold(k, hem, 0.028), "col": rd, "lin": lin, "ny": 36, "na": 80, "gain": 4.0, "round": 0.03})
	NN._coat_edge(k, cg, 0.012, 0.009, 0.0028, rd.darkened(0.12), N - 0.02)
	var hm2 := []
	for p in cg["hem"]:
		hm2.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, hm2, 0.0035, 0.0018, rd.darkened(0.16), false, cg["sk"])
	# yelek yakası: boynu çeviren bant
	var ck := [[N + 0.045, nk.x + 0.04, nk.y + 0.034, nk.z - 0.04], [N + 0.0, nk.x + 0.05, nk.y + 0.04, nk.z - 0.048], [N - 0.05, nk.x + 0.08, nk.y + 0.055, nk.z - 0.07]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	P._cl(k, {"keys": ck, "ny": 6, "na": 48, "rng": func(_v): return Vector2(0.55, TAU - 0.55), "top": func(_a): return N + 0.035, "hem": func(_a): return N - 0.045, "col": func(_a, _y, _v): return rd.darkened(0.06), "inner": lin, "skin": skt, "th": 0.005})
	for sd in ["Left", "Right"]:
		P._armhole(k, P._limb(k, sd, false), 0.075, 0.02, 0.0075, rd.darkened(0.08))
	# göğüste iki sarı yuvarlak: kabartma disk + koyu çerçeve
	var ff: Callable = cg["fold"]
	for sg in [1.0, -1.0]:
		var a0: float = sg * 0.78
		var y0: float = C + 0.02
		var mp: Callable = Q._local(keys, ff, a0, y0)
		var o: Vector3 = Q._spt(keys, ff, a0, y0)[1]
		Q._disc(k, mp, o, 0.034, 0.0035, Callable(), func(u, v): return yl.darkened(0.3) if Vector2(float(u), float(v)).length() > 0.9 else yl, func(p): return _tsk(k, p), 5, 32)
	if sage:
		_toad(k, -1.0, Color(0.42, 0.4, 0.43), Color(0.58, 0.63, 0.3), Color(0.92, 0.92, 0.9), Color(0.86, 0.86, 0.84), false)
		_toad(k, 1.0, Color(0.16, 0.12, 0.22), Color(0.82, 0.84, 0.74), Color(0.48, 0.24, 0.66), Color(0.9, 0.92, 0.95), true)


## Omuzda oturan kurbağa bilge kuklası: kukuletalı pelerin gövde, yüz, sarı gözler, ağız, saç. Sert durur (gövdeyle gider).
static func _toad(k, sg: float, cloak: Color, face: Color, hair: Color, rim: Color, curly: bool) -> void:
	var m = k.m
	var S := 1.32
	var sh: Vector3 = m._bp(("Left" if sg > 0.0 else "Right") + "UpperArm")
	var base := Vector3(sg * maxf(absf(sh.x) * 1.05, 0.168), k.N - 0.035, -0.035)
	var bones := [["UpperChest", 1.0]]
	var hgt := 0.17 * S
	# pelerin gövde: alt geniş, yukarı daralır, tepede kukuleta
	var path := []
	for j in 15:
		path.append(base + Vector3(0, hgt * float(j) / 14.0, 0))
	P._tb(k, path, func(s, a):
		var t: float = float(s)
		var r: float = lerpf(0.05, 0.04, t) * S * (1.0 + 0.12 * cos(float(a)))
		r *= sqrt(maxf(0.0, 1.0 - pow(smoothstep(0.78, 1.0, t), 2.0))) if t > 0.78 else 1.0
		return maxf(0.002, r + 0.004 * sin(float(a) * 7.0) * t), func(s, a, _p):
		var t: float = float(s)
		if t > 0.62 and cos(float(a)) > 0.35:
			return rim
		return cloak.darkened(0.15 if sin(float(a) * 7.0) < -0.3 else 0.0), func(_s, _p): return bones, 18)
	# kukuleta ağzı: öne bakan kenar
	var hc: Vector3 = base + Vector3(0, hgt * 0.72, 0.03 * S)
	var rows := []
	for j in 4:
		var ro := []
		for i in 20:
			var th := TAU * i / 20.0
			var rr: float = (0.034 + 0.004 * float(j)) * S
			ro.append(hc + Vector3(cos(th) * rr, sin(th) * rr * 1.05, 0.004 * float(j) - 0.006))
		rows.append(ro)
	k.grid(rows, true, func(_i, _j, _p): return rim, func(_i, _j, _p): return bones)
	# yüz: basık yumurta, hafif öne
	var fc: Vector3 = base + Vector3(0, hgt * 0.68, 0.032 * S)
	var fp := []
	for j in 9:
		fp.append(fc + Vector3(0, 0, (-0.03 + 0.06 * float(j) / 8.0) * S))
	P._tb(k, fp, func(s, a): return 0.031 * S * sqrt(maxf(0.0, sin(float(s) * PI))) * (1.0 + 0.12 * cos(float(a) * 2.0)), func(_s, _a, _p): return face, func(_s, _p): return bones, 16)
	# gözler: iri sarı yuvarlak, ortası yatay siyah yarık
	for ex in [-1.0, 1.0]:
		var ec: Vector3 = fc + Vector3(ex * 0.015, 0.009, 0.028) * S
		P._fan(k, ec, Vector3(ex * 0.25, 0.1, 1.0).normalized(), Vector3.UP, 0.0095 * S, Callable(), func(u, v):
			return Color(0.08, 0.06, 0.05) if absf(float(v)) < 0.25 and absf(float(u)) < 0.75 else Color(0.96, 0.78, 0.3), bones, 3, 18)
	# ağız: geniş çizgi
	var mo := []
	for i in 9:
		var t := float(i) / 8.0
		mo.append(fc + Vector3(lerpf(-0.02, 0.02, t), -0.012 - 0.004 * sin(t * PI), 0.0305 * sqrt(maxf(0.0, 1.0 - pow(lerpf(-0.65, 0.65, t), 2.0))) + 0.004) * S)
	P._cord(k, mo, 0.0018 * S, face.darkened(0.55), false, func(_p): return bones)
	# saç: Fukasaku tepede kabarık beyaz tutam, Shima kıvırcık mor topak
	if curly:
		for i in 9:
			var a := TAU * i / 9.0
			var c: Vector3 = fc + Vector3(cos(a) * 0.022, 0.03 + 0.008 * sin(a * 2.0), -0.006 + sin(a) * 0.016) * S
			P._boxr(k, c, Vector3(0.011 * S, 0, 0), Vector3(0, 0.011 * S, 0), Vector3(0, 0, 0.011 * S), hair, bones, 0.8)
	else:
		var tp := []
		for j in 7:
			var t := float(j) / 6.0
			tp.append(fc + Vector3(0.004 * sin(t * 5.0), 0.022 + 0.03 * t, -0.006 - 0.012 * t) * S)
		P._tb(k, tp, func(s, a): return 0.016 * S * pow(1.0 - float(s), 0.7) * (1.0 + 0.3 * sin(float(a) * 5.0)) + 0.001, func(_s, a, _p): return hair.darkened(0.12 if sin(float(a) * 5.0) < 0.0 else 0.0), func(_s, _p): return bones, 12)


# ------------------------------------------------------------------ Hebi Koromo (ref Shinobi Striker "Kabuto Robe"): bileğe inen kapalı koyu kırmızı cübbe, önde yakadan etek ucuna beyaz şerit,
## boyna düşmüş kapüşon (sırtta torba, üstünde kırmızı çizgili turuncu yılan gözleri), gri-yeşil astarlı geniş kollar, koyu kırmızı pantolon
static func _hebi(k) -> void:
	var rd := Color(0.3, 0.05, 0.08)
	var ln := Color(0.5, 0.57, 0.5)
	var wh := Color(0.88, 0.87, 0.84)
	var og := Color(0.95, 0.55, 0.12)
	var pr := Color(0.32, 0.07, 0.1)
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
	P._inner(k, b, func(_i, _j, _p): return pr.darkened(0.1), 0.006)
	K._seat(k, b, pr)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		K._pant(k, le, pr, 0.009, 0.01, 1.0, 1.8 if sd == "Left" else 0.7)
	# cübbe: tek parça kapalı (önden ayrılmaz), aşağı doğru A kesim açılır
	var hem: float = lerpf(KN, F, 0.8)
	var keys := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.02, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.045), P._kp(hp, H - 0.04, 0.05),
		[KN + 0.05, hp.x + 0.1, hp.y + 0.085, hp.z - 0.11], [hem, hp.x + 0.15, hp.y + 0.11, hp.z - 0.17]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var fe: float = smoothstep(0.02, 0.2, aw)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		return fe * (pow(t, 0.9) * ((0.03 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.014 * sin(a * 13.0 + 1.9))) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
	var csk := func(p): return _lsk(k, p, hem)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 50, "na": 96, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return rd, "gain": 4.5, "th": 0.006, "inner": rd.darkened(0.12), "skin": csk})
	P._cur_hem = hem
	# önde beyaz şerit: yakadan etek ucuna, kumaşa dikili
	Q._run(k, keys, ff, [Vector2(0.0, N + 0.0), Vector2(0.0, hem + 0.004)], 0.0042, 0.0032, 0.0022, wh, csk, 24)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.012, 0))
	P._bd(k, hm, 0.003, 0.0016, rd.darkened(0.25), true, csk)
	# yan dikişler
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.45, C + 0.0), Vector2(sg * 1.5, H + 0.0), Vector2(sg * 1.55, hem + 0.02)], 0.0024, 0.0014, 0.0014, rd.darkened(0.2), csk, 10)
	# geniş kollar: astar gri-yeşil
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		_wsleeve(k, ar, func(_s, _a): return rd, ln, 0.92, 0.05, 0.03, 1.7 if sd == "Left" else 0.6)
		P._lt(k, ar, func(s, _a): return 0.005 + 0.004 * smoothstep(0.7, 0.95, float(s)), func(_s, _a, ins): return pr.darkened(0.4) if ins else pr.darkened(0.15), 0.4, 0.975, 16, 16)
	# kapüşon: boyunda bol büzgülü halka + sırta düşmüş torba
	var q: float = Q._hq(k)
	var hk := [[N + 0.13 * q, nk.x + 0.08, nk.y + 0.06, nk.z - 0.095], [N + 0.06 * q, nk.x + 0.068, nk.y + 0.058, nk.z - 0.082], [N - 0.0, nk.x + 0.075, nk.y + 0.065, nk.z - 0.075], [N - 0.06, ch.x * 0.8, ch.y * 0.88, ch.z * 0.96]]
	var hf := func(a: float, _y: float, v: float) -> float:
		return 0.055 * sin(float(v) * PI * 2.2 + cos(a) * 1.1) * smoothstep(0.0, 0.25, float(v)) * (1.0 - float(v) * 0.6) + 0.012 * sin(a * 9.0 + 0.7) * float(v)
	var hg: Dictionary = P._cl(k, {"keys": hk, "ny": 18, "na": 70, "top": func(a):
		return N + q * lerpf(0.06, 0.12, smoothstep(0.4, 2.2, absf(float(a)))), "hem": func(a): return N - 0.05 - 0.02 * smoothstep(1.0, 2.6, absf(float(a))), "fold": hf,
		"col": func(_a, _y, _v): return rd.lightened(0.03), "gain": 6.0, "inner": ln.darkened(0.1), "skin": func(p): return Q._nsk(k, p), "th": 0.007})
	P._cord(k, hg["top"], 0.0048, rd.darkened(0.1), true, func(p): return Q._nsk(k, p))
	var sk2 := []
	for e2 in keys:
		sk2.append([e2[0], float(e2[1]) + 0.012, float(e2[2]) + 0.012, float(e2[3]) - 0.014])
	var bagf := func(a: float, _y: float, v: float) -> float:
		var db: float = clampf((PI - absf(a)) / 1.05, 0.0, 1.0)
		return 0.11 * sin(float(v) * PI) * (1.0 - db * db) + 0.01 * sin(a * 7.0 + 0.3) * float(v)
	var bg: Dictionary = P._cl(k, {"keys": sk2, "ny": 16, "na": 40, "rng": func(_v): return Vector2(PI - 1.05, PI + 1.05), "top": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.05, 0.0, 1.0)
		return N + 0.03 - 0.07 * db * db, "hem": func(a):
		var db: float = clampf((PI - absf(float(a))) / 1.05, 0.0, 1.0)
		return C - 0.12 + 0.12 * pow(db, 1.6), "fold": bagf, "col": func(_a, _y, _v): return rd, "gain": 5.0, "inner": ln.darkened(0.1), "skin": func(p): return _tsk(k, p), "th": 0.006})
	P._cord(k, bg["hem"], 0.0042, rd.darkened(0.12), false, func(p): return _tsk(k, p))
	# yılan gözleri: torbanın sırta bakan yüzünde, iki turuncu badem göz + ortadan inen kırmızı çizgi
	var brows: Array = bg["rows"]
	for ex in [-1.0, 1.0]:
		var mp: Callable = _gmap(brows, 20.0 + ex * 6.5, 6.0)
		var c0: Vector3 = mp.call(0.0, 0.0, 0.0)
		var o := Vector3(c0.x, 0.0, c0.z).normalized()
		Q._disc(k, mp, o, 0.03, 0.004, func(th): return 1.0 / sqrt(pow(cos(float(th)) / 1.0, 2.0) + pow(sin(float(th)) / 0.55, 2.0)) * (1.0 - 0.1 * absf(sin(float(th)))),
			func(u, v):
				var r := Vector2(float(u), float(v)).length()
				if absf(float(u)) < 0.14:
					return Color(0.62, 0.06, 0.06)
				return og.darkened(0.35) if r > 0.88 else og, func(p): return _tsk(k, p), 4, 30)
	P._cur_hem = hem


# ------------------------------------------------------------------ Shinku Yoroi (ref Shinobi Striker "Kagemasa Outfit"): siyah dar üst (dik boyun), göğüs altında biten kızıl göğüs zırhı (yüksek yaka, göğüs ve karın plakaları,
## perçinli küçük omuzluklar), plakalı kolluk + kızıl eldiven ağzı, açık kızıl bol pantolon (dizaltında dilimli toplanır), siyah kuşak + düğüm, dizlik ve uzun kaval koruyucu, beyaz baldır sargısı
static func _shinku(k) -> void:
	var bk := Color(0.11, 0.11, 0.13)
	var la := Color(0.62, 0.12, 0.2)
	var ld := la.darkened(0.38)
	var pn := Color(0.74, 0.29, 0.35)
	var wh := Color(0.86, 0.85, 0.8)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = L._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	# siyah dar üst: dik boyunlu, karında hafif kırışık
	var ik := [L._kp(nk, N + 0.075, 0.012, 0.014), L._kp(nk, N + 0.03, 0.018), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.92], L._kp(ch, C - 0.03, 0.01), L._kp(wa, H + 0.12, 0.01), L._kp(hp, H - 0.1, 0.01)]
	SE.body_layer(k, ik, 26, 44, func(_i, _j, p): return bk.lightened(0.04) if sin(float(p.y) * 60.0 + atan2(float(p.x), float(p.z)) * 3.0) > 0.7 and float(p.y) < C - 0.1 else bk, func(a, y): return 0.006 * sin(a * 9.0 + y * 12.0) * smoothstep(C - 0.1, H + 0.1, y))
	L._seat(k, b, pn.darkened(0.1))
	# kollar: siyah dar kol, ön kolda kızıl plakalı kolluk, bilekte eldiven ağzı
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var sg: float = l["sg"]
		var rip := func(s: float, a: float) -> float: return 0.004 * sin(a * 3.0 + s * 19.0) + 0.007 * exp(-pow((s - kn) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		L._lt(k, l, func(s, a): return 0.006 + float(rip.call(float(s), float(a))), func(s, a, ins): return bk.darkened(0.3) if ins else L._fs(bk.lightened(0.04), float(rip.call(float(s), float(a))), 15.0), 0.0, 1.0, 32, 18)
		L._lt(k, l, func(s, _a): return 0.012 + 0.004 * smoothstep(0.64, 0.94, float(s)), func(s, _a, ins): return ld if ins else (ld if float(s) < 0.645 or float(s) > 0.945 else la.darkened(0.06)), 0.635, 0.95, 14, 20)
		for s in [0.67, 0.81]:
			k.wrap_turn(L._lp(l, s), L._ld(l, s), L._lr(l, s) + 0.0175, 0.005, 0.0, ld, L._lskin(l, s))
		L._splint(k, l, 0.655, 0.8, 0.0, 0.62, 0.022, 0.006, la, ld, 5, 0.0)
		L._splint(k, l, 0.795, 0.94, 0.0, 0.62, 0.024, 0.006, la, ld, 5, 0.08)
		L._lt(k, l, func(s, _a): return 0.013 + 0.003 * smoothstep(0.95, 1.0, float(s)), func(s, _a, ins): return ld if ins else (ld if float(s) < 0.955 else la), 0.95, 1.0, 5, 20)
		# omuzluk: deltanın üstünde küçük bombeli plaka, üstünde üç perçin
		var sj: float = l["sj"]
		K._shell(k, l, sj - 0.01, sj + 0.13, sg * PI * 0.5 - 1.25, sg * PI * 0.5 + 1.25, func(s, a): return 0.012 + 0.008 * cos(float(a) - sg * PI * 0.5) * (1.0 - smoothstep(sj + 0.06, sj + 0.13, float(s))), 0.008,
			func(_u, v, e): return ld if e or float(v) > 0.92 else la, 10, 18)
		for i in 3:
			var e2: Array = K._lsurf(l, sj + 0.015 + 0.035 * i, sg * PI * 0.5, 0.012 + 0.008 + 0.008)
			P._stud(k, e2[0], e2[1], 0.0075, la.lightened(0.06), P._lskin(l, sj + 0.015 + 0.035 * i))
	# pantolon: iki ayrı bol paça, dizaltında toplanır; dilimli paça ağzı dizliğin üstüne düşer
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var ph: float = kn + 0.12
		var prof := func(s: float) -> float: return 0.024 + 0.05 * smoothstep(0.05, kn - 0.05, s) * (1.0 - smoothstep(kn - 0.02, ph, s)) + 0.012 * (1.0 - smoothstep(ph - 0.06, ph, s))
		L._wide(k, b, l, {"col": pn, "prof": prof, "pl": 5.0, "amp": 0.03, "s1": ph + 0.005, "top": 0.06, "seg": 40, "n": 30, "cmax": 0.82, "pad": 0.03})
		var rows := []
		var sks := []
		for j in 5:
			var v := float(j) / 4.0
			var ro := []
			var sr := []
			for i in 40:
				var a := TAU * i / 40.0 - PI
				var lobe: float = pow(absf(sin(a * 2.5 + 0.3)), 0.6)
				var s: float = ph - 0.045 + v * (0.04 + 0.04 * lobe)
				var d: Vector3 = L._ld(l, s)
				var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
				var ri := (-d).cross(fw).normalized()
				var r: float = L._lr(l, s) + float(prof.call(minf(s, ph))) + 0.004 - 0.006 * v * v
				ro.append(L._lp(l, s) + (ri * sin(a) + fw * cos(a)) * r)
				sr.append(L._lskin(l, s))
			rows.append(ro)
			sks.append(sr)
		k.grid(rows, true, func(_i, j, _p): return pn.darkened(0.22) if j == 4 else pn.darkened(0.04 * float(j)), func(i, j, _p): return sks[j][i])
		# beyaz baldır sargısı (kavalın arkasından görünür), dizlik ve uzun kaval koruyucu
		L._lt(k, l, func(_s, _a): return 0.005, func(_s, _a, _i): return wh.darkened(0.12), kn - 0.02, 0.99, 14, 16)
		L._wraps(k, l, kn + 0.02, 0.975, 11, 0.007, 0.0115, wh, 0.007)
		K._shell(k, l, kn - 0.02, kn + 0.13, -1.35, 1.35, func(s, a): return 0.02 + 0.016 * cos(float(a)) * sin(clampf((float(s) - kn + 0.02) / 0.15, 0.0, 1.0) * PI), 0.008,
			func(_u, _v, e): return ld if e else la, 10, 18)
		K._shell(k, l, kn + 0.12, 0.965, -1.4, 1.4, func(s, a): return 0.017 + 0.005 * cos(float(a)) - 0.004 * smoothstep(0.85, 0.965, float(s)), 0.008,
			func(_u, v, e): return ld if e or float(v) > 0.96 else la, 16, 20)
		for a in [-0.62, 0.62]:
			var pts := []
			var ou := []
			for j in 12:
				var s: float = lerpf(kn + 0.14, 0.95, float(j) / 11.0)
				var e3: Array = K._lsurf(l, s, float(a), 0.017 + 0.005 * cos(float(a)) - 0.004 * smoothstep(0.85, 0.965, s) + 0.0085)
				pts.append(e3[0])
				ou.append(e3[1])
			k.strip(pts, ou, 0.0018, 0.001, ld.darkened(0.3), false, func(_p): return [[(l["bo"] as Array)[1], 1.0]])
	# göğüs zırhı: ön ve arka levha (göğüs altında biter), göğüs ve karın plakaları
	var keys: Array = L._tk(k, b, 0.022, H + 0.01, 0.0, 0.0)
	var ty := func(a: float) -> float: return N - 0.06 - 0.05 * smoothstep(0.35, 1.25, absf(sin(a)))
	var yb: float = C - 0.175
	L._torso_plate(k, keys, 0.0, 1.38, N - 0.06, yb, 0.004, 0.01, la, ld, 30, 9, ty)
	L._torso_plate(k, keys, PI, 1.32, N - 0.06, yb, 0.004, 0.01, la, ld, 30, 9, func(a): return ty.call(a - PI))
	for sg in [1.0, -1.0]:
		L._torso_plate(k, keys, sg * 0.46, 0.4, N - 0.085, C - 0.075, 0.017, 0.007, la.lightened(0.05), ld, 14, 6)
		L._torso_plate(k, keys, sg * 0.44, 0.36, C - 0.095, yb + 0.012, 0.017, 0.007, la.lightened(0.02), ld, 14, 5)
		L._torso_plate(k, keys, sg * (PI - 0.5), 0.42, N - 0.09, C - 0.08, 0.017, 0.007, la.lightened(0.03), ld, 14, 5)
	L._rail(k, keys, [Vector2(0.0, N + 0.0), Vector2(0.0, yb + 0.004)], 0.0024, 0.017, 0.0015, ld.darkened(0.3), 8)
	# zırh yakası: boynu saran dik kızıl bant, önde ince yarık
	var ck := [[N + 0.085, nk.x + 0.026, nk.y + 0.024, nk.z - 0.028], [N + 0.02, nk.x + 0.036, nk.y + 0.032, nk.z - 0.036], [N - 0.05, nk.x + 0.07, nk.y + 0.05, nk.z - 0.06]]
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var cl: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 48, "rng": func(_v): return Vector2(0.06, TAU - 0.06), "top": func(_a): return N + 0.08, "hem": func(_a): return N - 0.05, "col": func(_a, _y, _v): return la, "inner": ld, "skin": skt, "th": 0.006})
	P._cord(k, cl["top"], 0.0035, ld, false, skt)
	# bel: geniş pantolon bandı + siyah kuşak, önde düğüm ve iki sarkan uç
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var kb := [P._kp(bl, H + 0.13, 0.034), P._kp(bl, H - 0.01, 0.04)]
	P._sash(k, kb, H + 0.07, 0.034, 0.008, pn.lightened(0.05), 0.08)
	P._sash(k, kb, H + 0.068, 0.013, 0.02, bk.lightened(0.06), 0.18)
	var kz: Array = SE.El.key_at(kb, H + 0.068)
	var kc := Vector3(0.0, H + 0.068, float(kz[2]) + 0.034)
	L._knot(k, kc, 0.026, 0.017, bk.lightened(0.06))
	var hm: float = H - 0.17
	for e in [[-0.006, -0.03, 0.0125], [0.006, 0.03, 0.0125]]:
		var pts := []
		var ou := []
		for i in 12:
			var v := float(i) / 11.0
			var y: float = kc.y - 0.012 - v * (kc.y - 0.012 - hm)
			var x: float = float(e[0]) + float(e[1]) * v
			var z: float = maxf(float(SE.El.key_at(keys, maxf(y, H - 0.05))[2]) + 0.03 - 0.06 * v * v, hp.y + 0.03) + 0.012 * (1.0 - v)
			pts.append(Vector3(x, y, z))
			ou.append(Vector3(0, 0, 1))
		k.strip(pts, ou, float(e[2]), 0.004, bk.lightened(0.04), false, func(p): return k.cloth_skin(p, hm, 0.5))


# ------------------------------------------------------------------ Megami Kimono (ref Shinobi Striker "Kaguya Outfit"): yere inen çan etekli beyaz kimono; boyundan sağ koltuk altına inen mor + sarı yaka bandı,
## önde altı siyah tomoe düğme, çan kollar (ağızda mor + sarı bant, üstünde siyah tomoe dizisi), etekte mor + sarı bant ve ince sarı çizgi
static func _megami(k) -> void:
	var wh := Color(0.95, 0.94, 0.92)
	var pu := Color(0.34, 0.12, 0.52)
	var ye := Color(0.93, 0.78, 0.26)
	var ink := Color(0.06, 0.06, 0.07)
	var lin := Color(0.62, 0.52, 0.72)
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
	P._inner(k, b, func(_i, _j, _p): return wh.darkened(0.08), 0.006)
	K._seat(k, b, wh.darkened(0.1))
	for sd in ["Left", "Right"]:
		K._pant(k, P._limb(k, sd, true), wh.darkened(0.06), 0.008, 0.008, 1.0, 1.2 if sd == "Left" else 2.2)
	var hem: float = F + 0.03
	var keys := [P._kp(nk, N + 0.012, 0.028), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.028), P._kp(wa, H + 0.12, 0.04), P._kp(hp, H - 0.04, 0.05),
		[KN + 0.05, hp.x + 0.11, hp.y + 0.09, hp.z - 0.12], [hem, hp.x + 0.2, hp.y + 0.15, hp.z - 0.21]]
	var ff := func(a: float, y: float) -> float:
		var aw: float = absf(a)
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		return pow(t, 0.9) * ((0.028 + 0.01 * bkf) * sin(a * 7.0 + 0.6) + 0.013 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.005 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
	var csk := func(p): return _lsk(k, p, hem, 0.028, 0.3)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": 54, "na": 96, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return wh, "gain": 4.0, "th": 0.006, "inner": wh.darkened(0.3), "skin": csk})
	P._cur_hem = hem
	# etek bantları: kumaşın üstüne binen ayrı katlar
	for e in [[hem + 0.062, hem - 0.002, pu, 0.004], [hem + 0.11, hem + 0.066, ye, 0.0035], [hem + 0.13, hem + 0.12, ye, 0.003]]:
		P._cl(k, {"keys": keys, "ny": 3, "na": 96, "top": func(_a): return float(e[0]), "hem": func(_a): return float(e[1]), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
			"col": func(_a, _y, _v): return e[2], "gain": 3.0, "lift": float(e[3]), "th": 0.003, "inner": (e[2] as Color).darkened(0.3), "skin": csk})
	# boyun yakası: arkada dik mor bant
	var q: float = Q._hq(k)
	var ck := [[N + 0.06 * q, nk.x + 0.032, nk.y + 0.028, nk.z - 0.036], [N + 0.0, nk.x + 0.042, nk.y + 0.034, nk.z - 0.044], [N - 0.05, nk.x + 0.07, nk.y + 0.05, nk.z - 0.06]]
	var skt := func(p): return Q._nsk(k, p)
	P._cl(k, {"keys": ck, "ny": 6, "na": 48, "rng": func(_v): return Vector2(0.62, TAU - 0.62), "top": func(a): return N + q * lerpf(0.02, 0.055, smoothstep(0.6, 2.2, absf(float(a)))), "hem": func(_a): return N - 0.045,
		"col": func(_a, _y, _v): return pu, "inner": lin, "skin": skt, "th": 0.006})
	# çapraz yaka bandı: sol omuzdan sağ koltuk altına; dışta mor, içte sarı
	var path := [Vector2(0.62, N + 0.004), Vector2(0.36, C + 0.03), Vector2(0.02, C - 0.06), Vector2(-0.45, C - 0.14), Vector2(-0.95, C - 0.2), Vector2(-1.3, C - 0.22)]
	P._band(k, keys, path, func(_t): return 0.032, 0.006, pu, 6, 6, 0.1, 0.2)
	var path2 := []
	for v in path:
		path2.append(Vector2(v.x, v.y - 0.034))
	path2[0] = Vector2(0.58, N - 0.026)
	P._band(k, keys, path2, func(_t): return 0.026, 0.005, ye, 6, 6, 0.08, 0.18)
	var path0 := [Vector2(-0.62, N + 0.004), Vector2(-0.4, C + 0.06), Vector2(-0.2, C + 0.0)]
	P._band(k, keys, path0, func(_t): return 0.028, 0.004, pu.darkened(0.06), 5, 6, 0.1, 0.2)
	# altı siyah tomoe düğme
	var tsk := func(p): return csk.call(p)
	for i in 6:
		var y: float = lerpf(C - 0.11, H - 0.1, float(i) / 5.0)
		var a: float = 0.13
		var mp: Callable = Q._local(keys, ff, a, y)
		Q._tomoe(k, mp, Q._spt(keys, ff, a, y)[1], 0.0115, -0.6, 0.004, ink, tsk)
	# çan kollar: bilekte genişler; ağızda mor + sarı bant, üstünde siyah tomoe dizisi; içi koyu mor
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var s1 := 0.95
		var sf: Callable = _wsleeve(k, ar, func(_s, _a): return wh, lin, s1, 0.055, 0.026, 1.4 if sd == "Left" else 2.7)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.003, func(_s, _a, ins): return lin if ins else pu, s1 - 0.075, s1 + 0.002, 5, 26)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return lin if ins else ye, s1 - 0.125, s1 - 0.074, 4, 26)
		P._lt(k, ar, func(s, _a): return 0.005 + 0.004 * smoothstep(0.7, 0.95, float(s)), func(_s, _a, ins): return wh.darkened(0.35) if ins else wh.darkened(0.15), 0.4, 0.975, 16, 16)
		var L0: float = ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length() + ((ar["p2"] as Vector3) - (ar["p1"] as Vector3)).length()
		var s0: float = s1 - 0.155
		for i in 7:
			var a0: float = lerpf(-2.2, 2.2, float(i) / 6.0)
			var R: float = P._lr(ar, s0) + float(sf.call(s0, a0))
			var mp := func(u: float, v: float, l: float) -> Vector3:
				var s2: float = s0 - v / L0
				var a2: float = a0 + u / maxf(0.03, R)
				return K._lsurf(ar, s2, a2, float(sf.call(s2, a2)) + l)[0]
			Q._tomoe(k, mp, K._lsurf(ar, s0, a0, R)[1], 0.0085, -0.6, 0.003, ink, func(_p): return P._lskin(ar, s0))
	P._cur_hem = hem


# ------------------------------------------------------------------ Megami Koromo (ref Shinobi Striker "Kaguya Outfit 2"): yere inen bembeyaz cübbe; çok yüksek dik yaka, bele kadar kapalı ön, belden aşağı ters V açılır;
## önde yakadan etek ucuna uzanan ince siyah çizgiler ve siyah kenar, geniş uzun kollar; altında sarı iç giysi, siyah pantolon
static func _megami2(k) -> void:
	var wh := Color(0.96, 0.96, 0.95)
	var ln := Color(0.84, 0.84, 0.87)
	var ink := Color(0.07, 0.07, 0.08)
	var ye := Color(0.9, 0.76, 0.3)
	var bk := Color(0.1, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, _j, _p): return ye, 0.006)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		K._pant(k, P._limb(k, sd, true), bk, 0.009, 0.01, 1.0, 1.5 if sd == "Left" else 2.9)
	var hem: float = F + 0.03
	var keys: Array = NN._coat_keys(k, b, 0.034, hem, 0.17, 0.12, 0.2)
	var ef := func(y: float) -> float: return 0.014 + 0.5 * pow(smoothstep(H + 0.04, hem, y), 0.7)
	var cg: Dictionary = _coat2(k, {"keys": keys, "hem": hem, "e": ef, "fold": NN._coat_fold(k, hem, 0.045), "col": wh, "lin": ln, "ny": 50, "na": 96, "gain": 3.4, "round": 0.04}, func(p): return _lsk(k, p, hem, 0.014))
	NN._coat_edge(k, cg, 0.008, 0.0042, 0.0022, ink, N - 0.02)
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, hm, 0.003, 0.0016, wh.darkened(0.16), false, cg["sk"])
	# ön çizgiler: her kanatta üç ince siyah kabartma, yakadan aşağı açılarak iner
	var pt: Callable = cg["pt"]
	for sg in [1.0, -1.0]:
		for e in [[0.06, 0.1], [0.2, 0.42], [0.36, 0.8]]:
			var pts := []
			var ou := []
			for j in 40:
				var t := float(j) / 39.0
				var y: float = lerpf(N - 0.03, hem + 0.03, t)
				var a: float = float(ef.call(y)) + lerpf(float(e[0]), float(e[1]), pow(t, 0.8))
				var p: Vector3 = pt.call(a * sg, y)
				var o: Vector3 = P._out(p, 0.02)
				pts.append(p + o * 0.0025)
				ou.append(o)
			k.strip(pts, ou, 0.0026, 0.0014, ink, false, cg["sk"])
	# çok yüksek dik yaka: önü dar yarık, kenarı siyah
	var q: float = Q._hq(k)
	var ck := [[N + 0.12 * q, nk.x + 0.07, nk.y + 0.06, nk.z - 0.07], [N + 0.055 * q, nk.x + 0.048, nk.y + 0.04, nk.z - 0.05], [N - 0.0, nk.x + 0.046, nk.y + 0.04, nk.z - 0.048], [N - 0.05, nk.x + 0.07, nk.y + 0.06, nk.z - 0.06]]
	var crg := func(v) -> Vector2:
		var e: float = lerpf(0.3, 0.08, float(v))
		return Vector2(e, TAU - e)
	var cl: Dictionary = P._cl(k, {"keys": ck, "ny": 14, "na": 52, "rng": crg, "top": func(a): return N + q * lerpf(0.095, 0.12, smoothstep(0.4, 2.2, absf(float(a)))), "hem": func(_a): return N - 0.045,
		"fold": func(a, _y, v): return 0.006 * (1.0 - float(v)) * sin(float(a) * 4.0), "col": func(_a, _y, _v): return wh, "inner": ln, "skin": func(p): return Q._nsk(k, p), "th": 0.007})
	P._cord(k, cl["top"], 0.0032, ink, false, func(p): return Q._nsk(k, p))
	for e3 in [cl["ea"], cl["eb"]]:
		P._cord(k, e3, 0.003, ink, false, func(p): return Q._nsk(k, p))
	for sg in [1.0, -1.0]:
		var pts := []
		for j in 12:
			var t := float(j) / 11.0
			pts.append(P._on(ck, sg * lerpf(0.42, 0.62, t), lerpf(N + 0.1 * q, N - 0.03, t), 0.012))
		P._cord(k, pts, 0.0026, ink, false, func(p): return Q._nsk(k, p))
	# geniş uzun kollar: elin üstüne iner, ağzında siyah kenar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var s1 := 0.97
		var sf: Callable = _wsleeve(k, ar, func(_s, _a): return wh, ln, s1, 0.068, 0.032, 2.3 if sd == "Left" else 0.9)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0024, func(_s, _a, ins): return ln if ins else ink, s1 - 0.018, s1 + 0.002, 3, 26)
		P._lt(k, ar, func(s, _a): return 0.005 + 0.004 * smoothstep(0.7, 0.95, float(s)), func(_s, _a, ins): return ye.darkened(0.4) if ins else ye.darkened(0.1), 0.4, 0.975, 16, 16)
