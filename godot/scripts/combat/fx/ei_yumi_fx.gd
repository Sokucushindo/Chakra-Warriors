extends RefCounted
## Ei Yumi (vatoz yayı; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/ei_yumi_fx.gd). Kanon (Narutopedia "Ray Bow", Seiren Funato, anime 242): vatoz biçimli yay, chakra oku atar.
## Sıyrık bile tehlikeli: ok chakra akışını bozar, yaralı yeri felç eder. Farklı kirişlere dokununca ok atıldıktan sonra yön değiştirir, savunmayı dolanır; ses yansımasıyla hedef bulur.
## Görünüş refs/ei_yumi: gri kanatlı vatoz gövde, ortada tutma deliği, kaburga oyukları, teller.
## Oyunda: ok geçerken 1 m'den sıyırsa da işler; 3 dokunuş chakrayı kapatır (2,5 sn). Hibiki, oyunun algılama sistemini açar: gizlenen ve duman ardındaki görülür. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const ID := "ei_yumi"
const BOW := "ei_yumi_yay"
const SPEED := 52.0
const GRAZE_R := 1.0
const SENSE_R := 34.0
const SENSE_T := 8.0

const ARROW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void fragment() {
	float e = abs(UV.x * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.45, 0.85, 0.9), vec3(0.92, 1.0, 1.0), 1.0 - e) * 1.5;
	ALPHA = 1.0 - smoothstep(0.3, 1.0, e);
}
"""

const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float m = 0.0;
	for (int i = 0; i < 3; i++) {
		float c = prog - float(i) * 0.14;
		if (c > 0.0) m = max(m, 1.0 - smoothstep(0.0, 0.012, abs(r - c)));
	}
	ALBEDO = vec3(0.55, 0.9, 0.95);
	ALPHA = m * (1.0 - prog) * 0.8;
	if (ALPHA < 0.01) discard;
}
"""


## Yay: tutuş z ekseninde (Yumi yayıyla aynı çerçeve), ok yönü +X, kanatlar ±Z
static func build_bow(b: MB) -> void:
	var g = Color(0.52, 0.54, 0.58)
	var d = Color(0.2, 0.21, 0.24)
	var o := PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.22, 0.18), Vector2(0.13, 0.42), Vector2(-0.02, 0.62), Vector2(-0.16, 0.76),
		Vector2(-0.05, 0.5), Vector2(-0.06, 0.3), Vector2(-0.13, 0.15), Vector2(-0.1, 0.0), Vector2(-0.13, -0.15), Vector2(-0.06, -0.3), Vector2(-0.05, -0.5),
		Vector2(-0.16, -0.76), Vector2(-0.02, -0.62), Vector2(0.13, -0.42), Vector2(0.22, -0.18)])
	var xf = Transform3D(Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK), Vector3.ZERO)
	b.add_slab(MB.hole(o, Vector2(0.05, 0.0), 0.075), 0.022, g, xf, Callable(), d)
	for s in [-1.0, 1.0]:
		for k in 3:   # kaburga oyukları (kaynaktaki koyu yarıklar)
			var z = s * (0.2 + k * 0.1)
			var r := PackedVector2Array([Vector2(0.14 - k * 0.04, z), Vector2(0.04 - k * 0.03, z + s * 0.035), Vector2(-0.0 - k * 0.03, z - s * 0.01)])
			b.add_slab(r, 0.026, d, xf)
	b.add("cyl", Vector3(0.05, 0, 0), Vector3(0.036, 0.16, 0.036), Color(0.3, 0.27, 0.24), Vector3(90, 0, 0), 8)
	for z in [-0.12, 0.0, 0.12]:   # üç kiriş
		var y = z * 0.1
		b.add("box", Vector3(-0.15, y, 0), Vector3(0.003, 0.003, 1.42 - absf(z) * 1.2), Color(0.86, 0.88, 0.9))
	b.add("box", Vector3(-0.1, 0, 0.72), Vector3(0.12, 0.02, 0.02), g)
	b.add("box", Vector3(-0.1, 0, -0.72), Vector3(0.12, 0.02, 0.02), g)


## Sağ eldeki küçük chakra oku (eşya simgesi de bu)
static func build_hand(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.16), Vector3(0.012, 0.42, 0.012), Color(0.62, 0.9, 0.95), Vector3(90, 0, 0), 5)


static func _arrow_vis() -> Node3D:
	var root = Node3D.new()
	var q = MeshInstance3D.new()
	var m = QuadMesh.new()
	m.size = Vector2(0.16, 1.0)
	q.mesh = m
	q.material_override = Yk.mat("ei_ok", ARROW_SH)
	q.rotation.x = PI * 0.5
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	var q2 = q.duplicate()
	q2.rotation = Vector3(PI * 0.5, 0, PI * 0.5)
	root.add_child(q2)
	return root


static func _from(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, BOW)
	return n.to_global(Vector3(0.28, 0, 0)) if n != null else who.global_position + Vector3.UP * 1.4 + who.face_dir() * 0.5


## Chakra akışı bozulur: yavaşlar, chakra kaçar; 3 dokunuşta chakra noktaları kapanır
static func disrupt(who: Node3D, t: Node3D) -> void:
	if not t.has_method("apply_status"):
		return
	var now = Game.now()
	var n = (int(t.get_meta("ei_n", 0)) if now - float(t.get_meta("ei_t", -99.0)) < 6.0 else 0) + 1
	t.set_meta("ei_t", now)
	t.apply_status("slow", 1.6)
	if t.get("chakra") != null:
		t.chakra = maxf(0.0, float(t.chakra) - float(t.max_chakra) * 0.04)
	if n >= 3:
		n = 0
		t.apply_status("sealed", 2.5)
		Combat.popup_text(t.global_position + Vector3.UP * 2.3, "Chakra felci!", Color(0.6, 0.92, 0.96))
	t.set_meta("ei_n", n)
	if is_instance_valid(who):
		U.credit(who, t)


static func _shoot(who: Node3D, dir: Vector3, tg: Node3D, turn: float, dmg: float) -> void:
	var from = _from(who)
	var grazed := {}
	var born = Game.now()
	var tick = func(pr: Projectile, dt: float) -> void:
		if turn > 0.0 and U.alive(tg) and Game.now() - born > 0.08:   # kiriş dokunuşu okun yönünü değiştirir
			var spd = pr.vel.length()
			pr.vel = pr.vel.normalized().slerp((U.chest(tg) - pr.global_position).normalized(), minf(1.0, dt * turn)).normalized() * spd
		for f in pr.get_tree().get_nodes_in_group("fighters"):
			if Combat.hostile(who, f) and not f.is_dead() and not grazed.has(f.get_instance_id()) and Combat.capsule_hit(pr.global_position, f, GRAZE_R):
				grazed[f.get_instance_id()] = true
				disrupt(who, f)
	var cb = func(_pos: Vector3, _t: Node3D) -> void:
		pass
	U.fire(who, from, dir * SPEED, {"g": 0.0, "r": 0.12, "life": 1.5, "vis": _arrow_vis(), "tick": tick, "hit": cb,
		"info": {"dmg": dmg, "knock": 1.0, "kind": "light", "hitstop": 0.0, "element": ""}})
	Sfx.play("clink", from, 0.55, 0.3)
	Sfx.play("whoosh", from, 2.1, 0.3)


static func _ring(p: Vector3, size: float, t: float) -> void:
	var holder = Node3D.new()
	Yk.root().add_child(holder)
	holder.global_position = p
	holder.rotation.x = -PI * 0.5
	var q = QuadMesh.new()
	q.size = Vector2.ONE * size
	var mi = MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = Yk.mat("ei_halka", RING_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size
	holder.add_child(mi)
	var tw = holder.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("prog", v), 0.0, 1.0, t)
	tw.tween_callback(holder.queue_free)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 3 and who is CharacterBody3D:
		var f: Vector3 = who.face_dir()
		who.velocity.x = -f.x * 7.5
		who.velocity.z = -f.z * 7.5
		who.velocity.y = 6.5


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var from = _from(who)
	var d: Vector3 = (aim - from).normalized()
	match i:
		0, 1, 3:
			_shoot(who, d, tg, 0.0, dmg * 0.7)
		2:   # yandan açılır, sonra hedefe kıvrılır: önden tutulan savunmayı dolanır
			var sgn = -1.0 if randf() < 0.5 else 1.0
			_shoot(who, d.rotated(Vector3.UP, sgn * 0.95), tg, 7.0, dmg * 0.95)
		4:   # kiriş yankısı: algılama açılır
			Combat.start_sensing(who, SENSE_R, SENSE_T)
			_ring(who.global_position + Vector3.UP * 1.2, SENSE_R * 0.8, 0.7)
			Combat.popup_text(who.global_position + Vector3.UP * 2.4, "Hibiki", Color(0.6, 0.92, 0.96))
		5:
			for k in 5:
				Yk.after(who, k * 0.09, func():
					var a = (float(k) - 2.0) * 0.32
					var t2 = U.target_of(who)
					var q = (U.aim_at(who, t2) - _from(who)).normalized()
					_shoot(who, q.rotated(Vector3.UP, a), t2, 5.5, dmg * 0.42))
