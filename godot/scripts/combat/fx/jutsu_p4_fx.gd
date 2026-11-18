extends RefCounted
## Parti 4 (anime özgün teknikleri). Hedef: res://scripts/combat/fx/jutsu_p4_fx.gd. p = PathJutsu örneği; oyuncu ve düşman aynı kod.
## Jibakujutsu, Bunshin Kaiten Kakato Otoshi, Kokūn, Tsuchi Kurenai, Maengan. Görünen her şey burada, kaynaktan üretilir.

const STEP := 1.0 / 30.0
const CONTROL_T := 5.0
const COCOON_T := 7.0
const CLOUD_R := 5.5
const CLOUD_T := 7.5

static var _c := {}

## Kanji vuruşları (birim kare, yazım sırasıyla)
const SO := [[[-0.46, 0.22], [-0.2, 0.26]], [[-0.33, 0.48], [-0.33, -0.42], [-0.4, -0.35]], [[-0.46, -0.12], [-0.19, 0.03]],
	[[-0.02, 0.46], [0.26, 0.46], [0.26, 0.28], [-0.02, 0.28], [-0.02, 0.46]],
	[[-0.14, 0.2], [0.06, 0.2], [0.06, 0.04], [-0.14, 0.04], [-0.14, 0.2]], [[0.16, 0.2], [0.38, 0.2], [0.38, 0.04], [0.16, 0.04], [0.16, 0.2]],
	[[-0.16, -0.1], [0.46, -0.1]], [[0.15, 0.0], [0.15, -0.48]], [[0.13, -0.12], [-0.14, -0.42]], [[0.17, -0.12], [0.46, -0.42]]]
const METSU := [[[-0.46, 0.42], [-0.37, 0.33]], [[-0.48, 0.15], [-0.39, 0.06]], [[-0.46, -0.42], [-0.33, -0.12]],
	[[-0.24, 0.24], [0.44, 0.3]], [[-0.2, 0.24], [-0.23, -0.2], [-0.32, -0.44]], [[0.12, 0.47], [0.2, 0.0], [0.46, -0.44], [0.48, -0.26]], [[0.31, 0.43], [0.4, 0.36]],
	[[-0.08, 0.08], [-0.04, -0.03]], [[0.11, 0.1], [0.07, -0.03]], [[0.02, 0.15], [0.0, -0.12], [-0.13, -0.31]], [[0.02, -0.07], [0.15, -0.31]]]

const INK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float reveal = 1.0;
instance uniform float fade = 1.0;
void fragment() {
	if (UV.x > reveal) discard;
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float dry = 0.5 + 0.5 * sin(UV.x * 90.0 + UV.y * 7.0);
	ALBEDO = mix(vec3(0.27, 0.16, 0.36), vec3(0.03, 0.02, 0.05), smoothstep(0.1, 0.55, e));
	ALPHA = smoothstep(0.0, 0.18 + 0.14 * dry, e) * fade;
}
"""

const BIT_SH := """shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""

const STREAK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.95, 0.72, 0.32), vec3(1.0, 0.98, 0.88), e);
	ALPHA = e * UV.x * fade;
}
"""

const COCOON_SH := """shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;
instance uniform float erode = 0.0;
varying vec3 lp;
float lump(vec3 p) {
	return sin(p.x * 5.1 + sin(p.y * 3.3)) * sin(p.y * 4.7 + sin(p.z * 2.9)) * sin(p.z * 5.3 + sin(p.x * 3.7));
}
float vein(vec3 p) {
	float a = abs(sin(p.x * 13.0 + 2.0 * sin(p.y * 6.0)) + sin(p.z * 12.0 + 2.0 * sin(p.x * 5.0)));
	float b = abs(sin(p.y * 15.0 + 2.0 * sin(p.z * 7.0)) + sin(p.x * 11.0 - 1.5 * sin(p.y * 4.0)));
	return 1.0 - smoothstep(0.0, 0.12, min(a, b));
}
void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * lump(VERTEX) * 0.05;
}
void fragment() {
	if (lump(lp * 3.0) * 0.5 + 0.5 < erode * 1.15) discard;
	float v = vein(lp);
	ALBEDO = mix(mix(vec3(0.2, 0.38, 0.07), vec3(0.36, 0.55, 0.12), lump(lp * 1.6) * 0.5 + 0.5), vec3(0.2, 0.33, 0.08), v * 0.85);
	ROUGHNESS = 0.7;
}
"""

const SILK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.62, 0.84, 0.86), vec3(0.97, 1.0, 1.0), e);
	ALPHA = smoothstep(0.0, 0.4, e) * fade;
}
"""

const GASH_SH := """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled, depth_prepass_alpha;
instance uniform float fade = 1.0;
void fragment() {
	float d = abs(UV.y * 2.0 - 1.0);
	float grain = 0.5 + 0.5 * sin(UV.x * 150.0 + sin(UV.y * 25.0) * 3.0) * sin(UV.y * 60.0);
	vec3 floor_c = mix(vec3(0.17, 0.05, 0.04), vec3(0.3, 0.09, 0.06), grain);
	vec3 bank_c = mix(vec3(0.58, 0.2, 0.13), vec3(0.42, 0.26, 0.16), smoothstep(0.62, 1.0, d));
	ALBEDO = mix(floor_c, bank_c * (0.85 + 0.2 * grain), smoothstep(0.3, 0.42, d));
	ALPHA = (1.0 - smoothstep(0.9, 1.0, d)) * fade;
}
"""

const FUME_SH := """shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
instance uniform float fade = 1.0;
varying vec3 lp;
float bulge(vec3 d) {
	return 0.5 + 0.5 * sin(d.x * 4.0 + 1.3) * sin(d.y * 3.5 + 0.4) * sin(d.z * 4.0 + 2.1);
}
float spike(vec3 d) {
	return pow(max(0.0, sin(d.x * 9.0 + 0.7) * sin(d.y * 8.0 + 2.2) * sin(d.z * 9.0 + 1.1)), 3.0);
}
void vertex() {
	lp = VERTEX;
	vec3 d = normalize(VERTEX);
	VERTEX += NORMAL * length(VERTEX) * (bulge(d) * 0.34 + spike(d) * 1.5);
}
void fragment() {
	// ref: düz iki tonlu bej-gri duman, üstü açık kıvrımlı
	float n = sin(lp.x * 23.0 + TIME * 0.6) * sin(lp.y * 19.0 - TIME * 0.5) * sin(lp.z * 21.0) * 0.5 + 0.5;
	if (n > fade * 1.05) discard;
	float top = lp.y + 0.07 * sin(lp.x * 13.0 + lp.z * 9.0);
	ALBEDO = top > 0.08 ? vec3(0.72, 0.72, 0.63) : vec3(0.47, 0.47, 0.4);
}
"""

const BURST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.83, 0.82, 0.72);
	ALPHA = smoothstep(UV.x * 0.8, UV.x * 0.8 + 0.15, e) * fade;
}
"""


# ------------------------------------------------------------------ altyapı (görünmez)
static func _mat(key: String, code: String) -> ShaderMaterial:
	var k = "m:" + key
	if not _c.has(k):
		var s = Shader.new()
		s.code = code
		var m = ShaderMaterial.new()
		m.shader = s
		_c[k] = m
	return _c[k]


static func _free(n) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()


static func _strip(p, mat: Material) -> Array:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 40.0
	p.scene_add(mi, Vector3.ZERO)
	return [mi, im]


static func _draw_cam(p, im: ImmediateMesh, pts: Array, w0: float, w1: float) -> void:
	im.clear_surfaces()
	if pts.size() < 2:
		return
	var cam = p.get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam != null else Vector3.UP * 100.0
	var last = float(pts.size() - 1)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var q: Vector3 = pts[i]
		var s = (b - a).cross(eye - q).normalized()
		var u = i / last
		var w = lerpf(w0, w1, u)
		im.surface_set_uv(Vector2(u, 0))
		im.surface_add_vertex(q - s * w)
		im.surface_set_uv(Vector2(u, 1))
		im.surface_add_vertex(q + s * w)
	im.surface_end()


static func _fade_out(mi: MeshInstance3D, t: float) -> void:
	var fn = func(v: float) -> void:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("fade", v)
	var tw = mi.create_tween()
	tw.tween_method(fn, 1.0, 0.0, t)
	tw.tween_callback(mi.queue_free)


static func _chest(n: Node3D) -> Vector3:
	var h = n.get("height")
	return n.global_position + Vector3.UP * (float(h) * 0.58 if h != null else 1.05)


static func _h(n: Node3D) -> float:
	var h = n.get("height")
	return float(h) if h != null else 1.8


static func _bez(a: Vector3, m: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(m, u).lerp(m.lerp(b, u), u)


static func _chunk() -> Mesh:
	if not _c.has("chunk"):
		var b = BoxMesh.new()
		b.size = Vector3.ONE
		_c["chunk"] = b
	return _c["chunk"]


## Savrulan katı parçalar (mürekkep damlası, toprak öbeği): renk ve boyut çağırandan
static func _bits(p, at: Vector3, dir: Vector3, n: int, spread: float, size: float, cols: Array, life := 0.6, g := 11.0) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _chunk()
	mm.instance_count = n
	var data = []
	for i in n:
		var v = dir + Vector3(randf_range(-1, 1), randf_range(0.1, 1), randf_range(-1, 1)) * spread
		data.append([v, randf_range(0.5, 1.0) * size, randf() * TAU])
		mm.set_instance_color(i, cols[i % cols.size()])
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), at))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("bit", BIT_SH)
	mi.custom_aabb = AABB(at - Vector3.ONE * 14.0, Vector3.ONE * 28.0)
	p.scene_add(mi, Vector3.ZERO)
	var step = func(t: float) -> void:
		if not is_instance_valid(mi):
			return
		var sc = 1.0 - smoothstep(life * 0.65, life, t)
		for i in n:
			var e: Array = data[i]
			var q = at + (e[0] as Vector3) * t + Vector3.DOWN * g * t * t
			mm.set_instance_transform(i, Transform3D(Basis(Vector3(0.5, 0.8, 0.3).normalized(), float(e[2]) + t * 9.0).scaled(Vector3.ONE * float(e[1]) * sc), q))
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(mi.queue_free)


# ------------------------------------------------------------------ Jibakujutsu
static func _glyph(key: String, strokes: Array) -> ArrayMesh:
	var k = "glyph:" + key
	if _c.has(k):
		return _c[k]
	var total = 0.0
	for s in strokes:
		for i in s.size() - 1:
			total += Vector2(s[i][0], s[i][1]).distance_to(Vector2(s[i + 1][0], s[i + 1][1]))
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc = 0.0
	for s in strokes:
		var n = s.size() - 1
		for i in n:
			var a = Vector2(s[i][0], s[i][1])
			var b = Vector2(s[i + 1][0], s[i + 1][1])
			var L = a.distance_to(b)
			var d = (b - a).normalized()
			var nr = Vector2(-d.y, d.x)
			var w0 = lerpf(0.05, 0.028, float(i) / n)
			var w1 = lerpf(0.05, 0.016, float(i + 1) / n)
			var a0 = a - d * 0.012
			var b0 = b + d * 0.012
			var u0 = acc / total
			var u1 = (acc + L) / total
			var quad = [[a0 - nr * w0, u0, 0.0], [a0 + nr * w0, u0, 1.0], [b0 + nr * w1, u1, 1.0], [a0 - nr * w0, u0, 0.0], [b0 + nr * w1, u1, 1.0], [b0 - nr * w1, u1, 0.0]]
			for q in quad:
				st.set_uv(Vector2(q[1], q[2]))
				st.set_normal(Vector3.BACK)
				var v: Vector2 = q[0]
				st.add_vertex(Vector3(v.x, v.y, 0.0))
			acc += L
	var m = st.commit()
	_c[k] = m
	return m


static func _end_control(t, team) -> void:
	if t == null or not is_instance_valid(t) or not t.has_meta("jibaku_until"):
		return
	t.remove_meta("jibaku_until")
	if t.get("dead") == true:
		return
	t.set("team", team)
	t.set("target", null)
	Combat.popup_text(t.global_position + Vector3.UP * 2.5, "Kendine geldi", Color(1.0, 0.72, 0.62))


## Kanon (Shiranami): parmakla havaya yazılan kanji hedefin bedenine geçer. 操: hedef iradesine girer, çok güçlü chakra bunu çözer. 滅: yok eder
static func jibakujutsu(p, c: Node3D, t: Node3D) -> void:
	var id = "jibakujutsu"
	p.busy(c, 0.8)
	p.anim(c, "cast", 1.1)
	var tt = p.tg(c, t, 20.0)
	var d: Vector3 = p._face(c, tt)
	var marked = p.live(tt) and Game.now() < float(tt.get_meta("jibaku_until", 0.0))
	var mi = MeshInstance3D.new()
	mi.mesh = _glyph("metsu", METSU) if marked else _glyph("so", SO)
	mi.material_override = _mat("ink", INK_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	p.scene_add(mi, c.global_position)
	var side = Vector3.UP.cross(d).normalized()
	var s = {"phase": 0, "t": 0.0, "from": Vector3.ZERO}
	Sfx.play("seal", c.global_position, 1.25, 0.6)
	var total = 0.56 + 0.2 + (CONTROL_T if not marked else 0.1)
	var team0 = tt.get("team") if p.live(tt) else null
	var tick = func(_i, _k: float) -> void:
		if not is_instance_valid(mi):
			return
		s["t"] += STEP
		var now: float = s["t"]
		if int(s["phase"]) == 0:
			var at = p.hand_pos(c, true) + d * 0.55 + Vector3.UP * 0.12 if p.live(c) else mi.global_position
			mi.global_transform = Transform3D(Basis(-side, Vector3.UP, -d).scaled(Vector3.ONE * 0.85), at)
			mi.set_instance_shader_parameter("reveal", clampf(now / 0.54, 0.0, 1.0) * 1.02)
			if now >= 0.56:
				s["phase"] = 1
				s["t"] = 0.0
				s["from"] = at
				Sfx.play("whoosh", at, 1.6, 0.5)
		elif int(s["phase"]) == 1:
			var k = clampf(now / 0.2, 0.0, 1.0)
			var to: Vector3 = _chest(tt) if p.live(tt) else (s["from"] as Vector3) + d * 12.0
			mi.global_position = (s["from"] as Vector3).lerp(to, k * k)
			if k >= 1.0:
				s["phase"] = 2
				s["t"] = 0.0
				if p.live(tt) and p.live(c):
					_kanji_lands(p, c, tt, id, marked, team0, mi)
				if marked or not p.live(tt) or not tt.has_meta("jibaku_until"):
					_fade_out(mi, 0.3)
					s["phase"] = 3
		elif int(s["phase"]) == 2:
			if not p.live(tt) or not tt.has_meta("jibaku_until"):
				s["phase"] = 3
				_fade_out(mi, 0.3)
				return
			var f: Vector3 = tt.face_dir() if tt.has_method("face_dir") else Vector3.BACK
			var x = Vector3.UP.cross(f).normalized()
			mi.global_transform = Transform3D(Basis(x, Vector3.UP, f).scaled(Vector3.ONE * 0.42), _chest(tt) + f * (float(tt.get("radius")) + 0.05 if tt.get("radius") != null else 0.45))
	var done = func() -> void:
		if is_instance_valid(mi) and int(s["phase"]) != 3:
			_free(mi)
	p.every(total, STEP, tick, done)


static func _kanji_lands(p, c: Node3D, tt: Node3D, id: String, marked: bool, team0, _mi) -> void:
	var ink = [Color(0.06, 0.04, 0.08), Color(0.2, 0.12, 0.28)]
	_bits(p, _chest(tt), Vector3.UP * 1.5, 12, 3.0, 0.05, ink, 0.45)
	Sfx.play("hit_blade", _chest(tt), 0.7, 0.5)
	if marked:   # 滅
		var orig = tt.get_meta("jibaku_team", team0)
		_end_control(tt, orig)
		tt.take_hit(p.inf(c, id, 1.3, {"knock": 7.0, "kind": "heavy", "hitstop": 0.1, "dir": p._face(c, tt)}))
		_bits(p, _chest(tt), Vector3.UP * 2.0, 26, 5.0, 0.07, ink, 0.6)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.5, "滅", Color(0.72, 0.5, 0.9))
		return
	tt.take_hit(p.inf(c, id, 0.2, {"knock": 0.0, "kind": "light", "hitstop": 0.02, "dir": Vector3.ZERO}))
	if not p.live(tt):
		return
	var tc = tt.get("max_chakra")
	var cc = c.get("max_chakra")
	var strong = tc != null and cc != null and float(tc) > float(cc) * 1.3
	if strong or float(tt.max_hp) > float(c.max_hp) * 4.0:   # kanon: muazzam chakra yazıyı çözer
		Combat.popup_text(tt.global_position + Vector3.UP * 2.5, "Yazı çözüldü!", Color(0.8, 0.8, 0.9))
		return
	tt.set_meta("jibaku_until", Game.now() + CONTROL_T)
	tt.set_meta("jibaku_team", team0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.5, "操", Color(0.72, 0.5, 0.9))
	if tt is Player:   # oyuncunun iradesi alınamaz: beden bir süre kımıldamaz
		p.st(tt, "paralyze", 2.2)
		p.after(2.2, func(): _clear_mark(tt))
		return
	tt.set("team", c.get("team"))
	tt.set("target", null)
	p.after(CONTROL_T, func(): _end_control(tt, team0))


static func _clear_mark(t) -> void:
	if t != null and is_instance_valid(t) and t.has_meta("jibaku_until"):
		t.remove_meta("jibaku_until")


# ------------------------------------------------------------------ Bunshin Kaiten Kakato Otoshi
static func _impact_lines(p, at: Vector3) -> void:
	for k in 7:
		var a = TAU * k / 7.0 + randf() * 0.3
		var e = Vector3(cos(a), randf_range(-0.2, 0.55), sin(a)).normalized()
		var r = _strip(p, _mat("kakato_streak", STREAK_SH))
		_draw_cam(p, r[1], [at + e * 1.25, at + e * 0.75, at + e * 0.3], 0.0, 0.05)
		_fade_out(r[0], 0.2)


## Kanon (Naruto): gölge klonlarla havalanıp takla atar, dönerek topukları hedefin omuz ve başına indirirsin
static func bunshin_kakato(p, c: Node3D, t: Node3D) -> void:
	var id = "bunshin_kakato"
	p.busy(c, 1.25)
	p.anim(c, "jump", 1.2)
	var tt = p.tg(c, t, 13.0)
	var d: Vector3 = p._face(c, tt)
	var ground: Vector3 = p.gp(c.global_position + d * 7.0)
	var jumpers = []
	for k in 4:
		var a = TAU * (k + 0.5) / 4.0
		var at = c.global_position + Vector3(cos(a), 0, sin(a)) * 1.3
		var cl = p.decoy(c, at, 1.5)
		cl.set_physics_process(false)
		jumpers.append(cl)
	jumpers.append(c)
	var info = []
	for j in jumpers.size():
		var a = TAU * j / 5.0
		var st = _strip(p, _mat("kakato_streak", STREAK_SH))
		info.append({"n": jumpers[j], "from": jumpers[j].global_position, "off": Vector3(cos(a), 0, sin(a)) * 0.42, "done": false, "trail": [], "rib": st, "out": Vector3(cos(a), 0, sin(a)) * 1.7})
	Sfx.play("whoosh", c.global_position, 0.9, 0.8)
	var T = 1.15
	var tick = func(_i, k: float) -> void:
		var now = k * T
		var live_t = p.live(tt)
		var base: Vector3 = tt.global_position if live_t else ground
		var top = base.y + (_h(tt) if live_t else 1.0)
		for j in info.size():
			var e: Dictionary = info[j]
			var n = e["n"]
			if not is_instance_valid(n):
				continue
			var tau = now - j * 0.075
			if tau < 0.0:
				continue
			var land = Vector3(base.x, top + 0.2, base.z) + (e["off"] as Vector3)
			var q: Vector3
			var spin = 0.0
			if tau < 0.5:
				var u = tau / 0.5
				var apex = land + Vector3.UP * 3.8 - d * 1.0
				q = _bez(e["from"], apex, land, u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65)
				spin = u * TAU * 2.0
			else:
				if not bool(e["done"]):
					e["done"] = true
					_heel(p, c, tt, land, id, j == info.size() - 1, d)
				var u = clampf((tau - 0.5) / 0.32, 0.0, 1.0)
				var g: Vector3 = p.gp(base + (e["out"] as Vector3))
				q = _bez(land, land.lerp(g, 0.5) + Vector3.UP * 0.9, g, u)
			n.global_position = q
			if n is CharacterBody3D:
				n.velocity = Vector3.ZERO
			var mdl = n.get("model")
			if mdl != null:   # takla bel hizasından dönsün (model ayak tabanından döner)
				if not e.has("p0"):
					e["p0"] = mdl.position
				mdl.rotation.x = spin
				mdl.position = (e["p0"] as Vector3) + Vector3(0, 0.9 * (1.0 - cos(spin)), -0.9 * sin(spin)).rotated(Vector3.UP, mdl.rotation.y)
			var tr: Array = e["trail"]
			if tau < 0.56:
				tr.append(q + Vector3.UP * 0.9 + (d * sin(spin) + Vector3.UP * cos(spin)) * 0.85)
				if tr.size() > 10:
					tr.pop_front()
			elif not tr.is_empty():
				tr.pop_front()
			var r: Array = e["rib"]
			_draw_cam(p, r[1], tr, 0.0, 0.14)
	var done = func() -> void:
		for j in info.size():
			var e: Dictionary = info[j]
			_free(e["rib"][0])
			var n = e["n"]
			if is_instance_valid(n):
				var mdl = n.get("model")
				if mdl != null:
					mdl.rotation.x = 0.0
					if e.has("p0"):
						mdl.position = e["p0"]
				if n != c:
					n.queue_free()
	p.every(T, STEP, tick, done)


static func _heel(p, c: Node3D, tt, at: Vector3, id: String, last: bool, d: Vector3) -> void:
	_impact_lines(p, at)
	Sfx.play("hit_heavy" if last else "punch", at, 0.85 if last else 1.15, 0.8)
	if not p.live(c):
		return
	var info: Dictionary = p.inf(c, id, 0.62 if last else 0.2, {"knock": 6.0 if last else 0.0, "kind": "heavy" if last else "light", "hitstop": 0.1 if last else 0.03, "dir": d})
	var hits = p.hit(c, at + Vector3.DOWN * 0.3, 1.25, info)
	for h in hits:
		p.st(h, "stun", 0.7 if last else 0.25)
	if p.live(tt) and last and Game.world != null:
		Game.world.env.add_shake(0.3)


# ------------------------------------------------------------------ Kokūn
static func _lobe_mesh() -> Mesh:
	if not _c.has("lobe"):
		var m = SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 36
		m.rings = 22
		_c["lobe"] = m
	return _c["lobe"]


static func _shield_left(c: Node3D) -> bool:
	var sh = c.get_meta("shields", {})
	if not (sh is Dictionary) or not sh.has("kokun"):
		return false
	return float(sh["kokun"].get("hp", 0.0)) > 0.0


## Kanon (Fū + Chōmei): dışarıdan chakra emilmesini kesen, çok dayanıklı koza; içindeki korunur, delinebilir
static func kokun(p, c: Node3D, _t: Node3D) -> void:
	var T = COCOON_T
	p.busy(c, T)
	p.anim(c, "cast", 1.0)
	if c is Player:
		Buffs.add("kokun", T, {})
		c.input_locked = T
	elif c.has_method("add_buff"):
		c.add_buff("kokun", T, {})
		p.st(c, "bind", T)
	Combat.set_shield(c, "kokun", float(c.max_hp) * 0.7, false)
	var base: Vector3 = p.gp(c.global_position)
	var f: Vector3 = p.fwd(c, null)
	var side = Vector3.UP.cross(f).normalized()
	var lobes = []
	for e in [[Vector3(0, 1.05, 0), 1.3], [Vector3.UP * 2.75 + side * 0.72 - f * 0.25, 1.02]]:
		var mi = MeshInstance3D.new()
		mi.mesh = _lobe_mesh()
		mi.material_override = _mat("cocoon", COCOON_SH)
		p.scene_add(mi, base + (e[0] as Vector3))
		mi.rotation = Vector3(randf(), randf() * TAU, randf())
		lobes.append([mi, float(e[1])])
	var silk = []
	for k in 16:
		var a = TAU * k / 16.0 + randf() * 0.25
		var dir = Vector3(cos(a), 0, sin(a))
		var top = base + Vector3.UP * randf_range(0.6, 2.0) + dir * 1.05
		var foot: Vector3 = p.gp(base + dir * randf_range(2.1, 3.7))
		var r = _strip(p, _mat("silk", SILK_SH))
		silk.append([r, top, foot, top.lerp(foot, 0.55) + Vector3.UP * randf_range(-0.25, 0.1)])
	Sfx.play("earth", base, 1.5, 0.6)
	var s = {"end": false, "t": 0.0, "t_end": 0.0}
	var release = func() -> void:
		if bool(s["end"]):
			return
		s["end"] = true
		s["t_end"] = s["t"]
		Sfx.play("earth", base, 1.8, 0.7)
		if is_instance_valid(c):
			if c is Player:
				c.input_locked = 0.0
			elif c.get("statuses") is Dictionary:
				c.statuses.erase("bind")
			var sh = c.get_meta("shields", {})
			if sh is Dictionary:
				sh.erase("kokun")
	var tick = func(_i, _k: float) -> void:
		s["t"] += STEP
		var now: float = s["t"]
		if not bool(s["end"]) and (not p.live(c) or (now > 0.2 and not _shield_left(c)) or now >= T - 0.05):
			release.call()
		var gr = smoothstep(0.0, 0.42, now)
		var er = 0.0
		if bool(s["end"]):
			er = clampf((now - float(s["t_end"])) / 0.5, 0.0, 1.0)
		for l in lobes:
			var mi: MeshInstance3D = l[0]
			if is_instance_valid(mi):
				mi.scale = Vector3.ONE * float(l[1]) * maxf(gr, 0.01)
				mi.set_instance_shader_parameter("erode", er)
		for e in silk:
			var r: Array = e[0]
			var u = smoothstep(0.1, 0.55, now)
			var pts = []
			for j in 7:
				pts.append(_bez(e[1], e[3], e[2], j / 6.0 * u))
			_draw_cam(p, r[1], pts, 0.045, 0.012)
			r[0].set_instance_shader_parameter("fade", 1.0 - er)
	var done = func() -> void:
		release.call()
		for l in lobes:
			_free(l[0])
		for e in silk:
			_free(e[0][0])
	p.every(T + 0.55, STEP, tick, done)


# ------------------------------------------------------------------ Tsuchi Kurenai
static func _drill_mesh() -> ArrayMesh:
	if _c.has("drill"):
		return _c["drill"]
	var b = MB.new()
	var steel = Color(0.5, 0.48, 0.47)
	var dk = Color(0.25, 0.24, 0.25)
	b.add("cone", Vector3(0, 0, -0.42), Vector3(0.62, 0.85, 0.62), steel, Vector3(-90, 0, 0), 12)
	b.add("cyl", Vector3(0, 0, 0.12), Vector3(0.68, 0.24, 0.68), dk, Vector3(90, 0, 0), 12)
	for i in 26:
		var u = i / 26.0
		var a = u * TAU * 3.2
		var r = lerpf(0.33, 0.03, u)
		b.add("box", Vector3(cos(a) * r, sin(a) * r, -u * 0.82 + 0.0), Vector3(0.075, 0.04, 0.09), dk, Vector3(0, 0, rad_to_deg(a)))
	var m = b.build(Props.toon())
	_c["drill"] = m
	return m


static func _dist_seg(q: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	ab.y = 0.0
	var aq = q - a
	aq.y = 0.0
	var k = clampf(aq.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (aq - ab * k).length()


## Hendeğin kesiti: dış toprak, sırt, iç kenar, taban, iç kenar, sırt, dış toprak
static func _draw_gash(im: ImmediateMesh, rows: Array, side: Vector3) -> void:
	const SEC := [[-1.5, 0.0], [-1.0, 0.34], [-0.6, -0.02], [0.6, -0.02], [1.0, 0.34], [1.5, 0.0]]
	im.clear_surfaces()
	if rows.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = rows.size()
	var L = float(n - 1)
	var wid = func(i: int) -> float:   # iki uçta sivrilir, kenar düz çizgi olmaz
		var tip = minf(1.0, minf(i / 3.0, (n - 1 - i) / 2.0) + 0.08)
		return tip * (1.0 + 0.16 * sin(i * 1.7) + 0.1 * sin(i * 3.3 + 1.0))
	for i in n - 1:
		var a: Vector3 = rows[i]
		var b: Vector3 = rows[i + 1]
		var wa: float = wid.call(i)
		var wb: float = wid.call(i + 1)
		for j in 5:
			var s0: Array = SEC[j]
			var s1: Array = SEC[j + 1]
			var v0 = float(j) / 5.0
			var v1 = float(j + 1) / 5.0
			var quad = [[a, s0, i / L, v0, wa], [b, s0, (i + 1) / L, v0, wb], [b, s1, (i + 1) / L, v1, wb], [a, s0, i / L, v0, wa], [b, s1, (i + 1) / L, v1, wb], [a, s1, i / L, v1, wa]]
			for q in quad:
				var sc: Array = q[1]
				var w: float = q[4]
				im.surface_set_normal(Vector3.UP)
				im.surface_set_uv(Vector2(q[2], q[3]))
				im.surface_add_vertex((q[0] as Vector3) + side * float(sc[0]) * w + Vector3.UP * float(sc[1]) * minf(w, 1.0))
	im.surface_end()


## Kanon (Toki): koldaki dev matkabı ateşler; matkap araziyi yarıp yeni bir hat açar. Hendek geçidi daraltır
static func tsuchi_kurenai(p, c: Node3D, t: Node3D) -> void:
	var id = "tsuchi_kurenai"
	p.busy(c, 0.9)
	p.anim(c, "cast", 1.2)
	var tt = p.tg(c, t, 28.0)
	var d: Vector3 = p._face(c, tt)
	var side = Vector3.UP.cross(d).normalized()
	var start: Vector3 = p.hand_pos(c, true) + d * 0.5
	var o: Vector3 = c.global_position + d * 1.2
	var L = 26.0
	var drill = MeshInstance3D.new()
	drill.mesh = _drill_mesh()
	p.scene_add(drill, start)
	drill.look_at(start + d, Vector3.UP)
	var gash = _strip(p, _mat("gash", GASH_SH))
	var rows = []
	var hitlist: Array = []
	var s = {"next": 0.0, "dust": 0}
	var soil = [Color(0.55, 0.19, 0.12), Color(0.36, 0.14, 0.1), Color(0.5, 0.33, 0.2)]
	Sfx.play("hit_heavy_weapon", start, 0.7, 0.9)
	var T = 0.62
	var tick = func(_i, k: float) -> void:
		var run = smoothstep(0.08, 1.0, k) * L
		var head: Vector3 = p.gp(o + d * run)
		var fly = clampf(k / 0.12, 0.0, 1.0)
		var at = start.lerp(head + Vector3.UP * 0.25, fly)
		if is_instance_valid(drill):
			drill.global_position = at
			drill.rotate_object_local(Vector3.BACK, 1.1)
		if fly < 1.0:
			return
		while float(s["next"]) <= run:
			rows.append(p.gp(o + d * float(s["next"])) + Vector3.UP * 0.03)
			s["next"] += 0.65
		_draw_gash(gash[1], rows, side)
		s["dust"] += 1
		if int(s["dust"]) % 2 == 0:
			_bits(p, head + Vector3.UP * 0.3, Vector3.UP * 4.0 - d * 2.0, 7, 3.0, 0.2, soil, 0.65, 12.0)
			Sfx.play("earth", head, randf_range(0.7, 1.0), 0.35)
		if p.live(c):
			var hits = p.hit(c, head + Vector3.UP * 0.8, 1.9, p.inf(c, id, 1.0, {"knock": 7.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.09, "dir": d}), hitlist)
			hitlist.append_array(hits)
	var done = func() -> void:
		var end: Vector3 = p.gp(o + d * L)
		_free(drill)
		_bits(p, end + Vector3.UP * 0.4, Vector3.UP * 5.0, 18, 4.0, 0.26, soil, 0.8, 12.0)
		if Game.world != null:
			Game.world.env.add_shake(0.45)
		_gash_zone(p, c, o, end, gash[0])
	p.every(T, STEP, tick, done)


## Yarılan arazi: içinden geçen yavaşlar, sonra hendek kapanır
static func _gash_zone(p, c: Node3D, a: Vector3, b: Vector3, mi: MeshInstance3D) -> void:
	var mid = (a + b) * 0.5
	var r = a.distance_to(b) * 0.5 + 2.0
	var tick = func(_i, _k: float) -> void:
		if not p.live(c):
			return
		for e in p.enemies_near(c, mid, r):
			if _dist_seg(e.global_position, a, b) < 1.3:
				p.st(e, "slow", 0.9)
	var done = func() -> void:
		if is_instance_valid(mi):
			_fade_out(mi, 1.0)
	p.every(7.0, 0.35, tick, done)


# ------------------------------------------------------------------ Maengan
static func _shell_mesh() -> ArrayMesh:
	if _c.has("shell"):
		return _c["shell"]
	var b = MB.new()
	b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.15, Color(0.16, 0.17, 0.16), Vector3.ZERO, 7)
	b.add("cyl", Vector3(0, 0, 0.09), Vector3(0.05, 0.05, 0.05), Color(0.5, 0.42, 0.26), Vector3(90, 0, 0), 5)
	var m = b.build(Props.toon())
	_c["shell"] = m
	return m


static func _puff_mesh() -> Mesh:
	if not _c.has("fume"):
		var m = SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 36
		m.rings = 20
		_c["fume"] = m
	return _c["fume"]


## Patlama anı: dışa fırlayan sivri duman dilleri (ref)
static func _shell_burst(p, at: Vector3) -> void:
	for k in 6:
		var a = TAU * k / 6.0 + randf() * 0.5
		var e = Vector3(cos(a), randf_range(0.15, 1.0), sin(a)).normalized()
		var r = _strip(p, _mat("maengan_dil", BURST_SH))
		var L = randf_range(1.1, 2.0)
		_draw_cam(p, r[1], [at, at + e * L * 0.4, at + e * L * 0.75 + Vector3.UP * 0.08, at + e * L + Vector3.UP * 0.2], 0.3, 0.02)
		_fade_out(r[0], 0.28)


## Kanon (Kihō): bilek fırlatıcısıyla küçük duman bombası yağmuru; patlayıp kalın duman perdesi kurar
static func maengan(p, c: Node3D, t: Node3D) -> void:
	var id = "maengan"
	p.busy(c, 0.95)
	p.anim(c, "cast", 1.5)
	var tt = p.tg(c, t, 24.0)
	var d: Vector3 = p._face(c, tt)
	var aim: Vector3 = p.gp(tt.global_position) if p.live(tt) else p.gp(c.global_position + d * 13.0)
	var s = {"cloud": false}
	for k in 10:
		var go = func() -> void:
			if not p.live(c):
				return
			var from: Vector3 = p.hand_pos(c, true) + d * 0.35
			var a = randf() * TAU
			var to: Vector3 = p.gp(aim + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * 3.6)
			var fl = 0.48 + randf() * 0.14
			var g = 16.0
			var v: Vector3 = (to - from) / fl + Vector3.UP * 0.5 * g * fl
			var body = MeshInstance3D.new()
			body.mesh = _shell_mesh()
			var on_h = func(pos: Vector3, _h2: Node3D) -> void:
				_shell_burst(p, pos)
				Sfx.play("boom", pos, 2.1, 0.22)
				if p.live(c):
					for h in p.hit(c, pos, 1.2, p.inf(c, id, 0.1, {"knock": 0.3, "kind": "light", "hitstop": 0.0})):
						p.st(h, "slow", 1.2)
				if not bool(s["cloud"]):
					s["cloud"] = true
					_cloud(p, c, aim)
			var info: Dictionary = p.inf(c, id, 0.0, {"knock": 0.0, "kind": "light", "hitstop": 0.0})
			var pr = p.shot(c, from, v.normalized(), v.length(), body, info, null, false, 1.6, on_h)
			pr.gravity = g
			pr.vel = v
			pr.radius = 0.16
			Sfx.play("throw", from, 1.5, 0.35)
		p.after(k * 0.07, go)


## Kalın duman: oyunun görüş kapama sistemine (duman bulutu grubu) kayıtlı, görünüşü bu tekniğin
static func _cloud(p, c: Node3D, at: Vector3) -> void:
	var root = Node3D.new()
	p.scene_add(root, at)
	root.add_to_group("kemuri_bulut")
	root.set_meta("owner_id", c.get_instance_id() if is_instance_valid(c) else 0)
	root.set_meta("c", at + Vector3.UP * 1.6)
	root.set_meta("r", 0.0)
	var n = 26
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _puff_mesh()
	mm.instance_count = n
	var data = []
	for i in n:
		var a = randf() * TAU
		var r = sqrt(randf()) * CLOUD_R * 0.8
		data.append([Vector3(cos(a) * r, randf_range(0.5, 2.9) * (1.15 - r / CLOUD_R * 0.7), sin(a) * r), randf_range(2.2, 3.7), randf() * TAU, randf_range(0.5, 1.0)])
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("fume", FUME_SH)
	mi.custom_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 12, 20))
	root.add_child(mi)
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if f.has_method("lose_target") and Combat.hostile(c, f) and not f.is_dead() and f.global_position.distance_to(at) < CLOUD_R + 1.0:
			f.lose_target(2.5)
	var s = {"t": 0.0, "end": CLOUD_T}
	var tick = func(_i, _k: float) -> void:
		if not is_instance_valid(root):
			return
		s["t"] += STEP
		var now: float = s["t"]
		if root.get_meta("wind", false):   # rüzgâr dumanı dağıtır
			s["end"] = minf(float(s["end"]), now + 0.8)
			root.remove_meta("wind")
		var end_t: float = s["end"]
		var gr = 1.0 - exp(-now * 3.4)
		var fd = 1.0 - smoothstep(end_t - 1.3, end_t, now)
		root.set_meta("r", CLOUD_R * 0.92 * gr * fd)
		mi.set_instance_shader_parameter("fade", fd)
		for i in n:
			var e: Array = data[i]
			var q = (e[0] as Vector3) * gr + Vector3.UP * now * 0.05 * float(e[3])
			var b = Basis(Vector3.UP, float(e[2]) + now * 0.08 * float(e[3])).scaled(Vector3.ONE * float(e[1]) * gr)
			mm.set_instance_transform(i, Transform3D(b, q))
		if now >= end_t:
			root.remove_from_group("kemuri_bulut")
			_free(root)
	var done = func() -> void:
		if is_instance_valid(root):
			root.remove_from_group("kemuri_bulut")
			_free(root)
	Sfx.play("wind", at, 0.7, 0.8)
	p.every(CLOUD_T + 0.2, STEP, tick, done)
