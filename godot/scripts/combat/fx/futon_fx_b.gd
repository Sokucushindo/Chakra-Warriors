class_name FutonFXB
extends RefCounted
## Fūton grubu B: on beş rüzgâr tekniğinin görselleri. Malzeme ve yapı taşları FutonLib'den (akım çizgisi, hava perdesi, kesici hilal,
## basınç bükülmesi, zemin izi, savrulan toz / yaprak / çakıl, hava küresi); hepsi kameraya yakın söner. Katı koni / kubbe / kabuk yok.
## Her tekniğin şekli / hareketi / sahnelenmesi bu dosyada ve birbirinden ayrı. Ortak efekt yardımcısı yok.
## Oynanış (hasar çağrıları, durumlar, süreler, menzil, hedefleme, mermi davranışı) ana ağaçtaki işleyicilerden satır satır taşındı;
## eski görsel çağrıların oyun etkileri (saç/kumaş savrulması, rüzgârın yanan zemini büyütmesi, yarık zemin) açıkça korunur.

const WHITE := Color(1.0, 1.0, 1.0, 0.95)
const CYAN := Color(0.5, 0.85, 1.0, 0.95)
const DEEP := Color(0.28, 0.52, 1.0, 0.95)
const GOLD := Color(1.0, 0.84, 0.48, 0.95)
const ROSE_SOFT := Color(0.95, 0.78, 0.72, 0.7)
const SAND_SOFT := Color(0.9, 0.84, 0.72, 0.8)
const SAND := Color(0.93, 0.8, 0.56, 0.95)
const BEAST := Color(0.4, 0.66, 1.0, 0.95)
const BEAST_HI := Color(0.75, 0.9, 1.0, 0.95)
const PALE := Color(0.86, 0.9, 0.95, 0.95)
const IRON := Color(0.2, 0.19, 0.21)
const IRON_EDGE := Color(0.3, 0.28, 0.3)
const PAPER := Color(0.95, 0.93, 0.86)
const MOON := Color(0.56, 0.34, 0.66)

static var _mc := {}


# ================================================================== küçük ortak işler (yalnız bu grup)
## Zemine göre savrulan parça: yeşil yerde yaprak, çöl / kar / kayada çakıl
static func _kick(pj: PathJutsu, p: Vector3, n: int, dir: Vector3, vmin: float, vmax: float, extra := {}) -> void:
	var g = FutonLib.floor_at(p)
	var o = {"dir": dir, "spread": 40.0, "vmin": vmin, "vmax": vmax, "life": 1.2, "radius": 0.6}
	o.merge(extra, true)
	if FutonLib.has_leaves(g):
		o["cols"] = FutonLib.leaf_cols(g)
		o["size"] = float(extra.get("size", 0.2))
		FutonLib.bits(pj, p, n, "leaf", o)
	else:
		var dc = FutonLib.ground_col(g).darkened(0.3)
		o["cols"] = [dc, dc, Color(dc.r, dc.g, dc.b, 0.0)]
		o["size"] = float(extra.get("size", 0.2)) * 0.6
		o["g"] = Vector3(0, -12.0, 0)
		FutonLib.bits(pj, p, n, "grit", o)


## Kameraya yakın sönme mesafesini büyüt (geniş perdeler ekranı kaplamasın): near'ın %35'inden yakında tamamen saydam
static func _far(mi: GeometryInstance3D, near := 9.0) -> GeometryInstance3D:
	if is_instance_valid(mi):
		mi.set_instance_shader_parameter("near", near)
	return mi


## Çağırandan bağımsız gecikme (salt görsel ardıl iz için)
static func _later(pj: PathJutsu, sec: float, fn: Callable) -> void:
	pj.get_tree().create_timer(sec).timeout.connect(fn)


## d'ye dik düzlemde yüzü d'ye bakan taban (warp düzlemi için; yerel Z = -d)
static func _face_basis(d: Vector3) -> Basis:
	var sd = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	return Basis(sd, up, -d.normalized())


## Düz çizgi yolu
static func _seg(a: Vector3, b: Vector3, n := 6) -> PackedVector3Array:
	return FutonLib.path_pts(func(u: float) -> Vector3: return a.lerp(b, u), n)


## Parıltı yıldızı: d'ye dik düzlemde kesişen kısa çizgiler
static func _glint(pj: PathJutsu, p: Vector3, d: Vector3, L: float, tint: Color, life := 0.22) -> void:
	var sd = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	for j in 4:
		var a = j * PI * 0.25
		var ax = sd * cos(a) + up * sin(a)
		var l2 = L if j % 2 == 0 else L * 0.55
		FutonLib.line(pj, _seg(p - ax * l2, p + ax * l2, 5), 0.05 if j % 2 == 0 else 0.03, life, tint, {"grow": 0.3})


# ================================================================== 1. Fūton: Senpūken (Kasırga Yumruk)
## Ref: yumruğu saran parlak camgöbeği girdap, koyu mavi dış bant, ileri burgulanan akım.
## Görünüş: hazırlıkta yumruğun çevresinde dönen mavi sarmal + avuçta vakum bükülmesi → vuruşta ileri delen dört kollu burgu
## (iç parlak çekirdek çizgisi, dış koyu mavi perde sarmalı) → çarpınca fırıldak gibi dışa kıvrılan çizgiler ve bükülme halkası.
static func futon_senpuken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	_senpuken_wind_up(pj, c, 0.6)
	pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.6)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var d = c.face_dir()
		var at = c.global_position + Vector3.UP * 1.2 + d * 1.3
		Dangle.gust(at + d * 3.0, d * 28.0, 3.6, 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
		_senpuken_drill(pj, at - d * 0.5, d)
		var hs = pj.hit(c, at, 2.0, pj.inf(c, "futon_senpuken", 1.4, {"knock": 20.0, "launch": 5.0, "kind": "heavy", "element": "fuuton"}))
		if not hs.is_empty():
			_senpuken_burst(pj, hs[0].global_position + Vector3.UP * 1.0, d)
			pj.shake(0.72)
		pj.shake(0.62)
		Sfx.play("wind", at, 1.3))


static func _senpuken_wind_up(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba == null:
		return
	pj.free_after(dur + 0.5, ba)
	FutonLib.warp(pj, Vector3.ZERO, 0.15, 0.45, dur, {"ring": false, "swirl": 2.0, "power": 0.8, "parent": ba, "glint": 0.0})
	pj.every(dur, 0.1, func(_i, _k):
		if not is_instance_valid(ba):
			return
		for j in 2:
			var pts = FutonLib.helix_pts(Vector3(0, -0.12, 0), Vector3.UP, 0.32, 0.12, 0.0, 0.32, randf() * TAU + j * PI, 1.2, 14)
			FutonLib.line(pj, pts, 0.025, 0.3, CYAN if j == 0 else DEEP, {"parent": ba, "grow": 0.5, "flow": 8.0}))


static func _senpuken_drill(pj: PathJutsu, o: Vector3, d: Vector3) -> void:
	var dn = d.normalized()
	for j in 4:
		var pts = FutonLib.helix_pts(o, dn, 0.25, 1.0, 0.0, 6.0, j * TAU / 4.0, 2.5, 40)
		FutonLib.line(pj, pts, 0.05 if j % 2 == 0 else 0.035, 0.45, CYAN if j % 2 == 0 else WHITE, {"grow": 0.35, "flow": 9.0})
	for j in 2:
		var pts2 = FutonLib.helix_pts(o, dn, 0.4, 1.3, 0.3, 5.5, j * PI + 0.6, 1.6, 30)
		FutonLib.sheet(pj, pts2, 0.45, 0.5, DEEP, {"grow": 0.4, "opacity": 0.6, "lines": 3.0})
	FutonLib.line(pj, _seg(o, o + dn * 6.2, 8), 0.06, 0.3, FutonLib.AIR, {"grow": 0.3})
	FutonLib.warp(pj, o + dn * 5.5, 0.3, 1.6, 0.35, {"ring": false, "swirl": 3.0, "power": 1.2})


static func _senpuken_burst(pj: PathJutsu, p: Vector3, d: Vector3) -> void:
	var sd = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	for i in 8:
		var a0 = TAU * i / 8.0
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var a = a0 + u * 1.6
			var r = lerpf(0.3, 2.6, u)
			return p + (sd * cos(a) + up * sin(a)) * r + d * u * 0.8, 12)
		FutonLib.line(pj, pts, 0.05, 0.35, CYAN if i % 2 == 0 else FutonLib.AIR, {"grow": 0.4})
	FutonLib.warp(pj, p, 0.3, 2.4, 0.4, {"swirl": 2.5, "power": 1.6})


# ================================================================== 2. Nadeshiko-Ryū Kōha Reppūken (Kükreyen Fırtına Yumruğu)
## Ref: altın ışıkla parlayan yumruk, arkada manga hız çizgileri, sarımsı hava.
## Görünüş: hazırlıkta yumruktan geriye yalayan kısa altın çizgiler + elde sıcak ışık → vuruşta yumruğun etrafından geçen
## hız çizgisi tüneli, yumruğa dik bükülme halkası, öne savrulan toz ve taşlar, yerde süpürülmüş iz; çarpınca altın parıltı yıldızı.
static func nadeshiko_ryu_koha_reppuken(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	_gold_fist(pj, c, 0.45)
	pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.6)
	pj.after(0.25, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var d = c.face_dir()
		var at = c.global_position + Vector3.UP * 1.2 + d * 1.2
		Dangle.gust(at + d * 2.5, d * 28.0, 3.2, 0.7)   # yoldaki saç/kumaş savrulur
		GroundFX.wind(at + d * 1.2, 4.5)   # rüzgâr yanan zemini büyütür (eski patlamanın oyun etkisi)
		_speed_tunnel(pj, at, d)
		var hs = pj.hit(c, at, 2.0, pj.inf(c, "nadeshiko_ryu_koha_reppuken", 1.5, {"knock": 18.0, "kind": "heavy", "element": "fuuton"}))
		if not hs.is_empty():
			var hp = hs[0].global_position + Vector3.UP * 1.0
			_glint(pj, hp, d, 1.3, GOLD)
			FutonLib.warp(pj, hp, 0.2, 1.6, 0.3, {"power": 1.4})
			pj.shake(0.7)
		pj.shake(0.5)
		Sfx.play("punch", at, 0.9))


static func _gold_fist(pj: PathJutsu, c: Node3D, dur: float) -> void:
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		var li = OmniLight3D.new()
		li.light_color = Color(1.0, 0.82, 0.45)
		li.light_energy = 1.6
		li.omni_range = 2.2
		li.shadow_enabled = false
		ba.add_child(li)
		pj.free_after(dur + 0.3, ba)
	pj.every(dur, 0.06, func(_i, _k):
		if not pj.live(c):
			return
		var hp = pj.hand_pos(c, true)
		var back = -c.face_dir()
		for j in 2:
			var p0 = hp + Vector3(randf_range(-0.12, 0.12), randf_range(-0.08, 0.12), randf_range(-0.12, 0.12))
			var L = randf_range(0.4, 0.7)
			var cv = randf_range(-0.2, 0.2)
			var pts = FutonLib.path_pts(func(u: float) -> Vector3:
				return p0 + back * L * u + Vector3.UP * (u * u * 0.35) + FutonLib.side_of(back) * cv * u, 6)
			FutonLib.line(pj, pts, 0.03, 0.22, GOLD if j == 0 else WHITE, {"grow": 0.5}))


static func _speed_tunnel(pj: PathJutsu, at: Vector3, d: Vector3) -> void:
	var sd = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	for i in 18:
		var a = TAU * i / 18.0 + randf_range(-0.15, 0.15)
		var off = (sd * cos(a) + up * sin(a)) * randf_range(0.7, 2.3)
		var p0 = at - d * randf_range(2.0, 4.0) + off
		var p1 = at + d * randf_range(1.5, 4.5) + off * 0.6
		FutonLib.line(pj, _seg(p0, p1, 6), randf_range(0.02, 0.05), randf_range(0.22, 0.32), GOLD if i % 3 == 0 else WHITE,
			{"grow": 0.25, "delay": randf() * 0.05})
	FutonLib.warp(pj, at + d * 0.6, 0.3, 2.8, 0.4, {"bill": false, "basis": _face_basis(d), "power": 1.8})
	var g = FutonLib.floor_at(at + d * 2.0)
	FutonLib.bits(pj, g + Vector3.UP * 0.3, 10, "puff", {"dir": (d + Vector3.UP * 0.3).normalized(), "spread": 25.0, "vmin": 5.0, "vmax": 10.0,
		"size": 0.8, "cols": FutonLib.dust_cols(g), "life": 0.8, "damp": 3.0, "g": Vector3(0, -0.5, 0)})
	FutonLib.chunks(pj, g, 6, 8.0, FutonLib.ground_col(g).darkened(0.3), 0.22, d)
	FutonLib.scour(pj, FutonLib.floor_at(at), d, 4.5, 2.2, 2.5, 0)


# ================================================================== 3. Fūton: Fūjin no Ya (Rüzgâr Tanrısı Oku) — c_ işleyicisi taşındı
## Görünüş: yay bırakışında ele dik küçük bükülme halkası ve geri tepen kiriş çizgileri → sıkıştırılmış hava oku:
## ince parlak gövde iğnesi, uçta çift düzlemli ok başı, çevresinde helezon çizen üç nane rengi iz + soluk iz kuyruğu.
static func kazahana_fujin_ya(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	pj.every(0.6, 0.2, func(_i, _k):
		var d = Jutsu._aim(c, t)
		var from = Jutsu._hand(c)
		Dangle.gust(from + d * 13.0, d * 28.0, 15.6, 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
		var holder = Node3D.new()
		var pr = pj.shot(c, from, d, 60.0, holder, pj.inf(c, "kazahana_fujin_ya", 0.45, {"knock": 7.0, "kind": "heavy", "element": "fuuton"}), null, true, 1.0)
		_wind_arrow(pj, pr)
		_bow_release(pj, from, d)
		Sfx.play("wind", c.global_position, 2.0, 0.6))


static func _wind_arrow(pj: PathJutsu, pr: Node3D) -> void:
	FutonLib.fixed(pj, _seg(Vector3(0, 0, 1.6), Vector3(0, 0, -0.75), 10), 0.05, "line", WHITE, {"parent": pr, "flow": 12.0})
	var tip = Vector3(0, 0, -0.75)
	for ax in [Vector3.RIGHT, Vector3.UP]:
		for s in [-1.0, 1.0]:
			FutonLib.fixed(pj, _seg(Vector3(0, 0, -0.25) + ax * 0.2 * s, tip, 4), 0.025, "line", FutonLib.MINT, {"parent": pr})
	for j in 3:
		FutonLib.follow(pj, pr, 0.03, 10, FutonLib.MINT, {"offset": Vector3(0.16, 0, 0).rotated(Vector3.FORWARD, j * TAU / 3.0), "spin": 28.0})
	FutonLib.follow(pj, pr, 0.07, 14, FutonLib.AIR)


static func _bow_release(pj: PathJutsu, from: Vector3, d: Vector3) -> void:
	FutonLib.warp(pj, from + d * 0.3, 0.15, 1.1, 0.25, {"bill": false, "basis": _face_basis(d), "power": 1.2})
	var sd = FutonLib.side_of(d)
	var up = FutonLib.up_of(d)
	for i in 6:
		var a = TAU * i / 6.0
		var p0 = from + (sd * cos(a) + up * sin(a)) * 0.35
		FutonLib.line(pj, _seg(p0, p0 - d * randf_range(0.7, 1.1) + (sd * cos(a) + up * sin(a)) * 0.3, 5), 0.025, 0.2, FutonLib.MINT, {"grow": 0.4})


# ================================================================== 4. Fūton: Atsugai (Basınç Hasarı)
## Ref: hedefi saran dev, soluk yeşil-beyaz şişen hava topu; içinden kopan toz parçaları, kenarda kum yelpazeleri.
## Görünüş: ağza içe çekilen çizgiler → ağızdan hedefe uzanan kalın hava sütunu → hedefte içe sarmal çizgiler, emilen toz,
## büyüyen vakum bükülmesi (basınç toplanır) → 1.2 sn sonra üç katlı genişleyen küresel yay çizgileri (kubbe değil), dev bükülme
## halkası, zeminde ışınsal süpürme + yarıklar, kaya parçaları, halka toz dalgası.
static func futon_atsugai(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.2)
	var tt = pj.tg(c, t, 24.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0) + Vector3.UP * 1.5
	_atsugai_inhale(pj, pj._mouth_pos(c))
	pj.after(0.3, func():
		var mo = pj._mouth_pos(c)
		var dir = (at - mo).normalized()
		var L = mo.distance_to(at)
		Dangle.gust(mo + dir * L * 0.5, dir * 28.0, maxf(L * 0.6, 2.8), 0.7)   # yoldaki saç/kumaş savrulur
		_atsugai_breath(pj, mo, dir, L)
		_atsugai_gather(pj, at, 1.2)
		_later(pj, 1.2, func(): _atsugai_burst(pj, at))
		pj.every(1.0, 0.2, func(_i, _k):
			pj.hit(c, at, 5.0, pj.inf(c, "futon_atsugai", 0.4, {"knock": 8.0, "launch": 3.0, "kind": "heavy", "element": "fuuton"})), Callable())
		pj.shake(0.9))
	Sfx.play("wind", c.global_position, 0.4)


static func _atsugai_inhale(pj: PathJutsu, mo: Vector3) -> void:
	FutonLib.warp(pj, mo, 0.5, 0.1, 0.3, {"ring": false, "power": -1.0})
	for i in 10:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized()
		var p0 = mo + dv * randf_range(1.8, 2.8)
		var tg = dv.cross(Vector3.UP).normalized() * randf_range(-0.6, 0.6)
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return p0.lerp(mo, u) + tg * sin(u * PI), 8)
		FutonLib.line(pj, pts, 0.03, 0.3, WHITE if i % 2 == 0 else FutonLib.MINT, {"grow": 0.6, "delay": randf() * 0.06})


static func _atsugai_breath(pj: PathJutsu, mo: Vector3, dir: Vector3, L: float) -> void:
	var sd = FutonLib.side_of(dir)
	var up = FutonLib.up_of(dir)
	for i in 8:
		var a0 = TAU * i / 8.0
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var a = a0 + u * 1.2
			var r = lerpf(0.15, 1.3, u)
			return mo + dir * L * u + (sd * cos(a) + up * sin(a)) * r, 18)
		FutonLib.line(pj, pts, 0.045, 0.5, WHITE if i % 2 == 0 else FutonLib.MINT, {"grow": 0.45, "flow": 6.0})
	for j in 2:
		var b0 = j * PI
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3:
			var a = b0 + u * 0.8
			return mo + dir * L * u + (sd * cos(a) + up * sin(a)) * lerpf(0.1, 0.8, u), 16)
		FutonLib.sheet(pj, pts2, 0.6, 0.55, FutonLib.MINT, {"grow": 0.45, "opacity": 0.45, "widths": _widen(16, 0.4, 1.6)})


## Uca doğru genişleyen en dizisi
static func _widen(n: int, a: float, b: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	for i in n:
		out.append(lerpf(a, b, float(i) / float(maxi(n - 1, 1))))
	return out


static func _atsugai_gather(pj: PathJutsu, at: Vector3, dur: float) -> void:
	FutonLib.warp(pj, at, 0.6, 3.8, dur + 0.05, {"ring": false, "power": 2.2, "swirl": 1.5, "fade_from": 0.9, "glint": 0.5})
	var g = FutonLib.floor_at(at)
	FutonLib.bits(pj, g + Vector3.UP * 0.2, 14, "puff", {"box": Vector3(6.0, 0.2, 6.0), "radial": -10.0, "dir": Vector3.UP, "spread": 20.0,
		"vmin": 0.5, "vmax": 2.0, "size": 0.9, "cols": FutonLib.dust_cols(g, 0.7), "life": 1.1, "burst": 0.3, "g": Vector3.ZERO})
	for w in 4:
		_later(pj, w * 0.28, func():
			for i in 9:
				var pts = FutonLib.helix_pts(at, Vector3.UP, 6.5, 0.6, randf_range(-1.5, 1.5), 0.0, randf() * TAU, 0.7, 18)
				FutonLib.line(pj, pts, 0.05, 0.45, WHITE if i % 3 != 0 else FutonLib.MINT, {"grow": 0.6, "delay": randf() * 0.1}))


static func _atsugai_burst(pj: PathJutsu, at: Vector3) -> void:
	var g = FutonLib.floor_at(at)
	GroundFX.wind(at, 14.0)   # rüzgâr yanan zemini büyütür (eski patlamanın oyun etkisi)
	GroundFX.add(g, "cracked", 4.8, 5.0)   # yarık zemin: üstünden geçen yavaşlar (eski çatlak izinin oyun etkisi)
	for shell in 3:
		var R = 3.0 + shell * 2.6
		for i in 13:
			var nrm = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var e1 = FutonLib.side_of(nrm) if absf(nrm.y) < 0.95 else Vector3.RIGHT
			var e2 = nrm.cross(e1).normalized()
			var a0 = randf() * TAU
			var span = randf_range(1.2, 2.4)
			var pts = FutonLib.path_pts(func(u: float) -> Vector3:
				var a = a0 + u * span
				var p = at + (e1 * cos(a) + e2 * sin(a)) * R
				p.y = maxf(p.y, g.y + 0.15)
				return p, 18)
			if i < 3:
				FutonLib.sheet(pj, pts, R * 0.22, 0.5 + shell * 0.08, FutonLib.MINT, {"delay": shell * 0.08, "grow": 0.4, "opacity": 0.45})
			else:
				FutonLib.line(pj, pts, 0.06 + shell * 0.03, 0.4 + shell * 0.08, WHITE if i % 3 != 0 else FutonLib.MINT, {"delay": shell * 0.08, "grow": 0.4})
	FutonLib.warp(pj, at, 1.0, 9.0, 0.6, {"power": 2.5})
	FutonLib.warp(pj, g + Vector3.UP * 0.1, 1.0, 10.0, 0.7, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.5})
	FutonLib.scour(pj, g, Vector3.FORWARD, 16.0, 16.0, 4.0, 1)
	FutonLib.scour(pj, g, Vector3.FORWARD, 9.0, 9.0, 5.0, 2)
	FutonLib.chunks(pj, g, 14, 11.0, Color(0.5, 0.42, 0.32), 0.35)
	FutonLib.bits(pj, g + Vector3.UP * 0.3, 22, "puff", {"box": Vector3(1.5, 0.2, 1.5), "radial": 14.0, "dir": Vector3.UP, "spread": 80.0,
		"vmin": 6.0, "vmax": 12.0, "size": 1.4, "cols": FutonLib.dust_cols(g), "life": 1.4, "damp": 2.5, "g": Vector3(0, -0.5, 0)})
	_kick(pj, g + Vector3.UP * 0.5, 18, Vector3.UP, 6.0, 12.0, {"spread": 70.0})


# ================================================================== 5. Fūton: Gōfū Bōheki (Büyük Rüzgâr Koruma Duvarı)
## Ref (Temari): kızıl-pembe tonlu, dairesel dönen yoğun hız çizgileri, bej toz yayları.
## Görünüş: önünde 5 m'de beş dönen sütun — her biri yukarı açılan gül-bej sarmal çizgiler + perde; sütunlar arasında yana akan
## bağlayıcı hava bantları, zeminde duvar boyunca süpürülmüş iz ve tabanlarda dönen toz. Yutulan mermi yukarı sarmalla dağılır.
static func futon_gofu_boheki(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var d = pj.fwd(c, t)
	var at = pj.gp(c.global_position + d * 4.0)
	var side = d.cross(Vector3.UP)
	_gofu_rise(pj, at, side)
	pj.every(5.0, 0.2, func(i, _k):
		if i % 2 == 0:
			_gofu_pillars(pj, at, side, i)
		for pr in pj.get_tree().get_nodes_in_group("projectiles"):
			if pr.get("shooter") != c and absf((pr.global_position - at).dot(d)) < 2.0 and absf((pr.global_position - at).dot(side)) < 7.5:
				_gofu_swallow(pj, pr.global_position)
				pr.queue_free()
		for e in pj.enemies_near(c, at, 6.0):
			if e.get("velocity") != null:
				e.velocity += d * 5.0, Callable())
	Sfx.play("wind", at, 0.6)


static func _gofu_rise(pj: PathJutsu, at: Vector3, side: Vector3) -> void:
	FutonLib.scour(pj, at - side * 7.5, side, 15.0, 2.6, 5.0, 0)
	for k in 5:
		var pc = at + side * ((k - 2) * 2.8)
		FutonLib.warp(pj, pc + Vector3.UP * 0.1, 0.4, 2.6, 0.45, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.2, "delay": k * 0.04})
		FutonLib.bits(pj, pc + Vector3.UP * 0.2, 6, "puff", {"radius": 1.2, "dir": Vector3.UP, "spread": 25.0, "vmin": 3.0, "vmax": 6.0,
			"size": 1.0, "cols": FutonLib.dust_cols(pc), "life": 1.0, "tang": 10.0, "damp": 2.0, "g": Vector3.ZERO})


static func _gofu_pillars(pj: PathJutsu, at: Vector3, side: Vector3, i: int) -> void:
	for k in 5:
		var pc = at + side * ((k - 2) * 2.8)
		for j in 2:
			var pts = FutonLib.helix_pts(pc, Vector3.UP, 1.4, 2.4, 0.0, 7.0, randf() * TAU, 1.3, 26)
			_far(FutonLib.line(pj, pts, 0.06, 0.6, ROSE_SOFT if j == 0 else WHITE, {"grow": 0.5, "flow": 6.0}))
		if i % 4 == 0:
			var ps = FutonLib.helix_pts(pc, Vector3.UP, 1.5, 2.3, 0.4, 6.4, randf() * TAU, 0.9, 20)
			_far(FutonLib.sheet(pj, ps, 0.7, 0.7, SAND_SOFT, {"grow": 0.45, "opacity": 0.28, "lines": 4.0}))
		if i % 6 == 0:
			FutonLib.bits(pj, pc + Vector3.UP * 0.3, 4, "puff", {"radius": 1.4, "dir": Vector3.UP, "spread": 20.0, "vmin": 1.0, "vmax": 3.0,
				"size": 0.9, "cols": FutonLib.dust_cols(pc, 0.6), "life": 0.9, "tang": 14.0, "g": Vector3.ZERO})
	if i % 4 == 2:
		var sgn = 1.0 if i % 8 == 2 else -1.0
		var a = at - side * 6.0 * sgn + Vector3.UP * 2.4
		var b = at + side * 6.0 * sgn + Vector3.UP * 2.4
		var ph = randf() * TAU
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3: return a.lerp(b, u) + Vector3.UP * sin(u * 9.0 + ph) * 0.4, 24)
		_far(FutonLib.line(pj, pts2, 0.05, 0.7, ROSE_SOFT, {"grow": 0.4}))


static func _gofu_swallow(pj: PathJutsu, p: Vector3) -> void:
	FutonLib.warp(pj, p, 0.2, 1.4, 0.3, {"swirl": 2.0, "power": 1.0})
	for j in 5:
		var pts = FutonLib.helix_pts(p, Vector3.UP, 0.5, 0.9, 0.0, 1.8, j * TAU / 5.0, 0.8, 12)
		_far(FutonLib.line(pj, pts, 0.035, 0.35, ROSE_SOFT if j % 2 == 0 else WHITE, {"grow": 0.5}), 5.0)


# ================================================================== 6. Ressenpū (Şiddetli Kasırga Yelpazesi)
## Ref: yerden yükselen kalın, topaklı kahverengi toz bulutları; hedefler toz içinde savrulur, ince toz çizgisi.
## Görünüş: zemin boyunca ileri yuvarlanan yatay eksenli girdap — yerde döne döne ilerleyen sikloid çizgiler, sırayla kabaran
## topaklı toz duvarı, taşlar; alçakta ileri akan kumlu perdeler ve 20 m süpürülmüş zemin izi.
static func ressenpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.0)
	var d = pj.fwd(c, t)
	var from = c.global_position + Vector3.UP * 1.0
	Dangle.gust(from + d * 10.0, d * 28.0, 12.0, 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
	_ressen_sweep(pj, from, d)
	for k in 6:
		pj.after(k * 0.06, func():
			var q = pj.gp(c.global_position + d * (3.0 + k * 3.0))
			_ressen_roll(pj, q, d, k))
	Combat.hit_zone(c, c.global_position, d, 20.0, 30.0, 4.0, pj.inf(c, "ressenpu", 1.3, {"knock": 14.0, "launch": 10.0, "kind": "heavy", "element": "fuuton", "dir": d}))
	pj.shake(0.6)
	Sfx.play("wind", c.global_position, 0.5)


static func _ressen_sweep(pj: PathJutsu, from: Vector3, d: Vector3) -> void:
	var sd = FutonLib.side_of(d)
	var gy = Game.jutsu_floor_at(from).y
	for i in 3:
		var h = [0.35, 0.9, 1.5][i]
		var ph = randf() * TAU
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var p = from + d * lerpf(1.0, 20.0, u) + sd * sin(u * 4.0 + ph) * 0.8
			p.y = gy + h + sin(u * 6.0 + ph) * 0.2
			return p, 24)
		_far(FutonLib.sheet(pj, pts, 0.9 + i * 0.3, 0.9, SAND_SOFT, {"grow": 0.45, "opacity": 0.32, "delay": i * 0.04}))
	for i in 6:
		var off = randf_range(-2.5, 2.5)
		var hh = randf_range(0.3, 1.8)
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3:
			var p = from + d * lerpf(0.5, 19.0, u) + sd * off
			p.y = gy + hh
			return p, 12)
		_far(FutonLib.line(pj, pts2, 0.04, 0.6, WHITE, {"grow": 0.4, "delay": randf() * 0.1}))


static func _ressen_roll(pj: PathJutsu, q: Vector3, d: Vector3, k: int) -> void:
	var sd = FutonLib.side_of(d)
	var R = 1.0 + k * 0.15
	for j in 3:
		var off = lerpf(-1.5, 1.5, j / 2.0) * (1.0 + k * 0.2)
		var ph = randf() * TAU
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var th = u * TAU * 1.25 + ph
			return q + sd * off + d * (u * 3.4 - 1.7 + R * 0.5 * sin(th)) + Vector3.UP * (0.25 + R * (1.0 - cos(th)) * 0.6), 26)
		_far(FutonLib.line(pj, pts, 0.05, 0.55, SAND if j != 1 else WHITE, {"grow": 0.5, "flow": 7.0}))
	FutonLib.bits(pj, q + Vector3.UP * 0.4, 8 + k, "puff", {"dir": (d * 0.4 + Vector3.UP).normalized(), "spread": 50.0, "vmin": 2.0, "vmax": 6.0,
		"size": 1.0 + k * 0.15, "cols": FutonLib.dust_cols(q), "life": 1.3, "damp": 2.5, "g": Vector3(0, -0.6, 0), "box": Vector3(1.8 + k * 0.3, 0.3, 1.8 + k * 0.3)})
	FutonLib.chunks(pj, q, 4, 7.0, FutonLib.ground_col(q).darkened(0.35), 0.25, d + Vector3.UP)
	FutonLib.scour(pj, q - d * 1.5, d, 3.5, 5.0 + k, 3.5, 0)


# ================================================================== 7. Fūton: Kūdan (Hava Mermileri)
## Ref (Nagato): yağmurda uçan saydam hava küreleri — arkasını mercek gibi büyütür, kenarı yer yer kopuk soluk çizgi.
## Görünüş: ağızda içe çekilen kısa çizgiler ve minik küre → mercek gibi kıran yırtık kenarlı hava küresi, ardında iki sarmal iz;
## çarpınca küre yırtılır: bükülme halkası, dışa kıvrılan kopuk çizgiler, yerdeyse ışınsal süpürme ve toz.
static func wind_release_air_bullets(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 26.0)
	for k in 3:
		pj.after(k * 0.18, func():
			if pj.live(c):
				_air_bullet(pj, c, tt))
	Sfx.play("wind", c.global_position, 1.0)


static func _air_bullet(pj: PathJutsu, c: Node3D, tt: Node3D) -> void:
	var from = pj._mouth_pos(c)
	_cheek_gather(pj, from, c.face_dir())
	pj.after(0.08, func():
		if not pj.live(c):
			return
		var info = {"knock": 8.0 * 1.2, "kind": "heavy", "element": "fuuton", "hitstop": 0.05}
		info.merge({"knock": 16.0}, true)
		var holder = Node3D.new()
		var pr = pj.shot(c, from, pj.aim_at(c, tt, from), 30.0, holder, pj.inf(c, "wind_release_air_bullets", 0.5, info), null, false, 1.6, func(p, _h):
			_bullet_pop(pj, p))
		pr.radius = 0.35 + 1.0 * 0.4
		FutonLib.orb(pj, Vector3.ZERO, 0.75, PALE, {"parent": pr, "tear": 0.55})
		FutonLib.follow(pj, pr, 0.05, 9, FutonLib.AIR, {"offset": Vector3(0.0, 0.55, 0.0), "spin": 9.0})
		FutonLib.follow(pj, pr, 0.05, 9, FutonLib.AIR, {"offset": Vector3(0.0, -0.55, 0.0), "spin": 9.0}))


static func _cheek_gather(pj: PathJutsu, mo: Vector3, f: Vector3) -> void:
	FutonLib.orb(pj, mo + f * 0.3, 0.25, PALE, {"life": 0.14, "tear": 0.2})
	for i in 6:
		var a = TAU * i / 6.0
		var dv = (f + FutonLib.side_of(f) * cos(a) * 0.9 + Vector3.UP * sin(a) * 0.9).normalized()
		FutonLib.line(pj, _seg(mo + dv * 1.2, mo + f * 0.3, 5), 0.025, 0.14, WHITE, {"grow": 0.6})


static func _bullet_pop(pj: PathJutsu, p: Vector3) -> void:
	FutonLib.warp(pj, p, 0.5, 3.2, 0.35, {"power": 2.2})
	for i in 12:
		var dv = Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		var tg = dv.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
		var L = randf_range(1.2, 2.4)
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return p + dv * (0.6 + L * u) + tg * u * u * 0.6, 8)
		FutonLib.line(pj, pts, 0.04, 0.3, WHITE if i % 3 != 0 else PALE, {"grow": 0.4})
	FutonLib.bits(pj, p, 6, "puff", {"radius": 0.5, "dir": Vector3.UP, "spread": 180.0, "vmin": 2.0, "vmax": 4.0, "size": 0.7,
		"cols": [Color(1, 1, 1, 0.0), Color(0.92, 0.95, 1.0, 0.5), Color(1, 1, 1, 0.0)], "life": 0.6, "damp": 3.0, "g": Vector3.ZERO})
	var g = FutonLib.floor_at(p)
	if p.y - g.y < 2.0:
		FutonLib.scour(pj, g, Vector3.FORWARD, 4.0, 4.0, 2.0, 1)
		FutonLib.bits(pj, g + Vector3.UP * 0.2, 6, "puff", {"box": Vector3(0.6, 0.1, 0.6), "radial": 8.0, "dir": Vector3.UP, "spread": 30.0,
			"vmin": 1.0, "vmax": 3.0, "size": 0.8, "cols": FutonLib.dust_cols(g), "life": 0.9, "g": Vector3.ZERO})


# ================================================================== 8. Fūton: Sajin Senpū (Kum Tozu Kasırgası) — c_ işleyicisi taşındı
## Görünüş: ileri yürüyen tek kumlu hortum: dibi dar, tepesi geniş, kendisiyle dönen kum renkli sarmal çizgiler ve perdeler;
## tabanda dönen toz ve yukarı fırlayan çakıl, ardında ışınsal süpürme izleri. Doğuşta zemine yatık bükülme halkası.
static func kazahana_sajin_senpu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var d = pj.fwd(c, t)
	var tor = Node3D.new()
	pj.get_tree().current_scene.add_child(tor)
	tor.global_position = pj.gp(c.global_position + d * 3.0)
	FutonLib.warp(pj, tor.global_position + Vector3.UP * 0.1, 0.5, 3.5, 0.5, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.4, "swirl": 1.5})
	var hit_t = {}
	pj.every(3.0, 1.0 / 30.0, func(i, _k):
		tor.global_position = pj.gp(tor.global_position + d * 0.32)
		tor.rotation.y += 0.5
		if i % 5 == 0:
			_sajin_funnel(pj, tor, i)
		if i % 4 == 0:
			_sajin_skirt(pj, tor.global_position, i)
		for e in pj.enemies_near(c, tor.global_position, 4.2):
			var key = e.get_instance_id()
			if Time.get_ticks_msec() - int(hit_t.get(key, 0)) > 500:
				hit_t[key] = Time.get_ticks_msec()
				pj.hit(c, e.global_position + Vector3.UP, 1.0, pj.inf(c, "kazahana_sajin_senpu", 0.35, {"knock": 3.0, "launch": 9.0, "kind": "heavy", "element": "fuuton"})), func():
		pj.fade_free(tor, 0.0, 0.4))
	Sfx.play("wind", c.global_position, 0.6)


static func _sajin_funnel(pj: PathJutsu, tor: Node3D, i: int) -> void:
	if not is_instance_valid(tor):
		return
	for j in 3:
		var pts = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.7, 3.6, 0.1, 9.5, randf() * TAU, 1.6, 30)
		FutonLib.line(pj, pts, 0.08, 0.5, SAND if j != 2 else WHITE, {"parent": tor, "grow": 0.5, "flow": 6.0})
	if i % 10 == 0:
		var ps = FutonLib.helix_pts(Vector3.ZERO, Vector3.UP, 0.9, 3.2, 0.3, 8.5, randf() * TAU, 1.1, 24)
		FutonLib.sheet(pj, ps, 1.0, 0.55, SAND, {"parent": tor, "grow": 0.45, "opacity": 0.55, "lines": 5.0})


static func _sajin_skirt(pj: PathJutsu, p: Vector3, i: int) -> void:
	FutonLib.bits(pj, p + Vector3.UP * 0.3, 5, "puff", {"radius": 1.0, "tang": 16.0, "radial": 2.0, "dir": Vector3.UP, "spread": 30.0,
		"vmin": 2.0, "vmax": 5.0, "size": 0.9, "cols": FutonLib.dust_cols(p), "life": 0.8, "g": Vector3.ZERO})
	var dc = FutonLib.ground_col(p).darkened(0.3)
	FutonLib.bits(pj, p + Vector3.UP * 0.2, 4, "grit", {"radius": 0.8, "tang": 20.0, "dir": Vector3.UP, "spread": 20.0, "vmin": 4.0, "vmax": 8.0,
		"size": 0.12, "cols": [dc, dc, Color(dc.r, dc.g, dc.b, 0.0)], "life": 1.0, "g": Vector3(0, -6.0, 0)})
	if i % 12 == 0:
		FutonLib.scour(pj, p, Vector3.FORWARD, 3.5, 3.5, 2.0, 1)


# ================================================================== 9. Fūton: Kazekiri no Mai (Rüzgâr Kesen Dans) — c_ işleyicisi taşındı
## Görünüş (Kazahana = rüzgâr çiçeği): her dalgada dansçının belinde yatay dönen etek gibi açılan çizgiler + savrulan çiçek yaprakları;
## sekiz yöne kendi ekseninde fırıl dönen yatay hilal bıçaklar (yatay kesik düzlemi).
static func kazahana_kazekiri_mai(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 1.0)
	pj.every(1.0, 0.25, func(i, _k):
		if c.get("model"):
			c.model.rotation.y += PI * 0.5
		_dance_skirt(pj, c.global_position + Vector3.UP * 1.0, i)
		for k in 8:
			var d = Vector3(cos(k * TAU / 8.0 + i * 0.4), 0, sin(k * TAU / 8.0 + i * 0.4))
			var holder = Node3D.new()
			var pr = pj.shot(c, c.global_position + Vector3.UP * 1.1 + d * 0.8, d, 24.0, holder, pj.inf(c, "kazahana_kazekiri_mai", 0.1, {"knock": 4.0, "kind": "light", "element": "fuuton"}), null, true, 0.5)
			pr.spin = Vector3(0, 22, 0)
			FutonLib.blade(pj, Vector3.ZERO, FutonLib.blade_basis(Vector3(0, 0, -1), Vector3.UP), 1.1, 0.55, FutonLib.MINT,
				{"parent": pr, "thick": 0.18, "wisp": 1.4, "grow": 0.15})
		Sfx.play("wind", c.global_position, 1.6, 0.6), func():
		if is_instance_valid(c) and c.get("model"):
			c.model.visible = true)


static func _dance_skirt(pj: PathJutsu, center: Vector3, i: int) -> void:
	for j in 6:
		var h = lerpf(-0.4, 0.6, j / 5.0)
		var pts = FutonLib.helix_pts(center + Vector3.UP * h, Vector3.UP, 0.9, 2.4, 0.0, -0.25, j * TAU / 6.0 + i * 0.4, 0.45, 16)
		FutonLib.line(pj, pts, 0.045, 0.35, FutonLib.MINT if j % 2 == 0 else WHITE, {"grow": 0.5})
	FutonLib.bits(pj, center, 10, "petal", {"radius": 0.8, "tang": 15.0, "radial": 6.0, "dir": Vector3.UP, "spread": 80.0, "vmin": 2.0, "vmax": 5.0,
		"size": 0.18, "cols": [FutonLib.PETAL, FutonLib.PETAL, Color(1.0, 0.78, 0.86, 0.0)], "life": 1.2, "g": Vector3(0, -1.5, 0)})


# ================================================================== 10. Fūton: Kamaitachi Rendan (Gelincik Orakları Art Arda)
## Görünüş: iki elden sırayla savrulan elde kısa savurma yayı → sağa / sola eğik, tırtıklı ön kenarlı dar orak hilali hedefe döner;
## iki boynuzundan ince iz; çarpınca hedefte X biçimli iki keskin kesik çizgisi, minik bükülme ve çakıl.
static func kazahana_kamaitachi_rendan(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 26.0)
	for k in 5:
		pj.after(0.15 + k * 0.1, func():
			if not pj.live(c):
				return
			var from = pj.hand_pos(c, k % 2 == 0)
			var dir = pj.aim_at(c, tt, from)
			var holder = Node3D.new()
			var pr = pj.shot(c, from, dir, 34.0, holder, pj.inf(c, "kazahana_kamaitachi_rendan", 0.35, {"knock": 3.0, "kind": "light", "bleed": 1.5, "element": "fuuton"}), tt, false, 1.0, func(p, _h):
				_sickle_cut(pj, p, dir, k))
			var a = 1.0 if k % 2 == 0 else -1.0
			var nrm = Vector3(sin(a), cos(a), 0.0)
			var bas = FutonLib.blade_basis(Vector3(0, 0, -1), nrm)
			FutonLib.blade(pj, Vector3.ZERO, bas, 1.5, 1.05, FutonLib.AIR, {"parent": pr, "thick": 0.22, "jag": 1.0, "wisp": 1.6, "grow": 0.1})
			for s in [-1.0, 1.0]:
				FutonLib.follow(pj, pr, 0.025, 8, FutonLib.AIR, {"offset": bas.x * 0.6 * s - bas.y * 0.15})
			_sickle_swing(pj, from, dir, a))
	Sfx.play("wind", c.global_position, 1.5)


static func _sickle_swing(pj: PathJutsu, from: Vector3, dir: Vector3, a: float) -> void:
	var sd = FutonLib.side_of(dir)
	var up = FutonLib.up_of(dir)
	var ax = (sd * cos(a) + up * sin(a)).normalized()
	var pts = FutonLib.path_pts(func(u: float) -> Vector3:
		var ang = lerpf(-1.2, 1.2, u)
		return from + (ax * sin(ang) + dir * cos(ang)) * 0.7 - dir * 0.3, 10)
	FutonLib.line(pj, pts, 0.04, 0.18, WHITE, {"grow": 0.5})


static func _sickle_cut(pj: PathJutsu, p: Vector3, dir: Vector3, k: int) -> void:
	var sd = FutonLib.side_of(dir)
	var up = FutonLib.up_of(dir)
	var tilt = 0.35 if k % 2 == 0 else -0.35
	for s in [-1.0, 1.0]:
		var ax = (sd * cos(PI * 0.25 * s + tilt) + up * sin(PI * 0.25 * s + tilt)).normalized()
		FutonLib.line(pj, _seg(p - ax * 0.9, p + ax * 0.9, 6), 0.05, 0.25, WHITE, {"grow": 0.25})
	FutonLib.warp(pj, p, 0.15, 0.9, 0.2, {"power": 1.0})
	_kick(pj, p, 4, -dir + Vector3.UP, 2.0, 4.0, {"size": 0.15, "life": 0.7})


# ================================================================== 11. Jūha Reppūshō (Canavar Dalgası Kasırga Avucu)
## Ref: ileri atılan mavi, canavar biçimli rüzgâr dalgası — önde pençe gibi uzanan parmaklar, kıvrılan baş tepesi, pırıltılı mavi gövde.
## Görünüş: her avuçta (üç kez, sağa-sola kavis çizerek) ileri koşan mavi canavar: kabaran perde gövde, öne kıvrılan tepe dudağı,
## öne uzanıp aşağı kanca yapan beş pençe çizgisi, arkada kuyruk izleri, gövdede mavi pırıltı; zeminde süpürülmüş iz.
static func juha_reppusho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	for k in 3:
		pj.after(0.18 + k * 0.14, func():
			if not pj.live(c):
				return
			var o = c.global_position + Vector3.UP * 1.1 + d * 0.8
			var sgn = 1.0 if k % 2 == 0 else -1.0
			Dangle.gust(o + d * 9.0, d * 28.0, 10.8, 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
			_beast_wave(pj, o, d, side, sgn, k)
			Combat.hit_zone(c, c.global_position, d, 18.0, 25.0, 3.0, pj.inf(c, "juha_reppusho", 0.55, {"knock": 9.0, "launch": 3.0, "kind": "heavy", "element": "fuuton", "bleed": 2.0, "dir": d})))
	pj.shake(0.4)
	Sfx.play("wind", c.global_position, 1.3)


static func _beast_wave(pj: PathJutsu, o: Vector3, d: Vector3, side: Vector3, sgn: float, k: int) -> void:
	var g0 = FutonLib.floor_at(o)
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_basis = Basis(side, Vector3.UP, -d)
	var start = Vector3(o.x, g0.y, o.z)
	root.global_position = start
	var sc = 1.0 + k * 0.15
	# gövde: kuyruktan (yerel +Z) başa (yerel -Z) kabaran, uçta öne-aşağı kıvrılan perdeler
	for i in 4:
		var x = lerpf(-1.6, 1.6, i / 3.0) * sc
		var ph = float(i)
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var z = lerpf(2.6, -2.2, u) * sc
			var h = (0.3 + 2.4 * pow(sin(u * PI * 0.62), 1.4)) * sc
			if u > 0.7:
				var q = (u - 0.7) / 0.3
				z -= sin(q * PI * 0.9) * 0.9 * sc
				h -= q * q * 1.6 * sc
			return Vector3(x + sin(u * 5.0 + ph) * 0.15, h, z), 22)
		FutonLib.sheet(pj, pts, 0.75 * sc, 0.75, BEAST, {"parent": root, "grow": 0.3, "opacity": 0.75, "lines": 5.0})
	# pençeler
	for i in 5:
		var xc = lerpf(-1.4, 1.4, i / 4.0) * sc
		var pts2 = FutonLib.path_pts(func(u: float) -> Vector3:
			return Vector3(xc * (1.0 + u * 0.4), (2.4 + sin(u * PI * 0.7) * 0.4 - u * u * 2.6) * sc, (-1.2 - u * 2.6) * sc), 14)
		FutonLib.line(pj, pts2, 0.07, 0.7, BEAST_HI, {"parent": root, "grow": 0.35, "delay": 0.04})
	# tepe dudağı: yan eksende kıvrılan sarmal
	var lip = FutonLib.helix_pts(Vector3(0, 2.6 * sc, -1.6 * sc), Vector3.RIGHT, 0.3, 1.0, -1.2 * sc, 1.2 * sc, 0.0, 1.0, 20)
	FutonLib.sheet(pj, lip, 0.5, 0.7, BEAST, {"parent": root, "grow": 0.35, "opacity": 0.7})
	# kuyruk izleri
	for i in 4:
		var xt = randf_range(-1.4, 1.4) * sc
		var ht = randf_range(0.3, 1.4)
		FutonLib.line(pj, _seg(Vector3(xt, ht, 2.4 * sc), Vector3(xt * 0.6, ht * 0.5, 5.0 * sc), 6), 0.04, 0.6, BEAST_HI, {"parent": root, "grow": 0.4})
	FutonLib.bits(pj, Vector3(0, 1.2, 0), 14, "grit", {"parent": root, "box": Vector3(1.8, 1.2, 2.5), "cols": [BEAST_HI, BEAST, Color(0.4, 0.66, 1.0, 0.0)],
		"size": 0.1, "vmin": 0.5, "vmax": 2.0, "g": Vector3.ZERO, "life": 0.7, "turb": true})
	FutonLib.scour(pj, start, d, 17.0, 4.5, 2.5, 0)
	var tw = root.create_tween()
	tw.tween_method(func(q: float):
		if is_instance_valid(root):
			var p = start + d * 16.0 * q + side * sgn * sin(q * PI) * 1.6
			p.y = Game.jutsu_floor_at(p).y
			root.global_position = p, 0.0, 1.0, 0.6)
	tw.tween_interval(0.25)
	tw.tween_callback(root.queue_free)


# ================================================================== 12. Fūton: Kakeami (Rüzgâr Ağı)
## Görünüş: ileri fırlatılan, uçarken açılan rüzgâr ağı (çapraz geçen, sarkan, titreyen ince saydam nane ipler) → hedefin üstüne
## düşer, tutma süresince içe büzülür ve kenardan merkeze akan ip çekişleri görünür; yakalanan her düşmanın çevresinde dönen üç kat ip halkası.
static func futon_kakeami(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.7)
	var tt = pj.tg(c, t, 22.0)
	var at = tt.global_position if tt else c.global_position + pj.fwd(c, t) * 10.0
	var from = c.global_position + Vector3.UP * 1.2
	var dir = (at - c.global_position).normalized()
	var L = c.global_position.distance_to(at)
	Dangle.gust(from + dir * L * 0.5, dir * 28.0, maxf(L * 0.6, 4.0), 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
	_net_cast(pj, from, at + Vector3.UP * 1.4, 0.25)
	pj.after(0.25, func(): _net_bind(pj, c, at, 4.0, 2.0, "futon_kakeami"))
	Sfx.play("wind", c.global_position, 1.1)


## Rüzgâr ağı ipleri: kenardan karşı yana çapraz geçen, sarkan, yanlara dalgalanan ince saydam nane ipler (düzgün kare örgü değil).
## Yerel XY (flat ise XZ) düzleminde h yarıçap; ipler akım çizgisi gibi titreyip kesik kesik akar.
static func _web_threads(pj: PathJutsu, parent: Node3D, h: float, n: int, w: float, flat: bool) -> Array:
	var out = []
	var a_off = randf() * TAU
	for i in n:
		var a0 = a_off + TAU * i / n + randf_range(-0.2, 0.2)
		var a1 = a0 + PI + randf_range(-0.9, 0.9)
		var r0 = h * randf_range(0.8, 1.05)
		var r1 = h * randf_range(0.8, 1.05)
		var p0 = Vector3(cos(a0) * r0, sin(a0) * r0, 0)
		var p1 = Vector3(cos(a1) * r1, sin(a1) * r1, 0)
		var perp = Vector3(-(p1 - p0).y, (p1 - p0).x, 0).normalized()
		var bow = randf_range(-0.25, 0.25) * h
		var ph = randf() * TAU
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var q = p0.lerp(p1, u) + perp * (sin(u * PI) * bow + sin(u * 11.0 + ph) * 0.04 * h)
			if flat:
				return Vector3(q.x, -sin(u * PI) * 0.12 * h, q.y)
			return q + Vector3(0, 0, sin(u * PI) * 0.1 * h), 18)
		var tint = Color(0.84, 1.0, 0.94, 0.55) if i % 3 != 0 else Color(1.0, 1.0, 1.0, 0.6)
		out.append(_far(FutonLib.fixed(pj, pts, w * randf_range(0.7, 1.1), "line", tint, {"parent": parent, "flow": randf_range(9.0, 14.0)}), 4.0))
	return out


static func _net_cast(pj: PathJutsu, from: Vector3, to: Vector3, dur: float) -> void:
	var f = (to - from).normalized()
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_basis = Basis(FutonLib.side_of(f), FutonLib.up_of(f), -f)
	root.global_position = from
	root.scale = Vector3.ONE * 0.15
	_web_threads(pj, root, 1.0, 10, 0.01, false)
	var tw = root.create_tween().set_parallel()
	tw.tween_property(root, "global_position", to, dur)
	tw.tween_property(root, "scale", Vector3.ONE * 4.0, dur).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(root.queue_free)


static func _net_bind(pj: PathJutsu, c: Node3D, at: Vector3, r: float, hold: float, id: String) -> void:
	var g = pj.gp(at)
	_net_drape(pj, g, r, hold)
	pj.after(0.3, func():
		for e in pj.enemies_near(c, g, r):
			if pj.live(e) and e.has_method("apply_status"):
				e.apply_status("bind", hold)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, id, 0.6, {"knock": 0.0, "kind": "light", "element": "fuuton"}))
				_net_wrap(pj, e, hold)
		pj.every(hold, 0.4, func(_i, _k):
			for e in pj.enemies_near(c, g, r):
				if pj.live(e):
					pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, id, 0.15, {"knock": 0.0, "kind": "light", "element": "fuuton"})), Callable()))


static func _net_drape(pj: PathJutsu, g: Vector3, r: float, hold: float) -> void:
	var root = Node3D.new()
	pj.get_tree().current_scene.add_child(root)
	root.global_position = g + Vector3.UP * 3.2
	var ls = _web_threads(pj, root, r, 14, 0.028, true)
	var tw = root.create_tween()
	tw.tween_property(root, "global_position", g + Vector3.UP * 0.9, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): FutonLib.warp(pj, g + Vector3.UP * 0.1, r, 1.0, 0.4, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.2}))
	tw.tween_callback(func(): _net_pull(pj, g, r, hold))
	tw.tween_property(root, "scale", Vector3(0.35, 1.0, 0.35), hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float):
		for mi in ls:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tw.tween_callback(root.queue_free)


## Tutma boyunca kenardan merkeze akan kısa ip çekişleri (ağ gözle görülür biçimde büzülür)
static func _net_pull(pj: PathJutsu, g: Vector3, r: float, hold: float) -> void:
	var waves = maxi(1, int(hold / 0.3))
	for w in waves:
		_later(pj, w * 0.3, func():
			var rr = r * lerpf(1.0, 0.4, float(w) / waves)
			for i in 6:
				var a = randf() * TAU
				var p0 = g + Vector3(cos(a), 0, sin(a)) * rr + Vector3.UP * randf_range(0.6, 1.2)
				var p1 = g + Vector3(cos(a + 0.5), 0, sin(a + 0.5)) * rr * 0.25 + Vector3.UP * 0.8
				var pts = FutonLib.path_pts(func(u: float) -> Vector3: return p0.lerp(p1, u) + Vector3.DOWN * sin(u * PI) * 0.2, 10)
				_far(FutonLib.line(pj, pts, 0.025, 0.35, Color(0.84, 1.0, 0.94, 0.6), {"grow": 0.5, "flow": 10.0}), 4.0))


static func _net_wrap(pj: PathJutsu, e: Node3D, hold: float) -> void:
	var holder = Node3D.new()
	e.add_child(holder)
	var rr = float(e.get("radius")) + 0.25 if e.get("radius") != null else 0.7
	for j in 3:
		var hh = 0.4 + j * 0.6
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var a = u * TAU
			return Vector3(cos(a) * rr, hh + sin(a * 3.0) * 0.06, sin(a) * rr), 26)
		_far(FutonLib.fixed(pj, pts, 0.025, "line", Color(0.84, 1.0, 0.94, 0.6), {"parent": holder, "flow": 10.0}), 4.0)
	var tw = Game.safe_loops(holder.create_tween(), int(ceil(hold / 0.5)))
	tw.tween_property(holder, "rotation:y", TAU, 0.5).as_relative()
	FutonLib.kill(pj, hold, holder)


# ================================================================== 13. Kyodai Sensu: Sanban Boshi (Dev Yelpaze, Üçüncü Ay)
## Kendi modeli: Temari'nin dev demir yelpazesi — koyu demir kaburgalar, krem kâğıt dilimleri, demir dış kenar, üç mor ay.
## Yelpaze her savuruşta üçte bir daha açılır ve o ayı gösterir (birinci, ikinci, üçüncü yıldız).
## Görünüş: her savuruşta yelpaze diliminin taradığı sektörde soldan sağa (sonra tersine) süpürülen perde ve çizgi yelpazesi,
## zeminde sektör boyunca süpürme izi, öne savrulan toz ve yaprak; üçüncü yıldızda ilerde yerde yayılan kasırga diski.
static func kyodai_sensu(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 1.6)
	var d = pj.fwd(c, t)
	var fan = _giant_fan(pj, c, 1.8)
	for k in 3:
		pj.after(0.25 + k * 0.42, func():
			if not pj.live(c):
				return
			pj.anim(c, "slash_c" if k % 2 == 0 else "slash_b", 1.4)
			_fan_open(fan, k)
			var s = 1.0 + k * 0.6
			var o = c.global_position + Vector3.UP * 1.3 + d * 0.8
			Dangle.gust(o + d * 7.0 * s, d * 28.0, maxf(14.0 * s * 0.6, 6.0 * s), 0.7)   # yoldaki saç/kumaş savrulur (eski akımın oyun etkisi)
			_fan_gale(pj, o, d, 14.0 * s, 25.0 + k * 10.0, k)
			if k == 2:
				_fan_storm(pj, pj.gp(c.global_position + d * 12.0))
			Combat.hit_zone(c, c.global_position, d, 14.0 * s, 25.0 + k * 10.0, 3.0 + k, pj.inf(c, "kyodai_sensu", 0.4 + k * 0.25, {"knock": 8.0 + k * 6.0, "launch": 2.0 + k * 2.0, "kind": "heavy", "element": "fuuton", "dir": d}))
			pj.shake(0.3 + k * 0.2))
	Sfx.play("wind", c.global_position, 0.9)


const FAN_R := 1.7
const FAN_SEG := 50.0


## Yelpazenin bir dilimi (a: 0..50°, +Y'den +X'e): 6 demir kaburga, iki kat kâğıt, demir kenar şeridi
static func _fan_seg_mesh() -> ArrayMesh:
	if _mc.has("seg"):
		return _mc["seg"]
	var b = MB.new()
	for r in 6:
		var a = deg_to_rad(lerpf(0.0, FAN_SEG, r / 5.0))
		var dir = Vector3(sin(a), cos(a), 0)
		b.add("box", dir * (FAN_R * 0.5 + 0.05), Vector3(0.05, FAN_R + 0.1, 0.05), IRON, Vector3(0, 0, -rad_to_deg(a)))
		if r < 5:
			var a2 = deg_to_rad(lerpf(0.0, FAN_SEG, (r + 0.5) / 5.0))
			var d2 = Vector3(sin(a2), cos(a2), 0)
			var rot = Vector3(0, 0, -rad_to_deg(a2))
			b.add("box", d2 * 0.85, Vector3(0.15, 0.62, 0.025), PAPER, rot)
			b.add("box", d2 * 1.4, Vector3(0.27, 0.62, 0.025), PAPER.darkened(0.04), rot)
			b.add("box", d2 * (FAN_R - 0.02), Vector3(0.31, 0.1, 0.06), IRON_EDGE, rot)
	var m = b.build(Props.toon())
	_mc["seg"] = m
	return m


static func _fan_moon_mesh() -> ArrayMesh:
	if _mc.has("moon"):
		return _mc["moon"]
	var b = MB.new()
	b.add("cyl", Vector3(0, 0, 0.03), Vector3(0.42, 0.02, 0.42), MOON, Vector3(90, 0, 0), 18)
	b.add("cyl", Vector3(0, 0, -0.03), Vector3(0.42, 0.02, 0.42), MOON, Vector3(90, 0, 0), 18)
	var m = b.build(Props.toon())
	_mc["moon"] = m
	return m


static func _fan_handle_mesh() -> ArrayMesh:
	if _mc.has("handle"):
		return _mc["handle"]
	var b = MB.new()
	b.add("cyl", Vector3(0, -0.12, 0), Vector3(0.13, 0.36, 0.13), IRON, Vector3.ZERO, 10)
	b.add("cyl", Vector3(0, 0.02, 0), Vector3(0.2, 0.08, 0.2), IRON_EDGE, Vector3(90, 0, 0), 12)
	var m = b.build(Props.toon())
	_mc["handle"] = m
	return m


static func _giant_fan(pj: PathJutsu, c: Node3D, dur: float) -> Dictionary:
	var root = Node3D.new()
	var ba = pj.bone_attach(c, "RightHand")
	if ba:
		ba.add_child(root)
		root.rotation_degrees = Vector3(-90, 0, 0)
	else:
		pj.scene_add(root, pj.hand_pos(c, true))
	root.add_child(pj.mi_of(_fan_handle_mesh()))
	var segs = []
	var moons = []
	for j in 3:
		var sg = Node3D.new()
		root.add_child(sg)
		sg.rotation.z = -deg_to_rad(-75.0)   # kapalı: hepsi ilk dilimin üstünde
		sg.add_child(pj.mi_of(_fan_seg_mesh()))
		var mn = pj.mi_of(_fan_moon_mesh())
		var am = deg_to_rad(FAN_SEG * 0.5)
		mn.position = Vector3(sin(am), cos(am), 0) * 1.15
		mn.scale = Vector3.ONE * 0.01
		sg.add_child(mn)
		segs.append(sg)
		moons.append(mn)
	root.scale = Vector3.ONE * 0.05
	var tw = root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.1, dur - 0.4))
	tw.tween_property(root, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(ba):
			ba.queue_free()
		elif is_instance_valid(root):
			root.queue_free())
	return {"root": root, "segs": segs, "moons": moons}


## k. savuruş: k. dilim yerine açılır, k. ay belirir
static func _fan_open(fan: Dictionary, k: int) -> void:
	var sg = fan["segs"][k]
	var mn = fan["moons"][k]
	if is_instance_valid(sg):
		var target = -deg_to_rad(-75.0 + FAN_SEG * k)
		sg.create_tween().tween_property(sg, "rotation:z", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(mn):
		mn.create_tween().tween_property(mn, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _fan_gale(pj: PathJutsu, o: Vector3, d: Vector3, reach: float, half_deg: float, k: int) -> void:
	var gy = Game.jutsu_floor_at(o).y
	var n_s = 3 + k * 2
	var n_l = 6 + k * 4
	var sweep = 1.0 if k % 2 == 0 else -1.0
	for i in n_s + n_l:
		var is_sheet = i < n_s
		var cnt = n_s if is_sheet else n_l
		var idx = i if is_sheet else i - n_s
		var frac = (float(idx) + randf_range(0.0, 0.6)) / float(cnt)
		var ang = deg_to_rad(lerpf(-half_deg, half_deg, frac)) * sweep
		var dir = d.rotated(Vector3.UP, ang)
		var L = reach * randf_range(0.75, 1.0)
		var h0 = randf_range(-0.6, 0.6)
		var pts = FutonLib.path_pts(func(u: float) -> Vector3:
			var p = o + dir * L * u + Vector3.UP * (h0 * u + sin(u * PI) * 0.4)
			p.y = maxf(p.y, gy + 0.15)
			return p, 18)
		if is_sheet:
			FutonLib.sheet(pj, pts, 0.7 + k * 0.35, 0.55 + k * 0.1, FutonLib.AIR, {"grow": 0.4, "opacity": 0.5, "delay": frac * 0.12, "widths": _widen(18, 0.3, 1.5)})
		else:
			FutonLib.line(pj, pts, 0.05, 0.45, WHITE, {"grow": 0.4, "delay": frac * 0.12})
	var g = FutonLib.floor_at(o)
	FutonLib.scour(pj, g, d, reach * 0.9, minf(14.0, reach * tan(deg_to_rad(half_deg)) * 1.2), 2.5, 0)
	var gm = FutonLib.floor_at(o + d * reach * 0.4)
	FutonLib.bits(pj, gm + Vector3.UP * 0.3, 8 + 6 * k, "puff", {"box": Vector3(reach * 0.2, 0.2, reach * 0.2), "dir": (d + Vector3.UP * 0.3).normalized(),
		"spread": 30.0, "vmin": 6.0, "vmax": 12.0, "size": 1.1, "cols": FutonLib.dust_cols(gm), "life": 1.0, "damp": 2.0, "g": Vector3(0, -0.4, 0)})
	_kick(pj, gm + Vector3.UP * 0.5, 10 + 8 * k, (d + Vector3.UP * 0.4).normalized(), 6.0, 12.0, {"spread": 30.0, "radius": reach * 0.15})


static func _fan_storm(pj: PathJutsu, g: Vector3) -> void:
	for w in 3:
		_later(pj, w * 0.25, func():
			for i in 8:
				var pts = FutonLib.helix_pts(g + Vector3.UP * 0.2, Vector3.UP, 1.0, 6.5, 0.0, randf_range(1.0, 2.2), randf() * TAU, 1.2, 28)
				FutonLib.line(pj, pts, 0.07, 0.6, WHITE if i % 3 != 0 else FutonLib.MINT, {"grow": 0.5, "flow": 7.0})
			for i in 2:
				var ps = FutonLib.helix_pts(g + Vector3.UP * 0.3, Vector3.UP, 1.5, 5.5, 0.2, 1.4, randf() * TAU, 0.8, 22)
				FutonLib.sheet(pj, ps, 1.2, 0.7, FutonLib.AIR, {"grow": 0.45, "opacity": 0.45})
			for i in 3:
				var pc = FutonLib.helix_pts(g, Vector3.UP, 0.5, 1.2, 0.3, 5.0, randf() * TAU, 0.8, 16)
				FutonLib.line(pj, pc, 0.05, 0.5, WHITE, {"grow": 0.45})
			FutonLib.bits(pj, g + Vector3.UP * 0.3, 10, "puff", {"radius": 3.0, "tang": 20.0, "radial": 4.0, "dir": Vector3.UP, "spread": 25.0,
				"vmin": 1.0, "vmax": 3.0, "size": 1.2, "cols": FutonLib.dust_cols(g), "life": 1.0, "g": Vector3.ZERO}))
	FutonLib.scour(pj, g, Vector3.FORWARD, 12.0, 12.0, 3.5, 1)
	_kick(pj, g + Vector3.UP * 0.5, 16, Vector3.UP, 4.0, 9.0, {"spread": 50.0, "tang": 18.0, "radius": 2.0})


# ================================================================== 14. Nadeshiko-Ryū Kōha Senkai Giri (Kükreyen Kasırga Tekmesi)
## Ref: çarpan ayakta sarı-beyaz parıltı, arkada kalkan toz bulutları, kırılan parçalar.
## Görünüş: sıçrayıp dönerken çevresinde yatay yörüngede dönen üç büyük kesici hilal + yukarı açılan sarmal çizgiler;
## zeminde ışınsal süpürme ve dışa yayılan toz halkası, yere yatık bükülme; çarpınca ayak hizasında altın-beyaz parıltı.
static func nadeshiko_senkai_giri(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 3.0, 8.0 if tt else 2.0)
	pj.busy(c, 0.8)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		var at = c.global_position + Vector3.UP * 0.9
		_cutting_ring(pj, at)
		GroundFX.wind(at, 4.5)   # rüzgâr yanan zemini büyütür (eski patlamanın oyun etkisi)
		var hs = pj.hit(c, at, 3.8, pj.inf(c, "nadeshiko_senkai_giri", 1.3, {"knock": 10.0, "launch": 9.0, "kind": "heavy", "element": "fuuton"}))
		if not hs.is_empty():
			var hp = hs[0].global_position + Vector3.UP * 1.0
			var dd = (hp - at)
			dd.y = 0.0
			dd = dd.normalized() if dd.length() > 0.01 else c.face_dir()
			_glint(pj, hp, dd, 1.1, Color(1.0, 0.94, 0.7, 0.95))
			FutonLib.warp(pj, hp, 0.2, 1.4, 0.3, {"power": 1.2})
			pj.shake(0.6)
		Sfx.play("punch", at, 0.8))


static func _cutting_ring(pj: PathJutsu, at: Vector3) -> void:
	var piv = Node3D.new()
	pj.get_tree().current_scene.add_child(piv)
	piv.global_position = at
	for j in 3:
		var a = j * TAU / 3.0
		var pos = Vector3(cos(a), 0, sin(a)) * 2.4
		var tang = Vector3(sin(a), 0, -cos(a))
		FutonLib.blade(pj, pos, FutonLib.blade_basis(tang, Vector3.UP), 2.6, 0.5, FutonLib.AIR, {"parent": piv, "thick": 0.16, "wisp": 2.0, "grow": 0.2})
	var tw = piv.create_tween()
	tw.tween_property(piv, "rotation:y", TAU * 1.4, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(piv.queue_free)
	for j in 6:
		var pts = FutonLib.helix_pts(at + Vector3.DOWN * 0.6, Vector3.UP, 0.8, 4.4, 0.0, 1.3, j * TAU / 6.0, -0.55, 16)
		FutonLib.line(pj, pts, 0.05, 0.4, WHITE, {"grow": 0.45})
	var g = FutonLib.floor_at(at)
	if at.y - g.y < 3.0:
		FutonLib.scour(pj, g, Vector3.FORWARD, 9.0, 9.0, 3.0, 1)
		FutonLib.warp(pj, g + Vector3.UP * 0.1, 0.8, 4.6, 0.45, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.3})
		FutonLib.bits(pj, g + Vector3.UP * 0.2, 16, "puff", {"box": Vector3(0.6, 0.1, 0.6), "radial": 18.0, "dir": Vector3.UP, "spread": 20.0,
			"vmin": 1.0, "vmax": 3.0, "size": 0.9, "cols": FutonLib.dust_cols(g), "life": 1.0, "damp": 2.0, "g": Vector3.ZERO})
		_kick(pj, g + Vector3.UP * 0.3, 8, Vector3.UP, 3.0, 7.0, {"spread": 70.0, "radial": 8.0})


# ================================================================== 15. Gufū Bōha (Kasırga Perdesi)
## Görünüş: 4 sn boyunca kullanıcının çevresinde 2.6 m'de, alçak eğimle yukarı süzülen nane rengi hava perdeleri ve ince çizgiler
## (dar hortum değil, geniş çevresel perde), yörüngede dönen yapraklar / çakıl; ilk anda zemine yatık bükülme halkası.
## Savrulan her mermide küçük bükülme + mermiyle birlikte dışa kıvrılan iki çizgi.
static func gufu_boha(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	pj.every(4.0, 0.3, func(i, _k):
		if not pj.live(c):
			return
		var at = pj.gp(c.global_position)
		_gufu_curtain(pj, at, i)
		for e in pj.enemies_near(c, at, 3.6):
			if pj.live(e):
				var v = (e.global_position - at)
				v.y = 0
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "gufu_boha", 0.3, {"knock": 9.0, "kind": "light", "element": "fuuton", "dir": v.normalized()}))
		for pr in c.get_tree().get_nodes_in_group("projectiles"):
			if is_instance_valid(pr) and pr.get("shooter") != c and pr.global_position.distance_to(at + Vector3.UP) < 4.0:
				pr.vel = (pr.global_position - at).normalized() * pr.vel.length()
				_gufu_deflect(pj, pr.global_position, pr.vel), Callable())
	Sfx.play("wind", c.global_position, 0.8)


static func _gufu_curtain(pj: PathJutsu, at: Vector3, i: int) -> void:
	if i == 0:
		FutonLib.warp(pj, at + Vector3.UP * 0.1, 0.5, 3.2, 0.45, {"bill": false, "basis": FutonLib.flat_basis(), "power": 1.2, "swirl": 1.0})
	for j in 5:
		var a0 = j * TAU / 5.0 + i * 0.9
		var ps = FutonLib.helix_pts(at, Vector3.UP, 2.6, 2.3, 0.1, 3.8, a0, 0.3, 16)
		FutonLib.sheet(pj, ps, 0.8, 0.5, FutonLib.MINT, {"grow": 0.45, "opacity": 0.4})
		var pl = FutonLib.helix_pts(at, Vector3.UP, 2.8, 2.5, 0.2, 4.4, a0 + 0.6, 0.35, 16)
		FutonLib.line(pj, pl, 0.05, 0.45, WHITE, {"grow": 0.45})
	if i % 2 == 0:
		_kick(pj, at + Vector3.UP * 1.0, 6, Vector3.UP, 1.0, 2.5, {"radius": 2.4, "tang": 22.0, "spread": 20.0, "life": 1.0})
	if i % 4 == 0:
		FutonLib.scour(pj, at, Vector3.FORWARD, 6.0, 6.0, 1.5, 1)


static func _gufu_deflect(pj: PathJutsu, p: Vector3, v: Vector3) -> void:
	var dn = v.normalized() if v.length() > 0.01 else Vector3.UP
	FutonLib.warp(pj, p, 0.2, 1.2, 0.25, {"swirl": 2.5, "power": 1.0})
	var sd = FutonLib.side_of(dn)
	for s in [-1.0, 1.0]:
		var pts = FutonLib.path_pts(func(u: float) -> Vector3: return p + dn * u * 2.0 + sd * s * sin(u * PI) * 0.5, 8)
		FutonLib.line(pj, pts, 0.04, 0.3, FutonLib.MINT, {"grow": 0.4})
