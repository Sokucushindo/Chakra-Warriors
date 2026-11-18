extends RefCounted
## Elle modellenmiş setler, parti b: taki, uzushio, jinmon, kusa, yu, shimo. Örnek: set_el.gd içindeki _shugonin.
const SE = preload("res://scripts/actors/set_el.gd")
const A = preload("res://scripts/actors/set_v2_a.gd")

const DONE := ["set_taki", "set_uzushio", "set_jinmon", "set_kusa", "set_yu", "set_shimo"]


static func recipe(k, sid: String) -> void:
	match sid:
		"set_taki": _taki(k)
		"set_uzushio": _uzushio(k)
		"set_jinmon": _jinmon(k)
		"set_kusa": _kusa(k)
		"set_yu": _yu(k)
		"set_shimo": _shimo(k)


# ------------------------------------------------------------------ yardımcılar
static func _hx(s: String) -> Color:
	return Color.html(s)


static func _fit(k: SE.El) -> Dictionary:
	return {"ch": k.M(k.C - 0.03, k.UA), "wa": k.M(k.H + 0.12, k.UA), "hp": k.M(k.H - 0.04, 0.3), "nk": k.M(k.N + 0.02, 0.09)}


## Bedene oturan kesit anahtarları; p: kumaş payı, top: boyundan yukarı, low: [[y, ek genişlik, ek derinlik], ...] kalçadan aşağı
static func _keys(k: SE.El, f: Dictionary, p: float, top := 0.005, low := []) -> Array:
	var ch: Vector3 = f["ch"]
	var wa: Vector3 = f["wa"]
	var hp: Vector3 = f["hp"]
	var nk: Vector3 = f["nk"]
	var ks := [[k.N + top, nk.x + p, nk.y + p, nk.z - p]]
	if top > 0.025:
		ks.append([k.N + 0.02, nk.x + p * 1.3, nk.y + p * 1.3, nk.z - p * 1.3])
	ks.append([k.N - 0.06, ch.x * 0.98 + p * 0.4, ch.y * 0.92 + p * 0.4, ch.z * 1.02 - p * 0.4])
	ks.append([k.C - 0.03, ch.x + p, ch.y + p, ch.z - p])
	ks.append([k.H + 0.12, wa.x + p, wa.y + p, wa.z - p])
	ks.append([k.H - 0.04, hp.x + p, hp.y + p, hp.z - p])
	for l in low:
		ks.append([l[0], hp.x + p + float(l[1]), hp.y + p + float(l[2]), hp.z - p - float(l[2])])
	return ks


static func _sp(keys: Array, a: float, y: float, extra := 0.0, n := 2.5) -> Vector3:
	var s: Array = SE.El.key_at(keys, y)
	var q: Vector2 = SE.El.sup(a, float(s[1]) + extra, float(s[2]) + extra, float(s[3]) - extra, n)
	return Vector3(q.x, y, q.y)


## Yüzeyde verilen x'in ön (front) ya da arka z'si
static func _zon(keys: Array, x: float, y: float, pad: float, front: bool, n := 2.5) -> float:
	var s: Array = SE.El.key_at(keys, y)
	var u := clampf(absf(x) / (float(s[1]) + pad), 0.0, 0.995)
	var r := pow(1.0 - pow(u, n), 1.0 / n)
	return r * (float(s[2]) + pad) if front else r * (float(s[3]) - pad)


static func _out(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z).normalized()


static func _gw(t: float, c: float, w: float) -> float:
	var d := (t - c) / w
	return exp(-d * d)


## Kıvrım gölgesi: vadi koyulaşır, sırt az açılır
static func _sh(c: Color, v: float, dk := 5.0, lt := 2.0) -> Color:
	return c.darkened(clampf(-v * dk, 0.0, 0.32)).lightened(clampf(v * lt, 0.0, 0.09))


## Yaka / atkı / ip: boyun kemiğini izlemez, göğüste kalır
static func _sk_up(k: SE.El) -> Callable:
	return func(p: Vector3) -> Array: return k.torso_skin(minf(p.y, k.C))


static func _sk_t(k: SE.El) -> Callable:
	return _sk_up(k)


## Etek / uzun giysi ağırlığı: kumaş bacakla açılır
static func _sk_cloth(k: SE.El, hem: float, leg := 0.58) -> Callable:
	return func(p: Vector3) -> Array: return k.cloth_skin(p, hem, leg)


static func _val(x, y: float) -> float:
	return float(x.call(y)) if x is Callable else float(x)


## Kumaş yüzeyi. o: top, hem, hemf(a), a0, a1 (sayı ya da y->açı), na, ny, closed, fold(a, y), uf(u), col (renk ya da (a, y, kıvrım)->renk), skin, lining, n
static func _shell(k: SE.El, keys: Array, o: Dictionary) -> Dictionary:
	var ny: int = o.get("ny", 36)
	var na: int = o.get("na", 64)
	var top: float = o.get("top", float(keys[0][0]))
	var hem: float = o.get("hem", float(keys[keys.size() - 1][0]))
	var closed: bool = o.get("closed", false)
	var a0 = o.get("a0", -PI)
	var a1 = o.get("a1", PI)
	var fold: Callable = o.get("fold", Callable())
	var uf: Callable = o.get("uf", Callable())
	var hemf: Callable = o.get("hemf", Callable())
	var cc = o.get("col", Color.WHITE)
	var n: float = o.get("n", 2.5)
	var skf: Callable = o.get("skin", _sk_t(k))
	var rows := []
	var cols := []
	var ea := []
	var eb := []
	var cnt: int = na if closed else na + 1
	for j in ny + 1:
		var v := float(j) / ny
		var yn := lerpf(top, hem, v)
		var e0 := _val(a0, yn)
		var e1 := _val(a1, yn)
		var ro := []
		var cr := []
		for i in cnt:
			var u := float(i) / na
			var a := lerpf(e0, e1, u)
			var y := lerpf(top, float(hemf.call(a)), v) if hemf.is_valid() else yn
			var fv: float = float(fold.call(a, y)) if fold.is_valid() else 0.0
			var g: float = float(uf.call(u)) if uf.is_valid() else 0.0
			var p := _sp(keys, a, y, 0.0, n)
			var s := 1.0 + fv + g
			ro.append(Vector3(p.x * s, y, p.z * s))
			cr.append(cc.call(a, y, fv) if cc is Callable else _sh(cc, fv))
		rows.append(ro)
		cols.append(cr)
		ea.append(ro[0])
		eb.append(ro[cnt - 1])
	k.grid(rows, closed, func(i, j, _p): return cols[j][i], func(_i, _j, p): return skf.call(p))
	if o.has("lining"):
		var lc: Color = o["lining"]
		var inn := []
		for ro in rows:
			var r2 := []
			for q in ro:
				r2.append(Vector3(q.x * 0.982, q.y, q.z * 0.982))
			r2.reverse()
			inn.append(r2)
		k.grid(inn, closed, func(_i, _j, _p): return lc, func(_i, _j, p): return skf.call(p))
	return {"rows": rows, "ea": ea, "eb": eb}


static func _cr(c: Array, sub: int, closed := false) -> Array:
	var n := c.size()
	var o := []
	var last: int = n if closed else n - 1
	for i in last:
		var p0: Vector3 = c[(i - 1 + n) % n] if closed or i > 0 else c[i]
		var p1: Vector3 = c[i]
		var p2: Vector3 = c[(i + 1) % n]
		var p3: Vector3 = c[(i + 2) % n] if closed or i + 2 < n else c[(i + 1) % n]
		for s in sub:
			o.append(p1.cubic_interpolate(p2, p0, p3, float(s) / sub))
	if not closed:
		o.append(c[n - 1])
	return o


## Yuvarlak kesitli kordon; tw > 0 ise burgulu ip (gerçek girinti + vadide koyu)
static func _cord(k: SE.El, pts: Array, r: float, col: Color, skf: Callable, closed := false, tw := 0.0, seg := 8, flat := 1.0) -> void:
	var n := pts.size()
	var rows := []
	var cols := []
	var nv := Vector3.ZERO
	var s := 0.0
	var cnt: int = n + 1 if closed else n
	for j in cnt:
		var p: Vector3 = pts[j % n]
		var pa: Vector3 = pts[(j - 1 + n) % n] if closed or j > 0 else pts[0]
		var pb: Vector3 = pts[(j + 1) % n] if closed or j < n - 1 else pts[n - 1]
		var t: Vector3 = (pb - pa).normalized()
		if j > 0:
			s += (p - pts[(j - 1) % n]).length()
		if nv == Vector3.ZERO:
			nv = (Vector3.UP - t * t.dot(Vector3.UP))
			if nv.length() < 0.1:
				nv = Vector3.BACK - t * t.dot(Vector3.BACK)
		nv = (nv - t * t.dot(nv)).normalized()
		var b: Vector3 = nv.cross(t).normalized()
		var cap := 1.0 if closed or (j > 0 and j < n - 1) else 0.25
		var ro := []
		var cr := []
		for i in seg:
			var a := TAU * i / seg
			var w := sin(3.0 * a + s / r * 1.25) if tw > 0.0 else 0.0
			var rr := r * cap * (1.0 + tw * w)
			ro.append(p + nv * cos(a) * rr * flat + b * sin(a) * rr)
			cr.append(col.darkened(clampf(-w * 0.34, 0.0, 0.34)) if tw > 0.0 else col)
		rows.append(ro)
		cols.append(cr)
	k.grid(rows, true, func(i, j, _p): return cols[j][i], func(_i, _j, p): return skf.call(p))


## Yüzeye oturan yuvarlak köşeli yastık: cep, plaka, kapak
static func _patch(k: SE.El, keys: Array, ca: float, cy: float, ha: float, hy: float, h: float, col, skf: Callable, base := 0.0, nx := 14, ny := 12, n := 2.5) -> void:
	var rows := []
	var cols := []
	for j in ny + 1:
		var v := 1.0 - 2.0 * float(j) / ny
		var ro := []
		var cr := []
		for i in nx + 1:
			var u := 2.0 * float(i) / nx - 1.0
			var e := 1.0 - pow(pow(absf(u), 6.0) + pow(absf(v), 6.0), 1.0 / 6.0)
			var rim := smoothstep(0.0, 0.2, e)
			var p := _sp(keys, ca + u * ha, cy + v * hy, base, n)
			ro.append(p + _out(p) * lerpf(-0.004, h, rim))
			var c0: Color = col.call(u, v) if col is Callable else col
			cr.append(c0.darkened(0.2 * (1.0 - smoothstep(0.1, 0.55, rim))))
		rows.append(ro)
		cols.append(cr)
	k.grid(rows, false, func(i, j, _p): return cols[j][i], func(_i, _j, p): return skf.call(p))


static func _stud(k: SE.El, p: Vector3, o: Vector3, r: float, col: Color, skf: Callable, h := 0.005) -> void:
	_cord(k, [p - o * 0.002, p + o * h * 0.55, p + o * h], r, col, skf, false, 0.0, 8)


## Kapalı kuşak: kesiti kabarık, kenarı koyu
static func _belt(k: SE.El, keys: Array, y: float, hw: float, pad: float, col: Color, wr := 0.0, na := 72) -> void:
	var s: Array = SE.El.key_at(keys, y)
	var rows := []
	for j in 7:
		var t := float(j) / 6.0
		var bu := 0.008 * sin(t * PI) + pad
		var ro := []
		for i in na:
			var a := TAU * i / na - PI
			var q: Vector2 = SE.El.sup(a, float(s[1]) + bu, float(s[2]) + bu, float(s[3]) - bu)
			var w := 1.0 + wr * sin(a * 5.0 + t * 3.0 + sin(a * 2.0))
			ro.append(Vector3(q.x * w, y + hw - t * hw * 2.0, q.y * w))
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.2) if j in [0, 6] else col, func(_i, _j, p): return k.torso_skin(minf(p.y, k.C)))


static func _prof(prof: Array, t: float) -> float:
	for i in prof.size() - 1:
		if t <= float(prof[i + 1][0]):
			return lerpf(prof[i][1], prof[i + 1][1], smoothstep(0.0, 1.0, inverse_lerp(float(prof[i][0]), float(prof[i + 1][0]), t)))
	return float(prof[prof.size() - 1][1])


## Kıvrımlı uzuv tüpü. fold(t, a) -> yarıçap oranı; col(t, a, iç mi, kıvrım) -> renk
static func _limb(k: SE.El, path: Array, bones: Array, prof: Array, fold: Callable, col: Callable, rings := 24, seg := 16) -> void:
	var L := 0.0
	var cum := [0.0]
	for i in path.size() - 1:
		L += (path[i + 1] - path[i]).length()
		cum.append(L)
	var rows := []
	var cols := []
	var info := []
	for j in rings + 4:
		var t := minf(1.0, float(j) / rings)
		var inside := j > rings
		var sv := t * L
		var q := 0
		while q < path.size() - 2 and sv > float(cum[q + 1]):
			q += 1
		var u := clampf((sv - float(cum[q])) / maxf(0.0001, float(cum[q + 1]) - float(cum[q])), 0.0, 1.0)
		var ctr: Vector3 = (path[q] as Vector3).lerp(path[q + 1], u)
		var d0: Vector3 = (path[q + 1] - path[q]).normalized()
		var d1: Vector3 = d0
		if u > 0.75 and q < path.size() - 2:
			d1 = d0.lerp((path[q + 2] - path[q + 1]).normalized(), (u - 0.75) * 2.0).normalized()
		var up := -d1
		var fw: Vector3 = (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
		var ri := up.cross(fw).normalized()
		var r := _prof(prof, t)
		if j == rings + 1:
			r *= 0.93
		elif j == rings + 2:
			r *= 0.78
			ctr -= d1 * 0.012
		elif j == rings + 3:   # iç kapak: ağızdan içerisi boş görünmesin
			r *= 0.06
			ctr -= d1 * 0.018
		var ro := []
		var cr := []
		for i in seg:
			var a := TAU * i / seg - PI
			var fv: float = 0.0 if inside else float(fold.call(t, a))
			var rr := r * (1.0 + fv)
			ro.append(ctr + ri * sin(a) * rr + fw * cos(a) * rr)
			cr.append(col.call(t, a, inside, fv))
		rows.append(ro)
		cols.append(cr)
		var bl := [[bones[q], 1.0]]
		if u > 0.72 and q + 1 < bones.size():
			var b2 := smoothstep(0.72, 1.0, u) * 0.5
			bl = [[bones[q], 1.0 - b2], [bones[q + 1], b2]]
		elif u < 0.28 and q > 0:
			var b2 := (1.0 - smoothstep(0.0, 0.28, u)) * 0.5
			bl = [[bones[q], 1.0 - b2], [bones[q - 1], b2]]
		info.append(bl)
	k.grid(rows, true, func(i, j, _p): return cols[j][i], func(_i, j, _p): return info[j])


static func _cut(path: Array, te: float) -> Array:
	if te >= 0.999:
		return path
	var L := 0.0
	for i in path.size() - 1:
		L += (path[i + 1] - path[i]).length()
	var left := L * te
	var o := [path[0]]
	for i in path.size() - 1:
		var d: float = (path[i + 1] - path[i]).length()
		if left <= d:
			o.append((path[i] as Vector3).lerp(path[i + 1], left / d))
			return o
		o.append(path[i + 1])
		left -= d
	return o


static func _arm_path(k: SE.El, sd: String) -> Array:
	var p0: Vector3 = k.m._bp(sd + "UpperArm")
	var p1: Vector3 = k.m._bp(sd + "LowerArm")
	var p2: Vector3 = k.m._bp(sd + "Hand")
	var ch: Vector3 = k.m._bp("UpperChest")
	return [p0.lerp(Vector3(0.0, ch.y, ch.z), 0.2), p1, p2.lerp(p1, 0.06)]


static func _leg_path(k: SE.El, sd: String) -> Array:
	var p0: Vector3 = k.m._bp(sd + "UpperLeg")
	var p1: Vector3 = k.m._bp(sd + "LowerLeg")
	var p2: Vector3 = k.m._bp(sd + "Foot")
	return [p0 + Vector3(0, 0.05, 0), p1, p2 + Vector3(0, 0.07, 0)]


## Yol üzerinde t oranındaki nokta: [merkez, yön, parça no]
static func _path_at(path: Array, t: float) -> Array:
	var L := 0.0
	for i in path.size() - 1:
		L += (path[i + 1] - path[i]).length()
	var left := L * t
	for i in path.size() - 1:
		var d: float = (path[i + 1] - path[i]).length()
		if left <= d or i == path.size() - 2:
			return [(path[i] as Vector3).lerp(path[i + 1], clampf(left / d, 0.0, 1.0)), (path[i + 1] - path[i]).normalized(), i]
		left -= d
	return [path[0], Vector3.DOWN, 0]


## Kol: te kolun ne kadarına kadar; fold(t, a, taraf)
static func _arms(k: SE.El, prof: Array, fold: Callable, col: Callable, te := 1.0, rings := 24, seg := 16) -> void:
	for sd in ["Left", "Right"]:
		var s := 1.0 if sd == "Left" else -1.0
		_limb(k, _cut(_arm_path(k, sd), te), [sd + "UpperArm", sd + "LowerArm"], prof, func(t, a): return fold.call(t, a, s), col, rings, seg)


static func _legs(k: SE.El, prof: Array, fold: Callable, col: Callable, rings := 30, seg := 18) -> void:
	for sd in ["Left", "Right"]:
		var s := 1.0 if sd == "Left" else -1.0
		_limb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], prof, func(t, a): return fold.call(t, a, s), col, rings, seg)


## İç giysi: gövdede üst kumaşla aynı ağırlık (dışarı taşmaz), yalnız boğaz boynu izler
static func _inner(k: SE.El, keys: Array, ny: int, na: int, col: Color) -> void:
	var sf := func(p: Vector3) -> Array: return k.torso_skin(p.y if p.y > k.N - 0.005 else minf(p.y, k.C))
	_shell(k, keys, {"closed": true, "ny": ny, "na": na, "col": col, "skin": sf})


## Pantolonun kalça kısmı: bacak tüplerinin üstünü kapatır
static func _pelvis(k: SE.El, f: Dictionary, col: Color, p := 0.012) -> void:
	var wa: Vector3 = f["wa"]
	var hp: Vector3 = f["hp"]
	var keys := [[k.H + 0.14, wa.x + p, wa.y + p, wa.z - p], [k.H - 0.04, hp.x + p, hp.y + p, hp.z - p], [k.H - 0.12, hp.x * 0.96 + p, hp.y * 0.96 + p, hp.z * 0.96 - p], [k.H - 0.19, hp.x * 0.42, hp.y * 0.55, hp.z * 0.55]]
	_shell(k, keys, {"closed": true, "ny": 16, "na": 40, "col": col, "skin": _sk_cloth(k, k.H - 0.19, 0.62)})


## Uzva oturan sargı: yarıçap uzvun kendi profilinden, turlar birbirine değer (n = 0: aralığa göre otomatik)
static func _wrap_limb(k: SE.El, path: Array, bones: Array, prof: Array, t0: float, t1: float, hw: float, tilt: float, col: Color, gap := 0.002, n := 0) -> void:
	var L := 0.0
	for i in path.size() - 1:
		L += (path[i + 1] - path[i]).length()
	var cnt: int = n if n > 0 else maxi(1, ceili((t1 - t0) * L / (hw * 1.72)) + 1)
	for i in cnt:
		var t := lerpf(t0, t1, float(i) / maxf(1.0, cnt - 1.0))
		var q := _path_at(path, t)
		k.wrap_turn(q[0], q[1], _prof(prof, t) + gap, hw, tilt, col.darkened(0.06 * float(i % 3)), [[bones[int(q[2])], 1.0]])


## Kumaşa oturan sarkan şerit (kuşak ucu, atkı ucu): yüzeyin kıvrımını izler
static func _tail(k: SE.El, keys: Array, ca: float, y0: float, y1: float, drift: float, hw: float, d: float, pad: float, col: Color, skf: Callable, fold := Callable(), n := 2.5) -> void:
	var pts := []
	var ou := []
	for j in 19:
		var t := float(j) / 18.0
		var y := lerpf(y0, y1, t)
		var a := ca + drift * t + 0.05 * sin(t * 7.0) * t
		var fv: float = float(fold.call(a, y)) if fold.is_valid() else 0.0
		var p := _sp(keys, a, y, 0.0, n)
		var o := _out(p)
		pts.append(Vector3(p.x * (1.0 + fv), y, p.z * (1.0 + fv)) + o * pad)
		ou.append(o)
	k.strip(pts, ou, hw, d, col, false, skf)


## Omuzdan karşı kalçaya inip sırttan dönen kapalı yol
static func _over(k: SE.El, keys: Array, s: float, xs: float, y_top: float, y_low: float, pad: float, n := 34) -> Array:
	var pts := []
	var low: Array = SE.El.key_at(keys, y_low)
	var xl: float = (float(low[1]) + pad) * 0.985
	for j in n + 1:
		var t := float(j) / n
		var y := lerpf(y_top, y_low, t)
		var x := lerpf(s * xs, -s * xl, t)
		pts.append(Vector3(x, y, _zon(keys, x, y, pad, true)))
	for j in range(n, -1, -1):
		var t := float(j) / n
		var y := lerpf(y_top, y_low, t)
		var x := lerpf(s * xs, -s * xl, t)
		pts.append(Vector3(x, y, _zon(keys, x, y, pad, false)))
	var zf: float = (pts[0] as Vector3).z
	var zb: float = (pts[pts.size() - 1] as Vector3).z
	pts.append(Vector3(s * xs, y_top + 0.03, lerpf(zb, zf, 0.3)))
	pts.append(Vector3(s * xs, y_top + 0.04, lerpf(zb, zf, 0.5)))
	pts.append(Vector3(s * xs, y_top + 0.03, lerpf(zb, zf, 0.7)))
	return pts


static func _outs_of(pts: Array, up := 0.0) -> Array:
	var o := []
	for p in pts:
		o.append((_out(p) + Vector3.UP * up).normalized())
	return o


# ------------------------------------------------------------------ Takigakure (ref Shibuki): teal tünik, kıvrık yaka, önde koyu şerit, çapraz deri kayış + mavi bağ
static func _taki(k: SE.El) -> void:
	var f := _fit(k)
	var te := _hx("2f7478")
	var nav := _hx("1d3350")
	var gr := _hx("566a76")
	var wh := _hx("d8d5c6")
	var br := _hx("4b3425")
	var lt := _hx("74b3b0")
	var N := k.N
	var H := k.H
	var hem := H - 0.31
	var skt := _sk_t(k)
	_inner(k, _keys(k, f, 0.006, 0.03), 20, 36, nav)
	_pelvis(k, f, gr.darkened(0.12))
	# pantolon: dizde bol, baldıra doğru daralır
	var pf := func(t: float, a: float, _s: float) -> float:
		return 0.12 * _gw(t, 0.44, 0.09) * sin(a * 3.0 + t * 16.0) + 0.08 * _gw(t, 0.2, 0.14) * sin(a * 2.0 - t * 12.0)
	var lp := [[0.0, 0.09], [0.26, 0.088], [0.46, 0.078], [0.62, 0.06], [1.0, 0.045]]
	var ap := [[0.0, 0.06], [0.5, 0.05], [1.0, 0.041]]
	_legs(k, lp, pf, func(_t, _a, ins, v): return gr.darkened(0.4) if ins else _sh(gr, v, 1.5, 0.5))
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], lp, 0.68, 0.99, 0.0165, 0.008, wh)
	# koyu önkol + bilek sargısı, üstünde bol yarım kol
	_arms(k, ap, func(_t, _a, _s): return 0.0, func(_t, _a, ins, _v): return nav.darkened(0.4) if ins else nav)
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], ap, 0.8, 0.98, 0.0115, 0.005, wh)
	_arms(k, [[0.0, 0.076], [0.45, 0.078], [0.8, 0.083], [1.0, 0.088]], func(t: float, a: float, _s: float) -> float:
		return 0.09 * _gw(t, 0.72, 0.16) * sin(a * 3.0 + t * 14.0) + 0.06 * _gw(t, 0.3, 0.2) * sin(a * 2.0 + t * 8.0), func(_t, _a, ins, v): return te.darkened(0.45) if ins else _sh(te, v, 2.6), 0.66)
	# tünik gövdesi
	var keys := _keys(k, f, 0.02, 0.006, [[H - 0.14, 0.034, 0.03], [hem, 0.066, 0.06]])
	var sku := _sk_up(k)
	var cf := func(a: float, y: float) -> float:
		var d := _gw(y, H + 0.09, 0.08)
		return d * (0.02 * sin(a * 9.0 + 0.7) + 0.012 * sin(a * 17.0)) + 0.006 * sin(a * 4.0 + y * 13.0)
	_shell(k, keys, {"closed": true, "hem": H + 0.0, "ny": 26, "na": 60, "fold": cf, "col": te})
	# yan yırtmaçlı ön ve arka etek: adımda bacağı izler
	var sf := func(a: float, y: float) -> float:
		var t := clampf((H + 0.03 - y) / (H + 0.03 - hem), 0.0, 1.0)
		return t * (0.055 * sin(a * 7.0 + 0.6) + 0.028 * sin(a * 13.0 + 1.9))
	var sks := _sk_cloth(k, hem)
	for pn in [[-1.36, 1.36], [PI - 1.36, PI + 1.36]]:
		var r := _shell(k, keys, {"top": H + 0.04, "hem": hem, "a0": pn[0], "a1": pn[1], "ny": 18, "na": 34, "fold": sf, "col": te, "skin": sks, "lining": te.darkened(0.42)})
		var last: Array = r["rows"][18]
		_cord(k, last, 0.0055, lt, sks)
		_cord(k, r["ea"], 0.005, lt, sks)
		_cord(k, r["eb"], 0.005, lt, sks)
	# önde koyu şerit, kuşak, kıvrık yaka
	_patch(k, keys, 0.0, (N - 0.09 + H + 0.09) * 0.5, 0.17, (N - 0.09 - H - 0.09) * 0.5, 0.005, nav, skt, 0.002, 6, 20)
	var col_pts := []
	for i in 56:
		var a := lerpf(0.12, TAU - 0.12, float(i) / 55.0)
		var dn := pow(absf(cos(a * 0.5)), 5.0)
		col_pts.append(_sp(keys, a, N + 0.012 - dn * 0.14, 0.012))
	_cord(k, col_pts, 0.019, lt, sku, false, 0.0, 10, 0.8)
	_belt(k, keys, H + 0.05, 0.036, 0.014, nav, 0.006)
	var bk: Vector3 = _sp(keys, -0.55, H + 0.05, 0.02)
	_cord(k, [bk + Vector3(-0.022, 0.012, 0.0), bk + Vector3(0.0, 0.0, 0.012), bk + Vector3(0.022, -0.012, 0.0)], 0.02, nav.lightened(0.06), skt, false, 0.0, 10)
	_tail(k, keys, -0.6, H + 0.03, hem + 0.05, -0.1, 0.024, 0.004, 0.006, nav, sks, sf)
	_tail(k, keys, -0.46, H + 0.03, hem + 0.12, 0.08, 0.021, 0.004, 0.009, nav.lightened(0.05), sks, sf)
	# çapraz deri kayış ve yanında mavi bağ
	var sh := _over(k, keys, 1.0, 0.12, N - 0.055, H + 0.05, 0.008)
	k.strip(sh, _outs_of(sh), 0.021, 0.006, br, true, sku)
	var sh2 := _over(k, keys, 1.0, 0.075, N - 0.05, H + 0.05, 0.01)
	_cord(k, sh2, 0.0065, _hx("2f4a9a"), sku, true, 0.0, 6)
	var bc: Vector3 = (sh[12] as Vector3) + Vector3(0, 0, 0.006)
	_cord(k, [bc + Vector3(-0.015, 0.012, 0.0), bc + Vector3(0.015, -0.012, 0.0)], 0.015, _hx("8a8d90"), sku, false, 0.0, 8, 0.45)


# ------------------------------------------------------------------ ortak: yaka, omuz plakası, örgü, kürk
## Boyun çevresinde önde V yapan yuvarlak yaka
static func _v_collar(k: SE.El, keys: Array, depth: float, r: float, pad: float, col: Color, flat := 0.8) -> void:
	var pts := []
	for i in 56:
		var a := lerpf(0.12, TAU - 0.12, float(i) / 55.0)
		pts.append(_sp(keys, a, k.N + 0.012 - pow(absf(cos(a * 0.5)), 5.0) * depth, pad))
	_cord(k, pts, r, col, _sk_up(k), false, 0.0, 10, flat)


## Sarmal giysinin yaka şeridi: alt uçtan boyuna, ense, öbür kanattan aşağı
static func _collar(k: SE.El, res: Dictionary, hw: float, d: float, col: Color, lo_a: int, lo_b: int) -> void:
	var ea: Array = res["ea"]
	var eb: Array = res["eb"]
	var top: Array = res["rows"][0]
	var pts := ea.slice(0, lo_a + 1)
	pts.reverse()
	pts.append_array(top.slice(1, top.size() - 1))
	pts.append_array(eb.slice(0, lo_b + 1))
	k.strip(pts, _outs_of(pts, 0.15), hw, d, col, false, _sk_up(k))


static func _frame(p0: Vector3, p1: Vector3) -> Array:
	var up: Vector3 = (p0 - p1).normalized()
	var fw: Vector3 = (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
	return [up.cross(fw).normalized(), fw]


## Üst kolu dıştan saran kavisli plaka; lames > 0 ise basamaklı
static func _sode(k: SE.El, sd: String, s: float, t0: float, t1: float, span: float, r: float, col: Color, lames: int, lin: Color, rim: Color) -> void:
	var p0: Vector3 = k.m._bp(sd + "UpperArm")
	var p1: Vector3 = k.m._bp(sd + "LowerArm")
	var fr := _frame(p0, p1)
	var bone := [[sd + "UpperArm", 1.0]]
	var rows := []
	var cols := []
	var ny := 6 * maxi(lames, 2)
	for j in ny + 1:
		var v := float(j) / ny
		var ctr: Vector3 = p0.lerp(p1, lerpf(t0, t1, v))
		var saw := fmod(v * lames, 1.0) if lames > 0 else 0.0
		var ro := []
		var cr := []
		for i in 19:
			var a := s * PI * 0.5 + lerpf(-span, span, float(i) / 18.0) * (1.0 + 0.16 * v)
			var rr := (r + 0.022 * v) * (1.0 + 0.09 * saw)
			ro.append(ctr + (fr[0] as Vector3) * sin(a) * rr + (fr[1] as Vector3) * cos(a) * rr)
			cr.append(col.darkened(0.26 * (1.0 - smoothstep(0.0, 0.3, saw))) if lames > 0 else col)
		rows.append(ro)
		cols.append(cr)
	var sf := func(_p: Vector3) -> Array: return bone
	k.grid(rows, false, func(i, j, _p): return cols[j][i], func(_i, _j, _p): return bone)
	var inn := []
	for ro in rows:
		var r2: Array = ro.duplicate()
		r2.reverse()
		inn.append(r2)
	k.grid(inn, false, func(_i, _j, _p): return lin, func(_i, _j, _p): return bone)
	_cord(k, rows[ny], 0.006, rim, sf)
	var e0 := []
	var e1 := []
	for ro in rows:
		e0.append(ro[0])
		e1.append(ro[18])
	_cord(k, e0, 0.005, rim, sf)
	_cord(k, e1, 0.005, rim, sf)


## Uzvu saran gerçek ağ: iki yönde sarmal ince kordon, uzvun profiline oturur
static func _lattice(k: SE.El, path: Array, bones: Array, prof: Array, t0: float, t1: float, n: int, turns: float, rr: float, col: Color) -> void:
	var bl := [[bones[int(_path_at(path, t1)[2])], 1.0]]
	var sf := func(_p: Vector3) -> Array: return bl
	for dr in [1.0, -1.0]:
		for c in n:
			var pts := []
			for j in 21:
				var t := float(j) / 20.0
				var tt := lerpf(t0, t1, t)
				var q := _path_at(path, tt)
				var fr := _frame(q[0], (q[0] as Vector3) + (q[1] as Vector3))
				var a: float = TAU * c / n + float(dr) * turns * TAU * t
				var r := _prof(prof, tt) + rr * 0.5
				pts.append((q[0] as Vector3) + (fr[0] as Vector3) * sin(a) * r + (fr[1] as Vector3) * cos(a) * r)
			_cord(k, pts, rr, col, sf, false, 0.0, 4)


## Uzuv çevresinde kürk bilezik
static func _fur(k: SE.El, ctr: Vector3, d: Vector3, r: float, ln: float, col: Color, bone: String) -> void:
	var fr := _frame(ctr, ctr + d)
	var dn: Vector3 = d.normalized()
	var bl := [[bone, 1.0]]
	var rows := []
	for j in 7:
		var v := float(j) / 6.0
		var ro := []
		for i in 36:
			var a := TAU * i / 36.0 - PI
			var nz := 0.82 + 0.12 * sin(i * 2.4) + 0.08 * sin(i * 5.1 + 1.0)
			var rr := r - 0.003 + (ln + 0.003) * sin(v * PI) * nz
			ro.append(ctr + dn * (v * ln * 1.1 - ln * 0.35) + (fr[0] as Vector3) * sin(a) * rr + (fr[1] as Vector3) * cos(a) * rr)
		rows.append(ro)
	k.grid(rows, true, func(_i, j, _p): return col.darkened(0.16 * absf(j - 3) / 3.0), func(_i, _j, _p): return bl)


# ------------------------------------------------------------------ Sorgu Birliği (ref Ibiki_Blazing): gri dik yakalı üniforma, açık önlü dik yakalı uzun siyah palto
static func _jinmon(k: SE.El) -> void:
	var f := _fit(k)
	var uni := _hx("4d4f5c")
	var coat := _hx("1a1a20")
	var cl := _hx("2c2c34")
	var me := _hx("8d919a")
	var wh := _hx("d9d6ca")
	var N := k.N
	var H := k.H
	var C := k.C
	var hem := k.K - 0.2
	var skt := _sk_t(k)
	var nk: Vector3 = f["nk"]
	_pelvis(k, f, uni.darkened(0.1))
	var pf := func(t: float, a: float, _s: float) -> float:
		return 0.1 * _gw(t, 0.45, 0.1) * sin(a * 3.0 + t * 15.0) + 0.14 * _gw(t, 0.72, 0.05) * sin(a * 5.0 + t * 20.0) + 0.06 * _gw(t, 0.2, 0.12) * sin(a * 2.0)
	var lp := [[0.0, 0.1], [0.3, 0.098], [0.5, 0.09], [0.72, 0.086], [0.79, 0.058], [1.0, 0.045]]
	_legs(k, lp, pf, func(_t, _a, ins, v): return uni.darkened(0.4) if ins else _sh(uni.darkened(0.08), v, 1.6, 0.6))
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], lp, 0.8, 0.99, 0.0165, 0.008, wh)
	# üniforma ceketi: kemerin altına iner
	var ik := _keys(k, f, 0.014, 0.005, [[H - 0.15, 0.022, 0.02]])
	var jf := func(a: float, y: float) -> float:
		return _gw(y, H + 0.09, 0.06) * 0.014 * sin(a * 11.0 + 0.5) + 0.004 * sin(a * 5.0 + y * 12.0)
	var jsk := _sk_cloth(k, H - 0.15, 0.4)
	var jr := _shell(k, ik, {"closed": true, "hem": H - 0.15, "ny": 30, "na": 56, "fold": jf, "col": uni, "lining": uni.darkened(0.4), "skin": jsk})
	_cord(k, jr["rows"][30] + [(jr["rows"][30] as Array)[0]], 0.005, uni.lightened(0.08), jsk)
	# dik yaka, düğme patı, göğüs cepleri
	var sc := [[N + 0.032, nk.x + 0.02, nk.y + 0.018, nk.z - 0.02], [N, nk.x + 0.024, nk.y + 0.022, nk.z - 0.024], [N - 0.03, nk.x + 0.05, nk.y + 0.05, nk.z - 0.05]]
	var cr := _shell(k, sc, {"a0": 0.16, "a1": TAU - 0.16, "ny": 6, "na": 30, "col": uni.lightened(0.05), "lining": uni.darkened(0.3)})
	_cord(k, cr["rows"][0], 0.0042, uni.lightened(0.14), skt)
	_cord(k, cr["ea"], 0.0042, uni.lightened(0.14), skt)
	_cord(k, cr["eb"], 0.0042, uni.lightened(0.14), skt)
	var py0 := N - 0.035
	var py1 := H - 0.14
	_patch(k, ik, 0.0, (py0 + py1) * 0.5, 0.11, (py0 - py1) * 0.5, 0.004, uni.lightened(0.05), skt, 0.002, 4, 24)
	for i in 6:
		var p := _sp(ik, 0.0, lerpf(py0 - 0.03, py1 + 0.03, float(i) / 5.0), 0.006)
		_stud(k, p, Vector3.BACK, 0.0085, me, skt, 0.004)
	for s in [1.0, -1.0]:
		var ca: float = float(s) * 0.62
		_patch(k, ik, ca, C - 0.045, 0.2, 0.05, 0.006, uni.darkened(0.04), skt, 0.0, 10, 8)
		_patch(k, ik, ca, C + 0.0, 0.225, 0.02, 0.0085, uni.lightened(0.06), skt, 0.004, 10, 5)
		var bp := _sp(ik, ca, C - 0.008, 0.012)
		_stud(k, bp, _out(bp), 0.0065, me, skt, 0.004)
	# kemer ve tokası
	_belt(k, ik, H + 0.055, 0.021, 0.005, _hx("15151a"))
	var bz := _sp(ik, 0.0, H + 0.055, 0.016)
	var fr := [Vector3(-0.034, 0.022, 0), Vector3(0.034, 0.022, 0), Vector3(0.034, -0.022, 0), Vector3(-0.034, -0.022, 0)]
	var bq := []
	for q in fr:
		bq.append(bz + (q as Vector3))
	_cord(k, _cr(bq, 3, true), 0.0042, me, skt, true, 0.0, 6)
	_cord(k, [bz + Vector3(-0.012, 0, 0.003), bz + Vector3(0.03, 0, 0.003)], 0.003, me, skt, false, 0.0, 5)
	# palto: arkası yırtmaçlı iki kanat, adımda bacağı izler
	var ck := _keys(k, f, 0.04, 0.005, [[H - 0.3, 0.075, 0.06], [hem, 0.15, 0.115]])
	var lk := _keys(k, f, 0.047, 0.005, [[H - 0.3, 0.082, 0.067], [hem, 0.157, 0.122]])
	var e := func(y: float) -> float:
		if y > H + 0.1:
			return lerpf(0.5, 0.74, smoothstep(H + 0.1, N, y))
		return lerpf(0.98, 0.5, smoothstep(hem, H + 0.1, y))
	var vent := func(y: float) -> float: return 0.14 * (1.0 - smoothstep(hem, H - 0.16, y))
	var cf := func(a: float, y: float) -> float:
		var t := clampf((H + 0.02 - y) / (H + 0.02 - hem), 0.0, 1.0)
		return t * t * (0.062 * sin(a * 5.0 + 0.4) + 0.03 * sin(a * 11.0 + 1.3)) + t * 0.012 * sin(a * 17.0) + (1.0 - t) * 0.006 * sin(a * 6.0 + y * 9.0)
	var ccf := func(a: float, y: float, v: float) -> Color: return _sh(coat, v, 3.0, 2.2).lightened(0.05 * (1.0 + sin(a * 2.0 + y)))
	var sks := _sk_cloth(k, hem)
	var pan := [[e, func(y: float) -> float: return PI - float(vent.call(y))], [func(y: float) -> float: return PI + float(vent.call(y)), func(y: float) -> float: return TAU - float(e.call(y))]]
	for q in pan:
		var r := _shell(k, ck, {"hem": hem, "a0": q[0], "a1": q[1], "ny": 48, "na": 34, "fold": cf, "col": ccf, "skin": sks, "lining": cl})
		var hm: Array = r["rows"][48]
		_cord(k, hm, 0.0055, cl, sks)
		_cord(k, r["ea"], 0.005, cl, sks)
		_cord(k, r["eb"], 0.005, cl, sks)
	# yakanın kıvrımı (göğse yatan klapa)
	var lw := func(y: float) -> float:
		var t := clampf((N - 0.02 - y) / (N - 0.02 - H - 0.08), 0.0, 1.0)
		return 0.6 * pow(1.0 - t, 0.8) + 0.015
	var lpl := _shell(k, lk, {"top": N - 0.02, "hem": H + 0.08, "a0": e, "a1": func(y: float) -> float: return float(e.call(y)) + float(lw.call(y)), "ny": 20, "na": 8, "fold": cf, "col": coat.lightened(0.07)})
	_cord(k, lpl["eb"], 0.005, cl.lightened(0.06), skt)
	var rp := _shell(k, lk, {"top": N - 0.02, "hem": H + 0.08, "a0": func(y: float) -> float: return TAU - float(e.call(y)) - float(lw.call(y)), "a1": func(y: float) -> float: return TAU - float(e.call(y)), "ny": 20, "na": 8, "fold": cf, "col": coat.lightened(0.07)})
	_cord(k, rp["ea"], 0.005, cl.lightened(0.06), skt)
	# yüksek dik palto yakası
	var hc := [[N + 0.092, nk.x + 0.078, nk.y + 0.06, nk.z - 0.08], [N + 0.03, nk.x + 0.058, nk.y + 0.052, nk.z - 0.06], [N - 0.03, nk.x + 0.07, nk.y + 0.06, nk.z - 0.07]]
	var hr := _shell(k, hc, {"a0": 0.78, "a1": TAU - 0.78, "ny": 10, "na": 34, "col": coat.lightened(0.05), "lining": cl})
	_cord(k, hr["rows"][0], 0.0055, cl.lightened(0.05), skt)
	_cord(k, hr["ea"], 0.005, cl.lightened(0.05), skt)
	_cord(k, hr["eb"], 0.005, cl.lightened(0.05), skt)
	# kollar, manşet kayışı
	var sp := [[0.0, 0.088], [0.42, 0.08], [0.56, 0.078], [0.9, 0.066], [1.0, 0.067]]
	_arms(k, sp, func(t: float, a: float, _s: float) -> float:
		return 0.09 * _gw(t, 0.5, 0.08) * sin(a * 3.0 + t * 12.0) + 0.05 * _gw(t, 0.75, 0.12) * sin(a * 2.0 + t * 9.0) + 0.04 * _gw(t, 0.25, 0.14) * sin(a * 2.0 - t * 6.0), func(_t, _a, ins, v): return cl if ins else _sh(coat, v, 2.2, 2.0).lightened(0.04))
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], sp, 0.9, 0.9, 0.012, 0.0, cl, 0.002, 1)
	# bel cepleri, arka yarım kemer, sırt dikişi
	for s in [1.0, -1.0]:
		var ca: float = float(s) * 1.12
		_patch(k, ck, ca, H - 0.03, 0.2, 0.018, 0.006, coat.lightened(0.07), sks, 0.002, 8, 4)
	_patch(k, ck, PI, H + 0.1, 0.5, 0.02, 0.006, coat.lightened(0.07), skt, 0.002, 12, 4)
	for s in [1.0, -1.0]:
		var bp := _sp(ck, PI + float(s) * 0.4, H + 0.1, 0.01)
		_stud(k, bp, _out(bp), 0.0075, cl.lightened(0.15), skt, 0.004)


# ------------------------------------------------------------------ Uzushio (ref Ashina_Uzumaki, Uzumaki-Senju): koyu kimono + hakama, kutu dō, kusazuri, sode, sırtta girdap ve burgu ip kanatları
static func _uzushio(k: SE.El) -> void:
	var f := _fit(k)
	var rb := _hx("3a2a24")
	var hk := _hx("2d2020")
	var ar := _hx("6c625a")
	var dk := _hx("3b3430")
	var rope := _hx("d9cfb6")
	var red := _hx("b5302a")
	var N := k.N
	var H := k.H
	var C := k.C
	var skt := _sk_t(k)
	var nk: Vector3 = f["nk"]
	_inner(k, _keys(k, f, 0.01, 0.03), 20, 36, rb.darkened(0.3))
	_pelvis(k, f, hk)
	# hakama: her bacak ayrı geniş paça, pileli; iç yanı basık
	var pl := func(t: float, a: float, s: float) -> float:
		return 0.075 * smoothstep(0.08, 0.5, t) * sin(a * 9.0 + 0.6) + 0.02 * sin(a * 4.0 + t * 7.0) - 0.3 * smoothstep(0.0, 0.8, t) * maxf(0.0, -sin(a) * s)
	_legs(k, [[0.0, 0.08], [0.24, 0.09], [0.42, 0.122], [0.6, 0.132], [1.0, 0.138]], pl, func(_t, _a, ins, v): return hk.darkened(0.45) if ins else _sh(hk, v, 3.4, 2.4), 28, 36)
	# bol kol, altında deri kolluk
	_arms(k, [[0.0, 0.056], [1.0, 0.043]], func(_t, _a, _s): return 0.0, func(_t, _a, _i, _v): return rb.darkened(0.3))
	_arms(k, [[0.0, 0.082], [0.5, 0.09], [1.0, 0.104]], func(t: float, a: float, _s: float) -> float:
		return 0.08 * _gw(t, 0.62, 0.2) * sin(a * 4.0 + t * 12.0) + 0.04 * sin(a * 3.0 - t * 5.0), func(_t, _a, ins, v): return rb.darkened(0.5) if ins else _sh(rb, v, 3.0, 2.2), 0.66)
	for sd in ["Left", "Right"]:
		var p1: Vector3 = k.m._bp(sd + "LowerArm")
		var p2: Vector3 = k.m._bp(sd + "Hand")
		var bpth := [p1.lerp(p2, 0.42), p2.lerp(p1, 0.06)]
		var bpr := [[0.0, 0.054], [1.0, 0.05]]
		_limb(k, bpth, [sd + "LowerArm"], bpr, func(_t, a): return 0.04 * cos(a * 2.0), func(_t, _a, ins, _v): return dk.darkened(0.4) if ins else dk.lightened(0.05), 8, 14)
		_wrap_limb(k, bpth, [sd + "LowerArm"], bpr, 0.2, 0.84, 0.005, 0.0, rope.darkened(0.2), 0.002, 3)
	# boyun koruması ve kimono yakası
	var ik := _keys(k, f, 0.016)
	_shell(k, ik, {"closed": true, "hem": H + 0.0, "ny": 22, "na": 48, "col": rb})
	_v_collar(k, ik, 0.11, 0.017, 0.012, rb.lightened(0.1))
	var nc := [[N + 0.032, nk.x + 0.024, nk.y + 0.02, nk.z - 0.024], [N + 0.005, nk.x + 0.036, nk.y + 0.032, nk.z - 0.036], [N - 0.04, nk.x + 0.07, nk.y + 0.06, nk.z - 0.07]]
	var ncr := _shell(k, nc, {"closed": true, "ny": 6, "na": 30, "col": dk.darkened(0.2)})
	_cord(k, ncr["rows"][0] + [(ncr["rows"][0] as Array)[0]], 0.005, dk, skt)
	# dō: kutu kesit, alt yarısı basamaklı lamel
	var top_y := C + 0.055
	var lam_y := H + 0.115
	var dko := _keys(k, f, 0.044)
	var dof := func(_a: float, y: float) -> float:
		if y > lam_y:
			return 0.0
		return 0.05 * fmod((lam_y - y) / 0.05, 1.0) - 0.012
	var doc := func(_a: float, y: float, _v: float) -> Color:
		if y > lam_y:
			return ar
		return ar.darkened(0.3 * (1.0 - smoothstep(0.0, 0.3, fmod((lam_y - y) / 0.05, 1.0))))
	var dr := _shell(k, dko, {"closed": true, "top": top_y, "hem": H + 0.005, "ny": 44, "na": 60, "n": 4.0, "fold": dof, "col": doc, "lining": dk})
	var rr0: Array = dr["rows"][0]
	_cord(k, rr0 + [rr0[0]], 0.007, ar.lightened(0.12), skt)
	# göğüs plakası: düğme ve bağ ipi
	_patch(k, dko, 0.0, C - 0.03, 0.62, 0.075, 0.008, ar.lightened(0.07), skt, 0.0, 16, 10, 4.0)
	var by := C - 0.0
	var bl := _sp(dko, -0.4, by, 0.012, 4.0)
	var br := _sp(dko, 0.4, by, 0.012, 4.0)
	_stud(k, bl, Vector3.BACK, 0.011, dk, skt)
	_stud(k, br, Vector3.BACK, 0.011, dk, skt)
	var lace := []
	for i in 13:
		var x := lerpf(bl.x, br.x, float(i) / 12.0)
		lace.append(Vector3(x, by, _zon(dko, x, by, 0.016, true, 4.0)))
	_cord(k, lace, 0.0035, rope.darkened(0.15), skt, false, 0.0, 5)
	# sırtta kızıl girdap: kabartma kordon
	var sw := []
	var cy := C - 0.088
	for i in 86:
		var t := float(i) / 85.0
		var an := t * TAU * 2.35 + 1.2
		var r := lerpf(0.01, 0.094, t)
		var x := cos(an) * r
		var y := cy + sin(an) * r
		sw.append(Vector3(x, y, _zon(dko, x, y, 0.006, false, 4.0)))
	_cord(k, sw, 0.0078, red, skt, false, 0.0, 6, 0.55)
	# omuz askıları üstünde burgu ip
	for s in [1.0, -1.0]:
		var x: float = float(s) * 0.105
		var zf := _zon(dko, x, top_y, 0.004, true, 4.0)
		var zb := _zon(dko, x, top_y, 0.004, false, 4.0)
		var st := _cr([Vector3(x, top_y - 0.015, zf), Vector3(x * 1.04, N - 0.03, zf * 0.72), Vector3(x * 1.12, N + 0.0, 0.0 + (zf + zb) * 0.5), Vector3(x * 1.04, N - 0.03, zb * 0.72), Vector3(x, top_y - 0.015, zb)], 6)
		_cord(k, st, 0.027, dk.lightened(0.04), _sk_up(k), false, 0.0, 8, 0.42)
		var lf := []
		for q in st:
			lf.append((q as Vector3) + Vector3(0, 0.012, 0))
		_cord(k, lf, 0.0115, rope, _sk_up(k), false, 0.2, 9)
	# sırttan yükselen burgu ip kanatları (ref: omuz arkasında)
	var chb := func(_p: Vector3) -> Array: return [["UpperChest", 1.0]]
	var bz := _zon(dko, 0.0, C + 0.02, 0.012, false, 4.0)
	for s in [1.0, -1.0]:
		var sf := float(s)
		var w := _cr([Vector3(sf * 0.05, C + 0.0, bz), Vector3(sf * 0.14, C + 0.075, bz - 0.022), Vector3(sf * 0.205, N + 0.0, bz - 0.036), Vector3(sf * 0.235, N + 0.05, bz - 0.044)], 12)
		_cord(k, w, 0.025, rope, chb, false, 0.22, 12)
	_cord(k, _cr([Vector3(-0.06, C + 0.0, bz - 0.004), Vector3(0.0, C - 0.012, bz - 0.012), Vector3(0.06, C + 0.0, bz - 0.004)], 8), 0.021, rope, chb, false, 0.22, 12)
	# bel ipi
	var wr := []
	for i in 72:
		wr.append(_sp(dko, TAU * i / 72.0 - PI, H + 0.015, 0.006, 4.0))
	_cord(k, wr, 0.0115, rope, skt, true, 0.2, 9)
	# kusazuri: kalça çevresi bindirmeli plakalar
	var kk := _keys(k, f, 0.056, 0.005, [[H - 0.27, 0.1, 0.095]])
	var skp := _sk_cloth(k, H - 0.262, 0.88)
	for i in 7:
		var ca := TAU * i / 7.0
		var pad := 1.0 + (0.0 if i % 2 == 0 else 0.022)
		var saw := func(_a: float, y: float) -> float: return 0.055 * fmod((H + 0.01 - y) / 0.068, 1.0) - 0.02 + pad - 1.0
		var scol := func(_a: float, y: float, _v: float) -> Color: return ar.darkened(0.08).darkened(0.3 * (1.0 - smoothstep(0.0, 0.3, fmod((H + 0.01 - y) / 0.068, 1.0))))
		var pr := _shell(k, kk, {"top": H + 0.01, "hem": H - 0.262, "a0": ca - 0.5, "a1": ca + 0.5, "ny": 24, "na": 10, "fold": saw, "col": scol, "skin": skp, "lining": dk.darkened(0.2)})
		_cord(k, pr["rows"][24], 0.0062, ar.lightened(0.14), skp)
		_cord(k, pr["ea"], 0.0045, ar.lightened(0.06), skp)
		_cord(k, pr["eb"], 0.0045, ar.lightened(0.06), skp)
		for sg in [-0.34, 0.34]:
			var lc := []
			for j in 8:
				var yy := lerpf(H + 0.0, H - 0.24, float(j) / 7.0)
				var a2: float = ca + float(sg)
				var p := _sp(kk, a2, yy, 0.0)
				var m2: float = 1.0 + float(saw.call(a2, yy))
				lc.append(Vector3(p.x * m2, yy, p.z * m2) + _out(p) * 0.004)
			_cord(k, lc, 0.0032, red.darkened(0.2), skp, false, 0.0, 4)
	# sode
	_sode(k, "Left", 1.0, -0.06, 0.62, 1.3, 0.1, ar, 4, dk.darkened(0.2), ar.lightened(0.14))
	_sode(k, "Right", -1.0, -0.06, 0.62, 1.3, 0.1, ar, 4, dk.darkened(0.2), ar.lightened(0.14))


# ------------------------------------------------------------------ Kusagakure (ref Team_Shiore): sarmal uzun kolsuz ot yeşili cübbe, mor kuşak, kalın beyaz ip, kol ve baldırda gerçek ağ
static func _kusa(k: SE.El) -> void:
	var f := _fit(k)
	var gr := _hx("44693a")
	var dk := _hx("262f22")
	var ms := _hx("0f120d")
	var pu := _hx("5a3a78")
	var ro := _hx("e6e1d2")
	var N := k.N
	var H := k.H
	var C := k.C
	var hem := k.K - 0.07
	var skt := _sk_t(k)
	_inner(k, _keys(k, f, 0.008, 0.03), 20, 36, dk)
	_pelvis(k, f, dk)
	var lp := [[0.0, 0.088], [0.3, 0.084], [0.5, 0.07], [0.7, 0.058], [1.0, 0.046]]
	var ap := [[0.0, 0.062], [0.45, 0.052], [0.6, 0.047], [1.0, 0.04]]
	_legs(k, lp, func(t: float, a: float, _s: float) -> float:
		return 0.08 * _gw(t, 0.45, 0.1) * sin(a * 3.0 + t * 15.0), func(_t, _a, ins, v): return dk.darkened(0.4) if ins else _sh(dk.lightened(0.04), v, 1.5, 1.0))
	_arms(k, ap, func(t: float, a: float, _s: float) -> float:
		return 0.05 * _gw(t, 0.45, 0.1) * sin(a * 3.0 + t * 10.0), func(_t, _a, ins, v): return dk.darkened(0.4) if ins else _sh(dk.lightened(0.05), v, 1.5, 1.0))
	for sd in ["Left", "Right"]:
		var apt := _arm_path(k, sd)
		var lpt := _leg_path(k, sd)
		var abn := [sd + "UpperArm", sd + "LowerArm"]
		var lbn := [sd + "UpperLeg", sd + "LowerLeg"]
		_lattice(k, apt, abn, ap, 0.56, 0.87, 7, 0.75, 0.0019, ms)
		_wrap_limb(k, apt, abn, ap, 0.89, 0.985, 0.0105, 0.004, _hx("c9c3ad"))
		_lattice(k, lpt, lbn, lp, 0.62, 0.86, 9, 0.8, 0.002, ms)
		_wrap_limb(k, lpt, lbn, lp, 0.88, 0.99, 0.0155, 0.006, _hx("c9c3ad"))
	var keys := _keys(k, f, 0.024, 0.006, [[H - 0.14, 0.03, 0.028], [H - 0.3, 0.056, 0.05], [hem, 0.11, 0.09]])
	var op := func(y: float) -> float: return lerpf(-0.3, 0.6, smoothstep(C - 0.1, N - 0.02, y))
	var op2 := func(y: float) -> float: return TAU + lerpf(0.18, -0.44, smoothstep(C - 0.1, N - 0.02, y))
	var uf := func(a: float, y: float) -> float:
		return 0.012 * sin(a * 3.0 + y * 8.0) + _gw(y, H + 0.1, 0.07) * 0.018 * sin(a * 11.0 + 1.0)
	var up := _shell(k, keys, {"hem": H + 0.0, "a0": op, "a1": op2, "ny": 30, "na": 64, "fold": uf, "col": gr, "lining": gr.darkened(0.45), "uf": func(u: float) -> float: return 0.03 * (1.0 - smoothstep(0.0, 0.2, u))})
	_collar(k, up, 0.021, 0.007, gr.darkened(0.42), 30, 15)
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], ap, 0.13, 0.13, 0.011, 0.0, gr.darkened(0.42), 0.005, 1)
	# etek kanatları: sol kanat üstte, yanlar yırtmaçlı
	var sf := func(a: float, y: float) -> float:
		var t := clampf((H + 0.04 - y) / (H + 0.04 - hem), 0.0, 1.0)
		return t * t * (0.06 * sin(a * 6.0 + 0.5) + 0.03 * sin(a * 13.0 + 2.0)) + t * 0.01 * sin(a * 21.0)
	var sks := _sk_cloth(k, hem)
	for q in [[-1.5, 0.2, 0.0], [1.72, TAU - 1.72, 0.0], [-0.3, 1.5, 0.018]]:
		var g: float = q[2]
		var r := _shell(k, keys, {"top": H + 0.06, "hem": hem, "a0": q[0], "a1": q[1], "ny": 32, "na": 26, "fold": sf, "col": gr, "skin": sks, "lining": gr.darkened(0.45), "uf": func(_u: float) -> float: return g})
		_cord(k, r["rows"][32], 0.007, gr.darkened(0.42), sks)
		_cord(k, r["ea"], 0.0065, gr.darkened(0.42), sks)
		_cord(k, r["eb"], 0.0065, gr.darkened(0.42), sks)
	# mor kuşak, düğüm, sarkan uçlar
	_belt(k, keys, H + 0.05, 0.05, 0.016, pu, 0.012)
	_belt(k, keys, H + 0.098, 0.006, 0.026, pu.lightened(0.15), 0.0)
	var kn := _sp(keys, 0.38, H + 0.05, 0.034)
	_cord(k, [kn + Vector3(-0.03, 0.016, -0.004), kn + Vector3(0.0, 0.0, 0.012), kn + Vector3(0.03, -0.016, -0.004)], 0.026, pu.lightened(0.05), skt, false, 0.0, 10)
	_tail(k, keys, 0.46, H + 0.02, H - 0.36, 0.07, 0.03, 0.004, 0.024, pu, sks, sf)
	_tail(k, keys, 0.3, H + 0.02, H - 0.27, -0.06, 0.027, 0.004, 0.028, pu.darkened(0.12), sks, sf)
	# omuzlara oturan kalın beyaz ip halkası
	var rp := []
	for i in 84:
		var a := TAU * i / 84.0 - PI
		var dn := pow(maxf(0.0, cos(a)), 2.0) * 0.1 + pow(maxf(0.0, -cos(a)), 2.0) * 0.035
		rp.append(_sp(keys, a, N - 0.034 - dn, 0.028))
	_cord(k, rp, 0.026, ro, _sk_up(k), true, 0.2, 12)
	var fp := _sp(keys, 0.0, N - 0.134, 0.05)
	_cord(k, [fp + Vector3(0, 0.022, -0.012), fp + Vector3(0, 0.0, 0.012), fp + Vector3(0, -0.022, -0.012)], 0.027, ro.darkened(0.05), _sk_up(k), false, 0.16, 12)


# ------------------------------------------------------------------ Yugakure (ref Shinbu, Team_Iwato): kalın yakalı, fermuarlı dolgulu kızıl yelek, koyu üniforma, uyluk bantları, arka bel çantası
static func _yu(k: SE.El) -> void:
	var f := _fit(k)
	var ve := _hx("99483a")
	var vd := ve.darkened(0.3)
	var dk := _hx("272230")
	var wh := _hx("e0dccd")
	var me := _hx("8c8f96")
	var pc := _hx("4a3a30")
	var N := k.N
	var H := k.H
	var C := k.C
	var skt := _sk_t(k)
	var nk: Vector3 = f["nk"]
	_inner(k, _keys(k, f, 0.008, 0.03, [[H - 0.1, 0.0, 0.0]]), 24, 40, dk)
	_pelvis(k, f, dk.lightened(0.03))
	var lp := [[0.0, 0.098], [0.3, 0.092], [0.5, 0.075], [0.72, 0.066], [0.86, 0.054], [1.0, 0.046]]
	var ap := [[0.0, 0.066], [0.45, 0.055], [0.6, 0.051], [1.0, 0.042]]
	_legs(k, lp, func(t: float, a: float, _s: float) -> float:
		return 0.1 * _gw(t, 0.47, 0.09) * sin(a * 3.0 + t * 14.0) + 0.08 * _gw(t, 0.24, 0.12) * sin(a * 2.0 + t * 9.0) + 0.1 * _gw(t, 0.8, 0.05) * sin(a * 4.0), func(_t, _a, ins, v): return dk.darkened(0.4) if ins else _sh(dk.lightened(0.05), v, 1.6, 1.2))
	_arms(k, ap, func(t: float, a: float, _s: float) -> float:
		return 0.07 * _gw(t, 0.47, 0.08) * sin(a * 3.0 + t * 12.0) + 0.05 * _gw(t, 0.8, 0.1) * sin(a * 2.0 + t * 20.0), func(_t, _a, ins, v): return dk.darkened(0.4) if ins else _sh(dk.lightened(0.05), v, 1.6, 1.2))
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _leg_path(k, sd), [sd + "UpperLeg", sd + "LowerLeg"], lp, 0.9, 0.99, 0.0155, 0.006, wh)
		_wrap_limb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], ap, 0.93, 0.985, 0.0105, 0.003, wh)
	# sağ uylukta beyaz bantlar
	_wrap_limb(k, _leg_path(k, "Right"), ["RightUpperLeg", "RightLowerLeg"], lp, 0.27, 0.35, 0.0105, 0.0, wh, 0.008, 3)
	# yelek: dolgulu kesit, yan paneller oluklu
	var vk := _keys(k, f, 0.04, 0.0, [[H - 0.02, 0.006, 0.004]])
	var bot := H + 0.03
	var vf := func(a: float, y: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		var g := -0.05 * _gw(aa, 1.2, 0.07) - 0.035 * _gw(aa, 0.03, 0.03)
		return g + 0.008 * sin(a * 5.0 + y * 10.0)
	var vc := func(_a: float, _y: float, v: float) -> Color: return _sh(ve, v, 6.0, 1.0)
	var vr := _shell(k, vk, {"closed": true, "top": N - 0.012, "hem": bot, "ny": 40, "na": 72, "n": 3.0, "fold": vf, "col": vc, "lining": vd.darkened(0.3)})
	var vb: Array = vr["rows"][40]
	_cord(k, vb + [vb[0]], 0.0125, vd, skt, false, 0.0, 8)
	# fermuar
	var zp := []
	for i in 24:
		var y := lerpf(N - 0.05, bot, float(i) / 23.0)
		zp.append(_sp(vk, 0.0, y, 0.0, 3.0) * Vector3(1, 1, 0.975))
	k.strip(zp, _outs_of(zp), 0.007, 0.003, vd.darkened(0.35), false, skt)
	var zt: Vector3 = zp[3]
	_cord(k, [zt + Vector3(0, 0.006, 0.006), zt + Vector3(0, -0.02, 0.008)], 0.0042, me, skt, false, 0.0, 5, 0.6)
	# göğüs panelleri, çift cep, sırt plakası ve üç dalga
	for s in [1.0, -1.0]:
		var sf := float(s)
		_patch(k, vk, sf * 0.56, C - 0.0, 0.37, 0.085, 0.01, ve.lightened(0.05), skt, 0.0, 14, 12, 3.0)
		for q in [0.36, 0.78]:
			var ca: float = sf * float(q)
			_patch(k, vk, ca, H + 0.1, 0.17, 0.052, 0.0145, vd.lightened(0.06), skt, 0.004, 8, 8, 3.0)
			_patch(k, vk, ca, H + 0.14, 0.185, 0.017, 0.019, ve, skt, 0.004, 8, 4, 3.0)
			var bp := _sp(vk, ca, H + 0.135, 0.026, 3.0)
			_stud(k, bp, _out(bp), 0.0058, me, skt, 0.004)
	_patch(k, vk, PI, C - 0.03, 0.88, 0.135, 0.01, ve.lightened(0.04), skt, 0.0, 18, 14, 3.0)
	for i in 3:
		var pts := []
		var x0 := -0.05 + 0.05 * i
		for j in 16:
			var t := float(j) / 15.0
			var y := C + 0.05 - t * 0.14
			var x := x0 + sin(t * TAU * 1.05) * 0.013
			pts.append(Vector3(x, y, _zon(vk, x, y, 0.009, false, 3.0)))
		_cord(k, pts, 0.0072, wh, skt, false, 0.0, 6, 0.6)
	# kalın dik yaka: iki yüksek ön kanat, ense sırtı
	var hc := [[N + 0.058, nk.x + 0.05, nk.y + 0.05, nk.z - 0.04], [N + 0.03, nk.x + 0.056, nk.y + 0.052, nk.z - 0.05], [N - 0.03, nk.x + 0.085, nk.y + 0.075, nk.z - 0.08]]
	var hr := _shell(k, hc, {"a0": 0.62, "a1": TAU - 0.62, "top": N + 0.058, "hem": N - 0.03, "ny": 12, "na": 44, "col": ve, "lining": vd.darkened(0.25), "fold": func(a: float, _y: float) -> float: return 0.04 * cos(a * 2.0)})
	_cord(k, hr["rows"][0], 0.0115, ve.lightened(0.06), skt, false, 0.0, 8)
	_cord(k, hr["ea"], 0.0105, ve.lightened(0.06), skt, false, 0.0, 8)
	_cord(k, hr["eb"], 0.0105, ve.lightened(0.06), skt, false, 0.0, 8)
	# omuz dolguları
	_sode(k, "Left", 1.0, -0.06, 0.13, 1.25, 0.074, ve, 0, vd.darkened(0.2), vd)
	_sode(k, "Right", -1.0, -0.06, 0.13, 1.25, 0.074, ve, 0, vd.darkened(0.2), vd)
	# kemer + arka çanta
	var bk := _keys(k, f, 0.02)
	_belt(k, bk, H + 0.0, 0.019, 0.004, _hx("17151c"))
	_patch(k, bk, PI + 0.34, H - 0.045, 0.31, 0.05, 0.034, pc, skt, 0.006, 10, 10)
	_patch(k, bk, PI + 0.34, H - 0.012, 0.33, 0.017, 0.043, pc.lightened(0.08), skt, 0.006, 10, 4)
	var bp2 := _sp(bk, PI + 0.34, H - 0.018, 0.052)
	_stud(k, bp2, _out(bp2), 0.0058, me, skt, 0.004)


# ------------------------------------------------------------------ Shimogakure (ref Fuki): kapitone yelek, kalın sarılı atkı, dolgulu kol, kürk ağızlı tozluk
static func _shimo(k: SE.El) -> void:
	var f := _fit(k)
	var ve := _hx("7a91a8")
	var dk := _hx("2f3b4b")
	var sl := _hx("44566a")
	var sc := _hx("b7bac9")
	var te := _hx("3b7c84")
	var fu := _hx("e6e9ee")
	var wd := _hx("7a5a3c")
	var N := k.N
	var H := k.H
	var skt := _sk_t(k)
	_inner(k, _keys(k, f, 0.01, 0.03), 18, 36, dk)
	_pelvis(k, f, dk)
	# bol pantolon dizin altında tozluğa girer; tozluk dolgulu
	_legs(k, [[0.0, 0.104], [0.3, 0.104], [0.48, 0.096], [0.56, 0.07], [1.0, 0.05]], func(t: float, a: float, _s: float) -> float:
		return 0.13 * _gw(t, 0.47, 0.06) * sin(a * 4.0 + t * 14.0) + 0.07 * _gw(t, 0.22, 0.14) * sin(a * 2.0 + t * 8.0), func(_t, _a, ins, v): return dk.darkened(0.4) if ins else _sh(dk.lightened(0.04), v, 1.6, 1.2))
	for sd in ["Left", "Right"]:
		var kn: Vector3 = k.m._bp(sd + "LowerLeg")
		var ft: Vector3 = k.m._bp(sd + "Foot") + Vector3(0, 0.07, 0)
		var bo: String = sd + "LowerLeg"
		_limb(k, [kn.lerp(ft, 0.16), ft], [bo], [[0.0, 0.078], [0.45, 0.072], [1.0, 0.058]], func(t: float, _a: float) -> float: return 0.09 * absf(sin(t * PI * 6.0)) - 0.045, func(t, _a, ins, _v):
			return sl.darkened(0.4) if ins else sl.darkened(0.3 * (1.0 - smoothstep(0.0, 0.35, absf(sin(t * PI * 6.0))))), 36, 16)
		_fur(k, kn.lerp(ft, 0.17), ft - kn, 0.08, 0.03, fu, bo)
	# kapitone kollar, örgü manşet
	var ap := [[0.0, 0.08], [0.5, 0.072], [0.86, 0.06], [1.0, 0.052]]
	_arms(k, ap, func(t: float, _a: float, _s: float) -> float: return 0.1 * absf(sin(t * PI * 9.0)) - 0.05, func(t, _a, ins, _v):
		return sl.darkened(0.4) if ins else sl.darkened(0.3 * (1.0 - smoothstep(0.0, 0.35, absf(sin(t * PI * 9.0))))), 1.0, 54, 16)
	for sd in ["Left", "Right"]:
		_wrap_limb(k, _arm_path(k, sd), [sd + "UpperArm", sd + "LowerArm"], ap, 0.91, 0.985, 0.0115, 0.0, te, 0.004)
	# yelek: yatay dolgu dilimleri, kalçayı kapatır
	var vk := _keys(k, f, 0.04, 0.0, [[H - 0.12, 0.006, 0.006]])
	var bot := H - 0.1
	var pitch := 0.082
	var bf := func(y: float) -> float: return absf(sin((y - H) * PI / pitch))
	var vf := func(a: float, y: float) -> float:
		var aa := absf(wrapf(a, -PI, PI))
		return (0.075 * sqrt(float(bf.call(y))) - 0.045) - 0.04 * _gw(aa, 0.0, 0.035)
	var vc := func(_a: float, y: float, _v: float) -> Color: return ve.darkened(0.34 * (1.0 - smoothstep(0.0, 0.42, float(bf.call(y)))))
	var vsk := _sk_cloth(k, bot, 0.35)
	var vr := _shell(k, vk, {"closed": true, "top": N - 0.03, "hem": bot, "ny": 78, "na": 64, "n": 2.8, "fold": vf, "col": vc, "lining": dk, "skin": vsk})
	var vb: Array = vr["rows"][78]
	_cord(k, vb + [vb[0]], 0.009, ve.darkened(0.3), vsk, false, 0.0, 8)
	for sd in ["Left", "Right"]:
		var q := _path_at(_arm_path(k, sd), 0.17)
		_fur(k, q[0], q[1], _prof(ap, 0.17) + 0.004, 0.02, fu, sd + "UpperArm")
	# ön: tahta kopçalar ve halkalar
	for i in 3:
		var y := lerpf(N - 0.17, H + 0.1, float(i) / 2.0)
		var p := _sp(vk, 0.0, y, 0.015, 2.8)
		_cord(k, [p + Vector3(-0.024, 0, 0.004), p + Vector3(0, 0, 0.009), p + Vector3(0.024, 0, 0.004)], 0.0072, wd, skt, false, 0.0, 7)
		for s in [1.0, -1.0]:
			_cord(k, _cr([p + Vector3(float(s) * 0.02, 0.006, 0.002), p + Vector3(float(s) * 0.042, 0.009, 0.0), p + Vector3(float(s) * 0.042, -0.009, 0.0), p + Vector3(float(s) * 0.02, -0.006, 0.002)], 3), 0.0026, dk, skt, false, 0.0, 4)
	# atkı: boyna üç kat dolanır, iki ucu sarkar
	var ak := _keys(k, f, 0.03, 0.09)
	for t in [[N - 0.042, 0.038, 0.0, sc], [N + 0.0, 0.033, 1.7, sc.darkened(0.07)], [N + 0.038, 0.027, 3.3, sc.lightened(0.03)]]:
		var rp := []
		var y0: float = t[0]
		var ph: float = t[2]
		for i in 44:
			var a := TAU * i / 44.0 - PI
			rp.append(_sp(ak, a, y0 + 0.012 * sin(a + ph), float(t[1]) * 0.55 + 0.012 * (1.0 + sin(a * 2.0 + ph))))
		_cord(k, rp, float(t[1]), t[3], _sk_up(k), true, 0.0, 12, 0.72)
	var fz := _sp(ak, 0.42, N - 0.075, 0.042)
	var fb := _sp(ak, PI + 0.5, N - 0.075, 0.042)
	_cord(k, [fz + Vector3(0.02, 0.022, -0.012), fz + Vector3(0.008, -0.004, 0.012), fz + Vector3(0.0, -0.03, 0.006)], 0.032, sc.darkened(0.04), _sk_up(k), false, 0.0, 10, 0.75)
	var tsk := func(p: Vector3) -> Array: return k.torso_skin(p.y)
	_tail(k, vk, 0.42, N - 0.09, H + 0.0, -0.1, 0.05, 0.007, 0.016, sc, vsk, vf, 2.8)
	_tail(k, vk, PI + 0.5, N - 0.09, H + 0.1, 0.12, 0.048, 0.007, 0.016, sc.darkened(0.06), tsk, vf, 2.8)
