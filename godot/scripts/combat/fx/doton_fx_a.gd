class_name DotonFXA
extends RefCounted
## Doton grubu A: on beş toprak tekniğinin görselleri — malzeme ve yapı taşları DotonLib'den (kendi kaya / çamur / toz / zemin
## shader'ları), her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı, zemin bölgeleri) ana ağaçtaki işleyicilerden taşındı.

static var _cache := {}


# ================================================================== ortak oynanış izleri
## Eski zemin çatlağının oyun tarafı: büyük yarık zemin üstünden geçeni yavaşlatır (boy >= 1.5)
static func _crack_zone(pos: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(pos, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


## Eski "toprak çıkışı" patlamasının oyun tarafı (çatlak 2.2 * s)
static func _burst_zone(pos: Vector3, s: float) -> void:
	_crack_zone(pos, 2.2 * s, 6.0)


static func _mouth(c: Node3D) -> Vector3:
	return c.global_position + Vector3.UP * 1.55 + c.face_dir() * 0.4


## Gizlenme (eski genel gizlenme mekaniği birebir): görünmezlik etkisi, yakın düşmanlar hedefi kaybeder, beden en çok 4 sn gizli.
## on_show: beden yeniden görününce (görsel çıkış için)
static func _stealth(pj: PathJutsu, c: Node3D, id: String, on_show := Callable()) -> void:
	var d: Dictionary = Data.jutsu.get(id, {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var dur = 8.0 + tier * 2.0
	Buffs.add("stealth_" + String(d.get("id", "")), dur, {"stealth": 1.0})
	for f in pj.get_tree().get_nodes_in_group("fighters"):
		if Combat.hostile(c, f) and f.global_position.distance_to(c.global_position) < 30 and f.has_method("lose_target"):
			f.lose_target(dur * 0.5)
	if c.get("model"):
		c.model.visible = false
		pj.get_tree().create_timer(minf(dur, 4.0)).timeout.connect(func():
			if is_instance_valid(c) and c.get("model"):
				c.model.visible = true
				if on_show.is_valid():
					on_show.call())
	Sfx.play("poof", c.global_position)


## Kopya (eski genel kopya mekaniği birebir): kademe sayısı kadar kopya çevrede doğar. each: her kopya için görsel
static func _clones(pj: PathJutsu, c: Node3D, id: String, each: Callable) -> void:
	var d: Dictionary = Data.jutsu.get(id, {})
	if d.is_empty():
		return
	var tier = int(d.get("tier", 2))
	var n = clampi(1 + tier / 2, 1, 4)
	for i in n:
		var ang = TAU * i / n
		var off = Vector3(cos(ang), 0, sin(ang)) * 2.6
		var cl = ShadowClone.new()
		cl.team = c.team
		cl.look = c.model.look.duplicate() if c.get("model") else {}
		pj.get_tree().current_scene.add_child(cl)
		cl.global_position = c.global_position + off
		each.call(cl)
	Sfx.play("poof", c.global_position)


# ================================================================== 1) Doro Hane: çamur yaylanması
## Ayağın altındaki toprak kabarcıklı çamur gölüne döner; çamur sütunu ayakları iterek fışkırır (bastırılıp bırakılan yay gibi
## önce ezilir, sonra uzar, sonra yayvanlaşıp çöker), halka halinde çamur topakları saçılıp çevreye yapışır.
static func doro_hane(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.3)
	var at = pj.gp(c.global_position)
	var mud: Color = DotonLib.pal(at)["mud"]
	DotonLib.puddle(pj, at, 1.9, 3.5)
	var colm = Node3D.new()
	DotonLib.put(pj, colm, at)
	for k in 5:
		var b = DotonLib.mud_blob(0.55 - k * 0.07, mud.lightened(k * 0.04))
		b.position = Vector3(randf_range(-0.12, 0.12), k * 0.42, randf_range(-0.12, 0.12))
		colm.add_child(b)
	colm.scale = Vector3(1.3, 0.05, 1.3)
	var tw = colm.create_tween()
	tw.tween_property(colm, "scale", Vector3(1.0, 1.05, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(colm, "scale", Vector3(1.7, 0.05, 1.7), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(colm.queue_free)
	for i in 12:
		var a = TAU * i / 12.0 + randf_range(-0.2, 0.2)
		var dv = Vector3(cos(a), randf_range(1.6, 2.6), sin(a)).normalized()
		DotonLib.toss(pj, DotonLib.mud_blob(randf_range(0.09, 0.18), mud, 0.02), at + Vector3.UP * 0.3, dv * randf_range(5.0, 8.0), 1.0, 20.0, 1.4)
	pj.after(0.55, func():
		for i in 3:
			var a = randf() * TAU
			DotonLib.puddle(pj, at + Vector3(cos(a), 0, sin(a)) * randf_range(1.8, 3.2), randf_range(0.35, 0.55), 2.6))
	GroundFX.add(at, "mud", 1.8, 3.5, c)
	c.velocity = c.face_dir() * 8.0 + Vector3.UP * 16.0
	Sfx.play("earth", at, 1.3)


# ================================================================== 2) Shinjū Zanshu: toprağa boynuna kadar gömme
## Ref: hedef boynuna kadar toprağa çekilir, başın çevresinde halka halinde yuvarlak taş topakları ve kabarmış toprak kalır.
## Atan yere dalar (çukur + içe çöken toprak), yer altından hedefe doğru ilerleyen kabarık toprak izi, hedefin altında zemin açılır.
static func shinju_zanshu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	if tt == null:
		return
	pj.busy(c, 1.0)
	var p0 = pj.gp(c.global_position)
	var pl = DotonLib.pal(p0)
	_burst_zone(c.global_position, 1.2)
	DotonLib.pit(pj, p0, 0.9, 1.1, 0.12)
	DotonLib.crack(pj, p0, 2.2, 3.0, 0.15)
	for i in 8:
		var a = TAU * i / 8.0
		var mi = DotonLib.chunk(randf_range(0.12, 0.2), 0, pl["body"])
		DotonLib.toss(pj, mi, p0 + Vector3(cos(a), 0.15, sin(a)) * 1.1, Vector3(-cos(a), 2.5, -sin(a)) * 2.2, 0.6)
	DotonLib.grit(pj, p0 + Vector3.UP * 0.2, 22, pl["body"], {"vmin": 3.0, "vmax": 6.0, "spread": 40.0})
	# yer altı yolculuğu: atandan hedefe uzanan kabarık toprak izi
	var tpos = pj.gp(tt.global_position)
	var n = int(clampf(p0.distance_to(tpos) / 1.1, 2.0, 14.0))
	for k in n:
		var q = p0.lerp(tpos, float(k + 1) / float(n + 1))
		pj.after(0.05 + 0.38 * float(k) / float(n), func():
			var m = DotonLib.chunk(1.0, 0, pl["top"].lerp(pl["body"], 0.4), {"ow": 0.025, "top": pl["top"], "top_y": 0.5, "upright": true})
			m.scale = Vector3(0.55, 0.22, 0.55)
			DotonLib.rise(pj, m, pj.gp(q), 0.25, 0.08, 0.35, 0.5)
			DotonLib.grit(pj, pj.gp(q) + Vector3.UP * 0.1, 6, pl["body"], {"vmin": 2.0, "vmax": 4.0, "spread": 35.0, "life": 0.6}))
	c.visible = false
	pj.after(0.45, func():
		if not pj.live(c):
			return
		c.visible = true
		if not pj.live(tt):
			return
		var at = tt.global_position
		c.global_position = pj.gp(at + (c.global_position - at).normalized() * 1.2)
		_burst_zone(at, 1.6)
		var ga = pj.gp(at)
		var hold = 2.85
		# hedefin çevresinde zemin yarılır, çukur açılır ve taş topakları yakasına kapanır
		DotonLib.crack(pj, ga, 3.2, 5.0, 0.2, 0.0, 8.0)
		DotonLib.pit(pj, ga, 0.75, hold + 0.5, 0.15)
		var rr = 0.42 + float(tt.get("radius") if tt.get("radius") != null else 0.4)
		for i in 11:
			var a = TAU * i / 11.0 + randf_range(-0.12, 0.12)
			var r = rr + randf_range(0.0, 0.35) + (0.35 if i % 3 == 0 else 0.0)
			var sn = DotonLib.chunk(1.0, 0, pl["body"].lightened(randf_range(0.0, 0.15)), {"ow": 0.03, "upright": true})
			var sz = randf_range(0.26, 0.4)
			sn.scale = Vector3(sz, sz * 0.7, sz)
			DotonLib.rise(pj, sn, pj.gp(ga + Vector3(cos(a), 0, sin(a)) * r) + Vector3.UP * sz * 0.25, 0.6, 0.16, hold, 0.4, i * 0.01)
		for i in 7:
			var a = randf() * TAU
			var pb = DotonLib.chunk(randf_range(0.06, 0.12), 0, pl["body"].darkened(0.1), {"ow": 0.02})
			DotonLib.toss(pj, pb, ga + Vector3(cos(a), 0.2, sin(a)) * 0.5, Vector3(cos(a), 1.6, sin(a)) * 3.5, 0.7)
		DotonLib.dust_ring(pj, ga, 0.6, 2.4, 7, 1.3, 0.9, pl["dust"])
		# atanın çıkışı: toprağı yarıp yükselir
		var cp = c.global_position
		DotonLib.burst_chunks(pj, cp, 7, 0.16, 5.0, pl["body"], 1.6, 0, 0.8)
		DotonLib.grit(pj, cp + Vector3.UP * 0.2, 18, pl["body"], {"vmin": 3.0, "vmax": 7.0, "spread": 30.0})
		pj.st(tt, "bind", 3.0)
		tt.take_hit(pj.inf(c, "doton_shinju_zanshu_no_jutsu", 0.5, {"knock": 0.0, "kind": "heavy", "element": "doton"}))
		var body = tt.get("model") if tt.get("model") else tt
		var y0 = body.position.y
		var tw = body.create_tween()
		tw.tween_property(body, "position:y", y0 - tt.height * 0.75, 0.25)
		tw.tween_interval(2.6)
		tw.tween_property(body, "position:y", y0, 0.3)
		Combat.popup_text(at + Vector3.UP * 1.2, "Toprağa gömüldü!", PathJutsu.EARTH.lightened(0.3))
		pj.shake(0.4)
		Sfx.play("earth", at, 1.0))


# ================================================================== 3) Sazareishi: çakıl saçması
## Ref: sivri, keskin yüzlü kıymık taşlar. Zeminden kıymıklar avuca çekilir; salınımda avuçtan geniş koni halinde sivri çakıl
## yağmuru + öne doğru açılan cel toz jeti + ince çakıl tozu.
static func _shard(col: Color) -> Node3D:
	var root = Node3D.new()
	var mi = DotonLib.chunk(randf_range(0.07, 0.13), 1, col.darkened(randf_range(0.0, 0.2)), {"ow": 0.018, "upright": true})
	mi.rotation = Vector3(-PI * 0.5, 0.0, randf() * TAU)
	root.add_child(mi)
	return root


static func sazareishi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	pj.anim(c, "push", 1.6)
	var tt = pj.tg(c, t, 18.0)
	var from = pj.hand_pos(c, true)
	var dir = pj.aim_at(c, tt, from)
	var pl = DotonLib.pal(c.global_position)
	var col: Color = pl["body"].lerp(Color(0.72, 0.6, 0.42), 0.4)
	for i in 9:
		var g0 = DotonLib.floor_at(c.global_position + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8)))
		var sh = DotonLib.chunk(randf_range(0.07, 0.12), 1, col)
		DotonLib.put(pj, sh, g0)
		var tw = sh.create_tween()
		tw.tween_property(sh, "global_position", from, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(sh.queue_free)
	DotonLib.grit(pj, DotonLib.floor_at(c.global_position) + Vector3.UP * 0.1, 14, col, {"vmin": 1.5, "vmax": 3.0, "spread": 70.0, "life": 0.5})
	pj.after(0.12, func():
		for k in 18:
			var d = dir.rotated(Vector3.UP, randf_range(-0.3, 0.3)) + Vector3.UP * randf_range(-0.06, 0.08)
			var pr = pj.shot(c, from, d.normalized(), randf_range(30.0, 42.0), _shard(col), pj.inf(c, "doton_sazareishi", 0.07, {"knock": 1.0, "kind": "light", "element": "doton"}), null, false, 0.7)
			if pr and k % 3 == 0:
				pr.on_hit = func(p: Vector3, _h: Node3D) -> void:
					DotonLib.grit(pj, p, 5, col, {"vmin": 2.0, "vmax": 4.0, "spread": 120.0, "life": 0.5})
		for k in 5:
			var q = from + dir * (0.5 + k * 1.1)
			DotonLib.dust(pj, q, 0.7 + k * 0.35, 0.55 + k * 0.06, dir * (7.0 - k), pl["dust"])
		DotonLib.grit(pj, from, 36, col, {"dir": dir, "spread": 18.0, "vmin": 16.0, "vmax": 28.0, "g": 5.0, "r": 0.15, "life": 0.55, "size": 0.05}))
	Sfx.play("earth", from, 1.8, 0.6)


# ================================================================== 4) Renga: tuğla blokları
## Ref: harç çizgili büyük tuğla blokları. Avuç zemine basılır, zemin çatlar; önünde dört tuğla blok yerden sökülerek yükselir
## (altında çatlak + çakıl), sırayla fırlar, çarpınca tuğlalara bölünüp tozla dağılır.
static func _brick_mesh(v: int) -> ArrayMesh:
	var key = "brick_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 991 + v * 37
	var m = DotonLib.prism_mesh(DotonLib.jag_rect(1.0, 0.7, 1, 0.03, rng), -0.3, 0.3, 0.1, 0.02, rng.randi())
	_cache[key] = m
	return m


static func _brick(col: Color) -> MeshInstance3D:
	return DotonLib.rock(_brick_mesh(randi() % 4), col.darkened(randf_range(0.0, 0.12)), {"brick": true, "ow": 0.035})


static func renga_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	pj.anim(c, "crouch", 1.5)
	var tt = pj.tg(c, t, 24.0)
	var g0 = pj.gp(c.global_position + c.face_dir())
	var pl = DotonLib.pal(g0)
	var bcol: Color = pl["body"].lerp(Color(0.6, 0.42, 0.32), 0.5)
	_burst_zone(g0, 1.4)
	DotonLib.crack(pj, g0, 2.6, 4.0, 0.18, 0.0, 6.0)
	DotonLib.grit(pj, g0 + Vector3.UP * 0.1, 16, pl["body"], {"vmin": 2.0, "vmax": 5.0, "spread": 60.0})
	for k in 4:
		# yükseliş (fırlatmadan 0.16 sn önce): blok zeminden sökülür
		pj.after(0.02 + k * 0.12, func():
			if not pj.live(c):
				return
			var f0 = c.global_position + c.face_dir() * 1.0 + c.face_dir().cross(Vector3.UP) * (k - 1.5) * 0.7 + Vector3.UP * 0.8
			var vb = _brick(bcol)
			vb.rotation.y = c.rotation.y
			DotonLib.rise(pj, vb, f0, 1.3, 0.15, 0.02, 0.05)
			DotonLib.grit(pj, pj.gp(f0) + Vector3.UP * 0.1, 8, pl["body"], {"vmin": 2.0, "vmax": 4.5, "spread": 45.0, "life": 0.6}))
		pj.after(0.18 + k * 0.12, func():
			if not pj.live(c):
				return
			var from = c.global_position + c.face_dir() * 1.0 + c.face_dir().cross(Vector3.UP) * (k - 1.5) * 0.7 + Vector3.UP * 0.8
			_burst_zone(pj.gp(from), 0.7)
			DotonLib.pit(pj, pj.gp(from), 0.55, 2.2, 0.1, Vector2(1.3, 1.0))
			DotonLib.dust(pj, pj.gp(from) + Vector3.UP * 0.4, 1.2, 0.7, Vector3.UP * 0.6, pl["dust"])
			var root = Node3D.new()
			root.add_child(_brick(bcol))
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 26.0, root, pj.inf(c, "doton_renga_no_jutsu", 0.4, {"knock": 6.0, "kind": "heavy", "element": "doton"}), null, false, 1.4, func(p, _h):
				for i in 6:
					var a = TAU * i / 6.0
					var bb = _brick(bcol)
					bb.scale = Vector3.ONE * randf_range(0.3, 0.45)
					DotonLib.toss(pj, bb, p, Vector3(cos(a), randf_range(0.6, 1.4), sin(a)) * randf_range(4.0, 7.0), 1.1)
				DotonLib.dust(pj, p, 1.6, 0.8, Vector3.UP * 0.5, pl["dust"])
				DotonLib.grit(pj, p, 14, bcol, {"vmin": 3.0, "vmax": 7.0, "spread": 150.0}))
			pr.spin = Vector3(6, 0, 3)
			pj.shake(0.2))
	Sfx.play("earth", c.global_position, 1.4)


# ================================================================== 5) Moguragakure: köstebek gibi kazıp gizlenme
## Ref: çevresi kırık topaklarla çevrili karanlık delik. Ayakların altında delik açılır, toprak köstebek kazar gibi geriye ve
## yanlara kürek kürek savrulur; yer altında ilerlerken üstünde kabarık toprak tümsekleri (köstebek yolu) belirir;
## çıkışta zemin yarılıp kırık topaklar halka halinde fırlar.
static func _dig_hole(pj: PathJutsu, p: Vector3, pl: Dictionary, back: Vector3, life: float) -> void:
	DotonLib.pit(pj, p, 1.0, life, 0.15)
	for i in 7:
		var a = TAU * i / 7.0 + randf_range(-0.2, 0.2)
		var rm = DotonLib.chunk(1.0, 0, pl["body"].lightened(randf_range(0.0, 0.1)), {"ow": 0.03, "upright": true, "top": pl["top"], "top_y": 0.55})
		var sz = randf_range(0.22, 0.34)
		rm.scale = Vector3(sz * 1.2, sz * 0.7, sz)
		DotonLib.rise(pj, rm, pj.gp(p + Vector3(cos(a), 0, sin(a)) * 0.95), 0.4, 0.12, life - 0.6, 0.45, i * 0.02)
	for k in 4:
		pj.after(k * 0.07, func():
			for i in 4:
				var dv = (back + DotonLib.side_of(back) * randf_range(-0.9, 0.9) + Vector3.UP * randf_range(1.2, 1.8)).normalized()
				var cl = DotonLib.chunk(randf_range(0.1, 0.2), 0, pl["body"].darkened(randf_range(0.0, 0.15)), {"ow": 0.025})
				DotonLib.toss(pj, cl, p + Vector3.UP * 0.2, dv * randf_range(4.0, 7.0), 1.0)
			DotonLib.grit(pj, p + Vector3.UP * 0.15, 10, pl["body"], {"dir": (back + Vector3.UP).normalized(), "spread": 35.0, "vmin": 3.0, "vmax": 6.0, "life": 0.7}))


static func moguragakure_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var p0 = pj.gp(c.global_position)
	var pl = DotonLib.pal(p0)
	_burst_zone(c.global_position, 0.8)
	_dig_hole(pj, p0, pl, -DotonLib.flat(c.face_dir()), 4.4)
	var last = {"p": p0}
	pj.every(4.0, 0.18, func(_i, _k):
		if not pj.live(c):
			return
		var q = pj.gp(c.global_position)
		if q.distance_to(last["p"]) < 0.7:
			return
		last["p"] = q
		var m = DotonLib.chunk(1.0, 0, pl["body"], {"ow": 0.025, "upright": true, "top": pl["top"], "top_y": 0.55})
		m.scale = Vector3(randf_range(0.42, 0.55), 0.24, randf_range(0.42, 0.55))
		DotonLib.rise(pj, m, q, 0.3, 0.1, 0.9, 0.7)
		DotonLib.grit(pj, q + Vector3.UP * 0.1, 5, pl["body"], {"vmin": 1.5, "vmax": 3.0, "spread": 50.0, "life": 0.5}), Callable())
	_stealth(pj, c, "doton_moguragakure_no_jutsu", func():
		var q = pj.gp(c.global_position)
		var pq = DotonLib.pal(q)
		DotonLib.crack(pj, q, 2.0, 2.5, 0.12)
		DotonLib.pit(pj, q, 0.8, 1.6, 0.1)
		DotonLib.burst_chunks(pj, q, 9, 0.2, 6.0, pq["body"], 1.8, 0, 0.9)
		DotonLib.dust_ring(pj, q, 0.4, 1.8, 5, 1.1, 0.8, pq["dust"]))


# ================================================================== 6) Dochū Eigyo: yer altında balık gibi süzülme
## Ref: beden toprağa su gibi yarı gömülü ilerler. Zemin sıvı gibi davranır: dalışta toprak taç gibi sıçrar (çukur yok, kapanır),
## gizliyken bulunduğu yerde halka halka toprak dalgaları yayılır, hareket ettikçe arkasında V biçimli toprak iz dalgası
## ve ince çakıl serpintisi; çıkışta yine sıvı gibi sıçrayarak fırlar.
static func _soil_splash(pj: PathJutsu, p: Vector3, pl: Dictionary, s: float) -> void:
	DotonLib.ripple(pj, p, 3.6 * s, 1.2)
	for i in 12:
		var a = TAU * i / 12.0 + randf_range(-0.15, 0.15)
		var cl = DotonLib.chunk(randf_range(0.08, 0.16) * s, 0, pl["body"].lightened(randf_range(0.0, 0.12)), {"ow": 0.02})
		DotonLib.toss(pj, cl, p + Vector3(cos(a), 0.1, sin(a)) * 0.5, Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.45).normalized() * randf_range(5.0, 7.5) * s, 1.0, 20.0, 0.5)
	DotonLib.grit(pj, p + Vector3.UP * 0.1, 24, pl["body"], {"vmin": 4.0, "vmax": 8.0, "spread": 22.0, "life": 0.8})


static func dochu_eigyo_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var p0 = pj.gp(c.global_position)
	var pl = DotonLib.pal(p0)
	_burst_zone(c.global_position, 0.8)
	_soil_splash(pj, p0, pl, 1.0)
	var last = {"p": p0}
	pj.every(4.0, 0.15, func(i, _k):
		if not pj.live(c):
			return
		var q = pj.gp(c.global_position)
		if i % 2 == 0:
			DotonLib.ripple(pj, q, 1.7, 0.85)
		var mv = q - last["p"]
		mv.y = 0.0
		if mv.length() > 0.25:
			var md = mv.normalized()
			var sd = DotonLib.side_of(md)
			for s in [-1.0, 1.0]:
				DotonLib.grit(pj, q - md * 0.3 + sd * s * 0.35, 4, pl["body"], {"dir": (sd * s - md * 0.6 + Vector3.UP * 0.8).normalized(), "spread": 18.0, "vmin": 2.0, "vmax": 3.5, "life": 0.45, "size": 0.05})
		last["p"] = q, Callable())
	_stealth(pj, c, "doton_dochu_eigyo_no_jutsu", func():
		var q = pj.gp(c.global_position)
		_soil_splash(pj, q, DotonLib.pal(q), 0.8))


# ================================================================== 7) Retsudo Tenshō: toprağı yırtıp döndürme
## Ref: zemin dev levhalar halinde yırtılıp kalkar. Avuç basılınca zemindeki taneler sarmal çizerek avuca akar; sonra sarmal
## çatlak ağı açılır, üç halka halinde üst örtülü toprak levhaları dışa eğik fırlar ve tüm halka merkez çevresinde döner
## (yırtılarak dönme), toz duvarı dışa yayılır, levhalar ağır ağır gömülür.
static func _slab_mesh(v: int) -> ArrayMesh:
	var key = "rslab_%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 4421 + v * 53
	var m = DotonLib.prism_mesh(DotonLib.jag_rect(1.5, 0.75, 2, 0.1, rng), -1.6, 0.25, 0.08, 0.06, rng.randi())
	_cache[key] = m
	return m


static func retsudo_tensho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj.anim(c, "crouch", 1.2)
	var at = pj.gp(c.global_position + c.face_dir() * 1.0)
	var pl = DotonLib.pal(at)
	for i in 14:
		var a0 = randf() * TAU
		var r0 = randf_range(2.5, 4.5)
		var gr = DotonLib.chunk(randf_range(0.06, 0.11), randi() % 2, pl["body"], {"ow": 0.015})
		DotonLib.put(pj, gr, at)
		var tw = gr.create_tween()
		tw.tween_method(func(k: float) -> void:
			if is_instance_valid(gr):
				var a = a0 + k * 2.4
				gr.global_position = DotonLib.floor_at(at + Vector3(cos(a), 0, sin(a)) * r0 * (1.0 - k)) + Vector3.UP * (0.08 + 0.25 * k), 0.0, 1.0, 0.2)
		tw.tween_callback(gr.queue_free)
	pj.after(0.2, func():
		_crack_zone(at, 10.0, 8.0)
		DotonLib.crack(pj, at, 10.0, 8.0, 0.35, 2.4, 9.0)
		DotonLib.crack(pj, at, 5.0, 7.0, 0.2, -1.5, 6.0)
		var ring = Node3D.new()
		DotonLib.put(pj, ring, at)
		var rt = ring.create_tween()
		rt.tween_property(ring, "rotation:y", 0.7, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rt.tween_interval(1.6)
		rt.tween_property(ring, "position:y", ring.position.y - 2.2, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rt.tween_callback(ring.queue_free)
		for k in 3:
			pj.after(k * 0.15, func():
				var r = 2.4 + k * 2.2
				var cnt = 6 + k * 3
				for i in cnt:
					var a = TAU * (i + randf_range(-0.2, 0.2)) / cnt
					var rad = Vector3(cos(a), 0, sin(a))
					var q = at + rad * r
					var fy = Game.jutsu_floor(q.x, q.z) - at.y
					var sl = DotonLib.rock(_slab_mesh(randi() % 5), pl["body"], {"top": pl["top"], "top_y": 0.25, "strata": 2.6, "ow": 0.045, "shadow": true})
					ring.add_child(sl)
					var lr = ring.global_basis.inverse() * rad
					sl.basis = Basis.looking_at(lr, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(-randf_range(35.0, 62.0)))
					var sz = randf_range(0.8, 1.25) * (1.0 + k * 0.15)
					sl.scale = Vector3.ONE * sz
					var lp = ring.global_basis.inverse() * (rad * r)
					sl.position = lp + Vector3.UP * (fy - 1.6 * sz)
					var tw = sl.create_tween()
					tw.tween_property(sl, "position:y", fy + 0.1, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					if i % 2 == 0:
						DotonLib.grit(pj, DotonLib.floor_at(q) + Vector3.UP * 0.2, 8, pl["body"], {"dir": (rad + Vector3.UP * 1.5).normalized(), "spread": 30.0, "vmin": 5.0, "vmax": 10.0})
				DotonLib.dust_ring(pj, at, r, r + 3.0, 6 + k * 3, 2.0 + k * 0.4, 1.2, pl["dust"])
				DotonLib.burst_chunks(pj, at, 6, 0.3, 9.0 + k * 2.0, pl["body"], 1.2, -1, 1.2))
		pj.shake(1.0)
		for e in pj.hit(c, at + Vector3.UP * 0.5, 7.0, pj.inf(c, "doton_retsudo_tensho", 0.6, {"knock": 3.0, "launch": 4.0, "kind": "heavy", "element": "doton"})):
			pj.st(e, "stun", 1.4))
	Sfx.play("earth", at, 0.7)


# ================================================================== 8) Tobi Tsubute: uçan taşlar
## Ref: koyu, keskin köşeli kaya blokları kabarık cel toz bulutundan fırlar. Zemin çatlar, sekiz blok küçük kraterlerden kopup
## çevrede asılı kalır (yavaş döner), kalın toz bulutu kabarır; sonra bloklar toz izi bırakarak hedefe yağar, çarpınca parçalanır.
static func _block(pl: Dictionary, s: float) -> MeshInstance3D:
	return DotonLib.chunk(s, 2, pl["stone"].darkened(randf_range(0.0, 0.12)), {"ow": 0.045})


static func tobi_tsubute(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	pj.anim(c, "cast", 1.3)
	var tt = pj.tg(c, t, 22.0)
	var pl = DotonLib.pal(c.global_position)
	_burst_zone(c.global_position, 1.8)
	DotonLib.crack(pj, c.global_position, 4.0, 4.0, 0.2, 0.0, 8.0)
	DotonLib.dust_ring(pj, c.global_position, 1.2, 4.5, 10, 2.4, 1.5, pl["dust"])
	var rocks = []
	for k in 8:
		var r = _block(pl, randf_range(0.5, 0.8))
		pj.get_tree().current_scene.add_child(r)
		var a = TAU * k / 8.0
		var q = c.global_position + Vector3(cos(a), 0, sin(a)) * 2.0
		r.global_position = pj.gp(q) - Vector3.UP * 0.5
		r.create_tween().tween_property(r, "global_position", q + Vector3.UP * 1.8, 0.35).set_trans(Tween.TRANS_BACK)
		r.create_tween().tween_property(r, "rotation", r.rotation + Vector3(randf_range(-1, 1), randf_range(-2, 2), randf_range(-1, 1)), 0.95)
		DotonLib.pit(pj, pj.gp(q), 0.6, 2.0, 0.1)
		DotonLib.grit(pj, pj.gp(q) + Vector3.UP * 0.1, 8, pl["stone"], {"vmin": 3.0, "vmax": 6.0, "spread": 30.0})
		rocks.append(r)
	pj.shake(0.4)
	Sfx.play("earth", c.global_position, 1.2)
	pj.after(0.6, func():
		for k in rocks.size():
			var r: Node3D = rocks[k]
			if not is_instance_valid(r):
				continue
			var from = r.global_position
			r.queue_free()
			if pj.live(c):
				var body = Node3D.new()
				body.add_child(_block(pl, 0.6))
				var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 28.0, body, pj.inf(c, "doton_tobi_tsubute", 0.3, {"knock": 5.0, "kind": "heavy", "element": "doton"}), tt, false, 1.4, func(p, _h):
					DotonLib.burst_chunks(pj, p, 6, 0.2, 6.0, pl["stone"], 0.9, 2, 1.0)
					DotonLib.dust(pj, p, 1.8, 0.9, Vector3.UP * 0.6, pl["dust"])
					DotonLib.grit(pj, p, 12, pl["stone"], {"vmin": 3.0, "vmax": 7.0, "spread": 150.0}))
				pr.spin = Vector3(5, 3, 0)
				var acc = {"t": 0.0}
				pr.on_tick = func(p2, dt: float) -> void:
					acc["t"] += dt
					if acc["t"] > 0.07 and is_instance_valid(p2):
						acc["t"] = 0.0
						DotonLib.dust(pj, p2.global_position, 0.55, 0.45, Vector3.ZERO, pl["dust"]))


# ================================================================== 9) Iwagakure: kayaya gizlenme
## Ref: beden dalgalı katmanlı kaya duvarının içine karışır. İki yarım kaya kütlesi atanın iki yanından yükselip ortada kapanır
## (yarık kapanırken çakıl dökülür), katman şeritli tek bir kaya çıkıntısı olur; süre bitince ikiye ayrılıp gömülür.
static func _outcrop_mesh(v: int, side: float) -> ArrayMesh:
	var key = "outc_%d_%d" % [v, int(side)]
	if _cache.has(key):
		return _cache[key]
	var rng = RandomNumberGenerator.new()
	rng.seed = 3301 + v * 29 + int(side) * 7
	var ol = PackedVector2Array()
	var n = 7
	for i in n + 1:
		var a = -PI * 0.5 + PI * float(i) / float(n)
		var rr = 0.85 * (1.0 + rng.randf_range(-0.15, 0.12))
		ol.append(Vector2(cos(a) * rr * side, sin(a) * rr))
	var m = DotonLib.prism_mesh(ol, 0.0, 2.5 + rng.randf_range(-0.2, 0.25), 0.07, 0.2, rng.randi())
	_cache[key] = m
	return m


static func iwagakure_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var base = pj.gp(c.global_position)
	var pl = DotonLib.pal(base)
	var rcol: Color = pl["stone"].lerp(pl["body"], 0.35)
	var rk = Node3D.new()
	DotonLib.put(pj, rk, base)
	rk.rotation.y = c.rotation.y
	var v = randi() % 3
	var halves = []
	for s in [-1.0, 1.0]:
		var h = DotonLib.rock(_outcrop_mesh(v, s), rcol, {"strata": 3.2, "ow": 0.05, "shadow": true})
		h.position = Vector3(s * 0.9, 0, 0)
		rk.add_child(h)
		halves.append(h)
		var th = h.create_tween()
		th.tween_interval(0.12)
		th.tween_property(h, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		th.tween_interval(3.45)
		th.tween_property(h, "position:x", s * 0.6, 0.2)
	for i in 3:
		var a = randf() * TAU
		var sm = DotonLib.chunk(randf_range(0.3, 0.45), 0, rcol.darkened(0.08), {"ow": 0.035, "strata": 3.2, "upright": true})
		sm.position = Vector3(cos(a) * 1.15, 0.1, sin(a) * 1.15)
		rk.add_child(sm)
	rk.scale = Vector3(1.0, 0.05, 1.0)
	var tw = rk.create_tween()
	tw.tween_property(rk, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(3.5)
	tw.tween_property(rk, "scale", Vector3(1.0, 0.05, 1.0), 0.3)
	tw.tween_callback(rk.queue_free)
	DotonLib.crack(pj, base, 1.4, 4.2, 0.15)
	DotonLib.grit(pj, base + Vector3.UP * 0.2, 16, rcol, {"vmin": 2.0, "vmax": 5.0, "spread": 60.0})
	pj.after(0.34, func():
		DotonLib.grit(pj, base + Vector3.UP * 2.2, 12, rcol, {"dir": Vector3.DOWN, "spread": 25.0, "vmin": 0.5, "vmax": 1.5, "life": 0.7, "size": 0.05}))
	_stealth(pj, c, "doton_iwagakure_no_jutsu")


# ================================================================== 10) Dosekiryū: çamur seli
## Ref: geniş çamur seli; koyu akış çizgileri, önünde kabaran yuvarlak kenar, kaya sürükler. ~1 m kabarık kesitli ıslak koyu kahve
## gövde ileri açılır (akan çizgi + ıslak parıltı), önde ~1.5 m yuvarlanan çamur dudağı ve kayalar, üstünde yuvarlanarak akan
## topaklar; sel bir süre kalır, kuruyup açılarak delinir ve toprağa çöker.
static func dosekiryu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	pj.anim(c, "crouch", 1.4)
	var d = pj.fwd(c, t)
	var p0 = c.global_position
	var pl = DotonLib.pal(p0)
	var mcol: Color = Color(0.46, 0.33, 0.2).lerp(pl["mud"], 0.3)
	var sd = DotonLib.side_of(d)
	var pts = PackedVector3Array()
	var ws = PackedFloat32Array()
	var hs = PackedFloat32Array()
	var L = 18.5
	var nseg = 46
	for i in nseg + 1:
		var k = float(i) / float(nseg)
		var q = p0 + d * (0.6 + k * L)
		pts.append(DotonLib.floor_at(q))
		ws.append(lerpf(2.0, 4.8, clampf(k * 4.0, 0.0, 1.0)) + 0.4 * k)
		hs.append(lerpf(0.4, 1.0, clampf(k * 3.0, 0.0, 1.0)) * (0.9 + 0.1 * sin(k * 23.0)))
	var sm = DotonLib.gi(DotonLib.strip_mesh(pts, ws, sd, 0.05, hs), DotonLib.flow_mat())
	sm.set_instance_shader_parameter("base", DotonLib.v3(mcol))
	sm.set_instance_shader_parameter("seed", randf() * 10.0)
	sm.set_instance_shader_parameter("head", 0.0)
	sm.set_instance_shader_parameter("fade", 0.0)
	DotonLib.put(pj, sm, Vector3.ZERO)
	# önde kabaran yuvarlak çamur dudağı (~1.5 m) + sürüklenen kayalar; gövdenin açılan ucunu örter, onunla eş ilerler
	var wave = Node3D.new()
	DotonLib.put(pj, wave, DotonLib.floor_at(p0 + d * 0.6))
	wave.basis = Basis.looking_at(d, Vector3.UP)
	for i in 12:
		var x = -2.3 + 4.6 * float(i) / 11.0
		var e = 1.0 - absf(x) / 2.6
		var b = DotonLib.mud_blob(randf_range(0.5, 0.75) * (0.6 + 0.4 * e), mcol.darkened(randf_range(0.0, 0.15)), 0.035)
		b.position = Vector3(x, 0.35 + 0.6 * e + randf_range(-0.1, 0.1), randf_range(-0.3, 0.3))
		wave.add_child(b)
		var tb = b.create_tween().set_loops(5)
		tb.tween_property(b, "rotation:x", b.rotation.x - TAU * 0.5, 0.14)
	for i in 4:
		var rkk = DotonLib.chunk(randf_range(0.3, 0.5), 2, pl["stone"], {"ow": 0.035})
		rkk.position = Vector3(randf_range(-1.8, 1.8), randf_range(0.9, 1.4), randf_range(0.2, 1.0))
		wave.add_child(rkk)
	var tw = sm.create_tween()
	tw.tween_method(func(h: float) -> void:
		if is_instance_valid(sm):
			sm.set_instance_shader_parameter("head", h)
		if is_instance_valid(wave):
			wave.global_position = DotonLib.floor_at(p0 + d * (0.6 + h - 0.35)), 0.3, L + 0.4, 0.62)
	tw.tween_interval(2.4)
	tw.tween_method(DotonLib.pf(sm, "fade"), 0.0, 1.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sm, "position:y", -0.9, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(sm.queue_free)
	var ww = wave.create_tween()
	ww.tween_interval(0.62)
	ww.tween_property(wave, "scale", Vector3(1.5, 0.05, 1.3), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ww.tween_callback(wave.queue_free)
	# çıkış kaynağı: atanın önünde kabaran çamur
	var src = Node3D.new()
	DotonLib.put(pj, src, DotonLib.floor_at(p0 + d * 0.5))
	for i in 4:
		var b = DotonLib.mud_blob(randf_range(0.4, 0.6), mcol, 0.03)
		b.position = sd * randf_range(-0.9, 0.9) + Vector3.UP * 0.15
		src.add_child(b)
	src.scale = Vector3(1, 0.05, 1)
	var ts = src.create_tween()
	ts.tween_property(src, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ts.tween_interval(2.2)
	ts.tween_property(src, "scale", Vector3(1.3, 0.05, 1.3), 0.8)
	ts.tween_callback(src.queue_free)
	# gövdenin üstünde yuvarlanarak akan topaklar
	for i in 9:
		var xo = randf_range(-0.6, 0.6)
		var r = randf_range(0.18, 0.32)
		var lump = DotonLib.mud_blob(r, mcol.lightened(randf_range(0.0, 0.1)), 0.025) if i % 3 != 0 else DotonLib.chunk(r, 0, pl["stone"], {"ow": 0.03})
		var z0 = randf_range(0.5, 3.0)
		var spd = randf_range(9.0, 13.0)
		var dl = 0.15 + i * 0.12
		var life = (L - z0) / spd
		lump.visible = false
		DotonLib.put(pj, lump, p0)
		var tl = lump.create_tween()
		tl.tween_interval(dl)
		tl.tween_callback(func(): lump.visible = true)
		tl.tween_method(func(z: float) -> void:
			if not is_instance_valid(lump):
				return
			var kz = clampf(z / L, 0.0, 1.0)
			var hh = lerpf(0.4, 1.0, clampf(kz * 3.0, 0.0, 1.0)) * pow(maxf(1.0 - xo * xo, 0.0), 0.6)
			var w = lerpf(2.0, 4.8, clampf(kz * 4.0, 0.0, 1.0)) * 0.5
			var q = p0 + d * (0.6 + z) + sd * xo * w
			lump.global_position = DotonLib.floor_at(q) + Vector3.UP * (0.05 + hh + r * 0.6)
			lump.rotation = Vector3(-z / maxf(r, 0.1), 0.0, 0.0).rotated(Vector3.UP, 0.0), z0, L - 0.5, life)
		tl.tween_property(lump, "scale", Vector3(r * 1.5, r * 0.2, r * 1.5), 0.4)
		tl.tween_callback(lump.queue_free)
	for k in 10:
		pj.after(k * 0.06, func():
			var q = pj.gp(c.global_position + d * (1.5 + k * 1.6))
			for s in [-1.0, 1.0]:
				var mb = DotonLib.mud_blob(randf_range(0.12, 0.22), mcol, 0.02)
				DotonLib.toss(pj, mb, q + sd * s * 2.0 + Vector3.UP * 0.3, (sd * s * 0.6 + d * 0.5 + Vector3.UP).normalized() * randf_range(4.0, 6.5), 0.9, 20.0, 0.6)
			if k % 3 == 0:
				DotonLib.grit(pj, q + Vector3.UP * 0.3, 10, pl["stone"], {"dir": (d + Vector3.UP).normalized(), "spread": 40.0, "vmin": 3.0, "vmax": 6.0})
			_crack_zone(q, 1.6, 6.0)
			for e in pj.hit(c, q + Vector3.UP * 0.5, 2.2, pj.inf(c, "doton_dosekiryu", 0.15, {"knock": 7.0, "kind": "light", "element": "doton", "dir": d})):
				pj.st(e, "slow", 3.0))
	pj.shake(0.4)
	Sfx.play("earth", c.global_position, 0.8)


# ================================================================== 11) Kaya Sığınağı (Earth Release Rock Shelter)
## Ref (üç kare): kalın, yumrulu toprak kubbe; kesik ağzında kalın katmanlı kenar, içi karanlık, dibinde kaya topakları ve kabarık toz.
## Zemin çatlar, kubbe dönerek yerden yükselir; ağzı arkaya (kamera tarafına) açık, ön taraf düşmana kapalı.
static func earth_release_rock_shelter(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	pj.anim(c, "crouch", 1.4)
	var at = pj.gp(c.global_position)
	var pl = DotonLib.pal(at)
	_crack_zone(at, 6.0)
	DotonLib.crack(pj, at, 5.0, 5.6, 0.3, 0.0, 8.0)
	DotonLib.dust_ring(pj, at, 1.5, 4.5, 9, 2.2, 1.3, pl["dust"])
	var face = DotonLib.flat(c.face_dir())
	var yaw = atan2(-face.x, -face.z)
	var dome = Node3D.new()
	var shell = DotonLib.rock(DotonLib.shell_mesh(2.6, 0.5, 0.85, 0.75, 0.8, randi() % 4), pl["body"], {"strata": 1.4, "ow": 0.055, "shadow": true})
	dome.add_child(shell)
	for i in 8:
		var a = TAU * (i + 0.5) / 8.0
		if absf(wrapf(a, -PI, PI)) < 0.8:
			continue
		var bd = DotonLib.chunk(randf_range(0.55, 0.85), 0, pl["body"].darkened(randf_range(0.0, 0.12)), {"ow": 0.045, "upright": true, "strata": 1.4})
		bd.position = Vector3(sin(a) * 2.7, 0.15, cos(a) * 2.7)
		dome.add_child(bd)
	get_tree_scene(pj).add_child(dome)
	dome.global_position = at - Vector3.UP * 3.2
	dome.rotation.y = yaw - 0.6
	var tw = dome.create_tween()
	tw.tween_property(dome, "global_position", at, 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(dome, "rotation:y", yaw, 0.35)
	tw.tween_callback(func():
		DotonLib.dust_ring(pj, at, 2.6, 6.5, 12, 2.6, 1.4, pl["dust"])
		DotonLib.burst_chunks(pj, at, 10, 0.3, 8.0, pl["body"], 0.9, -1, 1.1)
		DotonLib.grit(pj, at + Vector3.UP * 2.2, 18, pl["body"], {"dir": Vector3.DOWN, "spread": 70.0, "vmin": 1.0, "vmax": 3.0, "r": 1.6, "life": 0.8}))
	tw.tween_interval(4.5)
	tw.tween_property(dome, "global_position", at - Vector3.UP * 3.5, 0.5)
	tw.tween_callback(dome.queue_free)
	pj.shake(0.7)
	if c is Player:
		Buffs.add("rock_shelter", 5.0, {"armor": 0.15, "_name": "Kaya Sığınağı", "_desc": "kubbenin içindesin: gelen hasar çok azalır"})
	Sfx.play("earth", at, 0.8)


static func get_tree_scene(pj: PathJutsu) -> Node:
	return pj.get_tree().current_scene


# ================================================================== 12) Doriku Gaeshi: zemin levhasını duvar gibi devirme
## Önündeki zemin dikdörtgen bir levha halinde kesilir, uzak kenarından menteşe gibi kalkıp dik durur (üst örtüsü — çimen / kum —
## sana, katmanlı alt toprağı düşmana döner); kalktığı yerde dikdörtgen çukur kalır, üstünden toprak dökülür. Duvara çarpan
## mermiler çakıl olup dağılır. (Çarpışma kutusu ve süreleri eski duvarla aynı.)
static func _wall_body(pj: PathJutsu, at: Vector3, d: Vector3, w: float, h: float, dur: float) -> Node3D:
	var root = Node3D.new()
	pj.scene_add(root, pj.gp(at))
	root.look_at(root.global_position + d, Vector3.UP)
	var sb = StaticBody3D.new()
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = Vector3(w, h, 1.2)
	cs.shape = sh
	cs.position = Vector3.UP * h * 0.5
	sb.add_child(cs)
	root.add_child(sb)
	root.scale = Vector3(1, 0.02, 1)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(dur)
	tw.tween_property(root, "scale", Vector3(1, 0.02, 1), 0.4)
	tw.tween_callback(root.queue_free)
	_crack_zone(pj.gp(at), w * 0.5, dur)
	return root


static func doriku_gaeshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var d = pj.fwd(c, t)
	var at = c.global_position + d * 1.8
	var root = _wall_body(pj, at, d, 3.6, 3.0, 4.0)
	root.rotation.x = deg_to_rad(-12.0)
	var g = pj.gp(at)
	var pl = DotonLib.pal(g)
	# görsel levha: menteşe (düğüm) duvar tabanında, levha düşman tarafında yatık başlar ve kalkar
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()
	var slab = DotonLib.rock(DotonLib.prism_mesh(DotonLib.jag_rect(3.6, 3.0, 3, 0.12, rng, -3.0), -0.6, 0.6, 0.07, 0.06, rng.randi()), pl["body"], {"top": pl["top"], "top_y": 0.6, "strata": 2.4, "ow": 0.05, "shadow": true})
	slab.rotation.x = PI * 0.5
	var hinge = Node3D.new()
	hinge.add_child(slab)
	DotonLib.put(pj, hinge, g - Vector3.UP * 0.6)
	hinge.basis = Basis.looking_at(d, Vector3.UP)
	hinge.rotation.x = -PI * 0.5
	var tw = hinge.create_tween()
	tw.tween_property(hinge, "rotation:x", deg_to_rad(-12.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hinge, "global_position", g, 0.2)
	tw.tween_interval(4.0)
	tw.tween_property(hinge, "global_position", g - Vector3.UP * 3.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(hinge.queue_free)
	var pit = DotonLib.pit(pj, g + d * 1.5, 1.0, 4.7, 0.15, Vector2(1.9, 1.6))
	pit.rotation.y = atan2(-d.x, -d.z)
	DotonLib.crack(pj, g, 2.4, 4.4, 0.15, 0.0, 6.0)
	DotonLib.grit(pj, g + Vector3.UP * 0.2, 20, pl["body"], {"dir": (Vector3.UP - d * 0.3).normalized(), "spread": 45.0, "vmin": 3.0, "vmax": 7.0})
	pj.after(0.18, func():
		var sd = DotonLib.side_of(d)
		for i in 7:
			var q = g + Vector3.UP * randf_range(2.2, 3.0) + sd * randf_range(-1.6, 1.6)
			var cl = DotonLib.chunk(randf_range(0.1, 0.22), 0, pl["body"], {"ow": 0.025, "top": pl["top"], "top_y": 0.5})
			DotonLib.toss(pj, cl, q, (-d * randf_range(0.5, 1.5) + Vector3.UP * 0.5) * 2.0, 1.0)
		for i in 5:
			DotonLib.dust(pj, g + sd * (i - 2) * 0.8 + Vector3.UP * 0.4, 1.4, 0.9, (-d + Vector3.UP * 0.4) * 1.2, pl["dust"]))
	pj.every(4.3, 0.1, func(_i, _k):
		if not is_instance_valid(root):
			return
		for pr in c.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(pr) and pr.get("shooter") != c and pr.global_position.distance_to(root.global_position + Vector3.UP * 1.5) < 2.4:
				DotonLib.grit(pj, pr.global_position, 8, pl["body"], {"vmin": 2.0, "vmax": 5.0, "spread": 140.0, "life": 0.6})
				DotonLib.dust(pj, pr.global_position, 0.7, 0.5, Vector3.ZERO, pl["dust"])
				pr.queue_free(), Callable())
	Sfx.play("earth", c.global_position, 1.0)


# ================================================================== 13) Gantetsu-hō (Ganteppō): kaya mermisi
## Ağızdan art arda altı küçük, sıkı, koyu taş mermi: her atışta ağızdan dar çakıl konisi ve küçük toz halkası; mermi arkasında
## dönen ince çakıl izi bırakır; çarpınca küçük yıldız çatlak, sivri kıymıklar ve kısa toz.
static func ganteppo(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	var pl = DotonLib.pal(c.global_position)
	var bcol: Color = pl["stone"].darkened(0.15)
	for k in 6:
		pj.after(0.2 + k * 0.08, func():
			if not pj.live(c):
				return
			var from = _mouth(c)
			var b = Node3D.new()
			var core = DotonLib.chunk(0.24, 0, bcol, {"ow": 0.03})
			core.scale = Vector3(0.22, 0.2, 0.26)
			b.add_child(core)
			var aim = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.06, 0.06))
			var pr = pj.shot(c, from, aim, 38.0, b, pj.inf(c, "doton_ganteppo", 0.35, {"knock": 4.0, "kind": "heavy", "element": "doton"}), tt, false, 1.2, func(p, _h):
				DotonLib.crack(pj, p, 1.1, 2.0, 0.08, 0.0, 5.0)
				DotonLib.burst_chunks(pj, p, 5, 0.1, 5.0, bcol, 0.8, 1, 0.8)
				DotonLib.grit(pj, p, 10, bcol, {"vmin": 3.0, "vmax": 6.0, "spread": 160.0, "life": 0.6})
				DotonLib.dust(pj, p, 0.9, 0.55, Vector3.UP * 0.4, pl["dust"]))
			pr.spin = Vector3(8, 12, 0)
			pr.homing_turn = 2.0
			var acc = {"t": 0.0}
			pr.on_tick = func(p2, dt: float) -> void:
				acc["t"] += dt
				if acc["t"] > 0.05 and is_instance_valid(p2):
					acc["t"] = 0.0
					DotonLib.grit(pj, p2.global_position, 3, bcol, {"vmin": 0.5, "vmax": 1.5, "spread": 180.0, "g": 6.0, "life": 0.4, "r": 0.05, "size": 0.035})
			DotonLib.grit(pj, from, 10, bcol, {"dir": aim, "spread": 12.0, "vmin": 8.0, "vmax": 14.0, "g": 8.0, "life": 0.35, "r": 0.05, "size": 0.04})
			DotonLib.dust(pj, from + aim * 0.3, 0.6, 0.35, aim * 2.0, pl["dust"]))
	Sfx.play("earth", c.global_position, 1.3)


# ================================================================== 14) Doro Hoshi: çamur kopyası
## Kopyaların doğduğu yerde çamur sütunları yükselip bedeni örter, sonra çamur aşağı akıp eriyerek kopyayı açığa çıkarır
## (altında çamur gölü); yandaki çamur alanı kabarcıklı göl olur. Kopya ölünce çamura dağılır (çamur topakları + göl).
static func _mud_splat(pj: PathJutsu, p: Vector3, mud: Color) -> void:
	DotonLib.puddle(pj, p, 1.1, 2.5)
	for i in 9:
		var a = TAU * i / 9.0
		DotonLib.toss(pj, DotonLib.mud_blob(randf_range(0.1, 0.2), mud, 0.02), p + Vector3.UP * 0.9, Vector3(cos(a), randf_range(0.6, 1.4), sin(a)).normalized() * randf_range(3.5, 6.0), 1.0, 20.0, 1.0)


static func _mud_rise(pj: PathJutsu, cl: Node3D, mud: Color) -> void:
	var p = pj.gp(cl.global_position)
	DotonLib.puddle(pj, p, 1.0, 2.2)
	var colm = Node3D.new()
	DotonLib.put(pj, colm, p)
	var blobs = []
	for k in 5:
		var b = DotonLib.mud_blob(0.5 - k * 0.04, mud.lightened(k * 0.03), 0.03)
		b.position = Vector3(randf_range(-0.08, 0.08), 0.3 + k * 0.38, randf_range(-0.08, 0.08))
		colm.add_child(b)
		blobs.append(b)
	colm.scale = Vector3(1.0, 0.05, 1.0)
	var tw = colm.create_tween()
	tw.tween_property(colm, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		for b in blobs:
			if is_instance_valid(b):
				var tb = b.create_tween().set_parallel()
				tb.tween_property(b, "position:y", 0.1, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tb.tween_property(b, "scale", b.scale * Vector3(1.4, 0.5, 1.4), 0.7)
				tb.tween_method(DotonLib.pf(b, "melt"), 0.0, 1.0, 0.7))
	tw.tween_interval(0.75)
	tw.tween_callback(colm.queue_free)
	cl.tree_exiting.connect(func():
		if cl.has_method("is_dead") and cl.is_dead():
			var pos = cl.global_position
			pj.after(0.01, func(): _mud_splat(pj, pj.gp(pos), mud)))


static func doro_hoshi(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var p = pj.gp(c.global_position + c.face_dir().rotated(Vector3.UP, 1.2) * 2.0)
	var mud: Color = DotonLib.pal(p)["mud"]
	DotonLib.puddle(pj, p, 2.1, 5.0)
	for i in 6:
		var a = TAU * i / 6.0
		DotonLib.toss(pj, DotonLib.mud_blob(randf_range(0.1, 0.18), mud, 0.02), p + Vector3.UP * 0.3, Vector3(cos(a), 2.0, sin(a)).normalized() * randf_range(3.0, 5.0), 0.9, 20.0, 1.0)
	GroundFX.add(p, "mud", 2.0, 5.0, c)
	_clones(pj, c, "doton_doro_hoshi", func(cl): _mud_rise(pj, cl, mud))
	Sfx.play("earth", c.global_position, 1.1)


# ================================================================== 15) Iwadeppō: kaya tüfeği
## Ref (Narutopedia): ağızdan mermi boyu taş fırlar, uçarken dev kayaya BÜYÜR. Büyürken çevresindeki küçük taşlar ona yapışıp
## kaynaşır (birikerek büyüme); katman şeritli iri kaya olur; çarpınca iki büyük yarıya ayrılır, iri parçalar, kalın toz, çatlak.
static func _boulder(pl: Dictionary) -> Node3D:
	var root = Node3D.new()
	var core = DotonLib.chunk(0.62, 0, pl["stone"].lerp(pl["body"], 0.3), {"ow": 0.045, "strata": 2.4})
	root.add_child(core)
	for i in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var bit = DotonLib.chunk(randf_range(0.18, 0.28), randi() % 3, pl["stone"].darkened(randf_range(0.0, 0.15)), {"ow": 0.035})
		bit.position = dv * 1.1
		root.add_child(bit)
		var tw = bit.create_tween()
		tw.tween_property(bit, "position", dv * 0.5, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return root


static func iwadeppo_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 30.0)
	pj.busy(c, 1.0)
	pj.anim(c, "cast", 1.4)
	var pl = DotonLib.pal(c.global_position)
	for k in 3:
		pj.after(0.22 + k * 0.17, func():
			if not pj.live(c):
				return
			var from = _mouth(c)
			var rk = _boulder(pl)
			rk.scale = Vector3.ONE * 0.1
			var d = pj.aim_at(c, tt, from).rotated(Vector3.UP, randf_range(-0.05, 0.05))
			var pr = pj.shot(c, from, d, 30.0, rk, pj.inf(c, "doton_iwadeppo_no_jutsu", 0.34, {"knock": 6.0, "kind": "heavy", "element": "doton"}), null, false, 1.5, func(p, _h):
				var sc = DotonLib.pal(p)
				for s in [-1.0, 1.0]:
					var half = DotonLib.chunk(0.5, 2, sc["stone"].lerp(sc["body"], 0.3), {"ow": 0.045, "strata": 2.4})
					DotonLib.toss(pj, half, p, (DotonLib.side_of(d) * s * 1.2 + Vector3.UP * 0.9 + d * 0.3) * 4.0, 1.3)
				DotonLib.burst_chunks(pj, p, 9, 0.22, 8.0, sc["stone"], 0.9, -1, 1.1)
				for i in 3:
					DotonLib.dust(pj, p + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.5), randf_range(-0.6, 0.6)), 2.2, 1.1, Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1)), sc["dust"])
				DotonLib.grit(pj, p, 22, sc["stone"], {"vmin": 4.0, "vmax": 9.0, "spread": 160.0})
				var g = DotonLib.floor_at(p)
				if p.y - g.y < 2.5:
					DotonLib.crack(pj, g, 2.6, 3.5, 0.12, 0.0, 7.0))
			if pr:
				pr.radius = 0.25
				pr.spin = Vector3(6, 2, 0)
				var tw = pr.create_tween()
				tw.set_parallel(true)
				tw.tween_property(rk, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(pr, "radius", 0.95, 0.32)
			DotonLib.grit(pj, from, 8, pl["stone"], {"dir": d, "spread": 25.0, "vmin": 4.0, "vmax": 8.0, "life": 0.4})
			Sfx.play("earth", from, 1.5, 0.5))
