extends RefCounted
## Elle modellenmiş setler, parti as: ss_kuyruklu_beyaz, ss_flut, ss_ruzgar_kimono, ss_ruzgar_elbise, ss_ruzgar_elbise2, ss_ruzgar_zirh. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/{tailed_beast_white_garbs, tayuya_outfit, temari_outfit, temari_outfit_2, temari_outfit_3, temari_outfit_4}.png + refs/outfits_ss/all/<aynı ad>/.
## Kumaş / uzuv yardımcıları parti e (P), i (I), j (J), k (K), l (L), m (M), q (Q), r (R), s (S), t (T), y (Y), z (Z), aa (AA), ag (AG), aj (AJ) dosyalarından.
## Burada: rüzgâr (Kaze) setlerinin ortak kesimi (bot konçu, etek, lavanta üst + lamel göğüslük + kızıl kuşak), yin-yang, kalın girdap, tüy püskül ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const I = preload("res://scripts/actors/set_el_i.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const L = preload("res://scripts/actors/set_el_l.gd")
const M = preload("res://scripts/actors/set_el_m.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const W = preload("res://scripts/actors/set_el_w.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const AJ = preload("res://scripts/actors/set_el_aj.gd")

const DONE := ["ss_kuyruklu_beyaz", "ss_flut", "ss_ruzgar_kimono", "ss_ruzgar_elbise", "ss_ruzgar_elbise2", "ss_ruzgar_zirh"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_kuyruklu_beyaz": _kuyruklu(k)
		"ss_flut": _flut(k)
		"ss_ruzgar_kimono": _kimono(k)
		"ss_ruzgar_elbise": _elbise(k)
		"ss_ruzgar_elbise2": _kaze(k, false)
		"ss_ruzgar_zirh": _kaze(k, true)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ ortak yardımcılar
## Bot konçu: s0'dan bileğe; üstte katlı ağız, konçta hafif buruşukluk. Döner: yarıçap ekleme işlevi
static func _kboot(k, le: Dictionary, s0: float, col: Color, sv: float, base := 0.008) -> Callable:
	var bt := func(s: float, a: float) -> float:
		return base + 0.0035 * smoothstep(s0 + 0.05, s0, s) - 0.002 * smoothstep(0.93, 1.0, s) + 0.0016 * sin(a * 3.0 + s * 26.0 + sv) * smoothstep(s0 + 0.04, s0 + 0.1, s) * smoothstep(0.98, 0.9, s)
	P._lt(k, le, bt, func(s, a, ins): return col.darkened(0.35) if ins else P._fs(col, 0.0016 * sin(float(a) * 3.0 + float(s) * 26.0 + sv), 10.0), s0, 1.0, 18, 20)
	P._lt(k, le, func(s, a): return float(bt.call(float(s), float(a))) + 0.0028, func(_s, _a, ins): return col.darkened(0.35) if ins else col.lightened(0.07), s0, s0 + 0.026, 3, 20)
	return bt


## Mini etek ağırlığı: ön yüz uyluğu çabuk ve tam izler (öne kalkan uyluk eteği delmez), yanlarda ağırlık düşük (etek ucu kanat gibi açılmaz),
## arka yüz geniş geçişle iki bacağı izler (geri giden uyluk arkayı delmez)
static func _msk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	var fr: float = smoothstep(-0.02, 0.06, p.z) * (1.0 - smoothstep(0.55, 0.9, absf(p.x) / maxf(0.001, absf(p.x) + absf(p.z))))
	var top: float = H + 0.04 * fr   # önde ağırlık belin biraz üstünden başlar: kasık önünde kalkan uyluk eteğin üst kısmını delmez
	if p.y >= top:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var side: float = absf(p.x) / maxf(0.001, absf(p.x) + absf(p.z))
	var bk: float = smoothstep(0.02, -0.08, p.z)
	var wf: float = 0.97 * pow(minf(1.0, (top - p.y) / 0.12), 0.5)   # ön: kalçanın hemen altında tam (kalkan uyluğun üstü delmez)
	var wb: float = lerpf(0.8 * t, 0.92, smoothstep(0.6, 1.0, t))
	var w: float = lerpf(wf, wb, bk) * (1.0 - 0.3 * smoothstep(0.55, 0.9, side) * t)
	var hw: float = lerpf(0.022, 0.07, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Etek altı dar şort kalçası (eteğin arkası geri giden uylukla içeri gelince şort dışarı taşmaz)
static func _seat_in(k, b: Dictionary) -> Array:
	var hp: Vector3 = b["hp"]
	var bl: Vector3 = k.M(k.H + 0.05, 0.3)
	return [P._kp(bl, k.H + 0.085, 0.004), P._kp(bl, k.H + 0.04, 0.006), P._kp(hp, k.H - 0.05, 0.007), [k.H - 0.15, hp.x * 0.78, hp.y * 0.78, hp.z * 0.78]]


## Kalın girdap (kabartma şerit): mp yüzey eşlemesi, r dış yarıçap, turns tur sayısı; şerit ile ara aynı genişlikte
static func _spiral(k, mp: Callable, r: float, turns: float, lift: float, col: Color, skinf: Callable) -> void:
	var hw: float = r / turns * 0.26
	var pts := []
	var n: int = int(turns * 26.0)
	for i in n + 1:
		var t: float = float(i) / n
		var th: float = t * TAU * turns + 0.4
		var rr: float = lerpf(hw * 1.3, r, t)
		pts.append(Vector2(cos(th) * rr, sin(th) * rr))
	R._lstrip(k, mp, pts, hw, lift, 0.0018, col, skinf)


## Yin-yang amblemi (kabartma): koyu kenar halkası, beyaz disk, S sınırlı koyu yarı, iki zıt renk nokta
static func _yinyang(k, mp: Callable, out: Vector3, r: float, ink: Color, wh: Color, skinf: Callable) -> void:
	Q._disc(k, mp, out, r * 1.1, 0.003, Callable(), func(_u, _v): return ink, skinf, 2, 40)
	Q._disc(k, mp, out, r, 0.0042, Callable(), func(_u, _v): return wh, skinf, 3, 40)
	var rows := []
	var nv := 16
	var nu := 6
	var hr: float = r * 0.5
	for j in nv + 1:
		var v: float = lerpf(-r, r, float(j) / nv) * 0.995
		var xl: float = -sqrt(maxf(0.0, r * r - v * v))
		var xs: float = sqrt(maxf(0.0, hr * hr - pow(v - hr, 2.0))) if v >= 0.0 else -sqrt(maxf(0.0, hr * hr - pow(v + hr, 2.0)))
		var ro := []
		for i in nu + 1:
			ro.append(mp.call(lerpf(xl, xs, float(i) / nu), v, 0.0062))
		rows.append(ro)
	Q._mesh(k, rows, false, func(_i, _j, _p): return ink, func(_i, _j, p): return skinf.call(p), out)
	Q._disc(k, R._off(mp, 0.0, hr), out, r * 0.15, 0.0068, Callable(), func(_u, _v): return wh, skinf, 2, 14)
	Q._disc(k, R._off(mp, 0.0, -hr), out, r * 0.15, 0.0052, Callable(), func(_u, _v): return ink, skinf, 2, 14)


## Tüy püskülü: üstte boncuk, altında sivri uçlu yassı kızıl tüy (orta damarı koyu). Sert durur (kemiğine bağlı)
static func _feather(k, top: Vector3, o: Vector3, ln: float, w: float, col: Color, bead: Color, bones: Array) -> void:
	var d: Vector3 = (Vector3.DOWN + o * 0.1).normalized()
	var tx: Vector3 = d.cross(o).normalized()
	var on: Vector3 = (-d).cross(tx).normalized()
	var bp := []
	for i in 7:
		bp.append(top + d * lerpf(-0.009, 0.009, float(i) / 6.0))
	P._tb(k, bp, func(s, _a): return 0.0086 * sqrt(maxf(0.0, 1.0 - pow(2.0 * float(s) - 1.0, 2.0))) + 0.0006, func(s, _a, _p): return bead.lightened(0.18) if float(s) < 0.35 else bead, func(_s, _p): return bones, 10)
	var rows := []
	var n := 10
	for j in n + 1:
		var t: float = float(j) / n
		var c: Vector3 = top + d * (0.01 + ln * t)
		var ww: float = w * sin(pow(t, 0.7) * PI) * (1.0 - 0.25 * t) + 0.0008
		var th: float = 0.0025 * sin(t * PI) + 0.0006
		var ro := []
		for i in 8:
			var a: float = TAU * i / 8.0
			ro.append(c + tx * cos(a) * ww + on * sin(a) * th)
		rows.append(ro)
	k.grid(rows, true, func(i, j, _p): return col.darkened(0.38) if (i == 2 or i == 6) else (col.darkened(0.18) if j >= n - 1 else col), func(_i, _j, _p): return bones)


# ------------------------------------------------------------------ Bijū Byakue (ref Shinobi Striker "Tailed Beast White Garbs"): bol beyaz gi (üst kolda üç kısa, ön kolda üç uzun kara çubuk),
## belde beyaz sargı, kızıl girdaplı lacivert göğüslük (önde büyük, yanlarda ve sırtta küçük girdap), omuzdan geçen kalın lavanta askılar, kalçadan önde uyluğa
## sarkan kalın lavanta kuşak + yanlarında boncuklu kızıl tüy püsküller, lavanta eldiven, dizde iki kara kare yamalı bol beyaz pantolon, lacivert bot konçu
static func _kuyruklu(k) -> void:
	var wh := Color(0.949, 0.941, 0.918)
	var bk := Color(0.11, 0.11, 0.125)
	var nv := Color(0.165, 0.2, 0.5)
	var rd := Color(0.72, 0.13, 0.16)
	var lv := Color(0.69, 0.68, 0.85)
	var bt := Color(0.118, 0.165, 0.282)
	var tq := Color(0.25, 0.78, 0.84)
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
	# bol beyaz gi: boyundan bele
	var gk := [P._kp(nk, N + 0.012, 0.024), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.04), P._kp(wa, H + 0.03, 0.032), P._kp(hp, H - 0.05, 0.026)]
	var gf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((C - y) / (C - H), 0.0, 1.0)
		return t * (0.012 * sin(a * 6.0 + 0.5) + 0.006 * sin(a * 11.0 + 1.4)) + (1.0 - t) * 0.005 * sin(a * 4.0 + y * 13.0)
	var gg: Dictionary = P._cl(k, {"keys": gk, "ny": 30, "na": 80, "top": func(_a): return N + 0.012, "hem": func(_a): return H - 0.03, "fold": gf, "col": func(_a, _y, _v): return wh, "gain": 6.0,
		"th": 0.005, "inner": wh.darkened(0.3), "skin": tsk})
	P._cord(k, gg["top"], 0.0045, wh.darkened(0.06), true, nsk)
	# bol beyaz pantolon: baldırda toplanır, dizin altında iki kara kare; lacivert bot konçu
	K._seat(k, b, wh)
	I._seat(k, b, wh)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 1.2 if sd == "Left" else 2.6
		var tk: float = kn + 0.2
		var ad: Callable = Q._baggy(k, le, wh, wh, 0.024, 0.04, tk, sv)
		var ak: float = J._outer_a(le, kn + 0.03, Vector3(sg * 0.55, 0.0, 1.0))
		for da in [-0.2, 0.2]:
			AJ._lpatch(k, le, ad, kn + 0.035, ak + da, 0.011, 0.013, bk, bk.lightened(0.15))
		_kboot(k, le, tk - 0.03, bt, sv, 0.0125)
	# belde beyaz sargı (gi'yi pantolona bağlar)
	var wk := [P._kp(wa, H + 0.1, 0.036), P._kp(hp, H - 0.04, 0.036)]
	L._sash(k, wk, H + 0.03, 0.034, 0.0, wh.darkened(0.04), 0.16, 3)
	# kollar: bol beyaz kol + kara çubuklar, lavanta eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sg: float = ar["sg"]
		var sv: float = 0.7 if sd == "Left" else 1.9
		var sf: Callable = I._sleeve(k, ar, wh, 0.02, 0.93, sv, 0.0, 0.01)
		I._cuff(k, ar, 0.88, 0.935, 0.02, wh.darkened(0.05))
		var lf := func(s, a): return float(sf.call(float(s), float(a)))
		var a0: float = J._outer_a(ar, 0.2, Vector3(sg, 0.0, 0.25))
		var a1: float = J._outer_a(ar, 0.76, Vector3(sg, 0.0, 0.25))
		for i in 3:
			var o0: float = a0 + (float(i) - 1.0) * 0.34
			var o1: float = a1 + (float(i) - 1.0) * 0.4
			S._lstrip(k, ar, 0.12, 0.24, func(_s): return o0, lf, 0.0075, 0.0016, bk, 6)
			S._lstrip(k, ar, 0.66, 0.86, func(_s): return o1, lf, 0.0072, 0.0016, bk, 8)
		Z._glove_full(k, sd, lv)
		P._lt(k, ar, func(s, _a): return 0.006 + 0.004 * smoothstep(0.9, 0.945, float(s)), func(_s, _a, ins): return lv.darkened(0.3) if ins else lv, 0.9, 0.99, 6, 18)
	# lacivert göğüslük: koltuk altından bele, gövdeyi sarar
	var vk: Array = []
	for e in gk:
		vk.append([e[0], float(e[1]) + 0.014, float(e[2]) + 0.018, float(e[3]) - 0.014])
	var vtop := func(a: float) -> float: return N - 0.075 - 0.032 * smoothstep(0.5, 1.4, absf(sin(a)))
	var vf := func(a: float, y: float, _v: float) -> float: return 0.003 * sin(a * 5.0 + y * 11.0)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 22, "na": 84, "top": func(a): return vtop.call(float(a)), "hem": func(_a): return H + 0.075, "fold": vf, "col": func(_a, _y, _v): return nv, "gain": 8.0,
		"th": 0.008, "inner": nv.darkened(0.4), "skin": tsk})
	P._cord(k, vg["top"], 0.0042, nv.darkened(0.25), true, tsk)
	P._cord(k, vg["hem"], 0.0042, nv.darkened(0.25), true, tsk)
	var vff := func(a, y): return vf.call(float(a), float(y), 0.0)
	var cy: float = lerpf(N - 0.075, H + 0.075, 0.45)
	_spiral(k, func(u, v, l): return P._fp(vk, float(u), cy + float(v), true, float(l))[0], 0.112, 2.8, 0.0045, rd, tsk)
	_spiral(k, func(u, v, l): return P._fp(vk, -float(u), cy + float(v), false, float(l))[0], 0.1, 2.5, 0.0045, rd, tsk)
	for e in [[PI * 0.5, 0.062, 1.7], [-PI * 0.5, 0.062, 1.7]]:
		_spiral(k, Q._local(vk, vff, float(e[0]), cy), float(e[1]), float(e[2]), 0.0045, rd, tsk)
	# omuzdan geçen kalın lavanta askılar
	for sg in [1.0, -1.0]:
		I._pad(k, vk, sg * ch.x * 0.6, N - 0.08, N - 0.08, 0.026, 0.012, 0.01, lv)
	# kalçadan sarkan kalın lavanta kuşak: yanlarda kalçada, önde uyluğa iner, arkada kalçanın altından geçer
	var dk := [[H + 0.03, wa.x + 0.056, wa.y + 0.056, wa.z - 0.056], [H - 0.06, hp.x + 0.048, hp.y + 0.05, hp.z - 0.05], [H - 0.24, hp.x + 0.03, hp.y + 0.065, hp.z - 0.03]]
	var dy := func(a: float) -> float: return H + 0.005 - 0.2 * exp(-pow(a / 0.78, 2.0)) - 0.045 * exp(-pow((absf(a) - PI) / 0.9, 2.0))
	var dsk := func(p: Vector3) -> Array:
		if p.y >= H:
			return k.torso_skin(p.y)
		var t: float = clampf((H - p.y) / 0.2, 0.0, 1.0)
		var w: float = 0.78 * t
		var s: float = smoothstep(-0.07, 0.07, p.x)
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
	var pts := []
	for i in 80:
		var a: float = TAU * i / 80.0 - PI
		pts.append(P._sa(dk, a, dy.call(a), 0.0)[0])
	P._tb(k, pts, func(_s, _a): return 0.021, func(_s, a, _p): return lv.darkened(0.16) if cos(float(a)) < -0.4 else lv, func(_s, p): return dsk.call(p), 14, true)
	# tüy püsküller: kuşağın iki yanında
	for sg in [1.0, -1.0]:
		var sd: String = "Left" if sg > 0.0 else "Right"
		for i in 5:
			var a: float = sg * (0.82 + 0.29 * float(i))
			var e: Array = P._sa(dk, a, float(dy.call(a)) - 0.026, 0.004)
			var bo := [["Hips", 0.45], [sd + "UpperLeg", 0.55]]
			_feather(k, e[0], e[1], 0.13 - 0.008 * float(i % 2), 0.015, rd, tq, bo)


# ------------------------------------------------------------------ Fue Shōzoku (ref Shinobi Striker "Tayuya Outfit"): siyah tulum (boyun bandı, uyluğa siyah şort), üstünde soluk pembe bol kısa kollu tunik:
## belde kalın mor burgu ip, ipin altından yanları açık ön ve arka panel (önde beyaz daire içinde yin-yang), siyah ön kol ısıtıcısı, dizin altında siyah bant + beyaz baldır sargısı
static func _flut(k) -> void:
	var pk := Color(0.91, 0.831, 0.847)
	var pu := Color(0.478, 0.353, 0.69)
	var bk := Color(0.11, 0.11, 0.125)
	var wh := Color(0.93, 0.92, 0.9)
	var ink := Color(0.13, 0.11, 0.12)
	var skc: Color = Q._skc(k)
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
	# siyah tulum: gövde, boyun bandı
	var ik := [P._kp(nk, N + 0.03, 0.008, 0.01), P._kp(nk, N + 0.0, 0.014), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.006), P._kp(wa, H + 0.12, 0.006), P._kp(hp, H - 0.06, 0.008)]
	SE.body_layer(k, ik, 24, 44, func(_i, _j, _p): return bk)
	P._cord(k, P._ring_pts(ik, N + 0.026, 0.002, 48), 0.004, bk.lightened(0.08), true, nsk)
	R._seat(k, R._seat_keys(k, b), func(_i, _j, _p): return bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.0 if sd == "Left" else 2.4
		var s1: float = kn * 0.72
		var ad: Callable = R._short_leg(k, le, bk, s1, 0.008, 0.006, sv)
		R._hem_roll(k, le, ad, s1, bk.lightened(0.06), 0.022, 0.002)
		P._bare(k, le, skc, s1 - 0.05, 1.0)
		I._cuff(k, le, kn + 0.04, kn + 0.085, 0.013, bk)
		I._shin(k, le, kn + 0.08, 9, wh)
	# tunik üstü: bol, ipin üstünde kabarır
	var y_bl: float = H + 0.03
	var tk := [P._kp(nk, N + 0.006, 0.022), [N - 0.05, ch.x * 0.98, ch.y * 0.92, ch.z * 1.02], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.034), [y_bl, wa.x + 0.03, wa.y + 0.03, wa.z - 0.03]]
	var tf := func(a: float, y: float, _v: float) -> float:
		var bl: float = 0.012 * exp(-pow((y - (H + 0.078)) / 0.03, 2.0)) * (1.0 + 0.3 * sin(a * 7.0))   # ipin üstünde bluz kabarır
		return smoothstep(0.1, 0.4, absf(a)) * (0.007 * sin(a * 5.0 + y * 9.0) + 0.004 * sin(a * 11.0 + 0.6)) + bl
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 30, "na": 88, "top": func(a): return N + 0.006 - 0.014 * exp(-pow(float(a) / 0.6, 2.0)), "hem": func(_a): return y_bl, "fold": tf,
		"col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.005, "inner": pk.darkened(0.3), "skin": tsk})
	P._bd(k, tg["top"], 0.0055, 0.0026, bk.lightened(0.05), true, nsk, 0.3)
	# ön ve arka panel: ipin altından diz üstüne, yanlar açık
	var ey0: float = H + 0.075
	var ehem: float = KN + 0.07
	var wm: Vector3 = k.M(ey0, 0.3)
	var ekeys := [[ey0, wm.x + 0.018, wm.y + 0.018, wm.z - 0.018], [H - 0.04, hp.x + 0.05, hp.y + 0.052, hp.z - 0.05], [ehem, hp.x + 0.052, hp.y + 0.05, hp.z - 0.054]]
	var ffr := func(a, y) -> float:
		var aa: float = wrapf(float(a), -PI, PI)
		var t: float = clampf((H - float(y)) / (H - ehem), 0.0, 1.0)
		return t * (0.008 * sin(aa * 5.0 + 0.6) + 0.004 * sin(aa * 11.0 + 1.3)) * smoothstep(0.24, 0.6, absf(aa))
	for ctr in [0.0, PI]:
		var hw: float = 1.12
		var psk: Callable
		if ctr == 0.0:
			psk = func(p): return Z._psk(k, p, ehem)
		else:
			psk = func(p): return T._ksk(k, p, ehem)
		var pg: Dictionary = P._cl(k, {"keys": ekeys, "ny": 26, "na": 44, "rng": func(_v): return Vector2(ctr - hw, ctr + hw), "top": func(_a): return ey0, "hem": func(_a): return ehem,
			"fold": func(a, y, _v): return ffr.call(a, y), "col": func(_a, _y, _v): return pk, "gain": 6.0, "th": 0.006, "inner": pk.darkened(0.35), "skin": psk})
		for ed in [pg["ea"], pg["eb"]]:
			P._cord(k, ed, 0.0028, pk.darkened(0.12), false, psk)
		P._bd(k, K._yl(pg["hem"], 0.009), 0.0035, 0.0016, pk.darkened(0.14), false, psk)
	# önde yin-yang
	var yy: float = lerpf(H, ehem, 0.4)
	_yinyang(k, func(u, v, l): return P._fp(ekeys, float(u), yy + float(v), true, float(l))[0], Q._spt(ekeys, ffr, 0.0, yy)[1], 0.056, ink, Color(0.97, 0.96, 0.95), func(p): return Z._psk(k, p, ehem))
	# kalın mor burgu ip
	var rp: Array = P._ring_pts(tk, H + 0.05, 0.02, 72)
	T._twist(k, rp, true, 0.021, 11.0, pu, tsk)
	# kollar: bol kısa kol, çıplak kol, siyah ön kol ısıtıcısı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var kn: float = ar["kn"]
		var sv: float = 1.5 if sd == "Left" else 0.4
		var s1: float = kn * 0.62
		R._arm_skin(k, ar, kn * 0.4)
		var sf: Callable = I._sleeve(k, ar, pk, 0.016, s1, sv, 0.0, 0.006)
		P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0015, func(_s, _a, ins): return pk.darkened(0.3) if ins else pk.darkened(0.08), s1 - 0.025, s1, 3, 18)
		var s2: float = lerpf(kn, 1.0, 0.35)
		var wf := func(s: float, a: float) -> float: return 0.0105 + 0.002 * sin(a * 3.0 + s * 30.0 + sv) * smoothstep(s2 + 0.08, s2 + 0.02, s)
		P._lt(k, ar, wf, func(s, a, ins): return bk.darkened(0.3) if ins else P._fs(bk.lightened(0.06), 0.002 * sin(float(a) * 3.0 + float(s) * 30.0 + sv), 20.0), s2, 0.93, 16, 18, 0.02)


# ------------------------------------------------------------------ Kaze Kimono (ref Shinobi Striker "Temari Outfit"): uyluk ortasına inen lacivert kısa kimono (sol kanat sağın üstüne, V yaka),
## ön kol ortasına inen geniş kollar, açık çizgili koyu lacivert obi + ortasından geçen pembe ip (önde düğüm), arkada yassı obi düğümü, altta koyu şort, dizin altından siyah çizme konçu
static func _kimono(k) -> void:
	var kc := Color(0.165, 0.29, 0.753)
	var ob := Color(0.07, 0.09, 0.27)
	var st := Color(0.86, 0.82, 0.9)
	var pk := Color(0.96, 0.72, 0.82)
	var bk := Color(0.094, 0.094, 0.11)
	var skc: Color = Q._skc(k)
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
	M._inner_v(k, b, kc.darkened(0.3))
	R._seat(k, R._seat_keys(k, b), func(_i, _j, _p): return ob)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.3
		P._bare(k, le, skc, 0.1, 1.0)
		R._short_leg(k, le, ob, 0.16, 0.006, 0.004, sv)
		_kboot(k, le, kn + 0.05, bk, sv)
	# kimono: sol kanat sağın üstüne biner
	var hem: float = lerpf(H, KN, 0.48)
	var keys := [P._kp(nk, N + 0.0, 0.032), [N - 0.055, ch.x * 1.0, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.028), P._kp(hp, H - 0.04, 0.042), [hem, hp.x + 0.046, hp.y + 0.064, hp.z - 0.066]]
	var fold := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		var up: float = clampf((y - H) / (N - H), 0.0, 1.0)
		var blouse: float = 0.014 * exp(-pow((y - (H + 0.165)) / 0.035, 2.0))
		return t * (0.02 * sin(a * 5.0 + 0.4) + 0.01 * sin(a * 9.0 + 1.7)) + (1.0 - up) * 0.006 * sin(a * 7.0 + y * 10.0) * smoothstep(0.0, 0.1, up) + blouse
	var wg: Dictionary = M._wrap(k, {"keys": keys, "hem": hem, "col": func(_a, _y, v): return kc.darkened(0.1 * smoothstep(0.96, 1.0, float(v))), "fold": fold, "band": kc.darkened(0.12), "band_w": 0.017,
		"ny": 44, "na": 60, "gain": 4.5, "inner": kc.darkened(0.3), "low": -0.5, "skin_fn": func(p): return W._yk_skin(k, p, hem)})
	for lf in ["L", "R"]:
		var g: Dictionary = wg[lf]
		P._bd(k, M._yl(g["hem"], 0.008), 0.0055, 0.002, kc.darkened(0.14), false, func(p): return W._yk_skin(k, p, hem))
	# geniş kollar: ön kol ortasına iner, içi koyu astar; altında çıplak ön kol
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 1.3 if sd == "Left" else 0.4
		R._arm_skin(k, ar, 0.55)
		AA._hang_sleeve(k, ar, kc, kc.darkened(0.22), 0.012, 0.02, 0.016, 0.78, sv)
	# obi: koyu lacivert, alt üçte birde açık çizgi, ortasından pembe ip + önde düğüm; arkada yassı düğüm
	var ok := [P._kp(wa, H + 0.15, 0.046), P._kp(wa, H + 0.0, 0.058)]
	var oy: float = H + 0.075
	L._sash(k, ok, oy, 0.046, 0.0, ob, 0.12, 2)
	P._bd(k, P._ring_pts(ok, oy - 0.022, 0.012, 96), 0.0045, 0.0018, st, true, tsk)
	P._cord(k, P._ring_pts(ok, oy + 0.008, 0.0132, 96), 0.0028, pk, true, tsk, 0.9, 6)
	var kp: Array = P._sa(ok, 0.0, oy + 0.008, 0.017)
	var kc0: Vector3 = kp[0]
	P._tb(k, [kc0 + Vector3(-0.012, 0.004, 0), kc0, kc0 + Vector3(0.012, -0.004, 0)], func(s, a): return 0.0072 * (0.6 + 0.4 * sin(clampf(float(s), 0.0, 1.0) * PI)) * (1.0 + 0.15 * sin(float(a) * 3.0)),
		func(_s, a, _p): return pk.darkened(0.15) if sin(float(a) * 3.0) < -0.3 else pk, func(_s, p): return k.torso_skin(p.y), 10)
	var bq: Array = P._sa(ok, PI, oy, 0.026)
	var bc: Vector3 = bq[0]
	var hip: Array = [["Hips", 0.35], ["Spine", 0.65]]
	P._boxr(k, bc + Vector3(0, 0.008, -0.006), Vector3(0.07, 0, 0), Vector3(0, 0.046, 0), Vector3(0, 0, -0.015), ob.lightened(0.04), hip, 0.3)
	P._boxr(k, bc + Vector3(0, 0.008, -0.022), Vector3(0.026, 0, 0), Vector3(0, 0.05, 0), Vector3(0, 0, -0.008), ob.lightened(0.08), hip, 0.3)
	P._cord(k, [bc + Vector3(-0.05, -0.008, -0.022), bc + Vector3(0.0, -0.01, -0.031), bc + Vector3(0.05, -0.008, -0.022)], 0.0026, pk, false, func(_p): return hip, 0.9, 6)


# ------------------------------------------------------------------ Kaze Doresu (ref Shinobi Striker "Temari Outfit 2"): kısa kollu file iç (V yakada ve üst kolda görünür), koyu mor kolsuz V yakalı mini elbise,
## göğüs altından kalçaya lavanta sargı + ortasında pli pli koyu mor obi, iki yanda kemer kayışına asılı ten rengi keseler, koyu şort + uylukta file, siyah parmaksız eldiven, lavanta bantlı siyah diz çizmesi
static func _elbise(k) -> void:
	var dp := Color(0.2, 0.14, 0.24)
	var lv := Color(0.74, 0.7, 0.9)
	var ob := Color(0.33, 0.14, 0.28)
	var br := Color(0.27, 0.18, 0.15)
	var tn := Color(0.74, 0.64, 0.47)
	var nt := Color(0.44, 0.22, 0.24)
	var bk := Color(0.11, 0.11, 0.125)
	var skc: Color = Q._skc(k)
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
	# ten + file iç
	var sk_k := [P._kp(nk, N + 0.05, 0.004, 0.006), P._kp(nk, N + 0.012, 0.005), [N - 0.05, ch.x * 0.82, ch.y * 0.81, ch.z * 0.9], [C + 0.0, ch.x * 0.95, ch.y + 0.003, ch.z * 0.98], P._kp(ch, C - 0.03, 0.004), P._kp(wa, H + 0.1, 0.004), P._kp(hp, H - 0.06, 0.006)]
	SE.body_layer(k, sk_k, 30, 44, func(_i, _j, _p): return skc)
	P._net_patch(k, sk_k, func(a, y): return absf(float(a)) < 0.62 and float(y) < N + 0.008, -0.7, 0.7, C - 0.03, N + 0.01, 0.012, 0.0011, 0.0015, nt)
	P._cord(k, P._ring_pts(sk_k, N + 0.008, 0.002, 48), 0.0028, nt.darkened(0.2), true, nsk)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var en: float = ar["kn"]
		Z._arm_bare(k, ar)
		var s1: float = en - 0.07
		P._net_limb(k, ar, 0.0, s1, 0.0024, 10, 0.026, 0.0012, nt)
		P._lt(k, ar, func(s, _a): return 0.004 + 0.0012 * sin(clampf((float(s) - s1 + 0.03) / 0.03, 0.0, 1.0) * PI), func(_s, _a, ins): return nt.darkened(0.3) if ins else nt.darkened(0.2), s1 - 0.03, s1, 4, 20)
		# siyah parmaksız eldiven: ön kol ortasından ele
		AG._glove(k, sd, ar, bk)
		P._lt(k, ar, func(s, a): return 0.005 + 0.003 * smoothstep(0.69, 0.66, float(s)) + 0.0012 * sin(float(a) * 3.0 + float(s) * 30.0), func(_s, _a, ins): return bk.darkened(0.3) if ins else bk.lightened(0.04), 0.65, 0.9, 12, 18, 0.015)
	# şort + uylukta file; lavanta bantlı siyah diz çizmesi
	R._seat(k, _seat_in(k, b), func(_i, _j, _p): return ob.darkened(0.45))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.0
		P._bare(k, le, skc, 0.0, 1.0)
		R._short_leg(k, le, ob.darkened(0.45), kn * 0.12, 0.006, 0.003, sv)
		var s1: float = kn * 0.38
		P._net_limb(k, le, kn * 0.1, s1, 0.0026, 11, 0.026, 0.0012, nt)
		P._lt(k, le, func(s, _a): return 0.0045 + 0.0012 * sin(clampf((float(s) - s1 + 0.03) / 0.03, 0.0, 1.0) * PI), func(_s, _a, ins): return nt.darkened(0.3) if ins else nt.darkened(0.25), s1 - 0.03, s1, 4, 20)
		var bt: Callable = _kboot(k, le, kn - 0.03, bk, sv)
		for ss in [kn + 0.02, kn + 0.24]:
			Q._ring_on(k, le, ss, bt, 0.007, lv, 0.003)
	# elbise: V yaka, geniş omuz askısı, kolsuz; mini etek
	var hem: float = H - 0.2
	var dk: Array = Z._tk(k, b, H - 0.04, 0.012, 0.6)
	dk.append([hem, hp.x + 0.065, hp.y + 0.06, hp.z - 0.06])
	var topf := func(a: float) -> float:
		var u: float = absf(a)
		var base: float = lerpf(C + 0.01, N + 0.004, smoothstep(0.0, 0.42, u)) if u < PI * 0.5 else lerpf(N - 0.03, N + 0.004, smoothstep(PI, PI - 0.5, u))
		var arm: float = smoothstep(0.95, 1.3, u) * (1.0 - smoothstep(PI - 1.3, PI - 0.95, u))
		return lerpf(base, C - 0.035, arm)
	var dff := func(a: float, y: float) -> float:
		var t: float = clampf((H + 0.02 - y) / (H + 0.02 - hem), 0.0, 1.0)
		return t * (0.016 * sin(a * 8.0 + 0.5) + 0.006 * sin(a * 13.0 + 1.2)) + 0.003 * sin(a * 5.0 + y * 12.0) * (1.0 - t)
	var dsk := func(p): return _msk(k, p, hem) if float(p.y) < H + 0.05 else Q._nsk(k, p)
	var dg: Dictionary = P._cl(k, {"keys": dk, "ny": 44, "na": 96, "top": func(a): return topf.call(float(a)), "hem": func(_a): return hem, "fold": func(a, y, _v): return dff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return dp, "gain": 6.0, "th": 0.006, "inner": dp.darkened(0.35), "skin": dsk})
	P._cord(k, dg["top"], 0.003, dp.lightened(0.08), true, dsk)
	P._bd(k, K._yl(dg["hem"], 0.008), 0.0035, 0.0016, dp.darkened(0.2), true, dsk)
	# lavanta sargı: göğüs altından kalçaya
	var lk: Array = []
	for e in dk:
		lk.append([e[0], float(e[1]) + 0.008, float(e[2]) + 0.01, float(e[3]) - 0.008])
	var lff := func(a, y, _v): return 0.003 * sin(float(a) * 6.0 + float(y) * 15.0)
	var lw: Dictionary = P._cl(k, {"keys": lk, "ny": 24, "na": 88, "top": func(a): return C + 0.012 - 0.012 * smoothstep(0.8, 1.5, absf(sin(float(a)))), "hem": func(_a): return H - 0.035, "fold": lff,
		"col": func(_a, _y, _v): return lv, "gain": 7.0, "th": 0.006, "inner": lv.darkened(0.3), "skin": dsk})
	P._cord(k, lw["top"], 0.0032, lv.darkened(0.1), true, dsk)
	P._cord(k, lw["hem"], 0.0032, lv.darkened(0.1), true, dsk)
	# ortada pli pli koyu mor obi
	var okk: Array = []
	for e in lk:
		okk.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.006, float(e[3]) - 0.006])
	L._sash(k, okk, H + 0.075, 0.042, 0.0, ob, 0.2, 3)
	# keseler: kemer kayışına asılı, kalçanın iki yanında
	_kbelt(k, okk, H + 0.075, br)
	for sg in [1.0, -1.0]:
		var sd: String = "Left" if sg > 0.0 else "Right"
		var a: float = sg * 1.4
		var e: Array = P._sa(lk, a, H - 0.04, 0.03)
		var o: Vector3 = e[1]
		var tx: Vector3 = Vector3.UP.cross(o).normalized()
		var c0: Vector3 = e[0]
		var bo := [["Hips", 0.72], [sd + "UpperLeg", 0.28]]
		P._boxr(k, c0, tx * 0.032, Vector3.UP * 0.082, o * 0.016, tn, bo, 0.25)
		P._boxr(k, c0 + Vector3.UP * 0.068 + o * 0.006, tx * 0.034, Vector3.UP * 0.02, o * 0.014, tn.darkened(0.12), bo, 0.3)
		P._boxr(k, c0 + Vector3.UP * 0.1 + o * 0.004, tx * 0.009, Vector3.UP * 0.03, o * 0.004, br, [["Hips", 1.0]], 0.3)


## Kemer kayışı: obinin üstünde ince koyu kahve bant (yanlarda keseleri taşır)
static func _kbelt(k, keys: Array, y: float, col: Color) -> void:
	P._sash(k, keys, y, 0.011, 0.014, col, 0.06)


# ------------------------------------------------------------------ Kaze ortak kesimi (Temari Outfit 3 / 4): lavanta üst + kol, gri lamel göğüslük (önde ve arkada, omuz kayışları, yanlarda bağcık),
## belde iki kat kızıl kuşak. o: col (lavanta), plate, sash, vneck (kızıl iç yaka), sleeve ("bell" geniş / "fit" dar), lames, aw, pb (zırh alt kenarı). Döner: {keys}
static func _kaze_upper(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var lv: Color = o["col"]
	var pl: Color = o["plate"]
	var rs: Color = o["sash"]
	var vneck: bool = o.get("vneck", false)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	if vneck:
		var ik := [P._kp(nk, N + 0.016, 0.006, 0.008), P._kp(nk, N - 0.01, 0.012), [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], P._kp(ch, C - 0.03, 0.006), P._kp(wa, H + 0.12, 0.006)]
		SE.body_layer(k, ik, 16, 40, func(_i, j, _p): return rs.darkened(0.06) if j < 6 else rs.darkened(0.3))
	var tk := [P._kp(nk, N + 0.01, 0.018), [N - 0.055, ch.x * 0.96, ch.y * 0.92, ch.z * 1.02], P._kp(ch, C - 0.03, 0.018), P._kp(wa, H + 0.12, 0.022), P._kp(wa, H + 0.03, 0.02), P._kp(hp, H - 0.07, 0.02)]
	var tf := func(a: float, y: float, _v: float) -> float:
		return 0.005 * sin(a * 5.0 + y * 11.0) * smoothstep(0.2, 0.5, absf(a)) + 0.003 * sin(a * 9.0 + 0.7)
	var topf := func(a: float) -> float: return lerpf(C + 0.05, N + 0.01, smoothstep(0.0, 0.36, absf(a))) if vneck else N + 0.01
	var tg: Dictionary = P._cl(k, {"keys": tk, "ny": 32, "na": 84, "top": func(a): return topf.call(float(a)), "hem": func(_a): return H - 0.015, "fold": tf, "col": func(_a, _y, _v): return lv, "gain": 7.0,
		"th": 0.005, "inner": lv.darkened(0.3), "skin": tsk})
	if vneck:
		var ve := []
		for p in tg["top"]:
			if absf(atan2(float(p.x), float(p.z))) < 0.5:
				ve.append(p)
		P._bd(k, ve, 0.005, 0.0024, lv.darkened(0.12), false, nsk, 0.3)
		var ri := []   # kızıl iç yaka: V kenarının içinde görünen şerit
		for p in ve:
			ri.append((p as Vector3) + Vector3(-signf(float(p.x)) * 0.009, 0.0, -0.003))
		P._bd(k, ri, 0.007, 0.003, rs, false, nsk, 0.3)
	else:
		AJ._stand(k, nk, 0.035, 0.05, lv, lv.darkened(0.2), 0.026, 0.006)
	# kollar
	for sd in ["Left", "Right"]:
		var ar: Dictionary = I._limb(k, sd, false)
		var sv: float = 1.1 if sd == "Left" else 2.5
		if String(o.get("sleeve", "fit")) == "bell":
			R._arm_skin(k, ar, 0.62)
			AA._hang_sleeve(k, ar, lv, lv.darkened(0.2), 0.014, 0.02, 0.012, 0.82, sv)
		else:
			var sf: Callable = I._sleeve(k, ar, lv, 0.012, 0.9, sv)
			P._lt(k, ar, func(s, a): return float(sf.call(float(s), float(a))) + 0.0018, func(_s, _a, ins): return lv.darkened(0.3) if ins else lv.darkened(0.07), 0.87, 0.9, 3, 18)
	# gri lamel göğüslük: önde ve arkada üst plaka + üst üste binen sıralar, yanlarda bağcık
	var ak: Array = []
	for e in tk:
		ak.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.016, float(e[3]) - 0.012])
	var y_top: float = N - 0.06
	var y_bot: float = o.get("pb", H + 0.06)
	var n: int = o.get("lames", 4)
	var aw: float = o.get("aw", 1.0)
	var top_h: float = (y_top - y_bot) * float(o.get("top_f", 0.34))
	var rh: float = (y_top - top_h - y_bot) / n
	for ctr in [0.0, PI]:
		L._torso_plate(k, ak, ctr, aw, y_top, y_top - top_h, 0.0, 0.009, pl, pl.darkened(0.28), 28, 8)
		for i in n:
			var yt: float = y_top - top_h - rh * i + 0.01
			L._torso_plate(k, ak, ctr, aw + 0.025 * float(i + 1), yt, yt - rh - 0.008, 0.003 + 0.0025 * float(i + 1), 0.008, pl.darkened(0.035 * float(i + 1)), pl.darkened(0.3), 28, 4)
		for sg in [1.0, -1.0]:   # bağcık: plaka sıralarını dikine bağlar
			var cp := []
			for j in 13:
				var y: float = lerpf(y_top - 0.02, y_bot + 0.012, float(j) / 12.0)
				cp.append(L._sa(ak, ctr + sg * (aw - 0.12), y, 0.0145)[0])
			P._cord(k, cp, 0.0024, pl.darkened(0.45), false, tsk)
	for sg in [1.0, -1.0]:   # omuz kayışları
		L._over(k, ak, sg * (aw - 0.32), y_top - 0.004, sg * (PI - aw + 0.32), y_top - 0.004, 0.011, 0.008, 0.003, pl.darkened(0.35))
	# kızıl kuşak: iki kat
	var sk2: Array = []
	for e in tk:
		sk2.append([e[0], float(e[1]) + 0.026, float(e[2]) + 0.028, float(e[3]) - 0.026])
	L._sash(k, sk2, H + 0.035, 0.032, 0.0, rs, 0.18, 2)
	return {"keys": tk, "sk": sk2}


## Kaze etek: belden A kesim. o: y0, hem, flare, amp, col, lin, gap (etek ucunda önde açıklık yarı açısı; 0 kapalı), skin. Döner: keys, ff, g
static func _kskirt(k, b: Dictionary, o: Dictionary) -> Dictionary:
	var H: float = k.H
	var hp: Vector3 = b["hp"]
	var y0: float = o["y0"]
	var hem: float = o["hem"]
	var fl: float = o.get("flare", 0.05)
	var col: Color = o["col"]
	var wm: Vector3 = k.M(y0, 0.3)
	var keys := [[y0, wm.x + 0.022, wm.y + 0.024, wm.z - 0.022], [H - 0.04, hp.x + 0.032, hp.y + 0.034, hp.z - 0.032]]
	if hem < H - 0.25:
		keys.append([lerpf(H - 0.04, hem, 0.55), hp.x + 0.032 + fl * 0.6, hp.y + 0.036 + fl * 0.5, hp.z - 0.034 - fl * 0.55])
	keys.append([hem, hp.x + 0.032 + fl, hp.y + 0.036 + fl * 0.8, hp.z - 0.034 - fl * 0.9])
	var amp: float = o.get("amp", 0.016)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return t * (amp * sin(a * 8.0 + 0.6) + amp * 0.45 * sin(a * 13.0 + 1.9)) + 0.003 * sin(a * 14.0) * (1.0 - t)
	var sk: Callable = o["skin"]
	var co := {"keys": keys, "ny": o.get("ny", 26), "na": o.get("na", 104), "top": func(_a): return y0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return col, "gain": 6.0, "th": 0.006, "inner": o.get("lin", col.darkened(0.38)), "skin": sk}
	var gap: float = o.get("gap", 0.0)
	if gap > 0.0:
		co["rng"] = func(v) -> Vector2:
			var g2: float = lerpf(0.01, gap, pow(float(v), 0.8))
			return Vector2(g2, TAU - g2)
	var g: Dictionary = P._cl(k, co)
	var hm := []
	for p in g["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, hm, 0.0035, 0.0016, col.darkened(0.18), gap <= 0.0, sk)
	if gap > 0.0:
		for ed in [g["ea"], g["eb"]]:
			P._cord(k, ed, 0.003, col.darkened(0.14), false, sk)
	return {"keys": keys, "ff": ff, "g": g}


# ------------------------------------------------------------------ Kaze Nagasode (ref Shinobi Striker "Temari Outfit 3") ve Kaze Yoroi (ref "Temari Outfit 4"). Ortak: lavanta üst, gri lamel göğüslük, kızıl kuşak.
## Nagasode: alçak dik yaka, ön kola inen geniş kol (sağ ön kolda beyaz sargı), sol kalçada kuşak düğümü + dize inen kuşak ucu, uyluk ortasına inen lacivert etek, bacakta file, kısa siyah bot.
## Yoroi: kızıl iç yakalı V yaka, bileğe dar kol + lacivert parmaksız eldiven, önü kuşaktan aşağı açık dize inen mor etek (altında siyah şort), kısa siyah bot.
static func _kaze(k, zirh: bool) -> void:
	var lv: Color = Color(0.659, 0.596, 0.784) if zirh else Color(0.722, 0.659, 0.847)
	var pl: Color = Color(0.784, 0.769, 0.8) if zirh else Color(0.722, 0.722, 0.753)
	var rs := Color(0.659, 0.188, 0.227)
	var sc: Color = Color(0.29, 0.227, 0.416) if zirh else Color(0.165, 0.227, 0.416)
	var nv := Color(0.118, 0.165, 0.282)
	var bk := Color(0.11, 0.11, 0.125)
	var wh := Color(0.92, 0.91, 0.88)
	var nt := Color(0.16, 0.14, 0.16)
	var skc: Color = Q._skc(k)
	var H: float = k.H
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	# bacak: ten, şort; kısa siyah bot
	var hem: float = (KN - 0.05) if zirh else (H - 0.22)
	R._seat(k, _seat_in(k, b), func(_i, _j, _p): return bk if zirh else sc.darkened(0.4))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.3 if sd == "Left" else 0.5
		P._bare(k, le, skc, 0.0, 1.0)
		R._short_leg(k, le, bk if zirh else sc.darkened(0.4), kn * (0.4 if zirh else 0.14), 0.006, 0.004, sv)
		if not zirh:
			P._net_limb(k, le, kn * 0.4, kn - 0.02, 0.0026, 11, 0.026, 0.0012, nt)
			P._net_limb(k, le, kn + 0.05, 0.85, 0.0026, 10, 0.026, 0.0012, nt)
		_kboot(k, le, 0.84, bk, sv)
	var up: Dictionary = _kaze_upper(k, b, {"col": lv, "plate": pl, "sash": rs, "vneck": zirh, "sleeve": "fit" if zirh else "bell", "lames": 3 if zirh else 4, "aw": 1.1 if zirh else 0.95,
		"pb": H + 0.05, "top_f": 0.42 if zirh else 0.3})
	if zirh:
		for sd in ["Left", "Right"]:
			var ar: Dictionary = I._limb(k, sd, false)
			AG._glove(k, sd, ar, nv)
			P._lt(k, ar, func(s, _a): return 0.0105 + 0.002 * smoothstep(0.86, 0.84, float(s)), func(_s, _a, ins): return nv.darkened(0.3) if ins else nv, 0.84, 0.92, 6, 18, 0.01)
	else:
		var ar: Dictionary = I._limb(k, "Right", false)
		P._wraps(k, ar, 0.84, 0.94, 5, 0.006, 0.011, wh, 0.006)
	# etek
	var esk: Callable
	if zirh:
		esk = func(p): return AG._rsk(k, p, hem, 0.04, 0.55)   # önü açık uzun etek: ön kanatlar kendi uyluğunu, diz altı baldırı izler
	else:
		esk = func(p): return _msk(k, p, hem)
	var ek: Dictionary = _kskirt(k, b, {"y0": H + 0.045, "hem": hem, "flare": 0.05 if zirh else 0.045, "amp": 0.016 if zirh else 0.012, "col": sc, "lin": sc.darkened(0.45), "gap": 0.07 if zirh else 0.0,
		"skin": esk, "ny": 34 if zirh else 22, "na": 104})
	if zirh:
		return
	# kuşak düğümü sol kalçada + dize inen kuşak ucu (eteğin üstünden uyluğa oturur)
	var sk2: Array = up["sk"]
	var ka: float = 0.8
	var kq: Array = L._sa(sk2, ka, H + 0.035, 0.012)
	var kc: Vector3 = kq[0]
	var ko: Vector3 = kq[1]
	var kt: Vector3 = Vector3.UP.cross(ko).normalized()
	P._tb(k, [kc - kt * 0.016 + Vector3(0, 0.006, 0), kc, kc + kt * 0.016 - Vector3(0, 0.006, 0)], func(s, a): return 0.012 * (0.6 + 0.4 * sin(clampf(float(s), 0.0, 1.0) * PI)) * (1.0 + 0.14 * sin(float(a) * 3.0)),
		func(_s, a, _p): return rs.darkened(0.16) if sin(float(a) * 3.0) < -0.3 else rs, func(_s, p): return k.torso_skin(maxf(float(p.y), H + 0.001)), 12)
	var le: Dictionary = P._limb(k, "Left", true)
	var keys: Array = ek["keys"]
	var ff: Callable = ek["ff"]
	var pts := []
	var ou := []
	var sks := []
	var y_end: float = KN + 0.02
	for i in 25:
		var y: float = lerpf(H + 0.01, y_end, float(i) / 24.0)
		var e0: Array = Q._spt(keys, ff, ka + 0.06, maxf(y, hem + 0.004), 0.007)
		var s: float = Z._s_at(le, y)
		var al: float = J._outer_a(le, s, Vector3(0.55, 0.0, 0.85))
		var e1: Array = Q._ls(le, s, al, 0.006)
		var t: float = smoothstep(hem + 0.02, hem - 0.07, y)
		pts.append((e0[0] as Vector3).lerp(e1[0], t))
		ou.append((e0[1] as Vector3).lerp(e1[1], t).normalized())
		sks.append(W._mix(esk.call(e0[0]), P._lskin(le, s), smoothstep(hem + 0.03, hem - 0.04, y)))
	W._ridge(k, pts, ou, sks, 0.019, 0.004, rs)
