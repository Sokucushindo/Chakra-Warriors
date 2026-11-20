class_name BijuSaikenFX
extends RefCounted
## Saiken (Altı Kuyruk) tekniklerinin KENDİ görselleri: aşındırıcı sümük ve asit baloncukları. Ortak su / duman yok.
## Kaynak (anime): sümük = beyazımsı açık yeşil, parlak, ağır akan; baloncuklar saydam, yanardöner, patlayınca yapışkan damla saçar;
## asit sisi = sarımsı yeşil, koyu kenar çizgili yoğun bulut.

const ACID := Color(0.7, 0.95, 0.4)
const GOO := Color(0.82, 0.95, 0.88)

## Asit sisi kütlesi: içi sarı-yeşil, kenarında koyu yeşil cel çizgi
const _MIST := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float a = 0.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(vec3(0.25, 0.42, 0.12), vec3(0.78, 0.98, 0.55), step(0.22, f));
	ALBEDO = c;
	ALPHA = smoothstep(0.0, 0.3, f) * a;
}
"""

## Baloncuk: saydam, kenarı yanardöner (yeşil-pembe-mavi), parlak tepe noktası
const _BUBBLE := """
shader_type spatial;
render_mode cull_back, depth_draw_never;
uniform float a = 1.0;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 irid = 0.5 + 0.5 * cos(6.28318 * (f * 1.5 + vec3(0.0, 0.33, 0.67)));
	ALBEDO = mix(vec3(0.85, 1.0, 0.8), irid, 0.5);
	ROUGHNESS = 0.05;
	SPECULAR = 1.0;
	ALPHA = clamp(pow(f, 2.0) * 0.9 + 0.08, 0.0, 1.0) * a;
}
"""

## Sümük halkası: zeminde yayılan parlak sümük, kenarı kalın
const _GOO_RING := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = mix(0.3, 0.9, t) + 0.07 * sin(a * 8.0 + seed) + 0.04 * sin(a * 21.0);
	float m = 1.0 - smoothstep(edge - 0.05, edge, r);
	ALBEDO = vec3(0.82, 0.95, 0.88);
	ROUGHNESS = 0.1;
	SPECULAR = 0.9;
	ALPHA = m * 0.85 * (1.0 - smoothstep(0.6, 1.0, t));
}
"""

static var _c := {}


static func _blob() -> Mesh:
	if not _c.has("blob"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.85
		m.radial_segments = 10
		m.rings = 5
		var mt := StandardMaterial3D.new()
		mt.albedo_color = GOO
		mt.roughness = 0.08
		mt.metallic_specular = 1.0
		mt.rim_enabled = true
		m.material = mt
		_c["blob"] = m
	return _c["blob"]


static func _bubble_mesh() -> Mesh:
	if not _c.has("bub"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 14
		m.rings = 7
		var sm := ShaderMaterial.new()
		sm.shader = BeastFX._shader("sai_bubble", _BUBBLE)
		m.material = sm
		_c["bub"] = m
	return _c["bub"]


## Asit baloncuğu patlaması: yapışkan damlalar her yöne + küçük baloncuklar
static func acid_pop(pos: Vector3, s: float) -> void:
	BeastFX._parts(pos, _blob(), 12, 0.8, 3.0 * s, 7.0 * s, Vector3.UP, 180.0, Vector3(0, -14, 0), 0.12 * s, 0.25 * s, 0.4 * s, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])
	BeastFX._parts(pos, _bubble_mesh(), 6, 0.9, 1.0, 3.0, Vector3.UP, 120.0, Vector3(0, 1.5, 0), 0.2 * s, 0.4 * s, 0.4 * s, false, [[0.0, 0.5], [0.6, 1.0], [1.0, 0.0]])


## Sümük sıçraması: ağır damlalar + yayılan sümük halkası
static func splash(center: Vector3, s: float) -> void:
	BeastFX._parts(center, _blob(), 22, 1.0, 3.0 * s, 7.0 * s, Vector3.UP, 45.0, Vector3(0, -20, 0), 0.2 * s, 0.45 * s, 0.8 * s, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])
	BeastFX._card("sai_goo", _GOO_RING, BeastFX._ground(center), 5.0 * s, Vector3.UP, 1.2)


## Sümük gölünden yükselen baloncuk
static func bubble(pos: Vector3, s: float) -> void:
	BeastFX._parts(pos, _bubble_mesh(), 2, 1.0, 0.3, 1.0, Vector3.UP, 20.0, Vector3(0, 1.0, 0), 0.3 * s, 0.6 * s, 0.3 * s, false, [[0.0, 0.2], [0.8, 1.0], [1.0, 0.0]])


## Asit sisi (dur sn): yerde çöreklenen, yavaş kabaran sarı-yeşil kütleler
static func acid_mist(center: Vector3, R: float, s: float, dur: float) -> void:
	for k in 8:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 14
		sm.rings = 7
		mi.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("sai_mist", _MIST)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 8.0 + randf() * 0.5
		var off := Vector3(cos(a), 0, sin(a)) * R * randf_range(0.15, 0.7)
		if not BeastFX._add(mi, center + off + Vector3.UP * 1.2 * s):
			return
		mi.scale = Vector3(R * 0.55, R * 0.35, R * 0.55) * randf_range(0.8, 1.2)
		var tw := mi.create_tween()
		tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.0, 0.6, 0.7)
		tw.parallel().tween_property(mi, "scale", mi.scale * 1.25, dur)
		tw.parallel().tween_property(mi, "global_position", mi.global_position + Vector3.UP * 0.8 * s, dur)
		tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.6, 0.0, 0.8)
		tw.tween_callback(mi.queue_free)


## Aşınma köpürmesi (asitle eriyen hedefin üstünde): küçük baloncuklar
static func fizz(pos: Vector3, col: Color) -> void:
	var _c2 := col
	BeastFX._parts(pos, _bubble_mesh(), 4, 0.6, 0.5, 1.5, Vector3.UP, 60.0, Vector3(0, 2, 0), 0.12, 0.25, 0.3, false, [[0.0, 0.3], [0.6, 1.0], [1.0, 0.0]])
