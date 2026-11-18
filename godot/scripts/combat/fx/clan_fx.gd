class_name ClanFX
extends RefCounted
## Klan / taijutsu teknikleri (Hyūga, Hatake, Mitarashi, Namikaze, Gekkō, Gai) — her tekniğin kendi görünüşü.
## Ortak efekt kütüphanesi kullanılmaz: şerit, parçacık, halka, zemin çatlağı, yılan, kunai, kaplan hepsi bu dosyada üretilir.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil) eski işleyicilerden satır satır taşındı.

const DUST := Color(0.62, 0.52, 0.4)
const DIRT := Color(0.2, 0.15, 0.11)
const HYUGA := Color(0.62, 0.8, 1.0)
const HAKKO := Color(0.93, 0.97, 1.0)
const SNAKE_A := Color(0.66, 0.6, 0.4)      # ref (Jarangeki): açık kahve pullu gövde
const SNAKE_B := Color(0.45, 0.4, 0.26)     # pul halkaları
const SNAKE_BELLY := Color(0.93, 0.91, 0.82)
const VENOM := Color(0.55, 0.22, 0.68)
const FLASH_Y := Color(1.0, 0.86, 0.3)
const MOON := Color(0.82, 0.88, 1.0)
const GATE := Color(0.45, 1.0, 0.45)
const LEAF_G := Color(0.45, 0.75, 0.3)

static var _shaders := {}
static var _soft: Texture2D = null
static var _leaf_tex: Texture2D = null
static var _annuli := {}
static var _cres: ArrayMesh = null


# ================================================================== shader kodları (kendi)
## İz şeridi: ortada düz açık çekirdek, kenarda renkli kuşak (cel iki ton), uçta yumuşak sönme
const TRAIL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 core_col : source_color = vec4(1.0);
uniform vec4 rim_col : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float core_w = 0.32;
uniform float fade = 1.0;
void fragment() {
	float v = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - step(core_w, v);
	float a = 1.0 - smoothstep(0.72, 1.0, v);
	ALBEDO = mix(rim_col.rgb, core_col.rgb, core);
	ALPHA = clamp(COLOR.a * a * fade * mix(rim_col.a, core_col.a, core), 0.0, 1.0);
}
"""

## Sıkışmış hava / chakra kütlesi: dönen bulut lekeleri, iki düz ton + açık kenar çizgisi (anime cel)
const AIR_SH := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 0.8);
uniform vec4 shade : source_color = vec4(0.45, 0.65, 0.95, 1.0);
uniform vec4 edge_col : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float swirl = 5.0;
uniform float flow = 4.0;
uniform float fade = 1.0;
uniform float form = 0.0;
varying vec3 opos;
void vertex() {
	opos = VERTEX;
}
void fragment() {
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ang = atan(opos.z, opos.x);
	float h = opos.y * 4.0;
	float n1 = sin(ang * swirl + h * 1.3 - TIME * flow);
	float n2 = sin(ang * swirl * 2.0 - h * 2.1 + TIME * flow * 1.6 + n1 * 1.5);
	float n = n1 * 0.6 + n2 * 0.4;
	vec3 c = mix(shade.rgb, tint.rgb, smoothstep(-0.25, 0.25, n));
	float wisp = step(0.82, n2 * 0.5 + 0.5 + n1 * 0.15);
	c = mix(c, vec3(1.0), wisp * 0.7);
	float lit = dot(NORMAL, normalize(vec3(0.35, 0.75, 0.55)));
	c = mix(c, c * shade.rgb * 0.85, form * (1.0 - step(0.05, lit)));
	float e = step(0.74, fr);
	c = mix(c, edge_col.rgb, e * (1.0 - form));
	ALBEDO = c * COLOR.rgb;
	ALPHA = clamp(tint.a * fade * (0.7 + 0.3 * fr), 0.0, 1.0);
}
"""

## Düz halka (şok dalgası / zemin izi): UV.y iç→dış, istenirse rüzgâr gibi kırık
const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 col_in : source_color = vec4(1.0);
uniform vec4 col_out : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float breakup = 0.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
void fragment() {
	float v = UV.y;
	float a = smoothstep(0.0, 0.3, v) * (1.0 - smoothstep(0.8, 1.0, v));
	float gaps = step(0.35, fract(UV.x * 18.0 + sin(UV.x * 37.0 + seed) * 0.4 + v * 0.6));
	a *= mix(1.0, gaps, breakup);
	ALBEDO = mix(col_in.rgb, col_out.rgb, step(0.55, v));
	ALPHA = clamp(a * fade * mix(col_in.a, col_out.a, v), 0.0, 1.0);
}
"""

## Işıkla gölgelenen cel yüzey (yılan, kunai, kılıç): köşe rengi + koyu kenar çizgisi
const CEL_SH := """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float emit = 0.0;
void fragment() {
	vec3 nn = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = nn;
	float fr = 1.0 - clamp(dot(nn, VIEW), 0.0, 1.0);
	vec3 c = COLOR.rgb * tint.rgb;
	c = mix(c, c * 0.3, step(0.8, fr));
	ALBEDO = c;
	EMISSION = c * emit;
	ROUGHNESS = 0.9;
}
"""

## Koyu dış çizgi (ters kabuk): normal boyunca şişirilmiş arka yüzler — kütle gündüz ışığında okunur
const HULL_SH := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix;
uniform vec4 line_col : source_color = vec4(0.12, 0.18, 0.35, 1.0);
uniform float width = 0.04;
uniform float fade = 1.0;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = line_col.rgb;
	ALPHA = clamp(line_col.a * fade, 0.0, 1.0);
}
"""


# ================================================================== temel yapı taşları
static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _root() -> Node:
	return _tree().current_scene


static func _put(n: Node3D, pos: Vector3) -> Node3D:
	_root().add_child(n)
	n.global_position = pos
	return n


static func _kill_later(n: Node, sec: float) -> void:
	var w = weakref(n)
	_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.queue_free())


static func _cam() -> Vector3:
	var cam = _tree().root.get_camera_3d()
	return cam.global_position if cam else Vector3(0, 60, 0)


static func _gy(x: float, z: float) -> float:
	return Game.jutsu_floor(x, z) + 0.045


static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _gy(p.x, p.z), p.z)


static func _shader(key: String) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var s = Shader.new()
	match key:
		"trail":
			s.code = TRAIL_SH
		"trail_add":
			s.code = TRAIL_SH.replace("blend_mix", "blend_add")
		"air":
			s.code = AIR_SH
		"ring":
			s.code = RING_SH
		"ring_add":
			s.code = RING_SH.replace("blend_mix", "blend_add")
		"cel":
			s.code = CEL_SH
		"hull":
			s.code = HULL_SH
	_shaders[key] = s
	return s


static func _trail(core: Color, rim: Color, core_w := 0.32, add := false) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader("trail_add" if add else "trail")
	m.set_shader_parameter("core_col", core)
	m.set_shader_parameter("rim_col", rim)
	m.set_shader_parameter("core_w", core_w)
	return m


static func _air(tint: Color, shade: Color, edge: Color, swirl := 5.0, flow := 4.0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader("air")
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("edge_col", edge)
	m.set_shader_parameter("swirl", swirl)
	m.set_shader_parameter("flow", flow)
	return m


static func _ringm(cin: Color, cout: Color, breakup := 0.0, add := false) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader("ring_add" if add else "ring")
	m.set_shader_parameter("col_in", cin)
	m.set_shader_parameter("col_out", cout)
	m.set_shader_parameter("breakup", breakup)
	m.set_shader_parameter("seed", randf() * 10.0)
	return m


## Verilen mesh'in koyu dış çizgisi (aynı dönüşümde çocuk olarak eklenir); fade parametresi malzemede
static func _hull(mesh: Mesh, col: Color, width: float) -> MeshInstance3D:
	var m = ShaderMaterial.new()
	m.shader = _shader("hull")
	m.set_shader_parameter("line_col", col)
	m.set_shader_parameter("width", width)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _cel(emit := 0.0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = _shader("cel")
	m.set_shader_parameter("emit", emit)
	return m


static func _flat(col: Color, add := false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	return m


static func _soft_tex() -> Texture2D:
	if _soft == null:
		var g = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func _leaf() -> Texture2D:
	if _leaf_tex == null:
		var g = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 0.72])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.8, 0.9, 0.75, 1), Color(1, 1, 1, 0)])
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_SQUARE
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_leaf_tex = t
	return _leaf_tex


static func _grad(cols: Array) -> Gradient:
	var g = Gradient.new()
	var offs = PackedFloat32Array()
	var cs = PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


## Kendi parçacık bulutum (toz, chakra zerresi, zehir damlası, yaprak): billboard yumuşak lekeler
static func _puffs(pos: Vector3, o: Dictionary) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = int(o.get("n", 16))
	p.lifetime = float(o.get("life", 0.8))
	p.one_shot = not o.get("loop", false)
	p.explosiveness = float(o.get("expl", 0.92))
	p.randomness = 0.5
	p.lifetime_randomness = float(o.get("lrand", 0.35))
	p.local_coords = false
	var qm = QuadMesh.new()
	var sz = o.get("size", 0.6)
	qm.size = sz if sz is Vector2 else Vector2(float(sz), float(sz))
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if o.get("add", false) else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _leaf() if o.get("leaf", false) else _soft_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = m
	p.mesh = qm
	if o.has("pts"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		p.emission_points = o["pts"]
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(o.get("r", 0.3))
	p.direction = o.get("dir", Vector3.UP)
	p.spread = float(o.get("spread", 60.0))
	p.flatness = float(o.get("flat", 0.0))
	p.initial_velocity_min = float(o.get("vmin", 1.0))
	p.initial_velocity_max = float(o.get("vmax", 3.0))
	p.gravity = o.get("grav", Vector3(0, 0.4, 0))
	p.damping_min = float(o.get("damp", 2.0))
	p.damping_max = float(o.get("damp", 2.0)) * 1.5
	p.radial_accel_min = float(o.get("radial", 0.0))
	p.radial_accel_max = float(o.get("radial", 0.0)) * 1.2
	p.tangential_accel_min = float(o.get("tan", 0.0))
	p.tangential_accel_max = float(o.get("tan", 0.0)) * 1.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -float(o.get("spin", 0.0))
	p.angular_velocity_max = float(o.get("spin", 0.0))
	p.scale_amount_min = float(o.get("smin", 0.6))
	p.scale_amount_max = float(o.get("smax", 1.2))
	var cv = Curve.new()
	cv.max_value = 3.0
	cv.add_point(Vector2(0.0, float(o.get("s0", 0.4))))
	cv.add_point(Vector2(0.35, 1.0))
	cv.add_point(Vector2(1.0, float(o.get("s1", 0.8))))
	p.scale_amount_curve = cv
	p.color_ramp = _grad(o.get("cols", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = o.get("parent", null)
	if parent != null and is_instance_valid(parent):
		parent.add_child(p)
		p.position = o.get("local", Vector3.ZERO)
	else:
		_put(p, pos)
	p.emitting = true
	if not o.get("loop", false):
		_kill_later(p, p.lifetime * 1.5 + 0.3)
	return p


## Fırlayan toprak / kaya parçaları (kutu, cel), yerçekimiyle düşer
static func _chunks(pos: Vector3, n: int, col: Color, spd: float, sz := 0.22, dir := Vector3.UP, spread := 55.0) -> void:
	var p = CPUParticles3D.new()
	p.amount = maxi(1, n)
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime_randomness = 0.3
	p.local_coords = false
	var bm = BoxMesh.new()
	bm.size = Vector3.ONE * sz
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = false
	bm.material = m
	p.mesh = bm
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = spd * 0.5
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -20, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	var cv = Curve.new()
	cv.add_point(Vector2(0.0, 1.0))
	cv.add_point(Vector2(0.75, 1.0))
	cv.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = cv
	_put(p, pos)
	p.emitting = true
	_kill_later(p, 1.6)


static func _ring_pts(r: float, n: int, y := 0.0) -> PackedVector3Array:
	var a = PackedVector3Array()
	for i in n:
		var an = TAU * float(i) / n
		a.append(Vector3(cos(an) * r, y, sin(an) * r))
	return a


static func _line_pts(a: Vector3, b: Vector3, n: int, rel: Vector3) -> PackedVector3Array:
	var out = PackedVector3Array()
	for i in n:
		out.append(a.lerp(b, float(i) / maxf(1.0, n - 1)) - rel)
	return out


## Kendi iz şeridim: path_fn(q) yolu çizer; baş ilerler (grow), kuyruk izler, sonra uçtan yenilerek söner.
## o: n (dilim), tail (kuyruk uzunluğu 0..1), taper (kuyruk incelmesi), wfn(q, p) genişlik yönü (yoksa kameraya dönük), eat
static func _ribbon(path_fn: Callable, w: float, mat: Material, grow: float, hold: float, fade: float, o := {}) -> MeshInstance3D:
	var n: int = int(o.get("n", 20))
	var tail: float = float(o.get("tail", 1.0))
	var taper: float = float(o.get("taper", 0.8))
	var eat: float = float(o.get("eat", 0.7))
	var wfn: Callable = o.get("wfn", Callable())
	var cam = _cam()
	var mi = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	mi.mesh = im
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	var draw = func(head: float, tl: float, a: float) -> void:
		im.clear_surfaces()
		if head - tl < 0.004 or a <= 0.004:
			return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n + 1:
			var u = float(i) / n
			var q = lerpf(tl, head, u)
			var p: Vector3 = path_fn.call(q)
			var pa: Vector3 = path_fn.call(maxf(0.0, q - 0.01))
			var pb: Vector3 = path_fn.call(minf(1.0, q + 0.01))
			var tg = pb - pa
			if tg.length() < 0.00001:
				tg = Vector3.FORWARD
			var wd: Vector3
			if wfn.is_valid():
				wd = wfn.call(q, p)
			else:
				wd = tg.cross(cam - p).normalized()
			var ww = w * lerpf(1.0, u, taper) * clampf((1.0 - u) * 10.0 + 0.3, 0.0, 1.0)
			var al = a * lerpf(0.2, 1.0, u)
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(p - wd * ww * 0.5)
			im.surface_set_color(Color(1, 1, 1, al))
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(p + wd * ww * 0.5)
		im.surface_end()
	var tw = mi.create_tween()
	tw.tween_method(func(k: float): draw.call(k, maxf(0.0, k - tail), 1.0), 0.0, 1.0, maxf(grow, 0.01))
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(func(k: float): draw.call(1.0, lerpf(maxf(0.0, 1.0 - tail), 1.0, k * eat), 1.0 - k), 0.0, 1.0, maxf(fade, 0.01))
	tw.tween_callback(mi.queue_free)
	return mi


## Düz çizgi izi (kameraya dönük)
static func _streak(a: Vector3, b: Vector3, w: float, mat: Material, grow: float, hold: float, fade: float, o := {}) -> MeshInstance3D:
	return _ribbon(func(q: float) -> Vector3: return a.lerp(b, q), w, mat, grow, hold, fade, o)


## Kılıç / tekme yayı: cen etrafında f (ileri) ile sv (yan, roll kadar eğik) düzleminde a0→a1 süpürülen hilal şerit
static func _slash(cen: Vector3, f: Vector3, side: Vector3, roll: float, r: float, a0: float, a1: float, w: float, mat: Material, grow: float, hold: float, fade: float, o := {}) -> MeshInstance3D:
	var sv: Vector3 = side * cos(roll) + Vector3.UP * sin(roll)
	var oo = o.duplicate()
	oo["wfn"] = func(q: float, _p: Vector3) -> Vector3:
		var a = lerpf(a0, a1, q)
		return f * cos(a) + sv * sin(a)
	var path = func(q: float) -> Vector3:
		var a = lerpf(a0, a1, q)
		return cen + (f * cos(a) + sv * sin(a)) * r
	return _ribbon(path, w, mat, grow, hold, fade, oo)


static func _annulus(inner: float, seg := 48) -> ArrayMesh:
	var key = "%0.2f_%d" % [inner, seg]
	if _annuli.has(key):
		return _annuli[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 = TAU * float(i) / seg
		var a1 = TAU * float(i + 1) / seg
		var u0 = float(i) / seg
		var u1 = float(i + 1) / seg
		var p = [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
		var uv = [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_uv(uv[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(p[k])
	var m = st.commit()
	_annuli[key] = m
	return m


static func _orient(mi: Node3D, nrm: Vector3) -> void:
	var n = nrm.normalized()
	var ref = Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x = n.cross(ref).normalized()
	var z = x.cross(n).normalized()
	mi.global_basis = Basis(x, n, z)


## Genişleyen düz halka (şok dalgası); normal yönünde düzlem
static func _ring(pos: Vector3, nrm: Vector3, r0: float, r1: float, inner: float, mat: ShaderMaterial, dur: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _annulus(inner)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(mi, pos)
	_orient(mi, nrm)
	mi.scale = Vector3.ONE * maxf(r0, 0.01)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * r1, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(f: float): mat.set_shader_parameter("fade", f), 1.0, 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Yerde kalan sabit halka izi (krater kenarı vb.): hold kadar durur, fade'de söner
static func _mark(pos: Vector3, r: float, inner: float, mat: ShaderMaterial, hold: float, fade: float) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _annulus(inner, 40)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(mi, pos)
	mi.scale = Vector3.ONE * r
	var tw = mi.create_tween()
	tw.tween_interval(hold)
	tw.tween_method(func(f: float): mat.set_shader_parameter("fade", f), 1.0, 0.0, fade)
	tw.tween_callback(mi.queue_free)


static func _quad(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for p in [a, b, c, a, c, d]:
		im.surface_set_normal(Vector3.UP)
		im.surface_set_color(col)
		im.surface_add_vertex(p)


static func _fade_mat_free(mi: MeshInstance3D, mat: StandardMaterial3D, hold: float, fade: float) -> void:
	var c0: Color = mat.albedo_color
	var tw = mi.create_tween()
	tw.tween_interval(hold)
	tw.tween_method(func(a: float): mat.albedo_color = Color(c0.r, c0.g, c0.b, c0.a * a), 1.0, 0.0, fade)
	tw.tween_callback(mi.queue_free)


static func _crack_branch(im: ImmediateMesh, p: Vector3, dir: Vector3, L: float, w: float, depth: int, col: Color) -> void:
	var steps = 6
	var seg = L / steps
	var cur = p
	var d = dir
	for i in steps:
		d = d.rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()
		var nx = cur + d * seg * randf_range(0.75, 1.2)
		var w0 = w * (1.0 - float(i) / steps)
		var w1 = w * (1.0 - float(i + 1) / steps)
		var sd = Vector3(-d.z, 0, d.x)
		var a0 = _ground(cur)
		var a1 = _ground(nx)
		_quad(im, a0 - sd * w0, a0 + sd * w0, a1 + sd * w1, a1 - sd * w1, col)
		if depth > 0 and (i == 2 or i == 4) and randf() < 0.75:
			var turn = randf_range(0.6, 1.1) * (1.0 if randf() < 0.5 else -1.0)
			_crack_branch(im, nx, d.rotated(Vector3.UP, turn), L * 0.4, w0 * 0.65, depth - 1, col)
		cur = nx


## Zemin çatlakları: merkezden dallanan koyu yarıklar (zemin yüksekliğini izler), yavaş söner
static func _cracks(cen: Vector3, r: float, n: int, life: float, col := DIRT, bias := Vector3.ZERO) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	var mat = _flat(Color(1, 1, 1, 0.92))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in n:
		var a = TAU * (float(b) + randf_range(-0.3, 0.3)) / n
		var dir = Vector3(cos(a), 0, sin(a))
		var L = r * randf_range(0.65, 1.1)
		if bias != Vector3.ZERO:
			var bb = Vector3(bias.x, 0, bias.z).normalized()
			L *= 1.0 + maxf(0.0, dir.dot(bb)) * 0.8
		_crack_branch(im, cen + dir * r * 0.1, dir, L, 0.13 * clampf(r / 3.0, 0.6, 1.6), 2, col)
	im.surface_end()
	_fade_mat_free(mi, mat, life * 0.7, life * 0.3)


## Yerde kazınmış oluk: açık kahve kenarlar + koyu iç (a→b), uzun süre kalır
static func _gouge(a: Vector3, b: Vector3, w: float, life: float, rim := Color(0.58, 0.47, 0.34), core := Color(0.24, 0.18, 0.13)) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	var mat = _flat(Color(1, 1, 1, 0.9))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root().add_child(mi)
	var d = Vector3(b.x - a.x, 0, b.z - a.z)
	var L = d.length()
	if L < 0.1:
		mi.queue_free()
		return
	d /= L
	var sd = Vector3(-d.z, 0, d.x)
	var n = maxi(2, int(L / 0.45))
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pass_i in 2:
		var ww = w * (0.72 if pass_i == 0 else 0.34)
		var col = rim if pass_i == 0 else core
		for i in n:
			var u0 = float(i) / n
			var u1 = float(i + 1) / n
			var p0 = a.lerp(b, u0)
			var p1 = a.lerp(b, u1)
			var e0 = ww * sin(clampf(u0 * 1.4 + 0.05, 0.0, 1.0) * PI * 0.5) * (1.0 + randf_range(-0.15, 0.15))
			var e1 = ww * sin(clampf(u1 * 1.4 + 0.05, 0.0, 1.0) * PI * 0.5) * (1.0 + randf_range(-0.15, 0.15))
			var lift = 0.012 * pass_i
			var q0a = _ground(p0 - sd * e0) + Vector3.UP * lift
			var q0b = _ground(p0 + sd * e0) + Vector3.UP * lift
			var q1a = _ground(p1 - sd * e1) + Vector3.UP * lift
			var q1b = _ground(p1 + sd * e1) + Vector3.UP * lift
			_quad(im, q0a, q0b, q1b, q1a, col)
	im.surface_end()
	_fade_mat_free(mi, mat, life * 0.75, life * 0.25)


static func _light(pos: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	_put(l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## Kameraya dönük ışın yıldızı (vuruş parıltısı): ince uzun ışınlar, ortası ak
static func _glint(pos: Vector3, col: Color, size: float, dur: float, rays := 4, add := true) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _flat(Color(1, 1, 1, 1), add)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(mi, pos)
	var to_cam = (_cam() - pos).normalized()
	var ax = to_cam.cross(Vector3.UP)
	if ax.length() < 0.1:
		ax = Vector3.RIGHT
	ax = ax.normalized()
	var ay = ax.cross(to_cam).normalized()
	var off = to_cam * 0.3
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rot0 = randf() * 0.4 + PI * 0.5
	for k in rays:
		var a = rot0 + TAU * float(k) / rays
		var dv = ax * cos(a) + ay * sin(a)
		var sv = ax * cos(a + PI * 0.5) + ay * sin(a + PI * 0.5)
		var L = size * (1.0 if k % 2 == 0 else randf_range(0.45, 0.7))
		var wv = size * 0.06
		for v in [[off + sv * wv, Color(1, 1, 1, 1)], [off - sv * wv, Color(1, 1, 1, 1)], [off + dv * L, Color(col.r, col.g, col.b, 0.0)]]:
			im.surface_set_color(v[1])
			im.surface_add_vertex(v[0])
	# ak çekirdek
	for k in 8:
		var a0 = TAU * k / 8.0
		var a1 = TAU * (k + 1) / 8.0
		var cr = size * 0.12
		for v in [off, off + (ax * cos(a0) + ay * sin(a0)) * cr, off + (ax * cos(a1) + ay * sin(a1)) * cr]:
			im.surface_set_color(Color(1, 1, 1, 0.95))
			im.surface_add_vertex(v)
	im.surface_end()
	mi.scale = Vector3.ONE * 0.25
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, dur * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(0.02, 0.02, 0.02), dur * 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## İçe çekilen chakra / hava: küre yüzeyinden merkeze akan zerreler + birkaç akış çizgisi
static func _gather(pos: Vector3, col: Color, r: float, dur: float, lines := 8, add := true) -> void:
	_puffs(pos, {"n": 26, "life": dur, "expl": 0.0, "r": r, "vmin": 0.0, "vmax": 0.2, "grav": Vector3.ZERO, "damp": 0.0,
		"radial": -2.2 * r / (dur * dur), "size": 0.14, "s0": 1.0, "s1": 0.3, "add": add,
		"cols": [Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.9), Color(1, 1, 1, 0.9)]})
	var m = _trail(Color(1, 1, 1, 0.9), Color(col.r, col.g, col.b, 0.7), 0.3, add)
	for k in lines:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var a = pos + dv * r * randf_range(0.9, 1.3)
		var bend = dv.cross(Vector3.UP).normalized() * r * 0.3
		_ribbon(func(q: float) -> Vector3: return a.lerp(pos, q) + bend * sin(q * PI), 0.06, m, dur * 0.8, 0.0, dur * 0.25, {"tail": 0.45, "taper": 0.9, "n": 10})


## Kemiğe iliştirilmiş avuç ışığı (titreyen çekirdek + yükselen zerreler)
static func _hand_aura(pj: PathJutsu, c: Node3D, bone: String, col: Color, dur: float, r := 0.14, rate := 30) -> void:
	var ba = pj.bone_attach(c, bone)
	if ba == null:
		return
	for layer in 2:
		var sp = MeshInstance3D.new()
		var sm = SphereMesh.new()
		var rr = r * (1.0 if layer == 0 else 1.7)
		sm.radius = rr
		sm.height = rr * 2.0
		sm.radial_segments = 12
		sm.rings = 6
		sp.mesh = sm
		sp.material_override = _flat(Color(1, 1, 1, 0.75) if layer == 0 else Color(col.r, col.g, col.b, 0.35), true)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(sp)
		var tw = Game.safe_loops(sp.create_tween())
		tw.tween_property(sp, "scale", Vector3.ONE * (1.25 if layer == 0 else 1.1), 0.05 + layer * 0.03)
		tw.tween_property(sp, "scale", Vector3.ONE * 0.85, 0.05 + layer * 0.03)
	_puffs(Vector3.ZERO, {"parent": ba, "loop": true, "n": rate, "life": 0.45, "expl": 0.0, "r": r, "vmin": 0.5, "vmax": 1.6,
		"grav": Vector3(0, 2.5, 0), "damp": 1.0, "size": 0.12, "s0": 1.0, "s1": 0.2, "add": true,
		"cols": [Color(1, 1, 1, 0.9), Color(col.r, col.g, col.b, 0.8), Color(col.r, col.g, col.b, 0.0)]})
	pj.free_after(dur, ba)


## Byakugan: yalnız göz + damar (eski işleyicideki göz bölümü)
static func _byakugan(pj: PathJutsu, c: Node3D, dur: float) -> void:
	if c.get("model") and c.model.has_method("set_dojutsu_eyes"):
		c.model.set_dojutsu_eyes(2, 1, 2, 1, true)
		pj.after(dur, func():
			if is_instance_valid(c) and c.get("model"):
				if c is Player and c.combat and c.combat.modes and c.combat.modes.eyes:
					c.combat.modes.eyes.refresh_visual()
				else:
					c.model.set_dojutsu_eyes(0, 0, 0, 0, false))


## Zehir: eski poison() ile aynı vuruş + kendi görünüşü (mor damlalar, yeşilimsi buğu)
static func _poison(pj: PathJutsu, c: Node3D, e: Node3D, id: String, mul: float, dur := 4.0) -> void:
	var at = e.global_position + Vector3.UP * e.height * 0.6
	pj.hit(c, at, e.radius + 0.6, pj.inf(c, id, mul, {"knock": 1.0, "kind": "light", "burn": dur, "hitstop": 0.03}))
	_venom(at, 1.0)


static func _venom(at: Vector3, s: float) -> void:
	_puffs(at, {"n": int(14 * s), "life": 0.7, "r": 0.25, "vmin": 2.0, "vmax": 4.5, "spread": 80.0, "grav": Vector3(0, -9.0, 0), "damp": 0.5,
		"size": 0.1, "s0": 1.0, "s1": 0.6, "cols": [Color(0.75, 0.4, 0.95, 1), VENOM, Color(0.3, 0.1, 0.4, 0)]})
	_puffs(at, {"n": int(8 * s), "life": 1.1, "r": 0.35, "vmin": 0.2, "vmax": 0.8, "grav": Vector3(0, 0.3, 0),
		"size": 0.7 * s, "s0": 0.5, "s1": 1.3, "cols": [Color(0.5, 0.65, 0.35, 0.45), Color(0.45, 0.3, 0.55, 0.3), Color(0.3, 0.2, 0.35, 0)]})


# ================================================================== modeller (kendi)
static func _snake_head(s: float) -> MeshInstance3D:
	var b = MB.new()
	b.add("sphere", Vector3(0, 0, 0.05) * s, Vector3(0.48, 0.42, 0.55) * s, SNAKE_A)
	b.add("sphere", Vector3(0, 0.04, -0.32) * s, Vector3(0.62, 0.36, 0.9) * s, SNAKE_A)
	b.add("sphere", Vector3(0, 0.03, -0.72) * s, Vector3(0.44, 0.22, 0.5) * s, SNAKE_B)
	b.add("sphere", Vector3(0, -0.17, -0.58) * s, Vector3(0.4, 0.12, 0.72) * s, SNAKE_BELLY, Vector3(-16, 0, 0))
	b.add("sphere", Vector3(0, -0.07, -0.6) * s, Vector3(0.34, 0.08, 0.62) * s, Color(0.72, 0.18, 0.22))
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.1 * sx, -0.1, -0.88) * s, Vector3(0.05, 0.16, 0.05) * s, Color(0.97, 0.96, 0.9), Vector3(180, 0, 0), 6)
		b.add("sphere", Vector3(0.19 * sx, 0.13, -0.52) * s, Vector3(0.13, 0.12, 0.13) * s, Color(1.0, 0.85, 0.1))
		b.add("sphere", Vector3(0.245 * sx, 0.13, -0.53) * s, Vector3(0.03, 0.1, 0.05) * s, Color(0.05, 0.04, 0.03))
		b.add("sphere", Vector3(0.16 * sx, 0.18, -0.36) * s, Vector3(0.12, 0.05, 0.24) * s, SNAKE_B)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(null)
	mi.material_override = _cel(0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Hiraishin kunaisi: üç çatallı bıçak, sargılı sap, halka, mühür kâğıdı (ucu -Z)
static func _kunai3() -> MeshInstance3D:
	var b = MB.new()
	var steel = Color(0.62, 0.64, 0.7)
	b.add("cone", Vector3(0, 0, -0.2), Vector3(0.08, 0.3, 0.025), steel, Vector3(-90, 0, 0), 4)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.07 * sx, 0, -0.08), Vector3(0.045, 0.17, 0.018), steel, Vector3(-90, 0, 0), 4)
	b.add("box", Vector3(0, 0, -0.04), Vector3(0.18, 0.025, 0.04), steel)
	b.add("cyl", Vector3(0, 0, 0.07), Vector3(0.028, 0.18, 0.028), Color(0.12, 0.1, 0.1), Vector3(90, 0, 0), 6)
	b.add("torus", Vector3(0, 0, 0.19), Vector3(0.07, 0.07, 0.07), steel, Vector3(90, 0, 0), 10)
	b.add("box", Vector3(0, -0.025, 0.08), Vector3(0.045, 0.006, 0.13), Color(0.96, 0.93, 0.78))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(null)
	mi.material_override = _cel(0.15)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Hasangeki avucu: parmaklar +Y, avuç içi -Z (ileri) — dev chakra eli
static func _palm_node(mat: Material) -> MeshInstance3D:
	var b = MB.new()
	var w = Color.WHITE
	b.add("sphere", Vector3(0, 0, 0), Vector3(1.0, 1.05, 0.3), w, Vector3.ZERO, 16)
	var fx = [-0.36, -0.12, 0.12, 0.36]
	var fl = [0.5, 0.66, 0.62, 0.46]
	for i in 4:
		var L = fl[i]
		b.add("cyl", Vector3(fx[i], 0.48 + L * 0.5, 0), Vector3(0.2, L, 0.18), w, Vector3(0, 0, -fx[i] * 12.0), 10)
		b.add("sphere", Vector3(fx[i] - fx[i] * 0.12, 0.48 + L, 0), Vector3(0.2, 0.22, 0.18), w, Vector3.ZERO, 10)
	b.add("cyl", Vector3(0.6, 0.05, -0.04), Vector3(0.24, 0.55, 0.2), w, Vector3(0, 0, -52), 10)
	b.add("sphere", Vector3(0.82, 0.24, -0.04), Vector3(0.24, 0.24, 0.2), w, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, -0.85, 0.15), Vector3(0.95, 0.9, 0.3), w, Vector3(180, 0, 0), 14)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(null)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Birim hilal (XY düzleminde, +X'e bombeli, uçlar ±Y), UV.y dış→iç
static func _crescent_mesh() -> ArrayMesh:
	if _cres != null:
		return _cres
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg = 28
	var pts_o = []
	var pts_i = []
	for i in seg + 1:
		var a = lerpf(-PI * 0.5, PI * 0.5, float(i) / seg)
		pts_o.append(Vector3(cos(a), sin(a), 0))
		pts_i.append(Vector3(cos(a) * 0.42, sin(a), 0))
	for i in seg:
		var u0 = float(i) / seg
		var u1 = float(i + 1) / seg
		var q = [[pts_o[i], Vector2(u0, 0)], [pts_i[i], Vector2(u0, 1)], [pts_i[i + 1], Vector2(u1, 1)], [pts_o[i + 1], Vector2(u1, 0)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_uv(q[k][1])
			st.set_normal(Vector3.BACK)
			st.add_vertex(q[k][0])
	_cres = st.commit()
	return _cres


## Ay hilali: pos'ta, bombesi 'bulge' yönüne bakan, normal 'nrm' olan düzlemde; görünüp yavaş söner
static func _crescent(pos: Vector3, bulge: Vector3, nrm: Vector3, r: float, mat: ShaderMaterial, fin: float, hold: float, fade: float, drift := Vector3.ZERO) -> void:
	var mi = MeshInstance3D.new()
	mi.mesh = _crescent_mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(mi, pos)
	var x = bulge.normalized()
	var z = nrm.normalized()
	var y = z.cross(x).normalized()
	x = y.cross(z).normalized()
	mi.global_basis = Basis(x, y, z)
	mi.scale = Vector3.ONE * r * 0.6
	mat.set_shader_parameter("fade", 0.0)
	var tw = mi.create_tween()
	tw.tween_method(func(f: float): mat.set_shader_parameter("fade", f), 0.0, 1.0, maxf(fin, 0.01))
	tw.parallel().tween_property(mi, "scale", Vector3.ONE * r, maxf(fin, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(func(f: float): mat.set_shader_parameter("fade", f), 1.0, 0.0, fade)
	tw.parallel().tween_property(mi, "global_position", pos + drift, fade)
	tw.tween_callback(mi.queue_free)


## Kendi kılıcım (Gekkō): bilek kemiğinden +Z boyunca çelik ağız + ay ışığı kılıfı
static func _moon_blade(pj: PathJutsu, c: Node3D, dur: float, len_: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var b = MB.new()
	b.add("box", Vector3(0, 0, len_ * 0.55), Vector3(0.022, 0.07, len_), Color(0.78, 0.8, 0.86))
	b.add("cone", Vector3(0, 0, len_ * 1.08), Vector3(0.022, 0.12, 0.07), Color(0.78, 0.8, 0.86), Vector3(90, 0, 0), 4)
	b.add("cyl", Vector3(0, 0, 0.02), Vector3(0.11, 0.02, 0.11), Color(0.2, 0.18, 0.15), Vector3(90, 0, 0), 10)
	b.add("cyl", Vector3(0, 0, -0.1), Vector3(0.035, 0.22, 0.035), Color(0.12, 0.12, 0.2), Vector3(90, 0, 0), 6)
	var blade = MeshInstance3D.new()
	blade.mesh = b.build(null)
	blade.material_override = _cel(0.25)
	ba.add_child(blade)
	var gl = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	gl.mesh = sm
	gl.material_override = _flat(Color(MOON.r, MOON.g, MOON.b, 0.3), true)
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gl.position = Vector3(0, 0, len_ * 0.58)
	gl.scale = Vector3(0.07, 0.16, len_ * 1.05)
	blade.add_child(gl)
	var tw = Game.safe_loops(gl.create_tween())
	tw.tween_property(gl, "scale", Vector3(0.09, 0.2, len_ * 1.08), 0.12)
	tw.tween_property(gl, "scale", Vector3(0.06, 0.14, len_ * 1.02), 0.12)
	pj.free_after(dur, ba)


## Hakkō Chakura Tō: gerçek tanto + ağzında beyaz chakra kılıfı + kılıçtan dökülen ak zerreler
static func _white_tanto(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	var tanto = MeshInstance3D.new()
	tanto.mesh = CharacterModel.weapon_mesh("tanto")
	ba.add_child(tanto)
	for layer in 2:
		var gl = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 10
		sm.rings = 5
		gl.mesh = sm
		gl.material_override = _flat(Color(1, 1, 1, 0.8) if layer == 0 else Color(0.75, 0.88, 1.0, 0.28), true)
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc = Vector3(0.05, 0.08, 0.46) if layer == 0 else Vector3(0.13, 0.18, 0.58)
		gl.position = Vector3(0, 0, 0.22)
		gl.scale = sc
		tanto.add_child(gl)
		var tw = Game.safe_loops(gl.create_tween())
		tw.tween_property(gl, "scale", sc * Vector3(1.4, 1.3, 1.05), 0.07 + layer * 0.03)
		tw.tween_property(gl, "scale", sc, 0.07 + layer * 0.03)
	_puffs(Vector3.ZERO, {"parent": ba, "local": Vector3(0, 0, 0.25), "loop": true, "n": 36, "life": 0.6, "expl": 0.0, "r": 0.18, "vmin": 0.1, "vmax": 0.5,
		"grav": Vector3(0, 0.8, 0), "damp": 1.5, "size": 0.09, "s0": 1.0, "s1": 0.1, "add": true,
		"cols": [Color(1, 1, 1, 0.95), Color(0.85, 0.93, 1.0, 0.7), Color(0.7, 0.85, 1.0, 0.0)]})
	pj.free_after(dur, ba)


## Hirudora kaplanı: sıkışmış havadan kaplan başı — açık çene, dişler, kulaklar, parlayan gözler, arkaya savrulan yele (ileri -Z)
static func _tiger(s: float, mat: ShaderMaterial) -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	var w = Color.WHITE
	var g = Color(0.42, 0.48, 0.62)   # kaplan çizgileri (koyu gri-mavi)
	b.add("sphere", Vector3(0, 0.1, 0.1), Vector3(1.9, 1.55, 1.8), w, Vector3.ZERO, 18)   # kafatası
	b.add("sphere", Vector3(0, -0.15, -0.9), Vector3(1.3, 0.85, 1.0), w, Vector3.ZERO, 14)   # burun köprüsü
	b.add("sphere", Vector3(0, 0.0, -1.32), Vector3(1.05, 0.42, 0.75), w, Vector3(-8, 0, 0), 14)   # üst çene
	b.add("sphere", Vector3(0, -1.0, -1.12), Vector3(0.9, 0.3, 0.9), w, Vector3(30, 0, 0), 14)   # sonuna dek açılmış alt çene
	b.add("sphere", Vector3(0, 0.14, -1.66), Vector3(0.38, 0.22, 0.2), Color(0.16, 0.18, 0.26))   # burun ucu
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.74 * sx, 0.98, 0.15), Vector3(0.62, 0.85, 0.3), w, Vector3(0, 0, -25.0 * sx), 8)   # kulak
		b.add("cone", Vector3(0.72 * sx, 0.92, 0.0), Vector3(0.34, 0.5, 0.1), g, Vector3(0, 0, -25.0 * sx), 6)   # kulak içi
		b.add("sphere", Vector3(0.42 * sx, 0.52, -0.84), Vector3(0.72, 0.3, 0.46), w, Vector3(0, 0, 16.0 * sx), 10)   # çatık kaş
		b.add("sphere", Vector3(1.0 * sx, -0.32, -0.25), Vector3(0.75, 1.0, 1.2), w, Vector3.ZERO, 10)   # yanak tüyü
		b.add("cone", Vector3(1.3 * sx, -0.4, 0.05), Vector3(0.42, 0.9, 0.42), w, Vector3(0, 0, -100.0 * sx), 8)   # yanak sivrisi
		b.add("sphere", Vector3(0.32 * sx, -0.3, -1.36), Vector3(0.46, 0.36, 0.36), w, Vector3.ZERO, 10)   # bıyık yastığı
		for k in 3:   # yanak çizgileri
			b.add("box", Vector3((0.62 + k * 0.16) * sx, 0.15 - k * 0.22, -0.55 + k * 0.08), Vector3(0.1, 0.07, 0.6), g, Vector3(0, 30.0 * sx, -20.0 * sx))
	for k in 3:   # alın çizgileri
		b.add("box", Vector3(0, 0.86 - k * 0.05, -0.2 - k * 0.3), Vector3(0.62 - k * 0.14, 0.07, 0.1), g)
	for k in 7:   # yele: arkaya savrulan kısa tutamlar
		var a = TAU * float(k) / 7.0 + 0.2
		b.add("cone", Vector3(cos(a) * 0.7, sin(a) * 0.6 + 0.1, 1.05), Vector3(0.5, 1.2, 0.5), w, Vector3(90, 0, 0), 8)
	var body = MeshInstance3D.new()
	body.mesh = b.build(null)
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	root.add_child(_hull(body.mesh, Color(0.1, 0.16, 0.34, 1.0), 0.05))   # koyu dış çizgi: gündüz okunur
	var t = MB.new()   # ağız içi + dişler + gözler: cel, ışıklı
	t.add("sphere", Vector3(0, -0.5, -1.08), Vector3(0.8, 0.5, 0.62), Color(0.16, 0.17, 0.26))
	t.add("sphere", Vector3(0, -0.72, -1.15), Vector3(0.5, 0.12, 0.45), Color(0.75, 0.3, 0.35))   # dil
	for sx in [-1.0, 1.0]:
		t.add("cone", Vector3(0.34 * sx, -0.44, -1.5), Vector3(0.2, 0.62, 0.2), Color(0.98, 0.98, 1.0), Vector3(180, 0, 0), 6)
		t.add("cone", Vector3(0.3 * sx, -0.8, -1.45), Vector3(0.16, 0.45, 0.16), Color(0.98, 0.98, 1.0), Vector3.ZERO, 6)
		t.add("sphere", Vector3(0.45 * sx, 0.27, -1.0), Vector3(0.36, 0.18, 0.2), Color(1.0, 0.6, 0.12), Vector3(0, 0, -14.0 * sx))   # badem göz
		t.add("sphere", Vector3(0.45 * sx, 0.27, -1.09), Vector3(0.06, 0.17, 0.04), Color(0.03, 0.02, 0.02))   # yarık göz bebeği
	var teeth = MeshInstance3D.new()
	teeth.mesh = t.build(null)
	teeth.material_override = _cel(0.5)
	teeth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(teeth)
	root.scale = Vector3.ONE * s
	return root


## Serbest Namikaze ışınlanması: sarı-ak dikey çakma çizgisi + kıvılcımlar
static func _yellow_step(pos: Vector3, s := 1.0) -> void:
	var m = _trail(Color(1, 1, 0.92, 1), Color(FLASH_Y.r, FLASH_Y.g, FLASH_Y.b, 0.8), 0.28, true)
	_streak(pos + Vector3.UP * 2.3 * s, pos - Vector3.UP * 0.1, 0.35 * s, m, 0.03, 0.02, 0.16, {"tail": 1.0, "taper": 0.3, "n": 6})
	_puffs(pos + Vector3.UP * 1.0, {"n": 12, "life": 0.3, "r": 0.5, "vmin": 2.0, "vmax": 5.0, "spread": 180.0, "grav": Vector3.ZERO, "damp": 6.0,
		"size": 0.1, "s0": 1.0, "s1": 0.0, "add": true, "cols": [Color(1, 1, 0.9, 1), FLASH_Y, Color(1.0, 0.6, 0.1, 0)]})
	_light(pos + Vector3.UP, FLASH_Y, 3.0, 5.0, 0.15)


## Anime çarpma çizgileri: merkezden dışa açılan ince ak ışınlar (Kanransha ref)
static func _impact_lines(pos: Vector3, n: int, r0: float, r1: float, dur: float, col := Color(1, 1, 1)) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	var mat = _flat(Color(1, 1, 1, 1), false)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(mi, pos)
	var to_cam = (_cam() - pos).normalized()
	var ax = to_cam.cross(Vector3.UP)
	if ax.length() < 0.1:
		ax = Vector3.RIGHT
	ax = ax.normalized()
	var ay = ax.cross(to_cam).normalized()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n:
		var a = TAU * float(k) / n + randf_range(-0.12, 0.12)
		var dv = ax * cos(a) + ay * sin(a)
		var sv = ax * cos(a + PI * 0.5) + ay * sin(a + PI * 0.5)
		var ra = r0 * randf_range(0.8, 1.2)
		var rb = r1 * randf_range(0.7, 1.15)
		var wv = randf_range(0.025, 0.06) * r1 / 3.0
		for v in [[dv * ra, 0.0], [dv * rb + sv * wv, 0.95], [dv * rb - sv * wv, 0.95]]:
			im.surface_set_color(Color(col.r, col.g, col.b, v[1]))
			im.surface_add_vertex(to_cam * 0.4 + v[0])
	im.surface_end()
	mi.scale = Vector3.ONE * 0.6
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.15, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(a: float): mat.albedo_color = Color(1, 1, 1, a), 1.0, 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Kapı bedeli (eski _gate_cost ile aynı mekanik) + kendi yeşil buhar görünüşü
static func _gate_cost(c: Node3D, frac: float) -> void:
	if PathJutsu.gate_level(c) < 1:
		if c is Player:
			c.hp = maxf(1.0, c.hp - c.max_hp * frac)
		c.set_meta("gates", 1)
		c.set_meta("gates_until", Game.now() + 8.0)
	var p = _puffs(Vector3.ZERO, {"parent": c, "local": Vector3(0, 0.9, 0), "loop": true, "n": 28, "life": 0.7, "expl": 0.0, "r": 0.5,
		"vmin": 0.8, "vmax": 2.2, "spread": 25.0, "grav": Vector3(0, 1.5, 0), "damp": 1.0, "size": 0.45, "s0": 0.4, "s1": 1.3,
		"cols": [Color(0.75, 1.0, 0.7, 0.0), Color(0.55, 1.0, 0.5, 0.45), Color(0.35, 0.85, 0.35, 0.0)]})
	var w = weakref(p)
	_tree().create_timer(1.0).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.emitting = false)
	_kill_later(p, 1.9)


# ================================================================== yılan (Mitarashi): yenden çıkan kendi yılanım
## anchor: func() -> Variant (el konumu ya da null), target varsa uzanır + sarılır; yoksa free_to'ya uzanır
class Serpent extends Node3D:
	var anchor: Callable
	var target: Node3D = null
	var free_to := Vector3.ZERO
	var side := 0.0
	var lift := 0.1
	var phase := 0.0
	var coil := true
	var rad := 0.085
	var ext := 0.0
	var speed := 0.0
	var reach_cb: Callable = Callable()
	var reached := false
	var coil_k := 0.0
	var tt := 0.0
	var am: ArrayMesh
	var body: MeshInstance3D
	var head: MeshInstance3D
	const N := 18
	const SIDES := 6

	func _ready() -> void:
		am = ArrayMesh.new()
		body = MeshInstance3D.new()
		body.mesh = am
		body.material_override = ClanFX._cel(0.0)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		head = ClanFX._snake_head(rad * 3.4)
		add_child(head)
		head.visible = false

	func extend(dur: float, cb := Callable()) -> void:
		speed = 1.0 / maxf(dur, 0.01)
		reach_cb = cb

	func retract(dur: float) -> void:
		speed = -1.0 / maxf(dur, 0.01)
		reached = true

	func _alive_target() -> bool:
		return target != null and is_instance_valid(target) and not target.is_dead()

	func _coil_pt(k: float) -> Vector3:
		var h = float(target.height)
		var cen = target.global_position + Vector3.UP * h * lerpf(0.55, 0.32, k)
		var a = phase + k * TAU * 1.3
		var r = float(target.radius) + 0.12
		return cen + Vector3(cos(a), 0, sin(a)) * r

	func _pt(s: float, a: Vector3, g: Vector3) -> Vector3:
		var d = g - a
		var L = maxf(d.length(), 0.01)
		var f = d / L
		var sd = f.cross(Vector3.UP)
		if sd.length() < 0.1:
			sd = Vector3.RIGHT
		sd = sd.normalized()
		var up = sd.cross(f).normalized()
		var env = sin(s * PI)
		var wig = sin(s * 10.0 + phase - tt * 16.0) * 0.16 * env
		var lm = minf(L, 6.0)
		return a + d * s + sd * (wig + side * env * lm * 0.22) + up * (lift * env * lm * 0.2 + cos(s * 7.0 + phase - tt * 11.0) * 0.06 * env)

	func _process(dt: float) -> void:
		tt += dt
		ext = clampf(ext + speed * dt, 0.0, 1.0)
		if speed > 0.0 and ext >= 1.0 and not reached:
			reached = true
			if reach_cb.is_valid():
				reach_cb.call()
		if speed < 0.0 and ext <= 0.0:
			queue_free()
			return
		var want = 1.0 if (reached and speed >= 0.0 and coil and _alive_target()) else 0.0
		coil_k = move_toward(coil_k, want, dt * 5.0)
		_rebuild()

	func _rebuild() -> void:
		var av = anchor.call() if anchor.is_valid() else null
		if av == null:
			queue_free()
			return
		var a: Vector3 = av
		var has_t = _alive_target()
		var g: Vector3 = _coil_pt(0.0) if has_t else free_to
		var pts = []
		for i in N + 1:
			pts.append(_pt(ext * float(i) / N, a, g))
		if has_t and coil_k > 0.01 and ext >= 0.999:
			for i in range(1, 11):
				pts.append(_coil_pt(coil_k * float(i) / 10.0))
		am.clear_surfaces()
		var cnt = pts.size()
		if cnt < 2 or ext < 0.01:
			head.visible = false
			return
		var vs = PackedVector3Array()
		var ns = PackedVector3Array()
		var cs = PackedColorArray()
		var ix = PackedInt32Array()
		var run = 0.0
		for i in cnt:
			var p: Vector3 = pts[i]
			var tg: Vector3 = pts[mini(i + 1, cnt - 1)] - pts[maxi(i - 1, 0)]
			if tg.length() < 0.0001:
				tg = Vector3.FORWARD
			tg = tg.normalized()
			var sd = tg.cross(Vector3.UP)
			if sd.length() < 0.1:
				sd = tg.cross(Vector3.RIGHT)
			sd = sd.normalized()
			var up = sd.cross(tg).normalized()
			if i > 0:
				run += p.distance_to(pts[i - 1])
			var u = float(i) / (cnt - 1)
			var r = rad * lerpf(0.7, 1.0, u)
			var band = int(run / 0.15) % 2 == 0
			for j in SIDES:
				var an = TAU * float(j) / SIDES
				var nrm = sd * cos(an) + up * sin(an)
				var col: Color = ClanFX.SNAKE_A if band else ClanFX.SNAKE_B
				if sin(an) < -0.45:
					col = ClanFX.SNAKE_BELLY
				vs.append(p + nrm * r)
				ns.append(nrm)
				cs.append(col)
		for i in cnt - 1:
			for j in SIDES:
				var j2 = (j + 1) % SIDES
				var a0 = i * SIDES + j
				var a1 = i * SIDES + j2
				var b0 = (i + 1) * SIDES + j
				var b1 = (i + 1) * SIDES + j2
				for vi in [a0, b0, b1, a0, b1, a1]:
					ix.append(vi)
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_COLOR] = cs
		arr[Mesh.ARRAY_INDEX] = ix
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		head.visible = true
		var hp: Vector3 = pts[cnt - 1]
		var hd: Vector3 = hp - pts[cnt - 2]
		head.global_position = hp
		if hd.length() > 0.001:
			head.look_at(hp + hd, Vector3.UP if absf(hd.normalized().y) < 0.95 else Vector3.RIGHT)


## Eski sleeve_snake ile aynı yerleşim (yenden demet hâlinde çıkar, hedefe yakın ayrılır)
static func _serpent(pj: PathJutsu, c: Node3D, right: bool, e: Node3D, i: int, n: int, free_off: Vector3, coil := true) -> Serpent:
	var sn = Serpent.new()
	var side_k = (float(i) / maxf(1.0, n - 1) - 0.5) * 2.0 if n > 1 else 0.0
	var cw = weakref(c)
	sn.anchor = func():
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return null
		return pj.hand_pos(cc, right) - cc.face_dir() * 0.05
	sn.target = e if e and pj.live(e) else null
	sn.free_to = c.global_position + Vector3.UP * 1.2 + free_off.rotated(Vector3.UP, side_k * 0.1)
	sn.side = side_k * 0.3
	sn.lift = (0.25 if i % 2 == 0 else 0.05)
	sn.phase = float(i) * 1.7 + (0.0 if right else 0.9)
	sn.coil = coil
	_root().add_child(sn)
	return sn


# ================================================================== HYŪGA
## Hakkeshō Kaiten (ref: yarı saydam mavi kubbe, içinde ak bulut lekeleri, çevresinde eğik dönen kahverengi toz kuşakları):
## tenketsulardan zerre fışkırır → dönen kubbe → toz kuşakları + zemin halkası → kubbe yere çöker, dairesel krater kalır
static func kaiten(J, c: Node3D, _t: Node3D) -> void:
	var m = J._mult(c)
	var R = 3.2
	var o0: Vector3 = c.global_position
	# hazırlık: bütün tenketsulardan aynı anda fışkıran ince chakra noktaları
	_puffs(o0 + Vector3.UP * 1.0, {"n": 46, "life": 0.35, "r": 0.45, "vmin": 6.0, "vmax": 10.0, "spread": 180.0, "grav": Vector3.ZERO, "damp": 10.0,
		"size": 0.09, "s0": 1.0, "s1": 0.2, "add": true, "cols": [Color(1, 1, 1, 1), HYUGA, Color(0.4, 0.6, 1.0, 0)]})
	var dome = MeshInstance3D.new()
	var dsm = SphereMesh.new()
	dsm.radius = 1.0
	dsm.height = 1.0
	dsm.is_hemisphere = true
	dsm.radial_segments = 36
	dsm.rings = 14
	dome.mesh = dsm
	var dmat = _air(Color(0.74, 0.87, 1.0, 0.8), Color(0.43, 0.63, 0.96), Color(0.9, 0.97, 1.0), 5.0, 7.0)
	dome.material_override = dmat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	J.get_tree().current_scene.add_child(dome)
	dome.global_position = c.global_position
	dome.scale = Vector3(0.3, 0.3, 0.3)
	var dtw = dome.create_tween()
	dtw.tween_property(dome, "scale", Vector3(R, R * 0.85, R), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dtw.parallel().tween_property(dome, "rotation:y", TAU * 3.0, 1.15)
	dtw.tween_property(dome, "scale", Vector3(R * 1.05, 0.05, R * 1.05), 0.2)
	dtw.parallel().tween_method(func(f: float): dmat.set_shader_parameter("fade", f), 1.0, 0.2, 0.2)
	dtw.tween_callback(dome.queue_free)
	# iç çekirdek: daha açık, ters dönen ikinci kat (derinlik)
	var core = MeshInstance3D.new()
	core.mesh = dsm
	var cmat = _air(Color(0.9, 0.96, 1.0, 0.35), Color(0.6, 0.78, 1.0), Color(1, 1, 1), 3.0, -9.0)
	core.material_override = cmat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	J.get_tree().current_scene.add_child(core)
	core.global_position = c.global_position
	core.scale = Vector3(0.2, 0.2, 0.2)
	var ctw = core.create_tween()
	ctw.tween_property(core, "scale", Vector3(R * 0.7, R * 0.62, R * 0.7), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctw.tween_interval(0.95)
	ctw.tween_property(core, "scale", Vector3(R * 0.8, 0.04, R * 0.8), 0.18)
	ctw.tween_callback(core.queue_free)
	var belt_m = _trail(Color(0.76, 0.66, 0.52, 0.95), Color(0.52, 0.42, 0.31, 0.9), 0.5)
	var skirt_m = _trail(Color(0.7, 0.6, 0.46, 0.85), Color(0.5, 0.41, 0.3, 0.6), 0.4)
	var swirl = func():
		if not is_instance_valid(c):
			return
		var o = c.global_position + Vector3.UP * 0.05
		for n in 3:   # kubbenin yanında eğik dönen toz kuşakları
			var hy = R * 0.85 * (0.14 + n * 0.26)
			var a0 = randf() * TAU
			var tilt = randf_range(0.12, 0.3) * R * 0.3
			var path = func(q: float) -> Vector3:
				var a = a0 + q * 2.4
				var y = clampf(hy + sin(a - a0) * tilt, 0.05, R * 0.8)
				var rr = R * sqrt(maxf(0.04, 1.0 - pow(y / (R * 0.85), 2.0))) * 1.06
				return o + Vector3(cos(a) * rr, y, sin(a) * rr)
			var upw = func(_q: float, _p: Vector3) -> Vector3: return Vector3.UP
			_ribbon(path, 0.34 - n * 0.05, belt_m, 0.1, 0.0, 0.16, {"tail": 0.75, "taper": 0.5, "n": 16, "wfn": upw})
		var b0 = randf() * TAU   # yerde dönen toz eteği
		var skirt = func(q: float) -> Vector3:
			var a = b0 + q * 2.0
			var sx = o.x + cos(a) * R * 1.1
			var sz = o.z + sin(a) * R * 1.1
			return Vector3(sx, _gy(sx, sz) + 0.12, sz)
		var skirt_w = func(q: float, _p: Vector3) -> Vector3:
			var a = b0 + q * 2.0
			return Vector3(cos(a), 0.15, sin(a)).normalized()
		_ribbon(skirt, 0.7, skirt_m, 0.1, 0.0, 0.2, {"tail": 0.8, "taper": 0.4, "n": 14, "wfn": skirt_w})
	swirl.call()
	# anime: Neji kollarını iki yana açar (avuçlar açık, hafif çömelik), topuğu üstünde hızla döner — kubbe dönüşten doğar
	var mdl = c.get("model")
	if mdl and mdl.get("overlay"):
		var S = preload("res://scripts/combat/samehada_anim.gd")
		var F = preload("res://scripts/combat/style_legs.gd")
		var R_OUT = {"RightUpperArm": Vector3(-0.97, 0.12, 0.2), "RightLowerArm": Vector3(-0.95, 0.15, 0.25)}
		var L_OUT = {"LeftUpperArm": Vector3(0.97, 0.12, 0.2), "LeftLowerArm": Vector3(0.95, 0.15, 0.25)}
		var R_IN = {"RightUpperArm": Vector3(-0.35, -0.85, 0.35), "RightLowerArm": Vector3(0.1, 0.3, 0.95)}
		var L_IN = {"LeftUpperArm": Vector3(0.35, -0.85, 0.35), "LeftLowerArm": Vector3(-0.1, 0.3, 0.95)}
		mdl.overlay.fist = {"Right": -1.0, "Left": -1.0}
		mdl.overlay.play_keys({"len": 1.35, "hit": 0.1, "keys": [
			S._k(0.0, 0.35, 0, 4, Vector3(0, 0, 1), S._a(R_IN, L_IN), F.FIGHT),
			S._k(0.1, 0.45, 0, 2, Vector3(0, 0, 1), S._a(R_OUT, L_OUT), F.LOW),
			S._k(1.1, 0.45, 0, 2, Vector3(0, 0, 1), S._a(R_OUT, L_OUT), F.LOW),
			S._k(1.35, 0.35, 0, 4, Vector3(0, 0, 1), S._a(R_IN, L_IN), F.FIGHT)]}, 1.0)
	var f0 = float(c.get("facing")) if c.get("facing") != null else 0.0
	J._ticks(44, 0.025, func(i):
		if is_instance_valid(c) and c.get("facing") != null:
			c.facing = f0 + TAU * 3.0 * float(i + 1) / 44.0
			if c.get("model") and not c is Player:
				c.model.rotation.y = c.facing)
	# açılış basıncı: yerde dışa kaçan kırık toz halkası
	var g0 = _ground(c.global_position)
	_ring(g0 + Vector3.UP * 0.05, Vector3.UP, R * 0.9, R * 3.6, 0.72, _ringm(Color(0.8, 0.72, 0.58, 0.8), Color(0.6, 0.5, 0.38, 0.7), 0.55), 0.5)
	_puffs(g0 + Vector3.UP * 0.2, {"n": 24, "life": 0.8, "pts": _ring_pts(R * 0.9, 24), "vmin": 3.0, "vmax": 6.0, "dir": Vector3.UP, "spread": 70.0,
		"flat": 0.5, "grav": Vector3(0, -1.0, 0), "damp": 3.0, "size": 0.9, "s0": 0.5, "s1": 1.3,
		"cols": [Color(0.8, 0.72, 0.58, 0.8), Color(0.66, 0.57, 0.45, 0.55), Color(0.6, 0.52, 0.42, 0)]})
	if c is Player:
		c.combat.invuln = 1.1
		c.combat.action = "cast"
		c.combat.t = -10.0
	Sfx.play("wind", c.global_position, 1.2)
	J._ticks(10, 0.1, func(_i):
		if not is_instance_valid(c):
			return
		c.model.rotation.y += 1.4
		swirl.call()
		if _i % 3 == 0:
			_puffs(c.global_position + Vector3.UP * 0.15, {"n": 10, "life": 0.5, "pts": _ring_pts(R, 10), "vmin": 3.0, "vmax": 6.0, "dir": Vector3.UP,
				"spread": 30.0, "tan": 20.0, "grav": Vector3.ZERO, "damp": 2.0, "size": 1.0, "s0": 0.5, "s1": 1.2,
				"cols": [Color(0.85, 0.78, 0.62, 1), Color(0.75, 0.68, 0.52, 0.8), Color(0.7, 0.62, 0.48, 0)]})
		for pr in J.get_tree().get_nodes_in_group("projectiles"):
			if pr.shooter != c and not pr.dead and pr.global_position.distance_to(c.global_position + Vector3.UP) < 4.0:
				# mermiyi geri savur (sahibine döner)
				var out = (pr.global_position - c.global_position - Vector3.UP).normalized()
				pr.vel = out * maxf(14.0, pr.vel.length())
				pr.shooter = c
				pr.homing = null
				_glint(pr.global_position, HYUGA, 1.8, 0.14, 6)
		Combat.hit_sphere(c, c.global_position + Vector3.UP, 3.4, {"dmg": 3.0 * m, "knock": 22.0, "launch": 4.0, "kind": "heavy"}), func():
		if c is Player:
			c.combat.action = ""
		if is_instance_valid(c):   # kubbe çöker: dönüşün oyduğu dairesel krater kalır
			var g = _ground(c.global_position)
			_mark(g, R * 1.08, 0.84, _ringm(Color(0.32, 0.25, 0.18, 0.85), Color(0.2, 0.15, 0.11, 0.9)), 3.5, 1.5)
			_mark(g + Vector3.UP * 0.005, R * 0.84, 0.0, _ringm(Color(0.56, 0.47, 0.36, 0.0), Color(0.5, 0.41, 0.31, 0.45)), 3.5, 1.5)
			_cracks(g, R * 1.7, 10, 5.0)
			_chunks(g + Vector3.UP * 0.3, 16, Color(0.45, 0.36, 0.27), 7.0, 0.2, Vector3.UP, 80.0)
			_puffs(g + Vector3.UP * 0.2, {"n": 18, "life": 1.2, "pts": _ring_pts(R * 1.05, 18), "vmin": 1.0, "vmax": 2.5, "spread": 40.0,
				"grav": Vector3(0, 0.2, 0), "damp": 1.5, "size": 1.3, "s0": 0.5, "s1": 1.4,
				"cols": [Color(0.78, 0.7, 0.56, 0.7), Color(0.66, 0.57, 0.45, 0.4), Color(0.6, 0.52, 0.42, 0)]}))


## Hakke Hasangeki (ref: avuçtan fışkıran, ekranı yaran dev ak chakra dalgası): avuçta mavi alev toplanır →
## avuç biçimli dev chakra eli ileri fırlar, önünde basınç halkaları → yerde uzun oluk, çatlak, moloz
static func hakke_hasangeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_hand_aura(pj, c, "RightHand", HYUGA, 0.8, 0.12, 36)
	_hand_aura(pj, c, "LeftHand", HYUGA, 0.8, 0.12, 36)
	var tt = pj.tg(c, t, 6.0)
	if tt and is_instance_valid(tt):
		c.global_position = pj.gp(tt.global_position - (tt.global_position - c.global_position).normalized() * (tt.radius + 0.9))
		if c is Player:
			c.combat.face_to(tt)
	var d = pj.fwd(c, tt if tt else t)
	d.y = 0.0
	d = d.normalized()
	pj.busy(c, 0.75)
	_byakugan(pj, c, 1.2)
	pj.anim(c, "crouch", 2.0)   # geri çekiliş: ağırlık arka ayağa
	_gather(Jutsu._hand(c), HYUGA, 1.7, 0.28, 10)
	pj.after(0.28, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var p0 = c.global_position + Vector3.UP * 1.1 + d * 0.9
		_glint(p0, HYUGA, 3.6, 0.22, 8)
		_light(p0 + d * 2.0, Color(0.78, 0.9, 1.0), 8.0, 14.0, 0.4)
		# avuç biçimli dev chakra eli: ileri fırlar, büyür, dağılır (ak gövde, mavi kenar)
		for layer in 2:
			var pm = _air(Color(0.97, 0.98, 1.0, 0.9 if layer == 0 else 0.45), Color(0.62, 0.74, 0.95), Color(0.5, 0.72, 1.0), 4.0, 10.0)
			pm.set_shader_parameter("form", 0.4 if layer == 0 else 0.0)
			var palm = _palm_node(pm)
			var hl: MeshInstance3D = _hull(palm.mesh, Color(0.2, 0.38, 0.85, 1.0 if layer == 0 else 0.0), 0.035)
			palm.add_child(hl)
			var hm: ShaderMaterial = hl.material_override
			_put(palm, p0)
			palm.look_at(p0 + d, Vector3.UP)
			palm.scale = Vector3.ONE * (0.55 if layer == 0 else 0.4)
			var fset = func(f: float) -> void:
				pm.set_shader_parameter("fade", f)
				hm.set_shader_parameter("fade", f)
			var ptw = palm.create_tween()
			var dl = 0.0 if layer == 0 else 0.06
			ptw.tween_interval(dl)
			ptw.tween_property(palm, "global_position", p0 + d * (8.5 - layer * 2.0), 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			ptw.parallel().tween_property(palm, "scale", Vector3.ONE * (2.4 - layer * 0.5), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			ptw.parallel().tween_method(fset, 1.0, 0.0, 0.5).set_delay(0.22)
			ptw.tween_callback(palm.queue_free)
		# basınç cepheleri: avucun önünde dikey açılan halkalar
		_ring(p0 + d * 1.2, d, 0.6, 4.8, 0.62, _ringm(Color(1, 1, 1, 0.95), Color(0.55, 0.75, 1.0, 0.75), 0.3), 0.28)
		_ring(p0 + d * 4.5, d, 1.2, 6.5, 0.8, _ringm(Color(0.95, 0.98, 1.0, 0.6), Color(0.6, 0.78, 1.0, 0.5), 0.6), 0.42)
		# dalga: avuçtan ileri açılan basınç çizgileri
		var lm = _trail(Color(1, 1, 1, 0.95), Color(0.6, 0.78, 1.0, 0.8), 0.35)
		var sdv = d.cross(Vector3.UP).normalized()
		for n in 22:
			var off = sdv * randf_range(-0.8, 0.8) + Vector3.UP * randf_range(-0.5, 0.9)
			var spread = sdv * randf_range(-0.22, 0.22) + Vector3.UP * randf_range(-0.06, 0.14)
			var L = randf_range(9.0, 15.0)
			var lpath = func(q: float) -> Vector3: return p0 + off + (d + spread * q) * L * q
			_ribbon(lpath, randf_range(0.05, 0.12), lm, 0.22, 0.0, 0.18, {"tail": 0.45, "taper": 0.9, "n": 10})
		# yerde yarılan toprak: uzun oluk + kademeli moloz
		_gouge(c.global_position + d * 1.0, c.global_position + d * 14.0, 1.6, 6.0)
		for k in 7:
			pj.after(k * 0.04, func():
				var g = pj.gp(c.global_position + d * (2.0 + k * 2.0))
				_chunks(g + Vector3.UP * 0.2, 6, Color(0.5, 0.39, 0.28), 7.0, 0.22, Vector3.UP + d, 45.0)
				_puffs(g + Vector3.UP * 0.3, {"n": 6, "life": 0.9, "r": 0.9, "vmin": 2.0, "vmax": 5.0, "dir": (Vector3.UP + d).normalized(), "spread": 50.0,
					"grav": Vector3(0, -0.5, 0), "damp": 2.5, "size": 1.1, "s0": 0.4, "s1": 1.4,
					"cols": [Color(0.78, 0.68, 0.54, 0.8), Color(0.64, 0.55, 0.43, 0.5), Color(0.6, 0.52, 0.42, 0)]}))
		_cracks(pj.gp(c.global_position + d * 4.0), 5.0, 6, 5.0, DIRT, d)
		# yakın darbe: dayanılan hedef + önündeki dar koridor
		var hits = []
		for k in 5:
			for h in pj.hit(c, p0 + d * (0.6 + k * 1.6), 1.2 + k * 0.15, pj.inf(c, "hakke_hasangeki", 1.7, {"knock": 34.0, "launch": 5.0, "kind": "heavy", "dir": d, "hitstop": 0.1, "pierce_guard": true}), hits):
				hits.append(h)
		for h in hits:
			if is_instance_valid(h):
				_glint(h.global_position + Vector3.UP * 1.1, HYUGA, 2.6, 0.2, 6)
		Sfx.play("wind", p0, 0.6)
		Sfx.play("punch", p0, 0.7)
		pj.shake(0.7))


# ================================================================== HATAKE — Beyaz Işık Chakra Kılıcı
## Hakkō Chakura Tō (Konoha'nın Beyaz Dişi): ayakta toz patlar, ışık hızında atılış — geçtiği hatta ak chakra izi kalır,
## hat boyunca ak zerreler yavaşça süzülür, varışta yatay ak hilal kesik
static func hatake_hakko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_white_tanto(pj, c, 1.0)
	var start = c.global_position + Vector3.UP * 1.1
	var d = pj.fwd(c, t)
	var tt = pj.tg(c, t, 16.0)
	var s0 = c.global_position
	var dist = (tt.global_position.distance_to(c.global_position) + 3.0) if tt else 10.0
	var end = pj.gp(s0 + d * dist)
	var hs_all = []
	for k in 8:
		var p = s0.lerp(end, k / 7.0) + Vector3.UP * 1.1
		for h in pj.hit(c, p, 1.4, pj.inf(c, "hatake_hakko", 0.4, {"knock": 6.0, "kind": "heavy", "hitstop": 0.03})):
			hs_all.append(h)
	c.global_position = end
	if c is Player:
		c.facing = atan2(-d.x, -d.z)
	# atılış: ayağın bastığı yerde toz + kısa zemin halkası
	var g0 = _ground(s0)
	_puffs(g0 + Vector3.UP * 0.2, {"n": 10, "life": 0.6, "r": 0.4, "vmin": 2.0, "vmax": 4.0, "dir": (Vector3.UP - d).normalized(), "spread": 50.0,
		"grav": Vector3(0, -1.0, 0), "damp": 3.0, "size": 0.8, "s0": 0.4, "s1": 1.3,
		"cols": [Color(0.8, 0.72, 0.58, 0.75), Color(0.66, 0.57, 0.45, 0.4), Color(0.6, 0.52, 0.42, 0)]})
	_ring(g0 + Vector3.UP * 0.05, Vector3.UP, 0.3, 2.2, 0.7, _ringm(Color(0.85, 0.8, 0.7, 0.7), Color(0.7, 0.62, 0.5, 0.5), 0.5), 0.3)
	# ak chakra izi: geniş yumuşak kuşak + keskin ak çekirdek
	var a = start
	var b = end + Vector3.UP * 1.1
	_streak(a, b, 0.95, _trail(Color(0.97, 0.99, 1.0, 0.8), Color(0.66, 0.8, 1.0, 0.45), 0.4), 0.05, 0.5, 0.8, {"tail": 1.0, "taper": 0.85, "n": 16})
	_streak(a, b, 0.14, _trail(Color(1, 1, 1, 1), Color(0.8, 0.9, 1.0, 0.8), 0.5), 0.05, 0.35, 0.5, {"tail": 1.0, "taper": 0.95, "n": 16})
	_puffs(a, {"n": 26, "life": 1.4, "pts": _line_pts(a, b, 14, a), "vmin": 0.1, "vmax": 0.5, "spread": 180.0, "grav": Vector3(0, 0.35, 0), "damp": 1.0,
		"size": 0.1, "s0": 1.0, "s1": 0.0, "add": true, "expl": 0.6, "cols": [Color(1, 1, 1, 0.9), Color(0.85, 0.93, 1.0, 0.6), Color(0.7, 0.85, 1.0, 0)]})
	# varış: yatay ak hilal kesik
	var sd = d.cross(Vector3.UP).normalized()
	_slash(end + Vector3.UP * 1.1, d, sd, deg_to_rad(-20.0), 2.4, -1.4, 1.4, 0.6, _trail(Color(1, 1, 1, 1), Color(0.6, 0.78, 1.0, 0.9), 0.38), 0.08, 0.25, 0.4,
		{"tail": 0.9, "taper": 0.9, "n": 22})
	_light(end + Vector3.UP, Color(0.95, 0.97, 1.0), 6.0, 8.0, 0.25)
	_glint(end + Vector3.UP * 1.1, HAKKO, 2.4, 0.2, 4)
	for h in hs_all:
		if is_instance_valid(h):
			_glint(h.global_position + Vector3.UP * 1.1, HAKKO, 1.6, 0.16, 4)
	Sfx.play("whoosh", end, 1.6)
	pj.anim(c, "slash_a", 2.0)
	pj.after(0.25, func():
		if pj.live(c):
			var e2 = c.global_position + Vector3.UP * 1.1
			if (e2 - start).length() > 0.5:   # artakalan ince ak dikiş: yavaş incelir
				_streak(start, e2, 0.05, _trail(Color(1, 1, 1, 0.9), Color(0.85, 0.93, 1.0, 0.5), 0.6), 0.02, 0.5, 0.8, {"tail": 1.0, "taper": 0.0, "eat": 0.0, "n": 8}))


## Hakkōjin (Sakumo / genç Kakashi): dört ince ak hilal — kesiklerin yeri havada ince yarık olarak kalıp kapanır;
## sonunda yukarıdan dikey kesik yere iner: zeminde ak parlayan yarık, yanlara ak chakra kıvılcımı
static func hakkojin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.3)
	var id = "hakkojin"
	var d = pj._jump_at(c, tt, 0.0, 32.0)
	var side = d.cross(Vector3.UP).normalized()
	_white_tanto(pj, c, 1.5)
	Sfx.play("blade", c.global_position, 1.2)
	var rolls = [0.35, -0.5, 0.15, -0.2]
	var keys = ["slash_a", "slash_b", "slash_a", "slash_c"]
	var cut_m = _trail(Color(1, 1, 1, 1), Color(0.7, 0.9, 1.0, 0.85), 0.42)
	var slit_m = _trail(Color(1, 1, 1, 1), Color(0.85, 0.95, 1.0, 0.6), 0.5, true)
	for k in 4:
		var cut = func():
			if not pj.live(c):
				return
			if tt != null and pj.live(tt):
				d = pj._face(c, tt)
				side = d.cross(Vector3.UP).normalized()
			if c is CharacterBody3D:   # hedefe yapışık kalır: uzaksa kapatır, dibindeyse hafifçe iter
				c.velocity = d * (22.0 if tt != null and pj.live(tt) and c.global_position.distance_to(tt.global_position) > 2.2 else 4.0)
			pj.anim(c, keys[k], 2.6)
			var o = c.global_position + Vector3.UP * 1.15
			var sgn = 1.0 if k % 2 == 0 else -1.0
			_slash(o, d, side, rolls[k], 1.55, -1.25 * sgn, 1.25 * sgn, 0.32, cut_m, 0.07, 0.0, 0.16, {"tail": 0.7, "taper": 0.95, "n": 16})
			var hs = pj.hit(c, o + d * 1.2, 1.6, pj.inf(c, id, 0.5, {"knock": 1.0, "kind": "light", "bleed": 1.0, "hitstop": 0.03, "melee": true}))
			# kesik yeri: havada kalan ince yarık (kesik düzlemi boyunca), sonra kapanır
			var sv: Vector3 = side * cos(rolls[k]) + Vector3.UP * sin(rolls[k])
			var sc = o + d * 1.3
			_streak(sc - sv * 0.75, sc + sv * 0.75, 0.07, slit_m, 0.03, 0.25, 0.3, {"tail": 1.0, "taper": 0.0, "eat": 0.5, "n": 6})
			if hs.size() > 0:
				_glint(hs[0].global_position + Vector3.UP * 1.1, HAKKO, 1.5, 0.14, 4)
			Sfx.play("blade", o, 1.4, 0.5)
		pj.after(0.2 + k * 0.15, cut)
	# son: sıçrayıp yukarıdan aşağı
	var hop = func():
		if pj.live(c) and c is CharacterBody3D:
			c.velocity = d * 3.0 + Vector3.UP * 6.5
			_puffs(_ground(c.global_position) + Vector3.UP * 0.2, {"n": 8, "life": 0.5, "r": 0.35, "vmin": 1.5, "vmax": 3.0, "spread": 70.0, "flat": 0.6,
				"grav": Vector3.ZERO, "damp": 3.0, "size": 0.6, "cols": [Color(0.8, 0.72, 0.58, 0.6), Color(0.6, 0.52, 0.42, 0)]})
	pj.after(0.2 + 4 * 0.15, hop)
	var fin = func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_c", 2.0)
		if c is CharacterBody3D:
			c.velocity = Vector3.DOWN * 12.0
		var o = c.global_position + Vector3.UP * 1.2
		var g = pj.gp(c.global_position + d * 1.5)
		var vm = _trail(Color(1, 1, 1, 1), Color(0.75, 0.9, 1.0, 0.85), 0.4)
		var vplane = func(q: float) -> Vector3:
			var a = lerpf(1.35, -0.5, q)
			return o + (d * cos(a) + Vector3.UP * sin(a)) * 1.8
		var vw = func(q: float, _p: Vector3) -> Vector3:
			var a = lerpf(1.35, -0.5, q)
			return d * cos(a) + Vector3.UP * sin(a)
		_ribbon(vplane, 0.55, vm, 0.08, 0.04, 0.3, {"tail": 0.9, "taper": 0.9, "n": 20, "wfn": vw})
		var hs = pj.hit(c, o + d * 1.3 - Vector3.UP * 0.3, 1.9, pj.inf(c, id, 1.8, {"knock": 9.0, "launch": -8.0, "kind": "heavy", "bleed": 2.5, "hitstop": 0.12, "melee": true}))
		# zeminde ak yarık: önce parlak, sonra koyu kesik olarak kalır
		var ga = _ground(g - d * 0.6)
		var gb = _ground(g + d * 2.4)
		var sw = func(_q: float, _p: Vector3) -> Vector3: return side
		_streak(ga + Vector3.UP * 0.04, gb + Vector3.UP * 0.04, 0.22, _trail(Color(1, 1, 1, 1), Color(0.75, 0.9, 1.0, 0.8), 0.45, true), 0.05, 0.15, 0.5, {"tail": 1.0, "taper": 0.2, "n": 8, "wfn": sw})
		_gouge(g - d * 0.6, g + d * 2.4, 0.35, 4.0, Color(0.42, 0.34, 0.26), Color(0.12, 0.1, 0.08))
		_puffs(g + Vector3.UP * 0.2, {"n": 22, "life": 0.5, "r": 0.4, "vmin": 4.0, "vmax": 8.0, "dir": Vector3.UP, "spread": 75.0, "flat": 0.7,
			"grav": Vector3(0, -14.0, 0), "damp": 1.0, "size": 0.09, "s0": 1.0, "s1": 0.2, "add": true,
			"cols": [Color(1, 1, 1, 1), Color(0.8, 0.9, 1.0, 0.8), Color(0.7, 0.85, 1.0, 0)]})
		_glint(g + Vector3.UP * 0.9, HAKKO, 2.6 if hs.size() > 0 else 1.4, 0.16, 4)
		_light(g + Vector3.UP, Color(0.95, 0.97, 1.0), 5.0, 7.0, 0.2)
		if hs.size() > 0:
			pj.shake(0.5)
		Sfx.play("blade", o, 0.8)
	pj.after(0.2 + 4 * 0.15 + 0.3, fin)


# ================================================================== MITARASHI — yılanlar
## Mōjajūrin: iki yılan yenden fırlar, rakibe sarılır; rakip çevrende savrulurken yerden toz kasırgası kalkar,
## havaya bırakılınca yukarı rüzgâr çizgileri; dört yılan ısırır — mor zehir damlaları
static func mojajurin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.9)
	var id = "mojajurin"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var right = pj.fore_hand(c)
	var snakes = []
	for k in 2:
		var sn = _serpent(pj, c, right if k == 0 else not right, tt, k, 2, d * 12.0)
		snakes.append(sn)
	Sfx.play("whoosh", c.global_position, 0.7)
	var grabbed = {"ok": false}
	snakes[0].extend(0.3, func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		grabbed["ok"] = true
		pj.st(x, "bind", 1.4)
		_poison(pj, cc, x, id, 0.35, 3.0))
	snakes[1].extend(0.34)
	var whirl_m = _trail(Color(0.95, 0.96, 0.9, 0.8), Color(0.7, 0.66, 0.52, 0.55), 0.35)
	var spin = func(i, k):   # rakibi çevresinde savurur
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x) or not grabbed["ok"]:
			return
		var a = atan2(d.z, d.x) + k * TAU * 2.0
		var r = 3.2
		x.global_position = cc.global_position + Vector3(cos(a) * r, 1.2 + sin(k * PI) * 1.2, sin(a) * r)
		if x is CharacterBody3D:
			x.velocity = Vector3.ZERO
		if cc.get("model"):
			cc.model.rotation.y = -(a - atan2(d.z, d.x))
		if i % 6 == 0:   # savrulan gövdenin ardında kalan hava izi
			var o = cc.global_position
			var yy = 1.2 + sin(k * PI) * 1.2
			var wpath = func(u: float) -> Vector3:
				var aa = a - (1.0 - u) * 1.3
				return o + Vector3(cos(aa) * r, yy, sin(aa) * r)
			var upw = func(_q: float, _p: Vector3) -> Vector3: return Vector3.UP
			_ribbon(wpath, 0.5, whirl_m, 0.05, 0.0, 0.22, {"tail": 1.0, "taper": 0.9, "n": 12, "wfn": upw})
		if i % 8 == 0:   # yerden kalkan toz kasırgası
			_puffs(_ground(cc.global_position) + Vector3.UP * 0.2, {"n": 10, "life": 0.7, "pts": _ring_pts(r * 0.9, 10), "vmin": 1.0, "vmax": 3.0,
				"dir": Vector3.UP, "spread": 25.0, "tan": 14.0, "grav": Vector3(0, 0.8, 0), "damp": 1.5, "size": 0.9, "s0": 0.4, "s1": 1.4,
				"cols": [Color(0.8, 0.72, 0.58, 0.65), Color(0.66, 0.57, 0.45, 0.35), Color(0.6, 0.52, 0.42, 0)]})
	pj.after(0.35, func(): pj.every(0.85, 0.03, spin))
	pj.after(1.25, func():   # bırakır: havaya
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc != null and cc.get("model"):
			cc.model.rotation.y = 0.0
		for sn in snakes:
			if is_instance_valid(sn):
				sn.retract(0.2)
		if cc == null or x == null or not pj.live(cc) or not pj.live(x) or not grabbed["ok"]:
			return
		if "statuses" in x:
			x.statuses.erase("bind")
		x.take_hit(pj.inf(cc, id, 0.6, {"knock": 0.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.05}))
		var up_m = _trail(Color(1, 1, 1, 0.9), Color(0.8, 0.85, 0.75, 0.5), 0.3)
		var xp = x.global_position
		for n in 4:
			var off = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			_streak(xp + off, xp + off + Vector3.UP * randf_range(3.5, 5.5), 0.08, up_m, 0.15, 0.0, 0.2, {"tail": 0.5, "taper": 0.9, "n": 8})
		_ring(_ground(xp) + Vector3.UP * 0.05, Vector3.UP, 0.4, 3.0, 0.72, _ringm(Color(0.82, 0.74, 0.6, 0.7), Color(0.66, 0.57, 0.45, 0.5), 0.5), 0.35))
	pj.after(1.55, func():   # yılanlarla vurup uzaklaştırır
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or not pj.live(cc):
			return
		if x != null and pj.live(x):
			pj._face(cc, x)
		var fd: Vector3 = cc.face_dir()
		for k in 4:
			var sn = _serpent(pj, cc, k % 2 == 0, x if x != null and pj.live(x) else null, k, 4, fd * 10.0, false)
			sn.extend(0.16)
			pj.after(0.45, func():
				if is_instance_valid(sn):
					sn.retract(0.2))
		pj.after(0.17, func():
			var c2 = cw.get_ref()
			var x2 = tw.get_ref() if tw else null
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
				return
			_venom(x2.global_position + Vector3.UP, 1.6)
			_glint(x2.global_position + Vector3.UP, Color(0.8, 0.6, 1.0), 1.8, 0.16, 6, false)
			Sfx.play("bite", x2.global_position, 0.9)
			x2.take_hit(pj.inf(c2, id, 1.6, {"knock": 22.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.1, "poison": 3.0, "dir": fd}))))


## Konoha Kanransha (ref: alttan tekme anında dışa açılan ak çarpma çizgileri, toz bulutu): iki tekme — çarpma çizgileri,
## omuzlara binip taklalar: ikisinin çevresinde dikey dönen "dönme dolap" çemberi + savrulan yapraklar; yere çakılış: krater
static func konoha_kanransha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.65)
	var id = "konoha_kanransha"
	pj._jump_at(c, tt, 0.0, 11.0 if tt and tt.global_position.distance_to(c.global_position) > 2.0 else 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	pj._kick_pose(c, 0.25)
	pj.after(0.14, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		Sfx.play("punch", cc.global_position, 1.0)
		var hp = cc.global_position + Vector3.UP * 1.0 + cc.face_dir() * 1.1
		_kick_arc(cc, 1.0)
		var hs = pj.hit(cc, hp, 2.0, pj.inf(cc, id, 0.45, {"knock": 0.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.05}))
		if hs.size() > 0:
			_impact_lines(hs[0].global_position + Vector3.UP * 0.9, 22, 0.6, 2.6, 0.22)
		_puffs(_ground(cc.global_position) + Vector3.UP * 0.2, {"n": 8, "life": 0.6, "r": 0.5, "vmin": 1.0, "vmax": 2.5, "spread": 60.0, "flat": 0.5,
			"grav": Vector3(0, 0.3, 0), "damp": 2.0, "size": 0.9, "cols": [Color(0.85, 0.8, 0.7, 0.6), Color(0.7, 0.64, 0.55, 0)]}))
	pj.after(0.38, func():   # ikinci tekme: daha yükseğe
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or not pj.live(cc):
			return
		if cc is CharacterBody3D:
			cc.velocity = Vector3.UP * 9.0
		pj._kick_pose(cc, 0.25)
		_kick_arc(cc, -1.0)
		if x != null and pj.live(x):
			Sfx.play("punch", x.global_position, 1.1)
			x.take_hit(pj.inf(cc, id, 0.45, {"knock": 0.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.05}))
			_impact_lines(x.global_position + Vector3.UP * 0.9, 30, 0.7, 3.4, 0.26)
			var um = _trail(Color(1, 1, 1, 0.95), Color(0.75, 0.88, 0.7, 0.5), 0.3)
			for n in 3:
				var off = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
				_streak(x.global_position + off, x.global_position + off + Vector3.UP * 4.0, 0.07, um, 0.12, 0.0, 0.18, {"tail": 0.5, "n": 8}))
	var ride = {"on": false}
	pj.after(0.62, func():   # omuzlarına atlar
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		ride["on"] = true
		pj.st(x, "bind", 1.0)
		pj.anim(cc, "crouch", 1.4))
	var wheel_m = _trail(Color(1, 1, 0.97, 0.95), Color(0.6, 0.82, 0.5, 0.7), 0.35)
	var flip = func(i, k):   # taklalarla yere çakar: ikisi birlikte döner, alçalır
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or x == null or not pj.live(cc) or not pj.live(x) or not ride["on"]:
			return
		var g: Vector3 = pj.gp(x.global_position)
		var h = lerpf(4.5, 0.6, k)
		x.global_position = Vector3(x.global_position.x, g.y + h, x.global_position.z)
		cc.global_position = x.global_position + Vector3.UP * (float(x.height) if "height" in x else 1.7) * 0.85
		for n in [cc, x]:
			if n is CharacterBody3D:
				n.velocity = Vector3.ZERO
		if x.get("model"):
			x.model.rotation.x = k * TAU * 2.0
		if cc.get("model"):
			cc.model.rotation.x = k * TAU * 2.0
		if i % 3 == 0:   # dönme dolap: ikisinin çevresinde dikey çember
			var fd: Vector3 = cc.face_dir()
			var cen = x.global_position + Vector3.UP * 1.3
			var a0 = k * TAU * 2.0
			var wdir = func(u: float, _p: Vector3) -> Vector3:
				var a = a0 + u * 1.8
				return Vector3.UP * cos(a) + fd * sin(a)
			var wpath = func(u: float) -> Vector3:
				var a = a0 + u * 1.8
				return cen + (Vector3.UP * cos(a) + fd * sin(a)) * 1.6
			_ribbon(wpath, 0.4, wheel_m, 0.06, 0.0, 0.2, {"tail": 1.0, "taper": 0.9, "n": 12, "wfn": wdir})
		if i % 5 == 0:
			_puffs(x.global_position + Vector3.UP * 1.0, {"n": 5, "life": 0.9, "r": 1.4, "vmin": 1.0, "vmax": 3.0, "spread": 180.0,
				"grav": Vector3(0, -1.5, 0), "damp": 1.0, "size": Vector2(0.16, 0.09), "s0": 1.0, "s1": 0.8, "spin": 400.0, "leaf": true,
				"cols": [LEAF_G, LEAF_G.darkened(0.3), Color(0.6, 0.8, 0.35, 0)]})
	pj.after(0.64, func(): pj.every(0.6, 0.03, flip, func():
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		ride["on"] = false
		for n in [cc, x]:
			if n != null and is_instance_valid(n) and n.get("model"):
				n.model.rotation.x = 0.0
		if cc == null or not pj.live(cc):
			return
		if x != null and pj.live(x):
			var at: Vector3 = pj.gp(x.global_position)
			cc.global_position = at - cc.face_dir() * 1.3   # üstünden iner
			# baş aşağı çakılış: krater, çatlak, toz duvarı, çarpma çizgileri
			_cracks(at, 3.5, 8, 4.0)
			_mark(_ground(at), 1.6, 0.0, _ringm(Color(0.3, 0.23, 0.17, 0.75), Color(0.22, 0.17, 0.12, 0.6)), 3.0, 1.0)
			_ring(_ground(at) + Vector3.UP * 0.05, Vector3.UP, 0.6, 5.0, 0.7, _ringm(Color(0.85, 0.78, 0.64, 0.8), Color(0.66, 0.57, 0.45, 0.6), 0.45), 0.45)
			_chunks(at + Vector3.UP * 0.3, 14, PathJutsu.EARTH, 9.0, 0.24)
			_puffs(at + Vector3.UP * 0.4, {"n": 22, "life": 1.1, "r": 1.0, "vmin": 2.0, "vmax": 5.0, "spread": 75.0, "flat": 0.3,
				"grav": Vector3(0, -0.5, 0), "damp": 2.0, "size": 1.4, "s0": 0.4, "s1": 1.5,
				"cols": [Color(0.86, 0.8, 0.68, 0.85), Color(0.7, 0.63, 0.52, 0.55), Color(0.62, 0.55, 0.45, 0)]})
			_impact_lines(at + Vector3.UP * 0.8, 34, 0.9, 4.2, 0.3)
			_puffs(at + Vector3.UP * 0.8, {"n": 10, "life": 1.2, "r": 0.8, "vmin": 2.0, "vmax": 4.0, "spread": 120.0,
				"grav": Vector3(0, -1.2, 0), "damp": 1.0, "size": Vector2(0.16, 0.09), "s0": 1.0, "s1": 0.8, "spin": 400.0, "leaf": true,
				"cols": [LEAF_G, LEAF_G.darkened(0.3), Color(0.6, 0.8, 0.35, 0)]})
			pj.shake(0.8)
			Sfx.play("boom", at, 1.0)
			x.take_hit(pj.inf(cc, id, 2.2, {"knock": 2.0, "launch": 0.0, "kind": "heavy", "stun": 1.2, "hitstop": 0.12}))))


## Kanransha tekme yayı: ayağın çizdiği dikey hız izi (isabet olmasa da görünür) + yaprak kıpırtısı
static func _kick_arc(cc: Node3D, sg: float) -> void:
	var fd: Vector3 = cc.face_dir()
	var sd = fd.cross(Vector3.UP).normalized()
	var km = _trail(Color(1, 1, 0.96, 1), Color(0.55, 0.8, 0.45, 0.8), 0.35)
	_slash(cc.global_position + Vector3.UP * 1.0 + sd * 0.15 * sg, fd, Vector3.UP, 0.0, 1.25, -1.3, 1.45, 0.34, km, 0.07, 0.03, 0.18, {"tail": 0.8, "taper": 0.95, "n": 14})
	_puffs(cc.global_position + Vector3.UP * 1.2 + fd * 0.8, {"n": 5, "life": 0.8, "r": 0.5, "vmin": 1.0, "vmax": 3.0, "dir": Vector3.UP, "spread": 90.0,
		"grav": Vector3(0, -1.5, 0), "damp": 1.0, "size": Vector2(0.16, 0.09), "s0": 1.0, "s1": 0.8, "spin": 400.0, "leaf": true,
		"cols": [LEAF_G, LEAF_G.darkened(0.3), Color(0.6, 0.8, 0.35, 0)]})


## Jarangeki (ref: kunai kesiğinde altın-turuncu parlama, üstünden geçen ince mavi çizgi; açık kahve pullu yılan sürüsü):
## altın kesikler + mavi kesme çizgisi, çift diz, sonunda iki bilekten altı yılan — zehirli ısırık
static func jarangeki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	pj.busy(c, 1.6)
	var id = "jarangeki"
	pj._jump_at(c, tt, 0.0, 12.0 if tt and tt.global_position.distance_to(c.global_position) > 2.0 else 1.0)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var gold_m = _trail(Color(1, 0.98, 0.85, 1), Color(1.0, 0.62, 0.15, 0.9), 0.3, true)
	var blue_m = _trail(Color(0.55, 0.65, 1.0, 1), Color(0.15, 0.25, 0.95, 0.9), 0.4)
	var seq = [["slash_a", 0.1, 0.3], ["slash_b", 0.26, 0.3], ["knee", 0.46, 0.45], ["slash_a", 0.7, 0.3], ["slash_c", 0.86, 0.5]]
	for k in seq.size():
		pj.after(float(seq[k][1]), func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var x = tw.get_ref() if tw else null
			var f: Vector3 = pj._face(cc, x) if x != null and pj.live(x) else cc.face_dir()
			if x != null and pj.live(x) and cc is CharacterBody3D:
				cc.velocity = f * clampf((cc.global_position.distance_to(x.global_position) - 1.2) / 0.12, 0.0, 14.0)
			var knee = String(seq[k][0]) == "knee"
			var sd = f.cross(Vector3.UP).normalized()
			if knee:   # çift diz: sıçrayıp iki dizle
				if cc is CharacterBody3D:
					cc.velocity += Vector3.UP * 6.0
				pj.anim(cc, "crouch", 2.2)
				Sfx.play("punch", cc.global_position, 0.95)
			else:
				pj.anim(cc, String(seq[k][0]), 2.6)
				var sg = 1.0 if k % 2 == 0 else -1.0
				_slash(cc.global_position + Vector3.UP * 1.1, f, sd, 0.12 * sg, 1.5, -1.1 * sg, 1.1 * sg, 0.3, gold_m, 0.06, 0.0, 0.14, {"tail": 0.75, "taper": 0.95, "n": 14})
				var mid = cc.global_position + Vector3.UP * 1.1 + f * 1.2
				var tilt = (sd * sg + Vector3.UP * randf_range(-0.25, 0.25)).normalized()
				_streak(mid - tilt * 1.8, mid + tilt * 1.8, 0.035, blue_m, 0.04, 0.03, 0.15, {"tail": 1.0, "taper": 0.3, "n": 6})
				Sfx.play("slash", cc.global_position, 1.2 + k * 0.05)
			var hs = pj.hit(cc, cc.global_position + Vector3.UP * (1.3 if knee else 1.1) + f * 1.1, 2.0, pj.inf(cc, id, float(seq[k][2]), {"knock": 1.5, "launch": 3.0 if knee else 0.0, "kind": "light", "bleed": 0.0 if knee else 2.0, "hitstop": 0.04}))
			if hs.size() > 0:   # altın parlama yıldızı (ref)
				var hp = hs[0].global_position + Vector3.UP * (1.2 if knee else 1.0)
				_glint(hp, Color(1.0, 0.65, 0.15), 2.2 if knee else 1.7, 0.16, 10)
				if knee:
					_ring(hp, f, 0.3, 1.8, 0.7, _ringm(Color(1, 0.95, 0.8, 0.9), Color(1.0, 0.65, 0.2, 0.6), 0.3, true), 0.2))
	pj.after(1.08, func():   # iki bilekten yılanlar
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		var fd: Vector3 = cc.face_dir()
		pj.anim(cc, "push", 1.8)
		for k in 6:
			var sn = _serpent(pj, cc, k % 2 == 0, x if x != null and pj.live(x) else null, k, 6, fd * 9.0, false)
			sn.extend(0.2 + k * 0.02)
			pj.after(0.6, func():
				if is_instance_valid(sn):
					sn.retract(0.2))
		Sfx.play("whoosh", cc.global_position, 0.7)
		pj.after(0.22, func():
			var c2 = cw.get_ref()
			var x2 = tw.get_ref() if tw else null
			if c2 == null or x2 == null or not pj.live(c2) or not pj.live(x2):
				return
			Sfx.play("bite", x2.global_position, 0.8)
			_poison(pj, c2, x2, id, 1.5, 5.0)
			_venom(x2.global_position + Vector3.UP * 1.2, 1.3)
			x2.take_hit(pj.inf(c2, id, 0.6, {"knock": 14.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.08, "dir": fd}))))


# ================================================================== NAMIKAZE — Hiraishin hızı
## Senkō Enbu: Ten no Dan: tekme ile kaldırış (sarı yay) → üç çatallı kunailer havada beşgen kurar →
## her ışınlanmada sarı çakma, kunai noktasından hedefe sarı-turuncu kesik → tepede belirip saplar: ak-sarı mızrak çizgisi, yere çakılış izi
static func senko_enbu_ten_no_dan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Senkō Enbu: tekmeyle kaldırılacak hedef yok", Color(1.0, 0.9, 0.35))
		return
	pj.busy(c, 1.85)
	var id = "senko_enbu_ten_no_dan"
	var cw = weakref(c)
	var tw = weakref(tt)
	pj._jump_at(c, tt, 0.0, 12.0 if c.global_position.distance_to(tt.global_position) > 2.0 else 1.0)
	pj._kick_pose(c, 0.25)
	var gold_m = _trail(Color(1, 1, 0.9, 1), Color(1.0, 0.72, 0.2, 0.9), 0.3, true)
	pj.after(0.14, func():
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		Sfx.play("punch", x.global_position, 1.0)
		var fd: Vector3 = cc.face_dir()
		_slash(cc.global_position + Vector3.UP * 0.9, fd, fd.cross(Vector3.UP).normalized(), PI * 0.5, 1.3, -1.2, 1.4, 0.3, gold_m, 0.07, 0.0, 0.18, {"tail": 0.8, "n": 12})
		_glint(x.global_position + Vector3.UP * 0.8, FLASH_Y, 1.6, 0.14, 4)
		x.take_hit(pj.inf(cc, id, 0.4, {"knock": 0.0, "launch": 13.0, "kind": "heavy", "hitstop": 0.05})))
	var pts = []
	pj.after(0.3, func():   # havadaki rakibin çevresine kunailer
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		pj.anim(cc, "throw", 2.0)
		var cen: Vector3 = x.global_position + Vector3.UP * 1.0
		var from = pj.hand_pos(cc)
		var thin = _trail(Color(1, 1, 0.9, 0.8), Color(1.0, 0.8, 0.3, 0.4), 0.4, true)
		for k in 5:
			var a = TAU * k / 5.0 + 0.3
			var p = cen + Vector3(cos(a) * 2.6, (k % 2) * 1.2 - 0.4, sin(a) * 2.6)
			pts.append(p)
			var dur = 0.12 + k * 0.02
			var kn = _kunai3()
			_put(kn, from)
			if from.distance_to(p) > 0.05:
				kn.look_at(p, Vector3.UP if absf((p - from).normalized().y) < 0.95 else Vector3.FORWARD)
			var ktw = kn.create_tween()
			ktw.tween_property(kn, "global_position", p, dur)
			ktw.tween_callback(func(): _glint(p, FLASH_Y, 0.7, 0.18, 4))
			ktw.tween_interval(0.25)
			ktw.tween_callback(kn.queue_free)
			_streak(from, p, 0.05, thin, dur, 0.0, 0.15, {"tail": 0.6, "n": 6})
		Sfx.play("kunai", cc.global_position, 1.3))
	for k in 5:   # kunailer arasında ışınlanıp vurur
		pj.after(0.55 + k * 0.16, func():
			var cc = cw.get_ref()
			var x = tw.get_ref()
			if cc == null or x == null or not pj.live(cc) or not pj.live(x) or pts.size() < 5:
				return
			_yellow_step(cc.global_position)
			_hop(cc, pts[k], x)
			_yellow_step(pts[k] - Vector3.UP * 1.0, 0.8)
			if x is CharacterBody3D:
				x.velocity = Vector3.UP * 1.5   # havada asılı kalır
			pj.anim(cc, ["slash_a", "slash_b"][k % 2], 2.6)
			var q: Vector3 = x.global_position + Vector3.UP * 1.0
			var pk: Vector3 = pts[k]
			_streak(pk, q + (q - pk).normalized() * 1.2, 0.2, gold_m, 0.05, 0.02, 0.2, {"tail": 0.8, "taper": 0.9, "n": 8})
			_glint(q, FLASH_Y, 1.3, 0.12, 4)
			Sfx.play("slash", q, 1.2 + k * 0.05)
			x.take_hit(pj.inf(cc, id, 0.38, {"knock": 0.0, "launch": 0.0, "kind": "light", "bleed": 2.0, "hitstop": 0.03})))
	pj.after(1.4, func():   # tepede belirir, kunaiyi saplar
		var cc = cw.get_ref()
		var x = tw.get_ref()
		if cc == null or x == null or not pj.live(cc) or not pj.live(x):
			return
		_yellow_step(cc.global_position)
		var top = x.global_position + Vector3.UP * 2.4
		_hop(cc, top, x)
		_yellow_step(top - Vector3.UP * 1.0, 1.1)
		pj.anim(cc, "slash_c", 2.0)
		var xp = x.global_position
		_streak(top + Vector3.UP * 1.2, xp - Vector3.UP * 0.3, 0.45, _trail(Color(1, 1, 1, 1), Color(1.0, 0.8, 0.25, 0.9), 0.35, true), 0.05, 0.05, 0.3, {"tail": 1.0, "taper": 0.6, "n": 8})
		_glint(xp + Vector3.UP * 1.4, FLASH_Y, 3.0, 0.22, 8)
		_light(xp + Vector3.UP * 1.4, FLASH_Y, 6.0, 9.0, 0.3)
		pj.shake(0.6)
		Sfx.play("slash", x.global_position, 0.8)
		x.take_hit(pj.inf(cc, id, 1.3, {"knock": 2.0, "launch": -16.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.1}))
		if x is CharacterBody3D:
			x.velocity = Vector3.DOWN * 20.0
		var xw = weakref(x)
		pj.after(0.22, func():   # yere çakılış izi
			var x3 = xw.get_ref()
			var gp: Vector3 = _ground(x3.global_position if x3 != null and is_instance_valid(x3) else xp)
			_cracks(gp, 2.6, 7, 3.5)
			_ring(gp + Vector3.UP * 0.05, Vector3.UP, 0.4, 3.6, 0.7, _ringm(Color(1, 0.95, 0.75, 0.85), Color(1.0, 0.75, 0.3, 0.6), 0.4, true), 0.3)
			_chunks(gp + Vector3.UP * 0.3, 10, PathJutsu.EARTH, 7.0, 0.2)
			_puffs(gp + Vector3.UP * 0.3, {"n": 12, "life": 0.9, "r": 0.6, "vmin": 2.0, "vmax": 4.0, "spread": 70.0, "flat": 0.4,
				"grav": Vector3(0, -0.5, 0), "damp": 2.0, "size": 1.1, "s0": 0.4, "s1": 1.4,
				"cols": [Color(0.85, 0.78, 0.64, 0.75), Color(0.66, 0.57, 0.45, 0.4), Color(0.6, 0.52, 0.42, 0)]})))


## Eski _hira_hop (yer=false) ile aynı ışınlanma mekaniği; görüntü çağıranda
static func _hop(who: Node3D, p: Vector3, tgt: Node3D) -> void:
	who.global_position = p
	if who is CharacterBody3D:
		who.velocity = Vector3.ZERO
	if tgt and is_instance_valid(tgt) and "facing" in who:
		var d = tgt.global_position - p
		d.y = 0
		if d.length() > 0.01:
			who.facing = atan2(-d.x, -d.z)
			if who.get("model"):
				who.model.rotation.y = who.facing
	Sfx.play("whoosh", p, 1.6, 0.5)


## Shunraijin (ref: göz kamaştıran ak parlama, ardından kırmızı-turuncu kesik izleri): geçiş hattında ak-sarı hız kaması,
## hedefte kör edici ak patlama + kırmızı X kesik, arkada dönüp kırmızı-ak yay kesik
static func shunraijin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 0.85)
	var id = "shunraijin"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	var a: Vector3 = c.global_position
	var b: Vector3 = (tt.global_position + d * 2.2) if tt else a + d * 9.0
	b = pj.gp(b)
	var wedge = _trail(Color(1, 1, 0.95, 0.95), Color(1.0, 0.9, 0.55, 0.6), 0.35, true)
	for k in 5:   # hız kaması: geçtiği yol boyunca ak-sarı çizgiler (ortadakiler kalın)
		var o = Vector3.UP * (0.4 + k * 0.32)
		var ww = 0.12 if k == 2 or k == 3 else 0.06
		_streak(a + o, b + o, ww, wedge, 0.04, 0.05, 0.3, {"tail": 1.0, "taper": 0.95, "n": 10})
	c.global_position = b
	if c is CharacterBody3D:
		c.velocity = Vector3.ZERO
	var ga = _ground(a)
	_puffs(ga + Vector3.UP * 0.2, {"n": 10, "life": 0.7, "r": 0.4, "vmin": 2.0, "vmax": 5.0, "dir": (Vector3.UP + d).normalized(), "spread": 40.0,
		"grav": Vector3(0, -0.5, 0), "damp": 3.0, "size": 0.9, "s0": 0.4, "s1": 1.4,
		"cols": [Color(0.82, 0.74, 0.6, 0.75), Color(0.66, 0.57, 0.45, 0.4), Color(0.6, 0.52, 0.42, 0)]})
	_puffs(_ground(b) + Vector3.UP * 0.2, {"n": 8, "life": 0.6, "r": 0.4, "vmin": 1.5, "vmax": 3.5, "dir": (Vector3.UP + d).normalized(), "spread": 60.0,
		"grav": Vector3(0, -0.5, 0), "damp": 3.0, "size": 0.7, "cols": [Color(0.82, 0.74, 0.6, 0.6), Color(0.6, 0.52, 0.42, 0)]})
	Sfx.play("whoosh", b, 1.5)
	if tt and pj.live(tt):
		var hp = tt.global_position + Vector3.UP * 1.1
		_glint(hp, Color(1, 1, 0.9), 3.4, 0.2, 8)
		_light(hp, Color(1, 0.97, 0.85), 7.0, 9.0, 0.18)
		var red = _trail(Color(1, 0.9, 0.8, 1), Color(0.95, 0.15, 0.1, 0.95), 0.25)
		var sd = d.cross(Vector3.UP).normalized()
		for s in [-1.0, 1.0]:   # kırmızı X kesik izi
			var dv = (sd * s + Vector3.UP * 0.8).normalized()
			_streak(hp - dv * 0.9, hp + dv * 0.9, 0.16, red, 0.04, 0.2, 0.25, {"tail": 1.0, "taper": 0.5, "n": 6})
		tt.take_hit(pj.inf(c, id, 0.6, {"knock": 3.0, "kind": "heavy", "hitstop": 0.05, "dir": d}))
	pj.after(0.22, func():   # arkasında döner, keser
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var x = tw.get_ref() if tw else null
		if x != null and pj.live(x):
			pj._face(cc, x)
		pj.anim(cc, "slash_b", 2.2)
		var fd: Vector3 = cc.face_dir()
		var q = cc.global_position + Vector3.UP * 1.1 + fd * 1.3
		_slash(cc.global_position + Vector3.UP * 1.15, fd, fd.cross(Vector3.UP).normalized(), 0.0, 1.6, -1.0, 1.0, 0.4,
			_trail(Color(1, 0.97, 0.92, 1), Color(0.95, 0.25, 0.12, 0.9), 0.3), 0.06, 0.03, 0.2, {"tail": 0.85, "taper": 0.95, "n": 14})
		Sfx.play("slash", q, 1.1)
		var hs = pj.hit(cc, q, 2.0, pj.inf(cc, id, 1.8, {"knock": 9.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.09, "pierce_guard": true}))
		if hs.size() > 0:
			var hp2 = hs[0].global_position + Vector3.UP * 1.1
			_glint(hp2, Color(1.0, 0.4, 0.2), 2.2, 0.18, 6)
			_puffs(hp2, {"n": 12, "life": 0.35, "r": 0.2, "vmin": 4.0, "vmax": 8.0, "dir": fd, "spread": 50.0, "grav": Vector3(0, -6, 0), "damp": 3.0,
				"size": 0.08, "s0": 1.0, "s1": 0.1, "add": true, "cols": [Color(1, 0.9, 0.7, 1), Color(1.0, 0.3, 0.15, 0.8), Color(0.8, 0.1, 0.05, 0)]}))


## Chōkōkyaku (ref: tekmeyle yukarı fışkıran turuncu-sarı ışın): alçak sarı atılış izi → diz tekmesinde turuncu yıldız →
## kayarken zeminde iki paralel sürtünme izi + toz → aynı dize: dikey altın ışın sütunu, yerde halka, yükselen kıvılcımlar
static func chokokyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 12.0)
	pj.busy(c, 0.95)
	var id = "chokokyaku"
	var d = pj._face(c, tt)
	var cw = weakref(c)
	var tw = weakref(tt) if tt else null
	if tt:
		var from0 = c.global_position
		c.global_position = pj.gp(tt.global_position - d * 1.0)
		var upw = func(_q: float, _p: Vector3) -> Vector3: return Vector3.UP
		var dm = _trail(Color(1, 1, 0.9, 1), Color(1.0, 0.75, 0.25, 0.7), 0.3, true)
		_streak(from0 + Vector3.UP * 0.4, c.global_position + Vector3.UP * 0.4, 0.2, dm, 0.05, 0.03, 0.25, {"tail": 1.0, "taper": 0.95, "n": 10, "wfn": upw})
	pj._kick_pose(c, 0.2)
	pj.after(0.08, func():   # dize alçak tekme
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var p = cc.global_position + Vector3.UP * 0.5 + cc.face_dir() * 1.0
		Sfx.play("punch", p, 1.2)
		var hs = pj.hit(cc, p, 1.6, pj.inf(cc, id, 0.6, {"knock": 0.0, "kind": "light", "hitstop": 0.05, "slow": 2.0}))
		_glint(p, Color(1.0, 0.6, 0.15), 1.6 if hs.size() > 0 else 0.9, 0.14, 6))
	pj.after(0.3, func():   # kayarak arkasına
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or not pj.live(cc):
			return
		var a: Vector3 = cc.global_position
		var b: Vector3 = pj.gp((x.global_position if x != null and pj.live(x) else a + d * 2.0) + d * 1.0)
		pj.anim(cc, "crouch", 2.0)
		var mt = cc.create_tween()
		mt.tween_property(cc, "global_position", b, 0.14)
		var sd = d.cross(Vector3.UP).normalized()
		for s in [-1.0, 1.0]:   # iki ayağın sürtünme izi
			_gouge(a + sd * 0.18 * s, b + sd * 0.18 * s, 0.14, 3.0, Color(0.5, 0.41, 0.31), Color(0.3, 0.23, 0.17))
		_puffs(_ground(a.lerp(b, 0.5)) + Vector3.UP * 0.15, {"n": 14, "life": 0.7, "pts": _line_pts(a, b, 7, a.lerp(b, 0.5)), "vmin": 1.0, "vmax": 3.0,
			"dir": (Vector3.UP - d * 0.5).normalized(), "spread": 40.0, "grav": Vector3(0, -0.5, 0), "damp": 3.0, "size": 0.7, "s0": 0.4, "s1": 1.3,
			"cols": [Color(0.82, 0.74, 0.6, 0.7), Color(0.66, 0.57, 0.45, 0.4), Color(0.6, 0.52, 0.42, 0)]})
		Sfx.play("step_sand", a, 1.0))
	pj.after(0.5, func():   # aynı dize: havaya uçurur
		var cc = cw.get_ref()
		var x = tw.get_ref() if tw else null
		if cc == null or not pj.live(cc):
			return
		if x != null and pj.live(x):
			pj._face(cc, x)
		pj._kick_pose(cc, 0.3)
		var p = cc.global_position + Vector3.UP * 0.6 + cc.face_dir() * 1.0
		# ışın tekme: yukarı fışkıran altın sütun (geniş yumuşak + ak çekirdek)
		_streak(p, p + Vector3.UP * 7.0, 1.0, _trail(Color(1, 0.92, 0.6, 0.7), Color(1.0, 0.6, 0.15, 0.4), 0.4, true), 0.08, 0.08, 0.4, {"tail": 1.0, "taper": 0.0, "n": 10})
		_streak(p, p + Vector3.UP * 6.0, 0.25, _trail(Color(1, 1, 1, 1), Color(1.0, 0.85, 0.4, 0.8), 0.5, true), 0.06, 0.06, 0.3, {"tail": 1.0, "taper": 0.0, "n": 10})
		_ring(_ground(p) + Vector3.UP * 0.06, Vector3.UP, 0.3, 3.2, 0.72, _ringm(Color(1, 0.95, 0.75, 0.9), Color(1.0, 0.65, 0.2, 0.6), 0.3, true), 0.3)
		_puffs(p, {"n": 20, "life": 0.6, "r": 0.4, "vmin": 5.0, "vmax": 10.0, "dir": Vector3.UP, "spread": 18.0, "grav": Vector3(0, -3.0, 0), "damp": 1.5,
			"size": 0.1, "s0": 1.0, "s1": 0.2, "add": true, "cols": [Color(1, 1, 0.9, 1), Color(1.0, 0.75, 0.25, 0.9), Color(1.0, 0.4, 0.1, 0)]})
		_light(p + Vector3.UP, Color(1.0, 0.8, 0.4), 6.0, 9.0, 0.3)
		pj.shake(0.5)
		Sfx.play("punch", p, 0.8)
		var hs = pj.hit(cc, p, 1.9, pj.inf(cc, id, 1.4, {"knock": 2.0, "launch": 13.0, "kind": "heavy", "hitstop": 0.1}))
		if hs.size() > 0:
			_glint(hs[0].global_position + Vector3.UP * 0.7, Color(1.0, 0.7, 0.2), 2.4, 0.18, 8))


# ================================================================== GEKKŌ — ay ışığı kılıç sanatı
## Mangetsu Senpū: tek dönüşte kapanan dolunay halkası (soluk gümüş-mavi, ak çekirdek), yerde ay yansıması gibi açılan
## soluk ışık dairesi, dört yanda kalıp süzülen hilal artçı görüntüleri, yavaş inen ay tozu
static func gekko_mangetsu_senpu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	var id = "gekko_mangetsu_senpu"
	_moon_blade(pj, c, 0.6, 1.0)
	pj.anim(c, "slash_b", 1.8)
	var f0 = c.facing if "facing" in c else 0.0
	var cw = weakref(c)
	pj.every(0.3, 1.0 / 60.0, func(_i, k):
		var c2 = cw.get_ref()
		if c2 != null and is_instance_valid(c2) and "facing" in c2:
			c2.facing = f0 + TAU * k)
	var cen: Vector3 = c.global_position + Vector3.UP * 1.1
	var a_start = -f0 - PI * 0.5
	var ring_m = _trail(Color(1, 1, 1, 1), Color(MOON.r, MOON.g, MOON.b, 0.85), 0.36)
	var halo_m = _trail(Color(0.92, 0.95, 1.0, 0.45), Color(0.6, 0.7, 1.0, 0.2), 0.5, true)
	var rad_w = func(u: float, _p: Vector3) -> Vector3:
		var a = a_start + u * TAU
		return Vector3(cos(a), 0.0, sin(a))
	for q in 2:
		var rr = 2.4 + q * 0.18
		var hy = q * 0.05
		var rpath = func(u: float) -> Vector3:
			var a = a_start + u * TAU
			return cen + Vector3(cos(a) * rr, hy, sin(a) * rr)
		_ribbon(rpath, 0.3 if q == 0 else 0.7, ring_m if q == 0 else halo_m, 0.3, 0.15, 0.6, {"tail": 1.0, "taper": 0.25, "eat": 0.0, "n": 40, "wfn": rad_w})
	Sfx.play("swing_sword", cen, 1.0)
	# yerde ay yansıması: soluk ışık dairesi açılır, yavaş söner
	var g = _ground(c.global_position)
	_mark(g + Vector3.UP * 0.01, 2.7, 0.0, _ringm(Color(0.85, 0.9, 1.0, 0.0), Color(0.75, 0.82, 1.0, 0.35), 0.0, true), 0.6, 1.0)
	_ring(g + Vector3.UP * 0.02, Vector3.UP, 0.5, 2.8, 0.9, _ringm(Color(1, 1, 1, 0.8), Color(MOON.r, MOON.g, MOON.b, 0.6), 0.0, true), 0.35)
	pj.after(0.3, func():   # dört yanda kalan hilal artçıları + inen ay tozu
		for k in 4:
			var a = a_start + TAU * (k + 0.5) / 4.0
			var dv = Vector3(cos(a), 0, sin(a))
			var tg = Vector3(-sin(a), 0, cos(a))
			var cm = _trail(Color(1, 1, 1, 0.9), Color(0.7, 0.8, 1.0, 0.6), 0.4, true)
			_crescent(cen + dv * 2.4, dv, tg, 0.7, cm, 0.08, 0.25, 0.7, dv * 0.6 + Vector3.UP * 0.2)
		_puffs(cen + Vector3.UP * 0.6, {"n": 22, "life": 1.4, "pts": _ring_pts(2.4, 22), "vmin": 0.1, "vmax": 0.4, "spread": 180.0,
			"grav": Vector3(0, -0.6, 0), "damp": 0.5, "size": 0.08, "s0": 1.0, "s1": 0.2, "add": true,
			"cols": [Color(1, 1, 1, 0.9), Color(MOON.r, MOON.g, MOON.b, 0.7), Color(0.6, 0.7, 1.0, 0)]}))
	pj.after(0.15, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		for e in pj.enemies_near(cc, cc.global_position, 3.0):
			var v: Vector3 = e.global_position - cc.global_position
			v.y = 0
			_glint(e.global_position + Vector3.UP * 1.1, MOON, 1.4, 0.14, 4)
			e.take_hit(pj.inf(cc, id, 1.2, {"knock": 9.0, "kind": "heavy", "bleed": 2.0, "hitstop": 0.06, "dir": v.normalized() if v.length() > 0.1 else cc.face_dir()})))


## Tsukimi Iai ("ay seyri"): çömelip bekler — arkasında soluk dev hilal doğar, ay ışığı zerreleri kılıca akar;
## tek çekişte geçer: önce ince kıl gibi çizgi, bir an sonra kesik açılır (çizgi parlayıp ikiye ayrılır), yol boyunca hilal artçıları
static func gekko_tsukimi_iai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 14.0)
	pj.busy(c, 1.0)
	var id = "gekko_tsukimi_iai"
	var d = pj._face(c, tt)
	pj.anim(c, "crouch", 1.0)
	var cw = weakref(c)
	_hand_aura(pj, c, "RightHand", MOON, 0.5, 0.07, 14)
	_gather(Jutsu._hand(c), MOON, 1.4, 0.45, 6)
	var moon_m = _trail(Color(1, 1, 1, 0.55), Color(0.7, 0.8, 1.0, 0.35), 0.5, true)
	_crescent(c.global_position + Vector3.UP * 3.2 - d * 1.6, Vector3.UP + d * 0.3, -d, 1.5, moon_m, 0.4, 0.3, 0.6, Vector3.UP * 0.4)
	pj.after(0.5, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		_moon_blade(pj, cc, 0.4, 1.1)
		var p0: Vector3 = cc.global_position
		var L = clampf((p0.distance_to(tt.global_position) + 2.0) if tt and is_instance_valid(tt) else 9.0, 4.0, 14.0)
		var p1: Vector3 = pj.gp(p0 + d * L)
		cc.global_position = p1
		if cc is CharacterBody3D:
			cc.velocity = Vector3.ZERO
		pj.anim(cc, "slash_c", 2.4)
		# kıl çizgisi → kesik açılır
		var y0 = Vector3.UP * 1.05
		var hair = _trail(Color(1, 1, 1, 1), Color(MOON.r, MOON.g, MOON.b, 0.8), 0.6)
		_streak(p0 + y0, p1 + y0, 0.04, hair, 0.03, 0.12, 0.15, {"tail": 1.0, "taper": 0.0, "eat": 0.0, "n": 8})
		var cut = _trail(Color(1, 1, 1, 1), Color(0.6, 0.72, 1.0, 0.75), 0.3, true)
		var sdv = d.cross(Vector3.UP).normalized()
		var upw = func(_q: float, _p: Vector3) -> Vector3: return Vector3.UP
		pj.after(0.12, func():
			for s in [-1.0, 1.0]:
				var off = Vector3.UP * 0.06 * s
				var mi = _streak(p0 + y0 + off, p1 + y0 + off, 0.12, cut, 0.02, 0.1, 0.5, {"tail": 1.0, "taper": 0.0, "eat": 0.0, "n": 8, "wfn": upw})
				mi.create_tween().tween_property(mi, "position", Vector3.UP * 0.25 * s, 0.6)
			_light(p0.lerp(p1, 0.5) + y0, MOON, 4.0, L * 0.7, 0.35))
		for k in 3:   # yol boyunca hilal artçıları
			var at = p0.lerp(p1, (k + 1) / 4.0) + Vector3.UP * 1.1
			_crescent(at, d, sdv, 0.85 - k * 0.1, _trail(Color(1, 1, 1, 0.8), Color(0.7, 0.8, 1.0, 0.5), 0.4, true), 0.05, 0.2 + k * 0.08, 0.6, d * 0.5 + Vector3.UP * 0.15)
		_puffs(p0 + y0, {"n": 24, "life": 1.0, "pts": _line_pts(p0 + y0, p1 + y0, 12, p0 + y0), "vmin": 0.1, "vmax": 0.4, "spread": 180.0,
			"grav": Vector3(0, -0.4, 0), "damp": 1.0, "size": 0.07, "s0": 1.0, "s1": 0.1, "add": true, "expl": 0.5,
			"cols": [Color(1, 1, 1, 0.9), Color(MOON.r, MOON.g, MOON.b, 0.6), Color(0.6, 0.7, 1.0, 0)]})
		Sfx.play("swing_sword", p1, 1.5)
		for e in pj.enemies_near(cc, p0.lerp(p1, 0.5), L * 0.5 + 0.5):
			var v: Vector3 = e.global_position - p0
			var along = v.dot(d)
			var perp = v - d * along
			perp.y = 0
			if along > -0.5 and along < L + 0.5 and perp.length() < 1.6:
				_glint(e.global_position + Vector3.UP * 1.1, MOON, 1.8, 0.2, 4)
				e.take_hit(pj.inf(cc, id, 2.0, {"knock": 6.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.12, "pierce_guard": true, "dir": d})))


# ================================================================== GAI — Hirudora
## Hirudora (ref: avuçtan fırlayan, ağzı açık, parlak gözlü ak hava kaplanı): yedinci kapı yeşil buharı → avuçlara çekilen hava →
## sıkışmış havadan kaplan başı (yele arkaya akar), altında zemini yaran oluk + toz → çarpışta patlayan hava küresi, toz duvarı
static func hirudora(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	_gate_cost(c, 0.15)
	pj.busy(c, 1.1)
	pj.anim(c, "push", 1.0)
	var d = pj.fwd(c, t)
	_gather(c.global_position + Vector3.UP * 1.4 + d * 1.0, Color(0.85, 0.92, 1.0), 3.0, 0.35, 12, false)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var from = c.global_position + Vector3.UP * 1.4 + d * 1.6
		var tmat = _air(Color(0.97, 0.98, 1.0, 0.97), Color(0.6, 0.67, 0.8), Color(0.55, 0.75, 1.0), 3.0, 6.0)
		tmat.set_shader_parameter("form", 0.55)   # iki tonlu gövde gölgesi: biçim okunur
		var node = _tiger(1.4 * 0.9, tmat)
		var boom = {"done": false}
		var on_hit = func(pos: Vector3, target: Node3D) -> void:
			if target != null:   # yol üstündeki her hedefte hava çarpması
				_glint(pos, Color(0.85, 0.92, 1.0), 1.2, 0.16, 6)
				_ring(pos, d, 0.6, 2.2, 0.7, _ringm(Color(1, 1, 1, 0.9), Color(0.7, 0.85, 1.0, 0.6), 0.4), 0.25)
				return
			if boom["done"]:
				return
			boom["done"] = true
			_air_burst(pos, d)
		var pr = pj.shot(c, from, d, 24.0, node, pj.inf(c, "hirudora", 2.2, {"knock": 22.0, "launch": 6.0, "kind": "heavy", "hitstop": 0.1}), pj.tg(c, t, 30.0), true, 1.5, on_hit)
		pr.radius = 3.6   # kanon: göl dalgasını yaran dev hava basıncı — dar mermi değil
		node.scale = Vector3.ONE * 0.6 * 1.26
		node.create_tween().tween_property(node, "scale", Vector3.ONE * 1.26, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_glint(from, Color(0.9, 0.95, 1.0), 1.4, 0.14, 8)
		_ring(from - d * 1.0, d, 0.5, 4.0, 0.7, _ringm(Color(1, 1, 1, 0.9), Color(0.7, 0.85, 1.0, 0.6), 0.5), 0.3)
		var mane_m = _trail(Color(1, 1, 1, 0.85), Color(0.7, 0.82, 1.0, 0.5), 0.35)
		var tick = {"t": 0.0}
		pr.on_tick = func(p, dt):   # yele: başın ardından akan hava tutamları
			tick["t"] += dt
			if tick["t"] < 0.05:
				return
			tick["t"] = 0.0
			var hp: Vector3 = p.global_position
			var bk: Vector3 = -p.vel.normalized() if p.vel.length() > 0.1 else -d
			var sd2 = bk.cross(Vector3.UP).normalized()
			for n in 2:
				var off = (sd2 * randf_range(0.9, 1.5) * (1.0 if randf() < 0.5 else -1.0) + Vector3.UP * randf_range(-0.9, 1.3))
				var wob = randf_range(-0.6, 0.6)
				var mpath = func(q: float) -> Vector3: return hp + off * (1.0 + q * 0.4) + bk * (1.4 + q * 4.5) + sd2 * sin(q * 5.0) * wob
				_ribbon(mpath, 0.16, mane_m, 0.08, 0.0, 0.2, {"tail": 0.7, "taper": 0.9, "n": 10})
		var last = {"p": from}
		pj.every(1.5, 0.15, func(_i, _k):
			if is_instance_valid(pr):
				var gpos = pj.gp(pr.global_position)
				_gouge(pj.gp(last["p"]), gpos, 2.2, 4.0)
				last["p"] = pr.global_position
				_chunks(gpos + Vector3.UP * 0.3, 4, PathJutsu.EARTH, 8.0, 0.24, Vector3.UP, 50.0)
				_puffs(gpos + Vector3.UP * 0.3, {"n": 6, "life": 0.8, "r": 1.4, "vmin": 2.0, "vmax": 5.0, "spread": 60.0, "flat": 0.3,
					"grav": Vector3(0, -0.5, 0), "damp": 2.0, "size": 1.2, "s0": 0.4, "s1": 1.4,
					"cols": [Color(0.82, 0.76, 0.64, 0.7), Color(0.66, 0.58, 0.47, 0.4), Color(0.6, 0.52, 0.42, 0)]})
				_ring(pr.global_position, d, 1.5, 4.6, 0.82, _ringm(Color(0.95, 0.98, 1.0, 0.5), Color(0.7, 0.85, 1.0, 0.35), 0.6), 0.25), Callable())
		pj.shake(1.0)
		Sfx.play("wind", from, 0.5)
		Sfx.play("roar", from, 1.3, 0.6))


## Hirudora patlaması: hava küresi şişip dağılır, yerde halka + toz duvarı + moloz, kısa ışık
static func _air_burst(pos: Vector3, d: Vector3) -> void:
	var bm = _air(Color(0.97, 0.98, 1.0, 0.75), Color(0.7, 0.78, 0.9), Color(0.6, 0.8, 1.0), 6.0, 12.0)
	var sp = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 28
	sm.rings = 14
	sp.mesh = sm
	sp.material_override = bm
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(sp, pos)
	sp.scale = Vector3.ONE * 0.8
	var tw = sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE * 6.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(f: float): bm.set_shader_parameter("fade", f), 1.0, 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(sp.queue_free)
	var g = _ground(pos)
	_ring(g + Vector3.UP * 0.06, Vector3.UP, 1.0, 11.0, 0.75, _ringm(Color(0.9, 0.86, 0.76, 0.85), Color(0.68, 0.6, 0.48, 0.6), 0.5), 0.55)
	_ring(pos, d, 1.0, 8.0, 0.8, _ringm(Color(1, 1, 1, 0.8), Color(0.7, 0.85, 1.0, 0.5), 0.4), 0.35)
	_cracks(g, 5.0, 10, 5.0)
	_chunks(g + Vector3.UP * 0.4, 22, PathJutsu.EARTH, 12.0, 0.28, Vector3.UP, 70.0)
	_puffs(g + Vector3.UP * 0.5, {"n": 30, "life": 1.4, "pts": _ring_pts(2.5, 30), "vmin": 3.0, "vmax": 7.0, "dir": Vector3.UP, "spread": 70.0, "flat": 0.4,
		"radial": 3.0, "grav": Vector3(0, -0.6, 0), "damp": 2.0, "size": 1.8, "s0": 0.4, "s1": 1.6,
		"cols": [Color(0.88, 0.84, 0.74, 0.85), Color(0.7, 0.64, 0.53, 0.55), Color(0.62, 0.56, 0.46, 0)]})
	_light(pos, Color(0.9, 0.95, 1.0), 9.0, 16.0, 0.4)
	_glint(pos, Color(0.9, 0.95, 1.0), 5.0, 0.3, 10)
	Sfx.play("boom", pos, 0.9)
