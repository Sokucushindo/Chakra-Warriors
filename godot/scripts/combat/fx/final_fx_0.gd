class_name FinalFX0
extends RefCounted
## Son karma grup 0: Gogyō Fūin, Kokumu Gakure, Hankyōtei, Funato (Shiomaneki / Isō Ryōdan), Hatake ninken, Ryōken Bunshin,
## Suika, Mizudeppō, Magen Kijō no Rōkaku, Hyūga (Jūken / Ichigekishin / Sōke Juinjutsu), Iburi (Kemuri Ude / Sanka Kemuri /
## Kemuri Rōgoku). Her tekniğin görünüşü bu dosyada sıfırdan üretilir (kendi gölgelendiricileri: cel duman, cel su, mor alev,
## ince yankı halkası, kıskaç kabuğu...). Ortak efekt kütüphanesi kullanılmaz.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, gerçek çağrılar: ninken sürüsü, köpek klonları, istiridye, serap kopyalar,
## Byakugan göz sistemi, kıskaç meta kaydı) ana ağaçtaki işleyicilerden satır satır taşındı.

const PURPLE := Color(0.72, 0.42, 1.0)
const PURPLE_LT := Color(0.97, 0.8, 1.0)
const PURPLE_INK := Color(0.26, 0.05, 0.42)
const ECHO := Color(0.82, 0.92, 1.0)
const ECHO_EDGE := Color(0.32, 0.44, 0.6)
const CRAB_SHELL := Color(0.58, 0.22, 0.13)
const CRAB_HI := Color(0.8, 0.4, 0.25)
const CRAB_BLADE := Color(0.82, 0.88, 0.95)
const CRAB_INK := Color(0.16, 0.05, 0.03)
const CUT_RED := Color(0.98, 0.4, 0.22)
const EARTH := Color(0.47, 0.36, 0.25)
const EARTH_DK := Color(0.2, 0.14, 0.1)
const INK := Color(0.06, 0.05, 0.05)
const PAPER := Color(0.93, 0.88, 0.74)
const BLOOD := Color(0.62, 0.04, 0.06)
const FUR := Color(0.74, 0.58, 0.38)
const FUR_LT := Color(0.96, 0.9, 0.76)
const JUKEN := Color(0.74, 0.9, 1.0)
const JUKEN_DK := Color(0.16, 0.3, 0.62)
const CAGE := Color(0.26, 1.0, 0.52)
const CAGE_DK := Color(0.02, 0.32, 0.13)
const RUST := Color(0.74, 0.34, 0.12)
const EMBER := Color(1.0, 0.55, 0.18)

# cel duman paletleri: [aydınlık, gölge, kenar çizgisi]
const FOG_PAL = [Color(0.17, 0.25, 0.43, 0.93), Color(0.05, 0.07, 0.13, 1.0), Color(0.01, 0.02, 0.05, 1.0)]
const STEAM_PAL = [Color(0.98, 0.98, 1.0, 0.82), Color(0.8, 0.82, 0.88, 1.0), Color(0.56, 0.59, 0.67, 1.0)]
const DUST_PAL = [Color(0.76, 0.66, 0.5, 0.85), Color(0.52, 0.43, 0.32, 1.0), Color(0.3, 0.23, 0.17, 1.0)]
const SMOKE_PAL = [Color(0.8, 0.8, 0.82, 0.95), Color(0.52, 0.52, 0.57, 1.0), Color(0.24, 0.24, 0.29, 1.0)]
const RUST_PAL = [Color(0.66, 0.53, 0.4, 0.9), Color(0.4, 0.29, 0.22, 1.0), Color(0.2, 0.12, 0.08, 1.0)]
const PRISON_PAL = [Color(0.42, 0.42, 0.46, 0.94), Color(0.22, 0.22, 0.26, 1.0), Color(0.08, 0.08, 0.1, 1.0)]

static var _cache := {}


# ================================================================== gölgelendiriciler (kendi)
const NOISE_FN := """
float hsh(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hsh(i), hsh(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hsh(i + vec3(0.0, 1.0, 0.0)), hsh(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hsh(i + vec3(0.0, 0.0, 1.0)), hsh(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hsh(i + vec3(0.0, 1.0, 1.0)), hsh(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
"""

## Cel duman topağı: iki ton ışık + koyu kenar çizgisi, gürültüyle topak topak yüzey, aşınarak (delik delik) söner;
## kameraya yakın kısım yumuşakça incelir (ekranı kaplamaz)
const CLOUD_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
instance uniform vec4 lit_col : source_color = vec4(0.8, 0.8, 0.82, 0.9);
instance uniform vec4 shd_col : source_color = vec4(0.5, 0.5, 0.55, 1.0);
instance uniform vec4 edge_col : source_color = vec4(0.2, 0.2, 0.24, 1.0);
instance uniform float fade = 1.0;
instance uniform float erode = 0.0;
instance uniform float seed = 0.0;
instance uniform float near_a = 1.5;
instance uniform float near_b = 6.0;
varying vec3 lp;
%NOISE%
void vertex() {
	lp = VERTEX;
	float n = vnoise(VERTEX * 2.6 + vec3(seed));
	VERTEX += NORMAL * (n - 0.5) * 0.3;
}
void fragment() {
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.35, 0.9, 0.25, 0.0)).xyz);
	float l = dot(NORMAL, ld) + (vnoise(lp * 5.0 + vec3(seed)) - 0.5) * 0.55;
	vec3 c = mix(shd_col.rgb, lit_col.rgb, step(0.0, l));
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	c = mix(c, edge_col.rgb, step(0.7, fr));
	float hole = vnoise(lp * 3.2 + vec3(seed * 1.7, -TIME * 0.5, 0.0));
	if (hole < erode) {
		discard;
	}
	float near = smoothstep(near_a, near_b, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(lit_col.a * fade * near, 0.0, 1.0);
}
"""

## Düz renk (köşe rengi × ton): çizgi, şerit, mühür, iz; yakın kısım söner
const FLAT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
instance uniform float near_a = 0.5;
instance uniform float near_b = 2.0;
void fragment() {
	float near = smoothstep(near_a, near_b, -VERTEX.z);
	ALBEDO = COLOR.rgb * tint.rgb;
	ALPHA = clamp(COLOR.a * tint.a * fade * near, 0.0, 1.0);
}
"""

## Katı cel gövde (kıskaç, kesek, yumruk): iki ton + parlak leke + koyu kenar
const CEL_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float fade = 1.0;
void fragment() {
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.3, 0.9, 0.35, 0.0)).xyz);
	float l = dot(NORMAL, ld);
	vec3 base = COLOR.rgb * tint.rgb;
	vec3 c = mix(base * 0.6, base, step(0.0, l));
	vec3 h = normalize(ld + VIEW);
	c = mix(c, mix(base, vec3(1.0), 0.75), step(0.94, dot(NORMAL, h)));
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	c = mix(c, base * 0.3, step(0.82, fr));
	float near = smoothstep(0.3, 0.9, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(fade * near, 0.0, 1.0);
}
"""

## Kenar çizgisi (ters kabuk)
const HULL_SH := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix;
instance uniform vec4 ink : source_color = vec4(0.08, 0.05, 0.05, 1.0);
instance uniform float width = 0.02;
instance uniform float fade = 1.0;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	float near = smoothstep(0.4, 1.2, -VERTEX.z);
	ALBEDO = ink.rgb;
	ALPHA = clamp(ink.a * fade * near, 0.0, 1.0);
}
"""

## İnce halka (düzlem / dörtgen UV'sinden): yankı, dalgacık, basınç halkası; ekran ölçüsünde kenar yumuşatma, istenirse kesik kesik
const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 tint : source_color = vec4(0.85, 0.92, 1.0, 1.0);
instance uniform vec4 edge : source_color = vec4(0.3, 0.4, 0.55, 1.0);
instance uniform float radius = 0.3;
instance uniform float width = 0.01;
instance uniform float fade = 1.0;
instance uniform float dashes = 0.0;
instance uniform float near_a = 0.6;
instance uniform float near_b = 2.5;
void fragment() {
	vec2 q = UV - vec2(0.5);
	float d = length(q);
	float aa = fwidth(d) * 1.5;
	float w = max(width, aa);
	float core = 1.0 - smoothstep(w * 0.4, w * 0.4 + aa, abs(d - radius));
	float body = 1.0 - smoothstep(w, w + aa, abs(d - radius));
	float a = body;
	if (dashes > 0.5) {
		float ang = atan(q.y, q.x);
		a *= step(0.45, fract(ang * dashes / 6.2831853));
	}
	vec3 c = mix(edge.rgb, tint.rgb, core);
	float near = smoothstep(near_a, near_b, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(a * mix(edge.a, tint.a, core) * fade * near, 0.0, 1.0);
}
"""

## Mor parmak ucu alevi (ref: Gogyō Fūin): kameraya dönük damla biçimi, titreyen dil, açık çekirdek, koyu mor kenar, içinde işaret
const FLAME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform vec4 outer : source_color = vec4(0.72, 0.42, 1.0, 0.95);
instance uniform vec4 inner : source_color = vec4(0.97, 0.8, 1.0, 1.0);
instance uniform vec4 ink : source_color = vec4(0.26, 0.05, 0.42, 1.0);
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;
instance uniform float glyph = 1.0;
%NOISE%
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float y = 1.0 - UV.y;
	float n = vnoise(vec3(UV.x * 4.0 + seed, y * 3.0 - TIME * 3.5, seed));
	float x = (UV.x - 0.5) * 2.0 + (n - 0.5) * 0.6 * y;
	float wdt = sqrt(clamp(y * 4.0, 0.0, 1.0)) * (1.0 - y) * 1.15 - (n - 0.5) * 0.25 * y;
	float e = wdt - abs(x);
	if (e < 0.0) {
		discard;
	}
	vec3 c = outer.rgb;
	c = mix(c, inner.rgb, step(wdt * 0.55, e) * step(y, 0.6));
	float mark = max(step(abs(x), 0.05) * step(abs(y - 0.3), 0.11), step(abs(y - 0.33), 0.03) * step(abs(x), 0.16));
	c = mix(c, outer.rgb * 0.8 + vec3(0.2), mark * glyph);
	c = mix(ink.rgb, c, step(0.1, e));
	ALBEDO = c;
	ALPHA = clamp(fade * outer.a, 0.0, 1.0);
}
"""

## Cel su: iki ton mavi, akan ak çizgiler, parlak leke, koyu mavi kenar; sweep/ceil ile bedenin yukarıdan aşağı suya dönmesi
const WATER_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec4 body : source_color = vec4(0.64, 0.85, 1.0, 0.74);
uniform vec4 deep : source_color = vec4(0.27, 0.54, 0.93, 0.85);
uniform vec4 edge_c : source_color = vec4(0.08, 0.28, 0.75, 1.0);
uniform float flow = 2.5;
uniform float sweep = -10000.0;
uniform float ceil_y = 10000.0;
instance uniform float fade = 1.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (wp.y < sweep || wp.y > ceil_y) {
		discard;
	}
	vec3 ld = normalize((VIEW_MATRIX * vec4(0.3, 0.9, 0.3, 0.0)).xyz);
	float l = dot(NORMAL, ld);
	vec3 c = mix(deep.rgb, body.rgb, step(-0.1, l));
	float sl = sin(wp.y * 9.0 + TIME * flow + sin(wp.x * 4.0 + wp.z * 3.0) * 1.6);
	c = mix(c, vec3(0.94, 0.98, 1.0), step(0.86, sl) * 0.8);
	vec3 h = normalize(ld + VIEW);
	c = mix(c, vec3(1.0), step(0.95, dot(NORMAL, h)));
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	c = mix(c, edge_c.rgb, step(0.74, fr));
	float near = smoothstep(0.3, 1.2, -VERTEX.z);
	ALBEDO = c;
	ALPHA = clamp(mix(body.a, 1.0, step(0.74, fr)) * fade * near, 0.0, 1.0);
}
"""

## Beden kenarı ışıması (yankıda bulunan hedef) / ısı titremesi (serap kopya)
const RIM_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec4 col : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float amt = 1.0;
uniform float shimmer = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.45, 0.8, fr);
	float band = step(0.7, sin(wp.y * 22.0 - TIME * 6.0 + sin(wp.x * 5.0 + TIME * 2.0) * 2.0));
	float a = rim * amt + shimmer * (0.22 + 0.35 * band);
	ALBEDO = col.rgb;
	ALPHA = clamp(a * col.a, 0.0, 1.0);
}
"""


# ================================================================== altyapı
static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _scene() -> Node:
	return _tree().current_scene


static func _later(sec: float, fn: Callable) -> void:
	_tree().create_timer(sec).timeout.connect(fn)


static func _mat(key: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _cache.has(k):
		var code := ""
		match key:
			"cloud":
				code = CLOUD_SH.replace("%NOISE%", NOISE_FN)
			"cloud2":
				code = CLOUD_SH.replace("%NOISE%", NOISE_FN).replace("cull_back", "cull_disabled")
			"flat":
				code = FLAT_SH
			"add":
				code = FLAT_SH.replace("blend_mix", "blend_add")
			"cel":
				code = CEL_SH
			"hull":
				code = HULL_SH
			"ring":
				code = RING_SH
			"flame":
				code = FLAME_SH.replace("%NOISE%", NOISE_FN)
			"water":
				code = WATER_SH
			"water2":
				code = WATER_SH.replace("cull_back", "cull_disabled")
			"rim":
				code = RIM_SH
		var sh = Shader.new()
		sh.code = code
		var m = ShaderMaterial.new()
		m.shader = sh
		_cache[k] = m
	return _cache[k]


static func _sphere(seg := 12) -> SphereMesh:
	var k = "mesh:sph%d" % seg
	if not _cache.has(k):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = seg
		s.rings = maxi(4, seg / 2)
		_cache[k] = s
	return _cache[k]


static func _quad() -> QuadMesh:
	if not _cache.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2.ONE
		_cache["mesh:quad"] = q
	return _cache["mesh:quad"]


static func _plane() -> PlaneMesh:
	if not _cache.has("mesh:plane"):
		var p = PlaneMesh.new()
		p.size = Vector2.ONE
		_cache["mesh:plane"] = p
	return _cache["mesh:plane"]


static func _box() -> BoxMesh:
	if not _cache.has("mesh:box"):
		var b = BoxMesh.new()
		b.size = Vector3.ONE
		_cache["mesh:box"] = b
	return _cache["mesh:box"]


static func _spike() -> CylinderMesh:
	if not _cache.has("mesh:spike"):
		var cm = CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.14
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		_cache["mesh:spike"] = cm
	return _cache["mesh:spike"]


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _add(n: Node3D, pos: Vector3, parent: Node = null) -> Node3D:
	var p = parent if parent != null else _scene()
	p.add_child(n)
	n.global_position = pos
	return n


static func _ip(gi: GeometryInstance3D, o: Dictionary) -> void:
	for k in o:
		gi.set_instance_shader_parameter(k, o[k])


static func _orient(n: Node3D, dir: Vector3) -> void:
	if dir.length() > 0.001:
		var d = dir.normalized()
		n.look_at(n.global_position + d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)


## Kökün ve altındaki tüm görsellerin "fade" değerini sürer; istenirse sonunda siler
static func _fade_all(root: Node3D, delay: float, t: float, from := 1.0, to := 0.0, kill := true) -> void:
	if root == null or not is_instance_valid(root):
		return
	var gis: Array = []
	if root is GeometryInstance3D:
		gis.append(root)
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		gis.append(g)
	var setf = func(x: float) -> void:
		for g in gis:
			if is_instance_valid(g):
				(g as GeometryInstance3D).set_instance_shader_parameter("fade", x)
	var tw = root.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(setf, from, to, maxf(0.01, t))
	if kill:
		tw.tween_callback(root.queue_free)


## Yerçekimli uçuş (kesek, damla, kıvılcım): süre sonunda silinir
static func _fly(n: Node3D, p0: Vector3, v: Vector3, g: float, life: float, shrink := true) -> void:
	var s0 = n.scale
	var step = func(x: float) -> void:
		if is_instance_valid(n):
			n.global_position = p0 + v * x + Vector3.DOWN * (0.5 * g * x * x)
			if shrink:
				n.scale = s0 * maxf(0.05, 1.0 - x / life * 0.85)
	var tw = n.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(n.queue_free)


## Tek renkli küçük parça (kıvılcım, damla, kesek, pul)
static func _bit(pos: Vector3, size: Vector3, col: Color, mode := "flat", near := Vector2(0.4, 1.6)) -> MeshInstance3D:
	var mi = _mi(_box() if mode != "drop" else _sphere(6), _mat("add" if mode == "add" else ("cel" if mode == "cel" else "flat")))
	if mode == "drop":
		mi.material_override = _water_mat()
	_add(mi, pos)
	mi.scale = size
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	if mode == "drop":
		return mi
	if mode == "cel":
		_ip(mi, {"tint": col})
	else:
		_ip(mi, {"tint": col, "near_a": near.x, "near_b": near.y})
	return mi


static func _water_mat() -> ShaderMaterial:
	return _mat("water")


## Cel duman topağı: büyür, kayar, delik delik aşınıp söner
static func _puff(pos: Vector3, size: float, pal: Array, vel: Vector3, life: float, grow := 1.6, near := Vector2(1.5, 6.0), squash := 1.0) -> MeshInstance3D:
	var mi = _mi(_sphere(14), _mat("cloud"))
	_add(mi, pos)
	_ip(mi, {"lit_col": pal[0], "shd_col": pal[1], "edge_col": pal[2], "seed": randf() * 40.0, "near_a": near.x, "near_b": near.y, "erode": 0.0, "fade": 1.0})
	var s1 = Vector3(1.0, squash, 1.0) * size
	mi.scale = s1 * 0.45
	mi.rotation.y = randf() * TAU
	var er = func(x: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("erode", x)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", s1 * grow, life).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if vel != Vector3.ZERO:
		tw.tween_property(mi, "global_position", pos + vel * life, life).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(er, 0.0, 1.0, life * 0.6).set_delay(life * 0.4)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Boru: noktalar boyunca halkalar (dokunaç, kıl, duman kolu, su sarmalı)
static func _tube(pts: Array, radii: Array, sides := 8, cols: Array = []) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if tg.length() < 0.0001:
			tg = Vector3.FORWARD
		tg = tg.normalized()
		var rf = Vector3.UP if absf(tg.y) < 0.9 else Vector3.RIGHT
		var bn = tg.cross(rf).normalized()
		var nm = bn.cross(tg).normalized()
		var r: float = radii[i]
		var col: Color = cols[i] if i < cols.size() else Color.WHITE
		for s in sides + 1:
			var a = TAU * float(s) / sides
			var off = bn * cos(a) + nm * sin(a)
			st.set_color(col)
			st.set_normal(off)
			st.set_uv(Vector2(float(s) / sides, float(i) / maxf(1.0, n - 1)))
			st.add_vertex(p + off * r)
	for i in n - 1:
		for s in sides:
			var a0 = i * (sides + 1) + s
			var b0 = a0 + sides + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## Düz şerit (düzlem normali n): mühür çizgisi, yarık, hilal
static func _strip(st: SurfaceTool, pts: Array, w: float, col: Color, n: Vector3, taper := true, lift := Vector3.ZERO) -> void:
	var cnt = pts.size()
	if cnt < 2:
		return
	var wid = func(i: int) -> float:
		if not taper:
			return w
		return w * (sin(PI * float(i) / float(cnt - 1)) * 0.75 + 0.25)
	for i in cnt - 1:
		var a: Vector3 = pts[i] + lift
		var b: Vector3 = pts[i + 1] + lift
		var tg = (b - a).normalized()
		var sd = tg.cross(n).normalized()
		var sa = sd * float(wid.call(i)) * 0.5
		var sb = sd * float(wid.call(i + 1)) * 0.5
		for v in [a - sa, a + sa, b + sb, a - sa, b + sb, b - sb]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(v)


static func _strip_begin() -> SurfaceTool:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Kenar çizgisi çocuğu (ters kabuk)
static func _outline(mi: MeshInstance3D, ink: Color, w: float) -> MeshInstance3D:
	var h = _mi(mi.mesh, _mat("hull"))
	mi.add_child(h)
	_ip(h, {"ink": ink, "width": w})
	return h


## Halka dörtgeni: yatay (yer) ya da bir yöne bakan dikey; radius/width dünya metresi
static func _ring(pos: Vector3, size: float, face: Vector3, tint: Color, edge: Color, r0: float, r1: float, w: float, t: float, o := {}) -> MeshInstance3D:
	var horizontal = face == Vector3.ZERO
	var mi = _mi(_plane() if horizontal else _quad(), _mat("ring"))
	_add(mi, pos)
	mi.scale = Vector3(size, 1.0, size) if horizontal else Vector3(size, size, 1.0)
	if not horizontal:
		_orient(mi, face)
	_ip(mi, {"tint": tint, "edge": edge, "radius": r0 / size, "width": w / size, "fade": 1.0,
		"dashes": float(o.get("dashes", 0.0)), "near_a": float(o.get("near_a", 0.6)), "near_b": float(o.get("near_b", 2.5))})
	var ease_ = int(o.get("ease", Tween.EASE_OUT))
	var setr = func(x: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("radius", x / size)
	var setf = func(x: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("fade", x)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_method(setr, r0, r1, t).set_trans(Tween.TRANS_CUBIC).set_ease(ease_)
	tw.tween_method(setf, 1.0, 0.0, t * 0.55).set_delay(t * 0.45)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Yer çatlakları: merkezden kırık kırık koyu çizgiler (yerde kalıp söner)
static func _cracks(at: Vector3, r: float, n: int, col: Color, life: float) -> MeshInstance3D:
	var st = _strip_begin()
	for k in n:
		var a = TAU * float(k) / n + randf_range(-0.25, 0.25)
		var pts = [Vector3(cos(a), 0, sin(a)) * r * 0.12]
		var L = r * randf_range(0.55, 1.0)
		for q in 4:
			a += randf_range(-0.4, 0.4)
			pts.append(pts[-1] + Vector3(cos(a), 0, sin(a)) * L * 0.25)
		_strip(st, pts, r * 0.05, col, Vector3.UP, true, Vector3.UP * 0.03)
		if randf() < 0.6:   # dal
			var b0: Vector3 = pts[2]
			var ba = a + randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0)
			_strip(st, [b0, b0 + Vector3(cos(ba), 0, sin(ba)) * L * 0.3], r * 0.03, col, Vector3.UP, true, Vector3.UP * 0.03)
	var mi = _mi(st.commit(), _mat("flat"))
	_add(mi, at)
	_ip(mi, {"tint": Color.WHITE, "near_a": 0.3, "near_b": 1.2})
	mi.scale = Vector3.ONE * 0.4
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_all(mi, life * 0.6, life * 0.4)
	return mi


## Toprak kesekleri: yerden saçılıp düşer
static func _clods(at: Vector3, n: int, spd: float, s := 1.0) -> void:
	for k in n:
		var a = randf() * TAU
		var col = EARTH.lerp(EARTH_DK, randf() * 0.6)
		var b = _bit(at + Vector3.UP * 0.1, Vector3(randf_range(0.08, 0.17), randf_range(0.06, 0.12), randf_range(0.08, 0.16)) * s, col, "cel")
		_fly(b, b.global_position, Vector3(cos(a) * randf_range(0.4, 1.0) * spd, randf_range(0.8, 1.4) * spd * 1.3, sin(a) * randf_range(0.4, 1.0) * spd), 16.0, randf_range(0.5, 0.85))


# ================================================================== 1. Gogyō Fūin
## Ref: parmak uçlarında beş mor alev (içlerinde işaret); karna bastırılınca beş alev el açıklığında yanar, yerinde spiral
## Beş Element mührü kalır ve 12 sn hafifçe atar
static func _flame(size: Vector2, seed := 0.0) -> MeshInstance3D:
	var mi = _mi(_quad(), _mat("flame"))
	mi.scale = Vector3(size.x, size.y, 1.0)
	mi.set_instance_shader_parameter("seed", seed)
	mi.set_instance_shader_parameter("outer", Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.95))
	mi.set_instance_shader_parameter("inner", PURPLE_LT)
	mi.set_instance_shader_parameter("ink", PURPLE_INK)
	return mi


static func _gogyo_seal_mesh() -> ArrayMesh:
	if _cache.has("mesh:gogyo"):
		return _cache["mesh:gogyo"]
	var st = _strip_begin()
	var sp = []
	for i in 72:
		var th = float(i) / 71.0 * 12.0
		var r = 0.02 + 0.018 * th
		sp.append(Vector3(cos(th) * r, sin(th) * r, 0))
	_strip(st, sp, 0.034, PURPLE_INK, Vector3.BACK, false)
	_strip(st, sp, 0.014, PURPLE, Vector3.BACK, false, Vector3.BACK * 0.004)
	for k in 5:   # beş element işareti
		var a = PI * 0.5 + TAU * k / 5.0
		var cpos = Vector3(cos(a), sin(a), 0) * 0.3
		var tg = Vector3(-sin(a), cos(a), 0)
		var up = Vector3(cos(a), sin(a), 0)
		_strip(st, [cpos - tg * 0.05, cpos + tg * 0.05], 0.03, PURPLE_INK, Vector3.BACK, false)
		_strip(st, [cpos - up * 0.05, cpos + up * 0.05], 0.03, PURPLE_INK, Vector3.BACK, false)
		_strip(st, [cpos - tg * 0.04, cpos + tg * 0.04], 0.012, PURPLE_LT, Vector3.BACK, false, Vector3.BACK * 0.004)
		_strip(st, [cpos - up * 0.04, cpos + up * 0.04], 0.012, PURPLE_LT, Vector3.BACK, false, Vector3.BACK * 0.004)
	var ring = []
	for i in 49:
		var a2 = TAU * i / 48.0
		ring.append(Vector3(cos(a2), sin(a2), 0) * 0.38)
	_strip(st, ring, 0.02, PURPLE_INK, Vector3.BACK, false)
	var m = st.commit()
	_cache["mesh:gogyo"] = m
	return m


static func gogyo_fuin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	if tt == null:
		Hud.msg("Gogyō Fūin: hedef en fazla 9 metrede olmalı", Color(0.85, 0.75, 1.0))
		return
	# hazırlık: elin üstünde parmak uçları sırasıyla beş mor alev (el izlenir)
	var holder = Node3D.new()
	_add(holder, pj.hand_pos(c, true))
	var flames = []
	for k in 5:
		var f = _flame(Vector2(0.12, 0.2), k * 7.3)
		holder.add_child(f)
		f.position = Vector3((k - 2) * 0.05, 0.05 + (2 - absi(k - 2)) * 0.025, -0.08)
		var s1 = f.scale
		f.scale = s1 * 0.05
		var tw = f.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(f, "scale", s1, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		flames.append(f)
	var cw = weakref(c)
	var follow = func(_i, _k) -> void:
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc) and is_instance_valid(holder) and holder.get_parent() != null:
			holder.global_position = pj.hand_pos(cc, true) + cc.face_dir() * 0.08
			_orient(holder, cc.face_dir())
	pj.every(0.35, 1.0 / 60.0, follow)
	pj.busy(c, 0.8)
	pj.after(0.35, func():
		if not pj.live(tt):
			if is_instance_valid(holder):
				_fade_all(holder, 0.0, 0.2)
			return
		c.global_position = pj.gp(tt.global_position - (tt.global_position - c.global_position).normalized() * (tt.radius + 0.9))
		if c is Player:
			c.combat.face_to(tt)
		pj.anim(c, "cross", 2.0)
		var belly = tt.global_position + Vector3.UP * tt.height * 0.5
		var dn: Vector3 = tt.global_position - c.global_position
		dn.y = 0.0
		dn = dn.normalized() if dn.length() > 0.01 else c.face_dir()
		var side = dn.cross(Vector3.UP).normalized()
		var front = belly - dn * (tt.radius + 0.05)
		# beş alev el açıklığında karna iner (ref: başparmak altta, dört parmak yay)
		for k in 5:
			var f: MeshInstance3D = flames[k]
			if is_instance_valid(f):
				var ang = lerpf(-1.0, 1.0, k / 4.0)
				var dst = front + side * sin(ang) * 0.3 + Vector3.UP * (0.12 - cos(ang) * 0.16)
				var tw = f.create_tween()
				tw.tween_property(f, "global_position", dst, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pj.after(0.12, func():
			if not pj.live(tt):
				if is_instance_valid(holder):
					_fade_all(holder, 0.0, 0.2)
				return
			pj.hit(c, belly, tt.radius + 0.5, pj.inf(c, "gogyo_fuin", 0.9, {"knock": 7.0, "kind": "heavy", "hitstop": 0.12}))
			_gogyo_lock(pj, tt, 12.0, front, dn)
			# alevler büyüyüp bir an yanar, sonra mührün içine çekilir
			if is_instance_valid(holder):
				for f in holder.get_children():
					var tw2 = (f as Node3D).create_tween()
					tw2.tween_property(f, "scale", (f as Node3D).scale * 1.7, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
					tw2.tween_interval(0.35)
					tw2.tween_property(f, "global_position", front, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw2.parallel().tween_property(f, "scale", Vector3.ONE * 0.01, 0.18)
				free_later(holder, 0.8)
			# itişle saçılan mor alev dilleri (yüzeyde, dışa)
			for k in 8:
				var a = TAU * k / 8.0 + randf_range(-0.2, 0.2)
				var lk = _flame(Vector2(0.09, 0.16), randf() * 30.0)
				lk.set_instance_shader_parameter("glyph", 0.0)
				_add(lk, front)
				var tw3 = lk.create_tween().set_parallel(true)
				tw3.tween_property(lk, "global_position", front + (side * cos(a) + Vector3.UP * sin(a)) * randf_range(0.45, 0.7) - dn * 0.1, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
				tw3.tween_property(lk, "scale", Vector3(0.02, 0.03, 1.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw3.chain().tween_callback(lk.queue_free)
			_ring(front - dn * 0.02, 3.0, -dn, PURPLE_LT, PURPLE_INK, 0.15, 1.2, 0.05, 0.32, {"near_a": 0.4, "near_b": 1.5})
			Combat.popup_text(belly + Vector3.UP * 1.2, "Beş Element Mühürü: chakra kilitlendi!", Color(0.85, 0.65, 1.0))
			Sfx.play("seal", belly, 0.8)))


static func free_later(n: Node, t: float) -> void:
	var w = weakref(n)
	_later(t, func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


## Mühür kilidi (kanon: chakra akışı kapanır) + karında atan spiral mühür
static func _gogyo_lock(pj: PathJutsu, tt: Node3D, dur: float, front: Vector3, dn: Vector3) -> void:
	if not pj.live(tt):
		return
	pj.st(tt, "sealed", dur)
	Combat.popup_text(tt.global_position + Vector3.UP * (tt.height + 1.0), "Chakra noktaları kapandı!", Color(0.85, 0.55, 1.0))
	var seal = _mi(_gogyo_seal_mesh(), _mat("flat"))
	tt.add_child(seal)
	seal.global_position = front - dn * 0.01
	_orient(seal, dn)
	_ip(seal, {"tint": Color.WHITE, "near_a": 0.3, "near_b": 1.0, "fade": 1.0})
	var bs = ClanJutsu.body_scale(tt)
	seal.scale = Vector3.ONE * 0.2 * bs
	var tw = seal.create_tween()
	tw.tween_property(seal, "scale", Vector3.ONE * bs, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(seal, "rotation:z", seal.rotation.z + PI, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var sw = weakref(seal)
	var pulse = func(i, _k) -> void:
		var s = sw.get_ref()
		if s != null and is_instance_valid(s):
			(s as GeometryInstance3D).set_instance_shader_parameter("fade", 0.95 if i < 6 else (0.55 + 0.25 * sin(i * 0.9)))
	var done = func() -> void:
		var s = sw.get_ref()
		if s != null and is_instance_valid(s):
			_fade_all(s, 0.0, 0.5)
	pj.every(dur, 0.25, pulse, done)
	free_later(seal, dur + 1.0)


# ================================================================== 2. Kokumu Gakure no Jutsu
## Ref: lacivert-kara bulut kütlesi, tepeleri mavi ışıkla aydınlanmış. Ayaktan sızıp yerde yuvarlanarak yayılır, sonra kullanıcıyla akar
static func kokumu_gakure_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var id = "kokumu_gakure_no_jutsu"
	pj.anim(c, "seal", 1.4)
	var cw = weakref(c)
	var at: Vector3 = c.global_position
	_black_fog_bloom(at)
	Sfx.play("wind", at, 0.6, 0.6)
	var DUR = 6.0
	var mods = {"speed": 1.2, "_name": "Kokumu Gakure", "_desc": "kara siste gizlisin: rakipler seni kaybeder"}
	if c is Player:
		Buffs.add(id, DUR, mods)
	elif c.has_method("add_buff"):
		c.add_buff(id, DUR, mods)
	var hide = func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		if i % 6 == 0:   # sis kullanıcıyla birlikte akar
			_black_fog_trail(cc)
		for e in pj.enemies_near(cc, cc.global_position, 9.0):
			if e.has_method("lose_target") and e.get("target") == cc:
				e.lose_target(0.6)
	pj.every(DUR, 0.1, hide)


static func _black_fog_bloom(at: Vector3) -> void:
	var near = Vector2(2.5, 8.0)
	for k in 7:   # yerde süzülen kara dil
		var a = TAU * k / 7.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(at + dv * 0.4 + Vector3.UP * 0.2, randf_range(1.2, 1.7), FOG_PAL, dv * randf_range(1.6, 2.4), 2.6, 1.5, near, 0.38)
	for k in 12:   # kabaran gövde
		var a = randf() * TAU
		var r = randf_range(0.3, 2.4)
		var p = at + Vector3(cos(a) * r, randf_range(0.3, 1.6), sin(a) * r)
		var v = Vector3(cos(a) * 0.4, randf_range(0.35, 0.8), sin(a) * 0.4)
		var d = randf() * 0.5
		_later(d, func(): _puff(p, randf_range(1.1, 1.8), FOG_PAL, v, randf_range(2.4, 3.2), 1.7, near))
	for k in 4:   # bedenden sızan koyu duman
		var a = randf() * TAU
		_puff(at + Vector3(cos(a) * 0.2, randf_range(0.7, 1.4), sin(a) * 0.2), 0.6, FOG_PAL, Vector3(cos(a), 0.5, sin(a)) * 0.9, 1.6, 2.2, near)


static func _black_fog_trail(cc: Node3D) -> void:
	var near = Vector2(2.5, 8.0)
	var p: Vector3 = cc.global_position
	var mv = Vector3.ZERO
	if cc is CharacterBody3D:
		mv = (cc as CharacterBody3D).velocity
		mv.y = 0.0
	for k in 3:
		var a = randf() * TAU
		var r = randf_range(0.6, 1.4)
		_puff(p + Vector3(cos(a) * r, randf_range(0.3, 1.4), sin(a) * r), randf_range(0.9, 1.4), FOG_PAL, Vector3(cos(a) * 0.3, 0.4, sin(a) * 0.3) - mv * 0.15, randf_range(1.6, 2.2), 1.6, near)
	_puff(p - mv.normalized() * 0.8 + Vector3.UP * 0.15, 1.3, FOG_PAL, -mv * 0.2, 1.8, 1.4, near, 0.35)


# ================================================================== 3. Hankyōtei no Jutsu
## Ref: yay teli çekilir; ince, soluk iç içe halkalar dışa açılır; bulunan hedefin silueti ak kenarla belirir
static func hankyotei_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var id = "hankyotei_no_jutsu"
	pj.anim(c, "throw", 1.2)
	var cw = weakref(c)
	Sfx.play("clink", c.global_position, 0.6)
	_bow_twang(c, pj.hand_pos(c, true))
	if CanonRules.rainy():   # kanon zayıflık: gök gürültüsü yankıyı bozar
		_echo_out(c, 10.0, 1, true)
		if c == Game.player:
			Hud.msg("Gök gürültüsü yankıları bozuyor: algı tutmadı.", Color(0.7, 0.8, 0.9))
		return
	_echo_out(c, 40.0, 4, false)
	pj.after(0.45, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var n = 0
		for e in pj.enemies_near(cc, cc.global_position, 40.0):
			n += 1
			pj.st(e, "marked", 10.0)   # yeri belli: fazla hasar alır, saklanamaz
			var p: Vector3 = e.global_position + Vector3.UP * 1.0
			_echo_return(e, cc, 10.0)
			Combat.popup_text(p + Vector3.UP * 1.6, "Yankı!", Color(0.6, 0.9, 1.0))
		if cc == Game.player:
			Hud.msg("Yankı: %d hedefin yeri belli." % n, Color(0.6, 0.9, 1.0)))


## Yay teli: elin önünde ince dikey tel çekilip bırakılır, sönümlenerek titreşir
static func _bow_twang(c: Node3D, hp: Vector3) -> void:
	var line = _mi(_box(), _mat("add"))
	_add(line, hp + c.face_dir() * 0.25 + Vector3.UP * 0.1)
	line.scale = Vector3(0.012, 1.1, 0.012)
	_orient(line, c.face_dir())
	_ip(line, {"tint": ECHO, "near_a": 0.3, "near_b": 1.0})
	var r0 = line.rotation
	var tw = line.create_tween()
	for q in 8:
		var amp = 0.12 * (1.0 - q / 8.0)
		tw.tween_property(line, "rotation:z", r0.z + amp * (1.0 if q % 2 == 0 else -1.0), 0.04)
	tw.tween_property(line, "rotation:z", r0.z, 0.04)
	_fade_all(line, 0.3, 0.2)


## Dışa açılan yankı halkaları: elden küçük dikey halkalar + göğüs hizasında yatay, 40 m'ye uzanan ince halkalar
static func _echo_out(c: Node3D, R: float, rings: int, broken: bool) -> void:
	var o: Vector3 = c.global_position + Vector3.UP * 1.2
	var fd: Vector3 = c.face_dir()
	var dash = 26.0 if broken else 0.0
	for k in 3:
		var d0 = k * 0.07
		var p = o + fd * 0.5
		_later(d0, func(): _ring(p, 3.0, fd, ECHO, ECHO_EDGE, 0.05, 1.4, 0.025, 0.4, {"dashes": dash, "near_a": 0.4, "near_b": 1.6}))
	for k in rings:
		var d1 = 0.05 + k * 0.14
		var w = 0.07 * (1.0 + k * 0.5)
		_later(d1, func(): _ring(o, R * 2.0 + 2.0, Vector3.ZERO, ECHO, ECHO_EDGE, 0.6, R, w, 0.9 + k * 0.08, {"dashes": dash, "near_a": 1.0, "near_b": 4.0}))


## Dönen yankı: hedefte içe doğru daralan halkalar + siluet kenarı ak ışır (işaret süresince sönük kalır)
static func _echo_return(e: Node3D, cc: Node3D, dur: float) -> void:
	var p: Vector3 = e.global_position + Vector3.UP * 1.0
	var to_c: Vector3 = cc.global_position - e.global_position
	to_c.y = 0.0
	var face = to_c.normalized() if to_c.length() > 0.1 else Vector3.FORWARD
	for k in 2:
		var pp = p
		_later(k * 0.1, func(): _ring(pp, 4.0, face, ECHO, ECHO_EDGE, 1.8, 0.2, 0.04, 0.4, {"ease": Tween.EASE_IN, "near_a": 0.6, "near_b": 2.5}))
	var m = e.get("model")
	if m == null or not is_instance_valid(m):
		return
	var mat: ShaderMaterial = _mat("rim").duplicate()
	mat.set_shader_parameter("col", Color(ECHO.r, ECHO.g, ECHO.b, 0.95))
	mat.set_shader_parameter("amt", 1.2)
	mat.set_shader_parameter("shimmer", 0.0)
	var meshes = []
	for mi in (m as Node).find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay == null:
			(mi as MeshInstance3D).material_overlay = mat
			meshes.append(weakref(mi))
	var seta = func(x: float) -> void:
		mat.set_shader_parameter("amt", x)
	var tw = _tree().create_tween()
	tw.tween_method(seta, 1.2, 0.3, 1.4)
	_later(dur, func():
		for w in meshes:
			var mi = w.get_ref()
			if mi != null and is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == mat:
				(mi as MeshInstance3D).material_overlay = null)


# ================================================================== 4-5. Funato: Shiomaneki / Isō Ryōdan
## Ref: kızıl-kahve, yumrulu ve dikenli kabuk avuç; iki uzun kavisli kıskaç, iç kenarları gümüş testere dişli bıçak
static func _claw_finger(b: MB, lower: bool) -> void:
	var sg = -1.0 if lower else 1.0
	var n = 7
	for i in n:
		var s = float(i) / (n - 1)
		var z = 0.42 + s * 0.62
		var y = sg * (0.08 + sin(s * PI * 0.9) * 0.05 - s * s * 0.11)
		var r = lerpf(0.13, 0.03, s)
		var col = CRAB_SHELL.lerp(CRAB_HI, 0.4 + s * 0.4)
		b.add("sphere", Vector3(0, y + sg * 0.02, z), Vector3(r * 1.5, r * 1.6, r * 2.4), col, Vector3.ZERO, 10)
		# iç kenar: gümüş bıçak + diş
		if i < n - 1:
			b.add("sphere", Vector3(0, y - sg * r * 0.55, z), Vector3(r * 0.5, r * 0.9, r * 2.2), CRAB_BLADE, Vector3.ZERO, 8)
			b.add("cone", Vector3(0, y - sg * r * 1.05, z + 0.02), Vector3(0.035, 0.09, 0.035), CRAB_BLADE, Vector3(180.0 if not lower else 0.0, 0, 0), 4)


static func crab_claw(pj: PathJutsu, c: Node3D) -> Dictionary:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return {}
	var root = Node3D.new()
	ba.add_child(root)
	var b = MB.new()
	b.add_grad("sphere", Vector3(0, 0.02, 0.22), Vector3(0.38, 0.34, 0.56), CRAB_HI, CRAB_SHELL.darkened(0.25), Vector3.ZERO, 14)   # şişkin avuç
	b.add("cyl", Vector3(0, 0, -0.05), Vector3(0.19, 0.16, 0.19), CRAB_SHELL.darkened(0.35), Vector3(90, 0, 0), 12)   # bilek halkası
	var bumps = [Vector3(0.08, 0.15, 0.1), Vector3(-0.07, 0.16, 0.16), Vector3(0.02, 0.18, 0.26), Vector3(0.1, 0.12, 0.32), Vector3(-0.1, 0.12, 0.3), Vector3(0.0, 0.14, 0.4)]
	for p in bumps:
		b.add("sphere", p, Vector3(0.11, 0.08, 0.12), CRAB_HI.lightened(0.05), Vector3.ZERO, 8)
	var spikes = [Vector3(0.05, 0.17, 0.05), Vector3(-0.06, 0.18, 0.2), Vector3(0.07, 0.17, 0.3), Vector3(-0.03, 0.15, 0.42)]
	for p in spikes:
		b.add_grad("cone", p + Vector3.UP * 0.08, Vector3(0.06, 0.2, 0.06), CRAB_HI.lightened(0.2), CRAB_SHELL, Vector3(-25, 0, 0), 6)
	_claw_finger(b, false)
	var top = _mi(b.build(null), _mat("cel"))
	root.add_child(top)
	_outline(top, CRAB_INK, 0.012)
	var jaw = Node3D.new()
	jaw.position = Vector3(0, -0.08, 0.36)
	root.add_child(jaw)
	var bj = MB.new()
	_claw_finger(bj, true)
	var jm = _mi(bj.build(null), _mat("cel"))
	jm.position = Vector3(0, 0.0, -0.36)
	jaw.add_child(jm)
	_outline(jm, CRAB_INK, 0.012)
	root.scale = Vector3.ONE * 1.05
	return {"root": root, "jaw": jaw, "ba": ba}


## Çağırma formülü (yerde mürekkep çember + yazı çizgileri)
static func _formula(at: Vector3, r: float, ink: Color, life: float) -> MeshInstance3D:
	var st = _strip_begin()
	for rr in [r, r * 0.72]:
		var ring = []
		for i in 41:
			var a = TAU * i / 40.0
			ring.append(Vector3(cos(a), 0, sin(a)) * rr)
		_strip(st, ring, r * 0.035, ink, Vector3.UP, false, Vector3.UP * 0.03)
	for k in 14:
		var a = TAU * k / 14.0
		var d = Vector3(cos(a), 0, sin(a))
		_strip(st, [d * r * 0.76, d * r * 0.97], r * 0.05, ink, Vector3.UP, true, Vector3.UP * 0.03)
		var t = Vector3(-d.z, 0, d.x)
		_strip(st, [d * r * 0.86 - t * 0.06, d * r * 0.86 + t * 0.06], r * 0.025, ink, Vector3.UP, false, Vector3.UP * 0.03)
	var mi = _mi(st.commit(), _mat("flat"))
	_add(mi, at)
	_ip(mi, {"tint": Color.WHITE, "near_a": 0.3, "near_b": 1.2})
	mi.scale = Vector3.ONE * 0.3
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:y", 0.6, life).set_trans(Tween.TRANS_SINE)
	_fade_all(mi, life * 0.5, life * 0.5)
	return mi


static func funato_shiomaneki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var old = pj._crab_of(c)
	if not old.is_empty():
		old["ba"].queue_free()
	var gpos = pj.gp(c.global_position)
	_formula(gpos, 1.6, Color(0.05, 0.12, 0.22), 1.0)
	for k in 12:   # formülün kenarından deniz suyu fışkırır
		var a = TAU * k / 12.0
		var p = gpos + Vector3(cos(a), 0.05, sin(a)) * 1.5
		var dr = _bit(p, Vector3.ONE * randf_range(0.08, 0.13), Color.WHITE, "drop")
		_fly(dr, p, Vector3(cos(a) * 0.6, randf_range(3.0, 4.2), sin(a) * 0.6), 14.0, 0.55)
	Sfx.play("poof", gpos, 0.8)
	var st = crab_claw(pj, c)
	if st.is_empty():
		return
	c.set_meta("shiomaneki", st)
	_claw_arrive(st)
	pj._crab_snap(st, 32.0, 0.15, 0.1)
	if c is Player:
		Buffs.add("shiomaneki", 25.0, {"melee": 1.25, "_name": "Shiomaneki", "_desc": "Kemancı yengeç kıskacı: yakın dövüş +%25"})
	elif c.has_method("add_buff"):
		c.add_buff("shiomaneki", 25.0, {"melee": 1.25})
	pj.after(25.0, func():
		if is_instance_valid(st.get("ba")):
			_claw_dissolve(st)
		if is_instance_valid(c) and c.has_meta("shiomaneki") and c.get_meta("shiomaneki") == st:
			c.remove_meta("shiomaneki"))
	Sfx.play("summon", c.global_position, 1.2)


## Kola dolanan su sarmalı açılır, kıskaç içinden büyür
static func _claw_arrive(st: Dictionary) -> void:
	var root: Node3D = st["root"]
	var ba: Node3D = st["ba"]
	var s1 = root.scale
	root.scale = s1 * 0.05
	var tw = root.create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(root, "scale", s1, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pts = []
	var radii = []
	for i in 40:
		var s = float(i) / 39.0
		var a = s * TAU * 2.5
		pts.append(Vector3(cos(a) * 0.3, sin(a) * 0.3, -0.3 + s * 1.3))
		radii.append(0.05 * sin(s * PI) + 0.01)
	var hx = _mi(_tube(pts, radii, 6), _mat("water2"))
	ba.add_child(hx)
	var tw2 = hx.create_tween().set_parallel(true)
	tw2.tween_property(hx, "rotation:z", TAU, 0.45)
	tw2.tween_property(hx, "scale", Vector3(0.05, 0.05, 1.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.chain().tween_callback(hx.queue_free)
	_later(0.4, func():
		if not is_instance_valid(root):
			return
		var p = root.global_position
		for k in 7:
			var dr = _bit(p, Vector3.ONE * randf_range(0.06, 0.1), Color.WHITE, "drop")
			_fly(dr, p, Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 2.5), randf_range(-1.5, 1.5)), 14.0, 0.5))


## Süre bitti: kıskaç suya çözülüp damlar, yerde dalgacık
static func _claw_dissolve(st: Dictionary) -> void:
	var root: Node3D = st["root"]
	var ba: Node3D = st["ba"]
	if is_instance_valid(root):
		var p = root.global_position
		var tw = root.create_tween()
		tw.tween_property(root, "scale", root.scale * 0.05, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for k in 12:
			var q = p + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2))
			var dr = _bit(q, Vector3.ONE * randf_range(0.06, 0.11), Color.WHITE, "drop")
			_fly(dr, q, Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.8), randf_range(-0.4, 0.4)), 12.0, randf_range(0.4, 0.6))
		var g = Vector3(p.x, Game.jutsu_floor_at(p).y + 0.04, p.z)
		_ring(g, 3.0, Vector3.ZERO, Color(0.8, 0.93, 1.0), Color(0.2, 0.45, 0.8), 0.1, 1.2, 0.05, 0.7)
	free_later(ba, 0.45)


static func funato_iso_ryodan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var st = pj._crab_of(c)
	if st.is_empty():
		if c is Player:
			Hud.msg("Önce Kuchiyose: Shiomaneki ile kıskacı çağır.", Color(1, 0.75, 0.45))
		return
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.7)
	var d = pj.fwd(c, t)
	var start = c.global_position
	var end = pj.gp((tt.global_position - d * 1.2) if tt else start + d * 7.0)
	pj._crab_snap(st, 48.0, 0.18, 0.08)
	pj.anim(c, "cross", 1.4)
	_dash_streaks(start, end, d)
	pj.every(0.2, 1.0 / 60.0, func(_i, k):
		if pj.live(c):
			c.global_position = pj.gp(start.lerp(end, k)), func():
		if not pj.live(c):
			return
		var at = (tt.global_position + Vector3.UP * tt.height * 0.85) if tt and pj.live(tt) else end + Vector3.UP * 1.5
		_scissor_cut(at, d, ClanJutsu.body_scale(tt) if tt and pj.live(tt) else 1.0)
		pj.hit(c, at, 1.6, pj.inf(c, "funato_iso_ryodan", 2.4, {"knock": 8.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.12}))
		Sfx.play("clink", at, 0.7))


## Atılışta gövde boyunca ince hız çizgileri + ayaktan kalkan deniz damlaları
static func _dash_streaks(start: Vector3, end: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var L = maxf(1.5, start.distance_to(end))
	for k in 8:
		var ln = _mi(_box(), _mat("flat"))
		var mid = start.lerp(end, randf_range(0.2, 0.6)) + Vector3.UP * randf_range(0.4, 1.8) + side * randf_range(-0.7, 0.7)
		_add(ln, mid)
		_orient(ln, d)
		ln.scale = Vector3(0.025, 0.025, L * randf_range(0.4, 0.8))
		_ip(ln, {"tint": Color(0.95, 0.97, 1.0, 0.75), "near_a": 0.8, "near_b": 3.0})
		var tw = ln.create_tween()
		tw.tween_interval(k * 0.015)
		tw.tween_property(ln, "global_position", mid + d * L * 0.4, 0.25)
		_fade_all(ln, 0.08, 0.2)
	for k in 6:
		var p = start + Vector3.UP * 0.1 + side * randf_range(-0.3, 0.3)
		var dr = _bit(p, Vector3.ONE * 0.07, Color.WHITE, "drop")
		_fly(dr, p, -d * randf_range(1.0, 2.0) + Vector3.UP * randf_range(1.5, 2.5), 14.0, 0.4)


static func _crescent_mesh() -> ArrayMesh:
	if _cache.has("mesh:crescent"):
		return _cache["mesh:crescent"]
	var st = _strip_begin()
	var pts = []
	for i in 25:
		var a = deg_to_rad(lerpf(22.0, 158.0, i / 24.0))
		pts.append(Vector3(cos(a), sin(a), 0) * 0.7)
	_strip(st, pts, 0.17, CUT_RED, Vector3.BACK, true)
	_strip(st, pts, 0.07, Color(1.0, 0.98, 0.94), Vector3.BACK, true, Vector3(0, -0.02, 0.006))
	var m = st.commit()
	_cache["mesh:crescent"] = m
	return m


## Ref (Isō Ryōdan): kızıl-ak iki hilal kıskaç gibi baştan kapanır, geriye yatay tek kesik kalır; çelik kıvılcım ve kan damlası
static func _scissor_cut(at: Vector3, d: Vector3, s: float) -> void:
	var root = Node3D.new()
	_add(root, at)
	_orient(root, d)
	root.scale = Vector3.ONE * s
	var up = _mi(_crescent_mesh(), _mat("flat"))
	var lo = _mi(_crescent_mesh(), _mat("flat"))
	root.add_child(up)
	root.add_child(lo)
	lo.rotation.z = PI
	for m in [up, lo]:
		_ip(m, {"tint": Color.WHITE, "near_a": 0.4, "near_b": 1.6})
	up.position = Vector3(0, 0.15, 0)
	lo.position = Vector3(0, -0.15, 0)
	var tw = root.create_tween().set_parallel(true)
	tw.tween_property(up, "position:y", -0.62, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(lo, "position:y", 0.62, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(up, "scale", Vector3(1.3, 0.25, 1.0), 0.09).set_delay(0.03)
	tw.tween_property(lo, "scale", Vector3(1.3, 0.25, 1.0), 0.09).set_delay(0.03)
	_fade_all(up, 0.1, 0.12, 1.0, 0.0, true)
	_fade_all(lo, 0.1, 0.12, 1.0, 0.0, true)
	# kesik: yatay ince ak çizgi, kızıl kenar; uzayıp söner
	_later(0.09, func():
		if not is_instance_valid(root):
			return
		for layer in [[Vector3(2.0, 0.09, 0.02), CUT_RED], [Vector3(2.1, 0.035, 0.03), Color(1, 1, 0.97)]]:
			var ln = _mi(_box(), _mat("flat"))
			root.add_child(ln)
			ln.scale = layer[0] * Vector3(0.3, 1.0, 1.0)
			_ip(ln, {"tint": layer[1], "near_a": 0.4, "near_b": 1.6})
			var tw2 = ln.create_tween()
			tw2.tween_property(ln, "scale", layer[0], 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_fade_all(ln, 0.2, 0.3, 1.0, 0.0, true)
		var side = d.cross(Vector3.UP).normalized()
		for k in 12:   # çelik kıvılcımları
			var sg = 1.0 if k % 2 == 0 else -1.0
			var sp = _bit(at, Vector3(0.025, 0.025, 0.12), Color(1.0, 0.95, 0.75), "add")
			var v = side * sg * randf_range(3.0, 6.0) + Vector3.UP * randf_range(-0.5, 2.0) + d * randf_range(-1.0, 1.5)
			_orient(sp, v)
			_fly(sp, at, v, 9.0, randf_range(0.18, 0.3))
		for k in 6:   # kan damlaları (kanama)
			var bp = at + side * randf_range(-0.3, 0.3)
			var bd = _bit(bp, Vector3.ONE * randf_range(0.04, 0.07), BLOOD, "flat")
			_fly(bd, bp, Vector3(randf_range(-1, 1), randf_range(0.5, 1.8), randf_range(-1, 1)), 12.0, 0.5)
		free_later(root, 0.7))


# ================================================================== 6. Hatake Ninken
## Ref (Zabuza yakalanışı): kanlı parşömen yere açılır, köpekler kokuyu yeraltında izler; hedefin altında toprak yarılır,
## köpekler kesek ve tozla fışkırıp kenetlenir; bırakınca toprağa geri dalarlar
static func _blood_scroll(at: Vector3, fd: Vector3) -> Node3D:
	var root = Node3D.new()
	_add(root, at + Vector3.UP * 0.03)
	_orient(root, fd)
	var b = MB.new()
	b.add("box", Vector3(0, 0, -0.7), Vector3(0.42, 0.012, 1.4), PAPER, Vector3.ZERO)
	b.add("box", Vector3(0, 0.008, -0.7), Vector3(0.06, 0.006, 1.25), BLOOD, Vector3.ZERO)   # kan çizgisi
	for k in 7:
		var z = -0.2 - k * 0.17
		b.add("box", Vector3(-0.12, 0.01, z), Vector3(0.09, 0.006, 0.025), INK, Vector3(0, 30 * (k % 2), 0))
		b.add("box", Vector3(0.12, 0.01, z + 0.05), Vector3(0.025, 0.006, 0.09), INK, Vector3.ZERO)
	b.add("cyl", Vector3(0, 0.05, -1.42), Vector3(0.1, 0.46, 0.1), PAPER.darkened(0.15), Vector3(0, 0, 90), 10)   # sarılı uç
	var mi = _mi(b.build(null), _mat("cel"))
	root.add_child(mi)
	root.scale = Vector3(1.0, 1.0, 0.05)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_all(root, 1.4, 0.4)
	return root


## Yeraltından iz süren sürü: parşömenden hedefe yer kabarıp çöken toprak sırtı + mürekkep izi
static func _track_line(from: Vector3, to: Vector3) -> void:
	var d = to - from
	d.y = 0.0
	var L = d.length()
	if L < 0.5:
		return
	d = d.normalized()
	var n = clampi(int(L / 1.4), 3, 18)
	for i in n:
		var s = float(i + 1) / (n + 1)
		var p = from + d * L * s
		p.y = Game.jutsu_floor_at(p).y
		var delay = s * 0.18
		_later(delay, func():
			var bump = _mi(_sphere(10), _mat("cel"))
			_add(bump, p - Vector3.UP * 0.15)
			_ip(bump, {"tint": EARTH})
			bump.scale = Vector3(0.7, 0.05, 0.9)
			_orient(bump, d)
			var tw = bump.create_tween()
			tw.tween_property(bump, "scale", Vector3(0.7, 0.45, 0.9), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(bump, "scale", Vector3(0.75, 0.02, 0.95), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(bump.queue_free)
			if i % 2 == 0:
				_clods(p, 2, 1.4, 0.7))


static func hatake_ninken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	if tt == null:
		Hud.msg("Ninken sürüsü: önce bir hedef seç", Color(0.9, 0.8, 0.6))
		return
	pj.busy(c, 0.6)
	# kanon: başparmaktan kan, parşömen yere açılır, çağırma formülü — köpekler yeraltından kokuyu izler
	var sp = pj.gp(c.global_position + c.face_dir() * 0.9)
	_blood_scroll(sp, c.face_dir())
	Sfx.play("poof", sp, 0.8)
	if tt.has_meta("hidden") or tt.has_meta("invisible"):
		tt.remove_meta("hidden")
	var tg0 = pj.gp(tt.global_position)
	_track_line(sp, tg0)
	_cracks(tg0, 3.0, 9, EARTH_DK, 3.0)
	# anime (Zabuza yakalanışı): sekiz ninken (biri küçük Pakkun) hedefin altından fışkırır, bacaklarına, beline, kollarına
	# farklı yüksekliklerde kenetlenip ısırır. Köpekler ortak çağrı modeli (SummonModels dog_pack)
	var th = float(tt.get("height")) if tt.get("height") != null else 1.8
	var bites = [[0.0, 0.15], [1.6, 0.2], [3.2, 0.55], [4.7, 0.6], [0.8, 1.0], [2.4, 1.05], [3.9, 1.2], [5.5, 0.3]]
	for k in 8:
		var md = SummonModels.build("dog_small" if k == 0 else "dog_pack", 0.45 if k == 0 else 0.66, 1.0)
		var dog: Node3D = md["root"]
		pj.get_tree().current_scene.add_child(dog)
		var a = float(bites[k][0])
		var hy = float(bites[k][1]) * th * 0.6
		var p = pj.gp(tt.global_position) + Vector3(cos(a), 0, sin(a)) * (tt.radius + 0.42)
		dog.global_position = p - Vector3.UP * 1.2
		dog.look_at(Vector3(tt.global_position.x, p.y + hy, tt.global_position.z), Vector3.UP)
		dog.rotate_object_local(Vector3.RIGHT, -0.35 if hy > 0.5 else 0.0)   # üstten ısıranlar hafif yukarı
		var tw = dog.create_tween()
		tw.tween_interval(0.05 + k * 0.035)
		tw.tween_callback(func(): _dog_burst(p))
		tw.tween_property(dog, "global_position", p + Vector3.UP * hy, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for q in 6:   # ısırırken silkelenir
			tw.tween_property(dog, "rotation:z", 0.18 * (1 if q % 2 == 0 else -1), 0.12)
		tw.tween_property(dog, "rotation:z", 0.0, 0.1)
		tw.tween_interval(1.3)
		tw.tween_callback(func(): _clods(p, 3, 1.2, 0.6))   # toprağa geri dalar
		tw.tween_property(dog, "global_position", p - Vector3.UP * 1.3, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(dog.queue_free)
	_dust_ring(tg0, 1.6)
	pj.st(tt, "bind", 3.0)
	pj.every(3.0, 0.4, func(_i, _k):
		if pj.live(tt):
			pj.hit(c, tt.global_position + Vector3.UP * 0.8, 0.9, pj.inf(c, "hatake_ninken", 0.15, {"knock": 0.0, "launch": 0.0, "kind": "crush"}))   # ısırma tiki: bağlı hedef devrilmez
			Sfx.play("punch", tt.global_position, 1.6, 0.4))
	Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Ninkenler yakaladı!", Color(0.9, 0.8, 0.6))


## Tek köpeğin çıkışı: küçük yarık, kesek, alçak toz
static func _dog_burst(p: Vector3) -> void:
	_clods(p, 5, 2.0, 0.8)
	for k in 2:
		var a = randf() * TAU
		_puff(p + Vector3(cos(a), 0.2, sin(a)) * 0.2, 0.45, DUST_PAL, Vector3(cos(a), 0.6, sin(a)) * 1.2, 0.6, 1.5, Vector2(1.2, 4.5), 0.6)


## Alçak toz halkası (yerde dışa yuvarlanan cel toz)
static func _dust_ring(at: Vector3, s: float) -> void:
	for k in 9:
		var a = TAU * k / 9.0 + randf_range(-0.15, 0.15)
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(at + dv * 0.5 * s + Vector3.UP * 0.25, 0.6 * s, DUST_PAL, dv * 1.6 * s + Vector3.UP * 0.2, 0.9, 1.6, Vector2(1.2, 5.0), 0.55)


# ================================================================== 7. Ryōken Bunshin
## Kanon: Pakkun'un dökülen tüyleri süzülüp her biri bir köpek klonuna dönüşür; süre bitince klon yeniden tüye dağılır
static func _fur_mesh(v: int) -> ArrayMesh:
	var k = "mesh:fur%d" % v
	if _cache.has(k):
		return _cache[k]
	var pts = []
	var radii = []
	var cols = []
	var bend = [0.12, -0.08, 0.18][v % 3]
	for i in 5:
		var s = float(i) / 4.0
		pts.append(Vector3(sin(s * 2.4) * bend, s * 0.16, cos(s * 1.7) * bend * 0.4))
		radii.append(lerpf(0.016, 0.002, s))
		cols.append(FUR.lerp(FUR_LT, s))
	var m = _tube(pts, radii, 4, cols)
	_cache[k] = m
	return m


static func _fur(pos: Vector3) -> MeshInstance3D:
	var mi = _mi(_fur_mesh(randi() % 3), _mat("flat"))
	_add(mi, pos)
	_ip(mi, {"tint": Color.WHITE, "near_a": 0.3, "near_b": 1.0})
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	mi.scale = Vector3.ONE * randf_range(0.8, 1.3)
	return mi


## Süzülen tüy: yavaşça sallanarak süzülür, döner
static func _drift(mi: MeshInstance3D, p0: Vector3, v: Vector3, life: float, fall := 0.6) -> void:
	var ph = randf() * TAU
	var step = func(x: float) -> void:
		if is_instance_valid(mi):
			mi.global_position = p0 + v * x + Vector3(sin(x * 5.0 + ph) * 0.12, -fall * x * x, cos(x * 4.0 + ph) * 0.12)
			mi.rotation.y = ph + x * 3.0
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(mi.queue_free)
	_fade_all(mi, life * 0.6, life * 0.4, 1.0, 0.0, false)


static func ryoken_bunshin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 16.0)
	var dog = ClanMech.dog() if c is Player else null
	var src = dog.global_position if dog else c.global_position
	for k in 16:   # köpeğin sırtından tüy dökülür
		var p = src + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 0.7), randf_range(-0.3, 0.3))
		var a = TAU * k / 16.0
		_drift(_fur(p), p, Vector3(cos(a) * 0.9, randf_range(0.5, 1.0), sin(a) * 0.9), randf_range(0.7, 1.0), 0.2)
	for k in 4:
		pj.after(0.2 + k * 0.1, func():
			if not pj.live(c):
				return
			var a = k * TAU / 4.0
			var p = src + Vector3(cos(a), 0, sin(a)) * 1.2
			_fur_gather(p + Vector3.UP * 0.4)
			var d = Ninken.new()
			d.owner_f = c
			pj.get_tree().current_scene.add_child(d)
			d.global_position = pj.gp(p)
			if d.vis:
				d.vis.scale = Vector3.ONE * 0.05
				var tw = d.vis.create_tween()
				tw.tween_interval(0.12)
				tw.tween_property(d.vis, "scale", Vector3.ONE * 0.7, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if tt:
				d.tgt = tt
			pj.after(10.0, func():
				if is_instance_valid(d):
					_fur_scatter(d.global_position + Vector3.UP * 0.5)
					d.queue_free()))
	Sfx.play("growl", c.global_position, 1.0)


## Tüyler dönerek bir noktaya toplanır (klon orada şekillenir)
static func _fur_gather(p: Vector3) -> void:
	for k in 9:
		var a = TAU * k / 9.0
		var q0 = p + Vector3(cos(a) * 0.8, randf_range(-0.2, 0.5), sin(a) * 0.8)
		var f = _fur(q0)
		var spin = func(x: float) -> void:
			if is_instance_valid(f):
				var aa = a + x * 2.5
				var r = 0.8 * (1.0 - x)
				f.global_position = p + Vector3(cos(aa) * r, (q0.y - p.y) * (1.0 - x), sin(aa) * r)
				f.scale = Vector3.ONE * maxf(0.2, 1.0 - x * 0.8)
		var tw = f.create_tween()
		tw.tween_method(spin, 0.0, 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(f.queue_free)


## Klon dağılır: bir avuç tüy havalanıp yavaşça yere süzülür
static func _fur_scatter(p: Vector3) -> void:
	for k in 12:
		var a = randf() * TAU
		_drift(_fur(p), p, Vector3(cos(a) * randf_range(0.6, 1.4), randf_range(0.8, 1.6), sin(a) * randf_range(0.6, 1.4)), randf_range(1.0, 1.4), 1.6)


# ================================================================== 8. Suika no Jutsu (jutsu.gd j_ işleyici)
## Ref (Suigetsu): bedenin KENDİSİ cel suya döner — açık mavi-ak, aşağı sarkan su dilleri, mavi kenar. Baştan aşağı yayılır,
## süre boyunca damlar, bitince yukarıdan aşağı çekilip ayakta gölcük bırakır
static func suika(_j, c: Node3D, _t: Node3D) -> void:
	# referans (Suika karesi): bedenin KENDİSİ suya döner. Oyuncu: Buff; düşman: aynı kural meta "suika_until" (Enemy.take_hit)
	if c is Player:
		Buffs.add("suika", 15.0, {"_desc": "Hafif darbeler içinden geçer (chakra yer), ağır darbe yarı hasar; Raiton 2x hasar ve bedeni dağıtır"})
		Hud.msg("Suika no Jutsu: 15 sn hafif darbeler içinden geçer (chakra harcar). Raiton'a karşı çok zayıf!", Color(0.5, 0.75, 1))
	else:
		c.set_meta("suika_until", Time.get_ticks_msec() / 1000.0 + 15.0)
	_liquid_body(c, 15.0)
	Sfx.play("water", c.global_position, 1.2)


static func _liquid_body(c: Node3D, dur: float) -> void:
	var mm = c.get("model")
	if mm == null or not is_instance_valid(mm):
		return
	var wm: ShaderMaterial = _water_mat().duplicate()
	wm.set_shader_parameter("body", Color(0.72, 0.88, 1.0, 0.8))
	wm.set_shader_parameter("flow", 3.5)
	var base: float = c.global_position.y
	var top = base + 2.1
	wm.set_shader_parameter("sweep", top)
	var meshes = (mm as Node).find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = wm
	var sets = func(x: float) -> void:
		wm.set_shader_parameter("sweep", x)
	var tw = c.create_tween()
	tw.tween_method(sets, top, base - 0.3, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): wm.set_shader_parameter("sweep", -10000.0))
	# dönüşüm anı: ayakta dalgacık, yukarı sıçrayan birkaç damla
	var g = Vector3(c.global_position.x, Game.jutsu_floor_at(c.global_position).y + 0.04, c.global_position.z)
	_ring(g, 3.0, Vector3.ZERO, Color(0.85, 0.95, 1.0), Color(0.2, 0.45, 0.85), 0.2, 1.3, 0.05, 0.6)
	for k in 6:
		var a = TAU * k / 6.0
		var p = c.global_position + Vector3(cos(a) * 0.3, 1.5, sin(a) * 0.3)
		var dr = _bit(p, Vector3.ONE * 0.08, Color.WHITE, "drop")
		_fly(dr, p, Vector3(cos(a), 1.6, sin(a)) * 1.2, 12.0, 0.6)
	# süre boyunca bedenden damlar
	var cw = weakref(c)
	var drip = func() -> void:
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var p = (cc as Node3D).global_position + Vector3(randf_range(-0.25, 0.25), randf_range(0.8, 1.6), randf_range(-0.25, 0.25))
		var gy = Game.jutsu_floor_at(p).y
		var fall = maxf(0.1, sqrt(2.0 * maxf(0.05, p.y - gy) / 12.0))
		var dr = _bit(p, Vector3(0.06, 0.09, 0.06), Color.WHITE, "drop")
		dr.rotation = Vector3.ZERO
		_fly(dr, p, Vector3.ZERO, 12.0, fall, false)
		var gp = Vector3(p.x, gy + 0.03, p.z)
		_later(fall, func(): _ring(gp, 1.0, Vector3.ZERO, Color(0.85, 0.95, 1.0), Color(0.25, 0.5, 0.85), 0.03, 0.4, 0.025, 0.4, {"near_a": 0.3, "near_b": 1.2}))
	var tw2 = c.create_tween()
	var n = maxi(1, int(dur / 0.5))
	for i in n:
		tw2.tween_interval(0.5)
		tw2.tween_callback(drip)
	# bitiş: su baştan aşağı çekilir, ayakta gölcük
	var sc = func(x: float) -> void:
		wm.set_shader_parameter("ceil_y", x)
	var finish = func() -> void:
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var b2: float = (cc as Node3D).global_position.y
		var tw3 = (cc as Node3D).create_tween()
		tw3.tween_method(sc, b2 + 2.1, b2 - 0.3, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw3.tween_callback(func():
			for mi in meshes:
				if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == wm:
					(mi as MeshInstance3D).material_overlay = null)
		var q = (cc as Node3D).global_position
		_ring(Vector3(q.x, Game.jutsu_floor_at(q).y + 0.04, q.z), 3.5, Vector3.ZERO, Color(0.85, 0.95, 1.0), Color(0.2, 0.45, 0.85), 0.2, 1.5, 0.06, 0.9)
	_later(dur, finish)


# ================================================================== 9. Mizudeppō (Water Gun, jutsu.gd j_ işleyici)
## Ref: parmak ucundan uzanan damla biçimli su mermisi — ak parlak baş, mavi saydam gövde, ince koyu kenar
static func _bullet_mesh() -> ArrayMesh:
	if _cache.has("mesh:wbullet"):
		return _cache["mesh:wbullet"]
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(0.34, 0.32, 0.44), Color.WHITE, Vector3.ZERO, 14)
	b.add("cone", Vector3(0, 0, 0.5), Vector3(0.3, 0.9, 0.28), Color.WHITE, Vector3(90, 0, 0), 12)
	var m = b.build(null)
	_cache["mesh:wbullet"] = m
	return m


static func water_gun(j, c: Node3D, t: Node3D) -> void:
	var m = j._mult(c)
	var pr = Projectile.new()
	pr.shooter = c
	var aim: Vector3 = j._aim(c, t)
	pr.vel = aim * 42.0   # 70 m/s'de mermi görünmüyordu
	pr.radius = 0.5
	pr.info = {"dmg": 14.0 * m, "knock": 5.0, "kind": "light", "element": "suiton", "hitstop": 0.03}
	var holder = Node3D.new()
	pr.add_child(holder)
	var body = _mi(_bullet_mesh(), _water_mat())
	holder.add_child(body)
	body.scale = Vector3.ONE * 1.3
	_outline(body, Color(0.06, 0.24, 0.66), 0.025)
	var hl = _mi(_sphere(8), _mat("flat"))   # ak parlak leke (ref)
	holder.add_child(hl)
	hl.position = Vector3(-0.06, 0.12, -0.08)
	hl.scale = Vector3(0.07, 0.04, 0.22)
	_ip(hl, {"tint": Color(1, 1, 1, 0.95), "near_a": 0.3, "near_b": 1.0})
	holder.basis = Basis.looking_at(aim, Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT)
	var hand: Vector3 = j._hand(c)
	_fingertip_burst(hand, aim)
	pr.on_tick = func(p: Projectile, _dt: float) -> void:
		if randf() < 0.45:
			var q = p.global_position - aim * 0.6 + Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
			var dr = _bit(q, Vector3.ONE * randf_range(0.05, 0.09), Color.WHITE, "drop")
			_fly(dr, q, aim * randf_range(3.0, 8.0) + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.0), randf_range(-0.6, 0.6)), 16.0, 0.35)
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		_gun_splash(pos, aim)
	j.get_tree().current_scene.add_child(pr)
	pr.global_position = hand
	Sfx.play("water", c.global_position, 1.8, 0.6)


## Parmak ucunda: ileri püsküren ince damlalar + küçük basınç halkası
static func _fingertip_burst(p: Vector3, aim: Vector3) -> void:
	for k in 7:
		var v = (aim + Vector3(randf_range(-0.25, 0.25), randf_range(-0.15, 0.3), randf_range(-0.25, 0.25))).normalized() * randf_range(4.0, 8.0)
		var dr = _bit(p, Vector3.ONE * randf_range(0.04, 0.07), Color.WHITE, "drop")
		_fly(dr, p, v, 14.0, 0.3)
	_ring(p + aim * 0.3, 1.2, aim, Color(0.88, 0.96, 1.0), Color(0.15, 0.4, 0.85), 0.05, 0.45, 0.03, 0.22, {"near_a": 0.4, "near_b": 1.4})


## Çarpma: tacı açılan su sıçraması (yukarı kıvrılan damlalar) + yüzeye dik halka
static func _gun_splash(pos: Vector3, aim: Vector3) -> void:
	for k in 12:
		var a = TAU * k / 12.0
		var side = aim.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var up = side.cross(aim).normalized()
		var v = (side * cos(a) + up * sin(a)) * randf_range(2.5, 4.5) - aim * randf_range(0.5, 2.0) + Vector3.UP * 1.5
		var dr = _bit(pos, Vector3.ONE * randf_range(0.06, 0.11), Color.WHITE, "drop")
		_fly(dr, pos, v, 14.0, randf_range(0.4, 0.6))
	_ring(pos - aim * 0.1, 2.4, -aim, Color(0.9, 0.97, 1.0), Color(0.15, 0.4, 0.85), 0.1, 1.0, 0.05, 0.3, {"near_a": 0.5, "near_b": 1.8})
	var gy = Game.jutsu_floor_at(pos).y
	if pos.y - gy < 1.6:
		_ring(Vector3(pos.x, gy + 0.04, pos.z), 2.4, Vector3.ZERO, Color(0.85, 0.95, 1.0), Color(0.2, 0.45, 0.85), 0.1, 0.9, 0.04, 0.6)


# ================================================================== 10. Magen: Kijō no Rōkaku
## Ref (Ōhamaguri buharı): dev istiridyeden kabaran ak-gri cel buhar; seraplar ısı titremesiyle belirir, bitince buhara dağılır
static func magen_kijo_no_rokaku(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	pj.anim(c, "seal", 1.0)
	var at = pj.gp(c.global_position - c.face_dir() * 3.0)
	_steam_jet(at)
	# vurulabilir dev istiridye (kanon: yanılsamayı bitirmenin tek yolu istiridyeyi yenmek)
	var units = ClanConstruct.spawn(c, "clam", 1, Jutsu._jd("magen_kijo_no_rokaku"))
	var clam = units[0] if units is Array and not units.is_empty() else null
	if clam:
		clam.global_position = at
		clam.life = 14.5
	var dur = 14.0
	Sfx.play("th_steam", at, 0.8)
	var mirages = []
	for k in 3:
		var a = TAU * k / 3.0
		var q = pj.gp(c.global_position + Vector3(cos(a), 0, sin(a)) * 4.5)
		var dc = pj.decoy(c, q, dur)
		if dc:
			mirages.append(dc)
			_mirage_skin(dc)
	var ended = {"v": false}
	var end_fx = func(broken: bool):
		if ended["v"]:
			return
		ended["v"] = true
		for m in mirages:
			if is_instance_valid(m):
				_steam_release(m.global_position)
				m.queue_free()
		if broken:
			Combat.popup_text(at + Vector3.UP * 2.0, "İstiridye düştü: yanılsama bozuldu!", Color(0.8, 0.9, 1.0))
		elif is_instance_valid(clam) and not clam.dead:
			_steam_jet(at, 0.6)
			clam.vanish()
	pj.every(dur, 0.4, func(i, _k):
		if ended["v"]:
			return
		if clam == null or not is_instance_valid(clam) or clam.dead:
			end_fx.call(true)
			return
		_steam_rise(at, i, mirages)
		for e in pj.enemies_near(c, c.global_position, 14.0):
			if i % 3 == 0:
				pj.st(e, "slow", 1.4)
				if randf() < 0.3:
					pj.st(e, "fear", 0.8)   # seraplar arasında yön şaşar
		if not pj.live(c):
			end_fx.call(false), func():
		end_fx.call(false))


## İstiridyeden fışkıran buhar sütunu + yerde yayılan alçak buhar
static func _steam_jet(at: Vector3, s := 1.0) -> void:
	var near = Vector2(2.0, 7.0)
	for k in int(8 * s):
		var d = k * 0.04
		var p = at + Vector3(randf_range(-0.3, 0.3), 0.6 + k * 0.15, randf_range(-0.3, 0.3))
		var v = Vector3(randf_range(-0.4, 0.4), randf_range(4.0, 6.0), randf_range(-0.4, 0.4))
		_later(d, func(): _puff(p, randf_range(0.7, 1.1), STEAM_PAL, v, 1.3, 2.0, near))
	for k in int(6 * s):
		var a = TAU * k / 6.0
		var dv = Vector3(cos(a), 0, sin(a))
		_puff(at + dv * 0.8 + Vector3.UP * 0.25, 1.0, STEAM_PAL, dv * 2.0, 1.6, 1.6, near, 0.4)


## Sürekli buhar: istiridyeden kabaran topaklar; ara ara seraplara doğru yerde akan buhar
static func _steam_rise(at: Vector3, i: int, mirages: Array) -> void:
	var near = Vector2(2.0, 7.0)
	for k in 2:
		var p = at + Vector3(randf_range(-0.5, 0.5), randf_range(0.8, 1.3), randf_range(-0.5, 0.5))
		_puff(p, randf_range(1.0, 1.5), STEAM_PAL, Vector3(randf_range(-0.4, 0.4), randf_range(1.4, 2.4), randf_range(-0.4, 0.4)), 2.2, 2.1, near)
	if i % 3 == 0 and not mirages.is_empty():
		var m = mirages[randi() % mirages.size()]
		if is_instance_valid(m):
			var dv: Vector3 = (m as Node3D).global_position - at
			dv.y = 0.0
			_puff(at + Vector3.UP * 0.3, 1.2, STEAM_PAL, dv / 2.4, 2.4, 1.8, near, 0.4)


## Serap kopya: bedeni ısı titremesiyle dalgalanır (yatay kayan ışık bantları)
static func _mirage_skin(dc: Node3D) -> void:
	var w = weakref(dc)
	_later(0.05, func():
		var d = w.get_ref()
		if d == null or not is_instance_valid(d):
			return
		var mat: ShaderMaterial = _mat("rim").duplicate()
		mat.set_shader_parameter("col", Color(1.0, 0.97, 0.92, 0.85))
		mat.set_shader_parameter("amt", 0.6)
		mat.set_shader_parameter("shimmer", 1.0)
		for mi in (d as Node).find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay == null:
				(mi as MeshInstance3D).material_overlay = mat)


## Serap çözülür: yerinde yükselip dağılan buhar
static func _steam_release(p: Vector3) -> void:
	for k in 5:
		var q = p + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.7), randf_range(-0.3, 0.3))
		_puff(q, 0.7, STEAM_PAL, Vector3(randf_range(-0.5, 0.5), randf_range(1.5, 2.5), randf_range(-0.5, 0.5)), 1.1, 1.8, Vector2(1.5, 6.0))


# ================================================================== 11-13. Hyūga
## Gerçek Byakugan göz sistemi (damarlar dahil); el görseli ayrı
static func _byakugan_eyes(pj: PathJutsu, c: Node3D, dur: float) -> void:
	if c.get("model") and c.model.has_method("set_dojutsu_eyes"):
		c.model.set_dojutsu_eyes(2, 1, 2, 1, true)
		pj.after(dur, func():
			if is_instance_valid(c) and c.get("model"):
				if c is Player and c.combat and c.combat.modes and c.combat.modes.eyes:
					c.combat.modes.eyes.refresh_visual()
				else:
					c.model.set_dojutsu_eyes(0, 0, 0, 0, false))


## Avuçta chakra: elin çevresinde dönen ince ak-mavi akış telleri + sönük çekirdek (kemiğe bağlı, eli izler)
static func _chakra_palms(pj: PathJutsu, c: Node3D, dur: float) -> void:
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba == null:
			continue
		var spin = Node3D.new()
		ba.add_child(spin)
		spin.position = Vector3(0, 0.08, 0)
		for k in 4:
			var pts = []
			var radii = []
			var a0 = TAU * k / 4.0
			for i in 7:
				var s = float(i) / 6.0
				var a = a0 + s * 2.2
				pts.append(Vector3(cos(a) * 0.1, (s - 0.5) * 0.14 + 0.02 * k, sin(a) * 0.1))
				radii.append(0.008 * sin(s * PI) + 0.002)
			var fl = _mi(_tube(pts, radii, 4, []), _mat("add"))
			spin.add_child(fl)
			_ip(fl, {"tint": JUKEN, "near_a": 0.3, "near_b": 1.0})
		var core = _mi(_sphere(8), _mat("add"))
		spin.add_child(core)
		core.scale = Vector3.ONE * 0.13
		_ip(core, {"tint": Color(JUKEN.r * 0.5, JUKEN.g * 0.55, JUKEN.b * 0.7, 1.0), "near_a": 0.3, "near_b": 1.0})
		var tw = Game.safe_loops(spin.create_tween(), int(ceil(dur / 0.3)) + 1)
		tw.tween_property(spin, "rotation:y", TAU, 0.3).from(0.0)
		pj.free_after(dur, ba)


## Tenketsu darbesi: avucun değdiği noktada basınç dalgacığı, dışarıdan noktaya saplanan ince chakra iğneleri (iç hasar)
static func _tenketsu_strike(p: Vector3, dir: Vector3) -> void:
	_ring(p, 2.0, dir, Color(0.95, 0.98, 1.0), JUKEN_DK, 0.08, 0.75, 0.035, 0.2, {"near_a": 0.4, "near_b": 1.6})
	var side = dir.cross(Vector3.UP).normalized()
	for k in 6:
		var a = TAU * k / 6.0 + randf_range(-0.2, 0.2)
		var off = (side * cos(a) + Vector3.UP * sin(a)) * 0.55 - dir * 0.15
		var nd = _mi(_box(), _mat("add"))
		_add(nd, p + off)
		_orient(nd, -off)
		nd.scale = Vector3(0.018, 0.018, 0.4)
		_ip(nd, {"tint": JUKEN, "near_a": 0.4, "near_b": 1.4})
		var tw = nd.create_tween().set_parallel(true)
		tw.tween_property(nd, "global_position", p + dir * 0.15, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(nd, "scale", Vector3(0.01, 0.01, 0.05), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(nd.queue_free)
	var dot = _mi(_sphere(8), _mat("add"))
	_add(dot, p + dir * 0.12)
	dot.scale = Vector3.ONE * 0.12
	_ip(dot, {"tint": Color(1, 1, 1), "near_a": 0.4, "near_b": 1.4})
	_fade_all(dot, 0.08, 0.2)


## Chakra noktaları kapanır (kanon): durum + bedende sırayla sönen nokta dizisi (orta hat ve kollarda)
static func _tenketsu_close(pj: PathJutsu, t: Node3D, dur: float, col := Color(0.55, 0.8, 1.0)) -> void:
	if not pj.live(t):
		return
	pj.st(t, "sealed", dur)
	Combat.popup_text(t.global_position + Vector3.UP * (t.height + 1.0), "Chakra noktaları kapandı!", col)
	var b = MB.new()
	var h: float = t.height
	var r: float = t.radius
	for k in 7:   # orta hat
		b.add("sphere", Vector3(0, h * (0.35 + k * 0.08), -r * 0.95), Vector3.ONE * 0.06, Color.WHITE, Vector3.ZERO, 5)
	for sg in [-1.0, 1.0]:   # omuz/kol
		for k in 3:
			b.add("sphere", Vector3(sg * r * (0.8 + k * 0.25), h * (0.72 - k * 0.08), -r * 0.6), Vector3.ONE * 0.05, Color.WHITE, Vector3.ZERO, 5)
	var mi = _mi(b.build(null), _mat("add"))
	t.add_child(mi)
	_ip(mi, {"tint": col, "near_a": 0.4, "near_b": 1.4})
	var mw = weakref(mi)
	var blink = func(i, _k) -> void:
		var m = mw.get_ref()
		if m != null and is_instance_valid(m):
			(m as GeometryInstance3D).set_instance_shader_parameter("fade", 1.0 if i < 3 else (0.35 + 0.3 * float(i % 2)))
	var done = func() -> void:
		var m = mw.get_ref()
		if m != null and is_instance_valid(m):
			m.queue_free()
	pj.every(dur, 0.25, blink, done)
	free_later(mi, dur + 0.5)


## Ref (Neji): ileri basan ayakta toz sürtünmesi
static func _foot_scuff(c: Node3D) -> void:
	var fd: Vector3 = c.face_dir()
	var p = Vector3(c.global_position.x, Game.jutsu_floor_at(c.global_position).y, c.global_position.z) + fd * 0.4
	for k in 3:
		var side = fd.cross(Vector3.UP).normalized() * randf_range(-0.3, 0.3)
		_puff(p + side + Vector3.UP * 0.12, 0.35, DUST_PAL, -fd * randf_range(0.6, 1.2) + Vector3.UP * 0.3, 0.5, 1.5, Vector2(1.0, 4.0), 0.5)
	_clods(p, 3, 1.0, 0.45)


static func juken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_chakra_palms(pj, c, 1.2)
	var tt = pj.tg(c, t, 6.0)
	if tt and is_instance_valid(tt):
		c.global_position = pj.gp(tt.global_position - (tt.global_position - c.global_position).normalized() * (tt.radius + 1.0))
		if c is Player:
			c.combat.face_to(tt)
	pj.busy(c, 0.7)
	_byakugan_eyes(pj, c, 1.2)
	pj.every(0.6, 0.2, func(i, _k):
		pj.anim(c, ["jab", "cross", "jab"][i], 2.4)
		var p = c.global_position + Vector3.UP * 1.1 + c.face_dir() * 1.1
		_tenketsu_strike(p, c.face_dir())
		if i != 1:
			_foot_scuff(c)
		for h in pj.hit(c, p, 1.0, pj.inf(c, "juken", 0.55, {"knock": 1.0, "kind": "light", "pierce_guard": true})):
			_tenketsu_close(pj, h, 1.5 * (i + 1))
		Sfx.play("punch", p, 1.2))


## Jūkenhō Ichigekishin (kanon, Neji): Hyūga bedenindeki bütün tenketsulardan aynı anda chakra fışkırtır — yakındakiler
## savrulur; ağ, su hapsi gibi bağlar parçalanır. Ref: bedeni saran ak, sivri dikenli patlama silüeti (koyu kenarlı), uçuşan ak kırıntı
static func jukenho_ichigekishin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	_byakugan_eyes(pj, c, 0.9)
	pj.anim(c, "crouch", 2.4)
	var col = Color(0.78, 0.9, 1.0)
	# bağı çözer (kanon: bütün beden chakra basıncı)
	for k in ["bind", "mud", "slow", "chilled"]:
		if c.get("statuses") != null:
			c.statuses.erase(k)
	if c is Player:
		c.input_locked = 0.0
	# toplanma: tenketsu noktalarında küçük ışıltılar (bedene bağlı, sırayla yanar)
	var dots = []
	for k in 14:
		var q = Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.7), randf_range(-0.3, 0.3))
		var dt_ = _mi(_sphere(6), _mat("add"))
		c.add_child(dt_)
		dt_.position = q
		dt_.scale = Vector3.ONE * 0.001
		_ip(dt_, {"tint": col, "near_a": 0.4, "near_b": 1.4})
		var tw = dt_.create_tween()
		tw.tween_interval(k * 0.008)
		tw.tween_property(dt_, "scale", Vector3.ONE * 0.09, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		dots.append(dt_)
	pj.after(0.16, func():
		for dt_ in dots:
			if is_instance_valid(dt_):
				dt_.queue_free()
		if not pj.live(c):
			return
		pj.anim(c, "cast_out", 2.0)
		var cp = c.global_position + Vector3.UP * 1.0
		_spike_burst(c)
		# zemin: kısa radyal çatlak + dışa savrulan toz + ak kırıntı
		var g = Vector3(c.global_position.x, Game.jutsu_floor_at(c.global_position).y, c.global_position.z)
		_cracks(g, 2.4, 10, Color(0.3, 0.33, 0.4), 1.6)
		_dust_ring(g, 1.3)
		_ring(g + Vector3.UP * 0.05, 8.0, Vector3.ZERO, Color(0.95, 0.98, 1.0), Color(0.35, 0.5, 0.75), 0.4, 3.4, 0.06, 0.32, {"near_a": 0.6, "near_b": 2.5})
		for k in 14:
			var a = randf() * TAU
			var fl = _bit(cp + Vector3(0, randf_range(-0.6, 0.7), 0), Vector3(0.05, 0.015, 0.09), Color(0.97, 0.98, 1.0), "flat")
			_fly(fl, fl.global_position, Vector3(cos(a), randf_range(-0.1, 0.6), sin(a)) * randf_range(5.0, 9.0), 4.0, randf_range(0.25, 0.4))
		# yakındaki mermiler/teknik parçaları basınçla söner
		for n in pj.get_tree().current_scene.get_children():
			if n is Projectile and not n.dead and n.shooter != c and n.global_position.distance_to(cp) < 3.0:
				n.block()
		for e in pj.enemies_near(c, c.global_position, 3.4):
			var v = e.global_position - c.global_position
			v.y = 0.0
			v = v.normalized() if v.length() > 0.05 else c.face_dir()
			pj.hit(c, e.global_position + Vector3.UP, 0.9, pj.inf(c, "jukenho_ichigekishin", 0.7, {"knock": 18.0, "launch": 3.0, "kind": "heavy", "dir": v, "hitstop": 0.06}))
		Combat.popup_text(c.global_position + Vector3.UP * 2.6, "Ichigekishin!", col)
		Sfx.play("wind", c.global_position, 1.3)
		pj.shake(0.35))


## Bedenden dışa fırlayan ak dikenler (koyu ince kenar), kısa durup geri çekilir
static func _spike_burst(c: Node3D) -> void:
	var cg: Vector3 = c.global_position
	for n in 46:
		var hy = randf_range(0.05, 1.85)
		var ang = randf() * TAU
		var outd = Vector3(cos(ang), randf_range(-0.3, 0.5) + (0.6 if hy > 1.6 else 0.0), sin(ang)).normalized()
		var basep = cg + Vector3(cos(ang) * 0.32, hy, sin(ang) * 0.32)
		var Ls = randf_range(0.45, 1.15)
		var sp = _mi(_spike(), _mat("flat"))
		_ip(sp, {"tint": Color(0.98, 0.99, 1.0), "near_a": 0.4, "near_b": 1.4})
		var hl = _outline(sp, Color(0.32, 0.38, 0.5), 0.03)
		hl.set_instance_shader_parameter("width", 0.03)
		_scene().add_child(sp)
		var sdv = outd.cross(Vector3.UP if absf(outd.y) < 0.95 else Vector3.RIGHT).normalized()
		var bsp = Basis(sdv, outd, sdv.cross(outd))
		var grow = func(x: float) -> void:
			if is_instance_valid(sp):
				sp.global_transform = Transform3D(bsp * Basis.from_scale(Vector3(1, maxf(0.01, Ls * x), 1)), basep + outd * Ls * x * 0.5)
		var shrink = func(x: float) -> void:
			if is_instance_valid(sp):
				sp.global_transform = Transform3D(bsp * Basis.from_scale(Vector3(x, maxf(0.01, Ls * x), x)), basep + outd * Ls * x * 0.5)
		grow.call(0.01)
		var stw = sp.create_tween()
		stw.tween_method(grow, 0.0, 1.0, 0.08)
		stw.tween_interval(0.22)
		stw.tween_method(shrink, 1.0, 0.0, 0.15)
		stw.tween_callback(sp.queue_free)


## Kafes Kuş Mührü (ref): alında iki yan çizgi arasında X, yanlardan kıvrılan yeşil dokunaçlar; koyu yeşil kenar
static func _cage_mesh() -> ArrayMesh:
	if _cache.has("mesh:cage"):
		return _cache["mesh:cage"]
	var st = _strip_begin()
	var lines = []
	for sg in [-1.0, 1.0]:
		var dd = Vector3(cos(deg_to_rad(38.0)) * sg, sin(deg_to_rad(38.0)), 0)
		lines.append([-dd * 0.04, dd * 0.04])
		lines.append([Vector3(sg * 0.042, -0.012, 0), Vector3(sg * 0.068, 0.012, 0)])
		var curl = []
		for i in 12:   # kıvrılan dokunaç
			var s = float(i) / 11.0
			var a = s * 4.2
			var r = 0.02 * (1.0 - s * 0.6)
			curl.append(Vector3(sg * (0.07 + s * 0.035 + cos(a) * r * 0.5), 0.012 + sin(a) * r, 0))
		lines.append(curl)
	for ln in lines:
		_strip(st, ln, 0.016, CAGE_DK, Vector3.BACK, false)
	for ln in lines:
		_strip(st, ln, 0.008, CAGE, Vector3.BACK, false, Vector3.BACK * 0.001)
	var m = st.commit()
	_cache["mesh:cage"] = m
	return m


static func _caged_bird_seal(pj: PathJutsu, tt: Node3D) -> Node3D:
	var m = tt.get("model")
	if m == null or not is_instance_valid(m):
		return null
	var mi = _mi(_cage_mesh(), _mat("flat"))
	_ip(mi, {"tint": Color.WHITE, "near_a": 0.2, "near_b": 0.6})
	# konum: kafa kemiğinden, kişinin gerçek bakış yönüne göre alın (modelin yerel ekseni yüzün tersine bakıyor)
	var fd: Vector3 = tt.face_dir() if tt.has_method("face_dir") else -m.global_transform.basis.z
	var ba = pj.bone_attach(tt, "Head")
	var head: Vector3 = m.global_position + Vector3.UP * 1.62
	var bone_xf := Transform3D.IDENTITY
	if ba:
		bone_xf = m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Head"))
		head = bone_xf.origin
	var at = head + Vector3.UP * 0.12 + fd * 0.135
	var xf = Transform3D(Basis.looking_at(-fd, Vector3.UP), at)   # desen yüzü dışarı (bakış yönüne) dönük
	if ba:
		ba.add_child(mi)
		mi.transform = bone_xf.affine_inverse() * xf   # kemiğe göre yerel (eklenti bir sonraki karede kemiğe oturur)
	else:
		pj.get_tree().current_scene.add_child(mi)
		mi.global_transform = xf
	return mi


static func hyuga_soke_no_juinjutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	if tt == null or not pj._caged_bird(tt):
		if c is Player:
			Hud.msg("Kafes Kuş Mührü yalnız alnı mühürlü Hyūga yan aile üyelerinde işler.", Color(0.6, 1.0, 0.7))
			c.combat.cooldowns["hyuga_soke_no_juinjutsu"] = 1.0
		return
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.4)   # tek el mührü
	_hand_glyph(pj.hand_pos(c, true), c.face_dir())
	var seal = _caged_bird_seal(pj, tt)
	Combat.popup_text(tt.global_position + Vector3.UP * (tt.height + 0.9), "Kafes Kuş Mührü!", Color(0.45, 1.0, 0.6))
	Sfx.play("seal", tt.global_position, 0.9)
	pj.st(tt, "stun", 4.0)
	pj.every(4.0, 0.4, func(i, _k):
		if not pj.live(tt):
			return
		if tt.get("model"):
			tt.model.play("hit_head" if i % 2 == 0 else "hit", 0.05, 0.9, true)   # başını tutup kıvranır
		if is_instance_valid(seal):
			seal.scale = Vector3.ONE * (1.0 + 0.25 * float(i % 2))
			_pain_veins(seal)
		tt.take_hit(pj.inf(c, "hyuga_soke_no_juinjutsu", 0.3, {"knock": 0.0, "kind": "light", "pierce_guard": true})), func():
		if is_instance_valid(seal):
			(seal.get_parent() if seal.get_parent() is BoneAttachment3D else seal).queue_free())


## Ana ailenin tek el mührü: işaret parmağının önünde bir an yanan küçük yeşil X
static func _hand_glyph(p: Vector3, fd: Vector3) -> void:
	var mi = _mi(_cage_mesh(), _mat("flat"))
	_add(mi, p + fd * 0.2 + Vector3.UP * 0.05)
	_orient(mi, -fd)
	mi.scale = Vector3.ONE * 1.5
	_ip(mi, {"tint": Color.WHITE, "near_a": 0.2, "near_b": 0.8})
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_all(mi, 0.15, 0.25)


## Mühürden alna yayılan kısa, kırık yeşil acı damarları
static func _pain_veins(seal: Node3D) -> void:
	var st = _strip_begin()
	for k in 3:
		var a = randf_range(-0.6, 0.6) + (PI if k == 1 else 0.0)
		var pts = [Vector3.ZERO]
		for q in 3:
			a += randf_range(-0.6, 0.6)
			pts.append(pts[-1] + Vector3(cos(a), sin(a) * 0.6 + 0.3, 0) * 0.03)
		_strip(st, pts, 0.008, CAGE, Vector3.BACK, true, Vector3.BACK * 0.002)
	var mi = _mi(st.commit(), _mat("add"))
	seal.add_child(mi)
	_ip(mi, {"tint": Color.WHITE, "near_a": 0.2, "near_b": 0.6})
	_fade_all(mi, 0.08, 0.15)


# ================================================================== 14-16. Iburi (duman beden)
## Kemuri Ude: kol dumana çözülüp uzanır (kıvrılan cel duman borusu), ucunda katı bir duman yumruğu belirir, vurur, geri akar
static func _smoke_fist() -> ArrayMesh:
	if _cache.has("mesh:sfist"):
		return _cache["mesh:sfist"]
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(0.3, 0.28, 0.34), Color.WHITE, Vector3.ZERO, 12)
	for k in 4:
		b.add("sphere", Vector3(-0.1 + k * 0.067, 0.04 - absf(k - 1.5) * 0.015, -0.16), Vector3(0.1, 0.11, 0.12), Color.WHITE, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0.15, -0.04, -0.05), Vector3(0.09, 0.09, 0.15), Color.WHITE, Vector3.ZERO, 8)
	var m = b.build(null)
	_cache["mesh:sfist"] = m
	return m


static func iburi_kemuri_ude(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "iburi_kemuri_ude"
	var tt = pj.tg(c, t, 10.0)
	var d = pj._face(c, tt)
	pj.anim(c, "push", 1.6)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var reach = {"k": 0.0}
	var arm = _mi(ArrayMesh.new(), _mat("cloud2"))
	_add(arm, Vector3.ZERO)
	_ip(arm, {"lit_col": SMOKE_PAL[0], "shd_col": SMOKE_PAL[1], "edge_col": SMOKE_PAL[2], "seed": randf() * 30.0, "near_a": 1.2, "near_b": 4.5})
	var fist = _mi(_smoke_fist(), _mat("cloud"))
	_add(fist, pj.hand_pos(c, true))
	_ip(fist, {"lit_col": Color(0.86, 0.86, 0.88, 1.0), "shd_col": SMOKE_PAL[1], "edge_col": SMOKE_PAL[2], "seed": randf() * 30.0, "near_a": 1.0, "near_b": 4.0})
	fist.scale = Vector3.ONE * 0.01
	pj.every(0.6, 0.03, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var x = tw.get_ref() if tw else null
		var a: Vector3 = pj.hand_pos(cc)
		var b: Vector3 = (x.global_position + Vector3.UP * 1.2) if x != null and is_instance_valid(x) else a + d * 8.0
		var u = minf(1.0, k * 2.5) if k < 0.7 else (1.0 - (k - 0.7) / 0.3)
		var tip: Vector3 = a.lerp(b, u)
		_smoke_arm(arm, a, tip, i)
		if is_instance_valid(fist):
			fist.global_position = tip
			_orient(fist, (tip - a) if (tip - a).length() > 0.05 else d)
			var fs = clampf((u - 0.3) / 0.5, 0.01, 1.0) * 1.3
			fist.scale = Vector3.ONE * fs
		if i % 3 == 0 and u > 0.2:   # boru boyunca kopan duman
			var s = randf()
			_puff(a.lerp(tip, s), 0.3, SMOKE_PAL, Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3)), 0.6, 1.8, Vector2(1.2, 4.5))
		reach["k"] = u, func():
		if is_instance_valid(arm):
			arm.queue_free()
		if is_instance_valid(fist):
			_puff(fist.global_position, 0.4, SMOKE_PAL, Vector3.UP * 0.5, 0.5, 1.6, Vector2(1.2, 4.5))
			fist.queue_free())
	pj.after(0.25, func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		_smoke_knock(x.global_position + Vector3.UP * 1.2, d)
		Sfx.play("punch", x.global_position, 0.8)
		x.take_hit(pj.inf(cc, id, 1.4, {"knock": 10.0, "kind": "heavy", "hitstop": 0.08, "pierce_guard": true, "dir": d})))
	Sfx.play("smoke", c.global_position, 1.2)


## Duman kolu: elden uca kıvrılarak uzanan boru (her adımda yeniden kurulur; ortası şişkin, dalgalı)
static func _smoke_arm(arm: MeshInstance3D, a: Vector3, tip: Vector3, i: int) -> void:
	if not is_instance_valid(arm):
		return
	var L = a.distance_to(tip)
	if L < 0.08:
		arm.visible = false
		return
	arm.visible = true
	var dv = (tip - a).normalized()
	var side = dv.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var upv = side.cross(dv).normalized()
	var pts = []
	var radii = []
	for q in 12:
		var s = float(q) / 11.0
		var wob = sin(s * PI) * 0.18
		pts.append(a.lerp(tip, s) + side * sin(s * 7.0 + i * 0.5) * wob + upv * cos(s * 5.0 + i * 0.4) * wob * 0.6)
		radii.append(0.07 + sin(s * PI) * 0.1)
	arm.mesh = _tube(pts, radii, 8)


## Yumruk çarpması: darbe yönüne dik düzlemde halka halka dışa savrulan duman + geriye kopan ince duman
static func _smoke_knock(p: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	for k in 8:
		var a = TAU * k / 8.0
		var dv = side * cos(a) + Vector3.UP * sin(a)
		_puff(p, 0.4, SMOKE_PAL, dv * 2.6 + d * 0.6, 0.55, 1.9, Vector2(1.2, 4.5), 1.0)
	_puff(p + d * 0.3, 0.6, SMOKE_PAL, d * 2.0, 0.7, 1.6, Vector2(1.2, 4.5))


## Sanka Kemuri: ağızdan kahve-pas renkli sıcak duman akıntısı, içinde kor kıvılcımları; değdiği yerde pas pulları dökülür
static func iburi_sanka_kemuri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var id = "iburi_sanka_kemuri"
	var tt = pj.tg(c, t, 12.0)
	var d = pj._face(c, tt)
	pj.anim(c, "cast", 1.0)
	var cw = weakref(c)
	var hitk = {}
	pj.every(0.9, 0.05, func(i, k):
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var mouth: Vector3 = cc.global_position + Vector3.UP * 1.55 + d * 0.4
		for q in 2:
			var v = (d + Vector3(randf_range(-0.14, 0.14), randf_range(-0.08, 0.12), randf_range(-0.14, 0.14))).normalized() * randf_range(6.5, 9.5)
			_puff(mouth + d * 0.2, randf_range(0.28, 0.4), RUST_PAL, v, 0.85, 4.0, Vector2(2.5, 7.0))
		if i % 2 == 0:   # kor kıvılcımları
			for q in 2:
				var ev = (d + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.25), randf_range(-0.2, 0.2))).normalized() * randf_range(5.0, 8.0)
				var em = _bit(mouth + d * 0.6, Vector3.ONE * 0.04, EMBER, "add", Vector2(1.5, 4.0))
				_fly(em, em.global_position, ev, -1.5, 0.6)
		for e in pj.enemies_near(cc, cc.global_position + d * 4.0, 4.0):
			var v: Vector3 = e.global_position - cc.global_position
			v.y = 0
			if v.normalized().dot(d) < 0.7:
				continue
			pj.st(e, "slow", 1.0)
			var key = e.get_instance_id()
			if not hitk.has(key) or i % 6 == 0:
				hitk[key] = true
				_rust_flakes(e)
				e.take_hit(pj.inf(cc, id, 0.35, {"knock": 0.5, "kind": "light", "burn": 2.5, "element": "katon", "hitstop": 0.0})))
	Sfx.play("smoke", c.global_position, 0.8)


## Paslanma (kanon dışı türetme, açıklamadaki gibi): bedenden dökülen turuncu-kahve pullar + öksürükle çıkan küçük duman
static func _rust_flakes(e: Node3D) -> void:
	var h: float = e.height if e.get("height") != null else 1.8
	for k in 5:
		var p = e.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.4, h * 0.9), randf_range(-0.3, 0.3))
		var b = _bit(p, Vector3(0.06, 0.012, 0.05), RUST.lerp(Color(0.35, 0.18, 0.08), randf() * 0.5), "flat", Vector2(0.5, 2.0))
		_fly(b, p, Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), randf_range(-0.5, 0.5)), 3.0, randf_range(0.8, 1.2))
	_puff(e.global_position + Vector3.UP * h * 0.85, 0.22, SMOKE_PAL, Vector3.UP * 0.6, 0.5, 1.6, Vector2(1.0, 4.0))


## Kemuri Rōgoku: hedefin çevresinde üç sarmal kol hâlinde dönerek yükselen koyu duman sütunu, daralır; tepesi açılır,
## bitince sütun dışa çözülür
static func iburi_kemuri_rogoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var id = "iburi_kemuri_rogoku"
	var tt = pj.tg(c, t, 18.0)
	var d = pj._face(c, tt)
	pj._yama_seal(c)
	var cw = weakref(c)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var caught = []
	for e in pj.enemies_near(c, at, 2.0):
		caught.append(weakref(e))
	Sfx.play("smoke", at, 0.7)
	for k in 8:   # tabanda dönen alçak duman
		var a = TAU * k / 8.0
		_puff(at + Vector3(cos(a), 0.2, sin(a)) * 1.9, 0.9, PRISON_PAL, Vector3(-sin(a), 0, cos(a)) * 1.6, 1.2, 1.4, Vector2(3.0, 8.0), 0.45)
	pj.every(2.6, 0.08, func(i, k):
		var cc = cw.get_ref()
		var r = 1.8 * (1.0 - k * 0.5)
		for q in 3:   # dönerek yükselen duman duvarı (üç sarmal)
			var a0 = i * 0.5 + q * TAU / 3.0
			_helix_puff(at, a0, r)
		if i % 4 == 0:   # tepe dışa açılır
			var a1 = randf() * TAU
			_puff(at + Vector3(cos(a1) * r, 3.4, sin(a1) * r), 1.0, PRISON_PAL, Vector3(cos(a1), 0.3, sin(a1)) * 1.4, 1.0, 1.6, Vector2(3.0, 8.0))
		if cc == null or not pj.live(cc):
			return
		for w in caught:
			var e = w.get_ref()
			if e != null and pj.live(e):
				pj.st(e, "bind", 0.2)
				if e.has_method("lose_target"):
					e.lose_target(0.3)
				if i % 6 == 0:
					e.take_hit(pj.inf(cc, id, 0.12, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "pierce_guard": true})), func():
		for k in 10:   # sütun çözülür
			var hy = randf_range(0.4, 3.2)
			var a2 = randf() * TAU
			_puff(at + Vector3(cos(a2) * 0.9, hy, sin(a2) * 0.9), 1.0, PRISON_PAL, Vector3(cos(a2) * 2.0, 0.8, sin(a2) * 2.0), 1.1, 1.6, Vector2(3.0, 8.0)))


## Sarmal duman topağı: tabandan dönerek yükselir, yükseldikçe merkeze yaklaşır
static func _helix_puff(at: Vector3, a0: float, r: float) -> void:
	var mi = _puff(at + Vector3(cos(a0) * r, 0.2, sin(a0) * r), randf_range(0.9, 1.25), PRISON_PAL, Vector3.ZERO, 1.2, 1.35, Vector2(3.0, 8.0))
	var step = func(x: float) -> void:
		if is_instance_valid(mi):
			var aa = a0 + x * 2.2
			var rr = r * (1.0 - x * 0.25)
			mi.global_position = at + Vector3(cos(aa) * rr, 0.2 + x * 3.2, sin(aa) * rr)
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, 1.0, 1.2)
