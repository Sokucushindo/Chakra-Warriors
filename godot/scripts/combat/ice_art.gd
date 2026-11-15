class_name IceArt
extends RefCounted
## Hyōton buz kristalleri (anime referanslı): düzensiz altıgen gövdeli, eğik sivri uçlu, düz yüzeyli kristaller.
## Malzeme saydam camgöbeği + yüz yüz ton + beyaz parlama çizgileri (ice.gdshader) — opak beyaz koni / küre değil.

static var _mat: ShaderMaterial
static var _frost_mat: StandardMaterial3D


static func mat() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/ice.gdshader")
	return _mat


static func _frost() -> StandardMaterial3D:
	if _frost_mat == null:
		_frost_mat = StandardMaterial3D.new()
		_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_frost_mat.vertex_color_use_as_albedo = true
		_frost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _frost_mat


## Düz gölgeli üçgen: normal, verilen dış yöne (out) bakacak şekilde sarılır
static func _tri(b: MB, p0: Vector3, p1: Vector3, p2: Vector3, out: Vector3, col: Color) -> void:
	var n = (p1 - p0).cross(p2 - p0)
	if n.dot(out) > 0.0:
		var tmp = p1
		p1 = p2
		p2 = tmp
		n = -n
	var nn = -n.normalized()
	var i0 = b.verts.size()
	for p in [p0, p1, p2]:
		b.verts.append(p)
		b.normals.append(nn)
		b.colors.append(col)
		b.uvs.append(Vector2.ZERO)
	b.idx.append_array([i0, i0 + 1, i0 + 2])


## Tek kristal: base noktasından dir yönünde h boyunda, r yarıçaplı; gövde %55-70'te daralıp eğik bir uca biter.
## cap: alt yüz kapatılır (havada uçan parçalar için)
static func shard(b: MB, base: Vector3, dir: Vector3, h: float, r: float, rng: RandomNumberGenerator, col := Color.WHITE, sides := 6, cap := false) -> void:
	var y = dir.normalized()
	var x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	var rot = rng.randf() * TAU
	var mid = rng.randf_range(0.55, 0.72)
	var r0 = []
	var r1 = []
	for k in sides:
		var a = rot + (k + rng.randf_range(-0.25, 0.25)) * TAU / sides
		var rr = r * rng.randf_range(0.75, 1.15)
		var off = x * cos(a) + z * sin(a)
		r0.append(base + off * rr - y * r * 0.3)
		r1.append(base + off * rr * rng.randf_range(0.82, 1.0) + y * h * mid)
	var apex = base + y * h + (x * rng.randf_range(-1, 1) + z * rng.randf_range(-1, 1)) * r * 0.3
	var axis_mid = base + y * h * 0.5
	var tip_col = col.lerp(Color(1.08, 1.08, 1.1, col.a), 0.25)
	for k in sides:
		var k2 = (k + 1) % sides
		var out = ((r0[k] + r0[k2]) * 0.5 - base).normalized()
		_tri(b, r0[k], r0[k2], r1[k2], out, col)
		_tri(b, r0[k], r1[k2], r1[k], out, col)
		var out2 = ((r1[k] + r1[k2] + apex) / 3.0 - axis_mid).normalized()
		_tri(b, r1[k], r1[k2], apex, out2, tip_col)
		if cap:
			_tri(b, r0[k], r0[k2], base - y * r * 0.3, -y, col)


static func _mi(b: MB) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(mat())
	mi.material_override = mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _rng(seed := -1) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	return rng


## Tek buz sivrisi (eski _ice_spike yerine): taban orijinde, +Y
static func spike(h: float, r: float) -> MeshInstance3D:
	var b = MB.new()
	shard(b, Vector3.ZERO, Vector3.UP, h, r, _rng(), Color.WHITE, 6)
	return _mi(b)


## Tsurara: hedefin çevresinden yerden fışkıran, içe eğik büyük buz kristalleri + ortada hedefi saran buz kütlesi
static func encase(r := 1.6, h := 3.4) -> MeshInstance3D:
	var rng = _rng()
	var b = MB.new()
	# dış halka: içe eğik büyük kristaller, aralarında küçükler
	var n = 9
	for k in n:
		var a = k * TAU / n + rng.randf_range(-0.15, 0.15)
		var o = Vector3(cos(a), 0, sin(a))
		shard(b, o * r * rng.randf_range(0.9, 1.15), (Vector3.UP * 1.0 - o * rng.randf_range(0.25, 0.5)), h * rng.randf_range(0.8, 1.15), r * 0.36, rng)
		var a2 = a + PI / n
		var o2 = Vector3(cos(a2), 0, sin(a2))
		shard(b, o2 * r * 1.35, Vector3.UP * 1.0 + o2 * rng.randf_range(0.2, 0.6), h * rng.randf_range(0.35, 0.55), r * 0.2, rng)
	# orta kütle: hedefi saran kalın kristal öbeği
	for k in 5:
		var a = k * TAU / 5.0 + rng.randf()
		var o = Vector3(cos(a), 0, sin(a))
		shard(b, o * r * 0.35, Vector3.UP + o * 0.25, h * rng.randf_range(0.75, 0.95), r * 0.55, rng, Color(0.95, 0.98, 1.0))
	# dışa saçılan küçük yer kristalleri
	for k in 12:
		var a = rng.randf() * TAU
		var o = Vector3(cos(a), 0, sin(a))
		shard(b, o * r * rng.randf_range(1.6, 2.4), Vector3.UP + o * rng.randf_range(0.5, 1.2), h * rng.randf_range(0.12, 0.3), r * 0.1, rng)
	return _mi(b)


## Hyōgan Dōmu: üst üste binen, içe eğik kristal levhalardan örülü pürüzlü kubbe (pürüzsüz yarım küre değil)
static func dome(r := 2.4) -> MeshInstance3D:
	var rng = _rng()
	var b = MB.new()
	var rings = [[16, 1.0, 0.15, 0.9], [13, 0.88, 0.6, 0.8], [9, 0.62, 1.05, 0.7], [5, 0.33, 1.35, 0.55]]
	for ri in rings.size():
		var cnt: int = rings[ri][0]
		var rad: float = rings[ri][1] * r
		var y0: float = rings[ri][2] * r
		for k in cnt:
			var a = (k + (0.5 if ri % 2 == 1 else 0.0) + rng.randf_range(-0.2, 0.2)) * TAU / cnt
			var o = Vector3(cos(a), 0, sin(a))
			var lean = 0.25 + ri * 0.55
			var d = (Vector3.UP - o * lean).normalized()
			shard(b, o * rad + Vector3.UP * y0, d, r * rings[ri][3] * rng.randf_range(0.85, 1.2), r * (0.32 - ri * 0.04), rng, Color(1, 1, 1) if ri % 2 == 0 else Color(0.9, 0.96, 1.0))
	# tepe sivrisi ve dışarı taşan pürüzlü sivri uçlar
	shard(b, Vector3.UP * r * 1.25, Vector3.UP, r * 0.55, r * 0.22, rng)
	for k in 10:
		var a = rng.randf() * TAU
		var o = Vector3(cos(a), 0, sin(a))
		var yy = rng.randf_range(0.3, 1.1)
		shard(b, (o * cos(yy) + Vector3.UP * sin(yy)) * r * 0.95, o * 0.8 + Vector3.UP * 0.6, r * rng.randf_range(0.3, 0.55), r * 0.08, rng)
	# taban: yere yayılan küçük kristaller (dairesel çizgi yerine doğal etek)
	for k in 18:
		var a = rng.randf() * TAU
		var o = Vector3(cos(a), 0, sin(a))
		shard(b, o * r * rng.randf_range(1.05, 1.5), Vector3.UP + o * rng.randf_range(0.4, 1.0), r * rng.randf_range(0.15, 0.4), r * 0.09, rng)
	return _mi(b)


## Buz duvarı (Suishōheki): sık dizilmiş kalın kristal sütunlar, aralarında boşluk yok; w genişlik (yan ekseni X), h yükseklik
static func wall(w := 7.0, h := 4.0) -> MeshInstance3D:
	var rng = _rng()
	var b = MB.new()
	var n = int(w / 0.7)
	for k in n + 1:
		var x = -w * 0.5 + w * k / float(n)
		var hh = h * rng.randf_range(0.7, 1.15) * (1.0 - 0.35 * pow(absf(x) / (w * 0.5), 2.0))
		shard(b, Vector3(x, 0, rng.randf_range(-0.15, 0.15)), Vector3(rng.randf_range(-0.15, 0.15), 1, rng.randf_range(-0.12, 0.12)), hh, 0.55, rng)
	# önde ve arkada eğik destek kristalleri (kalın, sağlam duvar görünümü)
	for k in n:
		var x = -w * 0.5 + w * (k + 0.5) / float(n)
		for sz in [-1.0, 1.0]:
			shard(b, Vector3(x, 0, sz * 0.55), Vector3(rng.randf_range(-0.2, 0.2), 1, sz * rng.randf_range(0.3, 0.6)), h * rng.randf_range(0.3, 0.55), 0.35, rng, Color(0.92, 0.97, 1.0))
	return _mi(b)


## Buz kırlangıç (Tsubame Fubuki): iki ucu sivri kristal gövde, geriye süpürülmüş uzun sivri kanatlar, çatal kuyruk.
## -Z'ye bakar (mermi yönü). s=1: ~1.1 m kanat açıklığı
static func swallow(s := 1.0) -> MeshInstance3D:
	var rng = _rng()
	var b = MB.new()
	shard(b, Vector3(0, 0, 0.05) * s, Vector3.FORWARD, 0.42 * s, 0.07 * s, rng, Color.WHITE, 5, true)
	shard(b, Vector3(0, 0, 0.05) * s, Vector3.BACK, 0.25 * s, 0.07 * s, rng, Color(0.9, 0.96, 1.0), 5, true)
	for sx in [-1.0, 1.0]:
		shard(b, Vector3(sx * 0.03, 0.01, 0.0) * s, Vector3(sx * 1.0, 0.05, 0.42), 0.6 * s, 0.05 * s, rng, Color.WHITE, 4, true)
		shard(b, Vector3(sx * 0.02, 0.0, 0.2) * s, Vector3(sx * 0.35, 0.0, 1.0), 0.3 * s, 0.025 * s, rng, Color(0.9, 0.96, 1.0), 4, true)
	return _mi(b)


## Hyōryū Boppa ejder başı: keskin buz kristallerinden uzun burun, açık çene, geriye kıvrık kristal boynuzlar, yanak dikenleri. -Z'ye bakar
static func dragon_head(s := 1.0) -> MeshInstance3D:
	var rng = _rng()
	var b = MB.new()
	# kafatası: birkaç kalın kristal öbek
	for k in 4:
		shard(b, Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.1, 0.15), 0.4) * s, Vector3(rng.randf_range(-0.15, 0.15), 0.1, -1.0), 1.0 * s, 0.38 * s, rng, Color.WHITE, 6, true)
	# üst burun ve alt çene (açık ağız)
	shard(b, Vector3(0, 0.12, -0.2) * s, Vector3(0, 0.05, -1.0), 1.7 * s, 0.32 * s, rng, Color.WHITE, 5, true)
	shard(b, Vector3(0, -0.3, -0.1) * s, Vector3(0, -0.35, -1.0), 1.35 * s, 0.24 * s, rng, Color(0.88, 0.95, 1.0), 5, true)
	for k in 5:   # dişler
		for sx in [-1.0, 1.0]:
			shard(b, Vector3(sx * 0.17, 0.02, -0.5 - k * 0.22) * s, Vector3(sx * 0.1, -1.0, 0), 0.22 * s, 0.05 * s, rng, Color.WHITE, 4)
	for sx in [-1.0, 1.0]:
		shard(b, Vector3(sx * 0.3, 0.4, 0.3) * s, Vector3(sx * 0.35, 0.6, 1.0), 1.5 * s, 0.13 * s, rng, Color.WHITE, 5, true)
		shard(b, Vector3(sx * 0.25, 0.35, 0.6) * s, Vector3(sx * 0.2, 0.9, 1.0), 1.0 * s, 0.09 * s, rng, Color(0.9, 0.96, 1.0), 5, true)
		for k in 3:
			shard(b, Vector3(sx * 0.4, -0.05 + k * 0.12, 0.35 + k * 0.15) * s, Vector3(sx * 1.0, rng.randf_range(-0.2, 0.3), 0.6), (0.6 - k * 0.12) * s, 0.08 * s, rng, Color.WHITE, 4, true)
		b.add("sphere", Vector3(sx * 0.33, 0.28, -0.25) * s, Vector3(0.12, 0.1, 0.16) * s, Color(0.15, 0.35, 0.75), Vector3.ZERO, 8)
	for k in 4:   # ense dikenleri
		shard(b, Vector3(0, 0.35, 0.5 + k * 0.3) * s, Vector3(0, 1.0, 0.8), (0.7 - k * 0.1) * s, 0.1 * s, rng, Color.WHITE, 4, true)
	return _mi(b)


## Makyō Hyōshō aynası: ince düz buz levha (çapraz beyaz parlama çizgili), kenarları hafif kalın
static var _mirror_mat: ShaderMaterial
static func mirror(w := 1.6, h := 2.3) -> MeshInstance3D:
	if _mirror_mat == null:
		_mirror_mat = mat().duplicate()
		_mirror_mat.set_shader_parameter("alpha", 0.5)
		_mirror_mat.set_shader_parameter("streak", 1.6)
		_mirror_mat.set_shader_parameter("light_col", Color(0.88, 0.97, 1.0))
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(w, h, 0.07), Color.WHITE)
	for sy in [-1.0, 1.0]:
		b.add("box", Vector3(0, sy * h * 0.5, 0), Vector3(w + 0.06, 0.08, 0.12), Color(0.85, 0.94, 1.0))
		b.add("box", Vector3(sy * w * 0.5, 0, 0), Vector3(0.08, h, 0.12), Color(0.85, 0.94, 1.0))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(_mirror_mat)
	mi.material_override = _mirror_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Yerde donmuş zemin: düzensiz kenarlı beyaz-mavi buz lekesi (kenarlara doğru saydamlaşır)
static func frost(r := 3.0) -> MeshInstance3D:
	var rng = _rng()
	var b = MB.new()
	var seg = 28
	var pts = []
	for k in seg:
		var a = k * TAU / seg
		pts.append(Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.65, 1.1))
	var c_in = Color(0.85, 0.95, 1.0, 0.75)
	var c_out = Color(0.75, 0.9, 1.0, 0.0)
	for k in seg:
		var k2 = (k + 1) % seg
		_tri(b, Vector3.ZERO, pts[k], pts[k2], Vector3.UP, c_in)
		var i = b.colors.size()
		b.colors[i - 1] = c_out if b.verts[i - 1] != Vector3.ZERO else c_in
		b.colors[i - 2] = c_out if b.verts[i - 2] != Vector3.ZERO else c_in
		b.colors[i - 3] = c_out if b.verts[i - 3] != Vector3.ZERO else c_in
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(_frost())
	mi.material_override = _frost()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Kırılma: kristal parçaları yerçekimiyle saçılır, beyaz parıltı + soğuk buhar (küçülerek kaybolma yerine)
static func shatter(tree: SceneTree, pos: Vector3, s := 1.0, n := 14) -> void:
	var rng = _rng()
	var root = tree.current_scene
	for k in n:
		var b = MB.new()
		shard(b, Vector3.ZERO, Vector3(rng.randf_range(-1, 1), 1, rng.randf_range(-1, 1)), s * rng.randf_range(0.35, 0.8), s * rng.randf_range(0.08, 0.16), rng, Color.WHITE, 5, true)
		var mi = _mi(b)
		root.add_child(mi)
		var p0 = pos + Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 1.5), rng.randf_range(-1, 1)) * s
		mi.global_position = p0
		var v = (p0 - pos + Vector3.UP * 0.5).normalized() * rng.randf_range(3.0, 7.0) * sqrt(s) + Vector3.UP * rng.randf_range(2.0, 5.0)
		var spin = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		var life = rng.randf_range(0.7, 1.1)
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				mi.global_position = p0 + v * t + Vector3.DOWN * 9.8 * 0.5 * t * t
				mi.rotation = spin * t
				mi.scale = Vector3.ONE * clampf((life - t) / 0.25, 0.0, 1.0), 0.0, life, life)
		tw.tween_callback(mi.queue_free)
	FX.burst(pos + Vector3.UP * s, {"amount": int(30 * s), "life": 0.6, "tex": FX.tex_spark, "add": true, "size": 0.25, "radius": s, "vmin": 3, "vmax": 8,
		"colors": [Color(1, 1, 1, 1), Color(0.75, 0.92, 1.0, 0.9), Color(0.7, 0.9, 1.0, 0.0)]})
	VFX.fog(pos + Vector3.UP * 0.6 * s, {"amount": int(10 * s) + 4, "life": 1.4, "size": 1.4 * s, "radius": s, "vmin": 0.3, "vmax": 1.2, "dir": Vector3.UP, "spread": 80.0,
		"colors": [Color(0.95, 0.98, 1.0, 0.0), Color(0.9, 0.96, 1.0, 0.55), Color(0.88, 0.95, 1.0, 0.0)]})


# ---------------------------------------------------------------- film Hyōton yaratıkları (Narutopedia görselleri)
# Yumuşak gövdeler Loft tüpü; +Z'ye bakacak şekilde kurulur, ClayArt._fwd ile -Z'ye çevrilir.
static var _mats := {}


static func toon(key: String, c: Color) -> Material:
	if not _mats.has(key):
		_mats[key] = Props.toon_color(c)
	return _mats[key]


static func _tube(b: MB, pts: Array, rad: Array, s: float) -> void:
	var R = []
	for r in rad:
		R.append((r if r is Vector2 else Vector2(r, r)) * s)
	Loft.tube(b, ClayArt._sc(pts, s), R, Color.WHITE, 12, 3)


static func _part(b: MB, m: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(m)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _glow_dots(pts: Array, size: Vector3, col: Color) -> MeshInstance3D:
	var b = MB.new()
	for p in pts:
		b.add("sphere", p, size, col, Vector3.ZERO, 8)
	var key = "dot_%s" % col
	if not _mats.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		_mats[key] = m
	return _part(b, _mats[key])


## Dört ayaklı gövde + kalça / diz eklemli dört bacak, dörtnal döngüsü (ön çift / arka çift faz farkı)
static func _beast(s: float, m: Material, body_fn: Callable, front_z: float, back_z: float, hip_y: float, leg_r: float, wide: float, rate := 0.3) -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	root.add_child(body)
	var bb = MB.new()
	body_fn.call(bb)
	body.add_child(_part(bb, m))
	var legs = []
	var up = hip_y * 0.5
	for leg in [[-1.0, front_z, 0.0, 1.0], [1.0, front_z, 0.12, 1.0], [-1.0, back_z, 0.5, -1.0], [1.0, back_z, 0.62, -1.0]]:
		var hip = Node3D.new()
		hip.position = Vector3(leg[0] * wide, hip_y, leg[1]) * s
		var hb = MB.new()
		_tube(hb, [Vector3.ZERO, Vector3(0, -up * 0.5, 0), Vector3(0, -up, 0)], [leg_r * 1.35, leg_r * 1.1, leg_r * 0.85], s)
		hip.add_child(_part(hb, m))
		var knee = Node3D.new()
		knee.position = Vector3(0, -up, 0) * s
		var kb = MB.new()
		_tube(kb, [Vector3.ZERO, Vector3(0, -up * 0.5, 0), Vector3(0, -up * 0.9, 0.02), Vector3(0, -up, 0.1)], [leg_r * 0.85, leg_r * 0.7, leg_r * 0.8, leg_r * 0.5], s)
		knee.add_child(_part(kb, m))
		hip.add_child(knee)
		body.add_child(hip)
		legs.append([hip, knee, leg[2], leg[3]])
	var tw = root.create_tween().set_loops()
	tw.tween_method(func(ph: float):
		for L in legs:
			if not is_instance_valid(L[0]):
				return
			var a = TAU * (ph + L[2])
			L[0].rotation.x = -sin(a) * 0.85
			L[1].rotation.x = L[3] * (0.25 + 0.75 * maxf(0.0, sin(a + 1.3))) * 0.95
		body.position.y = absf(sin(TAU * ph)) * 0.07 * s
		body.rotation.x = sin(TAU * ph) * 0.07, 0.0, 1.0, rate)
	return root


## Rōga Nadare kurdu: kardan, tüylü boyunlu, sivri kulaklı, kabarık kuyruklu; pembe gözler (film)
static func wolf(s := 1.0) -> Node3D:
	var root = _beast(s, toon("snow", Color(0.86, 0.88, 0.99)), func(b: MB):
		_tube(b, [Vector3(0, 0.6, 1.08), Vector3(0, 0.63, 0.92), Vector3(0, 0.69, 0.72), Vector3(0, 0.72, 0.58), Vector3(0, 0.64, 0.42), Vector3(0, 0.54, 0.24), Vector3(0, 0.52, 0.0), Vector3(0, 0.54, -0.22), Vector3(0, 0.55, -0.4), Vector3(0, 0.56, -0.54)],
			[0.04, 0.085, Vector2(0.15, 0.16), Vector2(0.17, 0.18), 0.17, Vector2(0.22, 0.26), Vector2(0.19, 0.22), Vector2(0.15, 0.17), Vector2(0.17, 0.18), 0.1], s)
		_tube(b, [Vector3(0, 0.58, 0.62), Vector3(0, 0.52, 0.82), Vector3(0, 0.47, 0.98)], [0.085, 0.06, 0.03], s)   # açık alt çene
		for sx in [-1.0, 1.0]:
			_tube(b, [Vector3(sx * 0.08, 0.82, 0.6), Vector3(sx * 0.11, 0.95, 0.52), Vector3(sx * 0.12, 1.03, 0.46)], [0.055, 0.04, 0.006], s)   # kulak
			_tube(b, [Vector3(sx * 0.13, 0.64, 0.52), Vector3(sx * 0.27, 0.57, 0.36)], [0.08, 0.008], s)   # yanak tüyü
			_tube(b, [Vector3(sx * 0.14, 0.56, 0.38), Vector3(sx * 0.26, 0.46, 0.2)], [0.08, 0.008], s)   # boyun tüyü
		for q in 5:   # sırt boyunca geriye yatık kar tutamları
			var z = 0.46 - q * 0.2
			_tube(b, [Vector3(0, 0.72 - q * 0.02, z), Vector3(0, 0.9 - q * 0.03, z - 0.17)], [0.07, 0.008], s)
		_tube(b, [Vector3(0, 0.56, -0.52), Vector3(0, 0.62, -0.8), Vector3(0, 0.54, -1.1), Vector3(0, 0.5, -1.38)], [0.07, 0.125, 0.11, 0.01], s),   # kabarık kuyruk
		0.24, -0.38, 0.47, 0.062, 0.13)
	root.get_child(0).add_child(_glow_dots([Vector3(-0.09, 0.745, 0.8) * s, Vector3(0.09, 0.745, 0.8) * s], Vector3(0.045, 0.032, 0.04) * s, Color(1.0, 0.5, 0.8)))
	return ClayArt._fwd(root)


## Haryū Mōko kaplanı: soluk buzdan iri gövde, sırtında ve dirseklerinde geriye yatık buz bıçakları, uzun dişler
static func tiger(s := 1.0) -> Node3D:
	var root = _beast(s, toon("ice_body", Color(0.74, 0.9, 1.0)), func(b: MB):
		_tube(b, [Vector3(0, 0.62, 1.02), Vector3(0, 0.66, 0.9), Vector3(0, 0.72, 0.72), Vector3(0, 0.74, 0.56), Vector3(0, 0.66, 0.4), Vector3(0, 0.56, 0.22), Vector3(0, 0.54, 0.0), Vector3(0, 0.55, -0.25), Vector3(0, 0.56, -0.45), Vector3(0, 0.57, -0.6)],
			[0.09, 0.14, Vector2(0.2, 0.19), Vector2(0.22, 0.2), 0.18, Vector2(0.25, 0.28), Vector2(0.22, 0.24), Vector2(0.18, 0.2), Vector2(0.2, 0.21), 0.11], s)
		_tube(b, [Vector3(0, 0.6, 0.6), Vector3(0, 0.5, 0.8), Vector3(0, 0.43, 0.94)], [0.11, 0.09, 0.05], s)
		for sx in [-1.0, 1.0]:
			_tube(b, [Vector3(sx * 0.14, 0.86, 0.55), Vector3(sx * 0.18, 0.96, 0.5)], [0.06, 0.02], s)
		_tube(b, [Vector3(0, 0.58, -0.58), Vector3(0, 0.6, -0.95), Vector3(0, 0.7, -1.3), Vector3(0, 0.92, -1.55)], [0.07, 0.055, 0.045, 0.02], s),
		0.26, -0.42, 0.5, 0.078, 0.17, 0.34)
	var body: Node3D = root.get_child(0)
	var rng = _rng()
	var b = MB.new()
	for q in 6:   # sırt bıçakları
		shard(b, Vector3(0, 0.74 - q * 0.02, 0.5 - q * 0.2) * s, Vector3(0, 1.0, -0.9), (0.5 - q * 0.04) * s, 0.06 * s, rng, Color.WHITE, 4, true)
	for sx in [-1.0, 1.0]:
		shard(b, Vector3(sx * 0.2, 0.62, 0.3) * s, Vector3(sx * 0.8, 0.5, -1.0), 0.55 * s, 0.055 * s, rng, Color.WHITE, 4, true)   # omuz
		shard(b, Vector3(sx * 0.19, 0.6, -0.4) * s, Vector3(sx * 0.7, 0.5, -1.0), 0.45 * s, 0.05 * s, rng, Color.WHITE, 4, true)   # kalça
		shard(b, Vector3(sx * 0.16, 0.66, 0.6) * s, Vector3(sx * 1.0, 0.1, -0.5), 0.4 * s, 0.04 * s, rng, Color.WHITE, 4, true)   # yanak
		shard(b, Vector3(sx * 0.07, 0.62, 0.9) * s, Vector3(sx * 0.1, -1.0, 0.15), 0.22 * s, 0.028 * s, rng, Color.WHITE, 4, true)   # uzun diş
	shard(b, Vector3(0, 0.9, -1.52) * s, Vector3(0, 0.6, -1.0), 0.3 * s, 0.05 * s, rng, Color.WHITE, 4, true)   # kuyruk ucu
	body.add_child(_part(b, mat()))
	body.add_child(_glow_dots([Vector3(-0.11, 0.78, 0.82) * s, Vector3(0.11, 0.78, 0.82) * s], Vector3(0.05, 0.035, 0.045) * s, Color(0.75, 0.95, 1.0)))
	return ClayArt._fwd(root)


## Ikkaku Hakugei: tek boynuzlu dev beyaz balina — küt baş, şişkin gövde, yassı kuyruk ve yüzgeçler, ileri uzanan uzun boynuz.
## Birim boy ~8 (burun ucundan kuyruğa)
static func whale(s := 1.0) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	_tube(b, [Vector3(0, 0, 3.0), Vector3(0, 0.05, 2.6), Vector3(0, 0.1, 1.8), Vector3(0, 0.1, 0.8), Vector3(0, 0.05, -0.4), Vector3(0, 0, -1.6), Vector3(0, 0, -2.5), Vector3(0, 0, -3.1)],
		[0.25, Vector2(0.6, 0.5), Vector2(0.85, 0.75), Vector2(0.95, 0.85), Vector2(0.8, 0.7), Vector2(0.45, 0.4), Vector2(0.2, 0.18), 0.1], s)
	for sx in [-1.0, 1.0]:
		_tube(b, [Vector3(0, 0, -3.0), Vector3(sx * 0.55, 0, -3.4), Vector3(sx * 1.1, 0, -3.75)], [Vector2(0.25, 0.06), Vector2(0.36, 0.05), Vector2(0.05, 0.02)], s)
		_tube(b, [Vector3(sx * 0.8, -0.3, 1.4), Vector3(sx * 1.3, -0.5, 1.0), Vector3(sx * 1.9, -0.6, 0.3)], [Vector2(0.22, 0.07), Vector2(0.26, 0.06), Vector2(0.05, 0.02)], s)
	_tube(b, [Vector3(0, 0.95, -0.9), Vector3(0, 1.2, -1.25)], [Vector2(0.06, 0.2), 0.02], s)   # sırt çıkıntısı
	root.add_child(_part(b, toon("whale", Color(0.76, 0.87, 0.97))))
	var h = MB.new()
	_tube(h, [Vector3(0, 0.3, 2.75), Vector3(0, 0.72, 3.8), Vector3(0, 1.15, 4.9)], [0.075, 0.045, 0.005], s)
	root.add_child(_part(h, toon("horn", Color(0.97, 0.98, 1.0))))
	root.add_child(_glow_dots([Vector3(-0.72, -0.05, 2.1) * s, Vector3(0.72, -0.05, 2.1) * s], Vector3(0.05, 0.07, 0.08) * s, Color(0.1, 0.16, 0.3)))
	return ClayArt._fwd(root)
