extends RefCounted
## Elle modellenmiş setler, parti ak: ss_pijama, ss_bilge_palto, ss_turuncu_genc, ss_sakaci, ss_kader_genc, ss_ninja_yolu_tisort. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{naruto_outfit_pajama_vers, naruto_outfit_sage_mode_ver, naruto_outfit_young_vers, naruto_outfit_prankster_ver, neji_outfit_young_vers, ninja_way_t_shirts (Naruto_Shirt)}.
## Kumaş / uzuv yardımcıları parti e (P), i (I), k (K), q (Q), j (J), r (R), aa (AA), af (AF), n (NN), ah (AH) dosyalarından; burada yüzey üstü girdap, sekiz trigram mührü, Konoha yaprağı ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AF = preload("res://scripts/actors/set_el_af.gd")
const NN = preload("res://scripts/actors/set_el_n.gd")
const AH = preload("res://scripts/actors/set_el_ah.gd")

const DONE := ["ss_pijama", "ss_bilge_palto", "ss_turuncu_genc", "ss_sakaci", "ss_kader_genc", "ss_ninja_yolu_tisort"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_pijama": _pijama(k)
		"ss_bilge_palto": _bilge(k)
		"ss_turuncu_genc": _kodomo(k)
		"ss_sakaci": _itazura(k)
		"ss_kader_genc": _unmei(k)
		"ss_ninja_yolu_tisort": _nindo(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Yerel eşlemede girdap: dış halka + içe kıvrılan sarmal (kabartma)
static func _swirl(k, mp: Callable, r: float, col: Color, skinf: Callable, lift := 0.0022) -> void:
	var ring := []
	for i in 40:
		var t := TAU * i / 40.0
		ring.append(Vector2(cos(t), sin(t)) * r)
	R._lstrip(k, mp, ring, r * 0.1, lift, 0.0016, col, skinf, true)
	var sp := []
	for i in 44:
		var v := float(i) / 43.0
		var t := v * TAU * 1.8 + 0.4
		sp.append(Vector2(cos(t), sin(t)) * r * lerpf(0.74, 0.06, v))
	R._lstrip(k, mp, sp, r * 0.095, lift, 0.0016, col, skinf)


## Sekiz Trigram mührü (Hakke Fūin): ortada girdap, çevresinde sekiz yazı kümesi (her biri kendi çizgi düzeniyle, kabartma)
static func _hakke(k, mp: Callable, r: float, col: Color, skinf: Callable) -> void:
	_swirl(k, mp, r * 0.42, col, skinf, 0.0024)
	var g := r * 0.13
	var sets := [
		[[-1.0, 0.0, 1.0, 0.0], [-0.3, -0.9, -0.3, 0.9], [0.5, -0.7, 0.9, 0.6], [0.2, 0.9, 1.0, 1.1]],
		[[-1.0, -0.4, 0.9, -0.2], [0.0, -1.0, 0.1, 1.0], [-0.8, 0.6, 0.6, 0.8], [0.6, 0.1, 1.1, -0.9]],
		[[-0.9, 0.3, 1.0, 0.4], [-0.5, -1.0, -0.6, 0.9], [0.3, -0.9, 0.4, 0.3], [0.4, 0.3, 1.0, 1.0]]]
	for i in 8:
		var th: float = TAU * float(i) / 8.0 + PI / 8.0
		var c := Vector2(cos(th), sin(th)) * r * 0.82
		var ra := Vector2(cos(th), sin(th))
		var ta := Vector2(-ra.y, ra.x)
		for st in sets[i % 3]:
			var p0: Vector2 = c + (ra * float(st[0]) + ta * float(st[1])) * g * (1.0 + 0.1 * float(i % 2))
			var p1: Vector2 = c + (ra * float(st[2]) + ta * float(st[3])) * g * (1.0 + 0.1 * float(i % 2))
			R._lstrip(k, mp, [p0, p0.lerp(p1, 0.5), p1], g * 0.2, 0.0024, 0.0014, col, skinf)
		# dış uçta küçük kıvrık alev dili
		var e0: Vector2 = c + ra * g * 1.5
		R._lstrip(k, mp, [e0 - ta * g * 0.6, e0 + ra * g * 0.5, e0 + ta * g * 0.5 + ra * g * 0.9], g * 0.19, 0.0024, 0.0014, col, skinf)


## Konoha yaprağı: girdap + yaprak ucu (kabartma); mp yerel eşleme, v yukarı
static func _leaf_mark(k, mp: Callable, r: float, col: Color, skinf: Callable, lift := 0.0022) -> void:
	var sp := []
	for i in 36:
		var v := float(i) / 35.0
		var t := v * TAU * 1.35 + 0.9
		sp.append(Vector2(cos(t), sin(t)) * r * lerpf(0.85, 0.12, v))
	R._lstrip(k, mp, sp, r * 0.13, lift, 0.0015, col, skinf)
	var arc := []
	for i in 22:
		var t: float = lerpf(0.9, 0.9 + TAU * 0.78, float(i) / 21.0)
		arc.append(Vector2(cos(t), sin(t)) * r)
	R._lstrip(k, mp, arc, r * 0.13, lift, 0.0015, col, skinf)
	var a0: Vector2 = arc[0]
	var a1: Vector2 = arc[arc.size() - 1]
	var tip := Vector2(r * 1.75, -r * 1.55)
	R._lstrip(k, mp, [a0, a0.lerp(tip, 0.5), tip, tip.lerp(a1, 0.5), a1], r * 0.13, lift, 0.0015, col, skinf)


## Göğüs boşluğu teni (V yaka / açık yaka altında)
static func _v_skin(k, b: Dictionary, y1: float) -> void:
	var skc: Color = Q._skc(k)
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	SE.body_layer(k, [[k.N + 0.03, nk.x, nk.y, nk.z], [k.N - 0.05, ch.x * 0.76, ch.y * 0.82, ch.z * 0.86], [y1, ch.x * 0.92, ch.y * 0.97, ch.z * 0.94]], 10, 32, func(_i, _j, _p): return skc)


## Düz paça: kalçadan bileğe; s1 sonrası katlanmış manşet rulosu (paça ağzı bileğe kapanır, koşuda koyu halka görünmez). Döner: paça yarıçap işlevi
static func _leg_roll(k, le: Dictionary, col: Color, base: float, bag: float, s1: float, roll: float, rolls: int, sv: float, gain := 12.0) -> Callable:
	var sg: float = le["sg"]
	var kn: float = le["kn"]
	var fo := func(s: float, a: float) -> float:
		return 0.006 * P._lf(s, a, sv) * smoothstep(0.03, 0.15, s) + 0.007 * exp(-pow((s - kn) / 0.06, 2.0)) * sin(a * 3.0 + s * 30.0 + sv) + 0.006 * exp(-pow((s - s1 + 0.05) / 0.05, 2.0)) * sin(a * 5.0 + sv)
	var pa := func(s: float, a: float) -> float:
		var inn: float = clampf(-sin(a) * sg, 0.0, 1.0)
		var v: float = base + bag * smoothstep(0.0, 0.35, s) * (1.0 - 0.3 * smoothstep(0.55, s1, s))
		return v * (1.0 - 0.4 * inn * smoothstep(0.0, 0.3, s) * (1.0 - smoothstep(0.35, 0.6, s))) + float(fo.call(s, a))
	P._lt(k, le, pa, func(s, a, ins): return col.darkened(0.45) if ins else P._fs(col, float(fo.call(float(s), float(a))), gain), 0.0, s1 + 0.01, 40, 24)
	var e1: float = 0.985
	var rf := func(s: float, a: float) -> float:
		var u: float = clampf((s - s1) / (e1 - s1), 0.0, 1.0)
		var w: float = float(pa.call(s1, a)) * lerpf(1.0, 0.55, u) + roll
		return w + 0.004 * absf(sin(u * PI * float(rolls))) + 0.0015 * sin(a * 6.0 + sv)
	P._lt(k, le, rf, func(s, a, ins):
		if ins:
			return col.darkened(0.45)
		var u: float = clampf((float(s) - s1) / (e1 - s1), 0.0, 1.0)
		return col.darkened(0.2 * (1.0 - absf(sin(u * PI * float(rolls))))).lightened(0.03), s1 - 0.005, e1, 6 * rolls, 24)
	return pa


## Baldır boyu önü açık haori ağırlığı (AH._hsk ölçüsü): ön kanat ucu baldıra daha az bağlı (geri kalkan baldır köşeyi kaldırmaz), uçta ağırlık biraz düşer
static func _psk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.97 * pow(minf(1.0, (H - p.y) / 0.11), 0.5)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.96, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, lerpf(0.86, 0.94, bk), smoothstep(0.7, 1.0, t))
	var hw: float = lerpf(0.035, 0.1, bk)
	var s: float = smoothstep(-hw, hw, x)
	var kb: float = smoothstep(k.K + 0.1, k.K - 0.1, p.y) * lerpf(0.18, 0.7, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Gövde yüzeyinde (açı, y) noktası etrafında yerel eşleme + dış yön
static func _mp_at(keys: Array, ff: Callable, a: float, y: float) -> Array:
	return [Q._local(keys, ff, a, y), Q._spt(keys, ff, a, y)[1]]


# ------------------------------------------------------------------ Nemaki (ref "Naruto Outfit Pajama Vers."): uyluğa inen bol açık gri-lila pijama gömleği (devrik yaka + açık V, önde düğmeli pat,
## alt yanlarda iki cep kapağı, kıvrılmış bilek manşeti, sırtta kızıl girdap), bileğe inen bol pijama altı + katlanmış paça
static func _pijama(k) -> void:
	var pj := Color(0.78, 0.78, 0.85)
	var lin := Color(0.6, 0.58, 0.72)
	var bt := Color(0.94, 0.94, 0.96)
	var rd := Color(0.74, 0.22, 0.17)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	_v_skin(k, b, C - 0.05)
	K._seat(k, b, pj.darkened(0.05))
	# pijama altı: bol, bileğe iner, paçada katlanmış manşet
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_leg_roll(k, le, pj, 0.02, 0.018, 0.9, 0.006, 2, 1.3 if sd == "Left" else 3.1, 10.0)
	# gömlek: uyluğa iner, düz kesim, açık V yaka
	var hem: float = H - 0.15
	var fam := func(p): return AA._fam(k, p, hem)
	var tk := [P._kp(nk, N + 0.012, 0.028), [N - 0.055, ch.x * 1.05, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.05), P._kp(k.M(H + 0.06, 0.3), H + 0.06, 0.048), P._kp(hp, H - 0.04, 0.052), [hem, hp.x + 0.064, hp.y + 0.06, hp.z - 0.058]]
	var tf := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		var fr: float = smoothstep(0.08, 0.3, absf(a))   # pat düz kalır
		return fr * (t * (0.014 * sin(a * 6.0 + 0.5) + 0.007 * sin(a * 11.0 + 1.7)) + (1.0 - t) * 0.006 * sin(a * 5.0 + y * 12.0) * smoothstep(N - 0.02, C - 0.04, y))
	var tff := func(a, y): return tf.call(float(a), float(y))
	var vt := func(a: float) -> float: return lerpf(C - 0.025, N + 0.012, smoothstep(0.03, 0.6, absf(a)))
	P._cl(k, {"keys": tk, "ny": 46, "na": 100, "top": func(a): return vt.call(float(a)), "hem": func(a): return hem + 0.006 * cos(float(a) * 2.0), "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return pj, "gain": 6.0, "th": 0.006, "inner": lin, "skin": fam})
	# önde düğmeli pat + düğmeler
	Q._run(k, tk, tff, [Vector2(-0.03, C - 0.03), Vector2(-0.03, hem + 0.004)], 0.015, 0.0022, 0.0018, pj.lightened(0.03), fam, 18)
	Q._run(k, tk, tff, [Vector2(-0.075, C - 0.03), Vector2(-0.075, hem + 0.004)], 0.0016, 0.0042, 0.0012, lin, fam, 18)
	for i in 4:
		var y: float = lerpf(C - 0.06, H - 0.08, float(i) / 3.0)
		var e: Array = Q._spt(tk, tff, -0.03, y, 0.004)
		P._stud(k, e[0], e[1], 0.0058, bt, fam.call(e[0]))
	# yan dikiş + alt cep kapakları
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tff, [Vector2(sg * PI * 0.5, C - 0.05), Vector2(sg * PI * 0.5, hem + 0.01)], 0.0018, 0.0015, 0.0012, lin, fam, 10)
		AA._flap(k, tk, tff, sg * 0.66, H + 0.035, 0.09, 0.034, -sg * 0.05, pj.darkened(0.03), fam, 0.0045)
	# devrik yaka: arkada boynu saran, önde V boyunca göğse yatan kanatlar
	var q: float = Q._hq(k)
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var ck := [[N + 0.06 * q, nk.x + 0.03, nk.y + 0.03, nk.z - 0.034], [N + 0.0, nk.x + 0.05, nk.y + 0.044, nk.z - 0.054], [N - 0.045, nk.x + 0.082, nk.y + 0.066, nk.z - 0.08]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 56, "rng": func(_v): return Vector2(0.62, TAU - 0.62), "top": func(a): return N + q * lerpf(0.035, 0.055, smoothstep(0.7, 2.4, absf(float(a)))), "hem": func(_a): return N - 0.04,
		"fold": func(a, _y, v): return 0.01 * float(v) * sin(float(a) * 4.0 + 0.6), "col": func(_a, _y, _v): return pj.lightened(0.04), "gain": 5.0, "th": 0.005, "inner": lin, "skin": skt})
	P._cord(k, cg["hem"], 0.0032, pj.darkened(0.06), false, skt)
	for sg in [1.0, -1.0]:
		var path: Array = [Vector2(sg * 0.05, C - 0.022), Vector2(sg * 0.3, N - 0.07), Vector2(sg * 0.6, N + 0.004)]
		if sg < 0.0:
			path.reverse()
		P._band(k, tk, path, func(t): return lerpf(0.008, 0.036, float(t)) if sg > 0.0 else lerpf(0.036, 0.008, float(t)), 0.006, pj.lightened(0.05), 6, 6, 0.08, 0.2)
	# kollar: bileğe iner, ağzı kıvrılmış manşet
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.4
		var s1 := 0.95
		var sf := func(s: float, a: float) -> float:
			return 0.017 + 0.011 * smoothstep(0.05, 0.45, s) - 0.013 * smoothstep(0.68, 0.86, s) + 0.004 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins): return lin if ins else P._fs(pj, float(sf.call(float(s), float(a))) - 0.026, 12.0), 0.0, 0.87, 34, 22, 0.02)
		var cf := func(s: float, a: float) -> float: return float(sf.call(0.85, a)) + 0.004 + 0.0035 * sin(clampf((s - 0.84) / (s1 - 0.84), 0.0, 1.0) * PI) + 0.0012 * sin(a * 5.0 + sv)
		P._lt(k, ar, cf, func(_s, _a, ins): return lin if ins else pj.lightened(0.02), 0.84, s1, 8, 22, 0.02)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.005, lin, s1 - 0.06, s1 - 0.004, 4, 22)
		Q._ring_on(k, ar, 0.842, cf, 0.0035, pj.darkened(0.12), 0.0008)
	# sırtta kızıl girdap
	_swirl(k, AA._back_mp(tk, 0.0, C - 0.06), 0.058, rd, tsk, 0.005)


# ------------------------------------------------------------------ Sennin Gaitō (ref "Naruto Outfit Sage Mode Ver."): fermuarlı siyah-turuncu ceket (siyah dik yaka, boyunduruk ve uzun kollar, turuncu karın),
## üstünde baldıra inen önü açık kırmızı haori (dirsekte biten geniş kısa kol, eteğinde siyah alev dilleri, koyu kırmızı ön kenar), sol omuzdan sağ kalçaya kahve kayış,
## sırtta bele yatay asılı kızıl dev parşömen (siyah uç bantları, açık göbekli kapaklar), turuncu pantolon, sağ uylukta beyaz sargı + siyah kılıf, baldırda siyah sargı
static func _bilge(k) -> void:
	var og := Color(0.94, 0.54, 0.14)
	var bk := Color(0.11, 0.11, 0.14)
	var rd := Color(0.7, 0.13, 0.12)
	var lin := Color(0.36, 0.07, 0.07)
	var br := Color(0.62, 0.47, 0.32)
	var sc := Color(0.6, 0.1, 0.13)
	var zp := Color(0.74, 0.74, 0.76)
	var wh := Color(0.9, 0.89, 0.86)
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
	K._seat(k, b, og.darkened(0.05))
	# pantolon + baldır sargısı; sağ uylukta sargı + kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.7 if sd == "Left" else 0.4
		var pa: Callable = K._pant(k, le, og, 0.012, 0.016, 0.9, sv)
		var wf := func(s: float, a: float) -> float: return float(pa.call(minf(float(s), 0.9), a)) * lerpf(1.0, 0.4, smoothstep(0.86, 0.95, float(s))) + 0.002
		P._lt(k, le, wf, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.85, 0.99, 8, 20)
		P._wraps(k, le, 0.86, 0.975, 6, float(pa.call(0.9, 0.0)) * 0.5 + 0.007, 0.012, bk.lightened(0.06), 0.007)
		if sd == "Right":
			I._holster(k, le, pa, bk, bk.lightened(0.04), true)
	# ceket: kalçaya iner, fermuarlı; siyah boyunduruk, turuncu karın
	var jh: float = H - 0.02
	var keys := [P._kp(nk, N + 0.008, 0.026), [N - 0.055, ch.x * 1.02, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.03), P._kp(k.M(jh, 0.3), jh, 0.03)]
	var yy: float = C - 0.05
	var jf := func(a: float, y: float, _v: float) -> float:
		return smoothstep(0.15, 0.5, absf(a)) * (0.007 * sin(a * 6.0 + y * 15.0) + 0.004 * sin(a * 11.0 - y * 9.0) * smoothstep(C, jh, y))
	var jff := func(a, y): return jf.call(float(a), float(y), 0.0)
	var ycut := func(a: float) -> float: return yy - 0.02 * cos(a)
	P._cl(k, {"keys": keys, "ny": 34, "na": 88, "top": func(_a): return N + 0.008, "hem": func(_a): return jh, "fold": jf, "col": func(a, y, _v): return bk if float(y) > float(ycut.call(float(a))) else og,
		"gain": 6.0, "th": 0.005, "inner": bk.darkened(0.2), "skin": tsk})
	var yr := []
	for i in 49:
		var a: float = -PI + TAU * i / 48.0
		yr.append(Vector2(a, float(ycut.call(a)) + 0.001))
	Q._run(k, keys, jff, yr, 0.0025, 0.0016, 0.0014, bk.lightened(0.06), tsk, 2)
	P._bd(k, AA._yl(P._ring_pts(keys, jh + 0.018, 0.004, 88), 0.0), 0.016, 0.004, bk, true, tsk)
	Q._run(k, keys, jff, [Vector2(0.0, N - 0.0), Vector2(0.0, jh + 0.002)], 0.0042, 0.0045, 0.002, bk.lightened(0.08), tsk, 20)
	Q._run(k, keys, jff, [Vector2(0.0, N - 0.0), Vector2(0.0, jh + 0.002)], 0.0016, 0.0065, 0.0012, zp, tsk, 20)
	var q: float = Q._hq(k)
	var ck := [[N + 0.07 * q, nk.x + 0.024, nk.y + 0.026, nk.z - 0.028], [N + 0.02 * q, nk.x + 0.028, nk.y + 0.028, nk.z - 0.03], [N - 0.02, nk.x + 0.04, nk.y + 0.036, nk.z - 0.04]]
	var clg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 48, "top": func(_a): return N + 0.068 * q, "hem": func(_a): return N - 0.018, "col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.005, "inner": bk.lightened(0.04), "skin": nsk})
	P._cord(k, clg["top"], 0.0034, bk.lightened(0.06), true, nsk)
	Q._run(k, ck, Callable(), [Vector2(0.0, N + 0.064 * q), Vector2(0.0, N - 0.016)], 0.0016, 0.0035, 0.0012, zp, nsk, 6)
	# ceket kolları: siyah, bileğe; ağızda lastik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.6
		var s1 := 0.93
		var sf := func(s: float, a: float) -> float:
			return 0.012 + 0.005 * smoothstep(0.4, 0.7, s) - 0.006 * smoothstep(0.8, s1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.45, 0.6, s) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.04), float(sf.call(float(s), float(a))) - 0.014, 12.0), 0.0, s1, 32, 20, 0.02)
		P._lt(k, ar, func(s, a): return 0.0105 + 0.0015 * sin(clampf((float(s) - 0.87) / 0.08, 0.0, 1.0) * PI) + 0.001 * sin(float(a) * 10.0), func(_s, a, ins): return bk.darkened(0.35) if ins else bk.darkened(0.1 * float(sin(float(a) * 10.0) < 0.0)), 0.87, 0.95, 5, 22)
	# haori: baldıra iner, önü açık
	var hem: float = lerpf(k.K, k.F, 0.52)
	var fam := func(p): return _psk(k, p, hem)
	var hk: Array = NN._coat_keys(k, b, 0.052, hem, 0.15, 0.12, 0.23)
	hk[0] = P._kp(nk, N + 0.012, 0.046)
	hk[1] = [N - 0.055, ch.x * 1.08 + 0.012, ch.y * 1.0 + 0.012, ch.z * 1.06 - 0.016]
	var ef := func(y: float) -> float: return 0.36 + 0.26 * pow(smoothstep(C - 0.05, N + 0.012, y), 1.2)
	var ff: Callable = NN._coat_fold(k, hem, 0.045)
	var e_h: float = ef.call(hem)
	var rf := func(a: float) -> float: return 0.045 * (1.0 - smoothstep(e_h, e_h + 0.42, absf(wrapf(a, -PI, PI))))
	var cg: Dictionary = P._cl(k, {"keys": hk, "ny": 46, "na": 88, "rng": func(v): return Vector2(float(ef.call(lerpf(N + 0.012, hem, float(v)))), TAU - float(ef.call(lerpf(N + 0.012, hem, float(v))))),
		"top": func(_a): return N + 0.012, "hem": func(a): return hem + float(rf.call(float(a))), "fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return rd, "gain": 4.0, "th": 0.007, "inner": lin, "skin": fam})
	# siyah alev bandı: üst kenarı alev dili olan ayrı kat
	P._cl(k, {"keys": hk, "ny": 7, "na": 280, "rng": func(_v): return Vector2(e_h, TAU - e_h), "top": func(a): return NN._flame(float(a), hem + 0.11, 0.2) + float(rf.call(float(a))), "hem": func(a): return hem + float(rf.call(float(a))),
		"fold": func(a, y, _v): return ff.call(float(a), float(y)), "col": func(_a, _y, _v): return bk, "gain": 3.0, "lift": 0.0028, "skin": fam, "th": 0.003, "inner": bk.lightened(0.04)})
	AA._edge_band(k, cg["ea"], 0.012, 0.0035, rd.darkened(0.22), fam, 1.0)
	AA._edge_band(k, cg["eb"], 0.012, 0.0035, rd.darkened(0.22), fam, -1.0)
	# haori yakası: boynu çeviren kırmızı bant
	var skt := func(p): return k.torso_skin(minf(float(p.y), N))
	var hc := [[N + 0.06 * q, nk.x + 0.05, nk.y + 0.042, nk.z - 0.056], [N + 0.0, nk.x + 0.064, nk.y + 0.054, nk.z - 0.068], [N - 0.05, nk.x + 0.09, nk.y + 0.07, nk.z - 0.088]]
	var hcg: Dictionary = P._cl(k, {"keys": hc, "ny": 10, "na": 52, "rng": func(_v): return Vector2(0.62, TAU - 0.62), "top": func(a): return N + q * lerpf(0.02, 0.058, smoothstep(0.7, 2.3, absf(float(a)))), "hem": func(_a): return N - 0.045,
		"fold": func(a, _y, v): return 0.008 * (1.0 - float(v)) * sin(float(a) * 4.0 + 0.6), "col": func(_a, _y, _v): return rd.darkened(0.12), "inner": lin, "skin": skt, "th": 0.006, "gain": 5.0})
	P._cord(k, hcg["top"], 0.0036, rd.darkened(0.25), false, skt)
	# haori kolları: dirsekte biten geniş kısa kol
	for sd in ["Left", "Right"]:
		var ar2: Dictionary = P._limb(k, sd, false)
		NN._bell(k, ar2, rd, lin, 0.026, float(ar2["kn"]) + 0.02, rd.darkened(0.15), 0.025, 1.4 if sd == "Left" else 2.9)
	# parşömen: bele yatay, sırtın arkasında; sol yana daha çok taşar
	var hff := func(a, y): return ff.call(float(a), float(y))
	var sy: float = H + 0.07
	var bz: float = (Q._spt(hk, hff, PI, sy)[0] as Vector3).z
	var sr := 0.062
	var cx := 0.045
	var c0 := Vector3(cx, sy, bz - sr - 0.012)
	var sl := 0.29
	var sbo := [["Hips", 0.55], ["Spine", 0.45]]
	var pts := []
	for i in 19:
		pts.append(c0 + Vector3(lerpf(-sl, sl, float(i) / 18.0), 0, 0))
	P._tb(k, pts, func(s, _a):
		var u: float = absf(float(s) * 2.0 - 1.0)
		return sr * (1.0 + 0.04 * float(u > 0.78 and u < 0.9)) - 0.004 * float(u > 0.97), func(s, a, _p):
		var u: float = absf(float(s) * 2.0 - 1.0)
		if u > 0.78 and u < 0.9:
			return bk
		return sc.darkened(0.12 * float(sin(float(a) * 2.0) < -0.6)), func(_s, _p): return sbo, 22)
	for sx in [-1.0, 1.0]:   # kapak: koyu çerçeve + açık göbek
		var ce: Vector3 = c0 + Vector3(sx * sl, 0, 0)
		var o := Vector3(sx, 0, 0)
		P._fan(k, ce, o, Vector3.UP, sr * 0.98, Callable(), func(u, v):
			var rr: float = Vector2(float(u), float(v)).length()
			return Color(0.86, 0.8, 0.66) if rr < 0.36 else (sc.darkened(0.35) if rr < 0.8 else bk), sbo, 5, 24)
		P._tb(k, [ce + o * 0.004, ce + o * 0.03], func(_s, _a): return sr * 0.3, func(_s, _a, _p): return Color(0.86, 0.8, 0.66).darkened(0.08), func(_s, _p): return sbo, 12)
	# kahve kayış: sol omuzdan önde sağ kalçaya, arkada parşömenin üstünden geri
	var fr := [Vector2(1.18, N - 0.03), Vector2(0.75, C + 0.0), Vector2(0.15, C - 0.1), Vector2(-0.55, H + 0.12), Vector2(-1.2, H + 0.04), Vector2(-1.75, sy - 0.01)]
	var bkp := [Vector2(1.18, N - 0.03), Vector2(1.9, C - 0.02), Vector2(2.6, C - 0.12), Vector2(3.4, H + 0.15), Vector2(4.1, sy + 0.02), Vector2(4.53, sy - 0.01)]
	var ssk := func(p): return k.torso_skin(maxf(float(p.y), H + 0.02))
	Q._run(k, hk, hff, fr, 0.024, 0.006, 0.004, br, ssk, 8)
	Q._run(k, hk, hff, bkp, 0.024, 0.006, 0.004, br, ssk, 8)
	for e in [fr, bkp]:   # kayış kenar dikişi
		Q._run(k, hk, hff, e, 0.0016, 0.0105, 0.001, br.darkened(0.25), ssk, 8)
	# kayış parşömeni sarar (iki halka)
	for sx2 in [-0.2, 0.17]:
		var rp := []
		for i in 25:
			var t: float = TAU * float(i) / 24.0
			rp.append(c0 + Vector3(sx2, sin(t) * (sr + 0.003), cos(t) * (sr + 0.003)))
		k.strip(rp, rp.map(func(p): return ((p as Vector3) - (c0 + Vector3(sx2, 0, 0))).normalized()), 0.016, 0.003, br.darkened(0.08), true, func(_p): return sbo)


# ------------------------------------------------------------------ Daidai Kodomo (ref "Naruto Outfit Young Vers."): kabarık turuncu eşofman ceketi (mavi omuz boyunduruğu ve lastikli mavi bel bandı,
## kalın beyaz ribanalı yüksek yaka, yakadan bele fermuar, eğik cep ağızları, bilekte turuncu manşet, sırtta ve sol omuzda kızıl girdap),
## bol turuncu eşofman altı + iki katlı kıvrık paça, sağ uylukta beyaz sargı + lacivert kılıf
static func _kodomo(k) -> void:
	var og := Color(0.95, 0.53, 0.16)
	var bl := Color(0.16, 0.27, 0.62)
	var wh := Color(0.95, 0.95, 0.94)
	var zp := Color(0.78, 0.78, 0.8)
	var rd := Color(0.72, 0.15, 0.12)
	var nv := Color(0.12, 0.15, 0.3)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	K._seat(k, b, og.darkened(0.05))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var pa: Callable = _leg_roll(k, le, og, 0.024, 0.02, 0.87, 0.009, 2, 0.6 if sd == "Left" else 2.2, 10.0)
		if sd == "Right":
			I._holster(k, le, pa, nv, nv, true)
	# ceket: kabarık, bel bandında büzülür
	var jh: float = H + 0.0
	var keys := [P._kp(nk, N + 0.008, 0.034), [N - 0.055, ch.x * 1.07, ch.y * 1.0, ch.z * 1.09], P._kp(ch, C - 0.03, 0.048), P._kp(wa, H + 0.12, 0.05), P._kp(wa, H + 0.05, 0.034), P._kp(k.M(jh, 0.3), jh, 0.014)]
	var yy: float = C + 0.03
	var jf := func(a: float, y: float, _v: float) -> float:
		var aw: float = absf(a)
		var bag: float = smoothstep(H + 0.15, H + 0.04, y) * (0.012 * sin(a * 9.0 + 0.4) + 0.006 * sin(a * 17.0))   # bel bandı üstünde büzgü
		return smoothstep(0.12, 0.45, aw) * (0.008 * sin(a * 6.0 + y * 14.0) + 0.005 * sin(a * 11.0 - y * 9.0) + bag)
	var jff := func(a, y): return jf.call(float(a), float(y), 0.0)
	var ycut := func(a: float) -> float: return yy - 0.015 * cos(a)
	P._cl(k, {"keys": keys, "ny": 36, "na": 92, "top": func(_a): return N + 0.008, "hem": func(_a): return jh + 0.03, "fold": jf, "col": func(a, y, _v): return bl if float(y) > float(ycut.call(float(a))) else og,
		"gain": 6.0, "th": 0.005, "inner": og.darkened(0.3), "skin": tsk})
	var yr := []
	for i in 49:
		var a: float = -PI + TAU * i / 48.0
		yr.append(Vector2(a, float(ycut.call(a)) + 0.0005))
	Q._run(k, keys, jff, yr, 0.0026, 0.0016, 0.0014, bl.darkened(0.15), tsk, 2)
	# lastikli mavi bel bandı
	var hb := [P._kp(k.M(jh + 0.045, 0.3), jh + 0.045, 0.03), P._kp(k.M(jh - 0.01, 0.3), jh - 0.01, 0.022)]
	P._cl(k, {"keys": hb, "ny": 5, "na": 96, "top": func(_a): return jh + 0.042, "hem": func(_a): return jh - 0.008, "fold": func(a, _y, v): return 0.006 * sin(float(v) * PI) + 0.0022 * sin(float(a) * 50.0),
		"col": func(_a, _y, _v): return bl, "gain": 9.0, "th": 0.004, "inner": bl.darkened(0.3), "skin": tsk})
	# fermuar + eğik cep ağızları
	Q._run(k, keys, jff, [Vector2(0.0, N + 0.0), Vector2(0.0, jh + 0.034)], 0.0045, 0.0055, 0.002, og.darkened(0.12), tsk, 20)
	Q._run(k, keys, jff, [Vector2(0.0, N + 0.0), Vector2(0.0, jh + 0.034)], 0.0017, 0.0075, 0.0012, zp, tsk, 20)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, jff, [Vector2(sg * 0.42, H + 0.14), Vector2(sg * 0.66, H + 0.065)], 0.0038, 0.0012, 0.0008, og.darkened(0.35), tsk, 5)
		Q._run(k, keys, jff, [Vector2(sg * 0.41, H + 0.143), Vector2(sg * 0.65, H + 0.068)], 0.0022, 0.0042, 0.0018, og.lightened(0.04), tsk, 5)
		Q._run(k, keys, jff, [Vector2(sg * PI * 0.5, yy - 0.01), Vector2(sg * PI * 0.5, jh + 0.04)], 0.0018, 0.0016, 0.0012, og.darkened(0.2), tsk, 8)
	# beyaz ribanalı yüksek yaka: kalın, ağzı dışa kıvrık; önde fermuar geçer
	var q: float = Q._hq(k)
	var kb: Array = SE.El.key_at(keys, N - 0.02)
	var ck := [[N + 0.085 * q, nk.x + 0.05, nk.y + 0.05, nk.z - 0.054], [N + 0.04 * q, nk.x + 0.036, nk.y + 0.036, nk.z - 0.04], [N - 0.022, float(kb[1]) + 0.006, float(kb[2]) + 0.006, float(kb[3]) - 0.006]]
	var rib := func(a: float) -> float: return 0.012 * maxf(0.0, sin(a * 34.0)) - 0.003
	var clg: Dictionary = P._cl(k, {"keys": ck, "ny": 12, "na": 136, "top": func(_a): return N + 0.085 * q, "hem": func(_a): return N - 0.02, "fold": func(a, _y, v): return float(rib.call(float(a))) * (0.6 + 0.4 * sin(float(v) * PI)),
		"col": func(a, _y, _v): return wh.darkened(0.2 * (1.0 - smoothstep(-0.2, 0.6, sin(float(a) * 34.0)))), "gain": 4.0, "th": 0.007, "inner": wh.darkened(0.25), "skin": nsk})
	P._cord(k, clg["top"], 0.007, wh.darkened(0.04), true, nsk)
	Q._run(k, ck, Callable(), [Vector2(0.0, N + 0.08 * q), Vector2(0.0, N - 0.016)], 0.0017, 0.009, 0.0012, zp, nsk, 6)
	var zt: Array = Q._spt(ck, Callable(), 0.0, N + 0.06 * q, 0.012)
	P._boxr(k, zt[0], Vector3(0.0055, 0, 0), Vector3(0, 0.013, 0), (zt[1] as Vector3) * 0.0028, zp.lightened(0.06), [["Neck", 0.5], ["UpperChest", 0.5]], 0.3)
	# kollar: bol turuncu, bilekte manşet; mavi boyunduruk omuz başına iner
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.5 if sd == "Left" else 0.3
		var s1: float = 0.87
		var sf := func(s: float, a: float) -> float:
			return 0.02 + 0.012 * smoothstep(0.05, 0.4, s) - 0.012 * smoothstep(0.66, s1, s) + 0.005 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.009 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - s1 + 0.04) / 0.04, 2.0)) * sin(a * 6.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins):
			if ins:
				return og.darkened(0.35)
			var c0: Color = bl if float(s) < 0.1 else og
			return P._fs(c0, float(sf.call(float(s), float(a))) - 0.028, 12.0), 0.0, s1, 34, 22, 0.02)
		var cf := func(s: float, a: float) -> float: return 0.017 + 0.003 * sin(clampf((s - s1 + 0.01) / 0.09, 0.0, 1.0) * PI) + 0.0015 * sin(a * 6.0)
		P._lt(k, ar, cf, func(_s, _a, ins): return og.darkened(0.35) if ins else og.lightened(0.04), s1 - 0.01, 0.955, 6, 24)
		K._lt_in(k, ar, func(s, a): return float(cf.call(float(s), float(a))) - 0.005, og.darkened(0.35), 0.9, 0.95, 4, 24)
		Q._ring_on(k, ar, s1 - 0.006, cf, 0.003, og.darkened(0.2), 0.0)
		Q._ring_on(k, ar, 0.1, sf, 0.0025, bl.darkened(0.2), 0.0012)
		if sd == "Left":
			var oa: float = J._outer_a(ar, 0.26, Vector3(sg, 0.45, 0.2))
			_swirl(k, AF._lmap(ar, 0.26, oa, sf), 0.024, rd, func(_p): return P._lskin(ar, 0.26), 0.003)
	# sırtta kızıl girdap (turuncu zeminde)
	_swirl(k, AA._back_mp(keys, 0.0, lerpf(yy, H + 0.06, 0.4)), 0.055, rd, tsk, 0.007)


# ------------------------------------------------------------------ Itazura Kozō (ref "Naruto Outfit: Prankster Ver."): bol lacivert-siyah tişört (bisiklet yaka, üst kol ortasına inen kol), çıplak ön kol,
## bele bağlı turuncu ceket (gövdesi kalçayı sararak uyluk ortasına sarkar, önde cep kapaklı kanatlar, kolları önde düğümlenip lacivert manşetli uçlarla sarkar), kıvrık paçalı turuncu pantolon
static func _itazura(k) -> void:
	var ts := Color(0.13, 0.145, 0.24)
	var og := Color(0.93, 0.48, 0.24)
	var nv := Color(0.12, 0.16, 0.36)
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
	K._seat(k, b, og.darkened(0.05))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		_leg_roll(k, le, og, 0.02, 0.016, 0.88, 0.008, 2, 2.4 if sd == "Left" else 0.9, 10.0)
	# tişört: bol, kalçaya iner (ceket düğümünün altına girer)
	var th: float = H + 0.0
	var tk := [P._kp(nk, N + 0.01, 0.022), [N - 0.055, ch.x * 0.95, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.04), P._kp(k.M(th, 0.3), th, 0.03)]
	var vt := func(a: float) -> float: return lerpf(N - 0.035, N + 0.01, smoothstep(0.0, 0.85, absf(a)))
	var tf := func(a: float, y: float, _v: float) -> float:
		return 0.008 * sin(a * 5.0 + y * 13.0) * smoothstep(N - 0.02, C - 0.04, y) + 0.009 * sin(a * 7.0 + 0.8) * smoothstep(C - 0.05, H + 0.06, y) + 0.004 * sin(a * 13.0 - y * 20.0)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 30, "na": 84, "top": func(a): return vt.call(float(a)), "hem": func(_a): return th, "fold": tf, "col": func(_a, _y, _v): return ts, "gain": 7.0, "th": 0.004, "skin": tsk})
	_v_skin(k, b, N - 0.07)
	P._bd(k, tg["top"], 0.0055, 0.0028, ts.lightened(0.06), true, tsk, 0.35)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, Callable(), [Vector2(sg * PI * 0.5, N - 0.08), Vector2(sg * PI * 0.5, th + 0.02)], 0.0016, 0.0016, 0.0012, ts.darkened(0.3), tsk, 6)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.4 if sd == "Left" else 2.5
		var s1 := 0.38
		R._arm_skin(k, ar, s1 - 0.05)
		var sh := func(s: float, a: float) -> float: return 0.02 + 0.01 * smoothstep(0.05, s1, s) + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sh, func(s, a, ins): return ts.darkened(0.35) if ins else P._fs(ts, 0.003 * P._lf(float(s), float(a), sv), 16.0), 0.0, s1, 16, 22, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.0018, func(_s, _a, ins): return ts.darkened(0.3) if ins else ts.lightened(0.04), s1 - 0.026, s1 + 0.001, 3, 22)
	# bele bağlı ceket: kalçayı saran gövde, uyluk ortasına sarkar; önde iki kanat arası açık (kollar düğümlenir)
	var hem: float = H - 0.2
	var fam := func(p): return AA._fam(k, p, hem)
	var by: float = H + 0.03
	var ck := [P._kp(k.M(by + 0.03, 0.3), by + 0.03, 0.032), P._kp(k.M(by, 0.3), by, 0.04), P._kp(hp, H - 0.04, 0.05), [H - 0.12, hp.x + 0.06, hp.y + 0.05, hp.z - 0.06], [hem, hp.x + 0.075, hp.y + 0.055, hp.z - 0.075]]
	var cf := func(a: float, y: float) -> float:
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		var gat: float = (1.0 - smoothstep(0.0, 0.25, t)) * 0.02 * sin(a * 15.0 + 0.3)   # bağın altında büzgü
		return gat + t * (0.022 * sin(a * 6.0 + 0.9) + 0.01 * sin(a * 11.0 + 0.2))
	var cff := func(a, y): return cf.call(float(a), float(y))
	var eo := 0.5
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 26, "na": 96, "rng": func(_v): return Vector2(eo, TAU - eo), "top": func(_a): return by + 0.03, "hem": func(a): return hem + 0.03 * (1.0 - smoothstep(0.2, 0.9, absf(float(a)))),
		"fold": func(a, y, _v): return cf.call(float(a), float(y)), "col": func(_a, _y, _v): return og, "gain": 5.0, "th": 0.006, "inner": og.darkened(0.3), "skin": fam})
	P._bd(k, AA._yl(cg["hem"], 0.012), 0.012, 0.004, nv, false, fam)
	AA._edge_band(k, cg["ea"], 0.009, 0.003, og.darkened(0.12), fam, 1.0)
	AA._edge_band(k, cg["eb"], 0.009, 0.003, og.darkened(0.12), fam, -1.0)
	for sg in [1.0, -1.0]:   # ön kanatlarda cep kapağı + fermuar dişi
		AA._flap(k, ck, cff, sg * 0.62, H - 0.07, 0.08, 0.032, -sg * 0.04, og.darkened(0.04), fam, 0.005)
	Q._run(k, ck, cff, [Vector2(eo + 0.02, by), Vector2(eo + 0.02, hem + 0.05)], 0.0015, 0.003, 0.0012, Color(0.74, 0.74, 0.76), fam, 10)
	# kollar: yanlardan öne sarılır, önde düğüm, iki uç sarkar
	var ksk := [["Hips", 0.85], ["Spine", 0.15]]
	var R0 := 0.03
	var hk2 := [P._kp(k.M(by, 0.3), by, 0.045), P._kp(hp, H - 0.04, 0.03), [H - 0.22, hp.x + 0.01, hp.y + 0.006, hp.z]]
	for sg in [1.0, -1.0]:
		var wrp := []
		for i in 9:
			var t: float = float(i) / 8.0
			var a: float = sg * lerpf(1.5, 0.16, t)
			wrp.append(Q._spt(ck, cff, a, by + 0.008 - 0.01 * sin(t * PI), R0 * 0.75)[0])
		P._tb(k, wrp, func(s, a): return R0 * (1.0 - 0.38 * pow(cos(float(a)), 2.0)) * (1.0 + 0.08 * sin(float(s) * 20.0)), func(s, a, _p): return P._fs(og, 0.01 * sin(float(s) * 20.0 + float(a)), 8.0), func(_s, _p): return ksk, 14)
		# sarkan uç: kumaşın önüne yatar, ucu lacivert manşet
		var hg := []
		for i in 10:
			var t: float = float(i) / 9.0
			var y: float = lerpf(by - 0.02, H - 0.21, t)
			var a2: float = sg * lerpf(0.1, 0.3, t)
			hg.append(Q._spt(hk2, Callable(), a2, y, R0 * 0.62)[0])
		P._tb(k, hg, func(s, a):
			var cuf: float = smoothstep(0.78, 0.82, float(s))
			return (R0 * 0.95 + 0.004 * cuf) * (1.0 - 0.48 * pow(cos(float(a)), 2.0)) * (1.0 - 0.25 * smoothstep(0.95, 1.0, float(s))), func(s, a, _p):
			if float(s) > 0.8:
				return nv.darkened(0.1 * float(sin(float(a) * 9.0) < 0.0))
			return P._fs(og, 0.008 * sin(float(s) * 14.0 + float(a) * 2.0 + sg), 8.0), func(_s, p): return fam.call(p), 14)
	var kc: Array = Q._spt(ck, cff, 0.0, by - 0.002, R0 * 0.9)
	P._boxr(k, kc[0], Vector3(0.03, 0.004, 0), Vector3(-0.003, 0.024, 0), (kc[1] as Vector3) * 0.02, og.darkened(0.08), ksk, 0.5)
	P._boxr(k, (kc[0] as Vector3) + (kc[1] as Vector3) * 0.012, Vector3(0.012, 0, 0), Vector3(0, 0.026, 0), (kc[1] as Vector3) * 0.012, og.darkened(0.16), ksk, 0.5)


# ------------------------------------------------------------------ Unmei Wakate (ref "Neji Outfit Young Vers."): kırık beyaz kısa kollu gömlek (yüksek dik yaka, önde orta dikiş + beş yatay çin düğmesi kuşağı,
## kalçaya iner), diz boyu mor-lacivert şort, sağ kol bileğe dek sargılı, sağ baldır sargılı, sağ uylukta beyaz bantlı siyah kılıf, sol ön kol ve sol baldır açık
static func _unmei(k) -> void:
	var cr := Color(0.91, 0.88, 0.82)
	var crd := Color(0.72, 0.68, 0.62)
	var pn := Color(0.23, 0.19, 0.36)
	var wr := Color(0.94, 0.93, 0.9)
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
	# şort: diz boyu, paçası dizin hemen altında
	K._seat(k, b, pn.darkened(0.05))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.2 if sd == "Left" else 2.8
		var s1: float = kn + 0.05
		var ad: Callable = R._short_leg(k, le, pn, s1, 0.018, 0.016, sv)
		R._hem_roll(k, le, ad, s1, pn.darkened(0.08), 0.024, 0.0022)
		if sd == "Right":   # baldır sargısı: dizden bileğe
			P._lt(k, le, func(_s, _a): return 0.003, func(_s, _a, ins): return skc.darkened(0.3) if ins else wr.darkened(0.15), s1 - 0.06, 1.0, 16, 18)
			P._wraps(k, le, s1 - 0.02, 0.975, 15, 0.0075, 0.0125, wr, 0.009)
			I._holster(k, le, ad, bk, bk.lightened(0.05), true)
		else:
			P._bare(k, le, skc, s1 - 0.06, 1.0)
	# gömlek gövdesi: kalçaya iner, hafif açılır
	var hem: float = H - 0.07
	var fam := func(p): return AA._fam(k, p, hem)
	var tk := [P._kp(nk, N + 0.012, 0.026), [N - 0.055, ch.x * 1.04, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.036), P._kp(k.M(H + 0.06, 0.3), H + 0.06, 0.036), [H - 0.03, hp.x + 0.04, hp.y + 0.04, hp.z - 0.06], [hem, hp.x + 0.052, hp.y + 0.046, hp.z - 0.075]]
	var tf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - hem), 0.0, 1.0)
		var fr: float = smoothstep(0.32, 0.6, absf(a))   # çin düğmeli ön düz
		return fr * ((1.0 - t) * (0.007 * sin(a * 6.0 + y * 14.0) * smoothstep(N - 0.02, C - 0.04, y)) + t * (0.012 * sin(a * 7.0 + 0.6) + 0.006 * sin(a * 12.0)))
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	P._cl(k, {"keys": tk, "ny": 40, "na": 92, "top": func(_a): return N + 0.012, "hem": func(_a): return hem, "fold": tf, "col": func(_a, _y, _v): return cr, "gain": 6.0, "th": 0.006, "inner": crd, "skin": fam})
	# orta dikiş + yan dikiş + etek biyesi
	Q._run(k, tk, tff, [Vector2(0.0, N + 0.01), Vector2(0.0, hem + 0.004)], 0.0018, 0.0016, 0.0012, crd, fam, 18)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tff, [Vector2(sg * PI * 0.5, C - 0.05), Vector2(sg * PI * 0.5, hem + 0.01)], 0.0016, 0.0015, 0.0012, crd, fam, 10)
	P._bd(k, AA._yl(P._ring_pts(tk, hem, 0.0, 92), 0.01), 0.0085, 0.0028, cr.darkened(0.06), true, fam)
	# yatay çin düğmeleri: her biri iki ilmekli bar + ortada düğüm
	var bys: Array = [N - 0.06, C + 0.02, C - 0.045, C - 0.11, H + 0.05]
	for yb in bys:
		var by2: float = yb
		var ww: float = 0.3 if by2 > C else 0.34
		for sg in [1.0, -1.0]:
			# ilmek: dikdörtgen çerçeve (kabartma), kenarı ince
			var lp := [Vector2(sg * 0.035, by2 + 0.006), Vector2(sg * ww, by2 + 0.006), Vector2(sg * (ww + 0.035), by2), Vector2(sg * ww, by2 - 0.006), Vector2(sg * 0.035, by2 - 0.006)]
			Q._run(k, tk, tff, lp, 0.0042, 0.0032, 0.0026, cr.darkened(0.1), fam, 4)
			Q._run(k, tk, tff, [Vector2(sg * 0.035, by2), Vector2(sg * (ww - 0.02), by2)], 0.0016, 0.0058, 0.0008, crd.darkened(0.15), fam, 4)
		var e: Array = Q._spt(tk, tff, 0.0, by2, 0.004)
		P._stud(k, e[0], e[1], 0.0068, crd.darkened(0.1), fam.call(e[0]))
	# yüksek dik yaka: çeneye kadar, önde orta yarık
	var q: float = Q._hq(k)
	var ck := [[N + 0.08 * q, nk.x + 0.02, nk.y + 0.022, nk.z - 0.024], [N + 0.03 * q, nk.x + 0.026, nk.y + 0.026, nk.z - 0.028], [N - 0.02, nk.x + 0.044, nk.y + 0.04, nk.z - 0.044]]
	var clg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 60, "rng": func(_v): return Vector2(0.025, TAU - 0.025), "top": func(a): return N + q * lerpf(0.07, 0.082, smoothstep(0.2, 2.0, absf(float(a)))), "hem": func(_a): return N - 0.018,
		"fold": func(a, _y, _v): return 0.004 * sin(float(a) * 5.0), "col": func(_a, _y, _v): return cr, "gain": 6.0, "th": 0.006, "inner": crd, "skin": nsk})
	P._cord(k, clg["top"], 0.0032, cr.darkened(0.05), false, nsk)
	for yc in [N + 0.05 * q, N + 0.012]:
		var e2: Array = Q._spt(ck, Callable(), 0.0, yc, 0.004)
		P._boxr(k, e2[0], Vector3(0.02, 0, 0), Vector3(0, 0.0045, 0), (e2[1] as Vector3) * 0.003, cr.lightened(0.02), [["Neck", 0.5], ["UpperChest", 0.5]], 0.4)
	# kollar: üst kolun yarısına inen geniş kısa kol; sağ kol sargılı, sol ön kol açık
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.6 if sd == "Left" else 2.0
		var s1 := 0.4
		if sd == "Right":
			P._lt(k, ar, func(s, _a): return 0.003 - 0.004 * smoothstep(0.95, 0.99, float(s)), func(_s, _a, ins): return skc if ins else wr.darkened(0.15), s1 - 0.06, 0.985, 24, 18)
			P._wraps(k, ar, s1 - 0.02, 0.96, 18, 0.006, 0.0105, wr, 0.008)
		else:
			R._arm_skin(k, ar, s1 - 0.06)
		var sh := func(s: float, a: float) -> float: return 0.017 + 0.016 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.1, 0.3, s)
		P._lt(k, ar, sh, func(s, a, ins): return crd if ins else P._fs(cr, 0.004 * P._lf(float(s), float(a), sv), 14.0), 0.0, s1, 18, 22, 0.035)
		Q._ring_on(k, ar, s1 - 0.018, sh, 0.004, cr.darkened(0.06), 0.0012)


# ------------------------------------------------------------------ Nindō Tīshatsu (ref "Ninja Way T-Shirts", Naruto): turuncu gövdeli tişört, lacivert kısa kollar, lacivert V yaka ve etek biyesi,
## önde beyaz Sekiz Trigram mührü (girdap + sekiz yazı kümesi), sol kolda Konoha yaprağı; lacivert düz pantolon
static func _nindo(k) -> void:
	var og := Color(0.93, 0.6, 0.2)
	var nv := Color(0.12, 0.165, 0.28)
	var wh := Color(0.97, 0.96, 0.93)
	var pn := Color(0.12, 0.15, 0.25)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	K._seat(k, b, pn)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var pa: Callable = K._pant(k, le, pn, 0.014, 0.012, 0.975, 1.9 if sd == "Left" else 0.5)
		P._lt(k, le, func(s, a): return float(pa.call(minf(float(s), 0.975), a)) + 0.002, func(_s, _a, ins): return pn.darkened(0.4) if ins else pn.darkened(0.1), 0.955, 0.985, 3, 20)
	# tişört: kalçaya iner, önü düz (mühür bozulmaz)
	var hem: float = H - 0.06
	var fam := func(p): return AA._fam(k, p, hem)
	var tk := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.034), P._kp(k.M(H + 0.06, 0.3), H + 0.06, 0.032), P._kp(hp, H - 0.03, 0.034), [hem, hp.x + 0.04, hp.y + 0.034, hp.z - 0.036]]
	var vt := func(a: float) -> float: return lerpf(N - 0.055, N + 0.012, smoothstep(0.0, 0.5, absf(a)))
	var tf := func(a: float, y: float, _v: float) -> float:
		var fr: float = smoothstep(0.55, 0.95, absf(a))
		return fr * (0.007 * sin(a * 6.0 + y * 13.0) + 0.006 * sin(a * 9.0 + 0.7) * smoothstep(C - 0.05, hem, y)) + (1.0 - fr) * 0.002 * sin(y * 30.0 + a * 3.0) * smoothstep(H + 0.05, hem, y)
	var tff := func(a, y): return tf.call(float(a), float(y), 0.0)
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 40, "na": 92, "top": func(a): return vt.call(float(a)), "hem": func(_a): return hem, "fold": tf, "col": func(_a, _y, _v): return og, "gain": 7.0, "th": 0.005, "inner": og.darkened(0.3), "skin": fam})
	_v_skin(k, b, N - 0.1)
	# lacivert V yaka bandı + etek biyesi
	var tops: Array = tg["top"]
	P._bd(k, tops, 0.0085, 0.003, nv, true, tsk, 0.3)
	P._bd(k, AA._yl(tg["hem"], 0.011), 0.011, 0.0032, nv, true, fam)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tff, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, hem + 0.02)], 0.0016, 0.0015, 0.0012, og.darkened(0.25), fam, 8)
	# Sekiz Trigram mührü: göğüs ortasında, beyaz kabartma
	var sm: Array = _mp_at(tk, tff, 0.0, lerpf(C, H, 0.45))
	_hakke(k, sm[0], 0.15, wh, tsk)
	# kollar: lacivert kısa kol, omuzda gövdeye dikişli; sol kolda Konoha yaprağı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sg: float = ar["sg"]
		var sv: float = 1.1 if sd == "Left" else 2.7
		var s1 := 0.37
		R._arm_skin(k, ar, s1 - 0.05)
		var sh := func(s: float, a: float) -> float: return 0.014 + 0.011 * smoothstep(0.05, s1, s) + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sh, func(s, a, ins): return nv.darkened(0.35) if ins else P._fs(nv, 0.003 * P._lf(float(s), float(a), sv), 16.0), 0.0, s1, 16, 22, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.0018, func(_s, _a, ins): return nv.darkened(0.3) if ins else nv.lightened(0.05), s1 - 0.028, s1 + 0.001, 3, 22)
		Q._ring_on(k, ar, 0.07, sh, 0.0025, og.darkened(0.1), 0.0015)
		if sd == "Left":
			var oa: float = J._outer_a(ar, 0.22, Vector3(sg, 0.3, 0.15))
			_leaf_mark(k, AF._lmap(ar, 0.22, oa, sh), 0.016, Color(0.05, 0.06, 0.09), func(_p): return P._lskin(ar, 0.22), 0.0028)
