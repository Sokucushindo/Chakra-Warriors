class_name HyotonFXA
extends RefCounted
## Hyōton grubu A: on buz tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları HyotonLib'den (kendi yüzlü buz
## gölgelendiricisi, kırağı tabakası, kar, soğuk nefes, kırıntı); yaratıklar (kara ejder, kurt, balina, kaplan, kırlangıç)
## bu dosyada gerçek boyda yüzlü buzdan kurulur. Her tekniğin şekli, hareketi ve sahnelenmesi kendine özgü.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/hyoton_lib.gd")

const ICE_C := Color(0.7, 0.9, 1.0)
const RAI_C := Color(0.65, 0.85, 1.0)

static var _c := {}


static func _cached(key: String, fn: Callable) -> ArrayMesh:
	if not _c.has(key):
		_c[key] = fn.call()
	return _c[key]


# ================================================================== Hyōton: Hyōgan Dōmu (Buz Kaya Kubbesi)
## Hedefin ayağından kırağı halka halinde yayılır; çevresinde içe eğik buz levhaları fırlar, ardından blok blok örülmüş
## yüzlü buz kubbesi tabandan tepeye kapanır (gerilmeden büyür), tabanında kar kabuğu, çevresinde kar savrulması ve
## soğuk buğu. Süre dolunca kubbe çatlar (çizgileri koyulaşır) ve iri bloklara ayrılıp yuvarlanır; kırağı yavaşça söner.
static func hyoton_hyogan_domu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	L.frost(pj, at, 4.6, 4.2, {"t": 0.22, "out": 1.6})
	# içe eğik levhalar: kubbenin dibinde payanda
	var slabs: Array = []
	for k in 10:
		var a = k * TAU / 10.0 + randf_range(-0.1, 0.1)
		var dv = Vector3(cos(a), 0, sin(a))
		var sl = L.imi(L.slab_mesh(1.25, randf_range(1.3, 1.9), 0.26, k % 4), {"alpha": 0.8, "frost": 0.3, "near": 2.0})
		L.put(pj, sl, at + dv * 2.45)
		sl.global_basis = Basis.looking_at(-dv, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(-24.0))
		L.reveal(sl, 2.0, 0.12, k * 0.008)
		slabs.append(sl)
	# kubbe: tabandan tepeye kapanır
	var dome = L.imi(L.dome_mesh(2.4), {"two": true, "outline": true, "ow": 0.03, "alpha": 0.6, "frost": 0.45, "near": 2.2})
	L.put(pj, dome, at)
	dome.rotation.y = randf() * TAU
	L.reveal(dome, 2.6, 0.3, 0.08)
	L.later(pj, 0.08, func():
		if is_instance_valid(dome):
			L.glints(pj, at + Vector3.UP * 1.2, {"n": 18, "r": 1.8}))
	for k in 8:
		var a = k * TAU / 8.0 + randf() * 0.3
		var dv = Vector3(cos(a), 0, sin(a))
		L.mist(pj, at + dv * 2.8 + Vector3.UP * 0.5, randf_range(2.4, 3.2), 1.8, {"alpha": 0.55, "drift": dv * 1.6 + Vector3.UP * 0.15, "s0": 0.4, "grow": 0.5})
	L.snow(pj, at + Vector3.UP * 0.3, {"n": 40, "r": 2.4, "dir": Vector3.UP, "spread": 70.0, "vmin": 2.0, "vmax": 5.5, "smin": 0.12, "smax": 0.3, "life": 1.1})
	# süre sonu: çatlar, bloklara ayrılır
	var tw = dome.create_tween()
	tw.tween_interval(4.05)
	tw.tween_method(func(v: float): dome.set_instance_shader_parameter("crack", v), 0.0, 1.0, 0.28)
	tw.tween_callback(func():
		L.debris(pj, at + Vector3.UP * 1.3, {"n": 14, "s": 0.55, "r": 1.6, "v": 5.0, "up": 3.0, "life": 1.3})
		L.chips(pj, at + Vector3.UP * 1.4, {"n": 26, "r": 1.6, "vmin": 2.0, "vmax": 7.0})
		L.snow(pj, at + Vector3.UP * 0.6, {"n": 34, "r": 2.2, "vmin": 1.0, "vmax": 4.0})
		for sl in slabs:
			if is_instance_valid(sl):
				L.fade_free(sl, 0.0, 0.25))
	tw.tween_callback(dome.queue_free)
	pj.st(tt, "bind", 4.3)
	Combat.popup_text(at + Vector3.UP * 2.8, "Dondu!", ICE_C)
	Sfx.play("clink", at, 0.7)


# ================================================================== Hissatsu Hyōsō (Kesin Ölüm Buz Mızrakları)
## Havadaki nem hedefin çevresinde içe çekilen buğu kartlarıyla yoğunlaşır; her noktada kırağı parıltısı, ardından buz
## mızrağı dipten uca gerilmeden uzar. Mızraklar aynı anda hedefe saplanır, uçları merkezde kesişip kirpi gibi bir
## buz yıldızı kalır; saplanma anında yonga ve kırağı, kısa süre sonra mızraklar çatlayıp kırıntıya döner.
static func hissatsu_hyoso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 22.0)
	var at = (tt.global_position + Vector3.UP if tt else c.global_position + pj.fwd(c, t) * 10.0 + Vector3.UP)
	for k in 9:
		var a = k * TAU / 9.0 + randf() * 0.4
		var dv = Vector3(cos(a), randf_range(-0.1, 0.5), sin(a)).normalized()
		L.mist(pj, at + dv * 4.6, randf_range(2.0, 2.8), 1.0, {"alpha": 0.45, "drift": -dv * 3.0, "s0": 0.6, "grow": -0.3, "fin": 0.25})
	var spikes = []
	var sl = 1.9
	for k in 16:
		var a = k * TAU / 16.0
		var e = randf_range(-0.2, 0.9)
		var q = at + Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 5.0
		var sp = Node3D.new()
		var mi = L.imi(L.shard_mesh(sl, 0.17, k % 6, 5), {"alpha": 0.82, "near": 1.6})
		sp.add_child(mi)
		mi.rotation.x = -PI * 0.5   # +Y ucu -Z'ye (hedefe) döner
		pj.get_tree().current_scene.add_child(sp)
		sp.global_position = q
		sp.look_at(at, Vector3.UP if absf((at - q).normalized().y) < 0.95 else Vector3.RIGHT)
		L.reveal(mi, sl, 0.25, k * 0.01)
		L.free_later(pj, sp, 3.0)
		spikes.append([sp, q])
	L.glints(pj, at, {"n": 24, "r": 4.8, "smin": 0.2, "smax": 0.4, "life": 0.6})
	pj.after(0.55, func():
		for s in spikes:
			var sp: Node3D = s[0]
			if not is_instance_valid(sp):
				continue
			var q: Vector3 = s[1]
			var dir = (at - q).normalized()
			var tw = sp.create_tween()
			tw.tween_property(sp, "global_position", at - dir * sl * 0.72, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.62)
			tw.tween_method(func(v: float):
				for ch in sp.get_children():
					if ch is GeometryInstance3D:
						ch.set_instance_shader_parameter("crack", v), 0.0, 1.0, 0.16)
			tw.tween_callback(func():
				L.chips(pj, sp.global_position + dir * sl * 0.4, {"n": 5, "r": 0.4, "vmin": 1.5, "vmax": 4.0}))
			tw.tween_callback(sp.queue_free)
		pj.after(0.12, func():
			L.chips(pj, at, {"n": 34, "r": 0.5, "vmin": 4.0, "vmax": 10.0})
			L.glints(pj, at, {"n": 16, "r": 1.0, "vmin": 1.0, "vmax": 3.0})
			L.frost(pj, at, 2.6, 1.4, {"t": 0.15})
			pj.hit(c, at, 2.4, pj.inf(c, "hissatsu_hyoso", 2.0, {"knock": 4.0, "kind": "heavy", "element": "hyoton", "bleed": 4.0, "hitstop": 0.1}))))
	Sfx.play("clink", at, 0.8)


# ================================================================== Hyōton: Mangehyō (On Bin Buz Yaprağı)
## Avuçlarda kırağı parıltısı toplanır, ayak dibi donar; ardından önde koni biçiminde ileri savrulan bir kar tipisi içinden
## otuz ince, sırtlı buz yaprağı dönerek fırlar (her dördüncüsü kar izi bırakır), değdiği yerde ufak kırağı pırıltısı.
static func hyoton_mangehyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 22.0)
	var d = pj.fwd(c, tt)
	L.glints(pj, pj.hand_pos(c, true), {"n": 10, "r": 0.35, "life": 0.5})
	L.glints(pj, pj.hand_pos(c, false), {"n": 10, "r": 0.35, "life": 0.5})
	L.frost(pj, c.global_position, 2.2, 1.0, {"t": 0.2})
	var leaf_mesh = L.leaf_mesh(0.46, 0.1)
	for k in 30:
		pj.after(0.15 + k * 0.025, func():
			if not pj.live(c):
				return
			var holder = Node3D.new()
			holder.add_child(L.imi(leaf_mesh, {"alpha": 0.85, "near": 1.2}))
			var from = c.global_position + Vector3.UP * 1.3 + d.cross(Vector3.UP) * randf_range(-1.5, 1.5)
			var pr = pj.shot(c, from, (pj.aim_at(c, tt, from) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.15), randf_range(-0.2, 0.2))).normalized(), 40.0, holder, pj.inf(c, "hyoton_mangehyo", 0.08, {"knock": 0.8, "kind": "light", "element": "hyoton", "bleed": 1.0}), null, false, 0.9)
			pr.spin = Vector3(14, 8, 0)
			if k % 4 == 0:
				L.trail(pr, {"n": 16, "life": 0.35, "smin": 0.08, "smax": 0.16, "dir": Vector3.UP, "spread": 180.0, "vmin": 0.1, "vmax": 0.4})
			pr.on_hit = func(p, _h):
				if k % 3 == 0:
					L.glints(pj, p, {"n": 4, "r": 0.2, "life": 0.35, "smin": 0.12, "smax": 0.22}))
	var cone_at = c.global_position + Vector3.UP * 1.3 + d * 1.2
	L.snow(pj, cone_at, {"n": 60, "dir": d, "spread": 22.0, "vmin": 9.0, "vmax": 18.0, "g": Vector3(0, -1.0, 0), "damp": 2.0, "life": 0.9, "r": 0.5})
	for k in 4:
		L.mist(pj, cone_at + d * (1.5 + k * 1.8), 2.0 + k * 0.6, 0.9, {"alpha": 0.4, "drift": d * 5.0, "s0": 0.5, "grow": 0.6})
	Sfx.play("wind", c.global_position, 1.3)


# ================================================================== Hyōton: Suishōheki (Kristal Buz Duvarı)
## Kaynak (anime): yerden fışkıran, iç içe geçmiş dev yüzlü buz sütunları; dipte küçük kırık sivriler, yüzlerde derin mavi
## gölge ve kırılma çizgileri. Sütunlar ortadan dışa doğru sırayla tabandan uca uzar (gerilmeden), önüne yonga ve kar
## savrulur, dibi kırağı tutar. Takılan mermi yüzeyde kırıntı + pırıltı saçar. Süre sonunda üç noktadan bloklara ayrılır.
static func hyoton_suishoheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 3.0)
	var side = d.cross(Vector3.UP)
	# katı buz duvarı: içinden geçilemez (çarpışma), fışkırırken önündekileri savurur, mermileri durdurur
	var wall = StaticBody3D.new()
	pj.get_tree().current_scene.add_child(wall)
	wall.global_position = at
	wall.look_at(at + d, Vector3.UP)
	# sütunlar: yerel X boyunca 7 m, ortada en yüksek
	for k in 11:
		var x = (k - 5) * 0.66 + randf_range(-0.12, 0.12)
		var hgt = 4.3 - absf(x) * 0.32 + randf_range(-0.35, 0.3)
		var r = randf_range(0.55, 0.82)
		var mi = L.imi(L.shard_mesh(hgt, r, k % 6, 6), {"alpha": 0.84, "frost": 0.3, "outline": true, "ow": 0.025, "pal": (L.DEEP if k % 3 == 1 else L.ICE), "near": 2.0})
		wall.add_child(mi)
		mi.position = Vector3(x, 0, randf_range(-0.25, 0.25))
		mi.rotation = Vector3(randf_range(-0.12, 0.12), randf() * TAU, randf_range(-0.14, 0.14))
		L.reveal(mi, hgt + 0.2, 0.2, absf(k - 5) * 0.022)
	# dipte kırık küçük sivriler (ön ve arka)
	for k in 9:
		var x = randf_range(-3.4, 3.4)
		var hgt = randf_range(0.6, 1.3)
		var mi = L.imi(L.shard_mesh(hgt, randf_range(0.18, 0.3), k % 6, 5), {"alpha": 0.86, "frost": 0.15, "near": 1.6})
		wall.add_child(mi)
		mi.position = Vector3(x, 0, (0.7 if k % 2 == 0 else -0.7) + randf_range(-0.15, 0.15))
		mi.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
		L.reveal(mi, hgt, 0.15, 0.1 + k * 0.01)
	after_coll(pj, wall)
	Jutsu._element_wall(wall, "hyoton", c, Vector3(0, 2.0, 0), Vector3(3.6, 2.0, 0.7), 45.0 * Jutsu._mult(c))
	for k in 3:
		L.frost(pj, at + side * ((k - 1) * 2.6), 2.4, 6.0, {"t": 0.2, "out": 0.6})
	# fışkırma darbesi: duvar hattındakiler hasar alır ve geriye savrulur
	var hits = []
	for k in 5:
		var p = at + side * ((k - 2) * 1.5) + Vector3.UP
		hits.append_array(pj.hit(c, p, 1.4, pj.inf(c, "hyoton_suishoheki", 1.4, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "hyoton", "slow": 2.0, "hitstop": 0.08}), hits))
	L.chips(pj, at + Vector3.UP * 1.0 + d * 0.8, {"n": 34, "box": Vector3(3.2, 0.8, 0.3), "dir": d + Vector3.UP * 0.6, "spread": 40.0, "vmin": 4.0, "vmax": 9.0})
	L.snow(pj, at + Vector3.UP * 0.4 + d * 0.6, {"n": 40, "box": Vector3(3.4, 0.3, 0.4), "dir": d + Vector3.UP * 0.4, "spread": 45.0, "vmin": 2.0, "vmax": 6.0})
	for k in 4:
		L.mist(pj, at + side * ((k - 1.5) * 2.0) + d * 1.0 + Vector3.UP * 0.5, 3.0, 1.6, {"alpha": 0.45, "drift": d * 1.2 + Vector3.UP * 0.3})
	pj.shake(0.4)
	pj.after(6.5, func():
		if is_instance_valid(wall):
			for k in 3:
				var bp = at + side * ((k - 1) * 2.4) + Vector3.UP * 1.6
				L.debris(pj, bp, {"n": 7, "s": 0.5, "r": 1.0, "v": 4.0, "up": 3.0, "life": 1.2})
				L.chips(pj, bp, {"n": 12, "r": 1.0})
			wall.queue_free())
	pj.every(6.5, 0.1, func(_i, _k):
		if not is_instance_valid(wall):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and absf((p.global_position - at).dot(d)) < 1.0 and absf((p.global_position - at).dot(side)) < 3.8 and p.global_position.y < at.y + 4.5:
				L.chips(pj, p.global_position, {"n": 8, "r": 0.15, "vmin": 2.0, "vmax": 4.0, "smin": 0.4, "smax": 0.8})
				L.glints(pj, p.global_position, {"n": 5, "r": 0.2, "life": 0.4})
				p.queue_free(), Callable())
	Sfx.play("clink", at, 0.8)


## Duvarın çarpışma kutusu (fışkırma başladıktan 0.15 sn sonra)
static func after_coll(pj: PathJutsu, wall: StaticBody3D) -> void:
	pj.after(0.15, func():
		if is_instance_valid(wall):
			var cs = CollisionShape3D.new()
			var sh = BoxShape3D.new()
			sh.size = Vector3(7.2, 4.0, 1.4)
			cs.shape = sh
			cs.position = Vector3.UP * 2.0
			wall.add_child(cs))


# ================================================================== Hyōton: Kokuryū Bōfūsetsu (Kara Ejder Tipisi)
## Kaynak (film): kara buz-kardan ejder; gri ince konturlar, kızıl yanan gözler ve kızıl dişli açık ağız, geriye savrulan
## boynuz ve bıyıklar. Atanın ayağı kara kırağıyla kaplanır, kara kar girdabı yükselir. Baş kendi ekseni çevresinde sarmal
## çizerek uçar; gövde halkaları başın geçtiği yolu birebir izler (burgu gövde), yol boyunca kara tipi sisi ve kara kar.
## Çarpınca kara kar patlaması + kara buz kırıntıları; gövde halka halka dağılır.
static func hyoton_kokuryu_bofusetsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 32.0)
	L.frost(pj, c.global_position, 3.2, 2.0, {"pal": 1.0, "t": 0.25})
	L.snow(pj, c.global_position + Vector3.UP * 0.4, {"dark": true, "n": 30, "r": 1.4, "dir": Vector3.UP, "spread": 35.0, "vmin": 2.0, "vmax": 5.0, "g": Vector3(0, -1.0, 0)})
	pj.after(0.35, func():
		if not pj.live(c):
			return
		var d0 = pj.fwd(c, tt)
		var from = pj.hand_pos(c, true) + d0 * 1.0
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 23.0, _koku_head(), pj.inf(c, "hyoton_kokuryu_bofusetsu", 2.3, {"knock": 3.0, "launch": 17.0, "kind": "heavy", "element": "hyoton", "slow": 2.0, "hitstop": 0.12}), tt, false, 2.4,
			func(p, _h):
				L.snow(pj, p, {"dark": true, "n": 50, "r": 1.2, "vmin": 3.0, "vmax": 9.0, "smin": 0.15, "smax": 0.34})
				L.debris(pj, p, {"n": 10, "s": 0.4, "pal": L.BLACK, "v": 6.0, "up": 4.0})
				for k in 4:
					L.mist(pj, p + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.8), randf_range(-1, 1)), 3.2, 1.2, {"tone": 1.0, "alpha": 0.55, "drift": Vector3(randf_range(-2, 2), 0.6, randf_range(-2, 2))})
				pj.shake(0.5))
		pr.radius = 1.1
		pr.homing_turn = 2.6
		L.trail(pr, {"n": 40, "life": 0.7, "r": 0.9, "smin": 0.14, "smax": 0.3, "vmin": 0.5, "vmax": 2.0, "spread": 60.0,
			"cols": [Color(0.12, 0.12, 0.16, 1.0), Color(0.08, 0.08, 0.11, 0.9), Color(0.05, 0.05, 0.08, 0.0)]})
		_koku_body(pj, pr)
		var s0 = {"t": 0.0, "off": Vector3.ZERO}
		pr.on_tick = func(p, dt):
			s0["t"] += dt
			var v: Vector3 = p.vel.normalized()
			var sd = v.cross(Vector3.UP).normalized()
			var off = (sd * cos(s0["t"] * 14.0) + sd.cross(v) * sin(s0["t"] * 14.0)) * 1.5 * minf(1.0, s0["t"] * 3.0)
			p.global_position += off - s0["off"]
			s0["off"] = off
			var fl = Game.jutsu_floor(p.global_position.x, p.global_position.z) + 0.9   # sarmal ejderi yere gömmesin
			if p.global_position.y < fl:
				p.global_position.y = fl
		L.snow(pj, from, {"dark": true, "n": 30, "r": 0.6, "dir": d0, "spread": 50.0, "vmin": 3.0, "vmax": 8.0})
		L.mist(pj, from, 2.6, 0.9, {"tone": 1.0, "alpha": 0.5, "drift": d0 * 3.0})
		Sfx.play("wind", from, 0.7))
	Sfx.play("clink", c.global_position, 0.6)


## Kara ejder başı (gerçek boyda, ileri -Z): kara buz kafatası + açık çene, kızıl ağız içi / dişler / yarık gözler,
## geriye savrulan boynuzlar ve uzun bıyıklar
static func _koku_head() -> Node3D:
	var root = Node3D.new()
	var skull = _cached("koku_skull", func():
		var st = L.begin()
		L.loft(st, [
			{"p": Vector3(0, 0.1, 1.0), "rx": 0.85, "ry": 0.75},
			{"p": Vector3(0, 0.28, 0.3), "rx": 1.0, "ry": 0.82},
			{"p": Vector3(0, 0.22, -0.6), "rx": 0.8, "ry": 0.55},
			{"p": Vector3(0, 0.16, -1.5), "rx": 0.62, "ry": 0.4},
			{"p": Vector3(0, 0.1, -2.2), "rx": 0.45, "ry": 0.3},
			{"p": Vector3(0, 0.05, -2.45), "rx": 0.0}], 8, 0.05, 31)
		L.loft(st, [
			{"p": Vector3(0, -0.4, 0.5), "rx": 0.72, "ry": 0.3},
			{"p": Vector3(0, -0.72, -0.8), "rx": 0.55, "ry": 0.22},
			{"p": Vector3(0, -0.92, -1.9), "rx": 0.38, "ry": 0.14},
			{"p": Vector3(0, -0.98, -2.15), "rx": 0.0}], 7, 0.04, 32)
		for sx in [-1.0, 1.0]:
			# boynuzlar (ikişer, geriye ve yukarı)
			L.loft(st, [{"p": Vector3(0.42 * sx, 0.7, 0.3), "rx": 0.2}, {"p": Vector3(0.75 * sx, 1.25, 1.6), "rx": 0.12}, {"p": Vector3(0.95 * sx, 1.65, 2.9), "rx": 0.0}], 5, 0.0, 33)
			L.loft(st, [{"p": Vector3(0.62 * sx, 0.45, 0.6), "rx": 0.14}, {"p": Vector3(1.2 * sx, 0.75, 1.8), "rx": 0.0}], 5, 0.0, 34)
			# uzun bıyıklar
			L.loft(st, [{"p": Vector3(0.45 * sx, -0.05, -1.9), "rx": 0.08}, {"p": Vector3(1.4 * sx, -0.5, -0.4), "rx": 0.07}, {"p": Vector3(2.0 * sx, -0.9, 1.8), "rx": 0.05}, {"p": Vector3(2.5 * sx, -1.5, 4.0), "rx": 0.0}], 4, 0.0, 35)
			# yanak / ense dikenleri
			for i in 3:
				var y = 0.5 - i * 0.35
				L.loft(st, [{"p": Vector3(0.7 * sx, y, 0.7), "rx": 0.16}, {"p": Vector3((1.3 + i * 0.15) * sx, y - 0.1, 1.9), "rx": 0.0}], 4, 0.0, 36 + i)
		return L.finish(st))
	root.add_child(L.imi(skull, {"pal": L.BLACK, "outline": true, "ow": 0.05, "alpha": 0.96, "near": 3.0}))
	var red = L.glow_mat(Color(1.0, 0.1, 0.08))
	var inner = _cached("koku_mouth", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, -0.2, 0.3), "rx": 0.6, "ry": 0.34}, {"p": Vector3(0, -0.4, -1.0), "rx": 0.45, "ry": 0.28}, {"p": Vector3(0, -0.45, -1.9), "rx": 0.0}], 6, 0.0, 41)
		for sx in [-1.0, 1.0]:
			for i in 4:
				var z = -0.5 - i * 0.42
				L.loft(st, [{"p": Vector3(0.36 * sx * (1.0 - i * 0.12), -0.02, z), "rx": 0.08}, {"p": Vector3(0.34 * sx * (1.0 - i * 0.12), -0.36, z - 0.05), "rx": 0.0}], 4, 0.0, 42)
				L.loft(st, [{"p": Vector3(0.3 * sx * (1.0 - i * 0.12), -0.7 - i * 0.05, z), "rx": 0.07}, {"p": Vector3(0.3 * sx * (1.0 - i * 0.12), -0.42 - i * 0.05, z + 0.04), "rx": 0.0}], 4, 0.0, 43)
		return L.finish(st))
	var mo = MeshInstance3D.new()
	mo.mesh = inner
	mo.material_override = red
	mo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mo)
	var eyes = _cached("koku_eyes", func():
		var st = L.begin()
		for sx in [-1.0, 1.0]:
			L.loft(st, [{"p": Vector3(0.6 * sx, 0.5, -0.1), "rx": 0.0}, {"p": Vector3(0.66 * sx, 0.48, -0.4), "rx": 0.07, "ry": 0.2, "up": Vector3(sx, 0.4, 0)}, {"p": Vector3(0.6 * sx, 0.44, -0.75), "rx": 0.0}], 4, 0.0, 44)
		return L.finish(st))
	var ey = MeshInstance3D.new()
	ey.mesh = eyes
	ey.material_override = red
	ey.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ey)
	return root


static func _koku_seg_mesh() -> ArrayMesh:
	return _cached("koku_seg", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, 0, 1.0), "rx": 0.82, "ry": 0.74}, {"p": Vector3(0, 0.04, 0.0), "rx": 1.0, "ry": 0.9}, {"p": Vector3(0, 0, -1.0), "rx": 0.86, "ry": 0.78}], 7, 0.06, 51)
		L.loft(st, [{"p": Vector3(0, 0.7, -0.2), "rx": 0.12, "ry": 0.3, "up": Vector3(1, 0, 0)}, {"p": Vector3(0, 1.45, 0.8), "rx": 0.0}], 4, 0.0, 52)
		for sx in [-1.0, 1.0]:
			L.loft(st, [{"p": Vector3(0.75 * sx, 0.1, 0.0), "rx": 0.1}, {"p": Vector3(1.35 * sx, -0.1, 1.1), "rx": 0.0}], 4, 0.0, 53)
		return L.finish(st))


## Gövde: başın geçtiği yolu izleyen 15 halka (kuyruğa doğru incelir) + yol boyunca kara tipi sisi; baş yok olunca
## halkalar uçtan başa sönerek kara kara dağılır
static func _koku_body(pj: PathJutsu, pr: Projectile) -> void:
	var root = Node3D.new()
	L.put(pj, root, pr.global_position)
	var n = 15
	var segs: Array = []
	for i in n:
		var mi = L.imi(_koku_seg_mesh(), {"pal": L.BLACK, "outline": true, "ow": 0.05, "alpha": 0.95, "near": 3.0})
		root.add_child(mi)
		mi.top_level = true
		mi.scale = Vector3.ONE * lerpf(0.95, 0.3, float(i) / (n - 1))
		mi.visible = false
		segs.append(mi)
	var hist: Array = [pr.global_position]
	var wpr = weakref(pr)
	var s0 = {"dead": -1.0, "head": pr.global_position, "mk": 0.0, "burst": false}
	var sp = 1.15
	var total = 2.4 + 0.8
	var upd = func(tn: float):
		if not is_instance_valid(root):
			return
		var p = wpr.get_ref()
		if p != null and is_instance_valid(p) and not p.dead:
			var hp: Vector3 = p.global_position
			if hp.distance_to(hist[hist.size() - 1]) > 0.2:
				hist.append(hp)
				if hist.size() > 240:
					hist.pop_front()
			s0["head"] = hp
		elif s0["dead"] < 0.0:
			s0["dead"] = tn
		var k = 1.0 if s0["dead"] < 0.0 else clampf(1.0 - (tn - s0["dead"]) / 0.5, 0.0, 1.0)
		if s0["dead"] >= 0.0 and not s0["burst"]:
			s0["burst"] = true
			for ii in range(0, n, 3):
				var sgb: MeshInstance3D = segs[ii]
				if sgb.visible:
					L.snow(pj, sgb.global_position, {"dark": true, "n": 14, "r": 0.8, "vmin": 1.0, "vmax": 4.0})
		# yol boyunca yerleştir
		var a: Vector3 = s0["head"]
		var acc = 0.0
		var need = sp * 1.4
		var bi = hist.size() - 1
		var i = 0
		while i < n and bi >= 0:
			var b: Vector3 = hist[bi]
			var lab = a.distance_to(b)
			if lab > 0.0001 and acc + lab >= need:
				var q = a.lerp(b, (need - acc) / lab)
				var sg: MeshInstance3D = segs[i]
				sg.visible = true
				sg.global_position = q
				var f = (a - b).normalized()
				var bs = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT)
				sg.global_basis = bs.scaled(Vector3.ONE * lerpf(0.95, 0.3, float(i) / (n - 1)) * maxf(0.05, k))
				var lim = float(n - i) / n
				sg.set_instance_shader_parameter("fade", clampf((k - (1.0 - lim) * (1.0 - k)) , 0.0, 1.0))
				i += 1
				need += sp
				continue
			acc += lab
			a = b
			bi -= 1
		# tipi sisi: görünen halkalardan birinde ara ara kara buğu
		s0["mk"] += 1.0
		if k > 0.5 and int(s0["mk"]) % 7 == 0:
			var j = randi() % n
			var sgm: MeshInstance3D = segs[j]
			if sgm.visible:
				L.mist(pj, sgm.global_position + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.6), randf_range(-0.6, 0.6)), randf_range(2.4, 3.4), 1.0,
					{"tone": 1.0, "alpha": 0.4, "drift": Vector3(randf_range(-1, 1), 0.4, randf_range(-1, 1)), "near": 5.0})
	var tw = root.create_tween()
	tw.tween_method(upd, 0.0, total, total)
	tw.tween_callback(root.queue_free)


# ================================================================== Hyōton: Rōga Nadare no Jutsu (Kurt Dişi Çığı)
## Atanın önü kar örtüsüne döner, kar sütun gibi yükselir. Altı kar-buz kurdu (opak beyaz, mavi konturlu, dört bacağı
## koşar, kuyruğu savrulur) yere basarak hedeflere koşar, patilerinden kar savrulur; ardından yuvarlanan çığ cephesi kalın
## kar buğusu ve uçuşan kar tanesiyle ilerler, geçtiği yer kar örtüsüyle kalır. Raiton değen kurt kar olup dağılır.
static func hyoton_roga_nadare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 34.0)
	L.frost(pj, c.global_position, 4.5, 2.0, {"mode": 1.0, "t": 0.3})
	L.snow(pj, c.global_position + Vector3.UP * 0.3, {"n": 40, "r": 2.5, "dir": Vector3.UP, "spread": 25.0, "vmin": 3.0, "vmax": 7.0, "smin": 0.14, "smax": 0.32, "life": 1.0})
	var d = pj.fwd(c, tt)
	var side = d.cross(Vector3.UP)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var foes = pj.enemies_near(c, c.global_position + d * 16.0, 24.0)
		for k in 6:
			pj.after(k * 0.08, func():
				if not pj.live(c):
					return
				var w = Node3D.new()
				var wolf = _wolf()
				wolf.position.y = -0.85
				w.add_child(wolf)
				var target: Node3D = tt
				if not foes.is_empty():
					target = foes[k % foes.size()]
				var from = pj.gp(c.global_position + d * 1.8 + side * (k - 2.5) * 1.4) + Vector3.UP * 0.85
				var pr = pj.shot(c, from, (d + side * (k - 2.5) * 0.12).normalized(), 19.0 + (k % 3) * 1.5, w, pj.inf(c, "hyoton_roga_nadare", 0.9, {"knock": 5.0, "kind": "heavy", "element": "hyoton", "bleed": 3.0, "slow": 2.5}), target, false, 2.6,
					func(p, _h):
						L.snow(pj, p, {"n": 30, "r": 0.6, "vmin": 2.0, "vmax": 6.0, "smin": 0.12, "smax": 0.28})
						L.chips(pj, p, {"n": 8, "r": 0.4, "pal": L.SNOW}))
				pr.radius = 0.8
				pr.homing_turn = 3.2
				var kick = L.trail(w, {"n": 26, "life": 0.5, "r": 0.35, "dir": Vector3(0, 1, 1), "spread": 40.0, "vmin": 1.0, "vmax": 2.5, "g": Vector3(0, -5.0, 0), "smin": 0.1, "smax": 0.24})
				kick.position = Vector3(0, -0.8, 0.3)
				var ph = {"v": randf() * TAU}
				pr.on_tick = func(p, dt):
					p.global_position.y = Game.jutsu_floor(p.global_position.x, p.global_position.z) + 0.85
					ph["v"] += dt * 15.0
					_run(wolf, ph["v"], 0.7)
					for q in pj.get_tree().get_nodes_in_group("projectiles"):
						if q != p and is_instance_valid(q) and q.get("info") is Dictionary and String(q.info.get("element", "")) == "raiton" and q.global_position.distance_to(p.global_position) < 2.8:
							L.snow(pj, p.global_position, {"n": 36, "r": 0.8, "vmin": 2.0, "vmax": 6.0})
							L.mist(pj, p.global_position, 2.0, 0.8, {"alpha": 0.6})
							Combat.popup_text(p.global_position + Vector3.UP, "Şimşek kurdu dağıttı", RAI_C)
							p.queue_free()
							return)
		# çığ: kurtların ardından yuvarlanan kar dalgası (iter, yavaşlatır)
		var hits = []
		pj.every(1.1, 0.07, func(i, k):
			var front = pj.gp(c.global_position + d * (2.0 + k * 22.0))
			for q in 2:
				L.mist(pj, front + side * randf_range(-4.5, 4.5) + Vector3.UP * randf_range(0.6, 1.6), randf_range(3.0, 4.2), 0.9,
					{"alpha": 0.8, "drift": d * 4.0 + Vector3.UP * 0.6, "s0": 0.5, "grow": 0.5, "fin": 0.1, "near": 5.0})
			if i % 2 == 0:
				L.snow(pj, front + Vector3.UP * 0.6, {"n": 18, "box": Vector3(4.0, 0.5, 0.5), "dir": d + Vector3.UP * 0.5, "spread": 35.0, "vmin": 3.0, "vmax": 7.0, "smin": 0.14, "smax": 0.34})
			if i % 3 == 0:
				L.frost(pj, front, 3.4, 2.4, {"mode": 1.0, "t": 0.15})
			for sx in [-1.0, 0.0, 1.0]:
				hits.append_array(pj.hit(c, front + side * sx * 3.2 + Vector3.UP, 2.2, pj.inf(c, "hyoton_roga_nadare", 0.8, {"knock": 9.0, "kind": "heavy", "element": "hyoton", "slow": 3.0}), hits)), Callable())
		pj.shake(0.5)
		Sfx.play("wind", c.global_position, 0.6))
	Sfx.play("clink", c.global_position, 0.6)


## Dört ayaklı koşu: çapraz bacak çiftleri karşıt fazda salınır, kuyruk sallanır
static func _run(model: Node3D, ph: float, amp: float) -> void:
	if not is_instance_valid(model):
		return
	var legs: Array = model.get_meta("legs", [])
	for lg in legs:
		var n: Node3D = lg[0]
		if is_instance_valid(n):
			n.rotation.x = sin(ph + float(lg[1])) * amp
	var tl = model.get_meta("tail", null)
	if tl != null and is_instance_valid(tl):
		tl.rotation.y = sin(ph * 0.5) * 0.35


static func _add_legs(root: Node3D, leg: ArrayMesh, spots: Array, o: Dictionary) -> void:
	var legs: Array = []
	for s in spots:
		var pv = Node3D.new()
		root.add_child(pv)
		pv.position = s[0]
		pv.add_child(L.imi(leg, o))
		legs.append([pv, s[1]])
	root.set_meta("legs", legs)


## Kar-buz kurdu (tabanı y=0, boy ~1.6): yüzlü gövde, sivri kulaklar, ense yelesi, kabarık kuyruk, dört bacak
static func _wolf() -> Node3D:
	var root = Node3D.new()
	var o = {"pal": L.SNOW, "outline": true, "ow": 0.035, "alpha": 0.97, "near": 2.0}
	var body = _cached("wolf_body", func():
		var st = L.begin()
		L.loft(st, [
			{"p": Vector3(0, 1.0, 0.8), "rx": 0.2, "ry": 0.24},
			{"p": Vector3(0, 1.02, 0.45), "rx": 0.32, "ry": 0.36},
			{"p": Vector3(0, 1.05, -0.3), "rx": 0.34, "ry": 0.42},
			{"p": Vector3(0, 1.22, -0.68), "rx": 0.27, "ry": 0.3}], 7, 0.05, 61)
		L.loft(st, [
			{"p": Vector3(0, 1.32, -0.72), "rx": 0.25, "ry": 0.24},
			{"p": Vector3(0, 1.38, -0.98), "rx": 0.27, "ry": 0.22},
			{"p": Vector3(0, 1.3, -1.28), "rx": 0.14, "ry": 0.12},
			{"p": Vector3(0, 1.26, -1.48), "rx": 0.0}], 6, 0.03, 62)
		L.loft(st, [{"p": Vector3(0, 1.16, -0.92), "rx": 0.14, "ry": 0.06}, {"p": Vector3(0, 1.1, -1.36), "rx": 0.0}], 4, 0.0, 63)
		for sx in [-1.0, 1.0]:
			L.loft(st, [{"p": Vector3(0.14 * sx, 1.5, -0.86), "rx": 0.09, "ry": 0.04, "up": Vector3(0, 0, 1)}, {"p": Vector3(0.18 * sx, 1.82, -0.8), "rx": 0.0}], 4, 0.0, 64)
		for i in 4:
			var z = -0.55 + i * 0.22
			L.loft(st, [{"p": Vector3(0, 1.32 + 0.05 * (3 - i), z), "rx": 0.1, "ry": 0.2, "up": Vector3(1, 0, 0)}, {"p": Vector3(0, 1.62 - i * 0.05, z + 0.38), "rx": 0.0}], 4, 0.0, 65 + i)
		return L.finish(st))
	root.add_child(L.imi(body, o))
	var leg = _cached("wolf_leg", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, 0, 0), "rx": 0.11}, {"p": Vector3(0, -0.5, 0.03), "rx": 0.085}, {"p": Vector3(0, -0.86, -0.02), "rx": 0.07}, {"p": Vector3(0, -0.95, -0.14), "rx": 0.0}], 5, 0.0, 66)
		return L.finish(st))
	_add_legs(root, leg, [[Vector3(0.17, 0.95, -0.38), 0.0], [Vector3(-0.17, 0.95, -0.38), PI], [Vector3(0.17, 0.95, 0.55), PI], [Vector3(-0.17, 0.95, 0.55), 0.0]], o)
	var tail = _cached("wolf_tail", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, 0, 0), "rx": 0.1}, {"p": Vector3(0, -0.12, 0.45), "rx": 0.17}, {"p": Vector3(0, -0.3, 0.95), "rx": 0.0}], 5, 0.08, 67)
		return L.finish(st))
	var tp = Node3D.new()
	root.add_child(tp)
	tp.position = Vector3(0, 1.05, 0.8)
	tp.add_child(L.imi(tail, o))
	root.set_meta("tail", tp)
	var em = L.glow_mat(Color(0.2, 0.45, 0.85))
	for sx in [-1.0, 1.0]:
		var e = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.06
		e.mesh = sm
		e.material_override = em
		root.add_child(e)
		e.position = Vector3(0.13 * sx, 1.42, -1.05)
	return root


# ================================================================== Hyōton: Ikkaku Hakugei (Tek Boynuzlu Beyaz Balina)
## Kaynak (film): yüzlü soluk mavi dev balina (12 m), beyaz burgulu tek boynuz, uzun yüzgeçler, çatal kuyruk; karnı derin
## camgöbeği. Düşeceği yer önceden kırağıyla donar. Çıkış noktasında yer buz sivrileriyle yarılır, kar sütunları savrulur;
## balina kar izi bırakarak yay çizer, gövdesinden buz yongaları dökülür. Çöktüğü yerde yer kırık çizgileriyle yarılır,
## kar patlar, katı buz kütleleri dikilir (yolu keser, 6 sn sonra kırılır); balina iri bloklara ayrılır.
static func hyoton_ikkaku_hakugei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var tt = pj.tg(c, t, 30.0)
	L.frost(pj, c.global_position, 4.0, 2.0, {"t": 0.3})
	L.glints(pj, c.global_position + Vector3.UP * 0.8, {"n": 16, "r": 1.6, "dir": Vector3.UP, "spread": 20.0, "vmin": 1.0, "vmax": 2.5})
	var d = pj.fwd(c, tt)
	var land = pj.gp(tt.global_position) if pj.live(tt) else pj.gp(c.global_position + d * 15.0)
	var back = clampf(Vector3(land.x - c.global_position.x, 0, land.z - c.global_position.z).length() - 4.0, 5.0, 13.0)
	var start = pj.gp(land - d * back)
	L.frost(pj, land, 7.0, 5.7, {"t": 0.45, "out": 0.8})   # düşeceği yer önceden donar: kaçmak için zaman
	pj.after(0.5, func():
		if not pj.live(c):
			return
		# çıkış: yer yarılır, buz sivrileri ve kar sütunları
		for q in 7:
			var a = q * TAU / 7.0 + randf() * 0.4
			var hgt = randf_range(1.4, 2.6)
			var sp = L.imi(L.shard_mesh(hgt, randf_range(0.3, 0.5), q % 6, 5), {"alpha": 0.86, "frost": 0.2})
			L.put(pj, sp, pj.gp(start + Vector3(cos(a), 0, sin(a)) * randf_range(2.6, 3.6)))
			sp.rotation = Vector3(cos(a) * 0.5, randf() * TAU, -sin(a) * 0.5)
			L.reveal(sp, hgt, 0.12)
			L.fade_free(sp, 1.6, 0.4)
		L.debris(pj, start + Vector3.UP, {"n": 12, "s": 0.5, "r": 1.8, "v": 6.0, "up": 6.0, "life": 1.3})
		for q in 5:
			var a = randf() * TAU
			L.mist(pj, start + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.5) + Vector3.UP * 2.0, randf_range(3.0, 4.5), 1.4, {"alpha": 0.85, "drift": Vector3.UP * 3.0, "s0": 0.4, "grow": 0.8, "near": 5.0})
		L.snow(pj, start + Vector3.UP, {"n": 60, "r": 2.5, "dir": Vector3.UP, "spread": 40.0, "vmin": 4.0, "vmax": 11.0, "smin": 0.16, "smax": 0.36, "g": Vector3(0, -8.0, 0), "life": 1.3})
		pj.shake(0.6)
		Sfx.play("boom", start, 0.6)
		var wh = _whale()
		pj.scene_add(wh, start - Vector3.UP * 4.0)
		var wtr = L.trail(wh, {"n": 50, "life": 0.9, "r": 1.6, "smin": 0.16, "smax": 0.34, "vmin": 0.5, "vmax": 2.0, "spread": 70.0, "g": Vector3(0, -4.0, 0)})
		wtr.position = Vector3(0, 0, 4.0)
		var hit_done = {"v": false}
		var dur = 1.35
		var arc = func(k: float) -> Vector3:
			return start.lerp(land, k) + Vector3.UP * (sin(k * PI) * 11.0 - 4.0)
		var w_tick = func(_i, k):
			if not is_instance_valid(wh):
				return
			var p: Vector3 = arc.call(k)
			var nx: Vector3 = arc.call(minf(1.0, k + 0.02))
			wh.global_position = p
			if nx.distance_to(p) > 0.01:
				wh.look_at(nx, Vector3.UP)
			if randf() < 0.12:
				L.chips(pj, p + Vector3(randf_range(-3, 3), randf_range(-1.5, 1.5), randf_range(-3, 3)), {"n": 5, "r": 0.5, "vmin": 1.0, "vmax": 3.0, "smin": 0.8, "smax": 1.4})
			if k > 0.86 and not hit_done["v"]:
				hit_done["v"] = true
				pj.hit(c, land + Vector3.UP, 6.5, pj.inf(c, "hyoton_ikkaku_hakugei", 4.6, {"knock": 16.0, "launch": 7.0, "kind": "heavy", "element": "hyoton", "slow": 3.0, "hitstop": 0.16}))
				L.frost(pj, land, 9.0, 4.5, {"mode": 2.0, "t": 0.18, "out": 1.0})
				L.snow(pj, land + Vector3.UP, {"n": 80, "r": 3.5, "dir": Vector3.UP, "spread": 75.0, "vmin": 4.0, "vmax": 12.0, "smin": 0.18, "smax": 0.4, "g": Vector3(0, -7.0, 0), "life": 1.4})
				for q in 8:
					var a = q * TAU / 8.0
					var dv = Vector3(cos(a), 0, sin(a))
					L.mist(pj, land + dv * 3.5 + Vector3.UP * 0.8, randf_range(3.4, 4.6), 1.6, {"alpha": 0.75, "drift": dv * 4.0 + Vector3.UP * 0.5, "near": 5.0})
				pj.shake(1.3)
				Sfx.play("boom", land, 0.5)
				# kalan buz kütleleri: yolu keser (katı), 6 sn sonra kırılır
				for q in 5:
					var a = q * TAU / 5.0 + randf() * 0.5
					var bp = pj.gp(land + Vector3(cos(a), 0, sin(a)) * randf_range(2.6, 4.6))
					var blk = StaticBody3D.new()
					pj.scene_add(blk, bp)
					var hgt = randf_range(2.6, 4.2)
					var sp = L.imi(L.shard_mesh(hgt, 0.95, q, 6), {"alpha": 0.85, "frost": 0.4, "outline": true, "ow": 0.025})
					sp.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
					blk.add_child(sp)
					var cs = CollisionShape3D.new()
					var sh = CylinderShape3D.new()
					sh.radius = 0.85
					sh.height = hgt * 0.8
					cs.shape = sh
					cs.position = Vector3.UP * hgt * 0.4
					blk.add_child(cs)
					L.reveal(sp, hgt + 0.1, 0.18)
					pj.after(6.0, func():
						if is_instance_valid(blk):
							L.debris(pj, bp + Vector3.UP, {"n": 6, "s": 0.45, "r": 0.8, "v": 3.0, "up": 3.0})
							L.chips(pj, bp + Vector3.UP * 1.5, {"n": 10, "r": 0.8})
							blk.queue_free())
		var w_done = func():
				if is_instance_valid(wh):
					L.debris(pj, land + Vector3.UP * 1.5, {"n": 16, "s": 0.8, "r": 3.0, "v": 6.0, "up": 5.0, "life": 1.4})
					L.chips(pj, land + Vector3.UP * 2.0, {"n": 30, "r": 3.0, "vmin": 3.0, "vmax": 9.0, "smin": 1.0, "smax": 1.8})
					wh.queue_free()
		pj.every(dur, 1.0 / 60.0, w_tick, w_done))
	Sfx.play("clink", c.global_position, 0.6)


## Buz balinası (gerçek boy ~12 m, ileri -Z): yüzlü gövde + karın, uzun göğüs yüzgeçleri, çatal kuyruk, beyaz burgulu boynuz
static func _whale() -> Node3D:
	var root = Node3D.new()
	var body = _cached("whale_body", func():
		var st = L.begin()
		L.loft(st, [
			{"p": Vector3(0, 0.1, -6.0), "rx": 0.55, "ry": 0.5},
			{"p": Vector3(0, 0.15, -5.4), "rx": 1.25, "ry": 1.05},
			{"p": Vector3(0, 0.1, -4.2), "rx": 1.75, "ry": 1.5},
			{"p": Vector3(0, 0.15, -2.5), "rx": 1.95, "ry": 1.72},
			{"p": Vector3(0, 0.2, -0.5), "rx": 1.8, "ry": 1.55},
			{"p": Vector3(0, 0.3, 1.5), "rx": 1.35, "ry": 1.15},
			{"p": Vector3(0, 0.4, 3.3), "rx": 0.8, "ry": 0.7},
			{"p": Vector3(0, 0.45, 4.8), "rx": 0.38, "ry": 0.36},
			{"p": Vector3(0, 0.45, 5.6), "rx": 0.2, "ry": 0.2}], 10, 0.04, 71)
		for sx in [-1.0, 1.0]:
			# uzun göğüs yüzgeçleri (kambur balina)
			L.loft(st, [{"p": Vector3(1.55 * sx, -0.55, -3.0), "rx": 0.6, "ry": 0.14}, {"p": Vector3(3.2 * sx, -1.1, -2.0), "rx": 0.45, "ry": 0.1}, {"p": Vector3(4.7 * sx, -1.5, -0.6), "rx": 0.0}], 5, 0.0, 72)
			# kuyruk yüzgeci
			L.loft(st, [{"p": Vector3(0.1 * sx, 0.45, 5.5), "rx": 0.55, "ry": 0.1}, {"p": Vector3(1.3 * sx, 0.5, 6.1), "rx": 0.5, "ry": 0.08}, {"p": Vector3(2.4 * sx, 0.55, 6.9), "rx": 0.0}], 5, 0.0, 73)
		# sırt tümseği
		L.loft(st, [{"p": Vector3(0, 1.4, 1.2), "rx": 0.12, "ry": 0.4, "up": Vector3(1, 0, 0)}, {"p": Vector3(0, 1.85, 1.9), "rx": 0.0}], 4, 0.0, 74)
		return L.finish(st))
	root.add_child(L.imi(body, {"pal": L.ICE, "outline": true, "ow": 0.05, "alpha": 0.9, "near": 4.0}))
	var belly = _cached("whale_belly", func():
		var st = L.begin()
		L.loft(st, [
			{"p": Vector3(0, -0.45, -5.6), "rx": 0.7, "ry": 0.4},
			{"p": Vector3(0, -0.85, -3.6), "rx": 1.4, "ry": 0.9},
			{"p": Vector3(0, -0.8, -1.0), "rx": 1.45, "ry": 0.85},
			{"p": Vector3(0, -0.45, 1.8), "rx": 0.9, "ry": 0.6},
			{"p": Vector3(0, -0.1, 3.4), "rx": 0.0}], 8, 0.03, 75)
		return L.finish(st))
	root.add_child(L.imi(belly, {"pal": L.DEEP, "alpha": 0.9, "near": 4.0}))
	var horn = _cached("whale_horn", func():
		var st = L.begin()
		var rings: Array = []
		for i in 9:
			var k = float(i) / 8.0
			rings.append({"p": Vector3(0, 0.25 + k * 1.4, -5.9 - k * 4.4), "rx": 0.3 * (1.0 - k) + 0.01, "rot": k * TAU * 2.0})
		rings[8]["rx"] = 0.0
		L.loft(st, rings, 5, 0.0, 76)
		return L.finish(st))
	root.add_child(L.imi(horn, {"pal": L.SNOW, "outline": true, "ow": 0.04, "alpha": 1.0, "near": 3.0}))
	var em = L.glow_mat(Color(0.12, 0.3, 0.55))
	for sx in [-1.0, 1.0]:
		var e = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.24
		e.mesh = sm
		e.material_override = em
		root.add_child(e)
		e.position = Vector3(1.32 * sx, -0.15, -4.6)
	return root


# ================================================================== Hyōton: Haryū Mōko (Ejder Yırtan Azgın Kaplan)
## Kaynak (film): yüzlü buz kaplan (6 m), kontur çizgili, sırtında buz dikenleri, açık ağız ve köpek dişleri. Dört bacakla
## koşar (çapraz bacak fazı), kuyruğu savrulur; geçtiği yer kırağı izi olarak kalır. Yolundaki Suiton tekniği donup kırılır.
## Vurduğu kişi yüzlü buz kılıfına hapsolur, süre sonunda kılıf parçalanır.
static func hyoton_haryu_moko(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 30.0)
	L.frost(pj, c.global_position, 3.6, 2.0, {"t": 0.3, "pal": 0.0})
	L.mist(pj, c.global_position + Vector3.UP * 1.0 + c.face_dir() * 1.2, 2.6, 1.0, {"alpha": 0.55, "drift": c.face_dir() * 2.0})
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var d = pj.fwd(c, tt)
		var h = Node3D.new()
		var tiger = _tiger()
		tiger.position.y = -1.3
		h.add_child(tiger)
		var pr = pj.shot(c, pj.gp(c.global_position + d * 2.2) + Vector3.UP * 1.3, d, 26.0, h, pj.inf(c, "hyoton_haryu_moko", 3.2, {"knock": 10.0, "kind": "heavy", "element": "hyoton", "slow": 3.0, "hitstop": 0.1}), tt, true, 1.7,
			func(p, e):
				L.debris(pj, p, {"n": 7, "s": 0.35, "r": 0.6, "v": 4.0, "up": 3.0})
				if pj.live(e):
					pj.st(e, "bind", 1.6)
					var ice = L.imi(L.encase_mesh(1.2, 2.6), {"alpha": 0.62, "frost": 0.35, "outline": true, "ow": 0.03, "near": 2.0})
					pj.scene_add(ice, pj.gp(e.global_position))
					ice.rotation.y = randf() * TAU
					L.reveal(ice, 2.7, 0.18)
					L.free_later(pj, ice, 2.2)
					pj.after(1.6, func():
						if is_instance_valid(ice):
							L.debris(pj, ice.global_position + Vector3.UP, {"n": 10, "s": 0.4, "r": 0.8, "v": 4.0, "up": 3.5})
							L.chips(pj, ice.global_position + Vector3.UP * 1.2, {"n": 14, "r": 0.7})
							ice.queue_free())
					Combat.popup_text(e.global_position + Vector3.UP * 2.6, "Dondu!", ICE_C))
		pr.radius = 2.0
		pr.homing_turn = 1.2
		var ttr = L.trail(h, {"n": 30, "life": 0.6, "r": 0.8, "dir": Vector3(0, 1, 1), "spread": 45.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -5.0, 0), "smin": 0.14, "smax": 0.3})
		ttr.position = Vector3(0, -1.1, 1.0)
		var s0 = {"d": 0.0, "ph": 0.0}
		pr.on_tick = func(p, dt):
			p.global_position.y = Game.jutsu_floor(p.global_position.x, p.global_position.z) + 1.3
			s0["d"] += p.vel.length() * dt
			s0["ph"] += dt * 10.0
			_run(tiger, s0["ph"], 0.55)
			if s0["d"] > 2.4:   # geçtiği yer donar
				s0["d"] = 0.0
				L.frost(pj, p.global_position - Vector3.UP * 1.26, 2.2, 2.4, {"t": 0.12, "out": 0.5})
			for q in pj.get_tree().get_nodes_in_group("projectiles"):
				if q != p and is_instance_valid(q) and q.get("shooter") != c and q.get("info") is Dictionary and String(q.info.get("element", "")) == "suiton" and q.global_position.distance_to(p.global_position) < 3.6:
					L.debris(pj, q.global_position, {"n": 8, "s": 0.3, "r": 0.5, "v": 3.0, "up": 2.0})
					L.glints(pj, q.global_position, {"n": 8, "r": 0.5})
					Combat.popup_text(q.global_position + Vector3.UP, "Su dondu", ICE_C)
					q.queue_free()
		pj.shake(0.4)
		Sfx.play("wind", c.global_position, 0.8))
	Sfx.play("clink", c.global_position, 0.6)


## Buz kaplan (tabanı y=0, boy ~3.2, uzunluk ~6 m; ileri -Z)
static func _tiger() -> Node3D:
	var root = Node3D.new()
	var o = {"pal": L.ICE, "outline": true, "ow": 0.045, "alpha": 0.92, "frost": 0.15, "near": 3.0}
	var body = _cached("tiger_body", func():
		var st = L.begin()
		L.loft(st, [
			{"p": Vector3(0, 1.75, 2.5), "rx": 0.45, "ry": 0.5},
			{"p": Vector3(0, 1.8, 2.1), "rx": 0.78, "ry": 0.8},
			{"p": Vector3(0, 1.72, 1.0), "rx": 0.9, "ry": 0.82},
			{"p": Vector3(0, 1.8, -0.2), "rx": 0.88, "ry": 0.9},
			{"p": Vector3(0, 1.95, -1.2), "rx": 1.0, "ry": 1.05},
			{"p": Vector3(0, 2.2, -1.9), "rx": 0.72, "ry": 0.78},
			{"p": Vector3(0, 2.35, -2.25), "rx": 0.6, "ry": 0.62}], 8, 0.05, 81)
		L.loft(st, [
			{"p": Vector3(0, 2.4, -2.05), "rx": 0.55, "ry": 0.55},
			{"p": Vector3(0, 2.45, -2.6), "rx": 0.7, "ry": 0.6},
			{"p": Vector3(0, 2.35, -3.05), "rx": 0.5, "ry": 0.45},
			{"p": Vector3(0, 2.22, -3.4), "rx": 0.32, "ry": 0.28},
			{"p": Vector3(0, 2.18, -3.5), "rx": 0.0}], 8, 0.04, 82)
		L.loft(st, [{"p": Vector3(0, 1.98, -2.4), "rx": 0.4, "ry": 0.18}, {"p": Vector3(0, 1.88, -3.1), "rx": 0.3, "ry": 0.12}, {"p": Vector3(0, 1.86, -3.3), "rx": 0.0}], 6, 0.0, 83)
		for sx in [-1.0, 1.0]:
			L.loft(st, [{"p": Vector3(0.38 * sx, 2.85, -2.3), "rx": 0.2, "ry": 0.08, "up": Vector3(0, 0, 1)}, {"p": Vector3(0.48 * sx, 3.25, -2.2), "rx": 0.0}], 4, 0.0, 84)
			L.loft(st, [{"p": Vector3(0.55 * sx, 2.25, -2.5), "rx": 0.16}, {"p": Vector3(0.98 * sx, 2.1, -1.95), "rx": 0.0}], 4, 0.0, 85)
			L.loft(st, [{"p": Vector3(0.18 * sx, 2.12, -3.2), "rx": 0.06}, {"p": Vector3(0.18 * sx, 1.84, -3.18), "rx": 0.0}], 4, 0.0, 86)
		for i in 5:
			var z = 1.8 - i * 0.8
			L.loft(st, [{"p": Vector3(0, 2.45 + (0.15 if i == 4 else 0.0), z), "rx": 0.14, "ry": 0.3, "up": Vector3(1, 0, 0)}, {"p": Vector3(0, 2.95 + i * 0.05, z + 0.35), "rx": 0.0}], 4, 0.0, 87 + i)
		return L.finish(st))
	root.add_child(L.imi(body, o))
	var leg = _cached("tiger_leg", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, 0, 0), "rx": 0.34}, {"p": Vector3(0, -0.75, 0.05), "rx": 0.26}, {"p": Vector3(0, -1.45, -0.02), "rx": 0.2},
			{"p": Vector3(0, -1.65, -0.12), "rx": 0.27, "ry": 0.18}, {"p": Vector3(0, -1.75, -0.32), "rx": 0.0}], 6, 0.03, 92)
		return L.finish(st))
	_add_legs(root, leg, [[Vector3(0.55, 1.75, -1.3), 0.0], [Vector3(-0.55, 1.75, -1.3), PI], [Vector3(0.55, 1.75, 1.7), PI], [Vector3(-0.55, 1.75, 1.7), 0.0]], o)
	var tail = _cached("tiger_tail", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, 0, 0), "rx": 0.2}, {"p": Vector3(0, 0.3, 1.0), "rx": 0.17}, {"p": Vector3(0, 0.8, 1.8), "rx": 0.12}, {"p": Vector3(0, 1.2, 2.3), "rx": 0.0}], 5, 0.0, 93)
		return L.finish(st))
	var tp = Node3D.new()
	root.add_child(tp)
	tp.position = Vector3(0, 1.9, 2.5)
	tp.add_child(L.imi(tail, o))
	root.set_meta("tail", tp)
	var em = L.glow_mat(Color(0.85, 0.97, 1.0))
	for sx in [-1.0, 1.0]:
		var e = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.1
		e.mesh = sm
		e.material_override = em
		root.add_child(e)
		e.position = Vector3(0.32 * sx, 2.6, -2.78)
	return root


# ================================================================== Hyōton: Jisarenhyō (Yer Zinciri Buzu)
## Elden hedefe doğru sekiz adımda kırağı pırıltısı zinciri; hedefin ayağı donar, başının üstünde buz zerreleri belirip
## yavaşça üstüne yağar (süre boyunca), uzuvlarında küçük buz kristalleri dipten uca büyür. Hedef chakra yoğurursa
## bedeni yüzlü buz kılıfına kapanır, ardından kılıf parçalanır.
static func hyoton_jisarenhyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 18.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Buz zincirini bağlayacak hedef yok", Color(1, 0.7, 0.5))
		return
	var from = pj.hand_pos(c, true)
	for k in 8:
		pj.after(k * 0.03, func():
			if pj.live(tt):
				var q = from.lerp(tt.global_position + Vector3.UP * 1.0, (k + 1) / 8.0)
				L.glints(pj, q, {"n": 5, "r": 0.25, "life": 0.4, "vmin": 0.2, "vmax": 0.8}))
	pj.after(0.3, func():
		if not pj.live(tt):
			return
		var dur = 10.0
		var until = Game.now() + dur
		pj.st(tt, "slow", dur)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Buz zinciri", ICE_C)
		L.frost(pj, pj.gp(tt.global_position), 2.0, 1.0, {"t": 0.2, "out": 0.3})
		# başın üstünde oluşup yağan buz zerreleri (süre boyunca)
		var hh = float(tt.get("height")) if tt.get("height") != null else 1.8
		var motes = L.particles({"n": 10, "life": 1.4, "r": 0.45, "dir": Vector3.DOWN, "spread": 20.0, "vmin": 0.2, "vmax": 0.6, "g": Vector3(0, -0.6, 0),
			"smin": 0.12, "smax": 0.24, "kind": 1.0, "one_shot": false, "burst": 0.0, "cols": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1), Color(0.8, 0.94, 1.0, 0.0)]})
		tt.add_child(motes)
		motes.position = Vector3.UP * (hh + 0.35)
		motes.emitting = true
		L.free_later(pj, motes, dur + 0.5)
		# bedeni saran kırağı: uzuvlarda büyüyen küçük kristaller
		var bits = []
		for bn in ["LeftLowerLeg", "RightLowerLeg", "LeftUpperLeg", "RightUpperLeg", "Hips", "Spine", "LeftLowerArm", "RightLowerArm", "UpperChest"]:
			var ba = pj.bone_attach(tt, bn)
			if ba == null:
				continue
			for q in 2:
				var ln = randf_range(0.22, 0.4)
				var sp = L.imi(L.shard_mesh(ln, 0.07, (bits.size() + q) % 6, 4), {"alpha": 0.88, "near": 0.8})
				sp.rotation = Vector3(randf_range(0.6, 2.4), randf() * TAU, randf_range(-1.0, 1.0))
				sp.position = Vector3(randf_range(-0.05, 0.05), randf_range(0.0, 0.18), randf_range(-0.05, 0.05))
				ba.add_child(sp)
				L.reveal(sp, ln, 0.5 + bits.size() * 0.12)
			bits.append(ba)
		var s0 = {"cd": 0.0}
		var surge = func(who: Node, jid: String):
			if who != tt or not pj.live(tt) or Game.now() > until or Game.now() < s0["cd"]:
				return
			if String(Data.jutsu.get(jid, {}).get("category", "")) == "taijutsu":
				return   # chakra yoğurmayan hareket buzu azdırmaz
			s0["cd"] = Game.now() + 2.5
			pj.st(tt, "bind", 1.8)
			var ice = L.imi(L.encase_mesh(1.2, 2.6), {"alpha": 0.62, "frost": 0.35, "outline": true, "ow": 0.03, "near": 2.0})
			pj.scene_add(ice, pj.gp(tt.global_position))
			ice.rotation.y = randf() * TAU
			L.reveal(ice, 2.7, 0.2)
			L.glints(pj, tt.global_position + Vector3.UP * 1.2, {"n": 12, "r": 0.9})
			L.free_later(pj, ice, 2.4)
			pj.after(1.8, func():
				if is_instance_valid(ice):
					L.debris(pj, ice.global_position + Vector3.UP, {"n": 10, "s": 0.4, "r": 0.8, "v": 4.0, "up": 3.5})
					L.chips(pj, ice.global_position + Vector3.UP * 1.2, {"n": 12, "r": 0.7})
					ice.queue_free())
			if pj.live(c):
				tt.take_hit(pj.inf(c, "hyoton_jisarenhyo", 1.6, {"knock": 0.0, "kind": "light", "element": "hyoton", "pierce_guard": true}))
			Combat.popup_text(tt.global_position + Vector3.UP * 2.8, "Chakra yoğurdu: dondu!", ICE_C)
			Sfx.play("clink", tt.global_position, 0.7)
		Jutsu.jutsu_cast.connect(surge)
		var wt = weakref(tt)
		var wc = weakref(c)
		var j_tick = func(_i, _k):
			var e = wt.get_ref()
			var cc = wc.get_ref()
			if e != null and cc != null and pj.live(e) and pj.live(cc):
				e.take_hit(pj.inf(cc, "hyoton_jisarenhyo", 0.1, {"knock": 0.0, "kind": "light", "element": "hyoton", "pierce_guard": true}))
		var j_done = func():
				if Jutsu.jutsu_cast.is_connected(surge):
					Jutsu.jutsu_cast.disconnect(surge)
				for ba in bits:
					if is_instance_valid(ba):
						ba.queue_free()
				if is_instance_valid(motes):
					motes.queue_free()
		pj.every(dur, 1.0, j_tick, j_done))
	Sfx.play("clink", c.global_position, 0.8)


# ================================================================== Hyōton: Tsubame Fubuki (Buz Kırlangıç Fırtınası)
## Atanın çevresinde kar tipisi kabarır, ellerinden kırağı parıltısı saçılır; on altı yüzlü buz kırlangıç (çatal kuyruk,
## geriye kıvrık kanatlar) halka olup çevresinde döner, kanat çırpar; sonra tek tek hedefe dalar, ardında ince kar izi.
## Çarptığı yerde küçük buz yongaları.
static func hyoton_tsubame_fubuki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 28.0)
	var d = pj.fwd(c, tt)
	for k in 6:
		var a = k * TAU / 6.0
		L.mist(pj, c.global_position + Vector3(cos(a), 0, sin(a)) * 1.6 + Vector3.UP * 1.3, 2.0, 1.2, {"alpha": 0.45, "drift": Vector3(-sin(a), 0.2, cos(a)) * 2.5})
	L.glints(pj, c.global_position + Vector3.UP * 1.5, {"n": 30, "r": 1.5, "vmin": 1.0, "vmax": 3.0, "life": 1.0})
	L.snow(pj, c.global_position + Vector3.UP * 1.2, {"n": 30, "r": 2.0, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "g": Vector3(0, -0.8, 0), "life": 1.2})
	var n = 16
	for k in n:
		var bird = Node3D.new()
		var sw = _swallow()
		bird.add_child(sw)
		pj.get_tree().current_scene.add_child(bird)
		var a0 = k * TAU / n
		var r = 2.2 + (k % 3) * 0.5
		var h = 1.4 + (k % 4) * 0.45
		var st0 = {"a": a0}
		# sürü: atanın çevresinde dönen halka (kırlangıçlar dönüş yönüne bakar, kanatlar çırpar, gövde hafif yatar)
		var tw = bird.create_tween()
		tw.tween_method(func(u: float):
			if not is_instance_valid(bird) or not pj.live(c):
				return
			st0["a"] = a0 + u * 5.0
			var o = Vector3(cos(st0["a"]), 0, sin(st0["a"]))
			bird.global_position = c.global_position + o * r * minf(1.0, u * 4.0 + 0.2) + Vector3.UP * h
			bird.look_at(bird.global_position + Vector3(-sin(st0["a"]), 0, cos(st0["a"])), Vector3.UP)
			sw.rotation.z = sin(u * 40.0 + k) * 0.35
			_flap(sw, u * 60.0 + k), 0.0, 1.0, 0.35 + k * 0.035)
		tw.tween_callback(func():
			if not is_instance_valid(bird):
				return
			var from = bird.global_position
			bird.queue_free()
			if not pj.live(c):
				return
			var holder = Node3D.new()
			var sw2 = _swallow()
			holder.add_child(sw2)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from) if tt else (d + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))).normalized(), 34.0, holder,
				pj.inf(c, "hyoton_tsubame_fubuki", 0.22, {"knock": 2.0, "kind": "light", "element": "hyoton", "slow": 1.5, "bleed": 0.5}), tt, false, 1.4, func(p, _h):
					L.chips(pj, p - Vector3.UP * 0.2, {"n": 7, "r": 0.25, "vmin": 2.0, "vmax": 5.0, "smin": 0.5, "smax": 0.9})
					L.glints(pj, p, {"n": 4, "r": 0.2, "life": 0.35}))
			pr.homing_turn = 4.0
			var ph = {"v": 0.0}
			pr.on_tick = func(_p, dt):
				ph["v"] += dt * 26.0
				_flap(sw2, ph["v"])
			L.trail(pr, {"n": 20, "life": 0.4, "r": 0.08, "smin": 0.06, "smax": 0.12, "vmin": 0.1, "vmax": 0.4, "spread": 15.0, "g": Vector3.ZERO,
				"cols": [Color(1, 1, 1, 0.9), Color(0.8, 0.94, 1.0, 0.6), Color(0.75, 0.9, 1.0, 0.0)]}))
	Sfx.play("wind", c.global_position, 1.6)


static func _flap(sw: Node3D, ph: float) -> void:
	if not is_instance_valid(sw):
		return
	var a = sin(ph) * 0.6
	var wl = sw.get_meta("wl", null)
	var wr = sw.get_meta("wr", null)
	if wl != null and is_instance_valid(wl):
		wl.rotation.z = -a
	if wr != null and is_instance_valid(wr):
		wr.rotation.z = a


## Buz kırlangıç (kanat açıklığı ~1.3 m, ileri -Z): gövde + gaga, çatal kuyruk, ayrı çırpan kanatlar
static func _swallow() -> Node3D:
	var root = Node3D.new()
	var o = {"pal": L.ICE, "outline": true, "ow": 0.025, "alpha": 0.9, "glow": 0.1, "near": 1.2}
	var body = _cached("swallow_body", func():
		var st = L.begin()
		L.loft(st, [{"p": Vector3(0, 0, 0.32), "rx": 0.0}, {"p": Vector3(0, 0, 0.16), "rx": 0.08, "ry": 0.07}, {"p": Vector3(0, 0.01, -0.12), "rx": 0.1, "ry": 0.1},
			{"p": Vector3(0, 0.02, -0.28), "rx": 0.05}, {"p": Vector3(0, 0.0, -0.4), "rx": 0.0}], 6, 0.0, 101)
		for sx in [-1.0, 1.0]:
			L.loft(st, [{"p": Vector3(0.03 * sx, 0, 0.22), "rx": 0.035, "ry": 0.012}, {"p": Vector3(0.18 * sx, 0, 0.66), "rx": 0.0}], 4, 0.0, 102)
		return L.finish(st))
	root.add_child(L.imi(body, o))
	for sx in [-1.0, 1.0]:
		var wing = _cached("swallow_wing_%d" % int(sx), func():
			var st = L.begin()
			L.loft(st, [{"p": Vector3(0, 0, 0), "rx": 0.12, "ry": 0.016}, {"p": Vector3(0.3 * sx, 0.02, 0.08), "rx": 0.1, "ry": 0.014}, {"p": Vector3(0.64 * sx, 0, 0.32), "rx": 0.0}], 4, 0.0, 103)
			return L.finish(st))
		var pv = Node3D.new()
		root.add_child(pv)
		pv.position = Vector3(0.07 * sx, 0.03, -0.05)
		pv.add_child(L.imi(wing, o))
		root.set_meta("wl" if sx < 0.0 else "wr", pv)
	return root
