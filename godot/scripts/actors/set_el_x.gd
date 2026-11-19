extends RefCounted
## Elle modellenmiş setler, parti x: ss_soylu_pelerin, ss_kumo_genin, ss_konoha_genin, ss_kiri_genin, ss_suna_genin, ss_iwa_genin. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{hiashi_outfit, hidden_cloud/leaf/mist/sand/stone_outfit}. Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), q (Q) dosyalarından.
## Beş köy genin takımı ortak tulumdan (yüksek boyun, dirsek kırışıklı kol, dizde paylı pantolon, kalçada çanta) türer; yelek, kol / paça bitişi, arma ve aksesuar her köyde kendi ref'inden.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const T = preload("res://scripts/actors/set_el_t.gd")

## ss_soylu_pelerin tarifi (_soylu) hazır ama koşuda temiz değil: kalkan uyluk kimono önünü deliyor, kimono yan / arkada cübbeden taşıyor. Bu yüzden DONE dışında.
const DONE := ["ss_kumo_genin", "ss_konoha_genin", "ss_kiri_genin", "ss_suna_genin", "ss_iwa_genin"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_kumo_genin": _kumo(k)
		"ss_konoha_genin": _konoha(k)
		"ss_suna_genin": _suna(k)
		"ss_kiri_genin": _kiri(k)
		"ss_iwa_genin": _iwa(k)
		"ss_soylu_pelerin": _soylu(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ortak yardımcılar
static func _skc(k) -> Color:
	var c = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	return c if c is Color else Color(0.9, 0.72, 0.58)


static func _llen(l: Dictionary) -> float:
	return ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()


## Kısa bez / etek ağırlığı: iki bacak arasında geniş geçiş (ortadan yırtılmaz), uçta ağırlık düşer (koşuda sivri kanat açmaz)
static func _xsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.07, p.z)
	var w: float = lerpf(0.86 * pow(minf(1.0, t / 0.6), 0.6), 0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.8)), bk) * lerpf(1.0, 0.84, smoothstep(0.6, 1.0, t))
	var s: float = smoothstep(-0.1, 0.1, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Uzuv yüzeyinde (s, a) yolu boyunca kabartma çubuk / dikiş
static func _ll(k, l: Dictionary, ctrl: Array, liftf: Callable, hw: float, d: float, col: Color, steps := 6) -> void:
	var pts := []
	var ou := []
	var ss := []
	for q in P._path(ctrl, steps):
		var e: Array = Q._ls(l, q.x, q.y, float(liftf.call(q.x, q.y)))
		pts.append(e[0])
		ou.append(e[1])
		ss.append(q.x)
	var sm: float = (float(ss[0]) + float(ss[ss.size() - 1])) * 0.5
	k.strip(pts, ou, hw, d, col, false, func(_p): return P._lskin(l, sm))


## Uzvu saran eğik bant: önde ve arkada çaprazlaşan çift için tilt işareti ters verilir. ad(s, a): altındaki kumaşın kabarması
static func _xband(k, l: Dictionary, ad: Callable, s: float, tilt: float, hw: float, col: Color) -> void:
	var L := _llen(l)
	var rows := []
	for j in 5:
		var v := float(j) / 4.0
		var ro := []
		for i in 36:
			var a := TAU * i / 36.0 - PI
			var s2: float = s + (tilt * sin(a) + lerpf(-hw, hw, v)) / L
			ro.append(Q._ls(l, s2, a, float(ad.call(s2, a)) + 0.0008 + 0.0042 * sin(v * PI))[0])
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.16) if j in [0, 4] else col, func(_i, _j, _p): return P._lskin(l, s))


## Uzvu kısmen saran sert plaka; üst kenar açıya göre (s0f(a)): sivri dizlik, kalkan
static func _lplate(k, l: Dictionary, a0: float, a1: float, s0f: Callable, s1: float, addf: Callable, th: float, col: Color, ns := 10, na := 14) -> void:
	var rows := []
	var cc := []
	var sr := []
	for j in ns + 3:
		var e: int = clampi(j - 1, 0, ns)
		var v := float(e) / ns
		var cap: bool = j == 0 or j == ns + 2
		var ro := []
		var cr := []
		var sq := []
		for side in 2:
			for i in na + 1:
				var u := float(i) / na if side == 0 else 1.0 - float(i) / na
				var a := lerpf(a0, a1, u)
				var s: float = lerpf(float(s0f.call(a)), s1, v)
				var edge := minf(u, 1.0 - u) * (a1 - a0)
				var h: float = 0.0 if side == 1 or cap else th * lerpf(0.35, 1.0, smoothstep(0.0, 0.16, edge))
				ro.append(Q._ls(l, s, a, float(addf.call(s, a)) + h)[0])
				var rim: bool = edge < 0.06 or v < 0.08 or v > 0.92
				cr.append(col.darkened(0.42) if side == 1 or cap else (col.darkened(0.16) if rim else col))
				sq.append(s)
		rows.append(ro)
		cc.append(cr)
		sr.append(sq)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(i, j, _p): return P._lskin(l, sr[j][i]))


## Tulum kolu: dirsekte kırışık, s1'de biter (ağzı içe döner)
static func _sleeve(k, ar: Dictionary, col: Color, s1: float, sv: float, add0 := 0.009, s0 := 0.0) -> Callable:
	var en: float = ar["kn"]
	var sl := func(s: float, a: float) -> float:
		var e := exp(-pow((s - en) / 0.085, 2.0))
		return add0 + 0.0065 * e * sin(a * 3.0 + s * 31.0 + sv) + 0.003 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI)
	P._lt(k, ar, sl, func(s, a, ins): return col.darkened(0.42) if ins else P._fs(col, float(sl.call(s, a)) - add0, 30.0), s0, s1, 32, 18, 0.03)
	return sl


## Kıvrılmış kol / paça rulosu: kumaş kalın halka olarak toplanır, boğumları koyulaşır
static func _roll(k, l: Dictionary, s0: float, s1: float, base: Callable, R: float, col: Color, sv: float) -> void:
	var rf := func(s: float, a: float) -> float:
		var t: float = clampf(inverse_lerp(s0, s1, s), 0.0, 1.0)
		return float(base.call(s, a)) + R * pow(sin(t * PI), 0.7) * (1.0 + 0.16 * sin(a * 4.0 + sv)) + 0.002
	P._lt(k, l, rf, func(s, a, ins):
		if ins:
			return col.darkened(0.42)
		var t: float = clampf(inverse_lerp(s0, s1, float(s)), 0.0, 1.0)
		return col.darkened(0.2 * (1.0 - sin(t * PI)) + 0.1 * float(sin(float(a) * 4.0 + sv) < -0.5)), s0, s1, 8, 20)


## Boyun: yüksek dik boğaz (zip: önde fermuar ağzı)
static func _neck(k, b: Dictionary, col: Color, h: float, zip: bool, roll := 0.0) -> Dictionary:
	var N: float = k.N
	var nk: Vector3 = b["nk"]
	var hq: float = Q._hq(k)
	var ck := [P._kp(nk, N + h * hq, 0.012, 0.014), P._kp(nk, N + h * hq * 0.5, 0.015), P._kp(nk, N - 0.0, 0.018), P._kp(nk, N - 0.04, 0.034)]
	var o := {"keys": ck, "ny": 10, "na": 44, "top": func(_a): return N + h * hq, "hem": func(_a): return N - 0.04, "fold": func(a, y, _v): return 0.006 * sin(float(a) * 5.0 + float(y) * 30.0) + roll * sin((float(y) - N) * 90.0),
		"col": func(_a, _y, v): return col.lightened(0.04) if float(v) < 0.15 else col, "skin": func(p): return Q._nsk(k, p), "th": 0.005, "gain": 8.0}
	if zip:
		o["rng"] = func(_v): return Vector2(0.05, TAU - 0.05)
	var cg: Dictionary = P._cl(k, o)
	P._cord(k, cg["top"], 0.0045, col.lightened(0.03), not zip, func(p): return Q._nsk(k, p))
	return cg


## Kalçadaki alet çantası: gövde + kapak + kayış ilmeği (kalça kemiğinde)
static func _bag(k, keys: Array, y: float, lift: float, col: Color) -> void:
	var e: Array = P._fp(keys, 0.0, y, false, lift)
	var c0: Vector3 = e[0]
	var bo := [["Hips", 1.0]]
	P._boxr(k, c0, Vector3(0.072, 0, 0), Vector3(0, 0.036, 0), Vector3(0, 0, -0.025), col, bo, 0.28)
	P._boxr(k, c0 + Vector3(0, 0.027, -0.011), Vector3(0.076, 0, 0), Vector3(0, 0.015, 0), Vector3(0, 0, -0.025), col.lightened(0.07), bo, 0.3)
	for sx in [-0.045, 0.045]:
		P._boxr(k, c0 + Vector3(sx, 0.006, -0.026), Vector3(0.008, 0, 0), Vector3(0, 0.03, 0), Vector3(0, 0, -0.003), col.darkened(0.18), bo, 0.35)
	P._stud(k, c0 + Vector3(0, 0.018, -0.037), Vector3(0, 0, -1), 0.0055, col.darkened(0.3), bo)


# ------------------------------------------------------------------ Kumo genin (ref Hidden Cloud Outfit): lacivert fermuarlı yüksek boyunlu tulum, tek omuzdan kayışla asılan verev beyaz göğüslük (gri biye, dikişler,
## dört çizgi), kalçaya sarılı verev bez, diz üstünde çapraz beyaz kayışlar, sivri dizlikli kızıl çubuklu beyaz kaval
static func _kumo(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var wh := Color(0.9, 0.9, 0.885)
	var gr := Color(0.6, 0.61, 0.65)
	var rd := Color(0.58, 0.1, 0.14)
	var bg := Color(0.42, 0.31, 0.21)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	P._inner(k, b, func(_i, j, _p): return nv.lightened(0.04) if j < 3 else nv, 0.008)
	K._seat(k, b, nv.darkened(0.1))
	_neck(k, b, nv, 0.075, true)
	# fermuar: boğazdan göğüslüğün altına
	var ik := [P._kp(b["nk"], N + 0.02, 0.016), [N - 0.05, ch.x * 0.82, ch.y * 0.8 + 0.008, ch.z * 0.9], P._kp(ch, C - 0.03, 0.012)]
	P._strap(k, ik, [Vector2(0.0, N + 0.012), Vector2(0.0, C - 0.02)], true, 0.0032, 0.0035, 0.0018, Color(0.78, 0.79, 0.8), 10)
	var zp: Array = P._fp(ik, 0.0, N + 0.0, true, 0.006)
	P._boxr(k, zp[0], Vector3(0.0045, 0, 0), Vector3(0, 0.012, 0), (zp[1] as Vector3) * 0.003, Color(0.74, 0.75, 0.76), k.torso_skin(N))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.3 if sd == "Left" else 2.6
		var kn: float = le["kn"]
		var sl := _sleeve(k, ar, nv, 0.92, sv)
		k.wrap_turn(P._lp(ar, 0.9), P._ld(ar, 0.9), P._lr(ar, 0.9) + float(sl.call(0.9, 0.0)) + 0.003, 0.012, 0.0, nv.darkened(0.12), P._lskin(ar, 0.9))
		var pa: Callable = K._pant(k, le, nv, 0.012, 0.024, 1.0, sv)
		# diz üstü çapraz kayışlar
		_xband(k, le, pa, kn - 0.075, 0.03, 0.011, wh)
		_xband(k, le, func(s, a): return float(pa.call(s, a)) + 0.0045, kn - 0.075, -0.03, 0.011, wh.darkened(0.04))
		# kaval: beyaz kılıf, önde üç kızıl çubuk, bilekte beyaz manşet
		var ga := func(s: float, a: float) -> float: return float(pa.call(s, a)) + 0.007 + 0.006 * pow(maxf(0.0, cos(a)), 4.0)
		J._lta(k, le, ga, func(s, a, ins):
			if ins:
				return wh.darkened(0.45)
			return wh.darkened(0.12 * smoothstep(0.2, -0.7, cos(float(a)))), func(a): return kn + 0.12 - 0.025 * pow(maxf(0.0, cos(float(a))), 2.0), 0.935, 24, 22)
		for ax in [-0.4, 0.0, 0.4]:
			_ll(k, le, [Vector2(kn + 0.16, ax), Vector2(0.89, ax)], func(s, a): return float(ga.call(s, a)) + 0.001, 0.0085, 0.0034, rd, 8)
		_lt_ring(k, le, ga, 0.945, 0.025, wh, 0.006)
		# sivri dizlik: kavalın üstüne biner
		_lplate(k, le, -1.15, 1.15, func(a): return kn - 0.035 + 0.06 * pow(absf(float(a)) / 1.15, 1.3), kn + 0.14, func(s, a): return float(ga.call(s, a)) + 0.004, 0.009, wh.lightened(0.02), 10, 16)
	# kalçaya sarılı verev bez: sağ kalçada kısa, sol uyluğa iner; üstüne binen kanadın verev kenarı
	var hk := [P._kp(wa, H + 0.07, 0.016), P._kp(hp, H - 0.04, 0.036), [H - 0.18, hp.x + 0.066, hp.y + 0.062, hp.z - 0.066], [H - 0.3, hp.x + 0.078, hp.y + 0.072, hp.z - 0.078]]
	var dhem := func(a: float) -> float: return H - 0.085 - 0.14 * smoothstep(-0.5, 0.95, sin(a))
	var dsk := func(p): return _xsk(k, p, H - 0.23)
	var df := func(a, y, v) -> float: return float(v) * (0.022 * sin(float(a) * 7.0 + 0.5) + 0.011 * sin(float(a) * 13.0 + 1.7))
	P._cl(k, {"keys": hk, "ny": 14, "na": 84, "top": func(_a): return H + 0.065, "hem": func(a): return float(dhem.call(float(a))), "fold": df,
		"col": func(_a, _y, _v): return nv.lightened(0.02), "gain": 7.0, "th": 0.005, "skin": dsk})
	var fl: Dictionary = P._cl(k, {"keys": hk, "ny": 14, "na": 60, "rng": func(v): return Vector2(lerpf(-1.3, 0.62, float(v)), 2.35), "top": func(_a): return H + 0.065,
		"hem": func(a): return float(dhem.call(float(a))) - 0.006, "fold": df, "lift": 0.007, "col": func(_a, _y, _v): return nv.lightened(0.06), "gain": 7.0, "th": 0.005, "skin": dsk})
	P._cord(k, fl["ea"], 0.004, nv.lightened(0.1), false, dsk)
	_bag(k, hk, H - 0.045, 0.012 + 0.03, bg)
	# göğüslük: sağ koltuk altından sol omuza verev; sol omuzda kayış + çıtçıt
	var vk := [P._kp(b["nk"], N + 0.012, 0.026), [N - 0.055, ch.x * 0.98, ch.y * 0.95, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.028), P._kp(wa, H + 0.03, 0.034)]
	var top := func(a: float) -> float:
		var t: float = sin(a)
		if t < 0.72:
			return lerpf(C - 0.075, N - 0.035, smoothstep(-1.0, 0.72, t))
		return lerpf(N - 0.035, C - 0.045, smoothstep(0.72, 1.0, t))
	var vf := func(a, y, _v) -> float: return 0.004 * sin(float(a) * 4.0 + float(y) * 9.0)
	var cg: Dictionary = P._cl(k, {"keys": vk, "ny": 30, "na": 96, "top": func(a): return float(top.call(float(a))), "hem": func(_a): return H + 0.045, "fold": vf,
		"col": func(_a, _y, v): return wh.darkened(0.2) if float(v) > 0.97 else wh, "gain": 6.0, "th": 0.006, "inner": wh.darkened(0.35), "skin": func(p): return k.torso_skin(p.y)})
	var tsk := func(p): return k.torso_skin(p.y)
	P._cord(k, cg["top"], 0.0058, gr, true, tsk)
	P._cord(k, cg["hem"], 0.0085, gr, true, tsk)
	# dikişler (gri biye) ve Kumo'nun dört çizgisi
	P._line(k, vk, [Vector2(0.06, float(top.call(0.06)) - 0.006), Vector2(0.7, C - 0.07), Vector2(1.3, H + 0.13)], 0.0034, 0.0018, 0.0024, gr, 8)
	P._line(k, vk, [Vector2(0.86, C - 0.035), Vector2(0.3, H + 0.15), Vector2(-0.22, H + 0.052)], 0.0034, 0.0018, 0.0024, gr, 8)
	P._line(k, vk, [Vector2(PI - 0.25, float(top.call(PI - 0.25)) - 0.006), Vector2(PI - 1.1, H + 0.1)], 0.0034, 0.0018, 0.0024, gr, 8)
	for i in 4:
		var a: float = -0.02 + 0.12 * float(i)
		var yt: float = float(top.call(a)) - 0.014
		P._line(k, vk, [Vector2(a, yt), Vector2(a - 0.02, yt - 0.042)], 0.0036, 0.0018, 0.0024, gr, 4)
	var sx: float = ch.x * 0.58
	P._over(k, vk, sx, N - 0.05, N - 0.07, 0.022, 0.006, 0.006, wh.lightened(0.02))
	var sn: Array = P._fp(vk, sx, N - 0.035, true, 0.013)
	P._stud(k, sn[0], ((sn[1] as Vector3) + Vector3.UP * 0.6).normalized(), 0.0085, gr.darkened(0.15), k.torso_skin(N - 0.035))


## Uzvu saran düz manşet halkası (kumaşın gerçek yüzeyinde)
static func _lt_ring(k, l: Dictionary, ad: Callable, s: float, w: float, col: Color, bulge: float) -> void:
	var L := _llen(l)
	var s0: float = s - w / L * 0.5
	var s1: float = s + w / L * 0.5
	P._lt(k, l, func(s2, a): return float(ad.call(s2, a)) + bulge * sin(clampf(inverse_lerp(s0, s1, float(s2)), 0.0, 1.0) * PI) + 0.0015, func(_s, a, ins):
		return col.darkened(0.42) if ins else col.darkened(0.08 if sin(float(a) * 2.0) < -0.6 else 0.0), s0, s1, 5, 22)


# ------------------------------------------------------------------ Konoha genin (ref Hidden Leaf Outfit): lacivert yüksek boyunlu tulum, ön kolda kıvrık kol, baldırda kıvrık paça + beyaz sargı, açık yeşil yelek
## (iki parçalı dik yaka, çıtçıtlı omuz yastıkları, üç bantlı parşömen cepleri, ortadan ayrılan alt rulo, sırtta kızıl Uzumaki girdabı), sağ uylukta kara kese + iki beyaz bant
static func _konoha(k) -> void:
	var nv := Color(0.118, 0.165, 0.282)
	var ve := Color(0.43, 0.6, 0.52)
	var rd := Color(0.7, 0.16, 0.13)
	var wh := Color(0.89, 0.89, 0.87)
	var bk := Color(0.1, 0.11, 0.14)
	var bg := Color(0.45, 0.33, 0.22)
	var skc := _skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return nv.lightened(0.04) if j < 3 else nv, 0.008)
	K._seat(k, b, nv.darkened(0.1))
	_neck(k, b, nv, 0.07, false, 0.0025)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.1 if sd == "Left" else 2.4
		var kn: float = le["kn"]
		# kol: ön kolun ortasına kadar sıvanmış kalın rulo, altı çıplak
		var sl := _sleeve(k, ar, nv, 0.82, sv, 0.01)
		P._bare(k, ar, skc, 0.78, 1.0)
		_roll(k, ar, 0.765, 0.84, sl, 0.012, nv.lightened(0.04), sv)
		# paça: baldır ortasında kıvrık, altı beyaz sargı
		var pc: float = kn + 0.27
		var pa: Callable = K._pant(k, le, nv, 0.012, 0.028, pc + 0.02, sv)
		P._bare(k, le, skc, pc - 0.04, 1.0)
		_roll(k, le, pc - 0.035, pc + 0.04, pa, 0.014, nv.lightened(0.04), sv)
		J._shin_tape(k, le, func(_s, _a): return 0.003, pc + 0.03, 9, wh)
		if sd == "Right":
			J._holster(k, le, pa, wh, bk)
	# yelek gövdesi
	var hem: float = H + 0.03
	var vk := [P._kp(nk, N + 0.006, 0.032), [N - 0.055, ch.x * 0.96, ch.y * 0.95, ch.z * 1.05], [N - 0.13, ch.x * 1.02, ch.y * 1.02, ch.z * 1.07], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.04), P._kp(wa, hem, 0.046)]
	var quilt := func(a: float, y: float, _u: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		var g: float = -0.024 * exp(-pow(aa / 0.022, 2.0)) * smoothstep(N - 0.02, N - 0.06, y) - 0.012 * exp(-pow((aa - 1.7) / 0.05, 2.0))
		return g + 0.007 * sin(a * 5.0 + y * 9.0) * smoothstep(C + 0.05, C - 0.1, y)
	P._sheet(k, vk, 40, 92, Callable(), quilt, func(a, y, _u, v, _p): return P._fs(ve, float(quilt.call(a, y, 0.0)), 6.5).darkened(0.2 if v > 0.97 else 0.0), 0.008, 0.18, func(p): return k.torso_skin(p.y))
	var tsk := func(p): return k.torso_skin(p.y)
	# alt rulo: önde fermuarla ikiye ayrılır
	var ring: Array = P._ring_pts(vk, hem + 0.01, 0.01, 92)
	var half := []
	for i in 92:
		var a: float = TAU * i / 92.0 - PI
		if absf(a) > 0.05:
			half.append(ring[i])
	var hr: Array = half.slice(half.size() / 2) + half.slice(0, half.size() / 2)
	P._tb(k, hr, func(s, a): return 0.028 * (0.86 + 0.14 * absf(cos(float(a)))) * pow(clampf(minf(float(s), 1.0 - float(s)) * 40.0, 0.25, 1.0), 0.5), func(_s, a, _p):
		return ve.darkened(0.04 if cos(float(a)) > -0.3 else 0.22), func(_s, p): return k.torso_skin(p.y), 12, false)
	# iki parçalı dik yaka (yanlarda yükselir, önü açık)
	J._collar(k, [P._kp(nk, N + 0.085 * Q._hq(k), 0.034, 0.044), P._kp(nk, N + 0.045, 0.032, 0.04), P._kp(nk, N - 0.02, 0.052, 0.052)], 0.86, 0.34, ve, ve.lightened(0.08))
	var cc := Vector3(0.0, C, 0.0)
	# omuz yastıkları + çıtçıt
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.74, 2.3, float(v))
			var y: float = lerpf(N - 0.014, N - 0.082, float(u))
			return P._sa(vk, a, y, 0.0)[0]
		J._pil(k, surf, 12, 14, 0.013, ve.lightened(0.05), cc, 0.16, tsk)
		var e: Vector3 = surf.call(0.62, 0.2)
		var o: Vector3 = J._nrm(surf, 0.62, 0.2, cc)
		P._fan(k, e + o * 0.015, o, Vector3.UP, 0.0095, Callable(), func(u2, v2): return ve.darkened(0.42) if sqrt(u2 * u2 + v2 * v2) > 0.7 else Color(0.86, 0.87, 0.86), k.torso_skin(N - 0.04), 3, 14)
		# göğüs cebi: dik parşömen bölmeleri + üstten geçen bant ve üç küçük toka
		var px: float = sg * ch.x * 0.5
		var py: float = C - 0.06
		J._pouch(k, vk, px, py, ch.x * 0.54, 0.12, 3, ve.darkened(0.05), ve.lightened(0.12), sg * -0.01)
		for t in [-0.32, 0.0, 0.32]:
			var e2: Array = P._fp(vk, px + t * ch.x * 0.54, py - 0.12 * 0.06, true, 0.0215)
			P._boxr(k, e2[0], Vector3(0.0085, 0, 0), Vector3(0, 0.0055, 0), (e2[1] as Vector3) * 0.0025, ve.lightened(0.2), k.torso_skin(py), 0.35)
	# fermuar
	P._strap(k, vk, [Vector2(0.0, N - 0.06), Vector2(0.0, hem - 0.004)], true, 0.0058, 0.0012, 0.0022, ve.darkened(0.3), 26)
	P._strap(k, vk, [Vector2(0.0, N - 0.06), Vector2(0.0, hem - 0.004)], true, 0.0024, 0.0034, 0.0022, Color(0.86, 0.87, 0.86), 26)
	# sırtta Uzumaki girdabı
	J._swirl(k, vk, 0.0, C - 0.075, 0.078, rd, false)
	var hk := [P._kp(hp, H + 0.02, 0.018), P._kp(hp, H - 0.1, 0.018)]
	_bag(k, hk, H - 0.05, 0.03, bg)


# ------------------------------------------------------------------ Suna genin (ref Hidden Sand Outfit): kara-kahve yüksek boyunlu tulum, ön kola itilip büzülmüş kol, baldır ortasında düz kesik paça + beyaz sargı,
## kahve yelek (omzu örtüp dışa kıvrılan yuvarlak omuzluk + üstünde gri yama, uzun yan yaka parçaları, belde iki bölmeli üç çizgili cepler, ortadan ayrılan alt rulo), sağ uylukta kara kese, kalçada soluk yeşil çanta
static func _suna(k) -> void:
	var sh := Color(0.165, 0.141, 0.125)
	var ve := Color(0.4, 0.36, 0.3)
	var gp := Color(0.74, 0.76, 0.78)
	var wh := Color(0.89, 0.89, 0.87)
	var bk := Color(0.09, 0.09, 0.1)
	var bg := Color(0.6, 0.66, 0.52)
	var skc := _skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var UA: float = k.UA
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return sh.lightened(0.04) if j < 3 else sh, 0.008)
	K._seat(k, b, sh.darkened(0.1))
	_neck(k, b, sh, 0.08, false, 0.003)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 2.0 if sd == "Left" else 0.6
		var kn: float = le["kn"]
		var en: float = ar["kn"]
		# kol: ön kola itilmiş, dirsek altında büzgü kat kat toplanır
		var sl := func(s: float, a: float) -> float:
			var bun: float = smoothstep(en + 0.02, 0.74, s) * (1.0 - smoothstep(0.78, 0.82, s))
			return 0.011 + 0.006 * bun + (0.004 + 0.007 * bun) * sin(s * 95.0 + sin(a * 2.0 + sv) * 1.6) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 31.0 + sv) + 0.0028 * P._lf(s, a, sv)
		P._lt(k, ar, sl, func(s, a, ins): return sh.darkened(0.4) if ins else P._fs(sh, float(sl.call(s, a)) - 0.012, 24.0), 0.0, 0.8, 40, 18, 0.025)
		P._bare(k, ar, skc, 0.74, 1.0)
		# paça: baldır ortasında düz kesik, kalın kenar; altı sargılı
		var pc: float = kn + 0.3
		var pa: Callable = K._pant(k, le, sh, 0.013, 0.026, pc, sv)
		_lt_ring(k, le, pa, pc - 0.012, 0.022, sh.lightened(0.03), 0.003)
		P._bare(k, le, skc, pc - 0.05, 1.0)
		J._shin_tape(k, le, func(_s, _a): return 0.003, pc + 0.01, 10, wh)
		if sd == "Right":
			J._holster(k, le, pa, wh, bk)
	# yelek gövdesi
	var hem: float = H + 0.035
	var vk := [P._kp(nk, N + 0.006, 0.032), [N - 0.055, ch.x * 0.96, ch.y * 0.95, ch.z * 1.05], [N - 0.13, ch.x * 1.02, ch.y * 1.02, ch.z * 1.07], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.042), P._kp(wa, hem, 0.048)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return -0.022 * exp(-pow(aa / 0.022, 2.0)) - 0.012 * exp(-pow((aa - 1.65) / 0.05, 2.0)) + 0.006 * sin(a * 6.0 - y * 12.0) * smoothstep(C + 0.06, C - 0.1, y)
	P._sheet(k, vk, 40, 92, Callable(), fold, func(a, y, _u, v, _p):
		var c0: Color = P._fs(ve, float(fold.call(a, y, 0.0)), 6.5)
		var n: float = 0.04 * sin(a * 23.0 + y * 61.0) * sin(a * 7.0 - y * 37.0)   # yıpranmış deri lekesi
		return c0.darkened(maxf(0.0, n) + (0.2 if v > 0.97 else 0.0)), 0.008, 0.18, func(p): return k.torso_skin(p.y))
	var tsk := func(p): return k.torso_skin(p.y)
	var ring: Array = P._ring_pts(vk, hem + 0.01, 0.01, 92)
	var half := []
	for i in 92:
		var a: float = TAU * i / 92.0 - PI
		if absf(a) > 0.05:
			half.append(ring[i])
	var hr: Array = half.slice(half.size() / 2) + half.slice(0, half.size() / 2)
	P._tb(k, hr, func(s, a): return 0.026 * (0.86 + 0.14 * absf(cos(float(a)))) * pow(clampf(minf(float(s), 1.0 - float(s)) * 40.0, 0.25, 1.0), 0.5), func(_s, a, _p):
		return ve.darkened(0.04 if cos(float(a)) > -0.3 else 0.22), func(_s, p): return k.torso_skin(p.y), 12, false)
	# uzun yan yaka parçaları
	J._collar(k, [P._kp(nk, N + 0.1 * Q._hq(k), 0.04, 0.05), P._kp(nk, N + 0.05, 0.036, 0.046), P._kp(nk, N - 0.02, 0.058, 0.058)], 1.05, 0.46, ve.darkened(0.06), ve.lightened(0.05))
	var cc := Vector3(0.0, C, 0.0)
	# omuzluk: omzu örter, kolun üstüne doğru kıvrılır; üstünde gri yama
	var zc: float = (ch.y + ch.z) * 0.5
	for sd in ["Left", "Right"]:
		var sg: float = 1.0 if sd == "Left" else -1.0
		var S: Vector3 = k.m._bp(sd + "UpperArm")
		var surf := func(u, v) -> Vector3:
			var uu := float(u)
			var q := float(v) * 2.0 - 1.0
			var hw: float = 0.1 * (1.0 - 0.3 * uu * uu) + 0.004
			var y: float = lerpf(N - 0.004, S.y + 0.012, pow(uu, 1.25)) - 0.034 * q * q * (0.5 + 0.5 * uu) - 0.03 * pow(uu, 4.0) + 0.012 * sin(uu * PI)
			return Vector3(sg * lerpf(nk.x + 0.03, UA + 0.085, uu), y, zc + 0.008 + q * hw)
		var sk: Callable = J._ssk(k, sd, ch.x * 0.72, UA + 0.1, 0.34)
		J._slab(k, surf, 20, 12, 0.014, 0.013, ve.darkened(0.03), cc + Vector3(0, -0.15, 0), sk, func(u, v):
			return ve.darkened(0.04).darkened(0.24 if absf(float(v) - 0.5) > 0.43 or float(u) > 0.96 else 0.0))
		J._pil(k, func(u, v):
			var p: Vector3 = surf.call(lerpf(0.2, 0.48, float(u)), lerpf(0.34, 0.6, float(v)))
			return p + Vector3(0, 0.011 + 0.008 * sin(lerpf(0.2, 0.48, float(u)) * PI), 0), 6, 5, 0.006, gp, cc + Vector3(0, -0.15, 0), 0.2, sk)
		# bel cepleri: iki dik bölme, üstünde üç çizgi
		var px: float = sg * ch.x * 0.47
		var py: float = H + 0.13
		J._pouch(k, vk, px, py, ch.x * 0.5, 0.115, 2, ve.darkened(0.04), ve.darkened(0.25))
		for i in 3:
			var y2: float = py + 0.006 - float(i) * 0.011
			for t in [-0.25, 0.25]:
				var xx: float = px + t * ch.x * 0.5
				P._strap(k, vk, [Vector2(xx - 0.016, y2), Vector2(xx + 0.016, y2)], true, 0.0028, 0.0255, 0.0022, ve.darkened(0.3), 4, tsk)
	# fermuar
	P._strap(k, vk, [Vector2(0.0, N - 0.06), Vector2(0.0, hem - 0.004)], true, 0.0056, 0.0012, 0.0022, ve.darkened(0.3), 26)
	P._strap(k, vk, [Vector2(0.0, N - 0.06), Vector2(0.0, hem - 0.004)], true, 0.0024, 0.0034, 0.0022, Color(0.85, 0.86, 0.86), 26)
	# sırt: dikişli üst panel
	J._pil(k, func(u, v): return P._fp(vk, lerpf(-ch.x * 0.7, ch.x * 0.7, float(u)), lerpf(C + 0.02, H + 0.16, float(v)), false, 0.0)[0], 14, 12, 0.006, ve.lightened(0.02), cc, 0.08, tsk)
	var hk := [P._kp(hp, H + 0.02, 0.018), P._kp(hp, H - 0.1, 0.018)]
	_bag(k, hk, H - 0.05, 0.03, bg)


# ------------------------------------------------------------------ Kiri genin (ref Hidden Mist Outfit): kahve yüksek boyunlu tulum, dirsekte biten kol, leylak-gri sert zırh (düz göğüs plakası, boyna çıkan iki dikme,
## omuzdan dışa taşan yassı omuzluklar, yan tırnaklar, kalın bel plakası, önde yuvarlak uçlu önlük), dirsekten bileğe ve dizden bileğe çizgili mavi-gri ısıtıcılar, kalçada kahve çanta
static func _kiri(k) -> void:
	var jd := Color(0.173, 0.157, 0.149)
	var ve := Color(0.5, 0.49, 0.6)
	var bd := Color(0.47, 0.58, 0.74)
	var bg := Color(0.4, 0.29, 0.2)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var UA: float = k.UA
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return jd.lightened(0.04) if j < 3 else jd, 0.008)
	K._seat(k, b, jd.darkened(0.1))
	_neck(k, b, jd, 0.085, false, 0.0035)
	var rib := func(a: float, n: float) -> float: return pow(0.5 + 0.5 * cos(a * n), 3.0)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 0.7 if sd == "Left" else 2.9
		var kn: float = le["kn"]
		var en: float = ar["kn"]
		# kol ısıtıcısı (altta), kısa tulum kolu üstte biter
		var wf := func(s: float, a: float) -> float:
			return 0.007 + 0.003 * smoothstep(en, en + 0.1, s) * (1.0 - smoothstep(0.86, 0.95, s)) + 0.0028 * float(rib.call(a, 12.0)) + 0.0015 * sin(s * 60.0 + a * 2.0)
		P._lt(k, ar, wf, func(_s, a, ins): return bd.darkened(0.4) if ins else bd.darkened(0.3 * (1.0 - float(rib.call(float(a), 12.0)))), en - 0.04, 0.955, 28, 36, 0.02)
		_lt_ring(k, ar, wf, 0.945, 0.016, bd.darkened(0.12), 0.002)
		_sleeve(k, ar, jd, en + 0.075, sv, 0.0115, 0.07)
		# pantolon dizin altında ısıtıcıya girer; ısıtıcı bileğe doğru bollaşır
		var pa: Callable = K._pant(k, le, jd, 0.012, 0.026, kn + 0.16, sv)
		var lw := func(s: float, a: float) -> float:
			var t: float = clampf((s - kn) / (1.0 - kn), 0.0, 1.0)
			return float(pa.call(minf(s, kn + 0.12), a)) * (1.0 - t) + 0.006 + 0.012 * smoothstep(0.35, 0.95, t) + 0.0032 * float(rib.call(a, 14.0)) + 0.002 * sin(s * 45.0 + a * 3.0 + sv)
		P._lt(k, le, lw, func(_s, a, ins): return bd.darkened(0.4) if ins else bd.darkened(0.3 * (1.0 - float(rib.call(float(a), 14.0)))), kn + 0.05, 0.975, 30, 42, 0.03)
		_lt_ring(k, le, lw, 0.965, 0.018, bd.darkened(0.15), 0.002)
	# göğüs / sırt plakası: kol altında oyulmuş
	var vk := [P._kp(nk, N + 0.006, 0.03), [N - 0.055, ch.x * 0.96, ch.y * 0.95, ch.z * 1.05], [N - 0.13, ch.x * 1.0, ch.y * 1.02, ch.z * 1.06], P._kp(ch, C - 0.03, 0.042), P._kp(wa, H + 0.12, 0.032), P._kp(wa, H + 0.08, 0.03)]
	var ytop := func(a: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return N - 0.06 - 0.15 * exp(-pow((aa - PI * 0.5) / 0.62, 2.0))
	var tsk := func(p): return k.torso_skin(p.y)
	var pf := func(a, y, _v) -> float: return -0.01 * exp(-pow((absf(float(a)) - PI * 0.5) / 0.08, 2.0)) + 0.002 * sin(float(a) * 9.0 + float(y) * 30.0)
	var cg: Dictionary = P._cl(k, {"keys": vk, "ny": 30, "na": 96, "top": func(a): return float(ytop.call(float(a))), "hem": func(_a): return H + 0.105, "fold": pf,
		"col": func(_a, _y, _v): return ve, "gain": 6.0, "th": 0.008, "inner": ve.darkened(0.4), "skin": tsk})
	P._cord(k, cg["top"], 0.0055, ve.lightened(0.05), true, tsk)
	# bel plakası: kalın, alt ve üst kenarı dönük
	var wk := [P._kp(wa, H + 0.16, 0.044), P._kp(wa, H + 0.06, 0.05)]
	var wg: Dictionary = P._cl(k, {"keys": wk, "ny": 8, "na": 96, "top": func(_a): return H + 0.13, "hem": func(_a): return H + 0.075, "fold": func(_a, _y, v): return 0.012 * sin(float(v) * PI),
		"col": func(_a, _y, v): return ve.darkened(0.06).darkened(0.18 if float(v) > 0.86 else 0.0), "gain": 3.0, "th": 0.01, "inner": ve.darkened(0.4), "skin": tsk})
	P._cord(k, wg["top"], 0.006, ve.lightened(0.04), true, tsk)
	P._cord(k, wg["hem"], 0.006, ve.darkened(0.12), true, tsk)
	var cc := Vector3(0.0, C, 0.0)
	for sd in ["Left", "Right"]:
		var sg: float = 1.0 if sd == "Left" else -1.0
		# boyna çıkan dikme: omuz üstünden önden arkaya kalın yastık
		I._pad(k, vk, sg * (nk.x + 0.045), N - 0.075, N - 0.075, 0.03, 0.016, 0.008, ve.lightened(0.03))
		# yassı omuzluk: omzun üstünde dışa taşan kalın levha, kolla biraz döner
		var S: Vector3 = k.m._bp(sd + "UpperArm")
		var zc: float = (ch.y + ch.z) * 0.5
		var surf := func(u, v) -> Vector3:
			var uu := float(u)
			var q := float(v) * 2.0 - 1.0
			var hw: float = lerpf(0.1, 0.085, uu)
			return Vector3(sg * lerpf(nk.x + 0.06, UA + 0.135, uu), lerpf(N - 0.008, S.y + 0.012, pow(uu, 1.1)) + 0.018 - 0.02 * q * q, zc + q * hw)
		J._slab(k, surf, 14, 10, 0.016, 0.006, ve.lightened(0.02), cc + Vector3(0, -0.15, 0), J._ssk(k, sd, ch.x * 0.75, UA + 0.1, 0.3), func(u, v):
			return ve.lightened(0.02).darkened(0.22 if absf(float(v) - 0.5) > 0.44 or float(u) > 0.95 else 0.0))
		# yan tırnak
		J._pil(k, func(u, v):
			var x: float = sg * (ch.x * 0.84 + float(u) * 0.05)
			return P._fp(vk, x, C - 0.1 - float(v) * 0.03, true, 0.0)[0], 6, 4, 0.01, ve.darkened(0.04), cc, 0.2, tsk)
	# önlük: bel plakasının altından inen yuvarlak uçlu levha (kumaş gibi bacaklarla açılır)
	var ak := [P._kp(wa, H + 0.1, 0.05), P._kp(hp, H - 0.04, 0.05), [H - 0.16, hp.x + 0.07, hp.y + 0.064, hp.z - 0.07]]
	var ahem: float = H - 0.15
	var ask := func(p): return _xsk(k, p, ahem)
	var aw: float = ch.x * 0.72
	J._slab(k, func(u, v):
		var x: float = lerpf(-aw, aw, float(u))
		var ex: float = absf(x) / aw
		var yb: float = ahem + 0.045 * (1.0 - sqrt(maxf(0.0, 1.0 - pow(ex, 3.0))))
		return P._fp(ak, x, lerpf(H + 0.09, yb, float(v)), true, 0.006)[0], 16, 14, 0.008, 0.005, ve.darkened(0.02), Vector3(0, H, 0), ask)
	var hk := [P._kp(hp, H + 0.02, 0.018), P._kp(hp, H - 0.1, 0.018)]
	_bag(k, hk, H - 0.05, 0.03, bg)


# ------------------------------------------------------------------ Iwa genin (ref Hidden Stone Outfit): kızıl yüksek boyunlu tulum, sağ kol çıplak, sol kol bileğe doğru genişleyen çan ağızlı; kahve deri yelek
## (çivili omuz kayışları, fermuar, karında kapaklı büyük cep, yanlarda kayış, sırtta çanta), sağ uyluğun önüne inen koyu kızıl kuşak, diz altında manşetli bol paça + file baldır
static func _iwa(k) -> void:
	var rd := Color(0.62, 0.13, 0.16)
	var sa := Color(0.3, 0.045, 0.07)
	var br := Color(0.36, 0.26, 0.19)
	var bd := br.darkened(0.3)
	var mt := Color(0.7, 0.66, 0.58)
	var nt := Color(0.12, 0.11, 0.12)
	var skc := _skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	P._inner(k, b, func(_i, j, _p): return rd.lightened(0.04) if j < 3 else rd, 0.008)
	K._seat(k, b, rd.darkened(0.12))
	_neck(k, b, rd, 0.085, false, 0.004)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.4 if sd == "Left" else 3.1
		var kn: float = le["kn"]
		var en: float = ar["kn"]
		if sd == "Left":
			# çan ağızlı kol: bileğe doğru açılır; içinde tulumun dar kolu (ağızdan boşluk görünmez)
			var sl := func(s: float, a: float) -> float:
				var fl: float = smoothstep(en + 0.05, 0.97, s)
				return 0.009 + 0.03 * fl * fl + (0.0028 + 0.006 * fl) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 31.0 + sv)
			P._lt(k, ar, sl, func(s, a, ins): return rd.darkened(0.22) if ins else P._fs(rd, float(sl.call(s, a)) - 0.009 - 0.03 * pow(smoothstep(en + 0.05, 0.97, float(s)), 2.0), 22.0), 0.0, 0.97, 34, 24, 0.035)
			K._lt_in(k, ar, func(s, a): return float(sl.call(s, a)) - 0.005, rd.darkened(0.18), 0.72, 0.97, 10, 24)
			P._lt(k, ar, func(_s, _a): return 0.005, func(_s, _a, ins): return rd.darkened(0.3) if ins else rd.darkened(0.12), 0.6, 0.985, 14, 16)
		else:
			P._bare(k, ar, skc)
			P._lt(k, ar, func(s, _a): return 0.005 - 0.012 * (1.0 - smoothstep(0.0, 0.06, float(s))), func(_s, _a, ins): return rd.darkened(0.4) if ins else rd.darkened(0.06), 0.0, 0.13, 6, 18)
			k.wrap_turn(P._lp(ar, 0.125), P._ld(ar, 0.125), P._lr(ar, 0.125) + 0.0065, 0.0065, 0.0, rd.darkened(0.3), P._lskin(ar, 0.125))
		# bol paça diz altında manşetle biter; altı file
		var pc: float = kn + 0.13
		P._bare(k, le, skc, pc - 0.06, 1.0)
		P._net_limb(k, le, pc - 0.02, 0.975, 0.0035, 12, 0.034, 0.0017, nt)
		var pa: Callable = K._pant(k, le, rd, 0.014, 0.03, pc, sv)
		_roll(k, le, pc - 0.03, pc + 0.01, pa, 0.008, rd.darkened(0.1), sv)
		if sd == "Right":
			# koyu kızıl kuşak: belden uyluğun önüne, dizin üstüne iner
			_lplate(k, le, -2.0, 0.85, func(_a): return 0.0, kn - 0.04, func(s, a): return float(pa.call(s, a)) + 0.005, 0.004, sa, 18, 16)
	# kuşağın bel bandı (yelek altından görünür)
	var bk := [P._kp(wa, H + 0.08, 0.03), P._kp(hp, H - 0.02, 0.034)]
	P._sash(k, bk, H + 0.015, 0.018, 0.006, sa, 0.14)
	# yelek: kolsuz, önü fermuarlı
	var hem: float = H + 0.01
	var vk := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 0.96, ch.y * 0.95, ch.z * 1.05], [N - 0.13, ch.x * 1.0, ch.y * 1.02, ch.z * 1.06], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.04), P._kp(wa, hem, 0.05)]
	var ytop := func(a: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return N - 0.0 - 0.13 * exp(-pow((aa - PI * 0.5) / 0.42, 2.0))
	var tsk := func(p): return k.torso_skin(p.y)
	var vf := func(a, y, _v) -> float:
		return -0.018 * exp(-pow(float(a) / 0.02, 2.0)) + 0.005 * sin(float(a) * 7.0 + float(y) * 25.0) * smoothstep(C, H + 0.05, float(y))
	var vc := func(a, y, _v) -> Color:
		var n: float = 0.05 * sin(float(a) * 31.0 + float(y) * 70.0) * sin(float(a) * 9.0 - float(y) * 41.0)   # deri yüzey lekesi
		return br.darkened(maxf(0.0, n))
	var cg: Dictionary = P._cl(k, {"keys": vk, "ny": 34, "na": 96, "top": func(a): return float(ytop.call(float(a))), "hem": func(_a): return hem, "fold": vf,
		"col": vc, "gain": 6.0, "th": 0.007, "inner": bd.darkened(0.2), "skin": tsk})
	P._cord(k, cg["top"], 0.005, bd, true, tsk)
	P._cord(k, cg["hem"], 0.007, bd, true, tsk)
	P._strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, hem + 0.004)], true, 0.0026, 0.0035, 0.002, Color(0.86, 0.86, 0.84), 26)
	# çivili omuz kayışları
	for sg in [1.0, -1.0]:
		var x: float = sg * ch.x * 0.62
		I._pad(k, vk, x, N - 0.06, N - 0.07, 0.036, 0.011, 0.006, br.lightened(0.03))
		for fr in [true, false]:
			var e: Array = P._fp(vk, x, N - 0.045, fr, 0.019)
			P._stud(k, e[0], e[1], 0.0075, mt, k.torso_skin(N - 0.045))
		# yan kayışlar
		for yy in [H + 0.06, H + 0.1]:
			P._line(k, vk, [Vector2(sg * 0.95, yy), Vector2(sg * 1.75, yy - 0.004)], 0.006, 0.002, 0.003, bd, 6)
	# karında kapaklı büyük cep
	var cc := Vector3(0.0, C, 0.0)
	var pw: float = ch.x * 0.48
	J._pil(k, func(u, v): return P._fp(vk, lerpf(-pw, pw, float(u)), lerpf(H + 0.155, H + 0.07, float(v)), true, 0.0)[0], 14, 10, 0.018, br.lightened(0.05), cc, 0.14, tsk)
	J._pil(k, func(u, v): return P._fp(vk, lerpf(-pw - 0.005, pw + 0.005, float(u)), lerpf(H + 0.165, H + 0.128, float(v)), true, 0.018)[0], 14, 5, 0.007, br.lightened(0.09), cc, 0.2, tsk)
	# sırt çantası
	var e2: Array = P._fp(vk, 0.0, C - 0.06, false, 0.04)
	var bo := [["Chest", 0.6], ["UpperChest", 0.4]]
	P._boxr(k, e2[0], Vector3(0.1, 0, 0), Vector3(0, 0.085, 0), Vector3(0, 0, -0.04), br.darkened(0.05), bo, 0.3)
	P._boxr(k, (e2[0] as Vector3) + Vector3(0, 0.06, -0.016), Vector3(0.104, 0, 0), Vector3(0, 0.03, 0), Vector3(0, 0, -0.04), br.lightened(0.05), bo, 0.3)
	P._stud(k, (e2[0] as Vector3) + Vector3(0, 0.045, -0.058), Vector3(0, 0, -1), 0.007, mt, bo)


# ------------------------------------------------------------------ Kizoku Gaitō (ref Hiashi Outfit): bileğe inen beyaz kimono (sol kanat sağın üstüne, çapraz eri yakası), lacivert obi; üstünde önü açık,
## yere yakın koyu yeşil uzun cübbe (kenarı yaka bandı, içi astarlı, geniş düz kollar), altta lacivert diz boyu şort
static func _soylu(k) -> void:
	var wh := Color(0.94, 0.94, 0.93)
	var lv := Color(0.78, 0.76, 0.86)
	var ob := Color(0.141, 0.188, 0.416)
	var gn := Color(0.094, 0.157, 0.118)
	var gl := Color(0.06, 0.1, 0.075)
	var skc := _skc(k)
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
	K._seat(k, b, ob)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		K._pant(k, le, ob, 0.01, 0.012, kn + 0.05, 1.8 if sd == "Left" else 0.7)
		P._bare(k, le, skc, kn, 1.0)
	# kimono: tek parça, sol kanat sağın üstüne biner; bileğe iner
	var hem: float = lerpf(KN, F, 0.72)
	var keys := [P._kp(nk, N + 0.012, 0.022), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.034), P._kp(hp, H - 0.04, 0.04),
		[KN + 0.05, hp.x + 0.07, hp.y + 0.06, hp.z - 0.085], [hem, hp.x + 0.095, hp.y + 0.07, hp.z - 0.11]]
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		return pow(t, 0.9) * (0.018 * sin(a * 7.0 + 0.6) + 0.009 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.004 * sin(a * 5.0 + y * 9.0) * smoothstep(N - 0.03, C - 0.05, y)
	# kanatlar ayrı bacağı izler: alttaki sağ kanat sağ bacakla, üstteki sol kanat sol bacakla gider; bindirme payı aralığı örter
	var psk := func(p: Vector3, a: float) -> Array:
		var x: float = p.x
		if a < 0.75:
			x = minf(x, -0.09)
		elif a > TAU - 0.75:
			x = maxf(x, 0.09)
		return _ksk(k, Vector3(x, p.y, p.z), hem)
	var ny := 50
	var na := 92
	var ov := 0.5
	var aor := []
	var rows := []
	var angs := []
	for j in ny + 1:
		var y := lerpf(N + 0.012, hem, float(j) / ny)
		var ro := []
		var ar2 := []
		var ao := []
		for i in na + 1:
			var a := lerpf(-0.1, TAU - 0.1 + ov, float(i) / na)
			ao.append(a)
			var e: Array = Q._spt(keys, ff, a, y, 0.009 * smoothstep(TAU - 0.2, TAU - 0.05, a))
			var p: Vector3 = e[0]
			ro.append(Vector3(-p.x, p.y, p.z))
			ar2.append(-wrapf(a, -PI, PI))
		ro.reverse()
		ar2.reverse()
		ao.reverse()
		rows.append(ro)
		angs.append(ar2)
		aor.append(ao)
	var outer: Array = rows.duplicate()
	var src := []
	for j in ny + 1:
		src.append([j, false])
	var inw := func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
	var roll := []
	for p in outer[ny]:
		roll.append(inw.call(p, 0.004) + Vector3(0, -0.004, 0))
	rows.append(roll)
	src.append([ny, true])
	var j2: int = ny
	while float(outer[j2][0].y) < H - 0.02:
		var ro := []
		for p in outer[j2]:
			ro.append(inw.call(p, 0.007))
		rows.append(ro)
		src.append([j2, true])
		j2 -= 3
	k.grid(rows, false, func(i, j, _p):
		var e2: Array = src[j]
		if e2[1]:
			return lv.darkened(0.1)
		var oj: int = e2[0]
		var y: float = outer[oj][0].y
		var a: float = angs[oj][i]
		var c0: Color = P._fs(wh, float(ff.call(a, y)), 4.0)
		return c0.lerp(lv, 0.5 * smoothstep(0.35, 1.0, absf(sin(a * 3.5 + y * 4.0))) * smoothstep(H - 0.1, hem, y)), func(i, j, p): return psk.call(p, float(aor[src[j][0]][i])))
	var ed := []
	for j in range(2, ny + 1):
		ed.append(outer[j][0])
	P._bd(k, ed, 0.0035, 0.002, wh.darkened(0.12), false, func(p): return psk.call(p, TAU), 0.0)
	# eri: boynu saran, göğüste çaprazlanan kalın yaka bandı (sol üstte)
	for e3 in [[Vector2(-0.95, N + 0.03), Vector2(-0.35, N - 0.02), Vector2(0.15, C - 0.02), Vector2(0.45, H + 0.14)], [Vector2(0.95, N + 0.03), Vector2(0.35, N - 0.02), Vector2(-0.05, C + 0.0)]]:
		Q._run(k, keys, ff, e3, 0.014, 0.004 if e3.size() == 4 else 0.0025, 0.004, wh.darkened(0.04), func(p): return k.torso_skin(p.y), 8)
	Q._run(k, keys, ff, [Vector2(-0.95, N + 0.03), Vector2(-PI * 0.75, N + 0.012), Vector2(PI, N + 0.01), Vector2(PI * 0.75, N + 0.012), Vector2(0.95, N + 0.03)], 0.014, 0.0035, 0.004, wh.darkened(0.04), func(p): return Q._nsk(k, p), 8)
	# obi
	var obk := [P._kp(wa, H + 0.12, 0.042), P._kp(wa, H + 0.0, 0.05)]
	var by: float = H + 0.07
	P._sash(k, obk, by, 0.04, 0.008, ob, 0.14)
	P._sash(k, obk, by + 0.004, 0.03, 0.014, ob.lightened(0.05), 0.0)
	# cübbe: önü açık, yere yakın; içi astarlı
	var chem: float = lerpf(KN, F, 0.88)
	var ck := [P._kp(nk, N + 0.03, 0.04), [N - 0.045, ch.x * 1.04, ch.y * 0.98 + 0.012, ch.z * 1.08 - 0.012], P._kp(ch, C - 0.03, 0.05), P._kp(wa, H + 0.12, 0.074), P._kp(hp, H - 0.04, 0.074),
		[KN + 0.05, hp.x + 0.12, hp.y + 0.1, hp.z - 0.14], [chem, hp.x + 0.16, hp.y + 0.12, hp.z - 0.2]]
	var cskn := func(p): return K._coat_skin(k, p, chem)
	var e_at := func(y: float) -> float: return lerpf(0.42, 0.62, smoothstep(C, chem, y)) - 0.18 * smoothstep(N - 0.06, N + 0.03, y)
	var cf := func(a: float, y: float) -> float:
		var aw: float = absf(wrapf(a, -PI, PI))
		var t: float = clampf((H + 0.05 - y) / (H + 0.05 - chem), 0.0, 1.0)
		var bkf: float = smoothstep(1.2, 2.2, aw)
		return smoothstep(0.4, 0.8, aw) * (pow(t, 0.9) * ((0.05 + 0.016 * bkf) * sin(a * 7.0 + 0.6) + 0.026 * sin(a * 13.0 + 1.9)) + (1.0 - t) * 0.007 * sin(a * 5.0 + y * 7.0) * smoothstep(N - 0.03, C - 0.05, y))
	var cpt := func(a: float, y: float) -> Vector3:
		var s: Array = SE.El.key_at(ck, y)
		var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
		var f: float = 1.0 + float(cf.call(a, y))
		return Vector3(q.x * f, y, q.y * f)
	var cny := 56
	var cna := 100
	var co := []
	for j in cny + 1:
		var y := lerpf(N + 0.03, chem, float(j) / cny)
		var e: float = e_at.call(y)
		var ro := []
		for i in cna + 1:
			ro.append(cpt.call(lerpf(e, TAU - e, float(i) / cna), y))
		co.append(ro)
	var crows: Array = co.duplicate()
	var cs := []
	for j in cny + 1:
		cs.append([j, false])
	var croll := []
	for p in co[cny]:
		croll.append(inw.call(p, 0.005) + Vector3(0, -0.005, 0))
	crows.append(croll)
	cs.append([cny, true])
	for j in range(cny, -1, -2):
		var ro := []
		for i in cna + 1:
			ro.append(co[j][i] if i == 0 or i == cna else inw.call(co[j][i], 0.008))
		crows.append(ro)
		cs.append([j, true])
	k.grid(crows, false, func(i, j, _p):
		var e2: Array = cs[j]
		if e2[1]:
			return gl
		var oj: int = e2[0]
		var y: float = co[oj][0].y
		var e: float = e_at.call(y)
		var f: float = cf.call(lerpf(e, TAU - e, float(i) / cna), y)
		return gn.darkened(clampf(-f * 6.0, 0.0, 0.36)).lightened(clampf(f * 2.2, 0.0, 0.1)), func(_i, _j, p): return cskn.call(p))
	# ön kenar bandı (boyundan etek ucuna, kalın) + etek biyesi
	for side in 2:
		var pts := []
		var ou := []
		for j in range(0, cny + 1):
			var p: Vector3 = co[j][0 if side == 0 else cna]
			pts.append(p + Vector3(0.0, 0.0, 0.002))
			ou.append(Vector3(p.x * 0.3, 0.0, 1.0).normalized())
		k.strip(pts, ou, 0.016, 0.004, gn.lightened(0.05), false, cskn)
	var chm := []
	for p in co[cny]:
		chm.append((p as Vector3) + Vector3(0, 0.01, 0))
	P._bd(k, chm, 0.004, 0.002, gn.lightened(0.06), false, cskn)
	# arka yaka: cübbenin boyun ağzını saran rulo
	P._cord(k, co[0], 0.009, gn.lightened(0.04), false, func(p): return Q._nsk(k, p))
	# geniş düz kollar: içi astarlı, altta kimononun beyaz kolu
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sg: float = ar["sg"]
		var sv: float = 1.6 if sd == "Left" else 0.5
		var s1 := 0.9
		var sf := func(s: float, a: float) -> float:
			var fl: float = smoothstep(0.08, s1, s)
			var hang: float = maxf(0.0, -sin(a) * sg)
			return 0.02 + 0.042 * fl + 0.024 * fl * hang * hang + (0.003 + 0.007 * fl) * P._lf(s, a, sv) + 0.006 * exp(-pow((s - en) / 0.08, 2.0)) * sin(a * 3.0 + s * 30.0)
		P._lt(k, ar, sf, func(s, a, ins):
			if ins:
				return gl.lightened(0.04)
			return P._fs(gn, float(sf.call(float(s), float(a))) - 0.02 - 0.042 * smoothstep(0.08, s1, float(s)), 9.0), 0.0, s1, 32, 26, 0.04)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.006, gl.lightened(0.04), 0.45, s1, 12, 26)
		var ks := func(s: float, a: float) -> float: return 0.008 + 0.012 * smoothstep(0.5, 0.95, s) + 0.003 * P._lf(s, a, sv + 1.0)
		P._lt(k, ar, ks, func(_s, _a, ins): return lv.darkened(0.1) if ins else wh.darkened(0.04), 0.35, 0.965, 18, 20, 0.02)

## Bileğe inen kimono ağırlığı: ön yüz belin hemen altından kalkan uyluğu tam izler (uyluk önü kumaşı delmez), arka yüz yavaş artar ve
## iki bacak arasına yayılır (geri giden bacak eteği ezmez); diz altı baldırı da izler
static func _ksk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.98 * pow(minf(1.0, t / 0.22), 0.32)
	var wb: float = lerpf(0.8 * smoothstep(0.0, 1.0, minf(1.0, t / 0.9)), 0.96, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.006, 0.1, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var sd: String = "Left" if s >= 0.5 else "Right"
	var os: String = "Right" if s >= 0.5 else "Left"
	var ws: float = maxf(s, 1.0 - s)
	var kb: float = smoothstep(k.K + 0.08, k.K - 0.14, p.y) * lerpf(0.25, 0.55, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
