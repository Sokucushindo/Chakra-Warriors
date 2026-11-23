class_name FutonFXA
extends RefCounted
## Fūton grubu A: on beş rüzgâr tekniğinin görselleri — malzeme ve yapı taşları FutonLib'den (kendi akım çizgisi, hava perdesi,
## kesici hilal, basınç bükülmesi, zemin izi, savrulan toz/yaprak shader'ları). Katı koni / kubbe / kabuk yok.
## Her tekniğin şekli / hareketi / sahnelenmesi burada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı;
## eski görsel çağrıların oyun etkileri (saç/kumaş savrulması, rüzgârın yanan zemini büyütmesi, yarık zemin) açıkça korunur.

const WHITE := Color(1.0, 1.0, 1.0, 0.95)
const PALE_BLUE := Color(0.72, 0.88, 1.0, 0.95)
const DUST_GREY := Color(0.62, 0.6, 0.58, 0.95)
const STORM_GREY := Color(0.8, 0.82, 0.86, 0.95)


# ================================================================== küçük ortak işler (yalnız bu grup)
## Zemine göre savrulan parça: yeşil yerde yaprak, çöl / kar / kayada çakıl
static func _debris(host: Node, p: Vector3, n: int, o: Dictionary) -> void:
	var g = FutonLib.floor_at(p)
	if FutonLib.has_leaves(g):
		var ol = o.duplicate()
		ol["cols"] = FutonLib.leaf_cols(g)
		ol["size"] = float(o.get("size", 0.2))
		FutonLib.bits(host, p, n, "leaf", ol)
	else:
		var og = o.duplicate()
		var dc = FutonLib.ground_col(g).darkened(0.25)
		og["cols"] = [dc, dc, Color(dc.r, dc.g, dc.b, 0.0)]
		og["size"] = float(o.get("size", 0.2)) * 0.6
		og["g"] = Vector3(0, -14.0, 0)
		FutonLib.bits(host, p, n, "grit", og)


## Uca doğru kıvrılıp kopan düz akım yolu (d yönünde L boyunca, side/up kayması)
static func _gust_path(p0: Vector3, d: Vector3, L: float, side: Vector3, up: Vector3, s0: float, u0: float, cs: float) -> Callable:
	var ph = randf() * TAU
	var wob = randf_range(0.1, 0.3)
	return func(u: float) -> Vector3:
		var p = p0 + d * L * u + side * (s0 * u + sin(u * 8.0 + ph) * wob) + up * (u0 * u)
		if u > 0.72:
			var q = (u - 0.72) / 0.28
			p += (up * sin(q * PI) * 0.7 + side * cs * (1.0 - cos(q * PI)) * 0.6)
		return p


## Merkezden dışa kıvrılarak kaçan kısa çizgiler (darbe anı)
static func _radial_lines(host: Node, at: Vector3, r: float, n: int, w: float, life: float, tint := WHITE, flat := false) -> void:
	var gy = Game.jutsu_floor_at(at).y
	for i in n:
		var a = TAU * i / n + randf_range(-0.2, 0.2)
		var dir = Vector3(cos(a), (randf_range(-0.05, 0.25) if flat else randf_range(-0.5, 0.8)), sin(a)).normalized()
		var tng = Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
		var L = r * randf_range(0.7, 1.1)
		var p0 = at + dir * 0.3
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var p = p0 + dir * L * u + tng * sin(u * PI) * L * 0.2
			p.y = maxf(p.y, gy + 0.15)
			return p, 10)
		FutonLib.line(host, pts, w, life * randf_range(0.85, 1.15), tint, {"grow": 0.45})


# ================================================================== 1. Fūton: Daitoppa (Büyük Atılım) — j_ işleyicisi
## Ref (kanon): ağızdan patlayan geniş fırtına; merkezden her yöne açılan çizgi yelpazesi, yerde kalkan toz bandı, savrulan yaprak.
## Görünüş: ağızda basınç halkası → iki dalga halinde yelpaze gibi açılan perdeler + ışınsal parlak çizgiler; yerde süpürülmüş toz izi.
static func fuuton_daitoppa(J, c: Node3D, t: Node3D) -> void:
	var m = J._mult(c) * J._elem_bonus(c, "fuuton")
	var d = J._aim(c, t)
	d.y = clampf(d.y, -0.2, 0.3)
	Sfx.play("wind", c.global_position)
	var mo = J._mouth(c)
	Dangle.gust(mo + d * 0.4 + d.normalized() * 8.0, d.normalized() * 28.0, 9.6, 0.7)   # yoldaki saç/kumaş savrulur (eski hamlenin oyun etkisi)
	_daitoppa_wave(J, mo + d * 0.4, d, 20.0, 10.0, true)
	J.get_tree().create_timer(0.14).timeout.connect(func():
		Dangle.gust(mo + d * 0.4 + d.normalized() * 9.0, d.normalized() * 28.0, 11.0, 0.7)
		_daitoppa_wave(J, mo + d * 0.4, d, 18.0, 11.0, false))
	for k in 5:
		var pos = c.global_position + Vector3.UP * 1.2 + d * (2.0 + k * 2.4)
		Combat.hit_sphere(c, pos, 1.5 + k * 0.5, {"dmg": 12.0 * m, "element": "fuuton", "knock": 22.0, "launch": 3.0, "kind": "heavy", "dir": d, "hitstop": 0.05})


static func _daitoppa_wave(host: Node, mo: Vector3, d0: Vector3, reach: float, width: float, first: bool) -> void:
	var d = d0.normalized()
	var side = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	var gy = Game.jutsu_floor_at(mo).y
	FutonLib.warp(host, mo, 0.3, 3.0 if first else 2.2, 0.35, {"power": 1.8, "glint": 0.5})
	# yelpaze perdeleri: ağızda dar, ileride geniş; alttakiler yere yapışıp toz bandını taşır
	var ns = 7 if first else 5
	for i in ns:
		var s0 = lerpf(-1.0, 1.0, (i + 0.5) / ns) + randf_range(-0.12, 0.12)
		var u0 = randf_range(-0.35, 0.5)
		var L = reach * randf_range(0.85, 1.05)
		var bend = randf_range(-0.1, 0.1) * width
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var spread = lerpf(0.1, 0.5, u) * width
			var p = mo + d * L * u + side * (s0 * spread + sin(u * PI) * bend) + up * (u0 * spread * 0.45)
			p.y = maxf(p.y, gy + 0.35)
			return p, 16)
		var wd = PackedFloat32Array()
		for j in 16:
			wd.append(lerpf(0.15, 1.0, float(j) / 15.0))
		FutonLib.sheet(host, pts, width * 0.2, randf_range(0.6, 0.75), FutonLib.AIR, {"widths": wd, "opacity": 0.55, "lines": 5.0, "flow": 5.0, "grow": 0.4, "delay": randf() * 0.05})
	# ışınsal çizgiler: ağızdan dışa doğru açılan, uçta kıvrılan parlak çizgiler (ref: patlama yelpazesi)
	var nl = 18 if first else 12
	for i in nl:
		var s0 = randf_range(-1.0, 1.0) * width * 0.55
		var u0 = randf_range(-0.4, 1.0) * width * 0.25
		var cs = 1.0 if randf() < 0.5 else -1.0
		var pth = _gust_path(mo + side * s0 * 0.04 + up * u0 * 0.04, d, reach * randf_range(0.6, 1.05), side, up, s0, u0, cs)
		FutonLib.line(host, FutonLib.path_pts(pth, 14), randf_range(0.05, 0.1), randf_range(0.45, 0.65), WHITE, {"delay": randf() * 0.1, "grow": 0.5, "flow": 6.0})
	if first:
		var g = FutonLib.floor_at(mo + d * 2.0)
		FutonLib.scour(host, g, d, reach * 0.9, width * 0.55, 2.8, 0)
		var bas = Basis.looking_at(Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.05 else Vector3.FORWARD, Vector3.UP)
		FutonLib.bits(host, g + Vector3(d.x, 0.0, d.z).normalized() * reach * 0.25 + Vector3.UP * 0.3, 26, "puff", {"life": 1.3, "size": 1.3, "box": Vector3(width * 0.25, 0.2, reach * 0.25), "basis": bas,
			"dir": Vector3(0.0, 0.35, -1.0).normalized(), "spread": 18.0, "vmin": 10.0, "vmax": 20.0, "damp": 3.0, "g": Vector3(0, 0.3, 0), "grow": [0.5, 1.7], "spin": 40.0,
			"cols": FutonLib.dust_cols(g, 0.8), "burst": 0.7})
		_debris(host, g + Vector3.UP * 0.4, 28, {"life": 1.4, "radius": 1.5, "dir": (d + Vector3.UP * 0.3).normalized(), "spread": 25.0, "vmin": 14.0, "vmax": 26.0, "damp": 1.2, "spin": 720.0, "g": Vector3(0, -3.0, 0)})


# ================================================================== 2. Kamaitachi no Jutsu (Orak Gelincik)
## Ref (Temari): dev yelpaze savrulur, soluk mavi bulutlu fırtına içinde kesik çizgileri; Storm 4: yelpazenin etrafında beyaz hilaller.
## Görünüş: yelpaze ucuna toplanan çizgiler → savuruşta üç dev beyaz hilal ileri fırlar → ileri yürüyen kesici kasırga:
## yükselen sarmal çizgiler, soluk mavi perdeler, içinde dönüp dışa savrulan küçük orak bıçakları, zeminde kesik yarıkları.
static func kamaitachi_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	pj.anim(c, "slash_c", 1.2)
	var d = pj.fwd(c, t)
	pj.jutsu_weapon(c, "tessen", 1.0)
	var hp = c.global_position + Vector3.UP * 1.3 + d
	for i in 6:
		var a = TAU * i / 6.0
		var p0 = hp + Vector3(cos(a), sin(a) * 0.5 + 0.2, sin(a)) * 2.4
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
			return p0.lerp(hp, u) + Vector3(cos(a + u * 2.0), 0.0, sin(a + u * 2.0)) * sin(u * PI) * 0.5, 10), 0.045, 0.28, PALE_BLUE, {"delay": i * 0.015, "grow": 0.7})
	pj.after(0.12, func():
		var o = c.global_position + Vector3.UP * 1.1
		var sdv = FutonLib.side_of(d)
		# savuruş: üç dev beyaz hilal, yelpazenin önünden ileri fırlar (her biri biraz yatık)
		for k in 3:
			var roll = randf_range(-0.45, 0.45)
			FutonLib.blade(pj, o + d * (1.4 + k * 0.4) + Vector3.UP * (k - 1) * 0.5, FutonLib.blade_basis(d, Vector3.UP.rotated(d, roll)), 4.6 + k * 0.7, 0.5, WHITE,
				{"delay": k * 0.05, "vel": d * 16.0, "thick": 0.2, "wisp": 1.5, "grow": 0.2})
		# yelpaze savruluş yayı: yandan öne süpüren yatay yaylar
		for k in 3:
			var rr = randf_range(2.4, 3.4)
			var tl = randf_range(-0.3, 0.3)
			FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
				var aa = lerpf(-1.9, 1.9, u)
				return o + d * (cos(aa) * rr * 0.55 + 0.6) + sdv * sin(aa) * rr + Vector3.UP * (sin(aa) * tl + k * 0.25), 18), 0.09, 0.32, WHITE, {"delay": k * 0.04, "grow": 0.6})
		for k in 9:
			pj.after(0.1 + k * 0.11, func():
				if not is_instance_valid(c):
					return
				var q = pj.gp(c.global_position + d * (3.0 + k * 2.2))
				_kama_storm(pj, q, d, k)
				if k % 2 == 0:
					GroundFX.add(q, "cracked", 0.9, 5.0)   # eski zemin çatlağının oyun etkisi: yarık zemin üstünden geçeni yavaşlatır
					FutonLib.scour(pj, q, d.rotated(Vector3.UP, randf_range(-0.6, 0.6)), 3.0, 3.0, 4.0, 2))
		Combat.hit_zone(c, c.global_position, d, 24.0, 30.0, 4.0, pj.inf(c, "kamaitachi_no_jutsu", 1.3, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "fuuton", "bleed": 4.0, "dir": d}))
		pj.shake(0.6))
	Sfx.play("wind", c.global_position, 0.5)


## Kasırganın bir adımı: yükselen sarmal çizgiler + iki soluk mavi perde + dönüp savrulan orak bıçakları + dipte toz/yaprak
static func _kama_storm(host: Node, q: Vector3, d: Vector3, k: int) -> void:
	var a0 = randf() * TAU
	for i in 3:
		FutonLib.line(host, FutonLib.helix_pts(q, Vector3.UP, 0.5, 2.8, 0.2, 6.0, a0 + i * TAU / 3.0, 1.3, 20), 0.07, 0.5, PALE_BLUE, {"delay": i * 0.03, "grow": 0.5, "flow": 6.0})
	for i in 2:
		FutonLib.sheet(host, FutonLib.helix_pts(q, Vector3.UP, 0.7, 2.4, 0.4, 5.0, a0 + 1.0 + i * PI, 0.9, 18), 0.9, 0.6, Color(0.76, 0.9, 1.0, 0.95), {"opacity": 0.42, "lines": 4.0, "grow": 0.5})
	for i in 3:
		var a = a0 + i * TAU / 3.0 + 0.5
		var r = randf_range(1.3, 2.4)
		var pos = q + Vector3(cos(a) * r, randf_range(1.0, 4.2), sin(a) * r)
		var tng = Vector3(-sin(a), randf_range(-0.2, 0.3), cos(a)).normalized()
		FutonLib.blade(host, pos, FutonLib.blade_basis(tng, Vector3.UP.rotated(tng, randf_range(-0.6, 0.6))), randf_range(1.2, 1.7), 0.3, WHITE,
			{"vel": tng * 9.0 + d * 7.0, "thick": 0.17, "wisp": 1.2, "grow": 0.3, "delay": i * 0.03})
	if k % 3 == 0:
		_debris(host, q + Vector3.UP * 0.3, 8, {"life": 1.0, "radius": 1.2, "dir": Vector3.UP, "spread": 30.0, "vmin": 3.0, "vmax": 7.0, "tang": 22.0, "g": Vector3(0, -2.0, 0), "spin": 600.0})


# ================================================================== 3. Fūton: Toppa (Atılım)
## Ref (Mitsuki): ağızdan çıkan yumuşak beyaz akış, etrafında C biçimli hilal yaylar döner; uzakta tünel gibi dönen girdap, toz.
## Görünüş: dar ağızdan genişleyen perdeli akış, akış ekseni etrafında ileri yürüyen sarmal yay halkaları, yerde süpürülmüş iz,
## uçta yere yayılan ışınsal toz izi.
static func futon_toppa(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var d = pj.fwd(c, t)
	var from = pj._mouth_pos(c)
	FutonLib.warp(pj, from, 0.9, 0.2, 0.22, {"ring": false, "power": -1.2, "swirl": 1.5})
	Dangle.gust(from + d * 10.0, d * 28.0, 12.0, 0.7)
	var side = FutonLib.side_of(d)
	for i in 4:
		var s0 = randf_range(-0.6, 0.6)
		var u0 = randf_range(-0.3, 0.4)
		var ph = randf() * TAU
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			return from + d * 20.0 * u + side * (s0 * u * 2.4 + sin(u * 5.0 + ph) * 0.3) + Vector3.UP * (u0 * u * 1.6 - u * u * 0.4), 18)
		var wd = PackedFloat32Array()
		for j in 18:
			wd.append(lerpf(0.12, 1.0, sqrt(float(j) / 17.0)))
		FutonLib.sheet(pj, pts, 1.7, 0.75, Color(0.9, 0.93, 0.98, 0.95), {"widths": wd, "opacity": 0.6, "lines": 4.0, "flow": 4.0, "grow": 0.45, "delay": i * 0.03})
	for i in 8:
		var pth = _gust_path(from, d, 20.0 * randf_range(0.7, 1.0), side, Vector3.UP, randf_range(-1.6, 1.6), randf_range(-0.6, 0.9), 1.0 if randf() < 0.5 else -1.0)
		FutonLib.line(pj, FutonLib.path_pts(pth, 14), 0.06, 0.55, WHITE, {"delay": randf() * 0.1, "grow": 0.5})
	FutonLib.scour(pj, c.global_position + d * 1.5, d, 18.0, 4.0, 2.5, 0)
	for k in 5:
		pj.after(0.1 + k * 0.06, func():
			var q = pj.gp(c.global_position + d * (3.0 + k * 3.5))
			var cq = q + Vector3.UP * 1.2
			# akışı saran C yaylar: eksen etrafında yarım tur dönen kalın beyaz hilal çizgiler
			for j in 2:
				var a0 = randf() * TAU
				FutonLib.line(pj, FutonLib.helix_pts(cq, d, 0.9 + k * 0.35, 1.2 + k * 0.45, -0.5, 0.6, a0 + j * PI, 0.55, 14), 0.1, 0.38, WHITE, {"grow": 0.55, "flow": 5.0})
			_debris(pj, q + Vector3.UP * 0.2, 5, {"life": 0.8, "radius": 0.8, "dir": (d + Vector3.UP * 0.6).normalized(), "spread": 30.0, "vmin": 6.0, "vmax": 10.0, "spin": 500.0}))
	pj.after(0.22, func():
		var e = pj.gp(from + d * 20.0)
		FutonLib.scour(pj, e, d, 7.0, 7.0, 2.5, 1)
		FutonLib.bits(pj, e + Vector3.UP * 0.3, 16, "puff", {"life": 1.2, "size": 1.2, "radius": 1.0, "dir": Vector3.UP, "spread": 85.0, "vmin": 5.0, "vmax": 9.0, "damp": 4.0,
			"g": Vector3(0, -0.4, 0), "grow": [0.6, 1.6], "spin": 40.0, "cols": FutonLib.dust_cols(e, 0.75)}))
	Combat.hit_zone(c, c.global_position, d, 20.0, 28.0, 4.0, pj.inf(c, "futon_toppa", 1.0, {"knock": 26.0, "launch": 5.0, "kind": "heavy", "element": "fuuton", "dir": d}))
	pj.shake(0.6)
	Sfx.play("wind", c.global_position, 0.6)


# ================================================================== 4. Fūton: Reppūshō (Fırtına Avucu)
## Ref (Boruto): avucun çevresinde kıvrılan ince beyaz çizgiler; avuçtan itilen sıkışmış hava.
## Görünüş: avucu saran kıvrık çizgiler → ekranı hafifçe büken hava düğümü, etrafında burgu çizen üç ince çizgi iz; çarpınca basınç halkası
## ve dışa kaçan kısa çizgiler, yerde ışınsal iz.
static func futon_reppusho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	pj.anim(c, "push", 1.6)
	var tt = pj.tg(c, t, 24.0)
	var from = pj.hand_pos(c, true)
	var fd = c.face_dir()
	for i in 4:
		FutonLib.line(pj, FutonLib.helix_pts(from - fd * 0.3, fd, 0.6, 0.25, -0.4, 0.3, randf() * TAU, 0.8, 12), 0.045, 0.3, WHITE, {"delay": i * 0.03, "grow": 0.6})
	pj.after(0.16, func():
		if not pj.live(c):
			return
		var info = {"knock": 8.0 * 1.3, "kind": "heavy", "element": "fuuton", "hitstop": 0.05}
		info.merge({"knock": 18.0, "launch": 4.0}, true)
		var core = Node3D.new()
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, core, pj.inf(c, "futon_reppusho", 0.8, info), null, false, 1.6, func(p, _h):
			_reppu_hit(pj, p))
		pr.radius = 0.35 + 1.3 * 0.4
		FutonLib.warp(pj, Vector3.ZERO, 0.5, 0.65, 1.6, {"ring": false, "power": 1.2, "swirl": 1.2, "parent": core, "grow": 0.1, "fade_from": 0.95, "glint": 0.4})
		for i in 3:
			var a = TAU * i / 3.0
			FutonLib.follow(pj, pr, 0.06, 14, WHITE, {"offset": Vector3(cos(a), sin(a), 0.0) * 0.5, "spin": 18.0}))
	Sfx.play("wind", c.global_position, 1.3)


static func _reppu_hit(pj: PathJutsu, at: Vector3) -> void:
	var s = 1.3
	FutonLib.warp(pj, at, 0.4, 4.0 * s, 0.35, {"power": 1.6, "glint": 0.5})
	_radial_lines(pj, at, 3.0 * s, 12, 0.07, 0.35)
	_debris(pj, at, 8, {"life": 0.8, "radius": 0.4, "dir": Vector3.UP, "spread": 80.0, "vmin": 5.0, "vmax": 10.0, "spin": 600.0})
	var g = FutonLib.floor_at(at)
	if at.y - g.y < 2.5:
		FutonLib.scour(pj, g, Vector3.FORWARD, 3.5 * s, 3.5 * s, 2.0, 1)
	GroundFX.wind(at, 4.0 * s)   # eski isabetin oyun etkisi: rüzgâr yanan zemini büyütür
	pj.shake(0.25 + 0.25 * s)


# ================================================================== 5. Fūton: Kazekiri no Jutsu (Rüzgâr Kesici)
## Ref: hedefi yaran ince, kıvrık kenarlı hava dilimi (açık bej kontur, kesik). Görünüş: kol yatay savrulur (süpüren yay),
## yatay ince hilal bıçak + arkasında ince ikiz bıçak, uçlarından iki ince iz; değdiği yerde çapraz X kesik parlaması.
static func futon_kazekiri_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.45)
	pj.anim(c, "slash_b", 1.6)
	var tt = pj.tg(c, t, 26.0)
	var from = c.global_position + Vector3.UP * 1.25 + c.face_dir() * 0.7
	var fd = c.face_dir()
	var sd = FutonLib.side_of(fd)
	FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
		var aa = lerpf(-1.6, 1.2, u)
		return c.global_position + Vector3.UP * 1.25 + fd * cos(aa) * 1.1 + sd * sin(aa) * 1.1, 14), 0.07, 0.25, WHITE, {"grow": 0.7})
	pj.after(0.12, func():
		if not pj.live(c):
			return
		var blade = Node3D.new()
		var ad = pj.aim_at(c, tt, from)
		Dangle.gust(from + ad * 12.0, ad * 28.0, 14.4, 0.7)
		var pr = pj.shot(c, from, ad, 42.0, blade, pj.inf(c, "futon_kazekiri_no_jutsu", 0.7, {"knock": 5.0, "kind": "heavy", "element": "fuuton", "bleed": 3.0}), null, true, 0.9, func(p, _h):
			_kazekiri_cut(pj, p))
		pr.radius = 1.0
		var bb = FutonLib.blade_basis(Vector3.FORWARD, Vector3.UP)
		FutonLib.blade(pj, Vector3.ZERO, bb, 3.2, 0.9, Color(0.92, 1.0, 0.96, 0.95), {"parent": blade, "thick": 0.26, "wisp": 1.6, "grow": 0.08})
		FutonLib.blade(pj, Vector3(0, 0.1, 0.55), bb, 2.5, 0.9, FutonLib.MINT, {"parent": blade, "thick": 0.13, "wisp": 0.8, "grow": 0.12})
		for sx in [-1.0, 1.0]:
			FutonLib.follow(pj, pr, 0.035, 16, WHITE, {"offset": Vector3(sx * 1.5, 0.0, 0.35)})
		for i in 5:
			var pth = _gust_path(from, ad, randf_range(4.0, 7.0), FutonLib.side_of(ad), Vector3.UP, randf_range(-0.8, 0.8), randf_range(-0.3, 0.4), 1.0 if randf() < 0.5 else -1.0)
			FutonLib.line(pj, FutonLib.path_pts(pth, 10), 0.05, 0.3, WHITE, {"grow": 0.5}))
	Sfx.play("wind", from, 1.8, 0.6)


static func _kazekiri_cut(pj: PathJutsu, p: Vector3) -> void:
	var n = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()
	var y0 = n.cross(Vector3.UP).normalized()
	if y0.length() < 0.1:
		y0 = Vector3.RIGHT
	for k in 2:
		var dir = y0.rotated(n, PI * 0.25 + k * PI * 0.5)
		FutonLib.blade(pj, p - dir * 0.4, FutonLib.blade_basis(dir, n), 2.2, 0.22, WHITE, {"vel": dir * 4.0, "thick": 0.12, "wisp": 1.0, "grow": 0.15, "delay": k * 0.04})
	FutonLib.warp(pj, p, 0.3, 2.0, 0.25, {"power": 1.3})
	_debris(pj, p, 5, {"life": 0.6, "radius": 0.3, "dir": Vector3.UP, "spread": 90.0, "vmin": 4.0, "vmax": 8.0, "spin": 700.0})
	GroundFX.wind(p, 3.0)   # eski isabetin oyun etkisi: rüzgâr yanan zemini büyütür


# ================================================================== 6. Fūton: Fūjin no Jutsu (Toz Bulutu)
## Ref: ağızdan çıkan kalın, gri, sıkı toz seli hedefe uzanır. Görünüş: ağızdan dar başlayıp genişleyen yoğun gri-bej toz perdeleri,
## sel boyunca savrulan toz, ardından alanı kaplayan, ağır ağır dönen iki tonlu cel toz bulutu (içindekiler göremez).
static func futon_fujin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d = pj.fwd(c, t)
	var at = c.global_position + d * 8.0
	var mo = pj._mouth_pos(c)
	Dangle.gust(mo + d * 5.0, d * 28.0, 6.0, 0.7)
	var dc = FutonLib.ground_col(at)
	var tint = Color(lerpf(DUST_GREY.r, dc.r, 0.4), lerpf(DUST_GREY.g, dc.g, 0.4), lerpf(DUST_GREY.b, dc.b, 0.4), 0.95)
	var side = FutonLib.side_of(d)
	var gy = Game.jutsu_floor_at(at).y
	for i in 5:
		var s0 = randf_range(-0.5, 0.5)
		var ph = randf() * TAU
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var p = mo + d * 11.0 * u + side * (s0 * u * 3.0 + sin(u * 4.0 + ph) * 0.25)
			p.y = lerpf(mo.y, gy + 0.9, u * u)
			return p, 18)
		var wd = PackedFloat32Array()
		for j in 18:
			wd.append(lerpf(0.1, 1.0, float(j) / 17.0))
		FutonLib.sheet(pj, pts, 1.6, 0.95, tint, {"widths": wd, "opacity": 0.95, "lines": 6.0, "flow": 5.0, "grow": 0.45, "delay": i * 0.04})
	var bas = Basis.looking_at(d, Vector3.UP)
	FutonLib.bits(pj, mo + d * 4.0 + Vector3.DOWN * 0.4, 18, "puff", {"life": 0.9, "size": 0.9, "box": Vector3(0.5, 0.3, 3.0), "basis": bas, "dir": Vector3.FORWARD, "spread": 12.0, "vmin": 8.0, "vmax": 13.0,
		"damp": 2.5, "g": Vector3(0, -0.5, 0), "grow": [0.4, 1.8], "spin": 40.0, "cols": FutonLib.dust_cols(at, 0.85)})
	for k in 6:
		pj.after(0.2 + k * 0.1, func():
			FutonLib.bits(pj, at + Vector3(randf_range(-4, 4), 0.8, randf_range(-4, 4)), 14, "puff", {"life": 4.0, "size": 3.2, "radius": 2.5, "vmin": 0.3, "vmax": 1.2, "dir": Vector3.UP, "spread": 70.0,
				"g": Vector3(0, -0.05, 0), "tang": 0.6, "damp": 0.6, "grow": [0.5, 1.4], "spin": 20.0, "burst": 0.6, "cols": FutonLib.dust_cols(at, 0.92)}))
	# bulutun içinde alçak, ağır dönen toz çizgileri
	for i in 4:
		FutonLib.line(pj, FutonLib.helix_pts(pj.gp(at), Vector3.UP, 6.5, 5.0, 0.4, 1.4, randf() * TAU, 0.6, 22), 0.08, 2.2, Color(dc.r, dc.g, dc.b, 0.85), {"delay": 0.3 + i * 0.25, "grow": 0.5, "flow": 2.0})
	FutonLib.scour(pj, at, d, 9.0, 9.0, 4.5, 1)
	pj.every(4.0, 0.5, func(_i, _k):
		for e in pj.enemies_near(c, at, 8.0):
			pj.st(e, "slow", 1.0)
			if e.has_method("lose_target"):
				e.lose_target(1.5), Callable())
	Sfx.play("wind", c.global_position, 0.8)


# ================================================================== 7. Jūha Shō (Canavar Yırtan Avuç)
## Ref: kullanıcının çevresinde yatay dönen, üst kenarı tırtıklı parlak mavi pençe hilali. Görünüş: üç dalga halinde etrafında
## dönerek dışa savrulan tırtıklı mavi hilaller, yükselen mavi sarmal çizgiler, zeminde pençe yarıkları, savrulan toz/yaprak.
static func juha_sho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var at = c.global_position
	for k in 3:
		pj.after(k * 0.3, func():
			var a0 = randf() * TAU
			for i in 3:
				var a = a0 + i * TAU / 3.0
				var r = 1.8 + k * 0.6
				var pos = at + Vector3(cos(a), 0.0, sin(a)) * r + Vector3.UP * (0.7 + i * 0.4)
				var tng = Vector3(-sin(a), 0.0, cos(a))
				FutonLib.blade(pj, pos, FutonLib.blade_basis(tng, Vector3.UP.rotated(tng, randf_range(-0.3, 0.3))), 3.0 + k * 0.5, 0.4, FutonLib.BLUE,
					{"jag": 1.0, "thick": 0.26, "wisp": 1.4, "grow": 0.2, "vel": tng * 10.0 + Vector3(cos(a), 0.0, sin(a)) * 3.5, "delay": i * 0.04})
			for i in 3:
				FutonLib.line(pj, FutonLib.helix_pts(at, Vector3.UP, 1.0, 4.0, 0.2, 4.6, a0 + i * 2.1, 1.1, 20), 0.07, 0.5, PALE_BLUE, {"delay": i * 0.03, "grow": 0.5})
			FutonLib.scour(pj, at, Vector3(cos(a0), 0.0, sin(a0)), 5.0 + k, 5.0 + k, 3.0, 2))
	pj.every(1.2, 0.15, func(_i, _k):
		if _i % 2 == 0:
			_debris(pj, FutonLib.floor_at(at) + Vector3.UP * 0.3, 4, {"life": 0.8, "radius": 2.0, "dir": Vector3.UP, "spread": 40.0, "vmin": 3.0, "vmax": 8.0, "tang": 30.0, "g": Vector3(0, -3.0, 0), "spin": 700.0})
		pj.hit(c, at + Vector3.UP * 1.2, 3.8, pj.inf(c, "juha_sho", 0.12, {"knock": 9.0, "launch": 6.0, "kind": "light", "element": "fuuton"})), Callable())
	Sfx.play("wind", at, 0.7)


# ================================================================== 8. Fūjinheki (Hızlı Rüzgâr Duvarı)
## Ref: kullanıcıyı saran, kat kat dönen lavanta-beyaz geniş rüzgâr bantları. Görünüş: gövdeye bağlı, aralıklı (kabuk değil)
## lavanta perdeler sürekli yenilenerek döner; zeminde ışınsal iz; saptırılan mermide basınç patlaması + kaçan çizgiler.
static func fujinheki(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var root = Node3D.new()
	c.add_child(root)
	root.scale = Vector3.ONE * 0.1
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.2)
	tw.tween_interval(3.8)
	tw.tween_property(root, "scale", Vector3.ONE * 1.4, 0.2)
	tw.tween_callback(root.queue_free)
	FutonLib.scour(pj, pj.gp(c.global_position), Vector3.FORWARD, 5.0, 5.0, 3.0, 1)
	FutonLib.bits(pj, pj.gp(c.global_position) + Vector3.UP * 0.2, 14, "puff", {"life": 0.9, "size": 0.9, "radius": 2.0, "dir": Vector3.UP, "spread": 20.0, "vmin": 1.0, "vmax": 2.5,
		"tang": 16.0, "g": Vector3(0, -0.5, 0), "grow": [0.6, 1.4], "cols": FutonLib.dust_cols(c.global_position, 0.6)})
	pj.every(4.0, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		if _i % 3 == 0 and is_instance_valid(root):
			for j in 3:
				var a0 = randf() * TAU
				var h0 = randf_range(-0.1, 1.7)
				var dirn = 1.0 if j % 2 == 0 else -1.0
				FutonLib.sheet(pj, FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 2.3, 2.1, h0, h0 + randf_range(0.3, 0.8), a0, randf_range(0.45, 0.7) * dirn, 18), 0.55, 0.6, FutonLib.LAV,
					{"parent": root, "opacity": 0.6, "lines": 5.0, "flow": 4.0, "grow": 0.5})
			var a1 = randf() * TAU
			FutonLib.line(pj, FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 2.45, 2.35, randf_range(0.0, 2.0), randf_range(0.5, 2.6), a1, 0.6, 16), 0.05, 0.4, WHITE, {"parent": root, "grow": 0.5})
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position) < 3.0:
				_deflect_pop(pj, p.global_position, FutonLib.LAV)
				p.queue_free()
		for e in pj.enemies_near(c, c.global_position, 2.8):
			if e.get("velocity") != null:
				e.velocity += (e.global_position - c.global_position).normalized() * 6.0, Callable())
	if c is Player:
		Buffs.add("fujinheki", 4.0, {"armor": 0.6, "_name": "Rüzgâr Duvarı"})
	Sfx.play("wind", c.global_position, 0.9)


## Saptırılan mermi: basınç patlaması + dışa kaçan kısa çizgiler
static func _deflect_pop(host: Node, p: Vector3, tint: Color) -> void:
	FutonLib.warp(host, p, 0.2, 1.5, 0.22, {"power": 1.4})
	_radial_lines(host, p, 1.4, 6, 0.04, 0.25, tint)


# ================================================================== 9. Fūton: Hanachiri Mai (Çiçek Saçan Dans)
## Ref: kıvrılarak ilerleyen bej-pembe rüzgâr tüpü, başında savrulan saçak çizgiler, tüp boyunca saçılan beyaz-pembe çiçek yaprakları.
## Görünüş: hedefe doğru burgu çizerek uzanan sarmal perdeler (tüp), başında dışa kıvrılan saçak çizgiler, binlerce dönen yaprak;
## sonra havada süzülüp yere düşen yapraklar.
static func futon_hanachiri_mai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var o = c.global_position + Vector3.UP * 1.2
	Dangle.gust(o + d * 7.0, d * 28.0, 8.4, 0.7)
	var tube = Color(0.96, 0.86, 0.88, 0.95)
	for i in 5:
		FutonLib.sheet(pj, FutonLib.helix_pts(o, d, 0.5, 2.4, 0.0, 14.5, i * TAU / 5.0, 1.6, 28), 0.7, 1.0, tube, {"opacity": 0.55, "lines": 5.0, "grow": 0.55, "flow": 4.0, "delay": i * 0.02})
	var head = o + d * 14.0
	var sd = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	for i in 7:
		var a = TAU * i / 7.0
		var rd = (sd * cos(a) + up * sin(a))
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
			return head + rd * (1.8 + u * 2.4) + d * (u * 2.0 - u * u * 2.5) + rd.cross(d) * sin(u * PI) * 0.8, 12), 0.05, 0.7, Color(0.98, 0.9, 0.92, 0.95), {"delay": 0.35 + i * 0.03, "grow": 0.6})
	var petals = [Color(1.0, 0.7, 0.8, 1), Color(1.0, 0.92, 0.95, 1), Color(0.95, 0.55, 0.7, 1)]
	for k in 8:
		pj.after(k * 0.07, func():
			var q = c.global_position + Vector3.UP * 1.2 + d * (2.0 + k * 1.6)
			FutonLib.bits(pj, q, 40, "petal", {"life": 1.3, "size": 0.2, "radius": 1.2 + k * 0.3, "vmin": 6.0, "vmax": 12.0, "dir": d, "spread": 55.0, "damp": 1.5,
				"g": Vector3(0, -0.8, 0), "tang": 8.0, "spin": 540.0, "cols": [petals[k % 3], petals[(k + 1) % 3], Color(1, 0.9, 0.92, 0)]})
			pj.hit(c, q, 2.0 + k * 0.2, pj.inf(c, "futon_hanachiri_mai", 0.18, {"knock": 3.0, "kind": "light", "element": "fuuton", "bleed": 1.0})))
	pj.after(0.9, func():
		FutonLib.bits(pj, o + d * 9.0 + Vector3.UP * 1.0, 50, "petal", {"life": 3.5, "size": 0.18, "box": Vector3(4.0, 1.5, 4.0), "vmin": 0.2, "vmax": 1.0, "dir": d, "spread": 180.0,
			"damp": 1.2, "g": Vector3(0, -0.7, 0), "spin": 220.0, "burst": 0.3, "cols": [Color(1.0, 0.8, 0.88, 1), Color(1.0, 0.9, 0.94, 1), Color(1.0, 0.85, 0.9, 0)]}))
	Sfx.play("wind", c.global_position, 1.1)


# ================================================================== 10. Fūton: Renkūdan (Hava Mermisi)
## Kanon (Zabuza / Danzō): göğse çekilen hava ağızda sıkıştırılıp tek top olarak fırlatılır. Görünüş: ağza doğru akan çizgiler +
## içe çöken basınç; mermi = arkasını büken sıkışmış vakum topu + etrafında dönen sıkıştırma halkaları + burgu iz;
## çarpınca iki katlı basınç halkası, ışınsal çizgiler, yerde ışınsal iz, toz, fırlayan kaya.
static func futon_renkudan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 30.0)
	var mo = pj._mouth_pos(c)
	for i in 8:
		var a = TAU * i / 8.0
		var p0 = mo + Vector3(cos(a), sin(a) * 0.6 + 0.2, sin(a)) * 3.0
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
			return p0.lerp(mo, u) + Vector3(cos(a + 1.6), 0.0, sin(a + 1.6)) * sin(u * PI) * 0.6, 10), 0.05, 0.38, WHITE, {"delay": i * 0.02, "grow": 0.75})
	FutonLib.warp(pj, mo, 1.6, 0.25, 0.4, {"ring": false, "power": -1.6, "swirl": 2.0})
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var ball = Node3D.new()
		var pr = pj.shot(c, pj._mouth_pos(c), pj.aim_at(c, tt, pj._mouth_pos(c)), 30.0, ball, pj.inf(c, "futon_renkudan", 1.0, {"knock": 18.0, "launch": 4.0, "kind": "heavy", "element": "fuuton"}), tt, false, 1.6, func(p, _h):
			_renku_burst(pj, p)
			pj.hit(c, p, 5.0, pj.inf(c, "futon_renkudan", 0.5, {"knock": 14.0, "launch": 3.0, "kind": "heavy", "element": "fuuton"}))
			pj.shake(0.6))
		pr.radius = 1.4
		pr.homing_turn = 2.0
		FutonLib.warp(pj, Vector3.ZERO, 1.2, 1.35, 1.6, {"ring": false, "power": 2.4, "swirl": 1.8, "parent": ball, "grow": 0.1, "fade_from": 0.95, "glint": 0.6})
		for i in 4:
			var a = TAU * i / 4.0
			FutonLib.follow(pj, pr, 0.08, 18, WHITE, {"offset": Vector3(cos(a), sin(a), 0.0) * 1.0, "spin": 14.0})
		pj.every(1.5, 0.15, func(_i, _k):
			if not is_instance_valid(ball):
				return
			var nrm = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-0.4, 0.4)).normalized()
			FutonLib.line(pj, FutonLib.helix_pts(Vector3.ZERO, nrm, 1.15, 0.9, 0.0, 0.0, randf() * TAU, 0.85, 16), 0.05, 0.28, WHITE, {"parent": ball, "grow": 0.5, "flow": 8.0}), Callable()))
	Sfx.play("wind", c.global_position, 0.8)


static func _renku_burst(pj: PathJutsu, p: Vector3) -> void:
	FutonLib.warp(pj, p, 0.5, 8.0, 0.5, {"power": 2.6, "glint": 0.6})
	FutonLib.warp(pj, p, 0.5, 5.0, 0.45, {"power": 1.6, "delay": 0.08})
	_radial_lines(pj, p, 7.0, 20, 0.1, 0.5)
	var g = FutonLib.floor_at(p)
	if p.y - g.y < 7.0:
		FutonLib.scour(pj, g, Vector3.FORWARD, 9.0, 9.0, 3.0, 1)
		FutonLib.bits(pj, g + Vector3.UP * 0.3, 18, "puff", {"life": 1.2, "size": 1.4, "radius": 1.2, "dir": Vector3.UP, "spread": 88.0, "vmin": 8.0, "vmax": 14.0, "damp": 3.0,
			"g": Vector3(0, -0.4, 0), "grow": [0.6, 1.6], "spin": 40.0, "cols": FutonLib.dust_cols(g, 0.8)})
		_debris(pj, g + Vector3.UP * 0.3, 10, {"life": 1.0, "radius": 1.0, "dir": Vector3.UP, "spread": 70.0, "vmin": 7.0, "vmax": 12.0, "spin": 700.0})
		FutonLib.chunks(pj, g, 4, 7.0, FutonLib.ground_col(g).darkened(0.35), 0.3)
	GroundFX.wind(p, 7.0)   # eski isabetin oyun etkisi: rüzgâr yanan zemini büyütür


# ================================================================== 11. Fūsajin no Jutsu (Kum Tozu)
## Görünüş (kaynaksız, kanon: kum-toz perdesiyle görüşü kapatma): kullanıcının çevresinde yerden kalkıp yavaşça dönen iki tonlu
## kum-toz bulutu, içinde alçak hızlı dönen çakıl ve kum çizgileri, zeminde dairesel süpürülmüş iz. Fūjin'den ayrı: ileri sel değil,
## kullanıcı merkezli dönen girdap.
static func fusajin_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var at = pj.gp(c.global_position)
	var dc = FutonLib.ground_col(at)
	pj.every(4.0, 0.25, func(_i, _k):
		FutonLib.bits(pj, at + Vector3.UP * 0.4, 9, "puff", {"life": 1.6, "size": 2.4, "radius": 6.0, "vmin": 1.0, "vmax": 3.0, "dir": Vector3.UP, "spread": 60.0,
			"tang": 6.0, "g": Vector3(0, -0.3, 0), "damp": 0.8, "grow": [0.6, 1.3], "spin": 30.0, "burst": 0.3,
			"cols": [Color(dc.r, dc.g, dc.b, 0.0), Color(dc.r, dc.g, dc.b, 0.78), Color(dc.r * 0.93, dc.g * 0.93, dc.b * 0.93, 0.6), Color(dc.r, dc.g, dc.b, 0.0)]})
		if _i % 2 == 0:
			var gc = dc.darkened(0.3)
			FutonLib.bits(pj, at + Vector3.UP * 0.5, 10, "grit", {"life": 1.0, "size": 0.09, "radius": 4.5, "vmin": 2.0, "vmax": 4.0, "dir": Vector3.UP, "spread": 50.0,
				"tang": 24.0, "g": Vector3(0, -2.0, 0), "spin": 600.0, "turb": false, "cols": [gc, gc, Color(gc.r, gc.g, gc.b, 0.0)]})
		for e in pj.enemies_near(c, at, 7.0):
			if pj.live(e):
				if e.has_method("lose_target"):
					e.lose_target(1.0)
				if e.has_method("apply_status"):
					e.apply_status("slow", 0.6), Callable())
	var lc = Color(minf(1.0, dc.r * 1.08), minf(1.0, dc.g * 1.08), minf(1.0, dc.b * 1.08), 0.9)
	for i in 6:
		FutonLib.line(pj, FutonLib.helix_pts(at, Vector3.UP, 5.0, 4.0, 0.3, 2.4, randf() * TAU, 0.9, 22), 0.07, 0.8, lc, {"delay": i * 0.08, "grow": 0.5})
	for i in 2:
		FutonLib.sheet(pj, FutonLib.helix_pts(at, Vector3.UP, 4.6, 4.2, 0.4, 1.6, i * PI, 0.7, 20), 1.0, 0.9, Color(dc.r, dc.g, dc.b, 0.95), {"opacity": 0.6, "lines": 4.0, "grow": 0.5, "delay": 0.1})
	FutonLib.scour(pj, at, Vector3.FORWARD, 12.0, 12.0, 4.5, 1, Color(dc.r * 0.82, dc.g * 0.82, dc.b * 0.82, 0.7), {"grow_t": 0.6})
	Sfx.play("wind", at, 0.7)


# ================================================================== 12. Fūton: Uzu (Girdap)
## Görünüş (kaynaksız): hedefin altında birden açılan dar, hızlı dönen küçük hortum — dipte sıkışan sarmal çizgiler, iki ince perde,
## yükselen yaprak / ot; içine giren havaya kalkar; sonunda hortum dağılırken yatay dışa kaçan çizgiler ve yerde basınç halkası.
static func futon_uzu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var tt = pj.tg(c, t, 22.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 8.0)
	for i in 6:
		FutonLib.line(pj, FutonLib.helix_pts(at, Vector3.UP, 0.35, 1.7, 0.1, 3.6, i * TAU / 6.0, 2.2, 26), 0.06, 0.9, WHITE, {"delay": i * 0.04, "grow": 0.5, "flow": 7.0})
	for i in 2:
		FutonLib.sheet(pj, FutonLib.helix_pts(at, Vector3.UP, 0.6, 1.4, 0.2, 3.0, randf() * TAU, 1.5, 22), 0.5, 1.0, FutonLib.AIR, {"opacity": 0.5, "lines": 3.0, "grow": 0.5, "delay": 0.05})
	_debris(pj, at + Vector3.UP * 0.2, 14, {"life": 1.2, "radius": 0.9, "dir": Vector3.UP, "spread": 18.0, "vmin": 3.0, "vmax": 6.0, "tang": 26.0, "g": Vector3(0, -1.0, 0), "spin": 700.0})
	FutonLib.scour(pj, at, Vector3.FORWARD, 4.8, 4.8, 2.0, 1)
	pj.after(0.2, func():
		for e in pj.enemies_near(c, at, 2.4):
			if not pj.live(e):
				continue
			pj._wind_lift(c, e, 3.0, 0.8)
			pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "futon_uzu", 0.9, {"knock": 2.0, "launch": 4.0, "kind": "heavy", "element": "fuuton"})))
	pj.after(1.0, func():
		var q = at + Vector3.UP * 0.3
		_radial_lines(pj, q, 2.5, 10, 0.06, 0.35, WHITE, true)
		FutonLib.warp(pj, q, 0.3, 2.8, 0.3, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.4})
		GroundFX.wind(q, 2.5))   # eski dağılma patlamasının oyun etkisi: rüzgâr yanan zemini büyütür
	Sfx.play("wind", at, 1.2)


# ================================================================== 13. Kazanami (Rüzgâr Dalgaları)
## Ref (Danzō'nun yüzünü yaran hava): görünmez havanın arkasını büken keskin dalga. Görünüş: yere vurulan avuçtan halka halka
## yayılan, zemine yatık basınç halkaları (arkasındaki görüntü bükülür), halka önünde yerde süpürülen alçak yay çizgileri,
## dalga cephesinde kalkan ot / yaprak.
static func kazanami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var hp = pj.hand_pos(c, true)
	for i in 5:
		var a = TAU * i / 5.0
		var p0 = hp + Vector3(cos(a), 0.6, sin(a)) * 1.2
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3: return p0.lerp(hp, u), 6), 0.04, 0.24, WHITE, {"delay": i * 0.02, "grow": 0.7})
	pj.after(0.25, func():
		if not pj.live(c):
			return
		var at = pj.gp(c.global_position) + Vector3.UP * 0.4
		for k in 3:
			pj.after(k * 0.16, func():
				var R = 5.0 + k * 3.0
				_kaza_ring(pj, at, R, k == 0)
				GroundFX.wind(at, R)   # eski halka patlamasının oyun etkisi: rüzgâr yanan zemini büyütür
				for e in pj.enemies_near(c, at, R):
					if pj.live(e):
						var v = e.global_position - at
						v.y = 0
						pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "kazanami", 0.35, {"knock": 9.0, "launch": 1.0, "kind": "heavy", "element": "fuuton", "dir": v.normalized()})))
		pj.shake(0.4)
		Sfx.play("wind", at, 0.9))


static func _kaza_ring(pj: PathJutsu, at: Vector3, R: float, first: bool) -> void:
	var g = FutonLib.floor_at(at)
	FutonLib.warp(pj, g + Vector3.UP * 0.25, 0.5, R, 0.45, {"bill": false, "basis": FutonLib.flat_basis(), "power": 2.0, "band": 0.1, "glint": 0.5})
	FutonLib.warp(pj, at + Vector3.UP * 0.6, 0.4, R * 0.6, 0.35, {"power": 1.2, "band": 0.12})
	var a0 = randf() * TAU
	for i in 12:
		var a = a0 + TAU * i / 12.0
		var arc = randf_range(0.25, 0.45)
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
			var aa = a + (u - 0.5) * arc
			return g + Vector3(cos(aa), 0.0, sin(aa)) * R * lerpf(0.55, 1.0, u) + Vector3.UP * (0.15 + sin(u * PI) * 0.25), 10), 0.07, 0.4, WHITE, {"grow": 0.6, "hint": Vector3.UP, "twin": true})
	if first:
		FutonLib.scour(pj, g, Vector3.FORWARD, R * 2.0, R * 2.0, 2.5, 1)
	var kind_leaf = FutonLib.has_leaves(g)
	var cols = FutonLib.leaf_cols(g) if kind_leaf else [FutonLib.ground_col(g).darkened(0.2), FutonLib.ground_col(g).darkened(0.2), Color(0.5, 0.45, 0.4, 0.0)]
	FutonLib.bits(pj, g + Vector3.UP * 0.2, 22, "grass" if kind_leaf else "grit", {"life": 0.7, "size": 0.22, "radius": R * 0.5, "dir": Vector3.UP, "spread": 70.0,
		"vmin": 3.0, "vmax": 6.0, "radial": R * 2.0, "g": Vector3(0, -8.0, 0), "spin": 500.0, "cols": cols})


# ================================================================== 14. Daikamaitachi no Jutsu (Büyük Orak Gelincik)
## Ref (Temari): her şeyi yutan gri-beyaz dev fırtına, içinde kıvrılan perdeler, savrulan kaya. Görünüş: geniş göğüste toplanan
## çizgiler → 30 m boyunca kalın gri-beyaz perdeler + yuvarlanan sarmal çizgiler, içinde rastgele yükseklikte yirmi orak hilali
## alanı keser, her kesikte zeminde yarık; 12 m'de kalkan toz duvarı ve fırlayan kayalar.
static func daikamaitachi_no_jutsu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.1)
	pj.anim(c, "slash_c", 1.0)
	var d = pj.fwd(c, t)
	var cp = c.global_position + Vector3.UP * 1.5
	for i in 10:
		var a = TAU * i / 10.0
		var p0 = cp + Vector3(cos(a), sin(a) * 0.7 + 0.3, sin(a)) * 4.5
		FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
			return p0.lerp(cp, u) + Vector3(cos(a + 1.5), 0.0, sin(a + 1.5)) * sin(u * PI) * 1.0, 12), 0.06, 0.32, WHITE, {"delay": i * 0.012, "grow": 0.75})
	FutonLib.warp(pj, cp, 2.5, 0.4, 0.25, {"ring": false, "power": -1.4, "swirl": 1.6})
	pj.after(0.2, func():
		var o = c.global_position + Vector3.UP * 1.4
		Dangle.gust(o + d * 15.0, d * 28.0, 20.0, 0.7)
		var side = FutonLib.side_of(d)
		var gy = Game.jutsu_floor_at(o).y
		for i in 9:
			var s0 = lerpf(-1.0, 1.0, (i + 0.5) / 9.0)
			var u0 = randf_range(-0.2, 0.9)
			var ph = randf() * TAU
			var pts = FutonLib.path_pts(func(u: float) -> Vector3:
				var spread = lerpf(0.15, 1.0, u) * 9.0
				var p = o + d * 30.0 * u + side * (s0 * spread + cos(u * 5.0 + ph) * 1.2) + Vector3.UP * (u0 * spread * 0.4 + sin(u * 5.0 + ph) * 1.2)
				p.y = maxf(p.y, gy + 0.5)
				return p, 20)
			var wd = PackedFloat32Array()
			for j in 20:
				wd.append(lerpf(0.2, 1.0, float(j) / 19.0))
			FutonLib.sheet(pj, pts, 2.6, randf_range(1.1, 1.4), STORM_GREY, {"widths": wd, "opacity": 0.65, "lines": 6.0, "flow": 5.0, "grow": 0.4, "delay": randf() * 0.1})
		for i in 6:
			FutonLib.line(pj, FutonLib.helix_pts(o + side * randf_range(-3.0, 3.0), d, 1.5, 4.5, 0.0, 28.0, randf() * TAU, 2.2, 36), 0.09, 1.0, WHITE, {"delay": i * 0.05, "grow": 0.5, "flow": 7.0})
		for k in 20:
			pj.after(k * 0.03, func():
				var q = c.global_position + d * (3.0 + k * 1.4) + d.cross(Vector3.UP) * randf_range(-6.0, 6.0)
				var roll = randf_range(-0.8, 0.8)
				FutonLib.blade(pj, q + Vector3.UP * randf_range(0.4, 4.0), FutonLib.blade_basis(d, Vector3.UP.rotated(d, roll)), 4.0, 0.34, WHITE,
					{"vel": d * 14.0, "thick": 0.16, "wisp": 1.6, "grow": 0.3})
				GroundFX.add(pj.gp(q), "cracked", 1.2, 5.0)   # eski zemin çatlağının oyun etkisi: yarık zemin üstünden geçeni yavaşlatır
				FutonLib.scour(pj, pj.gp(q), d.rotated(Vector3.UP, PI * 0.5 + randf_range(-0.4, 0.4)), 3.0, 3.0, 4.5, 2))
		var w12 = pj.gp(c.global_position + d * 12.0)
		FutonLib.bits(pj, w12 + Vector3.UP * 0.4, 30, "puff", {"life": 2.2, "size": 2.6, "radius": 3.0, "dir": Vector3.UP, "spread": 80.0, "vmin": 3.0, "vmax": 7.0, "radial": 6.0,
			"damp": 1.5, "g": Vector3(0, -0.3, 0), "grow": [0.5, 1.6], "spin": 30.0, "cols": FutonLib.dust_cols(w12, 0.88)})
		FutonLib.scour(pj, w12, d, 24.0, 24.0, 4.0, 1)
		FutonLib.chunks(pj, w12, 7, 9.0, FutonLib.ground_col(w12).darkened(0.35), 0.45, d + Vector3.UP)
		_debris(pj, w12 + Vector3.UP * 0.5, 24, {"life": 1.6, "radius": 4.0, "dir": (d + Vector3.UP * 0.5).normalized(), "spread": 40.0, "vmin": 10.0, "vmax": 20.0, "spin": 800.0, "g": Vector3(0, -3.0, 0)})
		Combat.hit_zone(c, c.global_position, d, 32.0, 40.0, 6.0, pj.inf(c, "daikamaitachi_no_jutsu", 2.0, {"knock": 26.0, "launch": 6.0, "kind": "heavy", "element": "fuuton", "bleed": 5.0, "dir": d}))
		pj.shake(1.0))
	Sfx.play("wind", c.global_position, 0.4)


# ================================================================== 15. Fūton: Fūhakujun (Rüzgâr Kalkanı)
## Görünüş (kaynaksız): kullanıcının önünde dikilen görünmez basınç levhası — arkasındaki görüntü girdap gibi bükülür, levha
## düzleminde merkeze sarmallanan lavanta çizgiler, kenarda kısa lavanta hilal kıvılcımları; saptırılan mermide basınç patlaması.
static func futon_fuhakujun(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var _d = pj.fwd(c, t)
	var root = Node3D.new()
	c.add_child(root)
	root.position = Vector3(0, 1.1, 1.4)
	FutonLib.warp(pj, Vector3.ZERO, 0.3, 1.25, 4.3, {"ring": false, "bill": false, "aspect": Vector3(1.4, 1.2, 1.0), "power": 1.3, "swirl": 1.4, "parent": root,
		"grow": 0.05, "fade_from": 0.93, "glint": 0.35})
	var tw = root.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(root, "scale", Vector3(1.0, 1.0, 0.01), 0.3)
	tw.tween_callback(root.queue_free)
	pj.every(4.0, 0.1, func(_i, _k):
		if not pj.live(c):
			return
		if _i % 2 == 0 and is_instance_valid(root):
			var a0 = randf() * TAU
			var sg = 1.0 if randf() < 0.5 else -1.0
			FutonLib.line(pj, FutonLib.path_pts(func(u: float) -> Vector3:
				var aa = a0 + sg * u * PI * 1.3
				var r = lerpf(2.6, 0.5, u)
				return Vector3(cos(aa) * r * 1.2, sin(aa) * r, 0.0), 16), 0.05, 0.5, FutonLib.LAV, {"parent": root, "hint": Vector3(0, 0, 1), "twin": false, "grow": 0.5, "flow": 6.0})
		if randf() < 0.4 and is_instance_valid(root):
			var ea = randf() * TAU
			var ep = Vector3(cos(ea) * 2.4, sin(ea) * 2.0, 0.0)
			FutonLib.blade(pj, ep, FutonLib.blade_basis(Vector3(-sin(ea), cos(ea), 0.0), Vector3(0, 0, 1)), 0.8, 0.18, FutonLib.LAV, {"parent": root, "thick": 0.14, "wisp": 0.6})
		for p in pj.get_tree().get_nodes_in_group("projectiles"):
			if p.get("shooter") != c and p.global_position.distance_to(c.global_position + c.face_dir() * 1.4 + Vector3.UP) < 2.6:
				_deflect_pop(pj, p.global_position, FutonLib.LAV)
				p.queue_free(), Callable())
	if c is Player:
		Buffs.add("fuhakujun", 4.0, {"armor": 0.5, "_name": "Rüzgâr Kalkanı"})
	Sfx.play("wind", c.global_position, 1.0)
