extends RefCounted
## Enmaku Kote (sekiz namlulu bilek atarı; kanonda adsız; hedef: res://scripts/combat/fx/enmaku_kote_fx.gd). Kanon (Narutopedia "Wrist Launcher", "Dark Smoke Sphere", "Smoke Dragon"; Kihō, Shippūden 96):
## sağ kolda, sırta bağlı sekiz namlu; perde dumanı ve zehirli duman püskürtür. Küçük duman bombası yaylımı kalın bulut açar; sürekli duman chakrayla ejdere döner, atara bağlı kalır, fiziksel darbe ona işlemez.
## Görünüş refs/enmaku_kote: yumruğun çevresinde koyu lacivert sekiz namlu, krem kumaş sargı.
## Bulutlar oyunun duman görüş sistemine katılır (Combat.hidden_from): kullanan görür, rüzgâr dağıtır. Zehir DokuFX. Görseller burada. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const K = preload("res://scripts/combat/fx/kemuridama_fx.gd")
const Doku = preload("res://scripts/combat/fx/doku_fx.gd")

const ID := "enmaku_kote"
const BARRELS := 8
const RING := 0.078
const TIP_Z := 0.3
const CONE_R := 7.0
const DRAGON_R := 14.0

const PUFF_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
instance uniform float grow = 0.0;
instance uniform float erode = 0.0;
instance uniform float toxic = 0.0;
varying float sd;
void vertex() {
	sd = COLOR.r;
	vec3 c = VERTEX * grow + vec3(sin(TIME * 0.5 + sd * 40.0), 0.4 * sin(TIME * 0.4 + sd * 70.0), cos(TIME * 0.45 + sd * 90.0)) * 0.18;
	vec4 v = MODELVIEW_MATRIX * vec4(c, 1.0);
	v.xy += (UV - 0.5) * (0.8 + COLOR.g * 1.8) * (0.3 + 0.7 * min(grow, 1.0));
	VERTEX = v.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float e = 0.8 + 0.1 * sin(a * 4.0 + sd * 30.0) + 0.05 * sin(a * 9.0 - sd * 20.0) - erode * (0.5 + 0.6 * abs(sin(p.x * 5.0 + sd * 9.0) * sin(p.y * 6.0)));
	if (r > e || -VERTEX.z < 0.6) discard;
	float d = dot(vec3(p, sqrt(max(0.0, 1.0 - r * r))), normalize(vec3(0.3, 0.8, 0.4)));
	vec3 lit = mix(vec3(0.33, 0.33, 0.37), vec3(0.3, 0.36, 0.22), toxic);
	vec3 mid = mix(vec3(0.2, 0.2, 0.25), vec3(0.2, 0.25, 0.15), toxic);
	vec3 low = mix(vec3(0.11, 0.11, 0.15), vec3(0.11, 0.14, 0.09), toxic);
	ALBEDO = d > 0.45 ? lit : (d > 0.05 ? mid : low);
}
"""

const JET_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
instance uniform float toxic = 0.0;
void fragment() {
	float v = 1.0 - abs(UV.y * 2.0 - 1.0);
	float w = 0.5 + 0.5 * sin(UV.x * 22.0 - TIME * 18.0);
	float m = smoothstep(0.1 + 0.4 * w * UV.x, 0.6, v);
	ALBEDO = mix(vec3(0.24, 0.24, 0.29), vec3(0.28, 0.36, 0.2), toxic);
	ALPHA = m * fade_k * (1.0 - UV.x * UV.x * 0.8);
	if (ALPHA < 0.02) discard;
}
"""


static func build(b: MB) -> void:
	var navy = Color(0.16, 0.18, 0.25)
	var hole = Color(0.02, 0.02, 0.03)
	var cloth = Color(0.8, 0.74, 0.66)
	Loft.tube(b, [Vector3(0, 0, -0.14), Vector3(0, 0, -0.03), Vector3(0, 0, 0.07)], [0.06, 0.1, 0.122], cloth, 14, 2)
	for k in 3:
		b.add("torus", Vector3(0, 0, -0.08 + k * 0.05), Vector3(0.2 + k * 0.024, 0.2 + k * 0.024, 0.05), cloth.darkened(0.14), Vector3(90, 0, 0), 14)
	for k in BARRELS:
		var a = k * TAU / BARRELS
		var o = Vector3(cos(a) * RING, sin(a) * RING, 0)
		b.add("cyl", o + Vector3(0, 0, 0.17), Vector3(0.05, 0.26, 0.05), navy, Vector3(90, 0, 0), 10)
		b.add("cyl", o + Vector3(0, 0, TIP_Z + 0.001), Vector3(0.056, 0.012, 0.056), navy.lightened(0.1), Vector3(90, 0, 0), 10)
		b.add("cyl", o + Vector3(0, 0, TIP_Z + 0.004), Vector3(0.038, 0.012, 0.038), hole, Vector3(90, 0, 0), 10)


static func _hose_link() -> Mesh:
	return Yk.mesh("enmaku_hortum", func():
		var b = MB.new()
		b.add("cyl", Vector3.ZERO, Vector3(0.05, 0.05, 0.05), Color(0.1, 0.1, 0.13), Vector3(90, 0, 0), 8)
		return b.build(Props.toon()))


## Takılınca: atardan sırta giden hortum (kanon: düzenek sırta bağlı), sallanır
static func attach(node: Node3D, model: Node3D) -> void:
	var sk = model.get("skel")
	var bi = sk.find_bone("UpperChest") if sk != null else -1
	Yk.chain(node, _hose_link(), func(): return node.global_transform * Vector3(0, -0.1, -0.06), func():
		if bi < 0 or not is_instance_valid(sk):
			return node.global_position
		var xf: Transform3D = sk.global_transform * sk.get_bone_global_pose(bi)
		return xf.origin - model.global_transform.basis.z.normalized() * 0.16, INF, 20, 0.05, 0.14)


static func _muzzle(who: Node3D, k := -1) -> Vector3:
	var n = U.weapon_node(who, ID)
	if n == null:
		return who.global_position + Vector3.UP * 1.3 + who.face_dir() * 0.6
	if k < 0:
		return n.to_global(Vector3(0, 0, TIP_Z))
	var a = k * TAU / BARRELS
	return n.to_global(Vector3(cos(a) * RING, sin(a) * RING, TIP_Z))


static func _puff_mesh() -> Mesh:
	return Yk.mesh("enmaku_bulut", func():
		var items := []
		for i in 44:
			var d = Vector3(randf_range(-1, 1), randf_range(-0.1, 0.7), randf_range(-1, 1)).limit_length(1.0)
			items.append([d, Color(randf(), randf(), 0.0, 1.0)])
		return Kit.card_mesh(items))


## Görüş kesen bulut (tek düğüm; K.GROUP üyesi). toxic: içindekini zehirler
static func cloud(who: Node3D, at: Vector3, r: float, life: float, toxic: bool) -> void:
	var fl = Game.jutsu_floor(at.x, at.z)
	var c = Vector3(at.x, fl + 0.5 if at.y - fl < 3.0 else at.y, at.z)
	var s = {"t": 0.0, "life": life, "acc": 0.0, "n": null, "mi": null}
	var fn = func(dt: float) -> bool:
		s["t"] += dt
		var t: float = s["t"]
		var n: Node3D = s["n"]
		var mi: MeshInstance3D = s["mi"]
		s["acc"] += dt
		if float(s["acc"]) >= 0.25:
			s["acc"] = 0.0
			if n.get_meta("wind", false) or K._wind_near(n):
				s["life"] = minf(float(s["life"]), t + 0.6)
			K._drop_locks()
			if toxic and is_instance_valid(who):
				for f in Kit.fighters():
					if Combat.hostile(who, f) and not f.is_dead() and f.global_position.distance_to(c) < float(n.get_meta("r", 0.0)):
						Doku.add(f, 0.5)
		var lf: float = s["life"]
		var g = (1.0 - exp(-t * 3.5)) * r
		var e = clampf((t - (lf - 1.4)) / 1.4, 0.0, 1.0)
		mi.set_instance_shader_parameter("grow", g)
		mi.set_instance_shader_parameter("erode", e)
		n.set_meta("r", g * 0.95 * (1.0 - e * e))
		if t >= lf:
			n.remove_from_group(K.GROUP)
			return true
		return false
	var root = Kit.ticker(c, fn)
	s["n"] = root
	root.add_to_group(K.GROUP)
	root.set_meta("owner_id", who.get_instance_id() if is_instance_valid(who) else 0)
	root.set_meta("c", c)
	root.set_meta("r", 0.0)
	var mi = Kit.cards(root, _puff_mesh(), Yk.mat("enmaku_duman", PUFF_SH), Vector3.ONE * (r + 3.0))
	mi.set_instance_shader_parameter("toxic", 1.0 if toxic else 0.0)
	s["mi"] = mi
	Sfx.play("poof", c, 0.8, 0.6)


static func _grenade(who: Node3D, k: int, to: Vector3, dmg: float, r: float, life: float, toxic: bool) -> void:
	var from = _muzzle(who, k)
	var b = MeshInstance3D.new()
	b.mesh = Yk.mesh("enmaku_bomba", func():
		var mb = MB.new()
		mb.add("sphere", Vector3.ZERO, Vector3.ONE * 0.09, Color(0.14, 0.14, 0.18), Vector3.ZERO, 8)
		return mb.build(Props.toon()))
	var root = Node3D.new()
	root.add_child(b)
	var cb = func(pos: Vector3, _t: Node3D) -> void:
		cloud(who, pos, r, life, toxic)
	U.fire(who, from, U.solve(from, to, 36.0, 6.0), {"g": 6.0, "r": 0.12, "life": 1.6, "vis": root, "hit": cb,
		"info": {"dmg": dmg, "knock": 0.6, "kind": "light", "hitstop": 0.0}})
	Sfx.play("whoosh", from, 1.5, 0.3)


## Namludan çıkan koni püskürtme (görünen: kırık şeritler; hasar: Combat.hit_zone)
static func _spray(who: Node3D, f: Vector3, half: float, reach: float, dmg: float, dose: float) -> void:
	var from = _muzzle(who)
	var m = Yk.mat("enmaku_jet", JET_SH)
	for k in 7:
		var d = f.rotated(Vector3.UP, deg_to_rad(lerpf(-half, half, k / 6.0)))
		var pts = []
		for j in 7:
			var u = j / 6.0
			pts.append(from + d * reach * u + Vector3.UP * (sin(u * 6.0 + k) * 0.12 + u * 0.3))
		var mi = Yk.strip(pts, 0.1, m, -2.0)
		mi.set_instance_shader_parameter("toxic", 1.0)
		Yk.fade(mi, 0.16, 0.3)
	Sfx.play("wind", from, 1.35, 0.45)
	for h in Combat.hit_zone(who, who.global_position, f, reach, half, 2.6, {"dmg": dmg, "knock": 0.5, "kind": "light", "hitstop": 0.0, "melee": false}):
		Doku.add(h, dose)


## Enryū: atara bağlı duman ejderi hedefe kıvrılarak uzanır; şerit her karede yeniden çizilir. Fiziksel darbe işlemez: kullanan değil ejder vurur.
static func _dragon(who: Node3D, tg: Node3D, aim: Vector3, dmg: float) -> void:
	var s = {"t": 0.0, "mi": null, "hit": 0}
	var m = Yk.mat("enmaku_jet", JET_SH)
	var seed_a = randf() * TAU
	var fn = func(dt: float) -> bool:
		if not is_instance_valid(who) or who.is_dead():
			if is_instance_valid(s["mi"]):
				s["mi"].queue_free()
			return true
		s["t"] += dt
		var t: float = s["t"]
		var p0: Vector3 = _muzzle(who)
		var end: Vector3 = U.chest(tg) if U.alive(tg) and p0.distance_to(U.chest(tg)) < DRAGON_R else aim
		var ext = clampf(t / 0.3, 0.0, 1.0) * (1.0 - clampf((t - 0.85) / 0.2, 0.0, 1.0))
		var dir: Vector3 = (end - p0)
		var side = dir.cross(Vector3.UP).normalized()
		var pts = []
		for j in 18:
			var u = float(j) / 17.0 * ext
			var w = sin(u * 9.0 - t * 9.0 + seed_a) * 0.55 * sin(u * PI)
			pts.append(p0 + dir * u + side * w + Vector3.UP * cos(u * 7.0 - t * 7.0) * 0.28 * sin(u * PI))
		if is_instance_valid(s["mi"]):
			s["mi"].queue_free()
		if ext > 0.02:
			var mi = Yk.strip(pts, 0.34, m, 0.72)
			mi.set_instance_shader_parameter("toxic", 1.0)
			s["mi"] = mi
		var nh = int(t / 0.26)
		if nh > int(s["hit"]) and nh <= 3 and ext > 0.8:
			s["hit"] = nh
			for h in Combat.hit_sphere(who, pts[pts.size() - 1], 1.5, {"dmg": dmg * 0.42, "knock": 2.5, "kind": "heavy", "hitstop": 0.03, "melee": false}):
				Doku.add(h, 1.6)
		if t >= 1.05:
			if is_instance_valid(s["mi"]):
				s["mi"].queue_free()
			return true
		return false
	Kit.ticker(who.global_position, fn)
	Sfx.play("wind", who.global_position, 0.7, 0.6)


static func start(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	U.face(who, U.aim_at(who, U.target_of(who)))
	if i == 3 and who is CharacterBody3D:
		var f: Vector3 = who.face_dir()
		who.velocity.x = -f.x * 8.0
		who.velocity.z = -f.z * 8.0
		who.velocity.y = 4.0


static func strike(who: Node3D, i: int, dmg: float) -> void:
	var tg = U.target_of(who)
	var aim = U.aim_at(who, tg)
	U.face(who, aim)
	var f = Yk.face(who)
	match i:
		0:
			_grenade(who, 0, aim, dmg * 0.3, 3.6, 6.0, false)
		1:
			_spray(who, f, 22.0, CONE_R, dmg * 0.4, 2.6)
		2:
			for k in 3:
				Yk.after(who, k * 0.14, func():
					_spray(who, Yk.face(who), 26.0, CONE_R * 0.85, dmg * 0.22, 1.0))
		3:
			cloud(who, who.global_position + f * 0.8, 3.2, 5.0, false)
		4:   # Kokuen-kyū: sekiz küçük bomba, hedef çevresinde kalın bulut
			var c: Vector3 = aim
			for k in BARRELS:
				Yk.after(who, k * 0.07, func():
					var a = k * TAU / BARRELS
					_grenade(who, k, c + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 2.6), dmg * 0.12, 2.8 if k % 3 == 0 else 1.6, 7.0, k % 4 == 0))
		5:
			_dragon(who, tg, aim, dmg)
