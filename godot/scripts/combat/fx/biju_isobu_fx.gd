class_name BijuIsobuFX
extends RefCounted
## Isobu (Üç Kuyruk) tekniklerinin KENDİ görselleri: deniz suyu, mercan, yanılsama sisi. Ortak su / sis / çatlak yok.
## Kaynak (anime): su = koyu turkuaz gövdeli, beyaz köpük kenarlı; sıçrayınca iri parlak damlalar taç gibi açılır;
## mercan yerden kırık kabukla fışkırır; sis = deniz üstü gibi yerde yayılan soluk camgöbeği yumuşak kütleler.

const SEA := Color(0.25, 0.62, 0.72)
const FOAM := Color(0.92, 0.98, 1.0)

## Köpük halkası: dışa açılan beyaz köpük + içinde turkuaz su lekesi
const _FOAM := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rad = mix(0.2, 0.92, t) + 0.05 * sin(a * 11.0 + seed) + 0.03 * sin(a * 29.0 - seed);
	float foam = smoothstep(rad - 0.12, rad, r) * (1.0 - smoothstep(rad, rad + 0.04, r));
	float water = (1.0 - smoothstep(rad - 0.2, rad - 0.1, r)) * 0.55;
	ALBEDO = mix(vec3(0.2, 0.55, 0.65), vec3(0.95, 1.0, 1.0), foam);
	ALPHA = max(foam, water) * (1.0 - smoothstep(0.55, 1.0, t));
}
"""

## Deniz dibi yarığı: koyu yeşil-mavi ışınsal kırıklar, kenarı ıslak parlak
const _CRACK := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 8.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 3.17 + seed) * 951.3);
	float ca = (sec + 0.5 + (off - 0.5) * 0.6) / n * 6.28318 - 3.14159;
	float d = abs(sin(a - ca - 0.1 * sin(r * 9.0 + off * 4.0))) * r;
	float line = (1.0 - smoothstep(0.02, 0.07 * (1.1 - r), d)) * (1.0 - smoothstep(mix(0.6, 1.0, off) * 0.85, mix(0.6, 1.0, off), r));
	ALBEDO = vec3(0.07, 0.16, 0.18);
	ROUGHNESS = 0.2;
	SPECULAR = 0.8;
	ALPHA = line * (1.0 - smoothstep(0.75, 1.0, t)) * 0.9;
}
"""

## Sis kütlesi: içi yoğun, kenarı yumuşak sönen soluk camgöbeği
const _MIST := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float a = 0.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.84, 0.97, 0.97);
	ALPHA = pow(f, 1.6) * a;
}
"""

static var _c := {}


static func _drop() -> Mesh:
	if not _c.has("drop"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.2
		m.radial_segments = 8
		m.rings = 5
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.6, 0.86, 0.95)
		mt.roughness = 0.05
		mt.metallic_specular = 1.0
		mt.rim_enabled = true
		mt.rim = 0.8
		m.material = mt
		_c["drop"] = m
	return _c["drop"]


static func _shard(col: Color) -> Mesh:
	var k := "sh%s" % col.to_html()
	if not _c.has(k):
		var m := PrismMesh.new()
		m.size = Vector3(0.6, 1.0, 0.4)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 0.7
		m.material = mt
		_c[k] = m
	return _c[k]


## Su sıçraması: iri parlak damlalar taç gibi açılır + köpük halkası
static func splash(pos: Vector3, s: float) -> void:
	var g := BeastFX._ground(pos)
	BeastFX._parts(g, _drop(), int(clampf(30 * s, 20, 70)), 1.0, 4.0 * s, 9.0 * s, Vector3.UP, 28.0, Vector3(0, -25, 0), 0.08 * s, 0.18 * s, 0.9 * s, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])
	BeastFX._card("isb_foam", _FOAM, g, 5.0 * s, Vector3.UP, 0.8)


## Mercan büyümesi: zeminde deniz dibi yarıkları, kırık kabuk + damlalar fışkırır
static func sango_burst(center: Vector3, R: float, s: float) -> void:
	BeastFX._card("isb_crack", _CRACK, BeastFX._ground(center), R * 2.4, Vector3.UP, 8.0, {}, false)
	BeastFX._parts(center, _shard(Color(0.9, 0.5, 0.5)), 16, 1.0, 4.0, 9.0, Vector3.UP, 50.0, Vector3(0, -18, 0), 0.25 * s, 0.5 * s, R * 0.6)
	BeastFX._parts(center, _drop(), 30, 0.9, 3.0, 8.0, Vector3.UP, 50.0, Vector3(0, -22, 0), 0.07 * s, 0.15 * s, R * 0.6, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])


## Yanılsama sisi: yerde yayılan, yavaşça süzülüp sönen yumuşak kütleler (dur sn)
static func mist(center: Vector3, R: float, s: float, dur: float) -> void:
	for k in 9:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("isb_mist", _MIST)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 9.0 + randf() * 0.5
		var off := Vector3(cos(a), 0, sin(a)) * R * randf_range(0.2, 0.75)
		if not BeastFX._add(mi, center + off + Vector3.UP * 1.2 * s):
			return
		mi.scale = Vector3(R * 0.7, R * 0.28, R * 0.7) * randf_range(0.8, 1.2)
		var tw := mi.create_tween()
		tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.0, 0.28, 0.8)
		tw.parallel().tween_property(mi, "global_position", mi.global_position + off.normalized() * R * 0.15 + Vector3.UP * 0.6 * s, dur)
		tw.parallel().tween_property(mi, "scale", mi.scale * 1.3, dur)
		tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.28, 0.0, 0.9)
		tw.tween_callback(mi.queue_free)


## Su hapsi patlaması: damlalar her yöne + dışa açılan köpük halkası (kameraya dönük)
static func prison_burst(pos: Vector3, R: float, s: float) -> void:
	BeastFX._parts(pos, _drop(), 70, 1.1, R * 2.5, R * 5.0, Vector3.UP, 180.0, Vector3(0, -22, 0), 0.1 * s, 0.22 * s, R * 0.8, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])
	var cam := BeastFX._tree().root.get_viewport().get_camera_3d()
	BeastFX._card("isb_foam", _FOAM, pos, R * 3.0, (cam.global_position - pos).normalized() if cam else Vector3.BACK, 0.5)
	splash(pos, s * 1.5)
