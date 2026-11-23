extends RefCounted
## Kemuridama (煙玉, oyundaki alet kimliği "smoke"; hedef: res://scripts/combat/fx/kemuridama_fx.gd).
## Kanon (Narutopedia "Smoke Bomb"): kâğıda sarılı küçük top; patlayınca duman salar, rakibi kör edip vurmayı kolaylaştırır
## ya da kullanan kendini örter. Görünüş: refs/kemuridama (şerit sarılı top + uçuşan şeritler; kırılma anı sarı, sivri yıldız).
## Mekanik: bulut görüş hattını keser (oyuncu ve düşman aynı). Atan kendi dumanının içini izleyebilir.
## Aldanmayanlar: algılayıcı menzili, Byakugan / Rinnegan / Tenseigan / Jōgan, Inuzuka burnu. 2,5 m içi görülür. Rüzgâr dağıtır.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const GROUP := "kemuri_bulut"
const R := 6.0
const H := 4.2
const LIFE := 9.0
const FADE := 2.2
const SEE_NEAR := 2.5
const PIERCE_EYES := [2, 6, 7, 8]

static var _veil_k := 0.0
static var _veil_frame := -1
static var _veil_guard_on := false   # perde açıkken bağımsız bekçi döngüsü (duman erken silinse de perde kalksın)

const PUFF_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float grow = 0.0;
instance uniform float erode = 0.0;
instance uniform float light_k = 1.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float sz = COLOR.g * 4.6;
	vec3 c = VERTEX * grow;
	float t = TIME * 0.35;
	c += vec3(sin(t + sd * 40.0), 0.5 * sin(t * 0.8 + sd * 70.0), cos(t * 1.2 + sd * 90.0)) * 0.35 * grow;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float rot = sd * 6.283 + TIME * (sd - 0.5) * 0.25;
	float cs = cos(rot);
	float sn = sin(rot);
	vec2 k = (UV - 0.5) * sz * (0.35 + 0.65 * grow) * (1.0 + 0.08 * sin(TIME * 0.9 + sd * 50.0));
	v.xy += vec2(k.x * cs - k.y * sn, k.x * sn + k.y * cs);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 h = vec2(127.1, 311.7);
	float a = fract(sin(dot(i, h)) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), h)) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), h)) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), h)) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float lump = 0.10 * sin(a * 5.0 + sd * 50.0 + TIME * 0.4) + 0.06 * sin(a * 9.0 - sd * 30.0) + 0.035 * sin(a * 17.0 + sd * 9.0);
	float edge = 0.82 + lump - erode * (0.4 + 0.8 * vn(p * 3.0 + sd * 20.0));
	if (r > edge || -VERTEX.z < 0.7) discard;
	vec3 n = vec3(p, sqrt(max(0.0, 1.0 - r * r)));
	vec3 l = normalize((VIEW_MATRIX * vec4(0.45, 0.85, 0.3, 0.0)).xyz);
	float d = dot(n, l);
	vec3 col = d > 0.35 ? vec3(0.93, 0.93, 0.92) : (d > -0.05 ? vec3(0.76, 0.77, 0.80) : vec3(0.57, 0.59, 0.66));
	if (r > edge - 0.05) col *= 0.86;
	ALBEDO = col * light_k;
}
"""

const STAR_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
float tri(float x) { return abs(fract(x) - 0.5) * 2.0; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.283;
	float t1 = tri(a * 9.0 + 0.13);
	float t2 = tri(a * 23.0 + 0.4);
	float t3 = tri(a * 5.0 + 0.7);
	float e = mix(0.25, 0.97, t1 * t1) * (0.78 + 0.22 * t2) * smoothstep(0.0, 0.35, prog);
	float hole = smoothstep(0.45, 1.0, prog) * e * 0.92;
	if (r > e || r < hole) discard;
	ALBEDO = t3 > 0.5 ? vec3(1.0, 0.98, 0.56) : vec3(0.84, 0.81, 0.38);
}
"""

const RIBBON_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
instance uniform float seed_k = 0.0;
void vertex() {
	float k = VERTEX.z - 0.14;
	VERTEX.x += sin(k * 9.0 - TIME * 22.0 + seed_k) * k * 0.13;
	VERTEX.y += cos(k * 7.0 - TIME * 17.0 + seed_k * 2.0) * k * 0.11;
}
void fragment() {
	ALBEDO = FRONT_FACING ? vec3(0.82, 0.73, 0.5) : vec3(0.62, 0.53, 0.34);
}
"""

const VEIL_SH := """shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, blend_mix;
uniform float k = 0.0;
void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}
void fragment() {
	vec2 p = SCREEN_UV * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0) * 3.0;
	float t = TIME * 0.22;
	float n = sin(p.x * 1.7 + t + sin(p.y * 2.3 - t * 1.4) * 1.2) + sin(p.y * 2.9 - t * 0.8 + sin(p.x * 1.3 + t) * 1.5) + 0.5 * sin((p.x + p.y) * 5.1 + t * 2.0);
	float b = smoothstep(-0.2, 0.2, n);
	ALBEDO = mix(vec3(0.66, 0.68, 0.73), vec3(0.88, 0.88, 0.89), b);
	ALPHA = k * (0.72 + 0.14 * b);
}
"""


static func _ball_mesh() -> Mesh:
	return Kit.cached_mesh("kemuridama", func():
		var b = MB.new()
		var paper = Color(0.82, 0.71, 0.47)
		var ink = Color(0.2, 0.16, 0.1)
		b.add("sphere", Vector3.ZERO, Vector3.ONE * 0.32, paper.darkened(0.12), Vector3.ZERO, 14)
		var strips = [[Vector3(0.1, 0.2, 1), Vector3(0.45, 1, 0), 0.5], [Vector3(-0.8, 0.1, 0.6), Vector3(0.1, 0.3, 1), 0.42],
			[Vector3(0.8, -0.2, 0.5), Vector3(-0.2, 1, 0.3), 0.4], [Vector3(0, 0.9, 0.3), Vector3(1, 0, 0.2), 0.46],
			[Vector3(0, -0.9, 0.3), Vector3(1, 0.1, -0.2), 0.46], [Vector3(0.1, 0, -1), Vector3(0.6, 1, 0), 0.5], [Vector3(-0.7, 0.3, -0.6), Vector3(0, 1, -0.4), 0.4]]
		var lift = 0.161
		for s in strips:
			var c: Vector3 = (s[0] as Vector3).normalized()
			Kit.patch(b, c, s[1], 2.5, float(s[2]) + 0.03, lift, ink, 10, 1)
			lift += 0.0006
			Kit.patch(b, c, s[1], 2.46, float(s[2]), lift, paper, 10, 1)
			lift += 0.0006
		for tip in [[Vector3(0.1, 0.17, 0.02), 35.0], [Vector3(0.15, -0.09, 0.05), -60.0]]:   # yırtık kâğıt uçları
			b.add("prism", tip[0], Vector3(0.05, 0.1, 0.006), paper, Vector3(0, 0, -float(tip[1])))
		return b.build(Props.toon()))


static func _ribbon_mesh() -> Mesh:
	return Kit.cached_mesh("kemuri_serit", func():
		var pm = PlaneMesh.new()
		pm.size = Vector2(0.035, 1.0)
		pm.subdivide_depth = 12
		pm.center_offset = Vector3(0, 0, 0.64)
		return pm)


static func _puff_mesh() -> Mesh:
	return Kit.cached_mesh("kemuri_bulut", func():
		var items := []
		for i in 110:
			var a = randf() * TAU
			var rr = sqrt(randf())
			var y = randf()
			var wide = sqrt(maxf(0.0, 1.0 - y * y * 0.8))
			var p = Vector3(cos(a) * rr * wide * R * 0.86, y * H * 0.9 - 0.2, sin(a) * rr * wide * R * 0.86)
			items.append([p, Color(randf(), lerpf(1.0, 0.6, y) * randf_range(0.8, 1.0), 0.0, 1.0)])
		return Kit.card_mesh(items))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "smoke", 30.0, 3.0, _ball_mesh(), 1.0)
	var rm = Kit.shader_mat("kemuri_serit", RIBBON_SH)
	for i in 2:   # uçuşan kâğıt şeritleri (kendi rüzgârında çırpınır)
		var r = MeshInstance3D.new()
		r.mesh = _ribbon_mesh()
		r.material_override = rm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.extra_cull_margin = 1.0
		r.set_instance_shader_parameter("seed_k", float(i) * 2.4)
		r.rotation.z = float(i) * 1.1
		pr.add_child(r)
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		burst(who, pos)
	return pr


static func _day_light() -> float:
	var env = Game.world.get("env") if Game.world else null
	var tod = float(env.time_of_day) if env else 0.5
	return 0.42 + 0.58 * smoothstep(0.2, 0.3, tod) * (1.0 - smoothstep(0.72, 0.82, tod))


static func burst(who: Node3D, pos: Vector3) -> void:
	var fl = Game.jutsu_floor_at(pos).y
	var base = Vector3(pos.x, fl if pos.y - fl < 4.0 else pos.y - 1.5, pos.z)
	var s = {"t": 0.0, "life": LIFE, "acc": 0.0, "n": null, "mi": null}
	var oid = who.get_instance_id() if is_instance_valid(who) else 0
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		var n: Node3D = s["n"]
		s["acc"] += dt
		if s["acc"] >= 0.15:
			s["acc"] = 0.0
			if n.get_meta("wind", false) or _wind_near(n):
				s["life"] = minf(float(s["life"]), t + 0.8)
			_drop_locks()
		var life: float = s["life"]
		var g = (1.0 - exp(-t * 3.2)) + t * 0.012
		var fade_t = minf(FADE, maxf(0.6, life - (LIFE - FADE)))
		var e = clampf((t - (life - fade_t)) / fade_t, 0.0, 1.0)
		var mi: MeshInstance3D = s["mi"]
		mi.set_instance_shader_parameter("grow", g)
		mi.set_instance_shader_parameter("erode", e * e)
		n.set_meta("c", n.global_position + Vector3.UP * 1.6)
		n.set_meta("r", R * 0.92 * g * (1.0 - e * e))
		_veil_tick(dt)
		if t >= life:
			n.remove_from_group(GROUP)
			if n.get_tree().get_nodes_in_group(GROUP).is_empty():
				_veil_clear()
			return true
		return false
	var root = Kit.ticker(base, fn)
	s["n"] = root
	root.add_to_group(GROUP)
	root.set_meta("owner_id", oid)
	root.set_meta("c", base + Vector3.UP * 1.6)
	root.set_meta("r", 0.0)
	root.rotation.y = randf() * TAU
	var puffs = Kit.cards(root, _puff_mesh(), Kit.shader_mat("kemuri_duman", PUFF_SH), Vector3(11, 9, 11))
	puffs.set_instance_shader_parameter("light_k", _day_light())
	s["mi"] = puffs
	var star = Kit.quad(root, 3.6, Kit.shader_mat("kemuri_yildiz", STAR_SH))
	star.global_position = pos
	Kit.tween_param(star, "prog", 0.0, 1.0, 0.22, true)
	Sfx.play("poof", pos)
	# patlama anında yakalananlar bir an şaşırır (atan hariç)
	if is_instance_valid(who):
		for f in Kit.fighters():
			if f.has_method("lose_target") and Combat.hostile(who, f) and not f.is_dead() and f.global_position.distance_to(base) < R + 1.0 and not _pierces(f, 0.0):
				f.lose_target(2.0)


# ------------------------------------------------------------------ görüş
static func _clouds() -> Array:
	return Kit.tree().get_nodes_in_group(GROUP)


static func _seg_hits(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	if r <= 0.05:
		return false
	var ab = b - a
	var k = clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * k).distance_to(c) < r


## Bu bakan duman ardını görür mü (algılama menzili, göz, Inuzuka burnu)
static func _pierces(v: Node, d: float) -> bool:
	if Combat.sensing_r(v) > 0.0 and d <= Combat.sensing_r(v):
		return true
	if Kit.clan_of(v) == "inuzuka":
		return true
	if v is Player:
		var pc = v.get("combat")
		var ey = pc.modes.eyes if pc != null and pc.modes != null else null
		if ey != null and ey.active:
			for sd in ["sag", "sol"]:
				if ey._kind(sd) in PIERCE_EYES:
					return true
		return false
	return v.has_meta("eyes") and int(v.get_meta("eyes").get("kind", 0)) in PIERCE_EYES


## Kemuri Fuda: dumanı açanın yoldaşları görür
static func _ally_safe(c: Node, viewer: Node3D) -> bool:
	if not c.get_meta("ally_safe", false):
		return false
	var o = instance_from_id(int(c.get_meta("owner_id", 0)))
	return o != null and is_instance_valid(o) and not Combat.hostile(o, viewer)
## Combat.hidden_from ve Combat.nearest_enemy buraya sorar
static func veiled(viewer: Node3D, n: Node3D) -> bool:
	if viewer == null or n == null or not is_instance_valid(viewer) or not is_instance_valid(n):
		return false
	var a = Kit.eye(viewer)
	var b = Kit.chest(n)
	var d = a.distance_to(b)
	if d < SEE_NEAR or _pierces(viewer, d):
		return false
	var vid = viewer.get_instance_id()
	for c in _clouds():
		if int(c.get_meta("owner_id", 0)) != vid and not _ally_safe(c, viewer) and _seg_hits(a, b, c.get_meta("c"), float(c.get_meta("r", 0.0))):
			return true
	return false


## Işık gibi şeyler için çıplak hat denetimi (Hikaridama)
static func blocked(a: Vector3, b: Vector3) -> bool:
	for c in _clouds():
		if _seg_hits(a, b, c.get_meta("c"), float(c.get_meta("r", 0.0))):
			return true
	return false


## Rüzgâr dağıtır: Combat.hit_sphere fuuton alanları buraya haber verir
static func wind(at: Vector3, radius: float) -> void:
	for c in _clouds():
		if at.distance_to(c.get_meta("c")) < float(c.get_meta("r", 0.0)) + radius:
			c.set_meta("wind", true)


static func _wind_near(n: Node3D) -> bool:
	var c: Vector3 = n.get_meta("c")
	var r = float(n.get_meta("r", 0.0)) + 2.0
	for p in n.get_tree().get_nodes_in_group("projectiles"):
		if not p.dead and p.element() == "fuuton" and p.global_position.distance_to(c) < r + float(p.radius):
			return true
	return false


## Oyuncunun kilidi duman ardında kalan hedeften düşer (düşmanın hedef kaybıyla aynı kural)
static func _drop_locks() -> void:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.combat == null:
		return
	var lt = pl.combat.lock_target
	if lt != null and is_instance_valid(lt) and veiled(pl, lt):
		pl.combat.lock_target = null


# ------------------------------------------------------------------ kamera dumanın içindeyken
static func _veil_tick(dt: float) -> void:
	var fr = Engine.get_physics_frames()
	if fr == _veil_frame:
		return
	_veil_frame = fr
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.cam == null:
		return
	var cp: Vector3 = pl.cam.global_position
	var want = 0.0
	for c in _clouds():
		if cp.distance_to(c.get_meta("c")) < float(c.get_meta("r", 0.0)) * 0.8:
			want = 1.0
			break
	_veil_k = move_toward(_veil_k, want, dt * 3.5)
	var v = Kit.screen("kemuri", VEIL_SH)
	v.visible = _veil_k > 0.01
	v.material_override.set_shader_parameter("k", _veil_k)
	if v.visible and not _veil_guard_on:
		_veil_guard_on = true
		_veil_guard()


## Perde bekçisi: dumanın kendi sayacından bağımsız; 0.25 sn'de bir — kamera artık hiçbir canlı dumanın içinde değilse perdeyi
## söndürür (eskiden duman bulutu erken silinince / sayacı durunca perde ekranda sonsuza dek kalıyordu)
static func _veil_guard() -> void:
	var tr = Kit.tree()
	if tr == null:
		_veil_guard_on = false
		return
	var pl = Game.player
	var inside := false
	if pl != null and is_instance_valid(pl) and pl.cam != null:
		var cp: Vector3 = pl.cam.global_position
		for c in _clouds():
			if is_instance_valid(c) and c.is_inside_tree() and cp.distance_to(c.get_meta("c")) < float(c.get_meta("r", 0.0)) * 0.8:
				inside = true
				break
	if not inside:
		_veil_k = move_toward(_veil_k, 0.0, 0.25 * 3.5)
		var v = Kit.screen("kemuri", VEIL_SH)
		v.material_override.set_shader_parameter("k", _veil_k)
		if _veil_k <= 0.01:
			v.visible = false
			_veil_guard_on = false
			return
	tr.create_timer(0.25, false).timeout.connect(_veil_guard)


static func _veil_clear() -> void:
	_veil_k = 0.0
	Kit.screen("kemuri", VEIL_SH).visible = false
