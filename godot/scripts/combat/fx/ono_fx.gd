extends RefCounted
## Ono: model, çentik mekaniği ve dönen atış — kendi şekilleri ve gölgelendiricisi, ortak efekt yok.
## Kaynak: Yosaku_Cut.PNG (koyu geniş ağız, açık keskin kenar, kıvrık sırt, iple sarılı sap), Sabu sayfası, Yosaku Cut (alçak yatay darbe),
## Giant Spinning Axe (balta dönerek keser, ele döner). Çentik kanon değil: Yosaku'nun oduncu türküsünden ve baltanın işinden uyarlama.
## Her ağız isabeti hedefe çentik bırakır (en çok 3, 6 sn); dönen balta çentik başına fazladan keser, 2+ çentikli hedef devrilir. Oyuncu ve düşman aynı kod.

const ID := "ono"
const KERF_T := 6.0

static var _c := {}

const SPARK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""

const WHIRL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float e = smoothstep(0.0, 0.35, UV.x) * (1.0 - smoothstep(0.75, 1.0, UV.x));
	float w = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.86, 0.9, 0.95);
	ALPHA = e * smoothstep(0.0, 0.7, w) * 0.55;
}
"""


# ------------------------------------------------------------------ model
## Kabza 0, sap +Z, ağız -Y, yassı yüz X (Kabutowari ile aynı çerçeve).
static func model(b: MB) -> void:
	var wood = Color(0.33, 0.24, 0.17)
	var rope = Color(0.68, 0.58, 0.42)
	var iron = Color(0.27, 0.28, 0.27)
	var edge = Color(0.8, 0.81, 0.74)
	b.add("cyl", Vector3(0, 0, 0.29), Vector3(0.05, 1.84, 0.05), wood, Vector3(90, 0, 0), 8)
	for k in 7:   # başın altında iple sarılı bölüm
		b.add("cyl", Vector3(0, 0, 0.46 + k * 0.05), Vector3(0.062, 0.04, 0.062), rope.darkened((k % 2) * 0.14), Vector3(90 + (k % 2) * 7.0, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.63), Vector3(0.062, 0.04, 0.062), iron, Vector3(90, 0, 0), 8)
	var arc = []
	for i in 11:
		var u = -1.0 + i * 0.2
		arc.append(Vector2(-0.76 + 0.15 * u * u, 0.98 + 0.5 * u))
	var body = PackedVector2Array([Vector2(0.04, 0.82), Vector2(-0.12, 0.8), Vector2(-0.36, 0.62)])
	for p in arc:
		body.append(p)
	body.append_array(PackedVector2Array([Vector2(-0.36, 1.34), Vector2(-0.12, 1.16), Vector2(0.04, 1.14)]))
	b.add_slab(body, 0.05, iron)
	var band = PackedVector2Array()
	for p in arc:
		band.append(p)
	for i in range(arc.size() - 1, -1, -1):
		band.append((arc[i] as Vector2) + Vector2(0.11, 0.0))
	b.add_slab(band, 0.058, edge, Transform3D.IDENTITY, func(q: Vector2) -> float: return 0.012 if q.x < -0.68 else 0.058)   # bileylenmiş kenar incelir
	b.add("cyl", Vector3(0, 0, 0.98), Vector3(0.092, 0.36, 0.092), iron.darkened(0.2), Vector3(90, 0, 0), 8)   # yuva
	# sırtta kıvrık topuz (Wikipedia: "large scroll-shaped peen"; kaynak görselde rulo)
	b.add("box", Vector3(0, 0.1, 0.98), Vector3(0.06, 0.14, 0.2), iron)
	b.add("cyl", Vector3(0, 0.2, 0.98), Vector3(0.2, 0.09, 0.2), iron, Vector3(0, 0, 90), 12)
	b.add("cyl", Vector3(0, 0.2, 0.98), Vector3(0.1, 0.1, 0.1), iron.darkened(0.45), Vector3(0, 0, 90), 10)


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _node(who: Node3D) -> Node3D:
	var m = who.get("model")
	if m == null or not (m is CharacterModel):
		return null
	for w in m.weapons:
		if LazyFx.g("Gear").base_id(String(w["id"])) == ID and is_instance_valid(w["node"]):
			return w["node"]
	return null


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _foe(who: Node3D, r: float) -> Node3D:
	var best: Node3D = null
	var bd = r
	for x in who.get_tree().get_nodes_in_group("fighters"):
		if x == who or not Combat.hostile(who, x) or x.is_dead():
			continue
		var d = (x as Node3D).global_position.distance_to(who.global_position)
		if d < bd:
			bd = d
			best = x
	return best


static func _mat(key: String, code: String) -> ShaderMaterial:
	key = "mat:" + key
	if not _c.has(key):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[key] = m
	return _c[key]


## Çelik kıvılcım çizgileri (isabet ve yere değme)
static func _sparks(p: Vector3, d: Vector3, n: int, sp: float) -> void:
	var root = _root()
	if root == null:
		return
	if not _c.has("spark"):
		var b = BoxMesh.new()
		b.size = Vector3(0.016, 0.016, 1.0)
		_c["spark"] = b
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _c["spark"]
	mm.instance_count = n
	var data = []
	for i in n:
		data.append((d + Vector3(randf_range(-0.8, 0.8), randf_range(-0.3, 0.9), randf_range(-0.8, 0.8))).normalized() * randf_range(0.5, 1.0) * sp)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("spark", SPARK_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(p - Vector3.ONE * 5.0, Vector3.ONE * 10.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var T = 0.26
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		for i in n:
			var v: Vector3 = data[i] + Vector3.DOWN * 16.0 * t
			var z = v.normalized()
			var x = (Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).cross(z).normalized()
			mm.set_instance_transform(i, Transform3D(Basis(x, z.cross(x), z * 0.3 * (1.0 - t / T)), p + (data[i] as Vector3) * t + Vector3.DOWN * 8.0 * t * t))
			mm.set_instance_color(i, Color(1.0, 0.86, 0.6, 1.0 - t / T)), 0.0, T, T)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ çentik
static func kerfs(h: Node3D) -> int:
	if Game.now() > float(h.get_meta("ono_kerf_t", 0.0)):
		return 0
	return int(h.get_meta("ono_kerf", 0))


static func _add_kerf(who: Node3D, h: Node3D) -> void:
	var n = mini(kerfs(h) + 1, 3)
	h.set_meta("ono_kerf", n)
	h.set_meta("ono_kerf_t", Game.now() + KERF_T)
	var c = h.global_position + Vector3.UP * 1.1
	_sparks(c, (c - who.global_position).normalized(), 5 + n * 3, 6.0)
	Sfx.play("hit_blade", c, 0.82 + n * 0.08, 0.5)


# ------------------------------------------------------------------ dönen atış (Giant Spinning Axe)
static func _whirl_mesh() -> ArrayMesh:
	if _c.has("whirl"):
		return _c["whirl"]
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	for s in 2:   # baltanın izlediği iki kopuk yay (dolu disk değil)
		var base = v.size()
		for k in 15:
			var u = k / 14.0
			var a = s * PI + u * 2.0
			var dir = Vector3(0, cos(a), sin(a))
			v.append(dir * 0.95)
			v.append(dir * 1.42)
			uv.append(Vector2(u, 0))
			uv.append(Vector2(u, 1))
		for k in 14:
			var q = base + k * 2
			idx.append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_c["whirl"] = m
	return m


static func spin_throw(who: Node3D, dmg: float) -> void:
	var root = _root()
	var n = _node(who)
	if root == null or n == null:
		return
	var f = _face(who)
	var side = Vector3.UP.cross(f).normalized()
	var tg = _foe(who, 13.0)
	var from: Vector3 = who.global_position + Vector3.UP * 1.2 + f * 0.7
	var far: Vector3 = (tg.global_position + Vector3.UP * 1.0) if tg != null else from + f * 9.0
	n.visible = false
	var pivot = Node3D.new()
	root.add_child(pivot)
	var copy = MeshInstance3D.new()
	copy.mesh = CharacterModel.weapon_mesh(ID)
	pivot.add_child(copy)
	copy.position = Vector3(0, 0, -0.75)   # ağırlık merkezi başa yakın: oradan döner
	var whirl = MeshInstance3D.new()
	whirl.mesh = _whirl_mesh()
	whirl.material_override = _mat("whirl", WHIRL_SH)
	whirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(whirl)
	var aim = (far - from).normalized()
	var base = Basis(side, Vector3.UP, f)   # sap öne, dönüş ekseni yan: balta dikey çark gibi döner
	var T = 0.96
	var done: Array = []
	var st = {"tick": -1}
	var tw = pivot.create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(pivot) or not is_instance_valid(who):
			return
		var hand = who.global_position + Vector3.UP * 1.2 + _face(who) * 0.7
		var p: Vector3
		if k < 0.48:
			var u = k / 0.48
			p = from.lerp(far + aim * 1.0, 1.0 - (1.0 - u) * (1.0 - u))
		else:
			var u = (k - 0.48) / 0.52
			p = (far + aim * 1.0).lerp(hand, u * u)
		pivot.global_transform = Transform3D(Basis(side, k * T * 25.0) * base, p)
		whirl.global_transform = Transform3D(Basis(side, k * T * 25.0) * base, p)
		var tick = int(k * T / 0.05)
		if tick != int(st["tick"]) and k < 0.7:
			st["tick"] = tick
			var hits = Combat.hit_sphere(who, p, 1.25, {"dmg": dmg, "knock": 5.0, "kind": "heavy", "hitstop": 0.06, "melee": true}, done)
			done.append_array(hits)
			for h in hits:
				_fell(who, h, dmg, aim), 0.0, 1.0, T)
	tw.tween_callback(func():
		if is_instance_valid(pivot):
			pivot.queue_free()
		if is_instance_valid(whirl):
			whirl.queue_free()
		if is_instance_valid(n):
			n.visible = true
		if is_instance_valid(who):
			Sfx.play("clink", who.global_position, 0.7, 0.8))
	Sfx.play("swing_heavy", from, 0.85, 1.0)


## Çentik başına ek kesik; 2+ çentik: hedef kesilmiş ağaç gibi devrilir
static func _fell(who: Node3D, h: Node3D, dmg: float, aim: Vector3) -> void:
	if not is_instance_valid(h) or h.is_dead():
		return
	var n = kerfs(h)
	h.set_meta("ono_kerf", 0)
	if n <= 0:
		return
	var felled = n >= 2
	h.take_hit({"dmg": dmg * 0.24 * n, "attacker": who, "dir": aim, "knock": 9.0 if felled else 1.0, "kind": "heavy" if felled else "light", "hitstop": 0.05, "melee": true})
	if felled:
		Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Devrildi!", Color(1.0, 0.8, 0.45))
		Sfx.play("hit_heavy_weapon", h.global_position, 0.62, 0.9)


# ------------------------------------------------------------------ kombo bağları
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = _face(who)
	var p = who.global_position + f * 1.9
	p.y = Game.ground_height(p.x, p.z) + 0.05
	match i:
		0, 1:
			if who is Player and Game.world:
				Game.world.env.add_shake(0.14)
		2:
			_sparks(p, f, 8, 5.0)   # alçak kesik yeri yalar
			if who is Player and Game.world:
				Game.world.env.add_shake(0.2)
		4:
			Sfx.play("hit_heavy_weapon", p, 0.74, 0.7)
		5:
			spin_throw(who, dmg)


static func on_hit(who: Node3D, i: int, h: Node3D) -> void:
	if h != null and is_instance_valid(h) and not h.is_dead() and i in [0, 1, 2]:
		_add_kerf(who, h)
