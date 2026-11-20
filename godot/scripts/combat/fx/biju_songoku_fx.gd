class_name BijuSonGokuFX
extends RefCounted
## Son Gokū (Dört Kuyruk) tekniklerinin KENDİ görselleri: lav (Yōton). Ateş topu / ortak sıçrama / ortak akış yok.
## Kaynak (anime): lav = yapışkan, ağır sarı-turuncu akış, üstünde koyu soğumuş kabuk; kayalar pürüzlü, çatlaklarından kor ışır;
## yer çatlar, çatlak turuncu ışır, ardından lav sütunu fışkırır ve ağır damlalarla geri düşer.

const LAVA := Color(1.0, 0.45, 0.08)

## Kor yarığı: ışınsal sarı-turuncu ışıyan çatlaklar, kenarı koyu yanık
const _FISSURE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = 6.0;
	float sec = floor((a + 3.14159) / 6.28318 * n);
	float off = fract(sin(sec * 5.13 + seed) * 731.7);
	float ca = (sec + 0.5 + (off - 0.5) * 0.6) / n * 6.28318 - 3.14159;
	float d = abs(sin(a - ca - 0.12 * sin(r * 8.0 + off * 6.0))) * r;
	float len = mix(0.6, 1.0, off);
	float core = (1.0 - smoothstep(0.01, 0.035, d)) * (1.0 - smoothstep(len * 0.85, len, r));
	float burn = (1.0 - smoothstep(0.03, 0.1, d)) * (1.0 - smoothstep(len * 0.8, len, r));
	float hole = 1.0 - smoothstep(0.1, 0.22, r);
	vec3 hot = mix(vec3(1.0, 0.35, 0.02), vec3(1.0, 0.9, 0.35), core);
	ALBEDO = mix(vec3(0.08, 0.03, 0.02), hot, max(core, hole));
	ALPHA = max(max(core, burn * 0.8), hole) * (1.0 - smoothstep(0.8, 1.0, t));
}
"""

## Sıcaklık halkası: yerde kor turuncu halka (zırh tutuşurken)
const _HEAT := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float rad = mix(0.2, 0.9, t);
	float band = 1.0 - smoothstep(0.0, 0.08, abs(r - rad));
	ALBEDO = vec3(1.0, 0.5, 0.1);
	ALPHA = band * (1.0 - t);
}
"""

static var _c := {}


static func lava_mat(cool := 0.0) -> ShaderMaterial:
	var k := "lm%.2f" % cool
	if not _c.has(k):
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("lava", BeastFX._LAVA)
		m.set_shader_parameter("cool", cool)
		_c[k] = m
	return _c[k]


static func _blob() -> Mesh:
	if not _c.has("blob"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.8
		m.radial_segments = 8
		m.rings = 5
		m.material = lava_mat(0.0)
		_c["blob"] = m
	return _c["blob"]


static func _rock() -> Mesh:
	if not _c.has("rock"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 3
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.16, 0.09, 0.06)
		mt.roughness = 1.0
		m.material = mt
		_c["rock"] = m
	return _c["rock"]


## Pürüzlü lav kayası mermisi (çap d): köşeli kabuk, çatlaklarından kor + damlayan lav
static func lava_rock(d: float) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 7
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = lava_mat(0.55)
	mi.scale = Vector3(1.1, 0.85, 1.0) * d
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	root.add_child(mi)
	var dr := BeastFX._Drip.new()
	dr.r = d * 0.6
	root.add_child(dr)
	return root


## Lav çarpması: yapışkan lav topakları + koyu kaya parçaları + kısa kor ışığı
static func splash(pos: Vector3, s: float) -> void:
	BeastFX._parts(pos, _blob(), 14, 1.0, 3.0 * s, 7.0 * s, Vector3.UP, 65.0, Vector3(0, -26, 0), 0.25 * s, 0.55 * s, 0.4 * s, false, [[0.0, 1.0], [0.8, 0.9], [1.0, 0.0]])
	BeastFX._parts(pos, _rock(), 8, 1.1, 3.0 * s, 8.0 * s, Vector3.UP, 60.0, Vector3(0, -28, 0), 0.2 * s, 0.45 * s, 0.4 * s, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	BeastFX._light(pos, LAVA, 6.0, 7.0 * s, 0.6)


## Kor yarığı (dur sn)
static func fissure(p: Vector3, size: float, dur: float) -> void:
	GroundFX.add(p, "burning", size * 0.5, clampf(dur, 3.0, 5.0))
	BeastFX._card("sgk_fissure", _FISSURE, BeastFX._ground(p), size, Vector3.UP, dur, {}, false)


## Lav sütunu: yerden ağır lav fışkırır (kalın sütun yükselir, tepesi taşar, çöker), kaya ve lav damlaları
static func geyser(p: Vector3, h: float, w: float) -> void:
	h *= 0.65
	w *= 1.7
	var g := BeastFX._ground(p) - Vector3.UP * 0.4
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.62
	cm.bottom_radius = 0.45
	cm.height = 1.0
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = lava_mat(0.0)
	if not BeastFX._add(mi, g):
		return
	mi.scale = Vector3(w, 0.05, w)
	var tw := mi.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(mi):
			mi.scale = Vector3(w * (1.0 + 0.15 * sin(x * 20.0)), h * x, w)
			mi.global_position = g + Vector3.UP * h * x * 0.5, 0.05, 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_method(func(x: float):
		if is_instance_valid(mi):
			mi.scale = Vector3(w * (1.0 - x * 0.6), h * (1.0 - x), w * (1.0 - x * 0.6))
			mi.global_position = g + Vector3.UP * h * (1.0 - x) * 0.5, 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	BeastFX._parts(g + Vector3.UP * h * 0.9, _blob(), 12, 1.3, w * 2.0, w * 4.0, Vector3.UP, 50.0, Vector3(0, -24, 0), w * 0.3, w * 0.6, w * 0.5, false, [[0.0, 1.0], [0.8, 0.9], [1.0, 0.0]])
	BeastFX._parts(g + Vector3.UP, _rock(), 10, 1.2, w * 5.0, w * 9.0, Vector3.UP, 30.0, Vector3(0, -28, 0), w * 0.2, w * 0.4, w * 0.5, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])
	BeastFX._light(g + Vector3.UP * h * 0.5, LAVA, 8.0, h * 1.2, 1.0)


## Ağızdan göğe lav fışkırması
static func spew(from: Vector3, s: float, n: int) -> void:
	BeastFX._parts(from, _blob(), n, 1.6, 12.0 * s, 22.0 * s, Vector3.UP, 25.0, Vector3(0, -22, 0), 0.4 * s, 0.8 * s, 0.6 * s, false, [[0.0, 1.0], [0.85, 1.0], [1.0, 0.0]])


## Zırhtan damlayan lav (tek damla)
static func drip(pos: Vector3, s: float) -> void:
	BeastFX._parts(pos, _blob(), 2, 0.8, 0.2, 1.0, Vector3.DOWN, 40.0, Vector3(0, -14, 0), 0.15 * s, 0.3 * s, 0.6 * s, false, [[0.0, 1.0], [0.8, 0.8], [1.0, 0.0]])


## Zırh tutuşması: yerde kor halka
static func heat_ring(pos: Vector3, size: float) -> void:
	BeastFX._card("sgk_heat", _HEAT, BeastFX._ground(pos), size, Vector3.UP, 0.45)
