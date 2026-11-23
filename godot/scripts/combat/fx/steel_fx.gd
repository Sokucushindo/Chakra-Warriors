class_name SteelFX
extends RefCounted
## Kōton (çelik) görselleri ve on Kōton tekniğinin tamamı.
## Ortak efekt yardımcısı yok: kendi çelik shader'ı (koyu gri-mavi tabanca çeliği, tek parlak çizgi, soğuk mavi kenar ışığı,
## dövülürken kızgın turuncu parlayıp soğuma, ilerleyen "çeliğe dönüşme" cephesi), kendi kıvılcım / kızgın parıltı / çelik kıymığı /
## sürtünme izi / bıçak / zincir / çekiç / kafes geometrisi. Taş ya da çamur gibi görünmez: keskin, sert, parlak, ağır.

static var _cache := {}

const G := 20.0

# ------------------------------------------------------------------ malzemeler
const STEEL_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque, ambient_light_disabled;

instance uniform float heat = 0.0;
instance uniform float front = 1000.0;
instance uniform float fmode = 0.0;
instance uniform float seed = 0.0;
instance uniform float polish = 0.0;

varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// çeliğe dönüşme cephesi: 0 = merkezden halka, 1 = +Z boyunca, 2 = yukarı doğru
	float coord = fmode < 0.5 ? length(lp.xz) : (fmode < 1.5 ? lp.z : lp.y);
	float nz = (vnoise(lp.xz * 2.5 + vec2(lp.y * 1.7 + seed)) - 0.5) * 0.35;
	float fd = front - coord + nz;
	if (fd < 0.0) {
		discard;
	}
	float fr = 1.0 - smoothstep(0.0, 0.16, fd);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 base = lin(mix(vec3(0.27, 0.29, 0.33), vec3(0.45, 0.48, 0.53), polish));
	vec3 mid = lin(mix(vec3(0.17, 0.18, 0.22), vec3(0.3, 0.32, 0.37), polish));
	vec3 dark = lin(vec3(0.08, 0.085, 0.11));
	float key = dot(NORMAL, normalize(vec3(-0.4, 0.8, 0.45)));
	vec3 col = key > 0.3 ? base : (key > -0.25 ? mid : dark);
	// animedeki tek parlak çizgi
	float sv = NORMAL.x * 0.5 + NORMAL.y * 0.866;
	float stripe = step(0.5, sv) * step(sv, 0.64);
	col = mix(col, lin(vec3(0.94, 0.96, 1.0)), stripe * 0.92);
	col = mix(col, lin(vec3(0.5, 0.6, 0.75)), step(0.75, fres) * 0.55);
	col *= COLOR.rgb;
	// kızgınlık: dövülürken / vurulunca turuncu-sarı, soğudukça koyu kırmızı, sonra çelik
	float hm = heat * (0.65 + 0.35 * vnoise(lp.xy * 4.0 + vec2(seed * 2.0)));
	vec3 hot = mix(lin(vec3(0.75, 0.12, 0.02)), lin(vec3(1.0, 0.55, 0.12)), smoothstep(0.2, 0.7, hm));
	hot = mix(hot, lin(vec3(1.0, 0.92, 0.7)), smoothstep(0.75, 1.0, hm));
	col = mix(col, col * 0.4, smoothstep(0.05, 0.4, hm));
	ALBEDO = col * 0.45;
	EMISSION = col * 0.7 + hot * smoothstep(0.02, 0.3, hm) * (0.8 + 2.2 * hm) + lin(vec3(1.0, 0.5, 0.12)) * fr * 3.0;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += (ndl > 0.2 ? 1.0 : 0.45) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 hv = normalize(VIEW + LIGHT);
	float s = pow(max(dot(NORMAL, hv), 0.0), 90.0);
	SPECULAR_LIGHT += step(0.45, s) * ATTENUATION * LIGHT_COLOR / PI * 1.5;
}
"""

## Model yüzeyine giydirilen çelik deri (Kōtai): ayaklardan yukarı ilerleyen, ucu kızgın turuncu parlayan cephe
const SKIN_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque, ambient_light_disabled;

uniform float front = -2.0;
uniform float heat = 0.0;
varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	float s = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	lp = VERTEX * s;
	VERTEX += NORMAL * 0.008 / s;
}

void fragment() {
	float nz = (vnoise(lp.xz * 9.0 + vec2(lp.y * 3.0)) - 0.5) * 0.18;
	float fd = front - lp.y + nz;
	if (fd < 0.0) {
		discard;
	}
	float fr = 1.0 - smoothstep(0.0, 0.07, fd);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float key = dot(NORMAL, normalize(vec3(-0.4, 0.8, 0.45)));
	vec3 col = key > 0.3 ? lin(vec3(0.26, 0.28, 0.32)) : (key > -0.25 ? lin(vec3(0.16, 0.17, 0.21)) : lin(vec3(0.07, 0.075, 0.1)));
	float sv = NORMAL.x * 0.5 + NORMAL.y * 0.866;
	col = mix(col, lin(vec3(0.94, 0.96, 1.0)), step(0.52, sv) * step(sv, 0.64) * 0.9);
	col = mix(col, lin(vec3(0.5, 0.6, 0.75)), step(0.75, fres) * 0.5);
	float hm = heat * (0.6 + 0.4 * vnoise(lp.xy * 7.0));
	ALBEDO = col * 0.45;
	EMISSION = col * 0.7 + lin(vec3(1.0, 0.5, 0.12)) * (fr * 3.5 + hm * 1.5);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += (ndl > 0.2 ? 1.0 : 0.45) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 hv = normalize(VIEW + LIGHT);
	float s = pow(max(dot(NORMAL, hv), 0.0), 90.0);
	SPECULAR_LIGHT += step(0.45, s) * ATTENUATION * LIGHT_COLOR / PI * 1.5;
}
"""

## Kıvılcım / kızgın parıltı / kesik izi: ışık saçan (eklemeli), turuncu ya da mavi
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float heat = 1.0;
instance uniform float blue = 0.0;
instance uniform float fade = 1.0;

void fragment() {
	vec3 hot = mix(vec3(0.6, 0.06, 0.0), vec3(1.0, 0.42, 0.04), smoothstep(0.0, 0.5, heat));
	hot = mix(hot, vec3(1.0, 0.93, 0.7), smoothstep(0.55, 1.0, heat));
	vec3 bl = mix(vec3(0.1, 0.3, 1.0), vec3(0.8, 0.92, 1.0), heat);
	ALBEDO = mix(hot, bl, blue) * COLOR.rgb * fade * (0.5 + 1.5 * heat);
}
"""

## Yer izi: sürtünme / yanık / çökme gölgesi (koyu, yarı saydam)
const MARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;

void fragment() {
	ALBEDO = vec3(0.03, 0.03, 0.04) * COLOR.rgb;
	ALPHA = 0.8 * fade * COLOR.a;
}
"""


static func _sm(key: String, code: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = code
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func steel_mat() -> ShaderMaterial:
	return _sm("steel", STEEL_SHADER)


static func glow_mat() -> ShaderMaterial:
	return _sm("glow", GLOW_SHADER)


static func mark_mat() -> ShaderMaterial:
	return _sm("mark", MARK_SHADER)


## Kişiye özel çelik deri malzemesi (cephe her kullanıcıda ayrı ilerler)
static func skin_mat() -> ShaderMaterial:
	var base = _sm("skin_base", SKIN_SHADER)
	var m = ShaderMaterial.new()
	m.shader = base.shader
	return m


static func _mi(mesh: Mesh, heat := 0.0, polish := 0.0, shadow := true) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = steel_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("polish", polish)
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	return mi


static func _gl(mesh: Mesh, heat := 1.0, blue := 0.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("heat", heat)
	mi.set_instance_shader_parameter("blue", blue)
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


static func _mk(mesh: Mesh) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mark_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("fade", 1.0)
	return mi


static func _setter(mi: GeometryInstance3D, pname: String) -> Callable:
	return func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(pname, v)


## Örnek parametresini zamanla değiştir (kızgınlık soğuması, cephe ilerlemesi, sönme)
static func ramp(mi: GeometryInstance3D, pname: String, a: float, b: float, t: float, delay := 0.0) -> void:
	if not is_instance_valid(mi):
		return
	if delay <= 0.0:
		mi.set_instance_shader_parameter(pname, a)
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_setter(mi, pname), a, b, t)


static func ramp_all(n: Node, pname: String, a: float, b: float, t: float, delay := 0.0) -> void:
	if not is_instance_valid(n):
		return
	if n is MeshInstance3D:
		ramp(n, pname, a, b, t, delay)
	for ch in n.find_children("*", "MeshInstance3D", true, false):
		ramp(ch, pname, a, b, t, delay)


static func _face_basis(d: Vector3) -> Basis:   # yerel +Z = d
	var f = Vector3(d.x, 0, d.z)
	if f.length() < 0.01:
		f = Vector3.FORWARD
	return Basis.looking_at(-f.normalized(), Vector3.UP)


# ------------------------------------------------------------------ geometri
## Dışa bakan üçgen (Godot önyüz sırası); yassı gölgeli keskin yüzeyler için köşeler paylaşılmaz
static func _tri(sf: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, col := Color.WHITE) -> void:
	var n = (c - a).cross(b - a)
	if n.dot((a + b + c) / 3.0 - center) < 0.0:
		var t = b
		b = c
		c = t
	for v in [a, b, c]:
		sf.set_color(col)
		sf.set_uv(Vector2.ZERO)
		sf.add_vertex(v)


static func _commit(sf: SurfaceTool) -> ArrayMesh:
	sf.generate_normals()
	return sf.commit()


## Çelik kıymığı: iki ucu sivri, kesik yüzlü ince parça (uzun eksen Z)
static func shard_mesh(v: int) -> ArrayMesh:
	var key = "shard_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 911 * (v + 1)
	var L = rng.randf_range(0.8, 1.3)
	var t1 = Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1), L * 0.5)
	var t2 = Vector3(rng.randf_range(-0.1, 0.1), 0, -L * rng.randf_range(0.25, 0.4))
	var ring = []
	for k in 3:
		var a = k * TAU / 3.0 + rng.randf_range(-0.4, 0.4)
		ring.append(Vector3(cos(a) * rng.randf_range(0.12, 0.22), sin(a) * rng.randf_range(0.05, 0.12), rng.randf_range(-0.05, 0.05)))
	var cen = (t1 + t2 + ring[0] + ring[1] + ring[2]) / 5.0
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		_tri(sf, t1, ring[k], ring[(k + 1) % 3], cen)
		_tri(sf, t2, ring[k], ring[(k + 1) % 3], cen)
	var m = _commit(sf)
	_cache[key] = m
	return m


## Yerden fışkıran çelik mızrak: dört yüzlü, ortada burulmuş kesik yüzlerle keskin (yükseklik 1, taban yarıçapı 0.5)
static func spike_mesh(v: int) -> ArrayMesh:
	var key = "spike_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 577 * (v + 1)
	var base = []
	var midr = []
	var tw = rng.randf_range(0.2, 0.5)
	for k in 4:
		var a = k * TAU / 4.0 + PI * 0.25
		base.append(Vector3(cos(a) * 0.5, -0.05, sin(a) * 0.5))
		midr.append(Vector3(cos(a + tw) * 0.3, 0.38, sin(a + tw) * 0.3))
	var apex = Vector3(rng.randf_range(-0.04, 0.04), 1.0, rng.randf_range(-0.04, 0.04))
	var cen = Vector3(0, 0.3, 0)
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var k1 = (k + 1) % 4
		_tri(sf, base[k], base[k1], midr[k], cen)
		_tri(sf, base[k1], midr[k1], midr[k], cen)
		_tri(sf, midr[k], midr[k1], apex, cen)
	var m = _commit(sf)
	_cache[key] = m
	return m


## Bıçak: baklava kesitli, ucu sivri, -Z yönüne uzanan (kabza 0'da); sırt çizgisi ışığı yakalar
static func blade_mesh(L: float, W: float, T: float, tipL: float) -> ArrayMesh:
	var key = "blade_%d_%d_%d_%d" % [int(L * 100), int(W * 100), int(T * 100), int(tipL * 100)]
	if _cache.has(key):
		return _cache[key]
	var sec0 = [Vector3(-W * 0.5, 0, 0), Vector3(0, T * 0.5, 0), Vector3(W * 0.5, 0, 0), Vector3(0, -T * 0.5, 0)]
	var sec1 = []
	for p in sec0:
		sec1.append(Vector3(p.x * 0.92, p.y, -L))
	var tip = Vector3(0, 0, -L - tipL)
	var cen = Vector3(0, 0, -L * 0.5)
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var k1 = (k + 1) % 4
		_tri(sf, sec0[k], sec0[k1], sec1[k], cen)
		_tri(sf, sec0[k1], sec1[k1], sec1[k], cen)
		_tri(sf, sec1[k], sec1[k1], tip, Vector3(0, 0, -L - tipL * 0.3))
	_tri(sf, sec0[0], sec0[1], sec0[2], Vector3(0, 0, 0.5))
	_tri(sf, sec0[0], sec0[2], sec0[3], Vector3(0, 0, 0.5))
	var m = _commit(sf)
	_cache[key] = m
	return m


## Kılıç: bıçak + koruma + sargılı kabza + topuz (hepsi -Z yönünde uzanır)
static func sword_node(L: float, heat := 0.0) -> Node3D:
	var root = Node3D.new()
	root.add_child(_mi(blade_mesh(L, 0.16, 0.045, 0.28), heat, 0.6))
	var b = MB.new()
	b.add("box", Vector3(0, 0, 0.02), Vector3(0.34, 0.07, 0.07), Color(0.7, 0.72, 0.76))
	b.add("box", Vector3(0, 0, 0.24), Vector3(0.055, 0.055, 0.42), Color(0.35, 0.33, 0.32))
	for q in 4:
		b.add("box", Vector3(0, 0, 0.08 + q * 0.1), Vector3(0.068, 0.068, 0.03), Color(0.55, 0.55, 0.58))
	b.add("sphere", Vector3(0, 0, 0.47), Vector3(0.09, 0.09, 0.09), Color.WHITE, Vector3.ZERO, 8)
	root.add_child(_mi(b.build(null), heat))
	return root


static func spark_mesh() -> ArrayMesh:
	if _cache.has("spark"):
		return _cache["spark"]
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(1, 1, 1), Color.WHITE)
	var m = b.build(null)
	_cache["spark"] = m
	return m


## Parıltı yıldızı: üç eksende ince çubuk + ortada top (her açıdan görünür)
static func star_mesh() -> ArrayMesh:
	if _cache.has("star"):
		return _cache["star"]
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(1.0, 0.06, 0.06), Color.WHITE)
	b.add("box", Vector3.ZERO, Vector3(0.06, 1.0, 0.06), Color.WHITE)
	b.add("box", Vector3.ZERO, Vector3(0.06, 0.06, 1.0), Color.WHITE)
	b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.22, Color.WHITE, Vector3.ZERO, 8)
	var m = b.build(null)
	_cache["star"] = m
	return m


static func ring_mesh() -> ArrayMesh:
	if _cache.has("ring"):
		return _cache["ring"]
	var b = MB.new()
	b.add("torus", Vector3.ZERO, Vector3(2.0, 0.6, 2.0), Color.WHITE, Vector3.ZERO, 40)
	var m = b.build(null)
	_cache["ring"] = m
	return m


static func disc_mesh() -> ArrayMesh:
	if _cache.has("disc"):
		return _cache["disc"]
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(2.0, 0.01, 2.0), Color.WHITE, Vector3.ZERO, 28)
	var m = b.build(null)
	_cache["disc"] = m
	return m


## Zincir halkası: YZ düzleminde oval (uzun eksen Z), tel kalınlığı yuvarlak
static func link_mesh() -> ArrayMesh:
	if _cache.has("link"):
		return _cache["link"]
	var pts = []
	var radii = []
	for s in 17:
		var a = s * TAU / 16.0
		pts.append(Vector3(0, sin(a) * 0.06, cos(a) * 0.115))
		radii.append(0.022)
	var m = MudFX.tube_mesh(pts, radii, 6, 0.0, 0.0, 0.0)
	_cache["link"] = m
	return m


## Araziye oturan çelik kaplama (ilerleyen cephe için): disk ya da d yönünde şerit
static func plate_mesh(center: Vector3, d: Vector3, strip: bool, R: float, W := 1.6) -> ArrayMesh:
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side = Vector3.UP.cross(d).normalized() if strip else Vector3.RIGHT
	var fwd = d if strip else Vector3.BACK
	var nx = 6 if strip else 18
	var nz = int(clampf(R * 2.0, 6.0, 40.0)) if strip else 18
	for iz in nz + 1:
		for ix in nx + 1:
			var x
			var z
			if strip:
				var wz = W * (1.0 + 0.25 * sin(iz * 1.3))
				x = (float(ix) / nx - 0.5) * wz
				z = R * iz / nz
			else:
				x = (float(ix) / nx * 2.0 - 1.0) * R
				z = (float(iz) / nz * 2.0 - 1.0) * R
			var wpos = center + side * x + fwd * z
			var y = Game.jutsu_floor_at(wpos).y - center.y + 0.035
			sf.set_color(Color(0.85, 0.87, 0.9))
			sf.set_uv(Vector2.ZERO)
			sf.add_vertex(Vector3(x, y, z))
	for iz in nz:
		for ix in nx:
			var A = iz * (nx + 1) + ix
			var B = A + 1
			var C = A + nx + 1
			var D = C + 1
			sf.add_index(A)
			sf.add_index(B)
			sf.add_index(C)
			sf.add_index(B)
			sf.add_index(D)
			sf.add_index(C)
	return _commit(sf)


# ------------------------------------------------------------------ hareketli parçalar
## Kıvılcım demeti: ince uzun ışık çizgileri, hızlı saçılır, yer çekimiyle eğilir, kızgın beyazdan turuncuya söner.
## blue_frac: mavi kıvılcım oranı (çelik çeliğe vurunca)
static func sparks(pj: PathJutsu, pos: Vector3, n: int, spd: float, blue_frac := 0.3, bias := Vector3.ZERO, life := 0.45) -> void:
	for k in n:
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var v0 = dir * spd * randf_range(0.4, 1.2) + bias * randf_range(0.6, 1.2)
		var blue = 1.0 if randf() < blue_frac else 0.0
		var mi = _gl(spark_mesh(), 1.0, blue)
		pj.scene_add(mi, pos)
		mi.scale = Vector3.ONE * 0.01
		var lf = life * randf_range(0.6, 1.3)
		var th = randf_range(0.018, 0.035)
		var step = func(tt: float):
			if not is_instance_valid(mi):
				return
			var v = v0 + Vector3.DOWN * G * 0.6 * tt
			mi.global_position = pos + v0 * tt + Vector3.DOWN * 0.3 * G * tt * tt
			var u = tt / lf
			var L = clampf(v.length() * 0.035, 0.05, 0.55) * (1.0 - u * 0.6)
			if v.length() > 0.1:
				var f = v.normalized()
				mi.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3(th, th, L))
			mi.set_instance_shader_parameter("heat", 1.0 - u * 0.8)
			mi.set_instance_shader_parameter("fade", 1.0 - u * u)
		var tw = mi.create_tween()
		tw.tween_method(step, 0.0, lf, lf)
		tw.tween_callback(mi.queue_free)


## Kızgın parıltı: vurulan yerde beyaz-sarı yıldız çakar, altında turuncu nokta kalır ve yavaşça koyu kırmızıya soğuyup söner
static func glint(pj: PathJutsu, pos: Vector3, size: float, life := 1.2, parent: Node3D = null) -> void:
	var star = _gl(star_mesh(), 1.0, 0.0)
	var dot = _gl(MudFX.lump_mesh(0, 0.0), 1.0, 0.0)
	for n in [star, dot]:
		if parent and is_instance_valid(parent):
			parent.add_child(n)
			n.global_position = pos
		else:
			pj.scene_add(n, pos)
	star.scale = Vector3.ONE * size * 0.2
	star.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	var st = star.create_tween()
	st.tween_property(star, "scale", Vector3.ONE * size * 1.4, 0.06).set_ease(Tween.EASE_OUT)
	st.tween_property(star, "scale", Vector3.ONE * size * 0.05, 0.22).set_ease(Tween.EASE_IN)
	st.tween_callback(star.queue_free)
	dot.scale = Vector3.ONE * size * 0.12
	ramp(dot, "heat", 1.0, 0.0, life)
	var dt = dot.create_tween()
	dt.tween_interval(life)
	dt.tween_callback(dot.queue_free)


## Çelik kıymıkları: döne döne savrulur, yere çarpınca bir kez seker, yatar, sonra toprağa çöker. Kızgın doğup soğur
static func shards(pj: PathJutsu, pos: Vector3, n: int, spd: float, size: float, bias := Vector3.ZERO, heat := 0.6) -> void:
	for k in n:
		var a = randf() * TAU
		var v0 = Vector3(cos(a), 0, sin(a)) * spd * randf_range(0.3, 1.0) + Vector3.UP * spd * randf_range(0.3, 0.8) + bias * randf_range(0.6, 1.2)
		var mi = _mi(shard_mesh(randi() % 6), heat, 0.4, false)
		pj.scene_add(mi, pos + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2)))
		var s = size * randf_range(0.5, 1.3)
		mi.scale = Vector3.ONE * s
		ramp(mi, "heat", heat, 0.0, randf_range(0.8, 1.4))
		_toss(mi, mi.global_position, v0, Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14)), s)


static func _toss(mi: MeshInstance3D, p0: Vector3, v0: Vector3, tumble: Vector3, s: float) -> void:
	var stt = {"p0": p0, "v0": v0, "t0": 0.0, "bounced": false, "rest": false, "rot0": mi.rotation}
	var step = func(tt: float):
		if stt["rest"] or not is_instance_valid(mi):
			return
		var lt = tt - stt["t0"]
		var p = stt["p0"] + stt["v0"] * lt + Vector3.DOWN * 0.5 * G * lt * lt
		var fl = Game.jutsu_floor_at(p).y
		if lt > 0.02 and p.y <= fl + s * 0.1:
			var v = stt["v0"] + Vector3.DOWN * G * lt
			if not stt["bounced"]:   # tek sekme (metal tıngırdar)
				stt["bounced"] = true
				stt["p0"] = Vector3(p.x, fl + s * 0.12, p.z)
				stt["v0"] = Vector3(v.x * 0.35, absf(v.y) * 0.22, v.z * 0.35)
				stt["t0"] = tt
				return
			stt["rest"] = true
			mi.global_position = Vector3(p.x, fl + s * 0.08, p.z)
			mi.rotation = Vector3(randf_range(-0.2, 0.2), mi.rotation.y, randf_range(-0.2, 0.2) + PI * 0.5 * float(randi() % 2))
			var tw2 = mi.create_tween()
			tw2.tween_interval(randf_range(1.2, 2.2))
			tw2.tween_property(mi, "global_position", mi.global_position - Vector3.UP * s * 0.6, 0.6).set_ease(Tween.EASE_IN)
			tw2.tween_callback(mi.queue_free)
			return
		mi.global_position = p
		mi.rotation = stt["rot0"] + tumble * tt
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, 3.0, 3.0)
	tw.tween_callback(func():
		if not stt["rest"] and is_instance_valid(mi):
			mi.queue_free())


## Sürtünme / çatlama izi: merkezden kırık çizgilerle yayılan koyu yarıklar, ortalarında kızgın turuncu çizgi soğuyarak söner
static func scrape(pj: PathJutsu, pos: Vector3, R: float, n: int, dur: float, hot := 1.0) -> void:
	var c = pj.gp(pos)
	var bm = MB.new()
	var bh = MB.new()
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dir = Vector3(cos(a), 0, sin(a))
		var p = dir * R * 0.1
		var L = R * randf_range(0.55, 1.0)
		var segn = 4
		var wd = 0.2
		for s in segn:
			dir = dir.rotated(Vector3.UP, randf_range(-0.35, 0.35))
			var q = p + dir * L / segn
			var mid = (p + q) * 0.5
			mid.y = Game.jutsu_floor_at(Vector3(c.x + mid.x, c.y, c.z + mid.z)).y - c.y + 0.04
			var ry = rad_to_deg(atan2(dir.x, dir.z))
			bm.add("box", mid, Vector3(wd, 0.02, L / segn + 0.05), Color.WHITE, Vector3(0, ry, 0), 4)
			bh.add("box", mid + Vector3.UP * 0.01, Vector3(wd * 0.28, 0.02, L / segn), Color.WHITE, Vector3(0, ry, 0), 4)
			wd *= 0.75
			p = q
	var mk = _mk(bm.build(null))
	pj.scene_add(mk, c)
	var hl = _gl(bh.build(null), hot, 0.0)
	pj.scene_add(hl, c)
	for x in [mk, hl]:
		x.scale = Vector3(0.1, 1, 0.1)
		var tw = x.create_tween()
		tw.tween_property(x, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
	ramp(hl, "heat", hot, 0.0, dur * 0.6)
	ramp(hl, "fade", 1.0, 0.0, dur * 0.3, dur * 0.6)
	ramp(mk, "fade", 1.0, 0.0, 0.5, dur)
	pj.free_after(dur + 0.6, mk)
	pj.free_after(dur, hl)


## Düz zemin izi (çökme gölgesi / ezik): fade ile görünür
static func ground_mark(pj: PathJutsu, pos: Vector3, r: float, life: float, a := 0.0) -> MeshInstance3D:
	var mi = _mk(disc_mesh())
	pj.scene_add(mi, pj.gp(pos) + Vector3.UP * 0.03)
	mi.scale = Vector3(r, 1, r)
	mi.set_instance_shader_parameter("fade", a)
	pj.free_after(life, mi)
	return mi


## Yayılan ışık halkası (çelik çarpması parlaması)
static func ring_flash(pj: PathJutsu, pos: Vector3, r0: float, r1: float, t: float, blue := 1.0) -> void:
	var mi = _gl(ring_mesh(), 1.0, blue)
	pj.scene_add(mi, pos + Vector3.UP * 0.1)
	mi.scale = Vector3(r0, 1, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 0.4, r1), t).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)
	ramp(mi, "fade", 1.0, 0.0, t)


## Hız izi: iki nokta arasında soğuk mavi-beyaz ışık çizgisi, hızla söner
static func streak(pj: PathJutsu, a: Vector3, b: Vector3, w: float, life := 0.18, blue := 1.0) -> void:
	var L = a.distance_to(b)
	if L < 0.05:
		return
	var mi = _gl(spark_mesh(), 0.9, blue)
	pj.scene_add(mi, (a + b) * 0.5)
	var f = (b - a) / L
	mi.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT) * Basis.from_scale(Vector3(w, w * 0.4, L))
	ramp(mi, "fade", 1.0, 0.0, life)
	var tw = mi.create_tween()
	tw.tween_interval(life)
	tw.tween_callback(mi.queue_free)


## Hazırlık: erimiş çelik damlaları yay çizerek bir noktada toplanır (dövülmeden önce)
static func converge(pj: PathJutsu, to: Vector3, n: int, t: float, r := 1.2) -> void:
	for k in n:
		var a = randf() * TAU
		var p0 = to + Vector3(cos(a), randf_range(-0.6, 0.6), sin(a)) * r
		var mi = _gl(MudFX.lump_mesh(k % 6, 0.0), 1.0, 0.0)
		pj.scene_add(mi, p0)
		mi.scale = Vector3.ONE * randf_range(0.04, 0.07)
		var mid = (p0 + to) * 0.5 + Vector3.UP * 0.4
		var path = func(u: float):
			if is_instance_valid(mi):
				mi.global_position = p0.lerp(mid, u).lerp(mid.lerp(to, u), u)
		var tw = mi.create_tween()
		tw.tween_method(path, 0.0, 1.0, t * randf_range(0.7, 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## Yerde ilerleyen çelik cephesi: toprak kızgın turuncu bir sınırla çeliğe döner (disk ya da şerit), sonra geri çekilir
static func steel_floor(pj: PathJutsu, center: Vector3, d: Vector3, strip: bool, R: float, grow: float, hold: float, W := 1.6) -> MeshInstance3D:
	var c = pj.gp(center)
	var mi = _mi(plate_mesh(c, d, strip, R, W), 0.0, 0.2, false)
	pj.scene_add(mi, c)
	if strip:   # şerit yerel +Z = d ile kuruldu
		mi.global_basis = _face_basis(d)
	mi.set_instance_shader_parameter("fmode", 1.0 if strip else 0.0)
	mi.set_instance_shader_parameter("front", -0.3)
	ramp(mi, "front", -0.3, R * 1.1, grow)
	ramp(mi, "front", R * 1.1, -0.4, 0.5, grow + hold)
	pj.free_after(grow + hold + 0.55, mi)
	return mi


## Çarpma: kıvılcım + kıymık + parıltı + yerdeyse sürtünme izi ve ezik + ışık halkası
static func impact(pj: PathJutsu, p: Vector3, s: float, molten := false) -> void:
	sparks(pj, p, int(26 * s), 9.0 * s, 0.1 if molten else 0.35)
	shards(pj, p, int(6 * s), 5.0 * s, 0.2 * s, Vector3.ZERO, 0.9 if molten else 0.5)
	glint(pj, p, 0.6 * s, 1.3)
	var g = pj.gp(p)
	if p.y - g.y < 1.4:
		scrape(pj, g, 1.7 * s, 6, 2.0, 1.0)
		var dent = ground_mark(pj, g, 0.9 * s, 2.6, 0.7)
		ramp(dent, "fade", 0.7, 0.0, 0.6, 2.0)
	ring_flash(pj, p, 0.3, 2.4 * s, 0.22, 0.0 if molten else 1.0)


## Elbise yırtılır: dönüşen yerden kumaş parçaları kopup savrulur
static func cloth_tear(pj: PathJutsu, c: Node3D, n: int) -> void:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.84, 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in n:
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(randf_range(0.08, 0.18), 0.01, randf_range(0.06, 0.16)), Color.WHITE, Vector3(0, randf() * 90.0, 0))
		var mi = MeshInstance3D.new()
		mi.mesh = b.build(null)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a = randf() * TAU
		var p0 = c.global_position + Vector3(cos(a) * 0.3, randf_range(0.2, 1.5), sin(a) * 0.3)
		pj.scene_add(mi, p0)
		var p1 = p0 + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, 1.8) + Vector3.UP * randf_range(0.3, 1.2)
		var tw = mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "global_position", p1, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "rotation", Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 0.9)
		tw.chain().tween_property(mi, "global_position", Game.jutsu_floor_at(p1).y * Vector3.UP + Vector3(p1.x, 0, p1.z), 0.9).set_ease(Tween.EASE_IN)
		tw.chain().tween_property(mi, "scale", Vector3.ONE * 0.05, 0.3)
		tw.chain().tween_callback(mi.queue_free)


## Modelin yüzeyine çelik deri: cephe ayaklardan başa ilerler (rise sn); geri dönüş restore() ile.
## only_free: zaten kaplaması olan parçaları atla (Kōtai Tossin'deki eski parlama ile aynı kural)
static func skin_on(c: Node3D, rise: float, heat: float, only_free: bool) -> Array:
	var out = []
	var m = c.get("model")
	if m == null or not is_instance_valid(m):
		return out
	var sm = skin_mat()
	sm.set_shader_parameter("front", -1.2)
	sm.set_shader_parameter("heat", heat)
	for mi in (m as Node).find_children("*", "MeshInstance3D", true, false):
		var g = mi as MeshInstance3D
		if only_free and g.material_overlay != null:
			continue
		out.append([g, g.material_overlay])
		g.material_overlay = sm
	var set_front = func(v: float):
		sm.set_shader_parameter("front", v)
	var set_heat = func(v: float):
		sm.set_shader_parameter("heat", v)
	var tw = (m as Node).create_tween()
	tw.tween_method(set_front, -1.2, 2.6, rise).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(set_heat, heat, 0.0, 1.2)
	if out.size() > 0:
		out[0].append(sm)
	return out


## Çelik deri cephesi aşağı çekilir (dur sn içinde); sonra kayıtlı eski kaplamalar geri konur (çağıran zamanlar)
static func skin_recede(c: Node3D, mats: Array, t: float) -> void:
	if mats.is_empty() or mats[0].size() < 3:
		return
	var sm: ShaderMaterial = mats[0][2]
	var m = c.get("model") if is_instance_valid(c) else null
	if m == null or not is_instance_valid(m):
		return
	var set_front = func(v: float):
		sm.set_shader_parameter("front", v)
	var tw = (m as Node).create_tween()
	tw.tween_method(set_front, 2.6, -1.2, t).set_ease(Tween.EASE_IN)


# ================================================================== TEKNİKLER

## Kōdan — erimiş çelik damlaları ele toplanır, kızgın dövülmüş bir gülle olur (bantlı, çekiç izli), uçarken soğur; arkasında
## soğuk hız çizgileri. Çarpınca kıvılcım, kıymık, sürtünme izi ve ışık halkası. Yōton'la: kızgın sarmal burgu, eriyen damlalar
static func kodan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "koton_kodan"
	var tt = pj.tg(c, t, 30.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.5)
	var lava = pj._has_nature(c, "yoton")
	var from: Vector3 = pj.hand_pos(c) + d * 0.5
	converge(pj, from, 9, 0.2)
	var ball = Node3D.new()
	if lava:   # erimiş çelik: sivri, sarmal burgu (ileri = -Z)
		for k in 5:
			var a = k * TAU / 5.0
			var sp = _mi(spike_mesh(k), 0.8, 0.3, false)
			sp.position = Vector3(cos(a) * 0.12, sin(a) * 0.12, 0.1 - k * 0.12)
			sp.rotation = Vector3(-PI * 0.5, 0, a + k * 0.5)
			sp.scale = Vector3(0.32, 0.9, 0.32)
			ball.add_child(sp)
	else:
		var core = _mi(MudFX.lump_mesh(5, 0.06, 0.0, 8, 10), 1.0, 0.5)   # hafif çekiç izli küre
		core.scale = Vector3.ONE * 0.45
		ball.add_child(core)
		var bb = MB.new()
		bb.add("torus", Vector3.ZERO, Vector3(0.98, 0.5, 0.98), Color(0.8, 0.82, 0.86), Vector3.ZERO, 24)
		bb.add("torus", Vector3.ZERO, Vector3(0.98, 0.5, 0.98), Color(0.8, 0.82, 0.86), Vector3(90, 0, 0), 24)
		var band = _mi(bb.build(null), 1.0, 0.6)
		ball.add_child(band)
		ramp_all(ball, "heat", 1.0, 0.0, 0.45)
	Sfx.play("clink", from, 0.7)
	var on_hit = func(p, _h):
		impact(pj, p, 1.3, lava)
		pj.shake(0.4)
		Sfx.play("clink", p, 0.5)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0 if not lava else 42.0, ball, pj.inf(c, id, 3.0 if not lava else 3.6, {"knock": 18.0, "launch": 3.0, "kind": "heavy", "element": "koton", "hitstop": 0.1, "stun": 0.6, "burn": 2.0 if lava else 0.0}), null, lava, 1.6, on_hit)
	pr.radius = 0.6
	pr.gravity = 3.0 if not lava else 0.0
	var tr = {"last": from, "t": 0.0}
	pr.on_tick = func(p2, dt):
		if not is_instance_valid(p2):
			return
		var now: Vector3 = p2.global_position
		var sd = d.cross(Vector3.UP).normalized()
		for q in 3:   # gülle arkasında soğuk hız çizgileri
			var o = sd * (q - 1) * 0.32 + Vector3.UP * ((q % 2) * 0.25 - 0.1)
			streak(pj, tr["last"] + o, now + o, 0.05, 0.14, 0.0 if lava else 1.0)
		tr["last"] = now
		tr["t"] -= dt
		if lava and tr["t"] <= 0.0:   # eriyen çelik damlar
			tr["t"] = 0.05
			var drop = _gl(MudFX.lump_mesh(1, 0.0), 1.0, 0.0)
			pj.scene_add(drop, now)
			drop.scale = Vector3.ONE * 0.06
			var fl = Game.jutsu_floor_at(now).y
			var dtw = drop.create_tween()
			dtw.tween_property(drop, "global_position", Vector3(now.x, fl, now.z), clampf((now.y - fl) * 0.18, 0.1, 0.6)).set_ease(Tween.EASE_IN)
			dtw.tween_property(drop, "scale", Vector3(0.12, 0.02, 0.12), 0.08)
			dtw.tween_interval(0.6)
			dtw.tween_callback(drop.queue_free)
			ramp(drop, "heat", 1.0, 0.1, 1.2)
	var bw = weakref(ball)
	var spin = func(_i, _k):
		var bl = bw.get_ref()
		if bl != null:
			bl.rotate_object_local(Vector3.FORWARD if lava else Vector3.RIGHT, 0.6)
	pj.every(1.6, 0.03, spin)


## Kōjun no Jutsu — yerde çelik cephesi duvarın yerine koşar; perçinli, kenarı pahlı dövme çelik levhalardan kalkan kızgın
## yükselir (altı turuncu parlar, soğur). Çarpan atış kıvılcım saçıp yüzeyde kızgın ezik bırakır. Batarken tabanda sürtünme kıvılcımı
static func kojun_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "koton_kojun_no_jutsu"
	var d = pj._face(c, t)
	pj._yama_seal(c)
	var DUR = 6.0
	var at: Vector3 = pj.gp(c.global_position + d * 1.8)
	steel_floor(pj, c.global_position, d, true, 2.4, 0.18, DUR, 4.6)
	var wall = Node3D.new()
	var b = MB.new()
	var rv = MB.new()
	for k in 5:   # dövülmüş çelik levhalar: ortası yüksek, kenarları alçak, pah çizgisi, perçin sırası
		var x = (k - 2) * 0.85
		var h = 3.0 - absf(k - 2) * 0.35
		var z = -absf(k - 2) * 0.18
		var ry = (k - 2) * 8.0
		b.add("box", Vector3(x, h * 0.5, z), Vector3(0.82, h, 0.18), Color.WHITE, Vector3(0, ry, 0))
		b.add("box", Vector3(x, h * 0.5, z + 0.1), Vector3(0.06, h * 0.9, 0.03), Color(0.75, 0.77, 0.8), Vector3(0, ry, 0))
		b.add("box", Vector3(x, h - 0.06, z + 0.03), Vector3(0.84, 0.12, 0.2), Color(0.85, 0.87, 0.9), Vector3(0, ry, 0))   # üst pah
		b.add("box", Vector3(x, h * 0.62, z), Vector3(0.84, 0.1, 0.22), Color(0.6, 0.62, 0.66), Vector3(0, ry, 0))   # bant
		for q in 3:
			for side in [-1, 1]:
				rv.add("sphere", Vector3(x + side * 0.3, 0.4 + q * (h - 0.8) * 0.5, z + 0.1), Vector3.ONE * 0.1, Color.WHITE, Vector3.ZERO, 6)
	wall.add_child(_mi(b.build(null), 0.0, 0.3))
	wall.add_child(_mi(rv.build(null), 0.0, 0.8, false))
	ramp_all(wall, "heat", 0.9, 0.0, 1.3)
	pj.scene_add(wall, at - Vector3.UP * 3.0)
	wall.global_basis = Basis.looking_at(-d, Vector3.UP)
	var wt = wall.create_tween()
	wt.tween_property(wall, "global_position", at, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wt.tween_interval(DUR)
	wt.tween_property(wall, "global_position", at - Vector3.UP * 3.2, 0.4).set_ease(Tween.EASE_IN)
	wt.tween_callback(wall.queue_free)
	var sd = d.cross(Vector3.UP).normalized()
	scrape(pj, at, 2.6, 7, 2.0)
	for q in 5:   # yarığın boyunca kalkış kıvılcımı
		sparks(pj, at + sd * (q - 2) * 0.85, 6, 6.0, 0.3, Vector3.UP * 3.0)
	var slot = ground_mark(pj, at, 1.0, DUR + 0.8, 0.75)
	slot.global_basis = Basis.looking_at(-d, Vector3.UP) * Basis.from_scale(Vector3(2.4, 1, 0.35))
	Sfx.play("clink", at, 0.6)
	for e in pj.enemies_near(c, at, 2.0):   # kalkarken önündekini iter
		e.take_hit(pj.inf(c, id, 0.8, {"knock": 12.0, "launch": 4.0, "kind": "heavy", "element": "koton", "dir": d}))
	var cw = weakref(c)
	var guard = func(_i, _k):   # duvar katıdır: arkasından geçmek isteyen atışlar ona çarpar
		var cc = cw.get_ref()
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if not is_instance_valid(p) or p.get("shooter") == cc:
				continue
			var v: Vector3 = p.global_position - at
			if absf(v.dot(d)) < 0.7 and absf(v.dot(sd)) < 2.4 and v.y > -0.3 and v.y < 3.2:
				var hp: Vector3 = p.global_position
				sparks(pj, hp, 14, 7.0, 0.45, d * 3.0)
				glint(pj, at + sd * v.dot(sd) + Vector3.UP * v.y + d * 0.12, 0.45, 1.6, wall)
				Sfx.play("clink", hp, 1.3)
				p.queue_free()
	pj.every(DUR, 0.04, guard)
	var sink_fx = func(_i, _k):
		for q in 2:
			sparks(pj, at + sd * randf_range(-2.0, 2.0) + Vector3.UP * 0.1, 3, 4.0, 0.3, Vector3.UP * 2.0, 0.3)
	pj.after(0.22 + DUR, func(): pj.every(0.4, 0.05, sink_fx))


## Kōtai — ten ayaklardan başa doğru kızgın turuncu bir cepheyle koyu tabanca çeliğine döner (tek parlak çizgi, soğuk kenar ışığı);
## elbise dönüşen yerden yırtılıp savrulur, ayak dibinde zemin çeliğe kesilir. Süre bitince çelik aşağı çekilir, kıymıklar dökülür
static func kotai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "koton_kotai"
	pj._yama_seal(c)
	var DUR = 8.0
	var mats = skin_on(c, 0.55, 0.8, false)   # ten metal parlaklığına döner (gerçek model yüzeyi)
	cloth_tear(pj, c, 14)
	steel_floor(pj, c.global_position, Vector3.FORWARD, false, 1.4, 0.4, 0.8)
	sparks(pj, c.global_position + Vector3.UP * 0.2, 16, 5.0, 0.4, Vector3.UP * 2.0)
	var cwr = weakref(c)
	var rise = func(_i, k):   # cephe yükselirken üstünden kıvılcım
		var x = cwr.get_ref()
		if x != null and is_instance_valid(x):
			sparks(pj, x.global_position + Vector3.UP * (k * 1.8), 3, 3.0, 0.3, Vector3.ZERO, 0.3)
	pj.every(0.55, 0.06, rise)
	Sfx.play("clink", c.global_position, 0.5)
	glint(pj, c.global_position + Vector3.UP * 1.2, 0.7, 0.6)
	var mods = {"armor": 0.25, "speed": 0.7, "melee": 1.3, "_name": "Kōtai", "_desc": "çelik beden: darbelere neredeyse dokunulmaz, yumruk ağır; çelik ağır olduğu için yavaşsın"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)
	c.set_meta("kotai_until", Time.get_ticks_msec() + int(DUR * 1000.0))
	pj.after(DUR - 0.45, func():   # çelik aşağı çekilir, kıymıklar dökülür
		if is_instance_valid(c):
			skin_recede(c, mats, 0.45)
			shards(pj, c.global_position + Vector3.UP * 1.0, 8, 2.5, 0.12, Vector3.ZERO, 0.0))
	pj.after(DUR, func():
		for pair in mats:
			if is_instance_valid(pair[0]):
				pair[0].material_overlay = pair[1]
		if is_instance_valid(c):
			c.remove_meta("kotai_until"))


## Kōken — elde kızgın bir çelik kılıç dövülür (kıvılcımlar, soğuyan turuncu ağız); üç geniş savuruşun her biri ardında soğuk
## mavi-beyaz kesik yayı bırakır, son darbe yere sürter: kıvılcım ve kızgın iz
static func koken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.3)
	var id = "koton_koken"
	pj._jump_at(c, tt, 0.0, 18.0 if tt and tt.global_position.distance_to(c.global_position) > 2.4 else 1.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var blade = sword_node(1.4, 1.0)
		blade.rotation.y = PI   # bıçak elden ileri (+Z) uzanır
		ba.add_child(blade)
		blade.scale = Vector3(1, 1, 0.05)
		var bt = blade.create_tween()
		bt.tween_property(blade, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ramp_all(blade, "heat", 1.0, 0.0, 0.5)
		pj.free_after(1.35, ba)
	sparks(pj, pj.hand_pos(c), 14, 5.0, 0.3)
	Sfx.play("clink", c.global_position, 0.8)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var keys = ["slash_a", "slash_b", "slash_c"]
	for k in 3:
		var swing = func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var f: Vector3 = pj._face(cc, x) if x != null and pj.live(x) else cc.face_dir()
			if x != null and pj.live(x) and cc is CharacterBody3D:
				cc.velocity = f * clampf((cc.global_position.distance_to(x.global_position) - 1.6) / 0.15, 0.0, 12.0)
			pj.anim(cc, keys[k], 2.2)
			var last = k == 2
			var o: Vector3 = cc.global_position
			var path = func(u: float) -> Vector3:
				var an = lerpf(-1.3, 1.3, u) * (1.0 if k % 2 == 0 else -1.0)
				return o + Vector3.UP * (1.1 if not last else lerpf(2.4, 0.4, u)) + (f * cos(an) + f.cross(Vector3.UP) * sin(an)) * 2.0
			slash_arc(pj, path, 0.42 if last else 0.3, 0.22)
			if last:   # yere sürter
				var gpnt = pj.gp(o + f * 2.0)
				scrape(pj, gpnt, 1.6, 4, 1.6)
				sparks(pj, gpnt + Vector3.UP * 0.1, 20, 7.0, 0.35, f * 4.0)
			Sfx.play("swing_sword", cc.global_position, 0.9)
			Combat.hit_zone(cc, pj.gp(cc.global_position), f, 3.2, 65.0, 2.6, pj.inf(cc, id, 2.0 if last else 0.9, {"knock": 16.0 if last else 2.0, "launch": 3.0 if last else 0.0, "kind": "heavy", "element": "koton", "bleed": 3.0, "hitstop": 0.09 if last else 0.04}))
		pj.after(0.25 + k * 0.3, swing)


## Kesik yayı: yol boyunca incelen hilal şerit (dışı mavi-beyaz, içi beyaz çekirdek), hızla söner
static func slash_arc(pj: PathJutsu, path: Callable, w: float, life: float) -> void:
	for layer in 2:
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n = 16
		var p0: Vector3 = path.call(0.0)
		var cen: Vector3 = path.call(0.5)
		var verts = []
		for i in n + 1:
			var u = float(i) / n
			var p: Vector3 = path.call(u)
			var inward = (cen - p)
			inward.y = 0
			inward = inward.normalized() if inward.length() > 0.01 else Vector3.UP
			var ww = w * sin(u * PI) * (1.0 if layer == 0 else 0.35)
			verts.append([p, p + inward * ww * 0.3 + Vector3.UP * ww * 0.5])
		for i in n:
			for v in [verts[i][0], verts[i + 1][0], verts[i][1], verts[i + 1][0], verts[i + 1][1], verts[i][1]]:
				sf.set_color(Color.WHITE)
				sf.add_vertex(v - p0)
		var mi = _gl(sf.commit(), 0.95 if layer == 1 else 0.7, 1.0)
		pj.scene_add(mi, p0)
		ramp(mi, "fade", 1.0, 0.0, life)
		pj.free_after(life + 0.02, mi)


## Kōsōjin — avuç yere: önünden hedefe doğru zemin kızgın bir cepheyle çeliğe kesilir, sıra sıra burgulu çelik mızraklar kızgın
## turuncu doğup soğuyarak fışkırır (dipte kıvılcım, kıymık); son demet hedefi havaya kaldırır. Mızraklar çekilince yerde kızgın delikler
static func kosojin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "koton_kosojin"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.6)
	var cw = weakref(c)
	var L = clampf(c.global_position.distance_to(tt.global_position) + 1.5, 6.0, 18.0) if tt else 14.0
	var start: Vector3 = c.global_position + d * 1.2
	var sd = d.cross(Vector3.UP).normalized()
	var hitk = {}
	scrape(pj, start, 1.4, 5, 1.5)
	var N = 9
	steel_floor(pj, start, d, true, L + 0.5, 0.12 + N * 0.06, 1.0, 1.8)
	for k in N:
		var rise = func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var p: Vector3 = start + d * (L * (k + 1) / N)
			var last = k == N - 1
			var n_sp = 5 if last else 2
			for q in n_sp:
				var o = sd * (q - (n_sp - 1) * 0.5) * (0.55 if last else 0.7) + d * randf_range(-0.3, 0.3)
				var h = (3.6 if last else 1.6 + k * 0.12) * randf_range(0.85, 1.15)
				_spike(pj, p + o, h, 0.38 if last else 0.28, 0.9 if last else 0.5, Vector3(randf_range(-14, 14), 0, randf_range(-14, 14)) + (Vector3(-25, 0, 0) if last else Vector3.ZERO))
			sparks(pj, pj.gp(p) + Vector3.UP * 0.1, 10 if not last else 24, 6.0, 0.3, Vector3.UP * 3.0)
			shards(pj, pj.gp(p) + Vector3.UP * 0.2, 2 if not last else 6, 4.0, 0.12)
			Sfx.play("clink", p, 0.8 + k * 0.05)
			for e in pj.enemies_near(cc, p, 1.6 if not last else 2.2):
				var key = e.get_instance_id()
				if hitk.has(key):
					continue
				hitk[key] = true
				e.take_hit(pj.inf(cc, id, 2.1, {"knock": 4.0, "launch": 9.0, "kind": "heavy", "element": "koton", "bleed": 3.0, "hitstop": 0.08, "pierce_guard": true, "dir": d}))
		pj.after(0.12 + k * 0.06, rise)
	pj.after(0.12 + N * 0.06, func(): pj.shake(0.3))


## Çelik mızrak: kızgın doğar, soğur, sonra çekilir; yerinde kızgın kenarlı bir delik kalır
static func _spike(pj: PathJutsu, pos: Vector3, h: float, w: float, dur: float, tilt := Vector3.ZERO) -> Node3D:
	var g = pj.gp(pos)
	var mi = _mi(spike_mesh(randi() % 5), 1.0, 0.5)
	pj.scene_add(mi, g)
	mi.rotation_degrees = tilt
	mi.scale = Vector3(w, h * 0.04, w)
	ramp(mi, "heat", 1.0, 0.0, 0.5)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(w, h, w), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3(w, h * 0.02, w), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	var hole = ground_mark(pj, g, w * 0.6, dur + 2.0, 0.8)
	ramp(hole, "fade", 0.8, 0.0, 0.6, dur + 1.3)
	var rim = _gl(ring_mesh(), 0.8, 0.0)
	pj.scene_add(rim, g + Vector3.UP * 0.05)
	rim.scale = Vector3(w * 0.6, 0.3, w * 0.6)
	ramp(rim, "heat", 0.8, 0.0, dur + 1.5)
	pj.free_after(dur + 1.6, rim)
	return mi


## Kōsa — avuçtan oklu uçlu dövme çelik zincir fırlar (tek tek oval halkalar, çaprazlama dizili); değdiği yerde kıvılcım,
## rakibe sarmal halkalarla dolanıp onu çeker; sonunda sıkışıp ezer (kıvılcım + kıymık), halkalar yere dökülür
static func kosa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var id = "koton_kosa"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj.anim(c, "throw", 1.5)
	var cw = weakref(c)
	var tip = Node3D.new()
	var head = _mi(spike_mesh(2), 0.0, 0.7, false)   # ok ucu (-Z)
	head.rotation = Vector3(-PI * 0.5, 0, 0)
	head.scale = Vector3(0.2, 0.42, 0.09)
	tip.add_child(head)
	var from: Vector3 = pj.hand_pos(c) + d * 0.3
	sparks(pj, from, 8, 4.0, 0.5)
	var links = []
	for q in 22:
		var lk = _mi(link_mesh(), 0.0, 0.5, false)
		pj.scene_add(lk, from)
		lk.visible = false
		links.append(lk)
	var state = {"held": null, "end": 2.0, "coil": false}
	var on_hit = func(p, h):
		Sfx.play("clink", p, 0.7)
		sparks(pj, p, 16, 6.0, 0.5)
		glint(pj, p, 0.4, 0.8)
		if h and is_instance_valid(h) and pj.live(h):
			state["held"] = weakref(h)
			pj.st(h, "bind", 1.6)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0, tip, pj.inf(c, id, 0.7, {"knock": 0.0, "kind": "heavy", "element": "koton", "hitstop": 0.06}), tt, false, 0.8, on_hit)
	pr.radius = 0.4
	Sfx.play("clink", from, 1.2)
	var tw = weakref(pr)
	var upd = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var a: Vector3 = pj.hand_pos(cc)
		var e_pt: Vector3
		var hw = state["held"]
		var hx = hw.get_ref() if hw else null
		var prr = tw.get_ref()
		if hx != null and is_instance_valid(hx):
			e_pt = hx.global_position + Vector3.UP * 1.0
			if pj.live(cc) and pj.live(hx) and hx is CharacterBody3D:   # zincir çeker
				var v: Vector3 = cc.global_position - hx.global_position
				v.y = 0
				if v.length() > 1.6:
					hx.velocity = v.normalized() * 16.0
			if i % 6 == 0 and not state["coil"]:
				state["coil"] = true
				_chain_coil(pj, hx)
			if i % 4 == 0:   # gergin zincirden kıvılcım
				sparks(pj, e_pt, 2, 2.5, 0.5, Vector3.ZERO, 0.25)
		elif prr != null and is_instance_valid(prr):
			e_pt = prr.global_position
		else:
			for lk in links:
				if is_instance_valid(lk):
					lk.visible = false
			return
		var L = a.distance_to(e_pt)
		var f = (e_pt - a) / maxf(L, 0.01)
		var n = clampi(int(L / 0.17), 1, links.size())
		var up = Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
		var sag = sin(float(i) * 0.3) * 0.05
		for q in links.size():
			var lk = links[q]
			if not is_instance_valid(lk):
				continue
			lk.visible = q < n
			if q < n:
				var u = (q + 0.5) / n
				var p = a.lerp(e_pt, u) - Vector3.UP * sin(u * PI) * (0.25 + sag) * minf(1.0, L / 8.0)
				var bs = Basis.looking_at(f, up)
				if q % 2 == 1:
					bs = bs.rotated(f, PI * 0.5)
				lk.global_transform = Transform3D(bs, p)
	var done = func():
		var hw = state["held"]
		var hx = hw.get_ref() if hw else null
		var cc = cw.get_ref()
		if hx != null and cc != null and pj.live(hx) and pj.live(cc):   # zincir sıkışır: ezer
			hx.take_hit(pj.inf(cc, id, 1.1, {"knock": 2.0, "kind": "heavy", "element": "koton", "hitstop": 0.08, "pierce_guard": true}))
			Sfx.play("clink", hx.global_position, 0.6)
			sparks(pj, hx.global_position + Vector3.UP, 26, 6.0, 0.5)
			shards(pj, hx.global_position + Vector3.UP, 6, 4.0, 0.1, Vector3.ZERO, 0.3)
		for lk in links:   # halkalar yere dökülür
			if is_instance_valid(lk):
				if not lk.visible:
					lk.queue_free()
					continue
				var p: Vector3 = lk.global_position
				var fl = Game.jutsu_floor_at(p).y
				var ltw = lk.create_tween()
				ltw.set_parallel(true)
				ltw.tween_property(lk, "global_position", Vector3(p.x, fl + 0.03, p.z), clampf((p.y - fl) * 0.25, 0.1, 0.45)).set_ease(Tween.EASE_IN)
				ltw.tween_property(lk, "rotation", Vector3(PI * 0.5, randf() * TAU, 0), 0.3)
				ltw.chain().tween_interval(randf_range(0.8, 1.4))
				ltw.chain().tween_property(lk, "scale", Vector3.ONE * 0.05, 0.3)
				ltw.chain().tween_callback(lk.queue_free)
	pj.every(1.4, 1.0 / 30.0, upd, done)


## Hedefe sarmal dolanan zincir: üç tur, halkalar teğet dizili
static func _chain_coil(pj: PathJutsu, x: Node3D) -> void:
	var root = Node3D.new()
	var n = 42
	for q in n:
		var u = float(q) / n
		var a = u * TAU * 3.0
		var a2 = (u + 1.0 / n) * TAU * 3.0
		var p = Vector3(cos(a) * 0.42, 0.65 + u * 0.7, sin(a) * 0.42)
		var p2 = Vector3(cos(a2) * 0.42, 0.65 + (u + 1.0 / n) * 0.7, sin(a2) * 0.42)
		var lk = _mi(link_mesh(), 0.0, 0.5, false)
		root.add_child(lk)
		var f = (p2 - p).normalized()
		var bs = Basis.looking_at(f, Vector3.UP)
		if q % 2 == 1:
			bs = bs.rotated(f, PI * 0.5)
		lk.transform = Transform3D(bs, p)
	root.scale = Vector3(1.4, 1, 1.4)
	pj.attach(x, root, 1.5)
	var fit: Vector3 = root.scale   # hedef boyuna göre büyütülmüş olabilir
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3(fit.x / 1.4, fit.y, fit.z / 1.4), 0.2).set_ease(Tween.EASE_OUT)   # sıkışır


## Kōken Hōjin — sahibinin arkasında yelpaze gibi beş kılıç birer birer kızgın turuncu dövülür (kıvılcım), soğuyup çeliğe döner,
## asılı kalır; sonra sırayla hedefe uçar (arkasında soğuk hız çizgisi). Yere saplananlar bir süre titreşip kalır
static func koken_hojin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var id = "koton_koken_hojin"
	var tt = pj.tg(c, t, 30.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var sd = d.cross(Vector3.UP).normalized()
	var swords = []
	for k in 5:
		var s = Node3D.new()
		s.add_child(sword_node(1.3, 1.0))
		var a = (k - 2) * 0.45
		var off: Vector3 = -d * 0.8 + sd * sin(a) * 1.6 + Vector3.UP * (2.2 + cos(a) * 0.9)
		pj.scene_add(s, c.global_position + off)
		s.global_basis = Basis.looking_at(d + Vector3.UP * 0.25, Vector3.UP)
		s.scale = Vector3(1, 1, 0.05)
		var st_ = s.create_tween()
		st_.tween_interval(k * 0.06)
		st_.tween_property(s, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ramp_all(s, "heat", 1.0, 0.0, 0.45, k * 0.06)
		swords.append([s, off])
		var forge = func():
			sparks(pj, c.global_position + off, 10, 4.0, 0.3)
			glint(pj, c.global_position + off, 0.5, 0.4)
		pj.after(k * 0.06, forge)
	Sfx.play("clink", c.global_position, 0.6)
	var hover = func(_i, _k):   # dövülürken sahibinin arkasında asılı kalır
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		for sw in swords:
			if is_instance_valid(sw[0]) and not sw[0].has_meta("gone"):
				sw[0].global_position = cc.global_position + sw[1]
	pj.every(0.45, 1.0 / 30.0, hover)
	for k in 5:
		var launch = func():
			var cc = cw.get_ref()
			var s: Node3D = swords[k][0]
			if not is_instance_valid(s):
				return
			if cc == null or not pj.live(cc):
				s.queue_free()
				return
			s.set_meta("gone", true)
			var x = tw.get_ref() if tw else null
			var from: Vector3 = s.global_position
			var dir: Vector3 = ((x.global_position + Vector3.UP * 1.0) - from).normalized() if x != null and pj.live(x) else cc.face_dir()
			s.get_parent().remove_child(s)
			s.position = Vector3.ZERO
			s.rotation = Vector3.ZERO
			Sfx.play("swing_sword", from, 1.2)
			var on_hit = func(p, h):
				sparks(pj, p, 14, 6.0, 0.4)
				glint(pj, p, 0.4, 0.9)
				Sfx.play("clink", p, 1.0)
				if h == null:
					_stuck_sword(pj, p, dir)
			var pr = pj.shot(cc, from, dir, 44.0, s, pj.inf(cc, id, 0.36, {"knock": 2.5, "kind": "heavy", "element": "koton", "bleed": 3.0, "hitstop": 0.05}), x if x != null and pj.live(x) else null, false, 1.2, on_hit)
			pr.radius = 0.4
			var tr = {"last": from}
			pr.on_tick = func(p2, _dt):
				if is_instance_valid(p2):
					streak(pj, tr["last"], p2.global_position, 0.06, 0.16, 1.0)
					tr["last"] = p2.global_position
		pj.after(0.5 + k * 0.12, launch)


## Yere saplanan kılıç: eğik durur, titrer, giriş yerinde kızgın parıltı; sonra toprağa çekilir
static func _stuck_sword(pj: PathJutsu, p: Vector3, dir: Vector3) -> void:
	var s = sword_node(1.3, 0.3)
	var g = pj.gp(p)
	pj.scene_add(s, g + Vector3.UP * 0.02)
	var f = dir.normalized()
	if f.y > -0.35:
		f = (f + Vector3.DOWN * 0.8).normalized()
	s.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT)
	s.global_position = g - f * 0.45   # bıçağın ucu toprağın içinde
	ramp_all(s, "heat", 0.3, 0.0, 0.8)
	var tw = s.create_tween()
	for q in 4:   # titreşim
		tw.tween_property(s, "rotation:z", s.rotation.z + 0.06 * (1.0 - q * 0.22) * (1.0 if q % 2 == 0 else -1.0), 0.04)
	tw.tween_interval(1.4)
	tw.tween_property(s, "global_position", s.global_position + f * 1.4, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)
	scrape(pj, g, 0.6, 3, 1.4, 0.8)


## Kōtetsu Tsuchi — hedefin tepesinde dev çekiç başı kızgın turuncu dövülür (bantlar, perçinler, sargılı sap), yerde gölgesi
## büyüyerek kararır; iner: ağır kıvılcım yağmuru, kıymık, kızgın çekirdekli yarıklar, ezik çukur, ışık halkası; çekiç toprağa gömülür
static func kotetsu_tsuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var id = "koton_kotetsu_tsuchi"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	pj.anim(c, "cast", 1.2)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 9.0)
	var hm = Node3D.new()
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(3.4, 1.9, 1.9), Color.WHITE)
	for s in [-1, 1]:
		b.add("box", Vector3(s * 1.72, 0, 0), Vector3(0.16, 2.02, 2.02), Color(0.7, 0.72, 0.76))   # vuruş yüzleri
		b.add("box", Vector3(s * 0.95, 0, 0), Vector3(0.22, 2.0, 2.0), Color(0.55, 0.57, 0.62))   # bantlar
		b.add("box", Vector3(s * 1.0, 0, 0.96), Vector3(0.12, 1.5, 0.04), Color(0.8, 0.82, 0.86))
		for q in 3:
			b.add("sphere", Vector3(s * 0.95, -0.6 + q * 0.6, 1.0), Vector3.ONE * 0.16, Color(0.85, 0.87, 0.9), Vector3.ZERO, 6)
			b.add("sphere", Vector3(s * 0.95, -0.6 + q * 0.6, -1.0), Vector3.ONE * 0.16, Color(0.85, 0.87, 0.9), Vector3.ZERO, 6)
	b.add("box", Vector3(0, -1.0, 0), Vector3(3.0, 0.15, 1.6), Color(0.5, 0.52, 0.56))
	b.add("cyl", Vector3(0, 3.0, 0), Vector3(0.35, 4.2, 0.35), Color(0.45, 0.47, 0.5), Vector3.ZERO, 10)
	for q in 6:   # sap sargısı
		b.add("cyl", Vector3(0, 3.6 + q * 0.3, 0), Vector3(0.42, 0.12, 0.42), Color(0.32, 0.3, 0.3), Vector3(0, 0, 4.0 * (1 if q % 2 == 0 else -1)), 10)
	b.add("sphere", Vector3(0, 5.2, 0), Vector3.ONE * 0.6, Color(0.7, 0.72, 0.76), Vector3.ZERO, 10)
	hm.add_child(_mi(b.build(null), 1.0, 0.3))
	ramp_all(hm, "heat", 1.0, 0.0, 0.6)
	pj.scene_add(hm, at + Vector3.UP * 11.0)
	hm.global_basis = Basis.looking_at(d, Vector3.UP)
	hm.scale = Vector3.ONE * 0.05
	var tw_ = hm.create_tween()
	tw_.tween_property(hm, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_.tween_property(hm, "rotation:x", deg_to_rad(-25.0), 0.25)
	tw_.tween_property(hm, "global_position", at + Vector3.UP * 1.0, 0.16).set_ease(Tween.EASE_IN)
	tw_.tween_interval(0.5)
	tw_.tween_property(hm, "global_position", at - Vector3.UP * 1.2, 0.5).set_ease(Tween.EASE_IN)   # toprağa gömülür
	tw_.tween_callback(hm.queue_free)
	var forge = func(_i, _k):   # dövülürken çekiçten kıvılcım
		if is_instance_valid(hm):
			sparks(pj, hm.global_position + Vector3(randf_range(-1.6, 1.6), randf_range(-0.9, 0.9), randf_range(-0.9, 0.9)), 3, 4.0, 0.2, Vector3.ZERO, 0.35)
	pj.every(0.55, 0.05, forge)
	Sfx.play("clink", at, 0.5)
	var shadow = ground_mark(pj, at, 0.6, 2.6, 0.0)   # yerde gölgesi büyür
	var stw = shadow.create_tween()
	stw.set_parallel(true)
	stw.tween_property(shadow, "scale", Vector3(2.2, 1, 2.2), 0.71).set_ease(Tween.EASE_IN)
	stw.tween_method(_setter(shadow, "fade"), 0.0, 0.75, 0.71)
	stw.chain().tween_interval(1.2)
	stw.chain().tween_method(_setter(shadow, "fade"), 0.75, 0.0, 0.6)
	var slam = func():
		var cc = cw.get_ref()
		pj.shake(0.7)
		scrape(pj, at, 4.5, 10, 3.0)
		sparks(pj, at + Vector3.UP * 0.3, 50, 11.0, 0.35)
		shards(pj, at + Vector3.UP * 0.3, 12, 7.0, 0.25, Vector3.ZERO, 0.8)
		ring_flash(pj, at, 0.5, 7.0, 0.35, 0.0)
		ring_flash(pj, at, 0.3, 4.0, 0.25, 1.0)
		glint(pj, at + Vector3.UP * 0.4, 1.2, 1.0)
		Sfx.play("boom", at, 0.6)
		Sfx.play("clink", at, 0.4)
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, at, 3.0):
			e.take_hit(pj.inf(cc, id, 1.8, {"knock": 3.0, "launch": -4.0, "kind": "heavy", "element": "koton", "stun": 1.4, "hitstop": 0.12, "pierce_guard": true}))
		for e in pj.enemies_near(cc, at, 5.5):
			if e.global_position.distance_to(at) > 3.0 + e.radius:
				e.take_hit(pj.inf(cc, id, 0.5, {"knock": 8.0, "launch": 2.0, "kind": "heavy", "element": "koton", "dir": (e.global_position - at).normalized()}))
	pj.after(0.71, slam)


## Kōtai Tossin — beden bir anda çeliğe döner (cephe hızla yükselir), omuz önde atılırsın: arkanda soğuk mavi hız çizgileri,
## ayaklardan sürtünme kıvılcımı ve yerde kızgın sürtünme izi; çarpışta ağır kıvılcım patlaması, kıymık, ışık halkası
static func kotai_tossin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.8)
	var id = "koton_kotai_tossin"
	var d = pj._face(c, tt)
	var heavy = c.has_meta("kotai_until") and int(c.get_meta("kotai_until")) > Time.get_ticks_msec()
	var mats = skin_on(c, 0.12, 0.4, true)
	pj.get_tree().create_timer(0.9).timeout.connect(func():
		for pair in mats:
			if is_instance_valid(pair[0]):
				pair[0].material_overlay = null)
	pj.anim(c, "dash", 1.6)
	Sfx.play("clink", c.global_position, 0.5)
	sparks(pj, c.global_position + Vector3.UP * 0.2, 12, 5.0, 0.4, -d * 3.0)
	var cw = weakref(c)
	var hitk = {}
	var last = {"p": c.global_position}
	var tick = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = d * 30.0
		var p: Vector3 = cc.global_position
		var a: Vector3 = last["p"]
		if p.distance_to(a) > 0.3:
			for q in 2:
				var o = Vector3.UP * (0.7 + q * 0.6)
				streak(pj, a + o, p + o, 0.08, 0.2, 1.0)
			if i % 3 == 0:   # ayak dibinde sürtünme
				var g = pj.gp(p)
				sparks(pj, g + Vector3.UP * 0.05, 4, 4.0, 0.2, -d * 5.0 + Vector3.UP * 2.0, 0.35)
				var mk = _mk(spark_mesh())
				pj.scene_add(mk, (pj.gp(a) + g) * 0.5 + Vector3.UP * 0.04)
				mk.global_basis = _face_basis(d) * Basis.from_scale(Vector3(0.35, 0.01, a.distance_to(p) + 0.2))
				ramp(mk, "fade", 1.0, 0.0, 0.8, 1.2)
				pj.free_after(2.1, mk)
		last["p"] = p
		for e in pj.enemies_near(cc, p + d * 0.8, 1.4):
			var key = e.get_instance_id()
			if hitk.has(key):
				continue
			hitk[key] = true
			var ip = e.global_position + Vector3.UP
			sparks(pj, ip, 34, 9.0, 0.45, d * 4.0)
			shards(pj, ip, 5, 5.0, 0.14, d * 3.0, 0.4)
			glint(pj, ip, 0.8, 0.6)
			ring_flash(pj, ip - Vector3.UP * 0.9, 0.3, 3.0, 0.2, 1.0)
			Sfx.play("clink", e.global_position, 0.5)
			pj.shake(0.35)
			e.take_hit(pj.inf(cc, id, 3.0 if heavy else 2.0, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "element": "koton", "stun": 0.8 if heavy else 0.4, "hitstop": 0.12, "pierce_guard": true, "dir": d}))
	var done = func():
		var cc = cw.get_ref()
		if cc != null and cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
	pj.every(0.45, 1.0 / 60.0, tick, done)


## Kōrō — hedefin altında zemin halka halinde çeliğe kesilir; sekiz kızgın çelik çubuk dışa kavislenip tepede düğümlenir,
## iki çember bağlar; dipte kıvılcım ve kızgın delikler. Süre sonunda çubuklar içe kapanıp ezer: tepeden kıvılcım ve kıymık
static func koro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "koton_koro"
	var tt = pj.tg(c, t, 20.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var R = 1.5 * (ClanJutsu.body_scale(tt) if tt else 1.0)
	var H = 3.4 * (ClanJutsu.body_scale(tt) if tt else 1.0)
	steel_floor(pj, at, Vector3.FORWARD, false, R * 1.5, 0.15, 2.6)
	var cage = Node3D.new()
	for k in 8:
		var a = k * TAU / 8.0
		var dv = Vector3(cos(a), 0, sin(a))
		var pts = [dv * R + Vector3.DOWN * 0.2, dv * R * 1.08 + Vector3.UP * H * 0.3, dv * R * 0.95 + Vector3.UP * H * 0.62, dv * R * 0.55 + Vector3.UP * H * 0.88, dv * R * 0.12 + Vector3.UP * H]
		cage.add_child(_mi(MudFX.tube_mesh(pts, [0.09, 0.085, 0.08, 0.075, 0.07], 6, 0.0, 0.0, 0.5), 1.0, 0.5))
	for r in 2:   # bağlayan çemberler
		var yy = H * (0.3 + r * 0.35)
		var rr = R * (1.08 if r == 0 else 0.92)
		var pts = []
		var radii = []
		for s in 25:
			var a = s * TAU / 24.0
			pts.append(Vector3(cos(a) * rr, yy, sin(a) * rr))
			radii.append(0.055)
		cage.add_child(_mi(MudFX.tube_mesh(pts, radii, 6, 0.0, 0.0, 0.0), 1.0, 0.5))
	var knot = MB.new()   # tepe düğümü
	knot.add("sphere", Vector3(0, H, 0), Vector3(0.42, 0.3, 0.42), Color.WHITE, Vector3.ZERO, 10)
	knot.add("cone", Vector3(0, H + 0.3, 0), Vector3(0.22, 0.4, 0.22), Color(0.85, 0.87, 0.9), Vector3.ZERO, 4)
	cage.add_child(_mi(knot.build(null), 1.0, 0.6))
	ramp_all(cage, "heat", 1.0, 0.0, 0.9)
	pj.scene_add(cage, at - Vector3.UP * H)
	var ct = cage.create_tween()
	ct.tween_property(cage, "global_position", at, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.free_after(3.5, cage)
	for k in 8:   # çubuk diplerinde kıvılcım
		var a = k * TAU / 8.0
		sparks(pj, at + Vector3(cos(a), 0.1, sin(a)) * R, 6, 5.0, 0.3, Vector3.UP * 3.0)
	scrape(pj, at, R * 1.6, 8, 3.0)
	Sfx.play("clink", at, 0.6)
	var caught = []
	for e in pj.enemies_near(c, at, R):
		caught.append(weakref(e))
		pj.st(e, "bind", 2.6)
		e.take_hit(pj.inf(c, id, 0.4, {"knock": 0.0, "kind": "heavy", "element": "koton", "hitstop": 0.04}))
	var crush = func():   # içe kapanır
		var cc = cw.get_ref()
		if is_instance_valid(cage):
			var t2 = cage.create_tween()
			t2.tween_property(cage, "scale", Vector3(0.15, 1.05, 0.15), 0.12).set_ease(Tween.EASE_IN)
			t2.tween_interval(0.25)
			t2.tween_property(cage, "global_position", at - Vector3.UP * H, 0.3)
			t2.tween_callback(cage.queue_free)
			ramp_all(cage, "heat", 0.0, 0.7, 0.12)
		sparks(pj, at + Vector3.UP * H * 0.5, 30, 7.0, 0.45)
		shards(pj, at + Vector3.UP * H * 0.5, 6, 4.0, 0.14)
		Sfx.play("clink", at, 0.4)
		pj.shake(0.3)
		if cc == null or not pj.live(cc):
			return
		for w in caught:
			var e = w.get_ref()
			if e != null and pj.live(e) and e.global_position.distance_to(at) < R + 1.0:
				sparks(pj, e.global_position + Vector3.UP, 18, 6.0, 0.45)
				glint(pj, e.global_position + Vector3.UP, 0.6, 0.6)
				e.take_hit(pj.inf(cc, id, 1.3, {"knock": 2.0, "launch": 3.0, "kind": "heavy", "element": "koton", "bleed": 3.0, "hitstop": 0.1, "pierce_guard": true}))
	pj.after(2.6, crush)
