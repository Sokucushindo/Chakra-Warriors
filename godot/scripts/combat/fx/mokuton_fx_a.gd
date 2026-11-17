class_name MokutonFXA
extends RefCounted
## Mokuton grubu A: on ahşap tekniğinin görselleri. Malzeme ve yapı taşları MokutonLib'den (canlı ahşap shader'ı: gerçek zamanlı
## kökten uca büyüme, kabuk / budak / kesik yüz halkası, kontur, kameraya yakın inceltme); her tekniğin şekli, hareketi ve
## sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok. Oynanış (hasar, durum, süre, menzil, hedefleme, zemin
## bölgeleri) ana ağaçtaki işleyicilerden satır satır taşındı. Oyuncunun ulaşabileceği yeni çarpışma eklenmedi.

const ML = preload("res://scripts/combat/fx/lib/mokuton_lib.gd")

static var _cache := {}


# ================================================================== ortak oynanış izi
## Eski zemin çatlağının oyun tarafı: büyük yarık zemin üstünden geçeni yavaşlatır (boy >= 1.5)
static func _crack_zone(pos: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(pos, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


# ================================================================== Moku Bunshin
## Ref (Yamato / Hashirama): klon kullanıcının sırtından ahşap olarak filizlenip ayrılır. Beş kıvrık filiz sırttan klonun yerine
## doğru gerçek zamanlı büyür; klon ahşap heykel olarak kayarak çıkar, kabuğu ayaklarından başına doğru soyulup insana dönüşür
## (soyulma kenarı taze açık turuncu). Filizler kopunca kıymık saçılır ve geri çekilir. Klon yıkılınca kalas kıymıklarına dağılır.
static func moku_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var sd = c.face_dir().cross(Vector3.UP)
	var at = pj.gp(c.global_position + sd * 2.5)
	var org = c.global_position
	var back = -c.face_dir()
	var g = ML.Geo.new()
	var L = 0.0
	for k in 5:
		var p0 = Vector3.UP * (0.55 + k * 0.24) + sd * 0.28 + back * 0.12
		var p2 = (at - org) + Vector3.UP * (0.35 + k * 0.3) - sd * 0.25
		var p1 = (p0 + p2) * 0.5 + back * (0.5 + 0.15 * k) + Vector3.UP * 0.35
		var radii: Array = []
		for i in 9:
			radii.append(lerpf(0.09, 0.2, float(i) / 8.0))
		L = maxf(L, ML.tube(g, ML.bez(p0, p1, p2, 9), radii, {"sides": 8, "seed": k * 1.7, "cap_end": false}))
	var mi = ML.inst(pj, g.build(), org, {"ow": 0.025, "taper": 0.9, "nf": 2.2})
	ML.life(mi, L, 0.6, 0.25, 0.3, 0.05, {"taper": 0.9})
	ML.chips(pj, org + Vector3.UP * 1.0 + sd * 0.3, 10, 4.0, {"dir": sd, "spread": 50.0, "size": 0.22})
	pj.after(0.95, func():
		var mid = org.lerp(at, 0.5) + Vector3.UP * 1.0
		ML.chips(pj, mid, 14, 5.0, {"size": 0.28})
		ML.splinters(pj, mid, 3, 0.6, 5.0))
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var d = pj.decoy(c, c.global_position, 14.0, func(pos):
			ML.splinters(pj, pos + Vector3.UP, 7, 1.0, 7.0)
			ML.chips(pj, pos + Vector3.UP, 22, 7.0, {"size": 0.4}))
		if d == null:
			return
		d.set("max_hp", 4.0)
		d.set_meta("no_smoke", true)
		var sk = {"l": []}
		pj.after(0.05, func():
			if is_instance_valid(d) and d.get("model"):
				sk["l"] = ML.skin_on(d.model, ML.BARK.lightened(0.12), d.global_position.y, 1.9, 0.0))
		var tw = d.create_tween()
		tw.tween_property(d, "global_position", at, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_method(func(a: float):
			if is_instance_valid(d):
				ML.skin_peel(sk["l"], a, d.global_position.y), 0.0, 1.0, 0.6)
		tw.tween_callback(func(): ML.skin_off(sk["l"])))
	Sfx.play("earth", at, 1.2)


# ================================================================== Mokujōheki
## Ref: kullanıcının üstünde yarım silindir ahşap tünel — kesik ön / arka yüzler açık turuncu, kemer boyunca eş merkezli halkalar,
## iç yüz koyu. Kemerin iki ayağı yerden fışkırıp gerçek zamanlı büyüyerek tepede birleşir; ayak hatlarından toz ve kıymık,
## süre bitince kemer iki yana geri çekilerek toprağa girer.
static func mokuton_mokujoheki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at = pj.gp(c.global_position)
	var fd = c.face_dir()
	var g = ML.Geo.new()
	var Rm = 2.75
	var hl = 2.6
	var L = 0.0
	for sgn in [1.0, -1.0]:
		var pts: Array = []
		var radii: Array = []
		for i in 14:
			var th = lerpf(-0.12, PI * 0.5, float(i) / 13.0)
			pts.append(Vector3(0.0, sin(th) * Rm, cos(th) * Rm * sgn))
			radii.append(1.0)
		L = maxf(L, ML.tube(g, pts, radii, {"sides": 4, "hard": true, "a0": PI * 0.25, "sx": 0.25 / 0.7071, "sy": hl / 0.7071, "cap_end": false,
			"nfn": func(_i, p, _ti): return Vector3(0.0, p.y, p.z),
			"cut_faces": [0, 2], "face_tint": [Color(1, 1, 1), Color(0.55, 0.5, 0.48), Color(1, 1, 1), Color(1, 1, 1)],
			"ring_c": Vector3.ZERO, "ring_ax": Vector3.RIGHT}))
	var root = ML.inst(pj, g.build(), at, {"ow": 0.05, "taper": 1.2, "shadow": true, "nf": 3.0})
	root.rotation.y = atan2(-fd.z, fd.x)   # tünel ekseni bakış yönünde
	ML.life(root, L, 0.35, 5.0, 0.4, 0.0, {"taper": 1.2})
	var bz = root.global_basis.z
	var dc = ML.dust_col(at)
	for s in [-1.0, 1.0]:
		for k in 3:
			var q = ML.floor_at(at + bz * s * Rm + fd * (k - 1) * 2.0)
			ML.dust(pj, q + Vector3.UP * 0.3, 1.1, 0.9, {"col": dc, "vel": bz * s * 1.6 + Vector3.UP * 0.5})
			ML.chips(pj, q + Vector3.UP * 0.2, 7, 6.0, {"dir": (bz * s + Vector3.UP).normalized(), "spread": 35.0, "size": 0.28})
	ML.scar(pj, at, 3.2, 5.5, {"lines": 8.0, "pit": 0.0})
	pj.after(5.35, func():
		for s in [-1.0, 1.0]:
			ML.dust(pj, ML.floor_at(at + bz * s * Rm) + Vector3.UP * 0.3, 1.0, 0.8, {"col": dc}))
	_crack_zone(at, 2.2 * 2.0)
	if c is Player:
		Buffs.add("mokujoheki", 5.0, {"armor": 0.15, "_name": "Ahşap Kubbe", "_desc": "ahşap kubbe seni koruyor"})
	elif c.has_method("add_buff"):
		c.add_buff("mokujoheki", 5.0, {"armor": 0.15})   # AI aynı koruma
	# kanon: yakındaki düşman kubbenin içinde kapana kısılır
	for e in pj.enemies_near(c, at, 2.6):
		pj.st(e, "bind", 1.5)
	Sfx.play("earth", at, 0.8)


# ================================================================== Kakuan Nitten Suishu
## Ref (Yamato, bijū bastırma): dev kesik kütük zemini yükselir, çevresinde iç yüzü koyu sivri dikenli on kare ahşap direk
## toz bulutları içinden fırlar; her direğin tepesinden ahşap bir el uzayıp parmaklarıyla merkezdeki hedefi aşağı bastırır.
static func _kakuan_hand() -> ArrayMesh:
	var key = "kakuan_hand"
	if _cache.has(key):
		return _cache[key]
	var g = ML.Geo.new()
	var s_arm = ML.tube(g, [Vector3(0, 4.6, -0.3), Vector3(0, 5.0, -1.0), Vector3(0, 4.95, -1.8), Vector3(0, 4.6, -2.4)], [0.36, 0.33, 0.3, 0.3],
		{"sides": 10, "cap_end": false, "seed": 1.0})
	var s_p = ML.tube(g, [Vector3(0, 4.62, -2.3), Vector3(0, 4.45, -2.85), Vector3(0, 4.3, -3.2)], [0.5, 0.55, 0.5],
		{"sides": 10, "sy": 0.42, "s0": s_arm - 0.1, "cap_end": false, "seed": 2.0, "nfn": func(_i, _p, _ti): return Vector3.RIGHT})
	for f in 4:
		var x = -0.36 + f * 0.24
		ML.tube(g, [Vector3(x, 4.32, -3.12), Vector3(x, 4.1, -3.65), Vector3(x * 1.05, 3.6, -3.9), Vector3(x * 1.05, 3.05, -3.85)], [0.12, 0.11, 0.09, 0.05],
			{"sides": 7, "s0": s_p, "cap_end": false, "seed": 3.0 + f})
	ML.tube(g, [Vector3(0.45, 4.42, -2.55), Vector3(0.78, 4.1, -3.0), Vector3(0.78, 3.6, -3.25)], [0.13, 0.11, 0.06],
		{"sides": 7, "s0": s_arm + 0.2, "cap_end": false, "seed": 9.0})
	var m = g.build()
	_cache[key] = m
	return m


static func _kakuan_post() -> ArrayMesh:
	var key = "kakuan_post"
	if _cache.has(key):
		return _cache[key]
	var g = ML.Geo.new()
	ML.beam(g, Vector3(0, -0.3, 0), 5.7, 0.85, {"seed": 4.0})
	for i in 5:
		var y = 1.0 + i * 0.85
		ML.tube(g, [Vector3(0, y, -0.4), Vector3(0, y - 0.06, -0.98)], [0.17, 0.0], {"sides": 6, "cap_end": false, "tint": Color(0.3, 0.27, 0.26), "gnarl": 0.0})
	var m = g.build()
	_cache[key] = m
	return m


static func hokage_shiki_jijun_jutsu_kakuan_nitten_suishu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	_crack_zone(at, 2.2 * 1.6)
	ML.scar(pj, at, 6.0, 5.0, {"lines": 12.0, "pit": 0.0})
	# direklerin oturduğu dev kesik kütük zemini yerden yükselir (halkalı açık tepe, üstünde bastırma çatlakları)
	var pg = ML.Geo.new()
	ML.stump(pg, Vector3(0, -1.6, 0), 5.0, 2.05, {"seed": 5.0})
	var plat = ML.inst(pj, pg.build(), at - Vector3.UP * 1.4, {"ow": 0.05, "nf": 7.0})
	ML.scar(pj, Vector3(0, 0.47, 0), 4.2, 4.8, {"parent": plat, "lines": 8.0, "pit": 0.6, "soil": Color(0.45, 0.3, 0.2)})
	var tp = plat.create_tween()
	tp.tween_property(plat, "global_position", at, 0.25).set_trans(Tween.TRANS_BACK)
	tp.tween_interval(4.2)
	tp.tween_property(plat, "global_position", at - Vector3.UP * 1.4, 0.5)
	tp.tween_callback(plat.queue_free)
	ML.dust_ring(pj, at, 5.6, 12, 1.0, 1.2)
	var hand_mesh = _kakuan_hand()
	var post_mesh = _kakuan_post()
	var dc = ML.dust_col(at)
	for k in 10:
		var a = k * TAU / 10.0
		var q = at + Vector3(cos(a), 0, sin(a)) * 5.0
		var post = Node3D.new()
		ML.put(pj, post, q - Vector3.UP * 5.2)
		post.look_at(Vector3(at.x, post.global_position.y, at.z) + Vector3(0.001, 0, 0), Vector3.UP)
		ML.inst(pj, post_mesh, Vector3.ZERO, {"parent": post, "ow": 0.045, "nf": 7.0, "seed": k * 1.3})
		var hand = ML.inst(pj, hand_mesh, Vector3.ZERO, {"parent": post, "ow": 0.035, "grow": 0.0, "taper": 0.7, "nf": 7.0, "seed": k * 2.1})
		var tw = post.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(post, "global_position", q - Vector3.UP * 0.2, 0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_callback(func():
			for j in 3:
				var o = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
				ML.dust(pj, ML.floor_at(q + o * 0.9) + Vector3.UP * 0.4, 1.0, 1.1, {"col": dc, "vel": o * 1.8 + Vector3.UP * 0.6})
			ML.chips(pj, q + Vector3.UP * 0.4, 8, 7.0, {"col": ML.soil_col(q), "col2": dc, "size": 0.32}))
		tw.tween_method(ML.pf(hand, "grow"), 0.0, 9.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(3.5)
		tw.tween_property(post, "global_position", q - Vector3.UP * 5.2, 0.5)
		tw.tween_callback(post.queue_free)
	pj.after(0.6, func():
		for e in pj.enemies_near(c, at, 5.5):
			if not is_instance_valid(e) or e.is_dead():
				continue
			pj.st(e, "bind", 4.0)
			ML.chips(pj, e.global_position + Vector3.UP * 1.5, 10, 4.0, {"dir": Vector3.DOWN, "spread": 70.0, "size": 0.3})
			e.take_hit(pj.inf(c, "hokage_shiki_jijun_jutsu_kakuan_nitten_suishu", 1.4, {"knock": 0.0, "kind": "heavy", "chakra_drain": 20.0}))
		ML.dust_ring(pj, at, 3.0, 8, 0.9, 0.9, {"col": dc})
		pj.shake(0.6))
	Sfx.play("earth", at, 0.7)


# ================================================================== Issai Kaiku (ahşap + ateş)
## Ref: ahşap klon büstleri dizi halinde alev püskürtür. Kullanıcının iki yanında dört ahşap klon yerden büyüyerek yükselir
## (uzun saçlı büst), ağızlarından dil dil cel alev seli ufka yayılır; arkasından zemin yarılır, yarık içleri kor gibi parlar ve
## alan boyunca alev sütunları fışkırır. Ateş bitince klonlar kömürleşip toprağa çekilir.
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

varying float heat;
varying float alv;

float fh(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	heat = COLOR.r;
	alv = COLOR.a;
}

void fragment() {
	float hz = fh(floor(FRAGCOORD.xy));
	if (hz > alv) {
		discard;
	}
	float dist = length(VERTEX);
	if (hz > smoothstep(1.2, 3.0, dist)) {
		discard;
	}
	float ndv = abs(dot(NORMAL, VIEW));
	float hc = ndv + heat * 0.5 - 0.35;
	vec3 c = vec3(0.55, 0.1, 0.03);
	if (hc > 0.25) {
		c = vec3(0.95, 0.35, 0.06);
	}
	if (hc > 0.55) {
		c = vec3(1.0, 0.68, 0.16);
	}
	if (hc > 0.85) {
		c = vec3(1.0, 0.95, 0.62);
	}
	if (ndv < 0.18) {
		c *= 0.55;
	}
	ALBEDO = pow(c, vec3(2.2));
}
"""


static func _flame_mat() -> ShaderMaterial:
	if _cache.has("flame"):
		return _cache["flame"]
	var sh = Shader.new()
	sh.code = FLAME_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["flame"] = m
	return m


## Alev dili: Y boyunca iğ (parçacık hız yönüne hizalanır)
static func _tongue() -> ArrayMesh:
	if _cache.has("tongue"):
		return _cache["tongue"]
	var g = ML.Geo.new()
	ML.tube(g, [Vector3(0, -0.5, 0), Vector3(0, -0.2, 0), Vector3(0, 0.15, 0), Vector3(0, 0.5, 0)], [0.0, 0.3, 0.24, 0.0], {"sides": 7, "gnarl": 0.15, "cap_end": false})
	var m = g.build()
	_cache["tongue"] = m
	return m


static func _flame_curve() -> Curve:
	if _cache.has("fcurve"):
		return _cache["fcurve"]
	var c = Curve.new()
	c.max_value = 2.0
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(0.4, 1.0))
	c.add_point(Vector2(1.0, 1.4))
	_cache["fcurve"] = c
	return c


## Alev dili akımı. dur > 0: o kadar sürekli akar; dur = 0: tek patlama. o: rad, damp, burst, up
static func _flames(host: Node, p: Vector3, dirv: Vector3, n: int, lt: float, vmin: float, vmax: float, spread: float, size: float, dur := 0.0, o := {}) -> CPUParticles3D:
	var cp = CPUParticles3D.new()
	cp.mesh = _tongue()
	cp.material_override = _flame_mat()
	cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cp.amount = maxi(n, 1)
	cp.lifetime = lt
	cp.one_shot = dur <= 0.0
	cp.explosiveness = float(o.get("burst", 0.9 if dur <= 0.0 else 0.0))
	cp.randomness = 0.3
	cp.local_coords = false
	cp.direction = dirv
	cp.spread = spread
	cp.initial_velocity_min = vmin
	cp.initial_velocity_max = vmax
	cp.damping_min = float(o.get("damp", 2.2)) * 0.7
	cp.damping_max = float(o.get("damp", 2.2))
	cp.gravity = Vector3(0, float(o.get("up", 3.0)), 0)
	cp.particle_flag_align_y = true
	cp.scale_amount_min = size * 0.7
	cp.scale_amount_max = size * 1.3
	cp.scale_amount_curve = _flame_curve()
	cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cp.emission_sphere_radius = float(o.get("rad", 0.3))
	var ga = Gradient.new()
	ga.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ga.set_color(1, Color(0.0, 1.0, 1.0, 0.0))
	ga.add_point(0.55, Color(0.55, 1.0, 1.0, 0.9))
	cp.color_ramp = ga
	ML.put(host, cp, p)
	cp.emitting = true
	if dur > 0.0:
		var w = weakref(cp)
		host.get_tree().create_timer(dur).timeout.connect(func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x):
				x.emitting = false)
	ML.kill(host, dur + lt + 0.5, cp)
	return cp


static func _clone_bust() -> Dictionary:
	if _cache.has("bust"):
		return _cache["bust"]
	var g = ML.Geo.new()
	var L = ML.tube(g, [Vector3(0, -0.5, 0), Vector3(0.05, 0.4, 0.05), Vector3(-0.03, 1.2, 0.0), Vector3(0, 1.75, 0)], [0.48, 0.42, 0.38, 0.36], {"sides": 10, "cap_end": false, "seed": 2.0})
	ML.tube(g, [Vector3(-0.62, 1.82, 0), Vector3(0, 2.0, 0), Vector3(0.62, 1.82, 0)], [0.26, 0.34, 0.26], {"sides": 9, "s0": L - 0.3, "cap_end": false})
	var sh = ML.tube(g, [Vector3(0, 1.95, 0), Vector3(0, 2.25, -0.02), Vector3(0, 2.6, -0.02), Vector3(0, 2.86, 0.02)], [0.17, 0.3, 0.29, 0.1], {"sides": 10, "s0": L, "cap_end": false, "seed": 4.0})
	for k in 5:
		var x = -0.24 + k * 0.12
		ML.tube(g, [Vector3(x, 2.78, 0.12), Vector3(x * 1.3, 2.4, 0.38), Vector3(x * 1.5, 1.9, 0.48)], [0.11, 0.09, 0.02],
			{"sides": 6, "s0": sh - 0.3, "cap_end": false, "tint": Color(0.7, 0.68, 0.66), "seed": 6.0 + k})
	var r = {"mesh": g.build(), "len": sh + 0.6, "mouth": Vector3(0, 2.38, -0.3)}
	_cache["bust"] = r
	return r


static func issai_kaiku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	var at = c.global_position
	var bust = _clone_bust()
	var mouths: Array = []
	for s in [-3.4, -2.1, 2.1, 3.4]:
		var base = pj.gp(at + side * s + d * 0.3)
		var mi = ML.inst(pj, bust["mesh"], base, {"ow": 0.035, "shadow": true, "seed": s * 3.0})
		mi.global_basis = Basis.looking_at(d, Vector3.UP).scaled(Vector3.ONE * 1.2)
		ML.life(mi, float(bust["len"]), 0.3, 1.5, 0.5)
		ML.wither_to(mi, 0.0, 0.95, 0.6, 1.25)
		mouths.append(base + mi.global_basis * (bust["mouth"] as Vector3))
		ML.chips(pj, base + Vector3.UP * 0.3, 8, 6.0, {"col": ML.soil_col(base), "size": 0.3})
		ML.light(pj, base + Vector3.UP * 2.9 + d * 0.5, Color(1.0, 0.6, 0.2), 1.5, 4.0, 0.4)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		pj.anim(c, "push", 1.4)
		for j in mouths.size():
			var sg = -1.0 if j < 2 else 1.0
			var dirv = (d + side * sg * 0.08 - Vector3.UP * 0.05).normalized()
			_flames(pj, mouths[j], dirv, 60, 0.6, 28.0, 38.0, 9.0, 1.4, 1.2, {"rad": 0.2})
		_flames(pj, at + d * 5.0 + Vector3.UP * 1.5, d, 70, 1.1, 14.0, 24.0, 22.0, 3.2, 1.2, {"rad": 2.0, "damp": 1.0})
		ML.light(pj, at + d * 14.0 + Vector3.UP * 3.0, Color(1.0, 0.55, 0.15), 12.0, 50.0, 2.5)
		for k in 22:
			pj.after(0.25 + k * 0.05, func():
				var q = pj.gp(at + d * (4.0 + k * 1.5) + side * randf_range(-6.0, 6.0) * (0.4 + k / 22.0))
				ML.scar(pj, q, 2.3, 6.0, {"lines": 7.0, "pit": 0.5, "glow": Color(1.0, 0.55, 0.12), "soil": Color(0.2, 0.12, 0.08), "t_open": 0.15})
				_crack_zone(q, 2.5, 6.0)
				_flames(pj, q + Vector3.UP * 0.3, Vector3.UP, 12, 0.8, 8.0, 15.0, 12.0, 1.8, 0.0, {"rad": 0.6})
				_flames(pj, q + Vector3.UP * 1.0, Vector3.UP, 6, 0.7, 10.0, 16.0, 30.0, 0.4, 0.0, {"rad": 0.4, "damp": 1.0})
				for e in pj.enemies_near(c, q, 2.6):
					if not is_instance_valid(e) or e.is_dead():
						continue
					e.take_hit(pj.inf(c, "issai_kaiku", 0.35, {"knock": 6.0, "launch": 8.0, "kind": "heavy", "element": "katon", "burn": 2.0})))
		Combat.hit_zone(c, at, d, 34.0, 50.0, 5.0, pj.inf(c, "issai_kaiku", 2.6, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "element": "katon", "burn": 4.0}))
		pj.shake(1.6)
		Sfx.play("boom", at + d * 10.0, 0.5))
	Sfx.play("fire", c.global_position, 0.5)


# ================================================================== Jukai Shinshoku
## Ref: kullanıcının önünden yere yayılan, birbirine dolanan kalın gri-zeytin kökler. Her kök zemine yapışık kıvrılarak gerçek
## zamanlı sürünür (yer yer kabarıp tekrar toprağa girer), dallanıp kılcal köklere ayrılır, ucunda toprak saçar; yakalanan
## hedefin bacaklarına kökler sarmal dolanır. Süre bitince kökler kuruyup toprağa gömülür.
static func _root_coil(pj: PathJutsu, pos: Vector3) -> void:
	var g = ML.Geo.new()
	var radii: Array = []
	for i in 14:
		radii.append(lerpf(0.15, 0.05, float(i) / 13.0))
	var L = ML.tube(g, ML.helix(0.75, 0.42, 1.8, 1.6, 14, randf() * TAU, 1.0 if randf() < 0.5 else -1.0, -0.25), radii, {"sides": 7, "cap_end": false})
	var mi = ML.inst(pj, g.build(), pj.gp(pos), {"body": ML.BARK_GREY, "ow": 0.025, "taper": 0.6, "nf": 2.0})
	ML.life(mi, L, 0.25, 0.4, 0.2, 0.0, {"taper": 0.6})


static func jukai_shinshoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(c.global_position + pj.fwd(c, t) * 7.0)
	var d0 = pj.fwd(c, t)
	var o = pj.gp(c.global_position + d0 * 1.5)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var soil = ML.soil_col(o)
	for k in 22:
		var dir = d0.rotated(Vector3.UP, randf_range(-1.1, 1.1))
		var L = randf_range(9.0, 16.0)
		var r = randf_range(0.35, 0.7)
		var delay = randf() * 0.35
		var from = pj.gp(o + dir.cross(Vector3.UP) * randf_range(-1.0, 1.0))
		var g = ML.Geo.new()
		var res = ML.tree(g, Vector3(0, r * 0.3, 0), dir, L, r, {"rng": rng, "hug": true, "org": from, "lift": r * 0.3, "arch": r * 0.9,
			"bend": 0.28, "depth": 1, "kids": 2 if k % 3 == 0 else 1, "spread": 0.55, "tip": 0.1, "cap_end": true, "sides": 9, "gnarl": 0.12})
		var mi = ML.inst(pj, g.build(), from, {"body": ML.BARK_GREY, "taper": 1.5, "ow": 0.035, "shadow": true, "seed": k * 0.7})
		ML.life(mi, float(res["len"]), 0.55, 3.4, 0.6, delay, {"out": "sink", "depth": r * 2.5, "taper": 1.5})
		if k % 2 == 0:
			var tip: Vector3 = from + ((res["tips"] as Array)[0] as Vector3)
			pj.after(delay + 0.5, func():
				ML.chips(pj, pj.gp(tip) + Vector3.UP * 0.2, 8, 5.0, {"col": soil, "col2": soil.lightened(0.2), "size": 0.3}))
	ML.scar(pj, o, 3.5, 4.5, {"lines": 11.0, "pit": 0.4})
	_crack_zone(o, 3.0)
	pj.every(3.5, 0.5, func(i, k):
		if not pj.live(c):
			return
		for e in pj.enemies_near(c, at, 11.0):
			if not is_instance_valid(e) or e.is_dead():
				continue
			pj.st(e, "bind", 0.6)
			if int(k) % 2 == 0:
				ML.chips(pj, e.global_position + Vector3.UP * 0.3, 6, 4.0, {"col": soil, "col2": soil.lightened(0.2), "size": 0.28})
			if i % 2 == 0:
				_root_coil(pj, e.global_position)
			e.take_hit(pj.inf(c, "jukai_shinshoku", 0.35, {"knock": 0.0, "kind": "light", "element": "mokuton"})), Callable())
	pj.shake(0.6)
	Sfx.play("earth", at, 0.5)


# ================================================================== Daijurin
## Ref (Yamato): kol, ileri doğru yelpaze gibi açılan kaba yontma köşeli ahşap kirişlere dönüşür. Dokuz kiriş elden fışkırıp
## gerçek zamanlı uzar, yolda ikişer dala ayrılır (kesik uçlar açık turuncu), uçlarında yaprak savrulur; vuruşta zeminde kıymık
## yağmuru, süre sonunda kirişler ele geri çekilir.
static func mokuton_daijurin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	for k in 9:
		pj.after(0.3 + k * 0.05, func():
			if not pj.live(c):
				return
			var off = side * randf_range(-2.4, 2.4) + Vector3.UP * randf_range(-0.6, 1.8)
			var hp = pj.hand_pos(c, true)
			var to = hp + d * randf_range(14.0, 22.0) + off * 1.8
			var dv = to - hp
			var g = ML.Geo.new()
			var res = ML.tree(g, Vector3.ZERO, dv.normalized(), dv.length(), randf_range(0.28, 0.45) * 1.3, {"hard": true, "sides": 6, "bend": 0.18,
				"depth": 1, "kids": 2, "spread": 0.5, "tip": 0.3, "seg_len": 1.6, "cap_end": true})
			var mi = ML.inst(pj, g.build(), hp, {"taper": 2.0, "ow": 0.04, "shadow": true, "nf": 3.2, "seed": k * 1.1})
			ML.life(mi, float(res["len"]), 0.45, 1.6, 0.5, 0.0, {"taper": 2.0})
			var tips: Array = res["tips"]
			pj.after(0.45, func():
				for q in tips:
					ML.leaves(pj, hp + (q as Vector3), 6, 4.0, {"size": 0.35}))
			ML.chips(pj, hp, 5, 4.0, {"dir": d, "spread": 40.0, "size": 0.25}))
	pj.after(0.6, func():
		if not pj.live(c):
			return
		for k in 5:
			var q = pj.gp(c.global_position + d * (4.0 + k * 4.0))
			ML.splinters(pj, q + Vector3.UP * 0.5, 3, 0.9, 7.0)
			ML.chips(pj, q + Vector3.UP * 0.5, 10, 8.0, {"size": 0.4})
		Combat.hit_zone(c, c.global_position, d, 22.0, 28.0, 4.0, pj.inf(c, "mokuton_daijurin_no_jutsu", 2.4, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "element": "mokuton"}))
		pj.shake(0.8))
	Sfx.play("earth", c.global_position, 0.6)


# ================================================================== Mokujin
## Dev ahşap savaşçı (Mokujin modeli) yerden yükselirken toprağı halka halinde yırtar: altı noktada kopan kök kemerleri ve
## toprak topakları fışkırır, devin çevresinde dev cel toz halkası. Her yumruk hedefte çukurlu yarık açar, toprak ve ahşap
## kıymıkları savrulur, toz halkası dışa yayılır; yumruktan kabuk kıymıkları dökülür.
static func _rip(pj: PathJutsu, q: Vector3, s: float) -> void:
	var gq = pj.gp(q)
	var sl = ML.soil_col(gq)
	ML.scar(pj, gq, 2.2 * s, 5.5, {"lines": 9.0, "pit": 0.6})
	_crack_zone(gq, 2.2 * s)
	ML.splinters(pj, gq + Vector3.UP * 0.4, 4, 1.0, 8.0, {"col": sl})
	ML.chips(pj, gq + Vector3.UP * 0.3, 12, 9.0, {"col": sl, "col2": sl.lightened(0.25), "size": 0.45})
	ML.dust(pj, gq + Vector3.UP * 0.8, 2.0, 1.3, {"col": ML.dust_col(gq)})
	var g = ML.Geo.new()
	var dv = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	var L = ML.tube(g, ML.bez(-dv * s * 1.2 - Vector3.UP * 0.6, Vector3.UP * s * 1.3, dv * s * 1.2 - Vector3.UP * 0.6, 9), [0.4 * s, 0.38 * s, 0.36 * s, 0.34 * s, 0.32 * s, 0.3 * s, 0.26 * s, 0.22 * s, 0.18 * s],
		{"sides": 9, "cap_end": false})
	var mi = ML.inst(pj, g.build(), gq, {"ow": 0.05, "taper": 1.0, "nf": 7.0})
	ML.life(mi, L, 0.4, 2.0, 0.8, 0.0, {"out": "sink", "depth": 1.8 * s})


static func _mokujin_hit(pj: PathJutsu, goal: Vector3, mj: Node3D, right: bool) -> void:
	var sl = ML.soil_col(goal)
	ML.scar(pj, goal, 8.0, 6.0, {"lines": 12.0, "pit": 1.0})
	ML.splinters(pj, goal + Vector3.UP * 0.6, 8, 0.9, 14.0, {"col": sl})
	ML.splinters(pj, goal + Vector3.UP * 1.0, 4, 0.8, 11.0)
	ML.chips(pj, goal + Vector3.UP * 0.6, 24, 14.0, {"col": sl, "col2": sl.lightened(0.25), "size": 0.6})
	ML.dust_ring(pj, goal, 3.0, 12, 1.5, 1.4, {"spd": 8.0})
	if is_instance_valid(mj) and mj.has_method("fist_pos"):
		ML.chips(pj, mj.fist_pos(right), 14, 6.0, {"dir": Vector3.DOWN, "spread": 80.0, "size": 0.5})


static func mokuton_mokujin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 60.0)
	var d = pj.fwd(c, t)
	var goal0 = pj.gp(tt.global_position if tt else c.global_position + d * 30.0)
	var msd = d.cross(Vector3.UP).normalized()
	var mcam = ML.cam_pos(pj)
	var ms = 1.0 if (c.global_position + msd * 18.0).distance_to(mcam) >= (c.global_position - msd * 18.0).distance_to(mcam) else -1.0
	var at = pj.gp(c.global_position + msd * 22.0 * ms + d * 4.0)   # yanda, kameradan uzak (devin gövdesi ekranı kaplamasın)
	var yaw = atan2(-(goal0 - at).x, -(goal0 - at).z)
	var mj = Mokujin.spawn(pj.get_tree().current_scene, at - Vector3.UP * 120.0, yaw)
	mj.set_pose("rise", 0.0)
	for k in 6:
		var rq = at + Vector3(cos(k) * 18.0, 0, sin(k) * 18.0)
		if ML.near_cam(pj, rq, 16.0):
			_crack_zone(pj.gp(rq), 2.2 * 3.0)   # görsel yok, zemin bölgesi aynı
		else:
			_rip(pj, rq, 3.0)
	ML.scar(pj, at, 16.0, 6.0, {"lines": 14.0, "pit": 0.3})
	_crack_zone(at, 30.0)
	ML.dust_ring(pj, at, 14.0, 14, 2.2, 1.6)
	pj.shake(1.2)
	Sfx.play("earth", at, 0.4)
	var tw = mj.create_tween()
	tw.tween_property(mj, "global_position", at, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): mj.set_pose("stand", 0.4))
	for k in 2:
		var right = k == 0
		tw.tween_interval(0.35)
		tw.tween_callback(func(): mj.set_pose("pull_r" if right else "pull_l", 0.45))
		tw.tween_interval(0.5)
		tw.tween_callback(func(): mj.set_pose("punch_r" if right else "punch_l", 0.3))
		tw.tween_interval(0.3)
		tw.tween_callback(func():
			var goal = pj.gp(tt.global_position if tt and pj.live(tt) else goal0)
			_mokujin_hit(pj, goal, mj, right)
			_crack_zone(goal, 3.5 * 4.0)   # eski isabet çatlağı
			_crack_zone(goal, 14.0)
			pj.hit(c, goal + Vector3.UP, 9.0, pj.inf(c, "mokuton_mokujin_no_jutsu", 1.4, {"knock": 20.0, "launch": 6.0, "kind": "heavy", "element": "mokuton", "hitstop": 0.12}))
			pj.shake(1.4))
	tw.tween_interval(0.8)
	tw.tween_callback(func(): mj.set_pose("stand", 0.4))
	tw.tween_interval(0.4)
	tw.tween_property(mj, "global_position", at - Vector3.UP * 120.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mj.queue_free)


# ================================================================== Mokuton Henge
## Ref (Yamato): bedenin çevresinde yassı ahşap şeritler zıt yönlerde sarmal çizerek yerden yükselir, onu sarar; ayakta toprak
## sıçrar, kabuk kıymıkları sarmalla döner. Oyuncu: sargı kapanınca beden gerçek bir ağaca dönüşür, tepesinden yaprak dökülür.
static func _bark_spiral(pj: PathJutsu, at: Vector3) -> void:
	var g = ML.Geo.new()
	var L = 0.0
	for k in 3:
		var pts = ML.helix(1.05, 0.55, 2.5, 1.6, 22, k * TAU / 3.0, 1.0 if k % 2 == 0 else -1.0, -0.3)
		var radii: Array = []
		for i in 22:
			radii.append(1.0)
		L = maxf(L, ML.tube(g, pts, radii, {"sides": 6, "sx": 0.05, "sy": 0.22, "gnarl": 0.0, "cap_end": false, "seed": k * 2.0,
			"tint": Color(1, 1, 1).darkened(0.08 * k), "nfn": func(_i, p, _ti): return Vector3(p.x, 0.0, p.z)}))
	var mi = ML.inst(pj, g.build(), at, {"ow": 0.025, "nf": 2.0, "taper": 0.9})
	ML.life(mi, L, 0.5, 0.9, 0.45, 0.0, {"taper": 0.9})
	ML.dust_ring(pj, at, 0.8, 6, 0.8, 0.8)
	ML.chips(pj, at + Vector3.UP * 0.5, 14, 5.0, {"dir": Vector3.UP, "spread": 40.0, "size": 0.25})


static func mokuton_henge(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var at = pj.gp(c.global_position)
	_bark_spiral(pj, at)
	_crack_zone(at, 2.2)
	if not c is Player:
		return   # NPC: eski genel dönüşümün NPC kolu yalnız görseldi (mekanik yok)
	# oyuncu: sargı kapanınca beden gerçek bir ağaca dönüşür (köylü kılığı + duman değil); saldırınca bozulur (end_henge)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		if c.get_node_or_null("Disguise"):
			Jutsu.end_henge(c)
		var tree = MeshInstance3D.new()
		tree.name = "Disguise"
		tree.mesh = AnimeTree.mesh("slender", "forest", randi() % 4)
		var k = 4.0 / maxf(tree.mesh.get_aabb().size.y, 1.0)
		tree.scale = Vector3.ONE * k
		c.add_child(tree)
		c.model.visible = false
		Buffs.add("henge", 25.0, {"stealth": 1.0})
		ML.leaves(pj, c.global_position + Vector3.UP * 3.2, 14, 3.0, {"size": 0.3, "rad": 1.0})
		ML.chips(pj, c.global_position + Vector3.UP * 1.0, 10, 4.0, {"size": 0.22})
		Hud.msg("Mokuton Henge: ağaca dönüştün. Saldırırsan bozulur.", Color(0.8, 0.9, 0.65)))


# ================================================================== Kagerō
## Ref (Mayfly): beden soluk ahşaba döner, yüzeyinden hilal biçimli soluk kabuk pulları kopup çevresine savrulur; zemin kabuk
## halkalarıyla dalgalanır ve beden içine gömülür. Süre dolunca aynı dalgayla geri çıkar.
static func _flake_mesh() -> ArrayMesh:
	if _cache.has("flake"):
		return _cache["flake"]
	var g = ML.Geo.new()
	var pts: Array = []
	for i in 6:
		var a = lerpf(0.0, 2.2, float(i) / 5.0)
		pts.append(Vector3(cos(a) * 0.35, sin(a) * 0.35, 0.0))
	ML.tube(g, pts, [0.0, 0.08, 0.11, 0.1, 0.06, 0.0], {"sides": 6, "sx": 1.0, "sy": 0.35, "cap_end": false, "nfn": func(_i, p, _ti): return Vector3(p.x, p.y, 0.0)})
	var m = g.build()
	_cache["flake"] = m
	return m


static func _kagero_fx(pj: PathJutsu, at: Vector3, pale: Color, n: int) -> void:
	for k in 2:
		pj.after(k * 0.12, func():
			ML.scar(pj, at, 1.6 + k * 0.8, 1.6, {"lines": 0.0, "pit": 0.0, "rings": 3.0, "soil": ML.BARK_DARK, "t_open": 0.4}))
	ML.chips(pj, at + Vector3.UP * 0.8, 10, 3.0, {"col": pale, "col2": pale.lightened(0.1), "size": 0.2})
	var fm = _flake_mesh()
	for k in n:
		var a = TAU * k / n + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), 0, sin(a))
		var p = at + dv * 0.45 + Vector3.UP * randf_range(0.3, 1.7)
		var mi = ML.inst(pj, fm, p, {"body": pale, "ow": 0.015, "nf": 1.2, "fresh": 0.0})
		mi.global_basis = Basis.looking_at(dv, Vector3.UP).rotated(dv, randf_range(-0.6, 0.6))
		var tw = mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "global_position", p + dv * randf_range(0.9, 1.5) - Vector3.UP * 0.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.4).set_delay(0.55)
		tw.chain().tween_callback(mi.queue_free)


static func kagero(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	# kanon (Kagerō): kullanıcı ağaç / zemin yüzeyine kaynaşıp içine gömülür (ısı pusu değil)
	var at = pj.gp(c.global_position)
	var pale = Color(0.86, 0.84, 0.78)
	var skin: Array = []
	if c.get("model"):
		skin = ML.skin_on(c.model, pale, at.y, 1.9, 1.0)
		var sw = c.create_tween()
		sw.tween_method(func(a: float): ML.skin_peel(skin, a), 1.0, 0.0, 0.18)
	_kagero_fx(pj, at, pale, 9)
	# gizlenme (eski genel gizlenme mekaniğinin Kagerō kolu, birebir)
	var d: Dictionary = Data.jutsu.get("kagero", {})
	if d.is_empty():
		ML.skin_off(skin)
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	if c.get("model"):
		var m = c.model
		var y0 = m.position.y
		var tw = m.create_tween()
		tw.tween_property(m, "position:y", y0 - 2.0, 0.45).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			m.visible = false
			ML.skin_off(skin))
		pj.get_tree().create_timer(minf(dur, 4.0)).timeout.connect(func():
			if is_instance_valid(m):
				m.visible = true
				if is_instance_valid(c):
					_kagero_fx(pj, pj.gp(c.global_position), pale, 5)
				var tb = m.create_tween()
				tb.tween_property(m, "position:y", y0, 0.4).set_ease(Tween.EASE_OUT))
	else:
		ML.skin_off(skin)


# ================================================================== Mokuryū (jutsu.gd: J = Jutsu otomatik yüklemesi)
## Ref (Hashirama): Çin ejderi gibi yılansı tahta ejder — uzun burun, tırtıklı dişli açık çene, parlayan sarı gözler, geriye
## kıvrılan boynuzlar, kabuk dikenli yele, başın ardında küçük pençeli kollar; boğumlu uzun ahşap gövde başın izini birebir izler
## (topraktan çıkar, kıvrılarak göğe yükselir, dalar, hedefi sarar). Isırıkta emilen chakra yeşil ışık taneleri halinde ağza akar.
const DRAGON := Color(0.5, 0.49, 0.38)


static func _dragon_head() -> Node3D:
	var root = Node3D.new()
	var g = ML.Geo.new()
	var upn = func(_i, _p, _ti): return Vector3.UP
	ML.tube(g, [Vector3(0, 0.15, 0.9), Vector3(0, 0.2, 0.4), Vector3(0, 0.15, -0.2), Vector3(0, 0.08, -0.9), Vector3(0, 0.02, -1.6), Vector3(0, -0.02, -2.2)],
		[0.42, 0.58, 0.55, 0.42, 0.33, 0.2], {"sides": 12, "sx": 0.8, "gnarl": 0.1, "cap_end": true, "cap_start": true, "nfn": upn})
	for s in [-1.0, 1.0]:
		ML.tube(g, [Vector3(s * 0.18, 0.5, -0.1), Vector3(s * 0.42, 0.58, 0.2), Vector3(s * 0.5, 0.5, 0.5)], [0.08, 0.12, 0.06], {"sides": 6, "cap_end": false, "tint": Color(0.72, 0.72, 0.72)})
		ML.tube(g, [Vector3(s * 0.25, 0.55, 0.35), Vector3(s * 0.5, 0.95, 0.8), Vector3(s * 0.62, 1.3, 1.5), Vector3(s * 0.52, 1.4, 2.3)], [0.15, 0.12, 0.08, 0.015], {"sides": 7, "cap_end": false})
		ML.tube(g, [Vector3(s * 0.55, 1.05, 1.0), Vector3(s * 0.85, 1.35, 1.05), Vector3(s * 1.0, 1.55, 0.95)], [0.07, 0.05, 0.01], {"sides": 6, "cap_end": false})
		ML.tube(g, [Vector3(s * 0.45, -0.25, 1.1), Vector3(s * 0.85, -0.7, 0.9), Vector3(s * 0.8, -1.15, 0.6)], [0.16, 0.13, 0.1], {"sides": 8, "cap_end": false})
		for f in 3:
			var fa = (f - 1) * 0.35
			ML.tube(g, [Vector3(s * 0.8, -1.15, 0.6), Vector3(s * (0.8 + sin(fa) * 0.18), -1.35, 0.45 - cos(fa) * 0.1), Vector3(s * (0.82 + sin(fa) * 0.25), -1.45, 0.3 - cos(fa) * 0.15)],
				[0.06, 0.045, 0.0], {"sides": 5, "cap_end": false, "tint": Color(0.6, 0.6, 0.6)})
	var rng = RandomNumberGenerator.new()
	rng.seed = 6061
	for k in 34:
		var a = rng.randf_range(-1.7, 1.7)
		var b = Vector3(sin(a) * 0.5, 0.35 + cos(a) * 0.15, 0.3 + rng.randf_range(0.0, 0.6))
		var dv = Vector3(sin(a) * 0.6, rng.randf_range(0.15, 0.55), 1.0).normalized()
		var L = rng.randf_range(0.9, 2.0)
		ML.tube(g, [b, b + dv * L * 0.5, b + dv * L + Vector3(0, -0.15, 0)], [0.13, 0.07, 0.0], {"sides": 5, "cap_end": false, "tint": Color(0.7, 0.7, 0.7).lightened(rng.randf_range(0.0, 0.15))})
	ML.inst(root, g.build(), Vector3.ZERO, {"parent": root, "body": DRAGON, "ow": 0.05, "nf": 9.0, "fresh": 0.0})
	# dişler (kemik rengi) + ağız içi
	var tg = ML.Geo.new()
	var bone = Color(0.9, 0.86, 0.72)
	for k in 9:
		var z = lerpf(-2.0, -0.3, k / 8.0)
		for s in [-1.0, 1.0]:
			var p = Vector3(s * lerpf(0.16, 0.32, k / 8.0), -0.06, z)
			ML.tube(tg, [p, p + Vector3.DOWN * (0.22 + (k % 2) * 0.08)], [0.07, 0.0], {"sides": 5, "cap_end": false, "gnarl": 0.0, "tint": bone})
	var tmi = MeshInstance3D.new()
	tmi.mesh = tg.build()
	tmi.material_override = ML.plain_mat()
	root.add_child(tmi)
	var jaw = Node3D.new()
	jaw.name = "jaw"
	root.add_child(jaw)
	jaw.position = Vector3(0, -0.12, 0.25)
	jaw.rotation.x = deg_to_rad(40)
	var jg = ML.Geo.new()
	ML.tube(jg, [Vector3(0, -0.08, 0.0), Vector3(0, -0.12, -0.8), Vector3(0, -0.1, -1.6), Vector3(0, -0.08, -2.0)], [0.36, 0.34, 0.26, 0.14],
		{"sides": 10, "sx": 0.45, "cap_end": true, "cap_start": true, "nfn": upn})
	ML.inst(root, jg.build(), Vector3.ZERO, {"parent": jaw, "body": DRAGON.darkened(0.05), "ow": 0.05, "nf": 9.0, "fresh": 0.0})
	var jt = ML.Geo.new()
	for k in 8:
		var z = lerpf(-1.85, -0.2, k / 7.0)
		for s in [-1.0, 1.0]:
			var p = Vector3(s * lerpf(0.15, 0.26, k / 7.0), 0.05, z)
			ML.tube(jt, [p, p + Vector3.UP * (0.2 + (k % 2) * 0.07)], [0.06, 0.0], {"sides": 5, "cap_end": false, "gnarl": 0.0, "tint": bone})
	ML.tube(jt, [Vector3(0, 0.07, -0.15), Vector3(0, 0.07, -1.7)], [0.22, 0.12], {"sides": 6, "sx": 0.15, "cap_end": false, "gnarl": 0.0, "tint": Color(0.18, 0.07, 0.07), "nfn": upn})
	var jmi = MeshInstance3D.new()
	jmi.mesh = jt.build()
	jmi.material_override = ML.plain_mat()
	jaw.add_child(jmi)
	for s in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		eye.mesh = ML._ball()
		eye.material_override = ML.glow_mat(Color(1.0, 0.88, 0.3), 2.4)
		eye.position = Vector3(s * 0.38, 0.38, -0.15)
		eye.rotation_degrees = Vector3(0, s * 20, -s * 15)
		eye.scale = Vector3(0.2, 0.13, 0.16)
		root.add_child(eye)
	return root


## Gövde boğumu: başa bakan (-Z) kabuklu varil + sırt dikeni + yan yele lifleri
static func _dragon_seg(r: float, ln: float) -> ArrayMesh:
	var g = ML.Geo.new()
	ML.tube(g, [Vector3(0, 0, ln * 0.62), Vector3(0, 0.02 * r, 0.0), Vector3(0, 0, -ln * 0.62)], [r * 0.92, r, r * 0.95], {"sides": 12, "gnarl": 0.12, "cap_end": false, "seed": r})
	ML.tube(g, [Vector3(0, r * 0.85, -ln * 0.2), Vector3(0, r * 1.35, ln * 0.15), Vector3(0, r * 1.6, ln * 0.45)], [r * 0.24, r * 0.12, 0.0], {"sides": 6, "cap_end": false, "tint": Color(0.68, 0.68, 0.68)})
	for s in [-1.0, 1.0]:
		ML.tube(g, [Vector3(s * r * 0.8, r * 0.45, -ln * 0.1), Vector3(s * r * 1.2, r * 0.55, ln * 0.3), Vector3(s * r * 1.35, r * 0.3, ln * 0.65)], [r * 0.14, r * 0.07, 0.0],
			{"sides": 5, "cap_end": false, "tint": Color(0.7, 0.7, 0.7)})
	return g.build()


static func _drain_wisps(J, from: Vector3, head: Node3D) -> void:
	for k in 4:
		var mi = MeshInstance3D.new()
		mi.mesh = ML._ball()
		mi.material_override = ML.glow_mat(ML.SAP, 2.6)
		mi.scale = Vector3.ONE * randf_range(0.25, 0.4)
		var p0 = from + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.8), randf_range(-0.6, 0.6))
		ML.put(J, mi, p0)
		var bow = Vector3(randf_range(-1.5, 1.5), randf_range(0.5, 2.0), randf_range(-1.5, 1.5))
		var tw = mi.create_tween()
		tw.tween_interval(k * 0.06)
		tw.tween_method(func(q: float):
			if not is_instance_valid(mi):
				return
			var goal = head.global_position if is_instance_valid(head) else p0
			mi.global_position = p0.lerp(goal, q) + bow * sin(q * PI), 0.0, 1.0, 0.32)
		tw.tween_callback(mi.queue_free)


static func mokuton_mokuryu_no_jutsu(J, c: Node3D, t: Node3D) -> void:
	# kanon (Hashirama): dev yılansı tahta ejder topraktan çıkar, rakibe dalar, onu sarmal sarıp bağlar ve ısırarak chakrasını
	# emer (vampir gibi).
	var fd = J._aim_flat(c, t)
	var base0 = J._ground(c.global_position + fd * 4.0)   # eski çıkış noktası (zemin bölgesi burada kalır)
	var sd0 = fd.cross(Vector3.UP).normalized()
	var cam = ML.cam_pos(J)
	var sgn = 1.0 if (c.global_position + sd0 * 8.0).distance_to(cam) >= (c.global_position - sd0 * 8.0).distance_to(cam) else -1.0
	var base = J._ground(c.global_position + fd * 12.0 + sd0 * 8.0 * sgn)   # görsel çıkış: önde ve yanda, kameradan uzak
	var head = Node3D.new()
	J.get_tree().current_scene.add_child(head)
	head.global_position = base - Vector3.UP * 4.0
	var hn = _dragon_head()
	hn.scale = Vector3.ONE * 3.4
	head.add_child(hn)
	var jaw: Node3D = hn.get_node("jaw")
	# gövde: 26 boğum, 2.0 aralık, 2.2 yarıçap — başın izini izler
	var count = 26
	var spacing = 2.0
	var segs: Array = []
	for i in count:
		var q = float(i) / float(count - 1)
		var r = 2.2 * lerpf(1.0, 0.28, pow(q, 1.4))
		var sm = ML.inst(J, _dragon_seg(r, spacing), base - Vector3.UP * (8.0 + i * spacing), {"body": DRAGON, "ow": 0.06, "nf": 9.0, "fresh": 0.0, "seed": i * 0.9})
		segs.append(sm)
	var st = {"trail": [base - Vector3.UP * 4.0, base - Vector3.UP * 90.0], "cb": Callable()}
	var upd = func():
		if not is_instance_valid(head):
			for s in segs:
				if is_instance_valid(s):
					if randf() < 0.3:
						ML.chips(J, s.global_position, 8, 6.0, {"col": DRAGON, "size": 0.6})
					s.queue_free()
			if J.get_tree().process_frame.is_connected(st["cb"]):
				J.get_tree().process_frame.disconnect(st["cb"])
			return
		var hp: Vector3 = head.global_position
		var tr: Array = st["trail"]
		if hp.distance_to(tr[0]) > 0.3:
			tr.push_front(hp)
			if tr.size() > 500:
				tr.resize(500)
		var a: Vector3 = hp
		var acc = 0.0
		var idx = 0
		for i in segs.size():
			var want = 3.0 + i * spacing
			while idx < tr.size():
				var bq: Vector3 = tr[idx]
				var dl = a.distance_to(bq)
				if acc + dl >= want:
					break
				acc += dl
				a = bq
				idx += 1
			var p: Vector3
			var dirv: Vector3
			if idx < tr.size():
				var b2: Vector3 = tr[idx]
				var dl2 = maxf(a.distance_to(b2), 0.0001)
				p = a.lerp(b2, clampf((want - acc) / dl2, 0.0, 1.0))
				dirv = a - b2
			else:
				p = a - Vector3.UP * (want - acc)
				dirv = Vector3.UP
			var s = segs[i]
			if is_instance_valid(s):
				s.global_position = p
				if dirv.length() > 0.0001:
					var dn = dirv.normalized()
					s.global_basis = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.97 else Vector3.RIGHT)
	st["cb"] = upd
	J.get_tree().process_frame.connect(upd)
	ML.scar(J, base, 5.4, 6.0, {"lines": 12.0, "pit": 0.8})
	_crack_zone(base0, 9.0)
	ML.splinters(J, base + Vector3.UP * 0.5, 8, 0.9, 12.0, {"col": ML.soil_col(base)})
	ML.chips(J, base + Vector3.UP * 0.5, 24, 16.0, {"col": ML.soil_col(base), "col2": ML.dust_col(base), "size": 0.6})
	ML.dust_ring(J, base, 3.0, 10, 1.6, 1.3)
	Sfx.play("earth", base)
	var tg = J._tg(c, t, 40.0)
	var tw = head.create_tween()
	var top = base + Vector3.UP * 9.0 + fd * 4.0
	var side = fd.cross(Vector3.UP)
	tw.tween_method(func(k: float):   # yükseliş: kıvrılarak gökyüzüne
		var p = (base - Vector3.UP * 4.0).lerp(top, k) + side * sin(k * TAU) * 4.0
		var nx = (base - Vector3.UP * 4.0).lerp(top, minf(1.0, k + 0.03)) + side * sin(minf(1.0, k + 0.03) * TAU) * 4.0
		head.global_position = p
		head.look_at(nx, Vector3.RIGHT if absf((nx - p).normalized().y) > 0.98 else Vector3.UP), 0.0, 1.0, 0.7)
	tw.tween_method(func(k: float):   # dalış
		var goal = (tg.global_position + Vector3.UP * 1.5 if tg and is_instance_valid(tg) else c.global_position + fd * 26.0)
		var p = top.lerp(goal, k * k)
		if p.distance_to(head.global_position) > 0.01:
			head.look_at(p, Vector3.UP)
		head.global_position = p, 0.0, 1.0, 0.45)
	tw.tween_callback(func():
		var p = head.global_position
		var gq = J._ground(p)
		ML.splinters(J, p, 6, 0.9, 10.0, {"col": DRAGON})
		ML.chips(J, p, 18, 12.0, {"col": ML.soil_col(gq), "size": 0.5})
		ML.dust_ring(J, gq, 2.0, 8, 1.3, 1.1)
		Combat.hit_sphere(c, p, 4.5, J._inf(c, "mokuton_mokuryu_no_jutsu", 0.6, {"knock": 0.0}))
		if tg and is_instance_valid(tg):
			tg.apply_status("bind", 3.6)
			Combat.popup_text(tg.global_position + Vector3.UP * 2.6, "Mokuryū sardı!", Color(0.8, 0.75, 0.5))
		if Game.world: Game.world.env.add_shake(0.8))
	# sarma: baş rakibin çevresinde iki tur yükselerek döner, gövde sarmal halka olur; sonra ısırır
	var ctr = {"p": Vector3.ZERO}
	tw.tween_method(func(k: float):
		var cp = tg.global_position if tg and is_instance_valid(tg) else ctr["p"]
		if ctr["p"] == Vector3.ZERO:
			ctr["p"] = cp
		var a = k * TAU * 2.0
		var r = 3.6
		var p = cp + Vector3(cos(a) * r, 0.6 + k * 4.0, sin(a) * r)
		var nx = cp + Vector3(cos(a + 0.3) * r, 0.6 + k * 4.0 + 0.1, sin(a + 0.3) * r)
		head.global_position = p
		head.look_at(nx, Vector3.UP), 0.0, 1.0, 1.1)
	tw.tween_callback(func():
		if tg and is_instance_valid(tg):
			head.look_at(tg.global_position + Vector3.UP * 1.2, Vector3.UP)
			var jt = jaw.create_tween()
			jt.tween_property(jaw, "rotation:x", 0.0, 0.12)
			Sfx.play("bite", tg.global_position, 0.8))
	# ısırık (kanon, Naruto 608/656): ejder ısırarak chakrayı vampir gibi emer, rakip yavaş yavaş jutsu yapamaz hale gelir.
	# Karşı koyma (kanon: başı yok etmek emmeyi bitirir): bağdan kurtulan (Kawarimi/kaçış) rakipte emme kesilir.
	var drain = func():
		for k in 6:
			J.get_tree().create_timer(k * 0.35).timeout.connect(func():
				if not (tg and is_instance_valid(tg)) or tg.is_dead():
					return
				if tg.has_method("has_status") and not tg.has_status("bind"):
					return   # kurtuldu: ejderin dişleri boşa kapandı
				var before = float(tg.get("chakra")) if tg.get("chakra") != null else 0.0
				tg.take_hit(J._inf(c, "mokuton_mokuryu_no_jutsu", 0.12, {"knock": 0.0, "kind": "light", "chakra_drain": 12.0}))
				if c.get("chakra") != null and c.get("max_chakra") != null:
					c.chakra = minf(float(c.max_chakra), float(c.chakra) + 6.0)
				var mx = float(tg.get("max_chakra")) if tg.get("max_chakra") != null else 100.0
				var now = float(tg.get("chakra")) if tg.get("chakra") != null else 0.0
				_drain_wisps(J, tg.global_position + Vector3.UP * 1.2, head)   # emilen chakra ağza akar
				if k == 5 or now <= mx * 0.15:
					tg.apply_status("sealed", 3.0)   # chakrası çekildi: jutsu yapamaz
					Combat.popup_text(tg.global_position + Vector3.UP * 2.8, "Chakra emildi — jutsu yapamaz!", Color(0.6, 0.9, 0.5))
				elif before > now:
					Combat.popup_text(tg.global_position + Vector3.UP * 2.4, "-%d chakra" % int(before - now), Color(0.55, 0.85, 0.5)))
	tw.tween_callback(drain)
	tw.tween_interval(2.3)
	tw.tween_callback(func():
		ML.splinters(J, head.global_position, 10, 0.9, 10.0, {"col": DRAGON})
		ML.chips(J, head.global_position, 20, 10.0, {"col": DRAGON, "size": 0.6})
		head.queue_free())
