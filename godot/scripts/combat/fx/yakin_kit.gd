extends RefCounted
## yakin2 silahlarının ORTAK İSKELETİ (hedef: res://scripts/combat/fx/yakin_kit.gd): küçük yardımcılar, zincir izleyici, şerit geometrisi.
## Görünen malzeme ve gölgelendirici burada değil; her silah kendi halkasını ve kendi gölgelendiricisini verir.

static var _c := {}


## İki nokta arasında halka dizisi: halkalar eğri boyunca dizilir, orta nokta yaylanır (ikincil hareket)
class ChainLine extends MultiMeshInstance3D:
	var a_fn: Callable
	var b_fn: Callable
	var pitch := 0.1
	var sag := 0.2
	var life := INF
	var twist := false
	var end_node: Node3D = null
	var mid := Vector3.ZERO
	var vel := Vector3.ZERO
	var ok := false
	var count := 16

	func _process(dt: float) -> void:
		life -= dt
		if life <= 0.0 or not a_fn.is_valid() or not b_fn.is_valid():
			queue_free()
			return
		var par = get_parent()
		if par is Node3D and not par.is_visible_in_tree():
			visible = false
			return
		var A: Vector3 = a_fn.call()
		var cam = get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(A) > 1600.0:
			visible = false
			return
		visible = true
		global_transform = Transform3D.IDENTITY
		var B: Vector3 = b_fn.call()
		var L = A.distance_to(B)
		var n = clampi(ceili(L / pitch), 1, count)
		multimesh.visible_instance_count = n
		var want = (A + B) * 0.5 + Vector3.DOWN * maxf(0.02, sag - L * 0.05)
		if not ok:
			mid = want
			ok = true
		var d = minf(dt, 0.033)
		vel += (want - mid) * 90.0 * d
		vel *= exp(-7.0 * d)
		mid += vel * d
		for i in n:
			var u = (i + 0.5) / n
			var p: Vector3 = A.lerp(mid, u).lerp(mid.lerp(B, u), u)
			var z: Vector3 = (mid - A).lerp(B - mid, u)
			z = z.normalized() if z.length() > 0.0001 else Vector3.FORWARD
			var x: Vector3 = z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
			var bs = Basis(x, z.cross(x), z)
			if twist and i % 2 == 1:
				bs = Basis(z, PI * 0.5) * bs
			multimesh.set_instance_transform(i, Transform3D(bs, p))
		if end_node != null and is_instance_valid(end_node):
			end_node.global_position = B


static func root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func chain(parent: Node, link: Mesh, a_fn: Callable, b_fn: Callable, life: float, n: int, pitch: float, sag: float, twist := false, end_mesh: Mesh = null) -> ChainLine:
	var c = ChainLine.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	mm.instance_count = n
	c.multimesh = mm
	c.count = n
	c.a_fn = a_fn
	c.b_fn = b_fn
	c.life = life
	c.pitch = pitch
	c.sag = sag
	c.twist = twist
	c.top_level = true
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.custom_aabb = AABB(Vector3.ONE * -60.0, Vector3.ONE * 120.0)
	parent.add_child(c)
	if end_mesh != null:
		var e = MeshInstance3D.new()
		e.mesh = end_mesh
		c.add_child(e)
		e.top_level = true
		c.end_node = e
	return c


static func height_of(t: Node) -> float:
	var v = t.get("height")
	return float(v) if v != null else 1.8


## Hedefin gövdesine dolanan halka çemberi; hedefle birlikte gider
static func wrap(t: Node3D, link: Mesh, h: float, n: int, dur: float) -> void:
	var fr = t.get("radius")
	var r = (float(fr) if fr != null else 0.38) * 0.95
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	mm.instance_count = n
	for i in n:
		var a = float(i) / n * TAU
		var p = Vector3(cos(a) * r, sin(a * 3.0) * 0.03, sin(a) * r)
		var z = Vector3(-sin(a), 0, cos(a))
		var x = Vector3.UP.cross(z).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(x, z.cross(x), z), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(mi)
	mi.position = Vector3.UP * h
	t.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(mi):
			mi.queue_free())


static func mat(key: String, code: String) -> ShaderMaterial:
	if not _c.has(key):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[key] = m
	return _c[key]


static func mesh(key: String, build: Callable) -> Mesh:
	if not _c.has("m:" + key):
		_c["m:" + key] = build.call()
	return _c["m:" + key]


static func node_of(who: Node3D, id: String) -> Node3D:
	var m = who.get("model")
	if m == null or not (m is CharacterModel):
		return null
	for w in m.weapons:
		if LazyFx.g("Gear").base_id(String(w["id"])) == id and is_instance_valid(w["node"]):
			return w["node"]
	return null


static func face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func hand(who: Node3D, right := true) -> Vector3:
	return LazyFx.g("PathJutsu").get_pinst().live_hand(who, right)


static func gp(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.ground_height(p.x, p.z) + 0.03, p.z)


static func after(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


static func pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


static func nature(who: Node3D, el: String) -> bool:
	if who is Player:
		return el in (Game.profile.get("elements", []) as Array)
	return str(who.get("element")) == el if who.get("element") != null else false


static func shake(who: Node3D, a: float) -> void:
	if who is Player and Game.world:
		Game.world.env.add_shake(a)


static func live(n) -> bool:
	return n != null and is_instance_valid(n) and not n.is_dead()


## Aynı silahı taşıyan yakın yoldaş (Oni Kyōdai, Izumo-Kotetsu ortak zinciri)
static func partner(who: Node3D, id: String, r: float) -> Node3D:
	for f in who.get_tree().get_nodes_in_group("fighters"):
		if f != who and not f.is_dead() and not Combat.hostile(who, f) and f.global_position.distance_to(who.global_position) < r and node_of(f, id) != null:
			return f
	return null


## a-b doğrusuna yakın düşmanlar
static func foes_on_line(who: Node3D, a: Vector3, b: Vector3, w: float) -> Array:
	var out := []
	for f in who.get_tree().get_nodes_in_group("fighters"):
		if not Combat.hostile(who, f) or f.is_dead():
			continue
		var c: Vector3 = f.global_position + Vector3.UP
		var ab = b - a
		var k = clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if (a + ab * k).distance_to(c) < w:
			out.append(f)
	return out


## Noktalardan iki dik düzlemli şerit (u: boy, v: en); gölgelendirici çağırandan
static func strip(pts: Array, w: float, m: Material, taper := 0.6) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	var last = maxf(1.0, pts.size() - 1)
	for pl in 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var a: Vector3 = pts[maxi(i - 1, 0)]
			var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var d = (b - a).normalized()
			var s = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
			if pl == 1:
				s = s.cross(d).normalized()
			var k = 1.0 - float(i) / last * taper
			im.surface_set_uv(Vector2(float(i) / last, 0))
			im.surface_add_vertex(pts[i] - s * w * k)
			im.surface_set_uv(Vector2(float(i) / last, 1))
			im.surface_add_vertex(pts[i] + s * w * k)
		im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


static func fade(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)
