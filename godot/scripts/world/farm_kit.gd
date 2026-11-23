extends RefCounted
## Tarlalar: araziyi izleyen parseller. Kutu yok; pirinç tarlası = alçak toprak setler arasında su ve tek tek pirinç öbekleri,
## sebze bahçesi = sürülmüş toprak, yuvarlak sırtlar ve sıra sıra ekin. Her katman araziyi izler, hiçbir parça havada kalmaz.

const SOIL := Color(0.36, 0.26, 0.17)
const SOIL_D := Color(0.27, 0.19, 0.13)
const BUND := Color(0.42, 0.36, 0.2)
const BUND_G := Color(0.4, 0.52, 0.24)
const WATER := Color(0.36, 0.52, 0.55)
const WATER_D := Color(0.27, 0.43, 0.48)


## yerel plan (u, v) -> dünya xz + arazi yüksekliği
static func _at(b: Builder, x: float, n: float, yaw: float, u: float, v: float) -> Vector3:
	var o = Builder.rot(u, v, yaw)
	var wp: Vector3 = b.w(Vector3(x + o.x, 0.0, n + o.y))
	wp.y = Game.terrain_height(wp.x, wp.z)
	return wp


static func _v(m: MB, p: Vector3, nr: Vector3, c: Color) -> int:
	m.verts.append(p)
	m.normals.append(nr)
	m.colors.append(c)
	m.uvs.append(Vector2.ZERO)
	return m.verts.size() - 1


static func _quad(m: MB, a: int, b: int, c: int, d: int) -> void:
	m.idx.append_array(PackedInt32Array([a, c, b, b, c, d]))


## Zemine oturan ince katman: suya da toprağa (level INF: araziyi izler)
static func _sheet(m: MB, b: Builder, x: float, n: float, yaw: float, u0: float, u1: float, v0: float, v1: float, level: float, dy: float, c0: Color, c1: Color, rng: RandomNumberGenerator) -> void:
	var nu = maxi(2, int((u1 - u0) / 1.2))
	var nv = maxi(2, int((v1 - v0) / 1.2))
	var ids = []
	for j in nv + 1:
		for i in nu + 1:
			var p = _at(b, x, n, yaw, lerpf(u0, u1, float(i) / nu), lerpf(v0, v1, float(j) / nv))
			p.y = level if level != INF else p.y + dy
			ids.append(_v(m, p, Vector3.UP, c0.lerp(c1, rng.randf())))
	for j in nv:
		for i in nu:
			var a = j * (nu + 1) + i
			_quad(m, ids[a], ids[a + 1], ids[a + nu + 1], ids[a + nu + 2])


## Araziyi izleyen yuvarlak sırt (set / ekim sırtı); tabanı toprağın içinde biter
static func _ridge(m: MB, b: Builder, x: float, n: float, yaw: float, a: Vector2, e: Vector2, wd: float, h: float, top: Color, side: Color, rng: RandomNumberGenerator, floor_y := -INF) -> void:
	const SEC := [[-1.0, -0.5], [-0.72, 0.42], [-0.3, 0.92], [0.3, 0.92], [0.72, 0.42], [1.0, -0.5]]
	var L = a.distance_to(e)
	var cnt = maxi(2, int(L / 1.1))
	var d = (e - a).normalized()
	var s = Vector2(-d.y, d.x)
	var first = -1
	for j in cnt + 1:
		var q = a.lerp(e, float(j) / cnt)
		var wob = rng.randf_range(-0.07, 0.07)
		var hk = rng.randf_range(0.86, 1.1)
		for i in SEC.size():
			var f: float = SEC[i][0]
			var r = q + s * (f * wd + wob)
			var p = _at(b, x, n, yaw, r.x, r.y)
			p.y = maxf(p.y, floor_y) + float(SEC[i][1]) * h * hk
			var o = Builder.rot(s.x * f, s.y * f, yaw)
			var nr = Vector3(o.x, 0.9, -o.y).normalized()
			var k = _v(m, p, nr, top if absf(f) < 0.5 else side.lerp(top, 0.25))
			if first < 0:
				first = k
	for j in cnt:
		for i in SEC.size() - 1:
			var p0 = first + j * SEC.size() + i
			_quad(m, p0, p0 + 1, p0 + SEC.size(), p0 + SEC.size() + 1)


## Eğik yaprak: iki parçalı, ucu açık renk; iki yüzlü
static func _blade(m: MB, base: Vector3, dir: Vector3, ln: float, w: float, droop: float, c0: Color, c1: Color) -> void:
	var s = dir.cross(Vector3.UP)
	s = s.normalized() * w if s.length() > 0.01 else Vector3.RIGHT * w
	var mid = base + dir * ln * 0.55
	var tip = base + dir * ln + Vector3.DOWN * droop
	var nr = (s.cross(dir)).normalized()
	if nr.y < 0.0:
		nr = -nr
	nr = (nr + Vector3.UP).normalized()
	var cm = c0.lerp(c1, 0.55)
	var a = _v(m, base - s, nr, c0)
	var b = _v(m, base + s, nr, c0)
	var c = _v(m, mid - s * 0.75, nr, cm)
	var d = _v(m, mid + s * 0.75, nr, cm)
	var e = _v(m, tip, nr, c1)
	m.idx.append_array(PackedInt32Array([a, c, b, b, c, d, c, e, d, a, b, c, b, d, c, c, d, e]))


static func _tuft(m: MB, at: Vector3, n: int, ln: float, w: float, lean: float, c0: Color, c1: Color, rng: RandomNumberGenerator) -> void:
	var a0 = rng.randf() * TAU
	for k in n:
		var a = a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var dir = Vector3(cos(a) * lean, 1.0, sin(a) * lean).normalized()
		_blade(m, at + Vector3(cos(a), 0, sin(a)) * 0.03, dir, ln * rng.randf_range(0.8, 1.15), w, ln * lean * 0.35, c0, c1)


# ------------------------------------------------------------------ pirinç tarlası
## can_yield: oyun sırasında (dünya bölgesi) ortak kare bütçesi dolunca bir sonraki kareye geçer; tarla başına ~2000 pirinç öbeği
## tek karede ~95 ms sürüyordu (yükleme sonrası düzinelerce tarla = FPS 7)
static func paddy(b: Builder, x: float, n: float, yaw: float, wd: float, dp: float, rng: RandomNumberGenerator, can_yield := false) -> void:
	var cw: Vector3 = _at(b, x, n, yaw, 0.0, 0.0)
	var soil: MB = b._cell(cw, 2)
	var crop: MB = b._cell(cw, 1)
	var S = maxi(3, int(round(dp / 4.5)))
	var hu = wd * 0.5
	var sd = dp / S
	for k in S:
		var v0 = -dp * 0.5 + k * sd
		var v1 = v0 + sd
		_sheet(soil, b, x, n, yaw, -hu + 0.2, hu - 0.2, v0 + 0.2, v1 - 0.2, INF, 0.07, WATER, WATER_D, rng)   # su bütün parseli kaplar, araziyi izler
		var C = [Vector2(-hu, v0), Vector2(hu, v0), Vector2(hu, v1), Vector2(-hu, v1)]
		for e in 4:
			if e == 2 and k < S - 1:
				continue   # ortak set bir kez
			_ridge(soil, b, x, n, yaw, C[e], C[(e + 1) % 4], 0.55, 0.42, BUND_G, BUND, rng)
		var u = -hu + 0.85
		while u < hu - 0.7:
			var v = v0 + 0.75 + rng.randf_range(0.0, 0.2)
			while v < v1 - 0.6:
				var p = _at(b, x, n, yaw, u + rng.randf_range(-0.08, 0.08), v + rng.randf_range(-0.08, 0.08))
				p.y += 0.05
				var ripe = rng.randf()
				_tuft(crop, p, 5, rng.randf_range(0.55, 0.78), 0.022, 0.3, Color(0.27, 0.47, 0.2), Color(0.55, 0.72, 0.28).lerp(Color(0.78, 0.72, 0.32), ripe * 0.5), rng)
				v += 0.72
			u += 0.82
			if can_yield and BuildSites.frame_busy():
				await Engine.get_main_loop().process_frame
				if not is_instance_valid(b.root):
					return
	var c0: Vector3 = _at(b, x, n, yaw, 0.0, 0.0)
	b._grass_clear(c0, Vector3(wd + 1.0, 0.1, dp + 1.0), -yaw)


# ------------------------------------------------------------------ sebze bahçesi
static func veg(b: Builder, x: float, n: float, yaw: float, wd: float, dp: float, rng: RandomNumberGenerator, only := "") -> void:
	var cw: Vector3 = _at(b, x, n, yaw, 0.0, 0.0)
	var soil: MB = b._cell(cw, 2)
	var crop: MB = b._cell(cw, 1)
	var hu = wd * 0.5
	var hv = dp * 0.5
	_sheet(soil, b, x, n, yaw, -hu, hu, -hv, hv, INF, 0.035, SOIL_D, SOIL_D.lerp(SOIL, 0.6), rng)
	var kinds = ["lahana", "yesillik", "fasulye", "havuc", "balkabagi", "yesillik", "pirasa"]
	kinds.shuffle()
	var rows = maxi(3, int(wd / 2.2))
	for r in rows:
		var u = lerpf(-hu + 1.1, hu - 1.1, float(r) / (rows - 1))
		_ridge(soil, b, x, n, yaw, Vector2(u, -hv + 0.5), Vector2(u, hv - 0.5), 0.56, 0.24, SOIL.lightened(0.08), SOIL_D, rng)
		var kind: String = only if only != "" else kinds[r % kinds.size()]
		var step = {"lahana": 0.95, "balkabagi": 1.5, "fasulye": 1.15, "havuc": 0.42, "pirasa": 0.4}.get(kind, 0.55)
		var v = -hv + 0.9
		while v < hv - 0.8:
			_plant(crop, _at(b, x, n, yaw, u + rng.randf_range(-0.09, 0.09), v) + Vector3.UP * 0.2, kind, rng)
			v += step
	b._grass_clear(cw, Vector3(wd + 0.6, 0.1, dp + 0.6), -yaw)


static func _plant(m: MB, p: Vector3, kind: String, rng: RandomNumberGenerator) -> void:
	match kind:
		"lahana":
			var g = Color(0.42, 0.62, 0.3).lerp(Color(0.56, 0.72, 0.38), rng.randf())
			m.add("sphere", p + Vector3.UP * 0.17, Vector3(0.42, 0.34, 0.42), g.lightened(0.14), Vector3.ZERO, 7)
			_tuft(m, p, 7, 0.46, 0.1, 1.5, g.darkened(0.2), g, rng)
		"yesillik":
			_tuft(m, p, 6, 0.36, 0.055, 0.7, Color(0.26, 0.46, 0.2), Color(0.5, 0.7, 0.3), rng)
		"havuc":
			_tuft(m, p, 4, 0.34, 0.016, 0.3, Color(0.24, 0.44, 0.2), Color(0.42, 0.64, 0.26), rng)
			m.add("sphere", p + Vector3.UP * 0.01, Vector3(0.07, 0.06, 0.07), Color(0.88, 0.48, 0.16), Vector3.ZERO, 5)
		"pirasa":
			_tuft(m, p, 3, 0.52, 0.03, 0.14, Color(0.82, 0.86, 0.72), Color(0.34, 0.56, 0.3), rng)
		"balkabagi":
			_tuft(m, p, 6, 0.6, 0.09, 1.7, Color(0.24, 0.42, 0.2), Color(0.42, 0.6, 0.26), rng)
			var c = Color(0.88, 0.52, 0.16).lerp(Color(0.8, 0.62, 0.22), rng.randf())
			var o = Vector3(rng.randf_range(-0.2, 0.2), 0.11, rng.randf_range(-0.2, 0.2))
			for k in 5:
				var a = k * TAU / 5.0
				m.add("sphere", p + o + Vector3(cos(a), 0, sin(a)) * 0.08, Vector3(0.17, 0.22, 0.17), c, Vector3.ZERO, 6)
			m.add("cyl", p + o + Vector3.UP * 0.12, Vector3(0.025, 0.08, 0.025), Color(0.35, 0.42, 0.2), Vector3.ZERO, 4)
		"fasulye":
			var h = rng.randf_range(1.45, 1.75)
			var tilt = Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			m.add("cyl", p + Vector3.UP * h * 0.5, Vector3(0.035, h, 0.035), Color(0.55, 0.43, 0.28), tilt, 4)
			var y = 0.2
			while y < h - 0.1:
				var a = y * 5.3 + rng.randf()
				var at = p + Vector3(cos(a) * 0.05, y, sin(a) * 0.05)
				_blade(m, at, Vector3(cos(a), 0.45, sin(a)).normalized(), 0.26, 0.075, 0.08, Color(0.25, 0.46, 0.2), Color(0.46, 0.66, 0.28))
				if rng.randf() < 0.3:
					m.add("cyl", at + Vector3(cos(a) * 0.1, -0.09, sin(a) * 0.1), Vector3(0.016, 0.15, 0.016), Color(0.5, 0.72, 0.28), Vector3.ZERO, 4)
				y += 0.13
