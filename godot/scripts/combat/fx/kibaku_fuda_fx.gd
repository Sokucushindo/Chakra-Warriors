extends RefCounted
## Kibaku Fuda (起爆札; hedef: res://scripts/combat/fx/kibaku_fuda_fx.gd). Kanon (Narutopedia "Explosive Tag", manga 46, 313, 332, 338, 445):
## 爆 mühürlü kâğıt. Süre dolunca, uzaktan ya da alevle patlar; yüzeye yapıştırılır veya silaha sarılır. Uzaktan patlatmada ninja
## genelde Sıçan (Ne) mührü yapar; sıralı patlatılarak tuzak kurulur. Yağmurda da çalışır. Ref refs/kibaku_fuda/Paperbomb.png.
## Oyunda: at -> değdiği yüzeye ya da kişiye yapışır. En çok 5 etiket. İKİ KEZ BAS = Sıçan mührü: etiketler konma sırasıyla patlar.
## Alev (ateş mermisi) ve yakındaki patlama etiketi tutuşturur. Süresi dolan kendiliğinden patlar. Kişiye yapışan, yer değiştirme
## (Kawarimi) ile geride kalır. Düşman aynı kodu kullanır: etiketin yanına rakip gelince mühür yapar. Etiketli kunai ("tag") ayrı kalır.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")

const MAX_TAGS := 5
const MAX_ON_BODY := 2
const FUSE := 30.0          # oyuncu: kendiliğinden patlama
const FUSE_AI := 9.0
const BURN := 0.42          # tutuşma: kâğıt uçtan yanar
const STEP := 0.16          # sıralı patlama aralığı
const TAP := 0.4            # çift basma penceresi
const BLAST_R := 3.0
const CHAIN_R := 4.5
const DMG := 24.0
const AI_TRIG := 2.8

const TAG_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
instance uniform float burn = 0.0;
varying vec3 lp;
varying vec3 vc;
void vertex() {
	lp = VERTEX;
	vc = COLOR.rgb;
}
void fragment() {
	float n = 0.012 * sin(lp.x * 170.0) + 0.009 * sin(lp.x * 310.0 + 1.3);
	float front = mix(-0.16, 0.16, burn) + n;
	if (burn > 0.001 && lp.y < front) discard;
	float e = burn > 0.001 ? 1.0 - smoothstep(0.0, 0.028, lp.y - front) : 0.0;
	ALBEDO = mix(vc, e > 0.55 ? vec3(1.0, 0.72, 0.18) : vec3(0.1, 0.06, 0.05), e);
}
"""

const LOBE_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float e = 1.0 - pow(1.0 - prog, 3.0);
	vec3 c = VERTEX * (0.2 + 0.8 * e);
	c.y += prog * prog * 0.55;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * (0.5 + COLOR.g * 1.5) * (0.5 + 0.6 * e);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float e = 0.82 + 0.1 * sin(a * 5.0 + sd * 31.0) - prog * prog * (0.5 + 0.45 * sin(p.x * 6.0 + sd * 19.0) * sin(p.y * 6.0));
	if (r > e || -VERTEX.z < 0.4) discard;
	float h = 1.0 - prog * 1.35 + (0.35 - r * 0.35) + (p.y * 0.18);
	ALBEDO = h > 0.72 ? vec3(0.98, 0.95, 0.84) : (h > 0.36 ? vec3(0.96, 0.77, 0.36) : (h > 0.05 ? vec3(0.9, 0.42, 0.13) : vec3(0.2, 0.17, 0.16)));
}
"""

const BIT_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float age = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.g;
	float drag = (1.0 - exp(-age * 2.8)) / 2.8;
	vec3 c = VERTEX * drag * (5.0 + COLOR.r * 7.0);
	c.y += drag * 3.0 - age * age * 1.1;
	c.x += sin(age * 7.0 + sd * 30.0) * 0.2 * age;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	float r = sd * 6.283 + age * (4.0 + sd * 5.0);
	vec2 k = (UV - 0.5) * vec2(0.09, 0.16);
	v.xy += vec2(k.x * cos(r) - k.y * sin(r), k.x * sin(r) + k.y * cos(r));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float b = max(p.x, p.y) + 0.16 * sin(UV.x * 19.0 + sd * 30.0) * sin(UV.y * 15.0);
	float front = 1.1 - age * 0.95;
	if (b > front) discard;
	ALBEDO = b > front - 0.17 ? vec3(1.0, 0.5, 0.12) : (max(p.x, p.y) > 0.76 ? vec3(0.76, 0.27, 0.32) : vec3(0.91, 0.88, 0.76));
}
"""

const MARK_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.68 + 0.13 * sin(a * 7.0 + 0.8) + 0.08 * sin(a * 17.0);
	if (length(p) > e) discard;
	ALBEDO = vec3(0.07, 0.06, 0.06);
	ALPHA = fade_k * 0.78;
}
"""

static var _tags: Array = []


## Etiket: +Y uzun eksen, +Z yüz (ref: kızıl çerçeve, krem kâğıt, ortada 爆, iki yanda fırça yazısı)
static func _tag_mesh() -> Mesh:
	return Kit.cached_mesh("fuda_kagit", func():
		var b = MB.new()
		var rng = RandomNumberGenerator.new()
		rng.seed = 338
		var ink = Color(0.05, 0.05, 0.05)
		b.add("box", Vector3.ZERO, Vector3(0.13, 0.3, 0.0016), Color(0.76, 0.27, 0.32))
		b.add("box", Vector3(0, 0, 0.0012), Vector3(0.108, 0.272, 0.0008), Color(0.91, 0.88, 0.76))
		b.add("box", Vector3(0, 0, -0.0012), Vector3(0.108, 0.272, 0.0008), Color(0.86, 0.83, 0.72))
		var z = 0.0019
		var st = [[-0.03, 0.03, -0.03, -0.03], [-0.04, 0.008, -0.02, -0.004], [-0.014, 0.03, 0.036, 0.03], [-0.006, 0.036, -0.006, 0.016], [0.028, 0.036, 0.028, 0.016],
			[-0.006, 0.024, 0.028, 0.024], [-0.014, 0.012, 0.04, 0.012], [-0.016, -0.002, 0.042, -0.002], [0.012, -0.002, 0.012, -0.032], [-0.008, -0.01, 0.0, -0.022], [0.034, -0.01, 0.024, -0.024], [-0.012, -0.034, 0.004, -0.022], [0.038, -0.034, 0.02, -0.022]]
		for s in st:
			_stroke(b, Vector2(s[0], s[1]), Vector2(s[2], s[3]), 0.005, z, ink)
		for sy in [-1.0, 1.0]:   # üstte altta kıvrık fırça yazısı
			for col in [-0.032, 0.0, 0.032]:
				var p = Vector2(col, sy * 0.062)
				for k in 5:
					var q = p + Vector2(rng.randf_range(-0.012, 0.012), sy * rng.randf_range(0.008, 0.016))
					_stroke(b, p, q, rng.randf_range(0.0026, 0.0048), z, ink)
					p = q
		return b.build(Kit.shader_mat("fuda_kagit", TAG_SH)))


static func _stroke(b: MB, a: Vector2, c: Vector2, w: float, z: float, col: Color) -> void:
	var d = c - a
	if d.length() < 0.0005:
		return
	var rot = atan2(d.y, d.x)
	var m = (a + c) * 0.5
	b.add_xf("box", Transform3D(Basis(Vector3.BACK, rot) * Basis.from_scale(Vector3(d.length() + w * 0.5, w, 0.0005)), Vector3(m.x, m.y, z)), col)


static func _of(who: Node3D) -> Array:
	_tags = _tags.filter(func(s): return is_instance_valid(s["n"]))
	return _tags.filter(func(s): return s["who"] == who)


# ------------------------------------------------------------------ fırlatma / yapışma
static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "kibaku_fuda", 30.0, 5.0, _tag_mesh(), 1.0, Vector3(5, 1, 7))
	pr.life = 1.6
	var mult = Kit.tool_mult(who, true)
	pr.on_hit = func(pos: Vector3, tg: Node3D) -> void:
		if pr.life > 0.0 or tg != null:   # süresi dolan havada söner
			_stick(who, pos, tg, pr.vel, mult)
	return pr


static func _stick(who: Node3D, pos: Vector3, tg: Node3D, vel: Vector3, mult: float) -> void:
	var vn: Vector3 = vel.normalized() if vel.length() > 0.1 else Vector3.DOWN
	var n = Vector3.UP
	var at = pos
	var body: Node3D = null
	if tg != null and is_instance_valid(tg) and not tg.is_dead():
		var on = 0
		for e in _of(who):
			if e["body"] == tg:
				on += 1
		if on < MAX_ON_BODY:
			body = tg
	if body != null:
		n = -vn
		n.y = 0.0
		n = n.normalized() if n.length() > 0.05 else Vector3.BACK
		at = Kit.chest(body) + n * 0.22
	else:
		var q = PhysicsRayQueryParameters3D.create(pos - vn * 0.5, pos + vn * 0.5, 1)
		var hit = Kit.scene().get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			n = hit["normal"]
			at = hit["position"]
		else:
			at.y = Game.jutsu_floor(at.x, at.z) if tg != null else maxf(at.y, Game.jutsu_floor(at.x, at.z))   # kişiye yer kalmadıysa ayağının dibine düşer
		at += n * 0.012
	if is_instance_valid(who):
		var mine = _of(who)
		if mine.size() >= MAX_TAGS:
			mine[0]["lit_in"] = 0.0   # en eski etiket yer açar
	var s = {"who": who, "body": body, "off": at - body.global_position if body != null else Vector3.ZERO, "t": 0.0, "lit_in": -1.0, "burn": -1.0, "scan": randf() * 0.15,
		"fuse": FUSE if who is Player else FUSE_AI, "mult": mult, "n": null, "mi": null, "ai": is_instance_valid(who) and not (who is Player), "normal": n, "last": at}
	if is_instance_valid(who) and Game.now() - float(who.get_meta("kf_det", -9.0)) < 1.0:
		s["lit_in"] = 0.05   # mühür etiket uçarken yapıldı
	var fn = func(dt: float) -> bool: return _tick(s, dt)
	var root = Kit.ticker(at, fn)
	root.global_transform = Transform3D(Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD), at)
	var mi = MeshInstance3D.new()
	mi.mesh = _tag_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	s["n"] = root
	s["mi"] = mi
	_tags.append(s)
	Sfx.play("th_paper", at, 1.35, 0.35)


static func _tick(s: Dictionary, dt: float) -> bool:
	var n: Node3D = s["n"]
	s["t"] = float(s["t"]) + dt
	var body = s["body"]
	if body != null:
		if not is_instance_valid(body):
			s["body"] = null
		else:
			var p: Vector3 = body.global_position + s["off"]
			if p.distance_to(s["last"]) > 4.0:   # Kawarimi / ışınlanma: etiket geride kalır
				s["body"] = null
				n.global_position = Vector3(s["last"].x, Game.jutsu_floor(s["last"].x, s["last"].z) + 0.02, s["last"].z)
				n.global_transform.basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
				s["normal"] = Vector3.UP
			else:
				n.global_position = p
				s["last"] = p
	if float(s["burn"]) >= 0.0:
		s["burn"] = float(s["burn"]) + dt / BURN
		(s["mi"] as GeometryInstance3D).set_instance_shader_parameter("burn", clampf(float(s["burn"]), 0.0, 1.0))
		if float(s["burn"]) >= 1.0:
			_explode(s)
			return true
		return false
	if float(s["lit_in"]) >= 0.0:
		s["lit_in"] = float(s["lit_in"]) - dt
		if float(s["lit_in"]) < 0.0:
			_ignite(s)
		return false
	if float(s["t"]) >= float(s["fuse"]):
		_ignite(s)
		return false
	s["scan"] = float(s["scan"]) - dt
	if float(s["scan"]) <= 0.0:
		s["scan"] = 0.15
		var at: Vector3 = n.global_position
		for pr in Kit.tree().get_nodes_in_group("projectiles"):   # kanon: alev tutuşturur
			if is_instance_valid(pr) and str(pr.info.get("element", "")) in ["katon", "yoton", "shakuton"] and pr.global_position.distance_to(at) < float(pr.radius) + 1.4:
				_ignite(s)
				return false
		var who = s["who"]
		if bool(s["ai"]) and is_instance_valid(who) and float(s["t"]) > 0.45:   # düşman tuzağını kendisi tetikler
			var go = s["body"] != null and float(s["t"]) > 1.5
			if not go:
				for f in Kit.fighters():
					if Combat.hostile(who, f) and not f.is_dead() and f.global_position.distance_to(at) < AI_TRIG:
						go = true
						break
			if go:
				_rat(who)
				_ignite(s)
	return false


static func _ignite(s: Dictionary) -> void:
	if float(s["burn"]) < 0.0:
		s["burn"] = 0.0
		s["lit_in"] = -1.0
		Sfx.play("fire", (s["n"] as Node3D).global_position, 1.8, 0.28)


## Sıçan mührü: el pozu (oyuncu ve düşman)
static func _rat(who: Node3D) -> void:
	var m = who.get("model")
	if m == null or m.overlay == null or float(who.get_meta("kf_rat", -9.0)) > Game.now():
		return
	who.set_meta("kf_rat", Game.now() + 0.5)
	m.overlay.set_pose("seal", 1.0)
	Sfx.play("seal", who.global_position, 1.25, 0.6)
	who.get_tree().create_timer(0.42).timeout.connect(func():
		if is_instance_valid(m) and m.overlay != null:
			m.overlay.set_pose("seal", 0.0))


## Etiketler konma sırasıyla patlar (kanon: sıralı tuzak)
static func detonate(who: Node3D) -> void:
	who.set_meta("kf_det", Game.now())
	_rat(who)
	var k = 0
	for s in _of(who):
		if float(s["burn"]) < 0.0:
			s["lit_in"] = k * STEP
			k += 1


## Oyuncunun alet tuşu: tek basış yapıştırır, çift basış (ya da 5 etiket doluyken) mühür
static func player_use(p: Node3D) -> void:
	var c = p.combat
	var now = Game.now()
	var mine = _of(p)
	var dbl = now - float(p.get_meta("kf_tap", -9.0)) < TAP
	p.set_meta("kf_tap", now)
	if not mine.is_empty() and (dbl or mine.size() >= MAX_TAGS):
		detonate(p)
		c.tool_cd["kibaku_fuda"] = PlayerCombat.TOOL_CD / (1.0 + Mastery.get_v(Game.profile, "shurikenjutsu") / 50.0)
		return
	if dbl and mine.is_empty() and now - float(p.get_meta("kf_atis", -9.0)) < 1.6:   # etiket henüz havada: değince patlar
		detonate(p)
		c.tool_cd["kibaku_fuda"] = PlayerCombat.TOOL_CD / (1.0 + Mastery.get_v(Game.profile, "shurikenjutsu") / 50.0)
		return
	if c.action != "" and c.action != "guard":
		return
	var nm = str(Data.items.get("kibaku_fuda", {"name": "Kibaku Fuda"})["name"])
	if not c.tool_owned("kibaku_fuda"):
		Hud.msg("%s sende yok — pazardan bir kez al, sonra sınırsız." % nm, Color(1, 0.6, 0.5))
		return
	if float(c.tool_cd.get("kibaku_fuda", 0.0)) > 0.0:
		Hud.msg("%s hazır değil: %d sn" % [nm, ceili(float(c.tool_cd["kibaku_fuda"]))], Color(1, 0.75, 0.5))
		return
	c.action = "throw"
	c.t = 0.0
	var tgt = c._auto_target(40.0)
	var aim: Vector3
	var start: Vector3 = p.global_position + Vector3.UP * 1.4 + p.face_dir() * 0.4
	if tgt:
		c.face_to(tgt)
		aim = (tgt.global_position + Vector3.UP * tgt.height * 0.55 - start).normalized()
	else:
		aim = -p.cam.global_transform.basis.z
		p.facing = atan2(-aim.x, -aim.z)
	p.model.play("throw", 0.05, 1.8, true)
	Sfx.play("th_paper", start, 1.5, 0.5)
	Mastery.gain(Game.profile, "shurikenjutsu", 0.2)
	p.set_meta("kf_atis", now)
	launch(p, start, aim, tgt)
	if mine.is_empty():
		Hud.msg("Patlatmak için aleti iki kez at (Sıçan mührü)", Color(0.95, 0.85, 0.65), 2.5)


# ------------------------------------------------------------------ patlama
static func _explode(s: Dictionary) -> void:
	var n: Node3D = s["n"]
	var at: Vector3 = n.global_position
	var nr: Vector3 = s["normal"]
	var who = s["who"]
	_tags.erase(s)
	if is_instance_valid(who):
		var c: Vector3 = at + nr * 0.3
		if s["body"] != null and is_instance_valid(s["body"]):
			c = Kit.chest(s["body"])
		Combat.hit_sphere(who, c, BLAST_R, {"dmg": DMG * float(s["mult"]), "knock": 12.0, "launch": 4.0, "kind": "heavy", "hitstop": 0.05, "tool": "kibaku_fuda"})
	for o in _tags:   # yakındaki etiketler tutuşur (kimin olursa olsun)
		if is_instance_valid(o["n"]) and float(o["burn"]) < 0.0 and float(o["lit_in"]) < 0.0 and (o["n"] as Node3D).global_position.distance_to(at) < CHAIN_R:
			o["lit_in"] = 0.08
	Sfx.play("boom", at, 1.15, 0.8)
	var pl = Game.player
	if pl != null and is_instance_valid(pl) and Game.world and Game.world.get("env"):
		var d = pl.global_position.distance_to(at)
		if d < 30.0:
			Game.world.env.add_shake(clampf(0.6 - d / 50.0, 0.05, 0.6))
	var st = {"t": 0.0}
	var parts: Array = [null, null]
	var fn = func(dt: float) -> bool:
		st["t"] += dt
		var t: float = st["t"]
		(parts[0] as GeometryInstance3D).set_instance_shader_parameter("prog", clampf(t / 0.62, 0.0, 1.0))
		(parts[1] as GeometryInstance3D).set_instance_shader_parameter("age", t)
		return t >= 1.2
	var root = Kit.ticker(at, fn)
	var ref = Vector3.FORWARD if absf(nr.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var xx = ref.cross(nr).normalized()
	root.global_transform = Transform3D(Basis(xx, nr, xx.cross(nr)), at)   # patlama yüzeyden dışarı açılır
	var lm = Kit.cached_mesh("fuda_alev", func():
		var items := []
		for i in 30:
			var d = Vector3(randf_range(-0.8, 0.8), randf_range(0.05, 1.0), randf_range(-0.8, 0.8)).limit_length(1.0)
			items.append([d * BLAST_R * 0.72, Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))
	var bm = Kit.cached_mesh("fuda_parca", func():
		var items := []
		for i in 22:
			items.append([Vector3(randf_range(-1, 1), randf_range(0.0, 1), randf_range(-1, 1)).normalized(), Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))
	parts[0] = Kit.cards(root, lm, Kit.shader_mat("fuda_alev", LOBE_SH), Vector3(7, 7, 7))
	parts[1] = Kit.cards(root, bm, Kit.shader_mat("fuda_parca", BIT_SH), Vector3(9, 9, 9))
	if s["body"] == null:   # değdiği yüzeyde is izi
		var pm = PlaneMesh.new()
		pm.size = Vector2.ONE * BLAST_R * 1.5
		var sc = MeshInstance3D.new()
		sc.mesh = pm
		sc.material_override = Kit.shader_mat("fuda_is", MARK_SH)
		sc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.scene().add_child(sc)
		sc.global_transform = Transform3D(Basis(xx, nr, xx.cross(nr)).rotated(nr, randf() * TAU), at + nr * 0.03)
		var tw = sc.create_tween()
		tw.tween_interval(5.0)
		tw.tween_method(func(v: float):
			if is_instance_valid(sc):
				sc.set_instance_shader_parameter("fade_k", v), 1.0, 0.0, 1.6)
		tw.tween_callback(sc.queue_free)
