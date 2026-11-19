extends RefCounted
## Elle modellenmiş setler, parti aw: ss_kedi_alev, ss_iblis, ss_inuzuka_ceket, ss_kum_striker, ss_kum_striker_balon, ss_kum_striker_kabile. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/{sand_striker/Sand_Striker_1..3, yugito_outfit/Yugito_1..3 (+ refs/kiyafet/yugito), zabuza_outfit/Zabuza_Costume, kiba_outfit/Kiba_1..6}.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), j (J), r (R), y (Y), aa (AA), ag (AG), t (T), aq (AQ) dosyalarından; burada Suna Striker ortak kesimi (üç türev) ve setler.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const J = preload("res://scripts/actors/set_el_j.gd")
const R = preload("res://scripts/actors/set_el_r.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const AG = preload("res://scripts/actors/set_el_ag.gd")
const T = preload("res://scripts/actors/set_el_t.gd")
const AQ = preload("res://scripts/actors/set_el_aq.gd")
const S = preload("res://scripts/actors/set_el_s.gd")
const G = preload("res://scripts/actors/set_el_g.gd")

const DONE := ["ss_kum_striker", "ss_kum_striker_balon", "ss_kum_striker_kabile", "ss_kedi_alev", "ss_iblis", "ss_inuzuka_ceket"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_kum_striker": _kum(k, 0)
		"ss_kum_striker_balon": _kum(k, 1)
		"ss_kum_striker_kabile": _kum(k, 2)
		"ss_kedi_alev": _yugito(k)
		"ss_iblis": _iblis(k)
		"ss_inuzuka_ceket": _inuzuka(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Dikdörtgen kutu, yön vektörleriyle (toka, fişek kutusu, kese)
static func _blk(k, c: Vector3, ux: Vector3, uy: Vector3, o: Vector3, w: float, h: float, d: float, col: Color, bones: Array, rc := 0.25) -> void:
	P._boxr(k, c, ux.normalized() * w, uy.normalized() * h, o.normalized() * d, col, bones, rc)


## Yüzeye oturan üçgen (sivri ucu aşağı): mp yerel eşleme
static func _tri_tab(k, mp: Callable, o: Vector3, w: float, h: float, lift: float, col: Color, skinf: Callable) -> void:
	var rows := []
	for j in 4:
		var v := float(j) / 3.0
		var hw: float = w * (1.0 - v)
		var ro := []
		for i in 5:
			var u := float(i) / 4.0
			ro.append(mp.call((u - 0.5) * 2.0 * hw, -v * h, lift + 0.0012 * sin(u * PI) * (1.0 - v)))
		rows.append(ro)
	Q._mesh(k, rows, false, func(_i, j, _p): return col.darkened(0.1 * float(j == 0)), func(_i, _j, p): return skinf.call(p), o)


## Su balonu baskısı (kabartma): yuvarlak gövde + parlak yay + düğüm + ip; mp yerel eşleme
static func _balloon(k, mp: Callable, o: Vector3, r: float, col: Color, skinf: Callable, string_len := 0.0) -> void:
	Q._disc(k, mp, o, r, 0.0028, func(th): return 1.0 + 0.08 * maxf(0.0, -sin(float(th))), func(u, v):
		if Vector2(float(u) + 0.35, float(v) - 0.4).length() < 0.22:
			return col.lightened(0.45)
		return col.darkened(0.18) if float(v) < -0.55 else col, skinf, 3, 22)
	var hl := []
	for i in 7:
		var t := lerpf(2.3, 3.6, float(i) / 6.0)
		hl.append(Vector2(cos(t), sin(t)) * r * 0.62)
	R._lstrip(k, mp, hl, r * 0.08, 0.0042, 0.0012, col.lightened(0.5), skinf)
	R._lstrip(k, mp, [Vector2(-r * 0.22, r * 1.12), Vector2(0.0, r * 0.98), Vector2(r * 0.22, r * 1.12)], r * 0.13, 0.0034, 0.0016, col.darkened(0.25), skinf)
	if string_len > 0.0:
		var sp := []
		for i in 7:
			var t := float(i) / 6.0
			sp.append(Vector2(0.004 * sin(t * PI * 2.0), r * 1.12 + t * string_len))
		R._lstrip(k, mp, sp, 0.0011, 0.002, 0.001, Color(0.93, 0.93, 0.95), skinf)


## Uzun parmaksız eldiven: dirsek altından bileğe sıkı tüp (üstte kalın ağız; el, kıyafet katmanında bilekten içeri çizilmez)
static func _long_mitt(k, sd: String, ar: Dictionary, s0: float, col: Color, sv: float) -> Callable:
	var gf := func(s: float, a: float) -> float:
		return 0.003 + 0.0028 * smoothstep(s0 + 0.035, s0, s) + 0.0012 * P._lf(s, a, sv) * smoothstep(s0 + 0.04, 0.8, s) * smoothstep(0.9, 0.82, s) + 0.0015 * smoothstep(0.9, 0.97, s)
	P._lt(k, ar, gf, func(s, a, ins):
		if ins:
			return col.darkened(0.35)
		return P._fs(col, float(gf.call(float(s), float(a))) - 0.003, 16.0).lightened(0.05 * float(float(s) < s0 + 0.018)), s0, 0.958, 28, 18, 0.012)
	return gf


# ------------------------------------------------------------------ Suna Striker ortak kesimi (ref Shinobi Striker "Sand Striker" 1-3): uyluğa inen kolsuz tunik (omuz başını örter, kol oyuğu biyeli),
## boynu saran kalın atkı, soldan sağ kalçaya inen kılıflık kayışı + üstte fişek kutuları, geniş kemer + iki köprü, dirsek altına uzanan parmaksız eldiven,
## dizin altında toplanan bol pantolon + sağ uylukta kapaklı büyük cep ve dış yanda kese, altında koyu konç.
## v=0 asıl (soluk sarı tunik, beyaz atkı, gri kayış + gri kemer, koyu kahve eldiven, kahve pantolon), v=1 Balonlar (mavi tunikte su balonu baskıları, lacivert atkı,
## kırmızı noktalı beyaz kayış + altın fişeklik, camgöbeği şeritli beyaz kemer + altın köprü, balonlu beyaz eldiven ve konç, lacivert pantolon, cepte camgöbeği şerit),
## v=2 Kabile (mor tunik + eteğinde boncuklu sarı üçgen saçak, sarı boncuklu üçgen sıralı siyah atkı, koyu çizgili sarı kayış, baklava desenli dişli kemer,
## koyu camgöbeği eldiven, siyah pantolon + cepte sarı-siyah şerit, konçta sarı baklava çiftleri)
static func _kum(k, v: int) -> void:
	var tu: Color = [Color(0.86, 0.82, 0.68), Color(0.17, 0.3, 0.76), Color(0.38, 0.17, 0.54)][v]
	var scf: Color = [Color(0.93, 0.93, 0.92), Color(0.12, 0.15, 0.42), Color(0.08, 0.08, 0.09)][v]
	var stc: Color = [Color(0.5, 0.45, 0.43), Color(0.93, 0.93, 0.92), Color(0.91, 0.72, 0.19)][v]
	var amc: Color = [Color(0.4, 0.36, 0.35), Color(0.9, 0.7, 0.24), Color(0.12, 0.1, 0.1)][v]
	var blc: Color = [Color(0.56, 0.53, 0.53), Color(0.93, 0.93, 0.93), Color(0.91, 0.72, 0.19)][v]
	var lpc: Color = [Color(0.48, 0.45, 0.45), Color(0.9, 0.7, 0.24), Color(0.95, 0.78, 0.25)][v]
	var glc: Color = [Color(0.2, 0.18, 0.17), Color(0.93, 0.93, 0.92), Color(0.12, 0.29, 0.35)][v]
	var pc: Color = [Color(0.31, 0.26, 0.24), Color(0.12, 0.17, 0.42), Color(0.08, 0.08, 0.09)][v]
	var lowc: Color = [Color(0.15, 0.14, 0.14), Color(0.92, 0.92, 0.93), Color(0.17, 0.16, 0.3)][v]
	var pou: Color = [Color(0.12, 0.15, 0.32), Color(0.15, 0.27, 0.7), Color(0.07, 0.07, 0.08)][v]
	var yl := Color(0.91, 0.72, 0.19)
	var cy := Color(0.3, 0.82, 0.86)
	var rd := Color(0.82, 0.24, 0.26)
	var skc: Color = Q._skc(k)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var hem: float = H - 0.12
	var by: float = H + 0.075
	var tsk := func(p): return k.torso_skin(p.y)
	var fam := func(p): return AA._fam(k, p, hem)
	var nsk := func(p): return Q._nsk(k, p)
	K._seat(k, b, pc.darkened(0.08))
	# pantolon: bol, dizin altında toplanır; altında koyu konç
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sg: float = le["sg"]
		var sv: float = 1.5 if sd == "Left" else 0.4
		var tk: float = kn + 0.15
		var pa: Callable = Q._baggy(k, le, pc, lowc, 0.018, 0.042, tk, sv)
		var lo := func(s: float, a: float) -> float: return 0.006 + 0.002 * sin(a * 5.0 + s * 20.0) - 0.002 * smoothstep(0.95, 1.0, s)
		if v == 1:   # konçta balon baskıları
			var oa0: float = J._outer_a(le, 0.85, Vector3(0.0, 0.0, 1.0))
			for e in [[tk + 0.07, oa0 - 0.4, rd], [tk + 0.13, oa0 + 0.35, Color(0.95, 0.66, 0.2)], [tk + 0.1, oa0 + PI * 0.55 * sg, Color(0.72, 0.56, 0.86)]]:
				var mp0: Callable = R._lmap(le, lo, float(e[0]), float(e[1]))
				_balloon(k, mp0, R._out_of(mp0), 0.0085, e[2], func(p): return R._lsk(le, p))
		elif v == 2:   # konçta sarı baklava çiftleri
			var oa1: float = J._outer_a(le, 0.85, Vector3(0.0, 0.0, 1.0))
			for ss in [tk + 0.06, tk + 0.1, tk + 0.16, tk + 0.2]:
				var e1: Array = Q._ls(le, ss, oa1, float(lo.call(ss, oa1)) + 0.0012)
				var dd: Vector3 = -(P._ld(le, ss) as Vector3)
				var sx: Vector3 = (e1[1] as Vector3).cross(dd).normalized()
				P._boxr(k, e1[0], (sx + dd).normalized() * 0.0065, (dd - sx).normalized() * 0.0065, (e1[1] as Vector3) * 0.0018, yl, P._lskin(le, ss), 0.15)
		# sağ uylukta kapaklı büyük cep + dış yanda kese
		if sd == "Right":
			var oa: float = J._outer_a(le, 0.42, Vector3(-0.55, 0.0, 0.85).normalized())
			var pad := func(s, a): return float(pa.call(float(s), float(a))) + 0.0015
			K._shell(k, le, 0.3, kn - 0.04, oa - 0.62, oa + 0.62, pad, 0.0045, func(u, vv, e):
				if e:
					return pc.darkened(0.3)
				return pc.lightened(0.04).darkened(0.12 * float(minf(float(u), 1.0 - float(u)) < 0.04 or float(vv) > 0.95)), 12, 16)
			var flap := func(s, a): return float(pa.call(float(s), float(a))) + 0.0058
			K._shell(k, le, 0.28, 0.36, oa - 0.68, oa + 0.68, flap, 0.004, func(u, vv, e):
				if e:
					return pc.darkened(0.3)
				if v == 1 and float(vv) > 0.3 and float(vv) < 0.62:
					return cy
				if v == 2 and float(vv) > 0.25 and float(vv) < 0.75:
					return rd if float(u) > 0.86 else (yl if int(floor(float(vv) * 8.0)) % 2 == 0 else Color(0.08, 0.08, 0.09))
				return pc.darkened(0.06), 4, 18)
			# kese: uyluğun dış yanında, kalça bandına asılı
			var s0 := 0.14
			k.wrap_turn(P._lp(le, s0), P._ld(le, s0), P._lr(le, s0) + float(pa.call(s0, 0.0)) + 0.007, 0.011, 0.012, pou.darkened(0.15), P._lskin(le, s0))
			var ao: float = J._outer_a(le, s0 + 0.05, Vector3(-1.0, 0.0, 0.1))
			var e2: Array = Q._ls(le, s0 + 0.06, ao, float(pa.call(s0 + 0.06, ao)) + 0.02)
			var o2: Vector3 = e2[1]
			var d2: Vector3 = P._ld(le, s0)
			var bo := [["RightUpperLeg", 1.0]]
			_blk(k, e2[0], o2.cross(d2), -d2, o2, 0.03, 0.06, 0.017, pou, bo)
			_blk(k, (e2[0] as Vector3) + o2 * 0.016 + d2 * -0.034, o2.cross(d2), -d2, o2, 0.032, 0.022, 0.005, pou.darkened(0.12), bo, 0.2)
			if v == 1:
				P._stud(k, (e2[0] as Vector3) + o2 * 0.022 - d2 * 0.02, o2, 0.0035, Color(0.92, 0.92, 0.93), bo)
	# kollar: çıplak üst kol, dirsek altına uzanan parmaksız eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 1.1 if sd == "Left" else 2.2
		var ba: Dictionary = AA._bare_arm(k, sd)
		P._bare(k, ba, skc, 0.0, ak + 0.06)
		var s0: float = ak + 0.035
		var gf: Callable = _long_mitt(k, sd, ar, s0, glc, sv)
		if v == 1:   # eldivende balonlar
			var oa: float = J._outer_a(ar, 0.6, Vector3(float(ar["sg"]) * 0.3, 0.0, 1.0).normalized())
			for e in [[0.62, oa, rd], [0.71, oa + 0.5, Color(0.95, 0.66, 0.2)], [0.8, oa - 0.3, Color(0.72, 0.56, 0.86)], [0.66, oa + PI, cy]]:
				var mp: Callable = R._lmap(ar, gf, float(e[0]), float(e[1]))
				_balloon(k, mp, R._out_of(mp), 0.0078, e[2], func(p): return R._lsk(ar, p))
	# tunik: kolsuz, omuz başını örter, uyluğa iner; kemer altında hafif açılır
	var tk2 := [P._kp(nk, N + 0.02, 0.022), [N - 0.05, ch.x * 0.99, ch.y * 0.93, ch.z * 1.03], P._kp(ch, C - 0.03, 0.024), P._kp(wa, H + 0.12, 0.03), P._kp(hp, H - 0.03, 0.044), [hem, hp.x + 0.07, hp.y + 0.058, hp.z - 0.062]]
	var tf := func(a: float, y: float) -> float:
		var nb: float = 1.0 - exp(-pow((y - by) / 0.03, 2.0))
		var t: float = clampf((by - y) / (by - hem), 0.0, 1.0)
		return nb * (t * (0.02 * sin(a * 7.0 + 0.4) + 0.008 * sin(a * 13.0 + 1.3)) + (1.0 - t) * (0.006 * sin(a * 6.0 + y * 14.0) * smoothstep(N - 0.02, C - 0.04, y) + 0.008 * sin(a * 5.0 - y * 9.0) * smoothstep(C - 0.03, by + 0.03, y)))
	var tff := func(a, y): return tf.call(float(a), float(y))
	var tg: Dictionary = P._cl(k, {"keys": tk2, "ny": 40, "na": 96, "top": func(_a): return N + 0.02, "hem": func(a): return hem + 0.006 * cos(float(a) * 2.0), "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return tu, "gain": 6.0, "th": 0.006, "inner": tu.darkened(0.35), "skin": fam})
	var thm := []
	for p in tg["hem"]:
		thm.append((p as Vector3) + Vector3(0, 0.009, 0))
	P._bd(k, thm, 0.0035, 0.0018, tu.darkened(0.16), true, fam)
	for sg in [1.0, -1.0]:
		P._hole(k, tk2, sg, C + 0.005, 0.42, 0.085, 0.0042, 0.003, tu.darkened(0.14))
		Q._run(k, tk2, tff, [Vector2(sg * PI * 0.5, C - 0.08), Vector2(sg * PI * 0.5, by + 0.02)], 0.0018, 0.0012, 0.0012, tu.darkened(0.22), tsk, 8)
		Q._run(k, tk2, tff, [Vector2(sg * PI * 0.5, by - 0.025), Vector2(sg * PI * 0.5, hem + 0.012)], 0.0018, 0.0012, 0.0012, tu.darkened(0.22), fam, 6)
	if v == 1:   # su balonu baskıları: önde ve sırtta
		var bl := [[0.12, C + 0.07, 0.034, cy, 0.05], [-0.62, C - 0.02, 0.03, rd, 0.07], [0.62, C - 0.005, 0.028, Color(0.95, 0.66, 0.2), 0.09], [0.42, C - 0.085, 0.024, Color(0.75, 0.6, 0.88), 0.0],
			[1.15, C - 0.07, 0.022, Color(0.96, 0.8, 0.24), 0.0], [-1.1, H + 0.15, 0.02, cy, 0.0], [0.85, by - 0.055, 0.02, rd, 0.0], [-0.4, by - 0.06, 0.022, Color(0.96, 0.8, 0.24), 0.0],
			[PI - 0.5, C - 0.02, 0.03, rd, 0.0], [PI + 0.35, C + 0.05, 0.026, cy, 0.0], [PI + 0.9, H + 0.18, 0.024, Color(0.75, 0.6, 0.88), 0.0], [PI - 1.0, H + 0.2, 0.022, Color(0.95, 0.66, 0.2), 0.0], [PI, by - 0.06, 0.02, cy, 0.0]]
		for e in bl:
			var mp: Callable = Q._local(tk2, tff, float(e[0]), float(e[1]))
			_balloon(k, mp, Q._spt(tk2, tff, float(e[0]), float(e[1]))[1], float(e[2]), e[3], tsk if float(e[1]) > H + 0.02 else fam, float(e[4]))
	elif v == 2:   # eteğin altında boncuklu sarı üçgen saçak
		for i in 22:
			var a: float = TAU * (float(i) + 0.5) / 22.0 - PI
			var hy: float = hem + 0.006 * cos(a * 2.0)
			var mp2: Callable = Q._local(tk2, tff, a, hy + 0.004)
			var o3: Vector3 = Q._spt(tk2, tff, a, hy)[1]
			_tri_tab(k, mp2, o3, 0.017, 0.03, 0.0025, yl, fam)
			var tip: Vector3 = mp2.call(0.0, -0.034, 0.004)
			Y._ball(k, tip, 0.0042, Color(0.96, 0.86, 0.5), fam.call(tip))
	# kemer: geniş bant + iki dikey köprü
	var bkk: Array = []
	for e in tk2:
		bkk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	var bp: Array = P._ring_pts(bkk, by, 0.004, 96)
	P._bd(k, bp, 0.03, 0.0045, blc, true, tsk)
	P._bd(k, P._ring_pts(bkk, by + 0.029, 0.0075, 96), 0.0018, 0.002, blc.darkened(0.2), true, tsk)
	P._bd(k, P._ring_pts(bkk, by - 0.029, 0.0075, 96), 0.0018, 0.002, blc.darkened(0.2), true, tsk)
	if v == 1:   # iki camgöbeği şerit
		for dy in [-0.009, 0.009]:
			P._bd(k, P._ring_pts(bkk, by + dy, 0.0098, 96), 0.0035, 0.0018, cy, true, tsk)
	elif v == 2:   # lacivert orta bant + baklava sırası + üst kenarda diş sırası
		P._bd(k, P._ring_pts(bkk, by + 0.008, 0.0098, 96), 0.0055, 0.0018, Color(0.16, 0.16, 0.3), true, tsk)
		for i in 30:
			var a: float = TAU * float(i) / 30.0 - PI
			var e3: Array = P._sa(bkk, a, by - 0.013, 0.0105)
			var ux: Vector3 = Vector3.UP.cross(e3[1]).normalized()
			P._boxr(k, e3[0], (ux + Vector3.UP).normalized() * 0.0062, (Vector3.UP - ux).normalized() * 0.0062, (e3[1] as Vector3) * 0.0016, Color(0.4, 0.18, 0.55) if i % 2 == 0 else Color(0.16, 0.16, 0.3), tsk.call(e3[0]), 0.1)
			var e4: Array = P._sa(bkk, a + PI / 30.0, by + 0.031, 0.006)
			P._boxr(k, e4[0], ux * 0.0042, Vector3.UP * 0.004, (e4[1] as Vector3) * 0.0025, yl.darkened(0.08), tsk.call(e4[0]), 0.15)
	for a0 in [0.3, -0.55]:
		var e5: Array = P._sa(bkk, a0, by, 0.012)
		var ux2: Vector3 = Vector3.UP.cross(e5[1]).normalized()
		_blk(k, e5[0], ux2, Vector3.UP, e5[1], 0.013, 0.036, 0.0045, lpc, tsk.call(e5[0]))
		_blk(k, (e5[0] as Vector3) + (e5[1] as Vector3) * 0.004, ux2, Vector3.UP, e5[1], 0.008, 0.029, 0.002, lpc.darkened(0.12), tsk.call(e5[0]), 0.2)
	# kılıflık kayışı: sol omuzdan sağ kalçaya (önde ve sırtta)
	var fr := [Vector2(1.3, N - 0.03)]
	var bk := [Vector2(1.3, N - 0.03)]
	for i in 6:   # önde ve sırtta düz verev: x boyda doğrusal (açıdan çevrilir)
		var t := float(i) / 5.0
		var y: float = lerpf(N - 0.075, by + 0.02, t)
		var w: float = float(SE.El.key_at(tk2, y)[1])
		var x: float = lerpf(ch.x * 0.72, -hp.x * 0.62, t)
		var a: float = asin(clampf(x / w, -0.97, 0.97))
		fr.append(Vector2(a, y))
		bk.append(Vector2(PI - a, y))
	var shw: float = 0.019
	Q._run(k, tk2, tff, fr, shw, 0.0045, 0.0032, stc, tsk, 8)
	Q._run(k, tk2, tff, bk, shw, 0.0045, 0.0032, stc, tsk, 8)
	for side in [1.0, -1.0]:
		var ed := []
		for q in P._path(fr, 8):
			ed.append(q)
		var pts := []
		var ou := []
		for i in ed.size():
			var q2: Vector2 = ed[i]
			var qn: Vector2 = ed[mini(i + 1, ed.size() - 1)]
			var qp: Vector2 = ed[maxi(i - 1, 0)]
			var e6: Array = Q._spt(tk2, tff, q2.x, q2.y, 0.0075)
			var e7: Array = Q._spt(tk2, tff, qn.x, qn.y, 0.0075)
			var e8: Array = Q._spt(tk2, tff, qp.x, qp.y, 0.0075)
			var dd: Vector3 = ((e7[0] as Vector3) - (e8[0] as Vector3)).normalized()
			var sx: Vector3 = (e6[1] as Vector3).cross(dd).normalized()
			pts.append((e6[0] as Vector3) + sx * shw * 0.92 * side)
			ou.append(e6[1])
		k.strip(pts, ou, 0.0016, 0.0016, stc.darkened(0.22), false, tsk)
	var sp: Array = P._path(fr, 8)
	if v == 1:   # kırmızı çizgili beyaz noktalar
		for i in range(12, sp.size() - 2, 3):
			var q3: Vector2 = sp[i]
			var mp3: Callable = Q._local(tk2, tff, q3.x, q3.y)
			Q._disc(k, mp3, Q._spt(tk2, tff, q3.x, q3.y)[1], 0.0085, 0.0082, Callable(), func(u, vv):
				return Color(0.95, 0.94, 0.94) if absf(float(u) * 0.7 + float(vv) * 0.7) < 0.14 or absf(float(u) * 0.7 + float(vv) * 0.7 - 0.45) < 0.12 else rd, tsk, 3, 18)
	elif v == 2:   # koyu çizgiler
		for i in range(14, sp.size() - 3, 6):
			var q4: Vector2 = sp[i]
			var qn4: Vector2 = sp[i + 1]
			var e9: Array = Q._spt(tk2, tff, q4.x, q4.y, 0.0078)
			var dd2: Vector3 = ((Q._spt(tk2, tff, qn4.x, qn4.y, 0.0078)[0] as Vector3) - (e9[0] as Vector3)).normalized()
			var sx2: Vector3 = (e9[1] as Vector3).cross(dd2).normalized()
			k.strip([(e9[0] as Vector3) - sx2 * shw * 0.8, (e9[0] as Vector3) + sx2 * shw * 0.8], [e9[1], e9[1]], 0.0022, 0.0014, Color(0.3, 0.2, 0.1), false, tsk)
	# fişek kutuları: kayışın üst ucunda 3 sıra x 2
	for r in 3:
		var q5: Vector2 = sp[3 + r * 2]
		var q6: Vector2 = sp[4 + r * 2]
		var ea: Array = Q._spt(tk2, tff, q5.x, q5.y, 0.0085)
		var dd3: Vector3 = ((Q._spt(tk2, tff, q6.x, q6.y, 0.0085)[0] as Vector3) - (ea[0] as Vector3)).normalized()
		var o5: Vector3 = ea[1]
		var sx3: Vector3 = o5.cross(dd3).normalized()
		for c2 in [-1.0, 1.0]:
			var cc: Vector3 = (ea[0] as Vector3) + sx3 * c2 * 0.0085 + o5 * 0.004
			_blk(k, cc, sx3, dd3, o5, 0.0075, 0.0052, 0.0045, amc, tsk.call(cc), 0.2)
			_blk(k, cc + o5 * 0.0042, sx3, dd3, o5, 0.0055, 0.0028, 0.0012, amc.lightened(0.18) if v != 2 else yl.darkened(0.2), tsk.call(cc), 0.25)
	# atkı: boynu saran kalın yumuşak rulo, omza yayılır
	var q: float = Q._hq(k)
	var sk := [[N + 0.07 * q, nk.x + 0.03, nk.y + 0.03, nk.z - 0.032], [N + 0.03 * q, nk.x + 0.055, nk.y + 0.05, nk.z - 0.05], [N - 0.03, nk.x + 0.085, nk.y + 0.075, nk.z - 0.07], [N - 0.075, ch.x * 0.76, ch.y * 0.9, ch.z * 0.94]]
	var sf := func(a: float, y: float, _v: float) -> float:
		var t: float = clampf((y - (N - 0.075)) / (0.145 * q + 0.075), 0.0, 1.0)
		return 0.06 * sin(t * PI) * (0.75 + 0.25 * cos(a)) + 0.014 * sin(a * 5.0 + y * 30.0) * sin(t * PI) + 0.006 * sin(a * 9.0 - y * 40.0)
	var cg: Dictionary = P._cl(k, {"keys": sk, "ny": 18, "na": 64, "top": func(_a): return N + 0.07 * q, "hem": func(a): return N - 0.075 - 0.012 * maxf(0.0, cos(float(a))),
		"fold": sf, "col": func(_a, _y, _v): return scf, "gain": 4.0, "th": 0.006, "inner": scf.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.007, scf.darkened(0.04), true, nsk)
	# önde düşen kat: sol yandan gelen ikinci tur
	var rl := []
	for i in 21:
		var a: float = lerpf(-1.7, 1.9, float(i) / 20.0)
		var y: float = N - 0.035 + 0.035 * q * smoothstep(-1.7, -0.6, a) - 0.012 * cos(a) + 0.02 * smoothstep(0.6, 1.9, a) * q
		rl.append(Q._spt(sk, func(aa, yy): return sf.call(float(aa), float(yy), 0.0), a, y, 0.005)[0])
	P._tb(k, rl, func(s, aa): return 0.016 * (0.6 + 0.4 * sin(float(s) * PI)) * (1.0 + 0.1 * sin(float(aa) * 2.0 + float(s) * 18.0)), func(s, aa, _p):
		return scf.darkened(0.12) if sin(float(s) * 25.0 + float(aa)) < -0.7 else scf, func(_s, p): return nsk.call(p), 10)
	if v == 2:   # üst kenarda boncuklu sarı üçgenler
		for i in 9:
			var a2: float = lerpf(-1.25, 1.25, float(i) / 8.0)
			var y2: float = N + 0.062 * q
			var ff := func(aa, yy): return sf.call(float(aa), float(yy), 0.0)
			var mp4: Callable = Q._local(sk, ff, a2, y2)
			var o4: Vector3 = Q._spt(sk, ff, a2, y2)[1]
			_tri_tab(k, mp4, o4, 0.011, 0.02, 0.009, yl, nsk)
			var tip2: Vector3 = mp4.call(0.0, -0.023, 0.011)
			Y._ball(k, tip2, 0.0034, Color(0.96, 0.86, 0.5), nsk.call(tip2))


## Eğik kuşak: y(a) boyunca katlı kalın bez halkası (bir yanda aşağı iner)
static func _tsash(k, keys: Array, yf: Callable, h: float, lift: float, col: Color) -> void:
	var rows := []
	var cc := []
	var na := 64
	for j in 7:
		var t := float(j) / 6.0
		var bb := 0.007 * sin(t * PI) + lift
		var ro := []
		var cr := []
		for i in na:
			var a := TAU * i / na - PI
			var y0: float = yf.call(a)
			var s: Array = SE.El.key_at(keys, y0)
			var wob := 0.004 * sin(a * 5.0 + t * 7.0)
			var yy := y0 + h * (1.0 - 2.0 * t) + 0.004 * sin(a * 3.0 + 1.0)
			var q: Vector2 = SE.El.sup(a, float(s[1]) + bb + wob, float(s[2]) + bb + wob, float(s[3]) - bb - wob)
			ro.append(Vector3(q.x, yy, q.y))
			var cre: bool = (j == 2 or j == 4) and sin(a * 4.0 + float(j) + t * 3.0) > -0.3
			cr.append(col.darkened(0.16) if cre else col.lightened(0.03 * float(j == 3)))
		rows.append(ro)
		cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return k.torso_skin(p.y))


## Boncuk dizisi: pts boyunca boğumlu ip (her boncuk ayrı şişkinlik)
static func _beads(k, pts: Array, r: float, n: float, col: Color, skinf: Callable, closed := false) -> void:
	P._tb(k, pts, func(s, a): return r * (0.55 + 0.45 * pow(absf(sin(float(s) * n * PI)), 0.6)), func(s, a, _p):
		var hl: float = sin(float(a) + 0.8)
		return col.lightened(0.25) if hl > 0.7 and absf(sin(float(s) * n * PI)) > 0.6 else (col.darkened(0.25) if absf(sin(float(s) * n * PI)) < 0.35 else col), func(_s, p): return skinf.call(p), 8, closed)


## Bulut levha (Nibi işareti): yüzeye oturan, alt yanı dilimli plaka + dilim kenarları kabartma
static func _cloud_plate(k, mp: Callable, o: Vector3, r: float, col: Color, skinf: Callable, rot := 0.0) -> void:
	var rf := func(th: float) -> float:
		var w := wrapf(th - rot, -PI, PI)
		return 1.0 + (0.16 * absf(sin(w * 2.5)) if w < 0.0 else 0.0) - 0.12 * smoothstep(0.4, 1.6, w) * smoothstep(2.8, 1.6, w)
	Q._disc(k, mp, o, r, 0.0035, rf, func(_u, _v): return col, skinf, 4, 36)
	for i in 3:
		var c0 := Vector2(cos(rot - 0.7 - 0.9 * i), sin(rot - 0.7 - 0.9 * i)) * r * 0.55
		var arc := []
		for j in 7:
			var t := lerpf(rot - 2.6 - 0.9 * i, rot - 0.6 - 0.9 * i, float(j) / 6.0)
			arc.append(c0 + Vector2(cos(t), sin(t)) * r * 0.36)
		R._lstrip(k, mp, arc, r * 0.04, 0.0062, 0.0012, col.darkened(0.2), skinf)


# ------------------------------------------------------------------ Neko Yoroi (ref Shinobi Striker "Yugito Outfit" + refs/kiyafet/yugito): dik yakalı kısa kollu koyu mor üst,
## omuzsuz lavanta lamel göğüslük (dikey dikişler, sağ göğüs üstünde dilimli bulut levha), eğik kızıl sargı kuşak + sol önde düğüm,
## ön kolda beyaz sargı turları, sol ön kola sarılan mavi boncuk dizisi + bilezik, parmaksız siyah eldiven,
## baldır ortasına inen mor kapri + sol uyluk dışında bulut levhalar sırası, kapri altında beyaz bacak sargısı
static func _yugito(k) -> void:
	var pu := Color(0.27, 0.21, 0.4)
	var pp := Color(0.33, 0.24, 0.5)
	var lv := Color(0.66, 0.63, 0.71)
	var rs := Color(0.66, 0.22, 0.29)
	var wh := Color(0.93, 0.92, 0.9)
	var gl := Color(0.16, 0.14, 0.24)
	var bd := Color(0.24, 0.38, 0.72)
	var cl := Color(0.82, 0.82, 0.85)
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
	# iç üst (koyu mor) + dik yaka
	P._inner(k, b, func(_i, _j, _p): return pu, 0.006)
	K._seat(k, b, pp.darkened(0.06))
	var q: float = Q._hq(k)
	var ck := [[N + 0.075 * q, nk.x + 0.016, nk.y + 0.016, nk.z - 0.018], [N + 0.02 * q, nk.x + 0.02, nk.y + 0.02, nk.z - 0.02], [N - 0.03, nk.x + 0.042, nk.y + 0.038, nk.z - 0.04]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 10, "na": 48, "top": func(_a): return N + 0.075 * q, "hem": func(_a): return N - 0.03,
		"fold": func(a, y, _v): return 0.012 * sin(float(a) * 7.0 + float(y) * 40.0) * smoothstep(N + 0.06 * q, N, float(y)), "col": func(_a, _y, _v): return pu, "gain": 6.0, "th": 0.005, "inner": pu.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.0042, pu.darkened(0.1), true, nsk)
	# kısa kol + çıplak kol + ön kol sargısı + eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = G._arm(k, sd)   # omuz başı gövde ölçüsüne karışmaz (kol ağzı sivrilmez)
		var ak: float = ar["kn"]
		var sv: float = 0.8 if sd == "Left" else 2.1
		var ba: Dictionary = AA._bare_arm(k, sd)
		P._bare(k, ba, skc, ak - 0.25, 0.9)
		var s1: float = ak - 0.18
		var sf := func(s: float, a: float) -> float: return 0.009 + 0.008 * smoothstep(0.05, s1, s) + 0.003 * P._lf(s, a, sv) * smoothstep(0.08, 0.2, s) + 0.003 * exp(-pow((s - s1 + 0.04) / 0.04, 2.0)) * sin(a * 5.0 + sv)
		P._lt(k, ar, sf, func(s, a, ins): return pu.darkened(0.35) if ins else P._fs(pu, float(sf.call(float(s), float(a))) - 0.009 - 0.008 * smoothstep(0.05, s1, float(s)), 12.0), 0.0, s1, 22, 22, 0.03)
		K._lt_in(k, ar, func(s, a): return float(sf.call(float(s), float(a))) - 0.005, pu.darkened(0.4), s1 - 0.06, s1 - 0.004, 5, 22)
		Q._ring_on(k, ar, s1 - 0.012, func(s, a): return float(sf.call(float(s), float(a))) + 0.0008, 0.011, pu.darkened(0.06), 0.003)
		# ön kol sargısı: koyu taban + turlar
		var w0: float = ak + 0.04
		P._lt(k, ar, func(_s, _a): return 0.0035, func(_s, _a, ins): return wh.darkened(0.35) if ins else wh.darkened(0.2), w0, 0.9, 14, 18)
		P._lt(k, ar, func(_s, _a): return 0.004, func(_s, _a, ins): return gl.darkened(0.3) if ins else gl, 0.89, 0.958, 6, 18, 0.01)
		P._wraps(k, ar, w0 + 0.012, 0.86, 12, 0.004, 0.0105, wh, 0.006)
		if sd == "Left":   # boncuk dizisi: ön kola sarmal + bilezik
			var hp2 := []
			for i in 61:
				var t := float(i) / 60.0
				var s: float = lerpf(w0 + 0.01, 0.92, t)
				var a: float = 0.4 + t * TAU * 2.6
				hp2.append(Q._ls(ar, s, a, 0.0125)[0])
			_beads(k, hp2, 0.0034, 26.0, bd, func(p): return R._lsk(ar, p))
			var br := []
			for i in 24:
				br.append(Q._ls(ar, 0.935, TAU * i / 24.0, 0.0105)[0])
			_beads(k, br, 0.0032, 12.0, bd.lightened(0.08), func(_p): return P._lskin(ar, 0.935), true)
	# kapri: baldır ortasına iner, altında beyaz sargı; sol uyluk dışında bulut levhalar
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 1.3 if sd == "Left" else 0.2
		var s1: float = kn + 0.23
		var pa: Callable = K._pant(k, le, pp, 0.016, 0.024, s1, sv)
		Q._ring_on(k, le, s1 - 0.012, func(s, a): return float(pa.call(s, a)) + 0.001, 0.013, pp.darkened(0.06), 0.0035)
		P._lt(k, le, func(_s, _a): return 0.0035, func(_s, _a, ins): return wh.darkened(0.35) if ins else wh.darkened(0.2), s1 - 0.04, 0.985, 14, 18)
		P._wraps(k, le, s1 + 0.004, 0.975, 10, 0.004, 0.0125, wh, 0.007)
		if sd == "Left":
			var oa: float = J._outer_a(le, 0.6, Vector3(1.0, 0.0, 0.2).normalized())
			var lift := func(s, a): return float(pa.call(float(s), float(a))) + 0.0015
			K._shell(k, le, 0.36, s1 - 0.02, oa - 0.3, oa + 0.3, lift, 0.004, func(_u, _v, e): return cl.darkened(0.3) if e else cl.darkened(0.06), 14, 12)
			for i in 6:
				var ss: float = lerpf(0.4, s1 - 0.05, float(i) / 5.0)
				var mp: Callable = R._lmap(le, func(s, a): return float(pa.call(float(s), float(a))) + 0.0055, ss, oa - 0.26)
				_cloud_plate(k, mp, R._out_of(mp), 0.026, cl, func(p): return R._lsk(le, p), PI)
	# lamel göğüslük: omuzsuz, koltuk altından bele; yatay bindirmeli levhalar + dikey dikişler
	var vt: float = C + 0.055
	var vh: float = H + 0.03
	var vk := [P._kp(ch, vt + 0.01, 0.014), P._kp(ch, C - 0.03, 0.016), P._kp(wa, H + 0.12, 0.016), P._kp(k.M(vh, 0.3), vh, 0.016)]
	var lam := func(y: float) -> float: return 0.006 * fposmod((y - vh) / 0.036, 1.0)
	var vf := func(a: float, y: float, _v: float) -> float: return float(lam.call(y)) + 0.003 * sin(a * 6.0 + y * 12.0)
	var vtop := func(a: float) -> float: return vt - 0.022 * smoothstep(0.9, 1.6, absf(a)) + 0.01 * smoothstep(2.0, PI, absf(a))
	var vg: Dictionary = P._cl(k, {"keys": vk, "ny": 30, "na": 88, "top": func(a): return vtop.call(float(a)), "hem": func(_a): return vh, "fold": vf,
		"col": func(_a, y, _v): return lv.darkened(0.14 * float(float(lam.call(float(y))) < 0.0008)), "gain": 4.0, "th": 0.006, "inner": lv.darkened(0.35), "skin": tsk})
	P._cord(k, vg["top"], 0.004, lv.darkened(0.1), true, tsk)
	var vff := func(a, y): return vf.call(float(a), float(y), 0.0)
	for a0 in [0.38, -0.38, 1.2, -1.2, PI - 0.45, -PI + 0.45]:
		Q._run(k, vk, vff, [Vector2(a0, vtop.call(a0) - 0.008), Vector2(a0 * 1.04, C - 0.03), Vector2(a0, vh + 0.03)], 0.0018, 0.0075, 0.0014, lv.darkened(0.25), tsk, 8)
	var mpc: Callable = Q._local(vk, vff, -0.6, vt - 0.04)
	_cloud_plate(k, mpc, Q._spt(vk, vff, -0.6, vt - 0.04)[1], 0.048, cl, tsk, 0.3)
	# kızıl sargı kuşak: sağda aşağı iner, sol önde düğüm
	var sy := func(a: float) -> float: return H + 0.035 + 0.022 * sin(a) - 0.006 * cos(a)
	var skk: Array = []
	for e in [P._kp(wa, H + 0.12, 0.02), P._kp(k.M(H + 0.04, 0.3), H + 0.04, 0.024), P._kp(hp, H - 0.03, 0.03)]:
		skk.append(e)
	_tsash(k, skk, sy, 0.03, 0.004, rs)
	var ka: float = 0.55
	var ke: Array = Q._spt(skk, Callable(), ka, sy.call(ka), 0.03)
	var ko: Vector3 = ke[1]
	var kux: Vector3 = Vector3.UP.cross(ko).normalized()
	var kb := [["Hips", 0.5], ["Spine", 0.5]]
	_blk(k, ke[0], kux, Vector3.UP, ko, 0.016, 0.019, 0.011, rs.darkened(0.06), kb, 0.45)
	for sg in [1.0, -1.0]:   # düğümün iki kulağı: yanlara yatan kısa katlar
		var c0: Vector3 = (ke[0] as Vector3) + kux * sg * 0.026 - ko * 0.003
		_blk(k, c0, kux + Vector3.UP * 0.15 * sg, Vector3.UP, ko, 0.014, 0.012, 0.008, rs.lightened(0.04), kb, 0.5)
	var tl := []
	var to := []
	for i in 8:
		var t := float(i) / 7.0
		var a3: float = ka - 0.08 - 0.12 * t
		var e3: Array = Q._spt(skk, Callable(), a3, sy.call(ka) - 0.02 - t * 0.075, 0.034 - 0.012 * t)
		tl.append(e3[0])
		to.append(e3[1])
	Y._ribbon(k, tl, to, func(t): return lerpf(0.015, 0.012, float(t)), 0.003, rs.darkened(0.04), func(p): return AA._fam(k, p, H - 0.06))


## Fitilli ısıtıcı: uzvu saran açık mavi tüp, boyuna koyu fitil çizgileri (kabartma), üst / alt ağızda siyah bant
static func _warmer(k, l: Dictionary, s0: float, s1: float, base: float, col: Color, ln: Color, trim: Color, sv: float) -> Callable:
	var wf := func(s: float, a: float) -> float:
		var u: float = clampf((s - s0) / maxf(0.01, s1 - s0), 0.0, 1.0)
		return base + 0.0018 * cos(a * 12.0 + sv) + 0.0025 * sin(a * 2.0 + s * 14.0 + sv) * sin(u * PI) + 0.004 * exp(-pow(u / 0.06, 2.0))
	P._lt(k, l, wf, func(s, a, ins): return col.darkened(0.45) if ins else P._fs(col, 0.0018 * cos(float(a) * 12.0 + sv), 14.0), s0, s1, 22, 36, 0.02)
	var angs := []
	for i in 12:
		angs.append(TAU * (float(i) + 0.5) / 12.0 - PI - sv / 12.0)
	for a0 in angs:
		var av: float = a0
		S._lstrip(k, l, s0 + 0.03, s1 - 0.025, func(_s): return av, wf, 0.0016, 0.0014, ln, 12)
	Q._ring_on(k, l, s0 + 0.014, wf, 0.011, trim, 0.003)
	Q._ring_on(k, l, s1 - 0.01, wf, 0.008, trim, 0.0025)
	return wf


# ------------------------------------------------------------------ Kiri no Oni (ref Shinobi Striker "Zabuza Outfit"): geniş askılı kolsuz siyah üst (askı dikişleri önde ve sırtta), arkada düğmeli bel kuşağı,
## bileğe doğru toplanan bol siyah pantolon, boynu iki tur saran beyaz atkı + göğse düşen ucu (kumaşa yatar), siyah bantlı çizgili açık mavi kol ve bacak ısıtıcısı
static func _iblis(k) -> void:
	var bk := Color(0.09, 0.09, 0.105)
	var wh := Color(0.91, 0.91, 0.925)
	var wm := Color(0.66, 0.72, 0.88)
	var wl := Color(0.36, 0.42, 0.62)
	var trim := Color(0.07, 0.07, 0.09)
	var mt := Color(0.7, 0.71, 0.74)
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
	K._seat(k, b, bk)
	# pantolon: bol, baldırda ısıtıcının içine toplanır
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 0.7 if sd == "Left" else 2.0
		var tk: float = kn + 0.22
		Q._baggy(k, le, bk, bk, 0.015, 0.017, tk, sv)
		_warmer(k, le, tk - 0.03, 0.985, 0.0135, wm, wl, trim, sv)
	# kollar: çıplak, dirsek altından ele ısıtıcı + siyah el bandı
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var ak: float = ar["kn"]
		var sv: float = 1.4 if sd == "Left" else 2.9
		P._bare(k, AA._bare_arm(k, sd), skc, 0.0, ak + 0.08)
		_warmer(k, ar, ak + 0.045, 0.94, 0.0058, wm, wl, trim, sv)
		P._lt(k, ar, func(s, _a): return 0.0045 + 0.001 * smoothstep(0.95, 0.975, float(s)), func(_s, _a, ins): return trim.darkened(0.3) if ins else trim, 0.93, 0.958, 4, 18, 0.01)
	# üst: kolsuz, geniş askılı; boyundan bele, belde pantolona girer
	var top: float = N + 0.005
	var keys := [P._kp(nk, top, 0.02), [N - 0.05, ch.x * 0.98, ch.y * 0.92, ch.z * 1.02], P._kp(ch, C - 0.03, 0.018), P._kp(wa, H + 0.12, 0.02), P._kp(hp, H - 0.02, 0.028)]
	var tf := func(a: float, y: float) -> float: return 0.006 * sin(a * 6.0 + y * 14.0) * smoothstep(C, H + 0.1, y) + 0.004 * sin(a * 9.0 - y * 20.0) * smoothstep(N - 0.02, C - 0.04, y)
	var tff := func(a, y): return tf.call(float(a), float(y))
	var tg: Dictionary = P._cl(k, {"keys": keys, "ny": 34, "na": 88, "top": func(a): return top - 0.025 * pow(maxf(0.0, cos(float(a))), 3.0), "hem": func(_a): return H - 0.02, "fold": func(a, y, _v): return tf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.005, "inner": bk.lightened(0.04), "skin": tsk})
	P._cord(k, tg["top"], 0.0042, bk.lightened(0.05), true, nsk)
	for sg in [1.0, -1.0]:
		P._hole(k, keys, sg, C + 0.005, 0.42, 0.085, 0.0042, 0.003, bk.lightened(0.06))
		# askı dikişleri: omuzdan göğse (önde) ve kürek kemiğine (arkada)
		Q._run(k, keys, tff, [Vector2(sg * 0.95, N - 0.02), Vector2(sg * 0.85, C + 0.0), Vector2(sg * 0.8, C - 0.07)], 0.002, 0.0014, 0.0013, bk.lightened(0.1), tsk, 8)
		Q._run(k, keys, tff, [Vector2(sg * (PI - 0.95), N - 0.02), Vector2(sg * (PI - 0.85), C + 0.0), Vector2(sg * (PI - 0.8), C - 0.07)], 0.002, 0.0014, 0.0013, bk.lightened(0.1), tsk, 8)
		Q._run(k, keys, tff, [Vector2(sg * 0.8, C - 0.07), Vector2(sg * 0.15, C - 0.075), Vector2(sg * 0.0, C - 0.075)], 0.002, 0.0014, 0.0013, bk.lightened(0.1), tsk, 8)
		# karında iki cep yarığı + düğme
		Q._run(k, keys, tff, [Vector2(sg * 0.42, H + 0.13), Vector2(sg * 0.62, H + 0.05)], 0.0024, 0.0014, 0.0015, bk.lightened(0.12), tsk, 6)
		var ep: Array = Q._spt(keys, tff, sg * 0.4, H + 0.15, 0.003)
		P._stud(k, ep[0], ep[1], 0.0034, bk.lightened(0.16), tsk.call(ep[0]))
	# bel kuşağı: arkada iki düğmeyle iliklenir
	var by: float = H + 0.06
	var bkk: Array = []
	for e in keys:
		bkk.append([e[0], float(e[1]) + 0.004, float(e[2]) + 0.004, float(e[3]) - 0.004])
	P._bd(k, P._ring_pts(bkk, by, 0.004, 88), 0.022, 0.004, bk.lightened(0.06), true, tsk)
	for e in [[PI - 0.06, 1.0], [PI + 0.06, -1.0]]:
		var e1: Array = P._sa(bkk, float(e[0]), by, 0.0095)
		var ux: Vector3 = Vector3.UP.cross(e1[1]).normalized()
		_blk(k, e1[0], ux, Vector3.UP, e1[1], 0.022, 0.02, 0.003, bk.lightened(0.09), tsk.call(e1[0]), 0.3)
	for e in [[PI + 0.0, by + 0.009], [PI + 0.0, by - 0.009]]:
		var e2: Array = P._sa(bkk, float(e[0]), float(e[1]), 0.0135)
		P._stud(k, e2[0], e2[1], 0.005, mt, tsk.call(e2[0]))
	# atkı: boynu saran iki tur + göğse düşen uç
	var q: float = Q._hq(k)
	for e in [[N + 0.012 * q, 0.017, 0.4], [N + 0.045 * q, 0.015, 1.9]]:
		var pts := []
		for i in 32:
			var a := TAU * i / 32.0 - PI
			var y: float = float(e[0]) - 0.015 * pow(maxf(0.0, cos(a)), 2.0)
			var q2: Vector2 = SE.El.sup(a, nk.x + 0.02 + float(e[1]) * 0.5, nk.y + 0.024 + float(e[1]) * 0.5, nk.z - 0.016 - float(e[1]) * 0.4)
			pts.append(Vector3(q2.x, y, q2.y))
		var ph: float = e[2]
		P._tb(k, pts, func(s, a): return float(e[1]) * (1.0 + 0.12 * sin(float(s) * TAU * 3.0 + ph) + 0.06 * sin(float(a) * 2.0 + float(s) * 20.0)), func(s, a, _p):
			return wh.darkened(0.12) if sin(float(s) * TAU * 3.0 + ph + float(a)) < -0.6 else wh, func(_s, p): return nsk.call(p), 10, true)
	# düşen uç: sağ göğüste, kumaşa yatar
	var tl := []
	var to := []
	for i in 14:
		var t := float(i) / 13.0
		var y3: float = lerpf(N - 0.008, C - 0.11, t)
		var w3: float = float(SE.El.key_at(keys, y3)[1])
		var a3: float = asin(clampf(-0.075 / w3, -0.9, 0.9))   # düz iner: x sabit
		var e3: Array = Q._spt(keys, tff, a3, y3, 0.007 + 0.006 * (1.0 - t))
		if y3 > N - 0.035:
			e3 = [(e3[0] as Vector3) + (e3[1] as Vector3) * 0.012 * smoothstep(N - 0.035, N - 0.005, y3), e3[1]]
		tl.append(e3[0])
		to.append(e3[1])
	Y._ribbon(k, tl, to, func(t): return 0.021 - 0.002 * float(t), 0.004, wh, tsk)
	var e4: Array = Q._spt(keys, tff, asin(clampf(-0.075 / float(SE.El.key_at(keys, C - 0.112)[1]), -0.9, 0.9)), C - 0.112, 0.0115)
	k.strip([(e4[0] as Vector3) + Vector3(-0.019, 0, 0), (e4[0] as Vector3) + Vector3(0.019, 0, 0)], [e4[1], e4[1]], 0.0022, 0.002, wh.darkened(0.1), false, tsk)


## Fermuar: (açı, y) yolu boyunca koyu bant + iki yanda sıralı dişler (ayrı küçük parçalar) + üstte çekme dili
static func _zipper(k, keys: Array, ff: Callable, ctrl: Array, tape: Color, teeth: Color, skinf: Callable, pitch := 0.0085, pull := true) -> void:
	Q._run(k, keys, ff, ctrl, 0.0058, 0.0016, 0.0016, tape, skinf, 10)
	var path: Array = P._path(ctrl, 10)
	var pts := []
	for q in path:
		pts.append(Q._spt(keys, ff, q.x, q.y, 0.0034))
	var acc := 0.0
	var side := 1.0
	for i in range(1, pts.size()):
		var p0: Vector3 = pts[i - 1][0]
		var p1: Vector3 = pts[i][0]
		var seg: float = (p1 - p0).length()
		var dd: Vector3 = (p1 - p0).normalized()
		var o: Vector3 = pts[i][1]
		var sx: Vector3 = o.cross(dd).normalized()
		var t := 0.0
		while acc + seg - t >= pitch:
			t += pitch - acc
			acc = 0.0
			var c: Vector3 = p0.lerp(p1, t / seg) + sx * side * 0.0016
			P._boxr(k, c, sx * 0.0028, dd * 0.0019, o * 0.0016, teeth, skinf.call(c), 0.2)
			side = -side
		acc += seg - t
	if pull:
		var e: Array = pts[0]
		var dd2: Vector3 = ((pts[1][0] as Vector3) - (e[0] as Vector3)).normalized()
		var sx2: Vector3 = (e[1] as Vector3).cross(dd2).normalized()
		P._boxr(k, (e[0] as Vector3) + dd2 * 0.016 + (e[1] as Vector3) * 0.003, sx2 * 0.0042, dd2 * 0.012, (e[1] as Vector3) * 0.0018, teeth.lightened(0.1), skinf.call(e[0]), 0.3)


# ------------------------------------------------------------------ Kiba Shōzoku (ref Shinobi Striker "Kiba Outfit" 1-6): belde biten kısa siyah motorcu ceketi: verev fermuar (sol omuzdan göğüs ortasına, sonra dik),
## çentikli geniş klapalar + ense yakası, göğüs altında iki dikey fermuarlı cep, gri bel bandı, bileğe inen kırışık kollar; yakada file iç gömlek (dik bilekli boyun),
## baldır ortasına inen siyah kapri + altında çıplak baldır, sağ uylukta iki beyaz bantlı lacivert kılıf
static func _inuzuka(k) -> void:
	var bk := Color(0.095, 0.095, 0.11)
	var gy := Color(0.62, 0.62, 0.66)
	var zt := Color(0.86, 0.86, 0.88)
	var wh := Color(0.93, 0.93, 0.93)
	var nv := Color(0.12, 0.13, 0.26)
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
	var am := load("res://scripts/actors/set_el_am.gd")
	# file iç gömlek: gri taban + çapraz iplik; boyunda bilekli ağız
	var nt := skc.lerp(Color(0.35, 0.35, 0.38), 0.55)
	var ik: Array = P._inner(k, b, func(_i, _j, p): return nt if p.y > C - 0.02 else bk, 0.005)
	var va := 0.06
	var jtop := func(a: float) -> float:
		var d: float = absf(wrapf(a - va, -PI, PI))
		return lerpf(C + 0.03, N - 0.004, clampf((d - 0.02) / 0.5, 0.0, 1.0)) + 0.014 * smoothstep(1.4, PI, d)
	P._net_patch(k, ik, func(a, y): return float(y) > float(jtop.call(float(a))) - 0.03, -0.75, 0.85, C, N + 0.05, 0.012, 0.0011, 0.0022, Color(0.18, 0.18, 0.2))
	P._cord(k, P._ring_pts(ik, N + 0.045, 0.004, 40), 0.0035, Color(0.2, 0.2, 0.22), true, nsk)
	K._seat(k, b, bk)
	# kapri + çıplak baldır + sağ uylukta kılıf
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var kn: float = le["kn"]
		var sv: float = 2.4 if sd == "Left" else 1.0
		var s1: float = kn + 0.2
		P._bare(k, le, skc, s1 - 0.03, 1.0)
		var pa: Callable = K._pant(k, le, bk, 0.016, 0.022, s1, sv)
		Q._ring_on(k, le, s1 - 0.014, func(s, a): return float(pa.call(s, a)) + 0.0012, 0.015, bk.lightened(0.04), 0.004)
		if sd == "Right":
			am._holster(k, le, pa, wh, nv, kn * 0.42)
	# kollar: bileğe, dirsekte ve bilekte kırışık, bilekte büzgü
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var en: float = ar["kn"]
		var sv: float = 0.9 if sd == "Left" else 2.2
		var sf := func(s: float, a: float) -> float:
			return 0.016 + 0.008 * smoothstep(0.1, 0.5, s) + 0.0035 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) + 0.008 * exp(-pow((s - en) / 0.07, 2.0)) * sin(a * 3.0 + s * 30.0) + 0.006 * exp(-pow((s - 0.84) / 0.06, 2.0)) * sin(a * 5.0 + s * 50.0)
		P._lt(k, ar, sf, func(s, a, ins): return bk.lightened(0.04) if ins else P._fs(bk.lightened(0.02), float(sf.call(float(s), float(a))) - 0.02, 12.0), 0.0, 0.93, 36, 22, 0.03)
		Q._ring_on(k, ar, 0.915, sf, 0.012, bk.lightened(0.03), 0.003)
	# ceket: belde biter, V açıklık, omuz dikişi
	var hem: float = H + 0.06
	var jk := [P._kp(nk, N + 0.012, 0.03), [N - 0.055, ch.x * 1.04, ch.y * 0.98, ch.z * 1.06], P._kp(ch, C - 0.03, 0.036), P._kp(wa, H + 0.12, 0.04), [hem, wa.x + 0.04, wa.y + 0.038, wa.z - 0.038]]
	var jf := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 6.0 + y * 15.0) * smoothstep(C, hem, y) + 0.004 * sin(a * 11.0 - y * 9.0) + 0.006 * smoothstep(C + 0.02, hem, y) * sin(a * 3.0 + 1.0) * smoothstep(0.5, 1.2, absf(a))
	var jff := func(a, y): return jf.call(float(a), float(y))
	var jg: Dictionary = P._cl(k, {"keys": jk, "ny": 32, "na": 96, "top": func(a): return jtop.call(float(a)), "hem": func(_a): return hem, "fold": func(a, y, _v): return jf.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bk, "gain": 6.0, "th": 0.006, "inner": bk.lightened(0.05), "skin": tsk})
	# bel bandı
	var hb := []
	for p in jg["hem"]:
		hb.append((p as Vector3) + Vector3(0, 0.017, 0))
	P._bd(k, hb, 0.016, 0.0045, gy, true, tsk)
	# verev fermuar + üstte binen kanadın kalınlığı
	var zc := [Vector2(0.66, N - 0.045), Vector2(0.4, C + 0.0), Vector2(va + 0.01, C - 0.075), Vector2(va, H + 0.15), Vector2(va, hem + 0.03)]
	_zipper(k, jk, jff, zc, Color(0.2, 0.2, 0.22), zt, tsk)
	var ov := []
	for q in zc:
		ov.append(Vector2(q.x + 0.06, q.y))
	Q._run(k, jk, jff, ov, 0.004, 0.0022, 0.0028, bk.lightened(0.05), tsk, 10)
	# göğüs altı dikey cepler
	for sg in [1.0, -1.0]:
		var pc := [Vector2(sg * 0.66, C - 0.055), Vector2(sg * 0.68, hem + 0.045)]
		_zipper(k, jk, jff, pc, Color(0.16, 0.16, 0.18), zt, tsk, 0.0085, true)
		Q._run(k, jk, jff, [Vector2(sg * 0.66 + 0.035, C - 0.05), Vector2(sg * 0.68 + 0.035, hem + 0.045)], 0.0025, 0.0018, 0.0016, bk.lightened(0.06), tsk, 6)
		# omuz dikişi + yan dikiş
		Q._run(k, jk, jff, [Vector2(sg * 0.7, N - 0.04), Vector2(sg * 1.2, N - 0.055), Vector2(sg * 1.55, N - 0.06)], 0.002, 0.0018, 0.0014, bk.lightened(0.07), tsk, 6)
		Q._run(k, jk, jff, [Vector2(sg * PI * 0.5, C - 0.09), Vector2(sg * PI * 0.5, hem + 0.035)], 0.002, 0.0018, 0.0014, bk.lightened(0.07), tsk, 6)
	# çentikli klapalar: V kenarından dışa yatan iki kanat
	for sg in [-1.0, 1.0]:
		var rows := []
		for u in 5:
			var fu := float(u) / 4.0
			var ro := []
			for j in 15:
				var t := float(j) / 14.0
				var y: float = lerpf(N - 0.022, C + 0.032, t)
				var d0: float = clampf(((y - (C + 0.03)) / ((N - 0.004) - (C + 0.03))) * 0.48 + 0.02, 0.02, 0.5)
				var a_in: float = va + sg * d0
				var w: float = 0.2 if t < 0.2 else (lerpf(0.12, 0.44, smoothstep(0.2, 0.32, t)) if t < 0.45 else lerpf(0.44, 0.03, pow((t - 0.45) / 0.55, 0.9)))
				var a: float = a_in + sg * w * fu
				var e: Array = Q._spt(jk, jff, a, y - 0.004 * fu * float(t < 0.2), 0.004 + 0.0025 * sin(fu * PI) - 0.0025 * fu)
				ro.append(e[0])
			rows.append(ro)
		Q._mesh(k, rows, false, func(i, _j, _p): return bk.darkened(0.2) if i == 0 else bk.lightened(0.05), func(_i, _j, p): return tsk.call(p), Vector3(sg * 0.3, 0.0, 1.0).normalized())
	# ense yakası: boyun arkasını saran dik kat
	var q: float = Q._hq(k)
	var ck := [[N + 0.045 * q, nk.x + 0.034, nk.y + 0.034, nk.z - 0.036], [N + 0.0, nk.x + 0.04, nk.y + 0.04, nk.z - 0.042], [N - 0.03, nk.x + 0.06, nk.y + 0.05, nk.z - 0.05]]
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 8, "na": 40, "rng": func(_v): return Vector2(0.75, TAU - 0.75), "top": func(a): return N + q * lerpf(0.025, 0.045, smoothstep(0.8, 2.2, absf(float(a)))), "hem": func(_a): return N - 0.03,
		"fold": func(a, _y, v): return 0.01 * float(v) * sin(float(a) * 3.0), "col": func(_a, _y, _v): return bk.lightened(0.02), "inner": bk.lightened(0.06), "skin": nsk, "th": 0.005})
	P._cord(k, cg["top"], 0.0035, bk.lightened(0.06), false, nsk)
