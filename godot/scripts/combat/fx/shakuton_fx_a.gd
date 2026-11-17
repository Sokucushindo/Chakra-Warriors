class_name ShakutonFXA
extends RefCounted
## Shakuton grubu A (Pakura): on kavurma tekniğinin görselleri — malzeme ve yapı taşları ShakutonLib'den (kendi küre / kuyruk /
## buhar şeridi / kuru zemin shader'ları). Katon kalıbı değil: alev dili yok; yuvarlak akkor küreler yörüngede döner, süzülür,
## değdiği bedenin suyunu çeker (ten kararır, ince beyaz buhar şeritleri yükselir, kuru pullar dökülür).
## Her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.


# ================================================================== ortak hareket: süzülme (eski süzülme yardımcısının oynanışı birebir)
## Pakura (ref: Naruto Mobile): ayaklarının altında iki küçük kavurucu küre — yerden bir karış havada süzülür.
## Kürelerin altından aşağı ısı zerreleri dökülür, ayak altında hava titrer.
static func _hover(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var orbs = []
	for sx in [-1.0, 1.0]:
		var o = ShakutonLib.orb_body(0.26, ShakutonLib.PAL_SUN, 1.6)
		c.add_child(o)
		o.position = Vector3(0.25 * sx, -0.32, 0.0)
		ShakutonLib.bloom(o, 1.0, 0.2)
		orbs.append(o)
		ShakutonLib.motes(pj, Vector3.ZERO, 14, 0.12, {"dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.6, "vmax": 1.6, "g": Vector3(0, -0.5, 0), "life": 0.5, "emit": dur, "parent": o, "size": 0.06})
	ShakutonLib.haze(pj, Vector3(0, -0.2, 0), 1.4, 1.0, dur, c)
	var y0: float = c.global_position.y
	var hov_tick = func(_i, k):
		if pj.live(c):
			var p = c.global_position
			p.y = y0 + 0.8 * minf(1.0, k * 8.0) + sin(k * dur * 5.0) * 0.06
			c.global_position = p
			if "velocity" in c:
				c.velocity = Vector3.ZERO
	var hov_done = func():
		for o in orbs:
			ShakutonLib.snuff(o, 0.2)
	pj.every(dur, 1.0 / 60.0, hov_tick, hov_done)


## İki nokta arası kavisli nokta dizisi (ikinci derece eğri)
static func _arc_pts(a: Vector3, b: Vector3, mid: Vector3, n: int) -> PackedVector3Array:
	var out = PackedVector3Array()
	for i in n:
		var u = float(i) / maxf(1.0, n - 1.0)
		out.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
	return out


# ================================================================== 1) Kajōsatsu: dört güneş küresi, kurbanı mumyalaştırır
## Kanon (ref suns / Pakura / Mummy): küreler iki yanda avuç hizasında süzülür, kuyrukları dışa-geriye kıvrılır; sırayla fırlar.
## Değdiği kurbanın teni kararır, bedeninden ince dalgalı buhar şeritleri yükselir, ayağının altındaki zemin kurur.
static func shakuton_kajosatsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	var orbs = []
	var fd = c.face_dir()
	var sd = fd.cross(Vector3.UP).normalized()
	var spots = [sd * 1.6 + Vector3.UP * 1.9, -sd * 1.6 + Vector3.UP * 1.9, sd * 1.3 + Vector3.UP * 0.9 - fd * 0.3, -sd * 1.3 + Vector3.UP * 0.9 - fd * 0.3]
	var bases = []
	for k in 4:
		var o = ShakutonLib.orb_body(0.7)
		c.add_child(o)
		o.global_position = c.global_position + spots[k]
		bases.append(o.position)
		ShakutonLib.bloom(o, 1.0, 0.3)
		orbs.append(o)
		var out = (spots[k] * Vector3(1, 0, 1)).normalized() - fd * 0.5
		ShakutonLib.tail(pj, o, 0.34, 9, ShakutonLib.PAL_SUN, out.normalized() * 1.3 + Vector3.UP * 0.35)
	ShakutonLib.haze(pj, c.global_position + Vector3.UP * 1.4, 4.2, 3.4, 1.3)
	# bekleme: küreler yerinde küçük yörüngeler çizer (her biri ayrı evrede)
	var drift = func(_i, k):
		for n in orbs.size():
			var o = orbs[n]
			if is_instance_valid(o):
				var a = k * 9.0 + n * 1.7
				o.position = bases[n] + Vector3(cos(a) * 0.12, sin(a * 1.4) * 0.1, sin(a) * 0.12)
	pj.every(0.8, 1.0 / 40.0, drift, Callable())
	for k in 4:
		pj.after(0.4 + k * 0.12, func():
			var o = orbs[k]
			if not (pj.live(c) and is_instance_valid(o)):
				return
			var from = o.global_position
			o.queue_free()
			ShakutonLib.flash(pj, from, 1.6, ShakutonLib.col(0, 1), 0.18)
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 24.0, ShakutonLib.orb_body(0.7), pj.inf(c, "shakuton_kajosatsu", 0.9, {"knock": 4.0, "kind": "heavy", "element": "shakuton", "burn": 4.0}), tt, false, 1.6, func(p, h):
				ShakutonLib.sear(pj, p, 1.2, h)
				ShakutonLib.dry_patch(pj, p, 1.6, 4.0, 4)
				if h and pj.live(h):
					pj.st(h, "slow", 2.0))
			ShakutonLib.tail(pj, pr, 0.5, 12))
	Sfx.play("fire", c.global_position, 1.0)


# ================================================================== 2) Daijōhappa: üç küre tek dev küreye birleşir, alanın suyu çekilir
## Kanon (ref Explosive Blast / Wave / Aftermath): beyaz çekirdekli, kızıl kenarlı dev küre — parlak loblar; patlayınca
## alan gün batımı gibi kızıla boğulur, ardında suyu çekilmiş soluk gri kuru bir daire ve kenarında tüten buhar kalır.
static func shakuton_daijohappa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 24.0)
	pj.busy(c, 1.4)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0) + Vector3.UP * 1.5
	var orbs = []
	for k in 3:   # anime: üç beyaz çekirdekli küre
		var o = ShakutonLib.orb_body(0.8, ShakutonLib.PAL_CRIMSON)
		pj.scene_add(o, c.global_position + Vector3.UP * 2.2 + c.face_dir().cross(Vector3.UP) * (k - 1) * 1.2)
		ShakutonLib.bloom(o, 1.0, 0.3)
		orbs.append(o)
		ShakutonLib.tail(pj, o, 0.4, 12, ShakutonLib.PAL_CRIMSON)
	ShakutonLib.haze(pj, c.global_position + Vector3.UP * 2.2, 4.5, 2.6, 1.0)
	pj.after(0.45, func():
		for o in orbs:
			if is_instance_valid(o):
				var tw = o.create_tween()
				tw.tween_property(o, "global_position", at, 0.45).set_trans(Tween.TRANS_QUAD)
				tw.tween_callback(o.queue_free))
	pj.after(0.95, func():
		var big = ShakutonLib.orb_body(2.0, ShakutonLib.PAL_CRIMSON, 1.4)
		pj.scene_add(big, at)
		big.scale = Vector3.ONE * 0.6
		ShakutonLib.flash(pj, at, 6.0, ShakutonLib.col(1, 1), 0.3)
		ShakutonLib.haze(pj, at, 6.5, 5.5, 1.0)
		var tw = big.create_tween()
		tw.tween_property(big, "scale", Vector3.ONE * 1.6, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			# patlama: alev yok — kızıl-beyaz ışık dalgası, ısı titremesi, alanın suyu çekilir
			ShakutonLib.light(pj, at, Color(1.0, 0.35, 0.35), 6.0, 16.0, 0.35)
			ShakutonLib.flash(pj, at, 11.0, ShakutonLib.col(1, 2), 0.7)
			ShakutonLib.flash(pj, at, 5.0, ShakutonLib.col(1, 0), 0.3)
			ShakutonLib.haze(pj, ShakutonLib.floor_at(at) + Vector3.UP * 2.0, 7.0, 4.5, 2.2)
			ShakutonLib.dry_patch(pj, at, 6.5, 7.0, 14)
			ShakutonLib.motes(pj, at, 40, 2.4, {"vmin": 2.0, "vmax": 7.0, "spread": 180.0, "life": 1.0, "pal": ShakutonLib.PAL_CRIMSON, "size": 0.12})
			for k in 10:
				var a = k * TAU / 10.0 + randf() * 0.3
				var q = ShakutonLib.floor_at(at + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 5.5))
				ShakutonLib.wisp(pj, q, randf_range(2.0, 3.2), randf_range(1.2, 1.7), 0.22)
			pj.shake(0.8)
			for e in pj.enemies_near(c, at, 6.0):
				e.take_hit(pj.inf(c, "shakuton_daijohappa", 2.2, {"knock": 16.0, "launch": 3.0, "kind": "heavy", "element": "shakuton", "burn": 3.0}))
				ShakutonLib.sear(pj, e.global_position + Vector3.UP, 0.6, e, ShakutonLib.PAL_CRIMSON)
			GroundFX.add(pj.gp(at), "steam", 5.0, 4.0, c)
			ShakutonLib.snuff(big, 0.22)))
	Sfx.play("fire", c.global_position, 0.6)


# ================================================================== 3) Shakkyū: avuçta tek küre toplanır, fırlar
## Isı zerreleri avuca sarmal çizerek akar, küre orada açılır ve kuyruğunu sürükleyerek fırlar; değdiği yerden buhar şeritleri yükselir.
static func shakuton_shakkyu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 24.0)
	ShakutonLib.gather(pj, pj.hand_pos(c), 0.25, 8, 0.9)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c)
		ShakutonLib.flash(pj, from, 1.4, ShakutonLib.col(0, 1), 0.18)
		var body = ShakutonLib.orb_body(0.55)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 26.0, body, pj.inf(c, "shakuton_shakkyu", 1.0, {"knock": 4.0, "kind": "heavy", "element": "shakuton", "burn": 2.0}), tt, false, 1.4, func(p, _h):
			ShakutonLib.sear(pj, p, 0.8, _h))
		ShakutonLib.bloom(body, 1.0, 0.12)
		ShakutonLib.tail(pj, pr, 0.4, 10))
	Sfx.play("fire", c.global_position, 1.2)


# ================================================================== 4) Shakken: kavurucu kılıç
## Kılıcın ağzı akkor ısıyla sarılır (avuçta küçük küre, kılıç boyunca ısı titremesi ve zerre); üç kesik akkor yay bırakır,
## değdiği bedenden buhar tüter, ten kurur.
static func shakuton_shakken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	pj.busy(c, 1.0)
	pj._ensure_blade(c, 1.0)
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(ShakutonLib.orb_mi(0.16, ShakutonLib.PAL_SUN, 1.1, 2.0))
		ShakutonLib.motes(pj, Vector3.ZERO, 18, 0.15, {"vmin": 0.3, "vmax": 1.0, "life": 0.5, "emit": 0.9, "parent": ba, "size": 0.05})
		ShakutonLib.haze(pj, Vector3(0, 0.3, 0), 0.8, 1.4, 1.0, ba)
		pj.free_after(1.0, ba)
	pj._jump_at(c, tt, 0.0, 9.0)
	for k in 3:
		pj.after(0.2 + k * 0.18, func():
			if not pj.live(c):
				return
			var d = c.face_dir()
			var at = c.global_position + Vector3.UP * 1.1
			var a0 = -60.0 + k * 30.0
			var a1 = 50.0 + k * 30.0
			var r = 1.7
			# akkor kesik yayı: her kesik başka eğimde (sağdan sola, soldan sağa, çapraz)
			var tilt = [0.35, -0.35, 0.0][k]
			var pts = PackedVector3Array()
			for i in 14:
				var q = float(i) / 13.0
				pts.append(at + d.rotated(Vector3.UP, deg_to_rad(lerpf(a0, a1, q))) * r + Vector3.UP * lerpf(tilt, -tilt, q))
			ShakutonLib.sweep(pj, pts, 0.2, 0.32)
			var info = {"knock": 6.0, "kind": "heavy", "bleed": 3.0}
			info.merge({"element": "shakuton", "burn": 2.0}, true)
			var hits = pj.hit(c, at + d * r * 0.6, r * 0.9, pj.inf(c, "shakuton_shakken", 0.7, info))
			for h in hits:
				if pj.live(h):
					pj.st(h, "slow", 1.5)
					ShakutonLib.flash(pj, h.global_position + Vector3.UP * 1.1, 1.3, ShakutonLib.col(0, 1), 0.2)
					ShakutonLib.mummify(pj, h, 1.0, 0.6))
	Sfx.play("blade", c.global_position, 1.0)


# ================================================================== 5) Kaiten Shakkyū: bedeni saran üç dönen küre
## Üç küre 8 sn bedenin çevresinde hızla döner (kuyrukları halka gibi uzar); çevrede hava titrer. Yaklaşan kavrulur,
## gelen küçük mermiler kürelere değince buharlaşıp söner.
static func shakuton_kaiten_shakkyu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.6)
	var orbs = []
	for k in 3:
		var o = ShakutonLib.orb_body(0.45)
		c.add_child(o)
		ShakutonLib.bloom(o, 1.0, 0.25)
		orbs.append(o)
		ShakutonLib.tail(pj, o, 0.3, 11)
	ShakutonLib.haze(pj, Vector3.UP * 1.2, 4.0, 3.0, 8.0, c)
	if c is Player:
		Buffs.add("kaiten_shakkyu", 8.0, {"armor": 0.15, "_name": "Dönen Kavurucu Küreler", "_desc": "yaklaşanı kavurur"})
	pj.every(8.0, 0.03, func(_i, _k):
		for k in orbs.size():
			var o = orbs[k]
			if is_instance_valid(o):
				var a = _k * TAU * 6.0 + k * TAU / 3.0
				o.position = Vector3(cos(a) * 1.5, 1.2 + sin(a * 2.0) * 0.2, sin(a) * 1.5)
		if _i % 15 == 0 and pj.live(c):
			for e in pj.enemies_near(c, c.global_position, 2.2):
				e.take_hit(pj.inf(c, "shakuton_kaiten_shakkyu", 0.3, {"knock": 5.0, "kind": "light", "element": "shakuton", "burn": 1.0}))
				ShakutonLib.mummify(pj, e, 0.6, 0.4)
			for p in pj.get_tree().get_nodes_in_group("projectiles"):
				if p.get("shooter") != c and p.global_position.distance_to(c.global_position + Vector3.UP) < 2.0:
					# mermi kürenin ısısında buharlaşır: kısa parlama + iki buhar şeridi
					ShakutonLib.flash(pj, p.global_position, 1.0, ShakutonLib.col(0, 1), 0.2)
					for q in 2:
						ShakutonLib.wisp(pj, p.global_position + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), randf_range(0.8, 1.3), 0.8, 0.12)
					p.queue_free(), func():
		for o in orbs:
			ShakutonLib.snuff(o, 0.25))
	Sfx.play("fire", c.global_position, 0.9)


# ================================================================== 6) Shakkyū Rendan: süzülerek art arda küreler
## Ref Pakura: iki kürenin üstünde süzülür; iki avucundan sırayla küçük küreler atar — atılanın yerine avuçta hemen yenisi açılır.
static func shakuton_shakkyu_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 2.4)
	var tt = pj.tg(c, t, 26.0)
	pj._face(c, tt)
	_hover(pj, c, 2.4)
	Sfx.play("fire", c.global_position, 1.2)
	for k in 6:
		var fire_one = func():
			if not pj.live(c):
				return
			var from = pj.hand_pos(c, k % 2 == 0)
			var aim = pj.live(tt)
			var dir = pj.aim_at(c, tt if aim else null, from).rotated(Vector3.UP, randf_range(-0.05, 0.05))
			var pr = pj.shot(c, from, dir, 30.0, ShakutonLib.orb_body(0.36), pj.inf(c, "shakuton_shakkyu_rendan", 0.52, {"knock": 2.0, "kind": "light", "element": "shakuton", "burn": 1.5}), tt if aim else null, false, 1.3,
				func(p, h): ShakutonLib.sear(pj, p, 0.55, h))
			ShakutonLib.tail(pj, pr, 0.28, 9)
			# yerine yenisi: avuçta küçük küre açılır, bir sonraki atışa kadar parlar
			ShakutonLib.light(pj, from, Color(1.0, 0.55, 0.3), 2.5, 4.0, 0.15)
			var fresh = ShakutonLib.orb_mi(0.2, ShakutonLib.PAL_SUN, 1.1, 1.8, false)
			pj.scene_add(fresh, from)
			ShakutonLib.bloom(fresh, 0.2, 0.15)
			pj.after(0.26, func(): ShakutonLib.snuff(fresh, 0.06))
			Sfx.play("fire", from, 1.5, 0.5)
		pj.after(0.35 + k * 0.32, fire_one)


# ================================================================== 7) Shakkyū no Mai: iki uydulu büyük küre
## Ref Pakura: süzülürken iki küçük kürenin akkor iplikle bağlandığı tek büyük küre atar; uydular onun çevresinde döner.
## Büyük küre patlar (zemini kurutur), küçükler kopup yakındaki öteki düşmanlara yönelir.
static func shakuton_shakkyu_no_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.5)
	var tt = pj.tg(c, t, 26.0)
	pj._face(c, tt)
	_hover(pj, c, 1.5)
	Sfx.play("fire", c.global_position, 0.9)
	var throw_big = func():
		if not pj.live(c):
			return
		var head = Node3D.new()
		head.add_child(ShakutonLib.orb_mi(1.0, ShakutonLib.PAL_SUN, 1.1, 1.3))
		var sats = []
		for n in 2:
			var s = ShakutonLib.orb_mi(0.34, ShakutonLib.PAL_SUN, 1.05, 2.0, false)
			head.add_child(s)
			sats.append(s)
		# uyduları büyük küreye bağlayan akkor iplikler (sahnede; her karede yeniden kurulur)
		var fils = []
		for n in 2:
			var f = ShakutonLib.band_mi(ShakutonLib.PAL_SUN, 0.9, 3.0)
			pj.scene_add(f, Vector3.ZERO)
			fils.append(f)
			ShakutonLib.kill(pj, 2.2, f)
		var drop_fils = func():
			for f in fils:
				if is_instance_valid(f):
					f.queue_free()
		var from = c.global_position + Vector3.UP * 1.9 + c.face_dir() * 0.9
		var on_big = func(p, h):
			drop_fils.call()
			ShakutonLib.sear(pj, p, 1.5, h)
			ShakutonLib.dry_patch(pj, p, 3.2, 5.0, 6)
			ShakutonLib.haze(pj, p, 3.5, 3.0, 1.2)
			if not pj.live(c):
				return
			pj.hit(c, p, 3.2, pj.inf(c, "shakuton_shakkyu_no_mai", 0.45, {"knock": 8.0, "kind": "heavy", "element": "shakuton", "burn": 2.0}), [h] if h else [])
			# küçük küreler kopar: yakındaki öteki düşmanlara, yoksa aynı hedefe döner
			var others = []
			for e in pj.enemies_near(c, p, 12.0):
				if e != h:
					others.append(e)
			var split = func():
				for n in 2:
					var goal: Node3D = others[n % others.size()] if others.size() > 0 else h
					if not pj.live(c) or not pj.live(goal):
						continue
					var sd = Vector3(1.0 if n == 0 else -1.0, 0.6, 0).rotated(Vector3.UP, randf() * TAU).normalized()
					var q = pj.shot(c, p + sd * 0.8, sd, 22.0, ShakutonLib.orb_body(0.34), pj.inf(c, "shakuton_shakkyu_no_mai", 0.4, {"knock": 3.0, "kind": "light", "element": "shakuton", "burn": 1.5}), goal, false, 1.6,
						func(p2, h2): ShakutonLib.sear(pj, p2, 0.55, h2))
					if q:
						q.homing_turn = 9.0
					ShakutonLib.tail(pj, q, 0.24, 10)
			pj.after(0.05, split)
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 21.0, head, pj.inf(c, "shakuton_shakkyu_no_mai", 1.5, {"knock": 12.0, "kind": "heavy", "element": "shakuton", "burn": 3.0, "hitstop": 0.1}), tt, false, 1.8, on_big)
		ShakutonLib.tail(pj, pr, 0.85, 13)
		if pr:
			pr.radius = 0.9
			var orbit = {"a": 0.0}
			pr.on_tick = func(_p, dt):
				orbit["a"] += dt * 9.0
				for n in sats.size():
					if is_instance_valid(sats[n]):
						var a = orbit["a"] + n * PI
						sats[n].position = Vector3(cos(a), sin(a), 0.0) * 1.15
						if n < fils.size() and is_instance_valid(fils[n]) and is_instance_valid(head):
							var a0: Vector3 = head.global_position
							var b0: Vector3 = sats[n].global_position
							var mid = a0.lerp(b0, 0.5) + (b0 - a0).cross(Vector3.UP).normalized() * 0.15 * sin(orbit["a"] * 2.0)
							var ws = PackedFloat32Array()
							for i in 6:
								ws.append(0.07 * (1.0 - absf(i / 5.0 - 0.5)))
							fils[n].mesh = ShakutonLib.strip(pj, _arc_pts(a0, b0, mid, 6), ws)
			pr.tree_exiting.connect(drop_fils)
		ShakutonLib.flash(pj, from, 2.4, ShakutonLib.col(0, 1), 0.25)
		Sfx.play("fire", from, 0.7)
	pj.after(0.6, throw_big)


# ================================================================== 8) Nenshōkyaku: akkor tekme
## Ref Pakura: ayaklar kavurucu chakrayla sarılır (ayak bileğinde küçük küre, zerre, ayağın çizdiği yolda akkor iz);
## uçan tekmeyle düşmanların içinden geçer, dönüp topukla bitirir — topuğun indiği yerde zemin kurur, hava titrer.
static func shakuton_nenshokyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.1)
	for bn in ["RightFoot", "LeftFoot"]:
		var ba = pj.bone_attach(c, bn)
		if ba:
			ba.add_child(ShakutonLib.orb_mi(0.2, ShakutonLib.PAL_SUN, 1.1, 2.2))
			ShakutonLib.motes(pj, Vector3.ZERO, 16, 0.1, {"vmin": 0.2, "vmax": 0.8, "life": 0.45, "emit": 1.0, "parent": ba, "size": 0.05})
			ShakutonLib.tail(pj, ba, 0.16, 12)
			pj.free_after(1.1, ba)
	var d = pj._jump_at(c, tt, 1.5, 24.0)
	pj._kick_pose(c, 0.4)
	Sfx.play("fire", c.global_position, 1.3)
	var done_hit = []
	var fly = func(_i, _k):
		if not pj.live(c):
			return
		var at = c.global_position + Vector3.UP * 0.9 + d * 0.8
		for h in pj.hit(c, at, 1.7, pj.inf(c, "shakuton_nenshokyaku", 1.2, {"knock": 3.0, "kind": "heavy", "element": "shakuton", "melee": true, "burn": 2.0, "hitstop": 0.05}), done_hit):
			done_hit.append(h)
			pj.st(h, "slow", 1.5)
			ShakutonLib.sear(pj, h.global_position + Vector3.UP, 0.7, h)
	var heel = func():
		if not pj.live(c):
			return
		# dönüş: en yakın vurulana topuk
		if "velocity" in c:
			c.velocity = Vector3.ZERO
		var near: Node3D = null
		for h in done_hit:
			if pj.live(h) and (near == null or h.global_position.distance_to(c.global_position) < near.global_position.distance_to(c.global_position)):
				near = h
		if near:
			pj._jump_at(c, near, 2.0, 16.0)
		pj._kg_spin(c, 0.25, 1.0)
		var strike = func():
			if not pj.live(c):
				return
			pj._kick_pose(c, 0.3)
			var at = c.global_position + Vector3.UP * 1.1 + c.face_dir() * 1.0
			# topuğun indiği dikey akkor yay
			var fd = c.face_dir()
			var pts = PackedVector3Array()
			for i in 10:
				var q = float(i) / 9.0
				pts.append(c.global_position + fd * (0.4 + q * 0.8) + Vector3.UP * lerpf(2.6, 0.2, q * q))
			ShakutonLib.sweep(pj, pts, 0.26, 0.3)
			for h in pj.hit(c, at, 2.3, pj.inf(c, "shakuton_nenshokyaku", 2.2, {"knock": 17.0, "launch": 3.0, "kind": "heavy", "element": "shakuton", "melee": true, "burn": 3.0, "hitstop": 0.1})):
				ShakutonLib.sear(pj, h.global_position + Vector3.UP, 1.0, h)
			ShakutonLib.dry_patch(pj, at, 2.2, 3.5, 5)
			ShakutonLib.haze(pj, ShakutonLib.floor_at(at) + Vector3.UP * 0.8, 2.6, 1.8, 0.8)
			Sfx.play("hit_heavy", at, 0.9)
		pj.after(0.25, strike)
	pj.every(0.34, 1.0 / 40.0, fly, heel)


# ================================================================== 9) Shakkyū Hōijin: beş küreli ısı kafesi
## Beş küre hedefin çevresine dizilip daralan bir halkada döner; aralarını akkor bir ısı halkası bağlar (kafes), hedefin üstünde
## hava titrer, bedeninden buhar şeritleri yükselir. Sonunda beşi birden içine dalar.
static func shakuton_shakkyu_hoijin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 20.0)
	if tt == null:
		if c == Game.player:
			Hud.msg("Kürelerin saracağı hedef yok", Color(1, 0.7, 0.5))
		return
	pj._face(c, tt)
	var orbs = []
	var from = pj.hand_pos(c)
	for k in 5:
		var o = ShakutonLib.orb_body(0.4)
		pj.scene_add(o, from)
		ShakutonLib.bloom(o, 1.0, 0.2)
		orbs.append(o)
		ShakutonLib.tail(pj, o, 0.22, 8)
	pj.st(tt, "bind", 2.6)
	Sfx.play("fire", from, 1.0)
	var cage = ShakutonLib.band_mi(ShakutonLib.PAL_SUN, 0.85, 3.0)
	pj.scene_add(cage, Vector3.ZERO)
	ShakutonLib.kill(pj, 3.0, cage)
	ShakutonLib.haze(pj, Vector3.UP * 1.2, 2.6, 3.0, 2.6, tt)
	var wr = weakref(tt)
	var DUR := 2.6
	var ring = func(i, k):
		var x = wr.get_ref()
		if x == null or not pj.live(x):
			return
		var cen: Vector3 = x.global_position + Vector3.UP * 1.1
		var rr = lerpf(2.6, 1.5, k)
		for n in orbs.size():
			if is_instance_valid(orbs[n]):
				var a = k * DUR * 5.5 + n * TAU / 5.0
				var goal = cen + Vector3(cos(a) * rr, sin(a * 2.0 + n) * 0.35, sin(a) * rr)
				orbs[n].global_position = orbs[n].global_position.lerp(goal, 0.35)
		# kafes halkası: küreler arasından geçen, nabız gibi kalınlaşan akkor halka
		if is_instance_valid(cage) and i % 2 == 0:
			var pts = PackedVector3Array()
			var ws = PackedFloat32Array()
			var a0 = k * DUR * 5.5
			for q in 31:
				var a = a0 + q * TAU / 30.0
				pts.append(cen + Vector3(cos(a) * rr, sin(a * 2.0) * 0.18, sin(a) * rr))
				ws.append(0.05 + 0.03 * sin(q * 1.3 + i * 0.4))
			cage.mesh = ShakutonLib.strip(pj, pts, ws)
		if i % 12 == 6 and pj.live(c):
			x.take_hit(pj.inf(c, "shakuton_shakkyu_hoijin", 0.16, {"knock": 0.0, "kind": "light", "element": "shakuton", "burn": 1.0}))
			ShakutonLib.mummify(pj, x, 0.5, 0.5)
			# kafese dokunan da kavrulur
			for e in pj.enemies_near(c, cen, rr + 0.8):
				if e != x:
					e.take_hit(pj.inf(c, "shakuton_shakkyu_hoijin", 0.14, {"knock": 6.0, "kind": "light", "element": "shakuton", "burn": 1.0}))
	var plunge = func():
		if is_instance_valid(cage):
			cage.queue_free()
		var x = wr.get_ref()
		var cen: Vector3 = (x.global_position + Vector3.UP * 1.1) if x != null and is_instance_valid(x) else Vector3.ZERO
		for o in orbs:
			if is_instance_valid(o):
				if cen == Vector3.ZERO:
					cen = o.global_position
				var op: Vector3 = o.global_position
				o.queue_free()
				ShakutonLib.sweep(pj, _arc_pts(op, cen, op.lerp(cen, 0.5) + Vector3.UP * 0.4, 7), 0.2, 0.2)
		ShakutonLib.sear(pj, cen, 1.8, x if x != null and pj.live(x) else null)
		ShakutonLib.dry_patch(pj, cen, 2.6, 4.0, 6)
		if pj.live(c):
			pj.hit(c, cen, 2.8, pj.inf(c, "shakuton_shakkyu_hoijin", 1.5, {"knock": 9.0, "kind": "heavy", "element": "shakuton", "burn": 3.0, "hitstop": 0.12}))
		pj.shake(0.6)
		Sfx.play("fire", cen, 0.7)
	pj.every(DUR, 1.0 / 40.0, ring, plunge)


# ================================================================== 10) Nichirin: küçük güneş
## Küreler başının üstünde tek büyük kürede birleşir (küçük bir güneş): altındaki zemin yavaşça kurur, hava titrer, zerre yağar;
## 5 sn çevredeki düşmanlara kavisli ısı ışınları uzanır; sonunda güneş kilitli hedefin üstüne iner.
## Güneşin yeri: kullanan ile hedef arasında, önde ve yüksekte; kameraya 10 m'den yakın gelmez (ekranı kapatmasın)
static func _sun_anchor(pj: PathJutsu, c: Node3D, tt: Node3D, h: float) -> Vector3:
	var f = c.face_dir()
	var ahead := 4.0
	if pj.live(tt):
		var g: Vector3 = tt.global_position - c.global_position
		g.y = 0.0
		if g.length() > 0.5:
			f = g.normalized()
			ahead = clampf(g.length() * 0.5, 3.0, 8.0)
	var a: Vector3 = c.global_position + f * ahead + Vector3.UP * h
	var cam: Camera3D = pj.get_viewport().get_camera_3d() if pj.is_inside_tree() else null
	if cam:
		var v: Vector3 = a - cam.global_position
		if v.length() < 10.0:
			a = cam.global_position + (v.normalized() if v.length() > 0.01 else -cam.global_basis.z) * 10.0
	return a


## Güneş küresi ve halesi kameraya 9 m'den itibaren incelir
static func _sun_fade(sun: Node3D) -> void:
	for ch in sun.get_children():
		if ch is GeometryInstance3D:
			ch.set_instance_shader_parameter("near", 9.0)
			for g in ch.get_children():
				if g is GeometryInstance3D:
					g.set_instance_shader_parameter("near", 9.0)


static func shakuton_nichirin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 24.0)
	var sun = ShakutonLib.orb_body(1.2, ShakutonLib.PAL_SUN, 0.8)
	_sun_fade(sun)
	var a0 = _sun_anchor(pj, c, tt, 4.5)
	pj.scene_add(sun, a0)
	ShakutonLib.bloom(sun, 1.0, 0.6)
	ShakutonLib.gather(pj, a0, 0.5, 12, 1.6)
	ShakutonLib.haze(pj, Vector3.DOWN * 1.4, 3.2, 2.6, 5.0, sun)
	ShakutonLib.motes(pj, Vector3.ZERO, 30, 1.0, {"dir": Vector3.DOWN, "spread": 70.0, "vmin": 0.5, "vmax": 2.0, "g": Vector3(0, -1.0, 0), "life": 1.2, "emit": 5.0, "parent": sun, "size": 0.09})
	ShakutonLib.dry_patch(pj, c.global_position, 4.0, 7.0, 0)
	Sfx.play("fire", c.global_position, 0.6)
	var DUR := 5.0
	var sun_tick = func(i, k):
		if not is_instance_valid(sun) or not pj.live(c):
			return
		var grow = minf(1.0, k * 6.0)
		sun.global_position = sun.global_position.lerp(_sun_anchor(pj, c, tt, 4.5 + 1.5 * grow), 0.2)
		if i % 15 == 14:
			var o = sun.global_position
			ShakutonLib.light(pj, o, Color(1.0, 0.5, 0.3), 5.0, 12.0, 0.25)
			var n = 0
			for e in pj.enemies_near(c, c.global_position, 15.0):
				if n >= 3:
					break
				n += 1
				var b = e.global_position + Vector3.UP
				# ısı ışını: güneşten kurbana kavis çizen, baştan uca akan akkor şerit
				ShakutonLib.sweep(pj, _arc_pts(o, b, o.lerp(b, 0.5) + Vector3.UP * 0.6, 12), 0.2, 0.45)
				e.take_hit(pj.inf(c, "shakuton_nichirin", 0.26, {"knock": 1.0, "kind": "light", "element": "shakuton", "burn": 2.0}))
				ShakutonLib.sear(pj, b, 0.5, e)
	var sun_fall = func():
		if not is_instance_valid(sun):
			return
		var from = sun.global_position
		sun.queue_free()
		if not pj.live(c):
			return
		var aim = pj.live(tt)
		var goal: Vector3 = (tt.global_position + Vector3.UP) if aim else pj.gp(c.global_position + c.face_dir() * 10.0)
		var pr = pj.shot(c, from, (goal - from).normalized(), 24.0, ShakutonLib.orb_body(1.1, ShakutonLib.PAL_SUN, 1.2), pj.inf(c, "shakuton_nichirin", 1.3, {"knock": 12.0, "kind": "heavy", "element": "shakuton", "burn": 3.0, "hitstop": 0.12}), tt if aim else null, false, 1.6,
			func(p, h):
				ShakutonLib.sear(pj, p, 2.2, h)
				ShakutonLib.dry_patch(pj, p, 4.5, 6.0, 10)
				ShakutonLib.flash(pj, p, 6.0, ShakutonLib.col(0, 2), 0.5)
				if pj.live(c):
					pj.hit(c, p, 4.2, pj.inf(c, "shakuton_nichirin", 0.6, {"knock": 10.0, "kind": "heavy", "element": "shakuton", "burn": 2.0}), [h] if h else [])
				pj.shake(0.8))
		ShakutonLib.tail(pj, pr, 0.75, 14)
		if pr:
			pr.radius = 1.1
		Sfx.play("fire", from, 0.5)
	pj.every(DUR, 1.0 / 30.0, sun_tick, sun_fall)
