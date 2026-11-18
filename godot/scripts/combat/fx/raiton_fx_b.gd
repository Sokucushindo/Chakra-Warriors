class_name RaitonFXB
extends RefCounted
## Raiton B grubu: 15 tekniğin görseli ve taşınmış oynanışı. Malzeme / yapı taşı RaitonLib'den; her tekniğin şekli,
## hareketi ve sahnelenmesi kendine özgü (A grubunun kompozisyonları kullanılmaz). Oynanış (hasar çağrıları, durumlar,
## süreler, menzil, mermi davranışı) ana ağaçtaki PathJutsu / Jutsu gövdelerinden satır satır taşındı.

const PURPLE := Color(0.75, 0.5, 1.0)
const RANSHIN := Color(0.5, 1.0, 0.6)
const NERVE := Color(1.0, 0.5, 0.18)
const YOROI := Color(0.95, 0.95, 0.6)

static var _armor_sh: Shader = null


# ═════════════════════════════════════════ ortak küçük parçalar ═════════════════════════════════════════

static func _cam() -> Vector3:
	return RaitonLib.cam_pos()


## Zemine yakın mı (yanık / yer arkı yalnız yere değen çarpmada)
static func _near_ground(p: Vector3, h := 1.8) -> bool:
	return p.y - Game.jutsu_floor(p.x, p.z) < h


## Düğümün çevresinde kısa süre dönen ışık (anlık ışıktan farklı: düğümü izler)
static func _held_light(parent: Node3D, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	parent.add_child(l)
	return l


# ═════════════════════════════════════════ Shichū Shibari (dört sütun) ═════════════════════════════════════════

## Kaynak: dört yüksek, köşeli, açık gri taş sütun; aralarında çapraz çakan şimşekler ve tam ortada dişli beyaz çakmalar.
static func _pillar(k: int) -> MeshInstance3D:
	var b = MB.new()
	var stone = Color(0.6, 0.63, 0.68)
	var shade = Color(0.45, 0.48, 0.54)
	b.add("boulder", Vector3(0, 2.2, 0), Vector3(1.0, 4.6, 1.0), stone, Vector3(0, k * 20.0, 0), 3 + k)
	b.add("box", Vector3(0.08, 4.65, -0.04), Vector3(0.78, 0.8, 0.7), shade, Vector3(6.0, k * 33.0, -5.0))
	b.add("cone", Vector3(0, 5.2, 0), Vector3(0.7, 0.9, 0.7), stone, Vector3(0, 15.0 * k, 0), 5)
	b.add("box", Vector3(0, 0.25, 0), Vector3(1.45, 0.55, 1.3), shade, Vector3(0, k * 41.0, 0))
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(null)
	mi.material_override = Props.rock_toon()
	return mi


## Sütunlar arasında gerili elektrik perdesi (dört panel): yanıp söner, sonunda kapanır
static func _cage(pts: Array, dur: float) -> void:
	for k in 4:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % 4]
		var L = a.distance_to(b)
		var x = (b - a).normalized()
		var q = QuadMesh.new()
		q.size = Vector2(L * 0.86, 3.4)
		var m = RaitonLib.mat("sheet", {"glow": RaitonLib.CYAN, "power": 0.0})
		var mi = RaitonLib.mi_of(q, m)
		RaitonLib.root().add_child(mi)
		mi.global_transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), (a + b) * 0.5 + Vector3.UP * 2.5)
		var tw = mi.create_tween()
		tw.tween_property(m, "shader_parameter/power", 0.75, 0.15)
		tw.tween_interval(maxf(dur - 0.45, 0.1))
		tw.tween_property(m, "shader_parameter/power", 0.0, 0.3)
		tw.tween_callback(mi.queue_free)


static func four_pillar_bind(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 20.0)
	pj.busy(c, 0.9)
	if tt == null:
		return
	var at = pj.gp(tt.global_position)
	var pts = []
	for k in 4:
		var a = k * TAU / 4.0 + PI * 0.25
		var q = at + Vector3(cos(a), 0, sin(a)) * 3.0
		pts.append(q)
		var p = _pillar(k)
		RaitonLib.root().add_child(p)
		p.global_position = q - Vector3.UP * 5.5
		var tw = p.create_tween()
		tw.tween_property(p, "global_position", q, 0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(4.0)
		tw.tween_property(p, "global_position", q - Vector3.UP * 5.5, 0.5)
		tw.tween_callback(p.queue_free)
		# zemini yararak çıkış: kırıntı fışkırır, dibinde toz halkası
		RaitonLib.debris(q, 10, 7.0)
		RaitonLib.dust_ring(q, 0.6, 2.4, 0.6)
	pj.st(tt, "bind", 4.0)
	# sütunlar oturunca perde gerilir; tepelerde kısa çatırtı
	pj.after(0.3, func():
		_cage(pts, 3.7)
		for k in 4:
			RaitonLib.crackle(Vector3(pts[k]) + Vector3.UP * 4.9, 0.8, 3.7, RaitonLib.RAI, 3, 0.035, 0.08))
	_cross_bolts(pj, pts, at)
	pj.every(4.0, 0.5, func(_i, _k):
		if pj.live(tt):
			tt.take_hit(pj.inf(c, "four_pillar_bind", 0.2, {"knock": 0.0, "kind": "light", "element": "raiton"}))
			RaitonLib.body_arcs(tt, 0.4, RaitonLib.RAI, 3, 0.035), Callable())
	pj.shake(0.5)
	Sfx.play("thunder", at, 0.8)


## Sütundan sütuna çapraz atlayan şimşekler; kesiştikleri ortada dişli çakmalar (kaynak görseldeki gibi)
static func _cross_bolts(pj: PathJutsu, pts: Array, at: Vector3) -> void:
	pj.every(4.0, 0.1, func(i, _k):
		if i < 3:
			return   # sütunlar daha yükseliyor
		for k in 2:
			var s = randi() % 4
			var a = Vector3(pts[s]) + Vector3.UP * randf_range(1.2, 4.4)
			var b2 = Vector3(pts[(s + 2) % 4 if randf() < 0.6 else (s + 1) % 4]) + Vector3.UP * randf_range(1.2, 4.4)
			RaitonLib.bolt(a, b2, RaitonLib.RAI, 0.1, 0.14, 2, 0.2)
		if i % 3 == 0:
			RaitonLib.flash(at + Vector3.UP * randf_range(1.6, 3.6) + RaitonLib.hdir() * randf_range(0.0, 1.2), randf_range(0.8, 1.4), RaitonLib.RAI, 0.12, 7.0), Callable())


# ═════════════════════════════════════════ Thunderbolt ═════════════════════════════════════════

## Kaynak: iki yana açılmış kollarda iki büyük beyaz şimşek küresi, kürelerden her yöne dallanan şimşek; ardından gökten
## hedef alanına dört ayrı yıldırım iner.
static func _sky_strike(q: Vector3) -> void:
	var top = q + Vector3.UP * 16.0 + RaitonLib.hdir() * randf_range(0.5, 2.0)
	RaitonLib.bolt(q + Vector3.UP * 16.0, q + Vector3.UP * 0.2, RaitonLib.EMAG, 0.06, 0.06, 0, 0.12, 0.06, 3)   # öncü kanal
	RaitonLib.bolt(top, q + Vector3.UP * 0.2, Color(0.82, 0.9, 1.0), 0.42, 0.32, 4, 0.16, 0.045, 5)
	RaitonLib.bolt(top + RaitonLib.hdir() * 0.6, q + Vector3.UP * 0.2 + RaitonLib.hdir() * 0.8, RaitonLib.CYAN, 0.12, 0.22, 2, 0.22)
	RaitonLib.flash(q + Vector3.UP * 0.5, 2.6, RaitonLib.RAI, 0.16, 11.0)
	RaitonLib.ground_arcs(q, 2.0, 0.5, RaitonLib.RAI, 6, 0.05)
	RaitonLib.sparks(q + Vector3.UP * 0.3, 18, RaitonLib.RAI, 9.0, 0.5, Vector3.UP, 0.9)
	RaitonLib.scorch(q, 1.5, RaitonLib.RAI, 5.0, 0.8)
	RaitonLib.dust_ring(q, 0.3, 2.2, 0.5)
	RaitonLib.light(q + Vector3.UP * 2.0, RaitonLib.PALE, 8.0, 14.0, 0.25)
	RaitonLib.wet_shock(q, 1.0)


static func thunderbolt(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 30.0)
	var at = pj.gp(tt.global_position if tt else c.global_position + pj.fwd(c, t) * 12.0)
	for right in [true, false]:
		var ba = pj.bone_attach(c, "RightHand" if right else "LeftHand")
		if ba:
			var o = RaitonLib.orb(0.3, Color(1, 1, 1), RaitonLib.CYAN, RaitonLib.PALE)
			ba.add_child(o)
			o.scale = Vector3.ONE * 0.1
			o.create_tween().tween_property(o, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
			RaitonLib.crackle(RaitonLib.follow_fn(ba), 1.2, 0.85, RaitonLib.RAI, 5, 0.04, 0.05, ba)
			pj.free_after(0.9, ba)
	RaitonLib.light(c.global_position + Vector3.UP * 1.4, RaitonLib.CYAN, 3.0, 8.0, 0.9)
	# kürelerden göğe uzanan dallı şimşek: gök yüklenir
	pj.after(0.15, func():
		if not pj.live(c):
			return
		for right in [true, false]:
			var h = RaitonLib.hand_fn(pj, c, right)
			RaitonLib.bolt(h, Vector3(h.call()) + Vector3.UP * 9.0 + RaitonLib.hdir() * 3.0, RaitonLib.PALE, 0.07, 0.22, 3, 0.25))
	for k in 4:
		pj.after(0.35 + k * 0.12, func():
			var q = at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			_sky_strike(q)
			pj.hit(c, q + Vector3.UP, 2.6, pj.inf(c, "thunderbolt", 0.5, {"knock": 6.0, "launch": 3.0, "kind": "heavy", "element": "raiton", "stun": 0.6})))
	pj.shake(0.6)
	Sfx.play("thunder", at, 0.7)


# ═════════════════════════════════════════ Kaminarimon: Denki Ito (elektrik teli) ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) İki ince metal kazık, tepelerinde küçük plazma düğüm; aralarında hafif sarkık, içinden
## akım nabızları koşan ince tel. Atanın elinden kazıklara fırlayarak gerilir, 8 sn uğuldar, sonunda kopup yere düşer.
static func _stake(top: Vector3, dur: float) -> void:
	var g = Game.jutsu_floor(top.x, top.z)
	var h = maxf(top.y - g, 0.3)
	var b = MB.new()
	b.add("cyl", Vector3(0, h * 0.5, 0), Vector3(0.07, h, 0.07), Color(0.24, 0.26, 0.3), Vector3.ZERO, 6)
	b.add("cone", Vector3(0, -0.08, 0), Vector3(0.09, 0.2, 0.09), Color(0.2, 0.21, 0.24), Vector3(180, 0, 0), 6)
	var mi = MeshInstance3D.new()
	mi.mesh = b.build(Props.toon())
	RaitonLib.root().add_child(mi)
	mi.global_position = Vector3(top.x, g, top.z)
	var o = RaitonLib.orb(0.08, Color(1, 1, 1), RaitonLib.EMAG, RaitonLib.PALE)
	mi.add_child(o)
	o.position = Vector3(0, h, 0)
	var tw = mi.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(mi, "scale", Vector3(1, 0.01, 1), 0.3)
	tw.tween_callback(mi.queue_free)


static func _wire(pj: PathJutsu, c: Node3D, a: Vector3, b: Vector3, dur: float) -> void:
	var wm = RaitonLib.web_mat(RaitonLib.EMAG)
	var am = RaitonLib.arc_mat(RaitonLib.EMAG)
	var src: Vector3 = pj.hand_pos(c, true)
	var stt = {"jt": 0.0, "jit": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > dur + 0.45:
			return false
		var cam = _cam()
		if age < 0.24:
			# gerilme: elden a'ya, sonra a'dan b'ye uzanır
			var f = age / 0.24
			var line = [src]
			if f < 0.5:
				line.append(src.lerp(a, f * 2.0))
			else:
				line.append(a)
				line.append(a.lerp(b, (f - 0.5) * 2.0))
			RaitonLib.draw(im, am, [{"p": line, "w": 0.05, "a": 1.0, "k": 2}], 1.0, cam)
			return true
		var n = 18
		if age >= float(stt["jt"]):
			stt["jt"] = age + 0.05
			var jj = []
			for i in n + 1:
				jj.append(RaitonLib.rdir() * 0.025)
			stt["jit"] = jj
		var jit: Array = stt["jit"]
		if age < dur:
			var pts = []
			for i in n + 1:
				var f = float(i) / n
				pts.append(a.lerp(b, f) + Vector3.DOWN * 0.6 * f * (1.0 - f) + Vector3(jit[i]) * sin(PI * f))
			RaitonLib.draw(im, wm, [{"p": pts, "w": 0.045, "a": 1.0, "k": 2}], 1.0, cam)
		else:
			# kopma: iki yarı kazıklardan aşağı sarkar, söner
			var f2 = (age - dur) / 0.45
			var mid = (a + b) * 0.5
			var halves = []
			for side in [a, b]:
				var tip = side.lerp(mid, 1.0 - f2 * 0.6) + Vector3.DOWN * (0.6 + f2 * 1.6)
				var hp = []
				for i in 9:
					var g = float(i) / 8.0
					hp.append(Vector3(side).lerp(tip, g) + Vector3.DOWN * 0.4 * g * (1.0 - g))
				halves.append({"p": hp, "w": 0.035, "a": 1.0 - f2, "k": 2})
			RaitonLib.draw(im, wm, halves, 1.0, cam)
		return true)
	_stake(a, dur)
	_stake(b, dur)
	# tel boyunca ara ara zıplayan kıvılcımlar
	pj.every(dur, 0.35, func(_i, _k):
		var f = randf()
		var p = a.lerp(b, f) + Vector3.DOWN * 0.6 * f * (1.0 - f)
		RaitonLib.sparks(p, 4, RaitonLib.EMAG, 3.0, 0.25, Vector3.UP, 1.0, 0.015), Callable())
	pj.after(dur, func():
		RaitonLib.flash((a + b) * 0.5 + Vector3.DOWN * 0.15, 1.0, RaitonLib.EMAG, 0.12, 8.0))


static func kaminarimon_denki_ito(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var d = pj.fwd(c, t)
	var side = d.cross(Vector3.UP).normalized()
	var a = pj.gp(c.global_position + d * 6.0 + side * 4.0) + Vector3.UP
	var b = pj.gp(c.global_position + d * 6.0 - side * 4.0) + Vector3.UP
	_wire(pj, c, a, b, 8.0)
	pj.every(8.0, 0.15, func(i, _k):
		if i % 3 == 0:
			RaitonLib.bolt(a, b, RaitonLib.EMAG, 0.05, 0.12, 1, 0.06)   # telden geçen akım dalgası
		for e in pj.enemies_near(c, (a + b) * 0.5, 4.5):
			var p = e.global_position + Vector3.UP
			var ab = b - a
			var tpar = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if (a + ab * tpar).distance_to(p) < 1.0:
				pj.st(e, "stun", 1.0)
				e.take_hit(pj.inf(c, "kaminarimon_denki_ito", 0.3, {"knock": 2.0, "kind": "light", "element": "raiton"}))
				RaitonLib.bolt(a + ab * tpar, p, RaitonLib.EMAG, 0.06, 0.12, 1, 0.3)
				RaitonLib.body_arcs(e, 0.35, RaitonLib.EMAG, 3, 0.03), Callable())
	Sfx.play("chidori", c.global_position, 1.6)


# ═════════════════════════════════════════ Kaminarimon: Raikō (şimşek hücumu) ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Atan yatay bir yıldırıma dönüşür: kalın, sert köşeli manga zikzakı + çevresinde ince
## kırılımlı teller; çıkışta ve inişte çakma; yerde kararan, bir süre közlenen kayma izi.
static func _raikou_streak(a: Vector3, b: Vector3, d: Vector3) -> void:
	var am = RaitonLib.arc_mat(RaitonLib.EMAG)
	var cm = RaitonLib.arc_mat(RaitonLib.PALE)
	var stt = {"next": 0.0, "polys": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > 0.45:
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var out = [{"p": RaitonLib.zigzag(a, b, 9, 0.55), "w": 0.24, "a": 1.0, "k": 2}]
			for k in 3:
				out.append({"p": RaitonLib.jag(a + RaitonLib.rdir() * 0.3, b + RaitonLib.rdir() * 0.3, 0.08, 5), "w": 0.04, "a": 0.8})
			stt["polys"] = out
		var f = 1.0 - age / 0.45
		RaitonLib.draw(im, am, stt["polys"], f, _cam())
		RaitonLib.draw(im, cm, [stt["polys"][0]], f * 0.6, _cam())
		return true)
	RaitonLib.flash(a, 2.2, RaitonLib.EMAG, 0.12, 8.0)
	RaitonLib.flash(b + d * 0.5, 2.8, RaitonLib.EMAG, 0.18, 12.0)
	# kayma izi: kararmış şerit + üstünde kısa süre közlenen ince akım çizgisi
	var ga = RaitonLib.floor_at(a)
	var gb = RaitonLib.floor_at(b)
	var path = RaitonLib.ground_path(ga, gb, 0.025, 4, 0.04)
	var dm = RaitonLib.dust_mat(Color(0.1, 0.1, 0.12))
	var wm = RaitonLib.web_mat(RaitonLib.EMAG)
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > 3.0:
			return false
		var f = clampf(age / 0.08, 0.0, 1.0)
		var cut = maxi(2, int(path.size() * f))
		var pp = path.slice(0, cut)
		RaitonLib.draw(im, dm, [{"p": pp, "w": 0.3, "a": 1.0, "k": 2}], clampf((3.0 - age) / 1.0, 0.0, 1.0), _cam(), true)
		RaitonLib.draw(im, wm, [{"p": pp, "w": 0.07, "a": 1.0, "k": 2}], clampf((0.9 - age) / 0.6, 0.0, 1.0), _cam(), true)
		return true)
	RaitonLib.debris(gb, 8, 6.0, Color(0.42, 0.38, 0.33), d)
	RaitonLib.dust_ring(gb, 0.4, 2.2, 0.5)


static func kaminarimon_raikou(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.5)
	var d = pj.fwd(c, t)
	var start = c.global_position
	var end = pj.gp(start + d * 16.0)
	_raikou_streak(start + Vector3.UP, end + Vector3.UP, d)
	c.global_position = end
	Combat.hit_zone(c, start, d, 16.0, 10.0, 2.0, pj.inf(c, "kaminarimon_raikou", 1.4, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 0.5}))
	Sfx.play("thunder", c.global_position, 1.4)


# ═════════════════════════════════════════ Kaminarimon: Raikyū Ame (şimşek küresi yağmuru) ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Hedef alanın 14 m üstünde geniş bir ark ağı çatırdar; küreler oradan doğar, kuyruklu
## düşer, yere değince ezilip yassı bir plazma diskine yayılır, çevresinde yer arkları kalır.
static func _ball_splat(q: Vector3) -> void:
	var m = RaitonLib.plasma_mat(Color(1, 1, 1), RaitonLib.EMAG, RaitonLib.PALE)
	var mi = RaitonLib.mi_of(RaitonLib.sphere_mesh(), m)
	RaitonLib.root().add_child(mi)
	mi.global_position = q + Vector3.UP * 0.25
	mi.scale = Vector3.ONE * 0.8
	var tw = mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(3.2, 0.18, 3.2), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "shader_parameter/power", 0.0, 0.28)
	tw.chain().tween_callback(mi.queue_free)
	RaitonLib.ground_arcs(q, 1.5, 0.4, RaitonLib.EMAG, 5, 0.04)
	RaitonLib.sparks(q + Vector3.UP * 0.2, 8, RaitonLib.EMAG, 6.0, 0.35, Vector3.UP, 1.2)
	RaitonLib.scorch(q, 0.9, RaitonLib.EMAG, 4.0, 0.6)
	RaitonLib.light(q + Vector3.UP, RaitonLib.EMAG, 4.0, 7.0, 0.18)


static func kaminarimon_raikyu_ame(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var at = pj.gp(Jutsu._aim_ground(c, t, 10.0, 20.0))
	RaitonLib.crackle(at + Vector3.UP * 14.0, 4.5, 1.4, RaitonLib.EMAG, 7, 0.05, 0.08)
	for k in 10:
		pj.after(0.2 + k * 0.1, func():
			var q = at + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			var ball = RaitonLib.orb(0.4, Color(1, 1, 1), RaitonLib.EMAG, RaitonLib.PALE)
			RaitonLib.root().add_child(ball)
			ball.global_position = q + Vector3.UP * 14.0
			RaitonLib.trail(ball, RaitonLib.EMAG, 0.2, 0.12, 0.05)
			RaitonLib.crackle(RaitonLib.follow_fn(ball), 0.7, 0.5, RaitonLib.EMAG, 3, 0.03, 0.05, ball)
			var tw = ball.create_tween()
			tw.tween_property(ball, "global_position", q + Vector3.UP * 0.4, 0.35).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				_ball_splat(q)
				pj.hit(c, q + Vector3.UP, 2.2, pj.inf(c, "kaminarimon_raikyu_ame", 0.6, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.3})))
			tw.tween_callback(ball.queue_free))
	Sfx.play("thunder", at, 0.9)


# ═════════════════════════════════════════ Raigeki no Yoroi (Raikage zırhı) ═════════════════════════════════════════

## Kaynak: Raikage'nin bütün bedeni beyaz-sarı parlayan şimşek zırhıyla sarılı, silueti kalın ışıkla şişkin, ayağının
## altında zemin çöker. Bedenin kendi derili örgüsünün büyütülmüş kopyası (iki kat: parlak iç kabuk + titreşen dış hâle),
## kendi gölgelendiricisiyle; gövdede çatırtı, ayak dibinde yer arkları.
const SH_ARMOR := """
uniform vec4 glow : source_color = vec4(1.0, 0.98, 0.75, 1.0);
uniform float grow = 0.08;
uniform float power = 1.0;
uniform float jitter = 0.3;
varying vec3 lp;
void vertex() {
	float st = floor(TIME * 14.0);
	float j = rh3(floor(VERTEX * 9.0) + vec3(st));
	VERTEX += NORMAL * grow * (1.0 + jitter * (j - 0.5) * 2.0);
	lp = VERTEX;
}
void fragment() {
	float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float st = floor(TIME * 15.0);
	float n = rn3(lp * 6.0 + vec3(st * 0.31, -TIME * 3.0, st * 0.53));
	float vein = 1.0 - smoothstep(0.0, 0.045, abs(n - 0.5));
	float rim = step(0.5, fr);
	vec3 col = glow.rgb * (0.3 + rim * 1.1) + vec3(1.0) * vein * 1.1;
	ALBEDO = col * power;
}
"""


static func _armor_shader() -> Shader:
	if _armor_sh == null:
		_armor_sh = Shader.new()
		_armor_sh.code = "shader_type spatial;\nrender_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled;\n" + RaitonLib.SH_NOISE + "\n" + SH_ARMOR
	return _armor_sh


static func _armor_shell(pj: PathJutsu, c: Node3D, col: Color, dur: float, grow: float, power: float, jitter: float) -> MeshInstance3D:
	var m = c.get("model")
	if m == null or not m.get("body_mesh") or m.body_mesh == null or m.skel == null:
		return null
	var mt = ShaderMaterial.new()
	mt.shader = _armor_shader()
	mt.set_shader_parameter("glow", col)
	mt.set_shader_parameter("grow", grow)
	mt.set_shader_parameter("jitter", jitter)
	mt.set_shader_parameter("power", 0.0)
	var cm = MeshInstance3D.new()
	cm.mesh = m.body_mesh.mesh
	m.skel.add_child(cm)
	cm.skin = m.body_mesh.skin
	cm.skeleton = cm.get_path_to(m.skel)
	cm.material_override = mt
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw = cm.create_tween()
	tw.tween_property(mt, "shader_parameter/power", power, 0.25)
	tw.tween_interval(maxf(dur - 0.6, 0.1))
	tw.tween_property(mt, "shader_parameter/power", 0.0, 0.35)
	pj.free_after(dur, cm)
	return cm


static func raigeki_no_yoroi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.5)
	var col = YOROI
	_armor_shell(pj, c, Color(1.0, 0.98, 0.75), 12.0, 0.05, 1.0, 0.2)
	_armor_shell(pj, c, Color(0.75, 0.88, 1.0), 12.0, 0.13, 0.55, 0.6)
	# ateşleme: ayak altında zemin çöker (yanık + kırıntı + toz), göğüste dev çakma
	var g = pj.gp(c.global_position)
	RaitonLib.flash(c.global_position + Vector3.UP * 1.1, 3.2, col, 0.2, 13.0)
	RaitonLib.scorch(g, 2.0, col, 6.0, 1.5)
	RaitonLib.debris(g, 12, 6.0)
	RaitonLib.dust_ring(g, 0.5, 3.4, 0.7)
	RaitonLib.light(c.global_position + Vector3.UP, col, 6.0, 10.0, 0.6)
	var body = RaitonLib.crackle(RaitonLib.follow_fn(c, Vector3.UP * 1.0), 1.1, 12.0, col, 6, 0.045, 0.05, c)
	if c is Player:
		Buffs.add("raigeki_no_yoroi", 12.0, {"armor": 0.75})
	pj.every(12.0, 0.3, func(i, _k):
		if not pj.live(c):
			return
		if i % 2 == 0:
			RaitonLib.ground_arcs(pj.gp(c.global_position), 1.1, 0.4, col, 3, 0.035)
		for e in pj.enemies_near(c, c.global_position, 1.8):
			if pj.live(e):
				var v = e.global_position - c.global_position
				v.y = 0
				RaitonLib.bolt(c.global_position + Vector3.UP, e.global_position + Vector3.UP, col, 0.15, 0.12, 2)
				RaitonLib.flash(e.global_position + Vector3.UP, 1.1, col, 0.1, 9.0)
				pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.3, pj.inf(c, "raigeki_no_yoroi", 0.2, {"knock": 10.0, "kind": "heavy", "element": "raiton", "stun": 0.5, "dir": v.normalized()})), func():
		if is_instance_valid(body):
			body.queue_free())
	Sfx.play("chidori", c.global_position, 1.0)


# ═════════════════════════════════════════ Denkō Sekka (şimşek adımı) ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Kalkışta yerden yukarı tek dikey kıvılcım çizgisi ve geriye saçılan kıvılcım; yol boyunca
## arka arkaya sönen küçük çakma noktaları ve onları bağlayan iki ince düz ışık çizgisi (zikzak değil); varışta ayak
## dibinde halka gibi açılan kısa yer arkları.
static func _blink_chain(a: Vector3, b: Vector3) -> void:
	var d = (b - a)
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	RaitonLib.bolt(RaitonLib.floor_at(a) + Vector3.UP * 0.05, a + Vector3.UP * 1.8, RaitonLib.PALE, 0.07, 0.12, 0, 0.06)
	RaitonLib.sparks(a, 20, RaitonLib.RAI, 9.0, 0.35, -d, 0.6)
	for k in 6:
		var f = float(k) / 5.0
		RaitonLib.flash(a.lerp(b, f) + Vector3.UP * randf_range(-0.2, 0.2), 0.5 + f * 0.9, RaitonLib.RAI, 0.08 + f * 0.12, 6.0)
	var m = RaitonLib.arc_mat(RaitonLib.PALE)
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > 0.3:
			return false
		var f = 1.0 - age / 0.3
		var off = Vector3.UP * 0.22
		RaitonLib.draw(im, m, [{"p": [a + off, b + off], "w": 0.03, "a": 1.0, "k": 1}, {"p": [a - off, b - off], "w": 0.03, "a": 0.7, "k": 1}], f, _cam())
		return true)
	RaitonLib.ground_arcs(RaitonLib.floor_at(b), 1.4, 0.4, RaitonLib.RAI, 6, 0.04)


static func denko_sekka(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.3)
	var tt = pj.tg(c, t, 18.0)
	var a = c.global_position
	var b = pj.gp((tt.global_position - (tt.global_position - a).normalized() * 1.5) if tt else a + c.face_dir() * 14.0)
	_blink_chain(a + Vector3.UP, b + Vector3.UP)
	c.global_position = b
	RaitonLib.speed_lines(c, b - a, 0.3)
	RaitonLib.light(b + Vector3.UP, RaitonLib.RAI, 6.0, 10.0, 0.2)
	for e in pj.enemies_near(c, a.lerp(b, 0.5), a.distance_to(b) * 0.5 + 1.5):
		if pj.live(e):
			pj.hit(c, e.global_position + Vector3.UP, e.radius + 0.4, pj.inf(c, "denko_sekka", 0.8, {"knock": 4.0, "kind": "heavy", "element": "raiton", "stun": 0.6}))
	Sfx.play("chidori", b, 1.6, 0.5)


# ═════════════════════════════════════════ Raisenshō (şimşek çapraz el bıçağı) ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Elde yük; vuruşta önde X biçiminde iki çapraz şimşek kesiği (biri ötekinden bir an sonra
## süpürülür), merkezde çakma; sonra şimşek düşmandan düşmana sıçrar (her sıçrayışta küçük çakma).
static func _cross_slash(at: Vector3, d: Vector3) -> void:
	var side = d.cross(Vector3.UP).normalized()
	var lines = [[at + side * 1.3 + Vector3.UP * 1.0, at - side * 1.3 - Vector3.UP * 1.0], [at - side * 1.3 + Vector3.UP * 1.0, at + side * 1.3 - Vector3.UP * 1.0]]
	var am = RaitonLib.arc_mat(RaitonLib.RAI)
	var stt = {"next": 0.0, "thr": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > 0.36:
			return false
		var polys = []
		for k in 2:
			var t0 = 0.05 * k
			var sw = clampf((age - t0) / 0.06, 0.0, 1.0)
			if sw <= 0.0:
				continue
			var p0: Vector3 = lines[k][0]
			var p1: Vector3 = lines[k][1]
			var fade = clampf(1.0 - (age - t0 - 0.06) / 0.24, 0.0, 1.0)
			polys.append({"p": [p0, p0.lerp(p1, 0.5 * sw), p0.lerp(p1, sw)], "w": 0.17, "a": fade, "k": 0})
		if age >= float(stt["next"]):
			stt["next"] = age + 0.05
			var thr = []
			for k in 2:
				thr.append({"p": RaitonLib.jag(lines[k][0], lines[k][1], 0.12, 4), "w": 0.04, "a": 0.8})
			stt["thr"] = thr
		RaitonLib.draw(im, am, polys, 1.0, _cam())
		if age > 0.1:
			RaitonLib.draw(im, am, stt["thr"], clampf((0.36 - age) / 0.2, 0.0, 1.0), _cam())
		return true)
	RaitonLib.flash(at, 2.0, RaitonLib.RAI, 0.14, 10.0)
	RaitonLib.sparks(at, 16, RaitonLib.RAI, 10.0, 0.35, d, 0.5)


static func raisensho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj._jump_at(c, tt, 0.0, 12.0 if tt else 3.0)
	pj.busy(c, 0.6)
	RaitonLib.hand_charge(pj, c, 0.5, RaitonLib.RAI, 1.0)
	pj.after(0.22, func():
		if not pj.live(c):
			return
		pj.anim(c, "cross", 1.6)
		var at = c.global_position + Vector3.UP * 1.2 + c.face_dir() * 1.2
		var hits = pj.hit(c, at, 2.0, pj.inf(c, "raisensho", 1.4, {"knock": 12.0, "kind": "heavy", "element": "raiton", "stun": 1.0}))
		_cross_slash(at, c.face_dir())
		var last = at
		for e in pj.enemies_near(c, at, 9.0):   # zincir şimşek
			if pj.live(e) and not hits.has(e):
				var ep = e.global_position + Vector3.UP
				RaitonLib.bolt(last, ep, RaitonLib.RAI, 0.14, 0.28, 1, 0.22)
				RaitonLib.flash(ep, 0.9, RaitonLib.RAI, 0.1, 7.0)
				pj.hit(c, ep, e.radius + 0.3, pj.inf(c, "raisensho", 0.5, {"knock": 3.0, "kind": "heavy", "element": "raiton", "stun": 0.6}))
				last = ep
		Sfx.play("punch", at, 0.9))


# ═════════════════════════════════════════ Chidori ═════════════════════════════════════════

## Kaynak: çömelmiş atanın elinde göz alıcı beyaz öz, çevresinde kola ve yere uzanan çok sayıda cıvıldayan dallı ark;
## el yere sürterek koşulur (zeminde kesik / kıvılcım), çarpışta şimşek hedefin içinden arkaya fışkırır.
static func _chidori_hand(c: Node3D) -> Node3D:
	var hand: Node3D = Node3D.new()
	Jutsu._palm(c, hand)
	var o = RaitonLib.orb(0.15, Color(1, 1, 1), RaitonLib.PALE, RaitonLib.CYAN)
	hand.add_child(o)
	# cıvıltı: sık, kısa, kesik kesik çakan arklar + daha seyrek uzun kollar
	RaitonLib.crackle(RaitonLib.follow_fn(hand), 0.55, 30.0, RaitonLib.RAI, 8, 0.035, 0.035, hand)
	RaitonLib.crackle(RaitonLib.follow_fn(hand), 1.3, 30.0, RaitonLib.CYAN, 4, 0.03, 0.08, hand)
	_hand_chirp(hand)
	_held_light(hand, RaitonLib.CYAN, 2.6, 7.0)
	Sfx.play("chidori", c.global_position)
	return hand


## Elde küçük beyaz çakmaların hızlı ardışığı (bin kuşun cıvıltısı)
static func _hand_chirp(hand: Node3D) -> void:
	var stt = {"next": 0.0}
	var p = RaitonLib.Pulse.new()
	p.fn = func(_node, _dt, age) -> bool:
		if not is_instance_valid(hand) or not hand.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + randf_range(0.05, 0.11)
			RaitonLib.flash(Vector3.ZERO, randf_range(0.35, 0.6), RaitonLib.RAI, 0.06, randf_range(6.0, 10.0), hand)
		return true
	hand.add_child(p)


## Elin zemine sürttüğü yol: kararmış ince kesik + üstünde kısa süre parlayan akım çizgisi
static func _gouge(stt: Dictionary) -> void:
	var dm = RaitonLib.dust_mat(Color(0.12, 0.11, 0.12))
	var wm = RaitonLib.web_mat(RaitonLib.RAI)
	var mem = {"end": -1.0}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if bool(stt["done"]) and float(mem["end"]) < 0.0:
			mem["end"] = age
		var since = age - float(mem["end"]) if float(mem["end"]) >= 0.0 else 0.0
		if since > 2.5 or age > 6.0:
			return false
		var pts: Array = stt["pts"]
		if pts.size() < 2:
			return true
		RaitonLib.draw(im, dm, [{"p": pts, "w": 0.14, "a": 1.0, "k": 1}], clampf((2.5 - since) / 1.0, 0.0, 1.0), _cam(), true)
		RaitonLib.draw(im, wm, [{"p": pts, "w": 0.05, "a": 1.0, "k": 1}], clampf((0.7 - since) / 0.5, 0.0, 1.0), _cam(), true)
		return true)


static func _chidori_dash(pj: PathJutsu, c: Node3D, t: Node3D, hand: Node3D, charge: float, speed: float, info: Dictionary, col: Color) -> void:
	var tid: int = t.get_instance_id() if is_instance_valid(t) else 0   # silinen hedefi yakalamasın
	var tw = c.create_tween()
	tw.tween_interval(charge)
	var state = {"t": 0.0, "done": false}
	var gg = {"pts": [], "done": false}
	tw.tween_callback(func():
		if not is_instance_valid(c):
			return
		var timer = Timer.new()
		timer.wait_time = 1.0 / 60.0
		c.add_child(timer)
		timer.timeout.connect(func():
			var tt = instance_from_id(tid) if tid != 0 and is_instance_id_valid(tid) else null
			state["t"] += 1.0 / 60.0
			if state["done"] or not is_instance_valid(c):
				gg["done"] = true
				timer.queue_free()
				return
			var d: Vector3
			if c is Player:
				d = Jutsu._aim_flat(c, tt)
				c.facing = atan2(-d.x, -d.z)
			elif tt and is_instance_valid(tt) and not tt.is_dead():
				d = (tt.global_position - c.global_position)
				d.y = 0
				d = d.normalized()
				c.facing = atan2(-d.x, -d.z) if c is Player else c.facing
			else:
				d = c.face_dir()
			c.velocity = d * speed
			if c is Player:
				c.combat.action = "cast"
				c.combat.t = -10.0
			if c.get("model"):
				# kaymadan koşar: bacaklar koşu animasyonunda, sağ kol geride aşağıda
				if not state.has("ran"):
					state["ran"] = true
					Jutsu._pose_chidori_run(c)
				c.model.play("run", 0.08, 1.9)
			if not state.has("trail") and is_instance_valid(hand):
				state["trail"] = RaitonLib.trail(hand, col.lightened(0.3), 0.2, 0.25, 0.1)
				state["last"] = hand.global_position
				_gouge(gg)
				if c is Player:
					RaitonLib.speed_lines(c, d, 0.6, RaitonLib.PALE, 10)
			# el yere sürtünür: zeminde kesik, kıvılcım
			if is_instance_valid(hand):
				var hg = pj.gp(hand.global_position)
				(gg["pts"] as Array).append(hg + Vector3.UP * 0.05 + RaitonLib.hdir() * 0.04)
				if int(state["t"] * 60.0) % 4 == 0:
					RaitonLib.sparks(hg + Vector3.UP * 0.1, 4, col, 5.0, 0.3, Vector3.UP - d, 0.7, 0.018)
			# arkada çatırdayan şimşek izi
			if String(info.get("element", "")) == "raiton" and is_instance_valid(hand) and state.has("last") and int(state["t"] * 60.0) % 3 == 0:
				var hp = hand.global_position
				RaitonLib.bolt(hp, Vector3(state["last"]) + Vector3(randf_range(-0.4, 0.4), randf_range(-0.6, 0.3), randf_range(-0.4, 0.4)), col.lightened(0.3), 0.07, 0.15, 1)
				state["last"] = hp
			var pt = c.global_position + Vector3.UP * 1.1 + d * 1.0
			var hits = Combat.hit_sphere(c, pt, 1.0, info)
			if not hits.is_empty() or state["t"] > 0.6:
				state["done"] = true
				gg["done"] = true
				Jutsu._palm_release(c)
				if is_instance_valid(c) and c.get("model") and c.model.get("overlay"):
					c.model.overlay.set_pose("cast", 0.0)
				if c is Player:
					c.combat.action = ""
				c.velocity = Vector3.ZERO
				if not hits.is_empty():
					_chidori_pierce(pj, pt, d, col)
					Sfx.play("boom", pt, 1.2)
				var h = hand
				if is_instance_valid(h):
					var tw2 = h.create_tween()
					tw2.tween_property(h, "scale", Vector3.ONE * 0.01, 0.2)
					tw2.tween_callback(h.queue_free)
				timer.queue_free())
		timer.start())


## Delip geçen şimşek: hedefin arkasına fışkıran dallı şimşekler, büyük çakma, öne saçılan kıvılcım, yerde yanık ve kırıntı
static func _chidori_pierce(pj: PathJutsu, pt: Vector3, d: Vector3, col: Color) -> void:
	for k in 6:
		var dd = (d * 1.4 + RaitonLib.rdir() * 0.9).normalized()
		RaitonLib.bolt(pt, pt + dd * randf_range(4.0, 8.0), col, 0.18, 0.28, 2, 0.2)
	RaitonLib.flash(pt, 3.2, RaitonLib.RAI, 0.18, 12.0)
	RaitonLib.sparks(pt, 40, RaitonLib.RAI, 16.0, 0.55, d, 0.6)
	var g = RaitonLib.floor_at(pt)
	RaitonLib.scorch(g, 2.4, RaitonLib.RAI, 6.0, 1.2)
	RaitonLib.debris(g, 8, 11.0, Color(0.5, 0.42, 0.32), d)
	RaitonLib.light(pt, col, 12.0, 20.0, 0.5)
	pj.shake(1.0)


static func raiton_chidori(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var m = Jutsu._mult(c) * Jutsu._elem_bonus(c, "raiton")
	var hand = _chidori_hand(c)
	# anime hazırlık: çömelir, sağ el yere yakın önde (şimşek yeri dağlar), sol el çaprazdan sağ bileği tutar
	Jutsu._pose_chidori_charge(c)
	_chidori_dash(pj, c, t, hand, 0.55, 30.0, {"dmg": 34.0 * m, "element": "raiton", "knock": 14.0, "launch": 3.0, "kind": "heavy", "hitstop": 0.12, "stun": 1.0},
		Color(0.5, 0.75, 1.0))
	# hazırlıkta elden yere inen arklar ve zeminde sıçrayan kıvılcım; sonunda ayak dibinde dağlanmış iz
	pj.every(0.55, 0.05, func(_i, _k):
		if pj.live(c):
			var g = pj.gp(c.global_position) + Vector3.UP * 0.05
			var gq = g + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			RaitonLib.bolt(RaitonLib.hand_fn(pj, c), gq, Color(0.6, 0.85, 1.0), 0.07, 0.12, 1, 0.25)
			if randf() < 0.5:
				RaitonLib.sparks(gq, 3, RaitonLib.RAI, 4.0, 0.3, Vector3.UP, 0.8, 0.015), Callable())
	pj.after(0.55, func():
		if pj.live(c):
			RaitonLib.scorch(pj.gp(c.global_position), 1.4, RaitonLib.RAI, 5.0, 0.6))


# ═════════════════════════════════════════ Kuroi Kaminari (kara şimşek) ═════════════════════════════════════════

## Kaynak (Darui): kalın, opak siyah şimşek şeritleri; kenarlarında ince beyaz kontur, içlerinde beyaz kılcal damarlar,
## arkasında soluk beyaz hâle. Hazırlıkta ele beyaz kıvılcımlar çekilir; çarpışta hedefin çevresine siyah dallar ve beyaz
## dişli çakma, gövdesinde bir an kara çatırtı.
static func _dark_body(t: Node3D, dur: float) -> void:
	if not RaitonLib.alive(t):
		return
	var m = RaitonLib.dark_mat(RaitonLib.PALE)
	var tw = weakref(t)
	var hgt = float(t.get("height")) if t.get("height") != null else 1.8
	var stt = {"next": 0.0, "polys": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		var x = tw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + 0.06
			var out = []
			var base: Vector3 = x.global_position
			for k in 3:
				var s = base + Vector3.UP * randf_range(0.2, hgt) + RaitonLib.hdir() * 0.5
				RaitonLib.fork(s, s + RaitonLib.rdir() * randf_range(0.6, 1.2), 0.3, 3, 1, out, 0.06, 1.0)
			stt["polys"] = out
		RaitonLib.draw(im, m, stt["polys"], 1.0, _cam())
		return true)


static func kuroi_kaminari(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 24.0)
	var dm = RaitonLib.dark_mat(RaitonLib.PALE)
	RaitonLib.converge(RaitonLib.hand_fn(pj, c), 1.4, 0.3, Color(0.9, 0.9, 0.95), 12)
	RaitonLib.bolt_m(RaitonLib.hand_fn(pj, c), Vector3(pj.hand_pos(c, true)) + Vector3.UP * 0.5, dm, 0.05, 0.3, 2, 0.6, 0.06, 3)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var end = from + pj.aim_at(c, tt, from) * 22.0
		# soluk hâle (arkada), sonra kalın siyah gövde + ikinci kol
		RaitonLib.bolt(from, end, Color(0.55, 0.55, 0.7), 0.9, 0.35, 0, 0.1, 0.07, 4)
		RaitonLib.bolt_m(from, end, dm, 0.55, 0.5, 5, 0.14, 0.07, 5)
		RaitonLib.bolt_m(from + Vector3.UP * 0.3, end + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.8), randf_range(-1, 1)), dm, 0.3, 0.45, 2, 0.18, 0.07, 4)
		Combat.hit_zone(c, c.global_position, pj.aim_at(c, tt, from), 22.0, 6.0, 3.0, pj.inf(c, "kuroi_kaminari", 2.2, {"knock": 14.0, "kind": "heavy", "element": "raiton", "stun": 1.0, "hitstop": 0.1}))
		if tt:
			var hp = tt.global_position + Vector3.UP
			for k in 5:
				RaitonLib.bolt_m(hp, hp + Vector3(randf_range(-2.5, 2.5), randf_range(-0.5, 2.5), randf_range(-2.5, 2.5)), dm, 0.2, 0.35, 1, 0.22)
			RaitonLib.flash(hp, 2.0, Color(1, 1, 1), 0.15, 9.0)
			_dark_body(tt, 0.6)
			if _near_ground(hp, 2.5):
				RaitonLib.scorch(RaitonLib.floor_at(hp), 1.8, Color(0.9, 0.92, 1.0), 5.0, 0.8)
		RaitonLib.light(from, Color(0.8, 0.8, 0.9), 4.0, 9.0, 0.3)
		pj.shake(0.7)
		Sfx.play("thunder", from, 0.7))


# ═════════════════════════════════════════ Ranshinshō (sinir karıştırma) ═════════════════════════════════════════

## Kaynak: bedenin sinir haritası — omurga boyunca kalın turuncu hat, kaburgalara, kollara, bacaklara inen ince turuncu
## sinirler, birkaç noktada parlayan camgöbeği "bozulma" yıldızı. Avuç vuruşu küçük ve keskin (patlama değil); isabet
## eden hedefin bedeninde sinir haritası sersemleme boyunca yanar, ardından yavaşlamada ara ara seğirme arkları.
static func _nerve_map(t: Node3D, dur: float) -> void:
	if not RaitonLib.alive(t):
		return
	var wm = RaitonLib.web_mat(NERVE)
	var tw = weakref(t)
	var hgt = float(t.get("height")) if t.get("height") != null else 1.8
	var rad = float(t.get("radius")) if t.get("radius") != null else 0.45
	var stt = {"next": 0.0, "polys": [], "pt": 0.0}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		var x = tw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		var base: Vector3 = x.global_position
		var bs: Basis = x.global_transform.basis.orthonormalized()
		var sd: Vector3 = bs.x
		var fw: Vector3 = -bs.z * rad * 1.05   # gövdenin önünde (bedenin üstüne çizilmiş gibi)
		if age >= float(stt["next"]):
			stt["next"] = age + 0.1
			var o = []
			var neck = base + Vector3.UP * hgt * 0.84 + fw
			var pel = base + Vector3.UP * hgt * 0.5 + fw
			o.append({"p": RaitonLib.jag(base + Vector3.UP * hgt * 0.95 + fw * 0.8, pel, 0.03, 3), "w": 0.035, "a": 1.0, "k": 2})   # omurga
			for s in [-1.0, 1.0]:
				var sh = neck + sd * s * rad * 0.9
				o.append({"p": RaitonLib.jag(neck, sh, 0.1, 2), "w": 0.02, "a": 0.9})
				o.append({"p": RaitonLib.jag(sh, sh + sd * s * rad * 0.35 + Vector3.DOWN * hgt * 0.38, 0.08, 3), "w": 0.018, "a": 0.9})   # kol
				var hip = pel + sd * s * rad * 0.35
				o.append({"p": RaitonLib.jag(hip, base + Vector3.UP * 0.05 + sd * s * rad * 0.45 + fw * 0.6, 0.06, 3), "w": 0.02, "a": 0.9})   # bacak
				for r in 3:
					var y = hgt * (0.78 - r * 0.07)
					var sp = base + Vector3.UP * y + fw
					o.append({"p": RaitonLib.jag(sp, sp + sd * s * rad * 0.75 + Vector3.DOWN * 0.06, 0.12, 2), "w": 0.014, "a": 0.8})   # kaburga
			stt["polys"] = o
		if age >= float(stt["pt"]):
			stt["pt"] = age + randf_range(0.25, 0.45)
			var q = base + Vector3.UP * randf_range(0.35, hgt * 0.85) + sd * randf_range(-rad, rad) + fw * 1.1
			RaitonLib.flash(q, 0.32, RaitonLib.CYAN, 0.18, 4.0)
		RaitonLib.draw(im, wm, stt["polys"], clampf((dur - age) / 0.3, 0.0, 1.0), _cam())
		return true)


## Yavaşlama boyunca ara ara kısa seğirme arkları
static func _twitch(t: Node3D, dur: float) -> void:
	if not RaitonLib.alive(t):
		return
	var tw = weakref(t)
	var stt = {"next": 0.2}
	RaitonLib.pulse(Vector3.ZERO, func(_node, _dt, age) -> bool:
		var x = tw.get_ref()
		if age > dur or x == null or not is_instance_valid(x) or not x.is_inside_tree():
			return false
		if age >= float(stt["next"]):
			stt["next"] = age + randf_range(0.5, 0.9)
			RaitonLib.body_arcs(x, 0.14, RANSHIN, 2, 0.022)
		return true)


static func ranshinsho(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	var tt = pj.tg(c, t, 6.0)
	pj.busy(c, 0.6)
	pj.anim(c, "jab", 1.6)
	var p = pj.hand_pos(c, true)
	# keskin, küçük avuç vuruşu: parmak uçlarında yeşil-beyaz iğne çakması, kısa çatırtı, ince kıvılcım
	RaitonLib.flash(p + c.face_dir() * 0.4, 0.9, RANSHIN, 0.12, 6.0)
	RaitonLib.crackle(RaitonLib.hand_fn(pj, c), 0.45, 0.35, RANSHIN, 5, 0.03, 0.04)
	RaitonLib.sparks(p, 14, RANSHIN, 5.0, 0.3, c.face_dir(), 0.5, 0.015)
	Sfx.play("chidori", p, 1.6, 0.4)
	if tt and tt.global_position.distance_to(c.global_position) < 4.0:
		tt.take_hit(pj.inf(c, "ranshinsho", 0.6, {"knock": 1.0, "kind": "light"}))
		pj.st(tt, "stun", 3.0)
		_nerve_map(tt, 3.0)
		pj.after(3.0, func():
			pj.st(tt, "slow", 4.0)
			_twitch(tt, 4.0))
		Combat.popup_text(tt.global_position + Vector3.UP * 2.4, "Sinirler karıştı!", Color(0.6, 1, 0.7))


# ═════════════════════════════════════════ Chidori Nagashi (bedenden akım) ═════════════════════════════════════════

## Kaynak: bütün bedenden her yöne uzanan uzun, az kırılımlı, kalın beyaz şimşekler (mavi hâleli). Önce beden çatırdar,
## sonra uzun ışınlar dışa uzanır; akım zeminden de akar: ayaktan dışa yıldız gibi açılan düz yer çizgileri, yanık.
static func _ground_spokes(g: Vector3, r: float, n: int, dur: float) -> void:
	var lines = []
	for k in n:
		var a = TAU * (float(k) + randf_range(-0.3, 0.3)) / n
		var e = g + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.7, 1.15)
		lines.append(RaitonLib.ground_path(g, e, 0.06, 3, 0.05))
	var wm = RaitonLib.web_mat(RaitonLib.RAI)
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > dur:
			return false
		var f = clampf(age / 0.1, 0.0, 1.0)
		var polys = []
		for ln in lines:
			var cut = maxi(2, int((ln as Array).size() * f))
			polys.append({"p": (ln as Array).slice(0, cut), "w": 0.06, "a": 1.0, "k": 0})
		RaitonLib.draw(im, wm, polys, clampf((dur - age) / 0.35, 0.0, 1.0), _cam(), true)
		return true)


static func chidori_nagashi(pj: PathJutsu, c: Node3D, _t: Node3D) -> void:
	pj.busy(c, 0.7)
	var at = c.global_position + Vector3.UP * 1.0
	RaitonLib.body_arcs(c, 0.7, RaitonLib.PALE, 7, 0.05)
	pj.every(0.6, 0.06, func(_i, _k):
		if not pj.live(c):
			return
		for k in 3:
			var a = randf() * TAU
			RaitonLib.bolt(c.global_position + Vector3.UP * randf_range(0.4, 1.6), c.global_position + Vector3(cos(a) * 5.5, randf_range(0.2, 2.8), sin(a) * 5.5), Color(0.85, 0.95, 1.0), 0.13, 0.18, 1, 0.07, 0.06, 4), Callable())
	var g = pj.gp(at)
	_ground_spokes(g, 4.5, 14, 0.6)
	RaitonLib.flash(at, 2.4, RaitonLib.RAI, 0.14, 14.0)
	RaitonLib.scorch(g, 2.2, RaitonLib.RAI, 5.0, 1.0)
	RaitonLib.light(at, RaitonLib.PALE, 6.0, 10.0, 0.6)
	for e in pj.hit(c, at, 4.5, pj.inf(c, "chidori_nagashi", 1.1, {"knock": 8.0, "kind": "heavy", "element": "raiton"})):
		pj.st(e, "stun", 1.6)
		RaitonLib.body_arcs(e, 1.6, RaitonLib.RAI, 3, 0.035)
	Sfx.play("chidori", at, 1.0)


# ═════════════════════════════════════════ Chidori Senbon (şimşek iğneleri) ═════════════════════════════════════════

## Kaynak: yelpaze gibi açılan, çok sayıda dümdüz, ince beyaz iğne (camgöbeği hâle). Her iğne iki çapraz şerit
## (her açıdan ince çizgi görünür), arkasında çok kısa ışık kuyruğu; saplandığı yerde minik çakma ve kıvılcım.
static var _needle_mesh: ArrayMesh = null


## İğne şeridi: -Z boyunca 1.1 m, iki çapraz yüz; şimşek şeridi gölgelendiricisi için UV.y enine, köşe rengi beyaz
static func _needle_strip() -> ArrayMesh:
	if _needle_mesh != null:
		return _needle_mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw = 0.045
	for side in [Vector3.RIGHT, Vector3.UP]:
		var q0 = Vector3(0, 0, 0.55)
		var q1 = Vector3(0, 0, -0.55)
		var c4 = [[q0 + side * hw, 0.0, 0.0], [q0 - side * hw, 0.0, 1.0], [q1 + side * hw, 1.1, 0.0], [q1 - side * hw, 1.1, 1.0]]
		for idx in [0, 1, 2, 2, 1, 3]:
			st.set_color(Color(1, 1, 1, 1))
			st.set_uv(Vector2(c4[idx][1], c4[idx][2]))
			st.add_vertex(c4[idx][0])
	_needle_mesh = st.commit()
	return _needle_mesh


static func _needle() -> Node3D:
	var holder = Node3D.new()
	holder.add_child(RaitonLib.mi_of(_needle_strip(), RaitonLib.arc_mat(Color(0.7, 0.9, 1.0))))
	return holder


static func _needle_hit(p: Vector3) -> void:
	RaitonLib.flash(p, 0.6, RaitonLib.RAI, 0.08, 6.0)
	RaitonLib.sparks(p, 5, RaitonLib.RAI, 4.0, 0.25)
	RaitonLib.bolt(p, p + Vector3(randf_range(-0.6, 0.6), randf_range(0, 0.8), randf_range(-0.6, 0.6)), RaitonLib.RAI, 0.05, 0.15, 1, 0.3)


static func chidori_senbon(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.6)
	var tt = pj.tg(c, t, 24.0)
	var from = pj.hand_pos(c, true)
	RaitonLib.hand_charge(pj, c, 0.6, RaitonLib.RAI, 0.9)
	RaitonLib.converge(RaitonLib.hand_fn(pj, c), 0.9, 0.2, RaitonLib.PALE, 14, 0.018)
	pj.after(0.2, func():
		if not pj.live(c):
			return
		for k in 16:
			var nd = _needle()
			var pr = pj.shot(c, from, pj.aim_at(c, tt, from).rotated(Vector3.UP, deg_to_rad((k - 7.5) * 3.2)).rotated(Vector3.RIGHT, deg_to_rad(randf_range(-3.0, 3.0))), 50.0, nd, pj.inf(c, "chidori_senbon", 0.12, {"knock": 0.5, "kind": "light", "element": "raiton", "stun": 0.3}), null, false, 0.8, func(p, _h):
				_needle_hit(p))
			RaitonLib.trail(pr, Color(0.85, 0.95, 1.0), 0.03, 0.06, 0.0)
		RaitonLib.flash(from, 1.2, RaitonLib.PALE, 0.1, 16.0)
		Sfx.play("chidori", from, 1.5, 0.6))


# ═════════════════════════════════════════ Chidori Eisō (uzayan şimşek kılıcı) ═════════════════════════════════════════

## Kaynak: elden uzanan, hafif kavisli, ucu sivri beyaz ışık kılıcı (camgöbeği hâle); elde dişli beyaz çakma. Kılıç bir
## anda 18 m uzar, tutar, ele geri çekilir; çevresinde iki ince sarmal tel, ucunda küçük çakma ve kıvılcım.
static func _spear(pj: PathJutsu, c: Node3D, from: Vector3, dir: Vector3) -> void:
	var gm = RaitonLib.arc_mat(RaitonLib.CYAN)
	var cm = RaitonLib.arc_mat(RaitonLib.PALE)
	var base_fn = RaitonLib.hand_fn(pj, c)
	var pv = RaitonLib.perp(dir)
	var bend = pv * 0.7
	var stt = {"next": 0.0, "thr": []}
	RaitonLib.host(func(im, _n, _dt, age) -> bool:
		if age > 0.48:
			return false
		var b0: Vector3 = base_fn.call()
		var L = 18.0
		var s0 = 0.0
		if age < 0.08:
			L = 18.0 * (age / 0.08)
		elif age > 0.33:
			s0 = 18.0 * ((age - 0.33) / 0.15)   # geri çekilirken uç ele doğru kısalır
		var tip_len = maxf(L - s0, 0.05)
		var pts = []
		for i in 13:
			var f = float(i) / 12.0
			var u = tip_len * (1.0 - f)   # uçtan tabana: k=1 tabana doğru kalınlaşır
			pts.append(b0 + dir * u + bend * sin(PI * u / 18.0) * (u / 18.0))
		RaitonLib.draw(im, gm, [{"p": pts, "w": 0.26, "a": 0.8, "k": 1}], 1.0, _cam())
		RaitonLib.draw(im, cm, [{"p": pts, "w": 0.1, "a": 1.0, "k": 1}], 1.0, _cam())
		if age >= float(stt["next"]):
			stt["next"] = age + 0.04
			var thr = []
			for k in 2:
				var ph = randf() * TAU
				var sp = []
				for i in 16:
					var f = float(i) / 15.0
					var u = tip_len * f
					var rr = pv.rotated(dir, ph + f * 9.0) * 0.12
					sp.append(b0 + dir * u + bend * sin(PI * u / 18.0) * (u / 18.0) + rr)
				thr.append({"p": sp, "w": 0.025, "a": 0.8})
			stt["thr"] = thr
		RaitonLib.draw(im, gm, stt["thr"], 1.0, _cam())
		return true)
	RaitonLib.flash(from, 1.4, RaitonLib.RAI, 0.35, 12.0)


static func chidori_eiso(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.9)
	var tt = pj.tg(c, t, 20.0)
	RaitonLib.hand_charge(pj, c, 0.9, RaitonLib.RAI, 1.1)
	RaitonLib.converge(RaitonLib.hand_fn(pj, c), 1.3, 0.4, RaitonLib.RAI, 12)
	pj.after(0.4, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var dir = pj.aim_at(c, tt, from).normalized()
		var end = from + dir * 18.0
		_spear(pj, c, from, dir)
		Combat.hit_zone(c, c.global_position, pj.aim_at(c, tt, from), 18.0, 4.0, 2.5, pj.inf(c, "chidori_eiso", 1.8, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 0.8, "hitstop": 0.08}))
		pj.after(0.08, func():
			RaitonLib.flash(end, 1.2, RaitonLib.RAI, 0.12, 8.0)
			RaitonLib.sparks(end, 12, RaitonLib.RAI, 8.0, 0.35, dir, 0.6)
			if _near_ground(end, 1.5):
				RaitonLib.scorch(RaitonLib.floor_at(end), 0.9, RaitonLib.RAI, 4.0, 0.6))
		Sfx.play("chidori", from, 1.2))


# ═════════════════════════════════════════ Raiton: Shiden (mor şimşek) ═════════════════════════════════════════

## (Kaynak yok, kendi tasarım) Mor yük önkolu sarar, ayak dibinde mor yer arkları; salınımda elden hedefe kalın, dallı
## mor şimşek + beyaz-pembe öz; yol boyunca yanlara mor saçaklar kopar; çarpışta mor çakma, kıvılcım, yer arkı, mor yanık.
static func raiton_shiden(pj: PathJutsu, c: Node3D, t: Node3D) -> void:
	pj.busy(c, 0.8)
	var tt = pj.tg(c, t, 30.0)
	RaitonLib.hand_charge(pj, c, 0.6, PURPLE, 1.0)
	RaitonLib.crackle(RaitonLib.hand_fn(pj, c), 0.7, 0.3, PURPLE, 6, 0.035, 0.05)
	RaitonLib.ground_arcs(pj.gp(c.global_position), 1.2, 0.35, PURPLE, 4, 0.035)
	pj.after(0.3, func():
		if not pj.live(c):
			return
		var from = pj.hand_pos(c, true)
		var end = (tt.global_position + Vector3.UP if tt else from + c.face_dir() * 28.0)
		RaitonLib.bolt(from, end, PURPLE, 0.35, 0.35, 5, 0.18, 0.045, 5)
		RaitonLib.bolt(from, end, Color(1, 0.9, 1.0), 0.1, 0.35, 0, 0.18, 0.045, 5)
		var dd = (end - from)
		for k in 6:
			var s = from + dd * randf_range(0.15, 0.85)
			RaitonLib.bolt(s, s + RaitonLib.perp(dd) * randf_range(1.0, 2.2) + Vector3.UP * randf_range(-0.3, 0.6), PURPLE, 0.05, 0.22, 1, 0.3)
		RaitonLib.flash(end, 2.4, PURPLE, 0.16, 11.0)
		RaitonLib.sparks(end, 24, PURPLE, 10.0, 0.45)
		RaitonLib.light(end, PURPLE, 7.0, 12.0, 0.35)
		if _near_ground(end, 2.2):
			var g = RaitonLib.floor_at(end)
			RaitonLib.ground_arcs(g, 1.6, 0.45, PURPLE, 5, 0.04)
			RaitonLib.scorch(g, 1.4, PURPLE, 5.0, 0.8)
		if tt:
			pj.hit(c, end, 1.6, pj.inf(c, "raiton_shiden", 1.8, {"knock": 8.0, "kind": "heavy", "element": "raiton", "stun": 0.8}))
		Sfx.play("chidori", from, 1.0))
