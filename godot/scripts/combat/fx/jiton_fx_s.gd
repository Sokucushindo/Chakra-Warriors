class_name JitonFXS
extends RefCounted
## Kazekage soyları (2026-11-26): Altın Kum (Rasa) ve Demir Kum (Üçüncü Kazekage) dallarını 17'ye tamamlayan teknikler.
## Malzeme / yapı taşları Jiton'un kendi kütüphanesinden (JitonLib: altın / demir gövde shader'ı, taneler, topak / diken / boru
## ağları); her tekniğin şekli, hareketi ve sahnelenmesi burada ve birbirinden ayrı. Başka doğanın ya da ortak efekt yardımcısı yok.
## Kanon: Rasa'nın altın tozu ağırdır — dar akıntıdan dev dalgaya, kalın koruma duvarına (Narutopedia: Rasa / Air Gold Dust
## Protective Wall). Kanonda olmayanlar Rasa'nın ağır, ezici, gömen tarzından türetildi.


static func _melt(root: Node) -> Callable:
	var list = []
	if root is MeshInstance3D:
		list.append(root)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		list.append(n)
	return func(v: float) -> void:
		for g in list:
			if is_instance_valid(g):
				g.set_instance_shader_parameter("melt", v)


static func _by(dir: Vector3) -> Basis:   # +Y = dir
	var y = dir.normalized()
	var ref = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x = ref.cross(y).normalized()
	return Basis(x, y, x.cross(y).normalized())


## Altın akış kolu: a'dan b'ye kavisli boru, kökten uca akar, sonra kuyruğu ucuna çekilip silinir
static func _arm(pj: PathJutsu, a: Vector3, b: Vector3, r0: float, r1: float, lift: float, sway: float, t_in: float, hold: float, sd: int) -> void:
	var mid = (a + b) * 0.5 + Vector3.UP * lift + JitonLib.side_of(b - a) * sway
	var pts = []
	var rad = []
	for i in 10:
		var u = float(i) / 9.0
		pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u) - a)
		rad.append(lerpf(r0, r1, u) * (1.0 + 0.25 * sin(u * 9.0 + sd)))
	var arm = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 7, 0.3, 320 + sd), JitonLib.gold_mat(0.025, 2.5))
	JitonLib.put(pj, arm, a)
	JitonLib.grow_in(arm, t_in)
	var tw = arm.create_tween()
	tw.tween_interval(t_in + hold)
	tw.tween_method(JitonLib.pf(arm, "tail"), 0.0, 1.05, maxf(0.15, t_in * 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(arm.queue_free)


static func _buff(c: Node3D, bname: String, dur: float, mods: Dictionary) -> void:
	if c is Player:
		Buffs.add(bname, dur, mods)
	elif c.has_method("add_buff"):
		c.add_buff(bname, dur, mods)   # AI eşitliği


static func _gone_buff(c: Node3D, bname: String) -> bool:
	if c is Player:
		return not Buffs.has(bname)
	return not ("buffs" in c and (c.buffs as Dictionary).has(bname))


# ================================================================== A1) Sakin Tsubute: altın tozu saçması
## Rasa'nın dar akıntılarının en küçüğü: avuçta altın toz dönerek sıkışır, yedi ağır topak yelpaze halinde fırlar; her biri
## ardında ışıltılı toz bırakır. Altın ağırdır: isabet eden kısa süre yavaşlar, çarpan yerde altın serpinti kalır.
static func sakin_tsubute(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 26.0)
	var hp = pj.hand_pos(c, true)
	JitonLib.gather(pj, hp, 0.9, 50, 0.25, true)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true) + pj.fwd(c, tt) * 0.4
		var aim = pj.aim_at(c, tt, from)
		for k in 7:
			var h = Node3D.new()
			var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 60 + k, 0.28, 8, 6), JitonLib.gold_mat(0.02, 1.0))
			lm.scale = Vector3.ONE * randf_range(0.26, 0.34)
			h.add_child(lm)
			var dirk = aim.rotated(Vector3.UP, (k - 3) * 0.085).rotated(aim.cross(Vector3.UP).normalized(), randf_range(-0.04, 0.06))
			var pr = pj.shot(c, from, dirk, 34.0, h, pj.inf(c, "sakin_tsubute", 0.32, {"knock": 1.6, "kind": "light", "element": "jiton"}), null, false, 1.2,
				func(pos, e):
					JitonLib.grains(pj, pos, 18, {"gold": true, "r": 0.2, "dir": Vector3.UP, "spread": 80.0, "vmin": 1.5, "vmax": 4.0, "g": 10.0, "life": 0.5, "size": 0.07})
					if pj.live(e):
						pj.st(e, "slow", 1.2))
			pr.spin = Vector3(randf_range(4, 9), randf_range(4, 9), 0)
			JitonLib.grains(pj, Vector3.ZERO, 14, {"loop": true, "parent": pr, "gold": true, "r": 0.08, "spread": 180.0, "vmin": 0.1, "vmax": 0.5, "g": 2.0, "life": 0.3, "size": 0.05})
		Sfx.play("throw", from, 0.8))
	Sfx.play("earth", hp, 1.5)


# ================================================================== A2) Sakin Ryūsa: altın tozu akıntısı
## Kanon (Rasa: "dar akıntıdan dev dalgaya"): ayağının dibinden yere yapışık dar bir altın akıntı çıkar, yılan gibi kıvrılarak
## hedefe koşar; ucu hedefin altında kabarıp onu savurur. Akıntının geçtiği yerde altın tabaka kalır, sonra akıntı kuyruğundan
## ucuna doğru çekilip dağılır.
static func sakin_ryusa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 24.0)
	var d = pj.fwd(c, tt)
	var a = pj.gp(c.global_position + d * 1.0)
	var b = pj.gp(tt.global_position if tt else c.global_position + d * 16.0)
	var side = d.cross(Vector3.UP).normalized()
	var pts = []
	var rad = []
	var n = 16
	var sway = randf_range(1.2, 2.0) * (1.0 if randf() < 0.5 else -1.0)
	for i in n:
		var u = float(i) / (n - 1)
		var p = a.lerp(b, u) + side * sin(u * PI * 1.6) * sway * (1.0 - u * 0.6)
		p = pj.gp(p) + Vector3.UP * (0.25 + 0.35 * u * u)
		pts.append(p - a)
		rad.append(lerpf(0.22, 0.42, u) * (1.0 + 0.25 * sin(u * 14.0)))
	var arm = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 8, 0.25, 7), JitonLib.gold_mat(0.03, 3.0))
	JitonLib.put(pj, arm, a)
	JitonLib.grow_in(arm, 0.35)
	JitonLib.near_fade(arm, 4.0)
	var tw = arm.create_tween()
	tw.tween_interval(0.6)
	tw.tween_method(JitonLib.pf(arm, "tail"), 0.0, 1.05, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(arm.queue_free)
	var struck = []
	pj.every(0.35, 0.05, func(i, _k):
		var q = a + (pts[mini(i * 2, n - 1)] as Vector3)
		JitonLib.grains(pj, q, 16, {"gold": true, "r": 0.4, "dir": Vector3.UP, "spread": 50.0, "vmin": 1.5, "vmax": 3.5, "g": 9.0, "life": 0.45, "size": 0.08})
		for e in pj.hit(c, q + Vector3.UP * 0.5, 1.8, pj.inf(c, "sakin_ryusa", 1.6, {"knock": 9.0, "launch": 4.0, "kind": "heavy", "element": "jiton", "dir": d}), struck):
			struck.append(e), Callable())   # akıntının ucu geçtiği her hedefi bir kez savurur
	pj.after(0.33, func():
		var head = JitonLib.gi(JitonLib.lump_mesh(1.0, 71, 0.35, 10, 7), JitonLib.gold_mat(0.04, 1.5))
		JitonLib.put(pj, head, b + Vector3.UP * 0.4)
		head.scale = Vector3(0.4, 0.2, 0.4)
		var ht = head.create_tween()
		ht.tween_property(head, "scale", Vector3(0.9, 1.2, 0.9), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ht.tween_interval(0.25)
		ht.tween_method(_melt(head), 0.0, 1.0, 0.4)
		ht.tween_callback(head.queue_free)
		pj.hit(c, b + Vector3.UP, 2.2, pj.inf(c, "sakin_ryusa", 1.6, {"knock": 9.0, "launch": 4.0, "kind": "heavy", "element": "jiton", "dir": d}), struck)
		JitonLib.grains(pj, b + Vector3.UP * 0.6, 110, {"gold": true, "r": 0.8, "dir": Vector3.UP, "spread": 55.0, "vmin": 4.0, "vmax": 10.0, "g": 12.0, "life": 0.9, "size": 0.1})
		JitonLib.patch(pj, b, 3.2, 1, 3.0, 0.15)
		pj.shake(0.5)
		Sfx.play("earth", b, 0.8))
	JitonLib.patch(pj, a.lerp(b, 0.5), 2.4, 1, 2.4, 0.4)
	Sfx.play("whoosh", a, 0.7)


# ================================================================== A3) Sakin Shibari: altın tozu bağı
## Rasa tarzı (ağırlık): hedefin çevresinde yerden altın topaklar kabarır, iki kalın altın şerit bacaklarından beline dek
## sarmal sarılır ve ağırlaşır; hedef kıpırdayamaz, bağ çözülünce de üstündeki altın tozu onu bir süre yavaşlatır.
static func sakin_shibari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 22.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Bağlanacak hedef yok", Color(1, 0.7, 0.5))
		return
	var s = ClanJutsu.body_scale(tt)
	var root = Node3D.new()
	for k in 7:
		var ang = k * TAU / 7.0 + randf() * 0.3
		var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 80 + k, 0.3, 8, 6), JitonLib.gold_mat(0.03, 0.3))
		lm.position = Vector3(cos(ang), 0.05, sin(ang)) * 0.75
		lm.scale = Vector3(randf_range(0.3, 0.42), randf_range(0.18, 0.3), randf_range(0.3, 0.42))
		root.add_child(lm)
		JitonLib.grow_in(lm, 0.2, k * 0.02)
	for sx in [0.0, PI]:
		var pts = []
		var rad = []
		for i in 22:
			var u = float(i) / 21.0
			var ang = sx + u * TAU * 2.2
			pts.append(Vector3(cos(ang) * lerpf(0.62, 0.36, u), u * 1.05, sin(ang) * lerpf(0.62, 0.36, u)))
			rad.append(lerpf(0.14, 0.08, u))
		var coil = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 6, 0.2, 90 + int(sx)), JitonLib.gold_mat(0.025, 1.5))
		root.add_child(coil)
		JitonLib.grow_in(coil, 0.35, 0.12)
	pj.attach(tt, root, 2.6, Vector3.ZERO)
	var tw = root.create_tween()
	tw.tween_interval(2.1)
	tw.tween_method(_melt(root), 0.0, 1.0, 0.45)
	JitonLib.grains(pj, tt.global_position + Vector3.UP * 0.2, 60, {"gold": true, "r": 0.9 * s, "dir": Vector3.UP, "spread": 30.0, "vmin": 1.0, "vmax": 3.0, "g": 6.0, "life": 0.6, "size": 0.08})
	var wt = weakref(tt)
	pj.after(0.3, func():
		var x = wt.get_ref()
		if x != null and pj.live(x):
			pj.hit(c, x.global_position + Vector3.UP, 1.2, pj.inf(c, "sakin_shibari", 0.45, {"knock": 0.0, "kind": "light", "element": "jiton"}))
			pj.st(x, "bind", 2.0)
			pj.after(2.0, func():
				var y = wt.get_ref()
				if y != null and pj.live(y):
					pj.st(y, "slow", 3.0)))   # bağ çözülse de üstündeki altın ağırlığı kalır
	Sfx.play("earth", tt.global_position, 1.1)


# ================================================================== A4) Kūsakin Bōheki: havadaki altın toz koruma duvarı
## Kanon (Rasa, Air Gold Dust Protective Wall): havaya kaldırılan altın tozu bir anda önünde kalın, kıvrık bir duvara dönüşür;
## Gaara'nın Sand Hail kürelerini bile durdurur. Duvar yerden değil havadan toplanır (taneler yukarıdan iner), 5 sn ayakta kalır,
## değen mermileri yutar, sonra yukarıdan aşağı dağılır.
static func kusakin_boheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 2.6)
	var wall = Node3D.new()
	# ref: kalın, düz yüzlü, kenarları tozlu duvar (sivri kristal değil): dikey profil, hafif öne yatık tepe
	var prof = [Vector2(0.0, -0.3), Vector2(0.15, 0.8), Vector2(0.2, 1.8), Vector2(0.15, 2.8), Vector2(0.0, 3.5), Vector2(-0.2, 3.8)]
	var thick = [1.2, 1.1, 1.0, 0.9, 0.7, 0.4]
	var body = JitonLib.gi(JitonLib.curl_mesh(5.6, prof, thick, 12, 33, 0.25), JitonLib.gold_mat(0.05, 0.6))
	wall.add_child(body)
	for k in 5:
		var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 110 + k, 0.32, 9, 6), JitonLib.gold_mat(0.04, 0.4))
		lm.position = Vector3(lerpf(-2.3, 2.3, k / 4.0), randf_range(0.0, 0.4), randf_range(-0.2, 0.3))
		lm.scale = Vector3(randf_range(0.6, 0.9), randf_range(0.4, 0.6), randf_range(0.5, 0.7))
		wall.add_child(lm)
	JitonLib.put(pj, wall, at)
	wall.rotation.y = atan2(d.x, d.z)
	wall.scale = Vector3(1.0, 0.05, 1.0)
	JitonLib.grains(pj, at + Vector3.UP * 5.0, 160, {"gold": true, "r": 2.8, "dir": Vector3.DOWN, "spread": 20.0, "vmin": 4.0, "vmax": 9.0, "g": 8.0, "life": 0.5, "size": 0.1})
	var tw = wall.create_tween()
	tw.tween_property(wall, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glint = JitonLib.grains(pj, Vector3.UP * 1.8, 30, {"loop": true, "parent": wall, "gold": true, "kind": 2, "r": 2.4, "vmin": 0.1, "vmax": 0.5, "g": 0.0, "life": 0.5, "size": 0.25})
	pj.every(5.0, 1.0 / 30.0, func(_i, _k):
		if not is_instance_valid(wall):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c:
				var lp = wall.to_local(p.global_position)
				if absf(lp.x) < 3.0 and lp.y > -0.5 and lp.y < 4.0 and absf(lp.z) < 1.2:
					JitonLib.grains(pj, p.global_position, 22, {"gold": true, "r": 0.3, "spread": 180.0, "vmin": 1.0, "vmax": 3.5, "g": 8.0, "life": 0.5, "size": 0.08})
					p.queue_free(),
		func():
			if is_instance_valid(glint):
				glint.emitting = false
			if is_instance_valid(wall):
				JitonLib.grains(pj, wall.global_position + Vector3.UP * 2.0, 140, {"gold": true, "r": 2.5, "dir": Vector3.DOWN, "spread": 40.0, "vmin": 0.5, "vmax": 2.0, "g": 9.0, "life": 0.9, "size": 0.1})
				var ft = wall.create_tween()
				ft.tween_method(_melt(wall), 0.0, 1.0, 0.5)
				ft.tween_callback(wall.queue_free))
	Sfx.play("earth", at, 0.7)


# ================================================================== A5) Sakin no Yoroi: altın tozu zırhı
## Rasa tarzı (ağır savunma): gövdeye, omuzlara ve önkollara yassı altın plakalar oturur. Hasar indirimi değil KALKAN: plakalar
## gelen hasarı emer (canın %30'u kadar), emilecek pay bitince "kırılır" ve dökülür. Altın ağırdır: zırh varken biraz yavaşsın.
static func sakin_no_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var dur = 20.0
	var bname = "sakin_no_yoroi"
	var root = Node3D.new()
	var plates = []
	for k in 10:   # gövde çevresi: iki sıra yassı plaka
		var ang = k * TAU / 5.0 + (0.6 if k >= 5 else 0.0)
		var y = 1.15 if k < 5 else 0.85
		var pl = JitonLib.gi(JitonLib.blade_mesh(0.42, 0.34, 0.05, 130 + k, 0.1), JitonLib.gold_mat(0.025, 0.2))
		pl.position = Vector3(sin(ang) * 0.27, y, cos(ang) * 0.2)
		pl.rotation = Vector3(0.0, ang, 0.0)
		root.add_child(pl)
		plates.append(pl)
	for sx in [-1.0, 1.0]:   # omuz yapraklar
		var sh = JitonLib.gi(JitonLib.lump_mesh(1.0, 150 + int(sx), 0.2, 8, 6), JitonLib.gold_mat(0.03, 0.2))
		sh.position = Vector3(sx * 0.24, 1.42, 0.0)
		sh.scale = Vector3(0.16, 0.08, 0.15)
		root.add_child(sh)
		plates.append(sh)
	for pl in plates:
		JitonLib.grow_in(pl, 0.25, randf() * 0.15)
	pj.attach(c, root, dur, Vector3.ZERO)
	JitonLib.grains(pj, c.global_position + Vector3.UP * 1.0, 90, {"gold": true, "shell": true, "r": 1.4, "vmin": 0.0, "vmax": 0.2, "g": 0.0, "radial": -6.0, "life": 0.3, "size": 0.08})
	_buff(c, bname, dur, {"speed": -0.1})
	Combat.set_shield(c, bname, float(c.get("max_hp") if c.get("max_hp") != null else 300.0) * 0.3)
	pj.every(dur, 0.25, func(_i, _k):
		if not is_instance_valid(root) or not pj.live(c):
			return
		var sh: Dictionary = c.get_meta("shields", {}).get(bname, {})
		var frac = float(sh.get("hp", 0.0)) / maxf(1.0, float(sh.get("max", 1.0)))
		var keep = int(ceil(frac * plates.size()))
		for i in plates.size():   # kalkan eridikçe plakalar teker teker dökülür
			var pl = plates[i]
			if i >= keep and is_instance_valid(pl) and pl.visible:
				pl.visible = false
				JitonLib.grains(pj, pl.global_position, 16, {"gold": true, "r": 0.1, "dir": Vector3.DOWN, "spread": 60.0, "vmin": 0.5, "vmax": 2.0, "g": 9.0, "life": 0.5, "size": 0.07})
		if keep <= 0 or _gone_buff(c, bname):
			if c is Player:
				Buffs.remove(bname)
			elif "buffs" in c:
				(c.buffs as Dictionary).erase(bname)
			root.queue_free(), Callable())
	Sfx.play("clink", c.global_position, 0.7)


# ================================================================== A6) Sakin Bunshin: altın tozu klonu
## Rasa tarzı: ayağının dibinden altın toz sütunu dönerek yükselir, içinden altın kaplı bir klon çıkar (oyunun klon sistemi:
## düşmanlar ona yönelir). Klon bozulunca ağır altın tozu yığılır, yakındaki düşmanların ayaklarını gömer (kısa bağ + yavaşlık).
static func sakin_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = c.global_position + c.global_transform.basis.x * 2.4
	var g = pj.gp(at)
	var col = JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0.12, 0.7, 0.0), Vector3(-0.08, 1.3, 0.06), Vector3(0.0, 1.9, 0.0)], [0.55, 0.42, 0.36, 0.18], 9, 0.3, 160), JitonLib.gold_mat(0.03, 3.0))
	JitonLib.put(pj, col, g)
	col.scale = Vector3(1, 0.05, 1)
	var ct = col.create_tween()
	ct.tween_property(col, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.parallel().tween_property(col, "rotation:y", PI * 1.5, 0.45)
	ct.tween_method(_melt(col), 0.0, 1.0, 0.3)
	ct.tween_callback(col.queue_free)
	JitonLib.grains(pj, g + Vector3.UP * 0.1, 80, {"gold": true, "r": 0.9, "dir": Vector3.UP, "spread": 15.0, "vmin": 2.5, "vmax": 5.0, "g": 3.0, "radial": -1.5, "life": 0.6, "size": 0.08})
	var dec = pj.decoy(c, at, 12.0, func(p: Vector3):
		var heap = JitonLib.gi(JitonLib.lump_mesh(1.0, 161, 0.35, 10, 7), JitonLib.gold_mat(0.04, 0.4))
		JitonLib.put(pj, heap, pj.gp(p))
		heap.scale = Vector3(0.5, 1.0, 0.5)
		var ht = heap.create_tween()
		ht.tween_property(heap, "scale", Vector3(1.4, 0.35, 1.4), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ht.tween_interval(1.0)
		ht.tween_method(_melt(heap), 0.0, 1.0, 0.5)
		ht.tween_callback(heap.queue_free)
		JitonLib.grains(pj, p + Vector3.UP, 120, {"gold": true, "r": 0.7, "dir": Vector3.UP, "spread": 70.0, "vmin": 2.0, "vmax": 6.0, "g": 10.0, "life": 0.9, "size": 0.09})
		JitonLib.patch(pj, p, 3.0, 1, 3.0, 0.2)
		for e in pj.enemies_near(c, p, 4.0):
			pj.st(e, "bind", 1.5)
			pj.st(e, "slow", 3.0))
	if dec != null:
		var w = weakref(dec)
		pj.after(0.05, func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x) and x.get("model") != null:
				var gm = JitonLib.gold_mat(0.02, 0.6)
				for mi in (x.model as Node).find_children("*", "MeshInstance3D", true, false):
					mi.material_overlay = gm)   # altın kaplı klon (kendi altın gövde shader'ı)
	Sfx.play("earth", g, 1.2)


# ================================================================== A7) Sakin Senpū: altın tozu kasırgası
## Rasa tarzı: çevresinde yerden kalkan altın toz, bel hizasında dönen kalın bir halkaya dönüşür, üç tur döner ve dışa doğru
## patlayarak yakındakileri savurur. Dönerken içine giren mermileri de tanelere çevirir.
static func sakin_senpu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.1)
	var ring = Node3D.new()
	for k in 3:
		var pts = []
		var rad = []
		for i in 25:
			var a = i * TAU / 24.0
			var rr = 2.2 + 0.35 * k + 0.2 * sin(a * 3.0 + k)
			pts.append(Vector3(cos(a) * rr, 0.6 + k * 0.45 + 0.15 * sin(a * 2.0 + k), sin(a) * rr))
			rad.append(0.16 - k * 0.03 + 0.05 * sin(a * 5.0 + k))
		var band = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 7, 0.3, 170 + k), JitonLib.gold_mat(0.03, 4.0))
		ring.add_child(band)
		JitonLib.grow_in(band, 0.25, k * 0.06)
	pj.attach(c, ring, 1.3, Vector3.ZERO, 0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE, 0.25)
	tw.parallel().tween_property(ring, "rotation:y", TAU * 3.0, 1.05).as_relative()
	tw.tween_property(ring, "scale", Vector3(2.2, 0.5, 2.2), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_melt(ring), 0.0, 1.0, 0.2)
	var spray = JitonLib.grains(pj, Vector3.UP * 1.0, 90, {"loop": true, "parent": ring, "gold": true, "r": 2.6, "dir": Vector3.UP, "spread": 60.0, "vmin": 1.0, "vmax": 3.0, "g": 4.0, "life": 0.5, "size": 0.08})
	pj.every(1.05, 1.0 / 20.0, func(_i, _k):
		if not pj.live(c):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP) < 3.2:
				JitonLib.grains(pj, p.global_position, 14, {"gold": true, "r": 0.2, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "g": 8.0, "life": 0.4, "size": 0.07})
				p.queue_free(), Callable())
	pj.after(1.1, func():
		if is_instance_valid(spray):
			spray.emitting = false
		if not pj.live(c):
			return
		var o = c.global_position + Vector3.UP
		pj.hit(c, o, 4.2, pj.inf(c, "sakin_senpu", 1.8, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "jiton", "hitstop": 0.08}))
		JitonLib.grains(pj, o, 200, {"gold": true, "r": 2.5, "spread": 180.0, "vmin": 6.0, "vmax": 13.0, "g": 6.0, "damp": 2.0, "life": 0.8, "size": 0.09})
		JitonLib.patch(pj, c.global_position, 4.5, 1, 3.0, 0.15)
		pj.shake(0.6)
		Sfx.play("whoosh", o, 0.6))
	Sfx.play("earth", c.global_position, 1.0)


# ================================================================== A8) Sakin Yari: altın mızrak sırası
## Rasa tarzı: atanın önünden hedefe doğru yerde altın toz çizgisi koşar; her yarım metrede yerden yassı, uçları tırtıklı altın
## mızraklar çapraz fışkırır (önce kısa, hedefe yaklaştıkça uzun); hedefin altında en büyük üçlü demet. Mızraklar bir an asılı
## kalır, sonra taneli dağılır.
static func sakin_yari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	var d = pj.fwd(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	var start = c.global_position + d * 1.5
	var L = clampf(c.global_position.distance_to(tt.global_position) + 1.5 if tt else 14.0, 6.0, 20.0)
	var bl = JitonLib.blade_mesh(1.0, 0.36, 0.08, 180, 0.3)
	var struck = []
	var n = int(L / 1.1)
	for k in n:
		pj.after(0.05 + k * 0.05, func():
			if not pj.live(c):
				return
			var u = float(k) / maxf(1.0, n - 1)
			var p = pj.gp(start + d * (k * 1.1) + side * randf_range(-0.5, 0.5))
			var cnt = 1 if u < 0.85 else 3
			for j in cnt:
				var dirv = (Vector3.UP * 1.0 + d * randf_range(0.1, 0.5) + side * randf_range(-0.45, 0.45)).normalized()
				var sp = JitonLib.gi(bl, JitonLib.gold_mat(0.025, 0.4))
				JitonLib.put(pj, sp, p - dirv * 0.2)
				sp.global_basis = _by(dirv).rotated(dirv, randf() * TAU) * Basis.from_scale(Vector3(1.0, lerpf(1.2, 3.6, u) * randf_range(0.8, 1.15), 1.0))
				JitonLib.grow_in(sp, 0.08)
				JitonLib.crumble(sp, 0.55, 0.3)
			JitonLib.grains(pj, p + Vector3.UP * 0.1, 18, {"gold": true, "r": 0.4, "dir": Vector3.UP, "spread": 45.0, "vmin": 2.0, "vmax": 5.0, "g": 10.0, "life": 0.5, "size": 0.08})
			for e in pj.hit(c, p + Vector3.UP * 1.0, 1.6, pj.inf(c, "sakin_yari", 2.0, {"knock": 6.0, "launch": 5.0, "kind": "heavy", "element": "jiton", "bleed": 2.0}), struck):
				struck.append(e)
			if k % 3 == 0:
				Sfx.play("clink", p, 1.1))
	JitonLib.patch(pj, start + d * L * 0.5, L * 0.5, 1, 2.6, 0.5)
	Sfx.play("earth", start, 0.9)


# ================================================================== A9) Sakin Tsuchi: altın tozu balyozu
## Rasa tarzı (ağır, ezici): atanın üstünde altın toz toplanıp kalın saplı, köşeli başlı dev bir balyoza dönüşür; balyoz geri
## kalkar, sonra hedefin üstüne iner — yer çöker, altın tabaka ve fırlayan topaklar; sap kırılıp tozlaşır.
static func sakin_tsuchi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 20.0)
	var d = pj.fwd(c, tt)
	var at = pj.gp(tt.global_position if tt else c.global_position + d * 8.0)
	var piv = Node3D.new()   # atanın yerinde, hedefe bakan (yerel -Z = d)
	var arm = Node3D.new()   # menteşe: rotation.x > 0 geri kalkık, -PI/2 öne yatmış (sap +Y)
	piv.add_child(arm)
	var shaft = JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 2.5, 0), Vector3(0, 5.0, 0), Vector3(0, 7.0, 0)], [0.32, 0.36, 0.34, 0.3], 7, 0.15, 190), JitonLib.gold_mat(0.03, 1.0))
	arm.add_child(shaft)
	var head = JitonLib.gi(JitonLib.lump_mesh(1.0, 191, 0.15, 10, 7), JitonLib.gold_mat(0.05, 0.5))
	head.position = Vector3(0, 7.4, 0)
	head.scale = Vector3(1.4, 1.2, 2.6)
	arm.add_child(head)
	JitonLib.put(pj, piv, pj.gp(c.global_position - d * 0.5))
	piv.rotation.y = atan2(-d.x, -d.z)
	arm.rotation.x = 0.5
	piv.scale = Vector3.ONE * 0.1
	JitonLib.gather(pj, c.global_position + Vector3.UP * 5.0, 3.0, 120, 0.4, true)
	var tw = piv.create_tween()
	tw.tween_property(piv, "scale", Vector3.ONE * (at.distance_to(c.global_position) + 1.0) / 7.5, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_property(arm, "rotation:x", -PI * 0.5, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		pj.hit(c, at + Vector3.UP, 3.6, pj.inf(c, "sakin_tsuchi", 3.0, {"knock": 12.0, "kind": "heavy", "element": "jiton", "hitstop": 0.14, "pierce_guard": true}))
		JitonLib.patch(pj, at, 5.0, 1, 3.6, 0.12)
		JitonLib.shards(pj, at + Vector3.UP * 0.3, 10, 0.35, 9.0, true, 1.0, 1.1)
		JitonLib.grains(pj, at + Vector3.UP * 0.4, 220, {"gold": true, "r": 2.0, "dir": Vector3.UP, "spread": 75.0, "vmin": 5.0, "vmax": 12.0, "g": 12.0, "life": 1.0, "size": 0.11})
		pj.shake(1.0)
		Sfx.play("boom", at, 0.6))
	tw.tween_interval(0.5)
	tw.tween_method(_melt(piv), 0.0, 1.0, 0.6)
	tw.tween_callback(piv.queue_free)
	Sfx.play("earth", c.global_position, 0.6)


# ================================================================== A10) Sakin Omori: altın tozu ağırlığı
## Rasa tarzı: hedefin üstünde altın toz bulutu toplanır ve sağanak halinde üstüne yağar; taneler giysisine, omuzlarına yapışır
## (omuzda ve sırtta altın kabuk). Altın ağırdır: 6 sn boyunca çok yavaş.
static func sakin_omori(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 24.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Ağırlaştırılacak hedef yok", Color(1, 0.7, 0.5))
		return
	var top = tt.global_position + Vector3.UP * 4.5
	JitonLib.gather(pj, top, 2.2, 90, 0.4, true)
	var rain = JitonLib.grains(pj, top, 160, {"loop": true, "gold": true, "r": 1.0, "dir": Vector3.DOWN, "spread": 12.0, "vmin": 5.0, "vmax": 8.0, "g": 6.0, "life": 0.7, "size": 0.08})
	pj.after(0.9, func():
		if is_instance_valid(rain):
			rain.emitting = false
			JitonLib.kill(pj, 1.0, rain))
	var wt = weakref(tt)
	pj.after(0.5, func():
		var x = wt.get_ref()
		if x == null or not pj.live(x):
			return
		var crust = Node3D.new()
		for k in 6:
			var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 200 + k, 0.35, 7, 5), JitonLib.gold_mat(0.025, 0.2))
			var a = k * TAU / 6.0
			lm.position = Vector3(cos(a) * 0.24, 1.25 + 0.15 * sin(a * 2.0), sin(a) * 0.18)
			lm.scale = Vector3(0.16, 0.1, 0.14)
			crust.add_child(lm)
			JitonLib.grow_in(lm, 0.2, k * 0.03)
		pj.attach(x, crust, 6.0, Vector3.ZERO)
		var cw = crust.create_tween()
		cw.tween_interval(5.5)
		cw.tween_method(_melt(crust), 0.0, 1.0, 0.45)
		pj.hit(c, x.global_position + Vector3.UP, 1.2, pj.inf(c, "sakin_omori", 0.5, {"knock": 0.0, "kind": "light", "element": "jiton"}))
		pj.st(x, "slow", 7.0)
		Combat.popup_text(x.global_position + Vector3.UP * 2.4, "Ağırlaştı!", Color(1.0, 0.85, 0.35)))
	Sfx.play("earth", top, 1.3)


# ================================================================== A11) Sakin Ryūjin: altın tozu ejderi (A)
## Rasa tarzının büyük dalgalarından: yerden kalın bir altın gövde kıvrılarak yükselir; başı topaktan yontulmuş, ağzı açık,
## yelesi tırtıklı altın kıymıklar. Ejder bir an havada kıvrılır, sonra hedefe dalar — çarptığı yerde altın patlaması; gövde
## kuyruğundan başına doğru çekilip dağılır.
static func sakin_ryujin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var tt = pj.tg(c, t, 30.0)
	var d = pj.fwd(c, tt)
	var side = d.cross(Vector3.UP).normalized()
	var a = pj.gp(c.global_position + d * 3.5 + side * 3.0)   # atanın yanında ama kamerayı kapatmayacak kadar önde
	var b = (tt.global_position if tt else c.global_position + d * 18.0) + Vector3.UP * 0.8
	var top = a.lerp(b, 0.45) + Vector3.UP * 9.0 + side * 2.0
	var pts = []
	var rad = []
	var n = 20
	for i in n:
		var u = float(i) / (n - 1)
		var p = a.lerp(top, u) + side * sin(u * TAU * 1.2) * 1.8 * (1.0 - u) + Vector3.UP * sin(u * PI) * 1.5   # yerden tepeye kıvrılarak yükselir
		pts.append(p - a)
		rad.append(lerpf(0.7, 0.45, u) * (1.0 + 0.18 * sin(u * 22.0)))
	var body = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 9, 0.3, 210), JitonLib.gold_mat(0.05, 3.5))
	JitonLib.put(pj, body, a)
	JitonLib.grow_in(body, 0.6)
	var head = Node3D.new()
	var skull = JitonLib.gi(JitonLib.lump_mesh(1.0, 211, 0.25, 10, 7), JitonLib.gold_mat(0.05, 0.6))
	skull.scale = Vector3(1.2, 1.0, 2.0)
	head.add_child(skull)
	var jaw = JitonLib.gi(JitonLib.lump_mesh(1.0, 212, 0.3, 8, 6), JitonLib.gold_mat(0.04, 0.4))
	jaw.scale = Vector3(1.0, 0.45, 1.6)
	jaw.position = Vector3(0, -0.9, -0.6)
	jaw.rotation.x = 0.4   # açık çene
	head.add_child(jaw)
	for k in 9:   # tırtıklı yele ve iki boynuz
		var sp = JitonLib.gi(JitonLib.spike_mesh(1.0, 1.0, 4, 0.2, 213 + k, 0.5), JitonLib.gold_mat(0.025, 0.3))
		var ang = -0.9 + k * 0.22
		sp.transform = Transform3D(_by(Vector3(sin(ang) * 0.6, 0.7, 0.9).normalized()) * Basis.from_scale(Vector3(0.25, 1.6 if k % 4 else 2.4, 0.25)), Vector3(sin(ang) * 0.8, 0.6, 0.9))
		head.add_child(sp)
	JitonLib.put(pj, head, a + (pts[n - 1] as Vector3))
	head.look_at(b, Vector3.UP)   # tepede doğar, hedefe bakar, sonra dalar
	head.scale = Vector3.ONE * 0.05
	var ht = head.create_tween()
	ht.tween_interval(0.45)
	ht.tween_property(head, "scale", Vector3.ONE * 0.9, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ht.tween_interval(0.2)
	ht.tween_property(head, "global_position", b - Vector3.UP * 0.3, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ht.tween_callback(func():
		pj.hit(c, b, 4.2, pj.inf(c, "sakin_ryujin", 3.6, {"knock": 15.0, "launch": 5.0, "kind": "heavy", "element": "jiton", "hitstop": 0.14}))
		var g0 = pj.gp(b)
		JitonLib.patch(pj, g0, 6.0, 1, 4.0, 0.15)
		JitonLib.shards(pj, b, 12, 0.4, 10.0, true, 1.0, 1.2)
		JitonLib.grains(pj, b, 230, {"gold": true, "r": 1.5, "spread": 180.0, "vmin": 6.0, "vmax": 14.0, "g": 10.0, "damp": 1.0, "life": 1.1, "size": 0.12})
		JitonLib.grains(pj, b, 50, {"gold": true, "kind": 2, "r": 2.5, "spread": 180.0, "vmin": 2.0, "vmax": 6.0, "g": 0.0, "life": 0.8, "size": 0.32})
		pj.shake(1.1)
		Sfx.play("boom", b, 0.55))
	ht.tween_method(_melt(head), 0.0, 1.0, 0.4)
	ht.tween_callback(head.queue_free)
	var bt = body.create_tween()
	bt.tween_interval(1.25)
	bt.tween_method(JitonLib.pf(body, "tail"), 0.0, 1.05, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bt.tween_callback(body.queue_free)
	var spray = JitonLib.grains(pj, Vector3.ZERO, 100, {"loop": true, "parent": head, "gold": true, "r": 1.0, "spread": 180.0, "vmin": 0.5, "vmax": 2.0, "g": 5.0, "life": 0.5, "size": 0.1})
	JitonLib.grains(pj, a, 160, {"gold": true, "r": 1.5, "dir": Vector3.UP, "spread": 25.0, "vmin": 5.0, "vmax": 11.0, "g": 8.0, "life": 0.9, "size": 0.1})
	Sfx.play("earth", a, 0.5)


# ================================================================== A12) Sakin Hōkai: altın tozu çığı (A)
## Rasa'nın "devasa dalgalar" tarzının gökten hâli: hedef alanın üstünde altın toz kubbe gibi birikir (alttan bakınca dönen tavan),
## sonra kenarlarından başlayıp çığ gibi çöker; altın sel alanı doldurur, içindekileri ezip gömer (bağ), geriye yayvan altın tepeler kalır.
static func sakin_hokai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	var R = 6.5
	var roof = Node3D.new()
	for k in 9:
		var ang = k * TAU / 9.0
		var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 230 + k, 0.35, 10, 7), JitonLib.gold_mat(0.05, 1.5))
		lm.position = Vector3(cos(ang) * R * 0.55, randf_range(-0.4, 0.4), sin(ang) * R * 0.55)
		lm.scale = Vector3(2.6, 1.3, 2.6)
		roof.add_child(lm)
	var core = JitonLib.gi(JitonLib.lump_mesh(1.0, 240, 0.3, 12, 8), JitonLib.gold_mat(0.05, 2.0))
	core.scale = Vector3(R * 0.6, 1.8, R * 0.6)
	roof.add_child(core)
	JitonLib.put(pj, roof, at + Vector3.UP * 11.0)
	roof.scale = Vector3.ONE * 0.1
	var tw = roof.create_tween()
	tw.tween_property(roof, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	roof.create_tween().tween_property(roof, "rotation:y", 1.8, 1.4).as_relative()
	JitonLib.gather(pj, at + Vector3.UP * 11.0, 7.0, 200, 0.6, true)
	tw.tween_interval(0.3)
	tw.tween_property(roof, "global_position", at + Vector3.UP * 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(roof, "scale", Vector3(1.25, 0.45, 1.25), 0.35)
	tw.tween_callback(func():
		pj.hit(c, at + Vector3.UP, R, pj.inf(c, "sakin_hokai", 3.4, {"knock": 6.0, "kind": "heavy", "element": "jiton", "hitstop": 0.12, "pierce_guard": true}))
		for e in pj.enemies_near(c, at, R):
			pj.st(e, "bind", 1.5)
		JitonLib.patch(pj, at, R + 2.0, 1, 5.0, 0.2)
		for k in 14:
			var ang = k * TAU / 14.0
			JitonLib.grains(pj, at + Vector3(cos(ang), 0.2, sin(ang)) * R * 0.8, 30, {"gold": true, "r": 1.0, "dir": Vector3(cos(ang), 0.5, sin(ang)), "spread": 25.0, "vmin": 5.0, "vmax": 10.0, "g": 12.0, "life": 0.9, "size": 0.12})
		JitonLib.shards(pj, at + Vector3.UP * 0.5, 14, 0.45, 9.0, true, 0.8, 1.2)
		pj.shake(1.3)
		Sfx.play("boom", at, 0.45))
	tw.tween_interval(1.2)
	tw.tween_method(_melt(roof), 0.0, 1.0, 0.8)
	tw.tween_callback(roof.queue_free)
	var fall = JitonLib.grains(pj, Vector3(0, -1.0, 0), 160, {"loop": true, "parent": roof, "gold": true, "r": R * 0.6, "dir": Vector3.DOWN, "spread": 10.0, "vmin": 3.0, "vmax": 6.0, "g": 8.0, "life": 1.0, "size": 0.09})
	pj.after(1.0, func():
		if is_instance_valid(fall):
			fall.emitting = false)
	Sfx.play("earth", c.global_position, 0.5)


# ================================================================== A13) Ōgon Kyūden: altın saray (S)
## Rasa soyunun en büyük tekniği (kanonda Rasa'nın Sakin Taisō'sunun saray ölçeğinde hâli): hedef alanın çevresinde yerden on iki
## altın sütun fışkırır, aralarını kalın altın duvarlar örer, üstünde dönen altın kubbe kapanır — içindekiler kilitlenir. Saray
## üç kez nabız gibi içe sıkışır (her sıkışta hasar), sonra kubbenin tepesinden göğe altın ışık sütunu patlar ve saray çöker.
static func ogon_kyuden(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.2)
	var tt = pj.tg(c, t, 32.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	var R = 7.0
	var palace = Node3D.new()
	JitonLib.put(pj, palace, at)
	var pillars = []
	for k in 12:
		var ang = k * TAU / 12.0
		var pl = JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 3.0, 0), Vector3(0, 6.0, 0), Vector3(0, 8.5, 0)], [0.9, 0.7, 0.7, 0.95], 8, 0.12, 250 + k), JitonLib.gold_mat(0.05, 0.5))
		pl.position = Vector3(cos(ang), 0, sin(ang)) * R
		palace.add_child(pl)
		pl.scale = Vector3(1, 0.02, 1)
		var pt = pl.create_tween()
		pt.tween_interval(k * 0.04)
		pt.tween_property(pl, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pillars.append(pl)
		JitonLib.grains(pj, at + pl.position, 30, {"gold": true, "r": 0.8, "dir": Vector3.UP, "spread": 20.0, "vmin": 6.0, "vmax": 12.0, "g": 10.0, "life": 0.8, "size": 0.1})
	for k in 12:   # duvarlar: sütun aralarını kalın altın perde örer
		var a0 = k * TAU / 12.0
		var mid = (a0 + TAU / 24.0)
		var wall = JitonLib.gi(JitonLib.curl_mesh(2.0 * R * sin(PI / 12.0) + 0.6, [Vector2(0.0, 0.0), Vector2(0.0, 2.5), Vector2(0.0, 5.0), Vector2(-0.2, 7.5)], [0.7, 0.6, 0.55, 0.4], 8, 260 + k, 0.2), JitonLib.gold_mat(0.04, 0.8))
		wall.position = Vector3(cos(mid), 0, sin(mid)) * R * 0.97
		wall.rotation.y = atan2(cos(mid), sin(mid))
		palace.add_child(wall)
		JitonLib.grow_in(wall, 0.35, 0.3 + k * 0.02)
	var dome = JitonLib.gi(JitonLib.lump_mesh(1.0, 280, 0.1, 16, 10), JitonLib.gold_mat(0.05, 2.5))
	dome.position = Vector3(0, 8.0, 0)
	dome.scale = Vector3(R * 1.05, 0.2, R * 1.05)
	palace.add_child(dome)
	var spire = JitonLib.gi(JitonLib.spike_mesh(4.0, 1.4, 6, 0.1, 281, 0.4), JitonLib.gold_mat(0.04, 0.4))
	spire.position = Vector3(0, 8.0, 0)
	spire.scale = Vector3.ONE * 0.05
	palace.add_child(spire)
	var dt = dome.create_tween()
	dt.tween_interval(0.7)
	dt.tween_property(dome, "scale", Vector3(R * 1.05, R * 0.45, R * 1.05), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dt.parallel().tween_property(spire, "scale", Vector3.ONE, 0.4)
	dome.create_tween().tween_property(dome, "rotation:y", 2.0, 3.0).as_relative()
	JitonLib.near_fade(palace, 9.0)
	var trapped = []
	pj.after(1.1, func():
		for e in pj.enemies_near(c, at, R):
			trapped.append(weakref(e))
			pj.st(e, "bind", 2.3)
		if c == Game.player and not trapped.is_empty():
			Combat.popup_text(at + Vector3.UP * 9.5, "Ōgon Kyūden!", Color(1.0, 0.85, 0.3)))
	for pulse in 3:
		pj.after(1.4 + pulse * 0.45, func():
			if not is_instance_valid(palace):
				return
			var pw = palace.create_tween()
			pw.tween_property(palace, "scale", Vector3(0.86, 1.0, 0.86), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			pw.tween_property(palace, "scale", Vector3.ONE, 0.2)
			pj.hit(c, at + Vector3.UP, R, pj.inf(c, "ogon_kyuden", 1.6, {"knock": 0.0, "kind": "heavy", "element": "jiton", "hitstop": 0.06, "pierce_guard": true}))
			JitonLib.grains(pj, at + Vector3.UP * 2.0, 120, {"gold": true, "shell": true, "r": R * 0.9, "vmin": 0.0, "vmax": 0.2, "g": 0.0, "radial": -30.0, "life": 0.25, "size": 0.12})
			pj.shake(0.6)
			Sfx.play("earth", at, 0.5 + pulse * 0.08))
	pj.after(2.85, func():
		if not is_instance_valid(palace):
			return
		pj.hit(c, at + Vector3.UP, R, pj.inf(c, "ogon_kyuden", 4.5, {"knock": 18.0, "launch": 8.0, "kind": "heavy", "element": "jiton", "hitstop": 0.18, "pierce_guard": true}))
		var beam = JitonLib.gi(JitonLib.tube_mesh([Vector3.ZERO, Vector3(0, 12.0, 0), Vector3(0, 30.0, 0)], [2.2, 1.6, 0.6], 10, 0.1, 290), JitonLib.gold_mat(0.0, 6.0))
		JitonLib.put(pj, beam, at + Vector3.UP * 7.0)
		JitonLib.grow_in(beam, 0.15)
		var bw = beam.create_tween()
		bw.tween_interval(0.5)
		bw.tween_method(_melt(beam), 0.0, 1.0, 0.5)
		bw.tween_callback(beam.queue_free)
		JitonLib.grains(pj, at + Vector3.UP * 8.0, 240, {"gold": true, "r": 2.0, "dir": Vector3.UP, "spread": 30.0, "vmin": 12.0, "vmax": 25.0, "g": 6.0, "life": 1.3, "size": 0.14})
		JitonLib.grains(pj, at + Vector3.UP * 4.0, 80, {"gold": true, "kind": 2, "r": R, "spread": 180.0, "vmin": 1.0, "vmax": 5.0, "g": 0.0, "life": 1.0, "size": 0.4})
		JitonLib.shards(pj, at + Vector3.UP * 3.0, 20, 0.6, 12.0, true, 1.0, 1.4)
		JitonLib.patch(pj, at, R + 3.0, 1, 6.0, 0.25)
		pj.shake(1.6)
		Sfx.play("boom", at, 0.4)
		var cw = palace.create_tween()
		cw.tween_property(palace, "scale", Vector3(1.15, 0.05, 1.15), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		cw.parallel().tween_method(_melt(palace), 0.0, 1.0, 0.6)
		cw.tween_callback(palace.queue_free))
	Sfx.play("earth", at, 0.4)


# ================================================================== A14) Ōgon no Taiyō: altın güneş (S)
## Rasa soyunun son sırrı: atan iki elini göğe kaldırır, çevredeki bütün altın tozu (yerden, havadan) göğe akar ve atanın üstünde
## dönen dev bir altın küreye sıkışır; küre parladıkça çevresinde ışıltı halkaları döner. Sonra güneş hedef alana iner: çarpmada
## ışık patlaması, dev altın kıymıklar her yöne saplanır, geniş alan altınla kaplanır (içindekiler bir an gömülür).
static func ogon_no_taiyo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.4)
	var tt = pj.tg(c, t, 34.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 16.0)
	var sky = c.global_position + Vector3.UP * 14.0
	for k in 10:   # yerden göğe akan altın kolları
		var ang = k * TAU / 10.0
		var q = pj.gp(c.global_position + Vector3(cos(ang), 0, sin(ang)) * 8.0)
		pj.after(k * 0.05, func():
			_arm(pj, q, sky, 0.5, 0.2, 3.0, randf_range(-3.0, 3.0), 0.5, 0.3, k))
	var sun = Node3D.new()
	var core = JitonLib.gi(JitonLib.lump_mesh(1.0, 300, 0.08, 18, 12), JitonLib.gold_mat(0.06, 4.0))
	sun.add_child(core)
	var rings = []
	for k in 3:
		var pts = []
		var rad = []
		for i in 33:
			var ang = i * TAU / 32.0
			pts.append(Vector3(cos(ang), 0.0, sin(ang)) * (1.45 + k * 0.25))
			rad.append(0.05 + 0.03 * sin(ang * 6.0 + k))
		var rg = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 5, 0.2, 301 + k), JitonLib.gold_mat(0.0, 5.0))
		rg.rotation = Vector3(0.5 + k * 0.7, k * 1.1, 0.3 * k)
		sun.add_child(rg)
		rings.append(rg)
	JitonLib.put(pj, sun, sky)
	sun.scale = Vector3.ONE * 0.2
	var st = sun.create_tween()
	st.tween_property(sun, "scale", Vector3.ONE * 4.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for rg in rings:
		rg.create_tween().tween_property(rg, "rotation:y", TAU * 2.0, 2.0).as_relative()
	sun.create_tween().tween_property(sun, "rotation:y", 3.0, 2.0).as_relative()
	JitonLib.gather(pj, sky, 9.0, 260, 0.9, true)
	var glow = JitonLib.grains(pj, Vector3.ZERO, 70, {"loop": true, "parent": sun, "gold": true, "kind": 2, "r": 1.6, "spread": 180.0, "vmin": 0.5, "vmax": 2.0, "g": 0.0, "life": 0.6, "size": 0.35})
	if c == Game.player:
		Combat.popup_text(sky + Vector3.UP * 3.0, "Ōgon no Taiyō!", Color(1.0, 0.85, 0.3))
	st.tween_interval(0.35)
	st.tween_property(sun, "global_position", at + Vector3.UP * 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	st.tween_callback(func():
		if is_instance_valid(glow):
			glow.emitting = false
		pj.hit(c, at + Vector3.UP, 9.0, pj.inf(c, "ogon_no_taiyo", 6.0, {"knock": 20.0, "launch": 7.0, "kind": "heavy", "element": "jiton", "hitstop": 0.2, "pierce_guard": true}))
		for e in pj.enemies_near(c, at, 9.0):
			pj.st(e, "bind", 1.2)
		var bl = JitonLib.blade_mesh(6.0, 0.8, 0.1, 310, 0.25)
		for k in 30:   # her yöne saplanan dev altın kıymıklar
			var dirv = Vector3(randf_range(-1, 1), randf_range(0.05, 0.8), randf_range(-1, 1)).normalized()
			var sh = JitonLib.gi(bl, JitonLib.gold_mat(0.03))
			JitonLib.put(pj, sh, at + Vector3.UP * 0.8)
			sh.global_basis = _by(dirv).rotated(dirv, randf() * TAU) * Basis.from_scale(Vector3(randf_range(0.8, 1.4), randf_range(0.8, 1.6), 1.0))
			JitonLib.grow_in(sh, 0.1)
			JitonLib.crumble(sh, 1.2, 0.5)
		JitonLib.grains(pj, at + Vector3.UP * 2.0, 260, {"gold": true, "r": 2.5, "spread": 180.0, "vmin": 10.0, "vmax": 22.0, "g": 8.0, "damp": 1.0, "life": 1.4, "size": 0.14})
		JitonLib.grains(pj, at + Vector3.UP * 2.0, 90, {"gold": true, "kind": 2, "r": 6.0, "spread": 180.0, "vmin": 2.0, "vmax": 8.0, "g": 0.0, "life": 1.2, "size": 0.45})
		JitonLib.patch(pj, at, 12.0, 1, 7.0, 0.3)
		JitonLib.patch(pj, at, 7.0, 2, 6.0, 0.15)
		pj.shake(2.0)
		Sfx.play("boom", at, 0.35))
	st.tween_property(sun, "scale", Vector3.ONE * 6.0, 0.15)
	st.parallel().tween_method(_melt(sun), 0.0, 1.0, 0.4)
	st.tween_callback(sun.queue_free)
	Sfx.play("earth", c.global_position, 0.4)


# ================================================================== D1) Satetsu Heki: demir kum duvarı
## Kanon (Iron Sand Wall): yerden yukarı akan kara demir kumu, yan yana dikilmiş dar levhalardan bir çit duvara dönüşür; levhaların
## yüzü kısa dikenli, kenarları testere dişli. Oluşurken dibindekileri iter; 4 sn mermileri durdurur, sonra levhalar teker teker çöker.
static func satetsu_heki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.45)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var at = pj.gp(c.global_position + d * 2.2)
	var root = Node3D.new()
	JitonLib.put(pj, root, at)
	root.rotation.y = atan2(-d.x, -d.z)
	var slabs = []
	for k in 9:
		var x = (k - 4) * 0.62
		var h = 3.0 - absf(k - 4) * 0.18 + randf_range(-0.2, 0.2)
		var sl = JitonLib.gi(JitonLib.blade_mesh(h, 0.7, 0.22, 340 + k, 0.25), JitonLib.iron_mat(0.04, 0.3))
		sl.position = Vector3(x, 0.0, -absf(k - 4) * 0.08)
		sl.rotation.z = randf_range(-0.05, 0.05)
		root.add_child(sl)
		for j in 3:   # yüzdeki kısa dikenler (hedefe bakan yüz: -Z)
			var sp = JitonLib.gi(JitonLib.spike_mesh(0.5, 0.09, 4, 0.2, 350 + k * 3 + j, 0.5), JitonLib.iron_mat(0.015))
			sp.transform = Transform3D(_by(Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), -1.0)), Vector3(x + randf_range(-0.2, 0.2), randf_range(0.5, h - 0.4), -0.15))
			root.add_child(sp)
		sl.scale = Vector3(1, 0.02, 1)
		var st = sl.create_tween()
		st.tween_interval(absf(k - 4) * 0.03)
		st.tween_property(sl, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slabs.append(sl)
	JitonLib.grains(pj, at + Vector3.UP * 0.2, 120, {"r": 2.6, "dir": Vector3.UP, "spread": 15.0, "vmin": 5.0, "vmax": 9.0, "g": 12.0, "life": 0.5, "size": 0.08})
	JitonLib.patch(pj, at, 3.2, 0, 4.6, 0.2)
	for e in pj.enemies_near(c, at + d * 0.5, 2.2):
		pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "satetsu_heki", 0.4, {"knock": 8.0, "kind": "light", "element": "jiton", "dir": d}))
	pj.every(4.0, 1.0 / 30.0, func(_i, _k):
		if not is_instance_valid(root):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(p) and p.get("shooter") != c:
				var lp = root.to_local(p.global_position)
				if absf(lp.x) < 3.0 and lp.y > -0.3 and lp.y < 3.3 and absf(lp.z) < 1.0:
					JitonLib.grains(pj, p.global_position, 14, {"r": 0.3, "spread": 180.0, "vmin": 1.0, "vmax": 3.0, "g": 9.0, "life": 0.5, "size": 0.07})
					p.queue_free(),
		func():
			for k in slabs.size():
				var sl = slabs[k]
				if is_instance_valid(sl):
					JitonLib.crumble(sl, k * 0.05, 0.3)
			if is_instance_valid(root):
				JitonLib.kill(pj, 0.9, root))
	Sfx.play("earth", at, 0.9)


# ================================================================== D2) Satetsu Buki: demir kum silahı
## Kanon (Iron Sand Weaponry): sağ kolun boyunca kara demir kumu akıp önkoldan uzun, tırtıklı, kıvrık bir kılıca sertleşir. Üç
## kesik: yatay, çapraz, aşağı — her biri önünde kara akış izi bırakır, kanatır. Sonra kılıç kökten tanelere döner.
static func satetsu_buki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 6.0)
	var grip = pj.bone_attach(c, "RightHand")
	if grip:
		var bl = JitonLib.gi(JitonLib.blade_mesh(1.7, 0.22, 0.06, 360, 0.35), JitonLib.iron_mat(0.025, 2.0))
		bl.position = Vector3(0, 0.95, 0)
		grip.add_child(bl)
		JitonLib.grow_in(bl, 0.15)
		for k in 4:   # sırttaki tırtıklar
			var sp = JitonLib.gi(JitonLib.spike_mesh(0.3, 0.05, 4, 0.2, 361 + k, 0.5), JitonLib.iron_mat(0.01))
			sp.transform = Transform3D(_by(Vector3(-1.0, 0.6, 0.0)), Vector3(-0.08, 0.4 + k * 0.35, 0))
			grip.add_child(sp)
		pj.after(1.05, func():
			if is_instance_valid(bl):
				JitonLib.crumble(bl, 0.0, 0.25)
			if is_instance_valid(grip):
				JitonLib.kill(pj, 0.35, grip))
	JitonLib.gather(pj, pj.hand_pos(c, true), 0.6, 30, 0.15)
	var cuts = [[0.15, Vector3(1, 0.1, 0), "attack"], [0.45, Vector3(1, 0.6, 0), "attack"], [0.75, Vector3(0.2, 1, 0), "attack"]]
	for k in cuts.size():
		var cu = cuts[k]
		pj.after(float(cu[0]), func():
			if not pj.live(c):
				return
			var d = pj.fwd(c, tt)
			var side = d.cross(Vector3.UP).normalized()
			pj.anim(c, "slash_a" if k % 2 == 0 else "slash_c", 1.8)
			var o = c.global_position + Vector3.UP * 1.2 + d * 1.2
			var ax = (side * (cu[1] as Vector3).x + Vector3.UP * (cu[1] as Vector3).y).normalized()
			var pts = []
			for i in 9:
				var a = lerpf(-1.1, 1.1, i / 8.0)
				pts.append(o + ax * sin(a) * 1.6 + d * cos(a) * 1.2)
			JitonLib.ribbon(pj, pts, 0.22, Color(0.08, 0.08, 0.1), 1.0, 0.25)
			pj.hit(c, o + d * 0.6, 2.0, pj.inf(c, "satetsu_buki", 0.9 if k < 2 else 1.4, {"knock": 2.0 if k < 2 else 9.0, "kind": "light" if k < 2 else "heavy", "element": "jiton", "bleed": 2.0, "melee": true}))
			Sfx.play("swing_blade", o, 0.9 + k * 0.1))
	Sfx.play("earth", c.global_position, 1.4)


# ================================================================== D3) Satetsu Nami: demir kum dalgası
## Kanon (Iron Sand Wave): atanın önünden yere yatık, tepesi testere dişli kara bir dalga yükselir ve ileri koşar; dişlerden öne
## kısa dikenler uzanır. Geçtiği her hedefi keser ve kanatır, arkasında dikenli kara iz bırakır; 16 m sonra çöküp tanelenir.
static func satetsu_nami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var start = pj.gp(c.global_position + d * 1.8)
	var wave = Node3D.new()
	var prof = [Vector2(-0.6, -0.3), Vector2(-0.4, 0.8), Vector2(0.0, 1.8), Vector2(0.5, 2.5), Vector2(1.0, 2.7), Vector2(1.3, 2.2)]
	var thick = [1.0, 0.85, 0.7, 0.5, 0.35, 0.2]
	var body = JitonLib.gi(JitonLib.curl_mesh(6.0, prof, thick, 14, 370, 1.0), JitonLib.iron_mat(0.04, 2.5))
	wave.add_child(body)
	for k in 7:   # öne uzanan kısa dikenler
		var sp = JitonLib.gi(JitonLib.spike_mesh(1.4, 0.16, 4, 0.2, 371 + k, 0.5), JitonLib.iron_mat(0.015))
		sp.transform = Transform3D(_by(Vector3(0, 0.25, 1.0)), Vector3((k - 3) * 0.85, 2.2 + randf_range(-0.2, 0.3), 1.1))
		wave.add_child(sp)
	JitonLib.put(pj, wave, start)
	wave.rotation.y = atan2(d.x, d.z)
	wave.scale = Vector3(1, 0.05, 1)
	var struck = []
	var tw = wave.create_tween()
	tw.tween_property(wave, "scale", Vector3.ONE, 0.18)
	tw.tween_property(wave, "global_position", start + d * 16.0, 0.75)
	tw.tween_property(wave, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.parallel().tween_method(_melt(wave), 0.0, 1.0, 0.2)
	tw.tween_callback(wave.queue_free)
	var spray = JitonLib.grains(pj, Vector3(0, 2.4, 0.5), 100, {"loop": true, "parent": wave, "r": 2.8, "dir": (Vector3.UP - d * 0.5).normalized(), "spread": 30.0, "vmin": 2.0, "vmax": 5.0, "g": 10.0, "life": 0.5, "size": 0.08})
	pj.every(0.95, 0.06, func(i, _k):
		if not is_instance_valid(wave):
			return
		var gpos = pj.gp(wave.global_position)
		if i % 3 == 0:
			JitonLib.patch(pj, gpos, 2.6, 2, 3.0, 0.12)
		for e in pj.hit(c, wave.global_position + Vector3.UP * 1.0, 3.2, pj.inf(c, "satetsu_nami", 1.8, {"knock": 10.0, "launch": 2.5, "kind": "heavy", "element": "jiton", "bleed": 3.0, "dir": d}), struck):
			struck.append(e), func():
			if is_instance_valid(spray):
				spray.emitting = false)
	Sfx.play("earth", start, 0.7)


# ================================================================== D4) Satetsu Bunshin: demir kum klonu
## Kanon (Iron Sand Clone): kara demir kumu ayağının yanında dönerek yükselip demir kaplı bir klona sertleşir (oyunun klon sistemi:
## düşmanlar ona yönelir). Klon bozulunca gövdesinden her yöne kara dikenler patlar — yakındakiler kesilir ve kanar.
static func satetsu_bunshin(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = c.global_position - c.global_transform.basis.x * 2.4
	var g = pj.gp(at)
	JitonLib.grains(pj, g + Vector3.UP * 0.1, 90, {"r": 0.8, "dir": Vector3.UP, "spread": 12.0, "vmin": 3.0, "vmax": 6.0, "g": 3.0, "radial": -2.0, "life": 0.6, "size": 0.08})
	JitonLib.patch(pj, g, 2.0, 0, 3.0, 0.2)
	var dec = pj.decoy(c, at, 12.0, func(p: Vector3):
		var o = p + Vector3.UP * 1.0
		var nd = JitonLib.spike_mesh(1.0, 0.5, 4, 0.15, 380, 0.5)
		for k in 16:
			var dir = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.8), randf_range(-1, 1)).normalized()
			var sp = JitonLib.gi(nd, JitonLib.iron_mat(0.015))
			JitonLib.put(pj, sp, o)
			sp.global_basis = _by(dir) * Basis.from_scale(Vector3(0.2, randf_range(2.0, 3.2), 0.2))
			JitonLib.grow_in(sp, 0.08)
			JitonLib.crumble(sp, 0.5, 0.3)
		JitonLib.grains(pj, o, 140, {"r": 0.5, "spread": 180.0, "vmin": 5.0, "vmax": 11.0, "g": 10.0, "damp": 1.5, "life": 0.8, "size": 0.09})
		JitonLib.patch(pj, p, 3.2, 2, 3.0, 0.15)
		pj.hit(c, o, 3.2, pj.inf(c, "satetsu_bunshin", 1.8, {"knock": 8.0, "kind": "heavy", "element": "jiton", "bleed": 3.0}))
		Sfx.play("clink", o, 0.7))
	if dec != null:
		var w = weakref(dec)
		pj.after(0.05, func():
			var x = w.get_ref()
			if x != null and is_instance_valid(x) and x.get("model") != null:
				var im = JitonLib.iron_mat(0.02, 0.8)
				for mi in (x.model as Node).find_children("*", "MeshInstance3D", true, false):
					mi.material_overlay = im)   # demir kaplı klon
	Sfx.play("earth", g, 1.1)


# ================================================================== D5) Satetsu no Karada: demir kum bedeni
## Kanon (Iron Sand Body): kara demir kumu gövdeyi sarar ve sertleşir; omuzlardan ve sırttan geriye doğru kara dikenler çıkar.
## Hasar indirimi değil KALKAN (canın %25'i). Diken kabuk: dibine gelen düşmanı (1.8 m) saniyede bir keser ve kanatır.
static func satetsu_karada(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var dur = 18.0
	var bname = "satetsu_karada"
	var root = Node3D.new()
	var parts = []
	for k in 8:   # gövde kabuğu: kara topak plakalar
		var ang = k * TAU / 8.0
		var lm = JitonLib.gi(JitonLib.lump_mesh(1.0, 400 + k, 0.35, 7, 5), JitonLib.iron_mat(0.025, 1.0))
		lm.position = Vector3(sin(ang) * 0.24, 1.0 + 0.25 * (k % 2), cos(ang) * 0.17)
		lm.scale = Vector3(0.17, 0.2, 0.12)
		root.add_child(lm)
		parts.append(lm)
	for k in 7:   # omuz / sırt dikenleri (geriye, yukarı)
		var sx = -1.0 if k % 2 == 0 else 1.0
		var sp = JitonLib.gi(JitonLib.spike_mesh(1.0, 1.0, 4, 0.2, 410 + k, 0.5), JitonLib.iron_mat(0.015))
		var dirv = Vector3(sx * randf_range(0.3, 0.7), randf_range(0.4, 0.9), -1.0).normalized()
		sp.transform = Transform3D(_by(dirv) * Basis.from_scale(Vector3(0.09, randf_range(0.5, 0.8), 0.09)), Vector3(sx * randf_range(0.08, 0.24), randf_range(1.05, 1.45), -0.16))
		root.add_child(sp)
		parts.append(sp)
	for p in parts:
		JitonLib.grow_in(p, 0.2, randf() * 0.15)
	pj.attach(c, root, dur, Vector3.ZERO)
	JitonLib.grains(pj, c.global_position + Vector3.UP * 1.0, 100, {"shell": true, "r": 1.3, "vmin": 0.0, "vmax": 0.2, "g": 0.0, "radial": -6.0, "life": 0.3, "size": 0.07})
	_buff(c, bname, dur, {})
	Combat.set_shield(c, bname, float(c.get("max_hp") if c.get("max_hp") != null else 300.0) * 0.25)
	pj.every(dur, 1.0, func(_i, _k):
		if not is_instance_valid(root) or not pj.live(c):
			return
		var sh: Dictionary = c.get_meta("shields", {}).get(bname, {})
		if float(sh.get("hp", 0.0)) <= 0.0 or _gone_buff(c, bname):
			for pp in parts:
				if is_instance_valid(pp):
					JitonLib.crumble(pp, 0.0, 0.3)
			JitonLib.kill(pj, 0.4, root)
			if c is Player:
				Buffs.remove(bname)
			return
		for e in pj.enemies_near(c, c.global_position, 1.8):   # diken kabuk: dibindekini keser
			pj.hit(c, e.global_position + Vector3.UP, 0.8, pj.inf(c, "satetsu_karada", 0.25, {"knock": 3.0, "kind": "light", "element": "jiton", "bleed": 1.5})), Callable())
	Sfx.play("clink", c.global_position, 0.6)


# ================================================================== D6) Jitetsu Fūin Tō: mıknatıslı demir kum mühür kılıcı
## Kanon (Magnetic Iron Sand Sealing Blade): avuçta mıknatıs akış halkaları açılır, demir kumu uzun, çift ağızlı kara bir kılıca
## sıkışır; kılıç yatay dönerek hedefe uçar (güdümlü), ardında kara toz izi. İsabet eden mühürlenir: bir süre teknik kullanamaz,
## göğsünde dönen kara mühür halkası.
static func jitetsu_fuin_to(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 28.0)
	var hp = pj.hand_pos(c, true)
	JitonLib.field_loops(pj, hp, pj.fwd(c, tt), 0.8, 4, 0.5, JitonLib.FIELD, 0.05)
	JitonLib.gather(pj, hp, 1.0, 50, 0.3)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true) + pj.fwd(c, tt) * 0.5
		var h = Node3D.new()
		var bl = JitonLib.gi(JitonLib.blade_mesh(2.4, 0.3, 0.07, 420, 0.15), JitonLib.iron_mat(0.025, 1.5))
		bl.rotation.z = PI * 0.5   # yatay (Y ekseni -> yana)
		h.add_child(bl)
		var bl2 = JitonLib.gi(JitonLib.blade_mesh(2.4, 0.3, 0.07, 421, 0.15), JitonLib.iron_mat(0.025, 1.5))
		bl2.rotation.z = -PI * 0.5
		h.add_child(bl2)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, h, pj.inf(c, "jitetsu_fuin_to", 1.6, {"knock": 4.0, "kind": "heavy", "element": "jiton", "bleed": 2.0}), tt, false, 1.8,
			func(_p, e):
				if pj.live(e):
					pj.st(e, "sealed", 5.0)
					Combat.popup_text(e.global_position + Vector3.UP * 2.4, "Mühürlendi!", Color(0.7, 0.75, 0.9))
					var rg = Node3D.new()
					for k in 2:
						var pts = []
						var rad = []
						for i in 21:
							var a = i * TAU / 20.0
							pts.append(Vector3(cos(a) * (0.45 + k * 0.15), 0.0, sin(a) * (0.45 + k * 0.15)))
							rad.append(0.03)
						var rr = JitonLib.gi(JitonLib.tube_mesh(pts, rad, 4, 0.1, 430 + k), JitonLib.iron_mat(0.0, 4.0))
						rr.position = Vector3(0, 1.2, 0)
						rr.rotation.x = 0.3 * (1 - 2 * k)
						rg.add_child(rr)
					pj.attach(e, rg, 5.0, Vector3.ZERO)
					rg.create_tween().set_loops(5).tween_property(rg, "rotation:y", TAU, 1.0).as_relative())
		pr.homing_turn = 4.0
		pr.spin = Vector3(0, 22.0, 0)
		pr.radius = 0.7
		JitonLib.grains(pj, Vector3.ZERO, 40, {"loop": true, "parent": pr, "r": 0.6, "spread": 180.0, "vmin": 0.2, "vmax": 0.8, "g": 2.0, "life": 0.35, "size": 0.06})
		Sfx.play("throw", from, 0.7))
	Sfx.play("earth", hp, 1.3)


# ================================================================== D7) Rendan Satetsu Shigure: art arda demir kum yağmuru (A)
## Kanon (Successive Shots Iron Sand Drizzle, Üçüncü Kazekage): gökte üç yassı kara demir kumu kütlesi açılır; her biri sırayla hedefin
## o anki yerine (izleyerek) iğne sağanağı boşaltır — üç dalga, her dalgada 26 iğne; kütleler son dalgadan sonra tanelenir.
static func rendan_satetsu_shigure(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	var needle = JitonLib.spike_mesh(1.3, 0.07, 4, 0.15, 440, 0.5)
	var masses = []
	for m in 3:
		var off = Vector3(cos(m * TAU / 3.0), 0, sin(m * TAU / 3.0)) * 4.0 + Vector3.UP * (9.0 + m * 0.8)
		var ms = JitonLib.gi(JitonLib.lump_mesh(1.0, 441 + m, 0.32, 14, 6), JitonLib.iron_mat(0.05, 0.8))
		JitonLib.put(pj, ms, at + off)
		ms.scale = Vector3(0.2, 0.05, 0.2)
		var mt = ms.create_tween()
		mt.tween_interval(m * 0.12)
		mt.tween_property(ms, "scale", Vector3(3.0, 0.6, 3.0), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ms.create_tween().tween_property(ms, "rotation:y", 3.0, 3.0).as_relative()
		JitonLib.gather(pj, at + off, 3.0, 60, 0.4)
		masses.append(ms)
	for wave in 3:
		for k in 26:
			pj.after(0.5 + wave * 0.6 + randf() * 0.45, func():
				var ms = masses[wave]
				if not is_instance_valid(ms) or not pj.live(c):
					return
				var aim_p = tt.global_position if pj.live(tt) else at
				var q = ms.global_position + Vector3(randf_range(-1.6, 1.6), -0.2, randf_range(-1.6, 1.6))
				var dirv = (aim_p + Vector3(randf_range(-1.5, 1.5), 0.8, randf_range(-1.5, 1.5)) - q).normalized()
				var nd = Node3D.new()
				var mi = JitonLib.gi(needle, JitonLib.iron_mat(0.012))
				mi.rotation.x = -PI * 0.5
				mi.position = Vector3(0, 0, 0.6)
				nd.add_child(mi)
				pj.shot(c, q, dirv, 38.0, nd, pj.inf(c, "rendan_satetsu_shigure", 0.1, {"knock": 0.4, "kind": "light", "element": "jiton", "bleed": 0.8}), null, false, 0.8))
	for m in 3:
		pj.after(2.3 + m * 0.15, func():
			var ms = masses[m]
			if is_instance_valid(ms):
				JitonLib.crumble(ms, 0.0, 0.5))
	pj.after(0.8, func(): JitonLib.patch(pj, at, 5.5, 2, 4.0, 1.5))
	Sfx.play("earth", at, 1.2)


# ================================================================== D8) Kurogane Jigoku: kara demir cehennemi (S)
## Üçüncü Kazekage soyunun son sırrı (Satetsu Kaihō'nun yer hâli): atan avuçlarını yere bastırır; hedef alanın altındaki toprak kara
## demir kumu denizine döner (dalgalanan kara alan, mıknatıs akış halkaları). Merkezden dışa üç halka halinde dev dikenler fışkırır
## (her halka bir öncekinden büyük); içindekiler kilitlenir. Sonunda merkezden dev bir diken yükselip hedefi göğe kaldırır, sonra
## bütün orman taneli dağılır.
static func kurogane_jigoku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.2)
	var tt = pj.tg(c, t, 32.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	var R = 9.0
	JitonLib.patch(pj, at, R + 1.5, 0, 4.6, 0.6)
	JitonLib.patch(pj, at, R, 2, 4.4, 0.8)
	JitonLib.field_loops(pj, at + Vector3.UP * 0.5, Vector3.UP, R * 0.8, 6, 1.2, JitonLib.FIELD, 0.1)
	JitonLib.grains(pj, at + Vector3.UP * 0.2, 220, {"r": R * 0.8, "dir": Vector3.UP, "spread": 20.0, "vmin": 1.0, "vmax": 4.0, "g": 6.0, "life": 1.2, "size": 0.09})
	if c == Game.player:
		Combat.popup_text(at + Vector3.UP * 4.0, "Kurogane Jigoku!", Color(0.75, 0.78, 0.95))
	pj.after(0.5, func():
		for e in pj.enemies_near(c, at, R):
			pj.st(e, "bind", 2.0))
	var sp_mesh = JitonLib.spike_mesh(1.0, 1.0, 5, 0.2, 450, 0.5)
	for ring in 3:
		pj.after(0.6 + ring * 0.35, func():
			var rr = R * (0.3 + ring * 0.33)
			var cnt = 8 + ring * 6
			for k in cnt:
				var ang = k * TAU / cnt + randf() * 0.2
				var p = pj.gp(at + Vector3(cos(ang), 0, sin(ang)) * rr * randf_range(0.85, 1.1))
				var dirv = (Vector3.UP * 1.0 + Vector3(cos(ang), 0, sin(ang)) * randf_range(-0.25, 0.35)).normalized()
				var sp = JitonLib.gi(sp_mesh, JitonLib.iron_mat(0.04, 0.3))
				JitonLib.put(pj, sp, p - dirv * 0.4)
				var L = randf_range(3.0, 4.5) + ring * 1.2
				sp.global_basis = _by(dirv).rotated(dirv, randf() * TAU) * Basis.from_scale(Vector3(0.55 + ring * 0.12, L, 0.55 + ring * 0.12))
				JitonLib.grow_in(sp, 0.1)
				JitonLib.crumble(sp, 1.9 - ring * 0.3, 0.5)
				JitonLib.grains(pj, p + Vector3.UP * 0.2, 10, {"r": 0.4, "dir": Vector3.UP, "spread": 40.0, "vmin": 2.0, "vmax": 5.0, "g": 10.0, "life": 0.5, "size": 0.08})
			pj.hit(c, at + Vector3.UP, rr + 1.5, pj.inf(c, "kurogane_jigoku", 1.5, {"knock": 0.0, "kind": "heavy", "element": "jiton", "bleed": 3.0, "hitstop": 0.06, "pierce_guard": true}))
			pj.shake(0.5 + ring * 0.25)
			Sfx.play("clink", at, 0.5 + ring * 0.1))
	pj.after(1.9, func():
		var big = JitonLib.gi(JitonLib.spike_mesh(1.0, 1.0, 6, 0.15, 460, 0.45), JitonLib.iron_mat(0.05, 0.5))
		JitonLib.put(pj, big, at - Vector3.UP * 0.5)
		big.global_basis = Basis.from_scale(Vector3(1.6, 0.1, 1.6))
		var bt = big.create_tween()
		bt.tween_property(big, "scale", Vector3(1.6, 11.0, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_interval(1.0)
		bt.tween_method(_melt(big), 0.0, 1.0, 0.6)
		bt.tween_callback(big.queue_free)
		pj.hit(c, at + Vector3.UP, 2.5, pj.inf(c, "kurogane_jigoku", 4.0, {"knock": 2.0, "launch": 14.0, "kind": "heavy", "element": "jiton", "bleed": 4.0, "hitstop": 0.2, "pierce_guard": true}))
		JitonLib.grains(pj, at + Vector3.UP * 5.0, 200, {"r": 1.5, "spread": 180.0, "vmin": 6.0, "vmax": 14.0, "g": 10.0, "damp": 1.0, "life": 1.0, "size": 0.1})
		JitonLib.field_loops(pj, at + Vector3.UP * 4.0, Vector3.UP, 3.0, 5, 0.6, JitonLib.FIELD, 0.1)
		pj.shake(1.6)
		Sfx.play("boom", at, 0.5))
	Sfx.play("earth", at, 0.4)

