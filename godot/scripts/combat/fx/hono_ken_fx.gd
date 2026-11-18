extends RefCounted
## Honō no Ken (ateş kılıcı; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/hono_ken_fx.gd). Kanon (Narutopedia "Fire Sword", yalnız ANİME 217; Hōki, Seimei):
## büyük miktarda ateş çıkarıp dilediği gibi yönetir, önündekini yakar; uçtaki yeşil küreden ışık sinyali yollar; Mugen Kōgai, Gariantō ve Fujaku'yu çağırır.
## Oyunda bu üçü kılıcın sahibinden birlikte düşer (WeaponHolders "set"). Ref refs/ates_kilici/Hoki_Fire_Sword.png: koyu uzun ağız, oluklar, yeşil küre.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const FLAME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float seed_k = 0.0;
void fragment() {
	float x = UV.x * 26.0 + seed_k * 40.0;
	float t = abs(fract(x) - 0.5) * 2.0;
	float t2 = abs(fract(x * 0.43 + 0.3) - 0.5) * 2.0;
	float top = (0.35 + 0.42 * t + 0.23 * t2) * (1.0 - prog * prog) * smoothstep(0.0, 0.06, UV.x) * (1.0 - smoothstep(0.94, 1.0, UV.x));
	float eat = prog * prog * 0.55 * (0.6 + 0.4 * t2);
	if (UV.y > top || UV.y < eat) discard;
	float h = UV.y / max(top, 0.001);
	ALBEDO = h < 0.34 ? vec3(1.0, 0.92, 0.55) : (h < 0.7 ? vec3(1.0, 0.56, 0.12) : vec3(0.86, 0.2, 0.06));
	ALPHA = 1.0;
}
"""

const BEAM_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float fade_k = 1.0;
void fragment() {
	float d = abs(UV.y - 0.5) * 2.0;
	float w = (0.25 + 0.75 * fade_k) * (1.0 - UV.x * 0.35);
	if (d > w) discard;
	ALBEDO = mix(vec3(0.9, 1.0, 0.94), vec3(0.2, 0.9, 0.62), d / max(w, 0.001)) * 1.9;
	ALPHA = fade_k;
}
"""


static func build(b: MB) -> void:
	var steel = Color(0.27, 0.28, 0.29)
	var edge = Color(0.5, 0.52, 0.52)
	b.add_slab(PackedVector2Array([Vector2(-0.038, 0.08), Vector2(0.038, 0.08), Vector2(0.05, 0.3), Vector2(0.05, 1.08), Vector2(0.03, 1.17), Vector2(-0.03, 1.17), Vector2(-0.05, 1.08), Vector2(-0.05, 0.3)]), 0.018, steel)
	for sy in [-1.0, 1.0]:
		b.add("box", Vector3(0, sy * 0.05, 0.63), Vector3(0.008, 0.006, 0.98), edge)
		b.add("box", Vector3(0, sy * 0.018, 0.6), Vector3(0.021, 0.004, 0.88), Color(0.13, 0.13, 0.14))
		b.add_slab(PackedVector2Array([Vector2(sy * 0.01, 0.05), Vector2(sy * 0.11, 0.1), Vector2(sy * 0.075, 0.055), Vector2(sy * 0.02, 0.0)]), 0.03, Color(0.15, 0.15, 0.17))
	b.add("cyl", Vector3(0, 0, -0.09), Vector3(0.036, 0.2, 0.036), Color(0.12, 0.11, 0.13), Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0, -0.2), Vector3(0.05, 0.05, 0.05), Color(0.2, 0.2, 0.23), Vector3.ZERO, 8)
	b.add("torus", Vector3(0, 0, 1.11), Vector3(0.09, 0.09, 0.09), Color(0.18, 0.19, 0.2), Vector3(0, 0, 90), 14)
	b.add("sphere", Vector3(0, 0, 1.11), Vector3.ONE * 0.07, Color(0.28, 0.78, 0.58), Vector3.ZERO, 12)


static func _axes(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized(), who.global_position]


## Yerden kalkan alev şeridi: merkez c, a -> a1 yayı, yüksekliği h
static func _wave(c: Vector3, f: Vector3, s: Vector3, r: float, a0: float, a1: float, h: float, life: float, delay := 0.0) -> void:
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 41:
		var k = i / 40.0
		var a = lerpf(a0, a1, k)
		var p: Vector3 = c + (f * cos(a) + s * sin(a)) * r
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(p)
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(p + Vector3.UP * h)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("hono_alev", FLAME_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = delay <= 0.0
	Kit.scene().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter("seed_k", randf())
	var tw = mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): mi.visible = true)
	var set_p = func(v: float) -> void:
		mi.set_instance_shader_parameter("prog", v)
	tw.tween_method(set_p, 0.0, 1.0, life)
	tw.tween_callback(mi.queue_free)


static func _floor_at(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor(p.x, p.z) + 0.03, p.z)


static func _beam(from: Vector3, to: Vector3) -> void:
	var d = to - from
	var f = d.normalized()
	var side = Vector3.UP.cross(f).normalized()
	for up in [Vector3.UP, side]:
		var mi = Kit.quad(Kit.scene(), 1.0, Kit.shader_mat("hono_isin", BEAM_SH))
		var y: Vector3 = (up - f * f.dot(up)).normalized()
		mi.global_transform = Transform3D(Basis(f * d.length(), y * 0.2, f.cross(y)), (from + to) * 0.5)
		Kit.tween_param(mi, "fade_k", 1.0, 0.0, 0.3, true)


static func _zone(who: Node3D, f: Vector3, reach: float, half: float, dmg: float, extra := {}) -> void:
	var info = {"dmg": dmg, "knock": 4.0, "kind": "light", "element": "katon", "burn": 2.0, "hitstop": 0.03, "melee": false}
	info.merge(extra, true)
	Combat.hit_zone(who, who.global_position, f, reach, half, 3.2, info)


static func start(_who: Node3D, _i: int) -> void:
	pass


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var x = _axes(who)
	var f: Vector3 = x[0]
	var s: Vector3 = x[1]
	var c: Vector3 = _floor_at(x[2])
	Sfx.play("fire", c + Vector3.UP, randf_range(0.85, 1.05), 0.55)
	match i:
		0:
			_wave(c, f, s, 3.2, 1.1, -1.0, 1.8, 0.42)
			_zone(who, f, 4.3, 60.0, dmg * 0.55)
		1:
			_wave(c, f, s, 3.2, -1.1, 1.0, 1.8, 0.42)
			_zone(who, f, 4.3, 60.0, dmg * 0.55)
		2:
			for k in 6:
				var q = _floor_at(x[2] + f * (1.6 + k * 1.15))
				_wave(q, f, s, 0.5, 0.0, TAU, 2.4 + k * 0.15, 0.5, k * 0.05)
			_zone(who, f, 8.5, 16.0, dmg * 0.8, {"knock": 6.0})
		3:
			_wave(c, f, s, 3.4, 0.0, TAU, 2.2, 0.55)
			_wave(c, f, s, 2.3, 0.0, TAU, 1.5, 0.45, 0.06)
			Combat.hit_sphere(who, c + Vector3.UP, 4.0, {"dmg": dmg * 0.7, "knock": 7.0, "launch": 4.0, "kind": "heavy", "element": "katon", "burn": 2.0, "hitstop": 0.04, "melee": false})
		4:   # uçtaki yeşil küreden ışın (kanon: küreden ışık sinyali)
			var from: Vector3 = who.global_position + Vector3.UP * 1.35 + f * 1.3
			var n = who.get("model").weapons[0]["node"] if who.get("model") != null and not (who.get("model").weapons as Array).is_empty() else null
			if n != null and is_instance_valid(n):
				from = n.to_global(Vector3(0, 0, 1.11))
			_beam(from, from + f * 14.0)
			Sfx.play("zap", from, 1.7, 0.4)
			Combat.hit_zone(who, who.global_position, f, 14.5, 5.0, 3.2, {"dmg": dmg * 0.85, "knock": 3.0, "kind": "light", "hitstop": 0.03, "melee": false})
		5:
			for k in 3:
				_wave(c, f, s, 3.6 + k * 2.3, 0.75, -0.75, 3.0 + k * 0.5, 0.62, k * 0.09)
			_zone(who, f, 10.5, 42.0, dmg * 1.2, {"knock": 12.0, "launch": 3.0, "kind": "heavy", "burn": 3.5, "hitstop": 0.08})
			if who is Player and Game.world:
				Game.world.env.add_shake(0.55)
