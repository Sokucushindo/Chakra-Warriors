class_name TyphoonFX
extends RefCounted
## Taiton (Tayfun) görselleri — sıfırdan, kendi yapı taşlarıyla. Tayfun düz rüzgâr değil, bir fırtına sistemidir:
##   sakin GÖZ + yoğun dönen GÖZ DUVARI, içe kıvrılan kalın SARMAL YAĞMUR BANTLARI (farklı katlarda), bantların içinde yatay
##   sürüklenen YAĞMUR PERDELERİ, savrulan YAPRAK / KOPUK DÖKÜNTÜ, tabanda çalkalanan ALÇAK BULUT ETEĞİ, şimşeksiz koyu bulut
##   titremesi. Her teknik üç evreli: toplanma (bantlar içe çekilir) → salınma → artçı (yere yatmış ot izi, süzülen yapraklar,
##   sönen yağmur perdeleri, yerde kalan alçak bulut).
## Çizgi film (cel) görünüş: düz renkler + koyu bantlar, gerçekçi duman yok. Hazır / ortak efekt yardımcısı KULLANILMAZ; yalnız
## ham geometri (MB / ArrayMesh), kendi gölgelendiricilerimiz ve kendi CPUParticles3D ayarlarımız.
## Oynanış (hasar, savurma, çekme, durumlar, zamanlama, atış geri savurma, fırtınanın gözü zayıflığı) path_jutsu.gd'deki eski
## işleyişten satır satır taşındı; yalnız görünüş değişti.

const RAIN := Color(0.9, 0.94, 0.98)
const BAND_HI := Color(1.0, 1.0, 1.0)
const BAND_MID := Color(0.86, 0.9, 0.96)
const BAND_LO := Color(0.7, 0.76, 0.86)
const BAND_DEEP := Color(0.52, 0.58, 0.7)
const CLOUD_TOP := Color(0.88, 0.91, 0.95)
const CLOUD_BOT := Color(0.46, 0.53, 0.64)
const CHAKRA := Color(0.62, 0.88, 1.0)
const GRASS := Color(0.42, 0.58, 0.3)
const LEAF_RAMP := [Color(0.34, 0.58, 0.22), Color(0.56, 0.7, 0.26), Color(0.62, 0.48, 0.24), Color(0.6, 0.58, 0.54), Color(0.28, 0.44, 0.18)]
const CHIP_RAMP := [Color(0.5, 0.4, 0.3), Color(0.38, 0.31, 0.25), Color(0.62, 0.57, 0.5), Color(0.44, 0.36, 0.27)]

## Kalın bant gölgelendiricisi: şerit boyunca akan koyu yağmur bantları, yırtık bulut kenarı (sert cel basamak), şimşeksiz
## koyu titreme. UV.x = şerit boyu (metre * ölçek), UV.y = enine 0..1, COLOR.a = uçlarda sönme.
const BAND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 c_hi = vec3(0.97, 0.96, 0.91);
uniform vec3 c_mid = vec3(0.68, 0.74, 0.83);
uniform vec3 c_lo = vec3(0.36, 0.43, 0.55);
uniform float bands = 5.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float flow = 1.0;
instance uniform float flick = 0.0;
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float t = TIME * flow;
	float across = 1.0 - abs(v * 2.0 - 1.0);
	float n1 = vn(vec2(u * 6.0 - t * 2.1 + seed * 7.1, v * 2.6 + seed));
	float n2 = vn(vec2(u * 2.2 - t * 0.8 + seed * 3.3, v * 1.4 + 4.0));
	float edge = 0.1 + n1 * 0.48;
	if (across < edge) { discard; }
	if (length(VERTEX) < 1.4 + n1 * 2.2) { discard; }   // kameraya çok yakın bant açılır: içerideki kişi okunur
	if (COLOR.a < n2 * 0.75 + 0.06) { discard; }
	if (fade < n1 * 0.9 + 0.08) { discard; }
	float core = step(edge + 0.26 + n2 * 0.16, across);
	float stripe = step(0.6, fract(u * bands - t * 1.4 + v * 0.45 + n2 * 0.6));
	vec3 col = mix(c_mid, c_hi, core);
	col = mix(col, c_lo, stripe * (0.5 + 0.5 * (1.0 - core)));
	// ince hız taraması: şerit boyunca akan kesik çizgiler (satır satır, her satır kendi hızında)
	float row = floor(v * 11.0);
	float rh = h21(vec2(row, seed));
	float hatch = step(0.8, fract(v * 11.0)) * step(0.45, fract(u * (2.0 + rh * 3.0) - t * (2.2 + rh * 1.6) + rh * 5.0));
	col = mix(col, c_lo * 0.85, hatch * 0.7);
	// koyu iç kenar (şeridin iç / alt yüzü)
	col = mix(col, c_lo * 0.8, step(v, 0.2 + n1 * 0.08) * 0.75);
	float fl = flick * step(0.86, h21(vec2(floor(TIME * 6.0), seed)));
	col *= 1.0 - fl * 0.38;
	ALBEDO = col * COLOR.rgb;
	ALPHA = clamp(0.58 + 0.34 * core, 0.0, 1.0) * clamp(fade * 1.6, 0.0, 1.0);
}
"""

## Yağmur perdesi: şerit boyunca hızla sürüklenen ince yağmur çizgileri (satır satır, her satır kendi hızında)
const RAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 c_rain = vec3(0.82, 0.88, 0.95);
uniform float rows = 14.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float flow = 1.0;
instance uniform float flick = 0.0;
float h11(float x, float sd) { return fract(sin(x * 91.7 + sd * 13.3) * 43758.5453); }
void fragment() {
	float row = floor(UV.y * rows);
	float fy = fract(UV.y * rows);
	float r = h11(row, seed);
	float s = fract(UV.x * (3.0 + r * 3.0) - TIME * flow * (2.5 + r * 2.0) + r * 7.0);
	float streak = step(0.8 - r * 0.08, s) * step(abs(fy - 0.5), 0.07 + r * 0.04) * step(0.45, h11(row + 31.0, seed));
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	if (streak < 0.5 || across < 0.06 || COLOR.a < r * 0.6 + 0.04 || length(VERTEX) < 1.6 + r * 2.0) { discard; }
	ALBEDO = c_rain * COLOR.rgb * mix(0.82, 1.08, r) * (1.0 - flick * 0.2);
	ALPHA = (0.2 + 0.24 * r) * fade;
}
"""

## Bulut topakları: opak cel (üç ton), söndürme dünya-uzayı gürültüsüyle kenardan eriyerek
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 c_lit = vec3(0.97, 0.97, 0.98);
uniform vec3 c_shade = vec3(0.8, 0.84, 0.9);
uniform vec3 c_deep = vec3(0.62, 0.67, 0.76);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float flow = 1.0;
instance uniform float flick = 0.0;
varying vec3 wn;
varying vec3 wp;
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = vn(wp.xz * 1.3 + vec2(seed, TIME * flow * 0.3)) * 0.6 + vn(wp.xy * 1.7 + seed) * 0.4;
	if (n > fade * 1.05 || length(VERTEX) < 1.5 + n * 2.0) { discard; }
	float l = dot(normalize(wn), normalize(vec3(0.3, 0.9, 0.25))) + (n - 0.5) * 0.3;
	vec3 col = l > 0.32 ? c_lit : (l > -0.22 ? c_shade : c_deep);
	col *= 1.0 - flick * step(0.88, h21(vec2(floor(TIME * 6.0), seed))) * 0.3;
	ALBEDO = col * COLOR.rgb;
}
"""

static var _m_band: ShaderMaterial
static var _m_rain: ShaderMaterial
static var _m_cloud: ShaderMaterial
static var _m_pa: StandardMaterial3D
static var _m_po: StandardMaterial3D
static var _mesh_streak: Mesh
static var _mesh_leaf: Mesh
static var _mesh_chip: Mesh
static var _mesh_lump: Mesh
static var _curve_shrink: Curve
static var _g_rain: Gradient
static var _g_leaf: Gradient
static var _g_chip: Gradient
static var _g_chakra: Gradient


# ================================================================== malzemeler / hazır parçalar (kendi)
static func _shader_mat(code: String) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	return m


static func _band_mat() -> ShaderMaterial:
	if _m_band == null:
		_m_band = _shader_mat(BAND_SHADER)
	return _m_band


static func _rain_mat() -> ShaderMaterial:
	if _m_rain == null:
		_m_rain = _shader_mat(RAIN_SHADER)
	return _m_rain


static func _cloud_mat() -> ShaderMaterial:
	if _m_cloud == null:
		_m_cloud = _shader_mat(CLOUD_SHADER)
	return _m_cloud


## Parçacık malzemesi: düz (unshaded) tepe rengi; saydam (yağmur) ya da opak (yaprak, döküntü)
static func _pmat(alpha: bool) -> StandardMaterial3D:
	if alpha and _m_pa != null:
		return _m_pa
	if not alpha and _m_po != null:
		return _m_po
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_m_pa = m
	else:
		_m_po = m
	return m


## İnce uzun yağmur çizgisi (Y ekseni hıza hizalanır)
static func _streak_mesh() -> Mesh:
	if _mesh_streak == null:
		var bm = BoxMesh.new()
		bm.size = Vector3(0.012, 0.38, 0.012)
		bm.material = _pmat(true)
		_mesh_streak = bm
	return _mesh_streak


## Kıvrık yaprak: orta damardan hafif katlanmış iki yarım
static func _leaf_mesh() -> Mesh:
	if _mesh_leaf == null:
		# sivri uçlu yaprak silueti: orta damardan hafif katlı (kenarlar yukarı), kısa sap
		var sb = Strips.new()
		var L = 0.11
		var pts = []
		var sides = []
		var cols = []
		for k in 7:
			var u = k / 6.0
			pts.append(Vector3(0, 0, (u - 0.5) * L))
			var w = sin(pow(u, 0.8) * PI) * 0.032
			sides.append(Vector3(w, 0, 0))
			cols.append(Color(1, 1, 1, 1) if k % 2 == 0 else Color(0.86, 0.86, 0.86, 1))
		sb.strip(pts, sides, cols, [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0])
		sb.strip([Vector3(0, 0, -L * 0.5), Vector3(0, -0.004, -L * 0.72)], [Vector3(0.003, 0, 0), Vector3(0.002, 0, 0)], [Color(0.6, 0.6, 0.6), Color(0.6, 0.6, 0.6)], [0.0, 1.0])
		_mesh_leaf = sb.mesh()
		_mesh_leaf.surface_set_material(0, _pmat(false))
	return _mesh_leaf


## Kopuk döküntü: yırtık kabuk / taş yongası
static func _chip_mesh() -> Mesh:
	if _mesh_chip == null:
		var b = MB.new()
		b.add("prism", Vector3.ZERO, Vector3(0.06, 0.035, 0.05), Color.WHITE, Vector3(18, 35, 9))
		b.add("prism", Vector3(0.02, 0.01, 0.01), Vector3(0.035, 0.025, 0.03), Color(0.78, 0.78, 0.78), Vector3(-25, 70, 30))
		_mesh_chip = b.build(_pmat(false))
	return _mesh_chip


## Küçük alçak bulut topağı (parçacık): üstü açık, altı koyu — pişmiş iki ton
static func _lump_mesh() -> Mesh:
	if _mesh_lump == null:
		var b = MB.new()
		b.add_grad("sphere", Vector3.ZERO, Vector3(0.3, 0.13, 0.25), Color.WHITE, Color(0.78, 0.82, 0.88), Vector3.ZERO, 10)
		b.add_grad("sphere", Vector3(0.1, 0.03, 0.04), Vector3(0.18, 0.1, 0.17), Color.WHITE, Color(0.8, 0.84, 0.9), Vector3.ZERO, 8)
		_mesh_lump = b.build(_pmat(false))
	return _mesh_lump


static func _shrink() -> Curve:
	if _curve_shrink == null:
		_curve_shrink = Curve.new()
		_curve_shrink.add_point(Vector2(0.0, 0.35))
		_curve_shrink.add_point(Vector2(0.12, 1.0))
		_curve_shrink.add_point(Vector2(0.78, 1.0))
		_curve_shrink.add_point(Vector2(1.0, 0.0))
	return _curve_shrink


static func _grad(cols: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func _rain_ramp() -> Gradient:
	if _g_rain == null:
		_g_rain = _grad([Color(RAIN.r, RAIN.g, RAIN.b, 0.0), Color(RAIN.r, RAIN.g, RAIN.b, 0.38), Color(0.78, 0.84, 0.92, 0.28), Color(0.7, 0.77, 0.86, 0.0)])
	return _g_rain


static func _chakra_ramp() -> Gradient:
	if _g_chakra == null:
		_g_chakra = _grad([Color(1, 1, 1, 0.0), Color(0.85, 0.96, 1.0, 0.6), Color(CHAKRA.r, CHAKRA.g, CHAKRA.b, 0.4), Color(CHAKRA.r, CHAKRA.g, CHAKRA.b, 0.0)])
	return _g_chakra


static func _leaf_ramp() -> Gradient:
	if _g_leaf == null:
		_g_leaf = _grad(LEAF_RAMP)
	return _g_leaf


static func _chip_ramp() -> Gradient:
	if _g_chip == null:
		_g_chip = _grad(CHIP_RAMP)
	return _g_chip


# ================================================================== şerit kurucu (kendi ArrayMesh'i)
## Merkez çizgisi + her noktada yarım genişlik vektörü → üçgen şerit; birden çok şerit tek yüzeyde
class Strips extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var ix := PackedInt32Array()

	func strip(pts: Array, sides: Array, cols: Array, us: Array) -> void:
		var m := pts.size()
		if m < 2:
			return
		var base := v.size()
		for k in m:
			var p: Vector3 = pts[k]
			var sd: Vector3 = sides[k]
			var tng: Vector3 = pts[mini(k + 1, m - 1)] - pts[maxi(k - 1, 0)]
			var nr: Vector3 = tng.cross(sd)
			nr = nr.normalized() if nr.length_squared() > 0.000001 else Vector3.UP
			v.append(p - sd)
			v.append(p + sd)
			n.append(nr)
			n.append(nr)
			uv.append(Vector2(us[k], 0.0))
			uv.append(Vector2(us[k], 1.0))
			c.append(cols[k])
			c.append(cols[k])
		for k in m - 1:
			var a := base + k * 2
			ix.append(a)
			ix.append(a + 1)
			ix.append(a + 2)
			ix.append(a + 1)
			ix.append(a + 3)
			ix.append(a + 2)

	func mesh() -> ArrayMesh:
		var am := ArrayMesh.new()
		if v.is_empty():
			return am
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = ix
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am


static func _us(pts: Array, scale: float) -> Array:
	var out = [0.0]
	var acc = 0.0
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k]
		acc += a.distance_to(pts[k - 1])
		out.append(acc * scale)
	return out


static func _ca(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0))


## İçe kıvrılan sarmal kollar (yağmur bantları). s: dönüş yönü (+1/-1); kollar dönüşün gerisinde kalır (gerçek siklon gibi)
## tilt: 0 = yatay bant (üstten okunur), ~1.4 = dikey perde (yandan okunur)
static func _arms(sb: Strips, r_out: float, r_in: float, y: float, arms: int, turns: float, w_out: float, w_in: float, s: float,
		rise := 0.0, tilt := 0.3, col := BAND_MID, seg := 26, a_off := 0.0, us := 0.3) -> void:
	for j in arms:
		var a0 = a_off + TAU * j / arms + randf_range(-0.3, 0.3)
		var span = randf_range(0.78, 1.0)
		var pts = []
		var sides = []
		var cols = []
		for k in seg + 1:
			var u = float(k) / seg * span
			var r = lerpf(r_out, r_in, pow(u, 0.8))
			var a = a0 - s * turns * TAU * u
			var rad = Vector3(cos(a), 0, sin(a))
			var yy = y + rise * u + sin(u * 9.0 + a0 * 3.0) * 0.035 * r_out
			pts.append(rad * r + Vector3.UP * yy)
			var w = lerpf(w_out, w_in, u) * (0.72 + 0.28 * sin(u * 11.0 + j * 2.3))
			sides.append((rad * cos(tilt) + Vector3.UP * sin(tilt)) * w * 0.5)
			cols.append(_ca(col, minf(u / span, 1.0 - u / span) * 6.0))
		sb.strip(pts, sides, cols, _us(pts, us))


## Göz duvarı / huni: yükselen sarmal bulut şeritleri, birbirini örter (farklı boylarda: kesintisiz kabuk değil)
static func _wall(sb: Strips, r0: float, r1: float, h: float, n: int, twist: float, s: float, col: Color, y0 := 0.0, seg := 14,
		wmul := 1.5, us := 0.5) -> void:
	for j in n:
		var a0 = TAU * j / n + randf_range(-0.3, 0.3)
		var hs = randf_range(0.7, 1.0)
		var yb = randf_range(0.0, 0.12) * h
		var pts = []
		var sides = []
		var cols = []
		for k in seg + 1:
			var u = float(k) / seg
			var yy = yb + u * (h - yb) * hs
			var uu = yy / h
			var r = lerpf(r0, r1, uu) * (1.0 + 0.08 * sin(uu * 7.0 + j * 1.9))
			var a = a0 - s * twist * uu
			var tg = Vector3(sin(a), 0, -cos(a)) * s
			pts.append(Vector3(cos(a) * r, y0 + yy, sin(a) * r))
			sides.append((tg + Vector3.UP * 0.3).normalized() * (r * TAU / n) * wmul * 0.5)
			cols.append(_ca(col, minf(u, 1.0 - u) * 6.0))
		sb.strip(pts, sides, cols, _us(pts, us))


## Kopuk halka bandı (yatay ya da eğik): yay parçaları arasında boşluk bırakır
static func _ring_band(sb: Strips, r_in: float, r_out: float, y: float, arcs: int, col: Color, us := 0.4, gap := 0.25, tilt := 0.0) -> void:
	var span = TAU / arcs
	var seg = maxi(4, int(28.0 / arcs) + 3)
	var rm = (r_in + r_out) * 0.5
	var w = (r_out - r_in) * 0.5
	for j in arcs:
		var a0 = j * span + randf_range(-0.12, 0.12)
		var a1 = a0 + span * (1.0 - gap) * randf_range(0.82, 1.12)
		var pts = []
		var sides = []
		var cols = []
		for k in seg + 1:
			var u = float(k) / seg
			var a = lerpf(a0, a1, u)
			var rad = Vector3(cos(a), 0, sin(a))
			pts.append(rad * rm * (1.0 + 0.05 * sin(a * 5.0 + j)) + Vector3.UP * (y + sin(a * 3.0 + j) * w * 0.15))
			sides.append((rad * cos(tilt) + Vector3.UP * sin(tilt)) * w * (0.75 + 0.25 * sin(u * PI)))
			cols.append(_ca(col, minf(u, 1.0 - u) * 7.0))
		sb.strip(pts, sides, cols, _us(pts, us))


# ================================================================== sahne / yaşam süresi
static func _root(pj: PathJutsu, pos: Vector3) -> Node3D:
	var r = Node3D.new()
	pj.get_tree().current_scene.add_child(r)
	r.global_position = pos
	return r


static func _node(parent: Node) -> Node3D:
	var n = Node3D.new()
	parent.add_child(n)
	return n


static func _mi(parent: Node, mesh: Mesh, mat: Material, flow := 1.0, flick := 0.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("tfx", true)
	parent.add_child(mi)
	mi.set_instance_shader_parameter("seed", randf() * 50.0)
	mi.set_instance_shader_parameter("flow", flow)
	mi.set_instance_shader_parameter("flick", flick)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


static func _geos(n: Node) -> Array:
	var out = []
	_geos_into(n, out)
	return out


static func _geos_into(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D and ch.has_meta("tfx"):
			out.append(ch)
		_geos_into(ch, out)


static func _fade(geos: Array, f: float) -> void:
	for g in geos:
		if is_instance_valid(g):
			g.set_instance_shader_parameter("fade", f)


static func _stop(n: Node) -> void:
	for ch in n.get_children():
		if ch is CPUParticles3D:
			ch.emitting = false
		_stop(ch)


## Belirme → bekleme → sönme → parçacıklar dinsin → sil (atandan bağımsız: atan ölse de efekt temizlenir)
static func _life(root: Node3D, t_in: float, hold: float, t_out: float, tail := 1.0) -> Tween:
	var geos = _geos(root)
	var tw = root.create_tween()
	if t_in > 0.0:
		_fade(geos, 0.0)
		tw.tween_method(func(f: float): _fade(geos, f), 0.0, 1.0, t_in)
	tw.tween_interval(maxf(0.01, hold))
	tw.tween_callback(func(): _stop(root))
	tw.tween_method(func(f: float): _fade(geos, f), 1.0, 0.0, maxf(0.02, t_out))
	tw.tween_interval(tail)
	tw.tween_callback(root.queue_free)
	return tw


static func _spin(n: Node3D, period: float, s := 1.0, axis := "y") -> void:
	var tw = Game.safe_loops(n.create_tween())
	tw.tween_property(n, "rotation:" + axis, TAU * s, maxf(0.05, period)).as_relative()


static func _scale_to(n: Node3D, from: Vector3, to: Vector3, dur: float, trans := Tween.TRANS_QUAD, ez := Tween.EASE_OUT) -> void:
	n.scale = from
	var tw = n.create_tween()
	tw.tween_property(n, "scale", to, maxf(0.01, dur)).set_trans(trans).set_ease(ez)


# ================================================================== parçacıklar (kendi CPUParticles3D ayarları)
## Halka üstünde yönlü noktalar: teğet (dönüş yönünde) + içe + yukarı bileşen
static func _ring(n: int, r0: float, r1: float, y0: float, y1: float, s: float, tang: float, inward: float, up: float) -> Array:
	var pts = PackedVector3Array()
	var nrm = PackedVector3Array()
	for i in n:
		var a = TAU * i / n + randf_range(-0.15, 0.15)
		var rr = randf_range(r0, r1)
		var rad = Vector3(cos(a), 0, sin(a))
		var tg = Vector3(sin(a), 0, -cos(a)) * s
		pts.append(rad * rr + Vector3.UP * randf_range(y0, y1))
		var dv = tg * tang - rad * inward + Vector3.UP * up
		nrm.append(dv.normalized() if dv.length() > 0.001 else Vector3.UP)
	return [pts, nrm]


static func _emit(parent: Node, pts: PackedVector3Array, nrm: PackedVector3Array, mesh: Mesh, cfg: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.mesh = mesh
	p.amount = maxi(1, int(cfg.get("amount", 24) * (0.35 if mesh == _streak_mesh() else 0.5)))   # seyrek: bantlar okunmalı
	p.lifetime = cfg.get("life", 1.0)
	p.lifetime_randomness = cfg.get("life_rand", 0.35)
	p.one_shot = cfg.get("one_shot", false)
	p.explosiveness = cfg.get("explos", 0.95 if p.one_shot else 0.0)
	p.local_coords = cfg.get("local", false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	p.emission_points = pts
	p.emission_normals = nrm
	p.direction = Vector3(0, 0, 1)
	p.spread = cfg.get("spread", 10.0)
	p.gravity = cfg.get("grav", Vector3(0, -2.0, 0))
	p.initial_velocity_min = cfg.get("vmin", 4.0)
	p.initial_velocity_max = cfg.get("vmax", 8.0)
	p.tangential_accel_min = cfg.get("tang", 0.0)
	p.tangential_accel_max = cfg.get("tang", 0.0)
	p.radial_accel_min = cfg.get("radial", 0.0)
	p.radial_accel_max = cfg.get("radial", 0.0)
	p.damping_min = cfg.get("damp", 0.0)
	p.damping_max = cfg.get("damp", 0.0)
	p.scale_amount_min = minf(cfg.get("smin", 1.0), 0.8)
	p.scale_amount_max = minf(cfg.get("smax", 1.0), 1.1)
	p.particle_flag_align_y = cfg.get("align", false)
	if cfg.has("ramp"):
		p.color_ramp = cfg["ramp"]
	if cfg.has("init_ramp"):
		p.color_initial_ramp = cfg["init_ramp"]
	if cfg.get("shrink", false):
		p.scale_amount_curve = _shrink()
	var sp: float = cfg.get("spin", 0.0)
	if sp > 0.0:
		p.angular_velocity_min = -sp
		p.angular_velocity_max = sp
		p.angle_min = -180.0
		p.angle_max = 180.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


## Dönen yağmur çizgileri: teğet hız + içe merkezcil ivme → sarmal yörünge
static func _rain_swirl(parent: Node, r0: float, r1: float, y0: float, y1: float, s: float, amount: int, speed: float, life := 0.7,
		local := false, sz := 1.0, inward := 0.3) -> CPUParticles3D:
	var rp = _ring(maxi(16, amount), r0, r1, y0, y1, s, 1.0, inward, -0.12)
	var rm = maxf(0.4, (r0 + r1) * 0.5)
	return _emit(parent, rp[0], rp[1], _streak_mesh(), {"amount": amount, "life": life, "vmin": speed * 0.8, "vmax": speed * 1.15,
		"grav": Vector3(0, -4.0, 0), "tang": s * speed * 0.25, "radial": -speed * speed / rm * 0.85, "align": true, "local": local,
		"ramp": _rain_ramp(), "smin": 0.6 * sz, "smax": 1.25 * sz})


## Savrulan yaprak + kopuk döküntü (dönen, takla atan, sonunda küçülüp kaybolan)
static func _debris_swirl(parent: Node, r0: float, r1: float, y0: float, y1: float, s: float, amount: int, speed: float, up: float,
		life := 1.2, local := false, one_shot := false, grav_y := -3.0, sz := 1.0, chips := false, inward := 0.25) -> CPUParticles3D:
	var rp = _ring(maxi(12, amount), r0, r1, y0, y1, s, 1.0, inward, up)
	var rm = maxf(0.4, (r0 + r1) * 0.5)
	return _emit(parent, rp[0], rp[1], _chip_mesh() if chips else _leaf_mesh(), {"amount": amount, "life": life, "vmin": speed * 0.7,
		"vmax": speed * 1.2, "grav": Vector3(0, grav_y, 0), "tang": s * speed * 0.4 * (1.0 if grav_y <= 0.0 else -1.0),
		"radial": -speed * speed / rm * (0.6 if not one_shot else 0.0), "local": local, "one_shot": one_shot, "spread": 22.0,
		"init_ramp": _chip_ramp() if chips else _leaf_ramp(), "shrink": true, "spin": 540.0, "smin": 0.8 * sz, "smax": 1.8 * sz, "damp": 0.6})


# ================================================================== ortak evreler: toplanma ve artçı
## TOPLANMA: geniş halkadan içe çekilen sarmal bantlar + merkeze yakınsayan yağmur çizgileri (salınmadan önceki birkaç an)
static func _gather(pj: PathJutsu, pos: Vector3, R: float, dur: float, s: float, h := 1.2) -> void:
	var root = _root(pj, pos)
	var sp = _node(root)
	var sb = Strips.new()
	_arms(sb, R, R * 0.12, h * 0.2, 4, 0.9, R * 0.22, R * 0.04, s, h * 0.5, 0.35, BAND_MID, 22, 0.0, 1.6 / maxf(R, 0.5))
	_arms(sb, R * 0.8, R * 0.1, h * 0.6, 3, 0.8, h * 0.5, h * 0.12, s, h * 0.2, 1.3, BAND_LO, 20, 1.1, 1.6 / maxf(R, 0.5))
	_mi(sp, sb.mesh(), _band_mat(), 2.2, 0.5)
	_spin(sp, 0.45, s)
	_scale_to(sp, Vector3(1.5, 1.0, 1.5), Vector3(0.25, 1.0, 0.25), dur, Tween.TRANS_CUBIC, Tween.EASE_IN)
	var rp = _ring(24, R * 0.9, R * 1.3, 0.1, h, s, 0.6, 1.0, 0.05)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": 28, "life": dur * 0.9, "vmin": R * 1.1 / maxf(dur, 0.1), "vmax": R * 1.5 / maxf(dur, 0.1),
		"grav": Vector3.ZERO, "align": true, "ramp": _rain_ramp(), "explos": 0.3})
	_life(root, dur * 0.35, dur * 0.5, dur * 0.25, 0.4)


## ARTÇI: yere yatmış ot izi (sarmal desen, yavaş söner), yukarıdan süzülen yapraklar, alçak sis topakları, sönen yağmur perdesi
static func _aftermath(pj: PathJutsu, pos: Vector3, R: float, s: float, linger := 3.0, curtains := true) -> void:
	var root = _root(pj, pos)
	var sb = Strips.new()   # yatmış otlar: sarmal boyunca ince yeşil fırça darbeleri
	_arms(sb, R, R * 0.1, 0.06, 6, 0.7, R * 0.14, R * 0.04, s, 0.0, 0.0, GRASS, 24, randf() * TAU, 0.9 / maxf(R * 0.1, 0.3))
	_mi(root, sb.mesh(), _rain_mat(), 0.0, 0.0)
	if curtains:
		var sr = Strips.new()
		_arms(sr, R * 0.9, R * 0.3, 0.2, 2, 0.5, R * 0.25, R * 0.12, s, R * 0.15, 1.45, RAIN, 18, 0.7, 0.35 / maxf(R * 0.1, 0.3))
		var cur = _mi(root, sr.mesh(), _rain_mat(), 0.6, 0.0)
		var ctw = cur.create_tween()
		ctw.tween_method(func(f: float): cur.set_instance_shader_parameter("fade", f), 1.0, 0.0, minf(1.6, linger * 0.5))
	# yukarıdan süzülerek inen yapraklar: düşük yerçekimi, takla atarak
	var lp = PackedVector3Array()
	var ln = PackedVector3Array()
	for i in 20:
		var a = randf() * TAU
		var rr = randf() * R
		lp.append(Vector3(cos(a) * rr, randf_range(2.0, 2.0 + R * 0.5), sin(a) * rr))
		ln.append(Vector3(sin(a) * s, -0.3, -cos(a) * s).normalized())
	_emit(root, lp, ln, _leaf_mesh(), {"amount": clampi(int(R * 3.0), 6, 24), "life": 2.6, "vmin": 0.6, "vmax": 1.6, "grav": Vector3(0, -0.9, 0),
		"one_shot": true, "explos": 0.6, "init_ramp": _leaf_ramp(), "shrink": true, "spin": 300.0, "smin": 0.7, "smax": 1.1, "damp": 0.3, "spread": 40.0})
	_life(root, 0.0, linger * 0.7, 1.0, 0.3)


## Alçak bulut eteği topakları (opak cel, üstü açık altı koyu)
static func _lumps(parent: Node, r: float, n: int, size: float, y := 0.0, dark := false) -> MeshInstance3D:
	var b = MB.new()
	# her topak: yuvarlak, katmanlı bulut kümesi (geniş taban + iki yan kabarık + tepe kabarığı), altı gri, üstü beyaz
	var top = Color.WHITE.darkened(0.06) if dark else Color.WHITE
	var bot = Color(0.48, 0.53, 0.63) if dark else Color(0.58, 0.63, 0.72)
	size = minf(size, 0.7)
	n = mini(n, 12)
	for i in n:
		var a = TAU * i / n + randf_range(-0.25, 0.25)
		var rr = r * randf_range(0.85, 1.1)
		var sz = size * randf_range(0.7, 1.15)
		var c0 = Vector3(cos(a) * rr, y, sin(a) * rr)
		var tg = Vector3(-sin(a), 0, cos(a))
		var rot = Vector3(0, -rad_to_deg(a), 0)
		b.add_grad("sphere", c0 + Vector3.UP * sz * 0.3, Vector3(sz * 1.25, sz * 0.62, sz * 0.95), top, bot, rot, 12)
		b.add_grad("sphere", c0 + tg * sz * 0.5 + Vector3.UP * sz * 0.42, Vector3(sz * 0.75, sz * 0.62, sz * 0.7), top, bot, rot, 12)
		b.add_grad("sphere", c0 - tg * sz * 0.48 + Vector3.UP * sz * 0.38, Vector3(sz * 0.68, sz * 0.56, sz * 0.62), top, bot, rot, 12)
		b.add_grad("sphere", c0 + tg * sz * 0.08 + Vector3.UP * sz * 0.66, Vector3(sz * 0.62, sz * 0.55, sz * 0.58), top, bot, rot, 12)
	return _mi(parent, b.build(), _cloud_mat(), 0.6, 0.6)


# ================================================================== yapı taşları: fırtına gövdeleri
## Tam tayfun: sakin göz + göz duvarı (iki kat) + üç katta sarmal yağmur bantları (yatay bant + dikey perde) + bant içinde
## yağmur perdeleri + tepe örtüsü + taban bulut eteği + dönen yağmur + savrulan yaprak / döküntü
static func _cyclone(pj: PathJutsu, pos: Vector3, R: float, H: float, eye: float, s: float, dens := 1.0) -> Node3D:
	var root = _root(pj, pos)
	var core = _node(root)
	var body = _node(root)
	var skirt = _node(root)
	var us = 0.35 / maxf(R * 0.25, 0.3)
	var sw = Strips.new()
	_wall(sw, eye, eye * 1.55, H, int(9 * dens) + 5, 1.6, s, BAND_HI, 0.0, 16, 1.7, us * 1.4)
	_wall(sw, eye * 1.12, eye * 1.95, H * 0.82, int(5 * dens) + 3, 2.3, s, BAND_LO, H * 0.04, 14, 1.4, us * 1.4)
	_mi(core, sw.mesh(), _band_mat(), 1.6, 0.4)
	var sa = Strips.new()
	var lv_y = [0.04, 0.3, 0.58]
	var lv_c = [BAND_DEEP, BAND_LO, BAND_MID]
	for lv in 3:
		var y = H * lv_y[lv]
		var ro = R * (1.0 - lv * 0.12)
		_arms(sa, ro, eye * 1.35, y, int(3 * dens) + 1, 0.85, ro * 0.32, eye * 0.8, s, H * 0.04, 0.32, lv_c[lv], 26, lv * 0.9, us)
		_arms(sa, ro * 0.92, eye * 1.5, y + H * 0.05, 2, 0.7, H * 0.13, eye * 0.7, s, H * 0.02, 1.32, lv_c[lv], 22, lv * 0.9 + 1.0, us)
	_mi(body, sa.mesh(), _band_mat(), 1.0, 1.0)
	var sr = Strips.new()
	_arms(sr, R * 0.95, eye * 1.8, H * 0.08, int(dens) + 1, 0.75, H * 0.14, H * 0.07, s, H * 0.18, 1.45, RAIN, 22, 0.5, 0.06 * 8.0 / maxf(R, 1.0))
	_mi(body, sr.mesh(), _rain_mat(), 1.4, 0.0)
	var sc = Strips.new()
	_arms(sc, R * 1.28, eye * 1.7, H * 0.9, int(3 * dens) + 2, 0.55, R * 0.42, eye * 1.1, s, H * 0.08, 0.12, BAND_LO, 24, 0.3, us)
	_mi(body, sc.mesh(), _band_mat(), 0.8, 1.0)
	_lumps(skirt, R * 0.95, int(10 * dens) + 4, 0.7)
	var sk = Strips.new()
	_ring_band(sk, R * 0.72, R * 1.05, 0.25, 7, BAND_DEEP, us, 0.2, 0.15)
	_mi(skirt, sk.mesh(), _band_mat(), 0.7, 0.6)
	_spin(core, maxf(0.35, R * 0.11), s)
	_spin(body, maxf(0.6, R * 0.22), s)
	_spin(skirt, maxf(1.0, R * 0.42), s)
	var big = maxf(1.0, R / 3.0)
	_rain_swirl(root, eye * 1.6, R, H * 0.05, H * 0.6, s, int(55 * dens * big), 6.0 + R, 0.7, false, minf(2.0, big * 0.8))
	_debris_swirl(root, eye * 2.0, R * 0.9, 0.2, H * 0.25, s, int(26 * dens * big), 4.0 + R * 0.6, 0.6, 1.4, false, false, 1.2, minf(2.2, big * 0.7))
	_debris_swirl(root, eye * 2.0, R * 0.8, 0.1, 0.6, s, int(12 * dens * big), 3.0 + R * 0.5, 0.9, 1.0, false, false, -5.0, minf(2.0, big * 0.7), true)
	return root


## Ufak sarmal parlama (atış kapılınca / geri savrulunca): yassı kollar + dışa saçılan yağmur kıymıkları
static func _gust_pop(pj: PathJutsu, pos: Vector3, size: float, tint := Color.WHITE) -> void:
	var root = _root(pj, pos)
	var sp = _node(root)
	var sb = Strips.new()
	_arms(sb, size * 1.2, size * 0.12, 0.0, 3, 0.8, size * 0.38, size * 0.06, 1.0, size * 0.1, 0.4, tint, 16, randf() * TAU, 1.2 / maxf(size, 0.3))
	_mi(sp, sb.mesh(), _band_mat(), 2.8, 0.0)
	_spin(sp, 0.3, 1.0)
	_scale_to(sp, Vector3.ONE * 0.45, Vector3.ONE * 1.45, 0.3)
	var rp = _ring(16, 0.1, size * 0.3, -0.1, 0.1, 1.0, 0.5, -1.0, 0.15)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": int(12 + size * 6), "life": 0.35, "vmin": 6.0 * size, "vmax": 10.0 * size,
		"one_shot": true, "align": true, "grav": Vector3(0, -6, 0), "ramp": _rain_ramp(), "smin": 0.5, "smax": 1.0 * maxf(1.0, size)})
	if size > 1.5:
		_debris_swirl(root, 0.2, size * 0.5, 0.0, 0.4, 1.0, int(size * 6), size * 3.0, 0.6, 1.0, false, true, -6.0, 1.2)
	_life(root, 0.0, 0.18, 0.18, 0.6)


## Yerden göğe ince halat hortum: dar taban, geniş tepe, ortada parlak çekirdek, tepede yayılan bulut kolları,
## tabanda çalkalanan toz-bulut eteği; yükselen döküntü
static func _rope_tornado(pj: PathJutsu, pos: Vector3, r: float, h: float, s: float) -> Node3D:
	var root = _root(pj, pos)
	var funnel = _node(root)
	var corez = _node(root)
	var cap = _node(root)
	var base = _node(root)
	var us = 0.9 / maxf(r, 0.5)
	var sw = Strips.new()
	_wall(sw, r * 0.3, r * 1.15, h, 8, 3.2, s, BAND_MID, 0.0, 18, 1.5, us)
	_wall(sw, r * 0.38, r * 1.3, h * 0.9, 5, 2.4, s, BAND_DEEP, 0.1, 16, 1.2, us)
	_mi(funnel, sw.mesh(), _band_mat(), 2.0, 0.8)
	var sc = Strips.new()
	_wall(sc, r * 0.12, r * 0.5, h * 0.95, 3, 4.5, s, BAND_HI, 0.0, 18, 1.1, us * 1.5)
	_mi(corez, sc.mesh(), _band_mat(), 3.0, 0.0)
	var sr = Strips.new()
	_wall(sr, r * 0.5, r * 1.4, h * 0.85, 3, 2.0, s, RAIN, 0.2, 14, 1.0, 0.2)
	_mi(funnel, sr.mesh(), _rain_mat(), 2.2, 0.0)
	var sa = Strips.new()
	_arms(sa, r * 2.4, r * 1.0, h * 0.94, 4, 0.55, r * 0.9, r * 0.35, s, h * 0.06, 0.2, BAND_LO, 20, 0.0, us * 0.8)
	_arms(sa, r * 2.0, r * 0.9, h * 0.88, 2, 0.5, h * 0.18, h * 0.08, s, 0.0, 1.3, BAND_DEEP, 18, 1.3, us * 0.8)
	_mi(cap, sa.mesh(), _band_mat(), 1.0, 1.0)
	_lumps(base, r * 0.95, 9, r * 0.42)
	var sk = Strips.new()
	_ring_band(sk, r * 0.5, r * 1.5, 0.15, 5, BAND_DEEP, us, 0.25, 0.2)
	_mi(base, sk.mesh(), _band_mat(), 1.2, 0.0)
	_spin(funnel, 0.42, s)
	_spin(corez, 0.22, s)
	_spin(cap, 1.1, s)
	_spin(base, 0.7, s)
	_rain_swirl(root, r * 0.4, r * 1.2, 0.3, h * 0.8, s, 50, 9.0, 0.55, false, 1.0, 0.15)
	_debris_swirl(root, r * 0.4, r * 0.9, 0.0, 0.5, s, 34, 6.0, 1.3, 1.3, false, false, 1.5, 1.0)
	_debris_swirl(root, r * 0.3, r * 0.8, 0.0, 0.3, s, 14, 5.0, 1.0, 1.1, false, false, 0.5, 1.0, true)
	return root


# ================================================================== 1) Kyōfū Reppa — art arda patlayan dört eğik girdap
## Her girdap: öne eğik, basık, patlayarak genişleyen bir tayfun düğümü (huni duvarı + yerde dışa açılan sarmal kollar + koyu
## görüş kapatan bulut eteği) ve önüne doğru biçen yatay yağmur perdeleri
static func _gale_vortex(pj: PathJutsu, cen: Vector3, d: Vector3, size: float, s: float) -> void:
	var sd = d.cross(Vector3.UP).normalized()
	var root = _root(pj, cen)
	root.basis = Basis(sd, -0.28)   # tepesi ileri eğik
	var body = _node(root)
	var low = _node(root)
	var R = 2.6 * size
	var H = 5.0 * size
	var us = 0.35 / maxf(R * 0.25, 0.3)
	var sw = Strips.new()
	_wall(sw, 0.45 * size, R * 0.85, H, 9, 2.0, s, BAND_MID, 0.0, 16, 1.5, us * 1.5)
	_wall(sw, 0.6 * size, R * 0.95, H * 0.8, 5, 2.6, s, BAND_DEEP, 0.1, 14, 1.3, us * 1.5)
	_wall(sw, 0.25 * size, R * 0.4, H * 0.9, 3, 4.0, s, BAND_HI, 0.0, 14, 1.0, us * 2.0)
	_mi(body, sw.mesh(), _band_mat(), 2.4, 1.0)
	var sa = Strips.new()
	_arms(sa, R * 1.25, 0.55 * size, 0.15, 4, 0.8, R * 0.42, 0.3, s, 0.3, 0.22, BAND_LO, 22, 0.0, us)
	_arms(sa, R * 1.1, 0.6 * size, 0.4, 3, 0.7, H * 0.2, 0.3, s, 0.2, 1.35, BAND_DEEP, 20, 1.0, us)
	_arms(sa, R * 1.15, 0.8 * size, H * 0.92, 3, 0.6, R * 0.38, 0.4, s, H * 0.06, 0.15, BAND_MID, 20, 0.6, us)
	_mi(low, sa.mesh(), _band_mat(), 1.8, 1.0)
	_lumps(low, R * 0.85, 10, 0.6 * size, 0.0, true)   # görüşü kapatan bulut eteği
	var sr = Strips.new()
	_wall(sr, 0.7 * size, R * 1.0, H * 0.75, 3, 2.2, s, RAIN, 0.2, 12, 1.0, 0.25)
	_mi(body, sr.mesh(), _rain_mat(), 2.5, 0.0)
	_spin(body, 0.34, s)
	_spin(low, 0.6, s)
	_scale_to(root, Vector3.ONE * 0.25, Vector3.ONE * 1.25, 0.95, Tween.TRANS_EXPO, Tween.EASE_OUT)   # patlayarak açılır
	_rain_swirl(root, 0.6, R, 0.2, H * 0.7, s, 46, 10.0, 0.5, false, 1.0)
	# önüne biçen yatay yağmur perdeleri (dönmeyen ayrı düğüm, ileri kayar)
	var shear = _root(pj, cen)
	var sh = Strips.new()
	for q in 5:
		var yy = 0.5 + q * 0.5
		var fan = (q - 2) * 0.12
		var dq = d.rotated(Vector3.UP, fan)
		var pts = []
		var sides = []
		var cols = []
		for k in 13:
			var u = k / 12.0
			pts.append(dq * (u * 5.5 * size) + sd * sin(u * PI + q) * 0.3 + Vector3.UP * (yy + sin(u * 4.0 + q) * 0.15))
			sides.append((Vector3.UP * 0.35 + dq.cross(Vector3.UP) * 0.08) * (0.4 + u * 0.6) * size)
			cols.append(_ca(Color.WHITE, minf(u, 1.0 - u) * 5.0))
		sh.strip(pts, sides, cols, _us(pts, 0.22))
	_mi(shear, sh.mesh(), _rain_mat(), 3.5, 0.0)
	var mv = shear.create_tween()
	mv.tween_property(shear, "global_position", cen + d * 3.0 * size, 0.6).set_ease(Tween.EASE_OUT)
	_life(shear, 0.05, 0.3, 0.3, 0.1)
	# ileri savrulan yaprak ve yonga
	var fp = PackedVector3Array()
	var fnr = PackedVector3Array()
	for i in 16:
		var a = randf() * TAU
		fp.append(Vector3(cos(a), 0.2, sin(a)) * randf_range(0.3, R * 0.6))
		fnr.append((d * 1.4 + Vector3(cos(a), 0, sin(a)) * 0.6 + Vector3.UP * randf_range(0.3, 1.1)).normalized())
	_emit(shear, fp, fnr, _leaf_mesh(), {"amount": 26, "life": 1.1, "vmin": 7.0, "vmax": 13.0, "one_shot": true, "grav": Vector3(0, -7, 0),
		"init_ramp": _leaf_ramp(), "shrink": true, "spin": 720.0, "smin": 1.0, "smax": 2.0, "damp": 1.5, "spread": 25.0})
	_emit(shear, fp, fnr, _chip_mesh(), {"amount": 12, "life": 0.9, "vmin": 6.0, "vmax": 11.0, "one_shot": true, "grav": Vector3(0, -12, 0),
		"init_ramp": _chip_ramp(), "shrink": true, "spin": 600.0, "smin": 0.9, "smax": 1.6, "spread": 25.0})
	_life(root, 0.08, 0.5, 0.35, 0.8)


static func kyofu_reppa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "taiton_kyofu_reppa"
	var tt = pj.tg(c, t, 26.0)
	var d: Vector3 = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var sd = d.cross(Vector3.UP).normalized()
	Sfx.play("wind", c.global_position, 0.6)
	# toplanma: mühür sırasında avuçların önünde bantlar içe çekilir
	_gather(pj, c.global_position + Vector3.UP * 0.9 + d * 0.8, 2.2, 0.32, 1.0, 1.0)
	for k in 4:   # dört art arda patlayan girdap, her biri daha uzağa
		pj.after(0.15 + k * 0.18, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var cen: Vector3 = pj.gp(cc.global_position + d * (3.5 + k * 3.2) + sd * (1.2 if k % 2 == 0 else -1.2))
			_gale_vortex(pj, cen, d, 0.85 + k * 0.1, 1.0 if k % 2 == 0 else -1.0)
			if k == 3:   # artçı: dört girdabın yolu boyunca yatmış otlar, süzülen yapraklar
				_aftermath(pj, pj.gp(cc.global_position + d * 8.0), 7.0, 1.0, 3.0, true)
			Sfx.play("wind", cen, 0.8 + k * 0.1)
			for e in pj.enemies_near(cc, cen, 3.0):
				var v: Vector3 = e.global_position - cen
				v.y = 0
				e.take_hit(pj.inf(cc, id, 0.95, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "element": "taiton", "bleed": 2.0, "hitstop": 0.04, "dir": (d + v.normalized() * 0.5).normalized()}))
				if e.has_method("lose_target"):
					e.lose_target(0.8))   # görüşü kapatır


# ================================================================== 2) Mōfū Daireppa — gözü olan dev tayfun
static func mofu_daireppa(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 4.2)
	var id = "taiton_mofu_daireppa"
	pj._yama_seal(c)
	var cw = weakref(c)
	var R := 9.0
	var H := 22.0
	var cen0: Vector3 = pj.gp(c.global_position)
	Sfx.play("wind", cen0, 0.4)
	c.set_meta("taiton_eye_until", Time.get_ticks_msec() + 4200)
	# görünüş: tek bir tayfun sistemi; eski büyüme eğrisi (0.84 sn'de tam boy, son %10'da söner) ölçek + sönmeyle
	_gather(pj, cen0 + Vector3.UP * 1.0, R * 1.3, 0.7, 1.0, 4.0)
	var storm = _cyclone(pj, cen0, R, H, 2.2, 1.0, 1.0)
	_scale_to(storm, Vector3.ONE * 0.25, Vector3.ONE, 0.84, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_life(storm, 0.3, 3.45, 0.42, 1.2)
	var stw = weakref(storm)
	pj.after(3.78, func():
		var st = stw.get_ref()
		if st != null:
			var tw = st.create_tween()
			tw.tween_property(st, "scale", Vector3(1.25, 0.35, 1.25), 0.42).set_ease(Tween.EASE_IN))
	pj.after(4.0, func():   # artçı: geniş yatmış ot sarmalı, yere çöken bulut, süzülen yapraklar
		_aftermath(pj, cen0, R * 1.1, 1.0, 4.0, true))
	var spin = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if "velocity" in cc:
			cc.velocity = Vector3.ZERO
		if i % 4 == 0:
			for e in pj.enemies_near(cc, cen0, R + 4.0):
				var v: Vector3 = e.global_position - cen0
				v.y = 0
				var dh = v.length()
				if dh < 2.2:   # fırtınanın gözü: sakin; içeri girenin vuruşu yapanı savunmasız yakalar
					continue
				var tang = Vector3(-v.z, 0, v.x).normalized()
				e.take_hit(pj.inf(cc, id, 0.24, {"knock": 9.0, "launch": 5.0, "kind": "heavy", "element": "taiton", "bleed": 1.5, "hitstop": 0.02, "dir": (tang + v.normalized() * 0.6).normalized()}))
				if e.has_method("lose_target") and dh > 2.2:
					e.lose_target(0.5)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):   # atışlar kasırgaya kapılıp savrulur
			if is_instance_valid(p) and p.get("shooter") != cc:
				var pv: Vector3 = p.global_position - cen0
				if Vector2(pv.x, pv.z).length() < R + 1.0 and Vector2(pv.x, pv.z).length() > 2.2 and pv.y < H:
					_gust_pop(pj, p.global_position, 0.8)
					p.queue_free()
	pj.every(4.2, 0.05, spin, func():
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			cc.remove_meta("taiton_eye_until"))
	var mods = {"armor": 2.0, "_name": "Fırtınanın gözü", "_desc": "kasırga sürerken içinde savunmasızsın: içeri giren seni ağır vurur"}
	if c is Player:   # kanon zayıflığı: göze ulaşan darbe iki kat işler
		Buffs.add("taiton_eye", 4.2, mods)
	elif c.has_method("add_buff"):
		c.add_buff("taiton_eye", 4.2, mods)


# ================================================================== 3) Reppū Shuriken — chakra sarılı bıçaklar, arkada mini siklon
## Çarpma: chakra mavisi-beyaz yassı sarmal patlama + kısa dikey girdap + dışa saçılan yağmur kıymıkları + yaprak
static func _chakra_burst(pj: PathJutsu, pos: Vector3, R: float) -> void:
	var root = _root(pj, pos)
	var flat = _node(root)
	var up = _node(root)
	var sb = Strips.new()
	_arms(sb, R, 0.15, 0.0, 4, 0.9, R * 0.4, 0.1, 1.0, 0.2, 0.3, CHAKRA, 18, randf() * TAU, 1.4 / R)
	_ring_band(sb, R * 0.75, R * 1.05, 0.05, 6, BAND_HI, 1.0 / R, 0.3, 0.1)
	_mi(flat, sb.mesh(), _band_mat(), 3.2, 0.0)
	var sw = Strips.new()
	_wall(sw, 0.2, R * 0.55, R * 1.2, 5, 3.0, 1.0, Color(0.85, 0.96, 1.0), -0.3, 12, 1.2, 1.2 / R)
	_mi(up, sw.mesh(), _band_mat(), 3.5, 0.0)
	_spin(flat, 0.28, 1.0)
	_spin(up, 0.2, 1.0)
	_scale_to(flat, Vector3.ONE * 0.3, Vector3.ONE * 1.15, 0.22)
	_scale_to(up, Vector3(0.6, 0.2, 0.6), Vector3(1.0, 1.0, 1.0), 0.18)
	var rp = _ring(20, 0.1, 0.4, -0.2, 0.3, 1.0, 0.6, -1.0, 0.25)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": 30, "life": 0.4, "vmin": 10.0, "vmax": 16.0, "one_shot": true, "align": true,
		"grav": Vector3(0, -8, 0), "ramp": _chakra_ramp(), "smin": 0.6, "smax": 1.3})
	_debris_swirl(root, 0.1, 0.6, -0.2, 0.3, 1.0, 14, 7.0, 0.8, 1.0, false, true, -8.0, 1.2)
	_life(root, 0.0, 0.2, 0.3, 0.9)


static func reppu_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "taiton_reppu_shuriken"
	var tt = pj.tg(c, t, 34.0)
	var d: Vector3 = pj._face(c, tt)
	pj.anim(c, "throw", 1.8)
	var cw = weakref(c)
	# toplanma: elde dönen küçük chakra sarmalı (atış dizisi boyunca)
	_gather(pj, pj.hand_pos(c), 0.9, 0.3, 1.0, 0.4)
	for k in 5:
		pj.after(0.06 + k * 0.06, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var from: Vector3 = pj.hand_pos(cc)
			var dk: Vector3 = pj.aim_at(cc, tt, from).rotated(Vector3.UP, (k - 2) * 0.07)
			var b = MB.new()
			for q in 4:
				b.add("prism", Vector3(cos(q * PI * 0.5), 0, sin(q * PI * 0.5)) * 0.14, Vector3(0.1, 0.02, 0.26), Color(0.7, 0.72, 0.76), Vector3(0, -q * 90.0, 0), 3)
			b.add("cyl", Vector3.ZERO, Vector3(0.08, 0.03, 0.08), Color(0.25, 0.25, 0.28))
			var sh = Node3D.new()
			var blade = Node3D.new()
			sh.add_child(blade)
			var bm = MeshInstance3D.new()
			bm.mesh = b.build(Props.toon())
			blade.add_child(bm)
			# chakra sargısı: bıçağın çevresinde kopuk dönen mavi-beyaz bant + iki eğik sargı
			var wr = Strips.new()
			_ring_band(wr, 0.26, 0.42, 0.0, 3, CHAKRA, 2.5, 0.15, 0.0)
			_ring_band(wr, 0.2, 0.32, 0.0, 2, Color(0.9, 0.98, 1.0), 3.0, 0.3, 0.9)
			_mi(blade, wr.mesh(), _band_mat(), 4.0, 0.0)
			# arkada sürüklenen sıkı mini siklon (atış -Z'ye bakar; iz +Z yönünde)
			var tail = Node3D.new()
			tail.rotation.x = PI * 0.5
			sh.add_child(tail)
			var tsp = _node(tail)
			var tw_ = Strips.new()
			_wall(tw_, 0.1, 0.5, 1.9, 3, 7.0, 1.0, Color(0.82, 0.94, 1.0), 0.1, 16, 0.9, 1.6)
			_wall(tw_, 0.16, 0.62, 1.4, 2, 5.0, 1.0, BAND_LO, 0.25, 12, 0.8, 1.6)
			_mi(tsp, tw_.mesh(), _band_mat(), 4.5, 0.0)
			_spin(tsp, 0.16, 1.0)
			_spin(blade, 0.2, 1.0)
			# dünya uzayında kalan yağmur-chakra çizgi izi
			var tp = PackedVector3Array()
			var tn = PackedVector3Array()
			for q in 10:
				var a = TAU * q / 10.0
				tp.append(Vector3(cos(a) * 0.18, sin(a) * 0.18, 0.25))
				tn.append((Vector3(-sin(a), cos(a), 0) + Vector3(0, 0, 0.6)).normalized())
			var trail = _emit(sh, tp, tn, _streak_mesh(), {"amount": 26, "life": 0.32, "vmin": 1.5, "vmax": 3.0, "grav": Vector3.ZERO,
				"align": true, "ramp": _chakra_ramp(), "smin": 0.35, "smax": 0.7})
			var trw = weakref(trail)
			var pr = pj.shot(cc, from, dk, 52.0, sh, pj.inf(cc, id, 0.45, {"knock": 3.0, "kind": "light", "element": "taiton", "bleed": 2.0}), tt, false, 1.4, func(p, _h):
				var c2 = cw.get_ref()
				var tr = trw.get_ref()
				if tr != null and is_instance_valid(tr):   # iz söner, mermiyle birlikte kopup gitmez
					tr.emitting = false
					tr.reparent(pj.get_tree().current_scene)
					pj.get_tree().create_timer(0.5).timeout.connect(tr.queue_free)
				_chakra_burst(pj, p, 2.2)   # rüzgâr chakrası patlar
				Sfx.play("boom", p, 1.4, 0.6)
				if c2 != null and pj.live(c2):
					pj.hit(c2, p, 2.4, pj.inf(c2, id, 0.4, {"knock": 10.0, "launch": 3.0, "kind": "heavy", "element": "taiton"})))
			pr.radius = 0.35)
	Sfx.play("throw_kunai", c.global_position, 1.3)


# ================================================================== 4) Senpū Tatsumaki — yürüyen, kaldıran hortum
static func senpu_tatsumaki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "taiton_senpu_tatsumaki"
	var tt = pj.tg(c, t, 24.0)
	var d: Vector3 = pj._face(c, tt)
	pj.anim(c, "push", 1.4)
	var cw = weakref(c)
	var start: Vector3 = c.global_position + d * 2.0
	var L = 18.0
	var DUR = 2.6
	Sfx.play("wind", start, 0.5)
	_gather(pj, pj.gp(start), 3.0, 0.3, 1.0, 2.5)
	var tor = _rope_tornado(pj, pj.gp(start), 1.8, 6.5, 1.0)
	_scale_to(tor, Vector3(0.4, 0.1, 0.4), Vector3.ONE, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)   # yerden göğe uzanarak doğar
	_life(tor, 0.15, DUR - 0.2, 0.45, 1.3)
	var tw = weakref(tor)
	var trail = {"n": 0}
	pj.every(DUR, 0.05, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var cen: Vector3 = pj.gp(start + d * L * k + d.cross(Vector3.UP) * sin(k * 9.0) * 0.8)
		var tn = tw.get_ref()
		if tn != null:
			var mv = tn.create_tween()
			mv.tween_property(tn, "global_position", cen, 0.05)
		if i % 13 == 6 and trail["n"] < 3:   # artçı: geçtiği yolda yatmış ot sarmalları
			trail["n"] += 1
			_aftermath(pj, cen, 2.6, 1.0, 2.5, false)
		if i % 3 == 0:
			for e in pj.enemies_near(cc, cen, 2.4):
				var v: Vector3 = cen - e.global_position
				v.y = 0
				if e is CharacterBody3D:
					e.velocity = v * 4.0 + d * 6.0 + Vector3.UP * 6.0
				e.take_hit(pj.inf(cc, id, 0.22, {"knock": 0.5, "launch": 4.0, "kind": "light", "element": "taiton", "bleed": 1.0, "hitstop": 0.0, "dir": Vector3.UP}))
		if i % 10 == 0:
			Sfx.play("wind", cen, 0.7))


# ================================================================== 5) Tenkū Rasen Otoshi — göğe sıçrayıp sütunla çakılma
## Dalış sütunu: atanı saran, yukarı doğru açılan sıkı tayfun kılıfı (yükselirken yağmuru emer, inerken arkada iz bırakır)
static func _dive_column(pj: PathJutsu, pos: Vector3) -> Node3D:
	var root = _root(pj, pos)
	var sp = _node(root)
	var sp2 = _node(root)
	var sw = Strips.new()
	_wall(sw, 0.9, 2.6, 4.2, 8, 3.0, 1.0, BAND_MID, -0.2, 16, 1.4, 0.5)
	_wall(sw, 1.1, 2.9, 3.4, 4, 2.2, 1.0, BAND_DEEP, 0.2, 12, 1.2, 0.5)
	_mi(sp, sw.mesh(), _band_mat(), 2.6, 0.8)
	var sr = Strips.new()
	_wall(sr, 1.0, 2.4, 3.8, 3, 2.5, 1.0, RAIN, 0.0, 12, 1.0, 0.3)
	_arms(sr, 3.2, 1.0, 3.6, 3, 0.5, 1.2, 0.5, 1.0, 0.4, 1.3, RAIN, 14, 0.0, 0.3)
	_mi(sp2, sr.mesh(), _rain_mat(), 2.8, 0.0)
	_spin(sp, 0.25, 1.0)
	_spin(sp2, 0.4, 1.0)
	_rain_swirl(root, 0.9, 2.2, 0.0, 3.5, 1.0, 50, 9.0, 0.45, false, 1.0, 0.2)
	_debris_swirl(root, 1.0, 2.0, 0.0, 3.0, 1.0, 16, 6.0, 0.5, 0.9, false, false, -2.0, 1.0)
	return root


## Çakılma: yere yayılan yassı sarmal bantlar, dışa kayan 10 yatay yağmur perdesi, dışa savrulan bulut eteği,
## yerde kalan koyu basınç halkası, göğe saçılan taş / yaprak
static func _slam(pj: PathJutsu, at: Vector3, R: float) -> void:
	var root = _root(pj, at)
	var flat = _node(root)
	var rays = _node(root)
	var skirt = _node(root)
	var us = 1.4 / R
	var sb = Strips.new()
	_arms(sb, R, 0.5, 0.25, 5, 0.85, R * 0.35, 0.3, 1.0, 0.4, 0.25, BAND_MID, 24, 0.0, us)
	_arms(sb, R * 0.85, 0.6, 0.5, 3, 0.7, 1.5, 0.4, 1.0, 0.3, 1.3, BAND_DEEP, 20, 1.2, us)
	_mi(flat, sb.mesh(), _band_mat(), 3.0, 1.0)
	_spin(flat, 0.5, 1.0)
	_scale_to(flat, Vector3(0.25, 1.0, 0.25), Vector3(1.1, 0.7, 1.1), 0.35, Tween.TRANS_EXPO, Tween.EASE_OUT)
	var sr = Strips.new()
	for q in 10:   # yerden kalkıp dışa kayan yatay yağmur perdeleri
		var a = q * TAU / 10.0
		var dir = Vector3(cos(a), 0, sin(a))
		var side = dir.cross(Vector3.UP)
		var pts = []
		var sides = []
		var cols = []
		for k in 11:
			var u = k / 10.0
			pts.append(dir * (0.5 + u * 7.0) + Vector3.UP * (0.4 + sin(u * PI) * 0.6))
			sides.append((Vector3.UP * 0.45 + side * 0.15) * (0.4 + sin(u * PI) * 0.8))
			cols.append(_ca(Color.WHITE, minf(u, 1.0 - u) * 5.0))
		sr.strip(pts, sides, cols, _us(pts, 0.3))
	_mi(rays, sr.mesh(), _rain_mat(), 3.0, 0.0)
	_scale_to(rays, Vector3(0.2, 1.0, 0.2), Vector3(R / 7.0, 1.0, R / 7.0), 0.4, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_lumps(skirt, R * 0.3, 12, 0.5)
	_scale_to(skirt, Vector3(0.6, 1.0, 0.6), Vector3(1.8, 0.8, 1.8), 0.6, Tween.TRANS_EXPO, Tween.EASE_OUT)
	var ss = Strips.new()   # koyu basınç halkası (çatlak yerine: ezilmiş zemin)
	_ring_band(ss, 1.0, 3.6, 0.04, 9, Color(0.36, 0.38, 0.42), 1.2, 0.12, 0.0)
	var scar = _mi(root, ss.mesh(), _band_mat(), 0.05, 0.0)
	var stw = scar.create_tween()
	stw.tween_interval(1.4)
	stw.tween_method(func(f: float): scar.set_instance_shader_parameter("fade", f), 1.0, 0.0, 0.8)
	_debris_swirl(root, 0.3, 1.5, 0.0, 0.3, 1.0, 26, 11.0, 1.4, 1.3, false, true, -14.0, 1.4, true)
	_debris_swirl(root, 0.3, 2.0, 0.0, 0.3, 1.0, 28, 9.0, 0.8, 1.6, false, true, -5.0, 1.5)
	var rp = _ring(24, 0.3, 1.0, 0.1, 0.6, 1.0, 0.4, -1.0, 0.1)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": 40, "life": 0.45, "vmin": 14.0, "vmax": 20.0, "one_shot": true, "align": true,
		"grav": Vector3(0, -5, 0), "ramp": _rain_ramp(), "smin": 1.0, "smax": 1.8})
	_life(root, 0.0, 0.45, 0.5, 0.8)


static func tenku_rasen_otoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 1.3)
	var id = "taiton_tenku_rasen_otoshi"
	var d: Vector3 = pj._face(c, tt)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var cw = weakref(c)
	var p0: Vector3 = c.global_position
	pj.anim(c, "jump", 1.4)
	Sfx.play("wind", p0, 0.6)
	_gather(pj, p0, 3.5, 0.4, 1.0, 1.5)   # sıçrayış: yerdeki yağmur kolları atanın altına toplanır
	var col = _dive_column(pj, p0 - Vector3.UP * 1.0)
	_scale_to(col, Vector3.ONE * 0.4, Vector3.ONE, 0.25)
	_life(col, 0.1, 0.85, 0.2, 0.6)
	var colw = weakref(col)
	pj.every(0.9, 1.0 / 60.0, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var top = p0.lerp(at, 0.5) + Vector3.UP * 9.0
		var p: Vector3
		if k < 0.55:
			var u = k / 0.55
			p = p0.lerp(top, u) + Vector3.UP * sin(u * PI * 0.5) * 1.5
		else:
			var u = (k - 0.55) / 0.45
			p = top.lerp(at, u * u)
		cc.global_position = p
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		if "facing" in cc:
			cc.facing += 0.45
		var cl = colw.get_ref()
		if cl != null:
			cl.global_position = p - Vector3.UP * 1.0
			if k >= 0.55:   # dalışta sütun aşağı uzar: arkada yükselen kuyruk
				cl.set_scale(Vector3(1.0 - (k - 0.55) * 0.5, 1.0 + (k - 0.55) * 1.6, 1.0 - (k - 0.55) * 0.5)), func():
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		if not pj.live(cc):
			return
		pj._face(cc, tt if tt != null and is_instance_valid(tt) else null)
		pj._kick_pose(cc, 0.3)
		pj.shake(0.6)
		_slam(pj, at, 7.0)
		_aftermath(pj, at, 6.5, 1.0, 3.5, true)
		Sfx.play("boom", at, 0.8)
		for e in pj.enemies_near(cc, at, 5.0):
			var v: Vector3 = e.global_position - at
			v.y = 0
			var near = v.length() < 2.0 + e.radius
			e.take_hit(pj.inf(cc, id, 1.6 if near else 0.8, {"knock": 16.0, "launch": 6.0, "kind": "heavy", "element": "taiton", "bleed": 2.0, "hitstop": 0.1, "dir": v.normalized() if v.length() > 0.1 else d})))


# ================================================================== 6) Bōfū no Yoroi — dönen tayfun zırhı
## Bedene oturan sıkı fırtına kılıfı: iki kat göz duvarı şeridi, dışta yağmur bandı sarmalları, üst / alt yaka bantları,
## kılıfla birlikte dönen yağmur çizgileri, ayak dibinde küçük bulut eteği
static func _sleeve(_pj: PathJutsu, c: Node3D) -> Node3D:
	var root = Node3D.new()
	c.add_child(root)
	root.position = Vector3.ZERO
	var inner = _node(root)
	var outer = _node(root)
	var feet = _node(root)
	var sw = Strips.new()
	_wall(sw, 0.95, 1.12, 2.15, 6, 1.6, 1.0, BAND_HI, 0.0, 14, 0.75, 1.2)
	_mi(inner, sw.mesh(), _band_mat(), 3.0, 0.0)
	var so = Strips.new()
	_wall(so, 1.15, 1.32, 2.0, 3, 3.4, 1.0, BAND_LO, 0.05, 18, 0.9, 1.0)
	_ring_band(so, 1.0, 1.45, 0.12, 4, BAND_DEEP, 1.4, 0.18, 0.3)
	_ring_band(so, 0.95, 1.35, 2.05, 4, BAND_MID, 1.4, 0.18, -0.3)
	_mi(outer, so.mesh(), _band_mat(), 2.0, 1.0)
	_lumps(feet, 1.15, 7, 0.4)
	_spin(inner, 0.32, 1.0)
	_spin(outer, 0.5, 1.0)
	_spin(feet, 0.9, 1.0)
	var rp = _ring(24, 1.05, 1.3, 0.2, 1.9, 1.0, 1.0, 0.0, 0.05)
	_emit(inner, rp[0], rp[1], _streak_mesh(), {"amount": 36, "life": 0.4, "vmin": 6.0, "vmax": 8.0, "local": true, "grav": Vector3(0, -1, 0),
		"tang": 0.0, "radial": -40.0, "align": true, "ramp": _rain_ramp(), "smin": 0.5, "smax": 0.9})
	_debris_swirl(outer, 1.1, 1.3, 0.1, 1.6, 1.0, 12, 6.0, 0.3, 0.8, true, false, -1.0, 0.8)
	return root


static func bofu_no_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var id = "taiton_bofu_no_yoroi"
	pj._yama_seal(c)
	var DUR = 6.0
	var mods = {"armor": 0.7, "_name": "Bōfū no Yoroi", "_desc": "tayfun zırhı: atışlar geri savrulur, yakın darbeler yumuşar"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)
	var cw = weakref(c)
	Sfx.play("wind", c.global_position, 0.7)
	_gather(pj, c.global_position + Vector3.UP * 0.2, 2.6, 0.35, 1.0, 2.0)
	var slv = _sleeve(pj, c)
	_scale_to(slv, Vector3(1.8, 0.2, 1.8), Vector3.ONE, 0.35, Tween.TRANS_BACK, Tween.EASE_OUT)   # dışarıdan sıkışarak oturur
	var ltw = _life(slv, 0.2, DUR - 0.6, 0.4, 0.5)
	var sw = weakref(slv)
	var ended = {"v": false}
	pj.every(DUR, 0.05, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			var s0 = sw.get_ref()
			if s0 != null and not ended["v"]:   # atan düştü: zırh hemen söner
				ended["v"] = true
				ltw.kill()
				_life(s0, 0.0, 0.01, 0.25, 0.2)
			return
		var cen: Vector3 = cc.global_position
		for p in pj.get_tree().get_nodes_in_group("projectiles"):   # atışlar atana geri savrulur
			if not is_instance_valid(p) or p.get("shooter") == cc or p.has_meta("taiton_ref"):
				continue
			if p.global_position.distance_to(cen + Vector3.UP) < 2.4:
				var sh = p.get("shooter")
				var back: Vector3 = ((sh.global_position + Vector3.UP) - p.global_position).normalized() if sh != null and is_instance_valid(sh) else -Vector3(p.vel).normalized()
				p.vel = back * maxf(20.0, Vector3(p.vel).length())
				p.shooter = cc
				p.set_meta("taiton_ref", true)
				if p.get("info") is Dictionary:   # geri dönen atış beklenmedik gelir: savunmayı deler
					p.info = p.info.duplicate()
					p.info["pierce_guard"] = true
				if p.get("homing") != null:
					p.homing = sh if sh != null and is_instance_valid(sh) else null
				_gust_pop(pj, p.global_position, 0.9)
				Sfx.play("wind", p.global_position, 1.4)
		if i % 8 == 0:
			for e in pj.enemies_near(cc, cen, 1.8):
				var v: Vector3 = e.global_position - cen
				v.y = 0
				e.take_hit(pj.inf(cc, id, 0.25, {"knock": 6.0, "kind": "light", "element": "taiton", "bleed": 1.0, "hitstop": 0.0, "dir": v.normalized()})))


# ================================================================== 7) Taifū no Me — yerde çeken göz, sonra göğe patlama
## Yerde dönen göz: yere yapışık altı içe kıvrılan kol + alçak göz duvarı + merkeze yakınsayan yağmur ve yapraklar; gittikçe büzülür
static func _ground_eye(pj: PathJutsu, at: Vector3, R: float, dur: float) -> void:
	var root = _root(pj, at)
	var arms = _node(root)
	var wall = _node(root)
	var us = 1.6 / R
	var sb = Strips.new()
	_arms(sb, R, R * 0.12, 0.25, 6, 0.9, R * 0.22, R * 0.05, 1.0, 0.4, 0.12, BAND_MID, 26, 0.0, us)
	_arms(sb, R * 0.9, R * 0.15, 0.4, 3, 0.75, 1.2, 0.35, 1.0, 0.3, 1.35, BAND_DEEP, 22, 0.5, us)
	_mi(arms, sb.mesh(), _band_mat(), 2.0, 1.0)
	var sr = Strips.new()
	_arms(sr, R * 0.95, R * 0.2, 0.3, 3, 0.8, 1.6, 0.5, 1.0, 0.5, 1.4, RAIN, 20, 1.0, 0.25)
	_mi(arms, sr.mesh(), _rain_mat(), 2.5, 0.0)
	var sw = Strips.new()
	_wall(sw, 1.0, 1.45, 1.6, 9, 1.4, 1.0, BAND_HI, 0.0, 10, 1.5, 1.4)
	_mi(wall, sw.mesh(), _band_mat(), 2.8, 0.4)
	_lumps(wall, R * 0.85, 12, 0.85, 0.0, true)
	_spin(arms, 0.9, 1.0)
	_spin(wall, 0.4, 1.0)
	var sc = root.create_tween()   # göz gittikçe büzülür, kollar sıkılaşır
	sc.tween_property(arms, "scale", Vector3(0.7, 1.0, 0.7), dur).set_trans(Tween.TRANS_SINE)
	var rp = _ring(30, R * 0.85, R * 1.1, 0.2, 1.4, 1.0, 0.5, 1.0, -0.05)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": 60, "life": 0.6, "vmin": 9.0, "vmax": 13.0, "grav": Vector3(0, -1, 0),
		"tang": 2.0, "radial": -14.0, "align": true, "ramp": _rain_ramp(), "smin": 0.8, "smax": 1.4})
	var lp = _ring(24, R * 0.6, R * 1.0, 0.05, 0.3, 1.0, 0.6, 1.0, 0.15)
	_emit(root, lp[0], lp[1], _leaf_mesh(), {"amount": 36, "life": 1.0, "vmin": 4.0, "vmax": 7.0, "grav": Vector3(0, -1.5, 0), "tang": 3.0,
		"radial": -8.0, "init_ramp": _leaf_ramp(), "shrink": true, "spin": 600.0, "smin": 1.0, "smax": 2.0, "spread": 20.0})
	_life(root, 0.2, dur - 0.2, 0.25, 0.6)


## Göz göğe patlar: yerden 12 m fışkıran göz duvarı sütunu, tepede açılan bulut kolları, dışa savrulan bulut eteği, göğe
## fırlayan yaprak / taş, sarmal yukarı yağmur kıymıkları
static func _eye_burst(pj: PathJutsu, at: Vector3) -> void:
	var root = _root(pj, at)
	var colm = _node(root)
	var cs = _node(colm)
	var ci = _node(colm)
	var skirt = _node(root)
	var sw = Strips.new()
	_wall(sw, 2.5, 3.4, 12.0, 12, 2.4, 1.0, BAND_MID, 0.0, 18, 1.6, 0.35)
	_wall(sw, 2.7, 3.8, 10.0, 6, 3.0, 1.0, BAND_DEEP, 0.2, 16, 1.3, 0.35)
	_mi(cs, sw.mesh(), _band_mat(), 3.0, 1.0)
	var si = Strips.new()
	_wall(si, 1.0, 2.0, 12.0, 5, 4.0, 1.0, BAND_HI, 0.0, 18, 1.2, 0.5)
	_wall(si, 2.2, 3.0, 11.0, 3, 2.6, 1.0, RAIN, 0.0, 14, 1.0, 0.15)
	_mi(ci, si.mesh(), _band_mat(), 4.0, 0.0)
	var sa = Strips.new()
	_arms(sa, 6.5, 3.0, 11.5, 5, 0.5, 2.4, 1.2, 1.0, 0.8, 0.2, BAND_LO, 20, 0.0, 0.3)
	_mi(cs, sa.mesh(), _band_mat(), 1.5, 1.0)
	_spin(cs, 0.45, 1.0)
	_spin(ci, 0.25, 1.0)
	_scale_to(colm, Vector3(1.0, 0.05, 1.0), Vector3.ONE, 0.18, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_lumps(skirt, 3.0, 14, 0.6)
	_scale_to(skirt, Vector3(0.8, 1.0, 0.8), Vector3(1.6, 0.7, 1.6), 0.7, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_debris_swirl(root, 0.4, 2.6, 0.0, 0.5, 1.0, 30, 16.0, 3.0, 1.5, false, true, -14.0, 1.6, true)
	_debris_swirl(root, 0.4, 3.0, 0.0, 0.8, 1.0, 40, 14.0, 2.5, 2.0, false, true, -6.0, 1.8)
	var rp = _ring(24, 1.0, 2.6, 0.2, 1.5, 1.0, 0.4, 0.0, 2.0)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": 50, "life": 0.6, "vmin": 16.0, "vmax": 24.0, "one_shot": true, "align": true,
		"grav": Vector3(0, -6, 0), "ramp": _rain_ramp(), "smin": 1.0, "smax": 2.0})
	_life(root, 0.0, 0.45, 0.45, 1.6)


static func taifu_no_me(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "taiton_taifu_no_me"
	var tt = pj.tg(c, t, 24.0)
	var d: Vector3 = pj._face(c, tt)
	pj.anim(c, "cast", 1.3)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 9.0)
	var R = 7.0
	Sfx.play("wind", at, 0.4)
	_ground_eye(pj, at, R, 1.6)
	pj.every(1.6, 0.05, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, R):
			var v: Vector3 = at - e.global_position
			v.y = 0
			if e is CharacterBody3D and v.length() > 0.6:
				e.velocity = v.normalized() * (6.0 + k * 8.0) + Vector3(-v.z, 0, v.x).normalized() * 3.0
			if i % 8 == 0:
				pj.st(e, "slow", 0.6)
				e.take_hit(pj.inf(cc, id, 0.15, {"knock": 0.0, "kind": "light", "element": "taiton", "hitstop": 0.0})), func():
		var cc = cw.get_ref()
		_eye_burst(pj, at)
		_aftermath(pj, at, R * 0.8, 1.0, 3.0, true)
		Sfx.play("boom", at, 0.9)
		pj.shake(0.4)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 3.5):
			e.take_hit(pj.inf(cc, id, 1.1, {"knock": 1.0, "launch": 14.0, "kind": "heavy", "element": "taiton", "bleed": 2.0, "hitstop": 0.08, "dir": Vector3.UP})))


# ================================================================== 8) Shinkū Taiha — avuç çırpışı, yassı boşluk halkası
## Çırpış anı: avuçlar arasında çakan sert basınç yıldızı (ince ışınlar, ortada kısa göz halkası)
static func _clap(pj: PathJutsu, pos: Vector3, _d: Vector3) -> void:
	var root = _root(pj, pos)
	var sb = Strips.new()
	for q in 10:
		var a = q * TAU / 10.0 + randf_range(-0.1, 0.1)
		var dir = (Vector3(cos(a), sin(a) * 0.35, sin(a))).normalized()
		var side = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var L = randf_range(0.7, 1.3)
		var pts = [dir * 0.1, dir * L * 0.5, dir * L]
		var sides = [side * 0.02, side * 0.07, side * 0.005]
		var cols = [_ca(BAND_HI, 1.0), _ca(BAND_HI, 1.0), _ca(BAND_HI, 0.4)]
		sb.strip(pts, sides, cols, [0.0, 0.5, 1.0])
	_ring_band(sb, 0.25, 0.42, 0.0, 4, BAND_HI, 3.0, 0.1, 0.0)
	_mi(root, sb.mesh(), _band_mat(), 0.0, 0.0)
	_scale_to(root, Vector3.ONE * 0.2, Vector3.ONE * 1.3, 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_life(root, 0.0, 0.06, 0.12, 0.05)


## Kesik izi (halka çarptığında): hedefin üstünde çapraz iki ince yağmur-beyazı yarık
static func _cut(pj: PathJutsu, pos: Vector3, dir: Vector3) -> void:
	var root = _root(pj, pos)
	var side = dir.cross(Vector3.UP).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var sb = Strips.new()
	for q in 2:
		var ax = (side + Vector3.UP * (0.6 if q == 0 else -0.6)).normalized()
		var nrm = ax.cross(dir).normalized()
		var pts = [-ax * 0.7, Vector3.ZERO, ax * 0.7]
		sb.strip(pts, [nrm * 0.01, nrm * 0.07, nrm * 0.01], [_ca(BAND_HI, 0.5), _ca(BAND_HI, 1.0), _ca(BAND_HI, 0.5)], [0.0, 0.5, 1.0])
	_mi(root, sb.mesh(), _band_mat(), 0.0, 0.0)
	_scale_to(root, Vector3.ONE * 0.4, Vector3.ONE * 1.2, 0.08)
	_life(root, 0.0, 0.06, 0.14, 0.05)


static func shinku_taiha(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "taiton_shinku_taiha"
	pj.anim(c, "cross", 1.6)
	var cw = weakref(c)
	var cen: Vector3 = c.global_position + Vector3.UP * 1.0
	var hitk = {}
	Sfx.play("whoosh", cen, 0.6)
	_gather(pj, cen - Vector3.UP * 0.3, 2.4, 0.22, 1.0, 0.8)   # çırpış öncesi: chakra avuçlara toplanır
	pj.after(0.2, func():
		Sfx.play("boom", cen, 1.3, 0.5)
		_clap(pj, cen, c.face_dir() if is_instance_valid(c) and c.has_method("face_dir") else Vector3.FORWARD))
	# halka: r = 0.8 + k * 10 (0.5 sn, doğrusal) — kopuk yay parçaları + alçak basınç perdesi + yerde kalkan bulut halkası
	var ring = _root(pj, cen)
	var rb = Strips.new()
	_ring_band(rb, 0.9, 1.08, 0.0, 16, BAND_HI, 3.0, 0.12, 0.0)
	_ring_band(rb, 0.86, 1.0, -0.03, 8, CHAKRA, 2.0, 0.3, 0.6)
	_mi(ring, rb.mesh(), _band_mat(), 5.0, 0.0)
	var cur = Strips.new()   # yassı, yarı saydam basınç perdesi (halkanın biraz altında, eğik)
	_ring_band(cur, 0.8, 1.0, -0.3, 8, RAIN, 1.5, 0.15, 1.2)
	_mi(ring, cur.mesh(), _rain_mat(), 4.0, 0.0)
	var vac = Strips.new()   # arkadan gelen koyu emme halkası
	_ring_band(vac, 0.55, 0.7, 0.0, 10, BAND_DEEP, 2.0, 0.25, 0.2)
	_mi(ring, vac.mesh(), _band_mat(), 3.0, 0.0)
	var gnd = _root(pj, pj.gp(cen))
	var gd = Strips.new()   # yerden kalkan ince toz-bulut halkası
	_ring_band(gd, 0.9, 1.0, 0.12, 12, Color(0.92, 0.9, 0.86), 2.0, 0.2, 0.5)
	_mi(gnd, gd.mesh(), _band_mat(), 2.0, 0.0)
	var ntw = ring.create_tween()
	ntw.tween_property(ring, "scale", Vector3(10.8, 1.0, 10.8), 0.5).from(Vector3(0.8, 1.0, 0.8))
	var gtw = gnd.create_tween()
	gtw.tween_property(gnd, "scale", Vector3(10.0, 1.0, 10.0), 0.55).from(Vector3(0.8, 1.0, 0.8))
	_life(ring, 0.0, 0.4, 0.2, 0.05)
	_life(gnd, 0.0, 0.45, 0.4, 0.05)
	var rp = _ring(32, 0.3, 0.6, -0.1, 0.1, 1.0, 0.05, -1.0, 0.0)   # dışa fırlayan basınç çizgileri
	_emit(ring, rp[0], rp[1], _streak_mesh(), {"amount": 48, "life": 0.5, "vmin": 1.5, "vmax": 2.2, "one_shot": true, "align": true,
		"local": true, "grav": Vector3.ZERO, "ramp": _rain_ramp(), "smin": 0.08, "smax": 0.14})
	pj.after(0.45, func(): _aftermath(pj, pj.gp(cen), 9.0, 1.0, 2.5, false))   # artçı: halkanın yatırdığı otlar
	pj.every(0.5, 0.03, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var r = 0.8 + k * 10.0
		for e in pj.enemies_near(cc, cen, r + 0.6):
			var key = e.get_instance_id()
			var dd = Vector2(e.global_position.x - cen.x, e.global_position.z - cen.z).length()
			if hitk.has(key) or dd < r - 1.4:
				continue
			hitk[key] = true
			var v: Vector3 = e.global_position - cen
			v.y = 0
			_cut(pj, e.global_position + Vector3.UP, v.normalized() if v.length() > 0.1 else Vector3.FORWARD)
			e.take_hit(pj.inf(cc, id, 1.3, {"knock": 9.0, "launch": 1.5, "kind": "heavy", "element": "taiton", "bleed": 4.0, "hitstop": 0.06, "dir": v.normalized()})))


# ================================================================== 9) Reppū Kaitenkyaku — üç dönen tekme, uçan rüzgâr yayları
## Uçan hilal: üst üste üç kat ince fırtına yayı (ortası kalın), arkasında dikey yağmur perdesi, uçtan saçılan yağmur
static func _kick_arc(pj: PathJutsu, base: Vector3, f: Vector3, sd: Vector3, dist: float, big: bool) -> void:
	var root = _root(pj, base)
	var sb = Strips.new()
	var sr = Strips.new()
	var sc = 1.35 if big else 1.0
	for q in 3:
		var off = (q - 1) * 0.18
		var pts = []
		var sides = []
		var cols = []
		for j in 19:
			var u = j / 18.0
			var a = lerpf(-1.1, 1.1, u)
			var rv = f * cos(a) * 0.6 + sd * sin(a) * 1.8
			pts.append(f * (1.2 + u * 0.2) + rv * sc + Vector3.UP * off)
			sides.append(rv.normalized() * (0.03 + sin(u * PI) * (0.2 if q == 1 else 0.1)) * sc)
			cols.append(_ca(BAND_HI if q == 1 else BAND_LO, minf(u, 1.0 - u) * 6.0))
		sb.strip(pts, sides, cols, _us(pts, 0.8))
	var pts2 = []
	var sides2 = []
	var cols2 = []
	for j in 15:
		var u = j / 14.0
		var a = lerpf(-1.0, 1.0, u)
		pts2.append(f * (0.85 + u * 0.2) + (f * cos(a) * 0.55 + sd * sin(a) * 1.6) * sc)
		sides2.append(Vector3.UP * (0.08 + sin(u * PI) * 0.32) * sc)
		cols2.append(_ca(Color.WHITE, minf(u, 1.0 - u) * 5.0))
	sr.strip(pts2, sides2, cols2, _us(pts2, 0.6))
	_mi(root, sb.mesh(), _band_mat(), 3.0, 0.0)
	_mi(root, sr.mesh(), _rain_mat(), 3.5, 0.0)
	var mv = root.create_tween()
	mv.tween_property(root, "global_position", base + f * dist, 0.3).set_ease(Tween.EASE_OUT)
	mv.parallel().tween_property(root, "scale", Vector3.ONE * 1.3, 0.3)
	var tp = PackedVector3Array()
	var tn = PackedVector3Array()
	for j in 9:
		var a = lerpf(-1.1, 1.1, j / 8.0)
		tp.append(f * 1.3 + (f * cos(a) * 0.6 + sd * sin(a) * 1.8) * sc)
		tn.append((f + sd * sin(a) * 0.5).normalized())
	_emit(root, tp, tn, _streak_mesh(), {"amount": 22, "life": 0.35, "vmin": 6.0, "vmax": 11.0, "one_shot": true, "align": true,
		"grav": Vector3(0, -4, 0), "ramp": _rain_ramp(), "smin": 0.5, "smax": 1.0, "spread": 15.0})
	_life(root, 0.0, 0.18, 0.14, 0.4)


## Son tekmenin tayfunu: ileri yuvarlanan, yatay eksenli sıkı girdap (ekseni tekme yönünde)
static func _kick_vortex(pj: PathJutsu, pos: Vector3, f: Vector3) -> void:
	var root = _root(pj, pos - f * 1.2)
	root.basis = Basis(Quaternion(Vector3.UP, f.normalized()))
	var sp = _node(root)
	var sw = Strips.new()
	_wall(sw, 0.4, 1.7, 3.2, 8, 3.0, 1.0, BAND_MID, 0.0, 16, 1.4, 0.7)
	_wall(sw, 0.5, 1.9, 2.6, 4, 2.2, 1.0, BAND_DEEP, 0.3, 12, 1.2, 0.7)
	_wall(sw, 0.5, 1.5, 3.0, 3, 2.6, 1.0, RAIN, 0.1, 12, 1.0, 0.3)
	_mi(sp, sw.mesh(), _band_mat(), 3.2, 1.0)
	_spin(sp, 0.18, 1.0)
	_scale_to(root, Vector3(0.3, 0.3, 0.3), Vector3.ONE * 1.1, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	var mv = root.create_tween()
	mv.tween_property(root, "global_position", pos + f * 1.5, 0.55)
	_debris_swirl(root, 0.3, 1.2, 0.0, 2.5, 1.0, 22, 9.0, 0.3, 0.9, false, true, -6.0, 1.3)
	var rp = _ring(20, 0.6, 1.6, 0.0, 2.5, 1.0, 1.0, 0.3, 0.6)
	_emit(root, rp[0], rp[1], _streak_mesh(), {"amount": 30, "life": 0.4, "vmin": 8.0, "vmax": 12.0, "one_shot": true, "align": true,
		"grav": Vector3(0, -3, 0), "ramp": _rain_ramp(), "smin": 0.7, "smax": 1.2})
	_life(root, 0.0, 0.32, 0.25, 0.6)


static func reppu_kaitenkyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.2)
	var id = "taiton_reppu_kaitenkyaku"
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	# toplanma: ayakların çevresinde dönen alçak bant (üç tekme boyunca)
	_gather(pj, c.global_position + Vector3.UP * 0.2, 2.0, 0.9, 1.0, 1.4)
	for k in 3:
		pj.after(0.05 + k * 0.32, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var f: Vector3 = pj._face(cc, x) if x != null and pj.live(x) else cc.face_dir()
			var last = k == 2
			pj._kick_pose(cc, 0.25)
			var f0 = cc.facing if "facing" in cc else 0.0
			pj.every(0.22, 1.0 / 60.0, func(_i, kk):   # tam tur döner, sonunda hedefe bakar
				var c3 = cw.get_ref()
				if c3 != null and is_instance_valid(c3) and "facing" in c3:
					c3.facing = f0 + TAU * kk)
			if cc is CharacterBody3D:   # rakibe doğru dönerek ilerler
				cc.velocity = f * (clampf((cc.global_position.distance_to(x.global_position) - 2.0) / 0.25, 0.0, 16.0) if x != null and pj.live(x) else 5.0)
			var sd = f.cross(Vector3.UP).normalized()
			var base: Vector3 = cc.global_position + Vector3.UP * (0.9 + k * 0.25)
			var dist = 9.0 if last else 6.0
			_kick_arc(pj, base, f, sd, dist, last)   # biçen rüzgâr yayı ileri uçar
			Sfx.play("whoosh", cc.global_position, 1.1 + k * 0.1)
			Combat.hit_zone(cc, pj.gp(cc.global_position), f, dist, 40.0, 2.4, pj.inf(cc, id, 1.3 if last else 0.6, {"knock": 14.0 if last else 3.0, "launch": 5.0 if last else 0.0, "kind": "heavy", "element": "taiton", "bleed": 2.0, "hitstop": 0.07 if last else 0.03}))
			if last:
				_kick_vortex(pj, cc.global_position + f * 3.0 + Vector3.UP, f)
				_aftermath(pj, pj.gp(cc.global_position + f * 4.0), 4.0, 1.0, 2.5, false))


# ================================================================== 10) Oikaze — arkadan tayfun rüzgârıyla süzülme
## İz: atanın geçtiği yol boyunca iki yanda kıvrılan fırtına kanatları + ortada geriye akan yağmur perdesi (her adımda
## yeniden örülür), yerden sıyrılan alçak bulut topakları ve yapraklar
static func _oikaze_meshes(hist: Array, sd: Vector3, phase: float) -> Array:
	var wings = Strips.new()
	var sheet = Strips.new()
	var n = hist.size()
	if n < 2:
		return [wings.mesh(), sheet.mesh()]
	for s in [-1.0, 1.0]:
		for layer in 2:
			var pts = []
			var sides = []
			var cols = []
			for k in n:
				var u = float(k) / (n - 1)
				var p: Vector3 = hist[k]
				var ph = phase * s + u * 6.0 + layer * 1.6
				var rr = 0.55 + (1.0 - u) * 0.6
				pts.append(p + sd * s * (0.7 + cos(ph) * 0.25) * rr * 1.4 + Vector3.UP * (0.9 + sin(ph) * 0.45 + layer * 0.35))
				sides.append((Vector3.UP * cos(ph) - sd * s * sin(ph) * 0.6).normalized() * (0.1 + u * 0.3) * (1.0 - layer * 0.35))
				cols.append(_ca(BAND_HI if layer == 0 else BAND_LO, pow(u, 0.7) * minf(1.0, (1.0 - u) * 8.0 + 0.3)))
			wings.strip(pts, sides, cols, _us(pts, 0.6))
	var pts2 = []
	var sides2 = []
	var cols2 = []
	for k in n:
		var u = float(k) / (n - 1)
		var p: Vector3 = hist[k]
		pts2.append(p + Vector3.UP * (0.45 + sin(u * 5.0 + phase) * 0.1))
		sides2.append((sd * (0.3 + (1.0 - u) * 0.7) + Vector3.UP * 0.15))
		cols2.append(_ca(Color.WHITE, pow(u, 0.6)))
	sheet.strip(pts2, sides2, cols2, _us(pts2, 0.35))
	return [wings.mesh(), sheet.mesh()]


static func oikaze(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.9)
	var id = "taiton_oikaze"
	var d: Vector3 = pj._face(c, tt)
	pj.anim(c, "dash", 1.4)
	var cw = weakref(c)
	var hitk = {}
	var last = {"p": c.global_position}
	var sd = d.cross(Vector3.UP).normalized()
	Sfx.play("wind", c.global_position, 0.8)
	# toplanma: atanın arkasında rüzgâr toplanır (sırtına dolan bantlar)
	_gather(pj, c.global_position - d * 1.2 + Vector3.UP * 0.6, 2.0, 0.18, 1.0, 1.4)
	var tr = _root(pj, Vector3.ZERO)
	var wing_mi = _mi(tr, ArrayMesh.new(), _band_mat(), 3.0, 0.0)
	var sheet_mi = _mi(tr, ArrayMesh.new(), _rain_mat(), 3.5, 0.0)
	var em = _node(tr)
	em.global_position = pj.gp(c.global_position)
	var lp = _ring(16, 0.3, 0.7, 0.0, 0.2, 1.0, 0.3, -0.6, 0.5)
	var lpp: PackedVector3Array = lp[0]
	var lnn: PackedVector3Array = lp[1]
	for q in lnn.size():
		lnn[q] = (lnn[q] - d * 1.4).normalized()
	_emit(em, lpp, lnn, _lump_mesh(), {"amount": 34, "life": 0.7, "vmin": 2.0, "vmax": 5.0, "grav": Vector3(0, 0.4, 0),
		"init_ramp": _grad([CLOUD_TOP, CLOUD_BOT.lightened(0.3)]), "shrink": true, "spin": 120.0, "smin": 0.5, "smax": 0.9, "damp": 2.0})
	_emit(em, lpp, lnn, _leaf_mesh(), {"amount": 24, "life": 0.9, "vmin": 4.0, "vmax": 8.0, "grav": Vector3(0, -3, 0),
		"init_ramp": _leaf_ramp(), "shrink": true, "spin": 720.0, "smin": 1.0, "smax": 1.8, "spread": 30.0})
	_life(tr, 0.0, 0.62, 0.45, 0.9)
	var hist = [c.global_position]
	var ew = weakref(em)
	var ww = weakref(wing_mi)
	var shw = weakref(sheet_mi)
	pj.every(0.6, 1.0 / 60.0, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = d * 32.0 + Vector3.UP * 0.5
		var p: Vector3 = cc.global_position
		hist.append(p)
		if hist.size() > 24:
			hist.pop_front()
		var e0 = ew.get_ref()
		if e0 != null:
			e0.global_position = pj.gp(p)
		if i % 2 == 0:
			var ms = _oikaze_meshes(hist, sd, i * 0.35)
			var w0 = ww.get_ref()
			var s0 = shw.get_ref()
			if w0 != null:
				w0.mesh = ms[0]
			if s0 != null:
				s0.mesh = ms[1]
		last["p"] = p
		for e in pj.enemies_near(cc, p, 2.0):
			var key = e.get_instance_id()
			if hitk.has(key):
				continue
			hitk[key] = true
			var side = signf((e.global_position - p).dot(sd))
			e.take_hit(pj.inf(cc, id, 1.5, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "element": "taiton", "bleed": 3.0, "hitstop": 0.05, "dir": (sd * (side if side != 0 else 1.0) + d * 0.4).normalized()})), func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		var p: Vector3 = cc.global_position
		_gust_pop(pj, p + Vector3.UP, 3.0)
		_aftermath(pj, pj.gp(p), 3.5, 1.0, 2.5, true)
		Sfx.play("boom", p, 1.1, 0.6)
		for e in pj.enemies_near(cc, p, 3.2):
			var v: Vector3 = e.global_position - p
			v.y = 0
			e.take_hit(pj.inf(cc, id, 0.6, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "element": "taiton", "hitstop": 0.04, "dir": v.normalized() if v.length() > 0.1 else d})))
