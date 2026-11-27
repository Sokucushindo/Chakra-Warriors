extends RefCounted
## Hazır setlere gerçek 3B ayrıntı, grup a (hedef: res://scripts/actors/set_v2_a.gd). Kaynak: refs/outfits_ss + _tmp/ss_outfit/list.txt.
## Bütün giysi kabukları tek yüzey kaynağında birleşir: ayrıntı o noktadaki EN DIŞ katmana oturur, en yakın kabuk köşesinin
## kemik ağırlığını alır (kumaşla bükülür). Bitmiş ağ set + cinsiyet başına bir kez kurulur.

const SETS := ["ss_acik_ceket", "ss_algi", "ss_alti_yol", "ss_altinci", "ss_anbu_kapuson", "ss_antrenman", "ss_antrenman_geishun", "ss_ates_pelerin", "ss_ay_cubbe", "ss_bes_kalp",
	"ss_bilge_palto", "ss_buhar_zirh", "ss_bulut_striker", "ss_bulut_striker_toprak", "ss_bulut_striker_yildiz", "ss_buz_kimono", "ss_buz_kimono2", "ss_delta", "ss_demir_dovme", "ss_demir_kum",
	"ss_denki", "ss_esofman", "ss_esofman2", "ss_esofman_turuncu2", "ss_esofman_yirtik", "ss_flut", "ss_gelinlik", "ss_genc_canavar", "ss_genclik", "ss_genclik_ayi",
	"ss_genclik_kedi", "ss_genclik_ruh", "ss_genis_yaka", "ss_genjutsu_sargi", "ss_gezegen", "ss_gezgin_palto", "ss_goksel_beyaz", "ss_golge_genc", "ss_golge_jonin", "ss_gosterisli",
	"ss_gosterisli_bahar", "ss_gosterisli_hava", "ss_gozluk_genc", "ss_gunebakan", "ss_gunesi", "ss_harika", "ss_harika_yildiz", "ss_hime_hakama", "ss_iblis", "ss_ic_giysi",
	"ss_inuzuka_ceket", "ss_iryo_hemsire", "ss_iryo_hemsire_bahar", "ss_iwa_genin", "ss_kabuk_cocuk", "ss_kabuk_cubbe", "ss_kabuk_okul", "ss_kabuk_yirtik", "ss_kader_genc", "ss_kagit_melek"]

const CELL := 0.03
const ROW := 0.02
const SILVER := Color(0.72, 0.74, 0.78)
const GOLD := Color(0.86, 0.68, 0.24)
const IRON := Color(0.24, 0.25, 0.28)
const WRAP := Color(0.93, 0.92, 0.88)
const LEATHER := Color(0.36, 0.23, 0.13)

static var _cache := {}


static func build(m, sid: String, g: Dictionary) -> void:
	if not sid in SETS:
		return
	var key = "%s|%s" % [sid, str(m.look.get("gender", "m"))]
	if _cache.has(key):
		var e: Array = _cache[key]
		if e[0] != null:
			var mi = MeshInstance3D.new()
			mi.mesh = e[0]
			m.skel.add_child(mi)
			mi.skin = m.body_mesh.skin
			mi.skeleton = mi.get_path_to(m.skel)
			mi.material_override = LazyFx.g("Props").toon()
		_dangles(m, e[1])
		return
	var c = _begin(m)
	if c.is_empty():
		return
	_recipe(c, sid)
	var made = m._sk_end(g)
	_cache[key] = [made.mesh if made != null else null, c["dg"]]
	_dangles(m, c["dg"])


static func _dangles(m, list: Array) -> void:
	for d in list:
		m.dangle_strip(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])


static func _recipe(c: Dictionary, sid: String) -> void:
	match sid:
		"ss_acik_ceket": _acik_ceket(c)
		"ss_algi": _algi(c)
		"ss_alti_yol": _alti_yol(c)
		"ss_altinci": _altinci(c)
		"ss_anbu_kapuson": _anbu_kapuson(c)
		"ss_antrenman": _keiko(c, K("1c3590"), K("f4f4f6"), K("9ac4e8"))
		"ss_antrenman_geishun": _geishun(c)
		"ss_ates_pelerin": _ates_pelerin(c)
		"ss_ay_cubbe": _ay_cubbe(c)
		"ss_bes_kalp": _bes_kalp(c)
		"ss_bilge_palto": _bilge_palto(c)
		"ss_buhar_zirh": _buhar_zirh(c)
		"ss_bulut_striker": _bulut(c, K("f2f2ee"), K("8a8c92"), K("e8e8e4"), 0)
		"ss_bulut_striker_toprak": _bulut(c, K("2a9a80"), K("1e7a64"), K("5a4030"), 1)
		"ss_bulut_striker_yildiz": _bulut(c, K("d8e8ff"), K("6a9ad8"), K("1e2e8a"), 2)
		"ss_buz_kimono": _buz_kimono(c)
		"ss_buz_kimono2": _buz_kimono2(c)
		"ss_delta": _delta(c)
		"ss_demir_dovme": _demir_dovme(c)
		"ss_demir_kum": _demir_kum(c)
		"ss_denki": _denki(c)
		"ss_esofman": _esofman(c, K("d84a6a"), 0.11, true)
		"ss_esofman2": _esofman(c, K("c03a7a"), 0.09, false)
		"ss_esofman_turuncu2": _turuncu2(c)
		"ss_esofman_yirtik": _esofman_yirtik(c)
		"ss_flut": _flut(c)
		"ss_gelinlik": _gelinlik(c)
		"ss_genc_canavar": _genc_canavar(c)
		"ss_genclik": _genclik(c, K("d04a80"), K("ececea"), K("c8c8c6"), K("d04a80"))
		"ss_genclik_ayi": _genclik(c, K("f2f2f2"), K("f2f6ff"), K("9ac8e8"), K("7a5232"))
		"ss_genclik_kedi": _genclik(c, K("7a7a7e"), K("18181c"), K("7a7a7e"), K("1e5a2a"))
		"ss_genclik_ruh": _genclik(c, K("e8c030"), K("1e2ab0"), K("e8c030"), K("c82020"))
		"ss_genis_yaka": _genis_yaka(c)
		"ss_genjutsu_sargi": _genjutsu(c)
		"ss_gezegen": _gezegen(c)
		"ss_gezgin_palto": _gezgin(c)
		"ss_goksel_beyaz": _goksel(c)
		"ss_golge_genc": _golge_genc(c)
		"ss_golge_jonin": _golge_jonin(c)
		"ss_gosterisli": _gosterisli(c, K("2a2c38"), K("a2a8e6"), K("c8c8d2"), K("1e2a5a"))
		"ss_gosterisli_bahar": _gosterisli(c, K("e8d838"), K("e8d838"), K("f2f2f0"), K("1e7a5a"))
		"ss_gosterisli_hava": _gosterisli(c, K("7a6252"), K("f0c840"), K("e8c040"), K("a06a3a"))
		"ss_gozluk_genc": _gozluk(c)
		"ss_gunebakan": _gunebakan(c)
		"ss_gunesi": _gunesi(c)
		"ss_harika": _harika(c, K("c8c8ce"), true)
		"ss_harika_yildiz": _harika(c, K("2c2c34"), false)
		"ss_hime_hakama": _hime(c)
		"ss_iblis": _iblis(c)
		"ss_ic_giysi": _ic_giysi(c)
		"ss_inuzuka_ceket": _inuzuka(c)
		"ss_iryo_hemsire": _hemsire(c, K("a01822"), K("f2f2f4"), K("c02830"))
		"ss_iryo_hemsire_bahar": _hemsire(c, K("f0d040"), K("f4f4f6"), K("2a9a8a"))
		"ss_iwa_genin": _iwa(c)
		"ss_kabuk_cocuk": _kawaki(c, K("7a9ac8"), K("6a4428"), 0.06, false)
		"ss_kabuk_cubbe": _jigen(c)
		"ss_kabuk_okul": _kawaki(c, K("8aa8d0"), K("18181c"), 0.045, true)
		"ss_kabuk_yirtik": _ruro(c)
		"ss_kader_genc": _kader(c)
		"ss_kagit_melek": _konan(c)


static func K(h: String) -> Color:
	return Color.html(h)


# ------------------------------------------------------------------ yüzey kaynağı
static func _begin(m) -> Dictionary:
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var B := []
	var W := []
	var per = 0
	var srcs := []
	if m.body_mesh != null and m.body_mesh.mesh is ArrayMesh:
		srcs.append(m.body_mesh.mesh)
	for ch in m.skel.get_children():
		if ch is MeshInstance3D and str(ch.name).begins_with("Cloth") and ch.mesh is ArrayMesh and ch.visible:
			srcs.append(ch.mesh)
	for ms in srcs:
		if not m._sk_begin(ms):
			continue
		var s: Dictionary = m._sk
		if per != 0 and int(s["per"]) != per:
			continue
		per = int(s["per"])
		V.append_array(s["v"])
		N.append_array(s["n"])
		B.append_array(s["b"])
		W.append_array(s["w"])
	if V.is_empty():
		m._sk = {}
		return {}
	m._sk = {"v": V, "n": N, "b": B, "w": W, "per": per, "ov": PackedVector3Array(), "on": PackedVector3Array(), "oc": PackedColorArray(),
		"ob": PackedInt32Array(), "ow": PackedFloat32Array(), "oi": PackedInt32Array(), "custom": false, "d0": {}}
	var cell := {}
	var rows := {}
	var cols := {}
	for i in V.size():
		var q: Vector3 = V[i]
		var k = Vector2i(floori(q.x / CELL), floori(q.y / CELL))
		if not cell.has(k):
			cell[k] = []
		cell[k].append(i)
		var r = floori(q.y / ROW)
		if not rows.has(r):
			rows[r] = []
		rows[r].append(i)
		var x = floori(q.x / ROW)
		if not cols.has(x):
			cols[x] = []
		cols[x].append(i)
	return {"m": m, "V": V, "Nn": N, "cell": cell, "rows": rows, "cols": cols, "dg": [],
		"N": m._bp("Neck").y, "C": m._bp("UpperChest").y, "H": m._bp("Hips").y, "Kn": m._bp("LeftLowerLeg").y, "A": m._bp("LeftFoot").y,
		"UA": absf(m._bp("LeftUpperArm").x), "EL": absf(m._bp("LeftLowerArm").x), "HA": absf(m._bp("LeftHand").x), "LX": absf(m._bp("LeftLowerLeg").x)}


## Giysinin alt ucu (kalıp önbelleğinden); bulunamazsa verilen değer
static func _hem(c: Dictionary, key: String, fallback: float) -> float:
	var m = c["m"]
	var gm = m._garment_cache.get("%s|%s|%.3f" % [m.look["gender"], key, m._outer_pad])
	if gm == null:
		gm = m._garment_cache.get("%s|%s|%.3f" % [m.look["gender"], key, 0.0])
	return (gm as ArrayMesh).get_aabb().position.y if gm is ArrayMesh else fallback


## (x, y) çevresinde en dış köşe: [konum, dış yön] ya da boş
static func _hit(c: Dictionary, x: float, y: float, front := true, rad := 0.028) -> Array:
	var V: PackedVector3Array = c["V"]
	var cell: Dictionary = c["cell"]
	var cx = floori(x / CELL)
	var cy = floori(y / CELL)
	var best = -1
	var bz = -99.0
	for ix in range(cx - 1, cx + 2):
		for iy in range(cy - 1, cy + 2):
			var l = cell.get(Vector2i(ix, iy))
			if l == null:
				continue
			for i in l:
				var q: Vector3 = V[i]
				if absf(q.x - x) < rad and absf(q.y - y) < rad:
					var z = q.z if front else -q.z
					if z > bz:
						bz = z
						best = i
	if best < 0:
		return []
	var s = 1.0 if front else -1.0
	var n: Vector3 = ((c["Nn"] as PackedVector3Array)[best] + Vector3.BACK * s * 0.8).normalized()
	return [Vector3(x, y, V[best].z), n]


## Yüzeye oturan sürekli bant; P, O (dış), W (yarım genişlik vektörü) noktaları
static func _band(c: Dictionary, P: Array, O: Array, W: Array, d: float, col: Color, closed := false) -> void:
	var n = P.size()
	if n < 2:
		return
	var m = c["m"]
	var sk: Dictionary = m._sk
	var base: int = (sk["ov"] as PackedVector3Array).size()
	for i in n:
		var p: Vector3 = P[i]
		var o: Vector3 = O[i]
		var w: Vector3 = W[i]
		var wn: Vector3 = w.normalized()
		var j: int = m._sk_nearest(p)
		var bo = sk["b"][j]
		var we = sk["w"][j]
		var quad = [[p + w + o * d, o], [p - w + o * d, o], [p + w, wn], [p + w + o * d, wn], [p - w + o * d, -wn], [p - w, -wn]]
		for q in quad:
			sk["ov"].append(q[0])
			sk["on"].append(q[1])
			sk["oc"].append(col)
			sk["ob"].append_array(bo)
			sk["ow"].append_array(we)
	var ov: PackedVector3Array = sk["ov"]
	var on: PackedVector3Array = sk["on"]
	for i in (n if closed else n - 1):
		var a = base + i * 6
		var b = base + ((i + 1) % n) * 6
		for f in 3:
			var a0 = a + f * 2
			var a1 = a0 + 1
			var b0 = b + f * 2
			var b1 = b0 + 1
			var fc: Vector3 = (ov[b0] - ov[a0]).cross(ov[b1] - ov[a0])
			if fc.dot(on[a0]) < 0.0:
				sk["oi"].append_array(PackedInt32Array([a0, b0, b1, a0, b1, a1]))
			else:
				sk["oi"].append_array(PackedInt32Array([a0, b1, b0, a0, a1, b1]))


static func _box(c: Dictionary, ctr: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	var m = c["m"]
	var sk: Dictionary = m._sk
	var j: int = m._sk_nearest(ctr)
	var faces = [[n, u, v], [-n, v, u], [u, v, n], [-u, n, v], [v, n, u], [-v, u, n]]
	for f in faces:
		var fn: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var base: int = (sk["ov"] as PackedVector3Array).size()
		var o: Vector3 = ctr + fn
		var q = [o - a - b, o - a + b, o + a + b, o + a - b]
		for p in q:
			sk["ov"].append(p)
			sk["on"].append(fn.normalized())
			sk["oc"].append(col)
			sk["ob"].append_array(sk["b"][j])
			sk["ow"].append_array(sk["w"][j])
		var t: Vector3 = (q[1] - q[0]).cross(q[2] - q[0])
		if t.dot(fn) < 0.0:
			sk["oi"].append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		else:
			sk["oi"].append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


## Ön / arka yüzde kırık çizgi şerit: pts [Vector2...]
static func _seam(c: Dictionary, pts: Array, w: float, d: float, col: Color, front := true, lift := 0.003, step := 0.024) -> void:
	var S := []
	var D := []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var cnt = maxi(1, int(a.distance_to(b) / step))
		var e: Vector2 = (b - a).normalized()
		for k in cnt + (1 if i == pts.size() - 2 else 0):
			S.append(a.lerp(b, float(k) / cnt))
			D.append(e)
	var runP := []
	var runO := []
	var runW := []
	for i in S.size():
		var p: Vector2 = S[i]
		var h = _hit(c, p.x, p.y, front)
		if h.is_empty():
			_flush(c, runP, runO, runW, d, col, front)
			runP = []
			runO = []
			runW = []
			continue
		var e: Vector2 = D[i]
		runP.append(h[0])
		runO.append(h[1])
		runW.append(Vector3(-e.y, e.x, 0.0) * w * 0.5)
	_flush(c, runP, runO, runW, d, col, front, lift)


static func _flush(c: Dictionary, P: Array, O: Array, W: Array, d: float, col: Color, front: bool, lift := 0.003) -> void:
	if P.size() < 2:
		return
	var s = 1.0 if front else -1.0
	var Q := []
	for i in P.size():   # derinlik: komşulardan öne yumuşat, bant kırılmasın
		var z = (P[i] as Vector3).z * s
		for j in [i - 1, i + 1]:
			if j >= 0 and j < P.size():
				z = maxf(z, (P[j] as Vector3).z * s - 0.005)
		var p: Vector3 = P[i]
		Q.append(Vector3(p.x, p.y, z * s) + (O[i] as Vector3) * lift)
	_band(c, Q, O, W, d, col)


## Y ekseninde halka; a=0 ön, +PI/2 karakterin solu (+X), PI arka. sx ile tek bacak.
static func _ring(c: Dictionary, y: float, h: float, d: float, col: Color, a0 := -PI, a1 := PI, lift := 0.003, sx := 0.0, rmax := 9.0, xl := 0.33) -> void:
	var r = _prof_y(c, y, sx, rmax, xl)
	if r.is_empty():
		return
	var ctr: Vector2 = r["c"]
	var rr: PackedFloat32Array = r["r"]
	var full = absf(a1 - a0) > TAU - 0.01
	var cnt = maxi(4, int(absf(a1 - a0) / TAU * rr.size()))
	var P := []
	var O := []
	var W := []
	for i in (cnt if full else cnt + 1):
		var a = lerpf(a0, a1, float(i) / cnt)
		var o = Vector3(sin(a), 0.0, cos(a))
		P.append(Vector3(ctr.x, y, ctr.y) + o * (_rad(rr, a) + lift))
		O.append(o)
		W.append(Vector3.UP * h * 0.5)
	_band(c, P, O, W, d, col, full)


## Kesit profili: merkez + açı başına en dış yarıçap
static func _prof_y(c: Dictionary, y: float, sx := 0.0, rmax := 9.0, xl := 0.33) -> Dictionary:
	var V: PackedVector3Array = c["V"]
	var rows: Dictionary = c["rows"]
	var ry = floori(y / ROW)
	var band := []
	var ctr = Vector2.ZERO
	for k in [ry - 1, ry, ry + 1]:
		var l = rows.get(k)
		if l == null:
			continue
		for i in l:
			var q: Vector3 = V[i]
			if absf(q.y - y) < 0.016 and absf(q.x) < xl and (sx == 0.0 or signf(q.x) == sx) and (rmax > 8.0 or Vector2(q.x, q.z).length() < rmax):
				band.append(q)
				ctr += Vector2(q.x, q.z)
	if band.size() < 6:
		return {}
	ctr /= band.size()
	if sx == 0.0:
		ctr.x = 0.0
	return {"c": ctr, "r": _bins(band, ctr, 0, 2)}


static func _bins(band: Array, ctr: Vector2, ia: int, ib: int) -> PackedFloat32Array:
	var n = 40
	var r := PackedFloat32Array()
	r.resize(n)
	r.fill(0.0)
	for q in band:
		var dx = float(q[ia]) - ctr.x
		var dz = float(q[ib]) - ctr.y
		var k = int(fposmod(atan2(dx, dz) / TAU, 1.0) * n) % n
		r[k] = maxf(r[k], sqrt(dx * dx + dz * dz))
	for _p in 2:
		var s := r.duplicate()
		for i in n:
			var a = s[posmod(i - 1, n)]
			var b = s[(i + 1) % n]
			if s[i] <= 0.0:
				r[i] = maxf(a, b)
			else:
				r[i] = maxf(s[i], (a + b) * 0.5 - 0.004)
	return r


static func _rad(r: PackedFloat32Array, a: float) -> float:
	var n = r.size()
	var t = fposmod(a / TAU * n - 0.5, float(n))
	var i = int(t) % n
	return lerpf(r[i], r[(i + 1) % n], t - floorf(t))


## Dış yüzeyde dikey hat (etek pilisi, yan dikiş); a açısında y0 -> y1
static func _mer(c: Dictionary, a: float, y0: float, y1: float, w: float, d: float, col: Color, sx := 0.0, lift := 0.003) -> void:
	var cnt = maxi(2, int(absf(y1 - y0) / 0.035))
	var o2 = Vector3(sin(a), 0.0, cos(a))
	var side = Vector3(cos(a), 0.0, -sin(a))
	var P := []
	var O := []
	var W := []
	for k in cnt + 1:
		var y = lerpf(y0, y1, float(k) / cnt)
		var r = _prof_y(c, y, sx)
		if r.is_empty():
			continue
		var ct: Vector2 = r["c"]
		P.append(Vector3(ct.x, y, ct.y) + o2 * (_rad(r["r"], a) + lift))
		O.append(o2)
		W.append(side * w * 0.5)
	_band(c, P, O, W, d, col)


## Kol halkası: t omuz (0) -> bilek (1)
static func _cuff(c: Dictionary, t: float, h: float, d: float, col: Color, lift := 0.003, only := 0.0) -> void:
	var x0 = lerpf(float(c["UA"]), float(c["HA"]) - 0.02, t)
	for sx in [-1.0, 1.0]:
		if only != 0.0 and sx != only:
			continue
		_ring_x(c, x0 * sx, h, d, col, lift)


static func _ring_x(c: Dictionary, x: float, h: float, d: float, col: Color, lift := 0.003) -> void:
	var V: PackedVector3Array = c["V"]
	var cols: Dictionary = c["cols"]
	var rx = floori(x / ROW)
	var band := []
	var ctr = Vector2.ZERO
	for k in [rx - 1, rx, rx + 1]:
		var l = cols.get(k)
		if l == null:
			continue
		for i in l:
			var q: Vector3 = V[i]
			if absf(q.x - x) < 0.016:
				band.append(q)
				ctr += Vector2(q.y, q.z)
	if band.size() < 6:
		return
	ctr /= band.size()
	var rr = _bins(band, ctr, 1, 2)
	var P := []
	var O := []
	var W := []
	var cnt = 22
	for i in cnt:
		var a = TAU * i / cnt
		var o = Vector3(0.0, sin(a), cos(a))
		P.append(Vector3(x, ctr.x, ctr.y) + o * (_rad(rr, a) + lift))
		O.append(o)
		W.append(Vector3.RIGHT * h * 0.5)
	_band(c, P, O, W, d, col, true)


## Yüzeye yaslı kutu; rot derece
static func _plate(c: Dictionary, x: float, y: float, w: float, h: float, d: float, col: Color, front := true, rot := 0.0, lift := 0.002) -> void:
	var t = _hit(c, x, y, front)
	if t.is_empty():
		return
	var n: Vector3 = t[1]
	var u: Vector3 = Vector3.UP.cross(n).normalized()
	var v: Vector3 = n.cross(u).normalized()
	if rot != 0.0:
		var r = deg_to_rad(rot)
		var u2 = u * cos(r) + v * sin(r)
		v = v * cos(r) - u * sin(r)
		u = u2
	_box(c, (t[0] as Vector3) + n * (lift + d * 0.5), u * w * 0.5, v * h * 0.5, n * d * 0.5, col)


static func _disc(c: Dictionary, x: float, y: float, r: float, d: float, col: Color, front := true) -> void:
	for k in 3:
		_plate(c, x, y, r * 1.72, r * 1.72, d, col, front, k * 30.0)


static func _star(c: Dictionary, x: float, y: float, r: float, d: float, col: Color, front := true) -> void:
	for k in 5:
		var a = deg_to_rad(90.0 + k * 72.0)
		_plate(c, x + cos(a) * r * 0.5, y + sin(a) * r * 0.5, r * 0.3, r * 1.0, d, col, front, k * 72.0)
	_disc(c, x, y, r * 0.3, d, col, front)


static func _btns(c: Dictionary, x: float, y0: float, y1: float, n: int, r: float, col: Color, front := true) -> void:
	for k in n:
		_disc(c, x, lerpf(y0, y1, float(k) / maxi(n - 1, 1)), r, 0.004, col, front)


## Dikiş: aralıklı küçük çizgiler
static func _stitch(c: Dictionary, a: Vector2, b: Vector2, n: int, col: Color, front := true, w := 0.0035) -> void:
	var e: Vector2 = b - a
	var ln = e.length() / n
	var rot = rad_to_deg(atan2(e.y, e.x))
	for k in n:
		var p = a.lerp(b, (k + 0.5) / n)
		_plate(c, p.x, p.y, ln * 0.58, w, 0.0016, col, front, rot if front else -rot, 0.0035)


static func _spiral(c: Dictionary, x: float, y: float, r: float, turns: float, w: float, col: Color, front := true) -> void:
	var pts := []
	var cnt = int(turns * 12.0)
	for k in cnt + 1:
		var t = float(k) / cnt
		var a = t * turns * TAU
		pts.append(Vector2(x + cos(a) * r * t, y + sin(a) * r * t))
	_seam(c, pts, w, 0.0025, col, front, 0.003, 0.012)


static func _glyph(c: Dictionary, cx: float, cy: float, s: float, strokes: Array, w: float, col: Color, front := true, lift := 0.003, thick := 0.002) -> void:
	for q in strokes:
		_seam(c, [Vector2(cx + q[0] * s, cy + q[1] * s), Vector2(cx + q[2] * s, cy + q[3] * s)], w, thick, col, front, lift, 0.016)


static func _dg(c: Dictionary, bone: String, root: Vector3, dir: Vector3, ln: float, w: float, col: Color, stiff := 0.2, side := Vector3.RIGHT, thick := 0.004) -> void:
	(c["dg"] as Array).append([bone, root, dir, ln, w, col, stiff, side, thick])


## Halkaya gömülü noktada kısa kutu (bacak / gövde yanı): çanta, toka
static func _side_box(c: Dictionary, y: float, a: float, sx: float, w: float, h: float, d: float, col: Color, lift := 0.003) -> void:
	var r = _prof_y(c, y, sx)
	if r.is_empty():
		return
	var ct: Vector2 = r["c"]
	var o = Vector3(sin(a), 0.0, cos(a))
	var t = Vector3(cos(a), 0.0, -sin(a))
	var p: Vector3 = Vector3(ct.x, y, ct.y) + o * (_rad(r["r"], a) + lift + d * 0.5)
	_box(c, p, t * w * 0.5, Vector3.UP * h * 0.5, o * d * 0.5, col)


# ------------------------------------------------------------------ ortak parçalar (oranlar set başına verilir)
static func _zip(c: Dictionary, y0: float, y1: float, col: Color, x := 0.0, w := 0.008) -> void:
	_seam(c, [Vector2(x, y0), Vector2(x, y1)], w, 0.003, col)
	_plate(c, x, y0 - 0.012, 0.012, 0.024, 0.004, col.lightened(0.15))


static func _belt(c: Dictionary, y: float, h: float, col: Color, buckle: Color, bw := 0.05) -> void:
	_ring(c, y, h, 0.006, col, -PI, PI, 0.004)
	_plate(c, 0.0, y, bw, h * 1.35, 0.006, buckle, true, 0.0, 0.009)
	_plate(c, 0.0, y, bw * 0.55, h * 0.62, 0.003, col, true, 0.0, 0.014)
	for a in [0.75, -0.75, 2.2, -2.2]:
		_side_box(c, y, a, 0.0, 0.014, h * 1.4, 0.005, col.darkened(0.2), 0.009)


static func _pouch(c: Dictionary, x: float, y: float, w: float, h: float, col: Color, flap: Color, front := true, btn := SILVER) -> void:
	_plate(c, x, y, w, h, 0.012, col, front)
	_plate(c, x, y + h * 0.3, w * 1.06, h * 0.42, 0.005, flap, front, 0.0, 0.015)
	_disc(c, x, y + h * 0.13, 0.0065, 0.004, btn, front)


## Uyluk kılıfı: iki kayış + cep
static func _holster(c: Dictionary, sx: float, y: float, band: Color, pouch: Color) -> void:
	if c["m"].look.get("holster") != false:
		return
	for dy in [0.05, -0.04]:
		_ring(c, y + dy, 0.026, 0.005, band, -PI, PI, 0.006, sx)
	var a = sx * 1.25
	_side_box(c, y, a, sx, 0.085, 0.11, 0.024, pouch, 0.012)
	_side_box(c, y + 0.034, a, sx, 0.09, 0.044, 0.008, pouch.lightened(0.1), 0.036)


static func _neck(c: Dictionary, dy: float, h: float, d: float, col: Color, rmax := 0.125, lift := 0.004) -> void:
	_ring(c, float(c["N"]) + dy, h, d, col, -PI, PI, lift, 0.0, rmax)


## Bacak bantları (sargı)
static func _wraps(c: Dictionary, sx: float, y0: float, y1: float, n: int, h: float, col: Color, lift := 0.005) -> void:
	var hh = maxf(h, absf(y1 - y0) / maxi(n - 1, 1) * 0.94) if n > 1 else h
	for k in n:
		_ring(c, lerpf(y0, y1, float(k) / maxi(n - 1, 1)), hh, 0.004, col.darkened(0.04 * (k % 2)), -PI, PI, lift, sx)


static func _arm_wraps(c: Dictionary, t0: float, t1: float, n: int, h: float, col: Color, only := 0.0) -> void:
	var span = absf(t1 - t0) * (float(c["HA"]) - 0.02 - float(c["UA"]))
	var hh = maxf(h, span / maxi(n - 1, 1) * 0.94) if n > 1 else h
	for k in n:
		_cuff(c, lerpf(t0, t1, float(k) / maxi(n - 1, 1)), hh, 0.004, col.darkened(0.05 * (k % 2)), 0.004, only)


## Etek / palto ucunda diş diş sarkan kırık kenar (alev, yırtık)
static func _teeth(c: Dictionary, y: float, n: int, ln: float, w: float, col: Color, a0 := -PI, a1 := PI, seed0 := 1.0) -> void:
	var r = _prof_y(c, y)
	if r.is_empty():
		return
	var ct: Vector2 = r["c"]
	for k in n:
		var a = lerpf(a0, a1, (k + 0.5) / n)
		var o = Vector3(sin(a), 0.0, cos(a))
		var t = Vector3(cos(a), 0.0, -sin(a))
		var q = 0.55 + 0.45 * absf(sin(k * 2.4 + seed0))
		var rd: float = _rad(r["r"], a) + 0.006
		for j in 3:
			var f = j / 3.0
			var w2 = w * (1.0 - f * 0.72)
			var yy = y - ln * q * (f + 0.17)
			_box(c, Vector3(ct.x, yy, ct.y) + o * rd, t * w2 * 0.5, Vector3.UP * ln * q * 0.18, o * 0.002, col)


# ------------------------------------------------------------------ setler
static func _acik_ceket(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var jean = K("3a68b0")
	_belt(c, h + 0.035, 0.03, K("1e3a70"), SILVER, 0.04)
	_seam(c, [Vector2(0.0, h + 0.02), Vector2(0.0, h - 0.07)], 0.006, 0.002, jean.darkened(0.3))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.13, h + 0.015), Vector2(s * 0.085, h - 0.035), Vector2(s * 0.05, h + 0.015)], 0.005, 0.002, jean.lightened(0.2))
		_disc(c, s * 0.115, h + 0.005, 0.005, 0.003, GOLD)
		_plate(c, s * 0.085, h - 0.04, 0.07, 0.075, 0.003, jean.darkened(0.08), false)
		_ring(c, kn + 0.03, 0.03, 0.005, K("2a2c60"), -PI, PI, 0.004, s)
		_ring(c, an + 0.075, 0.012, 0.004, K("18181c"), -PI, PI, 0.006, s)
		_ring(c, an + 0.12, 0.012, 0.004, K("18181c"), -PI, PI, 0.006, s)
		_mer(c, s * 0.62, n - 0.08, h - 0.02, 0.016, 0.003, K("f2f2f4"))
		_seam(c, [Vector2(s * 0.03, n - 0.06), Vector2(s * 0.075, ch - 0.02)], 0.006, 0.002, K("18181c"))
	_ring(c, ch - 0.05, 0.012, 0.003, K("18181c"), -0.55, 0.55, 0.002)
	_cuff(c, 0.93, 0.03, 0.005, K("a8a0e0"))


static func _algi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var lav = K("b8a0d8")
	var grey = K("b4b8bc")
	_zip(c, n - 0.03, h + 0.11, K("8870b0"))
	_neck(c, 0.0, 0.04, 0.008, lav.lightened(0.1))
	_belt(c, h + 0.095, 0.04, grey, K("d0d4d8"), 0.075)
	_pouch(c, 0.0, h + 0.075, 0.15, 0.09, grey, grey.darkened(0.15), false, K("8a8e94"))
	_cuff(c, 0.9, 0.035, 0.005, lav.darkened(0.14))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.075, n - 0.13), Vector2(s * 0.085, h + 0.13)], 0.004, 0.002, lav.darkened(0.2))
		_ring(c, kn + 0.17, 0.022, 0.004, K("2a2420"), -PI, PI, 0.004, s)
		_ring(c, an + 0.1, 0.014, 0.004, K("18181c"), -PI, PI, 0.006, s)


static func _alti_yol(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]; var ch: float = c["C"]
	var line = K("c8c8da")
	_neck(c, 0.015, 0.012, 0.004, line)
	_seam(c, [Vector2(0.0, n - 0.03), Vector2(0.0, ch - 0.1)], 0.005, 0.002, line)
	_seam(c, [Vector2(0.0, h + 0.06), Vector2(0.0, an + 0.14)], 0.005, 0.002, line)
	var by = _hem(c, "rikudo_cubbe", an + 0.06) + 0.055
	_ring(c, by, 0.014, 0.003, line, -PI, PI, 0.004)
	_ring(c, by + 0.03, 0.006, 0.002, K("1e2a60"), -PI, PI, 0.004)
	for k in 12:
		_mer(c, -PI + (k + 0.5) * TAU / 12.0, h - 0.05, by + 0.05, 0.004, 0.002, line)
	_cuff(c, 0.82, 0.012, 0.003, K("1e2a60"))
	_stitch(c, Vector2(-0.13, h + 0.2), Vector2(0.13, h + 0.2), 14, K("eeeef2"))


const G_ROKU := [[0.0, 0.9, 0.1, 0.6], [-0.85, 0.35, 0.85, 0.35], [-0.35, 0.05, -0.7, -0.8], [0.35, 0.05, 0.75, -0.8]]
const G_DAI := [[-0.45, 0.9, -0.85, 0.1], [-0.6, 0.35, -0.6, -0.9], [-0.25, 0.25, 0.9, 0.45], [0.2, 0.9, 0.75, -0.75], [0.45, 0.75, 0.7, 0.6]]
const G_ME := [[-0.6, 0.9, 0.6, 0.9], [-0.6, 0.9, -0.6, -0.9], [0.6, 0.9, 0.6, -0.9], [-0.6, -0.9, 0.6, -0.9], [-0.6, 0.3, 0.6, 0.3], [-0.6, -0.3, 0.6, -0.3]]
const G_HI := [[-0.7, 0.35, -0.45, -0.05], [0.7, 0.35, 0.45, -0.05], [0.0, 0.9, 0.0, 0.15], [0.0, 0.15, -0.8, -0.85], [0.0, 0.15, 0.8, -0.85]]
const G_KAGE := [[-0.85, 0.85, -0.05, 0.85], [-0.85, 0.85, -0.85, 0.45], [-0.05, 0.85, -0.05, 0.45], [-0.85, 0.45, -0.05, 0.45], [-0.95, 0.25, 0.05, 0.25], [-0.7, 0.05, -0.2, 0.05], [-0.7, -0.25, -0.2, -0.25], [-0.45, -0.25, -0.45, -0.9], [0.75, 0.8, 0.2, 0.4], [0.85, 0.35, 0.2, -0.05], [0.9, -0.1, 0.15, -0.7]]


static func _altinci(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var red = K("b02428")
	var i = 0
	for g in [G_ROKU, G_DAI, G_ME, G_HI, G_KAGE]:
		_glyph(c, 0.0, h + 0.1 - i * 0.105, 0.043, g, 0.0085, red, false, 0.011, 0.004)
		i += 1
	var edge = K("c4c6c8")
	_seam(c, [Vector2(0.018, n - 0.16), Vector2(0.09, h + 0.06), Vector2(0.1, an + 0.13)], 0.006, 0.002, edge)
	_neck(c, 0.03, 0.012, 0.004, edge)
	_neck(c, -0.02, 0.012, 0.004, edge)
	var by = _hem(c, "rokudaime_cubbe", an + 0.08) + 0.04
	_ring(c, by, 0.012, 0.003, edge)
	_cuff(c, 0.8, 0.014, 0.003, edge)


static func _anbu_kapuson(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var ch: float = c["C"]
	var cr = K("cfcab8")
	_seam(c, [Vector2(0.0, n - 0.1), Vector2(0.0, kn + 0.13)], 0.005, 0.002, cr.darkened(0.18))
	_btns(c, 0.016, ch + 0.03, h + 0.0, 5, 0.008, cr.darkened(0.3))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.13, h + 0.0), Vector2(s * 0.065, h - 0.04)], 0.01, 0.003, cr.darkened(0.12))
		_seam(c, [Vector2(s * 0.09, ch + 0.08), Vector2(s * 0.11, h + 0.07)], 0.004, 0.002, cr.darkened(0.14))
		_seam(c, [Vector2(s * 0.09, n - 0.1), Vector2(s * 0.11, h + 0.03)], 0.004, 0.002, cr.darkened(0.14), false)
	_cuff(c, 0.9, 0.03, 0.004, cr.darkened(0.1))
	_cuff(c, 0.84, 0.006, 0.003, cr.darkened(0.25))


static func _keiko(c: Dictionary, blue: Color, white: Color, lining: Color) -> void:
	var h: float = c["H"]; var an: float = c["A"]; var n: float = c["N"]
	var top = h + 0.15
	for k in 14:
		var a = -PI + (k + 0.5) * TAU / 14.0
		_mer(c, a, top - 0.04, an + 0.16, 0.007, 0.004, blue.darkened(0.22))
	_ring(c, top, 0.05, 0.007, blue.darkened(0.12), -PI, PI, 0.005)
	_plate(c, 0.0, top + 0.002, 0.13, 0.06, 0.008, blue.lightened(0.08), true, 0.0, 0.01)   # önde düğüm
	_plate(c, 0.0, top + 0.002, 0.03, 0.074, 0.01, blue.darkened(0.25), true, 0.0, 0.014)
	_plate(c, 0.0, top + 0.02, 0.15, 0.1, 0.008, blue.lightened(0.05), false, 0.0, 0.008)   # koshi-ita
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.015, n - 0.03), Vector2(s * 0.09, n - 0.2)], 0.016, 0.003, lining)
		_dg(c, "Hips", Vector3(s * 0.055, top - 0.03, 0.14), Vector3(s * 0.08, -1.0, 0.1), 0.2, 0.03, blue.lightened(0.05), 0.3)
	_stitch(c, Vector2(-0.07, top + 0.052), Vector2(0.07, top + 0.052), 9, white, false)


static func _geishun(c: Dictionary) -> void:
	var h: float = c["H"]; var n: float = c["N"]; var kn: float = c["Kn"]
	var red = K("b01820")
	var top = h + 0.1
	for k in 18:
		_mer(c, -PI + (k + 0.5) * TAU / 18.0, top - 0.02, kn + 0.17, 0.006, 0.004, red.darkened(0.25))
	_ring(c, top + 0.01, 0.036, 0.006, red.darkened(0.1), -PI, PI, 0.005)
	for s in [-1.0, 1.0]:
		_plate(c, s * 0.05, top - 0.005, 0.085, 0.05, 0.012, red, true, s * 14.0, 0.008)
		_seam(c, [Vector2(s * 0.015, n - 0.03), Vector2(s * 0.09, n - 0.2)], 0.015, 0.003, red)
		_dg(c, "Hips", Vector3(s * 0.016, top - 0.03, 0.15), Vector3(s * 0.2, -1.0, 0.1), 0.16, 0.028, red, 0.3)
	_plate(c, 0.0, top - 0.005, 0.03, 0.04, 0.016, red.darkened(0.2), true, 0.0, 0.012)


static func _ates_pelerin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]
	var grey = K("9a9ca4")
	var blue = K("24408a")
	_belt(c, h + 0.05, 0.036, blue, SILVER, 0.045)
	for s in [-1.0, 1.0]:
		_side_box(c, h + 0.015, s * 1.1, 0.0, 0.065, 0.08, 0.026, K("2a2a30"), 0.01)
		_side_box(c, h + 0.044, s * 1.1, 0.0, 0.07, 0.03, 0.006, blue.darkened(0.15), 0.036)
		_ring(c, kn + 0.0, 0.03, 0.006, K("24242a"), -PI, PI, 0.005, s)
	_neck(c, 0.02, 0.06, 0.01, K("1c1c20"))
	_seam(c, [Vector2(0.0, n - 0.04), Vector2(0.0, ch + 0.06)], 0.012, 0.003, grey)
	_glyph(c, 0.0, ch + 0.03, 0.05, G_HI, 0.011, K("c43020"), false)
	_arm_wraps(c, 0.62, 0.9, 3, 0.012, K("6a7468"), -1.0)


static func _ay_cubbe(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var an: float = c["A"]
	var trim = K("b8b48a")
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.038, n - 0.02), Vector2(s * 0.058, ch - 0.1), Vector2(s * 0.085, h + 0.02)], 0.022, 0.003, trim)
		_seam(c, [Vector2(s * 0.13, h - 0.03), Vector2(s * 0.15, an + 0.17)], 0.005, 0.002, trim.darkened(0.15))
	_stitch(c, Vector2(0.09, n - 0.09), Vector2(-0.1, h + 0.04), 20, K("e4e2cc"))
	_cuff(c, 0.85, 0.02, 0.004, trim)


static func _stitches(c: Dictionary, pts: Array, col: Color, front := true) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		_seam(c, [a, b], 0.0035, 0.0015, col, front, 0.002, 0.012)
		var e: Vector2 = (b - a).normalized()
		var nr = Vector2(-e.y, e.x)
		for k in int(a.distance_to(b) / 0.022):
			var p = a + e * (k + 0.5) * 0.022
			_seam(c, [p - nr * 0.011, p + nr * 0.011], 0.0028, 0.0015, col, front, 0.002, 0.008)


static func _bes_kalp(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var ink = K("141418")
	_arm_wraps(c, 0.1, 0.1, 1, 0.006, ink)
	_arm_wraps(c, 0.38, 0.38, 1, 0.006, ink)
	_arm_wraps(c, 0.66, 0.66, 1, 0.006, ink)
	_arm_wraps(c, 0.92, 0.92, 1, 0.006, ink)
	_stitches(c, [Vector2(-0.13, n - 0.11), Vector2(-0.05, n - 0.13)], ink)
	_stitches(c, [Vector2(0.13, n - 0.11), Vector2(0.05, n - 0.13)], ink)
	_belt(c, h + 0.06, 0.05, K("e8e8ea"), K("c8c8cc"), 0.07)
	for k in 2:
		_neck(c, -0.012 + k * 0.03, 0.03, 0.014, K("8a8c92").lightened(k * 0.05), 0.14, 0.012)
	for s in [-1.0, 1.0]:
		_wraps(c, s, kn - 0.06, an + 0.08, 6, 0.024, K("e8e8ea"))
		for y0 in [h + 0.18, h + 0.33]:
			_disc(c, s * 0.055, n - (h + 0.42 - y0), 0.03, 0.004, K("e6e6e0"), false)


static func _bilge_palto(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var ch: float = c["C"]
	var red = K("a82228")
	var by = _hem(c, "hokage_haori", kn - 0.02)
	_ring(c, by + 0.03, 0.05, 0.003, K("1c1c20"), -PI, PI, 0.004)
	_teeth(c, by + 0.11, 20, 0.11, 0.05, K("1c1c20"))
	_zip(c, n - 0.04, h + 0.02, K("1c1c24"))
	_neck(c, 0.0, 0.04, 0.008, K("1c1c24"))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.1, n - 0.03), Vector2(s * 0.12, kn + 0.08)], 0.012, 0.003, red.darkened(0.25))
		_wraps(c, s, c["A"] + 0.13, c["A"] + 0.06, 3, 0.018, K("1c1c20"))


static func _buhar_zirh(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var grey = K("6e7078")
	var black = K("18181c")
	var red = K("7e1c30")
	_belt(c, h + 0.08, 0.05, black, K("3a3a40"), 0.06)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.03, n - 0.05), Vector2(s * 0.085, h + 0.12)], 0.04, 0.005, black)
		_dg(c, "Hips", Vector3(s * 0.04, h + 0.05, 0.145), Vector3(s * 0.1, -1.0, 0.05), 0.2, 0.03, black, 0.28)
		_ring(c, an + 0.12, 0.02, 0.005, grey.darkened(0.3), -PI, PI, 0.006, s)
		_wraps(c, s, kn - 0.02, kn - 0.14, 3, 0.012, grey.darkened(0.2))
	for k in 20:
		_mer(c, -PI + (k + 0.5) * TAU / 20.0, h + 0.03, h - 0.13, 0.005, 0.003, red.darkened(0.3))
	for k in 5:
		_ring(c, n - 0.0 - k * 0.022, 0.006, 0.004, red.darkened(0.25), -PI, PI, 0.004, 0.0, 0.13)
	_stitch(c, Vector2(-0.14, ch - 0.14), Vector2(0.14, ch - 0.14), 14, K("a0a2a8"), false)
	_cuff(c, 0.45, 0.012, 0.004, black)


static func _bulut(c: Dictionary, trim: Color, belt: Color, wrap_c: Color, kind: int) -> void:
	var h: float = c["H"]; var kn: float = c["Kn"]; var ch: float = c["C"]; var n: float = c["N"]; var an: float = c["A"]
	# ref: etekte önde çapraz biyeler + dikey kenar
	var top = ch - 0.1
	var bot = kn + 0.02
	if kind == 0:
		_seam(c, [Vector2(-0.15, h + 0.0), Vector2(0.0, h - 0.17), Vector2(0.17, bot + 0.02)], 0.012, 0.004, trim)
		_seam(c, [Vector2(0.0, h - 0.17), Vector2(-0.17, bot + 0.02)], 0.012, 0.004, trim)
	_ring(c, top - 0.035, 0.012, 0.003, trim, -PI, PI, 0.004)
	_ring(c, top + 0.03, 0.03, 0.005, belt, -PI, PI, 0.004)
	_plate(c, 0.0, top + 0.03, 0.04, 0.042, 0.004, trim, true, 0.0, 0.009)
	_stitch(c, Vector2(-0.13, top - 0.012), Vector2(0.13, top - 0.012), 12, trim)
	for k in 2:
		_neck(c, -0.018 + k * 0.03, 0.028, 0.012, trim.darkened(k * 0.06), 0.14, 0.008)
	_arm_wraps(c, 0.62, 0.92, 4, 0.016, wrap_c)
	for s in [-1.0, 1.0]:
		_wraps(c, s, kn - 0.12, an + 0.14, 4, 0.02, wrap_c)
	_dg(c, "UpperChest", Vector3(0.05, n - 0.03, -0.1), Vector3(0.14, -1.0, -0.2), 0.22, 0.05, trim, 0.2)
	if kind == 1:
		_stitch(c, Vector2(-0.14, top + 0.05), Vector2(0.14, top + 0.05), 12, K("c8e8d8"))


static func _buz_kimono(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var an: float = c["A"]
	var brown = K("6a4428")
	var white = K("eeeef0")
	_ring(c, h + 0.09, 0.075, 0.009, brown, -PI, PI, 0.004)
	_ring(c, h + 0.09, 0.012, 0.003, brown.darkened(0.3), -PI, PI, 0.0135)
	_plate(c, 0.03, h + 0.09, 0.075, 0.03, 0.01, brown.lightened(0.1), true, 12.0, 0.013)
	_dg(c, "Hips", Vector3(0.07, h + 0.07, 0.15), Vector3(0.1, -1.0, 0.05), 0.2, 0.05, brown, 0.3)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.02, n - 0.04), Vector2(s * 0.06, ch - 0.02), Vector2(s * 0.07, h + 0.14)], 0.024, 0.004, white)
	for k in 7:
		_ring(c, n + 0.02 - k * 0.018, 0.005, 0.003, K("4a4440"), -PI, PI, 0.004, 0.0, 0.12)
	for k in 16:
		_mer(c, -PI + (k + 0.5) * TAU / 16.0, h - 0.08, an + 0.14, 0.004, 0.002, K("55555c"))


static func _buz_kimono2(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var sw = K("5a3a6e")
	for q in [[0.1, h - 0.1], [-0.09, h - 0.2], [0.07, h - 0.32], [-0.11, h - 0.04], [0.0, kn + 0.08], [0.12, n - 0.2]]:
		_spiral(c, q[0], q[1], 0.03, 1.7, 0.0065, sw)
		_spiral(c, -float(q[0]) * 0.9, q[1] - 0.03, 0.03, 1.7, 0.0065, sw, false)
	_ring(c, h + 0.09, 0.008, 0.003, K("d8d0c8"), -PI, PI, 0.012)
	_plate(c, 0.0, h + 0.09, 0.05, 0.06, 0.008, K("efe8e0"), false, 0.0, 0.012)


static func _delta(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var blue = K("74989e")
	var white = K("f0f0f2")
	_zip(c, ch - 0.08, h - 0.09, K("d8dce0"), 0.0, 0.006)
	_neck(c, 0.03, 0.04, 0.008, blue.lightened(0.1))
	_cuff(c, 0.92, 0.05, 0.007, white)
	_cuff(c, 0.82, 0.014, 0.008, blue.darkened(0.2))
	for s in [-1.0, 1.0]:
		_ring(c, kn + 0.105, 0.024, 0.005, white.darkened(0.06), -PI, PI, 0.003, s)
		_seam(c, [Vector2(s * 0.09, ch + 0.0), Vector2(s * 0.12, h + 0.0)], 0.004, 0.002, blue.darkened(0.2))


static func _demir_dovme(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var ch: float = c["C"]
	var white = K("eeeeec")
	var red = K("a82028")
	for k in 3:
		_neck(c, -0.022 + k * 0.024, 0.03, 0.016, white.darkened(k * 0.05), 0.15, 0.014)
	_dg(c, "UpperChest", Vector3(-0.03, n - 0.03, -0.13), Vector3(-0.1, -1.0, -0.12), 0.3, 0.09, white, 0.18)
	_dg(c, "UpperChest", Vector3(0.05, n - 0.03, -0.125), Vector3(0.14, -1.0, -0.12), 0.22, 0.07, white.darkened(0.05), 0.18)
	_disc(c, -float(c["UA"]) - 0.03, n - 0.04, 0.03, 0.002, K("2a4a9a"))   # omuzda 鉄 dövmesinin yeri
	_cuff(c, 0.97, 0.018, 0.006, red)
	_plate(c, 0.0, h + 0.03, 0.05, 0.05, 0.006, SILVER, true, 45.0, 0.012)
	for s in [-1.0, 1.0]:
		_side_box(c, kn + 0.0, s * 1.5, s, 0.05, 0.06, 0.008, K("c8c8cc"), 0.012)


static func _demir_kum(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var fur = K("24242c")
	var r = _prof_y(c, n - 0.02, 0.0, 0.17)
	if not r.is_empty():
		var ct: Vector2 = r["c"]
		for lay in 3:
			var cnt = 22 + lay * 3
			for k in cnt:
				var a = TAU * (k + lay * 0.5) / cnt
				var o = Vector3(sin(a), 0.0, cos(a))
				var t = Vector3(cos(a), 0.0, -sin(a))
				var rd: float = _rad(r["r"], a) + 0.03 + lay * 0.018
				var q = 0.7 + 0.3 * absf(sin(k * 1.7 + lay))
				var up: Vector3 = (Vector3.UP * (0.7 - lay * 0.5) + o * 0.55).normalized()
				_box(c, Vector3(ct.x, n + 0.02 - lay * 0.03, ct.y) + o * rd, t * 0.018, up * 0.045 * q, up.cross(t).normalized() * 0.008, fur.lightened(0.04 * (k % 3)))
	var by = _hem(c, "savas_cubbe", an + 0.09)
	_teeth(c, by + 0.03, 34, 0.045, 0.028, K("16161a"))
	_seam(c, [Vector2(0.0, n - 0.12), Vector2(0.0, h + 0.03)], 0.005, 0.002, K("34343c"))
	_plate(c, 0.0, n - 0.2, 0.06, 0.09, 0.008, K("6a5038"))
	_cuff(c, 0.86, 0.012, 0.003, K("2a2a32"))


static func _denki(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]
	var blue = K("2a5ab8")
	var lb = K("8ac4e8")
	_belt(c, h + 0.055, 0.035, K("18181c"), SILVER, 0.05)
	_seam(c, [Vector2(0.0, n - 0.08), Vector2(0.0, h + 0.08)], 0.016, 0.003, blue.darkened(0.14))
	_btns(c, 0.0, ch + 0.0, h + 0.1, 4, 0.0065, blue.lightened(0.3))
	for s in [-1.0, 1.0]:
		_pouch(c, s * 0.08, ch + 0.01, 0.075, 0.075, blue.lightened(0.05), blue.darkened(0.1), true, K("e0e4ea"))
		_ring(c, kn - 0.0, 0.03, 0.006, blue.darkened(0.12), -PI, PI, 0.006, s)
	_seam(c, [Vector2(-0.07, n - 0.02), Vector2(0.0, n - 0.14), Vector2(0.07, n - 0.02)], 0.03, 0.005, lb)
	_plate(c, 0.0, n - 0.15, 0.03, 0.03, 0.008, lb.darkened(0.1), true, 45.0, 0.006)
	_dg(c, "UpperChest", Vector3(-0.015, n - 0.17, 0.13), Vector3(-0.15, -1.0, 0.1), 0.09, 0.035, lb, 0.35)
	_dg(c, "UpperChest", Vector3(0.015, n - 0.17, 0.13), Vector3(0.15, -1.0, 0.1), 0.09, 0.035, lb, 0.35)
	_holster(c, -1.0, h - 0.18, K("f0f0f0"), K("1c2a58"))
	_cuff(c, 0.32, 0.03, 0.006, blue.darkened(0.12))
	_disc(c, 0.0, ch + 0.06, 0.03, 0.003, lb, false)


static func _esofman(c: Dictionary, acc: Color, stripe: float, holster: bool) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var blk = K("24242a")
	for s in [-1.0, 1.0]:
		_mer(c, s * 0.42, n - 0.04, h + 0.0, 0.016, 0.004, acc)
		_mer(c, s * 0.5, n - 0.04, h + 0.0, 0.01, 0.003, blk)
		_mer(c, s * 1.57, h - 0.03, kn - 0.04, stripe * 0.1, 0.003, acc, s)
		_ring(c, an + 0.14, 0.026, 0.005, acc, -PI, PI, 0.006, s)
	_neck(c, 0.0, 0.04, 0.008, acc.darkened(0.12))
	_cuff(c, 0.95, 0.034, 0.005, blk)
	_ring(c, h - 0.0, 0.04, 0.005, blk, -PI, PI, 0.004)
	_seam(c, [Vector2(-0.015, n - 0.11), Vector2(0.015, n - 0.11)], 0.004, 0.002, K("18181c"))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.12, h + 0.09), Vector2(s * 0.085, h + 0.04)], 0.008, 0.003, blk)
	if holster:
		_holster(c, -1.0, h - 0.17, K("f0f0f0"), K("1c2a58"))


static func _turuncu2(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var org = K("e8906a")
	var blk = K("24242a")
	for s in [-1.0, 1.0]:
		_mer(c, s * 0.58, n - 0.04, h - 0.04, 0.014, 0.004, blk)
		_seam(c, [Vector2(s * 0.14, h + 0.08), Vector2(s * 0.1, h + 0.0)], 0.009, 0.003, blk)
		_mer(c, s * 1.57, h - 0.06, an + 0.15, 0.016, 0.003, org, s)
		_ring(c, an + 0.12, 0.05, 0.005, K("2e2e34"), -PI, PI, 0.006, s)
		_seam(c, [Vector2(s * 0.015, h + 0.03), Vector2(s * 0.025, h - 0.1)], 0.006, 0.003, K("f2f2f0"))
	_ring(c, h + 0.035, 0.04, 0.005, K("4a4a52"), -PI, PI, 0.004)
	_cuff(c, 0.95, 0.04, 0.005, blk)
	_ring(c, h - 0.045, 0.03, 0.005, blk, -PI, PI, 0.006)


static func _esofman_yirtik(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var red = K("c42232")
	_belt(c, h + 0.045, 0.03, K("6a4428"), K("a08858"), 0.04)
	_neck(c, 0.0, 0.04, 0.008, red.darkened(0.15))
	for s in [-1.0, 1.0]:
		_mer(c, s * 0.46, n - 0.05, h + 0.05, 0.01, 0.003, red)
		_ring(c, an + 0.2, 0.012, 0.004, K("24242a"), -PI, PI, 0.006, s)
	_teeth(c, h + 0.02, 18, 0.05, 0.03, K("18181c"), 0.5, TAU - 0.5, 2.0)
	_cuff(c, 0.97, 0.02, 0.004, red)


static func _flut(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var pink = K("e8d4d8")
	var ink = K("2a2428")
	# önde yin-yang (ref: tuniğin alt yarısı)
	var cx = 0.0
	var cy = h - 0.13
	var R = 0.058
	_disc(c, cx, cy, R, 0.002, K("f4f0f0"))
	var ar := []
	for k in 25:
		var a = TAU * k / 24.0
		ar.append(Vector2(cx + cos(a) * R, cy + sin(a) * R))
	_seam(c, ar, 0.005, 0.0025, ink, true, 0.005, 0.012)
	var sc := []
	for k in 9:
		var a = PI * 0.5 + PI * k / 8.0
		sc.append(Vector2(cx + cos(a) * R * 0.5, cy + R * 0.5 + sin(a) * R * 0.5))
	for k in range(1, 9):
		var a = PI * 0.5 - PI * k / 8.0
		sc.append(Vector2(cx + cos(a) * R * 0.5, cy - R * 0.5 + sin(a) * R * 0.5))
	_seam(c, sc, 0.005, 0.0025, ink, true, 0.005, 0.01)
	_disc(c, cx, cy + R * 0.5, 0.009, 0.003, ink)
	_disc(c, cx, cy - R * 0.5, 0.009, 0.003, ink)
	_neck(c, 0.0, 0.016, 0.004, pink.darkened(0.2))
	_cuff(c, 0.28, 0.014, 0.004, pink.darkened(0.2))
	for s in [-1.0, 1.0]:
		_wraps(c, s, kn + 0.02, an + 0.1, 7, 0.022, WRAP)
	_cuff(c, 0.62, 0.012, 0.004, K("3a3a42"))
	_cuff(c, 0.93, 0.012, 0.004, K("3a3a42"))


static func _gelinlik(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var an: float = c["A"]
	var d = K("2a1e34")
	var lt = K("4a3a56")
	var waist = h + 0.1
	# belde kat kat fırfır (peplum)
	for lay in 2:
		var cnt = 34
		var r = _prof_y(c, waist - lay * 0.035)
		if r.is_empty():
			continue
		var ct: Vector2 = r["c"]
		for k in cnt:
			var a = TAU * k / cnt
			var o = Vector3(sin(a), 0.0, cos(a))
			var t = Vector3(cos(a), 0.0, -sin(a))
			var rd: float = _rad(r["r"], a) + 0.012 + lay * 0.012
			var dn: Vector3 = (Vector3.DOWN + o * 0.4).normalized()
			_box(c, Vector3(ct.x, waist - lay * 0.035, ct.y) + o * rd + dn * 0.05, t * 0.016, dn * 0.055, dn.cross(t).normalized() * 0.003, (lt if k % 2 == 0 else d).darkened(lay * 0.08))
	_ring(c, waist + 0.03, 0.03, 0.006, lt, -PI, PI, 0.006)
	# ön pli paneli: ortada açık şeritler
	for k in 7:
		var x = (k - 3) * 0.024
		_seam(c, [Vector2(x * 0.7, waist - 0.07), Vector2(x * 2.2, an + 0.12)], 0.011 if k % 2 == 0 else 0.006, 0.004, lt if k % 2 == 0 else d.lightened(0.1))
	for k in 16:
		_mer(c, 1.0 + k * (TAU - 2.0) / 15.0, waist - 0.12, an + 0.14, 0.005, 0.003, d.darkened(0.2))
	_neck(c, -0.01, 0.024, 0.006, d.lightened(0.08))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.03, n - 0.02), Vector2(s * 0.075, ch + 0.0)], 0.012, 0.003, lt)
	_cuff(c, 0.2, 0.014, 0.004, lt)


static func _genc_canavar(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var org = K("e8842a")
	var grn = K("1e4a2a")
	for k in 4:
		_neck(c, -0.04 + k * 0.024, 0.03, 0.018, org.darkened(0.07 * (k % 2)), 0.15, 0.014)
	_belt(c, h + 0.05, 0.03, K("c43020"), GOLD, 0.05)
	_seam(c, [Vector2(0.0, n - 0.09), Vector2(0.0, h + 0.03)], 0.006, 0.003, grn.lightened(0.15))
	_arm_wraps(c, 0.42, 0.95, 9, 0.022, WRAP)
	for s in [-1.0, 1.0]:
		for y in [kn - 0.03, an + 0.12]:
			_ring(c, y, 0.016, 0.004, org.darkened(0.3), -PI, PI, 0.03, s)
	_stitch(c, Vector2(-0.12, n - 0.08), Vector2(-0.14, h + 0.08), 12, grn.lightened(0.2))
	_stitch(c, Vector2(0.12, n - 0.08), Vector2(0.14, h + 0.08), 12, grn.lightened(0.2))


static func _genclik(c: Dictionary, acc: Color, pant: Color, seam_c: Color, boot: Color) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var wht = K("f0f0ee")
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.022, n - 0.06), Vector2(s * 0.03, n - 0.2)], 0.005, 0.004, wht)
		_plate(c, s * 0.03, n - 0.21, 0.01, 0.018, 0.006, acc)
		_mer(c, s * 1.57, h - 0.04, kn + 0.02, 0.008, 0.003, seam_c, s)
		_side_box(c, h - 0.2, s * 1.2, s, 0.085, 0.09, 0.016, pant.darkened(0.08), 0.004)
		_side_box(c, h - 0.17, s * 1.2, s, 0.09, 0.03, 0.005, seam_c, 0.02)
		_ring(c, an + 0.2, 0.024, 0.005, pant.darkened(0.12), -PI, PI, 0.012, s)
		_ring(c, an + 0.1, 0.012, 0.005, boot.lightened(0.15), -PI, PI, 0.012, s)
	_seam(c, [Vector2(-0.1, h + 0.02), Vector2(0.1, h + 0.02)], 0.004, 0.002, K("3a3a42"))
	_cuff(c, 0.42, 0.024, 0.004, K("3a3a42"))
	_cuff(c, 0.9, 0.05, 0.006, acc, 0.004, -1.0)
	_holster(c, -1.0, h - 0.09, K("3a2c20"), K("1c2a58"))


static func _genis_yaka(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var bk = K("262a38")
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.02, n - 0.1), Vector2(s * 0.095, n - 0.015)], 0.042, 0.006, bk)
		_ring(c, an + 0.17, 0.05, 0.005, K("cfc8b0"), -PI, PI, 0.005, s)
		_ring(c, an + 0.1, 0.018, 0.005, K("3a8a58"), -PI, PI, 0.008, s)
	var chain := []
	for k in 15:
		var a = lerpf(-1.25, 1.25, k / 14.0)
		chain.append(Vector2(sin(a) * 0.075, n - 0.075 - cos(a) * 0.065))
	_seam(c, chain, 0.0055, 0.004, GOLD, true, 0.006, 0.012)
	_plate(c, 0.0, n - 0.15, 0.02, 0.026, 0.005, GOLD, true, 45.0, 0.007)
	_ring(c, h + 0.0, 0.03, 0.005, K("cfc8b0"), -PI, PI, 0.006)
	_cuff(c, 0.5, 0.012, 0.003, bk.lightened(0.1))


static func _genjutsu(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var w = K("f4f4f2")
	var e = K("c8c8cc")
	var d = K("18141a")
	var y = ch + 0.08
	for k in 7:
		var f = k * 0.075
		var s = 1.0 if k % 2 == 0 else -1.0
		for front in [true, false]:
			_seam(c, [Vector2(-s * 0.16, y - f), Vector2(s * 0.16, y - f - 0.11)], 0.055, 0.005, w if k % 2 == 0 else w.darkened(0.04), front)
			_seam(c, [Vector2(-s * 0.16, y - f - 0.03), Vector2(s * 0.16, y - f - 0.14)], 0.004, 0.003, e, front, 0.0075)
	for k in 8:
		_plate(c, -0.13 + k * 0.038, h - 0.15, 0.012, 0.03, 0.003, d, true, 8.0 * (k % 3 - 1), 0.009)
	_arm_wraps(c, 0.5, 0.93, 6, 0.02, WRAP, 1.0)
	_arm_wraps(c, 0.72, 0.95, 4, 0.02, WRAP, -1.0)
	for s in [-1.0, 1.0]:
		_wraps(c, s, h - 0.17, h - 0.3, 4, 0.024, WRAP, 0.004)


static func _gezegen(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]
	var g = K("6ac0a0")
	var q = [[0.085, h - 0.04, 0.026, 0], [-0.09, h - 0.08, 0.022, 0], [0.04, h - 0.13, 0.016, 1], [-0.035, h - 0.0, 0.02, 1], [0.12, h - 0.14, 0.018, 0]]
	for e in q:
		if e[3] == 0:
			_star(c, e[0], e[1], e[2], 0.0025, g)
			_star(c, -float(e[0]) * 0.8, e[1] + 0.02, e[2], 0.0025, g, false)
		else:
			_disc(c, e[0], e[1], e[2], 0.002, g)
			_seam(c, [Vector2(float(e[0]) - float(e[2]) * 1.7, float(e[1]) - 0.008), Vector2(float(e[0]) + float(e[2]) * 1.7, float(e[1]) + 0.008)], 0.004, 0.003, g.lightened(0.2), true, 0.005)
	_ring(c, h + 0.075, 0.03, 0.005, K("3a3a40"), -PI, PI, 0.004)
	_btns(c, 0.0, h + 0.075, h + 0.03, 2, 0.008, g)
	for k in 3:
		_cuff(c, 0.9 + k * 0.03, 0.006, 0.004, K("3a78c8"))
	_neck(c, 0.05, 0.05, 0.012, K("f6f6f8"), 0.13)
	_neck(c, 0.018, 0.008, 0.008, K("d8d8e0"), 0.13, 0.012)
	for s in [-1.0, 1.0]:
		_ring(c, c["A"] + 0.09, 0.016, 0.004, g, -PI, PI, 0.006, s)


static func _gezgin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var g = K("232328")
	var p = K("4a3a68")
	_seam(c, [Vector2(0.0, n - 0.05), Vector2(0.0, kn + 0.1)], 0.005, 0.002, g)
	_btns(c, 0.014, n - 0.09, h + 0.05, 5, 0.006, K("5a5a62"))
	_belt(c, h + 0.09, 0.022, p, SILVER, 0.03)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.13, h + 0.02), Vector2(s * 0.075, h - 0.03)], 0.012, 0.004, g)
	_seam(c, [Vector2(0.0, n - 0.09), Vector2(0.0, h + 0.02)], 0.005, 0.002, g, false)
	_cuff(c, 0.88, 0.025, 0.005, g)
	_side_box(c, h + 0.03, 0.9, 0.0, 0.045, 0.1, 0.018, p.darkened(0.1), 0.012)


static func _goksel(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var red = K("a01424")
	_cuff(c, 0.86, 0.075, 0.006, red)
	_cuff(c, 0.76, 0.01, 0.004, red.darkened(0.3))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.06, n - 0.06), Vector2(s * 0.1, _hem(c, "isshiki_palto", h - 0.2) + 0.05)], 0.016, 0.003, red)
		for k in 3:
			_disc(c, float(c["UA"]) * s + s * 0.1 + s * k * 0.06, n - 0.05, 0.009, 0.003, red, false)
	_disc(c, 0.0, n - 0.22, 0.02, 0.003, red, false)
	for k in 6:
		var a = TAU * k / 6.0
		_disc(c, cos(a) * 0.07, n - 0.22 + sin(a) * 0.07, 0.012, 0.003, red, false)


static func _golge_genc(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]
	var y = K("e8e0a8")
	var dk = y.darkened(0.22)
	_zip(c, n - 0.02, h + 0.0, K("c8c088"))
	for k in 5:
		var yy = ch + 0.08 - k * 0.075
		_ring(c, yy, 0.004, 0.003, dk, -PI, PI, 0.003, 0.0, 9.0, 0.2)
	_neck(c, 0.015, 0.05, 0.008, y)
	_ring(c, h + 0.0, 0.035, 0.006, y.darkened(0.08), -PI, PI, 0.004)
	_cuff(c, 0.95, 0.035, 0.005, y.darkened(0.1))
	_plate(c, 0.0, ch + 0.05, 0.06, 0.03, 0.003, K("3a4a2a"), false)
	_holster(c, -1.0, h - 0.17, K("f0f0f0"), K("18181c"))
	for s in [-1.0, 1.0]:
		_ring(c, kn - 0.09, 0.02, 0.005, K("16203a"), -PI, PI, 0.005, s)
		_seam(c, [Vector2(s * 0.12, h + 0.08), Vector2(s * 0.08, h + 0.03)], 0.007, 0.003, dk)


static func _golge_jonin(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var y = K("e8d498")
	var dk = y.darkened(0.2)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.03, n - 0.03), Vector2(s * 0.07, h + 0.03)], 0.03, 0.004, y.lightened(0.1))
		_seam(c, [Vector2(s * 0.12, h + 0.12), Vector2(s * 0.09, h + 0.07)], 0.009, 0.003, dk)
		_ring(c, kn - 0.1, 0.022, 0.005, K("16203a"), -PI, PI, 0.005, s)
	var pts := []
	for k in 13:
		var a = lerpf(-1.0, 1.0, k / 12.0)
		pts.append(Vector2(sin(a) * 0.05, n - 0.09 - cos(a) * 0.05))
	_seam(c, pts, 0.004, 0.003, SILVER, true, 0.006, 0.012)
	_plate(c, 0.0, n - 0.145, 0.02, 0.02, 0.004, SILVER, true, 45.0, 0.006)
	_cuff(c, 0.5, 0.016, 0.004, dk)
	_seam(c, [Vector2(0.0, n - 0.08), Vector2(0.0, kn + 0.1)], 0.005, 0.002, dk, false)
	_plate(c, 0.0, n - 0.15, 0.07, 0.04, 0.003, K("3a4a2a"), false)


static func _gosterisli(c: Dictionary, col_a: Color, _lining: Color, stripe: Color, boot: Color) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var by = _hem(c, "uzun_ceket", kn - 0.06)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.13, h + 0.1), Vector2(s * 0.09, h + 0.05)], 0.007, 0.003, col_a)
		_btns(c, s * 0.11, n - 0.13, n - 0.25, 2, 0.005, stripe)
		for k in 3:
			_ring(c, kn - 0.12 - k * 0.1, 0.018, 0.005, boot.lightened(0.12), -PI, PI, 0.006, s)
		_side_box(c, kn - 0.12, s * 1.3, s, 0.02, 0.028, 0.005, stripe, 0.012)
	_ring(c, by + 0.03, 0.012, 0.003, col_a, -PI, PI, 0.003)
	_cuff(c, 0.9, 0.03, 0.005, col_a)
	_seam(c, [Vector2(0.0, n - 0.05), Vector2(0.0, h + 0.0)], 0.004, 0.002, col_a, false)


static func _gozluk(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var org = K("e8842a")
	var navy = K("1e2a58")
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.03, n - 0.05), Vector2(s * 0.085, n - 0.2), Vector2(s * 0.09, h + 0.12)], 0.01, 0.003, org)
		_wraps(c, s, an + 0.17, an + 0.08, 4, 0.02, WRAP)
	_cuff(c, 0.97, 0.012, 0.004, org)
	_plate(c, 0.0, h + 0.055, 0.05, 0.03, 0.006, K("8a8c92"), true, 0.0, 0.012)
	_holster(c, -1.0, h - 0.17, K("f0f0f0"), navy)
	_disc(c, 0.0, n - 0.2, 0.032, 0.003, K("c43020"), false)
	_ring(c, n - 0.0, 0.05, 0.008, navy, -PI, PI, 0.006, 0.0, 0.13)


static func _gunebakan(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var y = K("f6d670")
	var dk = y.darkened(0.2)
	_ring(c, h - 0.015, 0.03, 0.005, y.darkened(0.08), -PI, PI, 0.004)
	_cuff(c, 0.95, 0.03, 0.005, y.darkened(0.08))
	_seam(c, [Vector2(-0.075, n - 0.3), Vector2(0.0, n - 0.27), Vector2(0.075, n - 0.3)], 0.005, 0.002, dk)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.09, n - 0.3), Vector2(s * 0.07, h + 0.02)], 0.005, 0.002, dk)
		_ring(c, kn + 0.1, 0.016, 0.004, K("2a2a30"), -PI, PI, 0.005, s)
	_teeth(c, h - 0.1, 20, 0.05, 0.05, K("f4f4f6"))


static func _gunesi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var or2 = K("d84a14")
	var y = K("f8d870")
	var by = h + 0.09
	for k in 9:
		var a = lerpf(-1.1, 1.1, k / 8.0)
		var r = _prof_y(c, by)
		if r.is_empty():
			break
		var o = Vector3(sin(a), 0.0, cos(a))
		var ct: Vector2 = r["c"]
		var dn: Vector3 = (Vector3.DOWN + o * 0.3).normalized()
		var t = Vector3(cos(a), 0.0, -sin(a))
		_box(c, Vector3(ct.x, by - 0.04, ct.y) + o * (_rad(r["r"], a) + 0.014), t * 0.012, dn * 0.022, dn.cross(t).normalized() * 0.008, y)
	_disc(c, 0.03, ch + 0.0, 0.03, 0.003, K("fff6dc"))
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.14, h + 0.04), Vector2(s * 0.16, h - 0.2)], 0.008, 0.003, or2)
	_dg(c, "Hips", Vector3(-0.07, by - 0.02, 0.15), Vector3(-0.15, -1.0, 0.1), 0.26, 0.09, K("c8302a"), 0.2)
	_neck(c, 0.015, 0.04, 0.008, K("e8801a"), 0.125)


static func _harika(c: Dictionary, rib: Color, ribbed: bool) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]; var kn: float = c["Kn"]
	for s in [-1.0, 1.0]:
		_mer(c, s * 0.68, n - 0.1, h - 0.07, 0.03, 0.005, rib)
		if ribbed:
			for k in 16:
				_seam(c, [Vector2(s * 0.1, n - 0.15 - k * 0.035), Vector2(s * 0.13, n - 0.15 - k * 0.035)], 0.0035, 0.002, rib.darkened(0.2))
		_seam(c, [Vector2(s * 0.13, h + 0.06), Vector2(s * 0.13, h - 0.02)], 0.006, 0.003, rib.darkened(0.15))
		_ring(c, kn - 0.14, 0.012, 0.004, K("8a8c90") if ribbed else K("2a3aa8"), -PI, PI, 0.012, s)
	_ring(c, h - 0.05, 0.04, 0.005, rib, -PI, PI, 0.004)
	_cuff(c, 0.95, 0.045, 0.006, rib)
	if ribbed:
		for k in 9:
			_cuff(c, 0.895 + k * 0.012, 0.003, 0.002, rib.darkened(0.2), 0.009)


static func _hime(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var an: float = c["A"]
	var y = K("f4e8b8")
	var red = K("a82a30")
	for k in 16:
		_mer(c, -PI + (k + 0.5) * TAU / 16.0, h + 0.06, an + 0.1, 0.007, 0.004, red.darkened(0.2))
	_ring(c, h + 0.11, 0.05, 0.006, y, -PI, PI, 0.005)
	_ring(c, h + 0.11, 0.008, 0.003, K("d8a848"), -PI, PI, 0.011)
	for s in [-1.0, 1.0]:
		_plate(c, s * 0.055, h + 0.11, 0.09, 0.05, 0.012, y, true, s * 10.0, 0.012)
		_dg(c, "Hips", Vector3(s * 0.02, h + 0.09, 0.155), Vector3(s * 0.12, -1.0, 0.08), 0.26, 0.04, y, 0.26)
		_seam(c, [Vector2(s * 0.018, n - 0.03), Vector2(s * 0.08, h + 0.15)], 0.022, 0.004, K("e87a30"))
	_plate(c, 0.0, h + 0.11, 0.03, 0.05, 0.016, y.darkened(0.08), true, 0.0, 0.014)
	_cuff(c, 0.9, 0.012, 0.003, K("f4e8b8"))


static func _iblis(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var g = K("a8b8e0")
	var blk = K("16161a")
	_ring(c, h + 0.08, 0.05, 0.006, K("24242a"), -PI, PI, 0.005)
	_plate(c, 0.0, h + 0.08, 0.12, 0.06, 0.006, K("2e2e34"), false, 0.0, 0.01)
	_btns(c, 0.0, h + 0.09, h + 0.07, 2, 0.008, SILVER, false)
	_dg(c, "Hips", Vector3(0.05, h + 0.05, -0.14), Vector3(0.1, -1.0, -0.1), 0.24, 0.05, K("2e2e34"), 0.24)
	_cuff(c, 0.56, 0.014, 0.004, blk)
	_cuff(c, 0.92, 0.014, 0.004, blk)
	for s in [-1.0, 1.0]:
		_ring(c, kn - 0.1, 0.016, 0.005, blk, -PI, PI, 0.03, s)
		_ring(c, c["A"] + 0.13, 0.016, 0.005, blk, -PI, PI, 0.02, s)
		_seam(c, [Vector2(s * 0.09, n - 0.06), Vector2(s * 0.11, h + 0.1)], 0.012, 0.003, K("24242a"))
	_cuff(c, 0.97, 0.012, 0.004, g.darkened(0.3))


static func _ic_giysi(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var nv = K("1e2a48")
	var dk = nv.darkened(0.25)
	_seam(c, [Vector2(0.0, n - 0.03), Vector2(0.0, h + 0.03)], 0.004, 0.002, dk)
	_ring(c, h + 0.03, 0.03, 0.006, K("16203a"), -PI, PI, 0.004)
	_spiral(c, -float(c["UA"]) - 0.075, n - 0.045, 0.024, 1.6, 0.005, K("b02428"))   # kolda kızıl girdap
	_cuff(c, 0.22, 0.05, 0.003, nv.lightened(0.06), 0.003, -1.0)
	_cuff(c, 0.93, 0.03, 0.005, dk)
	_holster(c, -1.0, h - 0.17, K("f0f0f0"), dk)
	for s in [-1.0, 1.0]:
		_ring(c, kn - 0.09, 0.024, 0.005, dk, -PI, PI, 0.005, s)
		_wraps(c, s, an + 0.17, an + 0.08, 4, 0.02, WRAP)
		_seam(c, [Vector2(s * 0.09, ch + 0.05), Vector2(s * 0.11, h + 0.05)], 0.004, 0.002, dk)


static func _inuzuka(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var an: float = c["A"]
	var blk = K("2a2a30")
	_seam(c, [Vector2(0.04, n - 0.04), Vector2(-0.07, ch - 0.12), Vector2(-0.05, h + 0.04)], 0.009, 0.004, SILVER)
	_seam(c, [Vector2(0.045, n - 0.03), Vector2(0.14, n - 0.12)], 0.05, 0.005, blk)
	_seam(c, [Vector2(-0.03, n - 0.03), Vector2(-0.14, n - 0.11)], 0.05, 0.005, blk)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.13, h + 0.09), Vector2(s * 0.085, h + 0.04)], 0.006, 0.003, SILVER)
		_plate(c, s * 0.1, ch + 0.0, 0.05, 0.006, 0.003, SILVER, true, s * -20.0)
		_ring(c, an + 0.14, 0.014, 0.005, blk, -PI, PI, 0.006, s)
	_cuff(c, 0.93, 0.024, 0.005, blk)
	for k in 5:
		_seam(c, [Vector2(-0.05, n - 0.015 - k * 0.012), Vector2(0.05, n - 0.015 - k * 0.012)], 0.002, 0.002, K("6a6a72"), true, 0.002)
	_holster(c, -1.0, h - 0.16, K("eeeeee"), K("24242a"))


static func _hemsire(c: Dictionary, trim: Color, stock: Color, shoe: Color) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var ch: float = c["C"]
	for s in [-1.0, 1.0]:
		_btns(c, s * 0.048, ch + 0.03, h + 0.0, 4, 0.0095, K("e8e8ec") if trim == K("a01822") else K("f4f4f4"))
		_seam(c, [Vector2(s * 0.1, ch + 0.0), Vector2(s * 0.115, h + 0.14)], 0.004, 0.002, trim)
		_seam(c, [Vector2(s * 0.125, h - 0.02), Vector2(s * 0.075, h - 0.06)], 0.01, 0.003, trim)
		_ring(c, kn + 0.16, 0.02, 0.004, stock.darkened(0.08), -PI, PI, 0.006, s)
		_ring(c, c["A"] + 0.08, 0.02, 0.004, shoe, -PI, PI, 0.007, s)
	_plate(c, 0.0, h + 0.1, 0.1, 0.05, 0.012, trim, false, -12.0, 0.01)
	_plate(c, 0.0, h + 0.1, 0.1, 0.05, 0.012, trim, false, 12.0, 0.01)
	_dg(c, "Hips", Vector3(0.02, h + 0.08, -0.15), Vector3(0.14, -1.0, -0.1), 0.15, 0.03, trim, 0.26)
	_dg(c, "Hips", Vector3(-0.02, h + 0.08, -0.15), Vector3(-0.14, -1.0, -0.1), 0.15, 0.03, trim, 0.26)
	_cuff(c, 0.95, 0.024, 0.005, trim)
	_cuff(c, 0.89, 0.03, 0.005, stock)


static func _iwa(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var br = K("5a4030")
	var red = K("a82228")
	_btns(c, 0.014, n - 0.09, ch - 0.0, 3, 0.008, K("c8b080"))
	for s in [-1.0, 1.0]:
		_pouch(c, s * 0.075, ch - 0.12, 0.09, 0.08, br.darkened(0.08), br.lightened(0.1), true, K("c8b080"))
		_stitch(c, Vector2(s * 0.12, n - 0.06), Vector2(s * 0.13, h + 0.1), 11, br.lightened(0.28))
		_ring(c, an + 0.24, 0.018, 0.004, K("2e2e34"), -PI, PI, 0.005, s)
	_pouch(c, 0.0, ch - 0.05, 0.16, 0.14, br.darkened(0.1), br.lightened(0.05), false, K("c8b080"))
	_ring(c, h + 0.05, 0.03, 0.006, K("3a2a20"), -PI, PI, 0.006)
	_plate(c, 0.09, h - 0.08, 0.1, 0.22, 0.004, red, true, 8.0, 0.006)
	_dg(c, "Hips", Vector3(0.1, h - 0.18, 0.14), Vector3(0.05, -1.0, 0.05), 0.2, 0.08, red, 0.2)
	_ring(c, kn - 0.1, 0.03, 0.004, red.darkened(0.2), -PI, PI, 0.004, 1.0)


static func _kawaki(c: Dictionary, trim: Color, belt: Color, lap: float, school: bool) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]; var ch: float = c["C"]
	var by = _hem(c, "kawaki_okul" if school else "kawaki_palto", kn - 0.05)
	_ring(c, by + 0.05, 0.016, 0.003, trim, -PI, PI, 0.003)
	_belt(c, h + 0.07, 0.034, belt, SILVER, 0.042)
	for s in [-1.0, 1.0]:
		_mer(c, s * 1.3, ch + 0.1, by + 0.06, 0.005, 0.003, trim.darkened(0.25))
		if school:
			_pouch(c, s * 0.1, ch + 0.02, 0.075, 0.07, K("2a5088"), trim.darkened(0.15), true, K("e0e4ea"))
	_seam(c, [Vector2(-0.07, n - 0.2), Vector2(0.0, n - 0.14), Vector2(0.07, n - 0.2), Vector2(0.0, n - 0.27), Vector2(-0.07, n - 0.2)], 0.008, 0.003, K("9a9ca4"), false)
	_seam(c, [Vector2(0.0, n - 0.27), Vector2(0.0, n - 0.27 - lap * 2.0)], 0.008, 0.003, K("9a9ca4"), false)
	if not school:
		_cuff(c, 0.92, 0.04, 0.008, K("2a2a30"), 0.004, 1.0)


static func _jigen(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]
	var red = K("a01e24")
	_neck(c, 0.02, 0.022, 0.006, red, 0.115)
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.02, n - 0.05), Vector2(s * 0.075, h + 0.15)], 0.018, 0.003, K("d8d8d8"))
	_plate(c, 0.0, h + 0.12, 0.04, 0.05, 0.008, K("eeeeec"), true, 0.0, 0.014)
	_seam(c, [Vector2(-0.06, n - 0.22), Vector2(0.0, n - 0.14), Vector2(0.06, n - 0.22), Vector2(0.0, n - 0.3), Vector2(-0.06, n - 0.22)], 0.007, 0.003, K("9a9ca4"), false)
	_cuff(c, 0.88, 0.02, 0.005, red)
	_stitch(c, Vector2(-0.12, ch - 0.13), Vector2(0.12, ch - 0.13), 12, K("c8c8c8"))


static func _ruro(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var kn: float = c["Kn"]
	var p = K("3a3450")
	var l = K("4a3a5a")
	for k in 3:
		_neck(c, -0.02 + k * 0.03, 0.034, 0.016, l.darkened(0.08 * (k % 2)), 0.15, 0.012)
	_dg(c, "UpperChest", Vector3(0.07, n - 0.02, 0.1), Vector3(0.15, -1.0, 0.2), 0.2, 0.06, l, 0.22)
	_belt(c, h + 0.06, 0.03, K("18181c"), SILVER, 0.04)
	var by = _hem(c, "kawaki_ruro", kn - 0.06)
	_teeth(c, by + 0.06, 26, 0.06, 0.038, p, -PI, PI, 3.0)
	_cuff(c, 0.95, 0.05, 0.005, K("6a1a22"), 0.004, 1.0)
	_cuff(c, 0.88, 0.008, 0.004, K("18181c"), 0.008, 1.0)


static func _kader(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]; var an: float = c["A"]
	var beige = K("e8e0d0")
	for k in 5:
		var y = ch + 0.09 - k * 0.07
		_seam(c, [Vector2(-0.055, y), Vector2(0.055, y)], 0.013, 0.004, beige.darkened(0.14))
		_disc(c, 0.0, y, 0.0075, 0.005, beige.darkened(0.32))
	_neck(c, 0.015, 0.036, 0.007, beige.darkened(0.06))
	_cuff(c, 0.3, 0.016, 0.004, beige.darkened(0.16))
	_ring(c, h + 0.0, 0.024, 0.005, beige.darkened(0.1), -PI, PI, 0.004)
	_holster(c, -1.0, h - 0.13, WRAP, K("1c2a58"))
	_wraps(c, -1.0, kn - 0.02, an + 0.09, 9, 0.024, WRAP)
	_arm_wraps(c, 0.4, 0.95, 8, 0.022, WRAP, -1.0)


static func _konan(c: Dictionary) -> void:
	var n: float = c["N"]; var h: float = c["H"]; var ch: float = c["C"]; var kn: float = c["Kn"]
	var band = K("9ab8d8")
	var pur = K("6a3a5a")
	for s in [-1.0, 1.0]:
		_seam(c, [Vector2(s * 0.14, h + 0.04), Vector2(-s * 0.05, h - 0.1), Vector2(-s * 0.15, kn + 0.17)], 0.05, 0.004, band if s > 0.0 else band.darkened(0.08))
		_seam(c, [Vector2(s * 0.145, h + 0.015), Vector2(-s * 0.03, h - 0.115)], 0.004, 0.002, K("3a4a68"), true, 0.0075)
	_ring(c, h + 0.07, 0.05, 0.006, K("6a6a78"), -PI, PI, 0.005)
	_ring(c, h + 0.07, 0.01, 0.004, K("1c1c20"), -PI, PI, 0.01)
	_plate(c, 0.0, h + 0.02, 0.12, 0.09, 0.024, pur, true, 0.0, 0.012)
	_plate(c, 0.0, h + 0.05, 0.128, 0.042, 0.006, pur.lightened(0.12), true, 0.0, 0.036)
	_disc(c, 0.0, h + 0.03, 0.008, 0.004, GOLD)
	_cuff(c, 0.5, 0.012, 0.004, K("b0a030"))
	_seam(c, [Vector2(-0.02, n - 0.03), Vector2(0.08, ch - 0.12)], 0.03, 0.004, K("b0a030"))
