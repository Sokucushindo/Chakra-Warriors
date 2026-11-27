extends RefCounted
## Tsurukame: model, atış düzeneği, cephane (hedef: res://scripts/combat/fx/tsurukame_fx.gd). Blok kuralları TateFX'in kendisi (yeni sistem yok): tam durdurma, dayanıklılık, kusursuz blok.
## Kanon: Iō'nun kalkan biçimli prototipi; Jidanda'nın doğrudan darbesine dayanır; içinden manriki zinciri, bomba, senbon fırlatır; boşalınca arkadaki bölmeye araç parşömeni sürülür. Rapid Fire tekniği. Ref Tsuru-Kame.PNG: yeşil altıgen kabuk, delikli gri plakalar.
## Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const TateFX = preload("res://scripts/combat/fx/tate_fx.gd")

const ID := "tsurukame"
const AMMO := 24

const BLAST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float edge = (0.3 + 0.62 * prog) * (0.75 + 0.25 * sin(a * 7.0) * sin(a * 3.0 + 1.0));
	float m = 1.0 - smoothstep(edge * 0.8, edge, length(p));
	ALBEDO = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.95, 0.7), 1.0 - prog);
	ALPHA = m * (1.0 - smoothstep(0.45, 1.0, prog));
	if (ALPHA < 0.02) discard;
}
"""


# ------------------------------------------------------------------ model
static func _hex(r: float) -> PackedVector2Array:
	var o = PackedVector2Array()
	for k in 6:
		var a = PI / 6.0 + k * PI / 3.0
		o.append(Vector2(cos(a), sin(a)) * r)
	return o


static func _xf(x: float, y: float, z: float, tilt_y: float, tilt_z: float) -> Transform3D:
	var b = Basis(Vector3.BACK, tilt_y) * Basis(Vector3.UP, tilt_z)
	return Transform3D(b, Vector3(x, y, z))


## Ön kol çerçevesi: +X dış yüz; YZ düzlemi kabuk. id tsurukame_kirik: çatlak.
static func model(b: MB, id := "tsurukame") -> void:
	var green = Color(0.2, 0.55, 0.45)
	var line = Color(0.08, 0.27, 0.34)
	var grey = Color(0.47, 0.48, 0.54)
	var hole = Color(0.04, 0.04, 0.05)
	var gold = Color(0.82, 0.7, 0.34)
	b.add("sphere", Vector3(0.05, 0, 0), Vector3(0.14, 0.76, 0.76), line, Vector3.ZERO, 16)
	b.add_slab(_hex(0.165), 0.03, green, _xf(0.135, 0, 0, 0, 0))
	for k in 6:
		var a = k * PI / 3.0
		var y = cos(a) * 0.285
		var z = sin(a) * 0.285
		var tiltz = -sin(a) * 0.32
		var tilty = cos(a) * 0.32
		var col = grey if k % 2 == 0 else green.darkened(0.12)
		b.add_slab(_hex(0.125), 0.028, col, _xf(0.1, y, z, tilty, tiltz))
		if k % 2 == 0:
			for j in 3:
				var q = j * TAU / 3.0 + a
				b.add("cyl", Vector3(0.122, y + cos(q) * 0.06, z + sin(q) * 0.06), Vector3(0.028, 0.006, 0.028), hole, Vector3(0, 0, 90), 8)
	for s in [-1.0, 1.0]:
		b.add("box", Vector3(0.075, 0.0, 0.385 * s), Vector3(0.02, 0.12, 0.03), gold)
	b.add("box", Vector3(0.012, 0, 0), Vector3(0.012, 0.1, 0.16), Color(0.2, 0.15, 0.1))   # iç bölme
	if id == "tsurukame_kirik":
		for e in [[0.08, 0.04, 20.0], [-0.1, -0.05, -40.0]]:
			b.add("box", Vector3(0.155, e[0], e[1]), Vector3(0.008, 0.24, 0.014), hole, Vector3(float(e[2]), 0, 0))


static func _build_needle() -> Mesh:
	var b = MB.new()
	b.add("cone", Vector3(0, 0, 0.1), Vector3(0.022, 0.3, 0.008), Color(0.84, 0.86, 0.9), Vector3(90, 0, 0), 4)
	b.add("cone", Vector3(0, 0, -0.08), Vector3(0.018, 0.1, 0.008), Color(0.6, 0.62, 0.66), Vector3(-90, 0, 0), 4)
	return b.build(LazyFx.g("Props").toon())


static func _build_bomb() -> Mesh:
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3(0.24, 0.24, 0.24), Color(0.1, 0.1, 0.12), Vector3.ZERO, 10)
	b.add("cyl", Vector3(0, 0.13, 0), Vector3(0.05, 0.05, 0.05), Color(0.45, 0.35, 0.2), Vector3.ZERO, 6)
	return b.build(LazyFx.g("Props").toon())


static func _build_weight() -> Mesh:
	var b = MB.new()
	b.add("cyl", Vector3.ZERO, Vector3(0.09, 0.16, 0.09), Color(0.3, 0.31, 0.35), Vector3(90, 0, 0), 8)
	return b.build(LazyFx.g("Props").toon())


static func _build_link() -> Mesh:
	var c = CylinderMesh.new()
	c.top_radius = 0.016
	c.bottom_radius = 0.016
	c.height = 1.0
	c.radial_segments = 5
	c.rings = 1
	return c


# ------------------------------------------------------------------ cephane
static func _ammo(who: Node3D) -> int:
	return int(who.get_meta("tk_ammo", AMMO))


static func _spend(who: Node3D, n: int) -> int:
	var have = _ammo(who)
	if have <= 0:
		Sfx.play("click", who.global_position + Vector3.UP * 1.2, 0.6, 0.8)
		if who is Player:
			Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Kabuk boş: parşömen sür", Color(0.85, 0.88, 0.92))
		return 0
	var u = mini(n, have)
	who.set_meta("tk_ammo", have - u)
	return u


static func _port(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	if n == null:
		return who.global_position + Vector3.UP * 1.2 + who.face_dir() * 0.6
	var a = randi() % 3 * TAU / 3.0
	return n.to_global(Vector3(0.14, cos(a) * 0.285, sin(a) * 0.285))


# ------------------------------------------------------------------ atışlar
static func _needle(who: Node3D, from: Vector3, dir: Vector3, dmg: float) -> void:
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = Kit.cached_mesh("tk_needle", Callable(_build_needle))
	v.rotation.y = PI
	root.add_child(v)
	U.fire(who, from, dir.normalized() * 58.0, {"g": 0.8, "r": 0.1, "life": 0.85, "stick": true, "vis": root,
		"info": {"dmg": dmg, "knock": 0.3, "kind": "light", "bleed": 0.8, "hitstop": 0.0}})


static func _fan(who: Node3D, aim: Vector3, n: int, dmg: float) -> void:
	var u = _spend(who, n)
	var from = _port(who)
	var d = (aim - from).normalized()
	for k in u:
		_needle(who, _port(who), d.rotated(Vector3.UP, deg_to_rad((k - (u - 1) * 0.5) * 5.5)), dmg)
	if u > 0:
		Sfx.play("throw", from, 1.7, 0.6)


static func _chain(who: Node3D, tg, aim: Vector3, dmg: float) -> void:
	if _spend(who, 2) <= 0:
		return
	var from = _port(who)
	var w = MeshInstance3D.new()
	w.mesh = Kit.cached_mesh("tk_weight", Callable(_build_weight))
	var link = MeshInstance3D.new()
	link.mesh = Kit.cached_mesh("tk_link", Callable(_build_link))
	link.material_override = LazyFx.g("Props").toon_color(Color(0.2, 0.2, 0.24), 0.3)
	link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	link.extra_cull_margin = 20.0
	var s = {"t": 0.0, "hit": false}
	var T = 0.62
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var k = float(s["t"]) / T
		if k >= 1.0 or not is_instance_valid(who):
			return true
		var o = _port_fixed(who)
		var c: Vector3 = U.chest(tg) if U.alive(tg) else aim
		var p = o.lerp(c, sin(minf(k / 0.8, 1.0) * PI * 0.5)) if k < 0.8 else c.lerp(o, (k - 0.8) / 0.2)
		w.global_position = p
		var d = p - o
		var L = maxf(d.length(), 0.03)
		var y = d / L
		var x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
		link.global_transform = Transform3D(Basis(x, y * L, x.cross(y)), (o + p) * 0.5)
		if k >= 0.42 and not bool(s["hit"]):
			s["hit"] = true
			if U.alive(tg) and p.distance_to(U.chest(tg)) < 1.4:
				tg.take_hit({"dmg": dmg * 0.7, "knock": 0.0, "kind": "light", "hitstop": 0.05, "melee": true, "attacker": who, "dir": (c - o).normalized()})
				if tg.has_method("apply_status"):
					tg.apply_status("bind", 1.1)
				U.credit(who, tg)
				Sfx.play("hit_chain", p, 1.0, 0.8)
		return false
	var root = Kit.ticker(from, fn)
	root.add_child(w)
	root.add_child(link)
	w.global_position = from
	link.global_transform = Transform3D(Basis.from_scale(Vector3.ZERO), from)
	Sfx.play("swing_chain", from, 1.1, 0.8)


static func _port_fixed(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	return n.to_global(Vector3(0.14, 0.0, 0.0)) if n != null else who.global_position + Vector3.UP * 1.2


static func _bomb(who: Node3D, to: Vector3, dmg: float) -> void:
	var from = _port(who)
	var root = Node3D.new()
	var v = MeshInstance3D.new()
	v.mesh = Kit.cached_mesh("tk_bomb", Callable(_build_bomb))
	root.add_child(v)
	var boom = func(p: Vector3, _t: Node3D) -> void:
		if is_instance_valid(who):
			_blast(who, p, dmg)
	U.fire(who, from, U.lob(from, to, 0.6, 16.0), {"g": 16.0, "r": 0.16, "life": 1.3, "vis": root, "hit": boom,
		"info": {"dmg": dmg * 0.2, "knock": 0.5, "kind": "light", "hitstop": 0.0}})


static func _blast(who: Node3D, p: Vector3, dmg: float) -> void:
	var mi = Kit.quad(Kit.scene(), 5.0, Kit.shader_mat("tk_blast", BLAST_SH))
	mi.global_position = p + Vector3.UP * 0.5
	Kit.tween_param(mi, "prog", 0.0, 1.0, 0.32, true)
	Combat.hit_sphere(who, p + Vector3.UP * 0.5, 2.1, {"dmg": dmg, "knock": 7.0, "launch": 2.5, "kind": "heavy", "hitstop": 0.05})
	Sfx.play("boom", p, 1.3, 0.7)


## Rapid Fire: kabuğun her yönüne iğne dalgaları
static func _storm_wave(who: Node3D, k: int, dmg: float) -> void:
	if not is_instance_valid(who) or who.is_dead():
		return
	var u = _spend(who, 3)
	if u <= 0:
		return
	var c = who.global_position + Vector3.UP * 1.15
	for j in 10:
		var a = TAU * j / 10.0 + k * 0.31
		var d = Vector3(cos(a), randf_range(-0.12, 0.2), sin(a))
		_needle(who, c + Vector3(d.x, 0, d.z) * 0.45, d, dmg)
	Sfx.play("throw", c, 1.5 + k * 0.03, 0.5)


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 0:
		TateFX._window(who, 0.04, 0.3)
	elif i == 3:
		TateFX._window(who, 0.06, 0.9)
	elif i == 5:
		TateFX._window(who, 0.05, 0.42)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	who.set_meta("tate_dmg", dmg)
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	if i == 0:
		return
	U.face(who, aim)
	if i == 1:
		_fan(who, aim, 7, dmg * 0.24)
	elif i == 2:
		_chain(who, tg, aim, dmg)
	elif i == 3:
		who.set_meta("tk_ammo", AMMO)
		Combat.popup_text(who.global_position + Vector3.UP * 2.1, "Dolduruldu", Color(0.85, 0.92, 0.85))
		Sfx.play("click", who.global_position + Vector3.UP * 1.2, 1.2, 0.8)
	elif i == 4:
		var u = _spend(who, 3)
		var f = aim - who.global_position
		f.y = 0.0
		var side = f.normalized().cross(Vector3.UP)
		for k in u:
			var q = aim + side * (k - 1) * 2.4
			q.y = Game.jutsu_floor_at(q).y
			_bomb(who, q, dmg * 0.75)
	else:
		for k in 6:
			who.get_tree().create_timer(k * 0.1).timeout.connect(_storm_wave.bind(who, k, dmg * 0.16))
