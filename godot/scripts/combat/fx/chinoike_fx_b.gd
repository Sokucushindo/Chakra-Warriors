class_name KetsuryuFX
extends RefCounted
## Chinoike (Ketsuryūgan) dört teknik + Fūma Chakura no Ito. Kaynak: Narutopedia — Genjutsu: Ketsuryūgan (göz / ten teması,
## beyin yıkama ya da rüya hâli, anı okuma), Chino (demirli suyu duvar ve damla olarak yönetir; su yoksa kendi kanı),
## Chakra Threads (Fūma): iki kalbi bağlayan kırık mavi ipler, birine gelen iç hasar ötekine de işler, biri ölürse öteki de.
## Görünen her şey bu dosyanın kendi gölgelendiricileri ve şekilleriyle sıfırdan üretilir (ortak efekt kütüphanesi yok).

static var _c := {}

const RUST_D := Color(0.3, 0.05, 0.04)
const RUST_L := Color(0.76, 0.24, 0.13)
const RUST_S := Color(1.0, 0.72, 0.5)
const EYE_R := Color(1.0, 0.12, 0.1, 1.0)
const VEIN := Color(0.85, 0.06, 0.08, 1.0)
const MEM := Color(1.0, 0.86, 0.82, 0.9)
const ITO := Color(0.35, 0.62, 1.0, 1.0)


# ================================================================== gölgelendiriciler (kendi)
## Demirli su: cel sıvı, yukarı akan parlak bantlar, mürekkep kenar; kameraya yakın söner
const LIQ_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;
uniform vec4 deep : source_color = vec4(0.24, 0.02, 0.03, 1.0);
uniform vec4 lite : source_color = vec4(0.55, 0.07, 0.06, 1.0);
uniform vec4 shine : source_color = vec4(0.95, 0.42, 0.32, 1.0);
uniform float flow_v = 1.4;
uniform vec2 near_d = vec2(1.2, 3.4);
instance uniform float fade_k = 1.0;
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float fr = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float n = vn(UV * vec2(18.0, 2.2) + vec2(0.0, -TIME * flow_v));
	float band = step(0.7, n) * (1.0 - step(0.8, n));
	float rust = vn(UV * vec2(9.0, 5.0) + vec2(TIME * 0.2, 0.0));
	vec3 col = mix(lite.rgb, deep.rgb, smoothstep(0.2, 0.7, fr));
	col = mix(col, shine.rgb, band * 0.7 * (1.0 - fr));
	col = mix(col, vec3(0.42, 0.18, 0.08), step(0.78, rust) * 0.35);
	col = mix(col, vec3(0.07, 0.015, 0.015), step(0.86, fr));
	ALBEDO = col;
	ALPHA = 0.93 * fade_k * smoothstep(near_d.x, near_d.y, -VERTEX.z);
}
"""

## Işıltı: yumuşak disk ya da ince halka (toplamalı)
const GLINT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform vec4 tint = vec4(1.0, 0.2, 0.2, 1.0);
instance uniform float fade_k = 1.0;
instance uniform float ring_k = 0.0;
uniform vec2 near_d = vec2(0.35, 1.4);
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float disc = 1.0 - smoothstep(0.0, 1.0, r);
	float ring = smoothstep(0.72, 0.86, r) * (1.0 - smoothstep(0.9, 1.0, r));
	float m = mix(disc * disc, ring, ring_k);
	ALBEDO = mix(tint.rgb, vec3(1.0), disc * disc * disc * (1.0 - ring_k) * 0.6);
	ALPHA = clamp(m * tint.a * fade_k * smoothstep(near_d.x, near_d.y, -VERTEX.z), 0.0, 1.0);
}
"""

## İp / damar şeridi: kesik kesik akan, ortası beyaz çekirdekli (toplamalı)
const THREAD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform vec4 tint = vec4(0.35, 0.62, 1.0, 1.0);
instance uniform float fade_k = 1.0;
instance uniform float dash_n = 12.0;
void fragment() {
	float s = fract(UV.x * dash_n - TIME * 1.6);
	float d = step(0.2, s);
	float core = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), core * core * 0.75);
	ALPHA = clamp(d * smoothstep(0.0, 0.45, core) * tint.a * fade_k, 0.0, 1.0);
}
"""

## Anı karesi: soluk kâğıt levha, içinde titreyen bulanık lekeler, kızıl kenar
const MEM_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
instance uniform float sd = 0.0;
uniform vec2 near_d = vec2(0.5, 1.6);
float h2(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1)) + sd * 17.0) * 15731.7); }
void fragment() {
	vec2 q = abs(UV * 2.0 - 1.0);
	float edge = step(0.86, max(q.x, q.y));
	float blot = step(0.55, h2(floor(UV * 5.0) + floor(TIME * 6.0)));
	vec3 col = mix(vec3(1.0, 0.9, 0.86), vec3(0.55, 0.38, 0.36), blot * 0.6);
	col = mix(col, vec3(0.75, 0.08, 0.08), edge);
	ALBEDO = col;
	ALPHA = 0.85 * fade_k * smoothstep(near_d.x, near_d.y, -VERTEX.z);
}
"""


static func _sh(key: String, code: String) -> Shader:
	var k = "sh:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		_c[k] = s
	return _c[k]


static func _mat(key: String) -> ShaderMaterial:
	var k = "mat:" + key
	if not _c.has(k):
		var m = ShaderMaterial.new()
		match key:
			"liq": m.shader = _sh("liq", LIQ_SH)
			"glint": m.shader = _sh("glint", GLINT_SH)
			"thread": m.shader = _sh("thread", THREAD_SH)
			"mem": m.shader = _sh("mem", MEM_SH)
		_c[k] = m
	return _c[k]


static func _sphere() -> Mesh:
	if not _c.has("mesh:sph"):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 14
		s.rings = 8
		_c["mesh:sph"] = s
	return _c["mesh:sph"]


static func _quad() -> Mesh:
	if not _c.has("mesh:quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_c["mesh:quad"] = q
	return _c["mesh:quad"]


# ================================================================== yapı taşları
static func _put(pj: Node, n: Node3D, pos: Vector3) -> Node3D:
	pj.add_child(n)
	n.global_position = pos
	return n


static func _gi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _fade(gi: GeometryInstance3D, delay: float, t: float) -> void:
	if not is_instance_valid(gi):
		return
	var tw = gi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		if is_instance_valid(gi):
			gi.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, t)
	tw.tween_callback(gi.queue_free)


## Kameraya dönük ışıltı levhası (disk / halka)
static func _glint(pj: Node, pos: Vector3, size: float, col: Color, life: float, ring := false, grow := 1.0) -> MeshInstance3D:
	var g = _gi(_quad(), _mat("glint"))
	_put(pj, g, pos)
	g.set_instance_shader_parameter("tint", col)
	g.set_instance_shader_parameter("ring_k", 1.0 if ring else 0.0)
	g.scale = Vector3.ONE * size
	var cam = pj.get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > 0.05:
		g.look_at(cam.global_position, Vector3.UP if absf((cam.global_position - pos).normalized().y) < 0.98 else Vector3.FORWARD)
	if grow != 1.0:
		g.create_tween().tween_property(g, "scale", Vector3.ONE * size * grow, life)
	_fade(g, life * 0.35, life * 0.65)
	return g


## Yere yatık halka / leke
static func _floor_ring(pj: Node, pos: Vector3, size: float, col: Color, life: float, grow: float, ring := true) -> void:
	var g = _gi(_quad(), _mat("glint"))
	_put(pj, g, pos + Vector3.UP * 0.05)
	g.rotation.x = -PI * 0.5
	g.set_instance_shader_parameter("tint", col)
	g.set_instance_shader_parameter("ring_k", 1.0 if ring else 0.0)
	g.scale = Vector3.ONE * size
	g.create_tween().tween_property(g, "scale", Vector3.ONE * size * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade(g, life * 0.3, life * 0.7)


## Damlacık sıçrağı: balistik demirli su damlaları, yere değince söner
class Drops extends Node3D:
	var vel: Array = []
	var life := 0.8
	var t := 0.0
	var floor_y := -1000.0

	func _process(dt: float) -> void:
		t += dt
		if t > life:
			queue_free()
			return
		var k = 0
		for ch in get_children():
			if k >= vel.size():
				break
			var v: Vector3 = vel[k]
			v += Vector3.DOWN * 14.0 * dt
			vel[k] = v
			ch.global_position += v * dt
			if ch.global_position.y < floor_y:
				ch.visible = false
			ch.scale *= 1.0 - dt * 0.8
			k += 1


static func _splash(pj: Node, pos: Vector3, n: int, spd: float, size: float, up := Vector3.UP, spread := 1.0) -> void:
	var d = Drops.new()
	pj.add_child(d)
	d.global_position = Vector3.ZERO
	d.floor_y = Game.jutsu_floor(pos.x, pos.z) - 0.05
	for i in n:
		var g = _gi(_sphere(), _mat("liq"))
		d.add_child(g)
		g.global_position = pos
		g.scale = Vector3.ONE * size * randf_range(0.6, 1.3)
		var v = (up + Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)) * spread).normalized() * spd * randf_range(0.5, 1.1)
		d.vel.append(v)


## Canlı şerit: iki uç her karede yeniden okunur; kırık (titrek) ya da düz; kameraya dönük
class Strand extends MeshInstance3D:
	var a_fn: Callable
	var b_fn: Callable
	var w := 0.03
	var jag := 0.1
	var life := 1.0
	var t := 0.0
	var segs := 14
	var flick := 12.0
	var im := ImmediateMesh.new()

	func _ready() -> void:
		mesh = im
		top_level = true
		global_transform = Transform3D.IDENTITY
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(dt: float) -> void:
		t += dt
		if t > life or not a_fn.is_valid() or not b_fn.is_valid():
			queue_free()
			return
		var a = a_fn.call()
		var b = b_fn.call()
		if a == null or b == null:
			queue_free()
			return
		var cam = get_viewport().get_camera_3d()
		var eye: Vector3 = cam.global_position if cam else a + Vector3.UP * 5.0
		var ab: Vector3 = b - a
		if ab.length() < 0.01:
			return
		var dirv = ab.normalized()
		var fl = floor(t * flick)
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in segs + 1:
			var k = float(i) / segs
			var p: Vector3 = a.lerp(b, k)
			if i > 0 and i < segs:
				p += Vector3(sin(i * 12.9 + fl * 3.1), cos(i * 7.3 + fl * 1.7), sin(i * 3.7 + fl * 2.3)) * jag * sin(k * PI)
			var side: Vector3 = dirv.cross((eye - p).normalized())
			if side.length() < 0.001:
				side = Vector3.RIGHT
			side = side.normalized() * w
			im.surface_set_uv(Vector2(k, 0.0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(k, 1.0))
			im.surface_add_vertex(p + side)
		im.surface_end()
		set_instance_shader_parameter("fade_k", clampf((life - t) / 0.35, 0.0, 1.0) * clampf(t / 0.12, 0.0, 1.0))


static func _strand(pj: Node, a_fn: Callable, b_fn: Callable, col: Color, life: float, w: float, jag: float, dash := 12.0) -> Strand:
	var s = Strand.new()
	s.a_fn = a_fn
	s.b_fn = b_fn
	s.life = life
	s.w = w
	s.jag = jag
	s.material_override = _mat("thread")
	pj.add_child(s)
	s.set_instance_shader_parameter("tint", col)
	s.set_instance_shader_parameter("dash_n", dash)
	return s


## Bedene dolanan kısa kırık ip parçaları (ref: Kagerō'nun ipleri Naruto'nun gövdesinde kısa mavi çizgiler)
class Wrap extends MeshInstance3D:
	var body: WeakRef
	var life := 2.0
	var t := 0.0
	var n := 12
	var rad := 0.45
	var hgt := 1.8
	var im := ImmediateMesh.new()
	var segs: Array = []
	var rt := 0.0

	func _ready() -> void:
		mesh = im
		top_level = true
		global_transform = Transform3D.IDENTITY
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func _process(dt: float) -> void:
		t += dt
		var b = body.get_ref() if body else null
		if t > life or b == null or not is_instance_valid(b):
			queue_free()
			return
		rt -= dt
		if rt <= 0.0 or segs.is_empty():
			rt = 0.12
			segs.clear()
			for i in n:
				segs.append([randf() * TAU, randf_range(0.1, 0.92), randf_range(0.25, 0.6), randf_range(-0.35, 0.35)])
		var cam = get_viewport().get_camera_3d()
		var base: Vector3 = b.global_position
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in segs:
			var a0: float = s[0]
			var y0: float = s[1] * hgt
			var p0 = base + Vector3(cos(a0) * rad, y0, sin(a0) * rad)
			var p1 = base + Vector3(cos(a0 + s[2]) * rad, y0 + float(s[3]) * 0.4, sin(a0 + s[2]) * rad)
			var eye: Vector3 = cam.global_position if cam else p0 + Vector3.UP
			var side = (p1 - p0).normalized().cross((eye - p0).normalized()).normalized() * 0.018
			for v in [[p0 - side, Vector2(0, 0)], [p0 + side, Vector2(0, 1)], [p1 + side, Vector2(1, 1)], [p0 - side, Vector2(0, 0)], [p1 + side, Vector2(1, 1)], [p1 - side, Vector2(1, 0)]]:
				im.surface_set_uv(v[1])
				im.surface_add_vertex(v[0])
		im.surface_end()
		set_instance_shader_parameter("fade_k", clampf((life - t) / 0.4, 0.0, 1.0))


static func _wrap(pj: Node, x: Node3D, col: Color, life: float, n := 12) -> void:
	var w = Wrap.new()
	w.body = weakref(x)
	w.life = life
	w.n = n
	w.hgt = float(x.get("height")) if x.get("height") != null else 1.8
	w.rad = (float(x.get("radius")) if x.get("radius") != null else 0.38) + 0.12
	w.material_override = _mat("thread")
	pj.add_child(w)
	w.set_instance_shader_parameter("tint", col)
	w.set_instance_shader_parameter("dash_n", 1.0)


static func _head(x: Node3D) -> Vector3:
	var h = float(x.get("height")) if x.get("height") != null else 1.8
	return x.global_position + Vector3.UP * h * 0.92


static func _chest(x: Node3D) -> Vector3:
	var h = float(x.get("height")) if x.get("height") != null else 1.8
	return x.global_position + Vector3.UP * h * 0.68


static func _fwd(x: Node3D) -> Vector3:
	if x.has_method("face_dir"):
		var f: Vector3 = x.face_dir()
		f.y = 0.0
		if f.length() > 0.01:
			return f.normalized()
	return -x.global_transform.basis.z


## Ketsuryūgan uyanışı: iki gözde kızıl ışıltı + gözden yanaklara inen ince kan damarları (dur sn)
static func _ketsu_eyes(pj: Node, c: Node3D, dur: float) -> void:
	var cw = weakref(c)
	var f = _fwd(c)
	var sd = f.cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:
		var off = sd * s * 0.055
		_strand(pj, func():
			var x = cw.get_ref()
			return null if x == null else _head(x) + _fwd(x) * 0.13 + off + Vector3.UP * 0.02, func():
			var x = cw.get_ref()
			return null if x == null else _head(x) + _fwd(x) * 0.12 + off * 1.4 + Vector3.DOWN * 0.11, VEIN, dur, 0.008, 0.012, 3.0)
	for k in int(dur / 0.5) + 1:
		pj.after(k * 0.5, func():
			var x = cw.get_ref()
			if x == null or not is_instance_valid(x):
				return
			var ff = _fwd(x)
			var ss = ff.cross(Vector3.UP).normalized()
			for s in [-1.0, 1.0]:
				_glint(pj, _head(x) + ff * 0.14 + ss * s * 0.055 + Vector3.UP * 0.02, 0.16 if k == 0 else 0.1, EYE_R, 0.55))


## Demirli su kaynağı: yakında su (ya da yağmur) varsa ondan; yoksa kendi bileğini keser (can bedeli)
static func _source(pj: Node, c: Node3D, frac: float) -> bool:
	if CanonRules.water_near(c):
		return true
	if c.get("hp") != null and c.get("max_hp") != null:
		c.hp = maxf(1.0, float(c.hp) - float(c.max_hp) * frac)
	var hp = pj.hand_pos(c) if pj.has_method("hand_pos") else _chest(c)
	_splash(pj, hp, 10, 3.0, 0.07, Vector3.DOWN, 0.6)
	Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Kendi kanı", Color(0.95, 0.25, 0.25))
	return false


# ================================================================== GENJUTSU: KETSURYŪGAN
## Göz teması (ya da dokunuş): zayıf hedefin beyni yıkanır, kendi dostuna saldırır; güçlü hedef rüya hâline düşer.
## Görsel: kızıl gözler, gözden göze akan kan damarı, hedefin başında daralan damar halkası, rüyada dönen kızıl damlalar
static func genjutsu_ketsuryugan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var id = "genjutsu_ketsuryugan"
	var tt = pj.tg(c, t, 10.0)
	_ketsu_eyes(pj, c, 2.2)
	if tt == null:
		return
	pj.busy(c, 0.5)
	pj._face(c, tt)
	var gm = pj._gen_power(c) * Eyes.genjutsu_land(c, tt, true)
	var cw = weakref(c)
	var tw = weakref(tt)
	_strand(pj, func():
		var x = cw.get_ref()
		return null if x == null else _head(x) + _fwd(x) * 0.14, func():
		var y = tw.get_ref()
		return null if y == null else _head(y) + _fwd(y) * 0.12, Color(0.75, 0.0, 0.02, 1.0), 0.7, 0.04, 0.05, 6.0)
	Sfx.play("genjutsu", tt.global_position)
	if gm <= 0.0:
		Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Göz teması yok", Color(0.8, 0.6, 0.6))
		return
	# hedefin başında daralan kızıl damar halkaları
	for k in 3:
		pj.after(0.25 + k * 0.15, func():
			var y = tw.get_ref()
			if y != null and is_instance_valid(y):
				_glint(pj, _head(y), 1.4 - k * 0.3, Color(0.9, 0.08, 0.1, 0.9), 0.5, true, 0.35))
	var others: Array = []
	if tt is Enemy:
		others = pj.enemies_near(c, tt.global_position, 22.0).filter(func(e): return e != tt and is_instance_valid(e) and not e.is_dead())
	var weak = tt is Enemy and Combat.power_of(tt) < Combat.power_of(c) * 0.85 and not others.is_empty()
	if weak:
		# beyin yıkama: kısa süre senin safına geçer, en yakın dostuna saldırır
		var dur = 4.0 * gm
		var old = tt.team
		tt.team = c.team
		var jl: Array = tt.arch.get("jutsu", []) if tt.get("arch") else []
		if jl.is_empty():
			pj.hit(tt, others[0].global_position + Vector3.UP, 1.5, pj.inf(c, id, 1.0, {"knock": 6.0, "kind": "heavy"}))
		else:
			Jutsu.execute(tt, jl.pick_random(), others[0])
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Beyni yıkandı!", Color(1.0, 0.35, 0.35))
		_dream_ring(pj, tt, dur, true)
		pj.after(dur, func():
			var y = tw.get_ref()
			if y != null and is_instance_valid(y):
				y.team = old
				pj.st(y, "stun", 1.0))
		return
	var d2 = 3.0 * gm
	pj.st(tt, "stun", d2)
	pj.st(tt, "fear", d2)
	pj.hit(c, tt.global_position + Vector3.UP, 0.8, pj.inf(c, id, 0.3, {"knock": 0.0, "dir": Vector3.ZERO}))
	Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Rüyaya düştü", Color(1.0, 0.5, 0.5))
	_dream_ring(pj, tt, d2, false)


## Rüya / beyin yıkama süresince başın çevresinde dönen kızıl damlalar, gözlerde boş kızıl ışıltı
static func _dream_ring(pj: Node, x: Node3D, dur: float, wash: bool) -> void:
	var xw = weakref(x)
	var n = 5
	for i in n:
		var a0 = i * TAU / n
		_strand(pj, func():
			var y = xw.get_ref()
			if y == null:
				return null
			var a = a0 + Game.now() * 1.8
			return _head(y) + Vector3(cos(a), 0.12 * sin(Game.now() * 3.0 + a0), sin(a)) * 0.42, func():
			var y = xw.get_ref()
			if y == null:
				return null
			var a = a0 + Game.now() * 1.8 + 0.5
			return _head(y) + Vector3(cos(a), 0.12 * sin(Game.now() * 3.0 + a0 + 0.5), sin(a)) * 0.42, VEIN if wash else Color(0.95, 0.3, 0.35, 0.8), dur, 0.03, 0.0, 2.0)
	for k in int(dur / 0.7) + 1:
		pj.after(k * 0.7, func():
			var y = xw.get_ref()
			if y != null and is_instance_valid(y):
				_glint(pj, _head(y) + _fwd(y) * 0.13, 0.22, Color(1.0, 0.1, 0.1, 0.8), 0.6))


# ================================================================== KETSURYŪGAN: TESSUI HEKI
## Demirli su duvarı (Chino): önünde kızıl-pas sudan kavisli bir sed yükselir; mermileri durdurur, değeni iter.
## Su yoksa kendi kanından (can bedeli %6). 4 sn
static func tessui_heki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	var id = "tessui_heki"
	pj.busy(c, 0.6)
	pj.anim(c, "push", 1.4)
	_ketsu_eyes(pj, c, 1.6)
	var full = _source(pj, c, 0.06)
	var f = _fwd(c)
	var gy = Game.jutsu_floor(c.global_position.x, c.global_position.z)
	var ctr = Vector3(c.global_position.x, gy, c.global_position.z)
	var H = 3.4 if full else 2.6
	var dur = 4.0
	var wall = _gi(_wall_mesh(H), _mat("liq"))
	_put(pj, wall, ctr)
	wall.look_at(ctr + f, Vector3.UP)
	wall.scale = Vector3(1, 0.02, 1)
	var tw = wall.create_tween()
	tw.tween_property(wall, "scale", Vector3(1, 1.08, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(wall, "scale", Vector3.ONE, 0.15)
	tw.tween_interval(dur - 0.8)
	tw.tween_property(wall, "scale", Vector3(1.05, 0.02, 1.05), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(wall.queue_free)
	Sfx.play("water", c.global_position, 0.8)
	# yerden fışkırma + ayak dibinde gölcük
	var sd = f.cross(Vector3.UP).normalized()
	for k in 5:
		var p = ctr + f * 2.4 + sd * (k - 2) * 1.0
		_splash(pj, p + Vector3.UP * 0.1, 6, 6.5, 0.12, Vector3.UP, 0.35)
	_floor_ring(pj, ctr + f * 1.6, 3.2, Color(0.55, 0.08, 0.06, 0.6), dur, 1.3, false)
	pj.after(dur - 0.45, func():
		_splash(pj, ctr + f * 2.4 + Vector3.UP * 0.5, 16, 3.0, 0.14, Vector3.UP, 1.0))
	var cw = weakref(c)
	var wc = ctr + f * 2.4 + Vector3.UP * 1.3
	pj.every(dur, 0.1, func(i, _k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		for pr in pj.get_tree().get_nodes_in_group("projectiles"):
			if pr.shooter == cc or pr.dead:
				continue
			var v: Vector3 = pr.global_position - wc
			if v.length() < 3.6 and v.dot(f) > -1.2:
				_splash(pj, pr.global_position, 5, 3.5, 0.08, -f, 0.6)
				if pr.element() == "":
					pr.block()
					continue
				var r = Elements.clash({"el": "suiton", "pow": 40.0 if full else 30.0}, {"el": pr.element(), "pow": pr.power()})
				pr.apply_clash(r["b_alive"], r["b_scale"])
		if i % 4 == 0:
			pj.hit(cc, wc, 2.4, pj.inf(cc, id, 0.15, {"knock": 9.0, "dir": f, "kind": "light", "hitstop": 0.0})))


## Kavisli sed: 120° yay, dalgalı üst kenar, kalınlığı olan iki yüzlü levha
static func _wall_mesh(H: float) -> Mesh:
	var k = "mesh:wall%.1f" % H
	if _c.has(k):
		return _c[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R = 2.6
	var nx = 24
	var ny = 6
	var a_span = deg_to_rad(120.0)
	var grid: Array = []
	for iy in ny + 1:
		var row: Array = []
		for ix in nx + 1:
			var u = float(ix) / nx
			var v = float(iy) / ny
			var a = -a_span * 0.5 + u * a_span
			var top = H * (0.85 + 0.15 * sin(u * 19.0) * sin(u * 7.0 + 1.3))
			var edge = sin(u * PI)
			var y = v * top * (0.55 + 0.45 * edge)
			var r = R + 0.25 * sin(v * PI) * edge
			row.append([Vector3(sin(a) * r, y, -cos(a) * r), Vector2(u, 1.0 - v), Vector3(sin(a), 0.0, -cos(a))])
		grid.append(row)
	for iy in ny:
		for ix in nx:
			var q = [grid[iy][ix], grid[iy][ix + 1], grid[iy + 1][ix + 1], grid[iy + 1][ix]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][2])
				st.set_uv(q[idx][1])
				st.add_vertex(q[idx][0])
	var m = st.commit()
	_c[k] = m
	return m


# ================================================================== KETSURYŪGAN: TESSUI DAN
## Demirli su damlaları (Chino): omuz çevresinde dönen kızıl-pas damlalar art arda hedefe fırlar; çarpınca sıçrar, kanatır.
## Su varsa 5, yoksa kendi kanından 3 damla (can bedeli %4)
static func tessui_dan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var id = "tessui_dan"
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.9)
	pj._face(c, tt)
	pj.anim(c, "push", 1.3)
	_ketsu_eyes(pj, c, 1.8)
	var full = _source(pj, c, 0.04)
	var n = 5 if full else 3
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var orb: Array = []
	for i in n:
		var b = _gi(_sphere(), _mat("liq"))
		_put(pj, b, c.global_position + Vector3.UP * 0.2)
		b.scale = Vector3.ONE * 0.05
		b.create_tween().tween_property(b, "scale", Vector3.ONE * 0.5, 0.25)
		orb.append(b)
	var t0 = Game.now()
	pj.every(0.3 + n * 0.14, 0.02, func(_i, _k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var ff = _fwd(cc)
		var ss = ff.cross(Vector3.UP).normalized()
		for j in orb.size():
			var b = orb[j]
			if not is_instance_valid(b) or b.get_meta("gone", false):
				continue
			var a = j * TAU / n + (Game.now() - t0) * 5.0
			var tgt = _chest(cc) + ss * cos(a) * 0.9 + Vector3.UP * (0.35 + sin(a) * 0.35) - ff * 0.2
			b.global_position = b.global_position.lerp(tgt, 0.35))
	Sfx.play("water", c.global_position, 1.1)
	for j in n:
		pj.after(0.3 + j * 0.14, func():
			var cc = cw.get_ref()
			var b = orb[j]
			if cc == null or not is_instance_valid(cc) or not is_instance_valid(b):
				return
			b.set_meta("gone", true)
			var x = tw.get_ref() if tw else null
			var from: Vector3 = b.global_position
			var aim: Vector3 = (_chest(x) if x != null and is_instance_valid(x) else from + _fwd(cc) * 20.0) - from
			b.queue_free()
			var shell = Node3D.new()
			var core = _gi(_sphere(), _mat("liq"))
			core.scale = Vector3(0.42, 0.42, 0.7)
			shell.add_child(core)
			for q in 3:
				var tail = _gi(_sphere(), _mat("liq"))
				tail.scale = Vector3.ONE * (0.2 - q * 0.05)
				tail.position = Vector3(0, 0, 0.32 + q * 0.2)
				shell.add_child(tail)
			var info = pj.inf(cc, id, 0.5, {"knock": 6.0, "kind": "heavy", "bleed": 2.0})
			pj.shot(cc, from, aim.normalized(), 30.0, shell, info, x if x != null and pj.live(x) else null, false, 1.6, func(hp_: Vector3, _tg = null):
				var at = hp_ if hp_ != Vector3.ZERO else (shell.global_position if is_instance_valid(shell) else from)
				_splash(pj, at, 14, 5.0, 0.11, -aim.normalized() + Vector3.UP * 0.6, 0.8)
				_floor_ring(pj, Vector3(at.x, Game.jutsu_floor(at.x, at.z), at.z), 0.8, Color(0.5, 0.06, 0.05, 0.7), 1.6, 1.6, false))
			Sfx.play("whoosh", from, 1.2))


# ================================================================== KETSURYŪGAN: KIOKU YOMI
## Anı okuma (Sasuke Shinden: Ketsuryūgan hedefin anılarını görür): eli hedefin alnına koyar; kurban kısa sersemler, anı kareleri
## ondan sana akar. 12 sn boyunca onun (ve herkesin) sıradaki üç saldırısını önceden bilip savuşturursun; tekniklerini öğrenirsin
static func kioku_yomi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var id = "kioku_yomi"
	var tt = pj.tg(c, t, 8.0)
	_ketsu_eyes(pj, c, 2.0)
	if tt != null and c.global_position.distance_to(tt.global_position) > 1.6:
		# ten teması şart: hedefin dibine süzülür (kısa atılış, ayakta kızıl iz)
		var dv: Vector3 = tt.global_position - c.global_position
		dv.y = 0.0
		var to: Vector3 = tt.global_position - dv.normalized() * 1.1
		_floor_ring(pj, Vector3(c.global_position.x, Game.jutsu_floor(c.global_position.x, c.global_position.z), c.global_position.z), 0.9, Color(0.6, 0.05, 0.05, 0.6), 0.5, 1.6)
		c.create_tween().tween_property(c, "global_position", Vector3(to.x, c.global_position.y, to.z), 0.14)
	if tt == null:
		Combat.popup_text(c.global_position + Vector3.UP * 2.4, "Dokunacak kadar yakın değil", Color(0.8, 0.6, 0.6))
		return
	pj.busy(c, 0.9)
	pj._face(c, tt)
	pj.anim(c, "push", 1.2)
	pj.st(tt, "stun", 1.4)
	pj.hit(c, tt.global_position + Vector3.UP, 0.8, pj.inf(c, id, 0.2, {"knock": 0.0, "dir": Vector3.ZERO, "sure": true}))
	var cw = weakref(c)
	var tw = weakref(tt)
	# avuçta kızıl ışıltı + alından gözlere akan damar
	_glint(pj, _head(tt) + _fwd(tt) * 0.15, 0.5, Color(1.0, 0.15, 0.12, 0.9), 0.7)
	_strand(pj, func():
		var y = tw.get_ref()
		return null if y == null else _head(y) + _fwd(y) * 0.12, func():
		var x = cw.get_ref()
		return null if x == null else _head(x) + _fwd(x) * 0.14, VEIN, 1.4, 0.02, 0.03, 9.0)
	# anı kareleri: hedefin başından sana akıp dağılır
	for k in 7:
		pj.after(0.1 + k * 0.14, func():
			var x = cw.get_ref()
			var y = tw.get_ref()
			if x == null or y == null or not is_instance_valid(x) or not is_instance_valid(y):
				return
			var fr = _gi(_quad(), _mat("mem"))
			var p0 = _head(y) + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.35), randf_range(-0.3, 0.3))
			_put(pj, fr, p0)
			fr.set_instance_shader_parameter("sd", randf() * 10.0)
			fr.scale = Vector3(0.32, 0.22, 1.0)
			fr.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
			var tw2 = fr.create_tween().set_parallel(true)
			tw2.tween_property(fr, "global_position", _head(x) + _fwd(x) * 0.2, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw2.tween_property(fr, "scale", Vector3(0.05, 0.035, 1.0), 0.55)
			tw2.tween_property(fr, "rotation:y", fr.rotation.y + PI, 0.55)
			_fade(fr, 0.35, 0.2))
	Sfx.play("genjutsu", tt.global_position, 0.9)
	# öngörü: sıradaki 3 darbe boşa çıkar (Combat mikiri penceresi; oyuncu ve düşman aynı)
	c.set_meta("mikiri_n", 3)
	c.set_meta("mikiri_t", Game.now() + 12.0)
	var jl: Array = tt.arch.get("jutsu", []) if tt is Enemy and tt.get("arch") else []
	var names: Array = []
	for j in jl.slice(0, 3):
		names.append(String(Data.jutsu.get(j, {}).get("name", j)).split(" (")[0])
	pj.after(0.9, func():
		var x = cw.get_ref()
		if x == null or not is_instance_valid(x):
			return
		Combat.popup_text(x.global_position + Vector3.UP * 2.6, "Anılar okundu" + ((": " + ", ".join(names)) if not names.is_empty() else ""), Color(1.0, 0.55, 0.5)))
	# süre boyunca gözlerde ara ara kızıl parıltı
	for k in 8:
		pj.after(1.5 + k * 1.3, func():
			var x = cw.get_ref()
			if x != null and is_instance_valid(x) and int(x.get_meta("mikiri_n", 0)) > 0 and float(x.get_meta("mikiri_t", 0.0)) > Game.now():
				var ff = _fwd(x)
				var ss = ff.cross(Vector3.UP).normalized()
				for s in [-1.0, 1.0]:
					_glint(pj, _head(x) + ff * 0.14 + ss * s * 0.055 + Vector3.UP * 0.02, 0.09, EYE_R, 0.45))


# ================================================================== FŪMA: CHAKURA NO ITO (kinjutsu)
## Kagerō'nun yasak tekniği: iki kalbi kırık mavi chakra ipleriyle bağlar. 15 sn boyunca birine gelen hasar ötekine de işler;
## biri ölürse öteki de ölür (güçlü hedef Combat.cap_one_shot ile direnir). Kalpler aynı anda atar: göğüslerde mavi atış halkası
static func chakura_no_ito(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var id = "chakura_no_ito"
	var tt = pj.tg(c, t, 12.0)
	if tt == null:
		return
	if tt.has_meta("ito_link_until") and float(tt.get_meta("ito_link_until")) > Game.now():
		return
	pj.busy(c, 0.8)
	pj._face(c, tt)
	pj.anim(c, "push", 1.3)
	var dur = 15.0
	tt.set_meta("ito_link_until", Game.now() + dur)
	c.set_meta("ito_link_until", Game.now() + dur)
	var cw = weakref(c)
	var tw = weakref(tt)
	Sfx.play("seal", c.global_position, 1.3)
	# ipler: ana bağ + iki ince yan iplik, kırık kırık titrer
	for k in 3:
		var o = Vector3(0, (k - 1) * 0.08, 0)
		_strand(pj, func():
			var x = cw.get_ref()
			return null if x == null else _chest(x) + o, func():
			var y = tw.get_ref()
			return null if y == null else _chest(y) - o, ITO if k == 1 else Color(0.5, 0.75, 1.0, 0.7), dur, 0.03 if k == 1 else 0.016, 0.16, 10.0 + k * 3.0)
	_wrap(pj, c, ITO, dur, 10)
	_wrap(pj, tt, ITO, dur, 14)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Kalpler bağlandı!", Color(0.55, 0.75, 1.0))
	var last := [float(c.hp), float(tt.hp)]
	var beat := [0.0]
	pj.every(dur, 0.1, func(_i, _k):
		var x = cw.get_ref()
		var y = tw.get_ref()
		if x == null or y == null or not is_instance_valid(x) or not is_instance_valid(y):
			return
		var xd = x.is_dead()
		var yd = y.is_dead()
		if xd != yd:
			# biri öldü: öteki de (kanon); güçlü hedef direnir
			var v = y if xd else x
			var killer = x if xd else y
			if not v.is_dead():
				v.take_hit({"dmg": float(v.max_hp) * 3.0, "attacker": killer, "execute": true, "sure": true, "knock": 0.0, "kind": "light", "hitstop": 0.0, "jutsu": id})
				_glint(pj, _chest(v), 1.4, ITO, 0.6, true, 2.0)
			x.set_meta("ito_link_until", 0.0)
			y.set_meta("ito_link_until", 0.0)
			return
		if xd or float(y.get_meta("ito_link_until", 0.0)) < Game.now():
			return
		var dx = last[0] - float(x.hp)
		var dy = last[1] - float(y.hp)
		if dx > 0.5:
			y.take_hit({"dmg": dx, "attacker": x, "sure": true, "knock": 0.0, "kind": "light", "hitstop": 0.0, "jutsu": id})
		if dy > 0.5:
			x.take_hit({"dmg": dy, "attacker": y, "sure": true, "knock": 0.0, "kind": "light", "hitstop": 0.0, "jutsu": id})
		last[0] = float(x.hp)
		last[1] = float(y.hp)
		# ortak kalp atışı
		beat[0] -= 0.1
		if beat[0] <= 0.0 or dx > 0.5 or dy > 0.5:
			beat[0] = 0.85
			for z in [x, y]:
				_glint(pj, _chest(z), 0.5, Color(0.45, 0.7, 1.0, 0.85), 0.35, true, 1.8)
				_glint(pj, _chest(z), 0.25, Color(0.6, 0.85, 1.0, 0.9), 0.25))
