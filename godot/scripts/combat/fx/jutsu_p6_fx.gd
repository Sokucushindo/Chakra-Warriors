extends RefCounted
## Eksik jutsular, parti 6 (hedef: res://scripts/combat/fx/jutsu_p6_fx.gd). Kaynak: refs/new/<id>.
## Altyapı (malzeme önbelleği, şerit) parti 3 dosyasından; görünen her şey tekniğin kendi gölgelendirici ve geometrisi.

const P = preload("res://scripts/combat/fx/jutsu_p3_fx.gd")
const Tsuru = preload("res://scripts/combat/fx/tsurukame_fx.gd")

static var _meshes := {}

const THREAD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float k = 1.0;
void fragment() {
	float e = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(vec3(0.62, 0.52, 0.78), vec3(0.97, 0.9, 1.0), e);
	ALPHA = smoothstep(0.0, 0.6, e) * (0.65 + 0.35 * sin(UV.x * 26.0 - TIME * 8.0)) * k;
}
"""

const STRAND_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float k = 1.0;
void fragment() {
	ALBEDO = vec3(0.07, 0.06, 0.08);
	ALPHA = (1.0 - abs(UV.y * 2.0 - 1.0)) * k;
}
"""

const SPARK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float k = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = abs(atan(p.y, p.x));
	float s = abs(sin(a * 3.0));
	float r = length(p);
	ALBEDO = vec3(1.0, 0.97, 0.9);
	ALPHA = smoothstep(0.35 + 0.6 * s, 0.0, r) * k;
}
"""

const SKIN_SH := """shader_type spatial;
render_mode cull_disabled, depth_draw_always, specular_disabled;
instance uniform float k = 1.0;
instance uniform float thin = 0.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	float w = sin(VERTEX.y * 9.0 + atan(VERTEX.x, VERTEX.z) * 5.0) * 0.03 * thin;
	VERTEX += NORMAL * w;
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float band = smoothstep(0.7, 1.5, lp.y + 0.12 * sin(atan(lp.x, lp.z) * 2.0));
	vec3 belly = vec3(0.92, 0.42, 0.68);
	vec3 top = vec3(0.86, 0.5, 0.74);
	ALBEDO = mix(belly, top, band) + rim * 0.22;
	float scale = 0.5 + 0.5 * sin(lp.y * 46.0) * sin(atan(lp.x, lp.z) * 22.0);
	ALPHA = k * mix(1.0, 0.42 + 0.3 * scale + rim * 0.3, thin);
	ALPHA_SCISSOR_THRESHOLD = 0.04;
}
"""

const SWOOSH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float e = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(1.0, 0.97, 0.86);
	ALPHA = smoothstep(0.0, 0.7, e) * UV.y * UV.y * 0.75;
}
"""


# ------------------------------------------------------------------ ortak düşük seviye
static func _thread(pj, a_fn: Callable, b_fn: Callable, dur: float, w: float, shader_key: String, shader: String, sag := 0.15) -> MeshInstance3D:
	var im = ImmediateMesh.new()
	var x = P._mi(im, P._mat(shader_key, shader))
	x.extra_cull_margin = 16384.0
	P._put(pj, x, Vector3.ZERO)
	x.global_transform = Transform3D.IDENTITY
	pj.free_after(dur + 0.2, x)
	pj.every(dur, 0.04, func(_i: int, _u: float) -> void:
		if not is_instance_valid(x):
			return
		var a: Vector3 = a_fn.call()
		var b: Vector3 = b_fn.call()
		var wv: Vector3 = Vector3.UP if absf((b - a).normalized().y) < 0.8 else Vector3.RIGHT
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for j in 13:
			var v = j / 12.0
			var p: Vector3 = a.lerp(b, v) + Vector3.DOWN * sin(v * PI) * sag
			im.surface_set_uv(Vector2(v, 0.0))
			im.surface_add_vertex(p - wv * w * 0.5)
			im.surface_set_uv(Vector2(v, 1.0))
			im.surface_add_vertex(p + wv * w * 0.5)
		im.surface_end())
	return x


static func _head(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * 1.62


# ================================================================== KUGUTSU MODOKI
## Kanon (Puppet Imitation, Saya): kukla hedeften saç teli alır; kullanan özel el mührüyle hedefi yönetir. Ino bunu Yamanaka
## tekniklerinin ucuz taklidi sayar. Oyunda: kukla ıskalarsa teknik boşa gider. Sıradan düşman kısa süre kullananın safına geçer;
## oyuncu ve patron yalnız kısa süre bağlanır. Kullanan sersemlerse bağ kopar.
static func kugutsu_modoki(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 20.0)
	var f: Vector3 = pj.fwd(c, tt)
	var from: Vector3 = P._chest(c) + f * 0.6
	var dir: Vector3 = (P._chest(tt) - from).normalized() if pj.live(tt) else f
	var doll = Node3D.new()
	var body = MeshInstance3D.new()
	body.mesh = _doll_mesh()
	body.rotation.y = PI
	doll.add_child(body)
	var land = func(_p: Vector3, who: Node3D) -> void:
		if who != null and pj.live(who):
			_snip(pj, c, who)
	var pr = pj.shot(c, from, dir, 21.0, doll, pj.inf(c, "kugutsu_modoki", 0.04, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "melee": false}), tt if pj.live(tt) else null, false, 1.25, land)
	pr.homing_turn = 3.2
	pr.radius = 0.32
	Sfx.play("clink", from, 1.5, 0.6)


## Kırmızı kimonolu, maskeli, uzun siyah saçlı küçük kukla (refs/new/kugutsu_modoki)
static func _doll_mesh() -> Mesh:
	if _meshes.has("doll"):
		return _meshes["doll"]
	var b = MB.new()
	var red = Color(0.78, 0.2, 0.26)
	var pink = Color(0.93, 0.62, 0.7)
	var black = Color(0.06, 0.05, 0.07)
	b.add("frustum", Vector3(0, -0.13, 0), Vector3(0.34, 0.34, 0.3), red, Vector3(180, 0, 0), 10)
	b.add("sphere", Vector3(0, 0.02, 0), Vector3(0.2, 0.2, 0.18), red.darkened(0.12), Vector3.ZERO, 8)
	b.add("cyl", Vector3(0, -0.06, 0), Vector3(0.23, 0.05, 0.21), pink, Vector3.ZERO, 10)
	for s in [-1.0, 1.0]:
		b.add("cyl", Vector3(s * 0.15, -0.05, 0.0), Vector3(0.08, 0.22, 0.08), red, Vector3(0, 0, s * 42.0), 6)
		b.add("box", Vector3(s * 0.03, 0.2, 0.082), Vector3(0.03, 0.01, 0.006), Color(0.1, 0.08, 0.1), Vector3(0, 0, s * 12.0))
	b.add("sphere", Vector3(0, 0.2, 0), Vector3(0.19, 0.22, 0.17), Color(0.96, 0.94, 0.9), Vector3.ZERO, 10)
	b.add("box", Vector3(0, 0.14, 0.085), Vector3(0.05, 0.008, 0.006), Color(0.7, 0.12, 0.16))
	b.add("sphere", Vector3(0, 0.25, -0.03), Vector3(0.23, 0.2, 0.2), black, Vector3.ZERO, 8)
	b.add("box", Vector3(0, 0.02, -0.1), Vector3(0.2, 0.42, 0.05), black)
	for s in [-1.0, 1.0]:
		b.add("box", Vector3(s * 0.1, 0.08, -0.02), Vector3(0.04, 0.32, 0.08), black)
	_meshes["doll"] = b.build(Props.toon())
	return _meshes["doll"]


static func _snip(pj, c: Node3D, tt: Node3D) -> void:
	Sfx.play("clink", tt.global_position, 1.9, 0.5)
	var from: Vector3 = _head(tt)
	var clock = {"u": 0.0}
	var tip_fn = func() -> Vector3:
		return from.lerp(pj.hand_pos(c, true), clock["u"]) if pj.live(c) else from
	var tail_fn = func() -> Vector3:
		return from.lerp(pj.hand_pos(c, true), maxf(0.0, clock["u"] - 0.12)) if pj.live(c) else from
	var hair = _thread(pj, tail_fn, tip_fn, 0.42, 0.012, "kugutsu_sac", STRAND_SH, 0.02)
	pj.every(0.4, 0.04, func(_i: int, u: float) -> void:
		clock["u"] = u)
	pj.free_after(0.45, hair)
	pj.after(0.45, func() -> void:
		if pj.live(c) and pj.live(tt):
			_take(pj, c, tt))


static func _take(pj, c: Node3D, tt: Node3D) -> void:
	var enemy_like = tt is Enemy and not (tt is Boss)
	var dur = 7.0 if enemy_like else 1.8
	var old = tt.get("team")
	if enemy_like:
		tt.team = c.team
		tt.target = null
	else:
		pj.st(tt, "bind", dur)
	pj.st(tt, "stun", 0.3)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.5, "Kukla oldu!", Color(0.85, 0.72, 1.0))
	Sfx.play("seal", c.global_position, 1.3, 0.7)
	var lines := []
	for k in 5:
		var off = Vector3(cos(k * 1.26) * 0.14, sin(k * 1.26) * 0.08, sin(k * 1.26) * 0.14)
		var ends = {"a": pj.hand_pos(c, k % 2 == 0), "b": _head(tt) + off}   # taraf silinirse ip son yerinde kalır
		var a_fn = func() -> Vector3:
			if pj.live(c):
				ends["a"] = pj.hand_pos(c, k % 2 == 0)
			return ends["a"]
		var b_fn = func() -> Vector3:
			if pj.live(tt):
				ends["b"] = _head(tt) + off
			return ends["b"]
		lines.append(_thread(pj, a_fn, b_fn, dur, 0.012, "kugutsu_ip", THREAD_SH, 0.18))
	var over = {"v": false}
	var release = func() -> void:
		if over["v"]:
			return
		over["v"] = true
		for l in lines:
			if is_instance_valid(l):
				l.queue_free()
		if enemy_like and pj.live(tt):
			tt.team = old
			tt.target = null
			pj.st(tt, "stun", 0.8)
	pj.every(dur, 0.1, func(_i: int, _u: float) -> void:
		if over["v"]:
			return
		if not pj.live(c) or not pj.live(tt) or (c.has_method("has_status") and (c.has_status("stun") or c.has_status("bind"))):
			release.call(), release)


# ================================================================== RENSHA
## Kanon (Rapid Fire, Kusune): Tsurukame kabuğundan yoğun, kalın senbon yağmuru. Oyunda: Tsurukame şart, gerçek cephane harcar;
## kabuk ağızlarından geniş yayla saçılır, ortası hedefe dönüktür.
static func rensha(pj, c: Node3D, t: Node3D) -> void:
	var shots = 16
	var gap = 0.065
	pj.busy(c, shots * gap + 0.2)
	var tt = pj.tg(c, t, 24.0)
	var left = {"stop": false}
	for k in shots:
		pj.after(0.12 + k * gap, func() -> void:
			if left["stop"] or not pj.live(c):
				return
			if Tsuru._spend(c, 1) <= 0:
				left["stop"] = true
				return
			var f: Vector3 = pj.fwd(c, tt)
			var from: Vector3 = Tsuru._port(c)
			var aim: Vector3 = (P._chest(tt) - from).normalized() if pj.live(tt) else f
			var fan = deg_to_rad((1.0 if k % 2 == 0 else -1.0) * randf_range(0.0, 34.0 if k % 3 != 0 else 5.0))
			var d: Vector3 = (aim.rotated(Vector3.UP, fan) + Vector3.UP * randf_range(-0.05, 0.1)).normalized()
			_spike(pj, c, from, d)
			_flash(pj, from)
			if c is CharacterBody3D:
				c.velocity -= f * 0.35
			Sfx.play("kunai", from, randf_range(0.62, 0.8), 0.5))


static func _spike_mesh() -> Mesh:
	if not _meshes.has("spike"):
		var b = MB.new()
		var bs = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) * Basis.from_scale(Vector3(0.075, 1.0, 0.075))
		b.add_xf("cone", Transform3D(bs, Vector3.ZERO), Color(0.86, 0.87, 0.85), 6)
		var ring = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) * Basis.from_scale(Vector3(0.082, 0.05, 0.082))
		b.add_xf("cyl", Transform3D(ring, Vector3(0, 0, 0.47)), Color(0.34, 0.35, 0.38), 6)
		_meshes["spike"] = b.build(Props.toon())
	return _meshes["spike"]


static func _spike(pj, c: Node3D, from: Vector3, d: Vector3) -> void:
	var v = MeshInstance3D.new()
	v.mesh = _spike_mesh()
	var land = func(p: Vector3, who: Node3D) -> void:
		if who != null:
			return
		var s = MeshInstance3D.new()
		s.mesh = _spike_mesh()
		P._put(pj, s, p - d * 0.28)
		s.look_at(s.global_position + d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
		pj.free_after(2.2, s)
	var pr = pj.shot(c, from, d, 52.0, v, pj.inf(c, "rensha", 0.13, {"knock": 0.6, "kind": "light", "hitstop": 0.0, "bleed": 0.8, "melee": false}), null, false, 0.75, land)
	pr.radius = 0.16


static func _flash(pj, at: Vector3) -> void:
	if not _meshes.has("spark"):
		var q = QuadMesh.new()
		q.size = Vector2(0.46, 0.46)
		_meshes["spark"] = q
	var x = P._mi(_meshes["spark"], P._mat("rensha_cikis", SPARK_SH))
	P._put(pj, x, at)
	P._fade(x, 1.0, 0.0, 0.09, true)


# ================================================================== URA SHIROHIGI: JIKKI UEMATSU NO SHŪ
## Kanon (Chiyo; Sōen: Hitomi Goku'dan türer): on bedeni birden yönetir, tek noktaya her yandan aynı anda saldırtır.
## Oyunda: on savaş kuklası hedefin üstünde yay kurar, ipleriyle bir arada iner. Yana kaçan kurtulur.
static func jikki_uematsu(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.5)
	var tt = pj.tg(c, t, 26.0)
	var at: Vector3 = pj.gp(tt.global_position if pj.live(tt) else c.global_position + pj.fwd(c, tt) * 10.0)
	var d = JutsuEngine.base_dmg(c, Jutsu._jd("jikki_uematsu"))
	var units := []
	for k in 10:
		var a = TAU * k / 10.0
		var u = ClanConstruct.new()
		u.kind = "puppet"
		u.owner_f = c
		u.team = c.team
		u.slot = k
		u.dmg = d * 0.1
		u.life = 3.0
		c.get_tree().current_scene.add_child(u)
		u.remove_from_group("fighters")
		u.set_physics_process(false)
		for th in u.threads:
			if is_instance_valid(th):
				th.queue_free()
		u.threads = []
		var top: Vector3 = at + Vector3(cos(a) * 5.5, 5.2 + 0.8 * sin(a * 2.0), sin(a) * 5.5)
		u.global_position = c.global_position + Vector3.UP * 0.5
		u.scale = Vector3.ONE * 0.2
		u.look_at(Vector3(at.x, u.global_position.y, at.z) + Vector3(0.001, 0.0, 0.0), Vector3.UP)
		var tw = u.create_tween()
		tw.set_parallel(true)
		tw.tween_property(u, "global_position", top, 0.48).set_delay(k * 0.022).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(u, "scale", Vector3.ONE, 0.4).set_delay(k * 0.022)
		units.append(u)
		var hand_r = k % 2 == 0
		var a_fn = func() -> Vector3:
			return pj.hand_pos(c, hand_r) if pj.live(c) else c.global_position
		var b_fn = func() -> Vector3:
			return u.global_position + Vector3.UP * 1.3 if is_instance_valid(u) else at
		_thread(pj, a_fn, b_fn, 1.95, 0.012, "uematsu_ip", THREAD_SH, 0.1)
	Sfx.play("clink", c.global_position, 0.7, 0.9)
	var strike = Vector3(at.x, at.y + 0.2, at.z)
	pj.after(0.95, func() -> void:
		var hit_at: Vector3 = strike
		if pj.live(tt):
			var p: Vector3 = pj.gp(tt.global_position)
			hit_at = Vector3(p.x, p.y + 0.2, p.z)
		for k in units.size():
			var u2 = units[k]
			if not is_instance_valid(u2):
				continue
			var a2 = TAU * k / 10.0
			var goal: Vector3 = hit_at + Vector3(cos(a2), 0.0, sin(a2)) * 0.55
			var tw2 = u2.create_tween()
			tw2.tween_interval(k * 0.012)
			tw2.tween_property(u2, "global_position", goal, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pj.after(0.3, func() -> void:
			if pj.live(c):
				pj.hit(c, hit_at + Vector3.UP * 0.9, 1.9, pj.inf(c, "jikki_uematsu", 1.35, {"knock": 9.0, "kind": "heavy", "stun": 0.5, "melee": false}))
			pj.shake(0.6)
			Sfx.play("hit_heavy_weapon", hit_at, 0.8, 0.9))
		pj.after(0.75, func() -> void:
			for u3 in units:
				if is_instance_valid(u3):
					var tw3 = u3.create_tween()
					tw3.tween_property(u3, "scale", Vector3.ONE * 0.05, 0.2)
					tw3.tween_callback(u3.queue_free)))


# ================================================================== RIBĀSHIBURU
## Kanon (Reversible Technique, Orochimaru): dev yılan hedefi yutar, deri değiştirir, ardından sindirir.
## Görsel: pembe yılan, yutunca karnı dev balon olur; deriden ince yılan çıkar. Oyunda: yutulan bağlıdır, sindirilir, sonunda
## kusulur. Bağı çözen ya da patron yutulamaz; o zaman yalnız ısırık.
static func ribashiburu(pj, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 14.0)
	var at: Vector3 = pj.gp(tt.global_position if pj.live(tt) else c.global_position + pj.fwd(c, tt) * 6.0)
	var root = Node3D.new()
	P._put(pj, root, at + Vector3.DOWN * 5.5)
	root.rotation.y = randf() * TAU
	var sn: Dictionary = SummonModels.toon_snake(root, 9.0, 5.0, 0.5, Color(0.86, 0.46, 0.72), Color(0.96, 0.72, 0.84), Color(0.72, 0.3, 0.58), false)
	var mouth: Vector3 = sn["mouth"]
	var holder: Node3D = sn["node"]
	holder.position = Vector3(-mouth.x, 0.0, -mouth.z)
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", at, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pj.free_after(6.5, root)
	Sfx.play("roar", at, 1.5, 0.6)
	pj.after(0.42, func() -> void:
		if sn["anim"] != null and is_instance_valid(sn["anim"]):
			sn["anim"].bite()
		if not pj.live(c):
			return
		var can = pj.live(tt) and tt.has_method("has_status") and tt.global_position.distance_to(at) < 2.6 and not (tt is Boss)
		pj.hit(c, at + Vector3.UP, 1.5, pj.inf(c, "ribashiburu", 0.35, {"knock": 1.0, "melee": false}))
		if can:
			_swallow(pj, c, tt, at, root)
		else:
			var out = root.create_tween()
			out.tween_interval(0.35)
			out.tween_property(root, "global_position", at + Vector3.DOWN * 6.0, 0.4)
			out.tween_callback(root.queue_free))


static func _swallow(pj, c: Node3D, tt: Node3D, at: Vector3, root: Node3D) -> void:
	var hold = 2.4
	pj.st(tt, "bind", hold)
	var mdl = tt.get("model")
	if mdl != null:
		mdl.visible = false
	var belly = P._mi(_belly_mesh(), P._mat("ribashiburu_deri", SKIN_SH))
	P._put(pj, belly, at + Vector3.UP * 0.2)
	belly.scale = Vector3.ONE * 0.35
	belly.set_instance_shader_parameter("thin", 0.0)
	belly.set_instance_shader_parameter("k", 1.0)
	belly.create_tween().tween_property(belly, "scale", Vector3.ONE * 0.75, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("poof", at, 0.6, 0.7)
	var rise = root.create_tween()
	rise.tween_property(root, "global_position", at + Vector3.UP * 1.9, 0.5)
	var done = {"v": false}
	var free_him = func() -> void:
		if done["v"]:
			return
		done["v"] = true
		if is_instance_valid(mdl):
			mdl.visible = true
		if pj.live(tt):
			pj.st(tt, "stun", 0.35)
		_shed(pj, belly, root, at)
	pj.every(hold, 0.4, func(_i: int, _u: float) -> void:
		if done["v"]:
			return
		if not pj.live(tt) or not tt.has_status("bind") or not pj.live(c):
			free_him.call()
			return
		tt.global_position = at + Vector3.UP * 0.1
		pj.hit(c, at + Vector3.UP, 0.8, pj.inf(c, "ribashiburu", 0.17, {"knock": 0.0, "kind": "light", "hitstop": 0.0, "pierce_guard": true, "melee": false})), free_him)


## Şişmiş karın: alttan geniş damla
static func _belly_mesh() -> Mesh:
	if not _meshes.has("belly"):
		var b = MB.new()
		var pts = [[0.0, 0.1], [0.08, 1.4], [0.5, 2.5], [1.3, 3.05], [2.2, 2.75], [3.0, 1.85], [3.55, 0.9], [3.82, 0.46], [4.1, 0.42]]
		var ps := []
		var rs := []
		for q in pts:
			ps.append(Vector3(0, float(q[0]), 0))
			rs.append(float(q[1]))
		Loft.tube(b, ps, rs, Color(0.9, 0.5, 0.74), 22, 3)
		_meshes["belly"] = b.build()
	return _meshes["belly"]


## Deri boşalır; ince yılan sıyrılıp uzaklaşır
static func _shed(pj, belly: MeshInstance3D, root: Node3D, at: Vector3) -> void:
	Sfx.play("wind", at, 1.5, 0.6)
	if is_instance_valid(belly):
		var set_thin = func(v: float) -> void:
			if is_instance_valid(belly):
				belly.set_instance_shader_parameter("thin", v)
		var tw = belly.create_tween()
		tw.set_parallel(true)
		tw.tween_method(set_thin, 0.0, 1.0, 0.35)
		tw.tween_property(belly, "scale", Vector3(0.84, 0.22, 0.84), 0.9).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_interval(0.05)
		var gone = func() -> void:
			if is_instance_valid(belly):
				P._fade(belly, 1.0, 0.0, 0.4, true)
		tw.chain().tween_callback(gone)
	if is_instance_valid(root):
		var dir = Vector3.FORWARD.rotated(Vector3.UP, root.rotation.y)
		var out = root.create_tween()
		out.tween_interval(0.25)
		out.tween_property(root, "global_position", at + dir * 7.0 + Vector3.DOWN * 5.8, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		out.tween_callback(root.queue_free)


# ================================================================== KAWARA SHURIKEN
## Kanon (Hiruzen; Tora-Tatsu-Ne-Uma-Tora): çevredeki kiremitler chakrayla kalkar, sertleşir, dönerek savrulur.
## Oyunda: on iki kiremit çevreden yükselir, kullananın çevresinde döner, sırayla hedefe gider.
static func kawara_shuriken(pj, c: Node3D, t: Node3D) -> void:
	var n = 12
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 28.0)
	var tiles := []
	for k in n:
		var a = TAU * k / n
		var x = MeshInstance3D.new()
		x.mesh = _tile_mesh()
		var g: Vector3 = pj.gp(c.global_position + Vector3(cos(a), 0.0, sin(a)) * 2.6)
		P._put(pj, x, g + Vector3.UP * 0.04)
		tiles.append(x)
		pj.free_after(2.6, x)
	Sfx.play("earth", c.global_position, 1.6, 0.5)
	var orbit = {"a": 0.0}
	pj.every(1.5, 0.03, func(i: int, _u: float) -> void:
		if not pj.live(c):
			return
		orbit["a"] += 0.09 + minf(i * 0.004, 0.13)
		var lift = smoothstep(0.0, 18.0, float(i))
		for k in tiles.size():
			var x2 = tiles[k]
			if not is_instance_valid(x2) or x2.get_meta("gone", false):
				continue
			var a2 = TAU * k / n + orbit["a"]
			var r = lerpf(2.6, 1.75, lift)
			var y = lerpf(0.04, 1.25 + 0.3 * sin(a2 * 2.0 + float(i) * 0.1), lift)
			x2.global_position = pj.gp(c.global_position) + Vector3(cos(a2) * r, y, sin(a2) * r)
			x2.rotation = Vector3(float(i) * 0.09 + k, -a2, float(i) * 0.14))
	for k in n:
		pj.after(0.62 + k * 0.07, func() -> void:
			var x3 = tiles[k]
			if not is_instance_valid(x3) or not pj.live(c):
				return
			x3.set_meta("gone", true)
			var from: Vector3 = x3.global_position
			var aim: Vector3 = (P._chest(tt) - from).normalized() if pj.live(tt) else pj.fwd(c, tt)
			x3.queue_free()
			_throw_tile(pj, c, from, aim, tt)
			Sfx.play("whoosh", from, randf_range(1.2, 1.5), 0.45))


static func _tile_mesh() -> Mesh:
	if not _meshes.has("tile"):
		var b = MB.new()
		var gold = Color(0.93, 0.68, 0.16)
		var dk = Color(0.66, 0.42, 0.08)
		b.add("halfcyl", Vector3.ZERO, Vector3(0.5, 0.16, 0.36), gold, Vector3(0, 90, 0), 10)
		b.add("box", Vector3(0, 0.005, 0.245), Vector3(0.37, 0.04, 0.03), dk)
		b.add("box", Vector3(0, 0.005, -0.245), Vector3(0.33, 0.03, 0.02), dk)
		for s in [-1.0, 1.0]:
			b.add("box", Vector3(s * 0.17, -0.01, 0.0), Vector3(0.018, 0.03, 0.48), dk)
		_meshes["tile"] = b.build(Props.toon())
	return _meshes["tile"]


static func _throw_tile(pj, c: Node3D, from: Vector3, aim: Vector3, tt: Node3D) -> void:
	var root = Node3D.new()
	var spin = Node3D.new()
	root.add_child(spin)
	var m = MeshInstance3D.new()
	m.mesh = _tile_mesh()
	spin.add_child(m)
	var tw = spin.create_tween().set_loops(4)
	tw.tween_property(spin, "rotation:y", TAU, 0.16).from(0.0)
	if not _meshes.has("tile_iz"):
		var q = QuadMesh.new()
		q.size = Vector2(0.34, 1.5)
		_meshes["tile_iz"] = q
	var tr = P._mi(_meshes["tile_iz"], P._mat("kawara_iz", SWOOSH_SH))
	tr.rotation.x = PI * 0.5
	tr.position = Vector3(0.0, 0.0, 0.85)
	root.add_child(tr)
	var h: Node3D = tt if pj.live(tt) else null
	var pr = pj.shot(c, from, aim, 36.0, root, pj.inf(c, "kawara_shuriken", 0.15, {"knock": 1.6, "kind": "light", "hitstop": 0.015, "melee": false}), h, false, 0.95)
	pr.homing_turn = 2.4
	pr.radius = 0.3
