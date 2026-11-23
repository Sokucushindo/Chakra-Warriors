extends RefCounted
## Jidanda: model, uzayan sap, gülle hareketi ve etiket patlamaları (hedef: res://scripts/combat/fx/jidanda_fx.gd).
## Kanon: Iō'nun Dakō ve Tsurukame verisiyle yaptığı dev dikenli demir gülle; içinde patlayıcı etiketler; sapı Dakō gibi uzar, kendisi de vurur; dikenler açılıp etiketleri gösterir; patlama tepmesiyle gülle havalanır, sap uzatılıp dev gürz gibi savrulur.
## Ref Jidanda.PNG, Jidanda_Tage_and_Handle.png. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const ID := "jidanda"
const BALL := 1.5     # uçan güllenin ölçeği (mesh yarıçapı 0.62)

const BAND_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float tick = step(0.82, fract(UV.x * 16.0));
	float e = abs(UV.y * 2.0 - 1.0);
	vec3 c = mix(vec3(0.34, 0.33, 0.33), vec3(0.17, 0.16, 0.16), tick);
	ALBEDO = mix(c, vec3(0.06, 0.06, 0.06), smoothstep(0.78, 0.95, e));
}
"""

const FLASH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
instance uniform float seed_k = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) + seed_k * 6.283;
	float r = (0.25 + 0.7 * sqrt(prog)) * (0.72 + 0.28 * abs(sin(a * 4.0)) * abs(sin(a * 7.0 + 2.0)));
	float m = 1.0 - smoothstep(r * 0.72, r, length(p));
	ALBEDO = mix(vec3(1.0, 0.92, 0.6), vec3(1.0, 0.32, 0.06), prog);
	ALPHA = m * (1.0 - smoothstep(0.5, 1.0, prog));
	if (ALPHA < 0.02) discard;
}
"""


# ------------------------------------------------------------------ model
static func _spike_at(b: MB, d: Vector3, r: float, L: float, w: float, col: Color, open: bool) -> void:
	var y = d.normalized()
	var x = y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z = x.cross(y)
	var base = y * (r + (0.12 if open else -0.02))
	b.add_xf("cone", Transform3D(Basis(x * w, y * L, z * w), base + y * L * 0.42), col, 8)
	if open:   # dikenin altındaki kaide ve etiket (ref 2)
		b.add_xf("cyl", Transform3D(Basis(x * w * 0.72, y * 0.16, z * w * 0.72), y * (r + 0.05)), Color(0.33, 0.33, 0.36), 8)
		b.add_xf("box", Transform3D(Basis(x * w * 0.42, y * 0.11, z * 0.008), y * (r + 0.06) + z * w * 0.37), Color(0.93, 0.89, 0.72))
		b.add_xf("box", Transform3D(Basis(x * w * 0.2, y * 0.07, z * 0.004), y * (r + 0.06) + z * (w * 0.37 + 0.008)), Color(0.7, 0.14, 0.16))


## Merkez 0, yarıçap 0.62
static func _ball(b: MB, open: bool) -> void:
	var iron = Color(0.26, 0.27, 0.32)
	var seam = Color(0.15, 0.15, 0.19)
	var spike = Color(0.56, 0.56, 0.62)
	var R = 0.62
	b.add("sphere", Vector3.ZERO, Vector3.ONE * R * 2.0, iron, Vector3.ZERO, 22)
	b.add("torus", Vector3.ZERO, Vector3(R * 2.1, 0.32, R * 2.1), seam, Vector3(90, 0, 0), 30)
	var n = 26
	for k in n:   # küre üstüne eşit dağılım
		var y = 1.0 - 2.0 * (k + 0.5) / n
		var r = sqrt(maxf(0.0, 1.0 - y * y))
		var a = k * 2.39996
		var d = Vector3(cos(a) * r, y, sin(a) * r)
		_spike_at(b, d, R, 0.3 if k % 3 else 0.2, 0.2 if k % 3 else 0.13, spike, open)
	for k in 30:
		var a = k * TAU / 30.0
		b.add("sphere", Vector3(cos(a) * R * 0.99, sin(a) * R * 0.99, 0.2), Vector3.ONE * 0.016, seam, Vector3.ZERO, 4)


static func _handle(b: MB) -> void:
	var m = Color(0.42, 0.42, 0.45)
	b.add("cyl", Vector3(0, 0, 0.1), Vector3(0.05, 0.42, 0.05), m, Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, -0.2), Vector3(0.045, 0.22, 0.045), Color(0.13, 0.13, 0.15), Vector3(90, 0, 0), 8)
	b.add("cyl", Vector3(0, 0, 0.3), Vector3(0.07, 0.03, 0.07), Color(0.22, 0.22, 0.25), Vector3(90, 0, 0), 8)


## jidanda: elde toplu; jidanda_sap: gülle uçarken; jidanda_top / jidanda_acik: gülle (merkez 0)
static func model(b: MB, id: String) -> void:
	match id:
		"jidanda_top":
			_ball(b, false)
		"jidanda_acik":
			_ball(b, true)
		"jidanda_sap":
			_handle(b)
		_:
			_handle(b)
			b.add("cyl", Vector3(0, 0, 0.55), Vector3(0.05, 0.5, 0.05), Color(0.34, 0.33, 0.33), Vector3(90, 0, 0), 8)
			var h = MB.new()
			_ball(h, false)
			b.add_mesh(h, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.72), Vector3(0, 0, 1.2)))


# ------------------------------------------------------------------ sap + gülle
static func _hand(who: Node3D) -> Vector3:
	var n = U.weapon_node(who, ID)
	return n.to_global(Vector3(0, 0, 0.3)) if n != null else who.global_position + Vector3.UP * 1.2


static func _band(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	im.clear_surfaces()
	for pass_i in 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var prev = a
		for i in 25:
			var u = i / 24.0
			var p = a.lerp(b, u).lerp(b.lerp(c, u), u)
			var d = (p - prev) if i > 0 else (b - a)
			var f = d.normalized() if d.length() > 0.0005 else Vector3.FORWARD
			var s = f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
			if pass_i == 1:
				s = s.cross(f).normalized()
			im.surface_set_uv(Vector2(u, 0))
			im.surface_add_vertex(p - s * 0.075)
			im.surface_set_uv(Vector2(u, 1))
			im.surface_add_vertex(p + s * 0.075)
			prev = p
		im.surface_end()


## path(k) -> [bükülme, gülle merkezi]; tick(k, merkez); acik: dikenler açık mı (k'ye göre Callable)
static func _swing(who: Node3D, T: float, path: Callable, tick := Callable(), roll := 0.0) -> void:
	var n = U.weapon_node(who, ID)
	if n == null or not (n is MeshInstance3D):
		return
	var tok = int(who.get_meta("jd_tok", 0)) + 1
	who.set_meta("jd_tok", tok)
	(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh("jidanda_sap")
	var ball = MeshInstance3D.new()
	ball.mesh = CharacterModel.weapon_mesh("jidanda_top")
	var im = ImmediateMesh.new()
	var band = MeshInstance3D.new()
	band.mesh = im
	band.material_override = Kit.shader_mat("jd_band", BAND_SH)
	band.extra_cull_margin = 40.0
	var s = {"t": 0.0, "prev": n.to_global(Vector3(0, 0, 1.2))}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var k = float(s["t"]) / T
		if k >= 1.0 or not is_instance_valid(who) or not is_instance_valid(n) or who.is_dead():
			if is_instance_valid(n) and is_instance_valid(who) and int(who.get_meta("jd_tok", 0)) == tok:
				(n as MeshInstance3D).mesh = CharacterModel.weapon_mesh(ID)
			return true
		var pts: Array = path.call(k)
		var c: Vector3 = pts[1]
		_band(im, _hand(who), pts[0], c)
		var v: Vector3 = c - (s["prev"] as Vector3)
		s["prev"] = c
		var ax = v.cross(Vector3.UP)
		var b = ball.global_transform.basis.orthonormalized()
		if ax.length() > 0.001:
			b = Basis(ax.normalized(), -v.length() / (0.62 * BALL) * (1.0 + roll)) * b
		ball.global_transform = Transform3D(b.scaled(Vector3.ONE * BALL), c)
		if tick.is_valid():
			tick.call(k, c, ball)
		return false
	var root = Kit.ticker(who.global_position, fn)
	root.add_child(band)
	band.top_level = true
	band.global_transform = Transform3D.IDENTITY
	root.add_child(ball)
	ball.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.72), s["prev"])
	Sfx.play("swing_heavy", who.global_position + Vector3.UP, 0.55, 0.9)


static func _ground(p: Vector3, r := 0.93) -> Vector3:
	return Vector3(p.x, Game.jutsu_floor_at(p).y + r, p.z)


# ------------------------------------------------------------------ patlama / darbe
static func _flash(p: Vector3, size: float) -> void:
	var mi = Kit.quad(Kit.scene(), size, Kit.shader_mat("jd_flash", FLASH_SH))
	mi.global_position = p
	mi.set_instance_shader_parameter("seed_k", randf())
	Kit.tween_param(mi, "prog", 0.0, 1.0, 0.36, true)


static func _tag_blast(who: Node3D, p: Vector3, dmg: float, r := 2.2) -> void:
	if not is_instance_valid(who):
		return
	_flash(p, r * 2.5)
	Combat.hit_sphere(who, p, r, {"dmg": dmg, "knock": 7.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.05})
	Sfx.play("boom", p, randf_range(1.05, 1.3), 0.65)


static func _thud(who: Node3D, c: Vector3, dmg: float, r: float, done: Array, extra := {}) -> void:
	var info = {"dmg": dmg, "knock": 9.0, "kind": "heavy", "hitstop": 0.09, "melee": true}
	info.merge(extra, true)
	var hits = Combat.hit_sphere(who, c, r, info, done)
	for h in hits:
		U.credit(who, h)
	done.append_array(hits)
	Sfx.play("hit_heavy_weapon", c, 0.5, 1.0)
	if who is Player and Game.world:
		Game.world.env.add_shake(0.55)


## Dikenler açılır, çevresine etiket halkası patlar
static func _open_burst(who: Node3D, ball: MeshInstance3D, c: Vector3, dmg: float) -> void:
	if is_instance_valid(ball):
		ball.mesh = CharacterModel.weapon_mesh("jidanda_acik")
	for k in 6:
		var a = TAU * k / 6.0
		var p = c + Vector3(cos(a), randf_range(-0.2, 0.3), sin(a)) * 1.9
		who.get_tree().create_timer(0.12 + k * 0.05).timeout.connect(_tag_blast.bind(who, p, dmg, 1.7))


# ------------------------------------------------------------------ adımlar
static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var from = who.global_position + Vector3.UP * 1.2
	var fw = aim - who.global_position
	fw.y = 0.0
	var f: Vector3 = fw.normalized() if fw.length() > 0.1 else who.face_dir()
	var side = f.cross(Vector3.UP).normalized()
	var D = clampf(fw.length(), 3.5, 8.0)
	var spot = _ground(who.global_position + f * D)
	var done: Array = []
	var st = {"hit": false, "n": 0}
	if i == 0:
		var top = from.lerp(spot, 0.5) + Vector3.UP * 5.5
		var path = func(k: float) -> Array:
			var c = from.lerp(top, smoothstep(0.0, 0.24, k)).lerp(spot, pow(clampf((k - 0.24) / 0.16, 0.0, 1.0), 2.0))
			if k > 0.72:
				c = spot.lerp(from + f * 1.0, (k - 0.72) / 0.28)
			return [from.lerp(c, 0.5) + Vector3.UP * 1.2, c]
		var tick = func(k: float, c: Vector3, _b) -> void:
			if k >= 0.4 and not bool(st["hit"]):
				st["hit"] = true
				_thud(who, c, dmg * 1.5, 2.3, done, {"stun": 0.45})
		_swing(who, 0.72, path, tick)
	elif i == 1:
		var path = func(k: float) -> Array:
			var a = lerpf(-1.9, 1.9, smoothstep(0.05, 0.72, k))
			var r = D * (1.0 - smoothstep(0.76, 1.0, k) * 0.85)
			var c = who.global_position + (f * cos(a) + side * sin(a)) * r + Vector3.UP * 1.1
			return [from.lerp(c, 0.5) - side * sin(a), c]
		var tick = func(k: float, c: Vector3, _b) -> void:
			if k < 0.74:
				_thud_quiet(who, c, dmg * 1.1, 1.7, done)
		_swing(who, 0.86, path, tick)
	elif i == 2:
		var end = _ground(who.global_position + f * (D + 3.0))
		var near = _ground(who.global_position + f * 1.6)
		var path = func(k: float) -> Array:
			var u = sin(clampf(k, 0.0, 1.0) * PI)
			var c = near.lerp(end, u)
			c = _ground(c)
			return [from.lerp(c, 0.5) + Vector3.UP * 0.4, c]
		var tick = func(_k: float, c: Vector3, _b) -> void:
			_thud_quiet(who, c, dmg * 1.0, 1.5, done)
		_swing(who, 0.9, path, tick, 0.4)
	elif i == 3:
		var path = func(k: float) -> Array:
			var c = from.lerp(spot + Vector3.UP * 0.1, smoothstep(0.0, 0.3, k))
			if k > 0.8:
				c = spot.lerp(from + f, (k - 0.8) / 0.2)
			return [from.lerp(c, 0.5) + Vector3.UP * 0.6, c]
		var tick = func(k: float, c: Vector3, b) -> void:
			if k >= 0.32 and not bool(st["hit"]):
				st["hit"] = true
				_open_burst(who, b, c, dmg * 0.62)
		_swing(who, 0.98, path, tick)
	elif i == 4:
		var high = spot + Vector3.UP * 9.0
		var path = func(k: float) -> Array:
			var c: Vector3
			if k < 0.46:
				c = from.lerp(high, sin(k / 0.46 * PI * 0.5))
			elif k < 0.62:
				c = high.lerp(spot, pow((k - 0.46) / 0.16, 2.0))
			else:
				c = spot.lerp(from + f, smoothstep(0.78, 1.0, k))
			return [from.lerp(c, 0.5) + Vector3.UP * 1.0, c]
		var tick = func(k: float, c: Vector3, _b) -> void:
			if int(st["n"]) == 0 and k > 0.04:
				st["n"] = 1
				_flash(from + f * 1.0, 3.2)   # tepme patlaması: gülleyi kaldırır
				Sfx.play("boom", from, 1.5, 0.7)
			if k >= 0.62 and not bool(st["hit"]):
				st["hit"] = true
				_thud(who, c, dmg * 1.7, 2.8, done, {"launch": 3.0})
		_swing(who, 1.12, path, tick)
	else:
		_stamp(who, from, f, D, dmg)


static func _thud_quiet(who: Node3D, c: Vector3, dmg: float, r: float, done: Array) -> void:
	var hits = Combat.hit_sphere(who, c, r, {"dmg": dmg, "knock": 8.0, "kind": "heavy", "hitstop": 0.07, "melee": true}, done)
	for h in hits:
		U.credit(who, h)
		Sfx.play("hit_heavy_weapon", c, 0.6, 0.9)
	done.append_array(hits)


## Bitiriş: üç ayak vuruşu (adının kaynağı), sonuncu tüm etiketler
static func _stamp(who: Node3D, from: Vector3, f: Vector3, D: float, dmg: float) -> void:
	var side = f.cross(Vector3.UP).normalized()
	var spots = [_ground(who.global_position + f * (D - 1.0) + side * 1.6), _ground(who.global_position + f * D - side * 1.6), _ground(who.global_position + f * (D + 0.6))]
	var times = [0.25, 0.52, 0.8]
	var st = {"n": 0}
	var path = func(k: float) -> Array:
		var c: Vector3 = from
		var prev: Vector3 = from
		for j in 3:
			var t1: float = times[j]
			var t0: float = t1 - 0.24
			var sp: Vector3 = spots[j]
			if k >= t0 and k < t1:
				var u = (k - t0) / 0.24
				var up = sp + Vector3.UP * 7.0
				c = prev.lerp(up, smoothstep(0.0, 0.55, u)).lerp(sp, pow(clampf((u - 0.55) / 0.45, 0.0, 1.0), 2.0))
				return [from.lerp(c, 0.5) + Vector3.UP * 1.4, c]
			prev = sp
			c = sp
		if k >= 0.9:
			c = (spots[2] as Vector3).lerp(from + f, (k - 0.9) / 0.1)
		return [from.lerp(c, 0.5) + Vector3.UP * 1.0, c]
	var tick = func(k: float, c: Vector3, b) -> void:
		var n: int = st["n"]
		if n < 3 and k >= float(times[n]):
			st["n"] = n + 1
			var once: Array = []
			_thud(who, c, dmg * (0.9 if n < 2 else 1.5), 2.7, once, {"stun": 0.3})
			if n == 2:
				_open_burst(who, b, c, dmg * 0.7)
	_swing(who, 1.6, path, tick)


static func start(who: Node3D, _i: int) -> void:
	if who != null and is_instance_valid(who):
		U.face(who, U.aim_at(who, U.target_of(who)))
