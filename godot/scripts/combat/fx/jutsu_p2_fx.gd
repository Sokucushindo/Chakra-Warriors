extends RefCounted
## Parti 2 (anime özgün teknikleri). Hedef: res://scripts/combat/fx/jutsu_p2_fx.gd. p = PathJutsu örneği; oyuncu ve düşman aynı kod.
## Kagerō Ninpō: Utakata, Kōmori Seichū, Enmaku Rō, Saibō no Kasseijutsu, Chakura no Hari. Görünen her şey burada, kaynaktan üretilir.

const UTAKATA_LOCK := 600.0
const STEP := 1.0 / 30.0

static var _c := {}

const WING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float open_k = 1.0;
void vertex() {
	float s = UV.x;
	VERTEX.z += sin(TIME * 7.0 + s * 5.0) * 0.07 * s;
	VERTEX.xy += normalize(VERTEX.xy + vec2(0.001)) * sin(TIME * 5.0 + s * 9.0) * 0.03 * s;
	VERTEX.xy *= open_k;
}
float wisp(vec2 p) {
	return 0.5 + 0.25 * sin(p.x * 13.0 - TIME * 3.2 + sin(p.y * 7.0)) + 0.25 * sin(p.x * 29.0 + p.y * 5.0 - TIME * 5.0);
}
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float w = wisp(UV);
	ALBEDO = mix(vec3(0.42, 0.82, 0.98), vec3(0.93, 1.0, 1.0), smoothstep(0.45, 0.95, e * (0.7 + 0.4 * w)));
	ALPHA = smoothstep(0.08 + 0.3 * w * UV.x, 0.72, e) * (1.0 - smoothstep(0.82, 1.0, UV.x)) * smoothstep(0.0, 0.05, UV.x) * 0.9;
}
"""

const BLAST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float f = 0.6 + 0.4 * sin(UV.x * 42.0 - TIME * 38.0);
	ALBEDO = mix(vec3(0.3, 0.75, 1.0), vec3(1.0), smoothstep(0.35, 0.9, e * f));
	ALPHA = smoothstep(0.0, 0.45, e) * fade;
}
"""

const MOTE_SH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
void fragment() {
	ALBEDO = vec3(0.72, 0.97, 1.0) * (0.7 + 0.3 * sin(TIME * 11.0 + FRAGCOORD.x * 0.02));
}
"""

const BAT_SH := """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
varying float wing;
void vertex() {
	wing = abs(VERTEX.x);
	VERTEX.y += wing * sin(TIME * 34.0 + float(INSTANCE_ID) * 1.7) * 0.85;
}
void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - wing * 0.22);
}
"""

const SONAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float dash = smoothstep(-0.2, 0.3, sin(UV.x * 34.0));
	ALBEDO = vec3(0.78, 0.8, 0.86);
	ALPHA = e * dash * fade * 0.8;
}
"""

const SMOKE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
float bump(vec2 p) {
	return 0.5 + 0.3 * sin(p.x * 11.0 + sin(p.y * 6.0 + TIME * 1.3) * 1.4 - TIME * 1.1) + 0.2 * sin(p.x * 23.0 - p.y * 9.0 + TIME * 0.9);
}
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float n = bump(UV * vec2(3.0, 1.0));
	ALBEDO = mix(vec3(0.29, 0.28, 0.17), vec3(0.56, 0.54, 0.36), smoothstep(0.2, 0.85, n * e + e * 0.25));
	ALPHA = smoothstep(0.0, 0.3 + 0.28 * n, e) * fade * 0.96;
}
"""

const PUFF_SH := """shader_type spatial;
render_mode unshaded, depth_draw_never, blend_mix;
instance uniform float fade = 1.0;
void fragment() {
	float rim = abs(dot(NORMAL, VIEW));
	float n = 0.5 + 0.5 * sin(UV.x * 37.0 + TIME) * sin(UV.y * 23.0 - TIME * 0.7);
	ALBEDO = mix(vec3(0.3, 0.29, 0.18), vec3(0.58, 0.56, 0.38), n * rim);
	ALPHA = smoothstep(0.08 + 0.2 * n, 0.62, rim) * fade;
}
"""

const FIBER_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float fade = 1.0;
varying vec3 tint;
void vertex() {
	tint = COLOR.rgb;
}
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	float pulse = pow(0.5 + 0.5 * sin(UV.x * 18.0 - TIME * 7.0 + tint.g * 9.0), 3.0);
	ALBEDO = tint * (0.55 + 1.3 * pulse);
	ALPHA = e * (0.35 + 0.65 * pulse) * fade;
}
"""

const CELL_SH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(vec3(0.28, 0.75, 0.62), vec3(0.95, 0.5, 0.42), rim);
	ALPHA = 0.25 + rim * 0.7;
}
"""

const ORB_SH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
float cracks(vec3 p) {
	vec3 q = p * 15.0 + vec3(0.0, TIME * 3.0, TIME * 1.6);
	float a = abs(sin(q.x + sin(q.y * 1.3)) * sin(q.y * 0.8 + sin(q.z)));
	return 1.0 - smoothstep(0.0, 0.14, a);
}
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = mix(vec3(1.0, 0.66, 0.12), vec3(1.0, 0.97, 0.7), cracks(lp) + facing * 0.35);
	ALPHA = 0.55 + cracks(lp) * 0.45;
}
"""

const NEEDLE_SH := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying float along;
void vertex() {
	along = VERTEX.z;
}
void fragment() {
	float tail = smoothstep(-0.3, 0.75, along);
	ALBEDO = mix(vec3(1.0, 0.95, 0.68), vec3(1.0, 0.55, 0.08), tail);
	ALPHA = 1.0 - tail * 0.92;
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


## Kameraya dönük şerit
static func _draw_cam(p, im: ImmediateMesh, pts: Array, w_fn: Callable) -> void:
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
		var w: float = w_fn.call(u)
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
	return n.global_position + Vector3.UP * (float(h) * 0.55 if h != null else 1.0)


static func _rad(n: Node3D) -> float:
	var r = n.get("radius")
	return float(r) if r != null else 0.4


static func _h(n: Node3D) -> float:
	var h = n.get("height")
	return float(h) if h != null else 1.8


static func _bez(a: Vector3, m: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(m, u).lerp(m.lerp(b, u), u)


# ------------------------------------------------------------------ şartlar (CanonRules.block: oyuncu ve yapay zekâ)
static func block(c: Node3D, jid: String) -> String:
	if jid == "kagero_utakata" and Game.now() < float(c.get_meta("utakata_lock", 0.0)):
		return "Bedenin Utakata'yı ikinci kez taşıyamaz."
	if jid == "saibo_kasseijutsu" and _patient(c) == null:
		return "Yanında ağır yaralı bir hasta yok: bu teknik yalnız ölümle pençeleşen birine uygulanır."
	return ""


static func _patient(c: Node3D) -> Node3D:
	var best = null
	var bd = 4.5
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if f == c or not is_instance_valid(f) or not f.has_method("is_dead") or f.is_dead() or Combat.hostile(c, f):
			continue
		var mx = f.get("max_hp")
		if mx == null or float(f.hp) > float(mx) * 0.5:
			continue
		var d = f.global_position.distance_to(c.global_position)
		if d < bd:
			bd = d
			best = f
	return best


# ------------------------------------------------------------------ Kagerō Ninpō: Utakata
## Kanat: kökten uca incelen, ortası şişkin ipeksi şerit
static func _wing_mesh(dir: Vector2, L: float) -> ArrayMesh:
	var k = "wing:%.2f:%.2f:%.2f" % [dir.x, dir.y, L]
	if _c.has(k):
		return _c[k]
	var v = PackedVector3Array()
	var uv = PackedVector2Array()
	var n = PackedVector3Array()
	var d = dir.normalized()
	var perp = Vector2(-d.y, d.x) * signf(d.x)
	for i in 15:
		var s = i / 14.0
		var c = d * L * s + perp * sin(s * PI) * L * 0.09
		var w = (0.05 + 0.2 * sin(pow(s, 0.7) * PI)) * L * 0.42
		for sg in [-1.0, 1.0]:
			var q = c + Vector2(-d.y, d.x) * w * sg
			v.append(Vector3(q.x, q.y, -s * 0.22))
			uv.append(Vector2(s, 0.5 + sg * 0.5))
			n.append(Vector3.BACK)
	var a = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TEX_UV] = uv
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, a)
	_c[k] = m
	return m


## Ateşböceği gibi dağılan ışık taneleri
static func _motes(p, at: Vector3, n: int, spread: float, life: float) -> void:
	if not _c.has("mote"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 5
		sm.rings = 2
		_c["mote"] = sm
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _c["mote"]
	mm.instance_count = n
	var data = []
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		data.append([d * randf_range(0.3, 1.0) * spread, randf_range(0.03, 0.075), randf() * TAU])
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("mote", MOTE_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -12.0, Vector3.ONE * 24.0)
	p.scene_add(mi, at)
	var step = func(t: float) -> void:
		if not is_instance_valid(mi):
			return
		var k = t / life
		var e = 1.0 - pow(1.0 - k, 2.0)
		for i in n:
			var r: Array = data[i]
			var q = (r[0] as Vector3) * e + Vector3.UP * k * 0.8 + Vector3(sin(float(r[2]) + k * 9.0), 0, cos(float(r[2]) + k * 7.0)) * 0.12
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * float(r[1]) * (1.0 - k)), q))
	var tw = mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(mi.queue_free)


## Kanon (Kagerō): dört ateşböceği kanadı, güçlü enerji boşalması, anlık yer değiştirme; kullanan ölümün eşiğinde kalır
static func kagero_utakata(p, c: Node3D, t: Node3D) -> void:
	var id = "kagero_utakata"
	p.busy(c, 2.3)
	p.anim(c, "cast", 0.9)
	c.set_meta("utakata_lock", Game.now() + UTAKATA_LOCK)
	var tt = p.tg(c, t, 24.0)
	var s = {"d": p._face(c, tt), "fired": false, "moved": false, "T": 0.0}
	var dirs = [Vector2(0.72, 0.7), Vector2(-0.72, 0.7), Vector2(0.62, -0.78), Vector2(-0.62, -0.78)]
	var lens = [2.5, 2.5, 2.05, 2.05]
	var holder = Node3D.new()
	p.scene_add(holder, c.global_position)
	var wings = []
	for i in 4:
		var mi = MeshInstance3D.new()
		mi.mesh = _wing_mesh(dirs[i], lens[i])
		mi.material_override = _mat("ut_wing", WING_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 3.0
		holder.add_child(mi)
		wings.append(mi)
	var rays = []
	for i in 4:
		var r = _strip(p, _mat("ut_blast", BLAST_SH))
		rays.append(r)
	var core = _strip(p, _mat("ut_blast", BLAST_SH))
	Sfx.play("charge", c.global_position, 1.35, 0.9)
	var tick = func(_i, k: float) -> void:
		if not p.live(c):
			return
		var T = k * 2.2
		var d: Vector3 = s["d"]
		if T < 0.8 and c is CharacterBody3D:
			c.velocity.y = maxf(c.velocity.y, 1.6)
		var open = smoothstep(0.0, 0.45, T) * (1.0 - smoothstep(1.85, 2.2, T))
		var side = Vector3.UP.cross(d).normalized()
		holder.global_transform = Transform3D(Basis(side, Vector3.UP, d), c.global_position + Vector3.UP * 1.22 - d * 0.2)
		for w in wings:
			w.set_instance_shader_parameter("open_k", maxf(open, 0.001))
		if T >= 0.8 and not bool(s["moved"]):
			s["moved"] = true
			_motes(p, c.global_position + Vector3.UP, 26, 2.0, 0.8)
			if p.live(tt):
				var to: Vector3 = tt.global_position - d.rotated(Vector3.UP, 0.5) * 6.5
				to.y = maxf(p.gp(to).y, tt.global_position.y)
				c.global_position = PlayerCombat.safe_dest(c, c.global_position, to)
				s["d"] = p._face(c, tt)
			Sfx.play("whoosh", c.global_position, 1.5, 0.8)
		if T >= 1.15 and T < 1.85:
			var fk = sin(clampf((T - 1.15) / 0.7, 0.0, 1.0) * PI)
			var nd: Vector3 = s["d"]
			var from = c.global_position + Vector3.UP * 1.22
			var aim: Vector3 = _chest(tt) if p.live(tt) else from + nd * 18.0
			var conv = from.lerp(aim, 0.28)
			for i in 4:
				var loc = Vector3(dirs[i].x, dirs[i].y, 0.0).normalized() * lens[i] * 0.92
				var tip = holder.to_global(loc)
				var pts = []
				for j in 11:
					pts.append(_bez(tip, conv, aim, j / 10.0))
				var wf = func(u: float) -> float:
					return (0.05 + 0.12 * sin(u * PI)) * fk
				_draw_cam(p, rays[i][1], pts, wf)
			var cw = func(u: float) -> float:
				return (0.06 + 0.42 * smoothstep(0.2, 0.45, u)) * fk
			_draw_cam(p, core[1], [conv, conv.lerp(aim, 0.25), conv.lerp(aim, 0.5), conv.lerp(aim, 0.75), aim], cw)
		elif T >= 1.85:
			for r in rays:
				(r[1] as ImmediateMesh).clear_surfaces()
			(core[1] as ImmediateMesh).clear_surfaces()
		if T >= 1.3 and not bool(s["fired"]):
			s["fired"] = true
			_utakata_blast(p, c, tt, id, s["d"])
	var done = func() -> void:
		_free(holder)
		for r in rays:
			_free(r[0])
		_free(core[0])
		if not p.live(c):
			return
		c.hp = minf(c.hp, maxf(1.0, float(c.max_hp) * 0.05))
		if c.get("chakra") != null:
			c.chakra = 0.0
		p.st(c, "stun", 1.8)
		Combat.popup_text(c.global_position + Vector3.UP * 2.3, "Ölümün eşiğinde!", Color(0.7, 0.92, 1.0))
	p.every(2.2, STEP, tick, done)


static func _utakata_blast(p, c: Node3D, tt, id: String, d: Vector3) -> void:
	var from = c.global_position + Vector3.UP * 1.2
	var to: Vector3 = _chest(tt) if p.live(tt) else from + d * 18.0
	var done: Array = []
	var inf: Dictionary = p.inf(c, id, 1.0, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.12})
	for k in 7:
		var hits = p.hit(c, from.lerp(to, (k + 1) / 7.0), 1.7, inf, done)
		done.append_array(hits)
	_motes(p, to, 40, 3.2, 1.1)
	Sfx.play("boom", to, 1.4, 0.9)
	if Game.world != null and Game.world.get("env") != null:
		Game.world.env.add_shake(0.5)


# ------------------------------------------------------------------ Kōmori Seichū
static func _bat_mesh() -> ArrayMesh:
	if _c.has("bat"):
		return _c["bat"]
	var b = MB.new()
	var fur = Color(0.27, 0.2, 0.17)
	var skin = Color(0.36, 0.28, 0.25)
	b.add("sphere", Vector3(0, 0, 0.02), Vector3(0.1, 0.09, 0.2), fur, Vector3.ZERO, 6)
	b.add("sphere", Vector3(0, 0.01, -0.11), Vector3.ONE * 0.08, fur, Vector3.ZERO, 5)
	for s in [-1.0, 1.0]:
		b.add("cone", Vector3(s * 0.024, 0.06, -0.12), Vector3(0.025, 0.06, 0.016), fur)
		var o = PackedVector2Array([Vector2(0.09, 0.03), Vector2(-0.06, 0.03), Vector2(0.0, -0.1), Vector2(-0.075, -0.2), Vector2(-0.015, -0.27), Vector2(-0.08, -0.38), Vector2(0.12, -0.34)])
		var pts = PackedVector2Array()
		for q in o:
			pts.append(Vector2(q.x * -1.0, q.y * s))
		b.add_slab(pts, 0.006, skin, Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT), Vector3.ZERO))
	var m = b.build(null)
	_c["bat"] = m
	return m


## Kanon (Rinji): ultrasesle yarasalara söz geçirir: çevreyi aratır, onlara güçlü ses dalgası saldırttırır
static func komori_seichu(p, c: Node3D, t: Node3D) -> void:
	var id = "komori_seichu"
	p.busy(c, 0.7)
	p.anim(c, "cast", 1.5)
	Combat.start_sensing(c, 30.0, 14.0)
	var tt = p.tg(c, t, 26.0)
	var d: Vector3 = p._face(c, tt)
	var n = 16
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _bat_mesh()
	mm.instance_count = n
	var seeds = []
	for i in n:
		seeds.append([randf() * TAU, randf_range(0.8, 1.7), randf_range(0.7, 1.25), randf_range(0.0, 0.2)])
		var g = randf_range(0.85, 1.1)
		mm.set_instance_color(i, Color(g, g, g))
	var mi = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat("bat", BAT_SH)
	mi.custom_aabb = AABB(Vector3.ONE * -60.0, Vector3.ONE * 120.0)
	p.scene_add(mi, Vector3.ZERO)
	mi.global_transform = Transform3D.IDENTITY
	var start = p.hand_pos(c, true)
	var s = {"wave": 0, "prev": {}}
	Sfx.play("whoosh", start, 1.8, 0.7)
	var T = 4.2
	var tick = func(_i, k: float) -> void:
		var live_t = p.live(tt)
		var now = k * T
		var cen: Vector3 = _chest(tt) + Vector3.UP * 0.5 if live_t else c.global_position + Vector3.UP * 2.4 + d * 7.0
		var R = 1.5 if live_t else 7.0
		for i in n:
			var e: Array = seeds[i]
			var a = float(e[0]) + now * 2.6 * float(e[2])
			var orbit = cen + Vector3(cos(a) * R * float(e[1]) * 0.75, sin(a * 1.7) * 0.55, sin(a) * R * float(e[1]) * 0.75)
			var go = smoothstep(float(e[3]), float(e[3]) + 0.55, now)
			var back = smoothstep(3.6, 4.2, now)
			var q = start.lerp(orbit, go) + Vector3.UP * sin(go * PI) * 1.4
			q = q.lerp(q + Vector3(cos(a), 1.2, sin(a)) * 16.0, back * back)
			var prev: Vector3 = s["prev"].get(i, q - Vector3.FORWARD * 0.1)
			var v = q - prev
			s["prev"][i] = q
			var z = -v.normalized() if v.length() > 0.001 else Vector3.BACK
			var x = Vector3.UP.cross(z)
			x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
			var sc = float(e[2]) * 1.15 * (1.0 - back)
			mm.set_instance_transform(i, Transform3D(Basis(x, z.cross(x), z).scaled(Vector3.ONE * maxf(sc, 0.001)), q))
		var w = int((now - 0.75) / 0.5)
		if live_t and now >= 0.75 and now < 3.5 and w >= int(s["wave"]):
			s["wave"] = w + 1
			_sonar(p, _chest(tt), _h(tt))
			if p.live(c):
				var hits = p.hit(c, _chest(tt), 2.6, p.inf(c, id, 0.2, {"knock": 0.4, "kind": "light", "hitstop": 0.0}))
				for h in hits:
					p.st(h, "slow", 1.4)
					if w % 2 == 0:
						p.st(h, "stun", 0.35)
	var done = func() -> void:
		_free(mi)
	p.every(T, STEP, tick, done)


## Ses dalgası: kesik, ince, genişleyen yaylar
static func _sonar(p, at: Vector3, h: float) -> void:
	for k in 3:
		var r = _strip(p, _mat("sonar", SONAR_SH))
		var mi: MeshInstance3D = r[0]
		var im: ImmediateMesh = r[1]
		var ax = Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)).normalized()
		var u = ax.cross(Vector3.RIGHT).normalized()
		var v = ax.cross(u).normalized()
		var a0 = randf() * TAU
		var R0 = 0.45 + k * 0.25
		var cen = at + Vector3.UP * (k - 1) * h * 0.18
		var step = func(q: float) -> void:
			if not is_instance_valid(mi):
				return
			var rr = R0 + q * 2.0
			im.clear_surfaces()
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for j in 25:
				var w = j / 24.0
				var a = a0 + w * TAU * 0.72
				var e = u * cos(a) + v * sin(a)
				im.surface_set_uv(Vector2(w, 0))
				im.surface_add_vertex(cen + e * (rr - 0.035))
				im.surface_set_uv(Vector2(w, 1))
				im.surface_add_vertex(cen + e * (rr + 0.035))
			im.surface_end()
			mi.set_instance_shader_parameter("fade", 1.0 - q)
		var tw = mi.create_tween()
		tw.tween_method(step, 0.0, 1.0, 0.42)
		tw.tween_callback(mi.queue_free)
	Sfx.play("zap", at, 2.4, 0.22)


# ------------------------------------------------------------------ Enmaku Rō
## Duman klon: iri, yumuşak kütlelerden insan siluet yığını
static func _smoke_body(p, at: Vector3) -> Array:
	var parts = []
	for e in [[0.2, 0.3], [0.55, 0.42], [0.95, 0.5], [1.32, 0.44], [1.68, 0.27]]:
		var sm = SphereMesh.new()
		sm.radius = float(e[1])
		sm.height = float(e[1]) * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		var mi = MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = _mat("enmaku_kutle", PUFF_SH)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.scene_add(mi, at + Vector3.UP * float(e[0]))
		mi.rotation = Vector3(randf(), randf() * TAU, randf())
		parts.append(mi)
	return parts


## Kanon (Kigiri): duman klonları dağılır, gövdelerindeki duman hedefe sarılıp onu bağlar. Kısa menzil
static func enmaku_ro(p, c: Node3D, t: Node3D) -> void:
	var id = "enmaku_ro"
	p.busy(c, 0.75)
	p.anim(c, "cast", 1.4)
	var tt = p.tg(c, t, 11.0)
	var d: Vector3 = p._face(c, tt)
	var side = Vector3.UP.cross(d).normalized()
	var ps = [p.gp(c.global_position + side * 1.5 + d * 0.8), p.gp(c.global_position - side * 1.5 + d * 0.8)]
	var bodies = [_smoke_body(p, ps[0]), _smoke_body(p, ps[1])]
	var bands = [_strip(p, _mat("smoke_band", SMOKE_SH)), _strip(p, _mat("smoke_band", SMOKE_SH))]
	var coil = _strip(p, _mat("smoke_band", SMOKE_SH))
	var s = {"bound": false}
	Sfx.play("wind", ps[0], 0.75, 0.7)
	var T = 4.1
	var tick = func(_i, k: float) -> void:
		var now = k * T
		var fade_b = 1.0 - smoothstep(0.42, 0.85, now)
		for b in bodies:
			for q in b:
				if is_instance_valid(q):
					q.set_instance_shader_parameter("fade", smoothstep(0.0, 0.2, now) * fade_b)
					q.scale = Vector3.ONE * (1.0 + (1.0 - fade_b) * 0.5)
		if not p.live(tt):
			for r in bands:
				(r[1] as ImmediateMesh).clear_surfaces()
			(coil[1] as ImmediateMesh).clear_surfaces()
			return
		var ch = _h(tt)
		var rr = _rad(tt) + 0.14
		var base = tt.global_position
		var grow = smoothstep(0.42, 0.95, now)
		var gone = smoothstep(3.75, 4.1, now)
		var cross = base + Vector3.UP * ch * 1.15 + d * -0.9
		for i in 2:
			var a: Vector3 = ps[i] + Vector3.UP * 1.0
			var tip = base + Vector3.UP * ch * 0.72 + side * rr * (1.0 if i == 1 else -1.0)
			var pts = []
			var from_u = gone
			for j in 15:
				var u = lerpf(from_u, maxf(grow, from_u + 0.001), j / 14.0)
				pts.append(_bez(a, cross, tip, u))
			var wf = func(u: float) -> float:
				return 0.1 + 0.26 * pow(1.0 - u, 1.5)
			_draw_cam(p, bands[i][1], pts, wf)
		var wk = smoothstep(0.8, 1.15, now) * (1.0 - gone)
		var im: ImmediateMesh = coil[1]
		im.clear_surfaces()
		if wk > 0.01:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			var n = 56
			for j in n + 1:
				var u = j / float(n) * wk
				var a = u * TAU * 3.3 + now * 0.5
				var e = Vector3(cos(a), 0.0, sin(a))
				var y = ch * (0.74 - u * 0.68)
				var c0 = base + Vector3.UP * y + e * rr * (0.96 + 0.08 * sin(u * 19.0))
				im.surface_set_normal(e)
				im.surface_set_uv(Vector2(u * 3.0, 0))
				im.surface_add_vertex(c0 + Vector3.UP * 0.16)
				im.surface_set_uv(Vector2(u * 3.0, 1))
				im.surface_add_vertex(c0 - Vector3.UP * 0.16)
			im.surface_end()
		if now >= 0.95 and not bool(s["bound"]):
			s["bound"] = true
			p.st(tt, "bind", 2.9)
			if p.live(c):
				tt.take_hit(p.inf(c, id, 0.5, {"knock": 0.0, "kind": "light", "hitstop": 0.03, "dir": Vector3.ZERO}))
			Sfx.play("wind", base, 0.6, 0.8)
	var done = func() -> void:
		for b in bodies:
			for q in b:
				_free(q)
		for r in bands:
			_free(r[0])
		_free(coil[0])
	p.every(T, STEP, tick, done)


# ------------------------------------------------------------------ Saibō no Kasseijutsu
static func _fiber_mesh(h: float, r: float) -> ArrayMesh:
	var k = "fiber:%.2f:%.2f" % [h, r]
	if _c.has(k):
		return _c[k]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red = Color(0.95, 0.24, 0.17)
	var teal = Color(0.25, 0.85, 0.72)
	for f in 22:
		var a0 = TAU * f / 22.0
		var col = teal if f % 3 == 0 else red
		var tw = 0.5 + 0.35 * sin(f * 2.3)
		var rows = 11
		var prev = []
		for j in rows + 1:
			var s = j / float(rows)
			var y = lerpf(0.12, h * 0.9, s)
			var body = 1.0 + 0.16 * sin(s * PI * 1.0) - 0.28 * smoothstep(0.78, 1.0, s)
			var a = a0 + (s - 0.5) * tw + 0.07 * sin(s * 13.0 + f)
			var e = Vector3(cos(a), 0, sin(a))
			var t = Vector3(-sin(a), 0, cos(a))
			var c = Vector3(0, y, 0) + e * r * body
			var row = [c - t * 0.012, c + t * 0.012, s]
			if not prev.is_empty():
				for q in [[prev[0], prev[2], 0.0], [prev[1], prev[2], 1.0], [row[1], s, 1.0], [prev[0], prev[2], 0.0], [row[1], s, 1.0], [row[0], s, 0.0]]:
					st.set_color(col)
					st.set_uv(Vector2(q[1], q[2]))
					st.set_normal(e)
					st.add_vertex(q[0])
			prev = row
	var m = st.commit()
	_c[k] = m
	return m


## Kanon (Tsunade): rafine chakra hastanın tüm hücrelerini aynı anda uyandırır; ameliyat sürerken doku ve kemik onarılır.
## Yalnız ağır yaralı hastaya, ellerin üstündeyken: bölünürse tedavi yarıda kalır
static func saibo_kasseijutsu(p, c: Node3D, _t: Node3D) -> void:
	var pat = _patient(c)
	if pat == null:
		return
	var T = 3.6
	p.busy(c, T)
	p.anim(c, "cast", 0.8)
	var ph = _h(pat)
	var pr = _rad(pat) + 0.05
	var fib = MeshInstance3D.new()
	fib.mesh = _fiber_mesh(ph, pr)
	fib.material_override = _mat("fiber", FIBER_SH)
	fib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pat.add_child(fib)
	if not _c.has("cell"):
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 7
		sm.rings = 4
		_c["cell"] = sm
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _c["cell"]
	mm.instance_count = 26
	var cells = []
	for i in 26:
		var a = randf() * TAU
		cells.append([Vector3(cos(a) * pr * 1.02, randf_range(0.2, ph * 0.86), sin(a) * pr * 1.02), randf() * TAU, randf_range(0.035, 0.07)])
	var cm = MultiMeshInstance3D.new()
	cm.multimesh = mm
	cm.material_override = _mat("cell", CELL_SH)
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cm.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	pat.add_child(cm)
	var threads = [_strip(p, _mat("fiber_line", BLAST_SH)), _strip(p, _mat("fiber_line", BLAST_SH))]
	var s = {"hp": float(c.hp), "ok": true, "beat": 0}
	Combat.popup_text(pat.global_position + Vector3.UP * (ph + 0.4), "Saibō no Kasseijutsu", Color(0.55, 1.0, 0.8))
	Sfx.play("seal", pat.global_position, 0.8, 0.7)
	var cleanup = func() -> void:
		_free(fib)
		_free(cm)
		for r in threads:
			_free(r[0])
	var tick = func(_i, k: float) -> void:
		if not bool(s["ok"]):
			return
		if not p.live(c) or not p.live(pat) or float(c.hp) < float(s["hp"]) - 0.01 or c.global_position.distance_to(pat.global_position) > 5.5:
			s["ok"] = false
			if p.live(c):
				Combat.popup_text(c.global_position + Vector3.UP * 2.2, "Tedavi bölündü!", Color(1.0, 0.6, 0.5))
			cleanup.call()
			return
		var now = k * T
		var a = smoothstep(0.0, 0.5, now)
		fib.set_instance_shader_parameter("fade", a)
		for i in 26:
			var e: Array = cells[i]
			var q = 0.5 + 0.5 * sin(now * 5.0 + float(e[1]))
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1.0 + q * 0.7, 1.0, 1.0) * float(e[2]) * a), e[0]))
		var to = _chest(pat)
		for i in 2:
			var h: Vector3 = p.hand_pos(c, i == 0)
			var m = h.lerp(to, 0.5) + Vector3.UP * (0.12 + 0.05 * sin(now * 6.0 + i))
			var pts = []
			for j in 9:
				pts.append(_bez(h, m, to, j / 8.0))
			var wf = func(_u: float) -> float:
				return 0.018
			_draw_cam(p, threads[i][1], pts, wf)
		var b = int(now / 0.45)
		if b > int(s["beat"]) and b <= 8:
			s["beat"] = b
			p.heal(pat, float(pat.max_hp) * 0.045)
	var done = func() -> void:
		if bool(s["ok"]):
			cleanup.call()
	p.every(T, STEP, tick, done)


# ------------------------------------------------------------------ Chakura no Hari
static func _needle_mesh() -> ArrayMesh:
	if _c.has("needle"):
		return _c["needle"]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip = Vector3(0, 0, -0.3)
	var tail = Vector3(0, 0, 0.75)
	for k in 4:
		var a0 = TAU * k / 4.0
		var a1 = TAU * (k + 1) / 4.0
		var p0 = Vector3(cos(a0), sin(a0), 0) * 0.028 + Vector3(0, 0, -0.14)
		var p1 = Vector3(cos(a1), sin(a1), 0) * 0.028 + Vector3(0, 0, -0.14)
		for q in [tip, p0, p1, p0, tail, p1]:
			st.add_vertex(q)
	var m = st.commit()
	_c["needle"] = m
	return m


static func _needle(p) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _needle_mesh()
	mi.material_override = _mat("needle", NEEDLE_SH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Kanon (Hinoko): parmak ucundan her zaman hedefi bulan chakra iğneleri; iğnenin niteliği değişir: felç eder, öldürür ya da canlandırır
static func chakura_no_hari(p, c: Node3D, t: Node3D) -> void:
	var id = "chakura_no_hari"
	p.busy(c, 0.72)
	p.anim(c, "cast", 1.7)
	var tt = p.tg(c, t, 26.0)
	var d: Vector3 = p._face(c, tt)
	var ally: Node3D = null
	if tt == null:
		var al = p._ally_for(c, 18.0)
		if al != c and float(al.hp) < float(al.max_hp):
			ally = al
	var sm = SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	sm.radial_segments = 16
	sm.rings = 10
	var orb = MeshInstance3D.new()
	orb.mesh = sm
	orb.material_override = _mat("orb", ORB_SH)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.scene_add(orb, p.hand_pos(c, true))
	Sfx.play("zap", orb.global_position, 1.7, 0.45)
	var hold = func(_i, k: float) -> void:
		if is_instance_valid(orb) and p.live(c):
			orb.global_position = p.hand_pos(c, true) + d * 0.1
			orb.scale = Vector3.ONE * (0.4 + k * 0.9)
	var fire = func() -> void:
		_free(orb)
		if not p.live(c):
			return
		_needles(p, c, tt, ally, d, id)
	p.every(0.34, STEP, hold, fire)


static func _needles(p, c: Node3D, tt, ally, d: Vector3, id: String) -> void:
	var from = p.hand_pos(c, true) + d * 0.15
	var s = {"n": 0}
	for k in 5:
		var fan = (k - 2) * 0.17
		var dir = (d.rotated(Vector3.UP, fan) + Vector3.UP * (0.08 + absf(fan) * 0.25)).normalized()
		var go = func() -> void:
			if not p.live(c):
				return
			Sfx.play("zap", from, 2.3, 0.2)
			if ally != null:
				_heal_needle(p, ally, from, dir)
				return
			var on_h = func(_pos: Vector3, h: Node3D) -> void:
				if h == null or not p.live(h) or not p.live(c):
					return
				s["n"] += 1
				if int(s["n"]) != 3:
					return
				if float(h.hp) <= float(h.max_hp) * 0.2:   # öldürücü nitelik
					h.take_hit(p.inf(c, id, 0.8, {"knock": 0.5, "kind": "heavy", "hitstop": 0.08, "dir": d}))
					Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Öldürücü iğne!", Color(1.0, 0.75, 0.3))
				else:   # felç niteliği
					p.st(h, "paralyze", 1.5)
					Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Felç!", Color(1.0, 0.86, 0.45))
			var info: Dictionary = p.inf(c, id, 0.2, {"knock": 0.2, "kind": "light", "hitstop": 0.01, "sure": true})
			var pr = p.shot(c, from, dir, 30.0, _needle(p), info, tt, false, 2.0, on_h)
			pr.homing_turn = 15.0
			pr.radius = 0.2
		p.after(k * 0.055, go)


## Canlandıran nitelik: iğne yaralı dosta süzülür
static func _heal_needle(p, ally: Node3D, from: Vector3, dir: Vector3) -> void:
	var mi = _needle(p)
	p.scene_add(mi, from)
	var ctrl = from + dir * 4.0
	var last = {"q": from}
	var tick = func(_i, k: float) -> void:
		if not is_instance_valid(mi) or not p.live(ally):
			return
		var q = _bez(from, ctrl, _chest(ally), k)
		var v: Vector3 = q - (last["q"] as Vector3)
		if v.length() > 0.001:
			mi.look_at_from_position(q, q + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT)
		last["q"] = q
	var done = func() -> void:
		_free(mi)
		if p.live(ally):
			p.heal(ally, float(ally.max_hp) * 0.03)
	p.every(0.55, STEP, tick, done)
