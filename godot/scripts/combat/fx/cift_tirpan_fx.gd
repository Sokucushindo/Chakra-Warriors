extends RefCounted
## Çift ağızlı tırpan (Futaba-gama; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/cift_tirpan_fx.gd). Kanon (Narutopedia "Double-Bladed Scythe",
## Ryūki, Boruto manga 12 / anime 110): Hidan'ınki gibi ritüel için kan toplar; kablosuzdur, yalnız saptan kullanılır, hafif olduğundan hızlı.
## Ref: kızıl sap, gümüş sargılı tutuş, iki gümüş bilezikten çıkan iki paralel pembe-kızıl hilal. İz: iki paralel ince yay (iki ağız).
## Mekanik: isabetler ağızlarda kan biriktirir (en çok 5); bitiriş kanı harcar.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const MAX_KAN := 5
const KAN_T := 8.0
const RED := Color(0.44, 0.13, 0.16)
const BLADE := Color(0.84, 0.46, 0.48)
const SILVER := Color(0.68, 0.7, 0.74)

const ARC_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float fade_k = 1.0;
instance uniform float blood = 0.0;
void fragment() {
	float x = UV.x;
	float w = 0.5 * sin(3.14159 * pow(x, 0.62)) * (0.3 + 0.7 * fade_k);
	float d = abs(UV.y - 0.5);
	if (d > w) discard;
	ALBEDO = mix(mix(vec3(0.98, 0.78, 0.8), vec3(0.72, 0.05, 0.08), blood), vec3(1.0, 0.96, 0.95), 1.0 - d / max(w, 0.001));
	ALPHA = fade_k;
}
"""


## Hilal (y, z): sapa dik çıkar, sapa doğru geri kıvrılır
static func _crescent(z: float) -> PackedVector2Array:
	var o = PackedVector2Array()
	var n = 12
	for i in n + 1:
		var u = float(i) / n
		o.append(Vector2(0.03 + 0.5 * u, z + 0.06 - 0.3 * u * u))
	for i in range(n, -1, -1):
		var u = float(i) / n
		o.append(Vector2(0.03 + 0.46 * u, z - 0.05 - 0.22 * u * u))
	return o


static func model(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.46), Vector3(0.032, 1.5, 0.032), RED, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.1), Vector3(0.038, 0.62, 0.038), SILVER, Vector3(90, 0, 0), 8)
	for k in 12:
		b.add("cyl", Vector3(0, 0, -0.38 + k * 0.05), Vector3(0.041, 0.01, 0.041), SILVER.darkened(0.35), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.42), Vector3(0.046, 0.03, 0.046), RED.darkened(0.2), Vector3(90, 0, 0), 8)
	for z in [0.9, 1.14]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.058, 0.12, 0.058), SILVER, Vector3(90, 0, 0), 10)
		b.add("cyl", Vector3(0, 0, z - 0.075), Vector3(0.066, 0.016, 0.066), RED, Vector3(90, 0, 0), 10)
		b.add_slab(_crescent(z), 0.012, BLADE)


static func kan(who: Node3D) -> int:
	return int(who.get_meta("ct_kan", 0)) if Game.now() - float(who.get_meta("ct_t", -99.0)) < KAN_T else 0


static func _axes(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized(), who.global_position + Vector3.UP * 1.1]


static func _arc(c: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, w: float, blood: float) -> void:
	var nx = a.cross(b).normalized()
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 25:
		var k = i / 24.0
		var e = lerpf(a0, a1, k)
		var d = (a * cos(e) + b * sin(e)).normalized()
		var ac = (d * 0.6 + nx * 0.4).normalized() * w * 0.5
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(c + d * r - ac)
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(c + d * r + ac)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("ct_yay", ARC_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter("blood", blood)
	Kit.tween_param(mi, "fade_k", 1.0, 0.0, 0.2, true)


## İki ağız = iki paralel yay
static func _twin(c: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, blood: float) -> void:
	_arc(c, a, b, r, a0, a1, 0.13, blood)
	_arc(c, a, b, r - 0.3, a0 + 0.06, a1 + 0.06, 0.1, blood)


static func start(who: Node3D, i: int) -> void:
	if who != null and is_instance_valid(who) and i == 2:
		U.face(who, U.aim_at(who, U.target_of(who)))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var x = _axes(who)
	var f: Vector3 = x[0]
	var s: Vector3 = x[1]
	var c: Vector3 = x[2]
	var bl = float(kan(who)) / MAX_KAN
	match i:
		0:
			_twin(c, f, s, 2.5, 1.2, -1.1, bl)
		1:
			_twin(c, f, s, 2.4, -1.1, 1.1, bl)
		2:
			_twin(c, f, Vector3.UP, 2.3, 0.7, -0.4, bl)
		3:
			_twin(c, f, Vector3.UP, 2.3, -0.8, 1.2, bl)
		4:
			_twin(c, f, s, 2.5, 0.0, TAU, bl)
		5:
			var n = kan(who)
			who.set_meta("ct_kan", 0)
			_twin(c, f, Vector3.UP, 2.9, 1.5, -0.7, 1.0 if n > 0 else 0.0)
			if n > 0:   # toplanan kan: ek kesik
				Combat.hit_sphere(who, c + f * 2.4, 2.2, {"dmg": dmg * 0.22 * n, "knock": 6.0, "kind": "heavy", "hitstop": 0.06, "melee": true, "blade": true})
				Combat.popup_text(who.global_position + Vector3.UP * 2.3, "Chimatsuri", Color(0.9, 0.25, 0.28))


static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	if i != 5:
		who.set_meta("ct_kan", mini(MAX_KAN, kan(who) + 1))
		who.set_meta("ct_t", Game.now())
	var m = Kit.cached_mesh("ct_damla", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.026, 0.04, 0.026), Color(0.62, 0.05, 0.07), Vector3.ZERO, 5)
		return b.build(LazyFx.g("Props").toon()))
	var c = U.chest(h)
	for k in 5:
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(mi)
		mi.global_position = c
		var v = Vector3(randf_range(-1, 1), randf_range(0.2, 1.3), randf_range(-1, 1)) * randf_range(1.2, 2.6)
		var fly = func(t: float) -> void:
			if is_instance_valid(mi):
				mi.global_position = c + v * t + Vector3.DOWN * 7.0 * t * t
		var tw = mi.create_tween()
		tw.tween_method(fly, 0.0, 0.34, 0.34)
		tw.tween_callback(mi.queue_free)
