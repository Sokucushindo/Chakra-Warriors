extends RefCounted
## Natatō: model, katlanma, Raiton yükü, fırlatma — kendi şekilleri ve gölgelendiricisi.
## Kaynak refs/natato/cleaver-sword.png: koyu geniş gövde, boyuna üç menteşe, açık renk dalgalı ağız, kısa beyaz sap + kızıl baklava.
## Kanon: menteşelerle katlanır; Raiton chakrası akıtılır, ağız elden çıksa da yükü tutar (Naruto 463). Raiton'u olmayan saf demir kullanır.

const Kit = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "natato"
const HINGE_Y := 0.13     # menteşe hattı: sırt yarısı -0.06..0.13, ağız yarısı 0.13..0.36
const LEN0 := 0.05
const LEN1 := 1.42
const CHARGE_COST := 0.08
const CHARGE_T := 9.0
const HOLD := 0.85

const BOLT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float flick = 0.7 + 0.3 * sin(UV.x * 40.0 - TIME * 60.0);
	ALBEDO = mix(vec3(0.25, 0.5, 1.0), vec3(0.92, 0.97, 1.0), smoothstep(0.4, 0.9, v));
	ALPHA = smoothstep(0.0, 0.45, v) * fade_k * flick;
}
"""


# ------------------------------------------------------------------ model
static func _spine(b: MB) -> void:
	var body = Color(0.27, 0.27, 0.29)
	var line = Color(0.1, 0.1, 0.11)
	b.add_slab(PackedVector2Array([Vector2(-0.06, LEN0), Vector2(HINGE_Y, LEN0), Vector2(HINGE_Y, LEN1), Vector2(-0.06, LEN1 - 0.03)]), 0.026, body, Transform3D.IDENTITY, Callable(), line)
	b.add("box", Vector3(0, HINGE_Y - 0.004, (LEN0 + LEN1) * 0.5), Vector3(0.03, 0.008, LEN1 - LEN0), line)
	for z in [0.36, 0.74, 1.12]:   # üç menteşe (kaynakta çizgi üstünde üç koyu kare)
		b.add("box", Vector3(0, HINGE_Y, z), Vector3(0.036, 0.034, 0.05), Color(0.14, 0.14, 0.15))
	var white = Color(0.9, 0.89, 0.86)
	var red = Color(0.6, 0.07, 0.1)
	b.add("box", Vector3(0, 0.0, -0.13), Vector3(0.036, 0.05, 0.36), white)
	for k in 4:   # sap sargısı arasından kızıl baklava
		var z = -0.26 + k * 0.085
		for s in [-1.0, 1.0]:
			b.add("box", Vector3(s * 0.019, 0.0, z), Vector3(0.004, 0.032, 0.032), red, Vector3(45, 0, 0))
	b.add("box", Vector3(0, 0.0, 0.03), Vector3(0.042, 0.075, 0.04), Color(0.2, 0.2, 0.21))


## Menteşeden dışa (yerel y 0..0.23): koyu yarı + dalgalı sınırlı açık ağız
static func _edge(b: MB) -> void:
	var body = Color(0.27, 0.27, 0.29)
	var steel = Color(0.82, 0.83, 0.85)
	b.add_slab(PackedVector2Array([Vector2(0.0, LEN0), Vector2(0.135, LEN0), Vector2(0.135, LEN1), Vector2(0.0, LEN1)]), 0.024, body)
	var o := PackedVector2Array([Vector2(0.23, LEN0), Vector2(0.23, LEN1 - 0.05)])
	var n = 22
	for i in range(n, -1, -1):   # kaynaktaki dalgalı sınır
		o.append(Vector2(0.12 + 0.012 * float(i % 2), lerpf(LEN0, LEN1, float(i) / n)))
	var thin = func(p: Vector2) -> float:
		return lerpf(0.02, 0.003, clampf((p.x - 0.12) / 0.11, 0.0, 1.0))
	b.add_slab(o, 0.018, steel, Transform3D.IDENTITY, thin, Color(0.62, 0.63, 0.66))


## Tam açık hâl (küçük resim, kın, fırlatılan kopya)
static func model(b: MB) -> void:
	_spine(b)
	var e = MB.new()
	_edge(e)
	b.add_mesh(e, Transform3D(Basis.IDENTITY, Vector3(0, HINGE_Y, 0)))


static func model_spine(b: MB) -> void:
	_spine(b)


static func model_edge(b: MB) -> void:
	_edge(b)


## Eldeki silah: sırt yarısı + menteşeli ağız yarısı (CharacterModel._weapons çağırır); katlı başlar
static func attach(node: Node3D) -> void:
	if not node is MeshInstance3D:
		return
	(node as MeshInstance3D).mesh = CharacterModel.weapon_mesh("natato_sirt")
	var e = MeshInstance3D.new()
	e.mesh = CharacterModel.weapon_mesh("natato_agiz")
	node.add_child(e)
	node.set_meta("natato_edge", e)
	_pose(e, 1.0)


static func _pose(e: Node3D, k: float) -> void:
	e.position = Vector3(0.022 * k, HINGE_Y, 0)
	e.rotation = Vector3(0, 0, PI * k)


static func _fold(n: Node3D, to: float) -> void:
	if n == null or not n.has_meta("natato_edge"):
		return
	var e: Node3D = n.get_meta("natato_edge")
	var from = float(n.get_meta("natato_k", 1.0))
	if not is_instance_valid(e) or absf(from - to) < 0.01:
		return
	n.set_meta("natato_k", to)
	var tw = e.create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(e):
			_pose(e, k), from, to, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("clink", n.global_position, 0.62, 0.55)


# ------------------------------------------------------------------ yük
static func charged(who: Node3D) -> bool:
	return Game.now() < float(who.get_meta("natato_volt", 0.0))


static func _arc(a: Vector3, b: Vector3, w: float, life: float) -> void:
	var pts = []
	for k in 7:
		var u = k / 6.0
		var off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.22 * sin(u * PI)
		pts.append(a.lerp(b, u) + off)
	Kit.fade(Kit.strip(pts, w, Kit.mat("natato_bolt", BOLT_SH), 0.5), life * 0.3, life * 0.7)


## Ağız boyunca kısa yaylar (silah uzayından dünyaya)
static func _blade_arcs(n: Node3D, c: int) -> void:
	if n == null or not is_instance_valid(n):
		return
	var xf: Transform3D = n.global_transform
	for i in c:
		var z = randf_range(0.2, 1.3)
		_arc(xf * Vector3(0, 0.3, z), xf * Vector3(randf_range(-0.1, 0.1), 0.42, z + randf_range(-0.25, 0.25)), 0.016, 0.16)


static func _charge(who: Node3D) -> void:
	if not Kit.nature(who, "raiton") or not Kit.pay(who, CHARGE_COST):
		return
	who.set_meta("natato_volt", Game.now() + CHARGE_T)
	Sfx.play("zap", who.global_position, 0.85, 0.7)
	var n = Kit.node_of(who, ID)
	for k in 5:
		Kit.after(who, k * 0.09, func():
			_blade_arcs(n, 3))


# ------------------------------------------------------------------ fırlatma (bitiriş)
static func _discharge(who: Node3D, at: Vector3, dmg: float) -> void:
	for j in 4:
		var a = randf() * TAU
		_arc(at + Vector3.UP * randf_range(0.5, 1.2), Kit.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(1.4, 2.8)), 0.035, 0.2)
	Combat.hit_sphere(who, at + Vector3.UP * 0.6, 2.8, {"dmg": dmg * 0.22, "knock": 0.8, "kind": "light", "element": "raiton", "stun": 0.25, "hitstop": 0.0, "melee": false})


static func _throw(who: Node3D, dmg: float) -> void:
	var scene = Kit.root()
	if scene == null:
		return
	var n = Kit.node_of(who, ID)
	var f = Kit.face(who)
	var volt = charged(who)
	var from: Vector3 = who.global_position + Vector3.UP * 1.35 + f * 0.5
	var tg = Combat.nearest_enemy(who, 9.0, f, 0.5)
	var at: Vector3 = Kit.gp(tg.global_position if tg != null else who.global_position + f * 7.5)
	var c = MeshInstance3D.new()
	c.mesh = CharacterModel.weapon_mesh(ID)
	scene.add_child(c)
	c.global_position = from
	if n != null:
		n.visible = false
	Combat.hit_zone(who, who.global_position, f, from.distance_to(at) + 0.8, 14.0, 2.2, {"dmg": dmg * 0.9, "knock": 4.0, "kind": "heavy", "hitstop": 0.05, "melee": false})
	Sfx.play("swing_heavy", from, 0.75, 0.9)
	var side = Vector3.UP.cross(f).normalized()
	var land_b = Basis.looking_at(Vector3.UP + f * 0.15, side)
	var fly_b = Basis.looking_at(-f, Vector3.UP) * Basis(Vector3.BACK, PI * 0.5)
	var tw = c.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(c):
			var spun = Basis(Vector3.UP, u * TAU * 2.5) * fly_b
			c.global_transform = Transform3D(spun.slerp(land_b, u * u), from.lerp(at + Vector3.UP * 1.2, u)), 0.0, 1.0, 0.26)
	tw.tween_callback(func():
		if not is_instance_valid(who):
			return
		Sfx.play("hit_heavy_weapon", at, 0.7, 0.9)
		Kit.shake(who, 0.45)
		Combat.hit_sphere(who, at + Vector3.UP * 0.7, 2.0, {"dmg": dmg * 0.8, "knock": 6.0, "launch": 3.5, "kind": "heavy", "hitstop": 0.06, "melee": false})
		if volt:   # saplı ağız yükünü boşaltır: elden çıkmış olsa da
			Sfx.play("thunder", at, 1.2, 0.7)
			for k in 4:
				Kit.after(who, 0.05 + k * 0.2, func():
					_discharge(who, at, dmg)))
	tw.tween_interval(HOLD)
	tw.tween_method(func(u: float):
		if is_instance_valid(c) and is_instance_valid(who):
			c.global_position = (at + Vector3.UP * 1.2).lerp(Kit.hand(who), u), 0.0, 1.0, 0.2)
	tw.tween_callback(func():
		if n != null and is_instance_valid(n):
			n.visible = true
		c.queue_free())


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	_fold(Kit.node_of(who, ID), 0.0)
	who.set_meta("natato_t", Game.now() + 3.4)
	Kit.after(who, 3.5, func():
		if Game.now() >= float(who.get_meta("natato_t", 0.0)):
			_fold(Kit.node_of(who, ID), 1.0))
	if i == 4:
		Kit.after(who, 0.2, func():
			_charge(who))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Kit.face(who)
	if i == 5:
		_throw(who, dmg)
		return
	if i == 2:
		Sfx.play("hit_heavy_weapon", who.global_position + f, 0.85, 0.7)
	if charged(who):
		Combat.hit_zone(who, who.global_position, f, 3.4, 60.0, 2.4, {"dmg": dmg * 0.3, "knock": 0.8, "kind": "light", "element": "raiton", "stun": 0.2, "hitstop": 0.0, "melee": false})
		_blade_arcs(Kit.node_of(who, ID), 4)
		Sfx.play("zap", who.global_position + f, 1.2, 0.45)


static func on_hit(who: Node3D, _i: int, h: Node3D) -> void:
	if charged(who) and h.has_method("apply_status"):
		h.apply_status("shock", 0.8)
