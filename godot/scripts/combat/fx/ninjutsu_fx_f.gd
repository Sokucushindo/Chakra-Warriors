class_name NinjutsuFXF
extends RefCounted
## Genel ninjutsu grubu F: kukla teknikleri (Sasori / Kankurō), Sekiz Kapı, Rasengan Uzuhiko, Chōjū Giga ejderi,
## Banbutsu Sōzō, Chirōkyū, Jūgo hücre aktarımı, yılan dikişi.
## Her tekniğin görüntüsü bu dosyada sıfırdan üretilir: kendi cel / kontur / sarmal / sis / hücre / alev / çizgi
## gölgelendiricileri, kendi parça yapı taşları. Oynanış ana ağaçtaki işleyicilerden satır satır taşındı; gerçek sistemler
## (klan kukla modeli ClanConstruct, EdoWarrior kukla savaşçısı, Summon / Contracts, Buffs, Projectile) olduğu gibi kullanılır.
## Okunurluk: büyük kütleler (bulut, sis, ışın, kalkan) kameraya 6–9 m'de yumuşakça söner; küçük parçalar 0.3–1 m'de.

const INK := Color(0.07, 0.05, 0.09, 1.0)
const WOOD := Color(0.55, 0.4, 0.27, 1.0)
const WOOD_D := Color(0.33, 0.22, 0.14, 1.0)
const WOOD_INK := Color(0.17, 0.1, 0.06, 1.0)
const STRING_C := Color(0.45, 0.78, 1.0, 1.0)
const STEEL := Color(0.84, 0.87, 0.92, 1.0)
const STEEL_INK := Color(0.16, 0.18, 0.24, 1.0)
const VENOM := Color(0.56, 0.36, 0.66, 1.0)
const VENOM_D := Color(0.33, 0.19, 0.42, 1.0)
const VENOM_INK := Color(0.14, 0.06, 0.19, 1.0)
const ACID := Color(0.97, 0.74, 0.68, 1.0)
const ACID_D := Color(0.83, 0.53, 0.5, 1.0)
const ACID_INK := Color(0.46, 0.22, 0.22, 1.0)
const CREAM := Color(1.0, 0.96, 0.84, 1.0)
const CREAM_INK := Color(0.6, 0.5, 0.34, 1.0)
const GATE := Color(0.45, 1.0, 0.45, 1.0)
const GATE_CORE := Color(0.86, 1.0, 0.8, 1.0)
const GATE_INK := Color(0.08, 0.4, 0.14, 1.0)
const DUST := Color(0.83, 0.79, 0.64, 1.0)
const DUST_D := Color(0.64, 0.6, 0.46, 1.0)
const DUST_INK := Color(0.36, 0.32, 0.22, 1.0)
const EARTH := Color(0.55, 0.42, 0.3, 1.0)
const BLOOD := Color(0.74, 0.05, 0.06, 1.0)
const SUMI := Color(0.04, 0.04, 0.05, 1.0)
const SUMI_EDGE := Color(0.72, 0.72, 0.78, 1.0)
const PAPER := Color(0.96, 0.94, 0.86, 1.0)
const SNAKE := Color(0.5, 0.46, 0.6, 1.0)
const SNAKE_BELLY := Color(0.87, 0.83, 0.72, 1.0)
const RAS_CORE := Color(0.95, 0.98, 1.0, 1.0)
const RAS_BAND := Color(0.45, 0.72, 1.0, 1.0)
const RAS_EDGE := Color(0.1, 0.24, 0.72, 1.0)

static var _sh := {}
static var _mc := {}

# ================================================================== gölgelendiriciler
## Cel yüzey: köşe rengi × tint, sabit ışığa göre iki ton, isteğe bağlı parlak vurgu; kameraya yakın yumuşakça söner.
const CEL_SH := """
shader_type spatial;
render_mode unshaded, CULLMODE, depth_draw_always, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float shade_k = 0.7;
uniform float hi = 0.0;
uniform float fade = 1.0;
uniform float near0 = 0.5;
uniform float near1 = 1.5;

varying vec3 wn;

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wn);
	if (!FRONT_FACING) {
		n = -n;
	}
	float l = dot(n, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 c = tint.rgb * COLOR.rgb;
	c *= mix(shade_k, 1.0, step(0.05, l));
	c = mix(c, vec3(1.0), hi * step(0.86, l));
	ALBEDO = c;
	ALPHA = clamp(tint.a * COLOR.a * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Koyu kontur: ters kabuk, ana geçişten önce çizilir
const OUTLINE_SH := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.09, 1.0);
uniform float width = 0.02;
uniform float fade = 1.0;
uniform float near0 = 0.5;
uniform float near1 = 1.5;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * COLOR.a * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Yumuşak ışıma (toplamalı, kenarda söner): chakra çekirdeği, ışık noktaları
const GLOW_SH := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float power = 1.6;
uniform float fade = 1.0;
uniform float near0 = 0.5;
uniform float near1 = 1.5;

void fragment() {
	float fr = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = clamp(pow(fr, power) * tint.a * COLOR.a * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Rasengan sarmalı: küre yüzeyinde dönen spiral kollar, beyaz öz, koyu mavi cel kenar
const SPIRAL_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 core_c : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 band_c : source_color = vec4(0.45, 0.72, 1.0, 1.0);
uniform vec4 edge_c : source_color = vec4(0.1, 0.24, 0.72, 1.0);
uniform float arms = 5.0;
uniform float twist = 3.0;
uniform float spin = 3.0;
uniform float body_a = 0.6;
uniform float fade = 1.0;
uniform float near0 = 0.4;
uniform float near1 = 1.2;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = normalize(lp);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float lon = atan(p.z, p.x);
	float s = fract((lon + lat * twist) / 6.28318 * arms - TIME * spin);
	float band = step(0.5, s);
	float fr = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(band_c.rgb, core_c.rgb, band * 0.75);
	c = mix(c, core_c.rgb, smoothstep(0.72, 0.95, fr));
	float rimv = step(fr, 0.22);
	c = mix(c, edge_c.rgb, rimv);
	ALBEDO = c;
	ALPHA = clamp((body_a + (1.0 - body_a) * max(band, rimv)) * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Yer sisi: düz disk üzerinde akan gürültü eşiği; iki ton + koyu cel sınır çizgisi, kenarlar aşınır
const FOG_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 base_c : source_color = vec4(0.56, 0.36, 0.66, 0.8);
uniform vec4 hi_c : source_color = vec4(0.7, 0.52, 0.8, 1.0);
uniform vec4 line_c : source_color = vec4(0.14, 0.06, 0.19, 1.0);
uniform float seed = 0.0;
uniform float flow = 0.15;
uniform float density = 0.0;
uniform float fade = 1.0;
uniform float near0 = 6.0;
uniform float near1 = 9.0;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float n = vn(UV * 4.0 + vec2(TIME * flow, seed)) * 0.6 + vn(UV * 9.0 + vec2(seed * 1.7, -TIME * flow * 1.6)) * 0.4;
	float m = n - (0.26 + r * 0.62) + density;
	if (m < 0.0) {
		discard;
	}
	vec3 c = mix(base_c.rgb, hi_c.rgb, step(0.16, m));
	c = mix(line_c.rgb, c, step(0.035, m));
	ALBEDO = c;
	ALPHA = clamp(base_c.a * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Jūgo hücreleri: kaynayan turuncu-kızıl hücre dokusu (3B voronoi), koyu hücre zarı çizgileri, parlak hücre çekirdekleri
const CELL_SH := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 a_c : source_color = vec4(1.0, 0.56, 0.14, 1.0);
uniform vec4 b_c : source_color = vec4(0.88, 0.24, 0.08, 1.0);
uniform vec4 line_c : source_color = vec4(0.36, 0.08, 0.04, 1.0);
uniform vec4 spark_c : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform float cells = 6.0;
uniform float wob = 0.03;
uniform float fade = 1.0;
uniform float near0 = 0.5;
uniform float near1 = 1.5;

varying vec3 lp;

vec3 h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * sin(TIME * 7.0 + VERTEX.y * 9.0 + VERTEX.x * 6.0) * wob;
}

void fragment() {
	vec3 p = lp * cells + vec3(0.0, TIME * 0.6, 0.0);
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec3 cid = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 rr = g + h3(ip + g) - fp;
				float dd = dot(rr, rr);
				if (dd < d1) {
					d2 = d1;
					d1 = dd;
					cid = ip + g;
				} else if (dd < d2) {
					d2 = dd;
				}
			}
		}
	}
	float edg = sqrt(d2) - sqrt(d1);
	vec3 hc = h3(cid);
	vec3 c = mix(a_c.rgb, b_c.rgb, step(0.55, hc.x));
	c = mix(c, spark_c.rgb, step(sqrt(d1), 0.13) * step(0.65, hc.y));
	c = mix(line_c.rgb, c, step(0.08, edg));
	float fr = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	c = mix(c, line_c.rgb, step(fr, 0.2));
	ALBEDO = c;
	ALPHA = clamp(fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Alev dili (kameraya dönük kart): gürültüyle kıvrılan damla biçimi, beyazımsı öz, koyu cel kenar
const FLAME_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 body_c : source_color = vec4(0.45, 1.0, 0.45, 0.9);
uniform vec4 core_c : source_color = vec4(0.86, 1.0, 0.8, 1.0);
uniform vec4 line_c : source_color = vec4(0.08, 0.4, 0.14, 1.0);
uniform float seed = 0.0;
uniform float speed = 2.5;
uniform float fade = 1.0;
uniform float near0 = 0.4;
uniform float near1 = 1.2;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i), hs(i + vec2(1.0, 0.0)), f.x), mix(hs(i + vec2(0.0, 1.0)), hs(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float yy = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	x += (vn(vec2(yy * 3.0 - TIME * speed, seed)) - 0.5) * 0.55 * yy;
	float w = 0.95 * pow(clamp(1.0 - yy, 0.0, 1.0), 0.7) * smoothstep(0.0, 0.28, yy);
	float n = vn(vec2(x * 3.0 + seed, yy * 5.0 - TIME * speed * 1.5));
	float m = w - abs(x) - n * 0.32 * yy;
	if (m < 0.0) {
		discard;
	}
	vec3 c = mix(body_c.rgb, core_c.rgb, step(0.24, m));
	c = mix(line_c.rgb, c, step(0.05, m));
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(body_c.a * COLOR.a * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Hız çizgisi / kuyruk: UV.x baş(1)→kuyruk(0) incelir ve söner; beyaz öz + renkli kenar
const STREAK_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.5, 0.6, 0.8, 1.0);
uniform float fade = 1.0;
uniform float near0 = 0.5;
uniform float near1 = 1.5;

void fragment() {
	float u = UV.x;
	float v = abs(UV.y * 2.0 - 1.0);
	float w = mix(0.12, 1.0, u);
	if (v > w) {
		discard;
	}
	vec3 c = mix(tint.rgb, edge.rgb, step(w * 0.5, v));
	ALBEDO = c;
	ALPHA = clamp(tint.a * COLOR.a * u * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""

## Chakra ipliği: ince parlak çekirdek, boyunca kayan boncuk nabzı
const LINE_SH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.78, 1.0, 1.0);
uniform float fade = 1.0;
uniform float near0 = 0.3;
uniform float near1 = 0.9;

void fragment() {
	float v = abs(UV.x * 2.0 - 1.0);
	float bead = step(fract(UV.y * 9.0 - TIME * 2.6), 0.14);
	vec3 c = mix(tint.rgb, vec3(1.0), step(v, 0.35) * 0.6 + bead * 0.4);
	ALBEDO = c;
	ALPHA = clamp((0.75 + 0.25 * bead) * (1.0 - v * 0.5) * fade * smoothstep(near0, near1, length(VERTEX)), 0.0, 1.0);
}
"""


# ================================================================== malzeme yardımcıları
static func _shader(key: String, code: String) -> Shader:
	if not _sh.has(key):
		var s := Shader.new()
		s.code = code
		_sh[key] = s
	return _sh[key]


static func _smat(key: String, code: String, near0: float, near1: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(key, code)
	m.set_shader_parameter("near0", near0)
	m.set_shader_parameter("near1", near1)
	return m


## Cel malzeme + koyu kontur (outline > 0)
static func _cel(col: Color, outline := 0.02, ink := INK, near0 := 0.5, near1 := 1.5, two := false, shade := 0.7, hi := 0.0) -> ShaderMaterial:
	var m := _smat("cel2" if two else "cel", CEL_SH.replace("CULLMODE", "cull_disabled" if two else "cull_back"), near0, near1)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("shade_k", shade)
	m.set_shader_parameter("hi", hi)
	if outline > 0.0:
		var o := _smat("outline", OUTLINE_SH, near0, near1)
		o.set_shader_parameter("ink", ink)
		o.set_shader_parameter("width", outline)
		o.render_priority = -1
		m.next_pass = o
	return m


static func _glow(col: Color, power := 1.6, near0 := 0.5, near1 := 1.5) -> ShaderMaterial:
	var m := _smat("glow", GLOW_SH, near0, near1)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("power", power)
	return m


static func _flame(body: Color, core: Color, line: Color, near0 := 0.4, near1 := 1.2, speed := 2.5) -> ShaderMaterial:
	var m := _smat("flame", FLAME_SH, near0, near1)
	m.set_shader_parameter("body_c", body)
	m.set_shader_parameter("core_c", core)
	m.set_shader_parameter("line_c", line)
	m.set_shader_parameter("seed", randf() * 40.0)
	m.set_shader_parameter("speed", speed)
	return m


static func _streak(tint: Color, edge: Color, near0 := 0.5, near1 := 1.5) -> ShaderMaterial:
	var m := _smat("streak", STREAK_SH, near0, near1)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("edge", edge)
	return m


static func _line_mat(col: Color) -> ShaderMaterial:
	var m := _smat("line", LINE_SH, 0.3, 0.9)
	m.set_shader_parameter("tint", col)
	return m


static func _spiral(near0: float, near1: float, arms := 5.0, spin := 3.0, body_a := 0.6) -> ShaderMaterial:
	var m := _smat("spiral", SPIRAL_SH, near0, near1)
	m.set_shader_parameter("core_c", RAS_CORE)
	m.set_shader_parameter("band_c", RAS_BAND)
	m.set_shader_parameter("edge_c", RAS_EDGE)
	m.set_shader_parameter("arms", arms)
	m.set_shader_parameter("spin", spin)
	m.set_shader_parameter("body_a", body_a)
	return m


## Malzemenin (ve kontur geçişinin) bir parametresi
static func _sp(m: Material, k: String, v: Variant) -> void:
	var q := m
	while q != null:
		if q is ShaderMaterial:
			(q as ShaderMaterial).set_shader_parameter(k, v)
		q = q.next_pass


## delay sonra dur sürede söner, sonra silinir
static func _fade(n: Node, m: Material, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void: _sp(m, "fade", v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


# ================================================================== düğüm / geometri yapı taşları
static func _mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _put(pj: PathJutsu, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	(parent if parent else pj.get_tree().current_scene).add_child(n)
	n.global_position = pos
	return n


static func _look(n: Node3D, p: Vector3) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var dv := p - n.global_position
	if dv.length() < 0.01:
		return
	n.look_at(p, Vector3.UP if absf(dv.normalized().y) < 0.97 else Vector3.RIGHT)


static func _cached(key: String, fn: Callable) -> Mesh:
	if not _mc.has(key):
		_mc[key] = fn.call()
	return _mc[key]


## a→b arası Y ekseni boyunca uzanan birim gövde dönüşümü (w: kalınlık)
static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var dv := b - a
	var L := maxf(dv.length(), 0.001)
	var y := dv / L
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * w, y * L, z * w), (a + b) * 0.5)


## Profil (px,py) → dik XY düzlemi, kalınlık Z
static func _up_b() -> Basis:
	return Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


## Profil (px,py) → yerde XZ (py → -Z), kalınlık Y
static func _flat_b() -> Basis:
	return Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))


static func _slab(outline: PackedVector2Array, thick: float, col: Color, b: Basis, origin := Vector3.ZERO) -> ArrayMesh:
	var mb := MB.new()
	mb.add_slab(outline, thick, col, Transform3D(b, origin))
	return mb.build()


static func _star(points: int, r_out: float, r_in: float, jit := 0.0) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in points * 2:
		var a := TAU * i / (points * 2.0)
		var r := (r_out * randf_range(1.0 - jit, 1.0 + jit)) if i % 2 == 0 else r_in
		o.append(Vector2(cos(a), sin(a)) * r)
	return o


static func _blob(r: float, n := 18, rough := 0.25) -> PackedVector2Array:
	var o := PackedVector2Array()
	var ph := randf() * 10.0
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + rough * (sin(a * 3.0 + ph) * 0.5 + sin(a * 7.0 + ph * 2.0) * 0.3 + randf_range(-0.3, 0.3))
		o.append(Vector2(cos(a), sin(a)) * r * k)
	return o


## Çapraz iki şerit, Y boyunca -0.5..0.5 (UV.y boy, UV.x en): iplik / ince bağ
static func _m_line() -> Mesh:
	return _cached("mesh:line", func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ax in [Vector3(0.5, 0, 0), Vector3(0, 0, 0.5)]:
			var a: Vector3 = ax
			var q := [Vector3(-a.x, -0.5, -a.z), Vector3(a.x, -0.5, a.z), Vector3(a.x, 0.5, a.z), Vector3(-a.x, 0.5, -a.z)]
			var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color.WHITE)
				st.set_uv(uv[i])
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
		return st.commit())


## Çapraz iki şerit, Z boyunca 0(baş, UV.x=1)..1(kuyruk, UV.x=0): hız izi
static func _m_streak() -> Mesh:
	return _cached("mesh:streak", func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ax in [Vector3(0.5, 0, 0), Vector3(0, 0.5, 0)]:
			var a: Vector3 = ax
			var q := [-a, a, a + Vector3(0, 0, 1), -a + Vector3(0, 0, 1)]
			var uv := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color.WHITE)
				st.set_uv(uv[i])
				st.set_normal(Vector3.UP)
				st.add_vertex(q[i])
		return st.commit())


## Yay şeridi (XZ düzlemi): UV.x a0(kuyruk)→a1(baş), UV.y en
static func _arc_band(r: float, w: float, a0: float, a1: float, n := 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n + 1:
		var u := float(i) / n
		var a := lerpf(a0, a1, u)
		var dv := Vector3(cos(a), 0, sin(a))
		for s in [0.0, 1.0]:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(u, s))
			st.set_normal(Vector3.UP)
			st.add_vertex(dv * (r + (s - 0.5) * w))
	for i in n:
		var k := i * 2
		st.add_index(k)
		st.add_index(k + 2)
		st.add_index(k + 1)
		st.add_index(k + 1)
		st.add_index(k + 2)
		st.add_index(k + 3)
	return st.commit()


## Yol boyunca şerit: nrms[i] şeridin yüz normali (yan = teğet × normal); UV.x ilk(0)→son(1)
static func _ribbon(pts: Array, w: float, nrms: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nr: Vector3 = nrms[i]
		var sd := tn.cross(nr).normalized()
		if sd.length() < 0.1:
			sd = Vector3.RIGHT
		var u := float(i) / float(n - 1)
		for s in [-1.0, 1.0]:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(u, (s + 1.0) * 0.5))
			st.set_normal(nr)
			st.add_vertex(p + sd * w * s * 0.5)
	for i in n - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()


static func _m_ball(seg := 12) -> Mesh:
	return _cached("mesh:ball%d" % seg, func() -> Mesh:
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE, Color.WHITE, Vector3.ZERO, seg)
		return b.build())


static func _m_disc() -> Mesh:
	return _cached("mesh:disc", func() -> Mesh:
		var p := PlaneMesh.new()
		p.size = Vector2(2, 2)
		return p)


static func _m_card(h := 1.6) -> Mesh:
	return _cached("mesh:card%.2f" % h, func() -> Mesh:
		var q := QuadMesh.new()
		q.size = Vector2(1.0, h)
		q.center_offset = Vector3(0, h * 0.5, 0)
		return q)


static func _m_chip() -> Mesh:
	return _cached("mesh:chip", func() -> Mesh:
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.24, 0.17, 0.2), Color.WHITE, Vector3(18, 30, 9))
		b.add("box", Vector3(0.05, 0.05, 0.02), Vector3(0.14, 0.12, 0.13), Color(0.84, 0.84, 0.84), Vector3(-20, 10, 35))
		return b.build())


## Tahta kıymığı / sopa (Y boyunca)
static func _m_stick() -> Mesh:
	return _cached("mesh:stick", func() -> Mesh:
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.06, 0.5, 0.06), Color.WHITE)
		b.add("cone", Vector3(0, 0.3, 0), Vector3(0.06, 0.1, 0.06), Color(0.85, 0.85, 0.85), Vector3.ZERO, 4)
		return b.build())


## Damla (Y boyunca uzun)
static func _m_drop() -> Mesh:
	return _cached("mesh:drop", func() -> Mesh:
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.16, 0.16, 0.16), Color.WHITE, Vector3.ZERO, 8)
		b.add("cone", Vector3(0, 0.13, 0), Vector3(0.14, 0.2, 0.14), Color.WHITE, Vector3.ZERO, 8)
		return b.build())


## Elmas kesitli iğne: uç -Z (mermi), uç +Y (parçacık hizası) iki sürüm
static func _m_spike(along_y: bool) -> Mesh:
	return _cached("mesh:spike%d" % int(along_y), func() -> Mesh:
		var b := MB.new()
		var r := Vector3(-90, 0, 0) if not along_y else Vector3.ZERO
		var rb := Vector3(90, 0, 0) if not along_y else Vector3(180, 0, 0)
		var f := Vector3(0, 0, -0.26) if not along_y else Vector3(0, 0.26, 0)
		var bk := Vector3(0, 0, 0.1) if not along_y else Vector3(0, -0.1, 0)
		b.add("cone", f, Vector3(0.1, 0.52, 0.1), Color.WHITE, r, 4)
		b.add("cone", bk, Vector3(0.1, 0.2, 0.1), Color(0.8, 0.82, 0.86), rb, 4)
		return b.build())


## İnce uzun senbon (uç -Z)
static func _m_senbon(dark: bool) -> Mesh:
	return _cached("mesh:senbon%d" % int(dark), func() -> Mesh:
		var b := MB.new()
		var body := Color(0.3, 0.3, 0.34) if dark else Color.WHITE
		b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.025, 0.5, 0.025), body, Vector3(90, 0, 0), 4)
		b.add("cone", Vector3(0, 0, -0.3), Vector3(0.025, 0.1, 0.025), Color.WHITE, Vector3(-90, 0, 0), 4)
		return b.build())


## Parça yağmuru (kendi CPU parçacık ayarı). o: r, dir, spread, vmin, vmax, g, damp, radial, smin, smax, spin, expl,
## align, hold, end_scale, parent (yerel çocuk), one (tek atım), keep (otomatik silme yok)
static func _burst(pj: PathJutsu, pos: Vector3, mesh: Mesh, m: Material, n: int, life: float, o := {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = bool(o.get("one", true))
	p.explosiveness = float(o.get("expl", 0.92))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.3))
	var dv: Vector3 = o.get("dir", Vector3.UP)
	p.direction = dv.normalized() if dv.length() > 0.001 else Vector3.UP
	p.spread = float(o.get("spread", 180.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("g", Vector3(0, -9, 0))
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.8))
	p.scale_amount_max = float(o.get("smax", 1.2))
	if o.get("align", false):
		p.particle_flag_align_y = true
	else:
		p.particle_flag_rotate_y = true
		p.angle_min = 0.0
		p.angle_max = 360.0
		var sp := float(o.get("spin", 120.0))
		p.angular_velocity_min = -sp
		p.angular_velocity_max = sp
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(float(o.get("hold", 0.65)), Color(1, 1, 1, 1))
	p.color_ramp = g
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, float(o.get("start_scale", 1.0))))
	cv.add_point(Vector2(1.0, float(o.get("end_scale", 0.6))))
	p.scale_amount_curve = cv
	var par: Node = o.get("parent", null)
	if par != null and is_instance_valid(par):
		par.add_child(p)
		p.position = pos
	else:
		_put(pj, p, pos)
	p.emitting = true
	if not o.get("keep", false):
		pj.free_after(life + 0.6, p)
	return p


## Sürekli yayıcıyı durdur, son parçalar ölünce sil
static func _stop(p: CPUParticles3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	var tw := p.create_tween()
	tw.tween_interval(p.lifetime + 0.2)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ ortak küçük parçalar
static func _chips(pj: PathJutsu, pos: Vector3, col: Color, n: int, v := 6.0) -> void:
	_burst(pj, pos, _m_chip(), _cel(col, 0.012, DUST_INK, 0.4, 1.0), n, 0.9, {"r": 0.4, "vmin": v * 0.4, "vmax": v,
		"spread": 70.0, "g": Vector3(0, -16, 0), "spin": 360.0, "smin": 0.5, "smax": 1.3, "hold": 0.8})


## Tahta kıymıkları + kopan tahta sopalar (kukla açılır / kapanır)
static func _splinters(pj: PathJutsu, pos: Vector3, s: float) -> void:
	_burst(pj, pos, _m_stick(), _cel(WOOD, 0.012, WOOD_INK, 0.4, 1.0), int(9 * s) + 3, 0.8, {"r": 0.35 * s, "vmin": 2.0, "vmax": 5.0 * s,
		"g": Vector3(0, -14, 0), "spin": 540.0, "smin": 0.5 * s, "smax": 1.0 * s, "hold": 0.75})


## Lekeli kümülüs tümseği: üst açık, alt koyu, isteğe bağlı beyaz benekler (asit bulutu ref'i)
static func _m_mound(key: String, top: Color, bot: Color, dots: bool, v: int) -> Mesh:
	return _cached("mesh:mound_%s_%d" % [key, v], func() -> Mesh:
		var b := MB.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key) + v * 977
		b.add_grad("sphere", Vector3(0, 0.45, 0), Vector3(1.6, 1.15, 1.6), top, bot, Vector3.ZERO, 14)
		var lobes: Array = []
		for k in 6:
			var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
			var s := rng.randf_range(0.7, 1.05)
			var p := Vector3(cos(a) * 0.62, 0.3 + rng.randf_range(0.0, 0.45), sin(a) * 0.62)
			b.add_grad("sphere", p, Vector3(s, s * 0.85, s), top, bot, Vector3.ZERO, 12)
			lobes.append([p, s])
		b.add_grad("sphere", Vector3(rng.randf_range(-0.2, 0.2), 0.95, rng.randf_range(-0.2, 0.2)), Vector3(0.95, 0.8, 0.95), top, bot, Vector3.ZERO, 12)
		if dots:
			for k in 14:
				var L: Array = lobes[k % lobes.size()]
				var c: Vector3 = L[0]
				var dv := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)).normalized()
				b.add("sphere", c + dv * float(L[1]) * 0.45, Vector3.ONE * rng.randf_range(0.06, 0.1), Color(1, 0.97, 0.96), Vector3.ZERO, 6)
		return b.build())


## Chakra iplikleri: iki elin parmaklarından birimin offs noktalarına (yerel) uzanan ince mavi iplikler; dur sn
static func _strings(pj: PathJutsu, c: Node3D, unit: Node3D, dur: float, offs: Array) -> void:
	var cw = weakref(c)
	var uw = weakref(unit)
	var lines: Array = []
	var m := _line_mat(STRING_C)
	for k in offs.size():
		var li := _mi(_m_line(), m)
		_put(pj, li, c.global_position)
		lines.append(li)
		pj.free_after(dur + 0.6, li)
	var upd := func(_i: int, _k: float) -> void:
		var cc = cw.get_ref()
		var u = uw.get_ref()
		for k in lines.size():
			var li: MeshInstance3D = lines[k]
			if not is_instance_valid(li):
				continue
			if cc == null or u == null or not is_instance_valid(cc) or not is_instance_valid(u) or not (u as Node3D).is_inside_tree():
				li.visible = false
				continue
			var a: Vector3 = pj.hand_pos(cc, k % 2 == 0)
			var b: Vector3 = (u as Node3D).global_transform * (offs[k] as Vector3)
			li.global_transform = _seg_xf(a, b, 0.022)
	upd.call(0, 0.0)
	pj.every(dur, 1.0 / 30.0, upd, func() -> void:
		for li in lines:
			if is_instance_valid(li):
				_fade(li, m, 0.0, 0.15))


## Klan kukla sisteminin gerçek modeli (ClanConstruct) sahnede: parşömenden yaylanarak açılır, iplikler bağlanır;
## dur sn sonra katlanıp kaybolur. Konum gp(at) (mekanik aynı).
static func _puppet(pj: PathJutsu, c: Node3D, at: Vector3, d: Vector3, dur: float, s := 1.0, dark := false) -> Node3D:
	var pup: Node3D = pj._puppet_mesh(s, dark)
	pj.scene_add(pup, pj.gp(at))
	pup.rotation.y = atan2(d.x, d.z)
	pup.scale = Vector3(1.0, 0.05, 1.0)
	var tw := pup.create_tween()
	tw.tween_property(pup, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strings(pj, c, pup, dur, [Vector3(0.24, 1.5 * s, 0), Vector3(-0.24, 1.5 * s, 0), Vector3(0.1, 1.8 * s, 0), Vector3(-0.1, 1.8 * s, 0)])
	_splinters(pj, pup.global_position + Vector3.UP * s, s)
	var pw = weakref(pup)
	pj.after(dur, func() -> void:
		var p = pw.get_ref()
		if p != null and is_instance_valid(p):
			_splinters(pj, (p as Node3D).global_position + Vector3.UP, s * 0.8)
			var t2 := (p as Node3D).create_tween()
			t2.tween_property(p, "scale", Vector3(1.0, 0.05, 1.0), 0.15).set_ease(Tween.EASE_IN)
			t2.tween_callback((p as Node3D).queue_free))
	pj.free_after(dur + 0.6, pup)
	return pup


## Kukla sarsılması: atış anında geri teper
static func _jolt(n: Node3D, amt: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var p0 := n.position
	var tw := n.create_tween()
	tw.tween_property(n, "position", p0 + Vector3(randf_range(-amt, amt), amt, randf_range(-amt, amt)), 0.04)
	tw.tween_property(n, "position", p0, 0.08)


## Kısa beyaz yıldız parıltısı (namlu / ağız)
static func _glint(pj: PathJutsu, pos: Vector3, dir: Vector3, s: float, col := Color.WHITE, ink := STEEL_INK) -> void:
	var m := _cel(col, 0.0, ink, 0.4, 1.0, true)
	var g := _mi(_slab(_star(4, 0.3, 0.07), 0.01, Color.WHITE, _up_b()), m)
	_put(pj, g, pos)
	_look(g, pos + dir)
	g.rotation.z = randf() * TAU
	g.scale = Vector3.ONE * s * 0.4
	var tw := g.create_tween()
	tw.tween_property(g, "scale", Vector3.ONE * s, 0.05)
	tw.tween_property(g, "scale", Vector3.ONE * s * 0.1, 0.1)
	tw.tween_callback(g.queue_free)


# ================================================================== 1. CHIRŌKYŪ — krem chakra kükremesi + pembe asit bulutları
## ref: dikenli krem şok halkası, kullanıcıyı saran kıvrımlı chakra halkası, ileri uzanan tırtıklı krem ışın;
## ref 2: yol boyunca kabaran pembe kümülüs asit bulutları (beyaz benekli), yerde aşınmış leke.
static func chirokyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d: Vector3 = pj.fwd(c, t)
	_acid_gather(pj, c.global_position + Vector3.UP * 1.5 + d * 0.5)
	pj.after(0.35, func() -> void:
		_acid_roar(pj, c.global_position + Vector3.UP * 1.25, d)
		for k in 6:
			pj.after(k * 0.06, func() -> void:
				var q: Vector3 = pj.gp(c.global_position + d * (3.0 + k * 3.0))
				_acid_cloud(pj, q, d, 1.0 + k * 0.22, k)
				_acid_stain(pj, q, 1.1 + k * 0.2)
				_chips(pj, q + Vector3.UP * 0.3, EARTH, 6, 8.0))
		Combat.hit_zone(c, c.global_position, d, 22.0, 30.0, 5.0, pj.inf(c, "chirokyu", 2.0, {"knock": 22.0, "launch": 6.0, "kind": "heavy"}))
		pj.shake(1.0))
	Sfx.play("roar", c.global_position, 0.9)


## Hazırlık: göğse çekilen krem diş kıvılcımları + büyüyen çekirdek
static func _acid_gather(pj: PathJutsu, at: Vector3) -> void:
	var m := _cel(CREAM, 0.012, CREAM_INK, 0.6, 1.4, true)
	var mesh := _slab(PackedVector2Array([Vector2(0, 0.28), Vector2(0.06, 0), Vector2(0, -0.06), Vector2(-0.06, 0)]), 0.02, Color.WHITE, _up_b())
	for k in 12:
		var dv := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized()
		var f := _mi(mesh, m)
		_put(pj, f, at + dv * randf_range(1.4, 2.0))
		_look(f, at)
		var tw := f.create_tween()
		tw.tween_property(f, "global_position", at, 0.3).set_delay(k * 0.012).set_ease(Tween.EASE_IN)
		tw.tween_callback(f.queue_free)
	var core := _mi(_m_ball(12), _glow(CREAM, 1.2, 0.5, 1.2))
	_put(pj, core, at)
	core.scale = Vector3.ONE * 0.05
	var t2 := core.create_tween()
	t2.tween_property(core, "scale", Vector3.ONE * 0.9, 0.33).set_ease(Tween.EASE_IN)
	t2.tween_property(core, "scale", Vector3.ONE * 0.05, 0.1)
	t2.tween_callback(core.queue_free)


## Salınım: dikenli şok diski + tırtıklı krem ışın + kullanıcıyı saran kıvrımlı halka
static func _acid_roar(pj: PathJutsu, o: Vector3, d: Vector3) -> void:
	# dikenli disk (ref: patlayan krem yıldız)
	var dm := _cel(Color.WHITE, 0.0, CREAM_INK, 2.0, 4.0, true, 0.85)
	var sp := _star(20, 1.7, 1.0, 0.25)
	var big := PackedVector2Array()
	for v in sp:
		big.append(v * 1.08)
	var dmb := MB.new()
	dmb.add_slab(big, 0.02, CREAM_INK, Transform3D(_up_b(), Vector3.ZERO))   # koyu dış çizgi (yalnız kenarda görünür)
	dmb.add_slab(sp, 0.06, CREAM, Transform3D(_up_b(), Vector3.ZERO))
	var disk := _mi(dmb.build(), dm)
	_put(pj, disk, o + d * 0.9)
	_look(disk, o + d * 3.0)
	disk.scale = Vector3.ONE * 0.3
	var tw := disk.create_tween()
	tw.tween_property(disk, "scale", Vector3.ONE * 1.5, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_fade(disk, dm, 0.12, 0.25)
	# tırtıklı ışın: iki çapraz levha (yataydan ve yandan okunur), boyu 0.25 sn'de 22 m'ye uzar, sonra incelir
	var L := 22.0
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var N := 22
	for i in N + 1:
		var u := float(i) / N
		var w := lerpf(1.15, 0.12, pow(u, 0.8)) * (1.0 + (0.35 if i % 2 == 1 else -0.1) * randf_range(0.6, 1.2))
		top.append(Vector2(u * L, w))
		bot.append(Vector2(u * L, -w * randf_range(0.8, 1.1)))
	var prof := PackedVector2Array()
	prof.append_array(top)
	prof.append(Vector2(L + 1.2, 0.0))
	bot.reverse()
	prof.append_array(bot)
	var bm := _cel(CREAM, 0.0, CREAM_INK, 6.0, 9.0, true, 0.82)
	var beam := Node3D.new()
	_put(pj, beam, o)
	_look(beam, o + d)
	var hb := Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	var vb := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	for bb in [hb, vb]:
		var sl := _mi(_slab(prof, 0.05, Color.WHITE, bb), bm)
		beam.add_child(sl)
		var edge_m := _cel(CREAM_INK, 0.0, INK, 6.0, 9.0, true)
		var core_p := PackedVector2Array()   # ışının ortasında koyu iz çizgisi (cel derinlik)
		for i in N + 1:
			var u := float(i) / N
			core_p.append(Vector2(u * L, 0.08 * (1.0 - u) + 0.02))
		for i in range(N, -1, -1):
			var u := float(i) / N
			core_p.append(Vector2(u * L, -0.08 * (1.0 - u) - 0.02))
		var cl := _mi(_slab(core_p, 0.06, Color.WHITE, bb), edge_m)
		beam.add_child(cl)
		_fade(cl, edge_m, 0.35, 0.3)
	beam.scale = Vector3(1, 1, 0.05)
	var t2 := beam.create_tween()
	t2.tween_property(beam, "scale", Vector3(1, 1, 1), 0.25).set_ease(Tween.EASE_OUT)
	t2.tween_property(beam, "scale", Vector3(0.25, 0.25, 1.05), 0.4).set_ease(Tween.EASE_IN)
	_fade(beam, bm, 0.35, 0.3)
	# kullanıcıyı saran kıvrımlı krem halka (ışın eksenine dik düzlemde döner)
	var pts: Array = []
	var nrm: Array = []
	var side := d.cross(Vector3.UP).normalized()
	for i in 41:
		var a := 0.3 + i / 40.0 * TAU * 0.85
		var r := 2.0 + sin(i * 0.9) * 0.15
		pts.append((side * cos(a) + Vector3.UP * sin(a)) * r - d * 0.4)
		nrm.append(d)
	var rm := _streak(CREAM, CREAM_INK, 2.5, 4.5)
	var sw := _mi(_ribbon(pts, 0.75, nrm), rm)
	_put(pj, sw, o)
	var t3 := sw.create_tween()
	t3.tween_method(func(a: float) -> void:
		if is_instance_valid(sw):
			sw.global_transform = Transform3D(Basis(d, a), o), 0.0, -2.4, 0.55).set_ease(Tween.EASE_OUT)
	_fade(sw, rm, 0.25, 0.3)


## Asit bulutu: 3-4 pembe kümülüs tümseği yerden kabarır, yavaşça şişer, sonra çöker ve söner
static func _acid_cloud(pj: PathJutsu, q: Vector3, d: Vector3, s: float, seed_k: int) -> void:
	var side := d.cross(Vector3.UP).normalized()
	for j in 3 + seed_k % 2:
		var m := _cel(Color.WHITE, 0.035, ACID_INK, 6.0, 9.0, false, 0.86)
		var mo := _mi(_m_mound("acid", ACID, ACID_D, true, (seed_k + j) % 3), m)
		var off := side * randf_range(-1.6, 1.6) * s + d * randf_range(-0.8, 0.8)
		_put(pj, mo, q + off + Vector3.DOWN * 0.2)
		mo.rotation.y = randf() * TAU
		var sc := s * randf_range(0.85, 1.25)
		mo.scale = Vector3.ONE * sc * 0.15
		var tw := mo.create_tween()
		tw.tween_property(mo, "scale", Vector3.ONE * sc, 0.32).set_delay(j * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mo, "scale", Vector3(sc * 1.18, sc * 1.1, sc * 1.18), 1.8).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mo, "global_position", mo.global_position + Vector3.UP * 0.5 + d * 0.6, 1.8)
		tw.tween_property(mo, "scale", Vector3(sc * 1.25, sc * 0.4, sc * 1.25), 0.6).set_ease(Tween.EASE_IN)
		_fade(mo, m, 2.0, 0.65)


## Yerde aşınmış asit lekesi + cızırdayan küçük kabarcıklar
static func _acid_stain(pj: PathJutsu, q: Vector3, r: float) -> void:
	var m := _cel(Color(0.56, 0.3, 0.32, 0.85), 0.0, INK, 1.0, 3.0, true, 1.0)
	var st := _mi(_slab(_blob(r, 20, 0.35), 0.02, Color.WHITE, _flat_b()), m)
	_put(pj, st, q + Vector3.UP * 0.03)
	st.rotation.y = randf() * TAU
	var m2 := _cel(Color(0.36, 0.17, 0.19, 0.9), 0.0, INK, 1.0, 3.0, true, 1.0)
	var inner := _mi(_slab(_blob(r * 0.55, 14, 0.4), 0.02, Color.WHITE, _flat_b()), m2)
	st.add_child(inner)
	inner.position = Vector3(randf_range(-0.2, 0.2), 0.012, randf_range(-0.2, 0.2))
	_fade(inner, m2, 3.0, 1.5)
	_fade(st, m, 3.0, 1.5)
	var bp := _burst(pj, q + Vector3.UP * 0.1, _m_ball(6), _cel(ACID, 0.01, ACID_INK, 0.6, 1.5), 14, 0.9, {"r": r * 0.7, "dir": Vector3.UP,
		"spread": 25.0, "vmin": 0.4, "vmax": 1.2, "g": Vector3(0, 0.6, 0), "smin": 0.08, "smax": 0.18, "expl": 0.0, "one": false, "keep": true, "start_scale": 0.4, "end_scale": 1.3})
	pj.free_after(4.0, bp)
	var bw = weakref(bp)
	pj.get_tree().create_timer(2.6).timeout.connect(func() -> void:
		var p = bw.get_ref()
		if p != null and is_instance_valid(p):
			_stop(p))


# ================================================================== 2. BANBUTSU SŌZŌ — Yin / Yang'dan varlık yaratma
## ref: sol elde mavi (Yin), sağ elde kızıl (Yang) alev; arkada ışınsal çizgiler. İki alev ileri noktada birleşir:
## ışık çekirdeği büyür, mavi-kızıl halkalar yörüngede döner, ışık patlar ve varlık ışığın içinden belirir.
static func banbutsu_sozo_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var hands: Array = []
	for pair in [["LeftHand", Color(0.3, 0.55, 1.0, 0.95), Color(0.85, 0.95, 1.0), Color(0.05, 0.12, 0.45)],
			["RightHand", Color(1.0, 0.3, 0.18, 0.95), Color(1.0, 0.9, 0.8), Color(0.45, 0.05, 0.03)]]:
		var ba: Node3D = pj.bone_attach(c, pair[0])
		if ba:
			_yin_yang_flame(ba, pair[1], pair[2], pair[3])
			pj.free_after(1.1, ba)
			hands.append([ba, pair[1]])
	var at: Vector3 = pj.gp(c.global_position + pj.fwd(c, t) * 3.0)
	var core_p := at + Vector3.UP * 1.2
	_creation_rays(pj, at)
	# iki el alevinden birleşme noktasına akan mavi / kızıl ışık damlaları
	var hw: Array = []
	for h in hands:
		hw.append([weakref(h[0]), h[1]])
	pj.every(0.85, 0.07, func(_i: int, _k: float) -> void:
		for h in hw:
			var b = (h[0] as WeakRef).get_ref()
			if b != null and is_instance_valid(b) and (b as Node3D).is_inside_tree():
				_light_mote(pj, (b as Node3D).global_position, core_p, h[1]))
	pj.after(0.9, func() -> void:   # Yin + Yang birleşir: ışık çekirdeği
		if not pj.live(c):
			return
		var pod := Node3D.new()
		_put(pj, pod, core_p)
		var gm := _glow(Color(1.0, 1.0, 0.95), 0.9, 1.0, 2.0)
		var ball := _mi(_m_ball(16), gm)
		pod.add_child(ball)
		ball.scale = Vector3.ONE * 0.9
		var cm := _cel(Color(1.0, 0.99, 0.94), 0.025, Color(0.55, 0.5, 0.35), 1.0, 2.0, false, 0.92)
		var inner := _mi(_m_ball(14), cm)
		pod.add_child(inner)
		inner.scale = Vector3.ONE * 0.5
		for k in 2:   # mavi ve kızıl yörünge halkaları (ters eğimli)
			var rm := _streak(Color(0.55, 0.75, 1.0) if k == 0 else Color(1.0, 0.5, 0.35), Color(0.1, 0.25, 0.8) if k == 0 else Color(0.7, 0.1, 0.05), 1.0, 2.0)
			var ring := _mi(_arc_band(0.75, 0.09, 0.0, TAU * 0.8, 40), rm)
			pod.add_child(ring)
			ring.rotation = Vector3(deg_to_rad(60.0 if k == 0 else -60.0), 0, deg_to_rad(20.0))
			var rt := Game.safe_loops(ring.create_tween())
			rt.tween_property(ring, "rotation:y", ring.rotation.y + (TAU if k == 0 else -TAU), 0.45).from(ring.rotation.y)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.97, 0.88)
		lt.omni_range = 7.0
		lt.light_energy = 0.0
		pod.add_child(lt)
		pod.scale = Vector3.ONE * 0.05
		var tw := pod.create_tween()
		tw.tween_property(pod, "scale", Vector3.ONE * 1.6, 0.45).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(pod, "rotation:y", TAU, 0.9)
		tw.parallel().tween_property(lt, "light_energy", 3.5, 0.45)
		tw.tween_interval(0.25)
		tw.tween_callback(func() -> void:   # ışık patlar, varlık doğar
			var pp := pod.global_position
			pod.queue_free()
			_creation_flash(pj, pp)
			if not pj.live(c):
				return
			var pool = []
			for cid in Contracts.DEFS:
				var tiers: Dictionary = Contracts.DEFS[cid]["tiers"]
				for tk in tiers:
					var sd: Dictionary = tiers[tk]
					if String(sd.get("role", "")) != "staff" and float(sd.get("h", 2.0)) <= 12.0:
						pool.append([cid, int(tk), sd])
			if pool.is_empty():
				return
			var pick = pool.pick_random()
			var sm = Summon.new()
			sm.contract = pick[0]
			sm.tier = pick[1]
			sm.def = pick[2]
			sm.owner_f = c
			sm.team = c.team
			pj.get_tree().current_scene.add_child(sm)
			sm.global_position = pj.gp(pp)
			sm.facing = c.facing if c.get("facing") != null else 0.0
			sm.say("...", 1.5)
			_materialize(pj, sm, pj.gp(pp))
			Combat.popup_text(pp + Vector3.UP * 1.5, "Yaratıldı: %s" % String(pick[2].get("name", "")), Color(0.6, 1.0, 0.65))))
	Sfx.play("genjutsu", c.global_position, 0.6)


## Elde yanan Yin / Yang alevi: üç alev dili + küçük magatama kıvılcımları + yumuşak ışıma
static func _yin_yang_flame(ba: Node3D, body: Color, core: Color, line: Color) -> void:
	for k in 3:
		var fm := _flame(body, core, line, 0.3, 0.8, 3.0)
		var f := _mi(_m_card(1.5), fm)
		ba.add_child(f)
		f.position = Vector3(randf_range(-0.05, 0.05), -0.05 + k * 0.03, randf_range(-0.05, 0.05))
		f.scale = Vector3.ONE * (0.45 - k * 0.1)
	var g := _mi(_m_ball(10), _glow(Color(body.r, body.g, body.b, 0.8), 1.4, 0.3, 0.8))
	ba.add_child(g)
	g.scale = Vector3.ONE * 0.5
	var mm := _cel(body.lightened(0.2), 0.008, line, 0.3, 0.8)
	var tear := PackedVector2Array()
	for i in 14:   # magatama profili
		var a := TAU * i / 14.0
		tear.append(Vector2(cos(a), sin(a)) * 0.05)
	tear.append(Vector2(0.06, -0.09))
	var mg := _mi(_slab(tear, 0.015, Color.WHITE, _up_b()), mm)
	ba.add_child(mg)
	mg.position = Vector3(0, 0.38, 0)
	var tw := Game.safe_loops(mg.create_tween())
	tw.tween_property(mg, "position:y", 0.48, 0.35)
	tw.tween_property(mg, "position:y", 0.38, 0.35)


## Yerde ışınsal ince çizgiler (ref: arka plandaki yayılan çizgiler) + merkez halka
static func _creation_rays(pj: PathJutsu, at: Vector3) -> void:
	var b := MB.new()
	for k in 28:
		var a := TAU * k / 28.0 + randf_range(-0.04, 0.04)
		var r0 := 0.9
		var r1 := randf_range(3.2, 4.6)
		var p0 := Vector3(cos(a), 0, sin(a)) * r0
		var p1 := Vector3(cos(a), 0, sin(a)) * r1
		b.add_xf("box", Transform3D(_seg_xf(p0, p1, 1.0).basis * Basis.from_scale(Vector3(0.035, 1.0, 0.012)), (p0 + p1) * 0.5), Color.WHITE)
	b.add_slab(MB.hole(_star(40, 0.86, 0.8), Vector2.ZERO, 0.7, 32), 0.012, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	var m := _cel(Color(0.18, 0.16, 0.2, 0.85), 0.0, INK, 1.0, 3.0, true, 1.0)
	var mi := _mi(b.build(), m)
	_put(pj, mi, at + Vector3.UP * 0.03)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:y", 0.4, 1.6)
	_fade(mi, m, 1.3, 0.5)


## Elden çekirdeğe kavisli yolla akan ışık damlası
static func _light_mote(pj: PathJutsu, a: Vector3, b: Vector3, col: Color) -> void:
	var m := _glow(Color(col.r, col.g, col.b, 1.0), 0.8, 0.4, 1.0)
	var mo := _mi(_m_ball(8), m)
	_put(pj, mo, a)
	mo.scale = Vector3.ONE * 0.18
	var mid := (a + b) * 0.5 + Vector3.UP * randf_range(0.4, 1.0) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	var tw := mo.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(mo):
			mo.global_position = a.lerp(mid, u).lerp(mid.lerp(b, u), u), 0.0, 1.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(mo.queue_free)


## Işık patlaması: dışa fırlayan beyaz ışın levhaları + ışık kıymıkları
static func _creation_flash(pj: PathJutsu, pp: Vector3) -> void:
	var rm := _cel(Color(1.0, 0.99, 0.93), 0.0, INK, 2.5, 5.0, true, 1.0)
	var rays := Node3D.new()
	_put(pj, rays, pp)
	for k in 12:
		var a := TAU * k / 12.0
		var ray := _mi(_slab(PackedVector2Array([Vector2(0.3, -0.06), Vector2(2.6, 0.0), Vector2(0.3, 0.06)]), 0.02, Color.WHITE, _up_b()), rm)
		rays.add_child(ray)
		ray.rotation = Vector3(0, randf() * PI, a)
	rays.scale = Vector3.ONE * 0.2
	var tw := rays.create_tween()
	tw.tween_property(rays, "scale", Vector3.ONE * 1.3, 0.2).set_ease(Tween.EASE_OUT)
	_fade(rays, rm, 0.1, 0.3)
	_burst(pj, pp, _slab(_star(4, 0.18, 0.04), 0.02, Color.WHITE, _up_b()), _cel(Color(1.0, 0.98, 0.9), 0.0, INK, 0.6, 1.5, true), 24, 0.8,
		{"r": 0.3, "vmin": 3.0, "vmax": 7.0, "g": Vector3(0, -2, 0), "damp": 3.0, "spin": 300.0, "smin": 0.6, "smax": 1.3})


## Varlık ışığın içinden belirir: ayaklarında ışık halkası, yükselen ışık zerreleri
static func _materialize(pj: PathJutsu, _sm: Node3D, g: Vector3) -> void:
	var rm := _streak(Color(1.0, 1.0, 0.92), Color(0.8, 0.72, 0.45), 1.0, 3.0)
	var ring := _mi(_arc_band(1.0, 0.25, 0.0, TAU, 48), rm)
	_put(pj, ring, g + Vector3.UP * 0.06)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "rotation:y", PI, 0.6)
	_fade(ring, rm, 0.2, 0.45)
	_burst(pj, g + Vector3.UP * 0.4, _m_ball(6), _glow(Color(1.0, 0.98, 0.85), 0.8, 0.6, 1.5), 30, 1.2,
		{"r": 0.9, "dir": Vector3.UP, "spread": 20.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3.ZERO, "smin": 0.08, "smax": 0.16, "expl": 0.5})


# ================================================================== 3. RASENGAN "UZUHIKO" — sıkıştırılmış, fırlatılan girdap
## Elde sarmal küre oluşur (çevreden rüzgâr zerreleri emilir); fırlatılınca galaksi diski gibi yassı bir girdap halkası
## taşır, ardında burgu iz bırakır; çarpınca 6 kat büyür, yerde dairesel oyuk ve teğetsel savrulan taşlar.
static func rasengan_uzuhiko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt: Node3D = pj.tg(c, t, 26.0)
	var ba: Node3D = pj.bone_attach(c, "RightHand")
	if ba:
		var hb := _ras_ball(0.25, false)
		ba.add_child(hb)
		hb.scale = Vector3.ONE * 0.1
		hb.create_tween().tween_property(hb, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
		_burst(pj, Vector3.ZERO, _m_ball(6), _cel(Color(0.85, 0.93, 1.0), 0.0, INK, 0.3, 0.8), 26, 0.35,
			{"parent": ba, "r": 0.9, "vmin": 0.0, "vmax": 0.2, "radial": -26.0, "g": Vector3.ZERO, "smin": 0.04, "smax": 0.08, "expl": 0.0, "end_scale": 0.3})
		pj.free_after(0.4, ba)
	pj.after(0.4, func() -> void:
		if not pj.live(c):
			return
		var from: Vector3 = pj.hand_pos(c, true)
		var r := _ras_ball(0.25, true)
		var pr: Projectile = pj.shot(c, from, pj.aim_at(c, tt, from), 34.0, r, pj.inf(c, "rasengan_uzuhiko", 1.8, {"knock": 18.0, "launch": 4.0, "kind": "heavy"}), tt, false, 1.4, func(p: Vector3, _h) -> void:
			_ras_burst(pj, p))
		pr.homing_turn = 5.0
		_ras_wake(pj, pr))
	Sfx.play("wind", c.global_position, 1.5)


## Rasengan küresi: sarmal çekirdek + yumuşak ışıma + dönen yay halkaları; disk=true: sıkıştırılmış yassı girdap diski
static func _ras_ball(s: float, disk: bool, near0 := 0.3, near1 := 0.8) -> Node3D:
	var root := Node3D.new()
	var core := _mi(_m_ball(18), _spiral(near0, near1, 5.0, 3.5, 0.65))
	root.add_child(core)
	core.scale = Vector3.ONE * s * 2.0
	var g := _mi(_m_ball(12), _glow(Color(0.5, 0.75, 1.0, 0.9), 1.3, near0, near1))
	root.add_child(g)
	g.scale = Vector3.ONE * s * 3.0
	var spin := Node3D.new()
	root.add_child(spin)
	for k in 3:
		var rm := _streak(Color(0.92, 0.97, 1.0), Color(0.3, 0.55, 1.0), near0, near1)
		var arc := _mi(_arc_band(s * 1.35, s * 0.18, 0.0, TAU * 0.6, 24), rm)
		spin.add_child(arc)
		arc.rotation = Vector3(deg_to_rad(randf_range(-70, 70)), k * TAU / 3.0, deg_to_rad(randf_range(-40, 40)))
	var st := Game.safe_loops(spin.create_tween())
	st.tween_property(spin, "rotation:y", -TAU, 0.3).from(0.0)
	if disk:
		var dm := _spiral(near0, near1, 4.0, 2.2, 0.25)
		var dk := _mi(_m_ball(20), dm)
		root.add_child(dk)
		dk.scale = Vector3(s * 4.2, s * 0.45, s * 4.2)
		var dt := Game.safe_loops(dk.create_tween())
		dt.tween_property(dk, "rotation:y", -TAU, 0.4).from(0.0)
	return root


## Uçuş izi: iki yörünge noktasından burgu şeklinde akan açık mavi rüzgâr zerreleri
static func _ras_wake(pj: PathJutsu, pr: Projectile) -> void:
	if pr == null or not is_instance_valid(pr):
		return
	var rot := Node3D.new()
	pr.add_child(rot)
	var m := _cel(Color(0.82, 0.92, 1.0), 0.0, INK, 0.5, 1.5)
	for k in 2:
		var e := Node3D.new()
		rot.add_child(e)
		e.position = Vector3(cos(k * PI), sin(k * PI), 0) * 0.32
		_burst(pj, Vector3.ZERO, _m_ball(6), m, 40, 0.35, {"parent": e, "r": 0.02, "vmin": 0.0, "vmax": 0.3, "g": Vector3.ZERO,
			"smin": 0.07, "smax": 0.11, "expl": 0.0, "one": false, "keep": true, "end_scale": 0.2})
	var tw := Game.safe_loops(rot.create_tween())
	tw.tween_property(rot, "rotation:z", TAU, 0.18).from(0.0)
	var sm := _streak(Color(0.9, 0.96, 1.0, 0.8), Color(0.35, 0.6, 1.0), 0.5, 1.5)
	var tail := _mi(_m_streak(), sm)
	pr.add_child(tail)
	tail.scale = Vector3(0.35, 0.35, 2.4)


## Çarpma: büyük rasengan 6 kat şişip öğütür; sonra kesik rüzgâr halkaları, yerde dairesel oyuk, teğetsel savrulan taşlar
static func _ras_burst(pj: PathJutsu, p: Vector3) -> void:
	var big := _ras_ball(0.4, false, 4.0, 7.0)
	_put(pj, big, p)
	var tw := big.create_tween()
	tw.tween_property(big, "scale", Vector3.ONE * 6.0, 0.25)
	tw.tween_callback(func() -> void:
		var g: Vector3 = pj.gp(p)
		for k in 3:
			var rm := _streak(Color(0.92, 0.97, 1.0), Color(0.3, 0.55, 1.0), 3.0, 6.0)
			var ring := _mi(_arc_band(1.0, 0.22, randf() * TAU, randf() * TAU + TAU * 0.7, 40), rm)
			_put(pj, ring, p + Vector3.UP * (k - 1) * 0.35)
			ring.rotation = Vector3(deg_to_rad(randf_range(-15, 15)), 0, deg_to_rad(randf_range(-15, 15)))
			var rt := ring.create_tween()
			rt.tween_property(ring, "scale", Vector3.ONE * (4.5 + k), 0.4).set_ease(Tween.EASE_OUT)
			rt.parallel().tween_property(ring, "rotation:y", -2.5, 0.4)
			_fade(ring, rm, 0.1, 0.3)
		var cm := _cel(Color(0.38, 0.3, 0.22, 0.9), 0.0, INK, 1.5, 4.0, true, 1.0)
		var b := MB.new()
		b.add_slab(_blob(1.6, 24, 0.12), 0.02, Color(0.75, 0.75, 0.75), Transform3D(_flat_b(), Vector3.ZERO))
		for k in 10:   # sarmal oyuk çizgileri (dönen kürenin yerde bıraktığı izler)
			var a0 := TAU * k / 10.0
			var pts: PackedVector2Array = PackedVector2Array()
			for i in 6:
				var a := a0 + i * 0.14
				pts.append(Vector2(cos(a), sin(a)) * (0.5 + i * 0.32))
			for i in range(5, -1, -1):
				var a := a0 + i * 0.14 + 0.06
				pts.append(Vector2(cos(a), sin(a)) * (0.5 + i * 0.32))
			b.add_slab(pts, 0.03, Color(0.45, 0.45, 0.45), Transform3D(_flat_b(), Vector3(0, 0.012, 0)))
		var crater := _mi(b.build(), cm)
		_put(pj, crater, g + Vector3.UP * 0.03)
		_fade(crater, cm, 3.0, 1.2)
		var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_burst(pj, g + Vector3.UP * 0.4, _m_chip(), _cel(EARTH, 0.014, DUST_INK, 0.6, 1.5), 22, 1.0,
			{"r": 1.2, "dir": side, "spread": 180.0, "vmin": 5.0, "vmax": 10.0, "g": Vector3(0, -14, 0), "spin": 500.0, "smin": 0.6, "smax": 1.5, "hold": 0.8})
		var bt := big.create_tween()
		bt.tween_property(big, "scale", Vector3.ONE * 6.6, 0.1)
		bt.tween_property(big, "scale", Vector3.ONE * 0.2, 0.12).set_ease(Tween.EASE_IN)
		bt.tween_callback(big.queue_free))


# ================================================================== 4. HACHIMON — kapıların açılışı
## ref: Lee — bedenden yükselen yeşil chakra dilleri, çevresinde sarmal mavi chakra şeritleri, kırmızı dikey hız çizgileri,
## ayaklarda kabaran toz bulutları; yerde yarıklar, basınçla havalanan taşlar. Yeşil alev 15 sn bedeni sarar.
static func hachimon(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var g: Vector3 = pj.gp(c.global_position)
	_gate_cracks(pj, g, 5.0)
	_gate_dust(pj, g)
	_gate_rocks(pj, g)
	_gate_streaks(pj, g)
	_gate_ribbons(pj, c)
	var a := _gate_aura(pj, c)
	if c is Player:
		Buffs.add("hachimon_3", 15.0, {"melee": 1.35, "speed": 1.2, "_name": "Üç Kapı Açık", "_desc": "yakın dövüş +%35, hız +%20; can yavaşça erir"})
	pj.every(15.0, 1.0, func(_i: int, _k: float) -> void:
		if pj.live(c) and c is Player:
			c.hp = maxf(1.0, c.hp - c.max_hp * 0.01), func() -> void:
		if is_instance_valid(a):
			_gate_aura_end(a))
	pj.shake(0.6)
	Sfx.play("roar", c.global_position, 1.3, 0.6)


## Yerde ışınsal kırık yarıklar + ortada basınç çukuru
static func _gate_cracks(pj: PathJutsu, g: Vector3, R: float) -> void:
	var b := MB.new()
	b.add_slab(_blob(1.3, 20, 0.2), 0.02, Color(0.62, 0.62, 0.62), Transform3D(_flat_b(), Vector3.ZERO))
	for k in 9:
		var a := TAU * k / 9.0 + randf_range(-0.2, 0.2)
		var p := Vector3(cos(a), 0, sin(a)) * 0.9
		var w := 0.16
		var n := 5 + randi() % 3
		for i in n:
			a += randf_range(-0.45, 0.45)
			var q := p + Vector3(cos(a), 0, sin(a)) * (R / n) * randf_range(0.7, 1.1)
			b.add_xf("box", Transform3D(_seg_xf(p, q, 1.0).basis * Basis.from_scale(Vector3(w, 1.0, 0.03)), (p + q) * 0.5 + Vector3.UP * 0.01), Color(0.2, 0.2, 0.2))
			if randf() < 0.4:   # yan çatlak
				var a2 := a + randf_range(0.6, 1.0) * (1.0 if randf() < 0.5 else -1.0)
				var q2 := q + Vector3(cos(a2), 0, sin(a2)) * randf_range(0.4, 0.8)
				b.add_xf("box", Transform3D(_seg_xf(q, q2, 1.0).basis * Basis.from_scale(Vector3(w * 0.5, 1.0, 0.03)), (q + q2) * 0.5 + Vector3.UP * 0.01), Color(0.2, 0.2, 0.2))
			p = q
			w *= 0.8
	var m := _cel(Color(0.3, 0.24, 0.18, 0.95), 0.0, INK, 1.5, 3.5, true, 1.0)
	var mi := _mi(b.build(), m)
	_put(pj, mi, g + Vector3.UP * 0.03)
	mi.scale = Vector3(0.3, 1, 0.3)
	mi.create_tween().tween_property(mi, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	_fade(mi, m, 4.0, 1.5)


## Ayakların çevresinde dışa itilen kabarık toz tümsekleri (ref)
static func _gate_dust(pj: PathJutsu, g: Vector3) -> void:
	for k in 10:
		var a := TAU * k / 10.0 + randf_range(-0.15, 0.15)
		var dv := Vector3(cos(a), 0, sin(a))
		var m := _cel(Color.WHITE, 0.03, DUST_INK, 3.0, 6.0, false, 0.84)
		var mo := _mi(_m_mound("dust", DUST, DUST_D, false, k % 3), m)
		_put(pj, mo, g + dv * 1.2)
		mo.rotation.y = randf() * TAU
		var s := randf_range(0.55, 0.85)
		mo.scale = Vector3.ONE * s * 0.3
		var tw := mo.create_tween()
		tw.tween_property(mo, "scale", Vector3.ONE * s, 0.25).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mo, "global_position", g + dv * randf_range(2.6, 3.4), 0.6).set_ease(Tween.EASE_OUT)
		tw.tween_property(mo, "scale", Vector3(s * 1.3, s * 0.5, s * 1.3), 0.6)
		_fade(mo, m, 0.55, 0.6)


## Basınçla havalanan taşlar: yavaşça yükselir, sonra düşüp sekerek söner
static func _gate_rocks(pj: PathJutsu, g: Vector3) -> void:
	for k in 8:
		var a := randf() * TAU
		var p := g + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 2.6)
		var m := _cel(Color(0.6, 0.55, 0.48), 0.018, DUST_INK, 1.0, 2.5)
		var r := _mi(_m_chip(), m)
		_put(pj, r, p)
		r.scale = Vector3.ONE * randf_range(1.0, 2.2)
		r.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var h := randf_range(0.8, 1.7)
		var tw := r.create_tween()
		tw.tween_property(r, "global_position", p + Vector3.UP * h, randf_range(0.45, 0.7)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(r, "rotation:y", r.rotation.y + randf_range(-2, 2), 0.7)
		tw.tween_property(r, "global_position", p, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(r, "global_position", p + Vector3.UP * 0.15, 0.08)
		tw.tween_property(r, "global_position", p, 0.08)
		_fade(r, m, 1.6, 0.6)


## Kırmızı dikey hız çizgileri (ref arka planı): halkada yükselip söner
static func _gate_streaks(pj: PathJutsu, g: Vector3) -> void:
	var m := _streak(Color(1.0, 0.35, 0.38, 0.85), Color(0.75, 0.05, 0.12), 2.5, 4.5)
	var holder := Node3D.new()
	_put(pj, holder, g)
	for k in 26:
		var a := TAU * k / 26.0 + randf_range(-0.1, 0.1)
		var s := _mi(_m_streak(), m)
		holder.add_child(s)
		var p := Vector3(cos(a), 0, sin(a)) * randf_range(2.8, 4.0) + Vector3.UP * randf_range(0.0, 1.5)
		s.position = p
		s.look_at(g + p + Vector3.UP, Vector3.FORWARD)   # -Z yukarı: baş yukarıda, iz aşağıda
		s.scale = Vector3(randf_range(0.08, 0.16), randf_range(0.08, 0.16), randf_range(1.6, 3.2))
		var tw := s.create_tween()
		tw.tween_property(s, "position", p + Vector3.UP * randf_range(2.0, 3.5), 0.6).set_delay(randf() * 0.15)
	_fade(holder, m, 0.25, 0.55)


## Sarmal mavi chakra şeritleri: bedenin çevresinde dönerek yükselir
static func _gate_ribbons(pj: PathJutsu, c: Node3D) -> void:
	for k in 2:
		var pts: Array = []
		var nrm: Array = []
		for i in 36:
			var u := i / 35.0
			var a := u * TAU * 1.4 + k * PI
			var r := 0.75 + sin(u * 9.0) * 0.06
			var dv := Vector3(cos(a), 0, sin(a))
			pts.append(dv * r + Vector3.UP * (u * 2.3))
			nrm.append(dv)
		var m := _streak(Color(0.75, 0.9, 1.0, 0.9), Color(0.25, 0.5, 1.0), 1.2, 2.5)
		var rb := _mi(_ribbon(pts, 0.32, nrm), m)
		_put(pj, rb, c.global_position)
		rb.scale = Vector3(1.0, 0.2, 1.0)
		var tw := rb.create_tween()
		tw.tween_property(rb, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(rb, "rotation:y", (TAU if k == 0 else -TAU) * 0.9, 1.4)
		_fade(rb, m, 0.9, 0.5)


## Yeşil kapı alevi: bedenden yükselen alev dilleri + yükselen yeşil kıvılcımlar (c'nin çocuğu, 15 sn)
static func _gate_aura(pj: PathJutsu, c: Node3D) -> Node3D:
	var a := Node3D.new()
	c.add_child(a)
	a.position = Vector3.ZERO
	var mats: Array = []
	for k in 9:
		var fm := _flame(Color(GATE.r, GATE.g, GATE.b, 0.55), GATE_CORE, GATE_INK, 1.2, 2.4, 3.2)
		mats.append(fm)
		var f := _mi(_m_card(1.6), fm)
		a.add_child(f)
		var ang := TAU * k / 9.0
		f.position = Vector3(cos(ang) * 0.42, 0.15 + (k % 3) * 0.55, sin(ang) * 0.42)
		f.scale = Vector3.ONE * randf_range(0.4, 0.6)
	var sp := _burst(pj, Vector3(0, 1.0, 0), _slab(_star(4, 0.12, 0.03), 0.01, Color.WHITE, _up_b()), _cel(GATE_CORE, 0.0, INK, 1.2, 2.4, true), 22, 0.8,
		{"parent": a, "r": 0.5, "dir": Vector3.UP, "spread": 15.0, "vmin": 1.5, "vmax": 3.0, "g": Vector3(0, 1.0, 0), "smin": 0.6, "smax": 1.1,
		"expl": 0.0, "one": false, "keep": true})
	a.set_meta("mats", mats)
	a.set_meta("sparks", sp)
	a.scale = Vector3(1.0, 0.1, 1.0)
	a.create_tween().tween_property(a, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return a


static func _gate_aura_end(a: Node3D) -> void:
	var sp = a.get_meta("sparks") if a.has_meta("sparks") else null
	if sp != null and is_instance_valid(sp):
		(sp as CPUParticles3D).emitting = false
	var mats: Array = a.get_meta("mats") if a.has_meta("mats") else []
	var tw := a.create_tween()
	tw.tween_method(func(v: float) -> void:
		for m in mats:
			_sp(m, "fade", v), 1.0, 0.0, 0.6)
	tw.tween_callback(a.queue_free)


# ================================================================== 5. CHŌJŪ GIGA: RYŪ — mürekkep ejderi
## Önde parşömen açılır, fırça izi çizilir; mürekkep sıçrar ve sayfadan kara bir ejder kıvrılarak çıkar: baş mermidir,
## gövde boğumları başın izini sürer, ardından mürekkep damlar. Çarpınca yere kara mürekkep lekeleri ve fırça halkası.
static func hoki_sumi_ryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt: Node3D = pj.tg(c, t, 28.0)
	var sc := _scroll()
	c.add_child(sc)
	sc.position = Vector3(0, 1.2, 0.7)
	pj.free_after(0.9, sc)
	pj.after(0.4, func() -> void:
		if not pj.live(c):
			return
		var from: Vector3 = c.global_position + Vector3.UP * 1.3 + c.face_dir() * 1.0
		_sumi_spray(pj, from, 30)
		var head := _ink_head(1.6)
		var pr: Projectile = pj.shot(c, from, pj.aim_at(c, tt, from), 22.0, head, pj.inf(c, "hoki_sumi_ryu", 1.8, {"knock": 14.0, "kind": "heavy"}), tt, false, 1.8, func(p: Vector3, _h) -> void:
			_sumi_spray(pj, p, 40)
			_ink_splat(pj, p))
		_ink_body(pj, pr, from, 1.6))
	Sfx.play("poof", c.global_position, 0.8)


## Parşömen: iki sap arasında açılan kâğıt, üstünde hızla çizilen kara fırça kıvrımı
static func _scroll() -> Node3D:
	var root := Node3D.new()
	var pm := _cel(PAPER, 0.012, Color(0.35, 0.3, 0.22), 0.6, 1.4, true, 0.85)
	var b := MB.new()
	b.add("box", Vector3.ZERO, Vector3(1.3, 0.015, 0.55), Color.WHITE)
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(sx * 0.67, 0, 0), Vector3(0.07, 0.62, 0.07), Color(0.55, 0.3, 0.18), Vector3(90, 0, 0), 8)
	var paper := _mi(b.build(), pm)
	root.add_child(paper)
	paper.scale = Vector3(0.05, 1, 1)
	paper.create_tween().tween_property(paper, "scale", Vector3.ONE, 0.16).set_ease(Tween.EASE_OUT)
	var pts := PackedVector2Array()
	var back := PackedVector2Array()
	for i in 16:
		var u := i / 15.0
		var x := lerpf(-0.55, 0.55, u)
		var y := sin(u * 9.0) * 0.12
		var w := 0.035 * (1.0 - absf(u - 0.4))
		pts.append(Vector2(x, y + w))
		back.append(Vector2(x, y - w))
	back.reverse()
	pts.append_array(back)
	var im := _cel(SUMI, 0.0, INK, 0.6, 1.4, true, 1.0)
	var stroke := _mi(_slab(pts, 0.01, Color.WHITE, _flat_b()), im)
	root.add_child(stroke)
	stroke.position = Vector3(0, 0.012, 0)
	stroke.scale = Vector3(0.02, 1, 1)
	var tw := stroke.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(stroke, "scale", Vector3.ONE, 0.25)
	return root


## Ejder başı (ileri -Z): uzun burun, açık çene, boynuzlar, bıyıklar, beyaz fırça göz / pul vurguları
static func _ink_head(s: float) -> Node3D:
	var mesh := _cached("mesh:ink_head", func() -> Mesh:
		var b := MB.new()
		var hi := Color(0.94, 0.94, 0.97)
		b.add("sphere", Vector3(0, 0.05, 0.0), Vector3(0.62, 0.48, 0.75), SUMI, Vector3.ZERO, 12)
		b.add("box", Vector3(0, 0.12, -0.42), Vector3(0.42, 0.16, 0.5), SUMI, Vector3(8, 0, 0))     # üst çene
		b.add("box", Vector3(0, -0.12, -0.36), Vector3(0.38, 0.12, 0.46), SUMI, Vector3(-16, 0, 0))  # alt çene (açık)
		for sx in [-1.0, 1.0]:
			b.add("cone", Vector3(sx * 0.17, 0.38, 0.2), Vector3(0.08, 0.6, 0.08), SUMI, Vector3(60, 0, sx * -18), 4)   # boynuz
			b.add("cyl", Vector3(sx * 0.3, 0.02, -0.6), Vector3(0.025, 0.75, 0.025), SUMI, Vector3(-80, sx * -40, 0), 4)   # bıyık
			b.add("box", Vector3(sx * 0.2, 0.18, -0.15), Vector3(0.12, 0.04, 0.02), hi, Vector3(0, sx * -25, sx * 10))     # göz
			b.add("box", Vector3(sx * 0.29, 0.0, 0.05), Vector3(0.02, 0.18, 0.3), hi, Vector3(0, 0, sx * 20))              # yanak fırça çizgisi
			for k in 3:
				b.add("cone", Vector3(sx * 0.12 - sx * k * 0.05, 0.03, -0.62 + k * 0.08), Vector3(0.04, 0.12, 0.04), hi, Vector3(180, 0, 0), 3)   # diş
		return b.build())
	var root := Node3D.new()
	var mi := _mi(mesh, _cel(Color.WHITE, 0.03, SUMI_EDGE, 0.6, 1.6, false, 0.9))
	root.add_child(mi)
	mi.scale = Vector3.ONE * s
	return root


## Ejder gövdesi: başın konum geçmişini izleyen 12 boğum (sırt yüzgeci + beyaz pul çizgisi), damlayan mürekkep;
## baş yok olunca boğumlar damlalara dağılır
static func _ink_body(pj: PathJutsu, pr: Projectile, from: Vector3, s: float) -> void:
	if pr == null or not is_instance_valid(pr):
		return
	var seg_mesh := _cached("mesh:ink_seg", func() -> Mesh:
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.7, 0.62, 0.62), SUMI, Vector3.ZERO, 10)
		b.add("cone", Vector3(0, 0.38, 0.05), Vector3(0.06, 0.32, 0.22), SUMI, Vector3(30, 0, 0), 3)
		b.add("box", Vector3(0.2, 0.05, 0), Vector3(0.02, 0.2, 0.3), Color(0.92, 0.92, 0.95), Vector3(0, 0, -20))
		return b.build())
	var m := _cel(Color.WHITE, 0.03, SUMI_EDGE, 0.6, 1.6, false, 0.9)
	var segs: Array = []
	var N := 12
	for i in N:
		var sg := _mi(seg_mesh, m)
		_put(pj, sg, from)
		var k := lerpf(1.0, 0.3, float(i) / N)
		sg.scale = Vector3.ONE * s * k
		sg.visible = false
		segs.append(sg)
	var hist: Array = [from]
	var pw = weakref(pr)
	var drip := _burst(pj, from, _m_drop(), _cel(SUMI, 0.01, SUMI_EDGE, 0.5, 1.2), 30, 0.7, {"r": 0.3, "dir": Vector3.DOWN, "spread": 30.0,
		"vmin": 0.5, "vmax": 1.5, "g": Vector3(0, -12, 0), "smin": 0.6, "smax": 1.1, "expl": 0.0, "one": false, "keep": true, "align": true})
	var state := {"gone": false}
	pj.every(2.2, 1.0 / 40.0, func(_i: int, _k: float) -> void:
		if state["gone"]:
			return
		var p = pw.get_ref()
		if p == null or not is_instance_valid(p) or (p as Projectile).dead:
			state["gone"] = true
			_stop(drip)
			for sg in segs:
				if is_instance_valid(sg):
					_sumi_spray(pj, (sg as Node3D).global_position, 4)
					var tw := (sg as Node3D).create_tween()
					tw.tween_property(sg, "scale", Vector3.ONE * 0.05, 0.25).set_ease(Tween.EASE_IN)
					tw.tween_callback((sg as Node3D).queue_free)
			return
		var hp := (p as Node3D).global_position
		hist.push_front(hp)
		if hist.size() > N * 3 + 2:
			hist.pop_back()
		if is_instance_valid(drip):
			drip.global_position = hp
		for i in N:
			var sg: MeshInstance3D = segs[i]
			if not is_instance_valid(sg):
				continue
			var j := mini((i + 1) * 3, hist.size() - 1)
			var q: Vector3 = hist[j]
			var nx: Vector3 = hist[maxi(j - 1, 0)]
			var side := (nx - q).cross(Vector3.UP).normalized()
			q += side * sin(Time.get_ticks_msec() * 0.008 + i * 0.7) * 0.25 * s * (float(i) / N)
			sg.visible = j > 0 and q.distance_to(hp) > 0.2
			sg.global_position = q
			_look(sg, nx), func() -> void:
		_stop(drip)
		for sg in segs:
			if is_instance_valid(sg):
				(sg as Node3D).queue_free())


static func _sumi_spray(pj: PathJutsu, pos: Vector3, n: int) -> void:
	_burst(pj, pos, _m_drop(), _cel(SUMI, 0.01, SUMI_EDGE, 0.5, 1.2), n, 0.7, {"r": 0.35, "vmin": 2.0, "vmax": 5.5, "spread": 90.0,
		"g": Vector3(0, -14, 0), "smin": 0.5, "smax": 1.3, "align": true, "hold": 0.8})


## Yere kara mürekkep lekeleri (ana leke + uydu damlaları) ve genişleyen fırça halkası
static func _ink_splat(pj: PathJutsu, p: Vector3) -> void:
	var g: Vector3 = pj.gp(p)
	var b := MB.new()
	b.add_slab(_blob(1.4, 22, 0.4), 0.02, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	for k in 9:
		var a := randf() * TAU
		var r := randf_range(1.6, 2.8)
		b.add_slab(_blob(randf_range(0.1, 0.3), 10, 0.3), 0.02, Color.WHITE, Transform3D(_flat_b(), Vector3(cos(a) * r, 0, sin(a) * r)))
		var tip := Vector3(cos(a), 0, sin(a)) * (r - 0.2)
		b.add_xf("box", Transform3D(_seg_xf(Vector3(cos(a), 0, sin(a)) * 1.0, tip, 1.0).basis * Basis.from_scale(Vector3(0.09, 1.0, 0.02)), (tip + Vector3(cos(a), 0, sin(a))) * 0.5), Color.WHITE)
	var m := _cel(Color(SUMI.r, SUMI.g, SUMI.b, 0.92), 0.0, INK, 1.5, 3.5, true, 1.0)
	var mi := _mi(b.build(), m)
	_put(pj, mi, g + Vector3.UP * 0.03)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(0.3, 1, 0.3)
	mi.create_tween().tween_property(mi, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	_fade(mi, m, 3.0, 1.5)
	var rm := _streak(Color(0.08, 0.08, 0.1, 0.95), Color(0.02, 0.02, 0.03), 2.0, 4.0)
	var ring := _mi(_arc_band(1.0, 0.3, randf() * TAU, randf() * TAU + TAU * 0.85, 40), rm)
	_put(pj, ring, p)
	ring.rotation = Vector3(deg_to_rad(randf_range(-25, 25)), 0, deg_to_rad(randf_range(-25, 25)))
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 3.2, 0.35).set_ease(Tween.EASE_OUT)
	_fade(ring, rm, 0.1, 0.3)


# ================================================================== 6. SAIHŌ HAISHUTSU — Jūgo hücre aktarımı
## ref: turuncu-kızıl, kaynayan, benekli hücre kütlesi. Kullanıcının elinden yaralı müttefike hücre kolu akar,
## yaranın üstünde hücre öbekleri kabarır, sonra bedene çekilip kapanır (yoksa kendi bedeninde kabarır).
static func saiho_haishutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tgt: Node3D = c
	for a in pj.get_tree().get_nodes_in_group("fighters"):
		if a != c and pj.live(a) and not Combat.hostile(c, a) and a.global_position.distance_to(c.global_position) < 4.0 and a.get("hp") != null and a.hp < a.max_hp:
			tgt = a
			break
	if tgt != c:
		_cell_arm(pj, c, tgt)
	_cell_patches(pj, tgt, 0.25 if tgt != c else 0.05)
	pj.every(1.0, 0.1, func(_i: int, _k: float) -> void:
		if pj.live(c) and pj.live(tgt):
			_burst(pj, tgt.global_position + Vector3.UP * 1.1, _m_ball(6), _cel(Color(1.0, 0.6, 0.2), 0.008, Color(0.4, 0.1, 0.04), 0.5, 1.2), 4, 0.5,
				{"r": 0.4, "dir": Vector3.UP, "spread": 60.0, "vmin": 0.3, "vmax": 1.0, "g": Vector3(0, 0.5, 0), "smin": 0.06, "smax": 0.12}))
	pj.after(0.8, func() -> void:
		if pj.live(tgt):
			pj.heal(tgt, tgt.max_hp * 0.4))
	Sfx.play("heal", c.global_position, 0.8)


## Elden hedefe sarkan yol boyunca akan hücre boncukları: 0.4 sn'de uzanır, 0.85'te hedefe doğru geri çekilir
static func _cell_arm(pj: PathJutsu, c: Node3D, tgt: Node3D) -> void:
	var m := _smat("cell", CELL_SH, 0.5, 1.4)
	m.set_shader_parameter("cells", 7.0)
	m.set_shader_parameter("wob", 0.02)
	var N := 14
	var beads: Array = []
	for i in N:
		var bd := _mi(_m_ball(12), m)
		_put(pj, bd, c.global_position)
		bd.visible = false
		beads.append(bd)
	var cw = weakref(c)
	var tw = weakref(tgt)
	pj.every(1.1, 1.0 / 30.0, func(_i: int, k: float) -> void:
		var cc = cw.get_ref()
		var tg = tw.get_ref()
		if cc == null or tg == null or not is_instance_valid(cc) or not is_instance_valid(tg):
			for bd in beads:
				if is_instance_valid(bd):
					(bd as Node3D).visible = false
			return
		var a: Vector3 = pj.hand_pos(cc, true)
		var b: Vector3 = (tg as Node3D).global_position + Vector3.UP * 1.1
		var mid := (a + b) * 0.5 + Vector3.DOWN * 0.35
		var head := clampf(k / 0.36, 0.0, 1.0)
		var tail := clampf((k - 0.62) / 0.3, 0.0, 1.0)
		for i in N:
			var bd: MeshInstance3D = beads[i]
			if not is_instance_valid(bd):
				continue
			var u := (float(i) + 0.5) / N
			bd.visible = u <= head and u >= tail
			var p := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
			p += Vector3(sin(u * 18.0 + k * 20.0), cos(u * 15.0 + k * 17.0), 0) * 0.05
			bd.global_position = p
			bd.scale = Vector3.ONE * (0.24 + 0.08 * sin(u * 12.0 + k * 25.0)), func() -> void:
		for bd in beads:
			if is_instance_valid(bd):
				(bd as Node3D).queue_free())


## Hedefin bedeninde kabaran hücre öbekleri: büyür, kaynar, iyileşmeyle bedene çekilir
static func _cell_patches(pj: PathJutsu, tgt: Node3D, delay: float) -> void:
	var h := float(tgt.get("height")) if tgt.get("height") != null else 1.8
	var spots := [Vector3(0.18, 0.62, 0.1), Vector3(-0.2, 0.5, 0.05), Vector3(0.05, 0.75, -0.15), Vector3(-0.1, 0.35, 0.18),
		Vector3(0.22, 0.3, -0.05), Vector3(-0.15, 0.85, 0.1), Vector3(0.0, 0.55, 0.22)]
	for k in spots.size():
		var m := _smat("cell", CELL_SH, 0.5, 1.4)
		m.set_shader_parameter("cells", 9.0)
		m.set_shader_parameter("wob", 0.04)
		var bl := _mi(_m_ball(14), m)
		tgt.add_child(bl)
		var sp: Vector3 = spots[k]
		bl.position = Vector3(sp.x, sp.y * h, sp.z)
		var s := randf_range(0.22, 0.34)
		bl.scale = Vector3.ONE * 0.01
		var tw := bl.create_tween()
		tw.tween_interval(delay + k * 0.05)
		tw.tween_property(bl, "scale", Vector3(s * 1.1, s, s * 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(bl, "scale", Vector3(s * 0.9, s * 1.15, s * 0.9), 0.15)
		tw.tween_property(bl, "scale", Vector3(s, s, s), 0.15)
		tw.tween_interval(maxf(0.0, 0.8 - delay - k * 0.05 - 0.55))
		tw.tween_property(bl, "scale", Vector3.ONE * 0.01, 0.4).set_ease(Tween.EASE_IN)
		tw.tween_callback(bl.queue_free)


# ================================================================== 7. SHIKOMI KUGUTSU: SHINSHIN HAPPA — sekiz dalga iğne
## ref: kuklanın pelerininden her yöne fışkıran gümüş elmas iğneler (koyu kontur). Her dalgada kukla geri teper,
## ağzında parıltı, çevreye halka halinde iğne saçılır; hedefe dördü uçar; sonunda yere saplanmış iğneler kalır.
static func shikomi_shinshin_happa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt: Node3D = pj.tg(c, t, 22.0)
	pj.busy(c, 1.2)
	var d: Vector3 = pj.fwd(c, t)
	var pup := _puppet(pj, c, c.global_position + d * 2.0 + Vector3.UP * 3.0, d, 2.0)
	var nm := _m_spike(false)
	var mat := _cel(STEEL, 0.012, STEEL_INK, 0.4, 1.0, false, 0.62, 0.6)
	var tip_m := _cel(VENOM, 0.0, INK, 0.4, 1.0)
	for w in 8:
		pj.after(0.3 + w * 0.1, func() -> void:
			if not (pj.live(c) and is_instance_valid(pup)):
				return
			var o: Vector3 = pup.global_position + Vector3.UP * 1.6
			_jolt(pup, 0.08)
			_glint(pj, o + d * 0.3, d, 0.9)
			_burst(pj, o, _m_spike(true), mat, 16, 0.32, {"r": 0.25, "vmin": 16.0, "vmax": 24.0, "g": Vector3.ZERO, "align": true,
				"smin": 0.8, "smax": 1.2, "hold": 0.8, "end_scale": 1.0})
			for k in 4:
				var dir: Vector3 = pj.aim_at(c, tt, o).rotated(Vector3.UP, randf_range(-0.35, 0.35))
				dir.y += randf_range(-0.1, 0.05)
				var nd := _mi(nm, mat)
				var tip := _mi(_m_ball(6), tip_m)
				nd.add_child(tip)
				tip.position = Vector3(0, 0, -0.42)
				tip.scale = Vector3.ONE * 0.05
				pj.shot(c, o, dir.normalized(), 36.0, nd, pj.inf(c, "shikomi_shinshin_happa", 0.12, {"knock": 1.0, "kind": "light", "poison": 2.0}), null, false, 0.8))
	var tw = weakref(tt) if tt else null
	pj.after(1.2, func() -> void:
		var tp: Vector3 = c.global_position + d * 10.0
		if tw != null and tw.get_ref() != null and is_instance_valid(tw.get_ref()):
			tp = (tw.get_ref() as Node3D).global_position
		_needle_field(pj, pj.gp(tp), d, mat))
	Sfx.play("throw_kunai", c.global_position, 1.4)


## Yere saplanmış iğneler: eğik, kümeli; 3 sn sonra söner
static func _needle_field(pj: PathJutsu, g: Vector3, d: Vector3, mat: Material) -> void:
	var root := Node3D.new()
	_put(pj, root, g)
	var nm := _m_spike(false)
	for k in 16:
		var n := _mi(nm, mat)
		root.add_child(n)
		var off := Vector3(randf_range(-2.2, 2.2), 0, randf_range(-2.2, 2.2))
		n.position = off + Vector3.UP * 0.3
		var dv := (d + Vector3.DOWN * randf_range(0.8, 1.6) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))).normalized()
		n.look_at(root.global_position + n.position + dv, Vector3.UP)
	var tw := root.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(root, "position:y", root.position.y - 0.4, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


# ================================================================== 8. KUGUTSU NO JUTSU: GISHU SENBON — protez kol
## ref: kahverengi kapsül kol, yüzeyinde çıkıntılı fırlatma tüpleri; arkasında sarı dikenli itiş alevi. İpte döner,
## her atışta tüp ağzında parıltı; senbonlar beyaz hız çizgileriyle uçar; sonunda kol tahta sopalara ayrılır.
static func gishu_senbon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt: Node3D = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	var am := _gishu_arm()
	var o: Vector3 = pj.hand_pos(c) + Vector3.UP * 0.2
	pj.scene_add(am, o)
	am.look_at(o + pj.fwd(c, t), Vector3.UP)
	_strings(pj, c, am, 1.0, [Vector3(0.0, 0.12, 0.25), Vector3(0.0, -0.12, 0.25)])
	var sm := _cel(STEEL, 0.008, STEEL_INK, 0.4, 1.0, false, 0.65, 0.6)
	var trail := _streak(Color(1, 1, 1, 0.9), Color(0.7, 0.8, 0.95), 0.4, 1.0)
	for k in 14:
		pj.after(0.2 + k * 0.04, func() -> void:
			if not (pj.live(c) and is_instance_valid(am)):
				return
			am.rotation.z += 0.6
			var base: Vector3 = pj.aim_at(c, tt, o)
			var dir := base.rotated(Vector3.UP, (k - 7) * 0.06)
			_glint(pj, am.global_position + dir * 0.45, dir, 0.5, Color(1.0, 0.95, 0.7))
			var nd := _mi(_m_senbon(false), sm)
			var tr := _mi(_m_streak(), trail)
			nd.add_child(tr)
			tr.scale = Vector3(0.06, 0.06, 1.6)
			pj.shot(c, am.global_position, dir, 40.0, nd, pj.inf(c, "gishu_senbon", 0.15, {"knock": 1.0, "kind": "light", "poison": 1.5}), null, false, 0.7))
	var aw = weakref(am)
	pj.after(1.0, func() -> void:
		var a = aw.get_ref()
		if a == null or not is_instance_valid(a):
			return
		_splinters(pj, (a as Node3D).global_position, 1.0)
		var tw := (a as Node3D).create_tween()
		tw.tween_property(a, "scale", (a as Node3D).scale * 0.05, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback((a as Node3D).queue_free))
	pj.free_after(1.6, am)
	Sfx.play("throw_kunai", c.global_position, 1.6)


## Protez kol (uzun eksen Z, ön -Z): kapsül gövde, çıkıntılı tüpler + kara delikler, bilek bandı, arkada itiş alevi
static func _gishu_arm() -> Node3D:
	var mesh := _cached("mesh:gishu_arm", func() -> Mesh:
		var b := MB.new()
		var body := Color(0.56, 0.43, 0.36)
		b.add("cyl", Vector3.ZERO, Vector3(0.28, 0.75, 0.28), body, Vector3(90, 0, 0), 14)
		b.add("sphere", Vector3(0, 0, -0.37), Vector3(0.28, 0.28, 0.2), body, Vector3.ZERO, 14)
		b.add("sphere", Vector3(0, 0, 0.37), Vector3(0.28, 0.28, 0.16), body.darkened(0.1), Vector3.ZERO, 14)
		b.add("cyl", Vector3(0, 0, -0.18), Vector3(0.3, 0.035, 0.3), body.darkened(0.25), Vector3(90, 0, 0), 14)   # bant
		for k in 16:
			var a := k * 2.4
			var z := -0.3 + (k % 6) * 0.12
			var dv := Vector3(cos(a), sin(a), 0)
			var rot := Vector3(0, 0, rad_to_deg(a) - 90.0)
			b.add("cyl", dv * 0.15 + Vector3(0, 0, z), Vector3(0.06, 0.07, 0.06), body.lightened(0.05), rot, 8)
			b.add("cyl", dv * 0.19 + Vector3(0, 0, z), Vector3(0.035, 0.01, 0.035), Color(0.1, 0.08, 0.07), rot, 8)
		for k in 5:   # ön kapakta delikler
			var a := TAU * k / 5.0
			b.add("cyl", Vector3(cos(a) * 0.07, sin(a) * 0.07, -0.47), Vector3(0.03, 0.01, 0.03), Color(0.1, 0.08, 0.07), Vector3(90, 0, 0), 6)
		return b.build())
	var root := Node3D.new()
	var mi := _mi(mesh, _cel(Color.WHITE, 0.012, WOOD_INK, 0.4, 1.0, false, 0.7))
	root.add_child(mi)
	var fl := Node3D.new()
	root.add_child(fl)
	fl.position = Vector3(0, 0, 0.5)
	var fm := _cel(Color(1.0, 0.92, 0.45), 0.0, INK, 0.4, 1.0, true)
	var star := _mi(_slab(_star(9, 0.5, 0.16, 0.35), 0.01, Color.WHITE, _up_b()), fm)
	fl.add_child(star)
	var cm := _cel(Color(1.0, 0.98, 0.85), 0.0, INK, 0.4, 1.0, true)
	var core := _mi(_slab(_star(9, 0.26, 0.1, 0.3), 0.01, Color.WHITE, _up_b()), cm)
	fl.add_child(core)
	core.position = Vector3(0, 0, 0.01)
	for k in 2:
		var f := _mi(_m_card(1.4), _flame(Color(1.0, 0.75, 0.25, 0.95), Color(1.0, 0.97, 0.8), Color(0.75, 0.32, 0.05), 0.4, 1.0, 5.0))
		fl.add_child(f)
		f.position = Vector3(0, -0.1, 0.1 + k * 0.1)
		f.scale = Vector3.ONE * 0.35
	var tw := Game.safe_loops(fl.create_tween())
	tw.tween_property(fl, "scale", Vector3(1.2, 1.2, 1.0), 0.05)
	tw.tween_property(fl, "scale", Vector3(0.85, 0.85, 1.0), 0.05)
	return root


# ================================================================== 9. KUGUTSU: DOKU KEMURI — kukladan mor zehir bulutu
## Kukla ağzını açar, mor sis yay çizerek ileriye püskürür; düştüğü yerde yere yapışık, kenarları aşınan katmanlı mor
## sis yayılır (5 sn), içinden spor zerreleri yükselir, altında solmuş mor leke kalır.
static func sasori_doku_kemuri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d: Vector3 = pj.fwd(c, t)
	var at: Vector3 = pj.gp(c.global_position + d * 6.0)
	var pup := _puppet(pj, c, c.global_position + d * 1.8, d, 1.4)
	pj.after(0.3, func() -> void:
		if is_instance_valid(pup):
			_jolt(pup, 0.1)
			_venom_arc(pj, pup.global_position + Vector3.UP * 1.5 + d * 0.3, at + Vector3.UP * 0.6)
		pj.after(0.25, func() -> void: _venom_fog(pj, at, 4.5, 5.0))
		pj.every(5.0, 0.5, func(_i: int, _k: float) -> void:
			for e in pj.enemies_near(c, at, 4.5):
				if is_instance_valid(e) and not e.is_dead():
					e.take_hit(pj.inf(c, "sasori_doku_kemuri", 0.12, {"knock": 0.0, "kind": "light", "poison": 3.0}))))
	Sfx.play("poof", at, 0.6)


## Ağızdan hedef noktaya yay çizen mor sis topakları
static func _venom_arc(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5 + Vector3.UP * 2.0
	for k in 14:
		var m := _cel(Color(VENOM.r, VENOM.g, VENOM.b, 0.9), 0.03, VENOM_INK, 2.5, 5.0, false, 0.75)
		var bl := _mi(_m_ball(10), m)
		_put(pj, bl, a)
		bl.scale = Vector3.ONE * 0.25
		var s := randf_range(0.5, 0.9)
		var tw := bl.create_tween()
		tw.tween_interval(k * 0.025)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(bl):
				bl.global_position = a.lerp(mid, u).lerp(mid.lerp(b, u), u)
				bl.scale = Vector3.ONE * lerpf(0.25, s, u), 0.0, 1.0, 0.32).set_ease(Tween.EASE_IN)
		tw.tween_callback(bl.queue_free)


## Katmanlı yer sisi + kenarda yuvarlanan alçak tümsekler + yükselen sporlar + solmuş leke
static func _venom_fog(pj: PathJutsu, at: Vector3, R: float, dur: float) -> void:
	var root := Node3D.new()
	_put(pj, root, at)
	var mats: Array = []
	for k in 3:
		var m := _smat("fog", FOG_SH, 6.0, 9.0)
		m.set_shader_parameter("base_c", Color(VENOM.r, VENOM.g, VENOM.b, 0.78 - k * 0.12))
		m.set_shader_parameter("hi_c", Color(0.72, 0.55, 0.82))
		m.set_shader_parameter("line_c", VENOM_INK)
		m.set_shader_parameter("seed", randf() * 30.0)
		m.set_shader_parameter("flow", 0.12 + k * 0.05)
		mats.append(m)
		var ly := _mi(_m_disc(), m)
		root.add_child(ly)
		ly.position = Vector3.UP * (0.15 + k * 0.55)
		ly.scale = Vector3.ONE * R * (1.1 - k * 0.15)
		var rt := Game.safe_loops(ly.create_tween())
		rt.tween_property(ly, "rotation:y", TAU * (1.0 if k % 2 == 0 else -1.0), 14.0 + k * 3.0).from(0.0)
	root.scale = Vector3(0.12, 1.0, 0.12)
	var gt := root.create_tween()
	gt.tween_property(root, "scale", Vector3.ONE, 0.6).set_ease(Tween.EASE_OUT)
	var bank: Array = []
	for k in 9:   # kenarda alçak kabarık sis tümsekleri
		var a := TAU * k / 9.0 + randf_range(-0.2, 0.2)
		var m := _cel(Color(0.78, 0.66, 0.86, 0.85), 0.03, VENOM_INK, 6.0, 9.0, false, 0.78)
		var mo := _mi(_m_mound("venom", Color(0.8, 0.68, 0.88), VENOM, false, k % 3), m)
		root.add_child(mo)
		mo.position = Vector3(cos(a), 0, sin(a)) * R * 0.82
		mo.scale = Vector3(1.0, 0.45, 1.0) * randf_range(0.7, 1.0)
		var bt := Game.safe_loops(mo.create_tween())
		bt.tween_property(mo, "position", mo.position + Vector3(0, 0.12, 0) - mo.position.normalized() * 0.3, 1.2).set_trans(Tween.TRANS_SINE)
		bt.tween_property(mo, "position", mo.position, 1.2).set_trans(Tween.TRANS_SINE)
		bank.append([mo, m])
	var sp := _burst(pj, at + Vector3.UP * 0.4, _m_ball(6), _cel(Color(0.85, 0.75, 0.95), 0.0, INK, 1.0, 3.0), 40, 1.6,
		{"r": R * 0.8, "dir": Vector3.UP, "spread": 20.0, "vmin": 0.3, "vmax": 0.9, "g": Vector3(0, 0.3, 0), "smin": 0.05, "smax": 0.1,
		"expl": 0.0, "one": false, "keep": true})
	var lm := _cel(Color(0.3, 0.16, 0.34, 0.75), 0.0, INK, 1.5, 4.0, true, 1.0)
	var stain := _mi(_slab(_blob(R * 0.8, 24, 0.3), 0.02, Color.WHITE, _flat_b()), lm)
	_put(pj, stain, at + Vector3.UP * 0.03)
	_fade(stain, lm, dur + 1.5, 2.0)
	pj.free_after(dur + 4.0, stain)
	var tw := root.create_tween()
	tw.tween_interval(dur - 0.6)
	tw.tween_callback(func() -> void: _stop(sp))
	tw.tween_method(func(v: float) -> void:
		for m in mats:
			_sp(m, "density", -0.7 * (1.0 - v))
			_sp(m, "fade", v)
		for bk in bank:
			_sp(bk[1], "fade", v), 1.0, 0.0, 1.2)
	tw.tween_callback(root.queue_free)
	pj.free_after(dur + 2.0, root)
	pj.free_after(dur + 3.0, sp)


# ================================================================== 10. KUGUTSU: SANDAIME KAZEKAGE
## Yerde kara mürekkepli çağırma parşömeni açılır, halka yazısı mavi chakra ile parlar; Üçüncü Kazekage kuklası
## (gerçek EdoWarrior savaşçısı) parşömenden yükselir, iplerle bağlanır; çevresinde demir kum taneleri sarmal döner.
static func kugutsu_sandaime(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d: Vector3 = pj.fwd(c, t)
	_summon_scroll(pj, c.global_position + d * 2.0, d, 2.5)
	pj.after(0.4, func() -> void:
		if pj.live(c):
			var w := _kazekage(pj, c, c.global_position + d * 2.2, "Üçüncü Kazekage", 25.0, 1.8)
			var ring := _iron_sand(w)
			pj.every(25.0, 0.4, func(_i: int, _k: float) -> void:
				if is_instance_valid(ring) and (not is_instance_valid(w) or w.dead):
					ring.visible = false))
	Sfx.play("poof", c.global_position, 0.8)


## Kukla savaşçısı: ana ağaçtaki _puppet_fighter ile aynı mekanik (EdoWarrior, güç, süre); görünüş bu dosyanın
static func _kazekage(pj: PathJutsu, c: Node3D, at: Vector3, nm: String, dur: float, pow_k: float) -> EdoWarrior:
	var w := EdoWarrior.new()
	w.team = c.team
	w.owner_f = c
	var lk = EdoWarrior.edo_look(nm.length())
	lk.merge({"skin": Color(0.72, 0.58, 0.42), "eye": Color(0.1, 0.08, 0.06), "top": Color(0.16, 0.14, 0.15), "band_style": ""}, true)
	w.look = lk
	w.life = dur
	w.power = (Stats.jutsu_mult(Game.profile) if c is Player else 1.0) * pow_k
	pj.get_tree().current_scene.add_child(w)
	w.global_position = pj.gp(at)
	_splinters(pj, w.global_position + Vector3.UP, 1.2)
	_strings(pj, c, w, dur, [Vector3(0.2, 1.5, 0), Vector3(-0.2, 1.5, 0), Vector3(0.35, 1.1, 0), Vector3(-0.35, 1.1, 0)])
	Combat.popup_text(w.global_position + Vector3.UP * 2.8, nm, Color(0.85, 0.72, 0.55))
	return w


## Yerde açılan çağırma parşömeni: kâğıt şerit + iki sap, ortada mürekkep halka yazısı, chakra çizgisiyle parlar
static func _summon_scroll(pj: PathJutsu, pos: Vector3, d: Vector3, r: float) -> void:
	var g: Vector3 = pj.gp(pos)
	var root := Node3D.new()
	_put(pj, root, g + Vector3.UP * 0.03)
	root.rotation.y = atan2(d.x, d.z)
	var pm := _cel(PAPER, 0.015, Color(0.35, 0.3, 0.22), 1.0, 2.5, true, 0.9)
	var b := MB.new()
	b.add("box", Vector3.ZERO, Vector3(r * 2.2, 0.02, 1.1), Color.WHITE)
	for sx in [-1.0, 1.0]:
		b.add("cyl", Vector3(sx * r * 1.12, 0.06, 0), Vector3(0.14, 1.25, 0.14), Color(0.5, 0.28, 0.16), Vector3(90, 0, 0), 10)
	var paper := _mi(b.build(), pm)
	root.add_child(paper)
	paper.scale = Vector3(0.05, 1, 1)
	paper.create_tween().tween_property(paper, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	var ib := MB.new()
	ib.add_slab(MB.hole(_star(36, r * 0.72, r * 0.66), Vector2.ZERO, r * 0.6, 36), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	for k in 12:   # halka yazısı: kısa fırça işaretleri
		var a := TAU * k / 12.0
		var p := Vector3(cos(a), 0, sin(a)) * r * 0.5
		ib.add_xf("box", Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(0.06, 0.01, 0.3)), p), Color.WHITE)
		ib.add_xf("box", Transform3D(Basis(Vector3.UP, -a + 0.8) * Basis.from_scale(Vector3(0.05, 0.01, 0.18)), p + Vector3(cos(a), 0, sin(a)) * 0.12), Color.WHITE)
	ib.add_slab(_blob(0.35, 12, 0.2), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	var im := _cel(SUMI, 0.0, INK, 1.0, 2.5, true, 1.0)
	var ink := _mi(ib.build(), im)
	root.add_child(ink)
	ink.position = Vector3(0, 0.02, 0)
	ink.scale = Vector3(0.55, 1.0, 0.55) * 0.01
	var tw := ink.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(ink, "scale", Vector3(0.55, 1.0, 0.55), 0.2).set_ease(Tween.EASE_OUT)
	var gm := _streak(Color(0.75, 0.9, 1.0, 0.9), STRING_C, 1.0, 2.5)
	var glow_ring := _mi(_arc_band(r * 0.4, 0.12, 0.0, TAU, 48), gm)
	root.add_child(glow_ring)
	glow_ring.position = Vector3(0, 0.05, 0)
	var gt := glow_ring.create_tween()
	gt.tween_property(glow_ring, "rotation:y", TAU, 0.8)
	_fade(glow_ring, gm, 0.4, 0.4)
	_fade(root, pm, 1.4, 0.5)
	var t2 := ink.create_tween()
	t2.tween_interval(1.4)
	t2.tween_method(func(v: float) -> void: _sp(im, "fade", v), 1.0, 0.0, 0.5)


## Demir kum: kuklanın çevresinde iki eğik sarmal bantta dönen kara metalik taneler (kuklanın çocuğu)
static func _iron_sand(w: Node3D) -> Node3D:
	var ring := Node3D.new()
	if w == null or not is_instance_valid(w):
		return ring
	w.add_child(ring)
	ring.position = Vector3(0, 1.0, 0)
	var mesh := _cached("mesh:iron_sand", func() -> Mesh:
		var b := MB.new()
		for k in 70:
			var band := k % 2
			var a := TAU * k / 35.0 + randf_range(-0.1, 0.1)
			var r := 0.95 + randf_range(-0.12, 0.18)
			var y := sin(a * 2.0 + band * PI) * 0.45 + randf_range(-0.08, 0.08)
			var s := randf_range(0.04, 0.09)
			b.add("box", Vector3(cos(a) * r, y, sin(a) * r), Vector3(s, s * 0.7, s * 1.3), Color(0.12, 0.12, 0.15) if k % 5 else Color(0.45, 0.45, 0.5),
				Vector3(randf() * 90, randf() * 90, 0))
		return b.build())
	var mi := _mi(mesh, _cel(Color.WHITE, 0.0, INK, 0.6, 1.4, false, 0.6, 0.5))
	ring.add_child(mi)
	var mi2 := _mi(mesh, _cel(Color.WHITE, 0.0, INK, 0.6, 1.4, false, 0.6, 0.5))
	ring.add_child(mi2)
	mi2.rotation = Vector3(0.5, 1.3, 0.2)
	mi2.scale = Vector3.ONE * 0.8
	var tw := Game.safe_loops(ring.create_tween())
	tw.tween_property(ring, "rotation:y", TAU, 1.6).from(0.0)
	var t2 := Game.safe_loops(mi2.create_tween())
	t2.tween_property(mi2, "rotation:y", 1.3 - TAU, 1.1).from(1.3)
	return ring


# ================================================================== 11. SENJU SŌBU — kukladan yüzlerce kol
## Koyu kukla göğsünü açar: gövdesinden yelpaze halinde eklemli tahta kollar açılır; yüzlercesi iplerle hedefe fırlar,
## tutan el hedefi bağlar.
static func senju_sobu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt: Node3D = pj.tg(c, t, 20.0)
	pj.busy(c, 1.4)
	var d: Vector3 = pj.fwd(c, t)
	var pup := _puppet(pj, c, c.global_position + d * 2.2, d, 2.2, 1.2, true)
	var am := _cel(Color.WHITE, 0.012, WOOD_INK, 0.4, 1.0, false, 0.7)
	pj.after(0.4, func() -> void:
		if not (pj.live(c) and is_instance_valid(pup)):
			return
		_arm_fan(pup, am)
		_jolt(pup, 0.12)
		var o: Vector3 = pup.global_position + Vector3.UP * 1.3
		var lm := _line_mat(STRING_C)
		for k in 28:
			var dir: Vector3 = (pj.aim_at(c, tt, o) + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.5), randf_range(-0.5, 0.5))).normalized()
			var arm := _mi(_m_wood_arm(), am)
			var pr: Projectile = pj.shot(c, o, dir, 28.0, arm, pj.inf(c, "senju_sobu", 0.12, {"knock": 2.0, "kind": "light"}), tt if k % 3 == 0 else null, false, 0.7, func(_pp: Vector3, h) -> void:
				if h and pj.live(h):
					pj.st(h, "bind", 1.5))
			if pr:
				_link(pj, o, pr, 0.7, lm))
	Sfx.play("whoosh", c.global_position, 0.8)


## Eklemli tahta kol (ileri -Z): üst kol, dirsek topu, ön kol, açık el (avuç + 4 parmak + başparmak)
static func _m_wood_arm() -> Mesh:
	return _cached("mesh:wood_arm", func() -> Mesh:
		var b := MB.new()
		b.add("cyl", Vector3(0, 0, 0.35), Vector3(0.11, 0.6, 0.11), WOOD, Vector3(90, 0, 0), 7)
		b.add("sphere", Vector3(0, 0, 0.02), Vector3(0.14, 0.14, 0.14), WOOD_D, Vector3.ZERO, 8)
		b.add("cyl", Vector3(0, 0, -0.3), Vector3(0.09, 0.6, 0.09), WOOD, Vector3(90, 0, 0), 7)
		b.add("cyl", Vector3(0, 0, -0.04), Vector3(0.12, 0.02, 0.12), WOOD_D, Vector3(90, 0, 0), 7)
		b.add("box", Vector3(0, 0, -0.68), Vector3(0.18, 0.05, 0.18), WOOD.lightened(0.08))
		for k in 4:
			b.add("box", Vector3(-0.065 + k * 0.043, 0, -0.84), Vector3(0.032, 0.035, 0.16), WOOD.lightened(0.08), Vector3(-15, 0, 0))
		b.add("box", Vector3(0.11, 0, -0.7), Vector3(0.03, 0.035, 0.12), WOOD.lightened(0.08), Vector3(0, -40, 0))
		return b.build())


## Kuklanın gövdesinden yelpaze halinde açılan dekor kolları (kuklanın çocuğu; kukla katlanınca gider)
static func _arm_fan(pup: Node3D, m: Material) -> void:
	var fan := Node3D.new()
	pup.add_child(fan)
	fan.position = Vector3(0, 1.3, 0.1)
	for k in 12:
		var a := lerpf(-PI * 0.9, PI * 0.9, k / 11.0)
		var dv := Vector3(sin(a), cos(a), randf_range(0.25, 0.55)).normalized()   # göğüs çevresinde ışınsal, hafif önde
		var arm := _mi(_m_wood_arm(), m)
		fan.add_child(arm)
		arm.transform = Transform3D(Basis.looking_at(dv, Vector3(0, 0, 1)), dv * 0.7)
		arm.scale = Vector3.ONE * 0.01
		var tw := arm.create_tween()
		tw.tween_property(arm, "scale", Vector3.ONE * randf_range(0.8, 1.1), 0.18).set_delay(k * 0.015).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## o noktasından mermiye uzanan chakra ipi (dur sn)
static func _link(pj: PathJutsu, o: Vector3, pr: Node3D, dur: float, m: Material) -> void:
	var li := _mi(_m_line(), m)
	_put(pj, li, o)
	var pw = weakref(pr)
	pj.every(dur, 1.0 / 30.0, func(_i: int, _k: float) -> void:
		if not is_instance_valid(li):
			return
		var p = pw.get_ref()
		if p == null or not is_instance_valid(p):
			li.visible = false
			return
		li.global_transform = _seg_xf(o, (p as Node3D).global_position, 0.02), func() -> void:
		if is_instance_valid(li):
			li.queue_free())
	pj.free_after(dur + 0.5, li)


# ================================================================== 12. KUROHIGI: SANSHŌUO — semender kalkan kukla
## Yassı, kalın derili semender kukla (yuvarlak gözler, geniş ağız, kısa bacaklar) önde belirir; sırtındaki plaka kabuk
## menteşeden kalkıp önünde dik bir kalkan duvarı olur; 8 sn sonra kapanır, kukla yere çöküp kaybolur.
static func kurohigi_sanshouo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d: Vector3 = pj.fwd(c, t)
	var sh := _sanshouo()
	pj.scene_add(sh, pj.gp(c.global_position + d * 1.6))
	sh.look_at(sh.global_position + d, Vector3.UP)
	_splinters(pj, sh.global_position + Vector3.UP, 1.3)
	_strings(pj, c, sh, 8.0, [Vector3(0.4, 1.4, 0.3), Vector3(-0.4, 1.4, 0.3)])
	sh.scale = Vector3(1.0, 0.05, 1.0)
	var tw := sh.create_tween()
	tw.tween_property(sh, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shell: Node3D = sh.get_meta("shell")
	tw.tween_property(shell, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(sh):
			_chips(pj, sh.global_position + Vector3.UP * 0.2 - sh.global_transform.basis.z * 0.9, DUST_D, 8, 4.0))
	if c is Player:
		Buffs.add("sanshouo", 8.0, {"armor": 0.25, "_name": "Semender Kalkanı", "_desc": "önündeki kukla darbeleri karşılar"})
	pj.after(8.0, func() -> void:
		if is_instance_valid(sh):
			_splinters(pj, sh.global_position + Vector3.UP, 1.0)
			var t2 := sh.create_tween()
			if is_instance_valid(shell):
				t2.tween_property(shell, "rotation:x", deg_to_rad(80.0), 0.2)
			t2.tween_property(sh, "scale", Vector3(1.0, 0.05, 1.0), 0.18).set_ease(Tween.EASE_IN)
			t2.tween_callback(sh.queue_free))
	pj.free_after(9.0, sh)
	Sfx.play("earth", c.global_position, 1.0)


## Semender kukla (ileri -Z). meta "shell": menteşeli kalkan (rotation.x = 80° sırtta yatık, 0 = dik duvar)
static func _sanshouo() -> Node3D:
	var body_mesh := _cached("mesh:sansh_body", func() -> Mesh:
		var b := MB.new()
		var skin := Color(0.45, 0.39, 0.33)
		var belly := Color(0.66, 0.58, 0.46)
		b.add_grad("sphere", Vector3(0, 0.62, 0.2), Vector3(1.9, 0.95, 2.1), skin.lightened(0.08), skin.darkened(0.15), Vector3.ZERO, 16)
		b.add("sphere", Vector3(0, 0.38, 0.2), Vector3(1.6, 0.4, 1.8), belly, Vector3.ZERO, 14)
		b.add_grad("sphere", Vector3(0, 0.75, -0.95), Vector3(1.15, 0.62, 0.85), skin.lightened(0.08), skin.darkened(0.15), Vector3.ZERO, 14)   # baş
		b.add("box", Vector3(0, 0.6, -1.33), Vector3(0.9, 0.04, 0.1), Color(0.14, 0.1, 0.08), Vector3(0, 0, 0))   # geniş ağız
		for sx in [-1.0, 1.0]:
			b.add("sphere", Vector3(sx * 0.3, 1.05, -1.0), Vector3(0.3, 0.3, 0.3), Color(0.95, 0.93, 0.85), Vector3.ZERO, 10)   # göz
			b.add("sphere", Vector3(sx * 0.3, 1.07, -1.13), Vector3(0.13, 0.15, 0.08), Color(0.08, 0.06, 0.05), Vector3.ZERO, 8)
			for fz in [-0.45, 0.85]:   # kısa kalın bacaklar + parmaklar
				b.add("cyl", Vector3(sx * 0.95, 0.28, fz), Vector3(0.3, 0.55, 0.3), skin.darkened(0.1), Vector3(0, 0, sx * 25), 8)
				for k in 3:
					b.add("sphere", Vector3(sx * (1.1 + k * 0.05), 0.06, fz - 0.15 + k * 0.15), Vector3(0.12, 0.08, 0.16), skin.darkened(0.2), Vector3.ZERO, 6)
		for k in 4:   # kuyruk
			var f := k / 3.0
			b.add("sphere", Vector3(0, 0.5 - f * 0.25, 1.25 + k * 0.32), Vector3(0.55 - f * 0.35, 0.4 - f * 0.25, 0.5), skin.darkened(0.1), Vector3.ZERO, 8)
		return b.build())
	var shell_mesh := _cached("mesh:sansh_shell", func() -> Mesh:
		var b := MB.new()
		var plate := Color(0.5, 0.36, 0.26)
		var rim := Color(0.3, 0.2, 0.13)
		for row in 3:   # dik duvar: 3 sıra üst üste binen yuvarlak plaka (yerel -Z'ye bakar)
			var n := 4 - (row % 2)
			for k in n:
				var x := (k - (n - 1) * 0.5) * 0.62
				var y := 0.35 + row * 0.55
				b.add_grad("sphere", Vector3(x, y, -0.04 * row), Vector3(0.72, 0.66, 0.22), plate.lightened(0.1), plate.darkened(0.12), Vector3.ZERO, 12)
				b.add("cyl", Vector3(x, y, -0.13 - 0.04 * row), Vector3(0.62, 0.02, 0.62), rim, Vector3(90, 0, 0), 12)
				b.add("sphere", Vector3(x, y, -0.15 - 0.04 * row), Vector3(0.1, 0.1, 0.06), Color(0.72, 0.62, 0.42), Vector3.ZERO, 6)   # perçin
		b.add("box", Vector3(0, 0.02, 0), Vector3(2.3, 0.1, 0.3), rim)   # menteşe kirişi
		return b.build())
	var root := Node3D.new()
	var bm := _cel(Color.WHITE, 0.03, WOOD_INK, 2.0, 4.0, false, 0.72)
	root.add_child(_mi(body_mesh, bm))
	var shell := Node3D.new()
	root.add_child(shell)
	shell.position = Vector3(0, 0.95, -0.35)
	shell.rotation.x = deg_to_rad(80.0)
	var sm := _cel(Color.WHITE, 0.03, WOOD_INK, 2.0, 4.0, false, 0.7)
	shell.add_child(_mi(shell_mesh, sm))
	root.set_meta("shell", shell)
	return root


# ================================================================== 13. KUROHIGI: KIKI SANPATSU — üç kukla yutar
## Üç ayrı kukla (Karasu: üç gözlü gagalı yüz; Kuroari: anten + yuvarlak göz lekeleri; Sanshōuo: plaka sırt) birer
## kabuk dilimi gibi açık çeneyle üç yandan kapanır ve hedefi tek bir kapsülde yutar; içeriden bıçaklar kabuğu delip
## dışarı fırlar, kan damlar; sonra dilimler dağılıp yere düşer.
static func kurohigi_kiki_sanpatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt: Node3D = pj.tg(c, t, 18.0)
	pj.busy(c, 1.3)
	if tt == null:
		return
	var at: Vector3 = pj.gp(tt.global_position)
	for k in 3:
		var a := k * TAU / 3.0
		var cm := _kiki_shell(k)
		var from := at + Vector3(cos(a), 0, sin(a)) * 6.0
		pj.scene_add(cm, from)
		cm.look_at(at, Vector3.UP)
		_strings(pj, c, cm, 1.4, [Vector3(0.0, 1.9, 0.2), Vector3(0.0, 1.9, 0.2)])
		var tw := cm.create_tween()
		tw.tween_property(cm, "global_position", at + Vector3(cos(a), 0, sin(a)) * 0.6, 0.35).set_delay(0.2 + k * 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if k == 2:
			tw.tween_callback(func() -> void:
				_chips(pj, at + Vector3.UP * 0.3, WOOD_D, 10, 5.0)
				pj.shake(0.3))
		tw.tween_interval(0.8)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(cm):
				return
			_splinters(pj, cm.global_position + Vector3.UP, 0.8)
			var out := Vector3(cos(a), 0, sin(a))
			var t2 := cm.create_tween()
			t2.tween_property(cm, "global_position", cm.global_position + out * 1.0 + Vector3.DOWN * 0.3, 0.25).set_ease(Tween.EASE_OUT)
			t2.parallel().tween_property(cm, "rotation:x", cm.rotation.x - 0.9, 0.25)
			t2.parallel().tween_property(cm, "scale", Vector3.ONE * 0.6, 0.25)
			t2.tween_callback(cm.queue_free))
		pj.free_after(2.2, cm)
	pj.after(0.7, func() -> void:
		if pj.live(tt):
			pj.st(tt, "bind", 1.2)
			for k in 3:
				pj.after(k * 0.15, func() -> void:
					if pj.live(tt):
						_kiki_blades(pj, at, k)
						_burst(pj, tt.global_position + Vector3.UP, _m_drop(), _cel(BLOOD, 0.008, Color(0.25, 0.0, 0.0), 0.5, 1.2), 8, 0.6,
							{"r": 0.5, "vmin": 2.0, "vmax": 4.5, "g": Vector3(0, -14, 0), "align": true, "smin": 0.5, "smax": 0.9})
						tt.take_hit(pj.inf(c, "kurohigi_kiki_sanpatsu", 0.8, {"knock": 0.0, "kind": "heavy", "bleed": 3.0}))))
	Sfx.play("blade", at, 0.8)


## Kabuk dilimi: kapalıyken birleşik kapsülün 1/3'ü (merkez yerel (0, ry, -0.6)); kenarları koyu cel çizgisi
static func _kiki_shell(k: int) -> Node3D:
	var cols := [Color(0.3, 0.31, 0.37), Color(0.2, 0.17, 0.15), Color(0.5, 0.38, 0.28)]
	var col: Color = cols[k]
	var wedge := _cached("mesh:kiki_wedge%d" % k, func() -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rx := 0.78
		var ry := 1.1
		var ctr := Vector3(0, ry + 0.02, -0.6)
		var NA := 12
		var NT := 18
		var half := deg_to_rad(62.0)
		for i in NT + 1:
			var th := PI * i / NT
			for j in NA + 1:
				var ph := lerpf(-half, half, float(j) / NA)
				var p := Vector3(rx * sin(th) * sin(ph), ry * cos(th), rx * sin(th) * cos(ph))
				var n := Vector3(p.x / (rx * rx), p.y / (ry * ry), p.z / (rx * rx)).normalized()
				var edge := j == 0 or j == NA or i == 9 or i == 13 or i == 5
				st.set_color(Color(0.12, 0.09, 0.07) if edge else col)
				st.set_normal(n)
				st.add_vertex(ctr + p)
		for i in NT:
			for j in NA:
				var a := i * (NA + 1) + j
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(a + NA + 1)
				st.add_index(a + 1)
				st.add_index(a + NA + 2)
				st.add_index(a + NA + 1)
		return st.commit())
	var det := _cached("mesh:kiki_det%d" % k, func() -> Mesh:
		var b := MB.new()
		var o := Vector3(0, 1.45, 0.12)   # dış yüzeyin üst kısmı
		match k:
			0:   # Karasu: koyu maske, üç sarı göz, gaga
				b.add("sphere", o, Vector3(0.5, 0.4, 0.14), Color(0.22, 0.22, 0.26), Vector3.ZERO, 10)
				for e in [Vector3(-0.11, 0.05, 0.07), Vector3(0.11, 0.05, 0.07), Vector3(0, 0.15, 0.07)]:
					b.add("sphere", o + e, Vector3(0.07, 0.05, 0.03), Color(1.0, 0.85, 0.2), Vector3.ZERO, 6)
				b.add("cone", o + Vector3(0, -0.08, 0.14), Vector3(0.1, 0.25, 0.1), Color(0.5, 0.42, 0.3), Vector3(90, 0, 0), 5)
			1:   # Kuroari: iki anten + yuvarlak göz lekeleri + menteşe kapak çizgisi
				for sx in [-1.0, 1.0]:
					b.add("cone", o + Vector3(sx * 0.15, 0.32, -0.05), Vector3(0.05, 0.5, 0.05), Color(0.12, 0.1, 0.09), Vector3(-20, 0, sx * -25), 4)
					b.add("sphere", o + Vector3(sx * 0.17, 0.0, 0.05), Vector3(0.16, 0.16, 0.06), Color(0.85, 0.82, 0.75), Vector3.ZERO, 8)
					b.add("sphere", o + Vector3(sx * 0.17, 0.0, 0.08), Vector3(0.07, 0.07, 0.03), Color(0.05, 0.05, 0.05), Vector3.ZERO, 6)
			_:   # Sanshōuo: sırt plakaları
				for r in 3:
					b.add_grad("sphere", o + Vector3(0, 0.25 - r * 0.42, 0.02), Vector3(0.5, 0.38, 0.12), Color(0.62, 0.46, 0.32), Color(0.42, 0.3, 0.2), Vector3.ZERO, 10)
		return b.build())
	var root := Node3D.new()
	root.add_child(_mi(wedge, _cel(Color.WHITE, 0.0, INK, 1.0, 2.5, true, 0.68)))
	root.add_child(_mi(det, _cel(Color.WHITE, 0.012, INK, 1.0, 2.5, false, 0.72)))
	return root


## Kapsülün içinden dışarı fırlayan bıçaklar (hit başına 3)
static func _kiki_blades(pj: PathJutsu, at: Vector3, k: int) -> void:
	var mesh := _cached("mesh:kiki_blade", func() -> Mesh:
		var b := MB.new()
		b.add_slab(PackedVector2Array([Vector2(0.0, -0.08), Vector2(0.9, -0.05), Vector2(1.2, 0.0), Vector2(0.9, 0.06), Vector2(0.0, 0.08)]), 0.025, Color.WHITE,
			Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3.ZERO))
		return b.build())
	var m := _cel(STEEL, 0.01, STEEL_INK, 0.5, 1.2, true, 0.6, 0.7)
	for j in 3:
		var a := TAU * (j / 3.0) + k * 0.7 + randf_range(-0.3, 0.3)
		var dv := Vector3(cos(a), randf_range(-0.3, 0.5), sin(a)).normalized()
		var p := at + Vector3.UP * randf_range(0.7, 1.6) + dv * 0.4
		var bl := _mi(mesh, m)
		_put(pj, bl, p)
		_look(bl, p + dv)
		bl.scale = Vector3(1, 1, 0.05)
		var tw := bl.create_tween()
		tw.tween_property(bl, "scale", Vector3.ONE, 0.06).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5 - k * 0.12)
		tw.tween_property(bl, "scale", Vector3(1, 1, 0.05), 0.1)
		tw.tween_callback(bl.queue_free)
		_glint(pj, p + dv * 1.1, dv, 0.5)


# ================================================================== 14. DOKUGIRI JIGOKU: BARIBARI HYAKU RENPATSU
## ref: ekranı dolduran mor sis içinde koyu, yırtık yarasa kanadı biçimli sis lekeleri; merkezden dışa uçan uzun koyu
## iğneler ve beyaz hız çizgileri. Kukla ağzından mor sis püskürür, ardından iğne yağmuru sisin içinden fırlar.
static func dokugiri_jigoku_baribari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt: Node3D = pj.tg(c, t, 20.0)
	pj.busy(c, 1.4)
	var d: Vector3 = pj.fwd(c, t)
	var pup := _puppet(pj, c, c.global_position + d * 2.0 + Vector3.UP * 2.0, d, 2.0)
	pj.after(0.3, func() -> void:
		if is_instance_valid(pup):
			_jolt(pup, 0.1)
			_mist_jet(pj, pup.global_position + Vector3.UP * 1.6 + d, d))
	var nm := _m_senbon(true)
	var mat := _cel(Color(0.4, 0.4, 0.45), 0.008, INK, 0.4, 1.0, false, 0.6, 0.8)
	var trail := _streak(Color(1, 1, 1, 0.95), Color(0.6, 0.5, 0.75), 0.4, 1.0)
	for k in 20:
		pj.after(0.6 + k * 0.04, func() -> void:
			if not (pj.live(c) and is_instance_valid(pup)):
				return
			var o: Vector3 = pup.global_position + Vector3.UP * 1.6
			var dir: Vector3 = pj.aim_at(c, tt, o).rotated(Vector3.UP, randf_range(-0.25, 0.25))
			var nd := _mi(nm, mat)
			var tr := _mi(_m_streak(), trail)
			nd.add_child(tr)
			tr.scale = Vector3(0.08, 0.08, 2.2)
			pj.shot(c, o, dir, 38.0, nd, pj.inf(c, "dokugiri_jigoku_baribari", 0.1, {"knock": 0.5, "kind": "light", "poison": 2.0}), null, false, 0.8))
	Sfx.play("throw_kunai", c.global_position, 1.5)


## Yırtık yarasa kanadı biçimli sis lekesi profili (ref)
static func _m_wisp(v: int) -> Mesh:
	return _cached("mesh:wisp%d" % v, func() -> Mesh:
		var o := PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 4111 + v * 37
		var n := 9
		for i in n + 1:   # üst kenar: tümsekler
			var u := float(i) / n
			o.append(Vector2(lerpf(-0.9, 0.9, u), 0.25 + sin(u * PI) * 0.25 + (0.12 if i % 2 == 0 else 0.0) * rng.randf_range(0.5, 1.2)))
		for i in range(n, -1, -1):   # alt kenar: sivri yırtık uçlar
			var u := float(i) / n
			o.append(Vector2(lerpf(-0.9, 0.9, u), (-0.35 - rng.randf_range(0.1, 0.35)) if i % 2 == 1 else -0.08))
		var b := MB.new()
		b.add_slab(o, 0.04, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO))
		return b.build())


## Mor sis püskürmesi: açık mor kabarık sis topakları (gövde) + koyu yırtık sis lekeleri, ileri doğru yayılır
static func _mist_jet(pj: PathJutsu, o: Vector3, d: Vector3) -> void:
	_burst(pj, o, _m_ball(10), _cel(Color(0.62, 0.46, 0.72, 0.8), 0.03, VENOM_INK, 6.0, 9.0, false, 0.8), 26, 2.0,
		{"r": 0.6, "dir": d, "spread": 32.0, "vmin": 3.0, "vmax": 6.5, "damp": 2.2, "g": Vector3(0, 0.2, 0), "smin": 1.0, "smax": 2.0,
		"expl": 0.35, "start_scale": 0.4, "end_scale": 1.8, "hold": 0.55, "spin": 30.0})
	for v in 2:
		_burst(pj, o, _m_wisp(v), _cel(VENOM_D, 0.0, INK, 6.0, 9.0, true, 0.9), 12, 1.8,
			{"r": 0.6, "dir": d, "spread": 40.0, "vmin": 3.5, "vmax": 7.5, "damp": 2.0, "g": Vector3(0, 0.3, 0), "smin": 0.9, "smax": 1.8,
			"expl": 0.4, "start_scale": 0.3, "end_scale": 1.6, "hold": 0.5, "spin": 60.0})
	_glint(pj, o, d, 1.0, Color(0.9, 0.8, 1.0), VENOM_INK)


# ================================================================== 15. HEBI SAISETSUGŌ — yılan dikişi
## Bedenin çevresinden ince soluk yılanlar fışkırıp kıvrılarak gövdeye dalar; giriş yerlerinde koyu dikiş izleri
## belirir ve yavaşça kapanır, dökülen pullar yere süzülür.
static func hebi_saisetsugo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.0)
	for k in 8:
		var a := k * TAU / 8.0
		var from := c.global_position + Vector3(cos(a) * 1.2, 0.3 + (k % 3) * 0.5, sin(a) * 1.2)
		pj.after(k * 0.05, func() -> void:
			if pj.live(c):
				_stitch_snake(pj, from, c.global_position + Vector3.UP * 1.0, 0.45, 0.4))
	pj.after(0.6, func() -> void:
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.4)
			_sutures(c)
			_burst(pj, c.global_position + Vector3.UP * 1.1, _slab(PackedVector2Array([Vector2(0, 0.06), Vector2(0.04, 0), Vector2(0, -0.06), Vector2(-0.04, 0)]), 0.01, Color.WHITE, _up_b()),
				_cel(Color(0.78, 0.74, 0.88), 0.006, VENOM_INK, 0.5, 1.2, true), 26, 1.4,
				{"r": 0.5, "vmin": 0.5, "vmax": 1.5, "g": Vector3(0, -1.5, 0), "damp": 1.0, "spin": 300.0, "smin": 0.7, "smax": 1.2}))
	Sfx.play("genjutsu", c.global_position, 0.7)


## İnce yılan: baş + 6 boğum; baş a'dan b'ye sinüs sapmalı yolla kıvrılır (dur), boğumlar başın izini sürer, sonra silinir
static func _stitch_snake(pj: PathJutsu, a: Vector3, b: Vector3, dur: float, wiggle: float) -> void:
	var head_mesh := _cached("mesh:stitch_head", func() -> Mesh:
		var mb := MB.new()
		mb.add_grad("sphere", Vector3.ZERO, Vector3(0.16, 0.12, 0.26), SNAKE.lightened(0.15), SNAKE.darkened(0.2), Vector3.ZERO, 10)
		mb.add("sphere", Vector3(0, -0.035, -0.08), Vector3(0.12, 0.05, 0.16), SNAKE_BELLY, Vector3(15, 0, 0), 8)
		for sx in [-1.0, 1.0]:
			mb.add("sphere", Vector3(sx * 0.055, 0.04, -0.06), Vector3(0.035, 0.03, 0.04), Color(1.0, 0.85, 0.15), Vector3.ZERO, 6)
		mb.add("cone", Vector3(0, -0.02, -0.18), Vector3(0.012, 0.1, 0.012), Color(0.75, 0.15, 0.2), Vector3(-90, 0, 0), 3)   # dil
		return mb.build())
	var m := _cel(Color.WHITE, 0.012, VENOM_INK, 0.4, 1.0, false, 0.72)
	var head := _mi(head_mesh, m)
	_put(pj, head, a)
	var segs: Array = []
	for i in 6:
		var sg := _mi(_m_ball(8), _cel(SNAKE, 0.012, VENOM_INK, 0.4, 1.0, false, 0.72))
		_put(pj, sg, a)
		var s := lerpf(0.11, 0.05, i / 5.0)
		sg.scale = Vector3(s, s, s * 1.5)
		segs.append(sg)
	var hist: Array = []
	var dv := b - a
	var side := dv.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	pj.every(dur, 1.0 / 40.0, func(_i: int, k: float) -> void:
		if not is_instance_valid(head):
			return
		var p := a.lerp(b, k) + side * sin(k * TAU * 1.5) * wiggle * (1.0 - k)
		var nx := a.lerp(b, minf(1.0, k + 0.04)) + side * sin((k + 0.04) * TAU * 1.5) * wiggle * (1.0 - k)
		head.global_position = p
		_look(head, nx)
		hist.push_front(p)
		for i in segs.size():
			var sg: MeshInstance3D = segs[i]
			if is_instance_valid(sg):
				var j := mini((i + 1) * 2, hist.size() - 1)
				sg.global_position = hist[j]
				_look(sg, hist[maxi(j - 1, 0)]), func() -> void:
		for i in segs.size():   # boğumlar gövdeye dalar
			var sg: MeshInstance3D = segs[i]
			if is_instance_valid(sg):
				var tw := sg.create_tween()
				tw.tween_property(sg, "global_position", b, 0.05 + i * 0.03)
				tw.tween_callback(sg.queue_free)
		if is_instance_valid(head):
			head.queue_free())
	pj.free_after(dur + 0.8, head)
	for sg in segs:
		pj.free_after(dur + 0.8, sg)


## Gövdede koyu dikiş izleri (çapraz iplik), birkaç saniyede kapanıp söner (c'nin çocuğu)
static func _sutures(c: Node3D) -> void:
	var h := float(c.get("height")) if c.get("height") != null else 1.8
	var mesh := _cached("mesh:suture", func() -> Mesh:
		var b := MB.new()
		b.add("box", Vector3(0, 0, 0), Vector3(0.36, 0.022, 0.012), Color(0.25, 0.12, 0.3))
		for k in 5:
			b.add("box", Vector3(-0.14 + k * 0.07, 0, 0.004), Vector3(0.016, 0.1, 0.01), Color(0.35, 0.18, 0.4), Vector3(0, 0, 25))
		return b.build())
	for k in 6:
		var a := TAU * k / 6.0 + randf_range(-0.3, 0.3)
		var m := _cel(Color.WHITE, 0.0, INK, 0.5, 1.2, true, 1.0)
		var s := _mi(mesh, m)
		c.add_child(s)
		s.position = Vector3(cos(a) * 0.27, h * randf_range(0.35, 0.8), sin(a) * 0.27)
		s.rotation = Vector3(0, -a + PI * 0.5, randf_range(-0.8, 0.8))
		s.scale = Vector3(0.01, 1, 1)
		var tw := s.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(s, "scale", Vector3.ONE, 0.15)
		_fade(s, m, 1.0 + k * 0.05, 0.6)
