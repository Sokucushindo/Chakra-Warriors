extends RefCounted
## Nobi-ude: model, buhar, avuç teli ve uçan el (hedef: res://scripts/combat/fx/nobi_ude_fx.gd). Kanon (Retractable Cable Arm): avucu delikli mekanik el; delikten bağlama teli çıkar, el uzayıp uzaktan yakalar ve yere çakar; buhar basıncı fiziksel darbeyi güçlendirir.
## Ref: kara küre avuç, ortada delik, beş boğumlu gri parmak, hortum. Oyuncu ve düşman aynı kod.

const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "nobi_ude"
const REACH := 11.0
const HOLD := 2.2
const LIFT_H := 3.2

const STEAM_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float w = 0.5 + 0.5 * sin(UV.x * 16.0 - TIME * 15.0 + UV.y * 7.0);
	ALBEDO = vec3(0.93, 0.95, 0.96);
	ALPHA = smoothstep(0.1 + 0.3 * w * UV.x, 0.7, e) * (1.0 - UV.x) * fade_k * 0.85;
	if (ALPHA < 0.02) discard;
}
"""

const WIRE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	ALBEDO = vec3(0.55, 0.57, 0.62);
}
"""


static func _hand(b: MB, o: Vector3, spread: float) -> void:
	var black = Color(0.13, 0.13, 0.15)
	var grey = Color(0.5, 0.51, 0.56)
	b.add("sphere", o, Vector3.ONE * 0.3, black, Vector3.ZERO, 16)
	b.add("cyl", o + Vector3(0, 0, 0.145), Vector3(0.05, 0.012, 0.05), Color(0.03, 0.03, 0.04), Vector3(90, 0, 0), 12)
	b.add("cyl", o + Vector3(0, 0, 0.138), Vector3(0.075, 0.008, 0.075), black.lightened(0.12), Vector3(90, 0, 0), 12)
	for k in 5:
		var a = TAU * k / 5.0 + 0.5
		var d = Vector3(cos(a), sin(a), spread).normalized()
		var x = d.cross(Vector3.BACK if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
		var z = x.cross(d)
		for j in 3:
			var c = o + d * (0.17 + j * 0.075)
			var w = 0.052 + j * 0.008
			b.add_xf("box", Transform3D(Basis(x * w, d * 0.07, z * 0.024), c), grey.darkened(j * 0.06))


## Ön kol çerçevesi: +Z bileğe. nobi_ude tam; _sap yalnız kolluk; _el yalnız el (merkez 0, +Z avuç)
static func model(b: MB, id: String) -> void:
	if id == "nobi_ude_el":
		_hand(b, Vector3.ZERO, 0.6)
		return
	var grey = Color(0.46, 0.47, 0.52)
	var dk = Color(0.22, 0.23, 0.27)
	b.add("cyl", Vector3(0, 0, -0.03), Vector3(0.13, 0.26, 0.13), grey, Vector3(90, 0, 0), 12)
	for z in [-0.13, 0.08]:
		b.add("cyl", Vector3(0, 0, z), Vector3(0.145, 0.03, 0.145), dk, Vector3(90, 0, 0), 12)
	b.add("cyl", Vector3(0.065, 0.02, -0.12), Vector3(0.024, 0.18, 0.024), dk, Vector3(70, 0, 0), 6)   # buhar hortumu
	b.add("cyl", Vector3(0.05, 0.075, -0.2), Vector3(0.03, 0.05, 0.03), grey.darkened(0.2), Vector3(30, 0, 0), 6)
	if id == "nobi_ude":
		_hand(b, Vector3(0, 0, 0.24), 0.75)


static func _palm(who: Node3D) -> Vector3:
	var n = Yk.node_of(who, ID)
	return n.to_global(Vector3(0, 0, 0.3)) if n != null else who.global_position + Vector3.UP * 1.25 + Yk.face(who) * 0.6


static func _elbow(who: Node3D) -> Vector3:
	var n = Yk.node_of(who, ID)
	return n.to_global(Vector3(0, 0, 0.09)) if n != null else who.global_position + Vector3.UP * 1.25


static func _swap(who: Node3D, mesh_id: String) -> void:
	var n = Yk.node_of(who, ID)
	if n is MeshInstance3D:
		(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh(mesh_id)


## Buhar: dirsekten geriye iki kısa fışkırma
static func _steam(who: Node3D, k: float) -> void:
	var n = Yk.node_of(who, ID)
	var o: Vector3 = n.to_global(Vector3(0.09, 0.02, -0.14)) if n != null else who.global_position + Vector3.UP * 1.3
	var f = Yk.face(who)
	var m = Yk.mat("nobi_steam", STEAM_SH)
	for s in [-1.0, 1.0]:
		var side = f.cross(Vector3.UP).normalized() * s
		var pts = []
		for j in 7:
			var u = j / 6.0
			pts.append(o - f * (1.3 * k) * u + side * 0.28 * u + Vector3.UP * (0.42 * u * u))
		Yk.fade(Yk.strip(pts, 0.05 + 0.08 * k, m, -0.9), 0.05, 0.28)
	Sfx.play("th_steam", o, 1.3, 0.3 + 0.3 * k)


## Tek tel: avuçtan hedefe
static func _wire(who: Node3D, tg, aim: Vector3) -> void:
	var s = {"t": 0.0, "hit": false}
	var T = 0.5
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = Yk.mat("nobi_wire", WIRE_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 30.0
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var k = float(s["t"]) / T
		if k >= 1.0 or not is_instance_valid(who):
			return true
		var a = _palm(who)
		var c: Vector3 = U.chest(tg) if U.alive(tg) else aim
		var b = a.lerp(c, minf(k * 3.0, 1.0))
		var d = (b - a).normalized()
		var side = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized() * 0.012
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		im.surface_add_vertex(a - side)
		im.surface_add_vertex(a + side)
		im.surface_add_vertex(b - side)
		im.surface_add_vertex(b + side)
		im.surface_end()
		if k >= 0.33 and not bool(s["hit"]):
			s["hit"] = true
			if U.alive(tg) and a.distance_to(c) <= REACH + 1.0:
				if tg.has_method("apply_status"):
					tg.apply_status("bind", 1.0)
				Combat.popup_text(tg.global_position + Vector3.UP * 2.2, "Tele sarıldı!", Color(0.8, 0.84, 0.9))
				Sfx.play("clink", c, 1.6, 0.6)
		return false
	var root = Kit.ticker(who.global_position, fn)
	root.add_child(mi)
	mi.top_level = true
	mi.global_transform = Transform3D.IDENTITY


static func _build_link() -> Mesh:
	var b = MB.new()   # zincir çizgisi parçayı +Z boyunca dizer
	b.add("cyl", Vector3.ZERO, Vector3(0.05, 0.24, 0.05), Color(0.12, 0.12, 0.14), Vector3(90, 0, 0), 6)
	return b.build(LazyFx.g("Props").toon())


## El uçar: path(k), yakalarsa hedefi taşıyıp getirir
static func _fly(who: Node3D, tg, aim: Vector3, dmg: float) -> void:
	_swap(who, "nobi_ude_sap")
	var el = MeshInstance3D.new()
	el.mesh = CharacterModel.weapon_mesh("nobi_ude_el")
	var s = {"t": 0.0, "got": false, "pos": _palm(who)}
	var T = 0.68
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var k = float(s["t"]) / T
		if k >= 1.0 or not is_instance_valid(who) or who.is_dead():
			if is_instance_valid(who):
				_swap(who, ID)
			return true
		var a = _palm(who)
		var c: Vector3 = U.chest(tg) if U.alive(tg) else aim
		var p: Vector3
		if k < 0.42:
			p = a.lerp(c, sin(k / 0.42 * PI * 0.5))
		else:
			p = c.lerp(a + Yk.face(who) * 1.3, smoothstep(0.42, 1.0, k))
		if k >= 0.42 and not bool(s["got"]):
			s["got"] = true
			if U.alive(tg) and (s["pos"] as Vector3).distance_to(U.chest(tg)) < 1.6:
				if Yk.height_of(tg) <= LIFT_H:   # dev gövde taşınmaz, yalnız vurulur
					s["held"] = tg
					who.set_meta("nobi_h", tg.get_instance_id())
					who.set_meta("nobi_t", Game.now() + HOLD)
				tg.take_hit({"dmg": dmg * 0.75, "knock": 0.0, "kind": "light", "hitstop": 0.05, "melee": true, "attacker": who, "dir": Yk.face(who)})
				if tg.has_method("apply_status"):
					tg.apply_status("bind", 0.9)
				U.credit(who, tg)
				Sfx.play("hit_heavy", c, 1.0, 0.7)
		s["pos"] = p
		var held = s.get("held")
		if U.alive(held) and k > 0.42:
			var q = Vector3(p.x, held.global_position.y, p.z)
			held.global_position = PlayerCombat.safe_dest(held, held.global_position, q)
		var d = p - a
		var z = d.normalized() if d.length() > 0.05 else Yk.face(who)
		var x = z.cross(Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT).normalized()
		el.global_transform = Transform3D(Basis(x, z.cross(x), z), p)
		return false
	var root = Kit.ticker(who.global_position, fn)
	root.add_child(el)
	el.global_position = s["pos"]
	var a_fn = func() -> Vector3:
		return _elbow(who) if is_instance_valid(who) else Vector3.ZERO
	var b_fn = func() -> Vector3:
		return el.global_position if is_instance_valid(el) else a_fn.call()
	Yk.chain(root, Yk.mesh("nobi_link", Callable(_build_link)), a_fn, b_fn, T, 64, 0.17, 0.05)
	Sfx.play("swing_chain", who.global_position + Vector3.UP, 0.9, 0.8)


static func _held(who: Node3D) -> Node3D:
	if Game.now() > float(who.get_meta("nobi_t", 0.0)):
		return null
	var id = int(who.get_meta("nobi_h", 0))
	if not is_instance_id_valid(id):
		return null
	var o = instance_from_id(id)
	return o if U.alive(o) else null


## Tataki: yakalananı kaldırıp yere çakar
static func _slam(who: Node3D, h: Node3D, dmg: float) -> void:
	var from = h.global_position
	var to = who.global_position + Yk.face(who) * 1.7
	to.y = Game.ground_height(to.x, to.z) + 0.05
	who.set_meta("nobi_t", 0.0)
	if h.has_method("apply_status"):
		h.apply_status("bind", 0.55)
	var arc = func(k: float) -> void:
		if is_instance_valid(h):
			h.global_position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 3.4
			if h is CharacterBody3D:
				h.velocity = Vector3.ZERO
	var land = func() -> void:
		if not is_instance_valid(h) or not is_instance_valid(who):
			return
		h.global_position = PlayerCombat.safe_dest(h, to + Vector3.UP * 0.1, to)
		h.take_hit({"dmg": dmg * 1.5, "knock": 1.0, "stun": 0.55, "kind": "heavy", "hitstop": 0.1, "melee": true, "attacker": who, "dir": Yk.face(who)})
		Sfx.play("hit_heavy_weapon", to, 0.6, 1.0)
		Yk.shake(who, 0.55)
	var tw = h.create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.36)
	tw.tween_callback(land)


static func start(who: Node3D, i: int) -> void:
	if who != null and is_instance_valid(who) and i in [2, 3]:
		U.face(who, U.aim_at(who, U.target_of(who)))


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	if i == 0 or i == 1:
		_steam(who, 0.55)
	elif i == 2:
		U.face(who, aim)
		_wire(who, tg, aim)
	elif i == 3:
		U.face(who, aim)
		_fly(who, tg, aim, dmg)
	elif i == 4:
		var h = _held(who)
		if h != null:
			_slam(who, h, dmg)
		else:
			var g = who.global_position + Vector3.UP * 0.8 + Yk.face(who) * 1.9
			Combat.hit_sphere(who, g, 1.6, {"dmg": dmg * 0.9, "knock": 3.0, "kind": "heavy", "hitstop": 0.07, "melee": true})
			Yk.shake(who, 0.3)
	elif i == 5:
		_steam(who, 1.0)
		Yk.shake(who, 0.4)
