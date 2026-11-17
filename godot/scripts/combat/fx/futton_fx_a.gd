class_name FuttonFXA
extends RefCounted
## Futton grubu A (Mei, Han): on kaynama tekniğinin görselleri — malzeme ve yapı taşları FuttonLib'den (kendi cel buhar bulutu,
## dişli buhar dili, buhar halkası, haşlanmış / asitli zemin shader'ları). Su sıçraması değil: yoğun beyaz kaynar buhar,
## gri gölgeli kabaran bulutlar, yoğuşup düşen damlalar; Mei'nin Kōmu'su soluk sarı-yeşil aşındırıcı sis.
## Her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı.


## Bedenin arka / omuz noktası (Han'ın zırh delikleri): sırtın ortası, iki omuz, iki dirsek hizası
static func _vents(c: Node3D) -> Array:
	var f = c.face_dir()
	var s = FuttonLib.side_of(f)
	var b = c.global_position
	return [b + Vector3.UP * 1.45 - f * 0.3, b + Vector3.UP * 1.55 - f * 0.2 + s * 0.3, b + Vector3.UP * 1.55 - f * 0.2 - s * 0.3,
		b + Vector3.UP * 1.05 - f * 0.15 + s * 0.38, b + Vector3.UP * 1.05 - f * 0.15 - s * 0.38]


# ================================================================== 1) Kōmu no Jutsu: ağızdan asit sisi
## Kanon (ref Skilled Mist): Mei ağzından yoğun, beyazdan soluk sarı-yeşile dönen sis üfler; sis önündeki alana çöker,
## alçak bulutlar hâlinde yavaşça dolanır, yer aşınıp kabarcıklanır, içindekilerin bedeninden asit kabarcıkları çıkar.
static func futton_komu_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 6.0)
	# üfleme: ağızdan çıkan dar akım genişleyerek ileri yuvarlanır (ağızda beyaz, uzakta sarı-yeşil)
	for k in 8:
		pj.after(k * 0.06, func():
			if pj.live(c):
				var o = pj._mouth_pos(c) + d * (0.6 + k * 0.7)
				var tn = FuttonLib.STEAM.lerp(FuttonLib.ACID, k / 7.0)
				FuttonLib.puff(pj, o, 0.2 + k * 0.08, 0.5 + k * 0.24, 1.6, d * 2.6, {"tint": tn, "rise": 0.2, "erode_at": 0.5})
				if k % 2 == 0:
					FuttonLib.puff(pj, o + FuttonLib.side_of(d) * randf_range(-0.4, 0.4), 0.15, 0.35 + k * 0.12, 1.1, d * 4.0 + Vector3.UP * 0.4, {"tint": tn, "rise": 0.3}))
	FuttonLib.stain(pj, at, 6.0, 7.5, 1.0)
	pj.every(7.0, 0.12, func(_i, _k):
		# çöken sis: alçak, ağır, yavaş dolanan bulutlar (aynı karede tek bulut — alan kalabalıklaşmaz)
		if _i % 2 == 0:
			var q = at + Vector3(randf_range(-4, 4), randf_range(0.5, 1.1), randf_range(-4, 4))
			var drift = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
			FuttonLib.puff(pj, q, 1.2, randf_range(2.0, 2.6), 2.8, drift, {"tint": FuttonLib.ACID, "rise": 0.25, "erode_at": 0.55})
		for e in pj.enemies_near(c, at, 6.0):
			pj.st(e, "slow", 0.6)
			e.take_hit(pj.inf(c, "futton_komu_no_jutsu", 0.06, {"knock": 0.0, "kind": "light", "poison": 1.0, "armor_break": 0.1}))
			if _i % 6 == 0:
				FuttonLib.fizz(pj, e.global_position + Vector3.UP * 1.0, 8, 0.35, {"life": 0.6}), Callable())
	Sfx.play("wind", c.global_position, 0.7)


# ================================================================== 2) Terumi Kōmu: Mei'nin kalın asit sis duvarı
## Klan biçimi: üç kol hâlinde yelpaze gibi açılan geniş üfleme; sis hedef alanın kenarında halka olur ve içe doğru kapanır
## (kaçış yolunu örten çember), merkezde daha koyu sarı-yeşil asit; yer çukur çukur aşınır, içindekilerden asit damlar.
static func terumi_futton_komu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 6.0)
	for k in 8:
		pj.after(k * 0.06, func():
			if pj.live(c):
				var o = pj._mouth_pos(c)
				for lane in 3:
					var ld = d.rotated(Vector3.UP, (lane - 1) * 0.32)
					FuttonLib.puff(pj, o + ld * (0.6 + k * 0.75), 0.25 + k * 0.08, 0.45 + k * 0.2, 1.5, ld * 3.0, {"tint": FuttonLib.ACID_THICK.lerp(FuttonLib.STEAM, 0.6 - k * 0.07), "rise": 0.15}))
	FuttonLib.stain(pj, at, 6.5, 5.8, 1.0)
	# sis halkası: hedef alanın kenarından içe doğru kapanan duvar
	for k in 10:
		var a = k * TAU / 10.0
		var edge = at + Vector3(cos(a), 0, sin(a)) * 6.0 + Vector3.UP * 0.9
		FuttonLib.puff(pj, edge, 0.8, 2.4, 3.2, (at - edge).normalized() * 2.4, {"tint": FuttonLib.ACID, "rise": 0.3, "delay": 0.35 + k * 0.04, "erode_at": 0.55})
	pj.every(5.0, 0.1, func(_i, _k):
		if _i % 2 == 0:
			var a = randf() * TAU
			var rr = sqrt(randf()) * 5.0
			var q = at + Vector3(cos(a) * rr, randf_range(0.4, 1.0), sin(a) * rr)
			# merkeze yakın bulutlar daha koyu (asit yoğun)
			var tn = FuttonLib.ACID_THICK.lerp(FuttonLib.ACID, rr / 5.0)
			FuttonLib.puff(pj, q, 1.0, randf_range(1.9, 2.5), 2.4, Vector3(-sin(a), 0, cos(a)) * 0.8, {"tint": tn, "rise": 0.2, "erode_at": 0.5}), Callable())
	pj.every(5.0, 0.5, func(_i, _k):
		for e in pj.enemies_near(c, at, 6.5):
			pj.st(e, "slow", 0.6)
			e.take_hit(pj.inf(c, "terumi_futton_komu", 0.3, {"knock": 0.0, "kind": "light", "poison": 2.0, "armor_break": 0.2}))
			FuttonLib.fizz(pj, e.global_position + Vector3.UP * 1.1, 10, 0.4, {"life": 0.7})
			FuttonLib.fizz(pj, e.global_position + Vector3.UP * 0.9, 6, 0.3, {"life": 0.6, "dir": Vector3.DOWN, "g": Vector3(0, -6.0, 0), "vmin": 0.2, "vmax": 0.6}), Callable())
	Sfx.play("wind", at, 0.8)


# ================================================================== 3) Kairiki Musō: buhar zırhı
## Kanon Han: zırhın deliklerinden (sırt, omuz, dirsek) dişli buhar dilleri fışkırır, ayak dibinde halka açılır; 15 sn boyunca
## delikler sırayla kısa kısa üfler, sırttan buhar tüter, yoğuşan damlalar düşer.
static func futton_kairiki_muso(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var vs = _vents(c)
	var f = c.face_dir()
	var s = FuttonLib.side_of(f)
	var outs = [Vector3.UP - f * 0.4, (Vector3.UP + s - f * 0.3).normalized(), (Vector3.UP - s - f * 0.3).normalized(), (s - f * 0.6 + Vector3.UP * 0.3).normalized(), (-s - f * 0.6 + Vector3.UP * 0.3).normalized()]
	for k in vs.size():
		FuttonLib.jet(pj, vs[k], outs[k], 2.6 if k < 3 else 1.8, 0.7 if k < 3 else 0.5, 0.7, {"delay": k * 0.04})
		FuttonLib.puff(pj, vs[k] + outs[k] * 1.4, 0.3, 0.9, 1.3, outs[k] * 2.0, {"delay": 0.1 + k * 0.04})
	FuttonLib.ring(pj, FuttonLib.floor_at(c.global_position) + Vector3.UP * 0.15, 3.0, 0.6)
	FuttonLib.droplets(pj, c.global_position + Vector3.UP * 1.6, 18, 0.6, {"vmin": 1.0, "vmax": 3.0, "spread": 70.0})
	if c is Player:
		Buffs.add("kairiki_muso", 15.0, {"melee": 1.4, "speed": 1.07, "_name": "Eşsiz Güç", "_desc": "buhar itişli vuruşlar: yakın dövüş +%40"})
	pj.every(15.0, 0.3, func(_i, _k):
		if pj.live(c):
			var v2 = _vents(c)
			var n = _i % v2.size()
			var up = (Vector3.UP - c.face_dir() * 0.35).normalized()
			if _i % 2 == 0:
				FuttonLib.jet(pj, v2[n], up, 0.9, 0.28, 0.4)
			FuttonLib.puff(pj, v2[0] + Vector3.UP * 0.2, 0.15, 0.45, 1.0, up * 1.2, {"rise": 0.5})
			if _i % 5 == 0:
				FuttonLib.droplets(pj, v2[0], 3, 0.2, {"vmin": 0.3, "vmax": 0.8, "life": 0.6}), Callable())
	Sfx.play("wind", c.global_position, 0.8)


# ================================================================== 4) Funsuiken: buhar itişli yumruk
## Ref Funsuiken: dirsek ve sırttaki deliklerden geriye uzun dişli buhar dilleri patlar, beden ileri fırlar; yumruk değince
## önünde dikey bir buhar halkası açılır, yumruk yönünde kaynar buhar koni gibi saçılır, damlalar sıçrar.
static func funsuiken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 7.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.7)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		# sırttan / dirsekten arkaya fışkıran buhar itişi
		var s = FuttonLib.side_of(d)
		var back = c.global_position + Vector3.UP * 1.2 - d * 0.5
		FuttonLib.jet(pj, back, (-d + Vector3.UP * 0.15).normalized(), 3.2, 0.9, 0.55)
		FuttonLib.jet(pj, back + s * 0.35 - Vector3.UP * 0.1, (-d + s * 0.25).normalized(), 2.4, 0.6, 0.45)
		for k in 4:
			FuttonLib.puff(pj, back - d * (0.8 + k * 0.6), 0.3, 0.8 + k * 0.15, 1.0, -d * 2.0, {"delay": k * 0.04, "rise": 0.3})
		if c is CharacterBody3D:
			c.velocity = d * 20.0
		pj.anim(c, "cross", 2.0)
		pj.after(0.12, func():
			if pj.live(c):
				var at = c.global_position + Vector3.UP * 1.2 + d * 1.3
				# buhar patlaması: ateş değil, beyaz kaynar buhar — yumruğun önünde dikey halka + ileri koni
				FuttonLib.ring(pj, at + d * 0.3, 2.4, 0.35, d, {"thick": 0.18})
				FuttonLib.jet(pj, at, d, 3.6, 1.3, 0.5)
				for k in 5:
					var dv = (d + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.5), randf_range(-0.5, 0.5))).normalized()
					FuttonLib.puff(pj, at + dv * 0.5, 0.3, randf_range(0.8, 1.2), 0.9, dv * 6.0, {"rise": 0.4})
				FuttonLib.droplets(pj, at, 16, 0.3, {"dir": d, "spread": 50.0, "vmin": 3.0, "vmax": 7.0})
				pj.hit(c, at, 2.0, pj.inf(c, "funsuiken", 1.8, {"knock": 22.0, "launch": 4.0, "kind": "heavy", "element": "futton"}))))
	Sfx.play("wind", c.global_position, 0.8)


# ================================================================== 5) Jōki Bakuhatsu: buhar patlaması
## Ref Steam Explosion: önce bedenin her yerinden buhar sızar (basınç toplanır), sonra beden yıldız gibi dışa doğru dişli
## buhar dilleri fırlatır, yerde geniş bir halka koşar, kabaran bulutlar çevreye yuvarlanır, damla yağar.
static func futton_joki_bakuhatsu(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.8)
	var at = c.global_position + Vector3.UP * 1.0
	# basınç: bedenden sızan küçük buhar ve kısa fısıltılar
	for k in 6:
		var q = at + Vector3(randf_range(-0.35, 0.35), randf_range(-0.6, 0.7), randf_range(-0.35, 0.35))
		FuttonLib.puff(pj, q, 0.1, 0.35, 0.6, (q - at).normalized() * 0.8, {"delay": k * 0.05, "rise": 0.4})
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.8), randf_range(-1, 1)).normalized()
		FuttonLib.jet(pj, q, dv, 0.6, 0.18, 0.25, {"delay": k * 0.05})
	pj.after(0.35, func():
		# bedenden dışa fırlayan yıldız biçimli dişli buhar dilleri + yerde koşan halka + dışa yuvarlanan bulutlar
		var g = FuttonLib.floor_at(at)
		FuttonLib.ring(pj, g + Vector3.UP * 0.2, 6.0, 0.6, Vector3.UP, {"thick": 0.12})
		for k in 12:
			var a = k * TAU / 12.0 + randf() * 0.15
			var dv = Vector3(cos(a), randf_range(-0.05, 0.35), sin(a)).normalized()
			FuttonLib.jet(pj, at, dv, randf_range(3.0, 4.2), 0.9, 0.55)
		for k in 9:
			var a = k * TAU / 9.0 + 0.3
			var dv = Vector3(cos(a), 0.15, sin(a))
			FuttonLib.puff(pj, at + dv * 0.8, 0.4, randf_range(1.6, 2.2), 1.4, dv * 7.0, {"rise": 0.8, "delay": 0.05})
		FuttonLib.puff(pj, at + Vector3.UP * 0.5, 0.5, 1.8, 1.3, Vector3.UP * 3.0, {"rise": 1.0})
		FuttonLib.droplets(pj, at + Vector3.UP * 1.0, 40, 1.0, {"vmin": 3.0, "vmax": 8.0, "spread": 160.0, "life": 1.1})
		FuttonLib.stain(pj, g, 4.5, 4.0, 0.0)
		pj.hit(c, at, 5.5, pj.inf(c, "futton_joki_bakuhatsu", 1.6, {"knock": 18.0, "launch": 5.0, "kind": "heavy", "element": "futton"}))
		pj.shake(0.8))
	Sfx.play("boom", at, 1.0)


# ================================================================== 6) Jōki Bakushin: buhar atılışı
## Ref Steam Dash: sırttaki deliklerden arkaya iki uzun dişli buhar dili patlar ve beden mermi gibi ileri fırlar; arkasında
## yere yakın, yuvarlanan bir buhar izi kalır. Yolda çarptığı herkesin önünde yan yana buhar savrulur.
static func joki_bakushin(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 16.0)
	var d = pj._face(c, tt)
	pj.busy(c, 0.6)
	# arkaya fışkıran buhar jeti seni ileri fırlatır
	var s = FuttonLib.side_of(d)
	var back = c.global_position + Vector3.UP * 1.3 - d * 0.6
	FuttonLib.jet(pj, back + s * 0.25, (-d + Vector3.UP * 0.2 + s * 0.1).normalized(), 4.2, 1.0, 0.6)
	FuttonLib.jet(pj, back - s * 0.25, (-d + Vector3.UP * 0.2 - s * 0.1).normalized(), 4.2, 1.0, 0.6)
	FuttonLib.puff(pj, back - d * 1.5, 0.5, 1.6, 1.2, -d * 3.0, {"rise": 0.5})
	FuttonLib.ring(pj, back - d * 0.4, 2.2, 0.35, -d, {"thick": 0.16})
	if c is CharacterBody3D:
		c.velocity = d * 32.0 + Vector3.UP * 2.0
	var done := {}
	pj.every(0.5, 1.0 / 30.0, func(_i, _k):
		if not pj.live(c):
			return
		if _i % 3 == 0:
			FuttonLib.puff(pj, c.global_position + Vector3.UP * 0.7 - d * 0.6, 0.25, randf_range(0.7, 1.0), 1.0, -d * 1.5 + Vector3.UP * 0.4, {"rise": 0.3, "erode_at": 0.3})
		for e in pj.enemies_near(c, c.global_position, 1.6):
			if not done.has(e):
				done[e] = true
				var ep = e.global_position + Vector3.UP
				for side in [-1.0, 1.0]:
					FuttonLib.puff(pj, ep + s * side * 0.4, 0.3, 1.0, 0.8, (s * side + d * 0.6).normalized() * 5.0, {"rise": 0.4})
				FuttonLib.jet(pj, ep - d * 0.3, (d + Vector3.UP * 0.3).normalized(), 2.0, 0.7, 0.35)
				e.take_hit(pj.inf(c, "joki_bakushin", 1.3, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "futton", "dir": d})), Callable())
	Sfx.play("wind", c.global_position, 0.7)


# ================================================================== 7) Futton: Kazan no Jutsu — yerden püsküren buhar sütunları
## Ref (Mei, oyun): yerde birkaç noktadan aşındırıcı buhar sızar, zemin kabarcıklanır; sonra her nokta sırayla patlar:
## dibi kızgın turuncu parlayan, yükseldikçe beyaz buhar dillerine dağılan uzun bir sütun; ağzında halka açılır.
static func futton_kazan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var cen = pj.gp(Jutsu._aim_ground(c, t, 9.0, 22.0))
	var spots = [cen]
	var a0 = randf() * TAU
	for k in 5:
		var a = a0 + k * TAU / 5.0
		spots.append(pj.gp(cen + Vector3(cos(a), 0, sin(a)) * randf_range(3.3, 4.6)))
	Sfx.play("th_steam", cen, 0.8)
	for s in spots:
		FuttonLib.stain(pj, s, 1.6, 3.6, 1.0)
	var vent = func(i, _k):
		for s in spots:
			if i % 2 == 0:
				FuttonLib.puff(pj, s + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), 0.15, randf_range(0.5, 0.8), 1.0, Vector3.UP * 1.5, {"tint": FuttonLib.ACID.lerp(FuttonLib.STEAM, 0.5), "rise": 0.8})
		if i % 3 == 0 and pj.live(c):
			for s in spots:
				for e in pj.enemies_near(c, s, 2.0):
					pj.st(e, "slow", 0.6)
					e.take_hit(pj.inf(c, "futton_kazan", 0.05, {"knock": 0.0, "kind": "light", "element": "futton", "poison": 1.0, "armor_break": 0.1}))
	pj.every(1.6, 0.12, vent, Callable())
	for k in spots.size():
		var s: Vector3 = spots[k]
		var erupt = func():
			# püskürme: dibi kızgın turuncu, yukarı doğru beyaz buhar sütunu
			FuttonLib.hot(pj, s + Vector3.UP * 0.4, 3.0, 0.7)
			FuttonLib.light(pj, s + Vector3.UP, Color(1.0, 0.65, 0.3), 5.0, 9.0, 0.3)
			FuttonLib.jet(pj, s, Vector3.UP, 7.0, 1.7, 0.9, {"tint": Color(1.0, 0.97, 0.93)})
			for q in 3:
				var tl = (Vector3.UP + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))).normalized()
				FuttonLib.jet(pj, s + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), tl, randf_range(3.5, 5.0), 0.8, 0.7, {"delay": 0.04 * q})
			FuttonLib.ring(pj, s + Vector3.UP * 0.15, 3.0, 0.5)
			FuttonLib.puff(pj, s + Vector3.UP * 5.5, 0.6, 2.0, 1.4, Vector3.UP * 2.0, {"rise": 1.2, "delay": 0.15})
			for q in 3:
				var a = randf() * TAU
				FuttonLib.puff(pj, s + Vector3(cos(a), 0.4, sin(a)) * 0.6, 0.3, 1.0, 0.9, Vector3(cos(a), 0.3, sin(a)) * 3.5, {"rise": 0.3})
			FuttonLib.droplets(pj, s + Vector3.UP * 4.0, 16, 0.8, {"vmin": 1.0, "vmax": 4.0, "spread": 120.0, "life": 1.2})
			if pj.live(c):
				pj.hit(c, s + Vector3.UP * 0.8, 2.6, pj.inf(c, "futton_kazan", 1.15, {"knock": 6.0, "launch": 7.0, "kind": "heavy", "element": "futton", "burn": 2.0, "armor_break": 0.2}))
			pj.shake(0.4)
			Sfx.play("boom", s, 1.2, 0.7)
		pj.after(1.6 + k * 0.22, erupt)


# ================================================================== 8) Funkōtō: buharla yere çakış
## Ref Han (Storm): hedefi buharla havaya atar, ayak altından aşağı buhar püskürterek peşinden çıkar; sırttaki ocaktan yukarı
## fışkıran dev buhar dilleri bedeni aşağı iter. Çarpışta yerden V biçiminde açılan beyaz buhar sütunları, koşan halka, ıslak zemin.
static func funkoto(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 5.5)
	pj.busy(c, 1.3)
	var d = pj._jump_at(c, tt, 0.0, 9.0 if tt else 3.0)
	var toss = func():
		if not pj.live(c):
			return
		pj.anim(c, "hook", 1.8)
		var o = c.global_position + Vector3.UP * 0.9
		FuttonLib.jet(pj, o + d * 0.6, (Vector3.UP + d * 0.2).normalized(), 3.0, 0.8, 0.5)
		FuttonLib.puff(pj, o + d * 0.8, 0.3, 0.9, 0.8, Vector3.UP * 4.0, {"rise": 0.6})
		if pj.live(tt) and tt.global_position.distance_to(c.global_position) < 3.2:
			tt.take_hit(pj.inf(c, "funkoto", 0.4, {"knock": 0.0, "launch": 13.0, "kind": "heavy", "element": "futton"}))
		Sfx.play("th_steam", c.global_position, 1.0)
	pj.after(0.16, toss)
	var rise = func():
		if not pj.live(c):
			return
		var top: Vector3 = (tt.global_position + Vector3.UP * 1.5) if pj.live(tt) else c.global_position + Vector3.UP * 4.5
		var foot = c.global_position + Vector3.UP * 0.3
		FuttonLib.jet(pj, foot, Vector3.DOWN, 2.4, 1.0, 0.45)
		FuttonLib.ring(pj, FuttonLib.floor_at(foot) + Vector3.UP * 0.15, 2.4, 0.4)
		FuttonLib.puff(pj, foot - Vector3.UP * 0.3, 0.4, 1.2, 0.9, Vector3.ZERO, {"rise": 0.2})
		c.global_position = top
		if "velocity" in c:
			c.velocity = Vector3.UP * 3.0
	pj.after(0.5, rise)
	var stomp = func():
		if not pj.live(c):
			return
		pj._kick_pose(c, 0.35)
		# sırttaki ocaktan yukarı fışkıran buhar bedeni aşağı iter
		var bk = c.global_position + Vector3.UP * 1.5 - d * 0.3
		var s = FuttonLib.side_of(d)
		for q in 3:
			var dv = (Vector3.UP + s * (q - 1) * 0.3 - d * 0.15).normalized()
			FuttonLib.jet(pj, bk + s * (q - 1) * 0.25, dv, 4.8 if q == 1 else 3.6, 1.2 if q == 1 else 0.8, 0.6)
		FuttonLib.puff(pj, bk + Vector3.UP * 2.5, 0.4, 1.4, 1.0, Vector3.UP * 2.0, {"rise": 0.8})
		if pj.live(tt) and tt.global_position.distance_to(c.global_position) < 4.0:
			tt.take_hit(pj.inf(c, "funkoto", 0.9, {"knock": 0.0, "launch": -24.0, "kind": "heavy", "element": "futton", "hitstop": 0.12}))
		if "velocity" in c:
			c.velocity = Vector3.DOWN * 26.0
		Sfx.play("th_steam", c.global_position, 0.7)
	pj.after(0.72, stomp)
	var crash = func():
		if not pj.live(c):
			return
		var at = pj.gp(c.global_position)
		# ref: yerden V biçiminde açılan beyaz buhar sütunları, çevrede alçak gri buhar dalgası
		var s = FuttonLib.side_of(d)
		for q in 5:
			var dv = (Vector3.UP + s * (q - 2) * 0.32 + d * randf_range(-0.15, 0.15)).normalized()
			FuttonLib.jet(pj, at + Vector3.UP * 0.3, dv, randf_range(5.0, 6.5), 1.1, 0.75, {"delay": absf(q - 2) * 0.03})
		FuttonLib.ring(pj, at + Vector3.UP * 0.2, 4.5, 0.55, Vector3.UP, {"thick": 0.15})
		for q in 8:
			var a = q * TAU / 8.0
			var dv = Vector3(cos(a), 0.1, sin(a))
			FuttonLib.puff(pj, at + dv * 1.0 + Vector3.UP * 0.4, 0.4, 1.3, 1.1, dv * 6.0, {"rise": 0.3})
		FuttonLib.stain(pj, at, 3.8, 4.5, 0.0)
		FuttonLib.droplets(pj, at + Vector3.UP * 2.0, 30, 1.0, {"vmin": 2.0, "vmax": 6.0, "spread": 100.0, "life": 1.1})
		pj.hit(c, at + Vector3.UP * 0.6, 3.6, pj.inf(c, "funkoto", 1.3, {"knock": 11.0, "launch": 3.0, "kind": "heavy", "element": "futton", "burn": 1.5}))
		pj.shake(1.0)
		Sfx.play("boom", at, 0.9)
	pj.after(0.98, crash)


# ================================================================== 9) Funkahō: buhar topu
## Han: ayak altından buharla havaya sıçrar, dönerek tekme ve yumruk indirir (değdiği yerde yana kısa buhar dilleri), sonra avucundan
## sıkışmış, yuvarlanan bir buhar topu hedefin üstüne iner — yerde kubbe gibi kabarıp dağılır.
static func funkaho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 9.0)
	pj.busy(c, 1.3)
	var d = pj._face(c, tt)
	var foot = c.global_position + Vector3.UP * 0.3
	FuttonLib.jet(pj, foot, (Vector3.DOWN - d * 0.3).normalized(), 2.2, 1.0, 0.45)
	FuttonLib.puff(pj, FuttonLib.floor_at(foot) + Vector3.UP * 0.4, 0.4, 1.2, 0.9, -d * 1.5, {"rise": 0.2})
	if "velocity" in c:
		var dist: float = c.global_position.distance_to(tt.global_position) if tt else 4.0
		c.velocity = d * clampf(dist * 2.6, 4.0, 22.0) + Vector3.UP * 10.0
	pj._kg_spin(c, 0.6, 2.0)
	Sfx.play("th_steam", c.global_position, 1.0)
	var kick = func():
		if not pj.live(c):
			return
		pj._kick_pose(c, 0.2)
		if pj.live(tt) and tt.global_position.distance_to(c.global_position) < 4.5:
			tt.take_hit(pj.inf(c, "funkaho", 0.4, {"knock": 0.0, "launch": 9.0, "kind": "heavy", "element": "futton", "melee": true}))
			var hp = tt.global_position + Vector3.UP
			var s = FuttonLib.side_of(d)
			FuttonLib.jet(pj, hp, s, 1.4, 0.45, 0.3)
			FuttonLib.jet(pj, hp, -s, 1.4, 0.45, 0.3)
	pj.after(0.34, kick)
	var punch = func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 2.0)
		if pj.live(tt) and tt.global_position.distance_to(c.global_position) < 5.5:
			c.global_position = tt.global_position - d * 1.2 + Vector3.UP * 0.6
			if "velocity" in c:
				c.velocity = Vector3.UP * 2.0
			tt.take_hit(pj.inf(c, "funkaho", 0.5, {"knock": 0.0, "launch": 3.0, "kind": "heavy", "element": "futton", "melee": true, "hitstop": 0.06}))
			FuttonLib.ring(pj, tt.global_position + Vector3.UP, 1.6, 0.3, d, {"thick": 0.2})
	pj.after(0.6, punch)
	var cannon = func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c)
		var land: Vector3 = pj.gp(tt.global_position) if pj.live(tt) else pj.gp(c.global_position + d * 5.0)
		var dir = (land + Vector3.UP * 0.3 - from).normalized()
		# buhar topu: sıkışmış, kendi çevresinde yuvarlanan beş bulut avuçtan hedefin üstüne iner, arkasında dişli buhar dili
		var ball = Node3D.new()
		pj.scene_add(ball, from)
		for q in 5:
			var off = Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			FuttonLib.puff(pj, off, 0.5, 0.75, 0.5, Vector3.ZERO, {"parent": ball, "rise": 0.0, "erode_at": 0.8})
		var btw = ball.create_tween().set_parallel()
		btw.tween_property(ball, "global_position", land + Vector3.UP * 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		btw.tween_property(ball, "rotation", Vector3(randf_range(4, 7), 0, randf_range(4, 7)), 0.18)
		btw.chain().tween_callback(ball.queue_free)
		FuttonLib.jet(pj, from, -dir, 1.6, 0.6, 0.35)
		FuttonLib.jet(pj, from, dir, from.distance_to(land), 0.9, 0.4)
		FuttonLib.light(pj, from, Color(1, 1, 1), 4.0, 8.0, 0.2)
		if pj.live(tt) and tt.global_position.distance_to(c.global_position) < 7.0:
			tt.take_hit(pj.inf(c, "funkaho", 1.3, {"knock": 0.0, "launch": -26.0, "kind": "heavy", "element": "futton", "burn": 2.0, "hitstop": 0.12}))
		if "velocity" in c:
			c.velocity = -dir * 6.0   # geri tepme
		var splash = func():
			# kubbe: yere çarpan top yarım küre gibi kabarıp dağılır
			for q in 7:
				var a = q * TAU / 7.0
				var dv = Vector3(cos(a), 0.5, sin(a)).normalized()
				FuttonLib.puff(pj, land + Vector3.UP * 0.6 + dv * 0.5, 0.5, 1.4, 1.2, dv * 4.5, {"rise": 0.6})
			FuttonLib.puff(pj, land + Vector3.UP * 1.2, 0.6, 1.9, 1.3, Vector3.UP * 2.5, {"rise": 0.9})
			FuttonLib.ring(pj, land + Vector3.UP * 0.2, 4.0, 0.5)
			FuttonLib.stain(pj, land, 3.0, 4.0, 0.0)
			FuttonLib.droplets(pj, land + Vector3.UP * 1.0, 24, 0.8, {"vmin": 2.0, "vmax": 5.0, "spread": 90.0})
			if pj.live(c):
				pj.hit(c, land + Vector3.UP * 0.6, 3.3, pj.inf(c, "funkaho", 0.7, {"knock": 9.0, "kind": "heavy", "element": "futton", "burn": 2.0}))
			pj.shake(0.8)
			Sfx.play("boom", land, 1.0)
		pj.after(0.18, splash)
		Sfx.play("th_steam", from, 0.6)
	pj.after(0.86, cannon)


# ================================================================== 10) Fungokyaku: buhar itişli tekme
## Han: buhar zırhından bedenin çevresine halka gibi buhar boşalır, tekme buharın itişiyle uzanır — bacak yönünde tek dişli buhar
## dili fırlar, ucunda küçük dikey halka açılır.
static func fungokyaku(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 0.6)
	if tt:
		pj._jump_at(c, tt, 0.0, 8.0)
	var o = c.global_position + Vector3.UP * 1.0
	for q in 6:
		var a = q * TAU / 6.0 + randf() * 0.3
		var dv = Vector3(cos(a), 0.2, sin(a))
		FuttonLib.puff(pj, o + dv * 0.5, 0.25, 0.8, 0.8, dv * 3.0, {"rise": 0.5, "delay": q * 0.02})
	FuttonLib.droplets(pj, o, 10, 0.5, {"vmin": 1.0, "vmax": 3.0, "spread": 90.0, "life": 0.7})
	Sfx.play("th_steam", c.global_position, 0.9)
	pj.after(0.18, func():
		if not pj.live(c):
			return
		pj._kick_pose(c, 0.3)
		var f = c.face_dir()
		var at = c.global_position + Vector3.UP * 1.0 + f * 1.4
		FuttonLib.jet(pj, c.global_position + Vector3.UP * 0.9 - f * 0.6, -f, 1.6, 0.5, 0.35)
		FuttonLib.jet(pj, c.global_position + Vector3.UP * 0.9 + f * 0.3, f, 2.8, 0.8, 0.4)
		FuttonLib.ring(pj, at + f * 0.4, 1.5, 0.3, f, {"thick": 0.2})
		FuttonLib.puff(pj, at, 0.3, 0.9, 0.7, f * 5.0, {"rise": 0.3})
		pj.hit(c, at, 1.8, pj.inf(c, "fungokyaku", 1.3, {"knock": 20.0, "launch": 3.0, "kind": "heavy", "burn": 2.0, "hitstop": 0.1}))
		Sfx.play("hit_heavy", at, 0.85))
