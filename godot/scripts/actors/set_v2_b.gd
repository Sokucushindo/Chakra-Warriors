extends RefCounted
## Hazır setler, grup b (q2 + q3 sayfaları, 60 set). Hedef: res://scripts/actors/set_v2_b.gd
## Her ayrıntı, bulunduğu noktada en dışta kalan kumaş katmanına (beden kabuğu / yelek / giysi kabuğu) SurfaceKit ile derilir:
## boyama yok, kemiğe sabit kutu yok; kumaşla birlikte bükülür. Bitmiş ağlar set + cinsiyet başına bir kez kurulur.
## +X karakterin solu, +Z ön. N boyun, H kalça, K diz, A ayak bileği yüksekliği.

const SETS := ["ss_kaplumbaga", "ss_kara_palto", "ss_karga_cubbe", "ss_karga_tunik", "ss_kaya_paltosu", "ss_kaya_striker",
	"ss_kaya_striker_kurtarici", "ss_kaya_striker_postaci", "ss_kedi", "ss_kedi_alev", "ss_kimono_etek", "ss_kiri_genin",
	"ss_kizil_elbise", "ss_kizil_fermuar", "ss_kizil_kayis", "ss_kizil_palto", "ss_kizil_palto2", "ss_kizil_takim",
	"ss_kizil_zirh", "ss_kod", "ss_kok_reisi", "ss_konoha_genin", "ss_kopuk", "ss_kukla", "ss_kukla_genc", "ss_kum_cocuk",
	"ss_kum_striker", "ss_kum_striker_balon", "ss_kum_striker_kabile", "ss_kumarbaz", "ss_kumo_genin", "ss_kurbaga",
	"ss_kurbaga_bilge", "ss_kurbaga_bilge2", "ss_kurucu_genc", "ss_kurucu_palto", "ss_kutlama", "ss_kuyruklu_beyaz",
	"ss_lav_zirh", "ss_lavanta_ceket", "ss_maske_pelerin", "ss_maskeli_gaiden", "ss_maskeli_genc", "ss_maskeli_jonin",
	"ss_metal_canavar", "ss_mevsim", "ss_mikoshi", "ss_mor_etek", "ss_mor_genc", "ss_mor_genin", "ss_mor_kemer", "ss_mor_uzun",
	"ss_murekkep", "ss_murekkep_ceket", "ss_naginata", "ss_ninja_yolu_tisort", "ss_okul_mor", "ss_on_kuyruk", "ss_onluk",
	"ss_orman_zirh"]

const CELL := 0.04
const LEATHER := Color(0.36, 0.23, 0.13)
const LEATHER_D := Color(0.2, 0.13, 0.08)
const STEEL := Color(0.72, 0.74, 0.78)
const BRASS := Color(0.78, 0.6, 0.26)
const WHITE := Color(0.94, 0.93, 0.9)
const BLACK := Color(0.09, 0.09, 0.11)
const WRAP := Color(0.88, 0.86, 0.8)

static var _meshes := {}   # set|cinsiyet -> {"sk": [ağ], "dg": [[kemik, paket]]}
static var _grids := {}    # kabuk ağı -> ızgara (hücre -> en ön z, en arka z)


static func build(m, sid: String, g: Dictionary) -> void:
	var key = "%s|%s" % [sid, str(m.look.get("gender", "m"))]
	if not _meshes.has(key):
		_meshes[key] = _make(m, sid, g)
	var e: Dictionary = _meshes[key]
	for mesh in e["sk"]:
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		m.skel.add_child(mi)
		mi.skin = m.body_mesh.skin
		mi.skeleton = mi.get_path_to(m.skel)
		mi.material_override = Props.toon()
	for d in e["dg"]:
		var dn = Dangle.make(d[1], Props.toon())
		if dn != null:
			m._attach(d[0], Transform3D.IDENTITY).get_child(0).add_child(dn)
			m._dangles.append(dn)


# ------------------------------------------------------------------ kurulum
static func _make(m, sid: String, g: Dictionary) -> Dictionary:
	var gender = m.look.get("gender")
	var cands: Array = []
	var body = m._shell_cache.get(gender)
	if body != null:
		cands.append(body)
	if m.look.get("vest") != null and m._shell_cache.get(str(gender) + "|vest") != null:
		cands.append(m._shell_cache.get(str(gender) + "|vest"))
	for lm in m._layer_meshes:
		if lm != null and not lm in cands:
			cands.append(lm)
	var ua: Vector3 = m._bp("LeftUpperArm")
	var ha: Vector3 = m._bp("LeftHand")
	var s = {"m": m, "c": cands, "ops": [], "dg": [], "N": m._bp("Neck").y, "H": m._bp("Hips").y, "K": m._bp("LeftLowerLeg").y,
		"A": m._bp("LeftFoot").y, "ua": ua, "ha": ha, "lx": absf(m._bp("LeftUpperLeg").x)}
	for c in cands:
		_grid(m, c)
	_spec(s, sid)
	var groups := {}
	for op in s["ops"]:
		var i = _pick(s, op["px"], op["py"], op["fr"])
		if i >= 0:
			if not groups.has(i):
				groups[i] = []
			groups[i].append(op)
	var out = []
	for i in groups:
		if not m._sk_begin(cands[i]):
			continue
		for op in groups[i]:
			_run(m, op)
		var mi = m._sk_end(g)
		if mi != null:
			out.append(mi.mesh)
			m.skel.remove_child(mi)
			mi.free()
	return {"sk": out, "dg": s["dg"]}


static func _grid(m, mesh) -> Dictionary:
	var id = mesh.get_instance_id()
	if _grids.has(id) and _grids[id][0] == mesh:
		return _grids[id][1]
	var G := {}
	if m._sk_begin(mesh):
		for q in (m._sk["v"] as PackedVector3Array):
			var k = _cell(floori(q.x / CELL), floori(q.y / CELL))
			if G.has(k):
				var v: Vector2 = G[k]
				G[k] = Vector2(maxf(v.x, q.z), minf(v.y, q.z))
			else:
				G[k] = Vector2(q.z, q.z)
		m._sk = {}
	if _grids.size() > 64:
		_grids.clear()
	_grids[id] = [mesh, G]
	return G


static func _cell(ix: int, iy: int) -> int:
	return (ix + 500) * 4000 + iy + 500


## O noktadaki dış yüzey derinliği (ön: büyük z, arka: küçük z'nin eksisi); yoksa -99
static func _score(G: Dictionary, x: float, y: float, fr: bool) -> float:
	var ix = floori(x / CELL)
	var iy = floori(y / CELL)
	var best = -99.0
	for a in range(-1, 2):
		for b in range(-1, 2):
			var k = _cell(ix + a, iy + b)
			if G.has(k):
				var v: Vector2 = G[k]
				best = maxf(best, v.x if fr else -v.y)
	return best


static func _pick(s: Dictionary, x: float, y: float, fr: bool) -> int:
	var best = -1
	var bs = -98.0
	var m = s["m"]
	var C: Array = s["c"]
	for i in C.size():
		var v = _score(_grid(m, C[i]), x, y, fr)
		if v >= bs:   # eşitlikte sonraki (dış) katman
			bs = v
			best = i
	return best


## Yüzeyin z'si (sarkan parça kökü için)
static func _zs(s: Dictionary, x: float, y: float, fr: bool) -> float:
	var i = _pick(s, x, y, fr)
	if i < 0:
		return 0.12 if fr else -0.12
	var v = _score(_grid(s["m"], s["c"][i]), x, y, fr)
	return v if fr else -v


static func _run(m, o: Dictionary) -> void:
	var a: Array = o["a"]
	match o["k"]:
		"path":
			var p0: Vector2 = a[0]
			var p1: Vector2 = a[1]
			m._sk_path(p0, p1, a[2], a[5], a[3], a[4], a[6], clampi(int(p0.distance_to(p1) / 0.022), 3, 26), 0.05)
		"ring":
			m._sk_ring(1, a[0], a[1], a[2], a[3], a[4], a[5], 36, a[6], 0.0, 0.0, a[7])
		"leg":
			m._sk_ring(1, a[0], a[1], a[2], a[3], -PI, PI, 24, 0.004, a[4])
		"cuff":
			m._sk_ring(0, a[0], a[1], a[2], a[3], -PI, PI, 20, 0.004, a[4])
		"box", "disc":
			var h: Array = m._sk_hit(a[0], a[1], a[6], 0.045)
			if h.is_empty():
				return
			var n: Vector3 = (h[1] as Vector3).normalized()
			if absf(n.y) > 0.8:
				n = Vector3.BACK if a[6] else Vector3.FORWARD
			var p = Vector3(a[0], a[1], (h[0] as Vector3).z)
			if o["k"] == "disc":
				m._sk_disc(p + n * a[7], n, a[2], a[4], a[5])
			else:
				var u: Vector3 = Vector3.UP.cross(n).normalized()
				var v: Vector3 = n.cross(u).normalized()
				m._sk_box(p + n * (a[7] + a[4] * 0.5), u * a[2] * 0.5, v * a[3] * 0.5, n * a[4] * 0.5, a[5])
		"pocket":
			m._sk_pocket(a[0], a[1], a[2], a[3], a[4], a[5])
		"panel":
			m._sk_panel(a[0], a[1], a[2], a[3], a[4], a[5], a[6])


# ------------------------------------------------------------------ ayrıntı sözcükleri
static func _op(s: Dictionary, k: String, px: float, py: float, fr: bool, a: Array) -> void:
	s["ops"].append({"k": k, "px": px, "py": py, "fr": fr, "a": a})


static func _path(s: Dictionary, x0: float, y0: float, x1: float, y1: float, w: float, col: Color, fr := true, d := 0.005, lift := 0.004) -> void:
	_op(s, "path", (x0 + x1) * 0.5, (y0 + y1) * 0.5, fr, [Vector2(x0, y0), Vector2(x1, y1), w, col, fr, d, lift])


## Önde ve arkada aynı hat (omuzdan geçen kayış)
static func _strap(s: Dictionary, x0: float, y0: float, x1: float, y1: float, w: float, col: Color) -> void:
	_path(s, x0, y0, x1, y1, w, col, true)
	_path(s, x0, y0, x1, y1, w, col, false)
	_path(s, x0, y0, x1, y1, w * 0.14, col.lightened(0.3), true, 0.003, 0.009)


static func _ring(s: Dictionary, y: float, h: float, col: Color, d := 0.007, a0 := -PI, a1 := PI, lift := 0.004, max_r := 9.0) -> void:
	_op(s, "ring", 0.0, y, false, [y, h, d, col, a0, a1, lift, max_r])


static func _belt(s: Dictionary, y: float, h: float, col: Color, buckle = null, bw := 0.05) -> void:
	_ring(s, y, h, col)
	_ring(s, y + h * 0.5 - 0.002, 0.003, col.lightened(0.24), 0.004, -PI, PI, 0.0095)
	_ring(s, y - h * 0.5 + 0.002, 0.003, col.lightened(0.24), 0.004, -PI, PI, 0.0095)
	if buckle != null:
		_box(s, 0.0, y, bw, h * 1.25, 0.007, buckle, true, 0.011)
		_box(s, 0.0, y, bw * 0.55, h * 0.6, 0.003, (buckle as Color).darkened(0.35), true, 0.018)


static func _leg(s: Dictionary, y: float, h: float, col: Color, d := 0.007) -> void:
	for sx in [-1.0, 1.0]:
		_op(s, "leg", sx * float(s["lx"]), y, true, [y, h, d, col, sx])


## f: omuzdan bileğe oran
static func _cuff(s: Dictionary, f: float, h: float, col: Color, d := 0.007, only := 0.0) -> void:
	var a: Vector3 = s["ua"]
	var c: Vector3 = s["ha"]
	var x = lerpf(absf(a.x), absf(c.x), f)
	var y = lerpf(a.y, c.y, f)
	for sx in [-1.0, 1.0]:
		if only == 0.0 or only == sx:
			_op(s, "cuff", x * sx, y, true, [x * sx, h, d, col, sx])


static func _box(s: Dictionary, x: float, y: float, w: float, h: float, d: float, col: Color, fr := true, lift := 0.003) -> void:
	_op(s, "box", x, y, fr, [x, y, w, h, d, col, fr, lift])


static func _btn(s: Dictionary, x: float, y: float, r: float, col: Color, fr := true, lift := 0.004) -> void:
	_op(s, "disc", x, y, fr, [x, y, r, 0.0, 0.004, col, fr, lift])


static func _zip(s: Dictionary, x: float, y0: float, y1: float, col := STEEL) -> void:
	_path(s, x, y0, x, y1, 0.008, col, true, 0.003)
	_box(s, x, y0 - 0.012, 0.01, 0.022, 0.004, col.lightened(0.2), true, 0.007)


## Kapaklı kese: gövde, kapak, düğme
static func _kese(s: Dictionary, x: float, y: float, w: float, h: float, col: Color, fr := true) -> void:
	_box(s, x, y, w, h, 0.02, col, fr, 0.003)
	_box(s, x, y + h * 0.24, w * 1.08, h * 0.52, 0.005, col.darkened(0.18), fr, 0.023)
	_btn(s, x, y + h * 0.04, 0.008, BRASS, fr, 0.028)


## Sarkan kumaş / ip ucu
static func _tail(s: Dictionary, x: float, y: float, dx: float, ln: float, w: float, col: Color, fr := true, stiff := 0.18, bone := "Hips") -> void:
	var z = _zs(s, x, y, fr) + (0.012 if fr else -0.012)
	_dg(s, bone, Vector3(x, y, z), Vector3(dx, -1.0, 0.1 if fr else -0.1), ln, w, col, stiff, Vector3.RIGHT)


static func _dg(s: Dictionary, bone: String, model_root: Vector3, dir: Vector3, length: float, width: float, col: Color, stiff := 0.2, side := Vector3.ZERO, thick := 0.004, taper := 0.35) -> void:
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
	s["dg"].append([bone, pack])


# ------------------------------------------------------------------ set içinde tekrar eden kalıplar (oranlar sete özel)
## Sarma yaka: iki omuzdan göğüste kesişen pervaz
static func _wrap_collar(s: Dictionary, col: Color, w: float, ybot: float, top := 0.075) -> void:
	var N = float(s["N"])
	_path(s, -top, N - 0.02, 0.05, ybot, w, col)
	_path(s, top, N - 0.02, -0.03, ybot + 0.05, w, col)


## Düğme dizisi
static func _buttons(s: Dictionary, x: float, y0: float, y1: float, n: int, r: float, col: Color) -> void:
	for i in n:
		_btn(s, x, lerpf(y0, y1, float(i) / maxi(n - 1, 1)), r, col)


## Yelek üstü yatay tokalı kayışlar
static func _bars(s: Dictionary, y0: float, dy: float, n: int, hw: float, h: float, col: Color, tip: Color) -> void:
	for i in n:
		var y = y0 - i * dy
		_path(s, -hw, y, hw, y, h, col)
		_box(s, hw * 0.45, y, 0.018, h * 1.4, 0.005, tip, true, 0.009)


## Bacak sargısı: art arda ince halkalar
static func _wraps(s: Dictionary, y0: float, y1: float, n: int, col: Color) -> void:
	for i in n:
		_leg(s, lerpf(y0, y1, float(i) / maxi(n - 1, 1)), 0.016, col.darkened(0.05 * (i % 2)), 0.005)


## Uyluk kılıfı (shuriken torbası): kayış + kese; sağ bacak
static func _holster(s: Dictionary, col: Color, band := WRAP) -> void:
	if s["m"].look.get("holster") != false:
		return   # kıyafetin kendi uyluk kılıfı zaten var
	var y = float(s["H"]) - 0.19
	var x = -float(s["lx"])
	_leg(s, y + 0.035, 0.018, band, 0.005)
	_kese(s, x - 0.05, y, 0.07, 0.085, col)


## Yuvarlak arma: halka + iç disk
static func _crest(s: Dictionary, x: float, y: float, r: float, ring_c: Color, in_c: Color, fr := false) -> void:
	_btn(s, x, y, r, ring_c, fr, 0.004)
	_btn(s, x, y, r * 0.72, in_c, fr, 0.008)


## Düz girdap + ışınlar (mühür baskısı yerine kabartma şerit)
static func _swirl(s: Dictionary, cx: float, cy: float, R: float, col: Color) -> void:
	var prev = Vector2(cx, cy)
	for i in range(1, 19):
		var t = float(i) / 18.0
		var a = t * TAU * 2.2
		var q = Vector2(cx + cos(a) * R * t, cy + sin(a) * R * t * 1.05)
		_path(s, prev.x, prev.y, q.x, q.y, 0.0075, col, true, 0.003, 0.005)
		prev = q
	for i in 12:
		var a = i * TAU / 12.0 + 0.2
		var r0 = R * 1.18
		var r1 = R * (1.55 if i % 2 == 0 else 1.36)
		_path(s, cx + cos(a) * r0, cy + sin(a) * r0, cx + cos(a + 0.13) * r1, cy + sin(a + 0.13) * r1, 0.008, col, true, 0.003, 0.005)


# ------------------------------------------------------------------ setler
static func _spec(s: Dictionary, sid: String) -> void:
	var N = float(s["N"])
	var H = float(s["H"])
	var K = float(s["K"])
	var A = float(s["A"])
	var W = H + 0.11      # bel
	var C = N - 0.2       # göğüs
	var lx = float(s["lx"])
	match sid:
		"ss_kaplumbaga":
			var teal = Color("2f8a78")
			_strap(s, -0.11, N - 0.05, 0.15, H + 0.2, 0.018, LEATHER)
			_box(s, 0.0, H + 0.2, 0.11, 0.036, 0.006, Color("8d86aa"), true, 0.006)
			_tail(s, 0.04, H + 0.03, 0.12, 0.34, 0.05, teal)
			_tail(s, 0.0, H + 0.03, -0.08, 0.27, 0.04, teal.darkened(0.14))
			_cuff(s, 0.93, 0.05, Color("23232c"), 0.01, 1.0)
			_box(s, 0.0, N - 0.32, 0.04, 0.02, 0.005, BRASS, false)
		"ss_kara_palto":
			var slate = Color("3c3f66")
			_path(s, -0.17, W + 0.03, 0.16, W - 0.015, 0.05, slate, true, 0.008, 0.006)
			_path(s, 0.16, W + 0.03, -0.16, W - 0.02, 0.04, slate.darkened(0.2), true, 0.008, 0.012)
			_box(s, 0.0, W, 0.05, 0.05, 0.008, slate.lightened(0.15), true, 0.018)
			_tail(s, 0.05, W - 0.03, 0.05, 0.26, 0.05, slate)
			_ring(s, N + 0.0, 0.008, BLACK, 0.006, -1.2, 1.2, 0.004, 0.15)
			_btn(s, 0.0, N - 0.11, 0.012, BLACK)
		"ss_karga_cubbe":
			var khaki = Color("b8a878")
			_ring(s, N - 0.01, 0.042, khaki, 0.012, -PI, PI, 0.012, 0.2)
			_ring(s, N + 0.018, 0.012, khaki.darkened(0.15), 0.008, -PI, PI, 0.02, 0.2)
			_zip(s, 0.0, N - 0.06, K + 0.2, Color("c8bda0"))
			_ring(s, W, 0.012, Color("4a1019"), 0.005)
			_cuff(s, 0.86, 0.02, khaki.darkened(0.1), 0.005)
		"ss_karga_tunik":
			_belt(s, W - 0.015, 0.024, WRAP, null)
			_path(s, -0.06, N - 0.015, 0.0, N - 0.12, 0.014, Color("37375e"))
			_path(s, 0.06, N - 0.015, 0.0, N - 0.12, 0.014, Color("37375e"))
			_cuff(s, 0.4, 0.016, Color("37375e"), 0.005)
			_ring(s, H - 0.18, 0.012, Color("37375e"), 0.005)
			_wraps(s, K - 0.12, A + 0.1, 5, WRAP)
		"ss_kaya_paltosu":
			var dk = Color("13323f")
			_path(s, -0.055, N - 0.03, -0.075, K + 0.05, 0.024, dk, true, 0.007)
			_path(s, 0.055, N - 0.03, 0.075, K + 0.05, 0.024, dk, true, 0.007)
			_buttons(s, -0.078, N - 0.16, H - 0.05, 4, 0.009, STEEL)
			_box(s, -0.0, W + 0.0, 0.1, 0.022, 0.006, LEATHER_D, true, 0.006)
			_crest(s, 0.0, N - 0.16, 0.05, Color("7b1f2c"), WRAP)
			_ring(s, K + 0.05, 0.016, dk, 0.006)
			_cuff(s, 0.72, 0.09, WRAP, 0.006)
			_leg(s, A + 0.12, 0.03, BLACK)
		"ss_kaya_striker", "ss_kaya_striker_kurtarici", "ss_kaya_striker_postaci":
			var acc = {"ss_kaya_striker": Color("e8b820"), "ss_kaya_striker_kurtarici": Color("f2f2ee"), "ss_kaya_striker_postaci": Color("f0c840")}[sid]
			_path(s, 0.05, N - 0.05, 0.075, W + 0.05, 0.006, acc, true, 0.003)
			_leg(s, K + 0.1, 0.018, LEATHER_D)
			_box(s, -lx - 0.06, K + 0.1, 0.022, 0.03, 0.005, STEEL)
			_cuff(s, 0.45, 0.014, acc, 0.004, 1.0)
		"ss_kedi":
			var fur = Color("f1eee2")
			_ring(s, N, 0.03, fur, 0.016, -PI, PI, 0.012, 0.18)
			_path(s, -0.17, C + 0.09, -0.17, W + 0.08, 0.02, fur, true, 0.012)
			_path(s, 0.17, C + 0.09, 0.17, W + 0.08, 0.02, fur, true, 0.012)
			_zip(s, 0.0, N - 0.04, W + 0.03)
			_kese(s, 0.11, H + 0.0, 0.08, 0.075, Color("6a5a2a"))
			_ring(s, H + 0.05, 0.016, LEATHER_D, 0.005)
			_tail(s, -lx - 0.0, H - 0.24, 0.0, 0.26, 0.04, Color("8a7030"), true, 0.3)
			_holster(s, BLACK)
		"ss_kedi_alev":
			var pink = Color("b84a62")
			_path(s, -0.17, H + 0.13, 0.17, H + 0.03, 0.05, pink, true, 0.008, 0.008)
			_tail(s, 0.13, H + 0.03, 0.08, 0.2, 0.05, pink.darkened(0.12))
			_strap(s, -0.12, N - 0.04, -0.04, C, 0.01, Color("3f6fb0"))
			for x in [-0.09, 0.09]:
				_path(s, x, C + 0.1, x, W + 0.09, 0.006, Color("8f8a9c"), true, 0.003)
			_wraps(s, K - 0.14, A + 0.1, 5, WRAP)
			for f in [0.6, 0.68, 0.76, 0.84]:
				_cuff(s, f, 0.018, WRAP, 0.005)
		"ss_kimono_etek":
			var ob = Color("e88a2c")
			_wrap_collar(s, Color("d9d9de"), 0.022, W + 0.05)
			_ring(s, W, 0.075, ob, 0.012, -PI, PI, 0.006)
			for dy in [-0.022, 0.022]:
				_ring(s, W + dy, 0.006, ob.darkened(0.25), 0.004, -PI, PI, 0.019)
			_box(s, 0.0, W, 0.13, 0.05, 0.016, ob.lightened(0.08), false, 0.018)
			_box(s, 0.0, W, 0.04, 0.066, 0.008, ob.darkened(0.2), false, 0.034)
			_kese(s, 0.0, H - 0.0, 0.1, 0.06, Color("e0b63c"), false)
			_ring(s, H - 0.2, 0.012, Color("d9d9de"), 0.005)
		"ss_kiri_genin":
			var pl = Color("5e5d74")
			_bars(s, C + 0.04, 0.075, 3, 0.15, 0.012, pl, STEEL)
			_path(s, 0.0, C + 0.09, 0.0, W, 0.008, pl, true, 0.004)
			_strap(s, -0.13, N - 0.02, -0.15, C - 0.06, 0.03, pl)
			_strap(s, 0.13, N - 0.02, 0.15, C - 0.06, 0.03, pl)
			_belt(s, H + 0.05, 0.022, LEATHER_D, STEEL)
			_holster(s, BLACK)
		"ss_kizil_elbise":
			var tr = Color("8c2a44")
			_path(s, -0.075, N - 0.03, 0.0, C - 0.09, 0.012, tr)
			_path(s, 0.075, N - 0.03, 0.0, C - 0.09, 0.012, tr)
			_tail(s, -0.03, N - 0.01, -0.1, 0.1, 0.05, Color("efd060"), true, 0.3, "UpperChest")
			_tail(s, 0.03, N - 0.01, 0.12, 0.09, 0.05, Color("e2c150"), true, 0.3, "UpperChest")
			_ring(s, H - 0.19, 0.012, tr, 0.005)
			_holster(s, BLACK)
		"ss_kizil_fermuar":
			var tr = Color("8e1c2a")
			_ring(s, N - 0.01, 0.03, tr, 0.009, -PI, PI, 0.006, 0.16)
			_path(s, 0.0, N - 0.04, 0.06, W + 0.02, 0.008, Color("e9dfd8"), true, 0.003)
			_box(s, 0.0, N - 0.05, 0.012, 0.024, 0.004, STEEL, true, 0.007)
			_crest(s, 0.0, N - 0.17, 0.045, Color("c83a44"), WHITE)
			_path(s, -0.17, H + 0.0, -0.14, H - 0.2, 0.012, tr, true, 0.004)
			_path(s, 0.17, H + 0.0, 0.14, H - 0.2, 0.012, tr, true, 0.004)
			_holster(s, BLACK)
		"ss_kizil_kayis":
			_bars(s, C + 0.08, 0.05, 3, 0.1, 0.012, BLACK, STEEL)
			_belt(s, W - 0.02, 0.03, LEATHER, STEEL)
			_path(s, -0.15, W - 0.03, 0.17, H - 0.1, 0.03, LEATHER, true, 0.007, 0.012)
			_path(s, -0.15, W - 0.03, 0.17, H - 0.1, 0.03, LEATHER, false, 0.007, 0.012)
			_kese(s, 0.18, H - 0.12, 0.07, 0.09, LEATHER_D)
			_cuff(s, 0.42, 0.03, Color("8d8d96"), 0.006)
			_wraps(s, K - 0.12, A + 0.2, 3, Color("8d8d96"))
		"ss_kizil_palto":
			_buttons(s, -0.06, N - 0.09, W + 0.05, 5, 0.011, BLACK)
			_buttons(s, 0.06, N - 0.09, W + 0.05, 5, 0.011, BLACK)
			_belt(s, W - 0.005, 0.03, LEATHER, STEEL)
			_belt(s, W - 0.055, 0.024, LEATHER_D, STEEL, 0.04)
			_ring(s, N - 0.005, 0.03, Color("6e1520"), 0.01, -PI, PI, 0.006, 0.16)
			_cuff(s, 0.86, 0.04, BLACK, 0.006)
			_path(s, 0.0, H - 0.1, 0.0, K - 0.1, 0.009, Color("5e111b"), false, 0.003)
		"ss_kizil_palto2":
			var g2 = Color("7d8092")
			_bars(s, C + 0.03, 0.05, 3, 0.11, 0.014, g2.darkened(0.25), STEEL)
			_path(s, -0.16, C + 0.13, 0.09, C + 0.02, 0.018, g2.darkened(0.2))
			_belt(s, W - 0.03, 0.026, g2, STEEL)
			_ring(s, N - 0.005, 0.028, Color("6e1520"), 0.01, -PI, PI, 0.006, 0.16)
			_cuff(s, 0.86, 0.04, BLACK, 0.006)
			_btn(s, 0.0, C - 0.17, 0.012, BLACK)
		"ss_kizil_takim":
			_zip(s, 0.0, N - 0.04, H + 0.02)
			_ring(s, N - 0.005, 0.034, WHITE, 0.012, -PI, PI, 0.008, 0.17)
			_ring(s, H + 0.02, 0.03, Color("701018"), 0.007)
			_cuff(s, 0.95, 0.03, Color("701018"), 0.007)
			_path(s, -0.13, C + 0.1, -0.15, H + 0.03, 0.006, WHITE, true, 0.003)
			_path(s, 0.13, C + 0.1, 0.15, H + 0.03, 0.006, WHITE, true, 0.003)
			_box(s, 0.0, C - 0.01, 0.15, 0.1, 0.004, WHITE, false)
			_box(s, 0.0, C - 0.01, 0.135, 0.085, 0.003, Color("a01c22"), false, 0.007)
			for x in [-0.035, 0.035]:
				_box(s, x, C - 0.01, 0.04, 0.05, 0.002, WHITE, false, 0.01)
			_leg(s, K - 0.14, 0.05, WHITE, 0.008)
		"ss_kizil_zirh":
			var dk = Color("6a1216")
			_path(s, 0.0, C + 0.09, 0.0, W + 0.05, 0.008, dk, true, 0.005)
			_path(s, -0.13, C + 0.0, 0.0, C - 0.06, 0.012, dk, true, 0.005)
			_path(s, 0.13, C + 0.0, 0.0, C - 0.06, 0.012, dk, true, 0.005)
			_tail(s, 0.0, W - 0.03, 0.03, 0.22, 0.05, BLACK)
			_tail(s, 0.03, W - 0.03, 0.14, 0.16, 0.04, BLACK.lightened(0.05))
			_leg(s, K + 0.03, 0.02, dk)
			_leg(s, A + 0.2, 0.02, dk)
			_cuff(s, 0.72, 0.02, dk)
		"ss_kod":
			var lil = Color("a890c8")
			_buttons(s, -0.03, C + 0.05, W + 0.04, 4, 0.0085, Color("3c3c48"))
			_box(s, 0.0, N - 0.075, 0.03, 0.05, 0.008, WHITE, true, 0.006)
			_path(s, 0.0, N - 0.09, 0.012, C + 0.02, 0.022, WHITE, true, 0.004, 0.008)
			_kese(s, 0.1, W + 0.0, 0.07, 0.022, Color("24242c"))
			_leg(s, K - 0.19, 0.11, lil, 0.008)
			_cuff(s, 0.86, 0.06, lil, 0.008)
		"ss_kok_reisi":
			var pu = Color("9a8ab0")
			_wrap_collar(s, Color("cfd7e4"), 0.03, W + 0.04)
			_ring(s, W - 0.03, 0.04, pu, 0.009)
			_box(s, 0.03, W - 0.03, 0.04, 0.05, 0.012, pu.darkened(0.15), true, 0.01)
			_tail(s, 0.05, W - 0.05, 0.06, 0.28, 0.05, pu)
			_tail(s, 0.015, W - 0.05, -0.03, 0.22, 0.04, pu.darkened(0.1))
			for f in [0.25, 0.4, 0.55, 0.7, 0.85]:
				_cuff(s, f, 0.024, WRAP, 0.008, -1.0)
		"ss_konoha_genin":
			_cuff(s, 0.42, 0.04, Color("172238"), 0.008)
			_leg(s, K - 0.06, 0.05, Color("172238"), 0.008)
			_wraps(s, K - 0.2, A + 0.09, 4, WRAP)
			_crest(s, 0.0, C + 0.0, 0.05, Color("9a2424"), Color("5f8c7c"))
			_holster(s, BLACK)
		"ss_kopuk":
			var bl = Color("1e3a9a")
			var or_c = Color("e8681e")
			_tail(s, -0.03, W - 0.03, -0.04, 0.4, 0.05, or_c, true, 0.2)
			_tail(s, 0.03, W - 0.03, 0.05, 0.46, 0.05, or_c.darkened(0.08), true, 0.2)
			_box(s, 0.0, W, 0.06, 0.06, 0.018, or_c.lightened(0.08), true, 0.016)
			_path(s, -0.14, W + 0.05, 0.12, W - 0.04, 0.026, or_c, true, 0.006, 0.012)
			_ring(s, A + 0.28, 0.03, bl, 0.006)
			_cuff(s, 0.84, 0.03, bl, 0.006)
		"ss_kukla":
			_strap(s, -0.11, N - 0.02, -0.14, C - 0.14, 0.03, WRAP)
			_strap(s, 0.11, N - 0.02, 0.14, C - 0.14, 0.03, WRAP)
			_ring(s, W, 0.024, Color("8a1a2a"), 0.008)
			_ring(s, N + 0.0, 0.036, Color("24242a"), 0.012, -PI, PI, 0.006, 0.15)
			_leg(s, A + 0.2, 0.03, Color("26262c"), 0.008)
			_cuff(s, 0.82, 0.03, Color("26262c"), 0.006)
		"ss_kukla_genc":
			_zip(s, 0.0, N - 0.03, W + 0.03)
			_ring(s, N, 0.05, Color("2e2240"), 0.012, -PI, PI, 0.006, 0.16)
			_path(s, -0.14, C + 0.04, -0.12, W + 0.05, 0.007, Color("2b2038"), true, 0.004)
			_path(s, 0.14, C + 0.04, 0.12, W + 0.05, 0.007, Color("2b2038"), true, 0.004)
			_box(s, 0.0, H + 0.1, 0.05, 0.03, 0.006, STEEL, true, 0.012)
			_wraps(s, K - 0.16, A + 0.1, 4, WRAP)
			_holster(s, BLACK)
		"ss_kum_cocuk":
			_strap(s, -0.11, N - 0.02, 0.16, H + 0.04, 0.024, LEATHER)
			_kese(s, 0.16, H + 0.03, 0.075, 0.095, LEATHER)
			_box(s, -0.01, C - 0.04, 0.07, 0.03, 0.005, STEEL, true, 0.016)
			_tail(s, -0.03, W - 0.1, 0.0, 0.4, 0.09, WHITE, true, 0.25)
			_wraps(s, K - 0.2, A + 0.09, 4, WRAP)
		"ss_kum_striker", "ss_kum_striker_balon", "ss_kum_striker_kabile":
			var c0 = {"ss_kum_striker": Color("c9bc92"), "ss_kum_striker_balon": Color("e8e8e2"), "ss_kum_striker_kabile": Color("e8b830")}[sid]
			for i in 5:
				_box(s, lerpf(-0.04, 0.06, i / 4.0), lerpf(C + 0.05, C - 0.06, i / 4.0), 0.016, 0.03, 0.009, c0.darkened(0.2), true, 0.012)
			_cuff(s, 0.5, 0.018, c0, 0.005)
			_leg(s, A + 0.12, 0.02, LEATHER_D)
		"ss_kumarbaz":
			_crest(s, 0.0, C + 0.0, 0.06, Color("a81e24"), Color("eee8d8"))
			for r in [[-0.022, 0.03], [0.0, 0.03], [0.022, 0.03]]:
				_box(s, r[0], C + 0.0, 0.007, 0.05, 0.002, BLACK, false, 0.012)
			_path(s, -0.04, C + 0.0, 0.04, C + 0.0, 0.007, BLACK, false, 0.002, 0.012)
			_wrap_collar(s, WHITE, 0.02, W + 0.05)
			_cuff(s, 0.86, 0.035, Color("1f4e2a"), 0.006)
			_ring(s, K + 0.03, 0.022, Color("1f4e2a"), 0.006)
			_wraps(s, K - 0.17, A + 0.09, 4, WRAP)
		"ss_kumo_genin":
			var g3 = Color("a9a9a4")
			_path(s, -0.12, C + 0.09, 0.15, W + 0.0, 0.016, g3, true, 0.005)
			_box(s, 0.1, N - 0.08, 0.05, 0.036, 0.008, g3)
			_leg(s, K + 0.1, 0.02, WRAP)
			for sx in [-1.0, 1.0]:
				_path(s, sx * (lx - 0.07), K + 0.07, sx * (lx + 0.07), K + 0.13, 0.016, WRAP)
				_path(s, sx * (lx + 0.07), K + 0.07, sx * (lx - 0.07), K + 0.13, 0.016, WRAP)
			_holster(s, BLACK)
		"ss_kurbaga":
			var dk = Color("3f8e3a")
			_zip(s, 0.0, N - 0.03, H - 0.02, dk)
			for sx in [-1.0, 1.0]:
				_btn(s, sx * 0.07, C - 0.13, 0.026, Color("8cd080"))
				_btn(s, sx * 0.045, H - 0.02, 0.018, Color("8cd080"))
				_path(s, sx * 0.17, C + 0.05, sx * 0.14, H - 0.05, 0.006, dk, true, 0.003)
			_ring(s, W - 0.04, 0.014, dk, 0.004)
			_cuff(s, 0.9, 0.02, dk, 0.005)
			_leg(s, A + 0.08, 0.02, dk, 0.005)
		"ss_kurbaga_bilge", "ss_kurbaga_bilge2":
			for sx in [-1.0, 1.0]:
				_btn(s, sx * 0.125, C + 0.0, 0.05, Color("d8ae50"), true, 0.006)
				_btn(s, sx * 0.125, C + 0.0, 0.036, Color("e8c468"), true, 0.01)
				_path(s, sx * 0.085, N - 0.04, sx * 0.135, K + 0.04, 0.014, Color("7a151a"), true, 0.004)
			_wrap_collar(s, Color("6e8a6e"), 0.02, W + 0.04)
			_belt(s, W - 0.01, 0.03, BLACK, null)
			_cuff(s, 0.86, 0.05, Color("3a3a42"), 0.008)
			_leg(s, A + 0.2, 0.024, LEATHER_D)
			_leg(s, A + 0.08, 0.022, LEATHER_D)
			if sid == "ss_kurbaga_bilge2":   # bilge kurbağaların tünediği omuz yastıkları
				_strap(s, -0.13, N - 0.015, -0.16, C + 0.0, 0.05, Color("3e3a3c"))
				_strap(s, 0.13, N - 0.015, 0.16, C + 0.0, 0.05, Color("5b4a78"))
		"ss_kurucu_genc":
			var ol = Color("b0a030")
			_wrap_collar(s, ol, 0.026, H + 0.02, 0.07)
			_path(s, 0.05, H + 0.02, 0.085, K + 0.12, 0.026, ol, true, 0.006)
			_ring(s, W + 0.01, 0.012, BLACK, 0.004, -PI, PI, 0.014)
			_cuff(s, 0.86, 0.06, Color("3a3a42"), 0.005)
			_leg(s, A + 0.22, 0.02, WRAP)
		"ss_kurucu_palto":
			_path(s, 0.0, N - 0.03, 0.0, A + 0.25, 0.012, Color("a01c22"), true, 0.004)
			_ring(s, N + 0.0, 0.06, Color("17171b"), 0.012, -PI, PI, 0.008, 0.17)
			_path(s, -0.15, W - 0.04, 0.18, H - 0.1, 0.02, LEATHER, true, 0.006, 0.014)
			_kese(s, 0.19, H - 0.13, 0.06, 0.08, LEATHER_D)
			_box(s, 0.0, W, 0.12, 0.05, 0.012, Color("7e7f92"), true, 0.014)
		"ss_kutlama":
			var fur = Color("efeae0")
			var cy = Color("2fa4b8")
			_strap(s, -0.1, N - 0.015, -0.13, C + 0.0, 0.06, fur)
			_strap(s, 0.1, N - 0.015, 0.13, C + 0.0, 0.06, fur)
			for sx in [-1.0, 1.0]:
				_btn(s, sx * 0.09, C - 0.05, 0.022, cy, true, 0.012)
				_tail(s, sx * 0.09, C - 0.07, 0.0, 0.1, 0.03, fur, true, 0.3, "UpperChest")
			_btn(s, 0.0, W, 0.024, cy, true, 0.016)
			_tail(s, 0.19, H - 0.2, 0.03, 0.14, 0.03, Color("d09a60"))
			_tail(s, -0.19, H - 0.2, -0.03, 0.14, 0.03, Color("d09a60"))
		"ss_kuyruklu_beyaz":
			var bk = Color("1c1c20")
			for i in 4:
				_path(s, -0.09, C + 0.08 - i * 0.05, 0.09, C + 0.08 - i * 0.05, 0.01, bk, false, 0.004)
			_btn(s, 0.0, C - 0.01, 0.022, Color("b02a30"), true, 0.012)
			_box(s, 0.0, W, 0.07, 0.028, 0.006, bk, true, 0.008)
			_ring(s, H + 0.03, 0.02, bk, 0.006)
			for f in [0.62, 0.72, 0.82, 0.92]:
				_cuff(s, f, 0.018, bk, 0.005)
			_leg(s, K - 0.05, 0.02, bk)
		"ss_lav_zirh":
			var br = Color("4e3420")
			_strap(s, -0.11, N - 0.02, -0.12, C - 0.1, 0.03, br)
			_strap(s, 0.11, N - 0.02, 0.12, C - 0.1, 0.03, br)
			_path(s, -0.11, C + 0.07, 0.11, C + 0.07, 0.012, br.lightened(0.15), true, 0.005, 0.012)
			_belt(s, W - 0.04, 0.03, Color("2c2448"), null)
			for sx in [-1.0, 1.0]:
				_kese(s, sx * 0.17, H - 0.09, 0.08, 0.14, br)
			_wrap_collar(s, Color("7c1c66"), 0.02, C - 0.02, 0.07)
		"ss_lavanta_ceket":
			_zip(s, 0.0, N - 0.04, H + 0.0)
			_ring(s, H + 0.0, 0.03, WHITE, 0.009)
			_cuff(s, 0.9, 0.04, Color("a8a0e0"), 0.008)
			_path(s, -0.13, C + 0.06, -0.15, H + 0.04, 0.012, WHITE, true, 0.004)
			_path(s, 0.13, C + 0.06, 0.15, H + 0.04, 0.012, WHITE, true, 0.004)
			_leg(s, K - 0.28, 0.034, Color("1d2a6a"), 0.006)
			_holster(s, BLACK)
		"ss_maske_pelerin":
			var lv = Color("c4c0e8")
			_ring(s, W, 0.05, lv, 0.012)
			_box(s, 0.0, W, 0.06, 0.03, 0.006, WHITE, true, 0.018)
			_ring(s, N - 0.0, 0.03, Color("1c1c52"), 0.012, -PI, PI, 0.01, 0.18)
			_crest(s, 0.0, C + 0.0, 0.055, Color("b02a30"), WHITE)
			_path(s, 0.045, H - 0.06, 0.09, A + 0.25, 0.018, Color("b8a050"), true, 0.004)
		"ss_maskeli_gaiden":
			_box(s, 0.0, C + 0.0, 0.05, 0.05, 0.007, STEEL, true, 0.014)
			_strap(s, -0.09, N - 0.02, 0.13, W + 0.03, 0.02, LEATHER)
			_strap(s, 0.09, N - 0.02, -0.13, W + 0.03, 0.02, LEATHER)
			_cuff(s, 0.12, 0.04, Color("8a8a96"), 0.006)
			_cuff(s, 0.78, 0.016, STEEL, 0.006)
			_wraps(s, K - 0.18, A + 0.1, 4, WRAP)
			_holster(s, BLACK)
		"ss_maskeli_genc":
			_box(s, 0.0, C - 0.1, 0.012, 0.13, 0.004, Color("567266"))
			_cuff(s, 0.15, 0.02, Color("9a2a2a"), 0.005, 1.0)
			_wraps(s, K - 0.17, A + 0.1, 4, WRAP)
			_holster(s, BLACK)
			_tail(s, -lx - 0.03, H - 0.25, 0.0, 0.16, 0.012, WRAP, true, 0.2)
		"ss_maskeli_jonin":
			_cuff(s, 0.18, 0.05, Color("a11f24"), 0.008, 1.0)
			_box(s, 0.0, H + 0.07, 0.15, 0.08, 0.008, Color("3f5a3c"), true, 0.004)
			_wraps(s, K - 0.04, K - 0.12, 2, WRAP)
			_holster(s, BLACK)
		"ss_metal_canavar":
			var or_c = Color("d9862e")
			_ring(s, N - 0.005, 0.03, or_c.darkened(0.12), 0.016, -PI, PI, 0.014, 0.17)
			_ring(s, N + 0.025, 0.026, or_c, 0.014, -PI, PI, 0.012, 0.15)
			_belt(s, W - 0.02, 0.034, BLACK, STEEL, 0.075)
			for f in [0.72, 0.8, 0.88, 0.96]:
				_cuff(s, f, 0.024, WRAP, 0.008)
			_leg(s, K - 0.04, 0.02, or_c.darkened(0.22))
			_holster(s, BLACK)
		"ss_mevsim":
			var dk = Color("4e9c86")
			var pink = Color("efa0bc")
			_strap(s, -0.1, N - 0.03, 0.15, H + 0.1, 0.009, Color("2c6a5a"))
			for i in 4:
				var a = i * 1.6
				_btn(s, -0.11 + 0.08 * i, H + 0.1 + 0.03 * sin(a), 0.02, pink)
				_btn(s, -0.09 + 0.06 * i, H + 0.03 + 0.02 * cos(a), 0.014, Color("f7e2a0"))
			for i in 4:
				for j in 3:
					if (i + j) % 2 == 0:
						_box(s, -0.11 + i * 0.075, C + 0.06 - j * 0.06, 0.06, 0.05, 0.002, dk, true, 0.005)
			for sx in [-1.0, 1.0]:
				_btn(s, sx * (lx + 0.03), K - 0.14, 0.03, pink)
				_btn(s, sx * (lx - 0.04), K - 0.05, 0.022, pink.lightened(0.1))
			_cuff(s, 0.92, 0.024, dk, 0.006)
		"ss_mikoshi":
			var gold = Color("c8a24a")
			_ring(s, W + 0.08, 0.06, Color("8d8d94"), 0.006)
			for dy in [-0.02, 0.0, 0.02]:
				_ring(s, W + 0.08 + dy, 0.004, Color("6c6c74"), 0.004, -PI, PI, 0.012)
			_path(s, -0.17, W + 0.02, 0.03, H - 0.2, 0.022, gold, true, 0.006, 0.01)
			_path(s, 0.17, W + 0.02, -0.03, H - 0.2, 0.022, gold, true, 0.006, 0.01)
			_path(s, -0.09, N - 0.01, 0.1, C + 0.0, 0.007, Color("b03030"), true, 0.003)
			for f in [0.56, 0.66, 0.76, 0.86]:
				_cuff(s, f, 0.022, Color("8d8d94"), 0.006)
		"ss_mor_etek":
			_box(s, 0.0, H - 0.1, 0.05, 0.2, 0.004, Color("4a1c70"))
			_ring(s, H + 0.03, 0.02, Color("4a1c70"), 0.006)
			_ring(s, N - 0.005, 0.022, Color("4a1c70"), 0.008, -PI, PI, 0.006, 0.15)
			_cuff(s, 0.42, 0.014, Color("6a2a9a"), 0.005)
			_cuff(s, 0.56, 0.014, Color("6a2a9a"), 0.005)
			_leg(s, K + 0.07, 0.014, Color("6a2a9a"), 0.005)
			_leg(s, K - 0.07, 0.014, Color("6a2a9a"), 0.005)
		"ss_mor_genc":
			_belt(s, H + 0.03, 0.03, Color("24306a"), STEEL, 0.07)
			_ring(s, W + 0.04, 0.05, WRAP, 0.006)
			for dy in [-0.012, 0.012]:
				_ring(s, W + 0.04 + dy, 0.003, Color("c8c4b8"), 0.003, -PI, PI, 0.012)
			_ring(s, N - 0.005, 0.03, Color("3f2472"), 0.01, -PI, PI, 0.006, 0.16)
			_kese(s, 0.0, H - 0.03, 0.1, 0.07, Color("b89a70"), false)
			_holster(s, BLACK)
		"ss_mor_genin":
			_ring(s, N - 0.005, 0.03, WHITE, 0.009, -PI, PI, 0.006, 0.16)
			_zip(s, 0.0, N - 0.04, H + 0.01, Color("9a8cc0"))
			for x in [-0.13, 0.13]:
				_path(s, x, C + 0.09, x, H + 0.02, 0.01, WHITE, true, 0.004)
			_ring(s, H + 0.0, 0.014, WHITE, 0.005)
			_leg(s, K + 0.15, 0.026, WRAP)
			_holster(s, BLACK)
		"ss_mor_kemer":
			var dk = Color("4c3a78")
			_ring(s, W + 0.0, 0.07, dk, 0.01)
			_ring(s, W + 0.025, 0.006, Color("3a2a5c"), 0.004, -PI, PI, 0.015)
			_box(s, 0.0, W, 0.09, 0.05, 0.006, Color("5e2f6c"), true, 0.014)
			for x in [-0.09, -0.045, 0.045, 0.09]:
				_path(s, x, C + 0.09, x, W + 0.05, 0.003, Color("a89ad0"), true, 0.002)
			_ring(s, N - 0.005, 0.03, Color("d8d2ec"), 0.009, -PI, PI, 0.006, 0.16)
			_holster(s, BLACK)
		"ss_mor_uzun":
			_path(s, -0.02, H + 0.02, 0.05, A + 0.2, 0.012, Color("41206a"), true, 0.004)
			_ring(s, A + 0.2, 0.016, Color("41206a"), 0.005)
			_ring(s, H + 0.03, 0.03, Color("41206a"), 0.007)
			_ring(s, N - 0.005, 0.022, Color("41206a"), 0.008, -PI, PI, 0.006, 0.15)
			_path(s, -0.1, C - 0.04, 0.1, C - 0.04, 0.012, Color("41206a"), true, 0.004)
		"ss_murekkep":
			var rd = Color("a01c22")
			_zip(s, 0.0, N - 0.03, C - 0.09)
			_strap(s, -0.1, N - 0.015, -0.1, C + 0.03, 0.022, rd)
			_strap(s, 0.1, N - 0.015, 0.1, C + 0.03, 0.022, rd)
			_ring(s, W + 0.02, 0.05, Color("7a6f9c"), 0.006)
			_belt(s, H + 0.04, 0.02, LEATHER, STEEL, 0.03)
			_kese(s, 0.15, H - 0.0, 0.07, 0.08, LEATHER_D)
			_holster(s, BLACK)
		"ss_murekkep_ceket":
			var rd = Color("a01c22")
			_strap(s, -0.11, N - 0.015, -0.12, C + 0.04, 0.024, rd)
			_strap(s, 0.11, N - 0.015, 0.12, C + 0.04, 0.024, rd)
			_zip(s, 0.0, N - 0.04, W + 0.04, Color("9aa0ae"))
			_belt(s, H + 0.05, 0.024, Color("c9c9cf"), BLACK)
			_kese(s, -0.15, H - 0.0, 0.07, 0.09, Color("7a2a24"))
			_holster(s, BLACK)
			_cuff(s, 0.9, 0.02, rd, 0.005)
		"ss_naginata":
			var rd = Color("c8486a")
			_wrap_collar(s, rd, 0.016, W + 0.06)
			_cuff(s, 0.5, 0.012, rd, 0.004)
			_ring(s, W, 0.05, rd, 0.01)
			_box(s, 0.0, W + 0.005, 0.15, 0.05, 0.012, rd.lightened(0.05), true, 0.012)
			_box(s, 0.0, W + 0.005, 0.04, 0.06, 0.012, rd.darkened(0.2), true, 0.024)
			_tail(s, -0.02, W - 0.02, -0.08, 0.14, 0.045, rd)
			_tail(s, 0.02, W - 0.02, 0.08, 0.14, 0.045, rd)
			_leg(s, K - 0.04, 0.024, rd.darkened(0.25), 0.012)
		"ss_ninja_yolu_tisort":
			_swirl(s, 0.0, C - 0.03, 0.062, Color("f6f2e8"))
			_crest(s, 0.2, N - 0.08, 0.018, Color("23305a"), WHITE, true)
			_ring(s, N, 0.014, Color("1e2a48"), 0.005, -PI, PI, 0.005, 0.15)
			_ring(s, H + 0.0, 0.016, Color("1e2a48"), 0.005)
		"ss_okul_mor":
			var dk = Color("6a48a8")
			_ring(s, W, 0.045, dk, 0.01)
			_path(s, -0.08, N - 0.02, 0.0, C + 0.0, 0.016, WHITE)
			_path(s, 0.08, N - 0.02, 0.0, C + 0.0, 0.016, WHITE)
			_box(s, 0.0, C - 0.01, 0.03, 0.025, 0.008, Color("8e2a6a"), true, 0.008)
			_tail(s, -0.01, C - 0.03, -0.1, 0.11, 0.03, Color("8e2a6a"), true, 0.22, "UpperChest")
			_tail(s, 0.01, C - 0.03, 0.1, 0.11, 0.03, Color("8e2a6a"), true, 0.22, "UpperChest")
			_box(s, 0.0, N - 0.09, 0.2, 0.08, 0.004, WHITE, false)
			_cuff(s, 0.34, 0.016, dk, 0.005)
			_ring(s, H - 0.2, 0.012, dk, 0.005)
		"ss_on_kuyruk":
			var ribs = Color("b6c6bc")
			for i in 6:
				var a = -1.0 + i * 0.4
				_btn(s, sin(a) * 0.12, N - 0.06 - cos(a) * 0.03, 0.017, BLACK, true, 0.008)
			for i in 9:
				var a = -1.3 + i * 0.325
				_btn(s, sin(a) * 0.14, N - 0.05 - cos(a) * 0.03, 0.017, BLACK, false, 0.008)
			for i in 4:
				for sx in [-1.0, 1.0]:
					_path(s, sx * 0.02, C - 0.03 - i * 0.05, sx * 0.1, C - 0.01 - i * 0.05, 0.012, ribs, true, 0.006)
			_path(s, 0.0, C + 0.0, 0.0, H + 0.0, 0.008, ribs, true, 0.005)
		"ss_onluk":
			var dk = Color("1a3524")
			_strap(s, -0.075, N - 0.015, -0.1, C + 0.02, 0.022, Color("244a30"))
			_strap(s, 0.075, N - 0.015, 0.1, C + 0.02, 0.022, Color("244a30"))
			_zip(s, 0.0, N - 0.02, N - 0.1)
			_ring(s, W + 0.02, 0.014, dk, 0.005)
			_box(s, 0.0, H - 0.06, 0.15, 0.12, 0.005, Color("2c5a3a"), true, 0.004)
			_path(s, -0.075, H - 0.0, 0.075, H - 0.0, 0.006, dk, true, 0.003, 0.01)
			_tail(s, 0.0, W + 0.01, 0.04, 0.2, 0.03, dk, false)
			_tail(s, -0.03, W + 0.01, -0.06, 0.18, 0.03, dk, false)
			_cuff(s, 0.9, 0.012, BLACK, 0.005, 1.0)
		"ss_orman_zirh":
			var dk = Color("6a1216")
			_bars(s, C + 0.04, 0.05, 4, 0.12, 0.007, dk, BRASS)
			_path(s, 0.0, C + 0.09, 0.0, W, 0.008, dk, true, 0.005)
			_belt(s, W - 0.04, 0.026, BLACK, BRASS)
			_wraps(s, K - 0.15, A + 0.1, 5, WRAP)
