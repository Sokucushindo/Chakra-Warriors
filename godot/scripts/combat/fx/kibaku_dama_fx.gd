extends RefCounted
## Kibaku-dama (patlayıcı top; kanonda romaji adı yok, ad 起爆札'tan; hedef: res://scripts/combat/fx/kibaku_dama_fx.gd).
## Kanon (Narutopedia "Explosive Tag Ball", Shippūden 91): top biçiminde sarılmış patlayıcı etiketler; gülle gibi kullanılır.
## Oyun kaynağı (Ultimate Ninja Storm, aynı sayfa): atılır, sekip yuvarlanır, rakibe değince ya da süre dolunca patlar.
## Görünüş refs/kibaku_dama: kırmızı kenarlı kâğıt etiketler, kara yazı.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const BALL_R := 0.17
const FUSE := 2.4
const BLAST_R := 4.2
const DMG := 40.0

const BLAST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float e = 1.0 - (1.0 - prog) * (1.0 - prog) * (1.0 - prog);
	vec3 c = VERTEX * e;
	c.y += prog * prog * (0.8 + sd * 1.4);
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float r = sd * 6.283 + prog * (sd - 0.5) * 3.0;
	vec2 k = (UV - 0.5) * (1.0 + COLOR.g * 2.8) * (0.45 + 0.75 * e);
	v.xy += vec2(k.x * cos(r) - k.y * sin(r), k.x * sin(r) + k.y * cos(r));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float lump = 0.11 * sin(a * 6.0 + sd * 40.0) + 0.06 * sin(a * 11.0 - sd * 25.0);
	float bite = 0.5 + 0.5 * sin(p.x * 7.0 + sd * 30.0) * sin(p.y * 8.0 - sd * 17.0);
	float edge = 0.84 + lump - prog * prog * (0.35 + 0.8 * bite);
	if (r > edge || -VERTEX.z < 0.5) discard;
	float heat = 1.15 - prog * 1.5 + (1.0 - r) * 0.45 + (sd - 0.5) * 0.2;
	vec3 col = heat > 0.95 ? vec3(1.0, 0.95, 0.68) : (heat > 0.6 ? vec3(1.0, 0.72, 0.2) : (heat > 0.25 ? vec3(0.93, 0.34, 0.08) : (heat > -0.02 ? vec3(0.36, 0.2, 0.16) : vec3(0.17, 0.15, 0.16))));
	ALBEDO = col;
}
"""

const FLARE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
float tri(float x) { return abs(fract(x) - 0.5) * 2.0; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x) / 6.283;
	float t = tri(a * 7.0);
	float e = (0.18 + 0.8 * t * t * t) * (0.5 + 0.5 * sin(prog * 3.14159));
	if (length(p) > e) discard;
	ALBEDO = vec3(1.0, 0.9, 0.6) * 2.0;
	ALPHA = 1.0 - prog;
}
"""

const SCRAP_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float age = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.g;
	vec3 d = VERTEX;
	float drag = (1.0 - exp(-age * 2.6)) / 2.6;
	vec3 c = d * drag * (6.0 + COLOR.r * 9.0);
	c.y += drag * 6.0 - age * age * 1.5;
	c.x += sin(age * 6.0 + sd * 30.0) * 0.25 * age;
	c.z += cos(age * 5.0 + sd * 50.0) * 0.25 * age;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float r = sd * 6.283 + age * (3.0 + sd * 5.0);
	vec2 k = (UV - 0.5) * vec2(0.17, 0.26) * (1.0 - smoothstep(1.1, 1.8, age));
	v.xy += vec2(k.x * cos(r) - k.y * sin(r), k.x * sin(r) + k.y * cos(r));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float burn = max(p.x, p.y) + 0.14 * sin(UV.x * 21.0 + sd * 40.0) * sin(UV.y * 17.0);
	float front = 1.15 - age * 0.55;
	if (burn > front) discard;
	ALBEDO = burn > front - 0.16 ? vec3(1.0, 0.5, 0.12) : (max(p.x, p.y) > 0.8 ? vec3(0.62, 0.16, 0.22) : vec3(0.88, 0.85, 0.76));
}
"""

const SCORCH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.72 + 0.1 * sin(a * 5.0 + 1.0) + 0.07 * sin(a * 11.0) + 0.05 * sin(a * 23.0 + 2.0);
	float r = length(p);
	if (r > e) discard;
	ALBEDO = r < e * 0.55 ? vec3(0.05, 0.045, 0.045) : vec3(0.11, 0.095, 0.085);
	ALPHA = fade_k * 0.82;
}
"""

const FUSE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
instance uniform float heat = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.35 + 0.55 * abs(sin(a * 3.0 + TIME * 31.0));
	if (length(p) > e) discard;
	float blink = 0.5 + 0.5 * sin(TIME * (14.0 + heat * 40.0));
	ALBEDO = mix(vec3(1.0, 0.6, 0.15), vec3(1.0, 0.12, 0.08), heat) * 1.8;
	ALPHA = 0.55 + 0.45 * blink;
}
"""


static func _ball_mesh() -> Mesh:
	return Kit.cached_mesh("kibaku_dama", func():
		var b = MB.new()
		var rng = RandomNumberGenerator.new()
		rng.seed = 4242
		var paper = Color(0.87, 0.85, 0.78)
		var red = Color(0.62, 0.16, 0.22)
		var ink = Color(0.08, 0.07, 0.07)
		b.add("sphere", Vector3.ZERO, Vector3.ONE * (BALL_R * 2.0), paper.darkened(0.12), Vector3.ZERO, 14)
		var lift = BALL_R + 0.001
		for i in 11:
			var y = 1.0 - (float(i) + 0.5) / 11.0 * 2.0   # etiketler küreye eşit dağılır
			var ring = sqrt(maxf(0.0, 1.0 - y * y))
			var ang = float(i) * 2.399
			var c = Vector3(cos(ang) * ring, y, sin(ang) * ring).normalized()
			var t = c.cross(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()).normalized()
			Kit.patch(b, c, t, 1.08, 0.68, lift, red, 4, 2)
			lift += 0.0004
			Kit.patch(b, c, t, 0.98, 0.58, lift, paper, 4, 2)
			lift += 0.0004
			var u = c.cross(t).normalized()
			for k in 7:   # kara mühür yazısı
				var x = rng.randf_range(-0.4, 0.4)
				var w = rng.randf_range(-0.2, 0.2)
				var dd = Vector2(rng.randf_range(-0.09, 0.09), rng.randf_range(-0.09, 0.09))
				Kit.stroke(b, c, u, Vector2(x, w) - dd, Vector2(x, w) + dd, 0.03, lift, ink)
			lift += 0.0004
		return b.build(Props.toon()))


static func _blast_mesh() -> Mesh:
	return Kit.cached_mesh("kibaku_alev", func():
		var items := []
		for i in 52:
			var d = Vector3(randf_range(-1, 1), randf_range(-0.15, 1), randf_range(-1, 1)).limit_length(1.0)
			items.append([d * BLAST_R * 0.82, Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))


static func _scrap_mesh() -> Mesh:
	return Kit.cached_mesh("kibaku_kagit", func():
		var items := []
		for i in 44:
			var d = Vector3(randf_range(-1, 1), randf_range(0.0, 1), randf_range(-1, 1)).normalized()
			items.append([d, Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "kibaku_dama", 24.0, 16.0, _ball_mesh(), 2.0, Vector3(8, 2, 3))
	var mult = Kit.tool_mult(who, true)
	pr.on_hit = func(pos: Vector3, tg: Node3D) -> void:
		var back: Vector3 = pos - pr.vel.normalized() * 0.25 + Vector3.UP * 0.1
		if tg != null:
			_roll(who, back, Vector3.ZERO, 0.1, mult)   # doğrudan isabet: hemen patlar
		else:
			var v: Vector3 = pr.vel * 0.34
			v.y = absf(pr.vel.y) * 0.42
			_roll(who, back, v, FUSE, mult)
	return pr


## Sekme + yuvarlanma: rakibe değince ya da fitil bitince patlar
static func _roll(who: Node3D, at: Vector3, v0: Vector3, fuse: float, mult: float) -> void:
	var s = {"t": 0.0, "v": v0, "fuse": fuse, "n": null, "mi": null, "spark": null}
	var fn = func(dt: float) -> bool:
		var n: Node3D = s["n"]
		s["t"] += dt
		var t: float = s["t"]
		var v: Vector3 = s["v"]
		v.y -= 22.0 * dt
		var from: Vector3 = n.global_position
		var to: Vector3 = from + v * dt
		var hv0 = Vector3(v.x, 0, v.z)   # yalnız yatay: zemini aşağıdaki yükseklik denetimi çözer, ışın yuvarlanmayı kesmesin
		if hv0.length() > 0.05:
			var q = PhysicsRayQueryParameters3D.create(from, from + hv0 * dt + hv0.normalized() * BALL_R, 1)
			var hit = n.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty() and (hit["normal"] as Vector3).y < 0.7:
				v = v.bounce(hit["normal"]) * 0.5
				to = from
		var fl = Game.jutsu_floor(to.x, to.z) + BALL_R
		if to.y <= fl:
			to.y = fl
			if v.y < -2.0:
				v.y = -v.y * 0.45
				Sfx.play("clink", to, 0.55, 0.35)
			else:
				v.y = 0.0
			var fr = exp(-2.4 * dt)
			v.x *= fr
			v.z *= fr
		n.global_position = to
		s["v"] = v
		var hv = Vector3(v.x, 0, v.z)
		if hv.length() > 0.05:
			(s["mi"] as Node3D).rotate(Vector3.UP.cross(hv).normalized(), hv.length() / BALL_R * dt)
		var left = float(s["fuse"]) - t
		(s["spark"] as GeometryInstance3D).set_instance_shader_parameter("heat", clampf(1.0 - left / 1.2, 0.0, 1.0))
		var touched = false
		if is_instance_valid(who):
			for f in Kit.fighters():
				if Combat.hostile(who, f) and not f.is_dead() and Combat.capsule_hit(to, f, BALL_R + 0.15):
					touched = true
					break
		if touched and left > 0.1:
			s["fuse"] = t + 0.1
			left = 0.1
		if left <= 0.0:
			_explode(who, to, mult)
			return true
		return false
	var root = Kit.ticker(at, fn)
	s["n"] = root
	var mi = MeshInstance3D.new()
	mi.mesh = _ball_mesh()
	root.add_child(mi)
	s["mi"] = mi
	var sp = Kit.quad(root, 0.34, Kit.shader_mat("kibaku_fitil", FUSE_SH))
	sp.position = Vector3(0, BALL_R + 0.06, 0)
	s["spark"] = sp
	Sfx.play("th_paper", at, 1.2, 0.5)


static func _explode(who: Node3D, at: Vector3, mult: float) -> void:
	if is_instance_valid(who):
		Combat.hit_sphere(who, at, BLAST_R, {"dmg": DMG * mult, "knock": 16.0, "launch": 7.0, "kind": "heavy", "hitstop": 0.08, "tool": "kibaku_dama"})
	Sfx.play("boom", at)
	var pl = Game.player
	if pl != null and is_instance_valid(pl) and Game.world and Game.world.get("env"):
		var d = pl.global_position.distance_to(at)
		if d < 40.0:
			Game.world.env.add_shake(clampf(1.0 - d / 40.0, 0.1, 0.9))
	var s = {"t": 0.0}
	var bl: Array = [null, null]
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		(bl[0] as GeometryInstance3D).set_instance_shader_parameter("prog", clampf(t / 0.95, 0.0, 1.0))
		(bl[1] as GeometryInstance3D).set_instance_shader_parameter("age", t)
		return t >= 2.0
	var root = Kit.ticker(at, fn)
	bl[0] = Kit.cards(root, _blast_mesh(), Kit.shader_mat("kibaku_alev", BLAST_SH), Vector3(9, 9, 9))
	bl[1] = Kit.cards(root, _scrap_mesh(), Kit.shader_mat("kibaku_kagit", SCRAP_SH), Vector3(14, 12, 14))
	var fl = Kit.quad(root, 7.5, Kit.shader_mat("kibaku_parlama", FLARE_SH))
	Kit.tween_param(fl, "prog", 0.0, 1.0, 0.18, true)
	var gy = Game.jutsu_floor(at.x, at.z)
	if at.y - gy < 2.5:
		var pm = PlaneMesh.new()
		pm.size = Vector2.ONE * BLAST_R * 2.1
		var sc = MeshInstance3D.new()
		sc.mesh = pm
		sc.material_override = Kit.shader_mat("kibaku_is", SCORCH_SH)
		sc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(sc)
		sc.global_position = Vector3(at.x, gy + 0.04, at.z)
		sc.rotation.y = randf() * TAU
		var tw = sc.create_tween()
		tw.tween_interval(6.0)
		tw.tween_method(func(v: float):
			if is_instance_valid(sc):
				sc.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, 2.0)
		tw.tween_callback(sc.queue_free)
