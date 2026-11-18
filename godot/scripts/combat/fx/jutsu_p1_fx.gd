extends RefCounted
## Parti 1 (hedef: res://scripts/combat/fx/jutsu_p1_fx.gd). Görünen her şey bu dosyanın kendi gölgelendirici ve geometrisi.
## Chikatsu Saisei, Saisei Kekkai, Bijū Sōshingeki, Tenpenchii, Yosakugiri. Kaynak görseller: refs/new/<id>/

const S = preload("res://scripts/combat/samehada_anim.gd")
const ORDER := ["shukaku", "matatabi", "isobu", "son_goku", "kokuo", "saiken", "chomei", "gyuki", "kurama"]   # kanon saldırı sırası
const AWAY := ["captured_org", "sealed_jar", "mazo", "jubi", "jubi_mine", "jubi_host"]
const CHANNEL := 8.0
const LAYERS := 36.0
const WALL := Vector2(12.0, 9.0)

static var _mats := {}


# ------------------------------------------------------------------ küçük altyapı
static func _mat(key: String, code: String) -> ShaderMaterial:
	if not _mats.has(key):
		var sh = Shader.new()
		sh.code = code
		var m = ShaderMaterial.new()
		m.shader = sh
		_mats[key] = m
	return _mats[key]


static func _node(mesh: Mesh, m: Material, half := 40.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -half, Vector3.ONE * half * 2.0)
	return mi


static func _flat(size: float, m: Material) -> MeshInstance3D:
	var q = PlaneMesh.new()
	q.size = Vector2.ONE * size
	return _node(q, m, size)


## Kart bulutu: her kart merkez + COLOR tohumu taşır, boyutu gölgelendirici verir
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


static func _friends(c: Node3D, at: Vector3, r: float, skip: Array) -> Array:
	var out = []
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if f != c and not f in skip and not f.is_dead() and not Combat.hostile(c, f) and f.get("model") != null and f.global_position.distance_to(at) <= r:
			out.append(f)
	return out


static func _foes(c: Node3D, at: Vector3, r: float) -> Array:
	var out = []
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if not f.is_dead() and Combat.hostile(c, f) and f.global_position.distance_to(at) <= r:
			out.append(f)
	return out


static func _patient(c: Node3D) -> Node3D:
	var best: Node3D = null
	var bd = 5.5
	for f in _friends(c, c.global_position, 5.5, []):
		var d = f.global_position.distance_to(c.global_position)
		if f.get("hp") != null and float(f.hp) < float(f.max_hp) * 0.35 and d < bd:
			bd = d
			best = f
	return best


static func _free_beasts() -> Array:
	var out = []
	var all: Dictionary = TailedBeasts.beasts()
	for id in ORDER:
		if not str(all.get(id, {}).get("state", "wild")) in AWAY:
			out.append(id)
	return out


## Kanon şartı (CanonRules.block çağırır: oyuncu ve düşman aynı). "" = atılabilir
static func gate(c: Node3D, jid: String) -> String:
	match jid:
		"chikatsu_saisei":
			if _patient(c) == null:
				return "Yakında ölmek üzere bir yoldaş yok."
			if not _foes(c, c.global_position, 14.0).is_empty():
				return "Bu ameliyat çatışmanın ortasında yapılmaz."
		"saisei_kekkai":
			if _friends(c, c.global_position, 12.0, []).size() < 2:
				return "Bariyer birkaç kişinin chakrasıyla kurulur: yakında en az iki yoldaş gerekir."
		"biju_soshingeki":
			if _free_beasts().size() < 3:
				return "Yanında duracak yeterince özgür kuyruklu canavar yok."
		"tenpenchii":
			if not (c is Player and bool(Game.profile.get("jubi_jinchuriki", false))):
				return "Bu felaket yalnız On Kuyruk'un chakrasıyla kopar."
	return ""


# ------------------------------------------------------------------ 1 Chikatsu Saisei: yerde yazılı ameliyat mührü (ref Chikatsu_Saisei.png)
const SEAL_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float box = max(abs(p.x), abs(p.y));
	float ink = 0.0;
	if (box < 0.93) {
		ink = step(0.885, box) * step(box, 0.93);
		ink = max(ink, step(0.84, box) * step(box, 0.85));
		for (int i = 0; i < 5; i++) {
			float r0 = 0.2 + float(i) * 0.15;
			ink = max(ink, step(abs(r - r0), 0.0045));
			if (r > r0 + 0.018 && r < r0 + 0.132) {
				float n = 22.0 + float(i) * 14.0;
				vec2 cell = vec2(floor(a * n), floor((r - r0) / 0.114 * 3.0));
				vec2 f = vec2(fract(a * n), fract((r - r0) / 0.114 * 3.0));
				float h = rnd(cell + float(i));
				float g = h > 0.5 ? step(abs(f.x - 0.3 - h * 0.4), 0.13) : step(abs(f.y - h), 0.16);
				ink = max(ink, g * step(0.2, h) * step(abs(f.x - 0.5), 0.42));
			}
		}
	}
	float drawn = smoothstep(prog * 1.5, prog * 1.5 - 0.08, r);
	float glow = exp(-r * r * 26.0) * (0.75 + 0.25 * sin(TIME * 3.2)) * smoothstep(0.1, 0.5, prog);
	float wash = (1.0 - smoothstep(0.1, 0.95, box)) * 0.22 * smoothstep(0.2, 0.7, prog);
	ALBEDO = mix(vec3(0.03, 0.06, 0.04), vec3(0.46, 1.0, 0.56), clamp(glow * 1.6, 0.0, 1.0));
	ALPHA = clamp(max(ink * drawn * 0.92, glow + wash * step(box, 0.93)), 0.0, 1.0) * fade;
	if (ALPHA < 0.01) discard;
}
"""

const CANDLE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled, skip_vertex_transform;
instance uniform float fade = 1.0;
void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xy += (UV - vec2(0.5, 0.15)) * vec2(0.26, 0.5);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0, UV.y);
	p.x += sin(UV.y * 6.0 + TIME * 7.0 + COLOR.r * 20.0) * 0.14 * UV.y;
	float w = (1.0 - UV.y) * sqrt(max(UV.y * 3.0, 0.0)) * 0.9;
	float m = smoothstep(w, w * 0.25, abs(p.x));
	ALBEDO = mix(vec3(1.0, 0.36, 0.06), vec3(1.0, 0.86, 0.46), m) * 1.5;
	ALPHA = m * fade;
	if (ALPHA < 0.01) discard;
}
"""

const MOTE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
void vertex() {
	vec3 c = VERTEX;
	c.y += prog * (1.2 + COLOR.g * 2.6);
	c.xz *= 1.0 + prog * 0.5;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * (0.07 + COLOR.r * 0.08) * sin(min(prog * 1.05, 1.0) * 3.14159);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	float m = smoothstep(1.0, 0.1, length(UV * 2.0 - 1.0));
	ALBEDO = vec3(0.46, 1.0, 0.6) * 1.4;
	ALPHA = m;
}
"""


static func chikatsu_saisei(pj, c: Node3D, _t: Node3D) -> void:
	var p = _patient(c)
	if p == null:
		return
	pj.busy(c, CHANNEL)
	pj.anim(c, "cast", 0.8)
	pj.st(p, "stun", CHANNEL + 0.2)
	var at: Vector3 = pj.gp(p.global_position)
	var root = Node3D.new()
	pj.scene_add(root, at + Vector3.UP * 0.04)
	var seal = _flat(8.4, _mat("chikatsu_muhur", SEAL_SH))
	root.add_child(seal)
	_param(seal, "prog", 0.0, 1.0, 2.2)
	var flames = []
	var cone = PrismMesh.new()
	cone.size = Vector3(0.36, 0.34, 0.36)
	for k in 4:
		var a = PI * 0.25 + k * PI * 0.5
		var o = Vector3(cos(a), 0.0, sin(a)) * 5.5
		var m = MeshInstance3D.new()
		m.mesh = cone
		m.material_override = Props.toon_color(Color(0.05, 0.05, 0.06), 0.1)
		m.position = o + Vector3.UP * 0.17
		root.add_child(m)
		var fl = _node(_cards(1, func(_i): return [Vector3.ZERO, Color(float(k) * 0.23, 0, 0, 1)]), _mat("chikatsu_mum", CANDLE_SH), 2.0)
		fl.position = o + Vector3.UP * 0.34
		root.add_child(fl)
		flames.append(fl)
	var team = _friends(c, at, 9.0, [p]).size()   # kanon: ekip; her ek şifacı şansı artırır
	var chance = minf(0.3 + team * 0.15, 0.8)
	var hp0 = float(c.hp)
	var s = {"broke": false}
	Sfx.play("seal", at, 0.8, 0.6)
	pj.every(CHANNEL, 0.15, func(_i, _k):
		if s["broke"]:
			return
		if not pj.live(c) or not pj.live(p) or float(c.hp) < hp0 - 0.5:
			s["broke"] = true
			Combat.popup_text(at + Vector3.UP * 2.2, "Ameliyat bölündü", Color(1.0, 0.6, 0.5))
			if is_instance_valid(c) and c is Player and c.combat.action == "cast":
				c.combat.action = ""
			if is_instance_valid(root):
				root.queue_free(), func():
		if s["broke"] or not is_instance_valid(root):
			return
		_param(seal, "fade", 1.0, 0.0, 1.2, false)
		for fl in flames:
			_param(fl, "fade", 1.0, 0.0, 0.5)
		root.get_tree().create_timer(1.3).timeout.connect(func():
			if is_instance_valid(root):
				root.queue_free())
		if not pj.live(p):
			return
		if randf() < chance:
			p.hp = minf(float(p.max_hp), maxf(float(p.hp), float(p.max_hp) * 0.75))
			for b in ["burn", "poison", "bleed"]:
				if p.statuses.has(b):
					p.statuses.erase(b)
			Combat.popup_text(p.global_position + Vector3.UP * 2.3, "Hayata tutundu", Color(0.5, 1.0, 0.6))
			Sfx.play("heal", at, 0.8, 0.7)
			var motes = _node(_cards(46, func(_i):
				var a = randf() * TAU
				var r = sqrt(randf()) * 0.9
				return [Vector3(cos(a) * r, randf() * 0.5, sin(a) * r), Color(randf(), randf(), 0, 1)]), _mat("chikatsu_zerre", MOTE_SH), 6.0)
			root.add_child(motes)
			_param(motes, "prog", 0.0, 1.0, 1.2)
		else:
			pj.heal(p, float(p.max_hp) * 0.1)
			Combat.popup_text(p.global_position + Vector3.UP * 2.3, "Kurtarılamadı", Color(0.8, 0.8, 0.75)))


# ------------------------------------------------------------------ 2 Saisei Kekkai: kat kat cam levha; çatlar ve kendini onarır (ref Thirty-Six_Layer_Barrier*.png)
const PANE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec3 hits[6];
instance uniform float on = 1.0;
float crack(vec2 p, vec3 h) {
	if (h.z > 5.0) return 0.0;
	vec2 d = p - h.xy;
	float r = length(d);
	float reach = 0.85 * (1.0 - smoothstep(1.5, 5.0, h.z)) * smoothstep(0.0, 0.12, h.z + 0.02);
	if (r > reach) return 0.0;
	float s = atan(d.y, d.x) * 11.0 / 6.28318;
	float k = floor(s);
	float off = 0.3 + fract(sin(k * 12.9) * 437.58) * 0.4;
	float spoke = 1.0 - smoothstep(0.004, 0.01, abs(fract(s) - off) / 1.75 * r);
	float rr = r * 7.0 + sin(k * 3.1) * 0.5;
	float seg = step(0.36, fract(k * 0.37 + floor(rr) * 0.61));
	float ring = (1.0 - smoothstep(0.015, 0.05, abs(fract(rr) - 0.5))) * seg;
	return max(spoke, ring);
}
float plate(vec2 p, vec3 h) {
	if (h.z > 3.0) return 0.0;
	float r = length(p - h.xy);
	return (1.0 - smoothstep(0.05, 0.22, r)) * (1.0 - h.z / 3.0);
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0 * 12.0 / 9.0, 2.0);
	vec2 e = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.93, 1.0, max(e.x, e.y));
	float sheen = 0.5 + 0.5 * sin((p.x + p.y) * 3.0 + TIME * 0.7);
	float c = 0.0;
	float pl = 0.0;
	for (int i = 0; i < 6; i++) {
		c = max(c, crack(p, hits[i]));
		pl = max(pl, plate(p, hits[i]));
	}
	ALBEDO = mix(vec3(0.72, 0.86, 1.0), vec3(0.05, 0.08, 0.14), c);
	ALBEDO = mix(ALBEDO, vec3(0.86, 0.94, 1.0), pl * (1.0 - c));
	ALPHA = clamp(0.035 + sheen * 0.025 + edge * 0.3 + c * 0.95 + pl * 0.45, 0.0, 1.0) * on;
	if (ALPHA < 0.005) discard;
}
"""


static func _shards(pj, at: Vector3, basis: Basis, n: int) -> void:
	var m = PackedVector3Array([Vector3(-0.5, -0.4, 0), Vector3(0.5, -0.3, 0), Vector3(0.05, 0.55, 0)])
	var a = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = m
	var tri = ArrayMesh.new()
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.8, 0.9, 1.0)
	for i in n:
		var mi = MeshInstance3D.new()
		mi.mesh = tri
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * randf_range(0.1, 0.34)
		pj.scene_add(mi, at)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var v: Vector3 = basis * Vector3(randf_range(-3.0, 3.0), randf_range(-0.6, 3.2), randf_range(-3.5, 1.0))
		var spin = Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7))
		var fly = func(k: float) -> void:
			if is_instance_valid(mi):
				mi.global_position = at + v * k + Vector3.DOWN * 4.9 * k * k
				mi.rotation = spin * k
		var tw = mi.create_tween()
		tw.tween_method(fly, 0.0, 1.0, 0.9)
		tw.tween_callback(mi.queue_free)


static func saisei_kekkai(pj, c: Node3D, t: Node3D) -> void:
	var dur = 14.0
	pj.busy(c, 0.8)
	pj.anim(c, "cast", 1.2)
	var d: Vector3 = pj.fwd(c, t)
	d.y = 0.0
	d = d.normalized()
	var root = Node3D.new()
	pj.scene_add(root, pj.gp(c.global_position + d * 5.0))
	pj.toward(root, d)
	var m: ShaderMaterial = _mat("kekkai_cam", PANE_SH).duplicate()
	var hits = PackedVector3Array()
	hits.resize(6)
	hits.fill(Vector3(0, 0, 99))
	m.set_shader_parameter("hits", hits)
	var quad = QuadMesh.new()
	quad.size = WALL
	var panes = []
	for i in 6:   # görünen katlar; 36 kat altıya bölünür
		var q = _node(quad, m, 10.0)
		q.position = Vector3(0, WALL.y * 0.5, -i * 0.13)
		q.set_instance_shader_parameter("on", 0.0)
		root.add_child(q)
		_param(q, "on", 0.0, 1.0, 0.25 + i * 0.1)
		panes.append(q)
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var cs = CollisionShape3D.new()
	var bx = BoxShape3D.new()
	bx.size = Vector3(WALL.x, WALL.y, 0.8)
	cs.shape = bx
	cs.position = Vector3(0, WALL.y * 0.5, -0.3)
	body.add_child(cs)
	root.add_child(body)
	Sfx.play("seal", root.global_position, 1.2, 0.7)
	var s = {"L": LAYERS, "age": [99.0, 99.0, 99.0, 99.0, 99.0, 99.0], "pos": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], "next": 0, "tick": 0.0, "dead": false}
	var crash = func() -> void:
		s["dead"] = true
		_shards(pj, root.global_position + Vector3.UP * 4.0, root.global_transform.basis, 40)
		Sfx.play("clash", root.global_position + Vector3.UP * 3.0, 0.6, 1.0)
		root.queue_free()
	pj.every(dur, 0.05, func(_i, _k):
		if s["dead"] or not is_instance_valid(root):
			return
		if not pj.live(c) or c.global_position.distance_to(root.global_position) > 24.0:
			crash.call()
			return
		for pr in c.get_tree().get_nodes_in_group("projectiles"):
			if not (pr is Projectile) or not is_instance_valid(pr) or pr.shooter == c:
				continue
			if pr.shooter != null and is_instance_valid(pr.shooter) and not Combat.hostile(c, pr.shooter):
				continue
			var l: Vector3 = root.to_local(pr.global_position)
			if absf(l.z + 0.3) < 0.9 and absf(l.x) < WALL.x * 0.5 and l.y > -0.5 and l.y < WALL.y:
				var cut = maxf(1.0, float(pr.info.get("dmg", 8.0)) / 7.0)
				s["L"] = float(s["L"]) - cut
				var n = int(s["next"])
				s["next"] = (n + 1) % 6
				s["age"][n] = 0.0
				s["pos"][n] = Vector2(l.x / (WALL.y * 0.5), -(l.y - WALL.y * 0.5) / (WALL.y * 0.5))
				_shards(pj, pr.global_position, root.global_transform.basis, 8)
				Sfx.play("clink", pr.global_position, 0.7, 0.7)
				Combat.popup_text(pr.global_position + Vector3.UP * 0.6, "%d kat" % maxi(int(s["L"]), 0), Color(0.75, 0.88, 1.0))
				pr.queue_free()
		if float(s["L"]) <= 0.0:
			crash.call()
			return
		s["tick"] = float(s["tick"]) + 0.05
		if float(s["tick"]) >= 0.5:   # kanon: bağlı chakra aktıkça kendini onarır
			s["tick"] = 0.0
			var h = _friends(c, root.global_position, 26.0, [])
			if h.size() >= 2 and float(c.chakra) > 1.0:
				c.chakra = float(c.chakra) - 1.2
				s["L"] = minf(LAYERS, float(s["L"]) + 0.8 * h.size())
		var arr = PackedVector3Array()
		for i in 6:
			s["age"][i] = float(s["age"][i]) + 0.05
			var p2: Vector2 = s["pos"][i]
			arr.append(Vector3(p2.x, p2.y, s["age"][i]))
		m.set_shader_parameter("hits", arr)
		for i in 6:
			(panes[i] as GeometryInstance3D).set_instance_shader_parameter("on", 1.0 if float(s["L"]) > float(i) * 6.0 else 0.0), func():
		if s["dead"] or not is_instance_valid(root):
			return
		for q in panes:
			_param(q, "on", 1.0, 0.0, 0.5)
		root.get_tree().create_timer(0.55).timeout.connect(func():
			if is_instance_valid(root):
				root.queue_free()))


# ------------------------------------------------------------------ 3 Bijū Sōshingeki: dokuz canavar sırayla (ref Tailed_Beasts_vs_Madara.png)
const BURST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
instance uniform int mode = 0;
instance uniform vec4 c1 = vec4(1.0);
instance uniform vec4 c2 = vec4(1.0);
varying float sd;
varying float pr;
void vertex() {
	sd = COLOR.r;
	float t = clamp(prog * (1.0 + COLOR.g * 0.5) , 0.0, 1.0);
	pr = t;
	vec3 c = VERTEX;
	float e = 1.0 - pow(1.0 - t, 2.5);
	float size = 0.5;
	if (mode == 0) { c *= e * 1.4; c.y -= t * t * 2.2; size = 0.34; }                       // kum: ağır taneler
	else if (mode == 1) { c.xz *= e; c.y += t * 5.0 * COLOR.g; size = 1.3 * (1.0 - t * 0.6); }   // mavi alev dilleri
	else if (mode == 2) { c *= e * 1.1; c.y += sin(t * 3.14) * 2.0 - t * t * 2.0; size = 0.55; } // su kütlesi
	else if (mode == 3) { c *= e; c.y += sin(t * 3.14) * 3.4 - t * t * 3.0; size = 0.42; }       // lav parçaları
	else if (mode == 4) { c.xz *= e * 1.3; c.y += t * 4.0; size = 1.1 + t * 1.4; }              // buhar
	else if (mode == 5) { c *= e * 0.9; c.y += t * 1.6; size = 0.3 + COLOR.g * 0.7; }           // asit kabarcığı
	else if (mode == 6) { c *= e * 1.6; c.y += sin(t * 9.0 + sd * 20.0) * 0.5; size = 0.2; }    // kanat tozu
	else if (mode == 7) { c *= e * 1.2; c.y -= t * t * 1.5; size = 0.26 + COLOR.g * 0.5; }      // mürekkep
	else { c.xz *= e * 1.1; c.y += t * 3.0; size = 1.5 * (1.0 - t * 0.4); }                     // kızıl alev
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float a = sd * 6.28 + t * 2.0;
	vec2 q = (UV - 0.5) * size;
	v.xy += vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float m = 0.0;
	float tone = 0.0;
	if (mode == 0 || mode == 3) { m = step(max(abs(p.x) * 0.8 + abs(p.y) * 0.6, r * 0.8), 0.8); tone = step(0.1, p.y + p.x); }
	else if (mode == 1 || mode == 8) { float w = (1.0 - UV.y) * sqrt(UV.y * 2.0 + 0.02); m = step(abs(p.x), w * 1.2); tone = step(abs(p.x), w * 0.55); }
	else if (mode == 2) { m = step(r, 0.9 + 0.1 * sin(atan(p.y, p.x) * 5.0 + sd * 9.0)); tone = step(0.35, p.y - p.x * 0.3); }
	else if (mode == 4) { m = step(r, 0.82 + 0.16 * sin(atan(p.y, p.x) * 6.0 + sd * 30.0)); tone = step(0.1, p.y); }
	else if (mode == 5) { m = step(r, 0.95) * (1.0 - step(r, 0.72)) + step(length(p - vec2(-0.25, 0.3)), 0.18); tone = 1.0; }
	else if (mode == 6) { m = step(abs(p.x) + abs(p.y), 0.95); tone = step(0.5, fract(sd * 7.0)); }
	else { m = step(r, 0.9 - 0.25 * sin(atan(p.y, p.x) * 3.0 + sd * 12.0)); tone = 0.0; }
	if (m < 0.5 || pr > 0.985) discard;
	ALBEDO = mix(c1.rgb, c2.rgb, tone);
	ALPHA = 1.0 - smoothstep(0.72, 0.98, pr);
}
"""

const BURST_COL := {"shukaku": [Color(0.62, 0.5, 0.3), Color(0.82, 0.7, 0.46), 0], "matatabi": [Color(0.1, 0.25, 0.85), Color(0.5, 0.82, 1.0), 1],
	"isobu": [Color(0.24, 0.48, 0.62), Color(0.7, 0.9, 0.95), 2], "son_goku": [Color(0.62, 0.14, 0.06), Color(1.0, 0.56, 0.12), 3],
	"kokuo": [Color(0.8, 0.82, 0.84), Color(0.98, 0.98, 0.98), 4], "saiken": [Color(0.72, 0.84, 0.72), Color(0.88, 0.97, 0.82), 5],
	"chomei": [Color(0.5, 0.8, 0.4), Color(0.96, 0.95, 0.6), 6], "gyuki": [Color(0.05, 0.05, 0.07), Color(0.2, 0.18, 0.24), 7],
	"kurama": [Color(0.95, 0.3, 0.06), Color(1.0, 0.8, 0.3), 8]}
const BEAST_ACT := {"shukaku": "roar", "matatabi": "swipe_l", "isobu": "charge", "son_goku": "stomp", "kokuo": "charge", "saiken": "roar", "chomei": "swipe_r", "gyuki": "swipe_l", "kurama": "slam"}


static func _burst(pj, at: Vector3, id: String) -> void:
	var e: Array = BURST_COL[id]
	var mesh = _cards(48, func(_i):
		var d = Vector3(randf_range(-1, 1), randf_range(-0.1, 1), randf_range(-1, 1)).normalized() * randf_range(1.0, 4.2)
		return [d, Color(randf(), randf(), 0, 1)])
	var mi = _node(mesh, _mat("soshin_patlama", BURST_SH), 14.0)
	pj.scene_add(mi, at)
	mi.set_instance_shader_parameter("mode", int(e[2]))
	mi.set_instance_shader_parameter("c1", e[0])
	mi.set_instance_shader_parameter("c2", e[1])
	_param(mi, "prog", 0.0, 1.0, 0.75, true)


## Kuyruk: eğri, sivrilen tüp
static func _tail_mesh(col: Color) -> ArrayMesh:
	var b = MB.new()
	var n = 12
	var prev: Vector3 = Vector3.ZERO
	for i in range(1, n + 1):
		var t = float(i) / n
		var p = Vector3(0, t * 12.0, sin(t * 2.4) * 2.2)
		var y = p - prev
		var r = lerpf(1.3, 0.12, t * t)
		var yn = y.normalized()
		var xn = yn.cross(Vector3.RIGHT).normalized()
		b.add_xf("sphere", Transform3D(Basis(xn.cross(yn) * r, y * 1.6, xn * -r), (p + prev) * 0.5), col, 8)
		prev = p
	return b.build(Props.toon_color(col, 0.35))


static func biju_soshingeki(pj, c: Node3D, t: Node3D) -> void:
	var id = "biju_soshingeki"
	var ids = _free_beasts()
	var tt = pj.tg(c, t, 30.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 1.0)
	pj.anim(c, "cast", 1.2)
	var cw = weakref(c)
	var aim = func() -> Vector3:
		return pj.gp(tt.global_position if pj.live(tt) else c.global_position + d * 12.0)
	var n = ids.size()
	Sfx.play("roar", c.global_position, 0.8, 0.9)
	for k in n:
		pj.after(0.25 + k * 0.52, func():
			var cc = cw.get_ref()
			if cc == null or not pj.live(cc):
				return
			var bid: String = ids[k]
			var at: Vector3 = aim.call()
			var a = k * TAU / n + 0.4
			var from: Vector3 = pj.gp(at + Vector3(cos(a), 0, sin(a)) * 10.0)
			var near: Vector3 = at + (from - at).normalized() * 3.4
			var rig = BeastModels.build(bid, 8.5)
			rig.remove_colliders()
			pj.scene_add(rig, from)
			pj.toward(rig, Vector3(at.x - from.x, 0.0, at.z - from.z))
			rig.play_action(str(BEAST_ACT[bid]), 0.55)
			var tw = rig.create_tween()
			tw.tween_property(rig, "global_position", near, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.26)
			tw.tween_property(rig, "scale", Vector3.ONE * 0.01, 0.18)
			tw.tween_callback(rig.queue_free)
			pj.after(0.24, func():
				var c2 = cw.get_ref()
				if c2 == null or not pj.live(c2):
					return
				var p: Vector3 = aim.call()
				_burst(pj, p + Vector3.UP * 0.6, bid)
				Sfx.play("hit_heavy", p, 0.7, 0.8)
				pj.shake(0.25)
				for e in pj.enemies_near(c2, p, 4.0):
					e.take_hit(pj.inf(c2, id, 0.15, {"knock": 0.6, "kind": "light", "hitstop": 0.02}))
					pj.st(e, "stun", 0.6)))
	pj.after(0.35 + n * 0.52, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var at: Vector3 = aim.call()
		for k in n:   # kuyruklar birleşip tek darbede iner
			var a = k * TAU / n
			var col: Color = BURST_COL[ids[k]][1]
			var mi = MeshInstance3D.new()
			mi.mesh = _tail_mesh(col)
			pj.scene_add(mi, at + Vector3(cos(a), 0, sin(a)) * 11.5)
			mi.look_at(at, Vector3.UP)
			var b0: Basis = mi.global_transform.basis
			var sweep = func(v: float) -> void:
				if is_instance_valid(mi):
					mi.global_transform.basis = b0 * Basis(Vector3.RIGHT, lerpf(0.2, -1.5, v * v))
			var tw = mi.create_tween()
			tw.tween_method(sweep, 0.0, 1.0, 0.34)
			tw.tween_interval(0.16)
			tw.tween_property(mi, "scale", Vector3(0.02, 1.0, 0.02), 0.2)
			tw.tween_callback(mi.queue_free)
		pj.after(0.32, func():
			var c2 = cw.get_ref()
			if c2 == null or not pj.live(c2):
				return
			pj.shake(0.9)
			Sfx.play("boom", at, 0.7, 1.0)
			pj.hit(c2, at + Vector3.UP, 7.0, pj.inf(c2, id, 0.9, {"knock": 14.0, "launch": 9.0, "kind": "heavy", "hitstop": 0.1}))))


# ------------------------------------------------------------------ 4 Tenpenchii: deprem, sel, fırtına, hortum, mantar bulutu (ref Tenpenchii_Anime_*.png)
const QUAKE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float m = 0.0;
	for (int i = 0; i < 3; i++) {
		float f = float(i);
		float n = 7.0 + f * 4.0;
		float wob = sin(a * n + f * 2.0) * 0.5 + sin(a * n * 2.7 + f) * 0.3;
		float d = abs(fract(a * n / 6.28318 + wob * 0.12 + r * (1.6 + f)) - 0.5);
		m = max(m, step(d, 0.018 + 0.012 * (1.0 - r)));
	}
	float ring = abs(r - prog);
	float crest = step(ring, 0.012);
	float reach = step(r, prog);
	if (max(m * reach, crest) < 0.5 || r > 1.0) discard;
	ALBEDO = mix(vec3(0.05, 0.035, 0.04), vec3(0.55, 0.42, 0.62), crest);
	ALPHA = 0.95 * (1.0 - smoothstep(0.8, 1.0, prog));
}
"""

const FLOOD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > prog) discard;
	float a = atan(p.y, p.x);
	float w = sin(r * 34.0 - TIME * 5.0 + sin(a * 7.0) * 1.6);
	float foam = step(0.86, w) + step(prog - 0.022 - 0.008 * sin(a * 18.0 + TIME * 3.0), r);
	ALBEDO = mix(mix(vec3(0.06, 0.13, 0.2), vec3(0.14, 0.27, 0.34), step(0.0, w)), vec3(0.74, 0.84, 0.86), clamp(foam, 0.0, 1.0));
	ALPHA = 0.86 * fade;
}
"""

const CLOUD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, skip_vertex_transform;
instance uniform float prog = 1.0;
instance uniform float rise = 0.0;
instance uniform vec4 c0 = vec4(0.1, 0.09, 0.16, 1.0);
instance uniform vec4 c1 = vec4(0.24, 0.21, 0.36, 1.0);
instance uniform vec4 c2 = vec4(0.5, 0.46, 0.64, 1.0);
varying float sd;
void vertex() {
	sd = COLOR.r;
	vec3 c = VERTEX;
	c.xz *= mix(0.25, 1.0, prog);
	c.y = mix(c.y * 0.15, c.y, rise);
	c.x += sin(TIME * 0.4 + sd * 20.0) * 0.4;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * (5.0 + COLOR.g * 9.0) * mix(0.3, 1.0, prog);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.82 + 0.08 * sin(a * 5.0 + sd * 40.0) + 0.05 * sin(a * 11.0 + sd * 17.0);
	float r = length(p);
	if (r > e) discard;
	vec3 n = vec3(p / e, sqrt(max(1.0 - r * r / (e * e), 0.0)));
	float l = dot(n, normalize(vec3(-0.4, 0.75, 0.5)));
	ALBEDO = l > 0.55 ? c2.rgb : (l > 0.1 ? c1.rgb : c0.rgb);
}
"""

const BOLT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float fade = 1.0;
void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.1, 0.32, d);
	float halo = (1.0 - d) * 0.32;
	ALBEDO = mix(vec3(0.42, 0.56, 1.0), vec3(1.0), core) * 1.6;
	ALPHA = clamp(core + halo, 0.0, 1.0) * fade;
}
"""

const TWIST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, skip_vertex_transform;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float h = fract(COLOR.g + TIME * (0.16 + sd * 0.1));
	float r = mix(0.5, 5.4, h * h) * (0.86 + sd * 0.28);
	float a = sd * 40.0 + TIME * (5.5 - h * 2.0);
	vec3 c = vec3(cos(a) * r, h * 24.0, sin(a) * r);
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * vec2(2.4, 0.9) * (0.6 + h * 1.6);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (p.x * p.x + p.y * p.y * 3.0 * (1.0 + 0.3 * sin(p.x * 8.0 + sd * 20.0)) > 1.0) discard;
	ALBEDO = mix(vec3(0.17, 0.16, 0.24), vec3(0.44, 0.42, 0.54), step(0.45, fract(sd * 5.0)));
}
"""

const BLAST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float m = pow(max(1.0 - r, 0.0), 1.6) * (1.0 - prog);
	ALBEDO = mix(vec3(0.72, 0.68, 1.0), vec3(1.0), m);
	ALPHA = clamp(m * 1.6, 0.0, 1.0);
}
"""


static func _bolt(pj, top: Vector3, bottom: Vector3) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 11
	var pts = []
	for i in n + 1:
		var k = float(i) / n
		var j = sin(k * PI) * 2.6
		pts.append(top.lerp(bottom, k) + Vector3(randf_range(-j, j), 0.0, randf_range(-j, j)))
	for side in [Vector3.RIGHT, Vector3.BACK]:
		for i in n:
			var w0 = lerpf(0.5, 0.26, float(i) / n)
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var q = [[a - side * w0, 0.0], [a + side * w0, 1.0], [b + side * w0, 1.0], [a - side * w0, 0.0], [b + side * w0, 1.0], [b - side * w0, 0.0]]
			for e in q:
				st.set_uv(Vector2(e[1], 0.0))
				st.add_vertex(e[0])
	var mi = _node(st.commit(), _mat("tenpen_simsek", BOLT_SH), 80.0)
	pj.get_tree().current_scene.add_child(mi)
	_param(mi, "fade", 1.0, 0.0, 0.32, true)


static func tenpenchii(pj, c: Node3D, _t: Node3D) -> void:
	var id = "tenpenchii"
	var R = 38.0
	pj.busy(c, 2.0)
	pj.anim(c, "cast", 0.9)
	var at: Vector3 = pj.gp(c.global_position)
	var root = Node3D.new()
	pj.scene_add(root, at)
	var cw = weakref(c)
	var alive = func():
		var cc = cw.get_ref()
		return cc if cc != null and pj.live(cc) else null
	# deprem: üç dalga
	var quake = _flat(R * 2.0, _mat("tenpen_catlak", QUAKE_SH))
	quake.position.y = 0.08
	root.add_child(quake)
	_param(quake, "prog", 0.0, 1.0, 3.0)
	for k in 3:
		pj.after(0.3 + k * 0.8, func():
			var cc = alive.call()
			if cc == null:
				return
			pj.shake(0.7)
			Sfx.play("earth", at, 0.55, 1.0)
			for e in pj.enemies_near(cc, at, R * (0.4 + k * 0.3)):
				if _on_ground(e):
					e.take_hit(pj.inf(cc, id, 0.08, {"knock": 0.0, "kind": "light", "hitstop": 0.0}))
					pj.st(e, "stun", 0.5))
	# bulut tavanı ve sel
	var cloud = _node(_cards(70, func(_i):
		var a = randf() * TAU
		var r = sqrt(randf()) * R
		return [Vector3(cos(a) * r, 30.0 + randf() * 5.0, sin(a) * r), Color(randf(), randf(), 0, 1)]), _mat("tenpen_bulut", CLOUD_SH), 80.0)
	root.add_child(cloud)
	cloud.set_instance_shader_parameter("rise", 1.0)
	_param(cloud, "prog", 0.0, 1.0, 2.0)
	var flood = _flat(R * 2.0, _mat("tenpen_sel", FLOOD_SH))
	flood.position.y = 0.3
	flood.visible = false
	root.add_child(flood)
	pj.after(2.0, func():
		if not is_instance_valid(flood):
			return
		flood.visible = true
		_param(flood, "prog", 0.02, 1.0, 2.2)
		Sfx.play("water", at, 0.6, 1.0))
	pj.every(5.0, 0.5, func(_i, _k):
		var cc = alive.call()
		if cc == null:
			return
		for e in pj.enemies_near(cc, at, R):
			pj.st(e, "wet", 3.0)
			pj.st(e, "slow", 1.0))
	# hortumlar
	var twists = []
	for k in 3:
		var tw = _node(_cards(120, func(_i): return [Vector3.ZERO, Color(randf(), randf(), 0, 1)]), _mat("tenpen_hortum", TWIST_SH), 40.0)
		tw.visible = false
		root.add_child(tw)
		twists.append(tw)
	pj.after(3.0, func():
		for tw in twists:
			if is_instance_valid(tw):
				tw.visible = true)
	pj.every(4.4, 0.05, func(i, k):
		var cc = alive.call()
		for q in 3:
			var tw = twists[q]
			if not is_instance_valid(tw):
				continue
			var a = q * TAU / 3.0 + k * 2.6
			var r = 11.0 + 9.0 * sin(k * 3.0 + q)
			tw.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
			if cc != null and i % 5 == 0:
				var wp: Vector3 = root.to_global(tw.position)
				for e in pj.enemies_near(cc, wp, 6.0):
					if e is CharacterBody3D:
						e.velocity += (wp - e.global_position).normalized() * 6.0 + Vector3.UP * 3.0
					e.take_hit(pj.inf(cc, id, 0.03, {"knock": 0.0, "kind": "light", "hitstop": 0.0})))
	# gök gürültülü fırtına: ıslak hedefte daha sert
	for k in 16:
		pj.after(3.0 + k * 0.27, func():
			var cc = alive.call()
			if cc == null:
				return
			var foes = pj.enemies_near(cc, at, R)
			var p: Vector3
			if not foes.is_empty() and randf() < 0.65:
				p = pj.gp((foes[randi() % foes.size()] as Node3D).global_position)
			else:
				var a = randf() * TAU
				p = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, R))
			_bolt(pj, p + Vector3(randf_range(-5, 5), 30.0, randf_range(-5, 5)), p)
			Sfx.play("zap", p, randf_range(0.6, 0.85), 0.8)
			for e in pj.enemies_near(cc, p, 3.0):
				var wet = e.has_method("has_status") and e.has_status("wet")
				e.take_hit(pj.inf(cc, id, 0.14 if wet else 0.09, {"knock": 1.0, "stun": 0.4, "kind": "light", "hitstop": 0.02})))
	# son: patlama ve mantar bulutu
	pj.after(7.6, func():
		var cc = alive.call()
		if is_instance_valid(root):
			for tw in twists:
				if is_instance_valid(tw):
					tw.visible = false
			var fl = MeshInstance3D.new()
			var qm = QuadMesh.new()
			qm.size = Vector2.ONE * 130.0
			fl.mesh = qm
			fl.material_override = _mat("tenpen_parlama", BLAST_SH)
			fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fl.position = Vector3.UP * 12.0
			root.add_child(fl)
			_param(fl, "prog", 0.0, 1.0, 0.9, true)
			var mush = _node(_cards(90, func(i):
				if i < 30:
					var a0 = randf() * TAU
					return [Vector3(cos(a0) * randf() * 5.0, randf() * 34.0, sin(a0) * randf() * 5.0), Color(randf(), randf() * 0.3, 0, 1)]
				var a1 = randf() * TAU
				var r1 = lerpf(4.0, 25.0, sqrt(randf()))
				return [Vector3(cos(a1) * r1, 36.0 + randf() * 11.0 - r1 * 0.2, sin(a1) * r1), Color(randf(), randf(), 0, 1)]), _mat("tenpen_bulut", CLOUD_SH), 90.0)
			root.add_child(mush)
			mush.set_instance_shader_parameter("c0", Color(0.2, 0.22, 0.16))
			mush.set_instance_shader_parameter("c1", Color(0.36, 0.39, 0.29))
			mush.set_instance_shader_parameter("c2", Color(0.58, 0.6, 0.47))
			_param(mush, "prog", 0.0, 1.0, 2.2)
			_param(mush, "rise", 0.0, 1.0, 2.2)
			pj.after(3.2, func():
				if is_instance_valid(mush):
					_param(mush, "prog", 1.0, 0.0, 1.5)
				if is_instance_valid(flood):
					_param(flood, "fade", 1.0, 0.0, 1.5)
				if is_instance_valid(cloud):
					_param(cloud, "prog", 1.0, 0.0, 1.5))
		pj.shake(1.5)
		Sfx.play("boom", at, 0.45, 1.0)
		if cc != null:
			pj.hit(cc, at + Vector3.UP, R * 0.8, pj.inf(cc, id, 1.0, {"knock": 20.0, "launch": 12.0, "kind": "heavy", "hitstop": 0.12})))
	pj.after(12.5, func():
		if is_instance_valid(root):
			root.queue_free())


# ------------------------------------------------------------------ 5 Yosakugiri: baltayla yere paralel alçak savuruş (ref Yosaku_Cut.PNG)
const FURROW_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
instance uniform float prog = 0.0;
instance uniform float fade = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.x, -p.y);
	float front = mix(-1.92, 1.92, prog);
	float w = 0.08 + 0.025 * sin(a * 23.0) + 0.012 * sin(a * 61.0);
	float d = abs(r - 0.78);
	if (d > w || abs(a) > 1.92 || a > front) discard;
	float t = d / w;
	ALBEDO = t < 0.55 ? vec3(0.09, 0.065, 0.05) : (t < 0.8 ? vec3(0.23, 0.17, 0.12) : vec3(0.36, 0.28, 0.2));
	ALPHA = fade;
}
"""


static func _on_ground(e: Node3D) -> bool:
	if e is Player:
		return bool(e.get("grounded"))
	if e is CharacterBody3D and e.is_on_floor():
		return true
	return e.global_position.y - Game.ground_height(e.global_position.x, e.global_position.z) < 0.4   # arazi yükseklik fonksiyonu: is_on_floor çimende güvenilmez


static func yosakugiri(pj, c: Node3D, t: Node3D) -> void:
	var id = "yosakugiri"
	var tt = pj.tg(c, t, 6.0)
	var d: Vector3 = pj._face(c, tt)
	pj.busy(c, 0.95)
	var m = c.get("model")
	if m != null and m.overlay != null:
		var L = S.LEG_LUNGE
		var B = S.LEG_BACK
		var w0 = S._a({"RightUpperArm": Vector3(0.75, -0.25, -0.6), "RightLowerArm": Vector3(0.7, -0.5, -0.5)}, {"LeftUpperArm": Vector3(0.75, -0.45, -0.45), "LeftLowerArm": Vector3(-0.1, -0.6, -0.8)})
		var w1 = S._a({"RightUpperArm": Vector3(-0.8, -0.45, 0.4), "RightLowerArm": Vector3(-0.8, -0.5, 0.3)}, {"LeftUpperArm": Vector3(-0.35, -0.6, 0.72), "LeftLowerArm": Vector3(-0.9, -0.35, 0.25)})
		m.overlay.play_keys({"len": 0.95, "hit": 0.42, "keys": [S._k(0.0, 0.4, 0.0, 2.0, Vector3(0.7, -0.3, 0.6).normalized(), w0, B),
			S._k(0.32, 0.62, -42.0, 14.0, Vector3(0.9, -0.35, -0.3).normalized(), w0, B), S._k(0.5, 0.72, 48.0, 22.0, Vector3(-0.9, -0.4, 0.2).normalized(), w1, L),
			S._k(0.74, 0.66, 56.0, 18.0, Vector3(-0.9, -0.4, 0.1).normalized(), w1, L), S._k(0.95, 0.4, 0.0, 2.0, Vector3(0.7, -0.3, 0.6).normalized(), w0, B)]}, 1.0)
		c.get_tree().create_timer(0.93).timeout.connect(func():
			if is_instance_valid(m) and m.overlay != null:
				m.overlay.stop_keys())
	var cw = weakref(c)
	pj.after(0.42, func():
		var cc = cw.get_ref()
		if cc == null or not pj.live(cc):
			return
		var at: Vector3 = pj.gp(cc.global_position)
		var f = _flat(9.4, _mat("yosaku_iz", FURROW_SH))
		pj.scene_add(f, at + Vector3.UP * 0.05)
		f.look_at(f.global_position + d, Vector3.UP)
		_param(f, "prog", 0.0, 1.0, 0.16)
		var ft = f.create_tween()
		ft.tween_interval(1.7)
		ft.tween_method(func(v: float):
			if is_instance_valid(f):
				f.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6)
		ft.tween_callback(f.queue_free)
		Sfx.play("swing_blade", at, 0.8, 0.9)
		var side: Vector3 = Vector3.UP.cross(d).normalized()
		for i in 18:   # savrulan toprak parçaları ağız önünde
			var a = lerpf(-1.8, 1.8, float(i) / 17.0)
			var o: Vector3 = (d * cos(a) - side * sin(a)) * 3.7
			var mi = MeshInstance3D.new()
			var b = MB.new()
			b.add("boulder", Vector3.ZERO, Vector3.ONE * randf_range(0.08, 0.2), Color(0.3, 0.23, 0.16), Vector3.ZERO, i % 4)
			mi.mesh = b.build(Props.toon())
			pj.scene_add(mi, at + o + Vector3.UP * 0.1)
			var v0: Vector3 = o.normalized() * randf_range(1.6, 3.8) + Vector3.UP * randf_range(2.0, 4.2)
			var p0: Vector3 = mi.global_position
			var fly = func(k: float) -> void:
				if is_instance_valid(mi):
					mi.global_position = p0 + v0 * k * 0.8 + Vector3.DOWN * 4.9 * k * k * 0.64
					mi.rotation = Vector3(k * 9.0, k * 6.0, 0.0)
			var tw = mi.create_tween()
			tw.tween_interval(absf(a + 1.8) * 0.02)
			tw.tween_method(fly, 0.0, 1.0, 0.8)
			tw.tween_callback(mi.queue_free)
		for e in pj.enemies_near(cc, at, 4.0):
			var to: Vector3 = e.global_position - at
			to.y = 0.0
			if to.length() > 0.2 and to.normalized().dot(d) < -0.35:
				continue
			if not _on_ground(e):   # kanon: alçak savuruş; havadakini biçemez
				continue
			e.take_hit(pj.inf(cc, id, 1.0, {"knock": 3.5, "launch": 2.0, "kind": "heavy", "melee": true, "blade": true, "stun": 0.7, "hitstop": 0.09}))
			pj.st(e, "slow", 2.5)
		pj.shake(0.3))
