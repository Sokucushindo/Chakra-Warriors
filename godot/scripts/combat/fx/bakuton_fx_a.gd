class_name BakutonFXA
extends RefCounted
## Bakuton grubu A: patlayıcı kil sanatı (C1, C2, C3, C4, C0) ve Iwa patlama yumrukları (Jiraiken ailesi).
## Malzeme ve yapı taşları BakutonLib'den (kendi kil / patlama / duman / halka / kurum shader'ları); her tekniğin şekli,
## hareketi ve sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı, zemin yarığı bölgeleri, ses, sarsıntı)
## ana ağaçtaki işleyicilerden satır satır taşındı.

const L = preload("res://scripts/combat/fx/lib/bakuton_lib.gd")

static var _cache := {}


# ================================================================== eski ortak yardımcıların OYUN tarafı (görselsiz)
## Yarık zemin: üstünden geçen yavaşlar (eski çatlak izinin oyun tarafı; boy >= 1.5)
static func _crack_zone(g: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(g, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


## Eski kil patlamasının oyun tarafı: ses, sarsıntı, zemine yakınsa yarık bölge
static func _blast_side(pj: PathJutsu, pos: Vector3, s: float) -> void:
	var g = L.floor_at(pos)
	if pos.y - g.y < 3.5 * s:
		_crack_zone(g, 4.5 * s, 8.0)
	pj.shake(0.6 * s)
	Sfx.play("boom", pos)


## Eski Bakuton isabetinin oyun tarafı (kil patlaması 1.1*s + yakın zemin yarığı + sarsıntı)
static func _impact_side(pj: PathJutsu, at: Vector3, s: float) -> void:
	_blast_side(pj, at, 1.1 * s)
	var g = L.floor_at(at)
	if at.y - g.y < 2.5:
		_crack_zone(g, 2.5 * s, 6.0)
	pj.shake(0.25 + 0.25 * s)


## Yakın dövüş vuruşu (eski mhit'in oyun tarafı): isabet + sarsıntı (+ ağır vuruşta yarık zemin). Görsel tekniğin kendisinde.
static func _mhit(pj: PathJutsu, c: Node3D, pos: Vector3, r: float, info: Dictionary, exclude: Array = []) -> Array:
	var hs = pj.hit(c, pos, r, info, exclude)
	if not hs.is_empty():
		var heavy = String(info.get("kind", "")) == "heavy"
		var s = clampf(0.8 + float(info.get("knock", 4.0)) * 0.04 + absf(float(info.get("launch", 0.0))) * 0.03, 0.8, 1.8)
		var ms = s if heavy else s * 0.7
		if heavy and s > 1.3:
			_crack_zone(pj.gp(hs[0].global_position), 3.0 * ms)
		pj.shake(0.2 + 0.3 * ms)
	return hs


# ================================================================== C1: kil kuşlar / örümcekler / böcek
## Avuç ağzı kili çiğner; kuş, örümcek, kuş, böcek sırayla ağızdan esneyerek doğar ve hedefe süzülür.
## Çarpınca "katsu": küçük sivri beyaz parlama, avuç büyüklüğünde kabaran top, savrulan kil kırıntısı, tek topak duman.
static func shi_wan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 26.0)
	var from = pj.hand_pos(c, true)
	L.palm_mouth(pj, c, true, 0.65)
	for k in 4:
		pj.after(0.15 + k * 0.12, func():
			if not pj.live(c):
				return
			var fig: Node3D
			match k:
				1:
					fig = L.spider(1.3)
				3:
					fig = L.beetle(1.6)
				_:
					fig = L.bird(1.3)
			var pr = pj.shot(c, from + Vector3.UP * 0.3, (pj.aim_at(c, tt, from) + Vector3.UP * 0.25).normalized(), 18.0, fig, pj.inf(c, "shi_wan", 0.7, {"knock": 10.0, "launch": 4.0, "kind": "heavy", "element": "bakuton"}), tt, false, 2.5, func(p, _h):
				_c1_pop(pj, p))
			pr.homing_turn = 5.0
			L.pop_in(fig, 0.16, 1.0)
			L.shrapnel(pj, from, 3, 1.4, 0.035, {"up": 0.1, "life": 0.6}))
	Sfx.play("poof", from, 1.4)


static func _c1_pop(pj: PathJutsu, p: Vector3) -> void:
	L.flash(pj, p, 2.2, 0.22, {"spikes": 7.0, "near": 3.0})
	L.fireball(pj, p, 0.3, 1.25, 0.9, {"rise": 1.4, "near": 4.0, "grow": 0.25})
	L.shrapnel(pj, p, 6, 7.0, 0.09)
	L.puff(pj, p + Vector3.UP * 0.4, 0.45, 1.3, Vector3(randf_range(-0.4, 0.4), 1.4, randf_range(-0.4, 0.4)), {"gray": 0.4, "near": 3.0})
	L.sparks(pj, p, 12, 0.2, {"vmin": 3.0, "vmax": 8.0, "life": 0.4})
	L.light(pj, p, Color(1.0, 0.88, 0.6), 3.0, 8.0, 0.3)
	var fl = L.floor_at(p)
	if p.y - fl.y < 1.2:
		L.soot(pj, fl, 1.2, 5.0, {"heat": 0.5})
	_blast_side(pj, p, 1.1)


# ================================================================== C2: kil ejderi + güdümlü füzeler
## Avuçtan tükürülen kil topağı havada şişip ejdere dönüşür; kanatlar süzülür, kuyruk sallanır. Baş her atışta öne eğilip
## ağzından boğumlu kil füze tükürür (füze gövdesi uçarken kıvrılır). Füze isabeti: zemine oturan orta patlama + halka + kurum.
## Ömrünün sonunda ejder içten kızarır, çatlakları ışıldar ve gövde boyunca üç noktadan parçalanarak patlar.
static func shi_tsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 30.0)
	var at = c.global_position + Vector3.UP * 5.5 - c.face_dir() * 5.0
	# ejder kameranın görüş alanında durur: kullananın önünde-yanında, yukarıda (arkasında kameranın içinde kalıyordu)
	var fd = c.face_dir()
	var side = fd.cross(Vector3.UP).normalized()
	var dpos = c.global_position + fd * 2.5 + side * 4.5 + Vector3.UP * 6.0
	L.palm_mouth(pj, c, true, 0.4)
	var blob = L.lump(0.6, 4.0)
	L.put(pj, blob, dpos)
	var tb = blob.create_tween()
	tb.tween_property(blob, "scale", Vector3.ONE * 4.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tb.tween_callback(blob.queue_free)
	var dragon = L.dragon(1.3, 4.5)
	pj.get_tree().current_scene.add_child(dragon)
	dragon.global_position = dpos
	dragon.look_at(dpos + fd, Vector3.UP)
	dragon.scale = Vector3.ONE * 0.1
	var tw = dragon.create_tween()
	tw.tween_property(dragon, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.6)
	tw.tween_callback(func(): L.fuse(dragon, 0.4, 0.9))
	tw.tween_interval(0.4)
	tw.tween_callback(func(): _c2_self_destruct(pj, dragon, at))
	tw.tween_callback(dragon.queue_free)
	for k in 5:
		pj.after(0.6 + k * 0.4, func():
			if not is_instance_valid(dragon) or not pj.live(c):
				return
			# füze ejderin ağzından çıkar
			var from = dragon.global_position + c.face_dir() * 4.3
			if dragon.has_meta("mouth") and is_instance_valid(dragon.get_meta("mouth")):
				from = (dragon.get_meta("mouth") as Node3D).global_position
			_c2_nod(dragon)
			var fig = L.missile(1.0)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 20.0, fig, pj.inf(c, "shi_tsu", 0.7, {"knock": 12.0, "launch": 4.0, "kind": "heavy", "element": "bakuton"}), tt, false, 3.0, func(p, _h):
				_c2_hit(pj, p)
				pj.hit(c, p, 3.5, pj.inf(c, "shi_tsu", 0.4, {"knock": 8.0, "kind": "heavy", "element": "bakuton"})))
			pr.homing_turn = 3.5
			L.pop_in(fig, 0.12, 1.0)
			var age = {"t": randf() * 3.0}
			pr.on_tick = func(_p: Projectile, dt: float) -> void:
				age["t"] += dt
				if is_instance_valid(fig):
					fig.rotation.z = sin(age["t"] * 13.0) * 0.35
					fig.rotation.y = sin(age["t"] * 9.0) * 0.12)
	Sfx.play("roar", at, 1.3)


## Baş öne eğilip geri kalkar (tükürme)
static func _c2_nod(dragon: Node3D) -> void:
	if not dragon.has_meta("head"):
		return
	var head: Node3D = dragon.get_meta("head")
	if not is_instance_valid(head):
		return
	var tw = head.create_tween()
	tw.tween_property(head, "rotation:x", -0.35, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(head, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _c2_hit(pj: PathJutsu, p: Vector3) -> void:
	L.flash(pj, p, 4.0, 0.3, {"spikes": 10.0, "near": 6.0})
	L.fireball(pj, p, 0.5, _cam_cap(pj, p, 2.2), 1.3, {"rise": 1.6, "near": 7.0})
	for k in 3:
		var a = k * TAU / 3.0 + randf() * 0.6
		var off = Vector3(cos(a), 0.4, sin(a))
		L.puff(pj, p + off * 1.2, minf(0.7, _cam_cap(pj, p, 0.7)), 1.6, off * 1.4 + Vector3.UP * 1.2, {"gray": 0.3, "hot": 0.5, "near": 7.0})
	var fl = L.floor_at(p)
	if p.y - fl.y < 2.5:
		L.ring(pj, fl + Vector3.UP * 0.12, 0.8, 4.5, 0.6, Vector3.UP, {"near": 7.0})
		L.soot(pj, fl, 3.2, 8.0, {"heat": 0.7, "cracks": 0.5})
	L.shrapnel(pj, p, 10, 11.0, 0.16)
	L.sparks(pj, p, 22, 0.5, {"vmin": 5.0, "vmax": 13.0})
	L.light(pj, p, Color(1.0, 0.86, 0.6), 6.0, 16.0, 0.45)
	_blast_side(pj, p, 2.8)


## Ejderin kendini patlatması: baş, gövde ve kuyruktan sırayla üç kabaran top, iri kil parçaları, geniş gri topaklar
static func _c2_self_destruct(pj: PathJutsu, dragon: Node3D, side_at: Vector3) -> void:
	if not is_instance_valid(dragon):
		return
	var pos = dragon.global_position
	var fw = -dragon.global_basis.z.normalized()
	var pts = [pos + fw * 5.0, pos, pos - fw * 5.5]
	if dragon.has_meta("head") and is_instance_valid(dragon.get_meta("head")):
		pts[0] = (dragon.get_meta("head") as Node3D).global_position + fw * 1.2
	L.flash(pj, pos, 9.0, 0.35, {"spikes": 11.0, "near": 9.0})
	for i in 3:
		var p: Vector3 = pts[i]
		var dly = i * 0.07
		var one = func():
			L.fireball(pj, p, 0.8, _cam_cap(pj, p, 3.8 - i * 0.6), 2.0, {"rise": 1.8, "near": 9.0, "grow": 0.25})
			L.shrapnel(pj, p, 6, 14.0, 0.5, {"life": 1.8})
		if dly <= 0.0:
			one.call()
		else:
			pj.get_tree().create_timer(dly).timeout.connect(one)
	for k in 4:
		var a = k * TAU / 4.0 + randf() * 0.5
		var off = Vector3(cos(a), 0.25, sin(a))
		var pp = pos + off * 3.0
		L.puff(pj, pp, minf(1.6, _cam_cap(pj, pp, 1.6)), 2.6, off * 2.5 + Vector3.UP * 1.5, {"gray": 0.45, "hot": 0.5, "near": 9.0})
	L.sparks(pj, pos, 50, 3.0, {"vmin": 8.0, "vmax": 20.0, "life": 0.8, "size": 0.22})
	L.light(pj, pos, Color(1.0, 0.86, 0.6), 14.0, 40.0, 0.7)
	_blast_side(pj, side_at, 4.5)   # oyun tarafı eski konumda (ejderin mantıksal yeri)


## Kameraya dönük taraf: top yüzeyi kameraya 6 m'den fazla yaklaşmasın (ekranı kaplamasın); en az 0.6 m
static func _cam_cap(pj: PathJutsu, p: Vector3, r: float) -> float:
	var cam = pj.get_viewport().get_camera_3d() if pj.get_viewport() else null
	if cam == null:
		return r
	return clampf(cam.global_position.distance_to(p) - 6.0, 0.6, r)


# ================================================================== C3: dev kil heykel
## Ağızdan küçük kil heykel (damla gövde, O ağız, karnını saran kollar) tükürülür, havada büyüyüp yayla hedefe süzülür,
## inerken içten kızarır. Patlama (anime): soluk sarı dev parlayan küre bir an asılı kalır, dibini koyu tırtıklı duman yakası
## sarar, geniş zemin halkası, uçuşan kaya, ışınsal yarıklı geniş kurum.
static func shi_suri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 34.0)
	var goal = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 16.0)
	var fig = L.c3_doll(1.0, 3.0)
	pj.get_tree().current_scene.add_child(fig)
	var start = pj._mouth_pos(c) + c.face_dir() * 0.6
	fig.global_position = start
	fig.scale = Vector3.ONE * 0.1
	var mid = start.lerp(goal, 0.5) + Vector3.UP * 8.0
	var tw = fig.create_tween()
	fig.look_at(goal, Vector3.UP)
	tw.tween_property(fig, "scale", Vector3.ONE * 2.2, 0.4)
	tw.tween_method(func(u: float):
		if is_instance_valid(fig):
			fig.global_position = start.lerp(mid, u).lerp(mid.lerp(goal + Vector3.UP, u), u), 0.0, 1.0, 1.0)
	tw.tween_callback(func():
		fig.queue_free()
		if not pj.live(c):
			return
		_c3_blast(pj, goal)
		pj.hit(c, goal + Vector3.UP, 15.0, pj.inf(c, "shi_suri", 3.6, {"knock": 30.0, "launch": 10.0, "kind": "heavy", "element": "bakuton", "hitstop": 0.15}))
		pj.shake(2.0))
	# inişin son anlarında heykel içten kızarır
	pj.get_tree().create_timer(1.05).timeout.connect(func():
		if is_instance_valid(fig):
			L.fuse(fig, 0.35, 0.8))
	L.shrapnel(pj, start, 4, 1.6, 0.05, {"up": 0.2, "life": 0.7})
	Sfx.play("boom", c.global_position, 1.2)


static func _c3_blast(pj: PathJutsu, goal: Vector3) -> void:
	var o = goal + Vector3.UP * 2.0
	L.flash(pj, o, 22.0, 0.35, {"spikes": 12.0, "near": 9.0})
	L.fireball(pj, o + Vector3.UP * 2.0, 1.0, 11.5, 2.6, {"pal": L.PAL_ORB, "near": 9.0, "rise": 0.3, "grow": 0.15, "cool": 0.9, "heat": 1.5, "lump": 0.6})
	for k in 14:
		var a = k * TAU / 14.0 + randf() * 0.2
		var dirv = Vector3(cos(a), 0.0, sin(a))
		L.puff(pj, goal + dirv * 8.5 + Vector3.UP * randf_range(0.8, 2.2), randf_range(2.0, 2.8), 3.2, dirv * 3.0 + Vector3.UP * 0.6, {"gray": 0.75, "near": 8.0, "grow": 1.5})
	L.ring(pj, goal + Vector3.UP * 0.2, 3.0, 24.0, 0.9, Vector3.UP, {"w": 0.18, "near": 9.0})
	L.soot(pj, goal, 16.0, 12.0, {"heat": 0.9, "cracks": 1.0, "grow": 0.4})
	L.shrapnel(pj, o, 30, 22.0, 0.55, {"col": L.STONE, "up": 0.9, "life": 2.0})
	L.sparks(pj, o, 60, 4.0, {"vmin": 10.0, "vmax": 26.0, "life": 1.0, "size": 0.3})
	L.light(pj, o, Color(1.0, 0.92, 0.6), 30.0, 60.0, 1.4)
	_blast_side(pj, o, 5.85)
	_crack_zone(goal, 24.0)


# ================================================================== C4 Karura
## Önünde dev kil kopya şişerek belirir; yüzeyi çatlayıp ışıldar, sonra kil kenarları kızararak ufalanır ve beden binlerce
## minik beyaz bombaya (zerre bulutu) dağılarak hedefe akar. Bulutu soluyanların bedeni içten pul pul kopar: gri parçalar
## savrulur, gövdenin üstünde art arda minik patlamalar çakar (büyük patlama yok).
static func shi_fo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(c.global_position + c.face_dir() * 5.0)
	var giant = L.giant(9.0, 7.0)
	pj.get_tree().current_scene.add_child(giant)
	giant.global_position = at
	giant.look_at(at + c.face_dir(), Vector3.UP)
	giant.scale = Vector3.ONE * 0.05
	var goal = pj.gp(tt.global_position if tt else at + c.face_dir() * 10.0)
	var tw = giant.create_tween()
	tw.tween_property(giant, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func(): L.fuse(giant, 0.3, 1.0))
	tw.tween_interval(0.3)
	tw.tween_callback(func(): _c4_disperse(pj, giant, at, goal))
	tw.tween_interval(0.55)
	tw.tween_callback(giant.queue_free)
	pj.after(1.2, func():
		if not pj.live(c):
			return
		for e in pj.enemies_near(c, goal, 9.0):
			if not is_instance_valid(e) or e.is_dead():
				continue
			_c4_inside(pj, e)
			e.take_hit(pj.inf(c, "shi_fo", 3.0, {"knock": 0.0, "kind": "heavy", "element": "bakuton", "bleed": 6.0, "hitstop": 0.1})))
	Sfx.play("smoke", at, 0.6)


static func _c4_disperse(pj: PathJutsu, giant: Node3D, at: Vector3, goal: Vector3) -> void:
	if not is_instance_valid(giant):
		return
	L.tp(giant, "melt", 0.0, 1.0, 0.5)
	var d = goal - at
	d.y = 0.0
	var dn = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	# mikro bomba bulutu: gövdeden kopup hedefe akan beyaz zerreler (iki dalga: yoğun çekirdek + geniş saçak)
	L.flakes(pj, at + Vector3.UP * 4.5, 260, 3.0, {"col0": Color(0.98, 0.97, 0.93), "col1": Color(0.9, 0.89, 0.85), "dir": dn, "spread": 40.0,
		"vmin": 2.0, "vmax": 6.0, "g": Vector3(0, -0.3, 0), "damp": 0.6, "life": 2.4, "size": 0.09, "burst": 0.6, "turb": 1.2, "spin": 400.0})
	L.flakes(pj, at + Vector3.UP * 3.0, 160, 3.8, {"col0": Color(0.95, 0.94, 0.9), "col1": Color(0.86, 0.85, 0.82), "dir": (dn + Vector3.UP * 0.2).normalized(), "spread": 70.0,
		"vmin": 1.0, "vmax": 3.5, "g": Vector3(0, -0.15, 0), "damp": 0.4, "life": 2.8, "size": 0.07, "burst": 0.3, "turb": 1.6, "spin": 400.0})
	L.light(pj, at + Vector3.UP * 4.5, Color(1.0, 0.95, 0.85), 3.0, 14.0, 0.6)


## Bedenin içinden kopuş: gri pullar dışa savrulur, gövdenin üstünde art arda minik sıcak çakmalar
static func _c4_inside(pj: PathJutsu, e: Node3D) -> void:
	var base = e.global_position
	L.flakes(pj, base + Vector3.UP * 1.0, 50, 0.45, {"col0": Color(0.42, 0.4, 0.4), "col1": Color(0.62, 0.6, 0.59), "dir": Vector3.UP, "spread": 180.0,
		"vmin": 1.5, "vmax": 5.0, "g": Vector3(0, -1.5, 0), "life": 1.5, "size": 0.14, "burst": 0.7})
	for j in 5:
		var q = base + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.6), randf_range(-0.3, 0.3))
		var pop = func():
			L.flash(pj, q, 0.6, 0.14, {"spikes": 5.0, "warm": 0.6, "near": 1.5})
			L.sparks(pj, q, 5, 0.05, {"vmin": 2.0, "vmax": 5.0, "life": 0.3, "size": 0.08})
		pj.get_tree().create_timer(j * 0.06).timeout.connect(pop)
	L.light(pj, base + Vector3.UP, Color(1.0, 0.8, 0.55), 2.5, 5.0, 0.35)


# ================================================================== C0
## Beden kararır ve şişer, göğüste dikişli ağız açılır (dikişler kopar), bedenden kara kil külü yükselir.
## Patlama (anime): göğe uzanan sivri beyaz yıldız sütunu, çevresinde iki eğik ince yörünge halkası, zemine oturan beyaz-camgöbeği
## kubbe; ışık sönerken geniş gri duman yakası, uçuşan moloz, yağan kül ve ışınsal yarıklı dev kurum.
static func shi_o(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 2.0)
	var at = c.global_position
	# modelin kendi toon malzemelerinin kopyası karartılır; patlamada eskileri geri konur
	var saved = []
	var mdl: Node3D = c.model if "model" in c and c.model else c
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var orig = mi.material_override
		var src = orig if orig else (mi.mesh.surface_get_material(0) if mi.mesh and mi.mesh.get_surface_count() > 0 else null)
		if src is ShaderMaterial and src.get_shader_parameter("tint") != null:
			var dm: ShaderMaterial = src.duplicate()
			saved.append([mi, orig, dm])
			mi.material_override = dm
	var tw0 = mdl.create_tween()
	tw0.tween_method(func(k: float):
		for e in saved:
			e[2].set_shader_parameter("tint", Color.WHITE.lerp(Color(0.1, 0.09, 0.11), k)), 0.0, 1.0, 1.1)
	tw0.parallel().tween_property(mdl, "scale", Vector3.ONE * 1.12, 1.2)
	L.chest_mouth(pj, c, 1.4, 1.0)
	for k in 10:
		pj.after(k * 0.12, func():
			if pj.live(c):
				L.flakes(pj, c.global_position + Vector3.UP * 1.0, 10, 0.5, {"col0": Color(0.08, 0.07, 0.08), "col1": Color(0.16, 0.15, 0.15), "dir": Vector3.UP, "spread": 50.0,
					"vmin": 0.4, "vmax": 1.4, "g": Vector3(0, 0.4, 0), "life": 1.2, "size": 0.12, "burst": 0.3}))
	pj.after(1.4, func():
		for e in saved:
			if is_instance_valid(e[0]):
				e[0].material_override = e[1]
		if is_instance_valid(mdl):
			mdl.scale = Vector3.ONE
		var o = at + Vector3.UP
		_c0_blast(pj, at, o)
		_crack_zone(pj.gp(at), 22.0)
		if pj.live(c):
			pj.hit(c, o, 15.0, pj.inf(c, "shi_o", 6.0, {"knock": 36.0, "launch": 12.0, "kind": "heavy", "element": "bakuton", "hitstop": 0.2}))
			if c is Player:
				c.hp = maxf(1.0, c.hp * 0.1)
		Sfx.play("boom", o, 0.4)
		pj.shake(2.6))
	Sfx.play("charge", at, 0.6)


static func _c0_blast(pj: PathJutsu, at: Vector3, o: Vector3) -> void:
	var g = L.floor_at(at)
	# göğe uzanan beyaz sütun: üst üste kabaran beyaz-camgöbeği toplar (kamera kullananın yakınında olduğundan dev kubbe
	# yerine dar, uzun sütun: kameranın içinde kalmaz, 2.5 sn görünür)
	for k in 6:
		var h = 3.0 + k * 4.0
		var dly = k * 0.06
		var one = func():
			L.fireball(pj, g + Vector3.UP * h, 0.8, 2.6 - k * 0.12, 2.8, {"pal": L.PAL_WHITE, "near": 5.0, "rise": 1.2, "grow": 0.2, "heat": 1.7, "cool": 0.85, "lump": 0.8})
		pj.get_tree().create_timer(dly).timeout.connect(one)
	# tepede sivri beyaz yıldız
	L.flash(pj, g + Vector3.UP * 23.0, 20.0, 2.2, {"spikes": 5.0, "near": 6.0, "stretch": Vector2(0.8, 1.0)})
	L.flash(pj, g + Vector3.UP * 9.0, 12.0, 1.2, {"spikes": 7.0, "near": 6.0})
	# zemine oturan basık kubbe (kameranın dışında kalacak boy)
	L.fireball(pj, g + Vector3.UP * 0.6, 0.8, 3.4, 3.4, {"pal": L.PAL_WHITE, "near": 4.0, "rise": 0.2, "grow": 0.2, "heat": 1.6, "squash": Vector3(1.3, 0.8, 1.3), "cool": 0.8})
	# sütunu saran iki eğik ince yörünge halkası
	for k in 2:
		var tilt = Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(14.0 if k == 0 else -11.0)).rotated(Vector3.UP, randf() * TAU)
		L.ring(pj, g + Vector3.UP * (16.0 - k * 6.0), 3.0, 12.0 - k * 2.0, 2.4, tilt, {"w": 0.06, "near": 5.0})
	L.ring(pj, g + Vector3.UP * 0.2, 2.0, 22.0, 1.8, Vector3.UP, {"w": 0.14, "near": 5.0})
	L.light(pj, o, Color(0.95, 0.98, 1.0), 20.0, 60.0, 1.6)
	L.sparks(pj, o + Vector3.UP * 4.0, 80, 3.0, {"vmin": 14.0, "vmax": 34.0, "life": 1.2, "size": 0.35})
	L.soot(pj, g, 22.0, 14.0, {"heat": 1.0, "cracks": 1.0, "grow": 0.5})
	pj.get_tree().create_timer(0.5).timeout.connect(func():
		for k in 16:
			var a = k * TAU / 16.0 + randf() * 0.2
			var dirv = Vector3(cos(a), 0.0, sin(a))
			L.puff(pj, g + dirv * randf_range(7.0, 10.0) + Vector3.UP * randf_range(1.0, 4.0), randf_range(2.2, 3.0), 4.0, dirv * 2.0 + Vector3.UP * 1.5, {"gray": 0.55, "near": 6.0, "grow": 1.4})
		L.shrapnel(pj, g + Vector3.UP, 40, 22.0, 0.5, {"col": Color(0.42, 0.33, 0.24), "up": 0.9, "life": 2.2})
		L.flakes(pj, o + Vector3.UP * 6.0, 140, 14.0, {"col0": Color(0.15, 0.14, 0.14), "col1": Color(0.25, 0.24, 0.24), "dir": Vector3.DOWN, "spread": 60.0,
			"vmin": 0.2, "vmax": 1.0, "g": Vector3(0, -1.2, 0), "life": 4.0, "size": 0.18, "burst": 0.4}))


# ================================================================== Iwa patlama yumrukları
## Mayın Yumruğu (anime, Kitsuchi / Kurotsuchi): yumruğun içinde patlayıcı chakra kıvılcımı kabarır; çarpınca patlama
## kullanana dönmez, yalnız ÖNE açılır — şeftali kenarlı sivri beyaz çekirdek, ileri uzayan kabaran top, yumruğun önünde
## yumruk yönüne dik şok halkası ve öne savrulan kara zikzak şok kıymıkları.
static func bakuton_jiraiken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 0.0, 14.0 if tt else 3.0)
	pj.busy(c, 0.7)
	_fist_charge(pj, c, 0.25, 0.5)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.3
		_landmine_burst(pj, at, c.face_dir())
		_impact_side(pj, at, 2.0)
		pj.hit(c, at, 3.5, pj.inf(c, "bakuton_jiraiken", 2.2, {"knock": 24.0, "launch": 6.0, "kind": "heavy", "element": "bakuton", "hitstop": 0.1}))
		Sfx.play("boom", at, 0.8))


## Yumrukta kabaran patlayıcı chakra çekirdeği (kemiğe iliştirilir; kemik yoksa noktaya akan kıvılcımlar)
static func _fist_charge(pj: PathJutsu, c: Node3D, t: float, size: float) -> void:
	var ba = L.bone(c, "RightHand")
	if ba:
		var orb = L.orb_mi(0.08, 0.5, 7.0)
		ba.add_child(orb)
		var tw = orb.create_tween()
		tw.tween_property(orb, "scale", Vector3.ONE * size, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		L.kill(pj, t + 0.05, ba)
	else:
		L.converge(pj, pj.hand_pos(c, true), t, 8, 0.9, {"warm": 0.5, "core": size})
	L.light(pj, pj.hand_pos(c, true), Color(1.0, 0.88, 0.65), 2.5, 5.0, t)


static func _landmine_burst(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	L.flash(pj, at + d * 0.5, 4.2, 0.28, {"spikes": 13.0, "warm": 0.6, "near": 3.5})
	L.fireball(pj, at + d * 1.6, 0.4, 2.2, 0.9, {"dir": d, "squash": Vector3(0.75, 0.75, 1.6), "rise": 0.4, "vel": d * 2.5, "near": 4.0, "grow": 0.2, "heat": 1.3})
	L.ring(pj, at + d * 0.9, 0.4, 3.6, 0.4, d, {"w": 0.3, "near": 3.0})
	_shock_shards(pj, at + d * 0.8, d, 14)
	L.sparks(pj, at + d * 0.5, 26, 0.3, {"dir": d, "spread": 35.0, "vmin": 10.0, "vmax": 22.0, "life": 0.35, "g": Vector3.ZERO})
	L.light(pj, at, Color(1.0, 0.88, 0.7), 8.0, 12.0, 0.35)


## Kara zikzak şok kıymığı (anime patlama çizgisi): -Z boyunca üç kırık çizgi
static func _shard_mesh() -> ArrayMesh:
	if _cache.has("shard"):
		return _cache["shard"]
	var b = MB.new()
	var col = Color(0.27, 0.25, 0.3)
	var pts = [Vector3(0, 0, 0), Vector3(0.12, 0, -0.26), Vector3(-0.1, 0, -0.52), Vector3(0.06, 0, -0.82)]
	for i in 3:
		var a: Vector3 = pts[i]
		var bb: Vector3 = pts[i + 1]
		var mid = (a + bb) * 0.5
		var ln = a.distance_to(bb)
		var yaw = rad_to_deg(atan2(bb.x - a.x, bb.z - a.z))
		b.add("box", mid, Vector3(0.07, 0.02, ln + 0.03), col, Vector3(0, yaw, 0))
		b.add("box", mid, Vector3(0.02, 0.07, ln + 0.03), col, Vector3(0, yaw, 0))
	var m = b.build()
	_cache["shard"] = m
	return m


static func _shock_shards(pj: PathJutsu, p: Vector3, d: Vector3, n: int) -> void:
	var side = d.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var upv = side.cross(d).normalized()
	for i in n:
		var mi = L.gi(_shard_mesh(), L.flat_mat())
		var off = side * randf_range(-1.2, 1.2) + upv * randf_range(-1.0, 1.0)
		var v = (d * randf_range(1.0, 1.4) + off * 0.35).normalized() * randf_range(14.0, 22.0)
		var p0 = p + off * 0.6
		L.put(pj, mi, p0)
		mi.global_basis = Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.97 else Vector3.RIGHT) * Basis.from_scale(Vector3.ONE * randf_range(0.8, 1.6))
		var life = randf_range(0.22, 0.34)
		var tw = mi.create_tween().set_parallel()
		tw.tween_property(mi, "global_position", p0 + v * life, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 2.2), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)


## Sokubakukyaku (Gari): ayağın altında patlama — yere basık yayılan top, zemin halkası ve kurum ileri fırlatır; uçarken
## topuklardan kısa itiş çakmaları; tekme isabetinde tekme yönünde dikey halka ve öne uzayan top.
static func bakuton_sokubakukyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 13.0)
	pj.busy(c, 0.7)
	var d = pj._face(c, tt)
	var foot = pj.gp(c.global_position) + Vector3.UP * 0.3 - d * 0.4
	_foot_blast(pj, foot, d)
	_impact_side(pj, foot, 0.9)
	Sfx.play("boom", c.global_position, 1.4)
	if "velocity" in c:
		c.velocity = d * 34.0 + Vector3.UP * 2.0
	pj._kick_pose(c, 0.45)
	var state = {"hit": false}
	var fly = func(i, _k):
		if state["hit"] or not pj.live(c):
			return
		if i % 5 == 0:
			_thrust_pop(pj, c.global_position + Vector3.UP * 0.4 - d * 0.6, d)
		var at = c.global_position + Vector3.UP * 1.0 + d * 0.9
		var hs = _mhit(pj, c, at, 1.6, pj.inf(c, "bakuton_sokubakukyaku", 4.0, {"knock": 22.0, "launch": 3.0, "kind": "heavy", "element": "bakuton", "melee": true, "hitstop": 0.1}))
		if hs.size() > 0:
			state["hit"] = true
			_kick_blast(pj, at, d)
			_impact_side(pj, at, 1.3)
			if "velocity" in c:
				c.velocity = -d * 5.0 + Vector3.UP * 5.0   # tepmeyle geri sıçrar
			Sfx.play("boom", at, 1.0)
	pj.every(0.4, 1.0 / 60.0, fly, Callable())


static func _foot_blast(pj: PathJutsu, foot: Vector3, d: Vector3) -> void:
	var fl = L.floor_at(foot)
	L.flash(pj, foot, 2.4, 0.2, {"spikes": 6.0, "warm": 0.3, "near": 2.5})
	L.fireball(pj, fl + Vector3.UP * 0.3 - d * 0.5, 0.3, 1.5, 0.8, {"squash": Vector3(1.25, 0.5, 1.25), "rise": 0.5, "vel": -d * 2.0, "near": 3.0, "grow": 0.2})
	L.ring(pj, fl + Vector3.UP * 0.08, 0.3, 3.0, 0.45, Vector3.UP, {"w": 0.3, "near": 2.5})
	L.soot(pj, fl, 1.6, 6.0, {"heat": 0.6})
	L.shrapnel(pj, foot, 6, 7.0, 0.1, {"col": L.STONE, "dir": -d, "bias": 0.5, "up": 0.6, "life": 0.9})


static func _thrust_pop(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	L.flash(pj, p, 0.9, 0.12, {"spikes": 5.0, "warm": 0.5, "near": 2.0})
	L.fireball(pj, p - d * 0.2, 0.15, 0.45, 0.35, {"vel": -d * 3.0, "rise": 0.2, "near": 2.5, "grow": 0.3})


static func _kick_blast(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	L.flash(pj, at + d * 0.3, 3.0, 0.22, {"spikes": 8.0, "warm": 0.3, "near": 3.0})
	L.ring(pj, at + d * 0.5, 0.3, 2.6, 0.35, d, {"w": 0.35, "near": 2.5})
	L.fireball(pj, at + d * 1.0, 0.3, 1.4, 0.7, {"dir": d, "squash": Vector3(0.9, 0.9, 1.3), "vel": d * 3.0, "rise": 0.4, "near": 3.5, "grow": 0.2})
	L.sparks(pj, at, 16, 0.2, {"dir": d, "spread": 50.0, "vmin": 6.0, "vmax": 14.0, "life": 0.35})


## Shunkan Shōkyaku (Gari): patlayıcı chakranın hepsi yumrukta toplanır — kemikteki beyaz çekirdek büyür, kıvılcımlar içe
## akar; vuruşta patlama YOK: yuvarlak sessiz beyaz parlama, sonra hedef bedenden kenarları kızgın kara kül pulları yükselir.
static func bakuton_shunkan_shokyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.5)
	pj._face(c, tt)
	var ba = pj.bone_attach(c, "RightHand")
	var core: Node3D = null
	if ba:
		core = Node3D.new()
		core.add_child(L.orb_mi(0.24, 0.15, 8.0))
		ba.add_child(core)
		pj.free_after(1.5, ba)
	Sfx.play("th_steam", c.global_position, 0.6)
	# toplama: yumruk akkor olana dek parlar (0.9 sn — bu sürede bozulabilir)
	var charge = func(i, k):
		if not pj.live(c):
			return
		if is_instance_valid(core):
			core.scale = Vector3.ONE * lerpf(1.0, 3.2, k)
		if i % 4 == 0:
			var hp = pj.hand_pos(c)
			L.light(pj, hp, Color(1, 0.9, 0.7), 1.5 + 4.0 * k, 3.0 + 3.0 * k, 0.12)
			L.sparks(pj, hp, 3, 0.9, {"vmin": -4.0, "vmax": -2.0, "spread": 180.0, "life": 0.3, "size": 0.1, "g": Vector3.ZERO, "damp": 0.0})
	var strike = func():
		if not pj.live(c):
			return
		pj._jump_at(c, tt, 0.0, 16.0 if tt else 3.0)
		var land = func():
			if not pj.live(c):
				return
			pj.anim(c, "cross", 1.8)
			var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.2
			for h in _mhit(pj, c, at, 1.9, pj.inf(c, "bakuton_shunkan_shokyaku", 4.6, {"knock": 0.0, "kind": "heavy", "element": "bakuton", "melee": true, "burn": 4.0, "stun": 1.2, "hitstop": 0.16, "attacker": c})):
				_ash_out(pj, h.global_position + Vector3.UP * 1.1)
			Sfx.play("hit_heavy", at, 0.6)
		pj.after(0.14, land)
	pj.every(0.9, 1.0 / 40.0, charge, strike)


static func _ash_out(pj: PathJutsu, o: Vector3) -> void:
	L.flash(pj, o, 2.6, 0.3, {"spikes": 0.0, "near": 2.5})
	L.light(pj, o, Color(1, 0.95, 0.85), 8.0, 7.0, 0.3)
	L.flakes(pj, o, 46, 0.5, {"col0": Color(0.12, 0.11, 0.1), "col1": Color(0.3, 0.28, 0.26), "ember": true, "dir": Vector3.UP, "spread": 180.0,
		"vmin": 0.4, "vmax": 2.2, "g": Vector3(0, 1.2, 0), "life": 1.6, "size": 0.15, "burst": 0.7})
	L.sparks(pj, o, 10, 0.4, {"dir": Vector3.UP, "spread": 60.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, 1.0, 0), "life": 1.0, "size": 0.07})


## Enmakuken (Gari): Mayın Yumruğu'nun yıkıcı olmayan hâli — parlama yok; yumruğun önünde ağır, yoğun gri cel duman
## bulutu boğuk bir pufla açılır, yere yayılan alçak topaklar ve toz halkası; bulut 2.5 sn asılı kalıp yavaşça aşınır.
static func bakuton_enmakuken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 0.0, 14.0 if tt else 3.0)
	pj.busy(c, 0.55)
	var punch = func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.8)
		var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.2
		_smoke_screen(pj, at, c.face_dir())
		for h in _mhit(pj, c, at, 2.4, pj.inf(c, "bakuton_enmakuken", 1.8, {"knock": 1.0, "kind": "heavy", "element": "bakuton", "melee": true})):
			pj.st(h, "stun", 2.2)
		# duman içinde kalanlar 2.5 sn yavaşlar
		var smoke = func(_i, _k):
			if pj.live(c):
				for e in pj.enemies_near(c, at, 3.2):
					pj.st(e, "slow", 0.5)
		pj.every(2.5, 0.3, smoke, Callable())
		Sfx.play("poof", at, 0.7)
	pj.after(0.2, punch)


static func _smoke_screen(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	L.fireball(pj, at + d * 0.6, 0.5, 2.4, 2.6, {"pal": L.PAL_SMOKE, "heat": 0.0, "rise": 0.15, "near": 5.0, "grow": 0.3, "lump": 1.3})
	for k in 7:
		var a = k * TAU / 7.0 + randf() * 0.4
		var off = Vector3(cos(a), randf_range(-0.3, 0.6), sin(a))
		L.puff(pj, at + d * 0.8 + off * randf_range(0.8, 1.5), randf_range(1.0, 1.5), randf_range(2.6, 3.0), off * 0.6 + Vector3.UP * 0.25, {"gray": 0.6, "near": 5.0, "grow": 1.5})
	var fl = L.floor_at(at)
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.5
		var off = Vector3(cos(a), 0.0, sin(a))
		L.puff(pj, fl + Vector3.UP * 0.4 + off * 1.2 + d * 0.8, randf_range(0.7, 1.0), 2.4, off * 1.8, {"gray": 0.5, "near": 5.0, "grow": 1.8})
	L.ring(pj, fl + Vector3.UP * 0.08, 0.5, 3.4, 0.6, Vector3.UP, {"white": 0.0, "w": 0.22, "near": 4.0})


## Jirai Renken: her yumruk bedene küçük kil tohum-mayın gömer (atan küçük parıltılı kil topağı, bedene yapışır);
## sonra tohumlar sırayla minik sivri parlama + kabaran topla patlar, sonuncusu iri ve halkalı.
static func bakuton_jirai_renken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 1.5)
	pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	var marks = []
	for k in 5:
		var jab = func():
			if not pj.live(c):
				return
			pj.anim(c, "cross" if k % 2 == 0 else "hook", 2.4)
			if pj.live(tt) and "velocity" in c:
				var gap: Vector3 = tt.global_position - c.global_position
				gap.y = 0.0
				c.velocity = gap.normalized() * (8.0 if gap.length() > 1.4 else 0.0)
			var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.0
			for h in _mhit(pj, c, at, 1.8, pj.inf(c, "bakuton_jirai_renken", 0.22, {"knock": 0.5, "kind": "light", "element": "bakuton", "melee": true, "hitstop": 0.03})):
				var m = _mine_seed()
				h.add_child(m)
				m.position = Vector3(randf_range(-0.28, 0.28), randf_range(0.7, 1.5), randf_range(-0.22, 0.22))
				marks.append([weakref(h), m])
				L.flash(pj, m.global_position, 0.9, 0.12, {"spikes": 5.0, "warm": 0.4, "near": 1.5})
			Sfx.play("hit_heavy", at, 1.4, 0.6)
		pj.after(0.18 + k * 0.13, jab)
	var blow_all = func():
		for n in marks.size():
			var one = func():
				var h = marks[n][0].get_ref()
				var m = marks[n][1]
				var mp = Vector3.ZERO
				var has_m = is_instance_valid(m)
				if has_m:
					mp = m.global_position
					m.queue_free()
				if h == null or not pj.live(h) or not pj.live(c):
					return
				var at = h.global_position + Vector3.UP * 1.1
				var last = n == marks.size() - 1
				_seed_pop(pj, mp if has_m else at, last)
				_impact_side(pj, at, 1.3 if last else 0.6)
				h.take_hit(pj.inf(c, "bakuton_jirai_renken", 0.85, {"knock": 15.0 if last else 1.0, "launch": 5.0 if last else 0.0, "kind": "heavy", "element": "bakuton"}))
				Sfx.play("boom", at, 1.3 if not last else 0.9, 0.7)
			pj.after(n * 0.08, one)
	pj.after(1.05, blow_all)


## Bedene yapışan kil tohum-mayın: küçük kil topak + nabız gibi atan sıcak parıltı
static func _mine_seed() -> Node3D:
	var root = L.lump(0.11, 0.3)
	L.sp(root, "glow", 0.5)
	var orb = L.orb_mi(0.16, 0.6, 5.0)
	root.add_child(orb)
	var tw = orb.create_tween().set_loops()
	tw.tween_property(orb, "scale", Vector3.ONE * 0.3, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(orb, "scale", Vector3.ONE * 0.14, 0.14).set_trans(Tween.TRANS_SINE)
	return root


static func _seed_pop(pj: PathJutsu, p: Vector3, last: bool) -> void:
	if last:
		L.flash(pj, p, 3.2, 0.26, {"spikes": 10.0, "near": 3.0})
		L.fireball(pj, p, 0.4, 1.8, 0.9, {"rise": 1.0, "near": 3.5, "grow": 0.22})
		L.ring(pj, p, 0.4, 2.6, 0.4, Vector3.UP, {"w": 0.3, "near": 3.0})
		L.shrapnel(pj, p, 8, 8.0, 0.08)
		L.sparks(pj, p, 18, 0.3, {"vmin": 4.0, "vmax": 10.0, "life": 0.4})
	else:
		L.flash(pj, p, 1.4, 0.16, {"spikes": 6.0, "warm": 0.3, "near": 2.0})
		L.fireball(pj, p, 0.15, 0.6, 0.55, {"rise": 0.8, "near": 2.5, "grow": 0.25})
		L.shrapnel(pj, p, 3, 4.0, 0.05)
	L.light(pj, p, Color(1.0, 0.85, 0.6), 3.0 if last else 1.5, 6.0, 0.25)


## Gansaiha: yere inen yumruk toprağı söker — kısa sıcak parlama, ışınsal yarıklı kurum, havaya kalkan kaya kütleri,
## toprak tozlu halka; patlayıcı chakra damarları içten parlayan beş kaya öne saçılır, değdiği yerde taş kıymıklı küçük
## patlamayla dağılır.
static func bakuton_gansaiha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	pj.anim(c, "hook", 1.4)
	var smash = func():
		if not pj.live(c):
			return
		var g = pj.gp(c.global_position + d * 1.2)
		_ground_smash(pj, g, d)
		_impact_side(pj, g + Vector3.UP * 0.3, 1.0)
		pj.shake(0.6)
		Sfx.play("boom", g, 1.0)
		for k in 5:
			var dir = (d.rotated(Vector3.UP, (k - 2.0) * 0.2) + Vector3.UP * 0.12).normalized()
			var rock = L.stone(randf_range(0.45, 0.7), 1.5, true)
			var pr = pj.shot(c, g + Vector3.UP * 0.8, dir, randf_range(22.0, 27.0), rock, pj.inf(c, "bakuton_gansaiha", 0.5, {"knock": 6.0, "kind": "heavy", "element": "bakuton"}), null, false, 0.6,
				func(p, h):
					_rock_burst(pj, p)
					_impact_side(pj, p, 0.8)
					if pj.live(c):
						_mhit(pj, c, p, 2.4, pj.inf(c, "bakuton_gansaiha", 0.3, {"knock": 8.0, "kind": "heavy", "element": "bakuton"}), [h] if h else []))
			if pr:
				pr.spin = Vector3(randf_range(4, 9), randf_range(4, 9), 0)
				pr.radius = 0.7
	pj.after(0.25, smash)


static func _ground_smash(pj: PathJutsu, g: Vector3, d: Vector3) -> void:
	L.flash(pj, g + Vector3.UP * 0.3, 1.8, 0.18, {"spikes": 7.0, "warm": 0.7, "near": 2.5})
	L.soot(pj, g, 2.4, 6.0, {"heat": 0.5, "cracks": 0.8})
	L.shrapnel(pj, g + Vector3.UP * 0.2, 7, 6.0, 0.3, {"col": L.STONE, "dir": d + Vector3.UP, "bias": 0.4, "up": 1.2, "life": 1.1})
	L.ring(pj, g + Vector3.UP * 0.08, 0.5, 4.0, 0.5, Vector3.UP, {"white": 0.0, "w": 0.28, "near": 3.0})
	for k in 3:
		var a = randf() * TAU
		var off = Vector3(cos(a), 0.0, sin(a))
		L.puff(pj, g + Vector3.UP * 0.5 + off * 0.8, 0.6, 1.2, off * 1.5 + Vector3.UP * 0.8, {"near": 3.0, "tone": Color(0.62, 0.52, 0.4, 0.7), "grow": 1.7})


static func _rock_burst(pj: PathJutsu, p: Vector3) -> void:
	L.flash(pj, p, 2.0, 0.18, {"spikes": 7.0, "warm": 0.3, "near": 3.0})
	L.fireball(pj, p, 0.25, 1.1, 0.7, {"rise": 0.9, "near": 3.5, "grow": 0.22, "heat": 1.2})
	L.shrapnel(pj, p, 9, 10.0, 0.18, {"col": L.STONE, "life": 1.0})
	L.puff(pj, p + Vector3.UP * 0.3, 0.5, 1.1, Vector3.UP * 1.2, {"near": 3.0, "tone": Color(0.6, 0.5, 0.4, 0.6)})
	L.sparks(pj, p, 10, 0.2, {"vmin": 4.0, "vmax": 9.0, "life": 0.35})


## Hannō Sōkō: patlayıcı chakra deriye işler (kıvılcımlar bedene akar, ayakta halka); 7 sn deride minik sıcak çakmalar
## kıpırdar; darbe alınca beden merkezli küresel tepki patlaması — bedeni saran kabaran top + bel hizasında yatay halka.
static func bakuton_hanno_soko(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.4)
	if c is Player:
		Buffs.add("hanno_soko", 7.0, {"_name": "Hannō Sōkō", "_desc": "darbe alınca çevrene patlar"})
	_armor_up(pj, c)
	Sfx.play("th_steam", c.global_position, 1.3)
	var state = {"hp": float(c.hp), "cd": 0.0}
	var armor = func(i, _k):
		if not pj.live(c):
			return
		state["cd"] -= 0.05
		if i % 3 == 0:
			var q = c.global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.4, 1.7), randf_range(-0.35, 0.35))
			L.flash(pj, q, 0.28, 0.16, {"spikes": 4.0, "warm": 0.5, "near": 1.0})
		var hp := float(c.hp)
		if hp < state["hp"] - 0.5 and state["cd"] <= 0.0:
			state["cd"] = 0.8
			var at = c.global_position + Vector3.UP * 1.1
			_reactive_blast(pj, at)
			_impact_side(pj, at, 1.2)
			pj.hit(c, at, 3.6, pj.inf(c, "bakuton_hanno_soko", 1.2, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "element": "bakuton"}))
			Sfx.play("boom", at, 1.1)
		state["hp"] = hp
	pj.every(7.0, 0.05, armor, Callable())


static func _armor_up(pj: PathJutsu, c: Node3D) -> void:
	var chest = c.global_position + Vector3.UP * 1.1
	L.converge(pj, chest, 0.4, 12, 1.1, {"warm": 0.5, "core": 0.5})
	L.ring(pj, L.floor_at(c.global_position) + Vector3.UP * 0.08, 0.2, 1.5, 0.45, Vector3.UP, {"w": 0.35, "near": 2.0})
	L.light(pj, chest, Color(1.0, 0.82, 0.55), 3.0, 5.0, 0.45)


static func _reactive_blast(pj: PathJutsu, at: Vector3) -> void:
	L.fireball(pj, at, 0.6, 2.4, 0.8, {"rise": 0.6, "near": 3.5, "grow": 0.18, "lump": 1.2, "heat": 1.2})
	L.ring(pj, at, 0.5, 4.2, 0.45, Vector3.UP, {"w": 0.25, "near": 3.0})
	L.sparks(pj, at, 24, 0.6, {"vmin": 6.0, "vmax": 14.0, "life": 0.45})
	for k in 2:
		var a = randf() * TAU
		var off = Vector3(cos(a), 0.5, sin(a))
		L.puff(pj, at + off * 1.6, 0.7, 1.4, off * 1.4 + Vector3.UP * 0.8, {"gray": 0.35, "hot": 0.5, "near": 3.0})
	L.light(pj, at, Color(1.0, 0.85, 0.6), 6.0, 10.0, 0.35)
