class_name BijuMatatabiFX
extends RefCounted
## Matatabi (İki Kuyruk) tekniklerinin KENDİ görselleri: mavi kedi alevi. Ortak ateş / patlama / kalıcı alev yok.
## Kaynak (anime / Storm 4): alev dumansız, hayalet gibi; içi beyaza yakın açık camgöbeği, dışı koyu kobalt, uçları ince kıvrık diller;
## ateş topu = beyaz çekirdekli, yüzeyi kaynayan mavi küre; yanan zemin = yerden yükselen titrek mavi diller, altında koyu mavi yanık izi;
## pençe = üç mavi alev yarığı.

const BLUE := Color(0.3, 0.5, 1.0)

## Mavi alev: UV.y boyunca akan gürültü; çekirdek beyaz-camgöbeği, kenar kobalt, uçta erir (koni / küre / kutu üstünde)
const _FLAME := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float speed = 2.2;
uniform float a = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 q = vec2(UV.x * 6.0, UV.y * 3.0 + TIME * speed);
	float n = n2(q) * 0.6 + n2(q * 2.3 + 4.0) * 0.4;
	float edge = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float core = clamp(1.0 - edge * 1.4, 0.0, 1.0);
	float body = smoothstep(0.3, 0.75, n * 0.8 + core * 0.55);
	vec3 c = mix(vec3(0.04, 0.1, 0.55), vec3(0.2, 0.45, 1.0), body);
	c = mix(c, vec3(0.62, 0.86, 1.0), smoothstep(0.85, 1.0, core * (0.6 + n * 0.5)));
	ALBEDO = c;
	float soft = (1.0 - edge * edge) * smoothstep(0.0, 0.35, 1.0 - abs(UV.y * 2.0 - 1.0) * 0.8);
	ALPHA = clamp(body * soft * a * 1.1, 0.0, 0.92);
}
"""

## Alev dili kartı (kameraya dönük, dik): anime cel alev — dalgalı kenarlı damla, üç ton bant (dış kobalt, orta mavi, iç açık camgöbeği)
const _TONGUE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
varying float seed;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 rgt = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fw = normalize(cross(rgt, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(rgt * sc.x, 0.0), vec4(vec3(0.0, 1.0, 0.0) * sc.y, 0.0), vec4(fw * sc.z, 0.0), MODEL_MATRIX[3]);
	seed = fract(MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.71);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float t = TIME * 3.0 + seed * 20.0;
	float sway = (n2(vec2(p.y * 2.5 - t, seed * 9.0)) - 0.5) * 0.9 * p.y * p.y;
	float w = 0.9 * sqrt(clamp(p.y * 5.0, 0.0, 1.0)) * pow(1.0 - p.y, 0.75) * (0.75 + 0.5 * n2(vec2(p.y * 5.0 - t * 1.3, seed * 5.0)));
	float d = abs(p.x - sway) / max(w, 0.001);
	float shape = 1.0 - d;
	if (shape < 0.0 || p.y > 0.98) discard;
	vec3 c = vec3(0.08, 0.2, 0.82);
	c = mix(c, vec3(0.28, 0.58, 1.0), step(0.35, shape));
	c = mix(c, vec3(0.78, 0.94, 1.0), step(0.7, shape) * step(p.y, 0.6));
	ALBEDO = c;
	ALPHA = 0.95;
}
"""

## Yanık izi: zeminde koyu lacivert, kenarı tırtıklı, ortası hafif mavi kor
const _SCORCH := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float edge = 0.75 + 0.12 * sin(a * 7.0 + seed) + 0.07 * sin(a * 17.0 - seed);
	float m = 1.0 - smoothstep(edge - 0.15, edge, r);
	float glow = (1.0 - smoothstep(0.0, 0.5, r)) * (1.0 - smoothstep(0.0, 0.6, t));
	ALBEDO = mix(vec3(0.03, 0.05, 0.15), vec3(0.3, 0.55, 1.0), glow);
	ALPHA = m * 0.6 * (1.0 - smoothstep(0.75, 1.0, t));
}
"""

static var _c := {}


static func mat(speed := 2.2, alpha := 1.0) -> ShaderMaterial:
	var k := "m%.1f_%.2f" % [speed, alpha]
	if not _c.has(k):
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("mtb_flame", _FLAME)
		m.set_shader_parameter("speed", speed)
		m.set_shader_parameter("a", alpha)
		_c[k] = m
	return _c[k]


static func _tongue() -> Mesh:
	if not _c.has("tongue"):
		var m := QuadMesh.new()
		m.size = Vector2(1.5, 2.0)
		m.center_offset = Vector3(0, 0.8, 0)
		var sm := ShaderMaterial.new()
		sm.shader = BeastFX._shader("mtb_tongue", _TONGUE)
		m.material = sm
		_c["tongue"] = m
	return _c["tongue"]


static func _ball_mesh() -> Mesh:
	if not _c.has("ball"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 16
		m.rings = 8
		_c["ball"] = m
	return _c["ball"]


static func scorch(pos: Vector3, size: float, dur := 5.0) -> void:
	GroundFX.add(pos, "burning", size * 0.5, clampf(dur, 3.0, 6.0))
	BeastFX._card("mtb_scorch", _SCORCH, BeastFX._ground(pos), size, Vector3.UP, dur, {}, false)


## Pençe yarığı: üç mavi alev şeridi uzar, söner + yerde yanık izi
static func claw_marks(pos: Vector3, dir: Vector3, s: float) -> void:
	var side := dir.cross(Vector3.UP).normalized()
	for k in 3:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 1.0)
		var m := MeshInstance3D.new()
		m.mesh = bm
		m.material_override = mat(5.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := pos + side * (k - 1) * 0.9 * s
		if not BeastFX._add(m, p):
			return
		m.global_transform = Transform3D(Basis.looking_at((dir + Vector3.DOWN * 0.6 + side * 0.25).normalized(), Vector3.UP), p)
		m.scale = Vector3(1.0 * s, 1.0 * s, 0.1)
		var tw := m.create_tween()
		tw.tween_property(m, "scale", Vector3(1.6 * s, 0.7 * s, 7.0 * s), 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "scale", Vector3(0.05, 0.05, 8.0 * s), 0.25)
		tw.tween_callback(m.queue_free)
	scorch(pos - Vector3.UP * pos.y + Vector3.UP * Game.ground_height(pos.x, pos.z), 3.5 * s)


## Sıçrayış izi: arkada titrek küçük mavi diller
static func wisp(p: Vector3, s: float) -> void:
	BeastFX._parts(p, _tongue(), 4, 0.45, 0.5, 2.0, Vector3.UP, 30.0, Vector3(0, 3, 0), 0.4 * s, 0.7 * s, 0.4 * s, false)


## İniş: yerde mavi alev halkası (dışa yatık diller)
static func land_ring(p: Vector3, s: float) -> void:
	BeastFX._parts(BeastFX._ground(p), _tongue(), 18, 0.55, 5.0 * s, 9.0 * s, Vector3.UP, 75.0, Vector3(0, 2, 0), 0.5 * s, 0.9 * s, 1.0 * s, false)


## Yanan zemin öbeği (dur sn): yerden titrek mavi diller, altında yanık izi
class _Burn extends Node3D:
	var s := 1.0
	var life := 6.0
	var acc := 0.0
	func _process(d: float) -> void:
		life -= d
		if life <= 0.0:
			queue_free()
			return
		acc += d
		if acc < 0.18:
			return
		acc = 0.0
		BeastFX._parts(global_position, BijuMatatabiFX._tongue(), 3, 0.7, 0.5, 1.6, Vector3.UP, 20.0, Vector3(0, 2.5, 0), 0.45 * s, 0.9 * s, 1.0 * s, false, [[0.0, 0.2], [0.3, 1.0], [1.0, 0.0]])


static func burn_patch(gp: Vector3, s: float, dur: float) -> void:
	var b := _Burn.new()
	b.s = s
	b.life = dur
	if BeastFX._add(b, gp):
		scorch(gp, 2.6 * s, dur)


## Mavi ateş topu (çap d): beyaz çekirdek + kaynayan mavi kabuk + arkaya savrulan diller
class _Spin extends Node3D:
	func _process(d: float) -> void:
		rotate_y(4.0 * d)
		rotate_x(2.3 * d)


static func fireball(d: float) -> Node3D:
	var root := _Spin.new()
	var core := MeshInstance3D.new()
	core.mesh = _ball_mesh()
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(0.85, 0.97, 1.0)
	core.material_override = cm
	core.scale = Vector3.ONE * d * 0.5
	root.add_child(core)
	for k in 2:
		var sh := MeshInstance3D.new()
		sh.mesh = _ball_mesh()
		sh.material_override = mat(3.0 + k * 1.5, 0.9 - k * 0.3)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.scale = Vector3.ONE * d * (0.85 + k * 0.35)
		root.add_child(sh)
	return root


## Ateş topu çarpması: dört yana fışkıran mavi diller + kısa ışık
static func pop(pos: Vector3, s: float) -> void:
	BeastFX._parts(pos, _tongue(), 16, 0.5, 4.0 * s, 9.0 * s, Vector3.UP, 85.0, Vector3(0, 3, 0), 0.5 * s, 1.0 * s, 0.6 * s, false)
	BeastFX._light(pos, BLUE, 5.0, 8.0 * s, 0.4)


## Alev nefesi: akış konisi malzemesi + akışta ileri savrulan diller
static func breath_mat() -> ShaderMaterial:
	return mat(6.0, 0.95)


static func breath_tongues(from: Vector3, dir: Vector3, s: float) -> void:
	BeastFX._parts(from, _tongue(), 5, 0.45, 18.0 * sqrt(s), 28.0 * sqrt(s), dir, 12.0, Vector3(0, 3, 0), 0.7 * s, 1.3 * s, 0.6 * s, false)


## Rinkaku halka sütunu: yerden fışkıran mavi alev sütunu
static func pillar(p: Vector3, s: float) -> void:
	BeastFX._parts(BeastFX._ground(p), _tongue(), 10, 0.9, 6.0 * s, 12.0 * s, Vector3.UP, 12.0, Vector3(0, 4, 0), 0.8 * s, 1.5 * s, 0.6 * s, false)


## Rinkaku merkez patlaması: büyük mavi dil fışkırması + yanık izi + ışık
static func blast(ctr: Vector3, s: float, R: float) -> void:
	BeastFX._parts(BeastFX._ground(ctr), _tongue(), 40, 0.9, 8.0 * s, 16.0 * s, Vector3.UP, 60.0, Vector3(0, 3, 0), 1.0 * s, 2.0 * s, R * 0.3, false)
	scorch(ctr, R * 1.6, 6.0)
	BeastFX._light(ctr + Vector3.UP * 2.0 * s, BLUE, 10.0, R * 2.0, 0.8)
