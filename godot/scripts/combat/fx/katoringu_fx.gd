extends RefCounted
## Katoringu: model, dönen namlular, ısı ve ateş mermileri (hedef: res://scripts/combat/fx/katoringu_fx.gd).
## Kanon (Fire Gatling): chakra istemez; içinde depolanmış Katon'u döner namlulardan seri ateş topları olarak saçar, geniş alana ağır hasar. Ref: Ao's_Weapon.png (ağızda dikenli beyaz parlama, turuncu toplar).
## Bedel oyun karşılığı: namlu ısınır; ısı dolunca silah tutukluk yapar, soğuyana dek ateş etmez. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "katoringu"
const SPEED := 64.0
const HEAT_SHOT := 0.04
const COOL := 0.2         # saniyede
const JAM_T := 2.4
const MUZZLE := Vector3(0, 0, 1.32)

const BALL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float m = 1.0 - smoothstep(0.1, 0.95, length(p * vec2(1.0, 0.8)));
	ALBEDO = mix(vec3(1.0, 0.36, 0.05), vec3(1.0, 0.93, 0.55), m);
	ALPHA = clamp(m * 1.7, 0.0, 1.0);
	if (ALPHA < 0.02) discard;
}
"""

const STAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
instance uniform float seed_k = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) + seed_k * 6.283;
	float spikes = 0.34 + 0.5 * pow(abs(sin(a * 5.0)), 5.0) + 0.16 * pow(abs(sin(a * 9.0 + 1.0)), 7.0);
	float m = 1.0 - smoothstep(spikes * 0.72, spikes, length(p));
	ALBEDO = vec3(1.0, 0.94, 0.68);
	ALPHA = m * fade;
	if (ALPHA < 0.02) discard;
}
"""

const HOT_SH := """shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;
instance uniform float heat = 0.0;
void fragment() {
	ALBEDO = mix(vec3(0.75, 0.12, 0.02), vec3(1.0, 0.65, 0.2), heat);
	ALPHA = smoothstep(0.35, 1.0, heat) * 0.85;
}
"""


## Namluları döndüren düğüm: dönüş hızı adım sırasında yükselir, ısı parıltısı
class Rig extends Node3D:
	var who: Node3D
	var drum: MeshInstance3D
	var glow: MeshInstance3D
	var spin := 0.0

	func _process(dt: float) -> void:
		if who == null or not is_instance_valid(who):
			var p = get_parent()
			while p != null and not p.has_method("take_hit"):
				p = p.get_parent()
			who = p as Node3D   # silah kına / ele taşınsa da sahibi aynı; önizlemede sahip yok
			if who == null:
				return
		if not is_visible_in_tree():
			return
		var now = Game.now()
		var want = 30.0 if now < float(who.get_meta("kt_fire_until", 0.0)) else 0.0
		spin = move_toward(spin, want, dt * (70.0 if want > 0.0 else 16.0))
		drum.rotation.z = fposmod(drum.rotation.z + spin * dt, TAU)
		var h = maxf(0.0, float(who.get_meta("kt_heat", 0.0)) - (now - float(who.get_meta("kt_heat_t", now))) * 0.2)
		glow.set_instance_shader_parameter("heat", h)


# ------------------------------------------------------------------ model
## Kabza 0, namlu +Z; gövde kalın bronz silindir, halka, altı namlu (namlular ayrı mesh, döner)
static func model(b: MB) -> void:
	var dark = Color(0.2, 0.19, 0.2)
	var bronze = Color(0.5, 0.4, 0.24)
	b.add("cyl", Vector3(0, 0, 0.2), Vector3(0.17, 0.8, 0.17), dark, Vector3(90, 0, 0), 14)
	b.add("sphere", Vector3(0, 0, -0.2), Vector3(0.17, 0.17, 0.16), dark.darkened(0.2), Vector3.ZERO, 12)
	for z in [0.34, 0.42]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.215, 0.05, 0.215), bronze, Vector3(90, 0, 0), 16)
	b.add("cyl", Vector3(0, 0, 0.62), Vector3(0.11, 0.05, 0.11), bronze.darkened(0.15), Vector3(90, 0, 0), 12)
	b.add("cyl", Vector3(0, -0.14, 0.42), Vector3(0.04, 0.18, 0.04), Color(0.12, 0.1, 0.09), Vector3(12, 0, 0), 8)   # ön tutamak
	b.add("box", Vector3(0, 0.1, 0.05), Vector3(0.05, 0.03, 0.34), bronze.darkened(0.3))


static func drum_model(b: MB) -> void:
	var steel = Color(0.5, 0.52, 0.56)
	for k in 6:
		var a = TAU * k / 6.0
		var c = Vector3(cos(a) * 0.052, sin(a) * 0.052, 0.96)
		b.add("cyl", c, Vector3(0.034, 0.7, 0.034), steel, Vector3(90, 0, 0), 8)
		b.add("cyl", c + Vector3(0, 0, 0.35), Vector3(0.02, 0.006, 0.02), Color(0.04, 0.04, 0.05), Vector3(90, 0, 0), 8)
	for z in [0.78, 1.16]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.15, 0.024, 0.15), steel.darkened(0.25), Vector3(90, 0, 0), 12)


static func _build_glow() -> Mesh:
	var c = CylinderMesh.new()
	c.top_radius = 0.094
	c.bottom_radius = 0.094
	c.height = 0.66
	c.radial_segments = 12
	c.rings = 1
	return c


## Silah kurulumunda: dönen namlular
static func attach(node: Node3D) -> void:
	var rig = Rig.new()
	rig.name = "KatoRig"
	var drum = MeshInstance3D.new()
	drum.mesh = CharacterModel.weapon_mesh("katoringu_namlu")
	rig.drum = drum
	rig.add_child(drum)
	var glow = MeshInstance3D.new()
	glow.mesh = Kit.cached_mesh("kato_glow", Callable(_build_glow))
	glow.material_override = Kit.shader_mat("kato_hot", HOT_SH)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0, 0.97)
	glow.rotation.x = PI * 0.5
	rig.glow = glow
	rig.add_child(glow)
	node.add_child(rig)


# ------------------------------------------------------------------ ısı
static func heat_of(who: Node3D) -> float:
	var now = Game.now()
	var h = maxf(0.0, float(who.get_meta("kt_heat", 0.0)) - (now - float(who.get_meta("kt_heat_t", now))) * COOL)
	who.set_meta("kt_heat", h)
	who.set_meta("kt_heat_t", now)
	return h


static func _can_fire(who: Node3D) -> bool:
	return Game.now() >= float(who.get_meta("kt_jam", 0.0))


static func _add_heat(who: Node3D, v: float) -> void:
	var h = heat_of(who) + v
	who.set_meta("kt_heat", minf(h, 1.0))
	if h >= 1.0:
		who.set_meta("kt_jam", Game.now() + JAM_T)
		who.set_meta("kt_heat", 1.0)
		Combat.popup_text(who.global_position + Vector3.UP * 2.2, "Namlu Kızdı!", Color(1.0, 0.55, 0.25))
		Sfx.play("th_steam", who.global_position + Vector3.UP * 1.2, 1.0, 0.8)


# ------------------------------------------------------------------ atış
static func _muzzle(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	return n.to_global(MUZZLE) if n != null else who.global_position + Vector3.UP * 1.2 + who.face_dir() * 1.3


static func _flash(p: Vector3, size: float) -> void:
	var root = Kit.scene()
	var mi = Kit.quad(root, size, Kit.shader_mat("kato_star", STAR_SH))
	mi.global_position = p
	mi.set_instance_shader_parameter("seed_k", randf())
	Kit.tween_param(mi, "fade", 1.0, 0.0, 0.08, true)


static func _ball_vis() -> Node3D:
	var root = Node3D.new()
	Kit.quad(root, 0.55, Kit.shader_mat("kato_ball", BALL_SH))
	var tail = Kit.quad(root, 0.34, Kit.shader_mat("kato_ball", BALL_SH))
	tail.position = Vector3(0, 0, 0.3)
	return root


## Tek top. mode: "air" hedefe, "ground" yere iner ve küçük alan yakar
static func _shot(who: Node3D, to: Vector3, dmg: float, mode: String) -> void:
	if not is_instance_valid(who) or who.is_dead() or not _can_fire(who):
		return
	var from = _muzzle(who)
	var land = func(pos: Vector3, t: Node3D) -> void:
		if t != null and is_instance_valid(t) and t.has_method("apply_status"):
			t.apply_status("burn", 0.9)
		elif mode == "ground" and is_instance_valid(who):
			Combat.hit_sphere(who, pos + Vector3.UP * 0.4, 1.15, {"dmg": dmg * 0.7, "knock": 0.5, "kind": "light", "element": "katon", "hitstop": 0.0})
			_flash(pos + Vector3.UP * 0.25, 1.1)
	U.fire(who, from, (to - from).normalized() * SPEED, {"r": 0.17, "life": 1.15, "vis": _ball_vis(), "hit": land,
		"info": {"dmg": dmg, "knock": 0.25, "kind": "light", "element": "katon", "hitstop": 0.0}})
	_flash(from, 1.5)
	Sfx.play("fire", from, randf_range(1.9, 2.3), 0.22)
	_add_heat(who, HEAT_SHOT)


## aim_fn(j) -> hedef noktası
static func _burst(who: Node3D, n: int, gap: float, aim_fn: Callable, dmg: float, mode := "air") -> void:
	if not _can_fire(who):
		Sfx.play("click", who.global_position + Vector3.UP * 1.2, 0.55, 0.8)
		return
	who.set_meta("kt_fire_until", Game.now() + n * gap + 0.25)
	for j in n:
		who.get_tree().create_timer(j * gap).timeout.connect(_fire_one.bind(who, j, aim_fn, dmg, mode))


static func _fire_one(who: Node3D, j: int, aim_fn: Callable, dmg: float, mode: String) -> void:
	if is_instance_valid(who):
		_shot(who, aim_fn.call(j), dmg, mode)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, _i: int) -> void:
	if who != null and is_instance_valid(who):
		U.face(who, U.aim_at(who, U.target_of(who)))
		who.set_meta("kt_fire_until", Game.now() + 0.5)   # namlu önce döner


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if i == 2:
		Sfx.play("hit_heavy_weapon", who.global_position + Vector3.UP, 1.0, 0.7)
		return
	var tg = U.target_of(who)
	var base = U.aim_at(who, tg)
	U.face(who, base)
	var fw = base - who.global_position
	fw.y = 0.0
	var f: Vector3 = fw.normalized() if fw.length() > 0.1 else who.face_dir()
	var side = f.cross(Vector3.UP).normalized()
	var D = maxf(fw.length(), 8.0)
	var live = func() -> Vector3:
		return U.aim_at(who, tg) if is_instance_valid(who) else base
	var scatter = func(j: int) -> Vector3:
		return live.call() + side * randf_range(-0.5, 0.5) * (1.0 + j * 0.05) + Vector3.UP * randf_range(-0.3, 0.3)
	var sweep = func(j: int) -> Vector3:
		return base + side * lerpf(-D * 0.55, D * 0.55, j / 9.0)
	var ground = func(j: int) -> Vector3:
		var q = who.global_position + f * lerpf(3.0, D + 2.0, j / 8.0) + side * sin(j * 1.4) * 0.8
		q.y = Game.jutsu_floor_at(q).y
		return q
	if i == 0:
		_burst(who, 5, 0.09, scatter, dmg * 0.22)
	elif i == 1:
		_burst(who, 10, 0.07, sweep, dmg * 0.2)
	elif i == 3:
		_burst(who, 9, 0.075, ground, dmg * 0.18, "ground")
	elif i == 4:
		_burst(who, 14, 0.055, scatter, dmg * 0.17)
	else:
		_burst(who, 22, 0.045, scatter, dmg * 0.16)
		who.get_tree().create_timer(22 * 0.045 + 0.02).timeout.connect(_overheat.bind(who))


static func _overheat(who: Node3D) -> void:
	if is_instance_valid(who) and _can_fire(who):
		_add_heat(who, 1.0)
