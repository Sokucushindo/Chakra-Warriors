class_name BijuKuramaFX
extends RefCounted
## Kurama (Dokuz Kuyruk) tekniklerinin KENDİ görselleri: turuncu-kızıl canavar chakrası. Ortak halka / yıldız / çatlak / moloz yok.
## Kaynak (anime): chakra kolu = kaynayan turuncu chakra, yakaladığı yerde kızıl parlama; yere ezince kızıl ışıyan yarıklar,
## kalkan toprak; kükreme = ağızdan art arda basınç halkaları, ekranda hız çizgisi yerine sarsıntı; Bijūdama Rasengan = koyu
## topun çevresinde chakra renginde dönen düz girdap diski; pençe = üç turuncu chakra yarığı.

## Chakra yarığı: kızıl-turuncu ışıyan kırıklar
const _CRACK := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
uniform vec4 col : source_color = vec4(1.0, 0.45, 0.1, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 7.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 4.37 + seed) * 613.1);
	float ca = (sec + 0.5 + (off - 0.5) * 0.6) / n * 6.28318 - 3.14159;
	float d = abs(sin(a - ca - 0.1 * sin(r * 12.0 + off * 5.0))) * r;
	float len = mix(0.6, 1.0, off);
	float core = (1.0 - smoothstep(0.012, 0.035, d)) * (1.0 - smoothstep(len * 0.85, len, r));
	float edge = (1.0 - smoothstep(0.035, 0.09, d)) * (1.0 - smoothstep(len * 0.8, len, r));
	ALBEDO = mix(vec3(0.12, 0.04, 0.02), col.rgb * 1.2, core * (1.0 - smoothstep(0.3, 0.8, t)));
	ALPHA = max(max(core, edge * 0.85), (1.0 - smoothstep(0.1, 0.2, r)) * 0.8) * (1.0 - smoothstep(0.75, 1.0, t));
}
"""

## Basınç halkası: kalın chakra halkası, iç kenarı beyaz
const _WAVE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(1.0, 0.45, 0.1, 1.0);
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float rad = mix(0.2, 0.92, t);
	float w = mix(0.14, 0.05, t);
	float band = smoothstep(rad - w, rad, r) * (1.0 - smoothstep(rad, rad + 0.03, r));
	ALBEDO = mix(col.rgb, vec3(1.0), smoothstep(rad - w * 0.4, rad, r) * 0.6);
	ALPHA = band * (1.0 - smoothstep(0.55, 1.0, t)) * 1.2;
}
"""

## Kızıl parlama: dört kollu, kameraya dönük
const _FLASH := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform vec4 col : source_color = vec4(1.0, 0.45, 0.1, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = pow(abs(cos(a * 2.0 + 0.785)), 20.0) * (1.0 - r) * 1.4;
	float ctr = 1.0 - smoothstep(0.0, 0.4, r);
	ALBEDO = mix(col.rgb, vec3(1.0), ctr);
	ALPHA = clamp((rays + ctr) * (1.0 - t), 0.0, 1.0);
}
"""

## Rasengan diski: chakra renginde dönen sarmal kollar
const _SPIRAL := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 col : source_color = vec4(1.0, 0.45, 0.1, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arms = pow(0.5 + 0.5 * sin(a * 4.0 + r * 9.0 - TIME * 18.0), 3.0);
	float ring = smoothstep(0.3, 0.45, r) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = mix(col.rgb, vec3(1.0), arms * 0.5);
	ALPHA = ring * (0.25 + arms * 0.75);
}
"""

static var _c := {}


static func _flash(pos: Vector3, col: Color, size: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BeastFX._quad()
	var m := ShaderMaterial.new()
	m.shader = BeastFX._shader("krm_flash", _FLASH)
	m.set_shader_parameter("col", col)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not BeastFX._add(mi, pos):
		return
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 0.5, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)


static func _clod() -> Mesh:
	if not _c.has("clod"):
		var m := PrismMesh.new()
		m.size = Vector3(1.0, 0.9, 0.8)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.36, 0.3, 0.25)
		mt.roughness = 1.0
		m.material = mt
		_c["clod"] = m
	return _c["clod"]


static func _streak(col: Color) -> ShaderMaterial:
	var k := "st%s" % col.to_html()
	if not _c.has(k):
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("krm_flash", _FLASH)
		m.set_shader_parameter("col", col)
		_c[k] = m
	return _c[k]


## Chakra eli yakalaması: kızıl parlama
static func grab_flash(tip: Vector3, col: Color, s: float) -> void:
	_flash(tip, col.lightened(0.3), 2.5 * s, 0.18)


## Yere ezme: kızıl ışıyan yarıklar + chakra halkası + toprak topakları
static func slam(p: Vector3, col: Color, s: float, R := 9.0) -> void:
	var g := BeastFX._ground(p)
	GroundFX.add(p, "cracked", R * 0.25 * s, 4.0)
	BeastFX._card("krm_crack", _CRACK, g, R * 0.5 * s, Vector3.UP, 4.0, {"col": col}, false)
	BeastFX._card("krm_wave", _WAVE, g + Vector3.UP * 0.1, R * s, Vector3.UP, 0.4, {"col": col})
	BeastFX._parts(g, _clod(), 10, 1.1, 5.0 * s, 12.0 * s, Vector3.UP, 40.0, Vector3(0, -26, 0), 0.3 * s, 0.6 * s, 1.0 * s, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])


## Kükreme basınç halkası (yön boyunca)
static func roar_wave(p: Vector3, col: Color, size: float, dir: Vector3) -> void:
	BeastFX._card("krm_wave", _WAVE, p, size, dir, 0.6, {"col": col})


## Bijūdama Rasengan halkası (topa bağlanır)
static func rasen_ring(d: float, col: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BeastFX._quad()
	var m := ShaderMaterial.new()
	m.shader = BeastFX._shader("krm_spiral", _SPIRAL)
	m.set_shader_parameter("col", col)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	mi.scale = Vector3.ONE * d * 0.5
	return mi


## Pençe yarığı: üç chakra yarığı (turuncu-kızıl ya da canavarın chakra rengi) + yerde ışıyan yarık
static func claw_marks(pos: Vector3, dir: Vector3, s: float, col := Color(1.0, 0.45, 0.1)) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	for k in 3:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 1.0)
		var m := MeshInstance3D.new()
		m.mesh = bm
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = col.lightened(0.35)
		m.material_override = mt
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := pos + side * (k - 1) * 0.9 * s
		if not BeastFX._add(m, p):
			return
		m.global_transform = Transform3D(Basis.looking_at((dir + Vector3.DOWN * 0.6 + side * 0.25).normalized(), Vector3.UP), p)
		m.scale = Vector3(1.0 * s, 1.0 * s, 0.1)
		var tw := m.create_tween()
		tw.tween_property(m, "scale", Vector3(1.4 * s, 0.6 * s, 7.0 * s), 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "scale", Vector3(0.05, 0.05, 8.0 * s), 0.25)
		tw.tween_callback(m.queue_free)
	var g := Vector3(pos.x, Game.ground_height(pos.x, pos.z), pos.z)
	BeastFX._card("krm_crack", _CRACK, BeastFX._ground(g), 3.5 * s, Vector3.UP, 4.0, {"col": col}, false)


## Dokuz kuyruk dövmesi: her vuruşta ışıyan yarık + halka + toprak
static func tail_slam(p: Vector3, col: Color, s: float) -> void:
	slam(p, col, s, 9.0)
