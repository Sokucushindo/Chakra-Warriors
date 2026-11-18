extends RefCounted
## Yumi: model, hareketli yay düzeneği, oklar. Ortak efekt kütüphanesi yok; her şey burada üretilir.
## Kanon (Narutopedia "Bow & Arrow", "Bukijutsu > Kyūjutsu", "Kidōmaru", "Spider War Bow: Terrible Split", "Fūma Clan (Land of Sound)"):
## yay Naruto'da seyrek; Shion'un muhafızları (Taruho, Susuki: sırtta sadak, beyaz tüylü oklar), Hikaru Tsuki, Tenji, Suzaku'nun okçuları.
## Kidōmaru kirişi normalin ötesinde gerer: ok gözle görülmez hızda çıkar; oka ip bağlayıp 50 m'ye kadar yönlendirir (Neji'nin kaçışını
## böyle yendi). Fūma klanı: chakra ipi + okçuluk. Zayıflık: kuruluş uzun, yakında savunmasız, çekerken vurulursa ok düşer.
## Düzen: sağ eldeki silah OK ("yumi", weapons[0]), sol eldeki ikinci silah YAY ("yumi_yay"). Yay uzayı: +Z üst uç, +X hedefe, kiriş -X'te.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const A = preload("res://scripts/combat/yumi_anim.gd")

const THREAD_COST := 0.07   # Ito-ya: azami chakranın oranı
const SPEED := 62.0
const SPEED_FULL := 118.0   # tam çekiş: gözle zor seçilir
const GRAV := 2.2

const LACQ := Color(0.43, 0.12, 0.08)      # Taruho'nun yayı: kızıl lake
const WRAP := Color(0.8, 0.74, 0.6)        # sap sargısı (Hikaru)
const BONE := Color(0.9, 0.86, 0.72)
const CORD := Color(0.93, 0.9, 0.8)

static var _c := {}

const STREAK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec3 tint = vec3(0.9, 0.92, 1.0);
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = tint;
	ALPHA = smoothstep(0.0, 0.7, across) * (1.0 - UV.y) * UV.y * 2.4 * 0.55;
}
"""

const THREAD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float fade_k = 1.0;
void fragment() {
	float pulse = 0.55 + 0.45 * sin(UV.y * 90.0 - TIME * 34.0);
	ALBEDO = vec3(0.55, 0.82, 1.0);
	ALPHA = pulse * fade_k * 0.9;
}
"""


# ------------------------------------------------------------------ hareketli yay
class Rig extends Node3D:
	const U2 = preload("res://scripts/combat/fx/uzak_nisan.gd")
	const L_UP := 0.98      # tutuşun üstü (yumi asimetriktir: tutuş alt üçte birde)
	const L_LO := 0.6
	const BRACE := 0.12
	const DRAW_LEN := 0.5
	const SEGS := 10

	var who: Node3D
	var bow: MeshInstance3D
	var limbs: MultiMesh
	var cord: MultiMesh
	var ya: MeshInstance3D
	var hooked := false
	var hook_in := -1.0
	var dr := 0.0
	var snap := -1.0
	var snap_d := 0.0
	var aim := Vector3.ZERO
	var back_in := -1.0   # sağ eldeki ok yeniden görünür

	## s: -1 alt uç .. +1 üst uç; dr: çekiş. Uçlar hedefe doğru hafif kıvrılır (Spider_War_Bow ref)
	static func limb_pt(s: float, d: float) -> Vector3:
		var u = absf(s)
		var L = L_UP if s >= 0.0 else L_LO
		var x = -(0.16 + 0.2 * d) * u * u + 0.04 * smoothstep(0.74, 1.0, u)
		return Vector3(x, 0.0, signf(s) * L * (u - 0.1 * d * u * u))

	static func seg_xf(a: Vector3, b: Vector3, w: float) -> Transform3D:
		var y = b - a
		if y.length() < 0.0005:
			y = Vector3(0, 0, 0.0005)
		var yn = y.normalized()
		var xn = yn.cross(Vector3.UP if absf(yn.y) < 0.9 else Vector3.RIGHT).normalized()
		return Transform3D(Basis(xn * w, y * 1.06, xn.cross(yn) * w), (a + b) * 0.5)

	func setup(w: Node3D, n: MeshInstance3D, limb_mesh: Mesh, cord_mesh: Mesh, ya_mesh: Mesh) -> void:
		who = w
		bow = n
		name = "YumiRig"
		process_priority = 60
		limbs = _mm(limb_mesh, SEGS * 2)
		cord = _mm(cord_mesh, 2)
		ya = MeshInstance3D.new()
		ya.mesh = ya_mesh
		ya.top_level = true
		ya.visible = false
		add_child(ya)
		_pose(_rest_nock(0.0), 0.0)

	func _mm(mesh: Mesh, n: int) -> MultiMesh:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = n
		var mi = MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.custom_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
		add_child(mi)
		return mm

	func _rest_nock(d: float) -> Vector3:
		return (limb_pt(1.0, d) + limb_pt(-1.0, d)) * 0.5

	func _pose(nock: Vector3, d: float) -> void:
		dr = d
		for side in 2:
			var sg = 1.0 if side == 0 else -1.0
			for k in SEGS:
				var u0 = float(k) / SEGS
				var u1 = float(k + 1) / SEGS
				limbs.set_instance_transform(side * SEGS + k, seg_xf(limb_pt(sg * maxf(u0, 0.001), d), limb_pt(sg * u1, d), lerpf(0.034, 0.015, u1)))
		cord.set_instance_transform(0, seg_xf(limb_pt(1.0, d), nock, 0.005))
		cord.set_instance_transform(1, seg_xf(nock, limb_pt(-1.0, d), 0.005))

	## step_hook: kaç sn sonra parmaklar kirişe takılır
	func engage(a: Vector3, step_hook: float) -> void:
		aim = a
		hook_in = step_hook
		snap = -1.0

	func _hook() -> void:
		hooked = true
		ya.visible = true
		back_in = -1.0
		var an = U2.weapon_node(who, "yumi")
		if an != null:
			an.visible = false

	func release(fired: bool) -> void:
		hook_in = -1.0
		if hooked or fired:
			snap = 0.0
			snap_d = dr
			back_in = 0.25
		hooked = false
		ya.visible = false

	func _orient(dt: float) -> void:
		if aim == Vector3.ZERO:
			return
		var x = aim
		x.y = clampf(x.y, -0.45, 0.8)
		x = x.normalized()
		var z = (Vector3.UP - x * x.dot(Vector3.UP)).normalized()
		var g = bow.global_transform
		var s = g.basis.get_scale().x
		var q = g.basis.orthonormalized().get_rotation_quaternion().slerp(Basis(x, z.cross(x), z).get_rotation_quaternion(), minf(1.0, dt * 16.0))
		bow.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * s), g.origin)

	func _process(dt: float) -> void:
		if who == null or not is_instance_valid(who) or not is_instance_valid(bow):
			return
		var m = who.get("model")
		if m == null or m.overlay == null:
			return
		var acting = m.drawn and m.overlay.key_t >= 0.0
		if hook_in >= 0.0:
			hook_in -= dt
			if hook_in < 0.0 and acting:
				_hook()
		if hooked and not acting:
			release(false)   # çekerken vuruldu / kombo kesildi: ok düşer, bırakış yok
		if back_in >= 0.0:
			back_in -= dt
			if back_in < 0.0 and not hooked:
				m._place_weapons()
		if acting:
			_orient(dt)
		if hooked:
			var hw: Vector3 = U2.fingers(who, "Right")
			var nl: Vector3 = bow.to_local(hw)
			var d = clampf((-nl.x - BRACE) / DRAW_LEN, 0.0, 1.0)
			var nock = Vector3(minf(nl.x, -BRACE), 0.0, clampf(nl.z, -0.1, 0.16))
			_pose(nock, d)
			var nw: Vector3 = bow.to_global(nock)
			var to: Vector3 = bow.to_global(Vector3(0.0, 0.02, 0.03)) - nw
			if to.length() > 0.02:
				var tn = to.normalized()
				ya.global_transform = Transform3D(Basis.looking_at(-tn, Vector3.UP if absf(tn.y) < 0.95 else Vector3.RIGHT).scaled(Vector3.ONE * bow.global_transform.basis.get_scale().x), nw)
		elif snap >= 0.0:
			snap += dt
			var d2 = snap_d * exp(-snap * 30.0)
			var vib = 0.03 * snap_d * exp(-snap * 8.0) * sin(snap * 85.0)   # kiriş titrer
			_pose(_rest_nock(d2) + Vector3(vib, 0, 0), d2)
			if snap > 0.7:
				snap = -1.0
				_pose(_rest_nock(0.0), 0.0)


# ------------------------------------------------------------------ modeller (CharacterModel.weapon_mesh buradan okur)
static func _seg(b: MB, p: Vector3, q: Vector3, w: float, col: Color) -> void:
	b.add_xf("cyl", Rig.seg_xf(p, q, w), col, 6)


## Tutuş: rattan sargı, altta iki beyaz bilezik (Taruho'nun yayı)
static func build_grip(b: MB) -> void:
	b.add("cyl", Vector3(0, 0, 0.0), Vector3(0.04, 0.16, 0.04), WRAP, Vector3(90, 0, 0), 8)
	for z in [-0.07, -0.03, 0.01, 0.05]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.043, 0.007, 0.043), WRAP.darkened(0.3), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0.0, 0.0, 0.1), Vector3(0.036, 0.03, 0.036), LACQ.darkened(0.25), Vector3(90, 0, 0), 8)
	for z in [-0.2, -0.16]:
		var p = Rig.limb_pt(z / Rig.L_LO, 0.0)
		b.add("cyl", p, Vector3(0.036, 0.018, 0.036), Color(0.94, 0.93, 0.88), Vector3(90, 0, 0), 8)


## Tam yay (dururken / sırtta): uçlar kemik, kiriş dümdüz
static func build_bow(b: MB) -> void:
	build_grip(b)
	var n = 26
	for k in n:
		var s0 = lerpf(-1.0, 1.0, float(k) / n)
		var s1 = lerpf(-1.0, 1.0, float(k + 1) / n)
		var u = maxf(absf(s0), absf(s1))
		_seg(b, Rig.limb_pt(s0, 0.0), Rig.limb_pt(s1, 0.0), lerpf(0.034, 0.015, u), BONE if u > 0.95 else LACQ)
	_seg(b, Rig.limb_pt(-1.0, 0.0), Rig.limb_pt(1.0, 0.0), 0.005, CORD)


## Ok: dip z=0, uç z=0.86; bambu gövde, koyu çentik, üç beyaz tüy (koyu bantlı), yaprak uç (Kidōmaru okunun geniş ucu)
static func build_arrow(b: MB, z0 := 0.0) -> void:
	var bam = Color(0.72, 0.62, 0.42)
	b.add("cyl", Vector3(0, 0, z0 + 0.4), Vector3(0.012, 0.8, 0.012), bam, Vector3(90, 0, 0), 5)
	for z in [0.24, 0.5]:
		b.add("cyl", Vector3(0, 0, z0 + z), Vector3(0.015, 0.012, 0.015), bam.darkened(0.35), Vector3(90, 0, 0), 5)
	b.add("cyl", Vector3(0, 0, z0 + 0.008), Vector3(0.015, 0.018, 0.015), Color(0.15, 0.12, 0.1), Vector3(90, 0, 0), 5)
	var leaf = PackedVector2Array([Vector2(0.0, 0.78), Vector2(0.02, 0.8), Vector2(0.012, 0.84), Vector2(0.0, 0.88), Vector2(-0.012, 0.84), Vector2(-0.02, 0.8)])
	var head = PackedVector2Array()
	for p in leaf:
		head.append(Vector2(p.x, p.y + z0))
	b.add_slab(head, 0.006, Color(0.66, 0.68, 0.72))
	for k in 3:
		var xf = Transform3D(Basis(Vector3.BACK, k * TAU / 3.0), Vector3.ZERO)
		var o = PackedVector2Array([Vector2(0.006, z0 + 0.03), Vector2(0.042, z0 + 0.05), Vector2(0.042, z0 + 0.17), Vector2(0.006, z0 + 0.21)])
		b.add_slab(o, 0.002, Color(0.95, 0.94, 0.9), xf)
		var o2 = PackedVector2Array([Vector2(0.006, z0 + 0.1), Vector2(0.043, z0 + 0.1), Vector2(0.043, z0 + 0.125), Vector2(0.006, z0 + 0.125)])
		b.add_slab(o2, 0.003, Color(0.2, 0.18, 0.2), xf)


## Sadak (ebira; Taruho: omuz arkasından çıkan tüylü oklar): silah uzayında +Z ağız
static func build_quiver(b: MB) -> void:
	var lea = Color(0.3, 0.13, 0.1)
	b.add("cyl", Vector3(0, 0, 0.2), Vector3(0.1, 0.42, 0.075), lea, Vector3(90, 0, 0), 10)
	for z in [0.03, 0.39]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.108, 0.02, 0.083), lea.darkened(0.3), Vector3(90, 0, 0), 10)
	for k in 5:
		var a = k * TAU / 5.0 + 0.4
		var o = Vector3(cos(a) * 0.028, sin(a) * 0.018, 0.0)
		var ab = MB.new()
		build_arrow(ab)
		b.add_mesh(ab, Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.BACK, a), o + Vector3(0, 0, 0.7 + k * 0.012)))


static func _mesh(key: String, fn: Callable) -> Mesh:
	if not _c.has(key):
		var b = MB.new()
		fn.call(b)
		_c[key] = b.build(Props.toon())
	return _c[key]


static func _unit_cyl(col: Color) -> Mesh:
	return _mesh("cyl:%s" % col.to_html(), func(b: MB): b.add("cyl", Vector3.ZERO, Vector3.ONE, col, Vector3.ZERO, 6))


static func _arrow_mesh() -> Mesh:
	return _mesh("arrow", func(b: MB): build_arrow(b))


static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[k] = m
	return _c[k]


# ------------------------------------------------------------------ düzenek
static func rig_of(who: Node3D) -> Rig:
	var n = U.weapon_node(who, "yumi_yay")
	if n == null or not (n is MeshInstance3D):
		return null
	var r = n.get_node_or_null("YumiRig")
	if r != null:
		return r
	var rig = Rig.new()
	n.add_child(rig)
	(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("yumi_yay_k")   # yay kolları ve kiriş artık düzenekten
	rig.setup(who, n, _unit_cyl(LACQ), _unit_cyl(CORD), _arrow_mesh())
	return rig


## Uçan ok: görsel -Z'ye bakar, merkez ortada; arkasında ince hava çizgisi
static func _flight(fast: bool) -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = _arrow_mesh()
	mi.rotation.y = PI
	mi.position = Vector3(0, 0, 0.43)
	root.add_child(mi)
	if not _c.has("mesh:streak"):
		var q = QuadMesh.new()
		q.size = Vector2(0.035, 1.0)
		_c["mesh:streak"] = q
	for k in 2:
		var s = MeshInstance3D.new()
		s.mesh = _c["mesh:streak"]
		s.material_override = _mat("streak", STREAK_SH)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var L = 2.6 if fast else 1.1
		s.transform = Transform3D(Basis(Vector3.BACK, k * PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1, L, 1)), Vector3(0, 0, 0.45 + L * 0.5))
		root.add_child(s)
	return root


## Kıymık + tüy parçaları (yalnız bu okun): kısa parabol
static func _chips(p: Vector3, n: int) -> void:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree) or (ml as SceneTree).current_scene == null:
		return
	if not _c.has("mesh:chip"):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.012, 0.006, 0.06), Color(0.72, 0.62, 0.42))
		_c["mesh:chip"] = b.build(Props.toon())
		var b2 = MB.new()
		b2.add("box", Vector3.ZERO, Vector3(0.03, 0.002, 0.05), Color(0.95, 0.94, 0.9))
		_c["mesh:tuft"] = b2.build(Props.toon())
	for k in n:
		var mi = MeshInstance3D.new()
		mi.mesh = _c["mesh:tuft"] if k % 3 == 0 else _c["mesh:chip"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(ml as SceneTree).current_scene.add_child(mi)
		mi.global_position = p
		var v = Vector3(randf_range(-1, 1), randf_range(0.4, 1.4), randf_range(-1, 1)) * randf_range(1.6, 3.2)
		var sp = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
		var tw = mi.create_tween()
		tw.tween_method(func(t: float):
			if is_instance_valid(mi):
				mi.global_position = p + v * t + Vector3.DOWN * 7.0 * t * t
				mi.rotation = sp * t, 0.0, 0.42, 0.42)
		tw.tween_callback(mi.queue_free)


static func _land(pos: Vector3, tgt: Node3D, vel: Vector3) -> void:
	_chips(pos, 5)
	if tgt != null and is_instance_valid(tgt):
		Sfx.play("hit_blade", pos, randf_range(1.05, 1.2), 0.7)
		var mi = MeshInstance3D.new()
		mi.mesh = _arrow_mesh()
		U.pin(mi, tgt, pos - vel.normalized() * 0.66, vel, 3.5)


static func _shoot(who: Node3D, from: Vector3, vel: Vector3, dmg: float, o := {}) -> Projectile:
	var fast = bool(o.get("fast", false))
	var inf = {"dmg": dmg, "knock": float(o.get("knock", 2.5)), "kind": str(o.get("kind", "light")), "hitstop": 0.03}
	var holder = [null]
	var vis = _flight(fast)
	var cb: Callable = o.get("hit", Callable())
	var on_land = func(pos: Vector3, tgt: Node3D) -> void:
		var pv: Vector3 = holder[0].vel if holder[0] != null and is_instance_valid(holder[0]) else vel
		_land(pos, tgt, pv)
		if is_instance_valid(vis) and not bool(o.get("pierce", false)):   # saplanan okta hava çizgisi kalmaz
			for c in vis.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).mesh is QuadMesh:
					c.visible = false
		if cb.is_valid():
			cb.call(pos, tgt)
	var pr = U.fire(who, from, vel, {"g": float(o.get("g", GRAV)), "r": 0.13, "life": float(o.get("life", 2.2)), "stick": true, "pierce": bool(o.get("pierce", false)),
		"info": inf, "vis": vis, "tick": o.get("tick", Callable()), "hit": on_land})
	holder[0] = pr
	return pr


# ------------------------------------------------------------------ kombo bağlantıları (KeyedCombos.on_start / on_strike)
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	var tg = U.target_of(who)
	var p = U.aim_at(who, tg)
	U.face(who, p)
	var rig = rig_of(who)
	if rig != null:
		rig.engage((p - U.bone_pos(who, "LeftHand")).normalized(), float(A.HOOK[clampi(i, 0, 5)]))
	if i == 3 and who is CharacterBody3D:   # Hiki-uchi: geri sıçrar
		var f: Vector3 = who.face_dir()
		who.velocity.x = -f.x * 7.5
		who.velocity.z = -f.z * 7.5
		who.velocity.y = 6.5


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var bow = U.weapon_node(who, "yumi_yay")
	var from: Vector3 = bow.to_global(Vector3(0.14, 0.0, 0.03)) if bow != null else who.global_position + Vector3.UP * 1.4 + who.face_dir() * 0.6
	var rig = rig_of(who)
	if rig != null:
		rig.release(true)
	Sfx.play("clink", from, 0.5, 0.22)   # kiriş sesi (kütüphanede ayrı kiriş sesi yok)
	Sfx.play("whoosh", from, 1.9 if i != 2 else 2.3, 0.45)
	match i:
		0, 1, 3:
			_shoot(who, from, U.solve(from, aim, SPEED, GRAV), dmg * (0.85 if i == 1 else 1.0))
		2:   # Tsuranuki: delip geçer, yolundaki herkesi vurur
			_shoot(who, from, U.solve(from, aim, SPEED_FULL, 0.6), dmg * 1.5, {"g": 0.6, "fast": true, "pierce": true, "knock": 6.0, "kind": "heavy", "life": 1.4})
			if who is Player and Game.world:
				Game.world.env.add_shake(0.25)
		4:   # Ya-ame: yedi ok art arda göğe; hedefin çevresine iner
			var c = aim
			for k in 7:
				who.get_tree().create_timer(k * 0.07).timeout.connect(func():
					if not is_instance_valid(who):
						return
					var q = (U.chest(tg) if U.alive(tg) else c) + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
					var fp: Vector3 = bow.to_global(Vector3(0.14, 0.0, 0.1)) if is_instance_valid(bow) else from
					_shoot(who, fp, U.lob(fp, q, 1.15, 13.0), dmg * 0.42, {"g": 13.0, "life": 2.0, "knock": 1.5}))
		5:   # Ito-ya: chakra ipi bağlı ok hedefi izler, yana kaçışla kopmaz; chakra yoksa düz güçlü ok
			var v = U.solve(from, aim, SPEED, GRAV)
			if U.pay(who, THREAD_COST):
				_thread_arrow(who, from, v.normalized() * 46.0, tg, dmg * 1.9)
			else:
				_shoot(who, from, v, dmg * 1.3, {"knock": 8.0, "kind": "heavy"})


static func _thread_arrow(who: Node3D, from: Vector3, v: Vector3, tg: Node3D, dmg: float) -> void:
	var line = MeshInstance3D.new()
	if not _c.has("mesh:thread"):
		var cm = CylinderMesh.new()
		cm.top_radius = 0.0035
		cm.bottom_radius = 0.0035
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		_c["mesh:thread"] = cm
	line.mesh = _c["mesh:thread"]
	line.material_override = _mat("thread", THREAD_SH)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	who.get_tree().current_scene.add_child(line)
	var tick = func(pr: Projectile, dt: float) -> void:
		if U.alive(tg):
			var want: Vector3 = (U.chest(tg) - pr.global_position).normalized()
			var spd = pr.vel.length()
			pr.vel = pr.vel.normalized().slerp(want, minf(1.0, dt * 7.0)).normalized() * spd
		if is_instance_valid(line) and is_instance_valid(who):
			var hand: Vector3 = U.fingers(who, "Right")
			var dv: Vector3 = pr.global_position - hand
			if dv.length() > 0.05:
				line.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dv.normalized())) * Basis.from_scale(Vector3(1, dv.length(), 1)), (pr.global_position + hand) * 0.5)
	var on_hit = func(_pos: Vector3, tgt: Node3D) -> void:
		if tgt != null and is_instance_valid(tgt) and tgt.has_method("apply_status"):
			tgt.apply_status("bind", 1.0)
	var pr = _shoot(who, from, v, dmg, {"g": 0.0, "life": 2.6, "tick": tick, "knock": 9.0, "kind": "heavy", "hit": on_hit})
	pr.tree_exited.connect(func():
		if is_instance_valid(line):
			var tw = line.create_tween()
			tw.tween_method(func(k: float):
				if is_instance_valid(line):
					line.set_instance_shader_parameter("fade_k", k), 1.0, 0.0, 0.18)
			tw.tween_callback(line.queue_free))
