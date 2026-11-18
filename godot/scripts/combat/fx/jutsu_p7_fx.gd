extends RefCounted
## Eksik jutsular, parti 7 (hedef: res://scripts/combat/fx/jutsu_p7_fx.gd). Kaynak görseller: refs/new/<id>/.
## Her teknik kendi gölgelendiricisi ve geometrisiyle; hasar ve durumlar oyunun sistemleriyle (oyuncu ve düşman aynı kod).

const P5 = preload("res://scripts/combat/fx/jutsu_p5_fx.gd")

static var _mats := {}
static var _meshes := {}

const BALL_SH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float a = atan(NORMAL.x, NORMAL.y) + TIME * 18.0 + (1.0 - f) * 6.0;
	float s = 0.5 + 0.5 * sin(a * 3.0);
	ALBEDO = mix(vec3(0.2, 0.5, 1.0), vec3(0.85, 0.96, 1.0), s * f + f * f * 0.5) * 1.6;
	ALPHA = smoothstep(0.0, 0.35, f);
}
"""

const POP_SH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform float k = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arm = 0.5 + 0.5 * sin(a * 3.0 + r * 11.0 - k * 16.0);
	float band = smoothstep(0.3, 0.0, abs(r - k * 0.85));
	ALBEDO = mix(vec3(0.25, 0.55, 1.0), vec3(0.9, 0.97, 1.0), arm);
	ALPHA = band * arm * (1.0 - k) * step(r, 1.0);
}
"""

const SAND_SH := """shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
instance uniform float grow = 0.0;
varying vec3 lp;
float wob(vec3 p) {
	return sin(p.x * 17.0 + p.y * 5.0) * sin(p.z * 15.0 - p.y * 7.0) + 0.5 * sin(p.y * 23.0 + p.x * 9.0);
}
void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * (0.02 + wob(VERTEX) * 0.022);
}
void fragment() {
	float hem = 0.76 + 0.13 * sin(UV.x * 44.0) * sin(UV.x * 17.0 + 1.0) + 0.07 * sin(UV.x * 97.0);
	float neck = 0.1 + 0.07 * sin(UV.x * 38.0 + 0.6) * sin(UV.x * 13.0);
	if (UV.y > hem * grow || UV.y < neck) discard;
	float g = fract(sin(dot(floor(lp * 150.0), vec3(12.9, 78.2, 37.7))) * 43758.5);
	vec3 c = mix(vec3(0.5, 0.26, 0.11), vec3(0.68, 0.39, 0.17), smoothstep(-0.8, 0.9, wob(lp)));
	ALBEDO = c * (g > 0.84 ? 0.76 : 1.0);
}
"""

const GUST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform float prog = 0.0;
void fragment() {
	float x = UV.x;
	float head = prog * 1.7 - COLOR.r * 0.5;
	float tail = head - 0.42 - COLOR.g * 0.2;
	float along = smoothstep(tail, tail + 0.14, x) * (1.0 - smoothstep(head - 0.05, head, x));
	float across = 1.0 - pow(abs(UV.y * 2.0 - 1.0), 1.6);
	float wisp = 0.65 + 0.35 * sin(x * 40.0 + COLOR.r * 30.0 + UV.y * 5.0);
	ALBEDO = mix(vec3(0.76, 0.87, 0.9), vec3(1.0), across);
	ALPHA = along * across * wisp * 0.8 * (1.0 - smoothstep(0.78, 1.0, prog));
}
"""

const STREAM_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
instance uniform float k = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	float e = abs(UV.y * 2.0 - 1.0);
	float edge = 0.86 + 0.14 * sin(UV.x * 90.0) * sin(UV.x * 31.0);
	if (UV.x > k || e > edge) discard;
	if (fract(UV.x * 37.0 + UV.y * 3.0) > fade * 1.02) discard;
	ALBEDO = mix(vec3(0.02, 0.025, 0.05), vec3(0.09, 0.11, 0.16), smoothstep(0.45, 0.9, e));
}
"""

const COIL_SH := """shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
instance uniform float k = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	if (UV.x > k) discard;
	float brk = fract(UV.x * 53.0) ;
	if (brk > fade * 1.02) discard;
	float side = abs(fract(UV.y + 0.2) - 0.5) * 2.0;
	float brush = sin(UV.x * 120.0) * 0.5 + sin(UV.x * 47.0 + 1.0) * 0.5;
	ALBEDO = (side < 0.2 && brush > 0.15) ? vec3(0.72, 0.74, 0.78) : vec3(0.015, 0.015, 0.025);
}
"""


# ------------------------------------------------------------------ altyapı
static func _mat(key: String, code: String) -> ShaderMaterial:
	if not _mats.has(key):
		var sh = Shader.new()
		sh.code = code
		var m = ShaderMaterial.new()
		m.shader = sh
		_mats[key] = m
	return _mats[key]


static func _param(mi: GeometryInstance3D, p: String, a: float, b: float, t: float) -> void:
	mi.set_instance_shader_parameter(p, a)
	var tw = mi.create_tween()
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter(p, v), a, b, t)


static func _height(n: Node3D) -> float:
	return clampf(P5._bone(n, "Head", 1.6).y - n.global_position.y + 0.14, 1.0, 12.0)


static func _along(dir: Vector3, s: float) -> Basis:
	var d = dir.normalized() if dir.length() > 0.001 else Vector3.UP
	return Basis(Quaternion(Vector3.UP, d)).scaled(Vector3.ONE * s)


static func _needle() -> Mesh:
	if not _meshes.has("needle"):
		var m = CylinderMesh.new()
		m.top_radius = 0.004
		m.bottom_radius = 0.024
		m.height = 0.72
		m.radial_segments = 5
		m.rings = 1
		m.material = Props.toon_color(Color(0.78, 0.8, 0.84), 0.45)
		_meshes["needle"] = m
	return _meshes["needle"]


static func _nails(n: int, parent: Node3D) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _needle()
	mm.instance_count = n
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-16, -3, -16), Vector3(32, 24, 32))
	parent.add_child(mi)
	return mm


static func _tube(pts: Array, r: float, sides := 6) -> ArrayMesh:
	var v = PackedVector3Array()
	var nr = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var n = pts.size()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var f: Vector3 = (b - a).normalized()
		var s: Vector3 = f.cross(Vector3.UP).normalized()
		if s.length() < 0.1:
			s = Vector3.RIGHT
		var u: Vector3 = s.cross(f).normalized()
		var x = float(i) / float(n - 1)
		var rr = r * minf(1.0, (1.0 - x) * 7.0 + 0.12)
		for j in sides + 1:
			var q = TAU * j / float(sides)
			var d: Vector3 = s * cos(q) + u * sin(q)
			v.append((pts[i] as Vector3) + d * rr)
			nr.append(d)
			uv.append(Vector2(x, float(j) / float(sides)))
	for i in n - 1:
		for j in sides:
			var p = i * (sides + 1) + j
			var q = p + sides + 1
			idx.append_array([p, q, p + 1, p + 1, q, q + 1])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ------------------------------------------------------------------ Chibitama Rasengan
## Kanon: chakra tükenmek üzereyken, elde kalan azıcık chakrayla yapılan minik Rasengan (ref: avuçta boncuk kadar küre).
static func block(c: Node3D, jid: String) -> String:
	if jid != "chibitama_rasengan" or c == null:
		return ""
	if c is Player and not "rasengan" in Game.profile.get("learned", []):
		return "Rasengan'ı bilmeden küçültemezsin."
	var mx = c.get("max_chakra")
	var ch = c.get("chakra")
	if mx != null and ch != null and float(ch) > float(mx) * 0.4:
		return "Chakran hâlâ bol — bu küre ancak elde avuç içi kadar chakra kalınca yapılır."
	return ""


static func chibitama_rasengan(pj, c: Node3D, t: Node3D) -> void:
	var id = "chibitama_rasengan"
	var tt = pj.tg(c, t, 5.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.4)
	var m = SphereMesh.new()
	m.radius = 0.075
	m.height = 0.15
	m.radial_segments = 20
	m.rings = 12
	var ball = MeshInstance3D.new()
	ball.mesh = m
	ball.material_override = _mat("chibi", BALL_SH)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pj.scene_add(ball, pj.hand_pos(c, true))
	ball.scale = Vector3.ONE * 0.2
	ball.create_tween().tween_property(ball, "scale", Vector3.ONE, 0.22)
	Sfx.play("wind", ball.global_position, 2.2, 0.35)
	var cw = weakref(c)
	pj.every(0.42, 1.0 / 60.0, func(_i, _k):
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(ball):
			ball.global_position = pj.live_hand(cc, true))
	pj.after(0.2, func():
		var cc = cw.get_ref()
		if cc != null and pj.live(cc):
			var tn = pj.tg(cc, null, 5.0)
			Jutsu._dash(cc, tn, 0.2, 15.0, func(_p): pass))
	pj.after(0.42, func():
		var cc = cw.get_ref()
		if is_instance_valid(ball):
			ball.queue_free()
		if cc == null or not pj.live(cc):
			return
		var fd: Vector3 = pj._face(cc, tt if pj.live(tt) else null)
		var at: Vector3 = cc.global_position + Vector3.UP * 1.15 + fd * 0.55
		var hits = pj.hit(cc, at + fd * 0.45, 1.3, pj.inf(cc, id, 1.0, {"knock": 5.0, "launch": 1.5, "kind": "heavy", "melee": true, "hitstop": 0.07}))
		var q = QuadMesh.new()
		q.size = Vector2.ONE * (2.6 if hits.size() > 0 else 1.3)
		var pop = MeshInstance3D.new()
		pop.mesh = q
		pop.material_override = _mat("chibi_pop", POP_SH)
		pop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pj.scene_add(pop, at + fd * 0.45)
		_param(pop, "k", 0.0, 1.0, 0.3)
		pop.get_tree().create_timer(0.32).timeout.connect(pop.queue_free)
		Sfx.play("wind", at, 1.5, 0.6))


# ------------------------------------------------------------------ Sunagoromo
## Kanon (Sana): yoldaşın bedenini kum zırhla örter; kum fırtınasında bile sarsılmaz (ref: gövdeye yapışmış yırtık kenarlı kum örtü).
static func _cloak_target(pj, c: Node3D) -> Node3D:
	var best: Node3D = c
	var score = 2.0
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if f == c or not pj.live(f) or Combat.hostile(c, f) or f.get("max_hp") == null:
			continue
		if f.global_position.distance_to(c.global_position) > 9.0:
			continue
		var r = float(f.hp) / maxf(float(f.max_hp), 1.0)
		if r < score:
			score = r
			best = f
	return best


static func sunagoromo(pj, c: Node3D, _t: Node3D) -> void:
	var T = 14.0
	pj.busy(c, 0.55)
	pj.anim(c, "cast", 1.0)
	var who: Node3D = _cloak_target(pj, c)
	if who is Player:
		Buffs.add("sunagoromo", T, {})
	elif who.has_method("add_buff"):
		who.add_buff("sunagoromo", T, {})
	Combat.set_shield(who, "sunagoromo", float(who.get("max_hp")) * 0.3, false)
	var m = CylinderMesh.new()
	m.top_radius = 0.135
	m.bottom_radius = 0.2
	m.height = 0.62
	m.radial_segments = 30
	m.rings = 12
	m.cap_top = false
	m.cap_bottom = false
	var coat: MeshInstance3D
	var md = who.get("model")
	if md != null and md.get("skel") != null and md.skel.find_bone("UpperChest") >= 0:
		coat = md._mesh_on("UpperChest", m, Transform3D(Basis.IDENTITY, md._bp("UpperChest") + Vector3(0, -0.12, 0)))   # kemikle birlikte eğilir
	else:
		coat = MeshInstance3D.new()
		coat.mesh = m
		who.add_child(coat)
		coat.position = Vector3.UP * _height(who) * 0.62
	coat.material_override = _mat("suna_koromo", SAND_SH)
	_param(coat, "grow", 0.0, 1.0, 0.45)
	Sfx.play("earth", who.global_position, 1.5, 0.5)
	var ww = weakref(who)
	var cw = weakref(coat)
	var left = {"t": T}
	var tick = coat.get_tree().create_timer(0.0)
	tick.timeout.connect(func(): _coat_watch(ww, cw, left))


static func _coat_watch(ww: WeakRef, cw: WeakRef, left: Dictionary) -> void:
	var coat = cw.get_ref()
	if coat == null:
		return
	var who = ww.get_ref()
	var alive = who != null and (who.get_meta("shields", {}) as Dictionary).has("sunagoromo") and float(who.get_meta("shields", {})["sunagoromo"]["hp"]) > 0.0
	left["t"] -= 0.2
	if not alive or float(left["t"]) <= 0.0:
		if who != null and (who.get_meta("shields", {}) as Dictionary).has("sunagoromo"):
			(who.get_meta("shields") as Dictionary).erase("sunagoromo")
		_param(coat, "grow", 1.0, 0.0, 0.35)
		var holder: Node = coat.get_parent().get_parent() if coat.get_parent() != who and coat.get_parent() != null else coat
		coat.get_tree().create_timer(0.37).timeout.connect(holder.queue_free)
		return
	coat.get_tree().create_timer(0.2).timeout.connect(func(): _coat_watch(ww, cw, left))


# ------------------------------------------------------------------ Gyoraishin
## Kanon (Gosunkugi): havaya atılan çiviler toprağa gömülür; üstüne basanın ayağını çiviler, mühürle yüzlercesi yerden fırlar.
static func gyoraishin(pj, c: Node3D, t: Node3D) -> void:
	var id = "gyoraishin"
	var tt = pj.tg(c, t, 20.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.3)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var root = Node3D.new()
	pj.scene_add(root, at)
	root.get_tree().create_timer(12.0).timeout.connect(root.queue_free)
	var n = 42
	var mm = _nails(n, root)
	var from: Vector3 = pj.hand_pos(c, true) - at
	var data = []
	for i in n:
		var a = randf() * TAU
		var r = sqrt(randf()) * 2.7
		data.append([Vector3(cos(a) * r, -0.16, sin(a) * r), randf_range(4.0, 7.0), randf_range(0.0, 0.14)])
	var fly = func(k: float) -> void:
		for i in n:
			var e: Array = data[i]
			var u = clampf((k - float(e[2])) / (1.0 - float(e[2])), 0.0, 1.0)
			var p: Vector3 = from.lerp(e[0], u) + Vector3.UP * float(e[1]) * 4.0 * u * (1.0 - u)
			var q: Vector3 = from.lerp(e[0], u + 0.03) + Vector3.UP * float(e[1]) * 4.0 * (u + 0.03) * (0.97 - u)
			mm.set_instance_transform(i, Transform3D(_along(p - q, 1.5), p))
	fly.call(0.0)
	root.create_tween().tween_method(fly, 0.0, 1.0, 0.55)
	Sfx.play("throw", at, 1.0, 0.6)
	var cw = weakref(c)
	var s = {"sprung": false}
	pj.after(0.6, func():
		Sfx.play("earth", at, 1.6, 0.4)
		pj.every(8.0, 0.1, func(_i, _k):
			var cc = cw.get_ref()
			if bool(s["sprung"]) or cc == null or not pj.live(cc) or not is_instance_valid(root):
				return
			var pinned = []
			for e in pj.enemies_near(cc, at, 2.8):
				if P5._grounded(e):
					pinned.append(e)
			if pinned.is_empty():
				return
			s["sprung"] = true
			for e in pinned:
				pj.st(e, "bind", 1.5)
				e.take_hit(pj.inf(cc, id, 0.2, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "bleed": 2.0}))
			Sfx.play("seal", at, 1.2, 0.6)
			pj.after(0.45, func(): _erupt(pj, cw, root, at, id)), func():
			if not bool(s["sprung"]) and is_instance_valid(root):
				root.queue_free()))


static func _erupt(pj, cw: WeakRef, root: Node3D, at: Vector3, id: String) -> void:
	if not is_instance_valid(root):
		return
	var cc = cw.get_ref()
	if cc != null and pj.live(cc):
		pj.hit(cc, at + Vector3.UP * 1.1, 3.1, pj.inf(cc, id, 1.0, {"knock": 2.0, "launch": 5.0, "kind": "heavy", "bleed": 4.0, "hitstop": 0.08}))
	pj.shake(0.35)
	Sfx.play("hit_heavy_weapon", at, 1.5, 0.8)
	var n = 110
	var mm = _nails(n, root)
	var data = []
	for i in n:
		var a = randf() * TAU
		var r = sqrt(randf()) * 2.9
		var o = Vector3(cos(a) * r, 0.0, sin(a) * r)
		data.append([o, (Vector3.UP * 3.0 + o * 0.16 + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))).normalized(), randf_range(1.6, 5.2), randf_range(0.0, 0.55)])
	var rise = func(k: float) -> void:
		for i in n:
			var e: Array = data[i]
			var u = clampf((k - float(e[3])) / 0.42, 0.0, 1.0)
			var run = (1.0 - pow(1.0 - u, 3.0)) * float(e[2])
			var sc = 0.01 if u <= 0.0 else 2.3 * (1.0 - smoothstep(0.82, 1.0, u)) + 0.01
			mm.set_instance_transform(i, Transform3D(_along(e[1], sc), (e[0] as Vector3) + (e[1] as Vector3) * run))
	rise.call(0.0)
	var tw = root.create_tween()
	tw.tween_method(rise, 0.0, 1.0, 0.85)
	tw.tween_callback(root.queue_free)


# ------------------------------------------------------------------ Kaze Gaeshi
## Kanon: üzerine gelen Fūton tekniğini boşa çıkarıp sahibine kasırga olarak çevirir (ref: yana savrulan beyaz rüzgâr şeritleri).
static func _gust_mesh() -> ArrayMesh:
	if _meshes.has("gust"):
		return _meshes["gust"]
	var v = PackedVector3Array()
	var nr = PackedVector3Array()
	var col = PackedColorArray()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	for r in 22:
		var y0 = randf_range(0.1, 4.4)
		var x0 = randf_range(-3.2, 3.2)
		var w = randf_range(0.3, 0.85)
		var tilt = Vector3(randf_range(-0.9, 0.9), 1.0, 0.0).normalized()
		var ph = randf() * TAU
		var amp = randf_range(0.25, 0.9)
		var c = Color(randf(), randf(), 0.0)
		var base = v.size()
		for i in 25:
			var u = i / 24.0
			var z = -u * 15.0
			var q = Vector3(x0 * (0.55 + u * 0.75) + sin(u * 5.0 + ph) * amp, y0 + sin(u * 3.5 + ph * 1.7) * amp * 0.55 + u * 0.5, z)
			var wd = w * (0.35 + 0.65 * sin(u * PI))
			v.append(q + tilt * wd * 0.5)
			v.append(q - tilt * wd * 0.5)
			nr.append(Vector3.BACK)
			nr.append(Vector3.BACK)
			col.append(c)
			col.append(c)
			uv.append(Vector2(u, 0.0))
			uv.append(Vector2(u, 1.0))
			if i < 24:
				var b = base + i * 2
				idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes["gust"] = m
	return m


static func kaze_gaeshi(pj, c: Node3D, t: Node3D) -> void:
	var id = "kaze_gaeshi"
	var W = 0.9
	var d: Vector3 = pj._face(c, pj.tg(c, t, 16.0))
	pj.busy(c, W + 0.3)
	pj.anim(c, "cast", 1.0)
	var s = {"n": 0, "done": false}
	var cw = weakref(c)
	var release = func() -> void:
		var cc = cw.get_ref()
		if bool(s["done"]) or cc == null or not pj.live(cc):
			return
		s["done"] = true
		var o: Vector3 = pj.gp(cc.global_position)
		var mi = MeshInstance3D.new()
		mi.mesh = _gust_mesh()
		mi.material_override = _mat("kaze_gaeshi", GUST_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-8, -1, -18), Vector3(16, 9, 20))
		pj.scene_add(mi, o)
		mi.look_at(o + d, Vector3.UP)
		_param(mi, "prog", 0.0, 1.0, 1.0)
		mi.get_tree().create_timer(1.05).timeout.connect(mi.queue_free)
		Sfx.play("wind", o, 0.8, 0.9)
		pj.shake(0.2 + 0.12 * mini(int(s["n"]), 3))
		var mul = 0.45 + 0.55 * mini(int(s["n"]), 3)
		var done = []
		for k in 5:
			done.append_array(pj.hit(cc, o + Vector3.UP * 1.2 + d * (1.8 + k * 2.9), 2.5, pj.inf(cc, id, mul, {"knock": 9.0, "launch": 3.0, "kind": "heavy", "element": "fuuton", "hitstop": 0.05}), done))
	pj.every(W, 1.0 / 30.0, func(_i, _k):
		var cc = cw.get_ref()
		if bool(s["done"]) or cc == null or not pj.live(cc):
			return
		for n in cc.get_tree().current_scene.get_children():
			if not (n is Projectile) or n.dead or n.shooter == cc or not is_instance_valid(n.shooter) or not Combat.hostile(cc, n.shooter):
				continue
			if str((n.info as Dictionary).get("element", "")) != "fuuton" or n.global_position.distance_to(cc.global_position) > 6.0:
				continue
			n.queue_free()   # kanon: gelen rüzgâr boşa çıkar, gücü kasırgaya katılır
			s["n"] += 1
		if int(s["n"]) > 0:
			release.call(), release)


# ------------------------------------------------------------------ Sumi Nagashi
## Kanon (Sai): fırçadan yere dökülen mürekkep hedefe akar, yılanlar olup sarar (ref: yerde zikzak koyu mürekkep, kola dolanan parlak siyah yılan).
static func _stream_mesh(pts: Array) -> ArrayMesh:
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var idx = PackedInt32Array()
	var n = pts.size()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var f = b - a
		f.y = 0.0
		var s = Vector3.UP.cross(f.normalized())
		var u = float(i) / float(n - 1)
		var w = 0.2 + 0.22 * abs(sin(i * 0.9)) + u * 0.12
		v.append((pts[i] as Vector3) + s * w)
		v.append((pts[i] as Vector3) - s * w)
		uv.append(Vector2(u, 0.0))
		uv.append(Vector2(u, 1.0))
		if i < n - 1:
			var p = i * 2
			idx.append_array([p, p + 1, p + 2, p + 1, p + 3, p + 2])
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	var nr = PackedVector3Array()
	nr.resize(v.size())
	nr.fill(Vector3.UP)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func sumi_nagashi(pj, c: Node3D, t: Node3D) -> void:
	var id = "sumi_nagashi"
	var tt = pj.tg(c, t, 17.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.0)
	var o: Vector3 = pj.gp(c.global_position + d * 0.6)
	var end: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 11.0)
	var side = Vector3.UP.cross(d).normalized()
	var pts = []
	var R = 34
	for i in R:
		var u = float(i) / float(R - 1)
		var zig = sin(u * 15.0) * 0.8 * sin(u * PI)
		var q: Vector3 = o.lerp(end, u) + side * zig
		pts.append(pj.gp(q) + Vector3.UP * 0.05 - o)
	var mi = MeshInstance3D.new()
	mi.mesh = _stream_mesh(pts)
	mi.material_override = _mat("sumi_akis", STREAM_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-24, -6, -24), Vector3(48, 12, 48))
	pj.scene_add(mi, o)
	mi.set_instance_shader_parameter("fade", 1.0)
	_param(mi, "k", 0.0, 1.02, 0.6)
	Sfx.play("water", o, 0.7, 0.4)
	var cw = weakref(c)
	var mw = weakref(mi)
	pj.after(0.62, func():
		var cc = cw.get_ref()
		var caught = null
		if cc != null and pj.live(cc):
			var bd = 2.6
			for e in pj.enemies_near(cc, end, 2.6):
				var q = e.global_position.distance_to(end)
				if q < bd:
					bd = q
					caught = e
		if caught != null:
			_coil(pj, cw, caught, id)
		var m2 = mw.get_ref()
		if m2 != null:
			_param(m2, "fade", 1.0, 0.0, 2.4 if caught != null else 0.7)
			m2.get_tree().create_timer(2.5 if caught != null else 0.75).timeout.connect(m2.queue_free))


static func _coil(pj, cw: WeakRef, e: Node3D, id: String) -> void:
	var T = 2.3
	pj.st(e, "bind", T)
	var cc = cw.get_ref()
	if cc != null and pj.live(cc):
		e.take_hit(pj.inf(cc, id, 0.45, {"knock": 0.0, "kind": "light", "hitstop": 0.04}))
	var h = _height(e)
	var R = 0.3 * clampf(h / 1.72, 0.7, 6.0)
	for s in 4:
		var pts = []
		var ph = s * TAU / 4.0
		var turns = 2.1 + s * 0.28
		for i in 70:
			var u = i / 69.0
			var a = ph + u * turns * TAU
			var y = lerpf(0.06 + s * 0.03, h * (0.5 + s * 0.13), u)
			var r = R * (1.28 - 0.3 * abs(sin(y / h * PI * 1.1 + 0.3))) + (1.0 - u) * 0.34
			pts.append(Vector3(cos(a) * r, y, sin(a) * r))
		var mi = MeshInstance3D.new()
		mi.mesh = _tube(pts, 0.052 * clampf(h / 1.72, 0.8, 4.0))
		mi.material_override = _mat("sumi_yilan", COIL_SH)
		mi.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, h + 2.0, 8))
		e.add_child(mi)
		mi.set_instance_shader_parameter("fade", 1.0)
		_param(mi, "k", 0.0, 1.0, 0.42 + s * 0.05)
		var tw = mi.create_tween()
		tw.tween_interval(T - 0.4)
		tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4)
		tw.tween_callback(mi.queue_free)
	var ew = weakref(e)
	pj.every(T - 0.3, 0.65, func(_i, _k):
		var c2 = cw.get_ref()
		var e2 = ew.get_ref()
		if c2 != null and pj.live(c2) and e2 != null and pj.live(e2):
			e2.take_hit(pj.inf(c2, id, 0.18, {"knock": 0.0, "kind": "light", "hitstop": 0.0})))
