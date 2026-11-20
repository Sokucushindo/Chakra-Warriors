class_name BijuKokuoFX
extends RefCounted
## Kokuō (Beş Kuyruk) tekniklerinin KENDİ görselleri: kaynar buhar (Futton). Ortak duman / halka / parlama yok.
## Kaynak (anime): buhar = bembeyaz, yuvarlak hatlı kabaran kütleler, hızla yükselip yayılır; altı hafif gri gölgeli;
## patlamada bedenden yere yayılan beyaz buhar halkası; boynuz vuruşunda akkor beyaz parlama.

const STEAM := Color(0.97, 0.95, 0.92)

## Buhar kütlesi: beyaz, altı gri gölgeli, kenarı yumuşak (cel: iki ton)
const _PUFF := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float a = 0.0;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	ALBEDO = mix(vec3(0.72, 0.7, 0.74), vec3(1.0, 0.99, 0.97), step(-0.15, wn.y));
	ALPHA = smoothstep(0.0, 0.85, f) * a;
}
"""

## Yerde yuvarlanan buhar halkası: kabarık dış kenar
const _RING := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rad = mix(0.2, 0.9, t) + 0.05 * abs(sin(a * 9.0 + seed));
	float band = smoothstep(rad - 0.25, rad - 0.05, r) * (1.0 - smoothstep(rad - 0.02, rad + 0.04, r));
	ALBEDO = mix(vec3(0.8, 0.78, 0.8), vec3(1.0), smoothstep(rad - 0.2, rad - 0.05, r));
	ALPHA = band * (1.0 - smoothstep(0.5, 1.0, t)) * 0.9;
}
"""

## Akkor parlama: altı kollu beyaz yıldız (kameraya dönük)
const _FLASH := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = pow(abs(cos(a * 3.0)), 24.0) * (1.0 - r);
	float ctr = 1.0 - smoothstep(0.0, 0.35, r);
	ALBEDO = vec3(1.0, 0.98, 0.94);
	ALPHA = clamp((rays * 1.4 + ctr) * (1.0 - t), 0.0, 1.0);
}
"""

static var _c := {}


static func _sphere() -> SphereMesh:
	if not _c.has("sph"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 14
		m.rings = 7
		_c["sph"] = m
	return _c["sph"]


## Kaynar buhar bulutu: kabarıp yükselen beyaz kütleler (life sn)
static func cloud(pos: Vector3, s: float, R: float, life: float) -> void:
	var n := clampi(int(R / maxf(0.5, s)) + 3, 5, 9)
	for k in n:
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere()
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("kko_puff", _PUFF)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * R * randf_range(0.0, 0.7)
		if not BeastFX._add(mi, pos + off):
			return
		var sz := 1.5 * s * randf_range(0.7, 1.3)
		mi.scale = Vector3.ONE * sz * 0.3
		var rise := Vector3.UP * randf_range(1.5, 3.5) * s + off.normalized() * R * 0.2
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * sz * 1.4, life).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "global_position", mi.global_position + rise, life).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(x: float): m.set_shader_parameter("a", x), 0.0, 0.7, life * 0.15)
		tw.chain().tween_method(func(x: float): m.set_shader_parameter("a", x), 0.7, 0.0, life * 0.5)
		tw.chain().tween_callback(mi.queue_free)


static func ring(pos: Vector3, size: float, dur := 0.5) -> void:
	BeastFX._card("kko_ring", _RING, BeastFX._ground(pos), size, Vector3.UP, dur)


static func flash(pos: Vector3, size: float, dur := 0.2) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BeastFX._quad()
	var m := ShaderMaterial.new()
	m.shader = BeastFX._shader("kko_flash", _FLASH)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not BeastFX._add(mi, pos):
		return
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 0.55, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)
