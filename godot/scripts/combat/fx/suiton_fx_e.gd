class_name SuitonFXE
extends RefCounted
## Suiton grubu E: on beş su tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları SuitonLib'den
## (su gölgelendiricisi, damla, birikinti, sis, kabarcık); bu dosyanın kendi parçaları: gerçek boyda kurulan su köpekbalığı
## (yüzgeç, solungaç, diş dizisi, açılan çene, sallanan hilal kuyruk), kesitten süpürülen dalga / sel duvarı, sarmal su kalkanı
## gölgelendiricisi, ayna kabuğu gölgelendiricisi, hortum gölgelendiricisi, burgulu su dikeni.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağacın işleyicilerinden satır satır taşındı.
## Büyük su kütleleri gerçek boyda kurulur (küçük mesh ölçeklenmez), kameraya 6-9 m'de incelir.

const L = preload("res://scripts/combat/fx/lib/suiton_lib.gd")

static var _cache := {}

## köpekbalığı gövde yarıçapı / boy (u: burun 0 → kuyruk sapı 1)
const SHARK_R := [[0.0, 0.012], [0.04, 0.05], [0.1, 0.08], [0.2, 0.104], [0.32, 0.117], [0.45, 0.112], [0.6, 0.09], [0.74, 0.058], [0.86, 0.032], [1.0, 0.022]]


# ------------------------------------------------------------------ gölgelendiriciler (bu gruba özgü)
## Suijun: dik duran, kendi çevresinde dönen sarmal su diski (ref: Yagura su kalkanı — iki kollu girdap, açık köpük kenarı, tırtıklı çevre)
const DISC_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float rad = 1.4;
instance uniform float pulse = 0.0;

varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	lp = VERTEX;
	float an = atan(VERTEX.y, VERTEX.x);
	float r = length(VERTEX.xy);
	VERTEX.z += (sin(an * 5.0 + TIME * 4.0 + seed) * 0.04 + pulse * 0.18) * r;
}

void fragment() {
	float r = length(lp.xy);
	float an = atan(lp.y, lp.x);
	float rn = r / rad;
	float edge = 0.86 + 0.1 * vn(vec2(an * 2.5 + seed, TIME * 1.3)) + 0.04 * vn(vec2(an * 9.0, TIME * 3.0 + seed));
	float inside = 1.0 - smoothstep(edge - 0.015, edge, rn);
	float sw = fract(rn * 3.4 + an / 6.2832 * 2.0 - TIME * 0.9 + vn(lp.xy * 3.0 + vec2(seed)) * 0.35);
	vec3 deep = vec3(0.1, 0.3, 0.62);
	vec3 mid = vec3(0.25, 0.52, 0.86);
	vec3 shal = vec3(0.62, 0.84, 0.98);
	vec3 col = mix(mid, deep, step(0.5, sw));
	col = mix(col, shal, step(0.78, sw) * step(sw, 0.9));
	col = mix(col, vec3(0.93, 0.98, 1.0), smoothstep(edge - 0.09, edge - 0.04, rn));
	float core = 1.0 - smoothstep(0.0, 0.14, rn);
	col = mix(col, shal, core * 0.6);
	float nearf = smoothstep(0.6, 2.4, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = inside * 0.9 * fade * nearf;
}
"""

## Meikyō Shisui: kıpırtısız, berrak ayna kabuğu (ref: Kagura — açık camgöbeği saydam küre, eğik ışık şeritleri, ince koyu kenar)
const GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform vec3 hit_l = vec3(0.0, 0.0, 0.0);
instance uniform float hit_t = 9.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fr = 1.0 - abs(dot(n, VIEW));
	vec3 col = vec3(0.6, 0.85, 0.97);
	float a = 0.15 + smoothstep(0.35, 0.95, fr) * 0.3;
	float dg = dot(lp.xy, vec2(0.62, 0.78)) + lp.z * 0.2;
	float b1 = step(0.82, fract(dg * 0.85 + TIME * 0.04 + seed));
	float b2 = step(0.93, fract(dg * 2.3 - TIME * 0.03 + seed * 1.7));
	col = mix(col, vec3(0.92, 0.98, 1.0), max(b1 * 0.7, b2));
	a += b1 * 0.12 + b2 * 0.2;
	float dd = length(lp - hit_l);
	float ring = (1.0 - smoothstep(0.0, 0.07, abs(dd - hit_t * 2.6))) * (1.0 - clamp(hit_t / 0.7, 0.0, 1.0));
	col = mix(col, vec3(1.0), ring);
	a = max(a, ring * 0.85);
	float bd = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = max(step(0.94, fr), 1.0 - smoothstep(0.0, 0.025, bd));
	col = mix(col, vec3(0.16, 0.42, 0.68), edge);
	a = max(a, edge * 0.7);
	float nearf = smoothstep(0.5, 2.2, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0) * fade * mix(0.35, 1.0, nearf);
}
"""

## Mizu Tatsumaki: camgöbeği-turkuaz hortum (ref: yatay bulanık su şeritleri, dönerek yükselen sütun, tepesi tırtıklı söner)
const TORNADO_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float hgt = 5.0;
instance uniform float spd = 1.0;

varying vec3 lp;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float an = atan(lp.z, lp.x);
	float y = lp.y / hgt;
	float a1 = an + TIME * 5.0 * spd + seed;
	float n1 = vn3(vec3(cos(a1) * 1.7, sin(a1) * 1.7, lp.y * 6.5));
	float a2 = an + TIME * 8.0 * spd;
	float n2 = vn3(vec3(cos(a2) * 3.4, sin(a2) * 3.4, lp.y * 15.0 + 7.0));
	float s = n1 * 0.6 + n2 * 0.4;
	vec3 deep = vec3(0.08, 0.5, 0.55);
	vec3 mid = vec3(0.25, 0.78, 0.78);
	vec3 lt = vec3(0.62, 0.96, 0.92);
	vec3 col = mix(deep, mid, step(0.38, s));
	col = mix(col, lt, step(0.56, s));
	col = mix(col, vec3(0.92, 1.0, 0.98), step(0.7, s));
	vec3 n = normalize(NORMAL);
	float fr = 1.0 - abs(dot(n, VIEW));
	float ak = (0.28 + 0.42 * step(0.38, s) + 0.22 * step(0.7, s)) * mix(0.55, 1.0, fr);
	float vy = smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.8 + 0.12 * n1, 1.0, y));
	float nearf = smoothstep(0.8, 3.0, -VERTEX.z);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = clamp(ak * vy, 0.0, 1.0) * fade * nearf;
}
"""


# ------------------------------------------------------------------ küçük yardımcılar
static func _c(key: String, build: Callable):
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func _up_for(d: Vector3) -> Vector3:
	return Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT


static func _flat(v: Vector3) -> Vector3:
	var f = Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


## Düğümün -Z eksenini d yönüne çevirir (sahnede olmalı)
static func _aim(n: Node3D, d: Vector3) -> void:
	if d.length() > 0.001:
		n.look_at(n.global_position + d, _up_for(d))


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _flatm(key: String, col: Color, add := false) -> StandardMaterial3D:
	return _c("m_" + key, func():
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.disable_receive_shadows = true
		if col.a < 0.999 or add:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m)


static func _smat(key: String, code: String) -> ShaderMaterial:
	return _c("s_" + key, func():
		var sh = Shader.new()
		sh.code = code
		var m = ShaderMaterial.new()
		m.shader = sh
		return m)


## Tüm alt meshleri söndürür (su gölgelendiricisi: fade; düz malzeme: saydamlık)
static func _fade_all(n: Node, v: float) -> void:
	if not is_instance_valid(n):
		return
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		var g = mi as GeometryInstance3D
		if g.material_override is ShaderMaterial:
			g.set_instance_shader_parameter("fade", v)
		else:
			g.transparency = 1.0 - v
	if n is GeometryInstance3D:
		if (n as GeometryInstance3D).material_override is ShaderMaterial:
			(n as GeometryInstance3D).set_instance_shader_parameter("fade", v)


static func _fade_out(n: Node3D, delay: float, t: float, sc := Vector3.ONE) -> void:
	if not is_instance_valid(n):
		return
	var tw = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): _fade_all(n, v), 1.0, 0.0, t)
	if sc != Vector3.ONE:
		tw.parallel().tween_property(n, "scale", n.scale * sc, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


## Zaman yavaşlatma (eski işleyicideki yavaş an, aynı kuralla: zaten yavaşsa dokunmaz)
static func _slowmo(h: Node, s: float, real_dur: float) -> void:
	if Combat.base_time_scale < 0.99:
		return
	Combat.base_time_scale = s
	Engine.time_scale = s
	h.get_tree().create_timer(real_dur, true, false, true).timeout.connect(func():
		if absf(Combat.base_time_scale - s) < 0.001:
			Combat.base_time_scale = 1.0)


static func _near_ground(p: Vector3, lim := 1.6) -> bool:
	return p.y - Game.jutsu_floor(p.x, p.z) < lim


# ------------------------------------------------------------------ meshler (gerçek boy)
## 2B kesit (f ileri, y yukarı, kalınlık) X boyunca w genişlikte süpürülür → kapalı su kütlesi. jag: tepe yüksekliği dalgalanması.
## Yerel: genişlik X, ileri -Z, yukarı Y. Uçlarda kesit yere doğru incelir.
static func _extrude_mesh(prof: Array, w: float, nx: int, jag := 0.0, seed_ := 0.0, jf := 1.0) -> ArrayMesh:
	var n = prof.size()
	var front = []
	var back = []
	for j in n:
		var p = Vector2(float(prof[j][0]), float(prof[j][1]))
		var pa: Array = prof[maxi(j - 1, 0)]
		var pb: Array = prof[mini(j + 1, n - 1)]
		var tg2 = (Vector2(float(pb[0]), float(pb[1])) - Vector2(float(pa[0]), float(pa[1]))).normalized()
		var nr = Vector2(tg2.y, -tg2.x)
		var th = float(prof[j][2]) * 0.5
		front.append(p + nr * th)
		back.append(p - nr * th)
	var loop2 = []
	for j in n:
		loop2.append(front[j])
	for j in n:
		loop2.append(back[n - 1 - j])
	var m = loop2.size()
	# sarım: (Y, Z=-f) düzleminde saat yönü tersi (kütüphanenin tüp sarımıyla aynı: dış yüz görünür)
	var area = 0.0
	for j in m:
		var p0: Vector2 = loop2[j]
		var p1: Vector2 = loop2[(j + 1) % m]
		area += p0.y * (-p1.x) - p1.y * (-p0.x)
	if area < 0.0:
		loop2.reverse()
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx + 1:
		var u = float(i) / nx
		var x = -w * 0.5 + w * u
		var e = maxf(0.04, pow(clampf(sin(PI * u), 0.0, 1.0), 0.35))
		var js = 1.0 + jag * (sin(x * 0.9 * jf + seed_) * 0.6 + sin(x * 2.3 * jf + seed_ * 1.7) * 0.4)
		for s in m + 1:
			var q: Vector2 = loop2[s % m]
			sf.set_uv(Vector2(x / 1.5, float(s) / m * 3.0))
			sf.add_vertex(Vector3(x, q.y * e * js, -q.x * lerpf(0.6, 1.0, e)))
	for i in nx:
		for s in m:
			var a0 = i * (m + 1) + s
			var u0 = a0 + m + 1
			sf.add_index(a0)
			sf.add_index(u0)
			sf.add_index(a0 + 1)
			sf.add_index(a0 + 1)
			sf.add_index(u0)
			sf.add_index(u0 + 1)
	sf.generate_normals()
	return sf.commit()


## Düz su diski (XY düzlemi, gerçek yarıçap)
static func _disc_mesh(r: float) -> ArrayMesh:
	return _c("disc_%d" % int(r * 100.0), func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs = 56
		var rings = 7
		sf.set_uv(Vector2(0.5, 0.5))
		sf.add_vertex(Vector3.ZERO)
		for k in rings:
			var rr = r * float(k + 1) / rings
			for s in segs:
				var a = s * TAU / segs
				sf.set_uv(Vector2(cos(a) * 0.5 + 0.5, sin(a) * 0.5 + 0.5))
				sf.add_vertex(Vector3(cos(a) * rr, sin(a) * rr, 0.0))
		for s in segs:
			sf.add_index(0)
			sf.add_index(1 + s)
			sf.add_index(1 + (s + 1) % segs)
		for k in rings - 1:
			var ib = 1 + k * segs
			var ob = ib + segs
			for s in segs:
				var s1 = (s + 1) % segs
				sf.add_index(ib + s)
				sf.add_index(ob + s)
				sf.add_index(ob + s1)
				sf.add_index(ib + s)
				sf.add_index(ob + s1)
				sf.add_index(ib + s1)
		sf.generate_normals()
		return sf.commit())


## Önde kubbelenen küre parçası (merkez orijin, yüzey -Z yönünde Rs uzakta)
static func _cap_mesh(rs: float) -> ArrayMesh:
	return _c("cap_%d" % int(rs * 100.0), func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nt = 28
		var np = 18
		for j in np + 1:
			var ph = lerpf(-0.95, 1.1, float(j) / np)
			for i in nt + 1:
				var th = lerpf(-1.25, 1.25, float(i) / nt)
				sf.set_uv(Vector2(float(i) / nt, float(j) / np))
				sf.add_vertex(Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph)) * rs)
		for j in np:
			for i in nt:
				var a0 = j * (nt + 1) + i
				var u0 = a0 + nt + 1
				sf.add_index(a0)
				sf.add_index(u0)
				sf.add_index(a0 + 1)
				sf.add_index(a0 + 1)
				sf.add_index(u0)
				sf.add_index(u0 + 1)
		sf.generate_normals()
		return sf.commit())


## Açık hortum silindiri (yukarı genişler), gerçek boy
static func _tornado_mesh(r: float, h: float) -> ArrayMesh:
	return _c("torn_%d_%d" % [int(r * 100.0), int(h * 10.0)], func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings = 18
		var segs = 40
		for i in rings + 1:
			var y = h * float(i) / rings
			var rr = r * (0.78 + 0.32 * y / h) * (1.0 + 0.05 * sin(i * 1.7))
			for s in segs + 1:
				var a = s * TAU / segs
				sf.set_uv(Vector2(float(s) / segs, float(i) / rings))
				sf.add_vertex(Vector3(cos(a) * rr, y, sin(a) * rr))
		for i in rings:
			for s in segs:
				var a0 = i * (segs + 1) + s
				var u0 = a0 + segs + 1
				sf.add_index(a0)
				sf.add_index(u0)
				sf.add_index(a0 + 1)
				sf.add_index(a0 + 1)
				sf.add_index(u0)
				sf.add_index(u0 + 1)
		sf.generate_normals()
		return sf.commit())


## Burgulu su dikeni: geniş taban, kıvrılarak incelen gövde, gövdeden fırlayan üç yan dikencik (gerçek boy)
static func _toge_mesh(h: float, r: float) -> ArrayMesh:
	return _c("toge_%d_%d" % [int(h * 10.0), int(r * 100.0)], func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts = []
		var rad = []
		var n = 16
		for i in n:
			var u = i / float(n - 1)
			var tw = u * 2.4
			pts.append(Vector3(cos(tw) * r * 0.14 * u, u * h, sin(tw) * r * 0.14 * u))
			var bul = 1.0 + 0.12 * sin(u * 17.0)
			rad.append(r * pow(1.0 - u, 1.15) * bul + 0.004)
		var vc = L.tube_into(sf, 0, pts, rad, 12)
		for k in 3:
			var a = k * TAU / 3.0 + 0.5
			var u0 = 0.18 + k * 0.12
			var b0 = Vector3(cos(a) * r * 0.6 * (1.0 - u0), u0 * h, sin(a) * r * 0.6 * (1.0 - u0))
			var dir = Vector3(cos(a), 1.6, sin(a)).normalized()
			var ln = h * 0.28
			vc = L.tube_into(sf, vc, [b0, b0 + dir * ln * 0.5, b0 + dir * ln], [r * 0.28, r * 0.14, 0.004], 8)
		sf.generate_normals()
		return sf.commit())


## Tırtıklı köpük halkası (Z ekseni çevresinde, yassı akış kesitine uyar)
static func _jag_ring_mesh(rr: float, v: int) -> ArrayMesh:
	return _c("jring_%d_%d" % [int(rr * 100.0), v], func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 331 + v * 77
		var n = 30
		var offs = []
		var zo = []
		for i in n:
			offs.append(1.0 + rng.randf_range(-0.08, 0.14))
			zo.append(rng.randf_range(-0.25, 0.25))
		var pts = []
		var rad = []
		for i in n + 1:
			var ix = i % n
			var a = ix * TAU / n
			pts.append(Vector3(cos(a) * rr * float(offs[ix]), sin(a) * rr * float(offs[ix]) * 0.72, float(zo[ix])))
			rad.append(0.06 + 0.13 * absf(sin(a * 4.0 + v)))
		return L.tube_mesh(pts, rad, 6, 0.45, Vector3.BACK))


## Teppunokyū girdap başı: dönen mercek + geriye yatık dört kol (gerçek boy, -Z ileri)
static func _whirl_head_mesh() -> ArrayMesh:
	return _c("whirl_head", func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = L.tube_into(sf, 0, [Vector3(0, 0, -0.32), Vector3(0, 0, -0.16), Vector3(0, 0, 0.0), Vector3(0, 0, 0.16), Vector3(0, 0, 0.32)],
			[0.12, 0.72, 0.95, 0.7, 0.1], 18)
		for k in 4:
			var a = k * TAU / 4.0
			var dr = Vector3(cos(a), sin(a), 0.0)
			var b0 = dr * 0.8
			vc = L.tube_into(sf, vc, [b0, b0 + dr * 0.45 + Vector3(0, 0, 0.15), b0 + dr * 0.9 + Vector3(0, 0, 0.4)], [0.14, 0.07, 0.005], 6, 0.4, Vector3.BACK)
		sf.generate_normals()
		return sf.commit())


## Boğan su kesesi: başı saran yuvarlak gövde + boyna sarkan damla ucu (gerçek boy, Y ekseni)
static func _blob_mesh() -> ArrayMesh:
	return _c("dek_blob", func():
		var ys = [-0.62, -0.52, -0.36, -0.2, 0.0, 0.18, 0.32, 0.42, 0.47]
		var rs = [0.0, 0.1, 0.2, 0.31, 0.37, 0.36, 0.29, 0.16, 0.0]
		var pts = []
		for y in ys:
			pts.append(Vector3(0, float(y), 0))
		return L.tube_mesh(pts, rs, 18, 0.95, Vector3.FORWARD))


## Avuç önündeki beyaz yıldız parlaması (XY düzlemi, ince sivri ışınlar)
static func _star_mesh() -> ArrayMesh:
	return _c("arare_star", func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 5150
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n = 18
		for k in n:
			var a = k * TAU / n + rng.randf_range(-0.08, 0.08)
			var ln = rng.randf_range(0.75, 1.0) if k % 2 == 0 else rng.randf_range(0.35, 0.6)
			var dr = Vector3(cos(a), sin(a), 0.0)
			var sd = Vector3(-sin(a), cos(a), 0.0)
			sf.add_vertex(sd * 0.05)
			sf.add_vertex(dr * ln)
			sf.add_vertex(-sd * 0.05)
		# merkez parlak çekirdek
		for k in 12:
			var a0 = k * TAU / 12.0
			var a1 = (k + 1) * TAU / 12.0
			sf.add_vertex(Vector3.ZERO)
			sf.add_vertex(Vector3(cos(a0), sin(a0), 0) * 0.16)
			sf.add_vertex(Vector3(cos(a1), sin(a1), 0) * 0.16)
		return sf.commit())


# ------------------------------------------------------------------ su köpekbalığı (ref: Kisame Suikōdan)
static func _sr(u: float) -> float:
	for i in range(SHARK_R.size() - 1):
		var a: Array = SHARK_R[i]
		var b: Array = SHARK_R[i + 1]
		if u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (u - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return 0.022


## ln boyunda köpekbalığı parçaları (gerçek boy, önbellekli). -Z burun, +Y sırt.
static func _shark_parts(ln: float) -> Dictionary:
	var key = "shark_%d" % int(round(ln * 20.0))
	if _cache.has(key):
		return _cache[key]
	var zf = func(u: float) -> float: return -0.5 * ln + u * 0.92 * ln
	var yf = func(u: float) -> float: return 0.025 * ln * maxf(0.0, 1.0 - u / 0.22)
	var fl = 0.8
	# --- gövde + sırt / göğüs / ikinci sırt / anal yüzgeçleri
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts = []
	var rad = []
	for i in 22:
		var u = i / 21.0
		pts.append(Vector3(0, yf.call(u), zf.call(u)))
		rad.append(_sr(u) * ln)
	var vc = L.tube_into(sf, 0, pts, rad, 14, fl, Vector3.UP)
	var ud = 0.36
	var top = Vector3(0, yf.call(ud) + _sr(ud) * ln * 0.85, zf.call(ud))
	pts = []
	rad = []
	for j in 6:
		var v = j / 5.0
		pts.append(top + Vector3(0, v * 0.2 * ln, v * v * 0.13 * ln))
		rad.append(0.075 * ln * pow(1.0 - v, 0.85) + 0.004 * ln)
	vc = L.tube_into(sf, vc, pts, rad, 6, 0.16, Vector3.BACK)
	var upc = 0.27
	for sx in [-1.0, 1.0]:
		var b0 = Vector3(sx * _sr(upc) * ln * fl * 0.8, yf.call(upc) - _sr(upc) * ln * 0.45, zf.call(upc))
		pts = []
		rad = []
		for j in 6:
			var v = j / 5.0
			pts.append(b0 + Vector3(sx * v * 0.24 * ln, -v * 0.07 * ln, v * v * 0.12 * ln))
			rad.append(0.055 * ln * pow(1.0 - v, 0.8) + 0.003 * ln)
		vc = L.tube_into(sf, vc, pts, rad, 6, 0.18, Vector3.BACK)
	for sg in [1.0, -1.0]:
		var u2 = 0.74
		var b1 = Vector3(0, yf.call(u2) + sg * _sr(u2) * ln * 0.8, zf.call(u2))
		vc = L.tube_into(sf, vc, [b1, b1 + Vector3(0, sg * 0.05 * ln, 0.04 * ln)], [0.024 * ln, 0.003 * ln], 5, 0.2, Vector3.BACK)
	sf.generate_normals()
	var body = sf.commit()
	# --- hilal kuyruk (kuyruk sapında döner)
	var tail_at = Vector3(0, yf.call(0.88), zf.call(0.88))
	sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	vc = L.tube_into(sf, 0, [Vector3(0, 0, -0.06 * ln), Vector3(0, 0, 0.05 * ln)], [0.03 * ln, 0.022 * ln], 8, fl, Vector3.UP)
	for lobe in [[0.27, 0.11, 0.065], [-0.17, 0.08, 0.05]]:
		pts = []
		rad = []
		for j in 7:
			var v = j / 6.0
			pts.append(Vector3(0, v * float(lobe[0]) * ln, 0.04 * ln + v * float(lobe[1]) * ln + v * v * 0.07 * ln))
			rad.append(float(lobe[2]) * ln * pow(1.0 - v, 0.8) + 0.003 * ln)
		vc = L.tube_into(sf, vc, pts, rad, 6, 0.15, Vector3.BACK)
	sf.generate_normals()
	var tail = sf.commit()
	# --- alt çene (menteşede açılır)
	var uh = 0.2
	var hinge = Vector3(0, yf.call(uh) - _sr(uh) * ln * 0.5, zf.call(uh))
	var jpts = []
	var jrad = []
	for j in 6:
		var v = j / 5.0
		var u = lerpf(uh, 0.04, v)
		jpts.append(Vector3(0, -0.012 * ln * sin(v * PI), zf.call(u) - hinge.z))
		jrad.append(lerpf(_sr(uh) * 0.62, 0.02, v) * ln)
	var jaw = L.tube_mesh(jpts, jrad, 10, 0.4, Vector3.RIGHT)
	# --- dişler: üst damakta aşağı, alt çenede yukarı (U dizilimi)
	var tsf = SurfaceTool.new()
	tsf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tvc = 0
	for k in 11:
		var s = lerpf(-1.0, 1.0, k / 10.0)
		var u = 0.045 + 0.15 * s * s
		var bp = Vector3(s * _sr(u) * ln * fl * 0.85, yf.call(u) - _sr(u) * ln * 0.6, zf.call(u))
		tvc = L.tube_into(tsf, tvc, [bp + Vector3.UP * 0.01 * ln, bp + Vector3.DOWN * 0.045 * ln], [0.013 * ln, 0.0005], 4)
	tsf.generate_normals()
	var teeth_up = tsf.commit()
	tsf = SurfaceTool.new()
	tsf.begin(Mesh.PRIMITIVE_TRIANGLES)
	tvc = 0
	for k in 11:
		var s = lerpf(-1.0, 1.0, k / 10.0)
		var v = 1.0 - s * s * 0.85
		var u = lerpf(uh, 0.04, v)
		var r = lerpf(_sr(uh) * 0.62, 0.02, v) * ln
		var bp = Vector3(s * r * 0.85, -0.012 * ln * sin(v * PI) + r * 0.3, zf.call(u) - hinge.z)
		tvc = L.tube_into(tsf, tvc, [bp + Vector3.DOWN * 0.01 * ln, bp + Vector3.UP * 0.04 * ln], [0.012 * ln, 0.0005], 4)
	tsf.generate_normals()
	var teeth_lo = tsf.commit()
	# --- koyu işaretler: solungaç yarıkları, gözler, ağız boşluğu
	var msf = SurfaceTool.new()
	msf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mvc = 0
	for sx in [-1.0, 1.0]:
		for g in 4:
			var u = 0.235 + g * 0.032
			var r = _sr(u) * ln
			var cx = sx * (r * fl + 0.004 * ln)
			var gp = []
			for j in 4:
				var v = j / 3.0
				gp.append(Vector3(cx, yf.call(u) + lerpf(0.42, -0.45, v) * r, zf.call(u) + 0.022 * ln * sin(v * PI)))
			mvc = L.tube_into(msf, mvc, gp, [0.004 * ln, 0.0065 * ln, 0.0065 * ln, 0.004 * ln], 4)
		var ue = 0.09
		var re = _sr(ue) * ln
		var ec = Vector3(sx * re * fl * 0.93, yf.call(ue) + re * 0.25, zf.call(ue))
		mvc = L.tube_into(msf, mvc, [ec + Vector3(0, 0, -0.02 * ln), ec, ec + Vector3(0, 0, 0.02 * ln)], [0.002 * ln, 0.014 * ln, 0.002 * ln], 8, 0.75, Vector3.UP)
	var cav = []
	var crad = []
	for j in 5:
		var v = j / 4.0
		var u = lerpf(0.05, 0.21, v)
		cav.append(Vector3(0, yf.call(u) - _sr(u) * ln * 0.5, zf.call(u)))
		crad.append(_sr(u) * ln * lerpf(0.35, 0.7, sin(v * PI * 0.5)))
	mvc = L.tube_into(msf, mvc, cav, crad, 10, 0.45, Vector3.RIGHT)
	msf.generate_normals()
	var marks = msf.commit()
	var out = {"body": body, "tail": tail, "tail_at": tail_at, "jaw": jaw, "hinge": hinge, "teeth_up": teeth_up, "teeth_lo": teeth_lo, "marks": marks}
	_cache[key] = out
	return out


## Su köpekbalığı düğümü (burun -Z). o: alpha, pal, neard
static func _shark(ln: float, o := {}) -> Node3D:
	var P = _shark_parts(ln)
	var root = Node3D.new()
	var wo = {"alpha": o.get("alpha", 0.86), "line": 0.11, "flow": 2.2, "streak": 1.6, "pal": o.get("pal", L.WATER), "neard": o.get("neard", 5.0), "foam": 0.0}
	root.add_child(L.wmi(P["body"], wo))
	var tooth = _flatm("shark_tooth", Color(0.96, 0.99, 1.0))
	var mark = _flatm("shark_mark", Color(0.04, 0.13, 0.36, 0.88))
	root.add_child(_mi(P["marks"], mark))
	root.add_child(_mi(P["teeth_up"], tooth))
	var jaw = Node3D.new()
	jaw.position = P["hinge"]
	root.add_child(jaw)
	jaw.add_child(L.wmi(P["jaw"], wo))
	jaw.add_child(_mi(P["teeth_lo"], tooth))
	var tail = Node3D.new()
	tail.position = P["tail_at"]
	root.add_child(tail)
	tail.add_child(L.wmi(P["tail"], wo))
	root.set_meta("jaw", jaw)
	root.set_meta("tail", tail)
	root.set_meta("ph", randf() * TAU)
	return root


## Köpekbalığı pozu: kuyruk sallanır, çene açılır (open radyan)
static func _shark_pose(sh: Node3D, t: float, open: float, wag := 1.0) -> void:
	if sh == null or not is_instance_valid(sh):
		return
	var ph = float(sh.get_meta("ph", 0.0))
	var tl = sh.get_meta("tail", null)
	if tl != null and is_instance_valid(tl):
		tl.rotation.y = sin(t * 10.0 + ph) * 0.38 * wag
	var jw = sh.get_meta("jaw", null)
	if jw != null and is_instance_valid(jw):
		jw.rotation.x = -open


## Köpekbalığının ardından kopan beyaz su şeritleri (ref: gövdeden yırtılarak geriye akan köpüklü dil)
static func _shark_wake(sh: Node3D, ln: float, n := 30) -> GPUParticles3D:
	var p = L.trail(sh, {"n": n, "life": 0.45, "dir": Vector3(0, 0.25, 1), "spread": 22.0, "vmin": 1.2, "vmax": 3.5, "g": Vector3(0, -7, 0),
		"r": ln * 0.1, "smin": ln * 0.06, "smax": ln * 0.12, "pal": L.FROST, "foam": 0.6, "alpha": 0.85, "local": false})
	p.position = Vector3(0, 0, ln * 0.15)
	return p


# ================================================================== 1) Suiton: Mizu Arare
## Ref: iki avucun önünde beyaz yıldız patlaması, çevreye savrulan iri gözyaşı damlaları; ardından damla yağmuru.
static func suiton_mizu_arare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 1.2)
	pj.anim(c, "push", 1.0)
	L.gather(pj, (pj.hand_pos(c, true) + pj.hand_pos(c, false)) * 0.5 + c.face_dir() * 0.4, 0.9, 10, 0.2, 0.2)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var d0 = pj._face(c, tt)
		var palm = (pj.hand_pos(c, true) + pj.hand_pos(c, false)) * 0.5 + d0 * 0.35
		_arare_flash(pj, palm, d0)
		_arare_fan(pj, palm, d0)
		Sfx.play("water", c.global_position, 1.5)
		pj.every(0.9, 0.06, func(_i, _k):
			if not pj.live(c):
				return
			var from = (pj.hand_pos(c, true) + pj.hand_pos(c, false)) * 0.5 + d0 * 0.35
			var dd = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.14, 0.14)) + Vector3.UP * randf_range(-0.05, 0.07)
			var dm = L.wmi(L.drop_mesh(), {"alpha": 0.9, "line": 0.14, "flow": 4.0, "streak": 1.4, "neard": 2.5})
			dm.scale = Vector3.ONE * randf_range(0.5, 0.62)
			var dn = dd.normalized()
			pj.shot(c, from, dn, 36.0, dm, pj.inf(c, "suiton_mizu_arare", 0.085, {"knock": 1.5, "kind": "light", "element": "suiton"}), null, false, 1.0, func(p, _h):
				_arare_pop(pj, p, dn)), Callable()))


static func _arare_flash(h: Node, at: Vector3, d: Vector3) -> void:
	var st = _mi(_star_mesh(), _flatm("arare_star", Color(0.85, 0.95, 1.0, 0.95), true))
	L.put(h, st, at)
	_aim(st, d)
	st.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	st.scale = Vector3.ONE * 0.25
	var tw = st.create_tween()
	tw.tween_property(st, "scale", Vector3.ONE * 1.35, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "transparency", 1.0, 0.16)
	tw.parallel().tween_property(st, "scale", Vector3.ONE * 1.6, 0.16)
	tw.tween_callback(st.queue_free)


## Avuçtan yelpaze gibi açılan iri gözyaşı damlaları (süs; ref: çevreye saçılan damlalar)
static func _arare_fan(h: Node, at: Vector3, d: Vector3) -> void:
	var sd = d.cross(Vector3.UP).normalized()
	var up = sd.cross(d).normalized()
	for k in 11:
		var a = k * TAU / 11.0 + randf_range(-0.2, 0.2)
		var dir = (sd * cos(a) + up * sin(a) * 0.8 + d * randf_range(0.35, 0.8)).normalized()
		var dm = L.wmi(L.drop_mesh(), {"alpha": 0.88, "line": 0.15, "flow": 3.0, "neard": 2.0})
		L.put(h, dm, at + dir * 0.2)
		dm.scale = Vector3.ONE * randf_range(0.38, 0.62)
		_aim(dm, dir)
		var tw = dm.create_tween()
		tw.tween_property(dm, "global_position", at + dir * randf_range(1.6, 2.8), 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		L.fade_free(dm, 0.14, 0.2)


static func _arare_pop(h: Node, p: Vector3, d: Vector3) -> void:
	L.spray(h, p, -d + Vector3.UP * 0.7, {"n": 7, "spread": 55.0, "vmin": 2.0, "vmax": 4.5, "life": 0.4, "smin": 0.08, "smax": 0.14, "foam": 0.3, "g": Vector3(0, -12, 0)})
	if _near_ground(p, 1.4):
		L.puddle(h, p, randf_range(0.3, 0.45), 0.7, {"alpha": 0.5, "ripple": 0.0, "spread": 0.12})


# ================================================================== 2) Suiton: Suikōdan
## Hazırlık: ayak dibinden su sarmal olup avuca toplanır; mermi Jutsu.j_suiton_suikoudan (dev, çenesi açık su köpekbalığı)
static func suiton_suikoudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var at = c.global_position + Vector3.UP * 1.3 + d
	var g = pj.gp(c.global_position)
	L.ripple(pj, g, 0.3, 2.4, 0.5, {"foam": 0.9})
	for k in 3:   # yerden kalkan üç sarmal su kolu
		var hx = L.wmi(L.helix_mesh(0.9, 1.6, 1.3, 0.11, k * TAU / 3.0), {"alpha": 0.85, "line": 0.12, "flow": 4.0, "streak": 2.0, "neard": 2.5})
		L.put(pj, hx, g)
		hx.scale = Vector3(1.2, 0.3, 1.2)
		var tw = hx.create_tween().set_parallel(true)
		tw.tween_property(hx, "scale", Vector3(0.35, 1.0, 0.35), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(hx, "rotation:y", 2.4, 0.3)
		tw.chain().tween_callback(hx.queue_free)
	L.gather(pj, at, 1.4, 14, 0.3, 0.38)
	Jutsu.j_suiton_suikoudan(c, t)


## jutsu.gd j_suiton_suikoudan gövdesi (oynanış aynen): j = Jutsu otomatik yüklemesi
static func j_suiton_suikoudan(j, c: Node3D, t: Node3D) -> void:
	var m = j._mult(c) * j._elem_bonus(c, "suiton")
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = j._aim(c, t) * 15.0   # anime Kisame: köpekbalığı görünür hızla yüzerek gelir
	pr.radius = 1.2
	pr.life = 3.0
	pr.homing = t
	pr.homing_turn = 5.0
	pr.info = {"dmg": 34.0 * m, "element": "suiton", "knock": 14.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.07}
	var ln = 4.4   # ref: insan boyunun iki katından uzun
	var sk = _shark(ln, {"neard": 7.0})
	pr.add_child(sk)
	_shark_wake(sk, ln, 40)
	var ck = {"t": 0.0}
	pr.on_tick = func(_p: Projectile, dt: float) -> void:
		ck["t"] += dt
		var tt = float(ck["t"])
		_shark_pose(sk, tt, 0.32 + 0.22 * sin(tt * 6.0))
		sk.position.y = sin(tt * 3.0) * 0.12
		sk.rotation.z = sin(tt * 2.2) * 0.08
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		_suikoudan_burst(j, pos, pr.global_basis if is_instance_valid(pr) else Basis(), ln)
		Sfx.play("water", pos)
	j.get_tree().current_scene.add_child(pr)
	pr.global_position = j._hand(c)


## Isırış ve dağılış: çene kapanır, köpekbalığı şişip suya çözülür; büyük taç, sis, birikinti
static func _suikoudan_burst(h: Node, pos: Vector3, b: Basis, ln: float) -> void:
	var sh = _shark(ln, {"neard": 7.0})
	L.put(h, sh, pos)
	sh.global_basis = b.orthonormalized()
	var tw = sh.create_tween()
	tw.tween_method(func(v: float): _shark_pose(sh, v, 0.55 * (1.0 - v / 0.12)), 0.0, 0.12, 0.12)
	tw.tween_property(sh, "scale", Vector3(1.25, 1.35, 1.1), 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float): _fade_all(sh, v), 1.0, 0.0, 0.3)
	tw.tween_callback(sh.queue_free)
	var g = L.ground(pos)
	var fw = -b.z
	L.spray(h, pos, (fw + Vector3.UP).normalized(), {"n": 34, "spread": 70.0, "vmin": 4.0, "vmax": 9.0, "life": 0.8, "smin": 0.18, "smax": 0.34, "foam": 0.35, "r": 0.9})
	L.mist(h, pos + Vector3.UP * 0.4, 3.4, 1.1, {"tone": 0.0, "alpha": 0.4, "near": 5.0, "drift": Vector3.UP * 0.6})
	if _near_ground(pos, 3.0):
		L.crown(h, g, 2.4, {"h": 1.5, "foam": 0.35, "fall": 0.55})
		L.puddle(h, g, 2.8, 2.4, {"alpha": 0.55, "ripple": 0.4})
		L.ripple(h, g, 1.0, 5.0, 0.7, {"foam": 1.0})


# ================================================================== 3) Hoshigaki: Samehada köpekbalıkları
## Samehada (canlı kılıç) elde belirir, ağzı açılır; ağzından yedi su köpekbalığı fırlar, her biri ayrı bir düşmanı kovalar.
## ClanJutsu da çağırabilir: yalnız ClanJutsu yardımcıları kullanılır.
static func hoshigaki_same(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var list = pj.enemies_near(c, c.global_position, 30.0)
	var tt = pj.tg(c, t, 30.0)
	if tt and not tt in list:
		list.push_front(tt)
	_samehada_live(pj, c, Jutsu._aim(c, t))
	for k in 7:
		var target = list[k % list.size()] if not list.is_empty() else null
		var d = (Jutsu._aim(c, t)).rotated(Vector3.UP, (k - 3) * 0.28)
		var ln = 1.7
		var shark = _shark(ln, {"neard": 4.0})
		var pr = pj.shot(c, c.global_position + Vector3.UP * 1.2 + d, d, 22.0, shark, pj.inf(c, "hoshigaki_same", 0.5, {"knock": 8.0, "kind": "heavy"}), target, false, 3.0, func(p, _h):
			_same_bite(pj, p, d))
		shark.scale = Vector3.ONE * 0.3   # ağızdan çıkarken büyür
		var stw = shark.create_tween()
		stw.tween_property(shark, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		L.trail(shark, {"n": 14, "life": 0.35, "dir": Vector3(0, 0.2, 1), "spread": 25.0, "vmin": 1.0, "vmax": 2.5, "r": 0.15, "smin": 0.08, "smax": 0.15, "foam": 0.4, "local": false})
		var ck = {"t": randf()}
		pr.on_tick = func(_p, dt):
			ck["t"] += dt
			_shark_pose(shark, float(ck["t"]) * 1.3, 0.3 + 0.25 * absf(sin(float(ck["t"]) * 7.0)), 1.3)
	Sfx.play("water", c.global_position, 0.8)


## Samehada geçici olarak elde: pullu canlı kılıç (MistSwords modeli) — ağzı açılıp kapanır, ağzından su boşalır, sonra çekilir
static func _samehada_live(h: Node, c: Node3D, d0: Vector3) -> void:
	var d = _flat(d0)
	var b = MB.new()
	MistSwords.build("samehada_acik", b)
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var at = c.global_position + Vector3.UP * 1.25 + d * 0.35 + d.cross(Vector3.UP) * 0.25
	L.put(h, root, at)
	root.look_at(at - d, Vector3.UP)   # kılıç ağzı (+Z) ileri
	root.scale = Vector3.ONE * 0.5
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3(1.25, 1.05, 1.2), 0.1)   # ağız açılırken gövde kabarır
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.12)
	tw.tween_interval(0.45)
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	var mouth = at + d * 1.7
	L.spray(h, mouth, d + Vector3.UP * 0.15, {"n": 26, "spread": 35.0, "vmin": 4.0, "vmax": 9.0, "life": 0.5, "smin": 0.12, "smax": 0.24, "foam": 0.3})
	L.mist(h, mouth, 1.6, 0.6, {"tone": 0.0, "alpha": 0.35, "near": 3.0})


static func _same_bite(h: Node, p: Vector3, d: Vector3) -> void:
	L.spray(h, p, d + Vector3.UP * 0.4, {"n": 14, "spread": 60.0, "vmin": 2.5, "vmax": 6.0, "life": 0.5, "smin": 0.1, "smax": 0.2, "foam": 0.25})
	if _near_ground(p, 2.0):
		L.ripple(h, p, 0.3, 1.8, 0.45, {"foam": 0.9})


# ================================================================== 4) Araumi Shibuki
## Ref (Yagura "Rough Sea Spume"): sopa yere çarpar, önünden koyu lacivert, beyaz yalazlı bir dalga kabarır, ileri koşar ve rakibin üstüne kırılır.
static func araumi_shibuki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "araumi_shibuki"
	var tt = pj.tg(c, t, 18.0)
	var d = pj._face(c, tt)
	pj.anim(c, "slash_c", 1.4)
	var cw = weakref(c)
	var start: Vector3 = pj.gp(c.global_position + d * 1.5)
	var Lw = 11.0
	var sd = d.cross(Vector3.UP).normalized()
	pj.after(0.25, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		L.ripple(pj, start, 0.4, 3.2, 0.5, {"foam": 1.0})
		L.spray(pj, start + Vector3.UP * 0.2, d + Vector3.UP * 1.2, {"n": 20, "spread": 40.0, "vmin": 3.0, "vmax": 7.0, "life": 0.6, "smin": 0.14, "smax": 0.26, "pal": L.DEEP, "foam": 0.4})
		Sfx.play("water", start, 0.5)
		pj.shake(0.3)
		var wave = _wave_node(pj, start, d)
		var hitk = {}
		pj.every(0.7, 0.05, func(i, k):
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			var front: Vector3 = start + d * Lw * k
			var h = 1.0 + sin(k * PI) * 3.2   # dalga kabarır, sonra kırılır
			_wave_step(pj, wave, front, d, sd, h, k, i)
			for e in pj.enemies_near(c2, front, 2.6):
				var key = e.get_instance_id()
				if hitk.has(key):
					continue
				hitk[key] = true
				e.take_hit(pj.inf(c2, id, 1.6, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "element": "suiton", "hitstop": 0.08, "dir": d}))
				pj.st(e, "slow", 2.0), func():
			_wave_break(pj, wave, start + d * Lw, d, sd)))


## Kıvrık dudaklı tek kırılan dalga: kesitten süpürülmüş gerçek boy kütle (6 m geniş, 4.2 m boy), lacivert gövde + beyaz köpük
static func _wave_node(h: Node, at: Vector3, d: Vector3) -> Node3D:
	var mesh = _c("araumi_wave", func():
		var prof = [[-1.2, 0.0, 2.4], [-0.6, 1.4, 1.8], [-0.1, 2.8, 1.1], [0.5, 3.9, 0.7], [1.2, 4.15, 0.45], [1.8, 3.6, 0.3], [2.1, 2.9, 0.13], [2.15, 2.5, 0.02]]
		return _extrude_mesh(prof, 6.0, 26, 0.12, 1.3))
	var root = Node3D.new()
	L.put(h, root, at)
	_aim(root, d)
	var wm = L.wmi(mesh, {"pal": L.DEEP, "alpha": 0.9, "foam": 0.28, "line": 0.1, "streak": 2.2, "flow": -3.0, "neard": 7.0, "wob": 0.6})
	root.add_child(wm)
	root.scale = Vector3(1.0, 0.25, 0.8)
	# tepe köpüğü: dudaktan ileri savrulan beyaz serpinti
	var cr = L.trail(root, {"n": 60, "life": 0.55, "dir": Vector3(0, 0.6, -1), "spread": 35.0, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, -9, 0),
		"r": 2.6, "smin": 0.16, "smax": 0.3, "pal": L.FROST, "foam": 0.8, "alpha": 0.9, "local": false})
	cr.position = Vector3(0, 4.0, -1.4)
	root.set_meta("crest", cr)
	return root


static func _wave_step(h: Node, wave: Node3D, front: Vector3, d: Vector3, sd: Vector3, hh: float, k: float, i: int) -> void:
	if not is_instance_valid(wave):
		return
	var g = L.ground(front)
	wave.global_position = g + d * 0.6
	var tip = -0.55 * smoothstep(0.55, 1.0, k)   # ikinci yarıda dudak öne devrilir
	wave.global_basis = Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, tip)
	wave.scale = Vector3(1.0, hh / 4.2, lerpf(0.75, 1.15, k))
	if i % 3 == 0:   # geçtiği yerde köpüklü ıslak iz
		L.puddle(h, g - d * 1.2, 1.7, 2.2, {"dir": d, "stretch": 1.7, "alpha": 0.5, "foam": 0.3, "ripple": 0.25, "pal": L.DEEP})
	if i % 4 == 1:
		var side = sd * randf_range(-2.6, 2.6)
		L.spray(h, g + side + Vector3.UP * 0.3, -d + Vector3.UP * 0.8, {"n": 6, "spread": 30.0, "vmin": 1.5, "vmax": 3.5, "life": 0.45, "smin": 0.12, "smax": 0.2, "foam": 0.5})


## Kırılış: dudak yere çöker, ileri köpük perdesi, yayılan geniş birikinti
static func _wave_break(h: Node, wave: Node3D, at: Vector3, d: Vector3, sd: Vector3) -> void:
	var g = L.ground(at)
	if is_instance_valid(wave):
		var cr = wave.get_meta("crest", null)
		if cr != null and is_instance_valid(cr):
			cr.emitting = false
		_fade_out(wave, 0.0, 0.35, Vector3(1.1, 0.15, 1.3))
	for q in 5:
		var o = sd * (q - 2) * 1.2
		L.spray(h, g + o + Vector3.UP * 0.6, d * 1.2 + Vector3.UP * 0.5, {"n": 14, "spread": 30.0, "vmin": 3.0, "vmax": 7.0, "life": 0.6, "smin": 0.16, "smax": 0.3, "foam": 0.7, "pal": L.FROST})
	L.puddle(h, g + d * 1.5, 3.2, 2.6, {"dir": d, "stretch": 1.5, "alpha": 0.55, "foam": 0.35, "ripple": 0.35, "pal": L.DEEP})
	L.mist(h, g + Vector3.UP * 1.0 + d, 4.0, 1.2, {"tone": 0.0, "alpha": 0.35, "near": 6.0})


# ================================================================== 5) Sentō
## Yagura'nın sopasıyla üç su sarılı darbe (her biri sopanın yayında kalan su şeridi), sonra kancayla takıp başının üstünden arkaya fırlatış
## (kanca yayı boyunca su kavsi, fırlayan rakibin ardında su kuyruğu). Elinde Yagura'nın sopası olmalı.
static func sento(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.35)
	var id = "sento"
	pj._jump_at(c, tt, 0.0, 11.0 if tt and tt.global_position.distance_to(c.global_position) > 2.3 else 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var keys = ["slash_a", "slash_b", "slash_a"]
	for k in 3:   # su sarılı sopa darbeleri
		pj.after(0.1 + k * 0.22, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			if x != null and pj.live(x):
				pj._face(cc, x)
			pj.anim(cc, keys[k], 2.4)
			var p = _club_tip(pj, cc) + Vector3.UP * 0.2
			_club_ribbon(pj, cc, k)
			Sfx.play("water", p, 1.4)
			var hs = pj.hit(cc, p, 2.0, pj.inf(cc, id, 0.45, {"knock": 1.5, "kind": "light", "element": "suiton", "hitstop": 0.04}))
			if not hs.is_empty():
				_club_smack(pj, hs[0].global_position + Vector3.UP * 1.0, cc.face_dir(), 0.8))
	pj.after(0.82, func():   # kancayla takıp fırlatır
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		pj.anim(cc, "hook", 1.6)
		_hook_arc(pj, cc)
		if x != null and pj.live(x) and x.global_position.distance_to(cc.global_position) < 3.4:
			var back: Vector3 = -cc.face_dir()
			var xt = x.create_tween()   # kanca rakibi önünden yakalayıp başının üstünden arkaya savurur
			xt.tween_property(x, "global_position", cc.global_position + Vector3.UP * 2.4, 0.16)
			pj.after(0.17, func():
				var c2 = cw.get_ref()
				var x2 = tw.get_ref() if tw else null
				if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
					return
				_throw_tail(pj, x2, back)
				Sfx.play("swing_staff", x2.global_position, 0.8)
				x2.take_hit(pj.inf(c2, id, 1.5, {"knock": 26.0, "launch": 5.0, "kind": "heavy", "element": "suiton", "hitstop": 0.1, "dir": back})))
		else:
			var hs = pj.hit(cc, _club_tip(pj, cc), 2.2, pj.inf(cc, id, 1.0, {"knock": 18.0, "kind": "heavy", "element": "suiton"}))
			if not hs.is_empty():
				_club_smack(pj, hs[0].global_position + Vector3.UP * 1.0, cc.face_dir(), 1.2))


static func _club_tip(pj: PathJutsu, c: Node3D) -> Vector3:
	return pj.hand_pos(c) + c.face_dir() * 1.3


## Sopanın süpürdüğü yay boyunca kalan yassı su şeridi (dönerek dağılır) + uçtan teğet savrulan damlalar
static func _club_ribbon(h: Node, cc: Node3D, k: int) -> void:
	var fd: Vector3 = cc.face_dir()
	var sd = fd.cross(Vector3.UP).normalized()
	var sg = 1.0 if k % 2 == 0 else -1.0
	var ctr = cc.global_position + Vector3.UP * 1.2
	var pts = []
	var rad = []
	var n = 16
	for i in n:
		var u = i / float(n - 1)
		var an = lerpf(-1.25, 1.25, u) * sg
		pts.append(ctr + (fd * cos(an) + sd * sin(an)) * 1.85 + Vector3.UP * (0.25 - 0.5 * u) * sg)
		rad.append(0.17 * sin(PI * pow(u, 0.7)) + 0.01)
	var mi = L.wmi(L.tube_mesh(pts, rad, 6, 0.28, Vector3.UP), {"alpha": 0.85, "line": 0.12, "flow": 6.0, "streak": 3.0, "neard": 2.5})
	L.put(h, mi, Vector3.ZERO)
	var tw = mi.create_tween()
	tw.tween_interval(0.06)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.22)
	tw.tween_callback(mi.queue_free)
	var endp: Vector3 = pts[n - 1]
	var prev: Vector3 = pts[n - 3]
	L.spray(h, endp, (endp - prev).normalized() + Vector3.UP * 0.2, {"n": 12, "spread": 22.0, "vmin": 4.0, "vmax": 8.0, "life": 0.45, "smin": 0.1, "smax": 0.18})


static func _club_smack(h: Node, p: Vector3, d: Vector3, s: float) -> void:
	L.spray(h, p, d + Vector3.UP * 0.3, {"n": int(10 * s) + 4, "spread": 75.0, "vmin": 2.5, "vmax": 5.0 + s * 2.0, "life": 0.4, "smin": 0.1, "smax": 0.2, "foam": 0.45})
	L.mist(h, p, 0.9 * s + 0.5, 0.4, {"tone": 0.0, "alpha": 0.3, "near": 2.5})


## Kanca yayı: önden aşağıdan başın üstünden arkaya dikey su kavsi
static func _hook_arc(h: Node, cc: Node3D) -> void:
	var fd: Vector3 = cc.face_dir()
	var sd = fd.cross(Vector3.UP).normalized()
	var base = cc.global_position
	var pts = []
	var rad = []
	var n = 18
	for i in n:
		var u = i / float(n - 1)
		var an = lerpf(-0.3, PI + 0.4, u)
		pts.append(base + Vector3.UP * 1.3 + (fd * cos(an) + Vector3.UP * sin(an)) * 1.5)
		rad.append(0.2 * sin(PI * u) + 0.015)
	var mi = L.wmi(L.tube_mesh(pts, rad, 6, 0.35, sd), {"alpha": 0.85, "line": 0.12, "flow": -5.0, "streak": 3.0, "neard": 2.5})
	L.put(h, mi, Vector3.ZERO)
	L.fade_free(mi, 0.12, 0.3)


## Fırlayan rakibin ardında uzayan su kuyruğu + ilk savruluş serpintisi
static func _throw_tail(h: Node, x: Node3D, back: Vector3) -> void:
	L.spray(h, x.global_position + Vector3.UP * 1.0, back + Vector3.UP * 0.4, {"n": 22, "spread": 30.0, "vmin": 4.0, "vmax": 9.0, "life": 0.6, "smin": 0.14, "smax": 0.26, "foam": 0.3})
	var tr = L.trail(x, {"n": 30, "life": 0.4, "dir": Vector3(0, 0.3, 0), "spread": 80.0, "vmin": 0.5, "vmax": 1.5, "r": 0.35, "smin": 0.1, "smax": 0.2, "local": false})
	tr.position = Vector3.UP * 1.0
	var w = weakref(tr)
	h.get_tree().create_timer(0.6).timeout.connect(func():
		var p = w.get_ref()
		if p != null and is_instance_valid(p):
			p.emitting = false)
	L.free_later(h, tr, 1.2)


# ================================================================== 6) Suiton: Suijun
## Ref (Yagura su kalkanı): atılan su topu önünde dik duran, kendi çevresinde dönen sarmal su diskine açılır; gelen atışları yutar.
static func suiton_suijun(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "suiton_suijun"
	var tt = pj.tg(c, t, 18.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.6)
	var cw = weakref(c)
	var from: Vector3 = pj.hand_pos(c)
	var at: Vector3 = c.global_position + d * 2.2
	# atılan su topu
	var ball = L.wmi(L.sphere_mesh(), {"alpha": 0.9, "wob": 1.4, "line": 0.12, "flow": 3.0})
	L.put(pj, ball, from)
	ball.scale = Vector3.ONE * 0.45
	var bt = ball.create_tween()
	bt.tween_property(ball, "global_position", at + Vector3.UP * 1.1, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bt.tween_callback(ball.queue_free)
	Sfx.play("water", from, 1.2)
	var DUR = 3.5
	var disc = MeshInstance3D.new()
	disc.mesh = _disc_mesh(1.55)
	disc.material_override = _smat("suijun_disc", DISC_SHADER)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.set_instance_shader_parameter("seed", randf() * 10.0)
	disc.set_instance_shader_parameter("rad", 1.55)
	disc.visible = false
	L.put(pj, disc, c.global_position + d * 2.0 + Vector3.UP * 1.1)
	_aim(disc, d)
	pj.after(0.15, func():   # top açılır, sarmal su kalkanı
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if is_instance_valid(disc):
			disc.visible = true
			disc.scale = Vector3.ONE * 0.15
			var dt = disc.create_tween()
			dt.tween_property(disc, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var c0 = at + Vector3.UP * 1.1
		var sd0 = d.cross(Vector3.UP).normalized()
		for q in 8:   # disk düzleminde dışa açılan su halkası
			var a = q * TAU / 8.0
			L.spray(pj, c0, sd0 * cos(a) + Vector3.UP * sin(a) + d * 0.3, {"n": 5, "spread": 15.0, "vmin": 3.0, "vmax": 5.5, "life": 0.35, "smin": 0.1, "smax": 0.18})
		L.ripple(pj, pj.gp(at), 0.5, 3.4, 0.5, {"foam": 0.9})
		for e in pj.enemies_near(cc, at, 3.4):   # açılırken iter
			var v: Vector3 = e.global_position - cc.global_position
			v.y = 0
			e.take_hit(pj.inf(cc, id, 0.8, {"knock": 18.0, "launch": 2.0, "kind": "heavy", "element": "suiton", "dir": v.normalized() if v.length() > 0.1 else d}))
			pj.st(e, "wet", 6.0))
	var wall = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if is_instance_valid(disc):
			disc.global_position = cc.global_position + d * 2.0 + Vector3.UP * 1.1
			if i % 7 == 3:   # disk altından süzülen su
				L.spray(pj, disc.global_position + Vector3.DOWN * 1.2, Vector3.DOWN, {"n": 4, "spread": 25.0, "vmin": 0.5, "vmax": 1.5, "life": 0.4, "smin": 0.08, "smax": 0.14})
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != cc:
				var v: Vector3 = p.global_position - cc.global_position
				if v.length() < 3.0 and Vector3(v.x, 0, v.z).normalized().dot(d) > 0.3:
					_suijun_swallow(pj, disc, p.global_position, d)
					p.queue_free()
	pj.every(DUR, 0.05, wall, func():
		_suijun_collapse(pj, disc))
	var mods = {"armor": 0.55, "_name": "Suijun", "_desc": "su kalkanı önünde: gelen darbeler kesilir"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)


static func _suijun_swallow(h: Node, disc: Node3D, p: Vector3, d: Vector3) -> void:
	L.spray(h, p, -d + Vector3.UP * 0.3, {"n": 8, "spread": 50.0, "vmin": 1.5, "vmax": 3.5, "life": 0.35, "smin": 0.08, "smax": 0.15, "foam": 0.4})
	if is_instance_valid(disc):
		var tw = disc.create_tween()
		tw.tween_method(func(v: float): disc.set_instance_shader_parameter("pulse", v), 0.0, 1.0, 0.06)
		tw.tween_method(func(v: float): disc.set_instance_shader_parameter("pulse", v), 1.0, 0.0, 0.2)


## Kalkan çöker: disk dikeyde ezilip yere boşalır, birikinti kalır
static func _suijun_collapse(h: Node, disc: Node3D) -> void:
	if not is_instance_valid(disc):
		return
	var p = disc.global_position
	L.spray(h, p, Vector3.DOWN, {"n": 22, "spread": 60.0, "vmin": 1.0, "vmax": 3.0, "life": 0.55, "smin": 0.12, "smax": 0.22, "r": 1.0})
	L.puddle(h, p, 1.8, 2.0, {"alpha": 0.55, "ripple": 0.4})
	var tw = disc.create_tween()
	tw.tween_property(disc, "scale", Vector3(1.1, 0.05, 1.0), 0.25).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(disc, "global_position", p + Vector3.DOWN * 0.9, 0.25)
	tw.parallel().tween_method(func(v: float): disc.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.25)
	tw.tween_callback(disc.queue_free)


# ================================================================== 7) Suiton: Meikyō Shisui
## Ref (Kagura): sudan, kıpırtısız berrak bir ayna kabuğu önünde yükselir (eğik ışık şeritleri); atılanı yüzeyinde dalgacıkla durdurur.
static func suiton_meikyo_shisui(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var id = "suiton_meikyo_shisui"
	var d = pj._face(c, t)
	pj._yama_seal(c)
	var cw = weakref(c)
	var DUR = 4.0
	var cap = MeshInstance3D.new()
	cap.mesh = _cap_mesh(1.75)
	cap.material_override = _smat("meikyo_glass", GLASS_SHADER)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.set_instance_shader_parameter("seed", randf() * 10.0)
	L.put(pj, cap, c.global_position + Vector3.UP * 1.05 + d * 0.15)
	cap.global_basis = Basis.looking_at(d, Vector3.UP)
	cap.scale = Vector3(1, 0.03, 1)
	var mt = cap.create_tween()   # sudan dikilir
	mt.tween_property(cap, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var g0 = pj.gp(c.global_position + d * 1.2)
	L.ripple(pj, g0, 0.4, 2.4, 0.5, {"foam": 0.7})
	L.puddle(pj, g0, 1.7, DUR, {"alpha": 0.4, "ripple": 0.0, "spread": 0.2})   # kıpırtısız ayna suyu
	Sfx.play("water", c.global_position, 1.5)
	var cwk = weakref(cap)
	var ht = {"t": 9.0}
	var hold = func(i, _k):
		var cc = cw.get_ref()
		var mr = cwk.get_ref()
		if cc == null or mr == null or not pj.live(cc):
			return
		var fd: Vector3 = cc.face_dir()
		var sc = mr.scale
		mr.global_position = cc.global_position + Vector3.UP * 1.05 + fd * 0.15   # yapanla döner
		mr.global_basis = Basis.looking_at(fd, Vector3.UP).scaled(sc)
		ht["t"] = float(ht["t"]) + 0.04
		mr.set_instance_shader_parameter("hit_t", float(ht["t"]))
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != cc:
				var v: Vector3 = p.global_position - cc.global_position
				if v.length() < 2.6 and Vector3(v.x, 0, v.z).normalized().dot(fd) > 0.2:
					var lp: Vector3 = mr.to_local(p.global_position)
					mr.set_instance_shader_parameter("hit_l", lp.normalized() * 1.75 if lp.length() > 0.01 else Vector3(0, 0, -1.75))
					ht["t"] = 0.0
					L.spray(pj, p.global_position, Vector3.DOWN - fd * 0.3, {"n": 6, "spread": 25.0, "vmin": 0.6, "vmax": 1.6, "life": 0.5, "smin": 0.07, "smax": 0.12, "g": Vector3(0, -5, 0)})
					p.queue_free()
		if i % 25 == 0:
			L.ripple(pj, pj.gp(mr.global_position + fd * 1.2), 0.3, 1.4, 0.6, {"foam": 0.5, "alpha": 0.5})
	pj.every(DUR, 0.04, hold, func():
		var mr = cwk.get_ref()
		if mr != null and is_instance_valid(mr):
			L.spray(pj, mr.global_position + Vector3.UP * 0.4, Vector3.DOWN, {"n": 16, "spread": 70.0, "vmin": 0.8, "vmax": 2.2, "life": 0.5, "smin": 0.08, "smax": 0.15, "r": 1.2})
			var et = mr.create_tween()   # su yere iner
			et.tween_property(mr, "scale", Vector3(1.0, 0.03, 1.0), 0.3).set_ease(Tween.EASE_IN)
			et.parallel().tween_method(func(v: float): mr.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
			et.tween_callback(mr.queue_free))
	var mods = {"armor": 0.4, "_name": "Meikyō Shisui", "_desc": "su aynası önünde: atılanı durdurur, darbeleri keser"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)


# ================================================================== 8) Suiton: Teppunokyū
## Ref (Funamushi "Imminent Danger"): burgulu su sütunu, başında dönen mercek ve yana fırlayan kollar; sert dönüşlerle hedeften hedefe atlar.
static func suiton_teppunokyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "suiton_teppunokyu"
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.4)
	var cw = weakref(c)
	var list = pj.enemies_near(c, c.global_position, 24.0)
	list.sort_custom(func(a, b): return a.global_position.distance_to(c.global_position) < b.global_position.distance_to(c.global_position))
	if tt and tt in list:
		list.erase(tt)
		list.push_front(tt)
	var stops = []
	for e in list.slice(0, 4):
		stops.append(weakref(e))
	var s = {"p": pj.hand_pos(c) + d * 0.6, "v": d, "idx": 0, "hit": {}, "hist": []}
	Sfx.play("water", c.global_position, 0.8)
	var body = L.wmi(L.sphere_mesh(), {"alpha": 0.86, "line": 0.1, "flow": 8.0, "streak": 3.0, "neard": 6.0})
	L.put(pj, body, Vector3.ZERO)
	body.scale = Vector3.ONE * 0.001
	var foam = L.wmi(L.sphere_mesh(), {"alpha": 0.92, "pal": L.FROST, "line": 0.0, "flow": 6.0, "foam": 0.6, "neard": 6.0})
	L.put(pj, foam, Vector3.ZERO)
	foam.scale = Vector3.ONE * 0.001
	var head = L.wmi(_whirl_head_mesh(), {"alpha": 0.9, "line": 0.12, "flow": 5.0, "streak": 2.0, "neard": 6.0, "foam": 0.2})
	L.put(pj, head, s["p"])
	head.scale = Vector3.ONE * 0.2
	var run = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var goal: Vector3 = s["p"] + s["v"] * 3.0
		while s["idx"] < stops.size():
			var e = stops[s["idx"]].get_ref()
			if e != null and pj.live(e) and not s["hit"].has(e.get_instance_id()):
				goal = e.global_position + Vector3.UP * 1.0
				break
			s["idx"] += 1
		var to: Vector3 = goal - s["p"]
		var nv: Vector3 = to.normalized() if to.length() > 0.1 else s["v"]
		s["v"] = s["v"].lerp(nv, 0.55).normalized()   # keskin, kestirilemez dönüşler
		var a: Vector3 = s["p"]
		s["p"] = a + s["v"] * 26.0 * 0.03 + Vector3(0, sin(i * 0.7) * 0.12, 0)
		var b: Vector3 = s["p"]
		_teppu_draw(s, body, foam, head, b, i)
		if i % 3 == 0:
			L.spray(pj, b, -s["v"] + Vector3.UP * 0.3, {"n": 5, "spread": 60.0, "vmin": 2.0, "vmax": 4.5, "life": 0.4, "smin": 0.1, "smax": 0.18, "foam": 0.3})
		for e in pj.enemies_near(cc, b, 1.8):
			var key = e.get_instance_id()
			if s["hit"].has(key):
				continue
			s["hit"][key] = true
			_teppu_engulf(pj, e)
			e.take_hit(pj.inf(cc, id, 1.6, {"knock": 10.0, "launch": 3.0, "kind": "heavy", "element": "suiton", "hitstop": 0.05, "stun": 0.6, "dir": s["v"]}))
			pj.st(e, "wet", 6.0)
	pj.every(1.4, 0.03, run, func():
		if is_instance_valid(head):
			L.spray(pj, head.global_position, s["v"], {"n": 24, "spread": 80.0, "vmin": 3.0, "vmax": 7.0, "life": 0.6, "smin": 0.14, "smax": 0.26, "foam": 0.4})
			_fade_out(head, 0.0, 0.3, Vector3(1.5, 1.5, 0.3))
		_fade_out(body, 0.05, 0.35)
		_fade_out(foam, 0.0, 0.3))


## Akıntının gövdesi (son konumlar boyunca gerçek boy tüp) + çevresine dolanan iki beyaz köpük sarmalı + dönen baş
static func _teppu_draw(s: Dictionary, body: MeshInstance3D, foam: MeshInstance3D, head: MeshInstance3D, b: Vector3, i: int) -> void:
	var hist: Array = s["hist"]
	hist.append(b)
	if hist.size() > 22:
		hist.pop_front()
	var n = hist.size()
	if n >= 3 and is_instance_valid(body):
		var rad = []
		for j in n:
			var u = j / float(n - 1)
			rad.append(lerpf(0.12, 0.62, u * u) * (1.0 + 0.1 * sin(j * 1.3 + i * 0.8)))
		body.mesh = L.tube_mesh(hist, rad, 12)
		body.scale = Vector3.ONE
		if is_instance_valid(foam):
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var vc = 0
			for q in 2:
				var fp = []
				var fr = []
				for j in n:
					var p: Vector3 = hist[j]
					var nx: Vector3 = hist[mini(j + 1, n - 1)]
					var pv: Vector3 = hist[maxi(j - 1, 0)]
					var tv = (nx - pv)
					tv = tv.normalized() if tv.length() > 0.001 else Vector3.FORWARD
					var sd = tv.cross(Vector3.UP)
					sd = sd.normalized() if sd.length() > 0.01 else Vector3.RIGHT
					var up = sd.cross(tv).normalized()
					var an = j * 0.95 - i * 0.6 + q * PI
					var rr = float(rad[j]) * 1.05
					fp.append(p + (sd * cos(an) + up * sin(an)) * rr)
					fr.append(0.07 * sin(PI * j / float(n - 1)) + 0.01)
				vc = L.tube_into(st, vc, fp, fr, 5)
			st.generate_normals()
			foam.mesh = st.commit()
			foam.scale = Vector3.ONE
	if is_instance_valid(head):
		head.global_position = b
		_aim(head, s["v"])
		head.rotate_object_local(Vector3.FORWARD, i * 0.55)
		head.scale = Vector3.ONE * minf(1.0, 0.2 + i * 0.12)


## Yakalanan rakibi bir an saran dönen su sarmalı
static func _teppu_engulf(h: Node, e: Node3D) -> void:
	var g = L.ground(e.global_position)
	var hx = L.wmi(L.helix_mesh(0.75, 2.3, 2.2, 0.14), {"alpha": 0.88, "line": 0.12, "flow": 6.0, "streak": 2.5, "neard": 2.5})
	L.put(h, hx, g)
	var tw = hx.create_tween().set_parallel(true)
	tw.tween_property(hx, "rotation:y", TAU, 0.6)
	tw.tween_property(hx, "scale", Vector3(1.4, 1.1, 1.4), 0.6)
	tw.tween_method(func(v: float): hx.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(hx.queue_free)
	L.spray(h, e.global_position + Vector3.UP, Vector3.UP, {"n": 14, "spread": 90.0, "vmin": 2.0, "vmax": 5.0, "life": 0.5, "smin": 0.1, "smax": 0.2, "r": 0.5})


# ================================================================== 9) Suiton: Suishō
## Ref (Funamushi "Jadeite"): uzatılan avuçtan çıkan, ileri genişleyen dev yatay su seli; üstünden tırtıklı beyaz köpük halkaları akar.
static func suiton_suisho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "suiton_suisho"
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.5)
	var cw = weakref(c)
	Sfx.play("water", c.global_position, 1.1)
	L.gather(pj, pj.hand_pos(c) + d * 0.3, 0.8, 8, 0.12, 0.0)
	pj.after(0.12, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var from: Vector3 = pj.hand_pos(cc) + d * 0.3
		var Ls = 13.0
		_suisho_torrent(pj, from, d, Ls)
		var hits = Combat.hit_zone(cc, pj.gp(cc.global_position), d, Ls, 14.0, 2.8, pj.inf(cc, id, 1.9, {"knock": 30.0, "launch": 2.0, "kind": "heavy", "element": "suiton", "hitstop": 0.06, "dir": d}))
		for e in hits:
			pj.st(e, "wet", 6.0)
			L.crown(pj, L.ground(e.global_position), 1.3, {"h": 1.3, "foam": 0.4})
			L.spray(pj, e.global_position + Vector3.UP, d + Vector3.UP * 0.4, {"n": 14, "spread": 40.0, "vmin": 4.0, "vmax": 8.0, "life": 0.5, "smin": 0.14, "smax": 0.24}))


static func _suisho_torrent(h: Node, from: Vector3, d: Vector3, ln: float) -> void:
	var mesh = _c("suisho_torrent", func():
		var pts = []
		var rad = []
		var n = 24
		for i in n:
			var u = i / float(n - 1)
			pts.append(Vector3(0, 0, -u * ln))
			rad.append(lerpf(0.3, 2.1, pow(u, 0.7)) * (1.0 + 0.07 * sin(u * 23.0)) * (1.0 if u < 0.96 else 0.6))
		return L.tube_mesh(pts, rad, 22, 0.72, Vector3.RIGHT))
	var root = Node3D.new()
	L.put(h, root, from)
	_aim(root, d)
	var tm = L.wmi(mesh, {"alpha": 0.9, "line": 0.09, "flow": 7.0, "streak": 3.2, "foam": 0.12, "wob": 0.6, "neard": 8.0})
	root.add_child(tm)
	root.scale = Vector3(0.6, 0.6, 0.05)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.35)
	tw.tween_property(root, "scale", Vector3(0.5, 0.35, 1.05), 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): tm.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4)
	tw.tween_callback(root.queue_free)
	for k in 4:   # akışla ileri kayan tırtıklı köpük halkaları
		var z = 2.4 + k * 2.9
		var rr = lerpf(0.3, 2.1, pow(z / ln, 0.7)) * 1.07
		var ring = L.wmi(_jag_ring_mesh(snappedf(rr, 0.1), k), {"alpha": 0.95, "pal": L.FROST, "foam": 0.7, "line": 0.06, "flow": 3.0, "neard": 6.0})
		root.add_child(ring)
		ring.position = Vector3(0, 0, -z)
		ring.visible = false
		var rt = ring.create_tween()
		rt.tween_interval(0.04 + k * 0.03)
		rt.tween_callback(ring.show)
		rt.tween_property(ring, "position:z", -z - 1.8, 0.5)
		rt.parallel().tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
	var end = from + d * ln
	h.get_tree().create_timer(0.14).timeout.connect(func():
		L.spray(h, end, d + Vector3.UP * 0.5, {"n": 30, "spread": 55.0, "vmin": 4.0, "vmax": 9.0, "life": 0.7, "smin": 0.18, "smax": 0.32, "r": 1.6, "foam": 0.3})
		L.puddle(h, from + d * ln * 0.55, 2.4, 2.4, {"dir": d, "stretch": 2.4, "alpha": 0.5, "ripple": 0.3}))


# ================================================================== 10) Suiton: Gōsuikyaku no Jutsu
## Ref (Suigetsu): su bacaklara iner, uyluk kasları suyla şişer (gerçek kemik), düz hatta sıçrayıp ezici tekme; çarpışta öne açılan su konisi.
static func suiton_gosuikyaku_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	var id = "suiton_gosuikyaku_no_jutsu"
	var m = c.get("model")
	var ov = m.overlay if m and m.get("overlay") else null
	if c is Player:
		Buffs.add("gosuikyaku", 10.0, {"speed": 1.25, "melee": 1.2, "_name": "Gōsuikyaku", "_desc": "su pompalanmış bacak kasları"})
	elif c.has_method("add_buff"):
		c.add_buff("gosuikyaku", 10.0, {"speed": 1.25, "melee": 1.2})
	if ov:
		var bones = ["RightUpperLeg", "LeftUpperLeg"]
		var setb = func(x: float):
			if is_instance_valid(m) and m.get("overlay"):
				for bn in bones:
					m.overlay.bulk[bn] = x
		var tw = c.create_tween()
		tw.tween_method(setb, 1.0, 2.1, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(9.4)
		tw.tween_method(setb, 2.1, 1.0, 0.3)
		tw.tween_callback(func():
			if is_instance_valid(m) and m.get("overlay"):
				for bn in bones:
					m.overlay.bulk.erase(bn))
	for k in 12:   # gövdeden bacaklara süzülen su boncukları
		var q = Vector3(randf_range(-0.3, 0.3), randf_range(0.9, 1.5), randf_range(-0.25, 0.25))
		var foot = Vector3(0.18 if k % 2 == 0 else -0.18, 0.35, 0.0)
		pj.after(k * 0.02, func():
			if pj.live(c):
				var bd = L.wmi(L.sphere_mesh(), {"alpha": 0.9, "line": 0.16, "flow": 3.0})
				c.add_child(bd)
				bd.position = q
				bd.scale = Vector3(0.07, 0.12, 0.07)
				var bt = bd.create_tween()
				bt.tween_property(bd, "position", foot, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				bt.tween_callback(bd.queue_free))
	pj.after(0.27, func():
		if pj.live(c):
			L.ripple(pj, pj.gp(c.global_position), 0.2, 1.3, 0.4, {"foam": 0.8}))
	pj.every(10.0, 0.5, func(_i, _k):   # şişkin bacaklardan damlayan su
		if pj.live(c):
			L.spray(pj, c.global_position + Vector3.UP * 0.5, Vector3.DOWN, {"n": 3, "spread": 40.0, "vmin": 0.3, "vmax": 1.0, "life": 0.4, "smin": 0.06, "smax": 0.1, "r": 0.25}))
	pj.busy(c, 0.85)
	pj.anim(c, "crouch", 2.0)
	Sfx.play("water", c.global_position, 1.3)
	var cw = weakref(c)
	var tw2 = weakref(tt) if tt else null
	var go = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw2.get_ref() if tw2 else null
		var g0 = pj.gp(cc.global_position)
		var d = pj._jump_at(cc, x if x != null and pj.live(x) else null, 1.5, 44.0)   # düz hatta sıçrama
		pj._kick_pose(cc, 0.45)
		Sfx.play("whoosh", cc.global_position, 0.8)
		L.spray(pj, g0 + Vector3.UP * 0.2, -d + Vector3.UP * 0.7, {"n": 20, "spread": 35.0, "vmin": 4.0, "vmax": 8.0, "life": 0.55, "smin": 0.12, "smax": 0.22, "foam": 0.3})
		L.ripple(pj, g0, 0.3, 2.4, 0.5, {"foam": 1.0})
		var s = {"hit": false}
		var fly = func(i, _k):
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2) or s["hit"]:
				return
			if i % 2 == 0:
				L.spray(pj, c2.global_position + Vector3.UP * 0.6, -d + Vector3.UP * 0.15, {"n": 3, "spread": 25.0, "vmin": 1.5, "vmax": 3.0, "life": 0.35, "smin": 0.08, "smax": 0.14})
			var hs = pj.hit(c2, c2.global_position + Vector3.UP * 1.0 + d * 1.4, 1.9, pj.inf(c2, id, 3.2, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.14, "melee": true, "stun": 0.8}))
			if hs.size() > 0:
				s["hit"] = true
				if c2 is CharacterBody3D:
					c2.velocity = Vector3.ZERO
				var o: Vector3 = hs[0].global_position + Vector3.UP * 1.0
				_kick_cone(pj, o, d)
				pj.shake(0.6)
				Sfx.play("punch", o, 0.6)
		pj.every(0.4, 1.0 / 60.0, fly, Callable())
	pj.after(0.32, go)


## Tekme çarpışı: tekme yönünde açılan sıvı su konisi (taç, ekseni ileri) + ileri serpinti
static func _kick_cone(h: Node, o: Vector3, d: Vector3) -> void:
	var cn = L.wmi(L.liquid_crown_mesh(randi() % 4), {"alpha": 0.88, "foam": 0.25, "wob": 1.0, "line": 0.12, "flow": 3.0, "neard": 3.0})
	L.put(h, cn, o)
	var y = d.normalized()
	var x = y.cross(Vector3.UP)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	var z = x.cross(y).normalized()
	var b0 = Basis(x, y, z)
	cn.global_basis = b0.scaled(Vector3(0.3, 0.1, 0.3))
	var tw = cn.create_tween()
	tw.tween_method(func(v: float): cn.set_global_basis(b0.scaled(Vector3(lerpf(0.3, 1.5, v), lerpf(0.1, 1.3, v), lerpf(0.3, 1.5, v)))), 0.0, 1.0, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): cn.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(cn.queue_free)
	L.spray(h, o, d + Vector3.UP * 0.4, {"n": 26, "spread": 40.0, "vmin": 5.0, "vmax": 10.0, "life": 0.55, "smin": 0.14, "smax": 0.26, "foam": 0.3})


# ================================================================== 11) Mizu Tatsumaki
## Ref (Shibuki / Tobirama): kullanıcının çevresinde yükselen, yatay bulanık şeritlerle dönen camgöbeği su hortumu; dışarıdan atılan giremez.
static func mizu_tatsumaki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.2)
	var id = "mizu_tatsumaki"
	pj._yama_seal(c)
	Sfx.play("water", c.global_position, 0.7)
	var cw = weakref(c)
	var R := 2.6
	var H := 5.0
	var root = Node3D.new()
	L.put(pj, root, pj.gp(c.global_position))
	var mat = _smat("tatsumaki", TORNADO_SHADER)
	var outer = _mi(_tornado_mesh(R, H), mat)
	outer.set_instance_shader_parameter("seed", randf() * 10.0)
	outer.set_instance_shader_parameter("hgt", H)
	root.add_child(outer)
	var inner = _mi(_tornado_mesh(R * 0.78, H * 0.95), mat)
	inner.set_instance_shader_parameter("seed", randf() * 10.0)
	inner.set_instance_shader_parameter("hgt", H * 0.95)
	inner.set_instance_shader_parameter("spd", 1.4)
	root.add_child(inner)
	root.scale = Vector3(0.3, 0.25, 0.3)
	var spin = func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var g = pj.gp(cc.global_position)
		if "velocity" in cc:
			cc.velocity = Vector3.ZERO
		var grow = minf(1.0, k * 5.0) * (1.0 if k < 0.85 else (1.0 - k) / 0.15)
		if is_instance_valid(root):
			root.global_position = g
			root.scale = Vector3(maxf(0.3, grow), maxf(0.25, grow), maxf(0.3, grow))
			outer.rotation.y += 0.35
			inner.rotation.y -= 0.22
		if i % 3 == 0:   # dipte teğet savrulan su
			var a = randf() * TAU
			L.spray(pj, g + Vector3(cos(a) * R, 0.3, sin(a) * R), Vector3(-sin(a), 0.9, cos(a)), {"n": 6, "spread": 25.0, "vmin": 3.0, "vmax": 6.0, "life": 0.5, "smin": 0.12, "smax": 0.2, "pal": L.SOAP, "foam": 0.3})
		if i % 8 == 0:
			L.ripple(pj, g, R * 0.8, R * 1.5, 0.5, {"foam": 0.8, "alpha": 0.6})
		if i % 4 == 0:
			for e in pj.enemies_near(cc, g, R + 0.9):
				var v: Vector3 = e.global_position - g
				v.y = 0.0
				e.take_hit(pj.inf(cc, id, 0.27, {"knock": 7.0, "launch": 3.0, "kind": "heavy", "element": "suiton", "hitstop": 0.02, "dir": v.normalized()}))
				pj.st(e, "wet", 6.0)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):   # girdap bariyerdir: dışarıdan atılan içeri giremez
			if is_instance_valid(p) and p.get("shooter") != cc:
				var pv: Vector3 = p.global_position - g
				if Vector2(pv.x, pv.z).length() < R + 0.5 and pv.y < H:
					L.spray(pj, p.global_position, Vector3(pv.x, 0.3, pv.z).normalized(), {"n": 8, "spread": 40.0, "vmin": 2.0, "vmax": 4.0, "life": 0.4, "smin": 0.1, "smax": 0.16, "pal": L.SOAP})
					p.queue_free()
	var burst = func():
		if is_instance_valid(root):
			var ct = root.create_tween()   # sütun dışa yıkılır
			ct.tween_property(root, "scale", Vector3(1.6, 0.05, 1.6), 0.35).set_ease(Tween.EASE_IN)
			ct.parallel().tween_method(func(v: float): _fade_all(root, v), 1.0, 0.0, 0.35)
			ct.tween_callback(root.queue_free)
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var g = pj.gp(cc.global_position)
		L.ripple(pj, g, 1.0, 9.0, 0.6, {"foam": 1.0})
		for k in 8:
			var a = k * TAU / 8.0
			L.spray(pj, g + Vector3(cos(a), 0.2, sin(a)) * 2.0, Vector3(cos(a), 0.8, sin(a)), {"n": 10, "spread": 30.0, "vmin": 4.0, "vmax": 8.0, "life": 0.6, "smin": 0.14, "smax": 0.26, "pal": L.SOAP, "foam": 0.3})
		L.puddle(pj, g, 3.6, 3.0, {"alpha": 0.5, "ripple": 0.45})
		for e in pj.enemies_near(cc, g, R + 2.0):
			var v: Vector3 = e.global_position - g
			v.y = 0.0
			e.take_hit(pj.inf(cc, id, 0.7, {"knock": 16.0, "launch": 5.0, "kind": "heavy", "element": "suiton", "hitstop": 0.08, "stun": 1.0, "dir": v.normalized()}))
		Sfx.play("water", g, 0.5)
	pj.every(2.0, 0.05, spin, burst)
	L.free_later(pj, root, 4.0)


# ================================================================== 12) Dekisui Suihō no Jutsu
## Ref (Suigetsu): koldan kopan su boncuk boncuk hedefin başına akar, başı saran yumru bir su kesesine dönüşür; içinde kaçan hava kabarcıkları.
static func dekisui_suiho_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Dekisui Suihō: suyun saracağı hedef yok", Color(0.6, 0.85, 1.0))
		return
	pj.busy(c, 0.7)
	var id = "dekisui_suiho_no_jutsu"
	pj._face(c, tt)
	pj.anim(c, "push", 1.4)
	Sfx.play("water", c.global_position, 1.4)
	var cw = weakref(c)
	var tw = weakref(tt)
	var head_of = func(x: Node3D) -> Vector3:
		return x.global_position + Vector3.UP * (float(x.height) * 0.9 if "height" in x else 1.6)
	var from = pj.hand_pos(c)
	for k in 3:   # koldan kopan su: boncuk dizisi kavis çizerek başa akar
		pj.after(k * 0.05, func():
			var x = tw.get_ref()
			if x != null and pj.live(x):
				var to: Vector3 = head_of.call(x)
				var mid = (from + to) * 0.5 + Vector3.UP * (0.6 + k * 0.25) + (to - from).cross(Vector3.UP).normalized() * (k - 1) * 0.5
				for b in 7:
					var bd = L.wmi(L.sphere_mesh(), {"alpha": 0.9, "line": 0.15, "flow": 3.0, "wob": 1.0})
					L.put(pj, bd, from)
					bd.scale = Vector3.ONE * lerpf(0.16, 0.09, b / 6.0)
					var bt = bd.create_tween()
					bt.tween_interval(b * 0.025)
					bt.tween_method(func(u: float): bd.set_global_position(from.lerp(mid, u).lerp(mid.lerp(to, u), u)), 0.0, 1.0, 0.24).set_ease(Tween.EASE_IN)
					bt.tween_callback(bd.queue_free))
	var wrap = func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		var blob = Node3D.new()
		var bm = L.wmi(_blob_mesh(), {"alpha": 0.55, "line": 0.08, "flow": 0.8, "streak": 0.6, "wob": 1.8, "neard": 1.5})
		blob.add_child(bm)
		blob.scale = Vector3.ONE * 0.3
		pj.attach(x, blob, 4.2, Vector3.UP * (float(x.height) * 0.9 if "height" in x else 1.6), 1)
		var gt = blob.create_tween()
		gt.tween_property(blob, "scale", blob.scale / 0.3, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Combat.popup_text(x.global_position + Vector3.UP * 2.6, "Nefes alamıyor!", Color(0.6, 0.85, 1.0))
		pj.st(x, "slow", 4.2)
		pj.st(x, "sealed", 4.2)   # nefessiz teknik atılamaz
		var bw = weakref(blob)
		var choke = func(i, _k):
			var c2 = cw.get_ref()
			var x2 = tw.get_ref()
			var b2 = bw.get_ref()
			if b2 == null or not b2.visible:
				return
			# su, kullanıcıdan uzaklaşınca ya da kullanıcı düşünce dağılır
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2) or c2.global_position.distance_to(x2.global_position) > 15.0:
				if x2 != null and is_instance_valid(x2):
					_blob_burst(pj, head_of.call(x2))
				b2.visible = false
				return
			if i % 2 == 0:   # ağızdan kaçan hava kabarcıkları
				var hp: Vector3 = head_of.call(x2)
				L.bubble(pj, hp + Vector3(randf_range(-0.12, 0.12), randf_range(-0.15, 0.05), randf_range(-0.12, 0.12)), randf_range(0.05, 0.09), 0.5, Vector3(0, 0.5, 0), false)
			if i % 4 == 3:
				x2.take_hit(pj.inf(c2, id, 0.2, {"knock": 0.0, "launch": 0.0, "kind": "crush", "element": "suiton", "hitstop": 0.0, "pierce": true}))
		var faint = func():
			var x2 = tw.get_ref()
			var b2 = bw.get_ref()
			if x2 != null and pj.live(x2) and b2 != null and b2.visible:
				pj.st(x2, "stun", 2.0)   # sonuna dek tutulursa bayılır
				_blob_burst(pj, head_of.call(x2))
				Combat.popup_text(x2.global_position + Vector3.UP * 2.6, "Bayıldı!", Color(0.6, 0.85, 1.0))
		pj.every(4.0, 0.1, choke, faint)
	pj.after(0.3, wrap)


## Kese patlar: su başın çevresinden aşağı dökülür, ayak dibinde birikinti
static func _blob_burst(h: Node, p: Vector3) -> void:
	L.spray(h, p, Vector3.DOWN, {"n": 20, "spread": 85.0, "vmin": 1.0, "vmax": 3.0, "life": 0.6, "smin": 0.1, "smax": 0.2, "r": 0.35})
	L.puddle(h, p, 0.9, 1.6, {"alpha": 0.5, "ripple": 0.3})


# ================================================================== 13) Suiton: Senshokukō
## Ref (Kisame "Bin Köpekbalığı"): ağzından boşalan, 30 m genişliğinde dik lacivert su duvarı; tepesinde ve içinde onlarca köpekbalığı yüzer,
## arkasında alçak sel; değdiğini sürükler ve ısırır. ClanJutsu da çağırabilir: yalnız ClanJutsu yardımcıları.
static func suiton_senshokuko(pj: ClanJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	var root = Node3D.new()
	L.put(pj, root, pj.gp(c.global_position + d * 4.0))
	_aim(root, d)
	# yuvarlak, yuvarlanan dalga cephesi: kameraya (arkaya) bakan yüz alçak ve uzun eğimli, ön yüzde kıvrık dudak.
	# tepe çizgisi yalnız çok yavaş dalgalanır (sivri dağ yok); köpük = dudak boyunca ayrı ince beyaz şerit (kamuflaj lekesi yok)
	var wall_m = _c("senshoku_wall2", func():
		var prof = [[-5.0, 0.0, 0.6], [-3.6, 0.55, 1.0], [-2.3, 1.35, 1.3], [-1.2, 2.2, 1.25], [-0.3, 2.8, 1.0], [0.5, 3.05, 0.75],
			[1.15, 2.85, 0.5], [1.55, 2.35, 0.28], [1.65, 1.95, 0.08]]
		return _extrude_mesh(prof, 30.0, 64, 0.07, 0.7, 0.2))
	var crest_m = _c("senshoku_crest2", func():
		var pts = []
		var rad = []
		var nx = 64
		for q in nx + 1:
			var u = float(q) / nx
			var x = -15.0 + 30.0 * u
			var e = maxf(0.04, pow(clampf(sin(PI * u), 0.0, 1.0), 0.35))
			var js = 1.0 + 0.07 * (sin(x * 0.18 + 0.7) * 0.6 + sin(x * 0.46 + 1.19) * 0.4)
			pts.append(Vector3(x, 3.1 * e * js, -0.6 * lerpf(0.6, 1.0, e)))
			rad.append((0.16 + 0.07 * sin(x * 1.9) + 0.04 * sin(x * 4.3)) * e)
		return L.tube_mesh(pts, rad, 8, 0.7, Vector3.UP))
	var wall = L.wmi(wall_m, {"pal": L.DEEP, "alpha": 0.86, "foam": 0.0, "line": 0.08, "streak": 3.0, "flow": 2.5, "wob": 0.25, "neard": 9.0})
	root.add_child(wall)
	var crest = L.wmi(crest_m, {"pal": L.FROST, "alpha": 0.95, "foam": 0.0, "line": 0.05, "streak": 2.0, "flow": 3.0, "wob": 0.6, "neard": 9.0})
	root.add_child(crest)
	var crs = []   # dudak boyunca dizili küçük serpinti kaynakları (tek dev küre önplana da saçıyordu)
	for q in 7:
		var e1 = L.trail(root, {"n": 18, "life": 0.55, "dir": Vector3(0, 0.8, -0.6), "spread": 30.0, "vmin": 2.0, "vmax": 4.5, "g": Vector3(0, -9, 0),
			"r": 1.2, "smin": 0.16, "smax": 0.3, "pal": L.FROST, "foam": 0.0, "alpha": 0.9, "local": false})
		e1.position = Vector3((q - 3) * 4.0, 3.0, -0.7)
		crs.append(e1)
	root.scale = Vector3(0.2, 0.2, 0.2)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	var sharks = []
	for k in 22:
		var s = _shark(randf_range(1.6, 2.1), {"neard": 4.0, "alpha": 0.9})
		L.put(pj, s, root.global_position)
		sharks.append([s, randf_range(-13, 13), randf_range(0.5, 4.5), randf_range(-3.5, 3.5), randf() * TAU])
	pj.busy(c, 0.8)
	_slowmo(pj, 0.55, 0.35)
	var bitten = {}
	pj.every(2.4, 1.0 / 30.0, func(i, k):
		var center = pj.gp(c.global_position + d * (4.0 + k * 30.0))
		if is_instance_valid(root):
			root.global_position = center
		for sh in sharks:
			var ph = i * 0.18 + sh[4]
			var p = center + side * (sh[1] + sin(ph) * 1.5) + Vector3.UP * (sh[2] + sin(ph * 1.7) * 0.6) + d * (sh[3] + cos(ph) * 1.2)
			if is_instance_valid(sh[0]):
				sh[0].look_at(p + d + side * cos(ph) * 0.5, Vector3.UP)
				sh[0].global_position = p
				_shark_pose(sh[0], i * 0.033, 0.25 + 0.3 * absf(sin(ph * 2.0)), 1.4)
		if i % 3 == 0:
			L.spray(pj, center + side * randf_range(-13, 13) + Vector3.UP * 2.9 + d * 0.6, d + Vector3.UP * 1.2, {"n": 8, "spread": 30.0, "vmin": 3.0, "vmax": 6.0, "life": 0.5, "smin": 0.16, "smax": 0.28, "pal": L.FROST, "foam": 0.0})
		if i % 6 == 0:
			L.puddle(pj, center - d * 3.5 + side * randf_range(-11, 11), 1.8, 1.2, {"dir": d, "stretch": 1.4, "alpha": 0.3, "ripple": 0.2})
		for e in pj.enemies_near(c, center, 15.0):
			var v = e.global_position - center
			if absf(v.dot(d)) < 5.0:
				e.global_position = pj.gp(e.global_position + d * 0.5)   # sel sürükler
				pj.st(e, "slow", 0.4)
				var key = e.get_instance_id()
				if Time.get_ticks_msec() - int(bitten.get(key, 0)) > 400:
					bitten[key] = Time.get_ticks_msec()
					pj.hit(c, e.global_position + Vector3.UP, 1.0, pj.inf(c, "suiton_senshokuko", 0.18, {"knock": 3.0, "kind": "light", "element": "suiton"})), func():
		for sh in sharks:
			if is_instance_valid(sh[0]):
				_fade_out(sh[0], 0.0, 0.3)
		if is_instance_valid(root):
			for e1 in crs:
				if is_instance_valid(e1):
					e1.emitting = false
			_fade_out(root, 0.0, 0.5, Vector3(1.0, 0.15, 1.2)))
	pj.shake(0.8)
	Sfx.play("water", c.global_position, 0.4)


# ================================================================== 14) Suiton: Suikōsandan no Jutsu
## Ref (Kisame "Water Shark Shotgun"): art arda köpekbalıkları yerin içinden yüzer (yalnız sırt yüzgeci ve V dalgası görünür),
## hedefe varınca yerden fırlayıp ağzı açık tepesine iner.
static func suiton_suikosandan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 1.0)
	var id = "suiton_suikosandan_no_jutsu"
	var d = pj._face(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	pj.anim(c, "push", 1.4)
	Sfx.play("water", c.global_position, 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var aim0: Vector3 = pj.gp(tt.global_position) if tt else pj.gp(c.global_position + d * 12.0)
	L.ripple(pj, pj.gp(c.global_position + d * 1.2), 0.4, 2.6, 0.5, {"foam": 1.0})
	for k in 5:
		var one = func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var ln = 2.2
			var sh = _shark(ln, {"neard": 4.5})
			var from: Vector3 = pj.gp(cc.global_position + d * 1.2 + side * (k - 2) * 0.55)
			pj.scene_add(sh, from)
			var ph = k * 1.3
			var s = {"last": from, "out": false}
			var sink = _sr(0.36) * ln * 0.85 + 0.06   # gövde yerin altında: yalnız sırt yüzgeci dışarıda
			var swim = func(i, u):
				if not is_instance_valid(sh):
					return
				var x = tw.get_ref() if tw else null
				var to: Vector3 = pj.gp(x.global_position) if x != null and pj.live(x) else aim0
				var dir0: Vector3 = to - from
				dir0.y = 0.0
				var Lr = dir0.length()
				var dn = dir0.normalized() if Lr > 0.1 else d
				var sd = dn.cross(Vector3.UP)
				var a: Vector3 = from + dn * maxf(0.0, Lr - 2.8)
				a.y = Game.jutsu_floor(a.x, a.z)
				var p: Vector3
				if u < 0.62:   # yerin içinden: yalnız sırt yüzgeci görünür
					var q = u / 0.62
					p = from.lerp(a, q) + sd * sin(q * 7.0 + ph) * 0.7 * (1.0 - q)
					p.y = Game.jutsu_floor(p.x, p.z) - sink
					_shark_pose(sh, i * 0.025, 0.0, 1.5)
					if i % 2 == 0:   # yüzgecin açtığı V dalgası
						L.ripple(pj, p, 0.15, 0.9, 0.4, {"foam": 1.0, "alpha": 0.75})
					if i % 5 == 0:
						L.spray(pj, Vector3(p.x, p.y + sink + 0.2, p.z), Vector3.UP + sd * 0.6, {"n": 3, "spread": 30.0, "vmin": 1.0, "vmax": 2.2, "life": 0.35, "smin": 0.07, "smax": 0.12})
				else:   # fışkırır, hedefin tepesine iner
					var q = (u - 0.62) / 0.38
					if not s["out"]:
						s["out"] = true
						L.spray(pj, a + Vector3.UP * 0.2, Vector3.UP, {"n": 22, "spread": 35.0, "vmin": 4.0, "vmax": 8.0, "life": 0.6, "smin": 0.12, "smax": 0.24, "foam": 0.35, "r": 0.5})
						L.ripple(pj, a, 0.4, 2.2, 0.5, {"foam": 1.0})
					p = a.lerp(to + Vector3.UP * 0.8, q) + Vector3.UP * sin(q * PI) * 3.2
					_shark_pose(sh, i * 0.025, 0.15 + 0.5 * q, 1.0)
				var mv: Vector3 = p - s["last"]
				if mv.length() > 0.01:
					var mn = mv.normalized()
					sh.global_basis = Basis.looking_at(mn, Vector3.UP if absf(mn.y) < 0.95 else dn)   # burun -Z hareket yönünde
				sh.global_position = p
				s["last"] = p
			var land = func():
				if not is_instance_valid(sh):
					return
				var p = sh.global_position
				sh.queue_free()
				L.spray(pj, p, Vector3.UP, {"n": 18, "spread": 85.0, "vmin": 2.5, "vmax": 5.5, "life": 0.55, "smin": 0.12, "smax": 0.22, "foam": 0.3, "r": 0.6})
				L.puddle(pj, p, 1.3, 1.6, {"alpha": 0.5, "ripple": 0.35})
				var c2 = cw.get_ref()
				if c2 != null and pj.live(c2):
					pj.hit(c2, p, 1.7, pj.inf(c2, id, 0.9, {"knock": 3.0, "launch": -8.0, "kind": "heavy", "element": "suiton", "bleed": 1.5, "hitstop": 0.04}))
				Sfx.play("water", p, 1.5, 0.5)
			pj.every(0.75, 1.0 / 40.0, swim, land)
		pj.after(0.2 + k * 0.17, one)


# ================================================================== 15) Suiton: Mizutoge no Jutsu
## Kaynaksız tasarım: hedefin altındaki zemin ıslanıp halka halka kararır, ardından burgulu, gövdesinden yan dikencikler fırlayan
## iri su dikeni fışkırır (su gövdede yukarı akar); çevresinde sırayla altı içe eğik diken. Dikenler çöküp birikinti bırakır.
static func suiton_mizutoge_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var id = "suiton_mizutoge_no_jutsu"
	var tt = pj.tg(c, t, 22.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cen: Vector3 = pj.gp(tt.global_position) if tt else pj.gp(c.global_position + d * 9.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	L.puddle(pj, cen, 3.0, 1.4, {"alpha": 0.6, "ripple": 0.8, "spread": 0.3})   # önce zemin ıslanır
	L.ripple(pj, cen, 3.2, 0.4, 0.4, {"foam": 0.7})   # halka içe çekilir
	Sfx.play("water", cen, 1.2)
	var main = func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var p0: Vector3 = pj.gp(x.global_position) if x != null and pj.live(x) else cen
		_toge(pj, p0, 4.2, 0.55)
		pj.hit(cc, p0 + Vector3.UP * 1.0, 1.3, pj.inf(cc, id, 1.7, {"knock": 0.0, "launch": 9.0, "kind": "heavy", "element": "suiton", "bleed": 3.0, "hitstop": 0.1, "armor_break": 0.3}))
		Sfx.play("blade", p0, 0.7)
		pj.shake(0.4)
		for k in 6:   # çevresinde sırayla, içe eğik dikenler
			var a = k * TAU / 6.0 + 0.4
			var q: Vector3 = pj.gp(p0 + Vector3(cos(a), 0, sin(a)) * 2.1)
			var ring = func():
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				_toge(pj, q, 3.0, 0.4, Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35))
				pj.hit(c2, q + Vector3.UP * 0.9, 1.15, pj.inf(c2, id, 0.6, {"knock": 2.0, "launch": 5.0, "kind": "heavy", "element": "suiton", "bleed": 1.5, "hitstop": 0.03}))
			pj.after(0.1 + k * 0.05, ring)
	pj.after(0.4, main)


## Tek su dikeni: zeminden fırlar, kısa durur, eriyip birikintiye çöker
static func _toge(h: Node, at: Vector3, hh: float, r: float, tilt := Vector3.ZERO, hold := 0.55) -> void:
	var mi = L.wmi(_toge_mesh(hh, r), {"alpha": 0.9, "line": 0.12, "flow": 4.0, "streak": 2.6, "foam": 0.18, "wob": 0.5, "neard": 6.0})
	L.put(h, mi, at + Vector3.DOWN * 0.1)
	mi.rotation = tilt
	mi.scale = Vector3(1.0, 0.02, 1.0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(mi, "scale", Vector3(1.5, 0.1, 1.5), 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	for k in 6:   # tabanda dışa halka çizen damlalar
		var a = k * TAU / 6.0 + randf() * 0.5
		L.spray(h, at + Vector3(cos(a), 0.0, sin(a)) * r * 0.9 + Vector3.UP * 0.15, Vector3(cos(a), 1.3, sin(a)), {"n": 4, "spread": 20.0, "vmin": 2.5, "vmax": 5.0, "life": 0.45, "smin": 0.08, "smax": 0.15})
	var tip = at + (Basis.from_euler(tilt) * Vector3.UP) * hh
	h.get_tree().create_timer(0.12).timeout.connect(func():
		L.spray(h, tip, Vector3.UP, {"n": 8, "spread": 70.0, "vmin": 1.0, "vmax": 2.5, "life": 0.6, "smin": 0.06, "smax": 0.11, "r": 0.1}))
	h.get_tree().create_timer(0.09 + hold).timeout.connect(func():
		L.puddle(h, at, r * 2.4, 1.4, {"alpha": 0.5, "ripple": 0.3}))
