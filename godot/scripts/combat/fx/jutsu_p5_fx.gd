extends RefCounted
## Parti 5 (hedef: res://scripts/combat/fx/jutsu_p5_fx.gd). Görünen her şey bu dosyanın kendi gölgelendirici ve geometrisi.
## Eikesō: I, Sumerudama, Enryū, Konshin Betsuri no Jutsu, Kuchiyose: Aian Meiden. Kaynak görseller: refs/new/<id>/

static var _mats := {}
static var _meshes := {}


# ------------------------------------------------------------------ küçük altyapı
static func _mat(key: String, code: String) -> ShaderMaterial:
	if not _mats.has(key):
		var sh = Shader.new()
		sh.code = code
		var m = ShaderMaterial.new()
		m.shader = sh
		_mats[key] = m
	return _mats[key]


static func _node(mesh: Mesh, m: Material, half := 12.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -half, Vector3.ONE * half * 2.0)
	return mi


static func _cards(n: int, fn: Callable) -> ArrayMesh:
	var v = PackedVector3Array()
	var c = PackedColorArray()
	var u = PackedVector2Array()
	var idx = PackedInt32Array()
	for i in n:
		var e: Array = fn.call(i)
		var b = v.size()
		for q in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			v.append(e[0])
			c.append(e[1])
			u.append(q)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var a = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_TEX_UV] = u
	a[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


static func _param(mi: GeometryInstance3D, p: String, a: float, b: float, t: float, free_after := false) -> void:
	mi.set_instance_shader_parameter(p, a)
	var tw = mi.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter(p, v), a, b, t)
	if free_after:
		tw.tween_callback(mi.queue_free)


static func _bone(c: Node3D, bone: String, fallback: float) -> Vector3:
	var m = c.get("model")
	if m != null and m.get("skel") != null:
		var i = m.skel.find_bone(bone)
		if i >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(i)).origin
	return c.global_position + Vector3.UP * fallback


static func _grounded(e: Node3D) -> bool:
	if e is Player:
		return bool(e.get("grounded"))
	if e is CharacterBody3D and e.is_on_floor():
		return true
	return e.global_position.y - Game.ground_height(e.global_position.x, e.global_position.z) < 0.4   # arazi yükseklik fonksiyonu: is_on_floor çimende güvenilmez


# ------------------------------------------------------------------ 1 Eikesō: I (ref Fuguki_fights_the_Third_Division.png): baştan her yöne yassı saç mızrakları
static func _spear_mesh(col: Color) -> ArrayMesh:
	var key = "eikeso_" + col.to_html(false)
	if _meshes.has(key):
		return _meshes[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 8
	var rings = []
	for i in n + 1:
		var t = float(i) / n
		var w = lerpf(0.05, 0.17, smoothstep(0.0, 0.16, t)) * pow(1.0 - t, 0.72) + 0.002
		var h = w * 0.2 + 0.002
		var z = -t
		rings.append([Vector3(-w, 0, z), Vector3(0, h, z), Vector3(w, 0, z), Vector3(0, -h, z)])
	var ridge = col.lightened(0.2)
	var dark = col.darkened(0.2)
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for q in 4:
			var q2 = (q + 1) % 4
			var cs = [a[q], b[q], b[q2], a[q], b[q2], a[q2]]
			for k in 6:
				var p: Vector3 = cs[k]
				st.set_color(ridge if absf(p.x) < 0.001 else (dark if q >= 2 else col))
				st.add_vertex(p)
	st.generate_normals()
	_meshes[key] = st.commit()
	return _meshes[key]


static func eikeso_i(pj, c: Node3D, t: Node3D) -> void:
	var id = "eikeso_i"
	pj.busy(c, 0.85)
	pj.anim(c, "cast", 1.6)
	var d: Vector3 = pj._face(c, pj.tg(c, t, 13.0))
	var side: Vector3 = Vector3.UP.cross(d).normalized()
	var look = c.get("look")
	var col = Color(0.5, 0.2, 0.17)
	if look is Dictionary and look.get("hair") is Color:
		col = look["hair"]
	var mesh = _spear_mesh(col)
	var mat = Props.toon()
	var head: Vector3 = _bone(c, "Head", 1.65)
	var aims = []
	var foes = pj.enemies_near(c, c.global_position, 13.0)
	foes.sort_custom(func(a, b): return a.global_position.distance_to(head) < b.global_position.distance_to(head))
	for e in foes.slice(0, 7):
		aims.append([(e.global_position + Vector3.UP * 1.1 - head), e])
	for k in 13:   # yelpaze: ref'teki gibi baştan her yöne, çoğu yukarı ve yanlara
		var a = k * TAU / 13.0
		var dir: Vector3 = (side * cos(a) + Vector3.UP * (sin(a) * 0.8 + 0.35) - d * 0.3).normalized()
		aims.append([dir * randf_range(5.0, 8.0), null])
	var nodes = []
	for e in aims:
		var v: Vector3 = e[0]
		var root = Node3D.new()
		pj.scene_add(root, head)
		root.look_at(head + v, Vector3.UP if absf(v.normalized().y) < 0.97 else Vector3.RIGHT)
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		root.add_child(mi)
		mi.scale = Vector3(1.0, 1.0, 0.01)
		var L = v.length()
		var width = clampf(L * 0.16, 0.7, 1.5)
		var tw = mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(width, width, L), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.42)
		tw.tween_property(mi, "scale", Vector3(width * 0.5, width * 0.5, 0.01), 0.17).set_ease(Tween.EASE_IN)
		tw.tween_callback(root.queue_free)
		nodes.append(root)
	var cw = weakref(c)
	pj.every(0.7, 1.0 / 30.0, func(_i, _k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc):
			return
		var hp: Vector3 = _bone(cc, "Head", 1.65)
		for r in nodes:
			if is_instance_valid(r):
				r.global_position = hp)
	pj.after(0.1, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		Sfx.play("hit_blade", head, 0.75, 0.8)
		for e in aims:
			var f = e[1]
			if f != null and pj.live(f):
				f.take_hit(pj.inf(cc, id, 0.8, {"knock": 2.0, "launch": 2.5, "kind": "heavy", "bleed": 3.0, "blade": true, "hitstop": 0.05}))
				pj.st(f, "stun", 0.55))


# ------------------------------------------------------------------ 2 Sumerudama (ref Smell_Sphere_1/2): mor kokulu nefes küresi, sivri fışkıran bulut
const SPHERE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float t = TIME * 3.0;
	float e = 0.76 + 0.09 * sin(a * 3.0 + t) + 0.06 * sin(a * 7.0 - t * 1.4);
	float r = length(p);
	if (r > e + 0.13) discard;
	vec3 c = vec3(1.0);
	if (r < e) {
		float b = sin(p.x * 5.0 + t) * cos(p.y * 4.0 - t * 0.7) + p.y * 0.8;
		c = b > 0.45 ? vec3(0.84, 0.62, 0.92) : (b > -0.25 ? vec3(0.66, 0.36, 0.82) : vec3(0.47, 0.2, 0.66));
	}
	ALBEDO = c;
}
"""

const GAS_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
varying float sd;
varying vec2 st;
void vertex() {
	sd = COLOR.r;
	float e = 1.0 - pow(1.0 - min(prog * 3.0, 1.0), 3.0);
	vec3 c = VERTEX * e;
	c.y = max(c.y, 0.1) + sin(TIME * 0.8 + sd * 30.0) * 0.1;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	vec4 o = MODELVIEW_MATRIX * vec4(0.0, 1.8, 0.0, 1.0);
	vec2 dir = v.xy - o.xy;
	float l = length(dir);
	dir = l > 0.01 ? dir / l : vec2(0.0, 1.0);
	float stretch = mix(3.0, 1.15, min(prog * 2.2, 1.0));
	vec2 q = (UV - 0.5) * (0.75 + COLOR.g * 1.05);
	q.y *= stretch;
	v.xy += vec2(dir.y, -dir.x) * q.x + dir * q.y;
	st = UV;
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	// ref: içi dolu, damla biçimli mor loblar; açık kontur, boyuna akan beyaz parıltı çizgileri
	vec2 p = st * 2.0 - 1.0;
	float y = p.y * 0.5 + 0.5;
	float w = sqrt(max(0.0, 1.0 - p.y * p.y)) * mix(0.3, 1.0, smoothstep(0.0, 0.75, y));
	w *= 0.93 + 0.07 * sin(p.y * 6.0 + sd * 40.0 + TIME * 0.7);
	if (abs(p.x) > w) discard;
	float s = p.x / max(w, 0.001);
	float tone = smoothstep(-0.5, 0.6, s + p.y * 0.35);
	vec3 c = mix(vec3(0.42, 0.16, 0.62), vec3(0.6, 0.31, 0.8), tone);
	float wob = sin(p.y * 4.0 + sd * 31.0) * 0.1 + sin(p.y * 9.0 + sd * 13.0) * 0.04;
	float len = smoothstep(-0.55, -0.1, p.y) * (1.0 - smoothstep(0.45, 0.8, p.y));
	float th = (0.05 + 0.07 * fract(sd * 7.0)) * len;
	if (abs(s + 0.42 - wob) < th || abs(s - 0.2 - wob * 1.4) < th * 0.55) c = vec3(0.94, 0.88, 0.98);
	if (abs(s) > 0.9) c = vec3(0.86, 0.73, 0.95);
	ALBEDO = c;
	ALPHA = 0.88 * fade;
}
"""


static func _smell_hit(pj, c: Node3D, e: Node3D, id: String) -> void:
	var nose = e is Ninken
	if e.get("arch") is Dictionary and str(e.arch.get("clan", "")) == "inuzuka":
		nose = true
	if e is Player and str(Game.profile.get("clan", "")) == "inuzuka":
		nose = true
	e.take_hit(pj.inf(c, id, 0.25, {"knock": 0.0, "kind": "light", "hitstop": 0.0}))
	pj.st(e, "stun", 2.4 if nose else 1.3)   # kanon: gaz felç eder, koku alan iz sürücüler en ağır etkilenir
	if e.has_method("lose_target"):
		e.lose_target(7.0 if nose else 3.5)
	elif e is Player and e.combat != null:
		e.combat.lock_target = null
	Combat.popup_text(e.global_position + Vector3.UP * 2.2, "Koku!", Color(0.8, 0.55, 0.95))


static func _gas(pj, c: Node3D, at: Vector3, id: String) -> void:
	var dur = 6.0
	var root = Node3D.new()
	pj.scene_add(root, at)
	var mi = _node(_cards(60, func(_i):
		var a = randf() * TAU
		var r = pow(randf(), 0.55) * 5.8
		return [Vector3(cos(a) * r, randf_range(0.3, 5.2) * (1.0 - r / 8.5), sin(a) * r), Color(randf(), randf(), 0, 1)]), _mat("sumeru_gaz", GAS_SH), 12.0)
	root.add_child(mi)
	_param(mi, "prog", 0.0, 1.0, dur)
	Sfx.play("poof", at, 0.65, 0.9)
	var cw = weakref(c)
	var last := {}
	pj.every(dur, 0.2, func(_i, _k):
		var cc = cw.get_ref()
		if cc == null or not is_instance_valid(cc) or cc.is_dead():
			return
		for e in pj.enemies_near(cc, at, 5.6):
			var key = e.get_instance_id()
			if Game.now() >= float(last.get(key, 0.0)):
				last[key] = Game.now() + 4.0
				_smell_hit(pj, cc, e, id), func():
		if is_instance_valid(mi):
			_param(mi, "fade", 1.0, 0.0, 0.7)
		if is_instance_valid(root):
			root.get_tree().create_timer(0.75).timeout.connect(root.queue_free))


static func sumerudama(pj, c: Node3D, t: Node3D) -> void:
	var id = "sumerudama"
	var tt = pj.tg(c, t, 24.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.55)
	pj.anim(c, "cast_out", 1.5)
	var from: Vector3 = _bone(c, "Head", 1.6) + d * 0.3 + Vector3.DOWN * 0.05
	var dir = d
	if tt:
		dir = (tt.global_position + Vector3.UP * 1.0 - from).normalized()
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = dir * 15.0
	pr.gravity = 1.5
	pr.radius = 0.5
	pr.life = 2.0
	pr.info = pj.inf(c, id, 0.1, {"knock": 0.0, "kind": "light", "hitstop": 0.0})
	var q = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2.ONE * 1.5
	q.mesh = qm
	q.material_override = _mat("sumeru_kure", SPHERE_SH)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.extra_cull_margin = 2.0
	pr.add_child(q)
	var cw = weakref(c)
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		var cc = cw.get_ref()
		if cc != null and is_instance_valid(cc):
			_gas(pj, cc, pj.gp(pos), id)
	c.get_tree().current_scene.add_child(pr)
	pr.global_position = from
	Sfx.play("whoosh", from, 0.7, 0.5)


# ------------------------------------------------------------------ 3 Enryū (ref Smoke_Dragon.png): bileğe bağlı, soluk cel duman ejderi
const PUFF_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
instance uniform float size = 1.0;
instance uniform float sd = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= size;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.86 + 0.07 * sin(a * 4.0 + sd * 30.0 + TIME * 1.6) + 0.04 * sin(a * 9.0 - TIME + sd * 9.0);
	float r = length(p);
	if (r > e) discard;
	float l = dot(normalize(vec3(p / e, sqrt(max(1.0 - r * r / (e * e), 0.0)))), normalize(vec3(-0.3, 0.8, 0.5)));
	ALBEDO = l > 0.25 ? vec3(0.74, 0.76, 0.68) : (l > -0.2 ? vec3(0.6, 0.63, 0.55) : vec3(0.45, 0.48, 0.42));
}
"""


static func _dragon_head() -> ArrayMesh:
	if _meshes.has("enryu_bas"):
		return _meshes["enryu_bas"]
	var b = MB.new()
	var g = Color(0.72, 0.75, 0.67)
	var d = Color(0.52, 0.55, 0.48)
	b.add("sphere", Vector3(0, 0.12, 0.25), Vector3(1.25, 0.85, 1.6), g, Vector3.ZERO, 10)
	b.add("sphere", Vector3(0, 0.03, -0.75), Vector3(0.82, 0.48, 1.75), g, Vector3.ZERO, 10)   # burun
	b.add("sphere", Vector3(0, -0.3, -0.45), Vector3(0.68, 0.22, 1.6), d, Vector3(-9, 0, 0), 8)   # alt çene
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(0.36 * sx, 0.52, 0.95), Vector3(0.24, 1.35, 0.3), g, Vector3(-68, 0, -10 * sx), 5)   # boynuz
		b.add("cone", Vector3(0.62 * sx, 0.1, 0.8), Vector3(0.2, 0.8, 0.16), d, Vector3(-80, 0, -38 * sx), 4)
		b.add("box", Vector3(0.39 * sx, 0.28, -0.32), Vector3(0.05, 0.1, 0.34), Color(0.75, 0.08, 0.12), Vector3(18, 0, -24 * sx))   # kızıl göz
		b.add("box", Vector3(0.36 * sx, 0.36, -0.32), Vector3(0.12, 0.05, 0.46), d, Vector3(14, 0, -24 * sx))
		for k in 5:   # testere ağız
			b.add("cone", Vector3((0.36 - k * 0.055) * sx, -0.21, -0.1 - k * 0.27), Vector3(0.1, 0.24, 0.1), Color(0.86, 0.87, 0.8), Vector3(180, 0, 0), 4)
	_meshes["enryu_bas"] = b.build(Props.toon())
	return _meshes["enryu_bas"]


static func enryu(pj, c: Node3D, t: Node3D) -> void:
	var id = "enryu"
	var tt = pj.tg(c, t, 24.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.7)
	pj.anim(c, "cast_out", 1.2)
	var dur = 8.0 if not CanonRules.rainy() else 4.5   # kanon: duman suda dağılır
	var n = 17
	var pts = []
	var nodes = []
	var from: Vector3 = _bone(c, "LeftHand", 1.1)
	var qm = QuadMesh.new()
	qm.size = Vector2.ONE
	var m = _mat("enryu_duman", PUFF_SH)
	for i in n:
		pts.append(from)
		var q = _node(qm, m, 3.0)
		pj.scene_add(q, from)
		q.set_instance_shader_parameter("sd", i * 0.137)
		q.set_instance_shader_parameter("size", lerpf(0.45, 1.7, pow(float(i) / (n - 1), 0.7)))
		nodes.append(q)
	var head = MeshInstance3D.new()
	head.mesh = _dragon_head()
	pj.scene_add(head, from)
	head.scale = Vector3.ONE * 0.2
	var s = {"gone": false, "tick": 0.0, "dir": d, "t": 0.0}
	var cw = weakref(c)
	var wipe = func() -> void:
		if s["gone"]:
			return
		s["gone"] = true
		for q in nodes:
			if is_instance_valid(q):
				var tw = q.create_tween()
				tw.tween_property(q, "scale", Vector3.ONE * 0.01, randf_range(0.2, 0.5))
				tw.tween_callback(q.queue_free)
		if is_instance_valid(head):
			var tw2 = head.create_tween()
			tw2.tween_property(head, "scale", Vector3.ONE * 0.01, 0.3)
			tw2.tween_callback(head.queue_free)
	Sfx.play("wind", from, 0.7, 0.6)
	pj.every(dur, 1.0 / 30.0, func(_i, _k):
		if s["gone"]:
			return
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			wipe.call()
			return
		var dt = 1.0 / 30.0
		s["t"] = float(s["t"]) + dt
		head.scale = head.scale.lerp(Vector3.ONE, 0.14)
		var hp: Vector3 = pts[n - 1]
		if cc.global_position.distance_to(hp) > 30.0:
			wipe.call()
			return
		for pr in cc.get_tree().get_nodes_in_group("projectiles"):   # Suiton dağıtır; fiziksel darbe duman geçer
			if pr is Projectile and is_instance_valid(pr) and pr.shooter != cc and str(pr.info.get("element", "")) == "suiton" and pr.global_position.distance_to(hp) < 3.0 + float(pr.radius):
				Combat.popup_text(hp + Vector3.UP, "Duman dağıldı", Color(0.8, 0.88, 0.85))
				wipe.call()
				return
		var goal: Vector3 = hp + (s["dir"] as Vector3) * 3.0
		var locked = pj.live(tt) and tt.global_position.distance_to(cc.global_position) < 32.0
		if locked:
			goal = tt.global_position + Vector3.UP * 1.4
		var to: Vector3 = goal - hp
		var close = locked and to.length() < 1.9
		if close:   # kanon: sarıp boğar
			var a = float(s["t"]) * 5.0
			goal = tt.global_position + Vector3(cos(a) * 1.25, 1.0 + sin(a * 0.7) * 0.5, sin(a) * 1.25)
			to = goal - hp
			s["tick"] = float(s["tick"]) + dt
			if float(s["tick"]) >= 0.5:
				s["tick"] = 0.0
				tt.take_hit(pj.inf(cc, id, 0.16, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "dir": Vector3.ZERO}))
				pj.st(tt, "bind", 0.7)
		var weave: Vector3 = Vector3.UP.cross(to.normalized() if to.length() > 0.05 else Vector3.FORWARD) * sin(float(s["t"]) * 5.0) * (0.0 if close else 2.2)
		var step: Vector3 = (to.normalized() * 12.5 + weave) * dt
		if step.length() > to.length() and not close:
			step = to
		var nh: Vector3 = hp + step
		nh.y = maxf(nh.y, pj.gp(nh).y + 0.9)
		pts[n - 1] = nh
		if step.length() > 0.01:
			s["dir"] = step.normalized()
		pts[0] = _bone(cc, "LeftHand", 1.1)
		for i in range(n - 2, 0, -1):   # gövde başı izler
			var nxt: Vector3 = pts[i + 1]
			var v: Vector3 = (pts[i] as Vector3) - nxt
			if v.length() > 0.62:
				pts[i] = nxt + v.normalized() * 0.62
		for i in range(1, n - 1):   # bileğe doğru gevşek bağ
			pts[i] = (pts[i] as Vector3).lerp(pts[i - 1], 0.035)
		for i in n:
			nodes[i].global_position = pts[i]
		head.global_position = nh + (s["dir"] as Vector3) * 0.5
		pj.toward(head, s["dir"]), wipe)


# ------------------------------------------------------------------ 4 Konshin Betsuri (ref Soul_detachment_technique.png): kızıl mühür, ruhu tılsıma çeker
const RING_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
float jit(float x) {
	float t = floor(TIME * 14.0);
	float i = floor(x);
	return mix(rnd(vec2(i, t)), rnd(vec2(i + 1.0, t)), fract(x)) - 0.5;
}
float line(float d, float w) { return 1.0 - smoothstep(w * 0.35, w, abs(d)); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float m = 0.0;
	for (int i = 0; i < 3; i++) {
		float r0 = 0.28 + float(i) * 0.3;
		m = max(m, line(r - r0 - jit(a * 26.0 + float(i) * 9.0) * 0.016, 0.012));
	}
	for (int k = 0; k < 4; k++) {
		float b = float(k) * 0.7854;
		vec2 dir = vec2(cos(b), sin(b));
		float along = dot(p, dir);
		float off = dot(p, vec2(-dir.y, dir.x));
		m = max(m, line(off - jit(along * 30.0 + float(k) * 5.0) * 0.016, 0.011) * step(abs(along), 0.98));
	}
	float seg = fract((a + 0.3927) / 0.7854);
	vec2 g = vec2((seg - 0.5) * 3.2, (r - 0.72) / 0.1);
	if (abs(g.y) < 1.0 && abs(g.x) < 0.8) {
		float cell = floor((a + 0.3927) / 0.7854);
		float stroke = sin(g.y * 7.0 + cell * 2.0 + sin(g.x * 9.0 + cell) * 1.4);
		m = max(m, step(0.72, stroke) * (1.0 - smoothstep(0.55, 0.8, abs(g.x))));
	}
	m *= step(r, prog * 1.05);
	float haze = exp(-pow((r - 0.58) * 2.0, 2.0)) * 0.05;
	ALBEDO = mix(vec3(1.0, 0.16, 0.14), vec3(1.0, 0.72, 0.62), m * m) * 1.5;
	ALPHA = clamp(m + haze, 0.0, 1.0) * fade;
}
"""

const SOUL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float fade = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(INV_VIEW_MATRIX[2].xyz, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, (1.0 - UV.y) * 2.0);
	p.x += sin(p.y * 3.0 + TIME * 3.0) * 0.07 * (1.0 - p.y * 0.3);
	float head = 1.0 - smoothstep(0.17, 0.25, length(p - vec2(0.0, 1.62)));
	float w = mix(0.08, 0.36, smoothstep(1.42, 1.15, p.y)) * smoothstep(0.0, 0.65, p.y);
	float body = (1.0 - smoothstep(w * 0.75, w, abs(p.x))) * step(p.y, 1.42);
	float m = max(head, body);
	if (m < 0.02) discard;
	ALBEDO = mix(vec3(0.7, 0.84, 1.0), vec3(1.0), m * 0.5) * 1.1;
	ALPHA = m * 0.62 * fade;
}
"""


static func _tag_mesh() -> ArrayMesh:
	if _meshes.has("konshin_tilsim"):
		return _meshes["konshin_tilsim"]
	var b = MB.new()
	b.add("box", Vector3(0, 0.34, 0), Vector3(0.2, 0.62, 0.008), Color(0.93, 0.89, 0.76))
	b.add("box", Vector3(0, 0.34, 0.006), Vector3(0.022, 0.46, 0.004), Color(0.7, 0.08, 0.08))
	for k in 5:
		b.add("box", Vector3(0, 0.16 + k * 0.09, 0.009), Vector3(0.1 - (k % 2) * 0.03, 0.014, 0.003), Color(0.08, 0.07, 0.07))
	b.add("cone", Vector3(0, 0.0, 0), Vector3(0.05, 0.14, 0.05), Color(0.25, 0.25, 0.28), Vector3(180, 0, 0), 5)
	_meshes["konshin_tilsim"] = b.build(Props.toon())
	return _meshes["konshin_tilsim"]


static func konshin_betsuri(pj, c: Node3D, t: Node3D) -> void:
	var id = "konshin_betsuri"
	var dur = 16.0
	var R = 4.4
	var tt = pj.tg(c, t, 16.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.6)
	pj.anim(c, "throw", 1.4)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 7.0)
	var root = Node3D.new()
	pj.scene_add(root, at)
	var plane = PlaneMesh.new()
	plane.size = Vector2.ONE * (R * 2.15)
	var ring = _node(plane, _mat("konshin_muhur", RING_SH), R * 2.0)
	ring.position.y = 0.06
	root.add_child(ring)
	_param(ring, "prog", 0.0, 1.0, 0.5)
	var tag = MeshInstance3D.new()
	tag.mesh = _tag_mesh()
	root.add_child(tag)
	Sfx.play("seal", at, 0.9, 0.7)
	var s = {"v": null, "soul": null, "over": false, "armed": Game.now() + 0.5}
	var cw = weakref(c)
	var finish = func() -> void:
		if s["over"]:
			return
		s["over"] = true
		if is_instance_valid(ring):
			_param(ring, "fade", 1.0, 0.0, 0.5)
		if s["soul"] != null and is_instance_valid(s["soul"]):
			(s["soul"] as Node).queue_free()
		root.get_tree().create_timer(0.55).timeout.connect(func():
			if is_instance_valid(root):
				root.queue_free())
	pj.every(dur, 0.1, func(_i, _k):
		if s["over"] or not is_instance_valid(root):
			return
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			finish.call()
			return
		if Game.now() < float(s["armed"]):
			return
		var v = s["v"]
		if v == null:
			for e in pj.enemies_near(cc, at, R):
				if e.get("model") == null or not _grounded(e):
					continue
				s["v"] = e
				e.take_hit(pj.inf(cc, id, 0.3, {"knock": 0.0, "kind": "light", "hitstop": 0.0}))
				pj.st(e, "stun", 8.0)
				Combat.popup_text(e.global_position + Vector3.UP * 2.3, "Ruh çekildi", Color(0.75, 0.86, 1.0))
				Sfx.play("genjutsu", e.global_position, 0.7, 0.8)
				var qm = QuadMesh.new()
				qm.size = Vector2(1.2, 2.2)
				var soul = _node(qm, _mat("konshin_ruh", SOUL_SH), 3.0)
				pj.scene_add(soul, e.global_position + Vector3.UP * 1.1)
				s["soul"] = soul
				var tw = soul.create_tween()
				tw.tween_property(soul, "global_position", at + Vector3.UP * 1.25, 0.9).set_trans(Tween.TRANS_SINE)
				break
			return
		if not pj.live(v) or not v.has_status("stun"):   # süre doldu ya da beden öldü
			finish.call()
			return
		_touch_tag(cc, v, at, finish), finish)


## Kanon: tılsıma dokunan ruhu serbest bırakır
static func _touch_tag(cc: Node3D, v: Node3D, at: Vector3, finish: Callable) -> void:
	for f in cc.get_tree().get_nodes_in_group("fighters"):
		if f != v and f != cc and not f.is_dead() and Combat.hostile(cc, f) and f.global_position.distance_to(at) < 1.3:
			v.statuses.erase("stun")
			if v is Player:
				v.input_locked = 0.0
			Combat.popup_text(at + Vector3.UP * 1.5, "Tılsım söküldü", Color(1.0, 0.75, 0.6))
			finish.call()
			return


# ------------------------------------------------------------------ 5 Kuchiyose: Aian Meiden (ref Summoning_Iron_Maiden.png): ikiye açılan demir beckoning kedi
static func _hemi(b: MB, c: Vector3, s: Vector3, col: Color, sx: float, seg := 12) -> void:
	b.add("hemi", Vector3(c.x * sx, c.y, c.z), Vector3(s.y, s.x, s.z), col, Vector3(0, 0, -90.0 * sx), seg)


static func _cat_half(sx: float) -> ArrayMesh:
	var key = "aian_%d" % int(sx)
	if _meshes.has(key):
		return _meshes[key]
	var b = MB.new()
	var w = Color(0.93, 0.91, 0.86)
	var red = Color(0.75, 0.13, 0.13)
	var gold = Color(0.86, 0.66, 0.2)
	var iron = Color(0.2, 0.2, 0.23)
	_hemi(b, Vector3.ZERO + Vector3(0, 1.45, 0), Vector3(2.9, 2.9, 2.5), w, sx)   # gövde
	_hemi(b, Vector3(0, 3.65, 0.05), Vector3(2.8, 2.25, 2.35), w, sx)   # baş
	b.add("cyl", Vector3(0.015 * sx, 1.45, 0), Vector3(2.75, 0.03, 2.3), iron, Vector3(0, 0, 90), 16)   # iç yüzler
	b.add("cyl", Vector3(0.015 * sx, 3.65, 0.05), Vector3(2.15, 0.03, 2.2), iron, Vector3(0, 0, 90), 14)
	for k in 13:   # iç dikenler: kapanınca kurbana saplanır
		var a = k * 2.399
		var r = 0.25 + k * 0.085
		b.add("cone", Vector3(0.2 * sx, 1.5 + sin(a) * r * 1.0, cos(a) * r * 0.9), Vector3(0.14, 0.42, 0.14), Color(0.62, 0.64, 0.68), Vector3(0, 0, 90.0 * sx), 4)
	# kulak
	b.add("cone", Vector3(0.82 * sx, 4.95, 0.0), Vector3(0.8, 0.95, 0.42), w, Vector3(0, 0, -16.0 * sx), 4)
	b.add("cone", Vector3(0.82 * sx, 4.9, 0.14), Vector3(0.5, 0.65, 0.2), red, Vector3(0, 0, -16.0 * sx), 4)
	# yüz: sarı göz, siyah yarık, pembe burun torbası
	b.add("sphere", Vector3(0.62 * sx, 3.9, 1.08), Vector3(0.5, 0.42, 0.14), Color(0.92, 0.72, 0.16), Vector3.ZERO, 10)
	b.add("sphere", Vector3(0.62 * sx, 3.9, 1.14), Vector3(0.36, 0.1, 0.08), Color(0.06, 0.05, 0.05), Vector3.ZERO, 8)
	_hemi(b, Vector3(0, 3.28, 1.02), Vector3(0.95, 0.68, 0.5), Color(0.92, 0.64, 0.66), sx, 10)
	b.add("box", Vector3(0.14 * sx, 3.56, 1.28), Vector3(0.24, 0.1, 0.06), Color(0.32, 0.12, 0.14))
	# boyun bağı, altın kısmı
	b.add("box", Vector3(0.72 * sx, 2.62, 1.0), Vector3(1.4, 0.2, 0.3), red, Vector3(0, -24.0 * sx, 0))
	_hemi(b, Vector3(0, 2.42, 1.2), Vector3(0.36, 0.36, 0.3), gold, sx, 8)
	# koban: altın oval ve kazınmış çizgiler
	_hemi(b, Vector3(0, 1.3, 1.2), Vector3(1.55, 1.95, 0.32), gold, sx)
	for k in 3:
		b.add("box", Vector3(0.24 * sx, 1.72 - k * 0.38, 1.36), Vector3(0.46 - k * 0.06, 0.07, 0.03), Color(0.2, 0.12, 0.05))
	if sx > 0.0:   # kalkık çağıran pati
		b.add("sphere", Vector3(1.55, 3.0, 0.3), Vector3(0.7, 1.5, 0.72), w, Vector3(0, 0, -24), 10)
		b.add("sphere", Vector3(1.86, 3.85, 0.32), Vector3(0.78, 0.72, 0.72), w, Vector3.ZERO, 10)
		b.add("sphere", Vector3(1.88, 3.85, 0.66), Vector3(0.36, 0.32, 0.1), Color(0.92, 0.64, 0.66), Vector3.ZERO, 8)
	else:
		b.add("sphere", Vector3(-1.1, 1.75, 0.95), Vector3(0.72, 1.15, 0.72), w, Vector3(0, 0, -14), 10)
	for k in 7:   # yıpranmış pas lekeleri
		var a = k * 1.9
		b.add("sphere", Vector3((0.72 + 0.34 * sin(a)) * sx, 0.8 + k * 0.42, 1.0 * cos(a * 0.4) + 0.05), Vector3(0.26, 0.2, 0.14), Color(0.68, 0.48, 0.26), Vector3.ZERO, 5)
	_meshes[key] = b.build(Props.toon())
	return _meshes[key]


static func _chains() -> ArrayMesh:
	if _meshes.has("aian_zincir"):
		return _meshes["aian_zincir"]
	var b = MB.new()
	var c = Color(0.36, 0.37, 0.41)
	for r in 4:
		var y = 0.75 + r * 1.15
		var R = 1.58 - absf(r - 1.2) * 0.1
		for k in 26:
			var a = k * TAU / 26.0 + r * 0.4
			var yy = y + sin(a * 2.0 + r) * 0.22
			var p = Vector3(cos(a) * R, yy, sin(a) * R * 0.95)
			var tang = Vector3(-sin(a), 0.1, cos(a)).normalized()
			var nrm = Vector3(cos(a), 0, sin(a))
			var u = nrm if k % 2 == 0 else Vector3.UP
			var v = tang.cross(u).normalized()
			b.add_xf("torus", Transform3D(Basis(tang * 0.3, v * 0.3, tang.cross(v).normalized() * 0.3), p), c, 8)
	_meshes["aian_zincir"] = b.build(Props.toon())
	return _meshes["aian_zincir"]


static func aian_meiden(pj, c: Node3D, t: Node3D) -> void:
	var id = "aian_meiden"
	var tt = pj.tg(c, t, 20.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.2)
	var at: Vector3 = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	Sfx.play("earth", at, 0.8, 0.6)
	var cw = weakref(c)
	pj.shake(0.2)
	pj.after(0.6, func():   # yerden yükselirken kaçılabilir
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var root = Node3D.new()
		pj.scene_add(root, at + Vector3.DOWN * 5.6)
		var to_c: Vector3 = cc.global_position - at
		to_c.y = 0.0
		if to_c.length() > 0.1:
			root.look_at(root.global_position - to_c, Vector3.UP)   # yüzü yapana dönük
		var halves = []
		for sx in [-1.0, 1.0]:
			var h = MeshInstance3D.new()
			h.mesh = _cat_half(sx)
			h.position.x = sx * 1.9
			root.add_child(h)
			halves.append(h)
		var tw = root.create_tween()
		tw.tween_property(root, "global_position", at, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("clash", at, 0.55, 0.9)
		pj.shake(0.5)
		pj.after(0.36, func():   # kapanış
			var c2 = cw.get_ref()
			if not is_instance_valid(root):
				return
			for k in 2:
				var ht = halves[k].create_tween()
				ht.tween_property(halves[k], "position:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			pj.after(0.12, func():
				var c3 = cw.get_ref()
				if not is_instance_valid(root):
					return
				pj.shake(0.6)
				Sfx.play("hit_heavy", at, 0.55, 1.0)
				var caught = []
				if c3 != null and pj.live(c3):
					for e in pj.enemies_near(c3, at, 2.0):
						if _grounded(e):
							caught.append(e)
							e.take_hit(pj.inf(c3, id, 0.35, {"knock": 0.0, "kind": "heavy", "bleed": 3.0, "hitstop": 0.08}))
							pj.st(e, "bind", 3.0)
				var ch = MeshInstance3D.new()
				ch.mesh = _chains()
				root.add_child(ch)
				ch.scale = Vector3(1.4, 0.02, 1.4)
				var ct = ch.create_tween()
				ct.tween_property(ch, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				Sfx.play("chain", at, 0.8, 0.9)
				pj.every(2.1, 0.7, func(_i, _k):
					var c4 = cw.get_ref()
					if c4 == null or not pj.live(c4):
						return
					for e in caught:
						if pj.live(e):
							e.take_hit(pj.inf(c4, id, 0.12, {"knock": 0.0, "kind": "light", "hitstop": 0.0})))
				pj.after(2.2, func():   # zincirler kediyi toprağa çeker
					if not is_instance_valid(root):
						return
					Sfx.play("earth", at, 0.6, 0.8)
					var c5 = cw.get_ref()
					if c5 != null and pj.live(c5):
						for e in caught:
							if pj.live(e):
								e.take_hit(pj.inf(c5, id, 0.55, {"knock": 1.0, "kind": "heavy", "hitstop": 0.08}))
								pj.st(e, "stun", 0.7)
					var dt = root.create_tween()
					dt.tween_property(root, "global_position", at + Vector3.DOWN * 6.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					dt.tween_callback(root.queue_free)))))
