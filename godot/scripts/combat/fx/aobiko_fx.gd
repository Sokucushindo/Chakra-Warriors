extends RefCounted
## Aobiko (青火粉; hedef: res://scripts/combat/fx/aobiko_fx.gd). Kanon (Narutopedia "Blue Fire Powder", roman Jinraiden): su değince büyük patlayan toz. Silindire doldurulur: üfleyince nefesin nemi
## tutuşturur, küçük silindir taş atar. Hafif nemlendirilip mayın yapılır. Görsel kaynağı YOK (yalnız roman): mavi toz yorumu bizim.
## Oyunda: kese atılır, yere mavi toz yayılır. Su, yağmur, Suiton mermisi ya da ıslak düşman patlatır. Fukiya kuşanılıyken alet tuşu tozlu taş üfler.

const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const T = preload("res://scripts/combat/fx/tuketim.gd")

const LIFE := 16.0
const R := 4.4
const DMG := 40.0
const CD := 30.0
const BLUE := Color(0.3, 0.52, 0.95)

const BLAST_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float prog = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	float e = 1.0 - pow(1.0 - prog, 3.0);
	vec3 c = VERTEX * e;
	c.y += prog * prog * 1.2;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * (0.7 + COLOR.g * 2.0) * (0.45 + 0.7 * e);
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float e = 0.8 + 0.12 * sin(a * 7.0 + sd * 30.0) - prog * prog * 0.75;
	float r = length(p);
	if (r > e || -VERTEX.z < 0.4) discard;
	float h = 1.1 - prog * 1.5 + (1.0 - r) * 0.4;
	ALBEDO = h > 0.85 ? vec3(0.92, 0.98, 1.0) : (h > 0.45 ? vec3(0.42, 0.72, 1.0) : (h > 0.1 ? vec3(0.13, 0.3, 0.86) : vec3(0.1, 0.11, 0.2)));
}
"""


static func _pouch() -> Mesh:
	return Kit.cached_mesh("aobiko_kese", func():
		var b = MB.new()
		b.add("sphere", Vector3.ZERO, Vector3(0.14, 0.12, 0.14), Color(0.3, 0.26, 0.24), Vector3.ZERO, 8)
		b.add("cyl", Vector3(0, 0.07, 0), Vector3(0.05, 0.03, 0.05), BLUE, Vector3.ZERO, 6)
		return b.build(Props.toon()))


static func _powder() -> Mesh:
	return Kit.cached_mesh("aobiko_toz", func():
		var b = MB.new()
		var rng = RandomNumberGenerator.new()
		rng.seed = 77
		for k in 90:
			var a = rng.randf() * TAU
			var r = sqrt(rng.randf()) * 1.5
			b.add("box", Vector3(cos(a) * r, 0.012, sin(a) * r), Vector3(rng.randf_range(0.02, 0.05), 0.012, rng.randf_range(0.02, 0.05)), BLUE.lightened(rng.randf() * 0.4), Vector3(0, rng.randf() * 180.0, 0))
		return b.build(Props.toon_color(BLUE, 0.6)))


static func _blast_mesh() -> Mesh:
	return Kit.cached_mesh("aobiko_alev", func():
		var items := []
		for i in 40:
			var d = Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)).limit_length(1.0)
			items.append([d * R * 0.8, Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))


static func _wet_here(p: Vector3) -> bool:
	return Game.water_level(p.x, p.z) > Game.terrain_height(p.x, p.z) + 0.02


static func _raining() -> bool:
	return Game.world != null and Game.world.env != null and Game.world.env.rain != null and Game.world.env.rain.emitting


static func explode(who: Node3D, at: Vector3, mult: float) -> void:
	if is_instance_valid(who):
		Combat.hit_sphere(who, at + Vector3.UP * 0.5, R, {"dmg": DMG * mult, "knock": 15.0, "launch": 6.0, "kind": "heavy", "hitstop": 0.08, "tool": "aobiko"})
	Sfx.play("boom", at, 0.95, 0.95)
	var s = {"t": 0.0}
	var part: Array = [null]
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		(part[0] as GeometryInstance3D).set_instance_shader_parameter("prog", clampf(float(s["t"]) / 0.8, 0.0, 1.0))
		return float(s["t"]) >= 0.85
	var root = Kit.ticker(at, fn)
	part[0] = Kit.cards(root, _blast_mesh(), Kit.shader_mat("aobiko_alev", BLAST_SH), Vector3(8, 8, 8))
	var pl = Game.player
	if pl != null and is_instance_valid(pl) and Game.world and pl.global_position.distance_to(at) < 30.0:
		Game.world.env.add_shake(clampf(0.8 - pl.global_position.distance_to(at) / 40.0, 0.05, 0.8))


static func _spread(who: Node3D, at: Vector3, mult: float) -> void:
	var g = Vector3(at.x, Game.jutsu_floor(at.x, at.z) + 0.02, at.z)
	if _wet_here(g) or _raining():
		explode(who, g, mult)
		return
	var s = {"t": 0.0, "scan": 0.0}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		s["scan"] = float(s["scan"]) - dt
		if float(s["t"]) >= LIFE:
			return true
		if float(s["scan"]) > 0.0:
			return false
		s["scan"] = 0.15
		var go = _raining()
		if not go:
			for pr in Kit.tree().get_nodes_in_group("projectiles"):
				if is_instance_valid(pr) and str(pr.info.get("element", "")) == "suiton" and pr.global_position.distance_to(g) < float(pr.radius) + 2.0:
					go = true
					break
		if not go:
			for f in Kit.fighters():
				if not f.is_dead() and f.has_method("has_status") and f.has_status("wet") and f.global_position.distance_to(g) < 2.2:
					go = true
					break
		if go:
			explode(who, g, mult)
			return true
		return false
	var root = Kit.ticker(g, fn)
	var mi = MeshInstance3D.new()
	mi.mesh = _powder()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	Sfx.play("th_sand", g, 1.3, 0.4)


static func launch(who: Node3D, start: Vector3, dir: Vector3, _target: Node3D) -> Projectile:
	var pr = Kit.launch(who, start, dir, "aobiko", 22.0, 14.0, _pouch(), 1.0, Vector3(5, 2, 4))
	var mult = Kit.tool_mult(who, true)
	pr.on_hit = func(pos: Vector3, _t: Node3D) -> void:
		_spread(who, pos, mult)
	return pr


## Fukiya ile: nefesin nemi tozu ateşler, taş fırlar
static func _blow(p: Node3D) -> void:
	var tg = U.target_of(p)
	var aim = U.aim_at(p, tg)
	U.face(p, aim)
	var n = U.weapon_node(p, "fukiya")
	var from: Vector3 = n.to_global(Vector3(0, 0, 0.74)) if n != null else Kit.eye(p) + p.face_dir() * 0.7
	var root = Node3D.new()
	var mi = MeshInstance3D.new()
	mi.mesh = Kit.cached_mesh("aobiko_tas", func():
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3.ONE * 0.05, Color(0.45, 0.44, 0.46), Vector3.ZERO, 4)
		return b.build(Props.toon()))
	root.add_child(mi)
	U.fire(p, from, U.solve(from, aim, 70.0, 2.0), {"g": 2.0, "r": 0.1, "life": 1.2, "vis": root, "info": {"dmg": 24.0 * Kit.tool_mult(p, true), "knock": 7.0, "kind": "heavy", "hitstop": 0.05}})
	Sfx.play("boom", from, 2.2, 0.4)


static func player_use(p: Node3D) -> void:
	var blow = U.weapon_node(p, "fukiya") != null and bool(Game.profile.get("weapon_drawn", false))
	if not T.gate(p, "aobiko", 8.0 if blow else CD, false, 0.35):
		return
	if blow:
		_blow(p)
		return
	var c = p.combat
	var tgt = c._auto_target(40.0)
	var start: Vector3 = p.global_position + Vector3.UP * 1.4 + p.face_dir() * 0.4
	var aim: Vector3
	if tgt:
		c.face_to(tgt)
		aim = (tgt.global_position + Vector3.UP * tgt.height * 0.55 - start).normalized()
	else:
		aim = -p.cam.global_transform.basis.z
		p.facing = atan2(-aim.x, -aim.z)
	p.model.play("throw", 0.05, 1.8, true)
	launch(p, start, aim, tgt)
