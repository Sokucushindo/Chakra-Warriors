class_name BijuJubiFX
extends RefCounted
## On Kuyruk (Jūbi) ve Raijū tekniklerinin KENDİ görselleri: Tenpenchii doğal afetleri (yıldırım, hortum, deprem),
## dev Bijūdama'nın düştüğü yer. Ortak şimşek / hortum / çatlak / moloz yok.
## Kaynak (anime, Tenpenchii): gök kararır, yere zikzak beyaz-mavi yıldırımlar iner (inmeden önce zeminde mavi kıvılcım titrer),
## gri hortumlar dönerek gezer, yer yarılıp kayalar kalkar.

## Yıldırım: kırık çizgi şerit, ortası beyaz, kenarı açık mavi
const _BOLT := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float a = 1.0;
void fragment() {
	float d = abs(UV.x * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.6, 0.78, 1.0), vec3(1.0), 1.0 - smoothstep(0.0, 0.35, d));
	ALPHA = (1.0 - smoothstep(0.5, 1.0, d)) * a;
}
"""

## Hortum hunisi: dönen gri-beyaz şeritler, tepe geniş, dip dar
const _FUNNEL := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float a = 0.8;
void fragment() {
	float s = 0.5 + 0.5 * sin(UV.x * 6.28318 * 5.0 + UV.y * 14.0 - TIME * 14.0);
	float band = smoothstep(0.35, 0.75, s);
	ALBEDO = mix(vec3(0.6, 0.63, 0.7), vec3(0.93, 0.95, 1.0), band);
	ALPHA = (0.35 + band * 0.55) * a * smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.9, 1.0, UV.y));
}
"""

## Deprem yarığı: geniş, koyu, dallanan kırık
const _QUAKE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 9.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 2.71 + seed) * 371.9);
	float ca = (sec + 0.5 + (off - 0.5) * 0.7) / n * 6.28318 - 3.14159;
	float d = abs(sin(a - ca - 0.15 * sin(r * 7.0 + off * 4.0))) * r;
	float line = (1.0 - smoothstep(0.02, 0.09 * (1.2 - r), d)) * (1.0 - smoothstep(mix(0.55, 1.0, off) * 0.85, mix(0.55, 1.0, off), r));
	ALBEDO = vec3(0.08, 0.06, 0.05);
	ALPHA = max(line, (1.0 - smoothstep(0.12, 0.26, r)) * 0.9) * (1.0 - smoothstep(0.8, 1.0, t));
}
"""

static var _c := {}


static func _rock() -> Mesh:
	if not _c.has("rock"):
		var m := PrismMesh.new()
		m.size = Vector3(1.0, 1.2, 0.8)
		m.left_to_right = 0.3
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.4, 0.35, 0.3)
		mt.roughness = 1.0
		m.material = mt
		_c["rock"] = m
	return _c["rock"]


static func _spark() -> Mesh:
	if not _c.has("spark"):
		var m := BoxMesh.new()
		m.size = Vector3(0.08, 0.6, 0.08)
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.75, 0.88, 1.0)
		m.material = mt
		_c["spark"] = m
	return _c["spark"]


## Yere iniş öncesi: zeminde titreyen mavi kıvılcımlar
static func pre_strike(at: Vector3, s: float) -> void:
	BeastFX._parts(at, _spark(), 10, 0.45, 0.5, 2.0, Vector3.UP, 180.0, Vector3.ZERO, 0.5 * s, 1.0 * s, 1.6 * s, true)


## Yıldırım: gökten zikzak şerit (kameraya dönük her parça), kısa ışık + taş sıçraması
static func bolt(from: Vector3, to: Vector3, w: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var pts := []
	for i in n + 1:
		var u := float(i) / n
		var p := from.lerp(to, u)
		if i > 0 and i < n:
			p += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (from - to).length() * 0.05
		pts.append(p)
	var cam := BeastFX._tree().root.get_viewport().get_camera_3d()
	var vdir := (cam.global_position - to).normalized() if cam else Vector3.BACK
	for i in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var sd := (b - a).cross(vdir).normalized() * w
		for v in [[a - sd, 0.0], [a + sd, 1.0], [b + sd, 1.0], [a - sd, 0.0], [b + sd, 1.0], [b - sd, 0.0]]:
			st.set_uv(Vector2(v[1], 0))
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = BeastFX._shader("jubi_bolt", _BOLT)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not BeastFX._add(mi, Vector3.ZERO):
		return
	mi.global_position = Vector3.ZERO
	var tw := mi.create_tween()
	tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	BeastFX._light(to + Vector3.UP * 3.0, Color(0.7, 0.85, 1.0), 10.0, 25.0, 0.3)
	BeastFX._parts(to, _rock(), 5, 1.0, 6.0, 12.0, Vector3.UP, 40.0, Vector3(0, -26, 0), 0.25, 0.5, 0.6, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])


## Hortum (life sn boyunca kendi yerinde döner; çağıran konumu taşır)
static func tornado(tp: Vector3, r: float, h: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 0.25
	cm.height = 1.0
	cm.radial_segments = 20
	cm.rings = 6
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = BeastFX._shader("jubi_funnel", _FUNNEL)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not BeastFX._add(mi, tp + Vector3.UP * h * 0.5):
		return
	mi.scale = Vector3(r, h, r)
	var tw := mi.create_tween()
	tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.8, 0.0, life)
	tw.tween_callback(mi.queue_free)


## Deprem yarığı + kalkan kayalar
static func quake(qp: Vector3, s: float) -> void:
	GroundFX.add(qp, "cracked", 3.0 * s, 4.0)
	BeastFX._card("jubi_quake", _QUAKE, BeastFX._ground(qp), 6.0 * s, Vector3.UP, 4.0, {}, false)
	BeastFX._parts(qp, _rock(), 10, 1.2, 6.0, 14.0, Vector3.UP, 35.0, Vector3(0, -26, 0), 0.35 * s, 0.7 * s, 2.0 * s, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])


## Dev Bijūdama'nın düştüğü yer: geniş yarık + büyük kaya savruluşu
static func crater(g: Vector3, R: float) -> void:
	GroundFX.add(g, "cracked", R * 0.5, 5.0)
	BeastFX._card("jubi_quake", _QUAKE, BeastFX._ground(g), R * 1.8, Vector3.UP, 8.0, {}, false)
	BeastFX._parts(g + Vector3.UP, _rock(), 26, 1.6, 12.0, 22.0, Vector3.UP, 45.0, Vector3(0, -24, 0), 0.6, 1.4, R * 0.4, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])


## Raijū şimşek pençesi: kısa mavi kıvılcım çubukları
static func shock(pt: Vector3, s: float) -> void:
	BeastFX._parts(pt, _spark(), 14, 0.35, 4.0 * s, 9.0 * s, Vector3.UP, 180.0, Vector3.ZERO, 0.6 * s, 1.2 * s, 0.4 * s, true)
	BeastFX._light(pt, Color(0.6, 0.8, 1.0), 6.0, 8.0 * s, 0.25)
