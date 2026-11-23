extends RefCounted
## Flail (hedef: res://scripts/combat/fx/flail_fx.gd). KANON ZAYIF: Narutopedia "Flail" yalnız Vikipedi'ye yönlenir; kullanıcı Tenten (manga + anime) ve Suiko.
## refs/tekko/Tentens_tools.png içinde dikenli kara top görünür. refs/flail/SuikoFlail.png ise ZİNCİRSİZ uzun saplı dikenli küp gürzdür: bu silah Tenten'in
## topundan ve gerçek flailden çıkarıldı. Sap + zincir + dikenli baş; baş gerçek zincirle gecikir (zincir_uc.gd).

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/flail_anim.gd")
const Z = preload("res://scripts/combat/fx/zincir_uc.gd")

const L := 1.05
const R_SW := 2.25
const TIP := Vector3(0, 0, 0.31)

const CRACK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float fade_k = 1.0;
instance uniform float seed_k = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + seed_k * 6.283;
	float w = sin(r * 13.0 + seed_k * 9.0) * 0.07;
	float m = abs(fract((a + w) * 7.0 / 6.283) - 0.5);
	float line = 1.0 - smoothstep(0.012, 0.045 * (1.15 - r), m * r * 1.2);
	float core = 1.0 - smoothstep(0.1, 0.2, r);
	if (r > 0.96 || max(line, core) < 0.3) discard;
	ALBEDO = vec3(0.09, 0.075, 0.065);
	ALPHA = fade_k;
}
"""


static func model(b: MB) -> void:
	var wood = Color(0.33, 0.2, 0.12)
	var iron = Color(0.2, 0.2, 0.23)
	b.add("cyl", Vector3(0, 0, 0.05), Vector3(0.036, 0.5, 0.036), wood, Vector3(90, 0, 0), 8)
	for z in [-0.19, -0.1, 0.0, 0.1]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.04, 0.012, 0.04), Color(0.12, 0.09, 0.07), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.29), Vector3(0.044, 0.04, 0.044), iron, Vector3(90, 0, 0), 8)
	b.add("sphere", Vector3(0, 0, -0.21), Vector3(0.05, 0.05, 0.05), iron, Vector3.ZERO, 8)


static func _head() -> Mesh:
	return Kit.cached_mesh("flail_bas", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.22, Color(0.17, 0.17, 0.2), Vector3.ZERO, 12)
		for i in 14:
			var y = 1.0 - (float(i) + 0.5) / 14.0 * 2.0
			var r = sqrt(maxf(0.0, 1.0 - y * y))
			var a = float(i) * 2.399
			var d = Vector3(cos(a) * r, y, sin(a) * r).normalized()
			if d.z < -0.82:
				continue   # zincirin girdiği yer boş
			var xn = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			b.add_xf("cone", Transform3D(Basis(xn * 0.052, d * 0.095, xn.cross(d) * 0.052), d * 0.138), Color(0.34, 0.34, 0.38), 5)
		return b.build(Props.toon()))


static func _link() -> Mesh:
	return Kit.cached_mesh("flail_halka", func():
		var b = MB.new()
		b.add("torus", Vector3.ZERO, Vector3(0.07, 0.11, 0.036), Color(0.16, 0.16, 0.19), Vector3.ZERO, 8)
		return b.build(Props.toon()))


## CharacterModel._weapons: silah kurulurken
static func attach(node: Node3D, owner_body: Node3D) -> void:
	var c = Z.new()
	c.name = "FlailZincir"
	node.add_child(c)
	c.setup(owner_body, node, TIP, _head(), _link(), L)


static func _chain(who: Node3D):
	var n = U.weapon_node(who, "flail")
	return n.get_node_or_null("FlailZincir") if n != null else null


## Başın izlediği yol: k 0..1, sona doğru hızlanır
static func _point(who: Node3D, i: int, k: float) -> Vector3:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	var s: Vector3 = Vector3.UP.cross(f).normalized()
	var c: Vector3 = who.global_position + Vector3.UP * 1.2
	var e = k * k
	var a := 0.0
	match i:
		0:
			a = lerpf(2.7, -0.75, e)
			return c + (f * cos(a) + s * sin(a)) * R_SW
		1:
			a = lerpf(-2.5, 0.8, e)
			return c + (f * cos(a) + s * sin(a)) * R_SW
		2:
			a = lerpf(2.9, -0.48, e)
			return c + (f * cos(a) + Vector3.UP * sin(a)) * (R_SW + 0.1)
		3:
			var t = U.target_of(who)
			var p: Vector3 = U.chest(t) if U.alive(t) and t.global_position.distance_to(who.global_position) < 4.2 else c + f * 3.2
			a = k * TAU * 2.0
			return c.lerp(p, minf(k / 0.55, 1.0)) + (s * cos(a) + Vector3.UP * sin(a) * 0.5) * (0.42 * smoothstep(0.5, 0.75, k))
		4:
			a = k * TAU * 3.0
			return c + Vector3.UP + (f * cos(a) + s * sin(a)) * R_SW
	if k < 0.72:
		a = k / 0.72 * TAU * 2.0
		return c + Vector3.UP + (f * cos(a) + s * sin(a)) * R_SW
	a = lerpf(2.2, -0.62, (k - 0.72) / 0.28)
	return c + (f * cos(a) + Vector3.UP * sin(a)) * (R_SW + 0.75)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var k = clampi(i, 0, 5)
	U.face(who, U.aim_at(who, U.target_of(who)))
	var ch = _chain(who)
	if ch != null:
		var path = func(u: float, a: Vector3) -> Vector3:
			return _point(who, k, u) if is_instance_valid(who) else a
		ch.drive(0.95 if k == 4 else float(A.HIT[k]) + (0.26 if k == 3 else 0.04), path)
	Sfx.play("swing_chain", who.global_position + Vector3.UP, 0.8, 0.4)


static func _crack(p: Vector3, r: float) -> void:
	var pm = PlaneMesh.new()
	pm.size = Vector2.ONE * r * 2.0
	var mi = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = Kit.shader_mat("flail_catlak", CRACK_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.scene().add_child(mi)
	mi.global_position = p
	mi.set_instance_shader_parameter("seed_k", randf())
	var tw = mi.create_tween()
	tw.tween_interval(2.5)
	var fade = func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("fade_k", v)
	tw.tween_method(fade, 1.0, 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


static func _chips(p: Vector3, n: int) -> void:
	var m = Kit.cached_mesh("flail_tas", func():
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE * 0.09, Color(0.42, 0.38, 0.33), Vector3.ZERO, 2)
		return b.build(Props.toon()))
	for k in n:
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(mi)
		mi.global_position = p
		var v = Vector3(randf_range(-1, 1), randf_range(0.8, 1.7), randf_range(-1, 1)) * randf_range(1.8, 3.4)
		var fly = func(t: float) -> void:
			if is_instance_valid(mi):
				mi.global_position = p + v * t + Vector3.DOWN * 8.0 * t * t
		var tw = mi.create_tween()
		tw.tween_method(fly, 0.0, 0.5, 0.5)
		tw.tween_callback(mi.queue_free)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	f = f.normalized()
	Sfx.play("hit_chain", who.global_position + f * 2.0 + Vector3.UP, 0.75, 0.5)
	match i:
		2, 5:
			var q: Vector3 = who.global_position + f * (2.1 if i == 2 else 2.8)
			q.y = Game.jutsu_floor_at(q).y + 0.04
			_crack(q, 1.4 if i == 2 else 2.8)
			_chips(q + Vector3.UP * 0.1, 5 if i == 2 else 10)
			Sfx.play("earth", q, 0.9, 0.6)
			if who is Player and Game.world:
				Game.world.env.add_shake(0.3 if i == 2 else 0.6)
			if i == 5:
				Combat.hit_sphere(who, q + Vector3.UP * 0.5, 3.0, {"dmg": dmg * 0.55, "knock": 7.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.05, "melee": false})
		3:   # zincir hedefe dolanır
			var t = U.target_of(who)
			if U.alive(t) and t.global_position.distance_to(who.global_position) < 4.2 and t.has_method("apply_status"):
				t.apply_status("bind", 0.9)
