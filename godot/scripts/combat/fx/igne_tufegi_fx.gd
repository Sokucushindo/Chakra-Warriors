extends RefCounted
## Chūsha-jū: model, lazer ve uyku şırıngaları (hedef: res://scripts/combat/fx/igne_tufegi_fx.gd).
## Kanon (Injection Shot Sniper + Injection Shot): ilkel keskin nişancı borusu; üstte dürbün, altta lazer; arka uca avuçla vurulunca şırınga uzun menzile çıkar. İçindeki kimyasal hedefi saniyeler içinde bayıltır.
## Mekanik: doz birikir. Normal atış 1 doz, nişanlı atış 2 doz; 2 dozda hedef kısa süre uyuşur, sonra uyur. Hasarı düşüktür. Uyuyana bitiriş ağır vurur. Fukiya'dan farkı: menzil, nişan, doz. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "igne_tufegi"
const SPEED := 105.0
const GRAV := 0.25
const DOSE_T := 9.0
const SLEEP_T := 2.2
const MUZZLE := Vector3(0, 0, 0.47)
const LASER := Vector3(0, -0.075, 0.36)

const LASER_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void fragment() {
	ALBEDO = vec3(1.0, 0.16, 0.12);
	ALPHA = 0.55;
}
"""


# ------------------------------------------------------------------ model
## Kabza 0, namlu +Z (ref Needle_Sniper_2.png): koyu boru, halkalar, hasır kavrama, üstte dürbün, ağızda alttan lazer kutusu
static func model(b: MB) -> void:
	var m = Color(0.25, 0.26, 0.31)
	var d = Color(0.15, 0.15, 0.19)
	b.add("cyl", Vector3(0, 0, 0.04), Vector3(0.05, 0.86, 0.05), m, Vector3(90, 0, 0), 10)
	for z in [-0.37, -0.22, 0.13, 0.3, 0.38]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.064, 0.022, 0.064), d, Vector3(90, 0, 0), 10)
	b.add("cyl", Vector3(0, 0, -0.08), Vector3(0.056, 0.12, 0.056), Color(0.1, 0.1, 0.11), Vector3(90, 0, 0), 8)
	b.add("box", Vector3(0, 0.05, 0.27), Vector3(0.03, 0.05, 0.1), d)
	b.add("cyl", Vector3(0, 0.09, 0.23), Vector3(0.03, 0.26, 0.03), m, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0.09, 0.09), Vector3(0.05, 0.05, 0.05), m, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0.09, 0.37), Vector3(0.046, 0.05, 0.046), m, Vector3(90, 0, 0), 8)
	b.add("box", Vector3(0, -0.06, 0.37), Vector3(0.04, 0.07, 0.06), d)


static func _build_dart() -> Mesh:
	var b = MB.new()
	var glass = Color(0.76, 0.8, 0.82)
	b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.03, 0.15, 0.03), glass, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.05), Vector3(0.032, 0.04, 0.032), Color(0.82, 0.84, 0.66), Vector3(90, 0, 0), 8)
	b.add("cone", Vector3(0, 0, 0.09), Vector3(0.03, 0.03, 0.03), glass, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.15), Vector3(0.004, 0.1, 0.004), Color(0.15, 0.15, 0.17), Vector3(90, 0, 0), 4)
	for k in 6:
		var a = TAU * k / 6.0
		b.add("cone", Vector3(cos(a) * 0.014, sin(a) * 0.014, -0.11), Vector3(0.022, 0.08, 0.008), Color(0.62, 0.6, 0.5), Vector3(-90 + sin(a) * 18.0, 0, -cos(a) * 18.0), 3)
	return b.build(LazyFx.g("Props").toon())


static func _build_beam() -> Mesh:
	var c = CylinderMesh.new()
	c.top_radius = 0.006
	c.bottom_radius = 0.006
	c.height = 1.0
	c.radial_segments = 4
	c.rings = 1
	return c


static func _dart_mesh() -> Mesh:
	return Kit.cached_mesh("igne_dart", Callable(_build_dart))


# ------------------------------------------------------------------ lazer
static func _laser(who: Node3D, dur: float) -> void:
	var s = {"t": 0.0}
	var beam = MeshInstance3D.new()
	beam.mesh = Kit.cached_mesh("igne_beam", Callable(_build_beam))
	beam.material_override = Kit.shader_mat("igne_laser", LASER_SH)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.extra_cull_margin = 200.0
	var tg = U.target_of(who)
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		if float(s["t"]) >= dur or not is_instance_valid(who) or who.is_dead():
			return true
		var n = U.weapon_node(who, ID)
		if n == null:
			return true
		var a: Vector3 = n.to_global(LASER)
		var b: Vector3 = U.aim_at(who, tg if U.alive(tg) else null)
		var d = b - a
		var L = maxf(d.length(), 0.05)
		var y = d / L
		var x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
		beam.global_transform = Transform3D(Basis(x, y * L, x.cross(y)), (a + b) * 0.5)
		return false
	Kit.ticker(who.global_position, fn).add_child(beam)
	beam.global_transform = Transform3D(Basis.from_scale(Vector3.ZERO), who.global_position)


# ------------------------------------------------------------------ doz
static func asleep(t: Node3D) -> bool:
	return Game.now() < float(t.get_meta("igne_uyku", 0.0))


static func _dose(t: Node3D, n: int) -> void:
	if n <= 0 or not U.alive(t) or not t.has_method("apply_status"):
		return
	var now = Game.now()
	var d = (int(t.get_meta("igne_doz", 0)) if now < float(t.get_meta("igne_doz_t", 0.0)) else 0) + n
	t.set_meta("igne_doz_t", now + DOSE_T)
	if d < 2:
		t.set_meta("igne_doz", d)
		t.apply_status("slow", 1.5)
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyuşuyor...", Color(0.78, 0.9, 0.82))
		return
	t.set_meta("igne_doz", 0)
	t.apply_status("slow", 1.0)
	t.get_tree().create_timer(0.7).timeout.connect(_sleep.bind(t))


static func _sleep(t: Node3D) -> void:
	if U.alive(t):
		t.apply_status("stun", SLEEP_T)
		t.set_meta("igne_uyku", Game.now() + SLEEP_T)
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyudu!", Color(0.78, 0.9, 0.82))


# ------------------------------------------------------------------ atış
static func _dart(who: Node3D, aim: Vector3, dmg: float, dose: int) -> void:
	var n = U.weapon_node(who, ID)
	var from: Vector3 = n.to_global(MUZZLE) if n != null else who.global_position + Vector3.UP * 1.3 + who.face_dir() * 0.5
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = _dart_mesh()
	v.rotation.y = PI
	root.add_child(v)
	var dir = (aim - from).normalized()
	var cb = func(pos: Vector3, t: Node3D) -> void:
		if t == null or not is_instance_valid(t):
			return
		var pin = MeshInstance3D.new()
		pin.mesh = _dart_mesh()
		U.pin(pin, t, pos - dir * 0.1, dir, 2.5)
		Sfx.play("hit_claw", pos, 1.9, 0.3)
		_dose(t, dose)
	U.fire(who, from, U.solve(from, aim, SPEED, GRAV), {"g": GRAV, "r": 0.09, "life": 2.6, "stick": true, "vis": root, "hit": cb,
		"info": {"dmg": dmg, "knock": 0.2, "kind": "light", "hitstop": 0.0}})
	Sfx.play("punch", from, 1.7, 0.35)   # avuç vuruşu
	Sfx.play("whoosh", from, 2.4, 0.2)


static func _shoot_later(who: Node3D, dmg: float, dose: int) -> void:
	if is_instance_valid(who):
		_dart(who, U.aim_at(who, U.target_of(who)), dmg, dose)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	var d = [0.32, 0.28, 0.36, 0.86, 0.54, 1.02]
	_laser(who, float(d[clampi(i, 0, 5)]))
	if i == 2 and who is CharacterBody3D:
		var f: Vector3 = who.face_dir()
		who.velocity.x = -f.x * 8.0
		who.velocity.z = -f.z * 8.0
		who.velocity.y = 4.5


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	if i == 3:
		_dart(who, aim, dmg * 0.7, 2)
	elif i == 4:
		_dart(who, aim, dmg * 0.3, 1)
		who.get_tree().create_timer(0.24).timeout.connect(_shoot_later.bind(who, dmg * 0.3, 1))
	elif i == 5:
		if U.alive(tg) and asleep(tg):
			_dart(who, aim, dmg * 2.3, 0)
			Combat.popup_text(tg.global_position + Vector3.UP * 2.5, "Derin Uyku", Color(0.78, 0.9, 0.82))
		else:
			_dart(who, aim, dmg * 0.8, 2)
	else:
		_dart(who, aim, dmg * 0.42, 1)
