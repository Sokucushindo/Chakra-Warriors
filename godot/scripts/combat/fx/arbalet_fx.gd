extends RefCounted
## Ōyumi (arbalet): model, gerçekten kurulan kiriş + bükülen yay kolu, cıvatalar. Ortak efekt yok.
## Kanon (Narutopedia "Crossbow" kullanıcıları ve geçişleri; hepsi metin, yakın çekim görseli bulunamadı):
##  - Inari ve Dalga Ülkesi halkı: Gatō'nun adamlarını arbaletle durdurur (Tool sayfasında manga + anime).
##  - Hoshigakure ninjaları sık kullanır; Akahoshi ölümcül isabetli; Sumaru arbalet + halatla Şeytan Geçidi'ni aşar.
##  - Tekuno Kanden (Konoha) patlayıcı etiketli mermi atan arbalet çağırır. Gökyüzü Ülkesi ninjaları kunai atan arbalet tuzağı kurar.
##  - Maruta, Nan, Mubi, Tenten de kullanır. Ağırlıklı olarak ANİME.
## Zayıflık: tek atış; boşken tetik "tık" eder, kurmak adım ister. Kurma hareketi gerçek arbaletten, kanon değil.
## Silah uzayı: kabza z=0, +Z namlu, +Y üst; yay kolları X ekseninde, z=0.46.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const SPEED := 78.0
const GRAV := 3.0
const PASSIVE := 2.4     # kombo dışında kendiliğinden yeniden kurulma süresi
const ROPE_RANGE := 24.0
const FIRE_STEPS := [0, 2, 4, 5]

const WOOD := Color(0.36, 0.23, 0.14)
const WOOD_D := Color(0.24, 0.15, 0.1)
const IRON := Color(0.32, 0.33, 0.36)
const CORD := Color(0.86, 0.82, 0.7)
const ROPE := Color(0.66, 0.56, 0.38)

static var _c := {}

const BLAST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float seed_k = 0.0;
void vertex() {
	float s = 3.4 * (0.35 + 0.65 * sqrt(prog));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= s;
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float a = atan(q.y, q.x) + seed_k * 6.283;
	float r = length(q);
	float teeth = 0.6 + 0.22 * abs(sin(a * 3.5)) + 0.16 * abs(sin(a * 8.0 + 1.3));
	float edge = 1.0 - smoothstep(teeth * (1.0 - prog * 0.12) - 0.03, teeth * (1.0 - prog * 0.12), r);
	float hole = smoothstep(prog * 0.75 - 0.08, prog * 0.75 + 0.02, r);   // içten boşalır: dolu disk kalmaz
	ALBEDO = mix(vec3(1.0, 0.86, 0.45), vec3(1.0, 0.34, 0.08), smoothstep(0.1, 0.85, r + prog * 0.3));
	ALPHA = edge * hole * (1.0 - prog * prog);
}
"""


class Rig extends Node3D:
	const U2 = preload("res://scripts/combat/fx/uzak_nisan.gd")
	const SPAN := 0.42
	const PROD_Z := 0.46
	const NUT := Vector3(0.0, 0.04, 0.1)
	const SEGS := 6

	var who: Node3D
	var prod: MultiMesh
	var cord: MultiMesh
	var bolt: MeshInstance3D
	var c := 1.0          # kuruluk (1 kurulu)
	var from_c := 1.0
	var t_c := -1.0
	var dur_c := 0.4
	var vib := -1.0

	static func prod_pt(s: float, k: float) -> Vector3:
		var u = absf(s)
		return Vector3(s * SPAN * (1.0 - 0.08 * k * u * u), 0.02, PROD_Z - (0.04 + 0.1 * k) * u * u)

	static func seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
		var y = b - a
		if y.length() < 0.0005:
			y = Vector3(0, 0, 0.0005)
		var yn = y.normalized()
		var xn = yn.cross(Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).normalized()
		return Transform3D(Basis(xn * w, y * 1.05, xn.cross(yn) * w), (a + b) * 0.5)

	func setup(w: Node3D, prod_mesh: Mesh, cord_mesh: Mesh, bolt_mesh: Mesh) -> void:
		who = w
		name = "ArbaletRig"
		process_priority = 60
		prod = _mm(prod_mesh, SEGS * 2)
		cord = _mm(cord_mesh, 2)
		bolt = MeshInstance3D.new()
		bolt.mesh = bolt_mesh
		bolt.position = Vector3(0, 0.046, 0.1)
		add_child(bolt)
		_pose(0.0)

	func _mm(mesh: Mesh, n: int) -> MultiMesh:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = n
		var mi = MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.custom_aabb = AABB(Vector3(-1.2, -1.2, -1.2), Vector3(2.4, 2.4, 2.4))
		add_child(mi)
		return mm

	func _pose(off: float) -> void:
		for side in 2:
			var sg = 1.0 if side == 0 else -1.0
			for k in SEGS:
				var u0 = float(k) / SEGS
				var u1 = float(k + 1) / SEGS
				prod.set_instance_transform(side * SEGS + k, seg_xf(prod_pt(sg * u0, c), prod_pt(sg * u1, c), lerpf(0.05, 0.022, u1)))
		var tip_r = prod_pt(1.0, c)
		var tip_l = prod_pt(-1.0, c)
		var mid = Vector3(0.0, lerpf(tip_r.y, NUT.y, c), lerpf(tip_r.z, NUT.z, c) + off)
		cord.set_instance_transform(0, seg_xf(tip_r, mid, 0.006))
		cord.set_instance_transform(1, seg_xf(mid, tip_l, 0.006))

	func cock(dur: float) -> void:
		from_c = c
		t_c = 0.0
		dur_c = maxf(dur, 0.05)

	func shot() -> void:
		c = 0.0
		t_c = -1.0
		vib = 0.0
		bolt.visible = false
		_pose(0.0)

	func _process(dt: float) -> void:
		if who == null or not is_instance_valid(who):
			return
		var parent_vis = get_parent() as Node3D
		if parent_vis != null and not parent_vis.is_visible_in_tree():
			return
		if t_c < 0.0 and c < 0.999 and Game.now() >= float(who.get_meta("arb_ready", 0.0)):
			cock(0.3)   # kombo dışında kendiliğinden yeniden kurar
		if t_c >= 0.0:
			t_c += dt
			c = lerpf(from_c, 1.0, smoothstep(0.0, 1.0, minf(t_c / dur_c, 1.0)))
			_pose(0.0)
			if t_c >= dur_c:
				t_c = -1.0
				c = 1.0
				bolt.visible = true
				Sfx.play("click", global_position, 0.7, 0.4)
		elif vib >= 0.0:
			vib += dt
			_pose(0.035 * exp(-vib * 9.0) * sin(vib * 95.0))
			if vib > 0.6:
				vib = -1.0
				_pose(0.0)


# ------------------------------------------------------------------ modeller
static func _seg(b: MB, p: Vector3, q: Vector3, w: float, col: Color) -> void:
	b.add_xf("cyl", Rig.seg_xf(p, q, w), col, 6)


## Gövde: dipçik, tüfek gövdesi, ceviz (nut), tetik kolu, üzengi. Yay kolu ve kiriş ayrı (düzenek).
static func build_body(b: MB) -> void:
	b.add("box", Vector3(0, 0, 0.11), Vector3(0.04, 0.042, 0.8), WOOD)   # gövde z -0.29..0.51
	b.add("box", Vector3(0, 0.024, 0.28), Vector3(0.012, 0.006, 0.44), WOOD_D)   # cıvata oluğu
	b.add("box", Vector3(0, -0.02, -0.27), Vector3(0.05, 0.11, 0.17), WOOD_D)    # dipçik
	b.add("box", Vector3(0, -0.075, -0.35), Vector3(0.05, 0.05, 0.04), WOOD_D.darkened(0.2))
	for z in [0.42, 0.5]:
		b.add("box", Vector3(0, 0, z), Vector3(0.05, 0.05, 0.016), IRON)
	b.add("cyl", Rig.NUT - Vector3(0, 0.012, 0), Vector3(0.04, 0.03, 0.04), Color(0.82, 0.78, 0.66), Vector3(0, 0, 90), 10)   # ceviz
	b.add("box", Vector3(0, -0.06, -0.03), Vector3(0.012, 0.09, 0.016), IRON, Vector3(14, 0, 0))    # tetik kolu
	# üzengi: burundaki demir halka (ayak burada)
	for sx in [-1.0, 1.0]:
		_seg(b, Vector3(sx * 0.02, 0, 0.5), Vector3(sx * 0.075, 0, 0.59), 0.012, IRON)
	_seg(b, Vector3(-0.075, 0, 0.59), Vector3(0.075, 0, 0.59), 0.012, IRON)


## Dururken tam model (kurulu)
static func build_full(b: MB) -> void:
	build_body(b)
	var n = 12
	for k in n:
		var s0 = lerpf(-1.0, 1.0, float(k) / n)
		var s1 = lerpf(-1.0, 1.0, float(k + 1) / n)
		_seg(b, Rig.prod_pt(s0, 1.0), Rig.prod_pt(s1, 1.0), lerpf(0.05, 0.022, maxf(absf(s0), absf(s1))), WOOD_D)
	_seg(b, Rig.prod_pt(1.0, 1.0), Rig.NUT, 0.006, CORD)
	_seg(b, Rig.NUT, Rig.prod_pt(-1.0, 1.0), 0.006, CORD)
	var bb = MB.new()
	build_bolt(bb)
	b.add_mesh(bb, Transform3D(Basis.IDENTITY, Vector3(0, 0.046, 0.1)))


## Cıvata: kısa kalın, deri kanat, demir uç. Dip z=0, uç z=0.42
static func build_bolt(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.19), Vector3(0.016, 0.38, 0.016), Color(0.3, 0.22, 0.15), Vector3(90, 0, 0), 6)
	b.add("cone", Vector3(0, 0, 0.395), Vector3(0.03, 0.07, 0.03), IRON, Vector3(90, 0, 0), 4)
	for sg in [0.0, PI * 0.5]:
		var o = PackedVector2Array([Vector2(-0.03, 0.02), Vector2(0.03, 0.02), Vector2(0.008, 0.1), Vector2(-0.008, 0.1)])
		b.add_slab(o, 0.003, Color(0.5, 0.2, 0.13), Transform3D(Basis(Vector3.BACK, sg), Vector3.ZERO))


## Patlayıcı etiketli cıvata (Tekuno_weapons.png: krem kâğıt, kızıl kenar, koyu mühür)
static func _tag_bolt(b: MB) -> void:
	build_bolt(b)
	b.add("box", Vector3(0, 0.0, 0.25), Vector3(0.004, 0.058, 0.13), Color(0.76, 0.2, 0.17))
	b.add("box", Vector3(0.0028, 0.0, 0.25), Vector3(0.002, 0.044, 0.112), Color(0.93, 0.89, 0.76))
	b.add("box", Vector3(0.0042, 0.0, 0.25), Vector3(0.001, 0.012, 0.062), Color(0.1, 0.09, 0.09))


## Halatlı cıvata: gövdede sarılı halat
static func _rope_bolt(b: MB) -> void:
	build_bolt(b)
	for k in 5:
		b.add("cyl", Vector3(0, 0, 0.14 + k * 0.016), Vector3(0.028, 0.012, 0.028), ROPE, Vector3(90, 0, 0), 8)


static func _mesh(key: String, fn: Callable) -> Mesh:
	if not _c.has(key):
		var b = MB.new()
		fn.call(b)
		_c[key] = b.build(LazyFx.g("Props").toon())
	return _c[key]


static func _bolt_mesh() -> Mesh:
	return _mesh("bolt", func(b: MB): build_bolt(b))


static func _tag_mesh() -> Mesh:
	return _mesh("tag", func(b: MB): _tag_bolt(b))


static func _rope_mesh() -> Mesh:
	return _mesh("ropeb", func(b: MB): _rope_bolt(b))


static func _unit(col: Color) -> Mesh:
	return _mesh("cyl:%s" % col.to_html(), func(b: MB): b.add("cyl", Vector3.ZERO, Vector3.ONE, col, Vector3.ZERO, 6))


static func rig_of(who: Node3D) -> Rig:
	var n = U.weapon_node(who, "arbalet")
	if n == null or not (n is MeshInstance3D):
		return null
	var r = n.get_node_or_null("ArbaletRig")
	if r != null:
		return r
	var rig = Rig.new()
	n.add_child(rig)
	(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("arbalet_govde")
	rig.setup(who, _unit(WOOD_D), _unit(CORD), _bolt_mesh())
	return rig


static func _muzzle(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, "arbalet")
	return n.to_global(Vector3(0, 0.05, 0.54)) if n != null else who.global_position + Vector3.UP * 1.35 + who.face_dir() * 0.8


static func _vis(mesh: Mesh, half: float) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.rotation.y = PI
	mi.position = Vector3(0, 0, half)
	root.add_child(mi)
	return root


static func _scene() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


## Kıymık / yanık kâğıt / kıvılcım parçaları
static func _bits(p: Vector3, n: int, cols: Array, spd: float, life: float) -> void:
	var root = _scene()
	if root == null:
		return
	for k in n:
		var col: Color = cols[k % cols.size()]
		var m = _mesh("bit:%s" % col.to_html(), func(b: MB): b.add("box", Vector3.ZERO, Vector3(0.03, 0.006, 0.04), col))
		var mi = MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = p
		var v = Vector3(randf_range(-1, 1), randf_range(0.2, 1.3), randf_range(-1, 1)) * spd * randf_range(0.5, 1.0)
		var sp = Vector3(randf_range(-16, 16), randf_range(-16, 16), randf_range(-16, 16))
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				mi.global_position = p + v * t + Vector3.DOWN * 6.0 * t * t
				mi.rotation = sp * t, 0.0, life, life)
		tw.tween_callback(mi.queue_free)


## Patlayıcı etiket: kendi alev dişli parlaması + yanık kâğıt; alan hasarı atan adına (oyuncu ve düşman aynı)
static func blast(who: Node3D, p: Vector3, dmg: float) -> void:
	var root = _scene()
	if root == null:
		return
	if not _c.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_c["mesh:quad"] = q
	if not _c.has("mat:blast"):
		var s = Shader.new()
		s.code = BLAST_SH
		var m = ShaderMaterial.new()
		m.shader = s
		_c["mat:blast"] = m
	for k in 2:
		var mi = MeshInstance3D.new()
		mi.mesh = _c["mesh:quad"]
		mi.material_override = _c["mat:blast"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 4.0
		root.add_child(mi)
		mi.global_position = p + Vector3.UP * 0.1 * k
		mi.set_instance_shader_parameter("seed_k", randf())
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.05)
		tw.tween_method(func(v: float):
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("prog", v), 0.0, 1.0, 0.34)
		tw.tween_callback(mi.queue_free)
	_bits(p, 12, [Color(0.93, 0.89, 0.76), Color(0.76, 0.2, 0.17), Color(0.12, 0.1, 0.1), Color(1.0, 0.6, 0.15)], 5.0, 0.6)
	Sfx.play("boom", p, randf_range(1.1, 1.25), 0.75)
	if is_instance_valid(who):
		Combat.hit_sphere(who, p, 2.7, {"dmg": dmg, "knock": 9.0, "launch": 3.0, "kind": "heavy", "burn": 1.2, "hitstop": 0.05, "melee": false})
		if who is Player and Game.world:
			Game.world.env.add_shake(0.35)


static func _bolt(who: Node3D, from: Vector3, to: Vector3, dmg: float, mesh: Mesh, o := {}) -> Projectile:
	var cb: Callable = o.get("hit", Callable())
	var dir = (to - from).normalized()
	var land = func(pos: Vector3, tgt: Node3D) -> void:
		_bits(pos, 4, [Color(0.3, 0.22, 0.15), IRON], 2.6, 0.36)
		if tgt != null and is_instance_valid(tgt):
			Sfx.play("hit_blade", pos, 0.9, 0.8)
			if bool(o.get("pin", true)):
				var mi = MeshInstance3D.new()
				mi.mesh = mesh
				U.pin(mi, tgt, pos - dir * 0.3, dir, 3.0)
		if cb.is_valid():
			cb.call(pos, tgt)
	var half = float(o.get("half", 0.21))
	return U.fire(who, from, U.solve(from, to, float(o.get("speed", SPEED)), GRAV), {"g": GRAV, "r": 0.13, "life": float(o.get("life", 1.8)), "stick": bool(o.get("stick", true)),
		"hit": land, "tick": o.get("tick", Callable()), "vis": _vis(mesh, half),
		"info": {"dmg": dmg, "knock": float(o.get("knock", 5.0)), "kind": str(o.get("kind", "light")), "hitstop": 0.04}})


## Sumaru'nun halatı: namludan cıvataya gerilir. Düşmanı bağlar ve çeker; sert yüzeye saplanırsa atanı oraya çeker (geçit aşma).
static func _rope_shot(who: Node3D, from: Vector3, to: Vector3, dmg: float) -> void:
	var line = MeshInstance3D.new()
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.016, 1.0, 0.016), ROPE, Vector3.ZERO, 5)
	line.mesh = b.build(LazyFx.g("Props").toon())
	who.get_tree().current_scene.add_child(line)
	var guard = line.create_tween()   # atan ölürse halat sahnede kalmasın
	guard.tween_interval(4.0)
	guard.tween_callback(line.queue_free)
	var stretch = func(a: Vector3, c: Vector3) -> void:
		if is_instance_valid(line):
			var dv = c - a
			if dv.length() > 0.05:
				line.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dv.normalized())) * Basis.from_scale(Vector3(1, dv.length(), 1)), (a + c) * 0.5)
	var holder = [null]
	var tick = func(pr: Projectile, _dt: float) -> void:
		if is_instance_valid(who):
			stretch.call(_muzzle(who), pr.global_position)
	var end_rope = func(delay: float) -> void:
		who.get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(line):
				line.queue_free())
	var on = func(pos: Vector3, tgt: Node3D) -> void:
		if not is_instance_valid(who):
			if is_instance_valid(line):
				line.queue_free()
			return
		if tgt != null and is_instance_valid(tgt):
			if tgt.has_method("apply_status"):
				tgt.apply_status("bind", 1.5)
			if tgt is CharacterBody3D:
				tgt.velocity = (who.global_position - tgt.global_position).normalized() * 10.0 + Vector3.UP * 2.0
			stretch.call(_muzzle(who), U.chest(tgt))
			end_rope.call(0.55)
			return
		var pr = holder[0]
		var spent = pr != null and is_instance_valid(pr) and float(pr.life) <= 0.0   # menzil bitti: tutunacak yer yok
		var dist = who.global_position.distance_to(pos)
		if spent or dist < 2.5:
			end_rope.call(0.1)
			return
		var a: Vector3 = who.global_position
		var flat = a - pos
		flat.y = 0.0
		var goal: Vector3 = pos + (flat.normalized() * 0.9 if flat.length() > 0.05 else Vector3.ZERO)
		goal.y = maxf(pos.y - 1.0, Game.ground_height(goal.x, goal.z) + 0.05)   # halatın ucunda asılı varır; uçurum üstünden geçebilir
		var dur = clampf(dist / 26.0, 0.2, 0.75)
		var ex = [who.get_rid()] if who is CollisionObject3D else []
		var tw = who.create_tween()
		tw.tween_method(func(k: float):
			if not is_instance_valid(who):
				return
			var q = a.lerp(goal, k * k * (3.0 - 2.0 * k))
			var cur: Vector3 = who.global_position
			var ray = PhysicsRayQueryParameters3D.create(cur + Vector3.UP, q + Vector3.UP, 1, ex)
			if who.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():   # yolda duvar varsa orada durur
				who.global_position = q
			if who is CharacterBody3D:
				who.velocity = Vector3.ZERO
			stretch.call(_muzzle(who), pos), 0.0, 1.0, dur)
		tw.tween_callback(func():
			if is_instance_valid(line):
				line.queue_free())
		Sfx.play("chain", a, 0.8, 0.5)
	holder[0] = _bolt(who, from, to, dmg, _rope_mesh(), {"hit": on, "tick": tick, "life": ROPE_RANGE / SPEED, "knock": 1.0})


# ------------------------------------------------------------------ kombo bağlantıları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	var rig = rig_of(who)
	if rig == null:
		return
	match i:
		1:   # Ashi-gake: üzengiye basınca kirişi çeker
			_recock(who, rig, 0.52, 0.2)
		3:   # Dai-uchi: darbenin arkasından kurar
			_recock(who, rig, 0.45, 0.3)
		5:   # Kunai-zume: hızlı kurma, oluğa kunai
			_recock(who, rig, 0.42, 0.14)
	match i:
		2: rig.bolt.mesh = _tag_mesh()
		4: rig.bolt.mesh = _rope_mesh()
		5: rig.bolt.mesh = CharacterModel.weapon_mesh("kunai")
		_: rig.bolt.mesh = _bolt_mesh()


static func _recock(who: Node3D, rig: Rig, dur: float, delay: float) -> void:
	who.set_meta("arb_ready", Game.now() + delay + dur)
	who.get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(rig):
			rig.cock(dur))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	if not i in FIRE_STEPS:
		if i == 1:
			Sfx.play("hit_heavy", who.global_position, 1.3, 0.35)   # ayak üzengiye iner
		return
	var rig = rig_of(who)
	var from = _muzzle(who)
	if Game.now() < float(who.get_meta("arb_ready", 0.0)) or (rig != null and rig.c < 0.95):
		Sfx.play("click", from, 0.6, 0.7)   # boş: yalnız tetik tıkırtısı
		if who is Player:
			Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Kurulu değil", Color(0.85, 0.82, 0.7))
		return
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	who.set_meta("arb_ready", Game.now() + PASSIVE)
	if rig != null:
		rig.shot()
	Sfx.play("clash", from, 0.55, 0.4)
	Sfx.play("whoosh", from, 1.7, 0.45)
	if who is Player and Game.world:
		Game.world.env.add_shake(0.12)
	match i:
		0:   # Ichi-ya: isabetli, sert (Akahoshi)
			_bolt(who, from, aim, dmg * 1.35, _bolt_mesh(), {"knock": 7.0})
		2:   # Bakufu-ya: saplanır, kısa süre sonra etiket patlar (Tekuno Kanden)
			var boom = func(pos: Vector3, tgt: Node3D) -> void:
				var stuck = tgt
				who.get_tree().create_timer(0.7).timeout.connect(func():
					var at: Vector3 = U.chest(stuck) if U.alive(stuck) else pos
					blast(who, at, dmg * 1.1))
			_bolt(who, from, aim, dmg * 0.4, _tag_mesh(), {"hit": boom, "knock": 1.0})
		4:   # Nawa-ya (Sumaru)
			_rope_shot(who, from, aim, dmg * 0.5)
		5:   # Kunai-zume: oluktan üç kunai yelpaze (Gökyüzü Ülkesi tuzak arbaletleri)
			var km = CharacterModel.weapon_mesh("kunai")
			var d = (aim - from).normalized()
			for k in 3:
				var to = from + d.rotated(Vector3.UP, deg_to_rad((k - 1) * 3.5)) * from.distance_to(aim)
				_bolt(who, from, to, dmg * 0.75, km, {"half": 0.12, "knock": 8.0, "kind": "heavy", "speed": SPEED * 0.9})
