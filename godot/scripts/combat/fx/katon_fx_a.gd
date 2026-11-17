class_name KatonFXA
extends RefCounted
## Katon grubu A: on beş ateş tekniğinin görselleri — malzeme ve yapı taşları KatonLib'den (kendi alev shader'ları),
## her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const FIRE_L := Color(1.0, 0.6, 0.2)
const BLUE_L := Color(0.4, 0.6, 1.0)
const CRIM_L := Color(1.0, 0.25, 0.15)

static var _cache := {}


# ================================================================== ortak oynanış izleri (eski patlama / çatlak çağrılarının oyun etkisi)
## Eski ateş patlamasının oyun tarafı: yakın saç/kumaş savrulur, zemine yakınsa yanan zemin bölgesi, sarsıntı, patlama sesi
static func _blast_marks(pos: Vector3, s: float) -> void:
	Dangle.blast(pos, 40.0 * s, 6.0 * s)
	var g = KatonLib.floor_at(pos)
	if pos.y - g.y < 3.0 * s:
		GroundFX.add(g + Vector3.UP * 0.12, "burning", 1.2 * s + 0.8, 4.0)
	if Game.world:
		Game.world.env.add_shake(0.7 * s)
	Sfx.play("boom", pos)


## Eski zemin çatlağının oyun tarafı: büyük yarık zemin üstünden geçeni yavaşlatır
static func _crack_zone(pos: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(pos, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


## Element mermisi çarpmasının oyun tarafı (ateş): patlama izi + zemine yakınsa yarık + sarsıntı
static func _bolt_marks(pj: PathJutsu, at: Vector3, s: float, ep: float) -> void:
	_blast_marks(at, 1.1 * s * ep)
	var g = KatonLib.floor_at(at)
	if at.y - g.y < 2.5:
		_crack_zone(g, 3.0 * s * ep, 6.0)
	pj.shake(0.25 + 0.25 * s)


## Element mermisi (eski ortak atışın oynanışı birebir): delay sonra ağızdan nişana, info/yarıçap/ömür aynı.
## body: mermi görselini kuran Callable, tick: uçuş görseli (p, dt), boom: çarpma görseli (pos, ep)
static func _bolt(pj: PathJutsu, c: Node3D, id: String, tt: Node3D, from: Vector3, size: float, speed: float, mul: float, extra: Dictionary, impact_s: float, delay: float, body: Callable, tick: Callable, boom: Callable) -> void:
	pj.after(delay, func():
		if not pj.live(c):
			return
		var info = {"knock": 8.0 * impact_s, "kind": "heavy", "element": "katon", "hitstop": 0.05}
		info.merge(extra, true)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), speed, body.call(), pj.inf(c, id, mul, info), null, false, 1.6)
		pr.radius = 0.35 + size * 0.4
		var ep = pr.epic
		pr.on_hit = func(p: Vector3, _h: Node3D) -> void:
			boom.call(p, ep)
			_bolt_marks(pj, p, impact_s, ep)
		if tick.is_valid():
			pr.on_tick = tick)


## Yakın dövüş isabetinde (eski isabet kıvılcımı yerine) kısa ateş parlaması: hale + dışa yalayan diller + kor
static func _hit_flare(pj: PathJutsu, at: Vector3, s: float, pal := 0.0) -> void:
	KatonLib.glow(pj, at, 2.2 * s, KatonLib.pal_col(pal, 1), 0.3)
	for k in 5:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
		KatonLib.tongue(pj, at, randf_range(0.6, 1.1) * s, 0.45 * s, 0.3, dv, dv * 2.0, pal, 3)
	KatonLib.embers(pj, at, 10, 0.3, pal, {"vmin": 2.0, "vmax": 6.0, "spread": 160.0, "life": 0.7})


static func _dark_mat(col: Color) -> StandardMaterial3D:
	var key = "dark_%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


static func _flat(b: MB) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(KatonLib.flat_mat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ================================================================== 1) Hōsenka: gizli şurikenli küçük ateş topları
## Kanon: ağızdan art arda küçük, uzamış alev topları; her birinin içinde gizli bir şuriken — alev sönünce şuriken yoluna devam eder.
static func katon_housenka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	# hazırlık: dudaklarda titreyen kısa diller + ağızda ısı dalgası (toplanma küresi değil)
	var mo0 = pj._mouth_pos(c)
	for q in 4:
		KatonLib.tongue(pj, mo0 + c.face_dir() * 0.1, 0.45, 0.25, 0.3, (c.face_dir() + Vector3.UP * 0.4).normalized(), c.face_dir() * 0.6, KatonLib.PAL_FIRE, 3)
	KatonLib.shimmer(pj, mo0 + c.face_dir() * 0.6, 0.9, 0.9, 0.5)
	# --- oynanış (Jutsu.j_katon_housenka'dan birebir)
	var m = Jutsu._mult(c) * Jutsu._elem_bonus(c, "katon")
	var dir = Jutsu._aim(c, t)
	Sfx.play("fire", c.global_position, 1.3)
	for i in 5:
		var d = dir.rotated(Vector3.UP, deg_to_rad(-24 + i * 12)) + Vector3.UP * randf_range(0.0, 0.15)
		var pr = Projectile.new()
		pr.shooter = c
		pr.vel = d.normalized() * 22.0
		pr.radius = 0.6
		pr.life = 2.2
		pr.homing = t
		pr.homing_turn = 2.5
		pr.info = {"dmg": 8.0 * m, "element": "katon", "knock": 3.0, "kind": "light", "hitstop": 0.02, "burn": 1.5}
		var vis = _housenka_body()
		pr.add_child(vis)
		var star: Node3D = vis.get_node("star")
		var cnt = {"n": i}
		pr.on_tick = func(p: Projectile, dt: float) -> void:
			if is_instance_valid(star):
				star.rotate_object_local(Vector3.FORWARD, dt * 28.0)
			cnt["n"] += 1
			if cnt["n"] % 3 == 0:
				var back = -p.vel.normalized()
				KatonLib.tongue(pj, p.global_position + back * 0.4, randf_range(0.7, 1.0), 0.45, 0.22, (back + Vector3.UP * 0.25).normalized(), back * 2.0, KatonLib.PAL_FIRE, 3, 1.0)
		pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
			_housenka_pop(pj, pos, pr.vel, pr.epic)
		pj.get_tree().current_scene.add_child(pr)
		pr.global_position = Jutsu._mouth(c) + d * 0.6


## Uzamış küçük alev topu (-Z ileri): önde yoğun çekirdek, arkaya uzanan kuyruk kütlesi ve diller; içinde dönen şuriken
static func _housenka_body() -> Node3D:
	var root = Node3D.new()
	var core = KatonLib.mass_mi(0.36, KatonLib.PAL_FIRE, 1.35, 1.8)
	core.position = Vector3(0, 0, -0.05)
	root.add_child(core)
	var tail = KatonLib.mass_mi(0.3, KatonLib.PAL_FIRE, 1.0, 2.2)
	tail.scale = Vector3(0.28, 0.28, 0.6)
	tail.position = Vector3(0, 0.03, 0.45)
	root.add_child(tail)
	for k in 3:
		var a = k * TAU / 3.0
		var tg = KatonLib.tongue_mi(1.1, 0.42, Vector3(cos(a) * 0.3, sin(a) * 0.3, 1.0), KatonLib.PAL_FIRE, 3, 0.0, 1.05)
		tg.position = Vector3(cos(a) * 0.12, sin(a) * 0.12, 0.15)
		root.add_child(tg)
	var star = Node3D.new()
	star.name = "star"
	star.position = Vector3(0, 0, -0.1)
	var b = MB.new()
	var steel = Color(0.32, 0.33, 0.38)
	for k in 4:
		var a = k * 90.0
		var off = Vector3(0, 0.15, 0).rotated(Vector3.BACK, deg_to_rad(a))
		b.add("cone", off, Vector3(0.1, 0.28, 0.02), steel, Vector3(0, 0, a), 4)
	b.add("cyl", Vector3.ZERO, Vector3(0.08, 0.025, 0.08), steel.darkened(0.4), Vector3(90, 0, 0), 8)
	star.add_child(_flat(b))
	root.add_child(star)
	return root


## Küçük patlama: alev kütlesi açılır, diller saçılır; içindeki şuriken alevden çıkıp yoluna devam eder ve yere düşer
static func _housenka_pop(pj: PathJutsu, pos: Vector3, vel: Vector3, ep: float) -> void:
	var s = 0.45 * ep
	var fwd = vel.normalized() if vel.length() > 0.1 else Vector3.FORWARD
	KatonLib.mass(pj, pos, 0.3, 1.2 * s + 0.4, 0.4, Vector3.UP * 0.8, KatonLib.PAL_FIRE, 1.3, 2.0)
	for k in 6:
		var dv = (Vector3(randf_range(-1, 1), randf_range(-0.1, 1.0), randf_range(-1, 1)) + fwd * 0.6).normalized()
		KatonLib.tongue(pj, pos, randf_range(0.8, 1.3) * (0.6 + s), 0.5, 0.35, dv, dv * 2.5, KatonLib.PAL_FIRE, 3)
	KatonLib.embers(pj, pos, 14, 0.3, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 6.0, "spread": 120.0, "life": 0.9})
	KatonLib.light(pj, pos, FIRE_L, 4.0, 6.0, 0.35)
	var g = KatonLib.floor_at(pos)
	if pos.y - g.y < 1.5:
		KatonLib.scorch(pj, g, 0.9 + s, 3.0)
	# şuriken alevden kurtulur: dönerek ileri savrulur ve yere düşer
	var b = MB.new()
	var steel = Color(0.4, 0.41, 0.46)
	for k in 4:
		var a = k * 90.0
		b.add("cone", Vector3(0, 0.15, 0).rotated(Vector3.BACK, deg_to_rad(a)), Vector3(0.1, 0.28, 0.02), steel, Vector3(0, 0, a), 4)
	KatonLib.toss(pj, _flat(b), pos + fwd * 0.3, fwd * 6.0 + Vector3.UP * 2.5, 0.9, 16.0)
	_blast_marks(pos, s)


# ================================================================== 2) Endan: kabaran akan alev topları
## Ağızdan art arda üç yuvarlanan, arkasında kabaran alev bulutu bırakan alev topu; çarpınca yassı alev sıçraması ve kavruk iz.
static func katon_endan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.55)
	var tt = pj.tg(c, t, 26.0)
	for k in 3:
		pj.after(k * 0.14, func():
			if pj.live(c):
				var from = pj._mouth_pos(c) + c.face_dir() * 0.5
				var size = 0.9 - k * 0.15
				# hazırlık: ağız önünde alev kabarır (yanaktan şişen sıcak)
				KatonLib.mass(pj, from, 0.15, 0.45 + size * 0.3, 0.16, c.face_dir() * 1.5, KatonLib.PAL_FIRE, 1.4, 2.5)
				var cnt = {"n": 0}
				var body_fn = func() -> Node3D:
					var root = Node3D.new()
					root.add_child(KatonLib.mass_mi(0.45 + size * 0.45, KatonLib.PAL_FIRE, 1.3, 2.4))
					for q in 5:
						var a = q * TAU / 5.0
						var tg = KatonLib.tongue_mi((1.6 + randf() * 0.8) * size * 1.4, 0.9 * size, Vector3(cos(a) * 0.45, sin(a) * 0.45 + 0.2, 1.0), KatonLib.PAL_FIRE, 5, 0.15, 1.1)
						tg.position = Vector3(cos(a), sin(a), 0.6) * 0.3 * size
						root.add_child(tg)
					return root
				var tick_fn = func(p: Projectile, _dt: float) -> void:
					cnt["n"] += 1
					if cnt["n"] % 2 == 0:
						var back = -p.vel.normalized()
						var jit = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.25 * size
						KatonLib.mass(pj, p.global_position + back * 0.6 * size + jit, 0.3 * size, (0.8 + randf() * 0.3) * size, 0.42, back * 2.5 + Vector3.UP * 0.8, KatonLib.PAL_FIRE, 1.05, 1.6)
				var boom_fn = func(p: Vector3, ep: float) -> void:
					_endan_splash(pj, p, (1.0 - k * 0.2) * ep)
				_bolt(pj, c, "katon_endan", tt, from, size, 30.0, 0.35, {"burn": 2.5}, 1.0 - k * 0.2, 0.1, body_fn, tick_fn, boom_fn))
	Sfx.play("fire", c.global_position, 1.2)


## Yassı alev sıçraması: çarptığı yüzeye yayılan geniş diller + açılan kütle + kor + ısı dalgası + kavruk iz
static func _endan_splash(pj: PathJutsu, p: Vector3, s: float) -> void:
	KatonLib.mass(pj, p, 0.4 * s, 1.9 * s, 0.55, Vector3.UP * 1.2, KatonLib.PAL_FIRE, 1.35, 1.6)
	for k in 10:
		var a = k * TAU / 10.0 + randf() * 0.3
		var dv = Vector3(cos(a), randf_range(0.1, 0.5), sin(a)).normalized()
		KatonLib.tongue(pj, p, randf_range(1.2, 2.0) * s, 0.8 * s, 0.5, (dv + Vector3.UP * 0.6).normalized(), dv * 4.0 * s, KatonLib.PAL_FIRE, 5)
	KatonLib.embers(pj, p, int(24 * s) + 6, 0.5 * s, KatonLib.PAL_FIRE, {"vmin": 3.0, "vmax": 8.0, "spread": 150.0})
	KatonLib.shimmer(pj, p + Vector3.UP * 1.2 * s, 2.6 * s, 2.6 * s, 1.2)
	KatonLib.light(pj, p, FIRE_L, 6.0 * s, 10.0 * s, 0.5)
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 2.5:
		KatonLib.scorch(pj, g, 2.0 * s, 5.0)


# ================================================================== 3) Enshōdan: kavisli atılan kor topakları
## Göğe doğru kavisle atılan dört akkor kor topağı; arkalarında kıvrılan alev şeridi; düşünce küçük patlama + etrafa saçılan yanan damlalar.
static func katon_enshodan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 26.0)
	# hazırlık: ağızda kızgın akkor parlar, yanaklarda ısı
	KatonLib.glow(pj, pj._mouth_pos(c) + c.face_dir() * 0.3, 1.4, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.6)
	for k in 4:
		pj.after(0.2 + k * 0.1, func():
			if not pj.live(c):
				return
			var from = pj._mouth_pos(c)
			var b = Node3D.new()
			b.add_child(KatonLib.mass_mi(0.26, KatonLib.PAL_FIRE, 1.6, 1.2))
			var crown = KatonLib.tongue_mi(0.75, 0.42, Vector3(0, 0.6, 1.0), KatonLib.PAL_FIRE, 3, 0.0, 1.15)
			b.add_child(crown)
			b.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 1.3))
			var dir = (pj.aim_at(c, tt, from) + Vector3.UP * 0.9 + c.face_dir().cross(Vector3.UP) * (k - 1.5) * 0.3).normalized()
			# kıvrılan iz şeridi: son konumların sarmal kaydırılmış dizisi (her iki karede yeniden kurulur)
			var rib = KatonLib.ribbon_mi(PackedVector3Array([from, from + Vector3.UP * 0.01]), 0.16, KatonLib.PAL_FIRE, {"flow": 4.0, "tiles": 3.0, "rag": 0.45})
			KatonLib.put(pj, rib, Vector3.ZERO)
			var hist = {"pts": [], "n": 0}
			var pr = pj.shot(c, from, dir, 22.0, b, pj.inf(c, "katon_enshodan", 0.4, {"knock": 6.0, "kind": "heavy", "element": "katon", "burn": 2.0}), tt, false, 2.0)
			pr.homing_turn = 3.5
			var ep = pr.epic
			pr.on_hit = func(p: Vector3, _h: Node3D) -> void:
				_enshodan_pop(pj, p, rib)
				_blast_marks(p, 0.7 * ep)
			pr.on_tick = func(p: Projectile, _dt: float) -> void:
				var arr: Array = hist["pts"]
				hist["n"] += 1
				var ph = hist["n"] * 0.45
				var sd = KatonLib.side_of(p.vel)
				var up = sd.cross(p.vel.normalized())
				arr.push_front(p.global_position + (sd * cos(ph) + up * sin(ph)) * 0.18)
				if arr.size() > 16:
					arr.pop_back()
				if hist["n"] % 2 == 0 and arr.size() > 2 and is_instance_valid(rib):
					var wid = PackedFloat32Array()
					for i in arr.size():
						wid.append(1.0 - float(i) / arr.size())
					rib.mesh = KatonLib.strip(PackedVector3Array(arr), 0.16, Vector3.ZERO, true, wid))
	Sfx.play("fire", c.global_position, 1.1)


## Kor topağı patlaması: küçük kabaran kütle + etrafa sekip düşen yanan damlalar (düştükleri yerde kısa diller); iz şeridi söner
static func _enshodan_pop(pj: PathJutsu, p: Vector3, rib: MeshInstance3D) -> void:
	if is_instance_valid(rib):
		var tw = rib.create_tween()
		tw.tween_method(KatonLib.pf(rib, "heat"), 1.1, 0.0, 0.35)
		tw.tween_callback(rib.queue_free)
	KatonLib.mass(pj, p, 0.2, 0.95, 0.4, Vector3.UP, KatonLib.PAL_FIRE, 1.4, 2.2)
	KatonLib.light(pj, p, FIRE_L, 3.5, 6.0, 0.3)
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.5
		var v = Vector3(cos(a) * randf_range(2.0, 4.0), randf_range(3.0, 5.0), sin(a) * randf_range(2.0, 4.0))
		var drop = KatonLib.mass_mi(0.1, KatonLib.PAL_FIRE, 1.4, 2.0)
		KatonLib.toss(pj, drop, p, v, 0.6, 16.0)
		var land = KatonLib.floor_at(p + Vector3(v.x, 0, v.z) * 0.55)
		pj.after(0.55, func():
			KatonLib.tongue(pj, land, randf_range(0.4, 0.7), 0.35, 0.9, Vector3.UP, Vector3.ZERO, KatonLib.PAL_FIRE, 3))
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 1.5:
		KatonLib.scorch(pj, g, 1.1, 3.0)


# ================================================================== 4) Kumo-ryū Kaengiri: alevli kılıç halkası
## Kılıca akan ateş çakrası (bıçak boyunca diller), dönerek çizilen 360° alev kesiği; kesik yere düşüp dışa yayılan alev halkasına dönüşür.
static func kumo_ryu_kaengiri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 8.0)
	var d = pj._jump_at(c, tt, 0.0, 14.0 if tt else 4.0)
	pj.busy(c, 0.8)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		# bıçağa sarılan alev: bıçak ekseninde akan şerit + üstünden yükselen diller
		var blade = PackedVector3Array()
		for i in 9:
			blade.append(Vector3(0, 0, 0.12 + i * 0.15))
		ba.add_child(KatonLib.ribbon_mi(blade, 0.1, KatonLib.PAL_FIRE, {"flow": 5.0, "tiles": 3.0, "rag": 0.5}))
		for i in 4:
			var tg = KatonLib.tongue_mi(0.5, 0.3, Vector3(0, 1, 0.2), KatonLib.PAL_FIRE, 3, 0.0, 1.1)
			tg.position = Vector3(0, 0, 0.3 + i * 0.28)
			ba.add_child(tg)
		pj.free_after(0.8, ba)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_b", 1.6)
		var at = c.global_position + Vector3.UP * 1.0
		# 360° kesik: bıçak ucunun çizdiği alev yayı (-90° → 270°)
		var arc = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 33:
			var u = float(i) / 32.0
			var a = deg_to_rad(lerpf(-90.0, 270.0, u))
			arc.append(at + d.rotated(Vector3.UP, a) * 2.4 + Vector3.UP * sin(u * PI) * 0.25)
			wid.append(0.35 + 0.65 * sin(u * PI))
		KatonLib.ribbon(pj, arc, 0.42, 0.45, KatonLib.PAL_FIRE, {"flow": 6.0, "tiles": 8.0, "rag": 0.5, "widths": wid, "hint": Vector3.UP, "twin": true})
		# kesik yere düşer: dışa yayılan alev halkası dalgaları
		var g = KatonLib.floor_at(c.global_position)
		for ring in 4:
			pj.after(0.12 + ring * 0.09, func():
				var rr = 2.4 + ring * 1.0
				var n = 14 + ring * 3
				for q in n:
					var a = q * TAU / n + randf() * 0.2
					var dv = Vector3(cos(a), 0, sin(a))
					var bp = KatonLib.floor_at(g + dv * rr)
					KatonLib.tongue(pj, bp, randf_range(1.0, 1.6) * (1.0 - ring * 0.18), 0.7, 0.5, (Vector3.UP + dv * 0.35).normalized(), dv * 1.5, KatonLib.PAL_FIRE, 4))
		KatonLib.scorch(pj, g, 5.5, 4.0, 0.0, KatonLib.PAL_FIRE, 0.5)
		KatonLib.light(pj, at, FIRE_L, 6.0, 10.0, 0.6)
		KatonLib.embers(pj, at, 26, 2.4, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 5.0, "spread": 90.0})
		var hs = pj.hit(c, at + d * 1.0, 3.0, pj.inf(c, "kumo_ryu_kaengiri", 1.4, {"knock": 10.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
		for e in hs:
			if is_instance_valid(e):
				_hit_flare(pj, e.global_position + Vector3.UP * 1.0, 1.1)
		Sfx.play("fire", at, 1.0))


# ================================================================== 5) Gōryūka: göğe süzülüp dalan ejder başları
## Ağza sarmal akan ateş, ağızdan art arda üç alev ejderi (boynuzlu açık çeneli baş + yeleli gövde) göğe kıvrılıp hedef bölgeye dalar.
static func katon_goryuka_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 34.0)
	KatonLib.spiral_in(pj, pj._mouth_pos(c), KatonLib.PAL_FIRE, 0.4, 12, 1.6)
	for k in 3:
		pj.after(0.25 + k * 0.18, func():
			if not pj.live(c):
				return
			pj.anim(c, "push", 1.4)
			var fd = c.face_dir()
			var sd = fd.cross(Vector3.UP)
			var from = pj._mouth_pos(c) + fd * 0.8
			var up_dir = (fd * 0.7 + Vector3.UP * 0.8 + sd * (k - 1) * 0.45).normalized()
			# ağızdan fışkıran kısa alev akımı (ejderin doğduğu yer)
			for q in 5:
				var u = randf()
				KatonLib.tongue(pj, pj._mouth_pos(c) + fd * (0.4 + u), randf_range(1.0, 1.8), 0.8, 0.35, (up_dir + fd).normalized(), up_dir * 6.0, KatonLib.PAL_FIRE, 5)
			KatonLib.mass(pj, from, 0.3, 1.1, 0.35, up_dir * 4.0, KatonLib.PAL_FIRE, 1.4, 2.0)
			KatonLib.light(pj, from, FIRE_L, 6.0, 10.0, 0.6)
			var head = Node3D.new()
			head.add_child(KatonLib.dragon_head(1.2, KatonLib.PAL_FIRE, 30.0 + k * 6.0, 2, 6))
			var off = sd * (k - 1) * 3.0
			var pr = pj.shot(c, from, up_dir, 22.0, head, pj.inf(c, "katon_goryuka_no_jutsu", 0.9, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "element": "katon", "burn": 3.0}), null, false, 3.0, func(p, _h):
				_goryuka_impact(pj, p)
				_blast_marks(p, 2.6)
				_bolt_marks(pj, p, 2.2, 1.0)
				_crack_zone(pj.gp(p), 6.0)
				var hs = pj.hit(c, p, 5.0, pj.inf(c, "katon_goryuka_no_jutsu", 0.6, {"knock": 12.0, "launch": 4.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
				for e in hs:
					if is_instance_valid(e):
						_hit_flare(pj, e.global_position + Vector3.UP, 1.4)
				pj.shake(0.8))
			pr.radius = 1.6
			KatonLib.serpent(pj, pr, 12, 1.15, 0.95, KatonLib.PAL_FIRE)
			var age = {"t": 0.0, "n": 0}
			pr.on_tick = func(p2, dt):
				age["t"] += dt
				if age["t"] > 0.5:
					var goal = ((tt.global_position + Vector3.UP) if tt and pj.live(tt) else pj.gp(c.global_position + fd * 22.0)) + off * maxf(0.0, 1.0 - (age["t"] - 0.5) * 1.5)
					p2.vel = p2.vel.lerp((goal - p2.global_position).normalized() * 30.0, minf(1.0, dt * 4.5))
				age["n"] += 1
				if age["n"] % 4 == 0:
					var back = -p2.vel.normalized()
					KatonLib.tongue(pj, p2.global_position + back * 1.2 + Vector3.UP * 0.4, randf_range(1.0, 1.6), 0.8, 0.35, (back + Vector3.UP).normalized(), Vector3.UP * 1.5, KatonLib.PAL_FIRE, 4, 1.0))
	Sfx.play("roar", c.global_position, 0.9)
	Sfx.play("fire", c.global_position, 0.6)


## Ejder dalışı: başın gömüldüğü yerde yukarı fışkıran alev tacı, yayılan kütle, kavrulmuş geniş zemin
static func _goryuka_impact(pj: PathJutsu, p: Vector3) -> void:
	var g = KatonLib.floor_at(p)
	KatonLib.mass(pj, p, 1.0, 3.6, 0.8, Vector3.UP * 2.0, KatonLib.PAL_FIRE, 1.35, 1.4)
	for k in 14:
		var a = k * TAU / 14.0 + randf() * 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		KatonLib.tongue(pj, KatonLib.floor_at(p + dv * randf_range(0.8, 2.2)), randf_range(2.4, 4.0), 1.2, 0.8, (Vector3.UP * 1.4 + dv).normalized(), dv * 3.0 + Vector3.UP * 2.0, KatonLib.PAL_FIRE, 6)
	KatonLib.embers(pj, p, 50, 1.5, KatonLib.PAL_FIRE, {"vmin": 4.0, "vmax": 11.0, "spread": 80.0, "life": 1.6})
	KatonLib.shimmer(pj, g + Vector3.UP * 3.0, 6.0, 6.0, 2.0)
	KatonLib.light(pj, p + Vector3.UP, FIRE_L, 10.0, 18.0, 0.9)
	if p.y - g.y < 3.0:
		KatonLib.burn_patch(pj, g, 3.6, 2.4, KatonLib.PAL_FIRE, 0.12, 1.3)


# ================================================================== 6) Nezumi Kedama: mavi alevli tüy fareler
const FUR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

instance uniform float seed = 0.0;
varying vec3 lp;

float fh(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float fv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float tw = floor(TIME * 9.0);
	float sp = fh(floor(lp.xy * 38.0 + lp.zz * 31.0) + vec2(seed + tw * 0.37, seed));
	float fz = fh(floor(UV * 80.0) + vec2(seed, tw * 0.11));
	if (fv < 0.4 && fz > fv * 2.3) {
		discard;
	}
	vec3 col = vec3(0.03, 0.04, 0.1);
	if (sp > 0.94) {
		col = vec3(0.62, 0.78, 1.0);
	} else if (sp > 0.82) {
		col = vec3(0.13, 0.17, 0.38);
	}
	ALBEDO = pow(col, vec3(2.2));
}
"""


static func _fur_mat() -> ShaderMaterial:
	if _cache.has("fur"):
		return _cache["fur"]
	var sh = Shader.new()
	sh.code = FUR_SHADER
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["fur"] = m
	return m


## Kanon: ağızdan fırlayan, mavi alev içinde koşan kara tüylü fareler (anime: kıvılcımlı kara tüy, ince kuyruk, mavi alev kılıfı)
static func nezumi_kedama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 24.0)
	for k in 5:
		pj.after(k * 0.1, func():
			if pj.live(c):
				var from = pj._mouth_pos(c)
				# hazırlık: dudakta mavi alev parlar
				KatonLib.tongue(pj, from + c.face_dir() * 0.15, 0.5, 0.3, 0.2, (c.face_dir() + Vector3.UP * 0.3).normalized(), Vector3.ZERO, KatonLib.PAL_BLUE, 3)
				var cnt = {"n": k}
				var body_fn = func() -> Node3D:
					return _rat()
				var tick_fn = func(p: Projectile, _dt: float) -> void:
					cnt["n"] += 1
					var r: Node3D = p.get_child(0) if p.get_child_count() > 0 else null
					if r and is_instance_valid(r):
						# koşma: gövde zıplar, kuyruk kıvrılır
						r.position.y = absf(sin(cnt["n"] * 0.55)) * 0.12
						var tl = r.get_node_or_null("tail")
						if tl:
							tl.rotation.y = sin(cnt["n"] * 0.7) * 0.5
					if cnt["n"] % 3 == 0:
						var back = -p.vel.normalized()
						KatonLib.tongue(pj, p.global_position + back * 0.5, randf_range(0.5, 0.8), 0.35, 0.25, (back + Vector3.UP * 0.3).normalized(), back * 1.5, KatonLib.PAL_BLUE, 3, 1.0)
				var boom_fn = func(p: Vector3, ep: float) -> void:
					_nezumi_burst(pj, p, 0.6 * ep)
				_bolt(pj, c, "nezumi_kedama", tt, from, 0.6, 32.0, 0.25, {"burn": 1.5}, 0.6, 0.04, body_fn, tick_fn, boom_fn))
	Sfx.play("fire", c.global_position, 1.3)


## Fare (-Z ileri): kara tüy gövde / baş / kulak / burun, ince kuyruk; çevresinde arkaya akan mavi alev kılıfı ve soluk mavi hale
static func _rat() -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	var w = Color.WHITE
	b.add("sphere", Vector3(0, 0, 0.08), Vector3(0.44, 0.36, 0.66), w, Vector3.ZERO, 12)
	b.add("sphere", Vector3(0, 0.04, -0.34), Vector3(0.3, 0.27, 0.34), w, Vector3.ZERO, 10)
	b.add("cone", Vector3(0, 0.02, -0.56), Vector3(0.14, 0.18, 0.14), w, Vector3(-90, 0, 0), 6)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.12, 0.2, -0.28), Vector3(0.15, 0.17, 0.05), w, Vector3(0, 0, sx * 20.0), 8)
	var body = MeshInstance3D.new()
	body.mesh = b.build()
	body.material_override = _fur_mat()
	body.set_instance_shader_parameter("seed", randf() * 10.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var tail = Node3D.new()
	tail.name = "tail"
	tail.position = Vector3(0, 0.02, 0.38)
	var pts = PackedVector3Array()
	for i in 10:
		var u = float(i) / 9.0
		pts.append(Vector3(sin(u * 5.0) * 0.08 * u, 0.06 * u, u * 0.75))
	var tm = MeshInstance3D.new()
	tm.mesh = KatonLib.strip(pts, 0.025)
	tm.material_override = _dark_mat(Color(0.03, 0.04, 0.1))
	tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.add_child(tm)
	root.add_child(tail)
	# mavi alev kılıfı: üst, yanlar ve alt boyunca arkaya akan diller (kara gövde içinde görünür kalır)
	for k in 6:
		var a = k * TAU / 6.0 + 0.3
		var ax = Vector3(cos(a) * 0.35, sin(a) * 0.35 + 0.15, 1.0)
		var tg = KatonLib.tongue_mi(1.3, 0.55, ax, KatonLib.PAL_BLUE, 4, 0.1, 1.05)
		tg.position = Vector3(cos(a) * 0.24, sin(a) * 0.2, -0.25)
		root.add_child(tg)
	var hl = KatonLib.glow_mi(Color(0.25, 0.45, 1.0), 1.6)
	hl.position = Vector3(0, 0, 0.2)
	root.add_child(hl)
	return root


## Mavi alev çarpması: fare dağılır — mavi diller saçılır, kara tüy kıvılcımları, mavi kızgın damarlı küçük iz
static func _nezumi_burst(pj: PathJutsu, p: Vector3, s: float) -> void:
	KatonLib.mass(pj, p, 0.2, 0.7 + s, 0.4, Vector3.UP * 0.6, KatonLib.PAL_BLUE, 1.3, 2.0)
	for k in 8:
		var dv = Vector3(randf_range(-1, 1), randf_range(0.0, 1.0), randf_range(-1, 1)).normalized()
		KatonLib.tongue(pj, p, randf_range(0.7, 1.2), 0.45, 0.4, dv, dv * 2.5, KatonLib.PAL_BLUE, 3)
	KatonLib.embers(pj, p, 18, 0.3, KatonLib.PAL_BLUE, {"vmin": 2.0, "vmax": 6.0, "spread": 150.0, "life": 0.9})
	KatonLib.light(pj, p, BLUE_L, 4.0, 7.0, 0.4)
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 1.5:
		KatonLib.scorch(pj, g, 1.0, 3.0, 0.0, KatonLib.PAL_BLUE)


# ================================================================== 7) Tenrō: göğse basılan ateş mührü
## Kanon (anime): avuçtaki kızıl alev mühür hedefin göğsüne çakılır, gövdeye çapraz yanık mühür bantları sarılır; ayağının dibinde
## alev parmaklıkları yükselir. Hedef bağlanır ve mühür yanarken hasar alır.
static func katon_tenro(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var hp = pj.hand_pos(c, true)
	var hh = float(tt.get("height")) if tt.get("height") != null else 1.8
	var chest = tt.global_position + Vector3.UP * hh * 0.68
	# avuç: kızıl alev çiçeği, mühür ışığı hedefe uçar
	for k in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)).normalized()
		KatonLib.tongue(pj, hp, 0.6, 0.3, 0.3, dv, dv, KatonLib.PAL_CRIMSON, 3)
	KatonLib.glow(pj, hp, 1.2, CRIM_L, 0.4)
	var path = PackedVector3Array()
	for i in 13:
		var u = float(i) / 12.0
		path.append(hp.lerp(chest, u) + Vector3.UP * sin(u * PI) * 0.8)
	KatonLib.ribbon(pj, path, 0.12, 0.35, KatonLib.PAL_CRIMSON, {"flow": 7.0, "tiles": 5.0, "rag": 0.3})
	# göğüste açılan kızıl alev çiçeği (anime: avuç değdiği an göğüste kızıl diller patlar)
	pj.after(0.18, func():
		if not pj.live(tt):
			return
		var cp = tt.global_position + Vector3.UP * hh * 0.68
		var face = (c.global_position - tt.global_position) if pj.live(c) else Vector3.FORWARD
		face.y = 0.0
		face = face.normalized() if face.length() > 0.01 else Vector3.FORWARD
		var sd = KatonLib.side_of(face)
		for k in 10:
			var a = k * TAU / 10.0
			var dv = (sd * cos(a) + Vector3.UP * sin(a) + face * 0.5).normalized()
			KatonLib.tongue(pj, cp + face * 0.25, randf_range(0.7, 1.1), 0.45, 0.45, dv, dv * 1.2, KatonLib.PAL_CRIMSON, 4)
		KatonLib.glow(pj, cp + face * 0.3, 2.0, CRIM_L, 0.5)
		# yanık mühür bantları: göğüste çapraz X + bel ve göğüs çevresinde kuşak (hedefe iliştirilir, hedefle büyür)
		var seal = Node3D.new()
		var rr = (float(tt.get("radius")) if tt.get("radius") != null else 0.38) * 1.15
		for sx in [-1.0, 1.0]:
			var pts = PackedVector3Array()
			for i in 17:
				var u = float(i) / 16.0
				var a = u * PI * 1.2 - PI * 0.1
				pts.append(Vector3(sin(a) * rr * sx, hh * lerpf(0.88, 0.38, u), -cos(a) * rr))
			seal.add_child(KatonLib.ribbon_mi(pts, 0.07, KatonLib.PAL_SEAL, {"flow": 0.6, "tiles": 6.0, "rag": 0.15}))
		for yy in [0.5, 0.72]:
			var ring = PackedVector3Array()
			for i in 25:
				var a = i * TAU / 24.0
				ring.append(Vector3(cos(a) * rr * 1.05, hh * yy, sin(a) * rr * 1.05))
			seal.add_child(KatonLib.ribbon_mi(ring, 0.05, KatonLib.PAL_SEAL, {"flow": 0.8, "tiles": 8.0, "rag": 0.15}))
		pj.attach(tt, seal, 3.7, Vector3.ZERO, 0)   # bantlar hedefin kendi boy / yarıçapından kuruldu: ayrıca büyütülmez
		seal.scale = Vector3.ONE * 0.05
		var tws = seal.create_tween()
		tws.tween_property(seal, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	# zemin: hedefin çevresinde yükselen alev parmaklıkları (hapis) + kavruk halka
	var root = Node3D.new()
	KatonLib.put(pj, root, at)
	for k in 10:
		var a = k * TAU / 10.0
		var bar = Node3D.new()
		bar.position = Vector3(cos(a) * 2.0, 0.0, sin(a) * 2.0)
		for q in 2:
			var tg = KatonLib.tongue_mi(3.6 - q * 1.2, 0.5 + q * 0.2, Vector3(0, 1, 0), KatonLib.PAL_CRIMSON if q == 1 else KatonLib.PAL_FIRE, 2 + q, 0.0, 1.1)
			bar.add_child(tg)
		root.add_child(bar)
	var ringp = PackedVector3Array()
	for i in 41:
		var a = i * TAU / 40.0
		ringp.append(Vector3(cos(a) * 2.0, 0.08, sin(a) * 2.0))
	root.add_child(KatonLib.ribbon_mi(ringp, 0.22, KatonLib.PAL_CRIMSON, {"hint": Vector3.UP, "twin": false, "flow": 2.0, "tiles": 12.0}))
	root.scale = Vector3(1, 0.02, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(3.5)
	tw.tween_property(root, "scale", Vector3(1, 0.02, 1), 0.3)
	tw.tween_callback(root.queue_free)
	KatonLib.scorch(pj, at, 2.6, 5.0, 0.0, KatonLib.PAL_CRIMSON)
	KatonLib.light(pj, at + Vector3.UP * 1.5, CRIM_L, 4.0, 8.0, 4.0)
	# --- oynanış
	pj.st(tt, "bind", 3.8)
	pj.every(3.8, 0.4, func(_i, _k):
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "katon_tenro", 0.2, {"knock": 0.0, "kind": "light", "element": "katon", "burn": 1.0}))
			KatonLib.embers(pj, tt.global_position + Vector3.UP * hh * 0.6, 6, 0.4, KatonLib.PAL_CRIMSON, {"vmin": 0.8, "vmax": 2.0, "life": 0.8}), Callable())
	_crack_zone(at, 3.0, 6.0)
	Sfx.play("fire", at, 0.6)


# ================================================================== 8) Karyū Endan: uzun gövdeli alev ejderi seli
## Ağızdan fışkıran alev uzun gövdeli tek bir ejdere dönüşür, yılan gibi kıvrılıp hedefe dalar; çarpınca kubbe biçimli
## dev alev patlaması, zeminde dışa koşan ışık çizgileri, geniş kavruk iz.
static func katon_karyuu(js, c: Node3D, t: Node3D) -> void:
	var m = js._mult(c) * js._elem_bonus(c, "katon")
	Sfx.play("fire", c.global_position, 0.8)
	var mo = js._mouth(c)
	var d = js._aim(c, t)
	# hazırlık: ağızdan ileri taşan alev seli (ejderin doğumu)
	for q in 8:
		var u = randf()
		KatonLib.tongue(js, mo + d * (0.3 + u * 1.2), randf_range(1.0, 2.0), 0.9, 0.4, (d + Vector3.UP * 0.5).normalized(), d * 6.0, KatonLib.PAL_FIRE, 5)
	KatonLib.mass(js, mo + d * 0.8, 0.3, 1.4, 0.45, d * 5.0 + Vector3.UP, KatonLib.PAL_FIRE, 1.4, 2.0)
	KatonLib.embers(js, mo, 20, 0.5, KatonLib.PAL_FIRE, {"dir": d, "vmin": 3.0, "vmax": 8.0, "spread": 40.0, "life": 0.6})
	# --- oynanış (Jutsu.j_katon_karyuu'dan birebir)
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = (d + Vector3.UP * 0.35).normalized() * 14.0
	pr.radius = 1.4
	pr.life = 3.5
	pr.homing = t
	pr.homing_turn = 1.6
	pr.info = {"dmg": 28.0 * m, "element": "katon", "knock": 14.0, "launch": 5.0, "kind": "heavy", "hitstop": 0.08}
	pr.add_child(KatonLib.dragon_head(1.15, KatonLib.PAL_FIRE, 34.0, 2, 8))
	var t0 = randf() * TAU
	var cnt = {"n": 0}
	pr.on_tick = func(p: Projectile, dt: float) -> void:
		var side = p.vel.cross(Vector3.UP).normalized()
		p.global_position += side * sin(Time.get_ticks_msec() * 0.007 + t0) * dt * 6.0 + Vector3.UP * cos(Time.get_ticks_msec() * 0.005 + t0) * dt * 2.0
		cnt["n"] += 1
		if cnt["n"] % 5 == 0:
			KatonLib.embers(js, p.global_position, 4, 0.8, KatonLib.PAL_FIRE, {"vmin": 0.5, "vmax": 2.0, "life": 0.8})
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		_karyuu_dome(js, pos, pr.epic)
		_blast_marks(pos, 1.0 * pr.epic)
		_crack_zone(js._ground(pos), 4.0 * pr.epic, 6.0)
		Combat.hit_sphere(c, pos, 4.0, {"dmg": 10.0 * m, "element": "katon", "knock": 12.0, "launch": 4.0, "kind": "heavy"}, pr.hit_list)
		if Game.world: Game.world.env.add_shake(0.6)
	js.get_tree().current_scene.add_child(pr)
	pr.global_position = mo + d * 1.5
	# uzun kıvrılan gövde: başın izinden giden alev halkaları (gövdesi görünsün diye önce yükselip süzülür)
	KatonLib.serpent(js, pr, 22, 0.85, 1.45, KatonLib.PAL_FIRE)


## Kubbe patlaması: yere oturan yarım küre alev kütlesi, içinden yükselen diller, zeminde dışa koşan parlak çizgiler
static func _karyuu_dome(host: Node, pos: Vector3, ep: float) -> void:
	var s = ep
	var g = KatonLib.floor_at(pos)
	var base = g if pos.y - g.y < 3.0 else pos
	# kubbe genişliği korunur, yüksekliği sınırlı (yassı kubbe ~4 m): arkadaki kamera kubbenin içinde kalmasın;
	# kameraya yakın kısım shader'da incelir
	KatonLib.mass(host, base + Vector3.UP * 0.3 * s, 1.2 * s, 4.2 * s, 0.9, Vector3.UP * 0.4, KatonLib.PAL_FIRE, 1.4, 1.2, minf(0.55, 4.0 / (4.2 * s)))
	for k in 6:
		var a = k * TAU / 6.0
		var off = Vector3(cos(a), 0, sin(a)) * 2.2 * s
		KatonLib.mass(host, base + off + Vector3.UP * 0.5, 0.6 * s, 2.0 * s, 0.75, off * 0.8 + Vector3.UP * 0.4, KatonLib.PAL_FIRE, 1.25, 1.4, 0.6)
	for k in 16:
		var a = k * TAU / 16.0 + randf() * 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		KatonLib.tongue(host, base + dv * randf_range(0.5, 2.5) * s, minf(randf_range(2.5, 4.5) * s, 4.5), 1.4 * s, 0.9, (Vector3.UP * 1.5 + dv).normalized(), Vector3.UP * 1.0, KatonLib.PAL_FIRE, 6)
	if pos.y - g.y < 3.0:
		for k in 14:
			var a = k * TAU / 14.0 + randf() * 0.15
			var dv = Vector3(cos(a), 0, sin(a))
			var pts = PackedVector3Array()
			var r0 = randf_range(2.5, 4.0) * s
			var r1 = r0 + randf_range(3.0, 6.0) * s
			for i in 6:
				var q = g + dv * lerpf(r0, r1, float(i) / 5.0)
				pts.append(KatonLib.floor_at(q) + Vector3.UP * 0.1)
			KatonLib.ribbon(host, pts, 0.07, 0.4, KatonLib.PAL_FIRE, {"hint": Vector3.UP, "twin": false, "flow": 8.0, "tiles": 2.0, "rag": 0.1, "heat": 1.6})
		KatonLib.scorch(host, g, 5.5 * s, 7.0)
	KatonLib.embers(host, pos, 60, 2.0 * s, KatonLib.PAL_FIRE, {"vmin": 4.0, "vmax": 12.0, "spread": 90.0, "life": 1.8})
	KatonLib.shimmer(host, base + Vector3.UP * 3.5 * s, 8.0 * s, 7.0 * s, 2.2)
	KatonLib.light(host, base + Vector3.UP * 2.0, FIRE_L, 12.0, 24.0 * s, 1.0)


# ================================================================== 9) Genjutsu Rinka: alevden canavar yanılsaması
## Anime (Hayalet Ateş): hedefin ardında alevden kaslı, kurt başlı dev bir canavar yükselir — omuzlarından alev dilleri,
## sivri kulaklar, sırıtan dişler; kurbanı korkudan donar, sonra canavar kor zerrelerine dağılır.
static func genjutsu_rinka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.6)
	pj.anim(c, "cast", 1.2)
	if tt == null:
		return
	var at = tt.global_position + (c.global_position - tt.global_position).normalized() * -2.0
	var beast = _fire_beast()
	KatonLib.put(pj, beast, pj.gp(at))
	var look_to = c.global_position
	look_to.y = beast.global_position.y
	if look_to.distance_to(beast.global_position) > 0.2:
		beast.look_at(look_to, Vector3.UP)
	beast.scale = Vector3.ONE * 0.1
	# soluk nefes: gövde kalkıp iner
	var body: Node3D = beast.get_node("body")
	var tb = body.create_tween().set_loops(4)
	tb.tween_property(body, "position:y", 0.18, 0.4).set_trans(Tween.TRANS_SINE)
	tb.tween_property(body, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	var tw = beast.create_tween()
	tw.tween_property(beast, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.4)
	tw.tween_callback(func():
		# dağılış: canavar kabaran kütlelere ve kor zerrelerine çözülür
		if not is_instance_valid(beast):
			return
		var bp = beast.global_position
		for k in 7:
			var q = bp + Vector3(randf_range(-2, 2), randf_range(1.0, 5.5), randf_range(-1.5, 1.5))
			KatonLib.mass(pj, q, 0.6, 1.4, 0.6, Vector3.UP * 2.0, KatonLib.PAL_FIRE, 1.0, 1.0)
		KatonLib.embers(pj, bp + Vector3.UP * 3.0, 40, 2.5, KatonLib.PAL_FIRE, {"vmin": 1.0, "vmax": 4.0, "life": 1.6}))
	tw.tween_property(beast, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_callback(beast.queue_free)
	# zemin: canavarın yükseldiği alev göleti
	KatonLib.burn_patch(pj, pj.gp(at), 2.4, 2.8, KatonLib.PAL_FIRE, 0.1, 1.2)
	KatonLib.light(pj, pj.gp(at) + Vector3.UP * 3.0, FIRE_L, 6.0, 14.0, 3.0)
	# --- oynanış
	pj.st(tt, "stun", 3.0)
	Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Korku!", Color(1, 0.6, 0.2))
	Sfx.play("fire", at, 0.6)
	Sfx.play("roar", at, 1.2)


## Alev canavarı (-Z ileri, ~6 m): gövde / göğüs / omuz / kol / yumruk alev kütlesi, kurt başı (burun, sivri kulak dilleri,
## parlak göz, dişli kara ağız), omuz ve sırtta yükselen diller, bel altı alev içinde
static func _fire_beast() -> Node3D:
	var root = Node3D.new()
	var body = Node3D.new()
	body.name = "body"
	root.add_child(body)
	# gövde (koyu turuncu, ısı düşük) ve baş (daha sıcak) ayrı tonda: siluet katmanlar halinde okunsun
	var parts = [
		[Vector3(0, 2.0, 0.1), Vector3(1.3, 1.1, 1.0), 0.9],
		[Vector3(0, 3.6, 0.0), Vector3(1.75, 1.3, 1.15), 0.95],
		[Vector3(-1.95, 4.25, 0.1), Vector3(1.0, 0.85, 0.9), 0.9],
		[Vector3(1.95, 4.25, 0.1), Vector3(1.0, 0.85, 0.9), 0.9],
		[Vector3(-2.55, 3.1, -0.3), Vector3(0.7, 0.95, 0.7), 0.85],
		[Vector3(2.55, 3.1, -0.3), Vector3(0.7, 0.95, 0.7), 0.85],
		[Vector3(-2.75, 1.9, -0.8), Vector3(0.62, 0.8, 0.62), 0.85],
		[Vector3(2.75, 1.9, -0.8), Vector3(0.62, 0.8, 0.62), 0.85],
		[Vector3(-2.65, 0.95, -1.1), Vector3(0.78, 0.65, 0.8), 0.95],
		[Vector3(2.65, 0.95, -1.1), Vector3(0.78, 0.65, 0.8), 0.95],
		[Vector3(0, 5.3, -0.35), Vector3(0.95, 0.85, 0.85), 1.15],
		[Vector3(0, 5.0, -1.25), Vector3(0.52, 0.42, 0.72), 1.2],
	]
	for pr in parts:
		var mi = KatonLib.mass_mi(1.0, KatonLib.PAL_FIRE, pr[2], 0.6)
		mi.position = pr[0]
		mi.scale = pr[1]
		body.add_child(mi)
	# kulaklar: başın üstünde dik, sivri tek dil (kurt kulağı)
	for sx in [-1.0, 1.0]:
		var ear = KatonLib.tongue_mi(1.9, 0.75, Vector3(sx * 0.3, 1, 0.15), KatonLib.PAL_FIRE, 1, 0.0, 1.3)
		ear.position = Vector3(sx * 0.6, 5.85, -0.3)
		body.add_child(ear)
	# boyun yelesi: başın arkasından ve yanlarından dışa yalayan diller (baş gövdeden ayrılsın)
	for q in 7:
		var a = lerpf(-1.3, 1.3, float(q) / 6.0)
		var mn = KatonLib.tongue_mi(1.4, 0.9, Vector3(sin(a) * 0.9, 0.7, 0.5), KatonLib.PAL_FIRE, 4, 0.0, 1.0)
		mn.position = Vector3(sin(a) * 0.9, 4.9 + cos(a) * 0.2, 0.25)
		body.add_child(mn)
	# omuz ve sırt alevleri (anime: omuzlardan yükselen büyük diller)
	for sx in [-1.0, 1.0]:
		for q in 2:
			var sh = KatonLib.tongue_mi(2.4 - q * 0.6, 1.3, Vector3(sx * 0.2, 1, 0.3), KatonLib.PAL_FIRE, 5, 0.0, 1.1)
			sh.position = Vector3(sx * (1.95 + q * 0.5), 4.7, 0.25 + q * 0.2)
			body.add_child(sh)
	for q in 4:
		var bk = KatonLib.tongue_mi(2.0, 1.4, Vector3(0, 1, 0.6), KatonLib.PAL_FIRE, 6, 0.0, 1.0)
		bk.position = Vector3((q - 1.5) * 0.7, 3.0 + q * 0.4, 0.8)
		body.add_child(bk)
	# bel altı: ateşten yükselen gövde (bacak yerine dil dil alev eteği)
	for q in 6:
		var a = q * TAU / 6.0
		var sk = KatonLib.tongue_mi(2.0, 1.5, Vector3(cos(a) * 0.2, 1, sin(a) * 0.2), KatonLib.PAL_FIRE, 6, 0.0, 1.1)
		sk.position = Vector3(cos(a) * 1.1, 0.0, sin(a) * 0.9)
		body.add_child(sk)
	# yüz (kütle yüzeyinin önünde, saydam alevin içinde kaybolmasın): parlak öfkeli gözler + kaş, kara burun,
	# açık kara ağız ve büyük dişler; yumruklarda koyu kızıl pençe çizgileri
	var b = MB.new()
	var white = Color(1.0, 0.97, 0.75)
	var dark = Color(0.3, 0.04, 0.02)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.4, 5.45, -1.25), Vector3(0.34, 0.15, 0.1), white, Vector3(0, 0, sx * -20.0), 8)
		b.add("sphere", Vector3(sx * 0.4, 5.45, -1.3), Vector3(0.1, 0.13, 0.04), dark, Vector3.ZERO, 6)
		b.add("box", Vector3(sx * 0.42, 5.62, -1.28), Vector3(0.46, 0.07, 0.05), dark, Vector3(0, 0, sx * -24.0))
		for i in 3:
			b.add("box", Vector3(sx * 2.65 + (i - 1) * 0.22, 0.95, -1.9), Vector3(0.05, 0.4, 0.05), dark, Vector3.ZERO)
	b.add("sphere", Vector3(0, 5.32, -1.98), Vector3(0.3, 0.2, 0.16), dark, Vector3.ZERO, 8)
	b.add("sphere", Vector3(0, 4.8, -1.82), Vector3(0.78, 0.42, 0.16), dark, Vector3.ZERO, 10)
	for i in 6:
		var x = (i - 2.5) * 0.13
		var big = 1.6 if i == 0 or i == 5 else 1.0
		b.add("cone", Vector3(x, 4.95, -1.92), Vector3(0.09, 0.2 * big, 0.06), white, Vector3(180, 0, 0), 4)
		b.add("cone", Vector3(x, 4.64, -1.92), Vector3(0.09, 0.18 * big, 0.06), white, Vector3.ZERO, 4)
	body.add_child(_flat(b))
	return root


# ================================================================== 10) Homura Nagase: göğe atılıp yağan alev göktaşları
## Ağızdan göğe üç alev topu fırlar; birazdan hedef bölgeye kızgın kaya çekirdekli alev göktaşları yağar — arkalarında uzun
## alev kuyruğu, düştükleri yerde krater, sıçrayan kaya parçaları ve yükselen alev sütunu.
static func katon_homuranagase(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 28.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	for k in 3:
		var fb = Node3D.new()
		fb.add_child(KatonLib.mass_mi(0.55, KatonLib.PAL_FIRE, 1.35, 2.0))
		var tg = KatonLib.tongue_mi(2.2, 0.8, Vector3.DOWN, KatonLib.PAL_FIRE, 4, 0.0, 1.1)
		fb.add_child(tg)
		KatonLib.put(pj, fb, pj._mouth_pos(c))
		var tw = fb.create_tween()
		var sky = c.global_position + Vector3.UP * 14.0 + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		tw.tween_property(fb, "global_position", sky, 0.4)
		tw.tween_callback(func():
			KatonLib.glow(pj, sky, 3.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.4)
			KatonLib.mass(pj, sky, 0.5, 1.6, 0.4, Vector3.ZERO, KatonLib.PAL_FIRE, 1.3, 2.0)
			fb.queue_free())
	for k in 9:
		pj.after(0.6 + k * 0.12, func():
			var q = at + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			var fb = _meteor()
			var start = q + Vector3(randf_range(-4, 4), 16.0, randf_range(-4, 4))
			var end = pj.gp(q) + Vector3.UP * 0.5
			KatonLib.put(pj, fb, start)
			KatonLib.look(fb, end - start)
			var tw = fb.create_tween()
			tw.tween_method(func(u: float) -> void:
				if not is_instance_valid(fb):
					return
				var p = start.lerp(end, u)
				fb.global_position = p
				if randf() < 0.45:
					KatonLib.mass(pj, p - (end - start).normalized() * 0.8, 0.4, 1.0, 0.45, Vector3.UP * 0.5, KatonLib.PAL_FIRE, 1.0, 1.4), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				_meteor_crater(pj, pj.gp(q) + Vector3.UP * 0.5)
				_bolt_marks(pj, pj.gp(q) + Vector3.UP * 0.5, 1.2, 1.0)
				pj.hit(c, pj.gp(q) + Vector3.UP, 3.0, pj.inf(c, "katon_homuranagase", 0.45, {"knock": 8.0, "launch": 4.0, "kind": "heavy", "element": "katon", "burn": 2.0}))
				fb.queue_free()))
	Sfx.play("fire", c.global_position, 0.8)


## Göktaşı (-Z düşüş yönü): önde kızgın damarlı kara kaya, arkasında kabaran alev ve geriye uzanan uzun diller
static func _meteor() -> Node3D:
	var root = Node3D.new()
	var b = MB.new()
	b.add("boulder", Vector3(0, 0, -0.35), Vector3(0.9, 0.8, 0.9), Color(0.16, 0.08, 0.05), Vector3(randf() * 90, randf() * 90, 0), randi_range(1, 6))
	b.add("sphere", Vector3(0, 0, -0.6), Vector3(0.55, 0.5, 0.4), Color(1.0, 0.55, 0.12), Vector3.ZERO, 8)
	root.add_child(_flat(b))
	var fl = KatonLib.mass_mi(0.75, KatonLib.PAL_FIRE, 1.25, 2.4)
	fl.position = Vector3(0, 0, 0.45)
	root.add_child(fl)
	for k in 4:
		var a = k * TAU / 4.0 + 0.4
		var tg = KatonLib.tongue_mi(3.2, 1.0, Vector3(cos(a) * 0.2, sin(a) * 0.2, 1.0), KatonLib.PAL_FIRE, 5, 0.1, 1.1)
		tg.position = Vector3(cos(a) * 0.3, sin(a) * 0.3, 0.4)
		root.add_child(tg)
	root.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 3.2))
	return root


## Göktaşı çukuru: yukarı fışkıran alev sütunu, açılan kütle, savrulan kızgın kaya parçaları, kavruk krater
static func _meteor_crater(pj: PathJutsu, p: Vector3) -> void:
	var g = KatonLib.floor_at(p)
	KatonLib.mass(pj, p, 0.5, 1.8, 0.5, Vector3.UP * 1.5, KatonLib.PAL_FIRE, 1.35, 1.6)
	for k in 6:
		var dv = Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)).normalized()
		KatonLib.tongue(pj, g + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), randf_range(2.0, 3.2), 1.0, 0.6, dv, Vector3.UP * 1.5, KatonLib.PAL_FIRE, 5)
	for k in 5:
		var rb = MB.new()
		rb.add("boulder", Vector3.ZERO, Vector3.ONE * randf_range(0.15, 0.3), Color(0.2, 0.1, 0.06), Vector3.ZERO, randi_range(1, 6))
		var a = randf() * TAU
		KatonLib.toss(pj, _flat(rb), p + Vector3.UP * 0.3, Vector3(cos(a) * randf_range(3, 6), randf_range(4, 7), sin(a) * randf_range(3, 6)), 1.2, 18.0)
	KatonLib.embers(pj, p, 24, 0.8, KatonLib.PAL_FIRE, {"vmin": 3.0, "vmax": 9.0, "spread": 70.0, "life": 1.2})
	KatonLib.scorch(pj, g, 2.2, 5.0)
	KatonLib.light(pj, p + Vector3.UP, FIRE_L, 6.0, 9.0, 0.5)


# ================================================================== 11) Gōenka: yelpaze gibi açılan iri yuvarlak ateş topları
## Ağızdan art arda sekiz iri, yuvarlak, benekli ateş topu; çevrelerinde parlak hale, yavaş dönen üst dilleri.
## Çarpınca yuvarlak alev çiçeği açılır, çevresine kısa diller halka olur.
static func katon_goenka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	# hazırlık: ağızda yuvarlak sıcak parlama + ısı dalgası
	KatonLib.glow(pj, pj._mouth_pos(c) + c.face_dir() * 0.4, 2.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.7)
	KatonLib.shimmer(pj, pj._mouth_pos(c) + c.face_dir() * 1.2, 1.8, 1.4, 0.9)
	for k in 8:
		pj.after(k * 0.08, func():
			if pj.live(c):
				var side = c.face_dir().cross(Vector3.UP) * ((k - 3.5) * 0.45)
				var from = pj._mouth_pos(c) + side * 0.3 + Vector3.UP * (0.15 * (k % 2))
				var cnt = {"n": k}
				var body_fn = func() -> Node3D:
					var root = Node3D.new()
					root.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 3.0))
					root.add_child(KatonLib.mass_mi(0.8, KatonLib.PAL_FIRE, 1.4, 0.6))
					for q in 3:
						var a = q * TAU / 3.0
						var tg = KatonLib.tongue_mi(0.9, 0.7, Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5), KatonLib.PAL_FIRE, 4, 0.0, 1.0)
						tg.position = Vector3(cos(a) * 0.35, 0.45, sin(a) * 0.35)
						root.add_child(tg)
					return root
				var tick_fn = func(p: Projectile, _dt: float) -> void:
					cnt["n"] += 1
					if cnt["n"] % 6 == 0:
						KatonLib.embers(pj, p.global_position, 3, 0.6, KatonLib.PAL_FIRE, {"vmin": 0.5, "vmax": 1.5, "life": 0.6})
				var boom_fn = func(p: Vector3, ep: float) -> void:
					_goenka_bloom(pj, p, 0.9 * ep)
				_bolt(pj, c, "katon_goenka", tt, from, 1.1, 28.0, 0.35, {"burn": 2.0}, 0.9, 0.04, body_fn, tick_fn, boom_fn))
	Sfx.play("fire", c.global_position, 0.7)


## Yuvarlak alev çiçeği: top patlayıp kabarır, çevresine halka halinde kısa diller dikilir, kavruk yuvarlak iz
static func _goenka_bloom(pj: PathJutsu, p: Vector3, s: float) -> void:
	KatonLib.mass(pj, p, 0.5 * s, 1.8 * s, 0.6, Vector3.UP * 0.6, KatonLib.PAL_FIRE, 1.45, 0.9)
	KatonLib.glow(pj, p, 4.0 * s, KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 0.5)
	var g = KatonLib.floor_at(p)
	var low = p.y - g.y < 2.0
	for k in 10:
		var a = k * TAU / 10.0
		var dv = Vector3(cos(a), 0, sin(a))
		var bp = KatonLib.floor_at(p + dv * 1.3 * s) if low else p + dv * 0.8 * s
		KatonLib.tongue(pj, bp, randf_range(0.9, 1.4) * s, 0.6 * s, 0.7, (Vector3.UP + dv * 0.2).normalized(), Vector3.ZERO, KatonLib.PAL_FIRE, 4)
	KatonLib.embers(pj, p, int(20 * s) + 6, 0.6 * s, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 6.0, "spread": 170.0, "life": 1.0})
	KatonLib.light(pj, p, FIRE_L, 5.0 * s, 9.0 * s, 0.45)
	if low:
		KatonLib.scorch(pj, g, 1.6 * s, 4.0)


# ================================================================== 12) Karyūdan: ejder başından alev mermileri
## Ağızdan çıkan ince dalgalı alev akımı (dipte mavi-beyaz) havada açık çeneli bir ejder başına dönüşür; ejder ağzından
## art arda dönerek uçan ince alev mermileri tükürür. Mermi çarpınca ileri delip saçılan dar alev demeti.
static func katon_karyudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 26.0)
	var head = c.global_position + Vector3.UP * 2.8 + c.face_dir() * 1.4
	var dh = KatonLib.dragon_head(0.95, KatonLib.PAL_FIRE, 40.0, 2, 7)
	pj.get_tree().current_scene.add_child(dh)
	dh.global_position = head
	var aim0 = tt.global_position + Vector3.UP if tt else head + c.face_dir() * 10.0
	dh.look_at(aim0, Vector3.UP)
	var fs = dh.scale
	dh.scale = fs * 0.1
	var tw = dh.create_tween()
	tw.tween_property(dh, "scale", fs, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.0)
	tw.tween_property(dh, "scale", fs * 0.05, 0.25)
	tw.tween_callback(dh.queue_free)
	# ağızdan başa uzanan ince dalgalı alev akımı (her karede dalgası kayar) + ağızda mavi-beyaz kök
	var mo = pj._mouth_pos(c)
	var rib = KatonLib.ribbon_mi(PackedVector3Array([mo, head]), 0.2, KatonLib.PAL_FIRE, {"flow": 6.0, "tiles": 4.0, "rag": 0.45})
	KatonLib.put(pj, rib, Vector3.ZERO)
	var wave = func(i, _k):
		if not is_instance_valid(rib) or not pj.live(c):
			return
		var a = pj._mouth_pos(c)
		var bq = head
		var sd = KatonLib.side_of(bq - a)
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for j in 13:
			var u = float(j) / 12.0
			pts.append(a.lerp(bq, u) + sd * sin(u * 7.0 - i * 0.9) * 0.3 * u + Vector3.UP * sin(u * PI) * 0.6)
			wid.append(0.35 + u * 0.9)
		rib.mesh = KatonLib.strip(pts, 0.2, Vector3.ZERO, true, wid)
		if i % 3 == 0:
			KatonLib.tongue(pj, a + c.face_dir() * 0.1, 0.4, 0.22, 0.18, (bq - a).normalized(), Vector3.ZERO, KatonLib.PAL_BLUE, 2, 1.2)
	var wave_end = func():
		if is_instance_valid(rib):
			var twr = rib.create_tween()
			twr.tween_method(KatonLib.pf(rib, "heat"), 1.1, 0.0, 0.3)
			twr.tween_callback(rib.queue_free)
	pj.every(0.8, 0.05, wave, wave_end)
	KatonLib.light(pj, head, FIRE_L, 5.0, 10.0, 1.4)
	pj.every(1.2, 0.12, func(_i, _k):
		if is_instance_valid(dh):
			KatonLib.embers(pj, dh.global_position + Vector3.UP * 0.4, 4, 0.7, KatonLib.PAL_FIRE, {"vmin": 1.0, "vmax": 3.0, "life": 0.7}), Callable())
	for k in 5:
		pj.after(0.35 + k * 0.16, func():
			if pj.live(c) and is_instance_valid(dh):
				var mouth = dh.global_position - dh.global_transform.basis.z * 1.6
				KatonLib.glow(pj, mouth, 1.6, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.2)
				var body_fn = func() -> Node3D:
					return _karyudan_dart()
				var tick_fn = func(p: Projectile, dt: float) -> void:
					var r: Node3D = p.get_child(0) if p.get_child_count() > 0 else null
					if r and is_instance_valid(r):
						r.rotate_object_local(Vector3.FORWARD, dt * 16.0)
				var boom_fn = func(p: Vector3, ep: float) -> void:
					_karyudan_pierce(pj, p, 1.1 * ep)
				_bolt(pj, c, "katon_karyudan", tt, mouth, 1.2, 30.0, 0.5, {"burn": 2.0}, 1.1, 0.04, body_fn, tick_fn, boom_fn))
	Sfx.play("roar", head, 1.1)


## İnce alev mermisi (-Z ileri): uzun sivri çekirdek + çevresinde dönen iki sarmal alev şeridi + arkaya uzanan dar dil
static func _karyudan_dart() -> Node3D:
	var root = Node3D.new()
	var core = KatonLib.mass_mi(0.36, KatonLib.PAL_FIRE, 1.45, 2.6)
	core.scale = Vector3(0.24, 0.24, 0.7)
	root.add_child(core)
	for h in 2:
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 17:
			var u = float(i) / 16.0
			var a = u * TAU * 1.5 + h * PI
			pts.append(Vector3(cos(a) * 0.3 * (0.4 + u), sin(a) * 0.3 * (0.4 + u), -0.5 + u * 1.9))
			wid.append(1.0 - u * 0.7)
		root.add_child(KatonLib.ribbon_mi(pts, 0.09, KatonLib.PAL_FIRE, {"flow": 6.0, "tiles": 3.0, "rag": 0.4, "widths": wid}))
	var tg = KatonLib.tongue_mi(1.6, 0.45, Vector3(0, 0.1, 1.0), KatonLib.PAL_FIRE, 3, 0.0, 1.1)
	tg.position = Vector3(0, 0, 0.3)
	root.add_child(tg)
	return root


## Delici çarpma: kısa parlak çakma + ileri doğru dar huni halinde saçılan diller + kor + küçük iz
static func _karyudan_pierce(pj: PathJutsu, p: Vector3, s: float) -> void:
	KatonLib.glow(pj, p, 2.4 * s, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.18)
	KatonLib.mass(pj, p, 0.25, 1.1 * s, 0.35, Vector3.UP * 0.8, KatonLib.PAL_FIRE, 1.4, 2.2)
	for k in 8:
		var dv = Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), randf_range(-0.6, 0.6)).normalized()
		KatonLib.tongue(pj, p, randf_range(1.0, 1.6) * s, 0.4 * s, 0.32, dv, dv * 5.0, KatonLib.PAL_FIRE, 3)
	KatonLib.embers(pj, p, 16, 0.3, KatonLib.PAL_FIRE, {"vmin": 4.0, "vmax": 10.0, "spread": 60.0, "life": 0.7})
	KatonLib.light(pj, p, FIRE_L, 4.0, 7.0, 0.3)
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 1.5:
		KatonLib.scorch(pj, g, 1.2 * s, 3.5)


# ================================================================== 13) Kaen Senpū: kullanıcıyı saran alev girdabı
## Kullanıcı dönerken bedeninden fışkıran alev onu saran yükselen sarmal şeritlere ve girdaba dönüşür (anime: fırıldak sarmal);
## yaklaşanı merkeze çeker ve yakar; sonunda şeritler dışa savrulur. Zeminde sarmal yanık izi kalır.
static func katon_kaen_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var at = c.global_position
	var R = 2.8
	var H = 7.5
	var dur = 1.6
	var root = Node3D.new()
	KatonLib.put(pj, root, pj.gp(at))
	var spin = Node3D.new()
	root.add_child(spin)
	for h in 3:
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		var a0 = h * TAU / 3.0
		for i in 25:
			var u = float(i) / 24.0
			var a = a0 + u * TAU * 1.6
			var r = lerpf(0.7, R, u)
			pts.append(Vector3(cos(a) * r, 0.2 + u * H, sin(a) * r))
			wid.append(0.5 + u * 1.2)
		spin.add_child(KatonLib.ribbon_mi(pts, 0.55, KatonLib.PAL_FIRE, {"flow": 4.0, "tiles": 6.0, "rag": 0.5, "widths": wid}))
	root.scale = Vector3(0.3, 0.15, 0.3)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	KatonLib.scorch(pj, pj.gp(at), R * 1.3, dur + 3.0, 1.0, KatonLib.PAL_FIRE, 0.6)
	KatonLib.light(pj, pj.gp(at) + Vector3.UP * H * 0.4, FIRE_L, 8.0, R * 6.0, dur)
	var st0 = {"t": 0.0, "p": pj.gp(at)}
	var tick = func(i, _k):
		st0["t"] += 0.05
		if c and is_instance_valid(c):
			st0["p"] = pj.gp(c.global_position)
		var base: Vector3 = st0["p"]
		if is_instance_valid(root):
			root.global_position = base
			spin.rotate_y(0.05 * 9.0)
		# huni yüzeyinden teğet savrulan diller
		for q in 2:
			var hk = randf()
			var a = randf() * TAU
			var r = R * (0.3 + 0.7 * hk)
			var p = base + Vector3(cos(a) * r, hk * H * 0.9 + 0.3, sin(a) * r)
			var tv = Vector3(-sin(a), 0.5, cos(a)).normalized()
			KatonLib.tongue(pj, p, randf_range(1.0, 1.8) * (0.6 + hk), 0.8, 0.35, tv, tv * 4.0, KatonLib.PAL_FIRE, 4)
		if i % 3 == 0:
			KatonLib.embers(pj, base + Vector3.UP * 0.5, 6, R, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 2.0, "vmax": 6.0, "spread": 30.0, "life": 0.8})
		# --- oynanış (eski alev hortumu: merkeze çekme + hafif yakma)
		if i % 4 == 0:
			for e in pj.enemies_near(c, base, R * 1.1):
				var to = base - e.global_position
				to.y = 0
				if "velocity" in e:
					e.velocity += to.normalized() * 3.0 + Vector3.UP * 2.0
				e.take_hit(pj.inf(c, "katon_kaen_senpu", 0.3, {"knock": 1.0, "kind": "light", "element": "katon", "burn": 1.0}))
	var done = func():
		# şeritler dışa savrulur, söner
		if is_instance_valid(root):
			var tw2 = root.create_tween().set_parallel()
			tw2.tween_property(root, "scale", Vector3(2.2, 1.2, 2.2), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			for rb in spin.get_children():
				if rb is MeshInstance3D:
					tw2.tween_method(KatonLib.pf(rb, "heat"), 1.1, 0.0, 0.4)
			tw2.chain().tween_callback(root.queue_free)
	pj.every(dur, 0.05, tick, done)
	pj.after(1.5, func():
		if pj.live(c):
			var cp = c.global_position + Vector3.UP
			for k in 14:
				var a = k * TAU / 14.0
				var dv = Vector3(cos(a), 0.15, sin(a)).normalized()
				KatonLib.tongue(pj, cp + dv * 0.6, randf_range(1.6, 2.4), 1.0, 0.45, dv, dv * 8.0, KatonLib.PAL_FIRE, 5)
			KatonLib.mass(pj, cp, 0.6, 2.2, 0.5, Vector3.UP, KatonLib.PAL_FIRE, 1.3, 1.6)
			KatonLib.embers(pj, cp, 30, 1.0, KatonLib.PAL_FIRE, {"vmin": 6.0, "vmax": 11.0, "spread": 180.0, "life": 0.9})
			pj.hit(c, c.global_position + Vector3.UP, 4.0, pj.inf(c, "katon_kaen_senpu", 0.9, {"knock": 14.0, "launch": 5.0, "kind": "heavy", "element": "katon", "burn": 2.0})))
	Sfx.play("fire", at, 0.6)


# ================================================================== 14) Beni Jigumo: kızıl alev örümcek ağı
## Ellerden çıkan kızıl alev ipliği önde yere çakılır, oradan zemine kızıl alev ağı örülür (sekiz ışın + dört sarkık halka),
## ipler boyunca kısa kızıl diller titrer; merkezde alevden bir örümcek çömelir. Ağın içindekiler yanar ve yavaşlar.
static func katon_beni_jigumo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var at = pj.gp(c.global_position + pj.fwd(c, t) * 6.0)
	var dur = 5.0
	# atılan iplik
	var hp = pj.hand_pos(c, true)
	var shotp = PackedVector3Array()
	for i in 11:
		var u = float(i) / 10.0
		shotp.append(hp.lerp(at + Vector3.UP * 0.1, u) + Vector3.UP * sin(u * PI) * 1.0)
	KatonLib.ribbon(pj, shotp, 0.06, 0.4, KatonLib.PAL_CRIMSON, {"flow": 6.0, "tiles": 4.0, "rag": 0.2})
	# ağ: 8 ışın + 4 halka (halka ipleri merkeze doğru sarkar)
	var spokes: Array = []
	for i in 8:
		var a = TAU * i / 8.0
		spokes.append(Vector3(cos(a), 0, sin(a)))
	var radii = [1.0, 2.3, 3.6, 4.9]
	var threads: Array = []
	for i in 8:
		var pts = PackedVector3Array()
		for s in 9:
			var q = at + spokes[i] * (5.0 * float(s) / 8.0)
			pts.append(KatonLib.floor_at(q) + Vector3.UP * 0.07)
		threads.append(pts)
	for r in radii:
		for i in 8:
			var a0: Vector3 = spokes[i] * r
			var a1: Vector3 = spokes[(i + 1) % 8] * r
			var pts = PackedVector3Array()
			for s in 7:
				var u = float(s) / 6.0
				var q = at + a0.lerp(a1, u) * (1.0 - sin(u * PI) * 0.1)
				pts.append(KatonLib.floor_at(q) + Vector3.UP * 0.07)
			threads.append(pts)
	var all_pts: Array = []
	var web: Array = []
	for k in threads.size():
		var pts: PackedVector3Array = threads[k]
		var mi = KatonLib.ribbon_mi(pts, 0.08, KatonLib.PAL_CRIMSON, {"hint": Vector3.UP, "twin": false, "flow": 1.5, "tiles": 3.0, "rag": 0.3})
		mi.set_instance_shader_parameter("head", 0.0)
		KatonLib.put(pj, mi, Vector3.ZERO)
		web.append(mi)
		for p in pts:
			all_pts.append(p)
		var tw = mi.create_tween()
		tw.tween_interval(0.25 if k < 8 else 0.35 + float(k - 8) * 0.01)
		tw.tween_method(KatonLib.pf(mi, "head"), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(dur)
		tw.tween_method(KatonLib.pf(mi, "heat"), 1.1, 0.0, 0.6)
		tw.tween_callback(mi.queue_free)
	# ip boyunca titreyen kısa kızıl diller
	pj.every(dur, 0.15, func(_i, _k):
		if _i < 3 or all_pts.is_empty():
			return
		for q in 3:
			var p: Vector3 = all_pts[randi() % all_pts.size()]
			KatonLib.tongue(pj, p, randf_range(0.35, 0.7), 0.3, 0.45, Vector3.UP, Vector3.ZERO, KatonLib.PAL_CRIMSON, 3, 1.1), Callable())
	# merkezdeki alev örümceği
	var spider = _fire_spider()
	KatonLib.put(pj, spider, at)
	KatonLib.look(spider, at - c.global_position)
	spider.scale = Vector3.ONE * 0.05
	var tws = spider.create_tween()
	tws.tween_interval(0.35)
	tws.tween_property(spider, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tws.tween_interval(dur - 0.3)
	tws.tween_property(spider, "scale", Vector3.ONE * 0.05, 0.3)
	tws.tween_callback(spider.queue_free)
	KatonLib.scorch(pj, at, 5.4, dur + 2.0, 0.0, KatonLib.PAL_CRIMSON, 0.6)
	KatonLib.light(pj, at + Vector3.UP, CRIM_L, 4.0, 10.0, dur + 0.5)
	# --- oynanış
	pj.every(5.0, 0.4, func(_i, _k):
		for e in pj.enemies_near(c, at, 5.6):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("burn", 1.5)
				e.apply_status("slow", 0.5), Callable())
	Sfx.play("fire", at, 0.8)


## Alev örümceği (-Z ileri): kızıl alev kütlesinden karın + baş, kıvrık alev şeridi bacaklar, sırtta küçük diller
static func _fire_spider() -> Node3D:
	var root = Node3D.new()
	var ab = KatonLib.mass_mi(1.0, KatonLib.PAL_CRIMSON, 1.15, 0.8)
	ab.scale = Vector3(0.75, 0.6, 0.95)
	ab.position = Vector3(0, 0.75, 0.75)
	root.add_child(ab)
	var hd = KatonLib.mass_mi(0.5, KatonLib.PAL_CRIMSON, 1.25, 0.8)
	hd.position = Vector3(0, 0.6, -0.35)
	root.add_child(hd)
	for sx in [-1.0, 1.0]:
		for i in 4:
			var z = -0.55 + i * 0.32
			var pts = PackedVector3Array()
			var wid = PackedFloat32Array()
			for j in 9:
				var u = float(j) / 8.0
				var reach = 0.3 + u * 1.8
				pts.append(Vector3(sx * reach, 0.6 + sin(u * PI * 1.1) * 0.75 - u * 0.55, z + (z * 0.6) * u))
				wid.append(1.0 - u * 0.6)
			root.add_child(KatonLib.ribbon_mi(pts, 0.09, KatonLib.PAL_CRIMSON, {"flow": 3.0, "tiles": 2.0, "rag": 0.35, "widths": wid}))
	for q in 3:
		var tg = KatonLib.tongue_mi(0.9, 0.6, Vector3(0, 1, 0.3), KatonLib.PAL_CRIMSON, 4, 0.0, 1.1)
		tg.position = Vector3((q - 1) * 0.3, 1.1, 0.7)
		root.add_child(tg)
	var b = MB.new()
	for i in 4:
		var x = (i - 1.5) * 0.12
		b.add("sphere", Vector3(x, 0.78 + absf(x) * 0.2, -0.75), Vector3(0.08, 0.08, 0.05), Color(1.0, 0.95, 0.7), Vector3.ZERO, 6)
	root.add_child(_flat(b))
	return root


# ================================================================== 15) Suyaki: ayak altından tutuşan zemin
## Hedefin ayağının altında zemin önce kızgın çatlaklarla ısınır, sonra sık, kısa diller halinde tutuşur; üstünde ısı dalgası,
## yükselen kor; içindekiler yavaşlar ve yanar. Sönünce kararmış zemin soğuyarak kalır.
static func katon_suyaki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	# ısınma: kızgın damarlı zemin hızla yayılır, birkaç dil önden fırlar
	KatonLib.scorch(pj, at, 3.2, 6.0, 0.0, KatonLib.PAL_FIRE, 0.35)
	for k in 5:
		var a = randf() * TAU
		KatonLib.tongue(pj, KatonLib.floor_at(at + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 1.5)), randf_range(1.6, 2.4), 0.7, 0.5, Vector3.UP, Vector3.UP * 1.0, KatonLib.PAL_FIRE, 4)
	# tutuşan halı: sık, kısa diller 3 sn
	pj.after(0.15, func():
		KatonLib.burn_patch(pj, at, 2.6, 3.0, KatonLib.PAL_FIRE, 0.05, 1.8))
	KatonLib.shimmer(pj, at + Vector3.UP * 2.2, 5.2, 4.0, 3.4)
	KatonLib.light(pj, at + Vector3.UP, Color(1.0, 0.5, 0.15), 6.0, 10.0, 3.0)
	# --- oynanış
	GroundFX.add(at, "burning", 3.0, 4.0, c)
	pj.every(3.0, 0.5, func(_i, _k):
		for e in pj.enemies_near(c, at, 3.0):
			if pj.live(e):
				if e.has_method("apply_status"):
					e.apply_status("slow", 0.8)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "katon_suyaki", 0.3, {"knock": 0.0, "kind": "light", "element": "katon", "burn": 2.0})), Callable())
	Sfx.play("fire", at, 0.7)
