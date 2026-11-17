class_name JitonFXA
extends RefCounted
## Jiton grubu A: on üç mıknatıs tekniğinin görselleri (Sandaime Kazekage'nin demir kumu, Rasa'nın altın tozu, Shinki, mıknatıslı
## şuriken, Bilge Mıknatıs Rasengan). Malzeme ve yapı taşları JitonLib'den (kendi taneli gövde / kontur / şerit / zemin shader'ları,
## kendi parçacık dokuları); her tekniğin şekli, hareketi ve sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.


# ================================================================== küçük yardımcılar
## +Y ekseni dir yönünde, X sırt / yüzey düzleminde kalan taban
static func _basis_y(dir: Vector3) -> Basis:
	var y = dir.normalized()
	var ref = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x = ref.cross(y).normalized()
	var z = x.cross(y).normalized()
	return Basis(x, y, z)


## Bir düğüm ağacındaki tüm gövdelerin taneli dağılmasını (melt) ayarlayan fonksiyon
static func _melt_fn(root: Node) -> Callable:
	var list = []
	if root is MeshInstance3D:
		list.append(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		list.append(n)
	return func(v: float) -> void:
		for g in list:
			if is_instance_valid(g):
				g.set_instance_shader_parameter("melt", v)


## Sürekli akan parçacığı sec sn sonra durdurur, söndükten sonra siler
static func _stop(pj: PathJutsu, ps: GPUParticles3D, sec: float) -> void:
	var w = weakref(ps)
	pj.get_tree().create_timer(sec).timeout.connect(func():
		var x = w.get_ref()
		if x != null and is_instance_valid(x):
			x.emitting = false
			JitonLib.kill(pj, x.lifetime + 0.3, x))


## Kameraya dönen düz kart (yıldız / leke)
static func _face_cam(pj: PathJutsu, n: Node3D) -> void:
	var cp = JitonLib.cam_pos(pj)
	if cp.distance_to(n.global_position) > 0.1:
		n.look_at(cp, Vector3.UP if absf((cp - n.global_position).normalized().y) < 0.95 else Vector3.RIGHT)


## Taban → uç arası iki noktalı yay boyunca akış borusu (yerel), a'ya göre
static func _arc_pts(a: Vector3, b: Vector3, lift: float, sway: float, n := 9) -> Array:
	var mid = (a + b) * 0.5 + Vector3.UP * lift + JitonLib.side_of(b - a) * sway
	var pts = []
	for i in n:
		var u = float(i) / (n - 1)
		pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u) - a)
	return pts


## Demir kumu / altın tozu akış kolu: kökten uca akar (reach), sonra kuyruğu ucuna çekilir (tail) ve silinir
static func _flow_arm(pj: PathJutsu, a: Vector3, b: Vector3, r0: float, r1: float, lift: float, sway: float, t_in: float, hold: float, gold := false, sd := 0) -> MeshInstance3D:
	var pts = _arc_pts(a, b, lift, sway)
	var rad = []
	for i in pts.size():
		var u = float(i) / (pts.size() - 1)
		rad.append(lerpf(r0, r1, u) * (1.0 + 0.25 * sin(u * 9.0 + sd)))
	var mat = JitonLib.gold_mat(0.025, 2.5) if gold else JitonLib.iron_mat(0.025, 2.5)
	var arm = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 7, 0.3, sd), mat)
	JitonLib.put(pj, arm, a)
	JitonLib.grow_in(arm, t_in)
	var tw = arm.create_tween()
	tw.tween_interval(t_in + hold)
	tw.tween_method(JitonLib.pf(arm, "tail"), 0.0, 1.05, maxf(0.15, t_in * 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(arm.queue_free)
	return arm


# ================================================================== 1) Satetsu Shigure: demir kumu çisentisi
## Ref (Sandaime Kazekage): göğü kaplayan kara demir kumu kütlesinden çapraz kısa kara iğneler sağanak gibi iner.
## Kollardan göğe kıvrılan üç ince akış kolu yükselir → hedefin üstünde dönen yassı kara kütle + topak bulutu toplanır →
## 80 iğne yağar (bir kısmı yere saplanıp kalır) → yerde demir kumu serpintisi, kütle taneli dağılır.
static func satetsu_shigure(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var sky = at + Vector3.UP * 8.0
	var hp = pj.hand_pos(c, true)
	for k in 3:
		_flow_arm(pj, hp + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), sky + Vector3(randf_range(-1.5, 1.5), 0.4, randf_range(-1.5, 1.5)),
			0.1, 0.32, randf_range(2.5, 4.5), randf_range(-2.5, 2.5), 0.35, 0.1, false, k)
	# göğü kaplayan dönen yassı kütle (alttan bakınca bulut tabanı) + asılı topak bulutu
	var mass = JitonLib.gi(JitonLib.lump_mesh(1.0, 3, 0.32, 14, 6), JitonLib.iron_mat(0.05, 0.6))
	JitonLib.put(pj, mass, sky + Vector3.UP * 0.7)
	mass.scale = Vector3(0.3, 0.08, 0.3)
	var mt = mass.create_tween()
	mt.tween_interval(0.2)
	mt.tween_property(mass, "scale", Vector3(4.3, 0.85, 4.3), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	mass.create_tween().tween_property(mass, "rotation:y", 2.4, 2.4).as_relative()
	JitonLib.crumble(mass, 1.75, 0.65)
	JitonLib.cloud(pj, sky, 3.6, 60, 2.2)
	JitonLib.gather(pj, sky, 5.0, 90, 0.5)
	var needle = JitonLib.spike_mesh(1.4, 0.07, 4, 0.15, 1, 0.5)
	for k in 80:
		pj.after(0.4 + randf() * 1.0, func():
			var r = 1.2 if k % 2 == 0 else 3.5
			var base = tt.global_position if (tt and pj.live(tt) and k % 2 == 0) else at
			var q = Vector3(base.x, at.y + 8.0, base.z) + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
			var nd = Node3D.new()
			var mi = JitonLib.gi(needle, JitonLib.iron_mat(0.012))
			mi.rotation.x = -PI * 0.5   # +Y → -Z (mermi ileri ekseni)
			mi.position = Vector3(0, 0, 0.7)
			nd.add_child(mi)
			var stuck = k % 3 == 0
			pj.shot(c, q, (pj.gp(q) + Vector3.UP * 0.8 - q).normalized(), 36.0, nd, pj.inf(c, "satetsu_shigure", 0.08, {"knock": 0.4, "kind": "light", "element": "jiton", "poison": 1.0}), null, false, 0.5,
				func(pos, e):
					if stuck and e == null:
						_plant_needle(pj, pos, needle)))
	pj.after(0.6, func(): JitonLib.patch(pj, at, 4.6, 0, 4.2, 1.0))
	Sfx.play("earth", at, 1.4)


## Yere saplanan iğne: hafif eğik, yarısı gömülü; ufak tane sıçraması, sonra taneli dağılır
static func _plant_needle(pj: PathJutsu, pos: Vector3, mesh: Mesh) -> void:
	var mi = JitonLib.gi(mesh, JitonLib.iron_mat(0.012))
	var dirv = (Vector3.UP + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))).normalized()
	JitonLib.put(pj, mi, pos - dirv * 0.55)
	mi.global_basis = _basis_y(dirv)
	JitonLib.crumble(mi, randf_range(1.0, 1.8), 0.4)
	JitonLib.grains(pj, pos + Vector3.UP * 0.05, 8, {"dir": Vector3.UP, "spread": 70.0, "vmin": 1.5, "vmax": 3.5, "g": 12.0, "life": 0.45, "size": 0.06})


# ================================================================== 2) Satetsu Kesshū: demir kumu toplanma saldırısı
## Ref: taneli yüzeyli dev üçgen kara kütleler. Atanın kollarından iki kalın akış kolu göğe uzanır, orada taneler dönerek
## toplanır; ters (ucu aşağı) kristal piramit yukarıdan aşağı belirerek oluşur, kenarlarından dört yassı üçgen levha açılır;
## piramit dalıp ucuyla yere çakılır → dikenli darbe izi, serpinti, fırlayan topaklar; iki saniye saplı kalır, taneli dağılır.
static func satetsu_kesshu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var top = at + Vector3.UP * 12.0
	var root = Node3D.new()
	var py = JitonLib.gi(JitonLib.spike_mesh(2.5, 1.05, 4, 0.12, 5, 0.5), JitonLib.iron_mat(0.04, 0.3))
	py.rotation.x = PI
	py.position.y = 0.6
	root.add_child(py)
	JitonLib.grow_in(py, 0.5)
	for k in 4:
		var a = TAU * (k + 0.5) / 4.0 + randf_range(-0.2, 0.2)
		var slab = JitonLib.gi(JitonLib.blade_mesh(2.3, 1.5, 0.16, k, 0.12), JitonLib.iron_mat(0.035))
		var dv = Vector3(cos(a), randf_range(0.25, 0.6), sin(a))
		slab.transform = Transform3D(_basis_y(dv), Vector3(cos(a), 0, sin(a)) * 0.55 + Vector3.UP * 0.45)
		root.add_child(slab)
		JitonLib.grow_in(slab, 0.3, 0.2)
	JitonLib.put(pj, root, top)
	root.scale = Vector3.ONE * 0.1
	root.set_meta("big", 1.8)   # ref: dev dikenli demir kum yapısı
	root.rotation.y = randf() * TAU
	for sx in [true, false]:
		_flow_arm(pj, pj.hand_pos(c, sx), top + Vector3.UP * 0.5, 0.18, 0.5, 3.0, 2.0 if sx else -2.0, 0.4, 0.15, false, 3 if sx else 4)
	JitonLib.gather(pj, top, 4.5, 120, 0.55)
	var fall = JitonLib.grains(pj, Vector3.UP * 0.4, 50, {"loop": true, "parent": root, "r": 0.8, "dir": Vector3.DOWN, "spread": 25.0, "vmin": 1.0, "vmax": 3.0, "g": 6.0, "life": 0.5, "size": 0.08})
	_stop(pj, fall, 0.8)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.8, 0.5)
	tw.tween_property(root, "global_position", at + Vector3.UP * 3.4, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		pj.hit(c, at + Vector3.UP, 4.5, pj.inf(c, "satetsu_kesshu", 2.2, {"knock": 14.0, "kind": "heavy", "element": "jiton", "bleed": 3.0, "hitstop": 0.1}))
		pj.shake(1.0)
		JitonLib.patch(pj, at, 4.8, 2, 3.6, 0.12)
		JitonLib.patch(pj, at, 6.5, 0, 4.0, 0.35)
		JitonLib.shards(pj, at + Vector3.UP * 0.3, 10, 0.32, 9.0, false, 1.0, 1.1)
		JitonLib.grains(pj, at + Vector3.UP * 0.3, 170, {"dir": Vector3.UP, "spread": 80.0, "vmin": 5.0, "vmax": 12.0, "g": 14.0, "r": 1.2, "life": 0.9, "size": 0.1})
		JitonLib.grains(pj, at + Vector3.UP * 0.5, 26, {"kind": 1, "dir": Vector3.UP, "spread": 85.0, "vmin": 3.0, "vmax": 7.0, "g": 10.0, "r": 1.0, "life": 0.8, "size": 0.5}))
	tw.tween_interval(2.0)
	tw.tween_method(_melt_fn(root), 0.0, 1.0, 0.5)
	tw.tween_callback(root.queue_free)
	Sfx.play("earth", at, 0.6)


# ================================================================== 3) Jiton: Sakin Taisō: altın tozu dalgası
## Ref (Rasa): göğe yükselen, yüzeyi ışıltılı, tırtıklı kenarlı dev altın tozu dalgası. Hedefin önünde yerden altın toz kabarır,
## kıvrık tepeli dalga aşağıdan yukarı büyüyerek yükselir (tepesinden altın serpinti savrulur), sonra ileri devrilip hedefin
## üstüne çöker → altın tozu tabakası, ışıltı sağanağı, savrulan altın topaklar; çöken kütle bir buçuk saniye yatar, dağılır.
static func jiton_sakin_taiso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var d = pj.fwd(c, t)
	var piv = Node3D.new()
	# dalga hedefin ARKASINDA (atandan / kameradan uzak tarafta) yükselir ve atana doğru hedefin üstüne devrilir: kamerayı örtmez
	JitonLib.put(pj, piv, pj.gp(at + d * 3.0) - Vector3.UP * 0.2)
	piv.rotation.y = atan2(-d.x, -d.z)
	var prof = [Vector2(-1.0, -0.4), Vector2(-0.8, 1.3), Vector2(-0.5, 2.8), Vector2(0.0, 4.2), Vector2(0.8, 5.3), Vector2(1.9, 5.9),
		Vector2(2.9, 5.6), Vector2(3.4, 4.7), Vector2(3.2, 3.7), Vector2(2.7, 3.2)]
	var thick = [2.6, 2.4, 2.2, 1.9, 1.6, 1.3, 1.0, 0.75, 0.5, 0.3]
	var wave = JitonLib.gi(JitonLib.curl_mesh(9.0, prof, thick, 11, randi() % 9, 0.7), JitonLib.gold_mat(0.05, 1.2))
	wave.set_instance_shader_parameter("near_fade", 8.0)
	piv.add_child(wave)
	JitonLib.grow_in(wave, 0.5)
	var spray = JitonLib.grains(pj, Vector3(0, 5.9, 2.4), 120, {"loop": true, "parent": piv, "gold": true, "r": 2.5, "dir": Vector3(0, 0.6, 1.0), "spread": 35.0,
		"vmin": 2.0, "vmax": 5.0, "g": 6.0, "life": 0.9, "size": 0.12})
	_stop(pj, spray, 0.85)
	var glint = JitonLib.grains(pj, Vector3(0, 5.0, 2.4), 40, {"loop": true, "parent": piv, "gold": true, "kind": 2, "r": 3.0, "vmin": 0.2, "vmax": 1.0, "g": 0.0, "life": 0.5, "size": 0.25})
	_stop(pj, glint, 0.85)
	JitonLib.grains(pj, piv.global_position + Vector3.UP * 0.3, 140, {"gold": true, "r": 3.0, "dir": Vector3.UP, "spread": 25.0, "vmin": 4.0, "vmax": 9.0, "g": 6.0, "life": 0.7, "size": 0.12})
	piv.scale = Vector3(0.6, 0.25, 0.6)
	var tw = piv.create_tween()
	tw.tween_property(piv, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(piv, "rotation:x", deg_to_rad(72.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		pj.hit(c, at + Vector3.UP, 6.0, pj.inf(c, "jiton_sakin_taiso", 2.2, {"knock": 8.0, "kind": "heavy", "element": "jiton", "hitstop": 0.1}))
		pj.shake(1.0)
		JitonLib.patch(pj, at + d * 0.5, 7.0, 1, 3.4, 0.2)
		JitonLib.grains(pj, at + Vector3.UP * 0.5, 200, {"gold": true, "r": 3.5, "dir": Vector3.UP, "spread": 75.0, "vmin": 4.0, "vmax": 10.0, "g": 12.0, "life": 1.1, "size": 0.12})
		JitonLib.grains(pj, at + Vector3.UP * 1.0, 50, {"gold": true, "kind": 2, "r": 4.0, "dir": Vector3.UP, "spread": 90.0, "vmin": 1.0, "vmax": 4.0, "g": 1.0, "life": 0.9, "size": 0.3})
		JitonLib.shards(pj, at + Vector3.UP * 0.4, 9, 0.35, 8.0, true, 0.9, 1.1))
	tw.tween_method(_melt_fn(piv), 0.0, 1.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # çöken kütle yatarken dağılır
	tw.tween_callback(piv.queue_free)
	Sfx.play("earth", at, 0.5)


# ================================================================== 4) Jiton: Jakuhō no Sōjin: mıknatıslı şuriken
## Ref: ortası delikli yassı kare çelik plakalar sıra halinde, arkalarında ince açık iz. Fırlatışta elde manyetik akış
## halkaları açılır; beş plaka yelpaze halinde dönerek uçar, her biri soluk iz şeridi bırakır; sıyırdığı hedef mıknatıslanır
## (göğsünü saran dönen akış çizgileri, çevresinde kısa akış kıvrımları).
static func jiton_jakuho_no_sojin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "throw", 1.3)
	var tt = pj.tg(c, t, 30.0)
	var d = pj.fwd(c, tt)
	JitonLib.field_loops(pj, pj.hand_pos(c, true), d, 0.7, 4, 0.5, JitonLib.FIELD, 0.05)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var from = c.global_position + Vector3.UP * 1.3 + d * 0.8
		var aim = pj.aim_at(c, tt, from)
		JitonLib.field_loops(pj, from, aim, 1.1, 5, 0.4, JitonLib.FIELD, 0.06)
		for k in 5:
			var pr = pj.shot(c, from, aim.rotated(Vector3.UP, (k - 2) * 0.17), 30.0, _plate(1.3), pj.inf(c, "jiton_jakuho_no_sojin", 1.1, {"knock": 2.0, "kind": "light", "element": "jiton", "bleed": 2.0}), null, false, 2.4,
				func(_p, e):
					if pj.live(e):
						JitonLib.magnetize(pj, c, e, 10.0, "Mıknatıslandı!", 0))
			pr.spin = Vector3(0, 30.0, 0)
			pr.radius = 0.5
			JitonLib.trail(pj, pr, 2.7, 0.32, Color(0.86, 0.9, 1.0), 9)
			pr.on_tick = func(p, _dt):
				if p.homing != null:
					return
				for e in pj.enemies_near(c, p.global_position, 2.2):
					JitonLib.magnetize(pj, c, e, 10.0, "Mıknatıslandı!", 0)   # sıyırması bile yeter
					break
		Sfx.play("throw", from, 0.9))


## Yassı kare çelik plaka (XZ düzleminde, Y'ye dik döner), ortasında kara delik
static func _plate(s: float) -> Node3D:
	var h = Node3D.new()
	var pl = JitonLib.gi(JitonLib.star_mesh(2, 0.5, 0.5, 0.06, 3, 0.03), JitonLib.steel_mat(0.015))
	pl.rotation.x = PI * 0.5
	pl.scale = Vector3.ONE * s
	h.add_child(pl)
	var hole = JitonLib.gi(JitonLib.lump_mesh(0.5, 2, 0.05, 8, 4), JitonLib.iron_mat(0.0))
	hole.scale = Vector3(0.11, 0.05, 0.11) * s
	h.add_child(hole)
	return h


# ================================================================== 5) Satetsu no Mākingu: demir kumu işareti (Shinki)
## Ref: hedefin sırtına çarpıp dikenli kenarlı kara leke olarak yapışan demir kumu; havada kalın kara çizgiler.
## Avuçtan uzun kara iğ biçimli demir kumu fırlar (arkasından tane akar), hedefe güdümlenir; çarptığı yerde taneler
## yassı halka halinde sıçrar, göğüs ve sırtta dikenli kara leke kalır, mıknatıslı süre boyunca çevresinden taneler lekeye akar.
static func satetsu_no_makingu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 28.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("İşaretlenecek hedef yok", Color(1, 0.7, 0.5))
		return
	var from = pj.hand_pos(c, true)
	JitonLib.gather(pj, from, 0.8, 30, 0.2)
	var h = Node3D.new()
	var head = JitonLib.gi(JitonLib.lump_mesh(0.5, 4, 0.3, 8, 5), JitonLib.iron_mat(0.015, 3.0))
	head.scale = Vector3(0.32, 0.32, 0.42)
	h.add_child(head)
	var tl = JitonLib.gi(JitonLib.blade_mesh(2.2, 0.26, 0.16, 4, 0.2), JitonLib.iron_mat(0.012, 3.0))
	tl.rotation.x = PI * 0.5   # +Y → +Z: mermi arkası
	tl.position = Vector3(0, 0, 0.05)
	h.add_child(tl)
	var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 36.0, h, pj.inf(c, "satetsu_no_makingu", 0.3, {"knock": 0.5, "kind": "light", "element": "jiton"}), tt, false, 1.6,
		func(p, e):
			JitonLib.grains(pj, p, 26, {"dir": Vector3.UP, "spread": 90.0, "vmin": 3.0, "vmax": 6.0, "g": 4.0, "damp": 3.0, "life": 0.45, "size": 0.07})
			if pj.live(e):
				JitonLib.magnetize(pj, c, e, 15.0, "Demir kumu işareti", 1))
	pr.homing_turn = 6.0
	JitonLib.grains(pj, Vector3.ZERO, 40, {"loop": true, "parent": pr, "r": 0.12, "dir": Vector3.UP, "spread": 180.0, "vmin": 0.2, "vmax": 0.8, "g": 2.0, "life": 0.35, "size": 0.06})
	Sfx.play("throw", from, 1.2)


# ================================================================== 6) Jiton: Sakin Taisōsō: altın tozu imparatorluk cenaze töreni
## Ref (Rasa): hedefi içine alan, ışıltılar saçan altın piramit mezar. Hedefin çevresindeki on noktadan altın akış kolları
## kavis çizip tepede birleşir; altın piramit + dibinde yığılmış toz topakları yerden kabarır ve hedefi gömer; mezar içe sıkışır
## (taneler merkeze çekilir) → patlayan ışıltı sütunu, altın sağanağı, savrulan topaklar, yerde altın tabaka; ezik kütle yayvanlaşıp kaybolur.
static func jiton_sakin_taisoso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 28.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	for k in 10:
		pj.after(k * 0.035, func():
			var a = k * TAU / 10.0
			var q = at + Vector3(cos(a), 0, sin(a)) * 3.4
			_flow_arm(pj, q, at + Vector3.UP * 5.0, 0.32, 0.12, 1.5, randf_range(-0.8, 0.8), 0.25, 0.1, true, k))
	JitonLib.gather(pj, at + Vector3.UP * 2.5, 4.0, 110, 0.45, true)
	var mound = Node3D.new()
	var py = JitonLib.gi(JitonLib.spike_mesh(5.4, 4.0, 4, 0.08, 7, 0.55), JitonLib.gold_mat(0.05, 0.4))
	py.rotation.y = randf() * TAU
	mound.add_child(py)
	for k in 12:   # ref: dibinde yığılmış düzensiz altın tozu topakları
		var a = k * TAU / 12.0 + randf() * 0.4
		var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, k, 0.3, 9, 6), JitonLib.gold_mat(0.04, 0.2))
		var rr = randf_range(2.2, 3.4)
		lm.position = Vector3(cos(a) * rr, randf_range(0.0, 0.4), sin(a) * rr)
		lm.scale = Vector3(randf_range(0.9, 1.5), randf_range(0.6, 1.1), randf_range(0.9, 1.5))
		mound.add_child(lm)
	pj.scene_add(mound, at)
	mound.scale = Vector3(1.0, 0.02, 1.0)
	var tw = mound.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(mound, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(mound, "scale", Vector3(0.55, 0.8, 0.55), 0.1)
	tw.tween_interval(0.5)
	tw.tween_property(mound, "scale", Vector3(0.7, 0.02, 0.7), 0.5)
	tw.tween_callback(mound.queue_free)
	var sparkle = JitonLib.grains(pj, Vector3.UP * 2.0, 50, {"loop": true, "parent": mound, "gold": true, "kind": 2, "r": 3.0, "vmin": 0.3, "vmax": 1.2, "g": -1.0, "life": 0.6, "size": 0.3})
	_stop(pj, sparkle, 1.2)
	pj.after(0.45, func():
		for e in pj.enemies_near(c, at, 3.6):
			pj.st(e, "bind", 1.2)
		Sfx.play("earth", at, 0.7))
	pj.after(1.0, func():   # içe sıkışma: taneler merkeze çekilir
		JitonLib.grains(pj, at + Vector3.UP * 1.5, 120, {"gold": true, "shell": true, "r": 4.0, "vmin": 0.0, "vmax": 0.2, "g": 0.0, "radial": -38.0, "life": 0.22, "size": 0.12}))
	pj.after(1.2, func():
		pj.hit(c, at + Vector3.UP, 4.2, pj.inf(c, "jiton_sakin_taisoso", 3.4, {"knock": 6.0, "launch": 3.0, "kind": "heavy", "element": "jiton", "hitstop": 0.15, "pierce_guard": true}))
		JitonLib.grains(pj, at + Vector3.UP * 2.0, 220, {"gold": true, "r": 1.5, "dir": Vector3.UP, "spread": 70.0, "vmin": 6.0, "vmax": 15.0, "g": 12.0, "life": 1.2, "size": 0.13})
		JitonLib.grains(pj, at + Vector3.UP * 1.0, 60, {"gold": true, "kind": 2, "r": 0.8, "dir": Vector3.UP, "spread": 12.0, "vmin": 6.0, "vmax": 14.0, "g": 2.0, "life": 0.9, "size": 0.35})
		JitonLib.shards(pj, at + Vector3.UP * 1.0, 10, 0.4, 9.0, true, 1.1, 1.2)
		JitonLib.patch(pj, at, 6.5, 1, 4.0, 0.25)
		pj.shake(1.0)
		Sfx.play("boom", at, 0.6))
	Sfx.play("earth", c.global_position, 0.6)


# ================================================================== 7) Sakin Kaihōdama: altın tozu dünya düzeni küresi
## Ref (Rasa): altın tozu kütlesinden her yöne fışkıran, yassı uzun altın kıymıklar. Altın topak kütlesi dönerek uçar, ardında
## ışıltılı toz akar; çarptığı ya da söndüğü yerde merkez kabarır ve 24 yassı altın kıymık bir anda dışa fırlar, havada asılı kalır,
## sonra kökten kopup dağılır; yerde altın tabaka.
static func sakin_kaihodama(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 26.0)
	JitonLib.gather(pj, c.global_position + Vector3.UP * 1.4 + pj.fwd(c, tt) * 1.0, 2.0, 70, 0.3, true)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = c.global_position + Vector3.UP * 1.4 + pj.fwd(c, tt) * 1.0
		var h = Node3D.new()
		var core = JitonLib.gi(JitonLib.lump_mesh(1.0, 6, 0.22, 12, 8), JitonLib.gold_mat(0.03, 1.5))
		core.scale = Vector3.ONE * 0.78
		h.add_child(core)
		for k in 6:
			var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 20 + k, 0.35, 7, 5), JitonLib.gold_mat(0.02))
			lm.position = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			lm.scale = Vector3.ONE * randf_range(0.3, 0.45)
			h.add_child(lm)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 21.0, h, pj.inf(c, "sakin_kaihodama", 0.6, {"knock": 3.0, "kind": "heavy", "element": "jiton"}), tt, false, 1.5)
		pr.radius = 0.8
		pr.spin = Vector3(3.0, 5.0, 0)
		JitonLib.grains(pj, Vector3.ZERO, 70, {"loop": true, "parent": pr, "gold": true, "r": 0.7, "spread": 180.0, "vmin": 0.2, "vmax": 1.0, "g": 3.0, "life": 0.5, "size": 0.1})
		JitonLib.grains(pj, Vector3.ZERO, 20, {"loop": true, "parent": pr, "gold": true, "kind": 2, "r": 0.8, "spread": 180.0, "vmin": 0.1, "vmax": 0.5, "g": 0.0, "life": 0.35, "size": 0.22})
		pr.tree_exiting.connect(func():
			var p = pr.global_position
			var fn = func(): _world_ball_burst(pj, c, p)
			fn.call_deferred()))
	Sfx.play("earth", c.global_position, 1.0)


static func _world_ball_burst(pj: PathJutsu, c: Node3D, p: Vector3) -> void:
	var bl = JitonLib.blade_mesh(5.5, 0.62, 0.07, 2, 0.25)
	for k in 24:
		var dir = Vector3(randf_range(-1, 1), randf_range(-0.15, 0.9), randf_range(-1, 1)).normalized()
		var L = randf_range(4.0, 7.5)
		var sh = JitonLib.gi(bl, JitonLib.gold_mat(0.03))
		JitonLib.put(pj, sh, p)
		sh.global_basis = _basis_y(dir).rotated(dir, randf() * TAU) * Basis.from_scale(Vector3(randf_range(0.8, 1.3), L / 5.5, 1.0))
		JitonLib.grow_in(sh, 0.1)
		var tw = sh.create_tween()
		tw.tween_interval(0.1 + 0.9)
		tw.tween_method(JitonLib.pf(sh, "tail"), 0.0, 1.05, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(sh.queue_free)
	var bulge = JitonLib.gi(JitonLib.lump_mesh(1.0, 13, 0.3, 10, 7), JitonLib.gold_mat(0.04))
	JitonLib.put(pj, bulge, p)
	bulge.scale = Vector3.ONE * 0.6
	var bt = bulge.create_tween()
	bt.tween_property(bulge, "scale", Vector3.ONE * 1.5, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_interval(0.7)
	bt.tween_method(JitonLib.pf(bulge, "melt"), 0.0, 1.0, 0.4)
	bt.tween_callback(bulge.queue_free)
	JitonLib.grains(pj, p, 180, {"gold": true, "r": 0.8, "spread": 180.0, "vmin": 5.0, "vmax": 13.0, "g": 8.0, "damp": 2.0, "life": 1.0, "size": 0.11})
	JitonLib.grains(pj, p, 40, {"gold": true, "kind": 2, "r": 2.0, "spread": 180.0, "vmin": 1.0, "vmax": 5.0, "g": 0.0, "life": 0.8, "size": 0.3})
	JitonLib.patch(pj, p, 5.0, 1, 3.5, 0.3)
	if pj.live(c):
		pj.hit(c, p, 5.6, pj.inf(c, "sakin_kaihodama", 2.1, {"knock": 10.0, "kind": "heavy", "element": "jiton", "bleed": 4.0, "hitstop": 0.1}))
	pj.shake(0.7)
	Sfx.play("clink", p, 0.6)


# ================================================================== 8) Kurogane no Kobushi: kara demir yumruk (Shinki)
## Ref: atanın iki yanında havada duran, pürüzlü kenarlı, taneli dev kara eller; ellerle atan arasında mavi-beyaz manyetik
## arklar. İki el kumdan kabarıp açılır; sağ el yumruk olup hedefe iner (dikenli darbe izi, serpinti, fırlayan topaklar),
## sol el önünde kalkan olur, gelen fırlatılanları tanelere çevirerek yutar; bitince el taneli dağılır.
static func kurogane_no_kobushi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 28.0)
	var d = pj.fwd(c, tt)
	var side = d.cross(Vector3.UP)
	var hands = []
	for sx in [-1.0, 1.0]:
		var h = _hand(2.0, sx)
		# atanın iki yanında, biraz önünde ve yukarıda: kameranın önüne girmez
		pj.scene_add(h, pj.gp(c.global_position + side * sx * 3.0 + d * 1.5) + Vector3.UP * 3.6)
		JitonLib.near_fade(h, 8.0)
		h.global_basis = Basis((-d).cross(Vector3.UP), -d, Vector3.UP)   # parmaklar yukarı, avuç ileri
		h.scale = Vector3.ONE * 0.05
		h.create_tween().tween_property(h, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		JitonLib.grains(pj, h.global_position, 90, {"r": 1.2, "spread": 180.0, "vmin": 2.0, "vmax": 6.0, "g": 6.0, "life": 0.6, "size": 0.1})
		JitonLib.grains(pj, h.global_position, 16, {"kind": 1, "r": 1.0, "spread": 180.0, "vmin": 1.5, "vmax": 4.0, "g": 4.0, "life": 0.5, "size": 0.5})
		hands.append(h)
	pj.every(1.0, 0.07, func(_i, _k):
		for h in hands:
			if is_instance_valid(h) and pj.live(c) and randf() < 0.7:
				JitonLib.arc(pj, c.global_position + Vector3.UP * 1.2, h.global_position + Vector3(randf_range(-0.6, 0.6), randf_range(-0.8, 0.8), randf_range(-0.6, 0.6)), 0.13, 0.12), Callable())
	# sağ el: yumruk olur, hedefe iner
	var fist: Node3D = hands[1]
	pj.after(0.45, func():
		if not is_instance_valid(fist):
			return
		var P = (tt.global_position if pj.live(tt) else pj.gp(c.global_position + d * 12.0)) + Vector3.UP * 1.3
		var dd = (P - fist.global_position).normalized()
		var sd2 = Vector3.UP.cross(dd).normalized()
		fist.global_basis = Basis(sd2, dd.cross(sd2), dd)   # parmak kökleri öne
		var trail = JitonLib.grains(pj, Vector3.ZERO, 60, {"loop": true, "parent": fist, "r": 1.0, "spread": 180.0, "vmin": 0.2, "vmax": 1.0, "g": 3.0, "life": 0.4, "size": 0.1})
		_stop(pj, trail, 0.4)
		var tw = fist.create_tween()
		tw.tween_method(func(k: float): _curl(fist, k), 0.25, 1.5, 0.12)
		tw.tween_property(fist, "global_position", P - dd * 2.4, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			pj.hit(c, P, 4.4, pj.inf(c, "kurogane_no_kobushi", 3.6, {"knock": 18.0, "kind": "heavy", "element": "jiton", "hitstop": 0.14}))
			var g0 = pj.gp(P)
			JitonLib.patch(pj, g0, 4.5, 2, 3.4, 0.12)
			JitonLib.patch(pj, g0, 6.0, 0, 3.8, 0.3)
			JitonLib.shards(pj, P - Vector3.UP * 0.6, 10, 0.3, 9.0, false, 0.9, 1.0)
			JitonLib.grains(pj, P, 160, {"r": 1.4, "spread": 180.0, "vmin": 5.0, "vmax": 12.0, "g": 12.0, "life": 0.9, "size": 0.1})
			JitonLib.field_loops(pj, P, dd, 2.4, 6, 0.4, JitonLib.FIELD, 0.09)
			pj.shake(0.9)
			Sfx.play("boom", P, 0.7))
		tw.tween_interval(0.35)
		tw.tween_method(_melt_fn(fist), 0.0, 1.0, 0.25)
		tw.tween_callback(fist.queue_free))
	# sol el: önünde kalkan (3 sn) — gelen fırlatılanları durdurur
	var guard: Node3D = hands[0]
	var g_tick = func(_i, _k):
		if not is_instance_valid(guard) or not pj.live(c):
			return
		var gp0 = c.global_position + c.face_dir() * 2.4 + Vector3.UP * 0.9
		guard.global_position = guard.global_position.lerp(gp0, 0.3)
		var fd = c.face_dir()
		guard.global_basis = Basis((-fd).cross(Vector3.UP), -fd, Vector3.UP).scaled(guard.scale)
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c and p.global_position.distance_to(guard.global_position + Vector3.UP * 2.2) < 3.4:
				JitonLib.grains(pj, p.global_position, 18, {"r": 0.3, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "g": 8.0, "life": 0.5, "size": 0.08})
				p.queue_free()
	var g_done = func():
		if is_instance_valid(guard):
			JitonLib.grains(pj, guard.global_position + Vector3.UP * 1.5, 80, {"r": 1.4, "dir": Vector3.DOWN, "spread": 50.0, "vmin": 0.5, "vmax": 2.0, "g": 9.0, "life": 0.8, "size": 0.1})
			var gt = guard.create_tween()
			gt.tween_method(_melt_fn(guard), 0.0, 1.0, 0.3)
			gt.tween_callback(guard.queue_free)
	pj.after(0.4, func(): pj.every(3.0, 1.0 / 30.0, g_tick, g_done))
	Sfx.play("earth", c.global_position, 0.8)


## Pürüzlü dev demir kumu eli: avuç +Z boyunca, parmaklar +Z'ye uzanır (eklemler X etrafında bükülür), bilekte sarkan tırtıklar
static func _hand(s: float, sx: float) -> Node3D:
	var root = Node3D.new()
	var m = JitonLib.iron_mat(0.05, 0.3)
	var mf = JitonLib.iron_mat(0.035, 0.3)
	var palm = JitonLib.gi(JitonLib.tube_mesh([Vector3(0, 0, -0.35) * s, Vector3(0, 0, 0.0), Vector3(0, 0, 0.55) * s, Vector3(0, 0, 1.02) * s],
		[0.3 * s, 0.42 * s, 0.56 * s, 0.52 * s], 9, 0.12, int(sx + 3.0)), m)
	palm.scale = Vector3(1.0, 0.48, 1.0)
	root.add_child(palm)
	var joints = []
	for k in 4:
		var kn = Node3D.new()
		kn.position = Vector3((k - 1.5) * 0.25, 0, 1.0) * s
		var ln = 0.5 if k in [1, 2] else 0.42
		kn.add_child(JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 0, ln * 0.5) * s, Vector3(0, 0, ln) * s], [0.125 * s, 0.13 * s, 0.115 * s], 7, 0.15, k), mf))
		var mid = Node3D.new()
		mid.position = Vector3(0, 0, ln) * s
		mid.add_child(JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 0, ln * 0.85) * s, Vector3(0, 0, ln * 0.95) * s], [0.115 * s, 0.095 * s, 0.05 * s], 7, 0.15, k + 5), mf))
		kn.add_child(mid)
		root.add_child(kn)
		joints.append([kn, mid])
	var th = Node3D.new()
	th.position = Vector3(sx * 0.5, 0, 0.25) * s
	th.rotation.y = sx * 0.95
	th.add_child(JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 0, 0.4) * s, Vector3(0, 0, 0.72) * s, Vector3(0, 0, 0.8) * s], [0.15 * s, 0.13 * s, 0.1 * s, 0.04 * s], 7, 0.15, 9), mf))
	root.add_child(th)
	for k in 4:   # ref: bilekte yırtık, sarkan tırtıklar
		var dr = JitonLib.gi(JitonLib.spike_mesh(1.0, 0.5, 4, 0.3, 30 + k, 0.4), mf)
		dr.transform = Transform3D(_basis_y(Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.2), -1.0)) * Basis.from_scale(Vector3.ONE * s * randf_range(0.22, 0.34)),
			Vector3((k - 1.5) * 0.18, 0, -0.3) * s)
		root.add_child(dr)
	root.set_meta("joints", joints)
	root.set_meta("thumb", th)
	_curl(root, 0.25)
	return root


static func _curl(hand: Node3D, k: float) -> void:
	if not is_instance_valid(hand):
		return
	for j in hand.get_meta("joints"):
		j[0].rotation.x = k
		j[1].rotation.x = k * 1.1
	var th: Node3D = hand.get_meta("thumb")
	th.rotation.x = k * 0.5


# ================================================================== 9) Satetsu Renzan: demir kumu sıradağı
## Ref: kara, keskin üçgen tepeler. Önünde yerden tepe tepe kara sıradağ kaması yükselir (gelen mermileri tanelere çevirip
## yutar), ardından yüzünden ileri doğru ortası uzun kenarları kısa kristal dikenler fırlar; yerde serpinti.
static func satetsu_renzan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	var at = pj.gp(c.global_position + d * 2.6)
	var wall = JitonLib.gi(JitonLib.ridge_mesh(6.0, 4.2, 1.6, 4, randi() % 7), JitonLib.iron_mat(0.05, 0.2))
	pj.scene_add(wall, at)
	wall.look_at(at + d, Vector3.UP)
	wall.scale = Vector3(1, 0.02, 1)
	var tw = wall.create_tween()
	tw.tween_property(wall, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(wall, "scale", Vector3(1, 0.02, 1), 0.4)
	tw.tween_callback(wall.queue_free)
	JitonLib.patch(pj, at, 4.0, 0, 3.8, 0.2)
	JitonLib.grains(pj, at + Vector3.UP * 0.5, 120, {"r": 2.5, "dir": Vector3.UP, "spread": 30.0, "vmin": 4.0, "vmax": 9.0, "g": 14.0, "life": 0.7, "size": 0.1})
	pj.every(3.2, 0.1, func(_i, _k):
		if not is_instance_valid(wall):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c and absf((p.global_position - at).dot(d)) < 1.0 and absf((p.global_position - at).dot(side)) < 3.2 and p.global_position.y < at.y + 4.0:
				JitonLib.grains(pj, p.global_position, 16, {"r": 0.3, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "g": 9.0, "life": 0.5, "size": 0.08})
				p.queue_free(), Callable())
	pj.after(0.4, func():
		if not pj.live(c):
			return
		for k in 11:   # sıradağ: ortası uzun, kenarları kısa, aralarında düzensiz boylar
			var x = (k - 5) * 0.55
			var L = (8.5 - absf(k - 5) * 0.9) * randf_range(0.55, 1.0)
			_thrust(pj, at + side * x + d * 0.3 + Vector3.UP * randf_range(0.5, 2.4), (d + side * x * 0.05 + Vector3.UP * randf_range(-0.06, 0.12)).normalized(), L, 0.2 + L * 0.02, 0.8, k)
		Combat.hit_zone(c, at + Vector3.UP * 0.2, d, 9.0, 32.0, 3.2, pj.inf(c, "satetsu_renzan", 3.4, {"knock": 14.0, "kind": "heavy", "element": "jiton", "bleed": 4.0, "hitstop": 0.1}))
		pj.shake(0.7)
		Sfx.play("clink", at, 0.6))
	Sfx.play("earth", at, 0.8)


## İleri fırlayan kristal diken: kökten uca uzar, durur, taneli dağılır
static func _thrust(pj: PathJutsu, p: Vector3, dir: Vector3, L: float, r: float, life: float, sd: int) -> void:
	var sp = JitonLib.gi(JitonLib.spike_mesh(1.0, 1.0, 4, 0.2, sd % 5, 0.5), JitonLib.iron_mat(0.035))
	JitonLib.put(pj, sp, p)
	sp.global_basis = _basis_y(dir).rotated(dir, randf() * TAU) * Basis.from_scale(Vector3(r * 1.2, L, r * 1.2))
	JitonLib.grow_in(sp, 0.14)
	JitonLib.crumble(sp, 0.14 + life, 0.3)


# ================================================================== 10) Satetsu Sōsō: demir kumu cenazesi
## Ref: hedefi saran, her yöne dikenler savuran kara yıldız patlaması. Hedefin altından burgu gibi akan kara sütun yükselip
## onu kaldırır, kalçasını kara topaklar kavrar; dört bir yandan ince iğneler saplanır; sonunda üst üste dönen kara dikenli
## yıldızlar patlar, taneler ve topaklar savrulur, yerde dikenli iz.
static func satetsu_soso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.5)
	var tt = pj.tg(c, t, 18.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Demir kumunun kavrayacağı hedef yok", Color(1, 0.7, 0.5))
		return
	# hedefin altından yükselen demir kumu sütunu (onu yukarı taşır)
	var col_m = JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 0.35, 0), Vector3(0, 0.7, 0), Vector3(0, 1.0, 0)], [1.0, 0.7, 0.5, 0.4], 9, 0.25, 3), JitonLib.iron_mat(0.04, 3.0))
	pj.scene_add(col_m, pj.gp(tt.global_position))
	col_m.scale = Vector3(1, 0.05, 1)
	pj.free_after(1.85, col_m)
	JitonLib.patch(pj, tt.global_position, 2.8, 0, 2.6, 0.2)
	pj.st(tt, "bind", 2.0)
	var base_y = pj.gp(tt.global_position).y
	var grip = pj.bone_attach(tt, "Hips")
	if grip:
		for k in 8:
			var a = k * TAU / 8.0
			var lm = JitonLib.gi(JitonLib.lump_mesh(0.5, k, 0.3, 7, 5), JitonLib.iron_mat(0.015))
			lm.position = Vector3(cos(a) * 0.3, randf_range(-0.15, 0.25), sin(a) * 0.3)
			lm.scale = Vector3.ONE * randf_range(0.6, 0.9)
			grip.add_child(lm)
		pj.free_after(1.9, grip)
	pj.every(1.8, 1.0 / 40.0, func(_i, k):
		if pj.live(tt):
			var p = tt.global_position
			p.y = base_y + 3.4 * minf(1.0, k * 4.0)
			tt.global_position = p
			if is_instance_valid(col_m):
				var hgt = maxf(0.1, p.y - base_y + 0.7)
				col_m.scale = Vector3(1, hgt, 1)
				col_m.global_position = Vector3(p.x, base_y, p.z)
				if randf() < 0.25:
					JitonLib.grains(pj, Vector3(p.x, base_y + 0.2, p.z), 8, {"r": 0.8, "dir": Vector3.UP, "spread": 40.0, "vmin": 1.5, "vmax": 4.0, "g": 8.0, "life": 0.5, "size": 0.08}), Callable())
	var nd = JitonLib.spike_mesh(1.0, 0.5, 4, 0.15, 2, 0.5)
	for k in 8:
		pj.after(0.55 + k * 0.13, func():
			if not pj.live(tt) or not pj.live(c):
				return
			var o = tt.global_position + Vector3.UP * 1.0
			var dir = Vector3(randf_range(-1, 1), randf_range(-0.4, 0.6), randf_range(-1, 1)).normalized()
			var sp = JitonLib.gi(nd, JitonLib.iron_mat(0.012))
			JitonLib.put(pj, sp, o + dir * 3.2)
			sp.global_basis = _basis_y(-dir) * Basis.from_scale(Vector3(0.16, 2.9, 0.16))
			JitonLib.grow_in(sp, 0.08)
			JitonLib.crumble(sp, 0.33, 0.2)
			JitonLib.grains(pj, o + dir * 0.4, 10, {"r": 0.15, "dir": dir, "spread": 30.0, "vmin": 2.0, "vmax": 4.0, "g": 6.0, "life": 0.35, "size": 0.06})
			tt.take_hit(pj.inf(c, "satetsu_soso", 0.24, {"knock": 0.0, "kind": "light", "element": "jiton", "bleed": 1.5}))
			Sfx.play("clink", o, 1.2))
	pj.after(1.8, func():
		if not is_instance_valid(tt):
			return
		var o = tt.global_position + Vector3.UP * 1.0
		for k in 3:   # ref: üst üste dönen kara dikenli yıldızlar
			var st = JitonLib.gi(JitonLib.star_mesh(9 + k * 2, 0.45, 2.0 - k * 0.35, 0.3, k, 0.45), JitonLib.iron_mat(0.04))
			JitonLib.put(pj, st, o)
			_face_cam(pj, st)
			st.rotate_object_local(Vector3.BACK, randf() * TAU)
			st.scale = Vector3.ONE * 0.2
			var tw = st.create_tween()
			tw.tween_property(st, "scale", Vector3.ONE * (1.0 + k * 0.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			st.create_tween().tween_property(st, "rotation:z", (0.6 if k % 2 == 0 else -0.6), 0.75).as_relative()
			JitonLib.crumble(st, 0.35, 0.4)
		JitonLib.grains(pj, o, 170, {"r": 0.6, "spread": 180.0, "vmin": 6.0, "vmax": 14.0, "g": 10.0, "damp": 1.5, "life": 0.9, "size": 0.1})
		JitonLib.shards(pj, o, 8, 0.28, 8.0, false, 0.6, 1.0)
		JitonLib.patch(pj, o, 3.5, 2, 3.0, 0.15)
		if pj.live(c):
			pj.hit(c, o, 3.6, pj.inf(c, "satetsu_soso", 1.5, {"knock": 16.0, "launch": 4.0, "kind": "heavy", "element": "jiton", "hitstop": 0.12}))
		pj.shake(0.8)
		Sfx.play("boom", o, 0.8))
	Sfx.play("earth", c.global_position, 0.9)


# ================================================================== 11) Senpō: Jiton Rasengan: bilge mıknatıs Rasengan
## Ref (Naruto, Altı Yol): avuçta dönen mavi Rasengan, yüzeyinde kara mühür işaretleri (nokta + kanca), çevresinde ışınsal çizgiler;
## arkada kara küreler. Çarpınca mühür yazısı bantları çevredeki düşmanlardan merkeze akar, hepsi merkeze çekilip birbirine yapışır.
static func senpo_jiton_rasengan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 10.0)
	pj.busy(c, 1.1)
	var hp = pj.hand_pos(c, true)
	JitonLib.gather(pj, hp, 1.4, 50, 0.45)
	JitonLib.field_loops(pj, hp, Vector3.UP, 0.9, 5, 0.6, JitonLib.FIELD, 0.05)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var orb = Node3D.new()
		ba.add_child(orb)
		orb.position = Vector3(0, 0.1, 0.05)
		var core = JitonLib.gi(_sphere(), JitonLib.rasen_mat())
		core.set_instance_shader_parameter("marks", 1.0)
		core.scale = Vector3.ONE * 0.05
		core.create_tween().tween_property(core, "scale", Vector3.ONE * 0.62, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		orb.add_child(core)
		var halo = JitonLib.gi(_quad(), JitonLib.halo_mat())
		halo.scale = Vector3.ONE * 0.95
		orb.add_child(halo)
		# ref: çevresinde dönen kara küreler
		var ring = Node3D.new()
		orb.add_child(ring)
		for k in 5:
			var o = JitonLib.gi(JitonLib.lump_mesh(0.5, 40 + k, 0.06, 10, 7), JitonLib.iron_mat(0.01))
			o.scale = Vector3.ONE * 0.22
			var a = k * TAU / 5.0
			o.position = Vector3(cos(a) * 0.62, sin(a * 2.0) * 0.12, sin(a) * 0.62)
			ring.add_child(o)
		ring.create_tween().tween_property(ring, "rotation:y", TAU * 3.0, 1.0)
		pj.free_after(1.0, ba)
	pj.after(0.45, func():
		if not pj.live(c):
			return
		var d = pj._jump_at(c, tt, 0.8, 10.0)
		pj.after(0.18, func():
			if not pj.live(c):
				return
			var at = c.global_position + Vector3.UP * 1.1 + d * 1.3
			_seal_burst(pj, at)
			for e in pj.enemies_near(c, at, 12.0):
				var tw = e.create_tween()
				tw.tween_property(e, "global_position", pj.gp(at + (e.global_position - at).normalized() * 0.8), 0.3)
				pj.st(e, "bind", 1.6)
				var a0 = e.global_position + Vector3.UP
				var pts = []
				for s in 10:
					var u = s / 9.0
					pts.append(a0.lerp(at, u) + Vector3.UP * sin(u * PI) * 0.8)
				JitonLib.ribbon(pj, pts, 0.55, Color(0.2, 0.22, 0.45), 1.0, 0.65, {"reps": maxf(3.0, a0.distance_to(at) / 0.6), "speed": 3.0})
			pj.hit(c, at, 3.0, pj.inf(c, "senpo_jiton_rasengan", 2.4, {"knock": 6.0, "kind": "heavy", "element": "jiton", "hitstop": 0.1}))))
	Sfx.play("wind", c.global_position, 1.0)


## Çarpma: mühürlü küre bir an büyüyüp çekim merkezine çöker; dikey mühür yazısı sütunu, akış halkaları
static func _seal_burst(pj: PathJutsu, at: Vector3) -> void:
	var sp = JitonLib.gi(_sphere(), JitonLib.rasen_mat())
	JitonLib.put(pj, sp, at)
	sp.scale = Vector3.ONE * 0.6
	var tw = sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE * 3.2, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(sp, "scale", Vector3.ONE * 0.1, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(sp.queue_free)
	var hl = JitonLib.gi(_quad(), JitonLib.halo_mat())
	JitonLib.put(pj, hl, at)
	hl.scale = Vector3.ONE * 1.0
	var ht = hl.create_tween()
	ht.tween_property(hl, "scale", Vector3.ONE * 5.5, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ht.tween_method(JitonLib.pf(hl, "fade"), 0.0, 1.0, 0.35)
	ht.tween_callback(hl.queue_free)
	for k in 2:   # ref (mühürleme): dikey sütun halinde akan mühür işaretleri
		var x = (k - 0.5) * 0.9
		var sd = JitonLib.side_of(JitonLib.cam_pos(pj) - at)
		var pts = []
		for s in 8:
			pts.append(at + sd * x + Vector3.UP * (-1.6 + s * 0.5) + sd * sin(s * 1.3 + k) * 0.25)
		JitonLib.ribbon(pj, pts, 0.7, Color(0.24, 0.26, 0.52), 1.0, 0.7, {"reps": 5.0, "speed": -2.0})
	JitonLib.field_loops(pj, at, Vector3.UP, 2.6, 7, 0.55, JitonLib.FIELD, 0.08)


static func _sphere() -> SphereMesh:
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 14
	return sm


static func _quad() -> QuadMesh:
	var q = QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	return q


# ================================================================== 12) Jitetsu Ryūfūshō: mıknatıs demir tanesi mühür avucu
## Ref (Shinki, manga): hedefi bütünüyle saran, kenarları dikenli, taneli kara küre. Avuçta taneler dönerek toplanır, avuçtan
## hedefe kalın akış kolu uzanır, taneler hedefin çevresinden içe çekilir; kara kabuk dağınık tanelerden kapanarak oluşur
## (dikenli sırtlar), süre bitince taneli dağılıp yere dökülür.
static func jitetsu_ryufusho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	pj.busy(c, 0.8)
	var hp = pj.hand_pos(c, true)
	JitonLib.gather(pj, hp, 1.3, 60, 0.4)
	if tt == null:
		return
	var to = tt.global_position + Vector3.UP
	_flow_arm(pj, hp, to, 0.2, 0.42, 0.8, randf_range(-0.6, 0.6), 0.3, 0.05, false, 7)
	pj.after(0.35, func():
		if not pj.live(tt):
			return
		var shell = Node3D.new()
		var dome = JitonLib.gi(JitonLib.lump_mesh(1.0, 9, 0.16, 14, 9), JitonLib.iron_mat(0.045, 0.4))
		dome.scale = Vector3(0.95, 1.25, 0.95)
		shell.add_child(dome)
		for k in 10:   # ref: kabuk yüzeyinde dikenli sırtlar
			var dv = Vector3(randf_range(-1, 1), randf_range(-0.5, 1.0), randf_range(-1, 1)).normalized()
			var sp = JitonLib.gi(JitonLib.spike_mesh(1.0, 0.5, 4, 0.25, 50 + k % 6, 0.45), JitonLib.iron_mat(0.025))
			sp.transform = Transform3D(_basis_y(dv) * Basis.from_scale(Vector3(0.3, randf_range(0.45, 0.8), 0.3)), Vector3(dv.x * 0.85, dv.y * 1.1, dv.z * 0.85))
			shell.add_child(sp)
		tt.add_child(shell)
		pj.fit_body(tt, shell)   # hedef boyunda (kuyruklu/dev hedefte küçük kalmasın)
		shell.position = Vector3.UP * 1.0
		shell.scale = Vector3.ONE * 1.5
		var mf = _melt_fn(shell)
		mf.call(0.7)
		var tw = shell.create_tween()
		tw.tween_property(shell, "scale", Vector3.ONE, 0.3)
		tw.parallel().tween_method(mf, 0.7, 0.0, 0.3)
		tw.tween_interval(3.1)
		tw.tween_callback(func():
			if is_instance_valid(shell):
				JitonLib.grains(pj, shell.global_position, 120, {"r": 1.2, "dir": Vector3.DOWN, "spread": 70.0, "vmin": 0.5, "vmax": 2.5, "g": 12.0, "life": 0.8, "size": 0.1}))
		tw.tween_method(mf, 0.0, 1.0, 0.4)
		tw.tween_callback(shell.queue_free)
		JitonLib.gather(pj, to, 2.2, 90, 0.35)
		pj.st(tt, "bind", 3.8)
		Combat.popup_text(tt.global_position + Vector3.UP * 2.6, "Demir kumuyla kilitlendi!", Color(0.6, 0.6, 0.7)))
	Sfx.play("earth", c.global_position, 1.3)


# ================================================================== 13) Satetsu Kurogane no Tsubasa: demir kumu kara demir kanatları
## Kaynak yok (Sandaime Kazekage'nin kanatları, kesshū ref'indeki tırtıklı kanatlar örnek alındı): sırttan kökten uca akarak
## büyüyen, yelpaze gibi açılmış, tırtıklı kenarlı yedi kara tüy-kıymık; kanatlar yavaşça çırpar (ikincil hareket), uçlarından
## sürekli ince demir kumu dökülür; bitişte taneli dağılır.
static func satetsu_kurogane_no_tsubasa(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	var m = c.get("model")
	var parts = []
	var wings = []
	if m and m.skel:
		var sk: Skeleton3D = m.skel
		var chest_b = "UpperChest" if sk.find_bone("UpperChest") >= 0 else "Chest"
		var p_ch: Vector3 = m._grest(sk.find_bone(chest_b)).origin
		for sx in [-1.0, 1.0]:
			var ba = m._attach(chest_b, Transform3D(Basis.IDENTITY, p_ch + Vector3(sx * 0.13, 0.05, -0.14)))
			var wing = Node3D.new()
			ba.get_child(0).add_child(wing)
			for k in 7:
				var ang = lerpf(-30.0, 70.0, k / 6.0)
				var L = 1.4 + 0.6 * sin(PI * (k + 1) / 8.0)
				var dv = Vector3(cos(deg_to_rad(ang)) * sx, sin(deg_to_rad(ang)), -0.15)
				var fe = JitonLib.gi(JitonLib.blade_mesh(1.0, 0.34, 0.06, k, 0.3), JitonLib.iron_mat(0.012, 0.8))
				fe.transform = Transform3D(_basis_y(dv) * Basis.from_scale(Vector3(1.0, L, 1.0)), dv * 0.06)
				wing.add_child(fe)
				JitonLib.grow_in(fe, 0.35, k * 0.03)
			wing.scale = Vector3.ONE * 0.05
			wing.create_tween().tween_property(wing, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
			var flap = wing.create_tween().set_loops(13)
			flap.tween_property(wing, "rotation:y", 0.28 * sx, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			flap.tween_property(wing, "rotation:y", -0.1 * sx, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			JitonLib.grains(pj, Vector3(sx * 1.2, 0.9, -0.1), 30, {"loop": true, "parent": wing, "r": 0.6, "dir": Vector3.DOWN, "spread": 40.0, "vmin": 0.3, "vmax": 1.0, "g": 5.0, "life": 1.0, "size": 0.06})
			parts.append(ba)
			wings.append(wing)
	JitonLib.grains(pj, c.global_position + Vector3.UP * 1.3, 140, {"r": 1.2, "dir": Vector3.UP, "spread": 120.0, "vmin": 2.0, "vmax": 6.0, "g": 4.0, "life": 0.9, "size": 0.09})
	JitonLib.gather(pj, c.global_position + Vector3.UP * 1.3, 2.4, 70, 0.4)
	if c is Player:
		Buffs.add("kurogane_tsubasa", 15.0, {"armor": 0.75, "_name": "Kara Demir Kanatlar", "_desc": "demir kum kanatlar: hasar azalır, uçabilirsin"})
		if c.has_method("start_flight"):
			c.start_flight("satetsu", {"drain": 0.0, "speed": 18.0, "dur": 15.0, "name": "Kara Demir Kanatlar"})
	pj.after(14.5, func():
		for w in wings:
			if is_instance_valid(w):
				w.create_tween().tween_method(_melt_fn(w), 0.0, 1.0, 0.45))
	pj.after(15.0, func():
		for pp in parts:
			if is_instance_valid(pp):
				pp.queue_free())
	Sfx.play("earth", c.global_position, 1.0)
