extends RefCounted
## Bakusaidama (爆砕玉; hedef: res://scripts/combat/fx/bakusaidama_fx.gd). Kanon (Narutopedia "Exploding Sphere", manga 256, Tenten):
## kunai kaynaklanmış metal küre, üstünde gizli patlayıcı etiket. Çarpınca patlar; kunailer ve küre parçaları şarapnel olur.
## Kibaku-dama'dan farkı: yuvarlanmaz, fitil yok, patlaması küçük; asıl zarar saçılan gerçek kunailerden gelir (yakın olan çok yer,
## arkasına saklanan kurtulur, kunailer çevreye saplanır). Ref refs/bakusaidama/Kunai_Grenade.png.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")

const BALL_R := 0.17
const BLAST_R := 2.6
const BLAST_DMG := 18.0
const KUNAI_N := 14
const KUNAI_DMG := 5.0
const KUNAI_SPEED := 38.0
const KUNAI_LIFE := 0.36

const IRON := Color(0.27, 0.27, 0.29)
const BLADE := Color(0.42, 0.43, 0.46)
const PAPER := Color(0.91, 0.89, 0.78)
const INK := Color(0.05, 0.05, 0.05)

const FLAME_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float e = 1.0 - (1.0 - prog) * (1.0 - prog);
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX * e, 1.0);
	vec3 d = (MODELVIEW_MATRIX * vec4(VERTEX, 0.0)).xyz;
	vec2 dir = length(d.xy) > 0.001 ? normalize(d.xy) : vec2(0.0, 1.0);
	vec2 per = vec2(-dir.y, dir.x);
	vec2 k = UV - 0.5;
	float L = (0.9 + COLOR.g * 1.5) * (1.0 - prog * 0.55);
	v.xy += dir * k.y * L + per * k.x * (0.3 + COLOR.g * 0.28);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;
	float w = sin(3.14159 * pow(y, 0.55)) * (1.0 - prog * 0.75);
	if (abs(x) > w || -VERTEX.z < 0.4) discard;
	float heat = 1.25 - prog * 1.9 + (1.0 - y) * 0.3 - abs(x) * 0.2 + (sd - 0.5) * 0.15;
	ALBEDO = heat > 0.95 ? vec3(1.0, 0.96, 0.78) : (heat > 0.55 ? vec3(1.0, 0.66, 0.16) : (heat > 0.15 ? vec3(0.82, 0.25, 0.07) : vec3(0.16, 0.14, 0.14)));
}
"""

const SHARD_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float age = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float drag = (1.0 - exp(-age * 3.2)) / 3.2;
	vec3 c = VERTEX * drag * (9.0 + COLOR.g * 11.0);
	c.y -= age * age * 5.0;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float r = sd * 6.283 + age * (9.0 + sd * 14.0);
	vec2 k = (UV - 0.5) * (0.07 + COLOR.g * 0.11) * (1.0 - smoothstep(0.6, 0.85, age));
	v.xy += vec2(k.x * cos(r) - k.y * sin(r), k.x * sin(r) + k.y * cos(r));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float e = abs(p.x) * (1.2 + sd) + p.y * 0.9;
	if (e > 0.72 || p.y < -0.8) discard;
	float hot = 1.0 - smoothstep(0.12, 0.34, age);
	vec3 steel = sd > 0.5 ? vec3(0.34, 0.34, 0.37) : vec3(0.19, 0.19, 0.21);
	ALBEDO = e > 0.5 ? mix(steel, vec3(1.0, 0.56, 0.14), hot) : mix(steel, vec3(1.0, 0.82, 0.4), hot * 0.7);
}
"""

const FLASH_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
instance uniform float prog = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float t = pow(abs(cos(a * 3.0 + 0.4)), 22.0) + 0.6 * pow(abs(cos(a * 4.0 - 0.7)), 34.0);
	float e = (0.12 + 0.86 * t) * sin(3.14159 * min(1.0, prog * 1.3 + 0.12));
	if (length(p) > e) discard;
	ALBEDO = vec3(1.0, 0.93, 0.74) * 2.2;
	ALPHA = 1.0 - prog * prog;
}
"""


## Kaynaklı kunai: dip yırtık, yaprak ağız; +Z uç
static func _blade_outline(L: float, w: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w * 0.45, 0.0), Vector2(w * 0.1, 0.012), Vector2(w * 0.45, 0.0), Vector2(w, L * 0.34), Vector2(0.0, L), Vector2(-w, L * 0.34)])


static func _ball_mesh() -> Mesh:
	return Kit.cached_mesh("bakusai_top", func():
		var b = MB.new()
		var rng = RandomNumberGenerator.new()
		rng.seed = 2560
		b.add("sphere", Vector3.ZERO, Vector3.ONE * (BALL_R * 2.0), IRON, Vector3.ZERO, 14)
		# dövme izleri (ref)
		for k in 22:
			var c = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var t = c.cross(Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)).normalized()).normalized()
			Kit.patch(b, c, t, rng.randf_range(0.2, 0.42), 0.022, BALL_R + 0.0008, IRON.darkened(0.42), 2, 1)
		# kaynaklı kunailer: etiketin (+Z) çevresi boş kalır
		for i in KUNAI_N:
			var y = 1.0 - (float(i) + 0.5) / KUNAI_N * 2.0
			var ring = sqrt(maxf(0.0, 1.0 - y * y))
			var a = float(i) * 2.399
			var d = Vector3(cos(a) * ring, y, sin(a) * ring).normalized()
			if d.z > 0.72:
				d = (d + Vector3(0, 0, -1.0)).normalized()
			var bs = Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
			b.add_slab(_blade_outline(0.15, 0.036), 0.014, BLADE, Transform3D(bs, d * (BALL_R - 0.012)))
		# etiket: kara çerçeve, krem kâğıt, halka içinde 爆 (çizgilerle yaklaşık), üstte altta yazı
		var f = Vector3(0, 0, 1)
		var u = Vector3(0.22, 1, 0).normalized()
		u = (u - f * u.dot(f)).normalized()
		var r = BALL_R + 0.002
		Kit.patch(b, f, u, 1.46, 0.98, r, INK, 6, 4)
		Kit.patch(b, f, u, 1.34, 0.86, r + 0.0006, PAPER, 6, 4)
		var r2 = r + 0.0012
		for k in 20:
			var a0 = TAU * k / 20.0
			var a1 = TAU * (k + 1) / 20.0
			Kit.stroke(b, f, u, Vector2(cos(a0), sin(a0)) * 0.3, Vector2(cos(a1), sin(a1)) * 0.3, 0.032, r2, INK)
		var strokes = [[-0.2, 0.17, -0.2, -0.17], [-0.26, 0.05, -0.14, -0.03], [-0.13, 0.15, 0.2, 0.15], [-0.08, 0.2, -0.08, 0.05], [0.14, 0.2, 0.14, 0.05],
			[-0.08, 0.1, 0.14, 0.1], [-0.11, 0.04, 0.2, 0.04], [-0.04, 0.04, -0.09, -0.04], [0.09, 0.04, 0.15, -0.04], [-0.13, -0.05, 0.21, -0.05],
			[0.04, -0.05, 0.04, -0.2], [-0.08, -0.1, -0.02, -0.16], [0.15, -0.1, 0.09, -0.17], [-0.1, -0.2, 0.0, -0.13], [0.18, -0.2, 0.08, -0.13]]
		for s in strokes:
			Kit.stroke(b, f, u, Vector2(s[0], s[1]), Vector2(s[2], s[3]), 0.03, r2, INK)
		for sy in [-1.0, 1.0]:
			for k in 6:
				var x = -0.26 + k * 0.105
				var q = Vector2(x, sy * rng.randf_range(0.46, 0.56))
				var dd = Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.05, 0.05))
				Kit.stroke(b, f, u, q - dd, q + dd, 0.024, r2, INK)
		return b.build(Props.toon()))


static func _kunai_mesh() -> Mesh:
	return Kit.cached_mesh("bakusai_kunai", func():
		var b = MB.new()
		b.add_slab(_blade_outline(0.2, 0.04), 0.012, BLADE)
		b.add("box", Vector3(0, 0, -0.008), Vector3(0.008, 0.03, 0.022), IRON)
		return b.build(Props.toon()))


static func _sphere_cards(n: int, r: float, yr := -0.3) -> ArrayMesh:
	var items := []
	for i in n:
		var d = Vector3(randf_range(-1, 1), randf_range(yr, 1), randf_range(-1, 1)).normalized()
		items.append([d * r, Color(randf(), randf(), 0.0, 1.0)])
	return Kit.card_mesh(items)


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "bakusaidama", 25.0, 13.0, _ball_mesh(), 4.0, Vector3(7, 3, 2))
	pr.radius = BALL_R + 0.05
	var mult = Kit.tool_mult(who, true)
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		var v: Vector3 = pr.vel.normalized() if pr.vel.length() > 0.1 else Vector3.DOWN
		_burst(who, pos - v * 0.22 + Vector3.UP * 0.12, mult)
	return pr


static func _burst(who: Node3D, at: Vector3, mult: float) -> void:
	var live = is_instance_valid(who)
	if live:
		Combat.hit_sphere(who, at, BLAST_R, {"dmg": BLAST_DMG * mult, "knock": 9.0, "launch": 2.0, "kind": "heavy", "hitstop": 0.05, "tool": "bakusaidama"})
		var km = _kunai_mesh()
		for i in KUNAI_N:   # küreden kopan kunailer: her biri gerçek mermi, yere ve duvara saplanır
			var y = lerpf(0.85, -0.12, (float(i) + 0.5) / KUNAI_N)
			var ring = sqrt(maxf(0.0, 1.0 - y * y))
			var a = float(i) * 2.399 + randf() * 0.25
			var d = Vector3(cos(a) * ring, y, sin(a) * ring).normalized()
			var vis = Node3D.new()
			var mi = MeshInstance3D.new()
			mi.mesh = km
			mi.rotation.y = PI
			mi.position = Vector3(0, 0, 0.1)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vis.add_child(mi)
			var hit = func(pos: Vector3, tgt: Node3D) -> void:
				if tgt != null and is_instance_valid(tgt):
					Sfx.play("hit_blade", pos, randf_range(1.15, 1.35), 0.4)
					var pm = MeshInstance3D.new()
					pm.mesh = km
					U.pin(pm, tgt, pos - d * 0.12, d, 2.5)
			U.fire(who, at + d * (BALL_R + 0.08), d * KUNAI_SPEED, {"g": 6.0, "r": 0.11, "life": KUNAI_LIFE, "stick": true, "vis": vis, "hit": hit,
				"info": {"dmg": KUNAI_DMG * mult, "knock": 1.5, "kind": "light", "hitstop": 0.0, "tool": "bakusaidama"}})
	Sfx.play("boom", at, 1.3, 0.85)
	Sfx.play("clash", at, 0.7, 0.55)
	var pl = Game.player
	if pl != null and is_instance_valid(pl) and Game.world and Game.world.get("env"):
		var dist = pl.global_position.distance_to(at)
		if dist < 26.0:
			Game.world.env.add_shake(clampf(0.55 - dist / 50.0, 0.05, 0.55))
	var s = {"t": 0.0}
	var parts: Array = [null, null]
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		(parts[0] as GeometryInstance3D).set_instance_shader_parameter("prog", clampf(t / 0.42, 0.0, 1.0))
		(parts[1] as GeometryInstance3D).set_instance_shader_parameter("age", t)
		return t >= 0.9
	var root = Kit.ticker(at, fn)
	var fm = Kit.cached_mesh("bakusai_alev", func(): return _sphere_cards(26, BLAST_R * 0.55))
	var sm = Kit.cached_mesh("bakusai_parca", func(): return _sphere_cards(46, 1.0))
	parts[0] = Kit.cards(root, fm, Kit.shader_mat("bakusai_alev", FLAME_SH), Vector3(6, 6, 6))
	parts[1] = Kit.cards(root, sm, Kit.shader_mat("bakusai_parca", SHARD_SH), Vector3(10, 8, 10))
	var fl = Kit.quad(root, 6.5, Kit.shader_mat("bakusai_flas", FLASH_SH))
	Kit.tween_param(fl, "prog", 0.0, 1.0, 0.14, true)
