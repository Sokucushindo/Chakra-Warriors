extends RefCounted
## Elle modellenmiş setler, parti v: ss_yedi_kanat, ss_kizil_palto, ss_kum_cocuk, ss_kizil_palto2, ss_yesil_canavar, ss_yesil_canavar2. Örnek: set_el.gd içindeki _shugonin.
## Kumaş / uzuv yardımcıları parti e (P), k (K), j (J), n (NN), q (Q), r (R) dosyalarından; burada eğik kemer, toka, geniş bez şerit, köy armaları,
## Gaara paltosunun ortak kesimi (iki türev) ve Gai tulumunun ortak kesimi (iki türev).
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const NN = preload("res://scripts/actors/set_el_n.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const R = preload("res://scripts/actors/set_el_r.gd")

const DONE := ["ss_yedi_kanat", "ss_kizil_palto", "ss_kum_cocuk", "ss_kizil_palto2", "ss_yesil_canavar", "ss_yesil_canavar2"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_yedi_kanat": _yedi(k)
		"ss_kizil_palto": _palto1(k)
		"ss_kum_cocuk": _kum(k)
		"ss_kizil_palto2": _palto2(k)
		"ss_yesil_canavar": _guy2(k)
		"ss_yesil_canavar2": _guy3(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Satırları dış yöne çevirip ızgaraya yazar (renk tablosu da birlikte döner)
static func _emit(k, rows: Array, cols: Array, skinf: Callable, out: Vector3, closed := false) -> void:
	var j0: int = mini(1, rows.size() - 2)
	var a: Vector3 = rows[j0][0]
	var fn: Vector3 = -((rows[j0][1] as Vector3) - a).cross((rows[j0 + 1][1] as Vector3) - a)
	if fn.dot(out) < 0.0:
		for ro in rows:
			ro.reverse()
		for cr in cols:
			cr.reverse()
	k.grid(rows, closed, func(i, j, _p): return cols[j][i], func(_i, _j, p): return skinf.call(p))


## Kemer / bel bandı: y(a) = yc + tilt * sin(a - ph) (eğik kemer), h yarı yükseklik; kenarları dikişli
static func _belt(k, keys: Array, yc: float, tilt: float, h: float, lift: float, col: Color, ph := 0.0, na := 72, skinf := Callable()) -> void:
	var rows := []
	for j in 5:
		var v := float(j) / 4.0
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var y: float = yc + tilt * sin(a - ph) + h * (1.0 - 2.0 * v)
			var s: Array = SE.El.key_at(keys, y)
			var bl: float = lift + 0.0025 * sin(v * PI)
			var q: Vector2 = SE.El.sup(a, float(s[1]) + bl, float(s[2]) + bl, float(s[3]) - bl)
			ro.append(Vector3(q.x, y, q.y))
		rows.append(ro)
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return k.torso_skin(p.y)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.2) if j == 0 or j == 4 else (col.lightened(0.04) if j == 2 else col), func(_i, _j, p): return sf.call(p))


## Kemerde açının noktası ve dış yönü
static func _belt_pt(keys: Array, a: float, yc: float, tilt: float, lift: float, ph := 0.0) -> Array:
	var y: float = yc + tilt * sin(a - ph)
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, float(s[1]) + lift, float(s[2]) + lift, float(s[3]) - lift)
	var p := Vector3(q.x, y, q.y)
	return [p, Vector3(p.x, 0.0, p.z).normalized()]


## Kare toka: dört kenar çubuğu + dil
static func _buckle(k, c: Vector3, o: Vector3, w: float, h: float, col: Color, bones: Array) -> void:
	var up := (Vector3.UP - o * Vector3.UP.dot(o)).normalized()
	var ri := up.cross(o).normalized()
	var t := 0.0032
	for e in [[0.0, h, w + t, t], [0.0, -h, w + t, t], [w, 0.0, t, h], [-w, 0.0, t, h]]:
		P._boxr(k, c + ri * float(e[0]) + up * float(e[1]) + o * 0.0035, ri * float(e[2]), up * float(e[3]), o * 0.0035, col, bones, 0.35)
	P._boxr(k, c + ri * (-w * 0.15) + o * 0.005, ri * t * 0.7, up * h * 0.95, o * 0.002, col.lightened(0.12), bones, 0.35)


## Yüzeye oturan geniş bez şerit: ctrl (x, y) yolu, w yarı genişlik; boyuna kıvrım sırtları (vadide koyulaşır)
static func _cloth_band(k, keys: Array, ctrl: Array, front: bool, w: float, lift: float, ridges: float, amp: float, col: Color, shade: Color, skinf: Callable, steps := 6, nu := 10) -> void:
	var path: Array = P._path(ctrl, steps)
	var n := path.size()
	var rows := []
	var cols := []
	for j in n:
		var pa: Vector2 = path[maxi(0, j - 1)]
		var pc: Vector2 = path[mini(n - 1, j + 1)]
		var t := (pc - pa).normalized()
		var no := Vector2(-t.y, t.x)
		var ro := []
		var cr := []
		for i in nu + 1:
			var u := float(i) / nu * 2.0 - 1.0
			var q: Vector2 = (path[j] as Vector2) + no * u * w
			var rid := sin((u * 0.5 + 0.5) * PI * ridges + float(j) * 0.07)
			var edge := 1.0 - pow(absf(u), 6.0)
			var l: float = lift + amp * (0.5 + 0.5 * rid) * edge - 0.002 * (1.0 - edge)
			ro.append(P._fp(keys, q.x, q.y, front, l)[0])
			cr.append(col.lerp(shade, clampf(-rid, 0.0, 1.0) * 0.55).darkened(0.12 if i == 0 or i == nu else 0.0))
		rows.append(ro)
		cols.append(cr)
	_emit(k, rows, cols, skinf, Vector3(0, 0, 1.0 if front else -1.0))


## Yüzey üstü şerit: kalkış noktaya göre değişir (başka parçanın üstünden aşar)
static func _strap2(k, keys: Array, ctrl: Array, front: bool, hw: float, liftf: Callable, d: float, col: Color, skinf: Callable, steps := 8) -> Array:
	var pts := []
	var ou := []
	var q2 := []
	for s in ctrl.size() - 1:
		for t in steps + (1 if s == ctrl.size() - 2 else 0):
			var q: Vector2 = (ctrl[s] as Vector2).lerp(ctrl[s + 1], float(t) / steps)
			var e: Array = P._fp(keys, q.x, q.y, front, float(liftf.call(q)))
			pts.append(e[0])
			ou.append(e[1])
			q2.append(q)
	k.strip(pts, ou, hw, d, col, false, skinf)
	return [pts, ou]


## İki boyutlu nokta-doğru parçası uzaklığı
static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(1e-6, ab.length_squared()), 0.0, 1.0)
	return (p - (a + ab * t)).length()


## Düzlem eşlemesi (toka / plaka üstü arma): (u, v, kalkış) -> nokta
static func _plane(c: Vector3, ri: Vector3, up: Vector3, o: Vector3) -> Callable:
	return func(u: float, v: float, l: float) -> Vector3: return c + ri * u + up * v + o * l


## Konoha yaprağı: sarmal + sivri yaprak ucu + sap
static func _m_leaf(k, mp: Callable, s: float, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	var sp := []
	for i in 30:
		var t := float(i) / 29.0
		var th := -0.4 - t * TAU * 1.3
		sp.append(Vector2(cos(th), sin(th)) * s * lerpf(0.07, 0.6, t))
	sp.append(Vector2(-0.72, 0.55) * s)
	sp.append(Vector2(-0.95, 0.95) * s)
	R._lstrip(k, mp, sp, hw, lift, 0.0016, col, skinf)
	R._lstrip(k, mp, [Vector2(-0.95, 0.95) * s, Vector2(-0.8, 0.2) * s, Vector2(-0.55, -0.4) * s, Vector2(-0.1, -0.72) * s, Vector2(0.35, -0.6) * s], hw, lift, 0.0016, col, skinf)


## Suna: kum saati (üst / alt çizgi, iki yay, ortada düğüm)
static func _m_suna(k, mp: Callable, s: float, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	R._lstrip(k, mp, [Vector2(-0.62, 0.72) * s, Vector2(0.62, 0.72) * s], hw, lift, 0.0016, col, skinf)
	R._lstrip(k, mp, [Vector2(-0.62, -0.72) * s, Vector2(0.62, -0.72) * s], hw, lift, 0.0016, col, skinf)
	for sg in [1.0, -1.0]:
		var pts := []
		for i in 9:
			var t := float(i) / 8.0
			var y: float = lerpf(0.72, -0.72, t)
			pts.append(Vector2(sg * (0.5 - 0.42 * sin(t * PI)), y) * s)
		R._lstrip(k, mp, pts, hw, lift, 0.0016, col, skinf)


## Taki: su damlası çevresi + içte kıvrım
static func _m_taki(k, mp: Callable, s: float, hw: float, lift: float, col: Color, skinf: Callable) -> void:
	var dr := []
	for i in 24:
		var t := TAU * i / 24.0
		dr.append(Vector2(0.62 * sin(t) * sin(t * 0.5), 0.72 * cos(t) + 0.08) * s)
	R._lstrip(k, mp, dr, hw, lift, 0.0016, col, skinf, true)
	var cu := []
	for i in 12:
		var t := float(i) / 11.0
		var th := 2.6 - t * TAU * 0.85
		cu.append(Vector2(cos(th), sin(th)) * s * lerpf(0.36, 0.1, t) + Vector2(0.0, -0.18) * s)
	R._lstrip(k, mp, cu, hw, lift, 0.0016, col, skinf)


## Uzvun dışa bakan açısı (dir yönünde)
static func _outer(l: Dictionary, s: float, dir: Vector3) -> float:
	var best := 0.0
	var bv := -9.0
	for i in 36:
		var a := TAU * i / 36.0 - PI
		var v: float = (Q._ls(l, s, a, 0.0)[1] as Vector3).dot(dir.normalized())
		if v > bv:
			bv = v
			best = a
	return best


# ------------------------------------------------------------------ Nanao Shōzoku (ref Shinobi Striker "Fuu Outfit"): kare yakalı askılı beyaz kısa üst, altında file bant, açık karın,
## sağ üst kolda Taki plakalı lacivert bant, dirsek üstünden bileğe beyaz bol kolluk, bel altı beyaz mini etek (kemer bandı, köprü), sol kalçada kese
static func _yedi(k) -> void:
	var wh := Color(0.95, 0.95, 0.94)
	var dk := Color(0.1, 0.1, 0.12)
	var nv := Color(0.13, 0.16, 0.3)
	var mt := Color(0.74, 0.76, 0.79)
	var tl := Color(0.17, 0.4, 0.38)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var hp: Vector3 = b["hp"]
	var tk: Array = R._bare_torso(k, b, H - 0.07, false)
	# kısa üst: düz kare yaka, göğüs altında biter
	var yt: float = C + 0.06
	var yh: float = C - 0.115
	var tops := []
	var yy: float = yt + 0.012
	while yy > yh - 0.02:
		var mx := Vector3.ZERO
		var mn := 9.0
		for dy in [-0.012, -0.006, 0.0, 0.006, 0.012]:
			var m0: Vector3 = k.M(yy + dy, k.UA)
			mx = Vector3(maxf(mx.x, m0.x), maxf(mx.y, m0.y), 0.0)
			mn = minf(mn, m0.z)
		tops.append(P._kp(Vector3(mx.x, mx.y, mn), yy, 0.009))
		yy -= 0.015
	var tf := func(a: float, y: float, _v: float) -> float:
		return 0.006 * sin(a * 6.0 + y * 20.0) * smoothstep(yt, yh, y) + 0.004 * sin(a * 11.0 + 0.4)
	var tg: Dictionary = P._cl(k, {"keys": tops, "ny": 16, "na": 72, "top": func(a): return yt - 0.03 * smoothstep(0.9, 1.7, absf(float(a))), "hem": func(_a): return yh,
		"fold": tf, "col": func(_a, _y, _v): return wh, "gain": 6.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": func(p): return k.torso_skin(p.y)})
	P._cord(k, tg["top"], 0.0028, wh.darkened(0.1), true, func(p): return k.torso_skin(p.y))
	# ince koyu askılar: yakadan omuz üstünden sırta
	for sg in [1.0, -1.0]:
		P._over(k, tk, sg * ch.x * 0.46, yt - 0.004, yt - 0.034, 0.0055, 0.004, 0.0022, dk)
	# file bant: koyu taban + çapraz iplikler, üst ve alt kenar şeridi
	var y0: float = yh - 0.003
	var y1: float = C - 0.19
	var nk2 := []
	for y in [y0 + 0.01, (y0 + y1) * 0.5, y1 - 0.01]:
		nk2.append(P._kp(k.M(y, k.UA), y, 0.004))
	SE.body_layer(k, [[y0, nk2[0][1], nk2[0][2], nk2[0][3]], nk2[1], [y1, nk2[2][1], nk2[2][2], nk2[2][3]]], 6, 64, func(_i, _j, _p): return skc.darkened(0.55))
	var nk3 := []
	for e in nk2:
		nk3.append([e[0], float(e[1]) + 0.002, float(e[2]) + 0.002, float(e[3]) - 0.002])
	Q._net(k, nk3, -PI, PI, y1 + 0.004, y0 - 0.002, 0.017, 0.0012, 0.0015, dk)
	var br := []
	for i in 64:
		br.append(Q._spt(nk3, Callable(), TAU * i / 64.0 - PI, y1 + 0.003, 0.002)[0])
	P._cord(k, br, 0.0034, dk.lightened(0.05), true, func(p): return k.torso_skin(p.y))
	# kollar: açık omuz ve üst kol, dirsek üstünden bileğe bol kolluk
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sg: float = ar["sg"]
		var sv: float = 1.1 if sd == "Left" else 2.7
		R._arm_skin(k, ar)
		var s0 := 0.335
		var wm := func(s: float, a: float) -> float:
			var mid: float = smoothstep(s0 + 0.02, s0 + 0.1, s) * smoothstep(0.985, 0.9, s)
			return 0.006 + 0.008 * smoothstep(0.5, 0.97, s) + mid * (0.0034 * sin(a * 3.0 + s * 38.0 + sv) + 0.0026 * P._lf(s, a, sv)) - 0.003 * smoothstep(s0 + 0.04, s0, s)
		P._lt(k, ar, wm, func(s, a, ins):
			return wh.darkened(0.35) if ins else P._fs(wh, float(wm.call(float(s), float(a))) - 0.006 - 0.008 * smoothstep(0.5, 0.97, float(s)), 16.0), s0, 0.975, 34, 20, 0.03)
		K._lt_in(k, ar, func(s, a): return float(wm.call(float(s), float(a))) - 0.004, wh.darkened(0.3), 0.88, 0.975, 4, 20)
		P._lt(k, ar, func(s, a): return float(wm.call(float(s), float(a))) + 0.0022, func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.06), s0, s0 + 0.022, 3, 20)
		if sd == "Right":   # lacivert bant + Taki plakası
			var sb := 0.275
			Q._ring_on(k, ar, sb, func(_s, _a): return 0.001, 0.018, nv, 0.007)
			var ao: float = _outer(ar, sb, Vector3(sg, 0.25, 0.35))
			var e: Array = Q._ls(ar, sb, ao, 0.011)
			var o: Vector3 = e[1]
			var d: Vector3 = P._ld(ar, sb)
			var ri: Vector3 = o.cross(d).normalized()
			var bo: Array = P._lskin(ar, sb)
			P._boxr(k, e[0], ri * 0.024, -d * 0.017, o * 0.003, mt, bo, 0.3)
			_m_taki(k, _plane((e[0] as Vector3) + o * 0.003, ri, -d, o), 0.012, 0.0014, 0.0008, mt.darkened(0.35), func(_p): return bo)
	# bacaklar: açık
	for sd in ["Left", "Right"]:
		P._bare(k, P._limb(k, sd, true), skc, 0.0, 1.0)
	var sl: Vector3 = k.M(H - 0.005, 0.3)
	SE.body_layer(k, [P._kp(sl, H - 0.005, 0.006), P._kp(hp, H - 0.05, 0.016), [H - 0.15, hp.x * 0.76, hp.y * 0.78, hp.z * 0.78]], 8, 34, func(_i, _j, _p): return wh.darkened(0.1))
	# mini etek: kalça altında başlar, uyluğun üçte birine iner; önde verev gerilme kırışıkları
	var ys: float = H + 0.012
	var hem: float = H - 0.235
	var mk := [P._kp(k.M(ys, 0.3), ys, 0.012), P._kp(hp, H - 0.04, 0.022), [hem, hp.x + 0.04, hp.y + 0.038, hp.z - 0.04]]
	var mf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((ys - y) / (ys - hem), 0.0, 1.0)
		var dg: float = 0.009 * sin(a * 4.0 + y * 46.0) * smoothstep(1.4, 0.4, absf(a)) * smoothstep(0.15, 0.4, t)
		return t * (0.01 * sin(a * 8.0 + 0.3) + 0.004 * sin(a * 15.0)) + dg
	var msk := func(p: Vector3) -> Array:   # yan kumaşın bacak payı azalır: adımda kanat açmaz
		if p.y >= H:
			return k.torso_skin(p.y)
		var t: float = clampf((H - p.y) / (H - hem), 0.0, 1.0)
		var side: float = absf(p.x) / maxf(0.001, absf(p.x) + absf(p.z))
		var w: float = t * 0.5 * (1.0 - 0.45 * smoothstep(0.45, 0.85, side))
		var s: float = smoothstep(-0.09, 0.09, p.x)
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
	var mg: Dictionary = P._cl(k, {"keys": mk, "ny": 18, "na": 84, "top": func(_a): return ys, "hem": func(_a): return hem, "fold": mf, "col": func(_a, _y, _v): return wh, "gain": 7.0, "th": 0.005, "inner": wh.darkened(0.3), "skin": msk})
	var hm := []
	for p in mg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, hm, 0.003, 0.0015, wh.darkened(0.1), true, msk)
	# kemer bandı + köprüler
	var bk2 := []
	for e in mk:
		bk2.append(e)
	_belt(k, bk2, ys - 0.014, 0.0, 0.0135, 0.004, wh.darkened(0.03), 0.0, 80, msk)
	for a in [-0.42, 0.3, PI - 0.55, PI + 0.55, 1.5, -1.5]:
		var ep: Array = Q._spt(mk, Callable(), a, ys - 0.014, 0.008)
		var o2: Vector3 = ep[1]
		P._boxr(k, ep[0], Vector3.UP.cross(o2).normalized() * 0.006, Vector3(0, 0.017, 0), o2 * 0.0025, wh.darkened(0.08), [["Hips", 1.0]], 0.3)
	# sol kalçada kese: kemer köprüsünden sarkar
	var pe: Array = Q._spt(mk, Callable(), 1.45, H - 0.1, 0.022)
	var po: Vector3 = pe[1]
	var bo3 := [["Hips", 0.75], ["LeftUpperLeg", 0.25]]
	P._boxr(k, (pe[0] as Vector3), po.cross(Vector3.UP).normalized() * 0.03, Vector3(0, 0.055, 0), po * 0.015, tl, bo3, 0.3)
	P._boxr(k, (pe[0] as Vector3) + Vector3(0, 0.04, 0) + po * 0.013, po.cross(Vector3.UP).normalized() * 0.032, Vector3(0, 0.016, 0), po * 0.006, tl.darkened(0.2), bo3, 0.3)
	P._stud(k, (pe[0] as Vector3) + Vector3(0, 0.028, 0) + po * 0.019, po, 0.005, mt, bo3)
	P._cur_hem = hem


# ------------------------------------------------------------------ Gaara paltosu ortak kesim (ref "Gaara Outfit", "Gaara Outfit 2"): kıvrık paçalı siyah pantolon, kalça astarı,
## uzun palto (göğüste kapalı, belden aşağı önü açılır), astarlı uzun kollar. o: hem (K..F oranı), yo (açılma başlangıcı), eo (etekte yarım açıklık), band (kol şeridi rengi)
static func _gaara_coat(k, col: Color, lin: Color, o: Dictionary) -> Dictionary:
	var bk := Color(0.1, 0.1, 0.12)
	var N: float = k.N
	var H: float = k.H
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	K._seat(k, b, bk)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var pa: Callable = K._pant(k, le, bk, 0.012, 0.016, 1.0, 1.7 if sd == "Left" else 3.1)
		Q._ring_on(k, le, 0.955, func(s, a): return float(pa.call(float(s), float(a))) + 0.003, 0.018, bk.lightened(0.07), 0.005)
	var hem: float = lerpf(KN, k.F, float(o.get("hem", 0.5)))
	var keys: Array = NN._coat_keys(k, b, 0.034, hem, 0.09, 0.08, 0.13)
	# kalça altı: uyluk ve kalça arkası paltoyu delmesin (seyrek anahtar arasında beden taşmaz)
	var yq: float = H - 0.14
	var kq: Array = SE.El.key_at(keys, yq)
	var mq: Vector3 = k.M(yq, 0.2)
	keys.insert(5, [yq, maxf(float(kq[1]), mq.x + 0.05), maxf(float(kq[2]), mq.y + 0.05), minf(float(kq[3]), mq.z - 0.075)])
	var yr: float = H - 0.24
	var kr: Array = SE.El.key_at(keys, yr)
	var mr: Vector3 = k.M(yr, 0.2)
	keys.insert(6, [yr, maxf(float(kr[1]), mr.x + 0.045), maxf(float(kr[2]), mr.y + 0.05), minf(float(kr[3]), mr.z - 0.072)])
	var yo: float = o.get("yo", H + 0.03)
	var eo: float = o.get("eo", 0.2)
	var ef := func(y: float) -> float: return 0.012 + eo * pow(smoothstep(yo, hem, y), 0.85)
	var cg: Dictionary = _coat_v(k, {"keys": keys, "hem": hem, "e": ef, "fold": NN._coat_fold(k, hem, 0.036), "col": col, "lin": lin, "ny": 44, "na": 88, "round": 0.04})
	NN._coat_edge(k, cg, 0.022, 0.0055, 0.0024, col.darkened(0.12), yo)
	var csk: Callable = cg["sk"]
	var ff: Callable = cg["fold"]
	var hm := []
	for p in cg["hem"]:
		hm.append((p as Vector3) + Vector3(0, 0.014, 0))
	P._bd(k, hm, 0.0028, 0.0014, col.darkened(0.2), false, csk)
	# yan dikişler + sırt ortası dikişi
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ff, [Vector2(sg * 1.45, N - 0.07), Vector2(sg * 1.5, H + 0.1), Vector2(sg * 1.52, hem + 0.02)], 0.0024, 0.0012, 0.0012, col.darkened(0.22), csk, 8)
	Q._run(k, keys, ff, [Vector2(PI, N - 0.02), Vector2(PI, hem + 0.02)], 0.0024, 0.0012, 0.0012, col.darkened(0.22), csk, 10)
	# kollar: omuzda dolgun, bileğe uzun, ağız hafif geniş; içi astar, ağızdan görünen koyu iç kol
	var band = o.get("band", null)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.2
		var sf := func(s: float, a: float) -> float:   # omuz kökü içe incelir: kol ucu omuzda boynuz gibi kalkmaz
			return -0.014 * (1.0 - smoothstep(0.0, 0.13, s)) + 0.013 + 0.013 * smoothstep(en - 0.05, 0.95, s) + 0.0035 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.007 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.12) / 0.1, 2.0))
		P._lt(k, ar, sf, func(s, a, ins):
			return lin if ins else P._fs(col, float(sf.call(float(s), float(a))) - 0.013 - 0.013 * smoothstep(en - 0.05, 0.95, float(s)), 12.0), 0.0, 0.955, 32, 20, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, lin, 0.74, 0.955, 6, 20)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return bk.darkened(0.3) if ins else bk, 0.6, 0.965, 10, 14)
		if band != null:
			Q._ring_on(k, ar, 0.855, func(s, a): return float(sf.call(float(s), float(a))) + 0.001, 0.011, band, 0.004)
	return {"cg": cg, "keys": keys, "hem": hem, "b": b, "sk": csk, "ff": ff}


## Palto ağırlığı (parti q yöntemi): ön yüz bacağı çabuk izler, diz altında baldıra da geçer (öne kalkan uylukla etek kanat gibi dik durmaz,
## baldırla aşağı kırılır); arka yüz boy boyunca yavaş artar ve iki bacak arasına geniş yayılır (geri giden bacak kumaşı ezmez)
static func _vsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var bk: float = smoothstep(0.03, -0.08, p.z)
	var wf: float = 0.97 * pow(minf(1.0, t / 0.3), 0.4)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.65)), 0.96, smoothstep(0.6, 0.95, t))
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.006, 0.1, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var sd: String = "Left" if s >= 0.5 else "Right"
	var os: String = "Right" if s >= 0.5 else "Left"
	var ws: float = maxf(s, 1.0 - s)
	var kb: float = smoothstep(k.K + 0.06, k.K - 0.14, p.y) * lerpf(0.5, 0.55, bk) * absf(2.0 * s - 1.0)
	if kb > 0.0:
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Önü açık uzun giysi (parti n _coat kesimi, ağırlığı _vsk)
static func _coat_v(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var hem: float = o["hem"]
	var top: float = keys[0][0]
	var ef: Callable = o["e"]
	var ff: Callable = o["fold"]
	var col: Color = o["col"]
	var sk := func(p: Vector3) -> Array: return _vsk(k, p, hem)
	var e_h: float = ef.call(hem)
	var rnd: float = o.get("round", 0.07)
	var rf := func(a: float) -> float: return rnd * (1.0 - smoothstep(e_h, e_h + 0.42, absf(wrapf(a, -PI, PI))))
	var rg := func(v: float) -> Vector2:
		var e: float = ef.call(lerpf(top, hem, v))
		return Vector2(e, TAU - e)
	var cg: Dictionary = P._cl(k, {"keys": keys, "ny": o.get("ny", 40), "na": o.get("na", 88), "rng": rg, "top": func(_a): return top, "hem": func(a): return hem + float(rf.call(float(a))),
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


## Dik yaka: önde küçük aralık, üst kenarı rulo
static func _stand_collar(k, b: Dictionary, hgt: float, gap: float, col: Color, lin: Color) -> void:
	var N: float = k.N
	var nk: Vector3 = b["nk"]
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + hgt * q + 0.01, 0.014, 0.018), P._kp(nk, N + hgt * 0.5 * q, 0.018), P._kp(nk, N - 0.02, 0.03), P._kp(nk, N - 0.05, 0.05, 0.045)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 9, "na": 48, "rng": func(_v): return Vector2(gap, TAU - gap), "top": func(_a): return N + hgt * q, "hem": func(_a): return N - 0.045,
		"fold": func(a, y, _v): return 0.008 * sin(float(a) * 5.0 + float(y) * 20.0), "col": func(_a, _y, _v): return col, "inner": lin, "skin": func(p): return Q._nsk(k, p), "th": 0.006})
	P._cord(k, cg["top"], 0.0042, col.lightened(0.05), false, func(p): return Q._nsk(k, p))
	for e in [cg["ea"], cg["eb"]]:
		P._cord(k, e, 0.0036, col.darkened(0.08), false, func(p): return Q._nsk(k, p))


# ------------------------------------------------------------------ Akasuna Gaitō (ref "Gaara Outfit"): kızıl kruvaze uzun palto (sol kanat sağa biner, çift sıra siyah düğme), dik yaka,
## kolda siyah şerit, iki kahve kemer (alttaki eğik) + gümüş tokalar, sol kalçada açık kahve su kabağı, belden aşağı önü açılır
static func _palto1(k) -> void:
	var rd := Color(0.44, 0.08, 0.13)
	var lin := Color(0.24, 0.04, 0.07)
	var bk := Color(0.09, 0.09, 0.11)
	var br := Color(0.55, 0.36, 0.2)
	var mt := Color(0.3, 0.3, 0.33)
	var gd := Color(0.76, 0.62, 0.44)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var g: Dictionary = _gaara_coat(k, rd, lin, {"hem": 0.52, "yo": H + 0.04, "eo": 0.2, "band": bk})
	var keys: Array = g["keys"]
	var ff: Callable = g["ff"]
	var b: Dictionary = g["b"]
	_stand_collar(k, b, 0.055, 0.1, rd, lin)
	# kruvaze kanat: yakadan sağ göğse verev iner, sonra düz bele (kemerin altında biter)
	var fk := []
	for e in keys:
		fk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	var y0: float = N + 0.008
	var y1: float = H + 0.075
	var ed := func(y: float) -> float: return lerpf(-0.5, -0.06, smoothstep(C + 0.02, y0, y))
	var fg: Dictionary = P._cl(k, {"keys": fk, "ny": 26, "na": 22, "rng": func(v): return Vector2(float(ed.call(lerpf(y0, y1, float(v)))), 1.15), "top": func(_a): return y0, "hem": func(_a): return y1,
		"fold": func(a, y, _v): return float(ff.call(float(a), float(y))) - 0.02 * smoothstep(0.75, 1.15, float(a)), "col": func(_a, _y, _v): return rd, "gain": 5.0, "th": 0.004, "inner": lin, "skin": func(p): return k.torso_skin(p.y)})
	P._cord(k, fg["ea"], 0.0032, rd.darkened(0.25), false, func(p): return k.torso_skin(p.y))
	# çift sıra düğme: dört sıra + yakada bir çift
	var fff := func(a, y): return float(ff.call(float(a), float(y)))
	for row in [[N - 0.055, -0.2, 0.18], [C + 0.04, -0.4, 0.26], [C - 0.03, -0.4, 0.26], [C - 0.1, -0.4, 0.26], [C - 0.17, -0.4, 0.26]]:
		for a in [row[1], row[2]]:
			var e: Array = Q._spt(fk, fff, float(a), float(row[0]), 0.004)
			P._stud(k, e[0], e[1], 0.0068, bk.lightened(0.05), k.torso_skin(float(row[0])))
	# iki kemer: üstteki düz, alttaki sola doğru iner; tokalar ve uç dili
	var bks := []
	for e in keys:
		bks.append(e)
	var yb1: float = H + 0.115
	var yb2: float = H + 0.035
	_belt(k, bks, yb1, 0.0, 0.019, 0.007, br, 0.0, 84)
	_belt(k, bks, yb2, 0.016, 0.016, 0.011, br.darkened(0.05), -PI * 0.5, 84)
	var e1: Array = _belt_pt(bks, -0.06, yb1, 0.0, 0.012)
	_buckle(k, e1[0], e1[1], 0.017, 0.016, mt, k.torso_skin(yb1))
	var e2: Array = _belt_pt(bks, -0.1, yb2, 0.016, 0.016, -PI * 0.5)
	_buckle(k, e2[0], e2[1], 0.015, 0.013, mt, k.torso_skin(float((e2[0] as Vector3).y)))
	# kemer köprüleri (kumaşa dikili)
	for a in [-1.0, 0.95, PI - 0.6, PI + 0.6]:
		var ep: Array = _belt_pt(bks, a, yb1, 0.0, 0.008)
		var o2: Vector3 = ep[1]
		P._boxr(k, ep[0], Vector3.UP.cross(o2).normalized() * 0.008, Vector3(0, 0.025, 0), o2 * 0.004, br.darkened(0.12), k.torso_skin(yb1), 0.3)
	# su kabağı: sol kalçada, alt kemerden kayışla asılı
	var sw: Array = SE.El.key_at(keys, H - 0.08)
	var gx: float = float(sw[1]) + 0.04
	var gz: float = 0.02
	var bo := [["Hips", 0.7], ["LeftUpperLeg", 0.3]]
	var gp := []
	for i in 12:
		gp.append(Vector3(gx, H - 0.0 - 0.15 * float(i) / 11.0, gz))
	P._tb(k, gp, func(s, _a):
		var sv: float = float(s)
		return 0.006 + 0.022 * exp(-pow((sv - 0.3) / 0.13, 2.0)) + 0.034 * exp(-pow((sv - 0.72) / 0.2, 2.0)) * (1.0 - 0.6 * smoothstep(0.9, 1.0, sv)), func(s, a, _p):
		return gd.darkened(0.18) if cos(float(a)) < -0.4 else gd.lightened(0.05 * float(sin(float(a) * 5.0 + float(s) * 9.0) > 0.7)), func(_s, _p): return bo, 14)
	P._tb(k, [Vector3(gx - 0.012, yb2 + 0.005, gz + 0.006), Vector3(gx - 0.002, H - 0.01, gz + 0.004), Vector3(gx, H - 0.025, gz)], func(_s, _a): return 0.0045, func(_s, _a, _p): return br.darkened(0.2), func(_s, _p): return bo, 6)
	P._boxr(k, Vector3(gx, H - 0.002, gz), Vector3(0.008, 0, 0), Vector3(0, 0.006, 0), Vector3(0, 0, 0.008), br.darkened(0.3), bo, 0.4)


# ------------------------------------------------------------------ Akasuna Gaitō Ni (ref "Gaara Outfit 2"): yüksek yakalı kızıl uzun palto (önü kapalı, belden aşağı açılır),
## gri gövde zırhı: sol omuzdan geçen geniş kayış, göğüs plakası + iki tokalı kayış, sırt plakası, belde çapraz sarılı iki bant
static func _palto2(k) -> void:
	var rd := Color(0.46, 0.09, 0.13)
	var lin := Color(0.24, 0.04, 0.07)
	var gy := Color(0.6, 0.61, 0.68)
	var mt := Color(0.36, 0.37, 0.42)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var g: Dictionary = _gaara_coat(k, rd, lin, {"hem": 0.6, "yo": H + 0.0, "eo": 0.14})
	var keys: Array = g["keys"]
	var ff: Callable = g["ff"]
	var b: Dictionary = g["b"]
	var ch: Vector3 = b["ch"]
	_stand_collar(k, b, 0.085, 0.06, rd, lin)
	# ön kapanış dikişi
	var csk := func(p): return k.torso_skin(p.y)
	Q._run(k, keys, ff, [Vector2(0.0, N + 0.0), Vector2(0.0, H + 0.02)], 0.0036, 0.0016, 0.0018, rd.darkened(0.3), csk, 12)
	# zırh yüzeyi: paltonun üstünde
	var gk := []
	for e in keys:
		if float(e[0]) > H - 0.05:
			gk.append([e[0], float(e[1]) + 0.012, float(e[2]) + 0.012, float(e[3]) - 0.012])
	var cc := Vector3(0.0, C, 0.0)
	var tsk := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	for front in [true, false]:
		var xs: float = -ch.x * (0.62 if front else 0.66)
		var xe: float = ch.x * (0.72 if front else 0.66)
		var yt: float = C + (0.05 if front else 0.03)
		var yb: float = C - 0.165
		J._pil(k, func(u, v): return P._fp(gk, lerpf(xs, xe, float(u)), lerpf(yt, yb, float(v)) + 0.012 * sin(float(u) * PI) * (1.0 - float(v)), front, 0.0)[0], 14, 12, 0.009, gy, cc, 0.12, tsk, func(u, v, ed):
			var c0: Color = gy.lightened(0.06) if float(v) < 0.12 else gy
			return c0.darkened(0.22) if float(ed) < 0.03 else c0)
	# sol omuz kayışı: önden arkaya geniş
	var ok := []
	for e in gk:
		ok.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	ok.push_front(P._kp(b["nk"], N + 0.03, 0.03))
	P._over(k, ok, ch.x * 0.45, C + 0.03, C + 0.01, 0.036, 0.007, 0.007, gy.lightened(0.03))
	# iki tokalı kayış: göğsü saran
	var sks := []
	for e in gk:
		sks.append([e[0], float(e[1]) + 0.009, float(e[2]) + 0.009, float(e[3]) - 0.009])
	for yb in [C - 0.0, C - 0.095]:
		_belt(k, sks, yb, 0.0, 0.013, 0.0, gy.darkened(0.12), 0.0, 72)
		var e: Array = _belt_pt(sks, -0.04, yb, 0.0, 0.004)
		_buckle(k, e[0], e[1], 0.019, 0.016, mt, k.torso_skin(yb))
		var e3: Array = _belt_pt(sks, 0.22, yb, 0.0, 0.004)
		P._boxr(k, e3[0], Vector3.UP.cross(e3[1]).normalized() * 0.022, Vector3(0, 0.0105, 0), (e3[1] as Vector3) * 0.0028, gy.darkened(0.2), k.torso_skin(yb), 0.3)
	# bel: çapraz sarılı iki bant
	var wk := []
	for e in keys:
		wk.append(e)
	_belt(k, wk, H + 0.075, 0.0, 0.017, 0.01, gy, 0.0, 84)
	_belt(k, wk, H + 0.065, 0.028, 0.013, 0.02, gy.darkened(0.08), 0.6, 84)


# ------------------------------------------------------------------ Suna Kodomo (ref "Gaara Outfit (Young Ver.)"): kısa kollu siyah tulum (kol ağzı file), sağ omuzdan sol kalçaya geniş kırık beyaz şal,
## bele dolanır ve önden dize sarkar; sol omuzdan sağ kalçaya kahve kayış (metal bağlantılar), sağ kalçada Suna alın koruyuculu kılıf, bol siyah pantolon, bilek sargısı
static func _kum(k) -> void:
	var dk := Color(0.15, 0.12, 0.14)
	var wh := Color(0.9, 0.89, 0.85)
	var lv := Color(0.62, 0.6, 0.68)
	var br := Color(0.42, 0.26, 0.17)
	var mt := Color(0.72, 0.73, 0.76)
	var ng := Color(0.55, 0.55, 0.58)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var ik: Array = P._inner(k, b, func(_i, j, _p): return dk.lightened(0.04) if j < 3 else dk, 0.008)
	K._seat(k, b, dk)
	var rleg := {}
	var nr := []
	for i in 40:
		nr.append(Q._spt(ik, Callable(), TAU * i / 40.0 - PI, N + 0.045, 0.003)[0])
	P._cord(k, nr, 0.004, dk.lightened(0.06), true, func(p): return Q._nsk(k, p))
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var sv: float = 1.4 if sd == "Left" else 2.5
		R._arm_skin(k, ar, 0.22)
		var sh := func(s: float, a: float) -> float: return 0.012 + 0.006 * smoothstep(0.05, 0.25, s) + 0.003 * P._lf(s, a, sv)
		P._lt(k, ar, sh, func(s, a, ins): return dk.darkened(0.45) if ins else P._fs(dk, float(sh.call(float(s), float(a))) - 0.016, 18.0), 0.0, 0.28, 14, 18, 0.03)
		P._lt(k, ar, func(s, a): return float(sh.call(float(s), float(a))) + 0.002, func(_s, _a, ins): return dk.darkened(0.45) if ins else dk.lightened(0.06), 0.255, 0.283, 3, 18)
		# file kol ağzı: ten üstünde çapraz ağ, altta gri kenar
		P._net_limb(k, ar, 0.26, 0.41, 0.003, 12, 0.022, 0.0016, ng)
		Q._ring_on(k, ar, 0.41, func(_s, _a): return 0.002, 0.006, ng.darkened(0.15), 0.003)
		var ad: Callable = Q._baggy(k, le, dk, dk.darkened(0.08), 0.02, 0.05, 0.8, sv)
		if sd == "Right":
			rleg["le"] = le
			rleg["ad"] = ad
		P._lt(k, le, func(s, a): return float(ad.call(float(s), float(a))) + 0.002, func(_s, _a, _i): return wh.darkened(0.16), 0.84, 0.985, 8, 16)
		P._wraps(k, le, 0.85, 0.975, 7, float(ad.call(0.92, 0.0)) + 0.008, 0.0125, wh, 0.008)
	# şal yüzeyi: tulumdan biraz dışarıda
	var sk_s := []
	for e in ik:
		sk_s.append([e[0], float(e[1]) + 0.006, float(e[2]) + 0.006, float(e[3]) - 0.006])
	var tsk := func(p: Vector3) -> Array: return k.torso_skin(maxf(p.y, H + 0.005))
	var sa := Vector2(-ch.x * 0.6, N - 0.065)
	var sb := Vector2(wa.x * 0.82, H + 0.06)
	_cloth_band(k, sk_s, [sa, sa.lerp(sb, 0.5) + Vector2(0.0, -0.01), sb], true, 0.052, 0.003, 3.0, 0.009, wh, lv, tsk, 6, 10)
	_cloth_band(k, sk_s, [Vector2(-ch.x * 0.6, N - 0.06), Vector2(wa.x * 0.85, H + 0.06)], false, 0.05, 0.003, 3.0, 0.009, wh, lv, tsk, 8, 10)
	P._over(k, sk_s, -ch.x * 0.6, N - 0.06, N - 0.055, 0.04, 0.004, 0.007, wh.darkened(0.03))
	# bele dolanan kat
	var wk := [P._kp(wa, H + 0.12, 0.012), P._kp(k.M(H + 0.02, 0.3), H + 0.02, 0.016)]
	P._sash(k, wk, H + 0.07, 0.03, 0.006, wh, 0.18)
	P._sash(k, wk, H + 0.062, 0.012, 0.013, wh.lerp(lv, 0.3), 0.1)
	# önden sarkan uç: belden sağ uyluğun önüne dizine dek dökülür; uyluğun bol paçasının üstünde kurulur (koşuda paça kumaşı delmez)
	var le: Dictionary = rleg["le"]
	var ad2: Callable = rleg["ad"]
	var kn: float = le["kn"]
	var prow := []
	var pcol := []
	var pss := []
	var nv := 16
	var nu := 12
	for j in nv + 1:
		var v := float(j) / nv
		var s: float = lerpf(-0.12, kn + 0.02, v)
		var ro := []
		var cr := []
		for i in nu + 1:
			var u := float(i) / nu
			var a: float = lerpf(-0.95, 0.35, u) - 0.12 * v
			var rid: float = sin(u * PI * 3.5 + v * 1.2)
			var l: float = float(ad2.call(maxf(0.0, s), a)) + 0.012 + 0.012 * v + 0.007 * rid * smoothstep(0.0, 0.25, v) + 0.03 * (1.0 - smoothstep(-0.12, 0.02, s))
			ro.append(Q._ls(le, s, a, l)[0])
			cr.append(wh.lerp(lv, clampf(-rid, 0.0, 1.0) * 0.6).darkened(0.12 if i == 0 or i == nu or j == nv else 0.0))
		prow.append(ro)
		pcol.append(cr)
		pss.append(s)
	var pz := []
	for j in nv + 1:
		pz.append(P._lskin(le, pss[j]))
	var jr := {}
	for j in nv + 1:
		for i in nu + 1:
			jr[(prow[j][i] as Vector3)] = pz[j]
	_emit(k, prow, pcol, func(p): return jr.get(p, pz[0]), Vector3(0, 0, 1))
	# kahve kayış: sol omuzdan sağ kalçaya, şalın üstünden aşar
	var ka := Vector2(ch.x * 0.5, N - 0.03)
	var kb := Vector2(-wa.x * 0.95, H + 0.0)
	var lf := func(q: Vector2) -> float: return 0.007 + 0.014 * exp(-pow(_seg_d(q, sa, sb) / 0.05, 2.0))
	_strap2(k, sk_s, [ka, kb], true, 0.019, lf, 0.004, br, tsk, 14)
	_strap2(k, sk_s, [ka, Vector2(-wa.x * 0.95, H + 0.02)], false, 0.019, func(q): return 0.007 + 0.014 * exp(-pow(_seg_d(q, Vector2(-ch.x * 0.6, N - 0.06), Vector2(wa.x * 0.85, H + 0.06)) / 0.05, 2.0)), 0.004, br, tsk, 14)
	P._over(k, sk_s, ch.x * 0.5, N - 0.035, N - 0.035, 0.019, 0.01, 0.004, br)
	# metal bağlantılar
	for t in [0.18, 0.56, 0.86]:
		var q: Vector2 = ka.lerp(kb, t)
		var e: Array = P._fp(sk_s, q.x, q.y, true, float(lf.call(q)) + 0.005)
		var o: Vector3 = e[1]
		var dirv := (P._fp(sk_s, kb.x, kb.y, true)[0] as Vector3) - (P._fp(sk_s, ka.x, ka.y, true)[0] as Vector3)
		P._boxr(k, e[0], dirv.normalized() * 0.01, o.cross(dirv).normalized() * 0.022, o * 0.003, mt.darkened(0.15), k.torso_skin(q.y), 0.3)
	# sağ kalçada kılıf + Suna alın koruyucusu
	var he: Array = P._fp([P._kp(k.M(H, 0.3), H + 0.02, 0.02), P._kp(b["hp"], H - 0.12, 0.026)], -wa.x * 0.98, H - 0.04, true, 0.03)
	var hc: Vector3 = he[0]
	var ho: Vector3 = he[1]
	var hb := [["Hips", 0.7], ["RightUpperLeg", 0.3]]
	var hri: Vector3 = Vector3.UP.cross(ho).normalized()
	P._boxr(k, hc, hri * 0.04, Vector3(0, 0.05, 0), ho * 0.022, br, hb, 0.3)
	P._boxr(k, hc + Vector3(0, 0.038, 0) + ho * 0.014, hri * 0.042, Vector3(0, 0.014, 0), ho * 0.012, br.darkened(0.15), hb, 0.3)
	var pc: Vector3 = hc + Vector3(0, -0.028, 0) + ho * 0.025
	P._boxr(k, pc, hri * 0.04, Vector3(0, 0.018, 0), ho * 0.004, mt, hb, 0.25)
	_m_suna(k, _plane(pc + ho * 0.004, hri, Vector3.UP, ho), 0.013, 0.0015, 0.0008, mt.darkened(0.4), func(_p): return hb)


# ------------------------------------------------------------------ Gai tulumu ortak kesim (ref "Guy Outfit 2", "Guy Outfit 3"): boğazlı tulum, dar paça, dizaltından bileğe fitilli turuncu tozluk,
## sağ uylukta iki beyaz sargı + kılıf
static func _guy_base(k, sh: Color, pouch: Color) -> Dictionary:
	var og := Color(0.93, 0.52, 0.16)
	var wh := Color(0.92, 0.91, 0.88)
	var N: float = k.N
	var b: Dictionary = P._base(k)
	var nk: Vector3 = b["nk"]
	var L: Dictionary = J._suit(k, b, sh, sh.darkened(0.03), {"bag": 0.008, "tuck": 0.24, "seed": 1.3, "cuff": sh.lightened(0.04)})
	# boğazlı yaka: boyna sarılan kalın rulo, yatay fitil
	var q: float = Q._hq(k)
	var ck := [P._kp(nk, N + 0.075 * q + 0.01, 0.008, 0.01), P._kp(nk, N + 0.03 * q, 0.01), P._kp(nk, N - 0.03, 0.022), P._kp(nk, N - 0.06, 0.04, 0.035)]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 44, "top": func(_a): return N + 0.075 * q, "hem": func(_a): return N - 0.05,
		"fold": func(_a, y, _v): return 0.012 * sin(float(y) * 260.0) * smoothstep(N - 0.03, N, float(y)), "col": func(_a, _y, _v): return sh.lightened(0.03), "gain": 4.0, "skin": func(p): return Q._nsk(k, p), "th": 0.006})
	P._cord(k, cg["top"], 0.0045, sh.lightened(0.06), true, func(p): return Q._nsk(k, p))
	for sd in ["Left", "Right"]:
		var e: Dictionary = L[sd]
		var le: Dictionary = e["le"]
		var pf: Callable = e["pf"]
		var kn: float = le["kn"]
		# tozluk: dikey fitil, üstte kalın ağız, bilekte yığılma
		var lg := func(s: float, a: float) -> float:
			var u: float = clampf((s - kn - 0.06) / (0.995 - kn - 0.06), 0.0, 1.0)
			var rib: float = 0.0046 * cos(a * 8.0 + (0.4 if sd == "Left" else 1.3)) * (1.0 - 0.4 * smoothstep(0.75, 0.95, u))
			var cuff: float = 0.012 * exp(-pow((u - 0.03) / 0.035, 2.0))
			var sl: float = smoothstep(0.62, 0.92, u) * (0.009 + 0.006 * sin(u * 36.0 + a * 1.5))
			return float(pf.call(s, a)) + 0.012 + 0.006 * u + rib + cuff + sl
		J.P._lt(k, le, lg, func(s, a, ins):
			if ins:
				return og.darkened(0.45)
			var rb: float = cos(float(a) * 8.0 + (0.4 if sd == "Left" else 1.3))
			return og.darkened(clampf(-rb, 0.0, 1.0) * 0.22).lightened(clampf(rb, 0.0, 1.0) * 0.05), kn + 0.06, 0.995, 30, 32, 0.03)
	# sağ uyluk: iki beyaz sargı, aralarında kılıf kayışı, dışta kılıf
	var re: Dictionary = L["Right"]
	var rl: Dictionary = re["le"]
	var rpf: Callable = re["pf"]
	var s0: float = float(rl["kn"]) * 0.5
	for s in [s0 - 0.02, s0 - 0.004, s0 + 0.07, s0 + 0.086]:
		k.wrap_turn(J.P._lp(rl, s), J.P._ld(rl, s), J.P._lr(rl, s) + float(rpf.call(s, 0.0)) + 0.006, 0.0105, 0.004, wh.darkened(0.05 * float(int(s * 100.0) % 2)), J.P._lskin(rl, s))
	k.wrap_turn(J.P._lp(rl, s0 + 0.035), J.P._ld(rl, s0), J.P._lr(rl, s0 + 0.035) + float(rpf.call(s0 + 0.035, 0.0)) + 0.005, 0.012, 0.0, pouch, J.P._lskin(rl, s0 + 0.035))
	var a: float = J._outer_a(rl, s0 + 0.04, Vector3(-1.0, 0.0, 0.2))
	var e2: Array = J._lsurf(rl, s0 + 0.05, a, float(rpf.call(s0 + 0.05, a)) + 0.024)
	var o: Vector3 = e2[1]
	var d: Vector3 = J.P._ld(rl, s0)
	var bo := [["RightUpperLeg", 1.0]]
	J.P._boxr(k, e2[0], o.cross(d).normalized() * 0.034, -d * 0.07, o * 0.018, pouch, bo)
	J.P._boxr(k, (e2[0] as Vector3) + o * 0.016 - d * 0.045, o.cross(d).normalized() * 0.036, -d * 0.024, o * 0.005, pouch.darkened(0.15), bo, 0.2)
	P._stud(k, (e2[0] as Vector3) + o * 0.022 - d * 0.03, o, 0.0045, pouch.lightened(0.25), bo)
	return {"L": L, "b": b}


## Yaprak plakalı kemer plakası (metal, kabartma arma)
static func _leaf_plate(k, c: Vector3, o: Vector3, w: float, h: float, mt: Color, bones: Array) -> void:
	var up := (Vector3.UP - o * Vector3.UP.dot(o)).normalized()
	var ri := up.cross(o).normalized()
	P._boxr(k, c, ri * w, up * h, o * 0.004, mt, bones, 0.22)
	_m_leaf(k, _plane(c + o * 0.004, ri, up, o), h * 0.62, 0.0018, 0.0009, mt.darkened(0.42), func(_p): return bones)
	for sg in [1.0, -1.0]:
		P._stud(k, c + ri * sg * w * 0.82 + o * 0.004, o, 0.0028, mt.darkened(0.2), bones)


## Konoha yelek omuz yastıkları + çıtçıt
static func _shoulder_pads(k, vk: Array, ve: Color, N: float) -> void:
	var cc := Vector3(0.0, k.C, 0.0)
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.72, 2.32, float(v))
			var y: float = lerpf(N - 0.012, N - 0.078, float(u))
			return P._sa(vk, a, y, 0.0)[0]
		J._pil(k, surf, 12, 14, 0.012, ve.lightened(0.05), cc, 0.16, func(p): return k.torso_skin(p.y))
		var e: Vector3 = surf.call(0.6, 0.18)
		var o: Vector3 = J._nrm(surf, 0.6, 0.18, cc)
		P._fan(k, e + o * 0.0145, o, Vector3.UP, 0.0085, Callable(), func(u2, v2): return ve.darkened(0.42) if sqrt(u2 * u2 + v2 * v2) > 0.7 else ve.lightened(0.28), k.torso_skin(N - 0.04), 3, 14)


# ------------------------------------------------------------------ Midori Tsunagi (ref "Guy Outfit 2"): yeşil tulum, fermuarı açık açık yeşil yelek (iki parçalı dik yaka, omuz yastıkları, parşömen cepleri,
## alt rulo, sırtta kırmızı Uzumaki girdabı), altta yaprak plakalı kırmızı kemer, kalça arkasında kahve çanta, sağ uylukta lacivert kılıf, turuncu tozluk
static func _guy2(k) -> void:
	var sh := Color(0.1, 0.23, 0.15)
	var ve := Color(0.45, 0.58, 0.42)
	var rd := Color(0.66, 0.15, 0.15)
	var mt := Color(0.76, 0.77, 0.79)
	var bn := Color(0.45, 0.31, 0.19)
	var zp := Color(0.86, 0.87, 0.86)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var g: Dictionary = _guy_base(k, sh, Color(0.12, 0.15, 0.3))
	var b: Dictionary = g["b"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var hp: Vector3 = b["hp"]
	# kırmızı kemer + yaprak plakası (açık yelek arasından görünür)
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var kb := [P._kp(bl, H + 0.1, 0.014), P._kp(bl, H - 0.0, 0.016)]
	P._sash(k, kb, H + 0.05, 0.02, 0.0, rd, 0.12)
	var fc: Array = P._sa(kb, 0.0, H + 0.05, 0.014)
	_leaf_plate(k, fc[0], fc[1], 0.042, 0.022, mt, [["Hips", 1.0]])
	# kalça arkasında çanta
	var bk2 := [P._kp(hp, H + 0.02, 0.016), P._kp(hp, H - 0.12, 0.016)]
	var e2: Array = P._fp(bk2, 0.0, H - 0.055, false, 0.024)
	P._boxr(k, e2[0], Vector3(0.075, 0, 0), Vector3(0, 0.042, 0), (e2[1] as Vector3) * 0.024, bn, [["Hips", 1.0]])
	P._boxr(k, (e2[0] as Vector3) + Vector3(0, 0.032, 0) + (e2[1] as Vector3) * 0.012, Vector3(0.078, 0, 0), Vector3(0, 0.016, 0), (e2[1] as Vector3) * 0.016, bn.darkened(0.15), [["Hips", 1.0]])
	P._stud(k, (e2[0] as Vector3) + Vector3(0, 0.022, 0) + (e2[1] as Vector3) * 0.03, e2[1], 0.005, mt, [["Hips", 1.0]])
	# açık yelek: önü fermuar aralığında açık
	var vk := [P._kp(nk, N + 0.005, 0.03), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.125, 0.034), P._kp(wa, H + 0.04, 0.042)]
	var ve0: float = 0.16
	var hem_v: float = H + 0.045
	var vf := func(a: float, y: float, _v: float) -> float:
		var aw: float = absf(a)
		return -0.016 * exp(-pow((aw - 1.72) / 0.05, 2.0)) + 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.1, y)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 40, "na": 84, "rng": func(_v): return Vector2(ve0, TAU - ve0), "top": func(_a): return N + 0.005, "hem": func(_a): return hem_v,
		"fold": vf, "col": func(_a, _y, _v): return ve, "gain": 7.0, "th": 0.007, "inner": ve.darkened(0.35), "skin": func(p): return k.torso_skin(p.y)})
	# alt rulo: yelek ucunda dolgun bant
	var hr := []
	for p in vg["hem"]:
		hr.append((p as Vector3) + Vector3(0, 0.014, 0) + P._out(p) * 0.006)
	P._tb(k, hr, func(s, _a): return 0.018 * (0.4 + 0.6 * pow(sin(clampf(float(s), 0.0, 1.0) * PI), 0.08)), func(_s, a, _p): return ve.darkened(0.2) if cos(float(a)) < -0.3 else ve.lightened(0.03), func(_s, p): return k.torso_skin(p.y), 10)
	# fermuar dişleri: iki kenarda
	for ed in [vg["ea"], vg["eb"]]:
		P._cord(k, ed, 0.0035, ve.darkened(0.15), false, func(p): return k.torso_skin(p.y))
		var n: int = (ed as Array).size()
		for j in range(2, n - 2, 2):
			var p: Vector3 = ed[j]
			var o: Vector3 = P._out(p)
			var tw: Vector3 = Vector3(signf(p.x) * -1.0, 0.0, 0.0)
			P._boxr(k, p + tw * 0.004 + o * 0.002, tw * 0.004, Vector3(0, 0.0035, 0), o * 0.0022, zp, k.torso_skin(p.y), 0.3)
	# iki parçalı dik yaka, omuz yastıkları, parşömen cepleri
	J._collar(k, [P._kp(nk, N + 0.092, 0.03, 0.04), P._kp(nk, N + 0.05, 0.03, 0.038), P._kp(nk, N - 0.02, 0.05, 0.05)], 0.82, 0.32, ve, ve.lightened(0.08))
	_shoulder_pads(k, vk, ve, N)
	for sg in [1.0, -1.0]:
		J._pouch(k, vk, sg * ch.x * 0.56, C - 0.115, ch.x * 0.48, 0.135, 3, ve.darkened(0.06), ve.lightened(0.14), sg * -0.012)
	# sırtta kırmızı Uzumaki girdabı
	J._swirl(k, vk, 0.0, C - 0.07, 0.075, rd, false)


# ------------------------------------------------------------------ Midori Tsunagi Ni (ref "Guy Outfit 3"): koyu yeşil tulum, önü fermuarlı kapalı yeşil yelek (boyna kalkan açık yeşil omuz plakaları + perçin),
## yeleğin üstünden geçen yaprak plakalı geniş kırmızı kemer, kemer altında yuvarlak etek bölmesi, sağ uylukta siyah kılıf, turuncu tozluk
static func _guy3(k) -> void:
	var sh := Color(0.07, 0.17, 0.1)
	var ve := Color(0.2, 0.42, 0.24)
	var pl := Color(0.42, 0.62, 0.46)
	var rd := Color(0.58, 0.13, 0.16)
	var mt := Color(0.76, 0.77, 0.79)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var g: Dictionary = _guy_base(k, sh, Color(0.08, 0.08, 0.1))
	var b: Dictionary = g["b"]
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var hp: Vector3 = b["hp"]
	# kapalı yelek: kalçaya iner, kemer altında hafif açılır
	var hem_v: float = H - 0.04
	var vk := [P._kp(nk, N + 0.005, 0.028), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], P._kp(ch, C - 0.03, 0.028), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.0, 0.036), P._kp(hp, hem_v, 0.042)]
	var vf := func(a: float, y: float, _v: float) -> float:
		var aw: float = absf(a)
		var g0: float = -0.02 * exp(-pow(a / 0.025, 2.0)) * smoothstep(N - 0.02, N - 0.05, y)
		var sd: float = -0.014 * exp(-pow((aw - 1.68) / 0.05, 2.0))
		var lo: float = 0.012 * sin(a * 9.0 + 0.6) * smoothstep(H + 0.06, hem_v, y)
		return g0 + sd + lo + 0.005 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.12, y)
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 46, "na": 84, "top": func(_a): return N + 0.005, "hem": func(a): return hem_v + 0.012 * pow(absf(sin(float(a))), 2.0),
		"fold": vf, "col": func(_a, _y, _v): return ve, "gain": 7.0, "th": 0.007, "inner": ve.darkened(0.35), "skin": func(p): return P._hs(k, p)})
	P._cur_hem = hem_v
	var hr := []
	for p in vg["hem"]:
		hr.append((p as Vector3) + Vector3(0, 0.008, 0))
	P._bd(k, hr, 0.006, 0.003, pl, true, func(p): return P._hs(k, p))
	var tk := func(p): return k.torso_skin(p.y)
	var vff := func(a, y): return float(vf.call(float(a), float(y), 0.0))
	# fermuar + alt bölme dikişi
	Q._run(k, vk, vff, [Vector2(0.0, N - 0.0), Vector2(0.0, H + 0.12)], 0.0032, 0.0018, 0.002, pl.lightened(0.05), tk, 14)
	Q._run(k, vk, vff, [Vector2(0.0, H + 0.06), Vector2(0.0, hem_v + 0.012)], 0.0028, 0.0018, 0.0018, pl, func(p): return P._hs(k, p), 6)
	for sg in [1.0, -1.0]:
		Q._run(k, vk, vff, [Vector2(sg * 1.5, N - 0.08), Vector2(sg * 1.55, H + 0.1)], 0.0026, 0.0015, 0.0014, ve.darkened(0.25), tk, 8)
	# omuz plakaları: boyna kalkan, perçinli
	var cc := Vector3(0.0, C, 0.0)
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.5, 2.35, float(v))
			var y: float = lerpf(N + 0.03 * (1.0 - smoothstep(0.0, 0.35, float(v))), N - 0.085, float(u))
			var e: Array = Q._spt(vk, vff, a, minf(y, N + 0.004), 0.004 + 0.02 * (1.0 - smoothstep(0.0, 0.35, float(v))) * (1.0 - float(u)))
			return (e[0] as Vector3) + Vector3(0, maxf(0.0, y - N - 0.004), 0)
		J._pil(k, surf, 12, 14, 0.011, pl, cc, 0.14, tk)
		var e: Vector3 = surf.call(0.55, 0.85)
		var o: Vector3 = J._nrm(surf, 0.55, 0.85, cc)
		P._stud(k, e + o * 0.011, o, 0.0055, pl.darkened(0.25), k.torso_skin(e.y))
	# omuz parçalarının boyna kalkan kanatları: önü geniş açık
	J._collar(k, [P._kp(nk, N + 0.085, 0.034, 0.042), P._kp(nk, N + 0.045, 0.034, 0.04), P._kp(nk, N - 0.025, 0.055, 0.052)], 1.05, 0.62, pl, pl.lightened(0.08), 0.006)
	# geniş kırmızı kemer + yaprak plakası
	var bks := []
	for e in vk:
		bks.append(e)
	var yb: float = H + 0.095
	_belt(k, bks, yb, 0.0, 0.032, 0.011, rd, 0.0, 84)
	var fc: Array = _belt_pt(bks, 0.0, yb, 0.0, 0.017)
	_leaf_plate(k, fc[0], fc[1], 0.05, 0.026, mt, k.torso_skin(yb))
