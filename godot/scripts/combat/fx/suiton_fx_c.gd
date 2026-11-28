class_name SuitonFXC
extends RefCounted
## Suiton grubu C: on beş su tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları SuitonLib'den
## (kendi su gölgelendiricisi, damla, birikinti, sis, sabun zarı); her tekniğin şekli, hareketi ve sahnelenmesi kendine özgü.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) eski işleyicilerden satır satır taşındı.
## Sıçramalar sıvı (yuvarlak diller), buz kırığı değil; kameraya yakın su gölgelendiricide incelir (ekranı kaplamaz).

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


static func _glow_mat(col: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.albedo_color = col
	return m


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


## Gökkuşağı zarlı kabarcık kabuğu (kütüphanenin zar gölgelendiricisi)
static func _film(size: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = L.sphere_mesh()
	mi.material_override = L.bubble_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.scale = Vector3.ONE * size
	return mi


static func _fade_out(gi: GeometryInstance3D, t: float) -> void:
	var tw = gi.create_tween()
	tw.tween_method(func(v: float): gi.set_instance_shader_parameter("fade", v), 1.0, 0.0, t)


# ================================================================== 1. Bakusui Shōha — sel dağı, alan denize döner
## Ref (Kisame): ağızda dev su toplanır, öne-aşağı kalın bir sel boşalır; düştüğü yerde üst üste üç köpüklü kat ve
## katların altından perde perde dökülen su (sel dağı). Halka duvar dalgalar dışa koşar, alan 6 sn boyunca deniz olur;
## deniz yüzeyinde kabaran halkalar ve küçük taçlar. Kameraya yakın kısımlar gölgelendiricide incelir.
static func suiton_bakusui_shoha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var d = pj.fwd(c, t)
	L.gather(pj, pj._mouth_pos(c), 2.0, 18, 0.3, 0.55)
	pj.after(0.3, func():
		var lake_c = pj.gp(c.global_position + d * 10.0)
		var fall_at = pj.gp(c.global_position + d * 3.2)
		_flood_gush(pj, pj._mouth_pos(c), d, fall_at)
		_flood_tiers(pj, fall_at)
		_flood_sea(pj, lake_c, fall_at)
		pj.every(1.2, 0.2, func(_i, _k):
			if not is_instance_valid(c):   # atan bu arada öldü / silindi
				return
			Combat.hit_zone(c, c.global_position, d, 22.0, 35.0, 4.0, pj.inf(c, "suiton_bakusui_shoha", 0.35, {"knock": 14.0, "kind": "heavy", "element": "suiton", "dir": d})), Callable())
		pj.every(7.0, 0.5, func(i, _k):
			if not is_instance_valid(c):
				return
			for e in pj.enemies_near(c, pj.gp(c.global_position + d * 10.0), 14.0):
				pj.st(e, "slow", 0.8)
			_flood_swell(pj, lake_c, i), Callable())
		pj.shake(1.0))
	Sfx.play("water", c.global_position, 0.3)


## Ağızdan öne-aşağı boşalan kalın sel: ağızda ince, yere vardıkça kalınlaşır; uzar, nabız atar, sonra incelip kopar
static func _flood_gush(pj: PathJutsu, mo: Vector3, d: Vector3, fall_at: Vector3) -> void:
	var mi = L.wmi(null, {"alpha": 0.92, "foam": 0.0, "flow": 3.5, "streak": 2.2, "wob": 1.2, "line": 0.1, "neard": 6.0})
	L.put(pj, mi, Vector3.ZERO)
	var p1 = mo + d * 1.8 + Vector3.UP * 0.2
	var p2 = fall_at + Vector3.UP * 0.4
	var tw = mi.create_tween()
	tw.tween_method(func(k: float):
		var reach = clampf(k / 0.18, 0.05, 1.0)
		var thin = maxf(0.08, clampf((1.0 - k) / 0.3, 0.0, 1.0))
		var pulse = 1.0 + 0.12 * sin(k * 40.0)
		var pts = []
		var rad = []
		for i in 14:
			var u = reach * i / 13.0
			var a = mo.lerp(p1, u)
			var b = p1.lerp(p2, u)
			pts.append(a.lerp(b, u))
			rad.append((0.28 + 1.3 * u * u) * pulse * thin)
		mi.mesh = L.tube_mesh(pts, rad, 14), 0.0, 1.0, 1.15)
	tw.tween_callback(mi.queue_free)
	L.spray(pj, mo, d - Vector3.UP * 0.35, {"n": 40, "burst": 0.0, "life": 1.0, "spread": 16.0, "vmin": 6.0, "vmax": 10.0, "smin": 0.3, "smax": 0.6, "foam": 0.5})


## Sel dağı: üç kat (yukarıdan aşağı genişler); her kat yuvarlak, kalın, kabaran bir su rulosu + kenarında küçük
## yuvarlak sıvı dilleri, altından yere dökülen ince perde. Büyük sivri taç yok (dev ölçekte kırık cam gibi görünüyordu).
static func _flood_tiers(pj: PathJutsu, at: Vector3) -> void:
	var tiers = [[3.4, 2.4], [2.0, 4.3], [0.6, 6.6]]
	for k in tiers.size():
		var y = float(tiers[k][0])
		var s = float(tiers[k][1])
		pj.after(0.06 + k * 0.1, func():
			var top = at + Vector3.UP * y
			var roll = L.wmi(_roll_ring_mesh(k, s), {"alpha": 0.9, "foam": 0.0, "streak": 1.2, "flow": 2.0, "wob": 1.4, "line": 0.12, "neard": 7.0})
			L.put(pj, roll, top)
			roll.rotation.y = randf() * TAU
			roll.scale = Vector3.ONE * 0.35
			var tr = roll.create_tween()
			tr.tween_property(roll, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tr.tween_interval(0.8)
			tr.tween_property(roll, "scale", Vector3(1.12, 0.3, 1.12), 0.7).set_ease(Tween.EASE_IN)
			tr.parallel().tween_method(func(v: float): roll.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.7)
			tr.tween_callback(roll.queue_free)
			var nb = 5 + k * 3
			for j in nb:
				var a = j * TAU / nb + randf() * 0.3
				var q = top + Vector3(cos(a), 0.15, sin(a)) * s
				pj.after(0.12 + randf() * 0.25, func():
					L.crown(pj, q, randf_range(0.7, 1.1), {"h": 0.8, "t": 0.18, "fall": 0.45, "foam": 0.2, "alpha": 0.9}))
			var cur = L.wmi(L.fall_mesh(), {"alpha": 0.32, "streak": 2.0, "flow": 2.6, "foam": 0.0, "line": 0.06, "wob": 0.6, "neard": 7.0})
			L.put(pj, cur, top)
			cur.scale = Vector3(s * 0.5, 0.05, s * 0.5)
			var tw = cur.create_tween()
			tw.tween_property(cur, "scale", Vector3(s * 0.5, y + 0.2, s * 0.5), 0.3).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.9)
			tw.tween_method(func(v: float): cur.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6)
			tw.tween_callback(cur.queue_free)
			L.spray(pj, top, Vector3.UP, {"n": 26, "spread": 85.0, "vmin": 3.0, "vmax": 7.0, "life": 0.9, "smin": 0.25, "smax": 0.5, "r": s * 0.6, "foam": 0.4}))


## Kat rulosu: s yarıçaplı çember boyunca kalın, yuvarlak kesitli, boğum boğum kabaran su halkası (gerçek ölçüde
## kurulur; düzgün ölçeklenince kesit yuvarlak kalır)
static func _roll_ring_mesh(k: int, s: float) -> ArrayMesh:
	return _c("roll_%d" % k, func():
		var pts = []
		var rad = []
		var n = 40 + k * 12
		var rc = 0.4 + 0.08 * s
		for i in n + 1:
			var a = i * TAU / n
			var lump = 1.0 + 0.22 * sin(a * (6.0 + k * 2.0)) + 0.12 * sin(a * 13.0 + k)
			pts.append(Vector3(cos(a) * s, rc * 0.4 * lump, sin(a) * s))
			rad.append(rc * lump)
		return L.tube_mesh(pts, rad, 12))


## Deniz: 14 m yarıçaplı alçak su yüzeyi (0.35 m; kamera hep üstünde), selin düştüğü yerde çalkantı, dışa koşan iki
## yuvarlak dalga rulosu. Büyük yüzeylerde köpük lekesi yok (ölçekle birlikte dev beyaz lekeye dönüşüyordu).
static func _flood_sea(pj: PathJutsu, lake_c: Vector3, fall_at: Vector3) -> void:
	L.puddle(pj, lake_c, 14.0, 6.0, {"spread": 0.9, "alpha": 0.8, "ripple": 0.45, "lift": 0.35, "foam": 0.0})
	L.puddle(pj, fall_at, 5.5, 5.0, {"spread": 0.5, "alpha": 0.5, "ripple": 0.9, "lift": 0.42, "foam": 0.0})
	for k in 2:
		pj.after(k * 0.35, func(): _flood_crest(pj, fall_at, 1.0 - k * 0.4))


## Yayılan sel dalgası: alçak (en çok ~0.9 m), yuvarlak kesitli su rulosu + üstünde ince beyaz köpük kıvrımı; her
## karede gerçek yarıçapla yeniden kurulur (kesit gerilmez), dışa koşarken alçalıp söner; kameraya 7 m'den yakını incelir
static func _flood_crest(pj: PathJutsu, at: Vector3, amp: float) -> void:
	var body = L.wmi(null, {"alpha": 0.88, "foam": 0.0, "streak": 1.4, "flow": 2.0, "wob": 1.0, "line": 0.12, "neard": 7.0})
	var rim = L.wmi(null, {"alpha": 0.9, "foam": 0.9, "streak": 0.6, "flow": 1.5, "wob": 0.8, "line": 0.06, "neard": 7.0})
	var g = L.ground(at)
	L.put(pj, body, g)
	L.put(pj, rim, g)
	var ph = randf() * TAU
	var tw = body.create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(rim):
			return
		var e = 1.0 - pow(1.0 - k, 3.0)
		var rad_r = lerpf(1.5, 16.0, e)
		var h = amp * lerpf(0.9, 0.3, e)
		var n = 56
		var bp = []
		var br = []
		var rp = []
		var rr = []
		for i in n + 1:
			var a = i * TAU / n
			var w = 1.0 + 0.2 * sin(a * 5.0 + ph) + 0.1 * sin(a * 11.0 + ph * 2.0)
			var hc = h * 0.5 * w
			var dirv = Vector3(cos(a), 0, sin(a))
			bp.append(dirv * rad_r + Vector3.UP * (0.3 + hc * 0.8))
			br.append(hc)
			rp.append(dirv * (rad_r + hc * 0.35) + Vector3.UP * (0.3 + hc * 1.75))
			rr.append(maxf(0.04, hc * 0.28))
		body.mesh = L.tube_mesh(bp, br, 10)
		rim.mesh = L.tube_mesh(rp, rr, 6)
		var f = clampf((1.0 - k) / 0.45, 0.0, 1.0)
		body.set_instance_shader_parameter("fade", f)
		rim.set_instance_shader_parameter("fade", f), 0.0, 1.0, 1.3)
	tw.tween_callback(func():
		if is_instance_valid(rim):
			rim.queue_free()
		body.queue_free())


## Deniz yüzeyinde kabaran halkalar, arada bir küçük sıvı taç (yalnız denizin ömrü boyunca)
static func _flood_swell(pj: PathJutsu, lake_c: Vector3, i: int) -> void:
	if i >= 12:
		return
	var q = lake_c + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.0, 11.0)
	var rp = L.ripple(pj, q, 0.5, randf_range(2.0, 3.5), 1.0, {"foam": 0.8, "alpha": 0.6})
	rp.global_position.y += 0.34
	if i % 3 == 1:
		L.crown(pj, L.ground(q) + Vector3.UP * 0.32, randf_range(0.7, 1.1), {"h": 0.6, "foam": 0.6, "fall": 0.5})


# ================================================================== 2. Suigadan — burgulu su dişleri
## Ref: su yüzeyinde iç içe halkalar ve dönerek fışkıran sivri su dişi. Hedefin çevresinde altı noktada yer
## girdaplanır (içe çekilen halkalar), dişler dönerek yerden fırlayıp ortada buluşur; buluştukları yerde
## yukarı-aşağı açılan sıvı dil çiçeği, yerde halka dalga ve ıslak iz kalır.
static func suiton_suigadan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.8)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	for k in 6:
		var a = k * TAU / 6.0
		var q = at + Vector3(cos(a), 0, sin(a)) * 3.0
		_fang_well(pj, q)
		pj.after(0.2 + k * 0.03, func(): _fang_rise(pj, q, at + Vector3.UP))
	pj.after(0.45, func():
		_fang_bloom(pj, at + Vector3.UP)
		pj.hit(c, at + Vector3.UP, 2.4, pj.inf(c, "suiton_suigadan", 1.5, {"knock": 6.0, "launch": 6.0, "kind": "heavy", "element": "suiton", "bleed": 2.0})))
	Sfx.play("water", at, 0.8)


## Fışkırma öncesi: yerde dönen koyu girdap ve içe çekilen köpük halkaları
static func _fang_well(pj: PathJutsu, q: Vector3) -> void:
	L.puddle(pj, q, 1.0, 0.45, {"alpha": 0.6, "ripple": 1.0, "spread": 0.15, "foam": 0.1})
	for j in 3:
		L.ripple(pj, q, 1.6 - j * 0.35, 0.25, 0.22 + j * 0.05, {"foam": 1.0, "alpha": 0.75})


## Burgulu su dişi: yerden kendi ekseninde dönerek fırlar, dibinde sıvı taç; geride damla izi bırakır
static func _fang_rise(pj: PathJutsu, q: Vector3, goal: Vector3) -> void:
	var dir = (goal - q).normalized()
	var piv = Node3D.new()
	L.put(pj, piv, q - dir * 0.6)
	_aim(piv, dir)
	var sp = L.wmi(L.spike_mesh(), {"alpha": 0.93, "streak": 2.6, "flow": 4.0, "foam": 0.18, "line": 0.12, "wob": 0.4})
	sp.scale = Vector3(1.25, 1.25, 1.0)
	piv.add_child(sp)
	var tws = sp.create_tween()
	tws.tween_property(sp, "rotation:z", TAU * 1.5, 0.3).from(0.0)
	var tw = piv.create_tween()
	tw.tween_property(piv, "global_position", goal, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(piv.queue_free)
	L.trail(piv, {"n": 14, "life": 0.35, "spread": 25.0, "vmin": 1.0, "vmax": 3.0, "smin": 0.15, "smax": 0.3, "g": Vector3(0, -12, 0), "foam": 0.3})
	L.crown(pj, q, 0.9, {"h": 1.0, "t": 0.12, "fall": 0.4, "foam": 0.45})
	L.spray(pj, q, Vector3.UP + dir * 0.4, {"n": 14, "spread": 30.0, "vmin": 3.0, "vmax": 6.5, "life": 0.6, "smin": 0.18, "smax": 0.35, "foam": 0.35})


## Altı diş ortada buluşur: yukarı ve aşağı açılan sıvı dil çiçeği, halka dalga, kalıcı ıslak iz
static func _fang_bloom(pj: PathJutsu, p: Vector3) -> void:
	L.crown(pj, p, 1.6, {"h": 1.5, "t": 0.12, "fall": 0.5, "foam": 0.5})
	var dn = L.crown(pj, p, 1.3, {"h": 1.1, "t": 0.12, "fall": 0.45, "foam": 0.35})
	dn.rotation.x = PI
	L.spray(pj, p, Vector3.UP, {"n": 40, "spread": 180.0, "vmin": 4.0, "vmax": 9.0, "life": 0.75, "smin": 0.18, "smax": 0.4, "foam": 0.45, "r": 0.4})
	var g = L.ground(p)
	L.ripple(pj, g, 0.6, 4.6, 0.6, {"foam": 1.0})
	L.puddle(pj, g, 2.6, 2.5, {"alpha": 0.6, "ripple": 0.4})


# ================================================================== 3. Hahonryū — avuçtan burgu akıntı
## Ref: avucu ve bileği saran dönen su sarmalı. Hazırlıkta iki sarmal şerit kolun çevresinde dönüp avuca sıkışır;
## salınımda önde sivrilen, arkada açılan üç kollu dönen burgu (saydam akış çekirdeğiyle) delip geçer, damla izi bırakır.
## Çarpınca damlalar sarmal savrulur, ileri koni sıçrar, yerde akış yönünde uzamış ıslak iz.
static func suiton_hahonryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 24.0)
	var from = pj.hand_pos(c, true)
	_palm_vortex(pj, from, pj.aim_at(c, tt, from))
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var dir = pj.aim_at(c, tt, from)
		var pr = pj.shot(c, from, dir, 34.0, _torrent_drill(), pj.inf(c, "suiton_hahonryu", 1.3, {"knock": 14.0, "kind": "heavy", "element": "suiton"}), null, true, 1.0, func(p, _h):
			_torrent_burst(pj, p, dir))
		pr.radius = 0.9
		L.trail(pr, {"n": 34, "life": 0.45, "spread": 28.0, "vmin": 1.5, "vmax": 4.5, "smin": 0.22, "smax": 0.42, "g": Vector3(0, -6, 0), "foam": 0.35, "r": 0.5}))
	Sfx.play("water", from, 1.0)


## Hazırlık: el ve bilek çevresinde iki sarmal şerit hızla döner ve avuca doğru sıkışır
static func _palm_vortex(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	L.gather(pj, at, 1.2, 12, 0.25, 0.25)
	var piv = Node3D.new()
	L.put(pj, piv, at)
	_aim(piv, d)
	var tilt = Node3D.new()
	tilt.rotation.x = -PI * 0.5   # sarmalın +Y ekseni ileri (-Z)
	tilt.position = Vector3(0, 0, 0.8)   # bileğin gerisinden başlar
	piv.add_child(tilt)
	var spin = Node3D.new()
	tilt.add_child(spin)
	for j in 2:
		spin.add_child(L.wmi(L.helix_mesh(0.42, 0.9, 2.2, 0.09, j * PI), {"alpha": 0.85, "streak": 2.0, "flow": 4.0, "foam": 0.3, "line": 0.12}))
	var tw = spin.create_tween().set_parallel(true)
	tw.tween_property(spin, "rotation:y", TAU * 2.5, 0.3).from(0.0)
	tw.tween_property(spin, "scale", Vector3(0.35, 1.2, 0.35), 0.3).from(Vector3(1.3, 0.6, 1.3)).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(piv.queue_free)


## Mermi gövdesi: önde sivrilen üç kollu burgu + arkaya açılan saydam akış çekirdeği, sürekli döner
static func _torrent_drill() -> Node3D:
	var root = Node3D.new()
	var tilt = Node3D.new()
	tilt.rotation.x = -PI * 0.5
	root.add_child(tilt)
	var spin = Node3D.new()
	spin.position = Vector3(0, -2.6, 0)
	tilt.add_child(spin)
	for j in 3:
		spin.add_child(L.wmi(_drill_mesh(j), {"alpha": 0.92, "streak": 2.4, "flow": 5.0, "foam": 0.35, "line": 0.12, "wob": 0.5}))
	var core = L.wmi(L.stream_mesh(), {"alpha": 0.5, "streak": 3.0, "flow": 6.0, "foam": 0.1, "line": 0.06})
	core.rotation.y = PI   # dar ağız önde, geniş kuyruk arkada
	core.scale = Vector3(0.75, 0.75, 2.8)
	root.add_child(core)
	var tw = Game.safe_loops(spin.create_tween())
	tw.tween_property(spin, "rotation:y", TAU, 0.22).from(0.0)
	return root


## Burgu kolu: Y boyunca (arka 0 → ön 2.7) daralan sarmal şerit
static func _drill_mesh(j: int) -> ArrayMesh:
	return _c("drill_%d" % j, func():
		var pts = []
		var rad = []
		var n = 30
		for i in n:
			var u = float(i) / (n - 1)
			var a = j * TAU / 3.0 + u * 1.7 * TAU
			var rr = lerpf(0.95, 0.1, pow(u, 0.8))
			pts.append(Vector3(cos(a) * rr, u * 2.7, sin(a) * rr))
			rad.append(0.16 * pow(maxf(0.0, sin(PI * clampf(u * 1.05, 0.0, 1.0))), 0.5) + 0.02)
		return L.tube_mesh(pts, rad, 6, 0.4, Vector3.UP))


## Çarpma: akıntı hedefte burgu gibi açılır — sarmal savrulan damlalar + ileri koni sıçrama + uzamış ıslak iz
static func _torrent_burst(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var upv = side.cross(d).normalized()
	for i in 10:
		var a = i * TAU / 10.0
		var radial = side * cos(a) + upv * sin(a)
		var tang = side * -sin(a) + upv * cos(a)
		var vdir = (radial + tang * 0.9 + d * 0.5).normalized()
		var drop = L.wmi(L.drop_mesh(), {"alpha": 0.9, "foam": 0.3, "line": 0.12, "flow": 3.0})
		L.put(pj, drop, p + radial * 0.3)
		_aim(drop, vdir)
		drop.scale = Vector3.ONE * randf_range(0.5, 0.8)
		var tw = drop.create_tween().set_parallel(true)
		tw.tween_property(drop, "global_position", p + vdir * randf_range(2.0, 3.2) + Vector3.DOWN * 0.6, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "scale", Vector3.ONE * 0.05, 0.35).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(drop.queue_free)
	L.spray(pj, p, d, {"n": 30, "spread": 35.0, "vmin": 5.0, "vmax": 11.0, "life": 0.6, "smin": 0.2, "smax": 0.4, "foam": 0.4, "r": 0.5})
	var g = L.ground(p)
	if p.y - g.y < 2.5:
		L.puddle(pj, g, 1.8, 1.5, {"dir": d, "stretch": 1.8, "alpha": 0.55, "ripple": 0.3})


# ================================================================== 4. Suijinchū — hedefin altından su sütunu
## Ref: savrulan dev su kütlesi. Önce hedefin altında yer kabarır (içe çekilen halka + şişen su kubbesi), sonra
## 12 m'lik burulmuş, dalgalı su sütunu fışkırır; tepesinde taç ve aşağı sarkan dil şemsiyesi, sütunun çevresine
## dökülen su perdesi ve geri yağan damlalar. Sütun yere çöker, dibinde büyük taç, halka dalga ve göl kalır.
static func suiton_suijinchu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.8)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	_pillar_bulge(pj, at)
	pj.after(0.2, func():
		_pillar_erupt(pj, at)
		pj.hit(c, at + Vector3.UP, 3.0, pj.inf(c, "suiton_suijinchu", 1.4, {"knock": 3.0, "launch": 20.0, "kind": "heavy", "element": "suiton"}))
		pj.shake(0.6))
	Sfx.play("water", at, 0.6)


static func _pillar_bulge(pj: PathJutsu, at: Vector3) -> void:
	L.ripple(pj, at, 4.2, 0.8, 0.22, {"foam": 0.9, "alpha": 0.8})
	L.puddle(pj, at, 3.0, 1.4, {"alpha": 0.6, "ripple": 0.8, "spread": 0.2})
	var dome = L.wmi(L.sphere_mesh(), {"alpha": 0.85, "foam": 0.2, "wob": 1.6, "line": 0.1, "flow": 2.0})
	L.put(pj, dome, at)
	dome.scale = Vector3(3.4, 0.05, 3.4)
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3(2.6, 1.2, 2.6), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(dome.queue_free)


static func _pillar_erupt(pj: PathJutsu, at: Vector3) -> void:
	var col = L.wmi(_pillar_mesh(), {"alpha": 0.9, "streak": 3.2, "flow": 4.5, "foam": 0.25, "wob": 1.3, "line": 0.1})
	L.put(pj, col, at)
	col.scale = Vector3(1, 0.02, 1)
	var tw = col.create_tween()
	tw.tween_property(col, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(col, "scale", Vector3(0.35, 0.02, 0.35), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(col.queue_free)
	var tr = col.create_tween()
	tr.tween_property(col, "rotation:y", 1.4, 1.3).from(0.0)
	L.crown(pj, at, 2.8, {"h": 0.55, "t": 0.15, "fall": 0.6, "foam": 0.5})
	L.spray(pj, at, Vector3.UP, {"n": 24, "spread": 40.0, "vmin": 4.0, "vmax": 8.0, "life": 0.7, "smin": 0.3, "smax": 0.55, "r": 1.6, "foam": 0.5})
	pj.after(0.18, func():
		var top = at + Vector3.UP * 11.6
		L.crown(pj, top, 3.0, {"h": 0.8, "t": 0.18, "fall": 0.9, "foam": 0.75})
		var hood = L.crown(pj, top, 2.6, {"h": 0.9, "t": 0.18, "fall": 0.8, "foam": 0.5})
		hood.rotation.x = PI
		L.spray(pj, top, Vector3.UP, {"n": 46, "spread": 70.0, "vmin": 4.0, "vmax": 9.0, "life": 1.5, "smin": 0.3, "smax": 0.6, "r": 1.4, "foam": 0.55, "g": Vector3(0, -14, 0)})
		var skirt = L.wmi(L.fall_mesh(), {"alpha": 0.4, "streak": 3.0, "flow": 3.0, "foam": 0.1, "line": 0.06})
		L.put(pj, skirt, top)
		skirt.scale = Vector3(1.9, 0.05, 1.9)
		var ts = skirt.create_tween()
		ts.tween_property(skirt, "scale", Vector3(1.9, 11.4, 1.9), 0.45).set_ease(Tween.EASE_IN)
		ts.tween_method(func(v: float): skirt.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5)
		ts.tween_callback(skirt.queue_free))
	pj.after(1.2, func():
		L.crown(pj, at, 3.6, {"h": 0.4, "t": 0.2, "fall": 0.7, "foam": 0.6})
		L.ripple(pj, at, 1.0, 6.5, 0.8, {"foam": 1.0})
		L.puddle(pj, at, 4.5, 2.0, {"alpha": 0.6, "ripple": 0.6}))


## Sütun: 0'dan +Y 12'ye hafif burulmuş, boğumlu su gövdesi; tepesi kapalı
static func _pillar_mesh() -> ArrayMesh:
	return _c("pillar", func():
		var pts = []
		var rad = []
		var n = 26
		for i in n:
			var u = float(i) / (n - 1)
			pts.append(Vector3(sin(u * 5.0) * 0.25, u * 12.0, cos(u * 4.0) * 0.2 - 0.2))
			var r = lerpf(2.2, 1.6, u) * (1.0 + 0.08 * sin(u * 23.0))
			if i == n - 1:
				r = 0.9
			rad.append(r)
		pts.append(Vector3(0, 12.3, 0))
		rad.append(0.0)
		return L.tube_mesh(pts, rad, 22))


# ================================================================== 5. Hatō — yuvarlanan kabaran deniz
## Ref (Boruto): ağızdan öne açılan geniş fışkırma, ince parıltılı damlalar, yerde halka halka izler. Fışkırma yere
## değince dokuz adımda ileri koşan bir dalga olur: her adımda arkadan yükselip tepede öne kıvrılan geniş dudak +
## altında kabaran kütle, öne devrilip çöker; tepeden köpük savrulur, yerde akış yönünde ıslak iz ve yan halkalar.
static func suiton_hato(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	_surge_breath(pj, c, d)
	for k in 9:
		pj.after(k * 0.06, func():
			var q = pj.gp(c.global_position + d * (2.0 + k * 2.0))
			_surge_lip(pj, q, d, k)
			pj.hit(c, q + Vector3.UP, 2.4, pj.inf(c, "suiton_hato", 0.3, {"knock": 6.0, "launch": 9.0, "kind": "heavy", "element": "suiton"})))
	Sfx.play("water", c.global_position, 0.6)


static func _surge_breath(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var mo = pj._mouth_pos(c)
	var aim = (d * 4.0 - Vector3.UP * 1.3).normalized()
	var mi = L.wmi(L.stream_mesh(), {"alpha": 0.7, "streak": 2.8, "flow": 5.0, "foam": 0.0, "line": 0.08, "neard": 5.0})
	L.put(pj, mi, mo)
	_aim(mi, aim)
	mi.scale = Vector3(0.6, 0.6, 0.3)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(2.4, 1.6, 4.2), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	L.spray(pj, mo, aim, {"n": 36, "burst": 0.2, "life": 0.55, "spread": 16.0, "vmin": 9.0, "vmax": 15.0, "smin": 0.14, "smax": 0.3, "foam": 0.6, "g": Vector3(0, -5, 0)})


## Yuvarlak kıvrılan dalga: kalın yuvarlak gövde rulosu + üst önde kalın kıvrık dudak + önüne sarkan ikinci kıvrım,
## dudak boyunca ince beyaz köpük kenarı; yükselir, öne yuvarlanarak çöker
static func _surge_lip(pj: PathJutsu, q: Vector3, d: Vector3, k: int) -> void:
	var root = Node3D.new()
	L.put(pj, root, q)
	_aim(root, d)
	root.add_child(L.wmi(_wave_body_mesh(k % 3), {"alpha": 0.9, "foam": 0.0, "streak": 1.2, "flow": 2.5, "wob": 1.2, "line": 0.12, "neard": 5.0}))
	root.add_child(L.wmi(_wave_rim_mesh(k % 3), {"alpha": 0.95, "foam": 0.9, "streak": 0.5, "flow": 1.5, "wob": 0.8, "line": 0.06, "neard": 5.0}))
	var hs = 1.0 + k * 0.06
	root.scale = Vector3(1.0, 0.05, 1.0)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.0, hs, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(root, "scale", Vector3(1.1, 0.05, 1.1), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(root, "global_position", q + d * 1.6, 0.35)
	tw.tween_callback(root.queue_free)
	pj.after(0.2, func():
		L.spray(pj, q + Vector3.UP * 2.0 + d * 0.8, d + Vector3.UP * 0.6, {"n": 14, "spread": 50.0, "vmin": 3.0, "vmax": 6.0, "life": 0.6, "smin": 0.2, "smax": 0.4, "r": 1.6, "foam": 0.4}))
	L.puddle(pj, q, 2.4, 1.2, {"dir": d, "stretch": 1.5, "alpha": 0.55, "ripple": 0.25, "spread": 0.2})
	if k % 2 == 1:
		var sd = d.cross(Vector3.UP).normalized() * (3.0 if k % 4 == 1 else -3.0)
		L.ripple(pj, q + sd, 0.3, 1.4, 0.6, {"foam": 0.9, "alpha": 0.6})


## Dalga boyunca (X ekseni, -2.8..2.8) uçları yuvarlak kapanan yatay tüp (y yükseklik, z derinlik, r yarıçap)
static func _wave_tube(sf: SurfaceTool, vc: int, rng: RandomNumberGenerator, y: float, z: float, r: float, wy: float, sides: int, flat := 1.0) -> int:
	var pts = []
	var rad = []
	var n = 14
	var ph = rng.randf() * TAU
	for i in n:
		var u = float(i) / (n - 1)
		var tap = pow(maxf(0.0, sin(PI * u)), 0.35)
		pts.append(Vector3(lerpf(-2.8, 2.8, u), y * (0.85 + 0.15 * tap) + sin(u * 7.0 + ph) * wy, z + sin(u * 5.0 + ph) * 0.08))
		rad.append(r * tap * (1.0 + 0.1 * sin(u * 9.0 + ph)))
	return L.tube_into(sf, vc, pts, rad, sides, flat, Vector3.UP)


## Gövde: arkada kalın yuvarlak kütle + üst önde kıvrık dudak + önde aşağı sarkan ikinci kıvrım (yandan "C" silueti)
static func _wave_body_mesh(v: int) -> ArrayMesh:
	return _c("wave_body_%d" % v, func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 5501 + v * 733
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vc = 0
		vc = _wave_tube(sf, vc, rng, 0.85, 0.25, 0.95, 0.06, 14, 1.15)
		vc = _wave_tube(sf, vc, rng, 1.75, -0.45, 0.48, 0.1, 12)
		vc = _wave_tube(sf, vc, rng, 1.3, -0.95, 0.3, 0.12, 10)
		sf.generate_normals()
		return sf.commit())


## Köpük kenarı: dudağın tepesinde ince, dalgalı beyaz tüp
static func _wave_rim_mesh(v: int) -> ArrayMesh:
	return _c("wave_rim_%d" % v, func():
		var rng = RandomNumberGenerator.new()
		rng.seed = 9901 + v * 377
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		_wave_tube(sf, 0, rng, 2.15, -0.6, 0.15, 0.08, 8)
		sf.generate_normals()
		return sf.commit())


# ================================================================== 6. Ja no Kuchi — koyu sudan yılan ağzı
## Ref: koyu gece mavisi su sütunu, ağzı açık bir baş gibi yükselir. Hedefin altından koyu su boynu fışkırır; iki
## çene (iç kenarında yuvarlak damla dişler, dışında soluk parlayan gözler) açık gelir, hedefi içine alıp kapanır;
## içeride koyu su çalkalanır, kabarcıklar kaçar. Süre bitince çeneler açılıp su yıkılır, baş yere geri çekilir.
static func suiton_ja_no_kuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var maw = _serpent_maw()
	var root: Node3D = maw["root"]
	L.put(pj, root, at - Vector3.UP * 4.0)
	root.look_at(root.global_position + _flat(at - c.global_position), Vector3.UP)
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", at, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(3.2)
	tw.tween_callback(func(): _maw_release(pj, at))
	tw.tween_property(root, "global_position", at - Vector3.UP * 4.0, 0.4)
	tw.tween_callback(root.queue_free)
	for pv in maw["jaws"]:
		var tj = pv.create_tween()
		tj.tween_interval(0.22)
		tj.tween_property(pv, "rotation:z", 0.04, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tj.tween_interval(3.0)
		tj.tween_property(pv, "rotation:z", -0.5, 0.2)
	var churn: MeshInstance3D = maw["churn"]
	churn.scale = Vector3.ONE * 0.05
	var tc = churn.create_tween()
	tc.tween_interval(0.4)
	tc.tween_property(churn, "scale", Vector3(1.6, 2.4, 1.6), 0.2)
	_maw_emerge(pj, at)
	pj.st(tt, "bind", 3.5)
	pj.every(3.5, 0.5, func(_i, _k):
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "suiton_ja_no_kuchi", 0.2, {"knock": 0.0, "kind": "light", "element": "suiton"}))
			L.bubble(pj, at + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3)), 0.16, 0.5, Vector3(0, 1.2, 0)), Callable())
	Sfx.play("water", at, 0.6)


## Yılan başı: koyu su boynu + boğaz, iki menteşeli çene (±X), damla dişler, parlayan gözler, içte çalkantı
static func _serpent_maw() -> Dictionary:
	var root = Node3D.new()
	var o = {"alpha": 0.93, "pal": L.DEEP, "streak": 1.6, "flow": 2.0, "foam": 0.12, "line": 0.14, "wob": 0.9}
	root.add_child(L.wmi(_neck_mesh(), o))
	var throat = L.wmi(L.sphere_mesh(), o)
	throat.scale = Vector3(3.6, 1.0, 2.6)
	throat.position = Vector3(0, 0.15, 0)
	root.add_child(throat)
	var eye_mat = _c("ja_eye", func(): return _glow_mat(Color(0.7, 0.95, 1.0, 0.9)))
	var jaws = []
	for sgn in [1.0, -1.0]:
		var pv = Node3D.new()
		pv.position = Vector3(1.2 * sgn, 0.2, 0)
		pv.rotation = Vector3(0, 0.0 if sgn > 0 else PI, -0.6)   # açık: üst uç dışa yatık
		root.add_child(pv)
		pv.add_child(L.wmi(_jaw_mesh(), o))
		for z in [-0.6, -0.2, 0.2, 0.6]:
			var f = L.wmi(L.drop_mesh(), {"alpha": 0.96, "foam": 1.0, "line": 0.1, "pal": L.DEEP})
			f.basis = Basis.looking_at(-Vector3(-0.5, -1.0, 0.0).normalized(), Vector3.FORWARD)   # ince uç içe-aşağı sarkar
			f.scale = Vector3.ONE * 0.5
			f.position = Vector3(-0.8, 2.6, z)   # çenenin iç yüzeyinde, yarısı gömülü
			pv.add_child(f)
		var eye = MeshInstance3D.new()
		eye.mesh = L.sphere_mesh()
		eye.material_override = eye_mat
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.scale = Vector3(0.14, 0.24, 0.1)
		eye.position = Vector3(0.12, 2.45, 0.75 * sgn)   # iki göz de öne (+Z, kullanana dönük)
		pv.add_child(eye)
		jaws.append(pv)
	var churn = L.wmi(L.sphere_mesh(), {"alpha": 0.35, "pal": L.DEEP, "wob": 2.0, "foam": 0.3, "line": 0.0, "flow": 1.5})
	churn.position = Vector3(0, 1.4, 0)
	root.add_child(churn)
	return {"root": root, "jaws": jaws, "churn": churn}


static func _neck_mesh() -> ArrayMesh:
	return _c("ja_neck", func():
		var pts = []
		var rad = []
		for i in 8:
			var u = i / 7.0
			pts.append(Vector3(sin(u * 3.0) * 0.25, -4.6 + u * 4.8, 0))
			rad.append(lerpf(1.6, 1.85, u) * (1.0 + 0.05 * sin(u * 17.0)))
		return L.tube_mesh(pts, rad, 18, 0.8, Vector3.RIGHT))


## Çene: menteşeden (0) yukarı 3.2 m, derinlikte (Z) geniş, X'te ince kabuk; tepesi içe (-X) kıvrılır
static func _jaw_mesh() -> ArrayMesh:
	return _c("ja_jaw", func():
		var pts = [Vector3(0, 0, 0), Vector3(-0.05, 1.0, 0), Vector3(-0.12, 2.0, 0), Vector3(-0.45, 2.75, 0), Vector3(-0.9, 3.1, 0), Vector3(-1.2, 3.18, 0)]
		var rad = [1.05, 1.25, 1.2, 1.0, 0.6, 0.0]
		return L.tube_mesh(pts, rad, 14, 0.38, Vector3.BACK))


static func _maw_emerge(pj: PathJutsu, at: Vector3) -> void:
	L.crown(pj, at, 2.6, {"h": 0.9, "pal": L.DEEP, "foam": 0.5, "t": 0.2, "fall": 0.6})
	L.puddle(pj, at, 3.2, 3.4, {"pal": L.DEEP, "alpha": 0.75, "ripple": 0.6})
	L.spray(pj, at, Vector3.UP, {"n": 30, "spread": 45.0, "vmin": 4.0, "vmax": 8.0, "life": 0.8, "pal": L.DEEP, "foam": 0.4, "r": 1.4, "smin": 0.25, "smax": 0.45})


static func _maw_release(pj: PathJutsu, at: Vector3) -> void:
	L.crown(pj, at, 2.8, {"h": 0.7, "pal": L.DEEP, "foam": 0.6, "t": 0.15, "fall": 0.55})
	L.spray(pj, at + Vector3.UP * 1.8, Vector3.UP, {"n": 40, "spread": 110.0, "vmin": 3.0, "vmax": 7.0, "life": 0.8, "pal": L.DEEP, "foam": 0.45, "r": 1.0, "smin": 0.25, "smax": 0.45})
	L.ripple(pj, at, 1.0, 5.0, 0.6, {"foam": 1.0, "pal": L.DEEP})


# ================================================================== 7. Suiben (Mizu Muchi) — su kırbacı
## Ref: elden uzanan ince, beyaz parıltılı uzun su kırbacı. Avuçta su toplanır; kırbaç S çizerek hedefe şaklar,
## gergin kalıp dalgalanır ve ucundan bedene üç tur dolanan sarmal bağ olur. Raiton bilen kullanırsa kırbaç
## boyunca titrek mavi şimşek akar (kendi çizdiğimiz kırık çizgi). Hedef yoksa kırbaç önde yay çizip yeri döver.
static func hozuki_mizu_muchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 12.0)
	var d = pj.fwd(c, tt if tt else t)
	var rai = ("raiton" in Game.profile.get("elements", [])) if c is Player else String(c.get("element") if c.get("element") != null else "") == "raiton"
	L.gather(pj, pj.hand_pos(c, true), 0.7, 8, 0.2, 0.14)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		if tt == null or not pj.live(tt):
			_whip_lash(pj, c, d)
			Combat.hit_zone(c, c.global_position, d, 9.0, 14.0, 2.5, pj.inf(c, "hozuki_mizu_muchi", 0.6, {"knock": 8.0, "kind": "heavy", "element": "suiton"}))
			return
		# kırbaç elden hedefe uzanır, bedenine dolanır (sarmal bağ), bağlar
		_whip_bind(pj, c, tt, 2.2)
		var coil = L.wmi(L.helix_mesh(0.5, 1.25, 3.0, 0.075), {"alpha": 0.92, "foam": 0.3, "streak": 2.0, "flow": 3.0, "line": 0.12, "wob": 0.6})
		pj.attach(tt, coil, 2.2, Vector3.UP * 0.35)
		var tcl = coil.create_tween()
		tcl.tween_property(coil, "scale", coil.scale, 0.2).from(coil.scale * Vector3(1.5, 1.0, 1.5)).set_ease(Tween.EASE_OUT)
		L.spray(pj, tt.global_position + Vector3.UP, Vector3.UP, {"n": 18, "spread": 120.0, "vmin": 2.0, "vmax": 4.5, "life": 0.5, "smin": 0.12, "smax": 0.25, "foam": 0.5, "r": 0.5})
		pj.st(tt, "bind", 2.2)
		pj.st(tt, "wet", 6.0)
		tt.take_hit(pj.inf(c, "hozuki_mizu_muchi", 0.5, {"knock": 0.0, "kind": "light", "element": "suiton"}))
		if rai:
			pj.after(0.5, func():
				if not pj.live(tt):
					return
				_whip_current(pj, c, tt, 0.6)
				Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Kırbaçtan şimşek!", Color(0.8, 0.9, 1.0))
				tt.take_hit(pj.inf(c, "hozuki_mizu_muchi", 0.9, {"knock": 0.0, "kind": "heavy", "element": "raiton", "stun": 1.0}))))
	Sfx.play("water", c.global_position, 1.3)


## Kırbaç elden hedefe şaklayarak uzanır (gevşek S yay), sonra gerilip hafifçe dalgalanır; her karede yeniden kurulur
static func _whip_bind(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float) -> void:
	var mi = L.wmi(null, {"alpha": 0.95, "foam": 0.2, "streak": 2.2, "flow": 3.5, "line": 0.14, "wob": 0.3})
	L.put(pj, mi, Vector3.ZERO)
	var sgn = 1.0 if randf() < 0.5 else -1.0
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float):
		if not (is_instance_valid(c) and is_instance_valid(tt)):
			mi.queue_free()
			return
		var a = pj.hand_pos(c, true)
		var b = tt.global_position + Vector3.UP * 1.0
		var reach = clampf(tm / 0.22, 0.05, 1.0)
		var span = b - a
		var side = span.cross(Vector3.UP)
		side = (side.normalized() if side.length() > 0.01 else Vector3.RIGHT) * sgn
		var slack = (1.0 - reach) * 1.4 + 0.25
		var pts = []
		var rad = []
		for i in 26:
			var u = i / 25.0 * reach
			var wave = sin(u * TAU * 1.5 - tm * 9.0) * 0.12 * (1.0 - u) * (1.0 + (1.0 - reach) * 3.0)
			pts.append(a + span * u + Vector3.UP * sin(u * PI) * slack * 0.8 + side * (sin(u * PI) * slack + wave))
			rad.append(lerpf(0.09, 0.06, u))
		mi.mesh = L.tube_mesh(pts, rad, 8), 0.0, dur, dur)
	tw.tween_callback(mi.queue_free)


## Hedef yoksa: kırbaç önde yatay yay çizerek savrulur (ucu geriden gelir), ucu yere vurup sıçratır
static func _whip_lash(pj: PathJutsu, c: Node3D, d: Vector3) -> void:
	var mi = L.wmi(null, {"alpha": 0.95, "foam": 0.2, "streak": 2.2, "flow": 3.5, "line": 0.14, "wob": 0.3})
	L.put(pj, mi, Vector3.ZERO)
	var side = d.cross(Vector3.UP).normalized()
	var tw = mi.create_tween()
	tw.tween_method(func(tm: float):
		if not is_instance_valid(c):
			mi.queue_free()
			return
		var a = pj.hand_pos(c, true)
		var k = tm / 0.35
		var ang = lerpf(-0.9, 0.9, smoothstep(0.0, 1.0, k))
		var reach = clampf(k * 2.0, 0.1, 1.0)
		var pts = []
		var rad = []
		for i in 26:
			var u = i / 25.0
			var dd = d.rotated(Vector3.UP, ang - u * u * 0.6)
			pts.append(a + dd * 9.0 * u * reach + Vector3.UP * (sin(u * PI) * 0.6 - u * 1.0) + side * sin(u * 8.0 - k * 14.0) * 0.12 * u)
			rad.append(lerpf(0.09, 0.05, u))
		mi.mesh = L.tube_mesh(pts, rad, 8), 0.0, 0.35, 0.35)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.2)
	tw.tween_callback(mi.queue_free)
	pj.after(0.3, func():
		if not is_instance_valid(c):
			return
		var tip = pj.gp(c.global_position + d.rotated(Vector3.UP, 0.6) * 8.5)
		L.crown(pj, tip, 0.8, {"h": 0.8, "t": 0.1, "fall": 0.35, "foam": 0.4})
		L.spray(pj, tip, Vector3.UP, {"n": 14, "spread": 60.0, "vmin": 2.0, "vmax": 5.0, "life": 0.5, "smin": 0.15, "smax": 0.3, "foam": 0.5}))


## Raiton: kırbaç boyunca titreyen kırık şimşek çizgisi (her karede yeniden) + hedefte mavi parlama
static func _whip_current(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float) -> void:
	var mi = MeshInstance3D.new()
	mi.material_override = _c("whip_bolt", func(): return _glow_mat(Color(0.75, 0.88, 1.0, 1.0)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.put(pj, mi, Vector3.ZERO)
	var tw = mi.create_tween()
	tw.tween_method(func(_tm: float):
		if not (is_instance_valid(c) and is_instance_valid(tt)):
			mi.queue_free()
			return
		var a = pj.hand_pos(c, true)
		var b = tt.global_position + Vector3.UP * 1.0
		var pts = []
		var rad = []
		for i in 14:
			var u = i / 13.0
			var j = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.22 * sin(u * PI)
			pts.append(a.lerp(b, u) + Vector3.UP * sin(u * PI) * 0.25 + j)
			rad.append(0.035)
		mi.mesh = L.tube_mesh(pts, rad, 4), 0.0, dur, dur)
	tw.tween_callback(mi.queue_free)
	_light(pj, tt.global_position + Vector3.UP, Color(0.6, 0.8, 1.0), 4.0, 6.0, dur)


# ================================================================== 8. Suihachi — dalga eli
## Ref (Hand of Waves): dev su eli. Hedefin ötesinde yer yarılıp sıçrar, bilek ve avuç yerden yükselir; dört parmak
## ve başparmak eklem eklem bükülüp hedefin üstünden kapanır (yumruk). İçerideyken her vuruşta el sıkar, parmak
## aralarından su süzülür; süre bitince el biçimini yitirip yere yıkılır, göl ve halka dalga kalır.
static func suiton_suihachi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	var hand = _wave_hand(pj, at, _flat(at - c.global_position))
	pj.after(0.6, func():
		for e in pj.enemies_near(c, at, 2.6):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("bind", 2.0)
		pj.every(2.0, 0.5, func(_i, _k):
			for e in pj.enemies_near(c, at, 2.6):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "suiton_suihachi", 0.3, {"knock": 0.0, "kind": "light", "element": "suiton"}))
			_hand_squeeze(pj, hand), func(): _hand_release(pj, hand, at)))
	Sfx.play("water", at, 0.8)


static func _wave_hand(pj: PathJutsu, at: Vector3, f: Vector3) -> Node3D:
	var root = Node3D.new()
	L.put(pj, root, at)
	root.look_at(at + f, Vector3.UP)   # -Z: kullanandan hedefe; avuç hedefin ötesinde, parmaklar kullanana doğru kapanır
	var mi = L.wmi(null, {"alpha": 0.88, "foam": 0.22, "streak": 1.6, "flow": 2.2, "wob": 0.8, "line": 0.12})
	root.add_child(mi)
	root.set_meta("mi", mi)
	var tw = mi.create_tween()
	tw.tween_method(func(k: float):
		var e = clampf(k / 0.45, 0.0, 1.0)
		var cl = clampf((k - 0.4) / 0.3, 0.0, 1.0)
		mi.mesh = _hand_mesh(1.0 - pow(1.0 - e, 3.0), cl * cl * (3.0 - 2.0 * cl)), 0.0, 0.7, 0.7)
	var wrist = L.ground(root.to_global(Vector3(0, 0, -1.6)))
	L.crown(pj, wrist, 2.2, {"h": 0.8, "t": 0.2, "fall": 0.6, "foam": 0.5})
	L.puddle(pj, at, 3.4, 2.6, {"alpha": 0.6, "ripple": 0.6})
	L.ripple(pj, wrist, 0.5, 4.0, 0.6, {"foam": 1.0})
	L.spray(pj, wrist, Vector3.UP, {"n": 24, "spread": 40.0, "vmin": 4.0, "vmax": 8.0, "life": 0.8, "smin": 0.25, "smax": 0.45, "r": 1.0, "foam": 0.5})
	L.free_later(pj, root, 4.5)
	return root


## Dev su eli (yerel: -Z hedefin ötesi). e: yerden çıkış (0..1), cl: parmakların kapanması (0 açık, 1 hedefi saran yumruk)
static func _hand_mesh(e: float, cl: float) -> ArrayMesh:
	var sf = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dy = Vector3.DOWN * (1.0 - e) * 4.5
	var vc = 0
	# bilek: yerden yükselir
	vc = L.tube_into(sf, vc, [Vector3(0, -2.5, -1.75) + dy, Vector3(0, 0.6, -1.7) + dy, Vector3(0, 1.6, -1.62) + dy], [0.95, 0.85, 0.8], 14, 0.75, Vector3.RIGHT)
	# avuç: yanlara geniş, öne-arkaya yassı
	vc = L.tube_into(sf, vc, [Vector3(0, 1.3, -1.62) + dy, Vector3(0, 1.9, -1.58) + dy, Vector3(0, 2.5, -1.5) + dy, Vector3(0, 2.75, -1.45) + dy], [0.95, 1.12, 1.1, 0.85], 14, 0.45, Vector3.RIGHT)
	# dört parmak: her eklem öne (+Z) bükülür
	var xs = [-0.78, -0.26, 0.26, 0.78]
	var lens = [[0.95, 0.75, 0.6], [1.1, 0.85, 0.65], [1.05, 0.82, 0.62], [0.85, 0.65, 0.5]]
	var bends = [0.9, 1.0, 0.95]
	for fi in 4:
		var x0 = float(xs[fi])
		var p = Vector3(x0 * (1.0 + 0.25 * (1.0 - cl)), 2.6, -1.45) + dy
		var ang = -0.12 * (1.0 - cl)   # açıkken hafif geriye yaslı
		var spread = x0 * 0.25 * (1.0 - cl)
		var pts = [p]
		var rad = [0.3]
		for j in 3:
			ang += float(bends[j]) * cl
			var dir = Vector3(spread, cos(ang), sin(ang)).normalized()
			var ln = float(lens[fi][j])
			for s in 2:
				p = p + dir * ln * 0.5
				pts.append(p)
				rad.append(lerpf(0.29, 0.2, float(j * 2 + s + 1) / 6.0))
		pts.append(p + Vector3(spread, cos(ang), sin(ang)).normalized() * 0.18)
		rad.append(0.0)
		vc = L.tube_into(sf, vc, pts, rad, 8)
	# başparmak: avucun yanından içe kapanır
	var tp = Vector3(1.0, 1.8, -1.45) + dy
	var tpts = [tp]
	var trad = [0.3]
	var tdir = Vector3(0.8, 0.55, 0.1).lerp(Vector3(-0.2, 0.3, 0.9), cl).normalized()
	for j in 4:
		tp = tp + tdir * 0.42
		tpts.append(tp)
		trad.append(lerpf(0.29, 0.2, j / 3.0))
		tdir = tdir.lerp(Vector3(-0.6, -0.2, 0.7), 0.25 * cl).normalized()
	tpts.append(tp + tdir * 0.16)
	trad.append(0.0)
	vc = L.tube_into(sf, vc, tpts, trad, 8)
	sf.generate_normals()
	return sf.commit()


static func _hand_squeeze(pj: PathJutsu, hand: Node3D) -> void:
	if not is_instance_valid(hand):
		return
	var tw = hand.create_tween()
	tw.tween_property(hand, "scale", Vector3(1.06, 0.94, 1.06), 0.08)
	tw.tween_property(hand, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
	L.spray(pj, hand.to_global(Vector3(0, 2.4, 0.3)), Vector3.DOWN, {"n": 10, "spread": 40.0, "vmin": 0.5, "vmax": 2.0, "life": 0.6, "smin": 0.15, "smax": 0.3, "r": 0.8, "foam": 0.3})


static func _hand_release(pj: PathJutsu, hand: Node3D, at: Vector3) -> void:
	if not is_instance_valid(hand):
		return
	var mi = hand.get_meta("mi")
	if is_instance_valid(mi):
		_fade_out(mi, 0.45)
	var tw = hand.create_tween()
	tw.tween_property(hand, "scale", Vector3(1.15, 0.05, 1.15), 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(hand.queue_free)
	pj.after(0.2, func():
		L.crown(pj, at, 3.0, {"h": 0.5, "t": 0.15, "fall": 0.55, "foam": 0.55})
		L.ripple(pj, at, 1.0, 5.5, 0.7, {"foam": 1.0})
		L.puddle(pj, at, 3.6, 1.5, {"alpha": 0.6, "ripple": 0.5}))
	L.spray(pj, at + Vector3.UP * 2.0, Vector3.DOWN, {"n": 40, "spread": 70.0, "vmin": 2.0, "vmax": 5.0, "life": 0.7, "smin": 0.25, "smax": 0.45, "r": 1.6, "foam": 0.3})


# ================================================================== 9. Mizuame Bakujō — yapışkan şurup ağı
## Ağızda amber şurup toplanır; üç ağır şurup damlası güdümlü uçar, her biri ağızla arasında sarkan yapışkan bir ip
## çeker (mermi bitince ip yere sarkıp kopar). Çarpınca hedefe yapışan şurup kütlesi ve gövdeden sarkan damlalı
## iplikler (3 sn), ayak dibinde yapışkan gölcük kalır.
static func mizuame_bakujo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 18.0)
	L.gather(pj, pj._mouth_pos(c), 0.7, 10, 0.25, 0.22, L.SYRUP)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var mo = pj._mouth_pos(c)
		for i in 3:
			var pr = pj.shot(c, mo, pj.aim_at(c, tt, mo).rotated(Vector3.UP, (i - 1) * 0.1), 26.0, _syrup_glob(), pj.inf(c, "mizuame_bakujo", 0.3, {"knock": 0.0, "kind": "light", "element": "suiton"}), tt, false, 1.2, func(p, h):
				_syrup_splat(pj, p, h)
				if h and pj.live(h) and h.has_method("apply_status"):
					h.apply_status("bind", 3.0))
			pr.radius = maxf(0.5, 0.25)
			pr.homing_turn = 3.0
			L.trail(pr, {"n": 10, "life": 0.6, "spread": 30.0, "vmin": 0.3, "vmax": 1.0, "g": Vector3(0, -9, 0), "pal": L.SYRUP, "smin": 0.12, "smax": 0.22, "alpha": 0.95})
			_syrup_thread(pj, mo, pr))
	Sfx.play("water", c.global_position, 1.3)


static func _syrup_glob() -> Node3D:
	var root = Node3D.new()
	var g = L.wmi(L.drop_mesh(), {"pal": L.SYRUP, "alpha": 0.96, "wob": 1.6, "foam": 0.12, "line": 0.14, "streak": 0.6, "flow": 1.0})
	g.scale = Vector3(0.9, 0.9, 1.3)
	root.add_child(g)
	return root


## Ağızdan mermiye uzanan sarkık şurup ipi; mermi bitince yere sarkıp incelir ve söner
static func _syrup_thread(pj: PathJutsu, mo: Vector3, pr: Projectile) -> void:
	var mi = L.wmi(null, {"pal": L.SYRUP, "alpha": 0.92, "foam": 0.0, "line": 0.12, "streak": 0.5, "flow": 0.6})
	L.put(pj, mi, Vector3.ZERO)
	var sv = {"end": mo, "drop": 0.0}
	var tw = mi.create_tween()
	tw.tween_method(func(_tm: float):
		if is_instance_valid(pr) and not pr.dead:
			sv["end"] = pr.global_position
		else:
			sv["drop"] = minf(1.0, float(sv["drop"]) + 0.05)
		var b: Vector3 = sv["end"]
		var ln = mo.distance_to(b)
		if ln < 0.05:
			return
		var dr = float(sv["drop"])
		var sag = 0.04 * ln + dr * 2.5
		var pts = []
		var rad = []
		for i in 16:
			var u = i / 15.0
			var p = mo.lerp(b, u) + Vector3.DOWN * sin(u * PI) * sag
			if dr > 0.0:
				p.y = maxf(L.ground(p).y + 0.05, p.y - dr * 1.5 * u)
			pts.append(p)
			rad.append(0.035 * (1.0 - 0.5 * sin(u * PI)) * (1.0 - dr * 0.6))
		mi.mesh = L.tube_mesh(pts, rad, 6), 0.0, 1.9, 1.9)
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


static func _syrup_splat(pj: PathJutsu, p: Vector3, h) -> void:
	L.spray(pj, p, Vector3.UP, {"n": 14, "spread": 100.0, "vmin": 1.0, "vmax": 3.0, "life": 0.8, "pal": L.SYRUP, "smin": 0.15, "smax": 0.3, "g": Vector3(0, -6, 0), "alpha": 0.95})
	var g = L.ground(p)
	L.puddle(pj, g, 1.3, 2.8, {"pal": L.SYRUP, "alpha": 0.85, "ripple": 0.0, "foam": 0.05, "spread": 0.5})
	if h == null or not is_instance_valid(h) or h.is_dead():
		L.crown(pj, g, 0.7, {"pal": L.SYRUP, "h": 0.7, "t": 0.2, "fall": 0.9, "foam": 0.1})
		return
	var goo = Node3D.new()
	var o = {"pal": L.SYRUP, "alpha": 0.9, "wob": 1.2, "foam": 0.1, "line": 0.12, "streak": 0.4, "flow": 0.5}
	var blob = L.wmi(L.sphere_mesh(), o)
	blob.scale = Vector3(1.0, 0.75, 1.0)
	goo.add_child(blob)
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.4
		var top = Vector3(cos(a) * 0.42, -0.1, sin(a) * 0.42)
		var ln = randf_range(0.5, 1.0)
		var pts = []
		var rad = []
		for i in 6:
			var u = i / 5.0
			pts.append(top + Vector3(cos(a) * 0.08 * u, -ln * u, sin(a) * 0.08 * u))
			rad.append(lerpf(0.07, 0.03, u) + (0.05 if i == 5 else 0.0))   # ucunda damla şişkinliği
		pts.append(top + Vector3(cos(a) * 0.08, -ln - 0.08, sin(a) * 0.08))
		rad.append(0.0)
		goo.add_child(L.wmi(L.tube_mesh(pts, rad, 6), o))
	pj.attach(h, goo, 3.0, Vector3.UP * 1.1)
	var tw = goo.create_tween()
	tw.tween_property(goo, "scale", goo.scale * Vector3(1.0, 1.25, 1.0), 2.6).set_ease(Tween.EASE_IN)   # iplikler yavaşça uzar


# ================================================================== 10. Suikyū — başa yapışan su topu
## Avuçta su toplanır, bir top olup hedefin başına uçar ve orada kalır: kalın, sallanan su kabuğu, altından süzülen
## damlalar. Her hasar anında içinden hava kabarcıkları kaçar ve top sarsılır; süre sonunda top yıkılıp başından
## aşağı boşalır, ayak dibinde gölcük ve küçük taç.
static func suiton_suikyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 20.0)
	var hand = pj.hand_pos(c, true)
	L.gather(pj, hand, 0.8, 9, 0.22, 0.3)
	if tt:
		_orb_throw(pj, hand, tt)
	pj.after(0.25, func():
		if not pj.live(c) or tt == null or not is_instance_valid(tt):
			return
		var orb = _water_helm()
		tt.add_child(orb)
		orb.position = Vector3.UP * (tt.height * 0.9 if "height" in tt else 1.6)
		if tt.has_method("apply_status"):
			tt.apply_status("slow", 3.0)
		pj.every(3.0, 1.0, func(_i, _k):
			if pj.live(tt):
				pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.3, pj.inf(c, "suiton_suikyu", 0.4, {"knock": 0.0, "kind": "light", "element": "suiton"}))
				_helm_gasp(pj, orb), func():
			if is_instance_valid(orb):
				_helm_burst(pj, orb.global_position)
				orb.queue_free()))
	Sfx.play("water", c.global_position, 1.2)


static func _orb_throw(pj: PathJutsu, from: Vector3, tt: Node3D) -> void:
	var b = L.wmi(L.sphere_mesh(), {"alpha": 0.85, "wob": 1.8, "foam": 0.15, "line": 0.12, "flow": 2.0})
	L.put(pj, b, from)
	b.scale = Vector3.ONE * 0.3
	var to = tt.global_position + Vector3.UP * (tt.height * 0.9 if "height" in tt else 1.6)
	var tw = b.create_tween().set_parallel(true)
	tw.tween_property(b, "global_position", to, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(b, "scale", Vector3.ONE * 0.9, 0.25)
	tw.chain().tween_callback(b.queue_free)


static func _water_helm() -> Node3D:
	var root = Node3D.new()
	var shell = L.wmi(L.sphere_mesh(), {"alpha": 0.6, "wob": 2.2, "foam": 0.1, "line": 0.12, "streak": 1.0, "flow": 1.2, "ripple": 0.3})
	shell.scale = Vector3.ONE * 1.1
	root.add_child(shell)
	var drip = L.trail(root, {"n": 6, "life": 0.5, "dir": Vector3.DOWN, "spread": 20.0, "vmin": 0.2, "vmax": 0.6, "g": Vector3(0, -12, 0), "smin": 0.1, "smax": 0.18, "r": 0.35, "alpha": 0.9})
	drip.position = Vector3.DOWN * 0.45
	var tw = Game.safe_loops(shell.create_tween())
	tw.tween_property(shell, "scale", Vector3(1.16, 1.02, 1.12), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shell, "scale", Vector3(1.06, 1.16, 1.08), 0.35).set_trans(Tween.TRANS_SINE)
	return root


## Nefes kaçışı: topun içinden yükselen hava kabarcıkları + sarsıntı
static func _helm_gasp(pj: PathJutsu, orb: Node3D) -> void:
	if not is_instance_valid(orb):
		return
	var p = orb.global_position
	for k in 3:
		L.bubble(pj, p + Vector3(randf_range(-0.15, 0.15), -0.1 + k * 0.08, randf_range(-0.15, 0.15)), randf_range(0.08, 0.14), 0.35, Vector3(0, 1.1, 0))
	var tw = orb.create_tween()
	tw.tween_property(orb, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
	tw.tween_property(orb, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)


static func _helm_burst(pj: PathJutsu, p: Vector3) -> void:
	L.spray(pj, p, Vector3.DOWN, {"n": 30, "spread": 75.0, "vmin": 1.5, "vmax": 4.0, "life": 0.6, "smin": 0.18, "smax": 0.35, "r": 0.5, "foam": 0.25})
	var g = L.ground(p)
	L.puddle(pj, g, 1.3, 1.4, {"alpha": 0.6, "ripple": 0.5})
	pj.after(0.25, func(): L.crown(pj, g, 0.8, {"h": 0.5, "t": 0.1, "fall": 0.35, "foam": 0.4}))


# ================================================================== 11. Amearare — sertleşmiş damla dolusu
## Ayak dibinde su sıçrar, kalın bir su fışkırması gökyüzüne fırlar ve tepede sertleşmiş damlalara saçılır. Hedef
## alanın 16 m üstünde kurşuni-mavi bir bulut, oradan yönlenmiş (köşeli) damla tanelerinden sağanak dolu iner;
## yerde her vuruşta küçük sıvı taçlar ve halkalar, zeminde damla halkalı ıslak alan.
static func suiton_amearare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var pr = pj.shot(c, c.global_position + Vector3.UP * 1.5, Vector3.UP, 30.0, _spout_body(), pj.inf(c, "suiton_amearare", 0.1, {"element": "suiton"}), null, false, 0.4, func(p, _h):
		_spout_burst(pj, p))
	pr.radius = maxf(0.5, 0.6)
	L.trail(pr, {"n": 24, "life": 0.5, "spread": 12.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -14, 0), "smin": 0.2, "smax": 0.4, "foam": 0.3, "r": 0.3})
	L.crown(pj, pj.gp(c.global_position), 1.0, {"h": 0.6, "t": 0.12, "fall": 0.35, "foam": 0.4})
	pj.after(0.5, func(): _hail_storm(pj, c, at, 6.0, 2.0))
	Sfx.play("water", c.global_position, 1.0)


static func _spout_body() -> Node3D:
	var root = Node3D.new()
	var d = L.wmi(L.drop_mesh(), {"alpha": 0.9, "streak": 2.5, "flow": 4.0, "foam": 0.2, "line": 0.12, "wob": 1.0})
	d.scale = Vector3(1.6, 1.6, 4.0)   # yuvarlak baş önde (yukarı), uzun kuyruk aşağı
	root.add_child(d)
	return root


static func _spout_burst(pj: PathJutsu, p: Vector3) -> void:
	L.spray(pj, p, Vector3.UP, {"n": 50, "spread": 180.0, "vmin": 4.0, "vmax": 10.0, "life": 0.9, "smin": 0.3, "smax": 0.5, "foam": 0.6, "g": Vector3(0, -6, 0), "mesh": _bead_mesh()})
	var ring = L.wmi(L.ring_mesh(), {"foam": 1.0, "alpha": 0.8, "line": 0.0})
	L.put(pj, ring, p)
	ring.scale = Vector3(0.5, 1.0, 0.5)
	var tw = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(4.0, 1.0, 4.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)


## Sertleşmiş damla tanesi: altı yüzlü (köşeli) kısa boncuk, +Y öne (parçacık hızına hizalı)
static func _bead_mesh() -> ArrayMesh:
	return _c("bead", func():
		var prof = [[-0.3, 0.0], [-0.22, 0.15], [-0.05, 0.2], [0.15, 0.17], [0.35, 0.09], [0.5, 0.0]]
		var pts = []
		var rad = []
		for pr in prof:
			pts.append(Vector3.DOWN * float(pr[0]))
			rad.append(float(pr[1]))
		return L.tube_mesh(pts, rad, 6))


static func _hail_storm(pj: PathJutsu, c: Node3D, at: Vector3, r: float, dur: float) -> void:
	var em = L.particles({"n": 110, "life": 0.78, "dir": Vector3.DOWN, "spread": 3.0, "vmin": 18.0, "vmax": 24.0, "g": Vector3(0, -10, 0),
		"smin": 0.4, "smax": 0.6, "one_shot": false, "burst": 0.0, "foam": 0.55, "alpha": 0.95, "mesh": _bead_mesh()})
	var pm: ParticleProcessMaterial = em.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r, 0.4, r)
	em.visibility_aabb = AABB(Vector3(-r - 2.0, -20.0, -r - 2.0), Vector3(r * 2.0 + 4.0, 24.0, r * 2.0 + 4.0))
	L.put(pj, em, at + Vector3.UP * 16.0)
	em.emitting = true
	var tw = em.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func(): em.emitting = false)
	tw.tween_interval(1.0)
	tw.tween_callback(em.queue_free)
	L.puddle(pj, at, r, dur, {"alpha": 0.5, "ripple": 1.0, "foam": 0.05, "spread": 0.8})
	L.mist(pj, at + Vector3.UP * 15.0, r * 2.4, dur + 0.6, {"tone": 3, "alpha": 0.35, "near": 8.0})
	pj.every(dur, 0.12, func(i, _k):
		if i % 2 == 0:
			var q = at + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
			L.crown(pj, L.ground(q) + Vector3.UP * 0.05, randf_range(0.28, 0.4), {"h": 0.9, "t": 0.07, "fall": 0.2, "foam": 0.45})
		if i % 3 == 0:
			L.ripple(pj, at + Vector3(randf_range(-r, r), 0, randf_range(-r, r)), 0.1, 0.8, 0.45, {"foam": 0.9, "alpha": 0.6})
		if i % 4 == 0:
			for e in pj.enemies_near(c, at, r):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "suiton_amearare", 0.35, {"knock": 0.5, "kind": "light", "element": "suiton"})), Callable())


# ================================================================== 12. Santōka — asit çiçeği
## Ref (Utakata): gökkuşağı zarlı kabarcıklar; değdiği yaprak beyaz dumanla erir. Avuçta yeşilimsi asit toplanır;
## içinde asit çekirdeği taşıyan üç kabarcıklık küme dönerek güdümlü uçar, asit damlatır. Çarpınca zarlar patlar,
## beş yapraklı beyaz aşındırıcı buhar "çiçeği" açılır; yere yakınsa yeşil asit gölcüğü cızırdayıp kabarcık çıkarır.
static func santoka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 22.0)
	L.gather(pj, pj.hand_pos(c, true), 0.6, 8, 0.2, 0.18, L.SOAP)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, _acid_cluster(), pj.inf(c, "santoka", 1.0, {"knock": 2.0, "kind": "heavy", "element": "suiton"}), tt, false, 1.2, func(p, h):
			_acid_flower(pj, p)
			if h and pj.live(h) and h.has_method("apply_status"):
				h.apply_status("burn", 4.0))
		pr.radius = maxf(0.5, 0.35)
		pr.homing_turn = 2.5
		L.trail(pr, {"n": 12, "life": 0.6, "spread": 35.0, "vmin": 0.2, "vmax": 0.8, "g": Vector3(0, -9, 0), "pal": L.SOAP, "smin": 0.1, "smax": 0.18, "alpha": 0.9}))
	Sfx.play("water", c.global_position, 1.4)


static func _acid_cluster() -> Node3D:
	var root = Node3D.new()
	var offs = [[Vector3(0, 0, 0), 0.55], [Vector3(0.32, 0.18, 0.3), 0.36], [Vector3(-0.28, -0.14, 0.38), 0.3]]
	for o in offs:
		var film = _film(float(o[1]))
		film.position = o[0]
		root.add_child(film)
		var core = L.wmi(L.sphere_mesh(), {"pal": L.SOAP, "alpha": 0.38, "wob": 2.0, "foam": 0.25, "line": 0.0})
		core.scale = Vector3.ONE * float(o[1]) * 0.55
		core.position = o[0]
		root.add_child(core)
	var tw = Game.safe_loops(root.create_tween())
	tw.tween_property(root, "rotation:z", TAU, 1.2).from(0.0)
	return root


static func _acid_flower(pj: PathJutsu, p: Vector3) -> void:
	L.bubble_pop(pj, p, 0.55)
	L.bubble_pop(pj, p + Vector3(0.3, 0.15, 0.2), 0.35)
	L.spray(pj, p, Vector3.UP, {"n": 18, "spread": 150.0, "vmin": 1.5, "vmax": 4.0, "life": 0.6, "pal": L.SOAP, "smin": 0.1, "smax": 0.2, "alpha": 0.9, "foam": 0.3})
	for k in 5:
		var a = k * TAU / 5.0 + randf() * 0.3
		var off = Vector3(cos(a), 0.35, sin(a)) * 0.45
		L.mist(pj, p + off, 1.0, 1.4, {"tone": 0, "alpha": 0.6, "near": 3.0, "drift": off * 1.4 + Vector3.UP * 0.5, "s0": 0.3, "grow": 0.3})
	L.mist(pj, p, 0.7, 1.1, {"tone": 4, "alpha": 0.5, "near": 3.0, "drift": Vector3.UP * 0.7, "s0": 0.4})
	var g = L.ground(p)
	if p.y - g.y < 2.5:
		var pool = L.puddle(pj, g, 1.3, 3.2, {"pal": L.SOAP, "alpha": 0.75, "ripple": 0.15, "foam": 0.3, "spread": 0.3})
		var tw = pool.create_tween().set_loops(10)
		tw.tween_interval(0.3)
		tw.tween_callback(func():
			var q = g + Vector3(randf_range(-0.9, 0.9), 0.05, randf_range(-0.9, 0.9))
			L.bubble(pj, q, randf_range(0.06, 0.12), randf_range(0.3, 0.5), Vector3(0, 0.5, 0)))


# ================================================================== 13. Iryō Suiton: Mizukurage — şifa denizanası
## Kullananı içine alan saydam sudan denizanası: fistolu kenarlı çan yüzer gibi nabız atar (kasılıp gevşer),
## kenarından yere değen dalgalı ağız kolları ve ince dokungaçlar salınır, içi soluk yeşil şifa ışığıyla dolu.
## Her iyileşme vuruşunda çandan yere inen şifa halkası ve yerden bedene süzülen damlalar; sonunda çan erir, yağar.
static func iryo_suiton_mizukurage(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var jelly = _medusa()
	c.add_child(jelly)
	jelly.position = Vector3.UP * 1.0
	pj.every(5.0, 0.5, func(i, _k):
		if pj.live(c):
			pj.heal(c, 3.0)
			_medusa_pulse(pj, c, jelly, i), func():
		if is_instance_valid(jelly):
			_medusa_melt(pj, jelly))
	Sfx.play("water", c.global_position, 0.9)


static func _medusa() -> Node3D:
	var root = Node3D.new()
	var bell = L.wmi(_bell_mesh(), {"alpha": 0.42, "foam": 0.08, "line": 0.16, "wob": 1.0, "streak": 0.7, "flow": 0.5, "ripple": 0.25})
	bell.position = Vector3.UP * 0.45
	root.add_child(bell)
	var inner = L.wmi(L.sphere_mesh(), {"pal": L.SOAP, "alpha": 0.18, "wob": 1.4, "foam": 0.35, "line": 0.0})
	inner.scale = Vector3(1.3, 0.7, 1.3)
	inner.position = Vector3.UP * 1.0
	root.add_child(inner)
	var arms = Node3D.new()
	root.add_child(arms)
	for k in 6:
		var a = k * TAU / 6.0 + 0.3
		var piv = Node3D.new()
		piv.position = Vector3(cos(a) * 1.05, -0.45, sin(a) * 1.05)
		piv.rotation.y = -a
		arms.add_child(piv)
		piv.add_child(L.wmi(_arm_mesh(k % 3), {"alpha": 0.6, "foam": 0.2, "line": 0.12, "streak": 1.0, "flow": 0.8, "wob": 0.6}))
		var tw = Game.safe_loops(piv.create_tween())
		tw.tween_property(piv, "rotation:z", 0.16, 0.9 + k * 0.07).set_trans(Tween.TRANS_SINE)
		tw.tween_property(piv, "rotation:z", -0.12, 0.9 + k * 0.07).set_trans(Tween.TRANS_SINE)
	for k in 12:
		var a = k * TAU / 12.0
		var td = L.wmi(_tendril_mesh(k % 4), {"alpha": 0.7, "foam": 0.3, "line": 0.1, "flow": 0.6})
		td.position = Vector3(cos(a) * 1.25, -0.5, sin(a) * 1.25)
		arms.add_child(td)
	var ta = Game.safe_loops(arms.create_tween())
	ta.tween_property(arms, "rotation:y", TAU, 9.0).from(0.0)
	var pulse = Game.safe_loops(bell.create_tween())
	pulse.tween_property(bell, "scale", Vector3(0.9, 1.08, 0.9), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse.tween_property(bell, "scale", Vector3(1.06, 0.94, 1.06), 0.55).set_trans(Tween.TRANS_SINE)
	root.scale = Vector3.ONE * 0.2
	var tg = root.create_tween()
	tg.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


## Çan: döner yüzey (tepe yuvarlak, kenar hafif içe), alt kenarı sekiz fistolu; dışa bakan yüzler
static func _bell_mesh() -> ArrayMesh:
	return _c("medusa_bell", func():
		var sf = SurfaceTool.new()
		sf.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs = 36
		var prof = [[0.0, 1.25], [0.45, 1.18], [0.85, 0.98], [1.15, 0.62], [1.32, 0.15], [1.38, -0.35], [1.32, -0.7], [1.2, -0.85]]
		var rows = prof.size()
		for ri in rows:
			for s in segs + 1:
				var a = s * TAU / segs
				var rr = float(prof[ri][0])
				var y = float(prof[ri][1])
				var lo = clampf(0.15 - y, 0.0, 1.0)
				rr *= 1.0 + 0.07 * lo * sin(a * 8.0)
				y -= 0.12 * lo * (0.5 + 0.5 * cos(a * 8.0))
				sf.set_uv(Vector2(float(s) / segs, float(ri) / (rows - 1)))
				sf.add_vertex(Vector3(cos(a) * rr, y, sin(a) * rr))
		for ri in rows - 1:
			for s in segs:
				var a0 = ri * (segs + 1) + s
				var b0 = a0 + segs + 1
				sf.add_index(a0)
				sf.add_index(b0)
				sf.add_index(a0 + 1)
				sf.add_index(a0 + 1)
				sf.add_index(b0)
				sf.add_index(b0 + 1)
		sf.generate_normals()
		return sf.commit())


## Dalgalı ağız kolu: kenardan yere sarkan yassı şerit (geniş yüzü kenar boyunca)
static func _arm_mesh(v: int) -> ArrayMesh:
	return _c("medusa_arm_%d" % v, func():
		var pts = []
		var rad = []
		for i in 12:
			var u = i / 11.0
			pts.append(Vector3(sin(u * 7.0 + v) * 0.12, -u * 0.55, cos(u * 5.0 + v * 2.0) * 0.06))
			rad.append(0.11 * (1.0 - u * 0.7))
		return L.tube_mesh(pts, rad, 6, 0.35, Vector3.FORWARD))


static func _tendril_mesh(v: int) -> ArrayMesh:
	return _c("medusa_tendril_%d" % v, func():
		var pts = []
		var rad = []
		var ln = 0.4 + v * 0.05
		for i in 10:
			var u = i / 9.0
			pts.append(Vector3(sin(u * 6.0 + v * 1.7) * 0.07, -u * ln, cos(u * 4.0 + v) * 0.05))
			rad.append(0.022 * (1.0 - u * 0.6))
		return L.tube_mesh(pts, rad, 4))


## Her iyileşme vuruşu: çandan yere inen soluk yeşil şifa halkası + yerden bedene süzülen şifa damlaları
static func _medusa_pulse(pj: PathJutsu, c: Node3D, jelly: Node3D, i: int) -> void:
	if not is_instance_valid(jelly):
		return
	var top = jelly.global_position + Vector3.UP * 0.6
	var ring = L.wmi(L.ring_mesh(), {"pal": L.SOAP, "foam": 1.0, "flat": 1.0, "alpha": 0.8, "line": 0.0})
	L.put(pj, ring, top)
	ring.scale = Vector3(1.3, 1.0, 1.3)
	var tw = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "global_position", L.ground(top) + Vector3.UP * 0.08, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "scale", Vector3(1.8, 1.0, 1.8), 0.45)
	tw.tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)
	if i % 2 == 0:
		for k in 4:
			var a = randf() * TAU
			var mote = L.wmi(L.sphere_mesh(), {"pal": L.SOAP, "foam": 0.8, "alpha": 0.9, "line": 0.0})
			L.put(pj, mote, L.ground(c.global_position) + Vector3(cos(a) * 1.1, 0.1, sin(a) * 1.1))
			mote.scale = Vector3.ONE * 0.09
			var tm = mote.create_tween().set_parallel(true)
			tm.tween_property(mote, "global_position", c.global_position + Vector3.UP * 1.1, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			tm.tween_property(mote, "scale", Vector3.ONE * 0.03, 0.6)
			tm.chain().tween_callback(mote.queue_free)


static func _medusa_melt(pj: PathJutsu, jelly: Node3D) -> void:
	var p = jelly.global_position
	L.spray(pj, p + Vector3.UP * 0.5, Vector3.DOWN, {"n": 36, "spread": 70.0, "vmin": 1.0, "vmax": 3.0, "life": 0.6, "smin": 0.15, "smax": 0.3, "r": 1.1, "foam": 0.2})
	L.puddle(pj, L.ground(p), 1.8, 1.2, {"alpha": 0.55, "ripple": 0.5})
	var tw = jelly.create_tween()
	tw.tween_property(jelly, "scale", Vector3(1.2, 0.08, 1.2), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(jelly.queue_free)


# ================================================================== 14. Obore Awa — boğan dev kabarcık
## Ağızdan küçük bir kabarcık üflenir, uçarken büyür ve hedefi içine alan dev gökkuşağı zarına dönüşür. Zarın
## içinde su birikir; her vuruşta su seviyesi yükselir, hedef biraz havalanır ve ağzından hava kabarcıkları kaçar.
## Süre sonunda zar patlar, su aşağı boşalır: yerde taç ve gölcük.
static func obore_awa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 20.0)
	if tt:
		_awa_blow(pj, pj._mouth_pos(c), tt)
	pj.after(0.25, func():
		if not pj.live(c) or tt == null or not is_instance_valid(tt):
			return
		var b = _drown_bubble()
		tt.add_child(b)
		ClanJutsu.fit_body(tt, b)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		b.position = Vector3.UP * 1.0
		if tt.has_method("apply_status"):
			tt.apply_status("bind", 2.5)
		pj.every(2.5, 0.5, func(i, _k):
			if pj.live(tt):
				tt.global_position += Vector3.UP * 0.25
				pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.3, pj.inf(c, "obore_awa", 0.35, {"knock": 0.0, "kind": "light", "element": "suiton"}))
				_drown_tick(pj, b, i), func():
			if is_instance_valid(b):
				_drown_burst(pj, b)
				b.queue_free()))
	Sfx.play("water", c.global_position, 1.3)


static func _awa_blow(pj: PathJutsu, from: Vector3, tt: Node3D) -> void:
	var f = _film(0.3)
	L.put(pj, f, from)
	var to = tt.global_position + Vector3.UP * 1.0
	var tw = f.create_tween().set_parallel(true)
	tw.tween_property(f, "global_position", to, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(f, "scale", Vector3.ONE * 1.6, 0.25)
	tw.chain().tween_callback(f.queue_free)


## Dev zar + içinde birikmiş su (alt kısım); kök ölçeği fit_body'ye bırakılır, büyüme çocuklarda
static func _drown_bubble() -> Node3D:
	var root = Node3D.new()
	var skin = _film(1.6)
	root.add_child(skin)
	var ts = skin.create_tween()
	ts.tween_property(skin, "scale", Vector3.ONE * 2.6, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fill = L.wmi(L.sphere_mesh(), {"alpha": 0.5, "foam": 0.12, "wob": 1.8, "line": 0.08, "ripple": 0.4, "flow": 0.8})
	fill.scale = Vector3(1.9, 0.7, 1.9)
	fill.position = Vector3(0, -0.85, 0)
	root.add_child(fill)
	root.set_meta("fill", fill)
	return root


## Her vuruş: su seviyesi yükselir, ağızdan hava kabarcıkları kaçar
static func _drown_tick(pj: PathJutsu, b: Node3D, i: int) -> void:
	if not is_instance_valid(b):
		return
	var fill = b.get_meta("fill")
	if is_instance_valid(fill):
		var k = clampf((i + 1) / 5.0, 0.0, 1.0)
		var tw = fill.create_tween().set_parallel(true)
		tw.tween_property(fill, "scale", Vector3(lerpf(1.9, 2.3, k), lerpf(0.7, 1.6, k), lerpf(1.9, 2.3, k)), 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fill, "position", Vector3(0, lerpf(-0.85, -0.45, k), 0), 0.3)
	var p = b.global_position + Vector3.UP * 0.4
	for j in 3:
		L.bubble(pj, p + Vector3(randf_range(-0.12, 0.12), j * 0.1, randf_range(-0.12, 0.12)), randf_range(0.07, 0.12), 0.45, Vector3(0, 1.4, 0))


static func _drown_burst(pj: PathJutsu, b: Node3D) -> void:
	var p = b.global_position
	var s = b.scale.x
	L.bubble_pop(pj, p, 2.0 * s)
	L.spray(pj, p, Vector3.DOWN, {"n": 44, "spread": 80.0, "vmin": 2.0, "vmax": 5.0, "life": 0.7, "smin": 0.2, "smax": 0.4, "r": 1.0 * s, "foam": 0.3})
	var g = L.ground(p)
	L.puddle(pj, g, 2.0 * s, 1.6, {"alpha": 0.6, "ripple": 0.5})
	pj.after(0.3, func(): L.crown(pj, g, 1.4 * s, {"h": 0.5, "t": 0.12, "fall": 0.45, "foam": 0.4}))


# ================================================================== 15. Kibaku Awa — patlayıcı kabarcıklar
## Ağızdan beş kabarcık süzülür; her birinin gökkuşağı zarının içinde fitil gibi titreyen turuncu chakra çekirdeği
## ve küçük ışığı var. Değince zar yırtılır: turuncu-beyaz chakra küresi bir anda şişip söner, yatay su şok
## halkası açılır, zar damlaları savrulur, yere yakınsa ıslak iz kalır.
static func kibaku_awa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 22.0)
	for k in 5:
		pj.after(0.2 + k * 0.1, func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.25, 0.25)), 12.0, _fuse_bubble(), pj.inf(c, "kibaku_awa", 0.5, {"knock": 8.0, "kind": "heavy", "element": "suiton"}), tt, false, 2.6, func(p, _h):
				_bubble_blast(pj, p)
				pj.hit(c, p, 2.6, pj.inf(c, "kibaku_awa", 0.4, {"knock": 8.0, "launch": 3.0, "kind": "heavy", "element": "suiton"})))
			pr.homing_turn = 1.5)
	Sfx.play("water", c.global_position, 1.4)


static func _fuse_bubble() -> Node3D:
	var root = Node3D.new()
	root.add_child(_film(0.8))
	var core = MeshInstance3D.new()
	core.mesh = L.sphere_mesh()
	core.material_override = _c("fuse_core", func(): return _glow_mat(Color(1.0, 0.62, 0.25, 0.85)))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * 0.22
	root.add_child(core)
	var tw = Game.safe_loops(core.create_tween())
	tw.tween_property(core, "scale", Vector3.ONE * 0.3, 0.09)
	tw.tween_property(core, "scale", Vector3.ONE * 0.16, 0.13)
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 0.8
	l.omni_range = 2.2
	l.shadow_enabled = false
	root.add_child(l)
	return root


static func _bubble_blast(pj: PathJutsu, p: Vector3) -> void:
	_light(pj, p, Color(1.0, 0.75, 0.45), 6.0, 9.0, 0.35)
	for layer in [[Color(1.0, 0.7, 0.35, 0.9), 4.4, 0.2, 0.3], [Color(1.0, 0.97, 0.9, 1.0), 2.2, 0.12, 0.18]]:
		var ball = MeshInstance3D.new()
		ball.mesh = L.sphere_mesh()
		var m = _glow_mat(layer[0])
		m.cull_mode = BaseMaterial3D.CULL_BACK   # içinden bakınca görünmez: ekranı kaplamaz
		ball.material_override = m
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		L.put(pj, ball, p)
		ball.scale = Vector3.ONE * 0.3
		var tw = ball.create_tween().set_parallel(true)
		tw.tween_property(ball, "scale", Vector3.ONE * float(layer[1]), float(layer[2])).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(m, "albedo_color:a", 0.0, float(layer[3])).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(ball.queue_free)
	var ring = L.wmi(L.ring_mesh(), {"foam": 1.0, "alpha": 0.85, "line": 0.0})
	L.put(pj, ring, p)
	ring.scale = Vector3(0.6, 1.0, 0.6)
	var tr = ring.create_tween().set_parallel(true)
	tr.tween_property(ring, "scale", Vector3(5.5, 1.0, 5.5), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tr.tween_method(func(v: float): ring.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	tr.chain().tween_callback(ring.queue_free)
	L.bubble_pop(pj, p, 0.8)
	L.spray(pj, p, Vector3.UP, {"n": 30, "spread": 180.0, "vmin": 5.0, "vmax": 11.0, "life": 0.55, "smin": 0.14, "smax": 0.3, "foam": 0.7, "damp": 2.0})
	var g = L.ground(p)
	if p.y - g.y < 2.0:
		L.puddle(pj, g, 1.6, 0.8, {"alpha": 0.5, "ripple": 0.3})
