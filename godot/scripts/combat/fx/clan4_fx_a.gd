class_name Clan4FXA
extends RefCounted
## Klan grubu 4 / A: Yūhi genjutsuları (Jubaku Satsu, Hanagasumi, Jubaku Messatsu, Jutō, Shinkirō, Ingen Shibari),
## Sarutobi (Chakra Bıçağı Düz Hat, Kongō Fūin, Sanpō Fūin, Enma Kongōnyoi, Shuriken Kage Bunshin),
## Hagoromo tüy teknikleri (Hane Goromo, Tobi Hane Otoshi, Ha Shibari, Senjō Hōkō, Ukyū Rakuha),
## Inuzuka (Gatsūga, Jūjin Bunshin, Shikyaku no Jutsu, Dainamikku Mākingu).
## Tüm görseller bu dosyada sıfırdan: kendi tüp örgüsü (ağaç, sarmaşık, pençe), kendi yaprak / tüy / kürk / taç yaprağı
## şekilleri, kendi gölgelendiricileri (cam-kabuk, yumuşak cel bulut, matkap taraması), kendi şerit / iz / zemin izi /
## parçacık sürüsü yapı taşları. Kameraya yakın parçalar söner; ağaç / kule / tomurcuk kameraya bakan yanı açık bırakır.
## Oynanış ana ağaçtaki işleyicilerden satır satır taşındı (hasar çarpanları, durumlar, süreler, menziller).

static var _cache := {}

const SAKURA := Color(1.0, 0.68, 0.8)
const SAKURA_D := Color(0.93, 0.38, 0.58)
const YUHI_RED := Color(0.86, 0.18, 0.3)
const BARK := Color(0.42, 0.31, 0.21)
const MOSS := Color(0.47, 0.53, 0.33)
const LEAF := Color(0.32, 0.56, 0.25)
const INK := Color(0.07, 0.05, 0.06)
const FEATHER := Color(0.97, 0.98, 1.0)
const FEATHER_T := Color(0.7, 0.78, 0.94)
const FUR := Color(0.64, 0.6, 0.57)
const FUR_D := Color(0.38, 0.33, 0.29)
const CREAM := Color(0.98, 0.95, 0.74)
const EARTH_C := Color(0.55, 0.45, 0.33)
const BEAN := Color(0.3, 0.58, 0.22)
const SEAL_G := Color(0.35, 1.0, 0.45)
const ENMA_G := Color(0.98, 0.74, 0.18)


# ================================================================== küçük yardımcılar
static func _scene(pj: PathJutsu) -> Node:
	return pj.get_tree().current_scene


static func _h(n: Node3D) -> float:
	if n == null or not is_instance_valid(n) or n.get("height") == null:
		return 1.8
	return float(n.get("height"))


static func _rad(n: Node3D) -> float:
	if n == null or not is_instance_valid(n) or n.get("radius") == null:
		return 0.38
	return float(n.get("radius"))


static func _r(i: int, s: float) -> float:
	var x = sin(float(i) * 12.9898 + s * 78.233) * 43758.5453
	return x - floor(x)


static func _flat(v: Vector3, fb := Vector3.FORWARD) -> Vector3:
	var d = Vector3(v.x, 0.0, v.z)
	return d.normalized() if d.length() > 0.001 else fb


static func _cam(pj: PathJutsu) -> Camera3D:
	return pj.get_viewport().get_camera_3d()


## Kameradan uzağa bakan yatay yön (ağaç / kabuk kurbanın arkasında kalsın, görüşü kapatmasın)
static func _away(pj: PathJutsu, at: Vector3, fb: Vector3) -> Vector3:
	var cam = _cam(pj)
	if cam == null:
		return _flat(fb)
	return _flat(at - cam.global_position, _flat(fb))


static func _cam_near(pj: PathJutsu, at: Vector3, r: float) -> bool:
	var cam = _cam(pj)
	return cam != null and cam.global_position.distance_to(at) < r


## +Y ekseni d'ye bakan taban
static func _yb(d: Vector3, hint := Vector3.UP) -> Basis:
	var y = d.normalized() if d.length() > 0.0001 else Vector3.UP
	var x = hint.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(y)
	if x.length() < 0.01:
		x = Vector3.FORWARD.cross(y)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


static func _mi(mesh: Mesh, mat: Material, overlay: Material = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if overlay:
		mi.material_overlay = overlay
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ================================================================== malzemeler
## Köşe rengi + örnek rengi kullanan düz (cel) malzeme; kameraya yakın söner
static func _vc(key: String, add: bool, na := 0.6, nb := 2.4) -> StandardMaterial3D:
	var k = "mat:vc:%s" % key
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = na
	m.distance_fade_max_distance = nb
	_cache[k] = m
	return m


## Yüze dönük (billboard) düz malzeme
static func _bill(key: String, add: bool, tint := Color.WHITE) -> StandardMaterial3D:
	var k = "mat:bill:%s" % key
	if _cache.has(k):
		return _cache[k]
	var m = _vc("billsrc_" + key, add).duplicate()
	m.albedo_color = tint
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	_cache[k] = m
	return m


## Ters kabuk kontur (cel çizgisi): material_overlay olarak
static func _ink(w: float) -> StandardMaterial3D:
	var k = "mat:ink:%.3f" % w
	if _cache.has(k):
		return _cache[k]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = INK
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = w
	_cache[k] = m
	return m


## Tek kullanımlık solabilen düz malzeme (zemin izleri)
static func _fade_mat(col: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.render_priority = 1
	return m


static func _shader(key: String, code: String) -> Shader:
	var k = "sh:" + key
	if not _cache.has(k):
		var s = Shader.new()
		s.code = code
		_cache[k] = s
	return _cache[k]


## Cam kabuk: içi yarı saydam çekirdek, kenarı (fresnel) dolu renk; swirl > 0 iç dalgalanma. Kameraya yakın söner.
const GLASS_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, %s;
uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 0.4);
uniform vec4 edge : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float edge_pow = 2.0;
uniform float swirl = 0.0;
uniform float near_a = 0.8;
uniform float near_b = 3.0;
instance uniform float amount = 1.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fr = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float e = pow(clamp(fr, 0.0, 1.0), edge_pow);
	float n = 0.5 + 0.5 * sin(wp.x * 2.1 + TIME * 1.6 + sin(wp.y * 1.7 - TIME * 1.1) * 2.0) * sin(wp.z * 2.4 - TIME * 1.2 + wp.y * 0.8);
	vec3 c = mix(core.rgb, edge.rgb, e);
	c = mix(c, c * 1.3 + vec3(0.06), swirl * n);
	float a = mix(core.a, edge.a, e) + swirl * 0.25 * (n - 0.5);
	ALBEDO = c;
	ALPHA = clamp(a * amount, 0.0, 1.0) * smoothstep(near_a, near_b, length(VERTEX));
}
"""

## Yumuşak cel bulut (billboard dörtgen): iki tonlu, dalgalı kenarlı; sis, toz, ateş topu, kürk tozu
const BLOB_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.8, 0.6);
uniform vec4 shade : source_color = vec4(0.8, 0.4, 0.6, 0.6);
uniform float near_a = 1.5;
uniform float near_b = 5.0;
instance uniform float amount = 1.0;
instance uniform float seed = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float ang = atan(q.y, q.x);
	float r = length(q) * (1.0 + 0.13 * sin(ang * 5.0 + seed * 6.0 + TIME * 0.7) + 0.06 * sin(ang * 9.0 - seed * 3.0));
	float body = 1.0 - smoothstep(0.76, 0.84, r);
	float inner = 1.0 - smoothstep(0.42, 0.5, length(q - vec2(-0.16, 0.2)));
	ALBEDO = mix(shade.rgb, tint.rgb, inner);
	ALPHA = body * mix(shade.a, tint.a, inner) * amount * smoothstep(near_a, near_b, length(VERTEX));
}
"""

## Gatsūga matkabı: gri gövde, akan koyu spiral taramalar, cel ışık, mürekkep kontur; form = burundan oluşum
const DRILL_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_col : source_color = vec4(0.6, 0.58, 0.62, 1.0);
uniform vec4 dark_col : source_color = vec4(0.15, 0.13, 0.17, 1.0);
uniform vec4 light_col : source_color = vec4(0.84, 0.83, 0.86, 1.0);
uniform float spin_speed = 5.0;
uniform float form = 1.0;
uniform float near_a = 0.9;
uniform float near_b = 2.6;
void fragment() {
	vec3 n = normalize(NORMAL);
	float lam = dot(n, normalize(vec3(0.35, 0.75, 0.55)));
	vec3 c = lam > 0.15 ? base_col.rgb : mix(base_col.rgb, dark_col.rgb, 0.4);
	if (lam > 0.72) { c = light_col.rgb; }
	float s = fract(UV.x * 7.0 + UV.y * 2.6 - TIME * spin_speed);
	float broken = step(0.2, fract(UV.y * 11.0 + UV.x * 3.0));
	c = mix(c, dark_col.rgb, step(0.84, s) * broken);
	float fr = abs(dot(n, normalize(VIEW)));
	c = mix(dark_col.rgb, c, step(0.2, fr));
	ALBEDO = c;
	ALPHA = step(1.0 - form, UV.y) * smoothstep(near_a, near_b, length(VERTEX));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""


static func _glass(key: String, core: Color, edge: Color, epow := 2.0, swirl := 0.0, add := false, na := 0.8, nb := 3.0) -> ShaderMaterial:
	var k = "mat:glass:%s" % key
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader("glass_add" if add else "glass_mix", GLASS_CODE % ("blend_add" if add else "blend_mix"))
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("edge_pow", epow)
	m.set_shader_parameter("swirl", swirl)
	m.set_shader_parameter("near_a", na)
	m.set_shader_parameter("near_b", nb)
	_cache[k] = m
	return m


static func _blob_mat(key: String, tint: Color, shade: Color, na := 1.5, nb := 5.0) -> ShaderMaterial:
	var k = "mat:blob:%s" % key
	if _cache.has(k):
		return _cache[k]
	var m = ShaderMaterial.new()
	m.shader = _shader("blob", BLOB_CODE)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("near_a", na)
	m.set_shader_parameter("near_b", nb)
	_cache[k] = m
	return m


# ================================================================== geometri
## Üçgen: köşe normallerine göre dışa bakacak şekilde sıralanır (Godot ön yüzü saat yönünde)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var tp = b
		b = c
		c = tp
		var tn = nb
		nb = nc
		nc = tn
		var tc = cb
		cb = cc
		cc = tc
	st.set_normal(na)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_color(cc)
	st.add_vertex(c)


## Kendi tüp örgüm: pts boyunca halka kesitler (yarıçap rad[i]); renk boy boyunca c0 -> c1, çevrede kabuk şeritleri
static func _tube(pts: Array, rad: Array, c0: Color, c1: Color, seg := 8, stripes := 0.0) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	var rings = []
	var nrm = []
	var prev = Vector3.ZERO
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3 = (pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		if tg.length() < 0.0001:
			tg = Vector3.UP
		tg = tg.normalized()
		var sd: Vector3 = prev if prev != Vector3.ZERO else (Vector3.RIGHT if absf(tg.x) < 0.9 else Vector3.FORWARD)
		sd = sd - tg * sd.dot(tg)
		if sd.length() < 0.001:
			sd = tg.cross(Vector3.FORWARD)
		sd = sd.normalized()
		prev = sd
		var up2 = tg.cross(sd).normalized()
		var ring = []
		var rn = []
		for k in seg + 1:
			var a = TAU * k / seg
			var o = sd * cos(a) + up2 * sin(a)
			ring.append(p + o * float(rad[i]))
			rn.append(o)
		rings.append(ring)
		nrm.append(rn)
	for i in n - 1:
		var u0 = float(i) / maxf(1.0, n - 1)
		var u1 = float(i + 1) / maxf(1.0, n - 1)
		for k in seg:
			var ca = c0.lerp(c1, u0)
			var cb = c0.lerp(c1, u1)
			if stripes > 0.0 and k % 3 == 0:
				ca = ca.darkened(stripes)
				cb = cb.darkened(stripes)
			_tri(st, rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], nrm[i][k], nrm[i][k + 1], nrm[i + 1][k + 1], ca, ca, cb)
			_tri(st, rings[i][k], rings[i + 1][k + 1], rings[i + 1][k], nrm[i][k], nrm[i + 1][k + 1], nrm[i + 1][k], ca, cb, cb)
	return st.commit()


## Düz yelpaze çokgen (XY düzlemi, uzun eksen +Y): taç yaprağı, yaprak, tüy, kürk tutamı. cup: uçlara doğru +Z kıvrımı
static func _fan(key: String, outline: Array, cen: Vector2, c_mid: Color, c_edge: Color, cup := 0.0, spine := Color(0, 0, 0, 0)) -> ArrayMesh:
	var k = "mesh:fan:" + key
	if _cache.has(k):
		return _cache[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nn = outline.size()
	for j in nn:
		var a: Vector2 = outline[j]
		var b: Vector2 = outline[(j + 1) % nn]
		st.set_normal(Vector3.BACK)
		st.set_color(c_mid)
		st.add_vertex(Vector3(cen.x, cen.y, 0.0))
		st.set_color(c_mid.lerp(c_edge, 0.85))
		st.add_vertex(Vector3(a.x, a.y, cup * (a.x * a.x * 4.0 + a.y * a.y * 0.5)))
		st.set_color(c_mid.lerp(c_edge, 0.85))
		st.add_vertex(Vector3(b.x, b.y, cup * (b.x * b.x * 4.0 + b.y * b.y * 0.5)))
	if spine.a > 0.0:   # orta damar / tüy sapı
		var w = 0.012
		var q = [Vector3(-w, -0.08, 0.004), Vector3(w, -0.08, 0.004), Vector3(w * 0.4, 0.96, 0.004), Vector3(-w * 0.4, 0.96, 0.004)]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.BACK)
			st.set_color(spine)
			st.add_vertex(q[t])
	var m = st.commit()
	_cache[k] = m
	return m


static func _petal_mesh() -> ArrayMesh:
	return _fan("petal", [Vector2(0, 0), Vector2(0.26, 0.22), Vector2(0.4, 0.55), Vector2(0.33, 0.88), Vector2(0.12, 1.0), Vector2(0.0, 0.86), Vector2(-0.12, 1.0), Vector2(-0.33, 0.88), Vector2(-0.4, 0.55), Vector2(-0.26, 0.22)],
		Vector2(0, 0.42), Color(1.0, 0.93, 0.96), SAKURA_D, 0.1)


static func _leaf_mesh() -> ArrayMesh:
	return _fan("leaf", [Vector2(0, 0), Vector2(0.2, 0.22), Vector2(0.27, 0.52), Vector2(0.14, 0.84), Vector2(0, 1.0), Vector2(-0.14, 0.84), Vector2(-0.27, 0.52), Vector2(-0.2, 0.22)],
		Vector2(0, 0.45), LEAF.lightened(0.25), LEAF.darkened(0.3), 0.05, LEAF.lightened(0.4))


## Yürek biçimli fasulye yaprağı
static func _heart_mesh() -> ArrayMesh:
	return _fan("heart", [Vector2(0, 0.02), Vector2(0.22, -0.02), Vector2(0.42, 0.18), Vector2(0.44, 0.48), Vector2(0.28, 0.78), Vector2(0, 1.0), Vector2(-0.28, 0.78), Vector2(-0.44, 0.48), Vector2(-0.42, 0.18), Vector2(-0.22, -0.02)],
		Vector2(0, 0.42), BEAN.lightened(0.3), BEAN.darkened(0.25), 0.06, BEAN.lightened(0.45))


## Chakra tüyü: ortası beyaz, kenarı soluk mavi, çentikli kenar, sap
static func _feather_mesh() -> ArrayMesh:
	return _fan("feather", [Vector2(0, -0.06), Vector2(0.07, 0.1), Vector2(0.12, 0.33), Vector2(0.09, 0.4), Vector2(0.13, 0.5), Vector2(0.12, 0.7), Vector2(0.08, 0.74), Vector2(0.09, 0.84), Vector2(0.03, 0.97), Vector2(0, 1.0),
		Vector2(-0.035, 0.94), Vector2(-0.09, 0.8), Vector2(-0.11, 0.6), Vector2(-0.08, 0.55), Vector2(-0.11, 0.42), Vector2(-0.1, 0.3), Vector2(-0.06, 0.1)],
		Vector2(0, 0.45), FEATHER, FEATHER_T, 0.04, Color(0.78, 0.84, 0.95))


## Kürk tutamı: dalgalı uçlu üç sivri
static func _tuft_mesh() -> ArrayMesh:
	return _fan("tuft", [Vector2(0, 0), Vector2(0.09, 0.2), Vector2(0.14, 0.7), Vector2(0.07, 0.5), Vector2(0.03, 1.0), Vector2(-0.02, 0.55), Vector2(-0.12, 0.85), Vector2(-0.08, 0.25)],
		Vector2(0, 0.25), Color(1, 1, 1), Color(0.75, 0.72, 0.7), 0.0)


## 4 kollu parıltı yıldızı
static func _star_mesh() -> ArrayMesh:
	var pts = []
	for k in 8:
		var a = TAU * k / 8.0
		var rr = 1.0 if k % 2 == 0 else 0.18
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return _fan("star", pts, Vector2.ZERO, Color(1, 1, 1, 1), Color(1, 1, 1, 0.6))


static func _sph() -> Mesh:
	var k = "mesh:sph"
	if not _cache.has(k):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 4
		_cache[k] = s
	return _cache[k]


static func _box() -> Mesh:
	var k = "mesh:box"
	if not _cache.has(k):
		var b = BoxMesh.new()
		b.size = Vector3.ONE
		_cache[k] = b
	return _cache[k]


static func _quad() -> Mesh:
	var k = "mesh:quad"
	if not _cache.has(k):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache[k] = q
	return _cache[k]


## Kalınlıklı (iki yüzlü) kubbeli büyük taç yaprağı: taban (0,0,0), uç +Y, iç yüz +Z
static func _petal_shell(key: String, w: float, h: float, cup: float, cb: Color, ct: Color) -> ArrayMesh:
	var k = "mesh:pshell:" + key
	if _cache.has(k):
		return _cache[k]
	var U = 7
	var V = 9
	var P = []
	for j in V + 1:
		var v = float(j) / V
		var row = []
		var wid = w * pow(sin(PI * clampf(v * 0.9 + 0.06, 0.0, 1.0)), 0.65) * (1.0 - 0.25 * v * v)
		for i in U + 1:
			var u = float(i) / U * 2.0 - 1.0
			var z = cup * (u * u) * (0.3 + v) + cup * 0.6 * v * v
			row.append(Vector3(u * wid * 0.5, v * h, z))
		P.append(row)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var th = 0.025 * h
	for j in V:
		for i in U:
			var a: Vector3 = P[j][i]
			var b: Vector3 = P[j][i + 1]
			var c: Vector3 = P[j + 1][i + 1]
			var d: Vector3 = P[j + 1][i]
			var nf = (b - a).cross(d - a).normalized()
			if nf.z < 0.0:
				nf = -nf
			var col0 = cb.lerp(ct, float(j) / V).lerp(Color(1, 0.95, 0.97), 0.25 * absf(float(i) / U * 2.0 - 1.0))
			var col1 = cb.lerp(ct, float(j + 1) / V).lerp(Color(1, 0.95, 0.97), 0.25 * absf(float(i) / U * 2.0 - 1.0))
			_tri(st, a, b, c, nf, nf, nf, col0, col0, col1)
			_tri(st, a, c, d, nf, nf, nf, col0, col1, col1)
			var o = -nf * th
			_tri(st, a + o, c + o, b + o, -nf, -nf, -nf, col0.darkened(0.15), col1.darkened(0.15), col0.darkened(0.15))
			_tri(st, a + o, d + o, c + o, -nf, -nf, -nf, col0.darkened(0.15), col1.darkened(0.15), col1.darkened(0.15))
	var m = st.commit()
	_cache[k] = m
	return m


# ================================================================== parçacık sürüsü / şerit / zemin izi
## Kendi parçacık sürüm: n örnek, her kare fn(i, u) -> [Transform3D, Color]; dur sonunda silinir
static func _swarm(pj: PathJutsu, mesh: Mesh, mat: Material, n: int, dur: float, fn: Callable, parent: Node3D = null) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent and is_instance_valid(parent):
		parent.add_child(mmi)
	else:
		_scene(pj).add_child(mmi)
		mmi.global_transform = Transform3D.IDENTITY
	var step = func(u: float):
		for i in n:
			var r: Array = fn.call(i, u)
			mm.set_instance_transform(i, r[0])
			mm.set_instance_color(i, r[1])
	step.call(0.0)
	var tw = mmi.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(mmi.queue_free)
	return mmi


## Kameraya dönük şerit (ImmediateMesh): pts baştan sona incelir ve saydamlaşır
static func _strip(mi: MeshInstance3D, im: ImmediateMesh, pts: Array, w: float, col: Color, a: float) -> void:
	im.clear_surfaces()
	var n = pts.size()
	if n < 2 or a <= 0.001:
		return
	var cam = mi.get_viewport().get_camera_3d() if mi.is_inside_tree() else null
	var cp: Vector3 = cam.global_position if cam else Vector3(0, 1000, 0)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in n:
		var p: Vector3 = pts[j]
		var tg: Vector3 = (pts[mini(j + 1, n - 1)] as Vector3) - (pts[maxi(j - 1, 0)] as Vector3)
		var sd = tg.cross(cp - p)
		sd = sd.normalized() if sd.length() > 0.00001 else Vector3.UP
		var f = 1.0 - float(j) / (n - 1)
		var ww = w * (0.2 + 0.8 * f)
		var cc = Color(col.r, col.g, col.b, col.a * a * f)
		im.surface_set_color(cc)
		im.surface_add_vertex(p + sd * ww)
		im.surface_set_color(cc)
		im.surface_add_vertex(p - sd * ww)
	im.surface_end()


static func _strip_node(pj: PathJutsu, add: bool) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.material_override = _vc("strip_add" if add else "strip_mix", add, 0.8, 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene(pj).add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


## Hareket eden bir kaynağın izi: src() Vector3 döndürdükçe geçmiş birikir; döndürmezse iz kısalarak söner
static func _trail(pj: PathJutsu, src: Callable, dur: float, w: float, col: Color, maxn := 12, add := true) -> void:
	var hist = []
	var mi = _strip_node(pj, add)
	var im: ImmediateMesh = mi.mesh
	var tw = mi.create_tween()
	tw.tween_method(func(u: float):
		var p = src.call()
		if p is Vector3:
			hist.push_front(p)
		elif not hist.is_empty():
			hist.pop_back()
			if not hist.is_empty():
				hist.pop_back()
		while hist.size() > maxn:
			hist.pop_back()
		_strip(mi, im, hist, w, col, 1.0 - smoothstep(0.85, 1.0, u)), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


## Yol boyunca kayan şerit: baş path(u), kuyruk span kadar geride
static func _path_ribbon(pj: PathJutsu, path: Callable, dur: float, w: float, col: Color, span := 0.35, add := true) -> void:
	var mi = _strip_node(pj, add)
	var im: ImmediateMesh = mi.mesh
	var tw = mi.create_tween()
	tw.tween_method(func(u: float):
		var pts = []
		for j in 12:
			var s = minf(u, 1.0) - span * j / 11.0
			if s < 0.0:
				break
			pts.append(path.call(s))
		_strip(mi, im, pts, w, col, 1.0 - smoothstep(1.0, 1.0 + span, u)), 0.0, 1.0 + span, dur)
	tw.tween_callback(mi.queue_free)


## Zemin izi: yere yapışık şerit (çatlak, oyuk, sıyrık); life sonunda solar
static func _scar(pj: PathJutsu, pts: Array, w: float, col: Color, life: float) -> void:
	if pts.size() < 2:
		return
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	var gpts = []
	for p in pts:
		var g: Vector3 = pj.gp(p)
		gpts.append(g + Vector3.UP * 0.035)
	for j in n - 1:
		var a: Vector3 = gpts[j]
		var b: Vector3 = gpts[j + 1]
		var sd = _flat(b - a).cross(Vector3.UP)
		var wa = w * (1.0 - 0.7 * float(j) / (n - 1))
		var wb = w * (1.0 - 0.7 * float(j + 1) / (n - 1))
		var q = [a + sd * wa, a - sd * wa, b - sd * wb, b + sd * wb]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(1, 1, 1))
			st.add_vertex(q[t])
	var m = _fade_mat(col)
	var mi = _mi(st.commit(), m)
	_scene(pj).add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var tw = mi.create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.4)
	tw.tween_callback(mi.queue_free)


## Işınsal kırık çatlak yıldızı
static func _cracks(pj: PathJutsu, at: Vector3, r: float, n: int, col: Color, life: float, seed := 0.0) -> void:
	for k in n:
		var a = TAU * k / n + _r(k, seed) * 0.5
		var pts = [at]
		var p = at
		var dir = Vector3(cos(a), 0, sin(a))
		for s in 4:
			dir = dir.rotated(Vector3.UP, (_r(k * 7 + s, seed + 1.0) - 0.5) * 0.9)
			p = p + dir * r * (0.2 + 0.1 * _r(k + s, seed + 2.0))
			pts.append(p)
		_scar(pj, pts, 0.06 + 0.04 * r / 4.0, col, life)


## Işık parlaması
static func _flash(pj: PathJutsu, at: Vector3, col: Color, energy: float, rng: float, life: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_scene(pj).add_child(l)
	l.global_position = at
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Tek cel bulut (billboard): büyür, yükselir, söner
static func _puff(pj: PathJutsu, mat: ShaderMaterial, pos: Vector3, s0: float, s1: float, life: float, rise: Vector3, seed: float, amax := 1.0) -> MeshInstance3D:
	var mi = _mi(_quad(), mat)
	_scene(pj).add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * s0
	mi.set_instance_shader_parameter("seed", seed)
	mi.set_instance_shader_parameter("amount", amax)
	var tw = mi.create_tween()
	tw.tween_method(func(u: float):
		if not is_instance_valid(mi):
			return
		mi.scale = Vector3.ONE * lerpf(s0, s1, 1.0 - pow(1.0 - u, 2.0))
		mi.global_position = pos + rise * u
		mi.set_instance_shader_parameter("amount", amax * (1.0 - smoothstep(0.55, 1.0, u))), 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)
	return mi


## Yere çöken parça sürüsü (taş, kabuk): balistik, yerde durur
static func _chunks(pj: PathJutsu, at: Vector3, n: int, speed: float, col: Color, size: float, dur: float, seed := 0.0) -> void:
	var g = at.y
	_swarm(pj, _box(), Props.toon(), n, dur, func(i: int, u: float) -> Array:
		var t = u * dur
		var a = TAU * _r(i, seed)
		var up = 0.4 + 0.8 * _r(i, seed + 1.0)
		var v = Vector3(cos(a) * (1.0 - up * 0.5), up, sin(a) * (1.0 - up * 0.5)) * speed * (0.5 + 0.5 * _r(i, seed + 2.0))
		var p = at + v * t + Vector3.DOWN * 9.8 * t * t * 0.5
		p.y = maxf(p.y, g + 0.05)
		var s = size * (0.5 + _r(i, seed + 3.0)) * (1.0 - smoothstep(0.75, 1.0, u))
		var b = Basis.from_euler(Vector3(t * 7.0 * _r(i, seed + 4.0), t * 5.0, a)).scaled(Vector3(s, s * 0.7, s * 0.9))
		return [Transform3D(b, p), col.darkened(0.25 * _r(i, seed + 5.0))])


## Zeminden dışa savrulan toz halkası (küçük küreler)
static func _dust_ring(pj: PathJutsu, at: Vector3, r: float, col: Color, n: int, dur: float, seed := 0.0) -> void:
	_swarm(pj, _sph(), _vc("dust", false, 1.0, 3.5), n, dur, func(i: int, u: float) -> Array:
		var a = TAU * i / n + _r(i, seed) * 0.4
		var e = 1.0 - pow(1.0 - u, 3.0)
		var p = at + Vector3(cos(a), 0, sin(a)) * r * e * (0.7 + 0.3 * _r(i, seed + 1.0)) + Vector3.UP * (0.15 + e * 0.5 * _r(i, seed + 2.0))
		var s = r * 0.16 * (0.6 + 0.6 * _r(i, seed + 3.0)) * (0.5 + e)
		return [Transform3D(Basis().scaled(Vector3(s, s * 0.7, s)), p), Color(col.r, col.g, col.b, 0.85 * (1.0 - u))])


## Genjutsu sersemliği: kurbanın başı üstünde dönen küçük taç yaprağı halkası
static func _daze(pj: PathJutsu, e: Node3D, dur: float, col: Color) -> void:
	if not pj.live(e):
		return
	var root = Node3D.new()
	e.add_child(root)
	root.position = Vector3.UP * (_h(e) + 0.3)
	var s = ClanJutsu.body_scale(e)
	root.scale = Vector3.ONE * s
	var mat = _vc("daze", false, 0.6, 2.0)
	for k in 5:
		var a = TAU * k / 5.0
		var p = _mi(_petal_mesh(), mat)
		root.add_child(p)
		p.position = Vector3(cos(a), 0.05 * sin(k * 2.0), sin(a)) * 0.32
		p.basis = _yb(Vector3(-sin(a), 0.3, cos(a))).scaled(Vector3.ONE * 0.16)
	var tw = root.create_tween().set_loops(int(dur / 0.9) + 1)
	tw.tween_property(root, "rotation:y", TAU, 0.9).as_relative()
	pj.free_after(dur, root)


## Rüzgârda savrulan yaprak / taç yaprağı bulutu (kai anı, patlama)
static func _scatter(pj: PathJutsu, mesh: Mesh, at: Vector3, n: int, r: float, speed: float, dur: float, size: float, seed := 0.0, up := 1.0) -> void:
	_swarm(pj, mesh, _vc("scatter", false, 0.7, 2.6), n, dur, func(i: int, u: float) -> Array:
		var t = u * dur
		var a = TAU * _r(i, seed)
		var el = (_r(i, seed + 1.0) - 0.3) * up
		var dir = Vector3(cos(a), el, sin(a)).normalized()
		var spd = speed * (0.4 + 0.6 * _r(i, seed + 2.0))
		var p = at + dir * r * _r(i, seed + 3.0) + dir * spd * (1.0 - exp(-t * 2.2)) / 2.2 + Vector3.DOWN * t * t * 0.6
		p += Vector3(sin(t * 4.0 + i), 0, cos(t * 3.0 + i * 1.3)) * 0.25 * u
		var b = Basis.from_euler(Vector3(t * 6.0 + i, t * 4.0 * _r(i, seed + 4.0), t * 5.0)).scaled(Vector3.ONE * size * (0.7 + 0.6 * _r(i, seed + 5.0)))
		return [Transform3D(b, p), Color(1, 1, 1, 1.0 - smoothstep(0.65, 1.0, u))])


## Mermi yörüngesine iliştirilen kısa iz (mermi silinince söner)
static func _proj_trail(pj: PathJutsu, pr: Node3D, dur: float, w: float, col: Color, maxn := 8) -> void:
	var wr = weakref(pr)
	var src = func():
		var x = wr.get_ref()
		if x != null and is_instance_valid(x) and x.is_inside_tree():
			return (x as Node3D).global_position
		return null
	_trail(pj, src, dur, w, col, maxn)


# ================================================================== YŪHİ — genjutsu ağaçları ve çiçekleri
## Büyüyen tüp: pts yavaş yavaş uzar (sarmaşık / bağlayan dal)
static func _grow_tube(parent: Node3D, pts: Array, rad: Array, c0: Color, c1: Color, t_grow: float, delay: float, mat: Material, overlay: Material, seg := 7) -> MeshInstance3D:
	var mi = _mi(null, mat, overlay)
	parent.add_child(mi)
	var n = pts.size()
	var tw = mi.create_tween()
	tw.tween_interval(maxf(0.001, delay))
	tw.tween_method(func(u: float):
		var f = 1.0 + u * (n - 1)
		var m = clampi(int(ceil(f)), 2, n)
		var sub = pts.slice(0, m)
		var sr = rad.slice(0, m)
		var fr = f - floor(f)
		if m < n and fr > 0.0:
			sub[m - 1] = (pts[m - 2] as Vector3).lerp(pts[m - 1], fr)
		sr[m - 1] = float(sr[m - 1]) * 0.4
		if is_instance_valid(mi):
			mi.mesh = _tube(sub, sr, c0, c1, seg), 0.0, 1.0, t_grow)
	return mi


## Kurbanı saran kol (bedenin çevresinde sarmal)
static func _wrap_pts(from_dir: Vector3, h0: float, rise: float, r0: float, r1: float, turns: float, n: int) -> Array:
	var a0 = atan2(from_dir.z, from_dir.x)
	var pts = []
	for i in n:
		var v = float(i) / (n - 1)
		var a = a0 + v * TAU * turns
		var rr = lerpf(r0, r1, minf(1.0, v * 3.0))
		pts.append(Vector3(cos(a) * rr, h0 + v * rise, sin(a) * rr))
	return pts


## Jubaku Satsu meşesi (referans: kalın yosunlu gövde kurbanın arkasında, iki yana açılan kalın dallar, gövdeden çıkıp
## kurbanı saran yeşil-gri kol); kameraya göre kurbanın arkasına kurulur
static func _oak_bind(pj: PathJutsu, tt: Node3D, at: Vector3, back: Vector3, bs: float, dur: float) -> void:
	var root = Node3D.new()
	pj.scene_add(root, at)
	var side = back.cross(Vector3.UP).normalized()
	var ink = _ink(0.03)
	var toon = Props.toon()
	var grow = Node3D.new()
	root.add_child(grow)
	var base = back * 0.8 * bs
	var tp = []
	var tr = []
	for i in 9:
		var v = i / 8.0
		tp.append(base + Vector3.UP * (v * 5.4 * bs - 0.3) + back * sin(v * 1.4) * 0.5 * bs + side * sin(v * 2.3) * 0.25 * bs)
		tr.append(lerpf(0.72, 0.38, pow(v, 0.8)) * bs * (1.0 + 0.5 * maxf(0.0, 0.2 - v) / 0.2))
	grow.add_child(_mi(_tube(tp, tr, BARK.lerp(MOSS, 0.25), MOSS, 10, 0.2), toon, ink))
	for k in 3:   # kökler zemine yayılır
		var a = atan2(back.z, back.x) + (k - 1) * 1.3
		var rp = []
		var rr = []
		for i in 5:
			var v = i / 4.0
			rp.append(base + Vector3(cos(a), 0, sin(a)) * v * 1.6 * bs + Vector3.UP * (0.35 - v * 0.42) * bs)
			rr.append(lerpf(0.3, 0.05, v) * bs)
		grow.add_child(_mi(_tube(rp, rr, BARK, BARK.darkened(0.2), 6, 0.15), toon, ink))
	var tips = []
	for k in 2:   # iki kalın dal (referans: V biçimli açılım)
		var s = -1.0 if k == 0 else 1.0
		var p0: Vector3 = tp[4 + k * 2]
		var bp = []
		var br = []
		for i in 6:
			var v = i / 5.0
			bp.append(p0 + side * s * v * 3.0 * bs + Vector3.UP * (v * 1.7 - v * v * 0.4) * bs + back * v * 0.4 * bs)
			br.append(lerpf(0.3, 0.07, v) * bs)
		grow.add_child(_mi(_tube(bp, br, MOSS.darkened(0.1), MOSS.lightened(0.1), 7, 0.15), toon, ink))
		tips.append(bp[5])
	tips.append(tp[8])
	var cb = MB.new()   # taç: cel yaprak kümeleri
	for q in tips.size():
		var tip: Vector3 = tips[q]
		for k in 5:
			var a = k * 2.4 + q
			var o = Vector3(cos(a) * (0.5 + _r(k, q) * 0.9), 0.2 + _r(k, q + 2.0) * 0.9, sin(a) * (0.5 + _r(k, q + 1.0) * 0.9)) * bs
			cb.add_grad("sphere", tip + o, Vector3.ONE * (1.1 + _r(k, q + 3.0) * 0.7) * bs, LEAF.lightened(0.12), LEAF.darkened(0.35), Vector3.ZERO, 10)
	grow.add_child(_mi(cb.build(null), toon, ink))
	grow.scale = Vector3(0.6, 0.02, 0.6)
	var gt = grow.create_tween()
	gt.tween_property(grow, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# gövdeden çıkıp kurbanı saran iki kol (referans: belini saran yeşil-gri dal)
	var er = (_rad(tt) + 0.1)
	for k in 2:
		var pts = _wrap_pts(back, (0.8 + k * 0.45) * bs, 0.25 * bs, 0.8 * bs, er * bs, 1.05 if k == 0 else -1.05, 13)
		var rr = []
		for i in 13:
			rr.append(lerpf(0.2, 0.1, i / 12.0) * bs)
		_grow_tube(root, pts, rr, MOSS.darkened(0.15), MOSS.lightened(0.05), 0.45, 0.3 + k * 0.15, toon, ink, 8)
	# taçtan süzülen yapraklar
	var top: Vector3 = at + tp[8]
	_swarm(pj, _leaf_mesh(), _vc("leaf", false, 0.7, 2.6), 18, dur, func(i: int, u: float) -> Array:
		var t = fmod(u * dur * 0.6 + _r(i, 3.0) * 2.5, 2.5) / 2.5
		var a = TAU * _r(i, 1.0)
		var p = top + Vector3(cos(a) * 2.2 * _r(i, 2.0), 0.5 - t * 5.5, sin(a) * 2.2 * _r(i, 2.0)) * bs + Vector3(sin(t * 9.0 + i) * 0.4, 0, cos(t * 7.0 + i) * 0.4)
		var b = Basis.from_euler(Vector3(t * 9.0 + i, t * 5.0, sin(t * 8.0) * 0.8)).scaled(Vector3.ONE * 0.22 * bs)
		return [Transform3D(b, p), Color(1, 1, 1, minf(1.0, t * 6.0) * (1.0 - smoothstep(0.8, 1.0, t)) * (1.0 - smoothstep(0.9, 1.0, u)))])
	# kai: ağaç yere çekilir, yaprak ve taç yaprağı olup dağılır
	var rw = weakref(root)
	pj.after(dur, func():
		var rn = rw.get_ref()
		if rn == null:
			return
		var at2: Vector3 = (rn as Node3D).global_position
		_scatter(pj, _leaf_mesh(), at2 + Vector3.UP * 3.5 * bs, 34, 2.0 * bs, 6.0, 1.4, 0.3 * bs, 1.0)
		_scatter(pj, _petal_mesh(), at2 + Vector3.UP * 1.2 * bs, 26, 0.8 * bs, 5.0, 1.2, 0.18 * bs, 2.0)
		var kt = (rn as Node3D).create_tween()
		kt.tween_property(rn, "scale", Vector3(0.7, 0.05, 0.7), 0.35).set_ease(Tween.EASE_IN)
		kt.tween_callback(rn.queue_free))


## Bıçak parıltısı: kısa beyaz-pembe kesik + dört kollu parıltı + kabuk kıymıkları
static func _stab_flash(pj: PathJutsu, p: Vector3, dir: Vector3, col: Color) -> void:
	var sd = _flat(dir).cross(Vector3.UP)
	_path_ribbon(pj, func(s: float) -> Vector3: return p - sd * 0.9 + sd * 1.8 * s + Vector3.UP * (0.5 - s) * 0.6, 0.18, 0.09, Color(1, 0.96, 0.98, 1), 0.5)
	var st = _mi(_star_mesh(), _bill("star", true))
	_scene(pj).add_child(st)
	st.global_position = p
	st.scale = Vector3.ONE * 0.1
	var tw = st.create_tween()
	tw.tween_property(st, "scale", Vector3.ONE * 0.9, 0.08)
	tw.tween_property(st, "scale", Vector3.ONE * 0.01, 0.16)
	tw.tween_callback(st.queue_free)
	_flash(pj, p, col, 3.0, 4.0, 0.2)


## Magen: Jubaku Satsu — kurbanın arkasından kalın meşe büyür, kolu kurbanı sarar (4 sn bağ); sen gövdeden çıkıp saplarsın
static func magen_jubaku_satsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		return
	var at: Vector3 = pj.gp(tt.global_position)
	var bs = ClanJutsu.body_scale(tt)
	var back = _away(pj, at, -tt.face_dir() if tt.has_method("face_dir") else Vector3.BACK)
	_oak_bind(pj, tt, at, back, bs, 4.0)
	_daze(pj, tt, 4.0, SAKURA)
	pj.st(tt, "bind", 4.0)
	pj.after(1.6, func():
		if not pj.live(tt) or not is_instance_valid(c):
			return
		c.global_position = pj.gp(tt.global_position + tt.face_dir() * 1.2) if tt.has_method("face_dir") else c.global_position
		pj.anim(c, "cross", 1.6)
		pj.hit(c, tt.global_position + Vector3.UP * 1.2, 1.3, pj.inf(c, "magen_jubaku_satsu", 2.2, {"knock": 4.0, "kind": "heavy", "hitstop": 0.12}))
		_stab_flash(pj, tt.global_position + Vector3.UP * 1.2, tt.global_position - c.global_position, SAKURA)
		_scatter(pj, _leaf_mesh(), c.global_position + Vector3.UP * 1.0, 10, 0.4, 3.0, 0.7, 0.18, 4.0))
	Sfx.play("genjutsu", tt.global_position, 0.9)


## Magen: Hanagasumi (ref: rakip dev bir çiçeğin ortasında; tomurcuk kapanır, çiçekli patlamayla açılır)
static func magen_hanagasumi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var id = "magen_hanagasumi"
	pj._face(c, tt)
	pj._yama_seal(c)
	Sfx.play("genjutsu", c.global_position, 1.0)
	var gm = Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var bs = ClanJutsu.body_scale(tt)
	var at: Vector3 = pj.gp(tt.global_position)
	var hold = 1.7 * gm
	pj.st(tt, "bind", hold + 0.2)
	_daze(pj, tt, hold, SAKURA)
	var bud = Node3D.new()
	pj.scene_add(bud, at)
	var toon = Props.toon()
	var ink = _ink(0.02)
	var to_cam = -_away(pj, at, Vector3.FORWARD)
	var near = _cam_near(pj, at, 10.0)
	var hinges = []
	var pmesh = _petal_shell("hana", 1.5, 2.9, 0.35, Color(0.95, 0.35, 0.55), Color(1.0, 0.78, 0.86))
	for k in 7:
		var a = TAU * k / 7.0
		var pv = Node3D.new()
		bud.add_child(pv)
		pv.rotation.y = a
		var hinge = Node3D.new()
		pv.add_child(hinge)
		hinge.position = Vector3(0, 0, -0.75 * bs)
		hinge.rotation.x = -1.25
		var pdir = Vector3(-sin(a), 0, -cos(a))
		var petal = _mi(pmesh, toon, ink)
		hinge.add_child(petal)
		petal.scale = Vector3.ONE * bs
		if near and pdir.dot(to_cam) > 0.55:   # kameraya bakan yaprak açık kalır: kurban görünür
			petal.visible = false
		hinges.append(hinge)
	# taban: yeşil çanak yaprakları
	var sb = MB.new()
	for k in 5:
		var a = TAU * k / 5.0 + 0.3
		sb.add("sphere", Vector3(cos(a) * 0.9, 0.08, sin(a) * 0.9) * bs, Vector3(0.9, 0.12, 0.45) * bs, LEAF, Vector3(0, -rad_to_deg(a), 0), 8)
	bud.add_child(_mi(sb.build(null), toon, ink))
	bud.scale = Vector3(1, 0.05, 1)
	var bt = bud.create_tween()
	bt.tween_property(bud, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for h in hinges:
		var ht = (h as Node3D).create_tween()
		ht.tween_interval(0.2)
		ht.tween_property(h, "rotation:x", 0.22, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# tomurcuğun çevresinde dönen taç yaprağı halkası
	_swarm(pj, _petal_mesh(), _vc("petal", false, 0.7, 2.6), 40, hold, func(i: int, u: float) -> Array:
		var a = TAU * i / 40.0 + u * hold * 2.2
		var r = (1.7 + 0.4 * sin(i * 1.7)) * bs
		var p = at + Vector3(cos(a) * r, (0.3 + 2.4 * _r(i, 2.0)) * bs + sin(u * 9.0 + i) * 0.15, sin(a) * r)
		var b = Basis.from_euler(Vector3(u * 12.0 + i, a, 0.4)).scaled(Vector3.ONE * 0.17 * bs)
		return [Transform3D(b, p), Color(1, 1, 1, minf(1.0, u * 8.0))])
	Combat.popup_text(at + Vector3.UP * 3.4, "Tomurcuğa hapsoldu!", SAKURA)
	var bw = weakref(bud)
	pj.after(hold, func():
		var b = bw.get_ref()
		var cc = cw.get_ref()
		var x = tw.get_ref()
		var p: Vector3 = (x.global_position if x != null and pj.live(x) else at) + Vector3.UP * 1.2
		if b != null:   # çiçek patlar: yapraklar dışa savrulup döner, küçülür
			for h in hinges:
				if is_instance_valid(h):
					var ht2 = (h as Node3D).create_tween()
					ht2.tween_property(h, "rotation:x", -2.2, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var bt2 = (b as Node3D).create_tween()
			bt2.tween_property(b, "scale", Vector3(1.5, 1.2, 1.5), 0.22)
			bt2.tween_property(b, "scale", Vector3(0.02, 0.02, 0.02), 0.3).set_ease(Tween.EASE_IN)
			bt2.tween_callback(b.queue_free)
		if cc == null or not pj.live(cc):
			return
		_scatter(pj, _petal_mesh(), p, 110, 0.6 * bs, 9.0 * bs, 1.5, 0.22 * bs, 5.0, 1.2)
		for k in 10:   # çiçek tozu şeritleri
			var a = TAU * k / 10.0
			var o = Vector3(cos(a), 0.2 + 0.4 * _r(k, 6.0), sin(a)).normalized()
			_path_ribbon(pj, func(s: float) -> Vector3: return p + o * s * 5.0 * bs + Vector3.UP * sin(s * PI) * 0.8, 0.4, 0.14 * bs, Color(1.0, 0.72, 0.84, 0.9), 0.45, false)
		_flash(pj, p, SAKURA, 4.0, 8.0, 0.35)
		pj.shake(0.6)
		Sfx.play("boom", p, 1.1)
		pj.hit(cc, p, 3.4 * bs, pj.inf(cc, id, 3.2, {"knock": 12.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.09})))


## Magen: Jubaku Messatsu (ref: Jubaku ağacına bağlanan hedefe dört yandan kunai yağar) — burulmuş ince çift gövde,
## sarmal dallar bedeni sarar; kunailer havada taç yaprağı kıvılcımından belirip saplanır
static func magen_jubaku_messatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	if tt == null:
		return
	var id = "magen_jubaku_messatsu"
	pj._face(c, tt)
	pj._yama_seal(c)
	Sfx.play("genjutsu", c.global_position, 0.9)
	var gm = Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var bs = ClanJutsu.body_scale(tt)
	var at: Vector3 = pj.gp(tt.global_position)
	var bd: Vector3 = -tt.face_dir() if tt.has_method("face_dir") else Vector3.BACK
	var hold = 2.6 * gm
	pj.st(tt, "bind", hold)
	_daze(pj, tt, hold, YUHI_RED)
	# görsel ağaç kameraya göre arkada (kunai yönü oynanıştaki bd'ye göre kalır)
	var back = _away(pj, at, bd)
	var root = Node3D.new()
	pj.scene_add(root, at)
	var toon = Props.toon()
	var ink = _ink(0.025)
	for q in 2:   # birbirine burulan iki ince gövde
		var pts = []
		var rr = []
		for i in 12:
			var v = i / 11.0
			var a = v * TAU * 1.2 + q * PI
			pts.append(back * 0.75 * bs + Vector3(cos(a), 0, sin(a)) * 0.18 * bs + Vector3.UP * (v * 7.0 * bs - 0.2))
			rr.append(lerpf(0.26, 0.06, v) * bs)
		_grow_tube(root, pts, rr, BARK.darkened(0.1), BARK.lightened(0.15), 0.55, 0.0, toon, ink, 7)
	var er = _rad(tt) + 0.08
	for k in 4:   # sarmal dallar bedeni sarar
		var pts2 = _wrap_pts(back, (0.5 + k * 0.42) * bs, 0.3 * bs, 0.7 * bs, er * bs, 1.3 if k % 2 == 0 else -1.3, 14)
		var rr2 = []
		for i in 14:
			rr2.append(lerpf(0.11, 0.05, i / 13.0) * bs)
		_grow_tube(root, pts2, rr2, BARK, MOSS, 0.4, 0.15 + k * 0.05, toon, ink, 6)
	for k in 6:   # tepede kıvrık çıplak dallar
		var a = TAU * k / 6.0
		var p0 = back * 0.75 * bs + Vector3.UP * (4.6 + k * 0.4) * bs
		var bp = [p0, p0 + Vector3(cos(a), 0.8, sin(a)) * 1.2 * bs, p0 + Vector3(cos(a + 0.6), 1.0, sin(a + 0.6)) * 2.0 * bs]
		_grow_tube(root, bp, [0.09 * bs, 0.05 * bs, 0.01], BARK, BARK.lightened(0.2), 0.3, 0.45, toon, ink, 5)
	Combat.popup_text(at + Vector3.UP * 3.2, "Ağaca bağlandı!", YUHI_RED)
	for k in 9:   # kunailer dört bir yandan saplanır
		pj.after(0.75 + k * 0.11, func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			if cc == null or x == null or not pj.live(cc) or not pj.live(x):
				return
			var a = k * 2.4
			var o = Vector3(cos(a), 0.35 + 0.25 * sin(k * 1.3), sin(a)).normalized()
			if o.dot(bd) > 0.5:   # ağacın arkasından gelmez
				o = (o - bd * 1.4).normalized()
			var aim: Vector3 = x.global_position + Vector3.UP * (0.7 + (k % 3) * 0.35) * bs
			var from: Vector3 = aim + o * 6.5
			var kb = MB.new()
			CharacterModel._kunai_mesh(kb)
			var kn = _mi(kb.build(null), Props.toon(), _ink(0.01))
			kn.scale = Vector3.ONE * 1.5
			var last = k == 8
			var pr = pj.shot(cc, from, (aim - from).normalized(), 46.0, kn, pj.inf(cc, id, 0.9 if last else 0.3, {"knock": 6.0 if last else 0.0, "kind": "heavy" if last else "light", "bleed": 3.0, "hitstop": 0.02}), null, false, 0.4)
			pr.radius = 0.5
			# kunai havada taç yaprağı kıvılcımından belirir, ardında ince pembe iz
			var sp = _mi(_star_mesh(), _bill("petal_star", true, Color(1.0, 0.7, 0.85)))
			_scene(pj).add_child(sp)
			sp.global_position = from
			sp.scale = Vector3.ONE * 0.6
			var st2 = sp.create_tween()
			st2.tween_property(sp, "scale", Vector3.ONE * 0.01, 0.2)
			st2.tween_callback(sp.queue_free)
			_scatter(pj, _petal_mesh(), from, 5, 0.2, 2.0, 0.6, 0.12, float(k))
			_proj_trail(pj, pr, 0.45, 0.05, Color(1.0, 0.75, 0.85, 0.8), 6)
			Sfx.play("kunai", from, 1.2 + k * 0.03, 0.6))
	var rw = weakref(root)
	pj.after(hold, func():   # kai: ağaç çözülür
		var rn = rw.get_ref()
		if rn == null:
			return
		_scatter(pj, _petal_mesh(), at + Vector3.UP * 2.5 * bs, 40, 1.6 * bs, 5.0, 1.3, 0.18 * bs, 7.0)
		var kt = (rn as Node3D).create_tween()
		kt.tween_property(rn, "scale", Vector3(0.6, 0.03, 0.6), 0.35).set_ease(Tween.EASE_IN)
		kt.tween_callback(rn.queue_free))


## Yanılsama kulesi: taş bloklardan sekizgen kule, mazgal dişleri, patlayıcı etiketler. Kamera yakınsa kameraya bakan yay açık.
static func _tower(pj: PathJutsu, at: Vector3, s: float) -> Array:
	var root = Node3D.new()
	pj.scene_add(root, at)
	var to_cam = -_away(pj, at, Vector3.FORWARD)
	var open = _cam_near(pj, at, 14.0)
	var b = MB.new()
	var tb = MB.new()
	var tags = []
	var R = 1.7 * s
	var rows = 8
	for r in rows:
		var y = (0.35 + r * 0.65) * s
		var rr = R * (1.0 - r * 0.02)
		for k in 12:
			var a = TAU * (k + (0.5 if r % 2 == 1 else 0.0)) / 12.0
			var dir = Vector3(cos(a), 0, sin(a))
			if open and dir.dot(to_cam) > 0.45:
				continue
			var col = Color(0.62, 0.6, 0.57).darkened(0.18 * _r(r * 12 + k, 1.0))
			b.add("box", dir * rr + Vector3.UP * y, Vector3(0.86, 0.6, 0.5) * s, col, Vector3(0, -rad_to_deg(a) + 90.0, 0))
			if (r * 5 + k * 3) % 7 == 0 and r < rows - 1:   # etiket
				var tp = dir * (rr + 0.27 * s) + Vector3.UP * y
				tb.add("box", tp, Vector3(0.2, 0.42, 0.014) * s, Color(0.96, 0.93, 0.82), Vector3(0, -rad_to_deg(a) + 90.0, 0))
				tb.add("box", tp + dir * 0.01, Vector3(0.06, 0.3, 0.014) * s, Color(0.75, 0.12, 0.1), Vector3(0, -rad_to_deg(a) + 90.0, 0))
				tags.append(at + tp)
	for k in 8:   # mazgal dişleri
		var a = TAU * k / 8.0
		var dir = Vector3(cos(a), 0, sin(a))
		if open and dir.dot(to_cam) > 0.45:
			continue
		b.add("box", dir * R * 0.9 + Vector3.UP * (rows * 0.65 + 0.45) * s, Vector3(0.6, 0.6, 0.45) * s, Color(0.58, 0.56, 0.53), Vector3(0, -rad_to_deg(a) + 90.0, 0))
	root.add_child(_mi(b.build(null), Props.toon(), _ink(0.03)))
	if not tb.is_empty():
		root.add_child(_mi(tb.build(null), Props.toon()))
	return [root, tags]


## Cel ateş topu: sarı çekirdekli turuncu bulutlar büyür, kül griye döner
static func _blast(pj: PathJutsu, p: Vector3, s: float, seed: float) -> void:
	var fm = _blob_mat("fire", Color(1.0, 0.92, 0.45, 1.0), Color(1.0, 0.45, 0.1, 0.95), 1.2, 4.0)
	var am = _blob_mat("ash", Color(0.5, 0.47, 0.45, 0.8), Color(0.3, 0.28, 0.27, 0.75), 1.2, 4.0)
	for k in 4:
		var o = Vector3(_r(k, seed) - 0.5, _r(k, seed + 1.0) * 0.6, _r(k, seed + 2.0) - 0.5) * 1.2 * s
		_puff(pj, fm, p + o, 0.3 * s, (1.5 + 0.6 * _r(k, seed + 3.0)) * s, 0.32, Vector3.UP * 0.6 * s, seed + k)
		pj.after(0.18, func(): _puff(pj, am, p + o + Vector3.UP * 0.4 * s, 1.0 * s, 2.0 * s, 0.7, Vector3.UP * 1.5 * s, seed + k + 9.0, 0.8))
	_flash(pj, p, Color(1.0, 0.6, 0.2), 5.0, 9.0, 0.35)


## Magen: Jutō (ref: rakip bir kuleye hapsolduğunu sanır; etiketler tutuşur, kule patlayıp çöker)
static func magen_juto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	if tt == null:
		return
	var id = "magen_juto"
	pj._face(c, tt)
	pj._yama_seal(c)
	Sfx.play("genjutsu", c.global_position, 0.8)
	var gm = Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	var cw = weakref(c)
	var tw = weakref(tt)
	var bs = maxf(1.0, ClanJutsu.body_scale(tt))
	var at: Vector3 = pj.gp(tt.global_position)
	var hold = 2.2 * gm
	pj.st(tt, "bind", hold + 0.1)
	_daze(pj, tt, hold, YUHI_RED)
	var tw_res = _tower(pj, at, bs)
	var tower: Node3D = tw_res[0]
	var tags: Array = tw_res[1]
	tower.scale = Vector3(1, 0.02, 1)
	var tt2 = tower.create_tween()
	tt2.tween_property(tower, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dust_ring(pj, at, 3.6 * bs, EARTH_C, 22, 0.8, 1.0)
	_chunks(pj, at + Vector3.UP * 0.2, 10, 5.0, Color(0.55, 0.5, 0.45), 0.22 * bs, 0.9, 2.0)
	Sfx.play("earth", at, 0.8)
	Combat.popup_text(at + Vector3.UP * 6.6 * bs, "Kuleye hapsoldu!", YUHI_RED)
	var wr = weakref(tower)
	for k in mini(6, tags.size()):   # etiketler sırayla tutuşur: kızıl kıvılcım + ışık
		var tp: Vector3 = tags[k]
		pj.after(hold - 0.65 + k * 0.1, func():
			var sp = _mi(_star_mesh(), _bill("ember", true, Color(1.0, 0.55, 0.2)))
			_scene(pj).add_child(sp)
			sp.global_position = tp
			sp.scale = Vector3.ONE * 0.2
			var stw = sp.create_tween()
			stw.tween_property(sp, "scale", Vector3.ONE * 0.7, 0.15)
			stw.tween_property(sp, "scale", Vector3.ONE * 0.3, 0.2)
			stw.tween_callback(sp.queue_free)
			_flash(pj, tp, Color(1.0, 0.6, 0.2), 2.0, 3.0, 0.25))
	pj.after(hold, func():
		var tn = wr.get_ref()
		if tn != null:   # kule çöker: yana yatıp yere gömülür
			var ct = (tn as Node3D).create_tween()
			ct.tween_property(tn, "rotation:z", 0.35, 0.45).set_ease(Tween.EASE_IN)
			ct.parallel().tween_property(tn, "scale", Vector3(1.15, 0.08, 1.15), 0.45).set_ease(Tween.EASE_IN)
			ct.tween_callback(tn.queue_free)
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for k in 5:
			var a = k * 1.26
			_blast(pj, at + Vector3(cos(a) * 1.5 * bs, (0.8 + k * 1.0) * bs, sin(a) * 1.5 * bs), bs, float(k) * 3.0)
		_chunks(pj, at + Vector3.UP * 2.5 * bs, 26, 12.0, Color(0.6, 0.58, 0.56), 0.4 * bs, 1.4, 5.0)
		_chunks(pj, at + Vector3.UP * 4.5 * bs, 16, 9.0, Color(0.5, 0.48, 0.47), 0.55 * bs, 1.5, 6.0)
		_dust_ring(pj, at, 5.0 * bs, Color(0.5, 0.46, 0.42), 26, 1.2, 7.0)
		_cracks(pj, at, 3.5 * bs, 7, Color(0.08, 0.06, 0.05, 0.85), 5.0, 3.0)
		pj.shake(0.9)
		Sfx.play("boom", at, 0.7)
		var x = tw.get_ref()
		if x != null and pj.live(x):
			x.take_hit(pj.inf(cc, id, 4.2, {"knock": 8.0, "launch": 3.0, "kind": "heavy", "element": "katon", "burn": 2.5, "hitstop": 0.1})))


## Genjutsu: Shinkirō (ref: pembe yaprak fırtınası ve sisin içinde ağaç gövdeleri belirir; kullanıcı kaybolur, görünmez yumruk,
## sonra rakibin önünde belirip tekme)
static func genjutsu_shinkiro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.5)
	var id = "genjutsu_shinkiro"
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var cen: Vector3 = c.global_position
	var g = pj.gp(cen)
	# ayak yere vurulur: küçük çatlak + halka halinde yaprak sıçraması
	_cracks(pj, g, 1.6, 6, Color(0.1, 0.07, 0.07, 0.8), 2.5, 11.0)
	_scatter(pj, _petal_mesh(), g + Vector3.UP * 0.2, 30, 0.6, 5.0, 1.0, 0.16, 12.0, 0.6)
	# pembe sis: kameraya yakın kısımlar söner, yalnız alan içinde
	var mist = _blob_mat("shinkiro", Color(1.0, 0.74, 0.86, 0.42), Color(0.92, 0.5, 0.7, 0.32), 2.5, 7.0)
	for k in 14:
		var a = TAU * k / 14.0 + _r(k, 4.0)
		var rr = 2.0 + 4.5 * _r(k, 5.0)
		var p = g + Vector3(cos(a) * rr, 0.6 + 2.2 * _r(k, 6.0), sin(a) * rr)
		_puff(pj, mist, p, 1.6, 3.8 + _r(k, 7.0) * 1.6, 2.2, Vector3.UP * 0.5, float(k), 1.0)
	# yanılsama ağaç gövdeleri sisin içinde yükselir (referans)
	var trunks = Node3D.new()
	pj.scene_add(trunks, g)
	var toon = Props.toon()
	for k in 6:
		var a = TAU * k / 6.0 + 0.4
		var rr = 4.0 + 1.6 * _r(k, 8.0)
		var base = Vector3(cos(a) * rr, -0.2, sin(a) * rr)
		var pts = []
		var rad = []
		for i in 6:
			var v = i / 5.0
			pts.append(base + Vector3(sin(v * 3.0 + k) * 0.3, v * 7.0, cos(v * 2.0 + k) * 0.3))
			rad.append(lerpf(0.34, 0.2, v))
		var mi = _mi(_tube(pts, rad, Color(0.32, 0.18, 0.16), Color(0.5, 0.28, 0.3), 7, 0.25), toon, _ink(0.025))
		trunks.add_child(mi)
	trunks.scale = Vector3(1, 0.02, 1)
	var trw = trunks.create_tween()
	trw.tween_property(trunks, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	trw.tween_interval(1.2)
	trw.tween_property(trunks, "scale", Vector3(1, 0.02, 1), 0.4).set_ease(Tween.EASE_IN)
	trw.tween_callback(trunks.queue_free)
	# yaprak fırtınası: kullanıcının çevresinde yükselen sarmal
	_swarm(pj, _petal_mesh(), _vc("petal", false, 0.7, 2.6), 90, 2.0, func(i: int, u: float) -> Array:
		var a = TAU * _r(i, 9.0) + u * 6.0 * (0.7 + _r(i, 10.0))
		var rr = 1.0 + 5.0 * _r(i, 11.0)
		var p = g + Vector3(cos(a) * rr, 0.2 + u * 3.5 * _r(i, 12.0) + _r(i, 13.0) * 1.5, sin(a) * rr)
		var b = Basis.from_euler(Vector3(u * 14.0 + i, a, u * 6.0)).scaled(Vector3.ONE * 0.2)
		return [Transform3D(b, p), Color(1, 1, 1, minf(1.0, u * 10.0) * (1.0 - smoothstep(0.75, 1.0, u)))])
	Sfx.play("genjutsu", cen, 1.1)
	var m = c.get("model")
	pj.after(0.25, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if is_instance_valid(m):
			m.visible = false   # sisin içinde kaybolur
		for e in pj.enemies_near(cc, cen, 12.0):
			if Eyes.genjutsu_land(cc, e, false) > 0.0:
				if e.has_method("lose_target"):
					e.lose_target(1.6)
				_daze(pj, e, 1.4, SAKURA))
	pj.after(0.8, func():   # görünmeyen yumruk: yalnız darbe izi (yumruk biçimli halka + hız çizgileri)
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or not pj.live(cc) or x == null or not pj.live(x):
			return
		var fd = (x.global_position - cen)
		fd.y = 0
		fd = fd.normalized() if fd.length() > 0.2 else d
		cc.global_position = pj.gp(x.global_position - fd * 1.2)
		var hp: Vector3 = x.global_position + Vector3.UP * 1.1
		var sd = fd.cross(Vector3.UP)
		for k in 7:   # hız çizgileri darbe noktasında toplanır
			var o = (sd * (_r(k, 14.0) - 0.5) * 1.6 + Vector3.UP * (_r(k, 15.0) - 0.5) * 1.2)
			_path_ribbon(pj, func(s: float) -> Vector3: return hp - fd * (2.4 - s * 2.2) + o * (1.0 - s * 0.7), 0.16, 0.05, Color(1, 0.85, 0.92, 0.9), 0.6)
		_scatter(pj, _petal_mesh(), hp, 18, 0.2, 6.0, 0.7, 0.15, 16.0)
		_flash(pj, hp, SAKURA, 3.0, 4.0, 0.2)
		Sfx.play("punch", x.global_position, 0.9)
		x.take_hit(pj.inf(cc, id, 0.9, {"knock": 13.0, "launch": 6.5, "kind": "heavy", "hitstop": 0.07, "dir": fd})))
	pj.after(1.15, func():   # havada dönen rakibin önünde belirir
		var cc = cw.get_ref()
		if is_instance_valid(m):
			m.visible = true
		var x = tw.get_ref() if tw else null
		if cc == null or not pj.live(cc) or x == null or not pj.live(x):
			return
		var fd = (x.global_position - cc.global_position)
		fd.y = 0
		fd = fd.normalized() if fd.length() > 0.2 else d
		cc.global_position = x.global_position - fd * 1.1 + Vector3.UP * 0.2
		if cc is CharacterBody3D:
			cc.velocity = Vector3.UP * 2.0
		_scatter(pj, _petal_mesh(), cc.global_position + Vector3.UP, 30, 0.5, 3.0, 0.8, 0.17, 17.0)
		pj._kick_pose(cc, 0.3)
		var kp: Vector3 = x.global_position + Vector3.UP * 1.0
		var sd2 = fd.cross(Vector3.UP)
		var cp: Vector3 = cc.global_position + Vector3.UP * 1.0
		_path_ribbon(pj, func(s: float) -> Vector3:   # tekme yayı
			var a = lerpf(-1.4, 1.2, s)
			return cp + fd * cos(a) * 1.4 + Vector3.UP * sin(a) * 1.2 + sd2 * 0.2, 0.22, 0.2, Color(0.95, 0.35, 0.5, 0.95), 0.6, false)
		_flash(pj, kp, YUHI_RED, 3.5, 5.0, 0.25)
		pj.shake(0.5)
		Sfx.play("punch", x.global_position, 0.7)
		x.take_hit(pj.inf(cc, id, 1.8, {"knock": 20.0, "launch": 0.0, "kind": "heavy", "hitstop": 0.1, "dir": fd})))
	pj.after(1.5, func():
		if is_instance_valid(m):
			m.visible = true)


## Fasulye sarmaşığı: yerden sarmal kıvrılarak yükselen sap, yürek yaprakları, uçta kıvrık filiz
static func _bean_vine(pj: PathJutsu, parent: Node3D, base: Vector3, h: float, phase: float, dir: float) -> void:
	var pts = []
	var rad = []
	var n = 16
	for i in n:
		var v = float(i) / (n - 1)
		var a = phase + v * TAU * 1.4 * dir
		var rr = lerpf(0.35, 0.5, sin(v * PI))
		pts.append(base + Vector3(cos(a) * rr, v * h, sin(a) * rr))
		rad.append(lerpf(0.07, 0.025, v))
	var tip: Vector3 = pts[n - 1]   # uçta kıvrık filiz
	for i in 5:
		var a = phase + 1.0 + i * 1.4 * dir
		pts.append(tip + Vector3(cos(a) * 0.12 * (5 - i), 0.05 * i, sin(a) * 0.12 * (5 - i)) * 0.6)
		rad.append(0.02)
	_grow_tube(parent, pts, rad, BEAN.darkened(0.2), BEAN.lightened(0.1), 0.6, 0.0, Props.toon(), _ink(0.012), 6)
	var lm = _vc("bean_leaf", false, 0.6, 2.2)
	for k in 5:   # yürek yaprakları sapın boyunda belirir
		var idx = 2 + k * 3
		var p: Vector3 = pts[idx]
		var out = _flat(p - base, Vector3.RIGHT)
		var lf = _mi(_heart_mesh(), lm)
		parent.add_child(lf)
		lf.position = p
		lf.basis = _yb(out + Vector3.UP * 0.4).scaled(Vector3.ONE * 0.01)
		var lt = lf.create_tween()
		lt.tween_interval(0.1 + k * 0.1)
		lt.tween_property(lf, "scale", Vector3.ONE * 0.38, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Genjutsu: Ingen Shibari — kullanıcı kaybolur, sarmaşıklar kurbanı sarıp kaldırır, fasulye kabuğu yerden çıkar ve açılır
static func yuhi_sarmasik(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var gm = Eyes.genjutsu_land(c, tt, true)
	if gm <= 0.0:
		return
	var m = c.get("model")
	if m:
		m.visible = false   # kullanıcı kaybolur
	var hold = 3.5 * gm
	pj.after(0.25, func():
		if not pj.live(tt):
			return
		var vines = Node3D.new()
		pj.scene_add(vines, pj.gp(tt.global_position))
		for k in 5:
			var a = k * TAU / 5.0
			_bean_vine(pj, vines, Vector3(cos(a), 0, sin(a)) * 0.6, 3.0, a, 1.0 if k % 2 == 0 else -1.0)
		var vw = weakref(vines)
		pj.after(hold, func():   # sarmaşıklar solar, yapraklar dökülür
			var vn = vw.get_ref()
			if vn == null:
				return
			_scatter(pj, _heart_mesh(), (vn as Node3D).global_position + Vector3.UP * 1.6, 18, 0.8, 3.0, 1.2, 0.3, 21.0)
			var wt = (vn as Node3D).create_tween()
			wt.tween_property(vn, "scale", Vector3(1.3, 0.02, 1.3), 0.4).set_ease(Tween.EASE_IN)
			wt.tween_callback(vn.queue_free))
		_daze(pj, tt, hold, BEAN.lightened(0.3))
		pj.st(tt, "bind", hold)
		var up = tt.create_tween()   # sarmaşıklar hedefi havaya kaldırır
		up.tween_property(tt, "global_position", tt.global_position + Vector3.UP * 1.6, 0.6).set_trans(Tween.TRANS_SINE)
		# fasulye kabuğu yerden yükselir ve iki yarısı açılır
		var front = pj.gp(tt.global_position + ((c.global_position - tt.global_position) * Vector3(1, 0, 1)).normalized() * 1.6)
		var pod = Node3D.new()
		_scene(pj).add_child(pod)
		pod.global_position = front - Vector3.UP * 2.0
		var halves = []
		for sx in [-1.0, 1.0]:
			var hv = Node3D.new()
			pod.add_child(hv)
			var pts = []
			var rad = []
			for i in 9:
				var v = i / 8.0
				pts.append(Vector3(sx * 0.12, v * 2.3, sin(v * PI) * 0.12))
				rad.append(maxf(0.03, sin(pow(v, 0.8) * PI) * 0.42))
			hv.add_child(_mi(_tube(pts, rad, BEAN.darkened(0.15), BEAN.lightened(0.2), 9, 0.08), Props.toon(), _ink(0.02)))
			hv.scale = Vector3(0.55, 1, 1)
			halves.append([hv, sx])
		pod.global_basis = Basis.looking_at(_flat(tt.global_position - front), Vector3.UP)   # yarılar kurbana göre yana açılır
		var ptw = pod.create_tween()
		ptw.tween_property(pod, "global_position", front, 0.5).set_trans(Tween.TRANS_BACK)
		ptw.tween_property(halves[0][0], "rotation:z", -float(halves[0][1]) * 1.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # kabuk açılır
		ptw.parallel().tween_property(halves[1][0], "rotation:z", -float(halves[1][1]) * 1.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.tween_callback(func():
			_scatter(pj, _heart_mesh(), front + Vector3.UP * 1.2, 8, 0.4, 2.5, 0.8, 0.25, 22.0)
			var pt2 = pod.create_tween()
			pt2.tween_property(pod, "scale", Vector3(1.2, 0.02, 1.2), 0.3).set_ease(Tween.EASE_IN)
			pt2.tween_callback(pod.queue_free)
			if is_instance_valid(c):
				c.global_position = front
				if c.get("model"):
					c.model.visible = true
				if pj.live(tt):
					pj._kick_pose(c, 0.25)
					_stab_flash(pj, tt.global_position + Vector3.UP * 1.0, tt.global_position - front, BEAN.lightened(0.3))
					tt.take_hit(pj.inf(c, "yuhi_sarmasik", 1.4, {"knock": 6.0, "launch": 0.0, "kind": "heavy", "pierce_guard": true})))
		pj.every(hold, 0.7, func(_i, _k):
			if pj.live(tt):
				tt.take_hit(pj.inf(c, "yuhi_sarmasik", 0.2, {"knock": 0.0, "launch": 0.0, "kind": "light"})), Callable()))
	pj.after(2.0, func():   # güvence
		if is_instance_valid(c) and c.get("model"):
			c.model.visible = true)
	Sfx.play("genjutsu", c.global_position, 1.0)


# ================================================================== SARUTOBİ
## Chakra Bıçağı: Düz Hat (ref: Asuma — bıçaktan uzayan ince mavi rüzgâr chakrası, tek yatay çizgi). Elde mavi bıçak,
## 15 m uzanan ince kesik hattı (beyaz çekirdek, mavi kabuk), yanında rüzgâr çizikleri, yerde ince yarık
static func chakura_to_maichimonji(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var bmat = _glass("asuma_blade", Color(0.75, 0.9, 1.0, 0.55), Color(0.35, 0.62, 1.0, 1.0), 1.6, 0.6, false, 0.5, 1.6)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:   # elde chakra bıçağı (titreşen ince yaprak)
		var bb = MB.new()
		bb.add("sphere", Vector3(0, 0, 0.5), Vector3(0.03, 0.08, 0.9), Color.WHITE, Vector3.ZERO, 10)   # bıçak kemiğin +Z yönünde
		var bl = _mi(bb.build(null), bmat)
		ba.add_child(bl)
		var fl = bl.create_tween().set_loops(12)
		fl.tween_property(bl, "scale", Vector3(1.3, 1, 1.08), 0.04)
		fl.tween_property(bl, "scale", Vector3(0.9, 1, 0.96), 0.04)
		pj.free_after(1.0, ba)
	pj.busy(c, 0.6)
	pj.after(0.3, func():
		var a = c.global_position + Vector3.UP * 1.1 + d * 0.5
		var b = a + d * 15.0
		# uzanan kesik hattı: 0.07 sn'de 15 m, sonra incelip söner
		var beam = MB.new()
		beam.add("sphere", Vector3(0, 0, -0.5), Vector3(0.12, 0.05, 1.0), Color.WHITE, Vector3.ZERO, 10)
		var core = _mi(beam.build(null), _glass("asuma_line", Color(0.95, 0.98, 1.0, 0.9), Color(0.4, 0.7, 1.0, 1.0), 1.2, 0.0, false, 0.6, 2.0))
		_scene(pj).add_child(core)
		core.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), a)
		core.scale = Vector3(1, 1, 0.01)
		var ct = core.create_tween()
		ct.tween_property(core, "scale", Vector3(1, 1, 15.0), 0.07).set_ease(Tween.EASE_OUT)
		ct.tween_interval(0.12)
		ct.tween_property(core, "scale", Vector3(0.05, 0.3, 15.0), 0.25).set_ease(Tween.EASE_IN)
		ct.tween_callback(core.queue_free)
		var sd = d.cross(Vector3.UP)
		for k in 4:   # hattın iki yanında rüzgâr çizikleri
			var o = sd * (0.25 + 0.2 * k) * (1.0 if k % 2 == 0 else -1.0) + Vector3.UP * (_r(k, 30.0) - 0.5) * 0.4
			pj.after(k * 0.03, func(): _path_ribbon(pj, func(s: float) -> Vector3: return a + o + d * 15.0 * s, 0.22, 0.05, Color(0.7, 0.88, 1.0, 0.8), 0.3))
		_path_ribbon(pj, func(s: float) -> Vector3:   # uçta kesik hilali
			var an = lerpf(-1.2, 1.2, s)
			return b + sd * sin(an) * 1.4 + d * (cos(an) - 1.0) * 0.6, 0.2, 0.18, Color(0.8, 0.92, 1.0, 0.9), 0.7)
		_scar(pj, [a - Vector3.UP * 1.1, a.lerp(b, 0.5) - Vector3.UP * 1.1, b - Vector3.UP * 1.1], 0.06, Color(0.08, 0.1, 0.16, 0.7), 2.0)
		for k in 10:
			pj.hit(c, a.lerp(b, k / 9.0), 0.9, pj.inf(c, "chakura_to_maichimonji", 0.25, {"knock": 6.0, "kind": "heavy"}))
		pj.anim(c, "slash_a", 2.2)
		Sfx.play("whoosh", a, 1.4))


## Mühür etiketi (kâğıt + kızıl yazı)
static func _tag_mesh() -> ArrayMesh:
	var k = "mesh:tag"
	if _cache.has(k):
		return _cache[k]
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.18, 0.4, 0.012), Color(1.0, 0.86, 0.84))
	b.add("box", Vector3(0, 0.05, 0.008), Vector3(0.05, 0.24, 0.006), Color(0.82, 0.1, 0.12))
	b.add("box", Vector3(0, 0.0, 0.008), Vector3(0.12, 0.03, 0.006), Color(0.82, 0.1, 0.12))
	b.add("box", Vector3(0, -0.13, 0.008), Vector3(0.1, 0.03, 0.006), Color(0.82, 0.1, 0.12))
	var m = b.build(null)
	_cache[k] = m
	return m


## Eterik maymun eli (ref: içi beyaz-pembe, kızıl kenarlı yarı saydam yumruk, bilekte kızıl kabarık kol yeni). +Z parmaklar.
static func _ape_hand(s: float) -> Node3D:
	var root = Node3D.new()
	var gm = _glass("enra_hand", Color(1.0, 0.9, 0.92, 0.5), Color(1.0, 0.18, 0.22, 1.0), 2.2, 0.55, false, 1.0, 3.5)
	var palm = MB.new()
	palm.add("sphere", Vector3(0, 0, 0.1), Vector3(1.0, 0.45, 0.95), Color.WHITE, Vector3.ZERO, 12)
	root.add_child(_mi(palm.build(null), gm))
	var fingers = []
	for f in 4:
		var x = (f - 1.5) * 0.24
		var kn = Node3D.new()
		root.add_child(kn)
		kn.position = Vector3(x, 0.02, 0.5)
		var chain = [kn]
		var par = kn
		for sgi in 3:
			var L = [0.36, 0.28, 0.22][sgi] * (0.85 if f == 3 else 1.0)
			var sb = MB.new()
			sb.add("sphere", Vector3(0, 0, L * 0.5), Vector3(0.21, 0.21, L * 1.15), Color.WHITE, Vector3.ZERO, 8)
			par.add_child(_mi(sb.build(null), gm))
			if sgi < 2:
				var j = Node3D.new()
				par.add_child(j)
				j.position = Vector3(0, 0, L)
				chain.append(j)
				par = j
		fingers.append(chain)
	var th = Node3D.new()   # başparmak
	root.add_child(th)
	th.position = Vector3(-0.5, -0.05, 0.15)
	th.rotation.y = -0.7
	var tb = MB.new()
	tb.add("sphere", Vector3(0, 0, 0.25), Vector3(0.22, 0.22, 0.55), Color.WHITE, Vector3.ZERO, 8)
	th.add_child(_mi(tb.build(null), gm))
	fingers.append([th])
	# bilekte kızıl kabarık kol ağzı (sivri tutamlar)
	var cuff = MB.new()
	for k in 14:
		var a = TAU * k / 14.0
		cuff.add("cone", Vector3(cos(a) * 0.4, sin(a) * 0.25, -0.45), Vector3(0.14, 0.3, 0.14), Color(0.8, 0.12, 0.14), Vector3(90, 0, -rad_to_deg(a) + 90), 5)
	cuff.add("cyl", Vector3(0, 0, -0.75), Vector3(0.8, 0.55, 0.5), Color(0.62, 0.08, 0.1), Vector3(90, 0, 0), 12)
	root.add_child(_mi(cuff.build(null), Props.toon(), _ink(0.02)))
	root.set_meta("fingers", fingers)
	root.scale = Vector3.ONE * s
	return root


static func _ape_curl(hand: Node3D, k: float) -> void:
	if hand == null or not is_instance_valid(hand) or not hand.has_meta("fingers"):
		return
	var fingers: Array = hand.get_meta("fingers")
	for f in fingers.size():
		var chain: Array = fingers[f]
		if chain.size() == 1:   # başparmak
			(chain[0] as Node3D).rotation.x = 0.9 * k
			continue
		for j in chain.size():
			(chain[j] as Node3D).rotation.x = k * (0.9 if j == 0 else 1.15)


## Kongō Fūin: En'yō Fūsatsu — dört kızıl etiket hedefin çevresine saplanır; eterik maymun eli inip kafesler (chakra tükenince açılır)
static func kongo_fuin_enyo_fusatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Kongō Fūin: kafeslenecek hedef yok", Color(1, 0.85, 0.4))
		return
	pj.busy(c, 1.0)
	var id = "kongo_fuin_enyo_fusatsu"
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cen = pj.gp(tt.global_position)
	var cw = weakref(c)
	var tw = weakref(tt)
	var hp0 = pj.hand_pos(c)
	for k in 4:   # dört mühür etiketi hedefin çevresine saplanır
		var a = k * TAU / 4.0 + PI * 0.25
		var p: Vector3 = pj.gp(cen + Vector3(cos(a), 0, sin(a)) * 2.4) + Vector3.UP * 0.25
		var tag = _mi(_tag_mesh(), Props.toon(), _ink(0.008))
		pj.scene_add(tag, hp0)
		tag.rotation.y = -a
		tag.scale = Vector3.ONE * 1.4
		var tg2 = tag.create_tween()
		tg2.tween_interval(k * 0.04)
		tg2.tween_property(tag, "global_position", p, 0.18).set_ease(Tween.EASE_OUT)
		tg2.tween_callback(func():
			_flash(pj, p + Vector3.UP * 0.2, Color(1.0, 0.3, 0.25), 2.0, 3.0, 0.3)
			_path_ribbon(pj, func(s: float) -> Vector3: return p + Vector3.UP * s * 3.0, 0.3, 0.06, Color(1.0, 0.3, 0.3, 0.9), 0.5))
		pj.free_after(5.0, tag)
	Sfx.play("kunai", c.global_position, 1.1)
	var cage = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var sc = 1.9 * ClanJutsu.body_scale(x)
		var hand = _ape_hand(sc)
		var top: Vector3 = x.global_position + Vector3.UP * ((float(x.height) if "height" in x else 1.8) + 0.3) - d * 0.55 * sc
		pj.scene_add(hand, top + Vector3.UP * 5.0)
		hand.global_basis = Basis(Vector3.UP.cross(d), Vector3.UP, d).scaled(Vector3.ONE * sc)   # avuç aşağı, parmaklar öne
		_ape_curl(hand, 0.15)
		var hw = weakref(hand)
		var ht = hand.create_tween()
		ht.tween_property(hand, "global_position", top, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ht.tween_method(func(k: float):
			var h2 = hw.get_ref()
			if h2 != null:
				_ape_curl(h2, k), 0.15, 1.05, 0.18)
		# yumruğun çevresinde süzülen kızıl etiketler (referans)
		var orbit = Node3D.new()
		pj.scene_add(orbit, pj.gp(x.global_position))
		for k in 10:
			var a = TAU * k / 10.0
			var tg3 = _mi(_tag_mesh(), _glass("enra_tag", Color(1.0, 0.35, 0.35, 0.85), Color(1.0, 0.1, 0.1, 1.0), 1.5, 0.0, false, 0.8, 2.5))
			orbit.add_child(tg3)
			tg3.position = Vector3(cos(a) * 2.4 * sc * 0.6, (0.6 + 1.6 * _r(k, 31.0)) * sc * 0.6, sin(a) * 2.4 * sc * 0.6)
			tg3.rotation.y = -a + PI * 0.5
			tg3.scale = Vector3.ONE * 1.6
		var ot = orbit.create_tween().set_loops(10)
		ot.tween_property(orbit, "rotation:y", TAU, 4.0).as_relative()
		var ow = weakref(orbit)
		_dust_ring(pj, pj.gp(x.global_position), 2.6 * sc * 0.6, Color(0.55, 0.42, 0.36), 18, 0.6, 32.0)
		pj.st(x, "bind", 4.2)
		pj.st(x, "sealed", 4.2)
		Combat.popup_text(x.global_position + Vector3.UP * 3.0, "Maymun eli kafesledi!", Color(1, 0.85, 0.3))
		Sfx.play("seal", x.global_position, 0.8)
		var s = {"open": false}
		var open = func():
			if s["open"]:
				return
			s["open"] = true
			var o2 = ow.get_ref()
			if o2 != null:
				o2.queue_free()
			var h2 = hw.get_ref()
			if h2 != null:
				var t2 = (h2 as Node3D).create_tween()
				t2.tween_method(func(k: float):
					var h3 = hw.get_ref()
					if h3 != null:
						_ape_curl(h3, k), 1.05, 0.1, 0.2)
				t2.tween_property(h2, "scale", Vector3.ONE * 0.01, 0.25)
				t2.tween_callback(h2.queue_free)
		var hold = func(i, _k):
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			if s["open"]:
				return
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
				open.call()
				return
			if i % 5 == 4:
				x2.take_hit(pj.inf(c2, id, 0.22, {"knock": 0.0, "launch": 0.0, "kind": "crush", "hitstop": 0.0}))
				if "chakra" in c2:   # kullanıcıyı çabuk yorar
					c2.chakra = maxf(0.0, c2.chakra - c2.max_chakra * 0.045)
					if c2.chakra <= 0.0:
						if "statuses" in x2:
							x2.statuses.erase("bind")
							x2.statuses.erase("sealed")
						Combat.popup_text(x2.global_position + Vector3.UP * 2.6, "Kurtuldu!", Color(1, 0.6, 0.4))
						open.call()
		pj.every(4.0, 0.1, hold, open)
	pj.after(0.45, cage)


## Işık kirişi (iki nokta arası ince kutu)
static func _beam_box(b: MB, a: Vector3, c2: Vector3, w: float) -> void:
	var v = c2 - a
	var L = v.length()
	if L < 0.01:
		return
	var dn = v / L
	var bs = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT)
	b.add_xf("box", Transform3D(bs * Basis.from_scale(Vector3(w, w, L)), (a + c2) * 0.5), Color.WHITE)


## Gölge klonunun belirişi: kısa beyaz-mavi ışınsal çizgi patlaması (duman yok)
static func _clone_pop(pj: PathJutsu, p: Vector3) -> void:
	for k in 8:
		var a = TAU * k / 8.0
		var o = Vector3(cos(a), 0.4 * sin(k * 1.7), sin(a))
		_path_ribbon(pj, func(s: float) -> Vector3: return p + o * (0.3 + s * 1.2), 0.18, 0.05, Color(0.85, 0.95, 1.0, 0.9), 0.5)
	_flash(pj, p, Color(0.8, 0.9, 1.0), 2.0, 3.0, 0.2)


## Fūinjutsu: Sanpō Fūin (ref: üç kullanıcı arasında yeşil ışıklı dört yüzlü mühür; içinde dönen sis) — fırlatılıp göğe gider,
## yerde çukur kalır
static func fuinjutsu_sanpo_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Sanpō Fūin: mühürlenecek hedef yok", Color(0.75, 0.9, 1.0))
		return
	pj.busy(c, 1.5)
	var id = "fuinjutsu_sanpo_fuin"
	var d = pj._face(c, tt)
	var cen = pj.gp(tt.global_position)
	var R := 3.2
	var cw = weakref(c)
	var corners = []
	for k in 3:
		corners.append(pj.gp(cen + (-d).rotated(Vector3.UP, k * TAU / 3.0) * R))
	c.global_position = corners[0]
	if c is CharacterBody3D:
		c.velocity = Vector3.ZERO
	pj._face(c, tt)
	pj._yama_seal(c)
	var clones = []
	for k in [1, 2]:
		_clone_pop(pj, corners[k] + Vector3.UP)
		var cl = pj.decoy(c, corners[k], 2.0)
		cl.set_physics_process(false)   # yerinde durur, mühür tutar
		cl.rotation.y = atan2(-(cen - corners[k]).x, -(cen - corners[k]).z)
		if cl.get("model") and cl.model.get("overlay"):
			cl.model.overlay.set_pose("seal", 1.0)
		clones.append(weakref(cl))
	Sfx.play("poof", cen, 0.9)
	pj.st(tt, "bind", 1.2)
	var root = Node3D.new()
	pj.scene_add(root, cen)
	var apex = Vector3.UP * 4.6
	var loc = []
	for p in corners:
		loc.append(p - cen + Vector3.UP * 0.06)
	var emat = _glass("sanpo_edge", Color(0.75, 1.0, 0.6, 1.0), Color(0.3, 1.0, 0.35, 1.0), 1.0, 0.0, true, 0.6, 2.0)
	# yerde üçgen: köşelerden kenarlar ilerler
	var b1 = MB.new()
	for k in 3:
		_beam_box(b1, loc[k], loc[(k + 1) % 3], 0.1)
	var tri = _mi(b1.build(null), emat)
	root.add_child(tri)
	tri.scale = Vector3(0.05, 1, 0.05)
	tri.create_tween().tween_property(tri, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
	_swarm(pj, _sph(), _vc("seal_mote", true, 0.6, 2.0), 24, 1.0, func(i: int, u: float) -> Array:   # köşelerden yükselen yeşil zerreler
		var p: Vector3 = cen + (loc[i % 3] as Vector3) * (1.0 - u * 0.3) + Vector3.UP * (u * 3.0 * _r(i, 40.0)) + Vector3(sin(i + u * 6.0), 0, cos(i * 1.3 + u * 5.0)) * 0.3
		var s = 0.08 * (1.0 - u)
		return [Transform3D(Basis().scaled(Vector3.ONE * s), p), Color(0.5, 1.0, 0.55, 1.0 - u)])
	Sfx.play("seal", cen, 0.9)
	var up = func():
		if not is_instance_valid(root):
			return
		var b2 = MB.new()
		for k in 3:
			_beam_box(b2, loc[k], apex, 0.09)
		var ed = _mi(b2.build(null), emat)
		root.add_child(ed)
		ed.scale = Vector3(1, 0.02, 1)
		ed.create_tween().tween_property(ed, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
		# yüzler: içi dalgalanan yarı saydam yeşil
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ctr = (loc[0] + loc[1] + loc[2] + apex) / 4.0
		for k in 3:
			var a: Vector3 = loc[k]
			var b: Vector3 = loc[(k + 1) % 3]
			var nf = ((a + b + apex) / 3.0 - ctr).normalized()
			_tri(st, a, b, apex, nf, nf, nf, Color.WHITE, Color.WHITE, Color.WHITE)
		var faces = _mi(st.commit(), _glass("sanpo_face", Color(0.2, 0.75, 0.3, 0.32), Color(0.45, 1.0, 0.5, 0.7), 2.5, 0.9, false, 1.0, 3.5))
		root.add_child(faces)
		faces.scale = Vector3(1, 0.02, 1)
		faces.create_tween().tween_property(faces, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
		var fog = _blob_mat("sanpo_fog", Color(0.55, 1.0, 0.85, 0.45), Color(0.2, 0.7, 0.55, 0.35), 1.5, 4.0)
		for k in 4:   # içte dönen sis
			_puff(pj, fog, cen + Vector3(_r(k, 41.0) - 0.5, 0.8 + k * 0.5, _r(k, 42.0) - 0.5), 0.6, 1.5, 0.55, Vector3.UP * 0.4, float(k) + 40.0, 0.9)
		_flash(pj, cen + Vector3.UP * 2.0, SEAL_G, 4.0, 9.0, 0.6)
	pj.after(0.45, up)
	var fire = func():
		for wc in clones:
			var k2 = wc.get_ref()
			if k2 != null and is_instance_valid(k2) and not k2.is_dead():
				k2.vanish()
		if not is_instance_valid(root):
			return
		var rt = root.create_tween()
		rt.tween_property(root, "global_position", cen + Vector3.UP * 22.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rt.parallel().tween_property(root, "scale", Vector3(0.5, 1.6, 0.5), 0.45)
		rt.tween_callback(root.queue_free)
		var rw = weakref(root)
		var rsrc = func():
			var rn = rw.get_ref()
			return ((rn as Node3D).global_position + Vector3.UP * 2.0) if rn != null else null
		_trail(pj, rsrc, 0.9, 0.5, Color(0.5, 1.0, 0.55, 0.8), 10)   # göğe giden yeşil ışık izi
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, cen, R * 0.75):
			e.take_hit(pj.inf(cc, id, 2.6, {"knock": 0.0, "launch": 24.0, "kind": "heavy", "hitstop": 0.14, "stun": 1.2, "attacker": cc}))
		# yerde kalan çukur: koyu üçgen iz + çatlaklar + taş parçaları
		var crater = []
		for k in 4:
			crater.append(cen + (loc[k % 3] as Vector3) * 0.85)
		_scar(pj, crater, 0.3, Color(0.12, 0.09, 0.07, 0.9), 7.0)
		_cracks(pj, cen, 5.0, 8, Color(0.1, 0.08, 0.06, 0.9), 7.0, 43.0)
		_chunks(pj, cen, 18, 11.0, Color(0.5, 0.42, 0.32), 0.3, 1.3, 44.0)
		_dust_ring(pj, cen, 4.5, EARTH_C, 24, 1.0, 45.0)
		_flash(pj, cen + Vector3.UP, SEAL_G, 6.0, 10.0, 0.4)
		pj.shake(0.9)
		Sfx.play("boom", cen, 0.8)
	pj.after(0.95, fire)


## Çağırma mührü: yerde mürekkep halka + dışa yayılan yazı darbeleri
static func _ink_seal(pj: PathJutsu, at: Vector3, r: float, life: float) -> void:
	var col = Color(0.08, 0.06, 0.06, 0.92)
	var ring = []
	for k in 25:
		var a = TAU * k / 24.0
		ring.append(at + Vector3(cos(a), 0, sin(a)) * r)
	_scar(pj, ring, 0.07, col, life)
	for k in 12:
		var a = TAU * k / 12.0 + 0.13
		var dir = Vector3(cos(a), 0, sin(a))
		var side = dir.cross(Vector3.UP)
		_scar(pj, [at + dir * r * 0.25, at + dir * r * 0.6 + side * 0.08 * r, at + dir * r * 0.95], 0.05, col, life)
		_scar(pj, [at + dir * r * 1.05, at + dir * r * 1.35], 0.06, col, life)


## Sarutobi: Enma Kongōnyoi — maymun kral Enma çağrılır (gerçek çağrı modeli), elmas asaya dönüşür; asa uzayıp saplanır,
## sonra çevreye savrulur
static func sarutobi_enma_kongonyoi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var d = pj.fwd(c, t)
	var g = pj.gp(c.global_position + d * 0.8)
	_ink_seal(pj, g, 2.0, 1.4)
	# Enma (oyunun maymun kral çağrı modeli) bir an belirir, dönerek asaya büzülür
	var md: Dictionary = SummonModels.build("monkey_king", 2.0, 2.0)
	var enma = md.get("root") as Node3D
	if enma:
		pj.scene_add(enma, g + d.cross(Vector3.UP) * 0.6)
		enma.look_at(enma.global_position + d, Vector3.UP)
		enma.scale = Vector3.ONE * 0.05
		var et = enma.create_tween()
		et.tween_property(enma, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		et.tween_property(enma, "rotation:y", enma.rotation.y + TAU, 0.14)
		et.parallel().tween_property(enma, "scale", Vector3(0.06, 1.2, 0.06), 0.14).set_ease(Tween.EASE_IN)
		et.tween_callback(enma.queue_free)
	_flash(pj, g + Vector3.UP, ENMA_G, 3.0, 5.0, 0.3)
	# oyunun gerçek Kongōnyoi modeli (Elmas Asa silahıyla aynı: CharacterModel.weapon_mesh "kongo_asa", sap +Z boyunca ~1.25 m)
	var staff = MeshInstance3D.new()
	staff.mesh = CharacterModel.weapon_mesh("kongo_asa")
	_scene(pj).add_child(staff)
	var sp0 = c.global_position + Vector3.UP * 1.2 + d * 0.3 + d.cross(Vector3.UP) * 0.3
	staff.global_position = sp0
	staff.look_at(sp0 - d, Vector3.UP)   # look_at -Z'yi çevirir; asa +Z boyunca: nişan yönüne uzanır
	var sw = weakref(staff)
	var tip = func():   # asanın ucu (dünya)
		var s2 = sw.get_ref()
		if s2 == null:
			return null
		return (s2 as Node3D).global_transform * Vector3(0, 0, 1.2)
	var tw = staff.create_tween()
	tw.tween_property(staff, "scale", Vector3(1.6, 1.6, 12.0), 0.18)
	tw.tween_callback(func():
		Combat.hit_zone(c, c.global_position, d, 15.0, 8.0, 1.5, pj.inf(c, "sarutobi_enma_kongonyoi", 1.6, {"knock": 18.0, "kind": "heavy", "hitstop": 0.1}))
		var ip = pj.gp(c.global_position + d * 14.0)   # uçta yer yarılır, taş fışkırır
		_cracks(pj, ip, 3.0, 6, Color(0.1, 0.08, 0.06, 0.9), 4.0, 50.0)
		_chunks(pj, ip + Vector3.UP * 0.3, 14, 8.0, Color(0.52, 0.44, 0.34), 0.28, 1.1, 51.0)
		_dust_ring(pj, ip, 2.4, EARTH_C, 16, 0.7, 52.0)
		_flash(pj, ip + Vector3.UP, ENMA_G, 3.0, 6.0, 0.3))
	tw.tween_callback(func(): _trail(pj, tip, 0.6, 0.6, Color(1.0, 0.82, 0.35, 0.85), 14))   # savruluş yayı (altın)
	tw.tween_property(staff, "rotation:y", TAU, 0.45)
	tw.tween_callback(func():
		pj.hit(c, c.global_position + Vector3.UP, 7.0, pj.inf(c, "sarutobi_enma_kongonyoi", 0.8, {"knock": 14.0, "kind": "heavy"}))
		_dust_ring(pj, pj.gp(c.global_position), 7.0, EARTH_C, 30, 0.9, 53.0)
		_scatter(pj, _leaf_mesh(), c.global_position + Vector3.UP * 0.5, 16, 3.0, 6.0, 1.0, 0.2, 54.0, 0.6))
	tw.tween_property(staff, "scale", Vector3(1, 1, 1), 0.15)
	tw.tween_callback(func():
		_flash(pj, c.global_position + Vector3.UP * 1.2, ENMA_G, 2.0, 3.0, 0.25)
		staff.queue_free())
	Sfx.play("blade", c.global_position, 0.6)


## Sarutobi: Shuriken Kage Bunshin — bir-iki gerçek shuriken fırlatılır, havada hayalet kopyalar halkası halinde
## yüzlercesine bölünüp hedef bölgesine yağar; çoğu yere saplanıp kalır
static func sarutobi_shuriken_tajuu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 28.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	pj.anim(c, "throw", 1.4)
	var mkm = func(scale: float) -> Mesh:
		var sb = MB.new()
		CharacterModel._w_star(sb, Vector3.ZERO, 0.19 * scale, 0.06 * scale, 4, Color(0.62, 0.64, 0.68), Color(0.15, 0.15, 0.17))
		var b = MB.new()
		b.add_mesh(sb, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
		return b.build(null)
	var mk = func(scale: float) -> Node3D:
		return _mi(mkm.call(scale), Props.toon())
	var split = []
	pj.after(0.15, func():
		if not pj.live(c):
			return
		for q in 2:
			var from = pj.hand_pos(c, true)
			var mid = from.lerp(at + Vector3.UP * 1.2, 0.35) + Vector3.UP * (1.2 + q * 0.4)
			var sh = mk.call(1.6)
			pj.scene_add(sh, from)
			var tw = sh.create_tween()
			tw.tween_property(sh, "global_position", mid, 0.22)
			tw.tween_callback(sh.queue_free)
			var spin = sh.create_tween().set_loops(8)
			spin.tween_property(sh, "rotation:y", TAU, 0.05).as_relative()
			var sw = weakref(sh)
			var ssrc = func():
				var s2 = sw.get_ref()
				return (s2 as Node3D).global_position if s2 != null else null
			_trail(pj, ssrc, 0.3, 0.05, Color(0.85, 0.9, 1.0, 0.7), 6)
			split.append(mid))
	pj.after(0.4, func():
		if not pj.live(c) or split.is_empty():
			return
		var ghost = mkm.call(1.7)
		for mp in split:   # bölünme anı: hayalet kopyalar halka gibi açılır
			var cp: Vector3 = mp
			_swarm(pj, ghost, _vc("ghost_star", true, 0.6, 2.0), 12, 0.2, func(i: int, u: float) -> Array:
				var a = TAU * i / 12.0
				var p = cp + Vector3(cos(a), sin(a) * 0.4, sin(a)) * u * 1.4
				return [Transform3D(Basis(Vector3.UP, u * 9.0 + a), p), Color(0.8, 0.9, 1.0, 0.8 * (1.0 - u))])
			var st = _mi(_star_mesh(), _bill("star", true))
			_scene(pj).add_child(st)
			st.global_position = cp
			st.scale = Vector3.ONE * 0.2
			var stw = st.create_tween()
			stw.tween_property(st, "scale", Vector3.ONE * 1.1, 0.07)
			stw.tween_property(st, "scale", Vector3.ONE * 0.01, 0.12)
			stw.tween_callback(st.queue_free)
		var pmesh: Mesh = mkm.call(1.7)
		for k in 70:
			var from: Vector3 = split[k % split.size()] + Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.5), randf_range(-0.8, 0.8))
			var goal = at + Vector3(randf_range(-4.0, 4.0), randf_range(0.3, 1.6), randf_range(-4.0, 4.0))
			var pr = pj.shot(c, from, (goal - from).normalized(), randf_range(30.0, 38.0), _mi(pmesh, Props.toon()), pj.inf(c, "sarutobi_shuriken_tajuu", 0.065, {"knock": 1.0, "kind": "light", "bleed": 1.0}), null, false, 1.0)
			pr.spin = Vector3(0, 28.0, 0)
		# ardıl iz: yere saplanmış shurikenler bir süre kalır, sonra gömülür
		var stuck = mkm.call(1.5)
		pj.after(0.3, func():
			_swarm(pj, stuck, Props.toon(), 22, 2.6, func(i: int, u: float) -> Array:
				var a = TAU * _r(i, 60.0)
				var rr = 4.0 * sqrt(_r(i, 61.0))
				var p: Vector3 = at + Vector3(cos(a) * rr, 0.06 - smoothstep(0.8, 1.0, u) * 0.25, sin(a) * rr)
				var b = Basis.from_euler(Vector3(0.9 + 0.4 * _r(i, 62.0), a, 0.3 * _r(i, 63.0)))
				return [Transform3D(b, p), Color(1, 1, 1)])
			for k in 6:
				_cracks(pj, at + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 0.5, 3, Color(0.1, 0.08, 0.07, 0.6), 2.5, 64.0 + k)))
	Sfx.play("throw", c.global_position, 1.0)


# ================================================================== HAGOROMO — chakra tüyleri
## Tüy düğümü (uç -Z): sahnede tek tüy
static func _feather(s := 1.0) -> Node3D:
	var n = Node3D.new()
	var f = _mi(_feather_mesh(), _vc("feather", false, 0.7, 2.4))
	n.add_child(f)
	f.basis = Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 0.75 * s)   # +Y uzunluk -> -Z
	return n


## Kanat: omurgada açılan tüy yelpazesi (n tüy). +X kanat yönü (dünyada yerleştirilir)
static func _wing(n: int, span: float) -> Node3D:
	var root = Node3D.new()
	var mat = _vc("feather", false, 0.7, 2.4)
	for k in n:
		var v = float(k) / maxf(1.0, n - 1)
		var f = _mi(_feather_mesh(), mat)
		root.add_child(f)
		var ang = lerpf(0.25, 1.45, v)   # yukarıdan yana-aşağı açılır
		f.position = Vector3(v * 0.25 * span, 0.1 - v * 0.15, 0)
		f.basis = Basis(Vector3.BACK, -ang).scaled(Vector3.ONE * span * lerpf(0.9, 0.6, v))
	return root


## Kanat çifti: c'nin sırtında, yüz yönüne göre her kare yerleştirilir
static func _wings_follow(pj: PathJutsu, c: Node3D, dur: float, n: int, span: float, flap: float) -> void:
	var holder = Node3D.new()
	_scene(pj).add_child(holder)
	var wl = _wing(n, span)
	var wr = _wing(n, span)
	holder.add_child(wl)
	holder.add_child(wr)
	wr.scale = Vector3(-1, 1, 1)
	var cw = weakref(c)
	var tw = holder.create_tween()
	tw.tween_method(func(u: float):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var fd = _flat((cc as Node3D).face_dir() if cc.has_method("face_dir") else Vector3.FORWARD)
		holder.global_transform = Transform3D(Basis.looking_at(fd, Vector3.UP), (cc as Node3D).global_position + Vector3.UP * 1.35 - fd * 0.22)
		var op = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.88, 1.0, u))
		var fl = sin(u * dur * flap) * 0.35
		wl.rotation = Vector3(0, 0.5 - op * 0.3, fl * op)
		wr.rotation = Vector3(0, -0.5 + op * 0.3, -fl * op)
		wl.scale = Vector3.ONE * maxf(0.01, op)
		wr.scale = Vector3(-1, 1, 1) * maxf(0.01, op), 0.0, 1.0, dur)
	tw.tween_callback(holder.queue_free)


## Süzülen tüy düşüşü (sürü): from noktasından aşağı yaprak gibi sallanarak
static func _feather_fall(pj: PathJutsu, from: Vector3, n: int, r: float, dur: float, s: float, seed: float) -> void:
	_swarm(pj, _feather_mesh(), _vc("feather", false, 0.7, 2.4), n, dur, func(i: int, u: float) -> Array:
		var t = u * dur
		var a = TAU * _r(i, seed)
		var p = from + Vector3(cos(a), 0, sin(a)) * r * _r(i, seed + 1.0) + Vector3(sin(t * 3.0 + i) * 0.5, -t * (1.2 + _r(i, seed + 2.0)), cos(t * 2.5 + i) * 0.3)
		var b = Basis.from_euler(Vector3(0.6 + sin(t * 4.0 + i) * 0.7, a + t, sin(t * 3.0) * 0.6)).scaled(Vector3.ONE * s)
		return [Transform3D(b, p), Color(1, 1, 1, minf(1.0, u * 8.0) * (1.0 - smoothstep(0.7, 1.0, u)))])


## Dışa patlayan tüy halkası (iniş)
static func _feather_burst(pj: PathJutsu, at: Vector3, n: int, r: float, dur: float, s: float, seed: float) -> void:
	_swarm(pj, _feather_mesh(), _vc("feather", false, 0.7, 2.4), n, dur, func(i: int, u: float) -> Array:
		var t = u * dur
		var a = TAU * i / n + _r(i, seed) * 0.3
		var dir = Vector3(cos(a), 0, sin(a))
		var e = 1.0 - exp(-t * 5.0)
		var p = at + dir * r * e + Vector3.UP * (0.3 + 1.2 * e * _r(i, seed + 1.0) - t * t * 0.8)
		var b = _yb(dir + Vector3.UP * (0.6 - u)).rotated(dir, t * 3.0).scaled(Vector3.ONE * s)
		return [Transform3D(b, p), Color(1, 1, 1, 1.0 - smoothstep(0.6, 1.0, u))])


## Hagoromo: Hane Goromo — tüyler havadan toplanıp bedene pelerin olur (4 sn), atışları yakalar; her yakalamada tüy kopar
static func hagoromo_hane_goromo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var id = "hagoromo_hane_goromo"
	pj._yama_seal(c)
	var DUR = 4.0
	var mods = {"armor": 0.6, "_name": "Hane Goromo", "_desc": "tüy pelerin: atışlar takılıp düşer, darbeler yumuşar"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)
	var g: Vector3 = c.global_position
	_swarm(pj, _feather_mesh(), _vc("feather", false, 0.7, 2.4), 30, 0.35, func(i: int, u: float) -> Array:   # tüyler toplanır
		var a = TAU * i / 30.0 + u * 3.0
		var rr = lerpf(3.5, 0.5, u * u)
		var p = g + Vector3(cos(a) * rr, 0.4 + 1.6 * _r(i, 70.0) + (1.0 - u) * 1.5, sin(a) * rr)
		var b = _yb(Vector3(-sin(a), 0.2, cos(a))).scaled(Vector3.ONE * 0.5)
		return [Transform3D(b, p), Color(1, 1, 1, minf(1.0, u * 4.0))])
	var cloak = Node3D.new()   # omuzlardan sarkan üç kat tüy (aşağı doğru, uçlar dışa)
	var mat = _vc("feather", false, 0.7, 2.4)
	var flaps = []
	for r in 3:
		for k in 11:
			var a = k * TAU / 11.0 + r * 0.29
			var f = _mi(_feather_mesh(), mat)
			cloak.add_child(f)
			f.position = Vector3(cos(a) * (0.36 + r * 0.04), 1.45 - r * 0.4, sin(a) * (0.36 + r * 0.04))
			var out = Vector3(cos(a), 0, sin(a))
			f.basis = _yb(Vector3.DOWN + out * (0.35 + r * 0.1)).scaled(Vector3.ONE * (0.55 + r * 0.08))
			flaps.append([f, f.basis, out])
	pj.attach(c, cloak, DUR, Vector3.ZERO, 1)
	var cw = weakref(c)
	Sfx.play("whoosh", c.global_position, 0.9)
	pj.every(DUR, 0.02, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if is_instance_valid(cloak):
			cloak.rotate_y(0.04)
			if i % 2 == 0:   # tüy uçları dalgalanır
				for q in flaps.size():
					var fl = flaps[q]
					if is_instance_valid(fl[0]):
						(fl[0] as Node3D).basis = (fl[1] as Basis).rotated(fl[2].cross(Vector3.UP).normalized(), sin(i * 0.25 + q) * 0.12)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if not is_instance_valid(p) or p.get("shooter") == cc:
				continue
			if p.global_position.distance_to(cc.global_position + Vector3.UP) < 2.3:   # hızlı atış bir karede bedene değmeden yakalansın
				var pp: Vector3 = p.global_position
				_feather_fall(pj, pp, 6, 0.3, 1.2, 0.4, float(i))   # kopan tüyler süzülür
				var st = _mi(_star_mesh(), _bill("star", true))
				_scene(pj).add_child(st)
				st.global_position = pp
				st.scale = Vector3.ONE * 0.35
				var stw = st.create_tween()
				stw.tween_property(st, "scale", Vector3.ONE * 0.01, 0.15)
				stw.tween_callback(st.queue_free)
				p.queue_free())
	pj.after(DUR, func():   # pelerin dağılır
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			_feather_fall(pj, (cc as Node3D).global_position + Vector3.UP * 1.4, 16, 0.6, 1.6, 0.45, 71.0))


## Hagoromo: Tobi Hane Otoshi — küçük tüy kanatlarla sıçrar, süzülür, iki ayakla dalar; inişte tüy halkası ve çatlak
static func hagoromo_tobi_hane_otoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 1.2)
	var id = "hagoromo_tobi_hane_otoshi"
	var d = pj._face(c, tt)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var p0: Vector3 = c.global_position
	var cw = weakref(c)
	pj.anim(c, "jump", 1.3)
	var body_src = func():
		var c2 = cw.get_ref()
		return ((c2 as Node3D).global_position + Vector3.UP * 0.9) if c2 != null and is_instance_valid(c2) else null
	_wings_follow(pj, c, 0.9, 6, 0.9, 22.0)
	_dust_ring(pj, pj.gp(p0), 1.6, Color(0.85, 0.85, 0.88), 12, 0.5, 80.0)
	pj.every(0.9, 1.0 / 60.0, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var top = p0.lerp(at, 0.5) + Vector3.UP * 6.0
		var p: Vector3
		if k < 0.45:
			p = p0.lerp(top, k / 0.45)
		elif k < 0.7:
			p = top + Vector3.UP * sin((k - 0.45) / 0.25 * PI) * 0.3   # süzülür
		else:
			p = top.lerp(at, pow((k - 0.7) / 0.3, 2.0))
		cc.global_position = p
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		if i % 12 == 0:
			_feather_fall(pj, p + Vector3.UP * 0.8, 2, 0.5, 1.0, 0.4, float(i))
		if i == 38:   # dalış başlar: beyaz hız izi
			_trail(pj, body_src, 0.45, 0.35, Color(0.92, 0.96, 1.0, 0.75), 10), func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		pj._kick_pose(cc, 0.3)
		_cracks(pj, at, 2.8, 7, Color(0.12, 0.09, 0.07, 0.9), 2.5, 81.0)
		_feather_burst(pj, at, 18, 3.0, 1.1, 0.5, 82.0)
		_dust_ring(pj, at, 3.0, Color(0.8, 0.8, 0.82), 16, 0.6, 83.0)
		_flash(pj, at + Vector3.UP, Color(0.85, 0.92, 1.0), 2.5, 5.0, 0.25)
		Sfx.play("boom", at, 1.0)
		pj.shake(0.4)
		for e in pj.enemies_near(cc, at, 2.6):
			e.take_hit(pj.inf(cc, id, 1.6, {"knock": 6.0, "launch": -3.0, "kind": "heavy", "stun": 0.6, "hitstop": 0.1})))


## Hagoromo: Ha Shibari — dört uzun tüy hedefin çevresine dikine saplanır; aralarında ve çapraz üstünde ışıyan tel gerilir
static func hagoromo_ha_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "hagoromo_ha_shibari"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.8)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var posts = []
	var from: Vector3 = pj.hand_pos(c)
	for k in 4:
		var a = k * TAU / 4.0 + PI * 0.25
		var p: Vector3 = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 1.3)
		var fth = _feather(3.0)
		pj.scene_add(fth, from)
		fth.look_at(p - Vector3.UP * 2.0, Vector3.RIGHT)   # dik saplı (uç aşağı)
		var ft = fth.create_tween()
		ft.tween_property(fth, "global_position", p + Vector3.UP * 1.6, 0.08)
		pj.free_after(2.2, fth)
		posts.append(p)
		_cracks(pj, p, 0.4, 3, Color(0.1, 0.08, 0.07, 0.7), 2.2, 90.0 + k)
	var lm = _glass("hane_thread", Color(0.85, 0.92, 1.0, 0.9), Color(0.6, 0.78, 1.0, 1.0), 1.0, 0.0, true, 0.5, 1.6)
	var thr = MB.new()
	for k in 4:   # çevre telleri + çapraz teller (kurbanın üstünde X)
		var a0: Vector3 = posts[k] + Vector3.UP * 0.9 - at
		var b0: Vector3 = posts[(k + 1) % 4] + Vector3.UP * 0.9 - at
		_beam_box(thr, a0, b0, 0.035)
		_beam_box(thr, a0 + Vector3.UP * 0.5, b0 - Vector3.UP * 0.3, 0.025)
	for k in 2:
		_beam_box(thr, posts[k] + Vector3.UP * 1.3 - at, posts[k + 2] + Vector3.UP * 1.3 - at, 0.03)
	var web = _mi(thr.build(null), lm)
	pj.scene_add(web, at)
	web.scale = Vector3(0.05, 1, 0.05)
	var wt = web.create_tween()
	wt.tween_interval(0.06)
	wt.tween_property(web, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	wt.tween_interval(1.6)
	wt.tween_property(web, "scale", Vector3(1, 0.02, 1), 0.2).set_ease(Tween.EASE_IN)
	wt.tween_callback(web.queue_free)
	pj.after(2.0, func(): _feather_fall(pj, at + Vector3.UP * 1.4, 14, 1.4, 1.4, 0.45, 95.0))
	Sfx.play("whoosh", at, 1.4)
	pj.after(0.1, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 1.4):
			pj.st(e, "bind", 2.0)
			e.take_hit(pj.inf(cc, id, 0.6, {"knock": 0.0, "kind": "light", "hitstop": 0.04})))


## Hagoromo: Senjō Hōkō — savaş narası: başın çevresinden dışa fırlayan manga hız çizgileri, yerden savrulan toz,
## omuzlardan kabaran tüyler
static func hagoromo_senjo_hoko(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "hagoromo_senjo_hoko"
	pj.anim(c, "power", 1.2)
	var mods = {"melee": 1.3, "_name": "Senjō Hōkō", "_desc": "savaş narası: yakın dövüş darbelerin daha sert"}
	if c is Player:
		Buffs.add(id, 8.0, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, 8.0, mods)
	var p: Vector3 = c.global_position
	var head = p + Vector3.UP * 1.55
	for q in 3:   # üç nara dalgası: dışa fırlayan kalın-ince çizgiler
		pj.after(q * 0.08, func():
			for k in 16:
				var a = TAU * k / 16.0 + q * 0.2
				var dir = Vector3(cos(a), 0.15 * sin(k * 2.3), sin(a))
				var r0 = 0.7 + q * 0.3
				_path_ribbon(pj, func(s: float) -> Vector3: return head + dir * (r0 + s * (2.5 + q * 2.0)), 0.22, 0.07, Color(1.0, 0.95, 0.85, 0.9), 0.35, false))
	_dust_ring(pj, pj.gp(p), 6.0, EARTH_C, 28, 0.8, 100.0)
	_cracks(pj, pj.gp(p), 1.4, 5, Color(0.1, 0.08, 0.07, 0.8), 2.0, 101.0)
	_feather_burst(pj, p + Vector3.UP * 1.3, 10, 1.2, 0.8, 0.4, 102.0)
	Sfx.play("roar", p, 1.2)
	pj.shake(0.3)
	for e in pj.enemies_near(c, p, 6.0):
		pj.st(e, "stun", 0.9)
		e.take_hit(pj.inf(c, id, 0.3, {"knock": 4.0, "kind": "light", "hitstop": 0.05, "dir": (e.global_position - p).normalized()}))


## Hagoromo: Ukyū Rakuha — büyük tüy kanatlarla göğe yükselip asılı kalır (altında dönen tüy halkası), göktaşı gibi iner
static func hagoromo_ukyu_rakuha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 1.6)
	var id = "hagoromo_ukyu_rakuha"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var p0: Vector3 = c.global_position
	pj.anim(c, "jump", 1.2)
	var hold = {"at": pj.gp(tt.global_position if tt else c.global_position + d * 6.0)}
	var body_src = func():
		var c2 = cw.get_ref()
		return ((c2 as Node3D).global_position + Vector3.UP * 0.9) if c2 != null and is_instance_valid(c2) else null
	_wings_follow(pj, c, 1.05, 9, 1.6, 9.0)
	_dust_ring(pj, pj.gp(p0), 2.4, Color(0.85, 0.85, 0.88), 16, 0.6, 110.0)
	var ring_n = 14
	_swarm(pj, _feather_mesh(), _vc("feather", false, 0.7, 2.4), ring_n, 1.05, func(i: int, u: float) -> Array:   # altında dönen tüy halkası
		var cc = cw.get_ref()
		var cp: Vector3 = (cc as Node3D).global_position if cc != null and is_instance_valid(cc) else p0
		var a = TAU * i / ring_n + u * 9.0
		var op = smoothstep(0.1, 0.3, u) * (1.0 - smoothstep(0.65, 0.72, u))
		var p = cp + Vector3(cos(a) * 1.3, -0.1 + sin(a * 2.0 + u * 8.0) * 0.1, sin(a) * 1.3)
		var b = _yb(Vector3(-sin(a), -0.2, cos(a))).scaled(Vector3.ONE * 0.6 * maxf(0.01, op))
		return [Transform3D(b, p), Color(1, 1, 1, op)])
	pj.every(1.4, 1.0 / 60.0, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		if x != null and is_instance_valid(x) and k < 0.75:
			hold["at"] = pj.gp(x.global_position)
		var at: Vector3 = hold["at"]
		var hover: Vector3 = p0 + Vector3.UP * 7.0
		var p: Vector3
		if k < 0.3:
			p = p0.lerp(hover, k / 0.3)
		elif k < 0.75:
			p = hover + Vector3.UP * sin(k * 20.0) * 0.15   # havada asılı
		else:
			p = hover.lerp(at, pow((k - 0.75) / 0.25, 2.0))
		cc.global_position = p
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		if i % 10 == 0 and k < 0.75:
			_feather_fall(pj, p + Vector3.UP * 0.5, 2, 0.6, 1.4, 0.45, float(i) + 111.0)
		if i == 63:   # göktaşı inişi: kalın beyaz-mavi iz
			_trail(pj, body_src, 0.5, 0.6, Color(0.85, 0.92, 1.0, 0.85), 12), func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var at: Vector3 = hold["at"]
		pj._kick_pose(cc, 0.3)
		var crater = []   # göktaşı çukuru: koyu halka
		for k in 21:
			var a = TAU * k / 20.0
			crater.append(at + Vector3(cos(a), 0, sin(a)) * 2.2)
		_scar(pj, crater, 0.35, Color(0.1, 0.08, 0.06, 0.85), 4.0)
		_cracks(pj, at, 4.0, 9, Color(0.12, 0.09, 0.07, 0.9), 4.0, 112.0)
		_chunks(pj, at, 18, 10.0, EARTH_C, 0.32, 1.3, 113.0)
		_feather_burst(pj, at, 30, 5.0, 1.4, 0.6, 114.0)
		_dust_ring(pj, at, 7.0, Color(0.82, 0.8, 0.78), 26, 0.9, 115.0)
		_flash(pj, at + Vector3.UP, Color(0.85, 0.92, 1.0), 4.0, 8.0, 0.35)
		Sfx.play("boom", at, 0.7)
		pj.shake(0.6)
		for e in pj.enemies_near(cc, at, 3.5):
			var v: Vector3 = e.global_position - at
			v.y = 0
			e.take_hit(pj.inf(cc, id, 1.8 if v.length() < 1.6 else 0.9, {"knock": 10.0, "launch": 4.0, "kind": "heavy", "stun": 0.5, "hitstop": 0.12, "dir": v.normalized() if v.length() > 0.1 else d})))


# ================================================================== İNUZUKA
## Gatsūga matkabı (ref: küt burunlu gri dönen gövde, sık koyu spiral taramalar, burun kenarında krem tırtıklı chakra
## halkası, arkada gri-kahve kürk tozu). -Z ileri. meta "drill_mat" (form 0..1)
static func _drill(size: float) -> Node3D:
	var root = Node3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof = [[1.6, 0.05], [1.35, 0.32], [0.95, 0.64], [0.4, 0.9], [-0.15, 1.0], [-0.65, 0.95], [-0.98, 0.78], [-1.18, 0.48], [-1.28, 0.18], [-1.3, 0.0]]
	var SEG = 22
	var L = 0.0
	var acc = [0.0]
	for i in range(1, prof.size()):
		L += Vector2(prof[i][0] - prof[i - 1][0], prof[i][1] - prof[i - 1][1]).length()
		acc.append(L)
	for i in prof.size() - 1:
		for k in SEG:
			var q = []
			for dd in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var ii = i + dd[0]
				var kk = k + dd[1]
				var z: float = prof[ii][0]
				var ang = TAU * kk / SEG + z * 0.5   # hafif burgu
				var r: float = prof[ii][1]
				q.append([Vector3(cos(ang) * r, sin(ang) * r, z), Vector3(cos(ang), sin(ang), 0.0), Vector2(float(kk) / SEG, acc[ii] / L)])
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a = q[tri[0]]
				var b = q[tri[1]]
				var cc = q[tri[2]]
				var nsum: Vector3 = a[1] + b[1] + cc[1]
				var order = [a, b, cc]
				if ((b[0] as Vector3) - (a[0] as Vector3)).cross((cc[0] as Vector3) - (a[0] as Vector3)).dot(nsum) > 0.0:
					order = [a, cc, b]
				for v in order:
					st.set_normal(v[1])
					st.set_uv(v[2])
					st.add_vertex(v[0])
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	var m = ShaderMaterial.new()
	m.shader = _shader("drill", DRILL_CODE)
	m.set_shader_parameter("form", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	root.set_meta("drill_mat", m)
	# burun kenarında titreyen krem tırtıklı halka
	var ring = MeshInstance3D.new()
	ring.position = Vector3(0, 0, -1.0)
	ring.material_override = _vc("drill_ring", false, 0.9, 2.6)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var rebuild = func():
		var rs = SurfaceTool.new()
		rs.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n = 12
		for k in n:
			var am = TAU * (k + randf_range(-0.3, 0.3)) / n
			var w = TAU / n * randf_range(0.3, 0.48)
			var ro = randf_range(1.3, 1.75)
			var p0 = Vector3(cos(am - w), sin(am - w), 0) * 0.98
			var p1 = Vector3(cos(am + w), sin(am + w), 0) * 0.98
			var tip = Vector3(cos(am) * ro, sin(am) * ro, randf_range(0.4, 0.85))
			for v in [p0, p1, tip]:
				rs.set_color(CREAM)
				rs.add_vertex(v)
		for k in 20:   # ince krem bant
			var a0 = TAU * k / 20.0
			var a1 = TAU * (k + 1) / 20.0
			var q2 = [Vector3(cos(a0), sin(a0), 0) * 0.9, Vector3(cos(a1), sin(a1), 0) * 0.9, Vector3(cos(a1), sin(a1), 0) * 1.08 + Vector3(0, 0, 0.25), Vector3(cos(a0), sin(a0), 0) * 1.08 + Vector3(0, 0, 0.25)]
			for tt in [0, 1, 2, 0, 2, 3]:
				rs.set_color(CREAM.darkened(0.08))
				rs.add_vertex(q2[tt])
		ring.mesh = rs.commit()
	rebuild.call()
	var tw = ring.create_tween().set_loops()
	tw.tween_callback(rebuild)
	tw.tween_interval(0.06)
	root.scale = Vector3.ONE * size * 1.1
	return root


## Matkap koşusu (j_gatsuga / gatsuga_run'dan aynen): beden döner, matkap oluşur, hedefin içinden 3 kez çapraz geçer
static func _gatsuga_run(pj: PathJutsu, node: Node3D, p: Vector3, side: float, size: float, jid: String, mul: float, owner_c: Node3D = null) -> void:
	var c: Node3D = owner_c if owner_c else node
	var drill = _drill(size)
	drill.top_level = true
	node.add_child(drill)
	var vis: Node3D = node.get("model") if node.get("model") else node.get("vis")
	var dm: ShaderMaterial = drill.get_meta("drill_mat")
	dm.set_shader_parameter("form", 0.0)
	var start: Vector3 = node.global_position
	drill.global_position = start + Vector3.UP * 1.0 * size
	drill.look_at(drill.global_position + Vector3(p.x - start.x, 0, p.z - start.z).normalized() if Vector2(p.x - start.x, p.z - start.z).length() > 0.1 else drill.global_position + Vector3.FORWARD, Vector3.UP)
	# kanon: beden yerinde fırıl fırıl döner, etrafında matkap oluşur; matkap tamamlanınca beden onun içinde kaybolur
	var form = 0.22
	var tw0 = node.create_tween()
	tw0.tween_method(func(u: float):
		if is_instance_valid(drill):
			dm.set_shader_parameter("form", u)
		if is_instance_valid(vis):
			vis.rotation.y += 0.9, 0.0, 1.0, form)
	tw0.tween_callback(func():
		if is_instance_valid(vis):
			vis.visible = false)
	# oluşum anı: bedenin çevresinde yükselen kürk tozu sarmalı
	_swarm(pj, _tuft_mesh(), _vc("fur", false, 0.9, 2.6), 26, form + 0.15, func(i: int, u: float) -> Array:
		var a = TAU * i / 26.0 + u * 14.0
		var pp = start + Vector3(cos(a) * (1.1 - u * 0.5) * size, (0.2 + u * 1.6 * _r(i, 120.0)) * size, sin(a) * (1.1 - u * 0.5) * size)
		var b = _yb(Vector3(-sin(a), 0.5, cos(a))).scaled(Vector3.ONE * 0.35 * size)
		return [Transform3D(b, pp), Color(FUR.r, FUR.g, FUR.b, 1.0 - smoothstep(0.7, 1.0, u))])
	var d0: Vector3 = (p - start)
	d0.y = 0
	d0 = d0.normalized() if d0.length() > 0.1 else Vector3.FORWARD
	# yol: başlangıç -> hedefin 5 m ötesi -> çapraz geri dönüş -> yeniden geçiş
	var pts = [start, p + d0 * 5.0, p + d0.rotated(Vector3.UP, side * 2.5) * 5.0, p + d0.rotated(Vector3.UP, -side * 0.6) * 5.5]
	var lens = []
	var total = 0.0
	for i in pts.size() - 1:
		var Ln = (pts[i + 1] as Vector3).distance_to(pts[i])
		lens.append(Ln)
		total += Ln
	var hitd = {}
	var dur = 0.95
	var dust = _blob_mat("gatsuga_dust", Color(0.7, 0.66, 0.66, 0.7), Color(0.46, 0.4, 0.44, 0.6), 1.5, 4.5)
	var last = {"q": start, "n": 0}
	var dw = weakref(drill)
	var dsrc = func():
		var dr = dw.get_ref()
		return (dr as Node3D).global_position if dr != null and is_instance_valid(dr) and (dr as Node3D).is_inside_tree() else null
	_trail(pj, dsrc, form + dur + 0.3, 0.75 * size, Color(0.62, 0.58, 0.6, 0.55), 10, false)   # gidiş yönünde kürk izi
	var tw = node.create_tween()
	tw.tween_interval(form)
	tw.tween_method(func(u: float):
		if not is_instance_valid(node) or not is_instance_valid(drill):
			return
		var dist = u * total
		var i = 0
		while i < lens.size() - 1 and dist > lens[i]:
			dist -= lens[i]
			i += 1
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var q = a.lerp(b, clampf(dist / maxf(0.01, lens[i]), 0.0, 1.0))
		q.y = pj.gp(q).y
		node.global_position = q
		var dv = (b - a)
		dv.y = 0
		drill.global_position = q + Vector3.UP * 1.0 * size
		if dv.length() > 0.01:
			drill.look_at(drill.global_position + dv.normalized(), Vector3.UP)   # matkabın sivri ucu gidiş yönünde
		last["n"] += 1
		if q.distance_to(last["q"]) > 0.9 * size:   # yerde oyuk + arkada kürk tozu
			_scar(pj, [last["q"], q], 0.35 * size, Color(0.14, 0.1, 0.08, 0.75), 3.0)
			if int(last["n"]) % 2 == 0:
				_puff(pj, dust, q + Vector3.UP * 0.8 * size - dv.normalized() * 1.2 * size, 0.6 * size, 1.6 * size, 0.45, Vector3.UP * 0.5, float(last["n"]), 0.9)
			last["q"] = q
		for f in pj.get_tree().get_nodes_in_group("fighters"):
			if Combat.hostile(c, f) and not f.is_dead() and f.global_position.distance_to(q) < 1.6 * size + f.radius:
				var key = "%d_%d" % [f.get_instance_id(), i]   # her geçişte bir kez çarpar
				if not hitd.has(key):
					hitd[key] = true
					f.take_hit(pj.inf(c, jid, 0.55 * mul, {"knock": 8.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.04, "dir": dv.normalized() if dv.length() > 0.01 else Vector3.FORWARD, "attacker": c}))
					_scatter(pj, _tuft_mesh(), f.global_position + Vector3.UP, 8, 0.3, 5.0, 0.6, 0.3, float(i) + 121.0), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(drill):
			drill.queue_free()
		if is_instance_valid(vis):
			vis.visible = true
		if node is Player:
			node.combat.action = "")
	if node is Player:
		node.combat.action = "cast"
		node.combat.t = -10.0


## Gatsūga: Inuzuka ve ninkeni iki dönen gri matkaba dönüşüp hedefin içinden çaprazlama geçer
static func gatsuga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	var aim = Jutsu._aim_flat(c, t)
	var p: Vector3 = tt.global_position if tt else c.global_position + aim * 12.0
	_dust_ring(pj, pj.gp(c.global_position), 2.2, Color(0.6, 0.56, 0.54), 14, 0.5, 125.0)
	_gatsuga_run(pj, c, p, 1.0, 1.35, "gatsuga", 1.0)
	for n in pj.get_tree().get_nodes_in_group("ninken"):
		if n.get("owner_f") == c and not n.dead:
			_gatsuga_run(pj, n, p, -1.0, 1.2, "gatsuga", 0.6, c)
	Sfx.play("wind", c.global_position, 1.6)


## Pençeler: parmak uç kemiklerine bağlı kıvrık, ucu koyulaşan pençe (her kare kemiği izler)
static func _claws(pj: PathJutsu, c: Node3D, dur: float, length := 0.07) -> void:
	var m = c.get("model")
	if m == null or not is_instance_valid(m) or m.get("skel") == null:
		return
	var sk: Skeleton3D = m.skel
	var mesh = _tube([Vector3(0, 0, 0), Vector3(0, -0.008, -length * 0.5), Vector3(0, -0.024, -length)], [0.012, 0.008, 0.001], Color(0.95, 0.92, 0.84), Color(0.4, 0.34, 0.3), 6)
	var pairs = []
	for sd in ["Left", "Right"]:
		for f in ["Index", "Middle", "Ring", "Little", "Thumb"]:
			var a = sk.find_bone(sd + f + ("Proximal" if f == "Thumb" else "Intermediate"))
			var b = sk.find_bone(sd + f + "Distal")
			if a < 0 or b < 0:
				continue
			var mi = _mi(mesh, Props.toon(), _ink(0.003))
			mi.top_level = true
			c.add_child(mi)
			pairs.append([mi, a, b])
	if pairs.is_empty():
		return
	var tw = c.create_tween()
	tw.tween_method(func(_u: float):
		if not is_instance_valid(sk):
			return
		for pr in pairs:
			var mi: MeshInstance3D = pr[0]
			if not is_instance_valid(mi):
				continue
			mi.visible = m.visible
			var pa: Vector3 = (sk.global_transform * sk.get_bone_global_pose(pr[1])).origin
			var pd: Vector3 = (sk.global_transform * sk.get_bone_global_pose(pr[2])).origin
			var dv = pd - pa
			if dv.length() < 0.0001:
				continue
			var tip = pd + dv.normalized() * dv.length() * 0.9
			var up = Vector3.UP if absf(dv.normalized().y) < 0.95 else Vector3.FORWARD
			mi.global_transform = Transform3D(Basis.looking_at(dv.normalized(), up), tip), 0.0, 1.0, dur)
	tw.tween_callback(func():
		for pr in pairs:
			if is_instance_valid(pr[0]):
				pr[0].queue_free())


## Vahşi chakra dilleri: kemiğe bağlı, titreşen küçük kızıl-turuncu alev dilleri
static func _feral_tongues(pj: PathJutsu, c: Node3D, bones: Array, dur: float, s := 1.0) -> void:
	var gm = _glass("feral", Color(1.0, 0.55, 0.35, 0.35), Color(0.95, 0.2, 0.15, 0.9), 1.4, 0.4, false, 0.8, 2.5)
	var tm = _tube([Vector3.ZERO, Vector3(0.02, 0.1, 0), Vector3(-0.02, 0.2, 0), Vector3(0.0, 0.3, 0)], [0.05, 0.045, 0.025, 0.002], Color.WHITE, Color.WHITE, 6)
	for bn in bones:
		var ba = pj.bone_attach(c, bn)
		if ba == null:
			continue
		for k in 3:
			var hold = Node3D.new()
			ba.add_child(hold)
			hold.top_level = false
			var f = _mi(tm, gm)
			hold.add_child(f)
			f.rotation = Vector3((k - 1) * 0.5, k * 2.1, (k - 1) * 0.3)
			hold.scale = Vector3.ONE * s
			var ft = f.create_tween().set_loops(int(dur / 0.16) + 1)
			ft.tween_property(f, "scale", Vector3(1.2, 1.3 + 0.2 * k, 1.2), 0.08)
			ft.tween_property(f, "scale", Vector3(0.8, 0.7, 0.8), 0.08)
		pj.free_after(dur, ba)


## Canavar-İnsan Klonu: ninken kürk tozu sarmalı içinde sahibine dönüşür (gerçek klon), 20 sn yanında senin gibi dövüşür
static func jujin_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_feral_tongues(pj, c, ["LeftHand", "RightHand"], 1.5, 0.8)
	var at = c.global_position + c.global_transform.basis.x * 2.0
	for n in pj.get_tree().get_nodes_in_group("ninken"):
		at = n.global_position
		n.visible = false
		pj.after(20.0, func():
			if is_instance_valid(n):
				n.visible = true)
	# dönüşüm: beyaz-kahve kürk tutamları sarmal yükselir, sonra dışa kabarıp dağılır
	var g: Vector3 = pj.gp(at)
	_swarm(pj, _tuft_mesh(), _vc("fur", false, 0.9, 2.6), 46, 0.75, func(i: int, u: float) -> Array:
		var a = TAU * i / 46.0 * 3.0 + u * 10.0
		var burst = smoothstep(0.6, 1.0, u)
		var rr = lerpf(0.9, 0.45, smoothstep(0.0, 0.6, u)) + burst * 1.6
		var p = g + Vector3(cos(a) * rr, (float(i) / 46.0) * 2.0 * minf(1.0, u * 2.0) + burst * 0.6, sin(a) * rr)
		var b = _yb(Vector3(cos(a), 0.6, sin(a))).scaled(Vector3.ONE * 0.4)
		var col = Color(0.97, 0.96, 0.93) if i % 3 != 0 else Color(0.62, 0.5, 0.4)
		return [Transform3D(b, p), Color(col.r, col.g, col.b, 1.0 - smoothstep(0.75, 1.0, u))])
	_dust_ring(pj, g, 1.6, Color(0.7, 0.66, 0.62), 12, 0.5, 130.0)
	var cl = ShadowClone.new()
	cl.team = c.team
	cl.look = c.model.look.duplicate()
	cl.life = 20.0
	_scene(pj).add_child(cl)
	cl.global_position = pj.gp(at)
	var clw = weakref(cl)
	pj.after(0.15, func():   # klon vahşi: pençeler ve el / sırttaki kızıl chakra dilleri
		var k2 = clw.get_ref()
		if k2 == null or not is_instance_valid(k2):
			return
		_claws(pj, k2, 19.8, 0.08)
		_feral_tongues(pj, k2, ["LeftHand", "RightHand", "Chest"], 19.8, 0.9))
	Hud.msg("Jūjin Bunshin: ninken sana dönüştü", Color(0.95, 0.75, 0.6))


## Dört Ayak: yere çöküş (pençe sıyrıkları + toz), parmak uçlarında uzayan pençeler, ağızda dişler, el / ayakta vahşi chakra
static func shikyaku_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var g: Vector3 = pj.gp(c.global_position)
	var fd = _flat(c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD)
	var sd = fd.cross(Vector3.UP)
	for k in 4:   # dört paralel pençe sıyrığı
		var o = sd * (k - 1.5) * 0.18
		_scar(pj, [g + fd * 0.6 + o, g + fd * 1.1 + o + sd * 0.05, g + fd * 1.6 + o + sd * 0.15], 0.05, Color(0.1, 0.07, 0.06, 0.85), 4.0)
	_dust_ring(pj, g, 2.6, Color(0.62, 0.55, 0.48), 18, 0.6, 140.0)
	if c is Player:
		Buffs.add("shikyaku", 20.0, {"speed": 1.18, "melee": 1.18})
	_claws(pj, c, 20.0, 0.075)
	var hb = pj.bone_attach(c, "Head")   # kanon: sivri köpek dişleri
	if hb:
		var fb = MB.new()
		for sx in [-1.0, 1.0]:
			fb.add("cone", Vector3(sx * 0.024, 0.035, 0.1), Vector3(0.012, 0.03, 0.012), Color(0.98, 0.97, 0.92), Vector3(180, 0, 0), 5)
		hb.add_child(_mi(fb.build(null), Props.toon()))
		pj.free_after(20.0, hb)
	_feral_tongues(pj, c, ["LeftHand", "RightHand", "LeftFoot", "RightFoot"], 20.0, 0.75)
	Sfx.play("roar", c.global_position, 1.6, 0.6)


## Koku izi: hedefin üstünde dalgalı sarı-yeşil çizgi (komik)
static func _stink_line(pj: PathJutsu, parent: Node3D, p: Vector3, life: float, seed: float, rise: float) -> void:
	var pts = []
	var rad = []
	for i in 7:
		var v = i / 6.0
		pts.append(Vector3(sin(v * TAU * 1.2 + seed) * 0.08, v * 0.45, 0))
		rad.append(0.018)
	var mi = _mi(_tube(pts, rad, Color(0.95, 0.88, 0.3), Color(0.85, 0.9, 0.35), 5), _vc("stink", false, 0.6, 2.0))
	if parent:
		parent.add_child(mi)
		mi.position = p
	else:
		_scene(pj).add_child(mi)
		mi.global_position = p
	if rise <= 0.0:
		var bt = mi.create_tween().set_loops()
		bt.tween_property(mi, "position:y", p.y + 0.12, 0.5).set_trans(Tween.TRANS_SINE)
		bt.tween_property(mi, "position:y", p.y, 0.5).set_trans(Tween.TRANS_SINE)
		return
	var tw = mi.create_tween()
	tw.tween_property(mi, "global_position", p + Vector3.UP * rise, life)
	tw.parallel().tween_property(mi, "scale", Vector3(1.4, 1.2, 1.4), life)
	tw.tween_callback(mi.queue_free)


## Dainamikku Mākingu: ninken hedefe işer — küçük sarı yay, çarpışta sarı damlacıklar, hedefin üstünde koku çizgileri (60 sn iz)
static func dainamikku_makingu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	var tt0 = tt
	if tt != null:
		var b = MB.new()   # damla zinciri
		for k in 3:
			b.add("sphere", Vector3(0, 0, k * 0.12), Vector3.ONE * (0.16 - k * 0.035), Color(1.0, 0.9, 0.3), Vector3.ZERO, 8)
		var drop = _mi(b.build(null), _vc("pee", false, 0.6, 2.0))
		var from: Vector3 = Jutsu._hand(c)
		var pr = pj.shot(c, from, (tt.global_position + Vector3.UP - from).normalized(), 30.0, drop, {"dmg": 1.0, "knock": 0.0}, tt, false, 1.5, func(_p, target):
			if pj.live(target):
				target.set_meta("inu_scent", Time.get_ticks_msec() / 1000.0 + 60.0)   # kanon: koku izi — Garōga onu dönerken bile bulur
				var tp: Vector3 = target.global_position
				_swarm(pj, _sph(), _vc("pee", false, 0.6, 2.0), 12, 0.5, func(i: int, u: float) -> Array:   # sarı sıçrama
					var a = TAU * i / 12.0
					var tt2 = u * 0.5
					var pp = tp + Vector3.UP * 1.2 + Vector3(cos(a) * 2.0, 3.0 - 9.8 * tt2, sin(a) * 2.0) * tt2
					return [Transform3D(Basis().scaled(Vector3.ONE * 0.07), pp), Color(1, 0.9, 0.3, 1.0 - u)])
				_scar(pj, [tp + Vector3(-0.35, 0, 0.1), tp + Vector3(0.0, 0, -0.1), tp + Vector3(0.35, 0, 0.05)], 0.22, Color(0.95, 0.85, 0.3, 0.55), 3.0)
				var tag = Node3D.new()   # hedefin başı üstünde dalgalanan koku çizgileri
				pj.attach(target, tag, 20.0, Vector3.UP * (target.height + 0.7))
				for k in 3:
					_stink_line(pj, tag, Vector3((k - 1) * 0.16, 0, 0), 0.0, float(k) * 2.0, 0.0)
				Combat.popup_text(target.global_position + Vector3.UP * 2.4, "İşaretlendi!", Color(1, 0.85, 0.3)))
		_proj_trail(pj, pr, 0.6, 0.05, Color(1.0, 0.88, 0.3, 0.85), 10)   # ince sarı yay
		for n in pj.get_tree().get_nodes_in_group("ninken"):
			n.tgt = tt
	if tt0:
		pj.after(0.5, func():
			if pj.live(tt0):
				pj.every(20.0, 0.5, func(_i, _k):
					if pj.live(tt0):
						_stink_line(pj, null, tt0.global_position + Vector3(randf_range(-0.4, 0.4), 0.4 + randf_range(0.0, 0.8), randf_range(-0.4, 0.4)), 1.0, randf() * 6.0, 0.8), Callable()))
