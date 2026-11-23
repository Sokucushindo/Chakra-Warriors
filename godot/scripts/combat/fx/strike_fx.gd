class_name StrikeFX
extends RefCounted
## Taijutsu / kenjutsu darbeleri ve ağır Doton kaya teknikleri (12 teknik). Ortak efekt yardımcısı yok:
## kendi cel shader'ım (3 kademeli ışık, kendi rengiyle koyu kenar, benek, kaya çatlak deseni, parça parça dağılma, ejder için
## soluk camgöbeği kenar parıltısı ve akan rüzgâr çizgileri), kendi şerit shader'ım (baştan uca açılan / kuyruktan kapanan,
## yırtık çizgili, kenarı mürekkepli şeritler), kendi geometrim (yontulmuş kaya, toprak plakası, toz topağı, kum tepesi, çimen
## tutamı, yaprak, katmanlı kaya bloğu, toprak kapak, arazinin üstüne oturan şerit / disk / çatlak).
## Davranış: hız izleri açılıp kapanır, toz ağır topaklar halinde yayılıp kırıntı kırıntı dağılır, kaya parçaları yay çizip düşer,
## yerde kalır ve toprağa gömülür; çatlaklar merkezden dışa doğru yürür, plakalar kalkar ve yavaşça geri çöker.

static var _cache := {}

const CHIP := 0
const TUFT := 1
const LEAF := 2

const DUST := Color(0.66, 0.56, 0.42)
const GREY_DUST := Color(0.64, 0.6, 0.54)
const SOIL := Color(0.45, 0.34, 0.24)
const SOIL_D := Color(0.28, 0.2, 0.14)
const ROCK := Color(0.6, 0.5, 0.38)
const SAND := Color(0.9, 0.78, 0.52)
const WHITE := Color(0.97, 0.98, 1.0, 0.95)
const INKC := Color(0.16, 0.13, 0.11, 0.85)

# ------------------------------------------------------------------ malzemeler
const CEL_SHADER := """
shader_type spatial;
render_mode CULLMODE, depth_draw_opaque, ambient_light_disabled;

instance uniform vec3 tint = vec3(1.0);
instance uniform float dis = 0.0;
instance uniform float cracks = 0.0;
instance uniform float speck = 0.0;
instance uniform float glow = 0.0;
instance uniform float wind = 0.0;
instance uniform float reveal = 2.0;
instance uniform float vanish = -1.0;
instance uniform float seed = 0.0;
instance uniform float ink_at = 0.78;

varying vec3 lp;
varying vec3 ln;

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

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float dd = length(g + h22(i + g) - f);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	if (UV.x > reveal || UV.x < vanish) {
		discard;
	}
	if (dis > 0.001 && vn3(lp * 4.0 + vec3(seed * 3.7)) * 0.75 + vn3(lp * 11.0 + vec3(seed)) * 0.25 < dis) {
		discard;
	}
	vec3 base = pow(clamp(COLOR.rgb * tint, vec3(0.0), vec3(1.0)), vec3(2.2));
	// benek (kum tanesi / kaya gözeneği)
	float sp = step(0.8, vn3(lp * 7.0 + vec3(seed * 2.0)));
	base *= 1.0 - sp * speck * 0.35;
	// kaya çatlakları: yüzeyin baktığı eksene göre düzlem seçilir, hücre kenarları kırık çizgi olur
	vec3 an = abs(ln);
	vec2 pc = an.y > 0.6 ? lp.xz : (an.x > an.z ? lp.zy : lp.xy);
	float ce = cell_edge(pc * 0.9 + vec2(seed * 3.0));
	float crk = (1.0 - smoothstep(0.025, 0.06, ce)) * step(1.0 - cracks * 0.7, vn3(lp * 0.8 + vec3(seed * 1.3)));
	base = mix(base, base * 0.18, crk * step(0.001, cracks));
	// akan rüzgâr çizgileri (ejder gövdesi)
	float ws = smoothstep(0.82, 0.92, sin(UV.x * 70.0 + UV.y * 12.566 - TIME * 9.0) * 0.5 + 0.5);
	base = mix(base, base * vec3(0.72, 0.84, 0.92), ws * wind);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	base = mix(base, base * 0.3, step(ink_at, fres));
	ALBEDO = base;
	EMISSION = base * (0.3 + glow * 0.8) + vec3(0.35, 0.85, 1.0) * smoothstep(0.4, 0.95, fres) * glow * 1.4;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.35 ? 1.0 : (ndl > -0.05 ? 0.62 : 0.36);
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
"""

## Toz: yarı saydam, kendi rengiyle iki tonlu, kenarı yumuşak dağınık, içinde yavaş kabaran desen; kameraya çok yakınken solar
const DUST_SHADER := """
shader_type spatial;
render_mode cull_back, depth_draw_never, blend_mix, ambient_light_disabled;

instance uniform vec3 tint = vec3(1.0);
instance uniform float fade = 1.0;
instance uniform float glow = 0.0;
instance uniform float seed = 0.0;

varying vec3 lp;
varying float camd;

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
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	camd = length(wpos - CAMERA_POSITION_WORLD);
}

void fragment() {
	vec3 base = pow(clamp(tint, vec3(0.0), vec3(1.0)), vec3(2.2));
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float n = vn3(lp * 2.6 + vec3(seed * 3.1, seed - TIME * 0.5, 0.0)) * 0.7 + vn3(lp * 6.0 + vec3(seed)) * 0.3;
	// iç kısım dolu, kenar düzensiz ve yumuşak dağılır (delik deseni yok)
	float a = 1.0 - smoothstep(0.3, 0.92, fres + (n - 0.5) * 0.45);
	a *= fade * 0.72;
	a *= smoothstep(1.5, 4.5, camd);
	base *= mix(1.0, 0.8, step(0.56, n));
	ALBEDO = base;
	ALPHA = clamp(a, 0.0, 1.0);
	EMISSION = base * (0.22 + glow);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.25 ? 1.0 : 0.66;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
"""

const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

instance uniform vec4 tint = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float head = 1.0;
instance uniform float tail = 0.0;
instance uniform float edge_ink = 0.0;
instance uniform float breakup = 0.0;
instance uniform float soft = 0.0;
instance uniform float seed = 0.0;
instance uniform float ends = 1.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float v = abs(UV.y - 0.5) * 2.0;
	float a = COLOR.a * tint.a * fade;
	// açık şeritte uçlar yumuşak söner; kapalı halka / diskte (ends = 0) dikiş olmasın
	a *= mix(1.0, smoothstep(tail, tail + 0.06, u) * (1.0 - smoothstep(head - 0.04, head + 0.0001, u)), ends);
	// boyuna yırtık çizgiler (hız / rüzgâr sürtmesi)
	float lane = floor(UV.y * 9.0);
	float nb = vn2(vec2(u * 7.0 + seed * 5.0, lane * 3.1 + seed));
	a *= mix(1.0, smoothstep(breakup - 0.05, breakup + 0.05, nb), step(0.001, breakup));
	a *= mix(1.0, 1.0 - smoothstep(0.35, 1.0, v), soft);
	vec3 col = pow(clamp(COLOR.rgb * tint.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));
	col = mix(col, col * 0.3, step(0.72, v) * edge_ink);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


static func _cel_mat(two_sided := false) -> ShaderMaterial:
	var key = "cel2" if two_sided else "cel"
	if _cache.has(key):
		return _cache[key]
	var sh = Shader.new()
	sh.code = CEL_SHADER.replace("CULLMODE", "cull_disabled" if two_sided else "cull_back")
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache[key] = m
	return m


static func _dust_mat() -> ShaderMaterial:
	if _cache.has("dust"):
		return _cache["dust"]
	var sh = Shader.new()
	sh.code = DUST_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["dust"] = m
	return m


static func _streak_mat() -> ShaderMaterial:
	if _cache.has("streak"):
		return _cache["streak"]
	var sh = Shader.new()
	sh.code = STREAK_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["streak"] = m
	return m


## Cel malzemeli mesh örneği; o: örnek başına shader değerleri ("shadow": gölge atsın mı)
static func _cel_mi(mesh: Mesh, tint: Color, o := {}, two_sided := false) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _cel_mat(two_sided)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if o.get("shadow", false) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	for k in o:
		if k != "shadow":
			mi.set_instance_shader_parameter(k, o[k])
	return mi


## Şerit malzemeli mesh örneği
static func _streak_mi(mesh: Mesh, o := {}) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _streak_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	for k in o:
		mi.set_instance_shader_parameter(k, o[k])
	return mi


static func _pf(mi: GeometryInstance3D, pname: String) -> Callable:
	return func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(pname, v)


## Şerit animasyonu: baştan uca açılır (head), bekler; close ise kuyruk ucu kapanırken söner, değilse yerinde söner; sonra silinir
static func _sweep(mi: GeometryInstance3D, t_in: float, hold: float, t_out: float, close := true) -> void:
	if not is_instance_valid(mi):
		return
	if t_in > 0.0:
		mi.set_instance_shader_parameter("head", 0.0)
	var tw = mi.create_tween()
	if t_in > 0.0:
		tw.tween_method(_pf(mi, "head"), 0.0, 1.0, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	if close:
		tw.tween_method(_pf(mi, "tail"), 0.0, 1.0, t_out).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, t_out)
	else:
		tw.tween_method(_pf(mi, "fade"), 1.0, 0.0, t_out)
	tw.tween_callback(mi.queue_free)


## Bir düğüm ağacındaki tüm parçaları birlikte söndürür: cel parçalar dağılır (dis), şeritler solar (fade)
static func _dis_all(n: Node) -> Callable:
	return func(v: float):
		if not is_instance_valid(n):
			return
		var all = n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D:
			all.append(n)
		for ch in all:
			if ch.material_override == _streak_mat():
				ch.set_instance_shader_parameter("fade", 1.0 - v)
			else:
				ch.set_instance_shader_parameter("dis", v)


## Cel nesnenin parça parça dağılarak yok olması
static func _dissolve_out(mi: GeometryInstance3D, delay: float, t: float) -> void:
	if not is_instance_valid(mi):
		return
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_pf(mi, "dis"), 0.0, 1.0, t)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ geometri
## [konum, normal, uv, renk] köşeleriyle üçgen; sıra normale göre çevrilir (Godot: saat yönü ön yüz → çapraz çarpım içe bakmalı)
static func _stri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var n = (b[0] - a[0]).cross(c[0] - a[0])
	if n.dot(a[1] + b[1] + c[1]) > 0.0:
		var tmp = b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_color(v[3])
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.add_vertex(v[0])


## Yassı gölgeli üçgen: normal, şeklin merkezinden (ctr) dışa
static func _ftri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ctr: Vector3, col: Color) -> void:
	var n = (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - ctr) > 0.0:
		var tmp = b
		b = c
		c = tmp
		n = -n
	var nn = -n.normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(nn)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(v)


static func _qv(st: SurfaceTool, p: Vector3, uv: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	st.set_uv(uv)
	st.add_vertex(p)


## Şerit: her noktada yan vektör + genişlik; UV.x boyuna (0..1), UV.y enine. Noktalar o'ya göre yerele çevrilir
static func _strip_into(st: SurfaceTool, pts: Array, sides: Array, widths: Array, col: Color, o: Vector3) -> void:
	var n = pts.size()
	for i in n - 1:
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		var a0 = pts[i] - o - sides[i] * widths[i] * 0.5
		var b0 = pts[i] - o + sides[i] * widths[i] * 0.5
		var a1 = pts[i + 1] - o - sides[i + 1] * widths[i + 1] * 0.5
		var b1 = pts[i + 1] - o + sides[i + 1] * widths[i + 1] * 0.5
		_qv(st, a0, Vector2(u0, 0.0), col)
		_qv(st, b0, Vector2(u0, 1.0), col)
		_qv(st, b1, Vector2(u1, 1.0), col)
		_qv(st, a0, Vector2(u0, 0.0), col)
		_qv(st, b1, Vector2(u1, 1.0), col)
		_qv(st, a1, Vector2(u1, 0.0), col)


static func _strip_mesh(pts: Array, sides: Array, widths: Array, col: Color, o: Vector3) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip_into(st, pts, sides, widths, col, o)
	return st.commit()


## Her açıdan görünen çizgi: yola dik iki şerit çaprazlanır
static func _ribbon_mesh(pts: Array, widths: Array, col: Color, o: Vector3) -> ArrayMesh:
	var s1 = []
	var s2 = []
	var n = pts.size()
	for i in n:
		var tv = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tv.length() < 0.0001:
			tv = Vector3.FORWARD
		tv = tv.normalized()
		var ref = Vector3.UP if absf(tv.y) < 0.9 else Vector3.RIGHT
		var a = tv.cross(ref).normalized()
		s1.append(a)
		s2.append(tv.cross(a).normalized())
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_strip_into(st, pts, s1, widths, col, o)
	_strip_into(st, pts, s2, widths, col, o)
	return st.commit()


## Uçlara doğru incelen genişlik dizisi (w0 baş, w1 son)
static func _taper(n: int, w0: float, w1: float, ends := 6.0) -> Array:
	var out = []
	for i in n:
		var u = float(i) / maxi(1, n - 1)
		out.append(lerpf(w0, w1, u) * clampf(minf(u, 1.0 - u) * ends + 0.12, 0.0, 1.0))
	return out


## İki nokta arası bölünmüş düz yol
static func _seg(a: Vector3, b: Vector3, n: int) -> Array:
	var out = []
	for i in n + 1:
		out.append(a.lerp(b, float(i) / n))
	return out


## Uzayda tek çizgi: açılır, kapanır
static func _line(pj: PathJutsu, pts: Array, w0: float, w1: float, col: Color, t_in: float, hold: float, t_out: float, o := {}) -> MeshInstance3D:
	var mi = _streak_mi(_ribbon_mesh(pts, _taper(pts.size(), w0, w1), col, pts[0]), o)
	pj.scene_add(mi, pts[0])
	_sweep(mi, t_in, hold, t_out)
	return mi


## Paralel taşıma çerçeveleri (tüp / sarmal): [N, B, teğet]
static func _frames(pts: Array) -> Array:
	var out = []
	var n = pts.size()
	var prev = Vector3.ZERO
	for i in n:
		var tv = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nv: Vector3
		if prev == Vector3.ZERO:
			var ref = Vector3.UP if absf(tv.y) < 0.9 else Vector3.RIGHT
			nv = tv.cross(ref).normalized()
		else:
			nv = (prev - tv * prev.dot(tv)).normalized()
		out.append([nv, tv.cross(nv).normalized(), tv])
		prev = nv
	return out


## Yumuşak gölgeli tüp; UV.x boyuna (açılma / sönme için), UV.y çevresel
static func _tube_mesh(pts: Array, radii: Array, sides: int, col: Color) -> ArrayMesh:
	var n = pts.size()
	var fr = _frames(pts)
	var rings = []
	for i in n:
		var r = []
		for k in sides + 1:
			var a = TAU * k / sides
			var dn = fr[i][0] * cos(a) + fr[i][1] * sin(a)
			r.append([pts[i] + dn * radii[i], dn, Vector2(float(i) / (n - 1), float(k) / sides), col])
		rings.append(r)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		for k in sides:
			_stri(st, rings[i][k], rings[i + 1][k], rings[i + 1][k + 1])
			_stri(st, rings[i][k], rings[i + 1][k + 1], rings[i][k + 1])
	return st.commit()


## Catmull-Rom eğrisi
static func _catmull(cps: Array, n: int) -> Array:
	var out = []
	var m = cps.size() - 1
	for i in n + 1:
		var s = float(i) / n * m
		var k = mini(int(s), m - 1)
		var u = s - k
		var p0: Vector3 = cps[maxi(k - 1, 0)]
		var p1: Vector3 = cps[k]
		var p2: Vector3 = cps[k + 1]
		var p3: Vector3 = cps[mini(k + 2, m)]
		out.append((p1 * 2.0 + (p2 - p0) * u + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * u * u + (p1 * 3.0 - p0 - p2 * 3.0 + p3) * u * u * u) * 0.5)
	return out


## Katmanlı gövde: outline (xz çokgeni) her halkada ölçeklenir; halka = [ölçek, y, bant rengi]; üst / alt kapak tek noktaya kapanır.
## Yassı gölgeli: kaya, toprak plakası, kaya bloğu, toprak kapak hep bununla
static func _stack_mesh(outline: Array, rings: Array, top_y: float, top_col: Color, bot_y: float, bot_col: Color, jit: float, sd: int) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var n = outline.size()
	var rv = []
	for r in rings:
		var arr = []
		for k in n:
			var o: Vector2 = outline[k]
			var s = float(r[0]) * (1.0 + rng.randf_range(-jit, jit))
			arr.append(Vector3(o.x * s, float(r[1]) + rng.randf_range(-jit, jit) * 0.5, o.y * s))
		rv.append(arr)
	var ctr = Vector3(0, (top_y + bot_y) * 0.5, 0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		var col: Color = rings[i][2]
		for k in n:
			var k2 = (k + 1) % n
			_ftri(st, rv[i][k], rv[i][k2], rv[i + 1][k2], ctr, col)
			_ftri(st, rv[i][k], rv[i + 1][k2], rv[i + 1][k], ctr, col)
	var tc = Vector3(rng.randf_range(-jit, jit), top_y, rng.randf_range(-jit, jit))
	var last = rv[rv.size() - 1]
	for k in n:
		_ftri(st, last[k], last[(k + 1) % n], tc, ctr, top_col)
	var bc = Vector3(0, bot_y, 0)
	for k in n:
		_ftri(st, rv[0][k], rv[0][(k + 1) % n], bc, ctr, bot_col)
	return st.commit()


static func _rand_poly(rng: RandomNumberGenerator, n: int, rough: float) -> Array:
	var out = []
	var a0 = rng.randf() * TAU
	for k in n:
		var a = a0 + k * TAU / n + rng.randf_range(-0.25, 0.25)
		var r = 1.0 + rng.randf_range(-rough, rough)
		out.append(Vector2(cos(a) * r, sin(a) * r))
	return out


## Yontulmuş kaya parçası (birim boy)
static func _rock_mesh(v: int) -> ArrayMesh:
	var key = "rock_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 4231 * (v + 2)
	var ol = _rand_poly(rng, rng.randi_range(5, 7), 0.25)
	var w = Color.WHITE
	var s = Color(0.88, 0.88, 0.88)
	var m = _stack_mesh(ol, [[0.7, -0.45, Color(0.78, 0.78, 0.78)], [1.0, -0.05, s], [0.78, 0.32, w]], rng.randf_range(0.42, 0.6), w, -0.55, Color(0.7, 0.7, 0.7), 0.14, rng.randi())
	_cache[key] = m
	return m


## Yerden kopan toprak plakası: üstü çimenli (ya da toprak), yanları katmanlı toprak, altı koyu
static func _plate_mesh(v: int, grassy: bool) -> ArrayMesh:
	var key = "plate_%d_%d" % [v, int(grassy)]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7717 * (v + 5)
	var ol = _rand_poly(rng, rng.randi_range(5, 6), 0.2)
	var top = Color(0.42, 0.54, 0.26) if grassy else Color(0.56, 0.45, 0.32)
	var m = _stack_mesh(ol, [[0.92, -0.55, SOIL_D], [1.0, -0.05, SOIL], [0.97, 0.06, top]], 0.1, top, -0.6, SOIL_D, 0.1, rng.randi())
	_cache[key] = m
	return m


## Toz topağı: tümsekli, altı basık küre (birim)
static func _puff_mesh(v: int) -> ArrayMesh:
	var key = "puff_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 911 * (v + 7)
	var bumps = []
	for k in 5:
		bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.2, 0.42)])
	var rn = 7
	var sg = 10
	var grid = []
	for i in rn + 1:
		var th = PI * i / rn
		var row = []
		for j in sg + 1:
			var ph = TAU * j / sg
			var dir = Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var r = 0.85
			for b in bumps:
				r += b[1] * pow(maxf(0.0, dir.dot(b[0])), 2.0)
			var p = dir * r
			if p.y < -0.25:
				p.y = -0.25 + (p.y + 0.25) * 0.35
			row.append([p, dir, Vector2(float(j) / sg, float(i) / rn), Color.WHITE])
		grid.append(row)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rn:
		for j in sg:
			_stri(st, grid[i][j], grid[i + 1][j], grid[i + 1][j + 1])
			_stri(st, grid[i][j], grid[i + 1][j + 1], grid[i][j + 1])
	var m = st.commit()
	_cache[key] = m
	return m


## Kum tepesi: x boyunca uzun, z'de rüzgâr yönü yumuşak / arka yüz dik sırt, üstünde ince dalgacıklar (taban y=0)
static func _dune_mesh(v: int) -> ArrayMesh:
	var key = "dune_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 3301 * (v + 1)
	var zc = rng.randf_range(0.1, 0.35)
	var ph = rng.randf() * TAU
	var hf = func(x: float, z: float) -> float:
		var along = pow(maxf(0.0, 1.0 - x * x), 1.3)
		var prof = 0.0
		if z < zc:
			prof = pow(clampf((z + 1.0) / (zc + 1.0), 0.0, 1.0), 1.6)
		else:
			prof = pow(clampf(1.0 - (z - zc) / (1.0 - zc), 0.0, 1.0), 0.6)
		return along * prof * (1.0 + 0.06 * sin(x * 9.0 + z * 4.0 + ph))
	var nx = 16
	var nz = 10
	var grid = []
	for i in nx + 1:
		var row = []
		var x = -1.0 + 2.0 * i / nx
		for j in nz + 1:
			var z = -1.0 + 2.0 * j / nz
			var h = hf.call(x, z)
			var e = 0.02
			var dx = (hf.call(x + e, z) - hf.call(x - e, z)) / (2.0 * e)
			var dz = (hf.call(x, z + e) - hf.call(x, z - e)) / (2.0 * e)
			var nrm = Vector3(-dx, 1.0, -dz).normalized()
			var col = SAND.darkened(0.12).lerp(SAND.lightened(0.08), clampf(h, 0.0, 1.0))
			row.append([Vector3(x, h, z), nrm, Vector2(float(i) / nx, float(j) / nz), col])
		grid.append(row)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx:
		for j in nz:
			_stri(st, grid[i][j], grid[i + 1][j], grid[i + 1][j + 1])
			_stri(st, grid[i][j], grid[i + 1][j + 1], grid[i][j + 1])
	var m = st.commit()
	_cache[key] = m
	return m


## Yaprak: ortası katlanmış, sivri uçlu (birim ~1 m; örnekte küçültülür)
static func _leaf_mesh() -> ArrayMesh:
	if _cache.has("leaf"):
		return _cache["leaf"]
	var g0 = Color(0.36, 0.56, 0.2)
	var g1 = Color(0.55, 0.72, 0.3)
	var tip = [Vector3(0, 0.0, 0.55), Vector3.UP, Vector2(0.5, 1.0), g1]
	var base = [Vector3(0, 0.0, -0.45), Vector3.UP, Vector2(0.5, 0.0), g0]
	var mid = [Vector3(0, 0.06, 0.0), Vector3.UP, Vector2(0.5, 0.5), g1]
	var l = [Vector3(-0.24, -0.02, 0.0), Vector3.UP, Vector2(0.0, 0.5), g0]
	var r = [Vector3(0.24, -0.02, 0.0), Vector3.UP, Vector2(1.0, 0.5), g0]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stri(st, tip, l, mid)
	_stri(st, tip, mid, r)
	_stri(st, base, mid, l)
	_stri(st, base, r, mid)
	var m = st.commit()
	_cache["leaf"] = m
	return m


## Koparılmış çimen tutamı: dışa açılan ince yapraklar, dibi koyu (birim ~1 m)
static func _tuft_mesh() -> ArrayMesh:
	if _cache.has("tuft"):
		return _cache["tuft"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dk = Color(0.25, 0.36, 0.14)
	var lt = Color(0.5, 0.68, 0.28)
	for k in 6:
		var a = k * TAU / 6.0 + 0.3 * sin(k * 2.7)
		var d = Vector3(cos(a), 0, sin(a))
		var sd = Vector3(-d.z, 0, d.x)
		var h = 0.75 + 0.25 * sin(k * 1.9)
		var b0 = [d * 0.05 - sd * 0.05, d, Vector2(0, 0), dk]
		var b1 = [d * 0.05 + sd * 0.05, d, Vector2(1, 0), dk]
		var tp = [d * (0.35 + 0.1 * cos(k * 3.1)) + Vector3.UP * h, d, Vector2(0.5, 1), lt]
		_stri(st, b0, b1, tp)
	var m = st.commit()
	_cache["tuft"] = m
	return m


## Yatay halka (iç 0.8, dış 1.0), UV.y enine
static func _ring_mesh() -> ArrayMesh:
	if _cache.has("ring"):
		return _cache["ring"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 48
	for k in n:
		var a0 = k * TAU / n
		var a1 = (k + 1) * TAU / n
		var i0 = Vector3(cos(a0), 0, sin(a0)) * 0.8
		var o0 = Vector3(cos(a0), 0, sin(a0))
		var i1 = Vector3(cos(a1), 0, sin(a1)) * 0.8
		var o1 = Vector3(cos(a1), 0, sin(a1))
		var u0 = float(k) / n
		var u1 = float(k + 1) / n
		_qv(st, i0, Vector2(u0, 0.0), Color.WHITE)
		_qv(st, o0, Vector2(u0, 1.0), Color.WHITE)
		_qv(st, o1, Vector2(u1, 1.0), Color.WHITE)
		_qv(st, i0, Vector2(u0, 0.0), Color.WHITE)
		_qv(st, o1, Vector2(u1, 1.0), Color.WHITE)
		_qv(st, i1, Vector2(u1, 0.0), Color.WHITE)
	var m = st.commit()
	_cache["ring"] = m
	return m


## Araziye oturan disk / halka (r_in > 0): köşeler gerçek zemin yüksekliğinde; UV.y = 0.5 merkez → 1 kenar (şerit shader'ında
## yumuşak kenar olur), renk merkezden kenara col → edge_col; kenar düzensiz (rag)
static func _disc_mesh(c: Vector3, R: float, r_in: float, col: Color, edge_col: Color, rag: float, lift: float) -> ArrayMesh:
	var na = 28
	var nr = 5
	var ph = randf() * TAU
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vert = func(x: float, z: float, rf: float, af: float) -> Array:
		var y = Game.jutsu_floor_at(Vector3(c.x + x, c.y, c.z + z)).y - c.y + lift
		return [Vector3(x, y, z), Vector3.UP, Vector2(af, 0.5 + 0.5 * rf), col.lerp(edge_col, rf)]
	var grid = []
	for i in nr + 1:
		var row = []
		var f = float(i) / nr
		for j in na + 1:
			var a = TAU * j / na
			var rr = lerpf(r_in, R, f)
			if i == nr:
				rr *= 1.0 + rag * (0.6 * sin(a * 3.0 + ph) + 0.4 * sin(a * 7.0 + ph * 2.0))
			row.append(vert.call(cos(a) * rr, sin(a) * rr, f, float(j) / na))
		grid.append(row)
	for i in nr:
		for j in na:
			if i == 0 and r_in <= 0.0:
				_stri(st, grid[0][j], grid[1][j], grid[1][j + 1])
			else:
				_stri(st, grid[i][j], grid[i + 1][j], grid[i + 1][j + 1])
				_stri(st, grid[i][j], grid[i + 1][j + 1], grid[i][j + 1])
	return st.commit()


## Kesik kenarlı dikdörtgen çevre (kaya bloğu)
static func _chamfer_rect(hx: float, hz: float, ch: float) -> Array:
	return [Vector2(hx - ch, -hz), Vector2(hx, -hz + ch), Vector2(hx, hz - ch), Vector2(hx - ch, hz),
		Vector2(-hx + ch, hz), Vector2(-hx, hz - ch), Vector2(-hx, -hz + ch), Vector2(-hx + ch, -hz)]


## Ganseki Atsu kaya bloğu (4 x 3 x 4 m, taban y=-1.5): koyu kahve gövde, üst kenarda açık ten pah bandı, düz üst yüz
static func _slab_mesh(v: int) -> ArrayMesh:
	var key = "slab_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rings = [[0.97, -1.5, Color(0.4, 0.3, 0.21)], [1.02, -0.4, Color(0.5, 0.38, 0.26)], [1.0, 1.1, Color(0.76, 0.62, 0.44)], [0.9, 1.5, Color.WHITE]]
	var m = _stack_mesh(_chamfer_rect(2.0, 2.0, 0.4), rings, 1.56, Color(0.54, 0.41, 0.28), -1.55, Color(0.3, 0.22, 0.15), 0.025, 9001 + v * 31)
	_cache[key] = m
	return m


## Otoshibuta toprak kapağı (r ~4.7): üstü çimenli toprak, yanı katman katman toprak, altı sarkık koyu toprak konisi
static func _lid_mesh(v: int) -> ArrayMesh:
	var key = "lid_%d" % v
	if _cache.has(key):
		return _cache[key]
	var ol = []
	for k in 16:
		var a = k * TAU / 16.0
		ol.append(Vector2(cos(a), sin(a)))
	var rings = [[4.1, -0.6, Color(0.3, 0.22, 0.15)], [4.8, -0.25, Color(0.42, 0.31, 0.21)], [4.75, 0.35, Color(0.52, 0.4, 0.27)], [4.6, 0.55, Color.WHITE]]
	var m = _stack_mesh(ol, rings, 0.63, Color(0.42, 0.56, 0.27), -1.3, Color(0.25, 0.18, 0.12), 0.05, 5501 + v * 17)
	_cache[key] = m
	return m


# ------------------------------------------------------------------ hareketli parçalar
## Balistik uçuş; yere değince on_land(mi, yer)
static func _fly(mi: MeshInstance3D, p0: Vector3, v0: Vector3, g: float, tum: Vector3, on_land: Callable, max_t := 3.0) -> void:
	var stt = {"done": false}
	var stepf = func(q: float):
		if stt["done"] or not is_instance_valid(mi):
			return
		var p = p0 + v0 * q + Vector3.DOWN * 0.5 * g * q * q
		var fl = Game.jutsu_floor_at(p).y
		if q > 0.04 and p.y <= fl:
			stt["done"] = true
			on_land.call(mi, Vector3(p.x, fl, p.z))
			return
		mi.global_position = p
		mi.rotation = tum * q
	var tw = mi.create_tween()
	tw.tween_method(stepf, 0.0, max_t, max_t)
	tw.tween_callback(func():
		if not stt["done"] and is_instance_valid(mi):
			mi.queue_free())


## Düşen kaya yere oturur, bir süre kalır, sonra toprağa gömülür
static func _land_rock(s: float, stay: float) -> Callable:
	return func(m, q):
		if not is_instance_valid(m):
			return
		m.global_position = q + Vector3.UP * s * 0.2
		var tw = m.create_tween()
		tw.tween_interval(stay * randf_range(0.8, 1.2))
		tw.tween_property(m, "global_position", q - Vector3.UP * s * 0.8, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(m.queue_free)


## Hafif parça yere düşer, yatar, kırıntı kırıntı dağılır
static func _land_soft(stay: float) -> Callable:
	return func(m, q):
		if not is_instance_valid(m):
			return
		m.global_position = q + Vector3.UP * 0.03
		m.rotation = Vector3(0, m.rotation.y, 0)
		_dissolve_out(m, stay * randf_range(0.8, 1.3), 0.5)


static func _chip(pj: PathJutsu, p: Vector3, v: Vector3, s: float, tint := ROCK, stay := 1.4) -> void:
	var mi = _cel_mi(_rock_mesh(randi() % 6), tint, {"speck": 0.6, "ink_at": 0.8})
	pj.scene_add(mi, p)
	mi.scale = Vector3.ONE * s
	_fly(mi, p, v, 22.0, Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)), _land_rock(s, stay))


static func _tuft(pj: PathJutsu, p: Vector3, v: Vector3, s: float) -> void:
	var mi = _cel_mi(_tuft_mesh(), Color.WHITE, {"ink_at": 2.0}, true)
	pj.scene_add(mi, p)
	mi.scale = Vector3.ONE * s
	_fly(mi, p, v, 13.0, Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), _land_soft(1.0))


## Yaprak: savrulur, sonra salınarak yavaşça süzülür, yere yatar
static func _leaf(pj: PathJutsu, p0: Vector3, v: Vector3, s: float) -> void:
	var mi = _cel_mi(_leaf_mesh(), Color(randf_range(0.9, 1.0), 1.0, randf_range(0.85, 1.0)), {"ink_at": 2.0}, true)
	pj.scene_add(mi, p0)
	mi.scale = Vector3.ONE * s
	var ph = randf() * TAU
	var sw = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var stt = {"done": false}
	var stepf = func(q: float):
		if stt["done"] or not is_instance_valid(mi):
			return
		var hz = Vector3(v.x, 0, v.z) * (1.0 - exp(-2.2 * q)) / 2.2
		var y = v.y * (1.0 - exp(-3.0 * q)) / 3.0 - 1.1 * q
		var p = p0 + hz + Vector3.UP * y + sw * sin(q * 4.0 + ph) * 0.35
		var fl = Game.jutsu_floor_at(p).y
		if q > 0.15 and p.y <= fl + 0.02:
			stt["done"] = true
			_land_soft(1.2).call(mi, Vector3(p.x, fl, p.z))
			return
		mi.global_position = p
		mi.rotation = Vector3(sin(q * 5.0 + ph) * 1.2, q * 3.0 + ph, cos(q * 4.0 + ph) * 0.9)
	var tw = mi.create_tween()
	tw.tween_method(stepf, 0.0, 4.5, 4.5)
	tw.tween_callback(func():
		if not stt["done"] and is_instance_valid(mi):
			mi.queue_free())


## Bir noktadan saçılan parçalar (kaya / çimen / yaprak)
static func _bits(pj: PathJutsu, pos: Vector3, n: int, spd: float, up: float, size: float, kind: int, bias := Vector3.ZERO, tint := ROCK) -> void:
	for k in n:
		var a = randf() * TAU
		var v = Vector3(cos(a), 0, sin(a)) * spd * randf_range(0.35, 1.0) + Vector3.UP * spd * up * randf_range(0.6, 1.2) + bias * randf_range(0.7, 1.2)
		var p = pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25))
		var s = size * randf_range(0.6, 1.3)
		if kind == CHIP:
			_chip(pj, p, v, s, tint)
		elif kind == TUFT:
			_tuft(pj, p, v, s)
		else:
			_leaf(pj, p, v, s)


## Toz topağı: sürüklenerek yavaşlar, şişer, kırıntı kırıntı dağılır. o: "drag", "glow", "ink_at"
static func _puff(pj: PathJutsu, pos: Vector3, vel: Vector3, s0: float, s1: float, life: float, col: Color, o := {}) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _puff_mesh(randi() % 5)
	mi.material_override = _dust_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("tint", Vector3(col.r, col.g, col.b))
	mi.set_instance_shader_parameter("glow", o.get("glow", 0.0))
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("fade", 0.0)
	pj.scene_add(mi, pos)
	# toz ağır ve yayvan: boyut biraz küçültülür, üst sınırı var (kamerayı kaplamasın)
	s0 *= 0.75
	s1 = minf(s1 * 0.7, 1.7)
	mi.scale = Vector3.ONE * s0
	var b0 = Basis(Vector3.UP, randf() * TAU)
	var roll = Vector3(vel.z, 0, -vel.x)
	roll = roll.normalized() if roll.length() > 0.05 else Vector3.RIGHT
	var rs = clampf(vel.length() * 0.35, 0.4, 2.5) * (1.0 if randf() < 0.5 else 0.7)
	var drag = float(o.get("drag", 2.5))
	var stepf = func(q: float):
		if not is_instance_valid(mi):
			return
		var k = (1.0 - exp(-drag * q)) / drag
		mi.global_position = pos + vel * k + Vector3.UP * 0.25 * q
		var u = q / life
		var s = lerpf(s0, s1, 1.0 - pow(1.0 - u, 2.0))
		mi.global_basis = Basis(roll, -rs * k * 2.0) * b0 * Basis.from_scale(Vector3(s, s * 0.8, s))   # yuvarlanarak ilerler
		mi.set_instance_shader_parameter("fade", smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.35, 1.0, u)))
	var tw = mi.create_tween()
	tw.tween_method(stepf, 0.0, life, life)
	tw.tween_callback(mi.queue_free)


## Yerde dışa yayılan toz halkası
static func _dust_ring(pj: PathJutsu, g: Vector3, r0: float, spd: float, n: int, col: Color, size: float, life: float, up := 0.25) -> void:
	for k in n:
		var a = k * TAU / n + randf_range(-0.3, 0.3)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * r0 + Vector3.UP * size * 0.5, dv * spd * randf_range(0.7, 1.2) + Vector3.UP * spd * up, size, size * 2.4, life * randf_range(0.8, 1.2), col)


## Hava basınç halkası: nrm düzlem normali; r0 → r1 genişleyip söner
static func _shock(pj: PathJutsu, pos: Vector3, nrm: Vector3, r0: float, r1: float, t: float, col: Color, ink := 0.0, soft := 0.5) -> void:
	var mi = _streak_mi(_ring_mesh(), {"tint": col, "edge_ink": ink, "soft": soft, "ends": 0.0})
	pj.scene_add(mi, pos)
	var n = nrm.normalized()
	var ref = Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var x = n.cross(ref).normalized()
	mi.global_basis = Basis(x, n, x.cross(n))
	mi.scale = Vector3(r0, 1.0, r0)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r1, 1.0, r1), t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(mi, "fade"), 1.0, 0.0, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Darbe noktasından fırlayan keskin çarpma çizgileri (beyaz + ince koyu)
static func _burst_lines(pj: PathJutsu, at: Vector3, n: int, L: float, d: Vector3) -> void:
	for k in n:
		var dir = (Vector3(randf_range(-1, 1), randf_range(-0.6, 1.0), randf_range(-1, 1)).normalized() + d * 0.6).normalized()
		var ln = L * randf_range(0.6, 1.0)
		var col = WHITE if k % 3 != 2 else INKC
		_line(pj, _seg(at + dir * 0.3, at + dir * ln, 5), 0.12 if k % 3 != 2 else 0.05, 0.0, col, 0.05, 0.0, 0.12)


## Taijutsu vuruşu: basınç halkası + çarpma çizgileri; yere yakınsa toz ve koparılmış çimen
static func _blow(pj: PathJutsu, at: Vector3, s: float, dir: Vector3, ground := true) -> void:
	var d = Vector3(dir.x, 0, dir.z)
	if d.length() < 0.05:
		d = Vector3.FORWARD
	d = d.normalized()
	_shock(pj, at, d, 0.25 * s, 1.5 * s, 0.2, WHITE, 0.0, 0.6)
	_shock(pj, at + d * 0.25, d, 0.15 * s, 1.0 * s, 0.15, Color(1, 1, 1, 0.85), 0.8, 0.0)
	_burst_lines(pj, at, 8, 1.7 * s, d)
	var g = pj.gp(at)
	if ground and at.y - g.y < 2.5:
		_dust_ring(pj, g, 0.3, 3.0 * s, 6, DUST, 0.4 * s, 0.8)
		_bits(pj, g, 3, 3.0 * s, 0.9, 0.12, TUFT)
	pj.shake(0.2 * s)


## Araziye oturan şerit (sürtme izi, çatlak, yarık): her nokta zemine iner
static func _ground_strip(pj: PathJutsu, pts: Array, widths: Array, col: Color, lift: float, o := {}) -> MeshInstance3D:
	var n = pts.size()
	var gp0 = pj.gp(pts[0])
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lr = []
	for i in n:
		var tv = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		tv.y = 0.0
		if tv.length() < 0.0001:
			tv = Vector3.FORWARD
		var sd = Vector3(-tv.z, 0, tv.x).normalized() * widths[i] * 0.5
		var l = pts[i] - sd
		var r = pts[i] + sd
		l.y = Game.jutsu_floor_at(l).y + lift
		r.y = Game.jutsu_floor_at(r).y + lift
		lr.append([l - gp0, r - gp0])
	for i in n - 1:
		var u0 = float(i) / (n - 1)
		var u1 = float(i + 1) / (n - 1)
		_qv(st, lr[i][0], Vector2(u0, 0.0), col)
		_qv(st, lr[i][1], Vector2(u0, 1.0), col)
		_qv(st, lr[i + 1][1], Vector2(u1, 1.0), col)
		_qv(st, lr[i][0], Vector2(u0, 0.0), col)
		_qv(st, lr[i + 1][1], Vector2(u1, 1.0), col)
		_qv(st, lr[i + 1][0], Vector2(u1, 0.0), col)
	var mi = _streak_mi(st.commit(), o)
	pj.scene_add(mi, gp0)
	return mi


## Zemin çatlakları: merkezden (r0 uzaklıktan) dışa doğru yürüyen kırık çizgiler; koyu yarık + açık toprak dudak, yan dallar
static func _cracks(pj: PathJutsu, pos: Vector3, R: float, n: int, dur: float, r0 := 0.0) -> void:
	var g = pj.gp(pos)
	for k in n:
		var a = k * TAU / n + randf_range(-0.35, 0.35)
		var dir = Vector3(cos(a), 0, sin(a))
		var pts = [g + dir * (r0 + R * 0.04)]
		var L = R * randf_range(0.4, 0.8)
		var segn = 9
		for s in segn:
			dir = dir.rotated(Vector3.UP, randf_range(-0.6, 0.6))
			pts.append(pts[pts.size() - 1] + dir * L / segn)
		var w = []
		var wl = []
		for i in pts.size():
			var u = float(i) / (pts.size() - 1)
			w.append(lerpf(0.09, 0.012, u) * (0.75 + 0.5 * randf()))
			wl.append(lerpf(0.24, 0.04, u))
		var lip = _ground_strip(pj, pts, wl, Color(0.62, 0.52, 0.38, 0.45), 0.035, {"soft": 0.8})
		var crk = _ground_strip(pj, pts, w, Color(0.12, 0.09, 0.07, 0.9), 0.05, {"edge_ink": 0.0})
		crk.sorting_offset = 0.5
		var tin = 0.12 + randf() * 0.06
		_sweep(lip, tin, dur, 0.6, false)
		_sweep(crk, tin, dur, 0.6, false)
		if randf() < 0.6:   # yan dal
			var mid: Vector3 = pts[3]
			var bd = dir.rotated(Vector3.UP, 0.9 if randf() < 0.5 else -0.9)
			var bp = [mid, mid + bd * L * 0.15, mid + bd.rotated(Vector3.UP, randf_range(-0.4, 0.4)) * L * 0.3]
			var br = _ground_strip(pj, bp, [0.05, 0.03, 0.01], Color(0.09, 0.07, 0.06, 0.9), 0.05)
			br.sorting_offset = 0.5
			_sweep(br, tin + 0.06, dur, 0.6, false)


## Yerden kalkan toprak plakası: iç kenarı kalkık, dışa eğik; bekler, sonra geri gömülür
static func _plate(pj: PathJutsu, pos: Vector3, out_dir: Vector3, size: float, tilt: float, hold: float, grassy := true) -> void:
	var mi = _cel_mi(_plate_mesh(randi() % 5, grassy), Color.WHITE, {"speck": 0.5, "ink_at": 0.8})
	var g = pj.gp(pos)
	var od = Vector3(out_dir.x, 0, out_dir.z)
	if od.length() < 0.01:
		od = Vector3.FORWARD
	od = od.normalized()
	var axis = Vector3.UP.cross(od).normalized()
	pj.scene_add(mi, g - Vector3.UP * size * 0.9)
	mi.global_basis = Basis(axis, deg_to_rad(tilt)) * Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.6, size))
	var tw = mi.create_tween()
	tw.tween_property(mi, "global_position", g + Vector3.UP * size * 0.05, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(mi, "global_position", g - Vector3.UP * size * 0.9, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Çevresinde dışa eğik plakalar halkası
static func _plate_ring(pj: PathJutsu, g: Vector3, r: float, n: int, size: float, tilt: float, hold: float) -> void:
	for k in n:
		var a = k * TAU / n + randf_range(-0.25, 0.25)
		var dv = Vector3(cos(a), 0, sin(a))
		_plate(pj, g + dv * r * randf_range(0.9, 1.15), dv, size * randf_range(0.75, 1.2), tilt * randf_range(0.7, 1.2), hold * randf_range(0.8, 1.2))


## Zemine oturan cel disk (kazınmış toprak, kum örtüsü, gevşek toprak halkası): büyüyerek açılır, sonra dağılır
static func _ground_patch(pj: PathJutsu, center: Vector3, R: float, r_in: float, col: Color, edge_col: Color, rag: float, grow: float, stay: float, o := {}) -> MeshInstance3D:
	var c = pj.gp(center)
	var mi = _cel_mi(_disc_mesh(c, R, r_in, col, edge_col, rag, 0.04), Color.WHITE, o)
	pj.scene_add(mi, c)
	mi.scale = Vector3(0.2, 1.0, 0.2)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, grow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(stay)
	tw.tween_method(_pf(mi, "dis"), 0.0, 1.0, 1.2)
	tw.tween_callback(mi.queue_free)
	return mi


## Düşen kütlenin yerdeki gölgesi: yumuşak kenarlı koyu disk, kütle yaklaştıkça büyür ve koyulaşır
static func _shadow(pj: PathJutsu, at: Vector3, R: float, t: float) -> MeshInstance3D:
	var c = pj.gp(at)
	var mi = _streak_mi(_disc_mesh(c, R, 0.0, Color(0.05, 0.04, 0.04, 0.55), Color(0.05, 0.04, 0.04, 0.55), 0.05, 0.03), {"soft": 1.0, "ends": 0.0})
	pj.scene_add(mi, c)
	mi.scale = Vector3(0.35, 1.0, 0.35)
	mi.set_instance_shader_parameter("fade", 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, t).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_pf(mi, "fade"), 0.3, 1.0, t)
	pj.free_after(t + 1.5, mi)   # kütle hiç inmezse kalmasın
	return mi


## Çevresinde dönerek yükselen parça (girdap enkazı), sonunda teğet yönünde savrulup düşer
static func _orbit_bit(pj: PathJutsu, center: Vector3, kind: int, r0: float, r1: float, h: float, w: float, t: float, s: float) -> void:
	var mi: MeshInstance3D
	if kind == CHIP:
		mi = _cel_mi(_rock_mesh(randi() % 6), ROCK, {"speck": 0.6, "ink_at": 0.8})
	elif kind == TUFT:
		mi = _cel_mi(_tuft_mesh(), Color.WHITE, {"ink_at": 2.0}, true)
	else:
		mi = _cel_mi(_leaf_mesh(), Color.WHITE, {"ink_at": 2.0}, true)
	pj.scene_add(mi, center)
	mi.scale = Vector3.ONE * s
	var a0 = randf() * TAU
	var hh = h * randf_range(0.45, 1.0)
	var tt = t * randf_range(0.75, 1.0)
	var stepf = func(q: float):
		if not is_instance_valid(mi):
			return
		var u = q / tt
		var a = a0 + w * q
		mi.global_position = center + Vector3(cos(a), 0, sin(a)) * lerpf(r0, r1, u) + Vector3.UP * (0.2 + hh * u)
		mi.rotation = Vector3(q * 7.0, q * 5.0, q * 3.0)
	var tw = mi.create_tween()
	tw.tween_method(stepf, 0.0, tt, tt)
	tw.tween_callback(func():
		if not is_instance_valid(mi):
			return
		var a = a0 + w * tt
		var v = Vector3(-sin(a), 0, cos(a)) * w * r1 * 0.5 + Vector3(cos(a), 0, sin(a)) * 3.0 + Vector3.UP * 2.0
		var land = _land_rock(s, 1.2) if kind == CHIP else _land_soft(1.0)
		_fly(mi, mi.global_position, v, 18.0 if kind == CHIP else 9.0, Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), land))


# ================================================================== taijutsu parçaları
## Dönen tekmenin yay izi: dönüş düzleminde yatan, öne doğru kalınlaşan sürtme bandı + dış kenarda keskin çizgi
static func _kick_arc(pj: PathJutsu, at: Vector3, R: float, k: int, col := Color(0.93, 0.97, 0.9, 0.6), span := 1.6 * PI, tilt := 18.0) -> void:
	var a0 = randf() * TAU
	var hz = Vector3(cos(a0), 0, sin(a0))
	var axis = Vector3.UP.rotated(hz, deg_to_rad(tilt * (1.0 if k % 2 == 0 else -1.0)))
	var e1 = axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var e2 = axis.cross(e1).normalized()
	var pts = []
	var sides = []
	var widths = []
	var edge = []
	var ew = []
	var n = 28
	for i in n + 1:
		var u = float(i) / n
		var th = span * u
		var rd = e1 * cos(th) + e2 * sin(th)
		pts.append(at + rd * R)
		sides.append(rd)
		widths.append(0.95 * pow(u, 0.8) * clampf((1.0 - u) * 10.0 + 0.2, 0.0, 1.0))
		edge.append(at + rd * (R + 0.47 * pow(u, 0.8)))
		ew.append(0.07 * u)
	var band = _streak_mi(_strip_mesh(pts, sides, widths, col, at), {"breakup": 0.4, "soft": 0.55})
	pj.scene_add(band, at)
	_sweep(band, 0.09, 0.03, 0.18)
	var rim = _streak_mi(_ribbon_mesh(edge, ew, WHITE, at), {})
	pj.scene_add(rim, at)
	_sweep(rim, 0.09, 0.02, 0.14)


## Yaprak savruğu: teğet yönde dönerek fırlayan yapraklar
static func _leaf_swirl(pj: PathJutsu, at: Vector3, n: int, r: float, spd: float) -> void:
	for k in n:
		var a = randf() * TAU
		var dv = Vector3(cos(a), 0, sin(a))
		var tv = Vector3(-dv.z, 0, dv.x)
		_leaf(pj, at + dv * r + Vector3.UP * randf_range(-0.3, 0.3), tv * spd + dv * 1.5 + Vector3.UP * randf_range(0.5, 2.5), randf_range(0.13, 0.2))


## Zikzak atılış: kırık hız çizgileri, kalkışta toz, varışta sürtme izi + ileri püsküren toz
static func _zigzag(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var d = b - a
	d.y = 0.0
	if d.length() < 0.05:
		return
	var L = d.length()
	d = d.normalized()
	var side = d.cross(Vector3.UP).normalized()
	var ga = pj.gp(a)
	var gb = pj.gp(b)
	for k in 3:
		var hgt = Vector3.UP * (0.6 + k * 0.45)
		var sg = 1.0 if k % 2 == 0 else -1.0
		var m1 = a.lerp(b, 0.33) + side * 0.7 * sg + hgt
		var m2 = a.lerp(b, 0.66) - side * 0.7 * sg + hgt
		var pts = _seg(a + hgt, m1, 3)
		pts.pop_back()
		pts.append_array(_seg(m1, m2, 3))
		pts.pop_back()
		pts.append_array(_seg(m2, b + hgt, 3))
		_line(pj, pts, 0.16, 0.06, WHITE, 0.05, 0.05, 0.2, {"breakup": 0.3})
		if k == 1:
			_line(pj, pts, 0.05, 0.02, INKC, 0.05, 0.03, 0.15)
	# kalkış
	_puff(pj, ga + Vector3.UP * 0.2 - d * 0.3, -d * 3.0 + Vector3.UP * 0.8, 0.3, 0.8, 0.6, DUST)
	_puff(pj, ga + Vector3.UP * 0.2 + side * 0.3, -d * 2.0 + side * 1.5 + Vector3.UP * 0.6, 0.25, 0.7, 0.5, DUST)
	# varış: ayağın kaydığı iz + öne püsküren toz ve çimen
	var sk = _ground_strip(pj, [gb - d * minf(1.6, L * 0.5), gb - d * 0.6, gb], [0.15, 0.4, 0.3], Color(0.3, 0.23, 0.16, 0.7), 0.04, {"soft": 0.5})
	_sweep(sk, 0.06, 2.2, 0.8, false)
	for q in 3:
		_puff(pj, gb + Vector3.UP * 0.2 + side * randf_range(-0.4, 0.4), d * randf_range(3.0, 5.0) + Vector3.UP * 0.6, 0.25, 0.75, 0.6, DUST)
	_bits(pj, gb, 2, 2.5, 0.8, 0.12, TUFT, d * 2.0)


## Çapraz darbe (X): iki keskin çizgi art arda çapraz iner
static func _x_cut(pj: PathJutsu, at: Vector3, d: Vector3, side: Vector3) -> void:
	var a1 = at + side * 1.1 + Vector3.UP * 1.0 - d * 0.2
	var b1 = at - side * 1.1 - Vector3.UP * 1.0 - d * 0.2
	var a2 = at - side * 1.1 + Vector3.UP * 1.0 - d * 0.2
	var b2 = at + side * 1.1 - Vector3.UP * 1.0 - d * 0.2
	_line(pj, _seg(a1, b1, 8), 0.3, 0.3, WHITE, 0.05, 0.15, 0.2, {"edge_ink": 0.6})
	pj.after(0.05, func():
		_line(pj, _seg(a2, b2, 8), 0.3, 0.3, WHITE, 0.05, 0.12, 0.2, {"edge_ink": 0.6}))


## Daisenkō şeridi: anında çakan düz hız çizgileri, yerde iki kazınmış iz, ardından sırayla kalkan toz duvarı
static func _flash_lane(pj: PathJutsu, a: Vector3, b: Vector3, d: Vector3) -> void:
	var ga = pj.gp(a)
	var gb = pj.gp(b)
	var side = d.cross(Vector3.UP).normalized()
	for k in 8:
		var off = side * randf_range(-0.7, 0.7) + Vector3.UP * randf_range(0.35, 1.9)
		var col = WHITE if k < 6 else INKC
		_line(pj, _seg(a + off, b + off, 10), 0.14 if k < 6 else 0.05, 0.05, col, 0.07, 0.04 + k * 0.01, 0.25, {"breakup": 0.25})
	var gpts = []
	for i in 15:
		gpts.append(ga.lerp(gb, i / 14.0))
	for s in [-1.0, 1.0]:
		var sp = []
		for p in gpts:
			sp.append(p + side * 0.35 * s)
		var gs = _ground_strip(pj, sp, _taper(sp.size(), 0.35, 0.2, 4.0), Color(0.28, 0.21, 0.15, 0.65), 0.04, {"soft": 0.5, "breakup": 0.2})
		_sweep(gs, 0.08, 3.5, 0.8, false)
	# kalkış: geri püsküren toz, küçük çatlaklar, kalkan plakalar
	_cracks(pj, ga, 1.8, 5, 2.5)
	for q in 4:
		_puff(pj, ga + Vector3.UP * 0.3 + side * randf_range(-0.5, 0.5), -d * randf_range(3.0, 5.0) + Vector3.UP * 1.0, 0.35, 1.0, 0.8, DUST)
	_plate(pj, ga - d * 0.6, -d, 0.45, 35.0, 1.5)
	# geçişin ardından kalkan toz duvarı
	for i in 14:
		pj.after(0.03 * i, func():
			var p = ga.lerp(gb, (i + 0.5) / 14.0) + side * randf_range(-0.8, 0.8)
			_puff(pj, pj.gp(p) + Vector3.UP * 0.3, Vector3.UP * randf_range(1.0, 2.0) + d * 2.0 + side * randf_range(-1.0, 1.0), 0.45, 1.6, randf_range(1.3, 1.8), DUST, {"drag": 1.8})
			if i % 3 == 0:
				_bits(pj, pj.gp(p), 2, 3.0, 0.7, 0.12, TUFT, side * (4.0 if randf() < 0.5 else -4.0)))
	# varış: kayma izi, öne püsküren toz
	var sk = _ground_strip(pj, [gb - d * 1.8, gb - d * 0.8, gb], [0.25, 0.6, 0.4], Color(0.3, 0.23, 0.16, 0.7), 0.045, {"soft": 0.5})
	_sweep(sk, 0.05, 3.0, 0.8, false)
	for q in 5:
		_puff(pj, gb + Vector3.UP * 0.25 + side * randf_range(-0.6, 0.6), d * randf_range(4.0, 7.0) + Vector3.UP * 0.8, 0.35, 1.2, 0.9, DUST)


## Şelale tekmesi: aşağı inen sarmal perde + sarmalın çevresinde düşen dikey hız çizgileri
static func _fall_spin(pj: PathJutsu, at: Vector3) -> void:
	var a0 = randf() * TAU
	var pts = []
	var sides = []
	var n = 30
	for i in n + 1:
		var u = float(i) / n
		var a = a0 + u * TAU * 1.1
		pts.append(at + Vector3(cos(a), 0, sin(a)) * 1.5 + Vector3.UP * (0.8 - u * 1.8))
		sides.append(Vector3.UP)
	var band = _streak_mi(_strip_mesh(pts, sides, _taper(n + 1, 0.25, 0.65, 8.0), Color(0.86, 0.93, 1.0, 0.6), at), {"breakup": 0.5, "soft": 0.5})
	pj.scene_add(band, at)
	_sweep(band, 0.08, 0.02, 0.2)
	for k in 6:
		var a = randf() * TAU
		var p = at + Vector3(cos(a), 0, sin(a)) * randf_range(1.3, 1.8)
		_line(pj, _seg(p + Vector3.UP * 1.3, p - Vector3.UP * 1.0, 4), 0.06, 0.03, WHITE, 0.07, 0.0, 0.15)


## İnişte ağır yer darbesi: yere yatık basınç halkası, yassı yayılan toz eteği, çatlak, kalkan plakalar
static func _fall_slam(pj: PathJutsu, g: Vector3, s: float) -> void:
	_shock(pj, g + Vector3.UP * 0.15, Vector3.UP, 0.5, 3.2 * s, 0.3, Color(1, 1, 1, 0.7), 0.0, 0.9)
	for k in 12:
		var a = k * TAU / 12.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * 0.6 + Vector3.UP * 0.2, dv * 8.0 * s + Vector3.UP * 0.5, 0.35, 1.2 * s, 0.9, DUST, {"drag": 3.5})
	_cracks(pj, g, 2.6 * s, 7, 3.5)
	_plate_ring(pj, g, 1.1 * s, 6, 0.45, 35.0, 2.0)
	_bits(pj, g, 6, 4.0, 0.9, 0.14, TUFT)
	_bits(pj, g, 4, 4.0, 1.0, 0.1, CHIP)
	pj.shake(0.3 * s)


## Çakra kesiği hilali (mermi yerel ekseni: -Z ileri). Dört iç içe yarı saydam bant + dışta ince koyu çizgi; çapraz eğik
static func _crescent_meshes() -> Array:
	if _cache.has("crescent"):
		return _cache["crescent"]
	var out = []
	var tilt = Basis(Vector3.FORWARD, deg_to_rad(25.0))
	for b in 5:
		var R = 1.5 - b * 0.17
		var pts = []
		var sides = []
		var widths = []
		var n = 22
		for i in n + 1:
			var u = float(i) / n
			var a = deg_to_rad(lerpf(-75.0, 75.0, u))
			var rd = Vector3(sin(a), 0, -cos(a))
			pts.append(tilt * (rd * R + Vector3(0, 0, 1.15 + b * 0.1)))
			sides.append(tilt * rd)
			var w = (0.36 - b * 0.05) if b < 4 else 0.05
			widths.append(w * pow(sin(u * PI), 0.7))
		var col = Color(0.9, 0.93, 0.96, 0.78 - b * 0.12) if b < 4 else Color(0.35, 0.38, 0.43, 0.75)
		if b == 4:   # dış kenar çizgisi en dış yarıçapta
			for i in pts.size():
				var a2 = deg_to_rad(lerpf(-75.0, 75.0, float(i) / n))
				pts[i] = tilt * (Vector3(sin(a2), 0, -cos(a2)) * 1.69 + Vector3(0, 0, 1.15))
		out.append(_strip_mesh(pts, sides, widths, col, Vector3.ZERO))
	_cache["crescent"] = out
	return out


static func _crescent() -> Node3D:
	var root = Node3D.new()
	var k = 0
	for m in _crescent_meshes():
		var mi = _streak_mi(m, {"breakup": 0.45 if k < 4 else 0.0, "soft": 0.3, "edge_ink": 0.25 if k < 4 else 0.0})
		root.add_child(mi)
		k += 1
	return root


## Uçan hilalin arkasında sönen yankıları ve yerde bıraktığı ince kesik + yanlara savrulan toz
static func _crescent_trail(pj: PathJutsu, pr: Node3D) -> void:
	var prw = weakref(pr)
	var stt = {}
	pj.every(0.9, 0.04, func(i, _k):
		var p2 = prw.get_ref()
		if p2 == null or not is_instance_valid(p2):
			return
		var echo = _crescent()
		pj.scene_add(echo, p2.global_position)
		echo.global_basis = p2.global_basis
		var kids = echo.get_children()
		var fadef = func(v: float):
			for ch in kids:
				if is_instance_valid(ch):
					ch.set_instance_shader_parameter("fade", v)
		fadef.call(0.5)
		var tw = echo.create_tween()
		tw.tween_method(fadef, 0.5, 0.0, 0.16)
		tw.parallel().tween_property(echo, "scale", Vector3.ONE * 1.15, 0.16)
		tw.tween_callback(echo.queue_free)
		var g = pj.gp(p2.global_position)
		if p2.global_position.y - g.y < 2.6:
			if stt.has("last"):
				var l: Vector3 = stt["last"]
				var cut = _ground_strip(pj, [l, l.lerp(g, 0.5), g], [0.12, 0.14, 0.12], Color(0.12, 0.09, 0.07, 0.85), 0.05)
				cut.sorting_offset = 0.5
				_sweep(cut, 0.0, 1.6, 0.6, false)
				var lip = _ground_strip(pj, [l, l.lerp(g, 0.5), g], [0.35, 0.4, 0.35], Color(0.66, 0.56, 0.42, 0.55), 0.035, {"soft": 0.7})
				_sweep(lip, 0.0, 1.4, 0.6, false)
			stt["last"] = g
			if i % 2 == 0:
				var sd = p2.global_basis.x.normalized() * (1.0 if randf() < 0.5 else -1.0)
				_puff(pj, g + Vector3.UP * 0.2, sd * 3.0 + Vector3.UP * 0.8, 0.25, 0.8, 0.6, DUST)
				_bits(pj, g, 1, 2.5, 0.8, 0.12, TUFT, sd * 2.5)
		else:
			stt.erase("last"), Callable())


## Kılıç savuruşu anında karakterin önünde yay çizen kalın sürtme
static func _swing_smear(pj: PathJutsu, c: Node3D) -> void:
	var d = c.face_dir()
	d.y = 0.0
	d = d.normalized() if d.length() > 0.05 else Vector3.FORWARD
	var side = d.cross(Vector3.UP).normalized()
	var ctr = c.global_position + Vector3.UP * 1.2
	var tilt = Basis(d, deg_to_rad(25.0))
	var pts = []
	var sides = []
	var n = 20
	for i in n + 1:
		var u = float(i) / n
		var a = deg_to_rad(lerpf(80.0, -80.0, u))
		var rd = tilt * (d * cos(a) + side * sin(a))
		pts.append(ctr + rd * 1.3)
		sides.append(rd)
	var mi = _streak_mi(_strip_mesh(pts, sides, _taper(n + 1, 0.1, 0.55, 8.0), Color(0.92, 0.95, 1.0, 0.65), ctr), {"breakup": 0.35, "soft": 0.4})
	pj.scene_add(mi, ctr)
	_sweep(mi, 0.06, 0.0, 0.15)


## Hilal isabeti: büyük kesik yayı, kopan kısa parçalar, basınç halkası, yere yakınsa toz
static func _slash_hit(pj: PathJutsu, p: Vector3, face: Vector3) -> void:
	var d = Vector3(face.x, 0, face.z)
	if d.length() < 0.05:
		d = Vector3.FORWARD
	d = d.normalized()
	var side = d.cross(Vector3.UP).normalized()
	var tilt = Basis(d, deg_to_rad(25.0))
	var pts = []
	var sides = []
	var n = 20
	for i in n + 1:
		var a = deg_to_rad(lerpf(-60.0, 60.0, float(i) / n))
		var rd = tilt * (side * sin(a) + Vector3.UP * cos(a) * 0.4 + d * cos(a) * 0.3).normalized()
		pts.append(p + rd * 1.6)
		sides.append(rd)
	var mi = _streak_mi(_strip_mesh(pts, sides, _taper(n + 1, 0.45, 0.45, 5.0), Color(0.95, 0.97, 1.0, 0.85), p), {"edge_ink": 0.5, "breakup": 0.3})
	pj.scene_add(mi, p)
	_sweep(mi, 0.06, 0.05, 0.2)
	for k in 6:
		var dir = (side * randf_range(-1, 1) + Vector3.UP * randf_range(-0.4, 0.8) + d * 0.8).normalized()
		_line(pj, _seg(p + dir * 0.3, p + dir * randf_range(1.0, 1.8), 4), 0.08, 0.0, WHITE, 0.05, 0.0, 0.12)
	_shock(pj, p, d, 0.3, 1.8, 0.18, WHITE, 0.4, 0.5)
	var g = pj.gp(p)
	if p.y - g.y < 2.2:
		_dust_ring(pj, g, 0.3, 3.0, 5, DUST, 0.35, 0.7)


## İaido çizgisi: tek ince parlak çizgi + soluk geniş bant, yerde kılıç kesiği, yol boyunca geç kalkan ince toz
static func _iai_line(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var d = b - a
	d.y = 0.0
	if d.length() < 0.05:
		return
	d = d.normalized()
	var h = Vector3.UP * 1.1
	_line(pj, _seg(a + h, b + h, 12), 0.05, 0.05, Color(1, 1, 1, 1), 0.04, 0.12, 0.25)
	_line(pj, _seg(a + h, b + h, 12), 0.4, 0.3, Color(0.95, 0.92, 0.85, 0.35), 0.05, 0.08, 0.3, {"soft": 1.0})
	var ga = pj.gp(a)
	var gb = pj.gp(b)
	var gpts = _seg(ga, gb, 10)
	var cut = _ground_strip(pj, gpts, _taper(gpts.size(), 0.08, 0.08, 6.0), Color(0.1, 0.08, 0.06, 0.85), 0.05)
	cut.sorting_offset = 0.5
	_sweep(cut, 0.06, 2.0, 0.6, false)
	var lip = _ground_strip(pj, gpts, _taper(gpts.size(), 0.22, 0.22, 6.0), Color(0.66, 0.56, 0.42, 0.55), 0.035, {"soft": 0.7})
	_sweep(lip, 0.06, 1.8, 0.6, false)
	for i in 6:
		pj.after(0.08 + i * 0.025, func():
			var p = ga.lerp(gb, (i + 0.5) / 6.0)
			_puff(pj, pj.gp(p) + Vector3.UP * 0.15, Vector3.UP * 0.8 + d * 1.0, 0.18, 0.55, 0.7, DUST))
	for q in 2:
		_puff(pj, gb + Vector3.UP * 0.2 - d * 0.4, -d * 2.5 + Vector3.UP * 0.6, 0.2, 0.6, 0.5, DUST)


## Alevli kesik (Homura): çapraz yay, dışı kızıl-turuncu dilli alev, ortası beyaz-sarı; titreşerek yanar, kor taneleri yükselir,
## kıvılcımlar fırlar, yerde kömürleşmiş ince iz kalır
static func _flame_cut(pj: PathJutsu, at: Vector3, face: Vector3) -> void:
	var d = Vector3(face.x, 0, face.z)
	if d.length() < 0.05:
		d = Vector3.FORWARD
	d = d.normalized()
	var side = d.cross(Vector3.UP).normalized()
	var p0 = at + side * 1.2 + Vector3.UP * 0.9
	var p1 = at - side * 1.2 - Vector3.UP * 0.9
	var mid = at - d * 0.4
	var pts = []
	var n = 18
	for i in n + 1:
		var u = float(i) / n
		pts.append(p0.lerp(mid, u).lerp(mid.lerp(p1, u), u))
	var ph = randf() * TAU
	var layers = [[0.5, Color(0.92, 0.3, 0.08, 0.85), 0.25, 0.5], [0.3, Color(1.0, 0.62, 0.2, 0.95), 0.15, 0.0], [0.11, Color(1.0, 0.96, 0.78, 1.0), 0.0, 0.0]]
	for L in layers:
		var widths = []
		for i in n + 1:
			var u = float(i) / n
			widths.append(L[0] * pow(sin(u * PI), 0.8) * (1.0 + 0.35 * sin(u * 37.0 + ph)))
		var mi = _streak_mi(_ribbon_mesh(pts, widths, L[1], at), {"breakup": L[2], "edge_ink": L[3]})
		pj.scene_add(mi, at)
		mi.set_instance_shader_parameter("head", 0.0)
		var tw = mi.create_tween()
		tw.tween_method(_pf(mi, "head"), 0.0, 1.0, 0.05)
		tw.tween_method(func(q: float):
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("fade", (0.8 + 0.2 * sin(q * 55.0 + ph)) * (1.0 - q * q * 0.5)), 0.0, 1.0, 0.65)
		tw.tween_method(_pf(mi, "tail"), 0.0, 1.0, 0.2).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(_pf(mi, "fade"), 0.5, 0.0, 0.2)
		tw.tween_callback(mi.queue_free)
	for k in 14:   # kor taneleri
		var p = pts[randi() % pts.size()]
		_puff(pj, p, Vector3(randf_range(-0.8, 0.8), randf_range(1.0, 2.2), randf_range(-0.8, 0.8)), randf_range(0.05, 0.09), 0.03, randf_range(0.6, 1.0), Color(1.0, 0.55, 0.15), {"glow": 1.2, "ink_at": 2.0, "drag": 1.0})
	for k in 8:   # kıvılcım
		var p = pts[randi() % pts.size()]
		var dir = (side * randf_range(-1, 1) + Vector3.UP * randf_range(0.0, 1.0) + d * randf_range(0.2, 1.0)).normalized()
		_line(pj, _seg(p, p + dir * randf_range(0.8, 1.4), 3), 0.05, 0.0, Color(1.0, 0.85, 0.4, 1.0), 0.04, 0.0, 0.1)
	var g0 = pj.gp(p0 + Vector3.DOWN * 3.0)
	var g1 = pj.gp(p1)
	var gl = _seg(g0, g1, 6)
	var char_l = _ground_strip(pj, gl, _taper(gl.size(), 0.18, 0.18, 5.0), Color(0.12, 0.08, 0.06, 0.75), 0.05)
	char_l.sorting_offset = 0.5
	_sweep(char_l, 0.06, 2.5, 0.8, false)
	var ember = _ground_strip(pj, gl, _taper(gl.size(), 0.4, 0.4, 5.0), Color(0.95, 0.42, 0.1, 0.5), 0.04, {"soft": 0.8})
	_sweep(ember, 0.06, 0.6, 0.6, false)
	var lt = OmniLight3D.new()
	lt.light_color = Color(1.0, 0.6, 0.25)
	lt.omni_range = 4.0
	lt.light_energy = 1.5
	pj.scene_add(lt, at)
	var tw2 = lt.create_tween()
	tw2.tween_property(lt, "light_energy", 0.0, 0.7)
	tw2.tween_callback(lt.queue_free)


## Ejder Tanrı (ref: dönen beyaz hortum gövde, sarmal halatlar, boynuzlu yeleli baş, sarı gözler, çevresinde dolanan ince
## camgöbeği yörünge çizgileri, gövdeye kapılıp yükselen taş ve yaprak)
static func _dragon(pj: PathJutsu, at: Vector3, face: Vector3) -> void:
	var root = Node3D.new()
	pj.scene_add(root, at)
	var f = Vector3(face.x, 0, face.z)
	if f.length() < 0.01:
		f = Vector3.FORWARD
	root.global_basis = Basis.looking_at(-f.normalized(), Vector3.UP)   # yerel +Z = ileri
	var cps = [Vector3(0, 0, 0), Vector3(0.3, 1.8, -0.2), Vector3(-0.5, 3.6, -0.4), Vector3(0.4, 5.4, -0.6), Vector3(-0.3, 7.2, -0.3),
		Vector3(0.2, 8.8, 0.4), Vector3(0.0, 10.0, 1.5), Vector3(0.0, 10.4, 2.9), Vector3(0.0, 9.9, 4.0)]
	var spine = _catmull(cps, 56)
	var fr = _frames(spine)
	var n = spine.size()
	var parts = []
	var core_r = []
	for i in n:
		var u = float(i) / (n - 1)
		core_r.append(0.42 * (1.0 - 0.3 * u) * clampf(u * 8.0, 0.25, 1.0))
	parts.append(_cel_mi(_tube_mesh(spine, core_r, 10, Color(0.82, 0.93, 1.0)), Color.WHITE, {"glow": 0.75, "wind": 1.0, "ink_at": 2.0, "reveal": 0.0}))
	for s in 3:   # gövdeyi saran üç halat (bükülmüş hortum)
		var sp = []
		var rr = []
		for i in n:
			var u = float(i) / (n - 1)
			var ang = u * TAU * 4.0 + s * TAU / 3.0
			var off = 0.5 * (1.0 - 0.3 * u) * clampf(u * 6.0, 0.3, 1.0)
			sp.append(spine[i] + (fr[i][0] * cos(ang) + fr[i][1] * sin(ang)) * off)
			rr.append(0.33 * (1.0 - 0.3 * u) * clampf(u * 8.0, 0.25, 1.0))
		parts.append(_cel_mi(_tube_mesh(sp, rr, 8, Color(0.97, 0.99, 1.0)), Color.WHITE, {"glow": 0.75, "wind": 1.0, "ink_at": 2.0, "reveal": 0.0}))
	for mi in parts:
		root.add_child(mi)
		var tw = mi.create_tween()
		tw.tween_method(_pf(mi, "reveal"), 0.0, 1.02, 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.85)
		tw.tween_method(_pf(mi, "vanish"), -0.01, 1.0, 0.5).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(_pf(mi, "dis"), 0.0, 0.8, 0.5)
	# baş
	var head = _dragon_head()
	root.add_child(head)
	var tip: Vector3 = spine[n - 1]
	var tdir: Vector3 = (spine[n - 1] - spine[n - 3]).normalized()
	head.transform = Transform3D(Basis.looking_at(tdir, Vector3.UP if absf(tdir.y) < 0.95 else Vector3.FORWARD), tip)
	head.scale = Vector3.ONE * 0.01
	var th = head.create_tween()
	th.tween_interval(0.3)
	th.tween_property(head, "scale", Vector3.ONE * 1.3, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	th.tween_interval(0.8)
	th.tween_method(_dis_all(head), 0.0, 1.0, 0.45)
	th.parallel().tween_property(head, "position", tip + Vector3.UP * 1.2, 0.45)
	# yörünge çizgileri
	for r in 3:
		var ring = Node3D.new()
		root.add_child(ring)
		ring.position = spine[int((0.3 + r * 0.25) * (n - 1))]
		ring.rotation = Vector3(deg_to_rad(randf_range(-22, 22)), randf() * TAU, deg_to_rad(randf_range(-22, 22)))
		var rp = []
		for i in 41:
			var a = TAU * i / 40.0
			rp.append(Vector3(cos(a) * 2.5, sin(a * 2.0) * 0.25, sin(a) * 1.7))
		var rm = _streak_mi(_ribbon_mesh(rp, _taper(41, 0.08, 0.08, 3.0), Color(0.75, 0.97, 1.0, 0.85), Vector3.ZERO), {"soft": 0.5})
		ring.add_child(rm)
		_sweep(rm, 0.25, 0.75 + r * 0.05, 0.3)
		var tr = ring.create_tween()
		tr.tween_property(ring, "rotation:y", ring.rotation.y - TAU * 1.5, 1.4)
	var lt = OmniLight3D.new()
	lt.light_color = Color(0.6, 0.95, 1.0)
	lt.omni_range = 10.0
	lt.light_energy = 0.0
	root.add_child(lt)
	lt.position = Vector3(0, 6, 0)
	var tl = lt.create_tween()
	tl.tween_property(lt, "light_energy", 2.0, 0.3)
	tl.tween_interval(0.9)
	tl.tween_property(lt, "light_energy", 0.0, 0.5)
	pj.free_after(1.9, root)
	# gövdeye kapılıp yükselen taş ve yapraklar
	for k in 8:
		_orbit_bit(pj, at, CHIP, 0.8, 2.0, 9.0, 7.0, 0.9, randf_range(0.08, 0.16))
	for k in 8:
		_orbit_bit(pj, at, LEAF, 0.9, 2.4, 9.0, 6.0, 1.0, randf_range(0.14, 0.2))


## Ejder başı (yerel -Z = burun): kafatası, burun, açık çene, dişler, geriye kıvrık boynuzlar, dikenli yele, sarı gözler, uzun bıyıklar
static func _dragon_head() -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	var wc = Color(0.97, 0.99, 1.0)
	var bc = Color(0.85, 0.94, 1.0)
	b.add("sphere", Vector3(0, 0, 0.05), Vector3(0.9, 0.75, 1.1), wc, Vector3.ZERO, 10)
	b.add("box", Vector3(0, -0.02, -0.72), Vector3(0.6, 0.38, 0.9), wc, Vector3(8, 0, 0))
	b.add("box", Vector3(0, -0.4, -0.58), Vector3(0.5, 0.16, 0.85), bc, Vector3(-18, 0, 0))
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.2, -0.27, -1.0), Vector3(0.08, 0.2, 0.08), wc, Vector3(180, 0, 0), 5)
		b.add("cone", Vector3(sx * 0.18, -0.32, -0.75), Vector3(0.07, 0.16, 0.07), wc, Vector3(0, 0, 0), 5)
		var hb = Vector3(sx * 0.3, 0.3, 0.2)
		var ha = Vector3(sx * 0.18, 0.45, 0.88).normalized()
		b.add_xf("cone", _axis_xf(hb + ha * 0.8, ha, Vector3(0.16, 1.6, 0.16)), bc, 6)
		b.add("sphere", Vector3(sx * 0.27, 0.1, -0.36), Vector3(0.17, 0.15, 0.12), Color(1.0, 0.8, 0.38), Vector3.ZERO, 8)
	for k in 7:   # yele
		var a = lerpf(-1.3, 1.3, k / 6.0)
		var ma = Vector3(sin(a) * 0.9, 0.35 + cos(a) * 0.2, 0.75).normalized()
		b.add_xf("cone", _axis_xf(Vector3(sin(a) * 0.35, 0.05, 0.4) + ma * 0.45, ma, Vector3(0.14, 0.9, 0.14)), wc, 5)
	var mi = _cel_mi(b.build(null), Color.WHITE, {"glow": 0.8, "ink_at": 2.0})
	root.add_child(mi)
	for sx in [-1.0, 1.0]:   # bıyıklar: burundan geriye akan ince çizgiler
		var wp = _catmull([Vector3(sx * 0.25, -0.1, -1.05), Vector3(sx * 1.2, 0.3, -0.4), Vector3(sx * 2.0, -0.2, 1.5), Vector3(sx * 2.6, 0.4, 3.6)], 16)
		var wm = _streak_mi(_ribbon_mesh(wp, _taper(17, 0.07, 0.02, 4.0), Color(0.85, 1.0, 1.0, 0.9), Vector3.ZERO), {})
		root.add_child(wm)
	return root


## +Y ekseni axis'e bakan, size ölçekli dönüşüm (MB primitifi için)
static func _axis_xf(pos: Vector3, axis: Vector3, size: Vector3) -> Transform3D:
	var y = axis.normalized()
	var ref = Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT
	var x = y.cross(ref).normalized()
	var z = x.cross(y).normalized()
	return Transform3D(Basis(x * size.x, y * size.y, z * size.z), pos)


## Kongōriki girdabı: huni gibi açılan, dönen sarmal rüzgâr perdeleri + içinde dönerek yükselen kaya ve çimen
static func _vortex(pj: PathJutsu, at: Vector3, R: float, H: float, dur: float) -> void:
	var root = Node3D.new()
	pj.scene_add(root, at)
	for s in 5:
		var pts = []
		var sides = []
		var widths = []
		var ph = s * TAU / 5.0
		var y0 = randf_range(0.0, 0.6)
		for i in 33:
			var u = i / 32.0
			var a = ph + u * TAU * 1.6
			pts.append(Vector3(cos(a), 0, sin(a)) * lerpf(1.0, R, pow(u, 0.8)) + Vector3.UP * (y0 + u * H))
			sides.append(Vector3.UP)
			widths.append(lerpf(0.5, 1.4, u) * clampf(minf(u, 1.0 - u) * 6.0 + 0.1, 0.0, 1.0))
		var mi = _streak_mi(_strip_mesh(pts, sides, widths, Color(0.9, 0.93, 0.86, 0.5), Vector3.ZERO), {"breakup": 0.45, "soft": 0.7})
		root.add_child(mi)
		_sweep(mi, 0.25, dur - 0.25, 0.35)
	var tw = root.create_tween()
	tw.tween_property(root, "rotation:y", -TAU * 2.2, dur + 0.4)
	tw.tween_callback(root.queue_free)
	for k in 8:
		_orbit_bit(pj, at, CHIP, 1.2, R * 0.9, H * 0.8, 6.5, dur * 0.9, randf_range(0.1, 0.18))
	for k in 8:
		_orbit_bit(pj, at, TUFT, 1.4, R, H * 0.7, 6.0, dur * 0.85, randf_range(0.14, 0.2))


# ================================================================== doton parçaları
## Yerin yarılması (dalış / çıkış): kalkan plakalar, savrulan kaya, yükselen soluk gri toz dalgası, çatlaklar
static func _rupture(pj: PathJutsu, g: Vector3, s: float) -> void:
	_plate_ring(pj, g, 0.9 * s, 7, 0.5 * s, 40.0, 1.6)
	_bits(pj, g, 10, 5.0 * s, 1.0, 0.13, CHIP)
	for k in 8:
		var a = randf() * TAU
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, g + dv * 0.5 + Vector3.UP * 0.4, Vector3.UP * randf_range(3.5, 6.0) + dv * 2.0, 0.6 * s, 2.0 * s, randf_range(1.0, 1.4), GREY_DUST, {"drag": 2.0})
	_dust_ring(pj, g, 0.6, 4.0 * s, 6, GREY_DUST, 0.45 * s, 0.9)
	_cracks(pj, g, 2.2 * s, 7, 3.0)
	_shock(pj, g + Vector3.UP * 0.12, Vector3.UP, 0.4, 2.6 * s, 0.3, Color(0.85, 0.78, 0.66, 0.55), 0.0, 0.9)


## Yeraltında ilerleyiş izi: üstte toprağı yaran V biçimli kalkan plakalar, iki yana savrulan gri toz, kaya kırıntısı
static func _wake(pj: PathJutsu, p: Vector3, dir: Vector3) -> void:
	var side = dir.cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:
		_plate(pj, p + side * 0.5 * s - dir * 0.2, side * s + dir * 0.3, randf_range(0.35, 0.5), 45.0, 0.6)
		_puff(pj, p + side * 0.4 * s + Vector3.UP * 0.3, side * s * randf_range(2.5, 3.5) + Vector3.UP * 1.2 - dir * 0.8, 0.35, 1.1, 0.9, GREY_DUST)
	_bits(pj, p, 2, 3.0, 1.0, 0.1, CHIP, -dir * 1.5)


## Yeraltı yolunun ardından kalan yarık: koyu kırık toprak çizgisi + iki yanda kabarmış açık toprak
static func _furrow(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var pts = [a, a.lerp(b, 0.5), b]
	var lip = _ground_strip(pj, pts, [0.9, 1.1, 0.9], Color(0.6, 0.5, 0.38, 0.6), 0.035, {"soft": 0.6, "breakup": 0.25})
	_sweep(lip, 0.0, 3.0, 0.8, false)
	var crk = _ground_strip(pj, pts, [0.35, 0.45, 0.35], Color(0.18, 0.13, 0.09, 0.85), 0.05, {"breakup": 0.15})
	crk.sorting_offset = 0.5
	_sweep(crk, 0.0, 3.0, 0.8, false)


## Dochū Senkō işleyişi (genel gizlenme kuralı, aynen): görünmezlik, düşman hedef kaybı, beden 4 sn görünmez
static func _burrow_cast(pj: PathJutsu, c: Node3D) -> void:
	var d: Dictionary = Data.jutsu.get("doton_dochu_senko", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	if c.get("model"):
		c.model.visible = false
		c.get_tree().create_timer(minf(dur, 4.0)).timeout.connect(func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = true)
	Sfx.play("earth", c.global_position)


## Kütlenin oluşumu: hedefin çevresinde yerden kopan taşlar havada büyüyen bloğa uçup katılır
static func _converge(pj: PathJutsu, at: Vector3, target: Node3D, t: float) -> void:
	var tw_ref = weakref(target)
	for k in 12:
		var a = randf() * TAU
		var p0 = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 4.5)) + Vector3.UP * 0.2
		var mi = _cel_mi(_rock_mesh(randi() % 6), ROCK, {"speck": 0.6, "ink_at": 0.8})
		pj.scene_add(mi, p0)
		var s = randf_range(0.15, 0.3)
		mi.scale = Vector3.ONE * s
		var off = Vector3(randf_range(-1.6, 1.6), randf_range(-1.2, 1.2), randf_range(-1.6, 1.6))
		var dt = t * randf_range(0.6, 1.0)
		var stepf = func(q: float):
			var tg2 = tw_ref.get_ref()
			if not is_instance_valid(mi) or tg2 == null or not is_instance_valid(tg2):
				return
			mi.global_position = p0.lerp(tg2.global_position + off, q * q)
			mi.rotation = Vector3(q * 6.0, q * 4.0, q * 5.0)
		var tw = mi.create_tween()
		tw.tween_method(stepf, 0.0, 1.0, dt)
		tw.tween_callback(mi.queue_free)
	_bits(pj, pj.gp(at), 6, 2.5, 0.8, 0.1, CHIP)


## Ganseki Atsu çarpması: blok kenarlarında kalkan plakalar, köşelerden yürüyen çatlaklar, kenarlardan fışkıran toz eteği, kaya
static func _press_impact(pj: PathJutsu, at: Vector3, yaw: float) -> void:
	var bas = Basis(Vector3.UP, yaw)
	for e in 4:
		var nrm = bas * Vector3(cos(e * PI * 0.5), 0, sin(e * PI * 0.5))
		var tv = Vector3(-nrm.z, 0, nrm.x)
		for j in 3:
			var p = at + nrm * 2.35 + tv * lerpf(-1.5, 1.5, j / 2.0)
			_plate(pj, p, nrm, randf_range(0.6, 0.85), randf_range(30.0, 45.0), randf_range(2.2, 2.8))
		for j in 4:
			var p = at + nrm * 2.1 + tv * randf_range(-1.8, 1.8)
			_puff(pj, p + Vector3.UP * 0.4, nrm * randf_range(6.0, 9.0) + Vector3.UP * 0.8, 0.7, 2.0, randf_range(1.1, 1.5), Color(0.74, 0.64, 0.5), {"drag": 2.5})
	_cracks(pj, at, 5.5, 12, 5.0, 2.2)
	_shock(pj, at + Vector3.UP * 0.15, Vector3.UP, 2.5, 7.0, 0.35, Color(0.85, 0.78, 0.66, 0.55), 0.0, 0.9)
	_bits(pj, at + Vector3.UP * 0.3, 16, 7.0, 0.7, 0.18, CHIP)


## Blok süre sonunda parçalanır: büyük kaya parçaları yığılıp düşer, toz kalkar, parçalar yerde kalıp gömülür
static func _crumble(pj: PathJutsu, b: Node3D) -> void:
	if not is_instance_valid(b):
		return
	var pos = b.global_position
	var bas = Basis(Vector3.UP, b.rotation.y)
	b.queue_free()
	for x in [-1.0, 1.0]:
		for y in [-0.6, 0.7]:
			for z in [-1.0, 1.0]:
				var off = bas * Vector3(x, y, z)
				var mi = _cel_mi(_rock_mesh(randi() % 6), Color(0.62, 0.48, 0.34), {"speck": 0.7, "ink_at": 0.8, "cracks": 0.5, "shadow": true})
				var s = randf_range(1.1, 1.5)
				pj.scene_add(mi, pos + off)
				mi.scale = Vector3.ONE * s
				var v = Vector3(off.x, 0, off.z).normalized() * randf_range(1.5, 3.0) + Vector3.UP * randf_range(0.5, 2.0)
				_fly(mi, pos + off, v, 22.0, Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), _land_rock(s, 2.0))
	for k in 8:
		var a = randf() * TAU
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, pos + dv * 1.5, dv * 3.0 + Vector3.UP * 1.5, 0.6, 1.8, 1.2, Color(0.74, 0.64, 0.5))


## Kum dansı alanı: yere yayılan kum örtüsü, iki halka kum tepesi yükselir ve ters yönlerde dönerek dalgalanır, sonra çöker
static func _sand_field(pj: PathJutsu, at: Vector3, dur: float) -> void:
	_ground_patch(pj, at, 5.2, 0.0, SAND, SAND.darkened(0.2), 0.25, 0.35, dur + 1.2, {"speck": 0.7, "ink_at": 2.0})
	for ring in 2:
		var root = Node3D.new()
		pj.scene_add(root, at + Vector3.DOWN * 0.15)
		var cnt = 7 if ring == 0 else 4
		var R = 3.4 if ring == 0 else 1.8
		var sz = Vector3(1.9, 0.75, 1.1) if ring == 0 else Vector3(1.1, 0.5, 0.7)
		for k in cnt:
			var a = k * TAU / cnt + randf_range(-0.15, 0.15)
			var dn = _cel_mi(_dune_mesh(randi() % 4), Color.WHITE, {"speck": 0.8, "ink_at": 0.85})
			root.add_child(dn)
			dn.position = Vector3(cos(a), 0, sin(a)) * R
			dn.rotation.y = -(a + PI * 0.5)
			dn.scale = Vector3(sz.x, 0.02, sz.z)
			var ph = randf() * TAU
			var full = sz * randf_range(0.85, 1.15)
			var tw = dn.create_tween()
			tw.tween_interval(k * 0.03)
			tw.tween_property(dn, "scale", full, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_method(func(q: float):
				if is_instance_valid(dn):
					dn.scale = Vector3(full.x * (1.0 + 0.1 * sin(q * 5.0 + ph)), full.y * (0.8 + 0.3 * sin(q * 3.5 + ph)), full.z), 0.0, dur, dur - 0.35)
			tw.tween_property(dn, "scale", Vector3(full.x * 1.1, 0.02, full.z * 1.1), 0.6).set_ease(Tween.EASE_IN)
		var tr = root.create_tween()
		tr.tween_property(root, "rotation:y", -TAU * 0.5 if ring == 0 else TAU * 0.4, dur + 0.9)
		tr.tween_callback(root.queue_free)


## Kum dansı her vuruşu: dönen kum bulutu, kum perdeleri, savrulan kum taneleri
static func _sand_tick(pj: PathJutsu, at: Vector3) -> void:
	for k in 4:
		var a = randf() * TAU
		var dv = Vector3(cos(a), 0, sin(a))
		var tv = Vector3(-dv.z, 0, dv.x)
		_puff(pj, at + dv * randf_range(2.4, 4.6) + Vector3.UP * 0.4, tv * 6.0 + Vector3.UP * 1.2, 0.5, 1.6, 0.9, SAND, {"drag": 1.4})
	for k in 2:
		var a0 = randf() * TAU
		var r = randf_range(2.6, 4.4)
		var h = randf_range(0.3, 1.6)
		var pts = []
		var sides = []
		for i in 13:
			var a = a0 + 1.2 * i / 12.0
			pts.append(at + Vector3(cos(a), 0, sin(a)) * r + Vector3.UP * (h + 0.4 * i / 12.0))
			sides.append(Vector3.UP)
		var mi = _streak_mi(_strip_mesh(pts, sides, _taper(13, 0.45, 0.7, 5.0), Color(SAND.r, SAND.g, SAND.b, 0.6), at), {"breakup": 0.5, "soft": 0.6})
		pj.scene_add(mi, at)
		_sweep(mi, 0.15, 0.05, 0.25)
	for k in 4:
		var a = randf() * TAU
		var dv = Vector3(cos(a), 0, sin(a))
		_chip(pj, at + dv * randf_range(2.0, 4.0) + Vector3.UP * 0.3, Vector3(-dv.z, 0, dv.x) * 5.0 + Vector3.UP * 3.0, 0.06, SAND, 0.6)


# ================================================================== TEKNİKLER

## Konoha Tsumuji Senpū — havada art arda dönen tekmeler: her tekme kendi eğik düzleminde yay çizen sürtme bandı bırakır,
## yapraklar teğet yönde savrulup salınarak süzülür; kalkışta toz ve koparılan çimen
static func konoha_tsumuji_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 4.0, 6.0 if tt else 2.0)
	pj.busy(c, 0.8)
	var g0 = pj.gp(c.global_position)
	_dust_ring(pj, g0, 0.4, 3.5, 7, DUST, 0.35, 0.7)
	_bits(pj, g0, 5, 3.5, 1.0, 0.13, TUFT)
	_bits(pj, g0, 6, 3.0, 1.3, 0.16, LEAF)
	for k in 4:
		pj.after(0.12 + k * 0.12, func():
			if not pj.live(c):
				return
			var at = c.global_position + Vector3.UP * 1.0
			_kick_arc(pj, at, 1.6, k)
			_leaf_swirl(pj, at, 5, 1.4, 5.0)
			var hs = pj.hit(c, at, 1.9, pj.inf(c, "konoha_tsumuji_senpu", 0.35, {"knock": 4.0, "launch": 2.0, "kind": "heavy"}))
			if not hs.is_empty():
				_blow(pj, hs[0].global_position + Vector3.UP, 0.9, hs[0].global_position - c.global_position, false))
	Sfx.play("whoosh", c.global_position, 1.4)


## Geki Konoha Kongōriki Senpū — önce çevredeki toz merkeze emilir; sonra huni gibi açılan, dönen sarmal rüzgâr perdeleri
## içinde kaya ve çimen dönerek yükselir; her tekmede yay izi + çarpma çizgileri; yerde kazınmış halka ve çatlaklar kalır
static func geki_konoha_kongoriki_senpu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(c.global_position)
	for k in 8:
		var a = k * TAU / 8.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(pj, at + dv * 4.2 + Vector3.UP * 0.3, -dv * 7.0 + Vector3.UP * 1.0, 0.5, 0.9, 0.45, DUST, {"drag": 3.0})
	_vortex(pj, at, 4.0, 6.5, 1.0)
	_ground_patch(pj, at, 4.4, 1.4, SOIL, SOIL_D, 0.15, 0.3, 3.5, {"speck": 0.6, "ink_at": 2.0})
	for k in 6:
		pj.after(k * 0.12, func():
			if not pj.live(c):
				return
			var dir = c.face_dir().rotated(Vector3.UP, k * 1.05)
			_kick_arc(pj, c.global_position + Vector3.UP * (0.6 + k * 0.15), 1.7, k, Color(0.95, 0.97, 0.92, 0.6), 1.2 * PI, 10.0)
			_burst_lines(pj, c.global_position + Vector3.UP + dir * 1.5, 6, 1.6, dir)
			pj.shake(0.2)
			for e in pj.enemies_near(c, c.global_position, 4.5):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "geki_konoha_kongoriki_senpu", 0.35, {"knock": 12.0, "launch": 6.0, "kind": "heavy"})))
	_cracks(pj, at, 4.0, 9, 4.0)
	Sfx.play("whoosh", at, 0.9)


## Kakuran Taijutsu — hedefin çevresinde zikzak atılışlar: kırık hız çizgileri, kalkışta geri püsküren toz, varışta ayak
## kayma izi ve öne savrulan çimen; her varışta çarpma halkası
static func kakuran_taijutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 0.9)
	if not tt:
		return
	for k in 3:
		pj.after(0.1 + k * 0.18, func():
			if not pj.live(c) or not pj.live(tt):
				return
			var a = randf() * TAU
			var from = c.global_position
			c.global_position = pj.gp(tt.global_position + Vector3(cos(a), 0, sin(a)) * 1.6)
			_zigzag(pj, from, c.global_position)
			var v = tt.global_position - c.global_position
			c.facing = atan2(-v.x, -v.z)
			_blow(pj, tt.global_position + Vector3.UP, 0.8, v, false)
			pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.4, pj.inf(c, "kakuran_taijutsu", 0.45, {"knock": 3.0, "kind": "heavy"})))
	Sfx.play("whoosh", c.global_position, 1.5)


## Konoha Daisenkō — göz açıp kapayana dek 14 m: anında çakan düz hız çizgileri, yerde iki kazınmış iz, geçişin ardından
## sırayla kalkan toz duvarı; hattaki her düşmana çapraz (X) darbe
static func konoha_daisenko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var d = pj.fwd(c, t)
	var a = c.global_position
	var b = pj.gp(a + d * 14.0)
	_flash_lane(pj, a, b, d)
	c.global_position = b
	pj.after(0.1, func():
		var side = d.cross(Vector3.UP).normalized()
		for e in pj.enemies_near(c, a.lerp(b, 0.5), 8.0):
			if pj.live(e):
				_x_cut(pj, e.global_position + Vector3.UP, d, side)
				_blow(pj, e.global_position + Vector3.UP, 1.0, d, false)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "konoha_daisenko", 1.6, {"knock": 10.0, "kind": "heavy", "stun": 0.6})))
	Sfx.play("whoosh", b, 0.8)


## Konoha Ryūjin — yerden göğe tekme: ayak dibinde yer yarılır, ardından bükülmüş beyaz hortum gövdeli, boynuzlu ejder
## yükselir (anime karesi), çevresinde camgöbeği yörünge çizgileri döner, taş ve yapraklar gövdeye kapılıp yükselir
static func konoha_ryujin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(c.global_position + c.face_dir() * 1.5)
	c.velocity = Vector3.UP * 14.0
	_dragon(pj, at, c.face_dir())
	_cracks(pj, at, 2.4, 7, 3.0)
	_dust_ring(pj, at, 0.6, 4.0, 8, DUST, 0.45, 0.9)
	_bits(pj, at, 6, 4.0, 1.6, 0.14, TUFT)
	pj.after(0.15, func():
		_blow(pj, at + Vector3.UP * 1.5, 1.6, c.face_dir() if pj.live(c) else Vector3.FORWARD, false)
		for e in pj.enemies_near(c, at, 3.0):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "konoha_ryujin", 1.8, {"knock": 2.0, "launch": 16.0, "kind": "heavy"})))
	Sfx.play("whoosh", at, 0.7)


## Takigakure no Senpū — şelale gibi dönerek inen tekmeler: aşağı akan sarmal perde ve düşen dikey hız çizgileri;
## inişte yassı yayılan toz eteği, yere yatık basınç halkası, çatlak ve kalkan plakalar
static func takigakure_no_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 5.0, 6.0 if tt else 2.0)
	pj.busy(c, 0.9)
	_dust_ring(pj, pj.gp(c.global_position), 0.4, 3.0, 6, DUST, 0.35, 0.6)
	for k in 5:
		pj.after(0.15 + k * 0.1, func():
			if not pj.live(c):
				return
			var at = c.global_position + Vector3.UP * 0.6
			_fall_spin(pj, at)
			var hs = pj.hit(c, at, 2.0, pj.inf(c, "takigakure_no_senpu", 0.35, {"knock": 4.0, "kind": "heavy"}))
			if not hs.is_empty():
				_blow(pj, hs[0].global_position + Vector3.UP, 0.8, hs[0].global_position - c.global_position, false))
	pj.after(0.7, func():
		if pj.live(c):
			_fall_slam(pj, pj.gp(c.global_position), 1.2))
	Sfx.play("whoosh", c.global_position, 1.3)


## Chakura Shōgeki Zan — savuruşta önde yay sürtmesi; kılıçtan kopan yarı saydam, yırtık çizgili gri-beyaz hilal (anime karesi)
## uçar, arkasında sönen yankılar ve yerde ince kesik bırakır; isabette büyük kesik yayı
static func chakura_shogeki_zan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 22.0)
	pj._ensure_blade(c, 0.8)
	pj.anim(c, "slash_b", 1.5)
	pj.after(0.18, func():
		if not pj.live(c):
			return
		var from = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 0.6
		var face = c.face_dir()
		_swing_smear(pj, c)
		var blade = _crescent()
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 36.0, blade, pj.inf(c, "chakura_shogeki_zan", 1.1, {"knock": 8.0, "kind": "heavy", "bleed": 2.0}), null, true, 0.9, func(p, _h):
			_slash_hit(pj, p, face))
		pr.radius = 1.0
		_crescent_trail(pj, pr))
	Sfx.play("whoosh", c.global_position, 1.5)


## Mifune-Ryū Ichi no Tachi: Homura — iaido: tek ince parlak çizgi ve yerde kılıç kesiği, ardından geç kalkan ince toz;
## hedefte gecikmeli açılan çapraz kesik dilli alev gibi titreşerek yanar, kor taneleri yükselir, yerde kömür izi kalır
static func mifune_ichi_no_tachi_homura(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 0.6)
	pj._ensure_blade(c, 0.7)
	var a = c.global_position
	var b = pj.gp((tt.global_position + c.face_dir() * 1.5) if tt else a + c.face_dir() * 6.0)
	_iai_line(pj, a, b)
	c.global_position = b
	pj.after(0.12, func():
		if tt and pj.live(tt):
			_flame_cut(pj, tt.global_position + Vector3.UP, c.face_dir())
			pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.5, pj.inf(c, "mifune_ichi_no_tachi_homura", 2.0, {"knock": 8.0, "kind": "heavy", "bleed": 4.0})))
	Sfx.play("whoosh", b, 1.8)


## Doton: Dochū Senkō — dalışta yer yarılır (plakalar kalkar, soluk gri toz dalgası yükselir: anime karesi); yerin altında
## ilerlerken üstte toprağı yaran V plakalar, iki yana savrulan toz ve ardında kırık yarık izi; 4 sn sonra çıkışta yer yeniden yarılır
static func doton_dochu_senko(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var g = pj.gp(c.global_position)
	_rupture(pj, g, 1.0)
	var stt = {"last": g}
	pj.every(4.0, 0.2, func(_i, _k):
		if pj.live(c):
			var p = pj.gp(c.global_position)
			var mv: Vector3 = p - stt["last"]
			mv.y = 0.0
			var dir = mv.normalized() if mv.length() > 0.15 else c.face_dir()
			_wake(pj, p, dir)
			if mv.length() > 0.15:
				_furrow(pj, stt["last"], p)
			stt["last"] = p, Callable())
	pj.after(4.0, func():
		if pj.live(c):
			_rupture(pj, pj.gp(c.global_position), 0.8))
	_burrow_cast(pj, c)


## Doton: Ganseki Atsu — hedefin üstünde yerden kopan taşlar toplanıp kesik kenarlı, çatlaklı dev kaya bloğuna dönüşür (anime
## karesi: koyu kahve gövde, açık ten üst kenar), gölgesi büyürken düşer; çarpınca gömülür, kenarlarda plakalar kalkar, toz eteği
## fışkırır, çatlaklar yürür; beklerken çatlakları çoğalır, sonunda büyük parçalara ayrılıp yıkılır
static func doton_ganseki_atsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var b = _cel_mi(_slab_mesh(randi() % 3), Color.WHITE, {"cracks": 0.35, "speck": 0.7, "ink_at": 0.8, "shadow": true})
	pj.scene_add(b, at + Vector3.UP * 12.0)
	b.rotation.y = randf() * TAU
	var yaw = b.rotation.y
	b.scale = Vector3.ONE * 0.55
	var sh = _shadow(pj, at, 3.2, 0.4)
	_converge(pj, at, b, 0.3)
	var tw = b.create_tween()
	tw.tween_property(b, "global_position", at + Vector3.UP * 1.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(sh):
			sh.queue_free()
		_press_impact(pj, at, yaw)
		pj.hit(c, at + Vector3.UP, 3.0, pj.inf(c, "doton_ganseki_atsu", 1.8, {"knock": 2.0, "kind": "heavy", "element": "doton", "stun": 1.0}))
		pj.shake(0.9))
	tw.tween_property(b, "global_position", at + Vector3.UP * 1.2, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_pf(b, "cracks"), 0.35, 0.7, 0.25)
	tw.tween_method(_pf(b, "cracks"), 0.7, 1.0, 0.95)
	tw.tween_callback(func(): _crumble(pj, b))
	Sfx.play("earth", at, 0.6)


## Doton: Sunaodori — ayak dibinden kum örtüsü yayılır, iki halka kum tepesi yükselip ters yönlerde dönerek dalgalanır (anime
## karesi: yuvarlak sarı kum tepeleri, koyu gölge bantları); dönen kum bulutları ve perdeleri içindekileri keser, gözlerini kumla doldurur
static func doton_sunaodori(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	var at = pj.gp(c.global_position)
	_sand_field(pj, at, 2.0)
	pj.every(2.0, 0.25, func(_i, _k):
		_sand_tick(pj, at)
		for e in pj.enemies_near(c, at, 4.5):
			if pj.live(e):
				_puff(pj, e.global_position + Vector3.UP * 1.6, Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)), 0.3, 0.8, 0.6, SAND)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "doton_sunaodori", 0.25, {"knock": 3.0, "kind": "light", "element": "doton"}))
				if e.has_method("lose_target"):
					e.lose_target(1.0), Callable())
	Sfx.play("wind", at, 0.7)


## Doton: Otoshibuta — yerden koparılmış dev yuvarlak toprak kapak (üstü çimen, yanı katman katman toprak, altından sarkan
## toprak topakları) gölgesi büyürken kırıntı dökerek düşer; çarpınca altındaki hava toz halinde yatay fışkırır, kenardan çatlaklar
## dışa yürür, plakalar kalkar; süre sonunda kapak toprağa gömülerek dağılır, çevresinde gevşek toprak halkası kalır
static func doton_otoshibuta(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var lid = _cel_mi(_lid_mesh(randi() % 3), Color.WHITE, {"speck": 0.6, "cracks": 0.3, "ink_at": 0.82, "shadow": true})
	pj.scene_add(lid, at + Vector3.UP * 14.0)
	lid.rotation.y = randf() * TAU
	for k in 7:   # altından sarkan toprak topakları
		var a = randf() * TAU
		var cl = _cel_mi(_rock_mesh(randi() % 6), SOIL, {"speck": 0.5, "ink_at": 0.8})
		lid.add_child(cl)
		cl.position = Vector3(cos(a), 0, sin(a)) * randf_range(1.2, 3.6) + Vector3.DOWN * randf_range(0.65, 0.95)
		cl.scale = Vector3.ONE * randf_range(0.45, 0.8)
	for k in 9:   # üstteki çimen tutamları
		var a = randf() * TAU
		var tf = _cel_mi(_tuft_mesh(), Color.WHITE, {"ink_at": 2.0}, true)
		lid.add_child(tf)
		tf.position = Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 4.0) + Vector3.UP * 0.6
		tf.scale = Vector3.ONE * randf_range(0.3, 0.45)
	var sh = _shadow(pj, at, 5.0, 0.35)
	var lw = weakref(lid)
	pj.every(0.35, 0.07, func(_i, _k):   # düşerken altından dökülen kırıntılar
		var l2 = lw.get_ref()
		if l2 != null and is_instance_valid(l2):
			for q in 2:
				var a = randf() * TAU
				_chip(pj, l2.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 3.8) + Vector3.DOWN * 0.8, Vector3.DOWN * 2.0, randf_range(0.1, 0.18), SOIL, 0.8), Callable())
	var tw = lid.create_tween()
	tw.tween_property(lid, "global_position", at + Vector3.UP * 0.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(sh):
			sh.queue_free()
		for k in 16:   # kapağın altından yatay fışkıran hava ve toz
			var a = k * TAU / 16.0 + randf_range(-0.1, 0.1)
			var dv = Vector3(cos(a), 0, sin(a))
			_puff(pj, at + dv * 4.8 + Vector3.UP * 0.4, dv * randf_range(8.0, 11.0) + Vector3.UP * 0.8, 0.9, 2.4, randf_range(1.1, 1.5), Color(0.72, 0.62, 0.48), {"drag": 2.2})
		_shock(pj, at + Vector3.UP * 0.15, Vector3.UP, 4.8, 10.0, 0.35, Color(0.85, 0.78, 0.66, 0.55), 0.0, 0.9)
		_cracks(pj, at, 3.5, 12, 5.0, 4.6)
		_plate_ring(pj, at, 5.3, 10, 0.8, 38.0, 2.6)
		_bits(pj, at + Vector3.UP * 0.4, 14, 7.0, 0.6, 0.18, CHIP, Vector3.ZERO, SOIL)
		for e in pj.enemies_near(c, at, 4.6):
			if pj.live(e):
				if e.has_method("apply_status"):
					e.apply_status("stun", 1.5)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "doton_otoshibuta", 1.8, {"knock": 0.0, "kind": "heavy", "element": "doton"}))
		pj.shake(1.0))
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		_ground_patch(pj, at, 5.8, 4.2, SOIL, SOIL_D, 0.2, 0.2, 2.5, {"speck": 0.6, "ink_at": 2.0}))
	tw.tween_property(lid, "global_position", at - Vector3.UP * 0.5, 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_dis_all(lid), 0.0, 1.0, 0.4)
	tw.tween_callback(lid.queue_free)
	Sfx.play("earth", at, 0.5)
