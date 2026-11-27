extends RefCounted
## Kanabō: model, yer yarma ve Raiton: Kanasaibō — kendi şekilleri ve gölgelendiricileri, ortak efekt yok.
## Kaynak: Doki.png (uca doğru kalınlaşan gri gövde, yuvarlak tepe, kenarda yumrular, koyu oyuklar, sargılı sap, dipte demir halka).
## Kanon: Lightning Release: Pulverising Lightning Rod (Gatai) — yıldırım chakrası gürzün çevresine akıtılır, darbenin gücü artar.
## Raiton doğası olmayan kullanıcı saf demir olarak savurur; bitirişte yarık daha kısadır. Oyuncu ve düşman aynı kod.

const ID := "kanabo"
const CHARGE_COST := 0.1

static var _c := {}

const ROCK_SH := """shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""

const CRACK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
instance uniform float volt = 0.0;
void fragment() {
	float v = abs(UV.y * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.35, 0.8, v);
	float edge = smoothstep(0.55, 0.8, v) * (1.0 - smoothstep(0.82, 1.0, v));
	vec3 rock = mix(vec3(0.03, 0.025, 0.03), vec3(0.3, 0.26, 0.22), edge);
	float pulse = 0.5 + 0.5 * sin(UV.x * 34.0 - TIME * 26.0);
	ALBEDO = mix(rock, vec3(0.65, 0.85, 1.0), core * volt * (0.45 + 0.55 * pulse));
	ALPHA = clamp(core + edge * 0.8, 0.0, 1.0) * fade_k;
	if (ALPHA < 0.01) discard;
}
"""

const BOLT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade_k = 1.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.35, 0.6, 1.0), vec3(0.95, 0.98, 1.0), smoothstep(0.45, 0.9, v));
	ALPHA = smoothstep(0.0, 0.5, v) * fade_k;
}
"""


# ------------------------------------------------------------------ model
## Kabza 0, uç +Z (~1.9 m). Sapı sargılı, gövde uca doğru kalınlaşır, yuvarlak tepe; koyu oyuk sıraları, kenar yumruları, dipte demir halka.
static func model(b: MB) -> void:
	var iron = Color(0.5, 0.5, 0.53)
	var hole = Color(0.2, 0.2, 0.23)
	var stud = Color(0.38, 0.38, 0.41)
	var cloth = Color(0.72, 0.6, 0.4)
	var pts = [Vector3(0, 0, -0.42), Vector3(0, 0, 0.26), Vector3(0, 0, 0.55), Vector3(0, 0, 0.98), Vector3(0, 0, 1.3)]
	LazyFx.g("Loft").tube(b, pts, [0.034, 0.038, 0.062, 0.105, 0.118], iron, 12, 4)
	LazyFx.g("Loft").tube(b, [Vector3(0, 0, -0.44), Vector3(0, 0, 0.3)], [0.042, 0.046], cloth, 10, 2, false, false)
	for k in 8:
		b.add("cyl", Vector3(0, 0, -0.4 + k * 0.095), Vector3(0.095, 0.01, 0.095), cloth.darkened(0.28), Vector3(90 + (k % 2) * 6.0, 0, 0), 10)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3311
	for k in 22:   # koyu yuvarlak oyuklar (doki.gd'deki dev gürzle aynı dil)
		var z = rng.randf_range(0.5, 1.32)
		var a = rng.randf() * TAU
		var r = _radius(z)
		var n = Vector3(cos(a), sin(a), 0)
		var y = n
		var x = y.cross(Vector3.BACK).normalized()
		var zz = x.cross(y)
		b.add_xf("sphere", Transform3D(Basis(x * 0.05, y * 0.016, zz * 0.05), n * r + Vector3(0, 0, z)), hole, 6)
	for s in 4:   # dört sıra yumru (kaynakta kenarda dizili)
		var a = s * PI * 0.5 + 0.4
		for k in 5:
			var z = 0.62 + k * 0.16
			var n = Vector3(cos(a), sin(a), 0)
			b.add("sphere", n * (_radius(z) + 0.004) + Vector3(0, 0, z), Vector3(0.05, 0.05, 0.05), stud, Vector3.ZERO, 6)
	b.add("cyl", Vector3(0, 0, -0.46), Vector3(0.06, 0.03, 0.06), hole, Vector3(90, 0, 0), 10)
	b.add("torus", Vector3(0, 0, -0.53), Vector3(0.13, 0.13, 0.13), hole, Vector3(0, 0, 90), 12)


static func _radius(z: float) -> float:
	return lerpf(0.062, 0.118, clampf((z - 0.55) / 0.75, 0.0, 1.0))


# ------------------------------------------------------------------ küçükler
static func _root() -> Node:
	var ml = Engine.get_main_loop()
	return (ml as SceneTree).current_scene if ml is SceneTree else null


static func _node(who: Node3D) -> MeshInstance3D:
	var m = who.get("model")
	if m == null or not (m is CharacterModel):
		return null
	for w in m.weapons:
		if LazyFx.g("Gear").base_id(String(w["id"])) == ID and is_instance_valid(w["node"]) and w["node"] is MeshInstance3D:
			return w["node"]
	return null


static func _face(who: Node3D) -> Vector3:
	var f: Vector3 = who.face_dir() if who.has_method("face_dir") else -who.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


static func _gp(p: Vector3) -> Vector3:
	return Vector3(p.x, Game.ground_height(p.x, p.z) + 0.03, p.z)


static func _pay(who: Node3D, frac: float) -> bool:
	if who.get("chakra") == null:
		return true
	var mx = float(who.get("max_chakra")) if who.get("max_chakra") != null else 100.0
	if float(who.chakra) < mx * frac:
		return false
	who.chakra = float(who.chakra) - mx * frac
	return true


## Kanon şartı: yıldırım doğası (oyuncu: öğrendiği doğalar; düşman: kendi doğası)
static func _volt(who: Node3D) -> bool:
	if who is Player:
		return "raiton" in (Game.profile.get("elements", []) as Array)
	return str(who.get("element")) == "raiton" if who.get("element") != null else false


static func _after(who: Node3D, t: float, fn: Callable) -> void:
	who.get_tree().create_timer(t).timeout.connect(func():
		if is_instance_valid(who):
			fn.call())


static func _mat(key: String, code: String) -> ShaderMaterial:
	key = "mat:" + key
	if not _c.has(key):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[key] = m
	return _c[key]


static func _fade(gi: GeometryInstance3D, delay: float, t: float) -> void:
	var tw = gi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


static func _shake(who: Node3D, a: float) -> void:
	if who is Player and Game.world:
		Game.world.env.add_shake(a)


# ------------------------------------------------------------------ taş parçaları
static func _rock_mesh() -> Mesh:
	if not _c.has("rock"):
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(1.0, 0.7, 0.85), Color.WHITE, Vector3(25, 35, 12))
		_c["rock"] = b.build()
	return _c["rock"]


## Yerden kalkan köşeli taşlar; dir verilirse o yöne savrulur
static func _rocks(p: Vector3, n: int, up: float, spread: float, size: float, dir := Vector3.ZERO) -> void:
	var root = _root()
	if root == null:
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _rock_mesh()
	mm.instance_count = n
	var data = []
	for i in n:
		var a = randf() * TAU
		var v = Vector3(cos(a), 0, sin(a)) * randf_range(0.2, 1.0) * spread + Vector3.UP * randf_range(0.5, 1.0) * up + dir * randf_range(0.6, 1.0)
		var g = randf_range(0.24, 0.36)
		data.append([v, randf_range(0.45, 1.0) * size, randf() * TAU, randf_range(3.0, 8.0)])
		mm.set_instance_color(i, Color(g * 1.18, g, g * 0.85))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("rock", ROCK_SH)
	mi.custom_aabb = AABB(p - Vector3.ONE * 12.0, Vector3.ONE * 24.0)
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	var T = 0.7
	var tw = mi.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(mi):
			return
		var fade = 1.0 - smoothstep(0.72 * T, T, t)
		for i in n:
			var e: Array = data[i]
			var q = p + (e[0] as Vector3) * t + Vector3.DOWN * 12.0 * t * t
			q.y = maxf(q.y, p.y)
			var br = Basis(Vector3(0.3, 0.8, 0.5).normalized(), float(e[2]) + float(e[3]) * t).scaled(Vector3.ONE * float(e[1]) * fade)
			mm.set_instance_transform(i, Transform3D(br, q)), 0.0, T, T)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ yarık ve yıldırım
## Zemini izleyen, zikzak, uca doğru incelen yarık şeridi
static func _crack(from: Vector3, f: Vector3, L: float, volt: bool, life: float) -> Array:
	var root = _root()
	if root == null:
		return []
	var side = Vector3.UP.cross(f).normalized()
	var path = []
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = 30
	var off = 0.0
	for i in n + 1:
		var u = float(i) / n
		off = clampf(off + randf_range(-0.2, 0.2), -0.55, 0.55) * (1.0 - u * 0.2)
		var c = _gp(from + f * L * u + side * off)
		c.y += 0.03
		path.append(c)
		var w = lerpf(0.34, 0.05, u) * randf_range(0.65, 1.25)
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(c - side * w)
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(c + side * w)
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _mat("crack", CRACK_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	mi.set_instance_shader_parameter("volt", 1.0 if volt else 0.0)
	_fade(mi, life * 0.6, life * 0.4)
	return path


## Noktalar arası kırık ışık şeridi; kameradan bağımsız görünsün diye iki dik düzlem
static func _bolt_mesh(pts: Array, w: float) -> ImmediateMesh:
	var im = ImmediateMesh.new()
	for pass_i in 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var a: Vector3 = pts[maxi(i - 1, 0)]
			var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var d = (b - a).normalized()
			var ref = Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
			var s = d.cross(ref).normalized()
			if pass_i == 1:
				s = s.cross(d).normalized()
			var k = 1.0 - float(i) / maxf(1.0, pts.size() - 1) * 0.6
			im.surface_set_uv(Vector2(float(i), 0))
			im.surface_add_vertex(pts[i] - s * w * k)
			im.surface_set_uv(Vector2(float(i), 1))
			im.surface_add_vertex(pts[i] + s * w * k)
		im.surface_end()
	return im


## Gürzü saran yıldırım: silah uzayında gövde çevresinde kırık yaylar, kısa aralıkla yeniden çizilir (Kanasaibō)
static func _wrap_bolts(n: MeshInstance3D, dur: float) -> void:
	var holder = MeshInstance3D.new()
	holder.material_override = _mat("bolt", BOLT_SH)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(holder)
	var redraw = func():
		if not is_instance_valid(holder):
			return
		var a = randf() * TAU
		var pts = []
		for k in 10:
			var z = lerpf(0.45, 1.36, k / 9.0)
			a += randf_range(0.5, 1.6)
			var r = _radius(z) + randf_range(0.03, 0.09)
			pts.append(Vector3(cos(a) * r, sin(a) * r, z))
		holder.mesh = _bolt_mesh(pts, 0.016)
	var steps = int(dur / 0.07)
	for i in steps:
		n.get_tree().create_timer(i * 0.07).timeout.connect(redraw)
	n.get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(holder):
			holder.queue_free())


## Yarık boyunca koşan şimşek çizgileri
static func _crack_bolts(path: Array, life: float) -> void:
	var root = _root()
	if root == null or path.size() < 4:
		return
	for s in 3:
		var pts = []
		var i = s * 3
		while i < path.size():
			pts.append((path[i] as Vector3) + Vector3(randf_range(-0.18, 0.18), randf_range(0.05, 0.42), randf_range(-0.18, 0.18)))
			i += 3
		if pts.size() < 2:
			continue
		var mi = MeshInstance3D.new()
		mi.mesh = _bolt_mesh(pts, 0.05)
		mi.material_override = _mat("bolt", BOLT_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_transform = Transform3D.IDENTITY
		_fade(mi, life * 0.3 + s * 0.05, life * 0.5)


# ------------------------------------------------------------------ vuruşlar
static func _impact(who: Node3D, d: float, n: int, size: float, shake: float, pitch := 0.7) -> Vector3:
	var g = _gp(who.global_position + _face(who) * d)
	_rocks(g, n, 4.2, 2.0, size)
	Sfx.play("hit_heavy_weapon", g, pitch, 0.9)
	_shake(who, shake)
	return g


## Bitiriş: yer çizgi hâlinde yarılır; yarık önden arkaya ilerler, üstündekileri vurur. Raiton varsa uzar ve şimşek taşır.
static func _rend(who: Node3D, dmg: float) -> void:
	var f = _face(who)
	var volt = bool(who.get_meta("kana_volt", false))
	var from = who.global_position + f * 1.5
	var L = 9.0 if volt else 5.5
	var path = _crack(from, f, L, volt, 1.5)
	if path.is_empty():
		return
	Sfx.play("earth", from, 0.62, 1.0)
	if volt:
		Sfx.play("thunder", from, 1.15, 0.8)
		_crack_bolts(path, 0.7)
	_shake(who, 0.8)
	var hits = 5
	var done: Array = []
	for k in hits:
		_after(who, 0.03 + k * 0.05, func():
			var q: Vector3 = path[int(float(k + 1) / hits * (path.size() - 1))]
			_rocks(q, 5, 5.5, 0.8, 0.16)
			var info = {"dmg": dmg * (0.95 if volt else 0.7), "knock": 2.0, "launch": 5.5, "kind": "heavy", "hitstop": 0.05}
			if volt:
				info["element"] = "raiton"
				info["stun"] = 0.55
			done.append_array(Combat.hit_sphere(who, q + Vector3.UP * 0.8, 1.7, info, done)))


# ------------------------------------------------------------------ kombo bağları
static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	match i:
		4:   # ikinci ve üçüncü iniş (ilki strike'ta): her biri daha sert
			_after(who, 0.64, func():
				_impact(who, 1.9, 6, 0.14, 0.28, 0.76))
			_after(who, 0.96, func():
				_impact(who, 1.9, 9, 0.17, 0.4, 0.66))
		5:
			var volt = _volt(who) and _pay(who, CHARGE_COST)
			who.set_meta("kana_volt", volt)
			if volt:
				var n = _node(who)
				if n != null:
					_wrap_bolts(n, 1.2)
				Sfx.play("zap", who.global_position, 0.8, 0.7)


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var f = _face(who)
	match i:
		0:
			_impact(who, 2.0, 8, 0.15, 0.32)
		1:   # kazınan toprak öne savrulur: taşlar yakını da sıyırır
			var g = _gp(who.global_position + f * 1.6)
			_rocks(g, 12, 3.2, 1.2, 0.14, f * 8.0)
			Sfx.play("earth", g, 1.0, 0.7)
			Combat.hit_sphere(who, g + f * 2.4 + Vector3.UP * 0.7, 1.5, {"dmg": dmg * 0.3, "knock": 2.0, "kind": "light", "hitstop": 0.01})
		3:
			Sfx.play("swing_heavy", who.global_position, 0.7, 0.9)
		4:
			_impact(who, 1.9, 4, 0.12, 0.2, 0.86)
		5:
			_impact(who, 1.9, 16, 0.22, 0.6, 0.6)
			_rend(who, dmg)
