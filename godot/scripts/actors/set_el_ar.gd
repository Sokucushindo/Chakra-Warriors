extends RefCounted
## Elle modellenmiş setler, parti ar: ss_gosterisli, ss_gosterisli_hava, ss_gosterisli_bahar, ss_tatli, ss_tatli_baklava, ss_tatli_kultur. Örnek: set_el.gd içindeki _shugonin.
## Ref: refs/outfits_ss/all/swanky_striker/{Swanky_Striker, Swanky_Air, Swanky_Springtime}, refs/outfits_ss/all/sweet_striker/{Sweet_1, Sweet_2, Sweet_3}.
## İki aile: _swanky (dik yakalı uzun ceket: önde fermuar biter, etek ucu yanlara verev çıkar, arkada baldıra sivri iner; astar açılımda görünür)
## ve _sweet (yüksek yakalı kolsuz iç üst + omzu açık kısa kazak, çan kol, bilek üstünde biten dar pantolon). Setin farkı ayrı kabartma parçalarla.
## Kumaş / uzuv yardımcıları parti e (P), k (K), q (Q), x (X), z (Z), aa (AA), y (Y), r (R) dosyalarından.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_e.gd")
const K = preload("res://scripts/actors/set_el_k.gd")
const Q = preload("res://scripts/actors/set_el_q.gd")
const X = preload("res://scripts/actors/set_el_x.gd")
const Z = preload("res://scripts/actors/set_el_z.gd")
const AA = preload("res://scripts/actors/set_el_aa.gd")
const Y = preload("res://scripts/actors/set_el_y.gd")
const R = preload("res://scripts/actors/set_el_r.gd")

const DONE := ["ss_gosterisli", "ss_gosterisli_hava", "ss_gosterisli_bahar", "ss_tatli", "ss_tatli_baklava", "ss_tatli_kultur"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	P._cur_long = false
	match sid:
		"ss_gosterisli": _gosterisli(k)
		"ss_gosterisli_hava": _hava(k)
		"ss_gosterisli_bahar": _bahar(k)
		"ss_tatli": _tatli(k)
		"ss_tatli_baklava": _baklava(k)
		"ss_tatli_kultur": _kultur(k)
	P._cur_leg = 0.58
	P._cur_long = false


# ------------------------------------------------------------------ yardımcılar
## Yüzeye oturan baklava (eşkenar dörtgen) yama: mp yerel eşleme, out dış yön
static func _dia(k, mp: Callable, out: Vector3, cx: float, cy: float, hw: float, hh: float, lift: float, col: Color, skinf: Callable) -> void:
	var rows := []
	for j in 9:
		var v := float(j) / 8.0 * 2.0 - 1.0
		var w: float = (1.0 - absf(v)) * hw + 0.0004
		var ro := []
		for i in 5:
			var u := float(i) / 4.0 * 2.0 - 1.0
			var e: float = 1.0 - maxf(absf(u), absf(v))
			ro.append(mp.call(cx + u * w, cy - v * hh, lift - 0.0018 + 0.0018 * smoothstep(0.0, 0.25, e)))
		rows.append(ro)
	Q._mesh(k, rows, false, func(i, j, _p): return col.darkened(0.12) if i == 0 or i == 4 or j == 0 or j == 8 else col, func(_i, _j, p): return skinf.call(p), out)


## Uzuv boyunca (s, a) yolunda kabartma çizgi; her nokta kendi yerinin ağırlığını alır (dizden geçen çizgi kopmaz)
static func _lline(k, l: Dictionary, pts2: Array, liftf: Callable, hw: float, d: float, col: Color) -> void:
	var pts := []
	var ou := []
	for q: Vector2 in pts2:
		var e: Array = Q._ls(l, q.x, q.y, float(liftf.call(q.x, q.y)))
		pts.append(e[0])
		ou.append(e[1])
	k.strip(pts, ou, hw, d, col, false, func(p): return R._lsk(l, p))


# ------------------------------------------------------------------ Gösterişli Striker ailesi
## Dik yakalı uzun ceket. o: body, yoke, sleeve, lin (astar), zip, pant, seam (omuz V dikişi rengi). Döner: {keys, ff, hemf, zend, side, back, skin, b}
## Swanky ceket ağırlığı: ön ve yan uyluğu izler; arkada iki bacak arası geniş geçiş ve kalçada pay (sivri arka uç bacak arasına
## sıkışıp torba / kuyruk olmaz, iki bacağın arkasında düz dökülür; diz altında baldırı az izler)
static func _swsk(k, p: Vector3, hem: float) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var th: float = atan2(p.x, p.z)
	var bk: float = smoothstep(0.1, -0.7, cos(th))
	var d: float = H - p.y
	var t: float = clampf(d / maxf(0.05, H - hem), 0.0, 1.0)
	var wf: float = 0.97 * pow(minf(1.0, d / 0.11), 0.5)
	var wb: float = lerpf(0.72 * smoothstep(0.0, 1.0, minf(1.0, t / 0.85)), 0.8, smoothstep(0.6, 0.95, t)) * lerpf(1.0, 0.5, 1.0 - smoothstep(0.04, 0.17, absf(p.x)))   # arka orta kalçayla gider: öndeki ve arkadaki bacağın ortalaması onu bacak arasına çekmez
	var w: float = lerpf(wf, wb, bk)
	var hw: float = lerpf(0.035, 0.22, bk)
	var s: float = smoothstep(-hw, hw, p.x)
	var kb: float = smoothstep(k.K + 0.04, k.K - 0.14, p.y) * 0.4 * bk * absf(2.0 * s - 1.0)
	if kb > 0.0:
		var sd: String = "Left" if s >= 0.5 else "Right"
		var os: String = "Right" if s >= 0.5 else "Left"
		var ws: float = maxf(s, 1.0 - s)
		return [["Hips", 1.0 - w], [sd + "UpperLeg", w * ws * (1.0 - kb)], [sd + "LowerLeg", w * ws * kb], [os + "UpperLeg", w * (1.0 - ws)]]
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


static func _swanky(k, o: Dictionary) -> Dictionary:
	var bc: Color = o["body"]
	var yc: Color = o["yoke"]
	var sc: Color = o["sleeve"]
	var lc: Color = o["lin"]
	var zc: Color = o["zip"]
	var pc: Color = o["pant"]
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
	var zend: float = H - 0.075
	var side: float = KN + 0.11
	var back: float = KN - 0.17
	var fam := func(p): return _swsk(k, p, back)
	# pantolon: dar, çizmeye girer
	K._seat(k, b, pc.darkened(0.04))
	var legs := []
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var pa: Callable = K._pant(k, le, pc, 0.007, 0.007, 1.0, 0.8 if sd == "Left" else 2.1)
		legs.append([le, pa])
	# ceket gövdesi: önde fermuar ucu, yanlara verev etek, arkada baldıra sivri uç
	var ck := [P._kp(nk, N + 0.01, 0.024), [N - 0.055, ch.x * 1.03, ch.y * 0.96, ch.z * 1.04], P._kp(ch, C - 0.03, 0.026), P._kp(wa, H + 0.12, 0.024), P._kp(k.M(H + 0.03, 0.3), H + 0.03, 0.03),
		[H - 0.06, hp.x + 0.036, hp.y + 0.034, hp.z - 0.036], [KN + 0.1, hp.x + 0.058, hp.y + 0.05, hp.z - 0.07], [back - 0.01, hp.x + 0.064, hp.y + 0.05, hp.z - 0.085]]
	var hemf := func(a: float) -> float:
		var s: float = absf(sin(a))
		if absf(a) <= PI * 0.5:
			return lerpf(zend, side, s)
		return lerpf(back, side, pow(s, 1.15))
	var ff := func(a: float, y: float) -> float:
		var t: float = clampf((H - y) / (H - back), 0.0, 1.0)
		var bkf: float = 1.0 - 0.5 * smoothstep(2.2, 2.9, absf(a))
		return 0.004 * sin(a * 6.0 + y * 14.0) * smoothstep(C, H + 0.05, y) + t * (0.02 * sin(a * 5.0 + 0.7) + 0.008 * sin(a * 11.0 + 1.9)) * smoothstep(0.1, 0.35, absf(a)) * bkf
	var cg: Dictionary = P._cl(k, {"keys": ck, "ny": 60, "na": 104, "top": func(_a): return N + 0.01, "hem": func(a): return hemf.call(float(a)), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return bc, "gain": 6.0, "th": 0.007, "inner": lc, "skin": fam})
	P._bd(k, AA._yl(cg["hem"], 0.007), 0.0055, 0.002, bc.darkened(0.12), true, fam)
	# omuz boyunduruğu: V dikişle biten ayrı kat
	var yv := func(a: float) -> float:
		var s: float = absf(sin(a))
		if absf(a) <= PI * 0.5:
			return lerpf(C - 0.05, C + 0.045, pow(s, 0.85))
		return lerpf(C + 0.0, C + 0.045, s)
	var yg: Dictionary = P._cl(k, {"keys": ck, "ny": 14, "na": 104, "top": func(_a): return N + 0.008, "hem": func(a): return yv.call(float(a)), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return yc, "gain": 6.0, "th": 0.003, "lift": 0.0035, "inner": yc.darkened(0.3), "skin": tsk})
	P._cord(k, yg["hem"], 0.0024, o.get("seam", yc.darkened(0.2)), true, tsk)
	# yan dikişler
	var ffv := func(a, y): return ff.call(float(a), float(y))
	for sg in [1.0, -1.0]:
		Q._run(k, ck, ffv, [Vector2(sg * 1.62, C - 0.06), Vector2(sg * 1.62, H - 0.05), Vector2(sg * 1.6, float(hemf.call(sg * 1.6)) + 0.012)], 0.0014, 0.0012, 0.001, bc.darkened(0.25), fam, 10)
	# fermuar: bant + diş
	Q._run(k, ck, ffv, [Vector2(0.0, N + 0.005), Vector2(0.0, zend + 0.004)], 0.0042, 0.0025, 0.0016, bc.darkened(0.15), fam, 24)
	Q._run(k, ck, ffv, [Vector2(0.0, N + 0.005), Vector2(0.0, zend + 0.004)], 0.0016, 0.0045, 0.0012, zc, fam, 24)
	var zb: Array = Q._spt(ck, ffv, 0.0, zend + 0.006, 0.006)
	P._boxr(k, zb[0], Vector3(0.0045, 0, 0), Vector3(0, 0.005, 0), (zb[1] as Vector3) * 0.002, zc.darkened(0.15), [["Hips", 1.0]], 0.3)
	# dik yaka: önde fermuar ağzı, kenarlarda fermuar dişi, tepede çekecek
	var ng: Dictionary = X._neck(k, b, yc, 0.072, true)
	for e in [ng["ea"], ng["eb"]]:
		P._cord(k, e, 0.0022, zc, false, nsk)
	var zt: Array = Q._spt(ck, ffv, 0.0, N - 0.01, 0.007)
	P._boxr(k, zt[0], Vector3(0.0055, 0, 0), Vector3(0, 0.012, 0), (zt[1] as Vector3) * 0.0028, zc, [["Neck", 0.4], ["UpperChest", 0.6]], 0.3)
	# kollar: dar, bileğe iner
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sv: float = 0.7 if sd == "Left" else 2.2
		var en: float = ar["kn"]
		var slf := func(s: float, a: float) -> float:   # omuz başında incelir: kol kökü ceketin omzundan sivri çıkmaz
			var e := exp(-pow((s - en) / 0.085, 2.0))
			return 0.011 + 0.0065 * e * sin(a * 3.0 + s * 31.0 + sv) + 0.003 * P._lf(s, a, sv) * sin(clampf(s, 0.0, 1.0) * PI) - P._lr(ar, s) * 0.4 * (1.0 - smoothstep(0.0, 0.16, s))
		P._lt(k, ar, slf, func(s, a, ins): return sc.darkened(0.42) if ins else P._fs(sc, float(slf.call(s, a)) - 0.011, 30.0), 0.0, 0.9, 32, 18, 0.03)
	return {"keys": ck, "ff": ffv, "hemf": hemf, "zend": zend, "side": side, "back": back, "skin": fam, "b": b, "legs": legs}


## Diz altına çıkan çizme konçu: pantolon içine girer, üstte kalın ağız, konçta kırışıklar. Döner: konç yarıçap işlevi
static func _boot(k, le: Dictionary, pa: Callable, col: Color, s0: float, sv: float) -> Callable:
	var bf := func(s: float, a: float) -> float:
		var base: float = float(pa.call(s, a))
		return base + 0.006 + 0.004 * smoothstep(s0 + 0.03, s0, s) + 0.0022 * sin(a * 3.0 + s * 46.0 + sv) * smoothstep(0.97, 0.85, s) * smoothstep(s0, s0 + 0.05, s)
	P._lt(k, le, bf, func(s, a, ins):
		if ins:
			return col.darkened(0.35)
		return col.darkened(0.12 * maxf(0.0, -sin(float(a) * 3.0 + float(s) * 46.0 + sv)) * smoothstep(s0, s0 + 0.05, float(s))).lightened(0.05 * float(float(s) < s0 + 0.02)), s0, 0.995, 22, 20, 0.02)
	return bf


## Konçu saran kayış / bant halkaları
static func _straps(k, le: Dictionary, bf: Callable, ss: Array, w: float, col: Color, bulge := 0.003) -> void:
	for s in ss:
		Q._ring_on(k, le, float(s), func(s2, a2): return float(bf.call(float(s2), float(a2))) + 0.001, w, col, bulge)


## Etek ucu boyunca yukarı yalazlanan kabartma şerit (Hava: sarı çimen / alev işi). sg: +1 sol kanat, -1 sağ
static func _blaze(k, g: Dictionary, sg: float, w: float, lift: float, col: Color, ph: float) -> void:
	var keys: Array = g["keys"]
	var ff: Callable = g["ff"]
	var hemf: Callable = g["hemf"]
	var skf: Callable = g["skin"]
	var n := 46
	var rows := []
	for j in 5:
		var v := float(j) / 4.0
		var ro := []
		for i in n + 1:
			var u := float(i) / n
			var a: float = sg * lerpf(0.035, PI * 0.5 - 0.04, u)
			var fl: float = w * (0.42 + 0.4 * pow(Y._teeth(a, 31.0, ph), 2.2) + 0.28 * pow(Y._teeth(a, 13.0, ph * 1.7), 3.0)) * (0.55 + 0.45 * smoothstep(0.0, 0.08, u))
			var y: float = float(hemf.call(a)) + 0.006 + fl * v
			var nar: float = lerpf(1.0, 0.25, v * v)   # uçlar incelir (yalaz)
			var ac: float = a + (0.0 if v < 0.5 else 0.012 * sin(a * 40.0 + ph) * v)
			ro.append(Q._spt(keys, ff, ac, y, lift + 0.0012 * sin(v * PI) * nar)[0])
		rows.append(ro)
	var out := Vector3(sg * 0.6, 0.0, 1.0).normalized()
	Q._mesh(k, rows, false, func(_i, j, _p): return col.darkened(0.1) if j == 0 else (col.lightened(0.12) if j >= 3 else col), func(_i, _j, p): return skf.call(p), out)


static func _gosterisli(k) -> void:
	var bk := Color(0.078, 0.078, 0.094)
	var lil := Color(0.635, 0.659, 0.902)
	var nv := Color(0.118, 0.165, 0.353)
	var g: Dictionary = _swanky(k, {"body": bk, "yoke": bk, "sleeve": bk, "lin": lil, "zip": Color(0.62, 0.6, 0.52), "pant": bk, "seam": Color(0.2, 0.2, 0.23)})
	# kayışlı lacivert çizme
	for e in g["legs"]:
		var le: Dictionary = e[0]
		var kn: float = le["kn"]
		var bf: Callable = _boot(k, le, e[1], Color(0.086, 0.102, 0.165), kn + 0.12, float(le["sg"]))
		_straps(k, le, bf, [kn + 0.2, kn + 0.32, kn + 0.44, kn + 0.56], 0.009, Color(0.141, 0.157, 0.227), 0.0035)
		for s in [kn + 0.2, kn + 0.32, kn + 0.44, kn + 0.56]:
			var bp: Array = Q._ls(le, s, PI * 0.5 * float(le["sg"]), float(bf.call(s, PI * 0.5 * float(le["sg"]))) + 0.004)
			P._boxr(k, bp[0], Vector3(0, 0, 0.007), Vector3(0, 0.008, 0), (bp[1] as Vector3) * 0.002, Color(0.5, 0.5, 0.54), P._lskin(le, s), 0.3)
	# lacivert parmaksız eldiven, bilekte çıtçıt
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		K._glove(k, sd, ar, nv, nv.darkened(0.15))
		var sp: Array = Q._ls(ar, 0.86, (PI * 0.5) * float(ar["sg"]), 0.017)
		P._stud(k, sp[0], sp[1], 0.0045, Color(0.55, 0.55, 0.58), P._lskin(ar, 0.86))


static func _hava(k) -> void:
	var wh := Color(0.949, 0.941, 0.925)
	var br := Color(0.478, 0.384, 0.322)
	var gd := Color(0.9, 0.72, 0.2)
	var mv := Color(0.46, 0.4, 0.46)
	var gl := Color(0.541, 0.353, 0.165)
	var g: Dictionary = _swanky(k, {"body": wh, "yoke": br, "sleeve": br, "lin": mv, "zip": gd, "pant": Color(0.949, 0.949, 0.941), "seam": br.darkened(0.3)})
	# kahve çizme, beyaz sargı halkaları
	for e in g["legs"]:
		var le: Dictionary = e[0]
		var kn: float = le["kn"]
		var bf: Callable = _boot(k, le, e[1], Color(0.627, 0.416, 0.227), kn + 0.12, float(le["sg"]))
		_straps(k, le, bf, [kn + 0.155, kn + 0.19, kn + 0.42, kn + 0.455], 0.014, wh, 0.006)
	# sarı yalaz işi: önde açılım kenarı boyunca iki kat
	for sg in [1.0, -1.0]:
		_blaze(k, g, sg, 0.085, 0.0035, gd, 0.3 + sg)
		_blaze(k, g, sg, 0.045, 0.0052, gd.lightened(0.22), 1.3 + sg)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		# beyaz manşet + kahve parmaksız eldiven
		P._lt(k, ar, func(s, a): return 0.0175 + 0.0012 * sin(float(a) * 4.0 + float(s) * 9.0) + 0.0025 * sin(clampf((float(s) - 0.82) / 0.06, 0.0, 1.0) * PI), func(_s, _a, ins): return wh.darkened(0.3) if ins else wh, 0.82, 0.88, 5, 20)
		K._glove(k, sd, ar, gl, gl.darkened(0.12))


static func _bahar(k) -> void:
	var gn := Color(0.204, 0.627, 0.478)
	var wh := Color(0.925, 0.94, 0.93)
	var yl := Color(0.91, 0.847, 0.22)
	var pg := Color(0.62, 0.86, 0.76)
	var g: Dictionary = _swanky(k, {"body": gn, "yoke": wh, "sleeve": wh, "lin": yl, "zip": Color(0.95, 0.9, 0.55), "pant": Color(0.949, 0.949, 0.941), "seam": wh.darkened(0.25)})
	# yeşil çizme: beyaz + sarı halkalar, konçta dalga işi
	for e in g["legs"]:
		var le: Dictionary = e[0]
		var kn: float = le["kn"]
		var bf: Callable = _boot(k, le, e[1], gn.darkened(0.25), kn + 0.12, float(le["sg"]))
		_straps(k, le, bf, [kn + 0.15, kn + 0.42], 0.012, wh, 0.005)
		_straps(k, le, bf, [kn + 0.18, kn + 0.45], 0.009, yl, 0.004)
		var wp := []
		for i in 37:
			var a := TAU * i / 36.0 - PI
			wp.append(Vector2(kn + 0.3 + 0.012 * sin(a * 5.0), a))
		_lline(k, le, wp, func(s2, a2): return float(bf.call(float(s2), float(a2))) + 0.0008, 0.0018, 0.0014, Color(0.62, 0.86, 0.76))
	var ck: Array = g["keys"]
	var ff: Callable = g["ff"]
	var hemf: Callable = g["hemf"]
	var fam: Callable = g["skin"]
	var H: float = k.H
	var C: float = k.C
	var N: float = k.N
	var tsk := func(p): return k.torso_skin(p.y)
	# sarı bel bandı + altında açık yeşil şerit
	for e in [[H + 0.205, H + 0.145, yl, 0.0042], [H + 0.143, H + 0.12, pg, 0.0032]]:
		var bg: Dictionary = P._cl(k, {"keys": ck, "ny": 4, "na": 96, "top": func(_a): return float(e[0]), "hem": func(_a): return float(e[1]), "fold": func(a, y, _v): return ff.call(float(a), float(y)),
			"col": func(_a, _y, _v): return e[2], "gain": 4.0, "th": 0.002, "lift": float(e[3]), "inner": (e[2] as Color).darkened(0.3), "skin": tsk})
		P._cord(k, bg["top"], 0.0018, (e[2] as Color).darkened(0.1), true, tsk)
	# etek ucuna yakın toplar (açık yeşil + sarı) ve aralarında kıvrık dal işi
	var balls := [[0.42, 0.105, 0.042, pg], [0.95, 0.075, 0.036, yl], [1.42, 0.07, 0.04, pg], [2.05, 0.09, 0.038, yl], [2.65, 0.1, 0.042, pg]]
	for sg in [1.0, -1.0]:
		var prev := Vector2.ZERO
		for i in balls.size():
			var e: Array = balls[i]
			var a: float = sg * float(e[0])
			var y: float = float(hemf.call(a)) + float(e[1])
			var mp: Callable = Q._local(ck, ff, a, y)
			var o2: Vector3 = (Q._spt(ck, ff, a, y)[1] as Vector3)
			var col: Color = e[3]
			Q._disc(k, mp, o2, float(e[2]), 0.0035, Callable(), func(u, v):
				var r := Vector2(float(u), float(v)).length()
				return col.darkened(0.14) if r > 0.86 else col.lightened(0.08 * float(Vector2(float(u) + 0.35, float(v) - 0.35).length() < 0.3)), fam, 4, 28)
			if i > 0:
				var path := []
				for t in 7:
					var tt := float(t) / 6.0
					path.append(Vector2(lerpf(prev.x, a, tt), lerpf(prev.y, y, tt) - 0.03 - 0.012 * sin(tt * PI * 3.0)))
				Q._run(k, ck, ff, path, 0.0018, 0.0035, 0.0014, pg.lightened(0.15), fam, 3)
			prev = Vector2(a, y)
	# sol göğüste arma: açık daire + sarı fiyonk
	var ea: float = 0.48
	var ey: float = C - 0.03
	var emp: Callable = Q._local(ck, ff, ea, ey)
	var eo: Vector3 = (Q._spt(ck, ff, ea, ey)[1] as Vector3)
	Q._disc(k, emp, eo, 0.018, 0.004, Callable(), func(u, v): return wh.darkened(0.08) if Vector2(float(u), float(v)).length() > 0.82 else wh, tsk, 3, 22)
	for sg in [1.0, -1.0]:
		R._lstrip(k, emp, [Vector2(0.0, -0.018), Vector2(sg * 0.012, -0.026), Vector2(sg * 0.014, -0.034)], 0.0035, 0.0045, 0.0018, yl, tsk)
	# yaka tepesinde dalgalı açık şerit
	var q: float = Q._hq(k)
	var nk: Vector3 = (g["b"] as Dictionary)["nk"]
	var wv := []
	for i in 60:
		var a := TAU * i / 60.0 - PI
		if absf(a) < 0.1:
			continue
		var p2: Vector2 = SE.El.sup(a, nk.x + 0.02, nk.y + 0.02, nk.z - 0.02)
		wv.append(Vector3(p2.x, N + 0.072 * q - 0.012 - 0.004 * sin(a * 9.0), p2.y))
	P._cord(k, wv, 0.0022, pg, false, func(p): return Q._nsk(k, p))
	# kollar: manşet bandı + dalga işi, beyaz eldiven
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		P._lt(k, ar, func(s, a): return 0.0135 + 0.001 * sin(float(a) * 5.0), func(_s, _a, ins): return wh.darkened(0.3) if ins else wh.darkened(0.04), 0.86, 0.9, 4, 18)
		var pts := []
		for i in 37:
			var a := TAU * i / 36.0 - PI
			pts.append(Vector2(0.815 + 0.008 * sin(a * 5.0), a))
		_lline(k, ar, pts, func(_s, _a): return 0.0125, 0.0018, 0.0016, pg)
		Z._long_glove(k, ar, 0.88, wh, 0.6 if sd == "Left" else 2.0)


# ------------------------------------------------------------------ Tatlı Striker ailesi
## Kolsuz yüksek yakalı iç üst + omzu açık kısa kazak, çan kol, dar kısa paça pantolon.
## o: inner, rib (iç üst örgü kaburgası), sw (kazak), sw_lin (kol içi), pant, flap (yaka bindirmesi), cuff (manşet bandı rengi, yoksa yok)
## Döner: {keys (kazak), ff, skin, top, hem, b}
static func _sweet(k, o: Dictionary) -> Dictionary:
	var ic: Color = o["inner"]
	var sw: Color = o["sw"]
	var sl: Color = o["sw_lin"]
	var pc: Color = o["pant"]
	var rib: float = o.get("rib", 0.0)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var skc: Color = Q._skc(k)
	var tsk := func(p): return k.torso_skin(p.y)
	var nsk := func(p): return Q._nsk(k, p)
	Z._skin_torso(k, b, C - 0.05)
	# pantolon: yüksek bel, bilek üstünde biter
	K._seat(k, b, pc.darkened(0.05))
	var pas := {}
	for sd in ["Left", "Right"]:
		var le: Dictionary = P._limb(k, sd, true)
		var pa: Callable = K._pant(k, le, pc, 0.011, 0.01, 0.9, 0.9 if sd == "Left" else 2.3)
		P._bare(k, le, skc, 0.86, 1.0)
		pas[sd] = [le, pa]
	# iç üst: boyna çıkan ön panel, omuzlar açık, kazağın altından bele iner
	var ihem: float = H + 0.05
	var ikeys := []
	for kk in Z._tk(k, b, ihem - 0.005, 0.006, 0.3):   # bel altı kendi ölçüsünden: pantolonun beli hep içte kalır
		if float(kk[0]) > C - 0.1:
			ikeys.append(kk)
	ikeys.append(P._kp(k.M(C - 0.12, k.UA), C - 0.12, 0.012))
	ikeys.append(P._kp(wa, H + 0.12, 0.016))
	for e3 in [[H + 0.08, 0.02, 0.028], [ihem - 0.005, 0.022, 0.036]]:
		var m3: Vector3 = k.M(float(e3[0]), 0.3)
		ikeys.append([float(e3[0]), m3.x + float(e3[1]), m3.y + float(e3[1]), m3.z - float(e3[2])])
	var itop := func(a: float) -> float:
		var u: float = absf(a)
		var sd2: float = smoothstep(0.36, 0.52, u) * (1.0 - smoothstep(PI - 0.52, PI - 0.36, u))
		return lerpf(N + 0.004, C - 0.02, sd2)
	var iff := func(a: float, y: float) -> float:
		return rib * (0.5 + 0.5 * cos(a * 64.0)) + 0.0025 * sin(a * 11.0 + y * 20.0) + 0.006 * sin(a * 6.0 + 0.4) * smoothstep(C - 0.02, ihem, y)
	var ig: Dictionary = P._cl(k, {"keys": ikeys, "ny": 28, "na": 128 if rib > 0.0 else 96, "top": func(a): return itop.call(float(a)), "hem": func(_a): return ihem, "fold": func(a, y, _v): return iff.call(float(a), float(y)),
		"col": func(a, _y, _v): return ic.darkened(0.1 * (0.5 - 0.5 * cos(float(a) * 64.0))) if rib > 0.0 else ic, "gain": 3.0, "th": 0.005, "inner": ic.darkened(0.3), "skin": nsk})
	P._cord(k, ig["top"], 0.0026, ic.darkened(0.08), true, nsk)
	P._cord(k, ig["hem"], 0.003, ic.darkened(0.06), true, tsk)
	# yüksek yaka + yan bindirme
	var q: float = Q._hq(k)
	var nh: float = 0.05
	var nck := [P._kp(nk, N + nh * q, 0.006, 0.009), P._kp(nk, N + nh * 0.4 * q, 0.01), P._kp(nk, N - 0.02, 0.018)]
	var nff := func(a: float, y: float) -> float: return rib * 1.4 * (0.5 + 0.5 * cos(a * 40.0)) + 0.004 * sin(a * 5.0 + y * 40.0)
	var cg: Dictionary = P._cl(k, {"keys": nck, "ny": 8, "na": 80 if rib > 0.0 else 56, "top": func(_a): return N + nh * q, "hem": func(_a): return N - 0.014, "fold": func(a, y, _v): return nff.call(float(a), float(y)),
		"col": func(a, _y, _v): return ic.darkened(0.1 * (0.5 - 0.5 * cos(float(a) * 40.0))) if rib > 0.0 else ic, "gain": 3.0, "th": 0.005, "inner": ic.darkened(0.3), "skin": nsk})
	P._cord(k, cg["top"], 0.003, ic.lightened(0.04), true, nsk)
	var flc: Color = o.get("flap", ic.darkened(0.25))
	var nfv := func(a, y): return nff.call(float(a), float(y)) * 0.0
	for w2 in [[0.011, 0.0035, flc], [0.004, 0.0052, flc.darkened(0.15)]]:
		Q._run(k, nck, nfv, [Vector2(0.62, N + nh * q - 0.004), Vector2(0.78, N + nh * 0.5 * q), Vector2(0.92, N - 0.004)], float(w2[0]), float(w2[1]), 0.0018, w2[2], nsk, 4)
	# kazak gövdesi: göğüs üstünde düz yaka (omuzlar açık), bele yakın biter
	var yt: float = C + 0.04
	var hem: float = H + 0.12
	var tm: Vector3 = k.M(yt, k.UA)
	var sk := [P._kp(tm, yt + 0.01, 0.018), P._kp(ch, C - 0.03, 0.026), P._kp(k.M(C - 0.12, k.UA), C - 0.12, 0.028), P._kp(wa, hem - 0.01, 0.03)]
	var stop := func(a: float) -> float:
		var u: float = absf(a)
		return yt - 0.035 * smoothstep(0.9, 1.5, u) * (1.0 - smoothstep(1.65, 2.25, u))
	var sff := func(a: float, y: float) -> float:
		return 0.006 * sin(a * 7.0 + y * 9.0) * smoothstep(C, hem, y) + 0.003 * sin(a * 13.0 - y * 17.0) + 0.012 * exp(-pow((y - hem - 0.012) / 0.025, 2.0)) * (0.6 + 0.4 * sin(a * 9.0))
	var sg0: Dictionary = P._cl(k, {"keys": sk, "ny": 26, "na": 104, "top": func(a): return stop.call(float(a)), "hem": func(_a): return hem, "fold": func(a, y, _v): return sff.call(float(a), float(y)),
		"col": func(_a, _y, _v): return sw, "gain": 6.0, "th": 0.008, "inner": sw.darkened(0.3), "skin": tsk})
	# kıvrık yaka bandı + kalın etek ucu
	P._cord(k, sg0["top"], 0.0075, sw.lightened(0.03), true, tsk)
	P._cord(k, AA._yl(sg0["hem"], 0.004), 0.0055, sw.darkened(0.05), true, tsk)
	# çan kollar: omuz başının altından başlar, bilekte geniş açılır; içte açık kol (ağız boşluk göstermez)
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sgn: float = ar["sg"]
		var sv: float = 1.1 if sd == "Left" else 2.4
		Z._arm_bare(k, ar)
		var s0f := func(a: float) -> float: return lerpf(0.03, 0.115, smoothstep(-0.4, 1.0, sin(a) * sgn))
		var s1 := 0.92
		var bell := func(s: float, a: float) -> float:
			var t: float = smoothstep(0.42, s1, s)
			var dn: float = 0.5 + 0.5 * cos(a - PI)   # alt yan daha bol
			return 0.015 + 0.006 * smoothstep(0.1, 0.3, s) + t * t * (0.036 + 0.014 * dn) + 0.004 * P._lf(s, a, sv) * smoothstep(0.1, 0.3, s) + 0.007 * t * sin(a * 5.0 + sv)
		P._lts(k, ar, bell, func(s, a, ins):
			if ins:
				return sl
			return P._fs(sw, 0.007 * float(smoothstep(0.42, s1, float(s))) * sin(float(a) * 5.0 + sv), 18.0), s0f, s1, 30, 26)
		K._lt_in(k, ar, func(s, a): return float(bell.call(float(s), float(a))) - 0.005, sl, 0.62, s1 - 0.003, 8, 26)
		# ağız: kalın dönük kenar
		var cp := []
		for i in 26:
			var a := TAU * i / 26.0 - PI
			cp.append(Q._ls(ar, s1 - 0.004, a, float(bell.call(s1 - 0.004, a)) - 0.001)[0])
		P._cord(k, cp, 0.0042, sw.darkened(0.06), true, func(_p): return P._lskin(ar, s1))
		# omuz kıvrığı: kol ağzının üst kenarı
		var tp := []
		for i in 30:
			var a := TAU * i / 30.0 - PI
			var s: float = s0f.call(a)
			tp.append(Q._ls(ar, s + 0.004, a, float(bell.call(s, a)) + 0.002)[0])
		P._cord(k, tp, 0.0068, sw.lightened(0.03), true, func(p): return R._lsk(ar, p))
		if o.has("cuff"):
			var cc: Color = o["cuff"]
			P._lt(k, ar, func(s, a): return float(bell.call(float(s), float(a))) + 0.0025, func(_s, _a, ins): return sl if ins else cc, s1 - 0.075, s1 - 0.002, 5, 26)
	var sffv := func(a, y): return sff.call(float(a), float(y))
	return {"keys": sk, "ff": sffv, "skin": tsk, "top": yt, "hem": hem, "b": b, "pants": pas}


static func _tatli(k) -> void:
	var lav := Color(0.659, 0.596, 0.847)
	var cr := Color(0.949, 0.933, 0.902)
	_sweet(k, {"inner": lav, "sw": cr, "sw_lin": Color(0.93, 0.8, 0.82), "pant": Color(0.118, 0.165, 0.478), "flap": Color(0.4, 0.3, 0.62), "cuff": cr.darkened(0.03)})


static func _baklava(k) -> void:
	var cr := Color(0.933, 0.91, 0.847)
	var rd := Color(0.69, 0.118, 0.118)
	var pk := Color(0.86, 0.5, 0.46)
	var g: Dictionary = _sweet(k, {"inner": cr, "rib": 0.006, "sw": rd, "sw_lin": rd.darkened(0.25), "pant": Color(0.541, 0.353, 0.22), "flap": Color(0.62, 0.58, 0.56)})
	var sk: Array = g["keys"]
	var ff: Callable = g["ff"]
	var tsk: Callable = g["skin"]
	var C: float = k.C
	var H: float = k.H
	# baklava paneli: iki yanda beyaz baklavalar (çapraz çizgili), ortada pembe küçük baklava kümeleri
	var y0: float = C - 0.005
	var hh: float = 0.044
	var mp: Callable = Q._local(sk, ff, 0.0, y0)
	var out := Vector3(0, 0, 1)
	var dk := Color(0.36, 0.33, 0.33)
	for r in 3:
		var cy: float = -float(r) * hh * 2.0
		for sx in [-1.0, 1.0]:
			var cx: float = sx * 0.068
			_dia(k, mp, out, cx, cy, 0.033, hh, 0.0042, cr, tsk)
			for d in [1.0, -1.0]:
				R._lstrip(k, mp, [Vector2(cx - 0.022 * d, cy + hh * 0.42), Vector2(cx + 0.022 * d, cy - hh * 0.42)], 0.0012, 0.0062, 0.0008, dk, tsk)
			R._lstrip(k, mp, [Vector2(cx, cy + hh * 0.8), Vector2(cx, cy - hh * 0.8)], 0.0011, 0.0062, 0.0008, dk, tsk)
		for e in [[0.0, 0.5], [0.0, -0.5], [0.5, 0.0], [-0.5, 0.0]]:
			_dia(k, mp, out, float(e[0]) * 0.026, cy + float(e[1]) * hh, 0.0125, hh * 0.48, 0.0038, pk.darkened(0.08 * float(e[0] == 0.0)), tsk)
	# arkada aynı baklava sırası (tek sütun)
	var bmp: Callable = Q._local(sk, ff, PI, y0)
	for r in 3:
		_dia(k, bmp, Vector3(0, 0, -1), 0.0, -float(r) * hh * 2.0, 0.03, hh, 0.0042, cr, tsk)


static func _kultur(k) -> void:
	var ow := Color(0.933, 0.918, 0.894)
	var nv := Color(0.118, 0.165, 0.478)
	var nl := Color(0.2, 0.26, 0.58)
	var nd := Color(0.15, 0.2, 0.52)
	var g: Dictionary = _sweet(k, {"inner": ow, "sw": nv, "sw_lin": nv.darkened(0.2), "pant": nv.darkened(0.04), "flap": ow.darkened(0.2)})
	var sk: Array = g["keys"]
	var ff: Callable = g["ff"]
	var tsk: Callable = g["skin"]
	var C: float = k.C
	# örgü bantları: göğüste iki sıra çizgi, aralarında küçük baklava dizisi
	for e in [[C - 0.03, 0.0], [C - 0.075, 0.12]]:
		var y: float = e[0]
		for dy in [0.012, -0.012]:
			var pts := []
			for i in 73:
				pts.append(Vector2(TAU * i / 72.0 - PI, y + dy))
			Q._run(k, sk, ff, pts, 0.0022, 0.0038, 0.0014, nl, tsk, 1)
		for i in 22:
			var a := TAU * (i + float(e[1])) / 22.0 - PI
			var mp: Callable = Q._local(sk, ff, a, y)
			_dia(k, mp, (Q._spt(sk, ff, a, y)[1] as Vector3), 0.0, 0.0, 0.0085, 0.0075, 0.0038, nl, tsk)
	# kollarda aynı bant
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var sgn: float = ar["sg"]
		for s in [0.34, 0.4]:
			var pts := []
			for i in 33:
				var a := TAU * i / 32.0 - PI
				pts.append(Vector2(s, a))
			_lline(k, ar, pts, func(s2, a2): return 0.015 + 0.006 * smoothstep(0.1, 0.3, float(s2)) + 0.0025 + 0.007 * smoothstep(0.42, 0.92, float(s2)) * sin(float(a2) * 5.0 + (1.1 if sd == "Left" else 2.4)) * 0.0, 0.002, 0.0014, nl)
	# ekose pantolon: açık lacivert dikey ve yatay kabartma iplikler
	var pas: Dictionary = g["pants"]
	for sd in ["Left", "Right"]:
		var e: Array = pas[sd]
		var le: Dictionary = e[0]
		var pa: Callable = e[1]
		for a0 in [0.0, PI * 0.5, PI, -PI * 0.5, 0.25 * PI, -0.75 * PI]:
			var pts := []
			for j in 25:
				pts.append(Vector2(lerpf(0.06, 0.87, float(j) / 24.0), a0))
			_lline(k, le, pts, func(s2, a2): return float(pa.call(float(s2), float(a2))) + 0.0012, 0.0014 if absf(fmod(a0, PI * 0.5)) < 0.01 else 0.0009, 0.0009, nd)
		for s in [0.14, 0.26, 0.38, 0.5, 0.62, 0.74, 0.84]:
			Q._ring_on(k, le, s, func(s2, a2): return float(pa.call(float(s2), float(a2))) + 0.0005, 0.0014, nd, 0.001)
