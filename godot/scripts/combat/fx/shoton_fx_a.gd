class_name ShotonFXA
extends RefCounted
## Shōton grubu A: on bir kristal tekniğinin görünüşü + taşınan oynanışı. Malzeme / yapı taşları ShotonLib'den (kendi
## kristal gölgelendiricisi: kalın beyaz yüz kenarı, yüz parıltısı, iç ışıma, yıldız pırıltısı, doygun alt dolgu; altıgen
## kristal halısı, halka izi, parıltı, toz, yonga, kırılma). Her tekniğin şekli, hareketi ve sahnelenmesi kendine özgü.
## Oynanış (hasar çarpanları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const S = preload("res://scripts/combat/fx/lib/shoton_lib.gd")

const PINK_C := Color(0.95, 0.6, 0.85)

static var _c := {}


static func _cached(key: String, fn: Callable) -> ArrayMesh:
	if not _c.has(key):
		_c[key] = fn.call()
	return _c[key]


## Bir düğümün altındaki tüm kristal örneklerinde görünen boyu kapatır (kristal yere geri çekilir) ve siler
static func _sink(n: Node3D, h: float, t: float) -> void:
	if not is_instance_valid(n):
		return
	var gis: Array = []
	for ch in n.find_children("*", "GeometryInstance3D", true, false):
		gis.append(ch)
	if n is GeometryInstance3D:
		gis.append(n)
	var tw = n.create_tween()
	tw.tween_method(func(v: float):
		for g in gis:
			if is_instance_valid(g):
				g.set_instance_shader_parameter("reveal_d", v), h, -0.01, t).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


# ================================================================== Kesshō no Yoroi (Kristal Zırh)
## Kaynak (Guren): yumruğu ve ön kolu saran, yüzlü pembe kristal eldiven; parlak kenar, yumruk ucunda ışık parıltısı.
## Ayak dibinde altıgen kristal halısı açılır, uzuvlarda kristal kabuk TRANS_BACK ile oturur ve beyaz parlayarak katılaşır.
## Süre sonunda zırh parçaları kırılıp pırıltıyla dağılır.
static func kessho_no_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var parts = []
	for bone in ["UpperChest", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftHand", "RightHand"]:
		var ba = pj.bone_attach(c, bone)
		if ba == null:
			continue
		var kind = "chest" if bone == "UpperChest" else ("hand" if bone.ends_with("Hand") else ("arm" if bone.ends_with("Arm") else "leg"))
		var mi = S.cmi(_armor_mesh(kind), {"pal": S.PINK, "alpha": 0.82, "outline": true, "ow": 0.012, "near": 0.6})
		ba.add_child(mi)
		mi.scale = Vector3.ONE * 0.1
		mi.create_tween().tween_property(mi, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		S.flash_in(mi, 0.4)
		parts.append(ba)
	S.carpet(pj, c.global_position, 1.8, 0.5, {"t": 0.3, "out": 0.4})
	S.sparkles(pj, c.global_position + Vector3.UP, {"n": 26, "r": 0.8, "vmin": 1.0, "vmax": 3.0})
	if c is Player:
		Buffs.add("kessho_yoroi", 15.0, {"armor": 0.7, "melee": 1.15, "_name": "Kristal Zırh", "_desc": "kristal plakalar: gelen hasar çok azalır, yumruklar sertleşir"})
	pj.after(15.0, func():
		for pp in parts:
			if is_instance_valid(pp):
				S.shatter(pj, pp.global_position, {"n": 3, "s": 0.08, "r": 0.15, "v": 2.0, "up": 2.0, "life": 0.7})
				pp.queue_free())
	Sfx.play("clink", c.global_position, 1.0)


## Zırh parçaları (kemik ekseni +Y): ön kol eldiveni, yumruk bloğu, uyluk kabuğu, göğüs plakası — dışa taşan kristal yüzlerle
static func _armor_mesh(kind: String) -> ArrayMesh:
	return _cached("armor_" + kind, func():
		var st = S.begin()
		match kind:
			"arm":
				S.loft(st, [{"p": Vector3(0, -0.02, 0), "rx": 0.07}, {"p": Vector3(0, 0.13, 0), "rx": 0.088, "rot": 0.25}, {"p": Vector3(0, 0.28, 0), "rx": 0.072}], 6, 0.0, 1)
				for k in 3:
					var a = k * TAU / 3.0 + 0.4
					var o = Vector3(cos(a), 0, sin(a))
					S.loft(st, [{"p": o * 0.07 + Vector3.UP * 0.06, "rx": 0.035}, {"p": o * 0.13 + Vector3.UP * 0.2, "rx": 0.0}], 4, 0.0, 2)
			"hand":
				S.loft(st, [{"p": Vector3(0, -0.02, 0), "rx": 0.07}, {"p": Vector3(0, 0.06, 0.01), "rx": 0.088, "ry": 0.07, "rot": 0.3}, {"p": Vector3(0, 0.14, 0.01), "rx": 0.065}], 6, 0.0, 3)
				S.loft(st, [{"p": Vector3(0, 0.12, 0.04), "rx": 0.07, "ry": 0.03, "up": Vector3(0, 0, 1)}, {"p": Vector3(0, 0.17, 0.05), "rx": 0.0}], 4, 0.0, 4)
			"leg":
				S.loft(st, [{"p": Vector3(0, 0.0, 0), "rx": 0.11}, {"p": Vector3(0, 0.22, 0), "rx": 0.125, "rot": 0.3}, {"p": Vector3(0, 0.42, 0), "rx": 0.1}], 6, 0.0, 5)
			_:
				S.loft(st, [{"p": Vector3(0, -0.06, 0), "rx": 0.16, "ry": 0.13}, {"p": Vector3(0, 0.1, 0), "rx": 0.19, "ry": 0.15, "rot": 0.26}, {"p": Vector3(0, 0.26, 0), "rx": 0.15, "ry": 0.12}], 6, 0.0, 6)
				for sx in [-1.0, 1.0]:
					S.loft(st, [{"p": Vector3(0.12 * sx, 0.2, 0.0), "rx": 0.05}, {"p": Vector3(0.22 * sx, 0.32, 0.0), "rx": 0.0}], 4, 0.0, 7)
		return S.finish(st))


# ================================================================== Shōton: Suishōtō (Yeşim Kristal Kılıç)
## Kaynak (Guren): ön koldan ileri uzanan mavi yüzlü kristal kılıç (koldan beyaz parlayarak dipten uca büyür). Savuruşta
## yay boyunca sırayla beliren ve düşen küçük kristal yongaları + pırıltı; vurulan kişinin çevresinden mavi altıgen
## kristal kümeleri yükselip onu içine alır, süre sonunda kırılır.
static func shoton_suishoto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	var d = pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.8)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var blade = _cached("suishoto_blade", func():
			var st = S.begin()
			S.loft(st, [{"p": Vector3(0, -0.12, 0), "rx": 0.06, "ry": 0.03, "up": Vector3(0, 0, 1)}, {"p": Vector3(0, 0.2, 0), "rx": 0.13, "ry": 0.035, "up": Vector3(0, 0, 1)},
				{"p": Vector3(0, 1.0, 0), "rx": 0.12, "ry": 0.03, "up": Vector3(0, 0, 1)}, {"p": Vector3(0.03, 1.42, 0), "rx": 0.05, "ry": 0.02, "up": Vector3(0, 0, 1)},
				{"p": Vector3(0.06, 1.6, 0), "rx": 0.0}], 4, 0.0, 11)
			for i in 3:
				var y = 0.12 + i * 0.16
				S.loft(st, [{"p": Vector3(-0.1, y, 0), "rx": 0.03}, {"p": Vector3(-0.2, y + 0.05, 0), "rx": 0.0}], 4, 0.0, 12)
			return S.finish(st))
		var bm = S.cmi(blade, {"pal": S.BLUE, "alpha": 0.9, "outline": true, "ow": 0.015, "near": 0.8})
		ba.add_child(bm)
		bm.rotation.x = PI * 0.5   # +Y boyu kolun ilerisine (+Z)
		S.grow_up(bm, 1.65, 0.14)
		S.flash_in(bm, 0.3)
		pj.free_after(1.3, ba)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "slash_b", 1.6)
		var ctr = c.global_position + Vector3.UP * 1.2
		var bas = Basis.looking_at(d, Vector3.UP)
		for k in 9:
			var ang = deg_to_rad(lerpf(60.0, -60.0, k / 8.0))
			var dv = bas * Vector3(sin(ang), 0, -cos(ang))
			var tg_v = bas * Vector3(cos(ang), 0, sin(ang))
			var ch = S.cmi(S.prism_mesh(0.42, 0.06, 0.12, k % 3), {"pal": S.BLUE, "alpha": 0.9, "near": 1.0})
			S.put(pj, ch, ctr + dv * 1.6)
			ch.global_basis = Basis.looking_at(tg_v, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
			ch.visible = false
			var tw = ch.create_tween()
			tw.tween_interval(k * 0.014)
			tw.tween_callback(func(): ch.visible = true)
			tw.tween_property(ch, "global_position", ch.global_position + Vector3.DOWN * 0.6 + dv * 0.4, 0.4).set_ease(Tween.EASE_IN)
			tw.parallel().tween_method(func(v: float): ch.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.4)
			tw.tween_callback(ch.queue_free)
		S.sparkles(pj, ctr + d * 1.4, {"n": 14, "r": 1.2, "pal": S.BLUE, "life": 0.6})
		var hs = pj.hit(c, c.global_position + Vector3.UP + d * 1.3, 2.0, pj.inf(c, "shoton_suishoto", 1.4, {"knock": 4.0, "kind": "heavy", "bleed": 2.0}))
		for h in hs:
			var at = pj.gp(h.global_position)
			var cl = Node3D.new()
			S.put(pj, cl, at)
			for q in 6:
				var a = q * TAU / 6.0 + randf() * 0.4
				var hgt = randf_range(1.4, 2.2)
				var pm = S.cmi(S.prism_mesh(hgt, randf_range(0.2, 0.3), 0.35, q % 4), {"pal": S.BLUE, "alpha": 0.62, "outline": true, "ow": 0.02, "near": 1.5})
				cl.add_child(pm)
				pm.position = Vector3(cos(a), 0, sin(a)) * 0.55
				pm.rotation = Vector3(-sin(a) * 0.3, randf() * TAU, cos(a) * 0.3)
				S.grow_up(pm, hgt + 0.05, 0.18, q * 0.02)
			var tw2 = cl.create_tween()
			tw2.tween_interval(2.4)
			tw2.tween_callback(func(): S.shatter(pj, at + Vector3.UP, {"n": 12, "s": 0.22, "r": 0.7, "pal": S.BLUE}))
			tw2.tween_callback(cl.queue_free)
			pj.st(h, "bind", 2.4)
		Sfx.play("clink", c.global_position, 1.4))


# ================================================================== Shōton: Suishō Rokkakuchū (Yeşim Kristal Altıgen Sütunlar)
## Kaynak: hedefin çevresinde yerde iç içe tırtıklı halka izleri yayılır; çevresinden dibinde beyaz kırık saçaklı, uçları
## piramit pembe altıgen dikilitaşlar yerden fırlar (ortadaki daha iri), dipte kristal yongaları sıçrar. Süre sonunda
## dikilitaşlar yere geri çekilir.
static func shoton_suisho_rokkakuchu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 20.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 9.0)
	S.carpet(pj, at, 7.0, 1.4, {"mode": 1.0, "t": 0.7, "out": 0.6})
	S.sparkles(pj, at + Vector3.UP * 3.0, {"n": 10, "box": Vector3(0.1, 3.0, 0.1), "g": Vector3.ZERO, "vmin": 0.1, "vmax": 0.3, "pal": S.SILVER, "life": 0.6})
	var frill = _cached("rokkaku_frill", func():
		var st = S.begin()
		for i in 12:
			var a = i * TAU / 12.0
			var o = Vector3(cos(a), 0, sin(a))
			S.loft(st, [{"p": o * 0.5, "rx": 0.07}, {"p": o * (0.7 + 0.08 * (i % 3)) + Vector3.UP * (0.12 + 0.06 * (i % 2)), "rx": 0.0}], 4, 0.0, 21)
		return S.finish(st))
	for k in 7:
		pj.after(0.15 + k * 0.05, func():
			var q = at + (Vector3.ZERO if k == 0 else Vector3(cos(k * 1.05), 0, sin(k * 1.05)) * 3.0)
			var big = k == 0
			var hgt = 3.0 if big else 2.2
			var root = Node3D.new()
			S.put(pj, root, pj.gp(q) - Vector3.UP * 3.0)
			root.rotation.y = randf() * TAU
			var col = S.cmi(S.prism_mesh(hgt, 0.6 if big else 0.42, 0.7 if big else 0.5, k % 4), {"pal": S.PINK, "alpha": 0.8, "outline": true, "ow": 0.025, "near": 2.0})
			root.add_child(col)
			S.flash_in(col, 0.3)
			var fr = S.cmi(frill, {"pal": S.SILVER, "alpha": 0.95, "near": 1.5})
			root.add_child(fr)
			fr.scale = Vector3.ONE * (1.3 if big else 1.0)
			var tw = root.create_tween()
			tw.tween_property(root, "global_position", pj.gp(q), 0.12)
			tw.tween_interval(2.0)
			tw.tween_callback(func():
				S.sparkles(pj, root.global_position + Vector3.UP * hgt * 0.5, {"n": 8, "r": 0.6, "life": 0.5})
				_sink(root, hgt + 0.1, 0.3))
			S.chips(pj, pj.gp(q) + Vector3.UP * 0.2, {"n": 10, "r": 0.5, "dir": Vector3.UP, "spread": 50.0, "vmin": 3.0, "vmax": 7.0, "pal": S.PINK})
			pj.hit(c, pj.gp(q) + Vector3.UP, 1.6, pj.inf(c, "shoton_suisho_rokkakuchu", 0.45, {"knock": 4.0, "launch": 9.0, "kind": "heavy", "bleed": 2.0})))
	Sfx.play("clink", at, 0.8)


# ================================================================== Shōton: Suishō Kyō (Yeşim Kristal Ayna)
## Kaynak: kalın, düzensiz yeşim kristal çubuklardan altıgen çerçeve, köşelerinde sivri uçlar; içinde soluk yeşil ayna camı
## üzerinde kayan çapraz ışık şeritleri. Altı ayna atanın çevresinde belirip yavaşça döner; mermi yansıyınca en yakın
## ayna beyaz parlar, yeşim pırıltısı saçılır.
static func shoton_suisho_kyo(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var root = Node3D.new()
	c.add_child(root)
	var frame = _cached("kyo_frame", func():
		var st = S.begin()
		for k in 6:
			var a0 = k * TAU / 6.0 + PI / 6.0
			var a1 = (k + 1) * TAU / 6.0 + PI / 6.0
			var p0 = Vector3(cos(a0), sin(a0), 0) * 1.0
			var p1 = Vector3(cos(a1), sin(a1), 0) * 1.0
			var mid = (p0 + p1) * 0.5 + Vector3(0, 0, 0.03 * (1 if k % 2 == 0 else -1))
			S.loft(st, [{"p": p0, "rx": 0.06, "up": Vector3(0, 0, 1)}, {"p": mid, "rx": 0.075, "up": Vector3(0, 0, 1), "rot": 0.4}, {"p": p1, "rx": 0.06, "up": Vector3(0, 0, 1)}], 5, 0.0, 30 + k)
			S.loft(st, [{"p": p0 * 0.98, "rx": 0.05, "up": Vector3(0, 0, 1)}, {"p": p0 * 1.28, "rx": 0.0, "up": Vector3(0, 0, 1)}], 4, 0.0, 40 + k)
		return S.finish(st))
	var panes: Array = []
	for k in 6:
		var a = k * TAU / 6.0
		var m = Node3D.new()
		root.add_child(m)
		m.position = Vector3(cos(a) * 2.2, 1.2, sin(a) * 2.2)
		m.basis = Basis.looking_at(Vector3(cos(a), 0, sin(a)), Vector3.UP)
		var pane = S.cmi(S.hexplate_mesh(0.98, 0.03), {"pal": S.JADE, "alpha": 0.16, "sheen": 1.0, "two": true, "near": 1.2})
		m.add_child(pane)
		var fm = S.cmi(frame, {"pal": S.JADE, "alpha": 0.95, "outline": true, "ow": 0.015, "near": 1.2})
		m.add_child(fm)
		S.flash_in(pane, 0.3)
		S.flash_in(fm, 0.3)
		panes.append(pane)
	root.scale = Vector3.ONE * 0.1
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(root, "rotation:y", 0.9, 4.25)
	tw.tween_callback(func():
		for p in panes:
			if is_instance_valid(p):
				S.sparkles(pj, p.global_position, {"n": 6, "r": 0.6, "pal": S.JADE, "life": 0.5}))
	tw.tween_callback(root.queue_free)
	S.sparkles(pj, c.global_position + Vector3.UP * 1.2, {"n": 18, "r": 2.2, "pal": S.JADE})
	pj.every(4.3, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP) < 2.6 and p.get("vel") != null:
				p.vel = -p.vel
				p.shooter = c
				S.sparkles(pj, p.global_position, {"n": 8, "r": 0.3, "pal": S.JADE, "life": 0.5})
				var best: Node3D = null
				var bd = 1e9
				for pn in panes:
					if is_instance_valid(pn) and pn.global_position.distance_to(p.global_position) < bd:
						bd = pn.global_position.distance_to(p.global_position)
						best = pn
				if best:
					S.flash_in(best, 0.3), Callable())
	if c is Player:
		Buffs.add("suisho_kyo", 4.0, {"armor": 0.6, "_name": "Kristal Ayna", "_desc": "mermiler saldırgana geri yansır"})
	Sfx.play("clink", c.global_position, 1.3)


# ================================================================== Kesshō Rokkaku Shuriken Ranbu (Kristal Altıgen Shuriken Fırtınası)
## Kaynak: ince, yarı saydam gümüş kristal diskler; içinde kar tanesi deseni (altı kol + yan dişler); çevrede yanıp sönen
## yıldız parıltıları. Atanın çevresinde pırıltı bulutu toplanır, diskler kendi düzleminde dönerek yağar, ardında gümüş
## parıltı izi; çarptığı yerde ince kristal kırıntısı.
static func kessho_rokkaku_shuriken_ranbu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	var from = c.global_position + Vector3.UP * 1.6
	S.sparkles(pj, from, {"n": 34, "r": 2.6, "pal": S.SILVER, "life": 1.3, "vmin": 0.1, "vmax": 0.6})
	S.dust(pj, from, {"n": 20, "r": 1.0, "spread": 180.0, "vmin": 0.5, "vmax": 1.5, "pal": S.SILVER, "life": 0.8})
	var sm = S.shuriken_mesh(0.42)
	for k in 14:
		pj.after(0.15 + k * 0.05, func():
			if not pj.live(c):
				return
			var star = Node3D.new()
			star.add_child(S.cmi(sm, {"pal": S.SILVER, "alpha": 0.42, "two": true, "near": 1.0}))
			var q = from + c.face_dir().cross(Vector3.UP) * randf_range(-2.0, 2.0) + Vector3.UP * randf_range(-0.4, 1.0)
			var pr = pj.shot(c, q, pj.aim_at(c, tt, q), 36.0, star, pj.inf(c, "kessho_rokkaku_shuriken_ranbu", 0.15, {"knock": 1.5, "kind": "light", "bleed": 2.0}), tt, false, 1.2, func(p, _h):
				S.chips(pj, p, {"n": 6, "r": 0.2, "vmin": 2.0, "vmax": 5.0, "pal": S.SILVER, "smin": 0.5, "smax": 0.9})
				S.sparkles(pj, p, {"n": 4, "r": 0.2, "pal": S.SILVER, "life": 0.4}))
			pr.spin = Vector3(0, 26, 0)
			S.trail(pr, {"pal": S.SILVER, "n": 16, "life": 0.4, "smin": 0.1, "smax": 0.22}))
	Sfx.play("clink", from, 1.6)


# ================================================================== Suishō Bunshin no Jutsu (Yeşim Kristal Klonu)
## Kaynak: klon, düzensiz yeşim kristal çubuklardan (çatallı eklemli) altıgen kafesin içinde belirir; kafes yüzlerinde soluk
## yeşil cam ve kayan ışık şeritleri. Kafes tabandan tepeye örülür, kısa süre sonra yeşim kırıntılarına ayrılır.
## Klon vurulunca yeşim kristal olup dağılır.
static func suisho_bunshin_no_jutsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var cage = _cached("bunshin_cage", func():
		var st = S.begin()
		for k in 6:
			var a = k * TAU / 6.0
			var a2 = (k + 1) * TAU / 6.0
			var p0 = Vector3(cos(a), 0, sin(a)) * 0.9
			var p1 = Vector3(cos(a2), 0, sin(a2)) * 0.9
			var kink = Vector3(cos(a + 0.2), 0, sin(a + 0.2)) * 0.06
			S.loft(st, [{"p": p0 + Vector3.UP * 0.02, "rx": 0.05}, {"p": p0 + kink + Vector3.UP * 1.0, "rx": 0.06, "rot": 0.5}, {"p": p0 - kink + Vector3.UP * 1.7, "rx": 0.05}, {"p": p0 * 1.05 + Vector3.UP * 2.25, "rx": 0.05}], 5, 0.0, 50 + k)
			# tepede çatallı eklem
			S.loft(st, [{"p": p0 * 1.02 + Vector3.UP * 2.2, "rx": 0.035}, {"p": p0 * 1.25 + Vector3.UP * 2.55, "rx": 0.0}], 4, 0.0, 60 + k)
			for y in [0.06, 2.2]:
				S.loft(st, [{"p": p0 + Vector3.UP * y, "rx": 0.045}, {"p": (p0 + p1) * 0.5 + Vector3.UP * (y + 0.04), "rx": 0.055, "rot": 0.3}, {"p": p1 + Vector3.UP * y, "rx": 0.045}], 5, 0.0, 70 + k)
		return S.finish(st))
	var panes = _cached("bunshin_panes", func():
		var st = S.begin()
		for k in 6:
			var a = k * TAU / 6.0
			var a2 = (k + 1) * TAU / 6.0
			var p0 = Vector3(cos(a), 0, sin(a)) * 0.88
			var p1 = Vector3(cos(a2), 0, sin(a2)) * 0.88
			S.quad(st, p0 + Vector3.UP * 0.06, p1 + Vector3.UP * 0.06, p1 + Vector3.UP * 2.2, p0 + Vector3.UP * 2.2, Vector3.UP * 1.1)
		return S.finish(st))
	for sx in [-1.0, 1.0]:
		var at = pj.gp(c.global_position + c.face_dir().cross(Vector3.UP) * 2.5 * sx)
		var root = Node3D.new()
		S.put(pj, root, at)
		root.rotation.y = randf() * TAU
		var fm = S.cmi(cage, {"pal": S.JADE, "alpha": 0.95, "outline": true, "ow": 0.015, "near": 1.2})
		root.add_child(fm)
		var pn = S.cmi(panes, {"pal": S.JADE, "alpha": 0.12, "sheen": 1.0, "two": true, "near": 1.2})
		root.add_child(pn)
		S.grow_up(fm, 2.6, 0.25)
		S.grow_up(pn, 2.6, 0.3)
		S.carpet(pj, at, 1.4, 0.8, {"pal": S.JADE, "t": 0.25, "out": 0.3})
		var tw = root.create_tween()
		tw.tween_interval(0.9)
		tw.tween_callback(func():
			S.shatter(pj, at + Vector3.UP, {"n": 14, "s": 0.18, "r": 0.9, "pal": S.JADE, "v": 4.0}))
		tw.tween_callback(root.queue_free)
		pj.after(0.35, func():
			if pj.live(c):
				pj.decoy(c, at, 10.0, func(pos):
					S.shatter(pj, pos + Vector3.UP, {"n": 16, "s": 0.2, "r": 0.8, "pal": S.JADE, "v": 5.0})
					S.dust(pj, pos + Vector3.UP, {"n": 24, "pal": S.JADE, "spread": 180.0, "vmin": 1.0, "vmax": 4.0})))
	Sfx.play("clink", c.global_position, 1.3)


# ================================================================== Shōton: Kurenai no Kajitsu (Kızıl Meyve)
## Avuçta kızıl kristal yapraklar çiçek gibi açılır, ortasında meyve büyür; fırlatılan meyve dönerek uçar, ardında kızıl
## pırıltı. Çarptığı yerde kıymıklar yağar, dışa eğik kristal dikenleri fışkırır; vurulan kişi Kaynak'taki gibi pembe
## jeodezik kristal kabuğa kapanır (alt yarısı doygun dolgu, beyaz üçgen ağ kenarları, içinde pırıltılar).
static func shoton_kurenai_no_kajitsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 1.0)
	var fl = Node3D.new()
	var petal = _cached("kurenai_petal", func():
		var st = S.begin()
		S.loft(st, [{"p": Vector3(0, 0, 0), "rx": 0.0}, {"p": Vector3(0, 0.08, 0), "rx": 0.05, "ry": 0.012, "up": Vector3(0, 0, 1)}, {"p": Vector3(0, 0.16, 0), "rx": 0.0}], 4, 0.0, 81)
		return S.finish(st))
	var pets: Array = []
	for k in 5:
		var pv = Node3D.new()
		fl.add_child(pv)
		pv.rotation.y = k * TAU / 5.0
		var pm = S.cmi(petal, {"pal": S.CRIMSON, "alpha": 0.9, "near": 0.5})
		pv.add_child(pm)
		pm.position = Vector3(0, 0, 0.02)
		pm.rotation.x = 0.1
		pets.append(pm)
		pm.create_tween().tween_property(pm, "rotation:x", 1.2, 0.35).set_ease(Tween.EASE_OUT)
	var fruit = S.cmi(S.gem_mesh(0.08, 1), {"pal": S.CRIMSON, "alpha": 0.95, "glow": 0.6, "near": 0.5})
	fl.add_child(fruit)
	fruit.position = Vector3.UP * 0.05
	fruit.scale = Vector3.ONE * 0.1
	fruit.create_tween().tween_property(fruit, "scale", Vector3.ONE, 0.4).set_delay(0.1)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(fl)
	else:
		fl.free()
	pj.after(0.5, func():
		if is_instance_valid(ba):
			ba.queue_free()
		if not pj.live(c):
			return
		var o = pj.hand_pos(c)
		var hold = Node3D.new()
		hold.add_child(S.cmi(S.gem_mesh(0.15, 1), {"pal": S.CRIMSON, "alpha": 0.95, "glow": 0.6, "outline": true, "ow": 0.015, "near": 0.8}))
		var pr = pj.shot(c, o, pj.aim_at(c, tt, o), 22.0, hold, pj.inf(c, "shoton_kurenai_no_kajitsu", 0.6, {"knock": 4.0, "kind": "heavy"}), tt, false, 1.6, func(pp, _h):
			S.shatter(pj, pp, {"n": 18, "s": 0.18, "r": 1.0, "v": 7.0, "up": 6.0, "pal": S.CRIMSON, "life": 1.2})
			S.sparkles(pj, pp, {"n": 24, "r": 1.5, "pal": S.PINK})
			for k in 8:
				var a = k * TAU / 8.0
				var hgt = randf_range(0.9, 1.5)
				var sp = S.cmi(S.prism_mesh(hgt, 0.16, 0.3, k % 4), {"pal": S.PINK, "alpha": 0.8, "outline": true, "ow": 0.015, "near": 1.2})
				S.put(pj, sp, pj.gp(pp + Vector3(cos(a), 0, sin(a)) * 2.0))
				sp.rotation = Vector3(sin(a) * deg_to_rad(40.0), 0, -cos(a) * deg_to_rad(40.0))
				S.grow_up(sp, hgt + 0.05, 0.14, k * 0.015)
				S.fade_free(sp, 1.5, 0.35)
			var hs = pj.hit(c, pp, 3.5, pj.inf(c, "shoton_kurenai_no_kajitsu", 1.4, {"knock": 0.0, "kind": "heavy", "bleed": 3.0}))
			for h in hs:
				if not pj.live(h):
					continue
				var hh = float(h.get("height")) if h.get("height") != null else 1.8
				var shell = S.cmi(S.shell_mesh(snappedf(hh * 0.42, 0.05), snappedf(hh * 1.2, 0.05), 8), {"pal": S.PINK, "alpha": 0.38, "fill": hh * 0.32, "two": true, "outline": true, "ow": 0.02, "near": 1.5})
				pj.scene_add(shell, pj.gp(h.global_position))
				shell.rotation.y = randf() * TAU
				S.grow_up(shell, hh * 1.25, 0.25)
				S.flash_in(shell, 0.35)
				var tws = shell.create_tween()
				tws.tween_interval(2.85)
				tws.tween_callback(func(): S.shatter(pj, shell.global_position + Vector3.UP * hh * 0.5, {"n": 16, "s": 0.22, "r": hh * 0.4, "pal": S.PINK}))
				tws.tween_callback(shell.queue_free)
				pj.st(h, "bind", 2.8))
		pr.spin = Vector3(5, 7, 0)
		S.trail(pr, {"pal": S.CRIMSON, "n": 18, "life": 0.4}))
	Sfx.play("clink", c.global_position, 1.3)


# ================================================================== Shōton: Suishō Yari (Kristal Mızrak)
## Kaynak: uzun, keskin kenarlı gümüş-beyaz kristal mızrak; arkasında yıldız gibi açılan kanat bıçakları, çevresinde
## pırıltılar. Elde pırıltı toplanır; mızrak delip geçer, ardında gümüş iz; değdiği yerde kırılma ve çarpma noktasından
## yıldız biçiminde dışa fışkıran kristal sivriler.
static func shoton_suisho_yari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 26.0)
	pj.busy(c, 0.9)
	S.sparkles(pj, pj.hand_pos(c) + Vector3.UP * 0.3, {"n": 18, "r": 0.9, "pal": S.SILVER, "life": 0.5, "vmin": 0.2, "vmax": 0.6})
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var o = pj.hand_pos(c) + Vector3.UP * 0.3
		var lance = _cached("yari_lance", func():
			var st = S.begin()
			S.loft(st, [{"p": Vector3(0, 0, 1.5), "rx": 0.0}, {"p": Vector3(0, 0, 1.1), "rx": 0.16, "rot": PI * 0.25}, {"p": Vector3(0, 0, -1.4), "rx": 0.11, "rot": PI * 0.25}, {"p": Vector3(0, 0, -2.9), "rx": 0.0}], 4, 0.0, 91)
			for k in 4:
				var a = k * TAU / 4.0
				var dv = Vector3(cos(a), sin(a), 0)
				S.loft(st, [{"p": dv * 0.1 + Vector3(0, 0, 0.5), "rx": 0.09, "ry": 0.015, "up": Vector3(0, 0, 1)}, {"p": dv * 0.65 + Vector3(0, 0, 1.3), "rx": 0.0}], 4, 0.0, 92 + k)
			return S.finish(st))
		var spear = Node3D.new()
		spear.add_child(S.cmi(lance, {"pal": S.SILVER, "alpha": 0.82, "outline": true, "ow": 0.02, "near": 1.2}))
		var pr = pj.shot(c, o, pj.aim_at(c, tt, o), 34.0, spear, pj.inf(c, "shoton_suisho_yari", 1.6, {"knock": 14.0, "kind": "heavy", "bleed": 2.0}), tt, true, 1.4, func(pp, _h):
			S.shatter(pj, pp, {"n": 10, "s": 0.2, "r": 0.5, "pal": S.SILVER, "v": 5.0})
			var root = Node3D.new()
			S.put(pj, root, pj.gp(pp))
			for k in 5:
				var dv = Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)).normalized()
				var hgt = randf_range(1.0, 1.8)
				var sp = S.cmi(S.prism_mesh(hgt, 0.14, 0.4, k % 4), {"pal": S.SILVER, "alpha": 0.85, "outline": true, "ow": 0.015, "near": 1.2})
				root.add_child(sp)
				sp.basis = Basis.looking_at(dv, Vector3.UP if absf(dv.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5)
				S.grow_up(sp, hgt + 0.05, 0.12)
			var tw = root.create_tween()
			tw.tween_interval(1.7)
			tw.tween_callback(func(): _sink(root, 1.9, 0.3)))
		S.trail(pr, {"pal": S.SILVER, "n": 26, "life": 0.5, "r": 0.3}))
	Sfx.play("whoosh", c.global_position, 0.9)


# ================================================================== Shōton: Suishō Hadō (Kristal Hapis Dalgası)
## Kaynak: atanın önünde pembe pırıltılı kristal tozu bulutu dalga dalga ileri savrulur, içinde iri pembe kristal parçaları
## süzülür; değdiği düşman Kaynak'taki gibi yüzlü pembe kristal mücevherin içine hapsolur (alt kısmı doygun dolgu,
## kalın beyaz kenarlar), süre sonunda mücevher kırılır.
static func shoton_suisho_hado(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var d = pj.fwd(c, t)
	for k in 6:
		pj.after(0.2 + k * 0.08, func():
			if not pj.live(c):
				return
			var p = c.global_position + Vector3.UP * 1.0 + d * (2.0 + k * 2.4)
			S.dust(pj, p, {"n": 26, "r": 1.0 + k * 0.4, "dir": d, "spread": 60.0, "vmin": 1.0, "vmax": 3.0, "pal": S.PINK, "life": 0.9})
			S.sparkles(pj, p, {"n": 6, "r": 1.0 + k * 0.4, "pal": S.PINK, "life": 0.7})
			var gem = S.particles({"mesh": S.gem_mesh(0.2, k % 4), "mat": S.crystal_mat(), "n": 4, "life": 1.1, "r": 0.8 + k * 0.3, "dir": d, "spread": 40.0,
				"vmin": 0.8, "vmax": 2.0, "g": Vector3(0, -0.3, 0), "smin": 0.7, "smax": 1.3, "cols": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)], "alpha": 0.85, "pal": S.PINK})
			S.put(pj, gem, p)
			gem.emitting = true
			S.free_later(pj, gem, 1.6))
	pj.after(0.6, func():
		for e in pj.enemies_near(c, c.global_position + d * 8.0, 8.0):
			if not (is_instance_valid(e) and not e.is_dead()):
				continue
			var v = e.global_position - c.global_position
			v.y = 0
			if v.normalized().dot(d) < 0.3:
				continue
			_prison(pj, c, e, 3.0, 6, 0.8)
			e.take_hit(pj.inf(c, "shoton_suisho_hado", 0.8, {"knock": 0.0, "kind": "heavy"})))
	Sfx.play("clink", c.global_position, 0.8)


## Kristal hapis: hedefin çevresinde yüzlü pembe mücevher (gerçek boyda), ayak dibinde altıgen halı; süre sonunda kırılır
static func _prison(pj: PathJutsu, c: Node3D, tt: Node3D, dur: float, sides: int, s: float) -> void:
	var at = pj.gp(tt.global_position)
	var gem = _cached("prison_%d_%.2f" % [sides, s], func():
		var st = S.begin()
		var half = PI / sides
		S.loft(st, [{"p": Vector3(0, 0.0, 0), "rx": 0.7 * s * 1.3, "rot": 0.0}, {"p": Vector3(0, 0.9 * s, 0), "rx": 1.25 * s * 1.1, "rot": half},
			{"p": Vector3(0, 2.4 * s, 0), "rx": 1.2 * s * 1.1, "rot": 0.0}, {"p": Vector3(0, 3.4 * s, 0), "rx": 0.6 * s, "rot": half}], sides, 0.0, 99, true, true)
		return S.finish(st))
	var mi = S.cmi(gem, {"pal": S.PINK, "alpha": 0.36, "fill": 1.2 * s, "two": true, "outline": true, "ow": 0.02, "near": 1.5})
	S.put(pj, mi, at)
	mi.rotation.y = randf() * TAU
	S.grow_up(mi, 3.5 * s, 0.25)
	S.flash_in(mi, 0.3)
	S.carpet(pj, at, 2.0, dur, {"t": 0.3, "out": 0.4})
	var tw = mi.create_tween()
	tw.tween_interval(dur + 0.25)
	tw.tween_callback(func():
		S.shatter(pj, at + Vector3.UP * 1.5 * s, {"n": 18, "s": 0.25, "r": 1.0, "pal": S.PINK, "v": 6.0})
		S.dust(pj, at + Vector3.UP * 1.5 * s, {"n": 30, "spread": 180.0, "vmin": 2.0, "vmax": 6.0}))
	tw.tween_callback(mi.queue_free)
	pj.st(tt, "bind", dur + 0.3)
	Combat.popup_text(at + Vector3.UP * 3.4, "Kristale hapsoldu!", PINK_C)


# ================================================================== Shōton: Suishō Hari (Kristal İğneler)
## Kaynak: iri, yüzlü, uçları sivri pembe kristal iğneler (beyaz kenar, koyu pembe yüzler). Elden yelpaze gibi on iğne
## fırlar, ardında pırıltı; değdiği yerde yerden çalı gibi açılan sivri pembe kristal demeti fışkırır ve söner.
static func shoton_suisho_hari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 22.0)
	pj.busy(c, 0.8)
	var needle = S.prism_mesh(1.2, 0.07, 0.4, 0, 6)
	for k in 10:
		pj.after(0.2 + k * 0.03, func():
			if not pj.live(c):
				return
			var o = pj.hand_pos(c)
			var dir = pj.aim_at(c, tt, o).rotated(Vector3.UP, randf_range(-0.15, 0.15))
			var nd = Node3D.new()
			var nm = S.cmi(needle, {"pal": S.PINK, "alpha": 0.93, "outline": true, "ow": 0.012, "near": 1.0})
			nd.add_child(nm)
			nm.rotation.x = -PI * 0.5   # +Y ucu ileriye (-Z)
			nm.position = Vector3(0, 0, 0.6)
			var pr = pj.shot(c, o, dir, 40.0, nd, pj.inf(c, "shoton_suisho_hari", 0.22, {"knock": 2.0, "kind": "light", "bleed": 1.0}), null, false, 0.9, func(pp, _h):
				_bloom(pj, pj.gp(pp)))
			if k % 2 == 0:
				S.trail(pr, {"n": 10, "life": 0.3, "smin": 0.08, "smax": 0.16}))
	Sfx.play("whoosh", c.global_position, 1.6)


## Yerden çalı gibi açılan pembe kristal demeti (1.8 sn)
static func _bloom(pj: PathJutsu, at: Vector3) -> void:
	var root = Node3D.new()
	S.put(pj, root, at)
	for k in 7:
		var hgt = randf_range(0.7, 1.7)
		var sp = S.cmi(S.prism_mesh(snappedf(hgt, 0.1), 0.12, 0.3, k % 4), {"pal": S.PINK, "alpha": 0.9, "outline": true, "ow": 0.012, "near": 1.2})
		root.add_child(sp)
		sp.position = Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		sp.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
		S.grow_up(sp, hgt + 0.05, 0.12, k * 0.012)
	S.chips(pj, at + Vector3.UP * 0.2, {"n": 6, "r": 0.3, "dir": Vector3.UP, "spread": 60.0, "vmin": 2.0, "vmax": 5.0})
	var tw = root.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func(): _sink(root, 1.8, 0.3))


# ================================================================== Shōton: Hashō Kōryū (Kırık Kristal İnen Ejder)
## Kaynak yok, tasarım: atanın arkasında yerde altıgen kristal halısı yayılır, pembe kristal ejder başı (altıgen kesitli
## kafatası, açık çene, geriye uzanan prizma boynuzlar, beyaz parlayan gözler) beyaz parıltıyla oluşur; gövdesi sırtı
## prizma pullu altıgen halkalardan, başın kıvrılarak çizdiği yolu izler, yol boyunca pırıltı dökülür. Hedefe dalınca kristal
## patlar, yer altıgen kristalle kaplanır, dışa eğik sütunlar fışkırır; gövde halka halka kırılıp dağılır.
static func shoton_hasho_koryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 1.4)
	var a = c.global_position + Vector3.UP * 2.0 - c.face_dir() * 1.5
	var b2 = (tt.global_position if is_instance_valid(tt) else c.global_position + pj.fwd(c, t) * 22.0)
	S.carpet(pj, c.global_position - c.face_dir() * 1.5, 3.2, 1.2, {"t": 0.35})
	S.sparkles(pj, a, {"n": 24, "r": 1.4, "life": 0.7})
	var head = Node3D.new()
	pj.scene_add(head, a)
	var hm = _hasho_head()
	head.add_child(hm)
	hm.scale = Vector3.ONE * 0.3
	hm.create_tween().tween_property(hm, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	for ch in hm.get_children():
		if ch is GeometryInstance3D:
			S.flash_in(ch, 0.4)
	S.free_later(pj, head, 4.0)
	S.trail(head, {"n": 30, "life": 0.6, "r": 0.6, "smin": 0.14, "smax": 0.3})
	_hasho_body(pj, head)
	pj.after(0.3, func():
		pj.slither(head, a + Vector3.UP * 3.0, b2, 1.0, 2.2, func():
			S.shatter(pj, b2 + Vector3.UP, {"n": 22, "s": 0.3, "r": 1.5, "v": 7.0, "up": 5.0})
			pj.shake(0.6)
			S.carpet(pj, b2, 4.5, 2.2, {"t": 0.35})
			for k in 10:
				var an = k * TAU / 10.0
				var hgt = randf_range(1.2, 2.4)
				var sp = S.cmi(S.prism_mesh(snappedf(hgt, 0.1), randf_range(0.2, 0.32), 0.45, k % 4), {"pal": S.PINK, "alpha": 0.82, "outline": true, "ow": 0.02, "near": 1.5})
				S.put(pj, sp, pj.gp(b2 + Vector3(cos(an), 0, sin(an)) * randf_range(0.8, 3.0)))
				sp.rotation = Vector3(sin(an) * deg_to_rad(30.0), randf() * TAU, -cos(an) * deg_to_rad(30.0))
				S.grow_up(sp, hgt + 0.05, 0.15, k * 0.02)
				var tw = sp.create_tween()
				tw.tween_interval(2.5)
				tw.tween_callback(func(): _sink(sp, hgt + 0.1, 0.35))
			pj.hit(c, b2 + Vector3.UP, 3.8, pj.inf(c, "shoton_hasho_koryu", 2.4, {"knock": 16.0, "launch": 4.0, "kind": "heavy"}))
			pj.after(0.3, func():
				if is_instance_valid(head):
					head.queue_free())))
	Sfx.play("roar", c.global_position, 1.3)


## Kristal ejder başı (ileri -Z, ~2.4 m)
static func _hasho_head() -> Node3D:
	var root = Node3D.new()
	var skull = _cached("hasho_skull", func():
		var st = S.begin()
		S.loft(st, [{"p": Vector3(0, 0.1, 0.7), "rx": 0.6, "ry": 0.55}, {"p": Vector3(0, 0.2, 0.1), "rx": 0.7, "ry": 0.6}, {"p": Vector3(0, 0.15, -0.7), "rx": 0.5, "ry": 0.38},
			{"p": Vector3(0, 0.1, -1.4), "rx": 0.32, "ry": 0.24}, {"p": Vector3(0, 0.05, -1.65), "rx": 0.0}], 6, 0.0, 111)
		S.loft(st, [{"p": Vector3(0, -0.3, 0.3), "rx": 0.48, "ry": 0.2}, {"p": Vector3(0, -0.55, -0.7), "rx": 0.34, "ry": 0.14}, {"p": Vector3(0, -0.66, -1.35), "rx": 0.0}], 6, 0.0, 112)
		for sx in [-1.0, 1.0]:
			S.loft(st, [{"p": Vector3(0.3 * sx, 0.55, 0.3), "rx": 0.14}, {"p": Vector3(0.55 * sx, 1.0, 1.4), "rx": 0.09}, {"p": Vector3(0.7 * sx, 1.25, 2.3), "rx": 0.0}], 6, 0.0, 113)
			S.loft(st, [{"p": Vector3(0.5 * sx, 0.1, 0.5), "rx": 0.1}, {"p": Vector3(1.0 * sx, 0.0, 1.3), "rx": 0.0}], 6, 0.0, 114)
			for i in 3:
				S.loft(st, [{"p": Vector3(0.28 * sx, -0.1, -0.5 - i * 0.3), "rx": 0.05}, {"p": Vector3(0.27 * sx, -0.38, -0.52 - i * 0.3), "rx": 0.0}], 4, 0.0, 115)
		return S.finish(st))
	root.add_child(S.cmi(skull, {"pal": S.PINK, "alpha": 0.86, "outline": true, "ow": 0.03, "glow": 0.2, "near": 2.0}))
	var em = StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.97, 1.0)
	for sx in [-1.0, 1.0]:
		var e = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.1
		sm.radial_segments = 6
		sm.rings = 3
		e.mesh = sm
		e.material_override = em
		root.add_child(e)
		e.position = Vector3(0.42 * sx, 0.38, -0.35)
	return root


## Kristal gövde: başın yolunu izleyen 18 altıgen halka (sırtında prizma pul); baş yok olunca halkalar uçtan kırılır
static func _hasho_body(pj: PathJutsu, head: Node3D) -> void:
	var seg = _cached("hasho_seg", func():
		var st = S.begin()
		S.loft(st, [{"p": Vector3(0, 0, 0.75), "rx": 0.62}, {"p": Vector3(0, 0, -0.75), "rx": 0.7, "rot": 0.0}], 6, 0.0, 121, true, true)
		for i in 3:
			var a = -0.7 + i * 0.7
			S.loft(st, [{"p": Vector3(sin(a) * 0.55, cos(a) * 0.55, 0.0), "rx": 0.13}, {"p": Vector3(sin(a) * 1.15, cos(a) * 1.15, 0.6), "rx": 0.0}], 6, 0.0, 122 + i)
		return S.finish(st))
	var root = Node3D.new()
	S.put(pj, root, head.global_position)
	var n = 18
	var segs: Array = []
	for i in n:
		var mi = S.cmi(seg, {"pal": S.PINK, "alpha": 0.82, "outline": true, "ow": 0.025, "near": 2.0})
		root.add_child(mi)
		mi.top_level = true
		mi.visible = false
		segs.append(mi)
	var hist: Array = [head.global_position]
	var wh = weakref(head)
	var s0 = {"head": head.global_position, "dead": false, "tk": 0}
	var sp = 0.85
	var upd = func(_tn: float):
		if not is_instance_valid(root):
			return
		var hd = wh.get_ref()
		if hd != null and is_instance_valid(hd):
			var hp: Vector3 = hd.global_position
			if hp.distance_to(hist[hist.size() - 1]) > 0.15:
				hist.append(hp)
				if hist.size() > 300:
					hist.pop_front()
			s0["head"] = hp
		elif not s0["dead"]:
			s0["dead"] = true
			for ii in n:
				var sg0: MeshInstance3D = segs[ii]
				if sg0.visible and ii % 2 == 0:
					S.shatter(pj, sg0.global_position, {"n": 4, "s": 0.2, "r": 0.5, "v": 3.0, "up": 2.0, "life": 0.8})
			root.queue_free()
			return
		var pa: Vector3 = s0["head"]
		var acc = 0.0
		var need = sp * 1.5
		var bi = hist.size() - 1
		var i = 0
		while i < n and bi >= 0:
			var pb: Vector3 = hist[bi]
			var lab = pa.distance_to(pb)
			if lab > 0.0001 and acc + lab >= need:
				var q = pa.lerp(pb, (need - acc) / lab)
				var sg: MeshInstance3D = segs[i]
				sg.visible = true
				sg.global_position = q
				var f = (pa - pb).normalized()
				sg.global_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.97 else Vector3.RIGHT).scaled(Vector3.ONE * lerpf(1.0, 0.35, float(i) / (n - 1)))
				i += 1
				need += sp
				continue
			acc += lab
			pa = pb
			bi -= 1
		s0["tk"] += 1
		if int(s0["tk"]) % 9 == 0:
			var sgs: MeshInstance3D = segs[randi() % n]
			if sgs.visible:
				S.sparkles(pj, sgs.global_position, {"n": 4, "r": 0.5, "life": 0.5})
	var tw = root.create_tween()
	tw.tween_method(upd, 0.0, 5.0, 5.0)
	tw.tween_callback(func():
		if is_instance_valid(root):
			root.queue_free())
