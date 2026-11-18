extends RefCounted
## Fujaku Hishō Shōken (不弱飛翔小剣; hedef: res://scripts/combat/fx/fujaku_fx.gd). Kanon (Narutopedia "Weaknessless Soaring Shortswords", ANİME 217; Kujaku, Hōki):
## Takumi yapımı ikiz jian. Saldırıya tepki verir, rüzgârı serbestçe dönüştürür, az chakrayla üst düzey Fūton yaptırır; kasırgayla havada taşır; iki ağız birleşip tek kılıç olur.
## Teknikler: Kaze-kiri, Kujaku Senpū, Kaze-gaeshi. Ref refs/fujaku/Shoken.png: açık mavi ağız, altın üçgen balçak, yeşil taş, ağ sargılı kabza.
## Silah kuşanılınca Fūton jutsuları daha az chakra ister (weapon.fuuton_cost, oyuncu ve düşman).

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const BLADE := Color(0.62, 0.78, 0.9)
const GOLD := Color(0.74, 0.6, 0.24)

const WIND_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float fade_k = 1.0;
void fragment() {
	float x = UV.x;
	float rag = 0.5 + 0.5 * sin(x * 37.0 + UV.y * 5.0);
	float w = 0.5 * sin(3.14159 * x) * (0.55 + 0.45 * rag) * (0.4 + 0.6 * fade_k);
	float d = abs(UV.y - 0.5);
	if (d > w) discard;
	ALBEDO = FRONT_FACING ? vec3(0.86, 0.96, 0.98) : vec3(0.56, 0.74, 0.8);
	ALPHA = fade_k * 0.95;
}
"""


static func _base(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, -0.09), Vector3(0.03, 0.17, 0.03), Color(0.56, 0.72, 0.86), Vector3(90, 0, 0), 8)
	for k in 5:
		b.add("cyl", Vector3(0, 0, -0.16 + k * 0.03), Vector3(0.0325, 0.005, 0.0325), Color(0.22, 0.28, 0.4), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.195), Vector3(0.04, 0.04, 0.04), GOLD, Vector3(90, 0, 0), 6)
	b.add_slab(PackedVector2Array([Vector2(-0.075, 0.0), Vector2(0.075, 0.0), Vector2(0.018, 0.1), Vector2(-0.018, 0.1)]), 0.026, GOLD)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.0135, 0, 0.034), Vector3(0.006, 0.042, 0.042), Color(0.2, 0.68, 0.52), Vector3.ZERO, 8)


static func _blade(b: MB, w: float, L: float) -> void:
	b.add_slab(PackedVector2Array([Vector2(-w, 0.08), Vector2(w, 0.08), Vector2(w, L - 0.07), Vector2(0.0, L), Vector2(-w, L - 0.07)]), 0.01, BLADE)
	b.add("box", Vector3(0, 0, (0.08 + L) * 0.47), Vector3(0.012, 0.005, L - 0.2), BLADE.lightened(0.35))


static func build(b: MB) -> void:
	_base(b)
	_blade(b, 0.021, 0.74)


## İki ağız birleşmiş tek kılıç
static func build_merged(b: MB) -> void:
	_base(b)
	_blade(b, 0.042, 1.04)
	b.add("box", Vector3(0, 0, 0.5), Vector3(0.012, 0.003, 0.8), Color(0.3, 0.42, 0.52))


static func _both(who: Node3D) -> Array:
	var out = []
	var m = who.get("model")
	if m == null or m.get("weapons") == null:
		return out
	for w in m.weapons:
		if str(w["id"]) == "fujaku" and is_instance_valid(w["node"]):
			out.append(w)
	return out


static func _axes(who: Node3D) -> Array:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	return [f, Vector3.UP.cross(f).normalized(), who.global_position + Vector3.UP * 1.1]


static func _arc(c: Vector3, a: Vector3, b: Vector3, r: float, a0: float, a1: float, w: float, life := 0.26) -> void:
	var nx = a.cross(b).normalized()
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 25:
		var k = i / 24.0
		var e = lerpf(a0, a1, k)
		var d = (a * cos(e) + b * sin(e)).normalized()
		var ac = (d * 0.35 + nx * 0.65).normalized() * w * 0.5
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(c + d * r - ac)
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(c + d * r + ac)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Kit.shader_mat("fujaku_ruzgar", WIND_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	Kit.tween_param(mi, "fade_k", 1.0, 0.0, life, true)


## Uçan rüzgâr kesiği (görsel -Z'ye gider)
static func _crescent_mesh() -> Mesh:
	return Kit.cached_mesh("fujaku_hilal", func():
		var im = ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 25:
			var k = i / 24.0
			var a = lerpf(-1.05, 1.05, k)
			var p = Vector3(sin(a), 0.0, -cos(a) + 1.0)
			im.surface_set_uv(Vector2(k, 0.0))
			im.surface_add_vertex(p * 1.5 + Vector3(0, -0.05, 0))
			im.surface_set_uv(Vector2(k, 1.0))
			im.surface_add_vertex(p * 1.5 + Vector3(0, 0.05, 0.28))
		im.surface_end()
		return im)


static func _cutter(who: Node3D, from: Vector3, dir: Vector3, dmg: float, scale_k := 1.0) -> void:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = _crescent_mesh()
	mi.material_override = Kit.shader_mat("fujaku_ruzgar", WIND_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * scale_k
	root.add_child(mi)
	U.fire(who, from, dir * 34.0, {"r": 0.75 * scale_k, "life": 0.5, "pierce": true, "vis": root, "info": {"dmg": dmg, "knock": 5.0, "kind": "light", "element": "fuuton", "hitstop": 0.02}})


## Kujaku Senpū: kasırga taşır (kanon: rüzgârla havada kalma)
static func _rise(who: Node3D, T: float, dmg: float) -> void:
	var st = {"t": 0.0, "next": 0.0}
	var fn = func(dt: float) -> bool:
		st["t"] += dt
		var t: float = st["t"]
		if not is_instance_valid(who) or t >= T:
			return true
		if who is CharacterBody3D:
			who.velocity.y = lerpf(8.5, 1.0, t / T)
		if t >= float(st["next"]):
			st["next"] = t + 0.11
			var c: Vector3 = who.global_position + Vector3.UP * randf_range(0.0, 1.8)
			var a0 = randf() * TAU
			_arc(c, Vector3.RIGHT, Vector3.BACK, randf_range(1.0, 2.1), a0, a0 + 2.2, 0.22, 0.22)
			Combat.hit_sphere(who, who.global_position + Vector3.UP, 2.5, {"dmg": dmg * 0.12, "knock": 1.0, "launch": 2.0, "kind": "light", "element": "fuuton", "hitstop": 0.0, "melee": false})
		return false
	Kit.ticker(who.global_position, fn)
	Sfx.play("wind", who.global_position, 1.2, 0.6)


## Kaze-gaeshi: 2.2 m içine giren düşman mermisi atana döner
static func _return(who: Node3D, T: float) -> void:
	var st = {"t": 0.0}
	var fn = func(dt: float) -> bool:
		st["t"] += dt
		if not is_instance_valid(who) or float(st["t"]) >= T:
			return true
		var c: Vector3 = who.global_position + Vector3.UP * 1.1
		for pr in Kit.tree().get_nodes_in_group("projectiles"):
			if not is_instance_valid(pr) or pr.dead or pr.shooter == null or not is_instance_valid(pr.shooter) or float(pr.radius) > 0.8:
				continue
			if Combat.hostile(who, pr.shooter) and pr.global_position.distance_to(c) < 2.2:
				pr.vel = -pr.vel * 1.1
				pr.shooter = who
				pr.hit_list = []
				if pr.get("homing") != null:
					pr.homing = null
				var d: Vector3 = pr.vel.normalized()
				_arc(pr.global_position, d, Vector3.UP, 0.9, -1.0, 1.0, 0.16, 0.2)
				Sfx.play("wind", c, 1.8, 0.45)
		return false
	Kit.ticker(who.global_position, fn)


static func _merge(who: Node3D, on: bool) -> void:
	for w in _both(who):
		var n: Node3D = w["node"]
		if str(w["side"]) == "Left":
			n.visible = not on
		elif n is MeshInstance3D:
			(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("fujaku_bir" if on else "fujaku")


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	match i:
		4:
			_return(who, 0.56)
		5:
			who.get_tree().create_timer(0.24).timeout.connect(func():
				if is_instance_valid(who):
					_merge(who, true)
					Sfx.play("clash", who.global_position + Vector3.UP, 1.6, 0.4))
			who.get_tree().create_timer(1.35).timeout.connect(func():
				if is_instance_valid(who):
					_merge(who, false))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var x = _axes(who)
	var f: Vector3 = x[0]
	var s: Vector3 = x[1]
	var c: Vector3 = x[2]
	var aim_d: Vector3 = (U.aim_at(who, U.target_of(who)) - c).normalized()
	match i:
		0:
			_arc(c, f, s, 1.9, 1.0, -0.9, 0.16)
		1:
			_arc(c, f, s, 1.9, -1.0, 0.9, 0.16)
		2:
			_arc(c, f, s, 1.9, 0.9, -0.9, 0.18)
			_cutter(who, c + f * 0.8, aim_d, dmg * 0.8)
			Sfx.play("wind", c, 1.5, 0.5)
		3:
			_rise(who, 0.7, dmg)
		4:
			_arc(c, f, s, 2.0, -1.5, 1.5, 0.2)
		5:
			_arc(c, f, Vector3.UP, 2.5, 1.5, -0.7, 0.28, 0.32)
			_cutter(who, c + f * 0.8, aim_d, dmg * 1.5, 2.0)
			Sfx.play("wind", c, 0.9, 0.7)
			if who is Player and Game.world:
				Game.world.env.add_shake(0.35)
