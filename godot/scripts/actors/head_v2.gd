extends RefCounted
## Kafalıklar (yeni nesil): dönel gövde üstüne kare kare boyanmış hasır / lake / örgü dokusu, bağlı kenar, çene ipi.
## Hepsi Head kemiğine; ölçüler kafanın gerçek boyundan. OutfitParts çağırır, CharacterModel eski tarifi atlar.

const Kit = preload("res://scripts/actors/head_kit.gd")
const PB = preload("res://scripts/actors/head_v2_b.gd")   # sert başlıklar
const PC = preload("res://scripts/actors/head_v2_c.gd")   # kumaş başlıklar
const STYLES := ["kasa", "kasa_y", "jingasa", "tengai", "neko_zukin", "fukumen", "sarashi_bo", "sarashi_zukin", "kami_hana", "gama_hitai"]
const HIDE_HAIR := ["tengai", "neko_zukin", "fukumen", "sarashi_zukin"]
const HOODED := ["neko_zukin", "fukumen"]
const ROPE := Kit.ROPE


static func has(s) -> bool:
	return s in STYLES or s in PB.STYLES or s in PC.STYLES


static func hides_hair(s) -> bool:
	return s in HIDE_HAIR or s in PB.HIDE_HAIR or s in PC.HIDE_HAIR


static func hooded(s) -> bool:
	return s in HOODED or s in PC.HOODED


static func build(m, s, col: Color, L: Dictionary) -> bool:
	if s in PB.STYLES:
		return PB.build(m, s, col, L)
	if s in PC.STYLES:
		return PC.build(m, s, col, L)
	if not s in STYLES:
		return false
	match s:
		"kasa": _kasa(m, col, false)
		"kasa_y": _kasa(m, col, true)
		"jingasa": _jingasa(m, col)
		"tengai": _tengai(m, col)
		"neko_zukin": _neko(m, col, L)
		"fukumen": _fukumen(m, col, L)
		"sarashi_bo": _sarashi_bo(m, col)
		"sarashi_zukin": _sarashi_zukin(m, col, L)
		"kami_hana": _hana(m, col)
		"gama_hitai": _gama(m, col)
	return true


# ---------------------------------------------------------------- hasır
static func _kasa(m, col: Color, torn: bool) -> void:
	var hw := Kit._hw(m)
	var hc: Vector3 = m._head_center()
	var base: float = m.head_top() - 0.06
	var R := hw * 1.62
	var H := 0.165
	var p := []
	var nt := 15
	for k in nt + 1:
		var t := float(k) / nt
		p.append(Vector2(maxf(R * t, 0.002), H * pow(1.0 - t, 1.12)))
	var top_n := p.size()
	p.append(Vector2(R + 0.005, -0.004))
	p.append(Vector2(R + 0.005, -0.013))
	p.append(Vector2(R - 0.008, -0.017))
	p.append(Vector2(R * 0.55, H * 0.42 - 0.02))
	p.append(Vector2(0.01, H - 0.03))
	var ragged = func(a: float) -> float:
		return absf(sin(a * 7.0 + 0.6) + 0.6 * sin(a * 17.0 + 1.0) + 0.35 * sin(a * 41.0))
	var colf = func(i: int, j: int, a: float, q: Vector2) -> Color:
		var c := col
		if j >= top_n + 2:
			c = col.darkened(0.38 if i % 2 == 0 else 0.45)
		elif j >= top_n - 1:
			c = col.darkened(0.55) if not torn else col.darkened(0.3 + 0.12 * float(i % 3))
		elif j < 2:
			c = col.darkened(0.42)
		else:
			c = col.darkened(0.17) if i % 4 == 0 else (col.darkened(0.05) if i % 4 == 2 else col.lightened(0.05))
			if j % 3 == 0:
				c = c.darkened(0.12)
			if torn:
				c = c.darkened(0.1 * float((i * 7 + j * 3) % 3))
				if j > 9 and ragged.call(a) > 1.45:
					c = col.darkened(0.6)
		return c
	var off = func(a: float, j: int) -> Vector2:
		var t := clampf(float(j) / nt, 0.0, 1.0)
		var ry := sin(a * 24.0) * 0.0028 * t
		var rs := 1.0
		if torn and j > 10:
			rs = 1.0 - 0.17 * clampf((float(j) - 10.0) / 6.0, 0.0, 1.0) * clampf(ragged.call(a) / 1.8, 0.0, 1.0)
		return Vector2(rs, ry if j < top_n else 0.0)
	var mb := MB.new()
	Kit._rev(mb, p, 96, colf, off)
	mb.add("sphere", Vector3(0, H + 0.002, 0), Vector3(0.03, 0.02, 0.03), col.darkened(0.5), Vector3.ZERO, 10)
	mb.add("cyl", Vector3(0, 0.03, 0), Vector3(hw * 1.05, 0.04, hw * 1.12), col.darkened(0.48), Vector3.ZERO, 16)
	Kit._chin(mb, base, m, hw, ROPE)
	Kit._put(m, mb, Vector3(hc.x, base, hc.z))
	m.hair_mask_plane(Vector3.UP, Vector3(0, base + 0.005, 0))


# ---------------------------------------------------------------- lake asker şapkası
static func _jingasa(m, col: Color) -> void:
	var hw := Kit._hw(m)
	var hc: Vector3 = m._head_center()
	var base: float = maxf(hc.y + 0.08, m.head_top() + 0.005) - 0.05
	var R := hw * 1.3
	var H := 0.105
	var gold := Color(0.86, 0.68, 0.26)
	var p := []
	var nt := 14
	for k in nt + 1:
		var t := float(k) / nt
		p.append(Vector2(maxf(R * t, 0.002), H * (1.0 - pow(t, 1.55)) + 0.008 * smoothstep(0.82, 1.0, t)))
	var n0 := p.size()
	p.append(Vector2(R + 0.004, 0.004))
	p.append(Vector2(R + 0.002, -0.004))
	p.append(Vector2(R * 0.6, H * 0.45))
	p.append(Vector2(0.01, H - 0.02))
	var colf = func(i: int, j: int, _a: float, _q: Vector2) -> Color:
		if j >= n0 + 1:
			return Color(0.5, 0.1, 0.09)   # içi kırmızı lake
		if j >= n0 - 1:
			return gold.darkened(0.12)
		if j == nt - 2:
			return gold
		if j < 2:
			return gold.darkened(0.2)
		var c := col.lightened(0.09) if j < 5 else col
		return c.lightened(0.07) if i % 12 == 0 else c
	var mb := MB.new()
	Kit._rev(mb, p, 72, colf)
	var ang := rad_to_deg(atan2(H * 1.3, R))
	var f := Vector3(0, H * 0.62 + 0.004, R * 0.42)
	mb.add("cyl", f, Vector3(0.078, 0.006, 0.078), gold, Vector3(90.0 - ang * 2.2, 0, 0), 20)
	mb.add("cyl", f + Vector3(0, 0.003, 0.002), Vector3(0.056, 0.006, 0.056), col, Vector3(90.0 - ang * 2.2, 0, 0), 20)
	mb.add("cyl", f + Vector3(0, 0.006, 0.004), Vector3(0.022, 0.006, 0.022), gold, Vector3(90.0 - ang * 2.2, 0, 0), 12)
	mb.add("sphere", Vector3(0, H + 0.004, 0), Vector3(0.03, 0.018, 0.03), gold, Vector3.ZERO, 10)
	mb.add("cyl", Vector3(0, 0.02, 0), Vector3(hw * 1.04, 0.035, hw * 1.1), Color(0.14, 0.1, 0.09), Vector3.ZERO, 16)
	Kit._chin(mb, base, m, hw, Color(0.5, 0.12, 0.1))
	Kit._put(m, mb, Vector3(hc.x, base, hc.z))
	m.hair_mask_plane(Vector3.UP, Vector3(0, base + 0.005, 0))


# ---------------------------------------------------------------- derin sepet
static func _tengai(m, col: Color) -> void:
	var hw := Kit._hw(m)
	var hc: Vector3 = m._head_center()
	var R := hw * 0.84
	var p: Array = Kit._curve([Vector2(0.002, 0.15), Vector2(R * 0.42, 0.143), Vector2(R * 0.82, 0.112), Vector2(R * 1.0, 0.055), Vector2(R * 1.05, -0.04), Vector2(R * 1.02, -0.14), Vector2(R * 0.94, -0.215)], 5)
	var n0 := p.size()
	p.append(Vector2(R * 0.92, -0.226))
	p.append(Vector2(R * 0.87, -0.22))
	p.append(Vector2(R * 0.88, 0.08))
	var bands := [0.09, 0.0, -0.1, -0.2]
	var colf = func(i: int, j: int, a: float, q: Vector2) -> Color:
		if j >= n0 - 1:
			return col.darkened(0.6)
		if j < 3:
			return col.darkened(0.4)
		for b in bands:
			if absf(q.y - float(b)) < 0.0065:
				return col.darkened(0.42)
		if absf(a) < 0.62 and q.y > -0.052 and q.y < -0.012:   # önde bakış kafesi
			return col.darkened(0.15) if i % 3 == 0 else Color(0.05, 0.04, 0.03)
		return col.darkened(0.2) if (i + j * 2) % 6 < 3 else col.lightened(0.04)
	var mb := MB.new()
	Kit._rev(mb, p, 84, colf)
	mb.add("sphere", Vector3(0, 0.153, 0), Vector3(0.05, 0.02, 0.05), col.darkened(0.45), Vector3.ZERO, 10)
	Kit._put(m, mb, Vector3(hc.x, hc.y + 0.02, hc.z))


# ---------------------------------------------------------------- yeni kafalıklar
## Kedi kulaklı başlık (ref Kankuro_Part_II)
static func _neko(m, col: Color, L: Dictionary) -> void:
	m.hood(col, String(L.get("hood", "")))
	var hc: Vector3 = m._head_center()
	var top: float = m.head_top()
	var mb := MB.new()
	for s in [-1.0, 1.0]:
		var o := Vector3(s * 0.078, 0.012, -0.012)
		mb.add("cone", o, Vector3(0.082, 0.115, 0.05), col, Vector3(0, 0, -s * 13.0), 4)
		mb.add("cone", o + Vector3(s * 0.002, -0.012, 0.016), Vector3(0.05, 0.075, 0.024), col.lightened(0.14), Vector3(0, 0, -s * 13.0), 4)
	Kit._put(m, mb, Vector3(hc.x, top + 0.03, hc.z))


## Yüzü örten başlık (ref Kakuzu_NXB): dar başlık + burundan boyna bez
static func _fukumen(m, col: Color, L: Dictionary) -> void:
	m.hood(col, String(L.get("hood", "")))
	if L.get("face_style") == null:
		m.face_item("cloth", col.lightened(0.06))


## Koyu kep + kalın sargı (ref Tayuya_Shot)
static func _sarashi_bo(m, col: Color) -> void:
	var dark := Color(0.15, 0.15, 0.17)
	var yb: float = m.cloth_band(col, 0.0, 0.05, 0.0, 0.0, 0.004, 0.016)
	m.head_cap(dark, yb + 0.03, 0.06, 0.05, 0.02)
	m.cloth_band(col.darkened(0.14), 0.024, 0.024, 0.0, 0.0, -0.005, 0.03)
	var hc: Vector3 = m._head_center()
	var mb := MB.new()
	mb.add("cyl", Vector3(0, 0.0, 0), Vector3(0.05, 0.03, 0.05), dark.lightened(0.05), Vector3.ZERO, 12)
	mb.add("sphere", Vector3(0, 0.022, 0), Vector3(0.05, 0.04, 0.05), dark.lightened(0.1), Vector3.ZERO, 12)
	Kit._put(m, mb, Vector3(hc.x, m.head_top() + 0.018, hc.z))


## Kat kat baş ve yüz sargısı (ref Mu)
static func _sarashi_zukin(m, col: Color, L: Dictionary) -> void:
	var yb: float = m.cloth_band(col, -0.008, 0.042, 0.0, 0.0, 0.01, 0.018)
	m.head_cap(col.darkened(0.05), yb + 0.016, 0.09, 0.03)
	m.cloth_band(col.darkened(0.12), 0.026, 0.03, 0.0, 0.0, -0.018, 0.022)
	m.cloth_band(col.darkened(0.04), 0.052, 0.028, 0.0, 0.0, 0.022, 0.024)
	if L.get("face_style") == null:
		m.face_item("bandaj_alt", col)


## Kâğıt çiçek (ref Konan): katlı kâğıt yapraklar, başın yanında
static func _hana(m, col: Color) -> void:
	var hw := Kit._hw(m)
	var hc: Vector3 = m._head_center()
	var ab: AABB = m.head_ab
	var hh := clampf(ab.size.y, 0.12, 0.26) if ab.size.y > 0.05 else 0.2
	var mb := MB.new()
	var rings := [[7, 0.05, 0.0, 26.0, 0.0], [6, 0.035, 0.01, 40.0, 0.07], [4, 0.017, 0.02, 58.0, 0.14]]
	for r in rings:
		for k in int(r[0]):
			var a: float = TAU * k / float(r[0]) + float(r[4]) * 6.0
			var o := Vector3(cos(a) * float(r[1]), float(r[2]), sin(a) * float(r[1]))
			var b := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, deg_to_rad(float(r[3]))) * Basis.from_scale(Vector3(0.062, 0.016, 0.044))
			mb.add_xf("sphere", Transform3D(b, o), col.darkened(float(r[4]) + (0.05 if k % 2 == 0 else 0.0)), 8)
	mb.add("sphere", Vector3(0, 0.03, 0), Vector3(0.016, 0.012, 0.016), col.darkened(0.25), Vector3.ZERO, 8)
	var mi := Kit._put(m, mb, Vector3(hc.x + hw * 0.56, hc.y + hh * 0.3, hc.z + 0.015))
	mi.rotation = Vector3(0.15, 0, -1.2)


## Boynuzlu alın plakası (ref Jiraiya_full2): 油 yazılı metal, iki yanda boynuz, uzun bağ
static func _gama(m, col: Color) -> void:
	var yb: float = m.cloth_band(col, 0.0, 0.044, 0.24, 0.036, 0.004)
	var rr: PackedFloat32Array = m.band_ring[1]
	var rf: float = rr[int(floor((PI * 0.5 + PI) / TAU * rr.size())) % rr.size()]
	var st := Color(0.74, 0.76, 0.8)
	var mb := MB.new()
	mb.add("box", Vector3.ZERO, Vector3(0.1, 0.052, 0.01), st.darkened(0.25))
	mb.add("box", Vector3(0, 0, 0.005), Vector3(0.09, 0.043, 0.006), st)
	for s in [-1.0, 1.0]:
		mb.add("cone", Vector3(s * 0.062, 0.03, 0.0), Vector3(0.034, 0.08, 0.018), st.darkened(0.08), Vector3(0, 0, -s * 34.0), 6)
		for y in [-0.016, 0.016]:
			mb.add("sphere", Vector3(s * 0.04, y, 0.009), Vector3(0.006, 0.006, 0.004), st.darkened(0.4), Vector3.ZERO, 6)
	var mi := Kit._put(m, mb, Vector3(m.skull_c.x, yb, m.skull_c.z + rf + 0.014))
	var l := Label3D.new()
	l.text = "油"
	l.font = LazyFx.g("KageAttire")._font()
	l.font_size = 64
	l.pixel_size = 0.00062
	l.modulate = Color(0.1, 0.1, 0.12)
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = Vector3(0, 0, 0.0095)
	mi.add_child(l)
