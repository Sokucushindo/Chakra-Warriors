extends RefCounted
## Elle modellenmiş setler, parti ae: ss_gelinlik, ss_kizil_kayis, ss_kagit_melek, ss_yeni_nesil, ss_yeni_nesil2, ss_genjutsu_sargi. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/{hinata_outfit_bridal_ver, koji_kashin_outfit, konan_outfit_young_ver, konohamaru_outfit, konohamaru_outfit_2, kurenai_outfit} + refs/outfits_ss/all/<ad>/.
## Kumaş / uzuv yardımcıları parti e (P), q (Q), k (K), j (J), x (X), y (Y), v (V), r (R), z (Z), g (G), aa (AA), t (T) dosyalarından. Burada: sarılı bant (_wband),
## dikenli kenar çizgisi, yere inen gelinlik ağırlığı (_dsk) ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const V = preload("res://scripts/actors/set_el_v.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const G = preload("res://scripts/actors/set_el_g.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const T = preload("res://scripts/actors/set_el_t.gd")

const DONE := ["ss_gelinlik", "ss_kizil_kayis", "ss_kagit_melek", "ss_yeni_nesil", "ss_yeni_nesil2", "ss_genjutsu_sargi"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_gelinlik": _gelinlik(k)
		"ss_kizil_kayis": _kayis(k)
		"ss_kagit_melek": _kami(k)
		"ss_yeni_nesil": _shinsedai(k)
		"ss_yeni_nesil2": _haori(k)
		"ss_genjutsu_sargi": _genso(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Sarılı bant: (a, yf(a)) yolu boyunca yüzeye binen kalın bez şerit; iki ucu alttaki kumaşa iner. under: alttaki katın kalkışı, lift: bandın tepesi.
## Bantlar aynı yüzeyin (keys + ff) üstünde, aynı ağırlıkla: kumaşla birlikte açılır, alttaki kattan ayrılmaz.
static func _wband(k, keys: Array, ff: Callable, a0: float, a1: float, yf: Callable, hw: float, under: float, lift: float, col: Color, skinf: Callable, n := 36, nv := 6, tuck0 := true, tuck1 := true) -> void:
	var rows := []
	var cc := []
	for j in n + 1:
		var u := float(j) / n
		var a := lerpf(a0, a1, u)
		var yc: float = yf.call(a)
		var ef: float = (smoothstep(0.0, 0.08, u) if tuck0 else 1.0) * (smoothstep(1.0, 0.92, u) if tuck1 else 1.0)
		var ro := []
		var cr := []
		for i in nv + 1:
			var v := float(i) / nv * 2.0 - 1.0
			var bump: float = 1.0 - pow(absf(v), 3.0)
			var l: float = under + (lift - under) * ef * (0.3 + 0.7 * bump)
			ro.append(Q._spt(keys, ff, a, yc + v * hw, l)[0])
			var fv: float = ff.call(wrapf(a, -PI, PI), yc) if ff.is_valid() else 0.0
			cr.append(P._fs(col, fv, 5.0).darkened(0.16 * (1.0 - bump)))
		rows.append(ro)
		cc.append(cr)
	var p0: Vector3 = rows[1][0]
	Q._mesh(k, rows, false, func(i, j, _p): return cc[j][i], func(_i, _j, p): return skinf.call(p), Vector3(p0.x, 0.0, p0.z).normalized())


## Bandın kenarında kabartma koyu çizgi; th > 0 ise üstünde aralıklı küçük dikenler (iki yana sivri üçgen)
static func _edge_line(k, keys: Array, ff: Callable, a0: float, a1: float, yf: Callable, lift: float, hw: float, col: Color, skinf: Callable, n := 30, th := 0.0, every := 3) -> void:
	var pts := []
	var ou := []
	for j in n + 1:
		var a := lerpf(a0, a1, float(j) / n)
		var e: Array = Q._spt(keys, ff, a, yf.call(a), lift)
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, 0.0016, col, false, skinf)
	if th <= 0.0:
		return
	for j in range(1, n, every):
		var p: Vector3 = pts[j]
		var o: Vector3 = ou[j]
		var tg: Vector3 = ((pts[j + 1] as Vector3) - (pts[j - 1] as Vector3)).normalized()
		var sd: Vector3 = o.cross(tg).normalized() * (1.0 if (j / every) % 2 == 0 else -1.0)
		var tp := [p, p + sd * th * 0.5 + tg * th * 0.25, p + sd * th + tg * th * 0.55]
		Y._ribbon(k, tp, [o, o, o], func(t): return lerpf(0.0034, 0.0004, float(t)), 0.0016, col, skinf)


## Uzun kollu kumaş kol (kıvrımlı, s1'de biter). Döner: yarıçap ekleme işlevi
static func _sl(k, ar: Dictionary, col: Color, s1: float, sv: float, add0 := 0.009) -> Callable:
	return X._sleeve(k, ar, col, s1, sv, add0)


# ------------------------------------------------------------------ Akaobi Shōzoku (ref Shinobi Striker "Koji Kashin Outfit"): bele inen kapalı kızıl ceket, koyu dik boğaz, sağdan inen siyah
## kapama bandı + üç kahve kayış ve gümüş toka, üst kolda üç gri bant, dirsekten bileğe koyu gri kolluk; kızıl kapri (kıvrık gri paça), kahve kemer,
## sol kalçadan sağ uyluğa inen çapraz kemer + uyluk kayışı ve kılıf, sol kalçada kese, baldırda siyah çorap
static func _kayis(k) -> void:
	var cr := Color(0.369, 0.094, 0.141)
	var pc := Color(0.345, 0.086, 0.125)
	var dk := Color(0.12, 0.12, 0.16)
	var bl := Color(0.07, 0.07, 0.08)
	var st := Color(0.33, 0.22, 0.15)
	var lb := Color(0.5, 0.37, 0.27)
	var mt := Color(0.82, 0.83, 0.86)
	var gb := Color(0.64, 0.65, 0.7)
	var gg := Color(0.29, 0.29, 0.32)
	var sc := Color(0.11, 0.11, 0.125)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var tsk := func(p): return k.torso_skin(p.y)
	# koyu dik boğaz (içteki boğazlı giysi)
	Z._stand(k, b, 0.06, 0.004, dk)
	K._seat(k, b, pc)
	var legs := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var kn: float = le["kn"]
		var en: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.6
		# kapri: baldır ortasında biter, kıvrık gri paça, altında siyah çorap
		var s1: float = kn + 0.21
		var pa: Callable = K._pant(k, le, pc, 0.014, 0.012, s1, sv)
		X._roll(k, le, s1 - 0.045, s1 + 0.006, pa, 0.007, gb.darkened(0.12), sv)
		P._lt(k, le, func(s, a): return 0.0035 + 0.001 * sin(float(a) * 4.0 + float(s) * 40.0), func(_s, _a, ins): return sc.darkened(0.3) if ins else sc, s1 - 0.05, 0.99, 14, 18)
		legs[sd] = [le, pa]
		# kol: bileğe inen kızıl kol, üst kolda üç gri bant, ön kolda koyu gri kolluk (bilekte kızıl ağız görünür)
		var sl: Callable = X._sleeve(k, ar, cr, 0.975, sv, 0.009)
		for i in 3:
			Q._ring_on(k, ar, 0.27 + 0.045 * i, sl, 0.011, gb.darkened(0.06 * float(i % 2)), 0.0045)
		var gf := func(s: float, a: float) -> float: return float(sl.call(s, a)) * 0.4 + 0.012 + 0.003 * smoothstep(en + 0.12, en + 0.07, s) + 0.0015 * sin(a * 2.0 + sv)
		P._lt(k, ar, gf, func(s, a, ins): return gg.darkened(0.35) if ins else gg.lightened(0.05 * float(float(s) < en + 0.1)).darkened(0.08 * maxf(0.0, -cos(float(a)))), en + 0.06, 0.935, 16, 18, 0.02)
	# ceket: boyundan bele, kapalı
	var hem: float = H - 0.01
	var keys := [P._kp(nk, N + 0.0, 0.026), [N - 0.05, ch.x * 1.02, ch.y * 0.96, ch.z * 1.04], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.028), P._kp(k.M(hem, 0.3), hem, 0.034)]
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return 0.006 * sin(a * 7.0 + y * 13.0) * t + 0.004 * sin(a * 11.0 + 1.3) * smoothstep(0.6, 1.0, t) + 0.003 * sin(a * 5.0 - y * 20.0) * (1.0 - t)
	var jg: Dictionary = P._cl(k, {"keys": keys, "ny": 32, "na": 80, "top": func(_a): return N + 0.0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return cr, "gain": 7.0, "th": 0.006, "inner": cr.darkened(0.4), "skin": tsk})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# etek biyesi (siyah)
	P._bd(k, K._yl(jg["hem"], 0.011), 0.011, 0.0028, bl, true, tsk)
	# yaka dikişi
	P._cord(k, jg["top"], 0.0042, cr.darkened(0.12), true, tsk)
	# siyah kapama bandı: yakadan sağa kıvrılır, dikey iner
	var pl := -0.3
	Q._run(k, keys, ffw, [Vector2(-0.04, N - 0.004), Vector2(-0.2, N - 0.045), Vector2(pl, C - 0.02), Vector2(pl, hem + 0.012)], 0.0105, 0.0022, 0.0032, bl, tsk, 8)
	# üç kahve kayış + gümüş toka (kayış bandın üstünden çıkar)
	for i in 3:
		var y: float = lerpf(C - 0.035, hem + 0.08, float(i) / 2.0)
		Q._run(k, keys, ffw, [Vector2(pl - 0.06, y), Vector2(0.2, y + 0.002), Vector2(0.62, y)], 0.0115, 0.0055, 0.0035, st.darkened(0.15), tsk, 8)
		var e: Array = Q._spt(keys, ffw, pl + 0.13, y, 0.009)
		var o: Vector3 = e[1]
		var tg: Vector3 = Vector3.UP.cross(o).normalized()
		P._boxr(k, e[0], tg * 0.016, Vector3.UP * 0.0115, o * 0.003, mt, k.torso_skin(y), 0.3)
		P._boxr(k, (e[0] as Vector3) + o * 0.0028 + tg * 0.004, tg * 0.005, Vector3.UP * 0.0055, o * 0.0014, mt.darkened(0.25), k.torso_skin(y), 0.3)
	# kemer + toka
	var bk := [P._kp(k.M(H + 0.0, 0.3), H + 0.02, 0.026), P._kp(hp, H - 0.07, 0.028)]
	var by: float = H - 0.035
	V._belt(k, bk, by, 0.0, 0.017, 0.006, lb, 0.0, 80)
	var bp: Array = V._belt_pt(bk, 0.22, by, 0.0, 0.012)
	V._buckle(k, bp[0], bp[1], 0.019, 0.015, mt, [["Hips", 1.0]])
	# çapraz kemer: sol kalçadan sağ uyluğa (uyluğa indikçe sağ uyluğa geçer)
	var dk2 := [P._kp(k.M(H, 0.3), H + 0.0, 0.034), P._kp(hp, H - 0.06, 0.036), [H - 0.2, hp.x + 0.012, hp.y + 0.04, hp.z - 0.02]]
	var dsk := func(p: Vector3) -> Array:
		var w: float = smoothstep(0.02, -0.08, p.x) * smoothstep(H - 0.04, H - 0.15, p.y)
		return [["Hips", 1.0 - w], ["RightUpperLeg", w]]
	var dpath := []
	for i in 13:
		var t := float(i) / 12.0
		dpath.append(Vector2(lerpf(wa.x * 1.05, -hp.x * 0.62, t), lerpf(H - 0.03, H - 0.175, t) + 0.025 * sin(t * PI)))
	V._strap2(k, dk2, dpath, true, 0.017, func(_q): return 0.02, 0.004, lb.darkened(0.06), dsk, 2)
	# sağ uyluk: kayış + kılıf, sol kalçada kese
	var lr: Array = legs["Right"]
	J._holster(k, lr[0], lr[1], st, st.darkened(0.25))
	var pp: Vector3 = Vector3(hp.x + 0.03, H - 0.1, 0.0)
	P._boxr(k, pp, Vector3(0, 0, 0.034), Vector3(0, 0.045, 0), Vector3(0.016, 0, 0), st.darkened(0.2), [["Hips", 0.6], ["LeftUpperLeg", 0.4]], 0.3)
	P._boxr(k, pp + Vector3(0.0165, 0.03, 0), Vector3(0, 0, 0.035), Vector3(0, 0.017, 0), Vector3(0.004, 0, 0), st.darkened(0.32), [["Hips", 0.6], ["LeftUpperLeg", 0.4]], 0.25)
	P._boxr(k, Vector3(pp.x - 0.004, by - 0.01, 0.0), Vector3(0, 0, 0.008), Vector3(0, 0.03, 0), Vector3(0.003, 0, 0), st, [["Hips", 1.0]], 0.3)


# ------------------------------------------------------------------ Shinsedai Jōnin (ref Shinobi Striker "Konohamaru Outfit"): lacivert tulum (kolları kıvrık), yeni nesil yeşil yelek: düz
## paneller, ortada dikiş, perçinli omuzluklar, belde geniş bant, altında iki parçalı önlük; boyunda yandan düğümlü mavi atkı, sol kolda kırmızı bant,
## bilekte toplanan lacivert pantolon + siyah bilek sargısı, belin arkasında iki tonlu kahve çanta
static func _shinsedai(k) -> void:
	var nv := Color(0.11, 0.141, 0.251)
	var ve := Color(0.4, 0.6, 0.4)
	var sc := Color(0.165, 0.502, 0.816)
	var rd := Color(0.7, 0.12, 0.13)
	var bk := Color(0.09, 0.09, 0.1)
	var br := Color(0.45, 0.31, 0.2)
	var bd := Color(0.28, 0.19, 0.13)
	var mt := Color(0.72, 0.74, 0.72)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc: Color = Q._skc(k)
	var tsk := func(p): return k.torso_skin(p.y)
	P._inner(k, b, func(_i, _j, _p): return nv)
	K._seat(k, b, nv)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.7 if sd == "Left" else 2.2
		var sl: Callable = X._sleeve(k, ar, nv, 0.885, sv, 0.01)
		X._roll(k, ar, 0.82, 0.895, sl, 0.01, nv.lightened(0.05), sv)
		P._bare(k, ar, skc, 0.87, 0.995)
		Y._jogger(k, le, nv, 0.01, 0.012, 0.9, sv)
		P._lt(k, le, func(s, a): return 0.0045 + 0.0012 * sin(float(a) * 5.0 + float(s) * 60.0), func(_s, a, ins): return bk.darkened(0.3) if ins else bk.darkened(0.12 * float(sin(float(a) * 5.0) < -0.4)), 0.885, 0.99, 8, 18)
		if sd == "Left":
			Q._ring_on(k, ar, 0.3, sl, 0.022, rd, 0.006)
	# yelek gövdesi: yakasız, ortada dikiş, belde bant
	var vk := [P._kp(nk, N + 0.0, 0.026), [N - 0.055, ch.x * 0.98, ch.y * 0.93, ch.z * 1.04], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.125, 0.03), P._kp(wa, H + 0.06, 0.032)]
	var vfold := func(a: float, y: float) -> float:
		var aa: float = absf(wrapf(a, -PI, PI))
		return -0.02 * exp(-pow(a / 0.025, 2.0)) - 0.012 * exp(-pow((aa - 1.62) / 0.05, 2.0)) + 0.004 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.1, y)
	var vt := func(a: float) -> float: return N + 0.0 - 0.035 * exp(-pow(a / 0.5, 2.0))
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 40, "na": 84, "top": func(a): return vt.call(float(a)), "hem": func(_a): return H + 0.05, "fold": func(a, y, _v): return vfold.call(float(a), float(y)),
		"col": func(_a, _y, _v): return ve, "gain": 6.0, "th": 0.008, "inner": ve.darkened(0.4), "skin": tsk})
	var vff := func(a, y): return vfold.call(float(a), float(y))
	P._cord(k, vg["top"], 0.0048, ve.darkened(0.08), true, tsk)
	# yan panel dikişleri ve göğüs bölmesi
	for sg in [1.0, -1.0]:
		Q._run(k, vk, vff, [Vector2(sg * 0.95, N - 0.04), Vector2(sg * 0.82, C - 0.06), Vector2(sg * 0.8, H + 0.09)], 0.0016, 0.0015, 0.0012, ve.darkened(0.25), tsk, 8)
	Q._run(k, vk, vff, [Vector2(0.0, vt.call(0.0) - 0.004), Vector2(0.0, H + 0.09)], 0.0022, 0.001, 0.0012, ve.lightened(0.18), tsk, 10)
	# bel bandı
	var wk := [P._kp(wa, H + 0.1, 0.038), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.04)]
	V._belt(k, wk, H + 0.065, 0.0, 0.026, 0.004, ve.darkened(0.04), 0.0, 84)
	# önlük: bel bandının altından inen iki parça (ön ortada ayrık), uyluğun üstüne iner
	var ahem: float = H - 0.1
	var ak := [P._kp(k.M(H + 0.04, 0.3), H + 0.045, 0.042), P._kp(hp, H - 0.04, 0.034), [ahem, hp.x + 0.03, hp.y + 0.035, hp.z - 0.02]]
	var ask := func(p): return Y._msk(k, p, ahem)
	for e in [[0.035, 1.62], [-1.62, -0.035]]:
		var a0: float = e[0]
		var a1: float = e[1]
		var ag: Dictionary = P._cl(k, {"keys": ak, "ny": 12, "na": 30, "rng": func(_v): return Vector2(a0, a1), "top": func(_a): return H + 0.045, "hem": func(a): return ahem + 0.01 * pow(absf(float(a)) / 1.6, 2.0),
			"fold": func(a, _y, _v): return 0.004 * sin(float(a) * 9.0), "col": func(_a, _y, _v): return ve.darkened(0.02), "gain": 6.0, "th": 0.007, "inner": ve.darkened(0.4), "skin": ask})
		P._bd(k, K._yl(ag["hem"], 0.006), 0.0028, 0.0018, ve.darkened(0.22), false, ask)
	# omuzluklar: perçinli sert yastık
	var cc := Vector3(0.0, C, 0.0)
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.6, 2.4, float(v))
			var y: float = lerpf(N - 0.008, N - 0.085, float(u))
			return Q._spt(vk, vff, a, y, 0.01)[0]
		J._pil(k, surf, 12, 16, 0.014, ve.lightened(0.1), cc, 0.16, tsk)
		for i in 3:
			var u2: float = 0.8
			var v2: float = 0.2 + 0.3 * i
			var e2: Vector3 = surf.call(u2, v2)
			var o2: Vector3 = J._nrm(surf, u2, v2, cc)
			P._stud(k, e2 + o2 * 0.0135, o2, 0.0042, mt, k.torso_skin(e2.y))
	# boyun atkısı: iki tur + sağ yanda düğüm ve iki kısa uç (omuza yatık, sert)
	G._rolls(k, b, sc, [[-0.012, 0.024, 0.017], [0.016, 0.02, 0.015]], {"skin": func(p): return Q._nsk(k, p), "drop": 0.012})
	var kc := Vector3(-nk.x - 0.035, N - 0.005, nk.y * 0.3)
	var nsk := func(_p): return [["Neck", 0.3], ["UpperChest", 0.7]]
	P._boxr(k, kc, Vector3(0.0, 0.0, 0.02), Vector3(0, 0.017, 0), Vector3(-0.016, 0, 0), sc.darkened(0.06), nsk.call(kc), 0.5)
	for e in [[Vector3(-0.07, 0.045, 0.02), 0.022], [Vector3(-0.075, -0.012, 0.035), 0.019]]:
		var dv: Vector3 = e[0]
		var pts := []
		var ou := []
		for i in 6:
			var t := float(i) / 5.0
			pts.append(kc + dv * t + Vector3(0, -0.01 * t * t, 0))
			ou.append(Vector3(0, 0.6, 1).normalized())
		var w0: float = e[1]
		Y._ribbon(k, pts, ou, func(t): return lerpf(w0, w0 * 0.55, float(t)), 0.004, sc, nsk)
	# belin arkasında iki tonlu çanta
	var e3: Array = P._fp(wk, 0.0, H + 0.0, false, 0.03)
	var o3: Vector3 = e3[1]
	P._boxr(k, (e3[0] as Vector3) + Vector3(0, -0.03, 0), Vector3(0.07, 0, 0), Vector3(0, 0.04, 0), o3 * 0.024, br, [["Hips", 1.0]], 0.35)
	P._boxr(k, (e3[0] as Vector3) + Vector3(0, -0.006, 0) + o3 * 0.02, Vector3(0.072, 0, 0), Vector3(0, 0.017, 0), o3 * 0.008, bd, [["Hips", 1.0]], 0.3)


# ------------------------------------------------------------------ Shinsedai Haori (ref Shinobi Striker "Konohamaru Outfit 2"): gri-yeşil kutu ceket (ortada lacivert kapama bandı, etek ve kol
## ağzında lacivert bant), boyunda kalın camgöbeği atkı (arkadan yere yakın sarkan uç), dizin altında biten gri-mor pantolon, sağ uylukta beyaz sargı + lacivert kılıf
static func _haori(k) -> void:
	var gj := Color(0.659, 0.69, 0.627)
	var nb := Color(0.149, 0.165, 0.345)
	var pn := Color(0.478, 0.408, 0.408)
	var sc := Color(0.165, 0.478, 0.604)
	var wh := Color(0.9, 0.9, 0.88)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc: Color = Q._skc(k)
	K._seat(k, b, pn)
	var right := []
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var kn: float = le["kn"]
		var sv: float = 1.9 if sd == "Left" else 0.4
		var s1: float = kn + 0.13
		var pa: Callable = K._pant(k, le, pn, 0.02, 0.016, s1, sv)
		R._hem_roll(k, le, pa, s1, pn.darkened(0.08), 0.02, 0.002)
		P._bare(k, le, skc, s1 - 0.03, 1.0)
		if sd == "Right":
			right = [le, pa]
		Y._sleeve(k, ar, gj, 0.013, 0.012, 0.97, sv, 0.065, nb)
	J._holster(k, right[0], right[1], wh, nb)
	# kutu ceket: kalçaya iner, düz düşer
	var hem: float = H - 0.1
	var keys := [P._kp(nk, N + 0.0, 0.03), [N - 0.055, ch.x * 1.04, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.12, 0.044), P._kp(hp, H - 0.04, 0.042), [hem, hp.x + 0.05, hp.y + 0.04, hp.z - 0.045]]
	var jsk := func(p): return Y._msk(k, p, hem)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return 0.004 * sin(y * 70.0 + a * 0.6) * (1.0 - 0.5 * t) + 0.006 * sin(a * 6.0 + 0.4) * t * t + 0.003 * sin(a * 11.0 + y * 9.0)
	var jg: Dictionary = P._cl(k, {"keys": keys, "ny": 40, "na": 84, "top": func(_a): return N + 0.0, "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return gj, "gain": 8.0, "th": 0.008, "inner": gj.darkened(0.4), "skin": jsk})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	P._bd(k, K._yl(jg["hem"], 0.014), 0.014, 0.003, nb, true, jsk)
	Q._run(k, keys, ffw, [Vector2(0.0, N - 0.004), Vector2(0.0, hem + 0.02)], 0.011, 0.0018, 0.0032, nb, jsk, 14)
	for sg in [1.0, -1.0]:
		Q._run(k, keys, ffw, [Vector2(sg * 1.57, N - 0.06), Vector2(sg * 1.57, hem + 0.03)], 0.0015, 0.0012, 0.001, gj.darkened(0.22), jsk, 10)
	# atkı: boynu saran kalın turlar
	var nsk := func(p): return Q._nsk(k, p)
	G._rolls(k, b, sc, [[-0.02, 0.034, 0.026], [0.014, 0.03, 0.024], [0.042, 0.022, 0.018]], {"skin": nsk, "drop": 0.018})
	# arkadan sarkan uç: sırt boyunca ceketin üstünden iner, ceket ucundan sonra iki bacağın arasında yere yakın biter
	var tl: float = F + 0.1
	var pts := []
	var ou := []
	var y := N - 0.02
	while y > tl:
		var p: Vector3
		if y > hem + 0.02:
			p = Q._spt(keys, ffw, PI, y, 0.009)[0]
		else:
			var e: Array = Q._spt(keys, ffw, PI, hem + 0.02, 0.009)
			p = (e[0] as Vector3) + Vector3(0, y - hem - 0.02, -0.012 * smoothstep(hem, tl, y))
		pts.append(p)
		ou.append(Vector3(0, 0, -1))
		y -= 0.025
	var tsk2 := func(p: Vector3) -> Array:
		if p.y >= H:
			return k.torso_skin(p.y)
		var w: float = 0.3 * smoothstep(H, H - 0.25, p.y)
		return [["Hips", 1.0 - w], ["LeftUpperLeg", w * 0.5], ["RightUpperLeg", w * 0.5]]
	Y._ribbon(k, pts, ou, func(t): return lerpf(0.042, 0.05, float(t)), 0.006, sc, tsk2)


# ------------------------------------------------------------------ Kami Kimono (ref Shinobi Striker "Konan Outfit (Young Ver.)"): file iç, sarı geniş çapraz yakalı siyah kısa kimono (dirseğe
## geniş kol), altında file ön kol; koyu lacivert iç etek üstüne önde çaprazlanan açık mavi sargı bantları (bant altlarında siyah çizgi), belde mor çanta, siyah diz çorabı
static func _kami(k) -> void:
	var bk := Color(0.12, 0.12, 0.14)
	var yl := Color(0.69, 0.627, 0.188)
	var lb := Color(0.604, 0.722, 0.847)
	var db := Color(0.13, 0.19, 0.42)
	var pu := Color(0.42, 0.27, 0.35)
	var nt := Color(0.08, 0.08, 0.09)
	var so := Color(0.11, 0.11, 0.125)
	var mt := Color(0.8, 0.8, 0.82)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc: Color = Q._skc(k)
	var tsk := func(p): return k.torso_skin(p.y)
	var inn: Array = P._inner(k, b, func(_i, _j, _p): return skc.lerp(nt, 0.25), 0.004)
	P._net_patch(k, inn, func(a, y): return float(y) > C - 0.06 - 0.0 * float(a), -0.6, 0.6, C - 0.06, N + 0.03, 0.013, 0.001, 0.0015, nt)
	R._seat(k, R._seat_keys(k, b), func(_i, _j, _p): return db.darkened(0.2))
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var kn: float = le["kn"]
		var en: float = ar["kn"]
		var sv: float = 1.3 if sd == "Left" else 0.2
		Y._knee_sock(k, le, so, kn + 0.05, sv)
		# ön kol: ten + file, bilekte koyu bant
		Z._arm_bare(k, ar)
		P._net_limb(k, ar, en - 0.08, 0.95, 0.0026, 12, 0.026, 0.0012, nt)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return nt.darkened(0.3) if ins else nt.lightened(0.05), 0.94, 0.975, 3, 16)
		# dirseğe inen geniş kol
		AA._hang_sleeve(k, ar, bk, bk.lightened(0.06), 0.016, 0.026, 0.03, en + 0.03, sv)
	# kimono ceket: bele iner; önde V (sağ yaka sola biner)
	var hem: float = H + 0.03
	var keys := [P._kp(nk, N + 0.006, 0.024), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.05], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.12, 0.034), P._kp(k.M(hem, 0.3), hem, 0.038)]
	var vy: float = C - 0.015
	var vx: float = 0.06
	var topf := func(a: float) -> float:
		var d: float = absf(a - vx)
		return lerpf(vy, N + 0.006, smoothstep(0.0, 0.62, d))
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((C - y) / (C - hem), 0.0, 1.0)
		return 0.008 * sin(a * 6.0 + 0.7) * t + 0.004 * sin(a * 9.0 - y * 15.0)
	var kg: Dictionary = P._cl(k, {"keys": keys, "ny": 30, "na": 84, "top": func(a): return topf.call(float(a)), "hem": func(_a): return hem, "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 7.0, "th": 0.006, "inner": bk.darkened(0.3), "skin": tsk})
	var ffw := func(a, y): return ff.call(float(a), float(y))
	# sarı yakalar: alttaki (sol) V'nin dibinde biter; üstteki (sağ omuzdan) sol bele iner
	var col_l := []
	for i in 9:
		var t := float(i) / 8.0
		col_l.append(Vector2(lerpf(0.62, vx + 0.02, t), lerpf(N + 0.004, vy - 0.005, t)))
	Q._run(k, keys, ffw, col_l, 0.021, 0.004, 0.004, yl.darkened(0.06), tsk, 3)
	var col_r := []
	for i in 13:
		var t := float(i) / 12.0
		var a: float = lerpf(-0.62, 0.62, t)
		var yy: float = topf.call(a) if a < vx else lerpf(vy - 0.004, hem + 0.02, (a - vx) / (0.62 - vx))
		col_r.append(Vector2(a, yy))
	Q._run(k, keys, ffw, col_r, 0.024, 0.008, 0.0045, yl, tsk, 3)
	P._bd(k, K._yl(kg["hem"], 0.008), 0.006, 0.0022, bk.lightened(0.05), true, tsk)
	# iç etek (koyu lacivert) + sargı bantlı açık mavi etek
	var shem: float = H - 0.25
	var sk := [P._kp(k.M(H + 0.06, 0.3), H + 0.06, 0.012), P._kp(hp, H - 0.04, 0.03), [shem, hp.x + 0.07, hp.y + 0.07, hp.z - 0.06]]
	var ssk := func(p): return Y._msk(k, p, shem)
	var sff := func(a: float, y: float) -> float: return 0.006 * sin(a * 7.0 + 0.5) * clampf((H - y) / (H - shem), 0.0, 1.0)
	var sffw := func(a, y): return sff.call(float(a), float(y))
	var ik := []
	for e in sk:
		ik.append([e[0], float(e[1]) - 0.008, float(e[2]) - 0.008, float(e[3]) + 0.008])
	P._cl(k, {"keys": ik, "ny": 14, "na": 64, "top": func(_a): return H + 0.04, "hem": func(_a): return shem + 0.012, "fold": func(a, y, _v): return sff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return db, "gain": 6.0, "th": 0.005, "inner": db.darkened(0.3), "skin": ssk})
	var gap := func(a: float) -> float: return shem + 0.11 * exp(-pow((a + 0.1) / 0.32, 2.0))
	P._cl(k, {"keys": sk, "ny": 18, "na": 84, "top": func(_a): return H + 0.06, "hem": func(a): return gap.call(float(a)), "fold": func(a, y, _v): return sff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return lb.darkened(0.2), "gain": 6.0, "th": 0.005, "inner": lb.darkened(0.4), "skin": ssk})
	# sargı bantları: önde çaprazlanır, alttakiler önce; her bandın alt kenarında siyah çizgi
	var hw := 0.042
	var bands := []
	for i in 2:
		var y0: float = lerpf(H - 0.04, shem + 0.1, float(i))
		bands.append([y0, 0.075, -1.85, 0.6, 0.004 + 0.003 * i])
		bands.append([y0 - 0.012, -0.075, -0.6, 1.85, 0.0055 + 0.003 * i])
	for i in bands.size():
		var e: Array = bands[i]
		var y0: float = e[0]
		var sl: float = e[1]
		var yf := func(a: float) -> float: return maxf(y0 + sl * a, shem + hw * 0.7)
		var lf: float = e[4]
		var a0: float = e[2]
		var a1: float = e[3]
		_wband(k, sk, sffw, a0, a1, yf, hw, lf - 0.004, lf, lb.lightened(0.06) if i % 2 == 0 else lb.darkened(0.05), ssk, 30, 6, true, true)
		var yl2 := func(a: float) -> float: return float(yf.call(a)) - hw * 0.55
		_edge_line(k, sk, sffw, a0 + 0.22, a1 - 0.22, yl2, lf + 0.0012, 0.0045, nt, ssk, 22)
	# ince koyu kuşak + mor çanta (iki tokalı kapak)
	var bk2 := [P._kp(k.M(H + 0.06, 0.3), H + 0.09, 0.026), P._kp(k.M(H + 0.0, 0.3), H + 0.0, 0.03)]
	V._belt(k, bk2, H + 0.05, 0.0, 0.009, 0.004, Color(0.16, 0.16, 0.2), 0.0, 72)
	var e4: Array = P._fp(bk2, -0.01, H + 0.035, true, 0.028)
	var c4: Vector3 = e4[0]
	var o4: Vector3 = e4[1]
	var bb := [["Hips", 0.8], ["Spine", 0.2]]
	P._boxr(k, c4, Vector3(0.068, 0, 0), Vector3(0, 0.05, 0), o4 * 0.026, pu, bb, 0.3)
	P._boxr(k, c4 + Vector3(0, 0.022, 0) + o4 * 0.024, Vector3(0.07, 0, 0), Vector3(0, 0.03, 0), o4 * 0.006, pu.lightened(0.05), bb, 0.25)
	for sg in [1.0, -1.0]:
		var sp: Vector3 = c4 + Vector3(sg * 0.035, 0.012, 0) + o4 * 0.031
		P._boxr(k, sp, Vector3(0.007, 0, 0), Vector3(0, 0.026, 0), o4 * 0.002, pu.darkened(0.25), bb, 0.3)
		V._buckle(k, sp + Vector3(0, -0.012, 0), o4, 0.008, 0.006, mt, bb)


# ------------------------------------------------------------------ Gensō Hōtai (ref Shinobi Striker "Kurenai Outfit"): file üst (koyu yuvarlak yaka), sağ kolda kırmızı tek kol, omuzlardan
## inen geniş beyaz sargı bantları önde çaprazlanır, kısa elbise önde ters V ile biter; bant kenarlarında dikenli siyah çizgi, altta lila şort, sol ön kol + bilek sargıları
static func _genso(k) -> void:
	var wh := Color(0.957, 0.957, 0.949)
	var ln := Color(0.06, 0.06, 0.07)
	var rd := Color(0.659, 0.133, 0.157)
	var nt := Color(0.08, 0.08, 0.09)
	var li := Color(0.8, 0.76, 0.88)
	var bw := Color(0.949, 0.941, 0.918)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var skc: Color = Q._skc(k)
	var tsk := func(p): return k.torso_skin(p.y)
	# file üst: ten üstüne ağ, boyunda koyu yaka
	var inn: Array = P._inner(k, b, func(_i, _j, p): return skc if p.y > N + 0.0 else skc.lerp(nt, 0.3), 0.004)
	P._net_patch(k, inn, func(_a, y): return float(y) < N - 0.006, -0.75, 0.75, C - 0.1, N + 0.0, 0.012, 0.001, 0.0015, nt)
	var nring := []
	for i in 40:
		var a := TAU * i / 40.0 - PI
		nring.append(P._on(inn, a, N - 0.0, 0.0) + Vector3(0, 0, 0))
	P._cord(k, nring, 0.004, nt, true, tsk)
	# lila şort + çıplak bacak
	R._seat(k, R._seat_keys(k, b), func(_i, _j, _p): return li)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.9 if sd == "Left" else 2.4
		var ad: Callable = R._short_leg(k, le, li, 0.14, 0.008, 0.004, sv)
		R._hem_roll(k, le, ad, 0.14, li.darkened(0.08), 0.015, 0.0015)
		P._bare(k, le, skc, 0.12, 1.0)
		if sd == "Right":
			# kırmızı tek kol: bileğe iner, altında bilek ve el sargısı
			X._sleeve(k, ar, rd, 0.93, sv, 0.008)
			P._bare(k, ar, skc, 0.9, 0.995)
			P._wraps(k, ar, 0.94, 0.985, 4, 0.004, 0.0085, bw, 0.006)
		else:
			Z._arm_bare(k, ar)
			P._wraps(k, ar, 0.6, 0.93, 10, 0.004, 0.0105, bw, 0.009)
			P._wraps(k, ar, 0.955, 0.985, 2, 0.004, 0.008, bw, 0.006)
	# elbise gövdesi: omuz askıları, önde V, kol oyukları; kalçada biraz bollaşır, önde ters V ile biter
	var hem: float = H - 0.17
	var keys := [P._kp(nk, N + 0.0, 0.016), [N - 0.045, ch.x * 0.8, ch.y * 0.88, ch.z * 0.94], P._kp(ch, C - 0.03, 0.022), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.04, 0.038), [hem, hp.x + 0.05, hp.y + 0.05, hp.z - 0.04]]
	var dsk := func(p): return T._ksk(k, p, hem)
	var topf := func(a: float) -> float:
		var aw: float = absf(a)
		var v_: float = lerpf(C - 0.09, N - 0.02, smoothstep(0.06, 0.55, aw))
		var arm: float = smoothstep(0.85, 1.15, aw) * (1.0 - smoothstep(1.95, 2.25, aw))
		return lerpf(v_, C - 0.02, arm)
	var hemf := func(a: float) -> float: return hem + 0.075 * exp(-pow(a / 0.3, 2.0))
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem), 0.0, 1.0)
		return 0.006 * sin(a * 5.0 + 0.6) * t + 0.003 * sin(a * 9.0 + y * 12.0)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var dg: Dictionary = P._cl(k, {"keys": keys, "ny": 40, "na": 96, "top": func(a): return topf.call(float(a)), "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return wh.darkened(0.1), "gain": 5.0, "th": 0.005, "inner": wh.darkened(0.35), "skin": dsk})
	var hw := 0.026
	# önde çapraz bantlar (göğüs): soldan sağa ve sağdan sola; bantlar aşağıya doğru kalça hizasına sıralanır
	var bands := []
	bands.append([0.6, N - 0.045, -1.2, H + 0.0, 0.006])
	bands.append([-0.6, N - 0.045, 1.2, H - 0.01, 0.009])
	var nb := 5
	for i in nb:
		var t := float(i) / (nb - 1)
		var yc: float = lerpf(C - 0.12, hem + 0.06, t)
		if i % 2 == 0:
			bands.append([1.75, yc + 0.07, -1.75, yc - 0.07, 0.004 + 0.0025 * i])
		else:
			bands.append([-1.75, yc + 0.07, 1.75, yc - 0.07, 0.004 + 0.0025 * i])
	bands.append([1.6, hem + 0.06, -0.05, hem + 0.025 + 0.075, 0.017])
	bands.append([-1.6, hem + 0.06, 0.05, hem + 0.025 + 0.075, 0.019])
	# sırt bantları (yatay, arkada)
	for i in 6:
		var yc2: float = lerpf(C - 0.05, hem + 0.04, float(i) / 5.0)
		bands.append([1.5, yc2 + 0.02, TAU - 1.5, yc2 - 0.02, 0.004 + 0.001 * i])
	for e in bands:
		var a0: float = e[0]
		var y0: float = e[1]
		var a1: float = e[2]
		var y1: float = e[3]
		var lf: float = e[4]
		var yf := func(a: float) -> float: return lerpf(y0, y1, (a - a0) / (a1 - a0))
		var lo: float = minf(a0, a1)
		var hi: float = maxf(a0, a1)
		var yfa := func(a: float) -> float: return yf.call(a)
		_wband(k, keys, ffw, lo, hi, yfa, hw, lf - 0.0045, lf, wh, dsk, 36, 6)
		var ye := func(a: float) -> float: return float(yfa.call(a)) - hw * 0.68
		_edge_line(k, keys, ffw, lo + 0.12, hi - 0.12, ye, lf + 0.0012, 0.0026, ln, dsk, 28, 0.011, 3)
	P._bd(k, K._yl(dg["hem"], 0.006), 0.004, 0.0018, wh.darkened(0.2), false, dsk)


# ------------------------------------------------------------------ gelinlik
## Yere inen gelinlik ağırlığı. Üst: ön yüz uyluğu çabuk izler (kalkan uyluk delmez), arka yüz boy boyunca yavaş artar ve iki bacak arasında geniş geçer.
## Diz altı: kendi baldırı yumuşak artan payla izlenir; pay en alt halkalarda en yüksek (etek ucu koşan bacağın ucunu izler, ama kumaş baldıra yapışıp
## topaklanmaz). İç ve dış kat AYNI işlevi kullanır: aynı yükseklik ve yönde aynı ağırlık, alt kat hep içeride kalır.
static func _dsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = clampf((H - p.y) / maxf(0.05, H - hem), 0.0, 1.0)
	var th: float = atan2(p.x, p.z)
	var x: float = 0.17 * sin(th)
	var z: float = 0.14 * cos(th)
	var bk: float = smoothstep(0.03, -0.08, z)
	var wf: float = 0.95 * pow(minf(1.0, t / 0.2), 0.35)
	var wb: float = lerpf(0.82 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.95, smoothstep(0.55, 0.92, t))
	var w: float = lerpf(wf, wb, bk) * lerpf(1.0, 0.94, smoothstep(0.8, 1.0, t))
	var kz: float = smoothstep(k.K + 0.06, k.K - 0.1, p.y)
	var hw: float = lerpf(lerpf(0.05, 0.1, smoothstep(0.1, 0.5, t)), lerpf(0.09, 0.04, kz), bk)
	var s: float = smoothstep(-hw, hw, x)
	var side: float = minf(1.0, absf(2.0 * s - 1.0) * lerpf(1.5, 3.0, bk * kz))
	var kf: float = smoothstep(k.K + 0.04, k.K - 0.16, p.y) * 0.5
	var kbk: float = pow(clampf(inverse_lerp(k.K + 0.04, hem, p.y), 0.0, 1.0), 0.7) * 0.78
	var low: float = smoothstep(hem + 0.3, hem, p.y)
	var kb: float = (lerpf(kf, kbk, bk) + low * lerpf(0.15, 0.0, bk)) * side
	kb = minf(kb, 0.95)
	var la: Array
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		la = [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	else:
		la = [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]
	# arka diz altı: iki baldır geniş geçişle paylaşılır (geri kalkan ayak kumaşı geniş bir çadır gibi kaldırır, dar tüp / topak olmaz)
	var mb: float = bk * kz
	if mb <= 0.0:
		return la
	var hw2: float = 0.18
	var sw: float = smoothstep(-hw2, hw2, x)
	var kb2: float = minf(0.95, kbk + low * 0.0)
	var lb := [["Hips", 1.0 - w], ["LeftUpperLeg", w * sw * (1.0 - kb2)], ["RightUpperLeg", w * (1.0 - sw) * (1.0 - kb2)], ["LeftLowerLeg", w * sw * kb2], ["RightLowerLeg", w * (1.0 - sw) * kb2]]
	var acc := {}
	for e in la:
		acc[e[0]] = float(acc.get(e[0], 0.0)) + float(e[1]) * (1.0 - mb)
	for e in lb:
		acc[e[0]] = float(acc.get(e[0], 0.0)) + float(e[1]) * mb
	var out := []
	for kk in acc:
		out.append([kk, acc[kk]])
	out.sort_custom(func(u, v): return float(u[1]) > float(v[1]))
	return out.slice(0, mini(out.size(), int(k.per)))


## Kuro Hanayome (ref Shinobi Striker "Hinata Outfit: Bridal Ver."): boyundan bağlı kolsuz siyah-mor gelinlik: dik yaka + önde anahtar deliği, göğüs altında
## pli fırfır, kemer, kemer altında pli kısa kat (peplum), yere inen A kesim etek; etek ucunda bir basamak içeri dönüp yere inen koyu alt kat (aynı yüzeyin
## devamı: iki kat birbirinden taşmaz), önde kemerden sarkan açık tonlu pli şeritler, dirsek üstüne çıkan parmaklı eldiven
static func _gelinlik(k) -> void:
	var c0 := Color(0.15, 0.11, 0.17)
	var c1 := Color(0.175, 0.128, 0.215)
	var lo := Color(0.105, 0.08, 0.125)
	var rb := Color(0.33, 0.29, 0.38)
	var gl := Color(0.11, 0.09, 0.13)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var KN: float = k.K
	var F: float = k.F
	var b: Dictionary = P._base(k)
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var ch: Vector3 = b["ch"]
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._skin_torso(k, b, C - 0.08)
	# altta koyu külotlu çorap
	K._seat(k, b, lo)
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		P._lt(k, le, func(s, a): return 0.0028 + 0.0012 * sin(float(a) * 3.0 + float(s) * 20.0), func(_s, a, ins): return lo.darkened(0.3) if ins else lo.lightened(0.05 * maxf(0.0, cos(float(a)))), 0.0, 0.99, 24, 14)
		var ar: Dictionary = P._limb(k, sd, false)
		Z._arm_bare(k, ar)
		Z._long_glove(k, ar, 0.3, gl, 0.6 if sd == "Left" else 1.7)
	# korsaj: boyundan bağlı, omuzlar açık, önde anahtar deliği; prenses dikişleri
	var bod: Dictionary = Z._halter(k, b, {"col": c0, "hem": H + 0.06, "cut": C - 0.035, "a0": 0.4, "a1": 1.0, "slit": 0.05, "slit_v": 0.22, "pad": 0.008, "hang": 0.35, "ny": 34})
	P._cord(k, bod["top"], 0.0032, c0.lightened(0.05), true, nsk)
	var bk: Array = bod["keys"]
	var bff: Callable = bod["ff"]
	for sg in [1.0, -1.0]:
		Q._run(k, bk, bff, [Vector2(sg * 0.5, C - 0.01), Vector2(sg * 0.42, C - 0.08), Vector2(sg * 0.38, H + 0.07)], 0.0018, 0.003, 0.0011, c0.darkened(0.25), tsk, 8)
	Z._stand(k, b, 0.055, 0.006, c0)
	var cb: Array = Q._spt([P._kp(b["nk"], N + 0.03, 0.012)], Callable(), 0.0, N + 0.03, 0.002)
	P._stud(k, cb[0], cb[1], 0.0038, c0.lightened(0.14), [["Neck", 0.5], ["UpperChest", 0.5]])
	var sl: Array = Q._spt(bk, bff, 0.0, N - 0.045, 0.004)
	P._stud(k, sl[0], sl[1], 0.0045, c0.lightened(0.12), k.torso_skin(N - 0.045))
	# kemer
	var by: float = H + 0.085
	var wk := [P._kp(k.M(H + 0.13, k.UA), H + 0.13, 0.014), P._kp(k.M(H + 0.04, 0.3), H + 0.04, 0.016)]
	V._belt(k, wk, by, 0.0, 0.021, 0.006, c0.lightened(0.03), 0.0, 96)
	# göğüs altı pli fırfır: üst kenarı dışa açılır
	var mb: Vector3 = k.M(C - 0.085, k.UA)
	var fy0: float = C - 0.07
	var fy1: float = by + 0.016
	var fk := [[fy0, mb.x + 0.034, maxf(mb.y, ch.y * 0.94) + 0.036, mb.z - 0.03], [lerpf(fy0, fy1, 0.5), mb.x + 0.02, maxf(mb.y, ch.y * 0.9) + 0.018, mb.z - 0.02], [fy1, wa.x + 0.016, wa.y + 0.016, wa.z - 0.016]]
	var fr: Dictionary = P._cl(k, {"keys": fk, "ny": 8, "na": 112, "top": func(_a): return fy0, "hem": func(_a): return fy1 - 0.004, "fold": func(a, _y, v): return Y._pleat(float(a), 15.0, 0.07) * (1.0 - 0.55 * float(v)) + 0.01 * (1.0 - float(v)),
		"col": func(_a, _y, _v): return c1, "gain": 6.0, "th": 0.004, "inner": c1.darkened(0.4), "skin": tsk})
	P._cord(k, fr["top"], 0.0026, c1.lightened(0.06), true, tsk)
	# etek: tek yüzey. Belden hem_m'e dış kat, hem_m'de kalın kıvrık kenar ve içe basamak, oradan yere koyu alt kat
	var hem_l: float = F + 0.012
	var hem_m: float = hem_l + 0.06
	var sk := [P._kp(k.M(H + 0.075, 0.3), H + 0.075, 0.012), P._kp(hp, H - 0.04, 0.04), [KN + 0.12, hp.x + 0.075, hp.y + 0.075, hp.z - 0.085], [KN - 0.12, hp.x + 0.11, hp.y + 0.13, hp.z - 0.15], [hem_l, hp.x + 0.145, hp.y + 0.16, hp.z - 0.18]]
	var dsk := func(p): return _dsk(k, p, hem_l)
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - hem_l), 0.0, 1.0)
		var fr2: float = 1.0 - 0.55 * exp(-pow(absf(a) / 0.3, 2.0))
		return fr2 * pow(t, 0.8) * (0.034 * sin(a * 6.0 + 0.6) + 0.016 * sin(a * 11.0 + 1.9)) + 0.004 * sin(a * 18.0) * (1.0 - t)
	var ffw := func(a, y): return ff.call(float(a), float(y))
	var na := 96
	var ny := 40
	var y0: float = H + 0.075
	var rows := []
	var cols := []
	var pt := func(a: float, y: float, d: float) -> Vector3:
		var s: Array = SE.El.key_at(sk, y)
		var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
		var f: float = 1.0 + float(ff.call(a, y))
		var o := Vector3(q.x, 0.0, q.y).normalized()
		return Vector3(q.x * f, y, q.y * f) - o * d
	var ys := []
	for j in ny + 1:
		ys.append([lerpf(y0, hem_m, float(j) / ny), 0.0, 0])
	ys.append([hem_m - 0.004, 0.003, 1])   # kıvrık kenar: dışa kabarır
	ys.append([hem_m - 0.009, 0.0, 1])
	ys.append([hem_m - 0.011, -0.008, 2])   # içe basamak
	for j in 7:
		ys.append([lerpf(hem_m - 0.016, hem_l, float(j) / 6.0), -0.008, 2])
	ys.append([hem_l - 0.002, -0.012, 3])
	ys.append([hem_l + 0.006, -0.018, 3])
	for e in ys:
		var y: float = e[0]
		var ro := []
		var cr := []
		for i in na:
			var a := TAU * i / na - PI
			ro.append(pt.call(a, y, -float(e[1])))
			var f: float = ff.call(a, y)
			var cc: Color = c1 if int(e[2]) <= 1 else lo
			if int(e[2]) == 1:
				cc = c1.darkened(0.12)
			elif int(e[2]) == 3:
				cc = lo.darkened(0.3)
			cr.append(P._fs(cc, f, 4.5))
		rows.append(ro)
		cols.append(cr)
	k.grid(rows, true, func(i, j, _p): return cols[j][i], func(_i, _j, p): return dsk.call(p))
	# astar: dizden etek ucuna içten (kalkan etek arkadan bakınca içi görünür, delik kalmaz)
	var lrows := []
	var ly0: float = KN + 0.1
	for j in range(18, -1, -1):
		var y: float = lerpf(ly0, hem_l + 0.004, float(j) / 18.0)
		var dd: float = 0.007 if y > hem_m - 0.011 else 0.015
		var ro := []
		for i in na:
			ro.append(pt.call(TAU * i / na - PI, y, dd))
		lrows.append(ro)
	k.grid(lrows, true, func(_i, _j, _p): return lo.darkened(0.25), func(_i, _j, p): return dsk.call(p))
	for sg in [1.0, -1.0]:
		Q._run(k, sk, ffw, [Vector2(sg * 1.57, H + 0.06), Vector2(sg * 1.57, hem_m + 0.02)], 0.0018, 0.002, 0.0011, c1.darkened(0.22), dsk, 14)
	P._cur_hem = hem_l
	# peplum: kemerin altında pli kısa kat
	var pk := [P._kp(k.M(H + 0.075, 0.3), H + 0.075, 0.024), [H - 0.06, hp.x + 0.07, hp.y + 0.07, hp.z - 0.07]]
	var pg: Dictionary = P._cl(k, {"keys": pk, "ny": 8, "na": 112, "top": func(_a): return by - 0.012, "hem": func(_a): return H - 0.06, "fold": func(a, _y, v): return Y._pleat(float(a), 16.0, 0.06) * (0.4 + 0.6 * float(v)),
		"col": func(_a, _y, _v): return c1.lightened(0.03), "gain": 6.0, "th": 0.005, "inner": c1.darkened(0.4), "skin": dsk})
	P._bd(k, K._yl(pg["hem"], 0.007), 0.0026, 0.0014, c1.darkened(0.15), true, dsk)
	# önde kemerden sarkan açık tonlu pli şeritler: eteğin üstüne oturur, eteğin kendi ağırlığını alır
	var rw := func(v: float) -> float: return lerpf(0.24, 0.15, v)
	var rk := []
	for e in sk:
		rk.append([e[0], float(e[1]) + 0.01, float(e[2]) + 0.016, float(e[3]) - 0.01])
	var rrng := func(v) -> Vector2:
		var w2: float = rw.call(float(v))
		return Vector2(-w2, w2)
	var rfold := func(a, y, v) -> float:
		var w3: float = rw.call(float(v))
		var u: float = (float(a) + w3) / (2.0 * w3)
		return Y._pleat(u * PI, 5.0, 0.03) + float(ff.call(float(a), float(y))) * 0.6
	var rg: Dictionary = P._cl(k, {"keys": rk, "ny": 42, "na": 30, "rng": rrng, "top": func(_a): return by - 0.01, "hem": func(a): return hem_m + 0.035 + 0.02 * absf(float(a)),
		"fold": rfold, "col": func(_a, _y, _v): return rb, "gain": 7.0, "th": 0.004, "inner": rb.darkened(0.4), "skin": dsk})
	for ed in [rg["ea"], rg["eb"]]:
		P._cord(k, ed, 0.0022, rb.darkened(0.2), false, dsk)
	P._cur_hem = hem_l
