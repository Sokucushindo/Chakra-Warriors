extends RefCounted
## Elle modellenmiş setler, parti l: set_kenpo, set_kenshi, set_joki, set_samurai, set_sengoku, set_kage_no. Örnek: set_el.gd içindeki _shugonin.
## Hakama iki ayrı geniş paçadır (gerçek umanori): her paça kendi bacağını izler, etek gibi sıkışmaz.
## Zırhlar ayrı ayrı kalınlığı olan plakalardan (lame) kurulur; plakalar birbirine bağcıkla bağlanır.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_kenpo", "set_kenshi", "set_joki", "set_samurai", "set_sengoku", "set_kage_no"]

static var _hem := 0.0


static func recipe(k, sid: String) -> void:
	match sid:
		"set_kenpo": _kenpo(k)
		"set_kenshi": _kenshi(k)
		"set_joki": _joki(k)
		"set_samurai": _samurai(k)
		"set_sengoku": _sengoku(k)
		"set_kage_no": _kage_no(k)


# ------------------------------------------------------------------ ölçü ve ağırlık
static func _base(k) -> Dictionary:
	return {"ch": k.M(k.C - 0.03, k.UA), "wa": k.M(k.H + 0.12, k.UA), "hp": k.M(k.H - 0.04, 0.3), "nk": k.M(k.N + 0.02, 0.09),
		"aL": _limb(k, "Left", false), "aR": _limb(k, "Right", false), "lL": _limb(k, "Left", true), "lR": _limb(k, "Right", true)}


static func _kp(m: Vector3, y: float, p: float, pz := -1.0) -> Array:
	var q: float = p if pz < 0.0 else pz
	return [y, m.x + p, m.y + q, m.z - q]


## Gövde kesitleri: boyundan etek ucuna. back: arka kumaş payı
static func _tk(k, b: Dictionary, pad: float, hem: float, flare := 0.05, back := 0.015) -> Array:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	var ke := [_kp(nk, k.N + 0.008, 0.03), [k.N - 0.06, ch.x * 0.98, ch.y * 0.92 + pad * 0.5, ch.z * 1.02 - pad * 0.5], _kp(ch, k.C - 0.03, pad + 0.012), _kp(b["wa"], k.H + 0.12, pad + 0.012)]
	var hk: Array = _kp(b["hp"], k.H - 0.04, pad + 0.016)
	hk[3] = float(hk[3]) - back
	ke.append(hk)
	if hem < k.H - 0.05:
		var he: Array = _kp(b["hp"], hem, pad + 0.016 + flare)
		he[3] = float(he[3]) - back * 1.8
		ke.append(he)
	return ke


static func _inner(k, b: Dictionary, colf: Callable, pad := 0.01) -> void:
	var nk: Vector3 = b["nk"]
	var ch: Vector3 = b["ch"]
	SE.body_layer(k, [_kp(nk, k.N + 0.06, 0.008, 0.01), _kp(nk, k.N + 0.02, 0.016), [k.N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], _kp(ch, k.C - 0.03, pad), _kp(b["wa"], k.H + 0.12, pad), _kp(b["hp"], k.H - 0.1, pad)], 26, 44, colf)


## Bel altı kumaş: iki bacak arasında geniş geçiş (kumaş ortada kırılmaz)
static func _hs(k, p: Vector3) -> Array:
	if p.y >= k.H:
		return k.torso_skin(p.y)
	var t: float = clampf((k.H - p.y) / maxf(0.05, k.H - _hem), 0.0, 1.0)
	var s: float = smoothstep(-0.12, 0.12, p.x)
	var w: float = t * _lg(p.z)
	return [["Hips", 1.0 - w], ["LeftUpperLeg", w * s], ["RightUpperLeg", w * (1.0 - s)]]


## Ön etek kalkan uyluğu daha çok izler (uyluk kumaşı delmez), arka etek geri giden bacağa payla yetişir
static func _lg(z: float) -> float:
	return lerpf(0.52, 0.86, smoothstep(0.0, 0.08, z))


static func _fs(c: Color, v: float, gain := 6.0) -> Color:
	return c.darkened(clampf(-v * gain, 0.0, 0.36)) if v < 0.0 else c.lightened(clampf(v * gain * 0.4, 0.0, 0.1))


static func _sa(keys: Array, a: float, y: float, lift := 0.0) -> Array:
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
	var o := Vector3(q.x, 0.0, q.y).normalized()
	return [Vector3(q.x, y, q.y) + o * lift, o]


static func _out(p: Vector3, up := 0.0) -> Vector3:
	return Vector3(p.x, up, p.z).normalized()


# ------------------------------------------------------------------ uzuv
static func _limb(k, sd: String, leg: bool) -> Dictionary:
	var m = k.m
	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var bo: Array
	if leg:
		p0 = m._bp(sd + "UpperLeg") + Vector3(0, 0.05, 0)
		p1 = m._bp(sd + "LowerLeg")
		p2 = m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		bo = [sd + "UpperLeg", sd + "LowerLeg"]
	else:
		var ch: Vector3 = m._bp("UpperChest")
		p0 = (m._bp(sd + "UpperArm") as Vector3).lerp(Vector3(0.0, ch.y, ch.z), 0.2)
		p1 = m._bp(sd + "LowerArm")
		p2 = (m._bp(sd + "Hand") as Vector3).lerp(p1, -0.05)
		bo = [sd + "UpperArm", sd + "LowerArm"]
	var la: float = (p1 - p0).length()
	var lb: float = (p2 - p1).length()
	var l := {"p0": p0, "p1": p1, "p2": p2, "bo": bo, "kn": la / (la + lb), "leg": leg, "sd": sd, "sg": 1.0 if sd == "Left" else -1.0, "sj": 0.0}
	if not leg:   # omuz ekleminin tüp üstündeki yeri: içerisi gövdeyle gider, kol inince boynuz gibi kalkmaz
		l["sj"] = ((m._bp(sd + "UpperArm") as Vector3) - p0).length() / (la + lb)
	var nb := 14
	var sum := []
	var cnt := []
	sum.resize(nb)
	cnt.resize(nb)
	sum.fill(0.0)
	cnt.fill(0)
	var cap: float = 0.13 if leg else 0.095
	var V: PackedVector3Array = k.c["V"]
	var sx: float = l["sg"]
	for q: Vector3 in V:
		if q.x * sx < 0.01:
			continue
		for seg in 2:
			var a: Vector3 = p0 if seg == 0 else p1
			var b: Vector3 = p1 if seg == 0 else p2
			var ab: Vector3 = b - a
			var t: float = (q - a).dot(ab) / ab.length_squared()
			if t < 0.0 or t > 1.0:
				continue
			var dd: float = (q - a - ab * t).length()
			if dd > cap:
				continue
			var s: float = t * float(l["kn"]) if seg == 0 else lerpf(l["kn"], 1.0, t)
			var bi: int = mini(nb - 1, int(s * nb))
			sum[bi] += dd
			cnt[bi] += 1
			break
	var rad := []
	var fall: float = 0.09 if leg else 0.05
	for i in nb:
		if cnt[i] > 0:
			fall = float(sum[i]) / cnt[i] * 1.1
		rad.append(fall)
	l["rad"] = rad
	return l


static func _lp(l: Dictionary, s: float) -> Vector3:
	var kn: float = l["kn"]
	if s < kn:
		return (l["p0"] as Vector3).lerp(l["p1"], s / kn)
	return (l["p1"] as Vector3).lerp(l["p2"], (s - kn) / (1.0 - kn))


static func _ld(l: Dictionary, s: float) -> Vector3:
	var d0: Vector3 = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).normalized()
	var d1: Vector3 = ((l["p2"] as Vector3) - (l["p1"] as Vector3)).normalized()
	return d0.lerp(d1, smoothstep(float(l["kn"]) - 0.06, float(l["kn"]) + 0.06, s)).normalized()


static func _lr(l: Dictionary, s: float) -> float:
	var rad: Array = l["rad"]
	var f: float = clampf(s * rad.size() - 0.5, 0.0, rad.size() - 1.001)
	var i: int = int(f)
	return lerpf(rad[i], rad[i + 1], f - i)


static func _lskin(l: Dictionary, s: float) -> Array:
	var bo: Array = l["bo"]
	var kn: float = l["kn"]
	var w: float = smoothstep(kn - 0.07, kn + 0.07, s)
	if w > 0.0:
		return [[bo[0], 1.0 - w], [bo[1], w]]
	if not l["leg"]:
		var sj: float = l["sj"]
		var wj: float = smoothstep(sj - 0.02, sj + 0.1, s)
		return [["UpperChest", 1.0 - wj], [bo[0], wj]] if wj < 1.0 else [[bo[0], 1.0]]
	var w0: float = (1.0 - smoothstep(0.0, 0.14, s)) * 0.4
	if w0 > 0.0:
		return [[bo[0], 1.0 - w0], ["Hips" if l["leg"] else "UpperChest", w0]]
	return [[bo[0], 1.0]]


## Uzuv tüpü: addf(s, a) yarıçapa eklenir, colf(s, a, ic). lining: uçtan içe dönen astar
static func _lt(k, l: Dictionary, addf: Callable, colf: Callable, s0 := 0.0, s1 := 1.0, n := 30, seg := 18, lining := 0.0) -> void:
	var st := []
	for j in n + 1:
		st.append([lerpf(s0, s1, float(j) / n), 0.0, false])
	if lining > 0.0:
		st.append([s1, -0.004, true])
		for j in 4:
			st.append([s1 - lining * float(j) / 3.0, -0.007, true])
	else:
		st.append([s1, -0.003, true])
		st.append([s1 - 0.004, -0.012, true])
	var rows := []
	for e in st:
		var s: float = e[0]
		var d: Vector3 = _ld(l, s)
		var c: Vector3 = _lp(l, s)
		var fw: Vector3 = (Vector3.BACK - d * d.dot(Vector3.BACK)).normalized()
		var ri: Vector3 = (-d).cross(fw).normalized()
		var ro := []
		for i in seg:
			var a: float = TAU * i / seg - PI
			var r: float = maxf(0.006, _lr(l, s) + float(addf.call(s, a)) + float(e[1]))
			ro.append(c + ri * sin(a) * r + fw * cos(a) * r)
		rows.append(ro)
	k.grid(rows, true, func(i, j, _p): return colf.call(st[j][0], TAU * i / seg - PI, st[j][2]), func(_i, j, _p): return _lskin(l, st[j][0]))


static func _wraps(k, l: Dictionary, s0: float, s1: float, n: int, add: float, hw: float, col: Color, tilt := 0.01) -> void:
	for i in n:
		var s: float = lerpf(s0, s1, float(i) / maxf(1.0, n - 1.0))
		k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + add, hw, tilt, col.darkened(0.05 * float(i % 3)), _lskin(l, s))


## Kolun dış yönü (omuz plakası, kolluk bu yöne bakar); bacakta ön
static func _ov(l: Dictionary) -> Vector3:
	return Vector3.BACK if l["leg"] else (Vector3.UP + Vector3(float(l["sg"]) * 0.4, 0.0, 0.0)).normalized()


# ------------------------------------------------------------------ kumaş
## Serbest kenarlı kumaş. o: keys, top(a), hem(a), rng(v), fold(a,y,v), col(a,y,v), ny, na, th, gain, skin(p)
static func _cl(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var top: Callable = o["top"]
	var hem: Callable = o["hem"]
	var ny: int = o.get("ny", 30)
	var na: int = o.get("na", 80)
	var closed: bool = not o.has("rng")
	var rng: Callable = o.get("rng", Callable())
	var fold: Callable = o.get("fold", Callable())
	var col: Callable = o["col"]
	var th: float = o.get("th", 0.005)
	var gain: float = o.get("gain", 6.5)
	var over: float = o.get("over", 0.0)
	var cnt: int = na if closed else na + 1
	var outer := []
	var cols := []
	var low := 99.0
	for j in ny + 1:
		var v: float = float(j) / ny
		var r: Vector2 = Vector2(-PI, PI) if closed else rng.call(v)
		var ro := []
		var cr := []
		for i in cnt:
			var u: float = float(i) / na
			var a: float = lerpf(r.x, r.y, u)
			var aw: float = wrapf(a, -PI, PI)
			var y: float = lerpf(float(top.call(aw)), float(hem.call(aw)), v)
			var s: Array = SE.El.key_at(keys, y)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f: float = float(fold.call(aw, y, v)) if fold.is_valid() else 0.0
			var up: float = over * (1.0 - smoothstep(0.0, 0.26, u))   # üste binen kanat dışarıda durur
			ro.append(Vector3(q.x * (1.0 + f + up), y, q.y * (1.0 + f + up)))
			cr.append(_fs(col.call(aw, y, v), f, gain))
			low = minf(low, y)
		outer.append(ro)
		cols.append(cr)
	_hem = low
	var rows: Array = outer.duplicate()
	var cc: Array = cols.duplicate()
	if th > 0.0:
		var inw := func(p: Vector3, d: float) -> Vector3: return p - Vector3(p.x, 0.0, p.z).normalized() * d
		var roll := []
		var rc := []
		for i in cnt:
			roll.append(inw.call(outer[ny][i], th * 0.5) + Vector3(0, -th * 0.5, 0))
			rc.append((cols[ny][i] as Color).darkened(0.25))
		rows.append(roll)
		cc.append(rc)
		for j in range(ny, -1, -1):
			var ro := []
			var cr := []
			for i in cnt:
				var edge: bool = not closed and (i == 0 or i == cnt - 1)
				ro.append(inw.call(outer[j][i], 0.0 if edge else th))
				cr.append((cols[j][i] as Color).darkened(0.42))
			rows.append(ro)
			cc.append(cr)
		rows.append(outer[0])
		cc.append(cols[0])
	var sf: Callable = o.get("skin", func(p: Vector3) -> Array: return _hs(k, p))
	k.grid(rows, closed, func(i, j, _p): return cc[j][i], func(_i, _j, p): return sf.call(p))
	var ea := []
	var eb := []
	for ro in outer:
		ea.append(ro[0])
		eb.append(ro[cnt - 1])
	return {"rows": outer, "top": outer[0], "hem": outer[ny], "ea": ea, "eb": eb, "low": low}


## Sarmal üst giysi: sol kanat sağın üstüne biner (kimono bindirmesi). close: bel altında bindirme genişliği
static func _wrap_top(k, keys: Array, foldf: Callable, colf: Callable, ny := 44, na := 92, close := 0.5, yend := -99.0) -> Dictionary:
	var ytop: float = keys[0][0]
	var yl: float = yend if yend > -9.0 else float(keys[keys.size() - 1][0])
	var N: float = k.N
	return _cl(k, {"keys": keys, "top": func(_a): return ytop, "hem": func(_a): return yl, "ny": ny, "na": na, "over": 0.045,
		"rng": func(v: float) -> Vector2:
			var y: float = lerpf(ytop, yl, v)
			var e: float = lerpf(-close, 0.52, clampf((y - (k.H + 0.04)) / (N - (k.H + 0.04)), 0.0, 1.0))
			return Vector2(e, TAU - e * 0.62),
		"fold": foldf, "col": colf})


## Devrik yaka: kanat kenarı boyunca iner, ense çevresinden geçer. je: inilecek satır
static func _eri(k, res: Dictionary, je: int, hw: float, d: float, col: Color, stitch: Color) -> void:
	var ea: Array = res["ea"]
	var eb: Array = res["eb"]
	var top: Array = res["top"]
	var pts := []
	for j in range(je, -1, -1):
		pts.append(ea[j])
	for i in range(2, top.size() - 2, 2):
		pts.append(top[i])
	for j in je + 1:
		pts.append(eb[j])
	var ou := []
	for p in pts:
		var w: float = smoothstep(k.N - 0.09, k.N, p.y)
		ou.append(Vector3(p.x, w * 0.5, p.z).normalized())
	var skf := func(p: Vector3) -> Array: return _hs(k, p)
	k.strip(pts, ou, hw, d, col, false, skf)
	var st := []
	for j in pts.size():
		st.append((pts[j] as Vector3) + (ou[j] as Vector3) * (d + 0.0005))
	k.strip(st, ou, 0.0016, 0.0009, stitch, false, skf)


static func _sash(k, keys: Array, y: float, h: float, lift: float, col: Color, crease := 0.14, layers := 2) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var na := 56
	var ny: int = 3 + 2 * layers
	var rows := []
	var cc := []
	for j in ny:
		var t: float = float(j) / (ny - 1)
		var b: float = 0.007 * sin(t * PI) + lift + 0.003 * sin(t * PI * layers * 2.0)
		var ro := []
		var cr := []
		for i in na:
			var a: float = TAU * i / na - PI
			var wob: float = 0.0035 * sin(a * 5.0 + t * 7.0)
			var q: Vector2 = SE.El.sup(a, float(s[1]) + b + wob, float(s[2]) + b + wob, float(s[3]) - b - wob)
			ro.append(Vector3(q.x, y + h * (1.0 - 2.0 * t) + 0.003 * sin(a * 3.0 + 1.0), q.y))
			cr.append(col.darkened(crease) if j % 2 == 1 and sin(a * 4.0 + float(j)) > -0.5 else col)
		rows.append(ro)
		cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return k.torso_skin(p.y))


## Kumaş üstüne oturan sarkan bant
static func _tail(k, keys: Array, x0: float, x1: float, y0: float, ln: float, hw: float, lift: float, col: Color, back := false) -> void:
	var pts := []
	var ou := []
	for i in 13:
		var v: float = float(i) / 12.0
		var y: float = y0 - v * ln
		var s: Array = SE.El.key_at(keys, y)
		var x: float = lerpf(x0, x1, v)
		var rx: float = clampf(absf(x) / float(s[1]), 0.0, 0.95)
		var zm: float = absf(float(s[3] if back else s[2])) * pow(1.0 - pow(rx, 2.5), 0.4)
		pts.append(Vector3(x, y, (-zm if back else zm) * 1.04 + (-lift if back else lift)))
		ou.append(Vector3(0, 0, -1.0 if back else 1.0))
	k.strip(pts, ou, hw, 0.004, col, false, func(p): return _hs(k, p))


## Eğri çizgi boyunca yuvarlak ip
static func _cord(k, pts: Array, r: float, col: Color, skinf: Callable, seg := 6) -> void:
	var n: int = pts.size()
	var rows := []
	for j in n:
		var a: Vector3 = pts[maxi(0, j - 1)]
		var b: Vector3 = pts[mini(n - 1, j + 1)]
		var t: Vector3 = (b - a).normalized()
		var fw: Vector3 = Vector3.BACK - t * t.dot(Vector3.BACK)
		if fw.length() < 0.2:
			fw = Vector3.UP - t * t.dot(Vector3.UP)
		fw = fw.normalized()
		var ri: Vector3 = (-t).cross(fw).normalized()
		var ro := []
		for i in seg:
			var q: float = TAU * i / seg - PI
			ro.append((pts[j] as Vector3) + (ri * sin(q) + fw * cos(q)) * r)
		rows.append(ro)
	k.grid(rows, true, func(i, _j, _p): return col.darkened(0.18) if i % 3 == 0 else col, func(_i, _j, p): return skinf.call(p))


static func _knot(k, c: Vector3, w: float, r: float, col: Color, bone := "Hips") -> void:
	k.tube([c + Vector3(-w, 0.008, 0), c + Vector3(w, -0.008, 0)], [bone], [[0.0, r * 0.62], [0.5, r], [1.0, r * 0.62]], func(_t, a, _i): return col.darkened(0.14 if sin(a * 3.0) < -0.2 else 0.0), 8, 12, false)


# ------------------------------------------------------------------ hakama / geniş paça
## İki ayrı geniş paça. o: prof(s) -> ek yarıçap, s1, pl (pli sayısı), amp, top (bel üstü), col, seg, n
static func _wide(k, b: Dictionary, l: Dictionary, o: Dictionary) -> void:
	var sg: float = l["sg"]
	var kn: float = l["kn"]
	var hp: Vector3 = b["hp"]
	var H: float = k.H
	var s1: float = o.get("s1", 1.0)
	var top: float = H + float(o.get("top", 0.1))
	var prof: Callable = o["prof"]
	var pl: float = o.get("pl", 9.0)
	var amp: float = o.get("amp", 0.05)
	var col: Color = o["col"]
	var seg: int = o.get("seg", 54)
	var n: int = o.get("n", 34)
	var pad: float = o.get("pad", 0.016)
	var cmax: float = o.get("cmax", 0.72)
	var p0: Vector3 = l["p0"]
	var st := []
	for j in 5:   # bel üstünden uyluk köküne
		st.append([lerpf(top, p0.y, float(j) / 5.0), 0.0, 0.0])
	for j in n + 1:
		var s: float = s1 * float(j) / n
		st.append([0.0, s, 0.0])
	st.append([0.0, s1, -0.005])
	for j in 3:
		st.append([0.0, s1 - 0.05 * float(j), -0.01])
	var ni: int = n + 6
	var rows := []
	var cc := []
	var sk := []
	var tx: float = hp.x * 0.56 + pad
	var cx0: float = sg * (hp.x * 0.44 + pad * 0.3)
	var zf: float = hp.y + pad
	var zb: float = absf(hp.z) + pad + 0.015
	var wa: Vector3 = b["wa"]
	for ji in st.size():
		var e: Array = st[ji]
		var s: float = e[1]
		var base: Vector3 = _lp(l, s) if float(e[0]) == 0.0 else Vector3(p0.x, e[0], p0.z)
		var tl: float = smoothstep(0.0, 0.32, s) if float(e[0]) == 0.0 else 0.0
		var R: float = _lr(l, s) + float(prof.call(s)) + float(e[2])
		var wt: float = 1.0 - smoothstep(H - 0.04, top - 0.01, base.y) if float(e[0]) != 0.0 else 1.0
		var tx2: float = lerpf(wa.x * 0.56 + pad, tx, wt)
		var cx2: float = lerpf(sg * (wa.x * 0.44 + pad * 0.3), cx0, wt)
		var cen := Vector3(lerpf(cx2, base.x, tl), base.y, lerpf(0.0, base.z, tl))
		var rx: float = lerpf(tx2, R, tl)
		var rf: float = lerpf(lerpf(wa.y + pad, zf, wt), R, tl)
		var rb: float = lerpf(lerpf(absf(wa.z) + pad, zb, wt), R * 1.06, tl)
		var ampv: float = amp * lerpf(0.3, 1.0, smoothstep(0.0, 0.5, s))
		var ro := []
		var cr := []
		var sr := []
		var w: float = smoothstep(0.02, 0.26, s) if float(e[0]) == 0.0 else 0.0
		var c: float = smoothstep(kn - 0.05, kn + 0.3, s) * cmax
		var bo: Array = l["bo"]
		for i in seg:
			var a: float = TAU * i / seg - PI
			var inn: float = smoothstep(0.0, 0.6, -sg * sin(a)) * (1.0 - smoothstep(0.22, 0.55, s))   # iç yüz kalçada kalır: paçalar açılınca ağda delik olmaz
			var w2: float = w * (1.0 - 0.7 * inn)
			sr.append([["Hips", 1.0 - w2], [bo[0], w2 * (1.0 - c)], [bo[1], w2 * c]])
			var saw: float = fposmod(a * pl / TAU + 0.15, 1.0)
			var f: float = ampv * (smoothstep(0.0, 0.16, saw) - smoothstep(0.16, 1.0, saw) - 0.2)
			var q: Vector2 = SE.El.sup(a, rx, rf, -rb, 2.2)
			ro.append(cen + Vector3(q.x * (1.0 + f), 0.0, q.y * (1.0 + f)))
			var c0: Color = col.darkened(clampf(-f / amp * 0.3, 0.0, 0.3)).lightened(clampf(f / amp * 0.08, 0.0, 0.08))
			cr.append(c0.darkened(0.42) if ji > ni - 1 else c0)
		rows.append(ro)
		cc.append(cr)
		sk.append(sr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(i, j, _p): return sk[j][i])


## İki paça arasını kapatan ağ parçası: koşarken paçalar açılınca içi görünmez
static func _seat(k, b: Dictionary, col: Color) -> void:
	var hp: Vector3 = b["hp"]
	var H: float = k.H
	SE.body_layer(k, [[H + 0.02, hp.x + 0.005, hp.y + 0.005, hp.z - 0.005], [H - 0.1, hp.x * 0.9, hp.y * 0.92, hp.z * 0.95], [H - 0.2, hp.x * 0.5, hp.y * 0.6, hp.z * 0.6], [H - 0.235, 0.02, 0.02, -0.02]], 12, 28, func(_i, _j, _p): return col.darkened(0.08))


# ------------------------------------------------------------------ zırh plakası
## Kalınlığı olan plaka. pf(u, v) -> taban noktası, nf(u, v) -> dış yön, colf(u, v, kenar) -> renk, skinf(u, v, p)
static func _shell(k, pf: Callable, nf: Callable, nu: int, nv: int, th: float, colf: Callable, skinf: Callable) -> void:
	var prof := [[0.0, 0.0]]
	for j in nv + 1:
		prof.append([float(j) / nv, 1.0])
	prof.append([1.0, 0.0])
	prof.append([0.0, 0.0])
	var rows := []
	for e in prof:
		var ro := []
		for i in nu + 1:
			var u: float = float(i) / nu
			var ed: float = smoothstep(0.0, 0.07, minf(u, 1.0 - u))
			ro.append((pf.call(u, e[0]) as Vector3) + (nf.call(u, e[0]) as Vector3) * th * float(e[1]) * ed)
		rows.append(ro)
	var a0: Vector3 = rows[1][nu / 2]
	var fn: Vector3 = -((rows[1][nu / 2 + 1] as Vector3) - a0).cross((rows[2][nu / 2 + 1] as Vector3) - a0)
	var flip: bool = fn.dot(nf.call(0.5, 0.0)) < 0.0
	if flip:
		for ro in rows:
			ro.reverse()
	k.grid(rows, false, func(i, j, _p):
		var u: float = float(nu - i if flip else i) / nu
		return colf.call(u, prof[j][0], float(prof[j][1]) == 0.0 or u < 0.05 or u > 0.95), func(i, j, p):
		return skinf.call(float(nu - i if flip else i) / nu, prof[j][0], p))


## Kalçadan sarkan plaka paneli (kusazuri): lames üst üste binen sıra. o: y0, ac, aw, n, h, ov, flare, add, col, trim, lace, th
static func _tasset(k, b: Dictionary, o: Dictionary) -> void:
	var hp: Vector3 = b["hp"]
	var y0: float = o["y0"]
	var ac: float = o["ac"]
	var aw: float = o["aw"]
	var n: int = o["n"]
	var h: float = o["h"]
	var ov: float = o.get("ov", 0.014)
	var flare: float = o.get("flare", 0.3)
	var add: float = o.get("add", 0.04)
	var col: Color = o["col"]
	var trim: Color = o.get("trim", col.darkened(0.3))
	var lace: Color = o.get("lace", col.darkened(0.45))
	var th: float = o.get("th", 0.007)
	var cb: float = o.get("cord_below", 99.0)
	var total: float = n * (h - ov) + ov
	var W: float = hp.x + add
	var F: float = hp.y + add
	var B: float = absf(hp.z) + add
	var sn: float = sin(ac)
	var gain: float = 0.86 if cos(ac) > 0.2 else 0.72   # her panel tek bacağı izler: kalkan uyluk plakayı delmez
	var lb: String = "LeftUpperLeg" if sn > 0.0 else "RightUpperLeg"
	var fh: float = o.get("follow", -99.0)   # üstlüğün altında kalan üst kısım üstlükle aynı gider, eteğinden dışarı çıkmaz
	var H: float = k.H
	var skf := func(p: Vector3) -> Array:
		var t: float = clampf((y0 - p.y) / total, 0.0, 1.0)
		var w: float = gain * smoothstep(0.0, 0.85, t)
		if fh < -9.0:
			return [["Hips", 1.0 - w], [lb, w]]
		var a: float = _lg(p.z) * clampf((H - p.y) / maxf(0.05, H - fh), 0.0, 1.0)
		var sx: float = smoothstep(-0.12, 0.12, p.x)
		var m: float = smoothstep(fh + 0.01, fh - 0.11, p.y)
		var wl: float = lerpf(a * sx, w if lb == "LeftUpperLeg" else 0.0, m)
		var wr: float = lerpf(a * (1.0 - sx), w if lb == "RightUpperLeg" else 0.0, m)
		return [["Hips", 1.0 - wl - wr], ["LeftUpperLeg", wl], ["RightUpperLeg", wr]]
	var pt := func(a: float, y: float, off: float) -> Vector3:
		var t: float = (y0 - y) / total
		var q: Vector2 = SE.El.sup(a, W, F, -B, 2.3)
		var sc: float = 1.0 + flare * t
		return Vector3(q.x * sc, y, q.y * sc) + Vector3(q.x, 0.0, q.y).normalized() * off
	for i in n:
		var yt: float = y0 - i * (h - ov)
		var yb: float = yt - h
		var pf := func(u: float, v: float) -> Vector3:
			return pt.call(ac + aw * (2.0 * u - 1.0), lerpf(yt, yb, v), lerpf(-0.004, 0.009, v) + 0.0035 * i)
		var nf := func(u: float, _v: float) -> Vector3:
			var q: Vector2 = SE.El.sup(ac + aw * (2.0 * u - 1.0), W, F, -B, 2.3)
			return Vector3(q.x, 0.12, q.y).normalized()
		var last: bool = i == n - 1
		_shell(k, pf, nf, 16, 5, th, func(_u, v, e):
			if last and v > 0.86:
				return trim
			return col.darkened(0.22) if e else col.darkened(0.08 * v), func(_u, _v, p): return skf.call(p))
		if not last and yb < cb:
			for u in [0.2, 0.8]:
				var a: float = ac + aw * (2.0 * float(u) - 1.0)
				for dx in [-0.012, 0.012]:
					var a2: float = a + float(dx) / maxf(0.08, W)
					_cord(k, [pt.call(a2, yb + 0.016, th + 0.009 + 0.0035 * i), pt.call(a2, yb - 0.004, th + 0.012 + 0.0035 * i), pt.call(a2, yb - 0.024, th + 0.006 + 0.0035 * (i + 1))], 0.0032, lace, skf, 5)


## Kol üstü sarkan omuz plakası (sode). o: s0, n, ln, ov, W, R, curve, col, trim, lace, th
static func _sode(k, l: Dictionary, o: Dictionary) -> void:
	var sd: String = l["sd"]
	var s0: float = float(o["s0"]) + float(l["sj"])
	var n: int = o["n"]
	var ln: float = o["ln"]
	var ov: float = o.get("ov", 0.018)
	var W: float = o["W"]
	var R: float = o["R"]
	var curve: float = o.get("curve", 3.0)
	var col: Color = o["col"]
	var trim: Color = o.get("trim", col.darkened(0.3))
	var lace: Color = o.get("lace", col.darkened(0.45))
	var th: float = o.get("th", 0.008)
	var ovec: Vector3 = _ov(l)
	var kn: float = l["kn"]
	var L: float = ((l["p1"] as Vector3) - (l["p0"] as Vector3)).length()
	var ds: float = (ln / L) * float(kn)
	var dov: float = (ov / L) * float(kn)
	var fr := func(s: float) -> Array:
		var d: Vector3 = _ld(l, s)
		var oo: Vector3 = (ovec - d * d.dot(ovec)).normalized()
		return [_lp(l, s), oo, d.cross(oo).normalized()]
	var skf := func(p: Vector3) -> Array:
		var t: float = clampf((p - _lp(l, s0)).length() / maxf(0.05, ln * n), 0.0, 1.0)
		var w: float = lerpf(0.4, 0.72, smoothstep(0.1, 0.6, t))
		return [["UpperChest", 1.0 - w], [sd + "UpperArm", w]]
	for i in n:
		var st: float = s0 + i * (ds - dov)
		var en: float = st + ds
		var wi: float = W * (1.0 + 0.05 * i)
		var ra: float = R + 0.005 * i
		var pf := func(u: float, v: float) -> Vector3:
			var f: Array = fr.call(lerpf(st, en, v))
			var x: float = (2.0 * u - 1.0) * wi
			return (f[0] as Vector3) + (f[1] as Vector3) * (ra + lerpf(-0.003, 0.009, v) - curve * x * x) + (f[2] as Vector3) * x
		var nf := func(u: float, v: float) -> Vector3:
			var f: Array = fr.call(lerpf(st, en, v))
			var x: float = (2.0 * u - 1.0) * wi
			return ((f[1] as Vector3) + (f[2] as Vector3) * (2.0 * curve * x)).normalized()
		var last: bool = i == n - 1
		_shell(k, pf, nf, 14, 5, th, func(_u, v, e):
			if last and v > 0.86:
				return trim
			return col.darkened(0.22) if e else col.darkened(0.07 * v), func(_u, _v, p): return skf.call(p))
		if not last:
			for ux in [-0.62, 0.62]:
				var a: Vector3 = pf.call(0.5 + float(ux) * 0.5, 0.86) + (nf.call(0.5, 0.86) as Vector3) * (th + 0.003)
				var c: Vector3 = pf.call(0.5 + float(ux) * 0.5, 1.0) + (nf.call(0.5, 1.0) as Vector3) * (th + 0.006)
				var f2: Array = fr.call(en - dov * 0.2 + ds * 0.08)
				var e2: Vector3 = (f2[0] as Vector3) + (f2[1] as Vector3) * (ra + 0.005 + th + 0.004 - curve * pow(float(ux) * wi, 2.0)) + (f2[2] as Vector3) * (float(ux) * wi)
				_cord(k, [a, c, e2], 0.0034, lace, skf, 5)


## Uzuv boyunca kavisli plaka (kolluk çubuğu, tozluk, dizlik, cep). ac: merkez açı, aw: yarı açı
static func _splint(k, l: Dictionary, s0: float, s1: float, ac: float, aw: float, add: float, th: float, col: Color, trim: Color, nv := 6, tip := 0.0) -> void:
	var ovec: Vector3 = _ov(l)
	var fr := func(s: float, u: float) -> Array:
		var d: Vector3 = _ld(l, s)
		var oo: Vector3 = (ovec - d * d.dot(ovec)).normalized()
		var tv: Vector3 = d.cross(oo).normalized()
		var w: float = aw * lerpf(1.0, 1.0 - tip, smoothstep(0.0, 1.0, inverse_lerp(s0, s1, s)))
		var a: float = ac + w * (2.0 * u - 1.0)
		return [_lp(l, s), oo * cos(a) + tv * sin(a)]
	var ls: float = (s0 + s1) * 0.5
	var sk0: Array = _lskin(l, ls)
	_shell(k, func(u: float, v: float) -> Vector3:
		var s: float = lerpf(s0, s1, v)
		var f: Array = fr.call(s, u)
		return (f[0] as Vector3) + (f[1] as Vector3) * (_lr(l, s) + add), func(u: float, v: float) -> Vector3:
		return fr.call(lerpf(s0, s1, v), u)[1], 8, nv, th, func(_u, v, e):
		return trim if e or v < 0.05 or v > 0.95 else col, func(_u, v, _p):
		return _lskin(l, lerpf(s0, s1, v)) if s1 - s0 > 0.25 else sk0)


## Gövde üzerinde parça plaka. ac, aw açı; y0-y1; add kaldırma
static func _torso_plate(k, keys: Array, ac: float, aw: float, y0: float, y1: float, add: float, th: float, col: Color, trim: Color, nu := 26, nv := 8, topf := Callable()) -> void:
	_shell(k, func(u: float, v: float) -> Vector3:
		var a: float = ac + aw * (2.0 * u - 1.0)
		var yt: float = float(topf.call(a)) if topf.is_valid() else y0
		return _sa(keys, a, lerpf(yt, y1, v), add)[0], func(u: float, v: float) -> Vector3:
		var a: float = ac + aw * (2.0 * u - 1.0)
		return _sa(keys, a, lerpf(y0, y1, v))[1], nu, nv, th, func(_u, v, e):
		return trim if e or v < 0.05 or v > 0.93 else col.darkened(0.06 * v), func(_u, _v, p): return k.torso_skin(p.y))


## Omuz üstünden geçen kayış: (x, y_ön) -> sırt
static func _over(k, keys: Array, a_f: float, y_f: float, a_b: float, y_b: float, hw: float, lift: float, d: float, col: Color) -> void:
	var ytop: float = float(keys[0][0]) - 0.012
	var pts := []
	var ou := []
	var n := 14
	for j in n + 1:
		var e: Array = _sa(keys, a_f, lerpf(y_f, ytop, float(j) / n), lift)
		pts.append(e[0])
		ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.55, 1.0, float(j) / n)).normalized())
	for j in range(n, -1, -1):
		var e: Array = _sa(keys, a_b, lerpf(y_b, ytop, float(j) / n), lift)
		pts.append(e[0])
		ou.append((e[1] as Vector3).lerp(Vector3.UP, smoothstep(0.55, 1.0, float(j) / n)).normalized())
	k.strip(pts, ou, hw, d, col)


## Yüzey üstünde (açı, y) yolu boyunca kayış
static func _rail(k, keys: Array, ctrl: Array, hw: float, lift: float, d: float, col: Color, steps := 6) -> void:
	var pts := []
	var ou := []
	for s in ctrl.size() - 1:
		for t in steps + (1 if s == ctrl.size() - 2 else 0):
			var q: Vector2 = (ctrl[s] as Vector2).lerp(ctrl[s + 1], float(t) / steps)
			var e: Array = _sa(keys, q.x, q.y, lift)
			pts.append(e[0])
			ou.append(e[1])
	k.strip(pts, ou, hw, d, col, false, func(p): return _hs(k, p))


static func _box(k, c: Vector3, ux: Vector3, uy: Vector3, uz: Vector3, col: Color, bones: Array, round_c := 0.3) -> void:
	var seg := 16
	var ring := func(h: float, sc: float) -> Array:
		var ro := []
		for i in seg:
			var a: float = TAU * i / seg - PI
			var sx: float = signf(sin(a)) * pow(absf(sin(a)), 0.45)
			var sz: float = signf(cos(a)) * pow(absf(cos(a)), 0.45)
			ro.append(c + uy * h + ux * sx * sc + uz * sz * sc)
		return ro
	var rows := [ring.call(1.0, 0.001), ring.call(1.0, 1.0 - round_c), ring.call(1.0 - round_c * 0.45, 1.0), ring.call(-1.0 + round_c * 0.45, 1.0), ring.call(-1.0, 1.0 - round_c), ring.call(-1.0, 0.001)]
	k.grid(rows, true, func(_i, j, _p): return col.lightened(0.05) if j <= 1 else (col.darkened(0.14) if j >= 4 else col), func(_i, _j, _p): return bones)


## Ayak bileği altlığı: paçanın içi boş görünmesin
static func _ankle(k, b: Dictionary, col: Color, s0 := 0.78) -> void:
	for lk in ["lL", "lR"]:
		_lt(k, b[lk], func(_s, _a): return 0.002, func(_s, _a, _i): return col, s0, 1.0, 8, 14)


# ------------------------------------------------------------------ Kenpō Dōgi: beyaz gi, siyah kuşak, bol paça, sargılı önkol
static func _kenpo(k) -> void:
	var b := _base(k)
	var wh := Color(0.93, 0.92, 0.88)
	var sh := Color(0.8, 0.79, 0.75)
	var blk := Color(0.13, 0.13, 0.15)
	var wrap := Color(0.88, 0.85, 0.78)
	var H: float = k.H
	_inner(k, b, func(_i, _j, _p): return sh)
	_ankle(k, b, Color(0.74, 0.72, 0.68))
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var rip := func(s: float, a: float) -> float:
			var bag: float = smoothstep(0.1, 0.5, s) * (1.0 - 0.25 * smoothstep(0.75, 1.0, s))
			return bag * (0.0045 * sin(a * 4.0 + s * 22.0 + float(l["sg"])) + 0.0035 * sin(a * 7.0 - s * 31.0)) + 0.009 * exp(-pow((s - kn) / 0.07, 2.0)) * sin(a * 4.0 + s * 30.0)
		_lt(k, l, func(s, a): return 0.018 + 0.034 * smoothstep(0.05, 0.5, s) + 0.012 * smoothstep(0.6, 1.0, s) + float(rip.call(s, a)), func(s, a, ins):
			return wh.darkened(0.4) if ins else _fs(wh, float(rip.call(s, a)), 7.0), 0.0, 0.985, 40, 26, 0.09)
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var rip := func(s: float, a: float) -> float:
			return 0.006 * sin(a * 3.0 + s * 18.0) + 0.009 * exp(-pow((s - kn) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		_lt(k, l, func(_s, _a): return 0.0, func(_s, _a, _i): return wrap.darkened(0.14), 0.45, 1.0, 12, 14)
		_lt(k, l, func(s, a): return 0.002 + 0.01 * smoothstep(0.0, 0.2, s) + 0.024 * smoothstep(0.2, 0.68, s) + float(rip.call(s, a)), func(s, a, ins):
			return wh.darkened(0.4) if ins else _fs(wh, float(rip.call(s, a)), 16.0), 0.0, 0.68, 26, 22, 0.08)
		_wraps(k, l, 0.72, 1.0, 13, 0.0045, 0.0125, wrap, 0.004)
	var hem: float = H - 0.2
	var keys := _tk(k, b, 0.012, hem, 0.05)
	var fold := func(a: float, y: float, _v: float) -> float:
		if y < H:
			var t: float = clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
			return (1.0 - t) * 0.032 * sin(a * 15.0 + 0.4) + t * 0.03 * sin(a * 7.0 + 0.9)
		var s: float = clampf((y - H) / (k.N - H), 0.0, 1.0)
		return (1.0 - s) * (0.022 * sin(a * 10.0 + y * 8.0)) + s * 0.008 * sin(a * 4.0 - y * 22.0)
	var res := _wrap_top(k, keys, fold, func(_a, _y, v): return wh.darkened(0.2) if v > 0.965 else wh)
	_eri(k, res, 34, 0.023, 0.006, wh.lightened(0.15), sh.darkened(0.08))
	_sash(k, keys, H + 0.045, 0.024, 0.012, blk, 0.3, 2)
	var s0: Array = SE.El.key_at(keys, H + 0.045)
	var zf: float = float(s0[2]) + 0.024
	_knot(k, Vector3(0.012, H + 0.045, zf), 0.034, 0.024, blk)
	_tail(k, keys, 0.018, 0.055, H + 0.03, 0.21, 0.02, 0.018, blk)
	_tail(k, keys, -0.008, -0.05, H + 0.03, 0.19, 0.02, 0.012, blk.lightened(0.05))
	_rail(k, keys, [Vector2(PI, H + 0.08), Vector2(PI, k.N - 0.05)], 0.0022, 0.002, 0.0012, sh)


# ------------------------------------------------------------------ Kenshi Shōzoku: lacivert kimono, bej yaka ve obi, pli hakama, metal kolluk
static func _kenshi(k) -> void:
	var b := _base(k)
	var nv := Color(0.2, 0.24, 0.36)
	var be := Color(0.75, 0.7, 0.6)
	var hk := Color(0.16, 0.16, 0.2)
	var st := Color(0.56, 0.57, 0.61)
	var H: float = k.H
	_inner(k, b, func(_i, _j, p): return be.lightened(0.12) if p.y > H + 0.04 else hk.darkened(0.2))
	_ankle(k, b, hk.darkened(0.2))
	_seat(k, b, hk)
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		_lt(k, l, func(_s, _a): return 0.003, func(_s, _a, _i): return hk.lightened(0.05), 0.42, 1.0, 14, 16)
		# geniş kimono kolu: dirsek altında biter
		var rip := func(s: float, a: float) -> float: return 0.008 * sin(a * 4.0 + s * 15.0) + 0.006 * sin(a * 7.0 - s * 21.0)
		_lt(k, l, func(s, a): return 0.002 + 0.01 * smoothstep(0.0, 0.2, s) + 0.028 * smoothstep(0.25, 0.7, s) + float(rip.call(s, a)), func(s, a, ins):
			return be.darkened(0.25) if ins else _fs(nv, float(rip.call(s, a)), 14.0), 0.0, 0.7, 28, 26, 0.12)
		# kolluk: üç çubuk + bilek plakası, iki bağ
		for ai in [-0.62, 0.0, 0.62]:
			_splint(k, l, 0.74, 0.965, float(ai), 0.25, 0.008, 0.0055, st, st.darkened(0.3), 5)
		_splint(k, l, 0.945, 1.0, 0.0, 0.95, 0.009, 0.005, st.lightened(0.05), st.darkened(0.3), 2)
		for s in [0.78, 0.925]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.0095, 0.0055, 0.0, be.darkened(0.2), _lskin(l, s))
	for lk in ["lL", "lR"]:
		_wide(k, b, b[lk], {"col": hk, "prof": func(s): return 0.03 + 0.1 * smoothstep(0.1, 1.0, s), "pl": 9.0, "amp": 0.05, "s1": 0.995, "top": 0.06, "pad": 0.03})
	var hem: float = H + 0.05
	var keys := _tk(k, b, 0.012, hem)
	var fold := func(a: float, y: float, _v: float) -> float:
		var s: float = clampf((y - H) / (k.N - H), 0.0, 1.0)
		return (1.0 - s) * (0.024 * sin(a * 11.0 + y * 9.0) + 0.01 * sin(a * 19.0 - y * 21.0)) + s * 0.008 * sin(a * 4.0 - y * 24.0)
	var res := _wrap_top(k, keys, fold, func(_a, _y, _v): return nv, 34, 92, 0.55, hem)
	_eri(k, res, 30, 0.021, 0.006, be, be.darkened(0.2))
	# hakama beli: koshi-ita (arka sert levha), obi ve kordonlar
	_sash(k, keys, H + 0.075, 0.03, 0.016, be, 0.14, 2)
	var hkk := _tk(k, b, 0.03, H - 0.04, 0.0, 0.0)
	for side in [1.0, -1.0]:
		for off in [0.0, 0.022]:
			var pts := []
			var ou := []
			for i in 15:
				var t: float = float(i) / 14.0
				var a: float = side * lerpf(0.05, 2.75, t)
				var e: Array = _sa(hkk, a, H + 0.022 - float(off) + 0.02 * sin(t * PI) - 0.018 * t, 0.012)
				pts.append(e[0])
				ou.append(e[1])
			k.strip(pts, ou, 0.0065, 0.0035, hk.lightened(0.14))
	_torso_plate(k, hkk, PI, 0.5, H + 0.105, H - 0.015, 0.018, 0.009, hk.lightened(0.05), hk.lightened(0.17), 14, 4)
	var zf: float = float(SE.El.key_at(hkk, H + 0.02)[2]) + 0.03
	_knot(k, Vector3(0.0, H + 0.022, zf), 0.03, 0.017, hk.lightened(0.14))
	for sg in [1.0, -1.0]:
		var pts := []
		var ou := []
		for i in 7:
			var t: float = float(i) / 6.0
			pts.append(Vector3(sg * (0.008 + 0.03 * t), H + 0.012 - 0.095 * t, zf + 0.004 - 0.008 * t))
			ou.append(Vector3(0, 0, 1))
		k.strip(pts, ou, 0.0065, 0.003, hk.lightened(0.14), false, func(p): return [["Hips", 1.0]])


# ------------------------------------------------------------------ Jōki Yoroi (Han): şişkin kızıl dilimli kollar, gri üstlük, kızıl plakalı etek, sargılı paça, kalın eldiven
static func _joki(k) -> void:
	var b := _base(k)
	var red := Color(0.5, 0.13, 0.16)
	var rd2 := Color(0.36, 0.09, 0.12)
	var ol := Color(0.31, 0.32, 0.27)
	var ol2 := Color(0.22, 0.23, 0.2)
	var blk := Color(0.13, 0.13, 0.13)
	var gold := Color(0.62, 0.5, 0.26)
	var H: float = k.H
	var N: float = k.N
	var C: float = k.C
	# kızıl dilimli göğüslük: yatay kaburgalar + perçinli dik yaka
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var ik := [_kp(nk, N + 0.05, 0.02), _kp(nk, N + 0.012, 0.024), [N - 0.05, ch.x * 0.86, ch.y * 0.84, ch.z * 0.92], _kp(ch, C - 0.03, 0.014), _kp(b["wa"], H + 0.12, 0.014), _kp(b["hp"], H - 0.1, 0.012)]
	var rib := func(y: float) -> float: return 0.5 + 0.5 * cos(y * TAU / 0.031)
	SE.body_layer(k, ik, 64, 48, func(_i, _j, p):
		if p.y > N - 0.004:
			return rd2.lightened(0.05)
		return red.darkened((1.0 - pow(float(rib.call(p.y)), 0.6)) * 0.5), func(_a, y):
		return 0.016 * pow(float(rib.call(y)), 0.6) if y < N - 0.012 else 0.0)
	for i in 12:
		var a: float = TAU * i / 12.0 - PI
		var e: Array = _sa(ik, a, N + 0.03, 0.002)
		_box(k, e[0], Vector3(0.0048, 0, 0), Vector3(0, 0.0048, 0), (e[1] as Vector3) * 0.0035, gold, [["Neck", 1.0]], 0.5)
	# şişkin dilimli kollar, koyu kalın eldiven
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var seg := func(s: float) -> float: return absf(sin(s / 0.72 * PI * 6.0))
		var add := func(s: float, a: float) -> float:
			var f: float = smoothstep(0.0, 0.05, s) * (1.0 - smoothstep(0.68, 0.74, s))
			return f * (0.012 + 0.034 * pow(float(seg.call(s)), 0.55) + 0.0028 * cos(a * 18.0))
		_lt(k, l, add, func(s, a, ins):
			if ins:
				return rd2.darkened(0.3)
			return red.darkened((1.0 - pow(float(seg.call(s)), 0.5)) * 0.55 + (0.12 if cos(a * 18.0) < -0.5 else 0.0)), 0.0, 0.73, 76, 36, 0.04)
		_lt(k, l, func(s, a): return 0.012 + 0.016 * smoothstep(0.86, 0.68, s) + 0.002 * sin(a * 3.0 + s * 20.0), func(s, _a, ins):
			return blk.darkened(0.4) if ins else (blk.lightened(0.09) if s < 0.7 else blk), 0.66, 1.0, 14, 20, 0.03)
	# paça: gri, baldırda toplanır; ip sargı
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var rip := func(s: float, a: float) -> float: return smoothstep(0.1, 0.5, s) * (1.0 - smoothstep(0.7, 0.8, s)) * (0.0055 * sin(a * 4.0 + s * 22.0 + float(l["sg"])) + 0.004 * sin(a * 7.0 - s * 31.0))
		_lt(k, l, func(s, a): return 0.008 + 0.054 * smoothstep(0.22, kn + 0.04, s) * (1.0 - smoothstep(0.68, 0.84, s)) + float(rip.call(s, a)), func(s, a, ins):
			return ol2.darkened(0.4) if ins else _fs(ol, float(rip.call(s, a)), 13.0), 0.0, 1.0, 40, 24)
		_wraps(k, l, 0.76, 0.97, 8, 0.024, 0.0105, ol2.lightened(0.05), 0.007)
		_wraps(k, l, 0.72, 0.965, 3, 0.031, 0.0048, gold.darkened(0.25), 0.012)
	# plakalı etek: dört geniş panel, ince üst üste plakalar
	for e in [[0.41, 0.42], [-0.41, 0.42], [PI * 0.5, 0.76], [-PI * 0.5, 0.76], [PI - 0.41, 0.42], [-PI + 0.41, 0.42]]:
		_tasset(k, b, {"y0": H - 0.06, "ac": e[0], "aw": e[1], "n": 7, "h": 0.054, "ov": 0.013, "flare": 0.3, "add": 0.03, "cord_below": H - 0.2, "follow": H - 0.15, "col": red, "trim": rd2, "lace": rd2.darkened(0.3), "th": 0.006})
	# gri üstlük: kolsuz, uyluğa inen
	var hem: float = H - 0.15
	var keys := _tk(k, b, 0.03, hem, 0.022)
	var fold := func(a: float, y: float, _v: float) -> float:
		if y < H + 0.03:
			return 0.022 * sin(a * 9.0 + 0.7) + 0.014 * sin(a * 15.0 + 1.3)
		var s: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return (1.0 - s) * 0.024 * sin(a * 8.0 + y * 8.0) + s * 0.01 * sin(a * 5.0 - y * 18.0)
	var res := _wrap_top(k, keys, fold, func(_a, _y, v): return ol2 if v > 0.97 else ol, 40, 92, 0.52)
	_eri(k, res, 30, 0.024, 0.006, ol2, ol.darkened(0.2))
	_sash(k, keys, H + 0.05, 0.036, 0.012, blk.lightened(0.05), 0.28, 2)
	# yırtık omuz kenarı: üstlük omzunda düzensiz dilimler (kumaşa oturur)
	for sg in [1.0, -1.0]:
		for i in 5:
			var a: float = sg * lerpf(1.05, 2.05, float(i) / 4.0)
			var e: Array = _sa(keys, a, N - 0.075 - 0.008 * float(i % 2), 0.006)
			var p: Vector3 = e[0]
			var o: Vector3 = e[1]
			k.strip([p + Vector3(0, 0.022, 0), p, p + Vector3(0, -0.03 - 0.012 * float(i % 3), 0) + o * 0.006], [o, o, o], 0.015 - 0.0015 * float(i % 2), 0.003, ol.darkened(0.1 + 0.05 * float(i % 2)))


# ------------------------------------------------------------------ Samurai Yoroi (Demir Ülkesi, Mifune): zincir örgü, koca kare omuz plakaları, geniş kalça plakaları, toplu hakama, zırhlı tozluk
static func _samurai(k) -> void:
	var b := _base(k)
	var mail := Color(0.34, 0.35, 0.37)
	var gi := Color(0.28, 0.29, 0.31)
	var dk := Color(0.1, 0.1, 0.12)
	var hk := Color(0.2, 0.22, 0.3)
	var ar := Color(0.27, 0.3, 0.38)
	var red := Color(0.5, 0.1, 0.12)
	var wh := Color(0.86, 0.84, 0.78)
	var H: float = k.H
	_seat(k, b, hk)
	# zincir örgü: gerçek kabartma, vadide koyulaşır
	var mf := func(u: float, v: float) -> float: return sin(u) * sin(v)
	var ik := _tk(k, b, -0.002, H - 0.09, 0.0, 0.0)
	SE.body_layer(k, [[k.N + 0.06, float(b["nk"].x) + 0.012, float(b["nk"].y) + 0.012, float(b["nk"].z) - 0.012]] + ik.slice(1), 60, 104, func(_i, _j, p):
		var a: float = atan2(p.x, p.z)
		return dk.lightened(0.12).darkened(0.32 * maxf(0.0, -float(mf.call(a * 42.0, p.y * 270.0)))), func(a, y):
		return 0.012 * float(mf.call(a * 42.0, y * 270.0)))
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		_lt(k, l, func(s, a): return 0.006 + 0.0028 * float(mf.call(a * 13.0, s * 170.0)), func(s, a, ins):
			return dk if ins else mail.darkened(0.42 * maxf(0.0, -float(mf.call(a * 13.0, s * 170.0)))).lightened(0.1 * maxf(0.0, float(mf.call(a * 13.0, s * 170.0)))), 0.25, 0.98, 74, 40)
		var rip := func(s: float, a: float) -> float: return 0.007 * sin(a * 4.0 + s * 18.0)
		_lt(k, l, func(s, a): return 0.018 + 0.03 * smoothstep(0.1, 0.46, s) + float(rip.call(s, a)), func(s, a, ins):
			return wh.darkened(0.35) if ins else _fs(gi, float(rip.call(s, a)), 14.0), 0.0, 0.46, 18, 24, 0.07)
		_splint(k, l, 0.62, 0.95, 0.0, 0.68, 0.009, 0.0055, ar, red, 5, 0.25)
		for s in [0.68, 0.9]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.012, 0.005, 0.0, red, _lskin(l, s))
		_sode(k, l, {"s0": 0.0, "n": 3, "ln": 0.125, "W": 0.112, "R": 0.082, "curve": 1.15, "col": ar, "trim": red, "lace": red, "th": 0.009})
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		_wide(k, b, l, {"col": hk, "prof": func(s): return 0.025 + 0.078 * smoothstep(0.05, kn, s) * (1.0 - smoothstep(kn + 0.08, 0.72, s)) + 0.012 * (1.0 - smoothstep(0.66, 0.72, s)), "pl": 6.0, "amp": 0.032, "s1": 0.73, "top": 0.05, "seg": 44, "n": 30, "cmax": 0.82, "pad": 0.03})
		_lt(k, l, func(_s, _a): return 0.006, func(_s, _a, _i): return wh, 0.62, 1.0, 14, 16)
		# zırhlı tozluk: üç dikey plaka, üst ve alt bağ
		for ai in [-0.8, 0.0, 0.8]:
			_splint(k, l, 0.7, 0.965, float(ai), 0.41, 0.012, 0.0065, ar, ar.darkened(0.32), 5)
		for s in [0.745, 0.925]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.0145, 0.0055, 0.0, red, _lskin(l, s))
	var hem: float = H + 0.045
	var keys := _tk(k, b, 0.014, hem)
	var fold := func(a: float, y: float, _v: float) -> float:
		var s: float = clampf((y - H) / (k.N - H), 0.0, 1.0)
		return (1.0 - s) * 0.022 * sin(a * 10.0 + y * 8.0) + s * 0.008 * sin(a * 4.0 - y * 22.0)
	# V açıklıktan zincir görünür; kısa kollu üst
	var res := _cl(k, {"keys": keys, "top": func(_a): return float(keys[0][0]), "hem": func(_a): return hem, "ny": 34, "na": 88, "over": 0.04, "fold": fold, "col": func(_a, _y, _v): return gi,
		"rng": func(v: float) -> Vector2:
			var y: float = lerpf(float(keys[0][0]), hem, v)
			var e: float = lerpf(-0.3, 0.42, clampf((y - (H + 0.04)) / (k.N - (H + 0.04)), 0.0, 1.0))
			return Vector2(e, TAU - e * 0.82)})
	_eri(k, res, 28, 0.017, 0.006, dk.lightened(0.05), gi)
	_sash(k, keys, H + 0.06, 0.036, 0.012, wh, 0.16, 2)
	var zf: float = float(SE.El.key_at(keys, H + 0.06)[2]) + 0.022
	_knot(k, Vector3(0.018, H + 0.06, zf), 0.034, 0.024, wh)
	for e in [[0.28, 0.29], [-0.28, 0.29], [PI * 0.5, 0.62], [-PI * 0.5, 0.62], [PI - 0.28, 0.29], [-PI + 0.28, 0.29]]:
		_tasset(k, b, {"y0": H + 0.015, "ac": e[0], "aw": e[1], "n": 3, "h": 0.115, "ov": 0.018, "flare": 0.3, "add": 0.046, "col": ar, "trim": red, "lace": red, "th": 0.009})


# ------------------------------------------------------------------ Sengoku Musha (Savaşan Devletler: Madara / Hashirama): siyah gömlek, kızıl lake göğüslük ve omuzluk, yan kalçalıklar, toplu kızıl hakama, zırhlı tozluk
static func _sengoku(k) -> void:
	var b := _base(k)
	var shirt := Color(0.13, 0.13, 0.15)
	var la := Color(0.47, 0.1, 0.09)
	var ld := Color(0.24, 0.05, 0.05)
	var hk := Color(0.3, 0.065, 0.075)
	var gold := Color(0.72, 0.58, 0.28)
	var wh := Color(0.84, 0.82, 0.76)
	var H: float = k.H
	var N: float = k.N
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var ik := [_kp(nk, N + 0.075, 0.012, 0.014), _kp(nk, N + 0.03, 0.018), [N - 0.05, ch.x * 0.84, ch.y * 0.82, ch.z * 0.92], _kp(ch, C - 0.03, 0.012), _kp(b["wa"], H + 0.12, 0.012), _kp(b["hp"], H - 0.1, 0.012)]
	_seat(k, b, hk)
	SE.body_layer(k, ik, 26, 44, func(_i, _j, _p): return shirt, func(a, y): return 0.008 * sin(a * 9.0 + y * 12.0) * (1.0 - smoothstep(N - 0.1, N - 0.02, y)))
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var rip := func(s: float, a: float) -> float: return 0.006 * sin(a * 3.0 + s * 19.0) + 0.009 * exp(-pow((s - kn) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0)
		_lt(k, l, func(s, a): return 0.01 + 0.012 * smoothstep(0.1, 0.5, s) * (1.0 - smoothstep(0.66, 0.74, s)) + float(rip.call(s, a)), func(s, a, ins):
			return shirt.darkened(0.3) if ins else _fs(shirt.lightened(0.05), float(rip.call(s, a)), 15.0), 0.0, 1.0, 34, 20)
		_splint(k, l, 0.64, 0.96, 0.0, 0.86, 0.008, 0.007, la, ld, 6, 0.18)
		for s in [0.69, 0.91]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.011, 0.0048, 0.0, gold.darkened(0.2), _lskin(l, s))
		_sode(k, l, {"s0": 0.0, "n": 3, "ln": 0.094, "ov": 0.016, "W": 0.074, "R": 0.069, "curve": 3.1, "col": la, "trim": ld, "lace": ld.darkened(0.25), "th": 0.008})
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		_wide(k, b, l, {"col": hk, "prof": func(s): return 0.022 + 0.04 * smoothstep(0.05, kn, s) * (1.0 - smoothstep(kn + 0.1, 0.75, s)) + 0.01 * (1.0 - smoothstep(0.7, 0.75, s)), "pl": 5.0, "amp": 0.03, "s1": 0.76, "top": 0.06, "seg": 40, "n": 30, "cmax": 0.82, "pad": 0.03})
		_lt(k, l, func(_s, _a): return 0.005, func(_s, _a, _i): return wh, 0.66, 1.0, 12, 16)
		_wraps(k, l, 0.77, 0.985, 10, 0.006, 0.0115, wh, 0.007)
		_splint(k, l, 0.72, 0.96, 0.0, 0.92, 0.016, 0.007, la, ld, 6, 0.12)
		for s in [0.76, 0.925]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.0185, 0.0048, 0.0, gold.darkened(0.2), _lskin(l, s))
	# göğüslük: ön ve arka levha, karın plakası, kapalı bel bandı
	var keys := _tk(k, b, 0.024, H + 0.01, 0.0, 0.0)
	var ty := func(a: float) -> float: return N - 0.075 - 0.06 * smoothstep(0.35, 1.25, absf(sin(a)))
	_torso_plate(k, keys, 0.0, 1.32, N - 0.075, C - 0.1, 0.004, 0.01, la, ld, 30, 8, ty)
	_torso_plate(k, keys, 0.0, 1.4, C - 0.085, H + 0.115, 0.009, 0.01, la.darkened(0.04), ld, 30, 7)
	_torso_plate(k, keys, PI, 1.3, N - 0.075, C - 0.1, 0.004, 0.01, la, ld, 30, 8, func(a): return ty.call(a - PI))
	_torso_plate(k, keys, PI, 1.4, C - 0.085, H + 0.115, 0.009, 0.01, la.darkened(0.04), ld, 30, 7)
	var bk := _tk(k, b, 0.036, H - 0.02, 0.0, 0.0)
	_torso_plate(k, bk, 0.0, PI * 0.995, H + 0.115, H + 0.05, 0.0, 0.009, la.darkened(0.1), ld, 56, 3)
	_sash(k, bk, H + 0.026, 0.024, 0.003, shirt.lightened(0.08), 0.22, 1)
	# göğüs bağları + ortada altın düğüm, omuz askıları
	for sg in [1.0, -1.0]:
		for a in [0.32, 0.9]:
			var e0: Array = _sa(keys, sg * float(a), C - 0.078, 0.019)
			var e1: Array = _sa(keys, sg * float(a), C - 0.112, 0.022)
			for dx in [-0.009, 0.009]:
				_cord(k, [(e0[0] as Vector3) + Vector3(float(dx), 0.0, 0.0), (e1[0] as Vector3) + Vector3(float(dx), 0.0, 0.0)], 0.0032, ld.darkened(0.25), func(p): return k.torso_skin(p.y), 5)
		_over(k, ik.slice(1), sg * 0.82, N - 0.09, sg * (PI - 0.82), N - 0.09, 0.03, 0.016, 0.009, la.darkened(0.08))
	var e2: Array = _sa(keys, 0.0, C + 0.03, 0.0175)
	_box(k, e2[0], Vector3(0.018, 0, 0), Vector3(0, 0.018, 0), Vector3(0, 0, 0.0045), gold, [["UpperChest", 1.0]], 0.5)
	# kalçalıklar: yanlarda ve önde üçer plaka, aralarından hakama görünür
	for e in [[0.155, 0.16, 2], [-0.155, 0.16, 2], [PI * 0.5 - 0.06, 0.4, 3], [-PI * 0.5 + 0.06, 0.4, 3], [PI - 0.155, 0.16, 2], [-PI + 0.155, 0.16, 2]]:
		_tasset(k, b, {"y0": H + 0.0, "ac": e[0], "aw": e[1], "n": e[2], "h": 0.092, "ov": 0.016, "flare": 0.2, "add": 0.042, "col": la, "trim": ld, "lace": ld.darkened(0.25), "th": 0.008})


# ------------------------------------------------------------------ Kage no Shinobi: dar siyah üst, boyun kapalı, taktik pantolon, deri kayış koşumu, uyluk çantası
static func _kage_no(k) -> void:
	var b := _base(k)
	var bk := Color(0.15, 0.15, 0.18)
	var bk2 := Color(0.24, 0.24, 0.28)
	var pn := Color(0.12, 0.12, 0.145)
	var lea := Color(0.25, 0.2, 0.16)
	var met := Color(0.48, 0.48, 0.5)
	var H: float = k.H
	var N: float = k.N
	var C: float = k.C
	var ch: Vector3 = b["ch"]
	var nk: Vector3 = b["nk"]
	var ik := [_kp(nk, N + 0.06, 0.013, 0.016), _kp(nk, N + 0.025, 0.02), [N - 0.045, ch.x * 0.97, ch.y * 0.84, ch.z * 0.92], _kp(ch, C - 0.03, 0.012), _kp(b["wa"], H + 0.12, 0.01), _kp(b["hp"], H - 0.1, 0.012)]
	SE.body_layer(k, ik, 44, 56, func(_i, _j, p):
		var bd: bool = p.y > N - 0.004 and fposmod(p.y * 58.0, 1.0) < 0.2
		var side: float = smoothstep(0.7, 0.92, absf(p.x) / maxf(0.08, float(SE.El.key_at(ik, p.y)[1])))
		return bk2.darkened(0.3) if bd else bk.lerp(bk2, side), func(a, y):
		var s: float = clampf((y - H) / (N - H), 0.0, 1.0)
		return (1.0 - s) * 0.014 * sin(a * 8.0 + y * 9.0) if y < N - 0.03 else 0.0)
	var keys: Array = ik.slice(1)   # dikiş ve koşum bedenin kendi yüzeyine oturur
	# raglan dikişi + yan panel
	for sg in [1.0, -1.0]:
		_rail(k, keys, [Vector2(sg * 0.5, N - 0.012), Vector2(sg * 1.2, C + 0.02), Vector2(sg * 1.5, C - 0.04)], 0.0022, 0.004, 0.0012, bk2)
		_rail(k, keys, [Vector2(sg * (PI - 0.5), N - 0.012), Vector2(sg * (PI - 1.2), C + 0.02), Vector2(sg * (PI - 1.5), C - 0.04)], 0.0022, 0.004, 0.0012, bk2)
	for lk in ["aL", "aR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var rip := func(s: float, a: float) -> float: return 0.008 * exp(-pow((s - kn) / 0.08, 2.0)) * sin(a * 3.0 + s * 34.0) + 0.0035 * sin(a * 3.0 + s * 21.0)
		_lt(k, l, func(s, a): return 0.006 + float(rip.call(s, a)) - 0.012 * (1.0 - smoothstep(0.02, 0.16, s)), func(s, a, ins):
			return bk.darkened(0.4) if ins else _fs(bk.lightened(0.04), float(rip.call(s, a)), 22.0), 0.0, 1.0, 36, 18)
		_splint(k, l, 0.7, 0.955, 0.0, 0.92, 0.008, 0.0045, bk2, lea.darkened(0.2), 5)
		for s in [0.74, 0.84, 0.93]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.0125, 0.0042, 0.0, lea, _lskin(l, s))
	for lk in ["lL", "lR"]:
		var l: Dictionary = b[lk]
		var kn: float = l["kn"]
		var sg: float = l["sg"]
		var rip := func(s: float, a: float) -> float: return smoothstep(0.05, 0.3, s) * (1.0 - smoothstep(0.76, 0.84, s)) * (0.0065 * sin(a * 3.0 + s * 19.0 + sg) + 0.004 * sin(a * 5.0 - s * 28.0)) + 0.008 * exp(-pow((s - kn) / 0.07, 2.0)) * sin(a * 3.0 + s * 32.0)
		_lt(k, l, func(s, a): return 0.014 + 0.012 * smoothstep(0.1, 0.5, s) * (1.0 - smoothstep(0.72, 0.84, s)) + float(rip.call(s, a)), func(s, a, ins):
			return pn.darkened(0.4) if ins else _fs(pn.lightened(0.03), float(rip.call(s, a)), 22.0), 0.0, 1.0, 38, 22)
		_wraps(k, l, 0.82, 0.985, 8, 0.01, 0.0105, bk2, 0.007)
		# dizlik, yan cep, uyluk çantası ve kayışları
		_splint(k, l, kn - 0.06, kn + 0.06, 0.0, 0.8, 0.028, 0.009, bk2, lea.darkened(0.3), 5)
		k.wrap_turn(_lp(l, kn - 0.075), _ld(l, kn - 0.075), _lr(l, kn - 0.075) + 0.032, 0.005, 0.0, lea, _lskin(l, kn - 0.075))
		k.wrap_turn(_lp(l, kn + 0.075), _ld(l, kn + 0.075), _lr(l, kn + 0.075) + 0.032, 0.005, 0.0, lea, _lskin(l, kn + 0.075))
		_splint(k, l, 0.2, 0.37, sg * 1.45, 0.48, 0.026, 0.017, lea, lea.darkened(0.35), 4)
		for s in [0.2, 0.34]:
			k.wrap_turn(_lp(l, s), _ld(l, s), _lr(l, s) + 0.03, 0.0065, 0.0, lea.darkened(0.12), _lskin(l, s))
	# bel: kalın kemer, toka, çantalar
	var bk3 := _tk(k, b, 0.022, H - 0.04, 0.0, 0.0)
	_sash(k, bk3, H + 0.012, 0.022, 0.003, lea, 0.18, 1)
	var fz: float = float(SE.El.key_at(bk3, H + 0.012)[2]) + 0.012
	_box(k, Vector3(0.0, H + 0.012, fz), Vector3(0.022, 0, 0), Vector3(0, 0.019, 0), Vector3(0, 0, 0.005), met, [["Hips", 1.0]], 0.35)
	for e in [[2.25, 0.03], [-2.25, 0.03], [0.95, 0.024]]:
		var s2: Array = _sa(bk3, float(e[0]), H - 0.015, 0.02)
		var o: Vector3 = s2[1]
		var r: Vector3 = Vector3.UP.cross(o).normalized()
		_box(k, s2[0], r * float(e[1]), Vector3(0, 0.03, 0), o * 0.018, lea.darkened(0.08), [["Hips", 1.0]], 0.28)
	# koşum: göğüste çapraz iki kayış, ortada halka, sırtta çapraz
	var kk: Array = keys
	var cy: float = C - 0.05
	for sg in [1.0, -1.0]:
		_rail(k, kk, [Vector2(sg * 0.62, N - 0.018), Vector2(sg * 0.12, cy + 0.015), Vector2(-sg * 0.1, cy - 0.015), Vector2(-sg * 0.82, H + 0.03)], 0.0135, 0.004, 0.0035, lea, 8)
		_rail(k, kk, [Vector2(sg * (PI - 0.62), N - 0.018), Vector2(sg * (PI + 0.08), cy), Vector2(sg * (PI + 0.82), H + 0.03)], 0.0135, 0.004, 0.0035, lea, 8)
		_over(k, kk, sg * 0.62, N - 0.03, sg * (PI - 0.62), N - 0.03, 0.0135, 0.004, 0.0035, lea)
	var rc: Array = _sa(kk, 0.0, cy, 0.012)
	_box(k, rc[0], Vector3(0.019, 0, 0), Vector3(0, 0.019, 0), Vector3(0, 0, 0.0055), met, [["UpperChest", 1.0]], 0.5)
	var rb: Array = _sa(kk, PI, cy, 0.012)
	_box(k, rb[0], Vector3(0.016, 0, 0), Vector3(0, 0.016, 0), Vector3(0, 0, 0.005), met, [["UpperChest", 1.0]], 0.5)
