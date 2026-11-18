extends RefCounted
## Suzu (鈴, çıngıraklı senbon; Narutopedia "Bell", "Shadow Senbon", "Genjutsu: Bell Sound Clone"; hedef: res://scripts/combat/fx/suzu_fx.gd). Kanon kullanıcı: Kin Tsuchi.
## Kanon: çıngıraklı senbonla sessiz senbon birlikte atılır; rakip sese döner, sessiz olan vurur. Çıngıraklara ip bağlanır, uzaktan çalınır. Ses kulaktan beyne geçer: felç + çoğalan görüntüler.
## Mekanik: 3 çıngıraklı iğne + 1 sessiz iğne. Çıngıraklar yere / hedefe düşer, ipleri elde kalır, 3 kez çalar. Art arda iki çalışı 5 m içinde duyan felç olur, çevresinde sahte kopyalar belirir. Uzaklaşan kurtulur.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const SPEED := 62.0
const BELL_DMG := 2.0
const SILENT_DMG := 12.0
const HEAR_R := 5.0
const STUN := 1.3
const RINGS := [0.55, 1.05, 1.55]
const LIFE := 2.2

const LINE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.86, 0.87, 0.8);
	ALPHA = smoothstep(0.0, 0.6, e) * smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x)) * fade * 0.85;
}
"""


static func _build_needle() -> Mesh:
	var b = MB.new()
	b.add("cyl", Vector3(0, 0, 0.14), Vector3(0.008, 0.28, 0.008), Color(0.32, 0.33, 0.38), Vector3(90, 0, 0), 4)
	b.add("cone", Vector3(0, 0, 0.3), Vector3(0.008, 0.05, 0.008), Color(0.2, 0.2, 0.24), Vector3(90, 0, 0), 4)
	return b.build(Props.toon())


static func _build_bell() -> Mesh:
	var b = MB.new()
	var metal = Color(0.72, 0.7, 0.62)
	b.add("sphere", Vector3.ZERO, Vector3(0.075, 0.075, 0.075), metal, Vector3.ZERO, 10)
	b.add("box", Vector3(0, -0.026, 0), Vector3(0.05, 0.007, 0.078), Color(0.12, 0.11, 0.1))
	b.add("sphere", Vector3(0, -0.026, 0), Vector3(0.016, 0.016, 0.016), Color(0.2, 0.18, 0.15), Vector3.ZERO, 6)
	b.add("torus", Vector3(0, 0.045, 0), Vector3(0.024, 0.024, 0.024), metal.darkened(0.2), Vector3(90, 0, 0), 8)
	return b.build(Props.toon())


## Kopuk ses yayları: birim yarıçap, iki parça (Bell_Ring_Genjutsu.png: ince eğri çizgiler)
static func _build_arcs() -> Mesh:
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	for s in 3:
		var a0 = s * TAU / 3.0 + 0.3
		var base = v.size()
		for k in 15:
			var u = k / 14.0
			var a = a0 + u * 1.5
			var d = Vector3(cos(a), sin(a * 2.0) * 0.08, sin(a))
			v.append(d * 0.97)
			v.append(d * 1.03)
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
	return m


static func _build_string() -> Mesh:
	var c = CylinderMesh.new()
	c.top_radius = 0.004
	c.bottom_radius = 0.004
	c.height = 1.0
	c.radial_segments = 4
	c.rings = 1
	return c


static func _needle_mesh() -> Mesh:
	return Kit.cached_mesh("suzu_needle", Callable(_build_needle))


static func _bell_mesh() -> Mesh:
	return Kit.cached_mesh("suzu_bell", Callable(_build_bell))


static func _string_mesh() -> Mesh:
	return Kit.cached_mesh("suzu_string", Callable(_build_string))


static func _hand(who: Node3D) -> Vector3:
	var pj = PathJutsu.get_pinst()
	return pj.hand_pos(who, true) if pj != null else Kit.chest(who)


static func _vis(with_bell: bool) -> Node3D:
	var root = Node3D.new()
	var n = MeshInstance3D.new()
	n.mesh = _needle_mesh()
	n.rotation.y = PI
	root.add_child(n)
	if with_bell:
		var bell = MeshInstance3D.new()
		bell.mesh = _bell_mesh()
		bell.position = Vector3(0, -0.07, 0.2)
		root.add_child(bell)
	return root


static func launch(who: Node3D, start: Vector3, dir: Vector3, target: Node3D) -> Projectile:
	var tg = target if U.alive(target) else null
	var aim: Vector3 = U.chest(tg) if tg != null else start + dir * 15.0
	var f = (aim - start).normalized()
	var side = f.cross(Vector3.UP).normalized()
	var field = {"bells": [], "t": 0.0, "ring": 0, "heard": {}, "done": {}}
	var mult = Kit.tool_mult(who)
	var first: Projectile = null
	for k in 3:
		var off = side * (k - 1) * 1.5 + Vector3.UP * (0.3 if k == 1 else -0.2)
		var pt = aim + off
		var land = func(pos: Vector3, _t: Node3D) -> void:
			_plant(field, pos)
		var pr = U.fire(who, start + side * (k - 1) * 0.12, U.solve(start, pt, SPEED, 1.0), {"g": 1.0, "r": 0.12, "life": 1.2, "vis": _vis(true), "hit": land,
			"info": {"dmg": BELL_DMG * mult, "knock": 0.0, "kind": "light", "hitstop": 0.0, "tool": "suzu"}})
		if first == null:
			first = pr
	# sessiz iğne: alttan, çıngırakların sesinin altında gider
	var low = start + Vector3.DOWN * 0.25 - side * 0.2
	U.fire(who, low, U.solve(low, aim, SPEED * 0.92, 0.6), {"g": 0.6, "r": 0.1, "life": 1.3, "stick": true, "vis": _vis(false),
		"info": {"dmg": SILENT_DMG * mult, "knock": 0.5, "kind": "light", "bleed": 1.0, "hitstop": 0.02, "tool": "suzu"}})
	Sfx.play("clink", start, 2.2, 0.55)
	_run(who, field)
	return first


static func _plant(field: Dictionary, pos: Vector3) -> void:
	var g = Game.jutsu_floor(pos.x, pos.z)
	(field["bells"] as Array).append(Vector3(pos.x, maxf(pos.y, g + 0.35), pos.z))


static func _run(who: Node3D, field: Dictionary) -> void:
	var nodes := {"bells": [], "strings": []}
	var root_box := {}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or who.is_dead():
			return true
		field["t"] += dt
		var t: float = field["t"]
		if t >= LIFE:
			return true
		var root: Node3D = root_box["n"]
		var bells: Array = field["bells"]
		while (nodes["bells"] as Array).size() < bells.size():
			var b = MeshInstance3D.new()
			b.mesh = _bell_mesh()
			root.add_child(b)
			nodes["bells"].append(b)
			var st = MeshInstance3D.new()
			st.mesh = _string_mesh()
			st.material_override = Props.toon_color(Color(0.8, 0.8, 0.74), 0.1)
			st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			st.extra_cull_margin = 30.0
			root.add_child(st)
			nodes["strings"].append(st)
		var hand = _hand(who)
		for i in bells.size():
			var p: Vector3 = bells[i]
			var sway = sin(t * 22.0 + i) * 0.03
			(nodes["bells"][i] as Node3D).global_position = p + Vector3(sway, 0, 0)
			var d = p - hand
			var L = maxf(d.length(), 0.02)
			var y = d / L
			var x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
			(nodes["strings"][i] as Node3D).global_transform = Transform3D(Basis(x, y * L, x.cross(y)), (hand + p) * 0.5)
		var r: int = field["ring"]
		if r < RINGS.size() and t >= float(RINGS[r]):
			field["ring"] = r + 1
			_ring(who, field, root)
		return false
	root_box["n"] = Kit.ticker(who.global_position, fn)


static func _ring(who: Node3D, field: Dictionary, root: Node3D) -> void:
	var bells: Array = field["bells"]
	if bells.is_empty():
		return
	for p in bells:
		Sfx.play("clink", p, randf_range(2.3, 2.7), 0.5)
		_arcs(root, p)
	var heard: Dictionary = field["heard"]
	for f in Kit.fighters():
		if not Combat.hostile(who, f) or f.is_dead():
			continue
		var id = f.get_instance_id()
		var near = false
		for p in bells:
			if (p as Vector3).distance_to(f.global_position + Vector3.UP) <= HEAR_R:
				near = true
				break
		heard[id] = int(heard.get(id, 0)) + 1 if near else 0
		if int(heard[id]) >= 2 and not (field["done"] as Dictionary).has(id):
			field["done"][id] = true
			_daze(who, f)


static func _arcs(root: Node3D, p: Vector3) -> void:
	for k in 2:
		var mi = MeshInstance3D.new()
		mi.mesh = Kit.cached_mesh("suzu_arcs", Callable(_build_arcs))
		mi.material_override = Kit.shader_mat("suzu_line", LINE_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 6.0
		root.add_child(mi)
		mi.global_position = p
		mi.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
		mi.scale = Vector3.ONE * 0.3
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * (2.2 + k * 1.1), 0.42)
		Kit.tween_param(mi, "fade", 1.0, 0.0, 0.42, true)


## Felç + çoğalan görüntü (kanon genjutsu; oyunun gerçek klon sistemi)
static func _daze(who: Node3D, f: Node3D) -> void:
	if f.has_method("apply_status"):
		f.apply_status("stun", STUN)
	Combat.popup_text(f.global_position + Vector3.UP * (Kit.height_of(f) + 0.3), "Çın çın...", Color(0.95, 0.9, 0.6))
	var pj = PathJutsu.get_pinst()
	if pj == null or who.get("model") == null:
		return
	for k in 3:
		var a = TAU * k / 3.0 + randf()
		pj.decoy(who, f.global_position + Vector3(cos(a), 0, sin(a)) * 2.4, STUN + 0.3)
