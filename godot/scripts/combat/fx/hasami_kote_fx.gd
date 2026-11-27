extends RefCounted
## Hasami Kote (makas kıskaç; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/hasami_kote_fx.gd). Kanon (Narutopedia "Scissor Pincers", Kamikiri, anime 137):
## yay sağ kola ve pazıya kara kayışla bağlı; her ağzın dibine bağlı beyaz ipler elde tutulur, dev makas tek elle çalışır. Keser, doğrar; kayayı yarar.
## Görünüş refs/hasami_kote: kara kavisli iki ağız, iç kenarda açık çelik, arkada C biçimli yay, ipli bağlar.
## Oyunda: gerçekten açılıp kapanır; kıskaca alınan hedef kısa süre tutulur, sıkılır, savrulur. Bağ fiziksel (Nawanuke çözer). Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "hasami_kote"
const OPEN_IDLE := 0.14
const OPEN_WIDE := 0.62
const HOLD := 1.0
const GRAB_R := 3.0

const SLASH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	if (v < 0.2 + 0.5 * UV.x) discard;
	ALBEDO = mix(vec3(0.3, 0.3, 0.33), vec3(0.95, 0.96, 0.98), smoothstep(0.5, 0.95, v));
	ALPHA = fade_k;
}
"""


# ------------------------------------------------------------------ model
## Tek ağız: dip orijinde, uç +Z, sırt +Y, kesen kenar -Y
static func _blade(b: MB) -> void:
	var o := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.09, 0.08), Vector2(0.15, 0.3), Vector2(0.15, 0.58), Vector2(0.09, 0.82), Vector2(-0.04, 1.02),
		Vector2(-0.02, 0.7), Vector2(-0.01, 0.34), Vector2(-0.015, 0.1)])
	b.add_slab(o, 0.022, Color(0.1, 0.1, 0.12), Transform3D.IDENTITY, Callable(), Color(0.05, 0.05, 0.06))
	var e := PackedVector2Array([Vector2(0.03, 0.2), Vector2(0.045, 0.5), Vector2(0.02, 0.8), Vector2(-0.04, 1.02), Vector2(-0.02, 0.7), Vector2(-0.01, 0.34)])
	b.add_slab(e, 0.026, Color(0.84, 0.85, 0.88))


static func _spring(b: MB) -> void:
	var black = Color(0.08, 0.08, 0.09)
	var pts = []
	var rad = []
	for k in 13:   # kolun arkasından dolaşan C yay
		var a = lerpf(-2.2, 2.2, k / 12.0)
		pts.append(Vector3(0, sin(a) * 0.17, -cos(a) * 0.13 + 0.03))
		rad.append(0.018)
	LazyFx.g("Loft").tube(b, pts, rad, black, 8, 2)
	for s in [-1.0, 1.0]:
		b.add("cyl", Vector3(0, s * 0.145, 0.1), Vector3(0.05, 0.03, 0.05), Color(0.76, 0.72, 0.62), Vector3(90, 0, 0), 8)   # ip bağları
	b.add("cyl", Vector3(0, 0, -0.03), Vector3(0.13, 0.05, 0.13), black, Vector3(90, 0, 0), 12)   # kol kayışı


static func model_base(b: MB) -> void:
	_spring(b)


static func model_blade(b: MB) -> void:
	_blade(b)


static func model(b: MB) -> void:
	_spring(b)
	var u = MB.new()
	_blade(u)
	b.add_mesh(u, Transform3D(Basis(Vector3.RIGHT, -0.14), Vector3(0, 0.12, 0.1)))
	b.add_mesh(u, Transform3D(Basis(Vector3.RIGHT, 0.14) * Basis(Vector3.BACK, PI), Vector3(0, -0.12, 0.1)))


static func _cord() -> Mesh:
	return Yk.mesh("hasami_ip", func():
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.008, 0.06, 0.008), Color(0.9, 0.88, 0.8), Vector3(90, 0, 0), 4)
		return b.build(LazyFx.g("Props").toon()))


## Kol silahı kurulumu: yay + iki menteşeli ağız + ele giden beyaz ipler (CharacterModel._weapons)
static func attach(node: Node3D, model_n: Node3D, side: String) -> void:
	if not node is MeshInstance3D:
		return
	(node as MeshInstance3D).mesh = CharacterModel.weapon_mesh("hasami_kote_k")
	var up = Node3D.new()
	var dn = Node3D.new()
	up.position = Vector3(0, 0.12, 0.1)
	dn.position = Vector3(0, -0.12, 0.1)
	node.add_child(up)
	node.add_child(dn)
	var bu = MeshInstance3D.new()
	bu.mesh = CharacterModel.weapon_mesh("hasami_kote_a")
	up.add_child(bu)
	var bd = MeshInstance3D.new()
	bd.mesh = bu.mesh
	bd.rotation.z = PI
	dn.add_child(bd)
	node.set_meta("hs_piv", [up, dn])
	_pose(node, OPEN_IDLE)
	var sk = model_n.get("skel")
	var bi = sk.find_bone(side + "Hand") if sk != null else -1
	for s in [-1.0, 1.0]:
		Yk.chain(node, _cord(), func(): return node.global_transform * Vector3(0, s * 0.145, 0.1), func():
			if bi < 0 or not is_instance_valid(sk):
				return node.global_position
			return (sk.global_transform * sk.get_bone_global_pose(bi)).origin, INF, 8, 0.06, 0.02)


static func _pose(n: Node3D, k: float) -> void:
	var p: Array = n.get_meta("hs_piv", [])
	if p.size() == 2 and is_instance_valid(p[0]) and is_instance_valid(p[1]):
		(p[0] as Node3D).rotation.x = -k
		(p[1] as Node3D).rotation.x = k
		n.set_meta("hs_k", k)


static func _to(who: Node3D, k: float, t: float) -> void:
	var n = Yk.node_of(who, ID)
	if n == null or not n.has_meta("hs_piv"):
		return
	var a = float(n.get_meta("hs_k", OPEN_IDLE))
	n.create_tween().tween_method(func(v: float):
		if is_instance_valid(n):
			_pose(n, v), a, k, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ görsel
static func _slash(c: Vector3, a: Vector3, b: Vector3, r: float) -> void:
	var pts = []
	for k in 9:
		var u = k / 8.0
		pts.append(c + a.normalized().slerp(b.normalized(), u).normalized() * r)
	Yk.fade(Yk.strip(pts, 0.1, Yk.mat("hasami_kesik", SLASH_SH), 0.8), 0.05, 0.14)


static func _shards(p: Vector3, n: int, up: float) -> void:
	var scene = Yk.root()
	if scene == null:
		return
	var m = Yk.mesh("hasami_tas", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.2, 0.12, 0.16), Color(0.36, 0.33, 0.3), Vector3(20, 30, 10))
		return b.build(LazyFx.g("Props").toon()))
	for i in n:
		var mi = MeshInstance3D.new()
		mi.mesh = m
		scene.add_child(mi)
		mi.global_position = p
		var v = Vector3(randf_range(-3, 3), randf_range(0.6, 1.0) * up, randf_range(-3, 3))
		var s = randf() * TAU
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				var q = p + v * t + Vector3.DOWN * 11.0 * t * t
				q.y = maxf(q.y, p.y)
				mi.global_transform = Transform3D(Basis(Vector3(0.4, 0.8, 0.3).normalized(), s + t * 7.0).scaled(Vector3.ONE * (1.0 - t * 1.2)), q), 0.0, 0.7, 0.7)
		tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ kıskaç
static func _grab(who: Node3D, dmg: float) -> void:
	var f = Yk.face(who)
	var tg = Combat.nearest_enemy(who, GRAB_R, f, 0.35)
	Sfx.play("clink", who.global_position + f, 0.55, 0.9)
	if tg == null:
		return
	if tg.has_method("apply_status"):
		tg.apply_status("bind", HOLD)
	tg.take_hit({"dmg": dmg * 0.4, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "bleed": 2.0})
	who.set_meta("hs_tut", tg.get_instance_id())
	var t0 = Time.get_ticks_msec()
	var keep = tg.global_position.y
	var tw = who.create_tween()
	tw.tween_method(func(_v: float):
		if is_instance_valid(who) and is_instance_valid(tg) and not tg.is_dead() and int(who.get_meta("hs_tut", 0)) == tg.get_instance_id() and Time.get_ticks_msec() - t0 < HOLD * 1000.0:
			var p: Vector3 = who.global_position + Yk.face(who) * 1.5
			tg.global_position = Vector3(p.x, keep, p.z), 0.0, 1.0, HOLD)


static func _crush(who: Node3D, dmg: float) -> void:
	var id = int(who.get_meta("hs_tut", 0))
	var h = instance_from_id(id) if id != 0 else null
	if not Yk.live(h):
		who.set_meta("hs_tut", 0)
		return
	for k in 3:
		Yk.after(who, 0.08 + k * 0.14, func():
			_to(who, 0.04 if k % 2 == 0 else 0.2, 0.07)
			if Yk.live(h):
				h.take_hit({"dmg": dmg * 0.34, "knock": 0.0, "kind": "light", "attacker": who, "dir": Vector3.ZERO, "hitstop": 0.03, "bleed": 2.0})
				Sfx.play("hit_heavy_weapon", h.global_position, 1.2, 0.5))
	Yk.after(who, 0.64, func():
		who.set_meta("hs_tut", 0)
		if Yk.live(h):
			var s = Vector3.UP.cross(Yk.face(who)).normalized()
			h.take_hit({"dmg": dmg * 0.5, "knock": 12.0, "launch": 3.0, "kind": "heavy", "attacker": who, "dir": s, "hitstop": 0.05}))


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	match i:
		0, 1, 3, 5:
			_to(who, OPEN_WIDE, 0.16)
		2:
			_to(who, 0.02, 0.1)
	who.set_meta("hs_t", Game.now() + 2.0)
	Yk.after(who, 2.1, func():
		if Game.now() >= float(who.get_meta("hs_t", 0.0)):
			_to(who, OPEN_IDLE, 0.25))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = Yk.face(who)
	var s = Vector3.UP.cross(f).normalized()
	var c: Vector3 = who.global_position + Vector3.UP * 1.2
	match i:
		0:
			_slash(c, -s + f * 0.3, s + f * 0.3, 2.3)
		1:
			_to(who, 0.02, 0.07)
			Sfx.play("clink", c + f, 0.62, 0.8)
			_slash(c + Vector3.UP * 0.2, Vector3.UP + f * 0.3, f - Vector3.UP * 0.7, 2.1)
		3:
			_to(who, 0.05, 0.07)
			_grab(who, dmg)
		4:
			_crush(who, dmg)
		5:
			_to(who, 0.02, 0.06)
			var g: Vector3 = Yk.gp(who.global_position + f * 2.0)
			_shards(g, 12, 6.0)
			Sfx.play("earth", g, 0.75, 0.9)
			Yk.shake(who, 0.45)
			Combat.hit_zone(who, who.global_position, f, 4.6, 16.0, 2.4, {"dmg": dmg * 0.55, "knock": 7.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.06, "melee": false})
