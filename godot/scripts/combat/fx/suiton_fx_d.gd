class_name SuitonFXD
extends RefCounted
## Suiton grubu D: on beş su tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları SuitonLib'den
## (kendi su gölgelendiricisi, damla, birikinti, sis); her tekniğin şekli, hareketi ve sahnelenmesi kendine özgü.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) eski işleyicilerden satır satır taşındı.
## Büyük su kütleleri GERÇEK boyunda kurulur (küçük mesh büyütülmez: gürültü metre ölçeğinde ince kalır);
## ilerleyen akış / sütun gerilmez, gölgelendiricinin "reveal" ucuyla açılır. Kameraya 6-9 m'den yakın su incelir ("neard").

const L = preload("res://scripts/combat/fx/lib/suiton_lib.gd")

static var _cache := {}


# ------------------------------------------------------------------ küçük yardımcılar
static func _c(key: String, build: Callable):
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func _up_for(d: Vector3) -> Vector3:
	return Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT


static func _flat(v: Vector3) -> Vector3:
	var f = Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


## Düğümün -Z eksenini d yönüne çevirir (sahnede olmalı)
static func _aim(n: Node3D, d: Vector3) -> void:
	n.look_at(n.global_position + d, _up_for(d))


static func _light(h: Node, pos: Vector3, col: Color, energy: float, rng: float, t: float) -> void:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	L.put(h, l, pos)
	var tw = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Su mermisi (yalnız oynanış): eski ortak su jetinin mekaniği — hız, ömür, yarıçap (en az 0.5), güdüm, çarpma geri çağrısı.
## Görünüşü her teknik kendisi takar.
static func _jet(pj: PathJutsu, c: Node3D, from: Vector3, dir: Vector3, speed: float, radius: float, info: Dictionary, homing: Node3D = null, life := 1.6, on_hit := Callable()) -> Projectile:
	var pr = pj.shot(c, from, dir, speed, null, info, homing, false, life, on_hit)
	pr.radius = maxf(0.5, radius)
	return pr


## Yağmur alanı oynanışı (eski ortak yağmurun mekaniği): dur boyunca 0.48 sn'de bir alandaki herkese hafif vuruş
static func _rain_hits(pj: PathJutsu, c: Node3D, at: Vector3, r: float, dur: float, id: String, mul: float) -> void:
	pj.every(dur, 0.12, func(i, _k):
		if i % 4 == 0:
			for e in pj.enemies_near(c, at, r):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, id, mul, {"knock": 0.5, "kind": "light", "element": "suiton"})), Callable())


## Izgara yüzey → çift yüzlü mesh (her yüz kendi normaliyle; saydam su iki yandan da doğru gölgelenir).
## P[satır][sütun] noktalar, U aynı boyda UV; wrap_c / wrap_r: son sütun / satır ilkinin kopyası (kapalı halka)
static func _grid_mesh(P: Array, U: Array, wrap_c: bool, wrap_r := false, C := []) -> ArrayMesh:
	var rows = P.size()
	var cols = P[0].size()
	var N = []
	for j in rows:
		var row = []
		for i in cols:
			var ip = mini(i + 1, cols - 1)
			var im = maxi(i - 1, 0)
			if wrap_c:
				if i == cols - 1:
					ip = 1
				if i == 0:
					im = cols - 2
			var jp = mini(j + 1, rows - 1)
			var jm = maxi(j - 1, 0)
			if wrap_r:
				if j == rows - 1:
					jp = 1
				if j == 0:
					jm = rows - 2
			var ti: Vector3 = P[j][ip] - P[j][im]
			var tj: Vector3 = P[jp][i] - P[jm][i]
			var n = ti.cross(tj)
			row.append(n.normalized() if n.length() > 0.000001 else Vector3.UP)
		N.append(row)
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 2:
		var sg = 1.0 if side == 0 else -1.0
		var base = side * rows * cols
		for j in rows:
			for i in cols:
				sf.set_normal(N[j][i] * sg)
				if not C.is_empty():
					sf.set_color(Color(1, 1, 1, float(C[j][i])))
				sf.set_uv(U[j][i])
				sf.add_vertex(P[j][i])
		for j in rows - 1:
			for i in cols - 1:
				var a = base + j * cols + i
				var b = a + 1
				var u = a + cols
				var v = u + 1
				var pa: Vector3 = P[j][i]
				var pb: Vector3 = P[j][i + 1]
				var pu: Vector3 = P[j + 1][i]
				# Godot'da ön yüz saat yönü: ön normal = -((p1-p0)×(p2-p0)); istenen normal yönüne göre sırayı seç
				var fn = -((pb - pa).cross(pu - pa))
				if fn.dot(N[j][i] * sg) >= 0.0:
					sf.add_index(a)
					sf.add_index(b)
					sf.add_index(u)
					sf.add_index(b)
					sf.add_index(v)
					sf.add_index(u)
				else:
					sf.add_index(a)
					sf.add_index(u)
					sf.add_index(b)
					sf.add_index(b)
					sf.add_index(u)
					sf.add_index(v)
	return sf.commit()


## Profil boyunca birikimli uzunluk (UV için, metre)
static func _cum(prof: Array, sx: float, sy: float) -> Array:
	var out = [0.0]
	for i in range(1, prof.size()):
		var a: Vector2 = prof[i - 1]
		var b: Vector2 = prof[i]
		out.append(float(out[i - 1]) + Vector2((b.x - a.x) * sx, (b.y - a.y) * sy).length())
	return out


## Araziye serilen şerit: düğüm 'at'ta, -Z = d (yatay); köşeler zemine oturur (gerçek boy, ölçeklenmez)
static func _drape_strip(at: Vector3, d: Vector3, w: float, length: float, lift: float, flare := 0.0) -> ArrayMesh:
	# kıyılar düzensiz ve yumuşak: her iki kenar ayrı dalgalanır, köşe alfası kenara / uçlara doğru söner (birikinti kipi COLOR.a)
	var bs = Basis.looking_at(_flat(d), Vector3.UP)
	var nx = maxi(12, int(w / 0.7))
	var nz = maxi(10, int(length / 1.0))
	var ph = randf() * TAU
	var P = []
	var U = []
	var C = []
	for j in nz + 1:
		var v = float(j) / nz
		var z = -length * v
		var hw = w * 0.5 * (1.0 + flare * v)
		var zl = -z
		var jl = 0.16 * sin(zl * 0.55 + ph) + 0.09 * sin(zl * 1.37 + ph * 2.0) + 0.05 * sin(zl * 3.1 + ph * 3.0)
		var jr = 0.16 * sin(zl * 0.48 + ph * 1.7) + 0.09 * sin(zl * 1.51 + ph * 0.6) + 0.05 * sin(zl * 2.9 + ph * 1.3)
		var row = []
		var urow = []
		var crow = []
		var rowa = smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.88, 1.0, v))
		for i in nx + 1:
			var u = float(i) / nx
			var x = lerpf(-hw * (1.0 + jl), hw * (1.0 + jr), u)
			var edge = absf(u - 0.5) * 2.0
			var wp = at + bs * Vector3(x, 0, z)
			var y = Game.jutsu_floor(wp.x, wp.z) - at.y + lift * (1.0 - edge * edge * 0.85)
			row.append(Vector3(x, y, z))
			urow.append(Vector2(x / 3.0, zl / 3.0))
			var ea = 1.0 - smoothstep(0.45, 1.0, edge + 0.08 * sin(zl * 2.3 + u * 9.0 + ph))
			crow.append(ea * rowa)
		P.append(row)
		U.append(urow)
		C.append(crow)
	return _grid_mesh(P, U, false, false, C)


## Kaba kaya parçası (yapı malzemesi: MB yumru kaya)
static func _rock(s: float) -> MeshInstance3D:
	var k = randi() % 4
	var m = _c("rock_%d" % k, func():
		var b = MB.new()
		b.add("boulder", Vector3.ZERO, Vector3(1.0, 0.8, 0.9), Color(0.4, 0.38, 0.37), Vector3.ZERO, 30 + k)
		b.add("boulder", Vector3(0.25, 0.15, 0.1), Vector3(0.6, 0.5, 0.55), Color(0.33, 0.31, 0.31), Vector3(0, 40, 0), 34 + k)
		return b.build(Props.toon()))
	var mi = MeshInstance3D.new()
	mi.mesh = m
	mi.scale = Vector3.ONE * s
	return mi


# ================================================================== 1. Suichū — hedefin altından çan biçimli su sütunu
## Ref (Kajika): hedefin altından yükselen, altı geniş çan biçimli, içten mavi parlayan dolu su sütunu; kişi tepesinde göğe kalkar.
## Hazırlık: hedefin altında koyu ıslak leke ve içe büzülen köpük halkaları; salınım: gerçek boydaki çan yerden çıkar
## (gerilmez), dibinde ışık; tutuluş; çöküş: sütun geri gömülürken tepeden damla sağanağı, geride ıslak alan.
static func suiton_suichu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	L.big_puddle(pj, at, 2.6, 1.2, {"alpha": 0.55, "ripple": 1.0, "spread": 0.3, "pal": L.DEEP, "neard": 7.0})
	pj.every(0.3, 0.06, func(i, _k):
		L.ripple(pj, at, 2.8 - i * 0.2, 0.4, 0.22, {"foam": 1.0, "alpha": 0.7})
		if i % 2 == 0:
			L.spray(pj, at + Vector3(randf_range(-1, 1), 0.05, randf_range(-1, 1)), Vector3.UP, {"n": 5, "spread": 20.0, "vmin": 1.5, "vmax": 3.0, "life": 0.35, "smin": 0.1, "smax": 0.18}), func():
		_bell_rise(pj, at)
		for e in pj.enemies_near(c, at, 2.4):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "suiton_suichu", 1.3, {"knock": 2.0, "launch": 14.0, "kind": "heavy", "element": "suiton"})))
	Sfx.play("water", at, 0.9)


static func _bell_mesh() -> ArrayMesh:
	return _c("bell", func():
		var H = 10.5
		var prof = [[0.0, 2.6], [0.03, 2.35], [0.08, 1.95], [0.16, 1.55], [0.28, 1.25], [0.45, 1.08], [0.65, 0.98], [0.82, 0.92], [0.92, 0.82], [0.97, 0.6], [0.995, 0.3], [1.0, 0.02]]
		var pts = []
		var rad = []
		for p in prof:
			pts.append(Vector3(0, float(p[0]) * H, 0))
			rad.append(float(p[1]))
		return L.tube_mesh(pts, rad, 30))


static func _bell_rise(pj: PathJutsu, at: Vector3) -> void:
	var H = 10.5
	var bell = L.wmi(_bell_mesh(), {"alpha": 0.8, "streak": 3.0, "flow": -2.5, "foam": 0.1, "line": 0.1, "wob": 0.5, "neard": 7.0})
	L.put(pj, bell, at - Vector3.UP * H)
	bell.rotation.y = randf() * TAU
	var tw = bell.create_tween()
	tw.tween_property(bell, "global_position", at - Vector3.UP * 0.3, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		# tepeden dağılan damla sağanağı
		L.spray(pj, at + Vector3.UP * (H - 0.6), Vector3.UP, {"n": 46, "spread": 75.0, "vmin": 3.0, "vmax": 7.0, "life": 1.1, "smin": 0.2, "smax": 0.42, "r": 0.8, "foam": 0.3, "neard": 6.0}))
	tw.tween_property(bell, "global_position", at - Vector3.UP * (H + 0.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): bell.set_instance_shader_parameter("fade", v), 1.0, 0.2, 0.55)
	tw.tween_callback(bell.queue_free)
	# çanın eteği: yerde açılan sıvı dil halkası + dipten mavi ışık
	L.crown(pj, at, 2.0, {"h": 0.8, "t": 0.2, "fall": 0.7, "foam": 0.4})
	L.spray(pj, at, Vector3.UP, {"n": 30, "spread": 70.0, "vmin": 3.0, "vmax": 6.0, "life": 0.7, "smin": 0.18, "smax": 0.34, "r": 1.6, "foam": 0.3})
	_light(pj, at + Vector3.UP * 1.5, Color(0.45, 0.7, 1.0), 3.5, 9.0, 1.4)
	pj.after(1.0, func(): L.big_puddle(pj, at, 3.4, 2.4, {"alpha": 0.5, "ripple": 0.6, "spread": 0.5}))


# ================================================================== 2. Nensuikai — dönen yapışkan su diski
## Ref (Nensuikai karesi): dönerek uçan yassı, kalın kenarlı yapışkan su diski. Avuçta su toplanır; disk kalın kontürlü,
## sallantılı zarlı; ardında sünen damlalar. Çarpınca yapışkan leke ve hedefi yere bağlayan sünek su iplikleri (bağlama süresince).
static func nensuikai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 22.0)
	L.gather(pj, pj.hand_pos(c, true), 0.8, 10, 0.25, 0.4)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var holder = Node3D.new()
		var disc = _goo_disc()
		disc.rotation = Vector3(0.25, 0, 0.3)
		holder.add_child(disc)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 20.0, holder, pj.inf(c, "nensuikai", 0.6, {"knock": 1.0, "kind": "heavy", "element": "suiton"}), tt, false, 1.4, func(p, h):
			_goo_splat(pj, p, h)
			if h and pj.live(h) and h.has_method("apply_status"):
				h.apply_status("bind", 2.0)
				h.apply_status("slow", 5.0))
		pr.spin = Vector3(0, 14.0, 0)
		pr.homing_turn = 2.0
		L.trail(pr, {"n": 18, "life": 0.5, "spread": 30.0, "vmin": 0.3, "vmax": 1.0, "smin": 0.18, "smax": 0.3, "g": Vector3(0, -6, 0), "dir": Vector3.DOWN, "wob": 1.0, "line": 0.16}))
	Sfx.play("water", c.global_position, 1.2)


static func _goo_disc() -> Node3D:
	var root = Node3D.new()
	var rim_m = _c("goo_rim", func():
		var pts = []
		var rad = []
		for i in 33:
			var a = i * TAU / 32.0
			pts.append(Vector3(cos(a) * 0.82, 0.0, sin(a) * 0.82))
			rad.append(0.17 + 0.03 * sin(a * 5.0))
		return L.tube_mesh(pts, rad, 10, 0.7, Vector3.UP))
	var rim = L.wmi(rim_m, {"alpha": 0.92, "wob": 1.4, "foam": 0.15, "line": 0.2, "flow": 2.0})
	root.add_child(rim)
	var cm = _c("goo_membrane", func():
		var m = CylinderMesh.new()
		m.top_radius = 0.84
		m.bottom_radius = 0.84
		m.height = 0.07
		m.radial_segments = 28
		return m)
	var mem = L.wmi(cm, {"alpha": 0.6, "wob": 2.0, "swirl": 0.0, "line": 0.06, "streak": 0.6})
	root.add_child(mem)
	return root


## Yapışkan leke + hedefe yapışan sünek iplikler (2 sn), sonra sarkıp kopar
static func _goo_splat(pj: PathJutsu, p: Vector3, h) -> void:
	var g = L.ground(p)
	L.big_puddle(pj, g, 1.6, 3.5, {"alpha": 0.75, "ripple": 0.15, "foam": 0.12, "spread": 0.2})
	L.spray(pj, p, Vector3.UP, {"n": 16, "spread": 110.0, "vmin": 1.5, "vmax": 3.5, "life": 0.6, "smin": 0.16, "smax": 0.3, "g": Vector3(0, -9, 0), "wob": 1.0, "line": 0.16})
	var top = (h.global_position + Vector3.UP * 0.9) if (h != null and is_instance_valid(h)) else g + Vector3.UP * 0.45
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vc = 0
	var n = 6
	for k in n:
		var a = k * TAU / n + randf_range(-0.2, 0.2)
		var foot = g + Vector3(cos(a), 0.02, sin(a)) * randf_range(0.7, 1.2)
		var mid = foot.lerp(top, 0.5) + Vector3(cos(a), 0, sin(a)) * 0.25 - Vector3.UP * 0.1
		var pts = []
		var rad = []
		for j in 7:
			var u = j / 6.0
			var q = foot.lerp(mid, u * 2.0) if u < 0.5 else mid.lerp(top, (u - 0.5) * 2.0)
			pts.append(q - g)
			rad.append(lerpf(0.09, 0.035, sin(u * PI)) + (0.05 if j == 0 else 0.0))
		vc = L.tube_into(sf, vc, pts, rad, 6)
	sf.generate_normals()
	var strands = L.wmi(sf.commit(), {"alpha": 0.85, "wob": 1.5, "line": 0.18, "streak": 0.5, "flow": 0.5, "neard": 4.0})
	L.put(pj, strands, g)
	var tw = strands.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(strands, "scale", Vector3(1.0, 0.25, 1.0), 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): strands.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5)
	tw.tween_callback(strands.queue_free)


# ================================================================== 3. Kugutsu Suiton: Yōame no Mai — kukla fıskiyesi, kesici damla yağmuru
## Kuklanın ağzından göğe ince bir su ipi fışkırır (dibinde fıskiye), tepede dağılır; hedef alana güneşte parlayan
## sivri bıçak damlalar eğik yağar, her biri yerde küçük halka açar; alan yavaşça ıslanır.
static func kugutsu_suiton_yoame(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var o = c.global_position + Vector3.UP * 2.0
	var up = (Vector3.UP + c.face_dir() * 0.4).normalized()
	var pr = _jet(pj, c, o, up, 26.0, 0.5, pj.inf(c, "kugutsu_suiton_yoame", 0.1, {"element": "suiton"}), null, 0.5, func(p, _h):
		L.spray(pj, p, Vector3.UP, {"n": 30, "spread": 180.0, "vmin": 2.0, "vmax": 5.0, "life": 0.6, "smin": 0.12, "smax": 0.22, "foam": 0.5}))
	var tip = L.wmi(L.spike_mesh(), {"alpha": 0.95, "streak": 3.0, "flow": 5.0, "foam": 0.3, "line": 0.12})
	tip.scale = Vector3(0.7, 0.7, 1.4)
	pr.add_child(tip)
	L.trail(pr, {"n": 40, "life": 0.45, "spread": 6.0, "vmin": 0.5, "vmax": 1.5, "smin": 0.14, "smax": 0.24, "g": Vector3(0, -4, 0), "foam": 0.35})
	# fıskiye dibi
	for k in 4:
		pj.after(k * 0.1, func():
			L.spray(pj, o, up, {"n": 14, "spread": 7.0, "vmin": 10.0, "vmax": 16.0, "life": 0.5, "smin": 0.12, "smax": 0.22, "foam": 0.3, "g": Vector3(0, -10, 0)}))
	pj.after(0.5, func():
		_blade_rain(pj, at, 5.0, 2.5, c.face_dir())
		_rain_hits(pj, c, at, 5.0, 2.5, "kugutsu_suiton_yoame", 0.4))
	Sfx.play("water", c.global_position, 1.1)


static func _needle_mesh() -> ArrayMesh:
	return _c("needle", func():
		return L.tube_mesh([Vector3(0, -0.55, 0), Vector3(0, -0.2, 0), Vector3(0, 0.25, 0), Vector3(0, 0.45, 0), Vector3(0, 0.55, 0)], [0.0, 0.03, 0.06, 0.04, 0.0], 5))


static func _blade_rain(pj: PathJutsu, at: Vector3, r: float, dur: float, lean: Vector3) -> void:
	var p = L.particles({"n": 70, "life": 0.75, "dir": (Vector3.DOWN + _flat(lean) * 0.22).normalized(), "spread": 3.0, "vmin": 22.0, "vmax": 27.0,
		"g": Vector3(0, -10, 0), "smin": 0.9, "smax": 1.3, "mesh": _needle_mesh(), "one_shot": false, "burst": 0.0, "pal": L.FROST, "foam": 0.5, "alpha": 0.95, "line": 0.1})
	var pm = p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r, 0.5, r)
	p.visibility_aabb = AABB(Vector3(-r - 4, -22, -r - 4), Vector3(r * 2 + 8, 26, r * 2 + 8))
	L.put(pj, p, at + Vector3.UP * 16.0 - _flat(lean) * 3.5)
	p.emitting = true
	pj.free_after(dur + 1.0, p)
	pj.after(dur, func():
		if is_instance_valid(p):
			p.emitting = false)
	L.big_puddle(pj, at, r, dur, {"alpha": 0.4, "ripple": 1.0, "spread": dur * 0.6, "s0": 0.2})
	pj.every(dur, 0.1, func(_i, _k):
		var q = at + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
		L.ripple(pj, q, 0.08, 0.5, 0.3, {"foam": 1.0, "alpha": 0.8})
		L.spray(pj, L.ground(q) + Vector3.UP * 0.05, Vector3.UP, {"n": 4, "spread": 35.0, "vmin": 1.5, "vmax": 2.8, "life": 0.3, "smin": 0.08, "smax": 0.14, "pal": L.FROST}), Callable())


# ================================================================== 4. Suiren — sudan dövülmüş kılıç
## Avuca damlalar toplanır, avuçtan su kılıcı uzar: tek ağızlı hafif kavisli yassı bıçak, boyunca akan parıltı,
## kabzayı saran dönen su sarmalı, ucundan sürekli damla süzülür. Süre bitince bıçak erir, damlalara dağılır.
static func suiton_suiren(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var hp = pj.hand_pos(c, true)
	L.gather(pj, hp, 0.7, 12, 0.25, 0.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var root = Node3D.new()
		ba.add_child(root)
		var blade = L.wmi(_blade_mesh(), {"alpha": 0.88, "streak": 4.0, "flow": 5.0, "foam": 0.08, "line": 0.16, "wob": 0.3, "neard": 1.2})
		root.add_child(blade)
		blade.scale = Vector3(1.0, 0.02, 1.0)
		blade.create_tween().tween_property(blade, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var wrap = L.wmi(L.helix_mesh(0.07, 0.22, 2.0, 0.035), {"alpha": 0.9, "foam": 0.3, "line": 0.14, "flow": 4.0, "neard": 1.2})
		wrap.position = Vector3(0, -0.02, 0)
		root.add_child(wrap)
		var tws = wrap.create_tween().set_loops()
		tws.tween_property(wrap, "rotation:y", TAU, 0.6).from(0.0)
		var tipn = Node3D.new()
		tipn.position = Vector3(0, 1.08, 0.08)
		root.add_child(tipn)
		L.trail(tipn, {"n": 10, "life": 0.6, "spread": 10.0, "vmin": 0.1, "vmax": 0.4, "smin": 0.08, "smax": 0.14, "g": Vector3(0, -9, 0), "dir": Vector3.DOWN, "local": false})
		pj.after(9.6, func():
			if is_instance_valid(blade):
				L.spray(pj, blade.global_position + Vector3.UP * 0.4, Vector3.UP, {"n": 20, "spread": 160.0, "vmin": 1.0, "vmax": 3.0, "life": 0.5, "smin": 0.1, "smax": 0.2})
				var tw = blade.create_tween()
				tw.tween_property(blade, "scale", Vector3(0.6, 0.02, 0.6), 0.35).set_ease(Tween.EASE_IN)
				tw.parallel().tween_method(func(v: float): blade.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.35))
		pj.free_after(10.0, ba)
	L.spray(pj, hp, Vector3.UP, {"n": 12, "spread": 90.0, "vmin": 1.0, "vmax": 2.5, "life": 0.45, "smin": 0.1, "smax": 0.18})
	if c is Player:
		Buffs.add("suiton_suiren", 10.0, {"melee": 1.18})
	Sfx.play("water", c.global_position, 1.3)


## Yassı, hafif kavisli tek ağızlı bıçak: kemik +Y boyunca, sırt +Z'ye kıvrık
static func _blade_mesh() -> ArrayMesh:
	return _c("suiren_blade", func():
		var pts = []
		var rad = []
		for i in 12:
			var u = i / 11.0
			pts.append(Vector3(0, 0.04 + u * 1.05, 0.1 * u * u))
			rad.append(0.07 * (1.0 - pow(u, 3.0)) + 0.008 + (0.025 if i == 0 else 0.0))
		return L.tube_mesh(pts, rad, 8, 0.22, Vector3.FORWARD))


# ================================================================== 5. Jōki Bōi — buhar kuklası (Hōki klanı)
## Ref: kalın, yumuşak buhar bulutlarının içinden beliren beyaz buhar kuklası. Su değil BUHAR: yerde tıslayan sıcak
## ıslak leke, dört yandan yükselen buhar sütunları, kukla içinde belirir; omuzlarından sürekli buhar sızar, ayağının
## dibinde buhar eteği. Patlayınca dışa savrulan kaynar buhar bulutları, sıcak beyaz parlama, yoğuşan damlalar.
static func joki_boi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var at = pj.gp(c.global_position + c.face_dir() * 2.5)
	L.big_puddle(pj, at, 1.8, 1.5, {"alpha": 0.45, "ripple": 0.8, "spread": 0.3})
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.4
		var q = at + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, 1.5)
		L.mist(pj, q + Vector3.UP * 0.5, randf_range(2.2, 3.0), 1.4, {"tone": 0.0, "alpha": 0.8, "drift": Vector3.UP * 2.2 + (q - at) * 0.3, "s0": 0.3, "grow": 0.5, "near": 4.0})
	L.mist(pj, at + Vector3.UP * 1.4, 4.2, 1.2, {"tone": 0.0, "alpha": 0.7, "drift": Vector3.UP * 1.0, "s0": 0.4, "near": 4.0})
	var d = pj.decoy(c, at, 12.0, func(pos):
		_steam_blast(pj, pos)
		pj.hit(c, pos + Vector3.UP, 4.5, pj.inf(c, "joki_boi", 1.8, {"knock": 16.0, "launch": 5.0, "kind": "heavy", "element": "futton", "burn": 2.0}))
		pj.shake(0.8))
	if d:
		d.scale = Vector3.ONE * 1.6
		pj.every(12.0, 0.25, func(i, _k):
			if is_instance_valid(d):
				var sx = -1.0 if i % 2 == 0 else 1.0
				L.mist(pj, Vector3(sx * 0.3, 1.5, 0.05), randf_range(0.7, 1.0), 0.9, {"parent": d, "tone": 0.0, "alpha": 0.6, "drift": Vector3(sx * 0.2, 0.9, 0), "s0": 0.3, "near": 3.0})
				if i % 3 == 0:
					L.mist(pj, d.global_position + Vector3(randf_range(-0.6, 0.6), 0.25, randf_range(-0.6, 0.6)), randf_range(1.2, 1.7), 1.1, {"tone": 0.0, "alpha": 0.45, "drift": Vector3(0, 0.3, 0), "s0": 0.6, "near": 3.0})
				if not pj.enemies_near(c, d.global_position, 2.2).is_empty():
					d.queue_free(), Callable())
	Sfx.play("water", at, 0.8)


## Kaynar buhar patlaması: küre biçiminde dışa savrulan buhar bulutları, sıcak parlama, yoğuşan damlalar, haşlanmış ıslak zemin
static func _steam_blast(pj: PathJutsu, pos: Vector3) -> void:
	var c0 = pos + Vector3.UP * 1.2
	_light(pj, c0, Color(1.0, 0.95, 0.85), 6.0, 10.0, 0.6)
	for k in 14:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.1, 1.0), randf_range(-1, 1)).normalized()
		L.mist(pj, c0 + dv * 0.6, randf_range(2.8, 4.2), randf_range(1.4, 2.0), {"tone": 0.0, "alpha": 0.85, "drift": dv * randf_range(3.5, 5.5) + Vector3.UP * 1.2,
			"s0": 0.2, "grow": 0.3, "fin": 0.05, "fout": 0.6, "near": 5.0})
	L.mist(pj, c0, 5.5, 1.0, {"tone": 0.0, "alpha": 0.9, "s0": 0.2, "grow": 0.2, "fin": 0.03, "near": 5.0})
	L.spray(pj, c0, Vector3.UP, {"n": 40, "spread": 180.0, "vmin": 4.0, "vmax": 9.0, "life": 0.8, "smin": 0.1, "smax": 0.2, "pal": L.FROST, "foam": 0.4, "r": 0.6})
	L.big_puddle(pj, pos, 3.5, 2.0, {"alpha": 0.45, "ripple": 0.4, "spread": 0.25})
	pj.after(0.4, func():
		for k in 5:
			var q = pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			L.mist(pj, L.ground(q) + Vector3.UP * 0.4, randf_range(1.2, 1.8), 2.2, {"tone": 0.0, "alpha": 0.4, "drift": Vector3.UP * 1.4, "s0": 0.5, "near": 4.0}))


# ================================================================== 6. Daibakufu — dev şelale sütunu ve yıkıcı dalga (jutsu.gd j_ işleyicisi)
## Ref 1 (manga): ağaçları söküp yuvarlayan devasa kıvrık dalga, tepesi beyaz köpük dilleri. Ref 2 (anime): yaprak biçimli
## koyu mavi dönen su kütlesi, çevresinde beyaz sarmal şeritler. Önce ileride yaprak biçimli koyu su kütlesi beyaz sarmal
## şeritleriyle dönerek yerden yükselir, tepesinden köpük saçar; sonra çöker ve atanın önünden gerçek boyda kıvrık dev dalga
## ilerler (tepe tırtıklı, önden kıvrılan dudak, tepeden köpük dilleri), ardında araziye serilen sel yatağı açılır.
static func suiton_daibakufu_no_jutsu(js, c: Node3D, t: Node3D) -> void:
	var dir: Vector3 = js._aim_flat(c, t)
	var start: Vector3 = js._ground(c.global_position + dir * 14.0)   # sütun oyuncu kamerasını yutmasın
	Sfx.play("water", start, 0.6)
	_vortex_column(js, start)
	js.get_tree().create_timer(0.8).timeout.connect(func():
		if not is_instance_valid(c):
			return
		var d = js._jd("suiton_daibakufu_no_jutsu").duplicate()
		d["tier"] = 5
		_great_wave(js, c, d, js._aim_flat(c, t))
		Combat.hit_sphere(c, start + dir * 10.0 + Vector3.UP, 20.0, js._inf(c, "suiton_daibakufu_no_jutsu", 1.4, {"knock": 22.0, "launch": 6.0}))
		if Game.world: Game.world.env.add_shake(1.2))


## Yaprak biçimli dönen koyu su kütlesi (gerçek boy, yerden çıkar)
static func _vortex_column(h: Node, start: Vector3) -> void:
	var H = 20.0
	var prof = [[0.0, 3.0], [0.08, 3.9], [0.22, 4.8], [0.4, 5.2], [0.58, 4.9], [0.74, 3.9], [0.86, 2.6], [0.95, 1.2], [1.0, 0.2]]
	var core_m = _c("vortex_core", func():
		var pts = []
		var rad = []
		for p in prof:
			pts.append(Vector3(0, float(p[0]) * H, 0))
			rad.append(float(p[1]))
		return L.tube_mesh(pts, rad, 36))
	var root = Node3D.new()
	L.put(h, root, start - Vector3.UP * (H + 1.0))
	var core = L.wmi(core_m, {"pal": L.DEEP, "alpha": 0.93, "streak": 1.6, "flow": 2.5, "foam": 0.06, "line": 0.12, "wob": 0.7, "neard": 8.0})
	root.add_child(core)
	var spin = Node3D.new()
	root.add_child(spin)
	for k in 2:
		var rib_m = _c("vortex_rib_%d" % k, func():
			var pts = []
			var rad = []
			var n = 60
			for i in n:
				var u = float(i) / (n - 1)
				var y = u * H * 0.97
				var rr = 0.0
				for j in prof.size() - 1:
					var a0 = prof[j]
					var a1 = prof[j + 1]
					if u >= float(a0[0]) and u <= float(a1[0]):
						rr = lerpf(float(a0[1]), float(a1[1]), (u - float(a0[0])) / maxf(0.001, float(a1[0]) - float(a0[0])))
				var a = k * PI + u * TAU * 1.3
				pts.append(Vector3(cos(a) * (rr + 0.12), y, sin(a) * (rr + 0.12)))
				rad.append(0.55 * pow(absf(sin(PI * u)), 0.35) + 0.05)
			return L.tube_mesh(pts, rad, 6, 0.25, Vector3.UP))
		var rib = L.wmi(rib_m, {"pal": L.FROST, "alpha": 1.0, "foam": 0.35, "line": 0.18, "flow": 4.0, "streak": 2.0, "neard": 8.0})
		spin.add_child(rib)
	var tws = spin.create_tween().set_loops()
	tws.tween_property(spin, "rotation:y", -TAU, 1.1).from(0.0)
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", start - Vector3.UP * 0.4, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		L.spray(h, start + Vector3.UP * (H - 1.5), Vector3.UP, {"n": 60, "spread": 70.0, "vmin": 5.0, "vmax": 11.0, "life": 1.3, "smin": 0.35, "smax": 0.7, "r": 1.5, "foam": 0.6, "neard": 8.0}))
	tw.tween_interval(0.3)
	tw.tween_property(root, "global_position", start - Vector3.UP * (H + 1.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float):
		core.set_instance_shader_parameter("fade", v)
		for r in spin.get_children():
			r.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.8)
	tw.tween_callback(root.queue_free)
	L.big_puddle(h, start, 5.5, 2.2, {"alpha": 0.5, "ripple": 1.0, "spread": 0.5, "neard": 7.0})
	for k in 8:
		var a = k * TAU / 8.0
		L.spray(h, start + Vector3(cos(a), 0.1, sin(a)) * 4.5, Vector3(cos(a), 1.6, sin(a)), {"n": 10, "spread": 25.0, "vmin": 4.0, "vmax": 8.0, "life": 0.8, "smin": 0.3, "smax": 0.55, "foam": 0.5, "neard": 7.0})


const CURL := [Vector2(1.6, 0.0), Vector2(0.9, 0.35), Vector2(0.3, 0.75), Vector2(-0.15, 0.97), Vector2(-0.55, 1.0), Vector2(-0.9, 0.9),
	Vector2(-1.1, 0.7), Vector2(-1.05, 0.5), Vector2(-0.85, 0.52), Vector2(-0.65, 0.62), Vector2(-0.45, 0.5), Vector2(-0.5, 0.25),
	Vector2(-0.7, 0.0), Vector2(0.4, -0.04), Vector2(1.6, 0.0)]


## Gerçek boyda kıvrık dalga: kesit (z, y) genişlik boyunca uzar; tepe tırtıklı, uçlar incelir; -Z öne
static func _wave_mesh(w: float, hh: float) -> ArrayMesh:
	var key = "wave_%d_%d" % [int(w), int(hh * 2.0)]
	if _cache.has(key):
		return _cache[key]
	var nx = maxi(18, int(w / 0.7))
	var rng = RandomNumberGenerator.new()
	rng.seed = 5501
	var ph = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var cum = _cum(CURL, hh, hh)
	var P = []
	var U = []
	for j in nx + 1:
		var u = float(j) / nx
		var x = (u - 0.5) * w
		var e = sqrt(maxf(0.0, 1.0 - pow(absf(u - 0.5) * 2.0, 3.0)))
		var crest = 1.0 + 0.13 * sin(u * 23.0 + ph[0]) + 0.07 * sin(u * 57.0 + ph[1])
		var lead = 0.22 * sin(u * 9.0 + ph[2])
		var row = []
		var urow = []
		for i in CURL.size():
			var q: Vector2 = CURL[i]
			var top = smoothstep(0.3, 1.0, q.y)
			var y = q.y * hh * maxf(e, 0.04) * lerpf(1.0, crest, top)
			var z = (q.x + lead * top) * hh * maxf(e, 0.25)
			row.append(Vector3(x, maxf(y, -0.15), z))
			urow.append(Vector2(x / 4.0, float(cum[i]) / 4.0))
		P.append(row)
		U.append(urow)
	var m = _grid_mesh(P, U, true)
	_cache[key] = m
	return m


## Eski dalganın oynanışı birebir (tier 5 su dalgası): genişlik / mesafe / bilgi JutsuEngine.vary / info'dan; 1 sn'de ilerler,
## her karede gövde küresi; görünüş: gerçek boyda kıvrık dalga + tepe köpük dilleri + araziye serilip açılan sel yatağı
static func _great_wave(js, c: Node3D, d: Dictionary, dir: Vector3) -> void:
	var tier = int(d.get("tier", 2))
	var vr = JutsuEngine.vary(d)
	var w = (5.0 + tier * 2.0) * vr["size"]
	var h = (2.0 + tier * 0.8) * clampf(vr["size"], 1.0, 2.6)
	var dist = (14.0 + tier * 3.0) * maxf(1.0, vr["size"] * 0.8)
	var inf = JutsuEngine.info(c, d, 1.0, {"knock": 14.0 + tier * 2})
	var start: Vector3 = js._ground(c.global_position + dir * 2.0)
	var hh = clampf(h * 0.4, 3.0, 4.6)   # tepe alçak: dev duvar kameranın önünü kapatmasın
	var ahead = hh * 1.7   # dalganın arka eteği atanın / kameranın arkasına taşmasın: görüntü önde başlar
	var bs = Basis.looking_at(_flat(dir), Vector3.UP)
	var side = bs.x
	var wave = L.wmi(_wave_mesh(w, hh), {"alpha": 0.86, "streak": 1.4, "flow": -1.6, "foam": 0.08, "line": 0.1, "wob": 0.8, "neard": 11.0})
	js.get_tree().current_scene.add_child(wave)
	wave.global_transform = Transform3D(bs, start + dir * ahead)
	wave.scale = Vector3(1, 0.05, 1)
	# sel yatağı: dalganın ardında açılan, araziye oturan su şeridi
	var bed = L.wmi(_drape_strip(start, dir, w * 0.92, dist + 3.0, 0.32, 0.08), {"alpha": 0.7, "streak": 1.6, "flow": 3.0, "foam": 0.04, "line": 0.0, "flat": 1.0, "ripple": 0.15, "neard": 10.0, "reveal": 0.0})
	js.get_tree().current_scene.add_child(bed)
	bed.global_transform = Transform3D(bs, start)
	var hit = []
	Sfx.play("water", start, 0.6)
	var st0 = {"i": 0}
	var tw = wave.create_tween()
	tw.tween_method(func(k: float):
		st0["i"] += 1
		var p = start + dir * k * dist
		if is_instance_valid(wave):
			var vp = p + dir * ahead
			wave.global_position = Vector3(vp.x, Game.jutsu_floor(vp.x, vp.z), vp.z)
			# atanın önünde alçak doğar, uzaklaştıkça boy atar
			wave.scale = Vector3(1.0, lerpf(0.2, 1.0, smoothstep(0.0, 10.0, k * dist)) * minf(1.0, k * 8.0 + 0.05), 1.0)
		if is_instance_valid(bed):
			bed.set_instance_shader_parameter("reveal_d", maxf(0.0, k * dist - 0.6))
		if st0["i"] % 3 == 0:
			var q = p + dir * ahead + side * randf_range(-w * 0.42, w * 0.42) + Vector3.UP * hh * 0.95 * smoothstep(0.0, 10.0, k * dist) - dir * hh * 0.5
			L.spray(js, q, (dir + Vector3.UP * 0.7).normalized(), {"n": 9, "spread": 28.0, "vmin": 4.0, "vmax": 8.0, "life": 0.7, "smin": 0.3, "smax": 0.6, "foam": 0.7, "neard": 8.0})
		if st0["i"] % 7 == 0:
			var q2 = p + side * randf_range(-w * 0.45, w * 0.45) - dir * hh * 0.8
			L.spray(js, L.ground(q2) + Vector3.UP * 0.3, (dir * 0.6 + Vector3.UP).normalized(), {"n": 6, "spread": 40.0, "vmin": 2.0, "vmax": 4.0, "life": 0.5, "smin": 0.25, "smax": 0.45, "foam": 0.5, "neard": 8.0})
		if is_instance_valid(c):
			hit.append_array(Combat.hit_sphere(c, p + Vector3.UP, w * 0.5, inf, hit)), 0.0, 1.0, 1.0)
	tw.tween_property(wave, "scale", Vector3(1.1, 0.05, 1.1), 0.3)
	tw.parallel().tween_method(func(v: float): wave.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(func():
		var endp = start + dir * dist
		for k in 6:
			var q = endp + side * lerpf(-w * 0.4, w * 0.4, k / 5.0)
			L.spray(js, L.ground(q) + Vector3.UP * 0.2, (dir + Vector3.UP * 1.4).normalized(), {"n": 12, "spread": 35.0, "vmin": 4.0, "vmax": 8.0, "life": 0.8, "smin": 0.3, "smax": 0.55, "foam": 0.6, "neard": 8.0})
		wave.queue_free())
	var twb = bed.create_tween()
	twb.tween_interval(2.6)
	twb.tween_method(func(v: float): bed.set_instance_shader_parameter("fade", v), 1.0, 0.0, 1.4)
	twb.tween_callback(bed.queue_free)


# ================================================================== 7. Suidanha — yüksek basınçlı ince su kesici
## Ref (Tobirama): ağızdan dümdüz uzanan, kenarları tırtıklı ince beyaz-mavi su teli; değdiği yerde gri su sisi.
## Tek gerçek ışın (beyaz çekirdek + titreyen mavi kılıf) ağızdan anında uzar ve yay çizerek savrulur; ucunda
## sis ve damla püskürür; geçtiği yayda zeminde ince kesik yarıklar kalır, yavaşça kapanır.
static func suiton_suidanha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 22.0)
	var d = pj.fwd(c, tt)
	var ang := {"a": -0.5}
	var cut: Array = []   # jet savrulurken her hedefi bir kez keser
	var beam = Node3D.new()
	L.put(pj, beam, pj._mouth_pos(c))
	var core_m = _c("cutter_core", func():
		return L.tube_mesh([Vector3.ZERO, Vector3(0, 0, -0.6), Vector3(0, 0, -10.0), Vector3(0, 0, -19.6), Vector3(0, 0, -20.0)], [0.035, 0.06, 0.065, 0.06, 0.0], 8))
	var sheath_m = _c("cutter_sheath", func():
		var pts = []
		var rad = []
		for i in 21:
			pts.append(Vector3(0, 0, -float(i)))
			rad.append(0.08 + 0.14 * float(i) / 20.0 + (0.05 if i % 3 == 1 else 0.0))
		return L.tube_mesh(pts, rad, 7))
	var core = L.wmi(core_m, {"pal": L.FROST, "alpha": 1.0, "streak": 6.0, "flow": 14.0, "line": 0.0, "reveal": 0.0, "neard": 1.5})
	var sheath = L.wmi(sheath_m, {"alpha": 0.5, "streak": 4.0, "flow": 12.0, "wob": 3.0, "line": 0.22, "reveal": 0.0, "neard": 2.5})
	beam.add_child(core)
	beam.add_child(sheath)
	var mo0 = pj._mouth_pos(c)
	L.spray(pj, mo0, d, {"n": 12, "spread": 25.0, "vmin": 2.0, "vmax": 5.0, "life": 0.35, "smin": 0.08, "smax": 0.14, "pal": L.FROST, "foam": 0.5})
	pj.every(0.8, 1.0 / 30.0, func(i, k):
		if not pj.live(c):
			return
		ang["a"] = lerpf(-0.5, 0.5, k)
		var dd = d.rotated(Vector3.UP, ang["a"])
		var from = pj._mouth_pos(c)
		var end = from + dd * 20.0
		if is_instance_valid(beam):
			beam.global_position = from
			_aim(beam, dd)
			var rv = minf(20.5, (i + 1) * 7.0)
			core.set_instance_shader_parameter("reveal_d", rv)
			sheath.set_instance_shader_parameter("reveal_d", rv)
		if i % 2 == 0:
			L.spray(pj, end, Vector3.UP - dd * 0.4, {"n": 6, "spread": 60.0, "vmin": 2.0, "vmax": 5.0, "life": 0.45, "smin": 0.1, "smax": 0.2, "g": Vector3(0, -12, 0), "foam": 0.4})
			L.mist(pj, end + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.4), randf_range(-0.6, 0.6)), randf_range(1.3, 2.0), 0.7, {"tone": 3.0, "alpha": 0.5, "drift": Vector3.UP * 0.6 - dd * 0.8, "s0": 0.4, "near": 4.0})
		if i % 4 == 0:
			_cut_slit(pj, pj.gp(from + dd * randf_range(13.0, 17.0)), dd)
			cut.append_array(Combat.hit_zone(c, c.global_position, dd, 20.0, 5.0, 3.0, pj.inf(c, "suiton_suidanha", 0.68, {"knock": 3.0, "kind": "heavy", "element": "suiton", "bleed": 3.0}), cut)), func():
		if is_instance_valid(beam):
			var tw = beam.create_tween()
			tw.tween_method(func(v: float):
				core.set_instance_shader_parameter("fade", v)
				sheath.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.15)
			tw.tween_callback(beam.queue_free))
	Sfx.play("water", c.global_position, 1.2)


## Zeminde ince kesik: koyu yarık + üstünde ıslak çizgi (yay boyunca teğet), 4 sn sonra kapanır
static func _cut_slit(pj: PathJutsu, g: Vector3, dd: Vector3) -> void:
	var m = _c("slit", func():
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(2.4, 0.05, 0.11), Color(0.13, 0.12, 0.13))
		b.add("box", Vector3(0, 0.012, 0.09), Vector3(2.2, 0.04, 0.06), Color(0.3, 0.27, 0.24))
		return b.build(Props.toon()))
	var mi = MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.put(pj, mi, g + Vector3.UP * 0.02)
	mi.look_at(mi.global_position + _flat(dd), Vector3.UP)
	var wet = L.wmi(L.strand_mesh(), {"alpha": 0.7, "line": 0.0, "flow": 1.0, "streak": 0.5})
	wet.rotation.y = PI * 0.5
	wet.position = Vector3(1.1, 0.03, 0)
	wet.scale = Vector3(0.6, 0.3, 2.2)
	mi.add_child(wet)
	L.spray(pj, g + Vector3.UP * 0.1, Vector3.UP, {"n": 8, "spread": 30.0, "vmin": 2.0, "vmax": 4.5, "life": 0.4, "smin": 0.1, "smax": 0.18})
	var tw = mi.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(mi, "scale", Vector3(1.0, 0.05, 0.05), 0.6)
	tw.tween_callback(mi.queue_free)


# ================================================================== 8. Suishōha — ağızdan boşalan su, kabarıp dışa yıkılan halka dalgalar
## Ref: ağızdan boşalan su atanın çevresinde dev, yuvarlak bir kubbe dalgası olarak kabarır, dışa devrilir.
## Ağızdan yere kalın su sütunu dökülür; atanın çevresinde gerçek boyda üç halka sırt (4 / 8 / 12 m) sırayla
## yerden kabarıp dışa kıvrılır ve çöker; sırt tepelerinden köpük, yerde genişleyen sel.
static func suiton_suishoha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var at = pj.gp(c.global_position)
	Sfx.play("water", at, 0.6)
	_mouth_pour(pj, c, at)
	for k in 3:
		pj.after(0.25 + k * 0.18, func():
			var r = 4.0 + k * 4.0
			_swell_ring(pj, at, r, 1.5 + k * 0.45)
			for e in pj.enemies_near(c, at, r + 1.0):
				if pj.live(e):
					var v = e.global_position - at
					v.y = 0
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "suiton_suishoha", 0.5, {"knock": 12.0, "launch": 4.0, "kind": "heavy", "element": "suiton", "dir": v.normalized()})))
	var mo = pj._mouth_pos(c)
	_jet(pj, c, mo, Vector3.DOWN + c.face_dir() * 0.3, 18.0, 0.8, pj.inf(c, "suiton_suishoha", 0.2, {"element": "suiton"}), null, 0.3)
	pj.shake(0.8)


## Ağızdan yere dökülen kalın su sütunu (gerçek boy, 0.5 sn)
static func _mouth_pour(pj: PathJutsu, c: Node3D, at: Vector3) -> void:
	var mo = pj._mouth_pos(c)
	var g = L.ground(mo + c.face_dir() * 0.6)
	var pts = []
	var rad = []
	for i in 8:
		var u = i / 7.0
		var q = mo.lerp(g, u) + c.face_dir() * sin(u * PI) * 0.35
		pts.append(q - mo)
		rad.append(lerpf(0.18, 0.6, u * u))
	var pour = L.wmi(L.tube_mesh(pts, rad, 14), {"alpha": 0.85, "streak": 3.0, "flow": -5.0, "foam": 0.15, "line": 0.1, "wob": 1.0, "neard": 5.0})
	L.put(pj, pour, mo)
	L.fade_free(pour, 0.45, 0.25)
	L.big_puddle(pj, at, 13.0, 2.2, {"alpha": 0.5, "ripple": 0.5, "spread": 0.9, "s0": 0.15, "neard": 7.0})


const MOUND := [Vector2(-1.0, 0.0), Vector2(-0.7, 0.35), Vector2(-0.3, 0.8), Vector2(0.1, 1.0), Vector2(0.5, 0.9), Vector2(0.85, 0.62),
	Vector2(1.0, 0.4), Vector2(0.88, 0.3), Vector2(0.7, 0.22), Vector2(0.8, 0.0), Vector2(0.0, -0.05), Vector2(-1.0, 0.0)]


## Gerçek yarıçapta halka sırt: kesit (radyal, y) çember boyunca döner; tepe tırtıklı, dış dudak kıvrık
static func _mound_mesh(R: float, W: float, H: float) -> ArrayMesh:
	var key = "mound_%d_%d" % [int(R * 2.0), int(H * 4.0)]
	if _cache.has(key):
		return _cache[key]
	var segs = maxi(36, int(TAU * R / 0.8))
	var ph = randf() * TAU
	var cum = _cum(MOUND, W, H)
	var P = []
	var U = []
	for j in segs + 1:
		var a = TAU * float(j % segs) / segs
		var crest = 1.0 + 0.16 * sin(a * 7.0 + ph) + 0.09 * sin(a * 17.0 + ph * 2.0)
		var row = []
		var urow = []
		for i in MOUND.size():
			var q: Vector2 = MOUND[i]
			var top = smoothstep(0.3, 1.0, q.y)
			var rr = R + q.x * W
			row.append(Vector3(cos(a) * rr, q.y * H * lerpf(1.0, crest, top), sin(a) * rr))
			urow.append(Vector2(a * R / 4.0, float(cum[i]) / 4.0))
		P.append(row)
		U.append(urow)
	var m = _grid_mesh(P, U, true, true)
	_cache[key] = m
	return m


static func _swell_ring(pj: PathJutsu, at: Vector3, r: float, hgt: float) -> void:
	var ring = L.wmi(_mound_mesh(r, 1.3, hgt), {"alpha": 0.85, "streak": 1.2, "flow": -1.5, "foam": 0.2, "line": 0.1, "wob": 0.9, "neard": 7.0})
	L.put(pj, ring, at - Vector3.UP * (hgt + 0.3))
	ring.scale = Vector3(0.88, 1.0, 0.88)
	var tw = ring.create_tween()
	tw.tween_property(ring, "global_position", at - Vector3.UP * 0.1, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(ring, "global_position", at - Vector3.UP * (hgt + 0.3), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.45)
	tw.tween_callback(ring.queue_free)
	var n = int(6 + r)
	for k in n:
		var a = k * TAU / n + randf() * 0.3
		var o = Vector3(cos(a), 0, sin(a))
		L.spray(pj, at + o * (r + 0.6) + Vector3.UP * hgt * 0.8, (o * 1.2 + Vector3.UP).normalized(), {"n": 7, "spread": 25.0, "vmin": 3.0, "vmax": 6.0, "life": 0.7,
			"smin": 0.25, "smax": 0.45, "foam": 0.6, "neard": 7.0})


# ================================================================== 9. Daibakuryū — ileri coşan sel
## Beş kollu alçak sel: araziye oturan geniş su yatağı önden açılır (hızlı akış çizgileri), her kolun önünde
## köpüklü yuvarlanan sel ağzı (≤0.6 m), içinde sürüklenen kaya parçaları; kıyılardan yana dil dil sıçrama.
static func suiton_daibakuryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	for k in 5:
		var off = (k - 2) * 1.6
		pj.after(k * 0.05, func():
			if pj.live(c):
				var pr = _jet(pj, c, c.global_position + Vector3.UP * 0.8 + side * off, d, 24.0, 1.2, pj.inf(c, "suiton_daibakuryu", 0.35, {"knock": 14.0, "launch": 2.0, "kind": "heavy", "element": "suiton", "dir": d}), null, 1.1, func(p, _h):
					L.spray(pj, p, Vector3.UP + d * 0.5, {"n": 14, "spread": 50.0, "vmin": 3.0, "vmax": 6.0, "life": 0.6, "smin": 0.25, "smax": 0.45, "foam": 0.6}))
				_surge_lobe(pj, pr))
	var g0 = pj.gp(c.global_position + d * 1.0)
	var bed = L.wmi(_drape_strip(g0, d, 9.0, 28.0, 0.35, 0.15), {"alpha": 0.78, "streak": 2.2, "flow": 6.0, "foam": 0.05, "line": 0.0, "flat": 1.0, "ripple": 0.2, "neard": 7.0, "reveal": 0.0})
	L.put(pj, bed, g0)
	bed.global_transform = Transform3D(Basis.looking_at(_flat(d), Vector3.UP), g0)
	var tw = bed.create_tween()
	tw.tween_method(func(v: float): bed.set_instance_shader_parameter("reveal_d", v), 0.0, 27.5, 1.1)
	tw.tween_interval(1.2)
	tw.tween_method(func(v: float): bed.set_instance_shader_parameter("fade", v), 1.0, 0.0, 1.2)
	tw.tween_callback(bed.queue_free)
	pj.every(1.0, 0.1, func(_i, k):
		var q = pj.gp(c.global_position + d * (2.0 + k * 22.0))
		for s in [-1.0, 1.0]:
			L.spray(pj, q + side * s * 4.4 + Vector3.UP * 0.2, (side * s + Vector3.UP * 1.3 + d * 0.5).normalized(), {"n": 6, "spread": 25.0, "vmin": 3.0, "vmax": 5.5, "life": 0.6,
				"smin": 0.22, "smax": 0.4, "foam": 0.5}), Callable())
	Sfx.play("water", c.global_position, 0.6)


static func _lobe_mesh() -> Mesh:
	return _c("surge_lobe", func():
		var m = SphereMesh.new()
		m.radius = 1.3
		m.height = 1.2
		m.is_hemisphere = true
		m.radial_segments = 20
		m.rings = 6
		return m)


## Sel ağzı: alçak, köpüklü, yuvarlanan su lobu + içinde dönen kaya + arkaya köpük izi (mermiye bağlı)
static func _surge_lobe(pj: PathJutsu, pr: Node3D) -> void:
	var body = Node3D.new()
	pr.add_child(body)
	body.position = Vector3(0, -0.75, 0)
	var lobe = L.wmi(_lobe_mesh(), {"alpha": 0.9, "foam": 0.45, "streak": 2.0, "flow": 5.0, "line": 0.1, "wob": 1.6, "neard": 6.0})
	lobe.scale = Vector3(1.0, 0.45, 1.25)
	body.add_child(lobe)
	var rk = _rock(randf_range(0.35, 0.55))
	rk.position = Vector3(randf_range(-0.5, 0.5), 0.35, 0.4)
	body.add_child(rk)
	var tw = rk.create_tween().set_loops()
	tw.tween_property(rk, "rotation:x", -TAU, 0.5).from(0.0)
	L.trail(pr, {"n": 26, "life": 0.5, "spread": 40.0, "vmin": 1.0, "vmax": 3.0, "smin": 0.22, "smax": 0.4, "g": Vector3(0, -12, 0), "dir": Vector3(0, 1, 1), "foam": 0.6, "r": 0.8})


# ================================================================== 10. Daikaisuidan — ağızdan dev çalkantılı su kütlesi
## Ağız önünde su toplanıp şişer; gerçek boyda (2.6 m) koyu, içi çalkalanan dev su küresi süzülür, yüzü burgulu
## köpük sarmallı açık su zarıyla kaplı, ardından ağır damlalar kopar. Çarpınca sönen kubbe, yere yassı sıvı diller ve
## 6.5 m'lik sel izi yayılır.
static func suiton_daikaisuidan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 28.0)
	var mo0 = pj._mouth_pos(c)
	L.gather(pj, mo0 + c.face_dir() * 1.2, 1.8, 18, 0.38, 1.4)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var mo = pj._mouth_pos(c)
		var pr = _jet(pj, c, mo, pj.aim_at(c, tt, mo), 18.0, 2.6, pj.inf(c, "suiton_daikaisuidan", 1.6, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "suiton"}), tt, 2.0, func(p, _h):
			_mass_burst(pj, p)
			pj.hit(c, p, 6.0, pj.inf(c, "suiton_daikaisuidan", 0.6, {"knock": 14.0, "kind": "heavy", "element": "suiton"}))
			pj.shake(0.8))
		pr.homing_turn = 1.5
		var core = L.wmi(_c("mass_core", func():
			var m = SphereMesh.new()
			m.radius = 2.3
			m.height = 4.6
			m.radial_segments = 32
			m.rings = 16
			return m), {"pal": L.DEEP, "alpha": 0.95, "wob": 2.2, "foam": 0.1, "streak": 1.0, "flow": 2.0, "line": 0.12, "neard": 7.0})
		pr.add_child(core)
		var skin = L.wmi(_c("mass_skin", func():
			var m = SphereMesh.new()
			m.radius = 2.6
			m.height = 5.0
			m.radial_segments = 32
			m.rings = 16
			return m), {"alpha": 0.45, "wob": 3.0, "swirl": 1.0, "foam": 0.18, "line": 0.1, "streak": 1.5, "flow": 3.0, "neard": 7.0})
		pr.add_child(skin)
		var tws = skin.create_tween().set_loops()
		tws.tween_property(skin, "rotation:z", TAU, 1.4).from(0.0)
		L.trail(pr, {"n": 30, "life": 0.7, "spread": 35.0, "vmin": 0.5, "vmax": 2.0, "smin": 0.35, "smax": 0.6, "g": Vector3(0, -12, 0), "r": 2.0, "foam": 0.3, "neard": 6.0}))
	Sfx.play("water", c.global_position, 0.6)


static func _mass_burst(pj: PathJutsu, p: Vector3) -> void:
	var g = L.ground(p)
	var dome = L.wmi(_c("burst_dome", func():
		var m = SphereMesh.new()
		m.radius = 3.8
		m.height = 3.8
		m.is_hemisphere = true
		m.radial_segments = 32
		m.rings = 10
		return m), {"alpha": 0.8, "foam": 0.25, "wob": 2.5, "streak": 1.5, "flow": -3.0, "line": 0.1, "neard": 7.0})
	L.put(pj, dome, g)
	dome.scale = Vector3(0.6, 0.9, 0.6)
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3(1.0, 0.7, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(dome, "scale", Vector3(1.0, 0.04, 1.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(v: float): dome.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.45)
	tw.tween_callback(dome.queue_free)
	for i in 10:
		var a = TAU * i / 10.0
		var o = Vector3(cos(a), 0, sin(a))
		L.spray(pj, g + o * 3.0 + Vector3.UP * 0.4, (o * 2.0 + Vector3.UP).normalized(), {"n": 9, "spread": 18.0, "vmin": 5.0, "vmax": 9.0, "life": 0.7, "smin": 0.35, "smax": 0.6, "foam": 0.45, "neard": 7.0})
	L.big_puddle(pj, g, 6.5, 2.6, {"alpha": 0.6, "ripple": 0.7, "spread": 0.4, "s0": 0.3, "neard": 7.0})
	L.ripple(pj, g, 1.0, 6.5, 0.7, {"foam": 1.0, "alpha": 0.6})


# ================================================================== 11. Haran Banshō — üst üste çarpan kırılan dalgalar
## Atanın altında çalkalanan girdap birikintisi; dört dalga boyunca her seferinde dört yöne kıvrık kırılan dalga sırtı
## fırlar (gerçek boy, dışa bükük yay), yol boyunca köpük saçar, ömrü bitince çöküp taç sıçrar; sırtlar sırayla dönerek
## üst üste biner.
static func suiton_haran_bansho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var at = pj.gp(c.global_position)
	L.big_puddle(pj, at, 3.2, 1.4, {"alpha": 0.6, "ripple": 1.0, "spread": 0.3, "foam": 0.1})
	for k in 4:
		pj.after(0.2 + k * 0.3, func():
			L.ripple(pj, at, 1.0, 4.5, 0.45, {"foam": 1.0, "alpha": 0.7})
			var a0 = randf() * TAU
			for i in 4:
				var a = a0 + i * TAU / 4.0
				var dir = Vector3(cos(a), 0, sin(a))
				if pj.live(c):
					var pr = _jet(pj, c, at + dir * 1.5 + Vector3.UP * 0.6, (dir + Vector3.UP * 0.15).normalized(), 18.0, 1.3, pj.inf(c, "suiton_haran_bansho", 0.35, {"knock": 12.0, "launch": 4.0, "kind": "heavy", "element": "suiton", "dir": dir}), null, 0.7, func(p, _h):
						L.crown(pj, L.ground(p), 1.5, {"h": 1.2, "t": 0.12, "fall": 0.5, "foam": 0.5})
						L.spray(pj, p, Vector3.UP, {"n": 14, "spread": 70.0, "vmin": 3.0, "vmax": 6.0, "life": 0.6, "smin": 0.22, "smax": 0.4, "foam": 0.5}))
					_breaker(pj, pr))
	pj.shake(0.9)
	Sfx.play("water", at, 0.6)


const BREAK := [Vector2(0.9, 0.0), Vector2(0.45, 0.5), Vector2(0.05, 0.92), Vector2(-0.3, 1.0), Vector2(-0.62, 0.82), Vector2(-0.6, 0.55),
	Vector2(-0.42, 0.6), Vector2(-0.3, 0.32), Vector2(-0.45, 0.0), Vector2(0.2, -0.04), Vector2(0.9, 0.0)]


## Dışa bükük yay boyunca kırılan dalga sırtı (gerçek boy ~3.6 m genişlik, 1.7 m boy); -Z öne
static func _breaker_mesh(v: int) -> ArrayMesh:
	return _c("breaker_%d" % v, func():
		var R = 2.6
		var H = 1.7
		var n = 18
		var ph = v * 1.7
		var cum = _cum(BREAK, H, H)
		var P = []
		var U = []
		for j in n + 1:
			var u = float(j) / n
			var a = lerpf(-0.72, 0.72, u)
			var e = sqrt(maxf(0.0, 1.0 - pow(absf(u - 0.5) * 2.0, 2.5)))
			var crest = 1.0 + 0.15 * sin(u * 13.0 + ph)
			var base = Vector3(sin(a) * R, 0, R - cos(a) * R)
			var rd = Vector3(sin(a), 0, -cos(a))
			var row = []
			var urow = []
			for i in BREAK.size():
				var q: Vector2 = BREAK[i]
				var top = smoothstep(0.3, 1.0, q.y)
				row.append(base + rd * (-q.x * H * maxf(e, 0.3)) + Vector3.UP * (q.y * H * maxf(e, 0.05) * lerpf(1.0, crest, top) - 0.6))
				urow.append(Vector2(a * R / 3.0, float(cum[i]) / 3.0))
			P.append(row)
			U.append(urow)
		return _grid_mesh(P, U, true))


static func _breaker(pj: PathJutsu, pr: Projectile) -> void:
	var cr = L.wmi(_breaker_mesh(randi() % 3), {"alpha": 0.86, "foam": 0.3, "streak": 1.5, "flow": -2.0, "line": 0.11, "wob": 1.2, "neard": 6.0})
	pr.add_child(cr)
	cr.scale = Vector3(0.7, 0.3, 0.7)
	var tw = cr.create_tween()
	tw.tween_property(cr, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	L.trail(pr, {"n": 22, "life": 0.45, "spread": 35.0, "vmin": 1.5, "vmax": 3.5, "smin": 0.2, "smax": 0.38, "g": Vector3(0, -12, 0), "dir": Vector3(0, 1.2, 0.6), "foam": 0.6, "r": 1.2})


# ================================================================== 12. Suigun Suima — sudan savaşçılar
## Atanın dört yanında birikintiden gerçek boyda (1.9 m) su savaşçıları yükselir: gövdesi aşağıda yere akan su eteği,
## başı, kolları ve elinde su kılıcı; hedefe dönüp süzülür, vurduğunda öne atılıp kılıcını indirir (taç sıçraması),
## yolunda ıslak iz; süre sonunda çöküp birikintiye dağılır.
static func suiton_suigun_suima(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	for k in 4:
		pj.after(0.2 + k * 0.12, func():
			if not pj.live(c):
				return
			var a = TAU * k / 4.0
			var p = pj.gp(c.global_position + Vector3(cos(a), 0, sin(a)) * 3.0)
			L.big_puddle(pj, p, 1.4, 0.8, {"alpha": 0.6, "ripple": 1.0, "spread": 0.2})
			L.crown(pj, p, 1.0, {"h": 1.0, "t": 0.15, "fall": 0.5, "foam": 0.3})
			var head = Node3D.new()
			pj.scene_add(head, p)
			var fig = L.wmi(_warrior_mesh(k % 2), {"alpha": 0.82, "streak": 2.0, "flow": -2.0, "foam": 0.12, "line": 0.14, "wob": 0.8, "neard": 3.0})
			head.add_child(fig)
			fig.position = Vector3(0, -3.6, 0)
			fig.create_tween().tween_property(fig, "position:y", -1.6, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var wake = Node3D.new()
			head.add_child(wake)
			wake.position = Vector3(0, -1.45, 0)
			L.trail(wake, {"n": 10, "life": 0.4, "spread": 50.0, "vmin": 0.5, "vmax": 1.5, "smin": 0.14, "smax": 0.24, "g": Vector3(0, -9, 0), "dir": Vector3.UP, "r": 0.4})
			every_warrior(pj, c, head, fig))
	Sfx.play("water", c.global_position, 0.8)


static func every_warrior(pj: PathJutsu, c: Node3D, head: Node3D, fig: MeshInstance3D) -> void:
	pj.every(5.0, 1.0 / 20.0, func(i, _kk):
		if not is_instance_valid(head):
			return
		var e = null
		for f in pj.enemies_near(c, head.global_position, 18.0):
			if pj.live(f):
				e = f
				break
		var base = pj.gp(head.global_position)
		if e:
			var v = e.global_position - base
			v.y = 0
			base += v.normalized() * minf(v.length(), 0.35)
			if v.length() > 0.1:
				head.look_at(head.global_position + v, Vector3.UP)
			if v.length() < 1.6 and i % 10 == 0:
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "suiton_suigun_suima", 0.4, {"knock": 6.0, "kind": "heavy", "element": "suiton"}))
				_warrior_slash(pj, fig, e.global_position)
		head.global_position = base + Vector3.UP * (1.6 + sin(i * 0.3) * 0.15)
		if i % 12 == 0:
			L.big_puddle(pj, base, 0.7, 0.8, {"alpha": 0.45, "ripple": 0.3, "spread": 0.2, "dry": 0.8}), func():
		if is_instance_valid(head):
			var g = L.ground(head.global_position)
			L.crown(pj, g, 1.3, {"h": 1.1, "t": 0.12, "fall": 0.5, "foam": 0.35})
			L.spray(pj, head.global_position, Vector3.UP, {"n": 22, "spread": 120.0, "vmin": 1.5, "vmax": 4.0, "life": 0.7, "smin": 0.2, "smax": 0.38, "r": 0.5})
			L.big_puddle(pj, g, 1.6, 1.6, {"alpha": 0.55, "ripple": 0.5, "spread": 0.3})
			head.queue_free())


## Kılıç inişi: figür öne atılıp geri döner, hedefte sıvı taç
static func _warrior_slash(pj: PathJutsu, fig: MeshInstance3D, ep: Vector3) -> void:
	if not is_instance_valid(fig):
		return
	var tw = fig.create_tween()
	tw.tween_property(fig, "position:z", -0.55, 0.08).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fig, "rotation:x", -0.25, 0.08)
	tw.tween_property(fig, "position:z", 0.0, 0.22).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(fig, "rotation:x", 0.0, 0.22)
	L.crown(pj, ep + Vector3.UP * 0.9, 0.7, {"h": 0.9, "t": 0.1, "fall": 0.35, "foam": 0.45})
	L.spray(pj, ep + Vector3.UP * 1.1, Vector3.UP, {"n": 12, "spread": 90.0, "vmin": 2.0, "vmax": 4.0, "life": 0.45, "smin": 0.14, "smax": 0.26})


## Su savaşçısı: yere akan etek-gövde, baş, iki kol, sağ elde su kılıcı (gerçek boy; ayak +Y=0, yüz -Z)
static func _warrior_mesh(v: int) -> ArrayMesh:
	return _c("warrior_%d" % v, func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = 0
		var lean = 0.05 if v == 0 else -0.04
		vc = L.tube_into(sf, vc, [Vector3(0, 0.0, 0.1), Vector3(0, 0.3, 0.05), Vector3(0, 0.75, 0), Vector3(lean, 1.1, -0.02), Vector3(lean, 1.38, 0), Vector3(lean, 1.52, 0)],
			[0.7, 0.42, 0.28, 0.33, 0.27, 0.1], 14, 0.8, Vector3.RIGHT)
		vc = L.tube_into(sf, vc, [Vector3(lean, 1.5, 0), Vector3(lean, 1.58, -0.02), Vector3(lean, 1.7, -0.03), Vector3(lean, 1.82, -0.02), Vector3(lean, 1.9, 0)],
			[0.07, 0.15, 0.17, 0.14, 0.0], 12)
		vc = L.tube_into(sf, vc, [Vector3(-0.3, 1.4, 0), Vector3(-0.44, 1.14, -0.12), Vector3(-0.36, 0.96, -0.38), Vector3(-0.3, 0.92, -0.48)], [0.1, 0.085, 0.075, 0.05], 8)
		vc = L.tube_into(sf, vc, [Vector3(0.3, 1.4, 0), Vector3(0.46, 1.18, -0.18), Vector3(0.38, 1.08, -0.48), Vector3(0.34, 1.07, -0.56)], [0.1, 0.085, 0.075, 0.06], 8)
		var bl = []
		var br = []
		for i in 9:
			var u = i / 8.0
			bl.append(Vector3(0.34 - u * 0.05, 1.07 + u * 0.75, -0.56 - u * 0.55))
			br.append(0.06 * (1.0 - pow(u, 2.5)) + 0.005)
		vc = L.tube_into(sf, vc, bl, br, 6, 0.25, Vector3.RIGHT)
		sf.generate_normals()
		return sf.commit())


# ================================================================== 13. Gekiryūdan — burgulu sel mermisi
## Ref (Mei): kalın, dolu bir su sütunu ileri fışkırır — gövdesi beyaz, üstünde soluk mavi fırça darbesi sarmalları
## matkap gibi döner; yanında söktüğü kayaları sürükler, çevresinde gri toz-sis. Gerçek boyda (20 m) sütun gerilmeden
## ağızdan ileri açılır (kendi burgu gölgelendiricisi), kayalar sarmal yörüngede sürüklenir, yol boyunca yerden kaya
## sökülür, iki yanda gri sis; sonunda incelip kesilir, ucu ve ortası ıslak alan bırakır.
const DRILL_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, unshaded, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float reveal_d = 100000.0;
instance uniform float len_m = 20.0;
instance uniform float near_d = 7.0;
instance uniform float spin_s = 2.4;

varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 white = vec3(0.92, 0.96, 0.99);
	vec3 blue = vec3(0.55, 0.74, 0.87);
	vec3 deep = vec3(0.33, 0.55, 0.76);
	vec3 lc = vec3(0.12, 0.25, 0.42);
	float v = UV.y * len_m;
	float u = UV.x;
	// fırça darbesi kenarı: tırtıklı, uzunluk boyunca kayan üç sarmal bant
	float jag = vn(vec2(u * 26.0, v * 1.4 - TIME * spin_s * 3.0)) - 0.5;
	float ph = fract(u * 3.0 + v * 0.32 + TIME * spin_s + jag * 0.4);
	vec3 col = white;
	col = mix(col, blue, step(ph, 0.36));
	col = mix(col, deep, step(ph, 0.12));
	vec3 n = normalize(NORMAL);
	float fres = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	col = mix(col, deep, step(0.74, fres) * 0.55);
	col = mix(col, lc, step(0.92, fres));
	ALBEDO = pow(col, vec3(2.2));
	float rvl = 1.0 - smoothstep(reveal_d - 0.8, reveal_d, -lp.z);
	float nearf = smoothstep(near_d * 0.25, near_d, -VERTEX.z);
	ALPHA = clamp(0.97 * rvl * nearf * fade, 0.0, 1.0);
}
"""


static func _drill_mat() -> ShaderMaterial:
	return _c("drill_mat", func():
		var sh = Shader.new()
		sh.code = DRILL_SHADER
		var m = ShaderMaterial.new()
		m.shader = sh
		return m)


static func _drill_mesh(len_m: float) -> ArrayMesh:
	return _c("drill_%d" % int(len_m), func():
		var prof = [[0.0, 0.25], [0.06, 0.75], [0.2, 1.15], [0.6, 1.25], [0.93, 1.2], [1.0, 0.05]]
		var pts = []
		var rad = []
		var n = 40
		for i in n:
			var u = float(i) / (n - 1)
			var z = u * len_m
			var rr = 0.0
			for j in prof.size() - 1:
				var a0 = prof[j]
				var a1 = prof[j + 1]
				var z0 = float(a0[0]) * len_m
				var z1 = float(a1[0]) * len_m
				if z >= z0 and z <= z1:
					rr = lerpf(float(a0[1]), float(a1[1]), (z - z0) / maxf(0.001, z1 - z0))
			if z <= 1.2:
				rr = lerpf(0.25, 0.75, z / 1.2)
			pts.append(Vector3(0, 0, -z))
			rad.append(rr * (1.0 + 0.05 * sin(u * 31.0)))
		return L.tube_mesh(pts, rad, 26))


static func suiton_gekiryudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	var d = pj._face(c, tt)
	pj.busy(c, 1.5)
	pj.anim(c, "cast", 1.0)
	L.gather(pj, pj._mouth_pos(c) + d * 0.5, 1.0, 12, 0.32, 0.6)
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var from = pj._mouth_pos(c) + d * 0.5
		var len_m = 20.0
		var root = Node3D.new()
		pj.get_tree().current_scene.add_child(root)
		root.global_position = from
		root.look_at(from + d, Vector3.UP)
		var col = MeshInstance3D.new()
		col.mesh = _drill_mesh(len_m)
		col.material_override = _drill_mat()
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		col.set_instance_shader_parameter("len_m", len_m)
		col.set_instance_shader_parameter("reveal_d", 0.0)
		root.add_child(col)
		# sütunun yanında sarmal yörüngede sürüklenen kayalar
		var rocks = []
		for k in 9:
			var rk = _rock(randf_range(0.3, 0.75))
			root.add_child(rk)
			rk.set_meta("a", randf() * TAU)
			rk.set_meta("z", randf_range(2.0, len_m - 2.0))
			rk.set_meta("r", randf_range(1.35, 1.9))
			rk.visible = false
			rocks.append(rk)
		Sfx.play("water", from, 0.7)
		pj.shake(0.3)
		var seen = []
		pj.every(1.05, 0.03, func(i, k):
			if not is_instance_valid(root):
				return
			var grow = clampf(k / 0.22, 0.05, 1.0)   # ileri fışkırır
			var thin = 1.0 - smoothstep(0.82, 1.0, k)   # sonunda incelip kesilir
			var reach = len_m * grow
			col.set_instance_shader_parameter("reveal_d", reach + 0.6)
			col.scale = Vector3(maxf(thin, 0.02), maxf(thin, 0.02), 1.0)
			for rk in rocks:
				var a = float(rk.get_meta("a")) - k * 9.0
				var z = fposmod(float(rk.get_meta("z")) + k * 26.0, len_m)
				rk.visible = z < reach and thin > 0.3
				rk.position = Vector3(cos(a), sin(a), 0) * float(rk.get_meta("r")) * maxf(thin, 0.4) + Vector3(0, 0, -z)
				rk.rotation += Vector3(0.3, 0.2, 0.1)
			if i % 3 == 0:
				var tip = from + d * reach
				L.spray(pj, tip, d + Vector3.UP * 0.3, {"n": 10, "spread": 55.0, "vmin": 4.0, "vmax": 8.0, "life": 0.6, "smin": 0.25, "smax": 0.45, "foam": 0.6, "neard": 6.0})
				var gt = pj.gp(from + d * randf_range(2.0, reach))
				_tear_ground(pj, gt, d)
			if pj.live(c) and k < 0.85:
				var n = int(reach / 2.2)
				for q in n:
					for e in pj.hit(c, from + d * (1.2 + q * 2.2), 2.0, pj.inf(c, "suiton_gekiryudan", 1.0, {"knock": 14.0, "launch": 4.0, "kind": "heavy", "element": "suiton", "dir": d}), seen):
						seen.append(e), func():
			if is_instance_valid(root):
				var endp = pj.gp(from + d * len_m)
				root.queue_free()
				L.big_puddle(pj, endp, 4.0, 2.5, {"alpha": 0.6, "ripple": 0.6, "spread": 0.35, "neard": 6.0})
				L.big_puddle(pj, pj.gp(from + d * len_m * 0.5), 3.0, 2.0, {"alpha": 0.5, "ripple": 0.4, "spread": 0.35, "neard": 6.0})
				L.crown(pj, endp, 2.0, {"h": 1.2, "t": 0.15, "fall": 0.6, "foam": 0.5})
				L.spray(pj, endp + Vector3.UP * 0.5, Vector3.UP, {"n": 36, "spread": 80.0, "vmin": 4.0, "vmax": 8.0, "life": 0.9, "smin": 0.3, "smax": 0.55, "foam": 0.5, "r": 1.0})))


## Sütunun söktüğü zemin: fırlayan kaya parçaları, iki yanda gri toz-sis, ince köpük
static func _tear_ground(pj: PathJutsu, g: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	for k in 2:
		var rk = _rock(randf_range(0.15, 0.3))
		L.put(pj, rk, g + Vector3.UP * 0.2)
		var vel = (Vector3.UP * randf_range(4.0, 7.0) + side * randf_range(-3.0, 3.0) + d * randf_range(1.0, 4.0))
		var p0 = rk.global_position
		var tw = rk.create_tween()
		tw.tween_method(func(tt: float):
			if is_instance_valid(rk):
				rk.global_position = p0 + vel * tt + Vector3(0, -7.0 * tt * tt, 0)
				rk.rotation += Vector3(0.25, 0.18, 0.1), 0.0, 0.9, 0.9)
		tw.tween_callback(rk.queue_free)
	var s = -1.0 if randf() < 0.5 else 1.0
	L.mist(pj, g + side * s * 2.2 + Vector3.UP * 0.8, randf_range(2.2, 3.2), 1.4, {"tone": 3.0, "alpha": 0.55, "drift": side * s * 1.2 + Vector3.UP * 0.6, "s0": 0.4, "near": 5.0})
	L.spray(pj, g + Vector3.UP * 0.3, Vector3.UP, {"n": 6, "spread": 45.0, "vmin": 2.5, "vmax": 5.0, "life": 0.5, "smin": 0.18, "smax": 0.3, "foam": 0.5})


# ================================================================== 14. Ukojizai — yağmurdaki çakrayla avlanan damlalar
## Ref (Hidan / Pain'in yağmuru): kurşuni gök, ince gri yağmur çizgileri; atan kollarını göğe kaldırır.
## Alanın üstünde koyu bulut tavanı toplanır, yoğun ince gri yağmur iner, zemin ıslanıp halka halka kabarır;
## yağmurdaki çakra hedefi bulur: hedefin tepesinden parlak, iri bir damla bir anda iner, değince yıldız gibi dağılır.
static func ukojizai_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(c.global_position + pj.fwd(c, t) * 8.0)
	_gloom_rain(pj, at, 12.0, 4.0)
	_rain_hits(pj, c, at, 12.0, 4.0, "ukojizai_no_jutsu", 0.0)
	pj.every(4.0, 0.4, func(_i, _k):
		for e in pj.enemies_near(c, at, 12.0):
			if pj.live(e):
				_seeker_drop(pj, e)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "ukojizai_no_jutsu", 0.3, {"knock": 1.0, "kind": "light", "element": "suiton"})), Callable())
	Sfx.play("water", at, 0.6)


static func _rain_line_mesh() -> ArrayMesh:
	return _c("rain_line", func():
		return L.tube_mesh([Vector3(0, -0.7, 0), Vector3(0, 0.7, 0)], [0.012, 0.012], 4))


static func _gloom_rain(pj: PathJutsu, at: Vector3, r: float, dur: float) -> void:
	for k in 9:
		var q = at + Vector3(randf_range(-r, r) * 0.8, 16.0 + randf_range(-1.0, 1.5), randf_range(-r, r) * 0.8)
		L.mist(pj, q, randf_range(8.0, 11.0), dur + 0.8, {"tone": 2.0, "alpha": 0.75, "drift": Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), "s0": 0.6, "fin": 0.15, "fout": 0.25, "near": 6.0})
	var p = L.particles({"n": 260, "life": 0.8, "dir": Vector3.DOWN, "spread": 1.5, "vmin": 21.0, "vmax": 25.0, "g": Vector3(0, -8, 0), "smin": 0.8, "smax": 1.2,
		"mesh": _rain_line_mesh(), "one_shot": false, "burst": 0.0, "pal": L.FROST, "alpha": 0.55, "line": 0.0, "foam": 0.0, "streak": 0.0})
	var pm = p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r, 0.5, r)
	p.visibility_aabb = AABB(Vector3(-r - 3, -22, -r - 3), Vector3(r * 2 + 6, 26, r * 2 + 6))
	L.put(pj, p, at + Vector3.UP * 16.0)
	p.emitting = true
	pj.free_after(dur + 1.2, p)
	pj.after(dur, func():
		if is_instance_valid(p):
			p.emitting = false)
	L.big_puddle(pj, at, r, dur, {"alpha": 0.32, "ripple": 1.0, "spread": dur * 0.5, "s0": 0.3, "neard": 6.0})
	pj.every(dur, 0.08, func(_i, _k):
		var q = at + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
		L.ripple(pj, q, 0.05, 0.35, 0.35, {"foam": 1.0, "alpha": 0.55}), Callable())


## Çakralı damla: hedefin 10 m üstünden 0.18 sn'de iner (parlak iri damla + kısa iz), değince yıldız gibi dağılır
static func _seeker_drop(pj: PathJutsu, e: Node3D) -> void:
	var head = Node3D.new()
	pj.scene_add(head, e.global_position + Vector3.UP * 10.0)
	var dr = L.wmi(L.drop_mesh(), {"pal": L.FROST, "alpha": 1.0, "foam": 0.5, "line": 0.15, "streak": 3.0, "flow": 6.0})
	dr.scale = Vector3.ONE * 1.5
	dr.rotation.x = -PI * 0.5   # yuvarlak ön (-Z) aşağı
	head.add_child(dr)
	L.trail(head, {"n": 12, "life": 0.25, "spread": 4.0, "vmin": 0.2, "vmax": 0.6, "smin": 0.1, "smax": 0.18, "dir": Vector3.UP, "g": Vector3.ZERO, "pal": L.FROST, "foam": 0.4})
	var goal = e.global_position + Vector3.UP * 1.2
	var tw = head.create_tween()
	tw.tween_property(head, "global_position", goal, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		L.spray(pj, head.global_position, Vector3.UP, {"n": 12, "spread": 180.0, "vmin": 2.5, "vmax": 5.0, "life": 0.35, "smin": 0.1, "smax": 0.2, "pal": L.FROST, "foam": 0.6, "g": Vector3(0, -8, 0)})
		for ch in head.get_children():
			if ch is GPUParticles3D:
				ch.emitting = false
				ch.reparent(pj.get_tree().current_scene)
				pj.free_after(0.5, ch)
		head.queue_free())


# ================================================================== 15. Mizuame Teppō — yapışkan şurup mermileri
## Ağız önünde amber şurup toplanır; üç ağır, sallantılı şurup topağı ardında sünen şurup teli ve yavaş damlalarla uçar.
## Değdiği yerde kalın amber şurup göleti (yavaşlatır), hedefin bedeninden aşağı süzülen koyu şurup damlaları (bağlı kaldığı sürece).
static func mizuame_teppo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.7)
	var from = pj._mouth_pos(c)
	L.gather(pj, from + c.face_dir() * 0.3, 0.9, 10, 0.3, 0.32, L.SYRUP)
	for k in 3:
		pj.after(0.12 + k * 0.14, func():
			if not pj.live(c):
				return
			var blob = Node3D.new()
			var gl = L.wmi(_syrup_glob_mesh(), {"pal": L.SYRUP, "alpha": 0.96, "wob": 1.6, "line": 0.17, "foam": 0.06, "streak": 0.8, "flow": 1.0, "neard": 2.5})
			blob.add_child(gl)
			var str_ = L.wmi(L.strand_mesh(), {"pal": L.SYRUP, "alpha": 0.9, "wob": 1.2, "line": 0.15, "neard": 2.5})
			str_.rotation.y = PI   # tel arkaya (+Z) uzanır
			str_.scale = Vector3(1.1, 1.1, 1.6)
			blob.add_child(str_)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 24.0, blob, pj.inf(c, "mizuame_teppo", 0.25, {"knock": 2.0, "kind": "light", "element": "suiton"}), null, false, 1.2, func(p, h):
				_syrup_pool(pj, c, p)
				if h and pj.live(h):
					pj.st(h, "bind", 2.0)
					_syrup_coat(pj, h))
			L.trail(pr, {"n": 10, "life": 0.6, "spread": 15.0, "vmin": 0.2, "vmax": 0.6, "smin": 0.16, "smax": 0.26, "g": Vector3(0, -7, 0), "dir": Vector3(0, -0.4, 1), "pal": L.SYRUP, "wob": 1.0, "line": 0.15}))
	Sfx.play("water", from, 0.9)


## Şurup topağı: yuvarlak ön (-Z), arkaya sarkan kalın kuyruk (gerçek boy ~0.35 m yarıçap)
static func _syrup_glob_mesh() -> ArrayMesh:
	return _c("syrup_glob", func():
		var prof = [[-0.36, 0.0], [-0.3, 0.2], [-0.15, 0.32], [0.05, 0.33], [0.25, 0.26], [0.45, 0.17], [0.65, 0.1], [0.82, 0.06], [0.95, 0.0]]
		var pts = []
		var rad = []
		for p in prof:
			pts.append(Vector3(0, -0.04 * float(p[0]) * float(p[0]), float(p[0])))
			rad.append(float(p[1]))
		return L.tube_mesh(pts, rad, 14))


## Şurup göleti + eski yağ göletinin oynanışı (4 sn, 0.45 sn'de bir 2 m içindekilere 1 sn yavaşlatma)
static func _syrup_pool(pj: PathJutsu, c: Node3D, p: Vector3) -> void:
	var at = pj.gp(p)
	L.spray(pj, p, Vector3.UP, {"n": 14, "spread": 100.0, "vmin": 1.5, "vmax": 3.5, "life": 0.6, "smin": 0.2, "smax": 0.34, "g": Vector3(0, -10, 0), "pal": L.SYRUP, "wob": 1.0, "line": 0.15})
	L.big_puddle(pj, at, 2.0, 4.0, {"pal": L.SYRUP, "alpha": 0.85, "ripple": 0.0, "foam": 0.05, "spread": 0.5, "s0": 0.3})
	var glob = L.wmi(_c("syrup_mound", func():
		var m = SphereMesh.new()
		m.radius = 0.6
		m.height = 0.6
		m.is_hemisphere = true
		m.radial_segments = 18
		m.rings = 6
		return m), {"pal": L.SYRUP, "alpha": 0.95, "wob": 1.8, "line": 0.15, "foam": 0.05})
	L.put(pj, glob, at)
	var tw = glob.create_tween()
	tw.tween_property(glob, "scale", Vector3(1.4, 0.35, 1.4), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(glob, "scale", Vector3(1.6, 0.05, 1.6), 0.6)
	tw.parallel().tween_method(func(v: float): glob.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6)
	tw.tween_callback(glob.queue_free)
	pj.every(4.0, 0.15, func(i, _k):
		if i % 3 == 0:
			for e in pj.enemies_near(c, at, 2.0):
				pj.st(e, "slow", 1.0), Callable())


## Hedefin bedeninden aşağı süzülen şurup damlaları (bağlı kaldığı 2 sn)
static func _syrup_coat(pj: PathJutsu, h: Node3D) -> void:
	var n = Node3D.new()
	h.add_child(n)
	n.position = Vector3(0, 1.3, 0)
	L.trail(n, {"n": 10, "life": 0.6, "spread": 25.0, "vmin": 0.1, "vmax": 0.4, "smin": 0.14, "smax": 0.24, "g": Vector3(0, -5, 0), "dir": Vector3.DOWN, "r": 0.3,
		"pal": L.SYRUP, "wob": 1.0, "line": 0.15})
	pj.free_after(2.0, n)
