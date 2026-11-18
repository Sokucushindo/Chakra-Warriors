extends RefCounted
## Kuwa: model, toprak ve karık (hedef: res://scripts/combat/fx/kuwa_fx.gd). Narutopedia yalnız kullanıcıyı verir (Fū Yamanaka); biçim gerçek tarla çapasından, kanon görseli yok.
## Mekanik: toprak silahı. Savrulan toprak yüzü kapatır (yavaşlatır, kısa sersemletir); açılan karık üstünden geçeni yavaşlatır. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const FURROW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float e = abs(UV.y * 2.0 - 1.0);
	float bump = 0.5 + 0.5 * sin(UV.x * 60.0);
	vec3 c = mix(vec3(0.1, 0.07, 0.05), vec3(0.36, 0.27, 0.18), smoothstep(0.45, 0.95 - bump * 0.1, e));
	ALBEDO = c;
	ALPHA = (1.0 - smoothstep(0.92, 1.0, e)) * fade_k;
}
"""

const CLOD_SH := """shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""


## Kabza 0, sap +Z, ağız -Y; ağız sapa dik, geniş yüzü X boyunca
static func model(b: MB) -> void:
	var wood = Color(0.47, 0.34, 0.21)
	var iron = Color(0.28, 0.28, 0.3)
	var edge = Color(0.7, 0.71, 0.72)
	b.add("cyl", Vector3(0, 0, 0.25), Vector3(0.05, 1.66, 0.05), wood, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 1.03), Vector3(0.075, 0.13, 0.075), iron, Vector3(90, 0, 0), 8)
	b.add("box", Vector3(0, -0.15, 1.05), Vector3(0.1, 0.2, 0.024), iron)
	b.add("box", Vector3(0, -0.31, 1.03), Vector3(0.26, 0.16, 0.02), iron, Vector3(8, 0, 0))
	b.add("box", Vector3(0, -0.4, 1.016), Vector3(0.275, 0.035, 0.01), edge, Vector3(8, 0, 0))
	b.add("cyl", Vector3(0, 0, 1.11), Vector3(0.03, 0.04, 0.03), wood.darkened(0.3), Vector3(90, 0, 0), 6)


static func _build_clod() -> Mesh:
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color.WHITE, Vector3(15, 30, 0), 4)
	return b.build()


## Toprak parçaları; dir yönüne savrulur
static func _clods(p: Vector3, n: int, dir: Vector3, up: float, spread: float, size: float) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Yk.mesh("kuwa_clod", Callable(_build_clod))
	mm.instance_count = n
	var data = []
	for i in n:
		var a = randf() * TAU
		var v = dir * randf_range(0.6, 1.0) + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, spread) + Vector3.UP * randf_range(0.5, 1.0) * up
		var g = randf_range(0.2, 0.32)
		data.append([v, randf_range(0.5, 1.0) * size])
		mm.set_instance_color(i, Color(g * 1.4, g, g * 0.72))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Yk.mat("kuwa_clod_m", CLOD_SH)
	mi.custom_aabb = AABB(p - Vector3.ONE * 12.0, Vector3.ONE * 24.0)
	Yk.root().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var T = 0.6
	var step = func(t: float) -> void:
		if not is_instance_valid(mi):
			return
		var sc = 1.0 - smoothstep(0.7 * T, T, t)
		for i in n:
			var e: Array = data[i]
			var q = p + (e[0] as Vector3) * t + Vector3.DOWN * 12.0 * t * t
			q.y = maxf(q.y, p.y)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3(0.4, 0.8, 0.4).normalized(), t * 7.0 + i).scaled(Vector3.ONE * float(e[1]) * sc), q))
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, T, T)
	tw.tween_callback(mi.queue_free)


## Yere yatık tek şerit (dikey kanat olmasın)
static func _flat(pts: Array, side: Vector3, w: float) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	var last = float(pts.size() - 1)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var k = 1.0 - i / last * 0.55
		im.surface_set_uv(Vector2(i / last, 0))
		im.surface_add_vertex(pts[i] - side * w * k)
		im.surface_set_uv(Vector2(i / last, 1))
		im.surface_add_vertex(pts[i] + side * w * k)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Yk.mat("kuwa_furrow", FURROW_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Yk.root().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


## Karık: yerde ilerleyen şerit; üstündekini vurur, yavaşlatır
static func _furrow(who: Node3D, from: Vector3, dir: Vector3, L: float, dmg: float) -> void:
	var side = dir.cross(Vector3.UP).normalized()
	var pts = []
	for k in 17:
		var u = k / 16.0
		pts.append(Yk.gp(from + dir * L * u + side * sin(u * 9.0 + L) * 0.07) + Vector3.UP * 0.02)
	Yk.fade(_flat(pts, side, 0.2), 1.4, 0.6)
	var done: Array = []
	for k in 5:
		Yk.after(who, 0.04 + k * 0.06, _furrow_hit.bind(who, pts[int((k + 1) * 3.2)], dir, dmg, done))


static func _furrow_hit(who: Node3D, p: Vector3, dir: Vector3, dmg: float, done: Array) -> void:
	_clods(p, 5, dir * 2.0, 3.6, 1.0, 0.13)
	var hits = Combat.hit_sphere(who, p + Vector3.UP * 0.6, 1.1, {"dmg": dmg, "knock": 2.0, "kind": "light", "hitstop": 0.04, "melee": true}, done)
	for h in hits:
		if h.has_method("apply_status"):
			h.apply_status("slow", 2.2)
	done.append_array(hits)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Yk.face(who)
	var g = Yk.gp(who.global_position + f * 2.0)
	if i == 0 or i == 1:
		_clods(g, 6, f * 1.5, 3.0, 1.2, 0.11)
		Sfx.play("step_dirt", g, 0.7, 0.8)
	elif i == 3:
		_clods(g, 18, f * 8.5, 3.0, 2.0, 0.13)
		Sfx.play("earth", g, 1.3, 0.6)
		var hits = Combat.hit_sphere(who, who.global_position + Vector3.UP * 1.3 + f * 2.8, 1.9, {"dmg": dmg * 0.4, "knock": 0.5, "stun": 0.45, "kind": "light", "hitstop": 0.02, "melee": true})
		for h in hits:
			if h.has_method("apply_status"):
				h.apply_status("slow", 2.5)
			Combat.popup_text(h.global_position + Vector3.UP * 2.2, "Gözüne toprak!", Color(0.8, 0.68, 0.48))
	elif i == 4:
		_furrow(who, who.global_position + f * 1.2, f, 7.0, dmg * 0.9)
		Sfx.play("earth", g, 0.9, 0.8)
	elif i == 5:
		var side = f.cross(Vector3.UP).normalized()
		for a in [-0.42, 0.0, 0.42]:
			_furrow(who, who.global_position + f * 1.3, (f + side * tan(a)).normalized(), 6.5, dmg * 0.75)
		_clods(g, 16, f * 2.0, 6.0, 3.0, 0.17)
		Sfx.play("hit_heavy_weapon", g, 0.62, 1.0)
		Yk.shake(who, 0.5)
