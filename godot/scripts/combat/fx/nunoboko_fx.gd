extends RefCounted
## Nunoboko no Ken: model, arayış gücü ve bitiriş (hedef: res://scripts/combat/fx/nunoboko_fx.gd).
## Kanon: arayış toplarından (Gudōdama) oluşmuş çift sarmal dev kılıç; Altı Yol Bilgesi dünyayı onunla "yarattı". Adı Kokoro no Ken: içindeki duygunun gücü kılıca geçer.
## Şart: yalnız On Kuyruk jinchūrikisi ya da Rikudō gücündeyken uyanır (eşya On Kuyruk'u bedene çekince verilir, parayla satılmaz). Uyanık değilken sıradan ağır kılıç.
## Uyanıkken: savuruş ileri uçan ninjutsuyu siler (arayış gücü), değdiği rakipten chakra koparır; canın azaldıkça ek kesik büyür (Kokoro). Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "nunoboko"
const L := 2.3
const BUFFS := ["rikudo_sennin", "rikudo_senjutsu", "rikudo_no_jutsu"]

const VOID_SH := """shader_type spatial;
render_mode unshaded, cull_back;
instance uniform float fade = 1.0;
void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(vec3(0.015, 0.015, 0.02), vec3(0.2, 0.2, 0.26), pow(rim, 3.0));
	if (fade < 0.999 && fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453) > fade) discard;
}
"""

const STAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float m = pow(max(0.0, 1.0 - sqrt(p.x) - sqrt(p.y) * 0.9), 2.0) * 3.0 + pow(max(0.0, 1.0 - sqrt(p.y) - sqrt(p.x) * 0.9), 2.0) * 3.0;
	ALBEDO = vec3(0.86, 0.9, 1.0);
	ALPHA = clamp(m, 0.0, 1.0) * fade;
	if (ALPHA < 0.02) discard;
}
"""


# ------------------------------------------------------------------ model
## Kabza 0, uç +Z. İki sarmal kol uca doğru kalınlaşıp sonda incelir, aralarında basamaklar; elin gerisinde ince burgulu sivri kuyruk (ref).
static func _r(u: float) -> float:
	return lerpf(0.05, 0.17, smoothstep(0.0, 0.45, u)) * (1.0 - smoothstep(0.85, 1.0, u) * 0.75)


static func model(b: MB) -> void:
	var black = Color(0.045, 0.045, 0.055)
	for s in 2:
		var pts = []
		var rad = []
		for k in 25:
			var u = k / 24.0
			var a = u * TAU * 2.25 + s * PI
			var r = _r(u)
			pts.append(Vector3(cos(a) * r, sin(a) * r, 0.14 + u * L))
			rad.append(lerpf(0.03, 0.062, sin(u * PI)))
		Loft.tube(b, pts, rad, black, 8, 1)
	for k in 10:
		var u = (k + 0.5) / 10.0
		var a = u * TAU * 2.25
		var r = _r(u)
		var z = 0.14 + u * L
		b.add("cyl", Vector3(0, 0, z), Vector3(0.028, r * 2.0, 0.028), black.lightened(0.04), Vector3(0, 0, rad_to_deg(a) - 90.0), 6)
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.05, 0.3, 0.05), black, Vector3(90, 0, 0), 8)   # kavrama
	var tail = []
	var tr = []
	for k in 7:
		var u = k / 6.0
		var a = u * TAU
		tail.append(Vector3(cos(a) * 0.016, sin(a) * 0.016, -0.1 - u * 0.5))
		tr.append(lerpf(0.024, 0.006, u))
	Loft.tube(b, tail, tr, black, 6, 1)


# ------------------------------------------------------------------ şart
static func awake(who: Node3D) -> bool:
	if not (who is Player):
		return true
	if bool(Game.profile.get("jubi_jinchuriki", false)):
		return true
	for k in BUFFS:
		if Buffs.has(k):
			return true
	return false


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir()
	f.y = 0.0
	return f.normalized()


static func _build_orb() -> Mesh:
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 18
	s.rings = 10
	return s


static func _orb_node(parent: Node, size: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = Kit.cached_mesh("nunoboko_orb", Callable(_build_orb))
	mi.material_override = Kit.shader_mat("nunoboko_void", VOID_SH)
	mi.scale = Vector3.ONE * size
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ arayış gücü
## Önündeki yayda uçan ninjutsu / atılan mermi silinir
static func _erase(who: Node3D, centre: Vector3, r: float) -> void:
	var n = 0
	for pr in who.get_tree().get_nodes_in_group("projectiles"):
		if not (pr is Projectile) or bool(pr.dead) or pr.shooter == who:
			continue
		if pr.shooter != null and is_instance_valid(pr.shooter) and not Combat.hostile(who, pr.shooter):
			continue
		if (pr as Node3D).global_position.distance_to(centre) > r:
			continue
		var p: Vector3 = pr.global_position
		pr.dead = true
		pr.queue_free()
		_vanish(p, 0.5)
		n += 1
	if n > 0:
		Combat.popup_text(who.global_position + Vector3.UP * 2.4, "Hükümsüz", Color(0.8, 0.82, 0.92))
		Sfx.play("absorb", centre, 0.7, 0.7)


static func _vanish(p: Vector3, size: float) -> void:
	var mi = _orb_node(Kit.scene(), size)
	mi.global_position = p
	Kit.tween_param(mi, "fade", 1.0, 0.0, 0.3, true)


static func _star(p: Vector3, size: float, delay: float) -> void:
	var mi = Kit.quad(Kit.scene(), size, Kit.shader_mat("nunoboko_star", STAR_SH))
	mi.global_position = p
	mi.set_instance_shader_parameter("fade", 0.0)
	var tw = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_star_fade.bind(mi))


static func _star_fade(mi: MeshInstance3D) -> void:
	if is_instance_valid(mi):
		Kit.tween_param(mi, "fade", 1.0, 0.0, 0.7, true)


## Kokoro no Ken: can azaldıkça ek kesik
static func _heart(who: Node3D, c: Vector3, r: float, dmg: float) -> void:
	var mh = float(who.get("max_hp")) if who.get("max_hp") != null else 0.0
	if mh <= 0.0:
		return
	var lost = clampf(1.0 - float(who.get("hp")) / mh, 0.0, 1.0)
	if lost > 0.1:
		Combat.hit_sphere(who, c, r, {"dmg": dmg * 0.55 * lost, "knock": 0.0, "kind": "light", "hitstop": 0.0, "melee": true})


# ------------------------------------------------------------------ uzayan kılıç
static func _stretch(who: Node3D, k: float, up: float, hold: float) -> void:
	var n = U.weapon_node(who, ID)
	if n == null:
		return
	var s0: Vector3 = n.scale
	var tw = n.create_tween()
	tw.tween_property(n, "scale", Vector3(s0.x, s0.y, s0.z * k), up)
	tw.tween_interval(hold)
	tw.tween_property(n, "scale", s0, 0.3)


# ------------------------------------------------------------------ Sōsei: yerden sarmal küreler, yıldız izi
static func _creation(who: Node3D, dmg: float) -> void:
	var f = _face(who)
	var side = f.cross(Vector3.UP).normalized()
	var from = who.global_position + f * 2.2
	var count = 14
	var done: Array = []
	var s = {"t": 0.0, "i": 0}
	var orbs: Array = []
	var box := {}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who):
			return true
		s["t"] += dt
		var t: float = s["t"]
		while int(s["i"]) < count and t >= int(s["i"]) * 0.05:
			var i: int = s["i"]
			s["i"] = i + 1
			for sign_v in [-1.0, 1.0]:
				var a = i * 0.7
				var q = from + f * (i * 0.72) + side * sin(a) * sign_v * 1.0
				q.y = Game.jutsu_floor_at(q).y - 0.4
				var o = _orb_node(box["root"], 0.75 + i * 0.015)
				o.global_position = q
				orbs.append({"n": o, "t0": t, "base": q})
			var c = from + f * (i * 0.72)
			c.y = Game.jutsu_floor_at(c).y + 1.0
			done.append_array(Combat.hit_sphere(who, c, 1.6, {"dmg": dmg * 0.5, "knock": 1.5, "launch": 3.5, "kind": "heavy", "hitstop": 0.04, "melee": false}, done))
			_star(c + Vector3(randf_range(-1, 1), randf_range(0.5, 2.4), randf_range(-1, 1)), 1.4, 0.05)
			Sfx.play("earth", c, 0.55 + i * 0.02, 0.3)
		for e in orbs:
			var age = t - float(e["t0"])
			var h = sin(clampf(age / 0.7, 0.0, 1.0) * PI) * 1.9
			(e["n"] as Node3D).global_position = (e["base"] as Vector3) + Vector3.UP * h
		return t > count * 0.05 + 0.8
	box["root"] = Kit.ticker(from, fn)
	if who is Player and Game.world:
		Game.world.env.add_shake(0.7)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who) or not awake(who):
		return
	if i == 2:
		_stretch(who, 1.45, 0.45, 0.25)
	elif i == 4:
		_stretch(who, 1.6, 0.5, 0.45)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = _face(who)
	var c = who.global_position + Vector3.UP * 1.2 + f * 2.2
	Sfx.play("swing_heavy", c, 0.55, 0.7)
	if not awake(who):
		return
	_erase(who, c, 4.0)
	_heart(who, c, 2.0, dmg)
	if i == 5:
		_creation(who, dmg)


static func on_hit(who: Node3D, _i: int, h: Node3D) -> void:
	if not awake(who) or h == null or not is_instance_valid(h):
		return
	if h.get("chakra") != null and h.get("max_chakra") != null:
		h.chakra = maxf(0.0, float(h.chakra) - float(h.max_chakra) * 0.05)
