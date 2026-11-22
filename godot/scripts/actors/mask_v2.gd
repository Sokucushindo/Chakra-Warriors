extends RefCounted
## Tam yüz maskeleri (ref refs/kiyafet/anbu/Konoha_Anbu): kavisli kabuk, yuvarlak göz deliği, yüzeye oturan fırça boyası.
## Her maske kendi çizimi; boyalar kabuğun üstünde incelen şeritler (çubuk / kutu yok).

const STYLES := ["anbu_kedi", "anbu_kurt", "anbu_kus", "anbu_ayi", "anbu_tilki", "anbu_kaplan", "anbu_yilan", "anbu_maymun", "anbu_baykus", "anbu_kartal", "anbu_tavsan", "anbu_geyik", "anbu_kaplumbaga", "anbu_yarasa", "anbu_kurbaga", "anbu_ejder", "kitsune", "kitsune_festival", "tengu", "oni", "hannya", "okame", "kok_maskesi", "spiral_maske", "avci_maske", "kemik_maske"]
const PB = preload("res://scripts/actors/mask_v2_b.gd")
## Maskenin kendi rengi (eşya rengi değil: boyalı ahşap / kemik maske boyanmaz)
const BASE := {"kitsune": Color(0.95, 0.94, 0.9), "kitsune_festival": Color(0.97, 0.95, 0.9), "tengu": Color(0.72, 0.1, 0.1), "oni": Color(0.68, 0.12, 0.1), "hannya": Color(0.86, 0.82, 0.68), "okame": Color(0.97, 0.94, 0.88), "kok_maskesi": Color(0.93, 0.92, 0.89), "spiral_maske": Color(0.93, 0.5, 0.14), "avci_maske": Color(0.93, 0.93, 0.9), "kemik_maske": Color(0.86, 0.82, 0.7)}
const ANBU_WHITE := Color(0.93, 0.93, 0.92)
const INK := Color(0.09, 0.08, 0.1)
const RED := Color(0.66, 0.11, 0.14)
const PUR := Color(0.28, 0.19, 0.42)
const BLU := Color(0.2, 0.28, 0.55)
const GRN := Color(0.2, 0.42, 0.26)
const GLD := Color(0.86, 0.66, 0.22)
const PNK := Color(0.93, 0.62, 0.64)
static var _cache := {}


static func has(s) -> bool:
	return s in STYLES or s in PB.STYLES


class Mk:
	var fg: Color
	var mb := MB.new()
	var ears := []    # [açı (0 tepe), genişlik, boy, sivri]
	var bumps := []   # [x, y, sx, sy, yükseklik, simetrik]

	func _init(c: Color) -> void:
		fg = c

	func S(x: float, y: float) -> float:
		var u := x / 0.105
		var v := y / 0.14
		var z := 0.034 - 0.06 * u * u - 0.018 * v * v
		z += 0.009 * exp(-pow(x / 0.015, 2.0)) * exp(-pow((y + 0.018) / 0.036, 2.0))   # burun sırtı
		z += 0.0035 * exp(-pow((y - 0.04) / 0.014, 2.0))   # kaş kemeri
		for b in bumps:
			for s in ([-1.0, 1.0] if b[5] else [1.0]):
				z += float(b[4]) * exp(-pow((x - float(b[0]) * s) / float(b[2]), 2.0) - pow((y - float(b[1])) / float(b[3]), 2.0))
		return z

	func N(x: float, y: float) -> Vector3:
		var e := 0.002
		return Vector3(S(x - e, y) - S(x + e, y), S(x, y - e) - S(x, y + e), 2.0 * e).normalized()

	func P(q: Vector2, lift := 0.0) -> Vector3:
		return Vector3(q.x, q.y, S(q.x, q.y) + lift)

	func edge(t: float) -> Vector2:
		var s := sin(t)
		var c := cos(t)
		var o := Vector2(0.098 * s * (1.0 - 0.2 * smoothstep(0.0, 1.0, -c)), (0.118 if c > 0.0 else 0.132) * c)
		var ang := absf(wrapf(t, -PI, PI))
		var k := 1.0
		for e in ears:
			var d: float = absf(ang - float(e[0])) / float(e[1])
			k += float(e[2]) * (exp(-d * 1.6) if e[3] else exp(-d * d))
		return o * k

	func _v(p: Vector3, n: Vector3, c: Color) -> int:
		mb.verts.append(p)
		mb.normals.append(n)
		mb.colors.append(c)
		mb.uvs.append(Vector2.ZERO)
		return mb.verts.size() - 1

	func _tri(a: int, b: int, c: int) -> void:
		var p: Vector3 = mb.verts[a]
		if (mb.verts[b] - p).cross(mb.verts[c] - p).z > 0.0:
			var t := b
			b = c
			c = t
		mb.idx.append(a)
		mb.idx.append(b)
		mb.idx.append(c)

	func shell() -> void:
		var NA := 72
		var NR := 11
		var c0 := _v(P(Vector2.ZERO), N(0, 0), fg)
		var grid := []
		for j in range(1, NR + 1):
			var ro := []
			for i in NA:
				var q := edge(TAU * i / NA) * (float(j) / NR)
				ro.append(_v(P(q), N(q.x, q.y), fg))
			grid.append(ro)
		var back := []
		var line := []
		var ln := fg.darkened(0.5)
		for i in NA:
			var q := edge(TAU * i / NA)
			var p := P(q)
			back.append(_v(p + Vector3(-q.x * 0.04, -q.y * 0.04, -0.02), Vector3(q.x, q.y, 0.0).normalized(), fg.darkened(0.35)))
			line.append([_v(P(q * 0.972, 0.0009), Vector3.BACK, ln), _v(P(q * 1.004, 0.0009), Vector3.BACK, ln)])
		for i in NA:
			var i2 := (i + 1) % NA
			_tri(c0, grid[0][i], grid[0][i2])
			for j in NR - 1:
				_tri(grid[j][i], grid[j + 1][i], grid[j + 1][i2])
				_tri(grid[j][i], grid[j + 1][i2], grid[j][i2])
			_tri2(line[i][0], line[i][1], line[i2][1], line[i2][0])
			var a: int = grid[NR - 1][i]
			var b: int = grid[NR - 1][i2]
			var pa: Vector3 = mb.verts[a]
			var pb: Vector3 = mb.verts[b]
			var o := (pa + pb) * 0.5
			var ba: int = back[i]
			var bb: int = back[i2]
			# kalınlık şeridi: dışa bakan yön
			var nn := Vector3(o.x, o.y, 0.0)
			var cr := (pb - pa).cross(mb.verts[bb] - pa)
			if cr.dot(nn) > 0.0:
				mb.idx.append_array([a, bb, b, a, ba, bb])
			else:
				mb.idx.append_array([a, b, bb, a, bb, ba])

	func _tri2(a: int, b: int, c: int, d: int) -> void:
		_tri(a, b, c)
		_tri(a, c, d)

	static func _cr(p: Array, sub: int) -> Array:
		var out := []
		for i in p.size() - 1:
			var p0: Vector2 = p[maxi(i - 1, 0)]
			var p1: Vector2 = p[i]
			var p2: Vector2 = p[i + 1]
			var p3: Vector2 = p[mini(i + 2, p.size() - 1)]
			for k in sub:
				var t := float(k) / sub
				out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
		out.append(p[p.size() - 1])
		return out

	## Fırça darbesi: uçlara doğru incelir (taper 0 = düz çizgi)
	func st(pts: Array, w: float, col: Color, sym := true, taper := 1.0) -> void:
		var q := _cr(pts, 6)
		var n := q.size()
		for s in ([-1.0, 1.0] if sym else [1.0]):
			var pa := -1
			var pb := -1
			for k in n:
				var t := float(k) / (n - 1)
				var d: Vector2 = q[mini(k + 1, n - 1)] - q[maxi(k - 1, 0)]
				var nr := Vector2(-d.y, d.x).normalized()
				var ww := maxf(0.0005, w * 0.5 * lerpf(1.0, pow(sin(PI * t), 0.6), taper))
				var c: Vector2 = q[k]
				var l: Vector2 = c + nr * ww
				var r: Vector2 = c - nr * ww
				l.x *= s
				r.x *= s
				var a := _v(P(l, 0.0014), N(l.x, l.y), col)
				var b := _v(P(r, 0.0014), N(r.x, r.y), col)
				if pa >= 0:
					_tri2(pa, pb, b, a)
				pa = a
				pb = b

	func dot(x: float, y: float, rx: float, ry: float, col: Color, sym := true, rot := 0.0, lift := 0.0016) -> void:
		for s in ([-1.0, 1.0] if sym else [1.0]):
			var f = func(a: float, k: float) -> Vector2:
				var o := Vector2(cos(a) * rx * k, sin(a) * ry * k).rotated(rot * s)
				return Vector2(x * s, y) + o
			var c := _v(P(f.call(0.0, 0.0), lift), N(x * s, y), col)
			var rings := []
			for r in 3:
				var ro := []
				for i in 18:
					var q: Vector2 = f.call(TAU * i / 18.0, float(r + 1) / 3.0)
					ro.append(_v(P(q, lift), N(q.x, q.y), col))
				rings.append(ro)
			for i in 18:
				var i2 := (i + 1) % 18
				_tri(c, rings[0][i], rings[0][i2])
				for r in 2:
					_tri2(rings[r][i], rings[r + 1][i], rings[r + 1][i2], rings[r][i2])

	## Dış bükey dolgu
	func poly(pts: Array, col: Color, sym := true, lift := 0.0012) -> void:
		var cn := Vector2.ZERO
		for p in pts:
			cn += p
		cn /= pts.size()
		var ed := []
		for i in pts.size():
			for k in 4:
				ed.append((pts[i] as Vector2).lerp(pts[(i + 1) % pts.size()], k / 4.0))
		for s in ([-1.0, 1.0] if sym else [1.0]):
			var m := Vector2(s, 1.0)
			var c := _v(P(cn * m, lift), N(cn.x * s, cn.y), col)
			var rings := []
			for r in 3:
				var ro := []
				for e in ed:
					var q: Vector2 = cn.lerp(e, float(r + 1) / 3.0) * m
					ro.append(_v(P(q, lift), N(q.x, q.y), col))
				rings.append(ro)
			var ne := ed.size()
			for i in ne:
				var i2 := (i + 1) % ne
				_tri(c, rings[0][i], rings[0][i2])
				for r in 2:
					_tri2(rings[r][i], rings[r + 1][i], rings[r + 1][i2], rings[r][i2])

	func eyes(y := 0.02, x := 0.036, r := 0.0135) -> void:
		dot(x, y, r * 1.14, r * 1.14, fg.darkened(0.42), true, 0.0, 0.0008)
		dot(x, y, r, r, Color(0.02, 0.02, 0.03))

	func nose(col := INK) -> void:
		st([Vector2(0, -0.022), Vector2(0, -0.038)], 0.0028, col, false, 0.3)
		st([Vector2(0, -0.038), Vector2(0.005, -0.033), Vector2(0.011, -0.033)], 0.0026, col)

	func frown(y := -0.068, col := INK) -> void:
		st([Vector2(0, y + 0.012), Vector2(0.018, y + 0.008), Vector2(0.038, y - 0.005)], 0.0034, col)

	func horn(x: float, y: float, z: float, w: float, h: float, tilt: float, col: Color, seg := 8, fwd := 0.0) -> void:
		for s in [-1.0, 1.0]:
			mb.add("cone", Vector3(x * s, y, z), Vector3(w, h, w * 0.8), col, Vector3(fwd, 0, -tilt * s), seg)


static func _design(k: Mk, s: String) -> void:
	var V = func(x: float, y: float) -> Vector2: return Vector2(x, y)
	match s:
		"anbu_kedi":
			k.ears = [[0.72, 0.13, 0.3, true]]
			k.shell()
			k.poly([V.call(-0.052, 0.112), V.call(0.052, 0.112), V.call(0.0, 0.03)], PUR, false)
			k.st([V.call(0.098, 0.0), V.call(0.078, -0.03), V.call(0.074, -0.075)], 0.017, PUR)
			k.dot(0.082, 0.112, 0.012, 0.016, PUR, true, -0.6)
			k.eyes()
			k.nose()
			k.frown()
		"anbu_kurt":
			k.ears = [[0.56, 0.1, 0.5, true]]
			k.bumps = [[0.0, -0.06, 0.03, 0.05, 0.018, false]]
			k.shell()
			k.dot(0.074, 0.138, 0.011, 0.024, BLU, true, -0.42)
			for i in 3:
				k.st([V.call(0.05 + i * 0.012, 0.062 - i * 0.012), V.call(0.078 + i * 0.008, 0.05 - i * 0.014)], 0.005, BLU)
			k.st([V.call(0.012, 0.044), V.call(0.03, 0.04), V.call(0.058, 0.03)], 0.0055, INK)
			k.eyes(0.016, 0.04, 0.012)
			k.dot(0.0, -0.047, 0.012, 0.008, INK, false)
			k.st([V.call(0, -0.054), V.call(0, -0.074)], 0.0028, INK, false, 0.2)
			k.st([V.call(0, -0.074), V.call(0.018, -0.083), V.call(0.038, -0.07)], 0.0034, INK)
			k.st([V.call(0.02, -0.082), V.call(0.024, -0.097)], 0.004, INK)
		"anbu_kus":
			k.bumps = [[0.0, -0.045, 0.02, 0.06, 0.03, false]]
			k.shell()
			k.poly([V.call(-0.046, 0.108), V.call(0.0, 0.118), V.call(0.046, 0.108), V.call(0.0, 0.03)], RED, false)
			for i in 5:
				var t := i / 4.0
				var p: Vector2 = V.call(0.06, 0.085).lerp(V.call(0.024, 0.04), t)
				k.st([p + V.call(-0.006, -0.005), p + V.call(0.006, 0.005)], 0.0026, INK, true, 0.2)
			for i in 3:
				k.st([V.call(0.066, 0.012 - i * 0.012), V.call(0.088, 0.018 - i * 0.012)], 0.0034, INK)
			k.eyes(0.015, 0.036, 0.0125)
			k.st([V.call(0.0, 0.0), V.call(0.012, -0.05), V.call(0.0, -0.118)], 0.003, INK)
			k.st([V.call(0.0, -0.03), V.call(0.0, -0.1)], 0.0025, INK, false)
		"anbu_ayi":
			k.ears = [[0.74, 0.17, 0.2, false]]
			k.shell()
			k.dot(0.094, 0.112, 0.012, 0.012, k.fg.darkened(0.3))
			k.eyes(0.03, 0.033, 0.0145)
			for i in 3:
				var y := -0.002 - i * 0.02
				k.st([V.call(0.056 + i * 0.004, y), V.call(0.074 + i * 0.002, y + 0.003), V.call(0.094, y + 0.012)], 0.006, RED)
			k.st([V.call(0, -0.024), V.call(0, -0.042)], 0.003, INK, false, 0.2)
			k.st([V.call(0, -0.042), V.call(0.01, -0.038), V.call(0.018, -0.031)], 0.0028, INK)
			k.st([V.call(0, -0.052), V.call(0.024, -0.06), V.call(0.048, -0.074)], 0.0038, INK)
		"anbu_tilki":
			k.ears = [[0.92, 0.1, 0.17, true]]
			k.shell()
			k.st([V.call(0.0, 0.114), V.call(0.002, 0.08), V.call(0.0, 0.044)], 0.017, RED, false)
			k.st([V.call(0.03, 0.11), V.call(0.024, 0.09), V.call(0.012, 0.066)], 0.01, RED)
			k.st([V.call(0.03, 0.044), V.call(0.054, 0.05), V.call(0.066, 0.026)], 0.006, RED)
			k.eyes(0.018, 0.036, 0.0125)
			k.dot(0.0, -0.03, 0.0034, 0.0026, INK, false)
			k.st([V.call(0.0, -0.058), V.call(0.024, -0.054), V.call(0.05, -0.066), V.call(0.068, -0.05)], 0.0075, RED)
			for i in 3:
				k.st([V.call(0.008 + i * 0.016, -0.09), V.call(0.006 + i * 0.015, -0.116 + i * 0.006)], 0.006, RED)
		"anbu_kaplan":
			k.ears = [[0.76, 0.14, 0.17, false]]
			k.bumps = [[0.0, -0.05, 0.04, 0.03, 0.01, false]]
			k.shell()
			k.st([V.call(0, 0.112), V.call(0, 0.086)], 0.009, INK, false)
			for i in 3:
				k.st([V.call(0.008, 0.09 - i * 0.014), V.call(0.026, 0.084 - i * 0.012), V.call(0.042 - i * 0.004, 0.09 - i * 0.02)], 0.0065, INK)
			for i in 3:
				k.st([V.call(0.094, 0.004 - i * 0.02), V.call(0.072, -0.004 - i * 0.02), V.call(0.054, -0.002 - i * 0.021)], 0.0085, INK)
			k.eyes(0.022, 0.037, 0.0125)
			k.nose(Color(0.74, 0.3, 0.18))
			k.st([V.call(0, -0.05), V.call(0.018, -0.066), V.call(0.042, -0.058)], 0.0036, INK)
		"anbu_yilan":
			k.ears = []
			k.shell()
			k.st([V.call(0.0, 0.11), V.call(0.03, 0.075), V.call(-0.024, 0.058), V.call(0.0, 0.036)], 0.0075, GRN, false)
			k.st([V.call(0.03, -0.004), V.call(0.044, 0.018), V.call(0.068, 0.03)], 0.0115, Color(0.03, 0.03, 0.04), true, 0.75)
			k.st([V.call(0.076, 0.012), V.call(0.08, -0.04), V.call(0.056, -0.09)], 0.008, PUR)
			k.dot(0.006, -0.026, 0.0018, 0.003, INK)
			k.st([V.call(0, -0.062), V.call(0.024, -0.058), V.call(0.04, -0.048)], 0.003, INK)
			k.st([V.call(0, -0.062), V.call(0, -0.082)], 0.0024, RED, false, 0.1)
			k.st([V.call(0, -0.082), V.call(0.007, -0.094)], 0.0022, RED)
		"anbu_maymun":
			k.ears = [[1.45, 0.17, 0.17, false]]
			k.shell()
			k.st([V.call(0.0, 0.052), V.call(0.038, 0.076), V.call(0.074, 0.044), V.call(0.074, -0.01), V.call(0.044, -0.05), V.call(0.056, -0.09), V.call(0.0, -0.112)], 0.0052, RED, true, 0.3)
			k.eyes(0.022, 0.033, 0.013)
			k.dot(0.006, -0.024, 0.0026, 0.0032, INK)
			k.st([V.call(0, -0.07), V.call(0.024, -0.064), V.call(0.042, -0.07)], 0.0042, INK)
			k.dot(0.06, -0.034, 0.012, 0.008, RED, true, 0.2)
		"anbu_baykus":
			k.ears = [[0.58, 0.1, 0.24, true]]
			k.bumps = [[0.0, -0.016, 0.012, 0.024, 0.012, false]]
			k.shell()
			k.dot(0.04, 0.024, 0.034, 0.034, Color(0.6, 0.44, 0.2), true, 0.0, 0.001)
			k.dot(0.04, 0.024, 0.028, 0.028, k.fg, true, 0.0, 0.0013)
			for i in 12:
				var a := TAU * i / 12.0
				k.st([V.call(0.04 + cos(a) * 0.019, 0.024 + sin(a) * 0.019), V.call(0.04 + cos(a) * 0.027, 0.024 + sin(a) * 0.027)], 0.0024, Color(0.45, 0.32, 0.15), true, 0.2)
			k.eyes(0.024, 0.04, 0.0145)
			k.poly([V.call(-0.011, 0.0), V.call(0.011, 0.0), V.call(0.0, -0.038)], GLD, false, 0.002)
			for i in 3:
				for j in 3 - i:
					k.st([V.call(0.016 + j * 0.022 + i * 0.011, -0.058 - i * 0.017), V.call(0.021 + j * 0.022 + i * 0.011, -0.065 - i * 0.017), V.call(0.026 + j * 0.022 + i * 0.011, -0.058 - i * 0.017)], 0.0026, Color(0.45, 0.32, 0.15))
		"anbu_kartal":
			k.bumps = [[0.0, -0.022, 0.016, 0.032, 0.026, false]]
			k.shell()
			k.st([V.call(0.014, 0.05), V.call(0.05, 0.05), V.call(0.088, 0.066)], 0.012, INK, true, 0.8)
			k.eyes(0.022, 0.04, 0.0115)
			k.poly([V.call(-0.016, 0.016), V.call(0.016, 0.016), V.call(0.01, -0.03), V.call(0.0, -0.066), V.call(-0.01, -0.03)], GLD, false, 0.003)
			k.st([V.call(-0.014, -0.016), V.call(0.0, -0.022), V.call(0.014, -0.016)], 0.0022, Color(0.5, 0.33, 0.1), false, 0.1)
			for i in 4:
				k.st([V.call(0.05 + i * 0.008, -0.03 - i * 0.015), V.call(0.08 - i * 0.006, -0.018 - i * 0.022)], 0.005, INK)
		"anbu_tavsan":
			k.ears = [[0.3, 0.075, 0.95, false]]
			k.shell()
			k.dot(0.05, 0.176, 0.009, 0.042, PNK, true, -0.26)
			k.eyes(0.022, 0.037, 0.0125)
			k.dot(0.0, -0.026, 0.0065, 0.0046, PNK, false)
			k.st([V.call(0, -0.032), V.call(0, -0.05)], 0.0026, INK, false, 0.1)
			k.st([V.call(0, -0.05), V.call(0.012, -0.057), V.call(0.024, -0.048)], 0.0028, INK)
			k.poly([V.call(0.001, -0.056), V.call(0.012, -0.058), V.call(0.011, -0.074), V.call(0.002, -0.074)], Color(0.96, 0.95, 0.92))
			for i in 2:
				k.st([V.call(0.058, -0.03 - i * 0.012), V.call(0.086, -0.024 - i * 0.016)], 0.0026, INK)
		"anbu_geyik":
			k.ears = [[1.15, 0.13, 0.22, true]]
			k.bumps = [[0.0, -0.06, 0.028, 0.04, 0.012, false]]
			k.shell()
			var br := Color(0.45, 0.3, 0.17)
			for t in [[0.04, 0.09, 0.075, 0.2], [0.058, 0.145, 0.03, 0.17], [0.064, 0.16, 0.1, 0.205]]:
				for s2 in [-1.0, 1.0]:
					_bar(k.mb, Vector3(float(t[0]) * s2, float(t[1]), 0.0), Vector3(float(t[2]) * s2, float(t[3]), -0.006), 0.0085, br)
			for p in [[0.058, 0.066], [0.074, 0.044], [0.06, -0.016], [0.078, -0.04], [0.05, -0.05]]:
				k.dot(float(p[0]), float(p[1]), 0.005, 0.005, Color(0.72, 0.46, 0.24))
			k.eyes(0.024, 0.038, 0.0125)
			k.dot(0.0, -0.07, 0.0095, 0.0062, INK, false)
			k.st([V.call(0, -0.076), V.call(0, -0.094)], 0.0024, INK, false, 0.1)
		"anbu_kaplumbaga":
			k.shell()
			var hexa = func(c: Vector2, r: float) -> void:
				var pts := []
				for i in 7:
					var a := PI / 6.0 + TAU * i / 6.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				k.st(pts, 0.0034, GRN, false, 0.0)
			hexa.call(V.call(0.0, 0.086), 0.019)
			for s2 in [-1.0, 1.0]:
				hexa.call(V.call(0.034 * s2, 0.066), 0.019)
				hexa.call(V.call(0.068 * s2, 0.046), 0.016)
			k.eyes(0.012, 0.036, 0.0115)
			k.dot(0.005, -0.03, 0.002, 0.0026, INK)
			k.st([V.call(0, -0.056), V.call(0.024, -0.062), V.call(0.052, -0.052)], 0.0045, GRN)
		"anbu_yarasa":
			k.ears = [[0.62, 0.12, 0.62, true]]
			k.shell()
			k.dot(0.082, 0.138, 0.016, 0.036, INK, true, -0.48)
			k.st([V.call(0.0, 0.08), V.call(0.032, 0.05), V.call(0.074, 0.058)], 0.008, INK)
			k.eyes(0.018, 0.038, 0.0125)
			k.poly([V.call(-0.01, -0.02), V.call(0.01, -0.02), V.call(0.0, -0.036)], INK, false)
			k.st([V.call(0.0, -0.058), V.call(0.024, -0.05), V.call(0.05, -0.06)], 0.0036, INK)
			k.poly([V.call(0.02, -0.056), V.call(0.033, -0.056), V.call(0.027, -0.084)], RED)
		"anbu_kurbaga":
			k.ears = [[0.56, 0.17, 0.22, false]]
			k.shell()
			k.dot(0.058, 0.094, 0.025, 0.025, GRN, true, 0.0, 0.001)
			k.dot(0.058, 0.094, 0.018, 0.018, k.fg, true, 0.0, 0.0014)
			k.dot(0.058, 0.094, 0.009, 0.009, INK)
			k.eyes(0.014, 0.036, 0.0115)
			k.dot(0.008, -0.024, 0.0024, 0.002, INK)
			k.st([V.call(0.0, -0.06), V.call(0.04, -0.062), V.call(0.082, -0.03)], 0.0065, GRN, true, 0.5)
			for p in [[0.05, -0.012], [0.066, 0.006], [0.073, -0.022]]:
				k.dot(float(p[0]), float(p[1]), 0.0046, 0.0046, GRN)
		"anbu_ejder":
			k.ears = [[0.98, 0.12, 0.16, true]]
			k.bumps = [[0.0, -0.05, 0.036, 0.03, 0.016, false], [0.038, 0.05, 0.024, 0.01, 0.007, true]]
			k.shell()
			k.horn(0.056, 0.14, -0.006, 0.026, 0.1, 24.0, GLD, 8, -16.0)
			k.st([V.call(0.012, 0.052), V.call(0.044, 0.05), V.call(0.08, 0.07)], 0.0075, RED)
			k.eyes(0.02, 0.04, 0.0115)
			for i in 4:
				var y := 0.102 - i * 0.012
				k.st([V.call(0.0, y), V.call(0.009, y - 0.008), V.call(0.018, y)], 0.0028, RED)
			k.dot(0.011, -0.04, 0.0036, 0.0028, INK)
			k.st([V.call(0.0, -0.068), V.call(0.038, -0.074), V.call(0.074, -0.044)], 0.0045, INK)
			for i in 4:
				k.poly([V.call(0.008 + i * 0.016, -0.069 - (0.002 if i < 2 else -0.002)), V.call(0.021 + i * 0.016, -0.069 + i * 0.001), V.call(0.0145 + i * 0.016, -0.086 + i * 0.002)], Color(0.97, 0.96, 0.9))
			k.st([V.call(0.05, -0.012), V.call(0.076, -0.016), V.call(0.094, -0.002)], 0.0055, RED)
		"kitsune", "kitsune_festival":
			var fes := s == "kitsune_festival"
			k.ears = [[0.64, 0.12, 0.42, true]]
			k.bumps = [[0.0, -0.066, 0.024, 0.04, 0.022, false]]
			k.shell()
			k.dot(0.07, 0.126, 0.012, 0.03, RED, true, -0.46)
			k.st([V.call(0.012, 0.03), V.call(0.04, 0.02), V.call(0.07, 0.044)], 0.0092, Color(0.04, 0.03, 0.04), true, 0.7)
			k.st([V.call(0.014, 0.05), V.call(0.044, 0.046), V.call(0.08, 0.072)], 0.0062, RED)
			k.dot(0.0, 0.076, 0.009, 0.015, RED, false)
			if fes:
				k.dot(0.0, 0.076, 0.004, 0.008, GLD, false, 0.0, 0.0022)
				for p in [[0.052, 0.086], [0.03, 0.098]]:
					k.dot(float(p[0]), float(p[1]), 0.0056, 0.0056, GLD)
			for i in 3:
				k.st([V.call(0.05, -0.022 - i * 0.012), V.call(0.08 + i * 0.002, -0.014 - i * 0.017)], 0.0038, RED if fes else INK)
			k.dot(0.0, -0.092, 0.0062, 0.0042, INK, false)
			k.st([V.call(0, -0.097), V.call(0.016, -0.106), V.call(0.038, -0.082)], 0.004, RED)
		"tengu":
			k.bumps = [[0.03, 0.044, 0.03, 0.012, 0.012, true], [0.04, -0.04, 0.026, 0.024, 0.008, true]]
			k.shell()
			var dk := k.fg.darkened(0.34)
			k.st([V.call(0.008, 0.038), V.call(0.04, 0.058), V.call(0.082, 0.05)], 0.018, Color(0.96, 0.95, 0.92), true, 0.75)
			k.dot(0.04, 0.02, 0.0165, 0.0105, Color(0.97, 0.94, 0.8), true, -0.14)
			k.dot(0.04, 0.02, 0.0072, 0.0072, INK)
			k.st([V.call(0.018, -0.044), V.call(0.052, -0.054), V.call(0.08, -0.03)], 0.006, dk)
			k.st([V.call(0.02, -0.074), V.call(0.0, -0.066)], 0.0048, INK)
			k.mb.add_mesh(_nose_cone(k.fg))
			for i in 7:
				var t := i / 6.0
				k.st([V.call(0.012 + t * 0.03, -0.108 + t * 0.016), V.call(0.018 + t * 0.03, -0.14 + t * 0.03)], 0.0065, Color(0.96, 0.95, 0.92))
		"oni":
			k.bumps = [[0.038, 0.05, 0.034, 0.013, 0.018, true], [0.05, -0.046, 0.03, 0.022, 0.012, true]]
			k.shell()
			k.horn(0.056, 0.134, -0.006, 0.034, 0.095, 15.0, Color(0.92, 0.88, 0.74), 8, -12.0)
			k.st([V.call(0.006, 0.03), V.call(0.044, 0.062), V.call(0.088, 0.056)], 0.015, INK, true, 0.55)
			k.dot(0.042, 0.022, 0.0175, 0.0115, GLD, true, 0.18)
			k.dot(0.042, 0.022, 0.0058, 0.0058, INK)
			k.dot(0.011, -0.03, 0.0064, 0.0048, k.fg.darkened(0.55))
			k.poly([V.call(-0.05, -0.058), V.call(0.05, -0.058), V.call(0.04, -0.092), V.call(-0.04, -0.092)], Color(0.1, 0.03, 0.04), false)
			for i in 3:
				k.poly([V.call(0.004 + i * 0.015, -0.058), V.call(0.016 + i * 0.015, -0.058), V.call(0.01 + i * 0.015, -0.069)], Color(0.97, 0.95, 0.88), true, 0.002)
			k.poly([V.call(0.03, -0.092), V.call(0.043, -0.09), V.call(0.042, -0.058)], Color(0.97, 0.95, 0.88), true, 0.002)
		"hannya":
			k.ears = [[1.42, 0.11, 0.2, true]]
			k.bumps = [[0.036, 0.052, 0.03, 0.016, 0.02, true], [0.05, -0.05, 0.028, 0.024, 0.016, true]]
			k.shell()
			k.horn(0.05, 0.13, -0.008, 0.032, 0.125, 11.0, GLD, 8, -10.0)
			k.st([V.call(0.008, 0.024), V.call(0.03, 0.064), V.call(0.08, 0.078)], 0.0078, INK)
			k.dot(0.043, 0.022, 0.0185, 0.0085, GLD, true, 0.34)
			k.dot(0.044, 0.022, 0.0056, 0.0056, INK)
			k.st([V.call(0.012, 0.0), V.call(0.024, -0.02), V.call(0.012, -0.038)], 0.0034, INK.lightened(0.15))
			k.poly([V.call(-0.07, -0.05), V.call(-0.03, -0.056), V.call(0.03, -0.056), V.call(0.07, -0.05), V.call(0.044, -0.104), V.call(-0.044, -0.104)], Color(0.32, 0.03, 0.05), false)
			for i in 4:
				k.poly([V.call(0.003 + i * 0.015, -0.055 + i * 0.0003), V.call(0.0155 + i * 0.015, -0.054), V.call(0.009 + i * 0.015, -0.068)], GLD.lightened(0.45), true, 0.002)
			k.poly([V.call(0.04, -0.1), V.call(0.051, -0.09), V.call(0.052, -0.06)], GLD.lightened(0.45), true, 0.002)
		"okame":
			k.bumps = [[0.055, -0.03, 0.04, 0.034, 0.024, true], [0.0, 0.07, 0.06, 0.03, 0.006, false]]
			k.shell()
			k.dot(0.058, -0.026, 0.021, 0.0165, PNK)
			k.st([V.call(0.018, 0.0225), V.call(0.038, 0.03), V.call(0.058, 0.0205)], 0.0042, INK, true, 0.4)
			k.dot(0.026, 0.078, 0.009, 0.0062, INK, true, 0.1)
			k.dot(0.0, -0.026, 0.0034, 0.0026, INK.lightened(0.2), false)
			k.dot(0.0, -0.066, 0.0105, 0.0046, RED, false)
			k.dot(0.0, -0.0645, 0.0044, 0.0022, Color(0.32, 0.05, 0.08), false, 0.0, 0.0024)
		"kok_maskesi":
			k.shell()
			k.st([V.call(0.0, 0.106), V.call(0.0, 0.05)], 0.0052, INK, false, 0.3)
			for i in 3:
				var y := 0.092 - i * 0.016
				k.st([V.call(0.0, y), V.call(0.018 + i * 0.006, y - 0.012), V.call(0.03 + i * 0.012, y - 0.008)], 0.0038, INK)
			k.st([V.call(0.03, -0.012), V.call(0.042, -0.05), V.call(0.03, -0.094)], 0.0048, RED)
			k.eyes(0.02, 0.035, 0.0118)
			k.st([V.call(0.008, -0.075), V.call(0.0, -0.077)], 0.003, INK)
		"spiral_maske":
			k.ears = []
			k.shell()
			var pts := []
			for i in 44:
				var t := i / 43.0
				var a := -0.2 + t * TAU * 3.25
				var r := 0.012 + t * 0.098
				pts.append(V.call(0.018 + sin(a) * r * 0.8, 0.022 + cos(a) * r))
			var clip := pts.filter(func(q): return (q as Vector2).length() < 0.108)
			k.st(clip, 0.0062, k.fg.darkened(0.42), false, 0.2)
			k.dot(0.018, 0.022, 0.0115, 0.0115, k.fg.darkened(0.5), false, 0.0, 0.0018)
			k.dot(0.018, 0.022, 0.0085, 0.0085, Color(0.02, 0.02, 0.03), false, 0.0, 0.0024)
		"avci_maske":
			k.shell()
			for i in 2:
				k.st([V.call(-0.016 + i * 0.012, 0.094 + i * 0.012 - 0.012), V.call(0.0 + i * 0.012, 0.102 + i * 0.012 - 0.012), V.call(0.014 + i * 0.012, 0.09 + i * 0.012 - 0.012)], 0.0036, INK, false, 0.2)
			k.st([V.call(0.02, 0.018), V.call(0.038, 0.024), V.call(0.058, 0.014)], 0.0085, Color(0.02, 0.02, 0.03), true, 0.65)
			k.st([V.call(-0.05, -0.05), V.call(-0.026, -0.044), V.call(0.0, -0.05), V.call(0.026, -0.044), V.call(0.05, -0.05)], 0.0042, BLU, false, 0.4)
			k.st([V.call(-0.036, -0.068), V.call(-0.012, -0.062), V.call(0.012, -0.068), V.call(0.036, -0.062)], 0.0034, BLU, false, 0.4)
		"kemik_maske":
			k.bumps = [[0.042, 0.028, 0.03, 0.026, -0.006, true], [0.05, -0.03, 0.024, 0.02, -0.009, true]]
			k.shell()
			k.dot(0.041, 0.022, 0.0255, 0.0245, Color(0.03, 0.03, 0.04))
			k.poly([V.call(0.0, -0.002), V.call(0.0105, -0.034), V.call(-0.0105, -0.034)], Color(0.03, 0.03, 0.04), false)
			k.st([V.call(0.074, 0.074), V.call(0.052, 0.082), V.call(0.044, 0.1)], 0.0034, k.fg.darkened(0.42))
			k.st([V.call(-0.02, 0.112), V.call(-0.012, 0.086), V.call(-0.024, 0.068)], 0.0034, k.fg.darkened(0.42), false)
			k.st([V.call(0.0, -0.06), V.call(0.038, -0.058), V.call(0.058, -0.05)], 0.0034, INK)
			for i in 5:
				k.st([V.call(0.005 + i * 0.012, -0.05), V.call(0.005 + i * 0.012, -0.112 + i * 0.008)], 0.0026, INK, true, 0.1)


static func _bar(mb: MB, a: Vector3, b: Vector3, w: float, c: Color) -> void:
	var d := b - a
	var up := d.normalized()
	var x := up.cross(Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(up).normalized()
	mb.add_xf("cyl", Transform3D(Basis(x * w, up * d.length(), z * w), (a + b) * 0.5), c, 6)


## Tengu burnu: kabuktan öne çıkan, kök kalın uç küt koni
static func _nose_cone(c: Color) -> MB:
	var mb := MB.new()
	mb.add("cone", Vector3(0, -0.017, 0.09), Vector3(0.036, 0.135, 0.034), c, Vector3(84, 0, 0), 12)
	mb.add("sphere", Vector3(0, -0.009, 0.154), Vector3(0.015, 0.015, 0.016), c.lightened(0.05), Vector3.ZERO, 8)
	mb.add("sphere", Vector3(0, -0.018, 0.04), Vector3(0.05, 0.042, 0.04), c, Vector3.ZERO, 10)
	return mb


static func build(m, s, fg: Color) -> bool:
	if s in PB.STYLES:
		return PB.build(m, s, fg)
	if not s in STYLES:
		return false
	fg = BASE.get(s, ANBU_WHITE)
	var key := String(s)
	if not _cache.has(key):
		var k := Mk.new(fg)
		_design(k, s)
		_cache[key] = k.mb.build(Props.toon())
	var hc: Vector3 = m._head_center()
	var ab: AABB = m.head_ab
	var hw := clampf(ab.size.x, 0.16, 0.26) if ab.size.x > 0.05 else 0.2
	var ey: float = m.eye_center_model.y if m.face_mi else hc.y - 0.03
	var sc := clampf(hw / 0.19, 0.85, 1.15) * 0.8   # yalnız yüzü kaplasın (kullanıcı: "kabile maskesi gibi büyük")
	var org := Vector3(hc.x, ey - 0.012, hc.z + 0.075 * sc)
	org.z += _push(m, org, sc)   # yüz kabuğun önüne taşmasın (şakak / kaş köşeleri 1-2 cm içeri giriyordu)
	m._mesh_on("Head", _cache[key], Transform3D(Basis.from_scale(Vector3.ONE * sc), org))
	return true


static var _push_cache := {}
## Maske dış çizgisinin içinde kalan yüz köşelerinden kabuğun önüne en çok taşanı kadar maske öne alınır (+3 mm pay).
## Yüz modeline göre önbellekli (yaş / cinsiyet / yüz kaynağı)
static func _push(m, org: Vector3, sc: float) -> float:
	if m._face_src.is_empty():
		return 0.0
	var key := "%s|%.3f|%.3f" % [m._sk_key, sc, org.z - float(m._head_center().z)]
	if _push_cache.has(key):
		return _push_cache[key]
	var fm: Mesh = m._face_src[0]
	var fx: Transform3D = m._face_src[1]
	var k := Mk.new(Color.WHITE)
	var worst := 0.0
	for si in fm.get_surface_count():
		for v in (fm.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var q: Vector3 = fx * v
			var l := Vector2(q.x - org.x, q.y - org.y) / sc
			if l.length() > k.edge(atan2(l.x, l.y)).length() * 0.97:
				continue
			worst = maxf(worst, q.z - (org.z + k.S(l.x, l.y) * sc))
	var r := (worst + 0.003) if worst > 0.0 else 0.0
	_push_cache[key] = r
	return r
