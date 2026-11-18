class_name NinjutsuFXD
extends RefCounted
## Genel ninjutsu grubu D: senbon / şuriken hileleri, sis suikastı, Altı Yol Yin-Yang, Katsuyu bölünmesi, Rasengan türevleri,
## dönüşüm şakaları, ruh / spor / ikame beden teknikleri.
## Her tekniğin görüntüsü bu dosyada sıfırdan üretilir (kendi cel / kontur / sarmal / sis / hayalet / çizgi gölgelendiricileri,
## kendi parça yapı taşları). Oynanış ana ağaçtaki işleyicilerden satır satır taşındı; gerçek sistemler (mermi, yanıltıcı kopya,
## Katsuyu parça modeli, Henge kılığı, buff, iyileşme, chakra emme) olduğu gibi kullanılır — yalnız görünüş yeni.
## Okunurluk: tüm gölgelendiricilerde kameraya yakın kısım yumuşakça söner (near); büyük kütlelerde 6–8 m.

const INK := Color(0.06, 0.05, 0.08, 1.0)
const STEEL := Color(0.78, 0.8, 0.86, 1.0)
const DARK_STEEL := Color(0.2, 0.21, 0.25, 1.0)
const SHADOW := Color(0.05, 0.05, 0.08, 1.0)
const RAS_BLUE := Color(0.55, 0.8, 1.0, 1.0)
const GOLD := Color(1.0, 0.85, 0.35, 1.0)
const YIN := Color(0.62, 0.48, 0.95, 1.0)
const SLUG_W := Color(0.94, 0.96, 0.98, 1.0)
const SLUG_B := Color(0.12, 0.45, 0.62, 1.0)
const PINK := Color(1.0, 0.62, 0.8, 1.0)
const MIST := Color(0.9, 0.92, 0.95, 1.0)
const SKIN := Color(0.93, 0.8, 0.66, 1.0)
const COTTON := Color(0.97, 0.97, 0.95, 1.0)

static var _sh := {}
static var _cache := {}

# ================================================================== gölgelendiriciler
## Cel yüzey: köşe rengi × tint, sabit ışığa göre iki ton, isteğe bağlı parlak vurgu; kameraya yakın söner.
const CEL_SHADER := """
shader_type spatial;
render_mode unshaded, CULLMODE, depth_draw_always, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float shade_k = 0.72;
uniform float hi = 0.0;
uniform float fade = 1.0;
uniform float near = 1.5;

varying vec3 wnrm;

void vertex() {
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wnrm);
	if (!FRONT_FACING) {
		n = -n;
	}
	float l = dot(n, normalize(vec3(0.35, 1.0, 0.25)));
	vec3 c = tint.rgb * COLOR.rgb;
	if (l < 0.05) {
		c *= shade_k;
	}
	if (hi > 0.0 && l > 0.85) {
		c = mix(c, vec3(1.0), hi);
	}
	ALBEDO = c;
	ALPHA = clamp(tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Koyu kontur: ters kabuk (arka yüzler normal boyunca şişirilir).
const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float width = 0.015;
uniform float fade = 1.0;
uniform float near = 1.5;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Işık: toplamalı, kenara doğru yumuşar (soft = 1) ya da düz (soft = 0, yassı parçalar için).
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float soft = 1.0;
uniform float fade = 1.0;
uniform float near = 2.0;

void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float k = mix(1.0, pow(f, 1.6), soft);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = clamp(tint.a * COLOR.a * k * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Sarmal küre (Rasengan özü): beyaz merkez, dönen açık mavi sarmal çizgiler, koyu mavi cel kenar.
const SPIRAL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 core_col : source_color = vec4(0.94, 0.98, 1.0, 1.0);
uniform vec4 mid_col : source_color = vec4(0.5, 0.76, 1.0, 1.0);
uniform vec4 rim_col : source_color = vec4(0.16, 0.36, 0.85, 1.0);
uniform float speed = 9.0;
uniform float fade = 1.0;
uniform float near = 1.2;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = normalize(lp);
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ang = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	float sw = sin(ang * 3.0 + lat * 7.0 - TIME * speed) * 0.5 + 0.5;
	float sw2 = sin(ang * 5.0 - lat * 9.0 - TIME * speed * 1.4 + 1.7) * 0.5 + 0.5;
	float lines = clamp(step(0.84, sw) + step(0.88, sw2) * 0.7, 0.0, 1.0);
	vec3 c = mix(mid_col.rgb, core_col.rgb, smoothstep(0.55, 0.95, f));
	c = mix(c, core_col.rgb, lines * 0.85);
	float a = 0.5 + 0.38 * f + lines * 0.15;
	if (f < 0.2) {
		c = rim_col.rgb;
		a = 0.92;
	}
	ALBEDO = c;
	ALPHA = clamp(a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Hız çizgileri: şeritlerde akan kesik çizgiler (UV.x boyunca akar). Anime hız / hareket bulanıklığı çizgisi.
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.1, 0.12, 0.2, 1.0);
uniform float lines = 16.0;
uniform float speed = 2.0;
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform float near = 3.0;

float h1(float x) {
	return fract(sin(x * 127.1 + seed * 13.7) * 43758.5453);
}

void fragment() {
	float lane = floor(UV.y * lines);
	float r = h1(lane);
	float fy = fract(UV.y * lines);
	float s = fract(UV.x * (1.0 + r) - TIME * speed * (0.6 + r) - r * 5.0);
	float seglen = 0.25 + 0.35 * h1(lane + 3.0);
	float on = step(s, seglen) * step(0.28, r);
	float body = step(0.3, fy) * step(fy, 0.7);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = clamp(on * body * tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Sis kütlesi: dünya uzayında kayan değer gürültüsü, iki tonlu cel; siluet kenarı yumuşak, kameraya yakın söner.
const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform vec4 shade : source_color = vec4(0.66, 0.7, 0.78, 1.0);
uniform float density = 0.75;
uniform float drift = 0.25;
uniform float fade = 1.0;
uniform float near = 7.0;

varying vec3 wp;

float hs(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hs(i), hs(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 0.0)), hs(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hs(i + vec3(0.0, 0.0, 1.0)), hs(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hs(i + vec3(0.0, 1.0, 1.0)), hs(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 q = wp * 0.45 + vec3(TIME * drift, TIME * 0.05, TIME * drift * 0.6);
	float n = vn(q) * 0.6 + vn(q * 2.3) * 0.4;
	float band = step(0.5, n);
	vec3 c = mix(shade.rgb, tint.rgb, 0.45 + band * 0.55);
	float a = density * smoothstep(0.05, 0.6, f) * (0.65 + 0.35 * n);
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(a * COLOR.a * fade * smoothstep(near * 0.35, near, length(VERTEX)), 0.0, 1.0);
}
"""

## Hayalet / ruh yüzeyi: içi soluk, akan dikey dalgalar, parlak kuşak ve koyu cel kenar çizgisi.
const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.82, 0.92, 1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.2, 0.32, 0.5, 1.0);
uniform float body_a = 0.2;
uniform float fade = 1.0;
uniform float near = 2.5;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = 1.0 - f;
	float fl = sin(lp.y * 9.0 - TIME * 4.0 + sin(lp.x * 7.0 + lp.z * 5.0) * 1.5) * 0.5 + 0.5;
	vec3 c = tint.rgb;
	float a = body_a + 0.18 * step(0.72, fl);
	if (fr > 0.55) {
		a = body_a + 0.3;
		c = mix(tint.rgb, vec3(1.0), 0.35);
	}
	if (fr > 0.83) {
		c = ink.rgb;
		a = 0.85;
	}
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""

## İşaret / parıltı dörtgeni: kind 0 = eşmerkezli halkalar, 1 = dört uçlu parıltı, 2 = yumuşak nokta. bill = 1 kameraya döner.
const SIGIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float kind = 0.0;
uniform float rings = 3.0;
uniform float scroll = 0.7;
uniform float bill = 1.0;
uniform float fade = 1.0;
uniform float near = 2.0;

void vertex() {
	if (bill > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = 0.0;
	if (kind < 0.5) {
		float band = fract(r * rings - TIME * scroll);
		a = smoothstep(0.0, 0.1, band) * smoothstep(0.3, 0.12, band) * smoothstep(1.0, 0.85, r) * smoothstep(0.2, 0.4, r);
	} else if (kind < 1.5) {
		float cr = max(1.0 - abs(q.x) * 9.0 - abs(q.y) * 1.1, 0.0) + max(1.0 - abs(q.y) * 9.0 - abs(q.x) * 1.1, 0.0);
		a = clamp(cr, 0.0, 1.0) + smoothstep(0.35, 0.0, r);
	} else {
		a = smoothstep(1.0, 0.0, r);
		a = a * a;
	}
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = clamp(a * tint.a * COLOR.a * fade * smoothstep(near * 0.4, near, length(VERTEX)), 0.0, 1.0);
}
"""


# ================================================================== malzeme yapı taşları
static func _shader(key: String, code: String) -> Shader:
	if not _sh.has(key):
		var s := Shader.new()
		s.code = code
		_sh[key] = s
	return _sh[key]


## Cel malzeme + koyu kontur (outline > 0). two_side: tek katlı yüzeyler.
static func cel(col := Color.WHITE, outline := 0.015, ink := INK, two_side := false, near := 1.5, hi := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("cel2" if two_side else "cel", CEL_SHADER.replace("CULLMODE", "cull_disabled" if two_side else "cull_back"))
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("hi", hi)
	m.set_shader_parameter("near", near)
	if outline > 0.0:
		var o := ShaderMaterial.new()
		o.shader = _shader("ol", OUTLINE_SHADER)
		o.set_shader_parameter("ink", ink)
		o.set_shader_parameter("width", outline)
		o.set_shader_parameter("near", near)
		o.render_priority = -1
		m.next_pass = o
	return m


static func glow(col: Color, near := 2.0, soft := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("glow", GLOW_SHADER)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("soft", soft)
	m.set_shader_parameter("near", near)
	return m


static func spiral_mat(near := 1.2, speed := 9.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("spiral", SPIRAL_SHADER)
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("speed", speed)
	return m


static func streak(col: Color, lines := 16.0, speed := 2.0, near := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("streak", STREAK_SHADER)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("lines", lines)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("seed", randf() * 50.0)
	m.set_shader_parameter("near", near)
	return m


static func mist_mat(density := 0.75, near := 7.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("mist", MIST_SHADER)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("drift", randf_range(0.15, 0.35))
	return m


static func ghost_mat(tint: Color, ink: Color, near := 2.5, body_a := 0.2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("ghost", GHOST_SHADER)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("ink", ink)
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("body_a", body_a)
	return m


static func sigil_mat(col: Color, kind := 0.0, rings := 3.0, bill := 1.0, near := 2.0, scroll := 0.7) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("sigil", SIGIL_SHADER)
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("rings", rings)
	m.set_shader_parameter("bill", bill)
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("scroll", scroll)
	return m


## Malzemenin (ve kontur geçişinin) sönüm değeri
static func set_fade(m: Material, v: float) -> void:
	var q := m
	while q != null:
		if q is ShaderMaterial:
			(q as ShaderMaterial).set_shader_parameter("fade", v)
		q = q.next_pass


## delay sonra dur sürede söner, sonra silinir
static func fade_free(n: Node, m: Material, delay: float, dur: float) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, maxf(dur, 0.01))
	tw.tween_callback(n.queue_free)


# ================================================================== düğüm / geometri yapı taşları
static func put(pj: PathJutsu, n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	(parent if parent else pj.get_tree().current_scene).add_child(n)
	n.global_position = pos
	return n


static func mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _cached(key: String, fn: Callable) -> Mesh:
	var k := "mesh:" + key
	if not _cache.has(k):
		_cache[k] = fn.call()
	return _cache[k]


static func _sphere(seg := 16) -> Mesh:
	return _cached("sphere%d" % seg, func():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = seg
		s.rings = maxi(6, seg / 2)
		return s)


static func _quad() -> Mesh:
	return _cached("quad", func():
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		return q)


## Yassı profil → yere yatık: profil x → X, profil y → -Z, kalınlık → Y
static func _flat_b() -> Basis:
	return Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))


## Yassı profil → dik: profil x → X, profil y → Y, kalınlık → Z
static func _up_b() -> Basis:
	return Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


static func slab_mesh(outline: PackedVector2Array, thick: float, col := Color.WHITE, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var b := MB.new()
	b.add_slab(outline, thick, col, xf)
	return b.build()


## a→b arası birim silindir dönüşümü (w: çap)
static func _seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
	var d := b - a
	var L := maxf(d.length(), 0.001)
	var y := d / L
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * w, y * L, z * w), (a + b) * 0.5)


## Halka şerit (XZ düzlemi): UV.x çevre boyunca, UV.y içten dışa
static func _annulus(r0: float, r1: float, seg := 32) -> Mesh:
	return _cached("ann_%.2f_%.2f_%d" % [r0, r1, seg], func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in seg + 1:
			var u := float(i) / seg
			var a := u * TAU
			var dv := Vector3(cos(a), 0, sin(a))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u, 0.0))
			st.add_vertex(dv * r0)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u, 1.0))
			st.add_vertex(dv * r1)
		for i in seg:
			var a := i * 2
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + 2)
			st.add_index(a + 1)
			st.add_index(a + 3)
			st.add_index(a + 2)
		return st.commit())


## Düz disk (XZ, yarıçap r)
static func _disc(r: float, seg := 24) -> Mesh:
	return _cached("disc_%.2f_%d" % [r, seg], func():
		var o := PackedVector2Array()
		for i in seg:
			var a := TAU * i / seg
			o.append(Vector2(cos(a), sin(a)) * r)
		return slab_mesh(o, 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)))


## Şerit (iki yüzlü), uçları incelir; UV.x boy, UV.y en
static func _ribbon(pts: Array, w: float, nrm: Vector3, col := Color.WHITE, taper := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tn: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn := nrm if nrm != Vector3.ZERO else Vector3(p.x, 0.0, p.z).normalized()   # ZERO: sarmalda dik bant (yarıçap yönü)
		var sd := tn.cross(nn).normalized()
		if sd.length() < 0.1:
			sd = tn.cross(Vector3.RIGHT).normalized()
		var u := float(i) / float(n - 1)
		var ww := w * ((0.25 + 0.75 * sin(PI * u)) if taper else 1.0)
		for s in [-1.0, 1.0]:
			st.set_color(col)
			st.set_uv(Vector2(u, (s + 1.0) * 0.5))
			st.set_normal(nn if nn != Vector3.ZERO else Vector3.UP)
			st.add_vertex(p + sd * ww * s * 0.5)
	for i in n - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	return st.commit()


## Yerel sarmal noktaları (Y ekseni boyunca): r yarıçap, h boy, turns tur, faz
static func _helix(r0: float, r1: float, h: float, turns: float, ph: float, n := 28) -> Array:
	var o := []
	for i in n:
		var u := float(i) / (n - 1)
		var a := ph + u * turns * TAU
		var r := lerpf(r0, r1, u)
		o.append(Vector3(cos(a) * r, u * h, sin(a) * r))
	return o


# ------------------------------------------------------------------ 2B profiller
static func _crescent(r: float, w: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		o.append(Vector2(cos(a), sin(a)) * r)
	for i in range(n - 1, 0, -1):
		var u := float(i) / n
		var a := deg_to_rad(lerpf(a0, a1, u))
		o.append(Vector2(cos(a), sin(a)) * (r - w * sin(u * PI)))
	return o


static func _heart(s: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		o.append(Vector2(x, y) * s / 32.0)
	return o


static func _star2d(points: int, r_out: float, r_in: float, rot := 0.0) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in points * 2:
		var a := rot + TAU * i / (points * 2.0)
		o.append(Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return o


static func _blob2d(r: float, n := 18, rough := 0.25) -> PackedVector2Array:
	var o := PackedVector2Array()
	var ph := randf() * 10.0
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + rough * (sin(a * 3.0 + ph) * 0.5 + sin(a * 7.0 + ph * 2.0) * 0.3 + randf_range(-0.3, 0.3))
		o.append(Vector2(cos(a), sin(a)) * r * k)
	return o


# ------------------------------------------------------------------ parça yağmuru (kendi CPU parçacık ayarı)
## o: r, dir, spread, vmin, vmax, g, damp, smin, smax, spin, expl, flat, align, hold, end_scale, radial
static func burst(pj: PathJutsu, pos: Vector3, mesh: Mesh, m: Material, n: int, life: float, o := {}) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = maxi(1, n)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = float(o.get("expl", 0.95))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(o.get("r", 0.3))
	var dv: Vector3 = o.get("dir", Vector3.UP)
	p.direction = dv.normalized() if dv.length() > 0.001 else Vector3.UP
	p.spread = float(o.get("spread", 180.0))
	p.flatness = float(o.get("flat", 0.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("g", Vector3(0, -6, 0))
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
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(1.0, float(o.get("end_scale", 0.6))))
	p.scale_amount_curve = cv
	put(pj, p, pos)
	p.emitting = true
	pj.free_after(life + 0.6, p)
	return p


## Kısa ömürlü işaret / parıltı (billboard): büyür ve söner. kind 0 halka, 1 parıltı, 2 nokta
static func _flash(pj: PathJutsu, pos: Vector3, col: Color, s0: float, s1: float, life: float, kind := 1.0, rings := 1.0, near := 2.0, parent: Node = null) -> MeshInstance3D:
	var m := sigil_mat(col, kind, rings, 1.0, near, 0.0)
	var x := mi(_quad(), m)
	put(pj, x, pos, parent)
	x.scale = Vector3.ONE * s0
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3.ONE * s1, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, life)
	tw.tween_callback(x.queue_free)
	return x


## Yere yatık halka işareti (bill = 0): genişler ve söner
static func _ground_ring(pj: PathJutsu, pos: Vector3, col: Color, r0: float, r1: float, life: float, rings := 1.0) -> void:
	var m := sigil_mat(col, 0.0, rings, 0.0, 3.0, 0.0)
	var x := mi(_quad(), m)
	put(pj, x, pj.gp(pos) + Vector3.UP * 0.06)
	x.rotation.x = -PI * 0.5
	x.scale = Vector3.ONE * r0 * 2.0
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3.ONE * r1 * 2.0, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, life)
	tw.tween_callback(x.queue_free)


## Hilal kılıç izi (beyaz ağız + koyu kontur): fwd yönüne bakan düzlemde, tilt ile çapraz
static func _slash(pj: PathJutsu, pos: Vector3, fwd: Vector3, tilt: float, r: float, col := Color(0.97, 0.98, 1.0), life := 0.28) -> void:
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var root := Node3D.new()
	put(pj, root, pos)
	root.global_transform = Transform3D(Basis(side, Vector3.UP, -fwd).rotated(fwd, tilt), pos)
	var m := cel(col, 0.02, INK, true, 1.2)
	var x := mi(_cached("slash", func(): return slab_mesh(_crescent(1.0, 0.16, -75.0, 75.0, 18), 0.02, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO))), m)
	root.add_child(x)
	root.scale = Vector3.ONE * r * 0.4
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * r, 0.06).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(x, "rotation:z", 0.5, life)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, life)
	tw.tween_callback(root.queue_free)


# ------------------------------------------------------------------ küçük biçimler (önbellekli, beyaz geometri; renk malzemeden)
static func _m_blob() -> Mesh:
	return _cached("blob", func():
		var b := MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.3, 0.24, 0.3), Color.WHITE, Vector3.ZERO, 8)
		return b.build())


static func _m_shard() -> Mesh:
	return _cached("shard", func():
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.03, 0.5, 0.03), Color.WHITE)
		return b.build())


static func _m_chunk() -> Mesh:
	return _cached("chunk", func():
		var b := MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.2, 0.15, 0.17), Color(0.62, 0.58, 0.52), Vector3(18, 30, 9))
		b.add("box", Vector3(0.04, 0.05, 0.02), Vector3(0.12, 0.1, 0.11), Color(0.5, 0.47, 0.42), Vector3(-20, 10, 35))
		return b.build())


## Senbon iğnesi: -Z'ye bakan ince gövde + sivri uç + ince halka sap
static func _m_needle() -> Mesh:
	return _cached("needle", func():
		var b := MB.new()
		b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.016, 0.36, 0.016), Color.WHITE, Vector3(90, 0, 0), 5)
		b.add("cone", Vector3(0, 0, -0.2), Vector3(0.016, 0.08, 0.016), Color(0.9, 0.92, 0.96), Vector3(-90, 0, 0), 5)
		b.add("cyl", Vector3(0, 0, 0.2), Vector3(0.022, 0.02, 0.022), Color(0.55, 0.56, 0.6), Vector3(90, 0, 0), 6)
		return b.build())


## Zil (iğnenin arka ucunda iple asılı)
static func _m_bell() -> Mesh:
	return _cached("bell", func():
		var b := MB.new()
		b.add("cyl", Vector3(0, -0.035, 0.2), Vector3(0.004, 0.07, 0.004), Color(0.3, 0.3, 0.32), Vector3.ZERO, 4)
		b.add("sphere", Vector3(0, -0.085, 0.2), Vector3(0.06, 0.055, 0.06), Color(0.86, 0.72, 0.3), Vector3.ZERO, 10)
		b.add("box", Vector3(0, -0.1, 0.2), Vector3(0.062, 0.008, 0.012), Color(0.15, 0.12, 0.08))
		return b.build())


## İz kuyruğu: iki çapraz üçgen (arkaya +Z doğru incelir)
static func _m_tail() -> Mesh:
	return _cached("tail", func():
		var o := PackedVector2Array([Vector2(-0.025, 0.0), Vector2(0.025, 0.0), Vector2(0.0, 1.0)])
		var b := MB.new()
		var bs := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))   # profil x → X, y → +Z (arkaya), kalınlık → Y
		b.add_slab(o, 0.002, Color.WHITE, Transform3D(bs, Vector3.ZERO))
		b.add_slab(o, 0.002, Color.WHITE, Transform3D(Basis(Vector3.BACK, PI * 0.5) * bs, Vector3.ZERO))
		return b.build())


# ================================================================== JŌRO SENBON — Chiyo'nun şemsiyesi
## Şemsiye: koyu zeytin kubbe (kaburga dilimleri, dalgalı etek), koyu kaburgalar, bambu sap
static func _umbrella() -> Node3D:
	var root := Node3D.new()
	var canopy := Node3D.new()
	root.add_child(canopy)
	root.set_meta("canopy", canopy)
	var cm := _cached("umb_canopy", func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 16
		var top := Vector3(0, 0.34, 0)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p0 := Vector3(cos(a0) * 1.4, 0.0, sin(a0) * 1.4)
			var p1 := Vector3(cos(a1) * 1.4, 0.0, sin(a1) * 1.4)
			var md := (p0 + p1) * 0.5 * 0.92 + Vector3.UP * 0.05
			var col := Color(0.38, 0.36, 0.24) if i % 2 == 0 else Color(0.33, 0.31, 0.2)
			for tri in [[top, p0, md], [top, md, p1]]:
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				for v in tri:
					st.set_color(col)
					st.set_normal(nrm)
					st.add_vertex(v)
		return st.commit())
	canopy.add_child(mi(cm, cel(Color.WHITE, 0.0, INK, true, 3.0)))
	var rib := _cached("umb_ribs", func():
		var b := MB.new()
		var top := Vector3(0, 0.345, 0)
		for i in 16:
			var a := TAU * i / 16.0
			var p := Vector3(cos(a) * 1.41, 0.0, sin(a) * 1.41)
			b.add_xf("cyl", _seg_xf(top, p, 0.025), INK, 4)
			var a2 := TAU * (i + 1) / 16.0
			var p2 := Vector3(cos(a2) * 1.41, 0.0, sin(a2) * 1.41)
			var md := (p + p2) * 0.5 * 0.92 + Vector3.UP * 0.05
			b.add_xf("cyl", _seg_xf(p, md, 0.03), INK, 4)
			b.add_xf("cyl", _seg_xf(md, p2, 0.03), INK, 4)
		b.add("cyl", top, Vector3(0.12, 0.05, 0.12), INK, Vector3.ZERO, 8)
		return b.build())
	canopy.add_child(mi(rib, cel(Color.WHITE, 0.0, INK, false, 3.0)))
	var stick := _cached("umb_stick", func():
		var b := MB.new()
		b.add("cyl", Vector3(0, -0.4, 0), Vector3(0.06, 1.55, 0.06), Color(0.78, 0.62, 0.42), Vector3.ZERO, 6)
		for k in 5:
			b.add("cyl", Vector3(0, 0.2 - k * 0.3, 0), Vector3(0.068, 0.025, 0.068), Color(0.55, 0.42, 0.28), Vector3.ZERO, 6)
		return b.build())
	root.add_child(mi(stick, cel(Color.WHITE, 0.012, INK, false, 3.0)))
	return root


## İğne mermisi görseli (dark: gölgede gizli ikinci iğne)
static func _needle(tail: bool, dark := false, bell := false) -> Node3D:
	var nd := Node3D.new()
	var m := cel(Color(0.08, 0.08, 0.12, 0.7) if dark else STEEL, 0.006, INK, false, 1.0, 0.0 if dark else 0.5)
	nd.add_child(mi(_m_needle(), m))
	if bell:
		nd.add_child(mi(_m_bell(), cel(Color.WHITE, 0.006, INK, false, 1.0, 0.4)))
	if tail:
		var tm := glow(Color(0.25, 0.25, 0.4, 0.55) if dark else Color(0.85, 0.9, 1.0, 0.55), 1.5, 0.0)
		var tx := mi(_m_tail(), tm)
		tx.position = Vector3(0, 0, 0.2)
		tx.scale = Vector3(1, 1, 0.9 if dark else 1.2)
		nd.add_child(tx)
	return nd


## İğne yere saplanır (ardıl iz) ya da hedefte parlar
static func _needle_stick(pj: PathJutsu, p: Vector3, h, dark := false) -> void:
	if h != null:
		_flash(pj, p, Color(1, 1, 1, 0.9), 0.15, 0.5, 0.14, 1.0)
		return
	var g := pj.gp(p)
	if absf(p.y - g.y) > 0.6:
		return
	var m := cel(Color(0.08, 0.08, 0.12, 0.8) if dark else STEEL, 0.006, INK, false, 1.0, 0.4)
	var x := mi(_m_needle(), m)
	put(pj, x, g + Vector3.UP * 0.12)
	x.rotation = Vector3(deg_to_rad(randf_range(55.0, 80.0)), randf() * TAU, 0)
	fade_free(x, m, 2.4, 0.6)


static func jouro_senbon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	pj.anim(c, "throw", 1.5)
	var tt = pj.tg(c, t, 24.0)
	var at: Vector3 = tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0
	var um := _umbrella()
	put(pj, um, pj.hand_pos(c, true))
	var canopy: Node3D = um.get_meta("canopy")
	canopy.scale = Vector3(0.2, 1.6, 0.2)   # kapalı şemsiye
	var tw := um.create_tween()
	tw.tween_property(um, "global_position", at + Vector3.UP * 9.0, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(um, "rotation:y", TAU * 3.0, 1.6)
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		# yağmur bitti: şemsiye kapanır, dönerek küçülüp kaybolur (duman yok)
		if is_instance_valid(canopy):
			canopy.create_tween().tween_property(canopy, "scale", Vector3(0.2, 1.6, 0.2), 0.2)
		var t2 := um.create_tween()
		t2.tween_property(um, "rotation:y", um.rotation.y + TAU, 0.45)
		t2.parallel().tween_property(um, "scale", Vector3.ONE * 0.02, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		t2.tween_callback(um.queue_free))
	# yükselişte açılır (geri tepen yay)
	var ct := canopy.create_tween()
	ct.tween_interval(0.38)
	ct.tween_property(canopy, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# kaynaktaki gibi: dönen şemsiyenin çevresinde koyu sarmal hız çizgileri
	pj.after(0.42, func():
		if not is_instance_valid(um):
			return
		for k in 2:
			var sm := streak(Color(0.08, 0.12, 0.22, 0.85), 22.0, 2.6 + k * 1.2, 5.0)
			var sw := mi(_annulus(1.5 + k * 0.4, 3.1 + k * 0.9, 40), sm)
			um.add_child(sw)
			sw.position = Vector3.UP * (0.12 - k * 0.2)
			fade_free(sw, sm, 1.5, 0.45))
	# hedef alanda şemsiyenin gölgesi büyür (yağmur alanı okunur)
	var shm := cel(Color(0.04, 0.05, 0.09, 0.3), 0.0, INK, true, 4.0)
	var sh := mi(_disc(1.0, 28), shm)
	put(pj, sh, pj.gp(at) + Vector3.UP * 0.05)
	sh.scale = Vector3(0.3, 1, 0.3)
	sh.create_tween().tween_property(sh, "scale", Vector3(3.0, 1, 3.0), 0.6).set_ease(Tween.EASE_OUT)
	fade_free(sh, shm, 2.0, 0.6)
	pj.after(0.5, func():
		var needles := 56 if CanonRules.weapon_ids(c).any(func(w): return Gear.base_id(String(w)) == "amagasa") else 40   # elde gerçek Amagasa: daha çok iğne
		for k in needles:
			pj.after(randf() * 0.9, func():
				var q: Vector3 = at + Vector3(randf_range(-1.2, 1.2), 8.6, randf_range(-1.2, 1.2))
				pj.shot(c, q, (at + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)) - q).normalized(), 40.0, _needle(k % 3 == 0), pj.inf(c, "jouro_senbon", 0.07, {"knock": 0.3, "kind": "light", "bleed": 1.0}), null, false, 0.5, func(p, h):
					_needle_stick(pj, p, h))
				if k % 5 == 0:
					_flash(pj, q, Color(0.9, 0.95, 1.0, 0.9), 0.2, 0.6, 0.12, 1.0, 1.0, 4.0)))
	Sfx.play("whoosh", c.global_position, 1.7)


# ================================================================== KAGE SENBON — zilli iğne + gölgesindeki ikinci iğne
static func kage_senbon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.4)
	var tt = pj.tg(c, t, 25.0)
	var from: Vector3 = pj.hand_pos(c, true)
	# zil sesinin halkaları elde (şaşırtma)
	_flash(pj, from, Color(1.0, 0.85, 0.45, 0.8), 0.1, 0.7, 0.3, 0.0, 2.0, 1.2)
	for wave in 2:
		pj.after(wave * 0.18, func():
			if not pj.live(c):
				return
			for k in 3:
				var nd := _needle(true, wave == 1, wave == 0)
				var d = pj.aim_at(c, tt, from).rotated(Vector3.UP, deg_to_rad((k - 1) * 3.0)) + Vector3.UP * (0.015 * (wave * 2 - 1))
				pj.shot(c, from - Vector3.UP * 0.1 * wave, d.normalized(), 52.0, nd, pj.inf(c, "kage_senbon", 0.14, {"knock": 0.5, "kind": "light", "bleed": 1.0}), null, false, 0.9, func(p, h):
					if wave == 0 and h != null:
						_flash(pj, p, Color(1.0, 0.85, 0.45, 0.8), 0.1, 0.9, 0.35, 0.0, 2.0, 1.2)   # zil çınlaması
					_needle_stick(pj, p, h, wave == 1)))
	Sfx.play("seal", from, 2.2, 0.4)
	Sfx.play("whoosh", from, 1.9, 0.4)


# ================================================================== KAGE SHURIKEN — fuma şuriken ve gölgesinden çıkan ikincisi
## Fuma şuriken: dört kavisli orak kanat (yere yatık), göbek halkası; kanatlarda koyu bulanık dönüş halkası (kaynak)
static func _m_fuma_blades() -> Mesh:
	return _cached("fuma", func():
		var b := MB.new()
		var n := 10
		var o := PackedVector2Array()
		var back := PackedVector2Array()
		for i in n + 1:
			var u := float(i) / n
			var rr := lerpf(0.1, 0.78, u)
			var a := u * 0.95
			var w := 0.16 * pow(1.0 - u, 0.65) + 0.012
			o.append(Vector2(cos(a), sin(a)) * rr + Vector2(-sin(a), cos(a)) * w * 0.3)
			back.append(Vector2(cos(a), sin(a)) * rr - Vector2(-sin(a), cos(a)) * w * 0.7)
		for i in range(back.size() - 2, -1, -1):
			o.append(back[i])
		for k in 4:
			b.add_slab(o, 0.035, Color.WHITE, Transform3D(Basis(Vector3.UP, k * PI * 0.5) * _flat_b(), Vector3.ZERO))
		b.add("cyl", Vector3.ZERO, Vector3(0.26, 0.06, 0.26), Color(0.7, 0.7, 0.75), Vector3.ZERO, 12)
		b.add("cyl", Vector3(0, 0.01, 0), Vector3(0.11, 0.07, 0.11), Color(0.15, 0.15, 0.18), Vector3.ZERO, 10)
		return b.build())


static func _fuma_star(s: float, col: Color, blur_col: Color) -> Node3D:
	var root := Node3D.new()
	var body := mi(_m_fuma_blades(), cel(col, 0.012, INK, false, 1.5, 0.35))
	body.scale = Vector3.ONE * s
	root.add_child(body)
	var bm := streak(blur_col, 9.0, -3.0, 2.0)
	var bl := mi(_annulus(0.28 * s, 0.84 * s, 32), bm)
	root.add_child(bl)
	return root


## Çelik çarpması: iki çapraz kesik + uzun kıvılcımlar
static func _steel_hit(pj: PathJutsu, p: Vector3, fwd: Vector3) -> void:
	_slash(pj, p, fwd, 0.7, 0.9)
	_slash(pj, p, fwd, -0.7, 0.75)
	burst(pj, p, _m_shard(), glow(Color(1.0, 0.95, 0.75), 1.2, 0.0), 12, 0.3, {"r": 0.1, "vmin": 5.0, "vmax": 10.0, "g": Vector3(0, -8, 0), "align": true, "smin": 0.4, "smax": 0.8, "end_scale": 0.2})


static func kage_shuriken_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 30.0)
	var from: Vector3 = pj.hand_pos(c, true) + Vector3.UP * 0.3
	var dir: Vector3 = pj.aim_at(c, tt, from)
	var info = pj.inf(c, "kage_shuriken_no_jutsu", 0.6, {"knock": 3.0, "kind": "heavy", "bleed": 3.0})
	var p1 = pj.shot(c, from, dir, 28.0, _fuma_star(1.5, DARK_STEEL, Color(0.1, 0.1, 0.13, 0.7)), info, tt, false, 1.6, func(p, _h):
		_steel_hit(pj, p, dir))
	p1.spin = Vector3(0, 26, 0)
	p1.radius = 0.8
	# kaynaktaki gibi: şurikenin altında yerde koyu gölgesi kayar (ikincisi o gölgede saklı)
	var shm := cel(Color(0.03, 0.03, 0.06, 0.45), 0.0, INK, true, 3.0)
	var shd := mi(_disc(1.0, 24), shm)
	put(pj, shd, pj.gp(from) + Vector3.UP * 0.05)
	shd.scale = Vector3(1.3, 1, 0.9)
	p1.on_tick = func(pp, _dt):
		if is_instance_valid(shd):
			shd.global_position = pj.gp(pp.global_position) + Vector3.UP * 0.05
	fade_free(shd, shm, 1.4, 0.3)
	Sfx.play("whoosh", from, 1.2, 0.6)
	pj.after(0.22, func():
		if not is_instance_valid(p1):
			return
		var g = pj.gp(p1.global_position) + Vector3.UP * 0.15
		# gölge sıvı gibi dalgalanır, içinden kara şuriken kopar
		var rm := cel(Color(0.02, 0.02, 0.05, 0.75), 0.0, INK, true, 2.0)
		var rg := mi(_annulus(0.7, 1.0, 32), rm)
		put(pj, rg, g - Vector3.UP * 0.08)
		rg.scale = Vector3.ONE * 0.6
		var rt := rg.create_tween()
		rt.tween_property(rg, "scale", Vector3.ONE * 2.2, 0.4).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_method(func(v: float): set_fade(rm, v), 1.0, 0.0, 0.4)
		rt.tween_callback(rg.queue_free)
		burst(pj, g, _m_blob(), cel(Color(0.04, 0.04, 0.07), 0.0, INK, false, 1.5), 14, 0.5, {"r": 0.5, "dir": Vector3.UP, "spread": 35.0, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, -12, 0), "smin": 0.25, "smax": 0.6})
		var side = dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
		var p2 = pj.shot(c, g, (dir + side * 0.5 + Vector3.UP * 0.25).normalized(), 30.0, _fuma_star(1.2, SHADOW, Color(0.2, 0.15, 0.3, 0.6)), info, tt, false, 1.4, func(p, _h):
			_steel_hit(pj, p, dir))
		p2.spin = Vector3(0, -30, 0)
		p2.homing_turn = 7.0
		p2.radius = 0.7
		Combat.popup_text(g + Vector3.UP * 1.2, "Gölgeden ikinci!", Color(0.8, 0.8, 0.9)))


# ================================================================== SHURIKEN KAGE BUNSHIN — tek şuriken yirmi dörde bölünür
static func _m_star() -> Mesh:
	return _cached("star4", func():
		var b := MB.new()
		var o := _star2d(4, 0.5, 0.13, PI * 0.25)
		b.add_slab(MB.hole(o, Vector2.ZERO, 0.06, 10), 0.04, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
		return b.build())


static func _star_shot(s: float) -> Node3D:
	var root := Node3D.new()
	var x := mi(_m_star(), cel(Color(0.3, 0.31, 0.36), 0.01, INK, false, 1.2, 0.35))
	x.scale = Vector3.ONE * s * 2.0
	root.add_child(x)
	var bm := streak(Color(0.12, 0.13, 0.16, 0.6), 7.0, -4.0, 1.5)
	var bl := mi(_annulus(0.12 * s * 2.0, 0.52 * s * 2.0, 24), bm)
	root.add_child(bl)
	return root


static func shuriken_kage_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d: Vector3 = Jutsu._aim(c, t)
	var tt = pj.tg(c, t, 35.0)
	var pr = pj.shot(c, Jutsu._hand(c), d, 26.0, _star_shot(0.35), {"dmg": 1.0, "knock": 0.0}, null, false, 0.3)
	pr.spin = Vector3(0, 30, 0)
	pj.after(0.22, func():
		var p: Vector3 = pr.global_position if is_instance_valid(pr) else Jutsu._hand(c) + d * 5.0
		# bölünme anı: chakra parıltısı + yelpaze gibi açılan saydam kopyalar (duman yok)
		_flash(pj, p, Color(0.75, 0.88, 1.0, 1.0), 0.3, 2.4, 0.22, 1.0, 1.0, 2.0)
		_flash(pj, p, Color(0.6, 0.8, 1.0, 0.8), 0.4, 3.2, 0.35, 0.0, 2.0, 2.0)
		var gm := ghost_mat(Color(0.75, 0.85, 1.0), Color(0.2, 0.25, 0.4), 1.5, 0.35)
		for k in 8:
			var gh := mi(_m_star(), gm)
			put(pj, gh, p)
			gh.scale = Vector3.ONE * 0.7
			var off: Vector3 = d.rotated(Vector3.UP, (k - 3.5) * 0.14) * 0.2 + d.cross(Vector3.UP).normalized() * (k - 3.5) * 0.35
			var gt := gh.create_tween()
			gt.tween_property(gh, "global_position", p + off, 0.15).set_ease(Tween.EASE_OUT)
			gt.parallel().tween_property(gh, "rotation:y", TAU, 0.15)
			gt.tween_callback(gh.queue_free)
		for k in 24:
			var dd = d.rotated(Vector3.UP, randf_range(-0.5, 0.5)).rotated(d.cross(Vector3.UP).normalized(), randf_range(-0.25, 0.25))
			var s = pj.shot(c, p, dd, 34.0, _star_shot(0.3), pj.inf(c, "shuriken_kage_bunshin_no_jutsu", 0.09, {"knock": 1.0, "kind": "light"}), tt if k % 3 == 0 else null, false, 1.4, func(q, h):
				_star_stick(pj, q, h))
			s.spin = Vector3(0, 30, 0))
	Sfx.play("kunai", c.global_position)


static func _star_stick(pj: PathJutsu, p: Vector3, h) -> void:
	if h != null:
		_flash(pj, p, Color(1, 1, 1, 0.9), 0.2, 0.7, 0.14, 1.0)
		return
	var g := pj.gp(p)
	if absf(p.y - g.y) > 0.6:
		return
	var m := cel(Color(0.3, 0.31, 0.36), 0.008, INK, false, 1.0, 0.35)
	var x := mi(_m_star(), m)
	put(pj, x, g + Vector3.UP * 0.1)
	x.scale = Vector3.ONE * 0.6
	x.rotation = Vector3(deg_to_rad(randf_range(50.0, 75.0)), randf() * TAU, 0)
	fade_free(x, m, 2.0, 0.6)


# ================================================================== SAIRENTO KIRINGU — Kirigakure sisi + sessiz suikast
static func _mist_bank(pj: PathJutsu, center: Vector3, n: int, spread: float, life: float) -> void:
	for k in n:
		var a := randf() * TAU
		var d := sqrt(randf()) * spread
		var m := mist_mat(randf_range(0.7, 0.85), 7.0)
		var x := mi(_sphere(18), m)
		put(pj, x, pj.gp(center + Vector3(cos(a) * d, 0, sin(a) * d)) + Vector3.UP * randf_range(0.4, 0.9))
		var s := Vector3(randf_range(4.0, 6.5), randf_range(1.8, 2.8), randf_range(4.0, 6.5))
		x.scale = Vector3(s.x * 0.4, 0.2, s.z * 0.4)
		var tw := x.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_property(x, "scale", s, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(x, "global_position", x.global_position + Vector3(randf_range(-0.8, 0.8), 0.2, randf_range(-0.8, 0.8)), life * 0.6)
		tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, life * 0.4)
		tw.tween_callback(x.queue_free)
	# yere yapışık, yavaş dönen sis şeritleri
	for k in 2:
		var sm := streak(Color(0.9, 0.92, 0.96, 0.55), 10.0, 0.35 + k * 0.2, 6.0)
		var rg := mi(_annulus(2.0 + k * 2.5, 6.0 + k * 3.0, 40), sm)
		put(pj, rg, pj.gp(center) + Vector3.UP * (0.25 + k * 0.35))
		rg.create_tween().tween_property(rg, "rotation:y", (1.0 if k == 0 else -1.0) * 1.2, life)
		fade_free(rg, sm, life * 0.6, life * 0.4)


static func sairento_kiringu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var base: Vector3 = c.global_position
	_mist_bank(pj, base, 9, 7.0, 4.2)
	# beden sisin içinde çözülür: soluk sis tutamları yükselir
	burst(pj, base + Vector3.UP * 1.0, _m_blob(), cel(Color(0.92, 0.94, 0.97, 0.6), 0.0, INK, false, 2.0), 18, 1.2, {"r": 0.5, "dir": Vector3.UP, "spread": 60.0, "vmin": 0.4, "vmax": 1.4, "g": Vector3(0, 0.6, 0), "damp": 1.0, "smin": 1.2, "smax": 2.4, "end_scale": 1.6, "hold": 0.4})
	for e in pj.enemies_near(c, c.global_position, 15.0):
		if e.has_method("lose_target"):
			e.lose_target(2.5)
	if c.get("model"):
		c.model.visible = false
	pj.after(1.4, func():
		if not is_instance_valid(c):
			return
		if c.get("model"):
			c.model.visible = true
		var list = pj.enemies_near(c, c.global_position, 18.0)
		if list.is_empty():
			return
		var e = list[0]
		var behind = e.global_position - (e.face_dir() if e.has_method("face_dir") else Vector3.FORWARD) * (e.radius + 0.9)
		c.global_position = pj.gp(behind)
		if c is Player:
			c.combat.face_to(e)
		# sis aralanır: arkada belirişte dönen soluk girdap
		var pts := _helix(0.9, 0.4, 2.0, 1.3, randf() * TAU)
		var wm := streak(Color(0.92, 0.94, 0.98, 0.8), 6.0, 3.0, 2.0)
		var wr := mi(_ribbon(pts, 0.35, Vector3.ZERO), wm)
		put(pj, wr, c.global_position)
		wr.create_tween().tween_property(wr, "rotation:y", 2.5, 0.5)
		fade_free(wr, wm, 0.2, 0.35)
		pj.every(0.45, 0.15, func(i, _k):
			pj.anim(c, ["slash_a", "slash_b", "slash_a"][i], 2.6)
			if not (is_instance_valid(e) and not e.is_dead()):
				return
			pj.hit(c, e.global_position + Vector3.UP, 1.2, pj.inf(c, "sairento_kiringu", 0.7, {"knock": 3.0 if i < 2 else 12.0, "kind": "heavy", "hitstop": 0.05}))
			var fwd: Vector3 = e.global_position - c.global_position
			_slash(pj, e.global_position + Vector3.UP * 1.1, fwd, [0.8, -0.8, 0.05][i], 1.0 if i < 2 else 1.6)
			if i == 2:
				_flash(pj, e.global_position + Vector3.UP * 1.1, Color(1, 1, 1, 1), 0.3, 2.2, 0.2, 1.0)
			Sfx.play("kunai", c.global_position, 1.3)))


# ================================================================== RİKUDŌ YIN — hilal mühür, yoktan biçim, çakra mühürlenir
static func _m_crescent_mark(r: float) -> Mesh:
	return _cached("cres_%.2f" % r, func(): return slab_mesh(_crescent(r, r * 0.55, 40.0, 320.0, 20), r * 0.12, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO)))


static func yin_palm(pj: PathJutsu, c: Node3D) -> Node3D:
	var ba = pj.bone_attach(c, "LeftHand")
	if ba == null:
		return null
	var b := MB.new()
	b.add_slab(_crescent(0.032, 0.02, 40.0, 320.0, 14), 0.004, Color(0.04, 0.03, 0.06), Transform3D(_up_b(), Vector3(0, 0.08, 0.035)))
	b.add_xf("cyl", _seg_xf(Vector3(-0.045, 0.05, 0.034), Vector3(0.045, 0.11, 0.034), 0.004), Color(0.1, 0.08, 0.12), 4)
	ba.add_child(mi(b.build(), cel(Color.WHITE, 0.0, INK, true, 0.8)))
	var orb := mi(_sphere(14), ghost_mat(Color(0.25, 0.18, 0.4), Color(0.75, 0.6, 1.0), 0.8, 0.5))
	orb.position = Vector3(0, 0.1, 0.09)
	orb.scale = Vector3.ONE * 0.16
	ba.add_child(orb)
	orb.create_tween().set_loops(5).tween_property(orb, "rotation:y", TAU, 0.2).as_relative()
	return ba


static func rikudo_no_in_no_chikara(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.0)
	var ba = yin_palm(pj, c)
	if ba:
		pj.free_after(1.0, ba)
	if tt == null:
		return
	pj._jump_at(c, tt, 0.5, 9.0)
	pj.after(0.35, func():
		if not (pj.live(c) and pj.live(tt)):
			return
		var chest: Vector3 = tt.global_position + Vector3.UP
		var to_c: Vector3 = c.global_position - tt.global_position
		to_c.y = 0.0
		to_c = to_c.normalized() if to_c.length() > 0.05 else Vector3.FORWARD
		# yoktan biçim: hedefin önünde kara hilal belirir, büyür, sonra bedene çöker
		var gm := cel(Color(0.03, 0.02, 0.06), 0.03, YIN, false, 1.5)
		var glyph := mi(_m_crescent_mark(1.0), gm)
		put(pj, glyph, chest + to_c * 0.6)
		glyph.look_at(glyph.global_position + to_c, Vector3.UP)
		glyph.scale = Vector3.ONE * 0.05
		var gt := glyph.create_tween()
		gt.tween_property(glyph, "scale", Vector3.ONE * 1.1, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		gt.tween_interval(0.15)
		gt.tween_property(glyph, "scale", Vector3.ONE * 0.05, 0.22).set_ease(Tween.EASE_IN)
		gt.parallel().tween_property(glyph, "global_position", chest, 0.22)
		gt.tween_callback(glyph.queue_free)
		# hedefin çakrası kara tellerle içe çekilir
		var tm := ghost_mat(Color(0.2, 0.12, 0.32), Color(0.7, 0.55, 1.0), 1.2, 0.55)
		for k in 4:
			var tr := mi(_ribbon(_helix(1.6, 0.25, 2.2, 1.2, k * TAU / 4.0), 0.14, Vector3.ZERO), tm)
			put(pj, tr, pj.gp(tt.global_position))
			var tw := tr.create_tween()
			tw.tween_property(tr, "rotation:y", -2.4, 0.6)
			tw.parallel().tween_property(tr, "scale", Vector3(0.2, 1.0, 0.2), 0.6).set_ease(Tween.EASE_IN)
			tw.tween_callback(tr.queue_free)
		burst(pj, chest, _m_blob(), cel(Color(0.05, 0.03, 0.09), 0.0, INK, false, 1.2), 24, 0.6, {"r": 1.8, "vmin": 0.0, "vmax": 0.2, "g": Vector3.ZERO, "radial": -9.0, "smin": 0.25, "smax": 0.5, "end_scale": 0.1})
		# hedefin çevresinde üç kat dönen hilal mühür halkası (kara hilaller + mor kontur), hedef boyunda
		for k in 3:
			var ring := Node3D.new()
			var rm := cel(Color(0.04, 0.03, 0.07), 0.012, YIN, false, 1.2)
			var rr := 0.9 - k * 0.2
			for q in 6:
				var a := q * TAU / 6.0
				var cm := mi(_m_crescent_mark(0.13), rm)
				cm.position = Vector3(cos(a) * rr, 0, sin(a) * rr)
				cm.rotation = Vector3(0, -a + PI * 0.5, 0)
				ring.add_child(cm)
			tt.add_child(ring)
			PathJutsu.fit_body(tt, ring)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
			ring.position = Vector3.UP * (0.5 + k * 0.5)
			ring.create_tween().set_loops(10).tween_property(ring, "rotation:y", (TAU if k % 2 == 0 else -TAU), 0.9 - k * 0.15).as_relative()
			pj.get_tree().create_timer(3.0).timeout.connect(ring.queue_free)
		# yerde mürekkep lekesi gibi kara mühür izi
		var bm := cel(Color(0.05, 0.03, 0.08, 0.6), 0.0, INK, true, 3.0)
		var blot := mi(slab_mesh(_blob2d(1.4, 20, 0.3), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)), bm)
		put(pj, blot, pj.gp(tt.global_position) + Vector3.UP * 0.04)
		blot.scale = Vector3.ONE * 0.2
		blot.create_tween().tween_property(blot, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
		fade_free(blot, bm, 2.4, 0.8)
		pj.st(tt, "stun", 3.0)
		tt.take_hit(pj.inf(c, "rikudo_no_in_no_chikara", 1.6, {"knock": 0.0, "kind": "heavy", "chakra_drain": 60.0})))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== RİKUDŌ YANG — güneş mühür, altın yaşam enerjisi
static func yang_palm(pj: PathJutsu, c: Node3D) -> Node3D:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return null
	var b := MB.new()
	var bs := _up_b()
	var ring := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		ring.append(Vector2(cos(a), sin(a)) * 0.03)
	b.add_slab(MB.hole(ring, Vector2.ZERO, 0.022, 14), 0.004, Color(0.12, 0.1, 0.06), Transform3D(bs, Vector3(0, 0.08, 0.035)))
	b.add_xf("cyl", _seg_xf(Vector3(-0.05, 0.05, 0.034), Vector3(-0.028, 0.068, 0.034), 0.004), Color(0.12, 0.1, 0.06), 4)
	b.add_xf("cyl", _seg_xf(Vector3(0.028, 0.092, 0.034), Vector3(0.05, 0.11, 0.034), 0.004), Color(0.12, 0.1, 0.06), 4)
	ba.add_child(mi(b.build(), cel(Color.WHITE, 0.0, INK, true, 0.8)))
	var orb := mi(_sphere(14), glow(GOLD, 0.8))
	orb.position = Vector3(0, 0.1, 0.09)
	orb.scale = Vector3.ONE * 0.2
	ba.add_child(orb)
	var tw := orb.create_tween().set_loops(4)
	tw.tween_property(orb, "scale", Vector3.ONE * 0.26, 0.12)
	tw.tween_property(orb, "scale", Vector3.ONE * 0.18, 0.12)
	return ba


static func _m_sprout() -> Mesh:
	return _cached("sprout", func():
		var b := MB.new()
		var leaf := PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0.08), Vector2(0.04, 0.2), Vector2(0, 0.28), Vector2(-0.04, 0.2), Vector2(-0.05, 0.08)])
		for k in 3:
			var xf := Transform3D(Basis(Vector3.UP, k * TAU / 3.0) * Basis(Vector3.RIGHT, 0.35) * _up_b(), Vector3.ZERO)
			b.add_slab(leaf, 0.01, Color(0.45, 0.82, 0.35) if k != 1 else Color(0.38, 0.72, 0.3), xf)
		return b.build())


static func _m_sun_rays() -> Mesh:
	return _cached("sun_rays", func(): return slab_mesh(MB.hole(_star2d(12, 1.0, 0.62), Vector2.ZERO, 0.45, 24), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)))


static func rikudo_no_yo_no_chikara(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.0)
	var ba = yang_palm(pj, c)
	if ba:
		pj.free_after(1.0, ba)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var foot: Vector3 = pj.gp(c.global_position)
		# yerde açılan güneş: on iki ışınlı altın çark
		var sm := glow(Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 3.0, 0.0)
		var sun := mi(_m_sun_rays(), sm)
		put(pj, sun, foot + Vector3.UP * 0.05)
		sun.scale = Vector3.ONE * 0.2
		var st := sun.create_tween()
		st.tween_property(sun, "scale", Vector3.ONE * 2.6, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		st.parallel().tween_property(sun, "rotation:y", 1.2, 1.8)
		fade_free(sun, sm, 1.0, 0.8)
		# bedeni saran altın yaşam sarmalları yükselir
		for k in 3:
			var hm := glow(Color(1.0, 0.88, 0.45, 0.85), 1.5, 0.0)
			var hx := mi(_ribbon(_helix(0.7, 0.45, 2.3, 1.4, k * TAU / 3.0), 0.12, Vector3.ZERO), hm)
			c.add_child(hx)
			hx.scale = Vector3(1, 0.1, 1)
			var ht := hx.create_tween()
			ht.tween_property(hx, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
			ht.parallel().tween_property(hx, "rotation:y", TAU * 0.8, 1.4).as_relative()
			fade_free(hx, hm, 0.9, 0.5)
		# altın aura kabuğu (kısa)
		var am := glow(Color(1.0, 0.82, 0.35, 0.5), 1.5, 1.0)
		var aura := mi(_sphere(18), am)
		c.add_child(aura)
		aura.position = Vector3.UP * 0.95
		aura.scale = Vector3(0.9, 2.0, 0.9)
		fade_free(aura, am, 0.6, 0.7)
		# yaşam: ayak dibinde filizler biter
		var lm := cel(Color.WHITE, 0.006, Color(0.1, 0.22, 0.08), false, 1.2)
		for k in 12:
			var a := randf() * TAU
			var r := randf_range(0.45, 1.5)
			var sp := mi(_m_sprout(), lm)
			put(pj, sp, pj.gp(foot + Vector3(cos(a) * r, 0, sin(a) * r)))
			sp.rotation.y = randf() * TAU
			sp.scale = Vector3.ONE * 0.05
			var tw := sp.create_tween()
			tw.tween_interval(randf() * 0.3)
			tw.tween_property(sp, "scale", Vector3.ONE * randf_range(0.9, 1.5), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_interval(2.4)
			tw.tween_property(sp, "scale", Vector3.ONE * 0.05, 0.4)
			tw.tween_callback(sp.queue_free)
		# altın yaşam zerreleri süzülerek yükselir
		burst(pj, c.global_position + Vector3.UP * 0.8, _sphere(8), glow(GOLD, 1.0), 30, 1.4, {"r": 0.7, "dir": Vector3.UP, "spread": 25.0, "vmin": 0.6, "vmax": 1.8, "g": Vector3(0, 0.8, 0), "smin": 0.06, "smax": 0.14, "end_scale": 0.2, "expl": 0.5})
		pj.heal(c, c.max_hp * 0.7)
		if c is Player:
			Buffs.add("rikudo_yo", 6.0, {"armor": 0.4, "_name": "Yang Gücü", "_desc": "yaşam enerjisi: hasar azalır"}))
	Sfx.play("heal", c.global_position, 0.7)


# ================================================================== KATSUYU DAIBUNRETSU — dev sümüklüböcek binlerce parçaya bölünür
static func _m_ink_seal() -> Mesh:
	if not _cache.has("mesh:ink_seal"):
		_cache["mesh:ink_seal"] = _build_ink_seal()
	return _cache["mesh:ink_seal"]


static func _build_ink_seal() -> Mesh:
	var b := MB.new()
	var outer := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		outer.append(Vector2(cos(a), sin(a)))
	b.add_slab(MB.hole(outer, Vector2.ZERO, 0.93, 40), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	var inner := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		inner.append(Vector2(cos(a), sin(a)) * 0.42)
	b.add_slab(MB.hole(inner, Vector2.ZERO, 0.38, 32), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO))
	for k in 16:
		var a := TAU * k / 16.0
		var L := 0.18 + 0.14 * float(k % 3)
		var p := Vector2(cos(a), sin(a)) * (0.5 + L * 0.5)
		b.add("box", Vector3(p.x, 0.0, -p.y), Vector3(0.035, 0.012, L), Color.WHITE, Vector3(0, rad_to_deg(a) + 90.0, 0))
	return b.build()


## Kendi çağrı mührü: yerde mürekkep halka, içte ikinci halka, dışa dönük yazı çizgileri
static func _ink_seal(pj: PathJutsu, at: Vector3, r: float, life: float) -> void:
	var m := cel(Color(0.05, 0.05, 0.07, 0.9), 0.0, INK, true, 3.0)
	var seal := mi(_m_ink_seal(), m)
	put(pj, seal, pj.gp(at) + Vector3.UP * 0.05)
	seal.scale = Vector3.ONE * r * 0.2
	var tw := seal.create_tween()
	tw.tween_property(seal, "scale", Vector3.ONE * r, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(seal, "rotation:y", 0.8, life)
	fade_free(seal, m, life * 0.7, life * 0.3)


## Kaynaktaki dev beyaz sümüklüböcek kütlesi: tümsek gövde, mavi şeritler, iki göz sapı
static func _slug_mound() -> Mesh:
	return _cached("slug_mound", func():
		var b := MB.new()
		b.add("sphere", Vector3(0, 0.6, 0), Vector3(3.2, 1.9, 3.6), SLUG_W, Vector3.ZERO, 16)
		b.add("sphere", Vector3(0, 1.3, 0.5), Vector3(1.8, 1.4, 1.8), SLUG_W, Vector3.ZERO, 12)
		for k in 9:
			var a := k * TAU / 9.0
			b.add("sphere", Vector3(cos(a) * 1.35, 0.55 + sin(k * 1.7) * 0.2, sin(a) * 1.5), Vector3(0.3, 0.75, 0.32), SLUG_B, Vector3(0, -rad_to_deg(a), 20.0), 8)
		for sx in [-1.0, 1.0]:
			b.add_xf("cyl", _seg_xf(Vector3(sx * 0.35, 1.8, 0.8), Vector3(sx * 0.9, 3.0, 1.1), 0.16), SLUG_W, 6)
			b.add("sphere", Vector3(sx * 0.92, 3.08, 1.12), Vector3(0.34, 0.34, 0.34), SLUG_W, Vector3.ZERO, 10)
			b.add("sphere", Vector3(sx * 0.95, 3.1, 1.27), Vector3(0.16, 0.18, 0.06), Color(0.55, 0.52, 0.62), Vector3.ZERO, 8)
		return b.build())


static func katsuyu_daibunretsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at: Vector3 = pj.gp(c.global_position)
	_ink_seal(pj, at, 3.0, 1.6)
	# dev beden mühürden kabarır, sonra binlerce parçaya bölünür
	var mm := cel(Color.WHITE, 0.03, INK, false, 6.0, 0.3)
	var mound := mi(_slug_mound(), mm)
	put(pj, mound, at - Vector3.UP * 0.1)
	mound.rotation.y = c.rotation.y
	mound.scale = Vector3(0.6, 0.05, 0.6)
	var mt := mound.create_tween()
	mt.tween_property(mound, "scale", Vector3.ONE, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	mt.tween_property(mound, "scale", Vector3(1.25, 0.05, 1.25), 0.22).set_ease(Tween.EASE_IN)
	mt.tween_callback(mound.queue_free)
	pj.after(0.3, func():
		burst(pj, at + Vector3.UP * 1.5, _m_blob(), cel(Color(0.85, 0.93, 0.98), 0.008, INK, false, 2.0, 0.3), 30, 0.9, {"r": 1.2, "dir": Vector3.UP, "spread": 70.0, "vmin": 3.0, "vmax": 7.0, "g": Vector3(0, -12, 0), "smin": 0.3, "smax": 0.8}))
	var pm := cel(Color(0.78, 0.9, 0.98, 0.5), 0.0, INK, true, 3.0, 0.4)
	var slugs = []
	for k in 24:
		# oyunun gerçek Katsuyu parçası modeli (Sümüklüböcek sözleşmesi Kuchiyose'siyle aynı: SummonModels "slug_frag")
		var s: Node3D = SummonModels.build("slug_frag", 0.4, 0.8)["root"]
		pj.get_tree().current_scene.add_child(s)
		var a = randf() * TAU
		var r = randf_range(1.0, 9.0)
		s.global_position = at + Vector3.UP * 3.0
		s.rotation.y = a
		s.visible = false
		var dest: Vector3 = pj.gp(at + Vector3(cos(a) * r, 0, sin(a) * r))
		var src: Vector3 = at + Vector3.UP * 3.0
		var fly := randf_range(0.4, 0.7)
		var tw = s.create_tween()
		tw.tween_interval(0.3)
		tw.tween_callback(func(): s.visible = true)
		tw.tween_method(func(u: float):
			if is_instance_valid(s):
				s.global_position = src.lerp(dest, u) + Vector3.UP * sin(u * PI) * (1.5 + r * 0.25), 0.0, 1.0, fly).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func():
			# indiği yerde parlak sümük izi
			var pd := mi(slab_mesh(_blob2d(0.45, 12, 0.25), 0.01, Color.WHITE, Transform3D(_flat_b(), Vector3.ZERO)), pm)
			s.add_child(pd)
			pd.position = Vector3.UP * 0.03
			pd.scale = Vector3.ONE * 0.3
			pd.create_tween().tween_property(pd, "scale", Vector3(1.0, 1.0, 1.6), 0.3))
		tw.tween_interval(5.7)
		tw.tween_property(s, "scale", Vector3(1.3, 0.05, 1.3), 0.3).set_ease(Tween.EASE_IN)   # parça eriyip yere siner
		tw.tween_callback(s.queue_free)
		slugs.append(s)
	pj.every(6.5, 0.5, func(_i, _k):
		if pj.live(c):
			pj.heal(c, c.max_hp * 0.03)
			# yakın parçalardan iyileştirici zerreler süzülür
			for q in 2:
				var sl = slugs[randi() % slugs.size()]
				if is_instance_valid(sl) and sl.visible:
					var mote := mi(_sphere(8), glow(Color(0.55, 1.0, 0.85, 0.9), 1.0))
					put(pj, mote, sl.global_position + Vector3.UP * 0.4)
					mote.scale = Vector3.ONE * 0.18
					var mtw := mote.create_tween()
					var s0: Vector3 = mote.global_position
					mtw.tween_method(func(u: float):
						if is_instance_valid(mote) and is_instance_valid(c):
							mote.global_position = s0.lerp(c.global_position + Vector3.UP, u) + Vector3.UP * sin(u * PI) * 1.2, 0.0, 1.0, 0.4)
					mtw.tween_callback(mote.queue_free)
			_ground_ring(pj, c.global_position, Color(0.5, 1.0, 0.8, 0.8), 0.3, 1.1, 0.5)
			pj.chakra_gain(c, 2.0), Callable())
	if c is Player:
		Buffs.add("katsuyu_bunretsu", 6.5, {"armor": 0.3, "_name": "Sümüklüböcek Bölünmesi", "_desc": "parçalar sürekli iyileştirir"})
	Sfx.play("smoke", at, 0.7)


# ================================================================== RASENGAN yapı taşı (yalnız bu grubun sarmal küre teknikleri)
## Sarmal küre: dönen sarmal öz + dışta beyaz rüzgâr çizgili kabuk
static func rasengan(s: float, near := 1.2) -> Node3D:
	var root := Node3D.new()
	var core := mi(_sphere(20), spiral_mat(near))
	core.scale = Vector3.ONE * s
	root.add_child(core)
	var wm := streak(Color(0.95, 0.98, 1.0, 0.8), 10.0, 5.0, near)
	var shell := mi(_sphere(16), wm)
	shell.scale = Vector3.ONE * s * 1.28
	root.add_child(shell)
	Game.safe_loops(shell.create_tween()).tween_property(shell, "rotation", Vector3(0.6, TAU, 0.3), 0.35).as_relative()
	return root


## Sarmal küre çarpması (Rasenrangan): küre öğütür, düz bir parça çizgisi halkası savrulur, taş kırıntıları
static func _ras_pop(pj: PathJutsu, p: Vector3) -> void:
	var m := spiral_mat(2.0, 14.0)
	var x := mi(_sphere(20), m)
	put(pj, x, p)
	x.scale = Vector3.ONE * 0.5
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3.ONE * 2.2, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, 0.25)
	tw.tween_callback(x.queue_free)
	var sm := streak(Color(0.85, 0.94, 1.0, 0.9), 14.0, 6.0, 2.0)
	var rg := mi(_annulus(0.6, 1.8, 32), sm)
	put(pj, rg, p)
	rg.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
	var rt := rg.create_tween()
	rt.tween_property(rg, "scale", Vector3.ONE * 1.6, 0.3).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_method(func(v: float): set_fade(sm, v), 1.0, 0.0, 0.3)
	rt.tween_callback(rg.queue_free)
	burst(pj, p, _m_chunk(), cel(Color.WHITE, 0.008, INK, false, 1.5), 10, 0.8, {"r": 0.3, "vmin": 3.0, "vmax": 7.0, "g": Vector3(0, -14, 0), "smin": 0.5, "smax": 1.0, "spin": 400.0})
	var g := pj.gp(p)
	if p.y - g.y < 1.6:
		_ground_ring(pj, g, Color(0.6, 0.85, 1.0, 0.8), 0.4, 1.6, 0.5, 2.0)


# ================================================================== RASENKYŪGAN — mermileri emen sarmal küre
static func rasenkyugan(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var ba = pj.bone_attach(c, "RightHand")
	var r: Node3D = null
	if ba:
		r = rasengan(0.5)
		ba.add_child(r)
		# emme alanı: kürenin çevresinde içe akan iki eğik çizgi halkası
		for k in 2:
			var sm := streak(Color(0.7, 0.88, 1.0, 0.75), 8.0, -4.0 - k, 1.2)
			var rg := mi(_annulus(0.38, 0.7, 28), sm)
			rg.rotation = Vector3(0.5 if k == 0 else -0.6, 0, 0.3)
			r.add_child(rg)
			Game.safe_loops(rg.create_tween()).tween_property(rg, "rotation:y", TAU * (1.0 if k == 0 else -1.0), 0.6).as_relative()
		pj.free_after(8.0, ba)
	pj.every(8.0, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP) < 4.0:
				_absorb_fx(pj, c, p.global_position, r)
				p.queue_free()
				if is_instance_valid(r):
					r.scale = r.scale * 1.12
				pj.chakra_gain(c, 5.0), Callable())
	if c is Player:
		Buffs.add("rasenkyugan", 8.0, {"armor": 0.6, "_name": "Emici Küre", "_desc": "yakındaki mermileri emip chakraya çevirir"})
	Sfx.play("wind", c.global_position, 1.6)


## Emilen mermi: yakalanan chakra ışığı sarmal çizerek küreye akar, kürede nabız halkası
static func _absorb_fx(pj: PathJutsu, c: Node3D, from: Vector3, r: Node3D) -> void:
	var mote := mi(_sphere(10), glow(Color(0.7, 0.9, 1.0, 1.0), 0.8))
	put(pj, mote, from)
	mote.scale = Vector3.ONE * 0.35
	var ph := randf() * TAU
	var tw := mote.create_tween()
	tw.tween_method(func(u: float):
		if not (is_instance_valid(mote) and is_instance_valid(c)):
			return
		var to: Vector3 = r.global_position if is_instance_valid(r) else c.global_position + Vector3.UP
		var q := from.lerp(to, u * u)
		var sw := (1.0 - u) * 0.6
		mote.global_position = q + Vector3(cos(ph + u * 9.0) * sw, sin(ph + u * 9.0) * sw * 0.6, sin(ph + u * 9.0) * sw)
		mote.scale = Vector3.ONE * lerpf(0.35, 0.08, u), 0.0, 1.0, 0.22)
	tw.tween_callback(func():
		if is_instance_valid(mote):
			mote.queue_free()
		if is_instance_valid(r):
			_flash(pj, r.global_position, Color(0.6, 0.85, 1.0, 0.9), 0.3, 1.4, 0.25, 0.0, 2.0, 1.0))
	_flash(pj, from, Color(0.7, 0.9, 1.0, 0.8), 0.6, 0.1, 0.2, 2.0)


# ================================================================== RASENRANGAN — havada beliren sarmal küreler yağar
static func rasenrangan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 26.0)
	var orbs = []
	for k in 8:
		var r := rasengan(0.5, 2.0)
		pj.get_tree().current_scene.add_child(r)
		var a = k * TAU / 8.0
		r.global_position = c.global_position + Vector3(cos(a) * 2.0, 2.4 + sin(a * 2.0) * 0.5, sin(a) * 2.0)
		r.scale = Vector3.ONE * 0.1
		r.create_tween().tween_property(r, "scale", Vector3.ONE, 0.3)
		# kaynaktaki gibi: her kürenin çevresinde eşmerkezli soluk halkalar
		var halo := mi(_quad(), sigil_mat(Color(0.6, 0.85, 1.0, 0.6), 0.0, 3.0, 1.0, 2.0, 0.5))
		halo.scale = Vector3.ONE * 1.5
		r.add_child(halo)
		# çakra yoktan toplanır
		burst(pj, r.global_position, _sphere(6), glow(Color(0.7, 0.9, 1.0), 1.0), 10, 0.3, {"r": 0.9, "vmin": 0.0, "vmax": 0.1, "g": Vector3.ZERO, "radial": -14.0, "smin": 0.05, "smax": 0.1, "end_scale": 0.3})
		orbs.append(r)
	pj.after(0.6, func():
		for k in orbs.size():
			var r: Node3D = orbs[k]
			if not is_instance_valid(r):
				continue
			var from = r.global_position
			r.queue_free()
			pj.after(k * 0.06, func():
				if pj.live(c):
					var orb := rasengan(0.5, 1.5)
					var tm := glow(Color(0.6, 0.85, 1.0, 0.7), 1.5, 0.0)
					var tail := mi(_m_tail(), tm)
					tail.scale = Vector3(8.0, 8.0, 1.6)
					tail.position = Vector3(0, 0, 0.2)
					orb.add_child(tail)
					var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, orb, pj.inf(c, "rasenrangan", 0.45, {"knock": 10.0, "kind": "heavy"}), tt, false, 1.6, func(p, _h):
						_ras_pop(pj, p))
					pr.homing_turn = 4.0))
	Sfx.play("wind", c.global_position, 1.0)


# ================================================================== RASENRENGAN — iki elde birer küre, art arda iki dev darbe
## Burgu çarpması: dev sarmal küre vuruş yönünde ilerleyip öğütür, iki burgu halkası, yerde sarmal oyuk izi
static func _ras_drill(pj: PathJutsu, at: Vector3, d: Vector3, s: float) -> void:
	var m := spiral_mat(3.0, 16.0)
	var x := mi(_sphere(24), m)
	put(pj, x, at)
	x.scale = Vector3.ONE * 0.6
	var tw := x.create_tween()
	tw.tween_property(x, "scale", Vector3.ONE * 2.2 * s, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(x, "global_position", at + d * 0.7, 0.3)
	tw.tween_method(func(v: float): set_fade(m, v), 1.0, 0.0, 0.3)
	tw.tween_callback(x.queue_free)
	var side := d.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for k in 2:
		var sm := streak(Color(0.9, 0.97, 1.0, 0.9), 12.0, 8.0 + k * 3.0, 2.5)
		var rg := mi(_annulus(0.9 * s, (1.6 + k * 0.5) * s, 36), sm)
		put(pj, rg, at + d * (0.2 + k * 0.4))
		rg.global_transform.basis = Basis(side, d, side.cross(d).normalized())   # halka düzlemi vuruş yönüne dik
		var rt := rg.create_tween()
		rt.tween_property(rg, "scale", Vector3.ONE * 1.5, 0.35).set_ease(Tween.EASE_OUT)
		rt.parallel().tween_method(func(v: float): set_fade(sm, v), 1.0, 0.0, 0.35)
		rt.tween_callback(rg.queue_free)
	burst(pj, at, _m_chunk(), cel(Color.WHITE, 0.008, INK, false, 1.5), 16, 0.9, {"r": 0.5, "dir": d + Vector3.UP * 0.4, "spread": 40.0, "vmin": 5.0, "vmax": 11.0, "g": Vector3(0, -14, 0), "smin": 0.6, "smax": 1.2, "spin": 400.0})
	# yerde sarmal oyuk
	var g := pj.gp(at + d * 0.6)
	var gm := cel(Color(0.18, 0.15, 0.13, 0.75), 0.0, INK, true, 3.0)
	var pts := []
	for i in 30:
		var u := float(i) / 29.0
		var a := u * TAU * 1.6
		pts.append(Vector3(cos(a), 0.0, sin(a)) * (0.2 + u * 1.3 * s))
	var sp := mi(_ribbon(pts, 0.28 * s, Vector3.UP), gm)
	put(pj, sp, g + Vector3.UP * 0.05)
	fade_free(sp, gm, 2.4, 0.8)


static func rasenrengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	pj.busy(c, 1.0)
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			ba.add_child(rasengan(0.45))
			pj.free_after(1.0, ba)
	for k in 2:
		pj.after(0.3 + k * 0.35, func():
			if not pj.live(c):
				return
			var d = pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
			pj.anim(c, "cross" if k == 0 else "hook", 1.8)
			var at = c.global_position + Vector3.UP * 1.2 + d * 1.3
			_ras_drill(pj, at, d, 1.0 + k * 0.35)
			var hs = pj.hit(c, at, 2.2, pj.inf(c, "rasenrengan", 1.2, {"knock": 14.0 + k * 8.0, "launch": 3.0, "kind": "heavy"}))
			if not hs.is_empty():
				_flash(pj, at, Color(0.85, 0.95, 1.0, 1.0), 0.5, 3.0 + k, 0.2, 1.0))
	Sfx.play("wind", c.global_position, 1.3)


# ================================================================== OIROKE — pembe bulutlu şaka dönüşümü
## Kendi pofuduk bulut topağı: üst üste yuvarlak kabarcıklar (cel, koyu kontur)
static func _m_cloud() -> Mesh:
	return _cached("cloud", func():
		var b := MB.new()
		b.add("sphere", Vector3(0, 0, 0), Vector3(0.6, 0.45, 0.5), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.35, 0.05, 0.05), Vector3(0.45, 0.38, 0.42), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(-0.33, 0.02, -0.04), Vector3(0.42, 0.34, 0.4), Color.WHITE, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.1, 0.22, 0.0), Vector3(0.4, 0.36, 0.38), Color.WHITE, Vector3.ZERO, 10)
		return b.build())


static func _m_heart() -> Mesh:
	return _cached("heart", func(): return slab_mesh(_heart(0.3), 0.05, Color.WHITE, Transform3D(_up_b(), Vector3.ZERO)))


static func _pink_pop(pj: PathJutsu, c: Node3D) -> void:
	var base: Vector3 = c.global_position
	var cm := cel(Color(1.0, 0.94, 0.97), 0.02, Color(0.55, 0.25, 0.42), false, 2.0, 0.25)
	var pm := cel(PINK, 0.02, Color(0.55, 0.2, 0.4), false, 2.0, 0.25)
	# kaynaktaki gibi bedeni yatay bulut kuşakları sarar (dönerek açılır)
	for band in 3:
		var y := 0.5 + band * 0.55
		var ring := Node3D.new()
		put(pj, ring, base + Vector3.UP * y)
		var n := 7
		for q in n:
			var a := TAU * q / n + band * 0.4
			var cl := mi(_m_cloud(), pm if (q + band) % 3 == 0 else cm)
			cl.position = Vector3(cos(a), 0, sin(a)) * 0.55
			cl.rotation.y = -a
			cl.scale = Vector3.ONE * randf_range(0.9, 1.2)
			ring.add_child(cl)
		ring.scale = Vector3.ONE * 0.2
		var tw := ring.create_tween()
		tw.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(ring, "rotation:y", 1.4 * (1.0 if band % 2 == 0 else -1.0), 1.1)
		tw.tween_property(ring, "scale", Vector3(2.4, 0.05, 2.4), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(ring.queue_free)
	# pat! — dışa savrulan küçük pembe-beyaz bulutçuklar
	burst(pj, base + Vector3.UP * 1.1, _m_cloud(), cm, 10, 0.8, {"r": 0.4, "vmin": 2.5, "vmax": 4.5, "g": Vector3(0, 1.0, 0), "damp": 4.0, "smin": 0.4, "smax": 0.7, "end_scale": 0.1, "spin": 60.0})
	burst(pj, base + Vector3.UP * 1.1, _m_cloud(), pm, 6, 0.8, {"r": 0.4, "vmin": 2.5, "vmax": 4.5, "g": Vector3(0, 1.0, 0), "damp": 4.0, "smin": 0.35, "smax": 0.6, "end_scale": 0.1, "spin": 60.0})
	# kalpler süzülür, pırıltılar çakar
	burst(pj, base + Vector3.UP * 1.6, _m_heart(), cel(Color(1.0, 0.45, 0.65), 0.01, Color(0.5, 0.1, 0.25), false, 1.5), 8, 1.4, {"r": 0.5, "dir": Vector3.UP, "spread": 50.0, "vmin": 0.8, "vmax": 1.8, "g": Vector3(0, 0.4, 0), "smin": 0.6, "smax": 1.0, "spin": 40.0, "expl": 0.7})
	for k in 4:
		pj.after(0.05 + k * 0.08, func():
			_flash(pj, base + Vector3(randf_range(-0.7, 0.7), randf_range(0.6, 2.0), randf_range(-0.7, 0.7)), Color(1.0, 0.8, 0.95, 1.0), 0.1, 0.6, 0.25, 1.0))


static func oiroke_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	_pink_pop(pj, c)
	Sfx.play("poof", c.global_position, 1.3)
	# oyunun genel dönüşüm buff'ı (genel motorun "transform" dalı) aynen
	var d: Dictionary = Data.jutsu.get("oiroke_no_jutsu", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 10.0 + tier * 3.0
	var mods = {"armor": maxf(0.5, 0.9 - 0.06 * tier), "melee": 1.05 + 0.04 * tier}
	Buffs.add(String(d.get("id", "buff")), dur, mods)
	if c is Player:
		Hud.msg("%s: %d sn" % [String(d.get("name", "")).split(" (")[0], int(dur)], PINK.lightened(0.3))
	Sfx.play("seal", c.global_position, 0.8)


# ================================================================== REİKA — ruh bedenden yükselir
## Ruh silueti: baş, omuzlu gövde, kollar; alt ucu kuyruk gibi incelen hayalet beden
static func _m_ghost() -> Mesh:
	return _cached("ghost", func():
		var b := MB.new()
		b.add("sphere", Vector3(0, 1.55, 0), Vector3(0.3, 0.34, 0.3), Color.WHITE, Vector3.ZERO, 12)
		b.add("sphere", Vector3(0, 1.1, 0), Vector3(0.58, 0.7, 0.36), Color.WHITE, Vector3.ZERO, 12)
		b.add("cone", Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.32), Color.WHITE, Vector3(180, 0, 0), 12)
		for sx in [-1.0, 1.0]:
			b.add_xf("cyl", _seg_xf(Vector3(sx * 0.27, 1.32, 0), Vector3(sx * 0.42, 0.85, 0.12), 0.12), Color.WHITE, 8)
			b.add("sphere", Vector3(sx * 0.43, 0.82, 0.13), Vector3(0.12, 0.12, 0.12), Color.WHITE, Vector3.ZERO, 8)
		return b.build())


static func reika_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var base: Vector3 = c.global_position
	var gm := ghost_mat(Color(0.82, 0.92, 1.0), Color(0.25, 0.38, 0.55), 2.2, 0.22)
	var soul := mi(_m_ghost(), gm)
	put(pj, soul, base)
	soul.rotation.y = atan2(-c.face_dir().x, -c.face_dir().z) if c.has_method("face_dir") else 0.0
	var dest: Vector3 = base + Vector3.UP * 1.5 + (c.face_dir() if c.has_method("face_dir") else Vector3.FORWARD) * 2.0
	var tw := soul.create_tween()
	tw.tween_property(soul, "global_position", dest, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(soul, "scale", Vector3(1.2, 1.2, 1.2), 0.8)
	tw.tween_property(soul, "scale", Vector3(0.4, 2.2, 0.4), 0.3).set_ease(Tween.EASE_IN)   # yukarı süzülüp çözülür
	tw.parallel().tween_method(func(v: float): set_fade(gm, v), 1.0, 0.0, 0.3)
	tw.tween_callback(soul.queue_free)
	# kaynaktaki gibi ince ışık sütunu ve yerde soluk halkalar
	var bm := glow(Color(0.8, 0.92, 1.0, 0.7), 3.0, 1.0)
	var beam := mi(_sphere(10), bm)
	put(pj, beam, base + Vector3.UP * 3.0)
	beam.scale = Vector3(0.12, 6.0, 0.12)
	var bt := beam.create_tween()
	bt.tween_property(beam, "scale", Vector3(0.3, 6.5, 0.3), 0.25)
	bt.tween_property(beam, "scale", Vector3(0.02, 7.0, 0.02), 0.45)
	bt.tween_callback(beam.queue_free)
	for k in 3:
		var a := TAU * k / 3.0 + randf()
		_ground_ring(pj, base + Vector3(cos(a), 0, sin(a)) * 1.3, Color(0.7, 0.85, 1.0, 0.8), 0.35, 0.55, 1.2)
	# ruh kuyruğundan dökülen soluk tutamlar
	burst(pj, base + Vector3.UP * 1.0, _sphere(8), glow(Color(0.8, 0.9, 1.0, 0.8), 1.2), 16, 1.2, {"r": 0.4, "dir": Vector3.UP, "spread": 30.0, "vmin": 1.0, "vmax": 2.2, "g": Vector3(0, 0.5, 0), "smin": 0.08, "smax": 0.16, "end_scale": 0.2, "expl": 0.4})
	_henge(c)


## Oyunun Henge kılığı sistemi (Jutsu.j_henge) aynen; görünüş bu dosyanın
static func _henge(c: Node3D) -> void:
	if not c is Player:
		return
	if c.get_node_or_null("Disguise"):
		var s0 = c.get_node_or_null("HengeSync")
		if s0:
			s0.free()
		var d0 = c.get_node_or_null("Disguise")
		if d0:
			d0.name = "DisguiseOld"
			d0.queue_free()
		if c.get("model") and is_instance_valid(c.model):
			c.model.visible = true
		Buffs.remove("henge")
	Buffs.add("henge", 25.0, {"stealth": 1.0})
	c.model.visible = false
	var disguise = CharacterModel.new()
	disguise.name = "Disguise"
	c.add_child(disguise)
	var tops = [Color(0.5, 0.6, 0.45), Color(0.6, 0.35, 0.3), Color(0.8, 0.75, 0.55), Color(0.4, 0.45, 0.6)]
	var t0: Color = tops.pick_random()
	disguise.setup({"gender": ["m", "f"].pick_random(), "top": t0, "top2": t0.darkened(0.15), "top_style": "uzun", "pants_style": "sivil",
		"pants": Color(0.35, 0.3, 0.28), "sandal": Color(0.3, 0.22, 0.15), "band": null, "vest": null, "hair_style": ["kısa", "uzun", "kase"].pick_random(),
		"hair": Color(0.25, 0.18, 0.1), "age": "adult"})
	disguise.position = c.model.position
	disguise.rotation = c.model.rotation
	var hs_cls = Jutsu.get_script().get_script_constant_map().get("HengeSync")
	if hs_cls:
		var sync = hs_cls.new()
		sync.name = "HengeSync"
		sync.owner_body = c
		sync.disguise = disguise
		c.add_child(sync)
	Hud.msg("Henge: köylü kılığındasın. Saldırırsan bozulur.", Color(0.9, 0.9, 0.7))


# ================================================================== HŌSHI — pamuk spor klonları yapışıp çakra emer
## Spor klonu: pamuk topağı gövde + baş, kapalı gözlü sade yüz çizgileri (kaynak)
static func _m_spore() -> Mesh:
	return _cached("spore", func():
		var b := MB.new()
		b.add("sphere", Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.6), COTTON, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.22, 0.35, 0.12), Vector3(0.38, 0.42, 0.36), COTTON, Vector3.ZERO, 8)
		b.add("sphere", Vector3(-0.24, 0.5, 0.06), Vector3(0.36, 0.4, 0.34), COTTON, Vector3.ZERO, 8)
		b.add("sphere", Vector3(0, 0.95, 0.05), Vector3(0.45, 0.45, 0.45), COTTON, Vector3.ZERO, 10)
		b.add("sphere", Vector3(0.12, 1.1, 0.0), Vector3(0.22, 0.2, 0.22), COTTON, Vector3.ZERO, 8)
		for sx in [-1.0, 1.0]:
			b.add("box", Vector3(sx * 0.08, 0.98, 0.27), Vector3(0.07, 0.012, 0.01), Color(0.35, 0.35, 0.38), Vector3(0, 0, sx * 12.0))
		b.add("box", Vector3(0, 0.86, 0.27), Vector3(0.06, 0.01, 0.01), Color(0.4, 0.38, 0.4))
		return b.build())


static func _fluff(pj: PathJutsu, pos: Vector3, n: int, r: float) -> void:
	burst(pj, pos, _m_blob(), cel(COTTON, 0.006, Color(0.45, 0.45, 0.5), false, 1.5), n, 1.6, {"r": r, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -0.6, 0), "damp": 1.5, "smin": 0.25, "smax": 0.55, "spin": 90.0, "end_scale": 0.3, "hold": 0.5})


static func hoshi_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var targets = pj.enemies_near(c, c.global_position, 16.0)
	var tt = pj.tg(c, t, 16.0)
	if tt and not targets.has(tt):
		targets.append(tt)
	# bedenden pamuk gibi spor tutamları kopar
	_fluff(pj, c.global_position + Vector3.UP, 22, 0.6)
	var sm := cel(Color.WHITE, 0.015, Color(0.4, 0.4, 0.46), false, 1.5, 0.2)
	var n = 0
	for e in targets:
		for k in 2:
			n += 1
			pj.after(0.2 + n * 0.07, func():
				if not (pj.live(c) and pj.live(e)):
					return
				var sn := mi(_m_spore(), sm)
				pj.get_tree().current_scene.add_child(sn)
				sn.global_position = c.global_position + Vector3.UP
				var off = Vector3(randf_range(-0.4, 0.4), randf_range(0.3, 1.3), randf_range(-0.4, 0.4))
				var tw = sn.create_tween()
				tw.tween_method(func(u: float):
					if is_instance_valid(sn) and is_instance_valid(e):
						sn.global_position = (c.global_position + Vector3.UP).lerp(e.global_position + off, u) + Vector3.UP * sin(u * PI) * 2.5, 0.0, 1.0, 0.45)
				tw.tween_callback(func():
					if is_instance_valid(sn) and is_instance_valid(e):
						sn.reparent(e)
						var tw2 = sn.create_tween()
						tw2.tween_property(sn, "scale", Vector3.ONE * 1.6, 3.5)
						tw2.tween_callback(func():
							_fluff(pj, sn.global_position + Vector3.UP * 0.5, 12, 0.5)   # spor patlar, pamuk tutamlarına dağılır
							sn.queue_free()))
				pj.every(3.5, 0.5, func(_i, _k):
					if pj.live(e) and pj.live(c):
						e.take_hit(pj.inf(c, "hoshi_no_jutsu", 0.1, {"knock": 0.0, "kind": "light", "chakra_drain": 5.0}))
						# emilen çakra: hedeften spora akan mavi zerre
						if is_instance_valid(sn) and sn.is_inside_tree():
							var mote := mi(_sphere(8), glow(Color(0.45, 0.75, 1.0, 1.0), 1.0))
							put(pj, mote, e.global_position + Vector3.UP * 1.0)
							mote.scale = Vector3.ONE * 0.14
							var mt := mote.create_tween()
							mt.tween_property(mote, "global_position", sn.global_position + Vector3.UP * 0.5, 0.3)
							mt.tween_callback(mote.queue_free)
						pj.chakra_gain(c, 2.0), Callable()))
	Sfx.play("smoke", c.global_position, 1.2)


# ================================================================== NARİKAWARİ — deri kabuk soyulur, beden geri sıçrar
static func _m_flake() -> Mesh:
	return _cached("flake", func():
		var b := MB.new()
		var o := PackedVector2Array([Vector2(-0.1, -0.06), Vector2(0.02, -0.08), Vector2(0.11, -0.03), Vector2(0.09, 0.06), Vector2(-0.02, 0.08), Vector2(-0.11, 0.03)])
		b.add_slab(o, 0.008, Color.WHITE, Transform3D(Basis(Vector3.RIGHT, 0.4) * _up_b(), Vector3.ZERO))
		b.add_slab(o, 0.008, Color(0.92, 0.9, 0.88), Transform3D(Basis(Vector3.RIGHT, -0.5) * _up_b(), Vector3(0, -0.06, 0.02)))
		return b.build())


static func _skin_shed(pj: PathJutsu, pos: Vector3, n: int, down := false) -> void:
	burst(pj, pos, _m_flake(), cel(SKIN, 0.008, Color(0.35, 0.22, 0.14), true, 1.2), n, 1.3, {"r": 0.5, "dir": Vector3.DOWN if down else Vector3.UP, "spread": 70.0 if down else 85.0, "vmin": 1.0, "vmax": 3.5, "g": Vector3(0, -5, 0), "damp": 1.2, "spin": 300.0, "smin": 0.8, "smax": 1.5, "end_scale": 0.5})


static func narikawari_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.3)
	if c is Player:
		Buffs.add("narikawari", 4.0, {"armor": 0.0, "_name": "İkame Beden", "_desc": "sonraki darbe ikame bedene gider"})
	var _shell = pj.decoy(c, c.global_position, 4.0, func(pos):
		# ikame kabuk vurulunca buruşup deri pullarına dökülür, yerde kalır
		_skin_shed(pj, pos + Vector3.UP, 26, true)
		var lm := cel(SKIN.darkened(0.1), 0.006, Color(0.35, 0.22, 0.14), true, 1.5)
		var b := MB.new()
		for i in 14:
			var a := randf() * TAU
			var dd := sqrt(randf()) * 0.9
			b.add_slab(_blob2d(0.08, 7, 0.4), 0.006, Color.WHITE, Transform3D(Basis(Vector3.UP, randf() * TAU) * _flat_b(), Vector3(cos(a) * dd, 0.0, sin(a) * dd)))
		var litter := mi(b.build(), lm)
		put(pj, litter, pj.gp(pos) + Vector3.UP * 0.04)
		fade_free(litter, lm, 2.0, 0.8))
	var from: Vector3 = c.global_position
	# soyulma: kabuktan deri pulları kopar
	_skin_shed(pj, from + Vector3.UP * 1.0, 18)
	c.global_position = pj.gp(c.global_position - c.face_dir() * 4.0)
	# geri sıçrayışta soluk ardıl görüntüler + yerde kayma izleri
	var gm := ghost_mat(Color(0.98, 0.9, 0.8), Color(0.45, 0.32, 0.22), 1.5, 0.25)
	for k in 3:
		var u := (k + 1) / 4.0
		var gh := mi(_m_ghost(), gm)
		put(pj, gh, from.lerp(c.global_position, u))
		gh.scale = Vector3(1.0, 1.05, 1.0)
		gh.rotation.y = atan2(-c.face_dir().x, -c.face_dir().z)
		fade_free(gh, gm, 0.05 * k, 0.3)
	var dm := streak(Color(0.45, 0.38, 0.3, 0.8), 6.0, 2.0, 2.0)
	var mid: Vector3 = (from + c.global_position) * 0.5
	var pts := [from - mid, Vector3.ZERO, c.global_position - mid]
	for i in pts.size():
		pts[i] = Vector3(pts[i].x, 0.0, pts[i].z)
	var skid := mi(_ribbon(pts, 0.6, Vector3.UP, Color.WHITE, false), dm)
	put(pj, skid, pj.gp(mid) + Vector3.UP * 0.06)
	fade_free(skid, dm, 0.6, 0.6)
	_ground_ring(pj, c.global_position, Color(0.9, 0.82, 0.7, 0.6), 0.3, 1.3, 0.4)
	Sfx.play("poof", c.global_position, 1.1)
