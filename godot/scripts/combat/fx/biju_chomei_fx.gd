class_name BijuChomeiFX
extends RefCounted
## Chōmei (Yedi Kuyruk) tekniklerinin KENDİ görselleri: pul tozu (rinpun), kör eden ışık, böcek sürüsü, kanat rüzgârı.
## Kaynak (anime): kanatlardan sarı-yeşil ışıltılı pul tozu savrulur; Rinpun Hikōmei = toz bulutunun içinde kör eden
## beyaz-sarı ışık patlaması; böcekler küçük yeşil parlak kanatlı; kanat çırpınca toz ve yaprak gibi pullar savrulur.

const SCALE := Color(0.85, 1.0, 0.5)

## Kör eden ışık: on iki kollu beyaz-sarı yıldız + geniş hale (kameraya dönük)
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
	float rays = pow(abs(cos(a * 6.0)), 30.0) * (1.0 - r) * 1.5;
	float halo = (1.0 - smoothstep(0.0, 1.0, r)) * 0.6;
	float ctr = 1.0 - smoothstep(0.0, 0.3, r);
	ALBEDO = mix(vec3(1.0, 1.0, 0.7), vec3(1.0), ctr);
	ALPHA = clamp((rays + halo + ctr) * (1.0 - t), 0.0, 1.0);
}
"""

static var _c := {}


## Pul: ince yassı, ışıltılı sarı-yeşil
static func _flake() -> Mesh:
	if not _c.has("flake"):
		var m := QuadMesh.new()
		m.size = Vector2(0.5, 0.8)
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = SCALE
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		mt.emission_enabled = true
		mt.emission = Color(0.9, 1.0, 0.5)
		mt.emission_energy_multiplier = 1.5
		m.material = mt
		_c["flake"] = m
	return _c["flake"]


## Işıltı tanesi
static func _mote() -> Mesh:
	if not _c.has("mote"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 3
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(1.0, 1.0, 0.75)
		m.material = mt
		_c["mote"] = m
	return _c["mote"]


## Kanat çırpışı: aşağı / yukarı savrulan pullar ve ışıltı
static func wing_gust(pos: Vector3, s: float, dir := Vector3.DOWN) -> void:
	BeastFX._parts(pos, _flake(), 18, 0.9, 4.0, 8.0, dir, 60.0, Vector3(0, -1, 0), 0.25 * s, 0.5 * s, 1.0 * s, false, [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]], 1.5)
	BeastFX._parts(pos, _mote(), 24, 1.0, 2.0, 6.0, dir, 80.0, Vector3.ZERO, 0.06 * s, 0.14 * s, 1.0 * s, false, [[0.0, 1.0], [1.0, 0.0]], 1.0)


## İniş: yerde savrulan toz halkası + pullar
static func landing(to: Vector3, s: float) -> void:
	BeastFX._card("dring", BeastFX._DUST_RING, BeastFX._ground(to), 14.0 * s, Vector3.UP, 0.6, {"col": Color(0.85, 0.82, 0.62)})
	BeastFX._parts(to, _flake(), 26, 1.2, 6.0, 12.0, Vector3.UP, 80.0, Vector3(0, -4, 0), 0.4 * s, 0.8 * s, 3.0 * s, false, [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]], 1.0)


## Pul tozu püskürmesi: ağızdan koni hâlinde ışıltılı pullar
static func scale_spray(from: Vector3, dir: Vector3, s: float) -> void:
	BeastFX._parts(from, _mote(), 70, 0.9, 10.0 * sqrt(s), 22.0 * sqrt(s), dir, 28.0, Vector3.ZERO, 0.16 * s, 0.35 * s, 0.6 * s, false, [[0.0, 1.0], [1.0, 0.0]], 1.2)
	BeastFX._parts(from, _flake(), 30, 1.0, 8.0 * sqrt(s), 18.0 * sqrt(s), dir, 30.0, Vector3.ZERO, 0.5 * s, 1.0 * s, 0.6 * s, false, [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]], 1.2)


## Kör eden ışık patlaması
static func blind_flash(ctr: Vector3, s: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BeastFX._quad()
	var m := ShaderMaterial.new()
	m.shader = BeastFX._shader("chm_flash", _FLASH)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not BeastFX._add(mi, ctr):
		return
	mi.scale = Vector3.ONE * 3.0 * s
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 5.0 * s, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x: float): m.set_shader_parameter("t", x), 0.0, 1.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)
	BeastFX._light(ctr, Color(1, 1, 0.8), 14.0, 30.0 * s, 0.35)
	BeastFX._parts(ctr, _mote(), 40, 0.8, 6.0 * s, 14.0 * s, Vector3.UP, 180.0, Vector3.ZERO, 0.08 * s, 0.16 * s, 0.5 * s, false, [[0.0, 1.0], [1.0, 0.0]], 2.0)


## Böcek (güdümlü mermi görseli): yeşil parlak gövde + titreşen saydam kanatlar
class _Buzz extends Node3D:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		for k in get_child_count():
			var ch := get_child(k)
			if ch.name.begins_with("kanat"):
				ch.rotation.z = (0.6 if k % 2 == 0 else -0.6) * sin(t * 60.0)


static func bug(size: float) -> Node3D:
	var root := _Buzz.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	body.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.25, 0.6, 0.15)
	bm.emission_enabled = true
	bm.emission = Color(0.6, 1.0, 0.3)
	bm.emission_energy_multiplier = 1.2
	body.material_override = bm
	body.scale = Vector3(0.6, 0.5, 1.0) * size
	root.add_child(body)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.9, 1.0, 0.85, 0.5)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 0.45)
		w.mesh = q
		w.material_override = wm
		w.name = "kanat%d" % int(sx + 1)
		w.position = Vector3(sx * 0.5, 0.25, 0) * size
		w.rotation = Vector3(-PI * 0.5, 0, 0)
		w.scale = Vector3.ONE * size
		root.add_child(w)
	return root


## Böcek ısırığı: küçük yeşil pul saçılması
static func bite(pos: Vector3) -> void:
	BeastFX._parts(pos, _flake(), 8, 0.5, 2.0, 5.0, Vector3.UP, 180.0, Vector3(0, -4, 0), 0.15, 0.3, 0.2)
