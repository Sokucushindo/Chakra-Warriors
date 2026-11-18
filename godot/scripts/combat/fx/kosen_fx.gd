extends RefCounted
## Kōsen (鋼線, çelik tel; Narutopedia "Wire Strings", hedef: res://scripts/combat/fx/kosen_fx.gd). Kullanıcılar: Sasuke, Kakashi, Chiyo, Kin, Kushimaru, Tenten...
## Kanon: ince ve çok dayanıklı tel; tuzak kurar, rakibi bağlar, silah yönetir. Sasuke telleri bağlayıp Ryūka'yı telden hedefe akıtır (Dragon Fire Technique).
## Mekanik (alet tuşu, tek atış): ucu kısa kunaili tel fırlar.
##   Rakibe değerse: dolanır, bağlar; atan Katon doğasına sahipse ve chakrası yetiyorsa ateş telden koşup hedefi yakar.
##   Yere / duvara düşerse: iki yana gerilip ayak hizasında tuzak olur; üstünden koşan tökezleyip düşer, tel kopar. Zıplayan ve duran etkilenmez.
## Dev gövde bağlanmaz. Görünen her şey bu dosyada. Oyuncu ve düşman aynı kod.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const SPEED := 46.0
const HIT_DMG := 4.0
const BIND_T := 1.5
const MAX_H := 3.4
const FIRE_COST := 0.06
const FIRE_DMG := 16.0
const TRAP_T := 14.0
const TRAP_HALF := 5.0
const TRIP_DMG := 6.0

const WIRE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float len_m = 1.0;
instance uniform float heat = 0.0;
varying float along;
void vertex() {
	along = VERTEX.y + 0.5;
}
void fragment() {
	float g = smoothstep(0.86, 1.0, sin(along * len_m * 2.4 - TIME * 8.0));   // telde kayan parıltı (Wire_Strings.png)
	ALBEDO = mix(mix(vec3(0.62, 0.66, 0.74), vec3(1.0), g), vec3(1.0, 0.55, 0.15), heat);
	ALPHA = mix(0.5 + 0.5 * g, 1.0, heat);
}
"""

const FLAME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float w = 0.1 * sin(p.y * 7.0 + TIME * 22.0);
	float m = 1.0 - smoothstep(0.1, 0.75, length(vec2((p.x + w) * (1.5 + p.y), p.y * 0.72)));
	ALBEDO = mix(vec3(1.0, 0.3, 0.05), vec3(1.0, 0.92, 0.55), m);
	ALPHA = clamp(m * 1.5, 0.0, 1.0);
	if (ALPHA < 0.02) discard;
}
"""


static func _head_mesh() -> Mesh:
	return Kit.cached_mesh("kosen_head", func():
		var b = MB.new()
		var steel = Color(0.3, 0.32, 0.36)
		b.add("cone", Vector3(0, 0, 0.09), Vector3(0.07, 0.18, 0.018), steel, Vector3(90, 0, 0), 4)
		b.add("cyl", Vector3(0, 0, -0.04), Vector3(0.018, 0.1, 0.018), Color(0.14, 0.14, 0.16), Vector3(90, 0, 0), 5)
		b.add("torus", Vector3(0, 0, -0.1), Vector3(0.05, 0.05, 0.05), Color(0.2, 0.2, 0.23), Vector3(90, 0, 0), 8)
		return b.build(Props.toon()))


## Birim boy (Y), sabit incelikte iki çapraz şerit: her açıdan görünür
static func _wire_mesh() -> Mesh:
	return Kit.cached_mesh("kosen_wire", func():
		var w = 0.008
		var v = PackedVector3Array([Vector3(-w, -0.5, 0), Vector3(w, -0.5, 0), Vector3(w, 0.5, 0), Vector3(-w, 0.5, 0),
			Vector3(0, -0.5, -w), Vector3(0, -0.5, w), Vector3(0, 0.5, w), Vector3(0, 0.5, -w)])
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
		var m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m)


static func _wire(parent: Node3D) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _wire_mesh()
	mi.material_override = Kit.shader_mat("kosen_wire", WIRE_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 30.0
	parent.add_child(mi)
	return mi


static func _span(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d = b - a
	var L = maxf(d.length(), 0.02)
	var y = d / L
	var x = y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(x, y * L, x.cross(y)), (a + b) * 0.5)
	mi.set_instance_shader_parameter("len_m", L)


static func _hand(who: Node3D) -> Vector3:
	var pj = PathJutsu.get_pinst()
	return pj.hand_pos(who, true) if pj != null else Kit.chest(who)


static func _katon(who: Node3D) -> bool:
	if who is Player:
		return "katon" in (Game.profile.get("elements", []) as Array)
	return str(who.get("element")) == "katon" if who.get("element") != null else false


static func _pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


static func _dodging(t: Node3D) -> bool:
	return (t is Player and float(t.evade_t) > 0.0) or (t is Enemy and String(t.state) == "dodge")


# ------------------------------------------------------------------ atış
static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "kosen", SPEED, 2.5, _head_mesh(), HIT_DMG * Kit.tool_mult(who))
	pr.life = 0.62
	pr.info["knock"] = 0.0
	(pr.get_child(0) as Node3D).rotation.y = PI   # mermi -Z yönüne bakar, model ucu +Z
	var fly = {"pr": pr}
	var alive = func(_dt: float) -> bool:
		return not is_instance_valid(fly["pr"]) or bool((fly["pr"] as Projectile).dead) or not is_instance_valid(who)
	var root = Kit.ticker(start, alive)
	var w = _wire(root)
	var follow = func(_p, _dt) -> void:
		if is_instance_valid(w) and is_instance_valid(who):
			_span(w, _hand(who), pr.global_position)
	pr.on_tick = follow
	pr.on_hit = func(pos: Vector3, t: Node3D) -> void:
		if not is_instance_valid(who):
			return
		if t != null and is_instance_valid(t) and not _dodging(t) and not t.is_dead():
			_bind(who, t)
		else:
			_trap(who, pos, Vector3(dir.x, 0, dir.z).normalized())
	Sfx.play("swing_chain", start, 1.9, 0.45)
	return pr


# ------------------------------------------------------------------ bağlama
static func _bind(who: Node3D, t: Node3D) -> void:
	var fits = Kit.height_of(t) <= MAX_H
	if fits and t.has_method("apply_status"):
		t.apply_status("bind", BIND_T)
		Combat.popup_text(t.global_position + Vector3.UP * (Kit.height_of(t) + 0.3), "Tele dolandı!", Color(0.8, 0.86, 0.95))
	Sfx.play("clink", t.global_position + Vector3.UP, 1.7, 0.7)
	var fire = fits and _katon(who) and _pay(who, FIRE_COST)
	var s = {"t": 0.0, "burnt": false}
	var dur = BIND_T if fits else 0.25
	var coils: Array = []
	var n := {}   # düğümler işlevden sonra kurulur: işlev sözlüğü yakalar
	var fn = func(dt: float) -> bool:
		var main_w: MeshInstance3D = n["w"]
		var flame = n.get("flame")
		s["t"] += dt
		var k: float = s["t"]
		if k >= dur or not is_instance_valid(who) or not is_instance_valid(t) or t.is_dead():
			return true
		if who.has_method("has_status") and who.has_status("stun"):
			return true   # tutan sersemledi: tel gevşer
		var c = Kit.chest(t)
		var h = _hand(who)
		_span(main_w, h, c)
		var r = maxf(float(t.get("radius")) if t.get("radius") != null else 0.4, 0.3) + 0.08
		var ht = Kit.height_of(t)
		for i in coils.size():
			var y = t.global_position.y + ht * (0.3 + i * 0.13)
			var tilt = Basis(Vector3.RIGHT, 0.16 * (1 if i % 2 == 0 else -1))
			coils[i].global_transform = Transform3D(tilt.scaled(Vector3(r * 2.0, 1.0, r * 2.0)), Vector3(c.x, y, c.z))
		if fire and flame != null:
			var u = clampf((k - 0.22) / 0.34, 0.0, 1.0)
			flame.visible = k > 0.22 and u < 1.0
			flame.global_position = h.lerp(c, u)
			main_w.set_instance_shader_parameter("heat", clampf(u * 1.6, 0.0, 1.0) * (1.0 - clampf((k - 0.8) / 0.4, 0.0, 1.0)))
			if u >= 1.0 and not bool(s["burnt"]):
				s["burnt"] = true
				t.take_hit({"dmg": FIRE_DMG * Kit.tool_mult(who), "knock": 0.0, "kind": "light", "element": "katon", "attacker": who, "dir": Vector3.ZERO, "tool": "kosen"})
				if t.has_method("apply_status"):
					t.apply_status("burn", 3.0)
				Sfx.play("fire", c, 1.2, 0.8)
		return false
	var root = Kit.ticker(t.global_position, fn)
	n["w"] = _wire(root)
	(n["w"] as MeshInstance3D).global_transform = Transform3D(Basis.from_scale(Vector3.ZERO), t.global_position)
	if fits:
		var make_coil = func() -> Mesh:
			var m = TorusMesh.new()
			m.inner_radius = 0.49
			m.outer_radius = 0.5
			m.rings = 26
			m.ring_segments = 4
			return m
		var tm = Kit.cached_mesh("kosen_coil", make_coil)
		for i in 4:
			var q = MeshInstance3D.new()
			q.mesh = tm
			q.material_override = Kit.shader_mat("kosen_wire", WIRE_SH)
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(q)
			q.global_transform = Transform3D(Basis.from_scale(Vector3.ZERO), t.global_position)
			coils.append(q)
	if fire:
		n["flame"] = Kit.quad(root, 0.75, Kit.shader_mat("kosen_flame", FLAME_SH))
		(n["flame"] as MeshInstance3D).visible = false
		Sfx.play("fire", _hand(who), 1.5, 0.5)


# ------------------------------------------------------------------ tuzak
static func _anchor(from: Vector3, d: Vector3, who: Node3D) -> Vector3:
	var q = PhysicsRayQueryParameters3D.create(from, from + d * TRAP_HALF, 1)
	var hit = who.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit["position"]
	var p = from + d * TRAP_HALF
	p.y = Game.jutsu_floor(p.x, p.z) + 0.3
	return p


static func _trap(who: Node3D, pos: Vector3, f: Vector3) -> void:
	if f.length() < 0.1:
		f = Vector3.FORWARD
	var side = Vector3.UP.cross(f).normalized()
	var c = Vector3(pos.x, Game.jutsu_floor(pos.x, pos.z) + 0.3, pos.z)
	var a = _anchor(c, side, who)
	var b = _anchor(c, -side, who)
	var s = {"t": 0.0, "acc": 0.0}
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who):
			return true
		s["t"] += dt
		if float(s["t"]) >= TRAP_T:
			return true
		s["acc"] += dt
		if float(s["acc"]) < 0.05:
			return false
		s["acc"] = 0.0
		var ab = Vector2(b.x - a.x, b.z - a.z)
		var len2 = maxf(ab.length_squared(), 0.01)
		for x in Kit.fighters():
			if not Combat.hostile(who, x) or x.is_dead() or x.get("grounded") == false:
				continue
			var v = x.get("velocity")
			if v is Vector3 and Vector2(v.x, v.z).length() < 1.5:
				continue   # yürür gibi yavaş geçen teli görür; koşan takılır
			var p: Vector3 = x.global_position
			if absf(p.y + 0.3 - lerpf(a.y, b.y, 0.5)) > 1.3:
				continue
			var ap = Vector2(p.x - a.x, p.z - a.z)
			var u = clampf(ap.dot(ab) / len2, 0.0, 1.0)
			var fr = float(x.get("radius")) if x.get("radius") != null else 0.4
			if (ap - ab * u).length() > fr + 0.2:
				continue
			if x.has_method("apply_status"):
				x.apply_status("bind", 0.8)
			x.take_hit({"dmg": TRIP_DMG * Kit.tool_mult(who), "knock": 0.0, "kind": "heavy", "attacker": who, "dir": Vector3(v.x, 0, v.z).normalized() if v is Vector3 else f, "tool": "kosen", "melee": true})
			Combat.popup_text(p + Vector3.UP * (Kit.height_of(x) + 0.3), "Tele takıldı!", Color(0.85, 0.88, 0.95))
			Sfx.play("clink", p, 2.1, 0.8)
			return true
		return false
	var root = Kit.ticker(c, fn)
	_span(_wire(root), a, b)
	for e in [a, b]:
		var peg = MeshInstance3D.new()
		peg.mesh = _head_mesh()
		root.add_child(peg)
		peg.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), e)   # uç aşağıda, yere saplı
	Sfx.play("clink", c, 1.4, 0.45)
