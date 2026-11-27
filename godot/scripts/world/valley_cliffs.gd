extends RefCounted
## Sonun Vadisi kanyon duvarları (ref: refs/valley_end/Valley_of_the_End.png).
## Animedeki yar: yuvarlak dikey kaya sütunları, aralarında derin koyu yarıklar; her sütun üst üste kaymış yatay levhalardan
## (çatlak çizgileriyle ayrılmış, hafif sarkan katmanlar); yeşilimsi gri taş, levha üstlerinde ve yarın tepesinde yosun/ot.
## Arazinin dik yamacının önünde tek parça yüzey ağı: her yükseklikte nehre doğru kabartı, tepede düzlüğe kıvrılan dudak
## (arazinin 30 m'lik eğik yamacı ve şeritli kaya boyası görünmez). Çarpışma aynı yüzeyin seyreltilmiş üçgen ağı (tırmanılır).

const DN := 3.0        # sütun adımı (m, kanyon boyunca)
const NF := 52         # yüz satırı (dipten tepeye)
const LIP := [[3.0, 2.2], [9.0, 3.4], [22.0, 3.6], [40.0, 3.2], [58.0, 1.4], [74.0, -4.0]]   # dudak: [yüzden dışa m, tepeden +y]
const CHUNK := 50      # parça başına sütun (görüş dışı kırpma + çarpışma parçası)

static var _fn: FastNoiseLite


static func _vn(x: float, y: float, sd := 0) -> float:
	if _fn == null:
		_fn = FastNoiseLite.new()
		_fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_fn.fractal_type = FastNoiseLite.FRACTAL_NONE
		_fn.frequency = 1.0
	return _fn.get_noise_2d(x + sd * 31.7, y - sd * 17.3) * 0.5 + 0.5


static func _h(a: int, b: int) -> float:
	var v = hash(Vector2i(a, b))
	return float(v % 10007) / 10007.0


## Kaya kabartısı (m, nehre doğru) + boyama bilgisi. s: duvar boyunca koordinat, y: yükseklik, base: duvar dibi
## dönüş: [kabartı, yarık (0..1), çatlak (0..1), katman no, sütun no]
static func relief(s: float, y: float, base: float) -> Array:
	# dikey sütunlar: genişlik 18-34 m, kenarları yarıkta keskin, ortası yuvarlak; yükseldikçe hafif kıvrılır
	var w = 24.0 + (_vn(s * 0.006, 3.0, 1) - 0.5) * 16.0
	var ph = s / w + (_vn(s * 0.004, y * 0.006, 2) - 0.5) * 1.1
	var ci = floori(ph)
	var f = ph - ci
	var pil = pow(sin(PI * f), 0.32)
	var crev = 1.0 - smoothstep(0.0, 0.16, minf(f, 1.0 - f))
	var amp = 4.5 + _h(ci, 7) * 5.0
	# yatay levhalar: 5-9 m kalınlık, dalgalı katman çizgisi, her levha sütun sütun farklı öne kayar (kademeli)
	var T = 10.0 + _h(ci, 3) * 5.0
	var yy = y - base + (_vn(s * 0.012, 0.0, 4) - 0.5) * 9.0 + _h(ci, 5) * T
	var li = floori(yy / T)
	var t = yy / T - li
	var slab = 2.4 * pow(sin(PI * clampf(t * 1.05, 0.0, 1.0)), 0.45) + _h(li, ci) * 3.6
	# çatlak çizgisi kesik kesik (animedeki fırça darbesi): her yerde sürekli şerit olmasın
	var crack = (1.0 - smoothstep(0.0, 0.07, t)) * smoothstep(0.35, 0.55, _vn(s * 0.08, li * 1.7, 12))
	# büyük ölçekli şişkinlik
	var big = (_vn(s * 0.007, y * 0.01, 6) - 0.3) * 7.0
	return [maxf(0.0, amp * pil + slab * (0.5 + 0.5 * pil) + big), crev, crack, li, ci]


## Boya: yeşilimsi gri levhalar (levha levha ton farkı), yarık ve çatlaklar koyu, yukarı bakan yüzler yosun, dipte ıslak
static func paint(r: Array, ny: float, y: float, base: float, top: float) -> Color:
	var li: int = r[3]
	var ci: int = r[4]
	var k = _h(li * 3 + 1, ci)
	var c = Color(0.5, 0.57, 0.47).lerp(Color(0.62, 0.66, 0.55), k * 0.7)
	c = c.lerp(Color(0.44, 0.5, 0.47), _h(ci, 11) * 0.5)
	c = c.darkened(float(r[1]) * 0.55)
	c = c.lerp(Color(0.24, 0.3, 0.27), float(r[2]) * 0.75)
	var moss = smoothstep(0.35, 0.75, ny) * (0.55 + 0.45 * _h(li, ci + 9))
	c = c.lerp(Color(0.3, 0.48, 0.22), moss)
	c = c.lerp(Color(0.27, 0.42, 0.2), smoothstep(top - 10.0, top, y) * 0.6 * (1.0 - float(r[1])))
	c = c.darkened(clampf(1.0 - (y - base) / 4.0, 0.0, 1.0) * 0.35)
	return c


## Bir duvar ağı: P(i, j) noktaları -> yüzey + çarpışma. pts satır sırası: j * NI + i; want: istenen dış yön (normal yönü)
static func _emit(b: Builder, mat: Material, pts: PackedVector3Array, cols: PackedColorArray, live: PackedByteArray, NI: int, NJ: int, want: Vector3, tag: String) -> int:
	var tris = 0
	var i0 = 0
	while i0 < NI - 1:
		var i1 = mini(NI - 1, i0 + CHUNK)
		var ni = i1 - i0 + 1
		var verts = PackedVector3Array()
		var norms = PackedVector3Array()
		var cc = PackedColorArray()
		verts.resize(ni * NJ)
		norms.resize(ni * NJ)
		cc.resize(ni * NJ)
		for j in NJ:
			for i in range(i0, i1 + 1):
				var k = j * NI + i
				var ta = pts[j * NI + mini(i + 1, NI - 1)] - pts[j * NI + maxi(i - 1, 0)]
				var tb = pts[mini(j + 1, NJ - 1) * NI + i] - pts[maxi(j - 1, 0) * NI + i]
				var nn = ta.cross(tb)
				if nn.dot(want) < 0.0:
					nn = -nn
				var q = j * ni + (i - i0)
				verts[q] = pts[k]
				norms[q] = nn.normalized() if nn.length_squared() > 1e-8 else want
				cc[q] = cols[k]
		var idx = PackedInt32Array()
		var faces = PackedVector3Array()
		for j in NJ - 1:
			for i in range(i0, i1):
				if live[i] == 0 or live[i + 1] == 0:
					continue
				var a = j * ni + (i - i0)
				var bq = a + 1
				var c = a + ni
				var d = c + 1
				# Godot ön yüz: saat yönü (normal görenden uzağa çapraz çarpım) -> istenen yöne göre sıralama
				var cr = (verts[bq] - verts[a]).cross(verts[c] - verts[a])
				if cr.dot(norms[a]) < 0.0:
					idx.append_array(PackedInt32Array([a, bq, c, bq, d, c]))
				else:
					idx.append_array(PackedInt32Array([a, c, bq, bq, c, d]))
				# çarpışma: her 2 sütun x 2 satırda bir dörtgen (~6 m), yüz yüzeyini izler
				if j % 2 == 0 and (i - i0) % 2 == 0:
					var j2 = mini(j + 2, NJ - 1)
					var i2 = mini(i + 2, i1)
					if live[i2] != 0:
						var p00 = verts[j * ni + (i - i0)]
						var p10 = verts[j * ni + (i2 - i0)]
						var p01 = verts[j2 * ni + (i - i0)]
						var p11 = verts[j2 * ni + (i2 - i0)]
						faces.append_array(PackedVector3Array([p00, p10, p11, p00, p11, p01]))
		if idx.size() > 0:
			var arr = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cc
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi = MeshInstance3D.new()
			mi.name = "VadiYari_%s_%d" % [tag, i0]
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.visibility_range_end = 9000.0
			b.root.add_child(mi)
			mi.global_transform = Transform3D.IDENTITY
			tris += idx.size() / 3
			if faces.size() > 0:
				var tri = ConcavePolygonShape3D.new()
				tri.backface_collision = true
				tri.set_faces(faces)
				var cs = CollisionShape3D.new()
				cs.shape = tri
				b.add_shape(cs)
		i0 = i1
	return tris


static var _mat: ShaderMaterial
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = LazyFx.g("Props").toon().duplicate()
		_mat.set_shader_parameter("detail_tex", load("res://assets/tex/rock.png"))
		_mat.set_shader_parameter("detail_tex_amt", 0.4)
		_mat.set_shader_parameter("detail_tex_scale", 0.16)
		_mat.set_shader_parameter("detail_noise", 0.18)
		_mat.set_shader_parameter("rim_amount", 0.1)
	return _mat


static func _th(b: Builder, x: float, n: float) -> float:
	var wp = b.w(Vector3(x, 0, n))
	return Game.terrain_height(wp.x, wp.z)


## Yan duvarlar (iki yaka) + şelale basamağının yüzü
static func build(b: Builder, spec: Dictionary) -> int:
	var half = float(spec["half"])
	var fall_n = float(spec["fall_dy"])
	var river = float(spec["river"])
	var upper = float(spec["upper"])
	var mat = material()
	var tris = 0
	var n0 = -1000.0
	var n1 = fall_n + 480.0
	var NI = int((n1 - n0) / DN) + 1
	var NJ = NF + 1 + LIP.size()
	for sx in [-1.0, 1.0]:
		var pts = PackedVector3Array()
		var cols = PackedColorArray()
		var live = PackedByteArray()
		pts.resize(NI * NJ)
		cols.resize(NI * NJ)
		live.resize(NI)
		for i in NI:
			var n = n0 + i * DN
			var floor_y = _th(b, sx * (half - 14.0), n)
			var top = maxf(_th(b, sx * (half + 45.0), n), _th(b, sx * (half + 70.0), n))
			live[i] = 1 if top - floor_y > 8.0 else 0
			var base = floor_y - 7.0
			var top_face = top - 1.5 + (_vn(n * 0.03, 1.0, 8) - 0.5) * 4.0
			var last_x = 0.0
			var last_r: Array = []
			for j in NF + 1:
				var y = lerpf(base, top_face, float(j) / NF)
				var r = relief(n, y, floor_y)
				# tepeye yakın kabartı söner (dudağa yumuşak geçiş), dipte suya gömülü
				var fade = 1.0 - smoothstep(top_face - 14.0, top_face, y) * 0.6
				var x = half + 1.0 - float(r[0]) * fade
				pts[j * NI + i] = b.w(Vector3(sx * x, y, n))
				cols[j * NI + i] = paint(r, 0.0, y, floor_y, top)
				last_x = x
				last_r = r
			for k in LIP.size():
				var j = NF + 1 + k
				var lp: Array = LIP[k]
				var x = last_x + float(lp[0]) + (_vn(n * 0.05, float(k), 9) - 0.5) * 3.0
				var y = top_face + float(lp[1]) + (_vn(n * 0.04, float(k) * 0.7, 10) - 0.5) * 1.2
				pts[j * NI + i] = b.w(Vector3(sx * x, y, n))
				cols[j * NI + i] = Color(0.3, 0.46, 0.2).lerp(Color(0.36, 0.5, 0.24), _vn(n * 0.02, float(k), 11)) if k > 0 else paint(last_r, 0.9, y, floor_y, top)
		# yosun: yukarı bakan levha üstleri (normal y) -> ikinci geçişte boya
		# (yukarı çıkarken yüzey nehirden geri çekiliyorsa basamağın üstü göğe bakar)
		var out_dir = Vector3(-sx, 0, 0)
		for j in range(1, NF):
			for i in NI:
				var dy = pts[(j + 1) * NI + i] - pts[(j - 1) * NI + i]
				var ny = -dy.normalized().dot(out_dir)
				if ny > 0.3:
					cols[j * NI + i] = cols[j * NI + i].lerp(Color(0.3, 0.47, 0.22), smoothstep(0.3, 0.75, ny) * 0.8)
		tris += _emit(b, mat, pts, cols, live, NI, NJ, Vector3(-sx, 0.6, 0.0), "y%d" % int(sx))
	# yar tepesinde ağaç / çalı kümeleri (ref: tepelerde yeşillik); dudağın gerisinde, arazi yüksekliğinde
	var rng = RandomNumberGenerator.new()
	rng.seed = 9127
	for sx in [-1.0, 1.0]:
		var n = n0 + 40.0
		while n < n1 - 40.0:
			var x = sx * (half + rng.randf_range(10.0, 46.0))
			var g = _th(b, x, n)
			if g - _th(b, sx * (half - 14.0), n) > 20.0:
				var cnt = rng.randi_range(1, 3)
				for k in cnt:
					b.tree(x + rng.randf_range(-5.0, 5.0) * sx, n + rng.randf_range(-6.0, 6.0), rng.randf_range(0.8, 1.3), rng, g - 0.3)
			n += rng.randf_range(14.0, 40.0)
	# şelale basamağı: nehirden yukarı yatağa dik yüz (şelale perdesinin arkası ıslak koyu, iki yanı sütunlu)
	var x0 = -(half + 4.0)
	var NX = int((2.0 * (half + 4.0)) / DN) + 1
	var NJ2 = NF + 1 + 3
	var fp = PackedVector3Array()
	var fc = PackedColorArray()
	var flive = PackedByteArray()
	fp.resize(NX * NJ2)
	fc.resize(NX * NJ2)
	flive.resize(NX)
	for i in NX:
		var x = x0 + i * DN
		flive[i] = 1
		var wet = 1.0 - smoothstep(56.0, 66.0, absf(x))
		var top_face = lerpf(upper + 2.5, upper - 2.5, wet)
		var base = river - 7.0
		for j in NF + 1:
			var y = lerpf(base, top_face, float(j) / NF)
			var r = relief(x + 500.0, y, river)
			var d = float(r[0]) * lerpf(1.0, 0.12, wet) * (1.0 - smoothstep(top_face - 10.0, top_face, y) * 0.6)
			fp[j * NX + i] = b.w(Vector3(x, y, fall_n - 2.0 - d))
			var c = paint(r, 0.0, y, river, top_face + 30.0)
			fc[j * NX + i] = c.lerp(Color(0.2, 0.27, 0.28), wet * 0.6)
		for k in 3:
			var j = NF + 1 + k
			var y = top_face + [1.0, 1.4, -1.5][k] * (1.0 - wet * 2.0)
			fp[j * NX + i] = b.w(Vector3(x, y, fall_n + [3.0, 10.0, 22.0][k]))
			fc[j * NX + i] = Color(0.3, 0.46, 0.2).lerp(Color(0.2, 0.27, 0.28), wet)
	tris += _emit(b, mat, fp, fc, flive, NX, NJ2, Vector3(0, 0.6, 1.0), "selale")
	return tris
