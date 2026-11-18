extends RefCounted
## Chakra oltası (Chakura Tsurizao, kanonda adsız; hedef: res://scripts/combat/fx/chakra_oltasi_fx.gd). Kanon (Narutopedia "Urashiki Ōtsutsuki", Boruto anime 128):
## chakradan esnek olta; uzayan ip ve kanca. Kanca kalkan ve bedeni delip hedefin chakrasını çeker; Urashiki oltayla Chōjūrō'nun kılıcını da karşılar, kancayı havada yönlendirir.
## Ref refs/chakra_oltasi: parlak kızıl ince sap ve ip, çekilen turuncu chakra topu. Efsane: satılmaz, sahibi var.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/chakra_oltasi_anim.gd")
const Z = preload("res://scripts/combat/fx/zincir_uc.gd")

const TIP := Vector3(0, 0, 1.3)
const COST := 0.05
const DRAIN := 30.0

const GLOW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float p = 0.82 + 0.18 * sin(TIME * 7.0 + UV.y * 9.0);
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.72, 0.72), 0.2) * p * 1.35;
}
"""

const ORB_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.68 + 0.14 * sin(a * 5.0 + TIME * 8.0) + 0.08 * sin(a * 11.0 - TIME * 6.0);
	float r = length(p);
	if (r > e) discard;
	ALBEDO = mix(vec3(1.0, 0.86, 0.6), vec3(1.0, 0.32, 0.14), r / e) * 1.7;
	ALPHA = 0.9;
}
"""


static func _glow() -> ShaderMaterial:
	return Kit.shader_mat("olta_isik", GLOW_SH)


static func build(b: MB) -> void:
	var red = Color(0.72, 0.1, 0.16)
	b.add("cyl", Vector3(0, 0, 0.5), Vector3(0.022, 1.6, 0.022), red, Vector3(90, 0, 0), 6)
	b.add("cyl", Vector3(0, 0, -0.14), Vector3(0.036, 0.26, 0.036), Color(0.5, 0.06, 0.1), Vector3(90, 0, 0), 8)


static func _hook() -> Mesh:
	return Kit.cached_mesh("olta_kanca", func():
		var b = MB.new()
		var c = Color(1.0, 0.25, 0.28)
		var n = 8
		var prev = Vector3(0, 0, 0)
		for k in range(1, n + 1):
			var a = float(k) / n * PI * 1.25
			var q = Vector3(0, 0.05 * (1.0 - cos(a)), 0.05 * sin(a) + float(k) / n * 0.06)
			var y = q - prev
			var yn = y.normalized()
			var xn = yn.cross(Vector3.RIGHT).normalized()
			b.add_xf("cyl", Transform3D(Basis(xn * 0.012, y * 1.1, xn.cross(yn) * 0.012), (q + prev) * 0.5), c, 5)
			prev = q
		return b.build(_glow()))


static func _link() -> Mesh:
	return Kit.cached_mesh("olta_ip", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.1, 0.009, 0.009), Color(0.95, 0.14, 0.2))
		return b.build(_glow()))


static func attach(node: Node3D, owner_body: Node3D) -> void:
	var c = Z.new()
	c.name = "OltaIp"
	node.add_child(c)
	c.setup(owner_body, node, TIP, _hook(), _link(), 0.9)


static func _line(who: Node3D):
	var n = U.weapon_node(who, "chakra_oltasi")
	return n.get_node_or_null("OltaIp") if n != null else null


static func _goal(who: Node3D, tg: Node3D, r: float) -> Vector3:
	var f: Vector3 = who.face_dir()
	if U.alive(tg) and tg.global_position.distance_to(who.global_position) <= r:
		return U.chest(tg)
	return who.global_position + Vector3.UP * 1.2 + f * r


## Kanca hedefe kıvrılarak gider (kanon: yolu yönlendirilir), vuruştan sonra geri çekilir
static func _cast(who: Node3D, i: int, tg: Node3D) -> void:
	var c = _line(who)
	if c == null:
		return
	var hit = float(A.HIT[i])
	var T = hit + 0.34
	var hk = hit / T
	var r = 9.0 if i == 5 else (6.5 if i == 3 else 5.5)
	var path = func(k: float, a: Vector3) -> Vector3:
		if not is_instance_valid(who):
			return a
		var f: Vector3 = who.face_dir()
		var s: Vector3 = Vector3.UP.cross(f).normalized()
		var goal = _goal(who, tg, r)
		if i == 1:
			var e = lerpf(2.2, -0.9, minf(k / hk, 1.0))
			return who.global_position + Vector3.UP * 1.2 + (f * cos(e) + s * sin(e)) * 4.0
		if k < hk:
			var u = k / hk
			return a.lerp(goal, u * u) + (s * sin(u * PI * 2.0) * 0.8 + Vector3.UP * sin(u * PI) * 0.8) * (1.0 - u)
		return goal.lerp(a, (k - hk) / (1.0 - hk))
	c.drive(T, path)


## Çekilen chakra: turuncu top ipten ele akar (Urashiki_Steals_Chakra.png)
static func _orb(who: Node3D, from: Vector3) -> void:
	var q = Kit.quad(Kit.scene(), 0.8, Kit.shader_mat("olta_top", ORB_SH))
	q.global_position = from
	var step = func(v: float) -> void:
		if is_instance_valid(q) and is_instance_valid(who):
			q.global_position = from.lerp(U.bone_pos(who, "LeftHand"), v * v)
	var tw = q.create_tween()
	tw.tween_method(step, 0.0, 1.0, 0.5)
	tw.tween_callback(q.queue_free)


static func _drain(who: Node3D, t: Node3D, amount: float) -> void:
	if t.get("chakra") != null:
		t.chakra = maxf(0.0, float(t.chakra) - amount)
	if t.has_method("apply_status"):
		t.apply_status("sealed", 1.2)
	if who.get("chakra") != null and who.get("max_chakra") != null:
		who.chakra = minf(float(who.max_chakra), float(who.chakra) + amount * 0.7)


## Combat.speed_dodge: Sao-uke duruşunda önden gelen yakın darbe karşılanır
static func parry(t: Node3D, info: Dictionary) -> bool:
	if Game.now() >= float(t.get_meta("olta_uke", 0.0)) or not info.get("melee", false) or info.get("sure", false):
		return false
	var atk = info.get("attacker")
	if atk == null or not is_instance_valid(atk) or not t.has_method("face_dir"):
		return false
	var to: Vector3 = atk.global_position - t.global_position
	to.y = 0.0
	if to.length() > 0.05 and t.face_dir().dot(to.normalized()) < 0.1:
		return false
	t.remove_meta("olta_uke")
	Sfx.play("clash", t.global_position + Vector3.UP, 1.5, 0.6)
	Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Karşılandı", Color(1.0, 0.7, 0.7))
	return true


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var tg = U.target_of(who)
	U.face(who, U.aim_at(who, tg))
	match i:
		0, 1, 3, 5:
			_cast(who, i, tg)
			Sfx.play("whoosh", who.global_position + Vector3.UP, 1.8, 0.4)
		2:
			who.set_meta("olta_uke", Game.now() + 0.55)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	match i:
		4:   # Amenosubaruboshinomikoto: kanca yağmuru
			var m = _hook()
			var from: Vector3 = U.bone_pos(who, "RightHand")
			var aim = U.aim_at(who, tg)
			for k in 5:
				var vis = Node3D.new()
				var mi = MeshInstance3D.new()
				mi.mesh = m
				mi.rotation.y = PI
				mi.scale = Vector3.ONE * 1.5
				vis.add_child(mi)
				var to = aim + Vector3(randf_range(-1, 1), randf_range(-0.4, 0.8), randf_range(-1, 1)) * 0.9
				var on_hit = func(_p: Vector3, t: Node3D) -> void:
					if t != null and is_instance_valid(t) and is_instance_valid(who):
						_drain(who, t, 3.0)
				U.fire(who, from, U.solve(from, to, 46.0, 0.0), {"r": 0.13, "life": 0.9, "vis": vis, "hit": on_hit, "info": {"dmg": dmg * 0.3, "knock": 0.5, "kind": "light", "hitstop": 0.0}})
		5:
			var free_c = U.pay(who, COST)
			if U.alive(tg) and tg.global_position.distance_to(who.global_position) <= 9.2:
				var p = U.chest(tg)
				tg.take_hit({"dmg": dmg * 0.9, "knock": 0.0, "kind": "light", "sure": true, "melee": false, "attacker": who, "dir": who.face_dir(), "hitstop": 0.04})
				U.credit(who, tg)
				if free_c:
					_drain(who, tg, DRAIN)
					tg.apply_status("bind", 0.9)
					_orb(who, p)
					Sfx.play("absorb", p, 1.1, 0.6)
