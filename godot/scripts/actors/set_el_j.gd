extends RefCounted
## Elle modellenmiş setler, parti j: köy üniformaları. Her köyün yeleği kendi kanon kesiminde:
## Konoha: yastıklı alt rulo, iki parçalı yaka, parşömen cepleri (ref Konoha_Flak_Jacket)
## Suna: kanat gibi açılan omuzluklar, geniş yaka, gri göğüs yamaları, ayrı alt kuşak (ref Suna_Flak_Jacket)
## Kiri: sert plakalı zırh, omuz kapakları, boyna çıkan dikmeler, önlük, çizgili kol/kaval koruyucu (ref Kiri_Flak_Jacket)
## Kumo: tek omuzlu beyaz göğüs zırhı, kalçaya sarılı bez, beyaz kaval koruyucu (ref Darui, Samui)
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")
const P = preload("res://scripts/actors/set_el_a.gd")

const DONE := ["set_jonin", "set_suna_chunin", "set_suna_jonin", "set_kiri_chunin", "set_kiri_jonin", "set_kumo_chunin"]


static func recipe(k, sid: String) -> void:
	P._cur_leg = 0.58
	match sid:
		"set_jonin": _konoha(k)
		"set_suna_chunin": _suna(k, Color(0.46, 0.37, 0.28), false)
		"set_suna_jonin": _suna(k, Color(0.38, 0.3, 0.22), true)
		"set_kiri_chunin": _kiri(k, Color(0.56, 0.53, 0.66), Color(0.6, 0.72, 0.9), false)
		"set_kiri_jonin": _kiri(k, Color(0.46, 0.43, 0.56), Color(0.52, 0.64, 0.84), true)
		"set_kumo_chunin": _kumo(k)


# ------------------------------------------------------------------ yüzey yardımcıları
## Etek ağırlığı: belden hemen sonra bacağa geçer (koşuda kalkan uyluk kumaşı delmez)
static func _cs(k, p: Vector3) -> Array:
	var H: float = k.H
	if p.y >= H:
		return k.torso_skin(p.y)
	var t: float = pow(clampf((H - p.y) / maxf(0.05, H - P._cur_hem), 0.0, 1.0), 0.55)
	var s := smoothstep(-0.075, 0.075, p.x)
	var w: float = t * P._cur_leg
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Satırları dışa bakacak şekilde çevirip ızgaraya yazar
static func _mesh(k, rows: Array, cols: Array, skins: Array, c0: Vector3, jc := -1) -> void:
	var j0: int = jc if jc >= 0 else rows.size() / 2
	var i0: int = (rows[0] as Array).size() / 2
	var a: Vector3 = rows[j0][i0]
	var fn: Vector3 = -((rows[j0][i0 + 1] as Vector3) - a).cross((rows[j0 + 1][i0 + 1] as Vector3) - a)
	if fn.dot(a - c0) < 0.0:
		for t in [rows, cols, skins]:
			for ro in t:
				ro.reverse()
	k.grid(rows, false, func(i, j, _p): return cols[j][i], func(i, j, _p): return skins[j][i])


static func _nrm(surf: Callable, u: float, v: float, c0: Vector3) -> Vector3:
	var e := 0.012
	var du: Vector3 = surf.call(minf(u + e, 1.0), v) - surf.call(maxf(u - e, 0.0), v)
	var dv: Vector3 = surf.call(u, minf(v + e, 1.0)) - surf.call(u, maxf(v - e, 0.0))
	var n := du.cross(dv)
	if n.length_squared() < 1e-14:
		return ((surf.call(u, v) as Vector3) - c0).normalized()
	n = n.normalized()
	return -n if n.dot((surf.call(u, v) as Vector3) - c0) < 0.0 else n


## Yüzeye oturan yastık parça: kenarı yüzeye iner. surf(u, v) -> nokta
static func _pil(k, surf: Callable, nu: int, nv: int, h: float, col: Color, c0: Vector3, bev := 0.14, skinf := Callable(), colf := Callable()) -> void:
	var rows := []
	var cols := []
	var skins := []
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return _cs(k, p)
	for j in nv + 1:
		var v := float(j) / nv
		var ro := []
		var cr := []
		var sr := []
		for i in nu + 1:
			var u := float(i) / nu
			var ed := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var p: Vector3 = surf.call(u, v)
			var q: Vector3 = p + _nrm(surf, u, v, c0) * (-0.003 + (h + 0.003) * smoothstep(0.0, bev, ed))
			ro.append(q)
			cr.append(colf.call(u, v, ed) if colf.is_valid() else (col.darkened(0.2) if ed < bev * 0.3 else col))
			sr.append(sf.call(q))
		rows.append(ro)
		cols.append(cr)
		skins.append(sr)
	_mesh(k, rows, cols, skins, c0)


## Kalınlığı olan serbest plaka: üst yüz + kenar + alt yüz (arkası da kapalı)
static func _slab(k, surf: Callable, nu: int, nv: int, th: float, bulge: float, col: Color, c0: Vector3, skinf: Callable, colf := Callable()) -> void:
	var rows := []
	var cols := []
	var skins := []
	var add = func(u_v: float, lift: float, under: bool) -> void:
		var ro := []
		var cr := []
		var sr := []
		for i in nu + 1:
			var u := float(i) / nu
			var p: Vector3 = surf.call(u, u_v)
			var q: Vector3 = p + _nrm(surf, u, u_v, c0) * lift
			ro.append(q)
			var cc: Color = colf.call(u, u_v) if colf.is_valid() else col
			var rim := minf(u_v, 1.0 - u_v) < 0.05
			cr.append(cc.darkened(0.45) if under else (cc.darkened(0.14) if rim else cc))
			sr.append(skinf.call(q))
		rows.append(ro)
		cols.append(cr)
		skins.append(sr)
	for j in nv + 1:
		var v := float(j) / nv
		add.call(v, bulge * sin(v * PI), false)
	add.call(1.0, -th * 0.5, false)
	for j in range(nv, -1, -1):
		add.call(float(j) / nv, -th, true)
	add.call(0.0, -th * 0.5, false)
	rows.append(rows[0].duplicate())
	cols.append(cols[0].duplicate())
	skins.append(skins[0].duplicate())
	_mesh(k, rows, cols, skins, c0, nv / 2)


## Üst ve alt kenarı açıya göre değişen sarılı yüzey (tek omuzlu zırh, eğik bez)
static func _wg(k, keys: Array, topf: Callable, botf: Callable, na: int, nv: int, foldf: Callable, colf: Callable, skinf: Callable) -> void:
	var rows := []
	for j in nv + 1:
		var v := float(j) / nv
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var y := lerpf(float(topf.call(a)), float(botf.call(a)), v)
			var s: Array = SE.El.key_at(keys, y)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f := 1.0 + float(foldf.call(a, y, v))
			ro.append(Vector3(q.x * f, y, q.y * f))
		rows.append(ro)
	k.grid(rows, true, func(i, j, p): return colf.call(TAU * i / na - PI, float(j) / nv, p), func(_i, _j, p): return skinf.call(p))


## Kenar biyesi: yuvarlak ince boru
static func _pipe(k, pts: Array, r: float, col: Color, skinf: Callable, closed := false) -> void:
	P._tb(k, pts, func(_s, _a): return r, func(_s, a, _p): return col.darkened(0.14) if cos(a) < -0.35 else col, func(_s, p): return skinf.call(p), 7, closed)


## Ön açık dik yaka: iki yanda yükselir, ağzı biyeli
static func _collar(k, ck: Array, op_top: float, op_bot: float, col: Color, pipe: Color, rr := 0.007) -> void:
	var y0: float = ck[0][0]
	var y1: float = ck[ck.size() - 1][0]
	var na := 44
	var ny := 12
	var o: Array = P._sheet(k, ck, ny, na, func(y: float) -> Vector2:
		var e := lerpf(op_bot, op_top, smoothstep(y1, y0, y))
		return Vector2(e, TAU - e), func(a: float, y: float, _u: float) -> float:
		return 0.012 * sin(a * 5.0 + y * 16.0), func(a, y, _u, v, _p):
		return P._fs(col.lightened(0.05) if v < 0.16 else col, 0.012 * sin(a * 5.0 + y * 16.0), 9.0), 0.007)
	var pts := []
	for j in range(ny, 0, -1):
		pts.append(o[j][0])
	for p in o[0]:
		pts.append(p)
	for j in range(1, ny + 1):
		pts.append(o[j][na])
	_pipe(k, pts, rr, pipe, func(p: Vector3) -> Array: return k.torso_skin(p.y))


## Omuz ağırlığı: gövdeden kola geçiş
static func _ssk(k, sd: String, x0: float, x1: float, w_max: float) -> Callable:
	return func(p: Vector3) -> Array:
		var w := smoothstep(x0, x1, absf(p.x)) * w_max
		return [["UpperChest", 1.0 - w], [sd + "UpperArm", w]]


static func _lsurf(l: Dictionary, s: float, a: float, lift: float) -> Array:
	var d: Vector3 = P._ld(l, s)
	var fw := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var ri := (-d).cross(fw).normalized()
	var o := ri * sin(a) + fw * cos(a)
	return [P._lp(l, s) + o * (P._lr(l, s) + lift), o]


## Uzvun dışa bakan açısı
static func _outer_a(l: Dictionary, s: float, dir: Vector3) -> float:
	var best := 0.0
	var bv := -9.0
	for i in 36:
		var a := TAU * i / 36.0 - PI
		var v: float = (_lsurf(l, s, a, 0.0)[1] as Vector3).dot(dir)
		if v > bv:
			bv = v
			best = a
	return best


## Alt ağzı açıya göre değişen uzuv kılıfı (sivri ağızlı kaval koruyucu): s0f(a) -> üst sınır
static func _lta(k, l: Dictionary, addf: Callable, colf: Callable, s0f: Callable, s1: float, n := 20, seg := 20) -> void:
	var rows := []
	var ss := []
	for j in n + 3:
		var v := minf(1.0, float(j) / n)
		var ro := []
		var sr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var s := lerpf(float(s0f.call(a)), s1, v)
			var e: Array = _lsurf(l, s, a, float(addf.call(s, a)) - (0.004 if j == n + 1 else (0.012 if j == n + 2 else 0.0)))
			ro.append(e[0])
			sr.append(s)
		rows.append(ro)
		ss.append(sr)
	k.grid(rows, true, func(i, j, _p): return colf.call(ss[j][i], TAU * i / seg - PI, j > n), func(i, j, _p): return P._lskin(l, ss[j][i]))


# ------------------------------------------------------------------ ortak takım: gömlek + pantolon (her köy kendi ölçüsüyle)
## o: bag (uyluk bolluğu), tuck (baldırda daralma başlangıcı, diz sonrası), cuff (bilek rulosu rengi)
static func _suit(k, b: Dictionary, sh: Color, pa: Color, o := {}) -> Dictionary:
	var H: float = k.H
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	P._inner(k, b, func(_i, j, _p): return sh.lightened(0.05) if j < 3 else sh)
	var bag: float = o.get("bag", 0.014)
	var tuck: float = o.get("tuck", 0.2)
	var seed_v: float = o.get("seed", 1.0)
	var under: float = o.get("under", 0.0)
	var hk := [P._kp(wa, H + 0.09, 0.013), P._kp(hp, H - 0.04, 0.017), P._kp(hp, H - 0.1, 0.004), [H - 0.135, 0.05, 0.05, -0.05], [H - 0.15, 0.01, 0.01, -0.01]]
	SE.body_layer(k, hk, 18, 40, func(_i, _j, _p): return pa)
	var out := {}
	for sd in ["Left", "Right"]:
		var ar: Dictionary = P._limb(k, sd, false)
		var le: Dictionary = P._limb(k, sd, true)
		var ak: float = ar["kn"]
		var kn: float = le["kn"]
		var sl := func(s: float, a: float) -> float:
			var e := exp(-pow((s - ak) / 0.085, 2.0))
			var w := exp(-pow((s - 0.86) / 0.07, 2.0))
			return 0.008 + 0.0065 * e * sin(a * 3.0 + s * 31.0 + seed_v) + 0.003 * w * sin(a * 4.0 + s * 40.0) + 0.0028 * P._lf(s, a, seed_v) * sin(s * PI)
		P._lt(k, ar, sl, func(s, a, ins):
			return sh.darkened(0.4) if ins else P._fs(sh, float(sl.call(s, a)) - 0.008, 34.0), 0.0, 0.985, 34, 18)
		k.wrap_turn(P._lp(ar, 0.955), P._ld(ar, 0.955), P._lr(ar, 0.955) + 0.012, 0.015, 0.0, (o.get("cuff", sh.lightened(0.05)) as Color), P._lskin(ar, 0.955))
		var pf := func(s: float, a: float) -> float:
			var th := bag * exp(-pow((s - kn * 0.55) / (kn * 0.62), 2.0))
			var kw := exp(-pow((s - kn) / 0.06, 2.0))
			var low := smoothstep(kn + tuck - 0.1, kn + tuck + 0.06, s)
			return 0.012 + th - 0.005 * low - under * (1.0 - smoothstep(kn * 0.2, kn * 0.62, s)) + (0.0075 * kw * sin(a * 3.0 + s * 34.0 + seed_v) + 0.004 * P._lf(s, a, seed_v + 1.0)) * (1.0 - low * 0.8)
		P._lt(k, le, pf, func(s, a, ins):
			return pa.darkened(0.4) if ins else P._fs(pa, float(pf.call(s, a)) - 0.016 - bag * 0.4 * (1.0 - s), 22.0), 0.0, 1.0, 40, 20)
		out[sd] = {"ar": ar, "le": le, "pf": pf, "sl": sl}
	return out


## Sandalet üstü bant sargısı (bilekten baldıra)
static func _shin_tape(k, l: Dictionary, pf: Callable, s0: float, n: int, col: Color) -> void:
	P._lt(k, l, func(s, a): return float(pf.call(s, a)) + 0.001, func(_s, _a, _i): return col.darkened(0.2), s0, 1.0, 10, 16)
	for i in n:
		var s := lerpf(s0 + 0.012, 0.985, float(i) / maxf(1.0, n - 1.0))
		k.wrap_turn(P._lp(l, s), P._ld(l, s), P._lr(l, s) + float(pf.call(s, 0.0)) + 0.006, 0.0125, 0.006, col.darkened(0.05 * float(i % 3)), P._lskin(l, s))


## Uyluk kılıfı: iki kayış + kutu (sağ)
static func _holster(k, l: Dictionary, pf: Callable, st: Color, box: Color) -> void:
	var kn: float = l["kn"]
	var s0: float = kn * 0.5
	for s in [s0, s0 + 0.08]:
		k.wrap_turn(P._lp(l, s), P._ld(l, s), P._lr(l, s) + float(pf.call(s, 0.0)) + 0.007, 0.012, 0.0, st, P._lskin(l, s))
	var a := _outer_a(l, s0 + 0.04, Vector3(-1.0, 0.0, 0.25))
	var e: Array = _lsurf(l, s0 + 0.04, a, float(pf.call(s0 + 0.04, a)) + 0.024)
	var o: Vector3 = e[1]
	var d: Vector3 = P._ld(l, s0)
	P._boxr(k, e[0], o.cross(d).normalized() * 0.036, -d * 0.056, o * 0.019, box, [["RightUpperLeg", 1.0]])
	P._boxr(k, (e[0] as Vector3) + o * 0.018 + d * 0.03 * -1.0, o.cross(d).normalized() * 0.038, -d * 0.024, o * 0.005, box.darkened(0.14), [["RightUpperLeg", 1.0]], 0.2)
	P._boxr(k, (e[0] as Vector3) + o * 0.0245 - d * 0.012, o.cross(d).normalized() * 0.007, -d * 0.007, o * 0.002, st, [["RightUpperLeg", 1.0]], 0.4)


## Parmaksız eldiven: bilek kolluğu + el sırtı
static func _glove(k, sd: String, ar: Dictionary, col: Color) -> void:
	var m = k.m
	var hd: Vector3 = m._bp(sd + "Hand")
	var el: Vector3 = m._bp(sd + "LowerArm")
	var d: Vector3 = (hd - el).normalized()
	P._lt(k, ar, func(s, _a): return 0.0125 + 0.004 * smoothstep(0.93, 0.985, s), func(_s, _a, ins): return col.darkened(0.4) if ins else col, 0.9, 0.99, 6, 18)
	var w := (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
	var t := d.cross(w).normalized()
	var skin_h := [[sd + "Hand", 1.0]]
	# avuç kılıfı: elin kendi köşelerinden ölçülür, parmak köküne kadar sarar
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
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.3) if j >= 4 else col, func(_i, _j, _p): return skin_h)
	# el sırtı metal plaka
	var o2 := (t if t.y > 0.0 else -t)
	var top_i: int = posmod(int(round((PI * (0.5 if t.y > 0.0 else -0.5) + PI) / TAU * nb)), nb)
	var lift: float = maxf(0.016, float(rad[2][top_i]))
	P._boxr(k, hd + d * 0.03 + o2 * (lift + 0.005), w * 0.021, d * 0.018, o2 * 0.0028, Color(0.66, 0.68, 0.72), skin_h, 0.25)


# ------------------------------------------------------------------ çizim parçaları
## Yüzey üstünde girdap (halka + sarmal)
static func _swirl(k, keys: Array, cx: float, cy: float, r: float, col: Color, front: bool) -> void:
	var pts := []
	var outs := []
	for i in 36:
		var t := TAU * i / 36.0
		var e: Array = P._fp(keys, cx + cos(t) * r, cy + sin(t) * r, front, 0.003)
		pts.append(e[0])
		outs.append(e[1])
	k.strip(pts, outs, r * 0.11, 0.0022, col, true, func(p: Vector3) -> Array: return _cs(k, p))
	pts = []
	outs = []
	for i in 40:
		var v := float(i) / 39.0
		var t := v * TAU * 1.75 + 0.5
		var rr := r * lerpf(0.72, 0.07, v)
		var e: Array = P._fp(keys, cx + cos(t) * rr, cy + sin(t) * rr, front, 0.003)
		pts.append(e[0])
		outs.append(e[1])
	k.strip(pts, outs, r * 0.1, 0.0022, col, false, func(p: Vector3) -> Array: return _cs(k, p))


## Kol üstünde girdap arması
static func _arm_swirl(k, l: Dictionary, s0: float, r: float, col: Color, add: float) -> void:
	var a0 := _outer_a(l, s0, Vector3(float(l["sg"]), 0.45, 0.2))
	var ls: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length() + ((l["p2"] as Vector3) - (l["p1"] as Vector3)).length()
	var R := P._lr(l, s0) + add
	var bo := P._lskin(l, s0)
	var run = func(n: int, f: Callable, hw: float, closed: bool) -> void:
		var pts := []
		var outs := []
		for i in n:
			var q: Vector2 = f.call(float(i) / (n if closed else n - 1))
			var e: Array = _lsurf(l, s0 + q.y / ls, a0 + q.x / R, add + 0.002)
			pts.append(e[0])
			outs.append(e[1])
		k.strip(pts, outs, hw, 0.002, col, closed, func(_p: Vector3) -> Array: return bo)
	run.call(28, func(v: float) -> Vector2: return Vector2(cos(v * TAU), sin(v * TAU)) * r, r * 0.13, true)
	run.call(30, func(v: float) -> Vector2:
		var t := v * TAU * 1.6 + 0.4
		return Vector2(cos(t), sin(t)) * r * lerpf(0.68, 0.08, v), r * 0.12, false)


## Bölmeli cep: her bölme ayrı yastık, üstünden bant geçer
static func _pouch(k, keys: Array, cx: float, cy: float, w: float, h: float, n: int, col: Color, band: Color, tilt := 0.0) -> void:
	var c0 := Vector3(0.0, cy, 0.0)
	_pil(k, func(u, v): return P._fp(keys, cx + (float(u) - 0.5) * (w + 0.012) + (float(v) - 0.5) * tilt, cy + (0.5 - float(v)) * (h + 0.012), true, 0.0)[0], 10, 10, 0.005, col.darkened(0.3), c0, 0.1)
	for i in n:
		var x0: float = cx - w * 0.5 + w * float(i) / n
		var dw: float = w / n
		_pil(k, func(u, v): return P._fp(keys, x0 + 0.0022 + float(u) * (dw - 0.0044) + (float(v) - 0.5) * tilt, cy + (0.5 - float(v)) * h, true, 0.004)[0], 5, 12, 0.0135, col, c0, 0.2, Callable(), func(u, v, ed):
			var c1: Color = col.lightened(0.07) if float(v) < 0.14 else col
			return c1.darkened(0.24) if ed < 0.05 or absf(float(u) - 0.5) > 0.44 else c1)
	var by := cy - h * 0.06
	P._strap(k, keys, [Vector2(cx - w * 0.52 + 0.0, by), Vector2(cx + w * 0.52, by)], true, h * 0.09, 0.0165, 0.003, band, 8)


# ------------------------------------------------------------------ Konoha Jōnin (ref Konoha_Flak_Jacket): lacivert takım, koyu yeşil yelek
static func _konoha(k) -> void:
	var nv := Color(0.12, 0.15, 0.3)
	var ve := Color(0.38, 0.48, 0.36)
	var red := Color(0.72, 0.17, 0.14)
	var wh := Color(0.86, 0.85, 0.8)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var nk: Vector3 = b["nk"]
	var L := _suit(k, b, nv, nv.darkened(0.04), {"bag": 0.012, "tuck": 0.24, "seed": 1.0, "cuff": nv.lightened(0.06)})
	var vk := [P._kp(nk, N + 0.005, 0.03), [N - 0.055, ch.x * 0.98, ch.y * 0.92, ch.z * 1.04], P._kp(ch, C - 0.03, 0.03), P._kp(wa, H + 0.125, 0.03), P._kp(wa, H + 0.088, 0.025), P._kp(wa, H + 0.052, 0.054), P._kp(wa, H + 0.012, 0.05), P._kp(wa, H - 0.012, 0.024)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.03 * exp(-pow(a / 0.028, 2.0)) - 0.016 * exp(-pow((aa - 1.72) / 0.05, 2.0))
		if y > H + 0.09:
			g += 0.006 * sin(a * 6.0 + y * 13.0) * smoothstep(C, H + 0.1, y)
		else:
			g += 0.007 * sin(a * 11.0 + 0.7)
		return g
	P._sheet(k, vk, 56, 88, Callable(), fold, func(a, y, _u, v, _p):
		var c0: Color = P._fs(ve, fold.call(a, y, 0.0), 7.0)
		if y < H + 0.1 and y > H + 0.075:
			c0 = c0.darkened(0.22)
		return c0.darkened(0.2) if v > 0.96 else c0, 0.007, 0.25)
	for sd in ["Left", "Right"]:
		var e: Dictionary = L[sd]
		_arm_swirl(k, e["ar"], 0.2, 0.03, red, 0.012)
		_shin_tape(k, e["le"], e["pf"], float(e["le"]["kn"]) + 0.3, 10, wh)
		_glove(k, sd, e["ar"], Color(0.09, 0.11, 0.2))
	_holster(k, L["Right"]["le"], L["Right"]["pf"], nv.darkened(0.3), wh.darkened(0.12))
	# iki parçalı dik yaka
	_collar(k, [P._kp(nk, N + 0.092, 0.03, 0.04), P._kp(nk, N + 0.05, 0.03, 0.038), P._kp(nk, N - 0.02, 0.05, 0.05)], 0.82, 0.3, ve, ve.lightened(0.08))
	var cc := Vector3(0.0, C, 0.0)
	# omuz yastıkları + çıtçıt
	for sg in [1.0, -1.0]:
		var surf := func(u, v) -> Vector3:
			var a: float = sg * lerpf(0.72, 2.32, float(v))
			var y: float = lerpf(N - 0.012, N - 0.078, float(u))
			return P._sa(vk, a, y, 0.0)[0]
		_pil(k, surf, 12, 14, 0.012, ve.lightened(0.05), cc, 0.16)
		var e: Vector3 = surf.call(0.66, 0.2)
		var o: Vector3 = _nrm(surf, 0.66, 0.2, cc)
		P._fan(k, e + o * 0.0145, o, Vector3.UP, 0.0095, Callable(), func(u2, v2): return ve.darkened(0.42) if sqrt(u2 * u2 + v2 * v2) > 0.7 else ve.lightened(0.28), k.torso_skin(N - 0.04), 3, 14)
	# parşömen cepleri, fermuar, dikiş
	for sg in [1.0, -1.0]:
		_pouch(k, vk, sg * ch.x * 0.48, C - 0.115, ch.x * 0.56, 0.135, 3, ve.darkened(0.06), ve.lightened(0.14), sg * -0.012)
	P._strap(k, vk, [Vector2(0.0, N - 0.03), Vector2(0.0, H + 0.0)], true, 0.0052, 0.0, 0.0035, Color(0.82, 0.83, 0.82), 26)
	# sırtta kırmızı girdap, omuz dikişi
	_swirl(k, vk, 0.0, C - 0.07, 0.075, red, false)
	# jōnin: bel arkasında alet çantası, yelek altından çıkar
	var hp: Vector3 = b["hp"]
	var bk := [P._kp(hp, H + 0.02, 0.016), P._kp(hp, H - 0.12, 0.016)]
	var e2: Array = P._fp(bk, wa.x * 0.42, H - 0.058, false, 0.02)
	P._boxr(k, e2[0], Vector3(0.05, 0, 0), Vector3(0, 0.036, 0), (e2[1] as Vector3) * 0.021, nv.darkened(0.3), [["Hips", 1.0]])
	var e3: Array = P._fp(bk, wa.x * 0.42, H - 0.04, false, 0.041)
	P._boxr(k, e3[0], Vector3(0.05, 0, 0), Vector3(0, 0.012, 0), (e3[1] as Vector3) * 0.004, nv.lightened(0.05), [["Hips", 1.0]])


# ------------------------------------------------------------------ Suna (ref Suna_Flak_Jacket, Baki): kanat omuzluk, geniş yaka, gri göğüs yamaları, ayrı alt kuşak
static func _suna(k, ve: Color, jonin: bool) -> void:
	var dk := Color(0.1, 0.1, 0.16)
	var pt := Color(0.1, 0.1, 0.15)
	var gr := Color(0.68, 0.7, 0.74)
	var san := Color(0.74, 0.65, 0.5)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var UA: float = k.UA
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var L := _suit(k, b, dk, pt, {"bag": 0.03, "tuck": 0.15, "seed": 2.3, "cuff": dk.lightened(0.05), "under": 0.03 if jonin else 0.0})
	var vk := [P._kp(nk, N + 0.005, 0.032), [N - 0.055, ch.x, ch.y * 0.94, ch.z * 1.05], P._kp(ch, C - 0.03, 0.034), P._kp(wa, H + 0.14, 0.036), P._kp(wa, H + 0.108, 0.03), P._kp(wa, H + 0.098, 0.02), P._kp(wa, H + 0.078, 0.062), P._kp(wa, H + 0.012, 0.066), P._kp(wa, H - 0.02, 0.03)]
	var fold := func(a: float, y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.028 * exp(-pow(a / 0.026, 2.0))
		if y > H + 0.1:
			g += 0.005 * sin(a * 5.0 - y * 15.0) - 0.014 * exp(-pow((aa - 1.5) / 0.05, 2.0))
		else:
			g -= 0.02 * exp(-pow((aa - 0.95) / 0.03, 2.0)) + 0.02 * exp(-pow((aa - 2.2) / 0.03, 2.0))
		return g
	P._sheet(k, vk, 60, 88, Callable(), fold, func(a, y, _u, v, _p):
		var c0: Color = P._fs(ve, fold.call(a, y, 0.0), 7.0)
		if y < H + 0.112 and y > H + 0.092:
			c0 = c0.darkened(0.34)
		return c0.darkened(0.22) if v > 0.96 else c0, 0.007, 0.25)
	var cc := Vector3(0.0, C, 0.0)
	var zc: float = (ch.y + ch.z) * 0.5
	var wing_x: float = UA + (0.235 if jonin else 0.2)
	for sd in ["Left", "Right"]:
		var sg := 1.0 if sd == "Left" else -1.0
		var e: Dictionary = L[sd]
		_shin_tape(k, e["le"], e["pf"], float(e["le"]["kn"]) + 0.2, 13, san if not jonin else san.darkened(0.14))
		var S: Vector3 = k.m._bp(sd + "UpperArm")
		var y_tip: float = S.y + 0.03
		var surf := func(u, v) -> Vector3:
			var uu := float(u)
			var q := float(v) * 2.0 - 1.0
			var hw := 0.128 * pow(maxf(0.0, 1.0 - pow(uu, 2.5)), 0.72) + 0.0015
			var y: float = lerpf(N + 0.004, y_tip, pow(uu, 1.15)) - 0.03 * q * q * (1.0 - uu * 0.65)
			return Vector3(sg * lerpf(nk.x + 0.02, wing_x, uu), y, zc + 0.012 + 0.018 * uu + q * hw)
		var sk: Callable = _ssk(k, sd, ch.x * 0.75, UA + 0.14, 0.32)
		_slab(k, surf, 22, 10, 0.013, 0.012, ve.lightened(0.04), cc + Vector3(0, -0.15, 0), sk, func(u, v):
			var d2: float = absf(float(v) - 0.5)
			return ve.lightened(0.09).darkened(0.3 if d2 > 0.42 else 0.0) if float(u) > 0.12 else ve)
		var ed := []
		for i in 23:
			var u := float(i) / 22.0
			ed.append((surf.call(u, 0.97) as Vector3) + Vector3(0, 0.006, 0))
		_pipe(k, ed, 0.0055, ve.lightened(0.16), sk)
		ed = []
		for i in 23:
			var u := float(i) / 22.0
			ed.append((surf.call(u, 0.03) as Vector3) + Vector3(0, 0.006, 0))
		_pipe(k, ed, 0.0055, ve.lightened(0.16), sk)
		# gri göğüs yaması: kanadın altında, kol ağzına doğru eğik
		_pil(k, func(u, v):
			var x: float = sg * lerpf(ch.x * 0.5, ch.x * 0.9, float(u))
			var y: float = lerpf(C + 0.052, C + 0.008, float(v)) - 0.03 * float(u)
			return P._fp(vk, x, y, true, 0.0)[0], 10, 6, 0.006, gr, cc, 0.14)
		_pouch(k, vk, sg * ch.x * 0.47, H + 0.2, ch.x * 0.62, 0.105, 4, ve.darkened(0.03), ve.darkened(0.3))
		if jonin:
			_glove(k, sd, e["ar"], Color(0.08, 0.08, 0.1))
			for s2 in [0.27, 0.31]:
				k.wrap_turn(P._lp(e["ar"], s2), P._ld(e["ar"], s2), P._lr(e["ar"], s2) + 0.012, 0.011, 0.002, san.darkened(0.12), P._lskin(e["ar"], s2))
	_holster(k, L["Right"]["le"], L["Right"]["pf"], pt.lightened(0.1), ve.darkened(0.25))
	_collar(k, [P._kp(nk, N + 0.112, 0.052, 0.062), P._kp(nk, N + 0.055, 0.046, 0.054), P._kp(nk, N - 0.025, 0.09, 0.086)], 0.98, 0.42, ve.lightened(0.03), ve.lightened(0.14), 0.009)
	P._strap(k, vk, [Vector2(0.0, N - 0.035), Vector2(0.0, H - 0.005)], true, 0.0052, 0.0, 0.0035, gr, 26)
	# sırt: dikişli üst panel
	_pil(k, func(u, v): return P._fp(vk, lerpf(-ch.x * 0.72, ch.x * 0.72, float(u)), lerpf(C + 0.03, H + 0.17, float(v)), false, 0.0)[0], 14, 12, 0.007, ve.lightened(0.03), cc, 0.08)
	if jonin:   # kalçaya sarılı çöl bezi + yan sarkan uç
		var hk := [P._kp(wa, H + 0.0, 0.052), P._kp(hp, H - 0.05, 0.05), P._kp(hp, H - 0.22, 0.066)]
		P._cur_hem = H - 0.22
		P._cur_leg = 0.86
		_pil(k, func(u, v):
			var y: float = lerpf(H - 0.03, H - 0.215, float(v))
			var w: float = lerpf(0.045, 0.03, float(v))
			return P._sa(hk, -1.5 + (float(u) - 0.5) * w / 0.09, y, 0.0)[0], 6, 12, 0.006, san.darkened(0.1), cc, 0.12, func(p: Vector3) -> Array: return _cs(k, p))
		P._cur_hem = H - 0.085
		_wg(k, hk, func(_a): return H - 0.012, func(a): return H - 0.07 - 0.012 * sin(a * 2.0 + 0.6), 72, 6, func(a, y, _v): return 0.032 + 0.007 * sin(a * 9.0 + y * 40.0), func(a, v, p):
			return P._fs(san.darkened(0.08), 0.007 * sin(a * 9.0 + p.y * 40.0), 16.0).darkened(0.16 if v > 0.84 else 0.0), func(p: Vector3) -> Array: return _cs(k, p))


# ------------------------------------------------------------------ Kiri (ref Kiri_Flak_Jacket): lila sert plaka, omuz kapakları, boyna çıkan dikmeler, önlük, çizgili koruyucular
static func _kiri(k, ve: Color, bd: Color, jonin: bool) -> void:
	var dk := Color(0.08, 0.08, 0.1)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var L := _suit(k, b, dk, dk.lightened(0.02), {"bag": 0.016, "tuck": 0.3, "seed": 3.7, "cuff": dk.lightened(0.05), "under": 0.026})
	var mid: Vector3 = ch.lerp(wa, 0.55)
	var vk := [P._kp(nk, N + 0.005, 0.03), [N - 0.055, ch.x * 0.96, ch.y * 0.94, ch.z * 1.05], P._kp(ch, C - 0.025, 0.04), P._kp(mid, C - 0.17, 0.036), P._kp(wa, H + 0.15, 0.03), P._kp(wa, H + 0.118, 0.02)]
	var fold := func(a: float, _y: float, _u: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		return -0.012 * exp(-pow((aa - 1.62) / 0.06, 2.0))
	P._sheet(k, vk, 44, 84, Callable(), fold, func(a, y, _u, v, _p):
		return P._fs(ve, fold.call(a, y, 0.0), 8.0).darkened(0.24 if v > 0.95 else 0.0), 0.006, 0.2)
	# karın plakası: göğüs plakasının altına girer
	var lk := [P._kp(wa, H + 0.13, 0.014), P._kp(wa, H + 0.075, 0.03), P._kp(wa, H + 0.0, 0.036), P._kp(hp, H - 0.03, 0.022)]
	P._sheet(k, lk, 16, 72, Callable(), Callable(), func(_a, _y, _u, v, _p): return ve.darkened(0.08).darkened(0.25 if v > 0.92 else 0.0), 0.006, 0.3)
	var cc := Vector3(0.0, C, 0.0)
	var ring: Array = P._ring_pts(lk, H + 0.098, 0.011, 72)
	_pipe(k, ring, 0.011, ve.lightened(0.1), func(p: Vector3) -> Array: return k.torso_skin(p.y), true)
	# önlük: öne ve arkaya sivrilen plaka, kumaş gibi bacakla açılır
	var hk := [P._kp(wa, H + 0.05, 0.036), P._kp(hp, H - 0.04, 0.04), P._kp(hp, H - 0.24, 0.062)]
	P._cur_leg = 0.86
	var hs := func(p: Vector3) -> Array: return _cs(k, p)
	# plakalı etek: yanlarda bacak için kısa, önde ve arkada uzun; dikey oluklar plakaları ayırır
	var tier := func(y_top: float, y_bot: float, col: Color, ph: float, off: float) -> void:
		P._cur_hem = y_bot
		var gr_f := func(a: float) -> float: return pow(0.5 + 0.5 * cos(a * 8.0 + ph), 26.0)
		var bt := func(a) -> float: return y_bot + 0.05 * pow(absf(sin(float(a))), 2.0) + 0.012 * float(gr_f.call(float(a)))
		_wg(k, hk, func(_a): return y_top, bt, 96, 10, func(a, _y, v): return off - 0.016 * float(gr_f.call(float(a))) + 0.012 * float(v), func(a, v, _p):
			return col.darkened(0.3 * float(gr_f.call(float(a)))).darkened(0.3 if float(v) > 0.9 else 0.0), hs)
	if jonin:
		tier.call(H - 0.02, H - 0.18, ve.darkened(0.06), 0.39, 0.036)
	tier.call(H + 0.035, H - (0.1 if jonin else 0.125), ve.lightened(0.03), 0.0, 0.066 if jonin else 0.062)
	for sd in ["Left", "Right"]:
		var sg := 1.0 if sd == "Left" else -1.0
		var e: Dictionary = L[sd]
		var ar: Dictionary = e["ar"]
		var le: Dictionary = e["le"]
		var ak: float = ar["kn"]
		var kn: float = le["kn"]
		# çizgili koruyucular
		var stripe := func(s: float) -> float: return 0.5 + 0.5 * sin(s * 150.0)
		var sl: Callable = e["sl"]
		var pf: Callable = e["pf"]
		var ga := func(s: float, a: float) -> float: return float(sl.call(s, a)) + 0.0055 + 0.0024 * float(stripe.call(s))
		P._lt(k, ar, ga, func(s, _a, ins): return bd.darkened(0.45) if ins else bd.darkened(0.3 * (1.0 - float(stripe.call(s)))), ak + 0.08, 0.93, 26, 18, 0.03)
		for s2 in [ak + 0.085, 0.925]:
			k.wrap_turn(P._lp(ar, s2), P._ld(ar, s2), P._lr(ar, s2) + float(sl.call(s2, 0.0)) + 0.0095, 0.008, 0.0, dk.lightened(0.1), P._lskin(ar, s2))
		var gl := func(s: float, a: float) -> float: return float(pf.call(s, a)) + 0.0065 + 0.0026 * float(stripe.call(s * 0.8))
		_lta(k, le, gl, func(s, _a, ins): return bd.darkened(0.45) if ins else bd.darkened(0.3 * (1.0 - float(stripe.call(float(s) * 0.8)))), func(a): return kn + 0.09 - 0.05 * pow(maxf(0.0, cos(float(a))), 2.0), 0.955, 28, 22)
		for s2 in [kn + 0.13, 0.945]:
			k.wrap_turn(P._lp(le, s2), P._ld(le, s2), P._lr(le, s2) + float(gl.call(s2, 0.0)) + 0.004, 0.009, 0.0, dk.lightened(0.1), P._lskin(le, s2))
		# boyna çıkan dikme (önden omuza)
		_pil(k, func(u, v):
			var vv := float(v)
			var x: float = sg * (lerpf(ch.x * 0.36, nk.x + 0.028, vv) + (float(u) - 0.5) * lerpf(0.082, 0.056, vv))
			return P._fp(vk, x, lerpf(C - 0.07, N - 0.012, vv), true, 0.0)[0], 6, 14, 0.011, ve.lightened(0.07), cc, 0.16)
		_pil(k, func(u, v):
			var vv := float(v)
			var x: float = sg * (lerpf(ch.x * 0.36, nk.x + 0.028, vv) + (float(u) - 0.5) * lerpf(0.082, 0.056, vv))
			return P._fp(vk, x, lerpf(C - 0.05, N - 0.012, vv), false, 0.0)[0], 6, 14, 0.011, ve.lightened(0.07), cc, 0.16)
		# yan yuva çentiği
		_pil(k, func(u, v):
			var x: float = sg * (wa.x * 0.62 + float(u) * 0.05)
			return P._fp(vk, x, H + 0.185 + float(u) * 0.016 - float(v) * 0.018, true, 0.0)[0], 5, 3, 0.003, dk.lightened(0.14), cc, 0.2)
		# omuz kapağı: üst kolu saran kabuk, kolla birlikte döner (bağ duruşu T: dış yön yukarı)
		var a0 := _outer_a(ar, 0.12, Vector3(sg * 0.15, 1.0, 0.0))
		var cap = func(s0: float, s1: float, wd: float, lf: float) -> Callable:
			return func(u, v) -> Vector3:
				var uu := float(u)
				var q := float(v) * 2.0 - 1.0
				var s: float = lerpf(s0, s1, uu)
				var nar := 1.0 - 0.28 * pow(uu, 3.0)
				return _lsurf(ar, s, a0 + q * wd * nar, lf + 0.022 * uu * uu - 0.012 * q * q)[0]
		var csk := func(p: Vector3) -> Array:
			var t2: float = clampf(((p - (ar["p0"] as Vector3)).dot(P._ld(ar, 0.1))) / ((ar["p1"] as Vector3) - (ar["p0"] as Vector3)).length(), 0.0, 1.0)
			var w2: float = smoothstep(0.0, 0.14, t2) * 0.6 + 0.4
			return [["UpperChest", 1.0 - w2], [sd + "UpperArm", w2]]
		var c1: Vector3 = P._lp(ar, 0.12)
		if jonin:
			_slab(k, cap.call(0.15, 0.31, 1.75, 0.03), 10, 16, 0.008, 0.004, ve.darkened(0.08), c1, csk)
		_slab(k, cap.call(0.0, 0.22 if jonin else 0.27, 1.95, 0.038), 12, 18, 0.009, 0.007, ve, c1, csk)
	# dik yaka: geniş açık, kenarı kalın
	_collar(k, [P._kp(nk, N + 0.082, 0.032, 0.044), P._kp(nk, N + 0.04, 0.03, 0.04), P._kp(nk, N - 0.02, 0.052, 0.052)], 1.12, 0.62, ve, ve.lightened(0.1), 0.0065)
	# göğüs: oturtulmuş üst plaka, sırt plakası
	_pil(k, func(u, v):
		var vv := float(v)
		return P._fp(vk, (float(u) - 0.5) * 2.0 * ch.x * lerpf(0.3, 0.66, vv * (2.0 - vv)), lerpf(C - 0.075, H + 0.145, vv), true, 0.0)[0], 14, 14, 0.008, ve.lightened(0.04), cc, 0.07)
	_pil(k, func(u, v): return P._fp(vk, (float(u) - 0.5) * 1.5 * ch.x, lerpf(C - 0.04, H + 0.15, float(v)), false, 0.0)[0], 12, 12, 0.007, ve.lightened(0.03), cc, 0.08)


# ------------------------------------------------------------------ Kumo (ref Darui, Samui): tek omuzlu beyaz göğüs zırhı, kalça bezi, beyaz kaval koruyucu
static func _kumo(k) -> void:
	var nv := Color(0.1, 0.12, 0.25)
	var wh := Color(0.88, 0.88, 0.86)
	var tr := Color(0.62, 0.57, 0.48)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var b: Dictionary = P._base(k)
	var ch: Vector3 = b["ch"]
	var wa: Vector3 = b["wa"]
	var hp: Vector3 = b["hp"]
	var nk: Vector3 = b["nk"]
	var L := _suit(k, b, nv, nv.darkened(0.03), {"bag": 0.02, "tuck": 0.08, "seed": 5.1, "cuff": wh, "under": 0.03})
	var vk := [P._kp(nk, N + 0.012, 0.024), [N - 0.055, ch.x * 0.97, ch.y * 0.93, ch.z * 1.04], P._kp(ch, C - 0.03, 0.028), P._kp(wa, H + 0.12, 0.024), P._kp(wa, H + 0.05, 0.028)]
	var hi := N + 0.002
	var lo := C - 0.1
	var top := func(a: float) -> float:
		return lerpf(lo, hi, pow(smoothstep(-0.78, 0.93, sin(a)), 1.55))
	var bot := func(a: float) -> float: return H + 0.062 + 0.006 * cos(a)
	var bon := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	_wg(k, vk, top, bot, 96, 40, func(a, y, _v): return 0.004 * sin(a * 4.0 + float(y) * 9.0), func(a, v, _p):
		var c0: Color = wh.darkened(0.05 if sin(float(a) * 4.0 + _p.y * 9.0) < -0.5 else 0.0)
		return c0.darkened(0.24) if v > 0.97 else c0, bon)
	var te := []
	var he := []
	for i in 96:
		var a := TAU * i / 96.0 - PI
		te.append(P._sa(vk, a, top.call(a), 0.002)[0])
		he.append(P._sa(vk, a, bot.call(a), 0.003)[0])
	_pipe(k, te, 0.0075, tr, bon, true)
	_pipe(k, he, 0.0115, tr, bon, true)
	var cc := Vector3(0.0, C, 0.0)
	# çapraz dikişler ve dört çizgi (Kumo zırhının işareti)
	var seam := func(pts: Array, fr: bool, hw: float) -> void:
		P._strap(k, vk, pts, fr, hw, 0.001, 0.0024, tr, 12)
	seam.call([Vector2(-ch.x * 0.98, C - 0.14), Vector2(-ch.x * 0.1, C - 0.1), Vector2(ch.x * 0.9, H + 0.12)], true, 0.0052)
	seam.call([Vector2(ch.x * 0.1, C - 0.15), Vector2(-ch.x * 0.42, H + 0.075)], true, 0.0052)
	seam.call([Vector2(-ch.x * 0.9, C - 0.13), Vector2(ch.x * 0.85, H + 0.13)], false, 0.0052)
	for i in 4:
		var x: float = ch.x * (0.02 + float(i) * 0.13)
		seam.call([Vector2(x, C - 0.04 - float(i) * 0.012), Vector2(x - 0.02, C - 0.085 - float(i) * 0.012)], true, 0.0042)
	# omuz çıtçıtı
	var sn: Array = P._sa(vk, 1.15, N - 0.03, 0.006)
	P._fan(k, sn[0], (sn[1] as Vector3 + Vector3.UP * 0.5).normalized(), Vector3.UP, 0.016, Callable(), func(u2, v2): return tr.darkened(0.3) if sqrt(u2 * u2 + v2 * v2) > 0.72 else wh.darkened(0.16), k.torso_skin(N - 0.03), 3, 16)
	# kaval koruyucu: dizin altına sivri ağız, ön sırt
	for sd in ["Left", "Right"]:
		var e: Dictionary = L[sd]
		var le: Dictionary = e["le"]
		var kn: float = le["kn"]
		var pf: Callable = e["pf"]
		var ga := func(s: float, a: float) -> float:
			return float(pf.call(s, a)) + 0.008 + 0.009 * pow(maxf(0.0, cos(a)), 6.0) + 0.012 * smoothstep(0.86, 0.96, s)
		_lta(k, le, ga, func(s, a, ins):
			if ins:
				return wh.darkened(0.45)
			return wh.darkened(0.12 * smoothstep(0.2, -0.6, cos(float(a)))).darkened(0.1 if absf(float(s) - 0.93) < 0.006 else 0.0), func(a): return kn + 0.1 - 0.085 * pow(maxf(0.0, cos(float(a))), 3.0), 0.965, 28, 24)
		for s2 in [kn + 0.17, 0.9]:
			k.wrap_turn(P._lp(le, s2), P._ld(le, s2), P._lr(le, s2) + float(ga.call(s2, PI)) + 0.002, 0.009, 0.0, nv.darkened(0.3), P._lskin(le, s2))
	# kalça bezi: eğik sarılı, sol yanda sarkan kahve iç kat
	var hk := [P._kp(wa, H + 0.075, 0.018), P._kp(wa, H + 0.03, 0.034), P._kp(hp, H - 0.05, 0.052), P._kp(hp, H - 0.17, 0.062), P._kp(hp, H - 0.33, 0.066)]
	P._cur_hem = H - 0.31
	P._cur_leg = 0.86
	_pil(k, func(u, v):
		var vv := float(v)
		var y: float = lerpf(H - 0.02, H - 0.31 + 0.06 * float(u), vv)
		var q0: Vector3 = P._sa(hk, lerpf(1.08, 2.1, float(u)), y, 0.0)[0]
		var sc := 1.05   # bezin üstünde durur: kıvrımlarla kesişip yırtık görünmez
		return Vector3(q0.x * sc, q0.y, q0.z * sc), 10, 14, 0.008, tr.darkened(0.14), cc, 0.1, func(p: Vector3) -> Array:
		if p.y >= H:
			return k.torso_skin(p.y)
		var t: float = pow(clampf((H - p.y) / 0.31, 0.0, 1.0), 0.35)   # sol uyluğa oturur: bacak kalkınca delinmez
		return [["Hips", 1.0 - t], ["LeftUpperLeg", t]])
	P._cur_hem = H - 0.23
	var dr := func(a: float, y: float) -> float: return 0.028 * sin(a * 4.0 + y * 21.0) + 0.012 * sin(a * 9.0 - y * 15.0)
	var dtop := func(_a): return H + 0.074
	var dbot := func(a) -> float: return H - 0.13 - 0.1 * smoothstep(-0.2, 0.95, sin(float(a)))
	_wg(k, hk, dtop, dbot, 88, 26, func(a, y, v): return float(dr.call(a, y)) * float(smoothstep(0.0, 0.25, v)), func(a, v, p):
		return P._fs(nv.lightened(0.1), float(dr.call(a, p.y)) * float(smoothstep(0.0, 0.25, v)), 9.0).darkened(0.3 if v > 0.94 else 0.0), func(p: Vector3) -> Array: return _cs(k, p))
