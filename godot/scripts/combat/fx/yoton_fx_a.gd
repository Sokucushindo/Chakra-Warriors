class_name YotonFXA
extends RefCounted
## Yōton grubu A: on beş lav / lastik / kül / kireç tekniğinin görselleri — malzeme ve yapı taşları YotonLib'den (kendi lav,
## hamur, kristal, çatlak shader'ları); her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı.
## Lav asla alev değildir: yapışkan, ağır akan sarı-turuncu kütle, üstünde koyu soğuyan kabuk, parlayan çatlaklar, ağır damlalar.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/yoton_lib.gd")

const HOT := Color(1.0, 0.6, 0.2, 0.85)
const LAVA_LIGHT := Color(1.0, 0.5, 0.18)

static var _cache := {}


# ================================================================== eski çağrıların oyun tarafı
## Eski lav çarpmasının oyun tarafı (lav sıçraması yarığı + sarsıntı): s = eski çarpma ölçeği
static func _impact_marks(pj: PathJutsu, at: Vector3, s: float) -> void:
	L.crack_zone(at, 1.6 * s, 4.0)
	pj.shake(0.25 + 0.25 * s)


## Eski yakın dövüş isabetinin oyun tarafı (yalnız isabet varsa): sarsıntı + ağır darbede zemin yarığı
static func _melee_marks(pj: PathJutsu, hs: Array, info: Dictionary) -> void:
	if hs.is_empty():
		return
	var heavy = String(info.get("kind", "")) == "heavy"
	var s = clampf(0.8 + float(info.get("knock", 4.0)) * 0.04 + absf(float(info.get("launch", 0.0))) * 0.03, 0.8, 1.8)
	var s2 = s if heavy else s * 0.7
	if heavy and s > 1.3 and is_instance_valid(hs[0]):
		L.crack_zone(pj.gp(hs[0].global_position + Vector3.UP), 3.0 * s2, 6.0)
	pj.shake(0.2 + 0.3 * s2)


# ================================================================== ortak küçük parçalar (yalnız bu dosyanın)
## Merminin uçuş izi: her every_s saniyede fn(mermi) (damla / kül dökme)
static func _set_tick(pr: Projectile, every_s: float, fn: Callable) -> void:
	var acc = {"t": 0.0}
	pr.on_tick = func(pp, dt):
		acc["t"] += dt
		if acc["t"] > every_s and is_instance_valid(pp):
			acc["t"] = 0.0
			fn.call(pp)


## Lav kaplı yumruk: el kemiğine iliştirilen kabarık lav topağı + birkaç kabuk plakası; büyüyerek belirir
static func _lava_fist(r: float, crust := 0.35) -> Node3D:
	var root = Node3D.new()
	var core = L.lava_blob(r, 1.1, crust, 0.3, {"near": Vector2(0.3, 0.9), "nscale": 5.0, "wob": 0.03})
	core.position = Vector3(0, r * 0.5, 0)
	root.add_child(core)
	for k in 3:
		var pl = L.lava_blob(r * 0.4, 0.25, 0.95, 0.5, {"near": Vector2(0.3, 0.9), "nscale": 6.0, "wob": 0.0})
		var a = k * TAU / 3.0 + randf() * 0.5
		pl.position = Vector3(cos(a) * r * 0.8, r * (0.3 + 0.4 * randf()), sin(a) * r * 0.8)
		root.add_child(pl)
	root.scale = Vector3.ONE * 0.05
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


## Bir parçanın kemiğe bağlı damlaması: dur boyunca her dt'de bağlı düğümlerden ağır lav damlası düşer
static func _drip_from(pj: PathJutsu, nodes: Array, dur: float, dt := 0.12) -> void:
	pj.every(dur, dt, func(_i, _k):
		for pp in nodes:
			if is_instance_valid(pp) and pp.is_inside_tree() and randf() < 0.7:
				L.lava_drops(pj, pp.global_position, 1, 1.5, Vector3.DOWN, 0.5, 0.055, 1.0, 1.4))


## Yerden fışkıran yapışkan lav parmağı: kabarır, ucundan ağır damla saçar, kendi ağırlığıyla çöker, soğuyup kararır
static func _lava_finger(pj: PathJutsu, base: Vector3, dirv: Vector3, h: float, w: float, life: float) -> void:
	var root = Node3D.new()
	L.put(pj, root, base)
	var sd = L.side_of(dirv)
	var lean = dirv * h * randf_range(0.15, 0.4)
	var ph = randf() * TAU
	var pts = []
	var rr = []
	for i in 6:
		var u = float(i) / 5.0
		pts.append(Vector3.UP * h * u + lean * u * u + sd * sin(u * 3.0 + ph) * 0.08 * h)
		rr.append(w * lerpf(1.0, 0.4, u) * (1.0 + 0.22 * sin(u * 7.0 + ph)))
	var mi = L.lava_mi(L.tube_mesh(pts, rr, 8, 0.22, ph, 1.3), 1.1, 0.35, {"nscale": 2.2, "wob": 0.06, "flow": -1.2, "near": Vector2(2.0, 5.0)})
	root.add_child(mi)
	root.scale = Vector3(1, 0.05, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3(1, 1.08, 1), life * 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3(1.15, 0.55, 1.15), life * 0.5).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(root, "scale", Vector3(1.3, 0.05, 1.3), life * 0.28).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	mi.create_tween().tween_method(L.pf(mi, "heat"), 1.1, 0.3, life)
	var tip = base + Vector3.UP * h + lean
	var dt = root.create_tween()
	dt.tween_interval(life * 0.2)
	dt.tween_callback(func(): L.lava_drops(pj, tip, 3, 5.0, Vector3.UP + dirv * 0.6, 0.5, 0.09))


## Hedefte cızırdayan küçük lav lekesi (Lav Çakra Modu teması): yapışan topak + buhar
static func _sizzle(pj: PathJutsu, e: Node3D) -> void:
	if not is_instance_valid(e):
		return
	var p = e.global_position + Vector3.UP * randf_range(0.6, 1.4) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var b = L.lava_blob(0.12, 1.0, 0.3, 0.3, {"wob": 0.0, "near": Vector2(0.4, 1.2)})
	L.put(pj, b, p)
	var tw = b.create_tween()
	tw.tween_method(L.pf(b, "heat"), 1.0, 0.1, 0.8)
	tw.tween_method(L.pf(b, "fade"), 1.0, 0.0, 0.3)
	tw.tween_callback(b.queue_free)
	L.vapor(pj, p, 0.6, 0.9, Vector3(0, 1.4, 0))


# ================================================================== Kakazan
## Çiçek Meyve Dağı: iki yumruk lav topağıyla kaplanır, ileri atılır; her yumrukta önündeki yerden kabuk parçalı
## lav parmakları duvar gibi fışkırır (ref: alttan yükselen, koyu taş benekli parlak lav dalgası) — sonuncusu tam duvar + lav gölü
static func kakazan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.1)
	var parts = []
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			ba.add_child(_lava_fist(0.17))
			parts.append(ba)
	_drip_from(pj, parts, 1.0)
	pj._jump_at(c, tt, 1.5, 8.0)
	for k in 3:
		pj.after(0.25 + k * 0.18, func():
			if not pj.live(c):
				return
			var at = c.global_position + Vector3.UP * 1.1 + c.face_dir() * 1.3
			pj.anim(c, ["punch", "punch2", "cross"][k], 1.6)
			_kakazan_wave(pj, c, at, k)
			_impact_marks(pj, at, 1.0 + k * 0.4)
			var info = pj.inf(c, "kakazan", 0.9 + k * 0.4, {"knock": 6.0 + k * 8.0, "kind": "heavy", "element": "yoton", "burn": 3.0})
			_melee_marks(pj, pj.hit(c, at, 2.4, info), info))
	pj.after(1.0, func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free())
	Sfx.play("fire", c.global_position, 0.8)


static func _kakazan_wave(pj: PathJutsu, c: Node3D, at: Vector3, k: int) -> void:
	var f = c.face_dir()
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var sd = L.side_of(f)
	var g = L.floor_at(at + f * 0.6)
	var n = 3 + k * 2
	var width = 1.2 + k * 1.2
	for i in n:
		var u = float(i) / maxf(1.0, n - 1) - 0.5
		var b = L.floor_at(g + sd * u * width + f * (randf_range(-0.1, 0.4) - absf(u) * 0.6))
		_lava_finger(pj, b, f, randf_range(1.0, 1.6) * (1.0 + k * 0.45), randf_range(0.16, 0.24) * (1.0 + k * 0.25), 0.9 + k * 0.2)
	for i in 3 + k * 2:
		L.crust_rock(pj, g + Vector3.UP * 0.5, f * randf_range(2.0, 5.0) + Vector3.UP * randf_range(4.0, 7.0) + sd * randf_range(-2.5, 2.5), randf_range(0.1, 0.22))
	L.lava_drops(pj, at, 6 + k * 3, 6.0, f + Vector3.UP * 0.5, 0.6, 0.1)
	L.glow(pj, at, 2.2 + k * 0.8, HOT, 0.35)
	L.light(pj, at, LAVA_LIGHT, 2.5 + k, 7.0, 0.5)
	L.cracks(pj, g + f * 0.8, 1.4 + k * 0.7, 3.5, 1.0, 0.2)
	if k == 2:
		L.lava_pool(pj, g + f * 1.4, 1.6, 4.0, 1.0)
		for i in 3:
			L.vapor(pj, g + f * 1.4 + sd * (i - 1) * 0.8 + Vector3.UP * 0.4, 1.2, 1.6, Vector3(0, 1.3, 0))


# ================================================================== Lav Çakra Modu
## Lav Çakra Modu: gerçek beden (deri ağı kopyası) baştan ayağa erimiş lav kaplamasıyla örtülür — koyu kabuk benekleri, parlayan
## damarlar; üstünde yalnız kenarlarda yukarı akan ısı perdesi (ref: Rōshi). Ayak altından halka halinde lav dalgası yayılır;
## mod boyunca bedenden lav damlar, adım yerinde küçük lav lekeleri soğur, buhar tüter, dokunan düşman cızırdar (20 sn)
static func yoton_chakura_modo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.9)
	_mode_ring(pj, c.global_position)
	var holder = Node3D.new()
	c.add_child(holder)
	holder.position = Vector3(0, 0.95, -0.15)
	var skins = []
	var m = c.get("model")
	if m and m.get("body_mesh") and m.body_mesh and m.skel:
		for layer in 2:
			var cm = MeshInstance3D.new()
			cm.mesh = m.body_mesh.mesh
			m.skel.add_child(cm)
			cm.skin = m.body_mesh.skin
			cm.skeleton = cm.get_path_to(m.skel)
			cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if layer == 0:
				cm.material_override = L.lava_mat()
				cm.set_instance_shader_parameter("seed", randf() * 20.0)
				cm.set_instance_shader_parameter("heat", 1.0)
				cm.set_instance_shader_parameter("crust", 0.4)
				cm.set_instance_shader_parameter("flow", 0.25)
				cm.set_instance_shader_parameter("wob", 0.0)
				cm.set_instance_shader_parameter("nscale", 5.5)
				cm.set_instance_shader_parameter("grow", 0.012)
				cm.set_instance_shader_parameter("near", Vector2(0.3, 0.9))
				cm.set_instance_shader_parameter("fade", 0.0)
			else:
				cm.material_override = L.haze_mat()
				cm.set_instance_shader_parameter("seed", randf() * 20.0)
				cm.set_instance_shader_parameter("grow", 0.08)
				cm.set_instance_shader_parameter("fade", 0.0)
			cm.create_tween().tween_method(L.pf(cm, "fade"), 0.0, 1.0, 0.35)
			skins.append(cm)
		holder.set_meta("cloak", skins[0])
		holder.tree_exiting.connect(func():
			for cm in skins:
				if is_instance_valid(cm):
					cm.queue_free())
	if c is Player:
		Buffs.add("yoton_chakura", 20.0, {"melee": 1.35, "armor": 0.75, "_name": "Lav Çakra Modu", "_desc": "lav örtüsü: dokunan yanar, güç artar"})
	pj.every(20.0, 0.5, func(i, _k):
		if not pj.live(c):
			return
		# bedenden yükselen buhar, damlayan lav, adım yerinde soğuyan lav lekesi
		L.vapor(pj, c.global_position + Vector3(randf_range(-0.3, 0.3), randf_range(1.2, 1.9), randf_range(-0.3, 0.3)), randf_range(0.7, 1.0), 1.2, Vector3(0, 1.4, 0))
		L.lava_drops(pj, c.global_position + Vector3(randf_range(-0.25, 0.25), randf_range(0.5, 1.3), randf_range(-0.25, 0.25)), 1, 1.0, Vector3.DOWN, 0.4, 0.06, 1.0, 1.6)
		if i % 2 == 0:
			L.lava_pool(pj, c.global_position, 0.45, 2.2, 0.9, 0.05)
		for e in pj.enemies_near(c, c.global_position, 2.8):
			_sizzle(pj, e)
			e.take_hit(pj.inf(c, "yoton_chakura_modo", 0.25, {"knock": 0.0, "kind": "light", "element": "yoton", "burn": 2.0})), func():
		for cm in skins:
			if is_instance_valid(cm):
				var tw = cm.create_tween()
				tw.tween_method(L.pf(cm, "fade"), 1.0, 0.0, 0.3)
		if is_instance_valid(holder):
			var th = holder.create_tween()
			th.tween_interval(0.32)
			th.tween_callback(holder.queue_free))
	pj.shake(0.6)
	Sfx.play("fire", c.global_position, 0.7)


## Mod açılışı: ayak altından dışa yuvarlanan kalın lav halkası (çember tüp), arkasında kızgın çatlaklar, yukarı ağır damlalar
static func _mode_ring(pj: PathJutsu, p: Vector3) -> void:
	var g = L.floor_at(p)
	var pts = []
	var rr = []
	for i in 25:
		var a = i * TAU / 24.0
		pts.append(Vector3(cos(a), 0.0, sin(a)))
		rr.append(0.11 * (1.0 + 0.3 * sin(a * 5.0)))
	var mi = L.lava_mi(L.tube_mesh(pts, rr, 7, 0.25, randf() * 5.0), 1.1, 0.3, {"nscale": 3.0, "wob": 0.04, "flow": 0.8, "near": Vector2(1.0, 2.5)})
	L.put(pj, mi, g + Vector3.UP * 0.08)
	mi.scale = Vector3(0.4, 1.6, 0.4)
	var tw = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(4.2, 0.8, 4.2), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(L.pf(mi, "fade"), 1.0, 0.0, 0.35)
	tw.tween_callback(mi.queue_free)
	mi.create_tween().tween_method(L.pf(mi, "heat"), 1.1, 0.35, 0.9)
	L.cracks(pj, g, 4.5, 4.0, 1.1, 0.5, 2.6)
	L.lava_drops(pj, g + Vector3.UP * 0.3, 12, 6.0, Vector3.UP, 0.7, 0.09)
	L.glow(pj, g + Vector3.UP * 1.0, 3.5, HOT, 0.5)
	L.light(pj, g + Vector3.UP * 1.0, LAVA_LIGHT, 4.0, 9.0, 0.8)


# ================================================================== Kaisekifū
## Kül Taşı Mühürü: ağızdan koyu kömür renkli, kıvrımlı kül taşı kütlesi (içinden mavi kristal pullar fışkıran) güdümlü uçar,
## arkasında kül döker; değdiği hedefi kat kat sarıp gövdeyi gömer, mavi kristaller dışarı batar (ref: Kinshiki), sonra ufalanır
static func yoton_kaisekifu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	var from = pj._mouth_pos(c)
	var body = _ash_body()
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 22.0, body, pj.inf(c, "yoton_kaisekifu_no_jutsu", 1.0, {"knock": 8.0, "kind": "heavy", "element": "yoton"}), tt, false, 1.6, func(p, h):
		_ash_burst(pj, p)
		L.crack_zone(pj.gp(p), 3.0, 6.0)
		if h and pj.live(h):
			pj.st(h, "bind", 2.5)
			pj.st(h, "slow", 5.0)
			Combat.popup_text(h.global_position + Vector3.UP * 2.3, "Taşlaşıyor!", Color(0.7, 0.7, 0.72))
			_ash_encase(pj, h, 2.5))
	pr.homing_turn = 2.0
	_set_tick(pr, 0.06, func(pp): L.paste_drops(pj, pp.global_position, 1, 1.5, L.K_ASH, Vector3.DOWN, 0.9, 0.07, 0.9))
	Sfx.play("water", from, 0.6)


static func _ash_body() -> Node3D:
	var root = Node3D.new()
	var spin = Node3D.new()
	root.add_child(spin)
	var core = L.paste_blob(0.55, L.K_ASH, 0.38, {"near": Vector2(0.8, 2.0), "wob": 0.06})
	core.scale = Vector3(0.6, 0.5, 0.75)
	spin.add_child(core)
	for k in 3:
		var coil = L.paste_blob(0.28, L.K_ASH, 0.3, {"near": Vector2(0.8, 2.0), "wob": 0.05})
		var a = k * TAU / 3.0
		coil.position = Vector3(cos(a) * 0.38, sin(a) * 0.3, 0.2)
		spin.add_child(coil)
	for k in 6:
		var cr = L.crystal_mi(randf_range(0.45, 0.7), 0.09)
		var dv = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-0.6, 1.0)).normalized()
		cr.basis = Basis.looking_at(dv, Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.35))
		cr.position = dv * 0.22
		spin.add_child(cr)
	var tw = Game.safe_loops(spin.create_tween())
	tw.tween_property(spin, "rotation:z", TAU, 0.9).from(0.0)
	return root


## Çarpma: kül topakları ve kopan mavi kristal pulları saçılır, zeminde kararan yarık
static func _ash_burst(pj: PathJutsu, p: Vector3) -> void:
	L.paste_drops(pj, p, 14, 6.0, L.K_ASH, Vector3.UP, 0.9, 0.14, 1.6)
	for k in 5:
		var cr = L.crystal_mi(randf_range(0.2, 0.35), 0.06)
		L.drop(pj, cr, p, Vector3(randf_range(-4, 4), randf_range(3, 6), randf_range(-4, 4)), 1.0, 1.2, 18.0)
	L.cracks(pj, p, 1.8, 3.0, 0.0, 0.15, 3.5)


## Hedefi saran kül taşı: alttan yukarı kat kat sarılan kalın kıvrımlar, yerde yayvan taban, dışa batmış mavi kristaller;
## süre biterken griye döner (taşlaşma) ve ufalanıp düşer
static func _ash_encase(pj: PathJutsu, h: Node3D, dur: float) -> void:
	var root = Node3D.new()
	h.add_child(root)
	ClanJutsu.fit_body(h, root)
	var pieces = []
	var base = L.paste_blob(1.0, L.K_ASH, 0.35, {"near": Vector2(0.6, 1.6), "wob": 0.03, "nscale": 1.6})
	base.scale = Vector3(1.15, 0.28, 1.15)
	base.position = Vector3(0, 0.1, 0)
	root.add_child(base)
	pieces.append(base)
	for k in 4:
		var y = 0.3 + k * 0.36
		var R = 0.62 - k * 0.06
		var pts = []
		var rr = []
		var ph = randf() * TAU
		for i in 15:
			var a = ph + i * TAU / 14.0 * 1.08
			pts.append(Vector3(cos(a) * R, y + (float(i) / 14.0 - 0.5) * 0.22, sin(a) * R))
			rr.append(0.25 - k * 0.025)
		var coil = L.paste_mi(L.tube_mesh(pts, rr, 7, 0.22, ph), L.K_ASH, {"near": Vector2(0.6, 1.6), "wob": 0.04, "nscale": 1.8})
		root.add_child(coil)
		coil.scale = Vector3(0.05, 1.0, 0.05)
		var cw = coil.create_tween()
		cw.tween_interval(k * 0.07)
		cw.tween_property(coil, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pieces.append(coil)
	for k in 5:
		var cr = L.crystal_mi(randf_range(0.55, 0.85), 0.11)
		var a = randf() * TAU
		var dv = Vector3(cos(a), randf_range(-0.2, 0.5), sin(a)).normalized()
		cr.basis = Basis.looking_at(dv, Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.35))
		cr.position = Vector3(cos(a) * 0.45, randf_range(0.4, 1.4), sin(a) * 0.45)
		root.add_child(cr)
	var tw = root.create_tween()
	tw.tween_interval(dur * 0.6)
	tw.tween_callback(func():
		for pc in pieces:
			if is_instance_valid(pc):
				pc.create_tween().tween_method(L.pf(pc, "stress"), 0.0, 1.0, dur * 0.35))
	tw.tween_interval(dur * 0.4)
	tw.tween_callback(func():
		if is_instance_valid(root) and root.is_inside_tree():
			L.paste_drops(pj, root.global_position + Vector3.UP * 0.9, 16, 4.0, L.K_ASH, Vector3.UP, 1.0, 0.13, 1.4))
	tw.tween_callback(root.queue_free)


# ================================================================== Yōkai (geniş çamur püskürtmesi)
## Eriten Görünüm (Mei, ref): ağızda bej çamur kabarır, sonra geniş, kabarık, yırtık kenarlı bej aşındırıcı çamur bulutu
## yelpaze gibi açılarak ileri fışkırır — kıvrık kanca uçlar, ince zerreler; vardığı yerde buhar tüten aşındırıcı göl kalır
static func yoton_yokai_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var mouth = pj._mouth_pos(c)
	_goo_gather(pj, mouth)
	var dir = (d - Vector3.UP * 0.15).normalized()
	_goo_fan(pj, c, mouth, dir, 14.0)
	var end = mouth + dir * 14.0
	pj.after(0.55, func():
		L.goo_pool(pj, end, 2.4, 5.0)
		L.goo_pool(pj, mouth + dir * 8.0, 1.4, 4.0)
		_impact_marks(pj, pj.gp(end) + Vector3.UP * 0.5, 1.4))
	Combat.hit_zone(c, c.global_position, d, 14.0, 18.0, 3.0, pj.inf(c, "yoton_yokai_no_jutsu", 1.6, {"knock": 8.0, "kind": "heavy", "element": "yoton", "burn": 4.0}))
	Sfx.play("fire", c.global_position, 0.5)


## Ağızda kabaran bej çamur kesesi + dudaktan düşen ağır damlalar
static func _goo_gather(pj: PathJutsu, at: Vector3) -> void:
	var b = L.paste_blob(0.05, L.K_GOO, 0.3, {"bub": 0.6, "near": Vector2(0.3, 0.9)})
	L.put(pj, b, at)
	var tw = b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE * 0.22, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_method(L.pf(b, "fade"), 1.0, 0.0, 0.15)
	tw.tween_callback(b.queue_free)
	L.paste_drops(pj, at, 3, 1.0, L.K_GOO, Vector3.DOWN, 0.5, 0.05, 1.0)


static func _goo_fan(pj: PathJutsu, c: Node3D, mouth: Vector3, dir: Vector3, reach: float) -> void:
	var sd = L.side_of(dir)
	pj.every(0.7, 0.05, func(i, _k):
		var o = pj._mouth_pos(c) if pj.live(c) else mouth
		var ang = deg_to_rad(randf_range(-17.0, 17.0))
		var dv = dir.rotated(Vector3.UP, ang) + Vector3.UP * randf_range(-0.05, 0.12)
		dv = dv.normalized()
		var dist = reach * randf_range(0.75, 1.0)
		var r1 = randf_range(1.1, 1.8)
		var b = L.paste_blob(0.2, L.K_GOO, 0.4, {"bub": 0.35, "wob": 0.12, "near": Vector2(2.0, 5.0), "nscale": 1.2})
		L.put(pj, b, o)
		var stretch = Vector3(r1, r1 * 0.75, r1 * 1.5)
		var tw = b.create_tween()
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(b):
				return
			var e = 1.0 - (1.0 - u) * (1.0 - u)
			b.global_position = o + dv * dist * e + Vector3.DOWN * u * u * 1.2
			b.global_basis = Basis.looking_at(dv, Vector3.UP) * Basis.from_scale(Vector3.ONE * 0.2 + stretch * e), 0.0, 1.0, 0.5)
		tw.tween_method(L.pf(b, "fade"), 1.0, 0.0, 0.25)
		tw.tween_callback(b.queue_free)
		if i % 3 == 1:
			_goo_hook(pj, o + dv * dist * 0.4, dv, sd)
		if i % 2 == 0:
			pj.after(0.3, func():
				L.paste_drops(pj, o + dv * dist * 0.6, 3, 3.0, L.K_GOO, dv + Vector3.UP * 0.3, 0.7, 0.06, 1.2)))


## Çamurun kıvrık kanca ucu (ref: bulutun üstünden kıvrılan ince çamur dili)
static func _goo_hook(pj: PathJutsu, p: Vector3, dv: Vector3, sd: Vector3) -> void:
	var pts = []
	var rr = []
	var sgn = 1.0 if randf() < 0.5 else -1.0
	for i in 8:
		var u = float(i) / 7.0
		var a = u * PI * 1.3
		pts.append(dv * u * 1.4 + Vector3.UP * sin(a) * 0.9 * u + sd * sgn * (1.0 - cos(a)) * 0.35 * u)
		rr.append(0.12 * (1.0 - u * 0.8))
	var mi = L.paste_mi(L.tube_mesh(pts, rr, 6, 0.1), L.K_GOO, {"wob": 0.03, "near": Vector2(2.0, 5.0), "nscale": 2.0})
	L.put(pj, mi, p)
	mi.scale = Vector3.ONE * 0.2
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.2, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position", p + dv * 4.0 + Vector3.DOWN * 0.6, 0.55)
	tw.chain().tween_method(L.pf(mi, "fade"), 1.0, 0.0, 0.2)
	tw.chain().tween_callback(mi.queue_free)


# ================================================================== Sekkaigyō
## Sönmemiş Kireç: ağızdan kabarık beyaz kireç kütlesi fışkırır, arkasına doğru sivri kireç dilleri savrulur (ref);
## hedefi beyaz topaklı kabukla örter, kabuk sertleşip çatlar, süre bitince parça parça kırılıp düşer
static func yoton_sekkaigyo_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 18.0)
	var from = pj._mouth_pos(c)
	var to = (tt.global_position + Vector3.UP if tt else from + c.face_dir() * 12.0)
	_lime_jet(pj, from, to)
	if tt:
		pj.after(0.3, func():
			if not pj.live(tt):
				return
			_lime_shell(pj, tt, 3.0)
			pj.st(tt, "bind", 3.0)
			tt.take_hit(pj.inf(c, "yoton_sekkaigyo_no_jutsu", 0.5, {"knock": 0.0, "kind": "heavy", "element": "yoton"})))
	Sfx.play("water", from, 0.7)


static func _lime_jet(pj: PathJutsu, from: Vector3, to: Vector3) -> void:
	var dv = to - from
	if dv.length() < 0.1:
		dv = Vector3.FORWARD
	var dn = dv.normalized()
	for j in 5:
		var head = Node3D.new()
		L.put(pj, head, from)
		L.look(head, dn)
		var s = 1.0 - j * 0.14
		var b = L.paste_blob(0.6 * s, L.K_LIME, 0.35, {"wob": 0.07, "near": Vector2(1.5, 3.5), "nscale": 1.6})
		b.scale = Vector3(0.6, 0.55, 0.8) * s
		head.add_child(b)
		if j < 2:
			# arkaya savrulan sivri kireç dilleri
			for k in 5:
				var a = k * TAU / 5.0 + randf() * 0.4
				var off = Vector3(cos(a) * 0.35, sin(a) * 0.3, 0.1) * s
				var ln = randf_range(0.9, 1.6) * s
				var pts = [off, off + Vector3(cos(a) * 0.15, sin(a) * 0.12, ln * 0.4), off + Vector3(cos(a) * 0.22, sin(a) * 0.2 + 0.05, ln)]
				var sp = L.paste_mi(L.tube_mesh(pts, [0.16 * s, 0.09 * s, 0.015], 5, 0.05, 0.0, 1.5), L.K_LIME, {"wob": 0.0, "near": Vector2(1.5, 3.5), "nscale": 2.0})
				head.add_child(sp)
		head.scale = Vector3.ONE * 0.4
		var tw = head.create_tween()
		tw.tween_interval(j * 0.035)
		tw.tween_property(head, "global_position", to - dn * j * 0.35, 0.3).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(head, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.08)
		tw.tween_property(head, "scale", Vector3.ONE * 0.05, 0.22).set_ease(Tween.EASE_IN)
		tw.tween_callback(head.queue_free)
	pj.after(0.3, func():
		L.paste_drops(pj, to, 10, 4.0, L.K_LIME, -dn + Vector3.UP * 0.4, 0.8, 0.1, 1.4))


static func _lime_shell(pj: PathJutsu, tt: Node3D, dur: float) -> void:
	var root = Node3D.new()
	tt.add_child(root)
	ClanJutsu.fit_body(tt, root)
	var lumps = []
	for k in 8:
		var a = k * TAU / 8.0 + randf() * 0.3
		var y = 0.25 + (k % 4) * 0.48
		var b = L.paste_blob(0.5, L.K_LIME, 0.3, {"wob": 0.02, "near": Vector2(0.6, 1.6), "nscale": 1.6})
		b.position = Vector3(cos(a) * 0.32, y, sin(a) * 0.32)
		b.scale = Vector3(0.55, 0.62, 0.55)
		root.add_child(b)
		lumps.append(b)
	var top = L.paste_blob(0.4, L.K_LIME, 0.3, {"wob": 0.02, "near": Vector2(0.6, 1.6)})
	top.position = Vector3(0, 1.95, 0)
	root.add_child(top)
	lumps.append(top)
	root.scale = Vector3(1.0, 0.1, 1.0)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for b in lumps:
		b.create_tween().tween_method(L.pf(b, "stress"), 0.0, 1.0, 0.6)
	tw.tween_interval(dur - 0.2)
	tw.tween_callback(func():
		if not is_instance_valid(root) or not root.is_inside_tree():
			return
		for b in lumps:
			if is_instance_valid(b):
				var chunk = L.paste_blob(0.22, L.K_LIME, 0.45, {"wob": 0.0, "stress": 1.0, "near": Vector2(0.4, 1.2)})
				var p0 = b.global_position
				var v = (p0 - root.global_position - Vector3.UP).normalized() * randf_range(2.0, 4.0) + Vector3.UP * 2.0
				L.drop(pj, chunk, p0, v, 0.22, 1.4, 20.0, Callable(), 0.0)
		L.paste_drops(pj, root.global_position + Vector3.UP, 16, 6.0, L.K_LIME, Vector3.UP, 0.9, 0.08, 1.2))
	tw.tween_callback(root.queue_free)


# ================================================================== Shakugaikōken
## Kavurucu Zırh Yumruğu: sağ kol ve yumruk kabuk plakalı, beyaz konturlu kalın lav zırhıyla kaplanır (ref), atılıp tek yumruk —
## çarpınca yumruk yönünde lav yelpaze gibi yassılaşıp yapışır, kabuk kırıkları ve ağır damlalar ileri savrulur
static func yoton_shakugaikoken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	pj.busy(c, 0.7)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(_lava_fist(0.24, 0.6))
		pj.free_after(0.7, ba)
	var bl = pj.bone_attach(c, "RightLowerArm")
	if bl:
		var arm = Node3D.new()
		for k in 3:
			var seg = L.lava_blob(0.13, 1.0, 0.6, 0.35, {"near": Vector2(0.3, 0.9), "nscale": 6.0, "wob": 0.02})
			seg.position = Vector3(0, 0.06 + k * 0.1, 0)
			seg.scale = Vector3(0.14, 0.11, 0.14)
			arm.add_child(seg)
		arm.scale = Vector3.ONE * 0.05
		arm.create_tween().tween_property(arm, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		bl.add_child(arm)
		pj.free_after(0.7, bl)
	var d = pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var at = c.global_position + Vector3.UP * 1.2 + d * 1.3
		_armor_impact(pj, at, d)
		_impact_marks(pj, at, 1.4)
		var info = pj.inf(c, "yoton_shakugaikoken", 1.8, {"knock": 16.0, "kind": "heavy", "element": "yoton", "burn": 4.0})
		_melee_marks(pj, pj.hit(c, at, 2.0, info), info)
		Sfx.play("fire", at, 0.9))


static func _armor_impact(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	# yumruk yönüne dik yassı lav sıçraması (havaya yapışmış gibi açılır, sonra sarkıp düşer)
	var sp = L.lava_blob(1.0, 1.15, 0.3, 0.45, {"wob": 0.08, "nscale": 3.0, "near": Vector2(2.0, 4.5)})
	L.put(pj, sp, at + d * 0.3)
	L.look(sp, d)
	var bs = sp.basis
	sp.basis = bs * Basis.from_scale(Vector3(0.2, 0.2, 0.05))
	var tw = sp.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(sp):
			sp.basis = bs * Basis.from_scale(Vector3(0.2 + 1.3 * u, 0.2 + 1.1 * u - 0.3 * u * u, 0.05 + 0.2 * u))
			sp.global_position = at + d * (0.3 + 0.8 * u) + Vector3.DOWN * 0.5 * u * u, 0.0, 1.0, 0.35)
	tw.tween_method(L.pf(sp, "fade"), 1.0, 0.0, 0.3)
	tw.tween_callback(sp.queue_free)
	sp.create_tween().tween_method(L.pf(sp, "heat"), 1.15, 0.4, 0.65)
	L.lava_drops(pj, at, 14, 8.0, d + Vector3.UP * 0.25, 0.45, 0.1)
	for k in 6:
		L.crust_rock(pj, at, d * randf_range(4.0, 8.0) + Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2)), randf_range(0.08, 0.18))
	L.glow(pj, at, 2.8, HOT, 0.3)
	L.light(pj, at, LAVA_LIGHT, 4.0, 8.0, 0.5)
	L.vapor(pj, at + Vector3.UP * 0.3, 1.4, 1.1, Vector3(0, 1.2, 0) + d * 0.5)
	L.cracks(pj, at, 2.0, 3.0, 1.0, 0.15)


# ================================================================== Shakugaryūgan
## Kavurucu Ejder Kayası: ağızdan art arda beş lav güllesi — sarı-turuncu parlayan, yüzeyi koyu taş benekli (ref) iri küre,
## ardında uzayan erimiş lav kuyruğu, düşen koyu kızıl damlalar; çarpınca yapışkan lav lekesine ezilir, kabuk kırıkları saçılır
static func yoton_shakugaryugan_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	for k in 5:
		pj.after(k * 0.13, func():
			if pj.live(c):
				_ryugan_shot(pj, c, tt, pj._mouth_pos(c), k))
	Sfx.play("fire", c.global_position, 0.6)


## Eski element mermisi oynanışı birebir: 0.05 sn sonra ağızdan nişana, yarıçap 0.75, ömür 1.6, bilgi aynı
static func _ryugan_shot(pj: PathJutsu, c: Node3D, tt: Node3D, from: Vector3, k: int) -> void:
	var bul = L.lava_blob(0.05, 1.2, 0.2, 0.3, {"near": Vector2(0.4, 1.2)})
	L.put(pj, bul, from)
	var bw = bul.create_tween()
	bw.tween_property(bul, "scale", Vector3.ONE * 0.3, 0.06)
	bw.tween_callback(bul.queue_free)
	pj.after(0.05, func():
		if not pj.live(c):
			return
		var info = {"knock": 8.0 * 1.1, "kind": "heavy", "element": "yoton", "hitstop": 0.05}
		info.merge({"burn": 3.0}, true)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, _ryugan_body(k), pj.inf(c, "yoton_shakugaryugan_no_jutsu", 0.45, info), null, false, 1.6, func(p, _h):
			_ryugan_burst(pj, p)
			_impact_marks(pj, p, 1.1))
		pr.radius = 0.35 + 1.0 * 0.4
		_set_tick(pr, 0.05, func(pp): L.lava_drops(pj, pp.global_position + pp.global_basis.z * 0.5, 1, 1.0, Vector3.DOWN, 0.6, 0.06, 0.8, 1.2)))


static func _ryugan_body(k: int) -> Node3D:
	var root = Node3D.new()
	var ball = L.lava_blob(0.48, 1.15, 0.5, 0.2, {"nscale": 4.2, "flow": 1.4, "wob": 0.05, "near": Vector2(0.6, 1.6)})
	root.add_child(ball)
	ball.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	var pts = []
	var rr = []
	var ph = k * 1.7
	for i in 7:
		var u = float(i) / 6.0
		pts.append(Vector3(sin(u * 4.0 + ph) * 0.1 * u, cos(u * 3.0 + ph) * 0.08 * u, 0.25 + u * 2.4))
		rr.append(0.34 * (1.0 - u * 0.85))
	var tail = L.lava_mi(L.tube_mesh(pts, rr, 7, 0.25, ph, 0.8), 1.1, 0.25, {"nscale": 3.0, "flow": 2.5, "wob": 0.06, "near": Vector2(0.6, 1.6)})
	root.add_child(tail)
	root.add_child(L.glow_mi(HOT, 1.6))
	var tw = Game.safe_loops(tail.create_tween())
	tw.tween_property(tail, "rotation:z", 0.4, 0.15)
	tw.tween_property(tail, "rotation:z", -0.4, 0.15)
	return root


static func _ryugan_burst(pj: PathJutsu, p: Vector3) -> void:
	var g = L.floor_at(p)
	var low = p.y - g.y < 1.6
	L.lava_drops(pj, p, 10, 6.5, Vector3.UP, 0.85, 0.1)
	for k in 4:
		L.crust_rock(pj, p, Vector3(randf_range(-4, 4), randf_range(2, 6), randf_range(-4, 4)), randf_range(0.1, 0.2))
	L.glow(pj, p, 2.2, HOT, 0.3)
	L.light(pj, p, LAVA_LIGHT, 3.0, 7.0, 0.5)
	if low:
		L.lava_pool(pj, g, 1.0, 3.0, 1.1)
		L.vapor(pj, g + Vector3.UP * 0.4, 1.0, 1.3, Vector3(0, 1.3, 0))
	else:
		var sp = L.lava_blob(0.5, 1.1, 0.4, 0.45, {"wob": 0.1, "near": Vector2(1.0, 2.5)})
		L.put(pj, sp, p)
		var tw = sp.create_tween()
		tw.tween_property(sp, "scale", Vector3(1.2, 0.5, 1.2), 0.15).set_ease(Tween.EASE_OUT)
		tw.tween_method(L.pf(sp, "fade"), 1.0, 0.0, 0.25)
		tw.tween_callback(sp.queue_free)


# ================================================================== Senpō Yōton Rasenshuriken
const DISC_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float fade = 1.0;
instance uniform float spin = 14.0;
instance uniform float seed = 0.0;

float dh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float dn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(dh(i), dh(i + vec2(1.0, 0.0)), f.x), mix(dh(i + vec2(0.0, 1.0)), dh(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float an = atan(uv.y, uv.x) + TIME * spin;
	vec2 pc = vec2(cos(an), sin(an));
	float n = dn(pc * 2.5 + vec2(r * 9.0, seed)) * 0.6 + dn(pc * 6.0 + vec2(r * 22.0, seed * 2.0)) * 0.4;
	float edge = 0.92 + (n - 0.5) * 0.18;
	if (r > edge || r < 0.14) {
		discard;
	}
	float a = 0.4 + 0.32 * smoothstep(0.45, 0.62, n);
	a *= smoothstep(edge, edge - 0.12, r) * smoothstep(0.14, 0.3, r);
	vec3 col = n > 0.55 ? vec3(0.98, 0.98, 1.0) : vec3(0.8, 0.82, 0.86);
	col = mix(col, vec3(1.0, 0.7, 0.4), smoothstep(0.45, 0.2, r) * 0.6);
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = a * fade * smoothstep(0.8, 2.5, -VERTEX.z);
}
"""


static func _disc_mat() -> ShaderMaterial:
	if not _cache.has("disc"):
		var sh = Shader.new()
		sh.code = DISC_SHADER
		var m = ShaderMaterial.new()
		m.shader = sh
		_cache["disc"] = m
	return _cache["disc"]


static func _disc_mesh() -> PlaneMesh:
	if not _cache.has("discm"):
		var p = PlaneMesh.new()
		p.size = Vector2(2.0, 2.0)
		_cache["discm"] = p
	return _cache["discm"]


## Lav Rasenşurikeni (yerel XZ düzleminde): kızgın lav çekirdeği (ince desenli, kaynayan), çevresinde dönen dört kavisli
## erimiş lav kanadı ve beyaz, bulanık rüzgâr diski (ref: Naruto'nun avucundaki lav çekirdekli Rasenşuriken)
static func _lava_rsh(s: float) -> Node3D:
	var root = Node3D.new()
	var core = L.lava_blob(0.36 * s, 1.25, 0.28, 0.12, {"nscale": 7.0, "flow": 1.8, "wob": 0.03, "near": Vector2(0.5, 1.3)})
	root.add_child(core)
	root.add_child(L.glow_mi(Color(1.0, 0.62, 0.25, 0.9), 1.8 * s))
	var blades = Node3D.new()
	root.add_child(blades)
	for k in 4:
		var a0 = k * TAU / 4.0
		var pts = []
		var rr = []
		for i in 7:
			var u = float(i) / 6.0
			var a = a0 + u * 0.95
			var rad = (0.32 + u * 1.05) * s
			pts.append(Vector3(cos(a) * rad, 0.0, sin(a) * rad))
			rr.append((0.13 * (1.0 - u) + 0.015) * s)
		var bl = L.lava_mi(L.tube_mesh(pts, rr, 6, 0.15, a0, 1.0), 1.1, 0.35, {"nscale": 4.0, "flow": 2.0, "wob": 0.02, "near": Vector2(0.5, 1.3)})
		bl.scale = Vector3(1.0, 0.35, 1.0)
		blades.add_child(bl)
	var bt = Game.safe_loops(blades.create_tween())
	bt.tween_property(blades, "rotation:y", -TAU, 0.35).from(0.0)
	var disc = L.gi(_disc_mesh(), _disc_mat())
	disc.set_instance_shader_parameter("fade", 1.0)
	disc.set_instance_shader_parameter("spin", 16.0)
	disc.set_instance_shader_parameter("seed", randf() * 10.0)
	disc.scale = Vector3(1.75 * s, 1.0, 1.75 * s)
	root.add_child(disc)
	return root


## Bilge Sanatı Lav Rasenşurikeni: avuca dört yandan lav zerreleri sarmal akar, lav çekirdekli Rasenşuriken elde büyür,
## fırlatılır; çarpınca erimiş lav kubbesi kabarıp çöker, her yöne yay çizen lav ipleri, kabuk taşları, geniş soğuyan lav gölü
static func senpo_yoton_rasenshuriken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 34.0)
	var from = pj.hand_pos(c, true) + Vector3.UP * 0.4
	_sage_gather(pj, c, from)
	pj.busy(c, 1.8)
	var held = _lava_rsh(0.7)
	L.put(pj, held, from)
	held.scale = Vector3.ONE * 0.1
	var ht = held.create_tween()
	ht.tween_method(func(u: float):
		if is_instance_valid(held) and pj.live(c):
			held.global_position = pj.hand_pos(c, true) + Vector3.UP * 0.9
			held.scale = Vector3.ONE * lerpf(0.1, 1.0, minf(1.0, u * 1.6)), 0.0, 1.0, 1.0)
	ht.tween_callback(held.queue_free)
	pj.after(1.0, func():
		if not pj.live(c):
			return
		var fr = pj.hand_pos(c, true) + Vector3.UP * 0.9
		var core = _lava_rsh(0.7)
		var pr = pj.shot(c, fr, pj.aim_at(c, tt, fr), 20.0, core, pj.inf(c, "senpo_yoton_rasenshuriken", 2.0, {"knock": 10.0, "kind": "heavy", "element": "yoton", "burn": 4.0}), tt, false, 1.8, func(p, _h):
			_rsh_burst(pj, p)
			_impact_marks(pj, p, 2.6)
			L.crack_zone(p, 5.2, 4.0)
			pj.hit(c, p, 7.0, pj.inf(c, "senpo_yoton_rasenshuriken", 1.6, {"knock": 20.0, "launch": 6.0, "kind": "heavy", "element": "yoton", "burn": 5.0}))
			pj.shake(1.2))
		pr.radius = 1.2
		_set_tick(pr, 0.07, func(pp): _rsh_fling(pj, pp)))
	Sfx.play("wind", c.global_position, 0.8)


## Dönen kanatlardan savrulan lav damlası
static func _rsh_fling(pj: PathJutsu, pp: Node3D) -> void:
	var a = randf() * TAU
	var sp = pp.global_basis * Vector3(cos(a), 0.0, sin(a)) * 1.1
	L.lava_drops(pj, pp.global_position + sp, 1, 3.0, sp + Vector3.DOWN * 0.3, 0.3, 0.07, 1.0, 1.2)


## Bilge hazırlığı: avucun çevresinde dört yandan lav damlaları sarmal çizerek içeri akar, avuçta kızgın ışık
static func _sage_gather(pj: PathJutsu, c: Node3D, to: Vector3) -> void:
	for k in 10:
		var a0 = k * TAU / 10.0
		var y0 = randf_range(-0.4, 0.8)
		var b = L.lava_blob(0.09, 1.1, 0.15, 0.2, {"wob": 0.0, "near": Vector2(0.4, 1.2)})
		L.put(pj, b, to + Vector3(cos(a0) * 1.5, y0, sin(a0) * 1.5))
		var dly = randf() * 0.25
		var tw = b.create_tween()
		tw.tween_interval(dly)
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(b):
				return
			var dest = (pj.hand_pos(c, true) + Vector3.UP * 0.9) if pj.live(c) else to
			var a = a0 + u * 3.6
			var rr = 1.5 * (1.0 - u)
			b.global_position = dest + Vector3(cos(a) * rr, y0 * (1.0 - u), sin(a) * rr)
			b.scale = Vector3.ONE * 0.09 * (1.0 + u * 0.6), 0.0, 1.0, maxf(0.1, 0.75 - dly)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.queue_free)
	L.glow(pj, to + Vector3.UP * 0.5, 1.4, HOT, 1.0)


static func _rsh_burst(pj: PathJutsu, p: Vector3) -> void:
	var g = L.floor_at(p)
	var base = g if p.y - g.y < 3.0 else p
	# erimiş lav kubbesi: kabarır, kendi ağırlığıyla çöküp yayılır, kabuk bağlar
	var dome = L.lava_blob(1.0, 1.25, 0.2, 0.3, {"nscale": 4.5, "flow": 0.8, "wob": 0.1, "near": Vector2(4.0, 8.0)})
	L.put(pj, dome, base)
	dome.scale = Vector3(0.5, 0.4, 0.5)
	var tw = dome.create_tween()
	tw.tween_property(dome, "scale", Vector3(4.2, 3.2, 4.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dome, "scale", Vector3(4.8, 0.25, 4.8), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(L.pf(dome, "fade"), 1.0, 0.0, 0.3)
	tw.tween_callback(dome.queue_free)
	dome.create_tween().tween_method(L.pf(dome, "heat"), 1.25, 0.45, 1.3)
	pj.after(0.7, func():
		L.lava_pool(pj, g, 4.0, 6.0, 1.0, 0.12))
	# her yöne yay çizen ağır lav ipleri
	for k in 8:
		var a = k * TAU / 8.0 + randf() * 0.3
		var dest = L.floor_at(base + Vector3(cos(a), 0.0, sin(a)) * randf_range(5.5, 8.0))
		var pts = L.arc_pts(Vector3.ZERO, dest - base, 9, randf_range(2.0, 3.2))
		var rr = []
		for i in 9:
			rr.append(0.24 * (1.0 - float(i) / 9.0 * 0.6))
		var arc = L.lava_mi(L.tube_mesh(pts, rr, 6, 0.25, a), 1.15, 0.3, {"nscale": 2.2, "flow": 1.6, "wob": 0.05, "near": Vector2(3.0, 6.5)})
		L.put(pj, arc, base)
		arc.scale = Vector3.ONE * 0.05
		var aw = arc.create_tween()
		aw.tween_property(arc, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)
		aw.tween_interval(0.5)
		aw.tween_method(L.pf(arc, "fade"), 1.0, 0.0, 0.4)
		aw.tween_callback(arc.queue_free)
		arc.create_tween().tween_method(L.pf(arc, "heat"), 1.15, 0.3, 1.2)
		pj.after(0.35, func():
			L.lava_pool(pj, dest, 0.8, 3.5, 1.0)
			L.lava_drops(pj, dest + Vector3.UP * 0.3, 3, 3.0, Vector3.UP, 0.6, 0.08))
	L.lava_drops(pj, p, 24, 11.0, Vector3.UP, 0.8, 0.13)
	for k in 10:
		L.crust_rock(pj, p, Vector3(randf_range(-7, 7), randf_range(4, 10), randf_range(-7, 7)), randf_range(0.15, 0.32), 2.2)
	# rüzgâr diskinin dağılan izi
	var ring = L.gi(_disc_mesh(), _disc_mat())
	ring.set_instance_shader_parameter("fade", 1.0)
	ring.set_instance_shader_parameter("spin", 6.0)
	ring.set_instance_shader_parameter("seed", randf() * 10.0)
	L.put(pj, ring, base + Vector3.UP * 0.6)
	ring.scale = Vector3(2.0, 1.0, 2.0)
	var rw = ring.create_tween()
	rw.set_parallel(true)
	rw.tween_property(ring, "scale", Vector3(9.0, 1.0, 9.0), 0.5).set_ease(Tween.EASE_OUT)
	rw.tween_method(L.pf(ring, "fade"), 1.0, 0.0, 0.5)
	rw.chain().tween_callback(ring.queue_free)
	L.cracks(pj, g, 6.5, 6.0, 1.15, 0.35, 2.4)
	L.glow(pj, base + Vector3.UP * 1.2, 7.0, HOT, 0.55)
	L.light(pj, base + Vector3.UP * 1.5, LAVA_LIGHT, 7.0, 16.0, 1.2)
	for k in 4:
		var a2 = k * TAU / 4.0
		L.vapor(pj, g + Vector3(cos(a2) * 2.5, 0.6, sin(a2) * 2.5), 2.0, 2.0, Vector3(0, 1.5, 0))


# ================================================================== Terumi Yōton Yōkai (kalın çamur halatı)
## Mei'nin Yōkai'si (hedefli): ağızdan kalın, bej, yapışkan aşındırıcı çamur halatı hedefe doğru uzar; uçta topaklar saçılır,
## hedefe çamur yapışıp aşağı sarkan ipler halinde akar, cızırdayıp buhar tüter; değdiği yerde kabarcıklı birikinti kalır
static func terumi_yoton_yokai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 16.0)
	var d = pj.fwd(c, t)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var o = pj._mouth_pos(c) + d * 0.3
		var end = (tt.global_position + Vector3.UP * 1.0) if tt and pj.live(tt) else o + d * 12.0 - Vector3.UP * 0.8
		var mi = L.paste_mi(L.blob_mesh(0), L.K_GOO, {"bub": 0.4, "wob": 0.06, "near": Vector2(1.2, 3.0), "nscale": 1.3})
		mi.mesh = null
		pj.get_tree().current_scene.add_child(mi)
		var grow = func(u: float):
			if not is_instance_valid(mi):
				return
			var pts = []
			var rr = []
			for k in 9:
				var v = (k / 8.0) * u
				var p = o.lerp(end, v) + Vector3.UP * sin(v * PI) * 0.6 + Vector3(sin(v * 9.0 + u * 6.0), 0, cos(v * 7.0)) * 0.12
				pts.append(p)
				rr.append(0.14 + v * 0.55 + sin(v * 11.0) * 0.08)
			mi.mesh = L.tube_mesh(pts, rr, 10, 0.18, u * 3.0, 0.9)
		var tw = mi.create_tween()
		tw.tween_method(grow, 0.05, 1.0, 0.35)
		tw.tween_callback(func():
			L.paste_drops(pj, end, 14, 5.0, L.K_GOO, Vector3.UP, 0.9, 0.12, 1.6)
			L.goo_pool(pj, end, 1.5, 4.5)
			if tt and pj.live(tt):
				_goo_stick(pj, tt))
		tw.tween_interval(0.35)
		tw.tween_method(L.pf(mi, "fade"), 1.0, 0.0, 0.3)
		tw.tween_callback(mi.queue_free)
		for k in 4:
			pj.after(0.08 * k, func():
				L.paste_drops(pj, o.lerp(end, 0.25 + k * 0.2), 3, 2.0, L.K_GOO, Vector3.DOWN, 0.6, 0.08, 1.2))
		pj.after(0.3, func():
			Combat.hit_zone(c, c.global_position, d, o.distance_to(end) + 1.5, 18.0, 2.5, pj.inf(c, "terumi_yoton_yokai", 1.8, {"knock": 8.0, "kind": "heavy", "element": "yoton", "burn": 5.0, "armor_break": 0.3}))))
	Sfx.play("water", c.global_position, 0.5)


## Hedefe yapışan çamur: göğüste topak, aşağı sarkan çamur ipleri, aşındıkça kararır, buhar tüter, sonra sinip söner
static func _goo_stick(pj: PathJutsu, tt: Node3D) -> void:
	var root = Node3D.new()
	tt.add_child(root)
	ClanJutsu.fit_body(tt, root)
	var parts = []
	for k in 3:
		var b = L.paste_blob(0.28, L.K_GOO, 0.35, {"bub": 0.5, "wob": 0.05, "near": Vector2(0.5, 1.4)})
		b.position = Vector3(randf_range(-0.25, 0.25), randf_range(0.9, 1.5), randf_range(-0.2, 0.2))
		b.scale = Vector3(0.3, 0.24, 0.3)
		root.add_child(b)
		parts.append(b)
		var pts = [b.position, b.position + Vector3(0.02, -0.35, 0.03), b.position + Vector3(-0.02, -0.75, 0.0)]
		var dr = L.paste_mi(L.tube_mesh(pts, [0.07, 0.05, 0.02], 6, 0.1, 0.0, 1.2), L.K_GOO, {"wob": 0.02, "near": Vector2(0.5, 1.4), "nscale": 2.0})
		root.add_child(dr)
		parts.append(dr)
		dr.scale = Vector3(1, 0.1, 1)
		dr.create_tween().tween_property(dr, "scale", Vector3.ONE, 0.8)
	for pc in parts:
		pc.create_tween().tween_method(L.pf(pc, "stress"), 0.0, 0.8, 2.2)
	var tw = root.create_tween()
	for i in 4:
		tw.tween_callback(func():
			if is_instance_valid(root) and root.is_inside_tree():
				L.vapor(pj, root.global_position + Vector3.UP * 1.3, 0.7, 1.0, Vector3(0, 1.2, 0), Color(0.96, 0.94, 0.86, 0.45)))
		tw.tween_interval(0.5)
	for pc in parts:
		tw.parallel().tween_method(L.pf(pc, "fade"), 1.0, 0.0, 0.4)
	tw.tween_callback(root.queue_free)


# ================================================================== Kazan
## Yanardağ: hedefin altında yer kızgın çatlaklarla yarılır, kabuk kayalarından küçük bir yanardağ höyüğü kabarır,
## tepesindeki lav ağzı kaynar; kalın lav sütunu fışkırır, kabuklu lav bombaları yay çizip çevreye düşer, höyük geri gömülür
static func kako_yoton_kazan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	L.crack_zone(at, 4.0, 6.0)
	L.cracks(pj, at, 4.0, 4.0, 1.1, 0.25, 2.8)
	var cone = Node3D.new()
	for k in 7:
		var a = k * TAU / 7.0 + randf() * 0.3
		var rk = L.lava_mi(L.blob_mesh(40 + k, 0.45, 6, 9), 0.2, 0.92, {"nscale": 2.0, "flow": 0.0, "wob": 0.0, "near": Vector2(1.5, 3.5)})
		rk.position = Vector3(cos(a) * 1.3, 0.5, sin(a) * 1.3)
		rk.scale = Vector3(0.75, 0.68, 0.62)
		rk.rotation.y = a
		cone.add_child(rk)
	for k in 4:
		var a2 = k * TAU / 4.0 + 0.4
		var rk2 = L.lava_mi(L.blob_mesh(50 + k, 0.45, 6, 9), 0.3, 0.85, {"nscale": 2.0, "flow": 0.0, "wob": 0.0, "near": Vector2(1.5, 3.5)})
		rk2.position = Vector3(cos(a2) * 0.72, 1.15, sin(a2) * 0.72)
		rk2.scale = Vector3(0.48, 0.45, 0.42)
		rk2.rotation.y = a2
		cone.add_child(rk2)
	var crater = L.lava_blob(1.0, 1.2, 0.18, 0.15, {"nscale": 3.0, "flow": 0.6, "wob": 0.08, "near": Vector2(1.5, 3.5)})
	crater.position = Vector3(0, 1.5, 0)
	crater.scale = Vector3(0.62, 0.2, 0.62)
	cone.add_child(crater)
	pj.get_tree().current_scene.add_child(cone)
	cone.global_position = at - Vector3.UP * 1.0
	var tw = cone.create_tween()
	tw.tween_property(cone, "global_position", at + Vector3.UP * 0.8, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func():
		_kazan_fountain(pj, at + Vector3.UP * 2.2)
		for k in 6:
			var q = at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			_kazan_bomb(pj, at + Vector3.UP * 2.5, q)
		pj.hit(c, at + Vector3.UP, 3.5, pj.inf(c, "kako_yoton_kazan", 1.6, {"knock": 6.0, "launch": 10.0, "kind": "heavy", "element": "yoton", "burn": 4.0}))
		pj.shake(0.6))
	tw.tween_interval(2.0)
	tw.tween_property(cone, "global_position", at - Vector3.UP * 1.0, 0.4)
	tw.tween_callback(cone.queue_free)
	Sfx.play("fire", at, 0.5)


## Lav ağzından fışkıran kalın sütun: hızla yükselir, tepeden ağır damla yağmuru, kendi ağırlığıyla geri çöker
static func _kazan_fountain(pj: PathJutsu, p: Vector3) -> void:
	var pts = []
	var rr = []
	for i in 7:
		var u = float(i) / 6.0
		pts.append(Vector3(sin(u * 5.0) * 0.12, u * 4.5, cos(u * 4.0) * 0.1))
		rr.append(0.42 * (1.0 - u * 0.55) * (1.0 + 0.2 * sin(u * 9.0)))
	var col = L.lava_mi(L.tube_mesh(pts, rr, 9, 0.25, randf() * 5.0, 1.0), 1.2, 0.2, {"nscale": 2.4, "flow": -2.4, "wob": 0.08, "near": Vector2(2.5, 6.0)})
	L.put(pj, col, p)
	col.scale = Vector3(1.0, 0.05, 1.0)
	var tw = col.create_tween()
	tw.tween_property(col, "scale", Vector3(1.0, 1.0, 1.0), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_property(col, "scale", Vector3(1.5, 0.05, 1.5), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(col.queue_free)
	col.create_tween().tween_method(L.pf(col, "heat"), 1.2, 0.5, 0.95)
	pj.after(0.18, func():
		L.lava_drops(pj, p + Vector3.UP * 4.3, 16, 7.0, Vector3.UP, 0.75, 0.12, 1.0, 2.4))
	L.glow(pj, p + Vector3.UP * 1.5, 4.0, HOT, 0.6)
	L.light(pj, p + Vector3.UP * 1.5, LAVA_LIGHT, 5.0, 12.0, 1.0)


## Kabuklu lav bombası: yay çizip düşer, yere ezilip küçük lav gölü bırakır
static func _kazan_bomb(pj: PathJutsu, p0: Vector3, q: Vector3) -> void:
	var rk = L.lava_blob(0.3, 1.0, 0.6, 0.4, {"nscale": 3.5, "wob": 0.04, "near": Vector2(0.8, 2.0)})
	L.put(pj, rk, p0)
	var dest = L.floor_at(q)
	var hgt = randf_range(1.5, 3.0)
	var tw = rk.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(rk):
			rk.global_position = p0.lerp(dest, u) + Vector3.UP * sin(u * PI) * hgt
			rk.rotation = Vector3(u * 7.0, u * 4.0, 0.0), 0.0, 1.0, 0.6)
	tw.tween_callback(func():
		L.lava_pool(pj, dest, 0.6, 2.5, 1.0)
		L.lava_drops(pj, dest + Vector3.UP * 0.2, 4, 3.0, Vector3.UP, 0.7, 0.07))
	tw.tween_callback(rk.queue_free)


# ================================================================== Yōgan Ken
## Lav Yumruğu: iki yumruk kaynayan lavla kaplanır; beş vuruşluk zincirde her yumruk ardında sarkan, damlayan bir lav yayı
## bırakır, isabet noktasında yumruk yönüne dik yapışkan lav lekesi açılır; son vuruşta yumrukla hedef arasında uzayıp kopan ipler
static func kako_yogan_ken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 8.0)
	var hands = []
	for side in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, side)
		if ba:
			ba.add_child(_lava_fist(0.13, 0.2))
			hands.append(ba)
			pj.free_after(1.2, ba)
	_drip_from(pj, hands, 1.2, 0.1)
	pj._jump_at(c, tt, 0.4, 8.0)
	for k in 5:
		pj.after(0.2 + k * 0.17, func():
			if not pj.live(c):
				return
			pj.anim(c, ["punch", "punch2", "cross", "jab", "cross"][k], 2.0)
			var at = c.global_position + Vector3.UP * 1.1 + c.face_dir() * 1.2
			_ken_hit(pj, c, at, k)
			_impact_marks(pj, at, 0.8 + k * 0.2)
			var info = pj.inf(c, "kako_yogan_ken", 0.5 + k * 0.15, {"knock": 3.0 + k * 3.0, "kind": "heavy", "element": "yoton", "burn": 2.0})
			_melee_marks(pj, pj.hit(c, at, 2.0, info), info))
	Sfx.play("fire", c.global_position, 1.0)


static func _ken_hit(pj: PathJutsu, c: Node3D, at: Vector3, k: int) -> void:
	var f = c.face_dir()
	var sd = L.side_of(f)
	var sgn = -1.0 if k % 2 == 0 else 1.0
	# yumruğun izlediği yay: yandan isabet noktasına sarkan lav şeridi (soğuyup düşer)
	var a = c.global_position + Vector3.UP * 1.25 + sd * sgn * 0.5 - f * 0.1
	var pts = []
	var rr = []
	for i in 7:
		var u = float(i) / 6.0
		pts.append(a.lerp(at, u) + sd * sgn * sin(u * PI) * 0.35 - f * sin(u * PI) * 0.1 - a)
		rr.append(0.05 + 0.07 * sin(u * PI * 0.9))
	var sw = L.lava_mi(L.tube_mesh(pts, rr, 6, 0.2, k * 1.3), 1.1, 0.25, {"nscale": 4.0, "flow": 1.5, "wob": 0.04, "near": Vector2(0.8, 2.0)})
	L.put(pj, sw, a)
	var tw = sw.create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(sw, "global_position", a + Vector3.DOWN * 0.6, 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(L.pf(sw, "fade"), 1.0, 0.0, 0.35)
	tw.tween_callback(sw.queue_free)
	sw.create_tween().tween_method(L.pf(sw, "heat"), 1.1, 0.35, 0.45)
	# isabette yumruğa dik açılan yapışkan lav lekesi
	var s = 0.6 + k * 0.15
	var sp = L.lava_blob(1.0, 1.1, 0.35, 0.5, {"nscale": 3.0, "wob": 0.06, "near": Vector2(1.0, 2.5)})
	L.put(pj, sp, at + f * 0.35)
	L.look(sp, f)
	var bs = sp.basis
	sp.basis = bs * Basis.from_scale(Vector3(0.1, 0.1, 0.04))
	var st = sp.create_tween()
	st.tween_method(func(u: float) -> void:
		if is_instance_valid(sp):
			sp.basis = bs * Basis.from_scale(Vector3(0.1 + 0.55 * s * u, 0.1 + 0.5 * s * u, 0.04 + 0.08 * u)), 0.0, 1.0, 0.12)
	st.tween_interval(0.12)
	st.tween_method(L.pf(sp, "fade"), 1.0, 0.0, 0.25)
	st.tween_callback(sp.queue_free)
	L.lava_drops(pj, at, 4 + k, 5.0, f + Vector3.UP * 0.4, 0.55, 0.07)
	if k >= 2:
		L.crust_rock(pj, at, f * 4.0 + Vector3.UP * 3.0 + sd * randf_range(-1.5, 1.5), 0.1)
	if k == 4:
		var hp = pj.hand_pos(c, true)
		for i in 3:
			L.strand(pj, hp + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0), at + f * 0.4 + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), 0), 0.045, 0.55,
				func(m: Mesh) -> MeshInstance3D:
					return L.lava_mi(m, 1.0, 0.1, {"nscale": 6.0, "wob": 0.0, "near": Vector2(0.6, 1.5)}))
		L.glow(pj, at, 2.2, HOT, 0.3)
		L.light(pj, at, LAVA_LIGHT, 3.0, 6.0, 0.4)


# ================================================================== Kansen
## Lav Fıskiyeleri: geniş alan boyunca yer, merkezden dışa doğru kızgın çatlak ağıyla yarılır; 4 sn boyunca çatlaklardan rastgele
## yerlerde ince, hızlı lav fıskiyeleri fışkırır (her birinin dibinde kızgın ağız, tepesinden ağır damla yağmuru, dipte küçük gölcük)
static func kako_yoton_kansen(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var at = pj.gp(Jutsu._aim_ground(c, t, 8.0, 20.0))
	L.crack_zone(at, 10.0, 6.0)
	L.cracks(pj, at, 8.0, 5.5, 1.1, 0.6, 2.0)
	L.glow(pj, at + Vector3.UP * 0.4, 6.0, Color(1.0, 0.5, 0.15, 0.5), 1.2)
	pj.every(4.0, 0.25, func(_i, _k):
		var q = at + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
		_geyser(pj, q, randf_range(3.0, 6.0))
		pj.hit(c, q + Vector3.UP, 1.8, pj.inf(c, "kako_yoton_kansen", 0.4, {"knock": 2.0, "launch": 6.0, "kind": "heavy", "element": "yoton", "burn": 3.0})), Callable())
	Sfx.play("fire", at, 0.5)


static func _geyser(pj: PathJutsu, q: Vector3, h: float) -> void:
	var g = L.floor_at(q)
	L.cracks(pj, g, 0.9, 1.6, 1.2, 0.08, 4.5)
	var pts = []
	var rr = []
	var ph = randf() * TAU
	for i in 6:
		var u = float(i) / 5.0
		pts.append(Vector3(sin(u * 6.0 + ph) * 0.06, u * h, cos(u * 5.0 + ph) * 0.06))
		rr.append(0.17 * (1.0 - u * 0.5))
	var col = L.lava_mi(L.tube_mesh(pts, rr, 7, 0.2, ph, 1.0), 1.2, 0.15, {"nscale": 3.0, "flow": -3.0, "wob": 0.05, "near": Vector2(1.5, 4.0)})
	L.put(pj, col, g)
	col.scale = Vector3(1.0, 0.05, 1.0)
	var tw = col.create_tween()
	tw.tween_property(col, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(col, "scale", Vector3(1.4, 0.05, 1.4), 0.32).set_ease(Tween.EASE_IN)
	tw.tween_callback(col.queue_free)
	pj.after(0.12, func():
		L.lava_drops(pj, g + Vector3.UP * h, 5, 4.0, Vector3.UP, 0.7, 0.08, 1.0, 1.8))
	L.lava_pool(pj, g, 0.5, 2.0, 1.0, 0.06)


# ================================================================== Gomu Heki
## Lastik Duvar (ref): ağızdan akan bej lastik yere dökülür, önünde esnek, kalın, parlak bir perde kabarır — tepesinde parmak gibi
## uzanan yuvarlak uçlu sarkıntılar, yerde yayılan taban; çarpan geri sekerken duvar esneyip içine göçer, sonra eriyip çöker
static func yoton_gomu_heki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 3.0)
	_rubber_pour(pj, pj._mouth_pos(c), at + Vector3.UP * 0.4)
	var wall = _rubber_wall()
	L.put(pj, wall, at)
	wall.look_at(at + d, Vector3.UP)
	wall.scale = Vector3(1, 0.05, 1)
	var tw = wall.create_tween()
	tw.tween_property(wall, "scale", Vector3(1, 1.08, 1), 0.3).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(wall, "scale", Vector3(1, 1, 1), 0.2)
	Buffs.add("gomu_heki", 6.0, {"armor": 0.35, "_name": "Lastik Duvar", "_desc": "önden gelen darbeler esner"})
	pj.every(6.0, 0.25, func(_i, _k):
		for e in pj.enemies_near(c, at, 2.2):
			var v = e.global_position - at
			v.y = 0
			e.velocity += v.normalized() * 10.0 + Vector3.UP * 3.0
			_wall_dent(wall))
	pj.after(6.0, func():
		if not is_instance_valid(wall):
			return
		var mw = wall.create_tween()
		mw.tween_property(wall, "scale", Vector3(1.15, 0.05, 1.15), 0.4).set_ease(Tween.EASE_IN)
		mw.tween_callback(wall.queue_free))
	L.kill(pj, 6.7, wall)   # atan bu arada ölürse duvar yerde kalmasın
	Sfx.play("water", c.global_position, 0.5)


static func _rubber_opts(ns: float) -> Dictionary:
	return {"stress": 0.7, "wob": 0.06, "nscale": ns, "near": Vector2(3.5, 6.5)}


static func _rubber_wall() -> Node3D:
	var root = Node3D.new()
	# gövde: iç içe geçmiş, eriyip akan kalın lastik kütleleri (yerel X genişlik, Y yukarı, -Z düşmana)
	for k in 9:
		var x = (k - 4) * 0.78 + randf_range(-0.12, 0.12)
		var b = L.paste_mi(L.blob_mesh(60 + k, 0.3), L.K_RUBBER, _rubber_opts(1.0))
		b.position = Vector3(x, 1.25 + sin(k * 1.7) * 0.15, randf_range(-0.08, 0.08))
		b.scale = Vector3(0.62, 1.35, 0.42)
		root.add_child(b)
	# tepede yuvarlak uçlu parmak sarkıntıları (ref)
	for k in 7:
		var x2 = (k - 3) * 0.95 + randf_range(-0.2, 0.2)
		var hh = randf_range(0.8, 1.5)
		var curl = randf_range(-0.35, 0.35)
		var pts = []
		var rr = []
		for i in 6:
			var u = float(i) / 5.0
			pts.append(Vector3(x2 + curl * u * u, 2.2 + hh * u, -0.12 * u))
			rr.append(lerpf(0.36, 0.2, u))
		var fg = L.paste_mi(L.tube_mesh(pts, rr, 8, 0.12, k * 1.1, 1.0), L.K_RUBBER, _rubber_opts(1.6))
		root.add_child(fg)
	# yanlarda alçak taşan loblar ve yerde yayılan taban
	for sx in [-1.0, 1.0]:
		var lb = L.paste_mi(L.blob_mesh(70 + int(sx + 1.0), 0.3), L.K_RUBBER, _rubber_opts(1.0))
		lb.position = Vector3(sx * 3.5, 0.75, 0.05)
		lb.scale = Vector3(0.75, 0.85, 0.5)
		root.add_child(lb)
	var base = L.paste_mi(L.blob_mesh(75, 0.25), L.K_RUBBER, _rubber_opts(2.5))
	base.position = Vector3(0, 0.1, 0.15)
	base.scale = Vector3(4.3, 0.3, 1.2)
	root.add_child(base)
	return root


## Duvar esnemesi: çarpan sekerken duvar içine göçüp lastik gibi geri fırlar
static func _wall_dent(wall: Node3D) -> void:
	if not is_instance_valid(wall) or wall.has_meta("dent"):
		return
	wall.set_meta("dent", true)
	var tw = wall.create_tween()
	tw.tween_property(wall, "scale", Vector3(1.04, 0.95, 0.75), 0.08)
	tw.tween_property(wall, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(wall):
			wall.remove_meta("dent"))


## Ağızdan dökülen lastik akıntısı: kalın halat ağızdan yere uzar, sonra incelip kopar
static func _rubber_pour(pj: PathJutsu, o: Vector3, to: Vector3) -> void:
	var mi = L.paste_mi(L.blob_mesh(0), L.K_RUBBER, {"stress": 0.5, "wob": 0.04, "nscale": 2.0, "near": Vector2(1.0, 2.5)})
	mi.mesh = null
	pj.get_tree().current_scene.add_child(mi)
	var tw = mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		var pts = []
		var rr = []
		for k in 8:
			var v = (k / 7.0) * minf(1.0, u * 1.6)
			pts.append(o.lerp(to, v) + Vector3.UP * sin(v * PI) * 0.5)
			rr.append((0.12 + v * 0.18) * (1.0 - maxf(0.0, u - 0.6) * 2.0))
		mi.mesh = L.tube_mesh(pts, rr, 8, 0.12, u * 2.0, 0.8), 0.0, 1.0, 0.45)
	tw.tween_callback(mi.queue_free)


# ================================================================== Gomudama
## Lastik Küre: ağızdan fırlayan lastik ip hedefe dolanır, hedefin çevresinde parlak bej lastik top şişer (tepede büzülmüş düğüm,
## gerilme çizgileri), top sıkışıp esneyerek zıplar; süre bitince patlar, lastik parçaları ve kopan ipler saçılır
static func yoton_gomudama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	_rubber_lasso(pj, c, tt)
	pj.after(0.35, func():
		if not pj.live(tt):
			return
		var ball = _rubber_ball()
		tt.add_child(ball)
		ClanJutsu.fit_body(tt, ball)
		ball.position = Vector3.UP * 1.0
		ball.scale = Vector3.ONE * 0.1
		var tw = ball.create_tween()
		tw.tween_property(ball, "scale", Vector3.ONE * 1.1, 0.25).set_trans(Tween.TRANS_ELASTIC)
		for k in 6:
			tw.tween_property(ball, "scale", Vector3(1.15, 0.95, 1.15), 0.25)
			tw.tween_property(ball, "scale", Vector3(0.95, 1.12, 0.95), 0.25)
		tw.tween_callback(func():
			_rubber_pop(pj, ball))
		tw.tween_callback(ball.queue_free)
		pj.st(tt, "bind", 3.0)
		tt.take_hit(pj.inf(c, "yoton_gomudama", 0.6, {"knock": 0.0, "kind": "heavy"})))
	Sfx.play("water", c.global_position, 0.6)


static func _rubber_ball() -> Node3D:
	var root = Node3D.new()
	var b = L.paste_mi(L.blob_mesh(80, 0.12, 12, 20), L.K_RUBBER, {"stress": 0.9, "wob": 0.07, "nscale": 1.2, "near": Vector2(1.5, 3.5)})
	b.scale = Vector3.ONE * 1.6
	root.add_child(b)
	# tepede büzülmüş düğüm (lastiğin kapandığı yer)
	var pts = [Vector3(0, 1.45, 0), Vector3(0.05, 1.7, 0.02), Vector3(-0.04, 1.85, 0.0), Vector3(0.02, 1.95, -0.03)]
	var knot = L.paste_mi(L.tube_mesh(pts, [0.3, 0.14, 0.12, 0.08], 8, 0.35, 1.0, 1.4), L.K_RUBBER, {"stress": 1.0, "wob": 0.02, "nscale": 3.0, "near": Vector2(1.5, 3.5)})
	root.add_child(knot)
	return root


static func _rubber_pop(pj: PathJutsu, ball: Node3D) -> void:
	if not is_instance_valid(ball) or not ball.is_inside_tree():
		return
	var p = ball.global_position
	for k in 8:
		var a = k * TAU / 8.0 + randf() * 0.4
		var shred = L.paste_blob(0.3, L.K_RUBBER, 0.5, {"stress": 1.0, "wob": 0.0, "near": Vector2(0.6, 1.6)})
		var v = Vector3(cos(a), randf_range(0.2, 1.0), sin(a)) * randf_range(5.0, 8.0)
		L.drop(pj, shred, p + Vector3(cos(a), 0.3, sin(a)) * 0.8, v, 0.3, 1.5, 18.0, Callable(), 0.6)
	for k in 4:
		var a2 = randf() * TAU
		L.strand(pj, p + Vector3(cos(a2), 0.5, sin(a2)) * 0.7, p + Vector3(cos(a2), 0.1, sin(a2)) * 2.2, 0.06, 0.3,
			func(m: Mesh) -> MeshInstance3D:
				return L.paste_mi(m, L.K_RUBBER, {"stress": 1.0, "wob": 0.0, "near": Vector2(0.6, 1.6), "nscale": 3.0}), 0.05)
	L.paste_drops(pj, p, 10, 5.0, L.K_RUBBER, Vector3.UP, 1.0, 0.08, 1.2)


## Ağızdan hedefe uzanan, gerilerek incelen lastik ip (0.35 sn bekleme boyunca görünür)
static func _rubber_lasso(pj: PathJutsu, c: Node3D, tt: Node3D) -> void:
	var mi = L.paste_mi(L.blob_mesh(0), L.K_RUBBER, {"stress": 1.0, "wob": 0.03, "nscale": 2.5, "near": Vector2(1.0, 2.5)})
	mi.mesh = null
	pj.get_tree().current_scene.add_child(mi)
	var tw = mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(mi) or not pj.live(c) or not pj.live(tt):
			return
		var o = pj._mouth_pos(c)
		var to = tt.global_position + Vector3.UP * 1.0
		var reach = minf(1.0, u * 2.2)
		var pts = []
		var rr = []
		for k in 8:
			var v = (k / 7.0) * reach
			pts.append(o.lerp(to, v) + Vector3.UP * sin(v * PI) * 0.4)
			rr.append(lerpf(0.1, 0.04, reach) * (1.0 + 0.5 * v))
		mi.mesh = L.tube_mesh(pts, rr, 6, 0.1, u * 2.0, 0.8), 0.0, 1.0, 0.38)
	tw.tween_callback(mi.queue_free)


# ================================================================== Gomu Kōsoku
## Lastik Yapışma: ağızdan üç esnek lastik damlası fırlar (ağızla arasında gerilip kopan ince lastik ip); hedefe yapışan damla
## şişer, gerilme çizgileri belirir, sonra patlayıp lastik parçaları saçarak iter
static func yoton_gomu_kosoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 18.0)
	pj.busy(c, 0.8)
	for k in 3:
		pj.after(0.2 + k * 0.1, func():
			if not pj.live(c):
				return
			var o = pj._mouth_pos(c)
			var blob = L.paste_blob(0.25, L.K_RUBBER, 0.25, {"stress": 0.3, "wob": 0.1, "nscale": 3.0, "near": Vector2(0.6, 1.5)})
			var pr = pj.shot(c, o, pj.aim_at(c, tt, o).rotated(Vector3.UP, (k - 1) * 0.08), 20.0, blob, pj.inf(c, "yoton_gomu_kosoku", 0.2, {"knock": 0.0, "kind": "light"}), tt, false, 1.5, func(pp, h):
				if h != null and pj.live(h):
					pj.st(h, "slow", 2.5)
					var gum = L.paste_blob(0.35, L.K_RUBBER, 0.3, {"stress": 0.0, "wob": 0.08, "nscale": 2.0, "near": Vector2(0.5, 1.4)})
					h.add_child(gum)
					gum.position = Vector3(randf_range(-0.3, 0.3), randf_range(0.5, 1.5), randf_range(-0.3, 0.3))
					gum.create_tween().tween_method(L.pf(gum, "stress"), 0.0, 1.0, 2.0)
					var tw = gum.create_tween()
					tw.tween_property(gum, "scale", Vector3.ONE * 0.35 * 2.2, 2.0)
					tw.tween_callback(func():
						if is_instance_valid(gum):
							_gum_pop(pj, gum)
							if pj.live(h):
								h.take_hit(pj.inf(c, "yoton_gomu_kosoku", 0.6, {"knock": 10.0, "launch": 3.0, "kind": "heavy"}))
							gum.queue_free())
				else:
					L.paste_drops(pj, pp, 5, 3.0, L.K_RUBBER, Vector3.UP, 0.8, 0.07, 1.0))
			_kosoku_string(pj, pr, o))
	Sfx.play("water", c.global_position, 0.8)


## Damla ile ağız arasında gerilip incelen, 0.22 sn sonra kopup geri çekilen lastik ip
static func _kosoku_string(pj: PathJutsu, pr: Node3D, o: Vector3) -> void:
	var mi = L.paste_mi(L.blob_mesh(0), L.K_RUBBER, {"stress": 1.0, "wob": 0.0, "nscale": 3.0, "near": Vector2(0.6, 1.5)})
	mi.mesh = null
	pj.get_tree().current_scene.add_child(mi)
	var tw = mi.create_tween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(mi):
			return
		if not is_instance_valid(pr) or not pr.is_inside_tree():
			mi.mesh = null
			return
		var e = pr.global_position
		var snap = maxf(0.0, (u - 0.7) / 0.3)
		var a = o.lerp(e, snap * 0.5)
		var b = e.lerp(o, snap * 0.5)
		var pts = []
		var rr = []
		for k in 5:
			var v = k / 4.0
			pts.append(a.lerp(b, v) + Vector3.DOWN * sin(v * PI) * 0.08)
			rr.append(0.035 * (1.0 - snap * 0.7) * (1.0 - 0.5 * sin(v * PI)))
		mi.mesh = L.tube_mesh(pts, rr, 5, 0.0, 0.0, 0.6), 0.0, 1.0, 0.3)
	tw.tween_callback(mi.queue_free)


static func _gum_pop(pj: PathJutsu, gum: Node3D) -> void:
	if not gum.is_inside_tree():
		return
	var p = gum.global_position
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.5
		var shred = L.paste_blob(0.15, L.K_RUBBER, 0.5, {"stress": 1.0, "wob": 0.0, "near": Vector2(0.4, 1.2)})
		L.drop(pj, shred, p, Vector3(cos(a), randf_range(0.3, 1.2), sin(a)) * randf_range(3.0, 6.0), 0.15, 1.2, 18.0, Callable(), 0.6)
	L.paste_drops(pj, p, 6, 4.0, L.K_RUBBER, Vector3.UP, 1.0, 0.06, 1.0)
