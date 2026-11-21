extends RefCounted
## Eksik jutsular, parti 3 (hedef: res://scripts/combat/fx/jutsu_p3_fx.gd). Kaynak: refs/new/<id>.
## Her teknik kendi gölgelendiricisi ve geometrisiyle; hasar, hedef ve durumlar oyunun sistemlerinden. Oyuncu ve düşman aynı kod.

const Amagasa = preload("res://scripts/combat/fx/amagasa_fx.gd")

static var _mats := {}
static var _meshes := {}

const RAIN_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, skip_vertex_transform;
instance uniform float k = 1.0;
varying float along;
varying float life;
void vertex() {
	float t = fract(TIME * COLOR.g * 2.0 + COLOR.r);
	vec3 base = NORMAL * t * 11.0;
	vec3 p = base + NORMAL * COLOR.b * 2.0 * UV.y;
	vec4 v = MODELVIEW_MATRIX * vec4(p, 1.0);
	vec2 d = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xy + vec2(0.0001));
	v.xy += vec2(-d.y, d.x) * UV.x * 0.012;
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	along = UV.y;
	life = t;
}
void fragment() {
	ALBEDO = mix(vec3(0.72, 0.9, 0.82), vec3(0.85, 0.08, 0.1), smoothstep(0.72, 1.0, along));
	ALPHA = k * smoothstep(0.0, 0.3, along) * smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.82, 1.0, life));
}
"""

const STUCK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float k = 1.0;
void fragment() {
	ALBEDO = mix(vec3(0.5, 0.06, 0.08), vec3(0.78, 0.86, 0.82), UV.y);
	ALPHA = k;
}
"""

const WIRE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float k = 1.0;
void fragment() {
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	float run = 0.55 + 0.45 * sin(UV.x * 34.0 - TIME * 16.0);
	ALBEDO = mix(vec3(0.3, 0.62, 0.95), vec3(0.92, 0.98, 1.0), edge * run);
	ALPHA = smoothstep(0.0, 0.55, edge) * k;
}
"""

const DANCE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float k = 1.0;
void fragment() {
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	float grain = 0.5 + 0.5 * sin(UV.x * 42.0 + UV.y * 5.0);
	ALBEDO = mix(vec3(0.34, 0.02, 0.07), vec3(0.86, 0.1, 0.2), edge * (0.6 + 0.4 * grain));
	ALPHA = smoothstep(0.0, 0.35, edge) * smoothstep(0.0, 0.2, UV.x) * (1.0 - smoothstep(0.55, 1.0, UV.x)) * k;
}
"""

const TRAIL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(0.78, 0.07, 0.16);
	ALPHA = edge * UV.y * UV.y * 0.8;
}
"""

const HAIR_SH := """shader_type spatial;
render_mode cull_disabled, specular_disabled;
varying float tip;
void vertex() {
	tip = clamp(UV.y, 0.0, 1.0);
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(COLOR.rgb * 0.62, COLOR.rgb * 1.12, smoothstep(0.1, 0.9, 1.0 - tip)) + rim * 0.12;
	ROUGHNESS = 0.8;
}
"""

const SWIRL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float k = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arm = sin(a * 3.0 + log(r + 0.04) * 7.0 + TIME * 5.0);
	float fine = sin(a * 7.0 - log(r + 0.04) * 11.0 + TIME * 7.0);
	float m = smoothstep(0.25, 0.92, arm) + 0.35 * smoothstep(0.55, 1.0, fine);
	float d = smoothstep(1.0, 0.72, r) * smoothstep(0.06, 0.24, r);
	ALBEDO = mix(vec3(0.34, 0.6, 0.86), vec3(0.9, 0.97, 1.0), clamp(m, 0.0, 1.0));
	ALPHA = clamp(m, 0.0, 1.0) * d * 0.72 * k;
}
"""

const WISP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float k = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float f = 0.5 + 0.5 * sin(UV.x * 18.0 - TIME * 9.0);
	ALBEDO = mix(vec3(0.42, 0.7, 0.95), vec3(0.94, 0.98, 1.0), f * e);
	ALPHA = smoothstep(0.0, 0.7, e) * sin(UV.x * 3.14159) * (0.35 + 0.65 * f) * k;
}
"""

const POINT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_add;
instance uniform float k = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.5, 0.8, 1.0), vec3(1.0), smoothstep(0.5, 0.05, r));
	ALPHA = smoothstep(1.0, 0.0, r) * k;
}
"""


# ------------------------------------------------------------------ altyapı
static func _mat(key: String, code: String) -> ShaderMaterial:
	if not _mats.has(key):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_mats[key] = m
	return _mats[key]


static func _mi(mesh: Mesh, m: Material) -> MeshInstance3D:
	var x = MeshInstance3D.new()
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


static func _put(pj, n: Node3D, p: Vector3) -> Node3D:
	pj.get_tree().current_scene.add_child(n)
	n.global_position = p
	return n


static func _fade(g: GeometryInstance3D, a: float, b: float, t: float, kill := false) -> void:
	g.set_instance_shader_parameter("k", a)
	var fn = func(v: float) -> void:
		if is_instance_valid(g):
			g.set_instance_shader_parameter("k", v)
	var tw = g.create_tween()
	tw.tween_method(fn, a, b, t)
	if kill:
		tw.tween_callback(g.queue_free)


## Yol boyunca şerit. ns: tek yön ya da nokta başına yüzey yönü
static func _ribbon(pts: Array, w: float, ns) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var c = pts.size()
	for i in c:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, c - 1)]
		var t: Vector3 = (b - a).normalized()
		var nn: Vector3 = ns[i] if ns is Array else ns
		var s: Vector3 = t.cross(nn).normalized()
		var u = float(i) / maxi(c - 1, 1)
		var p: Vector3 = pts[i]
		v.append(p - s * w * 0.5)
		v.append(p + s * w * 0.5)
		n.append(nn)
		n.append(nn)
		uv.append(Vector2(u, 0.0))
		uv.append(Vector2(u, 1.0))
		if i < c - 1:
			var q = i * 2
			idx.append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _chest(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * 1.15


static func _axis(y: Vector3) -> Basis:
	var n = y.normalized()
	var r = Vector3.BACK if absf(n.z) < 0.9 else Vector3.UP
	var x = n.cross(r).normalized()
	return Basis(x, n, x.cross(n).normalized())


# ================================================================== SAMIDARE KEKKA
## Kanon (May Rain Blood River, Shura): şemsiyenin altından senbon yağar; havada süzülürken şemsiye döndürülür, iğneler
## alttakilere saçılır. Oyunda: Amagasa şart (CanonRules), sıçrayıp yavaş süzülür, iğneler hedefin çevresine sarmal iner.
static func samidare_kekka(pj, c: Node3D, t: Node3D) -> void:
	var dur = 2.0
	pj.busy(c, 0.7)
	Amagasa._open(c, 0.03, dur)
	if c is CharacterBody3D:
		c.velocity.y = 10.0
	var tt = pj.tg(c, t, 16.0)
	var rain = _mi(_rain_mesh(), _mat("samidare", RAIN_SH))
	rain.custom_aabb = AABB(Vector3(-12, -13, -12), Vector3(24, 16, 24))
	_put(pj, rain, c.global_position + Vector3.UP * 2.0)
	_fade(rain, 0.0, 1.0, 0.18)
	pj.free_after(dur + 0.6, rain)
	Sfx.play("swing_fan", c.global_position, 0.8, 0.8)
	var step = 0.1
	pj.every(dur, step, func(i: int, _k: float) -> void:
		if not is_instance_valid(rain):
			return
		if pj.live(c):
			rain.global_position = c.global_position + Vector3.UP * 2.0
			rain.rotation.y += 0.62
			if c is CharacterBody3D and c.velocity.y < -1.1:
				c.velocity.y = -1.1
		if i % 2 == 0:
			var ctr: Vector3 = tt.global_position if pj.live(tt) else c.global_position
			var a = i * 1.15
			var r = 0.6 + fmod(i * 0.42, 5.2)
			var g: Vector3 = pj.gp(ctr + Vector3(cos(a), 0.0, sin(a)) * r)
			pj.hit(c, g + Vector3.UP * 0.9, 1.5, pj.inf(c, "samidare_kekka", 0.2, {"knock": 0.6, "kind": "light", "hitstop": 0.0, "bleed": 1.0, "melee": false}))
			_stuck(pj, g)
			Sfx.play("throw_kunai", g, randf_range(1.5, 1.9), 0.3), func() -> void:
		if is_instance_valid(rain):
			_fade(rain, 1.0, 0.0, 0.35, true))


static func _rain_mesh() -> ArrayMesh:
	if _meshes.has("rain"):
		return _meshes["rain"]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var rng = RandomNumberGenerator.new()
	rng.seed = 5150
	for s in 110:
		var a = rng.randf() * TAU
		var o = lerpf(0.08, 0.95, sqrt(rng.randf()))
		var d = Vector3(cos(a) * o, -1.0, sin(a) * o).normalized()
		var c = Color(rng.randf(), rng.randf_range(0.4, 0.75), rng.randf_range(0.25, 0.58))
		var b = v.size()
		for q in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
			v.append(Vector3.ZERO)
			n.append(d)
			col.append(c)
			uv.append(q)
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes["rain"] = m
	return m


## Yere saplanan iğne öbeği (tek ağ, kısa süre kalır)
static func _stuck(pj, g: Vector3) -> void:
	if not _meshes.has("stuck"):
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		var n := PackedVector3Array()
		var idx := PackedInt32Array()
		var rng = RandomNumberGenerator.new()
		rng.seed = 77
		for k in 9:
			var a = rng.randf() * TAU
			var p = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.1, 0.8)
			var tilt = Vector3(rng.randf_range(-0.28, 0.28), 1.0, rng.randf_range(-0.28, 0.28)).normalized()
			var s = tilt.cross(Vector3.RIGHT).normalized() * 0.008
			var b = v.size()
			for q in [[p - s, 0.0], [p + s, 0.0], [p + tilt * 0.32, 1.0]]:
				v.append(q[0])
				uv.append(Vector2(0.5, q[1]))
				n.append(Vector3.UP)
			idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_meshes["stuck"] = m
	var x = _mi(_meshes["stuck"], _mat("samidare_iz", STUCK_SH))
	_put(pj, x, g)
	x.rotation.y = randf() * TAU
	x.set_instance_shader_parameter("k", 1.0)
	var tw = x.create_tween()
	tw.tween_interval(1.8)
	var out = func() -> void:
		_fade(x, 1.0, 0.0, 0.5, true)
	tw.tween_callback(out)


# ================================================================== AYAMETORI
## Kanon (Murderous Grasp, Monju; Tora-I-Saru-Tora): chakrayla güçlenmiş metal tel; ellerde ip oyunu şekli kurulur, şekil
## kesici saldırı olarak fırlatılır; tel hedefi sıkar, çeliği keser. Oyunda: şekil kaçırılabilir mermi; değerse bağlar,
## sonunda savunmayı deler.
static func ayametori(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.95)
	var tt = pj.tg(c, t, 26.0)
	var fig = _mi(_figure_mesh(), _mat("ayame_tel", WIRE_SH))
	var holder = Node3D.new()
	holder.add_child(fig)
	_put(pj, holder, _chest(c))
	fig.scale = Vector3.ONE * 0.2
	fig.create_tween().tween_property(fig, "scale", Vector3.ONE * 0.62, 0.55).set_trans(Tween.TRANS_BACK)
	pj.every(0.7, 0.05, func(_i: int, _k: float) -> void:
		if is_instance_valid(holder) and pj.live(c):
			var f: Vector3 = pj.fwd(c, tt)
			holder.global_position = (pj.hand_pos(c, true) + pj.hand_pos(c, false)) * 0.5 + f * 0.25
			holder.look_at(holder.global_position + f, Vector3.UP))
	Sfx.play("chain", c.global_position, 1.8, 0.45)
	pj.after(0.72, func() -> void:
		if is_instance_valid(holder):
			holder.queue_free()
		if not pj.live(c):
			return
		var from: Vector3 = _chest(c) + pj.fwd(c, tt) * 0.5
		var dir: Vector3 = (_chest(tt) - from).normalized() if pj.live(tt) else pj.fwd(c, tt)
		var fly = _mi(_figure_mesh(), _mat("ayame_tel", WIRE_SH))
		fly.scale = Vector3.ONE * 0.95
		var hooked = {"t": null}
		var land = func(_p: Vector3, who: Node3D) -> void:
			if who != null and pj.live(who):
				hooked["t"] = who
				_constrict(pj, c, who)
		var pr = pj.shot(c, from, dir, 40.0, fly, pj.inf(c, "ayametori", 0.42, {"knock": 0.4, "kind": "light", "melee": false}), null, false, 0.72, land)
		pr.radius = 0.55
		pr.spin = Vector3(0.0, 0.0, 9.0)
		var end_fn = func() -> Vector3:
			if pj.live(hooked["t"]):
				return _chest(hooked["t"])
			return pr.global_position if is_instance_valid(pr) else from
		var start_fn = func() -> Vector3:
			return pj.hand_pos(c, true) if pj.live(c) else from
		_wire(pj, start_fn, end_fn, 2.3, 0.022, 0.1)
		Sfx.play("whoosh", from, 1.7, 0.7))


## İp oyunu şekli: çember üzerinde yıldız kirişleri + iç baklava; yerel XY düzleminde
static func _figure_mesh() -> ArrayMesh:
	if _meshes.has("figure"):
		return _meshes["figure"]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var add = func(a: Vector3, b: Vector3, w: float) -> void:
		var d: Vector3 = (b - a).normalized()
		var s: Vector3 = d.cross(Vector3.BACK).normalized() * w * 0.5
		var q = v.size()
		for e in [[a - s, 0.0, 0.0], [a + s, 0.0, 1.0], [b + s, 1.0, 1.0], [b - s, 1.0, 0.0]]:
			v.append(e[0])
			n.append(Vector3.BACK)
			uv.append(Vector2(e[1], e[2]))
		idx.append_array(PackedInt32Array([q, q + 1, q + 2, q, q + 2, q + 3]))
	var pts := []
	for k in 9:
		var a = TAU * k / 9.0 + 0.35
		pts.append(Vector3(cos(a), sin(a) * 0.82, 0.0) * 0.62)
	for k in 9:
		add.call(pts[k], pts[(k + 4) % 9], 0.016)
	var dm := [Vector3(0.0, 0.3, 0.0), Vector3(0.24, 0.0, 0.0), Vector3(0.0, -0.3, 0.0), Vector3(-0.24, 0.0, 0.0)]
	for k in 4:
		add.call(dm[k], dm[(k + 1) % 4], 0.02)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes["figure"] = m
	return m


## İki hareketli nokta arası dalgalı tel
static func _wire(pj, a_fn: Callable, b_fn: Callable, dur: float, w: float, amp: float) -> void:
	var im = ImmediateMesh.new()
	var x = _mi(im, _mat("ayame_tel", WIRE_SH))
	x.extra_cull_margin = 16384.0
	_put(pj, x, Vector3.ZERO)
	x.global_transform = Transform3D.IDENTITY
	pj.free_after(dur + 0.3, x)
	var clock = {"t": 0.0}
	pj.every(dur, 0.033, func(_i: int, k: float) -> void:
		if not is_instance_valid(x):
			return
		clock["t"] += 0.033
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		var d: Vector3 = b - a
		var side: Vector3 = d.cross(Vector3.UP).normalized() if d.length() > 0.05 else Vector3.RIGHT
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var seg = 22
		for j in seg + 1:
			var u = float(j) / seg
			var wob = sin(u * 13.0 + clock["t"] * 18.0) * amp * sin(u * PI) * (1.0 - k)
			var p: Vector3 = a.lerp(b, u) + side * wob + Vector3.UP * wob * 0.6
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(p - Vector3.UP * w * 0.5)
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(p + Vector3.UP * w * 0.5)
		im.surface_end())


## Tel sarılır, daralır, sonunda keser
static func _constrict(pj, c: Node3D, who: Node3D) -> void:
	var hold = 1.5
	pj.st(who, "bind", hold)
	Sfx.play("chain", who.global_position, 1.5, 0.7)
	var rings := []
	for k in 3:
		var pts := []
		var ns := []
		for j in 29:
			var a = TAU * j / 28.0
			var o = Vector3(cos(a), 0.0, sin(a))
			pts.append(o + Vector3.UP * sin(a * 2.0 + k) * 0.05)
			ns.append(o)
		var r = _mi(_ribbon(pts, 0.03, ns), _mat("ayame_tel", WIRE_SH))
		_put(pj, r, who.global_position)
		pj.free_after(hold + 0.45, r)
		rings.append(r)
	pj.every(hold, 0.04, func(_i: int, u: float) -> void:
		if not pj.live(who):
			return
		for k in 3:
			var r2: MeshInstance3D = rings[k]
			if is_instance_valid(r2):
				var s = lerpf(0.95, 0.34, smoothstep(0.0, 0.5, u))
				r2.scale = Vector3(s, 1.0, s)
				r2.global_position = who.global_position + Vector3.UP * (0.75 + k * 0.38)
				r2.rotation.y += 0.25 + k * 0.1, func() -> void:
		for r3 in rings:
			if is_instance_valid(r3):
				_fade(r3, 1.0, 0.0, 0.2, true)
		if pj.live(c) and pj.live(who):
			pj.hit(c, _chest(who), 0.9, pj.inf(c, "ayametori", 0.85, {"knock": 2.0, "pierce_guard": true, "bleed": 2.0, "melee": false}))
			_cut_line(pj, _chest(who), pj.fwd(c, who))
			Sfx.play("hit_blade", who.global_position, 1.3, 0.8))


static func _cut_line(pj, at: Vector3, f: Vector3) -> void:
	var s: Vector3 = f.cross(Vector3.UP).normalized()
	var pts := []
	for k in 9:
		var u = k / 8.0 * 2.0 - 1.0
		pts.append(at + s * u * 1.5 + Vector3.UP * u * 0.42)
	var x = _mi(_ribbon(pts, 0.05, f), _mat("ayame_tel", WIRE_SH))
	_put(pj, x, Vector3.ZERO)
	x.global_transform = Transform3D.IDENTITY
	_fade(x, 1.0, 0.0, 0.22, true)


# ================================================================== NADESHIKO-RYŪ SHINKU ENBU
## Kanon (Shizuka, Nadeshiko): iki elde pençe gibi tutulan kunailerle kesintisiz, isabetli yağmur; kaçması çok zor.
## Oyunda: havada yana süzülerek beş dalga, hedefi izleyen kunailer; arkalarında koyu kızıl dans izi kalır.
static func nadeshiko_shinku_enbu(pj, c: Node3D, t: Node3D) -> void:
	var waves = 5
	var gap = 0.3
	pj.busy(c, waves * gap + 0.1)
	var tt = pj.tg(c, t, 28.0)
	var claws := []
	for bone in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, bone)
		if ba == null:
			continue
		for k in 3:
			var pv = Node3D.new()
			pv.rotation.z = (k - 1) * 0.42
			var km = _mi(_kunai_mesh(), Props.toon())
			km.material_override = null
			km.rotation.x = -PI * 0.5
			km.position = Vector3(0.0, 0.05, 0.0)
			pv.add_child(km)
			ba.add_child(pv)
		claws.append(ba)
	for w in waves:
		pj.after(0.12 + w * gap, func() -> void:
			if not pj.live(c):
				return
			var right = w % 2 == 0
			var f: Vector3 = pj.fwd(c, tt)
			var side: Vector3 = f.cross(Vector3.UP).normalized() * (1.0 if right else -1.0)
			if c is CharacterBody3D:
				c.velocity = side * 7.0 + Vector3.UP * (4.5 if w % 2 == 0 else 2.5)
			_sweep(pj, c, f, side)
			var from: Vector3 = pj.hand_pos(c, right)
			var aim: Vector3 = (_chest(tt) - from).normalized() if pj.live(tt) else f
			for k in 3:
				var d: Vector3 = aim.rotated(Vector3.UP, (k - 1) * 0.16).normalized()
				_kunai(pj, c, from, d, tt)
			Sfx.play("throw_kunai", from, randf_range(1.0, 1.25), 0.7))
	pj.after(0.2 + waves * gap, func() -> void:
		for ba2 in claws:
			if is_instance_valid(ba2):
				ba2.queue_free())


static func _kunai_mesh() -> Mesh:
	if not _meshes.has("kunai"):
		var b = MB.new()
		CharacterModel._kunai_mesh(b)
		_meshes["kunai"] = b.build(Props.toon())
	return _meshes["kunai"]


static func _kunai(pj, c: Node3D, from: Vector3, d: Vector3, tt: Node3D) -> void:
	var root = Node3D.new()
	var km = MeshInstance3D.new()
	km.mesh = _kunai_mesh()
	km.rotation.y = PI   # uç -Z (mermi yönü)
	root.add_child(km)
	if not _meshes.has("kunai_iz"):
		var q = QuadMesh.new()
		q.size = Vector2(0.09, 1.1)
		_meshes["kunai_iz"] = q
	var tr = _mi(_meshes["kunai_iz"], _mat("nadeshiko_iz", TRAIL_SH))
	tr.rotation.x = PI * 0.5
	tr.position = Vector3(0.0, 0.0, 0.62)
	root.add_child(tr)
	var tr2 = _mi(_meshes["kunai_iz"], _mat("nadeshiko_iz", TRAIL_SH))
	tr2.rotation = Vector3(PI * 0.5, 0.0, PI * 0.5)
	tr2.position = tr.position
	root.add_child(tr2)
	var land = func(p: Vector3, who: Node3D) -> void:
		if who == null:
			_stuck_kunai(pj, p, d)
	var h: Node3D = tt if pj.live(tt) else null
	var pr = pj.shot(c, from, d, 34.0, root, pj.inf(c, "nadeshiko_shinku_enbu", 0.13, {"knock": 0.7, "kind": "light", "hitstop": 0.01, "melee": false}), h, false, 1.1, land)
	pr.radius = 0.2
	pr.homing_turn = 4.2


static func _stuck_kunai(pj, p: Vector3, d: Vector3) -> void:
	var km = MeshInstance3D.new()
	km.mesh = _kunai_mesh()
	_put(pj, km, p + Vector3.UP * 0.05)
	km.look_at(km.global_position - d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	pj.free_after(2.4, km)


## Kolun çizdiği kızıl yay
static func _sweep(pj, c: Node3D, f: Vector3, side: Vector3) -> void:
	var o: Vector3 = _chest(c)
	var pts := []
	for k in 15:
		var u = k / 14.0
		var a = lerpf(-1.1, 1.5, u)
		pts.append(o + (side * cos(a) + f * sin(a)) * lerpf(0.55, 1.15, u) + Vector3.UP * lerpf(-0.3, 0.45, u))
	var x = _mi(_ribbon(pts, 0.2, Vector3.UP), _mat("nadeshiko_yay", DANCE_SH))
	_put(pj, x, Vector3.ZERO)
	x.global_transform = Transform3D.IDENTITY
	_fade(x, 1.0, 0.0, 0.34, true)


# ================================================================== HARI JIGOKU
## Kanon (Needle Hell, Jiraiya; Hari Jizō'dan türer): saç bedeni sarar, sertleşmiş saç iğneleri öne yağar; kayaları deler.
## Oyunda: önce saç kabuğu büyür (hazırlık), sonra deler geçen iğneler. Renk kullanıcının saçı.
static func hari_jigoku(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.25)
	var hair: Color = Color(0.9, 0.86, 0.84)
	var mdl = c.get("model")
	if mdl != null and mdl.look.get("hair") is Color:
		hair = mdl.look["hair"]
	var tt = pj.tg(c, t, 30.0)
	var coat = _mi(_mantle_mesh(hair), _mat("hari_sac", HAIR_SH))
	_put(pj, coat, c.global_position + Vector3.UP * 1.0)
	coat.scale = Vector3.ONE * 0.12
	var tw = coat.create_tween()
	tw.tween_property(coat, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.62)
	tw.tween_property(coat, "scale", Vector3(0.2, 0.3, 0.2), 0.2)
	tw.tween_callback(coat.queue_free)
	pj.every(1.24, 0.033, func(_i: int, _k: float) -> void:
		if is_instance_valid(coat) and pj.live(c):
			coat.global_position = c.global_position + Vector3.UP * 1.0)
	Sfx.play("whoosh", c.global_position, 0.7, 0.8)
	for k in 36:
		pj.after(0.48 + k * 0.016, func() -> void:
			if not pj.live(c):
				return
			var f: Vector3 = pj.fwd(c, tt)
			var aim: Vector3 = (_chest(tt) - _chest(c)).normalized() if pj.live(tt) else f
			var s: Vector3 = f.cross(Vector3.UP).normalized()
			var d: Vector3 = (aim + s * randf_range(-0.62, 0.62) + Vector3.UP * randf_range(-0.24, 0.32)).normalized()
			var from: Vector3 = _chest(c) + d * 0.85 + Vector3.UP * randf_range(-0.3, 0.55)
			var nd = _mi(_needle_mesh(hair), _mat("hari_sac", HAIR_SH))
			var land = func(p: Vector3, who: Node3D) -> void:
				if who == null:
					_needle_stuck(pj, p, d, hair)
			pj.shot(c, from, d, 62.0, nd, pj.inf(c, "hari_jigoku", 0.075, {"knock": 0.8, "kind": "light", "hitstop": 0.0, "bleed": 0.5, "melee": false}), null, true, 0.62, land)
			if k % 6 == 0:
				Sfx.play("throw_kunai", from, randf_range(0.7, 0.9), 0.4))
	pj.after(0.5, func() -> void:
		pj.shake(0.2))


static func _mantle_mesh(hair: Color) -> Mesh:
	var key = "kabuk_" + hair.to_html(false)
	if _meshes.has(key):
		return _meshes[key]
	var b = MB.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 909
	for k in 96:
		var y = rng.randf_range(-0.82, 0.98)
		var a = rng.randf() * TAU
		var r = sqrt(maxf(1.0 - y * y, 0.02))
		var d = Vector3(cos(a) * r, y, sin(a) * r).normalized()
		var ln = rng.randf_range(0.55, 1.1)
		var w = rng.randf_range(0.1, 0.17)
		var col: Color = hair.darkened(rng.randf_range(0.0, 0.14))
		var bs: Basis = _axis(d) * Basis.from_scale(Vector3(w, ln, w))
		b.add_xf("cone", Transform3D(bs, d * (0.42 + ln * 0.5)), col, 5)
	var m: Mesh = b.build()
	_meshes[key] = m
	return m


static func _needle_mesh(hair: Color) -> Mesh:
	var key = "igne_" + hair.to_html(false)
	if not _meshes.has(key):
		var b = MB.new()
		var bs: Basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) * Basis.from_scale(Vector3(0.035, 1.0, 0.035))
		b.add_xf("cone", Transform3D(bs, Vector3.ZERO), hair.lightened(0.08), 4)
		_meshes[key] = b.build()
	return _meshes[key]


static func _needle_stuck(pj, p: Vector3, d: Vector3, hair: Color) -> void:
	var x = _mi(_needle_mesh(hair), _mat("hari_sac", HAIR_SH))
	_put(pj, x, p - d * 0.2)
	x.look_at(x.global_position + d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	var tw = x.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(x, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(x.queue_free)


# ================================================================== SHISHŌ TENKETSU
## Kanon (Pressure Points of Harm and Death, Guren): iki tenketsu açılır, yaşam gücü chakraya çevrilir; görünür chakra
## çevrede girdap yapar, güç ve beden kısa süre artar. Oyunda: canın %18'i gider, chakra dolar, 10 sn güç; bitince yorgunluk.
static func shisho_tenketsu(pj, c: Node3D, _t: Node3D) -> void:
	var dur = 10.0
	pj.busy(c, 0.7)
	var g: Vector3 = pj.gp(c.global_position) + Vector3.UP * 0.06
	var cost: float = float(c.max_hp) * 0.18
	c.hp = maxf(1.0, float(c.hp) - cost)
	Combat.popup_text(c.global_position + Vector3.UP * 2.3, "-%d can" % int(cost), Color(1.0, 0.5, 0.45))
	if c.get("chakra") != null:
		c.chakra = minf(float(c.max_chakra), float(c.chakra) + float(c.max_chakra) * 0.45)
	var mods = {"jutsu": 1.25, "melee": 1.2, "speed": 1.12}
	if c is Player:
		var pm = mods.duplicate()
		pm["_name"] = "Shishō Tenketsu"
		pm["_desc"] = "yaşam gücü chakraya dönüştü"
		Buffs.add("shisho_tenketsu", dur, pm)
	elif c.has_method("add_buff"):
		c.add_buff("shisho_tenketsu", dur, mods)
	# yerde açılan girdap
	if not _meshes.has("girdap"):
		var q = QuadMesh.new()
		q.size = Vector2(10.0, 10.0)
		q.orientation = PlaneMesh.FACE_Y
		_meshes["girdap"] = q
	var sw = _mi(_meshes["girdap"], _mat("shisho_girdap", SWIRL_SH))
	_put(pj, sw, g)
	sw.scale = Vector3.ONE * 0.2
	_fade(sw, 1.0, 1.0, 0.01)
	var tw = sw.create_tween()
	tw.tween_property(sw, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	var out = func() -> void:
		_fade(sw, 1.0, 0.0, 0.5, true)
	tw.tween_callback(out)
	# bedeni saran chakra kolları
	var wisps := []
	for k in 3:
		var pts := []
		var ns := []
		for j in 25:
			var u = j / 24.0
			var a = u * TAU * 1.5 + k * TAU / 3.0
			var o = Vector3(cos(a), 0.0, sin(a))
			pts.append(o * lerpf(0.62, 0.4, u) + Vector3.UP * lerpf(0.0, 2.1, u))
			ns.append(o)
		var w = _mi(_ribbon(pts, 0.17, ns), _mat("shisho_kol", WISP_SH))
		_put(pj, w, c.global_position)
		w.set_instance_shader_parameter("k", 1.0)
		pj.free_after(dur + 0.5, w)
		wisps.append(w)
	# açılan iki nokta
	var ba = pj.bone_attach(c, "UpperChest")
	if ba != null:
		if not _meshes.has("nokta"):
			var q2 = QuadMesh.new()
			q2.size = Vector2(0.2, 0.2)
			_meshes["nokta"] = q2
		for s in [-1.0, 1.0]:
			var d = _mi(_meshes["nokta"], _mat("shisho_nokta", POINT_SH))
			d.position = Vector3(s * 0.07, 0.03, 0.12)
			ba.add_child(d)
			_fade(d, 1.0, 0.0, 1.4)
		pj.free_after(1.6, ba)
	pj.shake(0.45)
	Sfx.play("roar", c.global_position, 1.4, 0.5)
	Sfx.play("wind", c.global_position, 0.7, 0.8)
	pj.every(dur, 0.05, func(i: int, k: float) -> void:
		if not pj.live(c):
			return
		for j in wisps.size():
			var w2: MeshInstance3D = wisps[j]
			if is_instance_valid(w2):
				w2.global_position = c.global_position
				w2.rotation.y -= 0.16
				w2.set_instance_shader_parameter("k", lerpf(1.0, 0.3, smoothstep(0.0, 0.14, k)) * (1.0 - smoothstep(0.93, 1.0, k)))
		if i > 0 and i % 40 == 0:
			c.hp = maxf(1.0, float(c.hp) - float(c.max_hp) * 0.008), func() -> void:
		for w3 in wisps:
			if is_instance_valid(w3):
				w3.queue_free()
		if pj.live(c):
			pj.st(c, "slow", 3.0)
			Combat.popup_text(c.global_position + Vector3.UP * 2.3, "Bitkin", Color(0.75, 0.82, 0.95)))
