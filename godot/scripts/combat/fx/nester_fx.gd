extends RefCounted
## Mesu (メス, neşter; hedef: res://scripts/combat/fx/nester_fx.gd). Kanon: Narutopedia "Scalpel" yalnız kullanıcı listesi verir: Kabuto, Shizune, Shin Uchiha (ana), anime ve
## filmlerde başkaları. Biçim sayfası yok: gerçek cerrahi neşter. Shin neşterlerle bedenin kilit noktalarına vurup hareketi engeller. Chakra Neşteri (jutsu, Tıp tarzı) ayrı kalır.
## Mekanik: az hasar, kesin kesik. Her isabet yavaşlatır; aynı hedefe üçüncü kesikte kiriş kopar: kısa süre kıpırdayamaz.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const STEEL := Color(0.8, 0.82, 0.86)
const CUT_T := 4.0

const NICK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(0.7);
	float s = sin(0.7);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float w = 0.05 * (1.0 - abs(q.x)) * (1.0 - prog);
	if (abs(q.y) > w) discard;
	ALBEDO = vec3(0.9, 0.97, 1.0) * 2.0;
	ALPHA = 1.0 - prog;
}
"""


## Uç +Z; düz yassı sap, bombeli küçük ağız. Boy ~21 cm
static func model(b: MB) -> void:
	b.add("box", Vector3.ZERO, Vector3(0.005, 0.016, 0.13), Color(0.66, 0.68, 0.72))
	for k in 5:
		b.add("box", Vector3(0, 0, -0.05 + k * 0.016), Vector3(0.0065, 0.017, 0.004), Color(0.42, 0.43, 0.47))
	b.add_slab(PackedVector2Array([Vector2(-0.007, 0.065), Vector2(0.007, 0.065), Vector2(0.012, 0.1), Vector2(0.006, 0.125), Vector2(-0.008, 0.15), Vector2(-0.007, 0.105)]), 0.002, STEEL)


static func _mesh() -> Mesh:
	return Kit.cached_mesh("mesu", func():
		var b = MB.new()
		model(b)
		return b.build(LazyFx.g("Props").toon()))


static func _nick(p: Vector3) -> void:
	var mi = Kit.quad(Kit.scene(), 0.9, Kit.shader_mat("mesu_cizik", NICK_SH))
	mi.global_position = p
	Kit.tween_param(mi, "prog", 0.0, 1.0, 0.13, true)


## Kanon (Shin): kilit noktaya isabet hareketi keser
static func cut(who: Node3D, h: Node3D) -> void:
	_nick(U.chest(h))
	Sfx.play("hit_blade", h.global_position + Vector3.UP, 1.75, 0.4)
	if not h.has_method("apply_status"):
		return
	h.apply_status("slow", 1.6)
	var key = "mesu_%d" % who.get_instance_id()
	var now = Game.now()
	var n = (int(h.get_meta(key, 0)) if now - float(h.get_meta(key + "_t", -9.0)) < CUT_T else 0) + 1
	h.set_meta(key + "_t", now)
	if n >= 3:
		n = 0
		h.apply_status("bind", 0.8)
		Combat.popup_text(h.global_position + Vector3.UP * 2.2, "Kiriş kesildi!", Color(0.85, 0.92, 1.0))
	h.set_meta(key, n)


static func _throw(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var m = _mesh()
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = m
	v.rotation.y = PI
	v.position = Vector3(0, 0, 0.05)
	root.add_child(v)
	var dir: Vector3 = (to - from).normalized()
	var cb = func(pos: Vector3, tgt: Node3D) -> void:
		if tgt != null and is_instance_valid(tgt) and is_instance_valid(who):
			var mi = MeshInstance3D.new()
			mi.mesh = m
			U.pin(mi, tgt, pos - dir * 0.08, dir, 2.2)
			cut(who, tgt)
	U.fire(who, from, U.solve(from, to, 62.0, 1.5), {"g": 1.5, "r": 0.09, "life": 1.3, "stick": true, "vis": root, "hit": cb, "info": {"dmg": dmg, "knock": 0.5, "kind": "light", "hitstop": 0.01}})


static func start(who: Node3D, i: int) -> void:
	if who != null and is_instance_valid(who) and i in [3, 5]:
		U.face(who, U.aim_at(who, U.target_of(who)))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if i != 3 and i != 5:
		return
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var from: Vector3 = U.bone_pos(who, "RightHand")
	var f: Vector3 = aim - from
	f.y = 0.0
	var s: Vector3 = Vector3.UP.cross(f.normalized() if f.length() > 0.05 else who.face_dir()).normalized()
	Sfx.play("throw", from, 1.5, 0.45)
	if i == 3:
		for k in 3:
			_throw(who, from, aim + s * (k - 1) * 0.5, dmg * 0.42)
		return
	var lh: Vector3 = U.bone_pos(who, "LeftHand")   # altı kilit nokta: omuzlar, dirsekler, dizler
	var pts = [Vector3(0.28, 0.35, 0), Vector3(-0.28, 0.35, 0), Vector3(0.4, 0.0, 0), Vector3(-0.4, 0.0, 0), Vector3(0.16, -0.55, 0), Vector3(-0.16, -0.55, 0)]
	for k in 6:
		var o: Vector3 = pts[k]
		_throw(who, lh if k % 2 == 1 else from, aim + s * o.x + Vector3.UP * o.y, dmg * 0.36)


static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	if i != 3 and i != 5:
		cut(who, h)
