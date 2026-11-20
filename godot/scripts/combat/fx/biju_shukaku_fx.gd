class_name BijuShukakuFX
extends RefCounted
## Shukaku (Bir Kuyruk) tekniklerinin KENDİ görselleri: kum ve sıkıştırılmış hava. Ortak efekt yok.
## Kaynak (anime / Storm): Renkūdan = ağızdan şişirilmiş karından çıkan saydam, içinde beyaz girdap çizgileri dönen hava küresi;
## yolunda basınç halkaları, çarpınca saydam küre şişip patlar, kum yere çarşaf gibi savrulur. Kum tsunamisi = sarı kum dalgası,
## üstünden kum taneleri saçılır. Kum kubbesi = içinde dönen kum taneleri.

const SAND := Color(0.86, 0.72, 0.48)
const SAND_D := Color(0.7, 0.56, 0.34)

## Hava küresi: saydam, kenarı beyaz, yüzeyinde dönen beyaz girdap çizgileri
const _AIR := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform float a = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ang = atan(lp.z, lp.x);
	float sw = pow(abs(sin(ang * 3.0 + lp.y * 8.0 - TIME * 14.0)), 12.0);
	ALBEDO = vec3(1.0, 0.98, 0.92);
	ALPHA = clamp((pow(f, 2.5) * 0.9 + sw * 0.45 * (0.3 + f)) * a, 0.0, 1.0);
}
"""

## Basınç halkası: ince beyaz halka, kenarları yumuşak
const _PRESS := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float t = 0.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float rad = mix(0.3, 0.95, t);
	float band = 1.0 - smoothstep(0.0, 0.07, abs(r - rad));
	ALBEDO = vec3(1.0, 0.97, 0.9);
	ALPHA = band * (1.0 - t) * 0.8;
}
"""

## Yerde savrulan kum çarşafı: dışa kayan tırtıklı kum halkası (içi açık kum rengi)
const _SAND_SHEET := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float t = 0.0;
uniform float seed = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rad = mix(0.15, 0.95, t) + 0.06 * sin(a * 13.0 + seed) + 0.04 * sin(a * 31.0);
	float band = smoothstep(rad - 0.45, rad, r) * (1.0 - smoothstep(rad, rad + 0.03, r));
	ALBEDO = mix(vec3(0.7, 0.56, 0.34), vec3(0.95, 0.86, 0.64), smoothstep(rad - 0.3, rad, r));
	ROUGHNESS = 1.0;
	ALPHA = band * (1.0 - smoothstep(0.5, 1.0, t)) * 0.95;
}
"""

static var _c := {}


static func _grain(col := SAND) -> Mesh:
	var k := "g%s" % col.to_html()
	if not _c.has(k):
		var m := BoxMesh.new()
		m.size = Vector3(0.7, 0.5, 0.6)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 1.0
		m.material = mt
		_c[k] = m
	return _c[k]


static func _clump(col := SAND) -> Mesh:
	var k := "c%s" % col.to_html()
	if not _c.has(k):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.55
		m.radial_segments = 7
		m.rings = 4
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 1.0
		m.material = mt
		_c[k] = m
	return _c[k]


## Renkūdan mermisi görseli (çap d)
static func air_bullet(d: float) -> Node3D:
	var root := Node3D.new()
	for k in 2:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		mi.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = BeastFX._shader("shk_air", _AIR)
		m.set_shader_parameter("a", 1.0 - k * 0.45)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * d * (1.0 - k * 0.35)
		root.add_child(mi)
	return root


## Atış: ağızdan namlu yönüne savrulan kum taneleri + önde basınç halkası
static func air_launch(from: Vector3, dir: Vector3, s: float) -> void:
	BeastFX._card("shk_press", _PRESS, from + dir * s, 3.5 * s, dir, 0.3)
	BeastFX._parts(from, _grain(), 22, 0.6, 6.0, 14.0, dir, 30.0, Vector3(0, -6, 0), 0.08 * s, 0.18 * s, 0.5 * s)


## Mermi yolu: arkasında basınç halkası
static func air_wake(pos: Vector3, dir: Vector3, s: float) -> void:
	BeastFX._card("shk_press", _PRESS, pos, 2.4 * s, dir, 0.25)


## Çarpma: saydam hava küresi şişip söner, yerde kum çarşafı dışa savrulur, kum taneleri ve topakları fırlar
static func air_boom(pos: Vector3, s: float) -> void:
	var b := air_bullet(1.0)
	if not BeastFX._add(b, pos):
		return
	b.scale = Vector3.ONE * 2.0 * s
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE * 11.0 * s, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(b.queue_free)
	var g := BeastFX._ground(pos)
	BeastFX._card("shk_sheet", _SAND_SHEET, g, 14.0 * s, Vector3.UP, 0.9)
	BeastFX._parts(g + Vector3.UP * s, _clump(), 20, 1.2, 6.0, 13.0, Vector3.UP, 80.0, Vector3(0, -10, 0), 0.22 * s, 0.45 * s, 2.0 * s, false, [[0.0, 0.4], [0.2, 1.0], [1.0, 0.0]], 1.5)
	BeastFX._parts(g + Vector3.UP * s, _grain(SAND_D), 30, 1.0, 8.0, 18.0, Vector3.UP, 85.0, Vector3(0, -22, 0), 0.12 * s, 0.25 * s, 1.5 * s)


## Kum dalgası üstünden saçılan kum
static func wave_spray(p: Vector3, W: float, s: float, dir: Vector3) -> void:
	BeastFX._parts(p, _grain(), 14, 0.9, 4.0, 9.0, (Vector3.UP + dir * 0.4).normalized(), 35.0, Vector3(0, -16, 0), 0.12 * s, 0.25 * s, W * 0.5)
	BeastFX._parts(p, _clump(), 6, 0.9, 3.0, 7.0, (Vector3.UP + dir * 0.4).normalized(), 30.0, Vector3(0, -14, 0), 0.25 * s, 0.45 * s, W * 0.4, false, [[0.0, 0.5], [0.2, 1.0], [1.0, 0.0]])


## Kum dökülmesi (tabut çözülür, mermi kuma yutulur, sıkışan kum ezer)
static func sand_fall(pos: Vector3, s: float, n := 12) -> void:
	BeastFX._parts(pos, _grain(), n, 0.8, 2.0, 5.0, Vector3.UP, 120.0, Vector3(0, -12, 0), 0.08 * s, 0.18 * s, 0.6 * s)
	BeastFX._parts(pos, _clump(), maxi(3, n / 3), 0.8, 1.0, 3.0, Vector3.UP, 120.0, Vector3(0, -10, 0), 0.18 * s, 0.35 * s, 0.6 * s, false, [[0.0, 1.0], [1.0, 0.0]])


## Kum kubbesinin içinde dönen kum taneleri (kubbe düğümüne bağlı, kubbeyle birlikte söner)
class _Orbit extends Node3D:
	var sp := 0.6
	func _process(d: float) -> void:
		rotate_y(sp * d)


static func dome_grains(root: Node3D, r: float) -> void:
	var o := _Orbit.new()
	root.add_child(o)
	for k in 40:
		var mi := MeshInstance3D.new()
		mi.mesh = _grain()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var y := randf_range(-0.6, 0.8)
		mi.position = Vector3(cos(a), y, sin(a)) * r * randf_range(0.85, 1.0)
		mi.scale = Vector3.ONE * r * randf_range(0.03, 0.06)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		o.add_child(mi)


## Sabaku Sōsō sıkışması: alanda kum çarşafı içe çöker gibi dış halka + kum fışkırması
static func crush(ctr: Vector3, R: float, s: float) -> void:
	var g := BeastFX._ground(ctr)
	BeastFX._card("shk_sheet", _SAND_SHEET, g, R * 2.2, Vector3.UP, 0.6)
	BeastFX._parts(g, _clump(), 26, 1.0, 5.0, 11.0, Vector3.UP, 40.0, Vector3(0, -14, 0), 0.3 * s, 0.6 * s, R * 0.8, false, [[0.0, 0.4], [0.2, 1.0], [1.0, 0.0]])


## Kum seli halkası: yerden yükselen kum
static func flood_ring(ctr: Vector3, rr: float, s: float) -> void:
	var g := BeastFX._ground(ctr)
	BeastFX._parts(g + Vector3.UP * s, _clump(), 14, 1.2, 5.0, 12.0, Vector3.UP, 45.0, Vector3(0, -14, 0), 0.3 * s, 0.6 * s, rr, false, [[0.0, 0.4], [0.2, 1.0], [1.0, 0.0]])
	BeastFX._parts(g + Vector3.UP * s, _grain(), 40, 1.0, 6.0, 12.0, Vector3.UP, 50.0, Vector3(0, -18, 0), 0.12 * s, 0.25 * s, rr)
