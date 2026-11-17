class_name SuitonFXB
extends RefCounted
## Suiton grubu B: on beş su tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları SuitonLib'den
## (kendi su gölgelendiricisi, damla, birikinti, sis, sabun zarı); her tekniğin şekli, hareketi ve sahnelenmesi kendine özgü.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı, gizlenme tutkunları) eski
## işleyicilerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/suiton_lib.gd")

static var _cache := {}

## Göz kamaştıran parıltı: kameraya dönük dört kollu yıldız + çekirdek (toplamalı)
const GLINT_SHADER := """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled, depth_draw_never;

instance uniform float fade = 1.0;
instance uniform float spin = 0.0;

void vertex() {
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float cs = cos(spin);
	float sn = sin(spin);
	q = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
	float r = length(q);
	float core = smoothstep(0.32, 0.0, r);
	float ax = max(smoothstep(0.07, 0.0, abs(q.y)) * (1.0 - abs(q.x)), smoothstep(0.07, 0.0, abs(q.x)) * (1.0 - abs(q.y)));
	vec2 d = vec2(q.x + q.y, q.x - q.y) * 0.7071;
	float dg = max(smoothstep(0.045, 0.0, abs(d.y)) * (1.0 - abs(d.x) * 1.7), smoothstep(0.045, 0.0, abs(d.x)) * (1.0 - abs(d.y) * 1.7));
	float v = clamp(core + ax + max(dg, 0.0) * 0.55, 0.0, 1.0);
	vec3 col = mix(vec3(1.0, 0.95, 0.75), vec3(1.0), core);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = v * fade;
}
"""


# ------------------------------------------------------------------ ortak küçük yardımcılar
static func _c(key: String, build: Callable):
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func _mouth(c: Node3D) -> Vector3:
	return c.global_position + Vector3.UP * 1.55 + c.face_dir() * 0.4


static func _side(c: Node3D) -> Vector3:
	return c.face_dir().cross(Vector3.UP).normalized()


static func _up_for(d: Vector3) -> Vector3:
	return Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT


## Kalıcı sabun zarı (kendi ömrünü sahibi yönetir)
static func _skin(size: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = L.sphere_mesh()
	mi.material_override = L.bubble_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.scale = Vector3.ONE * size
	return mi


static func _glint_mat() -> ShaderMaterial:
	return _c("glint", func():
		var sh = Shader.new()
		sh.code = GLINT_SHADER
		var m = ShaderMaterial.new()
		m.shader = sh
		return m)


static func _glint(size: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = L.quad_mesh()
	mi.material_override = _glint_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("spin", randf() * TAU)
	mi.scale = Vector3.ONE * size
	return mi


static func _unlit(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if col.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = emit
	return m


## Kısa ömürlü ışık patlaması
static func _flash(h: Node, pos: Vector3, col: Color, energy: float, rng: float, t: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	L.put(h, l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Hedef yüzeyine dik açılan ince su halkası (ses duvarı / delinme halkası)
static func _ring_burst(h: Node, pos: Vector3, normal: Vector3, r0: float, r1: float, t: float, o := {}) -> void:
	var mi = L.wmi(L.ring_mesh(), {"alpha": o.get("alpha", 0.8), "foam": o.get("foam", 0.6), "pal": o.get("pal", 0.0), "line": 0.0})
	L.put(h, mi, pos)
	var n = normal.normalized()
	mi.look_at(pos + n, _up_for(n))
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)   # halkanın düzlemi normale dik
	mi.scale = Vector3(r0, 1.0, r0)
	var tw = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(r1, 0.5, r1), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, t).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


# ------------------------------------------------------------------ meshler (bu grubun kendi şekilleri)
## Mürekkep yıldızı: merkezden çıkan kırık uçlu sivri lekeler (ref: Ink Bubble Explosion)
static func _ink_star_mesh() -> ArrayMesh:
	return _c("ink_star", func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 9137
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = 0
		for k in 16:
			var d = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var ln = rng.randf_range(1.5, 2.2) if k % 3 == 0 else rng.randf_range(0.6, 1.4)
			var w = rng.randf_range(0.16, 0.3)
			var sd = d.cross(_up_for(d)).normalized()
			var kink = sd * rng.randf_range(-0.14, 0.14)
			vc = L.tube_into(sf, vc, [Vector3.ZERO, d * ln * 0.3 + kink * 0.5, d * ln * 0.65 + kink, d * ln], [w, w * 0.72, w * 0.36, 0.0], 5, 0.4, sd)
		vc = L.tube_into(sf, vc, [Vector3(0, -0.5, 0), Vector3(0, -0.32, 0), Vector3.ZERO, Vector3(0, 0.32, 0), Vector3(0, 0.5, 0)], [0.0, 0.34, 0.5, 0.34, 0.0], 10)
		sf.generate_normals()
		return sf.commit())


## İnce ışık / su çizgisi: 0'dan +Z 1'e incelen tüp (birim; ölçekle uzatılır)
static func _streak_mesh() -> ArrayMesh:
	return _c("streak", func():
		return L.tube_mesh([Vector3.ZERO, Vector3(0, 0, 0.12), Vector3(0, 0, 0.55), Vector3(0, 0, 1.0)], [0.7, 1.0, 0.45, 0.0], 6))


## Yağmur çizgisi parçacığı (Y ekseninde)
static func _rain_mesh() -> ArrayMesh:
	return _c("rain", func():
		return L.tube_mesh([Vector3(0, -0.5, 0), Vector3(0, 0.0, 0), Vector3(0, 0.5, 0)], [0.012, 0.022, 0.0], 4))


## Denizanası çanı: -Z tepe, +Z açık ağız (ref: Raging Jellyfish — koyu mavi kubbe, açık kenar)
static func _bell_mesh() -> ArrayMesh:
	return _c("bell", func():
		var pts = [Vector3(0, 0, 0.3), Vector3(0, 0, 0.16), Vector3(0, 0, -0.05), Vector3(0, 0, -0.28), Vector3(0, 0, -0.44), Vector3(0, 0, -0.53), Vector3(0, 0, -0.56)]
		return L.tube_mesh(pts, [0.6, 0.7, 0.66, 0.54, 0.34, 0.14, 0.0], 18))


## Dalgalı, uzun dokunaç: 0'dan +Z'ye
static func _tentacle_mesh(v: int, ln: float, w: float) -> ArrayMesh:
	return _c("tent_%d_%d_%d" % [v, int(ln * 10), int(w * 100)], func():
		var pts = []
		var rad = []
		for j in 12:
			var u = j / 11.0
			pts.append(Vector3(sin(u * 5.0 + v * 1.7) * 0.28 * u, cos(u * 4.0 + v * 2.3) * 0.22 * u, u * ln))
			rad.append(w * (1.0 - u * 0.85))
		return L.tube_mesh(pts, rad, 6))


## Su ejderi başı: -Z burun, +Z boyun (birim boy ~3.3). Kafatası, açık alt çene, kaş, boynuz, yele dikenleri, bıyık, dişler.
static func _dragon_head_mesh() -> ArrayMesh:
	return _c("dragon_head", func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = 0
		# kafatası + burun (yassı, geniş ekseni yatay)
		vc = L.tube_into(sf, vc, [Vector3(0, 0.0, 1.3), Vector3(0, 0.12, 0.5), Vector3(0, 0.08, -0.3), Vector3(0, -0.02, -1.1), Vector3(0, -0.08, -1.75), Vector3(0, -0.1, -2.05)],
			[0.95, 1.0, 0.8, 0.56, 0.38, 0.06], 14, 0.72, Vector3.RIGHT)
		# alt çene (aşağı açık)
		vc = L.tube_into(sf, vc, [Vector3(0, -0.42, 0.4), Vector3(0, -0.6, -0.4), Vector3(0, -0.82, -1.15), Vector3(0, -0.95, -1.6)], [0.5, 0.4, 0.26, 0.04], 10, 0.6, Vector3.RIGHT)
		for sx in [-1.0, 1.0]:
			# kaş çıkıntısı
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.32, 0.5, -0.75), Vector3(sx * 0.5, 0.62, -0.3), Vector3(sx * 0.62, 0.7, 0.2)], [0.08, 0.16, 0.05], 6)
			# boynuz: geriye ve yukarı kıvrık
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.38, 0.62, 0.35), Vector3(sx * 0.6, 1.1, 1.1), Vector3(sx * 0.82, 1.45, 1.9), Vector3(sx * 0.95, 1.55, 2.6)], [0.2, 0.15, 0.09, 0.0], 6)
			# bıyık: burundan yanlara savrulan uzun su teli
			vc = L.tube_into(sf, vc, [Vector3(sx * 0.3, -0.15, -1.7), Vector3(sx * 0.9, -0.25, -1.4), Vector3(sx * 1.6, -0.45, -0.6), Vector3(sx * 2.1, -0.4, 0.6), Vector3(sx * 2.3, -0.2, 1.6)],
				[0.07, 0.06, 0.045, 0.03, 0.0], 5)
			# yanak yeleleri: geriye taranan sivri tutamlar
			for j in 3:
				var y0 = -0.2 + j * 0.3
				vc = L.tube_into(sf, vc, [Vector3(sx * 0.7, y0, 0.3), Vector3(sx * (1.15 + j * 0.15), y0 - 0.1, 1.2), Vector3(sx * (1.5 + j * 0.2), y0 - 0.25 + j * 0.1, 2.2)], [0.22, 0.12, 0.0], 5, 0.5)
			# dişler
			for j in 3:
				var z = -1.6 + j * 0.35
				vc = L.tube_into(sf, vc, [Vector3(sx * 0.24, -0.3, z), Vector3(sx * 0.24, -0.52, z - 0.03), Vector3(sx * 0.24, -0.7, z - 0.05)], [0.08, 0.05, 0.0], 4)
		# tepe yelesi: ortadan geriye uzanan diken dizisi
		for j in 5:
			var x = (j - 2) * 0.22
			vc = L.tube_into(sf, vc, [Vector3(x, 0.7, 0.6 + absf(x)), Vector3(x * 1.8, 1.25, 1.7), Vector3(x * 2.4, 1.5 - absf(x), 2.9)], [0.2, 0.12, 0.0], 5, 0.55)
		sf.generate_normals()
		return sf.commit())


## Su seddi: kullanıcıyı saran yuvarlak, akışkan su duvarı — GERÇEK boyutta örülür (ölçekle gerilmez, yüzler sivrilmez).
## Gövde hafif burgulu ve yumuşak dalgalı; üst kenarı dışa kıvrılıp yuvarlak bir köpük dudağı olur. İki yüzlü, UV.y yukarı akar.
const WALL_H := 5.2


static func _wall_ring(u: float, a: float) -> Vector3:
	var ht = 1.0 + 0.07 * sin(a * 3.0 + 1.3)
	var aa = a + u * 0.6
	var rr = 2.5 - 0.3 * u + 0.07 * sin(a * 4.0 + u * 5.0)
	return Vector3(cos(aa) * rr, u * WALL_H * ht, sin(aa) * rr)


static func _wall_mesh() -> ArrayMesh:
	return _c("wall2", func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs = 64
		var body_rows = 22
		var curl = 5
		var rows = body_rows + curl
		var vc = 0
		for flip in [false, true]:
			for r in rows:
				for s2 in segs + 1:
					var a = s2 * TAU / segs
					var q: Vector3
					var v: float
					if r < body_rows:
						var u = float(r) / (body_rows - 1)
						q = _wall_ring(u, a)
						v = u * 0.85
					else:
						# üst dudak: dışa ve aşağı kıvrılan yuvarlak kenar
						var top = _wall_ring(1.0, a)
						var ph = float(r - body_rows + 1) / curl * 2.4
						var out = Vector3(top.x, 0.0, top.z).normalized()
						q = top + out * (0.42 * (1.0 - cos(ph))) + Vector3.UP * (0.42 * sin(ph))
						v = 0.85 + 0.15 * float(r - body_rows + 1) / curl
					sf.set_uv(Vector2(float(s2) / segs * 6.0, v))
					sf.add_vertex(q)
			for r in rows - 1:
				for s2 in segs:
					var a0 = vc + r * (segs + 1) + s2
					var u0 = a0 + segs + 1
					if flip:
						sf.add_index(a0)
						sf.add_index(a0 + 1)
						sf.add_index(u0)
						sf.add_index(a0 + 1)
						sf.add_index(u0 + 1)
						sf.add_index(u0)
					else:
						sf.add_index(a0)
						sf.add_index(u0)
						sf.add_index(a0 + 1)
						sf.add_index(a0 + 1)
						sf.add_index(u0)
						sf.add_index(u0 + 1)
			vc += rows * (segs + 1)
		sf.generate_normals()
		return sf.commit())


## Duvar yüzeyinde dolanan sıvı akış şeridi (gerçek boyut, yuvarlak kesit)
static func _wall_streak_mesh(ph: float) -> ArrayMesh:
	var pts = []
	var rad = []
	var n = 40
	for i in n:
		var u = float(i) / (n - 1)
		var a = ph + u * 0.8 * TAU
		var q = _wall_ring(u * 0.97, a - u * 0.6)
		var o = Vector3(q.x, 0.0, q.z).normalized()
		pts.append(q + o * 0.08)
		rad.append(0.09 * pow(absf(sin(PI * u)), 0.5) + 0.01)
	return L.tube_mesh(pts, rad, 8)


## Dudak boyunca kabaran köpük halkası (kapalı, dalgalı)
static func _wall_lip_mesh() -> ArrayMesh:
	return _c("wall_lip", func():
		var pts = []
		var rad = []
		var n = 49
		for i in n:
			var a = float(i) / (n - 1) * TAU
			var top = _wall_ring(1.0, a)
			var out = Vector3(top.x, 0.0, top.z).normalized()
			pts.append(top + out * 0.42 + Vector3.UP * (0.3 + 0.12 * sin(a * 6.0)))
			rad.append(0.3 + 0.08 * sin(a * 9.0 + 0.7))
		return L.tube_mesh(pts, rad, 10))


## Kullanıcı silueti biçiminde su sütunu (dikey; tabandan baş hizasına)
static func _body_col_mesh() -> ArrayMesh:
	return _c("body_col", func():
		return L.tube_mesh([Vector3(0, 0.0, 0), Vector3(0, 0.25, 0), Vector3(0, 0.8, 0), Vector3(0, 1.25, 0), Vector3(0, 1.5, 0), Vector3(0, 1.62, 0), Vector3(0, 1.82, 0), Vector3(0, 1.92, 0)],
			[0.62, 0.4, 0.34, 0.4, 0.3, 0.15, 0.2, 0.0], 14))


# ================================================================== 1. Hōmatsu Tadayoi — süzülen köpük mayınları
## Ağızdan köpük solunur; sekiz köpük mayını (zar + süt beyazı köpük çekirdeği + çevresinde dönen uydu kabarcıklar)
## kullanıcıdan çevreye süzülür, yerinde salınır. Değen düşmanda köpük bombası gibi kabarıp patlar; süre bitince söner.
static func homatsu_tadayoi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var mouth = _mouth(c)
	L.spray(pj, mouth, c.face_dir() + Vector3.UP * 0.4, {"n": 16, "spread": 40.0, "vmin": 1.5, "vmax": 3.5, "life": 0.55, "smin": 0.1, "smax": 0.2,
		"g": Vector3(0, -1.5, 0), "damp": 2.0, "foam": 0.85, "alpha": 0.8})
	for i in 8:
		var b = Node3D.new()
		var p0 = c.global_position + Vector3(randf_range(-5, 5), randf_range(1.0, 2.5), randf_range(-5, 5))
		pj.scene_add(b, p0)
		var vis = _foam_mine(b)
		vis.position = mouth - p0   # ağızdan çıkıp yerine süzülür
		vis.scale = Vector3.ONE * 0.2
		var tv = vis.create_tween().set_parallel(true)
		tv.tween_property(vis, "position", Vector3.ZERO, 0.45 + i * 0.04).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tv.tween_property(vis, "scale", Vector3.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var ph = randf() * TAU
		pj.every(8.0, 0.1, func(_ii, k):
			if not is_instance_valid(b):
				return
			b.global_position = p0 + Vector3(sin(k * 6.0 + ph) * 0.8, sin(k * 9.0 + ph) * 0.3, cos(k * 5.0 + ph) * 0.8)
			for e in pj.enemies_near(c, b.global_position, 1.4):
				if pj.live(e):
					_foam_mine_burst(pj, b.global_position)
					pj.hit(c, b.global_position, 2.2, pj.inf(c, "homatsu_tadayoi", 0.6, {"knock": 6.0, "kind": "heavy", "element": "suiton"}))
					b.queue_free()
					return, func():
			if is_instance_valid(b):
				_foam_mine_fizzle(pj, b))
	Sfx.play("water", c.global_position, 1.6)


static func _foam_mine(b: Node3D) -> Node3D:
	var vis = Node3D.new()
	b.add_child(vis)
	vis.add_child(_skin(0.95))
	var core = L.wmi(L.sphere_mesh(), {"alpha": 0.28, "foam": 0.7, "wob": 1.4, "flow": 0.6, "line": 0.0})
	core.scale = Vector3.ONE * 0.38
	vis.add_child(core)
	var orbit = Node3D.new()
	vis.add_child(orbit)
	for j in 3:
		var a = j * TAU / 3.0
		var sat = _skin(randf_range(0.18, 0.28))
		sat.position = Vector3(cos(a) * 0.62, sin(a * 2.0) * 0.18, sin(a) * 0.62)
		orbit.add_child(sat)
	var tw = orbit.create_tween().set_loops()
	tw.tween_property(orbit, "rotation:y", TAU, 2.2 + randf() * 0.8).from(0.0)
	var tw2 = core.create_tween().set_loops()
	tw2.tween_property(core, "scale", Vector3.ONE * 0.44, 0.5).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(core, "scale", Vector3.ONE * 0.34, 0.5).set_trans(Tween.TRANS_SINE)
	# ince köpük tozu bırakır
	L.trail(vis, {"n": 6, "life": 0.8, "dir": Vector3.DOWN, "spread": 60.0, "vmin": 0.1, "vmax": 0.35, "g": Vector3(0, -0.6, 0),
		"smin": 0.05, "smax": 0.09, "foam": 1.0, "alpha": 0.6, "r": 0.35})
	return vis


static func _foam_mine_burst(pj: PathJutsu, p: Vector3) -> void:
	# köpük kabuğu şişip yırtılır
	var shell = L.wmi(L.sphere_mesh(), {"alpha": 0.75, "foam": 0.75, "wob": 2.0, "line": 0.1, "flow": 3.0})
	L.put(pj, shell, p)
	shell.scale = Vector3.ONE * 0.7
	var tw = shell.create_tween().set_parallel(true)
	tw.tween_property(shell, "scale", Vector3.ONE * 2.8, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): shell.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3).set_delay(0.06)
	tw.chain().tween_callback(shell.queue_free)
	L.bubble_pop(pj, p, 0.9)
	L.spray(pj, p, Vector3.UP, {"n": 26, "spread": 180.0, "vmin": 3.0, "vmax": 7.5, "life": 0.6, "smin": 0.1, "smax": 0.22, "foam": 1.0, "alpha": 0.9, "damp": 1.5})
	var g = L.ground(p)
	if p.y - g.y < 3.0:
		L.ripple(pj, g, 0.4, 2.6, 0.55, {"foam": 1.0})
		L.puddle(pj, g, 1.1, 0.8, {"foam": 0.7, "alpha": 0.5, "ripple": 0.2})


static func _foam_mine_fizzle(pj: PathJutsu, b: Node3D) -> void:
	var p = b.global_position
	var tw = b.create_tween()
	tw.tween_property(b, "scale", Vector3(1.15, 0.6, 1.15), 0.12)
	tw.tween_property(b, "scale", Vector3.ONE * 0.05, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		L.bubble_pop(pj, p, 0.5)
		b.queue_free())


# ================================================================== 2. Sumi Awa Bakuhatsu — mürekkep köpüğü patlaması
## Ağızda mürekkep toplanır; dört sabun zarının içi kara mürekkeple dolu (ref) yelpaze gibi uçar. Çarpınca
## kırık uçlu kara mürekkep yıldızı açılır, ardında görüşü kapatan kara mürekkep bulutu ve damlaları kalır.
static func sumi_awa_bakuhatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 20.0)
	L.gather(pj, pj._mouth_pos(c), 0.6, 8, 0.2, 0.2, L.INK)
	for k in 4:
		pj.after(0.2 + k * 0.08, func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c)
			var m = _ink_bubble(0.62)
			pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, (k - 1.5) * 0.12), 16.0, m, pj.inf(c, "sumi_awa_bakuhatsu", 0.25, {"knock": 2.0, "kind": "light", "element": "suiton"}), tt, false, 1.8, func(p, _h):
				_ink_burst(pj, p)
				for e in pj.enemies_near(c, p, 3.0):
					if e.has_method("lose_target"):
						e.lose_target(3.0)))
	Sfx.play("water", c.global_position, 1.5)


static func _ink_bubble(s: float) -> Node3D:
	var m = Node3D.new()
	var ink = L.wmi(L.sphere_mesh(), {"pal": L.INK, "alpha": 0.96, "wob": 1.4, "flow": 0.4, "line": 0.0, "foam": 0.12})
	ink.scale = Vector3(s * 0.88, s * 0.8, s * 0.88)
	ink.position = Vector3(0, -s * 0.04, 0)   # mürekkep zarın alt kısmında ağırlaşır
	m.add_child(ink)
	m.add_child(_skin(s))
	L.trail(m, {"n": 6, "life": 0.45, "dir": Vector3(0, -0.4, 1), "spread": 20.0, "vmin": 0.3, "vmax": 0.8, "g": Vector3(0, -7, 0),
		"smin": 0.05, "smax": 0.1, "pal": L.INK, "alpha": 0.9, "r": s * 0.3})
	return m


static func _ink_burst(pj: PathJutsu, p: Vector3) -> void:
	var star = L.wmi(_ink_star_mesh(), {"pal": L.INK, "alpha": 1.0, "line": 0.0, "wob": 0.6, "flow": 0.3})
	L.put(pj, star, p)
	star.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	star.scale = Vector3.ONE * 0.2
	var tw = star.create_tween()
	tw.tween_property(star, "scale", Vector3.ONE * 1.35, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_interval(0.14)
	tw.tween_property(star, "scale", Vector3.ONE * 1.6, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float): star.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(star.queue_free)
	L.bubble_pop(pj, p, 0.62)
	L.spray(pj, p, Vector3.UP, {"n": 20, "spread": 180.0, "vmin": 2.5, "vmax": 6.0, "life": 0.7, "smin": 0.1, "smax": 0.2, "pal": L.INK, "alpha": 1.0, "line": 0.0})
	# görüşü kapatan mürekkep bulutu (kameraya yakınken incelir)
	for j in 3:
		L.mist(pj, p + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.5), randf_range(-0.6, 0.6)), randf_range(2.2, 3.0), 1.7,
			{"tone": 2.0, "alpha": 0.75, "near": 3.5, "drift": Vector3(randf_range(-0.4, 0.4), 0.35, randf_range(-0.4, 0.4)), "fin": 0.1, "fout": 0.5})
	var g = L.ground(p)
	if p.y - g.y < 3.5:
		L.puddle(pj, g, 1.3, 2.0, {"pal": L.INK, "alpha": 0.85, "ripple": 0.0})


# ================================================================== 3. Sekken Awa — sabun köpüğü balçığı
## Elden zemine sabunlu köpük akar ve hedefin altında kaygan, yeşilimsi sabun balçığı serilir (ref: Soap Bubble Slime).
## Üstünde sabun kabarcıkları kabarıp patlar; içindekiler yavaşlar, ara ara kayıp savrulur (taban izinden balçık dişleri sıçrar).
static func sekken_awa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	_slime_run(pj, pj.gp(c.global_position + c.face_dir() * 0.8), at)
	L.puddle(pj, at, 4.3, 5.0, {"pal": L.SOAP, "alpha": 0.8, "ripple": 0.12, "foam": 0.3, "spread": 0.55, "lift": 0.04})
	L.puddle(pj, at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 2.4, 5.0, {"pal": L.SOAP, "alpha": 0.55, "ripple": 0.0, "foam": 0.6, "spread": 0.7, "lift": 0.06})
	pj.every(5.0, 0.3, func(i, _k):
		var q = L.ground(at + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
		L.bubble(pj, q + Vector3.UP * 0.12, randf_range(0.18, 0.42), randf_range(0.6, 1.3), Vector3(randf_range(-0.1, 0.1), 0.35, randf_range(-0.1, 0.1)), true)
		for e in pj.enemies_near(c, at, 4.0):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("slow", 0.6)
				if i % 3 == 0:
					L.spray(pj, e.global_position + Vector3.UP * 0.35, Vector3.DOWN, {"n": 4, "spread": 40.0, "vmin": 0.5, "vmax": 1.5, "life": 0.4,
						"smin": 0.08, "smax": 0.14, "pal": L.SOAP, "alpha": 0.9, "r": 0.3})
				if i % 5 == 0:
					var sh = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
					e.global_position += sh
					_slip(pj, e.global_position, sh), Callable())
	Sfx.play("water", at, 1.6)


static func _slime_run(pj: PathJutsu, a: Vector3, b: Vector3) -> void:
	var d = b - a
	d.y = 0.0
	var n = clampi(int(d.length() / 1.1), 1, 18)
	var dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	for j in n:
		var p = a + d * (float(j) / n)
		pj.after(j * 0.025, func():
			L.puddle(pj, p, randf_range(0.45, 0.6), 1.0, {"pal": L.SOAP, "alpha": 0.7, "ripple": 0.0, "foam": 0.4, "dir": dir, "stretch": 1.8, "spread": 0.2}))


## Kayma: tabandan yana fırlayan balçık dişleri + uzayan kayma izi
static func _slip(pj: PathJutsu, p: Vector3, sh: Vector3) -> void:
	var g = L.ground(p)
	var d = sh.normalized() if sh.length() > 0.01 else Vector3.FORWARD
	L.spray(pj, g + Vector3.UP * 0.1, (d + Vector3.UP * 0.6).normalized(), {"n": 10, "spread": 35.0, "vmin": 2.0, "vmax": 4.5, "life": 0.45,
		"smin": 0.12, "smax": 0.22, "pal": L.SOAP, "alpha": 0.95, "foam": 0.4})
	L.puddle(pj, g - d * 0.5, 0.6, 1.0, {"pal": L.SOAP, "alpha": 0.75, "ripple": 0.0, "foam": 0.5, "dir": d, "stretch": 2.6, "spread": 0.15, "lift": 0.07})
	L.bubble(pj, g + Vector3.UP * 0.25, 0.3, 0.5, Vector3(0, 0.8, 0), true)


# ================================================================== 4. Mekura Awa — göz kamaştıran köpükler
## Avuçta ışık toplanır; içinde parlak çekirdek taşıyan altı küçük köpük hedefin yüzüne süzülür ve
## gözünün önünde tek tek patlayıp dört kollu beyaz ışık parıltısı saçar.
static func mekura_awa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 20.0)
	var hp = pj.hand_pos(c, true)
	var g0 = _glint(0.15)
	L.put(pj, g0, hp)
	var tg0 = g0.create_tween()
	tg0.tween_property(g0, "scale", Vector3.ONE * 0.7, 0.2).set_ease(Tween.EASE_OUT)
	tg0.tween_method(func(v: float): g0.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.12)
	tg0.tween_callback(g0.queue_free)
	pj.after(0.2, func():
		if not pj.live(c) or not tt:
			return
		for k in 6:
			var b = _glare_bubble(0.35)
			pj.scene_add(b, pj.hand_pos(c, true))
			var tw = b.create_tween()
			tw.tween_property(b, "global_position", tt.global_position + Vector3.UP * 1.6 + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4)), 0.4 + k * 0.05)
			tw.tween_callback(func():
				_glare_pop(pj, b.global_position)
				b.queue_free())
		pj.after(0.55, func():
			if pj.live(tt) and tt.has_method("lose_target"):
				tt.lose_target(4.0)))
	Sfx.play("water", c.global_position, 1.7)


static func _glare_bubble(s: float) -> Node3D:
	var b = Node3D.new()
	var core = MeshInstance3D.new()
	core.mesh = L.sphere_mesh()
	core.material_override = _c("glare_core", func(): return _unlit(Color(1.0, 0.97, 0.82), 2.5))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * s * 0.32
	b.add_child(core)
	b.add_child(_skin(s))
	var gl = _glint(s * 1.6)
	gl.set_instance_shader_parameter("fade", 0.55)
	b.add_child(gl)
	return b


static func _glare_pop(pj: PathJutsu, p: Vector3) -> void:
	_flash(pj, p, Color(1, 1, 0.9), 4.0, 6.0, 0.15)
	var gl = _glint(0.3)
	L.put(pj, gl, p)
	var tw = gl.create_tween()
	tw.tween_property(gl, "scale", Vector3.ONE * 2.4, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): gl.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.28).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): gl.set_instance_shader_parameter("spin", v), 0.0, 0.5, 0.28)
	tw.tween_callback(gl.queue_free)
	L.bubble_pop(pj, p, 0.35)


# ================================================================== 5. Suiton Kakuremino — suya gömülme
## Beden kendi boyunda bir su sütununa dönüşüp birikintiye çöker (kenara çalkantı halkası); gizlenirken yerde
## yalnız soluk, halkalanan bir su lekesi kalır. Süre bitince kullanıcı yerden fışkıran su sütunuyla çıkıp çevresini savurur.
static func suiton_kakuremino(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	_melt_into_water(pj, c)
	if c is Player:
		Buffs.add("suiton_kakuremino", 6.0, {"stealth": 1.0})
	var m = c.get("model")
	if m:
		m.visible = false
	pj.after(6.0, func():
		if is_instance_valid(c):
			var mm = c.get("model")
			if mm:
				mm.visible = true
			_water_emerge(pj, pj.gp(c.global_position))
			pj.hit(c, c.global_position + Vector3.UP, 2.6, pj.inf(c, "suiton_kakuremino", 0.6, {"knock": 8.0, "launch": 4.0, "kind": "heavy", "element": "suiton"})))
	Sfx.play("water", c.global_position, 1.0)


static func _melt_into_water(pj: PathJutsu, c: Node3D) -> void:
	var g = L.ground(c.global_position)
	var col = L.wmi(_body_col_mesh(), {"alpha": 0.85, "wob": 1.8, "flow": -2.0, "foam": 0.15, "line": 0.12})
	L.put(pj, col, g)
	col.rotation.y = randf() * TAU
	var tw = col.create_tween()
	tw.tween_property(col, "scale", Vector3(1.15, 0.85, 1.15), 0.12)
	tw.tween_property(col, "scale", Vector3(2.0, 0.03, 2.0), 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(func(v: float): col.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.38).set_ease(Tween.EASE_IN)
	tw.tween_callback(col.queue_free)
	pj.after(0.4, func():
		L.ripple(pj, g, 0.6, 2.8, 0.6, {"foam": 0.8})
		L.spray(pj, g + Vector3.UP * 0.1, Vector3.UP, {"n": 18, "spread": 75.0, "vmin": 1.5, "vmax": 3.5, "life": 0.5, "smin": 0.1, "smax": 0.2, "foam": 0.3}))
	# gizlenme süresince soluk birikinti (halkalanır)
	L.puddle(pj, g, 1.3, 5.6, {"alpha": 0.32, "ripple": 0.7, "spread": 0.5})


static func _water_emerge(pj: PathJutsu, g: Vector3) -> void:
	var gy = L.wmi(L.geyser_mesh(), {"alpha": 0.88, "foam": 0.45, "wob": 1.2, "flow": -3.0, "line": 0.12})
	L.put(pj, gy, g)
	gy.scale = Vector3(2.6, 0.05, 2.6)
	var tw = gy.create_tween()
	tw.tween_property(gy, "scale", Vector3(2.8, 3.6, 2.8), 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(gy, "scale", Vector3(3.6, 0.2, 3.6), 0.45).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): gy.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(gy.queue_free)
	L.crown(pj, g, 1.7, {"h": 1.3, "foam": 0.55})
	L.spray(pj, g + Vector3.UP * 0.6, Vector3.UP, {"n": 34, "spread": 55.0, "vmin": 5.0, "vmax": 10.0, "life": 0.85, "smin": 0.16, "smax": 0.32, "foam": 0.3})
	L.ripple(pj, g, 0.5, 4.2, 0.7, {"foam": 1.0})
	L.puddle(pj, g, 2.2, 1.6, {"alpha": 0.55, "ripple": 0.6})


# ================================================================== 6. Mizufusen — su balonu
## Ayak dibindeki birikintiden ince bir su sapı avuca yükselip koparak bir su balonu şişirir (ref: saplı köpükler);
## çalkalanan balon damlalar akıtarak hedefe süzülür ve çarpınca su küresi patlayıp çevresini su altında bırakır.
static func mizufusen_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 22.0)
	var from = pj.hand_pos(c, true)
	_balloon_stem(pj, c, from)
	var m = _balloon()
	var pr = pj.shot(c, from, (pj.aim_at(c, tt, from) + Vector3.UP * 0.25).normalized(), 18.0, m, pj.inf(c, "mizufusen_no_jutsu", 0.8, {"knock": 9.0, "kind": "heavy", "element": "suiton"}), tt, false, 1.8, func(p, _h):
		_balloon_burst(pj, p)
		pj.hit(c, p, 3.0, pj.inf(c, "mizufusen_no_jutsu", 0.4, {"knock": 9.0, "kind": "heavy", "element": "suiton"})))
	pr.homing_turn = 2.0
	m.scale = Vector3.ONE * 0.3
	var tw = m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var age = {"t": 0.0}
	pr.on_tick = func(_p: Projectile, dt: float) -> void:
		age["t"] += dt
		if age["t"] > 0.22 and is_instance_valid(m):
			var w = sin(age["t"] * 13.0) * 0.09
			m.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w * 0.5)
	Sfx.play("water", c.global_position, 1.3)


static func _balloon() -> Node3D:
	var m = Node3D.new()
	var water = L.wmi(L.sphere_mesh(), {"alpha": 0.82, "wob": 2.2, "flow": 1.2, "foam": 0.14, "line": 0.13})
	water.scale = Vector3.ONE * 0.95
	m.add_child(water)
	m.add_child(_skin(1.04))
	var knot = L.wmi(L.drop_mesh(), {"alpha": 0.85, "line": 0.12})
	knot.scale = Vector3.ONE * 0.45
	knot.position = Vector3(0, 0, 0.42)
	m.add_child(knot)
	L.trail(m, {"n": 10, "life": 0.55, "dir": Vector3(0, -1, 0.5), "spread": 25.0, "vmin": 0.4, "vmax": 1.4, "g": Vector3(0, -12, 0),
		"smin": 0.1, "smax": 0.18, "alpha": 0.85, "r": 0.35})
	return m


static func _balloon_stem(pj: PathJutsu, c: Node3D, hand: Vector3) -> void:
	var g = L.ground(c.global_position + c.face_dir() * 0.4)
	L.puddle(pj, g, 0.9, 0.5, {"alpha": 0.6, "ripple": 0.8, "spread": 0.15})
	var d = hand - g
	if d.length() < 0.2:
		return
	var st = L.wmi(L.strand_mesh(), {"alpha": 0.8, "flow": -4.0, "line": 0.12})
	L.put(pj, st, g)
	st.look_at(hand, _up_for(d))
	st.scale = Vector3(1.0, 1.0, d.length())
	var tw = st.create_tween()
	tw.tween_interval(0.08)
	tw.tween_property(st, "scale", Vector3(0.15, 0.15, d.length()), 0.2).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): st.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.2)
	tw.tween_callback(st.queue_free)
	L.spray(pj, hand, Vector3.DOWN, {"n": 6, "spread": 25.0, "vmin": 0.5, "vmax": 1.5, "life": 0.35, "smin": 0.08, "smax": 0.14})


static func _balloon_burst(pj: PathJutsu, p: Vector3) -> void:
	var shell = L.wmi(L.sphere_mesh(), {"alpha": 0.72, "wob": 2.0, "foam": 0.3, "line": 0.1, "flow": 3.0})
	L.put(pj, shell, p)
	shell.scale = Vector3.ONE
	var tw = shell.create_tween().set_parallel(true)
	tw.tween_property(shell, "scale", Vector3(4.8, 3.6, 4.8), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): shell.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.32).set_delay(0.05)
	tw.chain().tween_callback(shell.queue_free)
	L.bubble_pop(pj, p, 1.0)
	L.spray(pj, p, Vector3.UP, {"n": 38, "spread": 180.0, "vmin": 4.0, "vmax": 10.0, "life": 0.75, "smin": 0.18, "smax": 0.38, "g": Vector3(0, -16, 0), "foam": 0.2})
	var g = L.ground(p)
	if p.y - g.y < 3.5:
		L.crown(pj, g, 1.8, {"h": 1.0, "foam": 0.4})
		L.puddle(pj, g, 3.0, 2.5, {"alpha": 0.6, "ripple": 0.6})
		L.ripple(pj, g, 0.6, 4.6, 0.7, {"foam": 1.0})


# ================================================================== 7. Ame Kakure — yağmura karışma
## Kullanıcının üstüne dar bir yağmur sütunu iner, beden yukarıdan aşağı yağmur damlalarına çözülüp
## yere akar; yerde yağmur halkaları. Süre bitince yerdeki damlalar yukarı akıp bedeni yeniden kurar.
static func ame_kakure(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	var raining = Game.world != null and String(Game.world.env.get("weather")).contains("yağmur")
	var dur = 10.0 if raining else 5.0
	_rain_dissolve(pj, c)
	if c is Player:
		Buffs.add("ame_kakure", dur, {"stealth": 1.0})
	var m = c.get("model")
	if m:
		m.visible = false
		pj.after(dur, func():
			if is_instance_valid(m):
				m.visible = true
				if is_instance_valid(c):
					_rain_reform(pj, c))
	Sfx.play("water", c.global_position, 1.2)


static func _rain_column(pj: PathJutsu, top: Vector3, ext: Vector3, n: int, t: float) -> GPUParticles3D:
	var p = L.particles({"n": n, "life": 0.45, "dir": Vector3.DOWN, "spread": 3.0, "vmin": 15.0, "vmax": 19.0, "g": Vector3(0, -10, 0),
		"smin": 0.8, "smax": 1.3, "mesh": _rain_mesh(), "one_shot": false, "burst": 0.0, "alpha": 0.75, "line": 0.0, "foam": 0.0})
	var pm = p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	L.put(pj, p, top)
	p.emitting = true
	pj.after(t, func():
		if is_instance_valid(p):
			p.emitting = false)
	L.free_later(pj, p, t + 0.6)
	return p


static func _rain_dissolve(pj: PathJutsu, c: Node3D) -> void:
	var base = c.global_position
	var g = L.ground(base)
	_rain_column(pj, base + Vector3.UP * 6.0, Vector3(0.9, 0.3, 0.9), 50, 0.6)
	# beden yukarıdan aşağıya damlalara çözülür
	for j in 4:
		var y = 1.8 - j * 0.45
		pj.after(j * 0.06, func():
			L.spray(pj, base + Vector3.UP * y, Vector3.DOWN, {"n": 12, "spread": 14.0, "vmin": 1.5, "vmax": 4.0, "life": 0.5, "g": Vector3(0, -20, 0),
				"smin": 0.12, "smax": 0.2, "r": 0.35, "alpha": 0.85, "line": 0.12}))
	L.puddle(pj, g, 1.1, 1.2, {"alpha": 0.45, "ripple": 1.0, "spread": 0.4})
	for j in 7:
		pj.after(0.1 + j * 0.1, func():
			L.ripple(pj, g + Vector3(randf_range(-1.4, 1.4), 0, randf_range(-1.4, 1.4)), 0.05, randf_range(0.4, 0.7), 0.45, {"foam": 0.8, "alpha": 0.7}))


static func _rain_reform(pj: PathJutsu, c: Node3D) -> void:
	var g = L.ground(c.global_position)
	L.spray(pj, g + Vector3.UP * 0.05, Vector3.UP, {"n": 22, "spread": 10.0, "vmin": 4.0, "vmax": 7.0, "life": 0.35, "g": Vector3(0, -4, 0),
		"smin": 0.1, "smax": 0.18, "r": 0.4, "alpha": 0.85})
	L.gather(pj, c.global_position + Vector3.UP * 1.0, 1.2, 14, 0.3, 0.0)
	L.ripple(pj, g, 0.3, 1.8, 0.5, {"foam": 0.9})


# ================================================================== 8. Suiton Suijinheki — su seddi (Jutsu otomatik yüklemesi)
## Ağızdan yere su püskürür; yerden kullanıcının çevresinde dönerek yükselen, üst kenarı dalga kırığı olan kalın bir su seddi
## kalkar (ref: Water Encampment Wall); yüzeyinde koyu mavi burgu çizgileri döner, tepeden damla saçar, tabanda çalkantı halkaları.
static func suiton_suijinheki(js, c: Node3D, _t: Node3D) -> void:
	Sfx.play("water", c.global_position, 0.9)
	var dur = 2.4
	_wall_fx(js, c, dur)
	var tw = js.create_tween()
	for i in 16:
		tw.tween_callback(func():
			if not is_instance_valid(c):
				return
			for pr in js.get_tree().get_nodes_in_group("projectiles"):
				if pr.shooter != c and not pr.dead and pr.global_position.distance_to(c.global_position + Vector3.UP) < 4.0:
					if pr.element() == "":
						pr.block()
						continue
					# su kalkanı: ateşi söndürür; toprak/ağaç/yıldırım gibi üstün elementler geçebilir
					var r = Elements.clash({"el": "suiton", "pow": 30.0 * js._mult(c)}, {"el": pr.element(), "pow": pr.power()})
					_wall_clash(js, pr.global_position, c, String(r.get("effect", "")))
					pr.apply_clash(r["b_alive"], r["b_scale"])
			Combat.hit_sphere(c, c.global_position + Vector3.UP, 3.6, {"dmg": 2.0, "element": "suiton", "knock": 10.0, "kind": "light"}))
		tw.tween_interval(0.15)
	if c is Player:
		c.combat.invuln = 0.6


static func _wall_fx(js, c: Node3D, dur: float) -> void:
	var gy0 = Game.jutsu_floor(c.global_position.x, c.global_position.z)
	# ağızdan yere püskürme
	var mouth = _mouth(c)
	var land = Vector3(mouth.x, gy0, mouth.z) + c.face_dir() * 1.3
	var mid = mouth.lerp(land, 0.5) + c.face_dir() * 0.6
	var spew = L.wmi(L.tube_mesh([mouth, mouth.lerp(mid, 0.5) + Vector3.UP * 0.1, mid, mid.lerp(land, 0.6), land], [0.1, 0.16, 0.24, 0.32, 0.45], 10), {"alpha": 0.88, "flow": 4.0, "foam": 0.2, "line": 0.12})
	L.put(js, spew, Vector3.ZERO)
	L.fade_free(spew, 0.3, 0.25)
	L.spray(js, land, Vector3.UP, {"n": 14, "spread": 60.0, "vmin": 2.0, "vmax": 4.5, "life": 0.5, "smin": 0.12, "smax": 0.22, "foam": 0.3})
	var root = Node3D.new()
	L.put(js, root, Vector3(c.global_position.x, gy0, c.global_position.z))
	# ana sed: yerin altından yükselir (gerilmez); kameraya 6 m içinde saydamlaşır
	var rise = Node3D.new()
	root.add_child(rise)
	rise.position.y = -WALL_H - 0.6
	var near_o = {"near": 1.0, "neard": 9.0}
	var wall = L.wmi(_wall_mesh(), {"alpha": 0.42, "flow": 2.4, "foam": 0.0, "wob": 0.8, "line": 0.1, "streak": 0.5, "near": 1.0, "neard": 9.0})   # büyük yüzeyde iri leke olmasın, kamera arkadan görsün
	rise.add_child(wall)
	# yüzeyde dolanan sıvı akış şeritleri (köpüklü açık su)
	for k in 3:
		var st = L.wmi(_wall_streak_mesh(k * TAU / 3.0), {"alpha": 0.85, "flow": 5.0, "foam": 0.45, "wob": 0.6, "line": 0.1, "streak": 2.0})
		L.setp(st, near_o)
		rise.add_child(st)
	# yuvarlak köpük dudağı
	var lip = L.wmi(_wall_lip_mesh(), {"alpha": 0.9, "foam": 0.8, "wob": 1.4, "flow": 2.0, "line": 0.12})
	L.setp(lip, near_o)
	rise.add_child(lip)
	var follow = root.create_tween()
	follow.tween_method(func(u: float):
		if is_instance_valid(c):
			root.global_position = Vector3(c.global_position.x, gy0, c.global_position.z)
		var e = L.env(u, 0.45 / (dur + 0.45), 0.45 / (dur + 0.45))
		rise.position.y = (-WALL_H - 0.6) * (1.0 - e)
		rise.rotation.y = u * 4.0
		lip.rotation.y = -u * 1.5, 0.0, 1.0, dur + 0.45)
	follow.tween_callback(root.queue_free)
	L.puddle(js, Vector3(c.global_position.x, gy0, c.global_position.z), 4.2, dur, {"alpha": 0.55, "ripple": 1.0, "foam": 0.2, "spread": 0.3})
	for q in 8:
		js.get_tree().create_timer(0.4 + q * 0.25).timeout.connect(func():
			if not is_instance_valid(root):
				return
			var a = randf() * TAU
			var rim = root.global_position + Vector3(cos(a) * 2.7, WALL_H + 0.3, sin(a) * 2.7)
			L.spray(js, rim, Vector3(cos(a), 0.9, sin(a)), {"n": 10, "spread": 30.0, "vmin": 3.0, "vmax": 6.0, "life": 0.7, "smin": 0.15, "smax": 0.3, "foam": 0.4})
			if q % 2 == 0:
				L.ripple(js, root.global_position, 2.6, 4.2, 0.6, {"foam": 1.0}))


## Seddin mermiyi yuttuğu nokta: buhar (ateşle) ya da su tokadı
static func _wall_clash(js, p: Vector3, c: Node3D, effect: String) -> void:
	var out = (p - (c.global_position + Vector3.UP)).normalized()
	L.spray(js, p, out + Vector3.UP * 0.4, {"n": 16, "spread": 50.0, "vmin": 3.0, "vmax": 7.0, "life": 0.5, "smin": 0.14, "smax": 0.26, "foam": 0.5})
	if effect == "steam":
		for j in 3:
			L.mist(js, p + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.6), randf_range(-0.5, 0.5)), randf_range(2.0, 3.0), 1.6,
				{"tone": 0.0, "alpha": 0.6, "near": 4.0, "drift": Vector3(0, 1.4, 0), "fin": 0.1, "fout": 0.6})
		Sfx.play("fire", p, 0.6, 0.5)
	Sfx.play("water", p, 1.4)


# ================================================================== 9. Mujin Meisai — tozsuz gizlenme
## Kullanıcının bedeni saydamlaşarak silinir (ref: Mū'nun görünmezliği): beden soluklaşırken çevresindeki hava ince
## parıltılarla titrer, yerde tek sessiz halka. Görünür olurken ters yönde yavaşça belirir.
static func mujin_meisai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# oynanış: JutsuEngine'in "stealth" biçiminden taşındı (Data'daki tier'e göre süre, yakın düşmanlar izi kaybeder)
	var d: Dictionary = Data.jutsu.get("mujin_meisai", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	_vanish(pj, c, minf(dur, 4.0))
	Sfx.play("poof", c.global_position)


static func _geos(m: Node) -> Array:
	var out = []
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		out.append(n)
	return out


static func _vanish(pj: PathJutsu, c: Node3D, hide_t: float) -> void:
	var m = c.get("model")
	var g = L.ground(c.global_position)
	L.ripple(pj, g, 0.3, 2.2, 0.8, {"foam": 0.5, "alpha": 0.35})
	# havada ince parıltı titremesi
	L.spray(pj, c.global_position + Vector3.UP * 1.0, Vector3.UP, {"n": 18, "spread": 180.0, "vmin": 0.2, "vmax": 0.7, "life": 0.9, "g": Vector3(0, 0.4, 0),
		"smin": 0.04, "smax": 0.08, "r": 0.7, "alpha": 0.35, "pal": L.FROST, "line": 0.0})
	if not m:
		return
	var geos = _geos(m)
	var orig = {}
	for gi in geos:
		orig[gi] = gi.transparency
	var tw = m.create_tween()
	tw.tween_method(func(v: float):
		for gi in geos:
			if is_instance_valid(gi):
				gi.transparency = lerpf(float(orig[gi]), 1.0, v), 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(m):
			m.visible = false)
	pj.get_tree().create_timer(hide_t).timeout.connect(func():
		if is_instance_valid(c) and is_instance_valid(m):
			m.visible = true
			var tb = m.create_tween()
			tb.tween_method(func(v: float):
				for gi in geos:
					if is_instance_valid(gi):
						gi.transparency = lerpf(1.0, float(orig[gi]), v), 0.0, 1.0, 0.45).set_ease(Tween.EASE_OUT))


# ================================================================== 10. Tenkyū — gök ağlaması
## Dudaklarda tek damla sıkışır, ağızda ince bir ses halkası açılır ve iğne gibi tek bir su damlası arkasında
## uzun beyaz ışık çizgisiyle (koyu kenarlı) hedefi deler; delik noktasında küçük delinme halkası + geri saçılan damla.
static func tenkyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.4)
	var tt = pj.tg(c, t, 30.0)
	var from = pj._mouth_pos(c)
	var dir = pj.aim_at(c, tt, from)
	var holder = _needle_drop()
	pj.shot(c, from, dir, 80.0, holder, pj.inf(c, "tenkyu", 1.2, {"knock": 2.0, "kind": "heavy", "element": "suiton", "bleed": 3.0, "hitstop": 0.06}), null, true, 0.6, func(p, _h):
		_needle_pierce(pj, p, dir))
	_ring_burst(pj, from + dir * 0.25, dir, 0.08, 0.55, 0.16, {"alpha": 0.7, "foam": 0.9})
	L.spray(pj, from, dir, {"n": 5, "spread": 8.0, "vmin": 5.0, "vmax": 9.0, "life": 0.25, "smin": 0.05, "smax": 0.08, "g": Vector3.ZERO})
	Sfx.play("whoosh", from, 2.2, 0.4)


static func _needle_drop() -> Node3D:
	var h = Node3D.new()
	var drop = L.wmi(L.drop_mesh(), {"alpha": 1.0, "line": 0.3, "pal": L.FROST, "flow": 4.0})
	drop.scale = Vector3(0.18, 0.18, 0.5)
	h.add_child(drop)
	var dark = MeshInstance3D.new()
	dark.mesh = _streak_mesh()
	dark.material_override = _c("tenkyu_dark", func(): return _unlit(Color(0.1, 0.16, 0.3, 0.55)))
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dark.scale = Vector3(0.075, 0.075, 4.2)
	dark.position = Vector3(0, 0, 0.15)
	h.add_child(dark)
	var lite = MeshInstance3D.new()
	lite.mesh = _streak_mesh()
	lite.material_override = _c("tenkyu_lite", func(): return _unlit(Color(0.94, 0.98, 1.0, 0.95), 1.5))
	lite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lite.scale = Vector3(0.04, 0.04, 4.0)
	lite.position = Vector3(0, 0, 0.12)
	lite.sorting_offset = 0.1
	h.add_child(lite)
	return h


static func _needle_pierce(pj: PathJutsu, p: Vector3, dir: Vector3) -> void:
	_ring_burst(pj, p, dir, 0.05, 0.6, 0.18, {"alpha": 0.85, "foam": 1.0})
	L.spray(pj, p, -dir + Vector3.UP * 0.3, {"n": 10, "spread": 28.0, "vmin": 2.5, "vmax": 6.0, "life": 0.35, "smin": 0.06, "smax": 0.12})
	L.spray(pj, p, dir, {"n": 6, "spread": 12.0, "vmin": 6.0, "vmax": 11.0, "life": 0.3, "smin": 0.05, "smax": 0.09, "g": Vector3(0, -6, 0)})


# ================================================================== 11. Kōmu Kekkaijutsu — kızıl sis bariyeri
## Ağızdan sis üflenir; kurşuni-mavi yoğun sis (ref) halka hâlinde dışa yuvarlanıp alanı sarar,
## yedi saniye boyunca katman katman kabarır. İçindekiler yavaşlar ve yönünü şaşırır.
static func komu_kekkaijutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var at = c.global_position + pj.fwd(c, t) * 5.0
	_mist_exhale(pj, c, at)
	_mist_roll(pj, at)
	pj.every(7.0, 0.25, func(_i, _k):
		L.mist(pj, at + Vector3(randf_range(-6, 6), randf_range(0.6, 2.4), randf_range(-6, 6)), randf_range(3.8, 5.6), 2.5,
			{"tone": 3.0, "alpha": 0.62, "near": 5.0, "drift": Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5)), "fin": 0.3, "fout": 0.4, "s0": 0.7})
		for e in pj.enemies_near(c, at, 7.0):
			pj.st(e, "slow", 0.6)
			if e.has_method("lose_target"):
				e.lose_target(1.0), Callable())
	Sfx.play("genjutsu", at, 0.6)


static func _mist_exhale(pj: PathJutsu, c: Node3D, at: Vector3) -> void:
	var a = _mouth(c)
	var b = at + Vector3.UP * 1.0
	for j in 6:
		var u = float(j) / 5.0
		pj.after(j * 0.05, func():
			L.mist(pj, a.lerp(b, u), 0.8 + u * 2.4, 1.2, {"tone": 3.0, "alpha": 0.55, "near": 3.0, "fin": 0.15, "fout": 0.5, "drift": (b - a).normalized() * 1.2}))


static func _mist_roll(pj: PathJutsu, at: Vector3) -> void:
	for k in 14:
		var a = k * TAU / 14.0 + randf_range(-0.1, 0.1)
		var d = Vector3(cos(a), 0, sin(a))
		L.mist(pj, at + d * 1.0 + Vector3.UP * randf_range(0.8, 1.6), randf_range(2.6, 3.6), 1.7,
			{"tone": 3.0, "alpha": 0.6, "near": 4.5, "drift": d * 5.8, "fin": 0.12, "fout": 0.45, "grow": 0.8, "s0": 0.5})


# ================================================================== 12. Suiton Amefuribari — yağmur iğneleri
## Kullanıcının elinden göğe su fışkırır, hedefin üstünde kara bir yağmur bulutu toplanır; buluttan sağanak
## yağarken içinden gümüş parlaklığında, koyu kenarlı su iğneleri (ref) iner; yere saplanan her iğne küçük bir damla taçı açar.
static func suiton_amefuribari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	_rain_cloud(pj, c, at)
	for k in 50:
		pj.after(0.3 + randf() * 1.2, func():
			var r = 1.2 if k % 2 == 0 else 4.5   # yarısı hedefin hemen üstüne yoğunlaşır
			var base = tt.global_position if (pj.live(tt) and k % 2 == 0) else at
			var q = Vector3(base.x, at.y, base.z) + Vector3(randf_range(-r, r), 11.0, randf_range(-r, r))
			var nd = _rain_needle(k % 5 == 0)
			pj.shot(c, q, (pj.gp(q) + Vector3.UP * 0.8 - q).normalized(), 40.0, nd, pj.inf(c, "suiton_amefuribari", 0.05, {"knock": 0.3, "kind": "light", "element": "suiton", "bleed": 1.0}), null, false, 0.4, func(p, _h):
				_needle_land(pj, p, k)))
	Sfx.play("water", at, 1.4)


static func _rain_cloud(pj: PathJutsu, c: Node3D, at: Vector3) -> void:
	L.spray(pj, c.global_position + Vector3.UP * 2.0, Vector3.UP, {"n": 22, "spread": 7.0, "vmin": 15.0, "vmax": 21.0, "life": 0.7, "g": Vector3(0, -3, 0),
		"smin": 0.14, "smax": 0.24, "alpha": 0.85})
	for j in 8:
		var a = j * TAU / 8.0
		var p = at + Vector3(cos(a) * randf_range(1.0, 4.0), 12.0 + randf_range(-0.6, 0.6), sin(a) * randf_range(1.0, 4.0))
		L.mist(pj, p, randf_range(5.5, 7.5), 2.4, {"tone": 2.0, "alpha": 0.78, "near": 6.0, "fin": 0.12, "fout": 0.3, "s0": 0.3, "grow": 0.25,
			"drift": Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))})
	pj.after(0.25, func():
		_rain_column(pj, at + Vector3.UP * 11.0, Vector3(4.5, 0.4, 4.5), 120, 1.3))


static func _rain_needle(trail: bool) -> Node3D:
	var h = Node3D.new()
	var nd = L.wmi(L.spike_mesh(), {"pal": L.FROST, "alpha": 1.0, "line": 0.38, "flow": 5.0})
	nd.scale = Vector3(0.055, 0.055, 0.24)
	h.add_child(nd)
	if trail:
		var s = MeshInstance3D.new()
		s.mesh = _streak_mesh()
		s.material_override = _c("rain_streak", func(): return _unlit(Color(0.85, 0.92, 1.0, 0.5), 0.6))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.scale = Vector3(0.03, 0.03, 1.8)
		s.position = Vector3(0, 0, 0.5)
		h.add_child(s)
	return h


static func _needle_land(pj: PathJutsu, p: Vector3, k: int) -> void:
	L.spray(pj, p + Vector3.UP * 0.05, Vector3.UP, {"n": 4, "spread": 40.0, "vmin": 1.2, "vmax": 2.6, "life": 0.3, "smin": 0.05, "smax": 0.09})
	if k % 3 == 0:
		L.ripple(pj, p, 0.05, 0.6, 0.4, {"foam": 0.8, "alpha": 0.7})


# ================================================================== 13. Suiton Abare Kurage — kudurmuş denizanası
## Havada su yoğunlaşır ve dört koyu mavi, saydam denizanası belirir (ref): parlak kenarlı kubbe çan, uzun dalgalı
## dokunaçlar ve kalın ağız kolları. Çanı nabız gibi kasılıp açılarak süzülür; çarpınca çan hedefin üstüne kapanıp
## aşağı boşalan bir su sağanağına dönüşür.
static func suiton_abare_kurage(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 24.0)
	for k in 4:
		var pre = c.global_position + Vector3.UP * 2.0 + c.face_dir().cross(Vector3.UP) * (k - 1.5) * 1.5
		L.gather(pj, pre, 1.0, 8, 0.15 + k * 0.15, 0.3)
		pj.after(0.15 + k * 0.15, func():
			if not pj.live(c):
				return
			var parts = _jellyfish()
			var jf: Node3D = parts[0]
			var bell: Node3D = parts[1]
			var from = c.global_position + Vector3.UP * 2.0 + c.face_dir().cross(Vector3.UP) * (k - 1.5) * 1.5
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 12.0, jf, pj.inf(c, "suiton_abare_kurage", 0.5, {"knock": 8.0, "kind": "heavy", "element": "suiton", "stun": 0.5}), tt, false, 2.5, func(p, _h):
				_kurage_hit(pj, p))
			pr.homing_turn = 3.0
			_jelly_sway(parts[2])
			jf.scale = Vector3.ONE * 0.2
			var tg = jf.create_tween()
			tg.tween_property(jf, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			var age = {"t": 0.0}
			pr.on_tick = func(_p: Projectile, dt: float) -> void:
				age["t"] += dt
				var s = sin(age["t"] * 8.0) * 0.15
				bell.scale = Vector3(1.0 + s, 1.0 + s, 1.0 - s))
	Sfx.play("water", c.global_position, 0.9)


## [kök, çan, sallanan pivotlar]
static func _jellyfish() -> Array:
	var jf = Node3D.new()
	var bell = Node3D.new()
	jf.add_child(bell)
	var dome = L.wmi(_bell_mesh(), {"alpha": 0.9, "wob": 0.8, "flow": 0.6, "line": 0.16, "foam": 0.08})
	bell.add_child(dome)
	var inner = L.wmi(L.sphere_mesh(), {"alpha": 0.95, "wob": 1.2, "flow": 0.3, "line": 0.0, "foam": 0.0})
	inner.scale = Vector3(0.62, 0.62, 0.5)
	inner.position = Vector3(0, 0, -0.12)
	bell.add_child(inner)
	var pivots: Array = []
	for j in 9:
		var a = j * TAU / 9.0
		var pv = Node3D.new()
		pv.position = Vector3(cos(a) * 0.55, sin(a) * 0.55, 0.28)
		pv.rotation = Vector3(sin(a) * 0.35, -cos(a) * 0.35, 0.0)   # dışa açılır
		jf.add_child(pv)
		var tn = L.wmi(_tentacle_mesh(j % 3, randf_range(2.2, 3.0), 0.075), {"alpha": 0.9, "flow": 2.0, "line": 0.16, "wob": 0.6})
		pv.add_child(tn)
		pivots.append(pv)
	for j in 3:
		var pv2 = Node3D.new()
		pv2.position = Vector3(cos(j * 2.1) * 0.15, sin(j * 2.1) * 0.15, 0.2)
		jf.add_child(pv2)
		var arm = L.wmi(_tentacle_mesh(3 + j, 1.6, 0.16), {"alpha": 0.85, "flow": 1.0, "line": 0.12, "foam": 0.3, "wob": 1.2})
		pv2.add_child(arm)
		pivots.append(pv2)
	return [jf, bell, pivots]


static func _jelly_sway(pivots: Array) -> void:
	for pv in pivots:
		if not is_instance_valid(pv) or not pv.is_inside_tree():
			continue
		var r0: Vector3 = pv.rotation
		var amp = randf_range(0.18, 0.32)
		var per = randf_range(0.35, 0.5)
		var tw = pv.create_tween().set_loops()
		tw.tween_property(pv, "rotation", r0 + Vector3(amp, -amp * 0.6, 0.0), per).set_trans(Tween.TRANS_SINE)
		tw.tween_property(pv, "rotation", r0 + Vector3(-amp * 0.6, amp, 0.0), per).set_trans(Tween.TRANS_SINE)


static func _kurage_hit(pj: PathJutsu, p: Vector3) -> void:
	var cap = L.wmi(_bell_mesh(), {"alpha": 0.85, "wob": 1.6, "line": 0.14, "flow": 2.0})
	L.put(pj, cap, p + Vector3.UP * 1.2)
	cap.look_at(p + Vector3.UP * 3.0, Vector3.RIGHT)   # tepe yukarı, ağız aşağı
	cap.scale = Vector3.ONE * 1.6
	var tw = cap.create_tween()
	tw.tween_property(cap, "scale", Vector3(2.8, 2.8, 0.6), 0.16).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cap, "global_position", p + Vector3.UP * 0.3, 0.16)
	tw.tween_method(func(v: float): cap.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(cap.queue_free)
	L.spray(pj, p + Vector3.UP * 1.0, Vector3.DOWN, {"n": 30, "spread": 55.0, "vmin": 3.0, "vmax": 7.0, "life": 0.55, "smin": 0.16, "smax": 0.3, "r": 0.9, "g": Vector3(0, -18, 0)})
	var g = L.ground(p)
	if p.y - g.y < 3.5:
		L.puddle(pj, g, 2.0, 1.8, {"alpha": 0.6, "ripple": 0.7})
		L.ripple(pj, g, 0.4, 3.2, 0.55, {"foam": 0.9})


# ================================================================== 14. Suiton Suiryūdan — su ejderi (Jutsu otomatik yüklemesi)
## Kullanıcının önünde yerden su sütunu fışkırır; içinden boynuzlu, yeleli, açık çeneli ve sarı parlayan gözlü bir su ejderi
## başı çıkar (ref: Tobirama'nın ejderi). Kalın, köpüklü, sırt yüzgeçli gövde başın izinden kıvrılarak kaynaktan uzanır;
## kullanıcının önünde kıvrılıp yükselir, sonra hedefe dalar. Çarpınca dev taç sıçraması, sel birikintisi, sarsıntı.
static func suiton_suiryuudan(js, c: Node3D, t: Node3D) -> void:
	var m = js._mult(c) * js._elem_bonus(c, "suiton")
	Sfx.play("water", c.global_position)
	var fd = js._aim_flat(c, t)
	var start = js._ground(c.global_position + fd * 2.5) + Vector3.UP * 2.6
	var src = start - Vector3.UP * 2.6
	_dragon_source(js, src)
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = Vector3.UP * 12.0 + fd * 8.0
	pr.radius = 1.8
	pr.life = 3.5
	pr.homing = t
	pr.homing_turn = 3.0
	pr.info = {"dmg": 30.0 * m, "element": "suiton", "knock": 16.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.08}
	var hd = _dragon_head()
	pr.add_child(hd)
	# gövde: başın izinden örülen su gövdesi (her karede yeniden örülür; akış çizgileri boyuna kayar)
	var body = L.wmi(L.sphere_mesh(), {"alpha": 0.9, "foam": 0.22, "flow": 5.0, "wob": 0.8, "line": 0.18, "streak": 2.5})
	body.mesh = null
	body.extra_cull_margin = 16.0
	js.get_tree().current_scene.add_child(body)
	body.global_position = Vector3.ZERO
	var hist: Array = [src, start]
	var age = {"t": 0.0, "prev": start}
	pr.on_tick = func(p: Projectile, dt: float) -> void:
		age["t"] += dt
		_dragon_pose(p, hd, age)
		_dragon_body(hd, body, hist)
		if age["t"] < 0.55:   # kullanıcının önünde kıvrılarak yükselir (~8 m; ekrandan kaçıp kaybolmasın), sonra hedefe dalar
			p.vel = (Vector3.UP * 14.0 + fd.cross(Vector3.UP) * cos(age["t"] * 8.0) * 12.0 + fd * 6.0)
			return
		p.homing_turn = 6.0   # sonra hedefe dal
		if not t and p.life < 2.8:
			p.vel = p.vel.lerp(js._aim(c, null) * 26.0, 0.05)
		p.vel = p.vel.normalized() * minf(30.0, p.vel.length() + 0.6)
	# gövdeden saçılan köpük
	L.trail(pr, {"n": 40, "life": 0.7, "dir": Vector3(0, 0.3, 1), "spread": 70.0, "vmin": 1.5, "vmax": 4.0, "g": Vector3(0, -9, 0),
		"smin": 0.16, "smax": 0.32, "r": 1.4, "foam": 0.6, "alpha": 0.9})
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		_dragon_crash(js, pos)
		if is_instance_valid(hd):
			_dragon_rear(js, hd.global_transform)
		Combat.hit_sphere(c, pos, 4.5, {"dmg": 12.0 * m, "element": "suiton", "knock": 14.0, "launch": 6.0, "kind": "heavy"}, pr.hit_list)
		Sfx.play("water", pos, 0.8)
		if Game.world: Game.world.env.add_shake(0.6)
	pr.tree_exiting.connect(func(): _dragon_drain(js, body, hist))
	js.get_tree().current_scene.add_child(pr)
	pr.global_position = start


const DRAGON_S := 2.1


static func _dragon_head() -> Node3D:
	var h = Node3D.new()
	var head = L.wmi(_dragon_head_mesh(), {"alpha": 0.97, "foam": 0.25, "flow": 2.5, "wob": 0.4, "line": 0.3})
	head.scale = Vector3.ONE * DRAGON_S
	h.add_child(head)
	var em = _c("dragon_eye", func(): return _unlit(Color(1.0, 0.92, 0.45), 3.0))
	for sx in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		eye.mesh = L.sphere_mesh()
		eye.material_override = em
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position = Vector3(sx * 0.5, 0.42, -0.62) * DRAGON_S
		eye.scale = Vector3(0.38, 0.17, 0.44) * DRAGON_S
		eye.rotation = Vector3(0, sx * 0.35, sx * 0.3)
		h.add_child(eye)
	return h


## Görsel baş: mermi hedefe dalarken baş hedefin üstünde kemer çizip yukarıdan iner (yalnız görünüş; çarpma mermide)
static func _dragon_pose(p: Node3D, hd: Node3D, st: Dictionary) -> void:
	if not is_instance_valid(hd):
		return
	var lift = 0.0
	var tgt = p.get("homing")
	if st["t"] > 0.55 and tgt != null and is_instance_valid(tgt):
		var dist = p.global_position.distance_to(tgt.global_position)
		lift = clampf((dist - 3.0) * 0.5, 0.0, 6.5) * clampf((st["t"] - 0.55) / 0.3, 0.0, 1.0)
	var vp = p.global_position + Vector3.UP * lift
	var prev: Vector3 = st["prev"]
	var mv = vp - prev
	hd.global_position = vp
	if mv.length() > 0.05:
		hd.look_at(vp + mv, _up_for(mv))
	st["prev"] = vp


## Başın izini kaydeder ve gövdeyi yeniden örer (kuyruk: kaynaktan çıkan en eski nokta)
static func _dragon_body(hd: Node3D, body: MeshInstance3D, hist: Array) -> void:
	if not is_instance_valid(body) or not is_instance_valid(hd):
		return
	var neck = hd.global_position + hd.global_transform.basis.z * 1.1 * DRAGON_S
	var last: Vector3 = hist[hist.size() - 1]
	if last.distance_to(neck) > 1.1:
		hist.append(neck)
		if hist.size() > 30:
			hist.pop_front()
	var pts = hist.duplicate()
	pts.append(neck)
	var n = pts.size()
	if n < 2:
		return
	var rad = []
	for i in n:
		var u = float(i) / (n - 1)
		rad.append(lerpf(0.25, 0.95, pow(u, 0.5)) * (1.0 + 0.1 * sin(i * 1.7)))
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vc = L.tube_into(sf, 0, pts, rad, 12)
	# sırt yüzgeci sırası (her iki halkada bir, geriye yatık)
	for i in range(1, n - 1, 2):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		var tg = (b - a).normalized()
		var up = (Vector3.UP - tg * tg.dot(Vector3.UP))
		if up.length() < 0.1:
			continue
		up = up.normalized()
		var r = float(rad[i])
		var fh = 0.6 + r * 0.9
		vc = L.tube_into(sf, vc, [a + up * r * 0.6, a + up * (r + fh * 0.5) - tg * 0.3, a + up * (r + fh) - tg * 0.9], [0.26, 0.14, 0.0], 4, 0.3, tg.cross(up))
	sf.generate_normals()
	body.mesh = sf.commit()


static func _dragon_source(js, src: Vector3) -> void:
	var gy = L.wmi(L.geyser_mesh(), {"alpha": 0.88, "foam": 0.5, "wob": 1.2, "flow": -3.5, "line": 0.12})
	L.put(js, gy, src)
	gy.scale = Vector3(4.0, 0.05, 4.0)
	var tw = gy.create_tween()
	tw.tween_property(gy, "scale", Vector3(4.4, 6.5, 4.4), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.25)
	tw.tween_property(gy, "scale", Vector3(5.5, 0.2, 5.5), 0.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): gy.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(gy.queue_free)
	L.crown(js, src, 2.4, {"h": 1.4, "foam": 0.5, "fall": 0.7})
	L.ripple(js, src, 1.0, 6.0, 0.9, {"foam": 1.0})
	L.puddle(js, src, 3.4, 2.8, {"alpha": 0.6, "ripple": 0.9})
	L.spray(js, src + Vector3.UP * 0.5, Vector3.UP, {"n": 30, "spread": 40.0, "vmin": 6.0, "vmax": 12.0, "life": 0.9, "smin": 0.2, "smax": 0.4, "r": 1.2, "foam": 0.3})


static func _dragon_crash(js, pos: Vector3) -> void:
	var g = L.ground(pos)
	var near = pos.y - g.y < 4.0
	var shell = L.wmi(L.sphere_mesh(), {"alpha": 0.75, "foam": 0.45, "wob": 2.0, "line": 0.1, "flow": 3.0})
	L.put(js, shell, pos)
	shell.scale = Vector3.ONE * 2.0
	var tw = shell.create_tween().set_parallel(true)
	tw.tween_property(shell, "scale", Vector3(8.0, 5.0, 8.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): shell.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4).set_delay(0.05)
	tw.chain().tween_callback(shell.queue_free)
	L.spray(js, pos, Vector3.UP, {"n": 48, "spread": 110.0, "vmin": 6.0, "vmax": 15.0, "life": 1.0, "smin": 0.25, "smax": 0.5, "r": 1.5, "g": Vector3(0, -18, 0), "foam": 0.3})
	if near:
		L.crown(js, g, 3.2, {"h": 1.6, "foam": 0.55, "fall": 0.8})
		L.ripple(js, g, 1.0, 8.5, 1.0, {"foam": 1.0})
		L.puddle(js, g, 5.5, 3.5, {"alpha": 0.6, "ripple": 0.8})
		for j in 6:
			var a = j * TAU / 6.0 + randf() * 0.4
			L.crown(js, g + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 4.0), randf_range(0.8, 1.2), {"h": 0.8, "foam": 0.6})


## Çarpışta baş bir an şahlanıp yukarı kalkar ve suya dağılır (çarpış sonrası da başı okunur)
static func _dragon_rear(js, xf: Transform3D) -> void:
	var g = _dragon_head()
	js.get_tree().current_scene.add_child(g)
	g.global_transform = xf
	var geos = []
	for ch in g.get_children():
		if ch is GeometryInstance3D:
			geos.append(ch)
	var p0 = g.global_position
	var tw = g.create_tween()
	tw.tween_method(func(u: float):
		g.global_position = p0 + Vector3.UP * (2.2 * sin(u * PI * 0.5))
		g.rotation.x = lerpf(g.rotation.x, 0.6, 0.12)
		for gi in geos:
			if gi.material_override is ShaderMaterial:
				gi.set_instance_shader_parameter("fade", 1.0 - u * u)
			else:
				gi.transparency = u * u, 0.0, 1.0, 0.55)
	tw.tween_callback(g.queue_free)
	L.spray(js, p0, Vector3.UP, {"n": 20, "spread": 40.0, "vmin": 3.0, "vmax": 7.0, "life": 0.7, "smin": 0.2, "smax": 0.4, "r": 1.2, "foam": 0.4})


## Ejder kaybolunca gövde damlalara dağılarak boşalır
static func _dragon_drain(js, body: MeshInstance3D, hist: Array) -> void:
	if not is_instance_valid(body):
		return
	if not body.is_inside_tree() or js.get_tree() == null or js.get_tree().current_scene == null:
		body.queue_free()
		return
	var tw = body.create_tween()
	tw.tween_method(func(v: float): body.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(body.queue_free)
	for i in range(0, hist.size(), 4):
		var q: Vector3 = hist[i]
		L.spray(js, q, Vector3.DOWN, {"n": 8, "spread": 50.0, "vmin": 1.0, "vmax": 3.0, "life": 0.8, "smin": 0.18, "smax": 0.32, "r": 1.0, "g": Vector3(0, -16, 0)})


# ================================================================== 15. Shabondama no Ninjutsu — sabun köpüğü ninjutsu
## Dudaklardan dizi dizi, irili ufaklı yanardöner sabun köpükleri şişerek salınır; hepsi hafif yalpalayarak
## süzülür. Değen köpük patlayıp zarı ince damlalara dağılır, ardında sarımsı asit buharı ve tıslayan asit damlaları kalır.
static func shabondama_no_ninjutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	for k in 12:
		pj.after(k * 0.06, func():
			if not pj.live(c):
				return
			var sz = randf_range(0.35, 0.7)
			var holder = Node3D.new()
			var bub = _skin(sz)
			holder.add_child(bub)
			var from = pj._mouth_pos(c) + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), 0)
			var pr = pj.shot(c, from, (pj.aim_at(c, tt, from) + Vector3(randf_range(-0.25, 0.25), randf_range(-0.05, 0.2), randf_range(-0.25, 0.25))).normalized(), randf_range(8.0, 14.0), holder,
				pj.inf(c, "shabondama_no_ninjutsu", 0.2, {"knock": 3.0, "kind": "light", "element": "suiton", "poison": 2.0}), null, false, 2.4, func(p, _h):
				_acid_pop(pj, p, sz))
			bub.scale = Vector3.ONE * sz * 0.15
			var tw = bub.create_tween()
			tw.tween_property(bub, "scale", Vector3.ONE * sz, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			var ph = randf() * TAU
			var age = {"t": 0.0}
			pr.on_tick = func(_p: Projectile, dt: float) -> void:
				age["t"] += dt
				if is_instance_valid(bub):
					bub.position = Vector3(sin(age["t"] * 3.1 + ph) * 0.18, sin(age["t"] * 4.3 + ph * 2.0) * 0.14, 0.0))
	L.spray(pj, pj._mouth_pos(c), c.face_dir(), {"n": 8, "spread": 25.0, "vmin": 0.8, "vmax": 1.8, "life": 0.4, "smin": 0.05, "smax": 0.09, "foam": 0.9, "alpha": 0.7, "g": Vector3(0, -2, 0)})
	Sfx.play("water", c.global_position, 1.6)


static func _acid_pop(pj: PathJutsu, p: Vector3, s: float) -> void:
	L.bubble_pop(pj, p, s)
	L.mist(pj, p, 1.0 + s * 1.2, 0.9, {"tone": 4.0, "alpha": 0.5, "near": 3.0, "drift": Vector3(0, 0.6, 0), "fin": 0.1, "fout": 0.6, "s0": 0.4, "grow": 0.5})
	L.spray(pj, p, Vector3.DOWN, {"n": 5, "spread": 60.0, "vmin": 0.8, "vmax": 2.0, "life": 0.45, "smin": 0.06, "smax": 0.1, "pal": L.SOAP, "alpha": 0.9, "line": 0.1})
