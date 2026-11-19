extends RefCounted
## Elle modellenmiş setler, parti an: ss_pembe_kunoichi2, ss_son_savas, ss_kizil_fermuar, ss_kizil_elbise, ss_kukla_genc, ss_yelpaze. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{sakura_outfit_3, sakura_outfit_last_battle_ver, sarada_outfit, sarada_outfit_2 (Indigo), sasori_outfit_young_ver, sasuke_outfit}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), r (R), x (X), z (Z), aa (AA), i (I), t (T), v (V), y (Y), ag (AG) dosyalarından.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const V = preload("res://scripts/actors/set_el_v.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")

const DONE := ["ss_pembe_kunoichi2", "ss_son_savas", "ss_kizil_fermuar", "ss_kizil_elbise", "ss_kukla_genc", "ss_yelpaze"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_pembe_kunoichi2": _haruno(k)
		"ss_son_savas": _saigo(k)
		"ss_kizil_fermuar": _sarada(k)
		"ss_kizil_elbise": _sarada2(k)
		"ss_kukla_genc": _sasori(k)
		"ss_yelpaze": _sasuke(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Ucu açıya göre değişen kol parçası (yırtık kol kökü): s1f(a) -> bitiş; ağız içe döner
static func _lt_var(k, l: Dictionary, add: float, col: Color, s1f: Callable, n := 8, seg := 30) -> void:
	var rows := []
	var ss := []
	for j in n + 3:
		var ro := []
		var sr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var e: float = float(s1f.call(a))
			var s: float = e * float(mini(j, n)) / n
			var lf: float = add * (1.0 - 0.25 * smoothstep(0.6, 1.0, float(mini(j, n)) / n))
			if j == n + 1:
				lf = add * 0.75 - 0.004
			elif j == n + 2:
				s = maxf(0.0, e - 0.03)
				lf = add * 0.75 - 0.007
			ro.append(Q._ls(l, s, a, lf)[0])
			sr.append(s)
		rows.append(ro)
		ss.append(sr)
	k.grid(rows, true, func(i, j, _p): return col.darkened(0.42) if j > n else P._fs(col, 0.004 * sin(TAU * float(i) / seg * 5.0 + float(j)), 10.0), func(i, j, _p): return P._lskin(l, ss[j][i]))


## Dirsek / diz yastığı: kabarık bant, kenarları kıvrık
static func _pad_on(k, l: Dictionary, s0: float, s1: float, add: float, col: Color, base := 0.001) -> void:
	P._lt(k, l, func(s, a):
		var u: float = clampf((float(s) - s0) / (s1 - s0), 0.0, 1.0)
		return base + add * (0.55 + 0.45 * sin(u * PI)) + 0.0018 * sin(float(a) * 5.0 + float(s) * 30.0) * sin(u * PI), func(s, a, ins):
		if ins:
			return col.darkened(0.35)
		var u: float = clampf((float(s) - s0) / (s1 - s0), 0.0, 1.0)
		return col.darkened(0.16 * (1.0 - smoothstep(0.0, 0.18, u) * smoothstep(1.0, 0.82, u)) + 0.06 * maxf(0.0, sin(float(a) * 5.0 + float(s) * 30.0))), s0, s1, 10, 22)


## Kısa etek altındaki şort kalçası: ince, kasık arasını kapatır; etek / panel arkasını delmez
static func _lowseat(k, b: Dictionary, y0: float, col: Color) -> void:
	var hp: Vector3 = b["hp"]
	var H: float = k.H
	SE.body_layer(k, [P._kp(k.M(y0, 0.3), y0, 0.006), P._kp(hp, H - 0.05, 0.008), [H - 0.13, hp.x * 0.72, hp.y * 0.72, hp.z * 0.72]], 12, 48, func(_i, _j, _p): return col)


## Uyluk sargısı (sıkı turlar)
static func _thigh_wrap(k, le: Dictionary, s0: float, n: int, add: float, col: Color) -> void:
	for i in n:
		var s: float = s0 + float(i) * 0.024
		k.wrap_turn(P._lp(le, s), P._ld(le, s), P._lr(le, s) + add, 0.0135, 0.007 * (1.0 if i % 2 == 0 else -1.0), col.darkened(0.05 * float(i % 2)), P._lskin(le, s))


## Sırtta yerel eşlemede halka
static func _ring2(r: float, n := 40) -> Array:
	var o := []
	for i in n:
		var t := TAU * i / n
		o.append(Vector2(cos(t), sin(t)) * r)
	return o


## Burgu ip halkası (bel)
static func _rope_ring(k, keys: Array, ff: Callable, y: float, tilt: float, lift: float, R0: float, col: Color, skinf: Callable) -> void:
	var pts := []
	for i in 72:
		var a := TAU * i / 72.0 - PI
		pts.append(Q._spt(keys, ff, a, y + tilt * sin(a + 0.6), lift + R0)[0])
	T._twist(k, pts, true, R0, 26.0, col, skinf)


## Ön / arka panel ağırlığı: her yarı kendi uyluğunu sıkı izler (geri giden kalça paneli delmez), ortada dar geçiş
static func _pnl(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var w: float = 0.93 * pow(minf(1.0, t / 0.3), 0.5) * lerpf(1.0, 0.9, smoothstep(0.7, 1.0, t))
	var s: float = smoothstep(-0.06, 0.06, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


# ------------------------------------------------------------------ Saigo no Tatakai (ref "Sakura Outfit Last Battle Ver."): yeleksiz lacivert Konoha takımı; dik boğazlı uzun kollu üst (sağ kolu omuzdan
## yırtık, düzensiz kopuk kenar), baldır ortasında biten pantolon, altında beyaz baldır sargısı, sağ uylukta iki beyaz bantlı lacivert kılıf
static func _saigo(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var wh := Color(0.9, 0.9, 0.88)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	K._seat(k, b, nv.darkened(0.06))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.9 if sd == "Left" else 2.2
		var pa: Callable = K._pant(k, le, nv, 0.012, 0.018, 0.85, sv)
		J._shin_tape(k, le, func(s, a): return minf(float(pa.call(float(s), float(a))), 0.006), 0.835, 8, wh)
		if sd == "Right":
			J._holster(k, le, pa, wh, nv.darkened(0.12))
	# üst: kalçaya iner, pantolonun üstüne biner
	var jh: float = H + 0.0
	var keys := [P._kp(nk, N + 0.01, 0.02), [N - 0.055, ch.x * 1.0, ch.y * 0.95, ch.z * 1.04], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.026), P._kp(k.M(H + 0.04, 0.3), H + 0.04, 0.03), P._kp(k.M(jh, 0.3), jh, 0.032)]
	var jf := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 6.0 + y * 15.0) * smoothstep(C, H + 0.06, y) + 0.003 * sin(a * 11.0 - y * 9.0) + 0.004 * sin(a * 4.0 - y * 24.0) * smoothstep(C - 0.04, N, y)
	var jg: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 84, "top": func(_a): return N + 0.01, "hem": func(_a): return jh, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return nv, "gain": 7.0, "th": 0.005, "inner": nv.darkened(0.4), "skin": tsk})
	P._bd(k, AA._yl(jg["hem"], 0.008), 0.005, 0.002, nv.darkened(0.1), true, tsk)
	X._neck(k, b, nv, 0.034, false)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, jf, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, jh + 0.014)], 0.0016, 0.0016, 0.0012, nv.darkened(0.28), tsk, 6)
	# sol kol tam, bilekte dönük ağız
	var la: Dictionary = P._limb(k, "Left", false)
	var sl: Callable = X._sleeve(k, la, nv, 0.965, 1.3, 0.01)
	P._lt(k, la, func(s, a): return float(sl.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return nv.darkened(0.4) if ins else nv.darkened(0.08), 0.93, 0.965, 3, 18)
	# sağ kol: çıplak; omuzda yırtık kol kökü
	var ra: Dictionary = P._limb(k, "Right", false)
	Z._arm_bare(k, ra)
	_lt_var(k, ra, 0.011, nv, func(a): return 0.1 + 0.035 * sin(float(a) * 2.0 + 0.7) + 0.028 * pow(Y._teeth(float(a), 11.0, 0.3), 2.0) + 0.012 * Y._teeth(float(a), 23.0, 0.1))


# ------------------------------------------------------------------ Kugutsu Wakate (ref "Sasori Outfit: Young Ver."): kalçaya inen dik yakalı fermuarlı koyu mor ceket, belde gümüş tokalı kahve kemer,
## bilekte beyaz sargı + siyah parmaksız eldiven, koyu gri pantolon, beyaz baldır sargısı, sağ uylukta beyaz sargı + lacivert kılıf
static func _sasori(k) -> void:
	var pu := Color(0.227, 0.165, 0.29)
	var gy := Color(0.33, 0.31, 0.39)
	var br := Color(0.48, 0.36, 0.24)
	var bk := Color(0.1, 0.1, 0.12)
	var wh := Color(0.9, 0.9, 0.88)
	var nvb := Color(0.13, 0.16, 0.3)
	var mt := Color(0.72, 0.73, 0.76)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	K._seat(k, b, gy.darkened(0.06))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.4 if sd == "Left" else 0.5
		var pa: Callable = K._pant(k, le, gy, 0.013, 0.022, 0.85, sv)
		J._shin_tape(k, le, func(s, a): return minf(float(pa.call(float(s), float(a))), 0.006), 0.835, 8, wh)
		if sd == "Right":
			I._holster(k, le, pa, wh, nvb, true)
	# ceket: kalçayı örter, kemer üstünde kabarır
	var hem: float = H - 0.075
	var by: float = H + 0.05
	var jk := [P._kp(nk, N + 0.01, 0.026), [N - 0.055, ch.x * 1.04, ch.y * 0.97, ch.z * 1.06], P._kp(ch, C - 0.03, 0.032), P._kp(wa, H + 0.12, 0.036), P._kp(wa, by, 0.03), [H - 0.0, hp.x + 0.032, hp.y + 0.03, hp.z - 0.032], [hem, hp.x + 0.046, hp.y + 0.042, hp.z - 0.046]]
	var jsk := func(p): return T._ksk(k, p, hem)
	var jf := func(a: float, y: float) -> float:
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		var bl: float = 0.014 * exp(-pow((y - by - 0.04) / 0.03, 2.0)) * (0.6 + 0.4 * sin(a * 9.0 + 0.4))
		return smoothstep(0.05, 0.22, absf(a)) * (0.006 * sin(a * 6.0 + y * 15.0) + 0.004 * sin(a * 11.0 - y * 9.0) + t * 0.012 * sin(a * 7.0 + 0.9)) + bl
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 40, "na": 92, "top": func(_a): return N + 0.01, "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return pu, "gain": 7.0, "th": 0.006, "inner": pu.darkened(0.4), "skin": jsk})
	P._bd(k, AA._yl(jg["hem"], 0.009), 0.006, 0.002, pu.darkened(0.15), true, jsk)
	Q._run(k, jk, jf, [Vector2(0.0, N + 0.0), Vector2(0.0, hem + 0.004)], 0.0042, 0.0036, 0.002, pu.darkened(0.22), jsk, 24)
	Q._run(k, jk, jf, [Vector2(0.0, N + 0.0), Vector2(0.0, hem + 0.004)], 0.0016, 0.0058, 0.0012, mt, jsk, 24)
	for sg in [1.0, -1.0]:
		Q._run(k, jk, jf, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, hem + 0.012)], 0.0016, 0.0016, 0.0012, pu.darkened(0.3), jsk, 8)
	# kemer + toka
	V._belt(k, jk, by, 0.0, 0.016, 0.009, br, 0.0, 96)
	var bp: Array = V._belt_pt(jk, 0.0, by, 0.0, 0.012)
	V._buckle(k, bp[0], bp[1], 0.024, 0.017, mt, [["Hips", 0.6], ["Spine", 0.4]])
	for sg in [1.0, -1.0]:
		var lp: Array = V._belt_pt(jk, sg * 1.25, by, 0.0, 0.011)
		P._boxr(k, lp[0], Vector3.UP.cross(lp[1]).normalized() * 0.006, Vector3(0, 0.02, 0), (lp[1] as Vector3) * 0.003, br.darkened(0.12), [["Hips", 0.6], ["Spine", 0.4]], 0.3)
	# dik yaka (önde fermuar ağzı) + fermuar çekeceği
	X._neck(k, b, pu, 0.075, true)
	var zt: Array = Q._spt(jk, jf, 0.0, N - 0.01, 0.006)
	P._boxr(k, zt[0], Vector3(0.005, 0, 0), Vector3(0, 0.012, 0), (zt[1] as Vector3) * 0.0028, mt, [["Neck", 0.4], ["UpperChest", 0.6]], 0.3)
	# kollar: bileğe, beyaz sargı, siyah parmaksız eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.7 if sd == "Left" else 2.1
		var sl: Callable = X._sleeve(k, ar, pu, 0.88, sv, 0.015)
		P._lt(k, ar, func(s, a): return float(sl.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return pu.darkened(0.4) if ins else pu.darkened(0.1), 0.85, 0.88, 3, 18)
		for i in 3:
			var s: float = 0.875 + float(i) * 0.02
			k.wrap_turn(P._lp(ar, s), P._ld(ar, s), P._lr(ar, s) + 0.006, 0.011, 0.005, wh.darkened(0.05 * float(i % 2)), P._lskin(ar, s))
		K._glove(k, sd, ar, bk, bk.lightened(0.08))


# ------------------------------------------------------------------ Uchiha Ryokō (ref "Sasuke Outfit"): mavimsi gri kısa kollu gömlek (huni gibi açılan yüksek yaka, yakadan önde sivri uca fermuar,
## sırtta Uchiha yelpazesi), dize inen lacivert bel örtüsü (üstte kıvrılmış kat), kalçada iki tur mor shimenawa ip + sağ önde dize sarkan iki ilmek,
## lacivert bileklik, koyu lacivert bol pantolon, siyah diz çizmesi
static func _sasuke(k) -> void:
	var sh := Color(0.604, 0.604, 0.722)
	var nv := Color(0.141, 0.165, 0.384)
	var pn := Color(0.1, 0.11, 0.2)
	var rp := Color(0.56, 0.45, 0.82)
	var bk := Color(0.094, 0.094, 0.11)
	var zp := Color(0.82, 0.82, 0.86)
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
	var nsk := func(p): return Q._nsk(k, p)
	K._seat(k, b, pn)
	# pantolon + çizme
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.6 if sd == "Left" else 1.9
		Q._baggy(k, le, pn, pn.darkened(0.1), 0.01, 0.016, kn + 0.1, sv)
		var s0: float = kn + 0.05
		P._lt(k, le, func(s, a): return 0.012 + 0.006 * smoothstep(s0 + 0.07, s0, float(s)) + 0.0015 * sin(float(a) * 3.0 + float(s) * 20.0) * smoothstep(0.92, 0.8, float(s)),
			func(s, a, ins): return bk.lightened(0.05) if ins else bk.lightened(0.06 * maxf(0.0, cos(float(a))) * float(float(s) > s0 + 0.02)), s0, 0.99, 18, 20, 0.02)
		P._lt(k, le, func(_s, _a): return 0.0195, func(_s, _a, ins): return bk.darkened(0.2) if ins else bk.lightened(0.03), s0, s0 + 0.018, 2, 20)
	# bel örtüsü: belden dize, sarılı; önde sol yanda bindirme kenarı
	var hem: float = KN + 0.005
	var y0: float = H + 0.1
	var sk := [P._kp(wa, y0, 0.018), P._kp(k.M(H + 0.03, 0.3), H + 0.03, 0.03), P._kp(hp, H - 0.04, 0.04), [H - 0.14, hp.x + 0.064, hp.y + 0.06, hp.z - 0.078], [hem, hp.x + 0.075, hp.y + 0.064, hp.z - 0.09]]
	var fam := func(p): return T._bsk(k, p, hem - 0.03)
	var sf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.026 * sin(a * 6.0 + 0.4) + 0.012 * sin(a * 11.0 + 1.7)) + 0.004 * sin(a * 9.0 + y * 20.0) + 0.012 * smoothstep(0.5, 0.56, a) * (1.0 - smoothstep(1.4, 2.0, a))
	var hemf := func(a: float) -> float: return hem + 0.03 * sin(a + 0.4) + 0.012 * sin(a * 3.0 + 1.0)
	var sg0: Dictionary = P._cl(k, {"keys": sk, "ny": 36, "na": 112, "top": func(_a): return y0, "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return sf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return nv, "gain": 6.0, "th": 0.007, "inner": nv.darkened(0.4), "skin": fam})
	P._bd(k, AA._yl(sg0["hem"], 0.008), 0.004, 0.0018, nv.darkened(0.2), true, fam)
	Q._run(k, sk, sf, [Vector2(0.55, y0 - 0.03), Vector2(0.56, H - 0.1), Vector2(0.58, hem + 0.05)], 0.0035, 0.004, 0.0024, nv.lightened(0.05), fam, 12)
	# üstte kıvrılmış kalın kat
	P._sash(k, [P._kp(wa, y0 + 0.02, 0.022), P._kp(k.M(H + 0.03, 0.3), H + 0.03, 0.03)], H + 0.075, 0.028, 0.006, nv.lightened(0.04), 0.18)
	# gömlek: belde, önde sivri uç bel örtüsünün üstüne iner
	var tk := [P._kp(nk, N + 0.01, 0.026), [N - 0.055, ch.x * 1.03, ch.y * 0.97, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.036), P._kp(k.M(H + 0.06, 0.3), H + 0.06, 0.05), P._kp(k.M(H - 0.0, 0.3), H - 0.0, 0.056)]
	var tf := func(a: float, y: float) -> float:
		return smoothstep(0.08, 0.3, absf(a)) * (0.006 * sin(a * 6.0 + y * 15.0) + 0.004 * sin(a * 11.0 - y * 9.0)) + 0.005 * sin(a * 4.0 - y * 24.0) * smoothstep(C - 0.04, N, y)
	var thf := func(a: float) -> float: return H + 0.075 - 0.07 * exp(-pow(a / 0.4, 2.0))
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 32, "na": 92, "top": func(_a): return N + 0.01, "hem": func(a): return thf.call(float(a)), "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return sh, "gain": 6.0, "th": 0.006, "inner": sh.darkened(0.35), "skin": tsk})
	P._bd(k, AA._yl(tg["hem"], 0.008), 0.004, 0.0018, sh.darkened(0.15), true, tsk)
	Q._run(k, tk, tf, [Vector2(0.0, N + 0.0), Vector2(0.0, H + 0.01)], 0.0045, 0.0034, 0.002, sh.darkened(0.12), tsk, 24)
	Q._run(k, tk, tf, [Vector2(0.0, N + 0.0), Vector2(0.0, H + 0.01)], 0.0016, 0.0056, 0.0012, zp, tsk, 24)
	for sg in [1.0, -1.0]:
		Q._run(k, tk, tf, [Vector2(sg * PI * 0.5, C - 0.06), Vector2(sg * PI * 0.5, H + 0.085)], 0.0016, 0.0016, 0.0012, sh.darkened(0.25), tsk, 8)
	# huni yaka: boyun çevresinde yükselir, önde açılır
	var hq: float = Q._hq(k)
	var ck := [[N + 0.105 * hq, nk.x + 0.06, nk.y + 0.064, nk.z - 0.05], [N + 0.07 * hq, nk.x + 0.04, nk.y + 0.046, nk.z - 0.04], [N + 0.03 * hq, nk.x + 0.026, nk.y + 0.032, nk.z - 0.032], [N - 0.02, nk.x + 0.05, nk.y + 0.05, nk.z - 0.05]]
	var gap_f := func(y: float) -> float: return lerpf(0.04, 0.5, smoothstep(N + 0.0, N + 0.1 * hq, y))
	var cr: Array = I._sheet(k, ck, 14, 56, func(y): return Vector2(gap_f.call(y), TAU - float(gap_f.call(y))), func(a, y, _u): return 0.01 * sin(a * 5.0 + y * 16.0),
		func(_a, y, _u, _v, _p): return sh.lightened(0.03).darkened(0.16 * (1.0 - smoothstep(N, N + 0.05, y))), 0.008, 1.0, nsk)
	P._cord(k, cr[0], 0.0055, sh.lightened(0.05), false, nsk)
	var ee: Array = I._edges(cr)
	P._cord(k, ee[0], 0.004, sh.lightened(0.02), false, nsk)
	P._cord(k, ee[1], 0.004, sh.lightened(0.02), false, nsk)
	AG._uchiwa(k, tk, C - 0.065, 0.066, sh.darkened(0.5))
	# kollar: geniş kısa kol, çıplak kol, lacivert bileklik
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.2 if sd == "Left" else 2.7
		Z._arm_bare(k, ar, 0.2)
		var s1 := 0.4
		var sf2 := func(s: float, a: float) -> float: return 0.016 + 0.012 * smoothstep(0.05, s1, s) + 0.004 * P._lf(s, a, sv) * smoothstep(0.1, 0.3, s)
		P._lt(k, ar, sf2, func(s, a, ins): return sh.darkened(0.25) if ins else P._fs(sh, 0.004 * P._lf(float(s), float(a), sv), 14.0), 0.0, s1, 16, 24, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf2.call(float(s), float(a))) - 0.004, sh.darkened(0.3), s1 - 0.1, s1, 5, 24)
		P._lt(k, ar, func(s, a): return float(sf2.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return sh.darkened(0.3) if ins else sh.darkened(0.06), s1 - 0.025, s1 + 0.001, 3, 24)
		P._lt(k, ar, func(s, a): return 0.009 + 0.0012 * sin(float(a) * 14.0) - 0.002 * smoothstep(0.95, 0.94, float(s)) * 0.0, func(_s, a, ins): return nv.darkened(0.45) if ins else nv.darkened(0.2 + 0.08 * float(sin(float(a) * 14.0) < 0.0)), 0.85, 0.95, 6, 28)
	# shimenawa: kalçada iki tur + sağ önde düğüm ve dize sarkan iki ilmek
	var R0 := 0.019
	for e in [[H - 0.02, 0.012], [H - 0.058, -0.008]]:
		_rope_ring(k, sk, sf, float(e[0]), float(e[1]), 0.006, R0, rp, fam)
	var ka: float = -0.5
	var ky: float = H - 0.04
	for e in [[KN + 0.07, 0.2, ka - 0.08, 0.0], [H - 0.22, 0.17, ka + 0.06, 0.6]]:
		var yb: float = e[0]
		var pts := []
		var n := 30
		for i in n:
			var t := TAU * i / n
			var yc: float = (ky + yb) * 0.5
			var ry: float = (ky - yb) * 0.5
			var y: float = yc + ry * cos(t)
			var wv: float = float(e[1]) * sin(t) * (0.35 + 0.65 * smoothstep(ky, yc, y))
			pts.append(Q._spt(sk, sf, float(e[2]) + wv + float(e[3]) * 0.0, y, 0.008 + R0 * 2.0)[0])
		T._twist(k, pts, true, R0 * 0.95, 12.0, rp, fam)
	var kc: Array = Q._spt(sk, sf, ka, ky, 0.03)
	P._tb(k, [(kc[0] as Vector3) - Vector3(0, 0.022, 0), (kc[0] as Vector3), (kc[0] as Vector3) + Vector3(0, 0.022, 0)], func(s, a): return R0 * (1.5 + 0.5 * sin(float(s) * PI)) * (1.0 + 0.15 * cos(3.0 * float(a) + float(s) * 9.0)),
		func(_s, a, _p): return rp.darkened(0.25) if cos(3.0 * float(a)) < -0.4 else rp, func(_s, p): return fam.call(p), 14)


# ------------------------------------------------------------------ Haruno Kunoichi Ni (ref "Sakura Outfit 3"): kolsuz kızıl çin elbisesi (beyaz dik yaka, yakadan sağ koltuk altına kıvrılan beyaz biye,
## sırtta Haruno halkası), belde geniş siyah kuşak + sırtta kese, uyluk ortasına inen etek (beyaz etek biyesi, yanlarda beyaz biyeli yırtmaç ağzı),
## siyah şort, uçuk pembe dirseklik ve dizlik, sağ uylukta beyaz sargı + lacivert kılıf, koyu mor eldiven
static func _haruno(k) -> void:
	var cr := Color(0.5, 0.1, 0.16)
	var wh := Color(0.93, 0.92, 0.9)
	var bk := Color(0.1, 0.1, 0.12)
	var pk := Color(0.86, 0.78, 0.86)
	var gl := Color(0.22, 0.15, 0.28)
	var nvb := Color(0.14, 0.17, 0.32)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var hp: Vector3 = b["hp"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._skin_torso(k, b, C - 0.06)
	# şort + bacaklar
	_lowseat(k, b, H + 0.06, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 1.9
		var s1: float = kn * 0.4
		var ad: Callable = R._short_leg(k, le, bk, s1, 0.01, 0.006, sv)
		R._hem_roll(k, le, ad, s1, bk.lightened(0.05), 0.02, 0.002)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		_pad_on(k, le, kn - 0.1, kn + 0.12, 0.01, pk)
		if sd == "Right":
			_thigh_wrap(k, le, s1 + 0.01, 6, 0.004, wh)
			I._holster(k, le, func(_s, _a): return 0.011, nvb, nvb)
	# üst: kolsuz, omuzları dar örter
	var top: Dictionary = Z._halter(k, b, {"col": cr, "hem": H + 0.08, "cut": C - 0.02, "a0": 0.78, "a1": 1.22, "pad": 0.01, "hang": 0.5, "top": N + 0.004})
	var tk: Array = top["keys"]
	var tff: Callable = top["ff"]
	P._cord(k, top["top"], 0.003, cr.darkened(0.12), true, nsk)
	Z._stand(k, b, 0.044, 0.006, wh)
	Q._run(k, tk, tff, [Vector2(-0.02, N - 0.006), Vector2(-0.3, N - 0.035), Vector2(-0.55, C + 0.0), Vector2(-0.78, C - 0.03)], 0.0055, 0.003, 0.0024, wh, tsk, 8)
	for sg in [1.0, -1.0]:   # göğüs pensleri
		Q._run(k, tk, tff, [Vector2(sg * 0.52, C - 0.02), Vector2(sg * 0.48, C - 0.11)], 0.0014, 0.0014, 0.001, cr.darkened(0.3), tsk, 5)
	R._lstrip(k, AA._back_mp(tk, 0.0, C - 0.07), _ring2(0.044), 0.0075, 0.004, 0.0022, wh, tsk, true)
	# etek: kuşağın altından uyluk ortasına; yanlarda yırtmaç ağzı
	var hem: float = H - 0.17
	var y0: float = H + 0.1
	var wm: Vector3 = k.M(y0, k.UA)
	var ek := [[y0, wm.x + 0.012, wm.y + 0.012, wm.z - 0.012], [H - 0.04, hp.x + 0.03, hp.y + 0.034, hp.z - 0.042], [hem, hp.x + 0.05, hp.y + 0.05, hp.z - 0.062]]
	var esk := func(p): return Y._msk(k, p, hem)
	var notch := func(a: float) -> float: return 0.055 * exp(-pow((absf(a) - PI * 0.5) / 0.12, 2.0))
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.014 * sin(a * 6.0 + 0.5) + 0.006 * sin(a * 11.0 + 1.3)) + 0.003 * sin(a * 9.0 + y * 20.0)
	var eg: Dictionary = P._cl(k, {"keys": ek, "ny": 22, "na": 112, "top": func(_a): return y0, "hem": func(a): return hem + float(notch.call(float(a))), "fold": func(a, y, _v): return ef.call(float(a), float(y)),
		"col": func(_a, _y, _v): return cr, "gain": 6.0, "th": 0.006, "inner": cr.darkened(0.35), "skin": esk})
	P._bd(k, AA._yl(eg["hem"], 0.008), 0.0072, 0.0026, wh, true, esk)
	for sg in [1.0, -1.0]:
		Q._run(k, ek, ef, [Vector2(sg * PI * 0.5, H + 0.06), Vector2(sg * PI * 0.5, hem + 0.06)], 0.0055, 0.0032, 0.0024, wh, esk, 8)
	# geniş siyah kuşak + sırtta kese
	var by: float = H + 0.1
	var ok := [P._kp(k.M(by + 0.05, k.UA), by + 0.05, 0.018), P._kp(k.M(by - 0.05, 0.3), by - 0.05, 0.02)]
	P._sash(k, ok, by, 0.036, 0.004, bk, 0.1)
	X._bag(k, ok, by - 0.004, 0.03, bk.lightened(0.07))
	# kollar: ten, dirseklik, eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		Z._arm_bare(k, ar)
		_pad_on(k, ar, en - 0.12, en + 0.12, 0.008, pk)
		Z._glove_full(k, sd, gl)


# ------------------------------------------------------------------ Uchiha Kunoichi (ref "Sarada Outfit"): kolsuz açık kırmızı uzun üst (yüksek dik yaka, yakadan göğse inip sola kıvrılan beyaz biyeli fermuar,
## belden aşağı önde ve arkada uyluğa inen pahlı paneller, koyu bordo kenar bandı, sırtta Uchiha yelpazesi), lacivert kolluk, uçuk pembe şort,
## diz üstü lacivert çorap, sağ uylukta beyaz sargı + lacivert kılıf
static func _sarada(k) -> void:
	var rd := Color(0.76, 0.17, 0.23)
	var mr := Color(0.44, 0.08, 0.13)
	var pk := Color(0.94, 0.83, 0.85)
	var nv := Color(0.17, 0.16, 0.32)
	var wh := Color(0.93, 0.92, 0.9)
	var nvb := Color(0.13, 0.15, 0.3)
	var zp := Color(0.92, 0.92, 0.94)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._skin_torso(k, b, C - 0.06)
	_lowseat(k, b, H + 0.02, pk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.4 if sd == "Left" else 1.6
		var s1: float = kn * 0.26
		var ad: Callable = R._short_leg(k, le, pk, s1, 0.012, 0.008, sv)
		R._hem_roll(k, le, ad, s1, pk.darkened(0.06), 0.02, 0.002)
		Y._sock_leg(k, le, nv, kn * 0.72, sv, 0.024)
		if sd == "Right":
			_thigh_wrap(k, le, s1 + 0.03, 4, 0.004, wh)
			I._holster(k, le, func(_s, _a): return 0.011, nvb, nvb)
	# üst
	var top: Dictionary = Z._halter(k, b, {"col": rd, "hem": H + 0.04, "cut": C - 0.015, "a0": 0.55, "a1": 1.02, "pad": 0.01, "hang": 0.6, "top": N + 0.004})
	var tk: Array = top["keys"]
	var tff: Callable = top["ff"]
	P._cord(k, top["top"], 0.003, rd.darkened(0.12), true, nsk)
	var zpath := [Vector2(0.0, N + 0.0), Vector2(0.0, C - 0.03), Vector2(0.12, C - 0.09), Vector2(0.36, H + 0.13), Vector2(0.5, H + 0.05)]
	Q._run(k, tk, tff, zpath, 0.0042, 0.003, 0.002, zp, tsk, 8)
	Q._run(k, tk, tff, zpath, 0.0012, 0.0052, 0.001, Color(0.6, 0.6, 0.64), tsk, 8)
	for sg in [1.0, -1.0]:   # göğüs altı pens kıvrımları
		Q._run(k, tk, tff, [Vector2(sg * 1.0, C - 0.02), Vector2(sg * 0.8, C - 0.07), Vector2(sg * 0.66, C - 0.1)], 0.0022, 0.0012, 0.0014, rd.darkened(0.3), tsk, 5)
	X._neck(k, b, rd, 0.062, true)
	var zt: Array = Q._spt(tk, tff, 0.0, N - 0.005, 0.006)
	P._boxr(k, zt[0], Vector3(0.005, 0, 0), Vector3(0, 0.011, 0), (zt[1] as Vector3) * 0.0028, Color(0.75, 0.75, 0.78), [["Neck", 0.4], ["UpperChest", 0.6]], 0.3)
	AG._uchiwa(k, tk, C - 0.07, 0.06, rd.darkened(0.45))
	# paneller: belden uyluğa, önde ve arkada, alt köşeleri pahlı
	var phem: float = H - 0.2
	var pky := [P._kp(k.M(H + 0.08, k.UA), H + 0.08, 0.012), P._kp(k.M(H + 0.02, 0.3), H + 0.02, 0.024), [H - 0.04, hp.x + 0.032, hp.y + 0.036, hp.z - 0.048], [phem, hp.x + 0.04, hp.y + 0.046, hp.z - 0.058]]
	var psk := func(p): return _pnl(k, p, phem)
	var pf := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - phem), 0.0, 1.0)
		return t * 0.008 * sin(a * 5.0 + 0.7) + 0.003 * sin(a * 9.0 + y * 20.0)
	for c0 in [0.0, PI]:
		var wf := func(v: float) -> float: return lerpf(0.98, 0.8, v)
		var pg: Dictionary = P._cl(k, {"keys": pky, "ny": 24, "na": 44, "rng": func(v): return Vector2(c0 - float(wf.call(float(v))), c0 + float(wf.call(float(v)))), "top": func(_a): return H + 0.08,
			"hem": func(a): return phem + 0.07 * smoothstep(0.5, 0.8, absf(wrapf(float(a) - c0, -PI, PI))), "fold": func(a, y, _v): return pf.call(float(a), float(y)),
			"col": func(_a, _y, _v): return rd, "gain": 6.0, "th": 0.005, "inner": rd.darkened(0.3), "skin": psk})
		AA._edge_band(k, pg["ea"], 0.008, 0.0025, mr, psk, 1.0)
		AA._edge_band(k, pg["eb"], 0.008, 0.0025, mr, psk, -1.0)
		P._bd(k, AA._yl(pg["hem"], 0.009), 0.009, 0.0025, mr, false, psk)
	# kollar: ten + lacivert kolluk
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.9 if sd == "Left" else 2.4
		Z._arm_bare(k, ar)
		var en: float = ar["kn"]
		var s0: float = en * 0.62
		P._lt(k, ar, func(s, a): return 0.0045 + 0.0018 * sin(float(a) * 3.0 + float(s) * 28.0 + sv) * exp(-pow((float(s) - en) / 0.07, 2.0)) - 0.0035 * smoothstep(0.95, 0.99, float(s)),
			func(s, a, ins): return nv.darkened(0.3) if ins else nv.darkened(0.12 * maxf(0.0, sin(float(a) * 3.0 + float(s) * 28.0 + sv)) * exp(-pow((float(s) - en) / 0.08, 2.0))), s0, 0.985, 26, 18)
		P._lt(k, ar, func(_s, _a): return 0.0068, func(_s, _a, ins): return nv.darkened(0.3) if ins else nv.lightened(0.05), s0, s0 + 0.03, 3, 18)


# ------------------------------------------------------------------ Uchiha Doresu (ref "Sarada Outfit 2", Indigo rengi; açıklamayla aynı): sarı kolsuz iç üst, üstünde derin V yakalı kolsuz mavi mini elbise,
## kalçada yatık beyaz kemer + önde sarkan beyaz dil, sırtta kahve kese, boynunda düğümlü sarı fular, mor parmaksız eldiven, siyah şort,
## sağ uylukta beyaz sargı + lacivert kılıf, siyah baldır botu + kaval plakası
static func _sarada2(k) -> void:
	var bl := Color(0.32, 0.5, 0.8)
	var yl := Color(0.96, 0.84, 0.3)
	var sc := Color(0.96, 0.9, 0.56)
	var wh := Color(0.92, 0.92, 0.92)
	var pu := Color(0.4, 0.23, 0.52)
	var bk := Color(0.1, 0.1, 0.12)
	var br := Color(0.55, 0.38, 0.24)
	var nvb := Color(0.13, 0.15, 0.3)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._skin_torso(k, b, C - 0.06)
	# sarı iç üst
	var inn: Dictionary = Z._halter(k, b, {"col": yl, "hem": C - 0.06, "cut": C - 0.025, "a0": 0.45, "a1": 0.95, "pad": 0.004, "top": N + 0.02, "hang": 0.4})
	P._cord(k, inn["top"], 0.0025, yl.darkened(0.1), true, nsk)
	# şort + bacaklar + bot
	_lowseat(k, b, H + 0.0, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.0
		var s1: float = kn * 0.3
		var ad: Callable = R._short_leg(k, le, bk, s1, 0.01, 0.006, sv)
		R._hem_roll(k, le, ad, s1, bk.lightened(0.05), 0.02, 0.002)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		var b0: float = kn + 0.17
		P._lt(k, le, func(s, a): return 0.007 + 0.004 * smoothstep(b0 + 0.04, b0, float(s)) + 0.0012 * sin(float(a) * 4.0 + float(s) * 30.0), func(_s, _a, ins): return bk.lightened(0.04) if ins else bk, b0, 0.99, 14, 20, 0.02)
		K._shell(k, le, b0 + 0.03, 0.95, -0.7, 0.7, func(_s, _a): return 0.012, 0.004, func(u, v, ins): return Color(0.2, 0.2, 0.23).darkened(0.3 if ins else 0.12 * float(u < 0.1 or u > 0.9 or v < 0.08)))
		if sd == "Right":
			_thigh_wrap(k, le, s1 + 0.02, 5, 0.004, wh)
			I._holster(k, le, func(_s, _a): return 0.011, nvb, nvb)
	# elbise üstü: kolsuz, derin V
	var dh: float = H + 0.0
	var vy: float = C - 0.085
	var top: Dictionary = Z._halter(k, b, {"col": bl, "hem": dh, "cut": C - 0.02, "a0": 0.5, "a1": 1.0, "pad": 0.011, "hang": 0.6, "top": N + 0.006, "slit": 0.62, "slit_v": (N + 0.006 - vy) / (N + 0.006 - dh)})
	var tk: Array = top["keys"]
	var tff: Callable = top["ff"]
	P._cord(k, top["top"], 0.003, bl.darkened(0.12), false, nsk)
	for e in [top["ea"], top["eb"]]:
		P._cord(k, e, 0.0028, bl.darkened(0.12), false, tsk)
	# etek: belden uyluğa A kesim
	var hem: float = H - 0.16
	var y0: float = H + 0.04
	var wm: Vector3 = k.M(y0, 0.3)
	var ek := [[y0, wm.x + 0.008, wm.y + 0.008, wm.z - 0.008], [H - 0.04, hp.x + 0.024, hp.y + 0.026, hp.z - 0.026], [hem, hp.x + 0.06, hp.y + 0.06, hp.z - 0.062]]
	var esk := func(p): return Y._msk(k, p, hem)
	var ef := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (0.02 * sin(a * 6.0 + 0.3) + 0.008 * sin(a * 11.0 + 1.6)) + 0.003 * sin(a * 9.0 + y * 20.0)
	var eg: Dictionary = P._cl(k, {"keys": ek, "ny": 22, "na": 112, "top": func(_a): return y0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ef.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bl, "gain": 6.0, "th": 0.006, "inner": bl.darkened(0.35), "skin": esk})
	P._bd(k, AA._yl(eg["hem"], 0.008), 0.004, 0.0018, bl.darkened(0.16), true, esk)
	# yatık beyaz kemer + sarkan dil + sırtta kese
	V._belt(k, ek, H - 0.015, 0.016, 0.01, 0.007, wh, 0.0, 96, esk)
	Q._run(k, ek, ef, [Vector2(0.3, H - 0.02), Vector2(0.31, H - 0.07), Vector2(0.32, H - 0.12)], 0.008, 0.009, 0.0022, wh, esk, 8)
	X._bag(k, ek, H - 0.03, 0.03, br)
	# fular: boynu saran sarı bez, solda düğüm, göğse yatan iki uç
	var nr := []
	for i in 36:
		var a := TAU * i / 36.0 - PI
		var q: Vector2 = SE.El.sup(a, nk.x + 0.018, nk.y + 0.02, nk.z - 0.018)
		nr.append(Vector3(q.x, N + 0.008 - 0.012 * cos(a), q.y))
	P._tb(k, nr, func(_s, a): return 0.0085 * (1.0 + 0.2 * sin(float(a) * 2.0)), func(s, _a, _p): return sc.darkened(0.08 * float(sin(float(s) * 40.0) < -0.5)), func(_s, p): return nsk.call(p), 10, true)
	var kp: Array = Q._spt(tk, tff, 0.32, N - 0.012, 0.012)
	var ko: Vector3 = kp[1]
	P._boxr(k, kp[0], Vector3.UP.cross(ko).normalized() * 0.016, Vector3(0, 0.012, 0), ko * 0.009, sc.darkened(0.05), [["Neck", 0.3], ["UpperChest", 0.7]], 0.45)
	for e in [[0.3, 0.52, N - 0.085], [0.34, 0.14, N - 0.09]]:
		var path := [Vector2(float(e[0]), N - 0.02), Vector2(lerpf(float(e[0]), float(e[1]), 0.5), N - 0.05), Vector2(float(e[1]), float(e[2]))]
		for w in [[0.015, 0.006, sc], [0.009, 0.0072, sc.lightened(0.04)], [0.004, 0.0082, sc.lightened(0.07)]]:
			Q._run(k, tk, tff, path, float(w[0]), float(w[1]), 0.0018, w[2], tsk, 6)
	# kollar: ten, mor parmaksız eldiven + bilek kolluğu
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		Z._arm_bare(k, ar)
		P._lt(k, ar, func(s, a): return 0.006 + 0.002 * smoothstep(0.82, 0.78, float(s)) + 0.001 * sin(float(a) * 5.0 + float(s) * 30.0), func(_s, _a, ins): return pu.darkened(0.3) if ins else pu, 0.76, 0.93, 8, 18)
		K._glove(k, sd, ar, pu, pu.darkened(0.1))
