class_name SuitonFXA
extends RefCounted
## Suiton grubu A: on beş su tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları SuitonLib'den
## (kendi su gölgelendiricisi, damla, taç, birikinti, sis, köpük); her tekniğin şekli, hareketi ve sahnelenmesi kendine özgü.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) eski işleyicilerden satır satır taşındı.

const L := preload("res://scripts/combat/fx/lib/suiton_lib.gd")


static func _mouth(c: Node3D) -> Vector3:
	return c.global_position + Vector3.UP * 1.55 + c.face_dir() * 0.4


## El kemiği konumu (Jutsu otomatik yüklemesinden çağrılan teknikler için; PathJutsu.hand_pos ile aynı hesap)
static func _hand(c: Node3D) -> Vector3:
	var m = c.get("model")
	if m and is_instance_valid(m) and m.skel:
		var bi = m.skel.find_bone("RightHand")
		if bi >= 0:
			return (m.skel.global_transform * m.skel.get_bone_global_pose(bi)).origin
	var side = c.face_dir().cross(Vector3.UP).normalized()
	return c.global_position + Vector3.UP * 1.2 + c.face_dir() * 0.4 + side * 0.3


static func _up_for(d: Vector3) -> Vector3:
	return Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT


## İki nokta arasına birim boylu (-Z) meshi yerleştir
static func _span(n: Node3D, a: Vector3, b: Vector3) -> bool:
	var v = b - a
	var ln = v.length()
	if ln < 0.05:
		return false
	var f = v / ln
	n.global_transform = Transform3D(Basis.looking_at(f, _up_for(f)) * Basis.from_scale(Vector3(1, 1, ln)), a)
	return true


## Eski element mermisi oynanışı aynen: gecikme, nişan, hasar bilgisi (knock 8*impact_s, heavy, suiton, hitstop 0.05 + extra),
## hız, ömür 1.6, güdümsüz, yarıçap 0.35 + size*0.4. Görünüş: look(size) → çekirdek, launched(pr, dir), impact(p, dir)
static func _water_bolt(pj: PathJutsu, c: Node3D, id: String, tt: Node3D, from: Vector3, size: float, speed: float, mul: float, extra: Dictionary,
		impact_s: float, delay: float, look: Callable, launched: Callable, impact: Callable) -> void:
	pj.after(delay, func():
		if not pj.live(c):
			return
		var dir = pj.aim_at(c, tt, from)
		var info = {"knock": 8.0 * impact_s, "kind": "heavy", "element": "suiton", "hitstop": 0.05}
		info.merge(extra, true)
		var core: Node3D = look.call(size)
		var pr = pj.shot(c, from, dir, speed, core, pj.inf(c, id, mul, info), null, false, 1.6, func(p, _h):
			impact.call(p, dir))
		pr.radius = 0.35 + size * 0.4
		launched.call(pr, dir))


# ================================================================== Kirigakure no Jutsu (Jutsu otomatik yüklemesi)
## Yoğun saklanma sisi: ayak dibinden halka halinde kabaran buhar, ardından alanı katman katman dolduran ağır beyaz sis;
## yerde sürünen alçak sis tabakası, yavaşça dönen kütle. Kameraya yakın kartlar incelir.
static func kirigakure_no_jutsu(js, c: Node3D, _t: Node3D) -> void:
	var pos = c.global_position
	var r = 20.0
	var dur = 12.0
	Sfx.play("water", pos, 0.5)
	var g = L.ground(pos)
	# hazırlık: ayak dibinden dışa kabaran buhar halkası + yükselen su buğusu
	for k in 12:
		var a = k * TAU / 12.0 + randf() * 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		L.mist(js, g + dv * 0.8 + Vector3.UP * 0.7, randf_range(2.6, 3.6), 1.8, {"alpha": 0.85, "drift": dv * randf_range(5.0, 8.0) + Vector3.UP * 0.6,
			"s0": 0.25, "grow": 0.5, "near": 2.0, "fin": 0.08, "fout": 0.5})
	L.spray(js, g + Vector3.UP * 0.3, Vector3.UP, {"n": 26, "spread": 70.0, "vmin": 2.0, "vmax": 5.0, "life": 0.7, "smin": 0.12, "smax": 0.25,
		"r": 0.9, "g": Vector3(0, -3, 0), "foam": 0.8, "alpha": 0.6})
	# ağır sis: dönen kütle, dört dalgada alana yayılır
	var mass = Node3D.new()
	L.put(js, mass, g)
	var rot = mass.create_tween()
	rot.tween_property(mass, "rotation:y", 0.9, dur)
	rot.tween_callback(mass.queue_free)
	for wv in 4:
		js.get_tree().create_timer(wv * 0.25).timeout.connect(func():
			if not is_instance_valid(mass):
				return
			for i in 12:
				var a = randf() * TAU
				var rr = r * sqrt(randf()) * (0.35 + 0.65 * (wv + 1) / 4.0)
				var lp = Vector3(cos(a) * rr, randf_range(0.6, 4.2), sin(a) * rr)
				L.mist(js, lp, randf_range(7.0, 11.0), dur * 0.7 - wv * 0.25, {"parent": mass, "alpha": randf_range(0.5, 0.7),
					"drift": Vector3(randf_range(-1, 1), randf_range(0.0, 0.6), randf_range(-1, 1)) * 1.5, "s0": 0.4, "grow": 0.3,
					"near": 5.0, "fin": 0.12, "fout": 0.3}))
	# yerde sürünen alçak tabaka
	for i in 10:
		var a = i * TAU / 10.0 + randf() * 0.3
		var rr = r * randf_range(0.2, 0.85)
		L.mist(js, Vector3(cos(a) * rr, 0.5, sin(a) * rr), randf_range(10.0, 13.0), dur * 0.75, {"parent": mass, "alpha": 0.6,
			"drift": Vector3(cos(a), 0, sin(a)) * 2.0, "s0": 0.3, "grow": 0.4, "near": 5.0, "fin": 0.15, "fout": 0.3})
	if Game.world:
		Game.world.env.set_tint(Color(0.85, 0.88, 0.95, 0.35))
		js.get_tree().create_timer(dur).timeout.connect(func(): Game.world.env.set_tint(Color(0, 0, 0, 0)))
	for f in js.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(pos) < r * 1.5 and f.has_method("lose_target"):
			f.lose_target(dur * 0.7)
	if c is Player:
		Buffs.add("kirigakure", dur, {"stealth": 1.0})


# ================================================================== Suirō no Jutsu (Jutsu otomatik yüklemesi)
## Su hapsi: hedefin ayağından sarmal su telleri yükselir, beyaz sarmal desenli su küresine kapanır; atanın kolu küreye
## uzanan su teliyle bağlı (yakındaysa); içeride kabarcıklar, basınç vuruşlarında ağızdan hava kaçar; sonunda küre çöker.
static func suiro_no_jutsu(js, c: Node3D, t: Node3D) -> void:
	var tg = js._tg(c, t, 18.0)
	if tg == null:
		if c is Player: Hud.msg("Hapsedilecek hedef yakında değil.", Color(0.8, 0.8, 0.8))
		return
	Sfx.play("water", tg.global_position)
	var g = L.ground(tg.global_position)
	# hazırlık: yerden fışkıran su, iki sarmal tel hedefi sarıp yükselir
	L.ripple(js, g, 0.6, 3.2, 0.5)
	L.spray(js, g + Vector3.UP * 0.2, Vector3.UP, {"n": 30, "spread": 22.0, "vmin": 5.0, "vmax": 9.0, "r": 1.2, "life": 0.5, "smin": 0.2, "smax": 0.4})
	for k in 2:
		var hx = L.wmi(L.helix_mesh(1.3, tg.height * 1.3, 1.3, 0.22, k * PI), {"flow": 3.0, "alpha": 0.9, "foam": 0.2, "line": 0.12, "wob": 0.6})
		L.put(js, hx, g)
		hx.scale = Vector3(1, 0.05, 1)
		var tw0 = hx.create_tween()
		tw0.tween_property(hx, "scale", Vector3(0.75, 1.0, 0.75), 0.25).set_ease(Tween.EASE_OUT)
		tw0.parallel().tween_property(hx, "rotation:y", PI * (1.0 if k == 0 else -1.0), 0.4)
		tw0.tween_property(hx, "scale", Vector3(0.3, 1.1, 0.3), 0.15)
		tw0.parallel().tween_method(func(v: float): hx.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.15)
		tw0.tween_callback(hx.queue_free)
	var sph = L.wmi(L.sphere_mesh(), {"swirl": 1.0, "alpha": 0.6, "flow": 0.4, "wob": 0.35, "line": 0.09})
	tg.add_child(sph)
	sph.position = Vector3(0, tg.height * 0.5, 0)
	var face = c.global_position - tg.global_position
	face.y = 0.0
	if face.length() > 0.2:
		sph.look_at(sph.global_position - face.normalized(), Vector3.UP)   # sarmal deseni (+Z) atana bakar
	sph.scale = Vector3.ONE * 0.2
	var r = maxf(3.4, tg.height * 1.9)
	sph.create_tween().tween_property(sph, "scale", Vector3.ONE * r, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# içeride yükselen kabarcıklar
	var bub = L.particles({"n": 10, "life": 1.2, "dir": Vector3.UP, "spread": 25.0, "vmin": 0.6, "vmax": 1.4, "g": Vector3(0, 1.5, 0),
		"smin": 0.15, "smax": 0.3, "r": 0.7, "align": false, "mesh": L.sphere_mesh(), "one_shot": false, "burst": 0.0, "foam": 0.3, "alpha": 0.55, "line": 0.25})
	tg.add_child(bub)
	bub.position = Vector3(0, tg.height * 0.5, 0)
	bub.emitting = true
	# atanın kolu: elden küreye uzanan su teli
	var arm = Node3D.new()
	L.put(js, arm, c.global_position)
	var am = L.wmi(L.strand_mesh(), {"flow": 2.5, "alpha": 0.82, "line": 0.18, "wob": 0.8})
	arm.add_child(am)
	arm.visible = false
	var dur = 5.0
	arm.create_tween().tween_method(func(_k: float):
		if not (is_instance_valid(c) and is_instance_valid(sph)):
			arm.visible = false
			return
		var a = _hand(c)
		var b = sph.global_position
		var ln = a.distance_to(b)
		arm.visible = ln > 0.4 and ln < 9.0 and _span(arm, a, b), 0.0, 1.0, dur)
	tg.apply_status("bind", dur)
	var inf = js._inf(c, "suiro_no_jutsu", 0.12, {"knock": 0.0, "launch": 0.0, "kind": "light", "hitstop": 0.0, "element": "suiton"})
	js._ticks(int(dur / 0.5), 0.5, func(_i):
		if is_instance_valid(tg) and not tg.is_dead():
			tg.take_hit(inf.merged({"attacker": c, "dir": Vector3.ZERO}, true))
			# basınç: ağızdan hava kaçar, küre yüzeyi titrer
			L.spray(js, tg.global_position + Vector3.UP * tg.height * 0.85, Vector3.UP, {"n": 5, "spread": 20.0, "vmin": 0.8, "vmax": 1.6, "life": 0.7,
				"g": Vector3(0, 1.0, 0), "smin": 0.12, "smax": 0.22, "align": false, "mesh": L.sphere_mesh(), "foam": 0.6, "alpha": 0.6})
			if is_instance_valid(sph):
				sph.set_instance_shader_parameter("wob", 1.2)
				sph.create_tween().tween_method(func(v: float): sph.set_instance_shader_parameter("wob", v), 1.2, 0.35, 0.4), func():
		if is_instance_valid(arm):
			arm.queue_free()
		if is_instance_valid(bub):
			bub.queue_free()
		if is_instance_valid(sph):
			_prison_burst(js, sph)
			sph.queue_free())


## Küre çöker: su kütlesi yere yığılır, taç sıçraması, dışa saçılan damlalar, büyük birikinti
static func _prison_burst(js, sph: MeshInstance3D) -> void:
	var p = sph.global_position
	var s = sph.scale.x
	var g = L.ground(p)
	var blob = L.wmi(L.sphere_mesh(), {"alpha": 0.7, "wob": 1.4, "flow": 2.0, "line": 0.09, "foam": 0.15})
	L.put(js, blob, p)
	blob.scale = Vector3.ONE * s
	var tw = blob.create_tween().set_parallel(true)
	tw.tween_property(blob, "scale", Vector3(s * 1.5, s * 0.08, s * 1.5), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(blob, "global_position", g + Vector3.UP * 0.1, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(blob.queue_free)
	L.spray(js, p, Vector3.UP, {"n": 50, "spread": 75.0, "vmin": 4.0, "vmax": 9.0, "life": 0.8, "r": s * 0.4, "smin": 0.3, "smax": 0.6})
	js.get_tree().create_timer(0.25).timeout.connect(func():
		L.crown(js, g, s * 0.55, {"h": 0.8, "fall": 0.5})
		L.ripple(js, g, s * 0.3, s * 1.4, 0.7)
		L.puddle(js, g, s * 0.75, 4.0, {"alpha": 0.55}))


# ================================================================== Mizudeppō no Jutsu
## Parmak ucundan fırlayan, yuvarlak önlü gözyaşı biçimli su mermisi (akan parıltılı gövde, ince damla izi);
## çarpınca küçük taç + geri saçılan damlalar, yerde ıslak leke.
static func mizudeppo_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.4)
	var tt = pj.tg(c, t, 24.0)
	var from = pj.hand_pos(c, true)
	var dir = pj.aim_at(c, tt, from)
	L.gather(pj, from, 0.45, 6, 0.1, 0.1)
	var head = Node3D.new()
	var drop = L.wmi(L.drop_mesh(), {"flow": 4.0, "alpha": 0.82, "line": 0.12, "foam": 0.08})
	drop.scale = Vector3(1.1, 1.1, 1.6)
	head.add_child(drop)
	var info = pj.inf(c, "mizudeppo_no_jutsu", 1.0, {"knock": 4.0, "kind": "heavy", "element": "suiton"})
	var pr = pj.shot(c, from, dir, 40.0, head, info, tt, false, 1.0, func(p, _h):
		_deppo_hit(pj, p, dir))
	pr.radius = maxf(0.5, 0.2)
	pr.homing_turn = 2.0
	L.trail(pr, {"n": 14, "life": 0.3, "vmin": 0.5, "vmax": 1.5, "spread": 12.0, "smin": 0.12, "smax": 0.25, "g": Vector3(0, -6, 0), "r": 0.08})
	L.spray(pj, from, dir, {"n": 8, "spread": 14.0, "vmin": 6.0, "vmax": 11.0, "life": 0.25, "smin": 0.1, "smax": 0.2, "r": 0.05})
	Sfx.play("water", c.global_position, 1.8)


static func _deppo_hit(pj: PathJutsu, p: Vector3, dir: Vector3) -> void:
	var g = pj.gp(p)
	L.spray(pj, p, (-dir + Vector3.UP * 0.8).normalized(), {"n": 16, "spread": 55.0, "vmin": 3.0, "vmax": 7.0, "life": 0.45, "smin": 0.15, "smax": 0.3})
	L.spray(pj, p, dir, {"n": 10, "spread": 30.0, "vmin": 4.0, "vmax": 8.0, "life": 0.35, "smin": 0.1, "smax": 0.22, "foam": 0.6})
	if p.y - g.y < 1.4:
		L.crown(pj, g, 0.45, {"h": 0.8})
		L.puddle(pj, g, 0.7, 1.6, {"alpha": 0.5})


# ================================================================== Suiton: Suidan no Jutsu
## Ağız önünde su kabarıp sivrilir; uzun, keskin uçlu, geriye incelen su sivrisi fırlar (ince buğu izi);
## çarpınca ileri savrulan koni sıçrama + yönde uzamış ıslak iz.
static func suiton_suidan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var from = _mouth(c)
	L.gather(pj, from + c.face_dir() * 0.3, 0.7, 8, 0.15, 0.22)
	var look = func(_s: float) -> Node3D:
		var core = Node3D.new()
		var sp = L.wmi(L.spike_mesh(), {"flow": 5.0, "alpha": 0.88, "foam": 0.22, "line": 0.1, "wob": 0.6})
		core.add_child(sp)
		return core
	var launched = func(pr: Projectile, dir: Vector3) -> void:
		L.spray(pj, from, dir, {"n": 12, "spread": 18.0, "vmin": 5.0, "vmax": 10.0, "life": 0.3, "smin": 0.15, "smax": 0.3, "r": 0.1})
		L.trail(pr, {"n": 22, "life": 0.35, "vmin": 1.0, "vmax": 2.5, "spread": 20.0, "smin": 0.08, "smax": 0.18, "foam": 0.7, "alpha": 0.6, "g": Vector3(0, -4, 0)})
	var impact = func(p: Vector3, dir: Vector3) -> void:
		_suidan_hit(pj, p, dir)
	_water_bolt(pj, c, "suiton_suidan_no_jutsu", pj.tg(c, t, 24.0), from, 0.9, 30.0, 0.8, {}, 1.0, 0.16, look, launched, impact)
	Sfx.play("water", c.global_position, 1.2)


static func _suidan_hit(pj: PathJutsu, p: Vector3, dir: Vector3) -> void:
	var g = pj.gp(p)
	var fd = Vector3(dir.x, 0.25, dir.z).normalized()
	L.spray(pj, p, fd, {"n": 26, "spread": 32.0, "vmin": 6.0, "vmax": 12.0, "life": 0.5, "smin": 0.2, "smax": 0.4})
	L.spray(pj, p, Vector3.UP, {"n": 10, "spread": 40.0, "vmin": 3.0, "vmax": 6.0, "life": 0.45, "smin": 0.15, "smax": 0.3, "foam": 0.7})
	if p.y - g.y < 2.0:
		L.puddle(pj, g + fd * 0.8, 0.9, 2.5, {"alpha": 0.55, "dir": Vector3(dir.x, 0, dir.z), "stretch": 2.2})
		L.ripple(pj, g, 0.4, 2.0, 0.45)


# ================================================================== Suiton: Suisandan
## Yelpaze halinde beş elmas kesitli su dartı (koyu mavi gövde, keskin beyaz parıltı kenarları);
## çarpınca küçük damla saçılması ve yerde tek dalgacık halkası.
static func suiton_suisandan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	var look = func(_s: float) -> Node3D:
		var core = Node3D.new()
		var dm = L.wmi(L.dart_mesh(), {"flow": 2.0, "alpha": 0.92, "foam": 0.06, "line": 0.12})
		dm.scale = Vector3(1.6, 1.6, 1.4)
		core.add_child(dm)
		return core
	var launched = func(pr: Projectile, _dir: Vector3) -> void:
		L.trail(pr, {"n": 8, "life": 0.22, "vmin": 0.4, "vmax": 1.2, "spread": 10.0, "smin": 0.08, "smax": 0.14, "g": Vector3(0, -5, 0), "r": 0.05})
	var impact = func(p: Vector3, _dir: Vector3) -> void:
		var g = pj.gp(p)
		L.spray(pj, p, Vector3.UP, {"n": 10, "spread": 80.0, "vmin": 2.0, "vmax": 5.0, "life": 0.35, "smin": 0.12, "smax": 0.22})
		if p.y - g.y < 1.5:
			L.ripple(pj, g, 0.2, 1.3, 0.35, {"alpha": 0.7})
			L.puddle(pj, g, 0.45, 1.4, {"alpha": 0.45, "ripple": 0.0})
	for k in 5:
		pj.after(k * 0.1, func():
			if pj.live(c):
				var side = c.face_dir().cross(Vector3.UP) * ((k - 2) * 0.9)
				var from = _mouth(c) + side * 0.3
				L.gather(pj, from, 0.35, 4, 0.06, 0.1)
				_water_bolt(pj, c, "suiton_suisandan", tt, from, 0.55, 32.0, 0.25, {}, 0.6, 0.06, look, launched, impact))
	Sfx.play("water", c.global_position, 1.3)


# ================================================================== Suiton: Mizu Shuriken
## Avuçta su toplanır; dört kıvrık yassı kanatlı su şurikenleri döne döne uçar (kanat uçlarından savrulan ince damla izi);
## çarpınca yatay yelpaze halinde yarılan su.
static func suiton_mizu_shuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 0.5)
	var from = pj.hand_pos(c, true)
	L.gather(pj, from, 0.9, 10, 0.12, 0.2)
	for k in 4:
		pj.after(0.12 + k * 0.08, func():
			if not pj.live(c):
				return
			var star = Node3D.new()
			var sm = L.wmi(L.star_mesh(), {"flow": 3.5, "alpha": 0.9, "foam": 0.12, "line": 0.14})
			sm.scale = Vector3.ONE * 0.9
			star.add_child(sm)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, (k - 1.5) * 0.06), 34.0, star, pj.inf(c, "suiton_mizu_shuriken", 0.3, {"knock": 2.0, "kind": "light", "element": "suiton", "bleed": 1.0}), tt, false, 1.3, func(p, _h):
				_shuriken_hit(pj, p))
			pr.spin = Vector3(0, 28, 0)
			L.trail(pr, {"n": 18, "life": 0.3, "dir": Vector3(1, 0, 0), "spread": 180.0, "vmin": 0.5, "vmax": 1.5, "smin": 0.08, "smax": 0.16,
				"g": Vector3(0, -6, 0), "r": 0.4, "foam": 0.3}))
	Sfx.play("water", from, 1.6)


static func _shuriken_hit(pj: PathJutsu, p: Vector3) -> void:
	# yatay yarılma: düzleme yakın yelpaze
	L.spray(pj, p, Vector3.UP, {"n": 18, "spread": 88.0, "vmin": 4.0, "vmax": 8.0, "life": 0.3, "smin": 0.12, "smax": 0.24, "g": Vector3(0, -5, 0), "foam": 0.3})
	var g = pj.gp(p)
	if p.y - g.y < 1.4:
		L.puddle(pj, g, 0.5, 1.2, {"alpha": 0.45, "ripple": 0.0})


# ================================================================== Suiton: Mizurappa
## Ağızdan kalınlaşarak yere çarpan güçlü su fışkırması; çarptığı yerde ileri yürüyen dev sivri taç sıçraması
## (tepesinden beyaz sprey), ardında ıslak birikinti izi ve dalgacıklar.
static func suiton_mizurappa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var from = _mouth(c)
	L.gather(pj, from, 0.8, 10, 0.2, 0.3)
	L.spray(pj, from + d * 0.5, d, {"n": 20, "spread": 20.0, "vmin": 8.0, "vmax": 14.0, "life": 0.35, "smin": 0.2, "smax": 0.4})
	_trumpet(pj, c, pj.gp(c.global_position + d * 2.0), d, 7.0, 2.2, 16.0, pj.inf(c, "suiton_mizurappa", 0.9, {"knock": 14.0, "kind": "heavy", "element": "suiton", "dir": d}))
	pj.shake(0.4)
	Sfx.play("water", c.global_position, 0.8)


## Eski su dalgası oynanışı aynen: 1 sn'de start → start + d*dist, her karede hit_sphere(p + UP, w*0.5) (vurulan bir kez)
static func _trumpet(pj: PathJutsu, c: Node3D, start: Vector3, d: Vector3, w: float, hgt: float, dist: float, info: Dictionary) -> void:
	Sfx.play("water", start)
	var hit_list = []
	var crest = Node3D.new()
	pj.scene_add(crest, start)
	crest.rotation.y = atan2(d.x, d.z)
	var cm = L.wmi(L.liquid_crown_mesh(1), {"foam": 0.3, "alpha": 0.88, "wob": 1.2, "line": 0.1, "flow": 2.0})
	cm.scale = Vector3(w * 0.3, hgt * 1.2, w * 0.2)
	crest.add_child(cm)
	var cm2 = L.wmi(L.liquid_crown_mesh(2), {"foam": 0.5, "alpha": 0.82, "wob": 1.5, "line": 0.1, "flow": 2.0})
	cm2.scale = Vector3(w * 0.2, hgt * 0.8, w * 0.13)
	cm2.position = Vector3(0, 0, -0.6)
	crest.add_child(cm2)
	L.trail(crest, {"n": 44, "life": 0.6, "dir": Vector3(0, 1, 0.6), "spread": 35.0, "vmin": 4.0, "vmax": 9.0, "smin": 0.3, "smax": 0.6, "r": w * 0.3, "foam": 0.45})
	var jet = Node3D.new()
	pj.scene_add(jet, start)
	var jm = L.wmi(L.stream_mesh(), {"flow": 6.0, "alpha": 0.85, "foam": 0.15, "line": 0.1, "wob": 0.5})
	jet.add_child(jm)
	jet.visible = false
	var stt = {"i": 0}
	crest.scale = Vector3(1, 0.05, 1)
	var tw = crest.create_tween()
	tw.tween_property(crest, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(k: float):
		stt["i"] += 1
		var p = start + d * k * dist
		var pg = L.ground(p)
		crest.global_position = pg
		if is_instance_valid(jet):
			jet.visible = is_instance_valid(c) and _span(jet, _mouth(c), pg + Vector3.UP * 0.6 - d * 0.8)
		if stt["i"] % 4 == 0:
			L.puddle(pj, pg - d * 1.2, w * 0.3, 2.5, {"alpha": 0.5, "dir": d, "stretch": 1.6})
		if stt["i"] % 7 == 0:
			L.ripple(pj, pg - d * 0.5, 0.5, w * 0.45, 0.6)
		if is_instance_valid(c):
			hit_list.append_array(Combat.hit_sphere(c, p + Vector3.UP, w * 0.5, info, hit_list)), 0.0, 1.0, 1.0)
	tw.tween_property(crest, "scale", Vector3(1.1, 0.05, 1.1), 0.3)
	tw.tween_callback(crest.queue_free)
	# fışkırma incelip kopar
	var tj = jet.create_tween()
	tj.tween_interval(1.0)
	tj.tween_property(jm, "scale", Vector3(0.05, 0.05, 1.0), 0.25).set_ease(Tween.EASE_IN)
	tj.tween_callback(jet.queue_free)


# ================================================================== Suiton: Teppōdama
## Ağızdan fışkıran su ağzın önünde iri bir küreye toplanır; ağır, kaynayan, köpük lekeli top geriye savrulan
## sivri sprey dilleriyle uçar; çarpınca dev taç patlaması, iki halka dalga, geniş birikinti, alçak su buğusu.
static func suiton_teppodama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var from = _mouth(c) + c.face_dir() * 1.1
	L.gather(pj, from, 1.6, 18, 0.3, 1.4)
	L.spray(pj, _mouth(c), c.face_dir(), {"n": 18, "spread": 18.0, "vmin": 3.0, "vmax": 6.0, "life": 0.3, "g": Vector3(0, -4, 0), "smin": 0.25, "smax": 0.45})
	var look = func(s: float) -> Node3D:
		var core = Node3D.new()
		var ball = L.wmi(L.sphere_mesh(), {"wob": 1.4, "foam": 0.3, "flow": 1.2, "alpha": 0.88, "line": 0.09})
		ball.scale = Vector3.ONE * s * 0.9
		core.add_child(ball)
		for k in 2:   # geriye savrulan tırtıklı sprey dilleri (taç dilleri +Z = geri)
			var tail = L.wmi(L.liquid_crown_mesh(k + 2), {"foam": 0.55, "alpha": 0.8, "wob": 1.2, "line": 0.1, "flow": 3.0})
			tail.rotation = Vector3(PI * 0.5, k * 0.7, 0)
			tail.scale = Vector3(s * 0.38, s * (0.55 + k * 0.2), s * 0.38)
			tail.position = Vector3(0, 0, s * 0.15)
			core.add_child(tail)
		return core
	var launched = func(pr: Projectile, _dir: Vector3) -> void:
		L.trail(pr, {"n": 40, "life": 0.5, "vmin": 1.0, "vmax": 3.0, "dir": Vector3(0, 0.3, 1), "spread": 40.0, "smin": 0.3, "smax": 0.6, "r": 1.0,
			"foam": 0.4, "g": Vector3(0, -10, 0)})
	var impact = func(p: Vector3, _dir: Vector3) -> void:
		_teppo_hit(pj, p)
	_water_bolt(pj, c, "suiton_teppodama", pj.tg(c, t, 26.0), from, 3.0, 22.0, 1.8, {"knock": 20.0, "launch": 3.0}, 2.0, 0.3, look, launched, impact)
	pj.shake(0.3)
	Sfx.play("water", c.global_position, 0.6)


static func _teppo_hit(pj: PathJutsu, p: Vector3) -> void:
	var g = pj.gp(p)
	L.spray(pj, p, Vector3.UP, {"n": 50, "spread": 70.0, "vmin": 6.0, "vmax": 13.0, "life": 0.9, "r": 1.0, "smin": 0.25, "smax": 0.5})
	if p.y - g.y < 2.5:
		L.crown(pj, g, 1.9, {"h": 0.9, "t": 0.2, "fall": 0.6})
		L.ripple(pj, g, 1.0, 5.5, 0.7, {"alpha": 0.55})
		pj.after(0.25, func(): L.ripple(pj, g, 0.5, 3.5, 0.6, {"alpha": 0.5}))
		L.puddle(pj, g, 4.0, 5.0, {"alpha": 0.5, "spread": 0.5})
		for k in 6:
			var a = k * TAU / 6.0 + randf() * 0.4
			L.mist(pj, g + Vector3(cos(a), 0, sin(a)) * 2.5 + Vector3.UP * 0.8, randf_range(3.0, 4.5), 1.4, {"alpha": 0.5, "near": 3.0,
				"drift": Vector3(cos(a), 0.3, sin(a)) * 2.0, "fin": 0.05, "fout": 0.6})
	else:
		L.spray(pj, p, Vector3.DOWN, {"n": 30, "spread": 180.0, "vmin": 4.0, "vmax": 9.0, "life": 0.8, "r": 1.0, "smin": 0.3, "smax": 0.6, "foam": 0.3})


# ================================================================== Suiton: Mizuame Nabara
## Ağızdan yay çizerek dökülen kıvamlı, amber-şeffaf şurup; yerde ağır topaklar halinde çöker, kalın dalgalı sırtlı
## geniş yapışkan göle yayılır; içine basanların ayağında uzayıp kopan şurup telleri.
static func suiton_mizuame_nabara(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 5.0)
	var m0 = _mouth(c)
	var pts = []
	var rad = []
	for i in 12:
		var u = i / 11.0
		pts.append(m0.lerp(at, u) + Vector3.UP * (1.4 * u * (1.0 - u)))
		rad.append(0.12 + 0.32 * u * u)
	var pour = L.wmi(L.tube_mesh(pts, rad, 12), {"pal": L.SYRUP, "flow": 0.8, "alpha": 0.8, "wob": 0.6, "line": 0.1, "fade": 0.0})
	L.put(pj, pour, Vector3.ZERO)
	var tp = pour.create_tween()
	tp.tween_method(func(v: float): pour.set_instance_shader_parameter("fade", v), 0.0, 1.0, 0.1)
	tp.tween_interval(0.25)
	tp.tween_method(func(v: float): pour.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tp.tween_callback(pour.queue_free)
	pj.after(0.15, func():
		L.spray(pj, at + Vector3.UP * 0.3, Vector3.UP, {"n": 14, "spread": 50.0, "vmin": 2.0, "vmax": 4.0, "g": Vector3(0, -16, 0), "life": 0.6,
			"smin": 0.35, "smax": 0.6, "pal": L.SYRUP, "align": false, "mesh": L.sphere_mesh(), "alpha": 0.85}))
	pj.after(0.3, func():
		var pool = Node3D.new()
		pj.scene_add(pool, at + Vector3.UP * 0.04)
		var pm = L.wmi(L.puddle_mesh(randi() % 6), {"pal": L.SYRUP, "alpha": 0.72, "ripple": 0.12, "wob": 0.25, "line": 0.0, "flow": 0.2, "flat": 1.0})
		pm.scale = Vector3(4.5, 1.0, 4.5)
		pm.sorting_offset = -1.0
		pool.add_child(pm)
		for k in 3:   # kalın dalgalı şurup sırtları
			var rg = L.wmi(L.ring_mesh(), {"pal": L.SYRUP, "alpha": 0.85, "line": 0.0, "wob": 0.8, "flow": 0.3, "flat": 1.0})
			var rr = 4.5 * (0.45 + k * 0.26)
			rg.scale = Vector3(rr, 4.0, rr)
			pool.add_child(rg)
			var pulse = Game.safe_loops(rg.create_tween())
			pulse.tween_property(rg, "scale", Vector3(rr * 1.05, 5.0, rr * 1.05), 1.1 + k * 0.3).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(rg, "scale", Vector3(rr, 4.0, rr), 1.1 + k * 0.3).set_trans(Tween.TRANS_SINE)
		pool.scale = Vector3(0.1, 1, 0.1)
		var tw = pool.create_tween()
		tw.tween_property(pool, "scale", Vector3.ONE, 0.5)
		tw.tween_interval(9.0)
		tw.tween_property(pool, "scale", Vector3(0.1, 1, 0.1), 0.5)
		tw.tween_callback(pool.queue_free))
	pj.every(10.0, 0.5, func(i, _k):
		for e in pj.enemies_near(c, at, 4.5):
			pj.st(e, "bind", 0.6)
			if i % 3 == 0:
				_syrup_strands(pj, e.global_position), Callable())
	Sfx.play("water", at, 0.6)


## Ayakta uzayıp incelerek kopan yapışkan teller
static func _syrup_strands(pj: PathJutsu, pos: Vector3) -> void:
	var g = pj.gp(pos)
	for k in 3:
		var a = randf() * TAU
		var hgt = randf_range(0.5, 0.9)
		var s = L.wmi(L.tube_mesh([Vector3.ZERO, Vector3(0, hgt * 0.5, 0), Vector3(0, hgt, 0)], [0.07, 0.03, 0.05], 6), {"pal": L.SYRUP, "alpha": 0.85, "line": 0.15})
		L.put(pj, s, g + Vector3(cos(a), 0, sin(a)) * 0.25)
		s.scale = Vector3(1, 0.1, 1)
		var tw = s.create_tween()
		tw.tween_property(s, "scale", Vector3(0.9, 1.0, 0.9), 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3(0.15, 1.15, 0.15), 0.4).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)


# ================================================================== Suiton: Hōmatsu Rappa
## Ağızdan kabaran beyaz köpük seli (köpük topakları + sürüklenen köpük izi); önünde yuvarlanan sabun köpükleri,
## yerde kalan kaygan köpük yığınları ve köpüklü ıslak leke.
static func suiton_homatsu_rappa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var from = _mouth(c)
	var side = d.cross(Vector3.UP).normalized()
	for i in 3:
		pj.after(i * 0.05, func():
			if pj.live(c):
				_foam_jet(pj, c, from, (d - Vector3.UP * 0.25 + side * (i - 1) * 0.15).normalized(), pj.inf(c, "suiton_homatsu_rappa", 0.15, {"element": "suiton"})))
	for k in 10:
		pj.after(0.1 + k * 0.06, func():
			var q = pj.gp(c.global_position + d * (2.0 + k * 1.2)) + Vector3.UP * 0.4
			for b in 3:
				L.bubble(pj, q + Vector3(randf_range(-1, 1), randf_range(0, 1.2), randf_range(-1, 1)), randf_range(0.25, 0.55), randf_range(0.8, 1.6),
					d * randf_range(0.5, 1.5) + Vector3.UP * randf_range(0.2, 0.7))
			_foam_heap(pj, pj.gp(q), randf_range(0.7, 1.0), 2.6)
			if k % 2 == 0:
				L.puddle(pj, q, 1.4, 2.6, {"alpha": 0.45, "foam": 0.35, "ripple": 0.0})
			for e in pj.hit(c, q, 2.0, pj.inf(c, "suiton_homatsu_rappa", 0.15, {"knock": 6.0, "kind": "light", "element": "suiton", "dir": d})):
				pj.st(e, "slow", 3.0))
	Sfx.play("water", c.global_position, 0.8)


## Eski su ipi mermisi oynanışı aynen (hız 20, yarıçap max(0.5, 0.7), güdümsüz, ömür 0.6); görünüş: köpük topağı başlık + köpük izi
static func _foam_jet(pj: PathJutsu, c: Node3D, from: Vector3, dir: Vector3, info: Dictionary) -> void:
	var head = Node3D.new()
	for b in 3:
		var f = L.wmi(L.sphere_mesh(), {"foam": 1.0, "alpha": 0.95, "line": 0.12, "wob": 1.2})
		f.position = Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.1, 0.3))
		f.scale = Vector3.ONE * randf_range(0.35, 0.6)
		head.add_child(f)
	var pr = pj.shot(c, from, dir, 20.0, head, info, null, false, 0.6, func(p, _h):
		_foam_heap(pj, pj.gp(p), 0.8, 2.0)
		L.spray(pj, p, Vector3.UP, {"n": 10, "spread": 70.0, "vmin": 1.5, "vmax": 3.5, "life": 0.5, "smin": 0.25, "smax": 0.45, "foam": 1.0,
			"align": false, "mesh": L.sphere_mesh(), "g": Vector3(0, -6, 0)}))
	pr.radius = maxf(0.5, 0.7)
	L.trail(pr, {"n": 24, "life": 0.5, "vmin": 0.3, "vmax": 1.2, "spread": 60.0, "g": Vector3(0, -2, 0), "smin": 0.35, "smax": 0.7, "foam": 1.0,
		"mesh": L.sphere_mesh(), "align": false, "r": 0.3, "damp": 2.0})


## Yerde kabarıp yavaşça sönen köpük yığını (beyaz topak kümesi)
static func _foam_heap(pj: PathJutsu, g: Vector3, s: float, life: float) -> void:
	var heap = Node3D.new()
	pj.scene_add(heap, g)
	for k in 5:
		var f = L.wmi(L.sphere_mesh(), {"foam": 1.0, "alpha": 0.95, "line": 0.12, "wob": 0.8})
		var a = randf() * TAU
		var rr = randf_range(0.0, 0.5) * s
		f.position = Vector3(cos(a) * rr, 0.1 * s, sin(a) * rr)
		var sz = randf_range(0.4, 0.75) * s
		f.scale = Vector3(sz, sz * 0.6, sz)
		heap.add_child(f)
	heap.scale = Vector3.ONE * 0.1
	var tw = heap.create_tween()
	tw.tween_property(heap, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life)
	tw.tween_property(heap, "scale", Vector3(1.2, 0.05, 1.2), 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(heap.queue_free)


# ================================================================== Suiton: Takitsubo no Jutsu
## Şelale çanağı: hedefin üstünde kaynayan su ağzı açılır, yukarıdan aşağı akan çizgili şelale perdesi iner;
## dibinde beyaz köpük-buğu bulutları, taç sıçraması; su kesilince kuyruğu yere iner, geniş birikinti kalır.
static func suiton_takitsubo_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.8)
	pj.anim(c, "crouch", 1.4)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	# hazırlık: yerde su kaynar, tepede su ağzı kabarır
	L.ripple(pj, at, 0.5, 5.0, 0.4)
	L.spray(pj, at + Vector3.UP * 0.2, Vector3.UP, {"n": 16, "spread": 35.0, "vmin": 1.5, "vmax": 3.5, "life": 0.4, "r": 2.0, "smin": 0.15, "smax": 0.3})
	var lip = L.wmi(L.sphere_mesh(), {"foam": 0.55, "alpha": 0.9, "wob": 2.0, "flow": 2.0, "line": 0.1})
	L.put(pj, lip, at + Vector3.UP * 9.6)
	lip.scale = Vector3(0.2, 0.1, 0.2)
	var tl = lip.create_tween()
	tl.tween_property(lip, "scale", Vector3(4.4, 1.2, 4.4), 0.25).set_ease(Tween.EASE_OUT)
	tl.tween_interval(0.6)
	tl.tween_property(lip, "scale", Vector3(0.3, 0.1, 0.3), 0.35).set_ease(Tween.EASE_IN)
	tl.tween_callback(lip.queue_free)
	pj.after(0.25, func():
		var top = Node3D.new()
		pj.scene_add(top, at + Vector3.UP * 9.5)
		var col = L.wmi(L.fall_mesh(), {"flow": 3.0, "streak": 6.0, "alpha": 0.82, "foam": 0.32, "line": 0.1, "wob": 0.4})
		top.add_child(col)
		col.scale = Vector3(1, 9.5, 1)
		top.scale = Vector3(1, 0.02, 1)
		var tw = top.create_tween()
		tw.tween_property(top, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.6)
		# su kesilir: kuyruk yere iner
		tw.tween_property(top, "scale", Vector3(0.7, 0.02, 0.7), 0.35).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(top, "global_position", at, 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(top.queue_free)
		# perdenin yüzeyinde aşağı düşen beyaz su çizgileri
		var rain = L.particles({"n": 60, "life": 0.55, "dir": Vector3.DOWN, "spread": 3.0, "vmin": 13.0, "vmax": 17.0, "g": Vector3(0, -8, 0),
			"smin": 0.3, "smax": 0.55, "r": 1.5, "one_shot": false, "burst": 0.0, "foam": 0.85, "alpha": 0.85, "line": 0.1})
		L.put(pj, rain, at + Vector3.UP * 9.3)
		rain.emitting = true
		pj.after(0.8, func():
			if is_instance_valid(rain):
				rain.emitting = false)
		L.free_later(pj, rain, 2.0)
		pj.after(0.15, func():
			L.crown(pj, at, 1.8, {"h": 1.0, "t": 0.15, "fall": 0.6, "foam": 0.35})
			L.spray(pj, at + Vector3.UP * 0.5, Vector3.UP, {"n": 60, "spread": 70.0, "vmin": 5.0, "vmax": 11.0, "life": 0.8, "r": 1.8, "smin": 0.3, "smax": 0.6})
			for k in 8:
				var a = k * TAU / 8.0 + randf() * 0.3
				L.mist(pj, at + Vector3(cos(a), 0, sin(a)) * 2.2 + Vector3.UP * randf_range(0.6, 1.6), randf_range(2.6, 3.8), 1.3,
					{"alpha": 0.8, "near": 3.0, "drift": Vector3(cos(a), 0.25, sin(a)) * 2.5, "fin": 0.06, "fout": 0.55}))
		pj.hit(c, at + Vector3.UP, 3.5, pj.inf(c, "suiton_takitsubo_no_jutsu", 1.2, {"knock": 6.0, "launch": 15.0, "kind": "heavy", "element": "suiton"}))
		L.puddle(pj, at, 3.6, 4.0, {"alpha": 0.6, "spread": 0.6})
		pj.shake(0.5))
	Sfx.play("water", at, 0.6)


# ================================================================== Suiton: Mizu Shibari
## Elden savrulan su kamçısı hedefe yay çizer; hedefin gövdesini zıt yönde dönen iki yassı su şeridi sarar
## (içerde parıltı damlaları); bağ bitince şeritler çözülüp yere dökülür.
static func suiton_mizu_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.6)
	if tt == null:
		return
	var at = tt.global_position
	var bs = ClanJutsu.body_scale(tt)
	# kamçı: elden hedefe yay çizen yassı su şeridi
	var h0 = pj.hand_pos(c, true)
	var chest = at + Vector3.UP * tt.height * 0.55
	var sd = (chest - h0).cross(Vector3.UP).normalized()
	var wp = []
	var wr = []
	for i in 16:
		var u = i / 15.0
		var mid = h0.lerp(chest, 0.5) + Vector3.UP * 1.6 + sd * 1.4
		wp.append(h0.lerp(mid, u).lerp(mid.lerp(chest, u), u))
		wr.append(0.05 + 0.11 * sin(PI * u))
	var whip = L.wmi(L.tube_mesh(wp, wr, 6, 0.35, Vector3.UP), {"flow": 4.0, "alpha": 0.9, "line": 0.12, "fade": 0.0})
	L.put(pj, whip, Vector3.ZERO)
	var tw0 = whip.create_tween()
	tw0.tween_method(func(v: float): whip.set_instance_shader_parameter("fade", v), 0.0, 1.0, 0.08)
	tw0.tween_method(func(v: float): whip.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw0.tween_callback(whip.queue_free)
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_position = at
	for k in 2:
		var mi = L.wmi(L.helix_mesh((0.62 - k * 0.1) * bs, tt.height * 0.95, 2.2 - k * 0.4, 0.17 * bs, k * 1.7), {"flow": 3.0, "alpha": 0.88, "foam": 0.15, "line": 0.12, "wob": 0.5})
		root.add_child(mi)
		var spin = Game.safe_loops(mi.create_tween())
		spin.tween_property(mi, "rotation:y", TAU * (1 if k == 0 else -1), 0.9).from(0.0)
	var glint = L.particles({"n": 12, "life": 0.6, "dir": Vector3.UP, "spread": 180.0, "vmin": 0.3, "vmax": 0.8, "g": Vector3.ZERO, "smin": 0.08, "smax": 0.14,
		"r": 0.6 * bs, "align": false, "mesh": L.sphere_mesh(), "one_shot": false, "burst": 0.0, "foam": 1.0, "alpha": 0.9})
	root.add_child(glint)
	glint.position = Vector3.UP * tt.height * 0.5
	glint.emitting = true
	root.scale = Vector3(1, 0.02, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.7)
	tw.tween_callback(func():
		var g = L.ground(at)
		L.spray(pj, at + Vector3.UP * tt.height * 0.5 if is_instance_valid(tt) else at + Vector3.UP, Vector3.UP, {"n": 30, "spread": 80.0, "vmin": 2.0, "vmax": 5.0,
			"life": 0.6, "r": 0.6, "smin": 0.2, "smax": 0.4})
		L.puddle(pj, g, 1.4, 2.5, {"alpha": 0.5}))
	tw.tween_callback(root.queue_free)
	pj.st(tt, "bind", 3.0)
	pj.every(3.0, 0.5, func(_i, _k):
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "suiton_mizu_shibari", 0.12, {"knock": 0.0, "kind": "light", "element": "suiton"})), Callable())
	L.ripple(pj, at, 0.3, 2.2, 0.45)
	L.spray(pj, at + Vector3.UP * 0.3, Vector3.UP, {"n": 16, "spread": 40.0, "vmin": 3.0, "vmax": 6.0, "life": 0.45, "r": 0.5, "smin": 0.15, "smax": 0.3})
	Sfx.play("water", at, 0.9)


# ================================================================== Köpük Klonu (Bubble Clone)
## Ağızdan çıkan sabun köpükleri yana süzülüp birleşir, gökkuşağı zarlı iki küreden (gövde + baş) saydam bir beden kabarır;
## vurulunca zar parçalanır: onlarca küçük köpük ve ince damla saçılır, çevredekiler sersemler.
static func bubble_clone_technique(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = c.global_position + c.face_dir().cross(Vector3.UP) * 2.5
	var m0 = _mouth(c)
	for k in 7:   # hazırlık: ağızdan çıkıp hedef noktaya süzülen köpükler (varınca bedene karışır)
		var s0 = m0 + Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), randf_range(-0.15, 0.15))
		var lf = randf_range(0.32, 0.45)
		L.bubble(pj, s0, randf_range(0.18, 0.32), lf, (at + Vector3.UP * randf_range(0.6, 1.6) - s0) / lf, false)
	var bub = Node3D.new()
	for part in [[Vector3(0, 0.62, 0), 1.24], [Vector3(0, 1.58, 0), 0.8]]:
		var mi = MeshInstance3D.new()
		mi.mesh = L.sphere_mesh()
		mi.material_override = L.bubble_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("seed", randf() * 10.0)
		mi.position = part[0]
		mi.scale = Vector3.ONE * float(part[1])
		bub.add_child(mi)
	pj.get_tree().current_scene.add_child(bub)
	bub.global_position = pj.gp(at)
	bub.scale = Vector3.ONE * 0.05
	bub.create_tween().tween_property(bub, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	for k in 10:
		L.bubble(pj, at + Vector3(randf_range(-1, 1), randf_range(0.3, 1.8), randf_range(-1, 1)), randf_range(0.12, 0.25), randf_range(0.6, 1.2),
			Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 1.0), randf_range(-0.4, 0.4)))
	var d = pj.decoy(c, at, 8.0, func(pos):
		if is_instance_valid(bub):
			bub.queue_free()
		_clone_pop(pj, pos)
		for e in pj.hit(c, pos + Vector3.UP, 3.5, pj.inf(c, "bubble_clone_technique", 0.5, {"knock": 6.0, "kind": "heavy", "element": "suiton"})):
			pj.st(e, "stun", 1.5)
		Sfx.play("water", pos, 1.3))
	if d:
		d.visible = false
		pj.every(8.0, 0.1, func(_i, _k):
			if is_instance_valid(bub) and is_instance_valid(d):
				bub.global_position = d.global_position, Callable())
	pj.free_after(8.2, bub)
	Sfx.play("water", at, 1.5)


static func _clone_pop(pj: PathJutsu, pos: Vector3) -> void:
	var cen = pos + Vector3.UP
	for k in 24:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		L.bubble(pj, cen + dv * randf_range(0.2, 0.9), randf_range(0.1, 0.3), randf_range(0.4, 0.9), dv * randf_range(2.0, 5.0))
	L.spray(pj, cen, Vector3.UP, {"n": 40, "spread": 180.0, "vmin": 3.0, "vmax": 7.0, "life": 0.5, "r": 0.8, "smin": 0.15, "smax": 0.3, "foam": 0.5, "alpha": 0.75})
	L.ripple(pj, pos, 0.4, 3.0, 0.5, {"alpha": 0.6})
	L.puddle(pj, pos, 1.2, 2.0, {"alpha": 0.4, "foam": 0.3})


# ================================================================== Shimogakure no Jutsu
## Kırağı gizlenmesi: ayak altından yayılan beyaz kırağı örtüsü ve dikilen buz iğneleri, parıldayan soğuk sis,
## yavaşça yağan kırağı tozu; atan kırağı parıltısı içinde görünmez olur.
static func shimogakure_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = pj.gp(c.global_position)
	L.puddle(pj, at, 6.0, 4.6, {"pal": L.FROST, "alpha": 0.82, "foam": 0.5, "ripple": 0.0, "spread": 0.6, "lift": 0.04})
	for k in 18:
		var a = randf() * TAU
		var rr = randf_range(0.8, 5.0)
		var cr = L.wmi(L.dart_mesh(), {"pal": L.FROST, "alpha": 0.9, "foam": 0.3, "line": 0.12})
		L.put(pj, cr, pj.gp(at + Vector3(cos(a), 0, sin(a)) * rr))
		cr.rotation = Vector3(PI * 0.5 + randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		var sz = randf_range(0.5, 1.1)
		cr.scale = Vector3(sz, sz, 0.05)
		var tc = cr.create_tween()
		tc.tween_interval(rr * 0.05)
		tc.tween_property(cr, "scale", Vector3(sz, sz, sz * 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tc.tween_interval(4.6)
		tc.tween_method(func(v: float): cr.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.6)
		tc.tween_callback(cr.queue_free)
	var dust = L.particles({"n": 40, "life": 1.6, "dir": Vector3.DOWN, "spread": 30.0, "vmin": 0.3, "vmax": 0.8, "g": Vector3(0, -0.6, 0), "smin": 0.06, "smax": 0.12,
		"r": 5.0, "align": false, "mesh": L.sphere_mesh(), "one_shot": false, "burst": 0.0, "pal": L.FROST, "foam": 1.0, "alpha": 0.95, "line": 0.0})
	L.put(pj, dust, at + Vector3.UP * 4.0)
	dust.emitting = true
	pj.after(5.0, func():
		if is_instance_valid(dust):
			dust.emitting = false)
	L.free_later(pj, dust, 7.0)
	pj.every(5.0, 0.2, func(_i, _k):
		for j in 2:
			var a = randf() * TAU
			var rr = randf_range(0.5, 5.0)
			L.mist(pj, at + Vector3(cos(a) * rr, randf_range(0.4, 1.6), sin(a) * rr), randf_range(3.0, 4.6), 1.8, {"tone": 1.0, "sparkle": 1.0, "alpha": 0.6,
				"near": 3.0, "drift": Vector3(-sin(a), 0.3, cos(a)) * 1.2, "fin": 0.25, "fout": 0.4}), Callable())
	# gizlenme (oyunun genel "stealth" kuralı aynen)
	var d: Dictionary = Data.jutsu.get("shimogakure_no_jutsu", {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in c.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	# beden kırağı parıltısına dağılır
	L.spray(pj, c.global_position + Vector3.UP, Vector3.UP, {"n": 30, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "life": 0.7, "r": 0.6, "g": Vector3(0, -1, 0),
		"smin": 0.08, "smax": 0.16, "align": false, "mesh": L.sphere_mesh(), "pal": L.FROST, "foam": 1.0, "alpha": 0.95})
	if c.get("model"):
		c.model.visible = false
		c.get_tree().create_timer(minf(dur, 4.0)).timeout.connect(func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = true)
	Sfx.play("poof", c.global_position)


# ================================================================== Suiton: Kokuu no Jutsu
## Kara yağmur: ağızdan göğe kara mürekkep fışkırır, hedefin üstünde kara bulut kabarır; dikey kara damla çizgileri
## yağar, değdikleri yerde kara lekeler kalır; ardından parlak kara yağ gölü (içinde kabarcıklar) — içindekiler yavaşlar.
static func suiton_kokuu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var gz = Node3D.new()
	pj.scene_add(gz, _mouth(c))
	var gm = L.wmi(L.geyser_mesh(), {"pal": L.INK, "flow": 4.0, "alpha": 0.95, "line": 0.1, "wob": 0.6})
	gm.scale = Vector3(1, 7.0, 1)
	gz.add_child(gm)
	gz.scale = Vector3(1, 0.02, 1)
	var tg0 = gz.create_tween()
	tg0.tween_property(gz, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tg0.tween_interval(0.15)
	tg0.tween_property(gz, "global_position", gz.global_position + Vector3.UP * 7.0, 0.3).set_ease(Tween.EASE_IN)
	tg0.parallel().tween_property(gz, "scale", Vector3(0.6, 0.02, 0.6), 0.3).set_ease(Tween.EASE_IN)
	tg0.tween_callback(gz.queue_free)
	for k in 22:
		var a = randf() * TAU
		var rr = randf_range(0.0, 5.0)
		L.mist(pj, at + Vector3(cos(a) * rr, 8.5 + randf_range(-0.6, 0.8), sin(a) * rr), randf_range(3.5, 5.5), 2.4, {"tone": 2.0, "alpha": 0.85,
			"near": 3.0, "s0": 0.3, "grow": 0.25, "drift": Vector3(cos(a), 0.1, sin(a)) * 1.2, "fin": 0.12, "fout": 0.35})
	for k in 60:
		pj.after(0.4 + randf() * 1.2, func():
			var q = at + Vector3(randf_range(-6, 6), 8.0, randf_range(-6, 6))
			var dr = L.wmi(L.drop_y_mesh(), {"pal": L.INK, "alpha": 0.95, "line": 0.0})
			pj.get_tree().current_scene.add_child(dr)
			dr.global_position = q
			dr.rotation.z = PI   # yuvarlak baş aşağıda (düşüş yönü)
			dr.scale = Vector3(0.35, 1.6, 0.35)
			var tw = dr.create_tween()
			tw.tween_property(dr, "global_position", pj.gp(q), 0.45).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				var g = pj.gp(q)
				L.puddle(pj, g, randf_range(0.2, 0.42), 7.0, {"pal": L.INK, "alpha": 0.95, "ripple": 0.0, "spread": 0.1, "lift": 0.035})
				L.spray(pj, g + Vector3.UP * 0.05, Vector3.UP, {"n": 4, "spread": 60.0, "vmin": 1.0, "vmax": 2.2, "life": 0.35, "smin": 0.1, "smax": 0.16, "pal": L.INK, "line": 0.0})
				dr.queue_free()))
	pj.after(1.0, func():
		_ink_pool(pj, c, at, 6.0, 8.0))
	Sfx.play("water", at, 0.5)


## Yağ gölü oynanışı (eski _oil_pool aynen): dur boyunca 0.15 sn'de bir, her üçüncüde r içindeki düşmanlar 1 sn yavaş
static func _ink_pool(pj: PathJutsu, c: Node3D, at: Vector3, r: float, dur: float) -> void:
	at = pj.gp(at)
	var pool = L.wmi(L.puddle_mesh(randi() % 6), {"pal": L.INK, "alpha": 0.93, "ripple": 0.3, "line": 0.0, "flow": 0.2, "wob": 0.2, "flat": 1.0})
	pool.sorting_offset = -1.0
	L.put(pj, pool, at + Vector3.UP * 0.045)
	pool.rotation.y = randf() * TAU
	pool.scale = Vector3(r * 0.3, 1.0, r * 0.3)
	pool.create_tween().tween_property(pool, "scale", Vector3(r, 1.0, r), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pj.every(dur, 0.15, func(i, _k):
		if i % 2 == 0:
			var b = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * r * 0.7
			var bl = L.wmi(L.sphere_mesh(), {"pal": L.INK, "alpha": 0.95, "line": 0.15})
			L.put(pj, bl, pj.gp(b) + Vector3.UP * 0.05)
			bl.scale = Vector3(0.05, 0.03, 0.05)
			var sz = randf_range(0.18, 0.35)
			var tb = bl.create_tween()
			tb.tween_property(bl, "scale", Vector3(sz, sz * 0.7, sz), 0.3).set_ease(Tween.EASE_OUT)
			tb.tween_callback(func():
				L.spray(pj, bl.global_position + Vector3.UP * 0.1, Vector3.UP, {"n": 3, "spread": 50.0, "vmin": 0.6, "vmax": 1.4, "life": 0.3, "smin": 0.06, "smax": 0.1, "pal": L.INK, "line": 0.0})
				bl.queue_free())
		if i % 3 == 0:
			for e in pj.enemies_near(c, at, r):
				pj.st(e, "slow", 1.0), func():
		if is_instance_valid(pool):
			L.fade_free(pool, 0.0, 1.0))
