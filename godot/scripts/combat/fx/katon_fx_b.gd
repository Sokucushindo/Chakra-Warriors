class_name KatonFXB
extends RefCounted
## Katon grubu B: on beş ateş tekniğinin görselleri — malzeme ve yapı taşları KatonLib'den (kendi alev / güneş / kül shader'ları),
## her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.

const FIRE_L := Color(1.0, 0.6, 0.2)
const BLUE_L := Color(0.4, 0.6, 1.0)

static var _cache := {}


# ================================================================== ortak oynanış izleri (eski patlama / çatlak çağrılarının oyun etkisi)
## Eski ateş patlamasının oyun tarafı: yakın saç/kumaş savrulur, zemine yakınsa yanan zemin bölgesi, sarsıntı, patlama sesi
static func _blast_marks(pos: Vector3, s: float, snd := true) -> void:
	Dangle.blast(pos, 40.0 * s, 6.0 * s)
	var g = KatonLib.floor_at(pos)
	if pos.y - g.y < 3.0 * s:
		GroundFX.add(g + Vector3.UP * 0.12, "burning", 1.2 * s + 0.8, 4.0)
	if Game.world:
		Game.world.env.add_shake(0.7 * s)
	if snd:
		Sfx.play("boom", pos)


## Eski zemin çatlağının oyun tarafı: büyük yarık zemin üstünden geçeni yavaşlatır
static func _crack_zone(pos: Vector3, size: float, dur := 6.0) -> void:
	if size >= 1.5:
		GroundFX.add(pos, "cracked", size * 0.6, clampf(dur, 3.0, 5.0))


## Eski ortak ateş isabetinin oyun tarafı (s ölçeğinde): sarsıntı + patlama izi + zemine yakınsa yarık
static func _impact_marks(pj: PathJutsu, at: Vector3, s: float) -> void:
	var g = KatonLib.floor_at(at)
	pj.shake(0.2 + 0.2 * s)
	_blast_marks(at, 1.1 * s)
	if at.y - g.y < 2.5:
		_crack_zone(g, 3.0 * s, 6.0)


static func _flat(b: MB) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(KatonLib.flat_mat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _rock(s: float, hot := true) -> MeshInstance3D:
	var b = MB.new()
	b.add("boulder", Vector3.ZERO, Vector3.ONE * s, Color(0.2, 0.13, 0.09), Vector3(randf() * 90, randf() * 90, 0), randi_range(1, 8))
	if hot:
		b.add("sphere", Vector3(0, -0.18, 0.1) * s, Vector3(0.5, 0.35, 0.5) * s, Color(1.0, 0.5, 0.12), Vector3.ZERO, 6)
	return _flat(b)


## Yere yatık daire / yay nokta dizisi (yerel, merkez orijin): r yarıçap, a0..a1 açı
static func _arc_pts(r: float, a0: float, a1: float, n: int, y := 0.0) -> PackedVector3Array:
	var pts = PackedVector3Array()
	for i in n:
		var a = lerpf(a0, a1, float(i) / maxf(1.0, n - 1))
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
	return pts


# ================================================================== 1) Enryūheki: ejderin çizdiği alev duvarı
## Anime: kullanıcının önünde alevden ejder ileri geri kıvrılır; geçtiği yerde yükselen alev perdesi kullanıcıyı hilal gibi sarar.
## Gelen mermiler perdeye değince alev ağzında yutulur (ısırılıp söner).
static func katon_enryuheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var center = pj.gp(c.global_position + d * 3.0)
	var head = Node3D.new()
	pj.scene_add(head, center + Vector3.UP * 1.8)   # gövde baştan kopmasın: baş hareketin başladığı yerde doğar
	head.add_child(KatonLib.dragon_head(0.85, KatonLib.PAL_FIRE, 22.0, 2, 5))
	KatonLib.serpent(pj, head, 16, 0.8, 1.15, KatonLib.PAL_FIRE)
	# alev perdesi: ejderin süpürdüğü hat boyunca, uçları kullanıcıya doğru kıvrılan hilal (ref: ateş halkası duvarı)
	var wall = Node3D.new()
	pj.scene_add(wall, center)
	var slots: Array = []
	var n = 15
	for i in n:
		var u = float(i) / (n - 1) * 2.0 - 1.0
		var x = u * 5.6
		var lp = side * x - d * (u * u) * 2.2
		var q = KatonLib.floor_at(center + lp)
		var sl = Node3D.new()
		wall.add_child(sl)
		sl.global_position = q
		var lean_in = -d * 0.15
		for k in 2:
			var tg = KatonLib.tongue_mi(randf_range(3.2, 4.6) * (1.0 - absf(u) * 0.25), randf_range(1.6, 2.1), Vector3.UP + lean_in + side * randf_range(-0.12, 0.12), KatonLib.PAL_FIRE, 6, 0.0, 0.0)
			tg.position = side * randf_range(-0.25, 0.25) + d * (k * 0.35 - 0.2)
			sl.add_child(tg)
		slots.append({"n": sl, "x": x, "on": false})
		KatonLib.scorch(pj, q, 1.3, 6.0)
	KatonLib.light(pj, center + Vector3.UP * 2.0, FIRE_L, 7.0, 16.0, 4.6)
	KatonLib.shimmer(pj, center + Vector3.UP * 3.0, 11.0, 5.0, 4.4)
	# --- oynanış (p_katon_enryuheki'den birebir) + perde yakma
	pj.every(4.0, 1.0 / 30.0, func(_i, k):   # ejder önünde ileri geri kıvrılarak duvar olur
		if is_instance_valid(head):
			var x = sin(k * TAU * 1.5) * 5.0
			var np = center + side * x + Vector3.UP * (1.8 + sin(k * TAU * 3.0) * 0.8)
			var mv = np - head.global_position
			head.global_position = np
			# baş gittiği yöne bakar; gövde onun izinden gelir
			if mv.length() > 0.01:
				head.look_at(np + mv, Vector3.UP)
			# ejderin geçtiği yerde perde tutuşur
			for sd in slots:
				if not sd["on"] and absf(float(sd["x"]) - x) < 1.2:
					sd["on"] = true
					var sl: Node3D = sd["n"]
					for tg in sl.get_children():
						var tw = tg.create_tween()
						tw.tween_method(KatonLib.pf(tg, "heat"), 0.0, 1.15, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					KatonLib.embers(pj, sl.global_position + Vector3.UP * 0.5, 8, 0.6, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 5.0, "life": 0.9})
			if _i % 5 == 0:
				var sd2 = slots[randi() % slots.size()]
				if sd2["on"]:
					var sp: Node3D = sd2["n"]
					KatonLib.tongue(pj, sp.global_position, randf_range(1.4, 2.6), 1.0, 0.6, Vector3.UP - d * 0.2, Vector3.UP * 1.5, KatonLib.PAL_FIRE, 4)
		for e in pj.enemies_near(c, center, 5.5):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("burn", 0.6)
		for pr in c.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(pr) and pr.get("shooter") != c and pr.global_position.distance_to(center + Vector3.UP * 1.8) < 5.0:
				_enryuheki_bite(pj, pr.global_position, d)
				_blast_marks(pr.global_position, 0.5)
				pr.queue_free(), func():
		if is_instance_valid(head):
			head.queue_free()
		# perde aşağıdan sönerek çöker
		if is_instance_valid(wall):
			for sl in wall.get_children():
				for tg in sl.get_children():
					var tw = tg.create_tween()
					tw.tween_method(KatonLib.pf(tg, "heat"), 1.15, 0.0, randf_range(0.5, 0.9)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			KatonLib.kill(pj, 1.0, wall))
	Sfx.play("fire", center, 0.7)


## Yutulan mermi: perdeden dışa doğru kapanan iki alev çenesi (yay şerit) + kısa parlama
static func _enryuheki_bite(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	KatonLib.glow(pj, p, 2.4, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.3)
	KatonLib.mass(pj, p, 0.3, 1.2, 0.35, d * 1.5, KatonLib.PAL_FIRE, 1.4, 2.0)
	var sd = KatonLib.side_of(d)
	for sy in [-1.0, 1.0]:
		var pts = PackedVector3Array()
		for i in 7:
			var a = lerpf(-1.2, 1.2, i / 6.0)
			pts.append(p + sd * sin(a) * 1.1 + Vector3.UP * sy * cos(a) * 0.7 + d * 0.4)
		KatonLib.ribbon(pj, pts, 0.18, 0.35, KatonLib.PAL_FIRE, {"flow": 6.0, "tiles": 2.0})
	KatonLib.embers(pj, p, 10, 0.3, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 6.0, "spread": 160.0, "life": 0.6})


# ================================================================== 2) Enarare: alev dolusu
## Anime: kullanıcı göğe alev püskürtür; alan üstüne çengel uçlu, kuyruklu küçük alev okları eğik yağmur gibi iner,
## değdiği yerde kısa yassı sıçrama + kavruk benek bırakır.
static func katon_enarare(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 26.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	# hazırlık: ağızdan göğe kısa alev püskürmesi
	var mo = pj._mouth_pos(c)
	for q in 5:
		var up = (Vector3.UP * 1.0 + c.face_dir() * 0.35 + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))).normalized()
		KatonLib.tongue(pj, mo + c.face_dir() * 0.3, randf_range(1.4, 2.2), 0.6, 0.35, up, up * 9.0, KatonLib.PAL_FIRE, 3)
	KatonLib.embers(pj, mo, 14, 0.2, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 6.0, "vmax": 12.0, "spread": 18.0, "life": 0.7})
	KatonLib.scorch(pj, at, 4.8, 5.0, 0.0, KatonLib.PAL_FIRE, 1.6)
	var slant = (c.face_dir() * 0.35 + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15)))
	# --- oynanış (p_katon_enarare'den birebir)
	pj.every(1.8, 0.08, func(_i, _k):
		var q = at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		for j in 2:
			var land = KatonLib.floor_at(q + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)))
			_hail_dart(pj, land, slant, j * 0.06)
		for e in pj.enemies_near(c, q, 1.5):
			if pj.live(e):
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "katon_enarare", 0.15, {"knock": 0.5, "kind": "light", "element": "katon", "burn": 1.0})), Callable())
	Sfx.play("fire", at, 1.1)


## Çengel uçlu alev oku: kızgın çekirdek + geriye uzun kuyruk dili + iki yana açılan kanca dilleri; eğik düşer
static func _hail_dart(pj: PathJutsu, land: Vector3, slant: Vector3, dly: float) -> void:
	var dirv = (Vector3.DOWN + slant).normalized()
	var start = land - dirv * 11.0
	var dart = Node3D.new()
	dart.add_child(KatonLib.mass_mi(0.17, KatonLib.PAL_FIRE, 1.5, 2.5))
	dart.add_child(KatonLib.tongue_mi(1.7, 0.42, Vector3(0, 0, 1), KatonLib.PAL_FIRE, 2, 0.12, 1.15))
	for sx in [-1.0, 1.0]:
		var hk = KatonLib.tongue_mi(0.55, 0.22, Vector3(sx * 0.9, 0.2, 0.6), KatonLib.PAL_FIRE, 1, -sx * 0.4, 1.2)
		hk.position = Vector3(0, 0, -0.05)
		dart.add_child(hk)
	KatonLib.put(pj, dart, start)
	KatonLib.look(dart, dirv)
	dart.visible = false
	var tw = dart.create_tween()
	tw.tween_interval(dly)
	tw.tween_callback(dart.show)
	tw.tween_property(dart, "global_position", land + Vector3.UP * 0.1, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var dd = Vector3(dirv.x, 0, dirv.z)
		for k in 3:
			var a = k * TAU / 3.0 + randf()
			var dv = (Vector3(cos(a), 0.35, sin(a)) + dd).normalized()
			KatonLib.tongue(pj, land, randf_range(0.5, 0.8), 0.35, 0.3, dv, dv * 1.5, KatonLib.PAL_FIRE, 2)
		if randf() < 0.5:
			KatonLib.tongue(pj, land, randf_range(0.5, 0.9), 0.4, 0.8, Vector3.UP, Vector3.ZERO, KatonLib.PAL_FIRE, 3, 1.0)
		KatonLib.embers(pj, land + Vector3.UP * 0.1, 3, 0.1, KatonLib.PAL_FIRE, {"vmin": 1.5, "vmax": 3.5, "spread": 70.0, "life": 0.5})
		dart.queue_free())


# ================================================================== 3) Hiuchi Yagura: çakmak taşı kulesi
## Anime: hedefin çevresinde çakmak taşı kıvılcımları yere çakar, oradan gökyüzüne uzanan dik, kalın ateş sütunu fışkırır
## (kule = yagura: dört köşe direğinde yukarı akan alev çizgileri). Sütun içindekini kıstırır; sonunda çöküp yere halka gibi yayılır.
static func katon_hiuchi_yagura(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 22.0)
	if not tt:
		return
	var at = pj.gp(tt.global_position)
	var H = 9.0
	var R = 1.9
	# çakmak taşı: dört köşede beyaz-sarı kıvılcım çakması (kulenin temeli)
	for k in 4:
		var a = k * TAU / 4.0 + PI * 0.25
		var cp = KatonLib.floor_at(at + Vector3(cos(a), 0, sin(a)) * R * 1.15)
		KatonLib.embers(pj, cp + Vector3.UP * 0.1, 12, 0.1, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 4.0, "vmax": 9.0, "spread": 35.0, "life": 0.45, "size": 0.07, "g": Vector3(0, -9, 0)})
		KatonLib.glow(pj, cp + Vector3.UP * 0.2, 1.2, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.25)
	# sütun: dönmeyen, dik; katman katman yukarı yalayan diller + iç çekirdek kütleleri + köşe direkleri
	var tower = Node3D.new()
	pj.scene_add(tower, at)
	tower.rotation.y = randf() * TAU
	var layers = 7
	for ly in layers:
		var h = float(ly) / layers * H
		var rr = R * (1.0 - float(ly) / layers * 0.2)
		var cnt = 6
		for k in cnt:
			var a = k * TAU / cnt + ly * 0.5
			var out = Vector3(cos(a), 0, sin(a))
			var tg = KatonLib.tongue_mi(randf_range(2.4, 3.2), rr * 1.25, Vector3.UP + out * 0.12, KatonLib.PAL_FIRE, 5, 0.0, 1.15)
			tg.position = out * rr * 0.75 + Vector3.UP * h
			tower.add_child(tg)
	for ly in 4:
		var core = KatonLib.mass_mi(R * 0.95, KatonLib.PAL_FIRE, 1.3, 2.6)
		core.scale = Vector3(R * 0.9, H * 0.16, R * 0.9)
		core.position = Vector3.UP * (0.9 + ly * H * 0.22)
		tower.add_child(core)
	for k in 4:
		var a = k * TAU / 4.0 + PI * 0.25
		var cp = Vector3(cos(a), 0, sin(a)) * R * 1.15
		var pts = PackedVector3Array()
		for i in 8:
			var u = i / 7.0
			pts.append(cp * (1.0 - u * 0.25) + Vector3.UP * u * (H + 1.5))
		var post = KatonLib.ribbon_mi(pts, 0.22, KatonLib.PAL_FIRE, {"flow": -3.0, "tiles": 5.0, "rag": 0.3, "heat": 1.3})
		tower.add_child(post)
	tower.scale = Vector3(1, 0.02, 1)
	KatonLib.scorch(pj, at, R * 2.0, 6.0)
	KatonLib.shimmer(pj, at + Vector3.UP * (H + 2.0), 6.0, 4.0, 2.8)
	KatonLib.light(pj, at + Vector3.UP * 3.0, FIRE_L, 6.0, 14.0, 2.8)
	var tw = tower.create_tween()
	tw.tween_property(tower, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_callback(func():
		# çöküş: sütun çöker, alev yere halka gibi yayılır
		_yagura_collapse(pj, at, R, H)
		_blast_marks(at + Vector3.UP * 2.0, 2.4)
		pj.hit(c, at + Vector3.UP, 3.5, pj.inf(c, "katon_hiuchi_yagura", 1.2, {"knock": 10.0, "launch": 6.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
		pj.shake(0.7))
	tw.tween_property(tower, "scale", Vector3(1.3, 0.02, 1.3), 0.25)
	tw.tween_callback(tower.queue_free)
	# --- oynanış (p_katon_hiuchi_yagura'dan birebir)
	if tt.has_method("apply_status"):
		tt.apply_status("stun", 2.6)
	pj.every(2.7, 0.08, func(i, _k):
		if not is_instance_valid(tower):
			return
		# sütun yüzeyinden kopup yükselen diller
		for q in 2:
			var a = randf() * TAU
			var p = at + Vector3(cos(a), 0, sin(a)) * R * 0.9 + Vector3.UP * randf_range(0.5, H * tower.scale.y)
			KatonLib.tongue(pj, p, randf_range(1.2, 2.0), 0.8, 0.45, Vector3(cos(a) * 0.25, 1, sin(a) * 0.25), Vector3.UP * 5.0, KatonLib.PAL_FIRE, 3)
		if i % 3 == 0:
			KatonLib.embers(pj, at + Vector3.UP * 3.0, 4, 1.5, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 5.0, "life": 0.8})
		if i % 6 == 0 and pj.live(tt):
			pj.hit(c, tt.global_position + Vector3.UP, tt.radius + 0.3, pj.inf(c, "katon_hiuchi_yagura", 0.3, {"knock": 0.0, "kind": "light", "element": "katon", "burn": 1.5})), Callable())
	Sfx.play("fire", at, 0.8)


## Çöküş: tepeden aşağı düşen alev kütleleri + tabandan dışa yayılan alçak alev halkası + kor yağmuru
static func _yagura_collapse(pj: PathJutsu, at: Vector3, R: float, H: float) -> void:
	for k in 5:
		var p = at + Vector3(randf_range(-1, 1), H * (0.4 + k * 0.12), randf_range(-1, 1))
		KatonLib.mass(pj, p, 1.2, 2.2, 0.45, Vector3.DOWN * (H * 0.4 + k * 2.0), KatonLib.PAL_FIRE, 1.3, 2.0)
	KatonLib.mass(pj, at + Vector3.UP * 1.2, 1.0, 3.6, 0.6, Vector3.UP * 0.6, KatonLib.PAL_FIRE, 1.4, 1.6)
	var ring = Node3D.new()
	KatonLib.put(pj, ring, at + Vector3.UP * 0.15)
	var rib = KatonLib.ribbon_mi(_arc_pts(1.0, 0.0, TAU, 33), 0.12, KatonLib.PAL_FIRE, {"hint": Vector3.UP, "twin": false, "flow": 5.0, "tiles": 10.0, "rag": 0.5, "heat": 1.4})
	ring.add_child(rib)
	ring.scale = Vector3.ONE * R
	var tw = ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(R * 4.0, 1.0, R * 4.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(rib, "heat"), 1.4, 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
	for k in 14:
		var a = k * TAU / 14.0 + randf() * 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		KatonLib.tongue(pj, KatonLib.floor_at(at + dv * R), randf_range(1.6, 2.6), 1.1, 0.6, (dv * 0.8 + Vector3.UP).normalized(), dv * 7.0, KatonLib.PAL_FIRE, 4)
	KatonLib.embers(pj, at + Vector3.UP * H * 0.5, 40, R, KatonLib.PAL_FIRE, {"dir": Vector3.DOWN, "vmin": 1.0, "vmax": 4.0, "spread": 120.0, "g": Vector3(0, -4, 0), "life": 1.4})
	KatonLib.scorch(pj, at, R * 3.5, 6.0)
	KatonLib.light(pj, at + Vector3.UP * 2.0, FIRE_L, 9.0, 18.0, 0.6)


# ================================================================== 4) Kibaku Enjin: patlayan etiket çemberi
## Anime: koldaki sargıdan yüzlerce patlayıcı etiket savrulur, hedefin çevresine çember çizip yere yapışır; etiketler sırayla cızırdar,
## aralarında kıvılcım fitili koşar, çember boyunca alev bariyeri yükselir — içeri çöker ve dik bir patlama sütunuyla tek seferde patlar.
static func katon_kibaku_enjin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	var tags = []
	var n = 12
	for k in n:
		var a = k * TAU / n + randf_range(-0.15, 0.15)
		var land = pj.gp(at + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 3.4)) + Vector3.UP * 0.03
		var tag = _paper_tag()
		var from = pj.hand_pos(c, true)
		pj.scene_add(tag, from)
		tags.append(tag)
		var mid = from.lerp(land, 0.5) + Vector3.UP * randf_range(1.5, 3.0)
		var spin = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		var tw = tag.create_tween()
		tw.tween_method(func(u: float):
			if is_instance_valid(tag):
				tag.global_position = from.lerp(mid, u).lerp(mid.lerp(land, u), u)
				tag.rotation = spin * (1.0 - u) + Vector3(0, a, 0) * u, 0.0, 1.0, 0.35 + k * 0.02)
	# yapışan etiketler cızırdar; aralarında yerde kıvılcım fitili koşar
	pj.after(0.45, func():
		var ring = Node3D.new()
		KatonLib.put(pj, ring, at + Vector3.UP * 0.06)
		var fuse = KatonLib.ribbon_mi(_arc_pts(2.6, 0.0, TAU, 40), 0.05, KatonLib.PAL_FIRE, {"hint": Vector3.UP, "twin": false, "flow": 10.0, "tiles": 14.0, "rag": 0.2, "heat": 1.5})
		fuse.set_instance_shader_parameter("head", 0.0)
		ring.add_child(fuse)
		var tw = ring.create_tween()
		tw.tween_method(KatonLib.pf(fuse, "head"), 0.0, 1.0, 0.45)
		KatonLib.kill(pj, 0.75, ring)
		pj.every(0.7, 0.08, func(_i, _k):
			for tg_ in tags:
				if is_instance_valid(tg_) and randf() < 0.4:
					KatonLib.embers(pj, tg_.global_position + Vector3.UP * 0.05, 3, 0.05, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 1.0, "vmax": 3.0, "spread": 60.0, "life": 0.25, "size": 0.06})
					KatonLib.tongue(pj, tg_.global_position, randf_range(0.2, 0.35), 0.16, 0.22, Vector3.UP, Vector3.ZERO, KatonLib.PAL_FIRE, 2), Callable()))
	# bariyer: çember boyunca içe eğik yükselen alev perdesi
	pj.after(0.85, func():
		for k in 16:
			var a = k * TAU / 16.0
			var dv = Vector3(cos(a), 0, sin(a))
			var bp = KatonLib.floor_at(at + dv * 3.6)
			var bt = KatonLib.tongue(pj, bp, randf_range(3.5, 4.5), 1.6, 0.42, (Vector3.UP - dv * 0.35).normalized(), -dv * 6.0, KatonLib.PAL_FIRE, 5)
			bt.set_instance_shader_parameter("lean", 0.2)
		KatonLib.glow(pj, at + Vector3.UP * 1.5, 7.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.4))
	pj.after(1.15, func():
		for tg_ in tags:
			if is_instance_valid(tg_):
				tg_.queue_free()
		_kibaku_column(pj, at)
		# --- oynanış (p_katon_kibaku_enjin'den birebir: patlama + kil patlaması + yarık + flaş)
		_blast_marks(at + Vector3.UP * 1.2, 4.2)
		if Game.world:
			Game.world.env.add_shake(0.6 * 4.0)
		_crack_zone(at, 9.0, 6.0)
		if Game.world:
			Game.world.env.screen_flash(0.2)
		pj.shake(1.6)
		for h in pj.hit(c, at + Vector3.UP, 6.5, pj.inf(c, "katon_kibaku_enjin", 2.6, {"knock": 22.0, "launch": 8.0, "kind": "heavy", "element": "katon", "burn": 3.0, "hitstop": 0.12})):
			pj.st(h, "stun", 0.6)
		Sfx.play("boom", at, 0.6))
	Sfx.play("whoosh", c.global_position, 1.2)


## Patlayıcı etiket: beyaz kâğıt, kırmızı mühür yazısı (dikey çizgi + yatay vuruşlar), üstte koyu bağ şeridi
static func _paper_tag() -> MeshInstance3D:
	var b = MB.new()
	b.add("box", Vector3.ZERO, Vector3(0.16, 0.012, 0.42), Color(0.97, 0.95, 0.88))
	var red = Color(0.72, 0.07, 0.05)
	b.add("box", Vector3(0, 0.008, 0.02), Vector3(0.03, 0.004, 0.3), red)
	for i in 4:
		var z = -0.1 + i * 0.07
		b.add("box", Vector3(0.0, 0.009, z), Vector3(0.1 - (i % 2) * 0.03, 0.004, 0.018), red)
	b.add("box", Vector3(0, 0.008, -0.17), Vector3(0.12, 0.004, 0.03), Color(0.2, 0.17, 0.15))
	return _flat(b)


## Dik patlama sütunu: içe çöken parlama → gökyüzüne fırlayan üst üste alev kütleleri, yerde düzleşen alev diski,
## savrulan yanık etiket parçaları, geniş kavruk iz
static func _kibaku_column(pj: PathJutsu, at: Vector3) -> void:
	KatonLib.glow(pj, at + Vector3.UP * 2.0, 12.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.35)
	for k in 6:
		var h = 1.0 + k * 2.1
		KatonLib.mass(pj, at + Vector3.UP * h, 1.0, 3.6 - k * 0.3, 0.75 + k * 0.05, Vector3.UP * (4.0 + k * 1.5), KatonLib.PAL_FIRE, 1.45, 1.5)
	KatonLib.mass(pj, at + Vector3.UP * 13.0, 1.5, 5.0, 1.0, Vector3.UP * 3.0, KatonLib.PAL_FIRE, 1.2, 1.0)
	# yere yassı yayılan alev diski
	var disc = Node3D.new()
	KatonLib.put(pj, disc, at + Vector3.UP * 0.4)
	for r in [0.6, 0.85, 1.0]:
		var rib = KatonLib.ribbon_mi(_arc_pts(r, 0.0, TAU, 36), 0.22, KatonLib.PAL_FIRE, {"hint": Vector3.UP, "twin": false, "flow": 4.0, "tiles": 12.0, "rag": 0.6, "heat": 1.4})
		disc.add_child(rib)
	disc.scale = Vector3(1.5, 1.0, 1.5)
	var tw = disc.create_tween().set_parallel()
	tw.tween_property(disc, "scale", Vector3(8.0, 1.0, 8.0), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for rib in disc.get_children():
		tw.tween_method(KatonLib.pf(rib, "heat"), 1.4, 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(disc.queue_free)
	for k in 18:
		var a = k * TAU / 18.0 + randf() * 0.2
		var dv = Vector3(cos(a), 0, sin(a))
		KatonLib.tongue(pj, KatonLib.floor_at(at + dv * randf_range(1.0, 3.0)), randf_range(2.5, 4.0), 1.3, 0.7, (Vector3.UP * 1.4 + dv).normalized(), dv * 8.0 + Vector3.UP * 3.0, KatonLib.PAL_FIRE, 5)
	# yanık etiket parçaları
	for k in 10:
		var a = randf() * TAU
		var v = Vector3(cos(a) * randf_range(4.0, 9.0), randf_range(6.0, 11.0), sin(a) * randf_range(4.0, 9.0))
		var bit = Node3D.new()
		var b = MB.new()
		b.add("box", Vector3.ZERO, Vector3(0.12, 0.01, 0.16), Color(0.3, 0.24, 0.2))
		b.add("box", Vector3(0, 0.006, 0.07), Vector3(0.12, 0.006, 0.03), Color(1.0, 0.55, 0.15))
		bit.add_child(_flat(b))
		bit.add_child(KatonLib.tongue_mi(0.4, 0.2, Vector3.UP, KatonLib.PAL_FIRE, 2, 0.0, 1.1))
		KatonLib.toss(pj, bit, at + Vector3.UP * 1.5, v, 1.4, 9.0)
	KatonLib.embers(pj, at + Vector3.UP * 3.0, 90, 2.5, KatonLib.PAL_FIRE, {"vmin": 5.0, "vmax": 14.0, "spread": 100.0, "life": 1.8})
	KatonLib.shimmer(pj, at + Vector3.UP * 6.0, 9.0, 12.0, 2.4)
	KatonLib.light(pj, at + Vector3.UP * 4.0, FIRE_L, 14.0, 30.0, 1.1)
	KatonLib.scorch(pj, at, 7.5, 9.0)


# ================================================================== 5) Gōka Messhitsu: ufku kaplayan alev dalgası
## Anime (Madara): ağızdan çıkan alev bir anda yelpaze gibi açılıp ufku kaplayan, ilerledikçe yükselen dev alev duvarına döner;
## önde yuvarlanan kabarık alev cephesi, arkasında yanan halı, kenarında kara kurum bulutları.
static func katon_goka_messhitsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.4)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP)
	var mo = pj._mouth_pos(c)
	# hazırlık: ağızda bir anlık beyaz-sarı şişme
	KatonLib.glow(pj, mo + d * 0.4, 1.8, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.3)
	KatonLib.mass(pj, mo + d * 0.8, 0.2, 0.9, 0.2, d * 4.0, KatonLib.PAL_FIRE, 1.5, 2.5)
	pj.anim(c, "push", 1.3)
	# ağızdan yelpazelenen kalın alev akımları (kaynak)
	for j in 5:
		var dd = (d + side * (j - 2) * 0.32).normalized()
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 9:
			var u = i / 8.0
			pts.append(mo + dd * (0.6 + u * 9.0) + Vector3.DOWN * u * u * 1.0)
			wid.append(0.3 + u * 2.2)
		KatonLib.ribbon(pj, pts, 0.8, 1.2, KatonLib.PAL_FIRE, {"flow": 7.0, "tiles": 3.0, "rag": 0.5, "widths": wid, "heat": 0.6})
	var origin = c.global_position
	var st0 = {"t": 0.0}
	pj.every(1.1, 0.05, func(i, k):
		st0["t"] = k
		var R = lerpf(3.0, 26.0, 1.0 - pow(1.0 - k, 2.0))
		var hgt = lerpf(2.0, 7.5, k)
		# cephe: yay boyunca yükselen, öne yatık geniş diller + yuvarlanan kütleler
		var cnt = int(4 + R * 0.35)
		for q in cnt:
			var a = deg_to_rad(randf_range(-58.0, 58.0))
			var dv = d.rotated(Vector3.UP, a)
			var p = KatonLib.floor_at(origin + dv * R)
			KatonLib.tongue(pj, p, randf_range(0.7, 1.0) * hgt, hgt * 0.55, 0.55, (Vector3.UP + dv * 0.45).normalized(), dv * 8.0, KatonLib.PAL_FIRE, 6, 0.82, 0.15)
		if i % 2 == 0:
			for q in 2:
				var a = deg_to_rad(randf_range(-50.0, 50.0))
				var dv = d.rotated(Vector3.UP, a)
				KatonLib.mass(pj, KatonLib.floor_at(origin + dv * R) + Vector3.UP * hgt * 0.35, hgt * 0.2, hgt * 0.45, 0.6, dv * 10.0 + Vector3.UP * 1.5, KatonLib.PAL_FIRE, 1.1, 1.8)
		# arkada yanan halı: kısa diller
		if R > 6.0:
			for q in 2:
				var a = deg_to_rad(randf_range(-55.0, 55.0))
				var p2 = KatonLib.floor_at(origin + d.rotated(Vector3.UP, a) * randf_range(4.0, R - 2.0))
				KatonLib.tongue(pj, p2, randf_range(1.0, 2.2), 1.2, 1.0, Vector3.UP, Vector3.ZERO, KatonLib.PAL_FIRE, 4, 0.85)
		# kenarda kara kurum
		if i % 4 == 2 and R > 10.0:
			var sa = deg_to_rad(60.0 * (1.0 if randf() < 0.5 else -1.0) * randf_range(0.8, 1.0))
			var sp = KatonLib.floor_at(origin + d.rotated(Vector3.UP, sa) * R) + Vector3.UP * 1.2
			KatonLib.ash_puff(pj, sp, 0.5, 1.4, 1.1, Vector3.UP * 3.0 + d * 2.0, 0.6))
	# zeminde yelpaze kavruk iz
	for k in 7:
		var dist = 6.0 + k * 3.0
		for sgn in [-1.0, 0.0, 1.0]:
			var p = origin + d * dist + side * sgn * dist * 0.75
			KatonLib.scorch(pj, p, 2.5 + dist * 0.18, 7.0, 0.0, KatonLib.PAL_FIRE, 0.6 + k * 0.08)
	KatonLib.shimmer(pj, origin + d * 14.0 + Vector3.UP * 5.0, 30.0, 10.0, 2.2)
	# --- oynanış (p_katon_goka_messhitsu'dan birebir)
	Combat.hit_zone(c, c.global_position, d, 26.0, 60.0, 5.0, pj.inf(c, "katon_goka_messhitsu", 2.2, {"knock": 14.0, "kind": "heavy", "element": "katon", "burn": 4.0}))
	pj.after(0.5, func():
		pj.shake(1.2))
	KatonLib.light(pj, c.global_position + d * 10.0 + Vector3.UP * 2.0, FIRE_L, 10.0, 40.0, 1.4)
	Sfx.play("fire", c.global_position, 0.4)


# ================================================================== 6) Ryūen Hōka: dişli ejder başlı alev mermileri
## Anime: ağızdan beş ateş fırlar; her biri sivri dişli, çekik gözlü, arkası alev yeleli ejder kafası — önce yelpaze gibi göğe
## sıçrar, sonra kıvrılıp hedefin üstüne dalar; çarpınca çeneler kapanır gibi alev ısırığı.
static func katon_ryuen_hoka_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 28.0)
	KatonLib.glow(pj, pj._mouth_pos(c) + c.face_dir() * 0.4, 1.6, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.5)
	for k in 5:
		pj.after(k * 0.12, func():
			if not pj.live(c):
				return
			var head = _fang_head()
			var fd = c.face_dir()
			var sd = fd.cross(Vector3.UP)
			var from = pj._mouth_pos(c) + sd * (k - 2) * 0.4
			KatonLib.mass(pj, from + fd * 0.3, 0.2, 0.8, 0.2, fd * 3.0, KatonLib.PAL_FIRE, 1.4, 2.5)
			var up_dir = (fd * 0.6 + Vector3.UP * 0.9 + sd * (k - 2) * 0.35).normalized()
			var pr = pj.shot(c, from, up_dir, 24.0, head, pj.inf(c, "katon_ryuen_hoka_no_jutsu", 0.6, {"knock": 9.0, "launch": 3.0, "kind": "heavy", "element": "katon", "burn": 2.0}), tt, false, 2.4, func(p, _h):
				_ryuen_bite(pj, p)
				_impact_marks(pj, p, 1.6)
				_blast_marks(p, 1.4, false))
			pr.homing_turn = 0.0
			pr.radius = 1.1
			var age = {"t": 0.0, "n": 0}
			pr.on_tick = func(p2, dt):
				age["t"] += dt
				if age["t"] > 0.4:
					# dalış: hedefe (yoksa önündeki yere) güçlü dönüş, hızlanarak iner
					var goal = (tt.global_position + Vector3.UP) if tt and pj.live(tt) else pj.gp(c.global_position + fd * 18.0)
					p2.vel = p2.vel.lerp((goal - p2.global_position).normalized() * 34.0, minf(1.0, dt * 6.0))
				# baş uçuş yönüne döner, arkasında kopan yele dilleri
				KatonLib.look(head, p2.vel)
				age["n"] += 1
				if age["n"] % 2 == 0:
					var back = -p2.vel.normalized()
					KatonLib.tongue(pj, p2.global_position + back * 1.2, randf_range(1.0, 1.6), 0.7, 0.3, (back + Vector3.UP * 0.3).normalized(), back * 3.0, KatonLib.PAL_FIRE, 4, 1.0))
	Sfx.play("fire", c.global_position, 0.6)


## Dişli ejder başı (-Z ileri): uzun alev kütlesi kafa, yarık ağızda alt-üst sivri diş sıraları, çekik parlak gözler,
## geriye savrulan alev yelesi (ref: ateş topu değil, sırıtan ejder suratı)
static func _fang_head() -> Node3D:
	var root = Node3D.new()
	var piv = Node3D.new()
	root.add_child(piv)
	var sk = KatonLib.mass_mi(1.0, KatonLib.PAL_FIRE, 1.25, 1.8)
	sk.scale = Vector3(0.7, 0.55, 0.8)
	piv.add_child(sk)
	# yüz parçaları kütlenin kabaran yüzeyinin önünde (yoksa alev kütlesi örter)
	var b = MB.new()
	var dark = Color(0.45, 0.1, 0.03)
	var tooth = Color(1.0, 0.93, 0.62)
	b.add("box", Vector3(0, -0.12, -1.02), Vector3(0.9, 0.08, 0.3), dark, Vector3(0, 0, 0))
	for i in 5:
		var x = -0.36 + i * 0.18
		b.add("cone", Vector3(x, -0.02, -1.12 + absf(x) * 0.4), Vector3(0.08, 0.24, 0.08), tooth, Vector3(180, 0, 0), 4)
		b.add("cone", Vector3(x + 0.09, -0.22, -1.1 + absf(x) * 0.4), Vector3(0.07, 0.2, 0.07), tooth, Vector3.ZERO, 4)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.3, 0.25, -1.0), Vector3(0.24, 0.09, 0.08), tooth, Vector3(0, 0, sx * 20.0), 8)
		b.add("sphere", Vector3(sx * 0.32, 0.26, -1.04), Vector3(0.07, 0.07, 0.04), dark, Vector3.ZERO, 6)
	piv.add_child(_flat(b))
	for k in 5:
		var a = lerpf(-0.9, 0.9, k / 4.0)
		var mn = KatonLib.tongue_mi(randf_range(1.8, 2.6), 0.95, Vector3(sin(a) * 0.6, 0.55, 1.0), KatonLib.PAL_FIRE, 4, 0.1, 1.15)
		mn.position = Vector3(sin(a) * 0.4, 0.25, 0.3)
		piv.add_child(mn)
	piv.add_child(KatonLib.tongue_mi(2.6, 1.1, Vector3(0, 0.1, 1.0), KatonLib.PAL_FIRE, 5, 0.0, 1.1))
	piv.scale = Vector3.ONE * 1.1
	return root


## Alev ısırığı: üst ve alt çene yayları birbirine kapanır, arasından kabaran kütle ve yukarı fışkıran diller
static func _ryuen_bite(pj: PathJutsu, p: Vector3) -> void:
	for sy in [-1.0, 1.0]:
		var pts = PackedVector3Array()
		for i in 9:
			var a = lerpf(-1.3, 1.3, i / 8.0)
			pts.append(p + Vector3(sin(a) * 1.8, sy * (0.5 + cos(a) * 1.0), 0.0))
		var rib = KatonLib.ribbon(pj, pts, 0.3, 0.4, KatonLib.PAL_FIRE, {"flow": 5.0, "tiles": 3.0, "rag": 0.5})
		var tw = rib.create_tween()
		tw.tween_property(rib, "position", Vector3(0, -sy * 0.6, 0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	KatonLib.mass(pj, p, 0.4, 2.2, 0.55, Vector3.UP * 1.5, KatonLib.PAL_FIRE, 1.4, 1.8)
	for k in 7:
		var dv = Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)).normalized()
		KatonLib.tongue(pj, p, randf_range(1.6, 2.6), 0.9, 0.5, dv, dv * 4.0, KatonLib.PAL_FIRE, 4)
	KatonLib.embers(pj, p, 20, 0.6, KatonLib.PAL_FIRE, {"vmin": 3.0, "vmax": 8.0, "spread": 140.0})
	KatonLib.light(pj, p, FIRE_L, 6.0, 10.0, 0.45)
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 2.5:
		KatonLib.scorch(pj, g, 2.4, 5.0)


# ================================================================== 7) Gōka Senpū: büyük ateş hortumu
## Anime: rüzgârla beslenen ateş, hedefin üstünde yukarı açılan dev bir huni olur; sarmal alev kolları döner, beyaz rüzgâr
## şeritleri gövdeyi sarar, yerden sökülen taş parçaları hortumda dönerek yükselir; içindekiler çekilir, kaldırılır, yanar.
static func katon_goka_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	var R = 4.2
	var H = 15.0
	var dur = 3.2
	KatonLib.glow(pj, pj._mouth_pos(c) + c.face_dir() * 0.4, 1.4, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.4)
	# dönen huni: sarmal alev kolları + sarmal rüzgâr şeritleri (kök düğüm döner)
	var root = Node3D.new()
	pj.scene_add(root, at)
	var spin = Node3D.new()
	root.add_child(spin)
	for arm in 3:
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 18:
			var u = i / 17.0
			var a = arm * TAU / 3.0 + u * 7.0
			var rr = R * (0.25 + 0.75 * u)
			pts.append(Vector3(cos(a) * rr, u * H, sin(a) * rr))
			wid.append(0.5 + u * 1.6)
		spin.add_child(KatonLib.ribbon_mi(pts, 0.9, KatonLib.PAL_FIRE, {"flow": -4.0, "tiles": 5.0, "rag": 0.55, "widths": wid, "heat": 1.2}))
	for arm in 2:
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 22:
			var u = i / 21.0
			var a = arm * PI + u * 9.0
			var rr = R * (0.35 + 0.85 * u) + 0.4
			pts.append(Vector3(cos(a) * rr, u * H * 0.9 + 0.3, sin(a) * rr))
			wid.append(sin(u * PI) * 0.9 + 0.1)
		var wmi = MeshInstance3D.new()
		wmi.mesh = KatonLib.strip(pts, 0.12, Vector3.ZERO, true, wid)
		wmi.material_override = _wind_mat()
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spin.add_child(wmi)
	var core = KatonLib.mass_mi(1.0, KatonLib.PAL_FIRE, 1.3, 3.0)
	core.scale = Vector3(R * 0.35, H * 0.4, R * 0.35)
	core.position = Vector3.UP * H * 0.4
	spin.add_child(core)
	# dönerek yükselen kaya parçaları
	for k in 10:
		var rk = _rock(randf_range(0.25, 0.55), randf() < 0.5)
		var a0 = randf() * TAU
		var h0 = randf_range(0.0, H * 0.3)
		var r0 = R * randf_range(0.8, 1.2)
		rk.position = Vector3(cos(a0) * r0, h0, sin(a0) * r0)
		spin.add_child(rk)
		var twr = rk.create_tween()
		twr.tween_property(rk, "position", Vector3(cos(a0) * r0 * 1.6, h0 + H * 0.65, sin(a0) * r0 * 1.6), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	root.scale = Vector3(0.2, 0.05, 0.2)
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur - 0.75)
	tw.tween_property(root, "scale", Vector3(1.4, 1.1, 1.4), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		KatonLib.embers(pj, at + Vector3.UP * H * 0.5, 50, R, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 6.0, "spread": 120.0, "life": 1.6})
		for k in 4:
			KatonLib.ash_puff(pj, at + Vector3(randf_range(-2, 2), H * randf_range(0.4, 0.8), randf_range(-2, 2)), 0.6, 1.6, 1.2, Vector3.UP * 3.0, 0.55)
		root.queue_free())
	var spt = Game.safe_loops(spin.create_tween(), int(dur / 0.6) + 2)
	spt.tween_property(spin, "rotation:y", -TAU, 0.6).from(0.0)
	KatonLib.scorch(pj, at, R * 1.5, 7.0, 1.0)
	KatonLib.light(pj, at + Vector3.UP * H * 0.4, FIRE_L, 8.0, R * 6.0, dur)
	KatonLib.shimmer(pj, at + Vector3.UP * (H + 2.0), R * 3.0, 6.0, dur)
	# --- oynanış (p_katon_goka_senpu ve eski hortum yardımcısından birebir: 3.2 sn, R 4.2; çekme + kaldırma + hafif yanık hasarı)
	var st0 = {"t": 0.0}
	pj.every(dur, 0.05, func(_i, _k):
		st0["t"] += 0.05
		var base: Vector3 = at
		# yüzeyden teğet hızla kopup yükselen diller + tabanda dönen toz/kor
		var tm: float = st0["t"]
		var grow = clampf(tm / 0.35, 0.15, 1.0) * clampf((dur - tm) / 0.4, 0.0, 1.0)
		for q in 2:
			var hh = randf()
			var a = randf() * TAU
			var r = R * (0.3 + 0.7 * hh) * grow
			var p = base + Vector3(cos(a) * r, hh * H * grow + 0.3, sin(a) * r)
			var tv = Vector3(-sin(a), 0.5, cos(a))
			KatonLib.tongue(pj, p, (1.5 + hh * 2.5), 1.0 + hh, 0.4, (tv + Vector3.UP).normalized(), tv * 6.0, KatonLib.PAL_FIRE, 4)
		if _i % 3 == 0:
			var a2 = tm * 9.0
			KatonLib.embers(pj, base + Vector3(cos(a2), 0.2, sin(a2)) * R * 0.9, 6, 0.6, KatonLib.PAL_FIRE, {"dir": Vector3(-sin(a2), 0.4, cos(a2)), "vmin": 2.0, "vmax": 5.0, "spread": 30.0, "life": 0.6})
		if _i % 4 == 0:
			for e in pj.enemies_near(c, base, R * 1.1):
				if not (is_instance_valid(e) and not e.is_dead()):
					continue
				var to = base - e.global_position
				to.y = 0
				if "velocity" in e:
					e.velocity += to.normalized() * 3.0 + Vector3.UP * 2.0
				e.take_hit(pj.inf(c, "katon_goka_senpu", 0.22, {"knock": 1.0, "kind": "light", "element": "katon", "burn": 1.0})), Callable())
	_crack_zone(at, 5.0)
	pj.shake(0.9)
	Sfx.play("fire", at, 0.5)
	Sfx.play("wind", at, 0.6)


## Rüzgâr şeridi malzemesi (yalnız bu hortumda): soluk mavi-beyaz, uca doğru incelen, akan kesikli çizgi
static func _wind_mat() -> ShaderMaterial:
	if _cache.has("wind"):
		return _cache["wind"]
	var sh = Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	float u = UV.x;
	float v = abs(UV.y * 2.0 - 1.0);
	float dash = step(0.35, fract(u * 6.0 - TIME * 2.5));
	float a = (1.0 - smoothstep(0.4, 1.0, v)) * dash * smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.85, 1.0, u));
	if (a < 0.05) {
		discard;
	}
	ALBEDO = vec3(0.78, 0.9, 1.0);
	ALPHA = a * 0.85;
}
"""
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["wind"] = m
	return m


# ================================================================== 8) Karura: ateş kuşu
## Kanon adı Garuda kuşu: üflenen alev kanat çırpan dev bir ateş kuşuna dönüşür — gagalı baş, alev tüylü geniş kanatlar,
## uzun kuyruk telekleri; çarpınca kanatlarını açıp patlar, gökten alev tüyleri yağar.
static func katon_karura(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	var tt = pj.tg(c, t, 34.0)
	# hazırlık: ağız önünde kanat açar gibi iki yana kıvrılan diller
	var mo0 = pj._mouth_pos(c)
	KatonLib.spiral_in(pj, mo0 + c.face_dir() * 0.6, KatonLib.PAL_FIRE, 0.4, 8, 1.2)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		pj.anim(c, "push", 1.3)
		var mo = pj._mouth_pos(c)
		var fd = c.face_dir()
		for q in 6:
			KatonLib.tongue(pj, mo + fd * 0.3, randf_range(1.2, 2.0), 0.8, 0.3, (fd + Vector3.UP * 0.2).normalized(), fd * 8.0, KatonLib.PAL_FIRE, 4)
		var bird = Node3D.new()
		var fb = _garuda_bird()
		bird.add_child(fb)
		fb.scale = Vector3.ONE * 0.2
		fb.create_tween().tween_property(fb, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		var pr = pj.shot(c, mo + fd * 1.5, pj.aim_at(c, tt, mo), 19.0, bird, pj.inf(c, "katon_karura", 2.2, {"knock": 16.0, "launch": 6.0, "kind": "heavy", "element": "katon", "burn": 5.0}), tt, false, 2.6, func(p, _h):
			_karura_burst(pj, p)
			# --- oynanış (p_katon_karura'dan birebir: patlama + kil patlaması + yarık + ikinci alan vuruşu)
			_blast_marks(p, 3.6)
			if Game.world:
				Game.world.env.add_shake(0.6 * 3.0)
			Sfx.play("boom", p)
			_crack_zone(pj.gp(p), 9.0)
			pj.hit(c, p, 7.0, pj.inf(c, "katon_karura", 0.9, {"knock": 14.0, "launch": 6.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
			pj.shake(1.4))
		pr.homing_turn = 2.0
		pr.radius = 2.2
		var cnt = {"n": 0}
		pr.on_tick = func(p2, _dt):
			cnt["n"] += 1
			if cnt["n"] % 3 == 0:
				var back = -p2.vel.normalized()
				for sx in [-1.0, 1.0]:
					var wing_tip = p2.global_position + KatonLib.side_of(p2.vel) * sx * 3.2 + back * 0.8
					KatonLib.tongue(pj, wing_tip, randf_range(1.0, 1.6), 0.6, 0.35, (back + Vector3.UP * 0.2).normalized(), back * 3.0, KatonLib.PAL_FIRE, 3, 1.0)
			if cnt["n"] % 6 == 0:
				KatonLib.embers(pj, p2.global_position - p2.vel.normalized() * 2.0, 6, 1.0, KatonLib.PAL_FIRE, {"vmin": 0.5, "vmax": 2.0, "life": 0.8})
		KatonLib.light(pj, mo, FIRE_L, 8.0, 20.0, 1.2))
	Sfx.play("fire", c.global_position, 0.5)


## Ateş kuşu (-Z ileri): gövde kütlesi, gagalı küçük baş, parlak göz, geri savrulan tepelik; kanat kökünden çırpan
## kanat pivotları (her kanat dört geniş tüy dili), arkada üç uzun kuyruk teleği
static func _garuda_bird() -> Node3D:
	var root = Node3D.new()
	var body = KatonLib.mass_mi(1.0, KatonLib.PAL_FIRE, 1.3, 2.0)
	body.scale = Vector3(0.9, 0.8, 1.6)
	root.add_child(body)
	var head = KatonLib.mass_mi(0.55, KatonLib.PAL_FIRE, 1.4, 2.2)
	head.position = Vector3(0, 0.55, -1.55)
	root.add_child(head)
	var b = MB.new()
	b.add("cone", Vector3(0, 0.5, -2.4), Vector3(0.22, 0.6, 0.22), Color(1.0, 0.92, 0.6), Vector3(-90, 0, 0), 5)
	for sx in [-1.0, 1.0]:
		b.add("sphere", Vector3(sx * 0.25, 0.68, -2.12), Vector3(0.16, 0.08, 0.06), Color(1.0, 0.98, 0.85), Vector3(0, 0, sx * 15.0), 6)
		b.add("sphere", Vector3(sx * 0.26, 0.68, -2.16), Vector3(0.05, 0.05, 0.03), Color(0.45, 0.08, 0.03), Vector3.ZERO, 6)
	root.add_child(_flat(b))
	var crest = KatonLib.tongue_mi(1.6, 0.6, Vector3(0, 0.7, 1.0), KatonLib.PAL_FIRE, 3, 0.0, 1.2)
	crest.position = Vector3(0, 0.8, -1.4)
	root.add_child(crest)
	for sx in [-1.0, 1.0]:
		var piv = Node3D.new()
		piv.position = Vector3(sx * 0.6, 0.3, -0.2)
		root.add_child(piv)
		for f in 4:
			var u = f / 3.0
			var fe = KatonLib.tongue_mi(lerpf(2.6, 3.8, u), 1.3, Vector3(sx * 1.0, 0.15, lerpf(-0.1, 0.7, u)), KatonLib.PAL_FIRE, 5, sx * 0.1, 1.15)
			fe.position = Vector3(sx * u * 0.4, 0, lerpf(-0.3, 0.6, u))
			piv.add_child(fe)
		var tw = Game.safe_loops(piv.create_tween())
		tw.tween_property(piv, "rotation:z", deg_to_rad(sx * 35.0), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(piv, "rotation:z", deg_to_rad(-sx * 30.0), 0.22).set_trans(Tween.TRANS_SINE)
	for k in 3:
		var tl = KatonLib.tongue_mi(4.2 - absf(k - 1) * 0.8, 0.9, Vector3((k - 1) * 0.3, 0.1, 1.0), KatonLib.PAL_FIRE, 4, 0.0, 1.1)
		tl.position = Vector3((k - 1) * 0.25, 0.1, 1.3)
		root.add_child(tl)
	root.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 6.0))
	return root


## Kuş patlaması: açılan kanatlar gibi iki yana yayılan dev yelpaze dilleri, yükselen mantar kütlesi,
## gökten süzülerek düşen alev tüyleri, geniş kavruk iz
static func _karura_burst(pj: PathJutsu, p: Vector3) -> void:
	var g = KatonLib.floor_at(p)
	var base = g if p.y - g.y < 3.0 else p
	KatonLib.glow(pj, p, 6.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.3)
	KatonLib.mass(pj, base + Vector3.UP * 1.3, 1.0, 3.0, 0.8, Vector3.UP * 2.0, KatonLib.PAL_FIRE, 1.3, 1.4, 0.8)
	KatonLib.mass(pj, base + Vector3.UP * 3.6, 0.7, 2.2, 0.9, Vector3.UP * 2.5, KatonLib.PAL_FIRE, 1.15, 1.0)
	for sx in [-1.0, 1.0]:
		for k in 6:
			var a = lerpf(0.1, 1.4, k / 5.0)
			var dv = Vector3(sx * cos(a), sin(a), randf_range(-0.3, 0.3)).normalized()
			KatonLib.tongue(pj, base + Vector3.UP * 1.0, randf_range(2.8, 4.0), 1.4, 0.7, dv, dv * 4.0, KatonLib.PAL_FIRE, 6, 1.0)
	for k in 16:
		var a = randf() * TAU
		var v = Vector3(cos(a) * randf_range(3.0, 7.0), randf_range(5.0, 9.0), sin(a) * randf_range(3.0, 7.0))
		var fe = Node3D.new()
		fe.add_child(KatonLib.tongue_mi(0.7, 0.35, Vector3.UP, KatonLib.PAL_FIRE, 2, 0.3, 1.2))
		KatonLib.toss(pj, fe, base + Vector3.UP * 2.0, v, 1.6, 6.0)
	KatonLib.embers(pj, p, 70, 2.0, KatonLib.PAL_FIRE, {"vmin": 4.0, "vmax": 12.0, "spread": 100.0, "life": 1.8})
	KatonLib.shimmer(pj, base + Vector3.UP * 4.0, 10.0, 8.0, 2.2)
	KatonLib.light(pj, base + Vector3.UP * 2.0, FIRE_L, 14.0, 28.0, 1.1)
	if p.y - g.y < 3.0:
		KatonLib.scorch(pj, g, 6.5, 8.0)
		for k in 5:
			KatonLib.burn_patch(pj, g + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 1.4, 3.0, KatonLib.PAL_FIRE, 0.2, 1.2)


# ================================================================== 9) Homura Ryūsei: alev yıldız kayması
## Kullanıcı göğe tek bir alev küresi tükürür; küre bölgenin tepesinde patlayıp yıldız gibi parlar, oradan beyaz-sıcak çekirdekli,
## uzun kuyruklu kayan yıldızlar geniş alana yelpaze gibi iner; her biri yerde yassı alev halkası ve kavruk benek bırakır (kaya yok).
static func katon_homura_ryusei(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 14.0)
	var sky = at + Vector3.UP * 30.0 - pj.fwd(c, t) * 6.0
	# göğe tükürülen küre
	var orb = Node3D.new()
	orb.add_child(KatonLib.mass_mi(0.7, KatonLib.PAL_FIRE, 1.4, 2.0))
	orb.add_child(KatonLib.tongue_mi(2.0, 0.8, Vector3.DOWN, KatonLib.PAL_FIRE, 3, 0.0, 1.1))
	KatonLib.put(pj, orb, pj._mouth_pos(c))
	var tw0 = orb.create_tween()
	tw0.tween_property(orb, "global_position", sky, 0.33).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw0.tween_callback(func():
		KatonLib.glow(pj, sky, 9.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 1.6)
		KatonLib.mass(pj, sky, 0.6, 2.6, 0.5, Vector3.ZERO, KatonLib.PAL_FIRE, 1.5, 2.0)
		for k in 8:
			var dv = Vector3(cos(k * TAU / 8.0), randf_range(-0.3, 0.3), sin(k * TAU / 8.0)).normalized()
			KatonLib.tongue(pj, sky, randf_range(2.0, 3.0), 0.5, 0.4, dv, dv * 6.0, KatonLib.PAL_FIRE, 1)
		KatonLib.light(pj, sky, FIRE_L, 10.0, 40.0, 1.6)
		orb.queue_free())
	# --- oynanış (p_katon_homura_ryusei'den birebir: 12 düşüş, 12 m yarıçap, 0.5 sn iniş)
	for k in 12:
		pj.after(0.35 + k * 0.11 + randf() * 0.06, func():
			var ang = randf() * TAU
			var q = pj.gp(at + Vector3(cos(ang), 0, sin(ang)) * sqrt(randf()) * 12.0)
			var m = _shooting_star()
			var start = sky + Vector3(randf_range(-2.5, 2.5), randf_range(-1.0, 1.0), randf_range(-2.5, 2.5))
			pj.scene_add(m, start)
			KatonLib.look(m, q - start)
			var tw = m.create_tween()
			tw.tween_property(m, "global_position", q + Vector3.UP * 0.5, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func():
				_star_splash(pj, q)
				_blast_marks(q + Vector3.UP * 0.6, 2.2)
				_crack_zone(q, 4.0)
				pj.hit(c, q + Vector3.UP, 4.2, pj.inf(c, "katon_homura_ryusei", 0.55, {"knock": 10.0, "launch": 4.0, "kind": "heavy", "element": "katon", "burn": 2.0}))
				pj.shake(0.35)
				m.queue_free()))
	Sfx.play("fire", c.global_position, 0.6)


## Kayan yıldız (-Z ileri): beyaz-sıcak küçük çekirdek, hale, arkaya çok uzun incelen alev kuyruğu
static func _shooting_star() -> Node3D:
	var root = Node3D.new()
	root.add_child(KatonLib.mass_mi(0.5, KatonLib.PAL_FIRE, 1.7, 3.0))
	root.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 3.2))
	var tail = KatonLib.tongue_mi(9.0, 1.3, Vector3(0, 0, 1), KatonLib.PAL_FIRE, 3, 0.0, 1.3)
	tail.position = Vector3(0, 0, 0.2)
	root.add_child(tail)
	var tail2 = KatonLib.tongue_mi(5.0, 0.7, Vector3(0, 0.05, 1), KatonLib.PAL_FIRE, 2, 0.1, 1.5)
	root.add_child(tail2)
	return root


## Yıldız düşüşü: yere yassı yayılan alev halkası + kısa dik alev sivrisi + kor + kavruk benek
static func _star_splash(pj: PathJutsu, q: Vector3) -> void:
	var ring = Node3D.new()
	KatonLib.put(pj, ring, q + Vector3.UP * 0.2)
	var rib = KatonLib.ribbon_mi(_arc_pts(1.0, 0.0, TAU, 28), 0.16, KatonLib.PAL_FIRE, {"hint": Vector3.UP, "twin": false, "flow": 6.0, "tiles": 9.0, "rag": 0.6, "heat": 1.4})
	ring.add_child(rib)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	var tw = ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(3.8, 1.0, 3.8), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(KatonLib.pf(rib, "heat"), 1.4, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
	KatonLib.glow(pj, q + Vector3.UP * 0.5, 4.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.25)
	for k in 4:
		var dv = Vector3(randf_range(-0.2, 0.2), 1, randf_range(-0.2, 0.2)).normalized()
		KatonLib.tongue(pj, q, randf_range(2.6, 3.8), 1.0, 0.45, dv, Vector3.UP * 3.0, KatonLib.PAL_FIRE, 3, 1.3)
	KatonLib.mass(pj, q + Vector3.UP * 0.5, 0.4, 1.6, 0.4, Vector3.UP * 1.0, KatonLib.PAL_FIRE, 1.4, 2.0)
	KatonLib.embers(pj, q + Vector3.UP * 0.4, 18, 0.5, KatonLib.PAL_FIRE, {"vmin": 3.0, "vmax": 8.0, "spread": 80.0, "life": 0.9})
	KatonLib.scorch(pj, q, 2.6, 6.0)
	KatonLib.light(pj, q + Vector3.UP, FIRE_L, 5.0, 10.0, 0.4)


# ================================================================== 10) Sanmai no Shinka: üç ateş halkası
## Samādhi gerçek ateşi: ayaktan başlayan tutuşma bedene tırmanır; bel, göğüs ve baş hizasında üç ateş halkası zıt yönlerde döner,
## ellerde ve omuzlarda sürekli yalayan diller, başın üstünde beyaz-altın tepe alevi; 12 sn sonra aşağıdan söner.
static func sanmai_no_shinka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var dur = 12.0
	var h = Node3D.new()
	c.add_child(h)
	h.position = Vector3.UP * 0.2
	var parts: Array = []
	var heights = [0.15, 0.85, 1.55]
	for ri in 3:
		var ring = Node3D.new()
		ring.position = Vector3.UP * float(heights[ri])
		h.add_child(ring)
		var cnt = 7 - ri
		for k in cnt:
			var a = k * TAU / cnt
			var out = Vector3(cos(a), 0, sin(a))
			var tg = KatonLib.tongue_mi(0.9 - ri * 0.15, 0.45, (Vector3.UP + out * 0.35).normalized(), KatonLib.PAL_FIRE, 3, 0.0, 0.0)
			tg.position = out * (0.55 - ri * 0.07)
			ring.add_child(tg)
			parts.append(tg)
		var spn = Game.safe_loops(ring.create_tween(), int(dur / 1.2) + 1)
		var sgn = 1.0 if ri % 2 == 0 else -1.0
		spn.tween_property(ring, "rotation:y", sgn * TAU, 1.2 + ri * 0.3).from(0.0)
		# tutuşma aşağıdan yukarı tırmanır
		for tg in ring.get_children():
			var tw = tg.create_tween()
			tw.tween_interval(ri * 0.18)
			tw.tween_method(KatonLib.pf(tg, "heat"), 0.0, 1.2, 0.25)
	var crown = KatonLib.tongue_mi(1.1, 0.55, Vector3.UP, KatonLib.PAL_FIRE, 3, 0.0, 0.0)
	crown.position = Vector3.UP * 1.75
	crown.set_instance_shader_parameter("pal", KatonLib.PAL_FIRE)
	h.add_child(crown)
	parts.append(crown)
	var tc = crown.create_tween()
	tc.tween_interval(0.55)
	tc.tween_method(KatonLib.pf(crown, "heat"), 0.0, 1.5, 0.3)
	for bn in ["RightHand", "LeftHand"]:
		var ba = pj.bone_attach(c, bn)
		if ba:
			var hf = KatonLib.tongue_mi(0.6, 0.32, Vector3.UP, KatonLib.PAL_FIRE, 3, 0.0, 1.25)
			ba.add_child(hf)
			KatonLib.kill(pj, dur + 0.4, ba)
	KatonLib.embers(pj, c.global_position + Vector3.UP * 0.1, 24, 0.6, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 2.0, "vmax": 5.0, "spread": 30.0, "life": 1.0})
	KatonLib.glow(pj, c.global_position + Vector3.UP, 3.5, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.6)
	var lt = OmniLight3D.new()
	lt.light_color = FIRE_L
	lt.light_energy = 2.5
	lt.omni_range = 5.0
	lt.shadow_enabled = false
	lt.position = Vector3.UP
	h.add_child(lt)
	# her saniye ayaktan kopan küçük kor zerresi (yanan beden hissi)
	pj.every(dur, 0.6, func(_i, _k):
		if is_instance_valid(h) and pj.live(c):
			KatonLib.embers(pj, c.global_position + Vector3.UP * 1.0, 3, 0.4, KatonLib.PAL_FIRE, {"vmin": 1.0, "vmax": 2.5, "life": 0.8}), Callable())
	# sönüş: aşağıdan yukarı
	var w = weakref(h)
	pj.get_tree().create_timer(dur - 0.4).timeout.connect(func():
		var x = w.get_ref()
		if x == null or not is_instance_valid(x):
			return
		for tg in parts:
			if is_instance_valid(tg):
				var tw = tg.create_tween()
				tw.tween_method(KatonLib.pf(tg, "heat"), 1.2, 0.0, 0.5))
	KatonLib.kill(pj, dur + 0.4, h)
	# --- oynanış (p_sanmai_no_shinka'dan birebir)
	if c is Player:
		Buffs.add("sanmai_no_shinka", 12.0, {"melee": 1.2, "katon": 1.3})
	KatonLib.light(pj, c.global_position + Vector3.UP, Color(1.0, 0.55, 0.15), 6.0, 8.0, 0.5)
	Sfx.play("fire", c.global_position, 0.8)


# ================================================================== 11) Enshin Bakuha: alev çekirdeği patlaması
## Hedefin altında toprak kızarır: kızgın damarlar merkeze akar, küçük taşlar zıplar, ısı dalgası titrer; ardından yerden dik bir
## alev gayzeri fışkırır, kızgın kaya parçaları savrulur, çevrede yanan zemin kalır.
static func katon_enshin_bakuha(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0)
	# hazırlık: merkeze akan kızgın damarlar + kızaran leke + titreşim
	KatonLib.scorch(pj, at, 3.2, 7.0, 0.0, KatonLib.PAL_FIRE, 0.6)
	for k in 7:
		var a = k * TAU / 7.0 + randf() * 0.3
		var pts = PackedVector3Array()
		for i in 6:
			var u = i / 5.0
			var jit = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)) * (1.0 - u)
			pts.append(KatonLib.floor_at(at + Vector3(cos(a), 0, sin(a)) * lerpf(5.0, 0.3, u) + jit) + Vector3.UP * 0.08)
		KatonLib.ribbon(pj, pts, 0.09, 0.9, KatonLib.PAL_FIRE, {"hint": Vector3.UP, "twin": false, "flow": -6.0, "tiles": 3.0, "rag": 0.15, "heat": 1.5})
	KatonLib.shimmer(pj, at + Vector3.UP * 1.0, 5.0, 2.2, 0.8)
	KatonLib.glow(pj, at + Vector3.UP * 0.2, 3.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 0.75)
	# --- oynanış (p_katon_enshin_bakuha'dan birebir)
	pj.every(0.7, 0.07, func(_i, _k):
		var sp = at + Vector3(randf_range(-2, 2), 0.1, randf_range(-2, 2))
		KatonLib.embers(pj, sp, 3, 0.2, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 1.0, "vmax": 3.0, "spread": 25.0, "life": 0.4})
		if _i % 2 == 0:
			KatonLib.toss(pj, _rock(randf_range(0.12, 0.22), false), sp, Vector3(randf_range(-0.6, 0.6), randf_range(2.0, 3.5), randf_range(-0.6, 0.6)), 0.5), func():
		_geyser(pj, at)
		_blast_marks(at + Vector3.UP * 0.5, 2.2)
		_crack_zone(at, 6.0)
		GroundFX.add(at, "burning", 5.0, 5.0, c)
		pj.hit(c, at + Vector3.UP, 5.0, pj.inf(c, "katon_enshin_bakuha", 2.0, {"knock": 8.0, "launch": 10.0, "kind": "heavy", "element": "katon", "burn": 3.0}))
		pj.shake(1.2))
	Sfx.play("fire", at, 0.6)


## Gayzer: dar tabandan yukarı fışkıran uzun dil demeti, tepede açılan kütle, savrulan kızgın kayalar, yanan zemin
static func _geyser(pj: PathJutsu, at: Vector3) -> void:
	KatonLib.glow(pj, at + Vector3.UP * 1.0, 6.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.3)
	for k in 10:
		var dv = Vector3(randf_range(-0.18, 0.18), 1, randf_range(-0.18, 0.18)).normalized()
		KatonLib.tongue(pj, at + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), randf_range(7.0, 10.0), 2.0, 0.75, dv, dv * 3.0, KatonLib.PAL_FIRE, 5, 1.35)
	for k in 3:
		KatonLib.mass(pj, at + Vector3.UP * (1.0 + k * 2.5), 0.8, 2.0 + k * 0.5, 0.55 + k * 0.1, Vector3.UP * (8.0 + k * 3.0), KatonLib.PAL_FIRE, 1.4, 2.0)
	for k in 14:
		var a = randf() * TAU
		var v = Vector3(cos(a) * randf_range(2.0, 6.0), randf_range(8.0, 14.0), sin(a) * randf_range(2.0, 6.0))
		KatonLib.toss(pj, _rock(randf_range(0.3, 0.6)), at + Vector3.UP * 0.5, v, 1.8, 16.0)
	for k in 10:
		var a = k * TAU / 10.0
		var dv = Vector3(cos(a), 0, sin(a))
		KatonLib.tongue(pj, KatonLib.floor_at(at + dv * 2.0), randf_range(1.5, 2.4), 1.0, 0.55, (dv * 0.6 + Vector3.UP).normalized(), dv * 5.0, KatonLib.PAL_FIRE, 4)
	KatonLib.embers(pj, at + Vector3.UP * 2.0, 50, 1.0, KatonLib.PAL_FIRE, {"dir": Vector3.UP, "vmin": 6.0, "vmax": 14.0, "spread": 35.0, "life": 1.5})
	KatonLib.burn_patch(pj, at, 4.5, 5.0, KatonLib.PAL_FIRE, 0.14, 1.6)
	KatonLib.light(pj, at + Vector3.UP * 3.0, FIRE_L, 12.0, 22.0, 0.8)


# ================================================================== 12) Gōkakyū: büyük ateş topu
## Anime imzası: derin nefes, ağızdan topa akan kalın alev nefesi; ağzın önünde güneş gibi benekli dev ateş topu şişer
## (koyu kızıl konveksiyon lekeleri, sarı-beyaz parlak kenar, kenardan yalayan diller), yerde yuvarlanarak ilerler, altında kavruk
## iz bırakır; çarpınca kabaran alev kütlesi, kara kurum, savrulan toprak parçaları.
static func katon_goukakyuu(js, c: Node3D, t: Node3D) -> void:
	var m = js._mult(c) * js._elem_bonus(c, "katon")
	var dir = js._aim(c, t)
	var start = js._mouth(c) + dir * 0.9
	# hazırlık: ağız önünde ısı dalgası + savrulan kor
	KatonLib.embers(js, start, 18, 0.4, KatonLib.PAL_FIRE, {"dir": dir, "vmin": 3.0, "vmax": 9.0, "spread": 40.0, "life": 0.7})
	KatonLib.shimmer(js, start + dir * 1.0, 2.2, 2.2, 1.0)
	Sfx.play("fire", start, 0.8, 1.4)
	# --- oynanış (Jutsu.j_katon_goukakyuu'dan birebir)
	var pr = Projectile.new()
	pr.shooter = c
	pr.vel = dir * 5.0
	pr.radius = 1.7
	pr.life = 3.6
	pr.info = {"dmg": 26.0 * m, "element": "katon", "knock": 14.0, "launch": 6.0, "kind": "heavy", "hitstop": 0.09, "burn": 3.0}
	var g: float = pr.epic
	# görsel: nefesle şişen benekli dev top (yarıçap ≈ zemin üstü yüksekliği: yerde yuvarlanır)
	var R = 1.6 * g
	var ball = Node3D.new()
	var roller = Node3D.new()
	ball.add_child(roller)
	roller.add_child(KatonLib.sun_mi(R, KatonLib.PAL_FIRE, 1.15, 1.2))
	var inner = KatonLib.mass_mi(R * 0.82, KatonLib.PAL_FIRE, 1.0, 1.6)
	roller.add_child(inner)
	# kenardan yalayan diller (kameraya göre her yönden taç)
	for k in 14:
		var a = k * TAU / 14.0
		var dv = Vector3(cos(a), sin(a), randf_range(-0.4, 0.4)).normalized()
		var tg = KatonLib.tongue_mi(R * randf_range(0.7, 1.0), R * 0.55, dv + Vector3.UP * 0.3, KatonLib.PAL_FIRE, 4, 0.0, 1.15)
		tg.position = dv * R * 0.8
		ball.add_child(tg)
	ball.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 2), R * 2.0))
	ball.scale = Vector3.ONE * 0.12
	pr.add_child(ball)
	var gt = ball.create_tween()
	gt.tween_property(ball, "scale", Vector3.ONE, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var light = OmniLight3D.new()
	light.light_color = FIRE_L
	light.light_energy = 3.0
	light.omni_range = 18.0 * g
	pr.add_child(light)
	# sürekli nefes akışı (~1 sn): ağızdan topa uzanan, topa doğru genişleyen alev dili şeridi
	var breath = KatonLib.ribbon_mi(PackedVector3Array([start, start + dir]), 0.5, KatonLib.PAL_FIRE, {"flow": 8.0, "tiles": 3.0, "rag": 0.45, "heat": 1.3})
	KatonLib.put(js, breath, Vector3.ZERO)
	js._ticks(10, 0.1, func(k):
		if not is_instance_valid(breath):
			return
		if k >= 9 or not is_instance_valid(c) or not is_instance_valid(pr):
			var tw = breath.create_tween()
			tw.tween_method(KatonLib.pf(breath, "heat"), 1.3, 0.0, 0.25)
			tw.tween_callback(breath.queue_free)
			return
		var mo = js._mouth(c) + dir * 0.6
		var to_ball = pr.global_position - mo
		var pts = PackedVector3Array()
		var wid = PackedFloat32Array()
		for i in 8:
			var u = i / 7.0
			pts.append(mo + to_ball * u + Vector3.UP * sin(u * PI) * 0.2)
			wid.append(0.35 + u * u * R * 1.1)
		breath.mesh = KatonLib.strip(pts, 1.0, Vector3.ZERO, true, wid)
		KatonLib.tongue(js, mo + dir * 0.3, randf_range(0.8, 1.4) + k * 0.1, 0.5, 0.25, (to_ball.normalized() + Vector3.UP * 0.2).normalized(), to_ball.normalized() * 6.0, KatonLib.PAL_FIRE, 3))
	var st = {"age": 0.0, "scar": 0.0, "n": 0}
	pr.on_tick = func(p: Projectile, dt: float) -> void:
		st["age"] += dt
		if st["age"] < 0.75:
			p.vel = dir * 5.0
		else:
			p.vel = p.vel.move_toward(dir * 24.0, dt * 40.0)
		# top yerin üstünde yuvarlansın (merkez görsel yarıçapın yarısı kadar yukarıda)
		var gy = Game.jutsu_floor(p.global_position.x, p.global_position.z)
		p.global_position.y = lerpf(p.global_position.y, gy + 1.6 * g, minf(1.0, dt * 3.0))
		# yuvarlanma: hıza göre ileri döner
		if is_instance_valid(roller):
			var sd = KatonLib.side_of(p.vel)
			roller.global_rotate(sd, -p.vel.length() * dt / maxf(R, 0.5))
		st["scar"] -= dt
		if st["scar"] <= 0.0 and st["age"] > 0.3:
			st["scar"] = 0.12
			var gp0 = Vector3(p.global_position.x, gy, p.global_position.z)
			_crack_zone(gp0, 2.6 * g, 6.0)
			st["n"] = int(st["n"]) + 1
			if int(st["n"]) % 3 == 0:
				KatonLib.scorch(js, gp0, 1.6 * g, 6.0, 0.0, KatonLib.PAL_FIRE, 0.2)
			var bk = -p.vel.normalized() if p.vel.length() > 0.1 else -dir
			KatonLib.tongue(js, gp0 + bk * R * 0.6, randf_range(1.2, 2.2) * g * 0.6, 1.2 * g * 0.5, 0.6, (Vector3.UP + bk * 0.4).normalized(), Vector3.UP, KatonLib.PAL_FIRE, 4)
	pr.on_hit = func(pos: Vector3, _tg: Node3D) -> void:
		var ge = pr.epic
		_goukakyuu_impact(js, pos, ge)
		_blast_marks(pos, 1.3 * ge)
		var gp = Vector3(pos.x, Game.jutsu_floor(pos.x, pos.z), pos.z)
		_crack_zone(gp, 3.0 * ge * ge)
		if Game.world:
			Game.world.env.add_shake(1.2)
			Game.world.env.screen_flash(0.15)
		Combat.hit_sphere(c, pos, 4.0, {"dmg": 14.0 * m, "element": "katon", "knock": 16.0, "launch": 7.0, "kind": "heavy", "burn": 3.0}, pr.hit_list)
	js.get_tree().current_scene.add_child(pr)
	pr.global_position = start + dir * 2.0


## Top çarpması: her yöne kabaran dev alev kütlesi, yükselen ikinci kütle, ardından kara kurum; toprak parçaları savrulur
static func _goukakyuu_impact(host: Node, pos: Vector3, ge: float) -> void:
	var g = KatonLib.floor_at(pos)
	KatonLib.glow(host, pos, 8.0 * ge, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.3)
	KatonLib.mass(host, pos, 1.6 * ge, 4.2 * ge, 0.8, Vector3.UP * 1.5, KatonLib.PAL_FIRE, 1.45, 1.3)
	for k in 6:
		var a = k * TAU / 6.0 + randf() * 0.3
		var dv = Vector3(cos(a), randf_range(0.1, 0.6), sin(a)).normalized()
		KatonLib.mass(host, pos + dv * 1.2 * ge, 0.6 * ge, 2.0 * ge, 0.6, dv * 6.0 * ge, KatonLib.PAL_FIRE, 1.3, 1.8)
	for k in 14:
		var dv = Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		KatonLib.tongue(host, pos, randf_range(2.0, 3.4) * ge, 1.2 * ge, 0.6, dv, dv * 5.0 * ge, KatonLib.PAL_FIRE, 5)
	var w = weakref(host)
	host.get_tree().create_timer(0.25).timeout.connect(func():
		var h = w.get_ref()
		if h == null:
			return
		for k in 4:
			KatonLib.ash_puff(h, pos + Vector3(randf_range(-1.2, 1.2) * ge, 2.0 + k * 0.7, randf_range(-1.2, 1.2) * ge), 0.35, 1.0, 0.9, Vector3.UP * 4.0, 0.6, 0.2))
	for k in 16:
		var a = randf() * TAU
		var v = Vector3(cos(a) * randf_range(3.0, 7.0), randf_range(5.0, 10.0), sin(a) * randf_range(3.0, 7.0)) * sqrt(ge)
		KatonLib.toss(host, _rock(randf_range(0.15, 0.35), randf() < 0.3), g + Vector3.UP * 0.4, v, 1.4)
	KatonLib.embers(host, pos, 60, 1.5 * ge, KatonLib.PAL_FIRE, {"vmin": 4.0, "vmax": 12.0, "spread": 120.0, "life": 1.6})
	KatonLib.shimmer(host, pos + Vector3.UP * 3.0 * ge, 6.0 * ge, 6.0 * ge, 2.0)
	KatonLib.light(host, pos, FIRE_L, 12.0, 24.0 * ge, 0.6)
	if pos.y - g.y < 3.0 * ge:
		KatonLib.scorch(host, g, 3.6 * ge, 8.0)


# ================================================================== 13) Haisekishō: yanan kül bulutu
## Anime (Sarutobi): ağızdan gri, topak topak kül bulutu üflenir; içindekiler görüşünü kaybeder, kül içinde gizli kor benekleri
## parıldar. Kullanıcı dişlerini çakınca kıvılcım bir alev fitili gibi bulutun içinden koşar — her topak sırayla tutuşup patlar.
static func sarutobi_haisekisho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var origin = Jutsu._mouth(c)
	var pts = []
	for k in 6:
		pts.append(origin + d * (2.5 + k * 1.8) + Vector3(randf_range(-1, 1), randf_range(-0.3, 0.6), randf_range(-1, 1)))
	# kül seli: ağızdan ileri koşan, yol boyunca kabaran topaklar
	var clouds: Array = []
	for k in 6:
		var cl: Array = []
		clouds.append(cl)
		pj.after(k * 0.08, func():
			if not pj.live(c):
				return
			var q: Vector3 = pts[k]
			var mo = pj._mouth_pos(c)
			for j in 4:
				var off = Vector3(randf_range(-1, 1), randf_range(-0.5, 0.8), randf_range(-1, 1)) * (0.8 + k * 0.2)
				var p0 = mo + d * 0.6
				var mi = KatonLib.ash_mi(0.2, 0.0, 0.5)
				KatonLib.put(pj, mi, p0)
				mi.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
				var tw = mi.create_tween().set_parallel()
				tw.tween_property(mi, "global_position", q + off, 0.35 + k * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(mi, "scale", Vector3.ONE * randf_range(1.0, 1.5) * (0.9 + k * 0.12), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.chain().tween_property(mi, "global_position", q + off + d * 0.5 + Vector3.UP * 0.3, 1.0)
				cl.append(mi)
				KatonLib.kill(pj, 3.2, mi))
	# --- oynanış (p_sarutobi_haisekisho → c_sarutobi_haisekisho'dan birebir)
	for e in pj.enemies_near(c, origin + d * 6.0, 7.0):
		if e.has_method("lose_target"):
			e.lose_target(1.6)
	Sfx.play("wind", origin, 0.6)
	pj.after(1.5, func():
		Sfx.play("clink", c.global_position, 1.6)   # dişler çakar: kıvılcım
		# dişlerde çakan kıvılcım + bulutun içinden koşan fitil
		var mo = pj._mouth_pos(c) if pj.live(c) else origin
		KatonLib.glow(pj, mo + d * 0.3, 1.0, KatonLib.pal_col(KatonLib.PAL_FIRE, 0), 0.15)
		KatonLib.embers(pj, mo + d * 0.3, 10, 0.05, KatonLib.PAL_FIRE, {"dir": d, "vmin": 4.0, "vmax": 9.0, "spread": 30.0, "life": 0.3, "size": 0.06})
		var fp = PackedVector3Array([mo + d * 0.4])
		for p in pts:
			fp.append(p)
		KatonLib.ribbon(pj, fp, 0.1, 0.5, KatonLib.PAL_FIRE, {"flow": 10.0, "tiles": 6.0, "rag": 0.4, "heat": 1.5})
		for i in pts.size():
			var p = pts[i]
			pj.after(i * 0.06, func():
				_ash_ignite(pj, p, clouds[i])
				_blast_marks(p, 1.1)
				pj.hit(c, p, 2.6, pj.inf(c, "sarutobi_haisekisho", 0.45, {"knock": 9.0, "launch": 3.0, "kind": "heavy"})))
		pj.shake(0.8))


## Kül topağı tutuşması: topak gürültü eşiğiyle ateşe döner ve şişer, içinden alev kütlesi patlar, diller ve kor saçılır
static func _ash_ignite(pj: PathJutsu, p: Vector3, cl: Array) -> void:
	for mi in cl:
		if is_instance_valid(mi):
			var tw = mi.create_tween().set_parallel()
			tw.tween_method(KatonLib.pf(mi, "ignite"), 0.0, 1.0, 0.18)
			tw.tween_property(mi, "scale", mi.scale * 1.5, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.chain().tween_method(KatonLib.pf(mi, "fade"), 1.0, 0.0, 0.3)
			tw.chain().tween_callback(mi.queue_free)
	KatonLib.mass(pj, p, 0.5, 2.3, 0.5, Vector3.UP * 1.2, KatonLib.PAL_FIRE, 1.45, 2.0)
	for k in 6:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.2, 1.0), randf_range(-1, 1)).normalized()
		KatonLib.tongue(pj, p, randf_range(1.4, 2.2), 0.9, 0.4, dv, dv * 4.0, KatonLib.PAL_FIRE, 4)
	KatonLib.embers(pj, p, 16, 0.8, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 7.0, "spread": 150.0, "life": 0.9})
	KatonLib.light(pj, p, FIRE_L, 5.0, 9.0, 0.35)
	KatonLib.ash_puff(pj, p + Vector3.UP * 1.0, 0.6, 1.6, 1.4, Vector3.UP * 1.5, 0.8)
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 3.0:
		KatonLib.scorch(pj, g, 1.6, 5.0)


# ================================================================== 14) Byōen Hōka: kedi alevi kükremesi
## Anime (Nibi gücü): kullanıcının üstünde mavi alevden dev kedi başı belirir — sivri kulaklar, kara çizgiler, iki renk göz,
## sivri dişli açık ağız; ağzından art arda turuncu ateş topları kükreyerek fırlar. İsabette turuncu çekirdek, mavi alev saçağı.
static func byoen_hoka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var tt = pj.tg(c, t, 26.0)
	var head = c.global_position + Vector3.UP * 3.0 + c.face_dir() * 1.5
	var cat = _cat_head()
	pj.get_tree().current_scene.add_child(cat)
	cat.global_position = head
	KatonLib.look(cat, c.face_dir())
	cat.scale = Vector3.ONE * 0.1
	var tw = cat.create_tween()
	tw.tween_property(cat, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.1)
	tw.tween_property(cat, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(cat.queue_free)
	KatonLib.light(pj, head, BLUE_L, 6.0, 12.0, 1.7)
	KatonLib.embers(pj, head, 20, 1.5, KatonLib.PAL_BLUE, {"vmin": 1.0, "vmax": 3.0, "life": 1.2})
	# --- oynanış (p_byoen_hoka'dan birebir)
	for k in 5:
		pj.after(0.35 + k * 0.14, func():
			if pj.live(c):
				var from = head + c.face_dir() * 0.8 + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.2), 0)
				# ağızda turuncu top şişer (kükreme)
				KatonLib.mass(pj, from, 0.2, 0.9, 0.18, c.face_dir() * 3.0, KatonLib.PAL_FIRE, 1.5, 2.0)
				var ball = Node3D.new()
				ball.add_child(KatonLib.mass_mi(0.55, KatonLib.PAL_FIRE, 1.3, 2.4))
				ball.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_FIRE, 2), 2.4))
				var tl = KatonLib.tongue_mi(1.5, 0.6, Vector3(0, 0.15, 1.0), KatonLib.PAL_BLUE, 3, 0.0, 1.1)
				ball.add_child(tl)
				var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, ball, pj.inf(c, "byoen_hoka", 0.9, {"knock": 6.0, "kind": "heavy", "element": "katon", "burn": 2.0}), tt, false, 1.4, func(p, _h):
					_cat_flame_hit(pj, p)
					_impact_marks(pj, p, 1.2))
				pr.homing_turn = 3.0
				var cnt = {"n": 0}
				pr.on_tick = func(p2, _dt):
					cnt["n"] += 1
					if cnt["n"] % 2 == 0:
						var back = -p2.vel.normalized()
						KatonLib.tongue(pj, p2.global_position + back * 0.5, randf_range(0.6, 1.0), 0.4, 0.25, back, back * 2.0, KatonLib.PAL_BLUE if cnt["n"] % 4 == 0 else KatonLib.PAL_FIRE, 3, 1.0))
	Sfx.play("roar", head, 1.2)
	Sfx.play("fire", head, 0.8)


## Mavi alev kedi başı (-Z ileri): yassı kafa kütlesi, iki sivri kulak dili, yanak yeleleri, kara kaplan çizgileri,
## sarı ve yeşil göz (dik göz bebeği), siyah burun, açık ağız (kara iç, beyaz sivri dişler)
static func _cat_head() -> Node3D:
	var root = Node3D.new()
	var sk = KatonLib.mass_mi(1.0, KatonLib.PAL_BLUE, 1.2, 1.2)
	sk.scale = Vector3(1.6, 1.3, 1.1)
	root.add_child(sk)
	var mz = KatonLib.mass_mi(1.0, KatonLib.PAL_BLUE, 1.3, 1.5)
	mz.scale = Vector3(0.9, 0.6, 0.6)
	mz.position = Vector3(0, -0.5, -1.0)
	root.add_child(mz)
	for sx in [-1.0, 1.0]:
		var ear = KatonLib.tongue_mi(1.8, 1.0, Vector3(sx * 0.35, 1.0, 0.1), KatonLib.PAL_BLUE, 2, 0.0, 1.25)
		ear.position = Vector3(sx * 0.95, 0.9, 0.0)
		root.add_child(ear)
		for k in 3:
			var ch = KatonLib.tongue_mi(1.4, 0.8, Vector3(sx * 1.0, -0.2 + k * 0.3, 0.5), KatonLib.PAL_BLUE, 4, 0.0, 1.1)
			ch.position = Vector3(sx * 1.4, -0.3 + k * 0.35, 0.2)
			root.add_child(ch)
	for k in 5:
		var a = lerpf(-1.0, 1.0, k / 4.0)
		var mn = KatonLib.tongue_mi(2.2, 1.3, Vector3(sin(a) * 0.7, 0.6, 1.0), KatonLib.PAL_BLUE, 5, 0.0, 1.1)
		mn.position = Vector3(sin(a) * 1.0, 0.6, 0.8)
		root.add_child(mn)
	var b = MB.new()
	var ink = Color(0.03, 0.04, 0.12)
	# yüz parçaları kütlelerin kabaran yüzeyinin önünde (yoksa mavi alev kütlesi örter)
	# kaplan çizgileri (alın + yanak)
	for i in 3:
		b.add("box", Vector3((i - 1) * 0.28, 0.85, -1.28), Vector3(0.07, 0.42, 0.04), ink, Vector3(0, 0, (i - 1) * 18.0))
	for sx in [-1.0, 1.0]:
		for i in 2:
			b.add("box", Vector3(sx * 1.2, 0.1 - i * 0.3, -1.12), Vector3(0.45, 0.07, 0.04), ink, Vector3(0, sx * 40.0, sx * (10.0 + i * 12.0)))
	# gözler: sağ sarı, sol yeşil; dik göz bebeği
	b.add("sphere", Vector3(-0.55, 0.35, -1.5), Vector3(0.42, 0.26, 0.08), Color(1.0, 0.86, 0.25), Vector3(0, 0, -14.0), 10)
	b.add("sphere", Vector3(0.55, 0.35, -1.5), Vector3(0.42, 0.26, 0.08), Color(0.55, 0.95, 0.35), Vector3(0, 0, 14.0), 10)
	for sx in [-1.0, 1.0]:
		b.add("box", Vector3(sx * 0.55, 0.35, -1.55), Vector3(0.06, 0.22, 0.02), ink)
	b.add("sphere", Vector3(0, -0.22, -1.82), Vector3(0.3, 0.16, 0.1), ink, Vector3.ZERO, 8)
	# açık ağız: kara iç + üst/alt sivri dişler
	b.add("sphere", Vector3(0, -1.05, -1.5), Vector3(1.0, 0.5, 0.5), Color(0.05, 0.03, 0.12), Vector3.ZERO, 12)
	for sx in [-1.0, 1.0]:
		b.add("cone", Vector3(sx * 0.36, -0.95, -1.78), Vector3(0.12, 0.42, 0.12), Color(0.97, 0.97, 1.0), Vector3(180, 0, 0), 5)
		b.add("cone", Vector3(sx * 0.3, -1.25, -1.74), Vector3(0.1, 0.32, 0.1), Color(0.97, 0.97, 1.0), Vector3.ZERO, 5)
		for i in 2:
			b.add("cone", Vector3(sx * (0.14 + i * 0.1), -0.95, -1.8), Vector3(0.06, 0.16, 0.06), Color(0.97, 0.97, 1.0), Vector3(180, 0, 0), 4)
	root.add_child(_flat(b))
	root.add_child(KatonLib.glow_mi(KatonLib.pal_col(KatonLib.PAL_BLUE, 2), 7.0))
	return root


## Kedi alevi isabeti: turuncu kabaran çekirdek, dışa savrulan mavi alev saçakları, mavi-turuncu kor
static func _cat_flame_hit(pj: PathJutsu, p: Vector3) -> void:
	KatonLib.mass(pj, p, 0.4, 1.9, 0.5, Vector3.UP * 1.0, KatonLib.PAL_FIRE, 1.4, 2.0)
	for k in 8:
		var a = k * TAU / 8.0 + randf() * 0.3
		var dv = Vector3(cos(a), randf_range(0.2, 0.7), sin(a)).normalized()
		KatonLib.tongue(pj, p, randf_range(1.4, 2.2), 0.8, 0.45, dv, dv * 4.0, KatonLib.PAL_BLUE, 4)
	KatonLib.embers(pj, p, 12, 0.4, KatonLib.PAL_BLUE, {"vmin": 2.0, "vmax": 6.0, "spread": 150.0, "life": 0.8})
	KatonLib.embers(pj, p, 12, 0.4, KatonLib.PAL_FIRE, {"vmin": 2.0, "vmax": 6.0, "spread": 150.0, "life": 0.8})
	KatonLib.light(pj, p, BLUE_L, 5.0, 9.0, 0.4)
	var g = KatonLib.floor_at(p)
	if p.y - g.y < 2.5:
		KatonLib.scorch(pj, g, 2.0, 5.0, 0.0, KatonLib.PAL_BLUE)


# ================================================================== 15) Dai Endan: kurbağa yağıyla büyük alev
## Anime (bilge kurbağalar): omuzlardaki kurbağalar kalın sarı-kahve yağ kusar; yağ kavis çizip yere döker, parlak yağ gölü oluşur.
## Kullanıcı alevi üfleyince alev yağ akıntısı boyunca geriye ve ileriye koşar, kalın, ağır, isli yağlı alev seline döner;
## yağ gölü uzun süre yanar, tepesinden kara is yükselir.
static func katon_dai_endan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.3)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var arcs: Array = []
	for sx in [-1.0, 1.0]:
		var sh = c.global_position + Vector3.UP * 1.55 + side * sx * 0.3 + d * 0.2
		var dd = (d - Vector3.UP * 0.06 + side * -sx * 0.03).normalized()
		var pts = PackedVector3Array()
		var vel = dd * 16.0
		for i in 12:
			var tm = i * 0.07
			var p = sh + vel * tm + Vector3.DOWN * 0.5 * 9.0 * tm * tm
			var fy = Game.jutsu_floor(p.x, p.z) + 0.1
			if p.y < fy:
				p.y = fy
			pts.append(p)
		arcs.append(pts)
		# omuzda yağ keseleri şişer
		var bulb = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		bulb.mesh = sm
		bulb.material_override = _oil_mat()
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		KatonLib.put(pj, bulb, sh + Vector3.UP * 0.15)
		bulb.scale = Vector3.ONE * 0.05
		var tb = bulb.create_tween()
		tb.tween_property(bulb, "scale", Vector3.ONE * 0.45, 0.15).set_trans(Tween.TRANS_BACK)
		tb.tween_property(bulb, "scale", Vector3.ONE * 0.05, 0.6)
		tb.tween_callback(bulb.queue_free)
		pj.after(0.15, func():
			if pj.live(c):
				_oil_stream(pj, pts))
	var pool_at = pj.gp(c.global_position + d * 12.0)
	pj.after(0.4, func():
		_oil_pool(pj, pool_at, 4.5, 6.0))
	Sfx.play("water", c.global_position, 0.7)
	pj.after(0.55, func():
		if not pj.live(c):
			return
		pj.anim(c, "push", 1.2)
		var mo = pj._mouth_pos(c)
		KatonLib.glow(pj, mo + d * 0.3, 1.6, KatonLib.pal_col(KatonLib.PAL_FIRE, 1), 0.3)
		# yağ akıntıları boyunca koşan alev
		for pts in arcs:
			KatonLib.ribbon(pj, pts, 0.35, 0.9, KatonLib.PAL_FIRE, {"flow": 6.0, "tiles": 4.0, "rag": 0.5, "heat": 1.3})
		# kalın, ağır, yağlı alev seli: alçak akan kütleler + geniş diller + üstte is
		pj.every(0.7, 0.05, func(i, _k):
			var m0 = pj._mouth_pos(c) if pj.live(c) else mo
			for q in 2:
				var u = randf()
				var p = m0 + d * (1.0 + u * 18.0) + side * randf_range(-1.0, 1.0) * (0.5 + u * 3.5) + Vector3.DOWN * u * 0.9
				KatonLib.mass(pj, p, 0.5 + u * 0.8, 1.2 + u * 2.0, 0.5, d * 10.0 + Vector3.UP * 0.4, KatonLib.PAL_FIRE, 1.35, 1.0)
			var u2 = randf()
			var p2 = m0 + d * (2.0 + u2 * 16.0) + side * randf_range(-1.0, 1.0) * (0.5 + u2 * 3.0)
			KatonLib.tongue(pj, p2, 2.0 + u2 * 2.5, 1.4 + u2 * 1.2, 0.5, (d + Vector3.UP * 0.7).normalized(), d * 9.0, KatonLib.PAL_FIRE, 6, 1.2)
			if i % 3 == 0:
				KatonLib.ash_puff(pj, m0 + d * (6.0 + randf() * 10.0) + Vector3.UP * 2.5, 0.4, 1.2, 1.0, Vector3.UP * 3.0 + d * 3.0, 0.8), Callable())
		KatonLib.shimmer(pj, c.global_position + d * 10.0 + Vector3.UP * 2.5, 12.0, 5.0, 1.6)
		KatonLib.light(pj, mo + d * 8.0, FIRE_L, 8.0, 20.0, 1.0)
		for k in 4:
			KatonLib.scorch(pj, c.global_position + d * (4.0 + k * 4.0), 2.2 + k * 0.4, 6.0)
		# --- oynanış (p_katon_dai_endan'dan birebir)
		Combat.hit_zone(c, c.global_position, d, 20.0, 22.0, 3.5, pj.inf(c, "katon_dai_endan", 1.6, {"knock": 10.0, "kind": "heavy", "element": "katon", "burn": 4.0}))
		# yere düşen yanan yağ gölü
		KatonLib.burn_patch(pj, pool_at, 4.0, 5.0, KatonLib.PAL_FIRE, 0.1, 1.8)
		pj.every(5.0, 0.5, func(_i, _k):
			if _i % 2 == 0:
				KatonLib.ash_puff(pj, pool_at + Vector3(randf_range(-2, 2), 2.2, randf_range(-2, 2)), 0.4, 1.2, 1.1, Vector3.UP * 3.0, 0.8)
			for e in pj.enemies_near(c, pool_at, 4.5):
				if is_instance_valid(e) and not e.is_dead():
					e.take_hit(pj.inf(c, "katon_dai_endan", 0.12, {"element": "katon", "burn": 1.0, "knock": 0.0, "kind": "light"})), Callable())
		pj.shake(0.8)
		Sfx.play("fire", c.global_position, 0.6))


## Yağ malzemesi (yalnız bu teknik): koyu kehribar gövde, akan parlak sarı damarlar, kalın koyu kenar
static func _oil_mat() -> ShaderMaterial:
	if _cache.has("oil"):
		return _cache["oil"]
	var sh = Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

instance uniform float fade = 1.0;

float oh(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float on(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(oh(i), oh(i + vec2(1.0, 0.0)), f.x), mix(oh(i + vec2(0.0, 1.0)), oh(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float fv = abs(dot(NORMAL, VIEW));
	float n = on(UV * vec2(8.0, 3.0) + vec2(-TIME * 1.6, 0.0));
	vec3 col = vec3(0.5, 0.34, 0.08);
	if (n > 0.55) {
		col = vec3(0.78, 0.6, 0.2);
	}
	if (n > 0.8) {
		col = vec3(0.98, 0.86, 0.45);
	}
	if (fv < 0.3) {
		col = vec3(0.22, 0.14, 0.04);
	}
	ALBEDO = pow(col, vec3(2.2));
	ALPHA = fade;
}
"""
	var m = ShaderMaterial.new()
	m.shader = sh
	_cache["oil"] = m
	return m


## Omuzdan dökülen kalın yağ kavisi: baştan ileri akan tüp şerit + uçuşan yağ damlaları
static func _oil_stream(pj: PathJutsu, pts: PackedVector3Array) -> void:
	var wid = PackedFloat32Array()
	for i in pts.size():
		wid.append(1.0 - float(i) / pts.size() * 0.3)
	var mi = MeshInstance3D.new()
	mi.mesh = KatonLib.strip(pts, 0.16, Vector3.ZERO, true, wid)
	mi.material_override = _oil_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	KatonLib.put(pj, mi, Vector3.ZERO)
	mi.set_instance_shader_parameter("fade", 1.0)
	var tw = mi.create_tween()
	tw.tween_interval(0.85)
	tw.tween_method(KatonLib.pf(mi, "fade"), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	for k in 6:
		var i = randi_range(2, pts.size() - 2)
		var drop = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		drop.mesh = sm
		drop.material_override = _oil_mat()
		drop.scale = Vector3.ONE * randf_range(0.1, 0.18)
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tv = (pts[i + 1] - pts[i - 1]).normalized()
		KatonLib.toss(pj, drop, pts[i], tv * randf_range(3.0, 6.0) + Vector3(randf_range(-1, 1), randf_range(0.5, 2.0), randf_range(-1, 1)), 0.8, 12.0)


## Parlak yağ gölü: yere yayılan yassı diskler, dur sonra solar
static func _oil_pool(pj: PathJutsu, at: Vector3, r: float, dur: float) -> void:
	var root = Node3D.new()
	KatonLib.put(pj, root, at + Vector3.UP * 0.04)
	for k in 4:
		var cy = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.02
		cm.radial_segments = 20
		cy.mesh = cm
		cy.material_override = _oil_mat()
		cy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cy.position = Vector3(randf_range(-1, 1) * r * 0.35, k * 0.005, randf_range(-1, 1) * r * 0.35)
		var rr = r * randf_range(0.45, 0.65)
		cy.scale = Vector3(0.1, 1.0, 0.1)
		root.add_child(cy)
		cy.set_instance_shader_parameter("fade", 1.0)
		var tw = cy.create_tween()
		tw.tween_property(cy, "scale", Vector3(rr, 1.0, rr * randf_range(0.7, 1.0)), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(dur)
		tw.tween_method(KatonLib.pf(cy, "fade"), 1.0, 0.0, 0.6)
	KatonLib.kill(pj, dur + 1.2, root)
