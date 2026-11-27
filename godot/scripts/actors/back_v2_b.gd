extends RefCounted
## Sırt / bel eşyaları, grup b (sirt_009 .. sirt_032). Hedef: res://scripts/actors/back_v2_b.gd
## Kayış ve kemerler oyunun SurfaceKit'iyle kıyafet kabuğuna derilidir (bedenle bükülür). Eşyalar kemiğe takılı sert parça.
## Tüm konumlar model uzayında: +Z ön, sırt -Z, +X karakterin solu. Yerel eşya uzayı: +Y eşyanın üstü, +Z bedene doğru.
## Kaynaklar refs/<tür>/: Gama-chan, Fūma Shuriken, Tonfa, Explosive Tag, Toad Contract Scroll, Telescope Technique, Kimimaro kemik kılıcı, Kankurō / Karasu, Tayuya, Shakujō.

const KINDS := ["naginata", "yay_sadak", "kukla_bohca", "uc_parsomen", "yatay_parsomen", "kurbaga_cuzdan", "ikiz_matara", "ilac_kutusu",
	"hasir_rulo", "flut_kemer", "kemik_kilic", "savas_baltasi", "ninjato", "tetsubo", "shuriken_kesesi", "etiket_kemeri",
	"fener", "ahsap_kalkan", "ikiz_fuma", "shakujo", "nobori", "kristal_kure", "ikiz_tonfa", "tessen_bel"]

const WOOD := Color(0.45, 0.31, 0.18)
const WOOD_D := Color(0.27, 0.18, 0.11)
const WOOD_L := Color(0.62, 0.46, 0.28)
const LEATHER := Color(0.36, 0.23, 0.13)
const LEATHER_D := Color(0.22, 0.14, 0.09)
const ROPE := Color(0.72, 0.62, 0.43)
const PAPER := Color(0.93, 0.89, 0.77)
const BANDAGE := Color(0.86, 0.81, 0.68)
const STEEL := Color(0.73, 0.76, 0.8)
const STEEL_L := Color(0.9, 0.92, 0.95)
const IRON := Color(0.2, 0.21, 0.24)
const BRASS := Color(0.78, 0.6, 0.26)
const BONE := Color(0.93, 0.91, 0.84)
const BONE_D := Color(0.72, 0.68, 0.58)
const CRIMSON := Color(0.62, 0.13, 0.15)
const INK := Color(0.08, 0.07, 0.07)
const STRAW := Color(0.77, 0.67, 0.43)


static var _meshes := {}   # tür|cinsiyet|renk|giysi payı -> bitmiş ağlar; aynı eşyanın sonraki kurulumu yalnız düğüm ekler


static func build(m, kind: String, bc: Color, _ch: Vector3, _hip: Vector3, toon: Material) -> bool:
	if not kind in KINDS:
		return false
	var key = "%s|%s|%s|%.3f" % [kind, str(m.look.get("gender", "m")), bc.to_html(), _lift(m)]
	if not _meshes.has(key):
		_meshes[key] = _make(m, kind, bc, toon)
	var e: Dictionary = _meshes[key]
	if e["u"] != null:
		m._mesh_on("UpperChest", e["u"], Transform3D.IDENTITY)
	if e["h"] != null:
		m._mesh_on("Hips", e["h"], Transform3D.IDENTITY)
	for x in e["extra"]:
		m._mesh_on(x[0], x[1], x[2])
	if e["sk"] != null:   # kabuğa derili kayışlar: _sk_end ile aynı bağlama
		var mi = MeshInstance3D.new()
		mi.mesh = e["sk"]
		m.skel.add_child(mi)
		mi.skin = m.body_mesh.skin
		mi.skeleton = mi.get_path_to(m.skel)
		mi.material_override = LazyFx.g("Props").toon()
	for d in e["dg"]:   # sallanan şeritler: paket ortak, fizik durumu model başına
		var dn = Dangle.make(d[1], LazyFx.g("Props").toon())
		if dn != null:
			m._attach(d[0], Transform3D.IDENTITY).get_child(0).add_child(dn)
			m._dangles.append(dn)
	return true


static func _make(m, kind: String, bc: Color, toon: Material) -> Dictionary:
	var C = _ctx(m)
	var B = MB.new()   # UpperChest
	var H = MB.new()   # Hips
	match kind:
		"naginata": _naginata(m, C, B, bc)
		"yay_sadak": _yay_sadak(m, C, B, bc)
		"kukla_bohca": _kukla(m, C, B, bc)
		"uc_parsomen": _uc_parsomen(m, C, B, bc)
		"yatay_parsomen": _yatay_parsomen(m, C, B, bc)
		"kurbaga_cuzdan": _gama(m, C, H, bc)
		"ikiz_matara": _matara(m, C, H, bc)
		"ilac_kutusu": _ilac(m, C, B, bc)
		"hasir_rulo": _hasir(m, C, B, bc)
		"flut_kemer": _flut(m, C, H, bc)
		"kemik_kilic": _kemik(m, C, B, bc)
		"savas_baltasi": _balta(m, C, B, bc)
		"ninjato": _ninjato(m, C, B, bc)
		"tetsubo": _tetsubo(m, C, B, bc)
		"shuriken_kesesi": _keseler(m, C, H, bc)
		"etiket_kemeri": _etiket(m, C, H, bc)
		"fener": _fener(m, C, H, bc)
		"ahsap_kalkan": _kalkan(m, C, B, bc)
		"ikiz_fuma": _fuma(m, C, B, bc)
		"shakujo": _shakujo(m, C, B, bc)
		"nobori": _nobori(m, C, B, bc)
		"kristal_kure": _kure(m, C, B, bc)
		"ikiz_tonfa": _tonfa(m, C, H, bc)
		"tessen_bel": _tessen(m, C, H, bc)
	var sk = null
	if C["ok"]:
		var mi = m._sk_end({})
		if mi != null:
			sk = mi.mesh
			m.skel.remove_child(mi)
			mi.free()
	return {"u": null if B.is_empty() else B.build(toon), "h": null if H.is_empty() else H.build(toon), "sk": sk, "extra": C["extra"], "dg": C["dg"]}


## dangle_strip ile aynı şerit; paketi saklanır
static func _dg(C: Dictionary, bone: String, model_root: Vector3, dir: Vector3, length: float, width: float, col: Color, stiff := 0.2, side := Vector3.ZERO, thick := 0.004, _parent = null, taper := 0.35) -> void:
	var dn = dir.normalized()
	var sd = side.normalized() if side != Vector3.ZERO else dn.cross(Vector3.BACK if absf(dn.z) < 0.9 else Vector3.RIGHT).normalized()
	var nrm = dn.cross(sd).normalized()
	var n = 6
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts = PackedVector3Array()
	var ring = []
	for k in n + 1:
		var t = float(k) / n
		var c = model_root + dn * length * t
		pts.append(c)
		var w = width * (1.0 - taper * t) * 0.5
		ring.append([c - sd * w - nrm * thick, c + sd * w - nrm * thick, c + sd * w + nrm * thick, c - sd * w + nrm * thick])
	for k in n:
		var a = ring[k]
		var b = ring[k + 1]
		for q in 4:
			var q2 = (q + 1) % 4
			for vv in [a[q], b[q], b[q2], a[q], b[q2], a[q2]]:
				st.set_color(col)
				st.add_vertex(vv)
	st.generate_normals()
	var pack = Dangle.build(st.commit(), [{"pts": pts, "stiff": stiff + 0.06, "stiff_tip": stiff * 0.4, "damp": 0.82, "grav": 0.7, "drag": 1.2, "air": 0.3, "follow": 0.5, "col_r": 0.012, "col_from": 1}],
		func(_i, v, _si): return [[0, Dangle.project(pts, v)[0], 1.0]])
	C["dg"].append([bone, pack])


# ------------------------------------------------------------------ beden ölçüleri
static func _lift(m) -> float:
	return 0.045 if m.look.get("outer_style") != null else (0.035 if m.look.get("vest") != null else 0.008)


static func _ctx(m) -> Dictionary:
	var neck: float = m._bp("Neck").y
	var hips: float = m._bp("Hips").y
	var lift = _lift(m)
	var pad = lift + 0.02
	var zf = func(y: float) -> float:
		var z: float = m._back_z(y)
		return (z if z < -0.02 else -0.12) - pad
	var zu: float = zf.call(neck - 0.1)
	var ym = lerpf(neck, hips, 0.45)
	var zm: float = zf.call(ym)
	var zl: float = zf.call(hips + 0.08)
	var ok: bool = m._sk_begin(m._shell_cache.get(m.look.get("gender")))
	return {"neck": neck, "hips": hips, "lift": lift, "ok": ok, "zu": zu, "zm": zm, "zl": zl, "ym": ym, "zb": minf(zu, minf(zm, zl)), "belt": hips + 0.04, "slices": {}, "dg": [], "extra": []}


## Sırt yüzeyinin (kıyafet payı dahil) o yükseklikteki z'si
static func _zat(C: Dictionary, y: float) -> float:
	var y0 = float(C["neck"]) - 0.1
	var y2 = float(C["hips"]) + 0.08
	var ym = float(C["ym"])
	if y >= ym:
		return lerpf(C["zm"], C["zu"], clampf((y - ym) / maxf(y0 - ym, 0.01), 0.0, 1.0))
	return lerpf(C["zl"], C["zm"], clampf((y - y2) / maxf(ym - y2, 0.01), 0.0, 1.0))


## Kabuk kesitinde a açısındaki dış nokta (0 ön, +PI/2 karakterin solu, PI arka) -> [konum, yatay dış yön]
static func _ring_pt(m, C: Dictionary, y: float, a: float) -> Array:
	var dir = Vector3(sin(a), 0.0, cos(a))
	var key = int(round(y * 200.0))
	var S: Dictionary = C["slices"]
	if C["ok"] and not S.has(key):
		var pts = PackedVector3Array()
		var c = Vector3.ZERO
		for q in (m._sk["v"] as PackedVector3Array):
			if absf(q.y - y) < 0.014 and absf(q.x) < 0.27:
				pts.append(q)
				c += q
		S[key] = [pts, c / maxf(pts.size(), 1.0)]
	var r = 0.0
	var ctr = Vector3(0.0, y, -0.01)
	if S.has(key) and (S[key][0] as PackedVector3Array).size() > 8:
		ctr = S[key][1]
		ctr.y = y
		for q in (S[key][0] as PackedVector3Array):
			var d = Vector3(q.x - ctr.x, 0.0, q.z - ctr.z)
			var l = d.length()
			if l > r and d.dot(dir) > l * 0.975:
				r = l
	if r <= 0.0:
		r = Vector2(0.165 * sin(a), 0.125 * cos(a)).length()
	return [ctr + dir * (r + float(C["lift"]) * 0.5 + 0.006), dir]


## Bel çevresine oturan yerel düzen: +X yana, +Y yukarı, +Z dışarı
static func _hip_xf(m, C: Dictionary, a: float, out := 0.0, y := -99.0) -> Transform3D:
	var yy = float(C["belt"]) if y < -50.0 else y
	var r = _ring_pt(m, C, yy, a)
	var o: Vector3 = r[1]
	return Transform3D(Basis(Vector3.UP.cross(o).normalized(), Vector3.UP, o), (r[0] as Vector3) + o * out)


## Sırta yatık uzun eşya: lean derece, üst uç karakterin sağına (-X) yatar. Yerel +Y eşyanın ucu, +Z bedene doğru.
static func _long(C: Dictionary, cx: float, cy: float, lean: float, r: float) -> Transform3D:
	var a = deg_to_rad(lean)
	var y = Vector3(-sin(a), cos(a), 0.0)
	return Transform3D(Basis(y.cross(Vector3.BACK).normalized(), y, Vector3.BACK), Vector3(cx, cy, float(C["zb"]) - r))


static func _pack(C: Dictionary, y: float, depth: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, y, _zat(C, y) - depth * 0.5))


# ------------------------------------------------------------------ deriye oturan kayışlar
static func _sash(m, C: Dictionary, w: float, col: Color, flip := false) -> void:
	if not C["ok"]:
		return
	var s = -1.0 if flip else 1.0
	var a = Vector2(-0.11 * s, float(C["neck"]) - 0.02)
	var c = Vector2(0.15 * s, float(C["hips"]) + 0.02)
	for fr in [true, false]:
		m._sk_path(a, c, w, 0.006, col, fr, C["lift"], 14, 0.05)
		m._sk_path(a, c, w * 0.16, 0.003, col.lightened(0.28), fr, float(C["lift"]) + 0.006, 10, 0.05)


static func _belt(m, C: Dictionary, w: float, col: Color) -> void:
	if C["ok"]:
		m._sk_ring(1, C["belt"], w, 0.007, col, -PI, PI, 36, C["lift"])


static func _shoulders(m, C: Dictionary, w: float, col: Color) -> void:
	if not C["ok"]:
		return
	var n = float(C["neck"])
	var y = n - 0.34
	for sx in [-1.0, 1.0]:
		for fr in [true, false]:
			m._sk_path(Vector2(0.1 * sx, n - 0.025), Vector2(0.128 * sx, n - 0.29), w, 0.006, col, fr, C["lift"], 12, 0.05)
			m._sk_path(Vector2(0.128 * sx, n - 0.285), Vector2(0.165 * sx, y), w, 0.006, col, fr, C["lift"], 5, 0.05)
		var a0 = 0.95 if sx > 0.0 else -2.25
		m._sk_ring(1, y, w, 0.006, col, a0, a0 + 1.3, 9, C["lift"], 0.0, 0.0, 0.24)   # koltuk altından arkaya


# ------------------------------------------------------------------ geometri
## Süpürme: pts boyunca kesit. prof(t) -> Vector2(U yarıçapı, V yarıçapı); nrm V yönünün başlangıcı. col Color ya da Callable(t).
static func _sweep(b: MB, pts: Array, prof: Callable, col, nrm := Vector3.ZERO, n := 8, caps := true, ph := 0.0) -> void:
	var cnt = pts.size()
	if cnt < 2:
		return
	var base = b.verts.size()
	var V = nrm
	var first_t = Vector3.ZERO
	var last_t = Vector3.ZERO
	for i in cnt:
		var t = float(i) / (cnt - 1)
		var T: Vector3 = ((pts[mini(i + 1, cnt - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if i == 0:
			first_t = T
			if V == Vector3.ZERO:
				V = Vector3.UP if absf(T.y) < 0.9 else Vector3.BACK
		last_t = T
		V = (V - T * V.dot(T)).normalized()
		var U: Vector3 = V.cross(T).normalized()
		var r: Vector2 = prof.call(t)
		var c: Color = col.call(t) if col is Callable else col
		for j in n:
			var a = ph + TAU * j / n
			var ca = cos(a)
			var sa = sin(a)
			b.verts.append((pts[i] as Vector3) + U * ca * r.x + V * sa * r.y)
			b.normals.append((U * ca / maxf(r.x, 0.0006) + V * sa / maxf(r.y, 0.0006)).normalized())
			b.colors.append(c)
			b.uvs.append(Vector2.ZERO)
	for i in cnt - 1:
		for j in n:
			var j2 = (j + 1) % n
			var A = base + i * n + j
			var Bq = base + (i + 1) * n + j
			var Cq = base + (i + 1) * n + j2
			var D = base + i * n + j2
			b.idx.append_array([A, Bq, Cq, A, Cq, D])
	if not caps:
		return
	for e in 2:
		var ri = 0 if e == 0 else cnt - 1
		var nn: Vector3 = -first_t if e == 0 else last_t
		var cb = b.verts.size()
		b.verts.append(pts[ri])
		b.normals.append(nn)
		b.colors.append(b.colors[base + ri * n])
		b.uvs.append(Vector2.ZERO)
		for j in n:
			b.verts.append(b.verts[base + ri * n + j])
			b.normals.append(nn)
			b.colors.append(b.colors[base + ri * n + j])
			b.uvs.append(Vector2.ZERO)
		for j in n:
			var j2 = (j + 1) % n
			if e == 0:
				b.idx.append_array([cb, cb + 1 + j, cb + 1 + j2])
			else:
				b.idx.append_array([cb, cb + 1 + j2, cb + 1 + j])


static func _k(rx: float, ry := -1.0) -> Callable:
	var v = Vector2(rx, rx if ry < 0.0 else ry)
	return func(_t: float) -> Vector2: return v


static func _rod(b: MB, pts: Array, d: float, col, n := 6) -> void:
	_sweep(b, pts, _k(d * 0.5), col, Vector3.ZERO, n)


static func _seg(b: MB, a: Vector3, c: Vector3, d: float, col: Color, seg := 6) -> void:
	_sweep(b, [a, c], _k(d * 0.5), col, Vector3.ZERO, seg)


## Yassı kayış / şerit: nrm yüzey yönü, genişlik ona dik
static func _band(b: MB, pts: Array, w: float, t: float, col, nrm := Vector3.BACK) -> void:
	_sweep(b, pts, _k(w * 0.7071, t * 0.7071), col, nrm, 4, true, PI * 0.25)


## Eksen çevresinde kısa bilezik
static func _cuff(b: MB, c: Vector3, axis: Vector3, d: float, h: float, col: Color, seg := 10) -> void:
	var n = axis.normalized() * h * 0.5
	_seg(b, c - n, c + n, d, col, seg)


## Düzlem levha: outline (u, v), o merkez, kalınlık U x V yönünde
static func _plate(b: MB, outline: PackedVector2Array, t: float, col: Color, o := Vector3.ZERO, U := Vector3.RIGHT, V := Vector3.UP) -> void:
	b.add_slab(outline, t, col, Transform3D(Basis(U.cross(V), U, V), o))


static func _curve(a: Vector3, c: Vector3, ctrl: Vector3, n: int) -> Array:
	var out = []
	for i in n + 1:
		var t = float(i) / n
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(c, t), t))
	return out


static func _line(a: Vector3, c: Vector3, n: int) -> Array:
	var out = []
	for i in n + 1:
		out.append(a.lerp(c, float(i) / n))
	return out


static func _circle(c: Vector3, u: Vector3, v: Vector3, r: float, n: int, a0 := 0.0, a1 := TAU) -> Array:
	var out = []
	for i in n + 1:
		var a = lerpf(a0, a1, float(i) / n)
		out.append(c + u * cos(a) * r + v * sin(a) * r)
	return out


## Sarmal ip / sargı: axis boyunca turlar
static func _lashing(b: MB, c: Vector3, axis: Vector3, r: float, h: float, turns: int, d: float, col: Color) -> void:
	var y = axis.normalized()
	var u = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var v = y.cross(u)
	var pts = []
	var n = turns * 9
	for i in n + 1:
		var t = float(i) / n
		var a = t * TAU * turns
		pts.append(c + y * (t - 0.5) * h + (u * cos(a) + v * sin(a)) * r)
	_rod(b, pts, d, col, 4)


## Uzun eşyayı kayışa bağlayan bağ: gövdesini saran bilezik + düğüm + bedene giden deri dil
static func _tie(b: MB, C: Dictionary, xf: Transform3D, s: float, r: float, col: Color, lx := 0.0) -> void:
	var p: Vector3 = xf * Vector3(lx, s, 0.0)
	var ax: Vector3 = xf.basis.y
	_cuff(b, p, ax, r * 2.0 + 0.012, 0.028, col, 10)
	_cuff(b, p, ax, r * 2.0 + 0.018, 0.006, col.lightened(0.2), 10)
	b.add("sphere", p - Vector3.BACK * (r + 0.008), Vector3(0.022, 0.018, 0.014), col.darkened(0.15), Vector3.ZERO, 6)
	var q = Vector3(clampf(p.x, -0.15, 0.15), clampf(p.y, float(C["hips"]), float(C["neck"]) - 0.04), 0.0)
	q.z = _zat(C, q.y) + 0.006
	var a = p + Vector3.BACK * r * 0.8
	if a.z < q.z:
		_band(b, [a, q], 0.024, 0.006, col, Vector3.UP)
		b.add("sphere", q + Vector3.BACK * -0.004, Vector3(0.012, 0.012, 0.006), BRASS, Vector3.ZERO, 6)


## İki nokta arası bağlantı kayışı
static func _lash(b: MB, a: Vector3, c: Vector3, w: float, col: Color) -> void:
	_band(b, [a, c], w, 0.006, col, Vector3.BACK)


static func _strap_pt(C: Dictionary, sx: float) -> Vector3:
	var y = float(C["neck"]) - 0.27
	return Vector3(0.124 * sx, y, _zat(C, y) + 0.004)


## Kapaklı deri kese. Yerel: +Z dışarı, +Y yukarı, merkez kesenin ortası.
static func _pouch(t: MB, w: float, h: float, d: float, col: Color) -> void:
	var pr = func(u: float) -> Vector2:
		var k = sqrt(clampf(u * 5.0, 0.12, 1.0))
		return Vector2(w * 0.5 * k, d * 0.5 * k)
	_sweep(t, _line(Vector3(0, -h * 0.5, 0), Vector3(0, h * 0.5, 0), 6), pr, col, Vector3.BACK, 10)
	var out = PackedVector2Array()
	var fw = w * 0.54
	var top = h * 0.53
	var bot = -h * 0.08
	out.append(Vector2(-fw, top))
	for i in 9:
		var a = lerpf(PI, TAU, i / 8.0)
		out.append(Vector2(cos(a) * fw, bot + sin(a) * h * 0.12))
	out.append(Vector2(fw, top))
	var fl = col.darkened(0.14)
	_plate(t, out, 0.007, fl, Vector3(0, 0, d * 0.5 + 0.005))
	_sweep(t, [Vector3(-fw, top, d * 0.5 + 0.004), Vector3(fw, top, d * 0.5 + 0.004)], _k(0.008, 0.012), fl, Vector3.BACK, 6)
	t.add("sphere", Vector3(0, bot - h * 0.06, d * 0.5 + 0.012), Vector3(0.018, 0.018, 0.01), BRASS, Vector3.ZERO, 8)
	for i in 7:   # dikiş
		var a = lerpf(PI + 0.25, TAU - 0.25, i / 6.0)
		t.add("box", Vector3(cos(a) * fw * 0.86, bot + sin(a) * h * 0.1, d * 0.5 + 0.0095), Vector3(0.008, 0.0025, 0.0015), col.lightened(0.42), Vector3(0, 0, rad_to_deg(a) + 90.0))


# ------------------------------------------------------------------ 1 Naginata
static func _naginata(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.03, LEATHER)
	_belt(m, C, 0.026, LEATHER)
	var r = 0.021
	var xf = _long(C, -0.02, float(C["neck"]) - 0.3, 15.0, r)
	var t = MB.new()
	_sweep(t, [Vector3(0, -0.66, 0), Vector3(0, 0.56, 0)], _k(0.0155, 0.0195), bc, Vector3.BACK, 8)
	_sweep(t, _line(Vector3(0, -0.73, 0), Vector3(0, -0.645, 0), 3), func(u): return Vector2(0.009 + u * 0.0085, 0.011 + u * 0.0105), IRON, Vector3.BACK, 8)
	for i in 11:   # tutma yerinde çapraz ip
		_cuff(t, Vector3(0, -0.16 + i * 0.024, 0), Vector3(0.14 * (1 - 2 * (i % 2)), 1, 0), 0.041, 0.012, INK if i % 2 == 0 else CRIMSON, 8)
	_cuff(t, Vector3(0, 0.5, 0), Vector3.UP, 0.044, 0.016, BRASS)
	_cuff(t, Vector3(0, 0.535, 0), Vector3.UP, 0.04, 0.03, IRON)
	_sweep(t, [Vector3(0, 0.555, 0), Vector3(0, 0.561, 0)], _k(0.035, 0.03), BRASS, Vector3.BACK, 10)   # tsuba
	_cuff(t, Vector3(0, 0.574, 0), Vector3.UP, 0.03, 0.022, BRASS, 8)
	var pts = []
	for i in 15:
		var u = i / 14.0
		pts.append(Vector3(-0.008 - 0.12 * u * u, 0.566 + 0.47 * u, 0.0))
	var pr = func(u: float) -> Vector2: return Vector2(lerpf(0.02, 0.031, sin(minf(u * 1.25, 1.0) * PI * 0.5)) * pow(maxf(1.0 - pow(u, 5.0), 0.0), 0.7) + 0.0008, 0.0052 * (1.0 - u * 0.75) + 0.0006)
	_sweep(t, pts, pr, STEEL, Vector3.BACK, 6)
	var g = []
	for i in range(1, 11):
		var p: Vector3 = pts[i]
		g.append(p + Vector3(0.008, 0, -0.0048 * (1.0 - i / 14.0 * 0.7)))
	_rod(t, g, 0.004, Color(0.48, 0.51, 0.56), 4)
	B.add_mesh(t, xf)
	_tie(B, C, xf, 0.08, r, LEATHER_D)
	_tie(B, C, xf, float(C["belt"]) - xf.origin.y, r, LEATHER_D)
	_dg(C, "UpperChest", xf * Vector3(0, 0.49, -0.024), Vector3(-0.1, -1.0, -0.15), 0.19, 0.016, CRIMSON, 0.14)


# ------------------------------------------------------------------ 2 Yay ve sadak
static func _yay_sadak(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.03, LEATHER)
	_sash(m, C, 0.022, LEATHER_D, true)
	var n = float(C["neck"])
	var qx = _long(C, 0.02, n - 0.4, 17.0, 0.07)
	var t = MB.new()
	var qp = func(u: float) -> Vector2:
		var k = lerpf(0.72, 1.0, sqrt(u)) * (0.45 + 0.55 * sqrt(minf(u * 9.0, 1.0)))
		return Vector2(0.066 * k, 0.046 * k)
	_sweep(t, _line(Vector3(0, -0.31, 0), Vector3(0, 0.24, 0), 7), qp, bc, Vector3.BACK, 10)
	_sweep(t, [Vector3(0, 0.222, 0), Vector3(0, 0.255, 0)], _k(0.07, 0.05), LEATHER_D, Vector3.BACK, 10, false)
	_sweep(t, [Vector3(0, 0.226, 0), Vector3(0, 0.23, 0)], _k(0.062, 0.042), INK, Vector3.BACK, 10)
	_cuff(t, Vector3(0, 0.256, 0), Vector3.UP, 0.13, 0.006, BRASS, 12)
	for y in [-0.17, 0.08]:
		_sweep(t, [Vector3(0, y - 0.012, 0), Vector3(0, y + 0.012, 0)], func(_u): return Vector2(0.066 * (0.84 + (y + 0.31) * 0.3) + 0.003, 0.05), LEATHER_D, Vector3.BACK, 10)
	for i in 14:   # dikiş
		t.add("box", Vector3(0, -0.28 + i * 0.038, -0.05 + i * 0.0004), Vector3(0.012, 0.003, 0.002), bc.lightened(0.45))
	for i in 6:
		var a = i * 2.4
		var o = Vector3(cos(a) * (0.012 + i * 0.006), 0.22, sin(a) * (0.008 + i * 0.004))
		var top = o + Vector3(o.x * 0.25, 0.2 + (i % 3) * 0.016, o.z * 0.25)
		_seg(t, o, top, 0.0075, WOOD_L, 5)
		var ax = (top - o).normalized()
		for q in 3:
			var f = q * TAU / 3.0 + i
			var e = Vector3(cos(f), 0, sin(f))
			var c = top - ax * 0.055 + e * 0.012
			t.add_xf("box", Transform3D(Basis(e * 0.02, ax * 0.075, e.cross(ax) * 0.0018), c), PAPER if q != 0 else CRIMSON)
		t.add_xf("box", Transform3D(Basis(Vector3.RIGHT * 0.01, ax * 0.012, Vector3.BACK * 0.01), top), INK)
	B.add_mesh(t, qx)
	_tie(B, C, qx, 0.1, 0.05, LEATHER_D)
	_tie(B, C, qx, -0.17, 0.05, LEATHER_D)
	# yumi: kabza ortanın altında, kanonik asimetrik gerçek Japon yayı
	var bx = _long(C, 0.03, n - 0.26, -20.0, 0.14)
	var y0 = -0.55
	var y1 = 0.8
	var bow = []
	for i in 25:
		var u = i / 24.0
		var y = lerpf(y0, y1, u)
		var g = (y - 0.0) / (y1 if y > 0.0 else -y0)
		bow.append(Vector3(0.105 * (1.0 - g * g) + 0.03 * sin(g * PI) * g, y, 0.0))
	var bcol = func(u: float) -> Color:
		var y = lerpf(y0, y1, u)
		if absf(y) < 0.075:
			return LEATHER_D
		return ROPE if fmod(u * 24.0, 5.0) < 1.0 else WOOD_D
	var bm = _bow_mb(bow, bcol)
	_seg(bm, bow[0], bow[24], 0.0032, PAPER, 4)
	B.add_mesh(bm, bx)
	_tie(B, C, bx, 0.3, 0.012, LEATHER_D, 0.1)
	_tie(B, C, bx, -0.3, 0.012, LEATHER_D, 0.09)


static func _bow_mb(bow: Array, bcol: Callable) -> MB:
	var b = MB.new()
	_sweep(b, bow, func(u): return Vector2(0.0095, 0.0125) * (1.0 - absf(u - 0.42) * 0.55), bcol, Vector3.BACK, 6)
	for e in [0, 24]:
		b.add("sphere", bow[e], Vector3(0.016, 0.02, 0.016), BONE_D, Vector3.ZERO, 6)
	return b


# ------------------------------------------------------------------ 3 Kukla bohçası (Part I Kankurō: Karasu sargılı, krem kayışlarla sırtta)
static func _kukla(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.036, BANDAGE)
	var n = float(C["neck"])
	var cy = lerpf(n, float(C["hips"]), 0.46)
	var xf = Transform3D(Basis.IDENTITY, Vector3(0.0, cy, float(C["zb"]) - 0.092))
	var rad = func(u: float) -> Vector2:
		var k = 0.66 + 0.34 * sin(clampf(u * 1.2, 0.0, 1.0) * PI)
		var head = smoothstep(0.74, 0.84, u) * 0.3 * sin(clampf((u - 0.74) / 0.26, 0.0, 1.0) * PI)
		var pinch = 1.0 - smoothstep(0.64, 0.76, u) * 0.4
		var ends = sqrt(clampf(u * 11.0, 0.12, 1.0)) * sqrt(clampf((1.0 - u) * 11.0, 0.12, 1.0))
		var lump = 1.0 + 0.04 * sin(u * 19.0) + 0.025 * sin(u * 43.0)
		var r = (0.122 * k * pinch * lump + 0.1 * head) * ends
		return Vector2(r, r * 0.76)
	var ctr = func(u: float) -> Vector3: return Vector3(0.007 * sin(u * 8.0), lerpf(-0.42, 0.46, u), -0.05 * pow(maxf(u - 0.5, 0.0) * 2.0, 2.0))
	var pts = []
	for i in 21:
		pts.append(ctr.call(i / 20.0))
	var t = MB.new()
	_sweep(t, pts, rad, BANDAGE.darkened(0.26), Vector3.BACK, 12)
	# birbirini örten geniş sargı katları: tek ton, şerit değil
	var tones = [BANDAGE, BANDAGE.darkened(0.07), BANDAGE.lightened(0.05)]
	for w in 3:
		var s = []
		for i in 47:
			var u = lerpf(0.025, 0.975, i / 46.0)
			var a = w * TAU / 3.0 + u * TAU * 6.0
			var R: Vector2 = rad.call(u)
			s.append((ctr.call(u) as Vector3) + Vector3(cos(a) * R.x, 0.0, sin(a) * R.y) * 1.015)
		_sweep(t, s, _k(0.03, 0.0045), tones[w], Vector3(1, 0, 0), 4, true, PI * 0.25)
	# boyanabilir parça: bohçayı toplayan iki bağ ipi
	for u in [0.3, 0.7]:
		var R: Vector2 = rad.call(u)
		var c: Vector3 = ctr.call(u)
		var ring = []
		for i in 17:
			var a = i * TAU / 16.0
			ring.append(c + Vector3(cos(a) * (R.x + 0.006), 0.012 * sin(a * 2.0), sin(a) * (R.y + 0.006)))
		_rod(t, ring, 0.012, bc, 4)
	B.add_mesh(t, xf)
	for sx in [-1.0, 1.0]:
		var sp = _strap_pt(C, sx)
		_lash(B, sp, xf * Vector3(0.085 * sx, 0.17, 0.05), 0.034, BANDAGE)
		var ly = float(C["hips"]) + 0.12
		var low = Vector3(0.125 * sx, ly, _zat(C, ly) + 0.004)
		_lash(B, sp, low, 0.03, BANDAGE.darkened(0.06))
		_lash(B, low, xf * Vector3(0.09 * sx, -0.2, 0.045), 0.03, BANDAGE.darkened(0.06))
	_dg(C, "UpperChest", xf * Vector3(0.06, -0.33, -0.075), Vector3(0.08, -1.0, -0.1), 0.16, 0.026, BANDAGE, 0.2)


# ------------------------------------------------------------------ parşömen ortak
## Yatay eksenli parşömen, merkez yerel başlangıç, X boyunca
static func _scroll_x(t: MB, c: Vector3, L: float, r: float, body: Color, cap: Color, tie: Color) -> void:
	var a = c - Vector3.RIGHT * L * 0.5
	var e = c + Vector3.RIGHT * L * 0.5
	_sweep(t, [a, e], _k(r), body, Vector3.UP, 10)
	for sx in [-1.0, 1.0]:
		var o = c + Vector3.RIGHT * sx * L * 0.5
		_cuff(t, o - Vector3.RIGHT * sx * 0.02, Vector3.RIGHT, r * 2.0 + 0.006, 0.03, cap, 10)
		_cuff(t, o + Vector3.RIGHT * sx * 0.008, Vector3.RIGHT, r * 1.15, 0.014, INK, 8)
		_cuff(t, o + Vector3.RIGHT * sx * 0.022, Vector3.RIGHT, r * 1.5, 0.012, cap.darkened(0.25), 8)
	_cuff(t, c, Vector3.RIGHT, r * 2.0 + 0.005, 0.022, tie, 10)
	t.add("sphere", c + Vector3(0, 0, -r - 0.004), Vector3(0.022, 0.018, 0.012), tie.darkened(0.15), Vector3.ZERO, 6)


# ------------------------------------------------------------------ 4 Üçlü parşömen rafı: sırt çerçevesi
static func _uc_parsomen(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.03, LEATHER)
	var n = float(C["neck"])
	var cy = n - 0.31
	var xf = _pack(C, cy, 0.11)
	var t = MB.new()
	var W = 0.168
	var Ht = 0.25
	for sx in [-1.0, 1.0]:
		_sweep(t, _curve(Vector3(W * sx, -Ht - 0.05, 0.03), Vector3(W * sx, Ht + 0.05, 0.03), Vector3(W * sx * 1.05, 0, 0.0), 6), _k(0.013, 0.017), WOOD, Vector3.BACK, 6)
		t.add("sphere", Vector3(W * sx, Ht + 0.055, 0.03), Vector3.ONE * 0.034, WOOD_D, Vector3.ZERO, 6)
		t.add("sphere", Vector3(W * sx, -Ht - 0.055, 0.03), Vector3.ONE * 0.03, WOOD_D, Vector3.ZERO, 6)
	for y in [-Ht, Ht]:
		_sweep(t, [Vector3(-W - 0.012, y, 0.03), Vector3(W + 0.012, y, 0.03)], _k(0.012, 0.014), WOOD, Vector3.BACK, 6)
		for sx in [-1.0, 1.0]:
			_lashing(t, Vector3(W * sx, y, 0.03), Vector3(1, 1, 0) if sx * y > 0.0 else Vector3(1, -1, 0), 0.02, 0.03, 3, 0.005, ROPE)
	var cols = [bc, CRIMSON, Color(0.2, 0.36, 0.3)]
	for i in 3:
		var y = -0.15 + i * 0.15
		_scroll_x(t, Vector3(0, y, -0.012 - (i % 2) * 0.012), 0.285, 0.062, PAPER.darkened(0.03 * i), cols[i], cols[(i + 1) % 3].lightened(0.1))
		t.add("box", Vector3(0.07 - i * 0.06, y - 0.012, -0.074 - (i % 2) * 0.012), Vector3(0.03, 0.05, 0.002), PAPER.lightened(0.05), Vector3(14 - i * 8, 0, 0))
	# tutucu bağlar
	for sx in [-1.0, 1.0]:
		_sweep(t, _curve(Vector3(0.085 * sx, Ht, 0.02), Vector3(0.085 * sx, -Ht, 0.02), Vector3(0.085 * sx, 0, -0.12), 10), _k(0.012, 0.0035), LEATHER_D, Vector3(0, 0, -1), 4, true, PI * 0.25)
	B.add_mesh(t, xf)
	for sx in [-1.0, 1.0]:
		_lash(B, _strap_pt(C, sx), xf * Vector3(W * 0.95 * sx, 0.18, 0.03), 0.03, LEATHER)
		var ly = float(C["hips"]) + 0.2
		_lash(B, Vector3(0.15 * sx, ly, _zat(C, ly) + 0.004), xf * Vector3(W * 0.95 * sx, -Ht, 0.03), 0.024, LEATHER)


# ------------------------------------------------------------------ 5 Yatay çağırma parşömeni (Toad Contract: yeşil gövde, kızıl uç, siyah kapak)
static func _yatay_parsomen(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.022, ROPE)
	var y = float(C["hips"]) + 0.15
	var R = 0.072
	var xf = Transform3D(Basis.IDENTITY, Vector3(0, y, _zat(C, y) - R - 0.004))
	var t = MB.new()
	var L = 0.54
	var tx = L * 0.3
	_sweep(t, [Vector3(-L * 0.5, 0, 0), Vector3(L * 0.5, 0, 0)], _k(R), bc, Vector3.UP, 16)
	for sx in [-1.0, 1.0]:
		_cuff(t, Vector3(sx * (L * 0.5 - 0.04), 0, 0), Vector3.RIGHT, R * 2.0 + 0.007, 0.07, CRIMSON, 16)
		for q in [0.0, 0.07]:
			_cuff(t, Vector3(sx * (L * 0.5 - 0.005 - q), 0, 0), Vector3.RIGHT, R * 2.0 + 0.011, 0.007, BRASS, 16)
		_cuff(t, Vector3(sx * (L * 0.5 + 0.012), 0, 0), Vector3.RIGHT, R * 1.5, 0.024, INK, 12)
		_cuff(t, Vector3(sx * (L * 0.5 + 0.03), 0, 0), Vector3.RIGHT, R * 0.85, 0.016, Color(0.16, 0.15, 0.16), 10)
	# etiket: gövdeye kavisli beyaz şerit, üç düz mühür çizgisi, kızıl damga
	for i in 7:
		var a = lerpf(-0.42, 0.42, i / 6.0)
		var d = Vector3(0, sin(a), -cos(a))
		t.add_xf("box", Transform3D(Basis(Vector3.RIGHT * 0.11, d.cross(Vector3.RIGHT).normalized() * 0.014 * 1.0, d * 0.002), d * (R + 0.002)), PAPER)
	for q in [[0.0, 0.24, 0.078, 0.006, INK], [0.0, 0.0, 0.078, 0.006, INK], [0.0, -0.24, 0.078, 0.006, INK], [0.036, -0.37, 0.018, 0.014, CRIMSON]]:
		var a = float(q[1])
		var d = Vector3(0, sin(a), -cos(a))
		t.add_xf("box", Transform3D(Basis(Vector3.RIGHT * float(q[2]), d.cross(Vector3.RIGHT).normalized() * float(q[3]), d * 0.002), Vector3(float(q[0]), 0, 0) + d * (R + 0.004)), q[4])
	B.add_mesh(t, xf)
	for sx in [-1.0, 1.0]:
		var c: Vector3 = xf.origin + Vector3(tx * sx, 0, 0)
		_lashing(B, c, Vector3.RIGHT, R + 0.005, 0.03, 3, 0.011, ROPE)
		_rod(B, _curve(_strap_pt(C, sx), c + Vector3(0, R * 0.85, 0.02), c + Vector3(0.03 * sx, 0.18, 0.015), 6), 0.016, ROPE, 5)
	_dg(C, "UpperChest", xf * Vector3(tx, -R, -0.03), Vector3(0.05, -1.0, -0.12), 0.14, 0.012, ROPE, 0.2)


# ------------------------------------------------------------------ 6 Gama-chan (kanon: yeşil kurbağa cüzdan, metal ağız, iri göz)
static func _gama(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.022, LEATHER_D)
	var G = Color(0.27, 0.56, 0.3)
	var GD = Color(0.17, 0.41, 0.22)
	var GL = Color(0.52, 0.72, 0.42)
	var xf = _hip_xf(m, C, 2.68, 0.06, float(C["belt"]) - 0.13)
	var t = MB.new()
	t.add("sphere", Vector3(0, -0.012, 0), Vector3(0.158, 0.118, 0.11), G, Vector3.ZERO, 12)
	t.add("sphere", Vector3(0, -0.028, 0.03), Vector3(0.112, 0.07, 0.06), GL, Vector3.ZERO, 10)
	t.add("sphere", Vector3(0, 0.03, 0.012), Vector3(0.126, 0.07, 0.088), G, Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		t.add("sphere", Vector3(0.04 * sx, 0.066, 0.02), Vector3.ONE * 0.044, G, Vector3.ZERO, 8)
		t.add("sphere", Vector3(0.043 * sx, 0.07, 0.036), Vector3(0.027, 0.027, 0.016), Color(0.96, 0.93, 0.74), Vector3.ZERO, 8)
		t.add("sphere", Vector3(0.044 * sx, 0.07, 0.044), Vector3(0.016, 0.009, 0.006), INK, Vector3.ZERO, 6)
		t.add("sphere", Vector3(0.012 * sx, 0.044, 0.052), Vector3.ONE * 0.005, GD, Vector3.ZERO, 4)
		# bacak ve perdeli ayak
		_rod(t, _curve(Vector3(0.066 * sx, -0.036, 0.005), Vector3(0.078 * sx, -0.074, 0.03), Vector3(0.1 * sx, -0.05, 0.0), 4), 0.026, G, 6)
		for k in 3:
			var a = (k - 1) * 0.5
			t.add("sphere", Vector3((0.078 + sin(a) * 0.016) * sx, -0.077, 0.036 + cos(a) * 0.012), Vector3(0.012, 0.006, 0.024), GD, Vector3(0, rad_to_deg(a) * sx, 0), 5)
		_rod(t, _curve(Vector3(0.05 * sx, 0.005, 0.04), Vector3(0.045 * sx, -0.058, 0.055), Vector3(0.07 * sx, -0.03, 0.055), 3), 0.016, G, 5)
	# ağız: metal çerçeve + fermuar dişleri + iki bilyeli kilit (ref Gama-chan.png)
	var mouth = []
	for i in 11:
		var a = lerpf(-1.05, 1.05, i / 10.0)
		mouth.append(Vector3(sin(a) * 0.062, 0.012 - (1.0 - cos(a)) * 0.012, cos(a) * 0.05 + 0.006))
	_rod(t, mouth, 0.0075, STEEL, 5)
	var lower = []
	for p in mouth:
		lower.append((p as Vector3) + Vector3(0, -0.012, 0.001))
	_rod(t, lower, 0.0075, STEEL, 5)
	for i in range(1, 10):
		t.add("box", (mouth[i] as Vector3) + Vector3(0, -0.006, 0.003), Vector3(0.004, 0.009, 0.0035), PAPER)
	for sx in [-1.0, 1.0]:
		t.add("sphere", Vector3(0.008 * sx, 0.025, 0.056), Vector3.ONE * 0.011, STEEL_L, Vector3.ZERO, 6)
	H.add_mesh(t, xf)
	var top: Vector3 = xf * Vector3(0, 0.072, -0.01)
	var hook: Vector3 = (_ring_pt(m, C, C["belt"], 2.68)[0] as Vector3) + xf.basis.z * 0.006
	_rod(H, _curve(hook, top, hook + xf.basis.z * 0.04 + Vector3(0, -0.03, 0), 5), 0.0075, bc, 5)
	_cuff(H, hook, xf.basis.x, 0.024, 0.028, BRASS, 8)
	_dg(C, "Hips", hook + xf.basis.x * 0.012, Vector3(0.12, -1.0, -0.08), 0.1, 0.009, bc, 0.16)


# ------------------------------------------------------------------ 7 İkiz matara: deri kaplı metal kırba, belin iki arka yanı
static func _matara(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.028, LEATHER)
	for sx in [-1.0, 1.0]:
		var xf = _hip_xf(m, C, 2.62 * sx, 0.038, float(C["belt"]) - 0.1)
		var t = MB.new()
		var pr = func(u: float) -> Vector2:
			var k = sqrt(clampf(u * 7.0, 0.08, 1.0)) * (1.0 - pow(smoothstep(0.68, 1.0, u), 2.0) * 0.78)
			return Vector2(0.056 * k, 0.034 * k)
		_sweep(t, _line(Vector3(0, -0.095, 0), Vector3(0, 0.075, 0), 10), pr, bc, Vector3.BACK, 12)
		_cuff(t, Vector3(0, 0.086, 0), Vector3.UP, 0.03, 0.022, STEEL, 8)
		_cuff(t, Vector3(0, 0.098, 0), Vector3.UP, 0.036, 0.006, STEEL_L, 8)
		_sweep(t, _line(Vector3(0, 0.1, 0), Vector3(0, 0.13, 0), 2), func(u): return Vector2.ONE * lerpf(0.0125, 0.017, u), WOOD_L, Vector3.BACK, 8)
		_rod(t, _curve(Vector3(0, 0.126, 0.012), Vector3(0.028, 0.06, 0.03), Vector3(0.03, 0.12, 0.04), 5), 0.003, STEEL, 4)
		for y in [-0.05, 0.03]:
			_sweep(t, [Vector3(0, y - 0.008, 0), Vector3(0, y + 0.008, 0)], _k(0.0585, 0.0365), LEATHER_D, Vector3.BACK, 12)
		for i in 9:   # yan dikiş
			var y = -0.075 + i * 0.016
			t.add("box", Vector3(-0.0562 * sx, y, 0.0), Vector3(0.002, 0.006, 0.009), bc.lightened(0.42))
		H.add_mesh(t, xf)
		var hook: Vector3 = _ring_pt(m, C, C["belt"], 2.62 * sx)[0]
		for q in [-0.025, 0.025]:
			_band(H, [hook + xf.basis.x * q + xf.basis.z * 0.004, hook + xf.basis.x * q + xf.basis.z * 0.022 - Vector3(0, 0.03, 0), xf * Vector3(q, -0.018, 0.03)], 0.014, 0.004, LEATHER_D, xf.basis.z)


# ------------------------------------------------------------------ 8 İlaç kutusu: Japon gezgin hekim çekmeceli kusuribako
static func _ilac(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.03, LEATHER)
	var d = 0.15
	var xf = _pack(C, float(C["neck"]) - 0.3, d)
	var W = 0.135
	var Ht = 0.17
	var D = d * 0.5
	var t = MB.new()
	var fr = bc
	t.add("box", Vector3.ZERO, Vector3(W * 2.0 - 0.012, Ht * 2.0 - 0.012, d - 0.01), WOOD_D)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_sweep(t, [Vector3(W * sx, -Ht, D * sz), Vector3(W * sx, Ht, D * sz)], _k(0.011), fr, Vector3.BACK, 6)
		for sy in [-1.0, 1.0]:
			_sweep(t, [Vector3(W * sx, Ht * sy, -D), Vector3(W * sx, Ht * sy, D)], _k(0.011), fr, Vector3.UP, 6)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_sweep(t, [Vector3(-W, Ht * sy, D * sz), Vector3(W, Ht * sy, D * sz)], _k(0.011), fr, Vector3.UP, 6)
			for sx in [-1.0, 1.0]:   # köşe demiri
				t.add("sphere", Vector3(W * sx, Ht * sy, D * sz), Vector3.ONE * 0.03, BRASS, Vector3.ZERO, 6)
	# çekmeceler (arka yüz dışarıda): 2 geniş + 3x2 küçük
	var z = -D - 0.003
	var rows = [[0.114, 1], [0.0, 3], [-0.114, 3]]
	for rw in rows:
		var cnt = int(rw[1])
		var w = (W * 2.0 - 0.024) / cnt
		for i in cnt:
			var x = (i - (cnt - 1) * 0.5) * w
			t.add("box", Vector3(x, float(rw[0]), z), Vector3(w - 0.009, 0.103, 0.012), WOOD.lightened(0.06 * ((i + cnt) % 2)))
			t.add("box", Vector3(x, float(rw[0]), z - 0.0065), Vector3(w * 0.42, 0.012, 0.002), BRASS.darkened(0.2))
			t.add_xf("torus", Transform3D(Basis(Vector3.RIGHT * 0.028, Vector3.BACK * -0.02, Vector3.UP * 0.028), Vector3(x, float(rw[0]) - 0.016, z - 0.009)), BRASS, 10)
	# üst sıra: kâğıt etiket + ince yaprak işareti (şifa otu)
	t.add("box", Vector3(-0.07, 0.114, z - 0.007), Vector3(0.06, 0.074, 0.0015), PAPER)
	var leaf = PackedVector2Array()
	for i in 12:
		var a = i * TAU / 12.0
		leaf.append(Vector2(sin(a) * 0.016 * abs(cos(a * 0.5)), cos(a) * 0.03))
	_plate(t, leaf, 0.002, Color(0.25, 0.48, 0.28), Vector3(-0.07, 0.114, z - 0.009))
	t.add("box", Vector3(-0.07, 0.114, z - 0.0105), Vector3(0.0018, 0.05, 0.001), Color(0.15, 0.32, 0.18))
	# üstte taşıma kolu, çapraz bağ
	_sweep(t, _curve(Vector3(-0.08, Ht + 0.01, 0), Vector3(0.08, Ht + 0.01, 0), Vector3(0, Ht + 0.075, 0), 8), _k(0.009, 0.006), LEATHER_D, Vector3.BACK, 6)
	for sx in [-1.0, 1.0]:
		_band(t, _line(Vector3(0.118 * sx, Ht + 0.003, -D - 0.008), Vector3(0.118 * sx, -Ht - 0.003, -D - 0.008), 1), 0.018, 0.004, LEATHER_D, Vector3(0, 0, -1))
	B.add_mesh(t, xf)
	for sx in [-1.0, 1.0]:
		_lash(B, _strap_pt(C, sx), xf * Vector3(0.105 * sx, 0.11, D + 0.004), 0.03, LEATHER)
		var ly = float(C["hips"]) + 0.2
		_lash(B, Vector3(0.15 * sx, ly, _zat(C, ly) + 0.004), xf * Vector3(0.105 * sx, -Ht + 0.02, D + 0.004), 0.024, LEATHER)


# ------------------------------------------------------------------ 9 Hasır uyku rulosu (goza)
static func _hasir(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.018, ROPE)
	var y = float(C["hips"]) + 0.16
	var R = 0.068
	var xf = Transform3D(Basis.IDENTITY, Vector3(0, y, _zat(C, y) - R))
	var t = MB.new()
	var L = 0.5
	var s = func(u: float) -> Color:
		var k = int(u * 22.0)
		return STRAW.darkened(0.1) if k % 2 == 0 else STRAW.lightened(0.05)
	_sweep(t, _line(Vector3(-L * 0.5, 0, 0), Vector3(L * 0.5, 0, 0), 22), func(u): return Vector2.ONE * (R + 0.0022 * sin(u * 140.0)), s, Vector3.UP, 12, false)
	for sx in [-1.0, 1.0]:
		var x = sx * L * 0.5
		_cuff(t, Vector3(x - sx * 0.016, 0, 0), Vector3.RIGHT, R * 2.0 + 0.004, 0.03, bc, 12)   # kumaş kenar şeridi
		_sweep(t, [Vector3(x - sx * 0.004, 0, 0), Vector3(x + sx * 0.0015, 0, 0)], _k(R * 0.98), STRAW.darkened(0.32), Vector3.UP, 12)
		# uçta sarmal hasır katmanları
		var sp = []
		for i in 37:
			var u = i / 36.0
			var a = u * TAU * 3.0
			var r = lerpf(0.01, R * 0.92, u)
			sp.append(Vector3(x + sx * 0.0035, sin(a) * r, cos(a) * r))
		_rod(t, sp, 0.0048, STRAW.lightened(0.08), 4)
		for k in 4:   # kaçak saplar
			var a = k * 1.9 + sx
			var o = Vector3(x, sin(a) * R * 0.8, cos(a) * R * 0.8)
			_seg(t, o, o + Vector3(sx * (0.018 + k * 0.006), sin(a) * 0.008, cos(a) * 0.008), 0.0028, STRAW, 3)
	B.add_mesh(t, xf)
	for sx in [-1.0, 1.0]:
		var c: Vector3 = xf.origin + Vector3(0.14 * sx, 0, 0)
		_lashing(B, c, Vector3.RIGHT, R + 0.004, 0.022, 3, 0.009, ROPE)
		_rod(B, _curve(_strap_pt(C, sx), c + Vector3(0, R * 0.86, 0.02), c + Vector3(0.015 * sx, 0.14, 0.018), 6), 0.013, ROPE, 5)
	_dg(C, "UpperChest", xf * Vector3(-0.14, -R, -0.02), Vector3(-0.05, -1.0, -0.12), 0.12, 0.01, ROPE, 0.2)


# ------------------------------------------------------------------ 10 Belde flüt (Tayuya'nın yan flütü): kuşağa geçirilmiş
static func _flut(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.026, bc.darkened(0.15))
	var xf = _hip_xf(m, C, 2.86, 0.022)
	xf.basis = xf.basis * Basis(Vector3.BACK, deg_to_rad(-58.0))
	var t = MB.new()
	var M = Color(0.62, 0.65, 0.68)
	_sweep(t, [Vector3(0, -0.21, 0), Vector3(0, 0.22, 0)], func(_u): return Vector2.ONE * 0.0125, M, Vector3.BACK, 8)
	_cuff(t, Vector3(0, 0.226, 0), Vector3.UP, 0.029, 0.012, BRASS, 8)
	_cuff(t, Vector3(0, -0.215, 0), Vector3.UP, 0.029, 0.012, BRASS, 8)
	t.add("sphere", Vector3(0, 0.236, 0), Vector3.ONE * 0.02, BRASS, Vector3.ZERO, 6)
	for y in [-0.17, -0.06, 0.08, 0.17]:   # sargılar
		_cuff(t, Vector3(0, y, 0), Vector3.UP, 0.0275, 0.016, bc, 8)
		_cuff(t, Vector3(0, y, 0), Vector3.UP, 0.029, 0.003, BRASS, 8)
	t.add("sphere", Vector3(0, 0.145, 0.0118), Vector3(0.0075, 0.011, 0.002), INK, Vector3.ZERO, 6)   # üfleme deliği
	for i in 6:
		t.add("sphere", Vector3(0, -0.145 + i * 0.03 + (0.03 if i > 2 else 0.0), 0.0122), Vector3(0.0066, 0.0066, 0.0016), INK, Vector3.ZERO, 6)
	H.add_mesh(t, xf)
	for s in [-0.09, 0.11]:
		var p: Vector3 = xf * Vector3(0, s, 0)
		_cuff(H, p, xf.basis.y, 0.034, 0.018, LEATHER_D, 8)
		var q = Vector3(p.x, float(C["belt"]), p.z) - xf.basis.z * 0.016
		_band(H, [p - xf.basis.z * 0.01, q], 0.016, 0.004, LEATHER_D, xf.basis.z)
	_dg(C, "Hips", xf * Vector3(0, -0.22, 0.004), Vector3(0.1, -1.0, -0.06), 0.17, 0.014, CRIMSON, 0.14)


# ------------------------------------------------------------------ 11 Kemik kılıç (Kimimaro: Camellia.png, ince beyaz kemik)
static func _kemik(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.026, LEATHER_D)
	_belt(m, C, 0.022, LEATHER_D)
	var r = 0.03
	var xf = _long(C, -0.03, float(C["neck"]) - 0.28, 13.0, r)
	var t = MB.new()
	var pts = []
	for i in 19:
		var u = i / 18.0
		pts.append(Vector3(0.018 * sin(u * 3.0) - 0.03 * u * u, lerpf(-0.14, 0.82, u), 0.006 * sin(u * 9.0)))
	var pr = func(u: float) -> Vector2:
		var taper = pow(maxf(1.0 - u, 0.0), 0.72)
		var nodes = 1.0 + 0.11 * pow(maxf(sin(u * 23.0), 0.0), 3.0) * (1.0 - u)
		return Vector2(0.0185 * taper * nodes + 0.0007, 0.0145 * taper * nodes + 0.0007)
	var bcolor = func(u: float) -> Color: return BONE.lerp(BONE_D, 0.5 * pow(maxf(sin(u * 23.0), 0.0), 3.0) * (1.0 - u))
	_sweep(t, pts, pr, bcolor, Vector3.BACK, 7)
	# eklem başı (iki yumrulu kondil) ve mahmuzlar
	for sx in [-1.0, 1.0]:
		t.add("sphere", Vector3(0.017 * sx, -0.17, 0), Vector3(0.04, 0.046, 0.036), BONE, Vector3.ZERO, 8)
	t.add("sphere", Vector3(0, -0.2, 0), Vector3(0.036, 0.026, 0.03), BONE_D, Vector3.ZERO, 6)
	for i in 3:
		var y = -0.04 + i * 0.09
		var o = Vector3(-0.012, y + 0.12, 0)
		_sweep(t, _curve(o, o + Vector3(-0.055 + i * 0.008, 0.075, 0), o + Vector3(-0.045, 0.012, 0), 4), func(u): return Vector2(0.0085, 0.0065) * (1.0 - u) + Vector2(0.0006, 0.0006), BONE, Vector3.BACK, 5)
	# bezle sarılı kabza
	_sweep(t, [Vector3(0, -0.14, 0), Vector3(0, 0.06, 0)], _k(0.0235, 0.0195), bc.darkened(0.35), Vector3.BACK, 8)
	var w = []
	for i in 41:
		var u = i / 40.0
		var a = u * TAU * 10.0
		w.append(Vector3(cos(a) * 0.0238, lerpf(-0.135, 0.055, u), sin(a) * 0.0198))
	_rod(t, w, 0.0095, bc.darkened(0.18), 4)
	B.add_mesh(t, xf)
	_tie(B, C, xf, 0.06, 0.022, LEATHER_D)
	_tie(B, C, xf, float(C["belt"]) - xf.origin.y + 0.04, 0.03, LEATHER_D)
	_dg(C, "UpperChest", xf * Vector3(0.02, -0.12, -0.02), Vector3(0.12, -1.0, -0.1), 0.24, 0.026, bc, 0.14)


# ------------------------------------------------------------------ 12 Savaş baltası
static func _balta(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.03, LEATHER)
	_belt(m, C, 0.026, LEATHER)
	var r = 0.021
	var xf = _long(C, -0.075, float(C["neck"]) - 0.3, 17.0, r)
	var t = MB.new()
	var hp = []
	for i in 9:
		var u = i / 8.0
		hp.append(Vector3(0.012 * sin(u * PI * 1.0) * (1.0 - u), lerpf(-0.46, 0.62, u), 0))
	_sweep(t, hp, func(u): return Vector2(0.0165, 0.0195) * lerpf(1.0, 0.86, u) * (1.0 + 0.16 * smoothstep(0.05, 0.0, u)), WOOD, Vector3.BACK, 8)
	t.add("sphere", Vector3(0.012, -0.475, 0), Vector3(0.04, 0.03, 0.044), IRON, Vector3.ZERO, 8)
	for i in 10:   # sap sargısı
		_cuff(t, Vector3(0.006, -0.34 + i * 0.024, 0), Vector3(0.12 * (1 - 2 * (i % 2)), 1, 0), 0.043, 0.014, bc if i % 3 else bc.darkened(0.25), 8)
	# baş: sakallı ağız. Dış hat (u = -X yönünde ağız)
	var body = PackedVector2Array([Vector2(0.024, 0.44), Vector2(0.024, 0.62), Vector2(-0.024, 0.625), Vector2(-0.06, 0.645), Vector2(-0.12, 0.715), Vector2(-0.158, 0.735), Vector2(-0.205, 0.7), Vector2(-0.232, 0.62), Vector2(-0.236, 0.53), Vector2(-0.218, 0.44), Vector2(-0.178, 0.355), Vector2(-0.14, 0.33), Vector2(-0.122, 0.385), Vector2(-0.085, 0.455), Vector2(-0.04, 0.48), Vector2(-0.024, 0.48), Vector2(-0.018, 0.44)])
	_plate(t, body, 0.011, IRON, Vector3.ZERO)
	# bileylenmiş ağız şeridi
	var ed = PackedVector2Array([Vector2(-0.158, 0.735), Vector2(-0.205, 0.7), Vector2(-0.232, 0.62), Vector2(-0.236, 0.53), Vector2(-0.218, 0.44), Vector2(-0.178, 0.355), Vector2(-0.14, 0.33), Vector2(-0.15, 0.375), Vector2(-0.186, 0.45), Vector2(-0.202, 0.53), Vector2(-0.198, 0.615), Vector2(-0.175, 0.68), Vector2(-0.14, 0.712)])
	_plate(t, ed, 0.0135, STEEL_L, Vector3.ZERO)
	_plate(t, PackedVector2Array([Vector2(-0.024, 0.6), Vector2(-0.075, 0.625), Vector2(-0.14, 0.655), Vector2(-0.14, 0.42), Vector2(-0.08, 0.475), Vector2(-0.024, 0.5)]), 0.0125, Color(0.3, 0.31, 0.34), Vector3.ZERO)
	_sweep(t, [Vector3(0.008, 0.43, 0), Vector3(0.008, 0.635, 0)], _k(0.026, 0.024), IRON, Vector3.BACK, 8)
	for y in [0.45, 0.61]:
		_cuff(t, Vector3(0.008, y, 0), Vector3.UP, 0.058, 0.012, BRASS, 8)
	for q in [Vector2(-0.04, 0.6), Vector2(-0.04, 0.51)]:
		for sz in [-1.0, 1.0]:
			t.add("sphere", Vector3(q.x, q.y, 0.0075 * sz), Vector3.ONE * 0.012, BRASS, Vector3.ZERO, 5)
	# dil: arkadaki kısa çekiç
	_sweep(t, _line(Vector3(0.03, 0.53, 0), Vector3(0.085, 0.53, 0), 3), func(u): return Vector2(0.026, 0.016) * lerpf(1.0, 0.72, u), IRON, Vector3.BACK, 6)
	B.add_mesh(t, xf)
	_tie(B, C, xf, 0.08, r, LEATHER_D)
	_tie(B, C, xf, float(C["belt"]) - xf.origin.y, r, LEATHER_D)


# ------------------------------------------------------------------ 13 Dik ninjatō: kare tsuba, düz saya, sageo
static func _ninjato(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.028, INK.lightened(0.14))
	_belt(m, C, 0.024, INK.lightened(0.14))
	var r = 0.021
	var xf = _long(C, -0.15, float(C["neck"]) - 0.2, 9.0, r)
	var t = MB.new()
	_sweep(t, [Vector3(0, -0.55, 0), Vector3(0, 0.12, 0)], _k(0.0235, 0.0145), bc, Vector3.BACK, 8)
	_sweep(t, [Vector3(0, -0.575, 0), Vector3(0, -0.54, 0)], _k(0.0255, 0.0165), IRON, Vector3.BACK, 8)
	_cuff(t, Vector3(0, 0.1, 0), Vector3.UP, 0.05, 0.022, INK, 8)
	t.add("box", Vector3(0, 0.0, -0.016), Vector3(0.014, 0.03, 0.01), IRON)   # kurigata
	# kare tsuba, pahlı
	var octa = PackedVector2Array([Vector2(0.046, 0.034), Vector2(0.034, 0.046), Vector2(-0.034, 0.046), Vector2(-0.046, 0.034), Vector2(-0.046, -0.034), Vector2(-0.034, -0.046), Vector2(0.034, -0.046), Vector2(0.046, -0.034)])
	_plate(t, octa, 0.006, IRON, Vector3(0, 0.137, 0), Vector3.RIGHT, Vector3(0, 0, -1))
	_cuff(t, Vector3(0, 0.147, 0), Vector3.UP, 0.04, 0.012, BRASS, 8)
	# tsuka: mat ve baklava sargı
	_sweep(t, [Vector3(0, 0.15, 0), Vector3(0, 0.335, 0)], _k(0.0172, 0.0125), Color(0.82, 0.8, 0.72), Vector3.BACK, 8)
	for i in 8:
		var y = 0.165 + i * 0.022
		for sg in [-1.0, 1.0]:
			var a = Vector3(-0.0178 * sg, y - 0.009, 0)
			var c = Vector3(0.0178 * sg, y + 0.009, 0)
			for fz in [-1.0, 1.0]:
				_band(t, _curve(a, c, Vector3(0, y, 0.0162 * fz), 3), 0.0075, 0.002, INK, Vector3.BACK * fz)
	_cuff(t, Vector3(0, 0.34, 0), Vector3.UP, 0.037, 0.018, IRON, 8)
	B.add_mesh(t, xf)
	_tie(B, C, xf, -0.05, 0.024, INK.lightened(0.14))
	_tie(B, C, xf, float(C["belt"]) - xf.origin.y + 0.1, 0.024, INK.lightened(0.14))
	var sageo: Vector3 = xf * Vector3(0.02, 0.08, 0)
	_rod(B, _curve(sageo, xf * Vector3(0, -0.05, 0.024), xf * Vector3(0.05, 0.01, 0.0), 5), 0.008, CRIMSON, 4)
	_dg(C, "UpperChest", sageo + Vector3(0, -0.005, -0.008), Vector3(0.14, -1.0, -0.12), 0.26, 0.014, CRIMSON, 0.15)


# ------------------------------------------------------------------ 14 Tetsubō: sekiz yüzlü, çivili demir topuz
static func _tetsubo(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.034, LEATHER_D)
	_belt(m, C, 0.03, LEATHER_D)
	var r = 0.058
	var xf = _long(C, -0.095, float(C["neck"]) - 0.28, 17.0, r)
	var t = MB.new()
	var R = func(u: float) -> float: return lerpf(0.018, 0.056, smoothstep(0.18, 0.5, u)) * (1.0 - pow(smoothstep(0.93, 1.0, u), 2.0) * 0.45)
	_sweep(t, _line(Vector3(0, -0.56, 0), Vector3(0, 0.74, 0), 12), func(u): return Vector2.ONE * float(R.call(u)), func(u): return WOOD_D.lerp(IRON, smoothstep(0.26, 0.34, u)), Vector3.BACK, 8, true, PI / 8.0)
	t.add("sphere", Vector3(0, -0.575, 0), Vector3(0.05, 0.04, 0.05), IRON, Vector3.ZERO, 8)
	t.add_xf("torus", Transform3D(Basis(Vector3.RIGHT * 0.05, Vector3.BACK * -0.05, Vector3.UP * 0.05), Vector3(0, -0.615, 0)), STEEL, 10)
	for i in 12:   # kabza sargısı
		_cuff(t, Vector3(0, -0.5 + i * 0.024, 0), Vector3(0.1 * (1 - 2 * (i % 2)), 1, 0), 0.043, 0.015, bc if i % 2 else bc.darkened(0.2), 8)
	for u in [0.34, 0.97]:
		var y = lerpf(-0.56, 0.74, u)
		_cuff(t, Vector3(0, y, 0), Vector3.UP, float(R.call(u)) * 2.0 + 0.012, 0.022, STEEL.darkened(0.28), 8)
	# çiviler: yüz ortalarına, kat kat şaşırtmalı
	for row in 8:
		var u = lerpf(0.4, 0.92, row / 7.0)
		var y = lerpf(-0.56, 0.74, u)
		var rr = float(R.call(u)) * 0.95
		for j in 4:
			var a = (j + (row % 2) * 0.5) * TAU / 4.0 + PI / 8.0
			var d = Vector3(cos(a), 0, sin(a))
			if d.z > 0.75:
				continue
			var p = Vector3(0, y, 0) + d * rr
			var s = d.cross(Vector3.UP).normalized()
			t.add_xf("cone", Transform3D(Basis(s * 0.026, d * 0.034, Vector3.UP * 0.026), p + d * 0.015), STEEL.darkened(0.16), 4)
	B.add_mesh(t, xf)
	_tie(B, C, xf, 0.02, 0.04, LEATHER_D)
	_tie(B, C, xf, float(C["belt"]) - xf.origin.y, 0.022, LEATHER_D)


# ------------------------------------------------------------------ 15 Shuriken keseleri
static func _keseler(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.03, LEATHER)
	var sizes = [[0.094, 0.11, 0.05], [0.11, 0.122, 0.058], [0.094, 0.11, 0.05]]
	for i in 3:
		var a = PI + (i - 1) * 0.72
		var S: Array = sizes[i]
		var xf = _hip_xf(m, C, a, float(S[2]) * 0.5 + 0.006, float(C["belt"]) - 0.03)
		var t = MB.new()
		_pouch(t, S[0], S[1], S[2], bc if i != 1 else bc.darkened(0.12))
		if i == 1:   # kapak altından çıkan shuriken ucu
			for k in 2:
				var c = Vector3(-0.02 + k * 0.04, 0.076, 0.004)
				var q = PackedVector2Array()
				for j in 8:
					var an = j * TAU / 8.0 + k
					var rr = 0.034 if j % 2 == 0 else 0.009
					q.append(Vector2(cos(an), sin(an)) * rr)
				_plate(t, q, 0.0035, STEEL, c)
				t.add("sphere", c + Vector3(0, 0, 0.0028), Vector3.ONE * 0.008, INK, Vector3.ZERO, 5)
		H.add_mesh(t, xf)
		for sx in [-1.0, 1.0]:   # kemer köprüsü
			var p: Vector3 = xf * Vector3(sx * float(S[0]) * 0.28, float(S[1]) * 0.28, -float(S[2]) * 0.5)
			var q: Vector3 = xf * Vector3(sx * float(S[0]) * 0.28, float(S[1]) * 0.56, -float(S[2]) * 0.46)
			_band(H, [p, q], 0.016, 0.004, LEATHER_D, xf.basis.z)
	var tp: Vector3 = _ring_pt(m, C, C["belt"], PI + 0.72)[0]
	_dg(C, "Hips", tp + Vector3(0, -0.02, -0.03), Vector3(0.1, -1.0, -0.1), 0.1, 0.01, LEATHER_D, 0.2)


# ------------------------------------------------------------------ 16 Patlayıcı etiket kemeri (Explosive Tag: krem kâğıt, kızıl çerçeve, siyah yazı)
static func _etiket(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.036, bc.darkened(0.25))
	if C["ok"]:
		m._sk_ring(1, float(C["belt"]) + 0.016, 0.005, 0.003, bc.lightened(0.2), -PI, PI, 36, float(C["lift"]) + 0.006)
	var n = 9
	for i in n:
		var a = PI + lerpf(-1.75, 1.75, float(i) / (n - 1))
		var xf = _hip_xf(m, C, a, 0.008)
		xf.basis = xf.basis * Basis(Vector3.BACK, deg_to_rad(sin(i * 2.3) * 5.0))
		var t = MB.new()
		var w = 0.046
		var h = 0.118
		var cy = -0.05
		t.add("box", Vector3(0, cy, 0.0), Vector3(w + 0.007, h + 0.007, 0.0012), CRIMSON)
		t.add("box", Vector3(0, cy, 0.0009), Vector3(w, h, 0.0012), PAPER)
		for k in 6:   # düz, birbirini kesmeyen mühür çizgileri
			var y = cy + 0.04 - k * 0.016
			var sk = fmod(float(i * 7 + k * 3), 5.0) - 2.0
			t.add("box", Vector3(0.0012 * sk, y, 0.002), Vector3(0.03 - absf(sk) * 0.003, 0.0036, 0.0007), INK)
		t.add("box", Vector3(0, cy - 0.046, 0.002), Vector3(0.012, 0.009, 0.0007), CRIMSON)
		_band(t, [Vector3(-0.031, 0.009, 0.004), Vector3(0.031, 0.009, 0.004)], 0.013, 0.003, LEATHER_D, Vector3.BACK)   # tutucu
		for sx in [-1.0, 1.0]:
			t.add("sphere", Vector3(0.027 * sx, 0.009, 0.0065), Vector3.ONE * 0.006, BRASS, Vector3.ZERO, 4)
		H.add_mesh(t, xf)
	for a in [PI - 2.05, PI + 2.05]:
		var p: Vector3 = _ring_pt(m, C, C["belt"], a)[0]
		_dg(C, "Hips", p + Vector3(0, -0.012, 0), Vector3(0, -1.0, 0), 0.115, 0.046, PAPER, 0.3, Vector3(cos(a), 0.0, -sin(a)), 0.0015, null, 0.02)


# ------------------------------------------------------------------ 17 Bel feneri: katlanır chōchin
static func _fener(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.024, LEATHER_D)
	var xf = _hip_xf(m, C, 2.76, 0.075, float(C["belt"]) - 0.17)
	var t = MB.new()
	var pr = func(u: float) -> Vector2:
		var k = sqrt(maxf(1.0 - pow(u * 2.0 - 1.0, 2.0), 0.0)) * 0.72 + 0.28
		var rib = 1.0 + 0.022 * cos(u * 14.0 * TAU)
		return Vector2.ONE * 0.068 * k * rib
	var pc = func(u: float) -> Color:
		var g = Color(0.97, 0.84, 0.58).lerp(Color(0.92, 0.66, 0.36), absf(u - 0.5) * 1.6)
		return g.darkened(0.22) if int(u * 28.0 + 0.5) % 2 == 0 else g
	_sweep(t, _line(Vector3(0, -0.075, 0), Vector3(0, 0.075, 0), 28), pr, pc, Vector3.BACK, 10, false)
	for sy in [-1.0, 1.0]:
		_cuff(t, Vector3(0, 0.082 * sy, 0), Vector3.UP, 0.06, 0.018, bc.darkened(0.35), 10)
		_cuff(t, Vector3(0, 0.094 * sy, 0), Vector3.UP, 0.05, 0.008, bc, 10)
	# yanal yazı yerine kızıl mon
	var mon = []
	for i in 13:
		var a = i * TAU / 12.0
		mon.append(Vector3(sin(a) * 0.024, cos(a) * 0.024, 0.0))
	var mt = MB.new()
	_rod(mt, mon, 0.0065, CRIMSON, 4)
	mt.add("box", Vector3.ZERO, Vector3(0.0065, 0.03, 0.002), CRIMSON)
	mt.add("box", Vector3.ZERO, Vector3(0.024, 0.0065, 0.002), CRIMSON)
	t.add_mesh(mt, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0695)))
	# tel kulp ve kanca
	_rod(t, _curve(Vector3(-0.025, 0.098, 0), Vector3(0.025, 0.098, 0), Vector3(0, 0.16, 0), 6), 0.0042, IRON, 4)
	H.add_mesh(t, xf)
	var top: Vector3 = xf * Vector3(0, 0.128, 0)
	var hook: Vector3 = _ring_pt(m, C, C["belt"], 2.76)[0]
	_rod(H, _curve(hook + Vector3(0, 0.012, 0), top, hook + xf.basis.z * 0.1 + Vector3(0, -0.02, 0), 6), 0.0058, IRON, 4)
	_cuff(H, hook, xf.basis.x, 0.022, 0.026, LEATHER_D, 8)
	_dg(C, "Hips", xf * Vector3(0, -0.104, 0), Vector3(0, -1.0, -0.05), 0.09, 0.012, CRIMSON, 0.14)


# ------------------------------------------------------------------ 18 Ahşap kalkan: kalaslar, demir çember, umbo
static func _kalkan(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.028, LEATHER)
	_sash(m, C, 0.028, LEATHER, true)
	var R = 0.24
	var y = float(C["neck"]) - 0.33
	var xf = Transform3D(Basis.IDENTITY, Vector3(0, y, _zat(C, y) - 0.052))
	xf.basis = Basis(Vector3.RIGHT, deg_to_rad(-5.0))
	var t = MB.new()
	var pl = 5
	var pw = 2.0 * R / pl
	for i in pl:
		var x0 = -R + i * pw + 0.0014
		var x1 = -R + (i + 1) * pw - 0.0014
		var top = []
		for q in 6:
			var x = lerpf(x0, x1, q / 5.0)
			top.append(Vector2(x, sqrt(maxf(R * R - x * x, 0.0))))
		var o = PackedVector2Array()
		for p in top:
			o.append(p)
		top.reverse()
		for p in top:
			o.append(Vector2(p.x, -p.y))
		_plate(t, o, 0.018, [WOOD, WOOD_L.darkened(0.14), WOOD.darkened(0.08)][i % 3])
	var fr = _circle(Vector3.ZERO, Vector3.RIGHT, Vector3.UP, R, 32)
	_sweep(t, fr, _k(0.013, 0.015), IRON, Vector3.BACK, 6, false)
	_sweep(t, _circle(Vector3(0, 0, -0.0105), Vector3.RIGHT, Vector3.UP, R * 0.68, 28), _k(0.026, 0.0028), bc, Vector3.BACK, 4, false, PI * 0.25)   # boyalı halka
	_sweep(t, _circle(Vector3(0, 0, -0.0108), Vector3.RIGHT, Vector3.UP, R * 0.3, 20), _k(0.012, 0.0026), bc.lightened(0.18), Vector3.BACK, 4, false, PI * 0.25)
	t.add("sphere", Vector3(0, 0, -0.012), Vector3(0.112, 0.112, 0.062), IRON, Vector3.ZERO, 12)
	t.add("sphere", Vector3(0, 0, -0.04), Vector3.ONE * 0.022, STEEL, Vector3.ZERO, 6)
	_cuff(t, Vector3(0, 0, -0.012), Vector3.BACK, 0.13, 0.004, STEEL.darkened(0.3), 14)
	for i in 12:
		var a = i * TAU / 12.0
		t.add("sphere", Vector3(cos(a) * (R - 0.013), sin(a) * (R - 0.013), -0.015), Vector3(0.015, 0.015, 0.008), STEEL.darkened(0.15), Vector3.ZERO, 5)
	for i in 6:
		var a = i * TAU / 6.0 + 0.5
		t.add("sphere", Vector3(cos(a) * 0.075, sin(a) * 0.075, -0.0108), Vector3(0.011, 0.011, 0.005), BRASS, Vector3.ZERO, 5)
	# arkada iki taşıyıcı çıta (kayışa bağlanır)
	for sy in [-1.0, 1.0]:
		_sweep(t, [Vector3(-0.15, 0.09 * sy, 0.02), Vector3(0.15, 0.09 * sy, 0.02)], _k(0.018, 0.01), WOOD_D, Vector3.BACK, 6)
	B.add_mesh(t, xf)
	for sx in [-1.0, 1.0]:
		_lash(B, _strap_pt(C, sx), xf * Vector3(0.14 * sx, 0.09, 0.026), 0.026, LEATHER)
		var ly = float(C["hips"]) + 0.18
		_lash(B, Vector3(0.14 * sx, ly, _zat(C, ly) + 0.004), xf * Vector3(0.14 * sx, -0.09, 0.026), 0.026, LEATHER)


# ------------------------------------------------------------------ 19 İkiz Fūma: kavisli dört kanat, ortada kavrama halkası (ref Fūma_Shuriken.png)
static func _fuma_one(t: MB, R: float, ph: float, wrap: Color) -> void:
	for k in 4:
		var f = ph + k * TAU / 4.0
		var outer = PackedVector2Array()
		var inner = PackedVector2Array()
		var edge = PackedVector2Array()
		for i in 11:
			var u = i / 10.0
			var r = lerpf(0.034, R, u)
			var a = f + 0.62 * pow(u, 1.5)
			var w = 0.62 * pow(1.0 - u, 0.8) * (0.34 + 0.66 * sin(minf(u * 3.2, 1.0) * PI * 0.5)) + 0.004
			outer.append(Vector2(cos(a), sin(a)) * r)
			inner.append(Vector2(cos(a - w), sin(a - w)) * r)
			edge.append(Vector2(cos(a - w * 0.3), sin(a - w * 0.3)) * r)
		var o = PackedVector2Array(outer)
		var e = PackedVector2Array(outer)
		for i in range(10, -1, -1):
			o.append(inner[i])
			e.append(edge[i])
		_plate(t, o, 0.007, STEEL.darkened(0.12))
		_plate(t, e, 0.0088, STEEL_L)
	_cuff(t, Vector3.ZERO, Vector3.BACK, 0.09, 0.016, IRON, 12)
	_sweep(t, _circle(Vector3.ZERO, Vector3.RIGHT, Vector3.UP, 0.045, 11), _k(0.008, 0.012), wrap, Vector3.BACK, 5, false)
	_cuff(t, Vector3.ZERO, Vector3.BACK, 0.026, 0.024, BRASS, 8)


static func _fuma(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.03, LEATHER_D)
	_sash(m, C, 0.03, LEATHER_D, true)
	var n = float(C["neck"])
	var lay = [[Vector3(-0.09, n - 0.18, 0.0), 0.225, 0.3, 0.034], [Vector3(0.085, n - 0.39, 0.0), 0.255, 1.1, 0.02]]
	for L in lay:
		var c: Vector3 = L[0]
		c.z = _zat(C, c.y) - float(L[3])
		var t = MB.new()
		_fuma_one(t, L[1], L[2], bc)
		B.add_mesh(t, Transform3D(Basis.IDENTITY, c))
		var q = Vector3(clampf(c.x, -0.1, 0.1), c.y, _zat(C, c.y) + 0.005)
		_seg(B, c, q, 0.018, BRASS, 8)   # kayıştan çıkan tıpa
		_cuff(B, q + Vector3(0, 0, -0.004), Vector3.BACK, 0.06, 0.006, LEATHER_D, 10)
		_cuff(B, c + Vector3(0, 0, -0.016), Vector3.BACK, 0.032, 0.008, IRON, 8)   # kilit somunu


# ------------------------------------------------------------------ 20 Shakujō: oyundaki asanın başı (gerçek hat, çift loblu halka başı)
static func _shakujo(m, C: Dictionary, B: MB, bc: Color) -> void:
	_sash(m, C, 0.026, bc.darkened(0.2))
	_belt(m, C, 0.022, bc.darkened(0.2))
	var r = 0.02
	var xf = _long(C, -0.03, float(C["neck"]) - 0.3, 14.0, r)
	var S = Color(0.23, 0.26, 0.2)
	var G = Color(0.86, 0.66, 0.2)
	var D = Color(0.6, 0.42, 0.12)
	var t = MB.new()
	_sweep(t, [Vector3(0, -0.66, 0), Vector3(0, 0.66, 0)], _k(0.0155), S, Vector3.BACK, 8)
	_sweep(t, _line(Vector3(0, -0.76, 0), Vector3(0, -0.655, 0), 2), func(u): return Vector2.ONE * lerpf(0.004, 0.02, u), G, Vector3.BACK, 6)
	_cuff(t, Vector3(0, -0.645, 0), Vector3.UP, 0.04, 0.03, G, 8)
	for i in 8:
		_cuff(t, Vector3(0, -0.1 + i * 0.024, 0), Vector3(0.12 * (1 - 2 * (i % 2)), 1, 0), 0.037, 0.013, bc, 8)
	_cuff(t, Vector3(0, 0.665, 0), Vector3.UP, 0.04, 0.012, D, 8)
	_cuff(t, Vector3(0, 0.695, 0), Vector3.UP, 0.044, 0.05, G, 8)
	_cuff(t, Vector3(0, 0.728, 0), Vector3.UP, 0.058, 0.016, G, 10)
	var head = 0.735
	var P = [Vector2(0.0, 0.0), Vector2(0.04, 0.006), Vector2(0.078, 0.04), Vector2(0.093, 0.09), Vector2(0.08, 0.138), Vector2(0.046, 0.16), Vector2(0.016, 0.15), Vector2(0.0, 0.13)]
	var sm = []
	for k in P.size() - 1:
		var pa: Vector2 = P[maxi(k - 1, 0)]
		var pb: Vector2 = P[mini(k + 2, P.size() - 1)]
		for j in 3:
			sm.append((P[k] as Vector2).cubic_interpolate(P[k + 1], pa, pb, j / 3.0))
	sm.append(P[P.size() - 1])
	for sx in [-1.0, 1.0]:
		var loop = []
		for q in sm:
			loop.append(Vector3((q as Vector2).x * sx, head + (q as Vector2).y, 0))
		_rod(t, loop, 0.012, G, 5)
	_seg(t, Vector3(0, head, 0), Vector3(0, head + 0.13, 0), 0.008, D, 5)
	t.add("sphere", Vector3(0, head + 0.065, 0), Vector3(0.022, 0.042, 0.008), G, Vector3.ZERO, 6)
	_sweep(t, _line(Vector3(0, head + 0.128, 0), Vector3(0, head + 0.24, 0), 3), func(u): return Vector2(0.024, 0.005) * (1.0 - u) + Vector2(0.0006, 0.0006), G, Vector3.BACK, 4)
	# altı halka: iki omuz pimine asılı, yerçekimiyle aşağı
	for sx in [-1.0, 1.0]:
		var pv = Vector3(0.066 * sx, head + 0.03, 0)
		for k in 3:
			var c = pv + Vector3(sx * (0.006 + k * 0.014), -0.038, 0.004 * (k - 1))
			t.add_xf("torus", Transform3D(Basis(Vector3.RIGHT.rotated(Vector3.BACK, 0.14 * sx * (k - 1)) * 0.062, Vector3.BACK * -0.05, Vector3.UP.rotated(Vector3.BACK, 0.14 * sx * (k - 1)) * 0.08), c), G, 10)
	B.add_mesh(t, xf)
	_tie(B, C, xf, 0.06, r, bc.darkened(0.2))
	_tie(B, C, xf, float(C["belt"]) - xf.origin.y, r, bc.darkened(0.2))
	_dg(C, "UpperChest", xf * Vector3(0, 0.0, -0.02), Vector3(0.1, -1.0, -0.12), 0.2, 0.024, bc, 0.14)


# ------------------------------------------------------------------ 21 Nobori: sırt sancağı (sashimono düzeni), gerçek sallanan kumaş
static func _nobori(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.03, LEATHER)
	_belt(m, C, 0.03, LEATHER)
	var n = float(C["neck"])
	var h = float(C["hips"])
	var x = -0.075
	var zb = float(C["zb"]) - 0.035
	var y0 = h + 0.03
	var y1 = n + 0.52
	_seg(B, Vector3(x, y0, zb), Vector3(x, y1, zb), 0.022, WOOD_D, 8)
	_cuff(B, Vector3(x, y1 + 0.006, zb), Vector3.UP, 0.028, 0.014, BRASS, 8)
	B.add("cone", Vector3(x, y1 + 0.05, zb), Vector3(0.026, 0.075, 0.026), BRASS, Vector3.ZERO, 6)
	for i in 6:   # boğumlar
		_cuff(B, Vector3(x, lerpf(n - 0.12, y1 - 0.08, i / 5.0), zb), Vector3.UP, 0.0255, 0.008, WOOD, 8)
	# kol ve kumaş halkaları
	var arm = -0.3
	_seg(B, Vector3(x, y1 - 0.03, zb), Vector3(x + arm, y1 - 0.03, zb), 0.014, WOOD_D, 6)
	B.add("sphere", Vector3(x + arm, y1 - 0.03, zb), Vector3.ONE * 0.02, BRASS, Vector3.ZERO, 6)
	_lashing(B, Vector3(x, y1 - 0.03, zb), Vector3(1, 1, 0), 0.015, 0.03, 3, 0.004, ROPE)
	for i in 3:
		B.add_xf("torus", Transform3D(Basis(Vector3.RIGHT * 0.032, Vector3.UP * 0.008, Vector3.BACK * 0.032), Vector3(x - 0.06 - i * 0.095, y1 - 0.03, zb)), BRASS, 8)
	var cx = x + arm * 0.5 - 0.0
	var top = y1 - 0.045
	var side = Vector3.RIGHT
	_dg(C, "UpperChest", Vector3(cx, top, zb), Vector3(0, -1.0, -0.015), 0.4, 0.2, bc, 0.42, side, 0.003, null, 0.0)
	_dg(C, "UpperChest", Vector3(cx, top - 0.09, zb - 0.0035), Vector3(0, -1.0, -0.015), 0.2, 0.044, PAPER, 0.42, side, 0.0028, null, 0.0)
	_dg(C, "UpperChest", Vector3(cx, top, zb - 0.0015), Vector3(0, -1.0, -0.015), 0.065, 0.2, bc.darkened(0.28), 0.5, side, 0.0028, null, 0.0)
	# taşıyıcı: üst köprü + alt yuva (uke-zutsu)
	var yu = n - 0.27
	_band(B, [Vector3(-0.124, yu, _zat(C, yu) + 0.004), Vector3(x, yu, zb + 0.013), Vector3(0.124, yu, _zat(C, yu) + 0.004)], 0.03, 0.006, LEATHER, Vector3.UP)
	_cuff(B, Vector3(x, yu, zb), Vector3.UP, 0.04, 0.036, LEATHER_D, 8)
	_cuff(B, Vector3(x, y0 + 0.05, zb), Vector3.UP, 0.04, 0.11, WOOD, 8)
	_cuff(B, Vector3(x, y0 - 0.006, zb), Vector3.UP, 0.044, 0.014, IRON, 8)
	_lash(B, Vector3(x, y0 + 0.05, zb + 0.016), Vector3(x, y0 + 0.05, _zat(C, y0 + 0.05) + 0.004), 0.028, LEATHER)


# ------------------------------------------------------------------ 22 Kristal küre kutusu: kafesli taşıyıcı (Telescope Technique: mor minder üstünde küre)
static func _kure(m, C: Dictionary, B: MB, bc: Color) -> void:
	_shoulders(m, C, 0.03, LEATHER)
	var d = 0.2
	var y = float(C["neck"]) - 0.3
	var xf = _pack(C, y, d)
	var W = 0.112
	var Ht = 0.13
	var D = d * 0.5
	var t = MB.new()
	var fr = bc
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_sweep(t, [Vector3(W * sx, -Ht, D * sz), Vector3(W * sx, Ht, D * sz)], _k(0.012), fr, Vector3.BACK, 6)
			for sy in [-1.0, 1.0]:
				t.add("sphere", Vector3(W * sx, Ht * sy, D * sz), Vector3.ONE * 0.033, BRASS, Vector3.ZERO, 6)
		for sy in [-1.0, 1.0]:
			_sweep(t, [Vector3(W * sx, Ht * sy, -D), Vector3(W * sx, Ht * sy, D)], _k(0.011), fr, Vector3.UP, 6)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_sweep(t, [Vector3(-W, Ht * sy, D * sz), Vector3(W, Ht * sy, D * sz)], _k(0.011), fr, Vector3.UP, 6)
	# taban, tepe kapağı
	t.add("box", Vector3(0, -Ht, 0), Vector3(W * 2.0, 0.014, d), WOOD_D)
	var roof = PackedVector2Array([Vector2(-W - 0.03, 0), Vector2(W + 0.03, 0), Vector2(W - 0.03, 0.04), Vector2(-W + 0.03, 0.04)])
	_plate(t, roof, d + 0.05, WOOD_D, Vector3(0, Ht + 0.006, 0), Vector3.RIGHT, Vector3.UP)
	# _plate kalınlığı Z yönündedir: çatı kesiti
	t.add("sphere", Vector3(0, Ht + 0.056, 0), Vector3(0.042, 0.03, 0.042), BRASS, Vector3.ZERO, 8)
	# ince kafes çıtaları: dış yüz ve yanlar (küre görünür kalır)
	for i in 2:
		var x = (i - 0.5) * 0.11
		_seg(t, Vector3(x, -Ht, -D), Vector3(x, Ht, -D), 0.0075, WOOD, 4)
	for sx in [-1.0, 1.0]:
		_seg(t, Vector3(W * sx, -0.03, -D), Vector3(W * sx, -0.03, D), 0.0075, WOOD, 4)
		_seg(t, Vector3(W * sx, -Ht, 0.0), Vector3(W * sx, Ht, 0.0), 0.0075, WOOD, 4)
	_seg(t, Vector3(-W, -0.06, -D), Vector3(W, -0.06, -D), 0.0075, WOOD, 4)
	# mor minder, dört köşe püskül
	var P = Color(0.44, 0.15, 0.42)
	t.add("sphere", Vector3(0, -Ht + 0.032, 0), Vector3(0.18, 0.052, 0.155), P, Vector3.ZERO, 12)
	t.add("sphere", Vector3(0, -Ht + 0.046, 0), Vector3(0.1, 0.03, 0.09), P.darkened(0.2), Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c = Vector3(0.08 * sx, -Ht + 0.024, 0.066 * sz)
			t.add("cone", c + Vector3(0, -0.012, 0), Vector3(0.016, 0.026, 0.016), BRASS, Vector3(180, 0, 0), 5)
	B.add_mesh(t, xf)
	# küre: yarı saydam cam, içinde soluk girdap
	var g = StandardMaterial3D.new()
	g.albedo_color = Color(0.62, 0.82, 1.0, 0.52)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.roughness = 0.06
	g.metallic_specular = 0.9
	g.rim_enabled = true
	g.rim = 0.7
	g.rim_tint = 0.3
	var gb = MB.new()
	var bc0 = Vector3(0, -Ht + 0.125, 0)
	gb.add("sphere", bc0, Vector3.ONE * 0.155, Color.WHITE, Vector3.ZERO, 20)
	C["extra"].append(["UpperChest", gb.build(g), xf])
	var core = MB.new()
	var sw = []
	for i in 19:
		var u = i / 18.0
		var a = u * TAU * 1.6
		sw.append(bc0 + Vector3(cos(a) * 0.04 * (1.0 - u * 0.5), lerpf(-0.03, 0.04, u), sin(a) * 0.04 * (1.0 - u * 0.5)))
	_rod(core, sw, 0.006, Color(0.55, 0.78, 0.95), 4)
	core.add("sphere", bc0 + Vector3(-0.03, 0.04, -0.048), Vector3(0.024, 0.016, 0.005), Color(0.97, 0.99, 1.0), Vector3(0, 0, 30), 6)
	B.add_mesh(core, xf)
	for sx in [-1.0, 1.0]:
		_lash(B, _strap_pt(C, sx), xf * Vector3(0.095 * sx, 0.09, D + 0.004), 0.03, LEATHER)
		var ly = float(C["hips"]) + 0.2
		_lash(B, Vector3(0.15 * sx, ly, _zat(C, ly) + 0.004), xf * Vector3(0.095 * sx, -Ht + 0.02, D + 0.004), 0.024, LEATHER)


# ------------------------------------------------------------------ 23 İkiz tonfa (ref Tonfa.png: koyu çelik çubuk, dik kabza), bel arkasında çapraz
static func _tonfa(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.034, LEATHER)
	var base = _hip_xf(m, C, PI, 0.03, float(C["belt"]) - 0.02)
	var T = Color(0.17, 0.18, 0.21)
	for k in 2:
		var s = 1.0 - 2.0 * k
		var t = MB.new()
		_sweep(t, [Vector3(0, -0.16, 0), Vector3(0, 0.27, 0)], _k(0.0145), T, Vector3.BACK, 8)
		for e in [-0.163, 0.273]:
			t.add("sphere", Vector3(0, e, 0), Vector3(0.03, 0.016, 0.03), STEEL.darkened(0.35), Vector3.ZERO, 8)
		_cuff(t, Vector3(0, -0.08, 0), Vector3.UP, 0.033, 0.008, STEEL.darkened(0.35), 8)
		_cuff(t, Vector3(0, -0.015, 0), Vector3.UP, 0.033, 0.008, STEEL.darkened(0.35), 8)
		# dik kabza dışarı bakar
		_sweep(t, [Vector3(0, -0.048, 0.01), Vector3(0, -0.048, 0.112)], _k(0.0118), T, Vector3.UP, 7)
		t.add("sphere", Vector3(0, -0.048, 0.116), Vector3.ONE * 0.03, STEEL.darkened(0.3), Vector3.ZERO, 8)
		var w = []
		for i in 25:
			var u = i / 24.0
			var a = u * TAU * 6.0
			w.append(Vector3(cos(a) * 0.0128, -0.048 + sin(a) * 0.0128, lerpf(0.026, 0.1, u)))
		_rod(t, w, 0.0065, bc, 4)
		var xf = base
		xf.basis = base.basis * Basis(Vector3.BACK, deg_to_rad(s * 52.0))
		xf.origin += base.basis.z * (0.006 + k * 0.03)
		H.add_mesh(t, xf)
		for q in [0.17, -0.11]:   # deri kılıf halkaları: kemere iner
			var p: Vector3 = xf * Vector3(0, q, 0)
			_cuff(H, p, xf.basis.y, 0.038, 0.022, LEATHER_D, 8)
			_cuff(H, p, xf.basis.y, 0.041, 0.004, BRASS, 8)
			var bp = p - base.basis.z * 0.024
			bp.y = lerpf(bp.y, float(C["belt"]), 0.75)
			_band(H, [p - base.basis.z * 0.012, bp], 0.018, 0.004, LEATHER_D, base.basis.z)


# ------------------------------------------------------------------ 24 Belde demir yelpaze (tessen): hafif aralık kaburgalar, perçin, püskül
static func _tessen(m, C: Dictionary, H: MB, bc: Color) -> void:
	_belt(m, C, 0.028, bc.darkened(0.3))
	var xf = _hip_xf(m, C, 2.88, 0.02, float(C["belt"]) - 0.05)
	xf.basis = xf.basis * Basis(Vector3.BACK, deg_to_rad(-22.0))
	var t = MB.new()
	var L = 0.31
	var N = 9
	for k in N:
		var u = float(k) / (N - 1)
		var a = deg_to_rad(lerpf(-8.0, 8.0, u))
		var outer = k == 0 or k == N - 1
		var o = PackedVector2Array()
		var w0 = 0.0085 if outer else 0.006
		var w1 = 0.0175 if outer else 0.0165
		for q in [Vector2(-w0, -0.012), Vector2(w0, -0.012), Vector2(w1, L * 0.96), Vector2(w1 * 0.55, L), Vector2(-w1 * 0.55, L), Vector2(-w1, L * 0.96)]:
			o.append((q as Vector2).rotated(a))
		var c = IRON if outer else (bc if k % 2 == 0 else bc.lightened(0.16))
		_plate(t, o, 0.0034 if outer else 0.0022, c, Vector3(0, 0, (u - 0.5) * 0.034))
		if not outer:
			var tip = Vector2(0, L - 0.002).rotated(a)
			t.add("sphere", Vector3(tip.x, tip.y, (u - 0.5) * 0.034), Vector3(0.009, 0.005, 0.003), BRASS, Vector3.ZERO, 4)
	for sg in [0, 1]:   # dış kaburgada oyma ve perçinler
		var a = deg_to_rad(-8.0 if sg == 0 else 8.0)
		var z = (-0.5 if sg == 0 else 0.5) * 0.034 + (-0.0022 if sg == 0 else 0.0022)
		for i in 4:
			var p = Vector2(0, 0.075 + i * 0.058).rotated(a)
			t.add("sphere", Vector3(p.x, p.y, z), Vector3(0.0075, 0.0075, 0.002), STEEL, Vector3.ZERO, 5)
	_cuff(t, Vector3.ZERO, Vector3.BACK, 0.021, 0.046, BRASS, 8)
	_cuff(t, Vector3(0, 0, 0.0), Vector3.BACK, 0.03, 0.006, IRON, 8)
	_sweep(t, _circle(Vector3(0, -0.026, 0), Vector3.RIGHT, Vector3.UP, 0.0135, 12), _k(0.0024), BRASS, Vector3.BACK, 4, false)
	H.add_mesh(t, xf)
	var lp: Vector3 = xf * Vector3(0, 0.13, 0)
	_cuff(H, lp, xf.basis.y, 0.06, 0.022, LEATHER_D, 6)   # kemerden inen kın halkası
	var lq = Vector3(lp.x, float(C["belt"]), lp.z) - xf.basis.z * 0.014
	_band(H, [lp - xf.basis.z * 0.018, lq], 0.018, 0.004, LEATHER_D, xf.basis.z)
	_dg(C, "Hips", xf * Vector3(0, -0.04, 0), Vector3(0.1, -1.0, -0.06), 0.15, 0.016, CRIMSON, 0.14)
