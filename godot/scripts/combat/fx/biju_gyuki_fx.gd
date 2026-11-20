class_name BijuGyukiFX
extends RefCounted
## Gyūki (Sekiz Kuyruk) tekniklerinin KENDİ görselleri: mürekkep ve dokunaç. Ortak duman / ateş / çatlak / moloz yok.
## Kaynak (anime): mürekkep = simsiyah, mor parlamalı, koyu sıvı; jet hâlinde ağızdan fışkırır, yerde göl olur, bulut hâlinde
## kaçışı örter; dokunaç (Lariat) yere çarpınca toprak yarılır, toz halkası kalkar.

## Mürekkep akışı (jet konisi): koyu, mor parıltılı akan sıvı
const _INK_FLOW := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float n = n2(vec2(UV.x * 8.0, UV.y * 4.0 - TIME * 5.0));
	ALBEDO = mix(vec3(0.02, 0.01, 0.03), vec3(0.22, 0.12, 0.3), smoothstep(0.6, 0.9, n));
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
"""

## Mürekkep bulutu kütlesi: kapkara, kenarında mor cel çizgi
const _CLOUD := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float a = 0.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(vec3(0.32, 0.18, 0.42), vec3(0.04, 0.02, 0.06), step(0.25, f));
	ALPHA = smoothstep(0.0, 0.7, f) * a;
}
"""

## Dokunaç çarpma yarığı: kahverengi ışınsal kırık
const _CRACK := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 5.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 9.7 + seed) * 517.3);
	float ca = (sec + 0.5 + (off - 0.5) * 0.7) / n * 6.28318 - 3.14159;
	float d = abs(sin(a - ca - 0.1 * sin(r * 11.0 + off * 3.0))) * r;
	float line = (1.0 - smoothstep(0.02, 0.07 * (1.2 - r), d)) * (1.0 - smoothstep(mix(0.6, 1.0, off) * 0.85, mix(0.6, 1.0, off), r));
	ALBEDO = vec3(0.14, 0.1, 0.08);
	ALPHA = max(line, (1.0 - smoothstep(0.12, 0.25, r)) * 0.85) * (1.0 - smoothstep(0.7, 1.0, t));
}
"""

static var _c := {}


static func ink_mat() -> ShaderMaterial:
	if not _c.has("flow"):
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("gyk_flow", _INK_FLOW)
		_c["flow"] = m
	return _c["flow"]


static func _blob() -> Mesh:
	if not _c.has("blob"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.85
		m.radial_segments = 10
		m.rings = 5
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.04, 0.02, 0.06)
		mt.roughness = 0.08
		mt.metallic_specular = 1.0
		mt.rim_enabled = true
		mt.rim = 0.5
		m.material = mt
		_c["blob"] = m
	return _c["blob"]


static func _clod() -> Mesh:
	if not _c.has("clod"):
		var m := PrismMesh.new()
		m.size = Vector3(1.0, 0.8, 0.8)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.4, 0.33, 0.26)
		mt.roughness = 1.0
		m.material = mt
		_c["clod"] = m
	return _c["clod"]


## Jet boyunca fışkıran mürekkep damlaları
static func ink_spray(from: Vector3, dir: Vector3, s: float) -> void:
	BeastFX._parts(from, _blob(), 6, 0.6, 24.0 * sqrt(s), 34.0 * sqrt(s), dir, 9.0, Vector3(0, -6, 0), 0.25 * s, 0.5 * s, 0.3 * s, false, [[0.0, 1.0], [0.8, 0.9], [1.0, 0.0]], 0.4)


## Mürekkep bulutu (kaçış): kapkara kabaran kütleler
static func ink_cloud(o: Vector3, s: float, dur := 1.6) -> void:
	for k in 11:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 14
		sm.rings = 7
		mi.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("gyk_cloud", _CLOUD)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var off := Vector3(cos(a), randf_range(-0.3, 0.6), sin(a)) * 1.6 * s
		if not BeastFX._add(mi, o + off):
			return
		var sz := 1.5 * s * randf_range(0.7, 1.2)
		mi.scale = Vector3.ONE * sz * 0.3
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * sz * 1.4, dur).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.0, 0.95, 0.15)
		tw.chain().tween_method(func(x: float): m.set_shader_parameter("a", x), 0.95, 0.0, dur * 0.5)
		tw.chain().tween_callback(mi.queue_free)


## Mürekkep dalgasından yukarı-öne sıçrayan damlalar
static func ink_splash(q: Vector3, s: float, dir: Vector3) -> void:
	BeastFX._parts(q, _blob(), 12, 1.0, 4.0 * s, 10.0 * s, (Vector3.UP + dir).normalized(), 40.0, Vector3(0, -16, 0), 0.3 * s, 0.6 * s, 2.0 * s, false, [[0.0, 1.0], [0.8, 0.9], [1.0, 0.0]])


## Dokunaç yakalaması: vantuz çarpması — mürekkep damlası
static func grab_hit(tip: Vector3, s: float) -> void:
	BeastFX._parts(tip, _blob(), 8, 0.6, 2.0 * s, 5.0 * s, Vector3.UP, 180.0, Vector3(0, -10, 0), 0.12 * s, 0.25 * s, 0.3 * s)


## Dokunaç yere çarpması: yarık + toz halkası + toprak topakları
static func slam(p: Vector3, s: float) -> void:
	GroundFX.add(p, "cracked", 2.0 * s, 3.0)
	BeastFX._card("gyk_crack", _CRACK, BeastFX._ground(p), 4.0 * s, Vector3.UP, 3.0, {}, false)
	BeastFX._card("dring", BeastFX._DUST_RING, BeastFX._ground(p), 8.0 * s, Vector3.UP, 0.45, {"col": Color(0.78, 0.7, 0.6)})
	BeastFX._parts(p, _clod(), 10, 1.0, 5.0 * s, 10.0 * s, Vector3.UP, 45.0, Vector3(0, -24, 0), 0.25 * s, 0.5 * s, 1.0 * s, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
