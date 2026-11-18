class_name RanjinFXA
extends RefCounted
## Ranton (Fırtına Salınımı — Kumo, Ikazuchi ışınları) ve Jinton (Toz Salınımı — Ōnoki / Mū) grubu.
## Her tekniğin görüntüsü bu dosyada sıfırdan üretilir; iki doğanın yapı taşları ayrıdır:
##   RANTON: su gibi bükülen camgöbeği "sıvı şimşek" ışını (kendi tüp geometrisi + akan parlak bant gölgelendiricisi,
##           ışın boyunca yanıp sönen şimşek kıvılcımları), cel fırtına bulutu (koyu kontur), ıslak halka izi, zikzak çatlak şimşek.
##   JINTON: yarı saydam keskin kenarlı geometrik kabuk (küp / küre / koni / silindir — kenar ve halka çizgileri
##           gölgelendiricide nesne uzayından), içte genişleyen beyaz-sıcak çekirdek ışığı, moleküllerine ayrılan ince tanecikler.
## Oynanış ana ağaçtaki işleyicilerden (path_jutsu p_* + clan_jutsu c_*) satır satır taşındı — yalnız görünüş yeni.
## Okunurluk: tüm gölgelendiricilerde kameraya yakın kısım yumuşakça söner (near); hiçbir parça ekranı kaplamaz.

const RAN_CORE := Color(0.93, 1.0, 1.0, 1.0)
const RAN_TEAL := Color(0.28, 0.82, 0.94, 1.0)
const RAN_DEEP := Color(0.06, 0.34, 0.52, 1.0)
const RAN_LIGHT := Color(0.55, 0.9, 1.0, 1.0)
const RAN_SPARK := Color(0.3, 0.7, 0.85, 1.0)
const STORM_INK := Color(0.04, 0.05, 0.08, 1.0)
const CLOUD_DARK := Color(0.22, 0.23, 0.28, 1.0)
const CLOUD_DARK_B := Color(0.13, 0.14, 0.18, 1.0)
const CLOUD_PALE := Color(0.76, 0.81, 0.9, 1.0)
const CLOUD_PALE_B := Color(0.56, 0.63, 0.76, 1.0)
const JIN_HOT := Color(1.0, 1.0, 1.0, 1.0)
const JIN_EDGE := Color(0.78, 0.9, 1.0, 1.0)
const JIN_BODY := Color(0.88, 0.95, 1.0, 0.1)
const JIN_MOTE := Color(0.96, 0.97, 1.0, 1.0)
const STONE := Color(0.56, 0.5, 0.44, 1.0)
const STONE_INK := Color(0.12, 0.1, 0.08, 1.0)

static var _sh := {}
static var _mc := {}


# ================================================================== gölgelendiriciler
## RANTON ışını (tüp; UV.x boy 0..1, UV.y çevre): beyaz öz, camgöbeği gövde, koyu kenar; boy boyunca su gibi akan
## kabarık dalga + ıslak parlaklık şeridi; kısa süre yanıp sönen zikzak şimşek kıvılcımları. head/tail ile büyür / çekilir.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.28, 0.82, 0.94, 1.0);
uniform vec4 core : source_color = vec4(0.93, 1.0, 1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.34, 0.52, 1.0);
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float len_m = 10.0;
uniform float flow = 3.0;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float near = 2.5;

float hsh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453);
}

void fragment() {
	float u = UV.x;
	if (u > head || u < tail) {
		discard;
	}
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float s = u * len_m;
	float wave = sin(s * 2.2 - TIME * flow * 4.0 + sin(s * 0.7 + TIME * 2.0) * 1.5);
	vec3 c = tint.rgb;
	float a = 0.92;
	if (fr < 0.4 + 0.1 * wave) {
		c = core.rgb;
	} else if (fr > 0.8) {
		c = ink.rgb;
		a = 0.85;
	}
	float gl = step(0.88, sin(s * 1.3 - TIME * flow * 6.0)) * step(0.42, fr) * step(fr, 0.76);
	c = mix(c, core.rgb, gl);
	float cell = floor(s * 1.5);
	float on = step(0.84, hsh(vec2(cell, floor(TIME * 14.0))));
	float zig = abs(fract(UV.y * 2.0 + fract(s * 1.5) * 2.0) - 0.5);
	c = mix(c, vec3(1.0), on * step(zig, 0.07));
	c = mix(c, core.rgb, smoothstep(head - 0.03, head, u));
	ALBEDO = c;
	ALPHA = clamp(a * tint.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## RANTON sıvı gövde (herhangi bir mesh: tazı, ejder başı, küre): dünya uzayında akan dalga, beyaz öz, koyu kenar, yanıp sönen kıvılcım.
const LIQUID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.28, 0.82, 0.94, 1.0);
uniform vec4 core : source_color = vec4(0.93, 1.0, 1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.34, 0.52, 1.0);
uniform float flick = 1.0;
uniform float fade = 1.0;
uniform float near = 2.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float sw = sin(wp.x * 3.1 + wp.y * 4.3 - TIME * 7.0) + sin(wp.z * 3.7 - wp.y * 2.0 + TIME * 5.0);
	vec3 c = tint.rgb;
	if (fr < 0.36 + 0.1 * sw) {
		c = core.rgb;
	} else if (fr > 0.78) {
		c = ink.rgb;
	}
	c = mix(c, core.rgb, step(1.5, sw) * step(0.3, fr) * step(fr, 0.76));
	float fl = step(0.965, fract(sin(dot(floor(wp * 3.0), vec3(12.9, 78.2, 37.7)) + floor(TIME * 12.0)) * 43758.5453)) * flick;
	c = mix(c, vec3(1.0), fl);
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## RANTON cel bulut: iki ton (üst açık / alt koyu), içten şimşekle aydınlanan alt yüz (glow), kameraya yakın söner.
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.22, 0.23, 0.28, 1.0);
uniform vec4 dark : source_color = vec4(0.13, 0.14, 0.18, 1.0);
uniform vec4 glow_col : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float glow = 0.0;
uniform float fade = 1.0;
uniform float near = 3.0;

varying vec3 wn;

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wn);
	float l = dot(n, normalize(vec3(0.3, 1.0, 0.2)));
	vec3 c = l > 0.05 ? tint.rgb : dark.rgb;
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float under = 0.35 + 0.65 * step(n.y, -0.1);
	c = mix(c, glow_col.rgb, clamp(glow * under * step(fr, 0.72), 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(tint.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Koyu cel kontur (ters kabuk) — bulut ve kaya için
const INK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.04, 0.05, 0.08, 1.0);
uniform float width = 0.04;
uniform float fade = 1.0;
uniform float near = 3.0;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Toplamalı ışıma (kıvılcım, halka, çekirdek); soft > 0: kenara doğru söner (küre ışıma)
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float soft = 0.0;
uniform float fade = 1.0;
uniform float near = 2.0;

void fragment() {
	float fc = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float a = tint.a * COLOR.a * fade * mix(1.0, pow(fc, 1.6), soft);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = clamp(a * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Zemin izi (yatay disk, UV): genişleyen halkalar, isteğe bağlı yanık yıldız ışınları, ortada leke.
const RIPPLE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.28, 0.82, 0.94, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.34, 0.52, 1.0);
uniform vec4 hi_col : source_color = vec4(1.0);
uniform float prog = 0.5;
uniform float rings = 2.0;
uniform float rays = 0.0;
uniform float pool_a = 0.35;
uniform float pool_r = 0.35;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float near = 2.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	if (d > 1.0) {
		discard;
	}
	float a = 0.0;
	vec3 c = tint.rgb;
	for (int i = 0; i < 3; i++) {
		if (float(i) < rings) {
			float pr = prog * (1.0 - float(i) * 0.3);
			float w = 0.03 + 0.015 * float(i);
			if (abs(d - pr) < w) {
				a = max(a, 0.9 - float(i) * 0.22);
				c = abs(d - pr) < w * 0.35 ? hi_col.rgb : tint.rgb;
			}
		}
	}
	if (rays > 0.0 && a < 0.5) {
		float ang = atan(q.y, q.x);
		float sr = pow(abs(cos(ang * rays * 0.5 + seed)), 26.0) * (1.0 - d) * step(d, prog);
		if (sr > 0.18) {
			c = ink.rgb;
			a = 0.75;
		}
	}
	float pool = step(d, prog * pool_r) * pool_a;
	if (a < pool) {
		a = pool;
		c = mix(ink.rgb, tint.rgb, 0.5);
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## JINTON kabuğu: yarı saydam beden + keskin parlak kenarlar + kayan halka çizgileri; glow = içten dolan beyaz-sıcak ışık.
## kind: 0 küp, 1 küre, 2 koni (Y ekseni boyunca, uç +Y), 3 silindir. half_ext: mesh'in yerel yarı boyu.
const JIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform int kind = 0;
uniform vec3 half_ext = vec3(0.5);
uniform vec4 body : source_color = vec4(0.88, 0.95, 1.0, 0.1);
uniform vec4 edge : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(1.0);
uniform float edge_w = 0.035;
uniform float lines = 5.0;
uniform float scroll = 1.0;
uniform float glow = 0.0;
uniform float fade = 1.0;
uniform float near = 3.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 q = lp / half_ext;
	vec3 aq = abs(q);
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float e = 0.0;
	float r = 0.0;
	float rad = length(q.xz);
	if (kind == 0) {
		float ex = step(1.0 - edge_w, aq.x);
		float ey = step(1.0 - edge_w, aq.y);
		float ez = step(1.0 - edge_w, aq.z);
		e = step(1.5, ex + ey + ez);
		r = step(fract(q.y * lines * 0.5 - TIME * scroll), 0.045);
	} else if (kind == 1) {
		e = step(0.84, fr);
		r = step(abs(fract(q.y * lines * 0.5 + TIME * scroll * 0.3) - 0.5), 0.022);
		r = max(r, step(abs(q.y), edge_w * 0.7));
	} else if (kind == 2) {
		e = max(step(0.9, fr), step(q.y, -1.0 + edge_w) * step(1.0 - edge_w * 2.0, rad));
		r = step(fract(q.y * lines * 0.5 - TIME * scroll), 0.06);
	} else {
		e = max(step(0.9, fr) * 0.6, step(1.0 - edge_w, aq.y) * step(1.0 - edge_w * 2.0, rad));
		r = step(fract(q.y * lines * 0.5 + TIME * scroll), 0.04);
	}
	vec3 c = body.rgb;
	float a = body.a * (0.6 + 0.9 * fr);
	a += glow * 0.42 * (1.0 - fr);
	c = mix(c, hot.rgb, clamp(glow * (1.0 - fr), 0.0, 1.0));
	if (r > 0.5) {
		c = edge.rgb;
		a = max(a, 0.42);
	}
	if (e > 0.5) {
		c = hot.rgb;
		a = 0.95;
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""


# ================================================================== malzeme yardımcıları
static func _shader(key: String, code: String) -> Shader:
	var k := "sh:" + key
	if not _sh.has(k):
		var s := Shader.new()
		s.code = code
		_sh[k] = s
	return _sh[k]


static func _mat(key: String, code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(key, code)
	return m


static func set_fade(m: Material, v: float) -> void:
	var q := m
	while q != null:
		if q is ShaderMaterial:
			(q as ShaderMaterial).set_shader_parameter("fade", v)
		q = q.next_pass


## delay sonra dur sürede söner, sonra silinir
static func _fade_out(n, m: Material, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw: Tween = n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var f := func(v: float) -> void:
		set_fade(m, v)
	tw.tween_method(f, 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


static func _beam_mat(L: float, tint := RAN_TEAL, flow := 3.0) -> ShaderMaterial:
	var m := _mat("beam", BEAM_SHADER)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("core", RAN_CORE)
	m.set_shader_parameter("ink", RAN_DEEP)
	m.set_shader_parameter("len_m", L)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("seed", randf() * 40.0)
	return m


static func _liquid_mat(flick := 1.0) -> ShaderMaterial:
	var m := _mat("liquid", LIQUID_SHADER)
	m.set_shader_parameter("tint", RAN_TEAL)
	m.set_shader_parameter("core", RAN_CORE)
	m.set_shader_parameter("ink", RAN_DEEP)
	m.set_shader_parameter("flick", flick)
	return m


static func _cloud_mat(light: Color, dark: Color, outline: float) -> ShaderMaterial:
	var m := _mat("cloud", CLOUD_SHADER)
	m.set_shader_parameter("tint", light)
	m.set_shader_parameter("dark", dark)
	m.set_shader_parameter("glow_col", RAN_LIGHT)
	if outline > 0.0:
		var o := _mat("ink", INK_SHADER)
		o.set_shader_parameter("ink", STORM_INK)
		o.set_shader_parameter("width", outline)
		o.render_priority = -1
		m.next_pass = o
	return m


static func _glow_mat(col: Color, soft := 0.0, near := 2.0) -> ShaderMaterial:
	var m := _mat("glow", GLOW_SHADER)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("soft", soft)
	m.set_shader_parameter("near", near)
	return m


static func _ripple_mat(tint: Color, ink: Color, rings := 2.0, rays := 0.0) -> ShaderMaterial:
	var m := _mat("ripple", RIPPLE_SHADER)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("ink", ink)
	m.set_shader_parameter("rings", rings)
	m.set_shader_parameter("rays", rays)
	m.set_shader_parameter("seed", randf() * 6.0)
	return m


static func _jin_mat(kind: int, half: Vector3, lines := 5.0, edge_w := 0.035) -> ShaderMaterial:
	var m := _mat("jin", JIN_SHADER)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("half_ext", half)
	m.set_shader_parameter("body", JIN_BODY)
	m.set_shader_parameter("edge", JIN_EDGE)
	m.set_shader_parameter("hot", JIN_HOT)
	m.set_shader_parameter("lines", lines)
	m.set_shader_parameter("edge_w", edge_w)
	return m


static func _mote_mat() -> StandardMaterial3D:
	var k := "mat:mote"
	if not _mc.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(1, 1, 1, 1)
		_mc[k] = m
	return _mc[k]


static func _stone_mat() -> Material:
	var k := "mat:stone"
	if not _mc.has(k):
		_mc[k] = Props.toon()
	return _mc[k]


static func _flat_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# ================================================================== düğüm / geometri yapı taşları
static func _put(pj: PathJutsu, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	(parent if parent else pj.get_tree().current_scene).add_child(n)
	n.global_position = pos
	return n


static func _mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _light(pj: PathJutsu, pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_put(pj, l, pos)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, maxf(dur, 0.05)).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


static func _cached(key: String, fn: Callable) -> Mesh:
	var k := "mesh:" + key
	if not _mc.has(k):
		_mc[k] = fn.call()
	return _mc[k]


static func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## a→b arası birim silindir dönüşümü (w: çap)
static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var L := maxf(d.length(), 0.001)
	var y := d / L
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * w, y * L, z * w), (a + b) * 0.5)


static func _poly_len(pts: Array) -> float:
	var L := 0.0
	for i in pts.size() - 1:
		L += (pts[i + 1] as Vector3).distance_to(pts[i])
	return maxf(L, 0.01)


## Tüp: pts boyunca halkalar (paralel taşımalı çerçeve — dikey ışında burulma yok). UV.x boy, UV.y çevre.
## r0 → r1 boyunca incelir; uçlarda taper oranında sivrilir.
static func _tube(pts: Array, r0: float, r1: float, sides := 8, taper := 0.08) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var t0: Vector3 = (pts[1] - pts[0])
	if t0.length() < 0.0001:
		t0 = Vector3.FORWARD
	t0 = t0.normalized()
	var sx := t0.cross(Vector3.UP if absf(t0.y) < 0.95 else Vector3.RIGHT).normalized()
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		if tn.length() < 0.0001:
			tn = t0
		tn = tn.normalized()
		sx = (sx - tn * sx.dot(tn))
		if sx.length() < 0.001:
			sx = tn.cross(Vector3.RIGHT)
		sx = sx.normalized()
		var sy := tn.cross(sx).normalized()
		var u := float(i) / float(n - 1)
		var rr := lerpf(r0, r1, u) * clampf(minf(u, 1.0 - u) / maxf(taper, 0.001), 0.2, 1.0)
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			var nrm := sx * cos(a) + sy * sin(a)
			st.set_uv(Vector2(u, float(s) / float(sides)))
			st.set_normal(nrm)
			st.add_vertex(p + nrm * rr)
	var ring := sides + 1
	for i in n - 1:
		for s in sides:
			var a0 := i * ring + s
			var b0 := a0 + ring
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


static func _bez(a: Vector3, m: Vector3, b: Vector3, n: int) -> Array:
	var pts := []
	for i in n:
		var f := float(i) / float(n - 1)
		pts.append(a.lerp(m, f).lerp(m.lerp(b, f), f))
	return pts


## Su gibi kıvrılan eğri: bezier + uçlarda sönen iki eksenli yılankavi salınım
static func _liquid_curve(a: Vector3, m: Vector3, b: Vector3, n: int, wob: float, phase: float) -> Array:
	var pts := []
	var d := b - a
	var sd := d.cross(Vector3.UP)
	if sd.length() < 0.01:
		sd = Vector3.RIGHT
	sd = sd.normalized()
	var up := sd.cross(d).normalized()
	for i in n:
		var f := float(i) / float(n - 1)
		var p := a.lerp(m, f).lerp(m.lerp(b, f), f)
		var env := sin(PI * f)
		p += (sd * sin(f * TAU * 1.5 + phase) + up * cos(f * TAU + phase * 0.7) * 0.6) * wob * env
		pts.append(p)
	return pts


## Zikzak şimşek noktaları
static func _zig(a: Vector3, b: Vector3, segs: int, jit: float) -> Array:
	var pts := [a]
	for i in range(1, segs):
		var f := float(i) / float(segs)
		pts.append(a.lerp(b, f) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jit)
	pts.append(b)
	return pts


static func _add_bolt(b: MB, pts: Array, w: float) -> void:
	for i in pts.size() - 1:
		b.add_xf("cyl", _seg_xf(pts[i], pts[i + 1], w * 2.8), RAN_SPARK, 4)
		b.add_xf("cyl", _seg_xf(pts[i], pts[i + 1], w), Color(1, 1, 1), 4)


## Genel parçacık salıcı (kendi ayarları): tek seferlik patlama
static func _spray(pj: PathJutsu, pos: Vector3, mesh: Mesh, m: Material, n: int, life: float, o := {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = bool(o.get("one_shot", true))
	p.explosiveness = float(o.get("expl", 0.9))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.3))
	var dv: Vector3 = o.get("dir", Vector3.UP)
	p.direction = dv.normalized() if dv.length() > 0.001 else Vector3.UP
	p.spread = float(o.get("spread", 180.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("g", Vector3(0, -6, 0))
	p.damping_min = float(o.get("damp", 0.0))
	p.damping_max = float(o.get("damp", 0.0))
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.7))
	p.scale_amount_max = float(o.get("smax", 1.3))
	if o.get("align", false):
		p.particle_flag_align_y = true
	else:
		p.particle_flag_rotate_y = true
		p.angle_min = 0.0
		p.angle_max = 360.0
		var sp := float(o.get("spin", 90.0))
		p.angular_velocity_min = -sp
		p.angular_velocity_max = sp
	var g := Gradient.new()
	var c0: Color = o.get("c0", Color(1, 1, 1, 1))
	var c1: Color = o.get("c1", Color(1, 1, 1, 0))
	g.set_color(0, c0)
	g.set_color(1, c1)
	g.add_point(float(o.get("hold", 0.6)), c0.lerp(c1, 0.25))
	p.color_ramp = g
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, float(o.get("start_scale", 1.0))))
	cv.add_point(Vector2(1.0, float(o.get("end_scale", 0.4))))
	p.scale_amount_curve = cv
	var parent: Node = o.get("parent", null)
	_put(pj, p, pos, parent)
	p.emitting = true
	if p.one_shot:
		pj.free_after(life + 0.6, p)
	return p


# ================================================================== RANTON yapı taşları
static func _m_drop() -> Mesh:
	return _cached("drop", func():
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.12, 0.2, 0.12), Color.WHITE, Vector3.ZERO, 8)
		return b.build())


static func _m_puff() -> Mesh:
	return _cached("puff", func():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 14
		s.rings = 7
		return s)


static func _m_ring() -> Mesh:
	return _cached("ring", func():
		var t := TorusMesh.new()
		t.inner_radius = 0.46
		t.outer_radius = 0.5
		t.rings = 40
		t.ring_segments = 6
		return t)


static func _m_disc() -> Mesh:
	return _cached("disc", func():
		var p := PlaneMesh.new()
		p.size = Vector2(2, 2)
		return p)


static func _m_glow_ball() -> Mesh:
	return _cached("gball", func():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 16
		s.rings = 8
		return s)


## Sıvı-şimşek ışını: pts boyunca tüp; grow sürede baştan uca akar, hold kalır, out sürede kuyruktan çekilir.
static func _beam(pj: PathJutsu, pts: Array, r: float, grow: float, hold: float, out: float, o := {}) -> MeshInstance3D:
	var L := _poly_len(pts)
	var m := _beam_mat(L, o.get("tint", RAN_TEAL), float(o.get("flow", 3.0)))
	m.set_shader_parameter("near", float(o.get("near", 2.5)))
	var x := _mi(_tube(pts, r, float(o.get("r1", r)), int(o.get("sides", 8)), float(o.get("taper", 0.06))), m)
	_put(pj, x, Vector3.ZERO)
	m.set_shader_parameter("head", 0.0 if grow > 0.0 else 1.0)
	var tw := x.create_tween()
	if grow > 0.0:
		var g := func(v: float) -> void:
			m.set_shader_parameter("head", v)
		tw.tween_method(g, 0.0, 1.0, grow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(hold, 0.0))
	var w := func(v: float) -> void:
		m.set_shader_parameter("tail", v)
		m.set_shader_parameter("fade", 1.0 - v * 0.5)
	tw.tween_method(w, 0.0, 1.0, maxf(out, 0.05)).set_ease(Tween.EASE_IN)
	tw.tween_callback(x.queue_free)
	return x


## Çatırdayan şimşek: src.call() → çapa noktaları; her 0.05 sn rastgele çapalardan reach boyunda zikzak çatlak + kol
static func _crackle(pj: PathJutsu, src: Callable, n: int, dur: float, w: float, reach: float) -> void:
	var m := _glow_mat(Color(1, 1, 1, 1), 0.0, 2.5)
	var x := _mi(ArrayMesh.new(), m)
	_put(pj, x, Vector3.ZERO)
	var tick := func(_i: int, _k: float) -> void:
		if not is_instance_valid(x):
			return
		var anchors: Array = src.call()
		if anchors.is_empty():
			x.mesh = null
			return
		var b := MB.new()
		for j in n:
			if randf() < 0.35:
				continue
			var a: Vector3 = anchors[randi() % anchors.size()]
			var e := a + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)).normalized() * reach * randf_range(0.6, 1.0)
			var pts := _zig(a, e, 5, reach * 0.16)
			_add_bolt(b, pts, w)
			if randf() < 0.6:
				var k0: Vector3 = pts[2]
				_add_bolt(b, _zig(k0, k0 + (e - a).rotated(Vector3.UP, randf_range(-1.2, 1.2)) * 0.4, 3, reach * 0.08), w * 0.6)
		x.mesh = b.build()
	var done := func() -> void:
		if is_instance_valid(x):
			x.queue_free()
	pj.every(dur, 0.05, tick, done)


## Tek parlak zikzak şimşek (kısa ömür) — a'dan b'ye, dallı
static func _bolt(pj: PathJutsu, a: Vector3, b: Vector3, w: float, life: float) -> void:
	var mb := MB.new()
	var pts := _zig(a, b, 7, a.distance_to(b) * 0.07)
	_add_bolt(mb, pts, w)
	for j in 2:
		var k0: Vector3 = pts[2 + j * 2]
		_add_bolt(mb, _zig(k0, k0 + (b - a).normalized().rotated(Vector3.UP, randf_range(-1.4, 1.4)) * a.distance_to(b) * 0.25 + Vector3.UP * randf_range(-0.5, 0.5), 3, 0.3), w * 0.55)
	var m := _glow_mat(Color(1, 1, 1, 1), 0.0, 2.5)
	var x := _mi(mb.build(), m)
	_put(pj, x, Vector3.ZERO)
	_fade_out(x, m, life * 0.4, life * 0.6)


## Islak zemin halkası (ve isteğe bağlı yanık yıldız)
static func _ripple(pj: PathJutsu, pos: Vector3, r: float, dur: float, o := {}) -> MeshInstance3D:
	var m := _ripple_mat(o.get("tint", RAN_TEAL), o.get("ink", RAN_DEEP), float(o.get("rings", 2.0)), float(o.get("rays", 0.0)))
	m.set_shader_parameter("pool_a", float(o.get("pool", 0.3)))
	m.set_shader_parameter("hi_col", o.get("hi", Color(1, 1, 1)))
	var x := _mi(_m_disc(), m)
	_put(pj, x, pos + Vector3.UP * float(o.get("lift", 0.05)))
	x.scale = Vector3.ONE * r
	var tw := x.create_tween()
	var pf := func(v: float) -> void:
		m.set_shader_parameter("prog", v)
	tw.tween_method(pf, float(o.get("p0", 0.12)), float(o.get("p1", 0.95)), dur * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ff := func(v: float) -> void:
		m.set_shader_parameter("fade", v)
	tw.tween_method(ff, 1.0, 0.0, dur * 0.45)
	tw.tween_callback(x.queue_free)
	return x


## Sıvı damla sıçraması
static func _droplets(pj: PathJutsu, pos: Vector3, n: int, vmin: float, vmax: float, dir := Vector3.UP, spread := 70.0) -> void:
	var m := _liquid_mat(0.0)
	_spray(pj, pos, _m_drop(), m, n, 0.7, {"r": 0.25, "dir": dir, "spread": spread, "vmin": vmin, "vmax": vmax, "g": Vector3(0, -16, 0),
		"align": true, "smin": 0.7, "smax": 1.5, "end_scale": 0.3, "c0": Color(1, 1, 1, 1), "c1": Color(1, 1, 1, 0)})


## Yatık parlak halka (ref: Reizā Sākasu'da ellerin çevresindeki elips halka) — axis halkanın normali
static func _halo(pj: PathJutsu, pos: Vector3, axis: Vector3, r: float, dur: float, squash := 0.55) -> void:
	var m := _glow_mat(Color(0.75, 0.97, 1.0, 0.9), 0.0, 2.0)
	var x := _mi(_m_ring(), m)
	_put(pj, x, pos)
	x.global_basis = _basis_y(axis)
	x.scale = Vector3(r * 0.4, 1.0, r * 0.4 * squash)
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3(r * 2.0, 1.0, r * 2.0 * squash), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_out(x, m, dur * 0.4, dur * 0.6)


## Elde sıvı-şimşek topağı: bone_attach'e eklenir (ağaca girdikten sonra canlandırılır), life sonra silinir
static func _attach_orb(pj: PathJutsu, c: Node3D, side: String, r: float, life: float) -> void:
	var ba := pj.bone_attach(c, side)
	if ba == null:
		return
	var root := Node3D.new()
	ba.add_child(root)
	var body := _mi(_m_glow_ball(), _liquid_mat())
	body.scale = Vector3.ONE * r
	root.add_child(body)
	var halo := _mi(_m_glow_ball(), _glow_mat(Color(0.45, 0.9, 1.0, 0.55), 1.0, 1.5))
	halo.scale = Vector3.ONE * r * 2.0
	root.add_child(halo)
	for k in 3:
		var ring := _mi(_m_ring(), _glow_mat(Color(0.8, 1.0, 1.0, 0.8), 0.0, 1.5))
		ring.scale = Vector3.ONE * r * (1.2 + k * 0.25)
		ring.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		root.add_child(ring)
		var tw := Game.safe_loops(ring.create_tween(), int(life / (0.35 + k * 0.1)) + 1)
		tw.tween_property(ring, "rotation:y", ring.rotation.y + TAU, 0.35 + k * 0.1).from(ring.rotation.y)
	var pt := Game.safe_loops(body.create_tween(), int(life / 0.14) + 1)
	pt.tween_property(body, "scale", Vector3.ONE * r * 1.2, 0.07)
	pt.tween_property(body, "scale", Vector3.ONE * r * 0.9, 0.07)
	pj.free_after(life, ba)


## Cel bulut kümesi: offs (yerel konum) / sizes; ortak malzeme meta "mat"
static func _cloud(pj: PathJutsu, pos: Vector3, offs: Array, sizes: Array, light: Color, dark: Color, outline: float, near := 3.0) -> Node3D:
	var root := Node3D.new()
	_put(pj, root, pos)
	var m := _cloud_mat(light, dark, outline)
	m.set_shader_parameter("near", near)
	if m.next_pass:
		(m.next_pass as ShaderMaterial).set_shader_parameter("near", near)
	root.set_meta("mat", m)
	var puffs := []
	for i in offs.size():
		var x := _mi(_m_puff(), m)
		root.add_child(x)
		x.position = offs[i]
		var s: float = sizes[i]
		x.scale = Vector3.ONE * s * 0.15
		x.set_meta("s", s)
		var tw := x.create_tween()
		tw.tween_interval(randf() * 0.25)
		tw.tween_property(x, "scale", Vector3(s, s * 0.82, s), randf_range(0.3, 0.55)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		puffs.append(x)
	root.set_meta("puffs", puffs)
	return root


## Bulut içi şimşek ışığı: alt yüz camgöbeği parlar, sönümlenir
static func _cloud_flash(root, amt: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	var m: ShaderMaterial = root.get_meta("mat")
	var tw: Tween = root.create_tween()
	var gf := func(v: float) -> void:
		m.set_shader_parameter("glow", v)
	tw.tween_method(gf, amt, 0.0, 0.25)


## Bulut kabarması: her puf kendi evresinde nefes alır
static func _cloud_breathe(root, t: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	var puffs: Array = root.get_meta("puffs")
	for i in puffs.size():
		var x: MeshInstance3D = puffs[i]
		if is_instance_valid(x):
			var s: float = x.get_meta("s")
			var w := 1.0 + 0.06 * sin(t * 2.3 + i * 1.7)
			x.scale = x.scale.lerp(Vector3(s * w, s * 0.82 * w, s * w), 0.25)


static func _cloud_end(root, dur: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	var m: ShaderMaterial = root.get_meta("mat")
	var tw: Tween = root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3(1.15, 0.6, 1.15), dur)
	var ff := func(v: float) -> void:
		set_fade(m, v)
	tw.tween_method(ff, 1.0, 0.0, dur)
	tw.chain().tween_callback(root.queue_free)


static func _ellipsoid_offsets(n: int, rx: float, ry: float, rz: float, smin: float, smax: float) -> Array:
	var offs := []
	var sizes := []
	for i in n:
		var a := randf() * TAU
		var rr := sqrt(randf()) if i > 0 else 0.0
		offs.append(Vector3(cos(a) * rx * rr, randf_range(-ry, ry) * (1.0 - rr * 0.5), sin(a) * rz * rr))
		sizes.append(randf_range(smin, smax) * (1.0 - rr * 0.35))
	return [offs, sizes]


## Takip eden sıvı gövde/iz: mermi geçmişinden her kare tüp (baş kalın, kuyruk ince); mermi bitince kuyruktan çekilir
static func _follow_tube(pj: PathJutsu, pr: Projectile, r0: float, r1: float, n: int, off := Vector3.ZERO, flow := 4.0, sides := 8) -> void:
	var hist: Array = [pr.global_position + off]
	var m := _beam_mat(1.0, RAN_TEAL, flow)
	var x := _mi(ArrayMesh.new(), m)
	_put(pj, x, Vector3.ZERO)
	var tick := func(_i: int, _k: float) -> void:
		if not is_instance_valid(x):
			return
		if is_instance_valid(pr) and not pr.dead:
			hist.push_front(pr.global_position + off)
			if hist.size() > n:
				hist.pop_back()
		elif hist.size() > 0:
			hist.pop_back()
		if hist.size() < 3:
			x.visible = false
			return
		x.visible = true
		x.mesh = _tube(hist, r0, r1, sides, 0.05)
		m.set_shader_parameter("len_m", _poly_len(hist))
	var done := func() -> void:
		if is_instance_valid(x):
			x.queue_free()
	pj.every(pr.life + 0.6, 1.0 / 30.0, tick, done)


## Islak çatlak damarları (Ranton): koyu yarık + içinde parlayan camgöbeği damar
static func _ran_fissure(pj: PathJutsu, pos: Vector3, r: float, dur: float) -> void:
	var dk := MB.new()
	var gl := MB.new()
	for k in 7:
		var a := k * TAU / 7.0 + randf_range(-0.3, 0.3)
		var p0 := Vector3(cos(a), 0, sin(a)) * 0.4
		var pts := [p0]
		var cur := p0
		var ang := a
		for s in 4:
			ang += randf_range(-0.45, 0.45)
			cur = cur + Vector3(cos(ang), 0, sin(ang)) * r * randf_range(0.16, 0.26)
			pts.append(cur)
		for i in pts.size() - 1:
			var w := 0.32 * (1.0 - float(i) / pts.size())
			var q0: Vector3 = pts[i]
			var q1: Vector3 = pts[i + 1]
			var xf := _seg_xf(q0, q1, w)
			dk.add_xf("box", Transform3D(xf.basis.scaled(Vector3(1, 0.08, 1)), xf.origin), STORM_INK)
			var xg := _seg_xf(q0 + Vector3.UP * 0.02, q1 + Vector3.UP * 0.02, w * 0.4)
			gl.add_xf("box", Transform3D(xg.basis.scaled(Vector3(1, 0.1, 1)), xg.origin), RAN_LIGHT)
	var dm := _flat_mat(Color(1, 1, 1, 0.92))
	var x := _mi(dk.build(), dm)
	_put(pj, x, pos + Vector3.UP * 0.04)
	var gm := _glow_mat(Color(1, 1, 1, 1), 0.0, 2.0)
	var y := _mi(gl.build(), gm)
	_put(pj, y, pos + Vector3.UP * 0.05)
	_fade_out(y, gm, dur * 0.3, dur * 0.5)
	var tw := x.create_tween()
	tw.tween_interval(dur * 0.6)
	tw.tween_property(dm, "albedo_color:a", 0.0, dur * 0.4)
	tw.tween_callback(x.queue_free)


# ================================================================== RANTON: Reizā Sākasu (Lazer Sirki)
## ref: Darui — avuçlarda parlak düğüm, çevresinde elips halka; bir düzine kalın ışın yelpaze gibi açılıp su gibi kıvrılarak
## ayrı hedeflere iner, yollarında ince dallar ayrılır; uçlarda ıslak sıçrama.
static func ranton_reiza_sakasu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	for side in ["RightHand", "LeftHand"]:
		_attach_orb(pj, c, side, 0.32, 1.0)
	# --- c_ranton_reiza_sakasu (mekanik aynen)
	var list = pj.enemies_near(c, c.global_position, 35.0)
	pj.busy(c, 0.9)
	var hand: Vector3 = Jutsu._hand(c)
	var fwd_d: Vector3 = Jutsu._aim(c, t)
	var side_v := fwd_d.cross(Vector3.UP).normalized()
	_halo(pj, hand + fwd_d * 0.35, fwd_d, 1.4, 0.9, 0.55)
	_halo(pj, hand + fwd_d * 0.2, fwd_d.rotated(Vector3.UP, 0.5), 0.9, 0.7, 0.4)
	for k in 12:
		var target = list[k % list.size()] if not list.is_empty() else null
		var end: Vector3 = (target.global_position + Vector3.UP * 1.0) if target else hand + (fwd_d + side_v * randf_range(-0.5, 0.5) + Vector3.UP * randf_range(-0.1, 0.3)).normalized() * 26.0
		var mid: Vector3 = hand.lerp(end, 0.45) + side_v * ((k - 5.5) * 1.6 + randf_range(-0.6, 0.6)) + Vector3.UP * (1.0 + (k % 4) * 1.8)
		var tt = target
		var e2 := end
		var kk := k
		var fire := func() -> void:
			if not is_instance_valid(c):
				return
			var h0: Vector3 = Jutsu._hand(c)
			var pts := _liquid_curve(h0, mid, e2, 28, 0.35 + randf() * 0.4, randf() * TAU)
			_beam(pj, pts, 0.15 + 0.05 * (kk % 3), 0.12, 0.22, 0.32, {"flow": 3.5})
			# yoldan ayrılan ince dal (ışın sirki: ışınlar çoğalır)
			if kk % 2 == 0:
				var j := 10 + randi() % 8
				var bp: Vector3 = pts[j]
				var bdir: Vector3 = ((pts[j + 1] as Vector3) - bp).normalized()
				var bend := bp + (bdir + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.4), randf_range(-0.6, 0.6))).normalized() * randf_range(4.0, 7.0)
				_beam(pj, _liquid_curve(bp, bp.lerp(bend, 0.5) + Vector3.UP * randf_range(-1.0, 1.5), bend, 12, 0.3, randf() * TAU), 0.05, 0.1, 0.12, 0.2, {"r1": 0.02, "sides": 6})
			_droplets(pj, e2, 6, 3.0, 6.0, (h0 - e2).normalized() + Vector3.UP, 60.0)
			_ripple(pj, e2, 0.9, 0.5, {"rings": 1.0, "pool": 0.0, "lift": 0.0})
			_light(pj, e2, Color(0.6, 0.85, 1.0), 4.0, 8.0, 0.3)
			if tt and is_instance_valid(tt) and not tt.is_dead():
				tt.take_hit(pj.inf(c, "ranton_reiza_sakasu", 0.3, {"knock": 4.0, "kind": "heavy", "element": "ranton", "stun": 0.4}))
		pj.get_tree().create_timer(0.08 + k * 0.03).timeout.connect(fire)
	_light(pj, hand, Color(0.8, 0.92, 1.0), 6.0, 10.0, 0.6)
	Sfx.play("chidori", c.global_position, 1.7)


# ================================================================== RANTON: Reizā Ame (Lazer Yağmuru)
## Elden göğe ince bir ışın yükselir; 14 m yukarıda açık gri, alt yüzü camgöbeği parlayan cel bulut kabarır, ortasında
## sıvı ışık düğümü; 2 sn boyunca ince ışınlar su gibi bükülerek yere yağar, her biri ıslak halka + damla sıçratır.
static func ikazuchi_reiza_ame(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var hp: Vector3 = Jutsu._hand(c)
	_light(pj, hp, Color(0.6, 0.85, 1.0), 4.0, 8.0, 0.4)
	# --- c_ikazuchi_reiza_ame
	var center: Vector3 = pj.gp(Jutsu._aim_ground(c, t, 12.0, 26.0))
	var top := center + Vector3.UP * 14.0
	_beam(pj, _liquid_curve(hp, hp.lerp(top, 0.5) + Vector3.UP * 2.0, top, 20, 0.6, randf() * TAU), 0.12, 0.18, 0.1, 0.25, {"r1": 0.06})
	var knot := Node3D.new()
	var kb := _mi(_m_glow_ball(), _liquid_mat())
	kb.scale = Vector3.ONE * 1.6
	knot.add_child(kb)
	var kh := _mi(_m_glow_ball(), _glow_mat(Color(0.5, 0.9, 1.0, 0.5), 1.0, 3.0))
	kh.scale = Vector3.ONE * 4.0
	knot.add_child(kh)
	_put(pj, knot, top)
	knot.scale = Vector3.ONE * 0.1
	var kt := knot.create_tween()
	kt.tween_property(knot, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	kt.tween_interval(1.9)
	kt.tween_property(knot, "scale", Vector3.ONE * 0.05, 0.3).set_ease(Tween.EASE_IN)
	kt.tween_callback(knot.queue_free)
	_light(pj, top, Color(0.6, 0.85, 1.0), 6.0, 30.0, 2.4)
	var od: Array = _ellipsoid_offsets(12, 7.0, 0.7, 5.0, 3.2, 4.8)
	var cloud := _cloud(pj, top + Vector3.UP * 1.0, od[0], od[1], CLOUD_PALE, CLOUD_PALE_B, 0.06, 4.0)
	var rain := func(i: int, _k: float) -> void:
		_cloud_breathe(cloud, i * 0.1)
		var list = pj.enemies_near(c, center, 10.0)
		var p: Vector3 = (list[randi() % list.size()].global_position if not list.is_empty() and randf() < 0.6 else center + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9)))
		var a := center + Vector3.UP * 14.0
		var mid := a.lerp(p, 0.4) + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		_beam(pj, _liquid_curve(a, mid, p + Vector3.UP * 0.2, 18, 0.5, randf() * TAU), 0.08, 0.08, 0.1, 0.16, {"r1": 0.11, "flow": 5.0})
		if i % 3 == 0:
			_cloud_flash(cloud, 0.9)
		pj.hit(c, p + Vector3.UP * 0.8, 1.4, pj.inf(c, "ikazuchi_reiza_ame", 0.12, {"knock": 2.0, "element": "ranton"}))
		var g: Vector3 = pj.gp(p)
		_ripple(pj, g, 1.3, 0.7, {"rings": 2.0, "pool": 0.25})
		_droplets(pj, g + Vector3.UP * 0.1, 5, 2.5, 5.0, Vector3.UP, 45.0)
	var stop := func() -> void:
		_cloud_end(cloud, 0.6)
	pj.every(2.0, 0.1, rain, stop)
	Sfx.play("thunder", center, 1.1)


# ================================================================== RANTON: Kōga (Işık Dişi)
## Sıvı ışıktan tazı: kendi gövde geometrisi (göğüs, gövde, baş, burun, kulak, sırt yelesi, kuyruk, dört bacak) — dörtnala
## bacak salınımı, zikzak koşu yönüne döner; ardında yere yakın ince ıslak iz ve pati izleri; çarpınca sıçrayan ıslak ısırık.
static func _hound(s: float) -> Node3D:
	var k := s / 2.6
	var root := Node3D.new()
	var m := _liquid_mat()
	var b := MB.new()
	b.add("sphere", Vector3(0, 0.98, 0.15) * k, Vector3(0.7, 0.66, 1.5) * k, Color.WHITE, Vector3(-4, 0, 0), 12)
	b.add("sphere", Vector3(0, 1.08, -0.45) * k, Vector3(0.82, 0.86, 0.85) * k, Color.WHITE, Vector3.ZERO, 12)
	b.add("cyl", Vector3(0, 1.3, -0.82) * k, Vector3(0.42, 0.6, 0.42) * k, Color.WHITE, Vector3(-50, 0, 0), 10)
	b.add("sphere", Vector3(0, 1.5, -1.02) * k, Vector3(0.5, 0.48, 0.58) * k, Color.WHITE, Vector3.ZERO, 12)
	b.add("box", Vector3(0, 1.42, -1.36) * k, Vector3(0.26, 0.2, 0.46) * k, Color.WHITE, Vector3(8, 0, 0))
	b.add("box", Vector3(0, 1.3, -1.3) * k, Vector3(0.22, 0.08, 0.38) * k, Color.WHITE, Vector3(-14, 0, 0))
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.15 * sx, 1.8, -0.96) * k, Vector3(0.14, 0.34, 0.1) * k, Color.WHITE, Vector3(22, 0, -14 * sx), 6)
	for j in 5:
		b.add("cone", Vector3(0, 1.38 + j * 0.02, -0.7 + j * 0.28) * k, Vector3(0.14, 0.42 - j * 0.05, 0.1) * k, Color.WHITE, Vector3(62, 0, 0), 5)
	b.add("cone", Vector3(0, 1.2, 1.15) * k, Vector3(0.2, 1.0, 0.2) * k, Color.WHITE, Vector3(62, 0, 0), 8)
	var body := _mi(b.build(), m)
	root.add_child(body)
	var legs := []
	for hip in [Vector3(-0.22, 0.95, -0.45), Vector3(0.22, 0.95, -0.45), Vector3(-0.2, 0.95, 0.6), Vector3(0.2, 0.95, 0.6)]:
		var pivot := Node3D.new()
		pivot.position = hip * k
		var lb := MB.new()
		lb.add("cyl", Vector3(0, -0.28, 0) * k, Vector3(0.2, 0.56, 0.2) * k, Color.WHITE, Vector3.ZERO, 8)
		lb.add("cyl", Vector3(0, -0.7, 0.05) * k, Vector3(0.13, 0.42, 0.13) * k, Color.WHITE, Vector3(12, 0, 0), 8)
		lb.add("sphere", Vector3(0, -0.92, -0.02) * k, Vector3(0.18, 0.1, 0.24) * k, Color.WHITE, Vector3.ZERO, 8)
		pivot.add_child(_mi(lb.build(), m))
		root.add_child(pivot)
		legs.append(pivot)
	root.set_meta("legs", legs)
	return root


static func ikazuchi_koga(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	# hazırlık: sağ elde sıvı-şimşek toplanır (içe çekilen damlalar)
	var hpos := pj.hand_pos(c, true)
	_spray(pj, hpos, _m_drop(), _liquid_mat(0.0), 14, 0.45, {"r": 1.4, "vmin": 0.0, "vmax": 0.2, "radial": -9.0, "g": Vector3.ZERO, "expl": 0.6, "align": true, "end_scale": 0.2})
	_light(pj, hpos, RAN_LIGHT, 3.0, 5.0, 0.6)
	# --- c_ikazuchi_koga
	var d := pj.fwd(c, t)
	var head := Node3D.new()
	var hound := _hound(2.6)
	hound.position.y = -0.9
	head.add_child(hound)
	var spd := 17.0
	var hit_fx := func(p, _h) -> void:
		_droplets(pj, p, 16, 4.0, 9.0, Vector3.UP, 80.0)
		_ripple(pj, pj.gp(p), 2.2, 0.7, {"rings": 3.0, "pool": 0.3})
		_crackle(pj, func() -> Array: return [p], 4, 0.25, 0.05, 1.6)
		_light(pj, p, RAN_LIGHT, 5.0, 9.0, 0.35)
	var pr: Projectile = pj.shot(c, pj.gp(c.global_position + d) + Vector3.UP * 0.9, d, spd, head, pj.inf(c, "ikazuchi_koga", 1.1, {"knock": 8.0, "kind": "heavy", "element": "ranton", "stun": 1.2}), pj.tg(c, t, 30.0), false, 2.2, hit_fx)
	_follow_tube(pj, pr, 0.22, 0.02, 9, Vector3(0, -0.4, 0), 5.0, 6)
	var st0 := {"t": 0.0, "off": 0.0, "paw": 0.0}
	var legs: Array = hound.get_meta("legs")
	var tick := func(p, dt) -> void:
		st0["t"] += dt
		var v: Vector3 = p.vel
		v.y = 0.0
		var side := v.normalized().cross(Vector3.UP) if v.length() > 0.1 else d.cross(Vector3.UP)
		var w := 6.5
		var off := sin(st0["t"] * w) * 1.8
		p.global_position += side * (off - st0["off"])
		st0["off"] = off
		p.global_position.y = Game.jutsu_floor(p.global_position.x, p.global_position.z) + 0.9
		if is_instance_valid(hound):
			hound.rotation.y = -atan2(cos(st0["t"] * w) * 1.8 * w, spd)
			# dörtnala: ön ve arka bacak çiftleri karşıt evrede
			var ph: float = st0["t"] * 16.0
			for li in legs.size():
				var lg: Node3D = legs[li]
				if is_instance_valid(lg):
					lg.rotation.x = sin(ph + (0.0 if li < 2 else PI) + (li % 2) * 0.4) * 0.75
			hound.position.y = -0.9 + absf(sin(ph)) * 0.12
		# pati izleri: ıslak parlayan küçük halkalar
		st0["paw"] += dt
		if st0["paw"] > 0.11:
			st0["paw"] = 0.0
			_ripple(pj, pj.gp(p.global_position) + side * randf_range(-0.3, 0.3), 0.45, 0.6, {"rings": 1.0, "pool": 0.45})
	pr.on_tick = tick
	Sfx.play("thunder", c.global_position, 1.5, 0.6)


# ================================================================== RANTON: Raiun (Gök Gürültüsü Bulutu)
## 8 sn boyunca hedef bölgenin üstünde kabaran koyu cel kara bulut (kalın koyu kontur), içinde çatırdayan zikzak şimşekler,
## alt yüzü her çakışta camgöbeği aydınlanır; saniyede bir içindeki her düşmana kalın sıvı ışın iner,
## yerde yanık yıldız + ıslak halka kalır.
static func ikazuchi_raiun(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var hp: Vector3 = Jutsu._hand(c)
	_light(pj, hp, Color(0.6, 0.85, 1.0), 4.0, 8.0, 0.4)
	_halo(pj, hp + Vector3.UP * 0.5, Vector3.UP, 1.0, 0.5, 1.0)
	# --- c_ikazuchi_raiun
	var center: Vector3 = pj.gp(Jutsu._aim_ground(c, t, 10.0, 24.0))
	var top := center + Vector3.UP * 12.0
	var od: Array = _ellipsoid_offsets(22, 8.0, 1.2, 8.0, 3.4, 5.4)
	var cloud := _cloud(pj, top, od[0], od[1], CLOUD_DARK, CLOUD_DARK_B, 0.08, 4.0)
	var anchors := func() -> Array:
		var out := []
		for j in 4:
			out.append(top + Vector3(randf_range(-6, 6), randf_range(-1.2, 0.2), randf_range(-6, 6)))
		return out
	_crackle(pj, anchors, 3, 8.0, 0.06, 3.2)
	var drift := func(i: int, _k: float) -> void:
		_cloud_breathe(cloud, i * 0.1)
		if is_instance_valid(cloud):
			cloud.rotate_y(0.004)
		if randf() < 0.12:
			_cloud_flash(cloud, 0.7)
			_light(pj, top + Vector3(randf_range(-5, 5), -1.0, randf_range(-5, 5)), RAN_LIGHT, 5.0, 14.0, 0.15)
	var gone := func() -> void:
		_cloud_end(cloud, 0.8)
	pj.every(8.0, 0.1, drift, gone)
	var strike := func(_i: int, _k: float) -> void:
		for e in pj.enemies_near(c, center, 12.0):
			var a := top + Vector3(randf_range(-4, 4), -1.5, randf_range(-4, 4))
			var b: Vector3 = e.global_position + Vector3.UP
			_beam(pj, _liquid_curve(a, a.lerp(b, 0.5) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), b, 20, 0.4, randf() * TAU), 0.24, 0.07, 0.18, 0.3, {"r1": 0.3, "flow": 4.0})
			_bolt(pj, a, b, 0.05, 0.3)
			var g: Vector3 = pj.gp(b)
			_ripple(pj, g, 2.4, 1.6, {"rings": 2.0, "rays": 7.0, "pool": 0.35, "ink": STORM_INK})
			_droplets(pj, b, 10, 3.0, 7.0, Vector3.UP, 75.0)
			_cloud_flash(cloud, 1.0)
			pj.hit(c, b, 1.0, pj.inf(c, "ikazuchi_raiun", 0.35, {"knock": 2.0, "element": "ranton", "stun": 0.5}))
		Sfx.play("thunder", center, 1.0, 0.7)
	pj.every(8.0, 1.0, strike, Callable())


# ================================================================== RANTON: Kōsen (Bükülen Işın)
## İki elde topak; tek kalın ışın yukarı kemer çizip engellerin üstünden aşar ve hedefe dikine dalar; kemerden ıslak damlalar
## süzülür, iniş noktasında taç biçimli sıçrama + çok katlı halka.
static func ikazuchi_kosen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	for side in ["RightHand", "LeftHand"]:
		_attach_orb(pj, c, side, 0.24, 0.8)
	# --- c_ikazuchi_kosen
	var tt := pj.tg(c, t, 40.0)
	var a: Vector3 = Jutsu._hand(c)
	var b: Vector3 = tt.global_position + Vector3.UP if tt else a + Jutsu._aim(c, t) * 25.0
	var mid := (a + b) * 0.5 + Vector3.UP * (6.0 + a.distance_to(b) * 0.2)
	var pts := _bez(a, mid, b, 34)
	# hafif yılankavi: su gibi akış
	var sd := (b - a).cross(Vector3.UP)
	sd = sd.normalized() if sd.length() > 0.01 else Vector3.RIGHT
	for i in pts.size():
		var f := float(i) / float(pts.size() - 1)
		pts[i] = (pts[i] as Vector3) + sd * sin(f * TAU * 1.2) * 0.5 * sin(PI * f)
	_beam(pj, pts, 0.3, 0.14, 0.32, 0.3, {"r1": 0.34, "flow": 4.5, "sides": 10})
	_beam(pj, pts, 0.1, 0.1, 0.2, 0.2, {"tint": RAN_CORE, "sides": 6})
	# kemerden süzülen damlalar
	for j in 4:
		var dp: Vector3 = pts[8 + j * 5]
		_spray(pj, dp, _m_drop(), _liquid_mat(0.0), 5, 0.9, {"r": 0.3, "vmin": 0.0, "vmax": 0.6, "g": Vector3(0, -12, 0), "expl": 0.3, "align": true, "end_scale": 0.5})
	pj.hit(c, b, 1.6, pj.inf(c, "ikazuchi_kosen", 1.8, {"knock": 8.0, "kind": "heavy", "element": "ranton", "stun": 0.8, "hitstop": 0.08}))
	var g: Vector3 = pj.gp(b)
	_droplets(pj, g + Vector3.UP * 0.2, 22, 5.0, 10.0, Vector3.UP, 30.0)
	_ripple(pj, g, 3.0, 1.0, {"rings": 3.0, "pool": 0.4})
	_halo(pj, b, Vector3.UP, 1.6, 0.4, 1.0)
	_light(pj, b, Color(0.7, 0.9, 1.0), 6.0, 10.0, 0.4)
	Sfx.play("chidori", a, 1.9)


# ================================================================== RANTON: Arashi Kyū (Fırtına Küresi)
## Su ve şimşek karışık küre: sıvı yüzeyli çekirdek, çevresinde dönen damla halkası ve iki çapraz akış halkası, ardında
## ince ıslak iz; çarpınca sekiz kısa ışın yıldız gibi dışarı kıvrılır, yerde geniş halka.
static func ikazuchi_ranton_kyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt := pj.tg(c, t, 28.0)
	var hpos := pj.hand_pos(c, true)
	_spray(pj, hpos, _m_drop(), _liquid_mat(0.0), 12, 0.3, {"r": 1.0, "vmin": 0.0, "vmax": 0.2, "radial": -10.0, "g": Vector3.ZERO, "expl": 0.5, "align": true, "end_scale": 0.2})
	var go := func() -> void:
		if not pj.live(c):
			return
		var from := pj.hand_pos(c, true)
		var orb := Node3D.new()
		var core := _mi(_m_glow_ball(), _liquid_mat())
		core.scale = Vector3.ONE * 1.3
		orb.add_child(core)
		var halo := _mi(_m_glow_ball(), _glow_mat(Color(0.45, 0.9, 1.0, 0.45), 1.0, 2.0))
		halo.scale = Vector3.ONE * 2.2
		orb.add_child(halo)
		var spin := Node3D.new()
		orb.add_child(spin)
		var dm := _liquid_mat(0.0)
		for j in 7:
			var a := j * TAU / 7.0
			var dr := _mi(_m_drop(), dm)
			dr.position = Vector3(cos(a), sin(a * 2.0) * 0.15, sin(a)) * 1.0
			dr.scale = Vector3.ONE * 1.4
			spin.add_child(dr)
		for j in 2:
			var rg := _mi(_m_ring(), _glow_mat(Color(0.75, 1.0, 1.0, 0.85), 0.0, 2.0))
			rg.scale = Vector3.ONE * 1.6
			rg.rotation = Vector3(0.6 + j * 1.2, j * 1.4, 0)
			spin.add_child(rg)
		var boom := func(p, _h) -> void:
			for k in 8:
				var a := k * TAU / 8.0
				var e: Vector3 = p + Vector3(cos(a), randf_range(-0.3, 0.6), sin(a)) * 4.0
				_beam(pj, _liquid_curve(p, p.lerp(e, 0.5) + Vector3.UP * randf_range(0.3, 1.2), e, 10, 0.3, randf() * TAU), 0.14, 0.06, 0.12, 0.2, {"r1": 0.03, "sides": 6})
			_droplets(pj, p, 18, 4.0, 9.0, Vector3.UP, 90.0)
			_ripple(pj, pj.gp(p), 4.0, 0.9, {"rings": 3.0, "pool": 0.2})
			_light(pj, p, Color(0.6, 0.85, 1.0), 5.0, 12.0, 0.3)
			pj.hit(c, p, 4.0, pj.inf(c, "ikazuchi_ranton_kyu", 0.6, {"knock": 6.0, "kind": "heavy", "element": "ranton"}))
		var pr: Projectile = pj.shot(c, from, pj.aim_at(c, tt, from), 26.0, orb, pj.inf(c, "ikazuchi_ranton_kyu", 1.4, {"knock": 8.0, "kind": "heavy", "element": "ranton", "stun": 0.5}), tt, false, 1.6, boom)
		_follow_tube(pj, pr, 0.4, 0.03, 10, Vector3.ZERO, 5.0, 8)
		var sp := func(_p, dt) -> void:
			if is_instance_valid(spin):
				spin.rotate_y(dt * 9.0)
				spin.rotate_x(dt * 3.0)
		pr.on_tick = sp
	pj.after(0.3, go)
	Sfx.play("thunder", c.global_position, 1.3)


# ================================================================== RANTON: Kaminari Ryū (Şimşek Ejderi)
## Göğe kalkan elin üstünde küçük kara bulut düğümü çatırdar; içinden sıvı ışıktan ejder başı (çene, boynuz, bıyık, diş)
## doğar, kalın akışkan gövdesi kıvrılarak peşinden gelir; inişte geniş ıslak sıçrama ve parlayan çatlak damarları.
static func _dragon_head(s: float) -> Node3D:
	var k := s / 2.2
	var root := Node3D.new()
	var m := _liquid_mat()
	var b := MB.new()
	b.add("sphere", Vector3(0, 0, 0.1) * k, Vector3(1.0, 0.8, 1.1) * k, Color.WHITE, Vector3.ZERO, 12)
	b.add("box", Vector3(0, 0.0, -0.8) * k, Vector3(0.62, 0.38, 1.0) * k, Color.WHITE, Vector3(6, 0, 0))
	b.add("box", Vector3(0, -0.38, -0.66) * k, Vector3(0.5, 0.14, 0.9) * k, Color.WHITE, Vector3(-20, 0, 0))
	b.add("sphere", Vector3(0, 0.1, -1.28) * k, Vector3(0.52, 0.34, 0.3) * k, Color.WHITE, Vector3.ZERO, 8)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.3 * sx, 0.38, 0.4) * k, Vector3(0.16, 1.2, 0.16) * k, Color.WHITE, Vector3(72, 0, -14 * sx), 6)
		b.add("cone", Vector3(0.34 * sx, -0.05, -1.05) * k, Vector3(0.06, 1.4, 0.06) * k, Color.WHITE, Vector3(80, 0, 38 * sx), 5)
		b.add("box", Vector3(0.32 * sx, 0.22, -0.55) * k, Vector3(0.12, 0.06, 0.26) * k, Color.WHITE, Vector3(0, 20 * sx, 0))
		for j in 3:
			b.add("cone", Vector3(0.18 * sx, -0.22, -1.1 + j * 0.2) * k, Vector3(0.07, 0.18, 0.07) * k, Color.WHITE, Vector3(180, 0, 0), 4)
	for j in 4:
		b.add("cone", Vector3(0, 0.38 - j * 0.02, 0.1 + j * 0.3) * k, Vector3(0.12, 0.5 - j * 0.07, 0.1) * k, Color.WHITE, Vector3(55, 0, 0), 5)
	root.add_child(_mi(b.build(), m))
	return root


static func ikazuchi_kaminari_ryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt := pj.tg(c, t, 32.0)
	var at := c.global_position + Vector3.UP * 7.0
	var od: Array = _ellipsoid_offsets(9, 2.2, 0.6, 2.2, 1.6, 2.4)
	var knot := _cloud(pj, at, od[0], od[1], CLOUD_DARK, CLOUD_DARK_B, 0.05, 3.0)
	_crackle(pj, func() -> Array: return [at + Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.6), randf_range(-1.5, 1.5))], 3, 0.8, 0.04, 1.8)
	var flick := func(_i: int, _k: float) -> void:
		_cloud_flash(knot, 1.0)
	pj.every(0.6, 0.15, flick, Callable())
	_light(pj, at, Color(0.6, 0.85, 1.0), 6.0, 20.0, 0.9)
	var close := func() -> void:
		_cloud_end(knot, 0.3)
	pj.after(0.6, close)
	_beam(pj, _liquid_curve(pj.hand_pos(c, true), at.lerp(pj.hand_pos(c, true), 0.5) + Vector3.RIGHT * 0.8, at, 14, 0.4, 0.0), 0.1, 0.15, 0.15, 0.2, {"r1": 0.05})
	var go := func() -> void:
		if not pj.live(c):
			return
		var head := Node3D.new()
		head.add_child(_dragon_head(2.2))
		var glow := _mi(_m_glow_ball(), _glow_mat(Color(0.45, 0.9, 1.0, 0.5), 1.0, 2.5))
		glow.scale = Vector3.ONE * 3.0
		glow.position.z = 0.6
		head.add_child(glow)
		var land := func(p, _h) -> void:
			var g: Vector3 = pj.gp(p)
			_droplets(pj, p, 28, 5.0, 12.0, Vector3.UP, 85.0)
			_ripple(pj, g, 5.5, 1.4, {"rings": 3.0, "pool": 0.35})
			_ran_fissure(pj, g, 6.0, 2.6)
			_bolt(pj, p + Vector3.UP * 0.5, g + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 0.06, 0.35)
			_light(pj, p, RAN_LIGHT, 7.0, 14.0, 0.5)
		var pr: Projectile = pj.shot(c, at, pj.aim_at(c, tt, at), 24.0, head, pj.inf(c, "ikazuchi_kaminari_ryu", 2.4, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "element": "ranton", "stun": 1.0}), tt, false, 2.0, land)
		_follow_tube(pj, pr, 0.75, 0.08, 18, Vector3.ZERO, 3.0, 10)
		var st0 := {"t": 0.0}
		var sway := func(p, dt) -> void:
			st0["t"] += dt
			var v: Vector3 = p.vel.normalized() if p.vel.length() > 0.1 else Vector3.FORWARD
			var sd := v.cross(Vector3.UP).normalized()
			p.global_position += (sd * cos(st0["t"] * 7.0) * 0.35 + Vector3.UP * sin(st0["t"] * 5.0) * 0.2)
		pr.on_tick = sway
	pj.after(0.5, go)
	Sfx.play("thunder", c.global_position, 0.8)


# ================================================================== RANTON: Raiunkūha (Gök Gürültüsü Bulutu İç Dalgası)
## ref: Darui — kişinin çevresinde kabarık, kalın koyu konturlu kömür rengi cel bulut halkası; içinde sürekli çatırdayan
## beyaz-camgöbeği zikzak şimşekler. Yaklaşan zikzak şimşekle itilir; mermiler bulutta söner (kısa çatırtı);
## arada bir buluttan en yakın düşmana sıvı ışın fırlar.
static func ranton_raiunkuha(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	var R := 3.4
	Sfx.play("thunder", c.global_position, 0.8, 0.8)
	var offs := []
	var sizes := []
	for k in 20:
		var a := k * TAU / 20.0 + randf_range(-0.08, 0.08)
		offs.append(Vector3(cos(a) * R, randf_range(-0.9, 1.0), sin(a) * R))
		sizes.append(randf_range(1.5, 2.3))
	for k in 8:
		var a := randf() * TAU
		offs.append(Vector3(cos(a) * R * 1.05, randf_range(1.0, 1.7), sin(a) * R * 1.05))
		sizes.append(randf_range(1.1, 1.6))
	var cloud := _cloud(pj, c.global_position + Vector3.UP * 1.2, offs, sizes, CLOUD_DARK, CLOUD_DARK_B, 0.07, 3.2)
	var ring_pts := func() -> Array:
		var out := []
		if is_instance_valid(c):
			var o: Vector3 = c.global_position + Vector3.UP * 1.2
			for j in 3:
				var a := randf() * TAU
				out.append(o + Vector3(cos(a) * R, randf_range(-0.6, 0.8), sin(a) * R))
		return out
	_crackle(pj, ring_pts, 3, 8.0, 0.045, 1.8)
	var cloud_tick := func(i: int, _k: float) -> void:
		if not pj.live(c):
			return
		var o: Vector3 = c.global_position + Vector3.UP * 1.2
		if is_instance_valid(cloud):
			cloud.global_position = o
			cloud.rotate_y(0.02)
			_cloud_breathe(cloud, i * 0.1)
		if i % 6 == 0:
			_cloud_flash(cloud, 0.8)
			_light(pj, o + Vector3(randf_range(-R, R), 0.2, randf_range(-R, R)), Color(0.55, 0.8, 1.0), 4.0, 7.0, 0.12)
		# çevre: yaklaşan çarpılır, geri itilir; fırlatılanlar bulutta söner
		if i % 5 == 0:
			for e in pj.enemies_near(c, c.global_position, R + 0.9):
				var b: Vector3 = e.global_position + Vector3.UP
				_bolt(pj, o + (b - o).normalized() * R * 0.8, b, 0.05, 0.22)
				e.take_hit(pj.inf(c, "ranton_raiunkuha", 0.25, {"knock": 13.0, "kind": "heavy", "element": "ranton", "stun": 0.4}))
			for p in pj.get_tree().get_nodes_in_group("projectiles"):
				if is_instance_valid(p) and p.get("shooter") != c and p.global_position.distance_to(o) < R + 0.7:
					var pp: Vector3 = p.global_position
					_crackle(pj, func() -> Array: return [pp], 3, 0.2, 0.04, 1.0)
					_light(pj, pp, RAN_LIGHT, 3.0, 4.0, 0.15)
					p.queue_free()
		# şimşek atışı: en yakın düşmana buluttan
		if i % 12 == 6:
			var best: Node3D = null
			var bd := 18.0
			for e in pj.enemies_near(c, c.global_position, 18.0):
				var dd: float = e.global_position.distance_to(c.global_position)
				if dd < bd:
					bd = dd
					best = e
			if best:
				var b: Vector3 = best.global_position + Vector3.UP
				var dir := (b - o)
				dir.y = 0.0
				var a := o + dir.normalized() * R
				_beam(pj, _liquid_curve(a, a.lerp(b, 0.5) + Vector3.UP * randf_range(0.8, 2.0), b, 18, 0.4, randf() * TAU), 0.2, 0.08, 0.14, 0.22, {"r1": 0.14, "flow": 4.0})
				_bolt(pj, a, b, 0.04, 0.25)
				_droplets(pj, b, 10, 3.0, 7.0, Vector3.UP, 80.0)
				_ripple(pj, pj.gp(b), 1.8, 0.7, {"rings": 2.0, "pool": 0.3})
				best.take_hit(pj.inf(c, "ranton_raiunkuha", 0.6, {"knock": 4.0, "kind": "heavy", "element": "ranton", "stun": 0.5}))
				Sfx.play("thunder", b, 1.2, 0.6)
	var fin := func() -> void:
		_cloud_end(cloud, 0.6)
	pj.every(8.0, 0.1, cloud_tick, fin)


# ================================================================== JINTON yapı taşları
static func _m_jcube() -> Mesh:
	return _cached("jcube", func():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		return bm)


static func _m_jsphere() -> Mesh:
	return _cached("jsphere", func():
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 40
		s.rings = 20
		return s)


static func _m_jcone() -> Mesh:
	return _cached("jcone", func():
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.0
		cm.height = 2.0
		cm.radial_segments = 24
		cm.rings = 8
		return cm)


static func _m_jcyl() -> Mesh:
	return _cached("jcyl", func():
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 2.0
		cm.radial_segments = 48
		cm.rings = 6
		return cm)


static func _m_mote() -> Mesh:
	return _cached("mote", func():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.06
		return bm)


static func _m_chip() -> Mesh:
	return _cached("chip", func():
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.26, 0.18, 0.22), STONE, Vector3(18, 30, 9))
		b.add("box", Vector3(0.05, 0.06, 0.02), Vector3(0.14, 0.12, 0.13), STONE.darkened(0.2), Vector3(-20, 10, 35))
		return b.build())


## Jinton kabuğu: kind 0 küp (yarı boy 0.5), 1 küre / 2 koni / 3 silindir (yarı boy 1)
static func _jin_shell(kind: int, lines := 5.0, edge_w := 0.035) -> MeshInstance3D:
	var mesh: Mesh = _m_jcube()
	var half := Vector3.ONE * 0.5
	if kind == 1:
		mesh = _m_jsphere()
		half = Vector3.ONE
	elif kind == 2:
		mesh = _m_jcone()
		half = Vector3.ONE
	elif kind == 3:
		mesh = _m_jcyl()
		half = Vector3.ONE
	return _mi(mesh, _jin_mat(kind, half, lines, edge_w))


static func _jin_glow(x, v: float) -> void:
	if is_instance_valid(x):
		(x.material_override as ShaderMaterial).set_shader_parameter("glow", v)


## Beyaz-sıcak çekirdek: yumuşak ışıma küresi + iki ince çapraz parıltı + ışık
static func _jin_core(r: float, energy := 3.0) -> Node3D:
	var root := Node3D.new()
	var ball := _mi(_m_glow_ball(), _glow_mat(Color(1, 1, 1, 1), 1.0, 2.0))
	ball.scale = Vector3.ONE * r
	root.add_child(ball)
	var inner := _mi(_m_glow_ball(), _glow_mat(Color(1, 1, 1, 1), 0.3, 2.0))
	inner.scale = Vector3.ONE * r * 0.35
	root.add_child(inner)
	for j in 2:
		var fl := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(r * 3.2, r * 0.06)
		fl.mesh = qm
		fl.material_override = _glow_mat(Color(0.9, 0.96, 1.0, 0.8), 0.0, 2.0)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fl.rotation.z = PI * 0.5 * j + PI * 0.25
		root.add_child(fl)
	var l := OmniLight3D.new()
	l.light_color = Color(0.95, 0.98, 1.0)
	l.light_energy = energy
	l.omni_range = r * 6.0 + 3.0
	l.shadow_enabled = false
	root.add_child(l)
	return root


## Moleküllerine ayrılan madde: küçük küp tanecikleri yükselir, döner, küçülerek kaybolur
static func _motes(pj: PathJutsu, pos: Vector3, r: float, n: int, life: float, o := {}) -> CPUParticles3D:
	var q := {"r": r, "vmin": float(o.get("vmin", 0.3)), "vmax": float(o.get("vmax", 1.6)), "g": o.get("g", Vector3(0, 0.9, 0)),
		"damp": 0.8, "spin": 220.0, "smin": 0.6, "smax": 1.6, "end_scale": 0.0, "expl": float(o.get("expl", 0.85)),
		"c0": JIN_MOTE, "c1": Color(0.7, 0.75, 0.82, 0.0), "hold": 0.5, "radial": float(o.get("radial", 0.0)),
		"dir": o.get("dir", Vector3.UP), "spread": float(o.get("spread", 180.0)), "one_shot": bool(o.get("one_shot", true))}
	if o.has("parent"):
		q["parent"] = o["parent"]
	return _spray(pj, pos, _m_mote(), _mote_mat(), n, life, q)


## Kenarda genişleyen ince silinme halkası (axis = halkanın normali)
static func _jin_ring(pj: PathJutsu, pos: Vector3, axis: Vector3, r0: float, r1: float, dur: float) -> void:
	var m := _glow_mat(Color(0.9, 0.96, 1.0, 0.9), 0.0, 2.5)
	var x := _mi(_m_ring(), m)
	_put(pj, x, pos)
	x.global_basis = _basis_y(axis)
	x.scale = Vector3(r0 * 2.0, 1.0, r0 * 2.0)
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3(r1 * 2.0, 1.0, r1 * 2.0), dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_out(x, m, dur * 0.35, dur * 0.65)


## Silinmiş zemin: pürüzsüz soluk disk, keskin beyaz kenar halkası; yavaş söner
static func _jin_scar(pj: PathJutsu, pos: Vector3, r: float, dur: float) -> void:
	var m := _ripple_mat(Color(0.92, 0.95, 1.0), Color(0.62, 0.66, 0.72), 1.0, 0.0)
	m.set_shader_parameter("pool_a", 0.28)
	m.set_shader_parameter("pool_r", 1.0)
	m.set_shader_parameter("prog", 0.96)
	var x := _mi(_m_disc(), m)
	_put(pj, x, pos + Vector3.UP * 0.04)
	x.scale = Vector3.ONE * r
	_fade_out(x, m, dur * 0.5, dur * 0.5)


## Hazırlık: el önünde tekniğin kendi şeklinde küçük kabuk döner, çekirdek büyür, toz tanecikleri içe çekilir
static func _jin_prep(pj: PathJutsu, c: Node3D, kind: int, dur: float) -> void:
	var root := Node3D.new()
	c.add_child(root)
	root.position = Vector3(0, 1.3, 0.55)
	var shell := _jin_shell(kind, 3.0, 0.06)
	var sz := 0.45 if kind == 0 else 0.25
	if kind == 2:
		shell.rotation.x = -PI * 0.5
		shell.scale = Vector3(0.22, 0.32, 0.22)
	elif kind == 3:
		shell.scale = Vector3(0.24, 0.26, 0.24)
	else:
		shell.scale = Vector3.ONE * sz
	var spin := Node3D.new()
	root.add_child(spin)
	spin.add_child(shell)
	var core := _jin_core(0.12, 1.5)
	root.add_child(core)
	core.scale = Vector3.ONE * 0.3
	_motes(pj, root.global_position, 1.2, 24, minf(dur, 0.6), {"vmin": 0.0, "vmax": 0.1, "radial": -5.0, "g": Vector3.ZERO, "expl": 0.4, "parent": root})
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spin, "rotation", Vector3(0.7, 1.6, 0.35), dur)
	tw.tween_property(core, "scale", Vector3.ONE * 1.4, dur).set_ease(Tween.EASE_IN)
	var gf := func(v: float) -> void:
		_jin_glow(shell, v)
	tw.tween_method(gf, 0.0, 0.8, dur)
	tw.chain().tween_callback(root.queue_free)


## Toz silme mekaniği (_atomize ile aynı: her düşmana vuruş, yapı hasarı, sarsıntı) + kendi taneciklerimiz
static func _jin_erase(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, id: String, mul: float) -> void:
	for e in pj.enemies_near(c, pos, r):
		pj.hit(c, e.global_position + Vector3.UP, 1.0, pj.inf(c, id, mul, {"knock": 1.0, "kind": "heavy", "hitstop": 0.1}))
		_motes(pj, e.global_position + Vector3.UP, 0.5, 40, 1.3, {"vmin": 0.4, "vmax": 2.2})
	WorldDamage.impact(pos, r, {"dmg": 260.0, "kind": "heavy"})
	_motes(pj, pos, r * 0.8, int(clampf(r * 18.0, 40.0, 160.0)), 1.8, {"vmin": 0.5, "vmax": 3.0})
	if Game.world:
		Game.world.env.screen_flash(0.2)
	pj.shake(0.9)


## Taş sütun (Ryōiki): pürüzlü kaya + sivri tepe, yerden fırlar, sonra çöker
static func _stone_pillar(pj: PathJutsu, p: Vector3, h: float, w: float, tilt: Vector3, dur: float) -> MeshInstance3D:
	var b := MB.new()
	b.add("crag", Vector3(0, h * 0.5, 0), Vector3(w, h, w), STONE, Vector3.ZERO, randi() % 6)
	b.add("cone", Vector3(0, h * 1.02, 0), Vector3(w * 0.5, h * 0.22, w * 0.5), STONE.lightened(0.12), Vector3.ZERO, 6)
	var x := _mi(b.build(), _stone_mat())
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_put(pj, x, p)
	x.rotation_degrees = tilt
	x.scale = Vector3(1, 0.05, 1)
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(x, "scale", Vector3(1, 0.02, 1), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(x.queue_free)
	return x


static func _chips(pj: PathJutsu, p: Vector3, n: int, spd: float) -> void:
	_spray(pj, p, _m_chip(), _stone_mat(), n, 1.1, {"r": 0.6, "dir": Vector3.UP, "spread": 60.0, "vmin": spd * 0.4, "vmax": spd, "g": Vector3(0, -18, 0),
		"spin": 300.0, "end_scale": 0.7, "c0": Color(1, 1, 1, 1), "c1": Color(1, 1, 1, 1), "hold": 0.9})


## Taş golem yumruğu: avuç + dört boğum + başparmak
static func _stone_fist(s: float) -> MeshInstance3D:
	var b := MB.new()
	b.add("box", Vector3(0, 0, 0), Vector3(0.9, 0.75, 0.8) * s, STONE, Vector3(4, 0, 3))
	for j in 4:
		b.add("box", Vector3(-0.33 + j * 0.22, 0.05, -0.48) * s, Vector3(0.2, 0.3, 0.3) * s, STONE.lightened(0.06), Vector3(randf_range(-6, 6), 0, 0))
	b.add("box", Vector3(0.5, -0.1, -0.2) * s, Vector3(0.22, 0.26, 0.45) * s, STONE.darkened(0.08), Vector3(0, -20, 10))
	b.add("cyl", Vector3(0, 0.6, 0.15) * s, Vector3(0.6, 0.7, 0.6) * s, STONE.darkened(0.12), Vector3.ZERO, 7)
	var x := _mi(b.build(), _stone_mat())
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return x


## Taş çatlakları (koyu yarıklar) — Ryōiki yumruğu
static func _stone_cracks(pj: PathJutsu, pos: Vector3, r: float, dur: float) -> void:
	var b := MB.new()
	for k in 9:
		var ang := k * TAU / 9.0 + randf_range(-0.25, 0.25)
		var cur := Vector3.ZERO
		for s in 4:
			var nxt := cur + Vector3(cos(ang), 0, sin(ang)) * r * randf_range(0.14, 0.26)
			var xf := _seg_xf(cur, nxt, 0.22 * (1.0 - s * 0.2))
			b.add_xf("box", Transform3D(xf.basis.scaled(Vector3(1, 0.08, 1)), xf.origin), STONE_INK)
			cur = nxt
			ang += randf_range(-0.5, 0.5)
	var m := _flat_mat(Color(1, 1, 1, 0.9))
	var x := _mi(b.build(), m)
	_put(pj, x, pos + Vector3.UP * 0.04)
	var tw := x.create_tween()
	tw.tween_interval(dur * 0.6)
	tw.tween_property(m, "albedo_color:a", 0.0, dur * 0.4)
	tw.tween_callback(x.queue_free)


# ================================================================== JINTON: Genkai Hakuri no Jutsu — Ryōiki
## Altı taş sütun hedefin çevresinden çapraz fırlar, taş golem yumruğu yay çizerek iner (çatlak + kaya parçası);
## sonra hedefte kanonik Toz KÜPÜ: keskin beyaz kenarlı yarı saydam küp patlarcasına açılır, içinde beyaz-sıcak çekirdek
## parlar, içindeki her şey (sütunlar dahil) taneciklere ayrılarak silinir; yerde pürüzsüz silinmiş iz kalır.
static func jinton_genkai_hakuri_ryoiki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.8)
	var tt := pj.tg(c, t, 20.0)
	var d := pj._face(c, tt)
	var cen: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 9.0)
	Sfx.play("earth", cen, 0.8)
	var pillars := []
	for k in 6:
		var kk := k
		var rise := func() -> void:
			var a := kk * TAU / 6.0 + 0.4
			var p: Vector3 = pj.gp(cen + Vector3(cos(a), 0, sin(a)) * 2.2)
			pillars.append(_stone_pillar(pj, p, randf_range(3.2, 4.6), 1.1, Vector3(-sin(a) * 16.0, 0, cos(a) * 16.0), 1.6))
			_chips(pj, p, 6, 7.0)
			if pj.live(c):
				pj.hit(c, p + Vector3.UP, 1.9, pj.inf(c, "jinton_genkai_hakuri_ryoiki", 0.15, {"knock": 0.0, "launch": 2.0, "kind": "heavy", "element": "doton"}))
		pj.after(0.1 + k * 0.07, rise)
	# golemin yumruğu: yandan yükselir, hedefin üstüne iner
	var fist_go := func() -> void:
		var from: Vector3 = pj.gp(cen - d * 5.0) + Vector3.UP * 0.5
		var fist := _stone_fist(3.0)
		_put(pj, fist, from)
		_chips(pj, from, 10, 8.0)
		var arc := func(_i: int, k: float) -> void:
			if is_instance_valid(fist):
				fist.global_position = from.lerp(cen + Vector3.UP * 1.2, k) + Vector3.UP * sin(k * PI) * 5.0
				fist.rotation.x = -k * 1.2
		var slam := func() -> void:
			if is_instance_valid(fist):
				_chips(pj, fist.global_position, 16, 11.0)
				fist.queue_free()
			_stone_cracks(pj, cen, 6.0, 5.0)
			if pj.live(c):
				pj.hit(c, cen + Vector3.UP, 3.2, pj.inf(c, "jinton_genkai_hakuri_ryoiki", 0.7, {"knock": 0.0, "kind": "heavy", "element": "doton", "stun": 1.0, "hitstop": 0.1}))
			pj.shake(0.9)
			Sfx.play("boom", cen, 0.8)
		pj.every(0.4, 1.0 / 60.0, arc, slam)
	pj.after(0.6, fist_go)
	_jin_prep(pj, c, 0, 1.5)
	var finish := func() -> void:
		if not pj.live(c):
			return
		var mid := cen + Vector3.UP * 3.5
		var cube := _jin_shell(0, 6.0, 0.03)
		_put(pj, cube, mid)
		cube.rotation.y = randf() * TAU
		cube.scale = Vector3.ONE * 0.3
		var core := _jin_core(1.0, 6.0)
		_put(pj, core, mid)
		core.scale = Vector3.ONE * 0.2
		var tw := cube.create_tween()
		tw.tween_property(cube, "scale", Vector3.ONE * 7.2, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		var hit_now := func() -> void:
			_jin_erase(pj, c, cen + Vector3.UP * 1.5, 3.6, "jinton_genkai_hakuri_ryoiki", 1.8)
			for pl in pillars:
				if is_instance_valid(pl):
					_motes(pj, (pl as Node3D).global_position + Vector3.UP * 2.0, 1.2, 40, 1.4)
					var pt := (pl as Node3D).create_tween()
					pt.tween_property(pl, "scale", Vector3(0.02, 0.02, 0.02), 0.18)
					pt.tween_callback((pl as Node3D).queue_free)
			_jin_ring(pj, cen + Vector3.UP * 0.1, Vector3.UP, 3.6, 6.5, 0.5)
			_jin_scar(pj, cen, 3.8, 4.0)
		tw.tween_callback(hit_now)
		var gf := func(v: float) -> void:
			_jin_glow(cube, v)
		tw.tween_method(gf, 0.0, 1.0, 0.3)
		tw.tween_property(cube, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
		tw.tween_callback(cube.queue_free)
		var ct := core.create_tween()
		ct.tween_property(core, "scale", Vector3.ONE * 3.2, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ct.tween_property(core, "scale", Vector3.ONE * 0.01, 0.25)
		ct.tween_callback(core.queue_free)
		Sfx.play("genjutsu", cen, 1.5)
	pj.after(1.3, finish)


# ================================================================== JINTON: Sōsai (Toz Kalkanı)
## Önünde iç içe iki küp: dış küp yavaşça yuvarlanır, iç küp ters döner, ortada beyaz-sıcak çekirdek; gelen teknikler küpe
## değince keskin bir halka çakıp taneciklere ayrılır; içine giren düşman dağılır.
static func jinton_sosai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var root := Node3D.new()
	_put(pj, root, c.global_position + Vector3.UP * 1.3 + c.face_dir() * 1.9)
	var cube := _jin_shell(0, 4.0, 0.045)
	root.add_child(cube)
	var inner := _jin_shell(0, 2.0, 0.07)
	inner.scale = Vector3.ONE * 0.5
	cube.add_child(inner)
	var core := _jin_core(0.22, 2.5)
	root.add_child(core)
	root.scale = Vector3.ONE * 0.3
	Sfx.play("genjutsu", c.global_position, 2.0)
	var guard := func(i: int, k: float) -> void:
		if not is_instance_valid(root) or not pj.live(c):
			return
		var o: Vector3 = c.global_position + Vector3.UP * 1.3 + c.face_dir() * 1.9
		root.global_position = o
		cube.rotation = Vector3(k * 5.0, k * 8.0, 0)
		inner.rotation = Vector3(-k * 9.0, -k * 6.0, k * 4.0)
		root.scale = Vector3.ONE * 2.6 * minf(1.0, k * 8.0) * minf(1.0, (1.0 - k) * 8.0 + 0.05)
		_jin_glow(cube, 0.15 + 0.1 * sin(k * 40.0))
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c and p.global_position.distance_to(o) < 2.8:
				var pp: Vector3 = p.global_position
				_motes(pj, pp, 0.35, 22, 0.9, {"vmin": 0.5, "vmax": 2.5})
				_jin_ring(pj, pp, (pp - o).normalized(), 0.1, 0.9, 0.3)
				_jin_glow(cube, 0.9)
				p.queue_free()
		if i % 16 == 8:
			for e in pj.enemies_near(c, o, 2.2):
				_jin_erase(pj, c, e.global_position + Vector3.UP, 1.0, "jinton_sosai", 0.45)
	var end := func() -> void:
		if is_instance_valid(root):
			_motes(pj, root.global_position, 0.9, 40, 1.0)
			root.queue_free()
	pj.every(2.5, 1.0 / 40.0, guard, end)


# ================================================================== JINTON: Kyū (Toz Küresi)
## Yavaş ilerleyen yarı saydam küre: parlak dış çizgi, kayan enlem halkaları, ekvator çizgisi, içte beyaz-sıcak çekirdek;
## ardında sürekli dağılan tanecik izi, geçtiği zeminde pürüzsüz silinmiş daireler kalır.
static func jinton_kyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d := pj.fwd(c, t)
	_jin_prep(pj, c, 1, 0.7)
	Sfx.play("genjutsu", c.global_position, 1.4)
	var go := func() -> void:
		if not pj.live(c):
			return
		var ball := Node3D.new()
		var shell := _jin_shell(1, 6.0, 0.03)
		shell.scale = Vector3.ONE * 2.0
		ball.add_child(shell)
		ball.add_child(_jin_core(0.9, 4.0))
		var from := c.global_position + Vector3.UP * 2.2 + d * 3.0
		var on_hit := func(p, _h) -> void:
			_motes(pj, p, 0.6, 40, 1.1, {"vmin": 1.0, "vmax": 4.0})
		var pr: Projectile = pj.shot(c, from, d, 8.0, ball, pj.inf(c, "jinton_kyu", 2.8, {"knock": 1.0, "kind": "heavy", "element": "jinton", "hitstop": 0.08}), null, true, 3.6, on_hit)
		if pr:
			pr.radius = 2.1
			pr.blockable = false
			_motes(pj, ball.global_position, 1.8, 40, 1.2, {"one_shot": false, "expl": 0.0, "vmin": 0.1, "vmax": 0.8, "parent": ball})
			shell.scale = Vector3.ONE * 0.2
			var gt := shell.create_tween()
			gt.tween_property(shell, "scale", Vector3.ONE * 2.0, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			var acc := {"t": 0.0}
			var tick := func(p, dt) -> void:
				acc["t"] += dt
				if is_instance_valid(shell):
					shell.rotate_y(dt * 0.8)
				for q in pj.get_tree().get_nodes_in_group("projectiles"):
					if q != p and is_instance_valid(q) and q.get("shooter") != c and q.global_position.distance_to(p.global_position) < 2.5:
						_motes(pj, q.global_position, 0.3, 18, 0.8, {"vmin": 0.5, "vmax": 2.0})
						_jin_glow(shell, 0.8)
						q.queue_free()
				if acc["t"] > 0.4:
					acc["t"] = 0.0
					WorldDamage.impact(p.global_position, 2.2, {"dmg": 260.0, "kind": "heavy"})
					_jin_scar(pj, pj.gp(p.global_position), 2.0, 2.4)
					_jin_glow(shell, 0.0)
			pr.on_tick = tick
	pj.after(0.6, go)


# ================================================================== JINTON: Sen (Toz Konisi)
## El önünde küçük koni hızla döner; sonra kalem inceliğinde, uca doğru daralan 30 m'lik keskin kenarlı koni ışın:
## boyunca kayan halka çizgileri, dipte beyaz-sıcak parlama; değdiği her hedefte iğne deliği kadar silinme + ince halka.
static func jinton_sen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt := pj.tg(c, t, 30.0)
	_jin_prep(pj, c, 2, 0.24)
	var go := func() -> void:
		if not pj.live(c):
			return
		var a := pj.hand_pos(c)
		var d := pj.aim_at(c, tt if pj.live(tt) else null, a)
		var cone := _jin_shell(2, 60.0, 0.05)
		var m: ShaderMaterial = cone.material_override
		m.set_shader_parameter("scroll", 6.0)
		_put(pj, cone, a + d * 15.0)
		cone.global_basis = _basis_y(d)
		cone.scale = Vector3(0.02, 15.0, 0.02)
		var tw := cone.create_tween()
		tw.tween_property(cone, "scale", Vector3(0.24, 15.0, 0.24), 0.06).set_ease(Tween.EASE_OUT)
		var gf := func(v: float) -> void:
			_jin_glow(cone, v)
		tw.tween_method(gf, 1.0, 0.3, 0.12)
		tw.tween_property(cone, "scale", Vector3(0.01, 15.0, 0.01), 0.15).set_ease(Tween.EASE_IN)
		tw.tween_callback(cone.queue_free)
		var flare := _jin_core(0.3, 3.0)
		_put(pj, flare, a)
		var ft := flare.create_tween()
		ft.tween_property(flare, "scale", Vector3.ONE * 0.05, 0.25).set_ease(Tween.EASE_IN)
		ft.tween_callback(flare.queue_free)
		_jin_ring(pj, a + d * 0.3, d, 0.1, 0.6, 0.25)
		for e in pj.enemies_near(c, a + d * 15.0, 17.0):
			var rel: Vector3 = e.global_position + Vector3.UP - a
			var along := rel.dot(d)
			if along > 0.0 and along < 30.0 and (rel - d * along).length() < 1.1:
				var o: Vector3 = e.global_position + Vector3.UP
				_motes(pj, o, 0.2, 18, 0.9, {"vmin": 1.0, "vmax": 3.0, "dir": d, "spread": 35.0})
				_jin_ring(pj, a + d * along, d, 0.05, 0.5, 0.3)
				e.take_hit(pj.inf(c, "jinton_sen", 2.7, {"knock": 2.0, "kind": "heavy", "element": "jinton", "armor_break": 0.3, "unblockable": true}))
		Sfx.play("genjutsu", a, 2.4)
	pj.after(0.22, go)


# ================================================================== JINTON: Entō (Toz Silindiri)
## Ellerin arasında küçük silindir döner; gökten 14 m yarıçaplı dev yarı saydam silindir iner (alt ve üst kenar daireleri
## keskin beyaz, gövdede aşağı akan halka çizgileri), yere değince içi beyaz-sıcak dolar, tüm alan taneciklere ayrılır,
## zeminde geniş halka yayılır ve pürüzsüz silinmiş daire uzun süre kalır.
static func jinton_ento(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_jin_prep(pj, c, 3, 0.9)
	# --- c_jinton_ento
	var center: Vector3 = pj.gp(Jutsu._aim_ground(c, t, 18.0, 40.0))
	var cyl := _jin_shell(3, 14.0, 0.02)
	var m: ShaderMaterial = cyl.material_override
	m.set_shader_parameter("scroll", -1.5)
	m.set_shader_parameter("near", 5.0)
	_put(pj, cyl, center + Vector3.UP * 60.0)
	cyl.scale = Vector3(14.0, 20.0, 14.0)
	var tw := cyl.create_tween()
	tw.tween_property(cyl, "global_position", center + Vector3.UP * 15.0, 0.5).set_ease(Tween.EASE_IN)
	var land := func() -> void:
		_jin_erase(pj, c, center + Vector3.UP * 2.0, 14.0, "jinton_ento", 3.5)
		_jin_ring(pj, center + Vector3.UP * 0.2, Vector3.UP, 14.0, 26.0, 0.5)
		_jin_ring(pj, center + Vector3.UP * 0.2, Vector3.UP, 13.0, 15.0, 0.8)
		_jin_scar(pj, center, 14.0, 6.0)
		var core := _jin_core(3.0, 8.0)
		_put(pj, core, center + Vector3.UP * 3.0)
		var ct := core.create_tween()
		ct.tween_property(core, "scale", Vector3.ONE * 3.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ct.tween_property(core, "scale", Vector3.ONE * 0.01, 0.3)
		ct.tween_callback(core.queue_free)
		_light(pj, center + Vector3.UP * 4.0, Color(0.95, 0.98, 1.0), 8.0, 40.0, 0.9)
	tw.tween_callback(land)
	var gf := func(v: float) -> void:
		_jin_glow(cyl, v)
	tw.tween_method(gf, 0.0, 0.8, 0.4)
	tw.tween_property(cyl, "scale", Vector3(0.01, 20.0, 0.01), 0.3)
	tw.tween_callback(cyl.queue_free)
	pj.busy(c, 1.0)
	Sfx.play("genjutsu", c.global_position, 1.5)
