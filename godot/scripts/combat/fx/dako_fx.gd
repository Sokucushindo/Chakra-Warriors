extends RefCounted
## Dakō: model, uzayıp bükülen gövde ve uç (hedef: res://scripts/combat/fx/dako_fx.gd). Kanon: Iō'nun prototipi; haç biçimli mızrak; uzar, kısalır, her yöne bükülür, taşı deler, havada yön değiştirir, kullanana manevra sağlar.
## Ref Dako.PNG: koyu yassı şerit gövde, burgulu çelik matkap uç, iki yana kıvrık kanca (haç), arkasında turuncu püskül; elde sivri kuyruk. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "dako"

const BAND_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float e = abs(UV.y * 2.0 - 1.0);
	vec3 c = FRONT_FACING ? vec3(0.17, 0.18, 0.25) : vec3(0.1, 0.1, 0.15);
	ALBEDO = mix(c, vec3(0.03, 0.03, 0.05), smoothstep(0.8, 0.95, e));
}
"""


# ------------------------------------------------------------------ model
static func _head(b: MB, z: float) -> void:
	var steel = Color(0.68, 0.7, 0.76)
	var dk = Color(0.33, 0.34, 0.4)
	for k in 4:
		var u = k / 4.0
		b.add("cone", Vector3(0, 0, z + 0.06 + u * 0.2), Vector3(0.13 * (1.0 - u * 0.7), 0.16, 0.13 * (1.0 - u * 0.7)), steel if k % 2 == 0 else dk, Vector3(90, 0, 0), 10)
	for s in [-1.0, 1.0]:   # haç kancaları
		b.add("cone", Vector3(0.1 * s, 0, z + 0.0), Vector3(0.028, 0.2, 0.05), steel, Vector3(0, 0, -90 * s), 4)
		b.add("cone", Vector3(0.19 * s, 0, z + 0.06), Vector3(0.018, 0.12, 0.035), steel, Vector3(55, 0, -30 * s), 4)
	var fur = Color(0.9, 0.56, 0.36)
	for k in 9:
		var a = TAU * k / 9.0
		b.add("cone", Vector3(cos(a) * 0.05, sin(a) * 0.05, z - 0.08), Vector3(0.06, 0.24, 0.03), fur.darkened((k % 2) * 0.12), Vector3(-90 + sin(a) * 42.0, 0, -cos(a) * 42.0), 3)


static func _handle(b: MB) -> void:
	var dark = Color(0.17, 0.18, 0.25)
	b.add("box", Vector3(0, 0, 0.0), Vector3(0.05, 0.024, 0.4), dark)
	b.add("cone", Vector3(0, 0, -0.28), Vector3(0.05, 0.16, 0.024), dark.darkened(0.3), Vector3(-90, 0, 0), 4)
	b.add("cyl", Vector3(0, 0, -0.02), Vector3(0.046, 0.13, 0.046), Color(0.32, 0.22, 0.15), Vector3(90, 0, 0), 8)


## dako: kısa (toplanmış) biçim; dako_sap: uç uçarken elde kalan; dako_bas: yalnız uç (merkez 0)
static func model(b: MB, id: String) -> void:
	if id == "dako_bas":
		_head(b, 0.0)
		return
	_handle(b)
	if id == "dako":
		b.add("box", Vector3(0, 0, 0.62), Vector3(0.05, 0.024, 0.9), Color(0.17, 0.18, 0.25))
		_head(b, 1.14)


# ------------------------------------------------------------------ gövde
static func _hand(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	return n.to_global(Vector3(0, 0, 0.2)) if n != null else who.global_position + Vector3.UP * 1.3


static func _ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 26
	var prev = a
	var last_dir = (c - b).normalized()
	for i in n + 1:
		var u = float(i) / n
		var p = a.lerp(b, u).lerp(b.lerp(c, u), u)
		var d = p - prev if i > 0 else b - a
		if d.length() > 0.0005:
			last_dir = d.normalized()
		var s = last_dir.cross(Vector3.UP if absf(last_dir.y) < 0.9 else Vector3.RIGHT).normalized() * lerpf(0.035, 0.085, u)
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(p - s)
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(p + s)
		prev = p
	im.surface_end()
	return last_dir


## path(k) -> [bükülme noktası, uç]; tick(k, uç) isteğe bağlı
static func _lash(who: Node3D, T: float, path: Callable, tick := Callable()) -> void:
	var n = U.weapon_node(who, ID)
	if n == null or not (n is MeshInstance3D):
		return
	var tok = int(who.get_meta("dako_tok", 0)) + 1
	who.set_meta("dako_tok", tok)
	(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("dako_sap")
	var head = MeshInstance3D.new()
	head.mesh = CharacterModel.weapon_mesh("dako_bas")
	var im = ImmediateMesh.new()
	var band = MeshInstance3D.new()
	band.mesh = im
	band.material_override = Kit.shader_mat("dako_band", BAND_SH)
	band.extra_cull_margin = 30.0
	var s = {"t": 0.0}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var k = float(s["t"]) / T
		if k >= 1.0 or not is_instance_valid(who) or not is_instance_valid(n) or who.is_dead():
			if is_instance_valid(n) and is_instance_valid(who) and int(who.get_meta("dako_tok", 0)) == tok:
				(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh(ID)
			return true
		var pts: Array = path.call(k)
		var a = _hand(who)
		var dir = _ribbon(im, a, pts[0], pts[1])
		var x = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		head.global_transform = Transform3D(Basis(x, dir.cross(x), dir), pts[1])
		if tick.is_valid():
			tick.call(k, pts[1])
		return false
	var root = Kit.ticker(who.global_position, fn)
	root.add_child(band)
	band.top_level = true
	band.global_transform = Transform3D.IDENTITY
	root.add_child(head)
	head.global_position = n.global_position
	Sfx.play("swing_chain", who.global_position + Vector3.UP, 1.5, 0.6)


static func _out(k: float) -> float:
	return sin(clampf(k, 0.0, 1.0) * PI)   # gider, döner


static func _hit(who: Node3D, p: Vector3, r: float, info: Dictionary, done: Array) -> void:
	var hits = Combat.hit_sphere(who, p, r, info, done)
	for h in hits:
		U.credit(who, h)
	done.append_array(hits)


# ------------------------------------------------------------------ adımlar
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var from = who.global_position + Vector3.UP * 1.2
	var f: Vector3 = (aim - from).normalized()
	var flat = Vector3(f.x, 0, f.z).normalized()
	var side = flat.cross(Vector3.UP).normalized()
	var D = clampf(from.distance_to(aim) + 0.6, 4.0, 9.0)
	var done: Array = []
	var live = func() -> Vector3:
		return U.aim_at(who, tg) if U.alive(tg) else aim
	var base = {"knock": 3.0, "kind": "light", "hitstop": 0.05, "melee": true, "dmg": dmg}
	if i == 0:   # taşı delen düz saplama: hattaki herkes
		var path = func(k: float) -> Array:
			var tip = from + f * D * _out(k)
			return [from.lerp(tip, 0.5), tip]
		var tick = func(_k: float, p: Vector3) -> void:
			_hit(who, p, 0.8, {"dmg": dmg * 1.05, "knock": 4.0, "kind": "light", "hitstop": 0.05, "melee": true}, done)
		_lash(who, 0.42, path, tick)
	elif i == 1:   # S çizip yandan
		var path = func(k: float) -> Array:
			var c: Vector3 = live.call()
			var b = from.lerp(c, 0.45) + side * 3.2 * sin(k * TAU)
			return [b, from.lerp(c + side * -0.4, _out(k))]
		var tick = func(_k: float, p: Vector3) -> void:
			_hit(who, p, 0.9, base, done)
		_lash(who, 0.5, path, tick)
	elif i == 2:   # dolanır, bağlar, çeker
		_coil(who, tg, f, D, from, dmg)
	elif i == 3:   # üstünden aşıp sırta
		var path = func(k: float) -> Array:
			var c: Vector3 = live.call()
			var back = c + flat * 1.1
			var tip = from.lerp(back, smoothstep(0.0, 0.55, k)).lerp(from, smoothstep(0.72, 1.0, k))
			return [from.lerp(c, 0.5) + Vector3.UP * 5.0, tip]
		var tick = func(k: float, p: Vector3) -> void:
			if k > 0.4:
				_hit(who, p, 1.05, {"dmg": dmg * 1.3, "knock": 3.0, "kind": "heavy", "hitstop": 0.08, "melee": true}, done)
		_lash(who, 0.66, path, tick)
	elif i == 4:   # çevrede halka
		var path = func(k: float) -> Array:
			var c = who.global_position + Vector3.UP * 1.1
			var a = k * TAU * 1.5
			var r = 4.4 * sin(minf(k * 4.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.85, 1.0, k))
			var tip = c + Vector3(cos(a), 0.05, sin(a)) * r
			return [c + Vector3(cos(a - 0.9), 0.1, sin(a - 0.9)) * r * 0.75, tip]
		var tick = func(_k: float, p: Vector3) -> void:
			_hit(who, p, 1.0, {"dmg": dmg * 0.75, "knock": 5.0, "kind": "light", "hitstop": 0.04, "melee": true}, done)
		_lash(who, 0.78, path, tick)
	else:
		_snake_jump(who, from, flat, D, dmg)


## Maki: uç hedefin çevresinde döner, gövde sıkar
static func _coil(who: Node3D, tg, f: Vector3, D: float, from: Vector3, dmg: float) -> void:
	var st = {"done": false}
	var path = func(k: float) -> Array:
		var live = U.alive(tg)
		var c: Vector3 = U.chest(tg) if live else from + f * D
		if k < 0.25:
			return [from.lerp(c, 0.4), from.lerp(c, k / 0.25)]
		if k < 0.72 and live:
			var a = (k - 0.25) / 0.47 * TAU * 2.0
			var r = 0.55
			return [from.lerp(c, 0.6), c + Vector3(cos(a) * r, (k - 0.48) * 1.2, sin(a) * r)]
		return [from.lerp(c, 0.5), c.lerp(from, clampf((k - 0.72) / 0.28, 0.0, 1.0))]
	var tick = func(k: float, _p: Vector3) -> void:
		if k > 0.27 and not bool(st["done"]) and U.alive(tg):
			st["done"] = true
			tg.take_hit({"dmg": dmg * 0.8, "knock": 0.0, "kind": "light", "hitstop": 0.05, "melee": true, "attacker": who, "dir": f})
			if tg.has_method("apply_status"):
				tg.apply_status("bind", 1.0)
			U.credit(who, tg)
			Sfx.play("hit_chain", tg.global_position + Vector3.UP, 0.9, 0.7)
	_lash(who, 0.8, path, tick)


## Hebi Tobi: uç ileride yere saplanır, gövde kısalıp kullanıcıyı yol boyunca çeker
static func _snake_jump(who: Node3D, from: Vector3, flat: Vector3, D: float, dmg: float) -> void:
	var anchor = who.global_position + flat * (D + 1.5)
	anchor.y = Game.jutsu_floor(anchor.x, anchor.z) + 0.1
	var start = who.global_position
	var land = PlayerCombat.safe_dest(who, start, anchor - flat * 0.8)
	var done: Array = []
	var st = {"last": 0.0}
	var path = func(k: float) -> Array:
		var tip = from.lerp(anchor, minf(k / 0.3, 1.0))
		return [_hand(who).lerp(tip, 0.5) + Vector3.UP * 0.8 * (1.0 - k), tip]
	var tick = func(k: float, _p: Vector3) -> void:
		if k < 0.3:
			return
		var u = smoothstep(0.3, 0.9, k)
		var q = start.lerp(land, u) + Vector3.UP * sin(u * PI) * 1.2
		who.global_position = PlayerCombat.safe_dest(who, who.global_position, q) if q.distance_to(who.global_position) > 0.01 else who.global_position
		who.global_position.y = q.y
		if who is CharacterBody3D:
			who.velocity = Vector3.ZERO
		_hit(who, who.global_position + Vector3.UP, 1.3, {"dmg": dmg * 1.6, "knock": 7.0, "kind": "heavy", "hitstop": 0.08, "melee": true}, done)
		st["last"] = k
	_lash(who, 0.7, path, tick)
	Sfx.play("whoosh", start, 1.2, 0.8)


static func start(who: Node3D, _i: int) -> void:
	if who != null and is_instance_valid(who):
		U.face(who, U.aim_at(who, U.target_of(who)))
