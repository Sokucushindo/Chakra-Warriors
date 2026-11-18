extends RefCounted
## Elle modellenmiş setler, parti c: tani, yamanaka, kurama, chinoike, iburi, funato. Örnek: set_el.gd içindeki _shugonin.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_iburi", "set_funato", "set_kurama", "set_chinoike", "set_tani", "set_yamanaka"]


static func recipe(k, sid: String) -> void:
	match sid:
		"set_tani": _tani(k)
		"set_yamanaka": _yamanaka(k)
		"set_kurama": _kurama(k)
		"set_chinoike": _chinoike(k)
		"set_iburi": _iburi(k)
		"set_funato": _funato(k)


# ------------------------------------------------------------------ parti yardımcıları
## Anahtar kesitinde yüzey noktası: a açısı (0 ön, +PI/2 karakterin solu), lift bağıl kabarma
static func _on(keys: Array, a: float, y: float, lift := 0.0) -> Vector3:
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
	return Vector3(q.x * (1.0 + lift), y, q.y * (1.0 + lift))


static func _out(p: Vector3, up := 0.0) -> Vector3:
	return Vector3(p.x, up, p.z).normalized()


## Kumaş yüzeyi: keys kesitleri boyunca açı aralığı. Kıvrım gerçek geometri + vadide koyulaşma, kenarda kalınlık, arkada iç yüz (çift taraf).
## o: keys, span(y)->Vector2, fold(a,y,u)->bağıl, col(a,y,u)->Color, ny, na, closed, lip, inner(Color), shade, skin(p)->Array
static func _gar(k, o: Dictionary) -> Dictionary:
	var keys: Array = o["keys"]
	var ny: int = o.get("ny", 36)
	var na: int = o.get("na", 64)
	var closed: bool = o.get("closed", false)
	var span: Callable = o.get("span", func(_y): return Vector2(-PI, PI))
	var fold: Callable = o.get("fold", Callable())
	var col: Callable = o["col"]
	var lip: float = o.get("lip", 0.007)
	var shade: float = o.get("shade", 3.8)
	var skf: Callable = o.get("skin", func(p: Vector3) -> Array: return k.torso_skin(p.y))
	var y0: float = keys[0][0]
	var y1: float = keys[keys.size() - 1][0]
	var rows := []
	var cols := []
	var nc: int = na if closed else na + 1
	for j in ny + 1:
		var y := lerpf(y0, y1, float(j) / ny)
		var s: Array = SE.El.key_at(keys, y)
		var e: Vector2 = span.call(y)
		var ro := []
		var cr := []
		for i in nc:
			var u := float(i) / na
			var a := lerpf(e.x, e.y, u)
			var q: Vector2 = SE.El.sup(a, s[1], s[2], s[3])
			var f: float = float(fold.call(a, y, u)) if fold.is_valid() else 0.0
			ro.append(Vector3(q.x * (1.0 + f), y, q.y * (1.0 + f)))
			var c0: Color = col.call(a, y, u)
			cr.append(c0.darkened(clampf(-f * shade, 0.0, 0.34)).lightened(clampf(f * shade * 0.35, 0.0, 0.08)))
		rows.append(ro)
		cols.append(cr)
	var inw = func(p: Vector3, d: float) -> Vector3: return p - _out(p) * d
	var out_r := []
	var out_c := []
	for j in rows.size():
		var ro: Array = (rows[j] as Array).duplicate()
		var cr: Array = (cols[j] as Array).duplicate()
		if not closed:
			ro.push_front(inw.call(ro[0], lip))
			ro.push_back(inw.call(ro[ro.size() - 1], lip))
			cr.push_front((cr[0] as Color).darkened(0.32))
			cr.push_back((cr[cr.size() - 1] as Color).darkened(0.32))
		out_r.append(ro)
		out_c.append(cr)
	var last: Array = []
	var lastc: Array = []
	for i in (out_r[out_r.size() - 1] as Array).size():
		last.append(inw.call(out_r[out_r.size() - 1][i], lip) + Vector3(0, lip * 0.8, 0))
		lastc.append((out_c[out_c.size() - 1][i] as Color).darkened(0.32))
	out_r.append(last)
	out_c.append(lastc)
	var sf = func(_i, _j, p): return skf.call(p)
	k.grid(out_r, closed, func(i, j, _p): return out_c[j][i], sf)
	if o.has("inner"):
		var ic: Color = o["inner"]
		var in_r := []
		for ro in out_r:
			var r2 := []
			for p in ro:
				r2.push_front(inw.call(p, lip))
			in_r.append(r2)
		k.grid(in_r, closed, func(_i, j, _p): return ic.darkened(0.1 * float(j) / out_r.size()), sf)
	var ea := []
	var eb := []
	for ro in rows:
		ea.append(ro[0])
		eb.append(ro[ro.size() - 1])
	return {"rows": rows, "ea": ea, "eb": eb, "hem": rows[ny]}


## Yüzeyden hafif kalkık şerit: dış yön noktadan hesaplanır
static func _bd(k, pts: Array, hw: float, d: float, col: Color, closed := false, skinf := Callable(), up := 0.0) -> void:
	var ou := []
	for p in pts:
		ou.append(_out(p, up))
	k.strip(pts, ou, hw, d, col, closed, skinf)


## Yuvarlak ip / biye: pts boyunca tüp; tw > 0 ise burgulu
static func _cord(k, pts: Array, r: float, col: Color, closed := false, skinf := Callable(), tw := 0.0, seg := 6) -> void:
	var n := pts.size()
	var rows := []
	var cc := []
	var count: int = n + 1 if closed else n
	for j in count:
		var i0: int = j % n
		var a: Vector3 = pts[(i0 - 1 + n) % n] if closed or i0 > 0 else pts[i0]
		var b: Vector3 = pts[(i0 + 1) % n] if closed or i0 < n - 1 else pts[i0]
		var t: Vector3 = (b - a).normalized()
		var p: Vector3 = pts[i0]
		var fw: Vector3 = _out(p, 0.2)
		fw = (fw - t * t.dot(fw)).normalized()
		var ri: Vector3 = (-t).cross(fw).normalized()
		var ro := []
		var cr := []
		for i in seg:
			var q := TAU * i / seg - PI
			var w := sin(float(j) * tw + q * 2.0) if tw > 0.0 else 0.0
			ro.append(p + (ri * sin(q) + fw * cos(q)) * r * (1.0 + 0.2 * w))
			cr.append(col.darkened(clampf(-w * 0.28, 0.0, 0.28)))
		rows.append(ro)
		cc.append(cr)
	var sf: Callable = skinf if skinf.is_valid() else func(p: Vector3) -> Array: return k.torso_skin(p.y)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return sf.call(p))


## Kuşak: katlı kalın bez halkası (kesitten alır)
static func _sash(k, keys: Array, y: float, h: float, lift: float, col: Color, crease := 0.14) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var rows := []
	var cc := []
	var na := 56
	for j in 7:
		var t := float(j) / 6.0
		var b := 0.008 * sin(t * PI) + lift
		var ro := []
		var cr := []
		for i in na:
			var a := TAU * i / na - PI
			var wob := 0.004 * sin(a * 5.0 + t * 7.0)
			var yy := y + h * (1.0 - 2.0 * t) + 0.004 * sin(a * 3.0 + 1.0)
			var q: Vector2 = SE.El.sup(a, float(s[1]) + b + wob, float(s[2]) + b + wob, float(s[3]) - b - wob)
			ro.append(Vector3(q.x, yy, q.y))
			var cre: bool = (j == 2 or j == 4) and sin(a * 4.0 + float(j)) > -0.4
			cr.append(col.darkened(crease) if cre else col)
		rows.append(ro)
		cc.append(cr)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, _j, p): return k.torso_skin(p.y))


## Kol / bacak tüpü, kesitte gerçek kıvrımlı: rad(t,a,yön)->Vector2(yarıçap, kıvrım m); colf(t,a)->Color
static func _tb(k, path: Array, bones: Array, rad: Callable, colf: Callable, rings := 24, seg := 16, inner := Color(0.08, 0.07, 0.07), chest := -1.0) -> void:
	var L := 0.0
	var cum := [0.0]
	for i in path.size() - 1:
		L += (path[i + 1] - path[i]).length()
		cum.append(L)
	var rows := []
	var cc := []
	var info := []
	var chw: float = chest if chest >= 0.0 else (0.8 if String(bones[0]).ends_with("UpperArm") else 0.0)
	for j in rings + 4:
		var t := minf(1.0, float(j) / rings)
		var s := t * L
		var q := 0
		while q < path.size() - 2 and s > float(cum[q + 1]):
			q += 1
		var sl := maxf(0.0001, float(cum[q + 1]) - float(cum[q]))
		var u := clampf((s - float(cum[q])) / sl, 0.0, 1.0)
		var ctr: Vector3 = (path[q] as Vector3).lerp(path[q + 1], u)
		var d: Vector3 = (path[q + 1] - path[q]).normalized()
		if u > 0.75 and q < path.size() - 2:
			d = d.lerp((path[q + 2] - path[q + 1]).normalized(), (u - 0.75) * 2.0).normalized()
		var up := -d
		var fw: Vector3 = (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
		var ri := up.cross(fw).normalized()
		var ro := []
		var cr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var dv: Vector3 = ri * sin(a) + fw * cos(a)
			var v: Vector2 = rad.call(t, a, dv)
			var r := v.x + v.y
			var c0: Color = colf.call(t, a)
			c0 = c0.darkened(clampf(-v.y * 26.0, 0.0, 0.24)).lightened(clampf(v.y * 9.0, 0.0, 0.05))
			if j == rings + 1:
				r *= 0.94
				c0 = c0.darkened(0.3)
			elif j == rings + 2:
				r *= 0.74
				c0 = inner
			elif j == rings + 3:
				r *= 0.3
				c0 = inner
			var back: float = 0.012 if j == rings + 2 else (0.07 if j == rings + 3 else 0.0)
			ro.append(ctr + dv * r - d * back)
			cr.append(c0)
		rows.append(ro)
		cc.append(cr)
		var bl := [[bones[q], 1.0]]
		if u > 0.72 and q + 1 < bones.size():
			var b2 := smoothstep(0.72, 1.0, u) * 0.5
			bl = [[bones[q], 1.0 - b2], [bones[q + 1], b2]]
		elif u < 0.28 and q > 0:
			var b2 := (1.0 - smoothstep(0.0, 0.28, u)) * 0.5
			bl = [[bones[q], 1.0 - b2], [bones[q - 1], b2]]
		if chw > 0.0 and s < 0.075:
			var w: float = chw * (1.0 - smoothstep(0.0, 0.075, s))
			bl = [[bones[0], 1.0 - w], ["UpperChest", w]]
		info.append(bl)
	k.grid(rows, true, func(i, j, _p): return cc[j][i], func(_i, j, _p): return info[j])


static func _arm_path(k, sd: String, end := 1.0, root := 0.12) -> Array:
	var m = k.m
	var p0: Vector3 = m._bp(sd + "UpperArm")
	var p1: Vector3 = m._bp(sd + "LowerArm")
	var p2: Vector3 = m._bp(sd + "Hand")
	var ch: Vector3 = m._bp("UpperChest")
	return [p0.lerp(Vector3(0.0, ch.y, ch.z), root), p1, p1.lerp(p2, end)]


## Kolun yenin altında kalan kısmı: omuzdan değil pazunun ortasından başlar (omuzda kumaşı delmesin)
static func _under_arm(k, sd: String) -> Array:
	var m = k.m
	var p0: Vector3 = m._bp(sd + "UpperArm")
	var p1: Vector3 = m._bp(sd + "LowerArm")
	return [p0.lerp(p1, 0.45), p1, m._bp(sd + "Hand")]


## Bacak her zaman kalçadan başlar; end: baldırda nerede biteceği
static func _leg_path(k, sd: String, end := 1.0) -> Array:
	var m = k.m
	var p0: Vector3 = m._bp(sd + "UpperLeg")
	var p1: Vector3 = m._bp(sd + "LowerLeg")
	var p2: Vector3 = m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
	return [p0 + Vector3(0, 0.05, 0), p1, p1.lerp(p2, end)]


## Kuşak / bağ ucu: sarkmaz, alttaki kumaşın kıvrımını izleyerek üstüne oturur
static func _tail(k, keys: Array, fold: Callable, a0: float, drift: float, y0: float, y1: float, hw: float, col: Color, skf: Callable) -> void:
	var pts := []
	for i in 13:
		var t := float(i) / 12.0
		var a: float = a0 + drift * t + 0.035 * sin(t * 7.0)
		var y: float = lerpf(y0, y1, t)
		var f: float = float(fold.call(a, y, 0.5)) if fold.is_valid() else 0.0
		pts.append(_on(keys, a, y, f + 0.016))
	_bd(k, pts, hw, 0.0035, col, false, skf)
	_bd(k, pts.slice(1, 12), hw * 0.16, 0.0048, col.darkened(0.2), false, skf)


## Ayaklardan profil: [[t, r], ...] içinde yumuşak ara değer
static func _pr(prof: Array, t: float) -> float:
	for i in prof.size() - 1:
		if t <= float(prof[i + 1][0]):
			return lerpf(prof[i][1], prof[i + 1][1], smoothstep(0.0, 1.0, inverse_lerp(float(prof[i][0]), float(prof[i + 1][0]), t)))
	return float(prof[prof.size() - 1][1])


## Yüzeye dikili yama: kenarı kumaşa iner, çevresinde iri dikiş
static func _patch(k, keys: Array, y: float, a: float, hw: float, hh: float, lift: float, col: Color, st: Color, rot := 0.1, skf := Callable()) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var r := maxf(0.05, float(s[1]))
	var pos = func(u: float, v: float, l: float) -> Vector3:
		var x := u * hw * cos(rot) - v * hh * sin(rot)
		var yy := u * hw * sin(rot) + v * hh * cos(rot)
		return _on(keys, a + x / r, y + yy, l)
	var rows := []
	for j in 7:
		var v := lerpf(1.0, -1.0, float(j) / 6.0)
		var ro := []
		for i in 7:
			var u := lerpf(-1.0, 1.0, float(i) / 6.0)
			var e := maxf(absf(u), absf(v))
			ro.append(pos.call(u, v, lift * (1.0 - e * e * e) + 0.004))
		rows.append(ro)
	k.grid(rows, false, func(i, j, _p): return col.darkened(0.06 * float((i + j * 2) % 3)), func(_i, _j, p): return skf.call(p) if skf.is_valid() else k.torso_skin(p.y))
	for sd in [[-1.0, 0.0], [1.0, 0.0], [0.0, 1.0], [0.0, -1.0]]:
		for n in 5:
			var w := lerpf(-0.8, 0.8, float(n) / 4.0)
			var c: Vector2 = Vector2(sd[0], sd[1]) * 0.86 + (Vector2(w, 0.0) if float(sd[0]) == 0.0 else Vector2(0.0, w))
			var t := Vector2(0.14, 0.0) if float(sd[0]) != 0.0 else Vector2(0.0, 0.14)
			var q0: Vector3 = pos.call(c.x - t.x, c.y - t.y, lift * 0.36 + 0.008)
			var q1: Vector3 = pos.call(c.x + t.x, c.y + t.y, lift * 0.36 + 0.008)
			_bd(k, [q0, q1], 0.0026, 0.0014, st, false, skf)


## Baldır / bilek sargısı turları
static func _wraps(k, a: Vector3, b: Vector3, n: int, r0: float, r1: float, hw: float, tilt: float, col: Color, bone: String) -> void:
	var d := b - a
	for i in n:
		var t := float(i) / maxf(1.0, float(n - 1))
		k.wrap_turn(a.lerp(b, t), d, lerpf(r0, r1, t), hw, tilt, col.darkened(0.06 * float(i % 3)), [[bone, 1.0]])


# ------------------------------------------------------------------ Tani (kaynak görsel yok; oyun tanımı: toprak rengi yelekli üniforma): yandan toklu yelek, kat kat omuzluk, bel kanatları, diz koruyucu
static func _tani(k) -> void:
	var dk := Color(0.23, 0.2, 0.17)
	var pn := Color(0.2, 0.17, 0.15)
	var ve := Color(0.46, 0.37, 0.27)
	var ed := Color(0.78, 0.72, 0.6)
	var le := Color(0.3, 0.23, 0.16)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = k.M(C - 0.03, k.UA)
	var wa: Vector3 = k.M(H + 0.12, k.UA)
	var bw: Vector3 = k.M(H + 0.04, 0.3)
	var hp: Vector3 = k.M(H - 0.04, 0.3)
	var nk: Vector3 = k.M(N + 0.02, 0.09)
	var inner := [[N + 0.055, nk.x + 0.008, nk.y + 0.01, nk.z - 0.01], [N - 0.05, ch.x * 0.82, ch.y * 0.8, ch.z * 0.9], [C - 0.03, ch.x + 0.008, ch.y + 0.008, ch.z - 0.008],
		[H + 0.12, wa.x + 0.008, wa.y + 0.008, wa.z - 0.008], [H - 0.04, hp.x + 0.012, hp.y + 0.012, hp.z - 0.012], [H - 0.13, hp.x * 0.72, hp.y * 0.74, hp.z * 0.74]]
	SE.body_layer(k, inner, 24, 40, func(_i, _j, _p): return dk)
	var arm_p := [[0.0, 0.054], [0.2, 0.058], [0.42, 0.056], [0.55, 0.053], [0.86, 0.042], [1.0, 0.043]]
	var leg_p := [[0.0, 0.098], [0.25, 0.093], [0.46, 0.078], [0.56, 0.073], [0.8, 0.064], [0.93, 0.056], [1.0, 0.051]]
	for sd in ["Left", "Right"]:
		_tb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], func(t, a, _d):
			var e: float = exp(-pow((t - 0.48) / 0.09, 2.0))
			return Vector2(_pr(arm_p, t), e * 0.004 * sin(t * 62.0 + a * 1.5) + 0.0012 * sin(a * 3.0 + t * 13.0)), func(_t, _a): return dk)
		_tb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], func(t, a, _d):
			var e: float = smoothstep(0.76, 0.94, t)
			return Vector2(_pr(leg_p, t), 0.002 * sin(a * 3.0 + t * 10.0) + e * 0.0045 * sin(t * 66.0 + a * 2.0)), func(_t, _a): return pn, 28, 18)
		_patch_leg(k, sd, le, ed.darkened(0.3), 0.074)
		var el: Vector3 = k.m._bp(sd + "LowerArm")
		var hd: Vector3 = k.m._bp(sd + "Hand")
		_wraps(k, el.lerp(hd, 0.74), el.lerp(hd, 0.94), 4, 0.0445, 0.0425, 0.011, 0.005, le, sd + "LowerArm")
		var kn: Vector3 = k.m._bp(sd + "LowerLeg")
		var ft: Vector3 = k.m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		_wraps(k, kn.lerp(ft, 0.82), kn.lerp(ft, 0.98), 3, 0.059, 0.054, 0.012, 0.006, le, sd + "LowerLeg")
		# omuzluk: üst üste iki kat deri
		var ap := _arm_path(k, sd, 1.0, 0.0)
		var p0: Vector3 = ap[0]
		var p1: Vector3 = ap[1]
		for l in [[0.3, 0.5, 0.082, le.darkened(0.08)], [0.0, 0.34, 0.086, ve.darkened(0.1)]]:
			var rr: float = l[2]
			var cc: Color = l[3]
			_tb(k, [p0.lerp(p1, float(l[0])), p0.lerp(p1, float(l[1]))], [sd + "UpperArm"], func(t, a, _d):
				return Vector2(lerpf(rr * 0.74, rr, smoothstep(0.0, 0.42, t)), 0.0012 * sin(a * 4.0)), func(t, _a): return ed.darkened(0.15) if t > 0.86 else cc, 9, 18, cc.darkened(0.55), 0.8 if float(l[0]) <= 0.0 else 0.0)
	# yelek: yandan kapanır, sol yana inen bindirme; toklu kayışlar
	var keys := [[N + 0.01, nk.x + 0.028, nk.y + 0.026, nk.z - 0.028], [N - 0.05, ch.x * 0.93, ch.y * 0.9, ch.z * 0.99], [C - 0.03, ch.x + 0.03, ch.y + 0.04, ch.z - 0.032],
		[H + 0.12, wa.x + 0.026, wa.y + 0.032, wa.z - 0.028], [H + 0.015, bw.x + 0.024, bw.y + 0.026, bw.z - 0.026]]
	var ef = func(y: float) -> float: return lerpf(-0.3, -1.05, smoothstep(N, C - 0.14, y))
	var ef2 = func(y: float) -> float: return TAU + lerpf(-0.42, -0.8, smoothstep(N, C - 0.14, y))
	var fold = func(a: float, y: float, u: float) -> float:
		return 0.006 * sin(a * 5.0 + y * 17.0) + 0.007 * sin(a * 9.0 + 1.0) * smoothstep(C - 0.1, H + 0.04, y) - 0.03 * smoothstep(0.88, 1.0, u)
	var g := _gar(k, {"keys": keys, "ny": 30, "na": 68, "span": func(y): return Vector2(ef.call(y), ef2.call(y)), "fold": fold, "col": func(_a, _y, _u): return ve, "inner": ve.darkened(0.45), "shade": 4.5})
	_bd(k, g["ea"], 0.0085, 0.0038, ed)
	var hm := []
	for p in g["hem"]:
		hm.append(p + Vector3(0, 0.009, 0))
	_bd(k, hm, 0.008, 0.0035, ed.darkened(0.08))
	# kayışlar: bindirmeyi tutan üç deri kayış + metal toka
	for i in 3:
		var y: float = lerpf(C - 0.03, H + 0.09, float(i) / 2.0)
		var e0: float = ef.call(y)
		var pts := []
		for q in 7:
			pts.append(_on(keys, lerpf(e0 - 0.3, e0 + 0.32, float(q) / 6.0), y + 0.004 * sin(float(q)), 0.04))
		_bd(k, pts, 0.0095, 0.0032, le)
		var b := _on(keys, e0 + 0.06, y, 0.075)
		var ring := []
		for q in 8:
			var w := TAU * q / 8.0
			ring.append(b + Vector3(cos(w) * 0.0125, sin(w) * 0.0115, 0.0))
		_cord(k, ring, 0.0024, Color(0.62, 0.6, 0.55), true)
	# göğüs ve sırt cepleri
	_patch(k, keys, C - 0.05, 0.8, 0.044, 0.04, 0.1, ve.lightened(0.05), ve.darkened(0.3), 0.04)
	_patch(k, keys, H + 0.095, 0.36, 0.05, 0.032, 0.11, ve.lightened(0.04), ve.darkened(0.3), 0.0)
	_patch(k, keys, C - 0.05, PI, 0.11, 0.058, 0.07, ve.darkened(0.08), ve.darkened(0.34), 0.0)
	# dik arka yaka: önü açık, kenarı biyeli
	var ck := [[N + 0.078, nk.x + 0.026, nk.y + 0.02, nk.z - 0.036], [N + 0.0, nk.x + 0.036, nk.y + 0.03, nk.z - 0.04]]
	var cg := _gar(k, {"keys": ck, "ny": 5, "na": 28, "span": func(_y): return Vector2(0.72, TAU - 0.72), "col": func(_a, _y, _u): return ve.darkened(0.06), "inner": ve.darkened(0.42)})
	_bd(k, cg["rows"][0], 0.0065, 0.003, ed, false, Callable(), 0.6)
	# kemer + bel kanatları: ön iki, yan iki, arka bir
	_sash(k, keys, H + 0.03, 0.022, 0.008, le, 0.12)
	var low := [[H + 0.02, bw.x + 0.024, bw.y + 0.032, bw.z - 0.032], [H - 0.05, hp.x + 0.028, hp.y + 0.038, hp.z - 0.038], [H - 0.2, hp.x + 0.046, hp.y + 0.06, hp.z - 0.06]]
	for c0 in [0.44, -0.44, 1.5, -1.5, PI]:
		var hw: float = 0.52 if absf(float(c0)) > 3.0 else 0.4
		var fl := _gar(k, {"keys": low, "ny": 10, "na": 14, "span": func(y):
				var w: float = hw * lerpf(1.0, 0.88, smoothstep(H + 0.02, H - 0.2, y))
				return Vector2(float(c0) - w, float(c0) + w),
			"fold": func(a, y, _u): return 0.012 * sin(a * 8.0) * smoothstep(H, H - 0.2, y), "col": func(_a, _y, _u): return ve.darkened(0.1), "inner": ve.darkened(0.5), "skin": func(p): return k.cloth_skin(p, H - 0.2)})
		var h2 := []
		for p in fl["hem"]:
			h2.append(p + Vector3(0, 0.008, 0))
		_bd(k, h2, 0.0075, 0.003, ed.darkened(0.08), false, func(p): return k.cloth_skin(p, H - 0.2))
# ------------------------------------------------------------------ Yamanaka (ref Inoichi): koyu iç giysi, kalın yakalı yeşil yelek, önü açık kolsuz kızıl uzun üst, kol koruyucu, baldır sargısı
static func _yamanaka(k) -> void:
	var dk := Color(0.12, 0.14, 0.24)
	var gn := Color(0.36, 0.44, 0.32)
	var rd := Color(0.42, 0.09, 0.13)
	var rl := Color(0.26, 0.06, 0.09)
	var gu := Color(0.58, 0.54, 0.5)
	var wh := Color(0.86, 0.84, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = k.M(C - 0.03, k.UA)
	var wa: Vector3 = k.M(H + 0.12, k.UA)
	var bl: Vector3 = k.M(H + 0.04, 0.3)
	var hp: Vector3 = k.M(H - 0.04, 0.3)
	var nk: Vector3 = k.M(N + 0.02, 0.09)
	# iç giysi: dik boyunlu, kalçaya kadar
	var inner := [[N + 0.05, nk.x + 0.008, nk.y + 0.01, nk.z - 0.01], [N - 0.05, ch.x * 0.8, ch.y * 0.8, ch.z * 0.9], [C - 0.03, ch.x + 0.008, ch.y + 0.008, ch.z - 0.008],
		[H + 0.12, wa.x + 0.008, wa.y + 0.008, wa.z - 0.008], [H - 0.04, hp.x + 0.012, hp.y + 0.012, hp.z - 0.012], [H - 0.13, hp.x * 0.72, hp.y * 0.74, hp.z * 0.74]]
	SE.body_layer(k, inner, 24, 40, func(_i, _j, _p): return dk)
	var arm_p := [[0.0, 0.043], [0.2, 0.057], [0.42, 0.056], [0.55, 0.053], [0.86, 0.042], [1.0, 0.043]]
	var leg_p := [[0.0, 0.098], [0.25, 0.092], [0.46, 0.076], [0.56, 0.07], [0.82, 0.058], [1.0, 0.052]]
	for sd in ["Left", "Right"]:
		_tb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], func(t, a, _d):
			var e: float = exp(-pow((t - 0.47) / 0.09, 2.0))
			return Vector2(_pr(arm_p, t), e * 0.0042 * sin(t * 62.0 + a * 1.5) + 0.0012 * sin(a * 3.0 + t * 15.0)), func(_t, _a): return dk.lightened(0.05))
		_tb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], func(t, a, _d):
			var e: float = exp(-pow((t - 0.48) / 0.1, 2.0))
			return Vector2(_pr(leg_p, t), e * 0.0048 * sin(t * 58.0 + a * 2.0) + 0.002 * sin(a * 3.0 + t * 11.0)), func(_t, _a): return dk, 28, 18)
		# kol koruyucu: dirsekten bileğe iki parça deri, kayışlı
		var el: Vector3 = k.m._bp(sd + "LowerArm")
		var hd: Vector3 = k.m._bp(sd + "Hand")
		_tb(k, [el.lerp(hd, 0.2), el.lerp(hd, 0.56), el.lerp(hd, 0.9)], [sd + "LowerArm", sd + "LowerArm"], func(t, a, _d):
			var rr: float = lerpf(0.0525, 0.0465, t)
			return Vector2(rr, 0.0016 * cos(a * 2.0) + 0.0014 * smoothstep(0.42, 0.5, t) * (1.0 - smoothstep(0.5, 0.58, t))), func(t, _a): return gu.darkened(0.3) if absf(t - 0.5) < 0.04 else gu, 14, 16)
		for f in [0.3, 0.8]:
			k.wrap_turn(el.lerp(hd, f), hd - el, lerpf(0.055, 0.05, f), 0.007, 0.0, dk.darkened(0.2), [[sd + "LowerArm", 1.0]])
		# baldırın üstünde beyaz sargı (kaynakta dizin altında)
		var kn: Vector3 = k.m._bp(sd + "LowerLeg")
		var ft: Vector3 = k.m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		_wraps(k, kn.lerp(ft, 0.1), kn.lerp(ft, 0.42), 6, 0.071, 0.067, 0.0165, 0.01, wh, sd + "LowerLeg")
		_wraps(k, kn.lerp(ft, 0.84), kn.lerp(ft, 0.98), 3, 0.054, 0.052, 0.012, 0.006, wh.darkened(0.08), sd + "LowerLeg")
	# yelek: bele oturan, kapalı, önde fermuar
	var v_key := [[N + 0.012, nk.x + 0.03, nk.y + 0.03, nk.z - 0.03], [N - 0.05, ch.x * 0.92, ch.y * 0.9, ch.z * 0.98], [C - 0.03, ch.x + 0.026, ch.y + 0.034, ch.z - 0.03],
		[H + 0.12, wa.x + 0.022, wa.y + 0.026, wa.z - 0.024], [H + 0.03, bl.x + 0.02, bl.y + 0.022, bl.z - 0.022]]
	var vf = func(a: float, y: float, _u: float) -> float:
		var rib: float = smoothstep(H + 0.1, H + 0.07, y)
		return 0.005 * sin(a * 6.0 + y * 20.0) + rib * 0.012 * sin(y * 150.0)
	_gar(k, {"keys": v_key, "ny": 30, "na": 64, "closed": true, "fold": vf, "col": func(a, _y, _u):
		return gn.darkened(0.24) if absf(wrapf(a, -PI, PI)) < 0.022 else gn, "shade": 5.0})
	# fermuar + göğüs kapakları + cepler
	var zp := []
	for j in 16:
		zp.append(_on(v_key, 0.0, lerpf(N - 0.015, H + 0.035, float(j) / 15.0), 0.018))
	_bd(k, zp, 0.0052, 0.0028, Color(0.26, 0.28, 0.25))
	for sg in [1.0, -1.0]:
		# göğüste kalın dolgu kapak: kumaş üstüne binen kavisli kenar
		_patch(k, v_key, C - 0.055, sg * 0.5, 0.058, 0.045, 0.1, gn.lightened(0.05), gn.darkened(0.28), -sg * 0.08)
		_patch(k, v_key, H + 0.135, sg * 0.56, 0.05, 0.03, 0.12, gn.lightened(0.03), gn.darkened(0.3), 0.0)
		_patch(k, v_key, C - 0.04, PI + sg * 0.58, 0.062, 0.058, 0.07, gn.darkened(0.04), gn.darkened(0.3), sg * 0.05)
	# kalın yaka: boynu saran, arkası yüksek, kıvrık yastık
	var col_rows := []
	for j in 7:
		var t := float(j) / 6.0
		var ro := []
		for i in 40:
			var a := TAU * i / 40.0 - PI
			var back: float = smoothstep(0.4, 2.2, absf(a))
			var r: float = 1.0 + 0.5 * sin(t * PI)
			var yy: float = N + 0.005 + (0.075 + 0.035 * back) * (1.0 - t)
			var w: float = (nk.x + 0.013) + 0.024 * r * sin(t * PI) + 0.012 * t
			var zf: float = (nk.y + 0.014) + 0.024 * r * sin(t * PI) + 0.012 * t
			var zb: float = (nk.z - 0.014) - 0.024 * r * sin(t * PI) - 0.012 * t
			var q: Vector2 = SE.El.sup(a, w, zf, zb)
			ro.append(Vector3(q.x, yy, q.y))
		col_rows.append(ro)
	k.grid(col_rows, true, func(i, j, _p):
		var c0: Color = gn.lightened(0.04)
		if absf(float(i) - 20.0) < 0.6:
			return c0.darkened(0.45)
		return c0.darkened(0.14) if j == 0 else c0, func(_i, _j, p): return k.torso_skin(p.y))
	# bel kemeri: yelek altı
	_sash(k, v_key, H + 0.04, 0.02, 0.004, dk.darkened(0.15), 0.1)
	# kızıl üst: iki ön kanat + arka yırtmaç; omuzda hafif kalkık, baldıra iner
	var hem := H - 0.34
	var keys := [[N + 0.0, nk.x + 0.055, nk.y + 0.04, nk.z - 0.05], [N - 0.05, ch.x * 1.06, ch.y * 0.98, ch.z * 1.06], [C - 0.03, ch.x + 0.05, ch.y + 0.06, ch.z - 0.056],
		[H + 0.12, wa.x + 0.065, wa.y + 0.06, wa.z - 0.075], [H - 0.04, hp.x + 0.055, hp.y + 0.05, hp.z - 0.08], [hem, hp.x + 0.105, hp.y + 0.075, hp.z - 0.085]]
	var op = func(y: float) -> float:
		return lerpf(0.5, 0.86, smoothstep(N, C - 0.04, y)) + 0.12 * smoothstep(H + 0.02, hem, y)
	var vent = func(y: float) -> float: return 0.14 * smoothstep(H - 0.08, hem, y)
	var fold = func(a: float, y: float, _u: float) -> float:
		var t: float = clampf((H + 0.06 - y) / (H + 0.06 - hem), 0.0, 1.0)
		return t * t * (0.05 * sin(a * 6.0 + 0.5) + 0.024 * sin(a * 11.0 + 2.1)) + (1.0 - t) * 0.007 * sin(a * 4.0 + y * 13.0)
	for sg in [1.0, -1.0]:
		var g := _gar(k, {"keys": keys, "ny": 42, "na": 44, "fold": func(a, y, u): return fold.call(a, y, u),
			"span": func(y):
				var a0: float = op.call(y)
				var a1: float = PI - float(vent.call(y))
				return Vector2(a0, a1) if sg > 0.0 else Vector2(-a1, -a0),
			"col": func(_a, _y, _u): return rd, "inner": rl, "skin": func(p): return k.cloth_skin(p, hem), "lip": 0.008})
		var fe: Array = g["ea"] if sg > 0.0 else g["eb"]
		_bd(k, fe, 0.014, 0.0045, rd.darkened(0.2), false, func(p): return k.cloth_skin(p, hem))
		var hm := []
		for p in g["hem"]:
			hm.append(p + Vector3(0, 0.014, 0))
		_bd(k, hm, 0.012, 0.004, rd.darkened(0.2), false, func(p): return k.cloth_skin(p, hem))
# ------------------------------------------------------------------ Kurama (ref Unkai): açık gri kimono, beyaz-turuncu-yeşil kat yaka, geniş çan kol, kalın obi, pileli hakama
static func _kurama(k) -> void:
	var gy := Color(0.68, 0.71, 0.76)
	var wh := Color(0.9, 0.89, 0.86)
	var og := Color(0.78, 0.47, 0.18)
	var gn := Color(0.31, 0.48, 0.42)
	var hk := Color(0.3, 0.36, 0.42)
	var ob := Color(0.22, 0.27, 0.33)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = k.M(C - 0.03, k.UA)
	var wa: Vector3 = k.M(H + 0.12, k.UA)
	var bw: Vector3 = k.M(H + 0.06, 0.3)
	var hp: Vector3 = k.M(H - 0.04, 0.3)
	var nk: Vector3 = k.M(N + 0.02, 0.09)
	var yb: float = H + 0.075
	var base := func(p: float) -> Array:
		return [[N + 0.022 + p * 0.1, nk.x + 0.008 + p, nk.y + 0.008 + p, nk.z - 0.008 - p], [N - 0.045, ch.x * 0.84 + p * 1.2, ch.y * 0.8 + p * 1.2, ch.z * 0.92 - p * 1.2], [C - 0.03, ch.x + 0.012 + p, ch.y + 0.014 + p, ch.z - 0.012 - p],
			[H + 0.13, wa.x + 0.014 + p, wa.y + 0.016 + p, wa.z - 0.014 - p], [yb - 0.03, bw.x + 0.012 + p, bw.y + 0.014 + p, bw.z - 0.014 - p]]
	# üç iç kat: her biri bir öncekinden biraz daha açık V yapar, sol kanat sağın üstüne biner
	var layers := [[wh, 0.0, 0.14], [og, 0.012, 0.27]]
	for l in layers:
		var kk: Array = base.call(float(l[1]))
		var e0: float = l[2]
		var cc: Color = l[0]
		_gar(k, {"keys": kk, "ny": 22, "na": 52, "col": func(_a, _y, _u): return cc, "lip": 0.004,
			"span": func(y):
				var e: float = lerpf(e0, -0.62, smoothstep(N + 0.02, C - 0.17, y))
				return Vector2(e, TAU - lerpf(e0, -0.3, smoothstep(N + 0.02, C - 0.17, y)))})
	# kimono: geniş yaka bandıyla, göğüste serbest, obiye girer
	var keys: Array = base.call(0.03)
	keys[2] = [C - 0.03, ch.x + 0.05, ch.y + 0.052, ch.z - 0.048]
	keys[3] = [H + 0.13, wa.x + 0.055, wa.y + 0.056, wa.z - 0.05]
	var ef = func(y: float) -> float: return lerpf(0.46, -0.58, smoothstep(N + 0.02, C - 0.17, y))
	var ef2 = func(y: float) -> float: return TAU - lerpf(0.46, -0.26, smoothstep(N + 0.02, C - 0.17, y))
	var fold = func(a: float, y: float, u: float) -> float:
		var near: float = smoothstep(C - 0.16, yb, y)
		return near * (0.03 * sin(a * 9.0 + 1.0) + 0.012 * sin(a * 16.0)) + 0.008 * sin(a * 3.0 + y * 9.0) - 0.03 * smoothstep(0.86, 1.0, u)
	var g := _gar(k, {"keys": keys, "ny": 30, "na": 76, "span": func(y): return Vector2(ef.call(y), ef2.call(y)), "fold": fold, "col": func(_a, _y, _u): return gy, "inner": gy.darkened(0.4), "lip": 0.007})
	# yaka: boyundan göğse iki kanat + ense üzerinden geçen geniş kumaş bant
	var edge := []
	var n_keep := 19
	var ea: Array = g["ea"]
	var eb: Array = g["eb"]
	for i in range(n_keep, -1, -1):
		edge.append(ea[i])
	for i in range(1, 12):
		var t := float(i) / 12.0
		var a: float = lerpf(float(ef.call(float(keys[0][0]))), float(ef2.call(float(keys[0][0]))), t)
		edge.append(_on(keys, a, float(keys[0][0]) + 0.004 + 0.008 * sin(t * PI), 0.0))
	for i in n_keep + 1:
		edge.append(eb[i])
	_bd(k, edge, 0.021, 0.0055, gn, false, Callable(), 0.25)
	var ed2 := []
	for p in edge:
		ed2.append(p + _out(p) * 0.0058)
	_bd(k, ed2, 0.0035, 0.0018, gn.darkened(0.3), false, Callable(), 0.25)
	# geniş çan kollar: önden arkaya uzayan ağız, bilekte serbest
	var sl_p := [[0.0, 0.05], [0.2, 0.084], [0.55, 0.096], [0.82, 0.106], [1.0, 0.112]]
	var ar_p := [[0.0, 0.058], [0.5, 0.05], [0.85, 0.041], [1.0, 0.04]]
	for sd in ["Left", "Right"]:
		_tb(k, _under_arm(k, sd), [sd + "UpperArm", sd + "LowerArm"], func(t, _a, _d): return Vector2(_pr(ar_p, t), 0.0), func(_t, _a): return wh.darkened(0.08), 14, 12, Color(0.08, 0.07, 0.07), 0.0)
		_tb(k, _arm_path(k, sd, 0.86, 0.14), [sd + "UpperArm", sd + "LowerArm"], func(t, a, _d0):
			var d: Vector3 = _d0
			var fl: float = 1.0 + 0.3 * smoothstep(0.3, 0.95, t) * absf(d.z)
			var f: float = (0.003 + 0.0065 * t) * sin(a * 6.0 + t * 7.0) + 0.0024 * sin(a * 11.0 + t * 12.0)
			return Vector2(_pr(sl_p, t) * fl, f), func(t, _a): return gn if t > 0.97 else gy, 26, 26, gy.darkened(0.5), 0.75)
	# hakama: pileli geniş paça
	var hk_p := [[0.0, 0.098], [0.3, 0.108], [0.62, 0.135], [1.0, 0.148]]
	for sd in ["Left", "Right"]:
		_tb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], func(t, a, _d):
			var f: float = 0.0085 * sin(a * 7.0 + 0.6) * (0.55 + 0.45 * t) + 0.0028 * sin(a * 14.0 + t * 4.0)
			return Vector2(_pr(hk_p, t), f), func(_t, _a): return hk, 28, 30, hk.darkened(0.55))
	# hakama üstü: belden kalçaya pileli kısım, bacakları örter
	var hkeys := [[yb + 0.005, bw.x + 0.05, bw.y + 0.05, bw.z - 0.05], [H - 0.03, hp.x + 0.045, hp.y + 0.056, hp.z - 0.056], [H - 0.17, hp.x + 0.03, hp.y + 0.05, hp.z - 0.05]]
	var hfold = func(a: float, y: float, _u: float) -> float:
		var d: float = smoothstep(yb, H - 0.04, y)
		var pl: float = sin(a * 7.0 + 0.6)
		return d * (0.04 * pl + 0.012 * sin(a * 14.0))
	_gar(k, {"keys": hkeys, "ny": 16, "na": 84, "closed": true, "fold": hfold, "col": func(_a, _y, _u): return hk, "inner": hk.darkened(0.5), "shade": 5.0, "skin": func(p): return k.cloth_skin(p, H - 0.17)})
	# koshi-ita: arkada obinin üstüne binen sert levha
	var plate := []
	for j in 5:
		var v := float(j) / 4.0
		var y: float = lerpf(yb + 0.075, yb - 0.04, v)
		var hw: float = lerpf(0.05, 0.1, v)
		var ro := []
		for i in 7:
			var a: float = PI + lerpf(hw, -hw, float(i) / 6.0) * 3.5
			ro.append(_on(hkeys, a, minf(y, yb), 0.05) + Vector3(0, y - minf(y, yb), 0))
		plate.append(ro)
	k.grid(plate, false, func(_i, j, _p): return hk.lightened(0.05) if j < 4 else hk.darkened(0.2), func(_i, _j, p): return k.torso_skin(p.y))
	# obi: kalın, iki kat; önde sıkı düğüm ve iki sarkan uç
	var okeys: Array = base.call(0.03)
	_sash(k, okeys, yb, 0.04, 0.012, ob, 0.16)
	_sash(k, okeys, yb + 0.014, 0.012, 0.027, ob.lightened(0.09), 0.08)
	var kp := _on(okeys, -0.25, yb, 0.0)
	kp += _out(kp) * 0.04
	var nr := []
	for j in 5:
		var v := lerpf(-1.0, 1.0, float(j) / 4.0)
		var ro := []
		for i in 9:
			var w := TAU * i / 8.0
			var r: float = sqrt(maxf(0.0, 1.0 - v * v * 0.86))
			ro.append(kp + Vector3(cos(w) * 0.03 * r + v * 0.002, v * -0.022, sin(w) * 0.016 * r))
		nr.append(ro)
	k.grid(nr, true, func(i, _j, _p): return ob.lightened(0.12) if i % 4 == 1 else ob.lightened(0.05), func(_i, _j, _p): return [["Hips", 0.6], ["Spine", 0.4]])
	var hsk = func(p): return k.cloth_skin(p, H - 0.17)
	_tail(k, hkeys, hfold, -0.2, 0.1, yb - 0.03, H - 0.15, 0.024, ob.lightened(0.08), hsk)
	_tail(k, hkeys, hfold, -0.32, -0.12, yb - 0.03, H - 0.09, 0.02, ob, hsk)
# ------------------------------------------------------------------ Chinoike (ref Chinoike_Clan): açık gri uzun kollu iç, çapraz bağlı koyu yelek + yırtmaçlı etek kanatları, boyunluk, kızıl bel bağı, bol şalvar + baldır sargısı
static func _chinoike(k) -> void:
	var lg := Color(0.58, 0.59, 0.6)
	var ve := Color(0.36, 0.37, 0.4)
	var tr := Color(0.34, 0.35, 0.38)
	var dk := Color(0.15, 0.15, 0.18)
	var rd := Color(0.44, 0.09, 0.12)
	var wr := Color(0.72, 0.72, 0.7)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = k.M(C - 0.03, k.UA)
	var wa: Vector3 = k.M(H + 0.12, k.UA)
	var bw: Vector3 = k.M(H + 0.06, 0.3)
	var hp: Vector3 = k.M(H - 0.04, 0.3)
	var nk: Vector3 = k.M(N + 0.02, 0.09)
	var yb: float = H + 0.06
	# iç gömlek: kapalı, kalçada serbest
	var inner := [[N + 0.03, nk.x + 0.008, nk.y + 0.008, nk.z - 0.008], [N - 0.05, ch.x * 0.84, ch.y * 0.8, ch.z * 0.92], [C - 0.03, ch.x + 0.012, ch.y + 0.014, ch.z - 0.012],
		[H + 0.12, wa.x + 0.012, wa.y + 0.014, wa.z - 0.012], [H - 0.04, hp.x + 0.02, hp.y + 0.02, hp.z - 0.02], [H - 0.13, hp.x + 0.03, hp.y + 0.03, hp.z - 0.03]]
	_gar(k, {"keys": inner, "ny": 26, "na": 48, "closed": true, "col": func(_a, _y, _u): return lg, "inner": lg.darkened(0.5), "skin": func(p): return k.cloth_skin(p, H - 0.13),
		"fold": func(a, y, _u): return 0.03 * smoothstep(H, H - 0.13, y) * sin(a * 7.0 + 0.8)})
	SE.body_layer(k, [[H - 0.02, hp.x, hp.y, hp.z], [H - 0.14, hp.x * 0.72, hp.y * 0.74, hp.z * 0.74]], 4, 28, func(_i, _j, _p): return tr.darkened(0.25))
	var arm_p := [[0.0, 0.056], [0.2, 0.062], [0.42, 0.061], [0.55, 0.058], [0.8, 0.05], [0.88, 0.043], [1.0, 0.042]]
	var leg_p := [[0.0, 0.104], [0.28, 0.114], [0.5, 0.116], [0.66, 0.108], [0.735, 0.068], [1.0, 0.055]]
	for sd in ["Left", "Right"]:
		_tb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], func(t, a, _d):
			var e: float = exp(-pow((t - 0.48) / 0.1, 2.0))
			return Vector2(_pr(arm_p, t), e * 0.0042 * sin(t * 60.0 + a * 1.5) + 0.0016 * sin(a * 3.0 + t * 10.0)), func(_t, _a): return lg)
		# şalvar: bol, baldırda büzülür; büzgüde sık kıvrım
		_tb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], func(t, a, _d):
			var g: float = exp(-pow((t - 0.67) / 0.07, 2.0))
			var f: float = 0.0028 * sin(a * 3.0 + t * 9.0) + g * 0.0075 * sin(a * 9.0 + 0.5) + exp(-pow((t - 0.47) / 0.09, 2.0)) * 0.004 * sin(t * 48.0 + a * 2.0)
			return Vector2(_pr(leg_p, t), f), func(_t, _a): return tr, 34, 20)
		var kn: Vector3 = k.m._bp(sd + "LowerLeg")
		var ft: Vector3 = k.m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		for i in 9:
			var t: float = float(i) / 8.0
			k.wrap_turn(kn.lerp(ft, lerpf(0.5, 0.97, t)), ft - kn, lerpf(0.0695, 0.058, t), 0.0165, 0.011, wr.darkened(0.42) if i % 2 == 1 else wr, [[sd + "LowerLeg", 1.0]])
		var el: Vector3 = k.m._bp(sd + "LowerArm")
		var hd: Vector3 = k.m._bp(sd + "Hand")
		_wraps(k, el.lerp(hd, 0.72), el.lerp(hd, 0.93), 4, 0.0475, 0.044, 0.012, 0.007, dk.lightened(0.1), sd + "LowerArm")
	# yelek: göğüste çapraz bindirme, kolsuz, bağın altında biter
	var keys := [[N + 0.004, nk.x + 0.032, nk.y + 0.03, nk.z - 0.03], [N - 0.05, ch.x * 0.95, ch.y * 0.9, ch.z * 1.0], [C - 0.03, ch.x + 0.03, ch.y + 0.034, ch.z - 0.03],
		[H + 0.12, wa.x + 0.03, wa.y + 0.034, wa.z - 0.03], [yb - 0.02, bw.x + 0.016, bw.y + 0.018, bw.z - 0.018]]
	var ef = func(y: float) -> float: return lerpf(0.42, -0.52, smoothstep(N, H + 0.14, y))
	var ef2 = func(y: float) -> float: return TAU - lerpf(0.42, -0.34, smoothstep(N, H + 0.14, y))
	var fold = func(a: float, y: float, u: float) -> float:
		var near: float = exp(-pow((y - yb) / 0.07, 2.0))
		return near * (0.028 * sin(a * 10.0 + 0.3) + 0.012 * sin(a * 17.0)) + 0.006 * sin(a * 5.0 + y * 15.0) - 0.028 * smoothstep(0.85, 1.0, u)
	var g := _gar(k, {"keys": keys, "ny": 30, "na": 72, "span": func(y): return Vector2(ef.call(y), ef2.call(y)), "fold": fold, "col": func(_a, _y, _u): return ve, "inner": ve.darkened(0.45), "shade": 4.5})
	_bd(k, g["ea"], 0.011, 0.004, ve.darkened(0.3))
	_bd(k, g["eb"], 0.011, 0.004, ve.darkened(0.3))
	# etek kanatları: önde ve arkada, yanları yırtmaçlı
	var low := [[yb, bw.x + 0.024, bw.y + 0.026, bw.z - 0.026], [H - 0.04, hp.x + 0.044, hp.y + 0.04, hp.z - 0.04], [H - 0.25, hp.x + 0.082, hp.y + 0.07, hp.z - 0.07]]
	var lfold = func(a: float, y: float, _u: float) -> float: return smoothstep(yb, H - 0.2, y) * (0.05 * sin(a * 5.0 + 1.0) + 0.02 * sin(a * 11.0))
	for c0 in [0.0, PI]:
		var lg2 := _gar(k, {"keys": low, "ny": 18, "na": 34, "span": func(y):
				var w: float = lerpf(1.4, 1.14, smoothstep(yb, H - 0.25, y))
				return Vector2(float(c0) - w, float(c0) + w),
			"fold": lfold, "col": func(_a, _y, _u): return ve, "inner": ve.darkened(0.45), "skin": func(p): return k.cloth_skin(p, H - 0.25), "shade": 4.5})
		var hm := []
		for p in lg2["hem"]:
			hm.append(p + Vector3(0, 0.012, 0))
		_bd(k, hm, 0.009, 0.003, ve.darkened(0.3), false, func(p): return k.cloth_skin(p, H - 0.25))
	# kızıl bel bağı: dar, iki kat, sol yanda düğüm + sarkan uçlar
	_sash(k, keys, yb, 0.024, 0.013, rd, 0.2)
	var kp: Vector3 = _on(keys, 1.0, yb, 0.0)
	kp += _out(kp) * 0.028
	var nr := []
	for j in 5:
		var v: float = lerpf(-1.0, 1.0, float(j) / 4.0)
		var r: float = sqrt(maxf(0.0, 1.0 - v * v * 0.8))
		var ro := []
		for i in 8:
			var w := TAU * i / 8.0
			ro.append(kp + Vector3(cos(w) * 0.019 * r, -v * 0.018, sin(w) * 0.016 * r))
		nr.append(ro)
	k.grid(nr, true, func(i, _j, _p): return rd.darkened(0.16) if i % 3 == 0 else rd, func(_i, _j, _p): return [["Hips", 1.0]])
	var lsk = func(p): return k.cloth_skin(p, H - 0.25)
	_tail(k, low, lfold, 0.98, 0.08, yb - 0.012, H - 0.235, 0.018, rd, lsk)
	_tail(k, low, lfold, 0.9, -0.14, yb - 0.012, H - 0.17, 0.015, rd.darkened(0.14), lsk)
	# koyu boyunluk: boynu saran, büzgülü, göğse dökülen
	var ck := [[N + 0.072, nk.x + 0.012, nk.y + 0.014, nk.z - 0.014], [N + 0.03, nk.x + 0.032, nk.y + 0.036, nk.z - 0.034], [N - 0.012, nk.x + 0.052, nk.y + 0.058, nk.z - 0.05], [N - 0.05, nk.x + 0.066, nk.y + 0.085, nk.z - 0.05]]
	_gar(k, {"keys": ck, "ny": 16, "na": 40, "closed": true, "inner": dk.darkened(0.3), "col": func(_a, _y, _u): return dk.lightened(0.04), "shade": 3.5,
		"fold": func(a, y, _u): return 0.05 * sin((y - N) * 115.0 + 1.4 * sin(a * 2.0)) + 0.016 * sin(a * 5.0 + y * 20.0)})
# ------------------------------------------------------------------ Iburi (ref Iburi_Ichizoku): kısa kollu bağcıklı köylü gömleği, ip kuşak, yamalar, diz altı paça
static func _iburi(k) -> void:
	var cl := Color(0.45, 0.37, 0.27)
	var pn := Color(0.33, 0.28, 0.22)
	var pt := Color(0.36, 0.29, 0.2)
	var pt2 := Color(0.52, 0.45, 0.33)
	var st := Color(0.74, 0.67, 0.52)
	var rope := Color(0.69, 0.62, 0.47)
	var sk: Color = k.m.look.get("skin", Color(0.9, 0.72, 0.58))
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = k.M(C - 0.03, k.UA)
	var wa: Vector3 = k.M(H + 0.12, k.UA)
	var bl: Vector3 = k.M(H + 0.05, 0.3)
	var hp: Vector3 = k.M(H - 0.04, 0.3)
	var nk: Vector3 = k.M(N + 0.02, 0.09)
	# açık göğüs teni (bağcık yırtmacının altı) + kalça astarı
	SE.body_layer(k, [[N + 0.03, nk.x, nk.y, nk.z], [N - 0.05, ch.x * 0.72, ch.y * 0.78, ch.z * 0.86], [C - 0.1, ch.x * 0.9, ch.y * 0.98, ch.z * 0.95]], 8, 28, func(_i, _j, _p): return sk)
	SE.body_layer(k, [[H + 0.08, bl.x, bl.y, bl.z], [H - 0.05, hp.x + 0.012, hp.y + 0.012, hp.z - 0.012], [H - 0.13, hp.x * 0.7, hp.y * 0.72, hp.z * 0.72]], 8, 32, func(_i, _j, _p): return pn.darkened(0.1))
	# çıplak kol ve baldır
	var bare := [[0.0, 0.052], [0.3, 0.05], [0.55, 0.046], [0.78, 0.043], [1.0, 0.036]]
	for sd in ["Left", "Right"]:
		_tb(k, _under_arm(k, sd), [sd + "UpperArm", sd + "LowerArm"], func(t, _a, _d): return Vector2(_pr(bare, t), 0.0), func(_t, _a): return sk, 20, 12, sk.darkened(0.4), 0.0)
		var lp := _leg_path(k, sd)
		k.tube([lp[1], lp[2]], [sd + "LowerLeg"], [[0.0, 0.056], [0.3, 0.058], [0.72, 0.043], [1.0, 0.04]], func(_t, _a, ins): return sk.darkened(0.4) if ins else sk, 14, 12)
	# bol pantolon: dizin altında biter, kıvrımlar dizde ve paçada toplanır
	var trouser := [[0.0, 0.1], [0.28, 0.097], [0.55, 0.086], [0.72, 0.083], [1.0, 0.08]]
	for sd in ["Left", "Right"]:
		_tb(k, _leg_path(k, sd, 0.36), [sd + "UpperLeg", sd + "LowerLeg"], func(t, a, _d):
			var kn: float = exp(-pow((t - 0.72) / 0.14, 2.0))
			var f: float = (0.0065 * kn + 0.003) * sin(t * 34.0 + a * 2.0) + 0.0035 * sin(a * 5.0 + t * 7.0)
			return Vector2(_pr(trouser, t), f), func(_t, _a): return pn, 28, 18)
		_patch_leg(k, sd, pt, st)
	# gömlek: kuşakta büzülür, üstünde kabarır, altında serbest düşer
	var hem := H - 0.17
	var yb := H + 0.05
	var keys := [[N + 0.016, nk.x + 0.016, nk.y + 0.018, nk.z - 0.018], [N - 0.045, ch.x * 0.9, ch.y * 0.84, ch.z * 0.94], [N - 0.085, ch.x + 0.012, ch.y * 0.95, ch.z * 1.04], [C - 0.03, ch.x + 0.03, ch.y + 0.034, ch.z - 0.03],
		[H + 0.14, wa.x + 0.042, wa.y + 0.046, wa.z - 0.042], [yb, bl.x + 0.012, bl.y + 0.014, bl.z - 0.014], [H - 0.03, hp.x + 0.03, hp.y + 0.03, hp.z - 0.03], [hem, hp.x + 0.058, hp.y + 0.05, hp.z - 0.05]]
	var slit_y := N - 0.125
	var slit = func(y: float) -> float: return lerpf(0.02, 0.2, smoothstep(slit_y, N - 0.03, y))
	var fold = func(a: float, y: float, _u: float) -> float:
		var near := exp(-pow((y - yb) / 0.055, 2.0))
		var low := smoothstep(yb, hem, y)
		return near * (0.034 * sin(a * 11.0 + 0.7) + 0.016 * sin(a * 17.0 + 2.0)) + low * (0.04 * sin(a * 6.0 + 1.2) + 0.018 * sin(a * 11.0 + 0.3)) + 0.006 * sin(a * 4.0 + y * 14.0)
	var g := _gar(k, {"keys": keys, "ny": 44, "na": 80, "span": func(y): return Vector2(slit.call(y), TAU - slit.call(y)), "fold": fold,
		"col": func(_a, _y, _u): return cl, "inner": cl.darkened(0.45), "skin": func(p): return k.cloth_skin(p, hem), "lip": 0.006})
	# yaka biyesi: boyun çevresi + yırtmaç kenarları, ham dikişli etek kıvrımı
	var top: Array = (g["rows"][0] as Array).duplicate()
	_bd(k, top, 0.0085, 0.004, cl.darkened(0.14), false, Callable(), 0.5)
	var ntop := int(float(slit_y - N - 0.016) / (hem - N - 0.016) * 44.0) + 2
	_bd(k, (g["ea"] as Array).slice(0, ntop), 0.006, 0.003, cl.darkened(0.14))
	_bd(k, (g["eb"] as Array).slice(0, ntop), 0.006, 0.003, cl.darkened(0.14))
	var hm := []
	for p in g["hem"]:
		hm.append(p + Vector3(0, 0.016, 0) + _out(p) * 0.001)
	_bd(k, hm, 0.0028, 0.0016, cl.darkened(0.3), false, func(p): return k.cloth_skin(p, hem))
	# bağcık: yırtmaçta çapraz, uçları sarkar
	var cc := pn.darkened(0.3)
	var rows_l := 4
	for i in rows_l:
		var y0 := lerpf(N - 0.03, slit_y + 0.008, float(i) / rows_l)
		var y1 := lerpf(N - 0.03, slit_y + 0.008, float(i + 1) / rows_l)
		for sg in [1.0, -1.0]:
			var p0 := _on(keys, sg * (float(slit.call(y0)) + 0.05), y0, 0.05)
			var p1 := _on(keys, -sg * (float(slit.call(y1)) + 0.05), y1, 0.05)
			_cord(k, [p0, p0.lerp(p1, 0.5) + Vector3(0, 0, 0.004), p1], 0.0028, cc)
	var kn := _on(keys, 0.0, N - 0.03, 0.07)
	for sg in [1.0, -1.0]:
		_cord(k, [kn, kn + Vector3(sg * 0.012, -0.03, 0.004), kn + Vector3(sg * 0.018, -0.07, 0.0)], 0.0026, cc)
	# kısa kollar: dirsek üstünde biter, ağzı bol, omuz dikişi
	for sd in ["Left", "Right"]:
		var ap := _arm_path(k, sd, 1.0, 0.14)
		var pth := [ap[0], (ap[0] as Vector3).lerp(ap[1], 0.8)]
		_tb(k, pth, [sd + "UpperArm"], func(t, a, _d):
			var f: float = (0.002 + 0.004 * t) * sin(a * 3.0 + t * 8.0) + 0.0018 * sin(a * 7.0)
			return Vector2(lerpf(0.046, 0.074, smoothstep(0.0, 0.45, t)), f), func(t, _a): return cl.darkened(0.16) if t > 0.9 or absf(t - 0.2) < 0.022 else cl, 14, 18, cl.darkened(0.55), 0.75)
	# yamalar: göğüs, sırt, omuz altı
	_patch(k, keys, C - 0.1, 1.05, 0.042, 0.038, 0.035, pt2, st, 0.16)
	_patch(k, keys, H + 0.2, -2.3, 0.055, 0.045, 0.04, pt, st, -0.12)
	_patch(k, keys, H - 0.09, -0.85, 0.04, 0.034, 0.075, pt, st, 0.2, func(p): return k.cloth_skin(p, hem))
	# ip kuşak: iki tur burgulu, önde düğüm, iki uç
	var bk: Array = SE.El.key_at(keys, yb)
	for t in 2:
		var pts := []
		var yy := yb + 0.009 - 0.018 * t
		for i in 48:
			var a := TAU * i / 48.0 - PI
			var q: Vector2 = SE.El.sup(a, float(bk[1]) + 0.012, float(bk[2]) + 0.012, float(bk[3]) - 0.012)
			pts.append(Vector3(q.x, yy + 0.002 * sin(a * 3.0 + t), q.y))
		_cord(k, pts, 0.0085, rope.darkened(0.05 * t), true, Callable(), 1.5, 7)
	var kp := _on(keys, 0.42, yb, 0.0) + _out(_on(keys, 0.42, yb)) * 0.018
	var hs := func(_p): return [["Hips", 1.0]]
	var kr := []
	for i in 10:
		var q := TAU * i / 10.0
		kr.append(kp + Vector3(cos(q) * 0.014, sin(q) * 0.012, sin(q * 2.0) * 0.004))
	_cord(k, kr, 0.0078, rope.lightened(0.05), true, hs, 2.0, 7)
	var csk = func(p): return k.cloth_skin(p, hem)
	for e in [[0.42, 0.1, yb - 0.17], [0.46, -0.13, yb - 0.13]]:
		var pts := []
		for i in 9:
			var t := float(i) / 8.0
			var a: float = float(e[0]) + float(e[1]) * t
			var y: float = lerpf(yb - 0.012, float(e[2]), t)
			pts.append(_on(keys, a, y, float(fold.call(a, y, 0.5)) + 0.05))
		_cord(k, pts, 0.0058, rope, false, csk, 1.5, 6)


## Pantolon diz yaması (bacak kemiğine bağlı)
static func _patch_leg(k, sd: String, col: Color, st: Color, r0 := 0.087) -> void:
	var kn: Vector3 = k.m._bp(sd + "LowerLeg")
	var bo := func(_p): return [[sd + "UpperLeg", 0.5], [sd + "LowerLeg", 0.5]]
	var rows := []
	for j in 6:
		var v := lerpf(1.0, -1.0, float(j) / 5.0)
		var ro := []
		for i in 7:
			var u := lerpf(-1.0, 1.0, float(i) / 6.0)
			var q := u * 0.72
			var e := maxf(absf(u), absf(v))
			var r := r0 + 0.0065 * (1.0 - e * e * e)
			ro.append(kn + Vector3(sin(q) * r, v * 0.05 + u * 0.006, cos(q) * r))
		rows.append(ro)
	k.grid(rows, false, func(i, j, _p): return col.darkened(0.06 * float((i + j) % 3)), func(_i, _j, p): return bo.call(p))
	for sg in [-1.0, 1.0]:
		for n in 5:
			var v := lerpf(-0.8, 0.8, float(n) / 4.0)
			var q: float = sg * 0.65
			var p := kn + Vector3(sin(q) * (r0 + 0.0075), v * 0.05, cos(q) * (r0 + 0.0075))
			var o := Vector3(sin(q), 0, cos(q))
			k.strip([p + Vector3(0.006 * sg, 0, 0), p - Vector3(0.006 * sg, 0, 0)], [o, o], 0.0024, 0.0013, st, false, bo)


# ------------------------------------------------------------------ Funato (ref Shizuku): çapraz kapanan beyaz cübbe, kabarık dirsek kolları, koyu uzun kol, bele bağlı ip, önü yırtmaçlı etek
static func _funato(k) -> void:
	var wh := Color(0.86, 0.87, 0.88)
	var bl := Color(0.25, 0.44, 0.62)
	var sl := Color(0.25, 0.3, 0.38)
	var tr := Color(0.72, 0.74, 0.78)
	var N: float = k.N
	var H: float = k.H
	var C: float = k.C
	var ch: Vector3 = k.M(C - 0.03, k.UA)
	var wa: Vector3 = k.M(H + 0.12, k.UA)
	var bw: Vector3 = k.M(H + 0.06, 0.3)
	var hp: Vector3 = k.M(H - 0.04, 0.3)
	var nk: Vector3 = k.M(N + 0.02, 0.09)
	var hem: float = lerpf(H, k.K, 1.12)
	var yb: float = H + 0.06
	# iç: pelvis + bol pantolon + koyu kol
	SE.body_layer(k, [[H + 0.1, wa.x, wa.y, wa.z], [H - 0.05, hp.x + 0.01, hp.y + 0.01, hp.z - 0.01], [H - 0.14, hp.x * 0.7, hp.y * 0.72, hp.z * 0.72]], 8, 32, func(_i, _j, _p): return tr.darkened(0.15))
	var leg_p := [[0.0, 0.09], [0.45, 0.08], [0.56, 0.074], [0.82, 0.066], [1.0, 0.056]]
	var arm_p := [[0.0, 0.056], [0.3, 0.053], [0.8, 0.042], [1.0, 0.042]]
	for sd in ["Left", "Right"]:
		_tb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], func(t, a, _d):
			var e: float = smoothstep(0.78, 1.0, t)
			return Vector2(_pr(leg_p, t), (0.002 + 0.0045 * e) * sin(t * 50.0 + a * 2.0)), func(_t, _a): return tr, 26, 16)
		_tb(k, _under_arm(k, sd), [sd + "UpperArm", sd + "LowerArm"], func(t, a, _d):
			var e: float = smoothstep(0.5, 0.95, t)
			return Vector2(_pr(arm_p, t), 0.0028 * e * sin(t * 70.0 + a * 1.5)), func(_t, _a): return sl, 24, 16, Color(0.08, 0.07, 0.07), 0.0)
	# koyu boğaz bandı
	SE.body_layer(k, [[N + 0.062, nk.x + 0.006, nk.y + 0.008, nk.z - 0.008], [N + 0.012, nk.x + 0.012, nk.y + 0.012, nk.z - 0.012], [N - 0.05, ch.x * 0.7, ch.y * 0.74, ch.z * 0.85]], 8, 28, func(_i, _j, _p): return sl.darkened(0.3))
	# cübbe: tek parça, sol kanat göğüsten sağ yana çapraz biner; belden aşağı önü yırtmaçlı
	var keys := [[N + 0.022, nk.x + 0.024, nk.y + 0.024, nk.z - 0.024], [N - 0.045, ch.x * 0.93, ch.y * 0.88, ch.z * 1.0], [C - 0.03, ch.x + 0.034, ch.y + 0.04, ch.z - 0.036],
		[H + 0.13, wa.x + 0.044, wa.y + 0.05, wa.z - 0.044], [yb, bw.x + 0.018, bw.y + 0.02, bw.z - 0.02], [H - 0.04, hp.x + 0.04, hp.y + 0.038, hp.z - 0.038], [hem, hp.x + 0.09, hp.y + 0.075, hp.z - 0.075]]
	var a0f = func(y: float) -> float:
		var d: float = lerpf(0.14, -1.0, smoothstep(N + 0.02, C - 0.13, y))
		return lerpf(d, 0.07, smoothstep(yb + 0.03, yb - 0.09, y))
	var a1f = func(y: float) -> float:
		return TAU + lerpf(0.3, -0.2, smoothstep(yb + 0.02, yb - 0.08, y))
	var fold = func(a: float, y: float, u: float) -> float:
		var near: float = exp(-pow((y - yb) / 0.05, 2.0))
		var low: float = smoothstep(yb, hem, y)
		var f: float = near * (0.03 * sin(a * 12.0 + 0.4) + 0.014 * sin(a * 19.0)) + low * (0.05 * sin(a * 5.0 + 0.9) + 0.022 * sin(a * 9.0 + 2.2)) + 0.005 * sin(a * 4.0 + y * 12.0)
		return f - 0.03 * smoothstep(0.86, 1.0, u) * (1.0 - low)
	var sk = func(p): return k.cloth_skin(p, hem)
	var g := _gar(k, {"keys": keys, "ny": 56, "na": 88, "span": func(y): return Vector2(a0f.call(y), a1f.call(y)), "fold": fold, "col": func(_a, _y, _u): return wh, "inner": wh.darkened(0.42), "skin": sk, "shade": 4.5})
	# mavi biye: bindirme kenarı boyunca, yaka çevresi ve etek ucu
	_bd(k, g["ea"], 0.011, 0.004, bl, false, sk)
	var ey: Array = (g["eb"] as Array)
	var n_low := 0
	for i in ey.size():
		if float(ey[i].y) > yb - 0.08:
			n_low = i
	_bd(k, ey.slice(n_low, ey.size()), 0.011, 0.004, bl, false, sk)
	var hm := []
	for p in g["hem"]:
		hm.append(p + Vector3(0, 0.013, 0))
	_bd(k, hm, 0.012, 0.004, bl, false, sk)
	# dik yuvarlak yaka: kalın, üst kenarı kıvrık
	var col_k := [[N + 0.058, nk.x + 0.02, nk.y + 0.022, nk.z - 0.022], [N + 0.038, nk.x + 0.031, nk.y + 0.033, nk.z - 0.033], [N + 0.01, nk.x + 0.036, nk.y + 0.038, nk.z - 0.038]]
	_gar(k, {"keys": col_k, "ny": 6, "na": 36, "closed": true, "col": func(_a, y, _u): return bl if y > N + 0.048 else wh, "inner": sl.darkened(0.3)})
	# kapanış düğümleri: kanat boyunca iplik ilik
	for i in 3:
		var y: float = lerpf(N - 0.04, C - 0.12, float(i) / 2.0)
		var a: float = float(a0f.call(y)) + 0.05
		var p := _on(keys, a, y, 0.03)
		var r2 := []
		for q in 8:
			var w := TAU * q / 8.0
			r2.append(p + Vector3(cos(w) * 0.008, sin(w) * 0.006, 0.0))
		_cord(k, r2, 0.0026, bl.darkened(0.15), true)
	# kabarık dirsek kolu: omuzda dikişli, dirsekte kıvrık manşet
	for sd in ["Left", "Right"]:
		var ap := _arm_path(k, sd, 1.0, 0.14)
		var p1: Vector3 = ap[1]
		var hd: Vector3 = k.m._bp(sd + "Hand")
		var e1: Vector3 = p1.lerp(hd, 0.1)
		var prof := [[0.0, 0.046], [0.3, 0.082], [0.66, 0.114], [0.88, 0.1], [1.0, 0.083]]
		_tb(k, [ap[0], p1, e1], [sd + "UpperArm", sd + "LowerArm"], func(t, a, d):
			var bag: float = 0.014 * smoothstep(-0.2, -1.0, d.y) * sin(t * PI)
			var f: float = (0.0045 + 0.004 * sin(t * PI)) * sin(a * 5.0 + t * 6.0) + 0.0022 * sin(a * 9.0 + t * 15.0)
			return Vector2(_pr(prof, t) + bag, f), func(_t, _a): return wh, 22, 22, wh.darkened(0.5), 0.75)
		# manşet: kalın kıvrık bant, biyeli
		var dir := (e1 - p1).normalized()
		_tb(k, [e1 - dir * 0.034, e1 + dir * 0.016], [sd + "LowerArm"], func(t, a, _d):
			return Vector2(0.09 + 0.006 * sin(t * PI), 0.0016 * sin(a * 6.0)), func(t, _a): return bl if t > 0.7 else wh.darkened(0.06), 6, 22, wh.darkened(0.5))
	# bel ipi: iki tur, sol önde fiyonk; iki uç eteğe sarkar
	var bk: Array = SE.El.key_at(keys, yb)
	for t in 2:
		var pts := []
		for i in 52:
			var a := TAU * i / 52.0 - PI
			var q: Vector2 = SE.El.sup(a, float(bk[1]) + 0.009, float(bk[2]) + 0.009, float(bk[3]) - 0.009)
			pts.append(Vector3(q.x, yb + 0.007 - 0.014 * t, q.y))
		_cord(k, pts, 0.0058, wh.darkened(0.08), true, Callable(), 1.2, 6)
	var kp: Vector3 = _on(keys, 0.3, yb, 0.0) + _out(_on(keys, 0.3, yb)) * 0.016
	var hs = func(_p): return [["Hips", 1.0]]
	for sg in [1.0, -1.0]:
		var lp := []
		for i in 11:
			var q := TAU * i / 10.0
			lp.append(kp + Vector3(sg * (0.034 - 0.034 * cos(q)) * 0.75, sin(q) * 0.015 + 0.002, 0.004 * sin(q * 2.0)))
		_cord(k, lp, 0.0044, wh.darkened(0.03), false, hs, 0.0, 6)
	_tail(k, keys, fold, 0.3, 0.16, yb - 0.01, yb - 0.3, 0.0075, wh.darkened(0.1), sk)
	_tail(k, keys, fold, 0.34, 0.42, yb - 0.01, yb - 0.23, 0.0075, wh.darkened(0.16), sk)
